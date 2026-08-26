extends Resource
class_name GlobalIntentContractEngine

const INTENT_SCHEMA:= "eralife.global_intent_contract"
const COMMIT_SCHEMA:= "eralife.global_intent_commit_contract"
const CONTRACT_VERSION:= 1
const RECENT_DEDUPE_WINDOW_MS:= 180
const MAX_RECENT_SIGNATURES:= 256
const MAX_AUDIT_ROWS:= 80

var gs = null
var intent_sequence: int = 0
var recent_intent_signatures: Dictionary = {}
var last_intent_report: Dictionary = {}
var post_commit_tail_queue: Array = []
var post_commit_tail_service_armed: bool = false

func _init(_gs = null) -> void:
	gs = _gs
	_ensure_state()


func bind_game_state(_gs) -> void:
	gs = _gs
	_ensure_state()


func receive_ui_intent(
	intent: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	if gs == null:
		return _failure(
			"missing_game_state",
			{
				"intent": intent.duplicate(false)
			}
		)

	if typeof(intent) != TYPE_DICTIONARY:
		return _failure(
			"invalid_intent_type",
			{
				"received_type": typeof(intent)
			}
		)

	var envelope: Dictionary = _normalize_intent(
		intent,
		context
	)

	if envelope.is_empty():
		return _failure(
			"empty_intent",
			{
				"intent": intent.duplicate(false)
			}
		)

	var ephemeral_infrastructure_intent: bool = (
		bool(
			envelope.get(
				"ephemeral_infrastructure_intent",
				false
			)
		)
		or bool(
			envelope.get(
				"skip_global_intent_persistence",
				false
			)
		)
	)
	var skip_crr_observation: bool = bool(
		envelope.get(
			"skip_crr_observation",
			false
		)
	)
	var authority_prevalidated: bool = (
		bool(
			envelope.get(
				"authority_prevalidated",
				false
			)
		)
		and bool(
			envelope.get(
				"skip_checks_and_balances",
				false
			)
		)
	)
	var immutable_contract_references: bool = bool(
		envelope.get(
			"immutable_contract_references",
			false
		)
	)
	var prevalidated_ephemeral_hot_path: bool = (
		ephemeral_infrastructure_intent
		and skip_crr_observation
		and authority_prevalidated
		and immutable_contract_references
	)

	if prevalidated_ephemeral_hot_path:
		var hot_route_report: Dictionary = _route_intent(
			envelope,
			context
		)
		var hot_success: bool = bool(
			hot_route_report.get(
				"success",
				not hot_route_report.is_empty()
			)
		)

		return {
			"success": hot_success,
			"mode": "global_intent_prevalidated_ephemeral_hot_commit",
			"intent_id": str(
				envelope.get(
					"intent_id",
					""
				)
			),
			"actor_id": int(
				envelope.get(
					"actor_id",
					-1
				)
			),
			"surface_id": str(
				envelope.get(
					"surface_id",
					""
				)
			),
			"action_id": str(
				envelope.get(
					"action_id",
					""
				)
			),
			"route_report": hot_route_report,
			"result": hot_route_report.get(
				"result",
				hot_route_report
			),
			"action_happened_only_if_committed": hot_success,
			"authority_prevalidated": true,
			"checks_and_balances_skipped": true,
			"global_intent_persistence_skipped": true,
			"global_intent_audit_skipped": true,
			"global_intent_crr_skipped": true,
			"global_intent_hot_path_deep_copy_performed": false,
			"ready_gate_member": false,
			"committed_at_ms": int(
				Time.get_ticks_msec()
			)
		}

	var duplicate_report: Dictionary = (
		_duplicate_report_if_recent(
			envelope
		)
	)

	if not duplicate_report.is_empty():
		if not ephemeral_infrastructure_intent:
			last_intent_report = (
				duplicate_report.duplicate(true)
			)

		_publish_audit_row(
			duplicate_report
		)
		_commit_state()
		return duplicate_report

	var validation: Dictionary = _validate_intent(
		envelope,
		context
	)

	if not bool(
		validation.get(
			"success",
			false
		)
	):
		var rejected: Dictionary = _commit_report(
			envelope,
			validation,
			context
		)

		if not ephemeral_infrastructure_intent:
			last_intent_report = (
				rejected.duplicate(true)
			)

		# FIX: this used to call _mark_signature(envelope) on the REJECTED path, which
		# meant a failed intent poisoned its own signature for the dedupe window --
		# so tapping the same button again was silently swallowed as a duplicate
		# instead of retried. That is why mashing a dead button did nothing even
		# after the underlying failure was fixed. Only successful commits are
		# deduped now; a rejection leaves no trace to collide with.
		_publish_audit_row(
			rejected
		)
		_commit_state()
		return rejected

	var route_report: Dictionary = _route_intent(
		envelope,
		context
	)
	var report: Dictionary = _commit_report(
		envelope,
		route_report,
		context
	)
	var mutation_committed: bool = bool(
		report.get(
			"committed",
			false
		)
	)

	if not ephemeral_infrastructure_intent:
		_mark_signature(
			envelope
		)

		last_intent_report = (
			report.duplicate(false)
		)

	var run_crr_tail: bool = (
		mutation_committed
		and not skip_crr_observation
	)
	var persist_tail: bool = (
		not ephemeral_infrastructure_intent
	)
	var diary_tail: bool = (
		mutation_committed
		and bool(
			envelope.get(
				"derive_diary_from_commit",
				false
			)
		)
	)

	report [
		"result_published_before_post_commit_tail"
	] = true
	report [
		"post_commit_tail_queued"
	] = (
		run_crr_tail
		or persist_tail
		or diary_tail
	)
	report [
		"continuous_reality_rendering_pending"
	] = run_crr_tail
	report [
		"audit_persistence_pending"
	] = persist_tail
	report [
		"diary_derivation_pending"
	] = diary_tail

	if ephemeral_infrastructure_intent:
		report [
			"global_intent_persistence_skipped"
		] = true
		report [
			"global_intent_audit_skipped"
		] = true
		report [
			"global_intent_crr_skipped"
		] = skip_crr_observation
		report [
			"global_intent_hot_path_deep_copy_performed"
		] = false

	_queue_post_commit_tail(
		envelope,
		report,
		route_report,
		context,
		persist_tail,
		run_crr_tail,
		diary_tail
	)

	return report
func enqueue_intent(intent: Dictionary, context: Dictionary = {}) -> Dictionary:
	return receive_ui_intent(intent, context)


func express_intent(intent: Dictionary, context: Dictionary = {}) -> Dictionary:
	return receive_ui_intent(intent, context)


func observe_committed_ui_signal(payload: Dictionary, context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	if gs == null:
		return {
			"success": false,
			"reason": "missing_game_state",
			"mode": "global_intent_observe_committed_ui_signal"
		}

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var rows: Array = _safe_array(gs.scenario_state.get("global_intent_observed_ui_signals", []))
	rows.append({
		"schema": "eralife.global_intent_observed_ui_signal",
		"version": CONTRACT_VERSION,
		"intent_id": str(context.get("intent_id", context.get("global_intent_id", ""))),
		"action_id": str(payload.get("action_id", payload.get("legacy_action_id", ""))),
		"surface_id": str(payload.get("surface_id", "")),
		"source": str(payload.get("source", context.get("source", "unknown"))),
		"observed_at_ms": int(Time.get_ticks_msec())
	})

	if rows.size() > MAX_AUDIT_ROWS:
		rows = rows.slice(rows.size() - MAX_AUDIT_ROWS, rows.size())

	gs.scenario_state ["global_intent_observed_ui_signals"] = rows

	return {
		"success": true,
		"mode": "global_intent_observed_committed_ui_signal",
	}


func export_state() -> Dictionary:
	_ensure_state()
	return {
		"schema": "eralife.global_intent_contract_engine_state",
		"version": CONTRACT_VERSION,
		"intent_sequence": intent_sequence,
		"recent_intent_signatures": recent_intent_signatures.duplicate(true),
		"last_intent_report": last_intent_report.duplicate(true)
	}


func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "invalid_state"
		}

	intent_sequence = int(data.get("intent_sequence", intent_sequence))
	recent_intent_signatures = _safe_dictionary(data.get("recent_intent_signatures", recent_intent_signatures))
	last_intent_report = _safe_dictionary(data.get("last_intent_report", last_intent_report))

	_commit_state()

	return {
		"success": true,
		"mode": "global_intent_contract_engine_imported",
		"intent_sequence": intent_sequence
	}


func _normalize_intent(
	intent: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	intent_sequence += 1

	var now_ms: int = int(
		Time.get_ticks_msec()
	)
	var immutable_contract_references: bool = bool(
		intent.get(
			"immutable_contract_references",
			context.get(
				"immutable_contract_references",
				false
			)
		)
	)
	var out: Dictionary = intent.duplicate(
		not immutable_contract_references
	)

	var actor_id: int = int(
		out.get(
			"actor_id",
			context.get(
				"actor_id",
				_default_actor_id()
			)
		)
	)
	var surface_id: String = str(
		out.get(
			"surface_id",
			context.get(
				"surface_id",
				"unknown_surface"
			)
		)
	).strip_edges()
	var action_id: String = str(
		out.get(
			"action_id",
			out.get(
				"legacy_action_id",
				out.get(
					"action",
					""
				)
			)
		)
	).strip_edges()
	var intent_type: String = str(
		out.get(
			"intent_type",
			out.get(
				"type",
				""
			)
		)
	).strip_edges()

	if intent_type == "":
		intent_type = _infer_intent_type(
			action_id,
			surface_id,
			out,
			context
		)

	if action_id == "":
		action_id = intent_type

	if surface_id == "":
		surface_id = "unknown_surface"

	var payload_raw: Variant = out.get(
		"payload",
		{}
	)
	var payload: Dictionary = (
		(
			payload_raw as Dictionary
		).duplicate(
			not immutable_contract_references
		)
		if typeof(
			payload_raw
		) == TYPE_DICTIONARY
		else {}
	)
	var target_raw: Variant = out.get(
		"target",
		{}
	)
	var target: Dictionary = (
		(
			target_raw as Dictionary
		).duplicate(
			not immutable_contract_references
		)
		if typeof(
			target_raw
		) == TYPE_DICTIONARY
		else {}
	)

	var legacy_callback: String = str(
		out.get(
			"legacy_callback",
			context.get(
				"legacy_callback",
				""
			)
		)
	).strip_edges()
	var legacy_args_raw: Variant = out.get(
		"legacy_args",
		context.get(
			"legacy_args",
			[]
		)
	)
	var legacy_args: Array = (
		(
			legacy_args_raw as Array
		).duplicate(
			not immutable_contract_references
		)
		if typeof(
			legacy_args_raw
		) == TYPE_ARRAY
		else []
	)

	if (
		target.is_empty()
		and legacy_callback != ""
	):
		target = {
			"route_kind": "main_scene_legacy_callback",
			"callback": legacy_callback
		}

	if (
		str(
			target.get(
				"route_kind",
				""
			)
		).strip_edges() == ""
		and str(
			target.get(
				"callback",
				""
			)
		).strip_edges() != ""
	):
		target ["route_kind"] = (
			"main_scene_legacy_callback"
		)

	var target_id: int = int(
		out.get(
			"target_id",
			context.get(
				"target_id",
				target.get(
					"target_id",
					-1
				)
			)
		)
	)

	if target_id > 0:
		target ["target_id"] = target_id

	var intent_id: String = str(
		out.get(
			"intent_id",
			out.get(
				"id",
				""
			)
		)
	).strip_edges()

	if intent_id == "":
		intent_id = (
			"global_intent_%d_%d_%d"
			% [
				actor_id,
				intent_sequence,
				now_ms
			]
		)

	out ["schema"] = INTENT_SCHEMA
	out ["version"] = CONTRACT_VERSION
	out ["intent_id"] = intent_id
	out ["id"] = intent_id
	out ["actor_id"] = actor_id
	out ["timestamp_ms"] = now_ms
	out ["timestamp_unix"] = int(
		Time.get_unix_time_from_system()
	)
	out ["intent_type"] = intent_type
	out ["type"] = intent_type
	out ["surface_id"] = surface_id
	out ["action_id"] = action_id
	out ["payload"] = payload
	out ["target"] = target
	out ["target_id"] = target_id
	out ["legacy_callback"] = legacy_callback
	out ["legacy_args"] = legacy_args
	out ["domain"] = str(
		out.get(
			"domain",
			_infer_domain(
				intent_type,
				surface_id,
				action_id
			)
		)
	).strip_edges()
	out ["source"] = str(
		out.get(
			"source",
			context.get(
				"source",
				"unknown_ui"
			)
		)
	).strip_edges()
	out ["authority"] = (
		"global_intent_contract_engine"
	)
	out ["intent_is_not_action"] = true
	out ["action_requires_commit"] = true
	out ["ui_is_expression_only"] = true
	out ["commit_required_before_log"] = true
	out [
		"immutable_contract_references"
	] = immutable_contract_references
	out [
		"intent_recursive_copy_performed"
	] = not immutable_contract_references

	return out

func _resolve_target_engine_for_route(
	engine_property: String
):
	var clean_engine_property: String = str(
		engine_property
	).strip_edges()

	if (
		gs == null
		or clean_engine_property == ""
	):
		return null

	var engine = gs.get(
		clean_engine_property
	)

	if engine != null:
		return engine






	if typeof(
		gs.contract_runtime_engines
	) == TYPE_DICTIONARY:
		var runtime_engines: Dictionary = (
			gs.contract_runtime_engines
		)
		if runtime_engines.has(
			clean_engine_property
		):
			engine = runtime_engines.get(
				clean_engine_property
			)
			if engine != null:
				return engine





	if (
		gs.game_state_contract_engine != null
		and gs.game_state_contract_engine.has_method(
			"get_engine_instance"
		)
	):
		engine = (
			gs.game_state_contract_engine.get_engine_instance(
				clean_engine_property
			)
		)

		if engine != null:
			return engine

	match clean_engine_property:
		"live_person_editor_engine":
			if gs.live_person_editor_engine == null:
				gs.live_person_editor_engine = (
					LivePersonEditorEngine.new(
						gs
					)
				)
			engine = gs.live_person_editor_engine

		"assets_contract_engine":
			if gs.assets_contract_engine == null:
				gs.assets_contract_engine = (
					AssetsContractEngine.new(
						gs
					)
				)
			engine = gs.assets_contract_engine

		"property_market_contract_engine":
			if gs.property_market_contract_engine == null:
				gs.property_market_contract_engine = (
					PropertyMarketContractEngine.new(
						gs
					)
				)
			engine = gs.property_market_contract_engine

		"dealership_contract_engine":
			if gs.dealership_contract_engine == null:
				gs.dealership_contract_engine = (
					DealershipContractEngine.new(
						gs
					)
				)
			engine = gs.dealership_contract_engine

		"property_makeover_contract_engine":
			if gs.property_makeover_contract_engine == null:
				gs.property_makeover_contract_engine = (
					PropertyMakeoverContractEngine.new(
						gs
					)
				)
			engine = gs.property_makeover_contract_engine

		"pet_shop_contract_engine":
			if gs.pet_shop_contract_engine == null:
				gs.pet_shop_contract_engine = (
					PetShopContractEngine.new(
						gs
					)
				)
			engine = gs.pet_shop_contract_engine

		_:
			engine = null

	if (
		engine != null
		and engine.has_method(
			"bind_game_state"
		)
	):
		engine.bind_game_state(
			gs
		)

	if typeof(
		gs.scenario_state
	) == TYPE_DICTIONARY:
		gs.scenario_state [
			"global_intent_last_lazy_engine_property"
		] = clean_engine_property
		gs.scenario_state [
			"global_intent_last_lazy_engine_available"
		] = engine != null
		gs.scenario_state [
			"global_intent_last_lazy_engine_at_ms"
		] = int(
			Time.get_ticks_msec()
		)

	return engine
func _validate_intent(envelope: Dictionary, context: Dictionary = {}) -> Dictionary:
	var action_id: String = str(envelope.get("action_id", "")).strip_edges()
	if action_id == "":
		return {
			"success": false,
			"reason": "missing_action_id",
			"mode": "global_intent_rejected"
		}

	var target: Dictionary = _safe_dictionary(envelope.get("target", {}))
	var route_kind: String = str(target.get("route_kind", "")).strip_edges().to_lower()

	if route_kind == "main_scene_legacy_callback":
		var callback_name: String = str(target.get("callback", envelope.get("legacy_callback", ""))).strip_edges()
		if callback_name == "":
			return {
				"success": false,
				"reason": "missing_legacy_callback",
				"mode": "global_intent_rejected"
			}

		var main_scene = context.get("main_scene", null)
		if main_scene == null or not is_instance_valid(main_scene):
			return {
				"success": false,
				"reason": "missing_main_scene_adapter",
				"mode": "global_intent_rejected",
				"callback": callback_name
			}

		if not main_scene.has_method("_commit_global_intent_legacy_main_scene_callback"):
			return {
				"success": false,
				"reason": "main_scene_legacy_adapter_not_installed",
				"mode": "global_intent_rejected",
				"callback": callback_name
			}

		return {
			"success": true,
			"mode": "global_intent_validated",
			"route_kind": route_kind
		}

	var engine_property: String = str(target.get("engine_property", envelope.get("engine_property", ""))).strip_edges()
	var method_name: String = str(target.get("method", envelope.get("method", ""))).strip_edges()

	if engine_property != "" or method_name != "":
		if engine_property == "" or method_name == "":
			return {
				"success": false,
				"reason": "incomplete_engine_target",
				"mode": "global_intent_rejected",
				"engine_property": engine_property,
				"method": method_name
			}

		var engine = _resolve_target_engine_for_route(
			engine_property
		)

		if engine == null:
			return {
				"success": false,
				"reason": "target_engine_unavailable",
				"mode": "global_intent_rejected",
				"engine_property": engine_property,
				"method": method_name,
				"ui_is_renderer_only": true
			}

		if not engine.has_method(method_name):
			return {
				"success": false,
				"reason": "target_engine_method_missing",
				"mode": "global_intent_rejected",
				"engine_property": engine_property,
				"method": method_name
			}

		return {
			"success": true,
			"mode": "global_intent_validated",
			"route_kind": "engine_method",
			"engine_property": engine_property,
			"method": method_name
		}

	return {
		"success": false,
		"reason": "no_route_available",
		"mode": "global_intent_rejected",
		"target": target.duplicate(true)
	}


func _route_intent(
	envelope: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	var target: Dictionary = _safe_dictionary(
		envelope.get(
			"target",
			{}
		)
	)
	var route_kind: String = str(
		target.get(
			"route_kind",
			""
		)
	).strip_edges().to_lower()
	var authority_prevalidated: bool = (
		bool(
			envelope.get(
				"authority_prevalidated",
				false
			)
		)
		or bool(
			envelope.get(
				"skip_checks_and_balances",
				false
			)
		)
		or bool(
			context.get(
				"authority_prevalidated",
				false
			)
		)
		or bool(
			context.get(
				"skip_checks_and_balances",
				false
			)
		)
	)
	var authority_report: Dictionary = {}

	if authority_prevalidated:
		authority_report = {
			"success": true,
			"mode": "prevalidated_hot_intent_authority",
			"commit_allowed": true,
			"authority_checked": false,
			"authority_prevalidated": true,
			"checks_and_balances_skipped": true,
			"ready_gate_member": false,
			"ui_is_renderer_only": true
		}
	else:
		authority_report = (
			_resolve_checks_and_balances_for_intent(
				envelope,
				context
			)
		)

	if (
		bool(
			authority_report.get(
				"authority_checked",
				false
			)
		)
		and not bool(
			authority_report.get(
				"commit_allowed",
				true
			)
		)
	):
		return authority_report

	var route_context: Dictionary = context.duplicate(false)
	route_context [
		"authority_prevalidated"
	] = authority_prevalidated
	route_context [
		"global_intent_hot_path"
	] = bool(
		envelope.get(
			"ephemeral_infrastructure_intent",
			false
		)
	) or bool(
		envelope.get(
			"skip_global_intent_persistence",
			false
		)
	)

	if bool(
		authority_report.get(
			"authority_checked",
			false
		)
	):
		route_context [
			"checks_and_balances_report"
		] = authority_report.duplicate(false)
		route_context [
			"constitutional_authority_resolved"
		] = true
	elif authority_prevalidated:
		route_context [
			"constitutional_authority_resolved"
		] = true
		route_context [
			"constitutional_authority_prevalidated"
		] = true

	if route_kind == "main_scene_legacy_callback":
		var legacy_report: Dictionary = (
			_route_main_scene_legacy_callback(
				envelope,
				route_context
			)
		)

		if bool(
			authority_report.get(
				"authority_checked",
				false
			)
		):
			legacy_report [
				"checks_and_balances_report"
			] = authority_report.duplicate(false)

		legacy_report [
			"global_intent_hot_path"
		] = bool(
			route_context.get(
				"global_intent_hot_path",
				false
			)
		)
		return legacy_report

	if route_kind == "engine_method":
		var engine_report: Dictionary = (
			_route_target_engine_method(
				envelope,
				route_context
			)
		)

		if bool(
			authority_report.get(
				"authority_checked",
				false
			)
		):
			engine_report [
				"checks_and_balances_report"
			] = authority_report.duplicate(false)

		engine_report [
			"global_intent_hot_path"
		] = bool(
			route_context.get(
				"global_intent_hot_path",
				false
			)
		)
		engine_report [
			"checks_and_balances_skipped"
		] = authority_prevalidated
		return engine_report

	var engine_property: String = str(
		target.get(
			"engine_property",
			envelope.get(
				"engine_property",
				""
			)
		)
	).strip_edges()
	var method_name: String = str(
		target.get(
			"method",
			envelope.get(
				"method",
				""
			)
		)
	).strip_edges()

	if (
		engine_property != ""
		and method_name != ""
	):
		var inferred_engine_report: Dictionary = (
			_route_target_engine_method(
				envelope,
				route_context
			)
		)

		if bool(
			authority_report.get(
				"authority_checked",
				false
			)
		):
			inferred_engine_report [
				"checks_and_balances_report"
			] = authority_report.duplicate(false)

		inferred_engine_report [
			"global_intent_hot_path"
		] = bool(
			route_context.get(
				"global_intent_hot_path",
				false
			)
		)
		return inferred_engine_report

	if str(
		target.get(
			"callback",
			envelope.get(
				"legacy_callback",
				""
			)
		)
	).strip_edges() != "":
		var inferred_legacy_report: Dictionary = (
			_route_main_scene_legacy_callback(
				envelope,
				route_context
			)
		)

		if bool(
			authority_report.get(
				"authority_checked",
				false
			)
		):
			inferred_legacy_report [
				"checks_and_balances_report"
			] = authority_report.duplicate(false)

		inferred_legacy_report [
			"global_intent_hot_path"
		] = bool(
			route_context.get(
				"global_intent_hot_path",
				false
			)
		)
		return inferred_legacy_report

	return {
		"success": false,
		"reason": "unroutable_intent",
		"mode": "global_intent_route_failed",
		"target": target.duplicate(false),
		"global_intent_hot_path": bool(
			route_context.get(
				"global_intent_hot_path",
				false
			)
		)
	}
func _resolve_checks_and_balances_for_intent(
	envelope: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	if (
		bool(
			envelope.get(
				"authority_prevalidated",
				false
			)
		)
		or bool(
			envelope.get(
				"skip_checks_and_balances",
				false
			)
		)
		or bool(
			context.get(
				"authority_prevalidated",
				false
			)
		)
		or bool(
			context.get(
				"skip_checks_and_balances",
				false
			)
		)
	):
		return {
			"success": true,
			"mode": "checks_and_balances_prevalidated_hot_path",
			"commit_allowed": true,
			"authority_checked": false,
			"authority_prevalidated": true,
			"checks_and_balances_skipped": true,
			"engine_constructed_during_route": false,
			"ui_is_renderer_only": true
		}

	if gs == null:
		return {
			"success": true,
			"mode": "checks_and_balances_unavailable_missing_game_state",
			"commit_allowed": true,
			"authority_checked": false,
			"engine_constructed_during_route": false,
			"ui_is_renderer_only": true
		}

	if not "checks_and_balances_contract_engine" in gs:
		return {
			"success": true,
			"mode": "checks_and_balances_engine_not_declared",
			"commit_allowed": true,
			"authority_checked": false,
			"engine_constructed_during_route": false,
			"ui_is_renderer_only": true
		}



	if gs.checks_and_balances_contract_engine == null:
		return {
			"success": true,
			"mode": "checks_and_balances_engine_not_resident",
			"commit_allowed": true,
			"authority_checked": false,
			"engine_constructed_during_route": false,
			"ready_gate_member": false,
			"ui_is_renderer_only": true
		}

	if not gs.checks_and_balances_contract_engine.has_method(
		"resolve_authority_for_intent"
	):
		return {
			"success": true,
			"mode": "checks_and_balances_engine_missing_resolve_method",
			"commit_allowed": true,
			"authority_checked": false,
			"engine_constructed_during_route": false,
			"ui_is_renderer_only": true
		}

	var authority_context: Dictionary = context.duplicate(false)
	authority_context [
		"source"
	] = "global_intent_contract_engine.route_intent"
	authority_context [
		"global_intent_id"
	] = str(
		envelope.get(
			"intent_id",
			""
		)
	)
	authority_context [
		"ui_is_renderer_only"
	] = true
	authority_context [
		"engine_constructed_during_route"
	] = false

	return (
		gs.checks_and_balances_contract_engine
		.resolve_authority_for_intent(
			envelope.duplicate(false),
			authority_context
		)
	)

func _route_main_scene_legacy_callback(envelope: Dictionary, context: Dictionary = {}) -> Dictionary:
	var main_scene = context.get("main_scene", null)
	if main_scene == null or not is_instance_valid(main_scene):
		return {
			"success": false,
			"reason": "main_scene_adapter_unavailable",
			"mode": "global_intent_route_failed"
		}

	if not main_scene.has_method("_commit_global_intent_legacy_main_scene_callback"):
		return {
			"success": false,
			"reason": "main_scene_adapter_method_missing",
			"mode": "global_intent_route_failed"
		}

	var commit_context: Dictionary = context.duplicate(true)
	commit_context ["global_intent_authorized_commit"] = true
	commit_context ["global_intent_id"] = str(envelope.get("intent_id", ""))
	commit_context ["intent_id"] = str(envelope.get("intent_id", ""))

	var result_variant = main_scene.call(
		"_commit_global_intent_legacy_main_scene_callback",
		envelope.duplicate(true),
		commit_context
	)

	var result: Dictionary = _safe_dictionary(result_variant)
	if result.is_empty():
		result = {
			"success": true,
			"mode": "legacy_main_scene_callback_committed"
		}

	result ["route_kind"] = "main_scene_legacy_callback"
	result ["routed_by"] = "global_intent_contract_engine"
	result ["intent_id"] = str(envelope.get("intent_id", ""))

	return result


func _route_target_engine_method(
	envelope: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	if gs == null:
		return {
			"success": false,
			"reason": "missing_game_state",
			"mode": "global_intent_route_failed"
		}

	var immutable_contract_references: bool = bool(
		envelope.get(
			"immutable_contract_references",
			false
		)
	)
	var target_raw: Variant = envelope.get(
		"target",
		{}
	)
	var target: Dictionary = (
		(
			target_raw as Dictionary
		).duplicate(
			not immutable_contract_references
		)
		if typeof(
			target_raw
		) == TYPE_DICTIONARY
		else {}
	)
	var payload_raw: Variant = envelope.get(
		"payload",
		{}
	)
	var payload: Dictionary = (
		(
			payload_raw as Dictionary
		).duplicate(
			not immutable_contract_references
		)
		if typeof(
			payload_raw
		) == TYPE_DICTIONARY
		else {}
	)
	var engine_property: String = str(
		target.get(
			"engine_property",
			envelope.get(
				"engine_property",
				""
			)
		)
	).strip_edges()
	var method_name: String = str(
		target.get(
			"method",
			envelope.get(
				"method",
				""
			)
		)
	).strip_edges()

	if (
		engine_property == ""
		or method_name == ""
	):
		return {
			"success": false,
			"reason": "missing_engine_route",
			"mode": "global_intent_route_failed"
		}

	var engine = _resolve_target_engine_for_route(
		engine_property
	)

	if engine == null:
		return {
			"success": false,
			"reason": "target_engine_unavailable",
			"mode": "global_intent_route_failed",
			"engine_property": engine_property,
			"method": method_name,
			"ui_is_renderer_only": true
		}

	if not engine.has_method(
		method_name
	):
		return {
			"success": false,
			"reason": "target_engine_method_missing",
			"mode": "global_intent_route_failed",
			"engine_property": engine_property,
			"method": method_name
		}

	var args_raw: Variant = target.get(
		"args",
		envelope.get(
			"args",
			[]
		)
	)
	var args: Array = (
		(
			args_raw as Array
		).duplicate(
			not immutable_contract_references
		)
		if typeof(
			args_raw
		) == TYPE_ARRAY
		else []
	)

	if args.is_empty():
		if bool(
			target.get(
				"pass_intent_context",
				false
			)
		):
			args = [
				envelope.duplicate(
					not immutable_contract_references
				),
				context.duplicate(
					not immutable_contract_references
				)
			]
		elif bool(
			target.get(
				"pass_actor_payload",
				true
			)
		):
			var routed_actor_id: int = int(
				target.get(
					"actor_id",
					payload.get(
						"actor_id",
						envelope.get(
							"actor_id",
							-1
						)
					)
				)
			)
			var routed_actor: Person = _actor_by_id(
				routed_actor_id
			)

			if routed_actor == null:
				return {
					"success": false,
					"reason": "target_actor_unavailable",
					"mode": "global_intent_route_failed",
					"engine_property": engine_property,
					"method": method_name,
					"requested_actor_id": routed_actor_id,
					"initiating_actor_id": int(
						envelope.get(
							"actor_id",
							-1
						)
					)
				}

			args = [
				routed_actor,
				payload
			]

	var result_variant: Variant = engine.callv(
		method_name,
		args
	)
	var result: Dictionary = (
		(
			result_variant as Dictionary
		).duplicate(
			not immutable_contract_references
		)
		if typeof(
			result_variant
		) == TYPE_DICTIONARY
		else {}
	)

	if result.is_empty():
		result = {
			"success": true,
			"mode": "target_engine_method_committed",
			"result": result_variant
		}

	result ["route_kind"] = "engine_method"
	result ["engine_property"] = engine_property
	result ["method"] = method_name
	result [
		"routed_by"
	] = "global_intent_contract_engine"
	result ["intent_id"] = str(
		envelope.get(
			"intent_id",
			""
		)
	)
	result ["routed_actor_id"] = int(
		target.get(
			"actor_id",
			payload.get(
				"actor_id",
				envelope.get(
					"actor_id",
					-1
				)
			)
		)
	)
	result [
		"immutable_contract_references"
	] = immutable_contract_references
	result [
		"route_recursive_copy_performed"
	] = not immutable_contract_references

	return result


func _commit_report(
	envelope: Dictionary,
	route_report: Dictionary,
	_context: Dictionary = {}
) -> Dictionary:
	var success: bool = bool(
		route_report.get(
			"success",
			false
		)
	)
	var mutation_committed: bool = bool(
		route_report.get(
			"committed",
			success
		)
	)
	var now_ms: int = int(
		Time.get_ticks_msec()
	)
	var skip_crr_observation: bool = bool(
		envelope.get(
			"skip_crr_observation",
			false
		)
	)

	var report_mode: String = (
		"global_intent_committed"
		if (
			success
			and mutation_committed
		)
		else (
			"global_intent_resolved_without_commit"
			if success
			else "global_intent_rejected"
		)
	)

	if bool(
		route_report.get(
			"authority_review_pending",
			false
		)
	):
		report_mode = (
			"global_intent_pending_authority_review"
		)
	elif (
		bool(
			route_report.get(
				"authority_checked",
				false
			)
		)
		and not bool(
			route_report.get(
				"commit_allowed",
				true
			)
		)
	):
		report_mode = (
			"global_intent_blocked_by_authority_contract"
		)
	elif str(
		route_report.get(
			"mode",
			""
		)
	).strip_edges().begins_with(
		"authority_"
	):
		report_mode = str(
			route_report.get(
				"mode",
				""
			)
		).strip_edges()

	var route_projection: Dictionary = (
		route_report.duplicate(false)
	)

	var report: Dictionary = {
		"schema": COMMIT_SCHEMA,
		"version": CONTRACT_VERSION,
		"success": success,
		"committed": mutation_committed,
		"mode": report_mode,
		"intent_id": str(
			envelope.get(
				"intent_id",
				""
			)
		),
		"actor_id": int(
			envelope.get(
				"actor_id",
				-1
			)
		),
		"target_id": int(
			envelope.get(
				"target_id",
				-1
			)
		),
		"intent_type": str(
			envelope.get(
				"intent_type",
				""
			)
		),
		"surface_id": str(
			envelope.get(
				"surface_id",
				""
			)
		),
		"action_id": str(
			envelope.get(
				"action_id",
				""
			)
		),
		"domain": str(
			envelope.get(
				"domain",
				""
			)
		),
		"source": str(
			envelope.get(
				"source",
				""
			)
		),
		"commit_authority": (
			"global_intent_contract_engine"
		),
		"constitutional_authority_checked": bool(
			route_report.get(
				"authority_checked",
				false
			)
		),
		"constitutional_commit_allowed": bool(
			route_report.get(
				"commit_allowed",
				success
			)
		),
		"authority_review_pending": bool(
			route_report.get(
				"authority_review_pending",
				false
			)
		),
		"intent_is_not_action": true,
		"action_happened_only_if_committed": mutation_committed,
		"ui_must_not_commit": true,
		"crr_required_after_commit": (
			mutation_committed
			and not skip_crr_observation
		),
		"observable_truth_required": mutation_committed,
		"route_report": route_projection,
		"committed_at_ms": now_ms
	}

	if route_report.has(
		"checks_and_balances_report"
	):
		report [
			"checks_and_balances_report"
		] = route_report.get(
			"checks_and_balances_report"
		)

	if route_report.has(
		"reason"
	):
		report [
			"reason"
		] = str(
			route_report.get(
				"reason",
				""
			)
		)

	if route_report.has(
		"result"
	):
		report [
			"result"
		] = route_report.get(
			"result"
		)

	return report
func _queue_post_commit_tail(
	envelope: Dictionary,
	report: Dictionary,
	route_report: Dictionary,
	context: Dictionary,
	persist_intent: bool,
	run_crr: bool,
	derive_diary: bool
) -> void:
	if (
		not persist_intent
		and not run_crr
		and not derive_diary
	):
		return

	post_commit_tail_queue.append({
		"envelope": envelope.duplicate(false),
		"report": report.duplicate(false),
		"route_report": route_report.duplicate(false),
		"context": context.duplicate(false),
		"persist_intent": persist_intent,
		"run_crr": run_crr,
		"derive_diary": derive_diary,
		"stage": 0,
		"queued_at_ms": int(
			Time.get_ticks_msec()
		)
	})

	_arm_post_commit_tail_service()
func _post_commit_tail_should_yield_to_ui() -> bool:
	if (
		gs == null
		or typeof(
			gs.scenario_state
		) != TYPE_DICTIONARY
	):
		return false

	var runtime_guard_raw: Variant = (
		gs.scenario_state.get(
			"runtime_guard",
			{}
		)
	)
	var runtime_guard: Dictionary = (
		runtime_guard_raw as Dictionary
		if typeof(runtime_guard_raw) == TYPE_DICTIONARY
		else {}
	)
	var now_ms: int = int(
		Time.get_ticks_msec()
	)
	var yield_until_ms: int = maxi(
		int(
			runtime_guard.get(
				"ui_interaction_grace_until_ms",
				0
			)
		),
		int(
			runtime_guard.get(
				"truth_resolution_yield_until_ms",
				0
			)
		)
	)

	yield_until_ms = maxi(
		yield_until_ms,
		int(
			gs.scenario_state.get(
				"ready_door_zero_frame_input_fence_until_ms",
				0
			)
		)
	)

	return now_ms < yield_until_ms
func _arm_post_commit_tail_service() -> void:
	if (
		post_commit_tail_service_armed
		or post_commit_tail_queue.is_empty()
	):
		return

	var tree:= Engine.get_main_loop() as SceneTree

	if tree == null:
		call_deferred(
			"_service_post_commit_tail"
		)
		return

	var service_callable:= Callable(
		self,
		"_service_post_commit_tail"
	)

	if tree.process_frame.is_connected(
		service_callable
	):
		post_commit_tail_service_armed = true
		return

	post_commit_tail_service_armed = true

	tree.process_frame.connect(
		service_callable,
		CONNECT_ONE_SHOT
	)
func _service_post_commit_tail() -> void:
	post_commit_tail_service_armed = false

	if post_commit_tail_queue.is_empty():
		return

	if _post_commit_tail_should_yield_to_ui():
		_arm_post_commit_tail_service()
		return

	var row_raw: Variant = (
		post_commit_tail_queue [
			0
		]
	)

	if typeof(row_raw) != TYPE_DICTIONARY:
		post_commit_tail_queue.pop_front()
		_arm_post_commit_tail_service()
		return

	var row: Dictionary = (
		row_raw as Dictionary
	)
	var envelope: Dictionary = (
		row.get(
			"envelope",
			{}
		) as Dictionary
	)
	var report: Dictionary = (
		row.get(
			"report",
			{}
		) as Dictionary
	)
	var route_report: Dictionary = (
		row.get(
			"route_report",
			{}
		) as Dictionary
	)
	var context: Dictionary = (
		row.get(
			"context",
			{}
		) as Dictionary
	)
	var stage: int = int(
		row.get(
			"stage",
			0
		)
	)

	match stage:
		0:
			if bool(
				row.get(
					"run_crr",
					false
				)
			):
				var crr_report: Dictionary = (
					_publish_commit_to_crr(
						envelope,
						report,
						route_report,
						context
					)
				)

				row [
					"crr_report"
				] = crr_report.duplicate(false)

			row ["stage"] = 1

		1:
			if bool(
				row.get(
					"persist_intent",
					false
				)
			):
				var persisted_report: Dictionary = (
					report.duplicate(false)
				)

				persisted_report.erase(
					"game_state"
				)
				persisted_report.erase(
					"runtime_ref"
				)

				last_intent_report = (
					persisted_report.duplicate(false)
				)

				_publish_audit_row(
					persisted_report
				)
				_commit_state()

			row ["stage"] = 2

		2:
			if (
				bool(
					row.get(
						"derive_diary",
						false
					)
				)
				and bool(
					report.get(
						"committed",
						false
					)
				)
			):
				_derive_diary_from_commit(
					envelope,
					report,
					context
				)

			row ["stage"] = 3

		_:
			post_commit_tail_queue.pop_front()

	if (
		not post_commit_tail_queue.is_empty()
		and int(
			row.get(
				"stage",
				0
			)
		) < 3
	):
		post_commit_tail_queue [
			0
		] = row
	elif (
		not post_commit_tail_queue.is_empty()
		and post_commit_tail_queue [
			0
		] == row
	):
		post_commit_tail_queue.pop_front()

	if not post_commit_tail_queue.is_empty():
		_arm_post_commit_tail_service()
func _publish_commit_to_crr(
		envelope: Dictionary,
		commit_report: Dictionary,
		route_report: Dictionary,
		context: Dictionary = {}
) -> Dictionary:
	if gs == null:
		return {}

	if not bool(
		commit_report.get(
			"success",
			false
		)
	):
		return {}




	if (
		bool(
			envelope.get(
				"skip_crr_observation",
				false
			)
		)
		or bool(
			context.get(
				"skip_crr_observation",
				false
			)
		)
	):
		return {}

	if not (
		"crr_contract_engine" in gs
	):
		return {}


	if gs.crr_contract_engine == null:
		return {}

	if not gs.crr_contract_engine.has_method(
		"observe_commit_report"
	):
		return {}

	var safe_envelope: Dictionary = (
		envelope.duplicate(false)
	)
	var safe_commit: Dictionary = (
		commit_report.duplicate(false)
	)
	var safe_route: Dictionary = (
		route_report.duplicate(false)
	)
	var safe_context: Dictionary = (
		context.duplicate(false)
	)

	safe_envelope.erase(
		"game_state"
	)
	safe_envelope.erase(
		"runtime_ref"
	)
	safe_commit.erase(
		"game_state"
	)
	safe_commit.erase(
		"runtime_ref"
	)
	safe_route.erase(
		"game_state"
	)
	safe_route.erase(
		"runtime_ref"
	)
	safe_context.erase(
		"main_scene"
	)
	safe_context.erase(
		"intent_authority_game_state"
	)

	safe_commit ["route_report"] = safe_route

	var mutation_payload: Dictionary = {
		"schema": (
			"eralife.global_intent_to_crr_mutation"
		),
		"version": CONTRACT_VERSION,
		"intent": safe_envelope,
		"commit_report": safe_commit,
		"route_report": safe_route,
		"context": safe_context,
	}

	return (
		gs.crr_contract_engine
		.observe_commit_report(
			safe_commit,
			mutation_payload
		)
	)
func _duplicate_report_if_recent(
		envelope: Dictionary
) -> Dictionary:



	if not bool(
		envelope.get(
			"global_intent_duplicate_suppression_allowed",
			true
		)
	):
		return {}

	var now_ms: int = int(
		Time.get_ticks_msec()
	)
	_prune_recent_signatures(
		now_ms
	)

	var signature: String = _intent_signature(
		envelope
	)

	if signature == "":
		return {}

	if not recent_intent_signatures.has(
		signature
	):
		return {}

	var previous_ms: int = int(
		recent_intent_signatures.get(
			signature,
			0
		)
	)

	if (
		now_ms - previous_ms
		> RECENT_DEDUPE_WINDOW_MS
	):
		return {}

	return {
		"schema": COMMIT_SCHEMA,
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": (
			"global_intent_duplicate_suppressed"
		),
		"intent_id": str(
			envelope.get(
				"intent_id",
				""
			)
		),
		"actor_id": int(
			envelope.get(
				"actor_id",
				-1
			)
		),
		"target_id": int(
			envelope.get(
				"target_id",
				-1
			)
		),
		"intent_type": str(
			envelope.get(
				"intent_type",
				""
			)
		),
		"surface_id": str(
			envelope.get(
				"surface_id",
				""
			)
		),
		"action_id": str(
			envelope.get(
				"action_id",
				""
			)
		),
		"reason": "recent_duplicate_intent"
	}

func _mark_signature(envelope: Dictionary) -> void:
	var now_ms: int = int(Time.get_ticks_msec())
	_prune_recent_signatures(now_ms)

	var signature: String = _intent_signature(envelope)
	if signature == "":
		return

	recent_intent_signatures [signature] = now_ms

	if recent_intent_signatures.size() > MAX_RECENT_SIGNATURES:
		var keys: Array = recent_intent_signatures.keys()
		while keys.size() > MAX_RECENT_SIGNATURES:
			var key = keys.pop_front()
			recent_intent_signatures.erase(key)


func _intent_signature(envelope: Dictionary) -> String:
	var target: Dictionary = _safe_dictionary(envelope.get("target", {}))
	var payload: Dictionary = _safe_dictionary(envelope.get("payload", {}))

	return "%d|%d|%s|%s|%s|%s|%s" % [
		int(envelope.get("actor_id", -1)),
		int(envelope.get("target_id", target.get("target_id", -1))),
		str(envelope.get("intent_type", "")),
		str(envelope.get("surface_id", "")),
		str(envelope.get("action_id", "")),
		str(target),
		str(payload)
	]


func _prune_recent_signatures(now_ms: int) -> void:
	# FIX: this hardcoded 2000ms while the dedupe check uses RECENT_DEDUPE_WINDOW_MS
	# (180ms). The two silently disagreed -- raising the constant above 2000 would
	# have made pruning drop entries the dedupe check still expected to find. Keep
	# a retention margin, but derive it from the constant so they cannot drift.
	var retention_ms: int = maxi(
		2000,
		RECENT_DEDUPE_WINDOW_MS * 4
	)

	var keys: Array = recent_intent_signatures.keys()
	for key in keys:
		var stamped_ms: int = int(recent_intent_signatures.get(key, 0))
		if now_ms - stamped_ms > retention_ms:
			recent_intent_signatures.erase(key)


func _derive_diary_from_commit(envelope: Dictionary, report: Dictionary, _context: Dictionary = {}) -> void:
	if gs == null:
		return
	if gs.life_diary_contract_engine == null:
		return
	if not gs.life_diary_contract_engine.has_method("emit_diary_intent"):
		return

	var route_report: Dictionary = _safe_dictionary(report.get("route_report", {}))
	var result: Dictionary = _safe_dictionary(route_report.get("result", report.get("result", {})))

	var diary_text: String = str(result.get("life_diary_text", result.get("diary_text", ""))).strip_edges()
	if diary_text == "" and bool(envelope.get("derive_text_from_result", false)):
		diary_text = str(result.get("text", result.get("popup_text", ""))).strip_edges()

	if diary_text == "":
		return

	gs.life_diary_contract_engine.emit_diary_intent({
		"type": "committed_action",
		"actor_id": int(envelope.get("actor_id", -1)),
		"text": diary_text,
		"source": "global_intent_contract_engine",
		"dedupe_key": "global_intent_diary_%s" % str(envelope.get("intent_id", "")),
		"commit_id": str(report.get("intent_id", "")),
		"intent_type": str(envelope.get("intent_type", "")),
		"action_id": str(envelope.get("action_id", ""))
	}, {
		"source": "global_intent_contract_engine.derive_diary_from_commit",
	})


func _publish_audit_row(report: Dictionary) -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var rows: Array = _safe_array(gs.scenario_state.get("global_intent_audit", []))
	rows.append({
		"intent_id": str(report.get("intent_id", "")),
		"intent_type": str(report.get("intent_type", "")),
		"surface_id": str(report.get("surface_id", "")),
		"action_id": str(report.get("action_id", "")),
		"actor_id": int(report.get("actor_id", -1)),
		"target_id": int(report.get("target_id", -1)),
		"success": bool(report.get("success", false)),
		"mode": str(report.get("mode", "")),
		"reason": str(report.get("reason", "")),
		"commit_authority": str(report.get("commit_authority", "global_intent_contract_engine")),
		"audited_at_ms": int(Time.get_ticks_msec())
	})

	if rows.size() > MAX_AUDIT_ROWS:
		rows = rows.slice(rows.size() - MAX_AUDIT_ROWS, rows.size())

	gs.scenario_state ["global_intent_audit"] = rows
	gs.scenario_state ["global_intent_last_report"] = report.duplicate(false)


func _ensure_state() -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var state: Dictionary = _safe_dictionary(gs.scenario_state.get("global_intent_contract_engine_state", {}))
	intent_sequence = max(intent_sequence, int(state.get("intent_sequence", intent_sequence)))
	recent_intent_signatures = _safe_dictionary(state.get("recent_intent_signatures", recent_intent_signatures))
	last_intent_report = _safe_dictionary(state.get("last_intent_report", last_intent_report))


func _commit_state() -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	gs.scenario_state ["global_intent_contract_engine_state"] = {
		"schema": "eralife.global_intent_contract_engine_state",
		"version": CONTRACT_VERSION,
		"intent_sequence": intent_sequence,
		"recent_intent_signatures": recent_intent_signatures.duplicate(false),
		"last_intent_report": last_intent_report.duplicate(false),
		"updated_at_ms": int(Time.get_ticks_msec())
	}


func _default_actor_id() -> int:
	if gs == null:
		return -1
	if gs.player != null:
		return int(gs.player.id)
	if "player_id" in gs:
		return int(gs.player_id)
	return -1


func _actor_by_id(actor_id: int):
	if gs == null:
		return null
	if gs.player != null and int(gs.player.id) == actor_id:
		return gs.player
	if gs.has_method("get_or_reactivate_npc_by_id"):
		return gs.get_or_reactivate_npc_by_id(actor_id)
	if gs.has_method("get_npc_by_id"):
		return gs.get_npc_by_id(actor_id)
	return null


func _infer_intent_type(action_id: String, surface_id: String, _intent: Dictionary = {}, _context: Dictionary = {}) -> String:
	var clean_action: String = str(action_id).strip_edges().to_lower()
	var clean_surface: String = str(surface_id).strip_edges().to_lower()

	if clean_action.find("switch") >= 0 or clean_action.find("live as") >= 0:
		return "switch_person"

	if clean_surface.find("relationship") >= 0 or clean_action.find("relationship") >= 0:
		return "relationship_action"

	if clean_action.find("family") >= 0 or clean_action.find("household") >= 0:
		return "family_care_action"

	if clean_surface.find("belong") >= 0 or clean_action in ["consume", "give_to", "share_consume", "throw_away"]:
		return "belonging_action"

	if clean_action.find("buy") >= 0 or clean_action.find("purchase") >= 0:
		return "purchase_action"

	if clean_surface.find("pending") >= 0:
		return "pending_situation_choice"

	if clean_surface.find("superpower") >= 0 or clean_surface.find("power") >= 0:
		return "power_action"

	if clean_surface.find("contract") >= 0:
		return "contract_surface_action"

	return "ui_action"


func _infer_domain(intent_type: String, surface_id: String, action_id: String) -> String:
	var clean_type: String = str(intent_type).strip_edges().to_lower()
	var clean_surface: String = str(surface_id).strip_edges().to_lower()
	var clean_action: String = str(action_id).strip_edges().to_lower()

	if clean_type == "switch_person":
		return "consciousness_switch"
	if clean_type.find("relationship") >= 0 or clean_surface.find("relationship") >= 0:
		return "relationships"
	if clean_type.find("family") >= 0:
		return "family"
	if clean_type.find("belonging") >= 0:
		return "belongings"
	if clean_type.find("purchase") >= 0:
		return "economy"
	if clean_surface.find("school") >= 0 or clean_action.find("school") >= 0:
		return "school"
	if clean_surface.find("career") >= 0 or clean_action.find("career") >= 0:
		return "career"
	if clean_type.find("power") >= 0:
		return "powers"
	return "runtime"


func _failure(reason: String, extra: Dictionary = {}) -> Dictionary:
	EraLog.failure(
		get_script().resource_path.get_file(),
		str(reason)
	)
	var out: Dictionary = {
		"schema": COMMIT_SCHEMA,
		"version": CONTRACT_VERSION,
		"success": false,
		"mode": "global_intent_failed",
		"reason": reason,
		"commit_authority": "global_intent_contract_engine",
		"failed_at_ms": int(Time.get_ticks_msec())
	}

	for key in extra.keys():
		out [key] = extra [key]

	last_intent_report = out.duplicate(true)
	_publish_audit_row(out)
	_commit_state()

	return out


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(value: Variant) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return (value as Array).duplicate(true)
	return []