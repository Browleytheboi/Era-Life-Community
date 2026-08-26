extends Resource
class_name RealityOrchestrator

const CONTRACT_SCHEMA:= "eralife.reality_orchestrator_contract"
const CONTRACT_VERSION:= 1
const STATE_SCHEMA:= "eralife.reality_orchestrator_state"
const STATE_KEY:= "reality_orchestrator_state"
const MAX_ORCHESTRATION_LEDGER:= 220

const AUTHORITY_LOCAL_EVENT:= 10
const AUTHORITY_DOMAIN:= 30
const AUTHORITY_REALITY:= 70
const AUTHORITY_META_CONTRACT:= 100

var gs
var active_contract: Dictionary = {}
var contract_registry: Dictionary = {}
var last_orchestration_report: Dictionary = {}
var last_contract_report: Dictionary = {}
var prewarmed_packet_cache: Dictionary = {}
var last_prewarm_report: Dictionary = {}



var resident_safe_streaming_prewarm_pump_armed: bool = false
var resident_safe_streaming_prewarm_budget: int = 1

func _init(_gs = null, contract: Dictionary = {}) -> void:
	gs = _gs
	set_contract(contract)


func set_contract(contract: Dictionary = {}) -> Dictionary:
	active_contract = _default_contract()
	if typeof(contract) == TYPE_DICTIONARY and not contract.is_empty():
		active_contract = _merge_dict(active_contract, contract)

	_apply_perception_contract_extensions()
	_bootstrap_contract_registry()

	last_contract_report = {
		"schema": "eralife.reality_orchestrator_contract_set_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"contract_id": str(active_contract.get("id", "reality_orchestrator.default")),
		"registered_contract_count": contract_registry.size(),
		"set_at_ms": int(Time.get_ticks_msec())
	}
	return last_contract_report.duplicate(true)


func bootstrap_default_contracts() -> Dictionary:
	_bootstrap_contract_registry()

	var state: Dictionary = _world_state()
	state ["contract_registry"] = contract_registry.duplicate(true)
	state ["authority_lattice"] = _safe_dictionary(active_contract.get("authority_lattice", {}))
	state ["domain_boundaries"] = _safe_dictionary(active_contract.get("domain_boundaries", {}))
	_commit_world_state(state)

	return {
		"schema": "eralife.reality_orchestrator_bootstrap_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"contract_count": contract_registry.size(),
		"bootstrapped_at_ms": int(Time.get_ticks_msec())
	}


func export_state() -> Dictionary:
	var state: Dictionary = _world_state()
	return {
		"schema": STATE_SCHEMA,
		"version": CONTRACT_VERSION,
		"save_key": STATE_KEY,
		"persistent": true,
		"backwards_compatible": true,
		"preserve_unknown_fields": true,
		"active_contract": active_contract.duplicate(true),
		"contract_registry": contract_registry.duplicate(true),
		"authority_lattice": _safe_dictionary(active_contract.get("authority_lattice", {})),
		"domain_boundaries": _safe_dictionary(active_contract.get("domain_boundaries", {})),
		"world_state": state.duplicate(true),
		"last_orchestration_report": last_orchestration_report.duplicate(true),
		"last_contract_report": last_contract_report.duplicate(true),
		"exported_at_ms": int(Time.get_ticks_msec())
	}


func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "RealityOrchestrator import_state expected Dictionary."
		}

	var default_contract: Dictionary = _default_contract()
	var contract_raw: Variant = data.get("active_contract", {})
	if typeof(contract_raw) == TYPE_DICTIONARY and not (contract_raw as Dictionary).is_empty():
		active_contract = _merge_dict(default_contract, contract_raw as Dictionary)
	else:
		active_contract = default_contract

	var registry_raw: Variant = data.get("contract_registry", {})
	if typeof(registry_raw) == TYPE_DICTIONARY:
		contract_registry = (registry_raw as Dictionary).duplicate(true)
	else:
		contract_registry = {}

	_bootstrap_contract_registry()

	var imported_state: Dictionary = {}
	var world_state_raw: Variant = data.get("world_state", {})
	if typeof(world_state_raw) == TYPE_DICTIONARY:
		imported_state = _normalize_state(world_state_raw as Dictionary)
	elif data.has("orchestration_ledger") or data.has("authority_lattice") or data.has("domain_boundaries") or data.has("last_orchestration_report"):
		imported_state = _normalize_state(data.duplicate(true))
	else:
		imported_state = _world_state()

	var state_registry: Dictionary = _safe_dictionary(imported_state.get("contract_registry", {}))
	for raw_key in state_registry.keys():
		var key: String = str(raw_key)
		if key != "":
			contract_registry [key] = _safe_dictionary(state_registry.get(raw_key, {}))

	imported_state ["contract_registry"] = contract_registry.duplicate(true)

	if typeof(imported_state.get("authority_lattice", {})) != TYPE_DICTIONARY or _safe_dictionary(imported_state.get("authority_lattice", {})).is_empty():
		imported_state ["authority_lattice"] = _safe_dictionary(active_contract.get("authority_lattice", {}))

	if typeof(imported_state.get("domain_boundaries", {})) != TYPE_DICTIONARY or _safe_dictionary(imported_state.get("domain_boundaries", {})).is_empty():
		imported_state ["domain_boundaries"] = _safe_dictionary(active_contract.get("domain_boundaries", {}))

	_commit_world_state(imported_state)

	var report_raw: Variant = data.get("last_orchestration_report", imported_state.get("last_orchestration_report", {}))
	if typeof(report_raw) == TYPE_DICTIONARY:
		last_orchestration_report = (report_raw as Dictionary).duplicate(true)

	var contract_report_raw: Variant = data.get("last_contract_report", {})
	if typeof(contract_report_raw) == TYPE_DICTIONARY:
		last_contract_report = (contract_report_raw as Dictionary).duplicate(true)

	return {
		"success": true,
		"schema": "eralife.reality_orchestrator_import_report",
		"version": CONTRACT_VERSION,
		"contract_count": contract_registry.size(),
		"backwards_compatible": true,
		"imported_at_ms": int(Time.get_ticks_msec())
	}

func register_orchestration_contract(contract: Dictionary = {}) -> Dictionary:
	if typeof(contract) != TYPE_DICTIONARY or contract.is_empty():
		return {
			"success": false,
			"reason": "Reality orchestration contract missing."
		}

	var normalized: Dictionary = _normalize_orchestration_contract(contract)
	var contract_id: String = str(normalized.get("id", "")).strip_edges()

	if contract_id == "":
		return {
			"success": false,
			"reason": "Reality orchestration contract id missing."
		}

	contract_registry [contract_id] = normalized.duplicate(true)

	var state: Dictionary = _world_state()
	state ["contract_registry"] = contract_registry.duplicate(true)
	_commit_world_state(state)

	return {
		"success": true,
		"contract_id": contract_id,
		"domain": str(normalized.get("domain", "generic")),
		"registered_at_ms": int(Time.get_ticks_msec())
	}


func route_command_envelope(envelope: Dictionary) -> Dictionary:
	if typeof(envelope) != TYPE_DICTIONARY or envelope.is_empty():
		return {
			"success": false,
			"reason": "RealityOrchestrator received an empty command envelope."
		}

	return orchestrate_intent(envelope, {
		"source": "route_command_envelope",
		"intent_format": "command_envelope"
	})


func orchestrate_intent(intent_payload: Variant, context: Dictionary = {}) -> Dictionary:
	var intent: Dictionary = _normalize_intent(intent_payload, context)
	var domain: String = str(intent.get("domain", context.get("domain", "generic"))).strip_edges().to_lower()
	var authority_id: String = str(intent.get("authority", context.get("authority", "local_event"))).strip_edges().to_lower()

	var selected_contracts: Array = _select_contracts(intent, context)
	var boundary_report: Dictionary = _resolve_orchestration_boundary(domain, authority_id, intent, selected_contracts, context)
	var conflict_report: Dictionary = _resolve_contract_conflicts(selected_contracts, boundary_report, context)
	var stability_report: Dictionary = _resolve_reality_stability(intent, boundary_report, conflict_report, context)
	var composition: Dictionary = _compose_reality(intent, selected_contracts, boundary_report, conflict_report, stability_report, context)
	var execution_report: Dictionary = {}

	if bool(stability_report.get("allow_execution", true)) and bool(boundary_report.get("authorized", false)):
		execution_report = _route_execution(intent, composition, context)
	else:
		execution_report = {
			"success": false,
			"mode": "blocked_by_orchestration",
			"reason": str(stability_report.get("reason", boundary_report.get("reason", "Reality orchestration blocked execution.")))
		}

	var report: Dictionary = {
		"schema": "eralife.reality_orchestration_report",
		"version": CONTRACT_VERSION,
		"success": bool(execution_report.get("success", false)) or str(execution_report.get("mode", "")) == "packet_only",
		"intent": intent.duplicate(true),
		"domain": domain,
		"authority": authority_id,
		"authority_rank": _authority_rank(authority_id),
		"selected_contracts": selected_contracts.duplicate(true),
		"boundary": boundary_report.duplicate(true),
		"conflicts": conflict_report.duplicate(true),
		"stability": stability_report.duplicate(true),
		"composition": composition.duplicate(true),
		"execution": execution_report.duplicate(true),
		"context": context.duplicate(true),
		"created_at_year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	_record_orchestration(report)
	last_orchestration_report = report.duplicate(true)
	return report.duplicate(true)


func orchestrate_competitive_event(payload: Dictionary, context: Dictionary = {}) -> Dictionary:
	var forwarded_context: Dictionary = context.duplicate(true)
	forwarded_context ["source"] = str(forwarded_context.get("source", "orchestrate_competitive_event"))
	forwarded_context ["domain"] = "competitive"

	return orchestrate_intent({
		"id": str(payload.get("event_name", payload.get("event_type", "competitive.event"))),
		"domain": "competitive",
		"authority": "domain",
		"event_payload": payload.duplicate(true),
		"composition_stack": [
			"competitive_domain",
			"bending_contracts",
			"rivalry_history",
			"dynasty_significance",
			"audience_context",
			"media_propagation",
			"injury_persistence",
			"timeline_stability",
			"cultural_echo_potential",
			"ui_manifestation",
			"historical_storage",
			"myth_formation"
		]
	}, forwarded_context)


func orchestrate_birth_event(payload: Dictionary, context: Dictionary = {}) -> Dictionary:
	var forwarded_context: Dictionary = context.duplicate(true)
	forwarded_context ["source"] = str(forwarded_context.get("source", "orchestrate_birth_event"))
	forwarded_context ["domain"] = "birth"

	return orchestrate_intent({
		"id": str(payload.get("event_name", "birth.intent")),
		"domain": "birth",
		"authority": "reality",
		"event_payload": payload.duplicate(true),
		"composition_stack": [
			"birth_contract_engine",
			"game_state_contract_engine",
			"game_state_hydration_runtime",
			"ui_contract_engine",
			"embedded_ui_contract_engine",
			"self_host_runtime_layer",
			"historical_storage"
		]
	}, forwarded_context)
func orchestrate_perception_event(payload: Dictionary, context: Dictionary = {}) -> Dictionary:
	var forwarded_context: Dictionary = context.duplicate(true)
	forwarded_context ["source"] = str(forwarded_context.get("source", "orchestrate_perception_event"))
	forwarded_context ["domain"] = "perception"

	return orchestrate_intent({
		"id": str(payload.get("event_name", payload.get("event_type", "upce.interpret_event"))),
		"domain": "perception",
		"authority": "domain",
		"target": "upce_engine",
		"engine_property": "upce_engine",
		"event_payload": payload.duplicate(true),
		"effects": [
			"event_interpretation",
			"memory_seeding",
			"emotional_physics",
			"reputation_propagation",
			"relationship_update",
			"fame_bridge",
			"scenario_hooks",
			"world_feed_signal",
			"myth_formation"
		],
		"composition_stack": [
			"upce_engine",
			"bias_profile_resolver",
			"memory_engine",
			"relationship_engine",
			"fame_engine",
			"reputation_engine",
			"scenario_engine",
			"world_feed_engine",
			"myth_formation"
		]
	}, forwarded_context)

func _default_contract() -> Dictionary:
	return {
		"schema": CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": "reality_orchestrator.default",
		"runtime_policy": {
			"emit_event_bus": true,
		},
		"authority_lattice": {
			"local_event": {
				"rank": AUTHORITY_LOCAL_EVENT,
				"label": "Local Event Authority",
			},
			"domain": {
				"rank": AUTHORITY_DOMAIN,
				"label": "Domain Authority",
			},
			"reality": {
				"rank": AUTHORITY_REALITY,
				"label": "Reality Authority",
			},
			"meta_contract": {
				"rank": AUTHORITY_META_CONTRACT,
				"label": "Meta Contract Authority",
			}
		},
		"domain_boundaries": {
			"competitive": {
				"authority_required": "domain",
				"allowed_engines": [
					"competitive_reality_runtime",
					"bending_engine",
					"bending_tournament_engine",
					"reality_surge_engine",
					"ui_contract_engine",
					"world_feed_engine",
					"world_chronicle_engine"
				],
				"allowed_effects": [
					"record_match",
					"advance_bracket",
					"injury_persistence",
					"media_propagation",
					"cultural_echo",
					"ui_manifestation",
					"historical_storage",
					"reality_surge"
				],
				"blocked_effects": [
					"birth_identity_rewrite",
					"save_schema_rewrite",
					"meta_contract_patch"
				],
				"composition_stack": [
					"competitive_domain",
					"bending_contracts",
					"rivalry_history",
					"dynasty_significance",
					"audience_context",
					"media_propagation",
					"injury_persistence",
					"timeline_stability",
					"cultural_echo_potential",
					"ui_manifestation",
					"historical_storage",
					"myth_formation"
				]
			},
			"birth": {
				"authority_required": "reality",
				"allowed_engines": [
					"birth_contract_engine",
					"character_creator",
					"game_state_contract_engine",
					"game_state_hydration_runtime",
					"game_state_serialization_runtime",
					"ui_contract_engine",
					"embedded_ui_contract_engine",
					"mod_loader"
				],
				"allowed_effects": [
					"identity_seed",
					"world_seed",
					"birth_contract_resolution",
					"character_identity_prepare",
					"hydration_prepare",
					"ui_manifestation",
					"save_slice_prepare"
				],
				"blocked_effects": [
					"unbounded_population_mutation",
					"meta_contract_patch_without_authority"
				],
				"composition_stack": [
					"birth_contract_engine",
					"character_creator",
					"game_state_contract_engine",
					"game_state_hydration_runtime",
					"ui_contract_engine",
					"self_host_runtime_layer",
					"historical_storage"
				]
			},
			"character_creation": {
				"authority_required": "domain",
				"allowed_engines": [
					"character_creator",
					"birth_contract_engine",
					"names_db",
					"npc_factory",
					"game_state_contract_engine",
					"ui_contract_engine",
					"embedded_ui_contract_engine"
				],
				"allowed_effects": [
					"character_template_resolution",
					"identity_seed",
					"family_context_read",
					"appearance_prepare",
					"trait_prepare",
					"ui_manifestation"
				],
				"blocked_effects": [
					"direct_world_overwrite",
					"save_schema_rewrite",
					"meta_contract_patch"
				],
				"composition_stack": [
					"character_creator",
					"birth_contract_engine",
					"identity_contracts",
					"family_context",
					"ui_manifestation",
					"historical_storage"
				]
			},
			"education": {
				"authority_required": "domain",
				"allowed_engines": [
					"school_engine",
					"career_engine",
					"relationship_engine",
					"memory_engine",
					"life_engine",
					"ui_contract_engine",
					"world_feed_engine"
				],
				"allowed_effects": [
					"school_progression",
					"class_assignment",
					"grade_update",
					"relationship_context",
					"memory_update",
					"ui_manifestation"
				],
				"blocked_effects": [
					"birth_identity_rewrite",
					"unbounded_stat_mutation",
					"meta_contract_patch"
				],
				"composition_stack": [
					"education_domain",
					"school_engine",
					"relationship_context",
					"memory_update",
					"life_progression",
					"ui_manifestation"
				]
			},
			"superhero": {
				"authority_required": "domain",
				"allowed_engines": [
					"power_engine",
					"superhero_engine",
					"infamy_engine",
					"scenario_engine",
					"reality_surge_engine",
					"ui_contract_engine",
					"world_feed_engine",
					"world_chronicle_engine"
				],
				"allowed_effects": [
					"power_grant",
					"power_activation",
					"power_training",
					"hero_patrol",
					"crime_response",
					"villain_tracking",
					"team_creation",
					"ally_recruitment",
					"infamy_update",
					"scenario_battle",
					"ui_manifestation",
					"historical_storage"
				],
				"blocked_effects": [
					"unbounded_identity_collapse",
					"birth_identity_rewrite_without_contract",
					"meta_contract_patch_without_authority"
				],
				"composition_stack": [
					"power_engine",
					"activation_resolver",
					"scaling_engine",
					"conflict_resolver",
					"hybridization_engine",
					"suppression_engine",
					"corruption_engine",
					"power_expression_router",
					"superhero_engine",
					"infamy_engine",
					"scenario_engine",
					"ui_manifestation",
					"historical_storage"
				]
			},
			"artifacts": {
				"authority_required": "reality",
				"allowed_engines": [
					"artifacts_engine",
					"belongings_engine",
					"reality_surge_engine",
					"world_feed_engine",
					"world_chronicle_engine",
					"ui_contract_engine"
				],
				"allowed_effects": [
					"artifact_discovery",
					"artifact_transfer",
					"inventory_manifestation",
					"reality_surge",
					"world_feed_signal",
					"historical_storage",
					"ui_manifestation"
				],
				"blocked_effects": [
					"unbounded_identity_collapse",
					"unknown_slice_drop",
					"meta_contract_patch_without_authority"
				],
				"composition_stack": [
					"artifacts_engine",
					"belongings_engine",
					"reality_surge_engine",
					"ui_manifestation",
					"historical_storage"
				]
			},
			"red_bonnet": {
				"authority_required": "reality",
				"allowed_engines": [
					"red_bonnet_engine",
					"artifacts_engine",
					"dynasty_legacy_engine",
					"relationship_engine",
					"memory_engine",
					"reality_surge_engine",
					"world_feed_engine",
					"world_chronicle_engine",
					"game_state_contract_engine",
					"ui_contract_engine"
				],
				"allowed_effects": [
					"bounded_reality_wish",
					"artifact_manifestation",
					"dynasty_influence",
					"memory_update",
					"relationship_update",
					"world_feed_signal",
					"reality_surge",
					"historical_storage",
					"ui_manifestation"
				],
				"blocked_effects": [
					"unknown_slice_drop",
					"save_schema_rewrite",
					"meta_contract_patch_without_authority",
					"unbounded_reality_rewrite"
				],
				"composition_stack": [
					"red_bonnet_engine",
					"reality_authority_boundary",
					"artifact_context",
					"dynasty_significance",
					"memory_update",
					"world_feed_signal",
					"timeline_stability",
					"ui_manifestation",
					"historical_storage",
					"myth_formation"
				]
			},
			"runtime": {
				"authority_required": "reality",
				"allowed_engines": [
					"game_state_contract_engine",
					"game_state_hydration_runtime",
					"game_state_serialization_runtime",
					"temporal_slice_transformation_runtime",
					"simulation_contract_engine",
					"ui_contract_engine",
					"embedded_ui_contract_engine",
					"mod_loader"
				],
				"allowed_effects": [
					"hydrate_slice",
					"serialize_slice",
					"stream_runtime",
					"route_ui",
					"load_mod_contract",
					"stability_guard"
				],
				"blocked_effects": [
					"direct_player_identity_delete",
					"unknown_slice_drop"
				],
				"composition_stack": [
					"game_state_contract_engine",
					"game_state_hydration_runtime",
					"game_state_serialization_runtime",
					"mod_loader",
					"ui_contract_engine",
					"embedded_ui_contract_engine",
					"self_host_runtime_layer"
				]
			},
			"reality_fusion": {
				"authority_required": "reality",
				"allowed_engines": [
					"reality_fusion_engine",
					"reality_surge_engine",
					"game_state_contract_engine",
					"game_state_hydration_runtime",
					"ui_contract_engine",
					"world_chronicle_engine"
				],
				"allowed_effects": [
					"identity_overlay",
					"stat_overlay",
					"inventory_overlay",
					"relationship_overlay",
					"timeline_stability",
					"ui_manifestation",
					"historical_storage"
				],
				"blocked_effects": [
					"unbounded_identity_collapse",
					"unknown_slice_drop",
					"meta_contract_patch_without_authority"
				],
				"composition_stack": [
					"reality_fusion_engine",
					"timeline_stability",
					"game_state_hydration_runtime",
					"ui_manifestation",
					"historical_storage"
				]
			}
		},
		"stability_contract": {
			"max_cross_domain_edges": 6,
			"max_mutation_weight_without_reality_authority": 35.0,
			"max_mutation_weight_with_reality_authority": 88.0,
			"hard_stop_threshold": 100.0,
			"unknown_effect_policy": "quarantine",
			"blocked_effect_policy": "block"
		},
		"orchestration_contracts": [
			{
				"id": "competitive.scoped_reality_composition",
				"domain": "competitive",
				"display_name": "Competitive Scoped Reality Composition",
				"authority_required": "domain",
				"composition_stack": [
					"competitive_domain",
					"bending_contracts",
					"rivalry_history",
					"dynasty_significance",
					"audience_context",
					"media_propagation",
					"injury_persistence",
					"timeline_stability",
					"cultural_echo_potential",
					"ui_manifestation",
					"historical_storage",
					"myth_formation"
				]
			},
			{
				"id": "birth.scoped_reality_composition",
				"domain": "birth",
				"display_name": "Birth Scoped Reality Composition",
				"authority_required": "reality",
				"composition_stack": [
					"birth_contract_engine",
					"character_creator",
					"game_state_contract_engine",
					"game_state_hydration_runtime",
					"ui_contract_engine",
					"embedded_ui_contract_engine",
					"self_host_runtime_layer",
					"historical_storage"
				]
			},
			{
				"id": "character_creation.scoped_reality_composition",
				"domain": "character_creation",
				"display_name": "Character Creator Scoped Reality Composition",
				"authority_required": "domain",
				"composition_stack": [
					"character_creator",
					"birth_contract_engine",
					"identity_contracts",
					"family_context",
					"ui_manifestation",
					"historical_storage"
				]
			},
			{
				"id": "education.scoped_reality_composition",
				"domain": "education",
				"display_name": "Education Scoped Reality Composition",
				"authority_required": "domain",
				"composition_stack": [
					"education_domain",
					"school_engine",
					"relationship_context",
					"memory_update",
					"life_progression",
					"ui_manifestation"
				]
			},
			{
				"id": "artifacts.scoped_reality_composition",
				"domain": "artifacts",
				"display_name": "Artifacts Scoped Reality Composition",
				"authority_required": "reality",
				"composition_stack": [
					"artifacts_engine",
					"belongings_engine",
					"reality_surge_engine",
					"ui_manifestation",
					"historical_storage"
				]
			},
			{
				"id": "red_bonnet.scoped_reality_composition",
				"domain": "red_bonnet",
				"display_name": "Red Bonnet Scoped Reality Composition",
				"authority_required": "reality",
				"composition_stack": [
					"red_bonnet_engine",
					"reality_authority_boundary",
					"artifact_context",
					"dynasty_significance",
					"memory_update",
					"world_feed_signal",
					"timeline_stability",
					"ui_manifestation",
					"historical_storage",
					"myth_formation"
				]
			},
			{
				"id": "runtime.scoped_reality_composition",
				"domain": "runtime",
				"display_name": "Runtime Scoped Reality Composition",
				"authority_required": "reality",
				"composition_stack": [
					"game_state_contract_engine",
					"game_state_hydration_runtime",
					"game_state_serialization_runtime",
					"mod_loader",
					"ui_contract_engine",
					"embedded_ui_contract_engine",
					"self_host_runtime_layer"
				]
			}
		]
	}


func _bootstrap_contract_registry() -> void:
	if typeof(contract_registry) != TYPE_DICTIONARY:
		contract_registry = {}

	var contracts: Array = _safe_array(active_contract.get("orchestration_contracts", []))
	for raw_contract in contracts:
		if typeof(raw_contract) != TYPE_DICTIONARY:
			continue

		var normalized: Dictionary = _normalize_orchestration_contract(raw_contract as Dictionary)
		var contract_id: String = str(normalized.get("id", "")).strip_edges()

		if contract_id == "":
			continue

		if not contract_registry.has(contract_id):
			contract_registry [contract_id] = normalized.duplicate(true)


func _normalize_orchestration_contract(contract: Dictionary) -> Dictionary:
	var out: Dictionary = contract.duplicate(true)
	out ["schema"] = str(out.get("schema", "eralife.reality_orchestration_contract"))
	out ["version"] = max(1, int(out.get("version", CONTRACT_VERSION)))
	out ["id"] = str(out.get("id", "generic.scoped_reality_composition")).strip_edges()
	out ["domain"] = str(out.get("domain", "generic")).strip_edges().to_lower()
	out ["display_name"] = str(out.get("display_name", out.get("id", "Scoped Reality Composition")))
	out ["authority_required"] = str(out.get("authority_required", "local_event")).strip_edges().to_lower()

	if typeof(out.get("composition_stack", [])) != TYPE_ARRAY:
		out ["composition_stack"] = []

	if typeof(out.get("effects", [])) != TYPE_ARRAY:
		out ["effects"] = []

	return out


func _normalize_intent(intent_payload: Variant, context: Dictionary = {}) -> Dictionary:
	if typeof(intent_payload) == TYPE_DICTIONARY:
		var out: Dictionary = (intent_payload as Dictionary).duplicate(true)
		out ["schema"] = str(out.get("schema", "eralife.reality_intent"))
		out ["id"] = str(out.get("id", out.get("command", out.get("action_id", "runtime.intent")))).strip_edges()

		if not out.has("domain"):
			out ["domain"] = _domain_from_command(str(out.get("id", "")), context)

		if not out.has("authority"):
			out ["authority"] = str(context.get("authority", "local_event")).strip_edges().to_lower()

		return out

	var text: String = str(intent_payload).strip_edges()
	return {
		"schema": "eralife.reality_intent",
		"id": text if text != "" else "runtime.intent",
		"domain": _domain_from_command(text, context),
		"authority": str(context.get("authority", "local_event")).strip_edges().to_lower(),
		"text": text
	}


func _domain_from_command(command_id: String, context: Dictionary = {}) -> String:
	var clean_command: String = str(command_id).strip_edges().to_lower()

	if clean_command.begins_with("bending.") or clean_command.begins_with("tournament.") or clean_command.begins_with("competitive."):
		return "competitive"

	if clean_command.begins_with("birth.") or clean_command.find("birth") >= 0:
		return "birth"

	if clean_command.begins_with("fusion.") or clean_command.begins_with("reality_fusion."):
		return "reality_fusion"

	if clean_command.begins_with("red_bonnet.") or clean_command.begins_with("bonnet.") or clean_command.find("red_bonnet") >= 0:
		return "red_bonnet"

	if clean_command.begins_with("upce.") or clean_command.begins_with("perception.") or clean_command.begins_with("social_physics.") or clean_command.begins_with("myth.") or clean_command.begins_with("rumor."):
		return "perception"

	if clean_command.begins_with("hero.") or clean_command.begins_with("superhero.") or clean_command.begins_with("power.") or clean_command.begins_with("villain.") or clean_command.begins_with("infamy."):
		return "superhero"
	if clean_command.begins_with("artifact.") or clean_command.begins_with("artifacts.") or clean_command.begins_with("stone.") or clean_command.begins_with("infinity_stone."):
		return "artifacts"

	if clean_command.begins_with("character.") or clean_command.begins_with("character_creator.") or clean_command.begins_with("creator.") or clean_command.begins_with("identity."):
		return "character_creation"

	if clean_command.begins_with("school.") or clean_command.begins_with("education.") or clean_command.begins_with("student.") or clean_command.begins_with("classroom."):
		return "education"

	if clean_command.begins_with("runtime.") or clean_command.begins_with("save.") or clean_command.begins_with("hydrate."):
		return "runtime"

	return str(context.get("domain", "generic")).strip_edges().to_lower()


func _select_contracts(intent: Dictionary, context: Dictionary = {}) -> Array:
	var selected: Array = []
	var domain: String = str(intent.get("domain", context.get("domain", "generic"))).strip_edges().to_lower()

	for raw_key in contract_registry.keys():
		var contract: Dictionary = _safe_dictionary(contract_registry.get(raw_key, {}))
		if contract.is_empty():
			continue

		if str(contract.get("domain", "")).strip_edges().to_lower() == domain:
			selected.append(contract.duplicate(true))

	for engine_id in _orchestrated_engine_ids_for_domain(domain):
		selected.append(_engine_contract_packet(str(engine_id), domain))

	if gs != null and "game_state_contract_engine" in gs and gs.game_state_contract_engine != null:
		if gs.game_state_contract_engine.has_method("export_meta_contract_layer"):
			var meta_layer: Dictionary = gs.game_state_contract_engine.export_meta_contract_layer()
			selected.append({
				"id": "game_state_contract_engine.meta_contract_layer",
				"domain": "meta_contract",
				"authority_required": "meta_contract",
				"source_engine": "game_state_contract_engine",
				"meta_contract_layer": meta_layer.duplicate(true)
			})

	if gs != null and "mod_loader" in gs and gs.mod_loader != null:
		if gs.mod_loader.has_method("export_registry"):
			var mod_registry: Dictionary = gs.mod_loader.export_registry()
			selected.append({
				"id": "mod_loader.contract_registry",
				"domain": "mods",
				"authority_required": "domain",
				"source_engine": "mod_loader",
				"mod_registry": mod_registry.duplicate(true)
			})

	if gs != null and "ui_contract_engine" in gs and gs.ui_contract_engine != null:
		if gs.ui_contract_engine.has_method("export_registry"):
			var ui_registry: Dictionary = gs.ui_contract_engine.export_registry()
			selected.append({
				"id": "ui_contract_engine.registry",
				"domain": "ui",
				"authority_required": "local_event",
				"source_engine": "ui_contract_engine",
				"ui_registry": ui_registry.duplicate(true)
			})

	return selected

func _orchestrated_engine_ids_for_domain(domain: String) -> Array:
	var clean_domain: String = str(domain).strip_edges().to_lower()

	match clean_domain:
		"competitive":
			return [
				"competitive_reality_runtime",
				"bending_engine",
				"bending_tournament_engine",
				"reality_surge_engine",
				"ui_contract_engine",
				"world_feed_engine",
				"world_chronicle_engine"
			]
		"birth":
			return [
				"birth_contract_engine",
				"character_creator",
				"game_state_contract_engine",
				"game_state_hydration_runtime",
				"game_state_serialization_runtime",
				"ui_contract_engine",
				"embedded_ui_contract_engine",
				"mod_loader"
			]
		"character_creation":
			return [
				"character_creator",
				"birth_contract_engine",
				"names_db",
				"npc_factory",
				"game_state_contract_engine",
				"ui_contract_engine",
				"embedded_ui_contract_engine"
			]
		"education":
			return [
				"school_engine",
				"career_engine",
				"relationship_engine",
				"memory_engine",
				"life_engine",
				"ui_contract_engine",
				"world_feed_engine"
			]
		"superhero":
			return [
				"power_engine",
				"superhero_engine",
				"infamy_engine",
				"scenario_engine",
				"reality_surge_engine",
				"ui_contract_engine",
				"world_feed_engine",
				"world_chronicle_engine"
			]
		"artifacts":
			return [
				"artifacts_engine",
				"belongings_engine",
				"reality_surge_engine",
				"world_feed_engine",
				"world_chronicle_engine",
				"ui_contract_engine"
			]
		"red_bonnet":
			return [
				"red_bonnet_engine",
				"artifacts_engine",
				"dynasty_legacy_engine",
				"relationship_engine",
				"memory_engine",
				"reality_surge_engine",
				"world_feed_engine",
				"world_chronicle_engine",
				"game_state_contract_engine",
				"ui_contract_engine"
			]
		"runtime":
			return [
				"game_state_contract_engine",
				"game_state_hydration_runtime",
				"game_state_serialization_runtime",
				"temporal_slice_transformation_runtime",
				"simulation_contract_engine",
				"ui_contract_engine",
				"embedded_ui_contract_engine",
				"mod_loader"
			]
		"reality_fusion":
			return [
				"reality_fusion_engine",
				"reality_surge_engine",
				"game_state_contract_engine",
				"game_state_hydration_runtime",
				"ui_contract_engine",
				"world_chronicle_engine"
			]
		"perception":
			return [
				"upce_engine",
				"memory_engine",
				"relationship_engine",
				"reputation_engine",
				"fame_engine",
				"scenario_engine",
				"world_feed_engine",
				"world_chronicle_engine"
			]

	return []


func _apply_perception_contract_extensions() -> void:
	var boundaries: Dictionary = _safe_dictionary(active_contract.get("domain_boundaries", {}))

	if not boundaries.has("perception"):
		boundaries ["perception"] = {
			"authority_required": "domain",
			"allowed_engines": [
				"upce_engine",
				"memory_engine",
				"relationship_engine",
				"reputation_engine",
				"fame_engine",
				"scenario_engine",
				"world_feed_engine",
				"world_chronicle_engine"
			],
			"allowed_effects": [
				"event_interpretation",
				"memory_seeding",
				"emotional_physics",
				"reputation_propagation",
				"relationship_update",
				"fame_bridge",
				"scenario_hooks",
				"world_feed_signal",
				"historical_storage",
				"myth_formation"
			],
			"blocked_effects": [
				"direct_identity_rewrite",
				"unbounded_memory_overwrite",
				"fame_engine_bypass",
				"relationship_engine_bypass",
				"meta_contract_patch_without_authority"
			],
			"composition_stack": [
				"upce_engine",
				"bias_profile_resolver",
				"memory_engine",
				"relationship_engine",
				"reputation_engine",
				"fame_engine",
				"scenario_engine",
				"world_feed_engine",
				"historical_storage",
				"myth_formation"
			]
		}

	active_contract ["domain_boundaries"] = boundaries

	var contracts: Array = _safe_array(active_contract.get("orchestration_contracts", []))
	var has_perception_contract: bool = false

	for raw_contract in contracts:
		if typeof(raw_contract) != TYPE_DICTIONARY:
			continue
		if str((raw_contract as Dictionary).get("id", "")).strip_edges() == "perception.scoped_reality_composition":
			has_perception_contract = true
			break

	if not has_perception_contract:
		contracts.append({
			"id": "perception.scoped_reality_composition",
			"domain": "perception",
			"display_name": "Universal Perception & Consequence Composition",
			"authority_required": "domain",
			"composition_stack": [
				"upce_engine",
				"bias_profile_resolver",
				"memory_engine",
				"relationship_engine",
				"reputation_engine",
				"fame_engine",
				"scenario_engine",
				"world_feed_engine",
				"historical_storage",
				"myth_formation"
			]
		})

	active_contract ["orchestration_contracts"] = contracts
func _engine_contract_packet(engine_id: String, domain: String) -> Dictionary:
	var engine = _engine_instance(engine_id)
	if engine == null:
		return {
			"id": "%s.unavailable" % engine_id,
			"domain": domain,
			"source_engine": engine_id,
			"available": false,
			"authority_required": "local_event"
		}

	var packet: Dictionary = {
		"id": "%s.contract_presence" % engine_id,
		"domain": domain,
		"source_engine": engine_id,
		"available": true,
		"authority_required": "domain",
		"engine_class": str(engine.get_class()) if engine is Object else str(typeof(engine))
	}

	if engine is Object:
		if engine.has_method("export_contract"):
			var contract_raw: Variant = engine.export_contract()
			if typeof(contract_raw) == TYPE_DICTIONARY:
				packet ["contract"] = (contract_raw as Dictionary).duplicate(true)
		elif engine.has_method("get_contract_snapshot"):
			var snapshot_raw: Variant = engine.get_contract_snapshot()
			if typeof(snapshot_raw) == TYPE_DICTIONARY:
				packet ["contract"] = (snapshot_raw as Dictionary).duplicate(true)
		elif engine.has_method("export_registry"):
			var registry_raw: Variant = engine.export_registry()
			if typeof(registry_raw) == TYPE_DICTIONARY:
				packet ["registry"] = (registry_raw as Dictionary).duplicate(true)

	return packet
func _resolve_orchestration_boundary(domain: String, authority_id: String, intent: Dictionary, selected_contracts: Array, _context: Dictionary = {}) -> Dictionary:
	var boundaries: Dictionary = _safe_dictionary(active_contract.get("domain_boundaries", {}))
	var boundary: Dictionary = _safe_dictionary(boundaries.get(domain, {}))

	if boundary.is_empty():
		boundary = {
			"authority_required": "local_event",
			"allowed_engines": [],
			"allowed_effects": [],
			"blocked_effects": [],
			"composition_stack": []
		}

	var required_authority: String = str(boundary.get("authority_required", "local_event")).strip_edges().to_lower()
	var actual_rank: int = _authority_rank(authority_id)
	var required_rank: int = _authority_rank(required_authority)
	var authorized: bool = actual_rank >= required_rank

	var effects: Array = _safe_array(intent.get("effects", []))
	var blocked_effects: Array = _safe_array(boundary.get("blocked_effects", []))
	var blocked_requested: Array = []

	for raw_effect in effects:
		var effect: String = str(raw_effect).strip_edges()
		if effect in blocked_effects:
			blocked_requested.append(effect)

	if not blocked_requested.is_empty():
		authorized = false

	return {
		"schema": "eralife.reality_orchestration_boundary_report",
		"version": CONTRACT_VERSION,
		"authorized": authorized,
		"domain": domain,
		"authority": authority_id,
		"authority_rank": actual_rank,
		"required_authority": required_authority,
		"required_rank": required_rank,
		"allowed_engines": _safe_array(boundary.get("allowed_engines", [])),
		"allowed_effects": _safe_array(boundary.get("allowed_effects", [])),
		"blocked_effects": blocked_effects,
		"blocked_requested_effects": blocked_requested,
		"composition_stack": _safe_array(boundary.get("composition_stack", [])),
		"selected_contract_count": selected_contracts.size(),
		"reason": "authorized" if authorized else "Intent exceeds scoped reality composition boundary."
	}


func _resolve_contract_conflicts(selected_contracts: Array, boundary_report: Dictionary, context: Dictionary = {}) -> Dictionary:
	var by_id: Dictionary = {}
	var duplicates: Array = []
	var kept: Array = []

	for raw_contract in selected_contracts:
		if typeof(raw_contract) != TYPE_DICTIONARY:
			continue

		var contract: Dictionary = raw_contract
		var contract_id: String = str(contract.get("id", "")).strip_edges()

		if contract_id == "":
			continue

		if by_id.has(contract_id):
			duplicates.append(contract_id)
			var existing: Dictionary = _safe_dictionary(by_id.get(contract_id, {}))
			if int(contract.get("priority", 0)) >= int(existing.get("priority", 0)):
				by_id [contract_id] = contract.duplicate(true)
		else:
			by_id [contract_id] = contract.duplicate(true)

	for key in by_id.keys():
		kept.append(_safe_dictionary(by_id.get(key, {})))

	return {
		"schema": "eralife.reality_orchestration_conflict_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"conflict_policy": str(context.get("conflict_policy", "highest_priority")),
		"duplicates": duplicates,
		"resolved_contracts": kept,
		"resolved_count": kept.size(),
		"boundary_authorized": bool(boundary_report.get("authorized", false))
	}


func _resolve_reality_stability(intent: Dictionary, boundary_report: Dictionary, _conflict_report: Dictionary, _context: Dictionary = {}) -> Dictionary:
	var stability_contract: Dictionary = _safe_dictionary(active_contract.get("stability_contract", {}))
	var effects: Array = _safe_array(intent.get("effects", []))
	var cross_domain_edges: int = int(intent.get("cross_domain_edges", effects.size()))
	var mutation_weight: float = float(intent.get("mutation_weight", effects.size() * 8.0))
	var authority_rank: int = int(boundary_report.get("authority_rank", _authority_rank(str(intent.get("authority", "local_event")))))

	var max_edges: int = int(stability_contract.get("max_cross_domain_edges", 6))
	var max_mutation_weight: float = float(stability_contract.get("max_mutation_weight_without_reality_authority", 35.0))
	if authority_rank >= AUTHORITY_REALITY:
		max_mutation_weight = float(stability_contract.get("max_mutation_weight_with_reality_authority", 88.0))

	var instability: float = 0.0
	if cross_domain_edges > max_edges:
		instability += float(cross_domain_edges - max_edges) * 8.0

	if mutation_weight > max_mutation_weight:
		instability += mutation_weight - max_mutation_weight

	var hard_stop_threshold: float = float(stability_contract.get("hard_stop_threshold", 100.0))
	var allow_execution: bool = instability < hard_stop_threshold and bool(boundary_report.get("authorized", false))

	return {
		"schema": "eralife.reality_orchestration_stability_report",
		"version": CONTRACT_VERSION,
		"allow_execution": allow_execution,
		"instability": instability,
		"cross_domain_edges": cross_domain_edges,
		"max_cross_domain_edges": max_edges,
		"mutation_weight": mutation_weight,
		"max_mutation_weight": max_mutation_weight,
		"hard_stop_threshold": hard_stop_threshold,
		"reason": "stable" if allow_execution else "Scoped reality composition stability guard blocked execution."
	}


func _compose_reality(intent: Dictionary, _selected_contracts: Array, boundary_report: Dictionary, conflict_report: Dictionary, stability_report: Dictionary, _context: Dictionary = {}) -> Dictionary:
	var stack: Array = _safe_array(intent.get("composition_stack", []))
	if stack.is_empty():
		stack = _safe_array(boundary_report.get("composition_stack", []))

	var resolved_contracts: Array = _safe_array(conflict_report.get("resolved_contracts", []))
	var layers: Array = []

	for raw_layer in stack:
		var layer_id: String = str(raw_layer).strip_edges()
		if layer_id == "":
			continue

		layers.append({
			"id": layer_id,
			"authorized": bool(boundary_report.get("authorized", false)),
			"authority": str(intent.get("authority", "local_event")),
			"domain": str(intent.get("domain", "generic")),
			"scope": "bounded",
			"write_mode": "deferred_or_routed",
			"mutation_allowed": bool(stability_report.get("allow_execution", false))
		})

	return {
		"schema": "eralife.scoped_reality_composition",
		"version": CONTRACT_VERSION,
		"intent_id": str(intent.get("id", "")),
		"domain": str(intent.get("domain", "generic")),
		"layers": layers,
		"layer_count": layers.size(),
		"contracts": resolved_contracts,
		"allowed_engines": _safe_array(boundary_report.get("allowed_engines", [])),
		"allowed_effects": _safe_array(boundary_report.get("allowed_effects", [])),
		"stability": stability_report.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec())
	}


func _route_execution(intent: Dictionary, composition: Dictionary, context: Dictionary = {}) -> Dictionary:
	var command_id: String = str(intent.get("command", intent.get("id", ""))).strip_edges().to_lower()
	var target_engine: String = str(intent.get("engine_property", intent.get("target", context.get("engine_property", "")))).strip_edges()
	var allowed_engines: Array = _safe_array(composition.get("allowed_engines", []))
	var event_payload: Dictionary = _safe_dictionary(intent.get("event_payload", {}))

	if bool(context.get("ui_intent_only", false)) or command_id.begins_with("ui.action."):
		return {
			"success": true,
			"mode": "ui_intent_packet_only",
			"reason": "UI intent was emitted as a contract packet without direct game logic execution.",
			"command": command_id,
			"intent": intent.duplicate(true),
			"composition": composition.duplicate(true)
		}

	if bool(context.get("prewarm_only", false)) or command_id == "ui.prewarm_surface" or command_id.begins_with("ui.prewarm.") or command_id.begins_with("red_bonnet.prewarm."):
		var prewarm_context: Dictionary = context.duplicate(true)
		for raw_key in event_payload.keys():
			prewarm_context [raw_key] = event_payload.get(raw_key)

		if command_id == "ui.prewarm_next_year" or command_id == "ui.prewarm.next_year" or command_id == "ui.prewarm.predictive_year":
			return prewarm_next_year_ui_surfaces(prewarm_context)

		if command_id == "ui.prewarm_surface_set" or command_id == "ui.prewarm_surfaces" or command_id == "ui.prewarm.surface_set" or bool(prewarm_context.get("multi_surface", false)):
			var surfaces: Array = _safe_array(intent.get("surfaces", event_payload.get("surfaces", prewarm_context.get("surfaces", []))))
			if bool(prewarm_context.get("streaming", true)):
				return queue_streaming_ui_surface_prewarm(surfaces, prewarm_context)
			return prewarm_ui_surface_set(surfaces, prewarm_context)

		if command_id == "ui.prewarm.red_bonnet_dragon_balls" or command_id == "red_bonnet.prewarm_dragon_balls" or bool(prewarm_context.get("prewarm_red_bonnet_dragon_balls", false)):
			return prewarm_red_bonnet_dragon_ball_summon(prewarm_context)

		var prewarm_surface_id: String = str(intent.get("surface_id", prewarm_context.get("surface_id", ""))).strip_edges()
		if prewarm_surface_id == "":
			prewarm_surface_id = str(event_payload.get("surface_id", "")).strip_edges()
		return prewarm_ui_surface(prewarm_surface_id, prewarm_context)

	if target_engine != "" and not allowed_engines.is_empty() and not target_engine in allowed_engines:
		return {
			"success": false,
			"mode": "blocked_by_boundary",
			"reason": "Target engine '%s' is outside the scoped reality composition boundary." % target_engine,
			"target_engine": target_engine
		}

	if target_engine != "":
		var engine = _engine_instance(target_engine)
		if engine != null and engine.has_method("route_command_envelope"):
			return engine.route_command_envelope(intent)

	if command_id.begins_with("competitive.") and gs != null and "competitive_reality_runtime" in gs and gs.competitive_reality_runtime != null:
		if gs.competitive_reality_runtime.has_method("record_match") and typeof(intent.get("event_payload", {})) == TYPE_DICTIONARY:
			return {
				"success": true,
				"mode": "competitive_runtime_ready",
				"engine": "competitive_reality_runtime",
				"composition": composition.duplicate(true),
				"event_payload": _safe_dictionary(intent.get("event_payload", {}))
			}

	if command_id.begins_with("birth.") and gs != null and "birth_contract_engine" in gs and gs.birth_contract_engine != null:
		if gs.birth_contract_engine.has_method("normalize_birth_intent"):
			var birth_intent: Dictionary = gs.birth_contract_engine.normalize_birth_intent(_safe_dictionary(intent.get("event_payload", intent)))
			return {
				"success": true,
				"mode": "birth_contract_normalized",
				"engine": "birth_contract_engine",
				"birth_intent": birth_intent.duplicate(true),
				"composition": composition.duplicate(true)
			}

	return {
		"success": true,
		"mode": "packet_only",
		"reason": "RealityOrchestrator composed the reality packet without direct execution.",
		"command": command_id,
		"composition": composition.duplicate(true)
	}
func prewarm_ui_surface(surface_id: String, context: Dictionary = {}) -> Dictionary:
	var clean_surface: String = str(surface_id).strip_edges()
	if clean_surface == "":
		return {
			"success": false,
			"mode": "ui_prewarm_failed",
			"reason": "Missing UI surface id."
		}

	if gs == null or not "ui_contract_engine" in gs or gs.ui_contract_engine == null:
		return {
			"success": false,
			"mode": "ui_prewarm_failed",
			"surface_id": clean_surface,
			"reason": "UIContractEngine unavailable."
		}

	if not gs.ui_contract_engine.has_method("prewarm_surface_packet"):
		return {
			"success": false,
			"mode": "ui_prewarm_failed",
			"surface_id": clean_surface,
			"reason": "UIContractEngine does not support prewarm_surface_packet yet."
		}

	var prewarm_context: Dictionary = context.duplicate(true)
	prewarm_context ["source"] = str(prewarm_context.get("source", "reality_orchestrator.prewarm_ui_surface"))
	prewarm_context ["prewarm_authority"] = true
	prewarm_context ["surface_id"] = clean_surface
	prewarm_context ["packet_contract_required"] = true
	prewarm_context ["perceived_truth_required"] = true

	var report: Dictionary = gs.ui_contract_engine.prewarm_surface_packet(clean_surface, prewarm_context, {
		"packet_contract_required": true,
		"source": "reality_orchestrator.prewarm_ui_surface"
	})
	var cache_key: String = _prewarm_packet_key(clean_surface, prewarm_context)
	var packet_raw: Variant = report.get("packet", {})
	var packet: Dictionary = packet_raw.duplicate(true) if typeof(packet_raw) == TYPE_DICTIONARY else {}
	var packet_ui_safe: bool = bool(packet.get("ui_safe", false))
	var packet_satisfied: bool = str(packet.get("contract_status", "")) == "satisfied"

	if bool(report.get("success", false)) and packet_ui_safe and packet_satisfied:
		prewarmed_packet_cache [cache_key] = {
			"surface_id": clean_surface,
			"report": report.duplicate(true),
			"context": prewarm_context.duplicate(true),
			"created_at_ms": int(Time.get_ticks_msec())
		}

	var out: Dictionary = {
		"success": bool(report.get("success", false)) and packet_ui_safe and packet_satisfied,
		"schema": "eralife.reality_orchestrator_ui_prewarm_report",
		"version": CONTRACT_VERSION,
		"mode": "ui_contract_satisfied_packet_prewarmed",
		"surface_id": clean_surface,
		"cache_key": cache_key,
		"ui_report": report.duplicate(true),
		"context": prewarm_context.duplicate(true),
		"ui_safe": packet_ui_safe,
		"contract_status": str(packet.get("contract_status", "unknown")),
		"packet_contract_id": str(packet.get("packet_contract_id", "")),
		"created_at_year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	_record_prewarm_report(out)
	last_prewarm_report = out.duplicate(true)
	return out

func prewarm_ui_surface_set(surface_rows: Array, context: Dictionary = {}) -> Dictionary:
	var base_context: Dictionary = context.duplicate(true)
	var batch_id: String = str(base_context.get("prewarm_batch_id", "surface_set_%d" % int(Time.get_ticks_msec())))
	base_context ["prewarm_batch_id"] = batch_id
	base_context ["streaming_multi_surface"] = bool(base_context.get("streaming_multi_surface", false))

	var results: Array = []
	var prewarmed_count: int = 0
	var failed_count: int = 0
	var skipped_count: int = 0

	for raw_row in surface_rows:
		var surface_id: String = ""
		var surface_context: Dictionary = base_context.duplicate(true)

		if typeof(raw_row) == TYPE_DICTIONARY:
			var row: Dictionary = raw_row as Dictionary
			surface_id = str(row.get("surface_id", row.get("id", ""))).strip_edges()

			var row_context: Dictionary = _safe_dictionary(row.get("context", {}))
			for raw_key in row_context.keys():
				surface_context [raw_key] = row_context.get(raw_key)

			if row.has("active_section_id"):
				surface_context ["active_section_id"] = str(row.get("active_section_id", "")).strip_edges()
			if row.has("revision"):
				surface_context ["revision"] = str(row.get("revision", "")).strip_edges()
		else:
			surface_id = str(raw_row).strip_edges()

		if surface_id == "":
			skipped_count += 1
			continue

		surface_context ["surface_id"] = surface_id
		surface_context ["prewarm_batch_id"] = batch_id

		var report: Dictionary = prewarm_ui_surface(surface_id, surface_context)
		results.append(report.duplicate(true))

		if bool(report.get("success", false)):
			prewarmed_count += 1
		else:
			failed_count += 1

	var out: Dictionary = {
		"success": prewarmed_count > 0,
		"schema": "eralife.reality_orchestrator_multi_surface_prewarm_report",
		"version": CONTRACT_VERSION,
		"mode": "ui_surface_set_prewarmed",
		"batch_id": batch_id,
		"requested_count": surface_rows.size(),
		"prewarmed_count": prewarmed_count,
		"failed_count": failed_count,
		"skipped_count": skipped_count,
		"results": results,
		"context": base_context.duplicate(true),
		"created_at_year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	_record_prewarm_report(out)
	last_prewarm_report = out.duplicate(true)
	return out


func queue_streaming_ui_surface_prewarm(surface_rows: Array, context: Dictionary = {}) -> Dictionary:
	if gs == null:
		return {
			"success": false,
			"schema": "eralife.reality_orchestrator_streaming_prewarm_queue_report",
			"version": CONTRACT_VERSION,
			"reason": "GameState unavailable."
		}
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var base_context: Dictionary = context.duplicate(true)
	var batch_id: String = str(base_context.get("prewarm_batch_id", "streaming_surface_set_%d" % int(Time.get_ticks_msec())))
	var queue: Array = _safe_array(gs.scenario_state.get("reality_orchestrator_streaming_prewarm_queue", []))
	var enqueued_count: int = 0
	var defer_row_context_until_flush: bool = bool(base_context.get("defer_row_context_until_flush", false))

	for raw_row in surface_rows:
		var surface_id: String = ""
		var surface_context: Dictionary = {}
		var row_context: Dictionary = {}
		var active_section_id: String = ""
		var revision: String = ""

		if typeof(raw_row) == TYPE_DICTIONARY:
			var row: Dictionary = raw_row as Dictionary
			surface_id = str(row.get("surface_id", row.get("id", ""))).strip_edges()
			row_context = _safe_dictionary(row.get("context", {}))
			active_section_id = str(row.get("active_section_id", "")).strip_edges()
			revision = str(row.get("revision", "")).strip_edges()
		else:
			surface_id = str(raw_row).strip_edges()

		if surface_id == "":
			continue

		if defer_row_context_until_flush:
			surface_context = {
				"surface_id": surface_id,
				"prewarm_batch_id": batch_id,
				"streaming_multi_surface": true
			}
			if active_section_id != "":
				surface_context ["active_section_id"] = active_section_id
			if revision != "":
				surface_context ["revision"] = revision
		else:
			surface_context = base_context.duplicate(true)
			for raw_key in row_context.keys():
				surface_context [raw_key] = row_context.get(raw_key)
			if active_section_id != "":
				surface_context ["active_section_id"] = active_section_id
			if revision != "":
				surface_context ["revision"] = revision
			surface_context ["surface_id"] = surface_id
			surface_context ["prewarm_batch_id"] = batch_id
			surface_context ["streaming_multi_surface"] = true

		queue.append({
			"surface_id": surface_id,
			"context": surface_context.duplicate(true),
			"base_context": base_context.duplicate(true) if defer_row_context_until_flush else {},
			"deferred_row_context": row_context.duplicate(true) if defer_row_context_until_flush else {},
			"defer_row_context_until_flush": defer_row_context_until_flush,
			"batch_id": batch_id,
			"queued_at_year": _current_year(),
			"queued_at_ms": int(Time.get_ticks_msec())
		})
		enqueued_count += 1

	gs.scenario_state ["reality_orchestrator_streaming_prewarm_queue"] = queue
	gs.scenario_state ["reality_orchestrator_streaming_prewarm_queue_size"] = queue.size()

	var budget: int = max(1, int(base_context.get("prewarm_budget", 3)))
	var manual_flush_after_shell: bool = bool(base_context.get("manual_flush_after_shell", false)) \
or bool(base_context.get("shell_first_manual_flush", false)) \
or bool(base_context.get("main_scene_drives_flush", false))
	var ui_shell_already_released: bool = bool(base_context.get("ui_shell_already_released", false))
	var auto_flush_enabled: bool = not manual_flush_after_shell and not ui_shell_already_released

	gs.scenario_state ["reality_orchestrator_streaming_prewarm_manual_flush"] = not auto_flush_enabled
	gs.scenario_state ["reality_orchestrator_streaming_prewarm_auto_flush_enabled"] = auto_flush_enabled
	gs.scenario_state ["reality_orchestrator_streaming_prewarm_flush_owner"] = "reality_orchestrator_call_deferred" if auto_flush_enabled else "main_scene_idle_timer"

	if auto_flush_enabled:
		call_deferred("_flush_streaming_ui_surface_prewarm_queue", budget)

	var out: Dictionary = {
		"success": enqueued_count > 0,
		"schema": "eralife.reality_orchestrator_streaming_prewarm_queue_report",
		"version": CONTRACT_VERSION,
		"mode": "streaming_ui_surface_prewarm_queued",
		"batch_id": batch_id,
		"enqueued_count": enqueued_count,
		"queue_size": queue.size(),
		"budget_per_flush": budget,
		"auto_flush_enabled": auto_flush_enabled,
		"manual_flush_after_shell": not auto_flush_enabled,
		"defer_row_context_until_flush": defer_row_context_until_flush,
		"flush_owner": str(gs.scenario_state.get("reality_orchestrator_streaming_prewarm_flush_owner", "")),
		"context": base_context.duplicate(true),
		"created_at_year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec())
	}
	_record_prewarm_report(out)
	last_prewarm_report = out.duplicate(true)
	return out
func queue_resident_safe_streaming_ui_surface_prewarm(
		surface_rows: Array,
		context: Dictionary = {}
) -> Dictionary:
	var safe_context: Dictionary = (
		context.duplicate(true)
	)

	safe_context [
		"manual_flush_after_shell"
	] = true
	safe_context [
		"shell_first_manual_flush"
	] = true
	safe_context [
		"main_scene_drives_flush"
	] = false
	safe_context [
		"resident_safe_orchestrator_pump"
	] = true
	safe_context [
		"ui_shell_already_released"
	] = true
	safe_context [
		"prewarm_budget"
	] = 1
	safe_context [
		"interactive_lens_has_absolute_priority"
	] = true
	safe_context [
		"optional_ui_prewarm_may_not_block_play"
	] = true

	var report: Dictionary = (
		queue_streaming_ui_surface_prewarm(
			surface_rows,
			safe_context
		)
	)

	if bool(
		report.get(
			"success",
			false
		)
	):
		resident_safe_streaming_prewarm_budget = 1

		if (
			gs != null
			and typeof(
				gs.scenario_state
			) == TYPE_DICTIONARY
		):
			gs.scenario_state [
				"reality_orchestrator_streaming_prewarm_flush_owner"
			] = (
				"reality_orchestrator_resident_safe_pump"
			)
			gs.scenario_state [
				"live_reality_surface_prewarm_pending"
			] = true
			gs.scenario_state [
				"live_reality_surface_prewarm_main_scene_flush_forbidden"
			] = true

		_ensure_resident_safe_streaming_prewarm_pump()

	report [
		"flush_owner"
	] = "reality_orchestrator_resident_safe_pump"
	report [
		"main_scene_flush_forbidden"
	] = true

	return report

func _resident_safe_streaming_prewarm_interactive_lens_attached() -> bool:
	if (
		gs == null
		or gs.reality_residency_manager == null
	):
		return false

	return str(
		gs.reality_residency_manager.attached_signature
	).strip_edges() != ""

func _ensure_resident_safe_streaming_prewarm_pump() -> void:
	if gs == null:
		resident_safe_streaming_prewarm_pump_armed = false
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var queue: Array = _safe_array(
		gs.scenario_state.get(
			"reality_orchestrator_streaming_prewarm_queue",
			[]
		)
	)

	if queue.is_empty():
		resident_safe_streaming_prewarm_pump_armed = false
		return

	if resident_safe_streaming_prewarm_pump_armed:
		return

	var tree:= Engine.get_main_loop() as SceneTree

	if tree == null:
		resident_safe_streaming_prewarm_pump_armed = false
		call_deferred(
			"_ensure_resident_safe_streaming_prewarm_pump"
		)
		return

	var interactive_lens_attached: bool = (
		_resident_safe_streaming_prewarm_interactive_lens_attached()
	)






	var delay_seconds: float = (
		0.25
		if interactive_lens_attached
		else 0.03
	)

	gs.scenario_state [
		"live_reality_surface_prewarm_interactive_lens_attached"
	] = interactive_lens_attached
	gs.scenario_state [
		"live_reality_surface_prewarm_interactive_lens_pauses_queue"
	] = interactive_lens_attached
	gs.scenario_state [
		"live_reality_surface_prewarm_one_packet_per_pump"
	] = not interactive_lens_attached
	gs.scenario_state [
		"live_reality_surface_prewarm_pause_reason"
	] = (
		"interactive_lens_absolute_priority_unbounded_packet"
		if interactive_lens_attached
		else ""
	)
	gs.scenario_state [
		"live_reality_surface_prewarm_pump_interval_ms"
	] = int(
		round(
			delay_seconds * 1000.0
		)
	)

	resident_safe_streaming_prewarm_pump_armed = true

	var timer:= tree.create_timer(
		delay_seconds,
		true,
		false,
		true
	)

	var connection_error: int = timer.timeout.connect(
		Callable(
			self,
			"_resident_safe_streaming_prewarm_pump_frame"
		),
		CONNECT_ONE_SHOT
	)

	if connection_error != OK:
		resident_safe_streaming_prewarm_pump_armed = false
		call_deferred(
			"_ensure_resident_safe_streaming_prewarm_pump"
		)
func _resident_safe_streaming_prewarm_pump_frame() -> void:
	resident_safe_streaming_prewarm_pump_armed = false

	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var queue: Array = _safe_array(
		gs.scenario_state.get(
			"reality_orchestrator_streaming_prewarm_queue",
			[]
		)
	)

	if queue.is_empty():
		gs.scenario_state [
			"live_reality_surface_prewarm_pending"
		] = false
		gs.scenario_state [
			"live_reality_surface_prewarm_complete"
		] = true
		gs.scenario_state [
			"live_reality_surface_prewarm_completed_at_ms"
		] = int(
			Time.get_ticks_msec()
		)
		return

	var interactive_lens_attached: bool = (
		_resident_safe_streaming_prewarm_interactive_lens_attached()
	)




	if interactive_lens_attached:
		gs.scenario_state [
			"live_reality_surface_prewarm_paused_for_interactive_lens"
		] = true
		gs.scenario_state [
			"live_reality_surface_prewarm_interactive_lens_throttled"
		] = false
		gs.scenario_state [
			"live_reality_surface_prewarm_pause_reason"
		] = "interactive_lens_absolute_priority_unbounded_packet"
		gs.scenario_state [
			"live_reality_surface_prewarm_flush_budget"
		] = 0
		gs.scenario_state [
			"live_reality_surface_prewarm_pending"
		] = true
		gs.scenario_state [
			"live_reality_surface_prewarm_remaining"
		] = queue.size()
		gs.scenario_state [
			"live_reality_surface_prewarm_last_flush_while_attached"
		] = false

		_ensure_resident_safe_streaming_prewarm_pump()
		return

	gs.scenario_state [
		"live_reality_surface_prewarm_paused_for_interactive_lens"
	] = false
	gs.scenario_state [
		"live_reality_surface_prewarm_interactive_lens_throttled"
	] = false
	gs.scenario_state [
		"live_reality_surface_prewarm_pause_reason"
	] = ""
	gs.scenario_state [
		"live_reality_surface_prewarm_flush_budget"
	] = 1

	var flush_report: Dictionary = (
		_flush_streaming_ui_surface_prewarm_queue(
			1
		)
	)
	var remaining: int = int(
		flush_report.get(
			"remaining",
			0
		)
	)

	gs.scenario_state [
		"live_reality_surface_prewarm_last_flush_report"
	] = flush_report.duplicate(true)
	gs.scenario_state [
		"live_reality_surface_prewarm_last_flush_at_ms"
	] = int(
		Time.get_ticks_msec()
	)
	gs.scenario_state [
		"live_reality_surface_prewarm_last_flush_while_attached"
	] = false

	if remaining > 0:
		gs.scenario_state [
			"live_reality_surface_prewarm_pending"
		] = true
		gs.scenario_state [
			"live_reality_surface_prewarm_remaining"
		] = remaining

		_ensure_resident_safe_streaming_prewarm_pump()
		return

	gs.scenario_state [
		"live_reality_surface_prewarm_pending"
	] = false
	gs.scenario_state [
		"live_reality_surface_prewarm_complete"
	] = true
	gs.scenario_state [
		"live_reality_surface_prewarm_remaining"
	] = 0
	gs.scenario_state [
		"live_reality_surface_prewarm_completed_at_ms"
	] = int(
		Time.get_ticks_msec()
	)
func _flush_streaming_ui_surface_prewarm_queue(max_count: int = 3) -> Dictionary:
	if gs == null:
		return {
			"success": false,
			"reason": "GameState unavailable."
		}
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var queue: Array = _safe_array(gs.scenario_state.get("reality_orchestrator_streaming_prewarm_queue", []))
	if queue.is_empty():
		gs.scenario_state ["reality_orchestrator_streaming_prewarm_queue_size"] = 0
		gs.scenario_state ["reality_orchestrator_streaming_prewarm_manual_flush"] = false
		gs.scenario_state ["reality_orchestrator_streaming_prewarm_waiting_external_flush"] = false
		return {
			"success": true,
			"processed": 0,
			"remaining": 0
		}

	var budget: int = max(1, int(max_count))
	var processed: int = 0
	var prewarmed_count: int = 0
	var failed_count: int = 0
	var results: Array = []

	while processed < budget and not queue.is_empty():
		var row: Dictionary = _safe_dictionary(queue.pop_front())
		var surface_id: String = str(row.get("surface_id", "")).strip_edges()
		var surface_context: Dictionary = _safe_dictionary(row.get("context", {}))

		if bool(row.get("defer_row_context_until_flush", false)):
			var base_context: Dictionary = _safe_dictionary(row.get("base_context", {}))
			var deferred_row_context: Dictionary = _safe_dictionary(row.get("deferred_row_context", {}))
			var materialized_context: Dictionary = base_context.duplicate(true)

			for raw_key in deferred_row_context.keys():
				materialized_context [raw_key] = deferred_row_context.get(raw_key)

			materialized_context ["surface_id"] = surface_id
			materialized_context ["prewarm_batch_id"] = str(row.get("batch_id", ""))
			materialized_context ["streaming_multi_surface"] = true

			for raw_key in surface_context.keys():
				materialized_context [raw_key] = surface_context.get(raw_key)

			surface_context = materialized_context

		if surface_id == "":
			processed += 1
			continue

		var report: Dictionary = prewarm_ui_surface(surface_id, surface_context)
		results.append(report.duplicate(true))

		if bool(report.get("success", false)):
			prewarmed_count += 1
		else:
			failed_count += 1

		processed += 1

	gs.scenario_state ["reality_orchestrator_streaming_prewarm_queue"] = queue
	gs.scenario_state ["reality_orchestrator_streaming_prewarm_queue_size"] = queue.size()

	var manual_flush: bool = bool(gs.scenario_state.get("reality_orchestrator_streaming_prewarm_manual_flush", false))
	gs.scenario_state ["reality_orchestrator_streaming_prewarm_last_flush"] = {
		"processed": processed,
		"prewarmed_count": prewarmed_count,
		"failed_count": failed_count,
		"remaining": queue.size(),
		"manual_flush": manual_flush,
		"flush_owner": str(gs.scenario_state.get("reality_orchestrator_streaming_prewarm_flush_owner", "")),
		"flushed_at_year": _current_year(),
		"flushed_at_ms": int(Time.get_ticks_msec())
	}

	var out: Dictionary = {
		"success": true,
		"schema": "eralife.reality_orchestrator_streaming_prewarm_flush_report",
		"version": CONTRACT_VERSION,
		"mode": "streaming_ui_surface_prewarm_flushed",
		"processed": processed,
		"prewarmed_count": prewarmed_count,
		"failed_count": failed_count,
		"remaining": queue.size(),
		"manual_flush": manual_flush,
		"flush_owner": str(gs.scenario_state.get("reality_orchestrator_streaming_prewarm_flush_owner", "")),
		"results": results,
		"created_at_year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec())
	}
	_record_prewarm_report(out)
	last_prewarm_report = out.duplicate(true)

	if not queue.is_empty():
		if manual_flush:
			gs.scenario_state ["reality_orchestrator_streaming_prewarm_waiting_external_flush"] = true
			gs.scenario_state ["reality_orchestrator_streaming_prewarm_external_flush_reason"] = "main_scene_idle_timer_owns_shell_first_flush"
		else:
			call_deferred("_flush_streaming_ui_surface_prewarm_queue", budget)
	else:
		gs.scenario_state ["reality_orchestrator_streaming_prewarm_manual_flush"] = false
		gs.scenario_state ["reality_orchestrator_streaming_prewarm_waiting_external_flush"] = false

	return out


func prewarm_next_year_ui_surfaces(context: Dictionary = {}) -> Dictionary:
	var next_context: Dictionary = context.duplicate(true)
	var target_year: int = int(next_context.get("target_year", next_context.get("next_year", _current_year() + 1)))
	if target_year <= _current_year():
		target_year = _current_year() + 1

	next_context ["source"] = str(next_context.get("source", "reality_orchestrator.predictive_next_year_prewarm"))
	next_context ["year"] = target_year
	next_context ["target_year"] = target_year
	next_context ["predictive_ui"] = true
	next_context ["prewarm_phase"] = "next_year_predictive"
	next_context ["revision"] = str(next_context.get("revision", "predictive_year:%d" % target_year))

	if not next_context.has("actor_id") and gs != null and "player" in gs and gs.player != null:
		next_context ["actor_id"] = int(gs.player.id)

	var surfaces: Array = _safe_array(next_context.get("surfaces", []))
	if surfaces.is_empty():
		surfaces = _predictive_ui_surface_rows(next_context)

	var red_bonnet_report: Dictionary = {}
	if bool(next_context.get("prewarm_artifact_transitions", true)):
		red_bonnet_report = prewarm_red_bonnet_dragon_ball_summon(next_context)

	var queue_report: Dictionary = queue_streaming_ui_surface_prewarm(surfaces, next_context)
	queue_report ["red_bonnet_dragon_ball_prewarm"] = red_bonnet_report.duplicate(true)
	queue_report ["predictive_surface_count"] = surfaces.size()
	queue_report ["target_year"] = target_year
	last_prewarm_report = queue_report.duplicate(true)
	return queue_report


func _predictive_ui_surface_rows(context: Dictionary = {}) -> Array:
	var out: Array = []
	var max_surfaces: int = max(1, int(context.get("max_predictive_surfaces", 36)))

	if gs != null and "ui_contract_engine" in gs and gs.ui_contract_engine != null:
		if gs.ui_contract_engine.has_method("export_registry"):
			var registry: Dictionary = _safe_dictionary(gs.ui_contract_engine.export_registry())
			var surface_registry: Dictionary = _safe_dictionary(registry.get("surface_registry", {}))

			for raw_surface_id in surface_registry.keys():
				if out.size() >= max_surfaces:
					break

				var surface_id: String = str(raw_surface_id).strip_edges()
				if surface_id == "":
					continue

				var surface_context: Dictionary = context.duplicate(true)
				surface_context ["surface_id"] = surface_id

				out.append({
					"surface_id": surface_id,
					"context": surface_context.duplicate(true)
				})

				var surface: Dictionary = _safe_dictionary(surface_registry.get(raw_surface_id, {}))
				var sections: Array = _safe_array(surface.get("sections", []))
				for raw_section in sections:
					if out.size() >= max_surfaces:
						break
					if typeof(raw_section) != TYPE_DICTIONARY:
						continue

					var section: Dictionary = raw_section as Dictionary
					var section_id: String = str(section.get("id", "")).strip_edges()
					if section_id == "":
						continue

					var section_context: Dictionary = context.duplicate(true)
					section_context ["surface_id"] = surface_id
					section_context ["active_section_id"] = section_id

					out.append({
						"surface_id": surface_id,
						"active_section_id": section_id,
						"context": section_context.duplicate(true)
					})

	if out.is_empty():
		var fallback_context: Dictionary = context.duplicate(true)
		fallback_context ["surface_id"] = "life_panel"
		out.append({
			"surface_id": "life_panel",
			"context": fallback_context.duplicate(true)
		})

	return out


func prewarm_red_bonnet_dragon_ball_summon(context: Dictionary = {}) -> Dictionary:
	if gs == null:
		return {
			"success": false,
			"schema": "eralife.reality_orchestrator_red_bonnet_dragon_ball_prewarm_report",
			"version": CONTRACT_VERSION,
			"reason": "GameState unavailable."
		}

	if not "red_bonnet_engine" in gs or gs.red_bonnet_engine == null:
		return {
			"success": false,
			"schema": "eralife.reality_orchestrator_red_bonnet_dragon_ball_prewarm_report",
			"version": CONTRACT_VERSION,
			"reason": "RedBonnetEngine unavailable."
		}

	if not gs.red_bonnet_engine.has_method("build_dragon_ball_summon_transition_packet"):
		return {
			"success": false,
			"schema": "eralife.reality_orchestrator_red_bonnet_dragon_ball_prewarm_report",
			"version": CONTRACT_VERSION,
			"reason": "RedBonnetEngine does not expose build_dragon_ball_summon_transition_packet yet."
		}

	var actor: Person = null
	var actor_raw: Variant = context.get("actor", null)
	if actor_raw is Person:
		actor = actor_raw as Person
	elif gs != null and "player" in gs and gs.player != null:
		actor = gs.player

	if actor == null:
		return {
			"success": false,
			"schema": "eralife.reality_orchestrator_red_bonnet_dragon_ball_prewarm_report",
			"version": CONTRACT_VERSION,
			"reason": "Actor unavailable."
		}

	var force_prewarm: bool = bool(context.get("force_prewarm", context.get("force", false)))
	if not force_prewarm and not _actor_has_red_bonnet_prewarm_authority(actor):
		return {
			"success": false,
			"schema": "eralife.reality_orchestrator_red_bonnet_dragon_ball_prewarm_report",
			"version": CONTRACT_VERSION,
			"mode": "red_bonnet_dragon_ball_prewarm_skipped",
			"reason": "Actor does not currently expose Red Bonnet prewarm authority.",
			"actor_id": int(actor.id)
		}

	var clean_wish: String = str(context.get("wish_key", "summon_dragon_balls")).strip_edges().to_lower()
	if clean_wish == "":
		clean_wish = "summon_dragon_balls"

	var payload: Dictionary = _safe_dictionary(context.get("payload", {}))
	payload ["wish_key"] = clean_wish
	payload ["source"] = str(payload.get("source", context.get("source", "reality_orchestrator.red_bonnet_dragon_ball_prewarm")))
	payload ["visual_only"] = true
	payload ["defer_runtime_effects"] = true
	payload ["renderer_first"] = true
	payload ["prewarm_authority"] = true

	var transition_packet: Dictionary = gs.red_bonnet_engine.build_dragon_ball_summon_transition_packet(actor, payload)
	if transition_packet.is_empty():
		return {
			"success": false,
			"schema": "eralife.reality_orchestrator_red_bonnet_dragon_ball_prewarm_report",
			"version": CONTRACT_VERSION,
			"reason": "RedBonnetEngine returned an empty Dragon Ball transition packet.",
			"actor_id": int(actor.id),
			"wish_key": clean_wish
		}

	var surface_id: String = str(context.get("surface_id", "red_bonnet_dragon_ball_summon_transition")).strip_edges()
	if surface_id == "":
		surface_id = "red_bonnet_dragon_ball_summon_transition"

	var cache_context: Dictionary = context.duplicate(true)
	cache_context ["source"] = "reality_orchestrator.red_bonnet_dragon_ball_prewarm"
	cache_context ["surface_id"] = surface_id
	cache_context ["actor_id"] = int(actor.id)
	cache_context ["wish_key"] = clean_wish

	var active_section_id: String = str(cache_context.get("active_section_id", "red_bonnet")).strip_edges()
	if active_section_id == "":
		active_section_id = "red_bonnet"
	cache_context ["active_section_id"] = active_section_id

	var revision: String = str(cache_context.get("revision", "")).strip_edges()
	if revision == "":
		revision = "red_bonnet_dragon_ball:%d:%s" % [_current_year(), clean_wish]
	cache_context ["revision"] = revision

	var cache_key: String = _prewarm_packet_key(surface_id, cache_context)

	transition_packet ["prewarmed"] = true
	transition_packet ["prewarm_cache_key"] = cache_key
	transition_packet ["prewarm_surface_id"] = surface_id
	transition_packet ["prewarmed_at_ms"] = int(Time.get_ticks_msec())

	var report: Dictionary = {
		"success": true,
		"schema": "eralife.reality_orchestrator_red_bonnet_dragon_ball_prewarm_report",
		"version": CONTRACT_VERSION,
		"mode": "red_bonnet_dragon_ball_transition_prewarmed",
		"surface_id": surface_id,
		"cache_key": cache_key,
		"actor_id": int(actor.id),
		"wish_key": clean_wish,
		"packet": transition_packet.duplicate(true),
		"context": cache_context.duplicate(true),
		"created_at_year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	prewarmed_packet_cache [cache_key] = {
		"surface_id": surface_id,
		"report": report.duplicate(true),
		"context": cache_context.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	_record_prewarm_report(report)
	last_prewarm_report = report.duplicate(true)
	return report


func _actor_has_red_bonnet_prewarm_authority(actor: Person) -> bool:
	if actor == null:
		return false

	if typeof(actor.traits) == TYPE_ARRAY:
		if "RedBonnetBearer" in actor.traits:
			return true
		if "RedBonnetDragonBallSynergy" in actor.traits:
			return true

	if gs != null and "belongings_engine" in gs and gs.belongings_engine != null:
		if gs.belongings_engine.has_method("has_item_named"):
			return bool(gs.belongings_engine.has_item_named(actor, "Artifacts", "Red Bonnet"))

	return false
func consume_prewarmed_ui_surface_packet(surface_id: String, context: Dictionary = {}) -> Dictionary:
	var clean_surface: String = str(surface_id).strip_edges()
	if clean_surface == "":
		return {}

	var consume_context: Dictionary = context.duplicate(true)
	consume_context ["surface_id"] = clean_surface
	consume_context ["packet_contract_required"] = true
	consume_context ["perceived_truth_required"] = true

	if gs != null and "ui_contract_engine" in gs and gs.ui_contract_engine != null:
		if gs.ui_contract_engine.has_method("consume_prewarmed_surface_packet"):
			var engine_packet: Dictionary = gs.ui_contract_engine.consume_prewarmed_surface_packet(clean_surface, consume_context)
			if not engine_packet.is_empty() and bool(engine_packet.get("ui_safe", false)) and str(engine_packet.get("contract_status", "")) == "satisfied":
				engine_packet ["consumed_from_ui_contract_engine_prewarm"] = true
				engine_packet ["consumed_at_ms"] = int(Time.get_ticks_msec())
				return engine_packet

	var cache_key: String = _prewarm_packet_key(clean_surface, consume_context)
	if prewarmed_packet_cache.has(cache_key):
		var cached_raw: Variant = prewarmed_packet_cache.get(cache_key, {})
		prewarmed_packet_cache.erase(cache_key)
		if typeof(cached_raw) == TYPE_DICTIONARY:
			var cached: Dictionary = cached_raw as Dictionary
			var report: Dictionary = _safe_dictionary(cached.get("report", {}))
			var cached_packet: Dictionary = _safe_dictionary(report.get("packet", {}))
			if not cached_packet.is_empty() and bool(cached_packet.get("ui_safe", false)) and str(cached_packet.get("contract_status", "")) == "satisfied":
				cached_packet ["consumed_from_reality_orchestrator_prewarm"] = true
				cached_packet ["consumed_at_ms"] = int(Time.get_ticks_msec())
				return cached_packet

	if gs != null and "ui_contract_engine" in gs and gs.ui_contract_engine != null:
		if gs.ui_contract_engine.has_method("build_ui_packet"):
			var fresh_packet: Dictionary = gs.ui_contract_engine.build_ui_packet(clean_surface, consume_context, {
				"use_prewarm": false,
				"packet_contract_required": true,
				"source": "reality_orchestrator.consume_prewarmed_ui_surface_packet.fresh_contract_fallback"
			})
			if not fresh_packet.is_empty() and bool(fresh_packet.get("ui_safe", false)) and str(fresh_packet.get("contract_status", "")) == "satisfied":
				fresh_packet ["consumed_from_contract_fallback"] = true
				fresh_packet ["consumed_at_ms"] = int(Time.get_ticks_msec())
				return fresh_packet

	return {}


func _prewarm_packet_key(surface_id: String, context: Dictionary = {}) -> String:
	var clean_surface: String = str(surface_id).strip_edges().to_lower()
	var actor_id: int = int(context.get("actor_id", -1))
	if actor_id <= 0 and gs != null and "player" in gs and gs.player != null:
		actor_id = int(gs.player.id)

	var device_profile: String = str(context.get("device_profile", context.get("platform", "auto"))).strip_edges().to_lower()
	var active_section_id: String = str(context.get("active_section_id", "")).strip_edges().to_lower()
	var revision: String = str(context.get("revision", context.get("diary_revision", context.get("year", "")))).strip_edges()

	return "%s::actor:%d::device:%s::section:%s::rev:%s" % [
		clean_surface,
		actor_id,
		device_profile,
		active_section_id,
		revision
	]


func _record_prewarm_report(report: Dictionary) -> void:
	var state: Dictionary = _world_state()
	var ledger: Array = _safe_array(state.get("prewarm_ledger", []))
	ledger.append(report.duplicate(true))

	while ledger.size() > 120:
		ledger.pop_front()

	state ["prewarm_ledger"] = ledger
	state ["last_prewarm_report"] = report.duplicate(true)
	_commit_world_state(state)

	if gs != null and "event_bus" in gs and gs.event_bus != null:
		if bool(_safe_dictionary(active_contract.get("runtime_policy", {})).get("emit_event_bus", true)):
			gs.event_bus.emit("reality.ui.prewarm.completed", report)
func _record_orchestration(report: Dictionary) -> void:
	var state: Dictionary = _world_state()
	var ledger: Array = _safe_array(state.get("orchestration_ledger", []))
	ledger.append(report.duplicate(true))

	while ledger.size() > MAX_ORCHESTRATION_LEDGER:
		ledger.pop_front()

	state ["orchestration_ledger"] = ledger
	state ["last_orchestration_report"] = report.duplicate(true)
	_commit_world_state(state)

	if gs != null and "event_bus" in gs and gs.event_bus != null:
		if bool(_safe_dictionary(active_contract.get("runtime_policy", {})).get("emit_event_bus", true)):
			gs.event_bus.emit("reality.orchestration.completed", report)


func _engine_instance(engine_property: String):
	if gs == null:
		return null

	var clean_engine: String = str(engine_property).strip_edges()
	if clean_engine == "":
		return null

	return gs.get(clean_engine)


func _authority_rank(authority_id: String) -> int:
	var clean_authority: String = str(authority_id).strip_edges().to_lower()
	var lattice: Dictionary = _safe_dictionary(active_contract.get("authority_lattice", {}))
	var row: Dictionary = _safe_dictionary(lattice.get(clean_authority, {}))

	if not row.is_empty():
		return int(row.get("rank", AUTHORITY_LOCAL_EVENT))

	match clean_authority:
		"meta_contract":
			return AUTHORITY_META_CONTRACT
		"reality":
			return AUTHORITY_REALITY
		"domain":
			return AUTHORITY_DOMAIN
		_:
			return AUTHORITY_LOCAL_EVENT


func _world_state() -> Dictionary:
	if gs == null:
		return _normalize_state({})

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var raw: Variant = gs.scenario_state.get(STATE_KEY, {})
	var state: Dictionary = {}

	if typeof(raw) == TYPE_DICTIONARY:
		state = (raw as Dictionary).duplicate(true)

	state = _normalize_state(state)
	gs.scenario_state [STATE_KEY] = state
	return state


func _normalize_state(state: Dictionary) -> Dictionary:
	var out: Dictionary = state.duplicate(true)
	out ["schema"] = str(out.get("schema", STATE_SCHEMA))
	out ["version"] = max(CONTRACT_VERSION, int(out.get("version", 1)))
	out ["save_key"] = str(out.get("save_key", STATE_KEY))
	out ["persistent"] = bool(out.get("persistent", true))
	out ["backwards_compatible"] = bool(out.get("backwards_compatible", true))
	out ["preserve_unknown_fields"] = bool(out.get("preserve_unknown_fields", true))

	if typeof(out.get("contract_registry", {})) != TYPE_DICTIONARY:
		out ["contract_registry"] = {}

	if typeof(out.get("orchestration_ledger", [])) != TYPE_ARRAY:
		out ["orchestration_ledger"] = []

	if typeof(out.get("last_orchestration_report", {})) != TYPE_DICTIONARY:
		out ["last_orchestration_report"] = {}

	if typeof(out.get("last_import_report", {})) != TYPE_DICTIONARY:
		out ["last_import_report"] = {}

	if typeof(out.get("authority_lattice", {})) != TYPE_DICTIONARY:
		out ["authority_lattice"] = _safe_dictionary(active_contract.get("authority_lattice", {}))

	if typeof(out.get("domain_boundaries", {})) != TYPE_DICTIONARY:
		out ["domain_boundaries"] = _safe_dictionary(active_contract.get("domain_boundaries", {}))

	if typeof(out.get("orchestration_snapshots", [])) != TYPE_ARRAY:
		out ["orchestration_snapshots"] = []

	if typeof(out.get("prewarm_ledger", [])) != TYPE_ARRAY:
		out ["prewarm_ledger"] = []

	if typeof(out.get("last_prewarm_report", {})) != TYPE_DICTIONARY:
		out ["last_prewarm_report"] = {}

	return out

func _commit_world_state(state: Dictionary) -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	gs.scenario_state [STATE_KEY] = _normalize_state(state)


func _current_year() -> int:
	if gs == null:
		return 0

	return int(gs.year)


func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _merge_dict(base: Dictionary, overlay: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)

	for raw_key in overlay.keys():
		var key: Variant = raw_key
		var incoming: Variant = overlay.get(key)

		if typeof(incoming) == TYPE_DICTIONARY and typeof(out.get(key, {})) == TYPE_DICTIONARY:
			out [key] = _merge_dict(_safe_dictionary(out.get(key, {})), _safe_dictionary(incoming))
		elif typeof(incoming) == TYPE_DICTIONARY:
			out [key] = _safe_dictionary(incoming)
		elif typeof(incoming) == TYPE_ARRAY:
			out [key] = (incoming as Array).duplicate(true)
		else:
			out [key] = incoming

	return out