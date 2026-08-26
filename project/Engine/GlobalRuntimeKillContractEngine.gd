extends Resource
class_name GlobalRuntimeKillContractEngine

const ENGINE_SCHEMA:= "eralife.global_runtime_kill_contract_engine"
const CONTRACT_VERSION:= 1
const MAX_LEDGER:= 120
const MAX_DOMAIN_LEDGER:= 120

const RUNTIME_DOMAIN_CINEMATIC:= "cinematic"
const RUNTIME_DOMAIN_MAIN_MENU:= "main_menu"
const RUNTIME_DOMAIN_TRANSITION:= "transition"
const RUNTIME_DOMAIN_SIMULATION:= "simulation"

var gs: GameState = null
var runtime_domain: String = RUNTIME_DOMAIN_CINEMATIC
var runtime_domain_reason: String = "boot"
var runtime_domain_entered_at_ms: int = 0
var runtime_domain_guard_until_ms: int = 0
var runtime_domain_context: Dictionary = {}
var runtime_domain_ledger: Array = []

var playable_shell_authority_locked: bool = false
var playable_shell_authority_reason: String = ""
var playable_shell_authority_acquired_at_ms: int = 0
var playable_shell_control_grace_until_ms: int = 0
var player_age_up_window_active: bool = false
var player_age_up_window_reason: String = ""
var player_age_up_window_until_ms: int = 0
var denied_ledger: Array = []
var last_report: Dictionary = {}


func _init(_gs: GameState = null):
	bind_game_state(_gs)


func bind_game_state(_gs: GameState, publish_on_bind: bool = true) -> void:
	if gs == _gs:
		if publish_on_bind:
			_ensure_state()
		return

	gs = _gs
	_ensure_state()

	if publish_on_bind:
		_publish_state("bind_game_state")
func bind_game_state_quiet(_gs: GameState) -> void:
	bind_game_state(_gs, false)

func set_runtime_domain(domain: String, reason: String = "runtime_domain", context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	var clean_domain: String = _normalize_runtime_domain(domain)
	var clean_reason: String = str(reason).strip_edges()
	if clean_reason == "":
		clean_reason = "runtime_domain"

	var now_ms: int = int(Time.get_ticks_msec())
	var guard_ms: int = max(0, int(context.get("guard_ms", 0)))

	runtime_domain = clean_domain
	runtime_domain_reason = clean_reason
	runtime_domain_entered_at_ms = now_ms
	runtime_domain_guard_until_ms = now_ms + guard_ms if guard_ms > 0 else 0
	runtime_domain_context = context.duplicate(true)

	var report: Dictionary = _report(true, "runtime_domain_set", {
		"runtime_domain": runtime_domain,
		"reason": clean_reason,
		"context": context.duplicate(true),
		"entered_at_ms": runtime_domain_entered_at_ms,
		"guard_until_ms": runtime_domain_guard_until_ms,
		"simulation_runtime_allowed": runtime_domain == RUNTIME_DOMAIN_SIMULATION,
		"cinematic_runtime_allowed": runtime_domain == RUNTIME_DOMAIN_CINEMATIC,
		"main_menu_runtime_allowed": runtime_domain == RUNTIME_DOMAIN_MAIN_MENU,
		"transition_runtime_allowed": runtime_domain == RUNTIME_DOMAIN_TRANSITION
	})

	_record_runtime_domain(report)
	_publish_state(clean_reason)
	return report


func enter_cinematic_runtime(reason: String = "cinematic_runtime", context: Dictionary = {}) -> Dictionary:
	return set_runtime_domain(RUNTIME_DOMAIN_CINEMATIC, reason, context)


func enter_main_menu_runtime(reason: String = "main_menu_runtime", context: Dictionary = {}) -> Dictionary:
	return set_runtime_domain(RUNTIME_DOMAIN_MAIN_MENU, reason, context)


func enter_transition_runtime(reason: String = "transition_runtime", context: Dictionary = {}) -> Dictionary:
	return set_runtime_domain(RUNTIME_DOMAIN_TRANSITION, reason, context)


func enter_simulation_runtime(reason: String = "simulation_runtime", context: Dictionary = {}) -> Dictionary:
	return set_runtime_domain(RUNTIME_DOMAIN_SIMULATION, reason, context)


func current_runtime_domain() -> String:
	return _normalize_runtime_domain(runtime_domain)


func simulation_runtime_active() -> bool:
	return _normalize_runtime_domain(runtime_domain) == RUNTIME_DOMAIN_SIMULATION


func prelife_runtime_active() -> bool:
	var clean_domain: String = _normalize_runtime_domain(runtime_domain)
	return clean_domain == RUNTIME_DOMAIN_CINEMATIC \
or clean_domain == RUNTIME_DOMAIN_MAIN_MENU \
or clean_domain == RUNTIME_DOMAIN_TRANSITION


func _normalize_runtime_domain(domain: String) -> String:
	var clean_domain: String = str(domain).strip_edges().to_lower()
	if clean_domain == "":
		return RUNTIME_DOMAIN_CINEMATIC

	if clean_domain in [
		RUNTIME_DOMAIN_CINEMATIC,
		RUNTIME_DOMAIN_MAIN_MENU,
		RUNTIME_DOMAIN_TRANSITION,
		RUNTIME_DOMAIN_SIMULATION
	]:
		return clean_domain

	return RUNTIME_DOMAIN_TRANSITION


func _record_runtime_domain(report: Dictionary) -> void:
	runtime_domain_ledger.append(report.duplicate(true))
	if runtime_domain_ledger.size() > MAX_DOMAIN_LEDGER:
		runtime_domain_ledger = runtime_domain_ledger.slice(runtime_domain_ledger.size() - MAX_DOMAIN_LEDGER, runtime_domain_ledger.size())
func acquire_playable_shell_authority(reason: String = "playable_shell_visible", context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	var now_ms: int = int(Time.get_ticks_msec())
	var control_grace_ms: int = int(context.get("control_grace_ms", 12000))
	if control_grace_ms < 12000:
		control_grace_ms = 12000

	playable_shell_authority_locked = true
	playable_shell_authority_reason = reason
	playable_shell_authority_acquired_at_ms = now_ms
	playable_shell_control_grace_until_ms = now_ms + control_grace_ms
	player_age_up_window_active = false
	player_age_up_window_reason = ""
	player_age_up_window_until_ms = 0

	var report: Dictionary = _report(true, "playable_shell_authority_acquired", {
		"reason": reason,
		"context": context.duplicate(true),
		"playable_shell_authority_acquired_at_ms": playable_shell_authority_acquired_at_ms,
		"playable_shell_control_grace_until_ms": playable_shell_control_grace_until_ms,
	})

	_publish_state(reason)
	return report

func release_for_player_initiated_age_up(reason: String = "age_up_button", context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	player_age_up_window_active = true
	player_age_up_window_reason = reason
	player_age_up_window_until_ms = int(Time.get_ticks_msec()) + int(context.get("age_up_window_ms", 45000))

	var report: Dictionary = _report(true, "player_age_up_window_opened", {
		"reason": reason,
		"context": context.duplicate(true),
		"player_age_up_window_until_ms": player_age_up_window_until_ms
	})

	_publish_state(reason)
	return report


func relock_after_player_action(reason: String = "player_action_complete", context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	playable_shell_authority_locked = true
	playable_shell_authority_reason = reason
	player_age_up_window_active = false
	player_age_up_window_reason = ""
	player_age_up_window_until_ms = 0

	var report: Dictionary = _report(true, "playable_shell_authority_relocked", {
		"reason": reason,
		"context": context.duplicate(true)
	})

	_publish_state(reason)
	return report


func request_claim(claim_type: String, source: String, reason: String = "", context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	var clean_claim: String = str(claim_type).strip_edges().to_lower()
	var clean_source: String = str(source).strip_edges()
	var clean_reason: String = str(reason).strip_edges()
	var now_ms: int = int(Time.get_ticks_msec())

	if clean_reason == "":
		clean_reason = clean_source

	var player_age_up_allowed: bool = _player_age_up_context_allows(context, now_ms)
	if player_age_up_allowed:
		return _report(true, "runtime_claim_allowed_player_age_up_before_domain_gate", {
			"claim_type": clean_claim,
			"source": clean_source,
			"reason": clean_reason,
			"runtime_domain": runtime_domain,
			"context": context.duplicate(true),
			"player_age_up_window_active": player_age_up_window_active,
			"player_age_up_window_reason": player_age_up_window_reason,
			"player_age_up_window_until_ms": player_age_up_window_until_ms,
			"commit_required_before_log": true
		})

	var domain_report: Dictionary = _runtime_domain_claim_report(clean_claim, clean_source, clean_reason, context, now_ms)
	if not domain_report.is_empty():
		return domain_report

	if not playable_shell_authority_locked:
		return _report(true, "runtime_claim_allowed_no_shell_lock", {
			"claim_type": clean_claim,
			"source": clean_source,
			"reason": clean_reason,
			"runtime_domain": runtime_domain,
			"context": context.duplicate(true)
		})

	if player_age_up_allowed:
		return _report(true, "runtime_claim_allowed_player_age_up", {
			"claim_type": clean_claim,
			"source": clean_source,
			"reason": clean_reason,
			"runtime_domain": runtime_domain,
			"context": context.duplicate(true)
		})

	var background_only: bool = bool(context.get("background_only", false))
	var blocks_ui: bool = bool(context.get("blocks_ui", true))
	var state_only: bool = bool(context.get("state_only", false))
	var renderer_only: bool = bool(context.get("renderer_only", false))
	var ui_safe_microtask: bool = bool(context.get("ui_safe_microtask", false))
	var microtask_budget: int = int(context.get("microtask_budget", 999))
	var inside_control_grace: bool = playable_shell_control_grace_until_ms > 0 and now_ms < playable_shell_control_grace_until_ms

	if clean_claim in ["renderer_frame", "input_read", "audio_runtime"] and renderer_only and not blocks_ui:
		return _report(true, "runtime_claim_allowed_renderer_only", {
			"claim_type": clean_claim,
			"source": clean_source,
			"reason": clean_reason,
			"runtime_domain": runtime_domain,
			"context": context.duplicate(true)
		})

	if clean_claim in ["state_bookkeeping", "contract_bookkeeping"] and state_only and background_only and not blocks_ui:
		return _report(true, "runtime_claim_allowed_state_only_bookkeeping", {
			"claim_type": clean_claim,
			"source": clean_source,
			"reason": clean_reason,
			"runtime_domain": runtime_domain,
			"context": context.duplicate(true)
		})

	if clean_claim in ["background_tail", "background_stream"]:
		if inside_control_grace:
			return _deny(clean_claim, clean_source, "%s_control_grace_denied" % clean_reason, context)

		if background_only and not blocks_ui and ui_safe_microtask and microtask_budget <= 1:
			return _report(true, "runtime_claim_allowed_explicit_microtask", {
				"claim_type": clean_claim,
				"source": clean_source,
				"reason": clean_reason,
				"runtime_domain": runtime_domain,
				"context": context.duplicate(true)
			})

		return _deny(clean_claim, clean_source, "%s_missing_microtask_contract" % clean_reason, context)

	if clean_claim in [
		"loading",
		"busy",
		"input_block",
		"ui_rebuild",
		"runtime_boot",
		"priority_escalation",
		"foreground_tail_work",
		"live_reality_bind",
		"runtime_intent_flush",
		"post_visible_finalization",
		"second_boot",
		"unknown"
	]:
		return _deny(clean_claim, clean_source, clean_reason, context)

	return _deny("unknown", clean_source, "%s_unknown_claim_%s" % [clean_reason, clean_claim], context)
func _runtime_domain_claim_report(clean_claim: String, clean_source: String, clean_reason: String, context: Dictionary, _now_ms: int) -> Dictionary:
	var clean_domain: String = _normalize_runtime_domain(runtime_domain)
	if clean_domain == RUNTIME_DOMAIN_SIMULATION:
		return {}

	var blocks_ui: bool = bool(context.get("blocks_ui", true))
	var renderer_only: bool = bool(context.get("renderer_only", false))
	var background_only: bool = bool(context.get("background_only", false))
	var state_only: bool = bool(context.get("state_only", false))
	var prelife_renderer_only: bool = bool(context.get("prelife_renderer_only", false))
	var transition_allowed: bool = bool(context.get("transition_allowed", false))

	if clean_claim in ["renderer_frame", "input_read", "audio_runtime"] and renderer_only and not blocks_ui:
		return _report(true, "runtime_claim_allowed_prelife_renderer_only", {
			"claim_type": clean_claim,
			"source": clean_source,
			"reason": clean_reason,
			"runtime_domain": clean_domain,
			"context": context.duplicate(true)
		})

	if clean_claim in ["state_bookkeeping", "contract_bookkeeping"] and state_only and background_only and not blocks_ui:
		return _report(true, "runtime_claim_allowed_prelife_state_bookkeeping", {
			"claim_type": clean_claim,
			"source": clean_source,
			"reason": clean_reason,
			"runtime_domain": clean_domain,
			"context": context.duplicate(true)
		})

	if prelife_renderer_only and not blocks_ui:
		return _report(true, "runtime_claim_allowed_prelife_visual", {
			"claim_type": clean_claim,
			"source": clean_source,
			"reason": clean_reason,
			"runtime_domain": clean_domain,
			"context": context.duplicate(true)
		})

	if clean_domain == RUNTIME_DOMAIN_TRANSITION and transition_allowed and not blocks_ui:
		return _report(true, "runtime_claim_allowed_transition_nonblocking", {
			"claim_type": clean_claim,
			"source": clean_source,
			"reason": clean_reason,
			"runtime_domain": clean_domain,
			"context": context.duplicate(true)
		})

	if clean_claim in [
		"background_tail",
		"background_stream",
		"loading",
		"busy",
		"input_block",
		"ui_rebuild",
		"runtime_boot",
		"priority_escalation",
		"foreground_tail_work",
		"live_reality_bind",
		"runtime_intent_flush",
		"post_visible_finalization",
		"second_boot"
	]:
		return _deny_runtime_domain(clean_claim, clean_source, clean_reason, context)

	if bool(context.get("simulation_only", false)) or bool(context.get("requires_simulation_runtime", false)):
		return _deny_runtime_domain(clean_claim, clean_source, clean_reason, context)

	return {}


func _deny_runtime_domain(claim_type: String, source: String, reason: String, context: Dictionary = {}) -> Dictionary:
	var now_ms: int = int(Time.get_ticks_msec())

	var row: Dictionary = _report(false, "runtime_claim_denied_by_runtime_domain", {
		"allowed": false,
		"denied": true,
		"claim_type": claim_type,
		"source": source,
		"reason": reason,
		"runtime_domain": runtime_domain,
		"context": context.duplicate(true),
		"at_ms": now_ms
	})

	denied_ledger.append(row.duplicate(true))
	if denied_ledger.size() > MAX_LEDGER:
		denied_ledger = denied_ledger.slice(denied_ledger.size() - MAX_LEDGER, denied_ledger.size())

	EraLog.truth("GLOBAL_RUNTIME_DOMAIN_DENIED|domain=%s|claim=%s|source=%s|reason=%s|at_ms=%d" % [
		runtime_domain,
		claim_type,
		source,
		reason,
		now_ms
	])

	_publish_state(reason, true)
	return row

func loading_allowed(source: String, reason: String = "", context: Dictionary = {}) -> bool:
	return bool(request_claim("loading", source, reason, context).get("allowed", false))


func busy_allowed(source: String, reason: String = "", context: Dictionary = {}) -> bool:
	return bool(request_claim("busy", source, reason, context).get("allowed", false))


func input_blocking_allowed(source: String, reason: String = "", context: Dictionary = {}) -> bool:
	return bool(request_claim("input_block", source, reason, context).get("allowed", false))


func runtime_boot_allowed(source: String, reason: String = "", context: Dictionary = {}) -> bool:
	return bool(request_claim("runtime_boot", source, reason, context).get("allowed", false))


func ui_rebuild_allowed(source: String, reason: String = "", context: Dictionary = {}) -> bool:
	return bool(request_claim("ui_rebuild", source, reason, context).get("allowed", false))


func priority_escalation_allowed(source: String, reason: String = "", context: Dictionary = {}) -> bool:
	return bool(request_claim("priority_escalation", source, reason, context).get("allowed", false))


func is_shell_locked() -> bool:
	return playable_shell_authority_locked


func current_state(include_ledger: bool = false) -> Dictionary:
	var state: Dictionary = {
		"schema": ENGINE_SCHEMA,
		"version": CONTRACT_VERSION,
		"runtime_domain": runtime_domain,
		"runtime_domain_reason": runtime_domain_reason,
		"runtime_domain_entered_at_ms": runtime_domain_entered_at_ms,
		"runtime_domain_guard_until_ms": runtime_domain_guard_until_ms,
		"runtime_domain_context": runtime_domain_context.duplicate(true),
		"simulation_runtime_active": runtime_domain == RUNTIME_DOMAIN_SIMULATION,
		"prelife_runtime_active": prelife_runtime_active(),
		"playable_shell_authority_locked": playable_shell_authority_locked,
		"playable_shell_authority_reason": playable_shell_authority_reason,
		"playable_shell_authority_acquired_at_ms": playable_shell_authority_acquired_at_ms,
		"playable_shell_control_grace_until_ms": playable_shell_control_grace_until_ms,
		"player_age_up_window_active": player_age_up_window_active,
		"player_age_up_window_reason": player_age_up_window_reason,
		"player_age_up_window_until_ms": player_age_up_window_until_ms,
		"last_report": last_report.duplicate(true),
		"denied_count": denied_ledger.size(),
		"domain_ledger_count": runtime_domain_ledger.size()
	}

	if include_ledger:
		state ["denied_ledger"] = denied_ledger.duplicate(true)
		state ["runtime_domain_ledger"] = runtime_domain_ledger.duplicate(true)

	return state

func _player_age_up_context_allows(context: Dictionary, now_ms: int) -> bool:
	var explicit_age_up: bool = bool(context.get("player_initiated_age_up", false)) \
or bool(context.get("age_up_button_user_initiated", false)) \
or str(context.get("source", "")).strip_edges() == "age_up_button"

	if explicit_age_up:
		return true

	if not player_age_up_window_active:
		return false

	if player_age_up_window_until_ms <= 0:
		return false

	if now_ms > player_age_up_window_until_ms:
		player_age_up_window_active = false
		player_age_up_window_reason = ""
		player_age_up_window_until_ms = 0
		return false

	return true


func _deny(claim_type: String, source: String, reason: String, context: Dictionary = {}) -> Dictionary:
	var now_ms: int = int(Time.get_ticks_msec())

	var row: Dictionary = _report(false, "runtime_claim_denied_after_visible_shell", {
		"allowed": false,
		"denied": true,
		"claim_type": claim_type,
		"source": source,
		"reason": reason,
		"context": context.duplicate(true),
		"playable_shell_authority_locked": playable_shell_authority_locked,
		"playable_shell_authority_reason": playable_shell_authority_reason,
		"at_ms": now_ms
	})

	denied_ledger.append(row.duplicate(true))
	if denied_ledger.size() > MAX_LEDGER:
		denied_ledger = denied_ledger.slice(denied_ledger.size() - MAX_LEDGER, denied_ledger.size())

	EraLog.truth("GLOBAL_RUNTIME_KILL_DENIED|claim=%s|source=%s|reason=%s|shell_locked=%s|age_up_window=%s|at_ms=%d" % [
		claim_type,
		source,
		reason,
		str(playable_shell_authority_locked),
		str(player_age_up_window_active),
		now_ms
	])

	_publish_state(reason, true)
	return row


func _report(success: bool, mode: String, payload: Dictionary = {}) -> Dictionary:
	var row: Dictionary = {
		"success": success,
		"allowed": success,
		"mode": mode,
		"schema": ENGINE_SCHEMA,
		"version": CONTRACT_VERSION,
		"created_at_ms": int(Time.get_ticks_msec())
	}

	for key in payload.keys():
		row [key] = payload [key]

	last_report = row.duplicate(true)
	return row


func _ensure_state() -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}


func _publish_state(reason: String, include_ledger: bool = false) -> void:
	_ensure_state()

	if gs == null:
		return

	var now_ms: int = int(Time.get_ticks_msec())

	gs.scenario_state ["global_runtime_kill_contract_engine_state"] = current_state(include_ledger)
	gs.scenario_state ["global_runtime_kill_contract_engine_reason"] = reason
	gs.scenario_state ["global_runtime_kill_contract_engine_updated_at_ms"] = now_ms

	gs.scenario_state ["global_runtime_domain"] = runtime_domain
	gs.scenario_state ["global_runtime_domain_reason"] = runtime_domain_reason
	gs.scenario_state ["global_runtime_domain_entered_at_ms"] = runtime_domain_entered_at_ms
	gs.scenario_state ["global_runtime_domain_guard_until_ms"] = runtime_domain_guard_until_ms
	gs.scenario_state ["global_runtime_simulation_allowed"] = runtime_domain == RUNTIME_DOMAIN_SIMULATION
	gs.scenario_state ["global_runtime_prelife_domain_active"] = prelife_runtime_active()
	gs.scenario_state ["global_runtime_cinematic_domain_active"] = runtime_domain == RUNTIME_DOMAIN_CINEMATIC
	gs.scenario_state ["global_runtime_main_menu_domain_active"] = runtime_domain == RUNTIME_DOMAIN_MAIN_MENU
	gs.scenario_state ["global_runtime_transition_domain_active"] = runtime_domain == RUNTIME_DOMAIN_TRANSITION

	gs.scenario_state ["global_runtime_after_visible_shell_loading_forbidden"] = playable_shell_authority_locked
	gs.scenario_state ["global_runtime_after_visible_shell_busy_forbidden"] = playable_shell_authority_locked
	gs.scenario_state ["global_runtime_after_visible_shell_input_block_forbidden"] = playable_shell_authority_locked
	gs.scenario_state ["global_runtime_after_visible_shell_boot_forbidden"] = playable_shell_authority_locked