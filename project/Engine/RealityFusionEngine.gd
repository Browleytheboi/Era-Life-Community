extends Resource
class_name RealityFusionEngine

const REALITY_FUSION_VERSION:= 1
const FUSION_CONTRACT_SCHEMA:= "eralife.reality_fusion_contract"
const FUSION_REPORT_SCHEMA:= "eralife.reality_fusion_report"

var gs
var last_fusion_report: Dictionary = {}
var fusion_ledger: Array = []


func _init(_gs = null):
	gs = _gs
	_hydrate_ledger_from_game_state()


func export_state() -> Dictionary:
	_hydrate_ledger_from_game_state()
	return {
		"schema": "eralife.reality_fusion_engine_state",
		"version": REALITY_FUSION_VERSION,
		"fusion_ledger": fusion_ledger.duplicate(true),
		"last_fusion_report": last_fusion_report.duplicate(true)
	}


func import_state(state: Dictionary) -> Dictionary:
	if typeof(state) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "RealityFusionEngine import_state expected a Dictionary."
		}

	fusion_ledger = _safe_array(state.get("fusion_ledger", []))
	last_fusion_report = _safe_dictionary(state.get("last_fusion_report", {}))
	_store_ledger_to_game_state()

	return {
		"success": true,
		"ledger_count": fusion_ledger.size()
	}


func preview_fusion_from_path(path: String, fusion_contract: Dictionary = {}) -> Dictionary:
	var normalized_path: String = str(path).strip_edges()
	if normalized_path == "":
		return _fail_report("missing_path", "Fusion source path is empty.", 0, {})
	if not FileAccess.file_exists(normalized_path):
		return _fail_report("missing_file", "Fusion source file is missing.", 0, {
			"path": normalized_path
		})

	var decoded: Dictionary = _decode_payload_from_path(normalized_path)
	if not bool(decoded.get("success", false)):
		return _fail_report("decode_failed", str(decoded.get("reason", "Fusion source could not be decoded.")), 0, {
			"path": normalized_path
		})

	var payload_raw: Variant = decoded.get("data", {})
	if typeof(payload_raw) != TYPE_DICTIONARY:
		return _fail_report("payload_invalid", "Fusion source payload is not a Dictionary.", 0, {
			"path": normalized_path
		})

	var payload: Dictionary = payload_raw
	var source_player: Dictionary = _source_player_from_payload(payload)
	if source_player.is_empty():
		return _fail_report("source_player_missing", "Fusion source has no playable player.", 0, {
			"path": normalized_path
		})

	var contract: Dictionary = _resolve_fusion_contract(fusion_contract)
	var source_stats: Dictionary = _extract_stats(source_player, _default_stat_keys())
	var source_bending_mastery: Dictionary = _safe_dictionary(source_player.get("bending_mastery", {}))
	var source_traits: Array = _safe_array(source_player.get("traits", []))

	return {
		"schema": "eralife.reality_fusion_preview",
		"version": REALITY_FUSION_VERSION,
		"success": true,
		"path": normalized_path,
		"format": str(decoded.get("format", "unknown")),
		"mode": str(contract.get("mode", "stats_blend")),
		"source_player": {
			"id": int(source_player.get("id", -1)),
			"name": _person_name_from_dict(source_player),
			"age": int(source_player.get("age", 0)),
			"identity": _source_identity_from_player(source_player),
			"stats": source_stats,
			"bending_type": str(source_player.get("bending_type", "none")),
			"bending_nation": str(source_player.get("bending_nation", "")),
			"bending_mastery": source_bending_mastery,
			"bending_latent_potential": _safe_dictionary(source_player.get("bending_latent_potential", {})),
			"avatar_state_unlocked": bool(source_player.get("avatar_state_unlocked", false)),
			"traits": source_traits,
			"bank_balance": float(source_player.get("bank_balance", 0)),
			"power_profile": _source_power_profile(source_player)
		},
		"contract": contract.duplicate(true)
	}

func fuse_from_path(path: String, fusion_contract: Dictionary = {}) -> Dictionary:
	var started_at: int = int(Time.get_ticks_msec())
	_hydrate_ledger_from_game_state()

	var normalized_path: String = str(path).strip_edges()
	if normalized_path == "":
		return _fail_report("missing_path", "Fusion source path is empty.", started_at, {})

	if gs == null:
		return _fail_report("game_state_missing", "GameState is unavailable for Reality Fusion.", started_at, {
			"path": normalized_path
		})

	if gs.player == null:
		return _fail_report("target_player_missing", "No active player exists to receive the fusion.", started_at, {
			"path": normalized_path
		})

	var contract: Dictionary = _resolve_fusion_contract(fusion_contract)
	var mode: String = str(contract.get("mode", "stats_blend")).strip_edges().to_lower()

	if mode in ["parallel_identity_import", "bring_person_family", "bring_family", "friend_person", "bring_family_member"]:
		return _import_parallel_identity(normalized_path, contract, started_at)

	var cooldown_report: Dictionary = _cooldown_report(contract)
	if bool(cooldown_report.get("blocked", false)):
		return _fail_report("fusion_cooldown_active", str(cooldown_report.get("reason", "Reality Fusion is cooling down.")), started_at, cooldown_report)

	if not FileAccess.file_exists(normalized_path):
		return _fail_report("missing_file", "Fusion source file is missing.", started_at, {
			"path": normalized_path
		})

	var decoded: Dictionary = _decode_payload_from_path(normalized_path)
	if not bool(decoded.get("success", false)):
		return _fail_report("decode_failed", str(decoded.get("reason", "Fusion source could not be decoded.")), started_at, {
			"path": normalized_path
		})

	var payload_raw: Variant = decoded.get("data", {})
	if typeof(payload_raw) != TYPE_DICTIONARY:
		return _fail_report("payload_invalid", "Fusion source payload is not a Dictionary.", started_at, {
			"path": normalized_path
		})

	var payload: Dictionary = payload_raw
	var source_player: Dictionary = _source_player_from_payload(payload)
	if source_player.is_empty():
		return _fail_report("source_player_missing", "Fusion source has no playable player.", started_at, {
			"path": normalized_path
		})

	var resistance_report: Dictionary = _roll_source_resistance(source_player, contract, normalized_path)
	if bool(resistance_report.get("blocked", false)):
		var blocked_report: Dictionary = _fail_report("source_resisted", str(resistance_report.get("reason", "The other reality fought back.")), started_at, {
			"path": normalized_path,
			"mode": mode,
			"source_player": _person_name_from_dict(source_player),
			"resistance": resistance_report.duplicate(true)
		})
		_push_world_feed("The other universe resisted your fusion attempt.")
		return blocked_report

	var extraction: Dictionary = _extract_components(source_player, payload, contract)
	var transform_report: Dictionary = _apply_components_to_target(gs.player, source_player, payload, extraction, contract)
	var reconcile_report: Dictionary = _reconcile_source_world(normalized_path, payload, source_player, extraction, contract)

	var report: Dictionary = {
		"schema": FUSION_REPORT_SCHEMA,
		"version": REALITY_FUSION_VERSION,
		"success": bool(transform_report.get("success", false)),
		"path": normalized_path,
		"format": str(decoded.get("format", "unknown")),
		"mode": mode,
		"contract": contract.duplicate(true),
		"source_player_name": _person_name_from_dict(source_player),
		"target_player_id": int(gs.player.id),
		"target_player_name": _person_name_from_object(gs.player),
		"extraction": extraction.duplicate(true),
		"transform_report": transform_report.duplicate(true),
		"reconcile_report": reconcile_report.duplicate(true),
		"resistance_report": resistance_report.duplicate(true),
		"started_at_ms": started_at,
		"finished_at_ms": int(Time.get_ticks_msec())
	}
	report ["duration_ms"] = int(report ["finished_at_ms"]) - started_at

	_apply_balance_cost(contract, report)
	_commit_fusion_report(report)

	if bool(report.get("success", false)):
		_push_world_feed(_fusion_world_feed_line(report))

	return report.duplicate(true)


func _import_parallel_identity(path: String, contract: Dictionary, started_at: int) -> Dictionary:
	if gs == null:
		return _fail_report("game_state_missing", "GameState is unavailable for parallel import.", started_at, {
			"path": path
		})
	if not FileAccess.file_exists(path):
		return _fail_report("missing_file", "Fusion source file is missing.", started_at, {
			"path": path
		})
	if not gs.has_method("merge_character_from_save"):
		return _fail_report("legacy_merge_missing", "GameState does not expose merge_character_from_save().", started_at, {
			"path": path
		})

	var imported = gs.merge_character_from_save(path, contract)
	if imported == null:
		return _fail_report("parallel_import_failed", "Parallel identity import failed.", started_at, {
			"path": path,
			"mode": str(contract.get("mode", "parallel_identity_import")),
			"merge_policy": _safe_dictionary(contract.get("merge_policy", {}))
		})

	var merge_report: Dictionary = {}
	if typeof(gs.scenario_state) == TYPE_DICTIONARY:
		merge_report = _safe_dictionary(gs.scenario_state.get("last_reality_merge_report", {}))

	var imported_name: String = _person_name_from_object(imported)
	var report: Dictionary = {
		"schema": FUSION_REPORT_SCHEMA,
		"version": REALITY_FUSION_VERSION,
		"success": true,
		"path": path,
		"mode": str(contract.get("mode", "parallel_identity_import")),
		"contract": contract.duplicate(true),
		"merge_policy": _safe_dictionary(contract.get("merge_policy", {})),
		"imported_player_id": int(imported.id),
		"imported_player_name": imported_name,
		"imported_count": int(merge_report.get("imported_count", 1)),
		"target_player_id": int(gs.player.id) if gs.player != null else -1,
		"target_player_name": _person_name_from_object(gs.player) if gs.player != null else "",
		"started_at_ms": started_at,
		"finished_at_ms": int(Time.get_ticks_msec())
	}
	report ["duration_ms"] = int(report ["finished_at_ms"]) - started_at
	_commit_fusion_report(report)
	_push_world_feed("%s crossed over from another universe." % imported_name)
	return report.duplicate(true)


func _resolve_fusion_contract(contract: Dictionary) -> Dictionary:
	var out: Dictionary = {
		"schema": FUSION_CONTRACT_SCHEMA,
		"version": REALITY_FUSION_VERSION,
		"id": "default_reality_fusion",
		"mode": "stats_blend",
		"extract": {
			"stats": _default_stat_keys(),
			"inventory": "none",
			"bending": {
				"skills": false,
			},
			"traits": {
				"include": [],
				"exclude": ["addiction", "reckless"]
			},
			"consciousness": {
				"enabled": true,
				"memory_echoes": true,
			},
			"money": false,
			"relationships": "none"
		},
		"transform": {
			"stats": {
				"mode": "weighted_blend",
				"weight_self": 0.7,
				"weight_source": 0.3,
				"cap": 100
			},
			"inventory": {
				"mode": "inject",
				"conflict": "stack_or_replace"
			},
			"traits": {
				"mode": "union",
				"mutation_chance": 0.0
			},
			"bending": {
				"mode": "skill_transfer",
				"cap": 100,
				"multiple_avatar_influence": true
			},
			"money": {
				"mode": "add",
				"multiplier": 0.25,
				"cap": 1000000
			},
			"consciousness": {
				"mode": "echo_merge",
				"memory_echo_limit": 5,
				"identity_drift_gain": 0.04,
				"multiverse_awareness_gain": 0.02
			}
		},
		"reconcile": {
			"source_world": "unchanged",
			"write_source_save": false,
			"compensation": "none"
		},
		"source_resistance": {
			"enabled": false,
			"chance": 0.0
		},
		"balance": {
			"fatigue_cost": 4.0,
			"mental_strain": 2.0,
			"identity_instability": 1.0,
			"mutation_risk": 0.0,
			"cooldown_ms": 2500
		}
	}

	if typeof(contract) == TYPE_DICTIONARY and not contract.is_empty():
		out = _merge_dict(out, contract)

	return _make_binary_safe(out)


func _extract_components(source_player: Dictionary, payload: Dictionary, contract: Dictionary) -> Dictionary:
	var extract_rules: Dictionary = _safe_dictionary(contract.get("extract", {}))
	var out: Dictionary = {
		"source_player_id": int(source_player.get("id", -1)),
		"source_player_name": _person_name_from_dict(source_player),
		"components": []
	}

	var stats_raw: Variant = extract_rules.get("stats", [])
	if typeof(stats_raw) == TYPE_ARRAY:
		var stat_keys: Array = _safe_array(stats_raw)
		if stat_keys.is_empty():
			stat_keys = _default_stat_keys()
		out ["stats"] = _extract_stats(source_player, stat_keys)
		out ["components"].append("stats")

	var inventory_raw: Variant = extract_rules.get("inventory", "none")
	var inventory_enabled: bool = false
	if typeof(inventory_raw) == TYPE_DICTIONARY:
		inventory_enabled = bool((inventory_raw as Dictionary).get("enabled", true))
	elif str(inventory_raw).strip_edges().to_lower() not in ["", "none", "false", "disabled"]:
		inventory_enabled = true

	if inventory_enabled:
		out ["inventory"] = _extract_inventory(payload, source_player, inventory_raw)
		out ["components"].append("inventory")

	var bending_rules: Dictionary = _safe_dictionary(extract_rules.get("bending", {}))
	if bool(bending_rules.get("skills", false)) or bool(bending_rules.get("enabled", false)):
		out ["bending"] = {
			"bending_type": str(source_player.get("bending_type", "none")),
			"bending_nation": str(source_player.get("bending_nation", "")),
			"bending_mastery": _safe_dictionary(source_player.get("bending_mastery", {})),
			"bending_latent_potential": _safe_dictionary(source_player.get("bending_latent_potential", {})),
			"avatar_state_unlocked": bool(source_player.get("avatar_state_unlocked", false))
		}
		out ["components"].append("bending")

	var traits_rules: Dictionary = _safe_dictionary(extract_rules.get("traits", {}))
	if not traits_rules.is_empty():
		out ["traits"] = _extract_traits(source_player, traits_rules)
		out ["components"].append("traits")

	var consciousness_rules: Dictionary = _safe_dictionary(extract_rules.get("consciousness", {}))
	if bool(consciousness_rules.get("enabled", false)):
		out ["consciousness"] = _extract_consciousness(source_player, consciousness_rules)
		out ["components"].append("consciousness")

	if bool(extract_rules.get("money", false)):
		out ["money"] = _extract_money(payload, source_player)
		out ["components"].append("money")
	return _make_binary_safe(out)

func _extract_consciousness(source_player: Dictionary, rules: Dictionary) -> Dictionary:
	var memory_echo_limit: int = max(0, int(rules.get("memory_echo_limit", 8)))
	var memories: Array = _safe_array(source_player.get("consciousness_memory_index", []))
	var selected_memories: Array = []

	if memory_echo_limit > 0 and memories.size() > memory_echo_limit:
		selected_memories = memories.slice(max(0, memories.size() - memory_echo_limit), memories.size())
	else:
		selected_memories = memories.duplicate(true)

	return {
		"consciousness_contract": _safe_dictionary(source_player.get("consciousness_contract", {})),
		"consciousness_state": _safe_dictionary(source_player.get("consciousness_state", {})),
		"memory_echoes": selected_memories,
		"identity_residue": _safe_dictionary(source_player.get("identity_residue", {}))
	}
func _apply_components_to_target(target, source_player: Dictionary, payload: Dictionary, extraction: Dictionary, contract: Dictionary) -> Dictionary:
	if target == null:
		return {
			"success": false,
			"reason": "Target player is missing."
		}
	var transform: Dictionary = _safe_dictionary(contract.get("transform", {}))
	var changed_components: Array = []
	var details: Dictionary = {}
	if extraction.has("stats"):
		var stats_report: Dictionary = _apply_stats_to_target(target, _safe_dictionary(extraction.get("stats", {})), _safe_dictionary(transform.get("stats", {})))
		details ["stats"] = stats_report
		if bool(stats_report.get("success", false)):
			changed_components.append("stats")
	if extraction.has("inventory"):
		var inventory_report: Dictionary = _apply_inventory_to_target(target, payload, extraction.get("inventory", {}), _safe_dictionary(transform.get("inventory", {})))
		details ["inventory"] = inventory_report
		if bool(inventory_report.get("success", false)):
			changed_components.append("inventory")
	if extraction.has("bending"):
		var bending_report: Dictionary = _apply_bending_to_target(target, _safe_dictionary(extraction.get("bending", {})), _safe_dictionary(transform.get("bending", {})), source_player)
		details ["bending"] = bending_report
		if bool(bending_report.get("success", false)):
			changed_components.append("bending")
	if extraction.has("traits"):
		var traits_report: Dictionary = _apply_traits_to_target(target, _safe_array(extraction.get("traits", [])), _safe_dictionary(transform.get("traits", {})), source_player)
		details ["traits"] = traits_report
		if bool(traits_report.get("success", false)):
			changed_components.append("traits")
	if extraction.has("consciousness"):
		var consciousness_report: Dictionary = _apply_consciousness_to_target(
			target,
			_safe_dictionary(extraction.get("consciousness", {})),
			_safe_dictionary(transform.get("consciousness", {})),
			source_player
		)
		details ["consciousness"] = consciousness_report
		if bool(consciousness_report.get("success", false)):
			changed_components.append("consciousness")

	if extraction.has("money"):
		var money_report: Dictionary = _apply_money_to_target(target, _safe_dictionary(extraction.get("money", {})), _safe_dictionary(transform.get("money", {})))
		details ["money"] = money_report
		if bool(money_report.get("success", false)):
			changed_components.append("money")
	return {
		"success": not changed_components.is_empty(),
		"changed_components": changed_components,
		"details": details
	}
func _apply_consciousness_to_target(target, consciousness: Dictionary, rules: Dictionary, source_player: Dictionary) -> Dictionary:
	if target == null:
		return {
			"success": false,
			"reason": "Target player is missing."
		}

	if gs == null or gs.consciousness_engine == null:
		return {
			"success": false,
			"reason": "ConsciousnessEngine unavailable."
		}

	var target_contract: Dictionary = gs.consciousness_engine.ensure_consciousness(target, {
		"source": "reality_fusion_pre_merge"
	})

	var source_contract: Dictionary = _safe_dictionary(consciousness.get("consciousness_contract", {}))
	var memory_echoes: Array = _safe_array(consciousness.get("memory_echoes", []))

	var continuity: Dictionary = _safe_dictionary(target_contract.get("continuity", {}))
	var awareness: Dictionary = _safe_dictionary(target_contract.get("awareness", {}))

	continuity ["identity_drift"] = clamp(float(continuity.get("identity_drift", 0.1)) + float(rules.get("identity_drift_gain", 0.04)), 0.0, 1.0)
	continuity ["cross_universe_memory"] = true
	awareness ["multiverse_awareness"] = clamp(float(awareness.get("multiverse_awareness", 0.05)) + float(rules.get("multiverse_awareness_gain", 0.02)), 0.0, 1.0)

	target_contract ["continuity"] = continuity
	target_contract ["awareness"] = awareness
	target.consciousness_contract = target_contract

	var source_name: String = _person_name_from_dict(source_player)
	var applied_memories: int = 0

	for raw_memory in memory_echoes:
		if typeof(raw_memory) != TYPE_DICTIONARY:
			continue
		var memory: Dictionary = raw_memory
		var memory_text: String = str(memory.get("text", "")).strip_edges()
		if memory_text == "":
			continue

		gs.consciousness_engine.remember(target, "An echo from %s's consciousness surfaced: %s" % [source_name, memory_text], {
			"source": "reality_fusion",
			"memory_type": "cross_universe_echo",
			"perspective": "first_person",
			"emotion_tags": ["reality_fusion", "identity_echo"],
			"emotional_weight": float(memory.get("salience", 1.0))
		})
		applied_memories += 1

	gs.consciousness_engine.apply_consciousness_modifier(target, {
		"id": "reality_fusion",
		"source": "reality_fusion",
		"intensity": 1.0
	})

	return {
		"success": true,
		"mode": str(rules.get("mode", "echo_merge")),
		"source_contract_present": not source_contract.is_empty(),
		"memory_echoes_applied": applied_memories,
		"source_player_name": source_name
	}

func _apply_stats_to_target(target, source_stats: Dictionary, rules: Dictionary) -> Dictionary:
	var mode: String = str(rules.get("mode", "weighted_blend")).strip_edges().to_lower()
	var weight_self: float = float(rules.get("weight_self", 0.7))
	var weight_source: float = float(rules.get("weight_source", 0.3))
	var soft_cap: float = float(rules.get("cap", 100.0))
	var allow_overcap: bool = bool(rules.get("allow_overcap", true))
	var hard_cap: float = float(rules.get("hard_cap", 250.0))
	var overcap_destabilizes: bool = bool(rules.get("overcap_destabilizes", true))

	var changed_stats: Dictionary = {}
	var overcap_stats: Dictionary = {}

	for raw_key in source_stats.keys():
		var stat_name: String = str(raw_key).strip_edges()
		if stat_name == "":
			continue

		var source_value: float = float(source_stats.get(stat_name, 0.0))
		var current_value: float = float(target.get(stat_name))
		var next_value: float = current_value

		match mode:
			"overwrite":
				next_value = source_value
			"add":
				next_value = current_value + source_value
			"max":
				next_value = max(current_value, source_value)
			_:
				next_value = (current_value * weight_self) + (source_value * weight_source)

		if allow_overcap:
			next_value = max(0.0, next_value)
			if hard_cap > 0.0:
				next_value = min(next_value, hard_cap)
		else:
			next_value = clamp(next_value, 0.0, soft_cap)

		if next_value > soft_cap:
			overcap_stats [stat_name] = {
				"before": current_value,
				"source": source_value,
				"after": next_value,
				"soft_cap": soft_cap,
				"over_by": next_value - soft_cap,
				"mode": mode
			}

		if _stat_should_be_int(stat_name):
			target.set(stat_name, int(round(next_value)))
		else:
			target.set(stat_name, next_value)

		changed_stats [stat_name] = {
			"before": current_value,
			"source": source_value,
			"after": next_value,
			"mode": mode,
			"soft_cap": soft_cap,
			"overcap": next_value > soft_cap
		}

	if overcap_destabilizes and not overcap_stats.is_empty():
		_record_reality_fusion_stat_overcap(target, overcap_stats, rules)

	return {
		"success": not changed_stats.is_empty(),
		"changed": changed_stats,
		"overcap": overcap_stats,
		"destabilized": not overcap_stats.is_empty()
	}
func _record_reality_fusion_stat_overcap(target, overcap_stats: Dictionary, rules: Dictionary) -> void:
	if gs == null or target == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var instability_multiplier: float = float(rules.get("overcap_instability_multiplier", 0.08))
	var instability_gain: float = 0.0

	for raw_key in overcap_stats.keys():
		var stat_report: Dictionary = _safe_dictionary(overcap_stats.get(raw_key, {}))
		instability_gain += max(0.0, float(stat_report.get("over_by", 0.0))) * instability_multiplier

	instability_gain = max(1.0, instability_gain)

	gs.scenario_state ["reality_fusion_identity_instability"] = float(
		gs.scenario_state.get("reality_fusion_identity_instability", 0.0)
	) + instability_gain

	gs.scenario_state ["reality_fusion_stat_overcap"] = _make_binary_safe(overcap_stats)
	gs.scenario_state ["reality_fusion_stat_overcap_at_ms"] = int(Time.get_ticks_msec())

	if "identity_residue" in target and typeof(target.identity_residue) == TYPE_DICTIONARY:
		target.identity_residue ["reality_fusion_overcap"] = {
			"stats": _make_binary_safe(overcap_stats),
			"instability_gain": instability_gain,
			"created_at_ms": int(Time.get_ticks_msec())
		}

func _apply_bending_to_target(target, bending: Dictionary, rules: Dictionary, source_player: Dictionary) -> Dictionary:
	var cap: float = float(rules.get("cap", 100.0))
	var mode: String = str(rules.get("mode", "skill_transfer")).strip_edges().to_lower()
	var changed_bending: Dictionary = {}
	var source_mastery: Dictionary = _safe_dictionary(bending.get("bending_mastery", {}))
	var target_mastery: Dictionary = {}
	if typeof(target.bending_mastery) == TYPE_DICTIONARY:
		target_mastery = target.bending_mastery.duplicate(true)
	for raw_key in source_mastery.keys():
		var element: String = str(raw_key).strip_edges()
		if element == "":
			continue
		var current_value: float = float(target_mastery.get(element, 0))
		var source_value: float = float(source_mastery.get(element, 0))
		var next_value: float = current_value
		match mode:
			"overwrite":
				next_value = source_value
			"blend":
				next_value = (current_value * 0.65) + (source_value * 0.35)
			_:
				next_value = max(current_value, source_value)
		next_value = clamp(next_value, 0.0, cap)
		target_mastery [element] = int(round(next_value))
		changed_bending [element] = {
			"before": current_value,
			"source": source_value,
			"after": next_value
		}
	target.bending_mastery = target_mastery
	var source_type: String = str(bending.get("bending_type", "none")).strip_edges().to_lower()
	if source_type != "" and source_type != "none":
		if str(target.bending_type).strip_edges().to_lower() in ["", "none"]:
			target.bending_type = source_type
		elif source_type == "avatar" and bool(rules.get("multiple_avatar_influence", true)):
			target.bending_type = "avatar"
			_record_avatar_influence(source_player)
	if bool(bending.get("avatar_state_unlocked", false)) and bool(rules.get("multiple_avatar_influence", true)):
		target.avatar_state_unlocked = true
		_record_avatar_influence(source_player)
	return {
		"success": not changed_bending.is_empty() or source_type != "none",
		"changed": changed_bending,
		"bending_type": str(target.bending_type)
	}


func _apply_traits_to_target(target, traits: Array, rules: Dictionary, source_player: Dictionary) -> Dictionary:
	var mode: String = str(rules.get("mode", "union")).strip_edges().to_lower()
	var mutation_chance: float = float(rules.get("mutation_chance", 0.0))
	var before: Array = target.traits.duplicate()
	var added: Array = []
	if mode == "overwrite":
		target.traits = traits.duplicate()
		added = target.traits.duplicate()
	else:
		for raw_trait in traits:
			var trait_name: String = str(raw_trait).strip_edges()
			if trait_name == "":
				continue
			if trait_name not in target.traits:
				target.traits.append(trait_name)
				added.append(trait_name)
	var mutation_roll: float = _seeded_unit("%s|traits|%s" % [
		_person_name_from_dict(source_player),
		str(before)
	])
	if mutation_chance > 0.0 and mutation_roll < mutation_chance:
		if "Reality-Touched" not in target.traits:
			target.traits.append("Reality-Touched")
			added.append("Reality-Touched")
	return {
		"success": not added.is_empty() or mode == "overwrite",
		"before": before,
		"added": added,
		"after": target.traits.duplicate()
	}


func _apply_money_to_target(target, money: Dictionary, rules: Dictionary) -> Dictionary:
	var multiplier: float = float(rules.get("multiplier", 0.25))
	var cap: float = float(rules.get("cap", 1000000.0))
	var source_cash: float = float(money.get("bank_balance", 0.0))
	var transfer_amount: float = clamp(source_cash * multiplier, 0.0, cap)
	var before: float = float(target.bank_balance)
	target.bank_balance = before + transfer_amount

	return {
		"success": transfer_amount > 0.0,
		"before": before,
		"source_bank_balance": source_cash,
		"transfer_amount": transfer_amount,
		"after": float(target.bank_balance)
	}


func _apply_inventory_to_target(target, _payload: Dictionary, inventory: Variant, rules: Dictionary) -> Dictionary:
	if gs == null:
		return {
			"success": false,
			"reason": "GameState missing."
		}

	if gs.belongings_engine != null and gs.belongings_engine.has_method("apply_reality_fusion_inventory"):
		var engine_report: Variant = gs.belongings_engine.apply_reality_fusion_inventory(target.id, inventory, rules)
		if typeof(engine_report) == TYPE_DICTIONARY:
			return engine_report

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var cache_raw: Variant = gs.scenario_state.get("reality_fusion_pending_inventory", [])
	var cache: Array = cache_raw.duplicate(true) if typeof(cache_raw) == TYPE_ARRAY else []
	cache.append({
		"target_id": int(target.id),
		"inventory": _make_binary_safe(inventory),
		"rules": rules.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec())
	})
	gs.scenario_state ["reality_fusion_pending_inventory"] = cache

	return {
		"success": true,
		"mode": "cached_for_belongings_engine",
		"reason": "BelongingsEngine has no fusion adapter yet, so inventory was preserved as a pending fusion packet."
	}


func _extract_stats(source_player: Dictionary, stat_keys: Array) -> Dictionary:
	var out: Dictionary = {}
	for raw_key in stat_keys:
		var key: String = str(raw_key).strip_edges()
		if key == "":
			continue
		if source_player.has(key):
			var value: Variant = source_player.get(key)
			if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
				out [key] = value
	return out


func _extract_traits(source_player: Dictionary, rules: Dictionary) -> Array:
	var source_traits: Array = _safe_array(source_player.get("traits", []))
	var include: Array = _safe_array(rules.get("include", []))
	var exclude: Array = _safe_array(rules.get("exclude", []))
	var out: Array = []
	for raw_trait in source_traits:
		var trait_name: String = str(raw_trait).strip_edges()
		if trait_name == "":
			continue
		var lower_trait: String = trait_name.to_lower()
		var excluded: bool = false
		for raw_exclude in exclude:
			if lower_trait == str(raw_exclude).strip_edges().to_lower():
				excluded = true
				break
		if excluded:
			continue
		if not include.is_empty():
			var included: bool = false
			for raw_include in include:
				if lower_trait == str(raw_include).strip_edges().to_lower():
					included = true
					break
			if not included:
				continue
		out.append(trait_name)
	return out


func _extract_money(payload: Dictionary, source_player: Dictionary) -> Dictionary:
	return {
		"bank_balance": float(source_player.get("bank_balance", 0.0)),
		"bank_engine_state": _safe_dictionary(payload.get("bank_engine_state", {}))
	}


func _extract_inventory(payload: Dictionary, source_player: Dictionary, inventory_rules: Variant) -> Dictionary:
	var out: Dictionary = {
		"owner_id": int(source_player.get("id", -1)),
		"rules": _make_binary_safe(inventory_rules),
		"raw": {}
	}

	for key in ["belongings", "belongings_engine_state", "heirlooms", "artifacts_ownership", "dragonballs_ownership"]:
		if payload.has(key):
			out ["raw"] [key] = _make_binary_safe(payload.get(key))

	var slices: Dictionary = _safe_dictionary(payload.get("slices", {}))
	for raw_key in slices.keys():
		var save_key: String = str(raw_key)
		var lower_key: String = save_key.to_lower()
		if lower_key.find("belonging") >= 0 or lower_key.find("inventory") >= 0 or lower_key.find("artifact") >= 0:
			out ["raw"] [save_key] = _make_binary_safe(slices.get(raw_key))

	return out


func _reconcile_source_world(path: String, payload: Dictionary, source_player: Dictionary, extraction: Dictionary, contract: Dictionary) -> Dictionary:
	var reconcile: Dictionary = _safe_dictionary(contract.get("reconcile", {}))
	var source_world_mode: String = str(reconcile.get("source_world", "unchanged")).strip_edges().to_lower()
	var write_source_save: bool = bool(reconcile.get("write_source_save", false))
	if source_world_mode in ["", "unchanged", "none", "clean_multiverse_steal"]:
		return {
			"success": true,
			"source_world": "unchanged"
		}
	var source_changes: Array = []
	if source_world_mode in ["remove_extracted", "destabilize", "drain_source"]:
		if extraction.has("stats"):
			var source_stats: Dictionary = _safe_dictionary(extraction.get("stats", {}))
			for raw_key in source_stats.keys():
				var stat_name: String = str(raw_key)
				var before_value: float = float(source_player.get(stat_name, 0.0))
				var after_value: float = max(0.0, before_value * 0.85)
				if _stat_should_be_int(stat_name):
					source_player [stat_name] = int(round(after_value))
				else:
					source_player [stat_name] = after_value
				source_changes.append("source_stat:%s" % stat_name)
		if extraction.has("money"):
			var money: Dictionary = _safe_dictionary(extraction.get("money", {}))
			var before_bank: float = float(source_player.get("bank_balance", 0.0))
			var removed: float = min(before_bank, float(money.get("bank_balance", 0.0)) * 0.25)
			source_player ["bank_balance"] = before_bank - removed
			source_changes.append("source_money")
		if extraction.has("bending"):
			var mastery: Dictionary = _safe_dictionary(source_player.get("bending_mastery", {}))
			for element in mastery.keys():
				mastery [element] = int(round(float(mastery [element]) * 0.9))
			source_player ["bending_mastery"] = mastery
			source_changes.append("source_bending")
	_write_source_player_into_payload(payload, source_player)
	if source_world_mode == "destabilize":
		var destabilized: Dictionary = _safe_dictionary(payload.get("scenario_state", {}))
		destabilized ["reality_fusion_destabilized"] = true
		destabilized ["reality_fusion_destabilized_at_ms"] = int(Time.get_ticks_msec())
		payload ["scenario_state"] = destabilized
		source_changes.append("source_world_destabilized")
	if write_source_save:
		var write_report: Dictionary = _write_payload_to_path(path, payload)
		return {
			"success": bool(write_report.get("success", false)),
			"source_world": source_world_mode,
			"changed": source_changes,
			"write_report": write_report
		}
	return {
		"success": true,
		"source_world": source_world_mode,
		"changed": source_changes,
	}


func _write_source_player_into_payload(payload: Dictionary, source_player: Dictionary) -> void:
	var player_id: int = int(source_player.get("id", -1))
	var npcs_raw: Variant = payload.get("npcs", [])
	if typeof(npcs_raw) != TYPE_ARRAY:
		return

	var npcs: Array = npcs_raw
	for i in range(npcs.size()):
		var raw_row: Variant = npcs [i]
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = raw_row
		if int(row.get("id", -1)) == player_id:
			npcs [i] = source_player.duplicate(true)
			payload ["npcs"] = npcs
			return


func _apply_balance_cost(contract: Dictionary, report: Dictionary) -> void:
	if gs == null or gs.player == null:
		return

	var balance: Dictionary = _safe_dictionary(contract.get("balance", {}))
	var fatigue_cost: float = float(balance.get("fatigue_cost", 0.0))
	var mental_strain: float = float(balance.get("mental_strain", 0.0))
	var instability: float = float(balance.get("identity_instability", 0.0))
	var cooldown_ms: int = int(balance.get("cooldown_ms", 0))

	if fatigue_cost > 0.0:
		gs.player.health = clamp(float(gs.player.health) - fatigue_cost, 0.0, 100.0)

	if mental_strain > 0.0:
		gs.player.mental_health = clamp(float(gs.player.mental_health) - mental_strain, 0.0, 100.0)

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	if instability > 0.0:
		gs.scenario_state ["reality_fusion_identity_instability"] = float(gs.scenario_state.get("reality_fusion_identity_instability", 0.0)) + instability

	if cooldown_ms > 0:
		gs.scenario_state ["reality_fusion_next_allowed_ms"] = int(Time.get_ticks_msec()) + cooldown_ms

	report ["balance_applied"] = {
		"fatigue_cost": fatigue_cost,
		"mental_strain": mental_strain,
		"identity_instability": instability,
		"cooldown_ms": cooldown_ms
	}


func _cooldown_report(contract: Dictionary) -> Dictionary:
	if gs == null or typeof(gs.scenario_state) != TYPE_DICTIONARY:
		return {
			"blocked": false
		}

	var balance: Dictionary = _safe_dictionary(contract.get("balance", {}))
	if bool(balance.get("ignore_cooldown", false)):
		return {
			"blocked": false
		}

	var now_ms: int = int(Time.get_ticks_msec())
	var next_allowed_ms: int = int(gs.scenario_state.get("reality_fusion_next_allowed_ms", 0))
	if next_allowed_ms <= now_ms:
		return {
			"blocked": false
		}

	return {
		"blocked": true,
		"reason": "Reality Fusion is cooling down for %d ms." % max(0, next_allowed_ms - now_ms),
		"next_allowed_ms": next_allowed_ms,
		"remaining_ms": max(0, next_allowed_ms - now_ms)
	}


func _roll_source_resistance(source_player: Dictionary, contract: Dictionary, path: String) -> Dictionary:
	var resistance: Dictionary = _safe_dictionary(contract.get("source_resistance", {}))
	if not bool(resistance.get("enabled", false)):
		return {
			"blocked": false,
			"enabled": false
		}

	var base_chance: float = float(resistance.get("chance", 0.0))
	var source_smarts: float = float(source_player.get("smarts", 50))
	var source_mental: float = float(source_player.get("mental_health", 50))
	var source_fame: float = float(source_player.get("fame", 0))
	var stat_pressure: float = clamp(((source_smarts + source_mental + source_fame) / 300.0) * 0.18, 0.0, 0.18)
	var chance: float = clamp(base_chance + stat_pressure, 0.0, 0.95)
	var roll: float = _seeded_unit("%s|%s|%s|%d" % [
		path,
		_person_name_from_dict(source_player),
		str(contract.get("mode", "")),
		int(Time.get_unix_time_from_system() / 60)
	])

	var blocked: bool = roll < chance
	return {
		"blocked": blocked,
		"enabled": true,
		"chance": chance,
		"roll": roll,
		"reason": "They fought back and stopped the fusion." if blocked else ""
	}


func _record_avatar_influence(source_player: Dictionary) -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var stack_raw: Variant = gs.scenario_state.get("avatar_influence_stack", [])
	var stack: Array = stack_raw.duplicate(true) if typeof(stack_raw) == TYPE_ARRAY else []
	stack.append({
		"source_player_id": int(source_player.get("id", -1)),
		"source_player_name": _person_name_from_dict(source_player),
		"created_at_ms": int(Time.get_ticks_msec())
	})
	gs.scenario_state ["avatar_influence_stack"] = stack


func _commit_fusion_report(report: Dictionary) -> void:
	last_fusion_report = _make_binary_safe(report)
	fusion_ledger.append(last_fusion_report.duplicate(true))
	if fusion_ledger.size() > 50:
		fusion_ledger = fusion_ledger.slice(fusion_ledger.size() - 50, fusion_ledger.size())

	_store_ledger_to_game_state()


func _store_ledger_to_game_state() -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	gs.scenario_state ["reality_fusion_ledger"] = fusion_ledger.duplicate(true)
	gs.scenario_state ["last_reality_fusion_report"] = last_fusion_report.duplicate(true)


func _hydrate_ledger_from_game_state() -> void:
	if gs == null or typeof(gs.scenario_state) != TYPE_DICTIONARY:
		return

	var ledger_raw: Variant = gs.scenario_state.get("reality_fusion_ledger", [])
	if typeof(ledger_raw) == TYPE_ARRAY:
		fusion_ledger = (ledger_raw as Array).duplicate(true)

	var last_raw: Variant = gs.scenario_state.get("last_reality_fusion_report", {})
	if typeof(last_raw) == TYPE_DICTIONARY:
		last_fusion_report = (last_raw as Dictionary).duplicate(true)


func _source_player_from_payload(payload: Dictionary) -> Dictionary:
	var player_id: int = int(payload.get("player_id", -1))
	var npcs: Array = _safe_array(payload.get("npcs", []))

	for raw_npc in npcs:
		if typeof(raw_npc) != TYPE_DICTIONARY:
			continue
		var npc: Dictionary = raw_npc
		if int(npc.get("id", -1)) == player_id:
			return npc.duplicate(true)

	return {}


func _decode_payload_from_path(path: String) -> Dictionary:
	var lower_path: String = str(path).to_lower()

	if lower_path.ends_with(".bin"):
		var f_bin = FileAccess.open(path, FileAccess.READ)
		if f_bin == null:
			return {
				"success": false,
				"reason": "Failed to open binary fusion source.",
				"path": path
			}

		var bytes: PackedByteArray = f_bin.get_buffer(f_bin.get_length())
		f_bin.close()

		var decoded: Variant = BinarySaveEngine.decode(bytes)
		if typeof(decoded) != TYPE_DICTIONARY:
			return {
				"success": false,
				"reason": "Binary fusion source is corrupted.",
				"path": path
			}

		return {
			"success": true,
			"format": "binary",
			"data": decoded
		}

	var f_json = FileAccess.open(path, FileAccess.READ)
	if f_json == null:
		return {
			"success": false,
			"reason": "Failed to open JSON fusion source.",
			"path": path
		}

	var parsed: Variant = JSON.parse_string(f_json.get_as_text())
	f_json.close()

	if typeof(parsed) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "JSON fusion source is corrupted.",
			"path": path
		}

	return {
		"success": true,
		"format": "json",
		"data": parsed
	}


func _write_payload_to_path(path: String, payload: Dictionary) -> Dictionary:
	var lower_path: String = str(path).to_lower()

	if lower_path.ends_with(".bin"):
		var bytes: PackedByteArray = BinarySaveEngine.encode(payload)
		var f_bin = FileAccess.open(path, FileAccess.WRITE)
		if f_bin == null:
			return {
				"success": false,
				"reason": "Failed to write reconciled binary source.",
				"path": path
			}
		f_bin.store_buffer(bytes)
		f_bin.close()
		return {
			"success": true,
			"format": "binary",
			"path": path
		}

	var f_json = FileAccess.open(path, FileAccess.WRITE)
	if f_json == null:
		return {
			"success": false,
			"reason": "Failed to write reconciled JSON source.",
			"path": path
		}

	f_json.store_string(JSON.stringify(payload, "\t"))
	f_json.close()

	return {
		"success": true,
		"format": "json",
		"path": path
	}


func _fusion_world_feed_line(report: Dictionary) -> String:
	var mode: String = str(report.get("mode", "fusion")).strip_edges()
	var source_name: String = str(report.get("source_player_name", "another life")).strip_edges()
	if source_name == "":
		source_name = "another life"

	match mode:
		"stats_blend":
			return "Reality bent softly. You absorbed echoes of %s's stats." % source_name
		"stats_steal":
			return "Reality cracked. You stole power from %s's universe." % source_name
		"bending_transfer":
			return "The elements remembered %s and answered you." % source_name
		"traits_merge":
			return "Your personality picked up fragments from %s's timeline." % source_name
		"money_transfer":
			return "A multiverse account transfer cleared from %s's reality." % source_name
		"inventory_merge":
			return "Objects from %s's universe are now bound to your timeline." % source_name
		_:
			return "Reality Fusion completed with %s's universe." % source_name


func _push_world_feed(text: String) -> void:
	if gs == null:
		return
	if gs.has_method("push_world_feed"):
		gs.push_world_feed(text, {
			"category": "reality_fusion",
			"personally_relevant": true
		})


func _default_stat_keys() -> Array:
	return [
		"health",
		"mental_health",
		"smarts",
		"looks",
		"imagination",
		"fertility",
		"satisfaction",
		"job_performance",
		"motivation",
		"ambition",
		"fame"
	]


func _stat_should_be_int(stat_name: String) -> bool:
	return stat_name in [
		"smarts",
		"looks",
		"imagination",
		"job_performance",
		"job_experience",
		"unemployed_years",
		"hours_worked_last_year",
		"fame",
		"scandal",
		"paparazzi_heat",
		"approval",
		"succession_rank",
		"class_mobility",
		"dynasty_prestige"
	]
func _source_identity_from_player(source_player: Dictionary) -> String:
	var bits: Array = []

	var bending_type: String = str(source_player.get("bending_type", "none")).strip_edges()
	if bending_type != "" and bending_type.to_lower() != "none":
		if bending_type.to_lower() == "avatar":
			bits.append("Avatar")
		else:
			bits.append("%s bender" % bending_type.capitalize())

	var title_text: String = str(source_player.get("title", source_player.get("royal_title", ""))).strip_edges()
	if title_text != "":
		bits.append(title_text)

	var job_text: String = str(source_player.get("job", source_player.get("career", ""))).strip_edges()
	if job_text != "":
		bits.append(job_text)

	var traits: Array = _safe_array(source_player.get("traits", []))
	if not traits.is_empty():
		bits.append("%d trait echoes" % traits.size())

	if bits.is_empty():
		return "parallel identity"

	return ", ".join(bits)


func _source_power_profile(source_player: Dictionary) -> Dictionary:
	var stats: Dictionary = _extract_stats(source_player, _default_stat_keys())
	var bending_mastery: Dictionary = _safe_dictionary(source_player.get("bending_mastery", {}))
	var bending_type: String = str(source_player.get("bending_type", "none")).strip_edges().to_lower()
	var traits: Array = _safe_array(source_player.get("traits", []))

	var max_bending: float = _max_number_in_dictionary(bending_mastery)
	var stat_pressure: float = (
		float(stats.get("health", source_player.get("health", 50))) +
		float(stats.get("smarts", source_player.get("smarts", 50))) +
		float(stats.get("mental_health", source_player.get("mental_health", 50))) +
		float(stats.get("fame", source_player.get("fame", 0)))
	) / 4.0

	var has_power: bool = false
	if bending_type != "" and bending_type != "none":
		has_power = true
	if max_bending > 0.0:
		has_power = true
	if bool(source_player.get("avatar_state_unlocked", false)):
		has_power = true

	for raw_trait in traits:
		var trait_text: String = str(raw_trait).strip_edges().to_lower()
		if trait_text.find("vampire") >= 0 \
or trait_text.find("avatar") >= 0 \
or trait_text.find("super") >= 0 \
or trait_text.find("cosmic") >= 0 \
or trait_text.find("reality") >= 0:
			has_power = true
			break

	return {
		"has_power": has_power,
		"bending_type": bending_type,
		"max_bending": max_bending,
		"stat_pressure": stat_pressure,
		"avatar_state_unlocked": bool(source_player.get("avatar_state_unlocked", false)),
		"traits": traits.duplicate(true)
	}


func _max_number_in_dictionary(data: Dictionary) -> float:
	var highest: float = 0.0
	for raw_key in data.keys():
		var value: Variant = data.get(raw_key)
		if typeof(value) == TYPE_DICTIONARY:
			highest = max(highest, _max_number_in_dictionary(value as Dictionary))
		elif typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
			highest = max(highest, float(value))
	return highest

func _person_name_from_dict(data: Dictionary) -> String:
	var full_name: String = str(data.get("name", "")).strip_edges()
	if full_name != "":
		return full_name

	return ("%s %s" % [
		str(data.get("first_name", "")),
		str(data.get("last_name", ""))
	]).strip_edges()


func _person_name_from_object(person) -> String:
	if person == null:
		return ""

	return ("%s %s" % [
		str(person.first_name),
		str(person.last_name)
	]).strip_edges()


func _seeded_unit(seed_text: String) -> float:
	var seed_value: int = abs(hash(seed_text))
	return float(seed_value % 10000) / 10000.0


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)


func _merge_dict(base: Dictionary, patch: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)

	for key in patch.keys():
		var patch_value: Variant = patch.get(key)
		if typeof(patch_value) == TYPE_DICTIONARY and typeof(out.get(key, {})) == TYPE_DICTIONARY:
			out [key] = _merge_dict(out.get(key, {}), patch_value)
		else:
			out [key] = patch_value

	return out


func _make_binary_safe(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var out:= {}
			for key in value.keys():
				out [str(key)] = _make_binary_safe(value [key])
			return out
		TYPE_ARRAY:
			var arr:= []
			for item in value:
				arr.append(_make_binary_safe(item))
			return arr
		TYPE_COLOR:
			var c: Color = value
			return "#%s" % c.to_html(true)
		TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_BOOL:
			return value
		TYPE_NIL:
			return null
		_:
			return str(value)


func _fail_report(reason_id: String, reason: String, started_at: int, extra: Dictionary = {}) -> Dictionary:
	var report: Dictionary = {
		"schema": FUSION_REPORT_SCHEMA,
		"version": REALITY_FUSION_VERSION,
		"success": false,
		"reason_id": reason_id,
		"reason": reason,
		"started_at_ms": started_at,
		"finished_at_ms": int(Time.get_ticks_msec())
	}
	report ["duration_ms"] = int(report ["finished_at_ms"]) - started_at

	for key in extra.keys():
		report [key] = extra [key]

	last_fusion_report = _make_binary_safe(report)
	_store_ledger_to_game_state()
	return report