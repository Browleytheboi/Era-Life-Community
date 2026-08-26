extends Resource
class_name CompetitiveRealityRuntime

const CONTRACT_SCHEMA:= "eralife.competitive_reality_runtime_contract"
const CONTRACT_VERSION:= 1
const STATE_SCHEMA:= "eralife.competitive_reality_runtime_state"
const STATE_KEY:= "competitive_reality_runtime_state"
const MAX_LEDGER_SIZE:= 350
const MAX_MEDIA_LEDGER_SIZE:= 220
const MAX_MEMORY_LEDGER_SIZE:= 260

var gs
var active_contract: Dictionary = {}
var contract_registry: Dictionary = {}
var last_contract_report: Dictionary = {}
var last_runtime_report: Dictionary = {}

func _init(_gs = null, contract: Dictionary = {}) -> void:
	gs = _gs
	set_contract(contract)

func set_contract(contract: Dictionary = {}) -> Dictionary:
	active_contract = _default_contract()
	if typeof(contract) == TYPE_DICTIONARY and not contract.is_empty():
		active_contract = _merge_dict(active_contract, contract)
	_bootstrap_contract_registry()
	last_contract_report = {
		"schema": "eralife.competitive_reality_contract_set_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"contract_id": str(active_contract.get("id", "competitive_reality_runtime.default")),
		"registered_contract_count": contract_registry.size(),
		"set_at_ms": int(Time.get_ticks_msec())
	}
	return last_contract_report.duplicate(true)

func bootstrap_default_contracts() -> Dictionary:
	_bootstrap_contract_registry()
	var state: Dictionary = _world_state()
	state ["contract_registry"] = contract_registry.duplicate(true)
	_commit_world_state(state)
	return {
		"success": true,
		"schema": "eralife.competitive_reality_bootstrap_report",
		"version": CONTRACT_VERSION,
		"contract_count": contract_registry.size(),
		"updated_at_ms": int(Time.get_ticks_msec())
	}

func export_state() -> Dictionary:
	return {
		"schema": STATE_SCHEMA,
		"version": CONTRACT_VERSION,
		"active_contract": active_contract.duplicate(true),
		"contract_registry": contract_registry.duplicate(true),
		"world_state": _world_state().duplicate(true),
		"last_contract_report": last_contract_report.duplicate(true),
		"last_runtime_report": last_runtime_report.duplicate(true),
		"exported_at_ms": int(Time.get_ticks_msec())
	}

func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "CompetitiveRealityRuntime import_state expected Dictionary."
		}

	var contract_raw: Variant = data.get("active_contract", {})
	if typeof(contract_raw) == TYPE_DICTIONARY:
		active_contract = _merge_dict(_default_contract(), contract_raw as Dictionary)
	else:
		active_contract = _default_contract()

	var registry_raw: Variant = data.get("contract_registry", {})
	if typeof(registry_raw) == TYPE_DICTIONARY:
		contract_registry = (registry_raw as Dictionary).duplicate(true)
	else:
		contract_registry = {}
	_bootstrap_contract_registry()

	var world_state_raw: Variant = data.get("world_state", {})
	if typeof(world_state_raw) == TYPE_DICTIONARY and not (world_state_raw as Dictionary).is_empty():
		_commit_world_state(_normalize_state(world_state_raw as Dictionary))

	var contract_report_raw: Variant = data.get("last_contract_report", {})
	if typeof(contract_report_raw) == TYPE_DICTIONARY:
		last_contract_report = (contract_report_raw as Dictionary).duplicate(true)

	var runtime_report_raw: Variant = data.get("last_runtime_report", {})
	if typeof(runtime_report_raw) == TYPE_DICTIONARY:
		last_runtime_report = (runtime_report_raw as Dictionary).duplicate(true)

	return {
		"success": true,
		"contract_count": contract_registry.size(),
		"imported_at_ms": int(Time.get_ticks_msec())
	}

func yearly_tick(_payload:= {}) -> void:
	if gs == null:
		return

	var state: Dictionary = _world_state()
	var year_value: int = _current_year()
	if int(state.get("last_yearly_tick_year", -999999)) == year_value:
		return

	var report: Dictionary = {
		"schema": "eralife.competitive_reality_yearly_tick_report",
		"version": CONTRACT_VERSION,
		"year": year_value,
		"media_decay_updates": 0,
		"culture_updates": 0,
		"memory_updates": 0,
		"updated_at_ms": int(Time.get_ticks_msec())
	}

	report ["media_decay_updates"] = _decay_media_heat(state)
	report ["culture_updates"] = _evolve_culture_memory(state)
	report ["memory_updates"] = _evolve_historical_memory(state)

	state ["last_yearly_tick_year"] = year_value
	state ["last_yearly_tick_report"] = report.duplicate(true)
	_commit_world_state(state)

	last_runtime_report = report.duplicate(true)

func register_competition_contract(contract: Dictionary = {}) -> Dictionary:
	if typeof(contract) != TYPE_DICTIONARY or contract.is_empty():
		return {
			"success": false,
			"reason": "Competition contract missing."
		}

	var normalized: Dictionary = _normalize_competition_contract(contract)
	var contract_id: String = str(normalized.get("id", "")).strip_edges()
	if contract_id == "":
		return {
			"success": false,
			"reason": "Competition contract id missing."
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

func record_match(match_contract: Dictionary = {}, participants: Array = [], context: Dictionary = {}) -> Dictionary:
	if gs == null:
		return {
			"success": false,
			"reason": "GameState missing."
		}

	var resolved_contract: Dictionary = _resolve_contract_from_payload(match_contract, context)
	var domain: String = str(resolved_contract.get("domain", context.get("domain", "generic"))).strip_edges().to_lower()
	var competition_id: String = str(resolved_contract.get("id", context.get("competition_id", "generic.competition"))).strip_edges()
	var participant_rows: Array = _normalize_participants(participants, context)

	if participant_rows.is_empty():
		return {
			"success": false,
			"reason": "No participants supplied.",
			"competition_id": competition_id
		}

	var scored_rows: Array = []
	for raw_row in participant_rows:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = raw_row.duplicate(true)
		var actor: Person = _participant_person(row)
		var score_report: Dictionary = record_performance(actor, resolved_contract, _merge_dict(context, row))
		row ["performance_report"] = score_report.duplicate(true)
		row ["score"] = float(score_report.get("score", 0.0))
		scored_rows.append(row)

	var winner_row: Dictionary = _resolve_winner(scored_rows, context)
	var winner_id: int = int(winner_row.get("person_id", -1))
	var winner_name: String = str(winner_row.get("person_name", "Unknown"))

	var match_id: String = str(context.get("match_id", "")).strip_edges()
	if match_id == "":
		match_id = "%s_%d_%d" % [competition_id.replace(".", "_"), _current_year(), int(Time.get_ticks_msec())]

	var audience_report: Dictionary = _resolve_audience_reaction(resolved_contract, scored_rows, context)
	var judgment_report: Dictionary = _resolve_judgment(resolved_contract, scored_rows, winner_row, context)
	var reputation_report: Dictionary = _apply_reputation_shift(resolved_contract, scored_rows, winner_row, audience_report, context)
	var media_packet: Dictionary = _build_media_packet(resolved_contract, winner_row, scored_rows, audience_report, judgment_report, context)
	var memory_packet: Dictionary = _build_historical_memory_packet(resolved_contract, winner_row, scored_rows, media_packet, context)
	var culture_packet: Dictionary = _build_cultural_propagation_packet(resolved_contract, winner_row, scored_rows, media_packet, context)

	var match_row: Dictionary = {
		"schema": "eralife.competitive_match_record",
		"version": CONTRACT_VERSION,
		"match_id": match_id,
		"competition_id": competition_id,
		"domain": domain,
		"year": _current_year(),
		"era": _current_era_key(),
		"participants": scored_rows.duplicate(true),
		"winner_id": winner_id,
		"winner_name": winner_name,
		"audience": audience_report.duplicate(true),
		"judgment": judgment_report.duplicate(true),
		"reputation": reputation_report.duplicate(true),
		"media": media_packet.duplicate(true),
		"historical_memory": memory_packet.duplicate(true),
		"culture": culture_packet.duplicate(true),
		"context": context.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	var state: Dictionary = _world_state()
	_append_limited(state ["match_ledger"], match_row, MAX_LEDGER_SIZE)
	_append_limited(state ["performance_ledger"], scored_rows, MAX_LEDGER_SIZE)
	if not media_packet.is_empty():
		_append_limited(state ["media_ledger"], media_packet, MAX_MEDIA_LEDGER_SIZE)
	if not memory_packet.is_empty():
		_append_limited(state ["historical_memory"], memory_packet, MAX_MEMORY_LEDGER_SIZE)
	if not culture_packet.is_empty():
		_append_limited(state ["cultural_propagation"], culture_packet, MAX_MEMORY_LEDGER_SIZE)

	state ["last_match_report"] = match_row.duplicate(true)
	_commit_world_state(state)

	_emit_world_feed_for_match(match_row)
	_emit_competitive_event("competitive.match.completed", match_row)

	last_runtime_report = match_row.duplicate(true)
	return {
		"success": true,
		"match": match_row.duplicate(true)
	}

func record_performance(actor: Person, competition_contract: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "Actor missing.",
			"score": 0.0
		}

	var resolved_contract: Dictionary = _resolve_contract_from_payload(competition_contract, context)
	var axes: Array = _safe_array(resolved_contract.get("performance_axes", []))
	if axes.is_empty():
		axes = _safe_array(active_contract.get("default_performance_axes", []))

	var score_total: float = 0.0
	var weight_total: float = 0.0
	var axis_reports: Array = []

	for raw_axis in axes:
		if typeof(raw_axis) != TYPE_DICTIONARY:
			continue
		var axis: Dictionary = raw_axis
		var axis_id: String = str(axis.get("id", "")).strip_edges()
		if axis_id == "":
			continue
		var weight: float = max(0.0, float(axis.get("weight", 1.0)))
		var value: float = _resolve_axis_value(actor, axis, context)
		var capped_value: float = clamp(value, float(axis.get("min", 0.0)), float(axis.get("max", 100.0)))
		score_total += capped_value * weight
		weight_total += weight
		axis_reports.append({
			"id": axis_id,
			"value": capped_value,
			"weight": weight,
			"source": str(axis.get("source", axis.get("actor_field", axis.get("payload_key", "contract"))))
		})

	var base_score: float = 0.0
	if weight_total > 0.0:
		base_score = score_total / weight_total

	var variance: float = _performance_variance(resolved_contract, context)
	var final_score: float = clamp(base_score + variance, 0.0, 100.0)

	var performance_row: Dictionary = {
		"schema": "eralife.competitive_performance_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"person_id": int(actor.id),
		"person_name": _person_label(actor),
		"domain": str(resolved_contract.get("domain", "generic")),
		"competition_id": str(resolved_contract.get("id", "")),
		"score": final_score,
		"base_score": base_score,
		"variance": variance,
		"axes": axis_reports.duplicate(true),
		"year": _current_year(),
		"era": _current_era_key(),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	var state: Dictionary = _world_state()
	var profiles: Dictionary = _safe_dictionary(state.get("actor_profiles", {}))
	var profile_key: String = "%s:%d" % [str(resolved_contract.get("domain", "generic")), int(actor.id)]
	var actor_profile: Dictionary = _safe_dictionary(profiles.get(profile_key, {}))
	actor_profile ["person_id"] = int(actor.id)
	actor_profile ["person_name"] = _person_label(actor)
	actor_profile ["domain"] = str(resolved_contract.get("domain", "generic"))
	actor_profile ["last_score"] = final_score
	actor_profile ["last_competition_id"] = str(resolved_contract.get("id", ""))
	actor_profile ["last_competed_year"] = _current_year()
	actor_profile ["performances"] = int(actor_profile.get("performances", 0)) + 1
	actor_profile ["average_score"] = _rolling_average(float(actor_profile.get("average_score", final_score)), final_score, int(actor_profile.get("performances", 1)))
	profiles [profile_key] = actor_profile
	state ["actor_profiles"] = profiles
	state ["last_performance_report"] = performance_row.duplicate(true)
	_commit_world_state(state)

	return performance_row

func on_boxing_fight_completed(payload: Dictionary) -> void:
	if typeof(payload) != TYPE_DICTIONARY:
		return

	var winner_id: int = int(payload.get("winner_id", payload.get("npc_id", -1)))
	var loser_id: int = int(payload.get("loser_id", payload.get("target_id", -1)))
	var winner: Person = _person_by_id(winner_id)
	var loser: Person = _person_by_id(loser_id)
	if winner == null or loser == null:
		return

	var contract: Dictionary = _resolve_contract("boxing.fight", "boxing")
	record_match(contract, [
		{
			"person_id": int(winner.id),
			"person_name": _person_label(winner),
			"role": "winner",
			"forced_score_bonus": 8.0
		},
		{
			"person_id": int(loser.id),
			"person_name": _person_label(loser),
			"role": "loser",
			"forced_score_bonus": -4.0
		}
	], {
		"source": "boxing_fight_completed",
		"domain": "boxing",
		"forced_winner_id": winner_id,
		"result_type": str(payload.get("result_type", "Decision")),
		"title_fight": bool(payload.get("title_fight", false)),
		"lineal_fight": bool(payload.get("lineal_fight", false)),
		"division": str(payload.get("division", "")),
		"belts": _safe_array(payload.get("belts", [])),
		"raw_payload": payload.duplicate(true)
	})

func on_boxing_title_won(payload: Dictionary) -> void:
	if typeof(payload) != TYPE_DICTIONARY:
		return

	var npc_id: int = int(payload.get("npc_id", payload.get("winner_id", -1)))
	var actor: Person = _person_by_id(npc_id)
	if actor == null:
		return

	var contract: Dictionary = _resolve_contract("boxing.title_win", "boxing")
	var performance: Dictionary = record_performance(actor, contract, {
		"source": "boxing_title_won",
		"domain": "boxing",
		"title_fight": true,
		"championship": true,
		"belt": str(payload.get("belt", payload.get("title", ""))),
		"division": str(payload.get("division", "")),
		"raw_payload": payload.duplicate(true)
	})

	var row: Dictionary = {
		"schema": "eralife.competitive_title_memory",
		"version": CONTRACT_VERSION,
		"domain": "boxing",
		"person_id": int(actor.id),
		"person_name": _person_label(actor),
		"score": float(performance.get("score", 0.0)),
		"year": _current_year(),
		"era": _current_era_key(),
		"payload": payload.duplicate(true)
	}

	var state: Dictionary = _world_state()
	_append_limited(state ["historical_memory"], row, MAX_MEMORY_LEDGER_SIZE)
	_commit_world_state(state)

func on_media_signal(payload: Dictionary) -> void:
	if typeof(payload) != TYPE_DICTIONARY:
		return

	var domain: String = str(payload.get("category", payload.get("domain", "generic"))).strip_edges().to_lower()
	var actor: Person = _person_by_id(int(payload.get("npc_id", payload.get("person_id", -1))))
	var media_packet: Dictionary = {
		"schema": "eralife.competitive_media_signal",
		"version": CONTRACT_VERSION,
		"domain": domain,
		"person_id": int(actor.id) if actor != null else int(payload.get("npc_id", -1)),
		"person_name": _person_label(actor) if actor != null else str(payload.get("person_name", "Unknown")),
		"text": str(payload.get("text", "")),
		"channel": _era_media_channel(),
		"narrative_frame": str(payload.get("event_name", payload.get("narrative_frame", "competitive_signal"))),
		"year": _current_year(),
		"era": _current_era_key(),
		"raw_payload": payload.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	var state: Dictionary = _world_state()
	_append_limited(state ["media_ledger"], media_packet, MAX_MEDIA_LEDGER_SIZE)
	state ["last_media_signal"] = media_packet.duplicate(true)
	_commit_world_state(state)

func get_runtime_snapshot(domain: String = "") -> Dictionary:
	var state: Dictionary = _world_state()
	var clean_domain: String = str(domain).strip_edges().to_lower()
	if clean_domain == "":
		return state.duplicate(true)

	var out: Dictionary = {
		"schema": "eralife.competitive_reality_domain_snapshot",
		"version": CONTRACT_VERSION,
		"domain": clean_domain,
		"actor_profiles": {},
		"matches": [],
		"media": [],
		"historical_memory": [],
		"culture": []
	}

	var profiles: Dictionary = _safe_dictionary(state.get("actor_profiles", {}))
	for key in profiles.keys():
		var profile: Dictionary = _safe_dictionary(profiles.get(key, {}))
		if str(profile.get("domain", "")).strip_edges().to_lower() == clean_domain:
			out ["actor_profiles"] [key] = profile.duplicate(true)

	for raw_match in _safe_array(state.get("match_ledger", [])):
		if typeof(raw_match) == TYPE_DICTIONARY and str(raw_match.get("domain", "")).strip_edges().to_lower() == clean_domain:
			out ["matches"].append((raw_match as Dictionary).duplicate(true))

	for raw_media in _safe_array(state.get("media_ledger", [])):
		if typeof(raw_media) == TYPE_DICTIONARY and str(raw_media.get("domain", "")).strip_edges().to_lower() == clean_domain:
			out ["media"].append((raw_media as Dictionary).duplicate(true))

	for raw_memory in _safe_array(state.get("historical_memory", [])):
		if typeof(raw_memory) == TYPE_DICTIONARY and str(raw_memory.get("domain", "")).strip_edges().to_lower() == clean_domain:
			out ["historical_memory"].append((raw_memory as Dictionary).duplicate(true))

	for raw_culture in _safe_array(state.get("cultural_propagation", [])):
		if typeof(raw_culture) == TYPE_DICTIONARY and str(raw_culture.get("domain", "")).strip_edges().to_lower() == clean_domain:
			out ["culture"].append((raw_culture as Dictionary).duplicate(true))

	return out

func _default_contract() -> Dictionary:
	return {
		"schema": CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": "competitive_reality_runtime.default",
		"runtime_policy": {
			"emit_world_feed": true,
			"emit_event_bus": true,
		},
		"default_performance_axes": [
			{ "id": "skill", "weight": 1.0, "payload_key": "skill", "actor_field": "smarts", "min": 0.0, "max": 100.0},
			{ "id": "physical_state", "weight": 0.75, "payload_key": "physical_state", "actor_field": "health", "min": 0.0, "max": 100.0},
			{ "id": "mental_state", "weight": 0.65, "payload_key": "mental_state", "actor_field": "mental_health", "min": 0.0, "max": 100.0},
			{ "id": "public_presence", "weight": 0.35, "payload_key": "public_presence", "actor_field": "fame", "min": 0.0, "max": 100.0}
		],
		"media_contract": {
			"ancient_channel": "oral_runtime",
			"medieval_channel": "oral_runtime",
			"industrial_channel": "oral_runtime",
			"modern_channel": "media_runtime",
			"future_channel": "future_media_runtime",
			"headline_threshold": 62.0,
			"viral_threshold": 84.0,
			"goat_debate_threshold": 92.0
		},
		"reputation_contract": {
			"winner_multiplier": 1.0,
			"participant_multiplier": 0.25,
			"fame_field_enabled": true,
			"respect_profile_enabled": true
		},
		"historical_memory_contract": {
			"salience_threshold": 58.0,
			"myth_threshold": 86.0,
			"allow_reinterpretation": true,
		},
		"cultural_propagation_contract": {
			"propagation_threshold": 65.0,
			"style_echo_threshold": 78.0,
			"copycat_threshold": 88.0
		},
		"competition_contracts": [
			{
				"id": "boxing.fight",
				"domain": "boxing",
				"display_name": "Boxing Fight",
				"competition_type": "combat_sport",
				"performance_axes": [
					{ "id": "boxing_skill", "weight": 1.15, "payload_key": "boxing_skill", "profile_path": "boxing_profile.overall_rating", "actor_field": "health", "min": 0.0, "max": 100.0},
					{ "id": "conditioning", "weight": 0.85, "payload_key": "conditioning", "actor_field": "health", "min": 0.0, "max": 100.0},
					{ "id": "discipline", "weight": 0.55, "payload_key": "discipline", "actor_field": "job_performance", "min": 0.0, "max": 100.0},
					{ "id": "public_pressure", "weight": 0.35, "payload_key": "public_pressure", "actor_field": "fame", "min": 0.0, "max": 100.0}
				]
			},
			{
				"id": "boxing.title_win",
				"domain": "boxing",
				"display_name": "Boxing Title Win",
				"competition_type": "championship_memory",
				"performance_axes": [
					{ "id": "championship_stakes", "weight": 1.2, "payload_key": "championship_stakes", "default": 92.0, "min": 0.0, "max": 100.0},
					{ "id": "public_presence", "weight": 0.65, "payload_key": "public_presence", "actor_field": "fame", "min": 0.0, "max": 100.0},
					{ "id": "physical_state", "weight": 0.45, "payload_key": "physical_state", "actor_field": "health", "min": 0.0, "max": 100.0}
				]
			},
			{
				"id": "bending.tournament_match",
				"domain": "bending",
				"display_name": "Bending Tournament Match",
				"competition_type": "fantasy_combat_sport",
				"performance_axes": [
					{ "id": "elemental_mastery", "weight": 1.3, "payload_key": "elemental_mastery", "profile_path": "bending_combat_profile.level", "actor_field": "smarts", "min": 0.0, "max": 100.0},
					{ "id": "willpower", "weight": 0.9, "payload_key": "willpower", "default": 50.0, "min": 0.0, "max": 100.0},
					{ "id": "adaptation", "weight": 0.75, "payload_key": "adaptation", "actor_field": "smarts", "min": 0.0, "max": 100.0},
					{ "id": "spectacle", "weight": 0.45, "payload_key": "spectacle", "actor_field": "fame", "min": 0.0, "max": 100.0}
				]
			},
			{
				"id": "music.performance",
				"domain": "music",
				"display_name": "Music Performance",
				"competition_type": "creative_performance",
				"performance_axes": [
					{ "id": "technical_skill", "weight": 0.85, "payload_key": "technical_skill", "actor_field": "smarts", "min": 0.0, "max": 100.0},
					{ "id": "creativity", "weight": 1.15, "payload_key": "creativity", "actor_field": "imagination", "min": 0.0, "max": 100.0},
					{ "id": "stage_presence", "weight": 0.75, "payload_key": "stage_presence", "actor_field": "looks", "min": 0.0, "max": 100.0},
					{ "id": "audience_connection", "weight": 0.75, "payload_key": "audience_connection", "actor_field": "satisfaction", "min": 0.0, "max": 100.0}
				]
			}
		]
	}

func _bootstrap_contract_registry() -> void:
	if typeof(contract_registry) != TYPE_DICTIONARY:
		contract_registry = {}

	var contracts: Array = _safe_array(active_contract.get("competition_contracts", []))
	for raw_contract in contracts:
		if typeof(raw_contract) != TYPE_DICTIONARY:
			continue
		var normalized: Dictionary = _normalize_competition_contract(raw_contract as Dictionary)
		var contract_id: String = str(normalized.get("id", "")).strip_edges()
		if contract_id == "":
			continue
		if not contract_registry.has(contract_id):
			contract_registry [contract_id] = normalized.duplicate(true)

func _normalize_competition_contract(contract: Dictionary) -> Dictionary:
	var out: Dictionary = contract.duplicate(true)
	out ["schema"] = str(out.get("schema", "eralife.competitive_competition_contract"))
	out ["version"] = max(1, int(out.get("version", CONTRACT_VERSION)))
	out ["id"] = str(out.get("id", "generic.competition")).strip_edges()
	out ["domain"] = str(out.get("domain", "generic")).strip_edges().to_lower()
	out ["display_name"] = str(out.get("display_name", out.get("id", "Competition")))
	out ["competition_type"] = str(out.get("competition_type", "competition"))
	if typeof(out.get("performance_axes", [])) != TYPE_ARRAY:
		out ["performance_axes"] = _safe_array(active_contract.get("default_performance_axes", []))
	return out

func _resolve_contract(contract_id: String, domain: String = "generic") -> Dictionary:
	_bootstrap_contract_registry()
	var clean_id: String = str(contract_id).strip_edges()
	if clean_id != "" and contract_registry.has(clean_id):
		return _safe_dictionary(contract_registry.get(clean_id, {}))

	var clean_domain: String = str(domain).strip_edges().to_lower()
	for key in contract_registry.keys():
		var row: Dictionary = _safe_dictionary(contract_registry.get(key, {}))
		if str(row.get("domain", "")).strip_edges().to_lower() == clean_domain:
			return row.duplicate(true)

	return {
		"id": clean_domain + ".generic",
		"domain": clean_domain,
		"display_name": clean_domain.capitalize() + " Competition",
		"competition_type": "generic_competition",
		"performance_axes": _safe_array(active_contract.get("default_performance_axes", []))
	}

func _resolve_contract_from_payload(contract: Dictionary, context: Dictionary = {}) -> Dictionary:
	if typeof(contract) == TYPE_DICTIONARY and not contract.is_empty():
		if str(contract.get("id", "")).strip_edges() != "":
			return _normalize_competition_contract(contract)
	var contract_id: String = str(context.get("contract_id", context.get("competition_id", ""))).strip_edges()
	var domain: String = str(context.get("domain", "generic")).strip_edges().to_lower()
	return _resolve_contract(contract_id, domain)

func _normalize_participants(participants: Array, context: Dictionary = {}) -> Array:
	var out: Array = []
	for raw_participant in participants:
		if raw_participant is Person:
			var actor: Person = raw_participant
			out.append({
				"person_id": int(actor.id),
				"person_name": _person_label(actor)
			})
		elif typeof(raw_participant) == TYPE_DICTIONARY:
			var row: Dictionary = (raw_participant as Dictionary).duplicate(true)
			var actor_from_row: Person = _participant_person(row)
			if actor_from_row != null:
				row ["person_id"] = int(actor_from_row.id)
				row ["person_name"] = _person_label(actor_from_row)
			out.append(row)

	if out.is_empty():
		var actor: Person = context.get("actor", null)
		if actor != null:
			out.append({
				"person_id": int(actor.id),
				"person_name": _person_label(actor)
			})
	return out

func _participant_person(row: Dictionary) -> Person:
	if typeof(row) != TYPE_DICTIONARY:
		return null
	var actor_raw: Variant = row.get("actor", null)
	if actor_raw is Person:
		return actor_raw
	return _person_by_id(int(row.get("person_id", row.get("npc_id", -1))))

func _resolve_winner(rows: Array, context: Dictionary = {}) -> Dictionary:
	var forced_winner_id: int = int(context.get("forced_winner_id", -1))
	if forced_winner_id > 0:
		for raw_forced in rows:
			if typeof(raw_forced) == TYPE_DICTIONARY and int(raw_forced.get("person_id", -1)) == forced_winner_id:
				return (raw_forced as Dictionary).duplicate(true)

	var best: Dictionary = {}
	var best_score: float = -999999.0
	for raw_row in rows:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = raw_row
		var score: float = float(row.get("score", 0.0))
		if score > best_score:
			best_score = score
			best = row.duplicate(true)
	return best

func _resolve_axis_value(actor: Person, axis: Dictionary, context: Dictionary = {}) -> float:
	var axis_id: String = str(axis.get("id", "")).strip_edges().to_lower()
	var payload_key: String = str(axis.get("payload_key", "")).strip_edges()
	if payload_key != "" and context.has(payload_key):
		return float(context.get(payload_key, axis.get("default", 50.0)))

	if axis_id == "willpower" and actor != null and gs != null and "willpower_engine" in gs and gs.willpower_engine != null:
		if gs.willpower_engine.has_method("score"):
			return float(gs.willpower_engine.score(actor, {
				"source": "competitive_reality_axis_value",
				"scope": str(context.get("domain", axis.get("domain", "competition")))
			}))
		if gs.willpower_engine.has_method("ensure_willpower"):
			var willpower_profile: Dictionary = gs.willpower_engine.ensure_willpower(actor, {
				"source": "competitive_reality_axis_value",
				"scope": str(context.get("domain", axis.get("domain", "competition")))
			})
			return float(willpower_profile.get("core_score", actor.willpower))

	var profile_path: String = str(axis.get("profile_path", "")).strip_edges()
	if profile_path != "":
		var path_value: Variant = _read_actor_path(actor, profile_path)
		if path_value != null:
			return float(path_value)

	var actor_field: String = str(axis.get("actor_field", "")).strip_edges()
	if actor_field != "" and actor != null:
		var field_value: Variant = actor.get(actor_field)
		if field_value != null:
			return float(field_value)

	return float(axis.get("default", 50.0))

func _read_actor_path(actor: Person, path: String) -> Variant:
	if actor == null:
		return null

	var pieces: PackedStringArray = str(path).split(".")
	if pieces.size() == 0:
		return null

	var current: Variant = actor.get(str(pieces [0]))
	for i in range(1, pieces.size()):
		if typeof(current) != TYPE_DICTIONARY:
			return null
		current = (current as Dictionary).get(str(pieces [i]), null)
	return current

func _performance_variance(contract: Dictionary, context: Dictionary = {}) -> float:
	var variance_contract: Dictionary = _safe_dictionary(contract.get("variance", {}))
	var amount: float = float(variance_contract.get("amount", context.get("variance_amount", 6.0)))
	if amount <= 0.0:
		return float(context.get("forced_score_bonus", 0.0))
	var roll: float = float((randi() % int(max(1.0, amount * 200.0)))) / 100.0
	roll -= amount
	roll += float(context.get("forced_score_bonus", 0.0))
	return roll

func _resolve_audience_reaction(contract: Dictionary, rows: Array, context: Dictionary = {}) -> Dictionary:
	var audience_count: int = int(context.get("audience_count", context.get("spectator_count", _default_audience_count(contract, context))))
	var highest_score: float = 0.0
	for raw_row in rows:
		if typeof(raw_row) == TYPE_DICTIONARY:
			highest_score = max(highest_score, float(raw_row.get("score", 0.0)))

	var reaction_score: float = clamp((highest_score * 0.7) + (min(audience_count, 1000000) / 1000000.0 * 30.0), 0.0, 100.0)
	var reaction_label: String = "quiet"
	if reaction_score >= 88.0:
		reaction_label = "legendary"
	elif reaction_score >= 72.0:
		reaction_label = "electric"
	elif reaction_score >= 55.0:
		reaction_label = "engaged"
	elif reaction_score >= 35.0:
		reaction_label = "mixed"

	return {
		"schema": "eralife.competitive_audience_reaction",
		"version": CONTRACT_VERSION,
		"audience_count": audience_count,
		"reaction_score": reaction_score,
		"reaction_label": reaction_label,
		"channel": _era_media_channel()
	}

func _resolve_judgment(contract: Dictionary, rows: Array, winner: Dictionary, context: Dictionary = {}) -> Dictionary:
	return {
		"schema": "eralife.competitive_judgment_report",
		"version": CONTRACT_VERSION,
		"method": str(context.get("result_type", context.get("judgment_method", "resolved_by_contract_score"))),
		"winner_id": int(winner.get("person_id", -1)),
		"winner_name": str(winner.get("person_name", "Unknown")),
		"controversy": _resolve_controversy(contract, rows, winner, context),
	}

func _resolve_controversy(_contract: Dictionary, rows: Array, winner: Dictionary, context: Dictionary = {}) -> Dictionary:
	if bool(context.get("controversy", false)):
		return {
			"has_controversy": true,
			"type": str(context.get("controversy_type", "public_dispute")),
			"heat": clamp(float(context.get("controversy_heat", 35.0)), 0.0, 100.0)
		}

	var winner_score: float = float(winner.get("score", 0.0))
	var closest: float = 999999.0
	for raw_row in rows:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = raw_row
		if int(row.get("person_id", -1)) == int(winner.get("person_id", -1)):
			continue
		closest = min(closest, abs(winner_score - float(row.get("score", 0.0))))

	if closest <= 3.0:
		return {
			"has_controversy": true,
			"type": "close_result",
			"heat": 22.0
		}

	return {
		"has_controversy": false,
		"type": "",
		"heat": 0.0
	}

func _apply_reputation_shift(contract: Dictionary, rows: Array, winner: Dictionary, audience: Dictionary, context: Dictionary = {}) -> Dictionary:
	var reputation_contract: Dictionary = _merge_dict(_safe_dictionary(active_contract.get("reputation_contract", {})), _safe_dictionary(contract.get("reputation_contract", {})))
	var winner_multiplier: float = float(reputation_contract.get("winner_multiplier", 1.0))
	var participant_multiplier: float = float(reputation_contract.get("participant_multiplier", 0.25))
	var audience_score: float = float(audience.get("reaction_score", 0.0))
	var updates: Array = []

	for raw_row in rows:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = raw_row
		var actor: Person = _person_by_id(int(row.get("person_id", -1)))
		if actor == null:
			continue

		var is_winner: bool = int(row.get("person_id", -1)) == int(winner.get("person_id", -999))
		var delta: int = int(round((float(row.get("score", 0.0)) / 100.0 * 8.0) + (audience_score / 100.0 * 5.0)))
		if is_winner:
			delta = int(round(float(delta) * winner_multiplier))
		else:
			delta = int(round(float(delta) * participant_multiplier))

		if bool(reputation_contract.get("fame_field_enabled", true)):
			actor.fame = clamp(int(actor.fame) + delta, 0, 100)

		if bool(reputation_contract.get("respect_profile_enabled", true)):
			var respect_profile: Dictionary = _safe_dictionary(actor.respect_profile)
			var domain: String = str(contract.get("domain", context.get("domain", "general"))).strip_edges().to_lower()
			respect_profile [domain] = clamp(int(respect_profile.get(domain, 50)) + delta, 0, 100)
			respect_profile ["public"] = clamp(int(respect_profile.get("public", 50)) + int(round(float(delta) * 0.5)), 0, 100)
			respect_profile ["last_delta"] = delta
			respect_profile ["last_reason"] = "competitive_reality_runtime"
			actor.respect_profile = respect_profile

		updates.append({
			"person_id": int(actor.id),
			"person_name": _person_label(actor),
			"delta": delta,
			"is_winner": is_winner,
			"new_fame": int(actor.fame)
		})

	return {
		"schema": "eralife.competitive_reputation_report",
		"version": CONTRACT_VERSION,
		"updates": updates,
		"source": str(context.get("source", "competitive_reality_runtime"))
	}

func _build_media_packet(contract: Dictionary, winner: Dictionary, rows: Array, audience: Dictionary, judgment: Dictionary, context: Dictionary = {}) -> Dictionary:
	var media_contract: Dictionary = _merge_dict(_safe_dictionary(active_contract.get("media_contract", {})), _safe_dictionary(contract.get("media_contract", {})))
	var channel: String = _era_media_channel()
	var winner_name: String = str(winner.get("person_name", "Unknown"))
	var display_name: String = str(contract.get("display_name", "competition"))
	var reaction_score: float = float(audience.get("reaction_score", 0.0))
	var headline: String = "%s wins %s" % [winner_name, display_name]
	var frame: String = "result"

	if reaction_score >= float(media_contract.get("goat_debate_threshold", 92.0)):
		frame = "goat_debate"
		headline = "%s just forced a new GOAT debate after %s" % [winner_name, display_name]
	elif reaction_score >= float(media_contract.get("viral_threshold", 84.0)):
		frame = "viral_moment"
		headline = "%s created a viral moment in %s" % [winner_name, display_name]
	elif reaction_score >= float(media_contract.get("headline_threshold", 62.0)):
		frame = "headline"
		headline = "%s made headlines in %s" % [winner_name, display_name]

	var controversy: Dictionary = _safe_dictionary(judgment.get("controversy", {}))
	if bool(controversy.get("has_controversy", false)):
		frame = "controversy"
		headline = "%s wins %s, but the result sparks debate" % [winner_name, display_name]

	return {
		"schema": "eralife.competitive_media_packet",
		"version": CONTRACT_VERSION,
		"domain": str(contract.get("domain", context.get("domain", "generic"))),
		"competition_id": str(contract.get("id", "")),
		"channel": channel,
		"headline": headline,
		"narrative_frame": frame,
		"reaction_score": reaction_score,
		"winner_id": int(winner.get("person_id", -1)),
		"winner_name": winner_name,
		"participant_count": rows.size(),
		"year": _current_year(),
		"era": _current_era_key(),
		"created_at_ms": int(Time.get_ticks_msec())
	}

func _build_historical_memory_packet(contract: Dictionary, winner: Dictionary, rows: Array, media: Dictionary, context: Dictionary = {}) -> Dictionary:
	var memory_contract: Dictionary = _merge_dict(_safe_dictionary(active_contract.get("historical_memory_contract", {})), _safe_dictionary(contract.get("historical_memory_contract", {})))
	var salience: float = float(media.get("reaction_score", 0.0))
	if salience < float(memory_contract.get("salience_threshold", 58.0)):
		return {}

	var myth_level: String = "remembered"
	if salience >= float(memory_contract.get("myth_threshold", 86.0)):
		myth_level = "mythologized"

	return {
		"schema": "eralife.competitive_historical_memory",
		"version": CONTRACT_VERSION,
		"domain": str(contract.get("domain", context.get("domain", "generic"))),
		"competition_id": str(contract.get("id", "")),
		"winner_id": int(winner.get("person_id", -1)),
		"winner_name": str(winner.get("person_name", "Unknown")),
		"salience": salience,
		"myth_level": myth_level,
		"memory_text": str(media.get("headline", "")),
		"participant_count": rows.size(),
		"allow_reinterpretation": bool(memory_contract.get("allow_reinterpretation", true)),
		"year": _current_year(),
		"era": _current_era_key(),
		"created_at_ms": int(Time.get_ticks_msec())
	}

func _build_cultural_propagation_packet(contract: Dictionary, winner: Dictionary, _rows: Array, media: Dictionary, context: Dictionary = {}) -> Dictionary:
	var culture_contract: Dictionary = _merge_dict(_safe_dictionary(active_contract.get("cultural_propagation_contract", {})), _safe_dictionary(contract.get("cultural_propagation_contract", {})))
	var salience: float = float(media.get("reaction_score", 0.0))
	if salience < float(culture_contract.get("propagation_threshold", 65.0)):
		return {}

	var propagation_type: String = "discussion"
	if salience >= float(culture_contract.get("copycat_threshold", 88.0)):
		propagation_type = "copycat_styles"
	elif salience >= float(culture_contract.get("style_echo_threshold", 78.0)):
		propagation_type = "style_echo"

	return {
		"schema": "eralife.competitive_cultural_propagation",
		"version": CONTRACT_VERSION,
		"domain": str(contract.get("domain", context.get("domain", "generic"))),
		"competition_id": str(contract.get("id", "")),
		"origin_person_id": int(winner.get("person_id", -1)),
		"origin_person_name": str(winner.get("person_name", "Unknown")),
		"propagation_type": propagation_type,
		"salience": salience,
		"era_channel": _era_media_channel(),
		"year": _current_year(),
		"era": _current_era_key(),
		"created_at_ms": int(Time.get_ticks_msec())
	}

func _emit_world_feed_for_match(match_row: Dictionary) -> void:
	if gs == null or not gs.has_method("push_world_feed"):
		return
	var media: Dictionary = _safe_dictionary(match_row.get("media", {}))
	var text: String = str(media.get("headline", "")).strip_edges()
	if text == "":
		return

	gs.push_world_feed(text, {
		"source": "competitive_reality_runtime",
		"category": str(match_row.get("domain", "competition")),
		"event_name": "competitive_match_completed",
		"competition_id": str(match_row.get("competition_id", "")),
		"match_id": str(match_row.get("match_id", "")),
		"npc_id": int(match_row.get("winner_id", -1)),
		"personally_relevant": gs.player != null and int(gs.player.id) == int(match_row.get("winner_id", -1))
	})

func _emit_competitive_event(event_type: String, payload: Dictionary) -> void:
	if gs == null or gs.event_bus == null:
		return
	if not bool(_safe_dictionary(active_contract.get("runtime_policy", {})).get("emit_event_bus", true)):
		return
	gs.event_bus.emit(event_type, payload)

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

	if typeof(out.get("contract_registry", {})) != TYPE_DICTIONARY:
		out ["contract_registry"] = {}
	if typeof(out.get("actor_profiles", {})) != TYPE_DICTIONARY:
		out ["actor_profiles"] = {}
	if typeof(out.get("league_state", {})) != TYPE_DICTIONARY:
		out ["league_state"] = {}

	for key in ["match_ledger", "performance_ledger", "media_ledger", "historical_memory", "cultural_propagation", "yearly_reports"]:
		if typeof(out.get(key, [])) != TYPE_ARRAY:
			out [key] = []

	if typeof(out.get("last_match_report", {})) != TYPE_DICTIONARY:
		out ["last_match_report"] = {}
	if typeof(out.get("last_performance_report", {})) != TYPE_DICTIONARY:
		out ["last_performance_report"] = {}
	if typeof(out.get("last_media_signal", {})) != TYPE_DICTIONARY:
		out ["last_media_signal"] = {}

	return out

func _commit_world_state(state: Dictionary) -> void:
	if gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	gs.scenario_state [STATE_KEY] = _normalize_state(state)

func _decay_media_heat(state: Dictionary) -> int:
	var profiles: Dictionary = _safe_dictionary(state.get("actor_profiles", {}))
	var updates: int = 0
	for key in profiles.keys():
		var profile: Dictionary = _safe_dictionary(profiles.get(key, {}))
		if profile.has("media_heat"):
			profile ["media_heat"] = max(0.0, float(profile.get("media_heat", 0.0)) - 4.0)
			profiles [key] = profile
			updates += 1
	state ["actor_profiles"] = profiles
	return updates

func _evolve_culture_memory(state: Dictionary) -> int:
	var culture: Array = _safe_array(state.get("cultural_propagation", []))
	var updates: int = 0
	for i in range(culture.size()):
		if typeof(culture [i]) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = culture [i]
		row ["age_in_years"] = max(0, _current_year() - int(row.get("year", _current_year())))
		row ["salience"] = clamp(float(row.get("salience", 0.0)) - 1.0, 0.0, 100.0)
		culture [i] = row
		updates += 1
	state ["cultural_propagation"] = culture
	return updates

func _evolve_historical_memory(state: Dictionary) -> int:
	var memories: Array = _safe_array(state.get("historical_memory", []))
	var updates: int = 0
	for i in range(memories.size()):
		if typeof(memories [i]) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = memories [i]
		var years_old: int = max(0, _current_year() - int(row.get("year", _current_year())))
		row ["age_in_years"] = years_old
		if years_old >= 10 and str(row.get("myth_level", "")) == "mythologized":
			row ["memory_text"] = str(row.get("memory_text", "")) + " People still argue about what it meant."
		memories [i] = row
		updates += 1
	state ["historical_memory"] = memories
	return updates

func _default_audience_count(contract: Dictionary, context: Dictionary = {}) -> int:
	if context.has("audience_count"):
		return int(context.get("audience_count", 0))
	var domain: String = str(contract.get("domain", "generic")).strip_edges().to_lower()
	match domain:
		"boxing":
			return 12000
		"bending":
			return 28000
		"music":
			return 800
		_:
			return 250

func _era_media_channel() -> String:
	var era_key: String = _current_era_key()
	match era_key:
		"ancient":
			return "oral_runtime"
		"medieval":
			return "oral_runtime"
		"industrial":
			return "oral_runtime"
		"future":
			return "future_media_runtime"
		_:
			return "media_runtime"

func _current_era_key() -> String:
	if gs == null:
		return "unknown"
	if gs.era_engine != null and gs.era_engine.has_method("get_era_key_from_year"):
		return str(gs.era_engine.call("get_era_key_from_year", int(gs.year))).strip_edges().to_lower()
	if gs.era != null:
		return str(gs.era.get("key") if typeof(gs.era) == TYPE_DICTIONARY else gs.era.name).strip_edges().to_lower()
	return "unknown"

func _current_year() -> int:
	if gs == null:
		return 0
	return int(gs.year)

func _person_by_id(person_id: int) -> Person:
	if gs == null or person_id <= 0:
		return null
	if gs.has_method("get_npc_by_id"):
		return gs.get_npc_by_id(person_id)
	for npc in gs.npcs:
		if npc != null and int(npc.id) == person_id:
			return npc
	return null

func _person_label(actor: Person) -> String:
	if actor == null:
		return "Unknown"
	var label: String = ("%s %s" % [str(actor.first_name), str(actor.last_name)]).strip_edges()
	if label == "":
		label = str(actor.name).strip_edges()
	if label == "":
		label = "Person %d" % int(actor.id)
	return label

func _rolling_average(current_average: float, incoming: float, count: int) -> float:
	var safe_count: int = max(1, count)
	return ((current_average * float(safe_count - 1)) + incoming) / float(safe_count)

func _append_limited(target: Variant, value: Variant, limit: int) -> void:
	if typeof(target) != TYPE_ARRAY:
		return
	var arr: Array = target
	if typeof(value) == TYPE_ARRAY:
		for raw in value:
			arr.append(raw)
	else:
		arr.append(value)
	while arr.size() > limit:
		arr.pop_front()

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