extends Resource
class_name ScenarioRuntimeContractEngine

const CONTRACT_STATE_SCHEMA:= "eralife.scenario_runtime_contract_engine_state"
const CONTRACT_VERSION:= 1

var gs
var active_popup_contracts: Dictionary = {}
var resolved_popup_contracts: Dictionary = {}
var archived_popup_contracts: Dictionary = {}
var popup_contract_sequence: int = 0
var last_tick_ms: int = 0
var last_report: Dictionary = {}

var state_hydrated: bool = false



const SCENARIO_RUNTIME_INTERVAL_MS: int = 1000





const SCENARIO_RUNTIME_MAX_CONTRACTS_PER_QUANTUM: int = 1
const SCENARIO_RUNTIME_QUANTUM_BUDGET_MS: int = 1

var runtime_scan_active: bool = false
var runtime_scan_contract_ids: Array = []
var runtime_scan_cursor: int = 0
var runtime_scan_changed_count: int = 0
var runtime_scan_automatic_resolutions: Array = []
var runtime_scan_automatic_cursor: int = 0
var runtime_scan_automatic_reports: Array = []


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

	active_popup_contracts = _safe_dictionary(
		gs.scenario_state.get(
			"active_popup_contracts",
			active_popup_contracts
		)
	)
	resolved_popup_contracts = _safe_dictionary(
		gs.scenario_state.get(
			"resolved_popup_contracts",
			resolved_popup_contracts
		)
	)
	archived_popup_contracts = _safe_dictionary(
		gs.scenario_state.get(
			"archived_popup_contracts",
			archived_popup_contracts
		)
	)
	popup_contract_sequence = int(
		gs.scenario_state.get(
			"popup_contract_sequence",
			popup_contract_sequence
		)
	)

	state_hydrated = true


func export_state() -> Dictionary:
	_ensure_state()
	return {
		"schema": CONTRACT_STATE_SCHEMA,
		"version": CONTRACT_VERSION,
		"active_popup_contracts": active_popup_contracts.duplicate(true),
		"resolved_popup_contracts": resolved_popup_contracts.duplicate(true),
		"archived_popup_contracts": archived_popup_contracts.duplicate(true),
		"popup_contract_sequence": popup_contract_sequence,
		"last_tick_ms": last_tick_ms,
		"last_report": last_report.duplicate(true),
		"exported_at_ms": int(Time.get_ticks_msec())
	}


func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "invalid_data"
		}

	active_popup_contracts = _safe_dictionary(data.get("active_popup_contracts", data.get("pending_popup_contracts", {})))
	resolved_popup_contracts = _safe_dictionary(data.get("resolved_popup_contracts", {}))
	archived_popup_contracts = _safe_dictionary(data.get("archived_popup_contracts", {}))
	popup_contract_sequence = int(data.get("popup_contract_sequence", 0))
	last_tick_ms = int(data.get("last_tick_ms", 0))
	last_report = _safe_dictionary(data.get("last_report", {}))

	_commit_state()

	return {
		"success": true,
		"mode": "scenario_runtime_contract_engine_imported",
		"active_count": active_popup_contracts.size(),
		"resolved_count": resolved_popup_contracts.size()
	}


func activate_popup_contract(contract: Dictionary) -> Dictionary:
	_ensure_state()

	if typeof(contract) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "invalid_contract"
		}

	var normalized: Dictionary = contract.duplicate(true)
	var contract_id: String = str(normalized.get("id", "")).strip_edges()
	if contract_id == "":
		popup_contract_sequence += 1
		contract_id = "popup_contract_%d_%d" % [int(Time.get_ticks_msec()), popup_contract_sequence]
		normalized ["id"] = contract_id

	normalized ["state"] = str(normalized.get("state", "pending"))
	normalized ["updated_at_ms"] = int(Time.get_ticks_msec())

	active_popup_contracts [contract_id] = normalized
	_commit_state()

	last_report = {
		"success": true,
		"mode": "popup_contract_activated",
		"contract_id": contract_id,
		"active_count": active_popup_contracts.size()
	}

	return last_report.duplicate(true)

func _contract_actionable_by_actor(
	contract: Dictionary,
	actor_id: int
) -> bool:
	if actor_id <= 0:
		return true

	var direct_target_id: int = int(
		contract.get(
			"target_id",
			contract.get(
				"target",
				-1
			)
		)
	)

	if direct_target_id == actor_id:
		return true

	var perspective_action_actor_ids: Array = _safe_array(
		contract.get(
			"perspective_action_actor_ids",
			[]
		)
	)

	if not perspective_action_actor_ids.is_empty():
		for raw_action_actor_id in perspective_action_actor_ids:
			if int(
				raw_action_actor_id
			) == actor_id:
				return true

		return false

	var schema: String = str(
		contract.get(
			"schema",
			""
		)
	).strip_edges()
	var source: String = str(
		contract.get(
			"source",
			""
		)
	).strip_edges().to_lower()
	var request: String = str(
		contract.get(
			"request",
			""
		)
	).strip_edges().to_lower()
	var is_birth_starter: bool = (
		schema == (
			"eralife.pending_situation."
			+ "birth_starter_contract"
		)
		or source == "birth_starter_contract"
	)



	if is_birth_starter:
		var shared_birth_decision: bool = (
			request == (
				"multi_perspective_family_argument"
			)
			or bool(
				_safe_dictionary(
					contract.get(
						"shared_decision_model",
						{}
					)
				).get(
					"enabled",
					false
				)
			)
		)

		if not shared_birth_decision:
			return false

	var decision_actor_ids: Array = _safe_array(
		contract.get(
			"decision_actor_ids",
			[]
		)
	)

	if not decision_actor_ids.is_empty():
		for raw_decision_actor_id in decision_actor_ids:
			if int(
				raw_decision_actor_id
			) == actor_id:
				return true

		return false




	var participant_ids: Array = _safe_array(
		contract.get(
			"participant_ids",
			[]
		)
	)

	for raw_participant_id in participant_ids:
		if int(
			raw_participant_id
		) == actor_id:
			return true

	return false
func _fallback_deadline_option_id(contract: Dictionary) -> String:
	# When a contract expires with nobody having acted, pick the LOWEST priority
	# option as "what happened by default". Priority in these option sets tracks how
	# constructive a choice is (accept_plan 86, apologize 80, walk_away 25), so the
	# lowest one is the neglect outcome -- which is the honest result of time running
	# out, rather than the household quietly making the best possible decision.
	var options: Array = _safe_array(
		contract.get(
			"response_options",
			[]
		)
	)

	var best_id: String = ""
	var best_priority: int = 0

	for raw_option in options:
		if typeof(raw_option) != TYPE_DICTIONARY:
			continue

		var option: Dictionary = raw_option as Dictionary
		var option_id: String = str(
			option.get(
				"id",
				""
			)
		).strip_edges()

		if option_id == "":
			continue

		var priority: int = int(
			option.get(
				"priority",
				50
			)
		)

		if best_id == "" or priority < best_priority:
			best_id = option_id
			best_priority = priority

	if best_id == "":
		return "acknowledge"

	return best_id


func get_pending_popup_contracts(
	target_id: int = -1
) -> Array:
	_ensure_state()

	var out: Array = []
	var now_ms: int = int(
		Time.get_ticks_msec()
	)

	for raw_id in active_popup_contracts.keys():
		var source_contract: Dictionary = _safe_dictionary(
			active_popup_contracts.get(
				raw_id,
				{}
			)
		)

		if source_contract.is_empty():
			continue

		var state: String = str(
			source_contract.get(
				"state",
				"pending"
			)
		).strip_edges().to_lower()

		if state not in [
			"pending",
			"escalated",
			"overdue",
			"active_obligation"
		]:
			continue

		if (
			target_id > 0
			and not _contract_actionable_by_actor(
				source_contract,
				target_id
			)
		):
			continue



		var projected_contract: Dictionary = (
			source_contract.duplicate(true)
		)

		projected_contract [
			"sort_urgency"
		] = float(
			projected_contract.get(
				"urgency",
				0.0
			)
		)
		projected_contract [
			"sort_age_ms"
		] = (
			now_ms
			- int(
				projected_contract.get(
					"created_at_ms",
					now_ms
				)
			)
		)
		projected_contract [
			"pending_viewer_actor_id"
		] = target_id
		projected_contract [
			"pending_visibility_decision_owner_scoped"
		] = true
		projected_contract [
			"audience_membership_does_not_create_pending_ownership"
		] = true

		out.append(
			projected_contract
		)

	out.sort_custom(
		Callable(
			self,
			"_sort_pending_contracts"
		)
	)

	return out
func get_pending_count(target_id: int = -1) -> int:
	return get_pending_popup_contracts(target_id).size()


func get_contract(contract_id: String) -> Dictionary:
	_ensure_state()
	var clean_id: String = str(contract_id).strip_edges()
	if clean_id == "":
		return {}
	return _safe_dictionary(active_popup_contracts.get(clean_id, resolved_popup_contracts.get(clean_id, {})))

func _contract_visible_to_actor(contract: Dictionary, actor_id: int) -> bool:
	if actor_id <= 0:
		return true

	var direct_target_id: int = int(contract.get("target_id", contract.get("target", -1)))
	if direct_target_id == actor_id:
		return true

	var participant_ids: Array = _safe_array(contract.get("participant_ids", []))
	for raw_id in participant_ids:
		if int(raw_id) == actor_id:
			return true

	var audience_ids: Array = _safe_array(contract.get("audience_ids", []))
	for raw_audience_id in audience_ids:
		if int(raw_audience_id) == actor_id:
			return true

	var decision_actor_ids: Array = _safe_array(contract.get("decision_actor_ids", []))
	for raw_decision_id in decision_actor_ids:
		if int(raw_decision_id) == actor_id:
			return true

	return false
func resolve_popup_contract(contract_id: String, option_id: String, payload: Dictionary = {}) -> Dictionary:
	_ensure_state()

	var clean_id: String = str(contract_id).strip_edges()
	if clean_id == "" or not active_popup_contracts.has(clean_id):
		return {
			"success": false,
			"reason": "contract_not_active",
			"contract_id": clean_id
		}

	var contract: Dictionary = _safe_dictionary(active_popup_contracts.get(clean_id, {}))
	var clean_option: String = str(option_id).strip_edges()
	if clean_option == "":
		clean_option = "acknowledge"

	var option: Dictionary = _option_for_contract(contract, clean_option)
	var resolution_report: Dictionary = _apply_contract_resolution(contract, option, payload)

	contract ["state"] = "resolved"
	contract ["selected_response"] = clean_option
	contract ["resolution"] = resolution_report.duplicate(true)
	contract ["resolved_at_ms"] = int(Time.get_ticks_msec())
	contract ["updated_at_ms"] = int(Time.get_ticks_msec())

	active_popup_contracts.erase(clean_id)
	resolved_popup_contracts [clean_id] = contract

	while resolved_popup_contracts.size() > 128:
		var oldest_key: String = str(resolved_popup_contracts.keys() [0])
		archived_popup_contracts [oldest_key] = resolved_popup_contracts.get(oldest_key, {})
		resolved_popup_contracts.erase(oldest_key)

	_commit_state()

	return {
		"success": true,
		"mode": "popup_contract_resolved",
		"contract_id": clean_id,
		"option_id": clean_option,
		"text": str(resolution_report.get("text", "")),
		"popup_title": str(resolution_report.get("popup_title", "Situation Resolved")),
		"popup_text": str(resolution_report.get("popup_text", resolution_report.get("text", ""))),
		"popup_footer": str(resolution_report.get("popup_footer", "Tap anywhere to continue.")),
		"resolution_report": resolution_report.duplicate(true)
	}


func runtime_tick(
	delta: float = 0.0
) -> Dictionary:
	var now_ms: int = int(
		Time.get_ticks_msec()
	)



	if (
		not runtime_scan_active
		and now_ms - last_tick_ms
			< SCENARIO_RUNTIME_INTERVAL_MS
	):
		var throttled_report: Dictionary = (
			last_report.duplicate(false)
		)
		throttled_report ["service_due"] = false
		throttled_report ["cycle_completed_now"] = false
		return throttled_report

	_ensure_state()

	if not runtime_scan_active:
		runtime_scan_active = true
		runtime_scan_contract_ids = (
			active_popup_contracts.keys()
		)
		runtime_scan_cursor = 0
		runtime_scan_changed_count = 0
		runtime_scan_automatic_resolutions = []
		runtime_scan_automatic_cursor = 0
		runtime_scan_automatic_reports = []

	var quantum_started_ms: int = int(
		Time.get_ticks_msec()
	)
	var processed_this_quantum: int = 0

	while (
		runtime_scan_cursor
			< runtime_scan_contract_ids.size()
		and processed_this_quantum
			< SCENARIO_RUNTIME_MAX_CONTRACTS_PER_QUANTUM
	):
		if (
			int(
				Time.get_ticks_msec()
			) - quantum_started_ms
			>= SCENARIO_RUNTIME_QUANTUM_BUDGET_MS
		):
			break

		var contract_id: String = str(
			runtime_scan_contract_ids [
				runtime_scan_cursor
			]
		)
		runtime_scan_cursor += 1
		processed_this_quantum += 1

		if not active_popup_contracts.has(
			contract_id
		):
			continue

		var contract: Dictionary = _safe_dictionary(
			active_popup_contracts.get(
				contract_id,
				{}
			)
		)

		if contract.is_empty():
			continue

		var before_state: String = str(
			contract.get(
				"state",
				"pending"
			)
		)
		var before_stage: int = int(
			contract.get(
				"escalation_stage",
				0
			)
		)

		contract = _tick_contract(
			contract,
			now_ms,
			delta
		)

		if (
			before_state != str(
				contract.get(
					"state",
					""
				)
			)
			or before_stage != int(
				contract.get(
					"escalation_stage",
					0
				)
			)
		):
			runtime_scan_changed_count += 1

		active_popup_contracts [
			contract_id
		] = contract

		if bool(
			contract.get(
				"automatic_deadline_resolution_requested",
				false
			)
		):
			runtime_scan_automatic_resolutions.append({
				"contract_id": contract_id,
				"option_id": str(
					contract.get(
						"deadline_default_option_id",
						"acknowledge"
					)
				),
				"target_id": int(
					contract.get(
						"target_id",
						-1
					)
				)
			})


	if (
		runtime_scan_cursor
			< runtime_scan_contract_ids.size()
	):
		last_report = {
			"success": true,
			"mode": (
				"scenario_runtime_contract_tick_quantum"
			),
			"service_due": true,
			"cycle_complete": false,
			"cycle_completed_now": false,
			"changed": runtime_scan_changed_count,
			"processed_this_quantum": (
				processed_this_quantum
			),
			"scan_cursor": runtime_scan_cursor,
			"scan_count": (
				runtime_scan_contract_ids.size()
			),
			"active_count": (
				active_popup_contracts.size()
			),
			"automatic_resolution_count": (
				runtime_scan_automatic_resolutions.size()
			),
			"ui_is_renderer_only": true,
			"updated_at_ms": now_ms
		}

		return last_report.duplicate(false)



	if (
		runtime_scan_automatic_cursor
			< runtime_scan_automatic_resolutions.size()
	):
		var resolution_raw: Variant = (
			runtime_scan_automatic_resolutions [
				runtime_scan_automatic_cursor
			]
		)
		runtime_scan_automatic_cursor += 1

		if typeof(resolution_raw) == TYPE_DICTIONARY:
			var resolution: Dictionary = (
				resolution_raw as Dictionary
			)
			var contract_id: String = str(
				resolution.get(
					"contract_id",
					""
				)
			)
			var option_id: String = str(
				resolution.get(
					"option_id",
					"acknowledge"
				)
			)

			if contract_id != "":
				runtime_scan_automatic_reports.append(
					resolve_popup_contract(
						contract_id,
						option_id,
						{
							"target_id": int(
								resolution.get(
									"target_id",
									-1
								)
							),
							"viewer_actor_id": int(
								resolution.get(
									"target_id",
									-1
								)
							),
						}
					)
				)

		last_report = {
			"success": true,
			"mode": (
				"scenario_runtime_automatic_resolution_quantum"
			),
			"service_due": true,
			"cycle_complete": false,
			"cycle_completed_now": false,
			"changed": runtime_scan_changed_count,
			"processed_this_quantum": (
				processed_this_quantum
			),
			"automatic_resolution_cursor": (
				runtime_scan_automatic_cursor
			),
			"automatic_resolution_count": (
				runtime_scan_automatic_resolutions.size()
			),
			"active_count": (
				active_popup_contracts.size()
			),
			"ui_is_renderer_only": true,
			"updated_at_ms": now_ms
		}

		return last_report.duplicate(false)




	if (
		runtime_scan_changed_count > 0
		and runtime_scan_automatic_reports.is_empty()
	):
		_commit_state()

	var completed_changed_count: int = (
		runtime_scan_changed_count
	)
	var completed_automatic_reports: Array = (
		runtime_scan_automatic_reports.duplicate(false)
	)
	var completed_scan_count: int = (
		runtime_scan_contract_ids.size()
	)

	runtime_scan_active = false
	runtime_scan_contract_ids = []
	runtime_scan_cursor = 0
	runtime_scan_changed_count = 0
	runtime_scan_automatic_resolutions = []
	runtime_scan_automatic_cursor = 0
	runtime_scan_automatic_reports = []

	last_tick_ms = now_ms

	last_report = {
		"success": true,
		"mode": "scenario_runtime_contract_tick",
		"service_due": true,
		"cycle_complete": true,
		"cycle_completed_now": true,
		"changed": completed_changed_count,
		"processed_contract_count": completed_scan_count,
		"active_count": active_popup_contracts.size(),
		"automatic_resolution_count": (
			completed_automatic_reports.size()
		),
		"automatic_resolution_reports": (
			completed_automatic_reports
		),
		"quantum_contract_limit": (
			SCENARIO_RUNTIME_MAX_CONTRACTS_PER_QUANTUM
		),
		"quantum_budget_ms": (
			SCENARIO_RUNTIME_QUANTUM_BUDGET_MS
		),
		"ui_is_renderer_only": true,
		"updated_at_ms": now_ms
	}

	return last_report.duplicate(false)


func _tick_contract(
	contract: Dictionary,
	now_ms: int,
	delta: float
) -> Dictionary:
	var out: Dictionary = contract.duplicate(true)
	var urgency: float = clampf(
		float(
			out.get(
				"urgency",
				0.0
			)
		)
		+ float(
			out.get(
				"decay",
				0.0
			)
		) * maxf(
			delta,
			1.0
		),
		0.0,
		100.0
	)
	out ["urgency"] = urgency

	var deadline_at_ms: int = int(
		out.get(
			"deadline_at_ms",
			0
		)
	)

	if deadline_at_ms > 0:
		var remaining_ms: int = maxi(
			0,
			deadline_at_ms - now_ms
		)
		out ["remaining_response_ms"] = remaining_ms
		out ["remaining_response_seconds"] = int(
			ceil(
				float(
					remaining_ms
				) / 1000.0
			)
		)

		if remaining_ms <= 0:
			out ["state"] = "overdue"
			out ["urgency"] = 100.0

			if not bool(
				out.get(
					"automatic_deadline_resolution_emitted",
					false
				)
			):
				out [
					"automatic_deadline_resolution_requested"
				] = true
				out [
					"automatic_deadline_resolution_emitted"
				] = true

	# FIX: nothing anywhere checked whether a contract's decision actors were still
	# alive. Combined with resolve_popup_contract() only ever being reachable from a
	# player tap, a household argument owned by the parents kept escalating after both
	# parents were dead -- nobody left in the world could ever settle it. If every
	# listed decision actor is gone, time settles it the same way expiry does.
	var decision_actor_ids: Array = _safe_array(
		out.get(
			"decision_actor_ids",
			[]
		)
	)

	if (
		not decision_actor_ids.is_empty()
		and not bool(
			out.get(
				"automatic_deadline_resolution_emitted",
				false
			)
		)
	):
		var living_decision_actor_found: bool = false

		for raw_decision_actor_id in decision_actor_ids:
			var decision_actor: Person = _runtime_actor_by_id(
				int(raw_decision_actor_id)
			)

			if decision_actor != null and bool(decision_actor.alive):
				living_decision_actor_found = true
				break

		if not living_decision_actor_found:
			out ["state"] = "overdue"
			out ["urgency"] = 100.0
			out [
				"automatic_deadline_resolution_requested"
			] = true
			out [
				"automatic_deadline_resolution_emitted"
			] = true
			out [
				"automatic_deadline_resolution_reason"
			] = "no_living_decision_actor"

			if str(
				out.get(
					"deadline_default_option_id",
					""
				)
			).strip_edges() == "":
				out [
					"deadline_default_option_id"
				] = _fallback_deadline_option_id(
					out
				)

	var expires_age: float = float(
		out.get(
			"expires_age",
			-1.0
		)
	)

	if (
		expires_age >= 0.0
		and gs != null
		and gs.player != null
		and float(
			gs.player.age
		) >= expires_age
	):
		out ["state"] = "overdue"
		out ["urgency"] = 100.0

		# FIX: expires_age used to only paint the contract "overdue" and leave it in
		# the pending list forever. Nothing in the game resolves a contract on an
		# NPC's behalf -- resolve_popup_contract() is only ever reached from a player
		# tap -- so a household situation owned by the parents could never clear. Age
		# based expiry now requests the same automatic resolution that deadline_at_ms
		# already used, so time passing actually settles it.
		if not bool(
			out.get(
				"automatic_deadline_resolution_emitted",
				false
			)
		):
			out [
				"automatic_deadline_resolution_requested"
			] = true
			out [
				"automatic_deadline_resolution_emitted"
			] = true
			out [
				"automatic_deadline_resolution_reason"
			] = "expires_age"

			if str(
				out.get(
					"deadline_default_option_id",
					""
				)
			).strip_edges() == "":
				out [
					"deadline_default_option_id"
				] = _fallback_deadline_option_id(
					out
				)

	var next_escalation_ms: int = int(
		out.get(
			"next_escalation_ms",
			0
		)
	)

	if (
		next_escalation_ms > 0
		and now_ms >= next_escalation_ms
	):
		out ["state"] = "escalated"
		out ["escalation_stage"] = int(
			out.get(
				"escalation_stage",
				0
			)
		) + 1
		out ["urgency"] = clampf(
			float(
				out.get(
					"urgency",
					0.0
				)
			) + 18.0,
			0.0,
			100.0
		)
		out ["next_escalation_ms"] = (
			now_ms
			+ _next_escalation_delay_ms(
				out
			)
		)

		var triggers: Array = _safe_array(
			out.get(
				"escalation_triggers",
				[]
			)
		)

		if not triggers.is_empty():
			_apply_escalation_trigger(
				out,
				triggers [
					mini(
						triggers.size() - 1,
						int(
							out.get(
								"escalation_stage",
								1
							)
						) - 1
					)
				]
			)

	out ["updated_at_ms"] = now_ms
	return out


func _next_escalation_delay_ms(contract: Dictionary) -> int:
	var urgency: float = float(contract.get("urgency", 0.0))
	if urgency >= 90.0:
		return 5000
	if urgency >= 70.0:
		return 10000
	if urgency >= 45.0:
		return 15000
	return 30000


func _apply_escalation_trigger(contract: Dictionary, trigger: Variant) -> void:
	if typeof(trigger) != TYPE_DICTIONARY:
		return

	var row: Dictionary = trigger as Dictionary
	var title_suffix: String = str(row.get("title_suffix", "")).strip_edges()
	if title_suffix != "":
		contract ["title"] = "%s %s" % [str(contract.get("title", "")), title_suffix]

	var overview: String = str(row.get("overview", "")).strip_edges()
	if overview != "":
		contract ["overview"] = overview

	var details: String = str(row.get("details", "")).strip_edges()
	if details != "":
		contract ["details"] = details


func _apply_contract_resolution(
	contract: Dictionary,
	option: Dictionary,
	payload: Dictionary = {}
) -> Dictionary:
	var option_id: String = str(
		option.get(
			"id",
			option.get(
				"resolution",
				"acknowledge"
			)
		)
	).strip_edges()
	var request: String = str(
		contract.get(
			"request",
			""
		)
	).strip_edges().to_lower()

	if (
		request == "loan"
		and option_id in [
			"accept",
			"give_money",
			"lend_money"
		]
	):
		return _apply_loan_acceptance(
			contract,
			option
		)

	var actor_id: int = int(
		payload.get(
			"viewer_actor_id",
			payload.get(
				"perspective_actor_id",
				payload.get(
					"target_id",
					contract.get(
						"target_id",
						contract.get(
							"target",
							-1
						)
					)
				)
			)
		)
	)
	var bank_delta: int = int(
		option.get(
			"bank_delta",
			0
		)
	)
	var bank_report: Dictionary = {}

	if bank_delta != 0:
		bank_report = _apply_contract_bank_delta(
			actor_id,
			bank_delta,
			contract,
			option
		)

	var routed_resolution_report: Dictionary = (
		_route_contract_resolution(
			contract,
			option,
			actor_id,
			payload
		)
	)
	var popup_text: String = str(
		option.get(
			"result_text",
			option.get(
				"text",
				"You chose: %s" % str(
					option.get(
						"label",
						option_id
					)
				)
			)
		)
	)

	if not routed_resolution_report.is_empty():
		popup_text = str(
			routed_resolution_report.get(
				"popup_text",
				routed_resolution_report.get(
					"text",
					popup_text
				)
			)
		)

	if not bank_report.is_empty():
		var balance_text: String = str(
			bank_report.get(
				"balance_text",
				""
			)
		).strip_edges()

		if balance_text != "":
			popup_text = "%s\n\n%s" % [
				popup_text,
				balance_text
			]

	return {
		"success": bool(
			routed_resolution_report.get(
				"success",
				true
			)
		),
		"text": str(
			routed_resolution_report.get(
				"text",
				option.get(
					"journal_text",
					option.get(
						"text",
						"I dealt with %s."
						% str(
							contract.get(
								"title",
								"the situation"
							)
						)
					)
				)
			)
		),
		"popup_title": str(
			routed_resolution_report.get(
				"popup_title",
				option.get(
					"popup_title",
					"Situation Resolved"
				)
			)
		),
		"popup_text": popup_text,
		"popup_footer": str(
			routed_resolution_report.get(
				"popup_footer",
				option.get(
					"popup_footer",
					"Tap anywhere to continue."
				)
			)
		),
		"bank_report": bank_report.duplicate(true),
		"money_delta_report": bank_report.duplicate(true),
		"routed_resolution_report": (
			routed_resolution_report.duplicate(true)
		)
	}


func _route_contract_resolution(
	contract: Dictionary,
	option: Dictionary,
	actor_id: int,
	payload: Dictionary
) -> Dictionary:
	if gs == null:
		return {}

	var route: Dictionary = _safe_dictionary(
		contract.get(
			"resolution_route",
			{}
		)
	)

	if route.is_empty():
		return {}

	var engine_property: String = str(
		route.get(
			"engine_property",
			""
		)
	).strip_edges()
	var method_name: String = str(
		route.get(
			"method",
			""
		)
	).strip_edges()

	if (
		engine_property == ""
		or method_name == ""
	):
		return {}

	var engine: Variant = gs.get(
		engine_property
	)

	if (
		engine == null
		or not engine.has_method(
			method_name
		)
	):
		return {
			"success": false,
			"reason": "pending_resolution_route_unavailable",
			"engine_property": engine_property,
			"method": method_name,
			"contract_id": str(
				contract.get(
					"id",
					contract.get(
						"contract_id",
						""
					)
				)
			)
		}

	var routed_actor: Person = _runtime_actor_by_id(
		actor_id
	)
	var resolution_payload: Dictionary = _safe_dictionary(
		option.get(
			"resolution_payload",
			{}
		)
	)

	for key in payload.keys():
		if not resolution_payload.has(
			key
		):
			resolution_payload [key] = payload [key]




	for canonical_key in [
		"case_id",
		"interrogation_stage",
		"interrogation_stage_count",
		"crime_event",
		"weapon_name",
		"weapon_action_label",
		"location_label",
		"target_name",
		"body_part",
		"witness_count",
		"severity",
		"intent",
		"target",
		"target_id",
		"contract_type",
		"category",
		"pending_category"
	]:
		if not contract.has(
			canonical_key
		):
			continue

		var canonical_value: Variant = contract.get(
			canonical_key
		)
		resolution_payload [canonical_key] = (
			canonical_value.duplicate(true)
			if typeof(canonical_value) in [
				TYPE_DICTIONARY,
				TYPE_ARRAY
			]
			else canonical_value
		)

	var stage_count: int = maxi(
		1,
		int(
			resolution_payload.get(
				"interrogation_stage_count",
				3
			)
		)
	)

	if contract.has(
		"interrogation_stage"
	):
		resolution_payload ["interrogation_stage"] = clampi(
			int(
				contract.get(
					"interrogation_stage",
					1
				)
			),
			1,
			stage_count
		)

	resolution_payload ["actor_id"] = actor_id
	resolution_payload ["option_id"] = str(
		option.get(
			"id",
			""
		)
	)
	resolution_payload ["source_contract_id"] = str(
		contract.get(
			"id",
			contract.get(
				"contract_id",
				""
			)
		)
	)
	resolution_payload ["source_contract_schema"] = str(
		contract.get(
			"schema",
			""
		)
	)
	resolution_payload ["resolution_route"] = (
		route.duplicate(true)
	)
	resolution_payload ["scenario_runtime_routed"] = true
	resolution_payload [
		"canonical_source_contract_identity_applied"
	] = true
	resolution_payload [
		"ui_identity_override_forbidden"
	] = true

	var pass_actor_payload: bool = bool(
		route.get(
			"pass_actor_payload",
			true
		)
	)
	var route_call_result: Variant

	if pass_actor_payload:
		if routed_actor == null:
			return {
				"success": false,
				"reason": "pending_resolution_actor_unavailable",
				"actor_id": actor_id,
				"engine_property": engine_property,
				"method": method_name,
				"contract_id": str(
					resolution_payload.get(
						"source_contract_id",
						""
					)
				)
			}

		route_call_result = engine.call(
			method_name,
			routed_actor,
			resolution_payload
		)
	else:
		route_call_result = engine.call(
			method_name,
			resolution_payload
		)

	var normalized_result: Dictionary = _safe_dictionary(
		route_call_result
	)

	if normalized_result.is_empty():
		return {
			"success": false,
			"reason": "pending_resolution_route_returned_invalid_result",
			"engine_property": engine_property,
			"method": method_name,
			"actor_id": actor_id,
			"contract_id": str(
				resolution_payload.get(
					"source_contract_id",
					""
				)
			),
			"returned_type": typeof(
				route_call_result
			)
		}

	normalized_result ["scenario_runtime_routed"] = true
	normalized_result ["resolution_engine_property"] = (
		engine_property
	)
	normalized_result ["resolution_method"] = method_name
	normalized_result ["source_contract_id"] = str(
		normalized_result.get(
			"source_contract_id",
			resolution_payload.get(
				"source_contract_id",
				""
			)
		)
	)
	normalized_result ["resolved_interrogation_stage"] = int(
		resolution_payload.get(
			"interrogation_stage",
			0
		)
	)
	normalized_result [
		"canonical_source_contract_identity_applied"
	] = true

	return normalized_result
func _apply_contract_bank_delta(actor_id: int, bank_delta: int, contract: Dictionary, option: Dictionary) -> Dictionary:
	if gs == null or actor_id <= 0 or bank_delta == 0:
		return {}

	var actor: Person = _runtime_actor_by_id(actor_id)
	if actor == null:
		return {}

	var previous_balance: int = max(0, int(actor.bank_balance))
	var new_balance: int = max(0, previous_balance + int(bank_delta))
	var bank_engine_report: Dictionary = {}

	if gs.bank_engine != null:
		if gs.bank_engine.has_method("ensure_bank_account_for_actor") and typeof(gs.bank_engine.get("accounts")) == TYPE_DICTIONARY:
			var account: Dictionary = gs.bank_engine.ensure_bank_account_for_actor(actor, {
				"source": "scenario_runtime_contract_resolution",
				"contract_id": str(contract.get("id", contract.get("contract_id", ""))),
				"option_id": str(option.get("id", "")),
				"currency": "USD"
			})
			var account_id: String = str(account.get("account_id", "")).strip_edges()
			if account_id != "" and gs.bank_engine.accounts.has(account_id):
				var account_balance: float = max(0.0, float(gs.bank_engine.accounts [account_id].get("balance", previous_balance)))
				previous_balance = int(round(account_balance))
				new_balance = max(0, previous_balance + int(bank_delta))
				gs.bank_engine.accounts [account_id] ["balance"] = float(new_balance)
				gs.bank_engine.accounts [account_id] ["updated_at_ms"] = int(Time.get_ticks_msec())

				if gs.bank_engine.has_method("_sync_actor_money_mirror"):
					gs.bank_engine.call("_sync_actor_money_mirror", actor)
				else:
					actor.bank_balance = new_balance

				bank_engine_report = {
					"success": true,
					"mode": "direct_bank_account_delta",
					"account_id": account_id
				}
		elif gs.bank_engine.has_method("request_actor_bank_action"):
			bank_engine_report = gs.bank_engine.request_actor_bank_action(actor, {
				"action": "credit_cash" if bank_delta > 0 else "debit_cash",
				"amount": abs(bank_delta),
				"currency": "USD",
				"reason": str(contract.get("request", "pending_contract_resolution")),
				"contract_id": str(contract.get("id", contract.get("contract_id", ""))),
				"option_id": str(option.get("id", ""))
			}, {
				"source": "scenario_runtime_contract_resolution",
				"contract_id": str(contract.get("id", contract.get("contract_id", ""))),
				"option_id": str(option.get("id", ""))
			})
			actor.bank_balance = new_balance
	else:
		actor.bank_balance = new_balance

	if int(actor.bank_balance) != new_balance:
		actor.bank_balance = new_balance

	return {
		"success": true,
		"actor_id": actor_id,
		"bank_delta": int(bank_delta),
		"previous_balance": previous_balance,
		"balance": new_balance,
		"new_balance": new_balance,
		"balance_text": "Bank balance: $%d" % new_balance,
		"contract_id": str(contract.get("id", contract.get("contract_id", ""))),
		"option_id": str(option.get("id", "")),
		"bank_engine_report": bank_engine_report.duplicate(true)
	}
func _runtime_actor_by_id(actor_id: int) -> Person:
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

func _apply_loan_acceptance(contract: Dictionary, _option: Dictionary) -> Dictionary:
	var amount: int = max(0, int(contract.get("amount", 0)))
	var target_id: int = int(contract.get("target_id", contract.get("target", -1)))
	var issuer_id: int = int(contract.get("issuer_id", contract.get("issuer", -1)))

	var lender: Person = null
	var borrower: Person = null

	if gs != null:
		if gs.player != null and int(gs.player.id) == target_id:
			lender = gs.player
		elif gs.has_method("get_npc_by_id"):
			lender = gs.get_npc_by_id(target_id)

		if gs.has_method("get_npc_by_id"):
			borrower = gs.get_npc_by_id(issuer_id)

	if lender != null and amount > 0:
		lender.bank_balance = max(0, int(lender.bank_balance) - amount)
	if borrower != null and amount > 0:
		borrower.bank_balance = int(borrower.bank_balance) + amount

	var loan_contract: Dictionary = contract.duplicate(true)
	loan_contract ["id"] = "loan_%s_%d" % [str(contract.get("id", "contract")), int(Time.get_ticks_msec())]
	loan_contract ["schema"] = "eralife.loan_contract"
	loan_contract ["request"] = "repayment"
	loan_contract ["category"] = "finance"
	loan_contract ["state"] = "active_obligation"
	loan_contract ["requires_attention"] = false
	loan_contract ["title"] = "Loan repayment owed"
	loan_contract ["overview"] = "A loan of $%d is now owed back." % amount
	loan_contract ["created_at_ms"] = int(Time.get_ticks_msec())
	active_popup_contracts [loan_contract ["id"]] = loan_contract

	return {
		"success": true,
		"text": "I loaned $%d." % amount,
		"popup_title": "Loan Created",
		"popup_text": "You gave them $%d. A repayment contract now exists in reality." % amount,
		"popup_footer": "Tap anywhere to continue.",
		"created_contract_id": str(loan_contract ["id"])
	}


func _option_for_contract(contract: Dictionary, option_id: String) -> Dictionary:
	var options: Array = _safe_array(contract.get("response_options", []))
	for raw_option in options:
		if typeof(raw_option) != TYPE_DICTIONARY:
			continue
		var option: Dictionary = raw_option as Dictionary
		if str(option.get("id", "")).strip_edges() == option_id:
			return option.duplicate(true)
	return {
		"id": option_id,
		"label": option_id.capitalize(),
		"resolution": option_id
	}


func _sort_pending_contracts(a: Dictionary, b: Dictionary) -> bool:
	var urgency_a: float = float(a.get("sort_urgency", a.get("urgency", 0.0)))
	var urgency_b: float = float(b.get("sort_urgency", b.get("urgency", 0.0)))
	if urgency_a == urgency_b:
		return int(a.get("created_at_ms", 0)) < int(b.get("created_at_ms", 0))
	return urgency_a > urgency_b


func _commit_state() -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}









	gs.scenario_state [
		"active_popup_contracts"
	] = active_popup_contracts

	gs.scenario_state [
		"resolved_popup_contracts"
	] = resolved_popup_contracts

	gs.scenario_state [
		"archived_popup_contracts"
	] = archived_popup_contracts

	gs.scenario_state [
		"popup_contract_sequence"
	] = popup_contract_sequence


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(value: Variant) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return (value as Array).duplicate(true)
	return []