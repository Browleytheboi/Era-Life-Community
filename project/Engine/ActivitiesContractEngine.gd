extends RefCounted
class_name ActivitiesContractEngine

const ENGINE_SCHEMA:= "eralife.activities_contract_engine"
const ENGINE_VERSION:= 1
const HUB_SCHEMA:= "eralife.activities_hub_contract"
const HUB_VERSION:= 1
const LENS_STATE_KEY:= "activities_hub_lens_state"

const CATEGORY_ORDER: Array = [
	"cave_baby",
	"young_survival",
	"tribe_bonds",
	"tribe_survival",
	"featured",
	"markets_assets",
	"companions",
	"public_life",
	"school_youth",
	"supernatural",
	"miscellaneous"
]

const MARKET_ACTIONS: Array = [
	"Trade On The Silk Road",
	"Look For Property",
	"Look For Vehicles",
	"Browse Property Market",
	"Browse Vehicle Market",
	"Review Estates",
	"Manage Holdings",
	"Open To Tenants",
	"Manage Fleet",
	"Assign Driver",
	"Assign Captain",
	"Artifact Shop",
	"Luxury Exchange",
	"View Assets"
]

const SCHOOL_ACTIONS: Array = [
	"Start School",
	"Enroll In Era School",
	"Enroll In Bending School",
	"Dual Enrollment",
	"Interact With Classmates"
]

const SUPERNATURAL_ACTIONS: Array = [
	"Feed",
	"Use Blood Bag",
	"Glamour Target",
	"Join Coven",
	"Found Coven",
	"Seek Cure",
	"Turn Someone",
	"Blood Bond",
	"Investigate Vampire Rumors",
	"Ask To Be Turned",
	"Forge Gauntlet",
	"Become A Super Hero"
]

const PUBLIC_ACTIONS: Array = [
	"Migrate Somewhere",
	"Go to the movies",
	"Go To The Movies"
]

const RETIRED_CAREER_ACTIONS: Array = [
	"Apply for Part Time Job",
	"Browse Part Time Jobs",
	"Apply for Full Time Job",
	"Browse Full Time Jobs",
	"Browse Famous Careers",
	"View Job Details",
	"Work Normally",
	"Work Hard",
	"Slack Off",
	"Ask for Raise",
	"View Coworkers",
	"Quit Job"
]
const DEMO_HIDDEN_ACTIVITY_ACTIONS: Array = [
	"Investigate Vampire Rumors",
	"Ask To Be Turned"
]
const RETIRED_TRAINING_ACTIONS: Array = [
	"Train Bending",
	"Teach Bending",
	"Grant Bending",
	"Remove Bending",
	"Challenge To Bending Duel",
	"Train Boxing",
	"Boxing Sparring",
	"Boxing Hub",
	"Open Boxing Hub",
	"Book Boxing Match",
	"View Boxing Record",
	"View Boxing Rivalries",
	"Call Out Opponent",
	"Change Weight Class",
	"Review Last Fight Log",
	"Enter Amateur Tournament",
	"Start Boxing"
]

var gs
var last_report: Dictionary = {}


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
		return _failure(
			"missing_game_state",
			"Activities state could not be imported."
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


func resolve_intent(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _failure(
			"missing_actor",
			"No Activities observer could be resolved."
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
	var lens: Dictionary = _lens_for(actor)
	var result: Dictionary = {
		"success": true,
		"type": "activities_hub_refreshed"
	}
	var projection_requested: bool = action_id in [
		"",
		"refresh",
		"open_hub",
		"set_section"
	]

	match action_id:
		"", "refresh", "open_hub":
			pass
		"set_section":
			lens ["active_section"] = _section(
				str(
					payload.get(
						"section_id",
						"all"
					)
				)
			)
		"perform_activity":
			result = _perform_activity(
				actor,
				str(
					payload.get(
						"action_label",
						""
					)
				).strip_edges(),
				payload
			)
		_:
			result = _failure(
				"unknown_activities_intent",
				(
					"The Activities contract does not "
					+ "recognize that action."
				)
			)

	_commit_lens(actor, lens)

	if (
		projection_requested
		or bool(
			payload.get(
				"include_projection_after_intent",
				false
			)
		)
	):
		result ["activities_hub_contract"] = emit_hub_contract(
			actor,
			{
				"active_section": str(
					payload.get(
						"section_id",
						lens.get(
							"active_section",
							"all"
						)
					)
				),
				"status_text": str(
					result.get(
						"text",
						""
					)
				),
				"source": (
					"activities_contract_engine.resolve_intent"
				)
			}
		)
		result ["activities_hub_projection_rebuilt"] = true
	else:
		result.erase("activities_hub_contract")
		result ["activities_hub_projection_rebuilt"] = false
		result ["activities_hub_projection_preserved"] = true
		result ["activities_action_input_frame_build"] = false

	result ["activities_contract_engine_owned"] = true
	result ["ui_is_renderer_only"] = true
	last_report = result.duplicate(true)

	return result

func emit_observable_contract(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _partial(
			actor,
			context
		)



	var labels: Array = []
	var seen: Dictionary = {}

	_append_baseline_labels(
		actor,
		labels,
		seen
	)

	var categories: Array = _categorize_labels(
		actor,
		labels
	)
	categories = _merge_mod_activity_provider_categories(
		actor,
		categories,
		{
			"target_id": "activities_hub",
			"active_section": str(
				context.get(
					"active_section",
					"all"
				)
			),
			"source": (
				"activities_contract_engine."
				+ "emit_observable_contract"
			)
		}
	)

	return {
		"success": true,
		"schema": HUB_SCHEMA,
		"version": HUB_VERSION,
		"actor_id": int(
			actor.id
		),
		"actor_name": _person_name(
			actor
		),
		"title": "🎭 ACTIVITIES HUB",
		"subtitle": (
			"Immediate life actions organized by domain."
		),
		"active_section": _section(
			str(
				context.get(
					"active_section",
					"all"
				)
			)
		),
		"identity_overview": _identity_overview(
			actor
		),
		"section_tabs": _section_tabs(
			categories
		),
		"category_rows": categories,
		"status_text": str(
			context.get(
				"status_text",
				(
					"Baseline activities are observable while "
					+ "live opportunities reconcile."
				)
			)
		),
		"truth_state": "observable_partial",
		"authoritative_projection": false,
		"surface_revision": "%d:%d:observable:%d" % [
			int(
				actor.id
			),
			_current_year(),
			labels.size()
		],
		"activity_provider_authority": (
			"mod_contract_engine"
		),
		"activity_execution_authority": (
			ENGINE_SCHEMA
		),
		"ui_is_renderer_only": true
	}
func persist_section_lens(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _failure(
			"missing_actor",
			"No activity observer could be resolved."
		)

	var section_id: String = _section(
		str(
			payload.get(
				"section_id",
				"all"
			)
		)
	)
	var lens: Dictionary = _lens_for(
		actor
	)
	lens ["active_section"] = section_id

	_commit_lens(
		actor,
		lens
	)

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"type": "activities_lens_section_persisted",
		"actor_id": int(
			actor.id
		),
		"active_section": section_id,
		"simulation_mutation_performed": false,
		"ui_is_renderer_only": true
	}
func emit_hub_contract(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	if actor == null or gs == null:
		return _partial(
			actor,
			context
		)

	var lens: Dictionary = _lens_for(
		actor
	)
	var requested_section: String = str(
		context.get(
			"active_section",
			lens.get(
				"active_section",
				"all"
			)
		)
	).strip_edges().to_lower()

	var reality_surface: Dictionary = (
		_active_reality_surface_contract(
			actor,
			context
		)
	)
	var reality_activities: Dictionary = _dict(
		reality_surface.get(
			"activities_contract",
			{}
		)
	)
	var replace_base_catalog: bool = bool(
		reality_activities.get(
			"replace_base_catalog",
			reality_surface.get(
				"replace_base_activity_catalog",
				false
			)
		)
	)

	if replace_base_catalog:
		var replacement_category_rows: Array = (
			_filter_activity_category_rows_for_visibility(
				_array(
					reality_activities.get(
						"category_rows",
						[]
					)
				)
			)
		)
		var replacement_identity: Dictionary = _dict(
			reality_activities.get(
				"identity_overview",
				{}
			)
		)
		var replacement_section: String = (
			_resolve_activity_section_for_categories(
				requested_section,
				replacement_category_rows
			)
		)

		lens ["active_section"] = replacement_section
		_commit_lens(
			actor,
			lens
		)

		return {
			"success": true,
			"schema": HUB_SCHEMA,
			"version": HUB_VERSION,
			"actor_id": int(actor.id),
			"actor_name": _person_name(actor),
			"title": str(
				reality_activities.get(
					"title",
					"     SURVIVAL HUB"
				)
			),
			"subtitle": str(
				reality_activities.get(
					"subtitle",
					"Caveman survival reality"
				)
			),
			"active_section": replacement_section,
			"identity_overview": replacement_identity,
			"section_tabs": _section_tabs(
				replacement_category_rows
			),
			"category_rows": replacement_category_rows,
			"pending_choice_contract": {},
			"status_text": str(
				context.get(
					"status_text",
					"The base activity catalog is dormant while Caveman Reality is active."
				)
			),
			"truth_state": "hot",
			"authoritative_projection": true,
			"surface_revision": str(
				reality_activities.get(
					"surface_revision",
					reality_surface.get(
						"surface_revision",
						""
					)
				)
			),
			"activity_provider_authority": (
				"caveman_reality_runtime_engine"
			),
			"activity_execution_authority": ENGINE_SCHEMA,
			"ui_is_renderer_only": true
		}

	var pending_contract: Dictionary = (
		_pending_choice_contract()
	)
	var using_locked_choices: bool = (
		not pending_contract.is_empty()
	)
	var source_labels: Array = []

	if using_locked_choices:
		source_labels = _array(
			pending_contract.get(
				"opps",
				[]
			)
		)
	elif gs.opportunity_engine != null:
		source_labels = _array(
			gs.opportunity_engine.generate_opportunities(
				actor,
				{
					"surface_id": "activities_hub",
					"exclude_career_opportunities": true,
					"hide_vampire_discovery_actions": true,
					"projection_read_only": true
				}
			)
		)

	var labels: Array = []
	var seen: Dictionary = {}

	for raw_label in source_labels:
		_append_activity_label(
			labels,
			seen,
			str(raw_label)
		)

	_append_baseline_labels(
		actor,
		labels,
		seen
	)

	var category_rows: Array = _categorize_labels(
		actor,
		labels
	)

	category_rows = _merge_mod_activity_provider_categories(
		actor,
		category_rows,
		{
			"target_id": "activities_hub",
			"active_section": requested_section,
			"source": (
				"activities_contract_engine."
				+ "emit_hub_contract"
			)
		}
	)

	category_rows = (
		_filter_activity_category_rows_for_visibility(
			category_rows
		)
	)

	var active_section: String = (
		_resolve_activity_section_for_categories(
			requested_section,
			category_rows
		)
	)

	lens ["active_section"] = active_section
	_commit_lens(
		actor,
		lens
	)

	var status_text: String = str(
		context.get(
			"status_text",
			""
		)
	).strip_edges()

	if status_text == "":
		status_text = (
			"Choose from the currently pending activity options."
			if using_locked_choices
			else "Choose from the activities available to this life."
		)

	return {
		"success": true,
		"schema": HUB_SCHEMA,
		"version": HUB_VERSION,
		"actor_id": int(actor.id),
		"actor_name": _person_name(actor),
		"title": "✦ ACTIVITIES HUB",
		"subtitle": (
			"Contextual life actions for %s during %s."
			% [
				_person_name(actor),
				_era_name()
			]
		),
		"active_section": active_section,
		"identity_overview": _identity_overview(actor),
		"section_tabs": _section_tabs(
			category_rows
		),
		"category_rows": category_rows,
		"pending_choice_contract": pending_contract,
		"using_locked_choices": using_locked_choices,
		"status_text": status_text,
		"truth_state": "hot",
		"authoritative_projection": true,
		"surface_revision": "%d:%d:%s:%d" % [
			int(actor.id),
			_current_year(),
			active_section,
			labels.size()
		],
		"activity_discovery_authority": (
			"opportunity_engine"
		),
		"activity_provider_authority": (
			"mod_contract_engine"
		),
		"activity_execution_authority": ENGINE_SCHEMA,
		"ui_is_renderer_only": true
	}
func _resolve_activity_section_for_categories(
	requested_section: String,
	category_rows: Array
) -> String:
	var clean_section: String = str(
		requested_section
	).strip_edges().to_lower()

	if clean_section == "" or clean_section == "all":
		return "all"

	for raw_category in category_rows:
		var category: Dictionary = _dict(
			raw_category
		)
		var category_id: String = str(
			category.get(
				"id",
				""
			)
		).strip_edges().to_lower()

		if category_id == clean_section:
			return clean_section

	return "all"
func _active_reality_surface_contract(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	if (
		gs == null
		or actor == null
		or gs.caveman_reality_runtime_engine == null
	):
		return {}

	var runtime_state: Dictionary = _dict(
		gs.caveman_reality_runtime_engine.state
	)

	if not bool(
		runtime_state.get(
			"enabled",
			false
		)
	):
		return {}

	return (
		gs.caveman_reality_runtime_engine
		.emit_reality_surface_contract(
			actor,
			{
				"source": str(
					context.get(
						"source",
						"activities_contract_engine"
					)
				)
			}
		)
	)
func _append_baseline_labels(
	actor: Person,
	labels: Array,
	seen: Dictionary
) -> void:
	_append_activity_label(
		labels,
		seen,
		"View Assets"
	)

	if int(actor.age) >= 18:
		_append_activity_label(
			labels,
			seen,
			"Look For Property"
		)
		_append_activity_label(
			labels,
			seen,
			"Look For Vehicles"
		)




	var cached_property_count: int = 0
	var cached_vehicle_count: int = 0

	if (
		gs != null
		and typeof(gs.scenario_state) == TYPE_DICTIONARY
	):
		var rollup_by_actor: Dictionary = _dict(
			gs.scenario_state.get(
				"resident_asset_rollup_by_actor",
				{}
			)
		)
		var actor_rollup: Dictionary = _dict(
			rollup_by_actor.get(
				str(actor.id),
				{}
			)
		)
		cached_property_count = int(
			actor_rollup.get(
				"property_count",
				0
			)
		)
		cached_vehicle_count = int(
			actor_rollup.get(
				"vehicle_count",
				0
			)
		)

	if cached_property_count > 0:
		_append_activity_label(
			labels,
			seen,
			"Review Estates"
		)
		_append_activity_label(
			labels,
			seen,
			"Manage Holdings"
		)

	if cached_vehicle_count > 0:
		_append_activity_label(
			labels,
			seen,
			"Manage Fleet"
		)

	var boxing: Dictionary = _boxing_affordance(actor)

	if bool(boxing.get("visible", false)):
		_append_activity_label(
			labels,
			seen,
			"Begin Boxing"
		)

	if (
		gs.artifacts_engine != null
		and int(actor.age) >= 6
	):
		_append_activity_label(
			labels,
			seen,
			"Artifact Shop"
		)



	if (
		gs != null
		and gs.luxury_shop_engine != null
	):
		_append_activity_label(
			labels,
			seen,
			"Luxury Exchange"
		)

	if (
		gs.artifacts_engine != null
		and gs.has_method("is_feature_enabled")
		and bool(gs.is_feature_enabled("artifacts"))
		and gs.artifacts_engine.has_method("player_has_all")
		and bool(gs.artifacts_engine.player_has_all())
		and not ("GauntletBearer" in actor.traits)
	):
		_append_activity_label(
			labels,
			seen,
			"Forge Gauntlet"
		)

	if _can_become_superhero(actor):
		_append_activity_label(
			labels,
			seen,
			"Become A Super Hero"
		)

	var pet_shop_label: String = _pet_shop_label()

	if pet_shop_label != "":
		_append_activity_label(
			labels,
			seen,
			pet_shop_label
		)

	var meat_market_label: String = _meat_market_label(actor)

	if meat_market_label != "":
		_append_activity_label(
			labels,
			seen,
			meat_market_label
		)

func _append_activity_label(
	labels: Array,
	seen: Dictionary,
	raw_label: String
) -> void:
	var label: String = str(
		raw_label
	).strip_edges()

	if (
		label == ""
		or _label_is_hidden(
			label
		)
		or seen.has(
			label
		)
	):
		return

	seen [label] = true
	labels.append(
		label
	)


func _categorize_labels(
	actor: Person,
	labels: Array
) -> Array:
	var buckets: Dictionary = {}

	for category_id in CATEGORY_ORDER:
		buckets [category_id] = []

	for raw_label in labels:
		var label: String = str(
			raw_label
		).strip_edges()

		if label == "":
			continue



		if (
			label == "Begin Boxing"
			and not bool(
				_boxing_affordance(
					actor
				).get(
					"visible",
					false
				)
			)
		):
			continue

		var category_id: String = _category_for_label(
			actor,
			label
		)
		var bucket: Array = _array(
			buckets.get(
				category_id,
				[]
			)
		)
		bucket.append(
			_action_contract(
				actor,
				label,
				category_id
			)
		)
		buckets [category_id] = bucket

	var rows: Array = []

	for category_id in CATEGORY_ORDER:
		var actions: Array = _array(
			buckets.get(
				category_id,
				[]
			)
		)

		if actions.is_empty():
			continue

		rows.append({
			"id": category_id,
			"label": _category_label(
				category_id
			),
			"icon": _category_icon(
				category_id
			),
			"description": _category_description(
				category_id
			),
			"actions": actions
		})

	return rows

func _presentation_result_for_label(
	actor: Person,
	label: String
) -> Dictionary:
	if actor == null:
		return {}

	if label == _pet_shop_label():
		return {
			"success": true,
			"type": "open_pet_shop_panel",
			"text": "I opened the era-valid companion market.",
			"log_to_diary": false
		}

	if label == _meat_market_label(actor):
		return {
			"success": true,
			"type": "open_meat_market_panel",
			"text": "I opened the local meat market.",
			"log_to_diary": false
		}

	match label:
		"Begin Boxing":
			return {
				"success": true,
				"type": "open_boxing_entry_popup",
				"text": "",
				"log_to_diary": false,
				"popup_title": "Begin Boxing",
				"popup_text": (
					"Choose whether this boxer enters "
					+ "the amateur circuit or starts "
					+ "through the professional path."
				),
				"popup_footer": "Choose a path."
			}

		"View Assets":
			return {
				"success": true,
				"type": "open_assets_panel",
				"text": "I opened my controlled assets.",
				"owner_id": int(actor.id),
				"log_to_diary": false
			}

		"Artifact Shop":
			return {
				"success": true,
				"type": "open_artifact_shop_panel",
				"text": "I opened the artifact market.",
				"log_to_diary": false
			}

		"Luxury Exchange":
			return {
				"success": true,
				"type": "open_luxury_exchange_panel",
				"text": (
					"I entered the resident private-acquisition exchange."
				),
				"log_to_diary": false,
				"ui_is_renderer_only": true
			}

		"Trade On The Silk Road":
			return {
				"success": true,
				"type": "open_silk_road_panel",
				"text": (
					"Choose a trade good for the "
					+ "Silk Road route."
				),
				"log_to_diary": false
			}

		"Look For Property", "Browse Property Market":
			if int(actor.age) < 18:
				return {}
			return {
				"success": true,
				"type": "open_property_market_panel",
				"text": (
					"I looked for property available during %s."
					% _era_name()
				),
				"log_to_diary": false
			}

		"Look For Vehicles", "Browse Vehicle Market":
			if int(actor.age) < 18:
				return {}
			return {
				"success": true,
				"type": "open_vehicle_market_panel",
				"text": (
					"I looked for vehicles available during %s."
					% _era_name()
				),
				"log_to_diary": false
			}

	return {}
func _action_contract(
	actor: Person,
	label: String,
	category_id: String
) -> Dictionary:
	var enabled: bool = true
	var disabled_reason: String = ""
	var eligibility: Dictionary = {}

	if label == "Begin Boxing":
		eligibility = _boxing_affordance(actor)
		enabled = bool(
			eligibility.get(
				"available",
				false
			)
		)
		disabled_reason = str(
			eligibility.get(
				"disabled_reason",
				""
			)
		)
	elif label in [
		"Look For Property",
		"Browse Property Market"
	]:
		enabled = int(actor.age) >= 18

		if not enabled:
			disabled_reason = (
				"Property markets unlock at age 18."
			)
	elif label in [
		"Look For Vehicles",
		"Browse Vehicle Market"
	]:
		enabled = int(actor.age) >= 18

		if not enabled:
			disabled_reason = (
				"Vehicle markets unlock at age 18."
			)
	elif label == "Become A Super Hero":
		enabled = _can_become_superhero(actor)

		if not enabled:
			disabled_reason = (
				"A valid power source and a minimum "
				+ "age of 13 are required."
			)

	var presentation_result: Dictionary = (
		_presentation_result_for_label(
			actor,
			label
		)
	)
	var reveal_prebuilt_surface: bool = (
		enabled
		and not presentation_result.is_empty()
	)

	return {
		"id": _slug(label),
		"action_id": "perform_activity",
		"action_label": label,
		"label": label,
		"icon": _action_icon(label),
		"description": _action_description(label),
		"category_id": category_id,
		"enabled": enabled,
		"disabled_reason": disabled_reason,
		"eligibility": eligibility,
		"intent_mode": (
			"reveal_prebuilt_surface"
			if reveal_prebuilt_surface
			else "authoritative_intent"
		),
		"presentation_result": presentation_result,
		"click_requests_engine": not reveal_prebuilt_surface,
		"destination_surface_prebuilt": reveal_prebuilt_surface,
		"ui_is_renderer_only": true
	}

func _perform_activity(
	actor: Person,
	action_label: String,
	payload: Dictionary
) -> Dictionary:
	if gs == null:
		return _failure(
			"missing_game_state",
			(
				"Activities reality is not available "
				+ "right now."
			)
		)

	var has_mod_provider_contract: bool = (
		typeof(
			payload.get(
				"mod_provider_contract",
				{}
			)
		) == TYPE_DICTIONARY
		and not _dict(
			payload.get(
				"mod_provider_contract",
				{}
			)
		).is_empty()
	)

	if (
		str(
			payload.get(
				"source_kind",
				""
			)
		).strip_edges().to_lower() == "mod_provider"
		or has_mod_provider_contract
	):
		return _perform_mod_provider_activity(
			actor,
			payload
		)

	if action_label == "":
		return _failure(
			"empty_activity",
			"No activity was selected."
		)

	if (
		gs.afterlife_influence_engine != null
		and gs.afterlife_active
		and gs.afterlife_influence_engine.has_pending_choice()
	):
		return (
			gs.afterlife_influence_engine
			.choose_pending_option(
				action_label
			)
		)

	if (
		gs.scenario_engine != null
		and gs.scenario_engine.has_pending_choice()
	):
		return gs.scenario_engine.choose_pending_option(
			action_label
		)

	if action_label == _pet_shop_label():
		return {
			"success": true,
			"type": "open_pet_shop_panel",
			"text": (
				"I opened the era-valid companion market."
			),
			"log_to_diary": false
		}

	if action_label == _meat_market_label(
		actor
	):
		return {
			"success": true,
			"type": "open_meat_market_panel",
			"text": "I opened the local meat market.",
			"log_to_diary": false
		}

	match action_label:
		"Begin Boxing":
			var boxing: Dictionary = _boxing_affordance(
				actor
			)

			if not bool(
				boxing.get(
					"available",
					false
				)
			):
				var boxing_reason: String = str(
					boxing.get(
						"disabled_reason",
						(
							"This life cannot begin "
							+ "boxing right now."
						)
					)
				)

				return {
					"success": false,
					"type": "activity_rejected",
					"text": boxing_reason,
					"popup_title": "Begin Boxing",
					"popup_text": boxing_reason,
					"popup_footer": (
						"Eligibility was resolved by "
						+ "ActivitiesContractEngine."
					)
				}

			return {
				"success": true,
				"type": "open_boxing_entry_popup",
				"text": "",
				"log_to_diary": false,
				"popup_title": "Begin Boxing",
				"popup_text": (
					"Choose whether this boxer enters "
					+ "the amateur circuit or starts "
					+ "through the professional path."
				),
				"popup_footer": "Choose a path."
			}

		"View Assets":
			return {
				"success": true,
				"type": "open_assets_panel",
				"text": "I opened my controlled assets.",
				"owner_id": int(
					actor.id
				),
				"log_to_diary": false
			}

		"Artifact Shop":
			return {
				"success": true,
				"type": "open_artifact_shop_panel",
				"text": "I opened the artifact market.",
				"log_to_diary": false
			}

		"Trade On The Silk Road":
			return {
				"success": true,
				"type": "open_silk_road_panel",
				"text": (
					"Choose a trade good for the "
					+ "Silk Road route."
				),
				"log_to_diary": false
			}

		"Become A Super Hero":
			if not _can_become_superhero(
				actor
			):
				return _failure(
					"superhero_requirements_not_met",
					"I cannot become a super hero yet."
				)

			if (
				gs.superhero_engine == null
				or not gs.superhero_engine.has_method(
					"become_hero"
				)
			):
				return _failure(
					"superhero_engine_unavailable",
					(
						"The SuperHeroEngine is not "
						+ "available right now."
					)
				)

			return gs.superhero_engine.become_hero(
				actor,
				{
					"source": (
						"activities_contract_engine"
					),
					"allow_bending_power_source": true,
					"public_launch": true
				}
			)

		"Forge Gauntlet":
			if gs.artifacts_engine == null:
				return _failure(
					"artifacts_engine_unavailable",
					(
						"The artifacts engine is not "
						+ "available right now."
					)
				)

			if "GauntletBearer" in actor.traits:
				return _failure(
					"gauntlet_already_forged",
					(
						"I have already forged the "
						+ "Infinity Gauntlet."
					)
				)

			if gs.artifacts_engine.forge_gauntlet():
				return {
					"success": true,
					"text": (
						"I have forged the Infinity Gauntlet."
					),
					"popup_title": "Infinity Gauntlet",
					"popup_text": (
						"You have forged the Infinity Gauntlet!"
					),
					"popup_footer": (
						"Tap anywhere to continue."
					)
				}

			return _failure(
				"missing_infinity_stones",
				(
					"I need all 6 Infinity Stones "
					+ "to forge the Gauntlet."
				)
			)

		"Train Bending":
			if (
				gs.player_action_engine != null
				and gs.player_action_engine.has_method(
					"perform"
				)
			):
				return gs.player_action_engine.perform(
					"train_bending"
				)

			return _failure(
				"train_bending_unavailable",
				"Train Bending is not wired right now."
			)

		"Teach Bending", "Grant Bending", "Remove Bending", "Challenge To Bending Duel":
			return _failure(
				"selected_target_required",
				(
					"That action needs a selected target. "
					+ "Use the relationship profile."
				)
			)

		"Look For Property", "Browse Property Market":
			if int(
				actor.age
			) < 18:
				return _failure(
					"property_age_gate",
					"I need to be 18 to look for property."
				)

			return {
				"success": true,
				"type": "open_property_market_panel",
				"text": (
					"I looked for property available during %s."
					% _era_name()
				)
			}

		"Look For Vehicles", "Browse Vehicle Market":
			if int(
				actor.age
			) < 18:
				return _failure(
					"vehicle_age_gate",
					"I need to be 18 to look for vehicles."
				)

			return {
				"success": true,
				"type": "open_vehicle_market_panel",
				"text": (
					"I looked for vehicles available during %s."
					% _era_name()
				)
			}

		"Review Estates":
			if gs.action_discovery_engine != null:
				return (
					gs.action_discovery_engine
					.review_property_portfolio(
						actor
					)
				)

		"Manage Holdings":
			if gs.action_discovery_engine != null:
				return (
					gs.action_discovery_engine
					.manage_property_portfolio(
						actor
					)
				)

		"Open To Tenants":
			if gs.action_discovery_engine != null:
				return (
					gs.action_discovery_engine
					.open_portfolio_to_tenants(
						actor
					)
				)

		"Manage Fleet":
			if gs.action_discovery_engine != null:
				return (
					gs.action_discovery_engine
					.manage_vehicle_portfolio(
						actor
					)
				)

		"Assign Driver":
			if gs.action_discovery_engine != null:
				return (
					gs.action_discovery_engine
					.assign_portfolio_driver(
						actor
					)
				)

		"Assign Captain":
			if gs.action_discovery_engine != null:
				return (
					gs.action_discovery_engine
					.assign_portfolio_captain(
						actor
					)
				)

		"Migrate Somewhere":
			if gs.migration_engine != null:
				return (
					gs.migration_engine
					.open_player_migration_panel(
						actor
					)
				)

			return _failure(
				"migration_engine_unavailable",
				"Migration is not wired right now."
			)

		"Browse Famous Careers":
			return {
				"success": true,
				"type": (
					"open_famous_career_browser_panel"
				),
				"text": (
					"I opened the famous career tracks."
				)
			}

	if (
		gs.opportunity_engine != null
		and gs.opportunity_engine.has_method(
			"resolve_action"
		)
	):
		var opportunity_result: Variant = (
			gs.opportunity_engine.resolve_action(
				action_label
			)
		)

		if (
			typeof(
				opportunity_result
			) == TYPE_DICTIONARY
		):
			var opportunity_report: Dictionary = (
				opportunity_result as Dictionary
			).duplicate(true)

			if not opportunity_report.is_empty():
				return opportunity_report

	if (
		gs.player_action_engine != null
		and gs.player_action_engine.has_method(
			"perform"
		)
	):
		return gs.player_action_engine.perform(
			_normalize_player_action(
				action_label
			)
		)

	return _failure(
		"activity_handler_missing",
		(
			"No action handler is wired yet for: %s"
			% action_label
		)
	)
func _merge_mod_activity_provider_categories(
	actor: Person,
	categories: Array,
	context: Dictionary = {}
) -> Array:
	if (
		gs == null
		or gs.mod_contract_engine == null
		or not gs.mod_contract_engine.has_method(
			"emit_provider_rows"
		)
	):
		return categories

	var provider_rows: Array = (
		gs.mod_contract_engine.emit_provider_rows(
			"activities",
			actor,
			context
		)
	)
	if provider_rows.is_empty():
		return categories

	var out: Array = categories.duplicate(true)
	var category_index: Dictionary = {}
	var seen_action_ids: Dictionary = {}

	for category_position in range(out.size()):
		if typeof(
			out [category_position]
		) != TYPE_DICTIONARY:
			continue

		var category: Dictionary = (
			out [category_position] as Dictionary
		)
		var category_id: String = str(
			category.get(
				"id",
				"miscellaneous"
			)
		).strip_edges().to_lower()
		category_index [category_id] = category_position

		for raw_action in _array(
			category.get(
				"actions",
				[]
			)
		):
			if typeof(raw_action) != TYPE_DICTIONARY:
				continue

			var action: Dictionary = raw_action as Dictionary
			var existing_id: String = str(
				action.get(
					"namespaced_action_id",
					action.get(
						"id",
						action.get(
							"action_id",
							""
						)
					)
				)
			)
			if existing_id != "":
				seen_action_ids [existing_id] = true

	for raw_provider_row in provider_rows:
		if typeof(raw_provider_row) != TYPE_DICTIONARY:
			continue

		var provider_row: Dictionary = (
			raw_provider_row as Dictionary
		).duplicate(true)
		var category_id: String = str(
			provider_row.get(
				"category_id",
				"miscellaneous"
			)
		).strip_edges().to_lower()

		if category_id not in CATEGORY_ORDER:
			category_id = "miscellaneous"

		var namespaced_action_id: String = str(
			provider_row.get(
				"namespaced_action_id",
				""
			)
		).strip_edges()

		if (
			namespaced_action_id == ""
			or seen_action_ids.has(
				namespaced_action_id
			)
		):
			continue

		seen_action_ids [namespaced_action_id] = true

		var action_label: String = str(
			provider_row.get(
				"label",
				provider_row.get(
					"title",
					"Mod Activity"
				)
			)
		).strip_edges()

		provider_row ["id"] = namespaced_action_id
		provider_row ["action_id"] = "perform_activity"
		provider_row ["action_label"] = action_label
		provider_row ["label"] = action_label
		provider_row ["category_id"] = category_id
		provider_row ["enabled"] = bool(
			provider_row.get(
				"enabled",
				true
			)
		)
		provider_row ["disabled_reason"] = str(
			provider_row.get(
				"disabled_reason",
				""
			)
		)
		provider_row ["eligibility"] = _dict(
			provider_row.get(
				"eligibility",
				{}
			)
		)
		provider_row ["mod_provider_contract"] = {
			"canonical_provider_key": str(
				provider_row.get(
					"canonical_provider_key",
					""
				)
			),
			"provider_action_id": str(
				provider_row.get(
					"provider_action_id",
					""
				)
			),
			"namespaced_action_id": namespaced_action_id,
			"mod_id": str(
				provider_row.get(
					"mod_id",
					""
				)
			),
			"provider_id": str(
				provider_row.get(
					"provider_id",
					""
				)
			)
		}
		provider_row ["source_kind"] = "mod_provider"
		provider_row ["ui_is_renderer_only"] = true

		if not category_index.has(category_id):
			out.append({
				"id": category_id,
				"label": _category_label(category_id),
				"icon": _category_icon(category_id),
				"description": (
					_category_description(category_id)
				),
				"actions": []
			})
			category_index [category_id] = out.size() - 1

		var position: int = int(
			category_index.get(
				category_id,
				-1
			)
		)
		if position < 0 or position >= out.size():
			continue

		var target_category: Dictionary = _dict(
			out [position]
		)
		var actions: Array = _array(
			target_category.get(
				"actions",
				[]
			)
		)
		actions.append(provider_row)
		target_category ["actions"] = actions
		out [position] = target_category

	return out


func _perform_mod_provider_activity(
	actor: Person,
	payload: Dictionary
) -> Dictionary:
	if (
		gs == null
		or gs.mod_contract_engine == null
		or not gs.mod_contract_engine.has_method(
			"resolve_provider_intent"
		)
	):
		return _failure(
			"mod_provider_unavailable",
			"That mod activity provider is not currently available."
		)

	var provider_contract: Dictionary = _dict(
		payload.get(
			"mod_provider_contract",
			{}
		)
	)
	var provider_payload: Dictionary = (
		payload.duplicate(true)
	)
	provider_payload ["action_id"] = "provider_intent"
	provider_payload ["canonical_provider_key"] = str(
		provider_contract.get(
			"canonical_provider_key",
			payload.get(
				"canonical_provider_key",
				""
			)
		)
	)
	provider_payload ["provider_action_id"] = str(
		provider_contract.get(
			"provider_action_id",
			payload.get(
				"provider_action_id",
				""
			)
		)
	)
	provider_payload ["namespaced_action_id"] = str(
		provider_contract.get(
			"namespaced_action_id",
			payload.get(
				"namespaced_action_id",
				""
			)
		)
	)
	provider_payload ["source"] = (
		"activities_contract_engine.mod_provider"
	)

	return gs.mod_contract_engine.resolve_provider_intent(
		actor,
		provider_payload
	)
func _pending_choice_contract() -> Dictionary:
	if gs == null:
		return {}

	if (
		gs.afterlife_influence_engine != null
		and gs.afterlife_active
		and gs.afterlife_influence_engine.has_pending_choice()
	):
		return _dict(
			gs.afterlife_influence_engine
			.get_pending_choice_result()
		)

	if (
		gs.scenario_engine != null
		and gs.scenario_engine.has_pending_choice()
	):
		return _dict(
			gs.scenario_engine.get_pending_choice_result()
		)

	return {}


func _boxing_affordance(
	actor: Person
) -> Dictionary:
	var report: Dictionary = {
		"visible": false,
		"available": false,
		"reason": "",
		"minimum_age": 7,
		"actor_age": -1,
		"era_allows": false,
		"disabled_reason": ""
	}

	if actor == null:
		report ["reason"] = "missing_actor"
		report ["disabled_reason"] = (
			"No controlled life is available."
		)
		return report

	report ["actor_age"] = int(
		actor.age
	)

	if not bool(
		actor.alive
	):
		report ["reason"] = "actor_not_alive"
		report ["disabled_reason"] = (
			"This life can no longer begin boxing."
		)
		return report

	var era_key: String = _era_name().to_lower()
	var era_allows: bool = (
		era_key.find(
			"modern"
		) >= 0
		or era_key.find(
			"future"
		) >= 0
	)

	if (
		not era_allows
		and gs.era_engine != null
		and gs.era_engine.has_method(
			"supports_world_title_boxing"
		)
	):
		era_allows = bool(
			gs.era_engine.supports_world_title_boxing()
		)

	report ["era_allows"] = era_allows

	if not era_allows:
		report ["reason"] = "era_not_modern_or_future"
		report ["disabled_reason"] = (
			"Organized boxing careers are not "
			+ "available in this era."
		)
		return report

	var profile: Dictionary = _dict(
		actor.boxing_profile
	)
	var already_started: bool = (
		bool(
			profile.get(
				"is_boxer",
				false
			)
		)
		or bool(
			profile.get(
				"boxing_hub_unlocked",
				false
			)
		)
		or bool(
			profile.get(
				"boxing_career_started_by_player",
				false
			)
		)
		or bool(
			profile.get(
				"turned_pro",
				false
			)
		)
		or bool(
			_dict(
				profile.get(
					"amateur_circuit",
					{}
				)
			).get(
				"is_amateur",
				false
			)
		)
	)

	if (
		already_started
		or bool(
			profile.get(
				"retired",
				false
			)
		)
	):
		report ["reason"] = (
			"boxing_retired"
			if bool(
				profile.get(
					"retired",
					false
				)
			)
			else "boxing_already_started"
		)
		return report



	report ["visible"] = true

	var minimum_age: int = 7

	if (
		gs.boxing_contract_engine != null
		and gs.boxing_contract_engine.has_method(
			"get_boxing_policy"
		)
	):
		minimum_age = int(
			gs.boxing_contract_engine.get_boxing_policy(
				"minimum_boxing_start_age",
				7
			)
		)

	report ["minimum_age"] = minimum_age

	if int(
		actor.age
	) < minimum_age:
		report ["reason"] = "actor_too_young"
		report ["disabled_reason"] = (
			"Boxing unlocks at age %d. Current age: %d."
			% [
				minimum_age,
				int(
					actor.age
				)
			]
		)
		return report

	report ["available"] = true
	report ["reason"] = "available"

	return report


func _can_become_superhero(
	actor: Person
) -> bool:
	if (
		actor == null
		or int(
			actor.age
		) < 13
		or gs.superhero_engine == null
	):
		return false

	if str(
		actor.bending_type
	).strip_edges().to_lower() not in [
		"",
		"none"
	]:
		return true

	if (
		gs.power_engine != null
		and gs.power_engine.has_method(
			"has_superpowers"
		)
	):
		return bool(
			gs.power_engine.has_superpowers(
				actor
			)
		)

	return false


func _pet_shop_label() -> String:
	if (
		gs.pet_shop_contract_engine != null
		and gs.pet_shop_contract_engine.has_method(
			"shop_label_for_current_era"
		)
	):
		return str(
			gs.pet_shop_contract_engine
			.shop_label_for_current_era()
		).strip_edges()

	return "Pet Shop"


func _meat_market_label(
	actor: Person
) -> String:
	if (
		actor == null
		or gs.meat_market_contract_engine == null
	):
		return ""

	if not (
		gs.meat_market_contract_engine
		.available_in_current_era()
	):
		return ""

	return str(
		gs.meat_market_contract_engine
		.market_label_for_actor(
			actor
		)
	).strip_edges()


func _label_is_hidden(
	action_label: String
) -> bool:
	var clean_label: String = str(
		action_label
	).strip_edges()
	var lowered: String = clean_label.to_lower()

	if clean_label == "":
		return true

	for raw_hidden_label in DEMO_HIDDEN_ACTIVITY_ACTIONS:
		var hidden_label: String = str(
			raw_hidden_label
		).strip_edges().to_lower()

		if (
			hidden_label != ""
			and lowered == hidden_label
		):
			return true

	if clean_label == "Begin Boxing":
		return false

	if clean_label in RETIRED_CAREER_ACTIONS:
		return true

	if clean_label in RETIRED_TRAINING_ACTIONS:
		return true

	if lowered.find(
		"career"
	) >= 0:
		return true

	if lowered.find(
		"job"
	) >= 0:
		return true

	if lowered.find(
		"coworker"
	) >= 0:
		return true

	if (
		lowered.find(
			"work "
		) >= 0
		or lowered == "work"
	):
		return true

	if lowered.find(
		"train"
	) >= 0:
		return true

	if lowered.find(
		"sparring"
	) >= 0:
		return true

	return false
func _filter_activity_category_rows_for_visibility(
	category_rows: Array
) -> Array:
	var out: Array = []

	for raw_category in category_rows:
		if typeof(
			raw_category
		) != TYPE_DICTIONARY:
			continue

		var category: Dictionary = (
			(raw_category as Dictionary).duplicate(
				true
			)
		)
		var actions_raw: Variant = category.get(
			"actions",
			[]
		)
		var actions: Array = (
			actions_raw as Array
			if typeof(actions_raw) == TYPE_ARRAY
			else []
		)
		var visible_actions: Array = []

		for raw_action in actions:
			if typeof(
				raw_action
			) != TYPE_DICTIONARY:
				continue

			var action: Dictionary = (
				raw_action as Dictionary
			)
			var action_label: String = str(
				action.get(
					"action_label",
					action.get(
						"label",
						action.get(
							"title",
							""
						)
					)
				)
			).strip_edges()

			if _label_is_hidden(
				action_label
			):
				continue





			var mod_provider_contract: Dictionary = _dict(
				action.get(
					"mod_provider_contract",
					{}
				)
			)
			var provenance_text: String = (
				"%s %s %s %s %s %s %s"
				% [
					str(
						action.get(
							"source_kind",
							""
						)
					),
					str(
						action.get(
							"category_id",
							""
						)
					),
					str(
						action.get(
							"namespaced_action_id",
							""
						)
					),
					str(
						mod_provider_contract.get(
							"canonical_provider_key",
							""
						)
					),
					str(
						mod_provider_contract.get(
							"provider_action_id",
							""
						)
					),
					str(
						mod_provider_contract.get(
							"provider_id",
							""
						)
					),
					action_label
				]
			).strip_edges().to_lower()

			var career_provenance: bool = false

			for career_marker in [
				"career",
				"job",
				"workplace"
			]:
				if provenance_text.find(
					str(
						career_marker
					)
				) >= 0:
					career_provenance = true
					break

			if career_provenance:
				continue

			visible_actions.append(
				action.duplicate(
					true
				)
			)

		if visible_actions.is_empty():
			continue

		category ["actions"] = visible_actions

		out.append(
			category
		)

	return out

func _category_for_label(
	actor: Person,
	action_label: String
) -> String:
	var lower_label: String = (
		action_label.to_lower()
	)

	if _is_pet_shop_label(
		lower_label
	):
		return "companions"

	if action_label == _meat_market_label(
		actor
	):
		return "markets_assets"

	if _is_meat_market_label(
		lower_label
	):
		return "markets_assets"

	if action_label in MARKET_ACTIONS:
		return "markets_assets"

	if action_label in SCHOOL_ACTIONS:
		return "school_youth"

	if action_label in SUPERNATURAL_ACTIONS:
		return "supernatural"

	if action_label in PUBLIC_ACTIONS:
		return "public_life"

	if action_label == "Begin Boxing":
		return "featured"

	return "miscellaneous"


func _section_tabs(
	categories: Array
) -> Array:
	var tabs: Array = [{
		"id": "all",
		"label": "ALL ACTIVITIES",
		"icon": "✦"
	}]

	for raw_category in categories:
		var category: Dictionary = _dict(
			raw_category
		)

		tabs.append({
			"id": str(
				category.get(
					"id",
					""
				)
			),
			"label": str(
				category.get(
					"label",
					"ACTIVITIES"
				)
			).to_upper(),
			"icon": str(
				category.get(
					"icon",
					"•"
				)
			)
		})

	return tabs


func _identity_overview(
	actor: Person
) -> Dictionary:
	return {
		"actor_id": int(
			actor.id
		),
		"name": _person_name(
			actor
		),
		"age": int(
			actor.age
		),
		"era_name": _era_name(),
		"year": _current_year(),
		"location": _location_text(
			actor
		),
		"ui_is_renderer_only": true
	}


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
	var actor_name: String = _person_name(
		actor
	)
	var categories: Array = []

	for category_id in CATEGORY_ORDER:
		categories.append({
			"id": category_id,
			"label": _category_label(
				category_id
			),
			"icon": _category_icon(
				category_id
			),
			"description": _category_description(
				category_id
			),
			"actions": []
		})

	return {
		"success": true,
		"schema": HUB_SCHEMA,
		"version": HUB_VERSION,
		"actor_id": actor_id,
		"actor_name": actor_name,
		"title": "🎭 ACTIVITIES HUB",
		"subtitle": (
			"Immediate life actions organized by domain."
		),
		"active_section": _section(
			str(
				context.get(
					"active_section",
					"all"
				)
			)
		),
		"identity_overview": {
			"actor_id": actor_id,
			"name": actor_name,
			"age": (
				int(
					actor.age
				)
				if actor != null
				else 0
			),
			"era_name": _era_name(),
			"year": _current_year(),
			"location": (
				_location_text(
					actor
				)
				if actor != null
				else "Current Reality"
			),
			"ui_is_renderer_only": true
		},
		"section_tabs": _section_tabs(
			categories
		),
		"category_rows": categories,
		"status_text": str(
			context.get(
				"status_text",
				(
					"Activity reality already exists "
					+ "and is observable."
				)
			)
		),
		"truth_state": "observable_partial",
		"authoritative_projection": false,
		"ui_is_renderer_only": true
	}


func _normalize_player_action(
	action_label: String
) -> String:
	match action_label:
		"Go to the movies", "Go To The Movies":
			return "go_to_the_movies"

		"Start School":
			return "start_school"

		"Enroll In Era School":
			return "enroll_in_era_school"

		"Enroll In Bending School":
			return "enroll_in_bending_school"

		"Dual Enrollment":
			return "dual_enrollment"

		"Interact With Classmates":
			return "interact_with_classmates"

		_:
			return (
				action_label
				.to_lower()
				.replace(
					" ",
					"_"
				)
			)


func _category_label(
	category_id: String
) -> String:
	match category_id:
		"featured":
			return "Featured"

		"markets_assets":
			return "Markets & Assets"

		"companions":
			return "Companions"

		"public_life":
			return "Public Life"

		"school_youth":
			return "School & Youth"

		"supernatural":
			return "Supernatural"

		_:
			return "Miscellaneous"


func _category_icon(
	category_id: String
) -> String:
	match category_id:
		"featured":
			return "✦"

		"markets_assets":
			return "🏛"

		"companions":
			return "🐾"

		"public_life":
			return "🌍"

		"school_youth":
			return "🎓"

		"supernatural":
			return "✨"

		_:
			return "◈"


func _category_description(
	category_id: String
) -> String:
	match category_id:
		"featured":
			return (
				"High-signal actions for this life."
			)

		"markets_assets":
			return (
				"Markets, property, vehicles, "
				+ "holdings, and trade."
			)

		"companions":
			return (
				"Animals, pets, mounts, and "
				+ "companion markets."
			)

		"public_life":
			return (
				"Places, travel, entertainment, "
				+ "and public movement."
			)

		"school_youth":
			return (
				"Education and age-contextual youth actions."
			)

		"supernatural":
			return (
				"Powers, artifacts, vampires, "
				+ "and mythic routes."
			)

		_:
			return (
				"Contextual actions that belong nowhere else."
			)


func _action_icon(
	action_label: String
) -> String:
	if action_label == "Begin Boxing":
		return "🥊"

	if action_label in [
		"Look For Property",
		"Browse Property Market"
	]:
		return "🏠"

	if action_label in [
		"Look For Vehicles",
		"Browse Vehicle Market"
	]:
		return "🚗"

	if action_label == "View Assets":
		return "📦"

	if action_label == "Artifact Shop":
		return "🏺"
	if action_label == "Luxury Exchange":
		return "◆"
	if action_label == "Forge Gauntlet":
		return "♾"

	if action_label == "Become A Super Hero":
		return "🦸"

	if action_label in SCHOOL_ACTIONS:
		return "🎓"

	if action_label in PUBLIC_ACTIONS:
		return "🌍"

	return "▶"


func _action_description(
	action_label: String
) -> String:
	match action_label:
		"Begin Boxing":
			return "Enter an era-valid organized boxing path."
		"View Assets":
			return "Inspect controlled property, vehicles, and holdings."
		"Look For Property", "Browse Property Market":
			return "Inspect era-valid property listings."
		"Look For Vehicles", "Browse Vehicle Market":
			return "Inspect era-valid mobility listings."
		"Review Estates", "Manage Holdings":
			return "Review and manage controlled real-estate holdings."
		"Manage Fleet":
			return "Review and manage controlled vehicles."
		"Artifact Shop":
			return "Enter the artifact market available in this reality."
		"Luxury Exchange":
			return (
				"Enter the era-aware private market for exceptional "
				+ "objects and cross-authority acquisitions."
			)
		"Forge Gauntlet":
			return "Attempt to forge the Infinity Gauntlet."
		"Become A Super Hero":
			return (
				"Establish a public heroic identity "
				+ "from a valid power source."
			)
		_:
			return "Perform %s." % action_label


func _is_pet_shop_label(
	lower_label: String
) -> bool:
	return (
		lower_label.find(
			"pet shop"
		) >= 0
		or lower_label.find(
			"animal market"
		) >= 0
		or lower_label.find(
			"companion"
		) >= 0
	)


func _is_meat_market_label(
	lower_label: String
) -> bool:
	return (
		lower_label.find(
			"meat market"
		) >= 0
		or lower_label.find(
			"butcher"
		) >= 0
		or lower_label.find(
			"protein market"
		) >= 0
	)


func _location_text(
	actor: Person
) -> String:
	var location_parts: Array = []

	for value in [
		actor.home_city,
		actor.home_country
	]:
		var text: String = str(
			value
		).strip_edges()

		if (
			text != ""
			and text not in location_parts
		):
			location_parts.append(
				text
			)

	return (
		", ".join(
			location_parts
		)
		if not location_parts.is_empty()
		else "Current Reality"
	)


func _person_name(
	actor: Person
) -> String:
	if actor == null:
		return "Unknown Life"

	var full_name: String = "%s %s" % [
		actor.first_name,
		actor.last_name
	]
	full_name = full_name.strip_edges()

	return (
		full_name
		if full_name != ""
		else "Life #%d" % int(
			actor.id
		)
	)


func _era_name() -> String:
	if (
		gs == null
		or gs.era == null
	):
		return "the current era"

	var name_value: String = str(
		gs.era.get(
			"name"
		)
	).strip_edges()

	return (
		name_value
		if name_value != ""
		else "the current era"
	)


func _current_year() -> int:
	return (
		int(
			gs.year
		)
		if gs != null
		else 0
	)


func _section(
	value: String
) -> String:
	var clean: String = str(
		value
	).strip_edges().to_lower()

	if (
		clean == "all"
		or clean in CATEGORY_ORDER
	):
		return clean

	return "all"


func _ensure_lens_root() -> void:
	if gs == null:
		return

	if typeof(
		gs.scenario_state
	) != TYPE_DICTIONARY:
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

	if gs == null:
		return {}

	return gs.scenario_state.get(
		LENS_STATE_KEY,
		{}
	)


func _lens_for(
	actor: Person
) -> Dictionary:
	var root: Dictionary = _lens_root()
	var key: String = str(
		int(
			actor.id
		)
	)
	var lens: Dictionary = _dict(
		root.get(
			key,
			{}
		)
	)

	if lens.is_empty():
		lens = {
			"active_section": "all"
		}

	return lens


func _commit_lens(
	actor: Person,
	lens: Dictionary
) -> void:
	if (
		gs == null
		or actor == null
	):
		return

	var root: Dictionary = _lens_root()

	root [
		str(
			int(
				actor.id
			)
		)
	] = lens.duplicate(true)

	gs.scenario_state [LENS_STATE_KEY] = root


func _slug(
	value: String
) -> String:
	return (
		str(
			value
		)
		.strip_edges()
		.to_lower()
		.replace(
			" ",
			"_"
		)
	)


func _dict(
	value: Variant
) -> Dictionary:
	if typeof(
		value
	) == TYPE_DICTIONARY:
		return (
			value as Dictionary
		).duplicate(true)

	return {}


func _array(
	value: Variant
) -> Array:
	if typeof(
		value
	) == TYPE_ARRAY:
		return (
			value as Array
		).duplicate(true)

	return []


func _failure(
	reason: String,
	text: String
) -> Dictionary:
	EraLog.failure(
		get_script().resource_path.get_file(),
		str(reason)
	)
	return {
		"success": false,
		"type": "activities_contract_failure",
		"reason": reason,
		"text": text,
		"popup_title": "Activities",
		"popup_text": text,
		"popup_footer": "Tap anywhere to continue.",
		"ui_is_renderer_only": true
	}