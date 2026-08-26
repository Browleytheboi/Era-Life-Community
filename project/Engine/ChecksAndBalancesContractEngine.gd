extends Resource
class_name ChecksAndBalancesContractEngine

const ENGINE_SCHEMA:= "eralife.checks_and_balances_contract_engine"
const AUTHORITY_ACTION_SCHEMA:= "eralife.government_authority_action_contract"
const CONSTITUTIONAL_CONTRACT_SCHEMA:= "eralife.constitutional_authority_graph_contract"
const REVIEW_CONTRACT_SCHEMA:= "eralife.government_authority_review_contract"
const CONTRACT_VERSION:= 1
const MAX_AUTHORITY_AUDIT_ROWS:= 160

var gs = null
var constitutional_contracts_by_realm_key: Dictionary = {}
var pending_authority_reviews: Dictionary = {}
var last_authority_report: Dictionary = {}


func _init(_gs = null) -> void:
	gs = _gs
	_ensure_state()


func bind_game_state(_gs) -> void:
	gs = _gs
	_ensure_state()


func resolve_authority_for_intent(envelope: Dictionary, context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	if gs == null:
		return _failure("missing_game_state", {
			"intent": envelope.duplicate(true)
		})

	if typeof(envelope) != TYPE_DICTIONARY:
		return _failure("invalid_intent_type", {
			"received_type": typeof(envelope)
		})

	if not _intent_requires_authority_resolution(envelope, context):
		return {
			"success": true,
			"schema": ENGINE_SCHEMA,
			"version": CONTRACT_VERSION,
			"mode": "authority_not_required",
			"commit_allowed": true,
			"authority_checked": false,
			"ui_is_renderer_only": true
		}

	var action_contract: Dictionary = _build_authority_action_contract(envelope, context)
	if action_contract.is_empty():
		return _failure("authority_action_contract_empty", {
			"intent_id": str(envelope.get("intent_id", "")),
			"ui_is_renderer_only": true
		})

	return resolve_authority_action_contract(action_contract, {
		"source": "global_intent_contract_engine",
		"intent": envelope.duplicate(true),
		"ui_is_renderer_only": true
	}.merged(context, true))


func resolve_authority_action_contract(action_contract: Dictionary, context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	if gs == null:
		return _failure("missing_game_state", context)

	if typeof(action_contract) != TYPE_DICTIONARY:
		return _failure("invalid_authority_action_contract", context)

	var realm_id: int = int(action_contract.get("realm_id", -1))
	var realm_name: String = str(action_contract.get("realm_name", "")).strip_edges()
	if realm_id <= 0:
		return _failure("invalid_realm_id", {
			"action_contract": action_contract.duplicate(true)
		})

	if realm_name == "":
		realm_name = _realm_name_for_id(realm_id)

	var constitutional_contract: Dictionary = constitutional_contract_for_realm(realm_id, realm_name, context)
	if constitutional_contract.is_empty():
		return _failure("missing_constitutional_contract", {
			"realm_id": realm_id,
			"realm_name": realm_name
		})

	var actor_branch: String = str(action_contract.get("authority", action_contract.get("branch", ""))).strip_edges().to_lower()
	var action_id: String = str(action_contract.get("action_id", action_contract.get("intent_type", ""))).strip_edges().to_lower()
	var action_rule: Dictionary = _action_rule_for_contract(action_id, action_contract, constitutional_contract)

	if action_rule.is_empty():
		var no_rule_report: Dictionary = _authority_allowed_report(
			action_contract,
			constitutional_contract,
			{
				"reason": "no_specific_rule_default_allow",
				"authority_resolution_mode": "default_allow_for_unknown_action"
			}
		)
		_commit_authority_report(no_rule_report)
		_emit_authority_event("government.authority.cleared", no_rule_report)
		return no_rule_report

	var required_branch: String = str(action_rule.get("branch", action_rule.get("authority", ""))).strip_edges().to_lower()
	if required_branch != "" and actor_branch != "" and actor_branch != required_branch:
		var disputed_report: Dictionary = _authority_disputed_report(
			action_contract,
			constitutional_contract,
			{
				"reason": "actor_branch_does_not_match_required_authority",
				"actor_branch": actor_branch,
				"required_branch": required_branch,
				"action_rule": action_rule.duplicate(true)
			}
		)
		_commit_authority_report(disputed_report)
		_emit_authority_event("government.authority.disputed", disputed_report)
		return disputed_report

	var pre_commit_reviews: Array = _safe_array(action_rule.get("pre_commit_reviews", []))
	var post_commit_reviews: Array = _safe_array(action_rule.get("post_commit_reviews", []))
	var can_commit_before_review: bool = bool(action_rule.get("can_commit_before_review", pre_commit_reviews.is_empty()))

	if not pre_commit_reviews.is_empty() and not can_commit_before_review:
		var pending_report: Dictionary = _create_review_contracts_for_action(
			action_contract,
			constitutional_contract,
			pre_commit_reviews,
			"pre_commit",
			{
				"commit_allowed": false,
				"authority_review_pending": true,
				"reason": "pre_commit_authority_review_required"
			}
		)
		_commit_authority_report(pending_report)
		_emit_authority_event("government.authority.review_requested", pending_report)
		return pending_report

	var allowed_report: Dictionary = _authority_allowed_report(
		action_contract,
		constitutional_contract,
		{
			"reason": "authority_contract_allowed_commit",
			"action_rule": action_rule.duplicate(true)
		}
	)

	if not post_commit_reviews.is_empty():
		var post_review_report: Dictionary = _create_review_contracts_for_action(
			action_contract,
			constitutional_contract,
			post_commit_reviews,
			"post_commit",
			{
				"commit_allowed": true,
				"authority_review_pending": true,
				"reason": "post_commit_authority_review_created"
			}
		)
		allowed_report ["post_commit_review_report"] = post_review_report.duplicate(true)
		allowed_report ["post_commit_review_pending"] = true
		_emit_authority_event("government.authority.review_requested", post_review_report)

	_commit_authority_report(allowed_report)
	_emit_authority_event("government.authority.cleared", allowed_report)

	return allowed_report


func constitutional_contract_for_realm(realm_id: int, realm_name: String = "", context: Dictionary = {}) -> Dictionary:
	if realm_id <= 0:
		return {}

	var clean_name: String = str(realm_name).strip_edges()
	if clean_name == "":
		clean_name = _realm_name_for_id(realm_id)

	var key: String = _realm_key(realm_id, clean_name)
	if constitutional_contracts_by_realm_key.has(key):
		var existing: Dictionary = constitutional_contracts_by_realm_key.get(key, {})
		if typeof(existing) == TYPE_DICTIONARY and not existing.is_empty():
			return existing.duplicate(true)

	var generated: Dictionary = _default_constitutional_contract_for_realm(realm_id, clean_name, context)
	if not generated.is_empty():
		constitutional_contracts_by_realm_key [key] = generated.duplicate(true)
		_commit_state()

	return generated.duplicate(true)


func publish_constitutional_contract(realm_id: int, contract: Dictionary, context: Dictionary = {}) -> Dictionary:
	if realm_id <= 0:
		return _failure("invalid_realm_id", context)

	if typeof(contract) != TYPE_DICTIONARY or contract.is_empty():
		return _failure("invalid_constitutional_contract", context)

	var realm_name: String = str(contract.get("realm_name", _realm_name_for_id(realm_id))).strip_edges()
	if realm_name == "":
		realm_name = "Realm %d" % realm_id

	var normalized: Dictionary = contract.duplicate(true)
	normalized ["schema"] = CONSTITUTIONAL_CONTRACT_SCHEMA
	normalized ["version"] = int(normalized.get("version", CONTRACT_VERSION))
	normalized ["realm_id"] = realm_id
	normalized ["realm_name"] = realm_name
	normalized ["moddable_authority_graph"] = true
	normalized ["checks_and_balances_engine_does_not_govern"] = true
	normalized ["ui_is_renderer_only"] = true

	var key: String = _realm_key(realm_id, realm_name)
	constitutional_contracts_by_realm_key [key] = normalized.duplicate(true)
	_commit_state()

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": CONTRACT_VERSION,
		"reason": "constitutional_contract_published",
		"realm_id": realm_id,
		"realm_name": realm_name,
		"contract_key": key,
		"ui_is_renderer_only": true
	}


func on_authority_review_outcome(payload: Dictionary = {}) -> void:
	if typeof(payload) != TYPE_DICTIONARY:
		return

	_ensure_state()

	var data_raw: Variant = payload.get("data", payload)
	var data: Dictionary = data_raw if typeof(data_raw) == TYPE_DICTIONARY else payload

	var review_id: String = str(data.get("review_id", data.get("authority_review_id", ""))).strip_edges()
	if review_id == "":
		return

	if not pending_authority_reviews.has(review_id):
		return

	var review: Dictionary = pending_authority_reviews.get(review_id, {})
	if typeof(review) != TYPE_DICTIONARY:
		return

	review ["status"] = str(data.get("status", data.get("outcome", "resolved"))).strip_edges()
	review ["outcome"] = str(data.get("outcome", review.get("status", "resolved"))).strip_edges()
	review ["resolved_at_ms"] = int(Time.get_ticks_msec())
	review ["resolver_payload"] = data.duplicate(true)
	review ["ui_is_renderer_only"] = true

	pending_authority_reviews [review_id] = review
	_commit_state()

	_emit_authority_event("government.authority.review_recorded", {
		"schema": ENGINE_SCHEMA,
		"version": CONTRACT_VERSION,
		"review_id": review_id,
		"review": review.duplicate(true),
		"ui_is_renderer_only": true
	})


func export_state() -> Dictionary:
	_ensure_state()
	return {
		"schema": "%s.state" % ENGINE_SCHEMA,
		"version": CONTRACT_VERSION,
		"constitutional_contracts_by_realm_key": constitutional_contracts_by_realm_key.duplicate(true),
		"pending_authority_reviews": pending_authority_reviews.duplicate(true),
		"last_authority_report": last_authority_report.duplicate(true),
		"ui_is_renderer_only": true
	}


func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "invalid_state",
			"schema": ENGINE_SCHEMA
		}

	constitutional_contracts_by_realm_key = _safe_dictionary(data.get("constitutional_contracts_by_realm_key", constitutional_contracts_by_realm_key))
	pending_authority_reviews = _safe_dictionary(data.get("pending_authority_reviews", pending_authority_reviews))
	last_authority_report = _safe_dictionary(data.get("last_authority_report", last_authority_report))

	_commit_state()

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"reason": "checks_and_balances_state_imported",
		"ui_is_renderer_only": true
	}


func _build_authority_action_contract(envelope: Dictionary, context: Dictionary = {}) -> Dictionary:
	var payload: Dictionary = _safe_dictionary(envelope.get("payload", {}))
	var target: Dictionary = _safe_dictionary(envelope.get("target", {}))
	var actor_id: int = int(envelope.get("actor_id", payload.get("actor_id", context.get("actor_id", -1))))
	var actor = _actor_by_id(actor_id)

	var realm_id: int = int(payload.get("realm_id", target.get("realm_id", context.get("realm_id", _realm_id_for_actor(actor)))))
	var realm_name: String = str(payload.get("realm_name", target.get("realm_name", context.get("realm_name", _realm_name_for_id(realm_id))))).strip_edges()

	var action_id: String = str(envelope.get("action_id", payload.get("action_id", envelope.get("intent_type", "")))).strip_edges()
	var intent_type: String = str(envelope.get("intent_type", action_id)).strip_edges()
	var authority: String = _authority_branch_for_actor_and_intent(actor, envelope, payload, realm_id, realm_name)

	return {
		"schema": AUTHORITY_ACTION_SCHEMA,
		"version": CONTRACT_VERSION,
		"intent_id": str(envelope.get("intent_id", "")),
		"actor_id": actor_id,
		"actor_name": _person_display_name(actor),
		"realm_id": realm_id,
		"realm_name": realm_name,
		"action_id": action_id,
		"intent_type": intent_type,
		"authority": authority,
		"branch": authority,
		"legal_basis": str(payload.get("legal_basis", payload.get("constitutional_basis", ""))).strip_edges(),
		"target": target.duplicate(true),
		"payload": payload.duplicate(true),
		"source": str(envelope.get("source", context.get("source", "global_intent_contract_engine"))),
		"ui_is_renderer_only": true
	}


func _intent_requires_authority_resolution(envelope: Dictionary, _context: Dictionary = {}) -> bool:
	var payload: Dictionary = _safe_dictionary(envelope.get("payload", {}))
	var target: Dictionary = _safe_dictionary(envelope.get("target", {}))
	var domain: String = str(envelope.get("domain", payload.get("domain", ""))).strip_edges().to_lower()
	var action_id: String = str(envelope.get("action_id", payload.get("action_id", envelope.get("intent_type", "")))).strip_edges().to_lower()
	var intent_type: String = str(envelope.get("intent_type", "")).strip_edges().to_lower()

	if _is_read_only_surface_action(action_id) or _is_read_only_surface_action(intent_type):
		return false

	if bool(payload.get("authority_contract_required", false)):
		return true
	if bool(payload.get("government_action", false)):
		return true
	if bool(payload.get("constitutional_authority", false)):
		return true
	if str(payload.get("legal_basis", "")).strip_edges() != "":
		return true
	if str(payload.get("constitutional_basis", "")).strip_edges() != "":
		return true

	if domain in [
		"government",
		"politics",
		"law",
		"legislation",
		"realm_governance",
		"federal_government",
		"monarchy",
		"authority",
		"organization_authority"
	]:
		return true

	if str(target.get("authority_contract_required", "")).strip_edges() == "true":
		return true

	return action_id in [
		"executive_order",
		"sign_executive_order",
		"royal_decree",
		"pass_law",
		"sign_bill",
		"veto_bill",
		"override_veto",
		"appoint_official",
		"approve_appointment",
		"dismiss_cabinet",
		"declare_war",
		"approve_budget",
		"reject_treaty",
		"ratify_treaty",
		"impeach",
		"judicial_review",
		"ignore_court_ruling",
		"emergency_power"
	]


func _is_read_only_surface_action(action_id: String) -> bool:
	var key: String = str(action_id).strip_edges().to_lower()
	if key == "":
		return false

	return key.begins_with("open_") \
or key.begins_with("view_") \
or key.begins_with("browse_") \
or key.begins_with("show_") \
or key.find("population") >= 0 \
or key.find("panel") >= 0 \
or key.find("lens") >= 0


func _default_constitutional_contract_for_realm(realm_id: int, realm_name: String, context: Dictionary = {}) -> Dictionary:
	var realm: Dictionary = _realm_dictionary(realm_id)
	var government_model: String = str(realm.get("government_model", realm.get("government_type", realm.get("government_style", context.get("government_model", ""))))).strip_edges().to_lower()
	var government_style: String = str(realm.get("government_style", government_model)).strip_edges().to_lower()

	if government_model.find("federal_presidential_republic") >= 0 or government_model.find("presidential") >= 0:
		return _federal_presidential_republic_contract(realm_id, realm_name, realm)

	if government_model.find("parliament") >= 0 or government_style.find("parliament") >= 0:
		return _parliamentary_contract(realm_id, realm_name, realm)

	if government_model.find("constitutional_monarchy") >= 0 or government_style.find("constitutional monarchy") >= 0:
		return _constitutional_monarchy_contract(realm_id, realm_name, realm)

	if government_model.find("absolute_monarchy") >= 0 or government_style.find("absolute monarchy") >= 0:
		return _absolute_monarchy_contract(realm_id, realm_name, realm)

	if government_model.find("dictatorship") >= 0 or government_model.find("military") >= 0:
		return _authoritarian_contract(realm_id, realm_name, realm)

	if government_model.find("tribal") >= 0 or government_model.find("council") >= 0:
		return _council_contract(realm_id, realm_name, realm)

	if str(realm_name).strip_edges().to_lower().find("fire nation") >= 0:
		return _absolute_monarchy_contract(realm_id, realm_name, realm)

	return _generic_realm_authority_contract(realm_id, realm_name, realm)


func _federal_presidential_republic_contract(realm_id: int, realm_name: String, realm: Dictionary) -> Dictionary:
	return _base_constitutional_contract(realm_id, realm_name, realm, {
		"government_model": "federal_presidential_republic",
		"branches": {
			"executive": {
				"can_execute": true,
				"can_be_reviewed_by": ["judicial", "legislative"]
			},
			"legislative": {
				"vote_required_default": "simple_majority",
				"supermajority": "two_thirds"
			},
			"judicial": {
				"can_stay": true,
				"can_block": true,
				"review_type": "constitutional_review"
			},
			"state_governor": {
				"responses": ["support", "oppose", "delay", "challenge", "refuse"]
			}
		},
		"authority_actions": {
			"executive_order": {
				"branch": "executive",
				"can_commit_before_review": true,
				"post_commit_reviews": [
					{ "authority": "judicial", "review_type": "constitutional_review", "outcomes": ["upheld", "blocked", "partially_blocked", "stayed", "returned", "delayed"]}
				]
			},
			"sign_executive_order": {
				"branch": "executive",
				"can_commit_before_review": true,
				"alias_for": "executive_order",
				"post_commit_reviews": [
					{ "authority": "judicial", "review_type": "constitutional_review", "outcomes": ["upheld", "blocked", "partially_blocked", "stayed", "returned", "delayed"]}
				]
			},
			"appoint_official": {
				"branch": "executive",
				"can_commit_before_review": false,
				"pre_commit_reviews": [
					{ "authority": "legislative", "review_type": "confirmation", "vote_required": "simple_majority", "outcomes": ["approved", "rejected", "delayed", "returned"]}
				]
			},
			"dismiss_cabinet": {
				"branch": "executive",
				"can_commit_before_review": true,
				"post_commit_reviews": []
			},
			"veto_bill": {
				"branch": "executive",
				"can_commit_before_review": true,
				"post_commit_reviews": [
					{ "authority": "legislative", "review_type": "override_veto", "vote_required": "two_thirds", "outcomes": ["override_successful", "override_failed", "delayed"]}
				]
			},
			"declare_war": {
				"branch": "executive",
				"can_commit_before_review": false,
				"pre_commit_reviews": [
					{ "authority": "legislative", "review_type": "war_authorization", "vote_required": "simple_majority", "outcomes": ["authorized", "rejected", "delayed"]}
				]
			},
			"sign_bill": {
				"branch": "executive",
				"can_commit_before_review": true,
				"post_commit_reviews": [
					{ "authority": "judicial", "review_type": "constitutional_review", "outcomes": ["upheld", "blocked", "partially_blocked", "stayed"]}
				]
			},
			"pass_law": {
				"branch": "legislative",
				"can_commit_before_review": false,
				"pre_commit_reviews": [
					{ "authority": "executive", "review_type": "signature_or_veto", "outcomes": ["signed", "vetoed", "pocket_veto", "delayed"]}
				],
				"post_commit_reviews": [
					{ "authority": "judicial", "review_type": "constitutional_review", "outcomes": ["upheld", "blocked", "partially_blocked", "stayed"]}
				]
			},
			"ignore_court_ruling": {
				"branch": "executive",
				"can_commit_before_review": false,
				"pre_commit_reviews": [
					{ "authority": "legislative", "review_type": "constitutional_crisis", "outcomes": ["impeachment", "censure", "military_refusal", "governor_resistance", "public_unrest"]}
				]
			}
		}
	})


func _parliamentary_contract(realm_id: int, realm_name: String, realm: Dictionary) -> Dictionary:
	return _base_constitutional_contract(realm_id, realm_name, realm, {
		"government_model": "parliamentary_government",
		"branches": {
			"executive": { "can_execute": true, "accountable_to": "legislative"},
			"legislative": { "can_initiate": true, "can_review": true, "confidence_power": true},
			"judicial": { "can_review": true, "review_type": "legal_review"}
		},
		"authority_actions": {
			"executive_order": {
				"branch": "executive",
				"can_commit_before_review": true,
				"post_commit_reviews": [
					{ "authority": "legislative", "review_type": "parliamentary_scrutiny", "outcomes": ["accepted", "reversed", "no_confidence", "delayed"]},
					{ "authority": "judicial", "review_type": "legal_review", "outcomes": ["upheld", "blocked", "stayed"]}
				]
			},
			"pass_law": {
				"branch": "legislative",
				"can_commit_before_review": true,
				"post_commit_reviews": [
					{ "authority": "judicial", "review_type": "legal_review", "outcomes": ["upheld", "blocked", "stayed"]}
				]
			}
		}
	})


func _constitutional_monarchy_contract(realm_id: int, realm_name: String, realm: Dictionary) -> Dictionary:
	return _base_constitutional_contract(realm_id, realm_name, realm, {
		"government_model": "constitutional_monarchy",
		"branches": {
			"monarch": { "symbolic_authority": true, "can_be_limited_by": ["legislative", "judicial"]},
			"executive": { "can_execute": true, "accountable_to": "legislative"},
			"legislative": { "can_review": true},
			"judicial": { "can_review": true}
		},
		"authority_actions": {
			"royal_decree": {
				"branch": "monarch",
				"can_commit_before_review": false,
				"pre_commit_reviews": [
					{ "authority": "legislative", "review_type": "constitutional_monarchy_review", "outcomes": ["approved", "blocked", "returned", "delayed"]}
				]
			}
		}
	})


func _absolute_monarchy_contract(realm_id: int, realm_name: String, realm: Dictionary) -> Dictionary:
	return _base_constitutional_contract(realm_id, realm_name, realm, {
		"government_model": "absolute_monarchy",
		"branches": {
			"monarch": { "can_execute": true, "can_decree": true},
			"council": { "can_advise": true, "can_pressure": true},
			"nobility": { "can_pressure": true, "can_rebel": true}
		},
		"authority_actions": {
			"royal_decree": {
				"branch": "monarch",
				"can_commit_before_review": true,
				"post_commit_reviews": [
					{ "authority": "council", "review_type": "advisory_pressure", "outcomes": ["supported", "opposed", "ignored", "rebellion_pressure"]}
				]
			},
			"dismiss_cabinet": {
				"branch": "monarch",
				"can_commit_before_review": true,
				"post_commit_reviews": []
			}
		}
	})


func _authoritarian_contract(realm_id: int, realm_name: String, realm: Dictionary) -> Dictionary:
	return _base_constitutional_contract(realm_id, realm_name, realm, {
		"government_model": "authoritarian_state",
		"branches": {
			"executive": { "can_execute": true, "emergency_power": true},
			"military": { "can_enforce": true, "can_refuse": true},
			"judicial": { "can_review": false}
		},
		"authority_actions": {
			"emergency_power": {
				"branch": "executive",
				"can_commit_before_review": true,
				"post_commit_reviews": [
					{ "authority": "military", "review_type": "enforcement_alignment", "outcomes": ["enforced", "refused", "coup_risk", "delayed"]}
				]
			}
		}
	})


func _council_contract(realm_id: int, realm_name: String, realm: Dictionary) -> Dictionary:
	return _base_constitutional_contract(realm_id, realm_name, realm, {
		"government_model": "council_government",
		"branches": {
			"council": { "can_initiate": true, "can_review": true},
			"chief": { "can_execute": true, "accountable_to": "council"}
		},
		"authority_actions": {
			"decree": {
				"branch": "chief",
				"can_commit_before_review": false,
				"pre_commit_reviews": [
					{ "authority": "council", "review_type": "council_approval", "outcomes": ["approved", "blocked", "amended", "delayed"]}
				]
			}
		}
	})


func _generic_realm_authority_contract(realm_id: int, realm_name: String, realm: Dictionary) -> Dictionary:
	return _base_constitutional_contract(realm_id, realm_name, realm, {
		"government_model": "generic_realm_government",
		"branches": {
			"executive": { "can_execute": true},
			"council": { "can_review": true},
			"judicial": { "can_review": true}
		},
		"authority_actions": {
			"executive_order": {
				"branch": "executive",
				"can_commit_before_review": true,
				"post_commit_reviews": [
					{ "authority": "judicial", "review_type": "legal_review", "outcomes": ["upheld", "blocked", "stayed", "returned"]}
				]
			}
		}
	})


func _base_constitutional_contract(realm_id: int, realm_name: String, realm: Dictionary, overlay: Dictionary) -> Dictionary:
	var out: Dictionary = overlay.duplicate(true)
	out ["schema"] = CONSTITUTIONAL_CONTRACT_SCHEMA
	out ["version"] = CONTRACT_VERSION
	out ["realm_id"] = realm_id
	out ["realm_name"] = realm_name
	out ["realm"] = realm.duplicate(true)
	out ["authority_is_contractual"] = true
	out ["checks_and_balances_engine_does_not_govern"] = true
	out ["checks_and_balances_engine_resolves_authority_only"] = true
	out ["moddable_authority_graph"] = true
	out ["ui_is_renderer_only"] = true
	return out


func _action_rule_for_contract(action_id: String, action_contract: Dictionary, constitutional_contract: Dictionary) -> Dictionary:
	var clean_action: String = str(action_id).strip_edges().to_lower()
	var actions_raw: Variant = constitutional_contract.get("authority_actions", {})
	var actions: Dictionary = actions_raw if typeof(actions_raw) == TYPE_DICTIONARY else {}

	if actions.has(clean_action):
		var direct: Dictionary = actions.get(clean_action, {})
		if typeof(direct) == TYPE_DICTIONARY:
			if direct.has("alias_for"):
				var alias_key: String = str(direct.get("alias_for", "")).strip_edges().to_lower()
				if actions.has(alias_key):
					var alias_rule: Dictionary = actions.get(alias_key, {})
					if typeof(alias_rule) == TYPE_DICTIONARY:
						return alias_rule.duplicate(true)
			return direct.duplicate(true)

	var intent_type: String = str(action_contract.get("intent_type", "")).strip_edges().to_lower()
	if actions.has(intent_type):
		var intent_rule: Dictionary = actions.get(intent_type, {})
		if typeof(intent_rule) == TYPE_DICTIONARY:
			return intent_rule.duplicate(true)

	return {}


func _create_review_contracts_for_action(
	action_contract: Dictionary,
	constitutional_contract: Dictionary,
	reviews: Array,
	timing: String,
	overlay: Dictionary = {}
) -> Dictionary:
	var review_contracts: Array = []

	for i in range(reviews.size()):
		var review_raw: Variant = reviews [i]
		if typeof(review_raw) != TYPE_DICTIONARY:
			continue

		var review: Dictionary = review_raw
		var review_id: String = _new_review_id(action_contract, timing, i)
		var contract: Dictionary = {
			"schema": REVIEW_CONTRACT_SCHEMA,
			"version": CONTRACT_VERSION,
			"review_id": review_id,
			"authority_review_id": review_id,
			"timing": timing,
			"status": "pending",
			"realm_id": int(action_contract.get("realm_id", -1)),
			"realm_name": str(action_contract.get("realm_name", "")),
			"intent_id": str(action_contract.get("intent_id", "")),
			"actor_id": int(action_contract.get("actor_id", -1)),
			"action_id": str(action_contract.get("action_id", "")),
			"review_authority": str(review.get("authority", "")),
			"review_type": str(review.get("review_type", "")),
			"vote_required": str(review.get("vote_required", "")),
			"outcomes": _safe_array(review.get("outcomes", [])),
			"action_contract": action_contract.duplicate(true),
			"constitutional_contract_key": _realm_key(int(action_contract.get("realm_id", -1)), str(action_contract.get("realm_name", ""))),
			"created_at_ms": int(Time.get_ticks_msec()),
			"ui_is_renderer_only": true
		}

		pending_authority_reviews [review_id] = contract.duplicate(true)
		review_contracts.append(contract)

	var report: Dictionary = {
		"success": bool(overlay.get("commit_allowed", false)),
		"schema": ENGINE_SCHEMA,
		"version": CONTRACT_VERSION,
		"mode": "authority_review_pending",
		"reason": str(overlay.get("reason", "authority_review_required")),
		"commit_allowed": bool(overlay.get("commit_allowed", false)),
		"authority_checked": true,
		"authority_review_pending": true,
		"review_timing": timing,
		"review_contracts": review_contracts.duplicate(true),
		"action_contract": action_contract.duplicate(true),
		"constitutional_contract": constitutional_contract.duplicate(true),
		"ui_is_renderer_only": true
	}

	_commit_state()
	return report


func _authority_allowed_report(action_contract: Dictionary, constitutional_contract: Dictionary, overlay: Dictionary = {}) -> Dictionary:
	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": CONTRACT_VERSION,
		"mode": "authority_allowed",
		"reason": str(overlay.get("reason", "authority_contract_allowed_commit")),
		"commit_allowed": true,
		"authority_checked": true,
		"authority_review_pending": false,
		"action_contract": action_contract.duplicate(true),
		"constitutional_contract": constitutional_contract.duplicate(true),
		"ui_is_renderer_only": true
	}.merged(overlay, true)


func _authority_disputed_report(action_contract: Dictionary, constitutional_contract: Dictionary, overlay: Dictionary = {}) -> Dictionary:
	return {
		"success": false,
		"schema": ENGINE_SCHEMA,
		"version": CONTRACT_VERSION,
		"mode": "authority_disputed",
		"reason": str(overlay.get("reason", "authority_disputed")),
		"commit_allowed": false,
		"authority_checked": true,
		"authority_review_pending": false,
		"action_contract": action_contract.duplicate(true),
		"constitutional_contract": constitutional_contract.duplicate(true),
		"ui_is_renderer_only": true
	}.merged(overlay, true)


func _commit_authority_report(report: Dictionary) -> void:
	last_authority_report = report.duplicate(true)
	_commit_state()
	_publish_audit_row(report)


func _publish_audit_row(report: Dictionary) -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var rows: Array = _safe_array(gs.scenario_state.get("checks_and_balances_authority_audit", []))
	rows.append({
		"schema": "%s.audit_row" % ENGINE_SCHEMA,
		"version": CONTRACT_VERSION,
		"mode": str(report.get("mode", "")),
		"reason": str(report.get("reason", "")),
		"realm_id": int(report.get("action_contract", {}).get("realm_id", -1)) if typeof(report.get("action_contract", {})) == TYPE_DICTIONARY else -1,
		"intent_id": str(report.get("action_contract", {}).get("intent_id", "")) if typeof(report.get("action_contract", {})) == TYPE_DICTIONARY else "",
		"action_id": str(report.get("action_contract", {}).get("action_id", "")) if typeof(report.get("action_contract", {})) == TYPE_DICTIONARY else "",
		"commit_allowed": bool(report.get("commit_allowed", false)),
		"authority_review_pending": bool(report.get("authority_review_pending", false)),
		"audited_at_ms": int(Time.get_ticks_msec()),
		"ui_is_renderer_only": true
	})

	if rows.size() > MAX_AUTHORITY_AUDIT_ROWS:
		rows = rows.slice(rows.size() - MAX_AUTHORITY_AUDIT_ROWS, rows.size())

	gs.scenario_state ["checks_and_balances_authority_audit"] = rows
	gs.scenario_state ["checks_and_balances_last_authority_report"] = report.duplicate(true)


func _emit_authority_event(event_name: String, payload: Dictionary) -> void:
	if gs == null:
		return
	if gs.event_bus == null:
		return

	gs.event_bus.emit(event_name, payload.duplicate(true))


func _new_review_id(action_contract: Dictionary, timing: String, index: int) -> String:
	return "authority_review_%s_%s_%d_%d" % [
		str(action_contract.get("intent_id", "intent")),
		str(timing),
		index,
		int(Time.get_ticks_msec())
	]


func _authority_branch_for_actor_and_intent(actor, envelope: Dictionary, payload: Dictionary, realm_id: int, realm_name: String) -> String:
	var explicit: String = str(payload.get("authority", payload.get("authority_branch", payload.get("branch", "")))).strip_edges().to_lower()
	if explicit != "":
		return explicit

	var contract_raw: Variant = _value(actor, "civic_office_contract", {})
	if typeof(contract_raw) == TYPE_DICTIONARY:
		var contract: Dictionary = contract_raw
		var branch: String = str(contract.get("branch", "")).strip_edges().to_lower()
		if branch != "":
			return branch

	var job_key: String = str(_value(actor, "job", "")).strip_edges().to_lower()
	var title_key: String = str(_value(actor, "civic_title", "")).strip_edges().to_lower()
	var action_id: String = str(envelope.get("action_id", payload.get("action_id", ""))).strip_edges().to_lower()

	if job_key.find("president") >= 0 or title_key.find("president") >= 0:
		return "executive"
	if job_key.find("prime minister") >= 0 or title_key.find("prime minister") >= 0:
		return "executive"
	if job_key.find("senator") >= 0 or title_key.find("senator") >= 0:
		return "legislative"
	if job_key.find("representative") >= 0 or title_key.find("representative") >= 0:
		return "legislative"
	if job_key.find("justice") >= 0 or title_key.find("justice") >= 0:
		return "judicial"
	if bool(_value(actor, "is_royal", false)) or bool(_value(actor, "is_ruler", false)):
		var model: String = str(constitutional_contract_for_realm(realm_id, realm_name).get("government_model", "")).strip_edges().to_lower()
		if model.find("monarchy") >= 0:
			return "monarch"
		return "executive"

	if action_id.find("royal") >= 0:
		return "monarch"
	if action_id.find("law") >= 0 or action_id.find("bill") >= 0:
		return "legislative"
	if action_id.find("court") >= 0 or action_id.find("judicial") >= 0:
		return "judicial"

	return "executive"


func _realm_id_for_actor(actor) -> int:
	if actor == null:
		return -1

	var realm_id: int = int(_value(actor, "realm_id", -1))
	if realm_id > 0:
		return realm_id

	return -1


func _realm_name_for_id(realm_id: int) -> String:
	if realm_id <= 0:
		return ""

	var realm: Dictionary = _realm_dictionary(realm_id)
	var name: String = str(realm.get("name", realm.get("country", ""))).strip_edges()
	if name != "":
		return name

	return "Realm %d" % realm_id


func _realm_dictionary(realm_id: int) -> Dictionary:
	if gs == null or realm_id <= 0:
		return {}

	if gs.realm_engine != null and "realms" in gs.realm_engine and typeof(gs.realm_engine.realms) == TYPE_DICTIONARY:
		var raw: Variant = gs.realm_engine.realms.get(realm_id, {})
		if typeof(raw) == TYPE_DICTIONARY:
			return (raw as Dictionary).duplicate(true)

	return {}


func _realm_key(realm_id: int, realm_name: String = "") -> String:
	return "%d:%s" % [
		realm_id,
		str(realm_name).strip_edges().to_lower()
	]


func _actor_by_id(actor_id: int):
	if gs == null or actor_id <= 0:
		return null

	if gs.player != null and int(_value(gs.player, "id", -1)) == actor_id:
		return gs.player

	if gs.has_method("get_npc_by_id"):
		var npc = gs.get_npc_by_id(actor_id)
		if npc != null:
			return npc

	if gs.has_method("get_or_reactivate_npc_by_id"):
		return gs.get_or_reactivate_npc_by_id(actor_id)

	return null


func _person_display_name(person) -> String:
	if person == null:
		return "Unknown"

	var first_name: String = str(_value(person, "first_name", "")).strip_edges()
	var last_name: String = str(_value(person, "last_name", "")).strip_edges()
	var full_name: String = "%s %s" % [first_name, last_name]
	full_name = full_name.strip_edges()
	if full_name != "":
		return full_name

	return str(_value(person, "name", "Unknown")).strip_edges()


func _value(source, key: String, fallback = null):
	if source == null:
		return fallback

	if typeof(source) == TYPE_DICTIONARY:
		return (source as Dictionary).get(key, fallback)

	return source.get(key) if key in source else fallback


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)


func _failure(reason: String, extra: Dictionary = {}) -> Dictionary:
	EraLog.failure(
		get_script().resource_path.get_file(),
		str(reason)
	)
	var out: Dictionary = {
		"success": false,
		"schema": ENGINE_SCHEMA,
		"version": CONTRACT_VERSION,
		"mode": "authority_resolution_failed",
		"reason": reason,
		"commit_allowed": false,
		"authority_checked": true,
		"ui_is_renderer_only": true
	}

	for key in extra.keys():
		out [key] = extra [key]

	last_authority_report = out.duplicate(true)
	_commit_state()
	return out


func _ensure_state() -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var state: Dictionary = _safe_dictionary(gs.scenario_state.get("checks_and_balances_contract_engine_state", {}))
	constitutional_contracts_by_realm_key = _safe_dictionary(state.get("constitutional_contracts_by_realm_key", constitutional_contracts_by_realm_key))
	pending_authority_reviews = _safe_dictionary(state.get("pending_authority_reviews", pending_authority_reviews))
	last_authority_report = _safe_dictionary(state.get("last_authority_report", last_authority_report))


func _commit_state() -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	gs.scenario_state ["checks_and_balances_contract_engine_state"] = {
		"schema": "%s.state" % ENGINE_SCHEMA,
		"version": CONTRACT_VERSION,
		"constitutional_contracts_by_realm_key": constitutional_contracts_by_realm_key.duplicate(true),
		"pending_authority_reviews": pending_authority_reviews.duplicate(true),
		"last_authority_report": last_authority_report.duplicate(true),
		"ui_is_renderer_only": true
	}