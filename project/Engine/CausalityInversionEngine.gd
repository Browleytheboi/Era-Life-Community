extends Resource
class_name CausalityInversionEngine

const CONTRACT_SCHEMA:= "eralife.causality_inversion_contract"
const CONTRACT_VERSION:= 1
const STATE_SCHEMA:= "eralife.causality_inversion_state"
const STATE_KEY:= "causality_inversion_state"
const MAX_INVERSION_LEDGER:= 180

var gs
var active_contract: Dictionary = {}
var last_inversion_report: Dictionary = {}

func _init(_gs = null, contract: Dictionary = {}) -> void:
	gs = _gs
	set_contract(contract)


func set_contract(contract: Dictionary = {}) -> Dictionary:
	active_contract = _default_contract()
	if typeof(contract) == TYPE_DICTIONARY and not contract.is_empty():
		active_contract = _merge_dict(active_contract, contract)

	return {
		"success": true,
		"schema": "eralife.causality_inversion_contract_set_report",
		"version": CONTRACT_VERSION,
		"contract_id": str(active_contract.get("id", "cie.default")),
		"updated_at_ms": int(Time.get_ticks_msec())
	}


func bootstrap_default_contracts() -> Dictionary:
	var state: Dictionary = _world_state()
	state ["active_contract"] = active_contract.duplicate(true)
	_commit_world_state(state)

	return {
		"success": true,
		"schema": "eralife.causality_inversion_bootstrap_report",
		"version": CONTRACT_VERSION,
		"contract_id": str(active_contract.get("id", "cie.default")),
		"bootstrapped_at_ms": int(Time.get_ticks_msec())
	}


func export_state() -> Dictionary:
	return {
		"schema": STATE_SCHEMA,
		"version": CONTRACT_VERSION,
		"save_key": STATE_KEY,
		"persistent": true,
		"backwards_compatible": true,
		"preserve_unknown_fields": true,
		"active_contract": active_contract.duplicate(true),
		"world_state": _world_state().duplicate(true),
		"last_inversion_report": last_inversion_report.duplicate(true),
		"exported_at_ms": int(Time.get_ticks_msec())
	}


func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "CausalityInversionEngine import_state expected Dictionary."
		}

	var contract_raw: Variant = data.get("active_contract", {})
	if typeof(contract_raw) == TYPE_DICTIONARY:
		active_contract = _merge_dict(_default_contract(), contract_raw as Dictionary)
	else:
		active_contract = _default_contract()

	var world_state_raw: Variant = data.get("world_state", {})
	if typeof(world_state_raw) == TYPE_DICTIONARY:
		_commit_world_state(_normalize_state(world_state_raw as Dictionary))

	var report_raw: Variant = data.get("last_inversion_report", {})
	if typeof(report_raw) == TYPE_DICTIONARY:
		last_inversion_report = (report_raw as Dictionary).duplicate(true)

	return {
		"success": true,
		"schema": "eralife.causality_inversion_import_report",
		"version": CONTRACT_VERSION,
		"imported_at_ms": int(Time.get_ticks_msec())
	}


func build_local_shell_packet(actor: Person, intent: Dictionary, context: Dictionary = {}) -> Dictionary:
	var normalized: Dictionary = _normalize_intent(intent, context)
	var domain_contract: Dictionary = _domain_contract(str(normalized.get("domain", "runtime")))
	var pressure: Dictionary = _intent_pressure_packet(actor, normalized, domain_contract, context)

	return {
		"schema": "eralife.local_shell_perception_packet",
		"version": CONTRACT_VERSION,
		"accepted": true,
		"truth_status": "confidence_weighted",
		"intent": normalized.duplicate(true),
		"ips": pressure.duplicate(true),
		"local_shell": {
			"visibility_state": "visible",
			"interaction_state": "buffered",
			"execution_state": "streaming",
			"confidence": float(pressure.get("confidence", 0.5)),
			"text": _local_shell_text_for_intent(normalized)
		},
		"context": context.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec())
	}


func resolve_inverted_intent(actor: Person, intent: Dictionary, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "CIE requires an actor."
		}

	var normalized: Dictionary = _normalize_intent(intent, context)
	var domain_id: String = str(normalized.get("domain", "runtime")).strip_edges().to_lower()
	var action_id: String = str(normalized.get("action_id", normalized.get("intent", "runtime.intent"))).strip_edges().to_lower()
	var domain_contract: Dictionary = _domain_contract(domain_id)

	var local_shell: Dictionary = build_local_shell_packet(actor, normalized, context)
	var ips: Dictionary = _intent_pressure_packet(actor, normalized, domain_contract, context)
	var crbs: Dictionary = _crbs_authority_packet(domain_id, action_id, context)
	var cie: Dictionary = _cie_policy_packet(normalized, domain_contract, ips, crbs)
	var rias: Dictionary = _rias_identity_anchor(actor, normalized, domain_contract, cie)
	var cje: Dictionary = _causal_justification(actor, normalized, domain_contract, ips, cie)
	var existence: Dictionary = _resolve_existence(actor, normalized, domain_contract, ips, cie, rias, cje, context)
	var composition: Dictionary = _compose_retrofit_packet(actor, normalized, existence, cje, rias, context)

	var report: Dictionary = {
		"success": bool(existence.get("success", false)),
		"schema": "eralife.causality_inversion_report",
		"version": CONTRACT_VERSION,
		"intent_id": str(normalized.get("intent_id", "")),
		"domain": domain_id,
		"action_id": action_id,
		"local_shell": local_shell.duplicate(true),
		"ips": ips.duplicate(true),
		"crbs": crbs.duplicate(true),
		"cie": cie.duplicate(true),
		"cje": cje.duplicate(true),
		"rias": rias.duplicate(true),
		"existence": existence.duplicate(true),
		"canonical_truth": {
			"truth_layer": "remote_runtime" if bool(context.get("remote_truth_layer", false)) else "local_runtime_truth_proxy",
			"declared": bool(existence.get("success", false)),
			"canonical_entity": _safe_dictionary(existence.get("entity", {})),
			"canonical_entities": _safe_array(existence.get("entities", [])),
			"scenario_seed": _safe_dictionary(existence.get("scenario_seed", {})),
			"causal_debt": _safe_dictionary(cie.get("causal_debt", {}))
		},
		"reality_composition": composition.duplicate(true),
		"retrofit_packet": composition.duplicate(true),
		"scenario_seed": _safe_dictionary(existence.get("scenario_seed", {})),
		"popup_title": str(existence.get("popup_title", "Reality Rewritten")),
		"popup_text": str(existence.get("popup_text", cje.get("summary", "Reality adjusted around your intent."))),
		"popup_footer": "CIE → CJE → RIAS → Runtime truth → Local shell retrofit.",
		"text": str(existence.get("text", cje.get("summary", "Reality adjusted around your intent."))),
		"created_at_year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	_record_inversion(report)
	last_inversion_report = report.duplicate(true)
	return report.duplicate(true)


func _default_contract() -> Dictionary:
	return {
		"schema": CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": "cie.default",
		"runtime_policy": {
			"truth_layer_required": true,
			"preserve_unknown_fields": true,
			"emit_world_feed": true,
			"emit_event_bus": true,
		},
		"identity_anchor": {
			"anchor_id": "player_core_identity",
			"immutable_traits": [
				"birth_origin",
				"timeline_continuity",
				"core_relationships",
				"historical_events"
			],
			"stability_weight": 0.92,
			"retroactive_binding_rules": {
				"merge_strategy": "canonical_truth_precedence"
			}
		},
		"domains": {
			"villains": {
				"actions": ["track_villain", "respond_to_crime", "patrol_city"],
				"existence_model": {
					"pre_existing_weight": 0.65,
					"emergent_weight": 0.35
				},
				"intent_resolution": {
					"generate_if_missing": true,
				},
				"causal_rules": {
				},
				"generation_policy": {
					"allow_generation": true,
					"historical_backfill_depth": 3,
					"conflict_probability": 0.35
				},
				"inversion_policy": {
					"inversion_allowed": true,
					"inversion_strength": 0.62,
					"max_backfill_depth": 3,
					"identity_risk_threshold": 0.25
				},
				"independence_policy": {
					"min_passive_entities": 3,
					"max_emergent_per_cycle": 2
				}
			},
			"sidekicks": {
				"actions": ["recruit_ally", "recruit_sidekick", "start_team"],
				"existence_model": {
					"pre_existing_weight": 0.55,
					"emergent_weight": 0.45
				},
				"intent_resolution": {
					"generate_if_missing": true,
				},
				"generation_policy": {
					"allow_generation": true,
					"historical_backfill_depth": 2,
					"conflict_probability": 0.18
				},
				"inversion_policy": {
					"inversion_allowed": true,
					"inversion_strength": 0.54,
					"max_backfill_depth": 2,
					"identity_risk_threshold": 0.22
				}
			},
			"bending_duels": {
				"actions": ["seek_bending_duel", "find_bending_duel", "bending_duel"],
				"existence_model": {
					"pre_existing_weight": 0.72,
					"emergent_weight": 0.28
				},
				"intent_resolution": {
					"generate_if_missing": true,
				},
				"generation_policy": {
					"allow_generation": true,
					"historical_backfill_depth": 2,
					"conflict_probability": 0.28
				},
				"inversion_policy": {
					"inversion_allowed": true,
					"inversion_strength": 0.42,
					"max_backfill_depth": 2,
					"identity_risk_threshold": 0.18
				}
			},
			"relationships": {
				"actions": ["ask_out", "find_date", "relationship_action"],
				"existence_model": {
					"pre_existing_weight": 0.82,
					"emergent_weight": 0.18
				},
				"intent_resolution": {
					"generate_if_missing": true,
				}
			},
			"career": {
				"actions": ["find_job", "career_action", "apply_job"],
				"existence_model": {
					"pre_existing_weight": 0.78,
					"emergent_weight": 0.22
				},
				"intent_resolution": {
					"generate_if_missing": true,
				}
			}
		}
	}


func _normalize_intent(intent: Dictionary, context: Dictionary = {}) -> Dictionary:
	var out: Dictionary = intent.duplicate(true)

	var action_id: String = str(out.get("action_id", out.get("action", out.get("intent", context.get("action_id", "runtime.intent"))))).strip_edges().to_lower()
	if action_id == "":
		action_id = "runtime.intent"

	var domain_id: String = str(out.get("domain", context.get("domain", ""))).strip_edges().to_lower()
	if domain_id == "":
		domain_id = _domain_for_action(action_id)

	out ["schema"] = str(out.get("schema", "eralife.causality_intent"))
	out ["version"] = max(1, int(out.get("version", 1)))
	out ["intent_id"] = str(out.get("intent_id", "%s_%d" % [action_id.replace(".", "_").replace(" ", "_"), int(Time.get_ticks_msec())]))
	out ["action_id"] = action_id
	out ["intent"] = action_id
	out ["domain"] = domain_id
	out ["source"] = str(out.get("source", context.get("source", "local_shell")))

	if typeof(out.get("constraint_weights", {})) != TYPE_DICTIONARY:
		out ["constraint_weights"] = {}
	if typeof(out.get("generation_policy", {})) != TYPE_DICTIONARY:
		out ["generation_policy"] = {}

	return out


func _domain_for_action(action_id: String) -> String:
	var clean_action: String = str(action_id).strip_edges().to_lower()

	if clean_action.find("villain") >= 0 or clean_action in ["respond_to_crime", "patrol_city"]:
		return "villains"
	if clean_action.find("sidekick") >= 0 or clean_action.find("ally") >= 0 or clean_action.find("team") >= 0:
		return "sidekicks"
	if clean_action.find("bending") >= 0 or clean_action.find("duel") >= 0:
		return "bending_duels"
	if clean_action.find("relationship") >= 0 or clean_action.find("date") >= 0 or clean_action.find("romance") >= 0:
		return "relationships"
	if clean_action.find("job") >= 0 or clean_action.find("career") >= 0:
		return "career"

	return "runtime"


func _domain_contract(domain_id: String) -> Dictionary:
	var domains: Dictionary = _safe_dictionary(active_contract.get("domains", {}))
	var clean_domain: String = str(domain_id).strip_edges().to_lower()
	var row: Dictionary = _safe_dictionary(domains.get(clean_domain, {}))

	if not row.is_empty():
		row ["domain"] = clean_domain
		return row

	return {
		"domain": clean_domain,
		"existence_model": {
			"pre_existing_weight": 0.7,
			"emergent_weight": 0.3
		},
		"intent_resolution": {
			"generate_if_missing": true,
		},
		"generation_policy": {
			"allow_generation": true,
			"historical_backfill_depth": 1,
			"conflict_probability": 0.15
		},
		"inversion_policy": {
			"inversion_allowed": true,
			"inversion_strength": 0.35,
			"max_backfill_depth": 1,
			"identity_risk_threshold": 0.2
		}
	}


func _intent_pressure_packet(actor: Person, intent: Dictionary, domain_contract: Dictionary, context: Dictionary = {}) -> Dictionary:
	var state: Dictionary = _world_state()
	var pressure_field: Dictionary = _safe_dictionary(state.get("intent_pressure_field", {}))

	var action_id: String = str(intent.get("action_id", "runtime.intent"))
	var actor_key: String = _actor_key(actor)
	var pressure_key: String = "%s:%s" % [actor_key, action_id]
	var row: Dictionary = _safe_dictionary(pressure_field.get(pressure_key, {}))

	var previous_pressure: float = float(row.get("pressure", 0.0))
	var domain_model: Dictionary = _safe_dictionary(domain_contract.get("existence_model", {}))
	var emergent_weight: float = float(domain_model.get("emergent_weight", 0.3))
	var pre_existing_weight: float = float(domain_model.get("pre_existing_weight", 0.7))
	var action_push: float = float(context.get("action_pressure", intent.get("pressure", 0.22)))

	var pressure: float = clamp(previous_pressure + action_push + emergent_weight * 0.18, 0.0, 1.0)
	var confidence: float = clamp((pressure * 0.55) + (pre_existing_weight * 0.35) + 0.1, 0.0, 1.0)
	var prepared_entities: int = int(row.get("prepared_entities", 0))

	if pressure >= 0.4:
		prepared_entities = max(prepared_entities, 1)
	if pressure >= 0.68:
		prepared_entities = max(prepared_entities, 2)

	row ["intent_type"] = action_id
	row ["domain"] = str(domain_contract.get("domain", intent.get("domain", "runtime")))
	row ["pressure"] = pressure
	row ["prepared_entities"] = prepared_entities
	row ["confidence"] = confidence
	row ["prewarm_depth"] = clamp(int(row.get("prewarm_depth", 0)) + 1, 0, 4)
	row ["updated_at_year"] = _current_year()
	row ["updated_at_ms"] = int(Time.get_ticks_msec())

	pressure_field [pressure_key] = row
	state ["intent_pressure_field"] = pressure_field
	_commit_world_state(state)

	return row.duplicate(true)


func _crbs_authority_packet(domain_id: String, action_id: String, context: Dictionary = {}) -> Dictionary:
	if gs == null or not gs.has_method("resolve_runtime_boot_domain_gate"):
		return {
			"allowed": true,
			"buffer_intent": false,
			"domain": domain_id,
			"action_id": action_id,
			"reason": "crbs_unavailable_local_authority_assumed"
		}

	var crbs_domain: String = _crbs_domain_for_cie_domain(domain_id)
	var gate: Dictionary = gs.resolve_runtime_boot_domain_gate(crbs_domain, action_id, context)

	gate ["cie_domain"] = domain_id
	gate ["crbs_domain"] = crbs_domain
	gate ["emergence_authority"] = true
	return gate


func _crbs_domain_for_cie_domain(domain_id: String) -> String:
	match str(domain_id).strip_edges().to_lower():
		"villains", "sidekicks":
			return "superhero"
		"bending_duels":
			return "bending"
		"relationships":
			return "world"
		"career":
			return "world"
		_:
			return "runtime"


func _cie_policy_packet(_intent: Dictionary, domain_contract: Dictionary, ips: Dictionary, _crbs: Dictionary) -> Dictionary:
	var inversion_policy: Dictionary = _safe_dictionary(domain_contract.get("inversion_policy", {}))
	var generation_policy: Dictionary = _safe_dictionary(domain_contract.get("generation_policy", {}))
	var resolution_policy: Dictionary = _safe_dictionary(domain_contract.get("intent_resolution", {}))

	var inversion_allowed: bool = bool(inversion_policy.get("inversion_allowed", true))
	var allow_generation: bool = bool(generation_policy.get("allow_generation", true))
	var generate_if_missing: bool = bool(resolution_policy.get("generate_if_missing", true))
	var pressure: float = float(ips.get("pressure", 0.0))
	var strength: float = float(inversion_policy.get("inversion_strength", 0.35))
	var identity_risk: float = clamp((strength * 0.2) + max(0.0, pressure - 0.75) * 0.18, 0.0, 1.0)
	var identity_threshold: float = float(inversion_policy.get("identity_risk_threshold", 0.25))

	var allowed: bool = inversion_allowed and allow_generation and generate_if_missing and identity_risk <= identity_threshold

	return {
		"schema": "eralife.causality_inversion_policy_report",
		"version": CONTRACT_VERSION,
		"inversion_allowed": inversion_allowed,
		"allow_generation": allow_generation,
		"generate_if_missing": generate_if_missing,
		"approved": allowed,
		"inversion_strength": strength,
		"pressure": pressure,
		"max_backfill_depth": int(inversion_policy.get("max_backfill_depth", generation_policy.get("historical_backfill_depth", 1))),
		"identity_risk": identity_risk,
		"identity_risk_threshold": identity_threshold,
		"causal_debt": {
			"total": clamp((strength * 0.38) + (float(inversion_policy.get("max_backfill_depth", 1)) * 0.08), 0.0, 1.0),
			"sources": [
				{
					"type": "retroactive_entity_generation",
					"weight": clamp(strength * 0.3, 0.0, 1.0)
				},
				{
					"type": "historical_backfill",
					"weight": clamp(float(inversion_policy.get("max_backfill_depth", 1)) * 0.08, 0.0, 1.0)
				}
			],
			"repayment_rules": [
				"world_feed_events",
				"npc_dialogue",
				"future_scenarios",
				"investigation_threads"
			]
		}
	}


func _rias_identity_anchor(actor: Person, intent: Dictionary, domain_contract: Dictionary, cie: Dictionary) -> Dictionary:
	var anchor: Dictionary = _safe_dictionary(active_contract.get("identity_anchor", {}))
	var immutable_traits: Array = _safe_array(anchor.get("immutable_traits", []))
	var conflicts: Array = []

	if actor == null:
		conflicts.append("actor_missing")
	if float(cie.get("identity_risk", 0.0)) > float(cie.get("identity_risk_threshold", 0.25)):
		conflicts.append("identity_risk_threshold_exceeded")

	return {
		"schema": "eralife.reality_identity_anchor_report",
		"version": CONTRACT_VERSION,
		"anchor_id": str(anchor.get("anchor_id", "player_core_identity")),
		"actor_id": int(actor.id) if actor != null else -1,
		"actor_name": _person_label(actor),
		"immutable_traits": immutable_traits,
		"stability_weight": float(anchor.get("stability_weight", 0.92)),
		"identity_conflicts": conflicts,
		"identity_safe": conflicts.is_empty(),
		"retroactive_binding_rules": _safe_dictionary(anchor.get("retroactive_binding_rules", {})),
		"domain": str(domain_contract.get("domain", intent.get("domain", "runtime")))
	}


func _causal_justification(actor: Person, intent: Dictionary, domain_contract: Dictionary, ips: Dictionary, cie: Dictionary) -> Dictionary:
	var action_id: String = str(intent.get("action_id", "runtime.intent"))
	var domain_id: String = str(domain_contract.get("domain", intent.get("domain", "runtime")))
	var actor_name: String = _person_label(actor)
	var pressure: float = float(ips.get("pressure", 0.0))
	var depth: int = int(cie.get("max_backfill_depth", 1))

	var why_now: String = "Pressure around this intent crossed %.0f%%, so the runtime surfaced a thread that was already forming." % [pressure * 100.0]
	var why_here: String = "The active reality shell had enough local context to bind this event into the current world."
	var why_you: String = "%s created the strongest relevance signal for this timeline branch." % actor_name
	var before: Array = [
		"Minor signals accumulated before the player saw the pattern.",
		"Background systems preserved enough ambiguity to support a believable reveal."
	]

	match domain_id:
		"villains":
			why_now = "Several unresolved incidents hardened into a recognizable villain pattern over the last %d cycle%s." % [max(1, depth), "" if depth == 1 else "s"]
			why_here = "This district has enough instability, witness noise, and powered attention to justify escalation."
			why_you = "%s's recent hero pressure made the hidden pattern worth surfacing now." % actor_name
			before = [
				"A failed operation created internal conflict.",
				"A stronger figure took control of the pattern quietly.",
				"Witness rumors started pointing toward the same masked presence."
			]
		"sidekicks":
			why_now = "Your public activity made a compatible powered ally step closer to the surface."
			why_here = "The local hero ecosystem now has enough trust pressure to justify a recruit."
			why_you = "%s has become visible enough for someone to believe joining you matters." % actor_name
			before = [
				"They studied your actions from a distance.",
				"They hesitated because your team did not feel stable yet.",
				"They were already looking for a cause that matched their abilities."
			]
		"bending_duels":
			why_now = "Your bending reputation created enough duel pressure for a compatible opponent to step forward."
			why_here = "Your nation and dojo tier can support a believable challenger."
			why_you = "%s's element, skill tier, and public trajectory made this duel plausible." % actor_name
			before = [
				"The opponent had been watching recent matches.",
				"Dojo gossip framed you as a useful test.",
				"A previous sparring chain made the challenge feel inevitable."
			]

	return {
		"schema": "eralife.causal_justification_report",
		"version": CONTRACT_VERSION,
		"why_now": why_now,
		"why_here": why_here,
		"why_you": why_you,
		"what_was_happening_before": before,
		"summary": "%s\n\n%s\n\n%s" % [why_now, why_here, why_you],
		"specificity_score": 0.82,
		"domain": domain_id,
		"action_id": action_id
	}


func _resolve_existence(actor: Person, intent: Dictionary, domain_contract: Dictionary, ips: Dictionary, cie: Dictionary, rias: Dictionary, cje: Dictionary, context: Dictionary = {}) -> Dictionary:
	if not bool(rias.get("identity_safe", false)):
		return {
			"success": false,
			"reason": "RIAS blocked causality inversion.",
			"popup_title": "Identity Anchor Refused",
			"popup_text": "Reality could not rewrite around this intent without risking identity continuity."
		}

	if not bool(cie.get("approved", false)):
		return {
			"success": false,
			"reason": "CIE policy blocked inversion.",
			"popup_title": "Causality Refused",
			"popup_text": "The intent created pressure, but not enough safe authority to rewrite reality."
		}

	var domain_id: String = str(domain_contract.get("domain", intent.get("domain", "runtime")))
	match domain_id:
		"villains":
			return _resolve_villain_existence(actor, intent, domain_contract, ips, cie, cje, context)
		"sidekicks":
			return _resolve_sidekick_existence(actor, intent, domain_contract, ips, cie, cje, context)
		"bending_duels":
			return _resolve_bending_duel_existence(actor, intent, domain_contract, ips, cie, cje, context)
		_:
			return {
				"success": true,
				"entity": {},
				"entities": [],
				"scenario_seed": {},
				"popup_title": "Reality Adjusted",
				"popup_text": str(cje.get("summary", "Reality adjusted around your intent.")),
				"text": str(cje.get("summary", "Reality adjusted around your intent."))
			}


func _resolve_villain_existence(actor: Person, intent: Dictionary, _resolved_domain_contract: Dictionary, _ips: Dictionary, _cie: Dictionary, cje: Dictionary, _context: Dictionary = {}) -> Dictionary:
	var villain: Person = null
	if gs != null and gs.superhero_engine != null and gs.superhero_engine.has_method("_resolve_or_create_villain"):
		villain = gs.superhero_engine.call("_resolve_or_create_villain", {
			"source": "causality_inversion_engine",
			"resolution_strategy": str(intent.get("resolution_strategy", "generate_if_missing")),
			"causal_justification": cje.duplicate(true),
			"_cie_materialization": true
		})

	if villain == null:
		return {
			"success": false,
			"reason": "No villain could be materialized."
		}

	var entity: Dictionary = {
		"schema": "eralife.canonical_villain_entity",
		"version": CONTRACT_VERSION,
		"person_id": int(villain.id),
		"name": _person_label(villain),
		"entity_type": "villain",
		"source": "cie",
		"causal_justification": cje.duplicate(true)
	}

	return {
		"success": true,
		"entity": entity,
		"entities": [entity],
		"scenario_seed": {
			"schema": "eralife.cie_scenario_seed",
			"version": CONTRACT_VERSION,
			"scenario_type": "superhero_villain_encounter",
			"actor_id": int(actor.id),
			"target_id": int(villain.id),
			"villain_id": int(villain.id),
			"battle_type": "villain_tracking",
			"causal_justification": cje.duplicate(true)
		},
		"popup_title": "Villain Trail Stabilized",
		"popup_text": "%s was not merely found. Reality now has a reason they were always moving in your orbit.\n\n%s" % [
			_person_label(villain),
			str(cje.get("summary", ""))
		],
		"text": "You track %s through a pattern reality just finished making true." % _person_label(villain)
	}
func _resolve_sidekick_existence(actor: Person, _intent: Dictionary, _resolved_domain_contract: Dictionary, _ips: Dictionary, _cie: Dictionary, cje: Dictionary, _context: Dictionary = {}) -> Dictionary:
	var ally: Person = null
	if gs != null and gs.superhero_engine != null:
		if gs.superhero_engine.has_method("_resolve_or_create_sidekick_recruit"):
			ally = gs.superhero_engine.call("_resolve_or_create_sidekick_recruit", actor, {
				"source": "causality_inversion_engine",
				"causal_justification": cje.duplicate(true),
				"_cie_materialization": true
			})
		elif gs.superhero_engine.has_method("_find_powered_recruit"):
			ally = gs.superhero_engine.call("_find_powered_recruit", actor)

	if ally == null:
		return {
			"success": false,
			"reason": "No sidekick candidate could be materialized."
		}

	var entity: Dictionary = {
		"schema": "eralife.canonical_sidekick_entity",
		"version": CONTRACT_VERSION,
		"person_id": int(ally.id),
		"name": _person_label(ally),
		"entity_type": "sidekick",
		"source": "cie",
		"causal_justification": cje.duplicate(true)
	}

	return {
		"success": true,
		"entity": entity,
		"entities": [entity],
		"scenario_seed": {
			"schema": "eralife.cie_scenario_seed",
			"version": CONTRACT_VERSION,
			"scenario_type": "sidekick_recruitment",
			"actor_id": int(actor.id),
			"target_id": int(ally.id),
			"ally_id": int(ally.id),
			"causal_justification": cje.duplicate(true)
		},
		"popup_title": "Sidekick Candidate Surfaced",
		"popup_text": "%s has been watching your work longer than you realized.\n\n%s" % [
			_person_label(ally),
			str(cje.get("summary", ""))
		],
		"text": "%s steps into your story as a possible sidekick." % _person_label(ally)
	}


func _resolve_bending_duel_existence(actor: Person, intent: Dictionary, _resolved_domain_contract: Dictionary, _ips: Dictionary, _cie: Dictionary, cje: Dictionary, _context: Dictionary = {}) -> Dictionary:
	var target: Person = null

	if intent.has("target_id") and gs != null and gs.has_method("get_or_reactivate_npc_by_id"):
		target = gs.get_or_reactivate_npc_by_id(int(intent.get("target_id", -1)))

	if target == null and gs != null and gs.bending_engine != null and gs.bending_engine.has_method("get_bending_targets_for_player"):
		var targets: Array = gs.bending_engine.get_bending_targets_for_player(actor, "__duel__", false)
		if not targets.is_empty():
			var row: Dictionary = _safe_dictionary(targets [0])
			if gs.has_method("get_or_reactivate_npc_by_id"):
				target = gs.get_or_reactivate_npc_by_id(int(row.get("id", -1)))

	if target == null and gs != null and gs.npc_factory != null and gs.npc_factory.has_method("create_random_npc"):
		target = gs.npc_factory.create_random_npc(true)
		if target != null:
			if gs.has_method("apply_reality_rules_to_person"):
				gs.apply_reality_rules_to_person(target)
			if typeof(gs.npcs) == TYPE_ARRAY:
				gs.npcs.append(target)
			if gs.has_method("_rebuild_npc_index"):
				gs._rebuild_npc_index()

	var entity: Dictionary = {}
	if target != null:
		entity = {
			"schema": "eralife.canonical_bending_duel_opponent",
			"version": CONTRACT_VERSION,
			"person_id": int(target.id),
			"name": _person_label(target),
			"entity_type": "bending_duel_opponent",
			"source": "cie",
			"causal_justification": cje.duplicate(true)
		}

	return {
		"success": target != null,
		"entity": entity,
		"entities": [entity] if not entity.is_empty() else [],
		"scenario_seed": {
			"schema": "eralife.cie_scenario_seed",
			"version": CONTRACT_VERSION,
			"scenario_type": "bending_duel",
			"actor_id": int(actor.id),
			"target_id": int(target.id) if target != null else -1,
			"causal_justification": cje.duplicate(true)
		},
		"popup_title": "Duel Pressure Stabilized",
		"popup_text": "%s becomes the answer to your duel pressure.\n\n%s" % [
			_person_label(target),
			str(cje.get("summary", ""))
		] if target != null else "No duel opponent could be stabilized.",
		"text": "A bending duel opponent surfaced through causality pressure." if target != null else "No duel opponent could be stabilized."
	}

func _compose_retrofit_packet(actor: Person, intent: Dictionary, existence: Dictionary, cje: Dictionary, rias: Dictionary, context: Dictionary = {}) -> Dictionary:
	return {
		"schema": "eralife.local_shell_retrofit_packet",
		"version": CONTRACT_VERSION,
		"actor_id": int(actor.id) if actor != null else -1,
		"intent": intent.duplicate(true),
		"existence": existence.duplicate(true),
		"causal_justification": cje.duplicate(true),
		"identity_anchor": rias.duplicate(true),
		"retrofit_steps": [
			"bind_entity_into_timeline",
			"inject_world_feed_echo",
			"update_domain_registry",
			"refresh_ui_surface",
			"queue_scenario_if_available"
		],
		"context": context.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec())
	}


func _local_shell_text_for_intent(intent: Dictionary) -> String:
	match str(intent.get("action_id", "")).strip_edges().to_lower():
		"track_villain":
			return "Scanning city activity..."
		"respond_to_crime":
			return "Listening for emergency signals..."
		"recruit_ally", "recruit_sidekick":
			return "Scanning compatible powered allies..."
		"start_team":
			return "Testing team formation pressure..."
		"seek_bending_duel", "find_bending_duel", "bending_duel":
			return "Reading duel pressure..."
		_:
			return "Reality is assembling around your intent..."


func _record_inversion(report: Dictionary) -> void:
	var state: Dictionary = _world_state()
	var ledger: Array = _safe_array(state.get("inversion_ledger", []))
	ledger.append(report.duplicate(true))
	while ledger.size() > MAX_INVERSION_LEDGER:
		ledger.pop_front()

	state ["inversion_ledger"] = ledger
	state ["last_inversion_report"] = report.duplicate(true)
	_commit_world_state(state)

	if gs != null and "event_bus" in gs and gs.event_bus != null:
		gs.event_bus.emit("causality.inversion.resolved", report)


func _actor_key(actor: Person) -> String:
	if actor == null:
		return "actor:none"
	return "actor:%d" % int(actor.id)


func _person_label(person: Person) -> String:
	if person == null:
		return "Unknown"
	var full_name: String = ("%s %s" % [str(person.first_name), str(person.last_name)]).strip_edges()
	if full_name == "":
		full_name = str(person.name).strip_edges() if "name" in person else "Unknown"
	return full_name


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
	if typeof(out.get("inversion_ledger", [])) != TYPE_ARRAY:
		out ["inversion_ledger"] = []
	if typeof(out.get("intent_pressure_field", {})) != TYPE_DICTIONARY:
		out ["intent_pressure_field"] = {}
	if typeof(out.get("last_inversion_report", {})) != TYPE_DICTIONARY:
		out ["last_inversion_report"] = {}
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