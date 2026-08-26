extends Resource
class_name CareerContractEngine

const ENGINE_SCHEMA:= "eralife.career_contract_engine"
const ENGINE_VERSION:= 1
const PANEL_SCHEMA:= "eralife.career_panel_contract"
const APPLICATION_SCHEMA:= "eralife.career_application_contract"
const PROMOTION_SCHEMA:= "eralife.career_promotion_contract"

var gs
var career_paths: Dictionary = {}
var alias_to_path_id: Dictionary = {}





var education_path_index: Dictionary = {}

var last_report: Dictionary = {}


func _init(_gs):
	gs = _gs
	_build_catalog()




	call_deferred(
		"_sync_provider_backed_access_paths_and_runtime"
	)


func bootstrap_default_contracts() -> Dictionary:
	if career_paths.is_empty():
		_build_catalog()



	call_deferred(
		"_sync_provider_backed_access_paths_and_runtime"
	)

	if (
		gs != null
		and gs.career_runtime_engine != null
	):
		gs.career_runtime_engine.ensure_world_ecosystem({
			"source": (
				"career_contract_engine.bootstrap_default_contracts"
			)
		})

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"path_count": career_paths.size(),
		"ui_is_renderer_only": true
	}


func resolve_intent(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _fail(
			"missing_actor",
			payload
		)

	if (
		gs == null
		or gs.career_runtime_engine == null
	):
		var unavailable: Dictionary = _fail(
			"career_runtime_unavailable",
			payload
		)
		unavailable [
			"career_panel_contract"
		] = _observable_partial_panel(
			actor,
			payload
		)
		return unavailable

	var action_id: String = str(
		payload.get(
			"action_id",
			payload.get(
				"intent_type",
				"refresh"
			)
		)
	).strip_edges().to_lower()

	var result: Dictionary = {}

	match action_id:
		"", "refresh", "open_panel", "set_section":
			result = {
				"success": true,
				"type": "career_panel_refreshed"
			}

		"apply_position":
			result = evaluate_application(
				actor,
				str(
					payload.get(
						"position_id",
						""
					)
				),
				payload
			)

		"apply_legacy_job":
			result = apply_for_legacy_job(
				actor,
				str(
					payload.get(
						"job_name",
						""
					)
				),
				str(
					payload.get(
						"lane",
						"full_time"
					)
				),
				payload
			)

		"perform_activity", "work_shift":
			result = perform_activity(
				actor,
				str(
					payload.get(
						"activity_id",
						""
					)
				),
				payload
			)

		"request_promotion":
			result = evaluate_promotion(
				actor,
				payload
			)

		"set_weekly_hours":
			result = (
				gs.career_runtime_engine
				.commit_weekly_hours(
					actor,
					int(
						payload.get(
							"weekly_hours",
							40
						)
					),
					payload
				)
			)

		"work_harder":
			result = (
				gs.career_runtime_engine
				.commit_work_harder(
					actor,
					payload
				)
			)

		"request_raise":
			result = evaluate_raise(
				actor,
				payload
			)

		"quit_position":
			result = (
				gs.career_runtime_engine
				.commit_quit(
					actor,
					payload
				)
			)

		"retire":
			result = (
				gs.career_runtime_engine
				.commit_retirement(
					actor,
					payload
				)
			)

		"view_coworkers":
			result = {
				"success": true,
				"type": (
					"open_career_coworkers_panel"
				),
				"coworker_ids": (
					gs.career_runtime_engine
					.coworker_ids_for_actor(
						actor
					)
				),
				"text": (
					"I viewed the professionals in my department."
				)
			}

		_:
			result = _fail(
				"unknown_career_intent",
				payload
			)

	var projection_only_action: bool = (
		action_id in [
			"",
			"refresh",
			"open_panel",
			"set_section"
		]
	)

	if projection_only_action:
		var section_id: String = str(
			payload.get(
				"section_id",
				"overview"
			)
		).to_lower()

		if section_id == "":
			section_id = "overview"

		result [
			"career_panel_contract"
		] = emit_panel_contract(
			actor,
			{
				"active_section": section_id,
				"status_text": str(
					result.get(
						"text",
						""
					)
				),
				"source": (
					"career_contract_engine.resolve_intent"
				),
				"projection_read_only": true,
				"build_on_click_forbidden": true,
				"ready_gate_member": false
			}
		)

		result [
			"career_panel_contract_publication_pending"
		] = false
		result [
			"career_panel_contract_rebuilt_before_action_receipt"
		] = true

	else:


		result [
			"career_panel_contract"
		] = {}
		result [
			"career_panel_contract_publication_pending"
		] = bool(
			result.get(
				"success",
				false
			)
		)
		result [
			"career_panel_contract_rebuilt_before_action_receipt"
		] = false
		result [
			"career_panel_contract_blocks_ui"
		] = false

	result [
		"career_contract_engine_owned"
	] = true
	result [
		"projection_does_not_reconcile_world"
	] = true
	result [
		"ui_is_renderer_only"
	] = true

	last_report = result.duplicate(true)

	return result
func evaluate_application(
	actor: Person,
	position_id: String,
	context: Dictionary = {}
) -> Dictionary:
	if (
		gs == null
		or gs.career_runtime_engine == null
	):
		return _fail(
			"career_runtime_unavailable",
			context
		)

	var position: Dictionary = (
		gs.career_runtime_engine
		.position_by_id(
			position_id
		)
	)

	if position.is_empty():
		return _fail(
			"position_not_found",
			context
		)

	if str(
		position.get(
			"status",
			""
		)
	) != "vacant":
		return _fail(
			"position_no_longer_vacant",
			context
		)

	var path: Dictionary = get_path_definition(
		str(
			position.get(
				"path_id",
				""
			)
		)
	)
	var rank: Dictionary = get_rank_definition(
		str(
			position.get(
				"path_id",
				""
			)
		),
		int(
			position.get(
				"rank_index",
				0
			)
		)
	)
	var requirements: Dictionary = (
		evaluate_entry_requirements(
			actor,
			path,
			rank
		)
	)
	var profile: Dictionary = (
		gs.career_runtime_engine
		.ensure_actor_profile(
			actor
		)
	)
	var application_count: int = _safe_array(
		profile.get(
			"application_ids",
			[]
		)
	).size()
	var score: int = clampi(
		20
		+ int(actor.smarts * 0.22)
		+ int(actor.job_performance * 0.18)
		+ int(actor.satisfaction * 0.08)
		+ int(
			_professional_reputation_score(
				profile
			) * 0.24
		)
		+ min(
			int(actor.job_experience) * 2,
			16
		),
		0,
		100
	)
	var competition: int = int(
		position.get(
			"competition",
			55
		)
	)
	var institutional_roll: int = _stable_roll(
		"application|%d|%s|%d|%d"
		% [
			int(actor.id),
			position_id,
			int(gs.year),
			application_count
		],
		0,
		24
	)
	var accepted: bool = (
		bool(
			requirements.get(
				"eligible",
				false
			)
		)
		and score + institutional_roll >= competition
	)
	var application: Dictionary = {
		"schema": APPLICATION_SCHEMA,
		"version": 1,
		"actor_id": int(actor.id),
		"position_id": position_id,
		"path_id": str(
			position.get(
				"path_id",
				""
			)
		),
		"organization_id": str(
			position.get(
				"organization_id",
				""
			)
		),
		"score": score,
		"competition": competition,
		"institutional_roll": institutional_roll,
		"accepted": accepted,
		"requirements": requirements.duplicate(true),
		"year": int(gs.year)
	}

	application = (
		gs.career_runtime_engine
		.record_application(
			actor,
			position,
			application
		)
	)

	if not bool(
		requirements.get(
			"eligible",
			false
		)
	):
		return {
			"success": false,
			"type": (
				"career_application_rejected"
			),
			"text": (
				"The institution rejected my application. %s"
				% str(
					requirements.get(
						"summary",
						""
					)
				)
			),
			"application_contract": application,
			"popup_title": "APPLICATION REJECTED",
			"popup_text": str(
				requirements.get(
					"summary",
					""
				)
			)
		}

	if not accepted:
		return {
			"success": false,
			"type": (
				"career_application_rejected"
			),
			"text": (
				"I qualified, but the organization selected another candidate."
			),
			"application_contract": application,
			"popup_title": "APPLICATION RESULT",
			"popup_text": (
				"Application score: %d. Threshold: %d."
				% [
					score + institutional_roll,
					competition
				]
			)
		}

	var commit_context: Dictionary = context.duplicate(
		true
	)
	commit_context [
		"application_contract"
	] = application.duplicate(true)

	var result: Dictionary = (
		gs.career_runtime_engine
		.commit_hire(
			actor,
			position,
			commit_context
		)
	)

	result [
		"application_contract"
	] = application

	return result
func evaluate_promotion(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	var assignment: Dictionary = (
		gs.career_runtime_engine
		.assignment_for_actor(
			actor
		)
	)

	if assignment.is_empty():
		return _fail(
			"actor_has_no_active_position",
			context
		)

	var path_id: String = str(
		assignment.get(
			"path_id",
			""
		)
	)
	var path: Dictionary = get_path_definition(
		path_id
	)
	var current_index: int = int(
		assignment.get(
			"rank_index",
			0
		)
	)
	var next_index: int = current_index + 1

	if next_index >= _safe_array(
		path.get(
			"ranks",
			[]
		)
	).size():
		return {
			"success": false,
			"type": (
				"career_promotion_unavailable"
			),
			"text": (
				"I already hold the highest rank in this profession."
			)
		}

	var next_rank: Dictionary = get_rank_definition(
		path_id,
		next_index
	)
	var vacancy: Dictionary = (
		gs.career_runtime_engine
		.find_promotion_vacancy(
			actor
		)
	)

	if vacancy.is_empty():
		return {
			"success": false,
			"type": (
				"career_promotion_no_vacancy"
			),
			"text": (
				"No %s position is currently vacant."
				% str(
					next_rank.get(
						"title",
						"higher rank"
					)
				)
			),
		}

	var profile: Dictionary = (
		gs.career_runtime_engine
		.ensure_actor_profile(
			actor
		)
	)
	var experience: int = int(
		assignment.get(
			"experience",
			actor.job_experience
		)
	)
	var reputation: int = (
		_professional_reputation_score(
			profile
		)
	)
	var eligible: bool = (
		experience >= int(
			next_rank.get(
				"min_experience",
				2
			)
		)
		and int(actor.job_performance) >= int(
			next_rank.get(
				"min_performance",
				65
			)
		)
		and reputation >= int(
			next_rank.get(
				"min_reputation",
				35
			)
		)
	)
	var review_score: int = clampi(
		int(actor.job_performance * 0.45)
		+ min(
			experience * 4,
			24
		)
		+ int(reputation * 0.31),
		0,
		100
	)
	var threshold: int = int(
		next_rank.get(
			"promotion_threshold",
			68
		)
	)

	if bool(
		context.get(
			"automatic_review",
			false
		)
	):
		threshold += 5

	var approved: bool = (
		eligible
		and review_score >= threshold
	)
	var contract: Dictionary = {
		"schema": PROMOTION_SCHEMA,
		"version": 1,
		"actor_id": int(actor.id),
		"path_id": path_id,
		"next_rank": next_rank.duplicate(true),
		"vacancy": vacancy.duplicate(true),
		"eligible": eligible,
		"approved": approved,
		"review_score": review_score,
		"threshold": threshold,
		"performance": int(actor.job_performance),
		"experience": experience,
		"professional_reputation": reputation,
		"year": int(gs.year)
	}

	if not approved:
		return {
			"success": false,
			"type": (
				"career_promotion_denied"
			),
			"text": (
				"The promotion review did not approve me yet."
			),
			"promotion_contract": contract
		}

	var result: Dictionary = (
		gs.career_runtime_engine
		.commit_promotion(
			actor,
			vacancy,
			contract
		)
	)
	result [
		"promotion_contract"
	] = contract

	return result
func _build_catalog() -> void:
	career_paths.clear()
	alias_to_path_id.clear()
	education_path_index.clear()

	_register_ancient_paths()
	_register_medieval_paths()
	_register_industrial_paths()
	_register_modern_paths()
	_register_future_paths()




	_register_expanded_ordinary_paths()

	_register_part_time_paths()



	_rebuild_education_path_index()
func _rebuild_education_path_index() -> void:
	education_path_index.clear()

	var requirement_keys: Array = [
		"majors_any",
		"required_majors_any",
		"graduate_programs_any",
		"graduate_schools_any",
		"historical_programs_any"
	]

	for raw_path_id in career_paths.keys():
		var path_id: String = str(
			raw_path_id
		).strip_edges()

		if path_id == "":
			continue

		var path: Dictionary = _safe_dictionary(
			career_paths.get(
				path_id,
				{}
			)
		)

		if path.is_empty():
			continue

		var requirements: Dictionary = _safe_dictionary(
			path.get(
				"entry_requirements",
				{}
			)
		)
		var eras: Array = _safe_array(
			path.get(
				"eras",
				[]
			)
		)
		var qualification_tokens: Array = []

		for requirement_key in requirement_keys:
			for raw_token in _safe_array(
				requirements.get(
					str(requirement_key),
					[]
				)
			):
				var token: String = str(
					raw_token
				).strip_edges()

				if (
					token != ""
					and token not in qualification_tokens
				):
					qualification_tokens.append(
						token
					)

		if qualification_tokens.is_empty():
			continue

		for raw_era in eras:
			var era_key: String = _normalize_lookup_key(
				str(
					raw_era
				)
			)

			if era_key == "":
				continue

			for raw_token in qualification_tokens:
				var token_key: String = _normalize_lookup_key(
					str(
						raw_token
					)
				)

				if token_key == "":
					continue

				var index_key: String = (
					"%s|%s"
					% [
						era_key,
						token_key
					]
				)
				var linked_raw: Variant = (
					education_path_index.get(
						index_key,
						[]
					)
				)
				var linked_path_ids: Array = (
					(linked_raw as Array).duplicate(false)
					if typeof(linked_raw) == TYPE_ARRAY
					else []
				)

				if path_id not in linked_path_ids:
					linked_path_ids.append(
						path_id
					)

				education_path_index [
					index_key
				] = linked_path_ids


func emit_education_path_projection(
	era_name: String,
	qualification_tokens: Array
) -> Dictionary:
	var clean_era: String = str(
		era_name
	).strip_edges()
	var era_key: String = _normalize_lookup_key(
		clean_era
	)
	var clean_tokens: Array = []
	var linked_path_ids: Array = []

	for raw_token in qualification_tokens:
		var token: String = str(
			raw_token
		).strip_edges()

		if token == "":
			continue

		if token not in clean_tokens:
			clean_tokens.append(
				token
			)

		var token_key: String = _normalize_lookup_key(
			token
		)

		if (
			era_key == ""
			or token_key == ""
		):
			continue

		var index_key: String = (
			"%s|%s"
			% [
				era_key,
				token_key
			]
		)
		var indexed_raw: Variant = (
			education_path_index.get(
				index_key,
				[]
			)
		)
		var indexed_paths: Array = (
			indexed_raw as Array
			if typeof(indexed_raw) == TYPE_ARRAY
			else []
		)

		for raw_path_id in indexed_paths:
			var path_id: String = str(
				raw_path_id
			).strip_edges()

			if (
				path_id != ""
				and path_id not in linked_path_ids
			):
				linked_path_ids.append(
					path_id
				)

	var career_rows: Array = []
	var display_lines: Array = []

	for raw_path_id in linked_path_ids:
		var path_id: String = str(
			raw_path_id
		).strip_edges()
		var path: Dictionary = _safe_dictionary(
			career_paths.get(
				path_id,
				{}
			)
		)

		if path.is_empty():
			continue

		var display_name: String = str(
			path.get(
				"display_name",
				path_id
			)
		).strip_edges()
		var aliases: Array = []

		for raw_alias in _safe_array(
			path.get(
				"aliases",
				[]
			)
		):
			var alias_name: String = str(
				raw_alias
			).strip_edges()

			if (
				alias_name != ""
				and alias_name not in aliases
			):
				aliases.append(
					alias_name
				)

		var requirements: Dictionary = _safe_dictionary(
			path.get(
				"entry_requirements",
				{}
			)
		)
		var graduate_programs: Array = _safe_array(
			requirements.get(
				"graduate_programs_any",
				requirements.get(
					"graduate_schools_any",
					[]
				)
			)
		)
		var career_titles: Array = aliases.duplicate(
			false
		)

		if career_titles.is_empty():
			career_titles.append(
				display_name
			)

		var career_title_text: String = (
			", ".join(
				PackedStringArray(
					career_titles
				)
			)
		)
		var display_line: String = (
			"%s → %s"
			% [
				display_name,
				career_title_text
			]
		)

		if not graduate_programs.is_empty():
			display_line += (
				" • further study: %s"
				% " or ".join(
					PackedStringArray(
						graduate_programs
					)
				)
			)

		career_rows.append({
			"path_id": path_id,
			"display_name": display_name,
			"career_titles": career_titles,
			"graduate_programs_required": (
				graduate_programs
			),
			"display_line": display_line,
			"ui_is_renderer_only": true
		})

		display_lines.append(
			display_line
		)

	if display_lines.is_empty():
		display_lines.append(
			(
				"Broad education path • no direct CareerContractEngine "
				+ "education gate is registered for this study yet."
			)
		)

	return {
		"success": true,
		"schema": (
			"eralife.career_contract_engine."
			+ "education_path_projection"
		),
		"version": ENGINE_VERSION,
		"era_name": clean_era,
		"qualification_tokens": clean_tokens,
		"career_paths": career_rows,
		"display_lines": display_lines,
		"career_path_count": career_rows.size(),
		"career_truth_source": ENGINE_SCHEMA,
		"projection_read_only": true,
		"ui_is_renderer_only": true
	}
func _register_expanded_ordinary_paths() -> void:
	_register_path(
		_ordinary_path_with_salary(
			_path(
				"ancient_field_labor",
				"Field and Irrigation Labor",
				[
					"Ancient Era"
				],
				"Estate and Irrigation Works",
				"agriculture",
				"Field Operations",
				[
					"Field Worker",
					"Farm Laborer",
					"Irrigation Worker",
					"Harvest Worker"
				],
				{
					"min_age": 12,
					"min_health": 28
				},
				[
					"Field Hand",
					"Irrigation Worker",
					"Harvest Overseer",
					"Estate Steward"
				],
				_agriculture_activities(),
				(
					"Plant, irrigate, harvest, and preserve the food "
					+ "supply that keeps an ancient settlement alive."
				)
			),
			{
				"Ancient Era": 720
			}
		)
	)

	_register_path(
		_ordinary_path_with_salary(
			_path(
				"ancient_river_port_labor",
				"River and Port Labor",
				[
					"Ancient Era"
				],
				"River Port Labor Exchange",
				"logistics",
				"Cargo and Loading",
				[
					"Dock Worker",
					"Porter",
					"Ship Loader",
					"River Laborer"
				],
				{
					"min_age": 14,
					"min_health": 38
				},
				[
					"Porter",
					"Dock Worker",
					"Cargo Foreman",
					"Harbor Overseer"
				],
				_logistics_activities(),
				(
					"Move grain, stone, livestock, and trade goods "
					+ "through a working river port."
				)
			),
			{
				"Ancient Era": 900
			}
		)
	)

	_register_path(
		_ordinary_path_with_salary(
			_path(
				"medieval_painter_workshop",
				"Painter's Workshop",
				[
					"Medieval Era"
				],
				"Painter and Illuminator Guild",
				"artist_workshop",
				"Painting and Illumination",
				[
					"Painter",
					"Portrait Painter",
					"Illuminator",
					"Church Painter",
					"Guild Painter"
				],
				{
					"min_age": 14,
					"min_smarts": 30
				},
				[
					"Pigment Grinder",
					"Apprentice Painter",
					"Painter",
					"Master Painter"
				],
				_painter_activities(),
				(
					"Prepare pigments, fulfill commissions, and create "
					+ "paintings whose value becomes persistent property."
				)
			),
			{
				"Medieval Era": 1500
			}
		)
	)

	_register_path(
		_ordinary_path_with_salary(
			_path(
				"medieval_bakery_guild",
				"Bakery and Oven Guild",
				[
					"Medieval Era"
				],
				"Bakery and Oven Guild",
				"restaurant",
				"Bread and Kitchen Service",
				[
					"Baker",
					"Bakery Helper",
					"Oven Keeper",
					"Bread Seller"
				],
				{
					"min_age": 12,
					"min_health": 25
				},
				[
					"Oven Helper",
					"Baker",
					"Senior Baker",
					"Master Baker"
				],
				_food_service_activities(),
				(
					"Prepare bread and meals inside a working guild "
					+ "kitchen serving the surrounding settlement."
				)
			),
			{
				"Medieval Era": 1050
			}
		)
	)

	_register_path(
		_ordinary_path_with_salary(
			_path(
				"medieval_carpenter_guild",
				"Carpenter Guild",
				[
					"Medieval Era"
				],
				"Carpenter and Joiner Guild",
				"guild",
				"Woodcraft and Construction",
				[
					"Carpenter",
					"Joiner",
					"Woodworker",
					"Wheelwright"
				],
				{
					"min_age": 14,
					"min_health": 34
				},
				[
					"Carpenter's Apprentice",
					"Journeyman Carpenter",
					"Master Carpenter",
					"Guild Master"
				],
				_craft_activities(),
				(
					"Build furniture, tools, carts, roofs, and structures "
					+ "through an apprenticeship-governed craft."
				)
			),
			{
				"Medieval Era": 1350
			}
		)
	)

	_register_path(
		_ordinary_path_with_salary(
			_path(
				"industrial_factory_production",
				"Factory Production",
				[
					"Industrial Era"
				],
				"Industrial Manufacturing Works",
				"factory",
				"Production Floor",
				[
					"Factory Worker",
					"Mill Worker",
					"Textile Worker",
					"Steel Worker",
					"Machine Operator"
				],
				{
					"min_age": 14,
					"min_health": 35
				},
				[
					"Factory Hand",
					"Machine Operator",
					"Skilled Operator",
					"Factory Foreman"
				],
				_factory_activities(),
				(
					"Operate machinery, maintain production quality, "
					+ "and respond to industrial breakdowns."
				)
			),
			{
				"Industrial Era": 15000
			}
		)
	)

	_register_path(
		_ordinary_path_with_salary(
			_path(
				"industrial_rail_service",
				"Railway Service",
				[
					"Industrial Era"
				],
				"National Rail Service",
				"logistics",
				"Rail and Station Operations",
				[
					"Railroad Conductor",
					"Station Clerk",
					"Rail Yard Worker",
					"Telegraph Operator"
				],
				{
					"min_age": 16,
					"min_smarts": 30
				},
				[
					"Rail Yard Runner",
					"Station Worker",
					"Railroad Conductor",
					"Station Master"
				],
				_logistics_activities(),
				(
					"Coordinate passengers, freight, timetables, "
					+ "signals, and railway disruptions."
				)
			),
			{
				"Industrial Era": 19000
			}
		)
	)

	_register_path(
		_ordinary_path_with_salary(
			_path(
				"industrial_photography_studio",
				"Photography Studio",
				[
					"Industrial Era"
				],
				"Portrait and News Photography Studio",
				"artist_workshop",
				"Photography and Development",
				[
					"Photographer",
					"Portrait Photographer",
					"News Photographer",
					"Darkroom Assistant"
				],
				{
					"min_age": 16,
					"min_smarts": 35
				},
				[
					"Darkroom Assistant",
					"Studio Photographer",
					"Senior Photographer",
					"Studio Proprietor"
				],
				_photography_activities(),
				(
					"Capture portraits and events, develop plates, "
					+ "and build a professional photographic archive."
				)
			),
			{
				"Industrial Era": 21000
			}
		)
	)

	_register_path(
		_ordinary_path_with_salary(
			_path(
				"modern_warehouse_operations",
				"Warehouse Operations",
				[
					"Modern Era"
				],
				"Regional Distribution Network",
				"logistics",
				"Warehouse and Fulfillment",
				[
					"Warehouse Associate",
					"Inventory Clerk",
					"Forklift Operator",
					"Fulfillment Worker"
				],
				{
					"min_age": 18,
					"min_health": 30
				},
				[
					"Warehouse Associate",
					"Inventory Specialist",
					"Shift Lead",
					"Warehouse Manager"
				],
				_logistics_activities(),
				(
					"Receive, track, store, and dispatch inventory "
					+ "inside a live distribution institution."
				)
			),
			{
				"Modern Era": 34000
			}
		)
	)

	_register_path(
		_ordinary_path_with_salary(
			_path(
				"modern_customer_support",
				"Customer Support",
				[
					"Modern Era"
				],
				"Customer Operations Network",
				"office",
				"Customer Support",
				[
					"Customer Support Agent",
					"Call Center Worker",
					"Support Representative"
				],
				{
					"min_age": 18,
					"min_smarts": 28
				},
				[
					"Support Agent",
					"Senior Support Agent",
					"Team Lead",
					"Support Manager"
				],
				_customer_support_activities(),
				(
					"Resolve customer problems, document cases, "
					+ "and manage service pressure."
				)
			),
			{
				"Modern Era": 38000
			}
		)
	)

	_register_path(
		_ordinary_path_with_salary(
			_path(
				"modern_facilities_service",
				"Facilities Service",
				[
					"Modern Era"
				],
				"Facilities and Building Services",
				"maintenance",
				"Building Operations",
				[
					"Maintenance Worker",
					"Custodian",
					"Facilities Technician"
				],
				{
					"min_age": 18,
					"min_health": 30
				},
				[
					"Facilities Worker",
					"Maintenance Technician",
					"Facilities Lead",
					"Building Operations Manager"
				],
				_maintenance_activities(),
				(
					"Maintain a building's equipment, cleanliness, "
					+ "safety, and service continuity."
				)
			),
			{
				"Modern Era": 36000
			}
		)
	)

	_register_path(
		_ordinary_path_with_salary(
			_path(
				"future_habitat_maintenance",
				"Habitat Maintenance",
				[
					"Future Era"
				],
				"Habitat Service Directorate",
				"maintenance",
				"Habitat Operations",
				[
					"Habitat Custodian",
					"Life Support Attendant",
					"Maintenance Technician"
				],
				{
					"min_age": 18,
					"min_health": 30
				},
				[
					"Habitat Service Worker",
					"Systems Attendant",
					"Habitat Technician",
					"Habitat Operations Lead"
				],
				_maintenance_activities(),
				(
					"Maintain sanitation, power, pressure, and life-support "
					+ "continuity throughout a future habitat."
				)
			),
			{
				"Future Era": 65000
			}
		)
	)

	_register_path(
		_ordinary_path_with_salary(
			_path(
				"future_drone_logistics",
				"Drone Logistics",
				[
					"Future Era"
				],
				"Autonomous Delivery Network",
				"logistics",
				"Drone Dispatch",
				[
					"Drone Runner",
					"Drone Dispatcher",
					"Orbital Courier",
					"Delivery Coordinator"
				],
				{
					"min_age": 16,
					"min_smarts": 30
				},
				[
					"Drone Runner",
					"Dispatch Technician",
					"Route Coordinator",
					"Logistics Controller"
				],
				_logistics_activities(),
				(
					"Coordinate autonomous deliveries across cities, "
					+ "habitats, orbital stations, and remote settlements."
				)
			),
			{
				"Future Era": 72000
			}
		)
	)

	_register_path(
		_ordinary_path_with_salary(
			_path(
				"future_nutrifabrication_worker",
				"Nutrifabrication Worker",
				[
					"Future Era"
				],
				"Future Food Fabrication Network",
				"factory",
				"Food Fabrication",
				[
					"Nutrifabrication Worker",
					"Food Printer Operator",
					"Synthetic Food Technician"
				],
				{
					"min_age": 16,
					"min_smarts": 28
				},
				[
					"Food Printer Attendant",
					"Fabrication Operator",
					"Quality Technician",
					"Nutrifabrication Supervisor"
				],
				_factory_activities(),
				(
					"Operate food-printing machinery and protect "
					+ "the quality of a future food supply."
				)
			),
			{
				"Future Era": 70000
			}
		)
	)
func _ordinary_path_with_salary(
	path: Dictionary,
	base_salary_by_era: Dictionary
) -> Dictionary:
	if path.is_empty():
		return {}

	var out: Dictionary = path.duplicate(true)

	out [
		"base_salary_by_era"
	] = base_salary_by_era.duplicate(true)
	out [
		"special_path"
	] = false
	out [
		"external_special_engine_owned"
	] = false
	out [
		"catalog_visibility"
	] = "ordinary"
	out [
		"salary_authority"
	] = ENGINE_SCHEMA

	return out
func _agriculture_activities() -> Array:
	return [
		_activity(
			"maintain_fields",
			"Maintain Fields",
			"Water crops, clear weeds, and protect the growing fields.",
			4,
			4.0,
			1,
			{
				"reliability": 2,
				"efficiency": 1
			},
			"achievements",
			0
		),
		_activity(
			"manage_harvest",
			"Manage Harvest",
			"Coordinate labor and preserve as much of the harvest as possible.",
			6,
			6.0,
			2,
			{
				"leadership": 1,
				"efficiency": 2
			},
			"world_traces",
			0
		),
		_activity(
			"repair_irrigation",
			"Repair Irrigation",
			"Restore a damaged water channel before crops are lost.",
			8,
			8.0,
			2,
			{
				"innovation": 1,
				"reliability": 2
			},
			"world_traces",
			1
		)
	]
func _logistics_activities() -> Array:
	return [
		_activity(
			"organize_cargo",
			"Organize Cargo",
			"Sort, document, and prepare cargo for safe movement.",
			4,
			3.0,
			1,
			{
				"efficiency": 2,
				"reliability": 1
			},
			"achievements",
			0
		),
		_activity(
			"coordinate_route",
			"Coordinate Route",
			"Resolve timing, capacity, and destination conflicts.",
			6,
			5.0,
			2,
			{
				"leadership": 1,
				"efficiency": 2
			},
			"world_traces",
			0
		),
		_activity(
			"recover_delayed_delivery",
			"Recover Delayed Delivery",
			"Rescue an important shipment after its route breaks down.",
			8,
			8.0,
			2,
			{
				"reliability": 2,
				"innovation": 1
			},
			"world_traces",
			1
		)
	]
func _food_service_activities() -> Array:
	return [
		_activity(
			"prepare_service_station",
			"Prepare Service Station",
			"Prepare ingredients, tools, and work surfaces before service.",
			4,
			3.0,
			1,
			{
				"reliability": 1,
				"efficiency": 2
			},
			"achievements",
			0
		),
		_activity(
			"work_service_rush",
			"Work Service Rush",
			"Handle a high-volume service period without losing order accuracy.",
			6,
			7.0,
			2,
			{
				"efficiency": 2,
				"reliability": 1
			},
			"achievements",
			0
		),
		_activity(
			"resolve_customer_order",
			"Resolve Customer Order Problem",
			"Correct a failed order while protecting the customer's trust.",
			7,
			5.0,
			2,
			{
				"kindness": 1,
				"reliability": 2
			},
			"world_traces",
			0
		)
	]
func _grocery_worker_activities() -> Array:
	return [
		_activity(
			"stock_store_shelves",
			"Stock Store Shelves",
			"Move inventory from storage to its correct sales location.",
			4,
			4.0,
			1,
			{
				"efficiency": 2,
				"reliability": 1
			},
			"achievements",
			0
		),
		_activity(
			"run_checkout_lane",
			"Run Checkout Lane",
			"Process customers while maintaining speed and transaction accuracy.",
			6,
			6.0,
			2,
			{
				"reliability": 2,
				"kindness": 1
			},
			"achievements",
			0
		),
		_activity(
			"audit_store_inventory",
			"Audit Store Inventory",
			"Find missing stock, pricing errors, and inventory discrepancies.",
			7,
			5.0,
			2,
			{
				"efficiency": 2,
				"reliability": 2
			},
			"world_traces",
			0
		)
	]
func _painter_activities() -> Array:
	var prepare_pigments: Dictionary = _activity(
		"prepare_pigments",
		"Prepare Pigments",
		"Grind pigments and prepare a stable painting surface.",
		4,
		3.0,
		2,
		{
			"reliability": 1,
			"innovation": 1
		},
		"achievements",
		0
	)

	var paint_commission: Dictionary = _activity(
		"paint_commission",
		"Paint Commission",
		"Create a commissioned painting for a real patron or institution.",
		7,
		6.0,
		3,
		{
			"innovation": 2,
			"reliability": 1
		},
		"achievements",
		1
	)

	paint_commission [
		"career_output_contract"
	] = {
		"output_kind": "painting",
		"category": "Art",
		"name_prefix": "Commissioned Painting",
		"base_value": 140,
		"value_per_performance": 3.0,
		"value_per_smarts": 1.5,
		"value_per_reputation": 1.8,
		"value_variance": 90
	}

	var paint_masterwork: Dictionary = _activity(
		"paint_masterwork",
		"Paint Masterwork",
		"Attempt a work that may outlive both artist and patron.",
		10,
		10.0,
		4,
		{
			"innovation": 3,
			"reliability": 1
		},
		"world_traces",
		2
	)

	paint_masterwork [
		"career_output_contract"
	] = {
		"output_kind": "painting",
		"category": "Art",
		"name_prefix": "Guild Masterwork",
		"base_value": 520,
		"value_per_performance": 7.0,
		"value_per_smarts": 3.0,
		"value_per_reputation": 4.0,
		"value_variance": 340
	}

	return [
		prepare_pigments,
		paint_commission,
		paint_masterwork
	]
func _factory_activities() -> Array:
	return [
		_activity(
			"operate_production_line",
			"Operate Production Line",
			"Maintain production speed without allowing quality to collapse.",
			4,
			5.0,
			1,
			{
				"efficiency": 2,
				"reliability": 1
			},
			"achievements",
			0
		),
		_activity(
			"inspect_production_quality",
			"Inspect Production Quality",
			"Find defects before finished goods leave the institution.",
			6,
			4.0,
			2,
			{
				"reliability": 2,
				"efficiency": 1
			},
			"achievements",
			0
		),
		_activity(
			"repair_production_failure",
			"Repair Production Failure",
			"Restore a failed production process under institutional pressure.",
			8,
			9.0,
			2,
			{
				"innovation": 2,
				"reliability": 2
			},
			"world_traces",
			1
		)
	]
func _photography_activities() -> Array:
	return [
		_activity(
			"prepare_photographic_plate",
			"Prepare Photographic Plate",
			"Prepare equipment and light-sensitive material for a clean exposure.",
			4,
			3.0,
			2,
			{
				"reliability": 1,
				"innovation": 1
			},
			"achievements",
			0
		),
		_activity(
			"complete_portrait_session",
			"Complete Portrait Session",
			"Direct a subject and create a professional portrait.",
			6,
			5.0,
			3,
			{
				"innovation": 2,
				"kindness": 1
			},
			"achievements",
			1
		),
		_activity(
			"document_historic_event",
			"Document Historic Event",
			"Capture an event whose image may become part of public memory.",
			8,
			8.0,
			3,
			{
				"innovation": 2,
				"bravery": 1
			},
			"world_traces",
			1
		)
	]
func _customer_support_activities() -> Array:
	return [
		_activity(
			"resolve_customer_case",
			"Resolve Customer Case",
			"Investigate a customer's problem and deliver a workable resolution.",
			5,
			4.0,
			2,
			{
				"kindness": 1,
				"reliability": 2
			},
			"achievements",
			0
		),
		_activity(
			"deescalate_customer",
			"De-escalate Customer",
			"Calm an escalating interaction without abandoning policy.",
			6,
			6.0,
			2,
			{
				"kindness": 2,
				"leadership": 1
			},
			"achievements",
			0
		),
		_activity(
			"repair_support_process",
			"Repair Support Process",
			"Identify and correct a recurring institutional service failure.",
			8,
			7.0,
			3,
			{
				"innovation": 2,
				"efficiency": 2
			},
			"world_traces",
			1
		)
	]
func _maintenance_activities() -> Array:
	return [
		_activity(
			"inspect_facility_systems",
			"Inspect Facility Systems",
			"Inspect equipment and identify failures before they become emergencies.",
			4,
			3.0,
			1,
			{
				"reliability": 2,
				"efficiency": 1
			},
			"achievements",
			0
		),
		_activity(
			"complete_maintenance_order",
			"Complete Maintenance Order",
			"Repair a live facility problem and return the space to service.",
			6,
			5.0,
			2,
			{
				"reliability": 2,
				"efficiency": 1
			},
			"achievements",
			0
		),
		_activity(
			"restore_critical_system",
			"Restore Critical System",
			"Restore a failed system before it threatens the institution.",
			9,
			9.0,
			3,
			{
				"bravery": 1,
				"reliability": 2,
				"innovation": 1
			},
			"world_traces",
			1
		)
	]
func _sync_provider_backed_access_paths_and_runtime() -> void:
	if gs == null:
		return

	var added_path_ids: Array = []

	if (
		gs.food_restaurant_engine != null
		and gs.food_restaurant_engine.has_method(
			"get_restaurants_for_era"
		)
	):
		for era_name in [
			"Industrial Era",
			"Modern Era",
			"Future Era"
		]:
			var fast_alias_claimed: bool = false
			var restaurant_alias_claimed: bool = false

			var restaurant_rows_raw: Variant = (
				gs.food_restaurant_engine
				.get_restaurants_for_era(
					era_name
				)
			)

			if typeof(
				restaurant_rows_raw
			) != TYPE_ARRAY:
				continue

			for raw_restaurant in (
				restaurant_rows_raw as Array
			):
				if typeof(
					raw_restaurant
				) != TYPE_DICTIONARY:
					continue

				var restaurant: Dictionary = (
					raw_restaurant as Dictionary
				)

				var restaurant_id: String = str(
					restaurant.get(
						"id",
						""
					)
				).strip_edges()

				if restaurant_id == "":
					continue

				var tier: String = str(
					restaurant.get(
						"tier",
						restaurant.get(
							"category",
							"restaurant"
						)
					)
				).strip_edges().to_lower()

				var category: String = str(
					restaurant.get(
						"category",
						tier
					)
				).strip_edges().to_lower()

				var fast_service: bool = (
					tier.contains(
						"fast"
					)
					or category == "fast_food"
				)

				var include_generic_alias: bool = false

				if (
					fast_service
					and not fast_alias_claimed
				):
					fast_alias_claimed = true
					include_generic_alias = true

				elif (
					not fast_service
					and not restaurant_alias_claimed
				):
					restaurant_alias_claimed = true
					include_generic_alias = true

				var provider_path: Dictionary = (
					_provider_backed_restaurant_path(
						restaurant,
						era_name,
						include_generic_alias
					)
				)

				var path_id: String = str(
					provider_path.get(
						"path_id",
						""
					)
				)

				if (
					path_id == ""
					or career_paths.has(
						path_id
					)
				):
					continue

				_register_path(
					provider_path
				)

				added_path_ids.append(
					path_id
				)

	if (
		gs.grocery_store_engine != null
		and gs.grocery_store_engine.has_method(
			"get_stores_for_era"
		)
	):
		for era_name in [
			"Modern Era",
			"Future Era"
		]:
			var generic_grocer_alias_claimed: bool = false

			var store_rows_raw: Variant = (
				gs.grocery_store_engine
				.get_stores_for_era(
					era_name
				)
			)

			if typeof(
				store_rows_raw
			) != TYPE_ARRAY:
				continue

			for raw_store in (
				store_rows_raw as Array
			):
				if typeof(
					raw_store
				) != TYPE_DICTIONARY:
					continue

				var store: Dictionary = (
					raw_store as Dictionary
				)

				var store_id: String = str(
					store.get(
						"id",
						""
					)
				).strip_edges()

				if store_id == "":
					continue

				var include_generic_alias: bool = (
					not generic_grocer_alias_claimed
				)

				if include_generic_alias:
					generic_grocer_alias_claimed = true

				var provider_path: Dictionary = (
					_provider_backed_grocery_path(
						store,
						era_name,
						include_generic_alias
					)
				)

				var path_id: String = str(
					provider_path.get(
						"path_id",
						""
					)
				)

				if (
					path_id == ""
					or career_paths.has(
						path_id
					)
				):
					continue

				_register_path(
					provider_path
				)

				added_path_ids.append(
					path_id
				)

	if added_path_ids.is_empty():
		return

	if (
		gs.career_runtime_engine != null
		and gs.career_runtime_engine.has_method(
			"queue_path_ecosystem_reconciliation"
		)
	):
		gs.career_runtime_engine.queue_path_ecosystem_reconciliation(
			added_path_ids,
			{
				"source": (
					"career_contract_engine."
					+ "provider_backed_path_sync"
				),
				"background_only": true,
				"blocks_ui": false,
				"build_on_click": false,
				"ready_gate_member": false
			}
		)

	set_meta(
		"provider_backed_career_path_count",
		added_path_ids.size()
	)
	set_meta(
		"provider_backed_career_paths_registered_at_ms",
		int(
			Time.get_ticks_msec()
		)
	)
	set_meta(
		"provider_backed_career_paths_block_ui",
		false
	)
func _provider_backed_restaurant_path(
	restaurant: Dictionary,
	era_name: String,
	include_generic_alias: bool
) -> Dictionary:
	var restaurant_id: String = str(
		restaurant.get(
			"id",
			"restaurant"
		)
	).strip_edges()

	var restaurant_name: String = str(
		restaurant.get(
			"name",
			"Restaurant"
		)
	).strip_edges()

	var tier: String = str(
		restaurant.get(
			"tier",
			restaurant.get(
				"category",
				"restaurant"
			)
		)
	).strip_edges().to_lower()

	var category: String = str(
		restaurant.get(
			"category",
			tier
		)
	).strip_edges().to_lower()

	var fast_service: bool = (
		tier.contains(
			"fast"
		)
		or category == "fast_food"
	)

	var role_name: String = (
		"Fast Food Worker"
		if fast_service
		else "Restaurant Worker"
	)

	var aliases: Array = [
		"%s Worker" % restaurant_name,
		"%s Crew Member" % restaurant_name,
		"%s Employee" % restaurant_name
	]

	if include_generic_alias:
		if fast_service:
			aliases.append_array([
				"Fast Food Worker",
				"Fast Food Crew Member"
			])

		else:
			aliases.append_array([
				"Restaurant Worker",
				"Restaurant Server",
				"Server",
				"Line Cook"
			])

	var ranks: Array = (
		[
			"Crew Member",
			"Line Cook",
			"Shift Leader",
			"Assistant Manager",
			"Restaurant Manager"
		]
		if fast_service
		else [
			"Busser",
			"Server",
			"Cook",
			"Shift Lead",
			"Restaurant Manager"
		]
	)

	var path: Dictionary = _path(
		"%s_restaurant_worker_%s" % [
			_slug(
				era_name
			),
			_slug(
				restaurant_id
			)
		],
		"%s at %s" % [
			role_name,
			restaurant_name
		],
		[
			era_name
		],
		restaurant_name,
		"restaurant",
		(
			"Quick Service Operations"
			if fast_service
			else "Restaurant Service"
		),
		aliases,
		{
			"min_age": 14,
			"min_health": 20
		},
		ranks,
		_food_service_activities(),
		(
			"Work inside %s using the restaurant identity, "
			+ "service model, and institutional presence already "
			+ "owned by FoodRestaurantEngine."
		) % restaurant_name
	)

	path [
		"base_salary_by_era"
	] = {
		era_name: _restaurant_worker_base_salary(
			era_name,
			tier,
			fast_service
		)
	}

	path [
		"provider_backed"
	] = true
	path [
		"provider_engine"
	] = "food_restaurant_engine"
	path [
		"provider_contract"
	] = {
		"provider_kind": "restaurant",
		"restaurant_id": restaurant_id,
		"restaurant_name": restaurant_name,
		"tier": tier,
		"category": category,
		"supports_drive_through": bool(
			restaurant.get(
				"supports_drive_through",
				false
			)
		)
	}
	path [
		"special_path"
	] = false

	return path
func _provider_backed_grocery_path(
	store: Dictionary,
	era_name: String,
	include_generic_alias: bool
) -> Dictionary:
	var store_id: String = str(
		store.get(
			"id",
			"grocery_store"
		)
	).strip_edges()

	var store_name: String = str(
		store.get(
			"name",
			"Grocery Store"
		)
	).strip_edges()

	var tier: String = str(
		store.get(
			"tier",
			"standard"
		)
	).strip_edges().to_lower()

	var aliases: Array = [
		"%s Grocer" % store_name,
		"%s Cashier" % store_name,
		"%s Stock Clerk" % store_name,
		"%s Employee" % store_name
	]

	if include_generic_alias:
		aliases.append_array([
			"Grocer",
			"Grocery Worker",
			"Grocery Bagger",
			"Grocery Cashier",
			"Stock Clerk"
		])

	var path: Dictionary = _path(
		"%s_grocery_worker_%s" % [
			_slug(
				era_name
			),
			_slug(
				store_id
			)
		],
		"Grocer at %s" % store_name,
		[
			era_name
		],
		store_name,
		"grocery_store",
		"Store Operations",
		aliases,
		{
			"min_age": 14,
			"min_health": 18
		},
		[
			"Grocery Bagger",
			"Stock Clerk",
			"Cashier",
			"Department Lead",
			"Store Manager"
		],
		_grocery_worker_activities(),
		(
			"Work inside %s using the store identity and inventory "
			+ "authority already owned by GroceryStoreEngine."
		) % store_name
	)

	path [
		"base_salary_by_era"
	] = {
		era_name: _grocery_worker_base_salary(
			era_name,
			tier
		)
	}

	path [
		"provider_backed"
	] = true
	path [
		"provider_engine"
	] = "grocery_store_engine"
	path [
		"provider_contract"
	] = {
		"provider_kind": "grocery_store",
		"store_id": store_id,
		"store_name": store_name,
		"tier": tier
	}
	path [
		"special_path"
	] = false

	return path
func _restaurant_worker_base_salary(
	era_name: String,
	tier: String,
	fast_service: bool
) -> int:
	match era_name:
		"Industrial Era":
			if fast_service:
				return 11000

			if tier.contains(
				"luxury"
			):
				return 18000

			return 14000

		"Future Era":
			if fast_service:
				return 56000

			if tier.contains(
				"luxury"
			):
				return 90000

			return 65000

		_:
			if fast_service:
				return 28000

			if tier.contains(
				"ultra"
			):
				return 52000

			if tier.contains(
				"luxury"
			):
				return 46000

			if tier.contains(
				"premium"
			):
				return 38000

			return 32000
func _grocery_worker_base_salary(
	era_name: String,
	tier: String
) -> int:
	if era_name == "Future Era":
		if tier.contains(
			"premium"
		):
			return 72000

		return 62000

	if tier.contains(
		"premium"
	):
		return 36000

	return 30000
func _career_path_is_external_special(
	path: Dictionary
) -> bool:
	if path.is_empty():
		return false

	if bool(
		path.get(
			"special_path",
			false
		)
	):
		return true

	var identity_values: Array = [
		str(
			path.get(
				"display_name",
				""
			)
		)
	]

	identity_values.append_array(
		_safe_array(
			path.get(
				"aliases",
				[]
			)
		)
	)

	for raw_rank in _safe_array(
		path.get(
			"ranks",
			[]
		)
	):
		var rank: Dictionary = _safe_dictionary(
			raw_rank
		)

		identity_values.append(
			str(
				rank.get(
					"title",
					""
				)
			)
		)

	var external_special_terms: Array = [
		"rapper",
		"singer",
		"musician",
		"music producer",
		"recording artist",
		"pop star",
		"actor",
		"streamer",
		"content creator",
		"influencer",
		"boxer",
		"prizefighter",
		"professional athlete",
		"athlete",
		"stage performer",
		"worldstream idol",
		"holo star"
	]

	for raw_identity in identity_values:
		var identity_key: String = _normalize_lookup_key(
			str(
				raw_identity
			)
		)

		if identity_key == "":
			continue

		for raw_special_term in external_special_terms:
			var special_key: String = _normalize_lookup_key(
				str(
					raw_special_term
				)
			)

			if (
				identity_key == special_key
				or identity_key.contains(
					special_key
				)
			):
				return true

	return false
func _register_ancient_paths() -> void:
	_register_path(
		_path(
			"ancient_temple_scribe",
			"Temple Scribe",
			["Ancient Era"],
			"Temple and Royal Archive System",
			"archive",
			"Records and State Memory",
			[
				"Scribe",
				"Temple Attendant",
				"Scholar",
				"Tax Collector",
				"Papyrus Maker"
			],
			{
				"min_age": 16,
				"min_smarts": 48,
				"historical_programs_any": [
					"Temple School",
					"Scholar House",
					"Philosophy Academy",
					"Priestly College"
				]
			},
			[
				"Assistant Scribe",
				"Temple Scribe",
				"Senior Scribe",
				"Royal Archivist"
			],
			_scribe_activities(),
			(
				"Writing becomes permanent state infrastructure."
			)
		)
	)

	_register_path(
		_medical_path(
			"ancient_physician",
			"Ancient Physician",
			["Ancient Era"],
			[
				"Herbal Healer",
				"Midwife",
				"Priest"
			],
			{
				"min_age": 16,
				"min_smarts": 52,
				"historical_programs_any": [
					"Temple School",
					"Priestly College",
					"Philosophy Academy"
				]
			},
			[
				"Healer's Apprentice",
				"Herbal Healer",
				"Temple Physician",
				"Royal Physician"
			]
		)
	)

	_register_path(
		_craft_path(
			"ancient_bronze_smith",
			"Bronze Smith",
			["Ancient Era"],
			[
				"Bronze Smith",
				"Copper Smith",
				"Chariot Maker",
				"Jeweler"
			],
			"Bronze and Metal Guild"
		)
	)

	_register_path(
		_military_path(
			"ancient_legion",
			"Ancient Legion",
			["Ancient Era"],
			[
				"Soldier",
				"Royal Guard",
				"Charioteer"
			],
			[
				"Recruit",
				"Soldier",
				"Centurion",
				"Tribune",
				"General"
			]
		)
	)

	_register_path(
		_merchant_path(
			"ancient_caravan_trade",
			"Caravan Trade",
			["Ancient Era"],
			[
				"Caravan Merchant",
				"Metal Trader",
				"Tax Collector"
			],
			[
				"Market Runner",
				"Trader",
				"Caravan Master",
				"Trade Elder"
			]
		)
	)
	_register_path(
		_path(
			"ancient_palace_service",
			"Palace Servant",
			[
				"Ancient Era"
			],
			"Royal Household",
			"palace",
			"Household Service",
			[
				"Palace Servant",
				"Royal Servant",
				"Household Attendant",
				"Chamber Attendant"
			],
			{
				"min_age": 14
			},
			[
				"Household Attendant",
				"Palace Servant",
				"Senior Palace Servant",
				"Household Steward"
			],
			_palace_servant_activities(),
			(
				"Service inside a royal household where reliability, "
				+ "protocol, and proximity to court shape advancement."
			)
		)
	)
func _register_medieval_paths() -> void:
	_register_path(
		_military_path(
			"medieval_knighthood",
			"Order of Knighthood",
			["Medieval Era"],
			[
				"Page",
				"Squire",
				"Knight",
				"Royal Guard",
				"Town Guard"
			],
			[
				"Page",
				"Squire",
				"Knight",
				"Knight Commander",
				"Marshal",
				"General"
			],
			{
				"min_age": 10,
				"min_health": 55,
				"historical_programs_any": [
					"Knight Hall",
					"Court Education",
					"Military Academy"
				]
			}
		)
	)

	_register_path(
		_path(
			"medieval_monastic_scholar",
			"Monastic Scholarship",
			["Medieval Era"],
			"Monastic and Cathedral Learning",
			"monastery",
			"Scriptorium and Theology",
			[
				"Monk",
				"Nun",
				"Abbey Scholar",
				"Priest"
			],
			{
				"min_age": 14,
				"min_smarts": 48,
				"historical_programs_any": [
					"Monastic School",
					"Abbey School",
					"Cathedral School"
				]
			},
			[
				"Novice",
				"Monk",
				"Scholar",
				"Prior",
				"Abbot"
			],
			_scholar_activities(),
			(
				"A monastery becomes an education, archive, and political institution."
			)
		)
	)

	_register_path(
		_craft_path(
			"medieval_blacksmith_guild",
			"Blacksmith Guild",
			["Medieval Era"],
			[
				"Apprentice Blacksmith",
				"Blacksmith",
				"Armorer",
				"Swordsmith"
			],
			"Guild Forge"
		)
	)

	_register_path(
		_merchant_path(
			"medieval_merchant_guild",
			"Merchant Guild",
			["Medieval Era"],
			[
				"Merchant",
				"Shopkeeper",
				"Innkeeper"
			],
			[
				"Apprentice Merchant",
				"Merchant",
				"Guild Merchant",
				"Guild Master"
			]
		)
	)

	_register_path(
		_medical_path(
			"medieval_physician",
			"Medieval Medicine",
			["Medieval Era"],
			[
				"Village Healer",
				"Herbalist"
			],
			{
				"min_age": 16,
				"min_smarts": 50,
				"historical_programs_any": [
					"Monastic School",
					"Cathedral School",
					"Guild College"
				]
			},
			[
				"Apprentice Healer",
				"Barber-Surgeon",
				"Physician",
				"Court Physician"
			]
		)
	)
func _register_industrial_paths() -> void:
	_register_path(
		_nursing_path(
			"industrial_nursing",
			["Industrial Era"],
			["Nurse"]
		)
	)

	_register_path(
		_physician_path(
			"industrial_physician",
			"Industrial Physician",
			["Industrial Era"],
			["Doctor"],
			"General Medicine",
			["Medical School"]
		)
	)

	_register_path(
		_engineering_path(
			"industrial_engineering",
			"Industrial Engineering",
			["Industrial Era"],
			[
				"Rail Engineer",
				"Inventor",
				"Mechanic",
				"Electrician",
				"Machinist"
			],
			[
				"Engineering",
				"Mechanical Engineering",
				"Electrical Engineering",
				"Chemistry"
			]
		)
	)

	_register_path(
		_law_path(
			"industrial_law",
			"Industrial Law",
			["Industrial Era"],
			[
				"Detective",
				"Police Constable"
			],
			[
				"Law",
				"Political Science",
				"Criminal Justice"
			]
		)
	)

	_register_path(
		_teaching_path(
			"industrial_teaching",
			"Industrial Teaching",
			["Industrial Era"],
			["Schoolteacher"],
			[
				"Teaching",
				"Education",
				"History",
				"Literature"
			]
		)
	)

	_register_path(
		_finance_path(
			"industrial_accounting",
			"Industrial Accounting",
			["Industrial Era"],
			[
				"Bookkeeper",
				"Bank Clerk",
				"Office Typist",
				"Secretary"
			],
			[
				"Accounting",
				"Finance",
				"Business"
			]
		)
	)
	_register_path(
		_brain_surgery_path(
			"industrial_brain_surgery",
			"Industrial Brain Surgery",
			[
				"Industrial Era"
			],
			false
		)
	)
func _register_modern_paths() -> void:
	_register_path(
		_nursing_path(
			"modern_nursing",
			["Modern Era"],
			[
				"Nurse",
				"Paramedic"
			]
		)
	)

	var specialties: Array = [
		["family_medicine", "Family Medicine"],
		["emergency_medicine", "Emergency Medicine"],
		["cardiology", "Cardiology"],
		["neurology", "Neurology"],
		["pediatrics", "Pediatrics"],
		["psychiatry", "Psychiatry"],
		["orthopedics", "Orthopedics"],
		["dermatology", "Dermatology"],
		["oncology", "Oncology"],
		["radiology", "Radiology"],
		["anesthesiology", "Anesthesiology"]
	]

	for row in specialties:
		_register_path(
			_physician_path(
				"modern_%s" % str(row [0]),
				str(row [1]),
				["Modern Era"],
				[
					"Doctor",
					"Physician",
					str(row [1])
				],
				str(row [1]),
				["Medical School"]
			)
		)

	_register_path(
		_engineering_path(
			"modern_software",
			"Software Engineering",
			["Modern Era"],
			[
				"Software Developer",
				"Game Developer"
			],
			[
				"Computer Science",
				"Software Engineering",
				"Information Systems",
				"Mathematics"
			]
		)
	)

	_register_path(
		_law_path(
			"modern_law",
			"Modern Law",
			["Modern Era"],
			[
				"Lawyer",
				"Judge",
				"Police Officer",
				"Detective"
			],
			[
				"Law",
				"Political Science",
				"Criminal Justice"
			]
		)
	)

	_register_path(
		_teaching_path(
			"modern_teaching",
			"Modern Education",
			["Modern Era"],
			[
				"Teacher",
				"Professor"
			],
			[
				"Education",
				"Teaching",
				"History",
				"Literature",
				"Psychology"
			]
		)
	)

	_register_path(
		_finance_path(
			"modern_finance",
			"Finance and Accounting",
			["Modern Era"],
			[
				"Accountant",
				"Financial Analyst",
				"Bank Teller",
				"Manager"
			],
			[
				"Finance",
				"Accounting",
				"Economics",
				"Business"
			]
		)
	)

	_register_path(
		_engineering_path(
			"modern_architecture",
			"Architecture",
			["Modern Era"],
			[
				"Architect",
				"Construction Worker",
				"Graphic Designer"
			],
			[
				"Architecture",
				"Civil Engineering",
				"Design"
			]
		)
	)

	_register_path(
		_research_path(
			"modern_science",
			"Scientific Research",
			["Modern Era"],
			[
				"Scientist",
				"Pharmacist"
			],
			[
				"Biology",
				"Chemistry",
				"Physics",
				"Mathematics",
				"Psychology"
			]
		)
	)
	_register_path(
		_brain_surgery_path(
			"modern_brain_surgery",
			"Brain Surgery",
			[
				"Modern Era"
			],
			false
		)
	)
func _register_future_paths() -> void:
	var future_specs: Array = [
		[
			"future_mars_terraformer",
			"Mars Terraformer",
			"Terraforming Authority",
			"Planetary Engineering",
			[
				"Terraformer",
				"Mars Habitat Planner",
				"Planetary Surveyor"
			],
			[
				"Planetary Engineering",
				"Climate Synthesis",
				"Synthetic Biology"
			],
			"world_traces",
			false
		],
		[
			"future_orbital_architect",
			"Orbital Architect",
			"Orbital Habitat Directorate",
			"Habitat Design",
			[
				"Orbital Architect",
				"Lunar Construction Worker",
				"Mars Habitat Planner"
			],
			[
				"Planetary Engineering",
				"Orbital Logistics",
				"Neural Architecture"
			],
			"buildings_created",
			false
		],
		[
			"future_gravity_engineer",
			"Gravity Engineer",
			"Gravity Systems Institute",
			"Gravity Systems",
			[
				"Gravity Engineer",
				"Gravity Systems Technician"
			],
			[
				"Quantum Systems",
				"Planetary Engineering",
				"Temporal Physics"
			],
			"patents_created",
			false
		],
		[
			"future_consciousness_auditor",
			"Consciousness Auditor",
			"Consciousness Standards Commission",
			"Consciousness Integrity",
			[
				"Consciousness Auditor",
				"Consciousness Archivist",
				"Android Psychologist"
			],
			[
				"Artificial Consciousness",
				"Neural Architecture",
				"AI Ethics"
			],
			"cases_won",
			false
		],
		[
			"future_quantum_navigator",
			"Quantum Navigator",
			"Interstellar Navigation Authority",
			"Quantum Navigation",
			[
				"Quantum Navigator",
				"Stellar Cartographer",
				"Orbital Traffic Controller"
			],
			[
				"Quantum Systems",
				"Orbital Logistics",
				"Temporal Physics"
			],
			"discoveries",
			false
		],
		[
			"future_ai_ethics_commissioner",
			"AI Ethics Commissioner",
			"Artificial Consciousness Commission",
			"AI Ethics and Rights",
			[
				"AI Ethics Commissioner",
				"Robot Rights Lawyer",
				"AI Therapist"
			],
			[
				"Artificial Consciousness",
				"AI Ethics",
				"Law"
			],
			"world_traces",
			true
		],
		[
			"future_planetary_governor",
			"Planetary Governor",
			"Planetary Government",
			"Executive Administration",
			[
				"Planetary Governor",
				"Off-World Diplomat"
			],
			[
				"Planetary Governance",
				"Orbital Logistics",
				"AI Ethics"
			],
			"world_traces",
			true
		],
		[
			"future_climate_synthesist",
			"Climate Synthesist",
			"Climate Synthesis Agency",
			"Climate Engineering",
			[
				"Climate Synthesist",
				"Climate Dome Engineer",
				"Atmosphere Technician"
			],
			[
				"Planetary Engineering",
				"Climate Synthesis",
				"Synthetic Biology"
			],
			"world_traces",
			false
		],
		[
			"future_reality_stability_technician",
			"Reality Stability Technician",
			"Reality Stability Directorate",
			"Reality Integrity",
			[
				"Reality Stability Technician",
				"Quantum Programmer",
				"Teleportation Safety Inspector"
			],
			[
				"Reality Computing",
				"Temporal Physics",
				"Quantum Systems"
			],
			"world_traces",
			false
		],
		[
			"future_nano_technician",
			"Nano Technician",
			"Nanotechnology Fabrication Network",
			"Nanofabrication",
			[
				"Nano Technician",
				"Nanobot Mechanic",
				"Nanotech Surgeon"
			],
			[
				"Nanotechnology",
				"Synthetic Biology",
				"Quantum Systems"
			],
			"patents_created",
			false
		],
		[
			"future_neural_architect",
			"Neural Architect",
			"Neural Architecture Consortium",
			"Neural Systems",
			[
				"Neural Architect",
				"Neural Interface Developer",
				"Memory Architect"
			],
			[
				"Neural Architecture",
				"Artificial Consciousness",
				"Reality Computing"
			],
			"patents_created",
			false
		]
	]

	for spec in future_specs:
		_register_path(
			_future_path(
				str(spec [0]),
				str(spec [1]),
				str(spec [2]),
				str(spec [3]),
				_safe_array(spec [4]),
				_safe_array(spec [5]),
				str(spec [6]),
				bool(spec [7])
			)
		)

	_register_path(
		_future_medical_path(
			"future_memory_surgeon",
			"Memory Surgeon",
			"Neural Medicine",
			[
				"Memory Surgeon",
				"Memory Architect",
				"Nanotech Surgeon"
			],
			[
				"Neural Architecture",
				"Interstellar Medicine"
			],
			[
				"Interstellar Medical School",
				"Neural Surgery Residency"
			],
			"patients_saved"
		)
	)

	_register_path(
		_future_medical_path(
			"future_synthetic_organ_designer",
			"Synthetic Organ Designer",
			"Biofabrication",
			[
				"Synthetic Organ Designer",
				"Biofabrication Specialist",
				"Genetic Sculptor"
			],
			[
				"Synthetic Biology",
				"Nanotechnology"
			],
			[
				"Interstellar Medical School",
				"Biofabrication Residency"
			],
			"patents_created"
		)
	)
	_register_path(
		_future_nursing_path()
	)

	_register_path(
		_brain_surgery_path(
			"future_brain_surgery",
			"Neural Brain Surgery",
			[
				"Future Era"
			],
			true
		)
	)
func _actor_social_class_tier(
	actor: Person
) -> int:
	if actor == null:
		return -1

	match str(
		actor.social_class
	).strip_edges().to_lower():
		"slave":
			return 0

		"peasant", "serf", "lower":
			return 1

		"commoner", "artisan", "working":
			return 2

		"merchant", "professional", "middle":
			return 3

		"noble", "elite", "upper", "gentry":
			return 4

		"royal", "sovereign":
			return 5

		_:
			return 2


func _historical_social_class_contract(
	actor: Person,
	path: Dictionary,
	era_name: String
) -> Dictionary:
	if era_name not in [
		"Ancient Era",
		"Medieval Era"
	]:
		return {
			"governed": false,
			"group": "",
			"minimum_tier": 0,
			"actor_tier": (
				_actor_social_class_tier(
					actor
				)
			),
			"eligible": true,
			"sort_order": 0
		}

	var path_id: String = str(
		path.get(
			"path_id",
			""
		)
	)

	var group: String = "COMMON OCCUPATIONS"
	var minimum_tier: int = 1
	var sort_order: int = 40

	match path_id:
		"ancient_palace_service":
			group = "PALACE & HOUSEHOLD SERVICE"
			minimum_tier = 0
			sort_order = 10

		"ancient_bronze_smith":
			group = "CRAFT & COMMON SERVICE"
			minimum_tier = 1
			sort_order = 20

		"ancient_legion":
			group = "MILITARY SERVICE"
			minimum_tier = 1
			sort_order = 30

		"ancient_temple_scribe", \
"ancient_physician":
			group = "LEARNED & TEMPLE SERVICE"
			minimum_tier = 2
			sort_order = 40

		"ancient_caravan_trade":
			group = "MERCHANT CLASS"
			minimum_tier = 3
			sort_order = 50

		"medieval_blacksmith_guild":
			group = "CRAFT & GUILD LABOR"
			minimum_tier = 1
			sort_order = 20

		"medieval_monastic_scholar", \
"medieval_physician":
			group = "CLERICAL & LEARNED SERVICE"
			minimum_tier = 2
			sort_order = 30

		"medieval_merchant_guild":
			group = "MERCHANT & GUILD CLASS"
			minimum_tier = 3
			sort_order = 40

		"medieval_knighthood":
			group = "COURT & NOBLE SERVICE"
			minimum_tier = 4
			sort_order = 50

	var actor_tier: int = (
		_actor_social_class_tier(
			actor
		)
	)

	return {
		"governed": true,
		"group": group,
		"minimum_tier": minimum_tier,
		"actor_tier": actor_tier,
		"actor_social_class": (
			str(actor.social_class)
		),
		"eligible": (
			actor_tier >= minimum_tier
		),
		"sort_order": sort_order
	}
func _path(
	path_id: String,
	display_name: String,
	eras: Array,
	institution: String,
	organization_type: String,
	department: String,
	aliases: Array,
	entry_requirements: Dictionary,
	rank_titles: Array,
	activity_blueprints: Array,
	description: String,
	lane: String = "full_time",
	special_path: bool = false
) -> Dictionary:
	var ranks: Array = []

	for rank_index in range(
		rank_titles.size()
	):
		var rank_activities: Array = []

		if not activity_blueprints.is_empty():
			var visible_activity_count: int = mini(
				activity_blueprints.size(),
				rank_index + 2
			)

			for activity_index in range(
				visible_activity_count
			):
				var activity: Dictionary = (
					_safe_dictionary(
						activity_blueprints [
							activity_index
						]
					)
				)

				if not activity.is_empty():
					rank_activities.append(
						activity
					)

		ranks.append({
			"rank_index": rank_index,
			"title": str(
				rank_titles [
					rank_index
				]
			),
			"min_experience": rank_index * 2,
			"min_performance": mini(
				90,
				42 + rank_index * 9
			),
			"salary_multiplier": (
				1.0
				+ float(rank_index) * 0.42
			),
			"responsibilities": (
				_responsibilities_for_rank(
					display_name,
					str(
						rank_titles [
							rank_index
						]
					),
					rank_index
				)
			),
			"activities": rank_activities,
			"capacity": maxi(
				1,
				5 - rank_index
			),
			"min_reputation": mini(
				82,
				25 + rank_index * 10
			),
			"promotion_threshold": mini(
				92,
				60 + rank_index * 6
			)
		})

	return {
		"path_id": path_id,
		"display_name": display_name,
		"eras": eras.duplicate(true),
		"institution": institution,
		"organization_key": institution,
		"organization_type": organization_type,
		"department": department,
		"aliases": aliases.duplicate(true),
		"entry_requirements": (
			entry_requirements.duplicate(true)
		),
		"ranks": ranks,
		"description": description,
		"lane": lane,
		"special_path": special_path,
		"persistent_institution": true,
		"vacancy_driven": true
	}


func get_path_definition(
	path_or_alias: String
) -> Dictionary:
	var clean_key: String = str(
		path_or_alias
	).strip_edges()

	if clean_key == "":
		return {}

	if career_paths.has(
		clean_key
	):
		return _safe_dictionary(
			career_paths.get(
				clean_key,
				{}
			)
		)

	var resolved_id: String = path_id_for_legacy_job(
		clean_key
	)

	if resolved_id == "":
		return {}

	return _safe_dictionary(
		career_paths.get(
			resolved_id,
			{}
		)
	)


func get_rank_definition(
	path_id: String,
	rank_index: int
) -> Dictionary:
	var path: Dictionary = get_path_definition(
		path_id
	)
	var ranks: Array = _safe_array(
		path.get(
			"ranks",
			[]
		)
	)

	if (
		rank_index < 0
		or rank_index >= ranks.size()
	):
		return {}

	return _safe_dictionary(
		ranks [
			rank_index
		]
	)


func path_id_for_legacy_job(
	job_name: String
) -> String:
	var normalized: String = _normalize_lookup_key(
		job_name
	)

	if normalized == "":
		return ""

	if alias_to_path_id.has(
		normalized
	):
		return str(
			alias_to_path_id.get(
				normalized,
				""
			)
		)

	for raw_path_id in career_paths.keys():
		var path_id: String = str(
			raw_path_id
		)
		var path: Dictionary = _safe_dictionary(
			career_paths.get(
				path_id,
				{}
			)
		)

		if _normalize_lookup_key(
			str(
				path.get(
					"display_name",
					""
				)
			)
		) == normalized:
			return path_id

		for raw_rank in _safe_array(
			path.get(
				"ranks",
				[]
			)
		):
			var rank: Dictionary = _safe_dictionary(
				raw_rank
			)

			if _normalize_lookup_key(
				str(
					rank.get(
						"title",
						""
					)
				)
			) == normalized:
				return path_id

	return ""


func legacy_job_names_for_actor(
	actor: Person,
	lane: String = "full_time"
) -> Array:
	var out: Array = []

	if actor == null or not actor.alive:
		return out

	var era_name: String = _current_era_name()
	var normalized_lane: String = str(
		lane
	).strip_edges().to_lower()

	for raw_path_id in career_paths.keys():
		var path: Dictionary = _safe_dictionary(
			career_paths.get(
				raw_path_id,
				{}
			)
		)

		if era_name not in _safe_array(
			path.get(
				"eras",
				[]
			)
		):
			continue

		if str(
			path.get(
				"lane",
				"full_time"
			)
		).to_lower() != normalized_lane:
			continue

		var aliases: Array = _safe_array(
			path.get(
				"aliases",
				[]
			)
		)
		var display_name: String = str(
			path.get(
				"display_name",
				"Career"
			)
		).strip_edges()
		var listing_name: String = display_name

		if not aliases.is_empty():
			listing_name = str(
				aliases [0]
			).strip_edges()

		if (
			listing_name != ""
			and listing_name not in out
		):
			out.append(
				listing_name
			)

	out.sort()

	return out


func describe_available_job(
	actor: Person,
	job_name: String
) -> Dictionary:
	if actor == null:
		return _fail(
			"missing_actor"
		)

	var path_id: String = path_id_for_legacy_job(
		job_name
	)

	if path_id == "":
		return _fail(
			"career_path_not_found",
			{
				"job_name": job_name
			}
		)

	var path: Dictionary = get_path_definition(
		path_id
	)
	var entry_rank: Dictionary = get_rank_definition(
		path_id,
		0
	)
	var requirements: Dictionary = (
		evaluate_entry_requirements(
			actor,
			path,
			entry_rank
		)
	)
	var ranks: Array = _safe_array(
		path.get(
			"ranks",
			[]
		)
	)
	var rank_names: Array = []

	for raw_rank in ranks:
		var rank: Dictionary = _safe_dictionary(
			raw_rank
		)
		var rank_title: String = str(
			rank.get(
				"title",
				""
			)
		).strip_edges()

		if rank_title != "":
			rank_names.append(
				rank_title
			)

	var organization_name: String = str(
		path.get(
			"institution",
			"Institution"
		)
	)
	var department_name: String = str(
		path.get(
			"department",
			"General"
		)
	)
	var path_type: String = (
		"Special institutional path"
		if bool(
			path.get(
				"special_path",
				false
			)
		)
		else "Open professional path"
	)
	var text: String = (
		"%s\n\n"
		+ "Institution: %s\n"
		+ "Department: %s\n"
		+ "Era: %s\n"
		+ "Path: %s\n"
		+ "Eligibility: %s\n"
		+ "Ranks: %s\n\n%s"
	) % [
		str(
			path.get(
				"display_name",
				job_name
			)
		).to_upper(),
		organization_name,
		department_name,
		_current_era_name(),
		path_type,
		str(
			requirements.get(
				"summary",
				"Requirements unresolved."
			)
		),
		" → ".join(
			PackedStringArray(
				rank_names
			)
		),
		str(
			path.get(
				"description",
				""
			)
		)
	]

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"path_id": path_id,
		"job_name": job_name,
		"career_name": str(
			path.get(
				"display_name",
				job_name
			)
		),
		"organization_name": organization_name,
		"department_name": department_name,
		"requirements": requirements,
		"text": text,
		"popup_title": str(
			path.get(
				"display_name",
				job_name
			)
		).to_upper(),
		"popup_text": text,
		"ui_is_renderer_only": true
	}


func apply_for_legacy_job(
	actor: Person,
	job_name: String,
	lane: String = "full_time",
	context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _fail(
			"missing_actor",
			context
		)

	if not actor.alive:
		return _fail(
			"actor_not_alive",
			context
		)

	if (
		gs == null
		or gs.career_runtime_engine == null
	):
		return _fail(
			"career_runtime_unavailable",
			context
		)

	if not (
		gs.career_runtime_engine
		.assignment_for_actor(
			actor
		)
		.is_empty()
	):
		return _fail(
			"actor_already_employed",
			context
		)

	var path_id: String = path_id_for_legacy_job(
		job_name
	)

	if path_id == "":
		path_id = ensure_legacy_fallback_path(
			job_name,
			lane
		)

	if path_id == "":
		return _fail(
			"career_path_not_found",
			{
				"job_name": job_name
			}
		)

	gs.career_runtime_engine.ensure_world_ecosystem({
		"source": (
			"career_contract_engine.apply_for_legacy_job"
		)
	})

	var selected_position: Dictionary = {}

	for raw_position in (
		gs.career_runtime_engine
		.open_positions_for_actor(
			actor,
			lane
		)
	):
		var position: Dictionary = _safe_dictionary(
			raw_position
		)

		if str(
			position.get(
				"path_id",
				""
			)
		) != path_id:
			continue

		if int(
			position.get(
				"rank_index",
				0
			)
		) != 0:
			continue

		selected_position = position
		break

	if (
		selected_position.is_empty()
		and gs.career_runtime_engine.has_method(
			"ensure_vacant_position_for_path"
		)
	):
		selected_position = (
			gs.career_runtime_engine
			.ensure_vacant_position_for_path(
				path_id,
				0,
				false
			)
		)

	if selected_position.is_empty():
		return {
			"success": false,
			"type": "career_application_no_vacancy",
			"text": (
				"That profession exists, but no entry position "
				+ "is currently vacant."
			),
			"path_id": path_id,
		}

	return evaluate_application(
		actor,
		str(
			selected_position.get(
				"position_id",
				""
			)
		),
		context
	)


func perform_activity(
	actor: Person,
	activity_id: String,
	context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _fail(
			"missing_actor",
			context
		)

	if (
		gs == null
		or gs.career_runtime_engine == null
	):
		return _fail(
			"career_runtime_unavailable",
			context
		)

	var assignment: Dictionary = (
		gs.career_runtime_engine
		.assignment_for_actor(
			actor
		)
	)

	if assignment.is_empty():
		return _fail(
			"actor_has_no_active_position",
			context
		)

	var rank: Dictionary = get_rank_definition(
		str(
			assignment.get(
				"path_id",
				""
			)
		),
		int(
			assignment.get(
				"rank_index",
				0
			)
		)
	)
	var activities: Array = _safe_array(
		rank.get(
			"activities",
			[]
		)
	)

	if activities.is_empty():
		return _fail(
			"rank_has_no_professional_activities",
			context
		)

	var selected: Dictionary = {}
	var normalized_id: String = str(
		activity_id
	).strip_edges().to_lower()

	for raw_activity in activities:
		var activity: Dictionary = _safe_dictionary(
			raw_activity
		)

		if (
			normalized_id == ""
			or str(
				activity.get(
					"id",
					""
				)
			).to_lower() == normalized_id
		):
			selected = activity
			break

	if selected.is_empty():
		return _fail(
			"activity_not_found",
			{
				"activity_id": activity_id
			}
		)

	return (
		gs.career_runtime_engine
		.commit_activity(
			actor,
			selected,
			context
		)
	)


func evaluate_raise(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _fail(
			"missing_actor",
			context
		)

	if (
		gs == null
		or gs.career_runtime_engine == null
	):
		return _fail(
			"career_runtime_unavailable",
			context
		)

	var assignment: Dictionary = (
		gs.career_runtime_engine
		.assignment_for_actor(
			actor
		)
	)

	if assignment.is_empty():
		return _fail(
			"actor_has_no_active_position",
			context
		)

	var profile: Dictionary = (
		gs.career_runtime_engine
		.ensure_actor_profile(
			actor
		)
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
	var reputation: int = (
		_professional_reputation_score(
			profile
		)
	)
	var current_salary: int = int(
		assignment.get(
			"salary",
			actor.income
		)
	)
	var review_score: int = clampi(
		int(
			round(
				float(
					performance
				) * 0.52
			)
		)
		+ int(
			round(
				float(
					reputation
				) * 0.28
			)
		)
		+ mini(
			experience * 3,
			20
		),
		0,
		100
	)
	var threshold: int = 67

	if review_score < threshold:
		return {
			"success": false,
			"type": "career_raise_denied",
			"text": (
				"The organization denied my raise request."
			),
			"review_score": review_score,
			"threshold": threshold
		}

	var increase_percent: float = clampf(
		0.03
		+ (
			float(
				review_score
				- threshold
			)
			/ 100.0
		),
		0.03,
		0.14
	)
	var new_salary: int = maxi(
		current_salary + 1,
		int(
			round(
				float(
					current_salary
				)
				* (
					1.0
					+ increase_percent
				)
			)
		)
	)

	return (
		gs.career_runtime_engine
		.commit_raise(
			actor,
			new_salary,
			{
				"source": str(
					context.get(
						"source",
						"career_raise_review"
					)
				),
				"review_score": review_score,
				"threshold": threshold,
				"increase_percent": increase_percent
			}
		)
	)


func evaluate_entry_requirements(
	actor: Person,
	path: Dictionary,
	rank: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return {
			"eligible": false,
			"summary": "No applicant exists.",
			"missing": [
				"Applicant"
			],
			"requirement_lines": [
				"Applicant unavailable"
			]
		}

	var requirements: Dictionary = _safe_dictionary(
		path.get(
			"entry_requirements",
			{}
		)
	)
	var missing: Array = []
	var lines: Array = []
	var education: Dictionary = {}

	if (
		gs != null
		and gs.school_engine != null
		and gs.school_engine.has_method(
			"emit_career_education_contract"
		)
	):
		education = (
			gs.school_engine
			.emit_career_education_contract(
				actor,
				{
					"source": (
						"career_contract_engine.evaluate_entry_requirements"
					)
				}
			)
		)

	var default_min_age: int = (
		18
		if str(
			path.get(
				"lane",
				"full_time"
			)
		) == "full_time"
		else 14
	)
	var min_age: int = int(
		requirements.get(
			"min_age",
			default_min_age
		)
	)
	var min_smarts: int = int(
		requirements.get(
			"min_smarts",
			0
		)
	)
	var min_health: int = int(
		requirements.get(
			"min_health",
			0
		)
	)
	var min_looks: int = int(
		requirements.get(
			"min_looks",
			0
		)
	)

	lines.append(
		"Minimum age: %d"
		% min_age
	)

	if int(actor.age) < min_age:
		missing.append(
			"Age %d+"
			% min_age
		)

	if min_smarts > 0:
		lines.append(
			"Minimum smarts: %d"
			% min_smarts
		)

		if int(actor.smarts) < min_smarts:
			missing.append(
				"Smarts %d+"
				% min_smarts
			)

	if min_health > 0:
		lines.append(
			"Minimum health: %d"
			% min_health
		)

		if int(actor.health) < min_health:
			missing.append(
				"Health %d+"
				% min_health
			)

	if min_looks > 0:
		lines.append(
			"Minimum looks: %d"
			% min_looks
		)

		if int(actor.looks) < min_looks:
			missing.append(
				"Looks %d+"
				% min_looks
			)

	var required_majors: Array = _safe_array(
		requirements.get(
			"majors_any",
			requirements.get(
				"required_majors_any",
				[]
			)
		)
	)

	if not required_majors.is_empty():
		var completed_majors: Array = _safe_array(
			education.get(
				"completed_majors",
				[]
			)
		)
		var major_met: bool = _contains_any_string(
			completed_majors,
			required_majors
		)

		lines.append(
			"Completed 4-year college major: %s"
			% " or ".join(
				PackedStringArray(
					required_majors
				)
			)
		)

		if not major_met:
			missing.append(
				"Required completed 4-year college major"
			)

	var required_programs: Array = _safe_array(
		requirements.get(
			"graduate_programs_any",
			requirements.get(
				"graduate_schools_any",
				[]
			)
		)
	)

	if not required_programs.is_empty():
		var completed_programs: Array = _safe_array(
			education.get(
				"graduate_schools",
				[]
			)
		)
		var program_met: bool = _contains_any_string(
			completed_programs,
			required_programs
		)

		lines.append(
			"Completed professional school: %s"
			% " or ".join(
				PackedStringArray(
					required_programs
				)
			)
		)

		if not program_met:
			missing.append(
				"Required professional school"
			)

	var historical_programs: Array = _safe_array(
		requirements.get(
			"historical_programs_any",
			[]
		)
	)

	if not historical_programs.is_empty():
		var completed_historical: Array = _safe_array(
			education.get(
				"historical_programs",
				[]
			)
		)
		var historical_met: bool = _contains_any_string(
			completed_historical,
			historical_programs
		)

		lines.append(
			"Era education: %s"
			% " or ".join(
				PackedStringArray(
					historical_programs
				)
			)
		)

		if not historical_met:
			missing.append(
				"Required era education or apprenticeship"
			)

	var era_name: String = _current_era_name()
	var social_class_contract: Dictionary = (
		_historical_social_class_contract(
			actor,
			path,
			era_name
		)
	)

	if bool(
		social_class_contract.get(
			"governed",
			false
		)
	):
		var social_class_group: String = str(
			social_class_contract.get(
				"group",
				""
			)
		)
		var social_class_eligible: bool = bool(
			social_class_contract.get(
				"eligible",
				false
			)
		)

		lines.append(
			"Social class track: %s"
			% social_class_group
		)
		lines.append(
			"Your social class: %s"
			% str(
				actor.social_class
			)
		)

		if not social_class_eligible:
			missing.append(
				"Social class access to %s"
				% social_class_group
			)

	var min_experience: int = 0
	var min_performance: int = 0
	var min_reputation: int = 0
	var rank_index: int = 0

	if not rank.is_empty():
		min_experience = int(
			rank.get(
				"min_experience",
				0
			)
		)
		min_performance = int(
			rank.get(
				"min_performance",
				0
			)
		)
		min_reputation = int(
			rank.get(
				"min_reputation",
				0
			)
		)
		rank_index = int(
			rank.get(
				"rank_index",
				0
			)
		)

	var profile: Dictionary = {}

	if (
		gs != null
		and gs.career_runtime_engine != null
		and gs.career_runtime_engine.has_method(
			"resident_actor_profile"
		)
	):
		profile = (
			gs.career_runtime_engine
			.resident_actor_profile(
				actor
			)
		)

	if min_experience > 0:
		lines.append(
			"Experience: %d+"
			% min_experience
		)

		if int(actor.job_experience) < min_experience:
			missing.append(
				"Professional experience %d+"
				% min_experience
			)

	if (
		min_performance > 0
		and rank_index > 0
	):
		lines.append(
			"Performance: %d+"
			% min_performance
		)

		if int(actor.job_performance) < min_performance:
			missing.append(
				"Performance %d+"
				% min_performance
			)

	if (
		min_reputation > 0
		and rank_index > 0
	):
		lines.append(
			"Professional reputation: %d+"
			% min_reputation
		)

		if _professional_reputation_score(
			profile
		) < min_reputation:
			missing.append(
				"Professional reputation %d+"
				% min_reputation
			)

	var eligible: bool = (
		missing.is_empty()
	)
	var summary: String = (
		"Requirements met."
		if eligible
		else (
			"Missing: %s."
			% ", ".join(
				PackedStringArray(
					missing
				)
			)
		)
	)

	return {
		"eligible": eligible,
		"qualification_eligible": eligible,
		"missing": missing,
		"summary": summary,
		"requirement_lines": lines,
		"education_contract": education,
		"special_path": bool(
			path.get(
				"special_path",
				false
			)
		),

		"social_class_governed": bool(
			social_class_contract.get(
				"governed",
				false
			)
		),
		"social_class_group": str(
			social_class_contract.get(
				"group",
				""
			)
		),
		"social_class_min_tier": int(
			social_class_contract.get(
				"minimum_tier",
				0
			)
		),
		"actor_social_class": str(
			actor.social_class
		),
		"actor_social_class_tier": int(
			social_class_contract.get(
				"actor_tier",
				_actor_social_class_tier(
					actor
				)
			)
		),
		"social_class_eligible": bool(
			social_class_contract.get(
				"eligible",
				true
			)
		),
		"social_class_sort_order": int(
			social_class_contract.get(
				"sort_order",
				0
			)
		)
	}
func emit_panel_contract(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _observable_partial_panel(
			actor,
			context
		)

	if (
		gs == null
		or gs.career_runtime_engine == null
	):
		return _observable_partial_panel(
			actor,
			context
		)




	var assignment: Dictionary = (
		gs.career_runtime_engine
		.assignment_for_actor(
			actor
		)
	)
	var organization: Dictionary = (
		gs.career_runtime_engine
		.organization_for_actor(
			actor
		)
	)
	var position: Dictionary = (
		gs.career_runtime_engine
		.position_for_actor(
			actor
		)
	)
	var profile: Dictionary = (
		gs.career_runtime_engine
		.resident_actor_profile(
			actor
		)
	)
	var education: Dictionary = {}

	if (
		gs.school_engine != null
		and gs.school_engine.has_method(
			"emit_career_education_contract"
		)
	):
		education = (
			gs.school_engine
			.emit_career_education_contract(
				actor,
				{
					"source": (
						"career_contract_engine.emit_panel_contract"
					)
				}
			)
		)

	var active_section: String = str(
		context.get(
			"active_section",
			"overview"
		)
	).strip_edges().to_lower()

	if active_section == "":
		active_section = "overview"

	var overview_cards: Array = []
	var activity_rows: Array = []
	var opportunity_rows: Array = []
	var organization_rows: Array = []
	var education_rows: Array = []
	var reputation_rows: Array = []
	var legacy_rows: Array = []
	var actions: Array = []

	if assignment.is_empty():
		overview_cards.append({
			"title": "Not Currently Employed",
			"description": (
				"Careers are institutional positions. Apply to a "
				+ "real vacancy to enter a profession."
			),
			"lines": [
				"Applications recorded: %d"
				% _safe_array(
					profile.get(
						"application_ids",
						[]
					)
				).size(),
				"Professional reputation: %d"
				% _professional_reputation_score(
					profile
				)
			]
		})
	else:
		var path_id: String = str(
			assignment.get(
				"path_id",
				""
			)
		)
		var path: Dictionary = get_path_definition(
			path_id
		)
		var rank: Dictionary = get_rank_definition(
			path_id,
			int(
				assignment.get(
					"rank_index",
					0
				)
			)
		)

		overview_cards.append({
			"title": str(
				assignment.get(
					"rank_title",
					actor.job
				)
			),
			"description": str(
				path.get(
					"description",
					(
						"A living professional role inside a "
						+ "persistent institution."
					)
				)
			),
			"lines": [
				"Organization: %s"
				% str(
					organization.get(
						"name",
						"Institution"
					)
				),
				"Department: %s"
				% str(
					assignment.get(
						"department_name",
						path.get(
							"department",
							"General"
						)
					)
				),
				"Salary: %d"
				% int(
					assignment.get(
						"salary",
						actor.income
					)
				),
				"Performance: %d"
				% int(
					assignment.get(
						"performance",
						actor.job_performance
					)
				),
				"Experience: %d"
				% int(
					assignment.get(
						"experience",
						actor.job_experience
					)
				),
				"Satisfaction: %d"
				% int(
					assignment.get(
						"satisfaction",
						actor.satisfaction
					)
				),
				"Work stress: %d"
				% int(
					round(
						float(
							assignment.get(
								"work_stress",
								actor.work_stress
							)
						)
					)
				)
			]
		})

		for raw_activity in _safe_array(
			rank.get(
				"activities",
				[]
			)
		):
			var activity: Dictionary = _safe_dictionary(
				raw_activity
			)

			activity_rows.append({
				"activity_id": str(
					activity.get(
						"id",
						""
					)
				),
				"label": str(
					activity.get(
						"label",
						"Professional Activity"
					)
				),
				"description": str(
					activity.get(
						"description",
						""
					)
				),
				"impact_lines": [
					"Performance: %+d"
					% int(
						activity.get(
							"performance_delta",
							0
						)
					),
					"Stress: %+d"
					% int(
						round(
							float(
								activity.get(
									"stress_delta",
									0.0
								)
							)
						)
					),
					"Satisfaction: %+d"
					% int(
						activity.get(
							"satisfaction_delta",
							0
						)
					)
				],
				"action_label": str(
					activity.get(
						"action_label",
						"PERFORM"
					)
				),
				"enabled": true
			})

		organization_rows.append({
			"title": str(
				organization.get(
					"name",
					"Institution"
				)
			),
			"description": (
				"%s • %s"
				% [
					str(
						organization.get(
							"organization_type",
							"organization"
						)
					).capitalize(),
					str(
						organization.get(
							"era_name",
							_current_era_name()
						)
					)
				]
			),
			"lines": [
				"Department: %s"
				% str(
					assignment.get(
						"department_name",
						"General"
					)
				),
				"Position ID: %s"
				% str(
					position.get(
						"position_id",
						""
					)
				),
				"Position state: %s"
				% str(
					position.get(
						"status",
						"filled"
					)
				).capitalize(),
				"Institution stability: %d"
				% int(
					organization.get(
						"stability",
						70
					)
				),
				"Institution prestige: %d"
				% int(
					organization.get(
						"prestige",
						50
					)
				)
			]
		})

		for coworker_id in (
			gs.career_runtime_engine
			.coworker_ids_for_actor(
				actor
			)
		):
			var coworker: Person = (
				gs.get_or_reactivate_npc_by_id(
					int(
						coworker_id
					)
				)
			)

			if coworker == null:
				continue

			organization_rows.append({
				"title": _actor_display_name(
					coworker
				),
				"description": str(
					coworker.job
				),
				"lines": [
					"Department colleague"
				],
				"target_id": int(
					coworker.id
				),
				"profile_label": (
					"VIEW COWORKER PROFILE"
				)
			})

		actions = [
			{
				"action_id": "request_promotion",
				"label": "REQUEST PROMOTION REVIEW",
				"section_id": "overview",
				"enabled": true
			},
			{
				"action_id": "request_raise",
				"label": "REQUEST RAISE",
				"section_id": "overview",
				"enabled": true
			},
			{
				"action_id": "view_coworkers",
				"label": "VIEW DEPARTMENT COWORKERS",
				"section_id": "organization",
				"enabled": true
			},
			{
				"action_id": "retire",
				"label": "RETIRE",
				"section_id": "overview",
				"enabled": int(
					actor.age
				) >= 55,
				"disabled_reason": (
					"Retirement becomes available at age 55."
				)
			},
			{
				"action_id": "quit_position",
				"label": "QUIT POSITION",
				"section_id": "overview",
				"enabled": true
			}
		]

	for raw_position in (
		gs.career_runtime_engine
		.open_positions_for_actor(
			actor,
			"all"
		)
	):
		var open_position: Dictionary = _safe_dictionary(
			raw_position
		)
		var open_path: Dictionary = get_path_definition(
			str(
				open_position.get(
					"path_id",
					""
				)
			)
		)
		var open_rank: Dictionary = get_rank_definition(
			str(
				open_position.get(
					"path_id",
					""
				)
			),
			int(
				open_position.get(
					"rank_index",
					0
				)
			)
		)
		var requirement_report: Dictionary = (
			evaluate_entry_requirements(
				actor,
				open_path,
				open_rank
			)
		)
		var open_organization: Dictionary = (
			gs.career_runtime_engine
			.organization_by_id(
				str(
					open_position.get(
						"organization_id",
						""
					)
				)
			)
		)

		opportunity_rows.append({
			"position_id": str(
				open_position.get(
					"position_id",
					""
				)
			),
			"title": str(
				open_position.get(
					"rank_title",
					open_rank.get(
						"title",
						"Open Position"
					)
				)
			),
			"career_name": str(
				open_path.get(
					"display_name",
					"Career"
				)
			),
			"organization_name": str(
				open_organization.get(
					"name",
					"Institution"
				)
			),
			"department_name": str(
				open_position.get(
					"department_name",
					open_path.get(
						"department",
						"General"
					)
				)
			),
			"eligible": bool(
				requirement_report.get(
					"eligible",
					false
				)
			),
			"requirement_lines": _safe_array(
				requirement_report.get(
					"requirement_lines",
					[]
				)
			),
			"requirement_summary": str(
				requirement_report.get(
					"summary",
					""
				)
			),
			"special_path": bool(
				open_path.get(
					"special_path",
					false
				)
			)
		})

	var completed_majors: Array = _safe_array(
		education.get(
			"completed_majors",
			[]
		)
	)
	var graduate_schools: Array = _safe_array(
		education.get(
			"graduate_schools",
			[]
		)
	)
	var historical_programs: Array = _safe_array(
		education.get(
			"historical_programs",
			[]
		)
	)

	education_rows.append({
		"title": "Current Education",
		"lines": [
			"Active major: %s"
			% str(
				education.get(
					"active_major",
					"None"
				)
			),
			"Active program: %s"
			% str(
				education.get(
					"active_program",
					"None"
				)
			),
			"College performance: %d"
			% int(
				education.get(
					"college_performance_score",
					0
				)
			)
		]
	})
	education_rows.append({
		"title": "Completed College Majors",
		"lines": (
			completed_majors
			if not completed_majors.is_empty()
			else [
				"None"
			]
		)
	})
	education_rows.append({
		"title": "Professional Schools",
		"lines": (
			graduate_schools
			if not graduate_schools.is_empty()
			else [
				"None"
			]
		)
	})
	education_rows.append({
		"title": "Era Education & Apprenticeships",
		"lines": (
			historical_programs
			if not historical_programs.is_empty()
			else [
				"None"
			]
		)
	})

	var reputation: Dictionary = _safe_dictionary(
		profile.get(
			"professional_reputation",
			{}
		)
	)

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
		reputation_rows.append({
			"id": axis,
			"label": str(
				axis
			).replace(
				"_",
				" "
			).capitalize(),
			"value": int(
				reputation.get(
					axis,
					0
				)
			),
			"max_value": 100,
			"description": (
				_reputation_axis_description(
					axis
				)
			)
		})

	var legacy: Dictionary = _safe_dictionary(
		profile.get(
			"legacy",
			{}
		)
	)

	for legacy_key in legacy.keys():
		legacy_rows.append({
			"title": str(
				legacy_key
			).replace(
				"_",
				" "
			).capitalize(),
			"lines": [
				"%d"
				% int(
					legacy.get(
						legacy_key,
						0
					)
				)
			]
		})

	return {
		"success": true,
		"schema": PANEL_SCHEMA,
		"version": 1,
		"actor_id": int(
			actor.id
		),
		"actor_name": _actor_display_name(
			actor
		),
		"title": "CAREER ECOSYSTEM",
		"subtitle": (
			"%s • %s"
			% [
				_actor_display_name(
					actor
				),
				_current_era_name()
			]
		),
		"active_section": active_section,
		"section_tabs": _panel_section_tabs(),
		"overview_cards": overview_cards,
		"activity_rows": activity_rows,
		"opportunity_rows": opportunity_rows,
		"organization_rows": organization_rows,
		"education_rows": education_rows,
		"reputation_rows": reputation_rows,
		"legacy_rows": legacy_rows,
		"actions": actions,
		"status_text": str(
			context.get(
				"status_text",
				""
			)
		),
		"truth_state": "hot",
		"projection_read_only": true,
		"ui_is_renderer_only": true
	}


func _observable_partial_panel(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	return {
		"success": true,
		"schema": PANEL_SCHEMA,
		"version": 1,
		"actor_id": (
			int(actor.id)
			if actor != null
			else -1
		),
		"actor_name": _actor_display_name(
			actor
		),
		"title": "CAREER ECOSYSTEM",
		"subtitle": (
			"Professional reality exists and is becoming observable."
		),
		"active_section": str(
			context.get(
				"active_section",
				"overview"
			)
		),
		"section_tabs": _panel_section_tabs(),
		"overview_cards": [
			{
				"title": "Career Reality",
				"lines": [
					(
						"Institutional truth is resolving "
						+ "without requiring another click."
					)
				]
			}
		],
		"activity_rows": [],
		"opportunity_rows": [],
		"organization_rows": [],
		"education_rows": [],
		"reputation_rows": [],
		"legacy_rows": [],
		"actions": [],
		"status_text": str(
			context.get(
				"status_text",
				"Career truth is resolving…"
			)
		),
		"truth_state": "observable_partial",
		"ui_is_renderer_only": true
	}


func _panel_section_tabs() -> Array:
	return [
		{
			"id": "overview",
			"label": "OVERVIEW"
		},
		{
			"id": "activities",
			"label": "WORK"
		},
		{
			"id": "opportunities",
			"label": "OPPORTUNITIES"
		},
		{
			"id": "organization",
			"label": "ORGANIZATION"
		},
		{
			"id": "education",
			"label": "EDUCATION"
		},
		{
			"id": "reputation",
			"label": "REPUTATION"
		},
		{
			"id": "legacy",
			"label": "LEGACY"
		}
	]


func ensure_legacy_fallback_path(
	job_name: String,
	lane: String = "full_time"
) -> String:
	var clean_name: String = str(
		job_name
	).strip_edges()

	if clean_name == "":
		return ""

	var existing_id: String = path_id_for_legacy_job(
		clean_name
	)

	if existing_id != "":
		return existing_id

	var path_id: String = (
		"legacy_%s_%s"
		% [
			_slug(
				clean_name
			),
			_slug(
				_current_era_name()
			)
		]
	)
	var path: Dictionary = _path(
		path_id,
		clean_name,
		[
			_current_era_name()
		],
		"Independent Professional Network",
		"legacy_compatibility",
		"General",
		[
			clean_name
		],
		{
			"min_age": (
				14
				if lane == "part_time"
				else 18
			)
		},
		[
			clean_name
		],
		_generic_activities(
			clean_name
		),
		(
			"A legacy occupation preserved as a contract-backed "
			+ "institutional position."
		),
		lane,
		false
	)

	_register_path(
		path
	)

	return path_id


func _register_path(
	path: Dictionary
) -> void:
	var normalized: Dictionary = _safe_dictionary(
		path
	)
	var path_id: String = str(
		normalized.get(
			"path_id",
			""
		)
	).strip_edges()

	if path_id == "":
		return

	normalized ["path_id"] = path_id
	normalized ["display_name"] = str(
		normalized.get(
			"display_name",
			path_id
		)
	).strip_edges()
	normalized ["eras"] = _safe_array(
		normalized.get(
			"eras",
			[]
		)
	)
	normalized ["aliases"] = _safe_array(
		normalized.get(
			"aliases",
			[]
		)
	)
	normalized ["ranks"] = _safe_array(
		normalized.get(
			"ranks",
			[]
		)
	)
	normalized [
		"entry_requirements"
	] = _safe_dictionary(
		normalized.get(
			"entry_requirements",
			{}
		)
	)

	career_paths [
		path_id
	] = normalized

	var lookup_values: Array = [
		path_id,
		normalized.get(
			"display_name",
			""
		)
	]
	lookup_values.append_array(
		_safe_array(
			normalized.get(
				"aliases",
				[]
			)
		)
	)

	for raw_rank in _safe_array(
		normalized.get(
			"ranks",
			[]
		)
	):
		var rank: Dictionary = _safe_dictionary(
			raw_rank
		)
		lookup_values.append(
			str(
				rank.get(
					"title",
					""
				)
			)
		)

	for raw_value in lookup_values:
		var lookup_key: String = _normalize_lookup_key(
			str(
				raw_value
			)
		)

		if lookup_key != "":
			alias_to_path_id [
				lookup_key
			] = path_id


func _register_part_time_paths() -> void:
	_register_path(
		_path(
			"part_time_market_assistant",
			"Market Assistant",
			[
				"Ancient Era",
				"Medieval Era",
				"Industrial Era",
				"Modern Era",
				"Future Era"
			],
			"Local Commerce Network",
			"part_time_employer",
			"Market Operations",
			[
				"Market Assistant",
				"Shop Assistant",
				"Retail Associate",
				"Bazaar Helper"
			],
			{
				"min_age": 14
			},
			[
				"Market Assistant"
			],
			_merchant_activities(),
			(
				"Entry-level commerce work that exists inside "
				+ "the local economy."
			),
			"part_time"
		)
	)

	_register_path(
		_path(
			"part_time_archive_assistant",
			"Archive Assistant",
			[
				"Ancient Era",
				"Medieval Era",
				"Industrial Era",
				"Modern Era",
				"Future Era"
			],
			"Local Learning Institution",
			"part_time_employer",
			"Records",
			[
				"Archive Assistant",
				"Library Assistant",
				"Scribe Helper",
				"Data Archive Assistant"
			],
			{
				"min_age": 14,
				"min_smarts": 35
			},
			[
				"Archive Assistant"
			],
			_scribe_activities(),
			(
				"Part-time records work that can become a bridge "
				+ "into scholarship."
			),
			"part_time"
		)
	)

	_register_path(
		_path(
			"part_time_courier",
			"Courier",
			[
				"Ancient Era",
				"Medieval Era",
				"Industrial Era",
				"Modern Era",
				"Future Era"
			],
			"Regional Delivery Network",
			"part_time_employer",
			"Delivery",
			[
				"Courier",
				"Messenger",
				"Delivery Worker",
				"Orbital Courier"
			],
			{
				"min_age": 14,
				"min_health": 30
			},
			[
				"Courier"
			],
			_generic_activities(
				"Courier"
			),
			(
				"A flexible delivery role shaped by the "
				+ "transportation technology of the era."
			),
			"part_time"
		)
	)
func _medical_path(
	path_id: String,
	display_name: String,
	eras: Array,
	aliases: Array,
	entry_requirements: Dictionary,
	rank_titles: Array
) -> Dictionary:
	return _path(
		path_id,
		display_name,
		eras,
		"Healing and Medical Institution",
		"medical",
		"Medicine",
		aliases,
		entry_requirements,
		rank_titles,
		_medical_activities(),
		(
			"A historically grounded medical path whose education "
			+ "and responsibilities change with the era."
		)
	)


func _craft_path(
	path_id: String,
	display_name: String,
	eras: Array,
	aliases: Array,
	institution: String
) -> Dictionary:
	return _path(
		path_id,
		display_name,
		eras,
		institution,
		"guild",
		"Craft and Production",
		aliases,
		{
			"min_age": 14,
			"min_health": 35
		},
		[
			"Apprentice",
			"Journeyman",
			"Master",
			"Guild Leader"
		],
		_craft_activities(),
		(
			"A production profession governed by apprenticeship, "
			+ "mastery, and guild reputation."
		)
	)


func _military_path(
	path_id: String,
	display_name: String,
	eras: Array,
	aliases: Array,
	rank_titles: Array,
	entry_requirements: Dictionary = {}
) -> Dictionary:
	var requirements: Dictionary = _safe_dictionary(
		entry_requirements
	)

	if not requirements.has(
		"min_age"
	):
		requirements ["min_age"] = 16

	if not requirements.has(
		"min_health"
	):
		requirements ["min_health"] = 55

	return _path(
		path_id,
		display_name,
		eras,
		"Military Command Institution",
		"military",
		"Field Command",
		aliases,
		requirements,
		rank_titles,
		_military_activities(),
		(
			"A command hierarchy driven by training, duty, "
			+ "courage, campaigns, and real vacancies."
		),
		"full_time",
		true
	)


func _merchant_path(
	path_id: String,
	display_name: String,
	eras: Array,
	aliases: Array,
	rank_titles: Array
) -> Dictionary:
	return _path(
		path_id,
		display_name,
		eras,
		"Merchant and Trade Guild",
		"commerce",
		"Trade",
		aliases,
		{
			"min_age": 14,
			"min_smarts": 35
		},
		rank_titles,
		_merchant_activities(),
		(
			"A commercial institution built around markets, "
			+ "routes, negotiation, and guild standing."
		)
	)


func _nursing_path(
	path_id: String,
	eras: Array,
	aliases: Array
) -> Dictionary:
	return _path(
		path_id,
		"Nursing",
		eras,
		"Hospital and Medical Network",
		"hospital",
		"Nursing",
		aliases,
		{
			"min_age": 18,
			"min_smarts": 45,
			"majors_any": [
				"Nursing",
				"Biology",
				"Medicine"
			],
			"graduate_programs_any": [
				"Nursing School"
			]
		},
		[
			"Nursing Assistant",
			"Licensed Nurse",
			"Registered Nurse",
			"Charge Nurse",
			"Nurse Manager"
		],
		_nursing_activities(),
		(
			"A patient-care profession with clinical education, "
			+ "shift responsibilities, leadership, and institutional promotion."
		)
	)


func _physician_path(
	path_id: String,
	display_name: String,
	eras: Array,
	aliases: Array,
	department: String,
	graduate_programs: Array
) -> Dictionary:
	return _path(
		path_id,
		display_name,
		eras,
		"Hospital and Medical Network",
		"hospital",
		department,
		aliases,
		{
			"min_age": 22,
			"min_smarts": 62,
			"majors_any": [
				"Biology",
				"Medicine",
				"Chemistry"
			],
			"graduate_programs_any": graduate_programs
		},
		[
			"Medical Intern",
			"Resident Physician",
			"Attending Physician",
			"Senior Physician",
			"Department Chief"
		],
		_physician_activities(),
		(
			"A specialized physician path with medical school, "
			+ "supervised residency, independent practice, teaching, "
			+ "and departmental command."
		)
	)


func _engineering_path(
	path_id: String,
	display_name: String,
	eras: Array,
	aliases: Array,
	majors: Array
) -> Dictionary:
	return _path(
		path_id,
		display_name,
		eras,
		"Engineering and Infrastructure Institution",
		"engineering",
		"Engineering",
		aliases,
		{
			"min_age": 18,
			"min_smarts": 52,
			"majors_any": majors
		},
		[
			"Junior Engineer",
			"Engineer",
			"Senior Engineer",
			"Lead Engineer",
			"Chief Engineer"
		],
		_engineering_activities(),
		(
			"An engineering hierarchy that turns education, design, "
			+ "maintenance, and invention into world infrastructure."
		)
	)


func _law_path(
	path_id: String,
	display_name: String,
	eras: Array,
	aliases: Array,
	majors: Array
) -> Dictionary:
	return _path(
		path_id,
		display_name,
		eras,
		"Courts and Legal Institution",
		"legal",
		"Legal Practice",
		aliases,
		{
			"min_age": 21,
			"min_smarts": 55,
			"majors_any": majors,
			"graduate_programs_any": [
				"Law School"
			]
		},
		[
			"Legal Clerk",
			"Associate",
			"Attorney",
			"Senior Counsel",
			"Managing Counsel"
		],
		_law_activities(),
		(
			"A legal institution shaped by education, cases, "
			+ "professional ethics, and judicial reputation."
		)
	)


func _teaching_path(
	path_id: String,
	display_name: String,
	eras: Array,
	aliases: Array,
	majors: Array
) -> Dictionary:
	return _path(
		path_id,
		display_name,
		eras,
		"Education Institution",
		"education",
		"Teaching and Scholarship",
		aliases,
		{
			"min_age": 18,
			"min_smarts": 48,
			"majors_any": majors
		},
		[
			"Teaching Assistant",
			"Teacher",
			"Senior Teacher",
			"Department Chair",
			"Head of Institution"
		],
		_teaching_activities(),
		(
			"An educational profession where students, scholarship, "
			+ "mentorship, and institutional leadership become legacy."
		)
	)


func _finance_path(
	path_id: String,
	display_name: String,
	eras: Array,
	aliases: Array,
	majors: Array
) -> Dictionary:
	return _path(
		path_id,
		display_name,
		eras,
		"Finance and Commerce Institution",
		"finance",
		"Accounting and Finance",
		aliases,
		{
			"min_age": 18,
			"min_smarts": 45,
			"majors_any": majors
		},
		[
			"Junior Associate",
			"Associate",
			"Senior Analyst",
			"Manager",
			"Director"
		],
		_finance_activities(),
		(
			"A financial profession driven by accuracy, risk, trust, "
			+ "capital, and institutional reputation."
		)
	)


func _research_path(
	path_id: String,
	display_name: String,
	eras: Array,
	aliases: Array,
	majors: Array
) -> Dictionary:
	return _path(
		path_id,
		display_name,
		eras,
		"Research Institution",
		"research",
		"Research and Discovery",
		aliases,
		{
			"min_age": 18,
			"min_smarts": 58,
			"majors_any": majors
		},
		[
			"Research Assistant",
			"Researcher",
			"Senior Researcher",
			"Principal Investigator",
			"Institute Director"
		],
		_research_activities(),
		(
			"A research hierarchy where experiments, publications, "
			+ "discoveries, patents, and students persist in history."
		)
	)


func _future_path(
	path_id: String,
	display_name: String,
	institution: String,
	department: String,
	aliases: Array,
	majors: Array,
	legacy_metric: String,
	special_path: bool
) -> Dictionary:
	return _path(
		path_id,
		display_name,
		[
			"Future Era"
		],
		institution,
		"future_institution",
		department,
		aliases,
		{
			"min_age": 18,
			"min_smarts": 58,
			"majors_any": majors
		},
		[
			"Trainee",
			"Specialist",
			"Senior Specialist",
			"Systems Lead",
			"Director"
		],
		_future_activities(
			display_name,
			legacy_metric
		),
		(
			"A genuinely futuristic profession embedded in planetary, "
			+ "orbital, neural, quantum, synthetic, or reality-scale infrastructure."
		),
		"full_time",
		special_path
	)


func _future_medical_path(
	path_id: String,
	display_name: String,
	department: String,
	aliases: Array,
	majors: Array,
	graduate_programs: Array,
	legacy_metric: String
) -> Dictionary:
	return _path(
		path_id,
		display_name,
		[
			"Future Era"
		],
		"Interstellar Medical Network",
		"future_hospital",
		department,
		aliases,
		{
			"min_age": 22,
			"min_smarts": 65,
			"majors_any": majors,
			"graduate_programs_any": graduate_programs
		},
		[
			"Clinical Trainee",
			"Resident Specialist",
			"Practitioner",
			"Senior Specialist",
			"Department Director"
		],
		_future_medical_activities(
			display_name,
			legacy_metric
		),
		(
			"A future medical profession where biology, neural systems, "
			+ "synthetic organs, memory, and interstellar care become "
			+ "institutional reality."
		)
	)


func _responsibilities_for_rank(
	career_name: String,
	rank_title: String,
	rank_index: int
) -> Array:
	var out: Array = [
		"Perform the duties of %s within %s."
		% [
			rank_title,
			career_name
		],
		"Protect the standards and reputation of the institution."
	]

	if rank_index >= 1:
		out.append(
			"Handle independent professional responsibilities."
		)

	if rank_index >= 2:
		out.append(
			"Mentor junior workers and review complex work."
		)

	if rank_index >= 3:
		out.append(
			"Coordinate teams, resources, and departmental outcomes."
		)

	if rank_index >= 4:
		out.append(
			(
				"Set institutional policy and shape the "
				+ "profession's historical legacy."
			)
		)

	return out
func _scribe_activities() -> Array:
	return [
		_activity(
			"copy_records",
			"Copy Records",
			"Preserve legal, religious, or commercial records.",
			4,
			2.0,
			1,
			{
				"reliability": 2,
				"efficiency": 1
			},
			"books_written",
			0
		),
		_activity(
			"verify_accounts",
			"Verify Accounts",
			"Audit names, taxes, inventories, and official entries.",
			5,
			4.0,
			0,
			{
				"reliability": 2,
				"carelessness": -1
			},
			"world_traces",
			1
		),
		_activity(
			"compose_archive",
			"Compose an Archive",
			"Create a durable record that future generations can inherit.",
			7,
			6.0,
			2,
			{
				"innovation": 1,
				"reliability": 2
			},
			"books_written",
			1
		)
	]


func _scholar_activities() -> Array:
	return [
		_activity(
			"study_texts",
			"Study Texts",
			"Interpret difficult teachings, laws, or historical records.",
			4,
			2.0,
			2,
			{
				"reliability": 1,
				"innovation": 1
			},
			"discoveries",
			0
		),
		_activity(
			"teach_novices",
			"Teach Novices",
			"Pass knowledge to the next professional generation.",
			5,
			3.0,
			3,
			{
				"kindness": 2,
				"leadership": 1
			},
			"students_mentored",
			1
		),
		_activity(
			"write_treatise",
			"Write a Treatise",
			"Create scholarship that can outlive the author.",
			7,
			5.0,
			2,
			{
				"innovation": 2,
				"reliability": 1
			},
			"books_written",
			1
		)
	]


func _medical_activities() -> Array:
	return [
		_activity(
			"prepare_remedies",
			"Prepare Remedies",
			"Prepare medicines and treatment materials.",
			4,
			3.0,
			1,
			{
				"reliability": 2,
				"kindness": 1
			},
			"patients_saved",
			0
		),
		_activity(
			"examine_patient",
			"Examine Patient",
			"Observe symptoms and decide on a course of care.",
			5,
			4.0,
			2,
			{
				"kindness": 1,
				"efficiency": 1
			},
			"patients_saved",
			1
		),
		_activity(
			"treat_critical_case",
			"Treat Critical Case",
			"Take responsibility for a dangerous medical emergency.",
			8,
			9.0,
			2,
			{
				"bravery": 2,
				"reliability": 2
			},
			"patients_saved",
			1
		)
	]


func _craft_activities() -> Array:
	return [
		_activity(
			"practice_craft",
			"Practice Craft",
			"Improve precision with tools and materials.",
			4,
			3.0,
			2,
			{
				"reliability": 1,
				"efficiency": 1
			},
			"achievements",
			0
		),
		_activity(
			"complete_commission",
			"Complete Commission",
			"Produce an item for a real client or institution.",
			6,
			5.0,
			2,
			{
				"reliability": 2,
				"efficiency": 1
			},
			"achievements",
			1
		),
		_activity(
			"design_masterwork",
			"Design Masterwork",
			"Attempt work worthy of becoming part of professional history.",
			8,
			8.0,
			3,
			{
				"innovation": 3,
				"carelessness": -1
			},
			"world_traces",
			1
		)
	]


func _military_activities() -> Array:
	return [
		_activity(
			"morning_training",
			"Morning Training",
			"Drill the body, weapons, formations, and discipline.",
			4,
			5.0,
			1,
			{
				"reliability": 1,
				"bravery": 1
			},
			"achievements",
			0
		),
		_activity(
			"weapons_practice",
			"Weapons Practice",
			"Train with the weapons required by the rank.",
			5,
			6.0,
			2,
			{
				"bravery": 1,
				"efficiency": 1
			},
			"battles_won",
			0
		),
		_activity(
			"escort_noble",
			"Escort Noble",
			"Protect an important traveler through uncertain territory.",
			6,
			7.0,
			1,
			{
				"reliability": 2,
				"bravery": 1
			},
			"world_traces",
			0
		),
		_activity(
			"border_patrol",
			"Border Patrol",
			"Guard the institution's territory and investigate threats.",
			7,
			8.0,
			1,
			{
				"bravery": 2,
				"leadership": 1
			},
			"battles_won",
			0
		),
		_activity(
			"castle_defense",
			"Castle Defense",
			"Coordinate defense during an attack or siege.",
			9,
			12.0,
			2,
			{
				"bravery": 3,
				"leadership": 2
			},
			"battles_won",
			1
		),
		_activity(
			"military_campaign",
			"Military Campaign",
			"Lead or participate in a major campaign.",
			10,
			15.0,
			1,
			{
				"bravery": 3,
				"leadership": 3
			},
			"battles_won",
			1
		)
	]


func _merchant_activities() -> Array:
	return [
		_activity(
			"inspect_goods",
			"Inspect Goods",
			"Verify quality, quantity, and condition before trade.",
			4,
			2.0,
			1,
			{
				"reliability": 1,
				"efficiency": 1
			},
			"achievements",
			0
		),
		_activity(
			"negotiate_trade",
			"Negotiate Trade",
			"Bargain over price, access, risk, and delivery.",
			5,
			4.0,
			2,
			{
				"leadership": 1,
				"efficiency": 2
			},
			"world_traces",
			0
		),
		_activity(
			"open_trade_route",
			"Open Trade Route",
			"Build a durable route between markets or civilizations.",
			8,
			8.0,
			3,
			{
				"innovation": 2,
				"leadership": 2
			},
			"world_traces",
			1
		)
	]


func _nursing_activities() -> Array:
	return [
		_activity(
			"deliver_medicine",
			"Deliver Medicine",
			"Administer medicine and document the patient's response.",
			4,
			4.0,
			2,
			{
				"reliability": 2,
				"kindness": 1
			},
			"patients_saved",
			0
		),
		_activity(
			"monitor_patients",
			"Monitor Patients",
			"Track changes and escalate dangerous symptoms.",
			5,
			5.0,
			2,
			{
				"reliability": 2,
				"carelessness": -1
			},
			"patients_saved",
			1
		),
		_activity(
			"assist_procedure",
			"Assist Procedure",
			"Support a physician or surgical team during treatment.",
			6,
			7.0,
			2,
			{
				"efficiency": 2,
				"bravery": 1
			},
			"patients_saved",
			1
		),
		_activity(
			"coordinate_shift",
			"Coordinate Shift",
			"Allocate staff and maintain care standards across the department.",
			7,
			8.0,
			2,
			{
				"leadership": 2,
				"reliability": 2
			},
			"students_mentored",
			1
		)
	]


func _physician_activities() -> Array:
	return [
		_activity(
			"observe_procedure",
			"Observe Procedure",
			"Study a senior clinician's decisions and technique.",
			4,
			3.0,
			2,
			{
				"reliability": 1,
				"innovation": 1
			},
			"patients_saved",
			0
		),
		_activity(
			"perform_diagnosis",
			"Perform Diagnosis",
			"Interpret evidence and determine what is harming the patient.",
			6,
			6.0,
			2,
			{
				"reliability": 2,
				"efficiency": 1
			},
			"patients_saved",
			1
		),
		_activity(
			"treat_emergency",
			"Treat Emergency",
			"Take responsibility for immediate life-saving care.",
			8,
			11.0,
			2,
			{
				"bravery": 2,
				"kindness": 1
			},
			"patients_saved",
			1
		),
		_activity(
			"lead_surgery",
			"Lead Surgery",
			"Direct a complex procedure and the team performing it.",
			9,
			14.0,
			2,
			{
				"leadership": 2,
				"reliability": 2
			},
			"patients_saved",
			1
		),
		_activity(
			"teach_residents",
			"Teach Residents",
			"Train the next generation of physicians.",
			7,
			6.0,
			4,
			{
				"leadership": 2,
				"kindness": 2
			},
			"students_mentored",
			1
		)
	]


func _engineering_activities() -> Array:
	return [
		_activity(
			"inspect_system",
			"Inspect System",
			"Diagnose the condition of a machine, structure, or network.",
			4,
			3.0,
			1,
			{
				"reliability": 2,
				"carelessness": -1
			},
			"achievements",
			0
		),
		_activity(
			"design_component",
			"Design Component",
			"Create a component that solves a real technical need.",
			6,
			5.0,
			3,
			{
				"innovation": 2,
				"efficiency": 1
			},
			"patents_created",
			0
		),
		_activity(
			"repair_critical_failure",
			"Repair Critical Failure",
			"Restore infrastructure before cascading damage spreads.",
			8,
			10.0,
			2,
			{
				"bravery": 1,
				"reliability": 2
			},
			"world_traces",
			1
		),
		_activity(
			"lead_infrastructure_project",
			"Lead Infrastructure Project",
			"Coordinate a project that changes how people live or move.",
			9,
			11.0,
			3,
			{
				"leadership": 3,
				"innovation": 1
			},
			"buildings_created",
			1
		)
	]


func _law_activities() -> Array:
	return [
		_activity(
			"review_evidence",
			"Review Evidence",
			"Analyze facts, testimony, and legal precedent.",
			4,
			3.0,
			1,
			{
				"reliability": 2,
				"carelessness": -1
			},
			"cases_won",
			0
		),
		_activity(
			"advise_client",
			"Advise Client",
			"Explain risk, rights, and available legal strategy.",
			5,
			4.0,
			2,
			{
				"kindness": 1,
				"reliability": 1
			},
			"cases_won",
			0
		),
		_activity(
			"argue_case",
			"Argue Case",
			"Present a case before an institutional authority.",
			7,
			8.0,
			2,
			{
				"leadership": 2,
				"bravery": 1
			},
			"cases_won",
			1
		),
		_activity(
			"write_precedent",
			"Write Precedent",
			"Create legal reasoning that can influence future cases.",
			8,
			7.0,
			3,
			{
				"innovation": 2,
				"reliability": 2
			},
			"world_traces",
			1
		)
	]


func _teaching_activities() -> Array:
	return [
		_activity(
			"prepare_lesson",
			"Prepare Lesson",
			"Turn knowledge into a structured learning experience.",
			4,
			3.0,
			2,
			{
				"reliability": 1,
				"innovation": 1
			},
			"students_mentored",
			0
		),
		_activity(
			"teach_class",
			"Teach Class",
			"Guide students through difficult material.",
			5,
			5.0,
			3,
			{
				"kindness": 2,
				"leadership": 1
			},
			"students_mentored",
			1
		),
		_activity(
			"mentor_student",
			"Mentor Student",
			"Invest directly in another person's professional future.",
			6,
			4.0,
			4,
			{
				"kindness": 3,
				"leadership": 1
			},
			"students_mentored",
			1
		),
		_activity(
			"publish_curriculum",
			"Publish Curriculum",
			"Create material that other institutions can continue using.",
			8,
			7.0,
			3,
			{
				"innovation": 2,
				"reliability": 1
			},
			"books_written",
			1
		)
	]


func _finance_activities() -> Array:
	return [
		_activity(
			"reconcile_accounts",
			"Reconcile Accounts",
			"Verify that institutional records match real transactions.",
			4,
			3.0,
			1,
			{
				"reliability": 2,
				"carelessness": -1
			},
			"achievements",
			0
		),
		_activity(
			"analyze_risk",
			"Analyze Risk",
			"Estimate exposure before committing resources.",
			6,
			5.0,
			2,
			{
				"efficiency": 2,
				"innovation": 1
			},
			"achievements",
			0
		),
		_activity(
			"manage_portfolio",
			"Manage Portfolio",
			"Allocate capital across competing needs and opportunities.",
			7,
			7.0,
			2,
			{
				"leadership": 1,
				"efficiency": 2
			},
			"world_traces",
			1
		),
		_activity(
			"audit_institution",
			"Audit Institution",
			"Investigate systemic errors, waste, or corruption.",
			8,
			8.0,
			2,
			{
				"reliability": 3,
				"corruption": -2
			},
			"world_traces",
			1
		)
	]


func _research_activities() -> Array:
	return [
		_activity(
			"review_literature",
			"Review Literature",
			"Study what the profession already knows.",
			4,
			2.0,
			2,
			{
				"reliability": 1,
				"innovation": 1
			},
			"discoveries",
			0
		),
		_activity(
			"run_experiment",
			"Run Experiment",
			"Test a hypothesis under controlled conditions.",
			6,
			6.0,
			3,
			{
				"innovation": 2,
				"carelessness": -1
			},
			"discoveries",
			1
		),
		_activity(
			"publish_results",
			"Publish Results",
			"Expose findings to professional scrutiny and historical memory.",
			7,
			7.0,
			3,
			{
				"reliability": 2,
				"innovation": 2
			},
			"books_written",
			1
		),
		_activity(
			"lead_research_program",
			"Lead Research Program",
			"Coordinate people, funding, and long-term discovery.",
			9,
			10.0,
			3,
			{
				"leadership": 3,
				"innovation": 2
			},
			"patents_created",
			1
		)
	]


func _future_activities(
	career_name: String,
	legacy_metric: String
) -> Array:
	return [
		_activity(
			"calibrate_future_system",
			"Calibrate %s Systems"
			% career_name,
			(
				"Stabilize advanced infrastructure before it "
				+ "affects entire populations."
			),
			5,
			5.0,
			2,
			{
				"reliability": 2,
				"innovation": 1
			},
			legacy_metric,
			0
		),
		_activity(
			"resolve_system_anomaly",
			"Resolve System Anomaly",
			(
				"Investigate behavior that ordinary models "
				+ "cannot explain."
			),
			7,
			8.0,
			3,
			{
				"innovation": 2,
				"bravery": 1
			},
			legacy_metric,
			1
		),
		_activity(
			"design_next_generation_protocol",
			"Design Next-Generation Protocol",
			(
				"Create a professional standard that future "
				+ "institutions can inherit."
			),
			9,
			10.0,
			4,
			{
				"innovation": 3,
				"leadership": 2
			},
			legacy_metric,
			1
		)
	]


func _future_medical_activities(
	career_name: String,
	legacy_metric: String
) -> Array:
	var rows: Array = _physician_activities()

	rows.append(
		_activity(
			"future_clinical_breakthrough",
			"Create %s Breakthrough"
			% career_name,
			(
				"Use future medicine to solve a condition "
				+ "that earlier eras could not treat."
			),
			10,
			13.0,
			4,
			{
				"innovation": 3,
				"kindness": 2,
				"reliability": 2
			},
			legacy_metric,
			1
		)
	)

	return rows


func _generic_activities(
	career_name: String
) -> Array:
	return [
		_activity(
			"complete_shift",
			"Complete %s Shift"
			% career_name,
			"Perform the core responsibilities of the position.",
			4,
			3.0,
			1,
			{
				"reliability": 1,
				"efficiency": 1
			},
			"achievements",
			0
		),
		_activity(
			"solve_workplace_problem",
			"Solve Workplace Problem",
			(
				"Resolve an operational problem without asking "
				+ "the UI to invent an outcome."
			),
			6,
			5.0,
			2,
			{
				"innovation": 1,
				"reliability": 1
			},
			"world_traces",
			0
		)
	]


func _activity(
	activity_id: String,
	label: String,
	description: String,
	performance_delta: int,
	stress_delta: float,
	satisfaction_delta: int,
	reputation_delta: Dictionary,
	legacy_metric: String,
	legacy_delta: int
) -> Dictionary:
	return {
		"id": activity_id,
		"label": label,
		"description": description,
		"performance_delta": performance_delta,
		"stress_delta": stress_delta,
		"satisfaction_delta": satisfaction_delta,
		"reputation_delta": reputation_delta.duplicate(
			true
		),
		"legacy_metric": legacy_metric,
		"legacy_delta": legacy_delta,
		"action_label": "PERFORM",
		"productive_uses_per_year": 3,
	}
func emit_career_catalog_contract(
	actor: Person,
	lane: String = "full_time",
	context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _fail(
			"missing_actor",
			context
		)

	var normalized_lane: String = str(
		lane
	).strip_edges().to_lower()

	if normalized_lane not in [
		"full_time",
		"part_time"
	]:
		normalized_lane = "full_time"

	var runtime = (
		gs.career_runtime_engine
		if gs != null
		else null
	)

	var open_entry_positions: Dictionary = {}
	var current_assignment: Dictionary = {}

	if runtime != null:

		current_assignment = (
			runtime.assignment_for_actor(
				actor
			)
		)

		for raw_position in (
			runtime.open_positions_for_actor(
				actor,
				normalized_lane
			)
		):
			if typeof(raw_position) != TYPE_DICTIONARY:
				continue

			var position: Dictionary = (
				raw_position as Dictionary
			)
			var path_id: String = str(
				position.get(
					"path_id",
					""
				)
			)

			if path_id == "":
				continue

			if int(
				position.get(
					"rank_index",
					0
				)
			) != 0:
				continue

			if open_entry_positions.has(
				path_id
			):
				continue

			open_entry_positions [
				path_id
			] = position

	var rows: Array = []
	var selected_path_id: String = str(
		context.get(
			"selected_path_id",
			""
		)
	).strip_edges()
	var selected_path: Dictionary = {}
	var selected_row: Dictionary = {}
	var eligible_application_count: int = 0
	var qualified_path_count: int = 0
	var vacancy_count: int = 0
	var era_name: String = _current_era_name()

	for raw_path_id in career_paths.keys():
		var path_id: String = str(
			raw_path_id
		)
		var path: Dictionary = get_path_definition(
			path_id
		)

		if path.is_empty():
			continue
		if _career_path_is_external_special(
			path
		):
			continue
		if era_name not in _safe_array(
			path.get(
				"eras",
				[]
			)
		):
			continue

		if str(
			path.get(
				"lane",
				"full_time"
			)
		).to_lower() != normalized_lane:
			continue

		var rank: Dictionary = get_rank_definition(
			path_id,
			0
		)

		var requirements: Dictionary = (
			evaluate_entry_requirements(
				actor,
				path,
				rank
			)
		)

		var vacancy_raw: Variant = (
			open_entry_positions.get(
				path_id,
				{}
			)
		)
		var vacancy: Dictionary = (
			vacancy_raw as Dictionary
			if typeof(vacancy_raw) == TYPE_DICTIONARY
			else {}
		)

		var has_vacancy: bool = (
			not vacancy.is_empty()
		)
		var qualification_eligible: bool = bool(
			requirements.get(
				"qualification_eligible",
				requirements.get(
					"eligible",
					false
				)
			)
		)
		var already_employed: bool = (
			not current_assignment.is_empty()
		)

		var can_apply: bool = (
			actor.alive
			and not already_employed
			and qualification_eligible
			and has_vacancy
		)

		var application_status: String = (
			"Eligible to apply"
		)

		if not actor.alive:
			application_status = (
				"Applications require a living applicant"
			)
		elif already_employed:
			application_status = (
				"Qualified jobs remain visible. "
				+ "Quit the current position before applying."
			)
		elif not qualification_eligible:
			application_status = str(
				requirements.get(
					"summary",
					"Requirements are not met."
				)
			)
		elif not has_vacancy:
			application_status = (
				"You qualify for this profession, "
				+ "but no entry position is currently vacant."
			)

		var rank_titles: Array = []

		for raw_rank in _safe_array(
			path.get(
				"ranks",
				[]
			)
		):
			var rank_row: Dictionary = _safe_dictionary(
				raw_rank
			)
			var rank_title: String = str(
				rank_row.get(
					"title",
					""
				)
			).strip_edges()

			if rank_title != "":
				rank_titles.append(
					rank_title
				)

		var salary_quote: int = 0

		if runtime != null:
			salary_quote = int(
				vacancy.get(
					"salary",
					runtime.salary_quote_for_path(
						path,
						0
					)
				)
			)

		var social_group: String = str(
			requirements.get(
				"social_class_group",
				""
			)
		)

		var row: Dictionary = {
			"path_id": path_id,
			"title": str(
				path.get(
					"display_name",
					path_id
				)
			),
			"description": str(
				path.get(
					"description",
					(
						"A living professional path "
						+ "inside this era."
					)
				)
			),
			"organization_name": str(
				path.get(
					"institution",
					"Professional Institution"
				)
			),
			"department_name": str(
				path.get(
					"department",
					"General"
				)
			),
			"organization_type": str(
				path.get(
					"organization_type",
					"institution"
				)
			),
			"lane": normalized_lane,
			"era_name": era_name,
			"rank_titles": rank_titles,
			"entry_rank_title": str(
				rank.get(
					"title",
					path.get(
						"display_name",
						"Entry Position"
					)
				)
			),
			"position_id": str(
				vacancy.get(
					"position_id",
					""
				)
			),

			"salary": salary_quote,
			"pay_amount": salary_quote,

			"currency_contract": (
				gs.economy_engine.get_currency(
					actor
				)
				if (
					gs != null
					and gs.economy_engine != null
				)
				else {}
			),

			"pay_text": (
				str(
					gs.economy_engine.format_money(
						salary_quote,
						actor
					)
				)
				if (
					gs != null
					and gs.economy_engine != null
				)
				else str(
					salary_quote
				)
			),
			"pay_period": (
				"monthly-equivalent"
				if era_name in [
					"Ancient Era",
					"Medieval Era"
				]
				else "annual"
			),

			"has_vacancy": has_vacancy,
			"can_apply": can_apply,

			"qualification_eligible": (
				qualification_eligible
			),
			"eligibility_state": (
				"eligible"
				if qualification_eligible
				else "ineligible"
			),
			"eligibility_label": (
				"YOU'RE ELIGIBLE FOR THIS JOB!"
				if qualification_eligible
				else "YOU'RE NOT ELIGIBLE FOR THIS JOB"
			),
			"eligibility_color_key": (
				"eligible_green"
				if qualification_eligible
				else "ineligible_red"
			),

			"application_status": (
				application_status
			),
			"requirements_met": (
				qualification_eligible
			),
			"requirements": requirements,
			"requirement_lines": _safe_array(
				requirements.get(
					"requirement_lines",
					[]
				)
			),

			"social_class_governed": bool(
				requirements.get(
					"social_class_governed",
					false
				)
			),
			"social_class_group": social_group,
			"social_class_sort_order": int(
				requirements.get(
					"social_class_sort_order",
					0
				)
			),

			"special_path": bool(
				path.get(
					"special_path",
					false
				)
			),
			"persistent_institution": bool(
				path.get(
					"persistent_institution",
					true
				)
			),
			"vacancy_driven": bool(
				path.get(
					"vacancy_driven",
					true
				)
			),
			"is_selected": (
				path_id == selected_path_id
			)
		}

		rows.append(
			row
		)

		if qualification_eligible:
			qualified_path_count += 1

		if can_apply:
			eligible_application_count += 1

		if has_vacancy:
			vacancy_count += 1

		if path_id == selected_path_id:
			selected_path = path
			selected_row = row

	var historical_grouping: bool = (
		era_name in [
			"Ancient Era",
			"Medieval Era"
		]
	)

	rows.sort_custom(
		func (
			left_raw: Variant,
			right_raw: Variant
		) -> bool:
			if (
				typeof(left_raw) != TYPE_DICTIONARY
				or typeof(right_raw) != TYPE_DICTIONARY
			):
				return false

			var left: Dictionary = (
				left_raw as Dictionary
			)

			var right: Dictionary = (
				right_raw as Dictionary
			)

			var left_pay: int = int(
				left.get(
					"pay_amount",
					left.get(
						"salary",
						0
					)
				)
			)

			var right_pay: int = int(
				right.get(
					"pay_amount",
					right.get(
						"salary",
						0
					)
				)
			)


			if left_pay != right_pay:
				return left_pay > right_pay

			var left_eligible: bool = bool(
				left.get(
					"qualification_eligible",
					false
				)
			)

			var right_eligible: bool = bool(
				right.get(
					"qualification_eligible",
					false
				)
			)

			if left_eligible != right_eligible:
				return left_eligible

			if historical_grouping:
				var left_group: int = int(
					left.get(
						"social_class_sort_order",
						0
					)
				)

				var right_group: int = int(
					right.get(
						"social_class_sort_order",
						0
					)
				)

				if left_group != right_group:
					return left_group < right_group

			return str(
				left.get(
					"title",
					""
				)
			) < str(
				right.get(
					"title",
					""
				)
			)
	)
	var qualification_revision_rows:= PackedStringArray()

	for raw_revision_row in rows:
		var revision_row: Dictionary = _safe_dictionary(
			raw_revision_row
		)

		qualification_revision_rows.append(
			"%s|%s|%s|%s|%d|%s"
			% [
				str(
					revision_row.get(
						"path_id",
						""
					)
				),
				str(
					bool(
						revision_row.get(
							"qualification_eligible",
							false
						)
					)
				),
				str(
					bool(
						revision_row.get(
							"can_apply",
							false
						)
					)
				),
				str(
					revision_row.get(
						"position_id",
						""
					)
				),
				int(
					revision_row.get(
						"pay_amount",
						0
					)
				),
				str(
					revision_row.get(
						"application_status",
						""
					)
				)
			]
		)

	var qualification_material: String = (
		"|".join(
			qualification_revision_rows
		)
	)

	var catalog_revision: String = (
		"%d:%d:%s:%s:%d"
		% [
			int(
				actor.id
			),
			int(
				actor.age
			),
			era_name,
			normalized_lane,
			int(
				qualification_material.hash()
			)
		]
	)
	return {
		"success": true,
		"schema": (
			"eralife.career_catalog_contract"
		),
		"version": 2,
		"actor_id": int(
			actor.id
		),
		"actor_age": int(
			actor.age
		),
		"era_name": era_name,
		"lane": normalized_lane,
		"title": (
			"PART-TIME CAREERS"
			if normalized_lane == "part_time"
			else "FULL-TIME CAREERS"
		),
		"sort_key": "pay_desc",
		"qualification_actor_id": int(
			actor.id
		),
		"qualification_actor_age": int(
			actor.age
		),
		"catalog_revision": catalog_revision,
		"career_rows": rows,
		"total_paths": rows.size(),
		"vacancy_count": vacancy_count,
		"qualified_path_count": qualified_path_count,
		"eligible_application_count": (
			eligible_application_count
		),
		"group_by_social_class": (
			historical_grouping
		),
		"selected_path_id": selected_path_id,
		"selected_path": selected_path,
		"selected_row": selected_row,
		"current_assignment": current_assignment,
		"status_text": (
			(
				"Occupations are grouped by social class. "
				+ "Green cards meet your current qualifications; "
				+ "red cards show what you are missing."
			)
			if historical_grouping
			else (
				"Green cards meet your current qualifications. "
				+ "Applications remain governed by education, "
				+ "credentials, vacancies, and institutional approval."
			)
		),
		"ui_is_renderer_only": true
	}
func _professional_reputation_score(
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

	var reputation: Dictionary = _safe_dictionary(
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


func _stable_roll(
	seed_text: String,
	minimum: int,
	maximum: int
) -> int:
	var low: int = mini(
		minimum,
		maximum
	)
	var high: int = maxi(
		minimum,
		maximum
	)
	var span: int = (
		high
		- low
		+ 1
	)

	if span <= 1:
		return low

	return (
		low
		+ posmod(
			int(
				str(
					seed_text
				).hash()
			),
			span
		)
	)


func _contains_any_string(
	haystack: Array,
	needles: Array
) -> bool:
	var normalized_haystack: Dictionary = {}

	for raw_value in haystack:
		normalized_haystack [
			_normalize_lookup_key(
				str(
					raw_value
				)
			)
		] = true

	for raw_value in needles:
		if normalized_haystack.has(
			_normalize_lookup_key(
				str(
					raw_value
				)
			)
		):
			return true

	return false


func _normalize_lookup_key(
	value: String
) -> String:
	var normalized: String = str(
		value
	).strip_edges().to_lower()

	normalized = normalized.replace(
		"-",
		" "
	).replace(
		"_",
		" "
	)

	while "  " in normalized:
		normalized = normalized.replace(
			"  ",
			" "
		)

	return normalized


func _slug(
	value: String
) -> String:
	var out: String = str(
		value
	).strip_edges().to_lower()

	for token in [
		" ",
		"-",
		"/",
		"\\",
		":",
		".",
		",",
		"'",
		"\""
	]:
		out = out.replace(
			token,
			"_"
		)

	while "__" in out:
		out = out.replace(
			"__",
			"_"
		)

	return out.trim_prefix(
		"_"
	).trim_suffix(
		"_"
	)


func _current_era_name() -> String:
	if (
		gs == null
		or gs.era == null
	):
		return "Unknown Era"

	return str(
		gs.era.get(
			"name",
			"Unknown Era"
		)
	)


func _actor_display_name(
	actor: Person
) -> String:
	if actor == null:
		return "Unknown Person"

	var full_name: String = (
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

	return (
		full_name
		if full_name != ""
		else "Person %d"
		% int(actor.id)
	)

func _brain_surgery_path(
	path_id: String,
	_display_name: String,
	eras: Array,
	future_path: bool = false
) -> Dictionary:
	var requirements: Dictionary = {
		"min_age": 22,
		"min_smarts": 70
	}

	if future_path:
		requirements ["majors_any"] = [
			"Interstellar Medicine",
			"Neural Architecture",
			"Synthetic Biology"
		]
		requirements [
			"graduate_programs_any"
		] = [
			"Interstellar Medical School",
			"Neural Surgery Residency"
		]

	else:
		requirements ["majors_any"] = [
			"Biology",
			"Medicine",
			"Chemistry"
		]
		requirements [
			"graduate_programs_any"
		] = [
			"Medical School"
		]

	var occupation_title: String = (
		"Neural Brain Surgeon"
		if future_path
		else "Brain Surgeon"
	)

	var path: Dictionary = _path(
		path_id,
		occupation_title,
		eras,
		(
			"Neural Medicine Institute"
			if future_path
			else "Hospital and Surgical Network"
		),
		"hospital",
		"Neurosurgery",
		[
			"Brain Surgeon",
			"Neurosurgeon",
			"Brain Surgery",
			"Neurosurgery"
		],
		requirements,
		[
			"Surgical Intern",
			"Neurosurgery Resident",
			"Brain Surgeon",
			"Senior Brain Surgeon",
			"Chief of Neurosurgery"
		],
		_medical_activities(),
		(
			"An elite surgical profession requiring completed "
			+ "college preparation, medical training, precision, "
			+ "and long-term professional performance."
		),
		"full_time",
		true
	)

	path [
		"occupation_title"
	] = occupation_title
	path [
		"minimum_base_salary_by_era"
	] = {
		"Industrial Era": 32000,
		"Modern Era": 95000,
		"Future Era": 185000
	}
	path [
		"salary_floor_authority"
	] = "career_contract_engine"
	path [
		"salary_floor_is_entry_position_floor"
	] = true

	return path


func _future_nursing_path() -> Dictionary:
	return _path(
		"future_nursing",
		"Future Nursing",
		[
			"Future Era"
		],
		"Interstellar Health Network",
		"hospital",
		"Advanced Nursing",
		[
			"Nurse",
			"Orbital Nurse",
			"Neural Care Nurse",
			"Interstellar Nurse"
		],
		{
			"min_age": 18,
			"min_smarts": 50,
			"majors_any": [
				"Interstellar Medicine",
				"Synthetic Biology",
				"Neural Architecture"
			]
		},
		[
			"Clinical Care Associate",
			"Interstellar Nurse",
			"Senior Interstellar Nurse",
			"Charge Nurse",
			"Director of Nursing"
		],
		_nursing_activities(),
		(
			"A future-era nursing profession requiring a "
			+ "completed advanced medical college major."
		)
	)


func _palace_servant_activities() -> Array:
	return [
		_activity(
			"prepare_royal_chambers",
			"Prepare Royal Chambers",
			(
				"Maintain chambers, ceremonial rooms, "
				+ "and private household spaces."
			),
			3,
			3.0,
			1,
			{
				"reliability": 2,
				"efficiency": 1
			},
			"world_traces",
			0
		),
		_activity(
			"carry_palace_messages",
			"Carry Palace Messages",
			(
				"Move sealed messages and instructions "
				+ "between officials and household staff."
			),
			4,
			4.0,
			1,
			{
				"reliability": 2,
				"social": 1
			},
			"world_traces",
			0
		),
		_activity(
			"serve_state_banquet",
			"Serve a State Banquet",
			(
				"Support a formal court gathering where "
				+ "status and protocol matter."
			),
			5,
			7.0,
			2,
			{
				"reliability": 1,
				"social": 2
			},
			"world_traces",
			1
		),
		_activity(
			"manage_household_stores",
			"Manage Household Stores",
			(
				"Track food, linens, tools, and provisions "
				+ "for the palace household."
			),
			6,
			5.0,
			1,
			{
				"efficiency": 2,
				"reliability": 2
			},
			"world_traces",
			1
		)
	]
func _reputation_axis_description(
	axis: String
) -> String:
	match str(axis):
		"reliability":
			return (
				"Whether institutions trust this professional "
				+ "to finish critical work."
			)

		"leadership":
			return (
				"Ability to coordinate people, responsibility, "
				+ "and institutional pressure."
			)

		"kindness":
			return (
				"How humanely this professional treats patients, "
				+ "clients, students, and coworkers."
			)

		"innovation":
			return (
				"Capacity to create techniques, systems, "
				+ "discoveries, and new standards."
			)

		"efficiency":
			return (
				"Ability to produce strong outcomes without "
				+ "wasting time or resources."
			)

		"bravery":
			return (
				"Willingness to act under danger, uncertainty, "
				+ "or professional risk."
			)

		"corruption":
			return (
				"Evidence that authority or professional access "
				+ "has been abused."
			)

		"carelessness":
			return (
				"A record of preventable mistakes and "
				+ "neglected responsibility."
			)

		_:
			return (
				"A persistent professional identity signal."
			)


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)


func _fail(
	reason: String,
	context: Dictionary = {}
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
		"text": (
			"Career contract could not resolve: %s."
			% reason
		),
		"context": context.duplicate(true),
		"ui_is_renderer_only": true
	}