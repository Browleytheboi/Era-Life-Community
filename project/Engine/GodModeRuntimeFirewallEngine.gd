extends Resource
class_name GodModeRuntimeFirewallEngine

const ENGINE_STATE_SCHEMA:= "eralife.god_mode_runtime_firewall_engine_state"
const CONTRACT_VERSION:= 1

const FORBIDDEN_RUNTIME_KEYS:= [
	"god_mode_capsule_entry_handoff_active",
	"god_mode_shell_first_handoff_requested",
	"god_mode_handoff_cover_release_pending",
	"god_mode_atomic_shell_handoff_active",
	"god_mode_cover_release_waiting_for_atomic_playable_ui",
	"god_mode_cover_keeps_full_panel_visible_until_live_frame",
	"god_mode_defer_cover_release_until_live_frame",
	"god_mode_live_surface_leak_quarantine_active",
	"god_mode_panel_may_process",
	"god_mode_panel_may_reassert_visibility",
	"god_mode_panel_may_hold_visual_authority",
	"god_mode_panel_may_hide_live_ui",
	"god_mode_panel_is_runtime_system",
	"main_menu_surface_active",
	"startup_intro_runtime_continue_pending",
	"startup_intro_sequence_runner_active",
	"startup_intro_loading_reveal_active"
]

var gs
var severed: bool = false
var sever_reason: String = ""
var severed_at_ms: int = 0
var confession_log: Array = []
var last_report: Dictionary = {}


func _init(_gs = null):
	gs = _gs
	_ensure_state()


func _ensure_state() -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	severed = bool(gs.scenario_state.get("god_mode_runtime_firewall_severed", severed))
	sever_reason = str(gs.scenario_state.get("god_mode_runtime_firewall_reason", sever_reason))
	severed_at_ms = int(gs.scenario_state.get("god_mode_runtime_firewall_severed_at_ms", severed_at_ms))
	confession_log = _safe_array(gs.scenario_state.get("god_mode_runtime_firewall_confession_log", confession_log))
	last_report = _safe_dictionary(gs.scenario_state.get("god_mode_runtime_firewall_last_report", last_report))


func sever(reason: String = "god_mode_panel_contract_emitted", context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	severed = true
	sever_reason = reason
	severed_at_ms = int(Time.get_ticks_msec())

	last_report = {
		"success": true,
		"mode": "god_mode_runtime_severed",
		"reason": reason,
		"severed": true,
		"severed_at_ms": severed_at_ms,
		"context": context.duplicate(true)
	}

	_commit_state()
	return last_report.duplicate(true)


func reset_for_intentional_god_mode_return(reason: String = "return_to_god_mode") -> Dictionary:
	_ensure_state()

	severed = false
	sever_reason = ""
	severed_at_ms = 0

	last_report = {
		"success": true,
		"mode": "god_mode_runtime_firewall_reset",
		"reason": reason,
		"reset_at_ms": int(Time.get_ticks_msec())
	}

	_commit_state()
	return last_report.duplicate(true)


func is_severed() -> bool:
	_ensure_state()
	return severed


func allow_god_mode_runtime(source: String, action: String = "runtime_check") -> bool:
	_ensure_state()

	if not severed:
		return true

	confess(source, action, "god_mode_runtime_severed", true)
	return false


func filter_runtime_bool(key: String, value: bool, source: String = "runtime_bool") -> bool:
	_ensure_state()

	var clean_key: String = str(key).strip_edges()
	if clean_key == "":
		return value

	if severed and FORBIDDEN_RUNTIME_KEYS.has(clean_key):
		if value:
			confess(source, "filtered_runtime_bool_%s" % clean_key, sever_reason, true)
		return false

	return value


func scenario_bool(state: Dictionary, key: String, fallback: bool = false, source: String = "scenario_read") -> bool:
	var value: bool = fallback

	if typeof(state) == TYPE_DICTIONARY:
		value = bool(state.get(key, fallback))

	return filter_runtime_bool(key, value, source)


func confess(source: String, action: String, reason: String, blocked: bool = true) -> void:
	var row: Dictionary = {
		"source": source,
		"action": action,
		"reason": reason,
		"blocked": blocked,
		"severed": severed,
		"sever_reason": sever_reason,
		"at_ms": int(Time.get_ticks_msec())
	}

	confession_log.append(row)
	if confession_log.size() > 160:
		confession_log = confession_log.slice(confession_log.size() - 160, confession_log.size())

	EraLog.truth("GOD_MODE_RUNTIME_FIREWALL|source=%s|action=%s|reason=%s|blocked=%s" % [
		source,
		action,
		reason,
		str(blocked)
	])

	_commit_state()


func _commit_state() -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	gs.scenario_state ["god_mode_runtime_firewall_severed"] = severed
	gs.scenario_state ["god_mode_runtime_firewall_reason"] = sever_reason
	gs.scenario_state ["god_mode_runtime_firewall_severed_at_ms"] = severed_at_ms
	gs.scenario_state ["god_mode_runtime_firewall_confession_log"] = confession_log.duplicate(true)
	gs.scenario_state ["god_mode_runtime_firewall_last_report"] = last_report.duplicate(true)


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(value: Variant) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return (value as Array).duplicate(true)
	return []