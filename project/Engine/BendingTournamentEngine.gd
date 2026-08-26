extends Resource
class_name BendingTournamentEngine

const CONTRACT_SCHEMA:= "eralife.bending_tournament_engine_contract"
const CONTRACT_VERSION:= 1
const STATE_KEY:= "bending_tournament_engine_state"
const WORLD_STATE_KEY:= "bending_world_championship"

var gs
var active_contract: Dictionary = {}
var last_contract_report: Dictionary = {}
var last_runtime_report: Dictionary = {}


func _init(_gs = null, contract: Dictionary = {}) -> void:
	gs = _gs
	set_contract(contract)


func set_contract(contract: Dictionary = {}) -> Dictionary:
	active_contract = _default_contract()
	if typeof(contract) == TYPE_DICTIONARY and not contract.is_empty():
		active_contract = _merge_dict(active_contract, contract)

	last_contract_report = {
		"schema": "eralife.bending_tournament_contract_set_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"contract_id": str(active_contract.get("id", "default_bending_tournament_engine_contract")),
		"set_at_ms": int(Time.get_ticks_msec())
	}

	return last_contract_report.duplicate(true)


func export_state() -> Dictionary:
	return {
		"schema": "eralife.bending_tournament_engine_state",
		"version": CONTRACT_VERSION,
		"active_contract": active_contract.duplicate(true),
		"last_contract_report": last_contract_report.duplicate(true),
		"last_runtime_report": last_runtime_report.duplicate(true),
		"exported_at_ms": int(Time.get_ticks_msec())
	}


func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "BendingTournamentEngine import_state expected Dictionary."
		}

	var contract_raw: Variant = data.get("active_contract", {})
	if typeof(contract_raw) == TYPE_DICTIONARY:
		active_contract = _merge_dict(_default_contract(), contract_raw)
	else:
		active_contract = _default_contract()

	var contract_report_raw: Variant = data.get("last_contract_report", {})
	if typeof(contract_report_raw) == TYPE_DICTIONARY:
		last_contract_report = contract_report_raw.duplicate(true)

	var runtime_report_raw: Variant = data.get("last_runtime_report", {})
	if typeof(runtime_report_raw) == TYPE_DICTIONARY:
		last_runtime_report = runtime_report_raw.duplicate(true)

	return {
		"success": true,
		"imported_at_ms": int(Time.get_ticks_msec())
	}


func yearly_tick(_payload:= {}) -> void:
	if gs == null:
		return

	var state: Dictionary = _world_state()
	var year_value: int = _current_year()

	if int(state.get("last_bending_tournament_engine_tick_year", -999999)) == year_value:
		return

	var reports: Array = []
	if bool(_runtime_policy().get("auto_settle_stale_player_tournaments", true)):
		reports = _auto_settle_stale_tournaments(year_value)

	state = _world_state()
	state ["last_bending_tournament_engine_tick_year"] = year_value
	state ["last_bending_tournament_engine_reports"] = reports
	_commit_world_state(state)

	last_runtime_report = {
		"schema": "eralife.bending_tournament_yearly_tick_report",
		"version": CONTRACT_VERSION,
		"year": year_value,
		"auto_settled_count": reports.size(),
		"reports": reports.duplicate(true),
		"updated_at_ms": int(Time.get_ticks_msec())
	}


func enter_world_championship(actor: Person, options: Dictionary = {}) -> Dictionary:
	if gs == null or gs.bending_engine == null:
		return {
			"success": false,
			"popup_title": "Bending World Championship",
			"popup_text": "BendingEngine is unavailable.",
			"popup_footer": "Tap anywhere to continue."
		}

	if not gs.bending_engine.has_method("enter_bending_world_championship"):
		return {
			"success": false,
			"popup_title": "Bending World Championship",
			"popup_text": "BendingEngine.enter_bending_world_championship() is unavailable.",
			"popup_footer": "Tap anywhere to continue."
		}

	return gs.bending_engine.enter_bending_world_championship(actor, options)


func advance_world_championship_round(actor: Person, options: Dictionary = {}) -> Dictionary:
	if gs == null or gs.bending_engine == null:
		return {
			"success": false,
			"popup_title": "Bending World Championship",
			"popup_text": "BendingEngine is unavailable.",
			"popup_footer": "Tap anywhere to continue."
		}

	if not gs.bending_engine.has_method("advance_bending_world_championship_round"):
		return {
			"success": false,
			"popup_title": "Bending World Championship",
			"popup_text": "BendingEngine.advance_bending_world_championship_round() is unavailable.",
			"popup_footer": "Tap anywhere to continue."
		}

	return gs.bending_engine.advance_bending_world_championship_round(actor, options)


func player_entry_gate(actor: Person, division: String, options: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {
			"allowed": false,
			"reason": "missing_actor",
			"popup_title": "Bending World Championship",
			"popup_text": "No bender was selected.",
			"popup_footer": "Tap anywhere to continue."
		}

	var clean_division: String = str(division).strip_edges().to_lower()
	var year_value: int = int(options.get("tournament_year", _current_year()))
	var tournament: Dictionary = _safe_dictionary(options.get("tournament", {}))
	var tournament_id: String = str(options.get("tournament_id", tournament.get("id", ""))).strip_edges()

	if tournament_id == "":
		tournament_id = _tournament_id_for_division(clean_division, year_value)

	var state: Dictionary = _world_state()
	var signals: Dictionary = _safe_dictionary(state.get("annual_player_entry_signals", {}))
	var actor_id: int = int(actor.id)

	var existing_signal: Dictionary = _safe_dictionary(signals.get(tournament_id, {}))
	if not existing_signal.is_empty():
		var signal_actor_id: int = int(existing_signal.get("actor_id", -1))
		var signal_actor_name: String = str(existing_signal.get("actor_name", "another controlled bender"))

		if signal_actor_id == actor_id:
			return {
				"allowed": true,
				"reason": "same_actor_continuing",
				"tournament_id": tournament_id,
				"signal": existing_signal.duplicate(true),
				"entry_button_label": "Continue Bending World Championship",
				"entry_button_disabled": false
			}

		return {
			"allowed": false,
			"reason": "annual_player_entry_already_started",
			"tournament_id": tournament_id,
			"signal": existing_signal.duplicate(true),
			"entry_button_label": "Tournament Already Started",
			"entry_button_disabled": true,
			"entry_button_tooltip": "%s already started this year's %s. Switch back to them or wait until next year." % [
				signal_actor_name,
				str(existing_signal.get("label", _division_label(clean_division)))
			],
			"popup_title": "Tournament Already Started",
			"popup_text": "%s already started this year's %s.\n\nYou cannot switch to another adult and enter a second controlled run in the same yearly bracket." % [
				signal_actor_name,
				str(existing_signal.get("label", _division_label(clean_division)))
			],
			"popup_footer": "Tap anywhere to continue."
		}

	var tournament_player_actor_id: int = int(tournament.get("player_entry_actor_id", -1))
	if tournament_player_actor_id > 0 and tournament_player_actor_id != actor_id:
		return {
			"allowed": false,
			"reason": "tournament_player_entry_actor_mismatch",
			"tournament_id": tournament_id,
			"entry_button_label": "Tournament Already Started",
			"entry_button_disabled": true,
			"popup_title": "Tournament Already Started",
			"popup_text": "This yearly bracket already has a controlled player entry.\n\nSwitch back to that bender or wait until next year.",
			"popup_footer": "Tap anywhere to continue."
		}

	return {
		"allowed": true,
		"reason": "available",
		"tournament_id": tournament_id,
		"entry_button_label": "Enter Bending World Championship as %s" % str(actor.first_name),
		"entry_button_disabled": false
	}


func mark_player_tournament_started(actor: Person, tournament: Dictionary, options: Dictionary = {}) -> Dictionary:
	if actor == null or tournament.is_empty():
		return {
			"success": false,
			"reason": "missing_actor_or_tournament"
		}

	var state: Dictionary = _world_state()
	var signals: Dictionary = _safe_dictionary(state.get("annual_player_entry_signals", {}))
	var entry_state: Dictionary = _safe_dictionary(state.get("player_entry_state", {}))
	var tournaments: Dictionary = _safe_dictionary(state.get("tournaments", {}))

	var tournament_id: String = str(tournament.get("id", options.get("tournament_id", ""))).strip_edges()
	if tournament_id == "":
		return {
			"success": false,
			"reason": "missing_tournament_id"
		}

	var year_value: int = int(tournament.get("year", options.get("tournament_year", _current_year())))
	var division: String = str(tournament.get("requested_division", tournament.get("division", options.get("division", "")))).strip_edges().to_lower()
	var runtime_division: String = str(tournament.get("division", division)).strip_edges().to_lower()
	var actor_name: String = _person_label(actor)
	var entry_affiliation: String = str(options.get("entry_affiliation", "solo")).strip_edges().to_lower()
	var dojo_membership: Dictionary = {}

	if gs != null and "bending_dojo_engine" in gs and gs.bending_dojo_engine != null:
		if gs.bending_dojo_engine.has_method("get_actor_dojo_membership"):
			dojo_membership = gs.bending_dojo_engine.get_actor_dojo_membership(actor)

	if entry_affiliation == "dojo" and dojo_membership.is_empty():
		entry_affiliation = "solo"

	var entry_signal: Dictionary = {
		"schema": "eralife.bending_tournament_player_entry_signal",
		"version": CONTRACT_VERSION,
		"tournament_id": tournament_id,
		"year": year_value,
		"division": division,
		"runtime_division": runtime_division,
		"label": str(tournament.get("label", _division_label(runtime_division))),
		"actor_id": int(actor.id),
		"actor_name": actor_name,
		"started": true,
		"started_at_ms": int(Time.get_ticks_msec()),
		"source": str(options.get("source", "player_entry")),
		"entry_affiliation": entry_affiliation,
		"dojo_id": str(dojo_membership.get("dojo_id", "")) if entry_affiliation == "dojo" else "",
		"dojo_name": str(dojo_membership.get("dojo_name", "")) if entry_affiliation == "dojo" else ""
	}

	signals [tournament_id] = entry_signal.duplicate(true)
	entry_state [tournament_id] = entry_signal.duplicate(true)

	if tournaments.has(tournament_id):
		var committed_tournament: Dictionary = _safe_dictionary(tournaments.get(tournament_id, {}))
		committed_tournament ["player_entry_started"] = true
		committed_tournament ["player_entry_actor_id"] = int(actor.id)
		committed_tournament ["player_entry_actor_name"] = actor_name
		committed_tournament ["player_entry_signal"] = entry_signal.duplicate(true)
		committed_tournament ["player_entry_affiliation"] = entry_affiliation
		committed_tournament ["player_entry_dojo_id"] = str(entry_signal.get("dojo_id", ""))
		committed_tournament ["player_entry_dojo_name"] = str(entry_signal.get("dojo_name", ""))
		tournaments [tournament_id] = committed_tournament

	state ["annual_player_entry_signals"] = signals
	state ["player_entry_state"] = entry_state
	state ["tournaments"] = tournaments
	state ["last_player_entry_signal"] = entry_signal.duplicate(true)
	_commit_world_state(state)

	last_runtime_report = {
		"schema": "eralife.bending_tournament_player_entry_mark_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"signal": entry_signal.duplicate(true)
	}

	return last_runtime_report.duplicate(true)


func decorate_hub_payload(actor: Person, payload: Dictionary) -> Dictionary:
	var out: Dictionary = payload.duplicate(true)
	if actor == null:
		return out

	var division: String = str(out.get("division", "")).strip_edges().to_lower()
	var tournament: Dictionary = _safe_dictionary(out.get("tournament", {}))
	var actor_status: Dictionary = _safe_dictionary(out.get("actor_tournament_status", {}))
	var actor_status_key: String = str(actor_status.get("status", "none")).strip_edges().to_lower()

	var gate: Dictionary = player_entry_gate(actor, division, {
		"source": "hub_payload",
		"tournament": tournament
	})

	out ["annual_entry_signal"] = gate.duplicate(true)

	if not bool(gate.get("allowed", true)) and actor_status_key in ["none", "not_entered"]:
		out ["entry_button_label"] = str(gate.get("entry_button_label", "Tournament Already Started"))
		out ["entry_button_disabled"] = true
		out ["entry_button_tooltip"] = str(gate.get("entry_button_tooltip", gate.get("popup_text", "This yearly tournament already has a controlled entry.")))

	return out


func _auto_settle_stale_tournaments(current_year: int) -> Array:
	var reports: Array = []
	var state: Dictionary = _world_state()
	var tournaments: Dictionary = _safe_dictionary(state.get("tournaments", {}))

	for raw_tournament_id in tournaments.keys():
		var tournament_id: String = str(raw_tournament_id)
		var tournament: Dictionary = _safe_dictionary(tournaments.get(tournament_id, {}))
		if tournament.is_empty():
			continue

		var tournament_year: int = int(tournament.get("year", current_year))
		if tournament_year >= current_year:
			continue

		if str(tournament.get("status", "")).strip_edges().to_lower() != "active":
			continue

		if gs == null or gs.bending_engine == null:
			continue
		if not gs.bending_engine.has_method("_settle_bending_cpu_tournament"):
			continue

		gs.bending_engine.call("_settle_bending_cpu_tournament", tournament_id, -1, {
			"source": "bending_tournament_engine_stale_auto_progress",
			"stale_year": tournament_year,
			"current_year": current_year
		})

		reports.append({
			"tournament_id": tournament_id,
			"year": tournament_year,
			"current_year": current_year,
		})

	return reports


func _default_contract() -> Dictionary:
	return {
		"schema": CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": "default_bending_tournament_engine_contract",
		"runtime_policy": {
			"auto_settle_stale_player_tournaments": true,
		},
		"entry_signal_policy": {
			"state_key": "annual_player_entry_signals",
			"signal_scope": "tournament_id",
		}
	}


func _runtime_policy() -> Dictionary:
	return _safe_dictionary(active_contract.get("runtime_policy", {}))


func _world_state() -> Dictionary:
	if gs == null:
		return {}

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var raw_state: Variant = gs.scenario_state.get(WORLD_STATE_KEY, {})
	var state: Dictionary = raw_state if typeof(raw_state) == TYPE_DICTIONARY else {}

	if state.is_empty():
		state = {
			"schema": "eralife.bending_world_championship_state",
			"version": 8,
			"created_year": _current_year(),
			"tournaments": {},
			"player_entry_state": {},
			"annual_player_entry_signals": {},
			"last_report": {}
		}

	state ["schema"] = str(state.get("schema", "eralife.bending_world_championship_state"))
	state ["version"] = max(8, int(state.get("version", 1)))

	if not state.has("tournaments") or typeof(state.get("tournaments")) != TYPE_DICTIONARY:
		state ["tournaments"] = {}
	if not state.has("player_entry_state") or typeof(state.get("player_entry_state")) != TYPE_DICTIONARY:
		state ["player_entry_state"] = {}
	if not state.has("annual_player_entry_signals") or typeof(state.get("annual_player_entry_signals")) != TYPE_DICTIONARY:
		state ["annual_player_entry_signals"] = {}
	if not state.has("last_report") or typeof(state.get("last_report")) != TYPE_DICTIONARY:
		state ["last_report"] = {}

	_commit_world_state(state)
	return state


func _commit_world_state(state: Dictionary) -> void:
	if gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	gs.scenario_state [WORLD_STATE_KEY] = state


func _tournament_id_for_division(division: String, year_value: int) -> String:
	if gs != null and gs.bending_engine != null and gs.bending_engine.has_method("_bending_tournament_id_for_division"):
		return str(gs.bending_engine.call("_bending_tournament_id_for_division", division, year_value))
	return "%s_%d" % [str(division).strip_edges().to_lower(), int(year_value)]


func _division_label(division: String) -> String:
	var clean_division: String = str(division).strip_edges().to_lower()
	match clean_division:
		"youth":
			return "Youth Bending World Championship"
		"adult":
			return "Adult Bending World Championship"
		"masters":
			return "Tournament of Champions"
		"elder_male":
			return "Elder Men's Bending World Championship"
		"elder_female":
			return "Elder Women's Bending World Championship"
		"elder":
			return "Elder Bending World Championship"
		"agni_kai":
			return "Agni Kai Championship of Unbreakable Fire"
		_:
			return "Bending World Championship"


func _person_label(actor: Person) -> String:
	if actor == null:
		return "Unknown"
	return ("%s %s" % [str(actor.first_name), str(actor.last_name)]).strip_edges()


func _current_year() -> int:
	if gs == null:
		return 0
	return int(gs.year)


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