extends Resource
class_name WillpowerEngine

const WILLPOWER_VERSION:= 1
const WILLPOWER_SCHEMA:= "eralife.willpower_contract"

var gs
var last_willpower_report: Dictionary = {}
var willpower_reports: Array = []

func _init(_gs = null):
	gs = _gs

func ensure_willpower(person: Person, context: Dictionary = {}) -> Dictionary:
	if person == null:
		return {}

	var existing: Dictionary = _safe_dictionary(person.willpower_profile)
	var should_birth_seed: bool = bool(context.get("force_birth_willpower_seed", false)) or _willpower_profile_needs_birth_seed(existing)

	var profile: Dictionary = _default_willpower_profile(person, context)
	if should_birth_seed:
		var existing_degradation: Dictionary = _safe_dictionary(existing.get("degradation", {}))
		var existing_duel_state: Dictionary = _safe_dictionary(existing.get("duel_state", {}))
		if not existing_degradation.is_empty():
			profile ["degradation"] = _merge_dict(_safe_dictionary(profile.get("degradation", {})), existing_degradation)
		if not existing_duel_state.is_empty():
			profile ["duel_state"] = _merge_dict(_safe_dictionary(profile.get("duel_state", {})), existing_duel_state)
	else:
		profile = _merge_dict(profile, existing)

	var resistance: Dictionary = _safe_dictionary(profile.get("resistance", {}))
	var persistence: Dictionary = _safe_dictionary(profile.get("persistence", {}))
	var reality_defiance: Dictionary = _safe_dictionary(profile.get("reality_defiance", {}))
	var degradation: Dictionary = _safe_dictionary(profile.get("degradation", {}))
	var duel_state: Dictionary = _safe_dictionary(profile.get("duel_state", {}))

	var avatar_state_active: bool = _avatar_state_willpower_active(person)
	var active_cap: float = _willpower_score_cap(person, context)
	var avatar_floor: float = _avatar_state_willpower_floor()
	var base_score: float = clamp(float(profile.get("core_score", _personal_willpower_seed_score(person))), 0.0, active_cap)

	resistance ["emotional_resistance"] = clamp(float(resistance.get("emotional_resistance", base_score)), 0.0, active_cap)
	resistance ["fear_resistance"] = clamp(float(resistance.get("fear_resistance", base_score)), 0.0, active_cap)
	resistance ["pain_resistance"] = clamp(float(resistance.get("pain_resistance", base_score)), 0.0, active_cap)
	resistance ["pressure_resistance"] = clamp(float(resistance.get("pressure_resistance", base_score)), 0.0, active_cap)

	persistence ["long_term_endurance"] = clamp(float(persistence.get("long_term_endurance", base_score)), 0.0, active_cap)
	persistence ["retry_willingness"] = clamp(float(persistence.get("retry_willingness", base_score)), 0.0, active_cap)
	persistence ["failure_tolerance"] = clamp(float(persistence.get("failure_tolerance", base_score)), 0.0, active_cap)

	var fantasy_enabled: bool = _fantasy_context_active(context)
	reality_defiance ["fate_resistance"] = clamp(float(reality_defiance.get("fate_resistance", 0.0)) + (8.0 if fantasy_enabled else 0.0), 0.0, active_cap)
	reality_defiance ["timeline_stability"] = clamp(float(reality_defiance.get("timeline_stability", 0.0)) + (6.0 if fantasy_enabled else 0.0), 0.0, active_cap)
	reality_defiance ["outcome_rejection_strength"] = clamp(float(reality_defiance.get("outcome_rejection_strength", 0.0)) + (10.0 if fantasy_enabled else 0.0), 0.0, active_cap)

	if avatar_state_active:
		resistance ["emotional_resistance"] = max(float(resistance.get("emotional_resistance", 0.0)), avatar_floor)
		resistance ["fear_resistance"] = max(float(resistance.get("fear_resistance", 0.0)), avatar_floor)
		resistance ["pain_resistance"] = max(float(resistance.get("pain_resistance", 0.0)), avatar_floor)
		resistance ["pressure_resistance"] = max(float(resistance.get("pressure_resistance", 0.0)), avatar_floor)
		persistence ["long_term_endurance"] = max(float(persistence.get("long_term_endurance", 0.0)), avatar_floor)
		persistence ["retry_willingness"] = max(float(persistence.get("retry_willingness", 0.0)), avatar_floor)
		persistence ["failure_tolerance"] = max(float(persistence.get("failure_tolerance", 0.0)), avatar_floor)
		reality_defiance ["fate_resistance"] = max(float(reality_defiance.get("fate_resistance", 0.0)), avatar_floor)
		reality_defiance ["timeline_stability"] = max(float(reality_defiance.get("timeline_stability", 0.0)), avatar_floor)
		reality_defiance ["outcome_rejection_strength"] = max(float(reality_defiance.get("outcome_rejection_strength", 0.0)), avatar_floor)
		duel_state ["avatar_state_willpower_boost_active"] = true
	else:
		duel_state ["avatar_state_willpower_boost_active"] = false

	degradation ["burnout"] = clamp(float(degradation.get("burnout", 0.0)), 0.0, active_cap)
	degradation ["mental_fatigue"] = clamp(float(degradation.get("mental_fatigue", 0.0)), 0.0, active_cap)
	degradation ["collapse_threshold"] = clamp(float(degradation.get("collapse_threshold", 100.0)), 15.0, active_cap)
	degradation ["collapse_pressure"] = clamp(float(degradation.get("collapse_pressure", 0.0)), 0.0, active_cap)

	if avatar_state_active:
		degradation ["collapse_threshold"] = max(float(degradation.get("collapse_threshold", 100.0)), avatar_floor)

	var degradation_load: float = (
		float(degradation.get("burnout", 0.0)) * 0.38
		+ float(degradation.get("mental_fatigue", 0.0)) * 0.34
		+ float(degradation.get("collapse_pressure", 0.0)) * 0.28
	)

	if avatar_state_active:
		degradation_load = 0.0

	var core_score: float = clamp(
		(
			float(resistance.get("emotional_resistance", base_score))
			+ float(resistance.get("fear_resistance", base_score))
			+ float(resistance.get("pain_resistance", base_score))
			+ float(resistance.get("pressure_resistance", base_score))
			+ float(persistence.get("long_term_endurance", base_score))
			+ float(persistence.get("retry_willingness", base_score))
			+ float(persistence.get("failure_tolerance", base_score))
		) / 7.0 - degradation_load * 0.42,
		0.0,
		active_cap
	)

	if avatar_state_active:
		core_score = max(core_score, avatar_floor)

	profile ["schema"] = WILLPOWER_SCHEMA
	profile ["version"] = WILLPOWER_VERSION
	profile ["person_id"] = int(person.id)
	profile ["person_name"] = _person_name(person)
	profile ["core_score"] = core_score
	profile ["active_cap"] = active_cap
	profile ["avatar_state_willpower_active"] = avatar_state_active
	profile ["birth_seeded"] = bool(profile.get("birth_seeded", true))
	profile ["resistance"] = resistance
	profile ["persistence"] = persistence
	profile ["reality_defiance"] = reality_defiance
	profile ["degradation"] = degradation
	profile ["duel_state"] = duel_state
	profile ["updated_at_year"] = _current_year()
	profile ["updated_at_ms"] = int(Time.get_ticks_msec())

	person.willpower = core_score
	person.willpower_profile = _make_binary_safe(profile)
	return person.willpower_profile.duplicate(true)

func score(person: Person, context: Dictionary = {}) -> float:
	if person == null:
		return 0.0
	var profile: Dictionary = ensure_willpower(person, context)
	return clamp(float(profile.get("core_score", person.willpower)), 0.0, _willpower_score_cap(person, context))

func try_reject_duel_outcome(person: Person, duel: Dictionary, context: Dictionary = {}) -> Dictionary:
	if person == null:
		return {
			"triggered": false,
			"reason": "missing_person"
		}

	var profile: Dictionary = ensure_willpower(person, context)
	var resistance: Dictionary = _safe_dictionary(profile.get("resistance", {}))
	var persistence: Dictionary = _safe_dictionary(profile.get("persistence", {}))
	var reality_defiance: Dictionary = _safe_dictionary(profile.get("reality_defiance", {}))
	var degradation: Dictionary = _safe_dictionary(profile.get("degradation", {}))
	var duel_state: Dictionary = _safe_dictionary(profile.get("duel_state", {}))

	var side: String = str(context.get("side", "player")).strip_edges().to_lower()
	var hp_key: String = "player_hp" if side == "player" else str(context.get("hp_key", "target_hp"))
	var hp_max_key: String = "player_hp_max" if side == "player" else str(context.get("hp_max_key", "target_hp_max"))

	var hp_max: int = max(1, int(duel.get(hp_max_key, int(person.health))))
	var current_hp: int = max(0, int(duel.get(hp_key, 0)))
	var damage_pressure: float = 1.0 - clamp(float(current_hp) / float(hp_max), 0.0, 1.0)

	var last_stand_count: int = int(duel_state.get("last_stand_count", 0))
	var loop_count: int = int(context.get("loop_count", 0))
	var avatar_state_active: bool = _avatar_state_willpower_active(person)

	var fantasy_multiplier: float = 1.0
	if _fantasy_context_active(context):
		fantasy_multiplier += 0.22
	if loop_count > 0:
		fantasy_multiplier += clamp(float(loop_count) * 0.05, 0.0, 0.35)
	if avatar_state_active:
		fantasy_multiplier += 4.0

	var resistance_score: float = (
		float(resistance.get("pain_resistance", 50.0)) * 0.3
		+ float(resistance.get("pressure_resistance", 50.0)) * 0.22
		+ float(persistence.get("retry_willingness", 50.0)) * 0.26
		+ float(persistence.get("failure_tolerance", 50.0)) * 0.16
		+ float(reality_defiance.get("outcome_rejection_strength", 0.0)) * 0.18
	) * fantasy_multiplier

	var burnout: float = float(degradation.get("burnout", 0.0))
	var fatigue: float = float(degradation.get("mental_fatigue", 0.0))
	var collapse_pressure: float = float(degradation.get("collapse_pressure", 0.0))
	var difficulty: float = 68.0 + damage_pressure * 28.0 + float(last_stand_count) * 14.0 + burnout * 0.32 + fatigue * 0.24 + collapse_pressure * 0.28

	var roll: float = resistance_score + randf() * 18.0
	var forced: bool = bool(context.get("force", false)) or avatar_state_active
	var triggered: bool = forced or roll >= difficulty

	if not triggered:
		degradation ["collapse_pressure"] = clamp(collapse_pressure + 6.0 + damage_pressure * 10.0, 0.0, _willpower_score_cap(person, context))
		profile ["degradation"] = degradation
		person.willpower_profile = _make_binary_safe(profile)
		person.willpower = score(person, {
			"source": "willpower_failed_outcome_rejection"
		})
		return {
			"triggered": false,
			"roll": roll,
			"difficulty": difficulty,
			"reason": "willpower_broke_before_outcome_rejection"
		}

	var heal_ratio: float = 0.95 if avatar_state_active else clamp(
		0.18
		+ float(profile.get("core_score", 50.0)) / 520.0
		+ float(reality_defiance.get("outcome_rejection_strength", 0.0)) / 650.0
		- float(last_stand_count) * 0.035,
		0.12,
		0.42
	)

	var restored_hp: int = clamp(int(round(float(hp_max) * heal_ratio)), 1, hp_max)

	if not avatar_state_active:
		degradation ["burnout"] = clamp(burnout + 8.0 + damage_pressure * 13.0 + float(last_stand_count) * 4.0, 0.0, _willpower_score_cap(person, context))
		degradation ["mental_fatigue"] = clamp(fatigue + 5.0 + damage_pressure * 9.0, 0.0, _willpower_score_cap(person, context))
		degradation ["collapse_pressure"] = clamp(collapse_pressure + 4.0 + float(last_stand_count) * 5.0, 0.0, _willpower_score_cap(person, context))

	duel_state ["last_stand_count"] = last_stand_count + 1
	duel_state ["last_stand_year"] = _current_year()
	duel_state ["last_stand_ms"] = int(Time.get_ticks_msec())
	duel_state ["avatar_state_last_stand"] = avatar_state_active

	profile ["degradation"] = degradation
	profile ["duel_state"] = duel_state
	person.willpower_profile = _make_binary_safe(profile)
	person.willpower = score(person, {
		"source": "willpower_outcome_rejection_resolved"
	})

	var line: String = ""
	if avatar_state_active:
		line = "%s hit the floor.\n\nThe Avatar State answered before defeat could finish the sentence.\n\n%s stood back up with impossible willpower.\n\nHealth restored: %d%%.\n\n\"I'm not done yet.\"" % [
			_person_name(person),
			_person_name(person),
			int(round(heal_ratio * 100.0))
		]
	else:
		line = "%s hit the floor.\n\n...\n\n\"...no.\"\n\n%s stood back up.\n\nHealth restored: %d%%.\nEnergy surged.\n\n\"I'm not done yet.\"" % [
			_person_name(person),
			_person_name(person),
			int(round(heal_ratio * 100.0))
		]

	var report: Dictionary = {
		"schema": "eralife.willpower_outcome_rejection_report",
		"version": WILLPOWER_VERSION,
		"triggered": true,
		"person_id": int(person.id),
		"person_name": _person_name(person),
		"side": side,
		"hp_key": hp_key,
		"hp_max_key": hp_max_key,
		"restored_hp": restored_hp,
		"heal_ratio": heal_ratio,
		"roll": roll,
		"difficulty": difficulty,
		"avatar_state_willpower_active": avatar_state_active,
		"line": line,
		"profile": person.willpower_profile.duplicate(true)
	}
	_commit_report(report)
	return report

func apply_duel_burnout(person: Person, amount: float, context: Dictionary = {}) -> Dictionary:
	if person == null:
		return {}
	var profile: Dictionary = ensure_willpower(person, context)
	var degradation: Dictionary = _safe_dictionary(profile.get("degradation", {}))

	if not _avatar_state_willpower_active(person):
		degradation ["burnout"] = clamp(float(degradation.get("burnout", 0.0)) + amount, 0.0, _willpower_score_cap(person, context))
		degradation ["mental_fatigue"] = clamp(float(degradation.get("mental_fatigue", 0.0)) + amount * 0.55, 0.0, _willpower_score_cap(person, context))

	profile ["degradation"] = degradation
	person.willpower_profile = _make_binary_safe(profile)
	person.willpower = score(person, {
		"source": "willpower_duel_burnout"
	})
	return person.willpower_profile.duplicate(true)

func _default_willpower_profile(person: Person, context: Dictionary = {}) -> Dictionary:
	var personal_score: float = _personal_willpower_seed_score(person)
	var lineage: Dictionary = _lineage_willpower_influence(person, context)
	var nation: Dictionary = _bending_nation_willpower_influence(person, context)
	var avatar_echo: Dictionary = _previous_avatar_willpower_influence(person, context)

	var weighted_score: float = personal_score * 0.58
	var weight_total: float = 0.58

	if int(lineage.get("ancestor_count", 0)) > 0:
		weighted_score += float(lineage.get("score", 50.0)) * 0.3
		weight_total += 0.3

	if bool(nation.get("applied", false)):
		weighted_score += float(nation.get("score", 50.0)) * 0.08
		weight_total += 0.08

	if int(avatar_echo.get("previous_avatar_count", 0)) > 0:
		weighted_score += float(avatar_echo.get("score", 50.0)) * 0.18
		weight_total += 0.18

	var variance: float = _stable_willpower_variance(person, "birthline_seed", 9.5)
	var base: float = clamp((weighted_score / max(0.01, weight_total)) + variance, 0.0, 100.0)

	return {
		"schema": WILLPOWER_SCHEMA,
		"version": WILLPOWER_VERSION,
		"person_id": int(person.id),
		"person_name": _person_name(person),
		"core_score": base,
		"birth_seeded": true,
		"birth_seed": {
			"schema": "eralife.willpower_birth_seed",
			"version": WILLPOWER_VERSION,
			"source": str(context.get("source", "willpower_birth_seed")),
			"personal_score": personal_score,
			"lineage_score": float(lineage.get("score", 50.0)),
			"ancestor_count": int(lineage.get("ancestor_count", 0)),
			"ancestor_depth_cap": int(lineage.get("ancestor_depth_cap", 4)),
			"ancestor_records": _safe_array(lineage.get("ancestor_records", [])),
			"bending_nation_score": float(nation.get("score", 50.0)),
			"bending_nation": str(nation.get("nation", "")),
			"bending_nation_applied": bool(nation.get("applied", false)),
			"previous_avatar_score": float(avatar_echo.get("score", 50.0)),
			"previous_avatar_count": int(avatar_echo.get("previous_avatar_count", 0)),
			"previous_avatar_records": _safe_array(avatar_echo.get("previous_avatar_records", [])),
			"stable_variance": variance,
			"final_birth_score": base,
			"seeded_at_year": _current_year(),
			"seeded_at_ms": int(Time.get_ticks_msec())
		},
		"resistance": {
			"emotional_resistance": base,
			"fear_resistance": base,
			"pain_resistance": base,
			"pressure_resistance": base
		},
		"persistence": {
			"long_term_endurance": base,
			"retry_willingness": base,
			"failure_tolerance": base
		},
		"reality_defiance": {
			"fate_resistance": 8.0 if _fantasy_context_active(context) else 0.0,
			"timeline_stability": 8.0 if _fantasy_context_active(context) else 0.0,
			"outcome_rejection_strength": 10.0 if _fantasy_context_active(context) else 0.0
		},
		"degradation": {
			"burnout": 0.0,
			"mental_fatigue": 0.0,
			"collapse_threshold": 100.0,
			"collapse_pressure": 0.0
		},
		"duel_state": {
			"last_stand_count": 0,
			"last_stand_year": -999999,
			"last_stand_ms": 0
		},
		"growth_history": []
	}
func apply_willpower_growth(person: Person, amount: float, context: Dictionary = {}) -> Dictionary:
	if person == null:
		return {}

	var growth_amount: float = clamp(float(amount), 0.0, 35.0)
	var profile: Dictionary = ensure_willpower(person, context)
	if growth_amount <= 0.0:
		return {
			"success": true,
			"growth": 0.0,
			"profile": profile.duplicate(true)
		}

	var resistance: Dictionary = _safe_dictionary(profile.get("resistance", {}))
	var persistence: Dictionary = _safe_dictionary(profile.get("persistence", {}))
	var reality_defiance: Dictionary = _safe_dictionary(profile.get("reality_defiance", {}))
	var source: String = str(context.get("source", "")).strip_edges().to_lower()
	var scope: String = str(context.get("scope", context.get("duel_scope", ""))).strip_edges().to_lower()

	if source.find("meditation") >= 0:
		resistance ["emotional_resistance"] = clamp(float(resistance.get("emotional_resistance", 50.0)) + growth_amount * 0.95, 0.0, _willpower_score_cap(person, context))
		resistance ["fear_resistance"] = clamp(float(resistance.get("fear_resistance", 50.0)) + growth_amount * 0.45, 0.0, _willpower_score_cap(person, context))
		resistance ["pressure_resistance"] = clamp(float(resistance.get("pressure_resistance", 50.0)) + growth_amount * 0.55, 0.0, _willpower_score_cap(person, context))
		persistence ["long_term_endurance"] = clamp(float(persistence.get("long_term_endurance", 50.0)) + growth_amount * 0.9, 0.0, _willpower_score_cap(person, context))
		persistence ["failure_tolerance"] = clamp(float(persistence.get("failure_tolerance", 50.0)) + growth_amount * 0.35, 0.0, _willpower_score_cap(person, context))
		reality_defiance ["timeline_stability"] = clamp(float(reality_defiance.get("timeline_stability", 0.0)) + growth_amount * 0.18, 0.0, _willpower_score_cap(person, context))
	elif source.find("high_willpower") >= 0 or source.find("strong_willpower") >= 0:
		resistance ["pain_resistance"] = clamp(float(resistance.get("pain_resistance", 50.0)) + growth_amount * 0.8, 0.0, _willpower_score_cap(person, context))
		resistance ["pressure_resistance"] = clamp(float(resistance.get("pressure_resistance", 50.0)) + growth_amount * 0.95, 0.0, _willpower_score_cap(person, context))
		persistence ["retry_willingness"] = clamp(float(persistence.get("retry_willingness", 50.0)) + growth_amount * 0.9, 0.0, _willpower_score_cap(person, context))
		persistence ["failure_tolerance"] = clamp(float(persistence.get("failure_tolerance", 50.0)) + growth_amount * 0.55, 0.0, _willpower_score_cap(person, context))
		reality_defiance ["outcome_rejection_strength"] = clamp(float(reality_defiance.get("outcome_rejection_strength", 0.0)) + growth_amount * 0.35, 0.0, _willpower_score_cap(person, context))
	elif source.find("championship") >= 0 or source.find("tournament") >= 0 or scope.find("bending") >= 0:
		resistance ["fear_resistance"] = clamp(float(resistance.get("fear_resistance", 50.0)) + growth_amount * 0.45, 0.0, _willpower_score_cap(person, context))
		resistance ["pain_resistance"] = clamp(float(resistance.get("pain_resistance", 50.0)) + growth_amount * 0.45, 0.0, _willpower_score_cap(person, context))
		resistance ["pressure_resistance"] = clamp(float(resistance.get("pressure_resistance", 50.0)) + growth_amount * 0.85, 0.0, _willpower_score_cap(person, context))
		persistence ["long_term_endurance"] = clamp(float(persistence.get("long_term_endurance", 50.0)) + growth_amount * 0.65, 0.0, _willpower_score_cap(person, context))
		persistence ["retry_willingness"] = clamp(float(persistence.get("retry_willingness", 50.0)) + growth_amount * 0.65, 0.0, _willpower_score_cap(person, context))
		persistence ["failure_tolerance"] = clamp(float(persistence.get("failure_tolerance", 50.0)) + growth_amount * 0.7, 0.0, _willpower_score_cap(person, context))
		reality_defiance ["outcome_rejection_strength"] = clamp(float(reality_defiance.get("outcome_rejection_strength", 0.0)) + growth_amount * 0.28, 0.0, _willpower_score_cap(person, context))
	else:
		resistance ["emotional_resistance"] = clamp(float(resistance.get("emotional_resistance", 50.0)) + growth_amount * 0.4, 0.0, _willpower_score_cap(person, context))
		resistance ["pressure_resistance"] = clamp(float(resistance.get("pressure_resistance", 50.0)) + growth_amount * 0.4, 0.0, _willpower_score_cap(person, context))
		persistence ["long_term_endurance"] = clamp(float(persistence.get("long_term_endurance", 50.0)) + growth_amount * 0.4, 0.0, _willpower_score_cap(person, context))
		persistence ["retry_willingness"] = clamp(float(persistence.get("retry_willingness", 50.0)) + growth_amount * 0.4, 0.0, _willpower_score_cap(person, context))

	var history: Array = _safe_array(profile.get("growth_history", []))
	history.append({
		"schema": "eralife.willpower_growth_event",
		"version": WILLPOWER_VERSION,
		"amount": growth_amount,
		"source": str(context.get("source", "willpower_growth")),
		"scope": str(context.get("scope", context.get("duel_scope", ""))),
		"reason": str(context.get("reason", "")),
		"year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec())
	})
	while history.size() > 40:
		history.pop_front()

	profile ["resistance"] = resistance
	profile ["persistence"] = persistence
	profile ["reality_defiance"] = reality_defiance
	profile ["growth_history"] = history
	profile ["last_growth_report"] = history [history.size() - 1]
	person.willpower_profile = _make_binary_safe(profile)
	person.willpower = score(person, {
		"source": "willpower_growth_commit"
	})

	var report: Dictionary = {
		"schema": "eralife.willpower_growth_report",
		"version": WILLPOWER_VERSION,
		"success": true,
		"person_id": int(person.id),
		"person_name": _person_name(person),
		"growth": growth_amount,
		"source": str(context.get("source", "willpower_growth")),
		"new_score": float(person.willpower),
		"profile": person.willpower_profile.duplicate(true)
	}
	_commit_report(report)
	return report.duplicate(true)

func _willpower_profile_needs_birth_seed(profile: Dictionary) -> bool:
	if profile.is_empty():
		return true
	if bool(profile.get("birth_seeded", false)):
		return false
	if not _safe_dictionary(profile.get("birth_seed", {})).is_empty():
		return false
	if not _safe_array(profile.get("growth_history", [])).is_empty():
		return false

	var core_score: float = float(profile.get("core_score", 50.0))
	var resistance: Dictionary = _safe_dictionary(profile.get("resistance", {}))
	var persistence: Dictionary = _safe_dictionary(profile.get("persistence", {}))
	var duel_state: Dictionary = _safe_dictionary(profile.get("duel_state", {}))

	var default_resistance: bool = (
		abs(float(resistance.get("emotional_resistance", 50.0)) - 50.0) <= 0.01
		and abs(float(resistance.get("fear_resistance", 50.0)) - 50.0) <= 0.01
		and abs(float(resistance.get("pain_resistance", 50.0)) - 50.0) <= 0.01
		and abs(float(resistance.get("pressure_resistance", 50.0)) - 50.0) <= 0.01
	)

	var default_persistence: bool = (
		abs(float(persistence.get("long_term_endurance", 50.0)) - 50.0) <= 0.01
		and abs(float(persistence.get("retry_willingness", 50.0)) - 50.0) <= 0.01
		and abs(float(persistence.get("failure_tolerance", 50.0)) - 50.0) <= 0.01
	)

	var untouched_duel_state: bool = int(duel_state.get("last_stand_count", 0)) <= 0
	return abs(core_score - 50.0) <= 0.01 and default_resistance and default_persistence and untouched_duel_state

func _personal_willpower_seed_score(person: Person) -> float:
	if person == null:
		return 50.0

	var discipline_score: float = _contract_discipline_score(person)
	return clamp(
		float(person.mental_health) * 0.23
		+ float(person.ambition) * 0.2
		+ float(person.motivation) * 0.2
		+ float(person.smarts) * 0.12
		+ float(person.satisfaction) * 0.08
		+ discipline_score * 0.12
		+ _trait_willpower_bonus(person)
		+ _stable_willpower_variance(person, "personal_seed", 8.0),
		0.0,
		100.0
	)

func _lineage_willpower_influence(person: Person, context: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {
		"score": 50.0,
		"ancestor_count": 0,
		"ancestor_depth_cap": clamp(int(context.get("ancestor_depth_cap", 4)), 1, 6),
		"ancestor_records": []
	}
	if person == null:
		return out

	var max_depth: int = int(out.get("ancestor_depth_cap", 4))
	var frontier: Array = []
	for raw_parent_id in _safe_array(person.parents):
		frontier.append({
			"id": int(raw_parent_id),
			"depth": 1
		})

	var visited: Dictionary = {}
	var weighted_total: float = 0.0
	var weight_sum: float = 0.0
	var records: Array = []

	while not frontier.is_empty():
		var cursor: Dictionary = _safe_dictionary(frontier.pop_front())
		var ancestor_id: int = int(cursor.get("id", -1))
		var depth: int = int(cursor.get("depth", 1))
		if ancestor_id <= 0:
			continue
		if depth > max_depth:
			continue
		if visited.has(ancestor_id):
			continue

		visited [ancestor_id] = true
		var ancestor: Person = _find_person_by_id(ancestor_id)
		if ancestor == null:
			continue

		var ancestor_score: float = _raw_person_willpower_seed_score(ancestor)
		var weight: float = 1.0 / float(max(1, depth))
		weighted_total += ancestor_score * weight
		weight_sum += weight

		records.append({
			"id": int(ancestor.id),
			"name": _person_name(ancestor),
			"depth": depth,
			"score": ancestor_score,
			"weight": weight
		})

		if depth < max_depth:
			for raw_grandparent_id in _safe_array(ancestor.parents):
				frontier.append({
					"id": int(raw_grandparent_id),
					"depth": depth + 1
				})

	if weight_sum > 0.0:
		out ["score"] = clamp(weighted_total / weight_sum, 0.0, 100.0)
	out ["ancestor_count"] = records.size()
	out ["ancestor_records"] = records
	return out

func _raw_person_willpower_seed_score(person: Person) -> float:
	if person == null:
		return 50.0

	var existing: Dictionary = _safe_dictionary(person.willpower_profile)
	if bool(existing.get("birth_seeded", false)) or not _safe_dictionary(existing.get("birth_seed", {})).is_empty():
		return clamp(float(existing.get("core_score", person.willpower)), 0.0, 100.0)

	if abs(float(person.willpower) - 50.0) > 0.01:
		return clamp(float(person.willpower), 0.0, 100.0)

	return _personal_willpower_seed_score(person)

func _bending_nation_willpower_influence(person: Person, _context: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {
		"applied": false,
		"nation": "",
		"score": 50.0,
		"modifier": 0.0
	}
	if person == null:
		return out

	var bending_type: String = str(person.bending_type).strip_edges().to_lower()
	if bending_type == "" or bending_type == "none":
		return out

	var nation: String = str(person.bending_nation).strip_edges()
	out ["nation"] = nation
	if nation == "":
		return out

	var key: String = nation.to_lower()
	var modifier: float = 0.0
	if key.find("air") >= 0:
		modifier = 5.0
	elif key.find("earth") >= 0:
		modifier = 6.0
	elif key.find("fire") >= 0:
		modifier = 4.5
	elif key.find("water") >= 0:
		modifier = 3.5

	out ["applied"] = true
	out ["modifier"] = modifier
	out ["score"] = clamp(50.0 + modifier + _stable_willpower_variance(person, "bending_nation_%s" % key, 5.0), 0.0, 100.0)
	return out

func _previous_avatar_willpower_influence(person: Person, _context: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {
		"score": 50.0,
		"previous_avatar_count": 0,
		"previous_avatar_records": []
	}
	if person == null:
		return out
	if str(person.bending_type).strip_edges().to_lower() != "avatar":
		return out
	if gs == null:
		return out

	if gs.bending_engine != null and gs.bending_engine.has_method("_seed_previous_avatar_history_for_birth"):
		gs.bending_engine.call("_seed_previous_avatar_history_for_birth", person)

	var state: Dictionary = {}
	if typeof(gs.scenario_state) == TYPE_DICTIONARY:
		state = _safe_dictionary(gs.scenario_state.get("bending_world_championship", {}))

	var previous: Array = _safe_array(state.get("previous_avatars", []))
	if previous.is_empty():
		return out

	var start_index: int = max(0, previous.size() - 4)
	var weighted_total: float = 0.0
	var weight_sum: float = 0.0
	var records: Array = []

	for i in range(start_index, previous.size()):
		var row: Dictionary = _safe_dictionary(previous [i])
		if row.is_empty():
			continue

		var avatar_score: float = _previous_avatar_record_willpower_score(row)
		var weight: float = 1.0 + (float(i - start_index) * 0.15)
		weighted_total += avatar_score * weight
		weight_sum += weight

		records.append({
			"name": str(row.get("name", "Previous Avatar")),
			"nation": str(row.get("nation", "")),
			"native_element": str(row.get("native_element", "")),
			"score": avatar_score,
			"weight": weight
		})

	if weight_sum > 0.0:
		out ["score"] = clamp(weighted_total / weight_sum, 0.0, 100.0)

	out ["previous_avatar_count"] = records.size()
	out ["previous_avatar_records"] = records
	return out

func _previous_avatar_record_willpower_score(row: Dictionary) -> float:
	if row.has("willpower_score"):
		return clamp(float(row.get("willpower_score", 50.0)), 0.0, 100.0)

	var imprint: Dictionary = _safe_dictionary(row.get("reputation_imprint", {}))
	var memory_strength: float = float(imprint.get("public_memory_strength", 50.0))
	var lifespan: float = float(row.get("lifespan", 70))
	var archetype_id: String = str(imprint.get("id", "")).strip_edges().to_lower()
	var archetype_bonus: float = 0.0

	if archetype_id.find("storm") >= 0:
		archetype_bonus = 9.0
	elif archetype_id.find("iron") >= 0:
		archetype_bonus = 7.0
	elif archetype_id.find("wandering") >= 0:
		archetype_bonus = 4.0
	elif archetype_id.find("merciful") >= 0:
		archetype_bonus = 3.0

	return clamp((memory_strength * 0.56) + (clamp(lifespan, 35.0, 100.0) * 0.22) + 14.0 + archetype_bonus, 0.0, 100.0)

func _stable_willpower_variance(person: Person, salt: String, spread: float = 8.0) -> float:
	if person == null:
		return 0.0

	var rng:= RandomNumberGenerator.new()
	rng.seed = abs(int(("%d:%s:%s:%s:%s" % [
		int(person.id),
		str(person.first_name),
		str(person.last_name),
		str(person.bending_nation),
		str(salt)
	]).hash()))

	return rng.randf_range(- abs(float(spread)), abs(float(spread)))

func _find_person_by_id(person_id: int) -> Person:
	if gs == null or person_id <= 0:
		return null

	if gs.player != null and int(gs.player.id) == person_id:
		return gs.player

	if gs.has_method("get_npc_by_id"):
		var found: Person = gs.get_npc_by_id(person_id)
		if found != null:
			return found

	if "npcs" in gs and typeof(gs.npcs) == TYPE_ARRAY:
		for raw_npc in gs.npcs:
			if raw_npc == null:
				continue
			var npc: Person = raw_npc
			if int(npc.id) == person_id:
				return npc

	return null

func _contract_discipline_score(person: Person) -> float:
	if person == null:
		return 50.0
	var contract: Dictionary = _safe_dictionary(person.consciousness_contract)
	var behavioral: Dictionary = _safe_dictionary(contract.get("behavioral_patterns", {}))
	if behavioral.has("discipline"):
		var value: float = float(behavioral.get("discipline", 0.5))
		if value <= 1.5:
			return clamp(value * 100.0, 0.0, 150.0)
		return clamp(value, 0.0, 150.0)
	return 50.0

func _trait_willpower_bonus(person: Person) -> float:
	if person == null:
		return 0.0

	var bonus: float = 0.0

	for raw_trait in _safe_array(person.traits):
		var trait_text: String = str(raw_trait).strip_edges().to_lower()
		if trait_text == "":
			continue

		if trait_text.find("disciplined") >= 0 or trait_text.find("determined") >= 0 or trait_text.find("driven") >= 0:
			bonus += 8.0

		if trait_text.find("stubborn") >= 0 or trait_text.find("unyielding") >= 0:
			bonus += 6.0

		if trait_text.find("coward") >= 0 or trait_text.find("fragile") >= 0:
			bonus -= 8.0

		if trait_text.find("cosmic") >= 0 or trait_text.find("avatar") >= 0 or trait_text.find("legend") >= 0:
			bonus += 10.0

	return clamp(bonus, -35.0, 45.0)
func apply_avatar_state_willpower(person: Person, context: Dictionary = {}) -> Dictionary:
	if person == null:
		return {}

	var profile: Dictionary = ensure_willpower(person, context)
	profile ["avatar_state_willpower_active"] = true
	profile ["avatar_state_willpower_floor"] = _avatar_state_willpower_floor()
	profile ["active_cap"] = _willpower_score_cap(person, context)

	person.willpower_profile = _make_binary_safe(profile)
	person.willpower = score(person, {
		"source": "avatar_state_willpower_applied"
	})
	return person.willpower_profile.duplicate(true)



func _avatar_state_willpower_active(person: Person) -> bool:
	if person == null:
		return false
	if str(person.bending_type).strip_edges().to_lower() != "avatar":
		return false
	return bool(person.avatar_state_used)



func _avatar_state_willpower_floor() -> float:
	return 999.0



func _willpower_score_cap(person: Person, context: Dictionary = {}) -> float:
	if person != null:
		if typeof(person.traits) == TYPE_ARRAY and "RedBonnetBearer" in person.traits:
			return 9999.0

	if bool(context.get("force_red_bonnet_cap", false)):
		return 9999.0

	if _avatar_state_willpower_active(person):
		return 9999.0

	return 150.0
func _fantasy_context_active(context: Dictionary = {}) -> bool:
	var source: String = str(context.get("source", "")).strip_edges().to_lower()
	var scope: String = str(context.get("duel_scope", context.get("scope", ""))).strip_edges().to_lower()
	if source.find("time_loop") >= 0 or scope.find("bending") >= 0 or scope.find("fusion") >= 0:
		return true
	if gs != null and "reality_mode" in gs:
		var mode: String = str(gs.reality_mode).strip_edges().to_lower()
		if mode in ["fantasy", "enhanced", "chaos"]:
			return true
	return false

func _person_name(person: Person) -> String:
	if person == null:
		return "Unknown"
	var full: String = ("%s %s" % [str(person.first_name), str(person.last_name)]).strip_edges()
	if full != "":
		return full
	return str(person.name)

func _current_year() -> int:
	if gs == null:
		return 0
	return int(gs.year)

func _commit_report(report: Dictionary) -> void:
	last_willpower_report = _make_binary_safe(report)
	willpower_reports.append(last_willpower_report.duplicate(true))
	while willpower_reports.size() > 80:
		willpower_reports.pop_front()

func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)

func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)

func _merge_dict(base: Dictionary, overlay: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	for raw_key in overlay.keys():
		var key: Variant = raw_key
		var overlay_value: Variant = overlay.get(key)
		var base_value: Variant = out.get(key)
		if typeof(base_value) == TYPE_DICTIONARY and typeof(overlay_value) == TYPE_DICTIONARY:
			out [key] = _merge_dict(base_value as Dictionary, overlay_value as Dictionary)
		else:
			out [key] = overlay_value
	return out

func _make_binary_safe(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		var out: Dictionary = {}
		for raw_key in (value as Dictionary).keys():
			out [str(raw_key)] = _make_binary_safe((value as Dictionary).get(raw_key))
		return out
	if typeof(value) == TYPE_ARRAY:
		var arr: Array = []
		for item in value:
			arr.append(_make_binary_safe(item))
		return arr
	return value