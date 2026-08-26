extends Resource
class_name ContractViewLayerContractEngine

const ENGINE_STATE_SCHEMA:= "eralife.contract_view_layer_contract_engine_state"
const VIEW_CONTRACT_SCHEMA:= "eralife.contract_view_layer.view_contract"
const DECISION_CONTRACT_SCHEMA:= "eralife.contract_view_layer.decision_contract"
const CONTRACT_VERSION:= 1

var gs
var view_contracts: Dictionary = {}
var decision_contracts: Dictionary = {}
var collision_contracts: Dictionary = {}
var emotional_impact_contracts: Dictionary = {}
var relationship_dna_index: Dictionary = {}
var relationship_memory_ledger: Array = []
var future_behavior_intents: Dictionary = {}

const EMOTIONAL_IMPACT_SCHEMA:= "eralife.relationship_emotional_impact_contract"
const RELATIONSHIP_DNA_SCHEMA:= "eralife.relationship_dna_snapshot"
const FUTURE_BEHAVIOR_INTENT_SCHEMA:= "eralife.relationship_future_behavior_intent"
const MAX_EMOTIONAL_IMPACT_CONTRACTS:= 240
const MAX_RELATIONSHIP_MEMORY_LEDGER:= 600
const MAX_FUTURE_BEHAVIOR_INTENTS:= 300
var observation_log: Array = []
var mutation_log: Array = []
var last_report: Dictionary = {}



var state_hydrated: bool = false


func _init(_gs = null):
	gs = _gs
	_ensure_state()


func _ensure_state() -> void:
	if gs == null:
		return

	if state_hydrated:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	view_contracts = _safe_dictionary(
		gs.scenario_state.get(
			"contract_view_layer_view_contracts",
			view_contracts
		)
	)
	decision_contracts = _safe_dictionary(
		gs.scenario_state.get(
			"contract_view_layer_decision_contracts",
			decision_contracts
		)
	)
	collision_contracts = _safe_dictionary(
		gs.scenario_state.get(
			"contract_view_layer_collision_contracts",
			collision_contracts
		)
	)
	observation_log = _safe_array(
		gs.scenario_state.get(
			"contract_view_layer_observation_log",
			observation_log
		)
	)
	mutation_log = _safe_array(
		gs.scenario_state.get(
			"contract_view_layer_mutation_log",
			mutation_log
		)
	)

	emotional_impact_contracts = _safe_dictionary(
		gs.scenario_state.get(
			"relationship_emotional_impact_contracts",
			emotional_impact_contracts
		)
	)
	relationship_dna_index = _safe_dictionary(
		gs.scenario_state.get(
			"relationship_dna_index",
			relationship_dna_index
		)
	)
	relationship_memory_ledger = _safe_array(
		gs.scenario_state.get(
			"relationship_memory_ledger",
			relationship_memory_ledger
		)
	)
	future_behavior_intents = _safe_dictionary(
		gs.scenario_state.get(
			"relationship_future_behavior_intents",
			future_behavior_intents
		)
	)

	_repair_state()

	state_hydrated = true



	_commit_state()

func export_state() -> Dictionary:
	_ensure_state()
	return {
		"schema": ENGINE_STATE_SCHEMA,
		"version": CONTRACT_VERSION,
		"view_contracts": view_contracts.duplicate(true),
		"decision_contracts": decision_contracts.duplicate(true),
		"collision_contracts": collision_contracts.duplicate(true),
		"observation_log": observation_log.duplicate(true),
		"mutation_log": mutation_log.duplicate(true),
		"emotional_impact_contracts": emotional_impact_contracts.duplicate(true),
		"relationship_dna_index": relationship_dna_index.duplicate(true),
		"relationship_memory_ledger": relationship_memory_ledger.duplicate(true),
		"future_behavior_intents": future_behavior_intents.duplicate(true),
		"last_report": last_report.duplicate(true),
		"exported_at_ms": int(Time.get_ticks_msec())
	}


func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "invalid_data"
		}

	view_contracts = _safe_dictionary(data.get("view_contracts", {}))
	decision_contracts = _safe_dictionary(data.get("decision_contracts", {}))
	collision_contracts = _safe_dictionary(data.get("collision_contracts", {}))
	observation_log = _safe_array(data.get("observation_log", []))
	mutation_log = _safe_array(data.get("mutation_log", []))
	emotional_impact_contracts = _safe_dictionary(data.get("emotional_impact_contracts", data.get("relationship_emotional_impact_contracts", {})))
	relationship_dna_index = _safe_dictionary(data.get("relationship_dna_index", {}))
	relationship_memory_ledger = _safe_array(data.get("relationship_memory_ledger", []))
	future_behavior_intents = _safe_dictionary(data.get("future_behavior_intents", data.get("relationship_future_behavior_intents", {})))
	last_report = _safe_dictionary(data.get("last_report", {}))

	_repair_state()
	_commit_state()

	last_report = {
		"success": true,
		"mode": "contract_view_layer_imported",
		"schema": ENGINE_STATE_SCHEMA,
		"version": CONTRACT_VERSION,
		"view_count": view_contracts.size(),
		"decision_count": decision_contracts.size(),
		"collision_count": collision_contracts.size(),
		"emotional_impact_count": emotional_impact_contracts.size(),
		"relationship_dna_pair_count": relationship_dna_index.size(),
		"future_behavior_intent_count": future_behavior_intents.size(),
		"repaired": true
	}

	return last_report.duplicate(true)

func _view_projection_semantic_revision(
	source_contract: Dictionary,
	viewer_id: int,
	perspective: String
) -> String:
	if source_contract.is_empty():
		return ""

	return str(
		hash(
			[
				str(
					source_contract.get(
						"id",
						source_contract.get(
							"contract_id",
							""
						)
					)
				),
				viewer_id,
				perspective,
				str(
					source_contract.get(
						"state",
						"pending"
					)
				),
				str(
					source_contract.get(
						"category",
						"general"
					)
				),
				float(
					source_contract.get(
						"urgency",
						0.0
					)
				),
				int(
					source_contract.get(
						"escalation_stage",
						0
					)
				),
				int(
					source_contract.get(
						"remaining_response_seconds",
						-1
					)
				),
				hash(
					source_contract.get(
						"response_options",
						[]
					)
				),
				hash(
					source_contract.get(
						"perspective_views",
						{}
					)
				),
				str(
					source_contract.get(
						"selected_response",
						""
					)
				),
				hash(
					source_contract.get(
						"resolution",
						{}
					)
				)
			]
		)
	)


func _commit_view_projection_row(
	view_id: String,
	view_contract: Dictionary
) -> void:
	if (
		gs == null
		or view_id == ""
		or view_contract.is_empty()
	):
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var registry_raw: Variant = gs.scenario_state.get(
		"contract_view_layer_view_contracts",
		{}
	)
	var registry: Dictionary = (
		registry_raw as Dictionary
		if typeof(registry_raw) == TYPE_DICTIONARY
		else {}
	)










	registry [view_id] = view_contract.duplicate(true)

	gs.scenario_state [
		"contract_view_layer_view_contracts"
	] = registry
func build_view_contract(
	source_contract: Dictionary,
	viewer: Person,
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	if (
		typeof(source_contract) != TYPE_DICTIONARY
		or source_contract.is_empty()
	):
		return {}

	var source_id: String = str(
		source_contract.get(
			"id",
			source_contract.get(
				"contract_id",
				""
			)
		)
	).strip_edges()

	if source_id == "":
		return {}

	var viewer_id: int = (
		int(viewer.id)
		if viewer != null
		else int(
			context.get(
				"viewer_actor_id",
				-1
			)
		)
	)
	var perspective: String = _perspective_for_viewer(
		source_contract,
		viewer
	)
	var view_id: String = (
		"view_%s_%d"
		% [
			source_id,
			viewer_id
		]
	)
	var semantic_revision: String = (
		_view_projection_semantic_revision(
			source_contract,
			viewer_id,
			perspective
		)
	)

	var existing_raw: Variant = view_contracts.get(
		view_id,
		{}
	)
	var existing_view: Dictionary = (
		existing_raw as Dictionary
		if typeof(existing_raw) == TYPE_DICTIONARY
		else {}
	)









	if (
		not existing_view.is_empty()
		and str(
			existing_view.get(
				"projection_semantic_revision",
				""
			)
		) == semantic_revision
	):
		var cached_view: Dictionary = (
			existing_view.duplicate(true)
		)
		cached_view [
			"resident_view_contract_cache_hit"
		] = true
		cached_view [
			"projection_rebuild_performed"
		] = false
		cached_view [
			"full_state_commit_performed"
		] = false
		return cached_view

	var perspective_views: Dictionary = _safe_dictionary(
		source_contract.get(
			"perspective_views",
			{}
		)
	)
	var view_data: Dictionary = _safe_dictionary(
		perspective_views.get(
			perspective,
			perspective_views.get(
				"self",
				{}
			)
		)
	)

	if (
		view_data.is_empty()
		and perspective in [
			"mother",
			"father",
			"guardian"
		]
	):
		view_data = _safe_dictionary(
			perspective_views.get(
				"guardian",
				{}
			)
		)

	var title: String = str(
		view_data.get(
			"title",
			source_contract.get(
				"title",
				"Pending Situation"
			)
		)
	)
	var overview: String = str(
		view_data.get(
			"overview",
			source_contract.get(
				"overview",
				""
			)
		)
	)
	var details: String = str(
		view_data.get(
			"details",
			source_contract.get(
				"details",
				overview
			)
		)
	)
	var response_options: Array = _safe_array(
		view_data.get(
			"response_options",
			source_contract.get(
				"response_options",
				[]
			)
		)
	)

	var trait_action_report: Dictionary = {}

	if (
		gs != null
		and "traits_contract_engine" in gs
		and gs.traits_contract_engine != null
	):
		var before_trait_option_count: int = (
			response_options.size()
		)
		response_options = (
			gs.traits_contract_engine
			.trait_action_options_for_actor(
				viewer,
				source_contract,
				response_options,
				{
					"source": (
						"contract_view_layer_build_view_contract"
					),
					"viewer_actor_id": viewer_id,
					"perspective": perspective,
					"source_contract_id": source_id
				}
			)
		)
		trait_action_report = {
			"success": true,
			"before_count": before_trait_option_count,
			"after_count": response_options.size(),
			"added_count": max(
				0,
				response_options.size()
				- before_trait_option_count
			)
		}

	var identity_profile: Dictionary = {}

	if (
		gs != null
		and "identity_contract_engine" in gs
		and gs.identity_contract_engine != null
		and viewer_id > 0
	):
		identity_profile = (
			gs.identity_contract_engine
			.get_identity_profile(
				viewer_id
			)
		)

	var created_at_ms: int = int(
		existing_view.get(
			"created_at_ms",
			Time.get_ticks_msec()
		)
	)

	var view_contract: Dictionary = {
		"schema": VIEW_CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": source_id,
		"contract_id": source_id,
		"view_contract_id": view_id,
		"source_contract_id": source_id,
		"contract_type": "contract_view",
		"viewer_actor_id": viewer_id,
		"perspective": perspective,
		"title": title,
		"overview": overview,
		"details": details,
		"category": str(
			source_contract.get(
				"category",
				"general"
			)
		),
		"urgency": float(
			source_contract.get(
				"urgency",
				0.0
			)
		),
		"state": str(
			source_contract.get(
				"state",
				"pending"
			)
		),
		"response_options": response_options,
		"trait_action_report": trait_action_report.duplicate(true),
		"identity_profile": identity_profile.duplicate(true),
		"information_control": _safe_dictionary(
			view_data.get(
				"information_control",
				{
					"truth_level": "actor_perspective",
				}
			)
		),
		"source_contract": source_contract.duplicate(true),
		"projection_semantic_revision": semantic_revision,
		"resident_view_contract_cache_hit": false,
		"projection_rebuild_performed": true,
		"full_state_commit_performed": false,
		"created_at_ms": created_at_ms,
		"updated_at_ms": int(
			Time.get_ticks_msec()
		),
		"contract_mesh": {
			"source_of_truth": (
				"ContractViewLayerContractEngine"
			),
			"source_contract_owner": (
				"ScenarioRuntimeContractEngine"
			),
			"pending_index_owner": (
				"PendingSituationsEngine"
			),
			"trait_action_owner": (
				"TraitsContractEngine"
			),
			"identity_owner": (
				"IdentityContractEngine"
			),
			"one_contract_multiple_views": true,
			"ui_observer": "PopupViewer",
			"ui_mutation_allowed": false,
			"persistent": true,
			"save_key": (
				"contract_view_layer_contract_engine_state"
			)
		}
	}

	view_contract = (
		_apply_latest_shared_decision_echo_to_view(
			view_contract,
			source_contract,
			viewer_id
		)
	)

	view_contracts [view_id] = view_contract

	_record_observation(
		source_id,
		viewer_id,
		perspective
	)



	_commit_view_projection_row(
		view_id,
		view_contract
	)

	return view_contract.duplicate(true)

func resolve_view_choice(source_contract: Dictionary, actor_id: int, option_id: String, payload: Dictionary = {}) -> Dictionary:
	_ensure_state()

	if typeof(source_contract) != TYPE_DICTIONARY or source_contract.is_empty():
		return {
			"success": false,
			"reason": "missing_source_contract"
		}

	var source_id: String = str(source_contract.get("id", source_contract.get("contract_id", ""))).strip_edges()
	if source_id == "":
		return {
			"success": false,
			"reason": "missing_source_contract_id"
		}

	var actor: Person = _actor_by_id(actor_id)
	var perspective: String = _perspective_for_viewer(source_contract, actor)
	var view_contract: Dictionary = build_view_contract(source_contract, actor, payload)

	var option: Dictionary = _option_for_view(view_contract, option_id)
	var source_resolves: bool = bool(option.get("source_resolves", _default_source_resolves_for_perspective(perspective, option_id)))
	var priority: int = int(option.get("priority", _priority_for_perspective(perspective)))
	var diary_records: Array = _diary_records_for_view_choice(source_contract, actor, perspective, option, option_id)

	var emotional_impact_contract: Dictionary = _build_emotional_impact_contract_for_view_choice(source_contract, actor, perspective, option, option_id, diary_records, payload)
	var emotional_application_report: Dictionary = _apply_emotional_impact_contract(emotional_impact_contract)

	var trait_growth_report: Dictionary = {}
	var traits_engine = _safe_object_property(gs, "traits_contract_engine", null)
	if traits_engine != null and traits_engine.has_method("apply_choice_contract") and actor != null:
		trait_growth_report = traits_engine.apply_choice_contract(actor, source_contract, option, {
			"source": "contract_view_layer_resolve_view_choice",
			"source_contract_id": source_id,
			"option_id": str(option_id),
			"emotional_application_report": emotional_application_report.duplicate(true),
			"emotional_impact_contract": emotional_impact_contract.duplicate(true),
			"payload": payload.duplicate(true)
		})

	var identity_report: Dictionary = {}
	var identity_engine = _safe_object_property(gs, "identity_contract_engine", null)
	if identity_engine != null and identity_engine.has_method("refresh_identity_for_actor") and actor != null:
		identity_report = identity_engine.refresh_identity_for_actor(actor, {
			"source": "contract_view_layer_resolve_view_choice",
			"source_contract_id": source_id,
			"option_id": str(option_id),
			"trait_growth_report": trait_growth_report.duplicate(true)
		})

	var decision_id: String = "decision_%s_%d_%s_%d" % [source_id, actor_id, str(option_id), int(Time.get_ticks_msec())]
	var decision_contract: Dictionary = {
		"schema": DECISION_CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": decision_id,
		"contract_id": decision_id,
		"source_contract_id": source_id,
		"actor_id": actor_id,
		"actor_name": _actor_first_name(actor),
		"perspective": perspective,
		"option_id": str(option_id),
		"option": option.duplicate(true),
		"source_resolves": source_resolves,
		"priority": priority,
		"state": "recorded",
		"diary_records": diary_records.duplicate(true),
		"emotional_impact_contract": emotional_impact_contract.duplicate(true),
		"emotional_application_report": emotional_application_report.duplicate(true),
		"trait_growth_report": trait_growth_report.duplicate(true),
		"identity_report": identity_report.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec()),
		"updated_at_ms": int(Time.get_ticks_msec()),
		"contract_mesh": {
			"source_of_truth": "ContractViewLayerContractEngine",
			"collision_resolution": "highest_priority_then_latest",
		}
	}

	decision_contracts [decision_id] = decision_contract
	var collision_report: Dictionary = _rebuild_collision_contract_for_source(source_id)

	_record_mutation(source_id, "view_choice_recorded", {
		"actor_id": actor_id,
		"perspective": perspective,
		"option_id": str(option_id),
		"source_resolves": source_resolves,
		"priority": priority,
		"diary_record_count": diary_records.size(),
		"emotional_impact_count": int(emotional_application_report.get("applied_update_count", 0)),
		"future_behavior_intent_count": int(emotional_application_report.get("future_behavior_intent_count", 0)),
		"trait_changed_count": _safe_array(trait_growth_report.get("changed_traits", [])).size(),
		"identity_refreshed": bool(identity_report.get("success", false))
	})

	_commit_state()

	return {
		"success": true,
		"mode": "view_choice_recorded",
		"source_contract_id": source_id,
		"decision_contract_id": decision_id,
		"perspective": perspective,
		"option_id": str(option_id),
		"source_resolves": source_resolves,
		"priority": priority,
		"collision_report": collision_report.duplicate(true),
		"diary_records": diary_records.duplicate(true),
		"emotional_impact_contract": emotional_impact_contract.duplicate(true),
		"emotional_application_report": emotional_application_report.duplicate(true),
		"relationship_dna_updates": _safe_array(emotional_application_report.get("relationship_dna_updates", [])),
		"future_behavior_intents": _safe_array(emotional_application_report.get("future_behavior_intents", [])),
		"trait_growth_report": trait_growth_report.duplicate(true),
		"identity_report": identity_report.duplicate(true),
		"text": str(option.get("journal_text", "I responded from my perspective.")),
		"popup_title": str(option.get("popup_title", "Perspective Recorded")),
		"popup_text": str(option.get("result_text", "Your choice was recorded, but the shared situation may still continue.")),
		"popup_footer": str(option.get("popup_footer", "Tap anywhere to continue."))
	}
func _diary_records_for_view_choice(source_contract: Dictionary, actor: Person, perspective: String, option: Dictionary, option_id: String) -> Array:
	var out: Array = []
	var actor_id: int = int(actor.id) if actor != null else -1
	if actor_id <= 0:
		return out

	var actor_name: String = _diary_actor_name_for_sentence(actor, "the baby")
	var option_label: String = str(option.get("label", str(option_id).capitalize())).strip_edges()
	if option_label == "":
		option_label = str(option_id).capitalize()

	var source_title: String = _diary_source_title_for_actor(source_contract, actor_id)
	if source_title == "":
		source_title = "the situation"

	var participant_ids: Array = _diary_actor_ids_for_source_contract(source_contract)
	if actor_id not in participant_ids:
		participant_ids.append(actor_id)

	for raw_actor_id in participant_ids:
		var diary_actor_id: int = int(raw_actor_id)
		if diary_actor_id <= 0:
			continue

		var text: String = ""
		if diary_actor_id == actor_id:
			text = _diary_text_for_decision_actor(source_title, option, option_label)
		else:
			var observer: Person = _actor_by_id(diary_actor_id)
			text = _diary_text_for_decision_observer(source_contract, source_title, observer, actor, option, str(option_id), option_label)

		text = str(text).strip_edges()
		if text == "":
			continue

		out.append({
			"actor_id": diary_actor_id,
			"text": text,
			"life_diary_text": text,
			"source_contract_id": str(source_contract.get("id", source_contract.get("contract_id", ""))),
			"decision_actor_id": actor_id,
			"decision_actor_name": actor_name,
			"perspective": str(perspective),
			"option_id": str(option_id),
			"option_label": option_label,
			"recorded_at_ms": int(Time.get_ticks_msec())
		})

	return out

func _diary_actor_ids_for_source_contract(source_contract: Dictionary) -> Array:
	var out: Array = []

	var key_order: Array = [
		"participant_ids",
		"decision_actor_ids",
		"audience_ids",
		"parent_ids",
		"involved_actor_ids",
		"subject_actor_ids",
		"recipient_actor_ids",
		"observer_ids"
	]

	for key in key_order:
		var ids: Array = _safe_array(source_contract.get(str(key), []))
		for raw_id in ids:
			var actor_id: int = int(raw_id)
			if actor_id > 0 and actor_id not in out:
				out.append(actor_id)

	var direct_key_order: Array = [
		"target_id",
		"target",
		"issuer_id",
		"issuer",
		"featured_relative_id",
		"featured_actor_id",
		"subject_actor_id",
		"recipient_actor_id",
		"responder_actor_id",
		"other_actor_id"
	]

	for raw_key in direct_key_order:
		var key: String = str(raw_key)
		var actor_id: int = int(source_contract.get(key, -1))
		if actor_id > 0 and actor_id not in out:
			out.append(actor_id)

	var role_map: Dictionary = _safe_dictionary(source_contract.get("perspective_actor_roles", {}))
	for raw_role_key in role_map.keys():
		var actor_id: int = int(str(raw_role_key))
		if actor_id > 0 and actor_id not in out:
			out.append(actor_id)

	return out

func _diary_text_for_decision_actor(source_title: String, option: Dictionary, option_label: String) -> String:
	var direct_text: String = str(option.get("journal_text", option.get("life_diary_text", option.get("diary_text", "")))).strip_edges()
	if direct_text != "":
		return direct_text

	return "I chose \"%s\" while dealing with %s." % [option_label, source_title]


func _diary_text_for_decision_observer(source_contract: Dictionary, source_title: String, observer: Person, decision_actor: Person, option: Dictionary, option_id: String, option_label: String) -> String:
	var observer_id: int = int(observer.id) if observer != null else -1
	var decision_actor_id: int = int(decision_actor.id) if decision_actor != null else -1
	var decision_actor_name: String = _diary_actor_name_for_sentence(decision_actor, "the baby")

	var request_key: String = str(source_contract.get("request", "")).strip_edges().to_lower()
	if request_key == "newborn_sibling_attention":
		return _newborn_sibling_observer_diary_text(source_contract, observer, decision_actor, option, option_id, option_label)

	var role_map: Dictionary = _safe_dictionary(source_contract.get("perspective_actor_roles", {}))
	var observer_role: String = str(role_map.get(str(observer_id), "observer")).strip_edges().to_lower()
	var relation_label: String = _relationship_label_for_other_actor(source_contract, observer_id, decision_actor_id)

	if observer_role == "child":
		return "I heard %s choose \"%s\" while the adults were dealing with %s." % [decision_actor_name, option_label, source_title]

	if relation_label == "partner":
		return "I watched my partner %s choose \"%s\" while we were dealing with %s." % [decision_actor_name, option_label, source_title]

	if relation_label in ["mother", "father", "guardian"]:
		return "I saw my %s %s choose \"%s\" while we were dealing with %s." % [relation_label, decision_actor_name, option_label, source_title]

	return "I saw %s choose \"%s\" while we were dealing with %s." % [decision_actor_name, option_label, source_title]
func _newborn_sibling_observer_diary_text(source_contract: Dictionary, observer: Person, decision_actor: Person, option: Dictionary, option_id: String, option_label: String) -> String:
	var observer_id: int = int(observer.id) if observer != null else -1
	var baby_id: int = int(decision_actor.id) if decision_actor != null else int(source_contract.get("target_id", source_contract.get("target", -1)))
	if observer_id <= 0 or baby_id <= 0 or observer_id == baby_id:
		return _diary_text_for_decision_actor(_diary_source_title_for_actor(source_contract, baby_id), option, option_label)

	var baby: Person = decision_actor
	if baby == null:
		baby = _actor_by_id(baby_id)

	var sibling_id: int = _newborn_featured_sibling_id_from_source_contract(source_contract, baby_id)
	var sibling: Person = _actor_by_id(sibling_id)

	if sibling_id <= 0 or sibling == null:
		var fallback_baby_relation: String = _baby_sibling_relation_for_observer(baby)
		var fallback_baby_name: String = _diary_actor_name_for_sentence(baby, "the baby")
		var fallback_reaction_phrase: String = _newborn_option_observer_phrase(str(option_id), option_label, "me")
		return "I saw my newborn %s %s %s after I stared at them in their crib." % [fallback_baby_relation, fallback_baby_name, fallback_reaction_phrase]

	var role_map: Dictionary = _safe_dictionary(source_contract.get("perspective_actor_roles", {}))
	var observer_role: String = str(role_map.get(str(observer_id), "observer")).strip_edges().to_lower()

	var baby_name: String = _diary_actor_name_for_sentence(baby, "the baby")
	var sibling_name: String = _diary_actor_name_for_sentence(sibling, "my sibling")
	var baby_object_pronoun: String = _actor_object_pronoun_for_sentence(baby)
	var baby_possessive_pronoun: String = _actor_possessive_pronoun_for_sentence(baby)
	var feeling_sentence: String = _newborn_observer_feeling_sentence(observer_role, str(option_id))

	if observer_id == sibling_id or observer_role in ["brother", "sister", "sibling", "featured_sibling"]:
		var baby_relation: String = _baby_sibling_relation_for_observer(baby)
		var sibling_reaction_phrase: String = _newborn_option_observer_phrase(str(option_id), option_label, "me")
		return "I saw my newborn %s %s %s after I stared at %s in %s crib. %s" % [
			baby_relation,
			baby_name,
			sibling_reaction_phrase,
			baby_object_pronoun,
			baby_possessive_pronoun,
			feeling_sentence
		]

	if observer_role in ["mother", "father", "guardian"]:
		var baby_child_relation: String = _actor_child_relation_label_for_sentence(baby)
		var sibling_child_relation: String = _actor_child_relation_label_for_sentence(sibling)
		var sibling_reference: String = ("my %s %s" % [sibling_child_relation, sibling_name]).strip_edges()
		var parent_reaction_phrase: String = _newborn_option_observer_phrase(str(option_id), option_label, sibling_reference)
		return "I saw my %s %s %s from %s crib after %s kept staring at %s. %s" % [
			baby_child_relation,
			baby_name,
			parent_reaction_phrase,
			baby_possessive_pronoun,
			sibling_name,
			baby_object_pronoun,
			feeling_sentence
		]

	var observer_baby_relation: String = _baby_sibling_relation_for_observer(baby)
	var observer_sibling_relation: String = _baby_sibling_relation_for_observer(sibling)
	var observer_sibling_reference: String = ("my %s %s" % [observer_sibling_relation, sibling_name]).strip_edges()
	var observer_reaction_phrase: String = _newborn_option_observer_phrase(str(option_id), option_label, observer_sibling_reference)
	return "I saw my newborn %s %s %s from %s crib after %s kept staring at %s. %s" % [
		observer_baby_relation,
		baby_name,
		observer_reaction_phrase,
		baby_possessive_pronoun,
		sibling_name,
		baby_object_pronoun,
		feeling_sentence
	]

func _newborn_option_observer_phrase(option_id: String, option_label: String, target_phrase: String = "me") -> String:
	var clean_option: String = str(option_id).strip_edges().to_lower()
	var clean_target: String = str(target_phrase).strip_edges()
	if clean_target == "":
		clean_target = "me"

	match clean_option:
		"blink_slowly":
			return "blink slowly at %s" % clean_target
		"start_crying":
			return "start crying"
		"stare_back":
			return "stare back at %s" % clean_target
		"smile":
			return "smile at %s" % clean_target
		"look_confused":
			return "look confused"
		"fall_asleep":
			return "fall asleep"
		"tiny_sneeze":
			return "sneeze"
		_:
			var label: String = str(option_label).strip_edges()
			if label == "":
				label = "respond"
			return "respond with \"%s\"" % label

func _newborn_featured_sibling_id_from_source_contract(source_contract: Dictionary, baby_id: int) -> int:
	var role_map: Dictionary = _safe_dictionary(source_contract.get("perspective_actor_roles", {}))

	for raw_key in role_map.keys():
		var actor_id: int = int(str(raw_key))
		if actor_id <= 0 or actor_id == baby_id:
			continue

		var role: String = str(role_map.get(raw_key, "")).strip_edges().to_lower()
		if role in ["brother", "sister", "sibling", "featured_sibling"]:
			return actor_id

	var parent_ids: Array = _safe_array(source_contract.get("parent_ids", []))
	var participant_ids: Array = _safe_array(source_contract.get("participant_ids", []))
	for raw_participant_id in participant_ids:
		var actor_id: int = int(raw_participant_id)
		if actor_id <= 0 or actor_id == baby_id:
			continue
		if actor_id in parent_ids:
			continue
		return actor_id

	var audience_ids: Array = _safe_array(source_contract.get("audience_ids", []))
	for raw_audience_id in audience_ids:
		var actor_id: int = int(raw_audience_id)
		if actor_id > 0 and actor_id != baby_id:
			return actor_id

	return -1


func _actor_child_relation_label_for_sentence(actor: Person) -> String:
	if actor == null:
		return "child"

	var gender_key: String = str(actor.gender).strip_edges().to_lower()
	if gender_key == "female":
		return "daughter"
	if gender_key == "male":
		return "son"
	return "child"


func _actor_object_pronoun_for_sentence(actor: Person) -> String:
	if actor == null:
		return "them"

	var gender_key: String = str(actor.gender).strip_edges().to_lower()
	if gender_key == "female":
		return "her"
	if gender_key == "male":
		return "him"
	return "them"


func _actor_possessive_pronoun_for_sentence(actor: Person) -> String:
	if actor == null:
		return "their"

	var gender_key: String = str(actor.gender).strip_edges().to_lower()
	if gender_key == "female":
		return "her"
	if gender_key == "male":
		return "his"
	return "their"


func _newborn_observer_feeling_sentence(observer_role: String, option_id: String) -> String:
	var clean_role: String = str(observer_role).strip_edges().to_lower()
	var clean_option: String = str(option_id).strip_edges().to_lower()

	if clean_role in ["brother", "sister", "sibling", "featured_sibling"]:
		match clean_option:
			"smile":
				return "I felt less suspicious, even if I did not understand why."
			"blink_slowly":
				return "I felt confused, but a little less tense."
			"stare_back":
				return "I felt challenged, like the crib had answered me."
			"start_crying":
				return "I felt startled and suddenly responsible for the noise."
			_:
				return "I felt like the tiny moment mattered more than I expected."

	if clean_role in ["mother", "father", "guardian"]:
		match clean_option:
			"smile":
				return "I felt relieved watching the tension soften."
			"blink_slowly":
				return "I felt amused and a little protective."
			"stare_back":
				return "I felt the room get funny and tense at the same time."
			"start_crying":
				return "I felt worried and hurried to understand what happened."
			_:
				return "I felt protective watching both of them react to each other."

	match clean_option:
		"smile":
			return "It made the room feel a little softer."
		"blink_slowly":
			return "It made the moment feel strange, but harmless."
		"stare_back":
			return "It made the crib feel like the center of the room."
		"start_crying":
			return "It made everyone suddenly pay attention."
		_:
			return "It felt like one of those tiny family moments that still mattered."
func _baby_sibling_relation_for_observer(actor: Person) -> String:
	if actor == null:
		return "sibling"

	var gender_key: String = str(actor.gender).strip_edges().to_lower()
	if gender_key == "female":
		return "sister"
	if gender_key == "male":
		return "brother"

	return "sibling"


func _diary_actor_name_for_sentence(actor: Person, fallback: String = "someone") -> String:
	if actor == null:
		return fallback

	var first_name: String = str(actor.first_name).strip_edges()
	if first_name != "" and first_name.to_lower() not in ["i", "me", "my", "you", "your"]:
		return first_name

	var full_name: String = str(actor.name).strip_edges()
	if full_name != "":
		var first_part: String = str(full_name.split(" ") [0]).strip_edges()
		if first_part != "" and first_part.to_lower() not in ["i", "me", "my", "you", "your"]:
			return first_part

	return fallback


func _diary_source_title_for_actor(source_contract: Dictionary, actor_id: int) -> String:
	var request_key: String = str(source_contract.get("request", "")).strip_edges().to_lower()
	if request_key == "newborn_sibling_attention":
		var target_id: int = int(source_contract.get("target_id", source_contract.get("target", -1)))
		if actor_id == target_id:
			return str(source_contract.get("title", "my sibling staring at me in my crib")).strip_edges()
		return "the new baby being home"

	return str(source_contract.get("title", "the situation")).strip_edges()

func _perspective_for_viewer(source_contract: Dictionary, viewer: Person) -> String:
	if viewer == null:
		return "self"

	var actor_id: int = int(viewer.id)
	var actor_key: String = str(actor_id)
	var role_map: Dictionary = _safe_dictionary(source_contract.get("perspective_actor_roles", {}))

	if role_map.has(actor_key):
		var mapped_role: String = str(role_map.get(actor_key, "self")).strip_edges().to_lower()
		if mapped_role != "":
			return mapped_role

	var target_id: int = int(source_contract.get("target_id", source_contract.get("target", -1)))
	if actor_id == target_id:
		if int(viewer.age) < 13:
			return "child"
		return "self"

	var parent_ids: Array = _safe_array(source_contract.get("parent_ids", []))
	for raw_parent_id in parent_ids:
		if int(raw_parent_id) == actor_id:
			var gender_key: String = str(viewer.gender).strip_edges().to_lower()
			if gender_key == "female":
				return "mother"
			if gender_key == "male":
				return "father"
			return "guardian"

	var participant_ids: Array = _safe_array(source_contract.get("participant_ids", []))
	if actor_id in participant_ids:
		return "participant"

	return "observer"
func _apply_latest_shared_decision_echo_to_view(view_contract: Dictionary, source_contract: Dictionary, viewer_id: int) -> Dictionary:
	var out: Dictionary = view_contract.duplicate(true)
	var source_id: String = str(source_contract.get("id", source_contract.get("contract_id", ""))).strip_edges()
	if source_id == "" or viewer_id <= 0:
		return out

	var latest_decision: Dictionary = _latest_parent_decision_for_source(source_id, viewer_id)
	if latest_decision.is_empty():
		return out

	var option: Dictionary = _safe_dictionary(latest_decision.get("option", {}))
	var other_actor_id: int = int(latest_decision.get("actor_id", -1))
	var other_name: String = str(latest_decision.get("actor_name", "")).strip_edges()
	if other_name == "":
		other_name = _first_name_for_actor_id(other_actor_id)

	var option_label: String = str(option.get("label", latest_decision.get("option_id", "responded"))).strip_edges()
	var relation_label: String = _relationship_label_for_other_actor(source_contract, viewer_id, other_actor_id)

	var follow_up_views: Dictionary = _safe_dictionary(source_contract.get("follow_up_views", source_contract.get("reply_views", {})))
	var perspective: String = str(out.get("perspective", "self")).strip_edges().to_lower()
	var follow_up_data: Dictionary = _safe_dictionary(follow_up_views.get(perspective, follow_up_views.get("default", {})))

	var tokens: Dictionary = {
		"other_first_name": other_name,
		"other_relation": relation_label,
		"option_label": option_label
	}

	if follow_up_data.is_empty():
		out ["title"] = "%s responded to the argument..." % other_name
		out ["overview"] = "%s chose \"%s\". What will you do?" % [other_name, option_label]
		out ["details"] = "%s %s responded with \"%s\". The situation is still alive, and now it is your turn to respond." % [relation_label.capitalize(), other_name, option_label]
		return out

	out ["title"] = _template_text(str(follow_up_data.get("title", out.get("title", ""))), tokens)
	out ["overview"] = _template_text(str(follow_up_data.get("overview", out.get("overview", ""))), tokens)
	out ["details"] = _template_text(str(follow_up_data.get("details", out.get("details", out.get("overview", "")))), tokens)

	var follow_up_options: Array = _safe_array(follow_up_data.get("response_options", []))
	if not follow_up_options.is_empty():
		out ["response_options"] = follow_up_options

	return out


func _latest_parent_decision_for_source(source_id: String, viewer_id: int) -> Dictionary:
	var best: Dictionary = {}
	var best_ms: int = -1

	for raw_decision_id in decision_contracts.keys():
		var decision: Dictionary = _safe_dictionary(decision_contracts.get(raw_decision_id, {}))
		if str(decision.get("source_contract_id", "")) != source_id:
			continue

		var actor_id: int = int(decision.get("actor_id", -1))
		if actor_id <= 0 or actor_id == viewer_id:
			continue

		var perspective: String = str(decision.get("perspective", "")).strip_edges().to_lower()
		if perspective not in ["mother", "father", "guardian", "participant"]:
			continue

		var updated_ms: int = int(decision.get("updated_at_ms", decision.get("created_at_ms", 0)))
		if updated_ms > best_ms:
			best_ms = updated_ms
			best = decision.duplicate(true)

	return best


func _template_text(template: String, tokens: Dictionary) -> String:
	var out: String = str(template)
	for raw_key in tokens.keys():
		var key: String = str(raw_key)
		out = out.replace("{%s}" % key, str(tokens.get(raw_key, "")))
	return out


func _relationship_label_for_other_actor(source_contract: Dictionary, viewer_id: int, other_actor_id: int) -> String:
	var roles: Dictionary = _safe_dictionary(source_contract.get("perspective_actor_roles", {}))
	var viewer_role: String = str(roles.get(str(viewer_id), "")).strip_edges().to_lower()
	var other_role: String = str(roles.get(str(other_actor_id), "")).strip_edges().to_lower()

	if viewer_role in ["mother", "father", "guardian"] and other_role in ["mother", "father", "guardian"]:
		return "partner"
	if other_role in ["mother", "father", "guardian"]:
		return other_role
	if other_role in ["brother", "sister", "sibling"]:
		return other_role
	if other_role == "featured_sibling":
		return "sibling"
	if other_role in ["child", "subject", "recipient", "participant"]:
		return other_role
	return "person"

func _first_name_for_actor_id(actor_id: int) -> String:
	var actor: Person = _actor_by_id(actor_id)
	return _actor_first_name(actor)


func _actor_first_name(actor: Person) -> String:
	if actor == null:
		return "Someone"

	var first_name: String = str(actor.first_name).strip_edges()
	if first_name != "":
		return first_name

	var full_name: String = str(actor.name).strip_edges()
	if full_name != "":
		return full_name.split(" ") [0]

	return "Someone"
func _rebuild_collision_contract_for_source(source_id: String) -> Dictionary:
	var decisions: Array = []
	for raw_decision_id in decision_contracts.keys():
		var decision: Dictionary = _safe_dictionary(decision_contracts.get(raw_decision_id, {}))
		if str(decision.get("source_contract_id", "")) == source_id:
			decisions.append(decision)

	decisions.sort_custom(Callable(self, "_sort_decisions_by_priority"))

	var winning_decision: Dictionary = {}
	if not decisions.is_empty():
		winning_decision = decisions [0]

	var collision_id: String = "collision_%s" % source_id
	var collision_contract: Dictionary = {
		"schema": "eralife.contract_view_layer.collision_contract",
		"version": CONTRACT_VERSION,
		"id": collision_id,
		"contract_id": collision_id,
		"source_contract_id": source_id,
		"decision_count": decisions.size(),
		"winning_decision": winning_decision.duplicate(true),
		"decisions": decisions.duplicate(true),
		"policy": "highest_priority_then_latest",
		"state": "active",
		"updated_at_ms": int(Time.get_ticks_msec())
	}

	collision_contracts [collision_id] = collision_contract
	return collision_contract


func _sort_decisions_by_priority(a: Dictionary, b: Dictionary) -> bool:
	var priority_a: int = int(a.get("priority", 0))
	var priority_b: int = int(b.get("priority", 0))
	if priority_a == priority_b:
		return int(a.get("created_at_ms", 0)) > int(b.get("created_at_ms", 0))
	return priority_a > priority_b


func _option_for_view(view_contract: Dictionary, option_id: String) -> Dictionary:
	var options: Array = _safe_array(view_contract.get("response_options", []))
	for raw_option in options:
		if typeof(raw_option) != TYPE_DICTIONARY:
			continue

		var option: Dictionary = raw_option as Dictionary
		if str(option.get("id", "")).strip_edges() == str(option_id).strip_edges():
			return option.duplicate(true)

	# FIX: do NOT set "source_resolves" here. resolve_view_choice() reads it with
	# option.get("source_resolves", _default_source_resolves_for_perspective(...)),
	# so hardcoding false meant any option whose id wasn't found in the view contract
	# could never resolve the situation. Omitting the key lets the perspective default
	# apply instead.
	return {
		"id": str(option_id),
		"label": str(option_id).capitalize()
	}


func _default_source_resolves_for_perspective(perspective: String, option_id: String) -> bool:
	var clean_perspective: String = str(perspective).strip_edges().to_lower()
	var clean_option: String = str(option_id).strip_edges().to_lower()

	# FIX: the actor the situation is ABOUT always resolves it. "self" and "child"
	# previously fell through to `return false`, so the player's own choice was filed
	# as a perspective record ("the shared situation still exists"), the narration
	# played, and the situation stayed pending forever. This check must come before
	# the option blacklist below, or picking "ignore" on your own situation would
	# still leave it stuck in the list.
	if clean_perspective in ["self", "child"]:
		return true

	if clean_option in ["ignore", "avoid_situation", "stay_quiet", "ask_whats_wrong", "try_to_help", "argue"]:
		return false

	if clean_perspective in ["mother", "father", "guardian"]:
		return true

	return false


func _priority_for_perspective(perspective: String) -> int:
	match str(perspective).strip_edges().to_lower():
		"mother":
			return 80
		"father":
			return 78
		"guardian":
			return 76
		"self":
			return 50
		"child":
			return 20
		_:
			return 10


func _record_observation(source_id: String, actor_id: int, perspective: String) -> void:
	observation_log.append({
		"source_contract_id": source_id,
		"actor_id": actor_id,
		"perspective": perspective,
		"observed_at_ms": int(Time.get_ticks_msec())
	})

	if observation_log.size() > 240:
		observation_log = observation_log.slice(observation_log.size() - 240, observation_log.size())


func _record_mutation(source_id: String, mutation_type: String, payload: Dictionary = {}) -> void:
	mutation_log.append({
		"source_contract_id": source_id,
		"mutation_type": mutation_type,
		"payload": payload.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec())
	})

	if mutation_log.size() > 240:
		mutation_log = mutation_log.slice(mutation_log.size() - 240, mutation_log.size())

func _build_emotional_impact_contract_for_view_choice(source_contract: Dictionary, actor: Person, perspective: String, option: Dictionary, option_id: String, diary_records: Array, payload: Dictionary = {}) -> Dictionary:
	if typeof(source_contract) != TYPE_DICTIONARY or source_contract.is_empty():
		return {}
	if actor == null:
		return {}

	var source_id: String = str(source_contract.get("id", source_contract.get("contract_id", ""))).strip_edges()
	if source_id == "":
		return {}

	var actor_id: int = int(actor.id)
	var impact_id: String = "emotional_impact_%s_%d_%s_%d" % [source_id, actor_id, str(option_id), int(Time.get_ticks_msec())]
	var relationship_updates: Array = []
	var seen_pairs: Dictionary = {}

	var participant_ids: Array = _diary_actor_ids_for_source_contract(source_contract)
	for raw_record in diary_records:
		if typeof(raw_record) != TYPE_DICTIONARY:
			continue
		var record_actor_id: int = int((raw_record as Dictionary).get("actor_id", -1))
		if record_actor_id > 0 and record_actor_id not in participant_ids:
			participant_ids.append(record_actor_id)

	if actor_id not in participant_ids:
		participant_ids.append(actor_id)

	for raw_owner_id in participant_ids:
		var owner_id: int = int(raw_owner_id)
		if owner_id <= 0:
			continue

		var target_id: int = actor_id
		if owner_id == actor_id:
			target_id = _primary_other_actor_id_for_impact(source_contract, actor_id)

		if target_id <= 0 or target_id == owner_id:
			continue

		var pair_key: String = _relationship_dna_key(owner_id, target_id)
		if bool(seen_pairs.get(pair_key, false)):
			continue
		seen_pairs [pair_key] = true

		var owner: Person = _actor_by_id(owner_id)
		var target: Person = _actor_by_id(target_id)
		if owner == null or target == null:
			continue

		var update: Dictionary = _relationship_update_from_view_choice(source_contract, owner, target, actor, perspective, option, option_id, payload)
		if update.is_empty():
			continue

		relationship_updates.append(update)

	if relationship_updates.is_empty():
		return {}

	return {
		"schema": EMOTIONAL_IMPACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": impact_id,
		"contract_id": impact_id,
		"source_contract_id": source_id,
		"decision_actor_id": actor_id,
		"decision_actor_name": _actor_first_name(actor),
		"perspective": str(perspective),
		"option_id": str(option_id),
		"option_label": str(option.get("label", str(option_id).capitalize())),
		"request": str(source_contract.get("request", "")),
		"category": str(source_contract.get("category", "relationship")),
		"created_year": int(source_contract.get("created_year", gs.year if gs != null else 0)),
		"created_age": float(source_contract.get("created_age", actor.age)),
		"relationship_updates": relationship_updates.duplicate(true),
		"payload": payload.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec()),
		"updated_at_ms": int(Time.get_ticks_msec()),
		"contract_mesh": {
			"source_of_truth": "ContractViewLayerContractEngine",
			"source_contract_owner": str(source_contract.get("contract_mesh", {}).get("source_of_truth", "unknown")) if typeof(source_contract.get("contract_mesh", {})) == TYPE_DICTIONARY else "unknown",
			"ui_mutation_allowed": false,
			"persistent": true,
			"save_key": "relationship_emotional_impact_contracts"
		}
	}


func _relationship_update_from_view_choice(source_contract: Dictionary, owner: Person, target: Person, decision_actor: Person, perspective: String, option: Dictionary, option_id: String, payload: Dictionary = {}) -> Dictionary:
	if owner == null or target == null:
		return {}

	var owner_id: int = int(owner.id)
	var target_id: int = int(target.id)
	if owner_id <= 0 or target_id <= 0 or owner_id == target_id:
		return {}

	var owner_role: String = _perspective_for_viewer(source_contract, owner)
	var target_role: String = _perspective_for_viewer(source_contract, target)
	var dna_delta: Dictionary = _emotional_delta_map_for_view_choice(source_contract, owner, target, decision_actor, owner_role, target_role, perspective, option, option_id, payload)
	if dna_delta.is_empty():
		return {}

	var emotion_changes: Array = []
	for raw_key in dna_delta.keys():
		var emotion_key: String = str(raw_key).strip_edges().to_lower()
		if emotion_key == "":
			continue
		var delta_value: float = float(dna_delta.get(raw_key, 0.0))
		if abs(delta_value) < 0.01:
			continue
		emotion_changes.append({
			"emotion": emotion_key,
			"delta": delta_value
		})

	if emotion_changes.is_empty():
		return {}

	return {
		"schema": "eralife.relationship_emotional_update",
		"version": CONTRACT_VERSION,
		"owner_actor_id": owner_id,
		"owner_actor_name": _actor_first_name(owner),
		"target_actor_id": target_id,
		"target_actor_name": _actor_first_name(target),
		"decision_actor_id": int(decision_actor.id) if decision_actor != null else -1,
		"decision_actor_name": _actor_first_name(decision_actor),
		"owner_role": owner_role,
		"target_role": target_role,
		"perspective": str(perspective),
		"emotion_changes": emotion_changes.duplicate(true),
		"relationship_dna_delta": dna_delta.duplicate(true),
		"relationship_delta": _relationship_affection_delta_from_dna_delta(dna_delta),
		"request": str(source_contract.get("request", "")),
		"category": str(source_contract.get("category", "relationship")),
		"option_id": str(option_id),
		"option_label": str(option.get("label", str(option_id).capitalize())),
		"era_context": _era_key_for_source_contract(source_contract),
		"source": "contract_view_layer_emotional_impact",
		"created_year": int(source_contract.get("created_year", gs.year if gs != null else 0)),
		"created_at_ms": int(Time.get_ticks_msec())
	}


func _emotional_delta_map_for_view_choice(source_contract: Dictionary, owner: Person, target: Person, decision_actor: Person, owner_role: String, target_role: String, perspective: String, option: Dictionary, option_id: String, payload: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}

	_merge_emotional_delta_map(out, _emotional_delta_map_from_option(option))
	_merge_emotional_delta_map(out, _emotional_delta_map_from_source_rules(source_contract, owner, target, decision_actor, owner_role, target_role, perspective, option, option_id, payload))

	if out.is_empty():
		_merge_emotional_delta_map(out, _fallback_emotional_delta_map(source_contract, owner, target, decision_actor, owner_role, target_role, option, option_id))

	out = _apply_era_emotional_flavor_to_delta_map(out, source_contract)
	return _clean_emotional_delta_map(out)


func _emotional_delta_map_from_option(option: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	if typeof(option) != TYPE_DICTIONARY:
		return out

	_merge_emotional_delta_map(out, _safe_dictionary(option.get("relationship_dna_delta", {})))
	_merge_emotional_delta_map(out, _safe_dictionary(option.get("emotional_impact", {})))
	_merge_emotional_delta_map(out, _safe_dictionary(option.get("emotion_delta", {})))
	_merge_emotional_delta_map(out, _safe_dictionary(option.get("emotional_delta", {})))

	var emotion_changes: Array = _safe_array(option.get("emotion_changes", []))
	for raw_change in emotion_changes:
		if typeof(raw_change) != TYPE_DICTIONARY:
			continue
		var change: Dictionary = raw_change as Dictionary
		var emotion_key: String = str(change.get("emotion", change.get("key", ""))).strip_edges().to_lower()
		if emotion_key == "":
			continue
		out [emotion_key] = float(out.get(emotion_key, 0.0)) + float(change.get("delta", 0.0))

	return out


func _emotional_delta_map_from_source_rules(source_contract: Dictionary, owner: Person, _target: Person, decision_actor: Person, owner_role: String, _target_role: String, _perspective: String, _option: Dictionary, option_id: String, _payload: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}
	var request_key: String = str(source_contract.get("request", "")).strip_edges().to_lower()
	var clean_option: String = str(option_id).strip_edges().to_lower()
	var owner_id: int = int(owner.id) if owner != null else -1
	var decision_actor_id: int = int(decision_actor.id) if decision_actor != null else -1

	var contract_rules: Dictionary = _safe_dictionary(source_contract.get("emotional_impact_rules", {}))
	if not contract_rules.is_empty():
		var by_option: Dictionary = _safe_dictionary(contract_rules.get("by_option", {}))
		_merge_emotional_delta_map(out, _safe_dictionary(by_option.get(clean_option, {})))

		var by_role: Dictionary = _safe_dictionary(contract_rules.get("by_owner_role", contract_rules.get("by_role", {})))
		_merge_emotional_delta_map(out, _safe_dictionary(by_role.get(str(owner_role).strip_edges().to_lower(), {})))

		var default_rules: Dictionary = _safe_dictionary(contract_rules.get("default", {}))
		_merge_emotional_delta_map(out, default_rules)

	if request_key == "newborn_sibling_attention":
		if owner_id == decision_actor_id:
			match clean_option:
				"smile":
					_merge_emotional_delta_map(out, { "trust": 2, "comfort": 3, "curiosity": 4, "affection": 3})
				"blink_slowly":
					_merge_emotional_delta_map(out, { "curiosity": 5, "comfort": 1})
				"stare_back":
					_merge_emotional_delta_map(out, { "curiosity": 7, "suspicion": 2})
				"start_crying":
					_merge_emotional_delta_map(out, { "fear": 3, "stress": 5, "comfort": -2})
				_:
					_merge_emotional_delta_map(out, { "curiosity": 2})
		elif owner_role in ["brother", "sister", "sibling", "featured_sibling", "participant"]:
			match clean_option:
				"smile":
					_merge_emotional_delta_map(out, { "suspicion": -15, "comfort": 6, "curiosity": 8, "affection": 5, "trust": 3})
				"blink_slowly":
					_merge_emotional_delta_map(out, { "suspicion": -6, "curiosity": 10, "comfort": 2})
				"stare_back":
					_merge_emotional_delta_map(out, { "suspicion": 5, "curiosity": 12, "rivalry": 4})
				"start_crying":
					_merge_emotional_delta_map(out, { "stress": 8, "guilt": 4, "suspicion": -2})
				_:
					_merge_emotional_delta_map(out, { "curiosity": 4})
		elif owner_role in ["mother", "father", "guardian"]:
			match clean_option:
				"smile":
					_merge_emotional_delta_map(out, { "protectiveness": 5, "comfort": 5, "stress": -4, "pride": 2})
				"start_crying":
					_merge_emotional_delta_map(out, { "protectiveness": 7, "stress": 7, "fear": 2})
				_:
					_merge_emotional_delta_map(out, { "protectiveness": 3, "curiosity": 2})
		else:
			match clean_option:
				"smile":
					_merge_emotional_delta_map(out, { "comfort": 3, "affection": 2})
				"start_crying":
					_merge_emotional_delta_map(out, { "stress": 4, "fear": 2})
				_:
					_merge_emotional_delta_map(out, { "curiosity": 2})

	elif request_key == "immediate_family_illness_notice":
		match clean_option:
			"visit_them":
				_merge_emotional_delta_map(out, { "trust": 8, "comfort": 7, "protectiveness": 4, "resentment": -4})
			"send_help":
				_merge_emotional_delta_map(out, { "trust": 6, "respect": 5, "comfort": 3, "stress": -2})
			"give_space":
				_merge_emotional_delta_map(out, { "respect": 2, "comfort": -2, "perceived_neglect": 4})
			"hope_they_recover":
				_merge_emotional_delta_map(out, { "comfort": 2, "protectiveness": 2})
			_:
				_merge_emotional_delta_map(out, { "comfort": 1})

	elif request_key.find("finance") >= 0 or request_key.find("money") >= 0:
		match clean_option:
			"stay_quiet":
				_merge_emotional_delta_map(out, { "stress": 4, "fear": 2, "perceived_neglect": 2})
			"ask_whats_wrong", "ask_what_finances_mean":
				_merge_emotional_delta_map(out, { "curiosity": 5, "trust": 1, "stress": 1})
			"start_crying":
				_merge_emotional_delta_map(out, { "stress": 8, "protectiveness": 6, "fear": 4})
			"try_to_help":
				_merge_emotional_delta_map(out, { "trust": 5, "comfort": 4, "protectiveness": 2})
			"argue":
				_merge_emotional_delta_map(out, { "resentment": 8, "stress": 5, "trust": -3})
			_:
				_merge_emotional_delta_map(out, { "stress": 2})

	return out


func _fallback_emotional_delta_map(source_contract: Dictionary, _owner: Person, _target: Person, _decision_actor: Person, _owner_role: String, _target_role: String, option: Dictionary, option_id: String) -> Dictionary:
	var out: Dictionary = {}
	var clean_option: String = str(option_id).strip_edges().to_lower()
	var label: String = str(option.get("label", clean_option)).strip_edges().to_lower()
	var joined: String = "%s %s %s %s" % [
		clean_option,
		label,
		str(source_contract.get("request", "")),
		str(source_contract.get("category", ""))
	]
	joined = joined.to_lower()

	if joined.find("compliment") >= 0 or joined.find("smile") >= 0 or joined.find("comfort") >= 0 or joined.find("help") >= 0 or joined.find("visit") >= 0:
		_merge_emotional_delta_map(out, { "trust": 4, "comfort": 4, "affection": 3})
	elif joined.find("insult") >= 0 or joined.find("sarcastic") >= 0 or joined.find("mock") >= 0:
		_merge_emotional_delta_map(out, { "resentment": 8, "humiliation": 6, "trust": -4})
	elif joined.find("ignore") >= 0 or joined.find("leave") >= 0 or joined.find("silent") >= 0 or joined.find("space") >= 0:
		_merge_emotional_delta_map(out, { "perceived_neglect": 4, "trust": -2, "comfort": -2})
	elif joined.find("fight") >= 0 or joined.find("argue") >= 0 or joined.find("attack") >= 0:
		_merge_emotional_delta_map(out, { "resentment": 10, "fear": 5, "trust": -6})
	elif joined.find("win") >= 0 or joined.find("achievement") >= 0 or joined.find("praise") >= 0:
		_merge_emotional_delta_map(out, { "pride": 7, "envy": 3})
	else:
		_merge_emotional_delta_map(out, { "curiosity": 1})

	return out


func _apply_era_emotional_flavor_to_delta_map(delta_map: Dictionary, source_contract: Dictionary) -> Dictionary:
	var out: Dictionary = _safe_dictionary(delta_map)
	var era_key: String = _era_key_for_source_contract(source_contract)

	if era_key.find("ancient") >= 0:
		if out.has("protectiveness"):
			out ["protectiveness"] = float(out.get("protectiveness", 0.0)) * 1.15
		if out.has("fear"):
			out ["fear"] = float(out.get("fear", 0.0)) * 1.1
		if out.has("trust"):
			out ["trust"] = float(out.get("trust", 0.0)) * 1.05
	elif era_key.find("medieval") >= 0:
		if out.has("respect"):
			out ["respect"] = float(out.get("respect", 0.0)) * 1.18
		if out.has("resentment"):
			out ["resentment"] = float(out.get("resentment", 0.0)) * 1.1
		if out.has("perceived_unfairness"):
			out ["perceived_unfairness"] = float(out.get("perceived_unfairness", 0.0)) * 1.12
	elif era_key.find("industrial") >= 0:
		if out.has("stress"):
			out ["stress"] = float(out.get("stress", 0.0)) * 1.22
		if out.has("resentment"):
			out ["resentment"] = float(out.get("resentment", 0.0)) * 1.12
		if out.has("comfort"):
			out ["comfort"] = float(out.get("comfort", 0.0)) * 0.95
	elif era_key.find("future") >= 0:
		if out.has("suspicion"):
			out ["suspicion"] = float(out.get("suspicion", 0.0)) * 1.2
		if out.has("curiosity"):
			out ["curiosity"] = float(out.get("curiosity", 0.0)) * 1.15
		if out.has("perceived_neglect"):
			out ["perceived_neglect"] = float(out.get("perceived_neglect", 0.0)) * 1.1
	else:
		if out.has("comfort"):
			out ["comfort"] = float(out.get("comfort", 0.0)) * 1.03
		if out.has("trust"):
			out ["trust"] = float(out.get("trust", 0.0)) * 1.03

	return out


func _apply_emotional_impact_contract(emotional_impact_contract: Dictionary) -> Dictionary:
	if emotional_impact_contract.is_empty():
		return {
			"success": true,
			"skipped": true,
			"reason": "empty_emotional_impact_contract",
			"applied_update_count": 0
		}

	var impact_id: String = str(emotional_impact_contract.get("id", emotional_impact_contract.get("contract_id", ""))).strip_edges()
	if impact_id == "":
		return {
			"success": false,
			"reason": "missing_emotional_impact_id",
			"applied_update_count": 0
		}

	var relationship_updates: Array = _safe_array(emotional_impact_contract.get("relationship_updates", []))
	var applied_updates: Array = []
	var emitted_intents: Array = []

	for raw_update in relationship_updates:
		if typeof(raw_update) != TYPE_DICTIONARY:
			continue

		var update: Dictionary = raw_update as Dictionary
		var owner_id: int = int(update.get("owner_actor_id", -1))
		var target_id: int = int(update.get("target_actor_id", -1))
		if owner_id <= 0 or target_id <= 0 or owner_id == target_id:
			continue

		var owner: Person = _actor_by_id(owner_id)
		var target: Person = _actor_by_id(target_id)
		if owner == null or target == null:
			continue

		var dna_delta: Dictionary = _safe_dictionary(update.get("relationship_dna_delta", {}))
		var dna_report: Dictionary = _apply_relationship_dna_delta(owner, target, dna_delta, update, emotional_impact_contract)
		if dna_report.is_empty():
			continue

		applied_updates.append(dna_report.duplicate(true))

		var intent_rows: Array = _refresh_future_behavior_intents_for_pair(owner, target, dna_report, update, emotional_impact_contract)
		for raw_intent in intent_rows:
			if typeof(raw_intent) == TYPE_DICTIONARY:
				emitted_intents.append((raw_intent as Dictionary).duplicate(true))

	emotional_impact_contract ["state"] = "applied"
	emotional_impact_contract ["applied_at_ms"] = int(Time.get_ticks_msec())
	emotional_impact_contract ["applied_update_count"] = applied_updates.size()
	emotional_impact_contract ["future_behavior_intent_count"] = emitted_intents.size()
	emotional_impact_contracts [impact_id] = emotional_impact_contract.duplicate(true)

	while emotional_impact_contracts.size() > MAX_EMOTIONAL_IMPACT_CONTRACTS:
		var oldest_key: String = str(emotional_impact_contracts.keys() [0])
		emotional_impact_contracts.erase(oldest_key)

	return {
		"success": true,
		"mode": "emotional_impact_applied",
		"emotional_impact_contract_id": impact_id,
		"applied_update_count": applied_updates.size(),
		"future_behavior_intent_count": emitted_intents.size(),
		"relationship_dna_updates": applied_updates.duplicate(true),
		"future_behavior_intents": emitted_intents.duplicate(true)
	}


func _apply_relationship_dna_delta(owner: Person, target: Person, dna_delta: Dictionary, update: Dictionary, emotional_impact_contract: Dictionary) -> Dictionary:
	if owner == null or target == null:
		return {}

	var owner_id: int = int(owner.id)
	var target_id: int = int(target.id)
	var key: String = _relationship_dna_key(owner_id, target_id)
	var before: Dictionary = _relationship_dna_for_pair(owner, target)
	var after: Dictionary = before.duplicate(true)

	for raw_key in dna_delta.keys():
		var metric: String = str(raw_key).strip_edges().to_lower()
		if metric == "":
			continue
		var old_value: float = float(after.get(metric, _default_relationship_metric_value(metric)))
		var new_value: float = clamp(old_value + float(dna_delta.get(raw_key, 0.0)), 0.0, 100.0)
		after [metric] = new_value

	after ["schema"] = RELATIONSHIP_DNA_SCHEMA
	after ["version"] = CONTRACT_VERSION
	after ["owner_actor_id"] = owner_id
	after ["owner_actor_name"] = _actor_first_name(owner)
	after ["target_actor_id"] = target_id
	after ["target_actor_name"] = _actor_first_name(target)
	after ["relationship_role"] = _relationship_role_label_for_dna(owner, target)
	after ["last_source_contract_id"] = str(emotional_impact_contract.get("source_contract_id", ""))
	after ["last_emotional_impact_id"] = str(emotional_impact_contract.get("id", ""))
	after ["last_option_id"] = str(update.get("option_id", ""))
	after ["last_updated_year"] = int(gs.year) if gs != null else int(emotional_impact_contract.get("created_year", 0))
	after ["updated_at_ms"] = int(Time.get_ticks_msec())

	relationship_dna_index [key] = after.duplicate(true)

	var relationship_delta: int = int(update.get("relationship_delta", _relationship_affection_delta_from_dna_delta(dna_delta)))
	_apply_relationship_affection_delta(owner, target, relationship_delta)

	var memory_row: Dictionary = _relationship_memory_row_from_update(owner, target, before, after, dna_delta, relationship_delta, update, emotional_impact_contract)
	relationship_memory_ledger.append(memory_row.duplicate(true))
	if relationship_memory_ledger.size() > MAX_RELATIONSHIP_MEMORY_LEDGER:
		relationship_memory_ledger = relationship_memory_ledger.slice(relationship_memory_ledger.size() - MAX_RELATIONSHIP_MEMORY_LEDGER, relationship_memory_ledger.size())

	return {
		"success": true,
		"relationship_dna_key": key,
		"owner_actor_id": owner_id,
		"target_actor_id": target_id,
		"before": before.duplicate(true),
		"after": after.duplicate(true),
		"dna_delta": dna_delta.duplicate(true),
		"relationship_delta": relationship_delta,
		"memory_row": memory_row.duplicate(true)
	}


func _relationship_dna_for_pair(owner: Person, target: Person) -> Dictionary:
	if owner == null or target == null:
		return {}

	var owner_id: int = int(owner.id)
	var target_id: int = int(target.id)
	var key: String = _relationship_dna_key(owner_id, target_id)
	var existing: Dictionary = _safe_dictionary(relationship_dna_index.get(key, {}))
	if existing.is_empty():
		existing = _base_relationship_dna(owner, target)

	return _normalize_relationship_dna(owner_id, target_id, existing)


func _base_relationship_dna(owner: Person, target: Person) -> Dictionary:
	var bond: int = 50

	if owner != null and target != null:
		if gs != null and gs.relationship_engine != null and gs.relationship_engine.has_method("ensure_pair_relationship_baseline"):
			bond = int(gs.relationship_engine.ensure_pair_relationship_baseline(owner, target))
		elif typeof(owner.affection) == TYPE_DICTIONARY:
			var target_id: int = int(target.id)
			var key: Variant = target_id
			if not owner.affection.has(key) and owner.affection.has(str(target_id)):
				key = str(target_id)
			bond = int(owner.affection.get(key, 50))

	return {
		"schema": RELATIONSHIP_DNA_SCHEMA,
		"version": CONTRACT_VERSION,
		"trust": clamp(float(bond), 0.0, 100.0),
		"respect": 50.0,
		"comfort": clamp(float(bond), 0.0, 100.0),
		"affection": clamp(float(bond), 0.0, 100.0),
		"envy": 0.0,
		"fear": 0.0,
		"suspicion": 0.0,
		"resentment": 0.0,
		"humiliation": 0.0,
		"curiosity": 0.0,
		"stress": 0.0,
		"pride": 0.0,
		"protectiveness": 0.0,
		"disappointment": 0.0,
		"perceived_favoritism": 0.0,
		"perceived_neglect": 0.0,
		"perceived_unfairness": 0.0,
		"history": []
	}


func _normalize_relationship_dna(owner_id: int, target_id: int, dna: Dictionary) -> Dictionary:
	var out: Dictionary = dna.duplicate(true)
	out ["owner_actor_id"] = owner_id
	out ["target_actor_id"] = target_id

	var keys: Array = [
		"trust",
		"respect",
		"comfort",
		"affection",
		"envy",
		"fear",
		"suspicion",
		"resentment",
		"humiliation",
		"curiosity",
		"stress",
		"pride",
		"protectiveness",
		"disappointment",
		"perceived_favoritism",
		"perceived_neglect",
		"perceived_unfairness"
	]

	for raw_key in keys:
		var key: String = str(raw_key)
		out [key] = clamp(float(out.get(key, _default_relationship_metric_value(key))), 0.0, 100.0)

	if typeof(out.get("history", [])) != TYPE_ARRAY:
		out ["history"] = []

	return out


func _relationship_memory_row_from_update(owner: Person, target: Person, before: Dictionary, after: Dictionary, dna_delta: Dictionary, relationship_delta: int, update: Dictionary, emotional_impact_contract: Dictionary) -> Dictionary:
	var dominant_metric: String = _dominant_emotional_metric(dna_delta)
	var year_value: int = int(gs.year) if gs != null else int(emotional_impact_contract.get("created_year", 0))

	return {
		"schema": "eralife.relationship_memory_row",
		"version": CONTRACT_VERSION,
		"year": year_value,
		"owner_actor_id": int(owner.id),
		"owner_actor_name": _actor_first_name(owner),
		"target_actor_id": int(target.id),
		"target_actor_name": _actor_first_name(target),
		"dominant_metric": dominant_metric,
		"dna_delta": dna_delta.duplicate(true),
		"relationship_delta": relationship_delta,
		"source_contract_id": str(emotional_impact_contract.get("source_contract_id", "")),
		"emotional_impact_contract_id": str(emotional_impact_contract.get("id", "")),
		"option_id": str(update.get("option_id", "")),
		"option_label": str(update.get("option_label", "")),
		"before_snapshot": before.duplicate(true),
		"after_snapshot": after.duplicate(true),
		"memory_decay_policy": {
		},
		"created_at_ms": int(Time.get_ticks_msec())
	}


func _refresh_future_behavior_intents_for_pair(owner: Person, target: Person, dna_report: Dictionary, update: Dictionary, emotional_impact_contract: Dictionary) -> Array:
	var out: Array = []
	if owner == null or target == null:
		return out

	var after: Dictionary = _safe_dictionary(dna_report.get("after", {}))
	if after.is_empty():
		return out

	var candidate_types: Array = []

	if float(after.get("resentment", 0.0)) >= 35.0 or float(after.get("humiliation", 0.0)) >= 35.0:
		candidate_types.append("long_term_grudge")
	if float(after.get("envy", 0.0)) >= 35.0:
		candidate_types.append("sibling_rivalry")
	if float(after.get("perceived_favoritism", 0.0)) >= 30.0 or float(after.get("perceived_unfairness", 0.0)) >= 35.0:
		candidate_types.append("favoritism_wound")
	if float(after.get("trust", 0.0)) >= 72.0 and float(after.get("comfort", 0.0)) >= 68.0:
		candidate_types.append("protective_bond")
	if float(after.get("perceived_neglect", 0.0)) >= 35.0:
		candidate_types.append("neglect_memory")
	if float(after.get("suspicion", 0.0)) >= 45.0 or float(after.get("fear", 0.0)) >= 40.0:
		candidate_types.append("uneasy_history")

	for raw_type in candidate_types:
		var arc_type: String = str(raw_type)
		var intent_id: String = "relationship_future_%s_%d_%d" % [arc_type, int(owner.id), int(target.id)]
		var existing: Dictionary = _safe_dictionary(future_behavior_intents.get(intent_id, {}))
		var intensity: float = _future_behavior_intensity_for_type(arc_type, after)

		var intent: Dictionary = existing.duplicate(true)
		if intent.is_empty():
			intent = {
				"schema": FUTURE_BEHAVIOR_INTENT_SCHEMA,
				"version": CONTRACT_VERSION,
				"id": intent_id,
				"contract_id": intent_id,
				"arc_type": arc_type,
				"state": "watching",
				"owner_actor_id": int(owner.id),
				"owner_actor_name": _actor_first_name(owner),
				"target_actor_id": int(target.id),
				"target_actor_name": _actor_first_name(target),
				"created_year": int(gs.year) if gs != null else int(emotional_impact_contract.get("created_year", 0)),
				"eligible_age_min": _future_behavior_eligible_age(owner, arc_type),
				"cooldown_years": 2,
				"times_emitted": 0,
				"last_emitted_year": -999999
			}

		intent ["intensity"] = intensity
		intent ["latest_relationship_dna"] = after.duplicate(true)
		intent ["latest_emotional_impact_id"] = str(emotional_impact_contract.get("id", ""))
		intent ["latest_source_contract_id"] = str(emotional_impact_contract.get("source_contract_id", ""))
		intent ["latest_option_id"] = str(update.get("option_id", ""))
		intent ["updated_at_ms"] = int(Time.get_ticks_msec())
		intent ["contract_mesh"] = {
			"source_of_truth": "ContractViewLayerContractEngine",
			"pending_situation_consumer": "PendingSituationsEngine",
			"ui_mutation_allowed": false,
			"persistent": true,
			"save_key": "relationship_future_behavior_intents"
		}

		future_behavior_intents [intent_id] = intent.duplicate(true)
		out.append(intent.duplicate(true))

	return out


func _primary_other_actor_id_for_impact(source_contract: Dictionary, actor_id: int) -> int:
	var direct_keys: Array = [
		"featured_relative_id",
		"featured_actor_id",
		"subject_actor_id",
		"recipient_actor_id",
		"issuer_id",
		"issuer",
		"other_actor_id"
	]

	for raw_key in direct_keys:
		var key: String = str(raw_key)
		var other_id: int = int(source_contract.get(key, -1))
		if other_id > 0 and other_id != actor_id:
			return other_id

	var participant_ids: Array = _diary_actor_ids_for_source_contract(source_contract)
	for raw_id in participant_ids:
		var other_id: int = int(raw_id)
		if other_id > 0 and other_id != actor_id:
			return other_id

	return -1


func _relationship_dna_key(owner_id: int, target_id: int) -> String:
	return "%d:%d" % [owner_id, target_id]


func _merge_emotional_delta_map(into: Dictionary, delta_map: Dictionary) -> void:
	if typeof(into) != TYPE_DICTIONARY or typeof(delta_map) != TYPE_DICTIONARY:
		return

	for raw_key in delta_map.keys():
		var key: String = str(raw_key).strip_edges().to_lower()
		if key == "":
			continue
		into [key] = float(into.get(key, 0.0)) + float(delta_map.get(raw_key, 0.0))


func _clean_emotional_delta_map(delta_map: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	if typeof(delta_map) != TYPE_DICTIONARY:
		return out

	for raw_key in delta_map.keys():
		var key: String = str(raw_key).strip_edges().to_lower()
		if key == "":
			continue
		var value: float = float(delta_map.get(raw_key, 0.0))
		if abs(value) < 0.01:
			continue
		out [key] = value

	return out


func _default_relationship_metric_value(metric: String) -> float:
	match str(metric).strip_edges().to_lower():
		"trust", "comfort", "affection":
			return 50.0
		"respect":
			return 50.0
		_:
			return 0.0


func _relationship_affection_delta_from_dna_delta(dna_delta: Dictionary) -> int:
	var positive: float = 0.0
	var negative: float = 0.0

	positive += float(dna_delta.get("trust", 0.0))
	positive += float(dna_delta.get("comfort", 0.0))
	positive += float(dna_delta.get("affection", 0.0))
	positive += float(dna_delta.get("respect", 0.0))
	positive += float(dna_delta.get("protectiveness", 0.0)) * 0.5
	positive += float(dna_delta.get("pride", 0.0)) * 0.4

	negative += float(dna_delta.get("resentment", 0.0))
	negative += float(dna_delta.get("fear", 0.0)) * 0.7
	negative += float(dna_delta.get("suspicion", 0.0)) * 0.6
	negative += float(dna_delta.get("envy", 0.0)) * 0.5
	negative += float(dna_delta.get("disappointment", 0.0)) * 0.6
	negative += float(dna_delta.get("perceived_neglect", 0.0)) * 0.7
	negative += float(dna_delta.get("perceived_unfairness", 0.0)) * 0.7
	negative += float(dna_delta.get("humiliation", 0.0)) * 0.8

	return int(clamp(round((positive - negative) / 5.0), -12.0, 12.0))


func _apply_relationship_affection_delta(owner: Person, target: Person, delta: int) -> void:
	if owner == null or target == null or delta == 0:
		return

	if gs != null and gs.relationship_engine != null and gs.relationship_engine.has_method("ensure_pair_relationship_baseline"):
		gs.relationship_engine.ensure_pair_relationship_baseline(owner, target)

	if typeof(owner.affection) != TYPE_DICTIONARY:
		owner.affection = {}

	var target_id: int = int(target.id)
	var key: Variant = target_id
	if not owner.affection.has(key) and owner.affection.has(str(target_id)):
		key = str(target_id)

	var current_value: int = int(owner.affection.get(key, 50))
	owner.affection [key] = clamp(current_value + delta, 0, 100)


func _dominant_emotional_metric(dna_delta: Dictionary) -> String:
	var best_key: String = ""
	var best_value: float = 0.0

	for raw_key in dna_delta.keys():
		var value: float = abs(float(dna_delta.get(raw_key, 0.0)))
		if value > best_value:
			best_value = value
			best_key = str(raw_key).strip_edges().to_lower()

	return best_key


func _future_behavior_intensity_for_type(arc_type: String, dna: Dictionary) -> float:
	match str(arc_type).strip_edges().to_lower():
		"long_term_grudge":
			return max(float(dna.get("resentment", 0.0)), float(dna.get("humiliation", 0.0)))
		"sibling_rivalry":
			return float(dna.get("envy", 0.0))
		"favoritism_wound":
			return max(float(dna.get("perceived_favoritism", 0.0)), float(dna.get("perceived_unfairness", 0.0)))
		"protective_bond":
			return max(float(dna.get("trust", 0.0)), float(dna.get("comfort", 0.0)), float(dna.get("protectiveness", 0.0)))
		"neglect_memory":
			return float(dna.get("perceived_neglect", 0.0))
		"uneasy_history":
			return max(float(dna.get("suspicion", 0.0)), float(dna.get("fear", 0.0)))
		_:
			return 0.0


func _future_behavior_eligible_age(owner: Person, arc_type: String) -> int:
	if owner == null:
		return 0

	var current_age: int = int(owner.age)
	match str(arc_type).strip_edges().to_lower():
		"long_term_grudge", "sibling_rivalry", "favoritism_wound":
			return max(current_age + 1, 5)
		"protective_bond":
			return max(current_age + 1, 3)
		"neglect_memory", "uneasy_history":
			return max(current_age + 1, 4)
		_:
			return current_age + 1


func _relationship_role_label_for_dna(owner: Person, target: Person) -> String:
	if gs != null and gs.relationship_engine != null and gs.relationship_engine.has_method("_relationship_role_between"):
		return str(gs.relationship_engine.call("_relationship_role_between", owner, target))
	return "relationship"


func _era_key_for_source_contract(source_contract: Dictionary) -> String:
	var era_name: String = str(source_contract.get("era", source_contract.get("era_name", ""))).strip_edges().to_lower()
	if era_name != "":
		return era_name

	var weighting: Dictionary = _safe_dictionary(source_contract.get("starter_weighting", {}))
	era_name = str(weighting.get("era", "")).strip_edges().to_lower()
	if era_name != "":
		return era_name

	if gs != null:
		if gs.has_method("get_current_era_name"):
			era_name = str(gs.call("get_current_era_name")).strip_edges().to_lower()
			if era_name != "":
				return era_name

		era_name = str(_safe_object_property(gs, "current_era", "")).strip_edges().to_lower()
		if era_name != "":
			return era_name

		era_name = str(_safe_object_property(gs, "era", "")).strip_edges().to_lower()
		if era_name != "":
			return era_name

		era_name = str(_safe_object_property(gs, "era_name", "")).strip_edges().to_lower()
		if era_name != "":
			return era_name

	return "modern"
func _repair_state() -> void:
	var repaired_views: Dictionary = {}
	for raw_id in view_contracts.keys():
		var view: Dictionary = _safe_dictionary(view_contracts.get(raw_id, {}))
		if view.is_empty():
			continue
		var view_id: String = str(view.get("view_contract_id", view.get("id", raw_id))).strip_edges()
		if view_id == "":
			continue
		view ["schema"] = str(view.get("schema", VIEW_CONTRACT_SCHEMA))
		view ["version"] = int(view.get("version", CONTRACT_VERSION))
		repaired_views [view_id] = view
	view_contracts = repaired_views

	var repaired_dna: Dictionary = {}
	for raw_key in relationship_dna_index.keys():
		var dna: Dictionary = _safe_dictionary(relationship_dna_index.get(raw_key, {}))
		if dna.is_empty():
			continue
		var owner_id: int = int(dna.get("owner_actor_id", -1))
		var target_id: int = int(dna.get("target_actor_id", -1))
		if owner_id <= 0 or target_id <= 0 or owner_id == target_id:
			continue
		var key: String = _relationship_dna_key(owner_id, target_id)
		dna ["schema"] = str(dna.get("schema", RELATIONSHIP_DNA_SCHEMA))
		dna ["version"] = int(dna.get("version", CONTRACT_VERSION))
		repaired_dna [key] = _normalize_relationship_dna(owner_id, target_id, dna)
	relationship_dna_index = repaired_dna

	var repaired_intents: Dictionary = {}
	for raw_intent_key in future_behavior_intents.keys():
		var intent: Dictionary = _safe_dictionary(future_behavior_intents.get(raw_intent_key, {}))
		if intent.is_empty():
			continue
		var intent_id: String = str(intent.get("id", raw_intent_key)).strip_edges()
		if intent_id == "":
			continue
		intent ["schema"] = str(intent.get("schema", FUTURE_BEHAVIOR_INTENT_SCHEMA))
		intent ["version"] = int(intent.get("version", CONTRACT_VERSION))
		repaired_intents [intent_id] = intent
	future_behavior_intents = repaired_intents

	while emotional_impact_contracts.size() > MAX_EMOTIONAL_IMPACT_CONTRACTS:
		var oldest_impact_key: String = str(emotional_impact_contracts.keys() [0])
		emotional_impact_contracts.erase(oldest_impact_key)

	if relationship_memory_ledger.size() > MAX_RELATIONSHIP_MEMORY_LEDGER:
		relationship_memory_ledger = relationship_memory_ledger.slice(relationship_memory_ledger.size() - MAX_RELATIONSHIP_MEMORY_LEDGER, relationship_memory_ledger.size())

	while future_behavior_intents.size() > MAX_FUTURE_BEHAVIOR_INTENTS:
		var oldest_intent_key: String = str(future_behavior_intents.keys() [0])
		future_behavior_intents.erase(oldest_intent_key)

	if observation_log.size() > 240:
		observation_log = observation_log.slice(observation_log.size() - 240, observation_log.size())
	if mutation_log.size() > 240:
		mutation_log = mutation_log.slice(mutation_log.size() - 240, mutation_log.size())

func _commit_state() -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	gs.scenario_state ["contract_view_layer_view_contracts"] = view_contracts.duplicate(true)
	gs.scenario_state ["contract_view_layer_decision_contracts"] = decision_contracts.duplicate(true)
	gs.scenario_state ["contract_view_layer_collision_contracts"] = collision_contracts.duplicate(true)
	gs.scenario_state ["contract_view_layer_observation_log"] = observation_log.duplicate(true)
	gs.scenario_state ["contract_view_layer_mutation_log"] = mutation_log.duplicate(true)
	gs.scenario_state ["relationship_emotional_impact_contracts"] = emotional_impact_contracts.duplicate(true)
	gs.scenario_state ["relationship_dna_index"] = relationship_dna_index.duplicate(true)
	gs.scenario_state ["relationship_memory_ledger"] = relationship_memory_ledger.duplicate(true)
	gs.scenario_state ["relationship_future_behavior_intents"] = future_behavior_intents.duplicate(true)
func _actor_by_id(actor_id: int) -> Person:
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

func _safe_object_property(value: Variant, property_name: String, fallback: Variant = null) -> Variant:
	var clean_property_name: String = str(property_name).strip_edges()
	if clean_property_name == "":
		return fallback

	if value == null:
		return fallback

	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).get(clean_property_name, fallback)

	if typeof(value) != TYPE_OBJECT:
		return fallback

	for raw_property in value.get_property_list():
		if typeof(raw_property) != TYPE_DICTIONARY:
			continue

		var property_row: Dictionary = raw_property as Dictionary
		if str(property_row.get("name", "")).strip_edges() == clean_property_name:
			return value.get(clean_property_name)

	return fallback
func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(value: Variant) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return (value as Array).duplicate(true)
	return []