extends Resource
class_name BendingDojoEngine

const CONTRACT_SCHEMA:= "eralife.bending_dojo_contract"
const CONTRACT_VERSION:= 1
const STATE_SCHEMA:= "eralife.bending_dojo_state"

var gs
var active_contract: Dictionary = {}
var dojo_state: Dictionary = {}
var last_report: Dictionary = {}

func _init(_gs = null, contract: Dictionary = {}) -> void:
	gs = _gs
	set_contract(contract)


func set_contract(contract: Dictionary = {}) -> Dictionary:
	active_contract = _default_contract()
	if typeof(contract) == TYPE_DICTIONARY and not contract.is_empty():
		active_contract = _merge_dict(active_contract, contract)

	last_report = {
		"schema": "eralife.bending_dojo_contract_set_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"contract_id": str(active_contract.get("id", "default_bending_dojo_contract")),
		"set_at_ms": int(Time.get_ticks_msec())
	}
	return last_report.duplicate(true)


func export_state() -> Dictionary:
	return {
		"schema": STATE_SCHEMA,
		"version": CONTRACT_VERSION,
		"active_contract": active_contract.duplicate(true),
		"dojo_state": _ensure_state().duplicate(true),
		"last_report": last_report.duplicate(true),
		"exported_at_ms": int(Time.get_ticks_msec())
	}


func import_state(state: Dictionary) -> Dictionary:
	if typeof(state) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "BendingDojoEngine import_state expected Dictionary."
		}

	var contract_raw: Variant = state.get("active_contract", {})
	if typeof(contract_raw) == TYPE_DICTIONARY:
		active_contract = _merge_dict(_default_contract(), contract_raw)

	var dojo_raw: Variant = state.get("dojo_state", {})
	if typeof(dojo_raw) == TYPE_DICTIONARY:
		dojo_state = dojo_raw.duplicate(true)

	var report_raw: Variant = state.get("last_report", {})
	if typeof(report_raw) == TYPE_DICTIONARY:
		last_report = report_raw.duplicate(true)

	_ensure_state()

	return {
		"success": true,
		"imported_at_ms": int(Time.get_ticks_msec())
	}


func get_dojo_hub_payload(actor: Person, options: Dictionary = {}) -> Dictionary:
	var state: Dictionary = _ensure_state()
	var element: String = str(options.get("element", _element_for_actor(actor))).strip_edges().to_lower()
	var available: Array = []
	var membership: Dictionary = get_actor_dojo_membership(actor)
	var accepted_dojo: Dictionary = {}
	var accepted_sensei: Dictionary = {}
	var accepted_classmates: Array = []
	var accepted_rankings: Array = []
	var accepted_history: Dictionary = {}
	var accepted_rivalries: Array = []
	var accepted_sparring_record: Dictionary = {}
	var accepted_sparring_tiers: Array = []
	var accepted_film_study: Dictionary = {}
	var film_study_available: bool = _dojo_film_study_available()
	var film_study_locked_reason: String = _dojo_film_study_locked_reason()

	if not membership.is_empty():
		accepted_dojo = _dojo_by_id(str(membership.get("dojo_id", "")))
		if not accepted_dojo.is_empty():
			_ensure_dojo_institution_state(accepted_dojo)
			var accepted_element: String = str(accepted_dojo.get("element", element)).strip_edges().to_lower()
			accepted_sensei = _person_card(_teacher_for_dojo(actor, accepted_dojo), accepted_element)
			accepted_classmates = _classmates_for_dojo(actor, accepted_dojo)
			accepted_rankings = _dojo_student_rankings(actor, accepted_dojo)
			accepted_history = _dojo_history_row(str(accepted_dojo.get("id", "")))
			accepted_rivalries = _dojo_rivalry_rows(str(accepted_dojo.get("id", "")))
			accepted_sparring_record = _dojo_sparring_record_for_actor(actor)
			accepted_sparring_tiers = get_dojo_sparring_tiers(actor, accepted_dojo, {
				"source": "dojo_hub_payload"
			})
			if film_study_available:
				accepted_film_study = _dojo_film_study_row(actor, str(accepted_dojo.get("id", "")))

	for raw_dojo in _safe_array(state.get("dojos", [])):
		if typeof(raw_dojo) != TYPE_DICTIONARY:
			continue

		var dojo: Dictionary = raw_dojo
		if element != "" and str(dojo.get("element", "")).strip_edges().to_lower() != element:
			continue

		_ensure_dojo_institution_state(dojo)

		var gate: Dictionary = _dojo_entry_gate(actor, dojo)
		var dojo_id: String = str(dojo.get("id", ""))
		var row: Dictionary = dojo.duplicate(true)
		row ["entry_gate"] = gate.duplicate(true)
		row ["accepted"] = str(membership.get("dojo_id", "")) == dojo_id
		row ["sensei"] = _person_card(_teacher_for_dojo(actor, dojo), str(dojo.get("element", element)))
		row ["classmates"] = _classmates_for_dojo(actor, dojo)
		row ["reputation"] = _dojo_reputation_row(dojo_id)
		row ["ranking"] = _dojo_student_rank_row(actor, dojo)
		row ["history"] = _dojo_history_row(dojo_id)
		row ["rivalries"] = _dojo_rivalry_rows(dojo_id)

		if bool(row.get("accepted", false)):
			row ["sparring_record"] = accepted_sparring_record.duplicate(true)
			row ["sparring_tiers"] = accepted_sparring_tiers.duplicate(true)
			row ["film_study"] = accepted_film_study.duplicate(true)
			row ["film_study_available"] = film_study_available
			row ["film_study_locked_reason"] = film_study_locked_reason
		available.append(row)

	return {
		"schema": "eralife.bending_dojo_hub_payload",
		"version": CONTRACT_VERSION,
		"actor_id": int(actor.id) if actor != null else -1,
		"element": element,
		"actor_membership": membership.duplicate(true),
		"accepted_dojo": accepted_dojo.duplicate(true),
		"accepted_sensei": accepted_sensei.duplicate(true),
		"accepted_classmates": accepted_classmates.duplicate(true),
		"accepted_rankings": accepted_rankings.duplicate(true),
		"accepted_history": accepted_history.duplicate(true),
		"accepted_rivalries": accepted_rivalries.duplicate(true),
		"accepted_sparring_record": accepted_sparring_record.duplicate(true),
		"accepted_sparring_tiers": accepted_sparring_tiers.duplicate(true),
		"accepted_film_study": accepted_film_study.duplicate(true),
		"dojos": available,
		"training_actions": [
			{
				"id": "spar_beginner",
				"label": "Beginner Spar",
				"tier_id": "beginner"
			},
			{
				"id": "spar_intermediate",
				"label": "Intermediate Spar",
				"tier_id": "intermediate"
			},
			{
				"id": "spar_advanced",
				"label": "Advanced Spar",
				"tier_id": "advanced"
			},
			{
				"id": "spar_master",
				"label": "Master Spar",
				"tier_id": "master"
			},
			{
				"id": "spectate_dojo_spar",
				"label": "Spectate NPC Spar",
			},
			{
				"id": "film_study",
				"label": "Study Sparring Film",
				"available": film_study_available,
				"disabled_reason": film_study_locked_reason
			},
			{
				"id": "train_form",
				"label": "Train Forms",
			},
			{
				"id": "dojo_history",
				"label": "Dojo History",
			}
		],
		"generated_at_year": int(gs.year) if gs != null else 0
	}
func visit_dojo(actor: Person, dojo_id: String, _options: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"popup_title": "Bending Dojo",
			"popup_text": "No bender was selected.",
			"popup_footer": "Tap anywhere to continue."
		}

	var state: Dictionary = _ensure_state()
	var dojo: Dictionary = _dojo_by_id(str(dojo_id))
	if dojo.is_empty():
		return {
			"success": false,
			"popup_title": "Dojo Missing",
			"popup_text": "That dojo could not be found.",
			"popup_footer": "Tap anywhere to continue."
		}

	var membership: Dictionary = get_actor_dojo_membership(actor)
	if membership.is_empty() or str(membership.get("dojo_id", "")) != str(dojo.get("id", "")):
		return {
			"success": false,
			"popup_title": "Apply First",
			"popup_text": "%s does not let walk-ins train on the inner floor.\n\nApply first. If you qualify, they will accept you immediately." % str(dojo.get("name", "This dojo")),
			"popup_footer": "Tap anywhere to continue.",
			"dojo": dojo.duplicate(true)
		}

	var element: String = str(dojo.get("element", _element_for_actor(actor))).strip_edges().to_lower()
	var teacher: Person = _teacher_for_dojo(actor, dojo)
	var classmates: Array = _classmates_for_dojo(actor, dojo)
	var before_level: int = _bending_level(actor, element)
	var classmate_bonus: int = int(floor(float(classmates.size()) / 3.0))
	var gain: int = clamp(int(dojo.get("training_gain", 2)) + classmate_bonus, 1, 12)
	var skill_points: int = clamp(int(dojo.get("skill_point_gain", 1)), 0, 5)

	if teacher != null and gs != null and gs.bending_engine != null and gs.bending_engine.has_method("train_with_teacher"):
		gs.bending_engine.train_with_teacher(teacher, actor, element)
	elif gs != null and gs.bending_engine != null and gs.bending_engine.has_method("gain_bending_progress"):
		gs.bending_engine.gain_bending_progress(actor, element, gain, "training at %s" % str(dojo.get("name", "a bending dojo")))

	if skill_points > 0 and gs != null and gs.bending_engine != null and gs.bending_engine.has_method("award_bending_skill_points"):
		gs.bending_engine.award_bending_skill_points(actor, skill_points, "bending_dojo_training")

	actor.satisfaction = clamp(int(actor.satisfaction) + 2, 0, 100)
	actor.mental_health = clamp(int(actor.mental_health) + 1, 0, 100)

	var after_level: int = _bending_level(actor, element)
	_add_dojo_honor(actor, dojo, 2 + classmate_bonus, {
		"source": "dojo_visit",
		"level_gain": max(0, after_level - before_level)
	})

	var class_line: String = ""
	if not classmates.is_empty():
		class_line = "\n\nClassmates on the floor:\n%s" % _classmate_names(classmates)

	var teacher_line: String = "A senior instructor"
	if teacher != null:
		teacher_line = _person_label(teacher)

	var report: Dictionary = {
		"schema": "eralife.bending_dojo_visit_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"actor_id": int(actor.id),
		"dojo_id": str(dojo.get("id", "")),
		"dojo_name": str(dojo.get("name", "Bending Dojo")),
		"element": element,
		"teacher_id": int(teacher.id) if teacher != null else -1,
		"teacher_name": teacher_line,
		"classmate_count": classmates.size(),
		"before_level": before_level,
		"after_level": after_level,
		"skill_points": skill_points,
		"year": int(gs.year) if gs != null else 0
	}

	last_report = report.duplicate(true)
	state ["last_report"] = report.duplicate(true)
	dojo_state = state.duplicate(true)

	return {
		"success": true,
		"popup_title": str(dojo.get("name", "Bending Dojo")),
		"popup_text": "%s watched your stance, corrected your breathing, and put you through %s forms.\n\nLevel: %d → %d\nSkill Points gained: %d%s" % [
			teacher_line,
			element.capitalize(),
			before_level,
			after_level,
			skill_points,
			class_line
		],
		"popup_footer": "Tap anywhere to continue.",
		"report": report.duplicate(true)
	}
func get_actor_dojo_membership(actor: Person) -> Dictionary:
	if actor == null:
		return {}

	var state: Dictionary = _ensure_state()
	var enrollments: Dictionary = _safe_dictionary(state.get("enrollments", {}))
	var row: Dictionary = _safe_dictionary(enrollments.get(str(int(actor.id)), {}))

	if row.is_empty():
		return {}

	if str(row.get("status", "")).strip_edges().to_lower() != "accepted":
		return {}

	return row.duplicate(true)


func apply_to_dojo(actor: Person, dojo_id: String, options: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"popup_title": "Bending Dojo",
			"popup_text": "No bender was selected.",
			"popup_footer": "Tap anywhere to continue."
		}

	var state: Dictionary = _ensure_state()
	var dojo: Dictionary = _dojo_by_id(str(dojo_id))
	if dojo.is_empty():
		return {
			"success": false,
			"popup_title": "Dojo Missing",
			"popup_text": "That dojo could not be found.",
			"popup_footer": "Tap anywhere to continue."
		}

	var gate: Dictionary = _dojo_entry_gate(actor, dojo)
	if not bool(gate.get("allowed", false)):
		return {
			"success": false,
			"popup_title": str(dojo.get("name", "Bending Dojo")),
			"popup_text": str(gate.get("reason_text", "You do not qualify for this dojo yet.")),
			"popup_footer": "Tap anywhere to continue.",
			"entry_gate": gate.duplicate(true)
		}

	var enrollments: Dictionary = _safe_dictionary(state.get("enrollments", {}))
	var actor_key: String = str(int(actor.id))
	var element: String = str(dojo.get("element", _element_for_actor(actor))).strip_edges().to_lower()
	var teacher: Person = _teacher_for_dojo(actor, dojo)
	var teacher_name: String = _person_label(teacher) if teacher != null else "the senior instructor"

	var membership: Dictionary = {
		"schema": "eralife.bending_dojo_membership",
		"version": CONTRACT_VERSION,
		"status": "accepted",
		"actor_id": int(actor.id),
		"actor_name": _person_label(actor),
		"dojo_id": str(dojo.get("id", "")),
		"dojo_name": str(dojo.get("name", "Bending Dojo")),
		"element": element,
		"tier": str(dojo.get("tier", "local")),
		"joined_year": int(gs.year) if gs != null else 0,
		"honor": 0,
		"student_rank_label": "New Disciple",
		"accepted_at_ms": int(Time.get_ticks_msec()),
		"source": str(options.get("source", "dojo_application"))
	}

	enrollments [actor_key] = membership.duplicate(true)
	state ["enrollments"] = enrollments
	dojo_state = state.duplicate(true)

	return {
		"success": true,
		"popup_title": "Accepted",
		"popup_text": "%s studied your stance, your breathing, and the way your element answered you.\n\nThen %s nodded.\n\n\"You qualify. Train with us, and carry this dojo's name with honor.\"\n\nYou have joined %s." % [
			str(dojo.get("name", "The dojo")),
			teacher_name,
			str(dojo.get("name", "the dojo"))
		],
		"popup_footer": "Tap anywhere to continue.",
		"membership": membership.duplicate(true)
	}


func spar_in_dojo(actor: Person, target_id: int = -1, _options: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"popup_title": "Dojo Sparring",
			"popup_text": "No bender was selected.",
			"popup_footer": "Tap anywhere to continue."
		}

	var membership: Dictionary = get_actor_dojo_membership(actor)
	if membership.is_empty():
		return {
			"success": false,
			"popup_title": "Dojo Sparring Locked",
			"popup_text": "You need to be accepted into a dojo before sparring on its floor.",
			"popup_footer": "Tap anywhere to continue."
		}

	var dojo: Dictionary = _dojo_by_id(str(membership.get("dojo_id", "")))
	if dojo.is_empty():
		return {
			"success": false,
			"popup_title": "Dojo Missing",
			"popup_text": "Your dojo record exists, but the dojo itself could not be found.",
			"popup_footer": "Tap anywhere to continue."
		}

	_ensure_dojo_institution_state(dojo)

	var options: Dictionary = _options.duplicate(true)
	var element: String = str(dojo.get("element", _element_for_actor(actor))).strip_edges().to_lower()
	var requested_tier_id: String = str(options.get("tier_id", "")).strip_edges().to_lower()
	var target: Person = null

	if int(target_id) > 0:
		target = _find_person_by_id(int(target_id))
	elif requested_tier_id != "":
		target = _dojo_target_for_sparring_tier(actor, dojo, requested_tier_id)
	else:
		target = _teacher_for_dojo(actor, dojo)

	if target == null:
		return {
			"success": false,
			"popup_title": "No Sparring Partner",
			"popup_text": "No valid sparring partner was available.",
			"popup_footer": "Tap anywhere to continue."
		}

	var tier_id: String = requested_tier_id
	if tier_id == "":
		tier_id = _dojo_sparring_tier_for_target(actor, target, dojo)

	var tier_config: Dictionary = _dojo_sparring_tier_config(tier_id)
	options ["tier_id"] = str(tier_config.get("id", tier_id))
	options ["tier_label"] = str(tier_config.get("label", "Beginner"))
	options ["ai_aggression"] = float(tier_config.get("ai_aggression", 1.0))
	options ["move_variety"] = int(tier_config.get("move_variety", 3))
	options ["sensei_teaching_enabled"] = true
	options ["style_adaptation_enabled"] = true
	options ["film_study_enabled"] = true

	if bool(options.get("interactive", true)):
		return build_dojo_spar_scenario(actor, target, dojo, element, options)

	var match_payload: Dictionary = _simulate_dojo_spar_match(actor, target, dojo, element, options)
	var actor_won: bool = int(match_payload.get("winner_id", -1)) == int(actor.id)
	var finalize_report: Dictionary = finalize_dojo_sparring_result(actor, target, {
		"mock_match": true,
		"controlled_training": true,
		"dojo_id": str(dojo.get("id", "")),
		"dojo_name": str(dojo.get("name", "")),
		"player_element": element,
		"target_element": element,
		"sparring_tier": str(tier_config.get("id", tier_id)),
		"sparring_tier_label": str(tier_config.get("label", "Beginner")),
		"pending_player_attack": {
			"name": str(match_payload.get("finish_move", "Controlled Sparring Finish"))
		},
		"last_enemy_move": {
			"name": str(match_payload.get("finish_move", "Controlled Sparring Finish"))
		},
		"match_payload": match_payload.duplicate(true)
	}, actor_won, options)

	finalize_report ["match_payload"] = match_payload.duplicate(true)
	return finalize_report
func build_dojo_spar_scenario(actor: Person, target: Person, dojo: Dictionary, element: String, options: Dictionary = {}) -> Dictionary:
	if actor == null or target == null:
		return {
			"success": false,
			"popup_title": "Dojo Sparring",
			"popup_text": "No valid sparring pair was selected.",
			"popup_footer": "Tap anywhere to continue."
		}

	var clean_element: String = str(element).strip_edges().to_lower()
	if clean_element == "":
		clean_element = _element_for_actor(actor)

	var dojo_id: String = str(dojo.get("id", ""))
	var dojo_name: String = str(dojo.get("name", "Bending Dojo"))
	var actor_name: String = _person_label(actor)
	var target_name: String = _person_label(target)

	var scenario: Dictionary = {
		"id": "dojo_mock_match_%d_%d_%d" % [
			int(actor.id),
			int(target.id),
			int(Time.get_ticks_msec())
		],
		"source": "bending_dojo_engine",
		"resolver_owner": "scenario_engine",
		"category": "bending",
		"cooldown_key": "dojo_spar_%s" % dojo_id,
		"resolver_method": "_resolve_bending_duel_choice",
		"panel_title": "DOJO MOCK MATCH — LIVE SPARRING",
		"footer_text": "Controlled training match. You still fight exchange by exchange, but the dojo keeps it from becoming a real injury spiral.",
		"prompt": "%s steps onto the floor at %s.\n\n%s settles into a sparring stance. Do you begin the mock match?" % [
			target_name,
			dojo_name,
			target_name
		],
		"actor_id": int(actor.id),
		"target_id": int(target.id),
		"bending_duel_target_id": int(target.id),
		"bending_duel_target_name": target_name,
		"mock_match": true,
		"controlled_training": true,
		"dojo_id": dojo_id,
		"dojo_name": dojo_name,
		"dojo_element": clean_element,
		"bending_duel_contract": {
			"schema": "eralife.bending_duel_contract",
			"version": 2,
			"source": "bending_dojo_spar",
			"record_scope": "dojo_sparring",
			"uses_scenario_panel": true,
			"mock_match": true,
			"controlled_training": true,
			"damage_reflects_on_stats": false,
			"world_feed_enabled": false,
			"dojo_id": dojo_id,
			"dojo_name": dojo_name,
			"dojo_element": clean_element
		},
		"combat_ui": _bending_prefight_combat_ui(actor, target, {
			"id": dojo_id,
			"label": dojo_name,
			"division": "dojo_mock_match"
		}, {
			"match_id": "dojo_mock_match_%d_%d" % [int(actor.id), int(target.id)],
			"round_label": "Mock Match"
		}, "Mock match challenge issued"),
		"choices": [
			{
				"id": "bending_duel_accept",
				"label": "Begin the mock match",
				"journal_text": "I began a dojo mock match with %s." % target_name,
				"button_theme": "bending_ability",
				"power_source": "bending",
				"bending_duel_target_id": int(target.id)
			},
			{
				"id": "bending_duel_decline",
				"label": "Step off the mat",
				"journal_text": "I decided not to spar %s." % target_name,
				"button_theme": "defensive_escape",
				"power_source": "survival",
				"bending_duel_target_id": int(target.id)
			}
		],
		"context": {
			"dojo_id": dojo_id,
			"dojo_name": dojo_name,
			"dojo_element": clean_element,
			"actor_name": actor_name,
			"target_name": target_name,
			"source": str(options.get("source", "dojo_spar"))
		}
	}

	return {
		"schema": "eralife.bending_dojo_sparring_scenario_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"route": "scenario_engine",
		"scenario": scenario,
		"dojo_id": dojo_id,
		"dojo_name": dojo_name,
		"target_id": int(target.id),
		"target_name": target_name
	}

func _bending_prefight_combat_ui(actor: Person, opponent: Person, tournament: Dictionary = {}, match_row: Dictionary = {}, status_text: String = "Match ready") -> Dictionary:
	if gs != null and gs.bending_engine != null and gs.bending_engine.has_method("_bending_prefight_combat_ui"):
		var delegated: Variant = gs.bending_engine.call("_bending_prefight_combat_ui", actor, opponent, tournament, match_row, status_text)
		if typeof(delegated) == TYPE_DICTIONARY and not (delegated as Dictionary).is_empty():
			return (delegated as Dictionary).duplicate(true)

	var division: String = str(tournament.get("division", match_row.get("division", ""))).strip_edges().to_lower()
	var actor_element: String = _element_for_actor(actor)
	var opponent_element: String = _element_for_actor(opponent)

	if actor_element == "":
		actor_element = str(tournament.get("element", "bending")).strip_edges().to_lower()
	if opponent_element == "":
		opponent_element = str(tournament.get("element", actor_element)).strip_edges().to_lower()
	if actor_element == "":
		actor_element = "bending"
	if opponent_element == "":
		opponent_element = "bending"

	var actor_willpower: int = _dojo_actor_willpower_score(actor, {
		"source": "dojo_prefight_combat_ui",
		"division": division
	})
	var opponent_willpower: int = _dojo_actor_willpower_score(opponent, {
		"source": "dojo_prefight_combat_ui",
		"division": division
	})
	var odds: Dictionary = _dojo_prefight_win_odds(actor, opponent, division)

	return {
		"visible": true,
		"theme": _dojo_duel_theme_for_fighters(actor, opponent, actor_element),
		"player_theme": _dojo_actor_combat_theme(actor, actor_element),
		"enemy_theme": _dojo_actor_combat_theme(opponent, opponent_element),
		"player_avatar_pulse": actor != null and str(actor.bending_type).strip_edges().to_lower() == "avatar",
		"enemy_avatar_pulse": opponent != null and str(opponent.bending_type).strip_edges().to_lower() == "avatar",
		"status_text": status_text,
		"player_label": "%s • %s bending • Record %s • WP %d • Win odds %d%%" % [
			_person_label(actor),
			actor_element.capitalize(),
			_dojo_actor_record_summary(actor),
			actor_willpower,
			int(odds.get("actor_odds", 50))
		],
		"player_value": int(actor.health) if actor != null else 100,
		"player_max": max(1, int(actor.health) if actor != null else 100),
		"enemy_label": "%s • %s bending • Record %s • WP %d • Win odds %d%%" % [
			_person_label(opponent),
			opponent_element.capitalize(),
			_dojo_actor_record_summary(opponent),
			opponent_willpower,
			int(odds.get("opponent_odds", 50))
		],
		"enemy_value": int(opponent.health) if opponent != null else 100,
		"enemy_max": max(1, int(opponent.health) if opponent != null else 100),
		"prefight_read": {
			"actor_id": int(actor.id) if actor != null else -1,
			"opponent_id": int(opponent.id) if opponent != null else -1,
			"actor_willpower": actor_willpower,
			"opponent_willpower": opponent_willpower,
			"actor_record": _dojo_actor_record_summary(actor),
			"opponent_record": _dojo_actor_record_summary(opponent),
			"actor_odds": int(odds.get("actor_odds", 50)),
			"opponent_odds": int(odds.get("opponent_odds", 50)),
			"division": division,
			"tournament_id": str(tournament.get("id", "")),
			"tournament_match_id": str(match_row.get("match_id", ""))
		}
	}


func _dojo_prefight_win_odds(actor: Person, opponent: Person, division: String = "") -> Dictionary:
	if actor == null or opponent == null:
		return {
			"actor_odds": 50,
			"opponent_odds": 50,
			"actor_score": 0.0,
			"opponent_score": 0.0
		}

	var actor_score: float = float(_dojo_prefight_actor_score(actor, division))
	var opponent_score: float = float(_dojo_prefight_actor_score(opponent, division))

	actor_score += float(_dojo_actor_willpower_score(actor, {
		"source": "dojo_prefight_odds"
	})) * 0.35
	opponent_score += float(_dojo_actor_willpower_score(opponent, {
		"source": "dojo_prefight_odds"
	})) * 0.35

	var total: float = max(1.0, actor_score + opponent_score)
	var actor_odds: int = int(clamp(round((actor_score / total) * 100.0), 5.0, 95.0))
	var opponent_odds: int = 100 - actor_odds

	return {
		"actor_odds": actor_odds,
		"opponent_odds": opponent_odds,
		"actor_score": actor_score,
		"opponent_score": opponent_score
	}


func _dojo_prefight_actor_score(actor: Person, division: String = "") -> float:
	if actor == null:
		return 0.0

	var element: String = _element_for_actor(actor)
	if element == "":
		element = str(division).strip_edges().to_lower()
	if element == "":
		element = "bending"

	var level_score: float = float(_bending_level(actor, element))
	var health_score: float = float(actor.health)
	var mental_score: float = float(actor.mental_health)
	var smarts_score: float = float(actor.smarts)
	var respect_score: float = 50.0

	if typeof(actor.respect_profile) == TYPE_DICTIONARY:
		respect_score = float(actor.respect_profile.get("bending", actor.respect_profile.get("public", 50)))

	return (
		level_score * 1.2
		+ health_score * 0.34
		+ mental_score * 0.22
		+ smarts_score * 0.18
		+ respect_score * 0.16
	)


func _dojo_actor_willpower_score(actor: Person, context: Dictionary = {}) -> int:
	if actor == null:
		return 0

	if gs != null and "willpower_engine" in gs and gs.willpower_engine != null:
		if gs.willpower_engine.has_method("score"):
			return int(clamp(round(float(gs.willpower_engine.score(actor, context))), 0.0, 999.0))
		if gs.willpower_engine.has_method("ensure_willpower"):
			var profile: Dictionary = gs.willpower_engine.ensure_willpower(actor, context)
			return int(clamp(round(float(profile.get("core_score", actor.willpower))), 0.0, 999.0))

	return int(clamp(round(float(actor.willpower)), 0.0, 999.0))


func _dojo_actor_record_summary(actor: Person) -> String:
	if actor == null:
		return "0-0"

	if gs != null and gs.bending_engine != null and gs.bending_engine.has_method("_bending_actor_record_summary"):
		var delegated: Variant = gs.bending_engine.call("_bending_actor_record_summary", actor)
		var delegated_text: String = str(delegated).strip_edges()
		if delegated_text != "":
			return delegated_text

	var records: Dictionary = actor.bending_duel_records if typeof(actor.bending_duel_records) == TYPE_DICTIONARY else {}
	var overall: Dictionary = _safe_dictionary(records.get("overall", {}))
	var wins: int = int(overall.get("wins", 0))
	var losses: int = int(overall.get("losses", 0))
	var kos: int = int(overall.get("kos", 0))
	var deaths: int = int(overall.get("deaths", 0))

	var extra: Array = []
	if kos > 0:
		extra.append("%d KO" % kos)
	if deaths > 0:
		extra.append("%d lethal" % deaths)

	if extra.is_empty():
		return "%d-%d" % [wins, losses]

	return "%d-%d • %s" % [wins, losses, " | ".join(extra)]


func _dojo_actor_combat_theme(actor: Person, fallback_element: String = "") -> String:
	if actor != null and str(actor.bending_type).strip_edges().to_lower() == "avatar":
		return "bending_avatar"

	var element: String = _element_for_actor(actor)
	if element == "":
		element = str(fallback_element).strip_edges().to_lower()

	if element in ["air", "earth", "fire", "water"]:
		return "bending_element_%s" % element

	return "bending_duel"


func _dojo_duel_theme_for_fighters(actor: Person, opponent: Person, fallback_element: String = "") -> String:
	if actor != null and str(actor.bending_type).strip_edges().to_lower() == "avatar":
		return "bending_avatar"
	if opponent != null and str(opponent.bending_type).strip_edges().to_lower() == "avatar":
		return "bending_avatar"

	var element: String = _element_for_actor(actor)
	if element == "":
		element = str(fallback_element).strip_edges().to_lower()

	if element in ["air", "earth", "fire", "water"]:
		return "bending_element_%s" % element

	return "bending_duel"
func finalize_dojo_sparring_result(actor: Person, target: Person, duel: Dictionary, actor_won: bool, options: Dictionary = {}) -> Dictionary:
	if actor == null or target == null:
		return {
			"success": false,
			"popup_title": "Dojo Sparring",
			"popup_text": "The sparring result could not be finalized.",
			"popup_footer": "Tap anywhere to continue."
		}

	var membership: Dictionary = get_actor_dojo_membership(actor)
	var dojo: Dictionary = _dojo_by_id(str(duel.get("dojo_id", membership.get("dojo_id", ""))))
	if dojo.is_empty() and not membership.is_empty():
		dojo = _dojo_by_id(str(membership.get("dojo_id", "")))

	var dojo_id: String = str(dojo.get("id", duel.get("dojo_id", "")))
	var dojo_name: String = str(dojo.get("name", duel.get("dojo_name", "the dojo")))
	var element: String = str(dojo.get("element", duel.get("player_element", _element_for_actor(actor)))).strip_edges().to_lower()

	var tier_id: String = str(options.get("tier_id", duel.get("sparring_tier", "beginner"))).strip_edges().to_lower()
	if tier_id == "":
		tier_id = "beginner"

	var tier_config: Dictionary = _dojo_sparring_tier_config(tier_id)

	var winner: Person = actor if actor_won else target
	var loser: Person = target if actor_won else actor

	var finish_move: String = ""
	if typeof(duel.get("pending_player_attack", {})) == TYPE_DICTIONARY:
		finish_move = str(duel.get("pending_player_attack", {}).get("name", ""))

	if finish_move == "" and typeof(duel.get("last_enemy_move", {})) == TYPE_DICTIONARY:
		finish_move = str(duel.get("last_enemy_move", {}).get("name", "Controlled Sparring Finish"))

	if finish_move == "":
		finish_move = "Controlled Sparring Finish"

	var actor_level: int = _bending_level(actor, element)
	var target_level: int = _bending_level(target, element)
	var base_honor_gain: int = 4 if actor_won else 1
	var honor_gain: int = int(max(1, round(float(base_honor_gain) * float(tier_config.get("honor_multiplier", 1.0)))))
	var difficulty_bonus: int = int(floor(float(max(0, target_level - actor_level)) / 18.0))
	difficulty_bonus += int(floor(float(target_level) / 40.0))

	var progress_gain: int = int(clamp(
		round(float(int(dojo.get("spar_gain", 2)) + (2 if actor_won else 1) + difficulty_bonus) * float(tier_config.get("progress_multiplier", 1.0))),
		1,
		18
	))

	var skill_points_awarded: int = _dojo_sparring_skill_points(actor, target, dojo, element, actor_won, tier_id)

	if not dojo.is_empty():
		_add_dojo_honor(actor, dojo, honor_gain, {
			"source": "dojo_spar",
			"won": actor_won,
			"target_id": int(target.id),
			"target_level": target_level,
			"actor_level": actor_level,
			"skill_points_awarded": skill_points_awarded,
			"sparring_tier": tier_id,
			"sparring_tier_label": str(tier_config.get("label", "Beginner")),
			"duel": duel.duplicate(true)
		})

	if gs != null and gs.bending_engine != null and gs.bending_engine.has_method("gain_bending_progress"):
		gs.bending_engine.gain_bending_progress(actor, element, progress_gain, "interactive dojo sparring at %s" % dojo_name)

	if skill_points_awarded > 0 and gs != null and gs.bending_engine != null and gs.bending_engine.has_method("award_bending_skill_points"):
		gs.bending_engine.award_bending_skill_points(actor, skill_points_awarded, "dojo_sparring_%s" % ("win" if actor_won else "lesson"))

	var sparring_record: Dictionary = _record_dojo_sparring_result(actor, target, dojo, element, actor_won, skill_points_awarded, {
		"source": "dojo_spar",
		"finish_move": finish_move,
		"duel": duel.duplicate(true),
		"options": options.duplicate(true),
		"progress_gain": progress_gain,
		"tier_id": tier_id,
		"tier_label": str(tier_config.get("label", "Beginner")),
		"honor_gain": honor_gain
	})

	var match_payload: Dictionary = duel.get("match_payload", {}) if typeof(duel.get("match_payload", {})) == TYPE_DICTIONARY else {}
	var film_row: Dictionary = {}
	if bool(options.get("film_study_enabled", true)) and _dojo_film_study_available() and not match_payload.is_empty():
		film_row = _append_dojo_film_study_from_match(actor, dojo, match_payload, {
			"source": "player_dojo_spar",
			"tier_id": tier_id
		})

	var state: Dictionary = _ensure_state()
	var sparring_reports: Array = _safe_array(state.get("sparring_reports", []))
	var report: Dictionary = {
		"schema": "eralife.bending_dojo_sparring_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"interactive": true,
		"controlled_training": true,
		"actor_id": int(actor.id),
		"target_id": int(target.id),
		"winner_id": int(winner.id),
		"loser_id": int(loser.id),
		"dojo_id": dojo_id,
		"dojo_name": dojo_name,
		"element": element,
		"actor_level": actor_level,
		"target_level": target_level,
		"honor_gain": honor_gain,
		"progress_gain": progress_gain,
		"skill_points_awarded": skill_points_awarded,
		"finish_move": finish_move,
		"sparring_record": sparring_record.duplicate(true),
		"year": int(gs.year) if gs != null else 0,
		"duel": duel.duplicate(true),
		"sparring_tier": tier_id,
		"sparring_tier_label": str(tier_config.get("label", "Beginner")),
		"film_row": film_row.duplicate(true),
		"film_study_available": _dojo_film_study_available(),
		"film_study_locked_reason": _dojo_film_study_locked_reason(),
		"options": options.duplicate(true)
	}

	sparring_reports.append(report.duplicate(true))
	while sparring_reports.size() > 50:
		sparring_reports.pop_front()

	state ["sparring_reports"] = sparring_reports
	state ["last_report"] = report.duplicate(true)
	dojo_state = state.duplicate(true)
	last_report = report.duplicate(true)

	return {
		"success": true,
		"popup_title": "Dojo Mock Match Complete",
		"popup_text": "You sparred %s at %s.\n\nResult: %s\nFinish: %s\nSparring Record: %d-%d\nHonor gained: %d\nTraining progress: +%d\nSkill Points earned: +%d" % [
			_person_label(target),
			dojo_name,
			"You won the mock match." if actor_won else "You lost the mock match, but your tournament instincts sharpened.",
			finish_move,
			int(sparring_record.get("wins", 0)),
			int(sparring_record.get("losses", 0)),
			honor_gain,
			progress_gain,
			skill_points_awarded
		],
		"popup_footer": "Tap anywhere to continue.",
		"actor_won": actor_won,
		"target_id": int(target.id),
		"dojo_id": dojo_id,
		"honor_gain": honor_gain,
		"progress_gain": progress_gain,
		"skill_points_awarded": skill_points_awarded,
		"sparring_record": sparring_record.duplicate(true),
		"report": report.duplicate(true)
	}
func _blank_dojo_sparring_record(actor: Person) -> Dictionary:
	return {
		"schema": "eralife.bending_dojo_sparring_record",
		"version": CONTRACT_VERSION,
		"actor_id": int(actor.id) if actor != null else -1,
		"actor_name": _person_label(actor),
		"matches": 0,
		"wins": 0,
		"losses": 0,
		"current_streak": 0,
		"best_streak": 0,
		"skill_points_earned": 0,
		"honor_earned": 0,
		"progress_earned": 0,
		"last_result": "",
		"last_opponent_id": -1,
		"last_opponent_name": "",
		"last_finish_move": "",
		"last_dojo_id": "",
		"last_dojo_name": "",
		"last_year": int(gs.year) if gs != null else 0,
		"last_match": {}
	}


func _dojo_sparring_record_for_actor(actor: Person) -> Dictionary:
	if actor == null:
		return {}

	var state: Dictionary = _ensure_state()
	var records: Dictionary = _safe_dictionary(state.get("sparring_records", {}))
	var actor_key: String = str(int(actor.id))
	var record: Dictionary = _safe_dictionary(records.get(actor_key, {}))

	if record.is_empty():
		record = _blank_dojo_sparring_record(actor)
	else:
		record ["schema"] = str(record.get("schema", "eralife.bending_dojo_sparring_record"))
		record ["version"] = int(record.get("version", CONTRACT_VERSION))
		record ["actor_id"] = int(record.get("actor_id", actor.id))
		record ["actor_name"] = str(record.get("actor_name", _person_label(actor)))
		record ["matches"] = int(record.get("matches", 0))
		record ["wins"] = int(record.get("wins", 0))
		record ["losses"] = int(record.get("losses", 0))
		record ["current_streak"] = int(record.get("current_streak", 0))
		record ["best_streak"] = int(record.get("best_streak", 0))
		record ["skill_points_earned"] = int(record.get("skill_points_earned", 0))
		record ["honor_earned"] = int(record.get("honor_earned", 0))
		record ["progress_earned"] = int(record.get("progress_earned", 0))
		record ["last_result"] = str(record.get("last_result", ""))
		record ["last_opponent_id"] = int(record.get("last_opponent_id", -1))
		record ["last_opponent_name"] = str(record.get("last_opponent_name", ""))
		record ["last_finish_move"] = str(record.get("last_finish_move", ""))
		record ["last_dojo_id"] = str(record.get("last_dojo_id", ""))
		record ["last_dojo_name"] = str(record.get("last_dojo_name", ""))
		record ["last_year"] = int(record.get("last_year", int(gs.year) if gs != null else 0))

		if typeof(record.get("last_match", {})) != TYPE_DICTIONARY:
			record ["last_match"] = {}

	records [actor_key] = record.duplicate(true)
	state ["sparring_records"] = records
	dojo_state = state.duplicate(true)

	return record.duplicate(true)


func _dojo_sparring_skill_points(actor: Person, target: Person, dojo: Dictionary, element: String, actor_won: bool, tier_id: String = "") -> int:
	if actor == null or target == null:
		return 0

	var clean_element: String = str(element).strip_edges().to_lower()
	if clean_element == "":
		clean_element = _element_for_actor(actor)

	var actor_level: int = _bending_level(actor, clean_element)
	var target_level: int = _bending_level(target, clean_element)
	var dojo_tier: String = str(dojo.get("tier", "local")).strip_edges().to_lower()
	var sparring_tier: Dictionary = _dojo_sparring_tier_config(tier_id)
	var sparring_tier_id: String = str(sparring_tier.get("id", "beginner"))

	if not actor_won:
		if sparring_tier_id in ["advanced", "master"]:
			return 1
		if target_level >= 70:
			return 1
		return 0

	var points: int = 1
	points += int(floor(float(target_level) / 25.0))

	var level_gap: int = target_level - actor_level
	if level_gap >= 10:
		points += 1
	if level_gap >= 25:
		points += 1

	match dojo_tier:
		"elite", "legacy", "premium":
			points += 1

	match sparring_tier_id:
		"intermediate":
			points += 1
		"advanced":
			points += 2
		"master":
			points += 3

	var multiplier: float = float(sparring_tier.get("skill_multiplier", 1.0))
	points = int(ceil(float(points) * multiplier))

	return clamp(points, 1, 10)


func _record_dojo_sparring_result(actor: Person, target: Person, dojo: Dictionary, element: String, actor_won: bool, skill_points_awarded: int, context: Dictionary = {}) -> Dictionary:
	if actor == null or target == null:
		return {}

	var state: Dictionary = _ensure_state()
	var records: Dictionary = _safe_dictionary(state.get("sparring_records", {}))
	var actor_key: String = str(int(actor.id))
	var record: Dictionary = _dojo_sparring_record_for_actor(actor)

	var finish_move: String = str(context.get("finish_move", "Controlled Sparring Finish")).strip_edges()
	if finish_move == "":
		finish_move = "Controlled Sparring Finish"

	var dojo_id: String = str(dojo.get("id", context.get("dojo_id", ""))).strip_edges()
	var dojo_name: String = str(dojo.get("name", context.get("dojo_name", "Bending Dojo"))).strip_edges()
	var result_text: String = "win" if actor_won else "loss"

	record ["matches"] = int(record.get("matches", 0)) + 1

	if actor_won:
		record ["wins"] = int(record.get("wins", 0)) + 1
		record ["current_streak"] = max(1, int(record.get("current_streak", 0)) + 1)
		record ["best_streak"] = max(int(record.get("best_streak", 0)), int(record.get("current_streak", 0)))
	else:
		record ["losses"] = int(record.get("losses", 0)) + 1
		record ["current_streak"] = min(-1, int(record.get("current_streak", 0)) - 1)

	record ["skill_points_earned"] = int(record.get("skill_points_earned", 0)) + max(0, int(skill_points_awarded))
	record ["honor_earned"] = int(record.get("honor_earned", 0)) + max(0, int(context.get("honor_gain", 0)))
	record ["progress_earned"] = int(record.get("progress_earned", 0)) + max(0, int(context.get("progress_gain", 0)))
	record ["last_result"] = result_text
	record ["last_opponent_id"] = int(target.id)
	record ["last_opponent_name"] = _person_label(target)
	record ["last_finish_move"] = finish_move
	record ["last_dojo_id"] = dojo_id
	record ["last_dojo_name"] = dojo_name
	record ["last_year"] = int(gs.year) if gs != null else 0
	record ["last_match"] = {
		"schema": "eralife.bending_dojo_sparring_match_record",
		"version": CONTRACT_VERSION,
		"actor_id": int(actor.id),
		"target_id": int(target.id),
		"target_name": _person_label(target),
		"dojo_id": dojo_id,
		"dojo_name": dojo_name,
		"element": str(element).strip_edges().to_lower(),
		"result": result_text,
		"finish_move": finish_move,
		"actor_level": _bending_level(actor, element),
		"target_level": _bending_level(target, element),
		"skill_points_awarded": max(0, int(skill_points_awarded)),
		"honor_gain": max(0, int(context.get("honor_gain", 0))),
		"progress_gain": max(0, int(context.get("progress_gain", 0))),
		"year": int(gs.year) if gs != null else 0
	}

	records [actor_key] = record.duplicate(true)
	state ["sparring_records"] = records
	dojo_state = state.duplicate(true)

	return record.duplicate(true)

func record_tournament_honor(actor: Person, tournament: Dictionary, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "missing_actor"
		}

	var membership: Dictionary = get_actor_dojo_membership(actor)
	if membership.is_empty():
		return {
			"success": false,
			"reason": "actor_has_no_dojo"
		}

	var dojo: Dictionary = _dojo_by_id(str(membership.get("dojo_id", "")))
	if dojo.is_empty():
		return {
			"success": false,
			"reason": "dojo_missing"
		}

	var won: bool = bool(context.get("won", false))
	var honor_gain: int = 18 if won else 4
	if bool(context.get("championship", true)):
		honor_gain += 12

	_add_dojo_honor(actor, dojo, honor_gain, {
		"source": "tournament",
		"won": won,
		"tournament_id": str(tournament.get("id", "")),
		"tournament_label": str(tournament.get("label", "Bending Tournament"))
	})

	return {
		"success": true,
		"dojo_id": str(dojo.get("id", "")),
		"dojo_name": str(dojo.get("name", "")),
		"honor_gain": honor_gain
	}


func _ensure_state() -> Dictionary:
	if typeof(dojo_state) != TYPE_DICTIONARY or dojo_state.is_empty():
		dojo_state = {
			"schema": STATE_SCHEMA,
			"version": CONTRACT_VERSION,
			"created_year": int(gs.year) if gs != null else 0,
			"dojos": _seed_dojos(),
			"enrollments": {},
			"dojo_reputation": {},
			"dojo_history": {},
			"dojo_rosters": {},
			"dojo_rivalries": {},
			"training_reports": [],
			"sparring_reports": [],
			"sparring_records": {},
			"sparring_film_study": [],
			"sparring_style_memory": {},
			"dojo_live_spar_reports": [],
			"dojo_global_rankings": [],
			"dojo_legends": {},
			"dojo_awareness_reports": [],
			"last_report": {}
		}

	if not dojo_state.has("dojos") or typeof(dojo_state.get("dojos")) != TYPE_ARRAY:
		dojo_state ["dojos"] = _seed_dojos()
	if not dojo_state.has("enrollments") or typeof(dojo_state.get("enrollments")) != TYPE_DICTIONARY:
		dojo_state ["enrollments"] = {}
	if not dojo_state.has("dojo_reputation") or typeof(dojo_state.get("dojo_reputation")) != TYPE_DICTIONARY:
		dojo_state ["dojo_reputation"] = {}
	if not dojo_state.has("dojo_history") or typeof(dojo_state.get("dojo_history")) != TYPE_DICTIONARY:
		dojo_state ["dojo_history"] = {}
	if not dojo_state.has("dojo_rosters") or typeof(dojo_state.get("dojo_rosters")) != TYPE_DICTIONARY:
		dojo_state ["dojo_rosters"] = {}
	if not dojo_state.has("dojo_rivalries") or typeof(dojo_state.get("dojo_rivalries")) != TYPE_DICTIONARY:
		dojo_state ["dojo_rivalries"] = {}
	if not dojo_state.has("training_reports") or typeof(dojo_state.get("training_reports")) != TYPE_ARRAY:
		dojo_state ["training_reports"] = []
	if not dojo_state.has("sparring_reports") or typeof(dojo_state.get("sparring_reports")) != TYPE_ARRAY:
		dojo_state ["sparring_reports"] = []
	if not dojo_state.has("sparring_records") or typeof(dojo_state.get("sparring_records")) != TYPE_DICTIONARY:
		dojo_state ["sparring_records"] = {}
	if not dojo_state.has("sparring_film_study") or typeof(dojo_state.get("sparring_film_study")) != TYPE_ARRAY:
		dojo_state ["sparring_film_study"] = []
	if not dojo_state.has("sparring_style_memory") or typeof(dojo_state.get("sparring_style_memory")) != TYPE_DICTIONARY:
		dojo_state ["sparring_style_memory"] = {}
	if not dojo_state.has("dojo_live_spar_reports") or typeof(dojo_state.get("dojo_live_spar_reports")) != TYPE_ARRAY:
		dojo_state ["dojo_live_spar_reports"] = []
	if not dojo_state.has("dojo_global_rankings") or typeof(dojo_state.get("dojo_global_rankings")) != TYPE_ARRAY:
		dojo_state ["dojo_global_rankings"] = []
	if not dojo_state.has("dojo_legends") or typeof(dojo_state.get("dojo_legends")) != TYPE_DICTIONARY:
		dojo_state ["dojo_legends"] = {}
	if not dojo_state.has("dojo_awareness_reports") or typeof(dojo_state.get("dojo_awareness_reports")) != TYPE_ARRAY:
		dojo_state ["dojo_awareness_reports"] = []
	if not dojo_state.has("last_report") or typeof(dojo_state.get("last_report")) != TYPE_DICTIONARY:
		dojo_state ["last_report"] = {}

	return dojo_state

func _seed_dojos() -> Array:
	var out: Array = []
	var templates: Array = _safe_array(active_contract.get("dojo_templates", []))

	for raw_template in templates:
		if typeof(raw_template) == TYPE_DICTIONARY:
			out.append(raw_template.duplicate(true))

	return out


func _default_contract() -> Dictionary:
	return {
		"schema": CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": "default_bending_dojo_contract",
		"age_groups": {
			"kids": { "min_age": 3, "max_age": 12},
			"teen": { "min_age": 13, "max_age": 17},
			"adult": { "min_age": 18, "max_age": 64},
			"elder": { "min_age": 65, "max_age": 999}
		},
		"dojo_templates": [
			{
				"id": "air_youth_spiral_dojo",
				"name": "Sky Spiral Youth Dojo",
				"element": "air",
				"tier": "starter",
				"age_policy": "kids",
				"required_level": 0,
				"required_social_score": 0,
				"training_gain": 2,
				"spar_gain": 2,
				"skill_point_gain": 1,
				"teacher_min_level": 45
			},
			{
				"id": "air_thousand_step_monastery",
				"name": "Thousand Step Air Monastery",
				"element": "air",
				"tier": "elite",
				"age_policy": "all",
				"required_level": 45,
				"required_social_score": 20,
				"training_gain": 5,
				"spar_gain": 4,
				"skill_point_gain": 2,
				"teacher_min_level": 78
			},
			{
				"id": "water_moon_pool_dojo",
				"name": "Moon Pool Waterbending Dojo",
				"element": "water",
				"tier": "standard",
				"age_policy": "all",
				"required_level": 5,
				"required_social_score": 0,
				"training_gain": 3,
				"spar_gain": 3,
				"skill_point_gain": 1,
				"teacher_min_level": 55
			},
			{
				"id": "water_white_tide_academy",
				"name": "White Tide Academy",
				"element": "water",
				"tier": "premium",
				"age_policy": "teen",
				"required_level": 30,
				"required_social_score": 25,
				"training_gain": 5,
				"spar_gain": 4,
				"skill_point_gain": 2,
				"teacher_min_level": 76
			},
			{
				"id": "earth_stone_gate_dojo",
				"name": "Stone Gate Earthbending Dojo",
				"element": "earth",
				"tier": "standard",
				"age_policy": "all",
				"required_level": 5,
				"required_social_score": 0,
				"training_gain": 3,
				"spar_gain": 3,
				"skill_point_gain": 1,
				"teacher_min_level": 55
			},
			{
				"id": "earth_iron_root_hall",
				"name": "Iron Root Hall",
				"element": "earth",
				"tier": "premium",
				"age_policy": "adult",
				"required_level": 38,
				"required_social_score": 18,
				"training_gain": 5,
				"spar_gain": 4,
				"skill_point_gain": 2,
				"teacher_min_level": 80
			},
			{
				"id": "fire_sun_court_dojo",
				"name": "Sun Court Firebending Dojo",
				"element": "fire",
				"tier": "standard",
				"age_policy": "all",
				"required_level": 5,
				"required_social_score": 0,
				"training_gain": 3,
				"spar_gain": 3,
				"skill_point_gain": 1,
				"teacher_min_level": 55
			},
			{
				"id": "fire_crimson_dragon_school",
				"name": "Crimson Dragon School",
				"element": "fire",
				"tier": "elite",
				"age_policy": "all",
				"required_level": 55,
				"required_social_score": 30,
				"training_gain": 6,
				"spar_gain": 5,
				"skill_point_gain": 3,
				"teacher_min_level": 88
			},
			{
				"id": "elder_lotus_dojo",
				"name": "Elder Lotus Bending Hall",
				"element": "air",
				"tier": "legacy",
				"age_policy": "elder",
				"required_level": 25,
				"required_social_score": 0,
				"training_gain": 4,
				"spar_gain": 3,
				"skill_point_gain": 2,
				"teacher_min_level": 75
			}
		]
	}

func _dojo_by_id(dojo_id: String) -> Dictionary:
	for raw_dojo in _safe_array(_ensure_state().get("dojos", [])):
		if typeof(raw_dojo) != TYPE_DICTIONARY:
			continue

		var dojo: Dictionary = raw_dojo
		if str(dojo.get("id", "")) == dojo_id:
			return dojo.duplicate(true)

	return {}


func _dojo_accepts_age(dojo: Dictionary, age_value: int) -> bool:
	var policy: String = str(dojo.get("age_policy", "all")).strip_edges().to_lower()
	if policy == "all":
		return true
	if policy == "kids":
		return age_value >= 3 and age_value <= 12
	if policy == "teen":
		return age_value >= 13 and age_value <= 17
	if policy == "adult":
		return age_value >= 18 and age_value <= 64
	if policy == "elder":
		return age_value >= 65
	return true


func _teacher_for_dojo(_actor: Person, dojo: Dictionary) -> Person:
	if gs == null or gs.bending_engine == null:
		return null

	var institution: Dictionary = _ensure_dojo_institution_state(dojo)
	var sensei_id: int = int(institution.get("active_sensei_id", -1))
	var sensei: Person = _find_person_by_id(sensei_id)

	if sensei != null and bool(sensei.alive):
		return sensei

	institution = _rotate_dojo_sensei(dojo, "sensei_unavailable")
	sensei_id = int(institution.get("active_sensei_id", -1))
	return _find_person_by_id(sensei_id)


func _classmates_for_dojo(actor: Person, dojo: Dictionary) -> Array:
	var out: Array = []
	if gs == null:
		return out

	var institution: Dictionary = _ensure_dojo_institution_state(dojo)
	var classmate_ids: Array = _safe_array(institution.get("active_classmate_ids", []))
	var element: String = str(dojo.get("element", _element_for_actor(actor))).strip_edges().to_lower()

	for raw_id in classmate_ids:
		var npc: Person = _find_person_by_id(int(raw_id))
		if npc == null or not bool(npc.alive):
			continue
		if actor != null and int(npc.id) == int(actor.id):
			continue
		if not _dojo_accepts_age(dojo, int(npc.age)):
			continue

		out.append({
			"id": int(npc.id),
			"name": _person_label(npc),
			"age": int(npc.age),
			"level": _bending_level(npc, element),
			"dojo_id": str(dojo.get("id", "")),
			"dojo_name": str(dojo.get("name", "Bending Dojo"))
		})

		if out.size() >= 12:
			break

	return out

func _classmate_names(classmates: Array) -> String:
	var names: Array = []
	for raw_row in classmates:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = raw_row
		names.append("%s, age %d" % [
			str(row.get("name", "Unknown")),
			int(row.get("age", 0))
		])
	return ", ".join(names)


func _element_for_actor(actor: Person) -> String:
	if actor == null:
		return ""
	var bending_type: String = str(actor.bending_type).strip_edges().to_lower()
	if bending_type in ["air", "water", "earth", "fire"]:
		return bending_type
	if gs != null and gs.bending_engine != null and gs.bending_engine.has_method("_element_from_nation"):
		return str(gs.bending_engine._element_from_nation(str(actor.bending_nation))).strip_edges().to_lower()
	return ""


func _bending_level(actor: Person, element: String) -> int:
	if actor == null or gs == null or gs.bending_engine == null:
		return 0

	var clean_element: String = str(element).strip_edges().to_lower()
	if clean_element == "":
		return 0

	var engine = gs.bending_engine

	if engine.has_method("_base_bending_elements"):
		if clean_element not in engine._base_bending_elements():
			return 0

	if engine.has_method("_ensure_bending_level_storage_only"):
		engine._ensure_bending_level_storage_only(actor)

	if engine.has_method("_raw_bending_level"):
		return int(engine._raw_bending_level(actor, clean_element))

	if typeof(actor.bending_mastery) == TYPE_DICTIONARY:
		return clamp(int(actor.bending_mastery.get(clean_element, 0)), 0, 100)

	return 0


func _person_label(person: Person) -> String:
	if person == null:
		return "Unknown"
	return ("%s %s" % [str(person.first_name), str(person.last_name)]).strip_edges()

func _dojo_entry_gate(actor: Person, dojo: Dictionary) -> Dictionary:
	if actor == null:
		return {
			"allowed": false,
			"reason": "missing_actor",
			"reason_text": "No bender was selected."
		}

	var element: String = str(dojo.get("element", _element_for_actor(actor))).strip_edges().to_lower()
	var actor_element: String = _element_for_actor(actor)
	if element != "" and actor_element != "" and element != actor_element:
		return {
			"allowed": false,
			"reason": "wrong_element",
			"reason_text": "%s only trains %s benders." % [
				str(dojo.get("name", "This dojo")),
				element.capitalize()
			]
		}

	if not _dojo_accepts_age(dojo, int(actor.age)):
		return {
			"allowed": false,
			"reason": "age_locked",
			"reason_text": "%s does not accept your age group." % str(dojo.get("name", "This dojo"))
		}

	var required_level: int = int(dojo.get("required_level", 0))
	var current_level: int = _bending_level(actor, element)
	if current_level < required_level:
		return {
			"allowed": false,
			"reason": "level_locked",
			"reason_text": "%s requires %s bending level %d.\n\nYour current level: %d." % [
				str(dojo.get("name", "This dojo")),
				element.capitalize(),
				required_level,
				current_level
			],
			"required_level": required_level,
			"current_level": current_level
		}

	var required_social_score: int = int(dojo.get("required_social_score", 0))
	var social_score: int = _actor_social_class_score(actor)
	if social_score < required_social_score:
		return {
			"allowed": false,
			"reason": "patronage_locked",
			"reason_text": "%s is selective. You have the bending foundation, but you need stronger public standing, wealth, fame, or patronage to qualify.\n\nRequired standing: %d\nYour standing: %d." % [
				str(dojo.get("name", "This dojo")),
				required_social_score,
				social_score
			],
			"required_social_score": required_social_score,
			"current_social_score": social_score
		}

	return {
		"allowed": true,
		"reason": "qualified",
		"reason_text": "You qualify for %s." % str(dojo.get("name", "this dojo")),
		"required_level": required_level,
		"current_level": current_level,
		"required_social_score": required_social_score,
		"current_social_score": social_score
	}


func _actor_social_class_score(actor: Person) -> int:
	if actor == null:
		return 0

	var score: int = 0
	score += int(floor(float(clamp(int(actor.fame), 0, 100)) / 4.0))
	score += int(clamp(floor(float(actor.income) / 25000.0), 0.0, 25.0))
	score += int(clamp(floor(float(actor.bank_balance) / 100000.0), 0.0, 25.0))

	if "royal_title" in actor and str(actor.royal_title).strip_edges() != "":
		score += 35
	if "title" in actor and str(actor.title).strip_edges() != "":
		score += 20
	if int(actor.respect) > 60:
		score += 10

	return int(clamp(score, 0, 100))

func _apply_dojo_legacy_from_match(dojo: Dictionary, winner: Person, loser: Person, match_payload: Dictionary, context: Dictionary = {}) -> Dictionary:
	if dojo.is_empty() or winner == null:
		return {}

	var element: String = str(dojo.get("element", match_payload.get("element", _element_for_actor(winner)))).strip_edges().to_lower()
	var winner_level: int = _bending_level(winner, element)
	var loser_level: int = _bending_level(loser, element) if loser != null else 0
	var dojo_id: String = str(dojo.get("id", "")).strip_edges()

	var renown_gain: int = 1
	renown_gain += int(floor(float(winner_level) / 24.0))
	renown_gain += int(floor(float(max(0, loser_level - winner_level)) / 18.0))

	if bool(context.get("spectated", false)):
		renown_gain += 1
	if str(context.get("source", "")).find("tournament") >= 0:
		renown_gain += 6
	if _is_avatar_bender(winner):
		renown_gain += 18
	elif winner_level >= 90:
		renown_gain += 8
	elif winner_level >= 75:
		renown_gain += 4

	_bump_dojo_reputation(dojo, renown_gain, {
		"source": str(context.get("source", "dojo_match_legacy")),
		"winner_id": int(winner.id),
		"winner_name": _person_label(winner),
		"winner_level": winner_level,
		"loser_id": int(loser.id) if loser != null else -1,
		"loser_name": _person_label(loser) if loser != null else "",
		"finish_move": str(match_payload.get("finish_move", "")),
		"year": int(gs.year) if gs != null else 0
	})

	var legend_row: Dictionary = _maybe_promote_dojo_legend(dojo, winner, match_payload, {
		"source": str(context.get("source", "dojo_match_legacy")),
		"winner_level": winner_level,
		"renown_gain": renown_gain
	})

	return {
		"success": true,
		"dojo_id": dojo_id,
		"renown_gain": renown_gain,
		"legend_row": legend_row.duplicate(true)
	}
func _bump_dojo_reputation(dojo: Dictionary, amount: int, context: Dictionary = {}) -> void:
	if dojo.is_empty():
		return

	var dojo_id: String = str(dojo.get("id", "")).strip_edges()
	if dojo_id == "":
		return

	var state: Dictionary = _ensure_state()
	var reputation: Dictionary = _safe_dictionary(state.get("dojo_reputation", {}))
	var row: Dictionary = _safe_dictionary(reputation.get(dojo_id, {}))

	row ["dojo_id"] = dojo_id
	row ["dojo_name"] = str(dojo.get("name", "Bending Dojo"))
	row ["element"] = str(dojo.get("element", ""))
	row ["honor"] = int(row.get("honor", 0)) + max(0, int(amount))
	row ["renown"] = int(row.get("renown", 0)) + max(0, int(amount))
	row ["tournament_points"] = int(row.get("tournament_points", 0)) + int(context.get("tournament_points", 0))
	row ["legend_points"] = int(row.get("legend_points", 0)) + int(context.get("legend_points", 0))
	row ["last_context"] = context.duplicate(true)
	row ["updated_year"] = int(gs.year) if gs != null else 0

	reputation [dojo_id] = row
	state ["dojo_reputation"] = reputation
	state ["dojo_global_rankings"] = _global_dojo_rankings_from_state(state)
	dojo_state = state.duplicate(true)
func _maybe_promote_dojo_legend(dojo: Dictionary, actor: Person, match_payload: Dictionary, _context: Dictionary = {}) -> Dictionary:
	if actor == null or dojo.is_empty():
		return {}

	var element: String = str(dojo.get("element", match_payload.get("element", _element_for_actor(actor)))).strip_edges().to_lower()
	var level: int = _bending_level(actor, element)
	var actor_key: String = str(int(actor.id))

	var qualifies: bool = false
	var title: String = ""

	if _is_avatar_bender(actor):
		qualifies = true
		title = "Avatar-Trained Legend"
	elif int(actor.age) <= 17 and level >= 72:
		qualifies = true
		title = "Dojo Prodigy"
	elif level >= 90:
		qualifies = true
		title = "Dojo Legend"
	elif level >= 82 and str(match_payload.get("source", "")).find("tournament") >= 0:
		qualifies = true
		title = "Tournament-Raised Legend"

	if not qualifies:
		return {}

	var state: Dictionary = _ensure_state()
	var legends: Dictionary = _safe_dictionary(state.get("dojo_legends", {}))
	var existing: Dictionary = _safe_dictionary(legends.get(actor_key, {}))

	var row: Dictionary = existing.duplicate(true)
	row ["schema"] = "eralife.bending_dojo_legend"
	row ["version"] = CONTRACT_VERSION
	row ["actor_id"] = int(actor.id)
	row ["actor_name"] = _person_label(actor)
	row ["title"] = title
	row ["dojo_id"] = str(dojo.get("id", ""))
	row ["dojo_name"] = str(dojo.get("name", "Bending Dojo"))
	row ["element"] = element
	row ["level"] = level
	row ["age_first_seen"] = int(row.get("age_first_seen", int(actor.age)))
	row ["year_first_seen"] = int(row.get("year_first_seen", int(gs.year) if gs != null else 0))
	row ["last_finish_move"] = str(match_payload.get("finish_move", ""))
	row ["legend_score"] = max(int(row.get("legend_score", 0)), level + int(actor.fame) + int(actor.respect))
	row ["updated_year"] = int(gs.year) if gs != null else 0

	legends [actor_key] = row
	state ["dojo_legends"] = legends

	_bump_dojo_reputation(dojo, 8 if title == "Dojo Prodigy" else 12, {
		"source": "dojo_legend_promoted",
		"legend_points": 12,
		"legend_actor_id": int(actor.id),
		"legend_title": title
	})

	dojo_state = state.duplicate(true)
	return row.duplicate(true)
func _global_dojo_rankings_from_state(state: Dictionary) -> Array:
	var reputation: Dictionary = _safe_dictionary(state.get("dojo_reputation", {}))
	var legends: Dictionary = _safe_dictionary(state.get("dojo_legends", {}))
	var rows: Array = []

	for raw_dojo in _safe_array(state.get("dojos", [])):
		if typeof(raw_dojo) != TYPE_DICTIONARY:
			continue

		var dojo: Dictionary = raw_dojo
		var dojo_id: String = str(dojo.get("id", "")).strip_edges()
		if dojo_id == "":
			continue

		var rep: Dictionary = _safe_dictionary(reputation.get(dojo_id, {}))
		var legend_count: int = 0
		for raw_legend in legends.values():
			if typeof(raw_legend) != TYPE_DICTIONARY:
				continue
			var legend: Dictionary = raw_legend
			if str(legend.get("dojo_id", "")) == dojo_id:
				legend_count += 1

		var ranking_score: int = int(rep.get("renown", 0))
		ranking_score += int(rep.get("tournament_points", 0)) * 3
		ranking_score += int(rep.get("legend_points", 0)) * 4
		ranking_score += legend_count * 18

		rows.append({
			"dojo_id": dojo_id,
			"dojo_name": str(dojo.get("name", "Bending Dojo")),
			"element": str(dojo.get("element", "")),
			"tier": str(dojo.get("tier", "local")),
			"renown": int(rep.get("renown", 0)),
			"tournament_points": int(rep.get("tournament_points", 0)),
			"legend_points": int(rep.get("legend_points", 0)),
			"legend_count": legend_count,
			"ranking_score": ranking_score
		})

	rows.sort_custom(func (a, b):
		if int(a.get("ranking_score", 0)) != int(b.get("ranking_score", 0)):
			return int(a.get("ranking_score", 0)) > int(b.get("ranking_score", 0))
		return str(a.get("dojo_name", "")) < str(b.get("dojo_name", ""))
	)

	for index in range(rows.size()):
		var row: Dictionary = rows [index]
		row ["global_rank"] = index + 1
		rows [index] = row

	return rows
func _global_dojo_rankings() -> Array:
	var state: Dictionary = _ensure_state()
	var rankings: Array = _global_dojo_rankings_from_state(state)
	state ["dojo_global_rankings"] = rankings
	dojo_state = state.duplicate(true)
	return rankings
func _is_avatar_bender(actor: Person) -> bool:
	if actor == null:
		return false
	return str(actor.bending_type).strip_edges().to_lower() == "avatar"
func _dojo_awareness_row(actor: Person, dojo: Dictionary) -> Dictionary:
	if actor == null or dojo.is_empty():
		return {}

	var element: String = str(dojo.get("element", _element_for_actor(actor))).strip_edges().to_lower()
	var level: int = _bending_level(actor, element)
	var is_avatar: bool = _is_avatar_bender(actor)

	var awareness_level: String = "normal"
	var room_text: String = "The dojo treats you like another student."

	if is_avatar:
		awareness_level = "avatar"
		room_text = "The whole room knows the Avatar is on the floor. Students lower their voices, the sensei watches carefully, and every spar suddenly feels historic."
	elif level >= 90:
		awareness_level = "legendary_bender"
		room_text = "Everyone in the gym knows they are standing near a legendary bender."
	elif level >= 75:
		awareness_level = "high_level_bender"
		room_text = "Students keep glancing over. Your bending level changes the room."
	elif int(actor.fame) >= 70:
		awareness_level = "famous_bender"
		room_text = "People recognize you before the lesson even begins."

	return {
		"schema": "eralife.bending_dojo_awareness",
		"version": CONTRACT_VERSION,
		"actor_id": int(actor.id),
		"actor_name": _person_label(actor),
		"dojo_id": str(dojo.get("id", "")),
		"dojo_name": str(dojo.get("name", "Bending Dojo")),
		"element": element,
		"level": level,
		"is_avatar": is_avatar,
		"awareness_level": awareness_level,
		"room_text": room_text
	}
func _register_dojo_presence_awareness(actor: Person, dojo: Dictionary, context: Dictionary = {}) -> Dictionary:
	var awareness: Dictionary = _dojo_awareness_row(actor, dojo)
	if awareness.is_empty():
		return {}

	var awareness_level: String = str(awareness.get("awareness_level", "normal"))
	if awareness_level == "normal":
		return awareness

	var renown_gain: int = 0
	if awareness_level == "avatar":
		renown_gain = 28
	elif awareness_level == "legendary_bender":
		renown_gain = 12
	elif awareness_level == "high_level_bender":
		renown_gain = 6
	elif awareness_level == "famous_bender":
		renown_gain = 4

	_bump_dojo_reputation(dojo, renown_gain, {
		"source": str(context.get("source", "dojo_presence_awareness")),
		"awareness_level": awareness_level,
		"actor_id": int(actor.id),
		"actor_name": _person_label(actor),
		"renown_gain": renown_gain
	})

	var state: Dictionary = _ensure_state()
	var reports: Array = _safe_array(state.get("dojo_awareness_reports", []))
	reports.append(awareness.duplicate(true))
	while reports.size() > 80:
		reports.pop_front()
	state ["dojo_awareness_reports"] = reports
	dojo_state = state.duplicate(true)

	return awareness
func _dojo_for_actor_or_roster(actor: Person) -> Dictionary:
	if actor == null:
		return {}

	var membership: Dictionary = get_actor_dojo_membership(actor)
	if not membership.is_empty():
		return _dojo_by_id(str(membership.get("dojo_id", "")))

	var state: Dictionary = _ensure_state()
	var rosters: Dictionary = _safe_dictionary(state.get("dojo_rosters", {}))
	for dojo_id in rosters.keys():
		var roster: Dictionary = _safe_dictionary(rosters.get(dojo_id, {}))
		var ids: Array = _safe_array(roster.get("active_classmate_ids", []))
		if ids.has(int(actor.id)):
			return _dojo_by_id(str(dojo_id))

	return {}
func apply_dojo_tournament_legacy_from_duel(winner: Person, loser: Person, context: Dictionary = {}) -> Dictionary:
	if winner == null:
		return {
			"success": false,
			"reason": "winner_missing"
		}

	var winner_dojo: Dictionary = _dojo_for_actor_or_roster(winner)
	if winner_dojo.is_empty():
		return {
			"success": false,
			"reason": "winner_has_no_dojo_context"
		}

	var finish_move: String = str(context.get("finish_move", "Tournament Finish"))
	var match_payload: Dictionary = {
		"source": "bending_tournament",
		"element": str(winner_dojo.get("element", _element_for_actor(winner))),
		"winner_id": int(winner.id),
		"winner_name": _person_label(winner),
		"loser_id": int(loser.id) if loser != null else -1,
		"loser_name": _person_label(loser) if loser != null else "",
		"finish_move": finish_move,
		"tournament_id": str(context.get("tournament_id", "")),
		"tournament_match_id": str(context.get("tournament_match_id", "")),
		"year": int(gs.year) if gs != null else 0
	}

	_bump_dojo_reputation(winner_dojo, 10, {
		"source": "tournament_win",
		"tournament_points": 6,
		"winner_id": int(winner.id),
		"winner_name": _person_label(winner),
		"finish_move": finish_move
	})

	var legacy_report: Dictionary = _apply_dojo_legacy_from_match(winner_dojo, winner, loser, match_payload, {
		"source": "tournament_dojo_legacy",
		"tournament": true,
		"tournament_id": str(context.get("tournament_id", "")),
		"tournament_match_id": str(context.get("tournament_match_id", ""))
	})

	return {
		"success": true,
		"dojo_id": str(winner_dojo.get("id", "")),
		"dojo_name": str(winner_dojo.get("name", "Bending Dojo")),
		"legacy_report": legacy_report.duplicate(true)
	}
func _dojo_reputation_row(dojo_id: String) -> Dictionary:
	var state: Dictionary = _ensure_state()
	var reputation: Dictionary = _safe_dictionary(state.get("dojo_reputation", {}))
	var row: Dictionary = _safe_dictionary(reputation.get(dojo_id, {}))

	if row.is_empty():
		row = {
			"dojo_id": dojo_id,
			"honor": 0,
			"renown": 0,
			"tier_label": "Unknown Dojo"
		}

	var renown: int = int(row.get("renown", 0))
	var tier_label: String = "Unknown Dojo"
	if renown >= 250:
		tier_label = "Household Bending Dojo"
	elif renown >= 100:
		tier_label = "Known Dojo"
	elif renown >= 35:
		tier_label = "Rising Dojo"

	row ["tier_label"] = tier_label
	return row.duplicate(true)


func _add_dojo_honor(actor: Person, dojo: Dictionary, amount: int, context: Dictionary = {}) -> void:
	if actor == null or dojo.is_empty():
		return

	var state: Dictionary = _ensure_state()
	var dojo_id: String = str(dojo.get("id", "")).strip_edges()
	if dojo_id == "":
		return

	var enrollments: Dictionary = _safe_dictionary(state.get("enrollments", {}))
	var actor_key: String = str(int(actor.id))
	var membership: Dictionary = _safe_dictionary(enrollments.get(actor_key, {}))
	membership ["honor"] = int(membership.get("honor", 0)) + max(0, int(amount))
	membership ["student_rank_label"] = _student_rank_label(int(membership.get("honor", 0)))
	enrollments [actor_key] = membership

	var reputation: Dictionary = _safe_dictionary(state.get("dojo_reputation", {}))
	var row: Dictionary = _safe_dictionary(reputation.get(dojo_id, {}))
	row ["dojo_id"] = dojo_id
	row ["dojo_name"] = str(dojo.get("name", "Bending Dojo"))
	row ["honor"] = int(row.get("honor", 0)) + max(0, int(amount))
	row ["renown"] = int(row.get("renown", 0)) + max(0, int(amount))
	row ["last_context"] = context.duplicate(true)
	row ["updated_year"] = int(gs.year) if gs != null else 0
	reputation [dojo_id] = row

	state ["enrollments"] = enrollments
	state ["dojo_reputation"] = reputation
	dojo_state = state.duplicate(true)


func _student_rank_label(honor: int) -> String:
	if honor >= 220:
		return "Dojo Legend"
	if honor >= 120:
		return "Senior Disciple"
	if honor >= 60:
		return "Ranked Student"
	if honor >= 20:
		return "Trusted Student"
	return "New Disciple"


func _dojo_student_rank_row(actor: Person, dojo: Dictionary) -> Dictionary:
	if actor == null:
		return {}

	var membership: Dictionary = get_actor_dojo_membership(actor)
	if membership.is_empty():
		return {}

	if str(membership.get("dojo_id", "")) != str(dojo.get("id", "")):
		return {}

	return {
		"actor_id": int(actor.id),
		"name": _person_label(actor),
		"honor": int(membership.get("honor", 0)),
		"rank_label": str(membership.get("student_rank_label", _student_rank_label(int(membership.get("honor", 0))))),
		"dojo_id": str(dojo.get("id", ""))
	}


func _dojo_student_rankings(actor: Person, dojo: Dictionary) -> Array:
	var out: Array = []
	var element: String = str(dojo.get("element", _element_for_actor(actor))).strip_edges().to_lower()

	if actor != null:
		var actor_row: Dictionary = _dojo_student_rank_row(actor, dojo)
		if not actor_row.is_empty():
			actor_row ["level"] = _bending_level(actor, element)
			out.append(actor_row)

	for raw_classmate in _classmates_for_dojo(actor, dojo):
		if typeof(raw_classmate) != TYPE_DICTIONARY:
			continue

		var classmate: Dictionary = raw_classmate
		classmate ["honor"] = int(classmate.get("level", 0)) + randi_range(0, 20)
		classmate ["rank_label"] = _student_rank_label(int(classmate.get("honor", 0)))
		out.append(classmate)

	out.sort_custom(func (a, b):
		if int(a.get("honor", 0)) != int(b.get("honor", 0)):
			return int(a.get("honor", 0)) > int(b.get("honor", 0))
		return int(a.get("level", 0)) > int(b.get("level", 0))
	)

	while out.size() > 10:
		out.pop_back()

	return out


func _person_card(person: Person, element: String = "") -> Dictionary:
	if person == null:
		return {}

	return {
		"id": int(person.id),
		"name": _person_label(person),
		"age": int(person.age),
		"level": _bending_level(person, element),
		"fame": int(person.fame),
		"respect": int(person.respect)
	}


func _find_person_by_id(person_id: int) -> Person:
	if gs == null:
		return null

	if gs.player != null and int(gs.player.id) == int(person_id):
		return gs.player

	if "npcs" in gs and typeof(gs.npcs) == TYPE_ARRAY:
		for raw_npc in gs.npcs:
			if raw_npc == null:
				continue

			var npc: Person = raw_npc
			if int(npc.id) == int(person_id):
				return npc

	return null
func get_dojo_history_payload(actor: Person, options: Dictionary = {}) -> Dictionary:
	var state: Dictionary = _ensure_state()
	var membership: Dictionary = get_actor_dojo_membership(actor)
	var requested_dojo_id: String = str(options.get("dojo_id", membership.get("dojo_id", ""))).strip_edges()
	var active_dojo: Dictionary = _dojo_by_id(requested_dojo_id)
	var history: Dictionary = {}
	var rivalries: Array = []

	if not active_dojo.is_empty():
		history = _ensure_dojo_institution_state(active_dojo)
		rivalries = _dojo_rivalry_rows(requested_dojo_id)

	return {
		"schema": "eralife.bending_dojo_history_payload",
		"version": CONTRACT_VERSION,
		"actor_id": int(actor.id) if actor != null else -1,
		"dojo_id": requested_dojo_id,
		"dojo": active_dojo.duplicate(true),
		"history": history.duplicate(true),
		"rivalries": rivalries.duplicate(true),
		"generated_at_year": int(gs.year) if gs != null else 0,
		"state_version": int(state.get("version", CONTRACT_VERSION))
	}


func record_dojo_conflict(winner: Person, loser: Person, context: Dictionary = {}) -> Dictionary:
	if winner == null or loser == null:
		return {
			"success": false,
			"reason": "missing_winner_or_loser"
		}

	var winner_membership: Dictionary = get_actor_dojo_membership(winner)
	var loser_membership: Dictionary = get_actor_dojo_membership(loser)

	if winner_membership.is_empty() or loser_membership.is_empty():
		return {
			"success": false,
			"reason": "one_or_both_benders_have_no_dojo"
		}

	var winner_dojo_id: String = str(winner_membership.get("dojo_id", "")).strip_edges()
	var loser_dojo_id: String = str(loser_membership.get("dojo_id", "")).strip_edges()

	if winner_dojo_id == "" or loser_dojo_id == "":
		return {
			"success": false,
			"reason": "missing_dojo_id"
		}

	if winner_dojo_id == loser_dojo_id:
		_append_dojo_history_event(winner_dojo_id, {
			"type": "internal_sparring_result",
			"year": int(gs.year) if gs != null else 0,
			"text": "%s defeated %s in an internal dojo match." % [
				_person_label(winner),
				_person_label(loser)
			],
			"winner_id": int(winner.id),
			"loser_id": int(loser.id),
			"context": context.duplicate(true)
		})

		return {
			"success": true,
			"internal": true,
			"dojo_id": winner_dojo_id
		}

	var state: Dictionary = _ensure_state()
	var rivalries: Dictionary = _safe_dictionary(state.get("dojo_rivalries", {}))
	var pair: Array = [winner_dojo_id, loser_dojo_id]
	pair.sort()
	var rivalry_id: String = "%s::%s" % [str(pair [0]), str(pair [1])]
	var row: Dictionary = _safe_dictionary(rivalries.get(rivalry_id, {}))

	var dojo_a_id: String = str(pair [0])
	var dojo_b_id: String = str(pair [1])
	var winner_is_a: bool = winner_dojo_id == dojo_a_id

	if row.is_empty():
		row = {
			"schema": "eralife.bending_dojo_rivalry",
			"version": CONTRACT_VERSION,
			"rivalry_id": rivalry_id,
			"dojo_a_id": dojo_a_id,
			"dojo_b_id": dojo_b_id,
			"dojo_a_name": str(_dojo_by_id(dojo_a_id).get("name", dojo_a_id)),
			"dojo_b_name": str(_dojo_by_id(dojo_b_id).get("name", dojo_b_id)),
			"dojo_a_wins": 0,
			"dojo_b_wins": 0,
			"heat": 0,
			"first_recorded_year": int(gs.year) if gs != null else 0,
			"last_recorded_year": int(gs.year) if gs != null else 0,
			"recent_results": []
		}

	if winner_is_a:
		row ["dojo_a_wins"] = int(row.get("dojo_a_wins", 0)) + 1
	else:
		row ["dojo_b_wins"] = int(row.get("dojo_b_wins", 0)) + 1

	row ["heat"] = clamp(int(row.get("heat", 0)) + (8 if bool(context.get("tournament", false)) else 3), 0, 100)
	row ["last_recorded_year"] = int(gs.year) if gs != null else 0
	row ["last_winner_dojo_id"] = winner_dojo_id
	row ["last_loser_dojo_id"] = loser_dojo_id
	row ["last_context_source"] = str(context.get("source", "dojo_conflict"))

	var recent_results: Array = _safe_array(row.get("recent_results", []))
	recent_results.append({
		"year": int(gs.year) if gs != null else 0,
		"winner_id": int(winner.id),
		"winner_name": _person_label(winner),
		"winner_dojo_id": winner_dojo_id,
		"winner_dojo_name": str(winner_membership.get("dojo_name", winner_dojo_id)),
		"loser_id": int(loser.id),
		"loser_name": _person_label(loser),
		"loser_dojo_id": loser_dojo_id,
		"loser_dojo_name": str(loser_membership.get("dojo_name", loser_dojo_id)),
		"source": str(context.get("source", "dojo_conflict")),
		"tournament": bool(context.get("tournament", false)),
		"finish_move": str(context.get("finish_move", ""))
	})

	while recent_results.size() > 20:
		recent_results.pop_front()

	row ["recent_results"] = recent_results
	rivalries [rivalry_id] = row
	state ["dojo_rivalries"] = rivalries
	dojo_state = state.duplicate(true)

	_append_dojo_history_event(winner_dojo_id, {
		"type": "rivalry_win",
		"year": int(gs.year) if gs != null else 0,
		"text": "%s brought honor to %s by defeating %s of %s." % [
			_person_label(winner),
			str(winner_membership.get("dojo_name", winner_dojo_id)),
			_person_label(loser),
			str(loser_membership.get("dojo_name", loser_dojo_id))
		],
		"rivalry_id": rivalry_id,
		"context": context.duplicate(true)
	})

	_append_dojo_history_event(loser_dojo_id, {
		"type": "rivalry_loss",
		"year": int(gs.year) if gs != null else 0,
		"text": "%s of %s fell to %s of %s." % [
			_person_label(loser),
			str(loser_membership.get("dojo_name", loser_dojo_id)),
			_person_label(winner),
			str(winner_membership.get("dojo_name", winner_dojo_id))
		],
		"rivalry_id": rivalry_id,
		"context": context.duplicate(true)
	})

	return {
		"success": true,
		"internal": false,
		"rivalry": row.duplicate(true)
	}


func _ensure_dojo_institution_state(dojo: Dictionary) -> Dictionary:
	if dojo.is_empty():
		return {}

	var state: Dictionary = _ensure_state()
	var dojo_id: String = str(dojo.get("id", "")).strip_edges()
	if dojo_id == "":
		return {}

	var history: Dictionary = _safe_dictionary(state.get("dojo_history", {}))
	var rosters: Dictionary = _safe_dictionary(state.get("dojo_rosters", {}))
	var row: Dictionary = _safe_dictionary(history.get(dojo_id, {}))
	var current_year: int = int(gs.year) if gs != null else 0

	if row.is_empty():
		var founded_year: int = _stable_dojo_founded_year(dojo)
		row = {
			"schema": "eralife.bending_dojo_history",
			"version": CONTRACT_VERSION,
			"dojo_id": dojo_id,
			"dojo_name": str(dojo.get("name", "Bending Dojo")),
			"element": str(dojo.get("element", "")),
			"tier": str(dojo.get("tier", "local")),
			"founded_year": founded_year,
			"years_active": max(0, current_year - founded_year),
			"active_sensei_id": -1,
			"active_sensei_name": "",
			"sensei_lineage": [],
			"notable_events": []
		}

	if int(row.get("active_sensei_id", -1)) <= 0 or _find_living_person_by_id(int(row.get("active_sensei_id", -1))) == null:
		row = _assign_or_rotate_dojo_sensei_row(dojo, row, "initial_assignment" if int(row.get("active_sensei_id", -1)) <= 0 else "sensei_unavailable")

	row ["years_active"] = max(0, current_year - int(row.get("founded_year", current_year)))

	var roster: Dictionary = _safe_dictionary(rosters.get(dojo_id, {}))
	var active_classmate_ids: Array = _safe_array(roster.get("active_classmate_ids", []))
	active_classmate_ids = _living_dojo_roster_ids(active_classmate_ids, dojo, row)

	if active_classmate_ids.size() < 8:
		active_classmate_ids = _select_dojo_classmate_ids(dojo, active_classmate_ids, 14, row)

	roster ["schema"] = "eralife.bending_dojo_roster"
	roster ["version"] = CONTRACT_VERSION
	roster ["dojo_id"] = dojo_id
	roster ["dojo_name"] = str(dojo.get("name", "Bending Dojo"))
	roster ["active_classmate_ids"] = active_classmate_ids
	roster ["updated_year"] = current_year

	row ["active_classmate_ids"] = active_classmate_ids.duplicate(true)
	history [dojo_id] = row
	rosters [dojo_id] = roster
	state ["dojo_history"] = history
	state ["dojo_rosters"] = rosters
	dojo_state = state.duplicate(true)

	return row.duplicate(true)


func _rotate_dojo_sensei(dojo: Dictionary, reason: String = "sensei_rotation") -> Dictionary:
	var state: Dictionary = _ensure_state()
	var dojo_id: String = str(dojo.get("id", "")).strip_edges()
	var history: Dictionary = _safe_dictionary(state.get("dojo_history", {}))
	var row: Dictionary = _safe_dictionary(history.get(dojo_id, {}))

	if row.is_empty():
		row = _ensure_dojo_institution_state(dojo)

	row = _assign_or_rotate_dojo_sensei_row(dojo, row, reason)
	history [dojo_id] = row
	state ["dojo_history"] = history
	dojo_state = state.duplicate(true)
	return row.duplicate(true)


func _assign_or_rotate_dojo_sensei_row(dojo: Dictionary, row: Dictionary, reason: String) -> Dictionary:
	var current_year: int = int(gs.year) if gs != null else 0
	var previous_sensei_id: int = int(row.get("active_sensei_id", -1))
	var lineage: Array = _safe_array(row.get("sensei_lineage", []))

	if previous_sensei_id > 0:
		for i in range(lineage.size() - 1, -1, -1):
			if typeof(lineage [i]) != TYPE_DICTIONARY:
				continue

			var lineage_row: Dictionary = lineage [i]
			if int(lineage_row.get("sensei_id", -1)) != previous_sensei_id:
				continue

			if int(lineage_row.get("end_year", -1)) < 0:
				lineage_row ["end_year"] = current_year
				lineage_row ["end_reason"] = reason
				lineage_row ["status"] = "former"
				lineage [i] = lineage_row
			break

	var new_sensei: Person = _select_sensei_for_dojo(dojo, previous_sensei_id)
	if new_sensei != null:
		row ["active_sensei_id"] = int(new_sensei.id)
		row ["active_sensei_name"] = _person_label(new_sensei)

		lineage.append({
			"sensei_id": int(new_sensei.id),
			"sensei_name": _person_label(new_sensei),
			"start_year": current_year,
			"end_year": -1,
			"status": "active",
			"reason": reason
		})

		var notable_events: Array = _safe_array(row.get("notable_events", []))
		notable_events.append({
			"type": "sensei_succession",
			"year": current_year,
			"text": "%s became the sensei of %s." % [
				_person_label(new_sensei),
				str(dojo.get("name", "the dojo"))
			],
			"sensei_id": int(new_sensei.id),
			"reason": reason
		})

		while notable_events.size() > 40:
			notable_events.pop_front()

		row ["notable_events"] = notable_events
		row ["updated_year"] = current_year
	else:
		row ["active_sensei_id"] = -1
		row ["active_sensei_name"] = ""

	row ["sensei_lineage"] = lineage
	return row


func _select_sensei_for_dojo(dojo: Dictionary, exclude_id: int = -1) -> Person:
	if gs == null or gs.bending_engine == null:
		return null

	var element: String = str(dojo.get("element", "")).strip_edges().to_lower()
	var min_level: int = int(dojo.get("teacher_min_level", 50))
	var preferred_master_level: int = _dojo_preferred_sensei_master_level(dojo)
	var best_teacher: Person = null
	var best_score: int = -999999

	if not ("npcs" in gs) or typeof(gs.npcs) != TYPE_ARRAY:
		return null

	for raw_npc in gs.npcs:
		if raw_npc == null:
			continue

		var npc: Person = raw_npc
		if not bool(npc.alive):
			continue
		if int(npc.id) == int(exclude_id):
			continue
		if int(npc.age) < 18:
			continue

		var level: int = _bending_level(npc, element)
		if level < min_level:
			continue

		var score: int = level * 6
		score += int(npc.respect)
		score += int(npc.fame)

		if level >= preferred_master_level:
			score += 1600
		elif level >= 80:
			score += 650
		else:
			score -= max(0, preferred_master_level - level) * 18

		if int(npc.age) >= 30:
			score += 60
		if int(npc.age) >= 55:
			score += 90
		if "title" in npc and str(npc.title).strip_edges() != "":
			score += 40
		if "royal_title" in npc and str(npc.royal_title).strip_edges() != "":
			score += 55

		if score > best_score:
			best_score = score
			best_teacher = npc

	return best_teacher
func _dojo_preferred_sensei_master_level(dojo: Dictionary) -> int:
	var tier: String = str(dojo.get("tier", "local")).strip_edges().to_lower()
	var min_level: int = int(dojo.get("teacher_min_level", 50))

	match tier:
		"elite":
			return max(min_level, 88)
		"legacy":
			return max(min_level, 86)
		"standard":
			return max(min_level, 82)
		_:
			return max(min_level, 76)


func _living_dojo_roster_ids(ids: Array, dojo: Dictionary, institution_row: Dictionary = {}) -> Array:
	var out: Array = []
	var level_window: Dictionary = _dojo_student_level_window(dojo, institution_row)
	var element: String = str(dojo.get("element", "")).strip_edges().to_lower()
	var min_level: int = int(level_window.get("min_level", 1))
	var max_level: int = int(level_window.get("max_level", 100))

	for raw_id in ids:
		var npc: Person = _find_living_person_by_id(int(raw_id))
		if npc == null:
			continue
		if not _dojo_accepts_age(dojo, int(npc.age)):
			continue

		var level: int = _bending_level(npc, element)
		if level < min_level or level > max_level:
			continue

		if not out.has(int(npc.id)):
			out.append(int(npc.id))

	return out


func _select_dojo_classmate_ids(dojo: Dictionary, existing_ids: Array = [], limit: int = 14, institution_row: Dictionary = {}) -> Array:
	var out: Array = existing_ids.duplicate()
	if gs == null or not ("npcs" in gs) or typeof(gs.npcs) != TYPE_ARRAY:
		return out

	var element: String = str(dojo.get("element", "")).strip_edges().to_lower()
	var level_window: Dictionary = _dojo_student_level_window(dojo, institution_row)
	var min_level: int = int(level_window.get("min_level", 1))
	var max_level: int = int(level_window.get("max_level", 100))
	var target_level: int = int(level_window.get("target_level", max_level))
	var scored_rows: Array = []

	for raw_npc in gs.npcs:
		if raw_npc == null:
			continue

		var npc: Person = raw_npc
		if not bool(npc.alive):
			continue
		if out.has(int(npc.id)):
			continue
		if not _dojo_accepts_age(dojo, int(npc.age)):
			continue

		var level: int = _bending_level(npc, element)
		if level < min_level or level > max_level:
			continue

		var distance_penalty: int = abs(level - target_level)
		var score: int = 1000 - distance_penalty
		score += int(floor(float(level) * 1.6))
		score += int(floor(float(npc.respect) * 0.35))
		score += int(floor(float(npc.ambition) * 0.18))

		scored_rows.append({
			"id": int(npc.id),
			"level": level,
			"respect": int(npc.respect),
			"age": int(npc.age),
			"score": score
		})

	scored_rows.sort_custom(func (a, b):
		if int(a.get("score", 0)) != int(b.get("score", 0)):
			return int(a.get("score", 0)) > int(b.get("score", 0))
		return int(a.get("level", 0)) > int(b.get("level", 0))
	)

	for raw_row in scored_rows:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = raw_row
		if out.has(int(row.get("id", -1))):
			continue

		out.append(int(row.get("id", -1)))
		if out.size() >= limit:
			break

	return out
func _dojo_student_level_window(dojo: Dictionary, institution_row: Dictionary = {}) -> Dictionary:
	var element: String = str(dojo.get("element", "")).strip_edges().to_lower()
	var required_level: int = max(1, int(dojo.get("required_level", 1)))
	var tier: String = str(dojo.get("tier", "local")).strip_edges().to_lower()

	var sensei_id: int = int(institution_row.get("active_sensei_id", -1))
	var sensei_level: int = 0
	var sensei: Person = _find_living_person_by_id(sensei_id)
	if sensei != null:
		sensei_level = _bending_level(sensei, element)

	var gap: int = 10
	match tier:
		"elite":
			gap = 8
		"legacy":
			gap = 10
		"standard":
			gap = 12
		_:
			gap = 14

	var min_level: int = max(1, required_level - 6)
	var max_level: int = 100

	if sensei_level > 0:
		max_level = clamp(sensei_level - gap, min_level, 99)
	else:
		max_level = clamp(required_level + 35, min_level, 99)

	var target_level: int = clamp(int(round(lerp(float(min_level), float(max_level), 0.72))), min_level, max_level)

	return {
		"element": element,
		"min_level": min_level,
		"max_level": max_level,
		"target_level": target_level,
		"sensei_level": sensei_level,
		"gap": gap
	}

func _simulate_dojo_spar_match(actor: Person, target: Person, dojo: Dictionary, element: String, options: Dictionary = {}) -> Dictionary:
	var clean_element: String = str(element).strip_edges().to_lower()
	if clean_element == "":
		clean_element = str(dojo.get("element", _element_for_actor(actor))).strip_edges().to_lower()

	var tier_id: String = str(options.get("tier_id", _dojo_sparring_tier_for_target(actor, target, dojo))).strip_edges().to_lower()
	if tier_id == "":
		tier_id = "beginner"

	var tier_config: Dictionary = _dojo_sparring_tier_config(tier_id)
	var tier_label: String = str(tier_config.get("label", "Beginner"))

	var actor_level: int = _bending_level(actor, clean_element)
	var target_level: int = _bending_level(target, clean_element)

	var actor_health_max: int = 100
	var target_health_max: int = 100
	var actor_health: int = actor_health_max
	var target_health: int = target_health_max

	var rounds: Array = []
	var coaching_notes: Array = []
	var spectator_frames: Array = []
	var finish_move: String = "Controlled Sparring Finish"

	var max_rounds: int = max(1, int(tier_config.get("rounds", 3)))
	var ai_aggression: float = float(options.get("ai_aggression", tier_config.get("ai_aggression", 1.0)))
	var move_variety: int = int(options.get("move_variety", tier_config.get("move_variety", 3)))

	var style_memory: Dictionary = _dojo_style_memory_for_pair(actor, target, dojo)
	var pair_matches: int = int(style_memory.get("pair_matches", 0))

	var actor_adaptation: Dictionary = _dojo_live_adaptation_profile(actor, clean_element, style_memory, {
		"side": "actor",
		"tier_id": tier_id,
		"ai_aggression": ai_aggression
	})
	var target_adaptation: Dictionary = _dojo_live_adaptation_profile(target, clean_element, style_memory, {
		"side": "target",
		"tier_id": tier_id,
		"ai_aggression": ai_aggression
	})

	spectator_frames.append(_dojo_live_spar_frame(actor, target, dojo, tier_label, clean_element, actor_health, actor_health_max, target_health, target_health_max, {
		"text": "%s and %s step onto the floor at %s.\n\nThe room quiets down. Everyone can feel this is not just another drill." % [
			_person_label(actor),
			_person_label(target),
			str(dojo.get("name", "the dojo"))
		],
		"status_text": "%s • opening stances" % tier_label,
		"opps": [
			{
				"label": "%s settles into stance" % _person_label(actor),
				"disabled": true,
				"button_theme": "bending_ability",
				"ability_element": clean_element,
				"power_source": "bending"
			},
			{
				"label": "%s starts reading the rhythm" % _person_label(target),
				"disabled": true,
				"button_theme": "defensive_escape",
				"ability_element": clean_element,
				"power_source": "bending"
			}
		]
	}))

	var last_actor_move: String = str(style_memory.get("last_actor_move", ""))
	var last_target_move: String = str(style_memory.get("last_target_move", ""))

	for round_index in range(1, max_rounds + 1):
		var actor_move: String = _dojo_adaptive_spar_move(clean_element, round_index, true, {
			"move_variety": move_variety,
			"tier_id": tier_id,
			"style_memory": style_memory.duplicate(true),
			"last_self_move": last_actor_move,
			"last_enemy_move": last_target_move,
			"adaptation": actor_adaptation.duplicate(true)
		})

		var target_move: String = _dojo_adaptive_spar_move(clean_element, round_index, false, {
			"move_variety": move_variety,
			"tier_id": tier_id,
			"style_memory": style_memory.duplicate(true),
			"last_self_move": last_target_move,
			"last_enemy_move": last_actor_move,
			"adaptation": target_adaptation.duplicate(true)
		})

		var actor_adaptation_bonus: int = int(actor_adaptation.get("current_bonus", 0))
		var target_adaptation_bonus: int = int(target_adaptation.get("current_bonus", 0))

		var actor_roll: int = actor_level + randi_range(6, 24) + int(floor(float(actor.ambition) / 20.0)) + actor_adaptation_bonus
		var target_roll: int = target_level + randi_range(6, 24) + int(floor(float(target.ambition) / 20.0)) + target_adaptation_bonus

		target_roll += int(round(float(round_index) * ai_aggression))
		if tier_id == "master":
			target_roll += 5
		elif tier_id == "advanced":
			target_roll += 3
		elif tier_id == "intermediate":
			target_roll += 1

		var round_text: String = ""
		var exchange_winner_side: String = ""

		if actor_roll >= target_roll:
			var damage_to_target: int = _dojo_adaptive_exchange_damage(actor_roll, target_roll, actor_level, int(target_adaptation.get("defensive_read", 0)))
			target_health = int(clamp(target_health - damage_to_target, 0, target_health_max))
			round_text = "%s adapted into %s and clipped %s for %d control damage." % [
				_person_label(actor),
				actor_move,
				_person_label(target),
				damage_to_target
			]
			finish_move = actor_move
			exchange_winner_side = "actor"
			target_adaptation ["current_bonus"] = _dojo_live_adaptation_gain(target_adaptation, true)
			actor_adaptation ["current_bonus"] = _dojo_live_adaptation_gain(actor_adaptation, false)
		else:
			var damage_to_actor: int = _dojo_adaptive_exchange_damage(target_roll, actor_roll, target_level, int(actor_adaptation.get("defensive_read", 0)))
			actor_health = int(clamp(actor_health - damage_to_actor, 0, actor_health_max))
			round_text = "%s adjusted with %s and forced %s backward for %d control damage." % [
				_person_label(target),
				target_move,
				_person_label(actor),
				damage_to_actor
			]
			finish_move = target_move
			exchange_winner_side = "target"
			actor_adaptation ["current_bonus"] = _dojo_live_adaptation_gain(actor_adaptation, true)
			target_adaptation ["current_bonus"] = _dojo_live_adaptation_gain(target_adaptation, false)

		var sensei_tip: String = ""
		if bool(options.get("sensei_teaching_enabled", true)):
			sensei_tip = _dojo_sensei_tip(clean_element, tier_id, round_index, actor_move, target_move, actor_health, target_health)
			if sensei_tip != "":
				coaching_notes.append({
					"round": round_index,
					"text": sensei_tip
				})

		var adaptation_note: String = _dojo_live_adaptation_note(actor, target, actor_adaptation, target_adaptation, exchange_winner_side)
		if adaptation_note != "":
			round_text += "\n\n%s" % adaptation_note

		var round_row: Dictionary = {
			"round": round_index,
			"actor_health": actor_health,
			"target_health": target_health,
			"actor_move": actor_move,
			"target_move": target_move,
			"actor_roll": actor_roll,
			"target_roll": target_roll,
			"actor_adaptation_bonus": int(actor_adaptation.get("current_bonus", 0)),
			"target_adaptation_bonus": int(target_adaptation.get("current_bonus", 0)),
			"exchange_winner_side": exchange_winner_side,
			"sensei_tip": sensei_tip,
			"text": round_text
		}
		rounds.append(round_row)

		spectator_frames.append(_dojo_live_spar_frame(actor, target, dojo, tier_label, clean_element, actor_health, actor_health_max, target_health, target_health_max, {
			"text": "Exchange %d\n\n%s" % [round_index, round_text],
			"status_text": "%s • exchange %d • adaptation active" % [tier_label, round_index],
			"impact_shake": true,
			"impact_shake_amount": clamp(float(abs(actor_roll - target_roll)) * 0.12, 3.0, 18.0),
			"opps": [
				{
					"label": "%s: %s" % [_person_label(actor), actor_move],
					"disabled": true,
					"button_theme": "bending_ability",
					"ability_element": clean_element,
					"power_source": "bending",
					"spectator_chosen": exchange_winner_side == "actor"
				},
				{
					"label": "%s: %s" % [_person_label(target), target_move],
					"disabled": true,
					"button_theme": "defensive_escape",
					"ability_element": clean_element,
					"power_source": "bending",
					"spectator_chosen": exchange_winner_side == "target"
				}
			]
		}))

		last_actor_move = actor_move
		last_target_move = target_move

		if actor_health <= 0 or target_health <= 0:
			break

	var actor_won: bool = actor_health >= target_health
	var winner: Person = actor if actor_won else target
	var loser: Person = target if actor_won else actor

	if actor_won:
		target_health = 0 if target_health <= actor_health else target_health
		actor_health = max(1, actor_health)
	else:
		actor_health = 0 if actor_health <= target_health else actor_health
		target_health = max(1, target_health)

	spectator_frames.append(_dojo_live_spar_frame(actor, target, dojo, tier_label, clean_element, actor_health, actor_health_max, target_health, target_health_max, {
		"text": "%s wins the live spar with %s.\n\n%s lowers their guard while the dojo reacts to what they just saw." % [
			_person_label(winner),
			finish_move,
			_person_label(loser)
		],
		"status_text": "%s • winner declared" % tier_label,
		"opps": [
			{
				"label": "Winner: %s" % _person_label(winner),
				"disabled": true,
				"button_theme": "bending_ability",
				"ability_element": clean_element,
				"power_source": "bending",
			},
			{
				"label": "Finish: %s" % finish_move,
				"disabled": true,
				"button_theme": "artifact_action",
				"power_source": "knowledge"
			}
		]
	}))

	var match_payload: Dictionary = {
		"schema": "eralife.bending_dojo_mock_match",
		"version": CONTRACT_VERSION + 1,
		"dojo_id": str(dojo.get("id", "")),
		"dojo_name": str(dojo.get("name", "Bending Dojo")),
		"element": clean_element,
		"sparring_tier": tier_id,
		"sparring_tier_label": tier_label,
		"ai_aggression": ai_aggression,
		"move_variety": move_variety,
		"style_adaptation": {
			"enabled": bool(options.get("style_adaptation_enabled", true)),
			"pair_matches_before": pair_matches,
			"actor_profile": actor_adaptation.duplicate(true),
			"target_profile": target_adaptation.duplicate(true)
		},
		"actor_id": int(actor.id),
		"actor_name": _person_label(actor),
		"actor_level": actor_level,
		"actor_final_health": actor_health,
		"target_id": int(target.id),
		"target_name": _person_label(target),
		"target_level": target_level,
		"target_final_health": target_health,
		"winner_id": int(winner.id),
		"winner_name": _person_label(winner),
		"loser_id": int(loser.id),
		"loser_name": _person_label(loser),
		"finish_move": finish_move,
		"coaching_notes": coaching_notes,
		"rounds": rounds,
		"spectator_frames": spectator_frames,
		"year": int(gs.year) if gs != null else 0
	}

	if bool(options.get("style_adaptation_enabled", true)):
		_update_dojo_style_memory_from_match(actor, target, dojo, match_payload, {
			"source": str(options.get("source", "dojo_spar_simulation")),
			"tier_id": tier_id
		})

	_apply_dojo_legacy_from_match(dojo, winner, loser, match_payload, {
		"source": str(options.get("source", "dojo_spar_simulation")),
		"tier_id": tier_id,
		"spectated": bool(options.get("spectated", false))
	})

	return match_payload
func _dojo_live_adaptation_profile(actor: Person, element: String, style_memory: Dictionary, context: Dictionary = {}) -> Dictionary:
	var level: int = _bending_level(actor, element)
	var smarts_score: int = int(actor.smarts) if actor != null else 0
	var mental_score: int = int(actor.mental_health) if actor != null else 0
	var ambition_score: int = int(actor.ambition) if actor != null else 0
	var pair_matches: int = int(style_memory.get("pair_matches", 0))

	var speed: float = 0.35
	speed += float(level) / 165.0
	speed += float(smarts_score) / 260.0
	speed += float(mental_score) / 420.0
	speed += float(ambition_score) / 500.0
	speed += clamp(float(pair_matches) * 0.035, 0.0, 0.22)

	var tier_id: String = str(context.get("tier_id", "beginner")).strip_edges().to_lower()
	if tier_id == "master":
		speed += 0.16
	elif tier_id == "advanced":
		speed += 0.1
	elif tier_id == "intermediate":
		speed += 0.05

	speed = clamp(speed, 0.25, 1.35)

	var ceiling: int = clamp(4 + int(round(float(level) / 8.0)) + int(round(speed * 5.0)), 4, 24)
	var defensive_read: int = clamp(int(round(float(level) * 0.32 + float(smarts_score) * 0.18 + float(pair_matches) * 1.5)), 0, 42)

	return {
		"schema": "eralife.dojo_live_adaptation_profile",
		"version": CONTRACT_VERSION,
		"actor_id": int(actor.id) if actor != null else -1,
		"actor_name": _person_label(actor),
		"element": element,
		"level": level,
		"speed": speed,
		"ceiling": ceiling,
		"current_bonus": int(clamp(pair_matches * 2, 0, 12)),
		"defensive_read": defensive_read,
		"pair_matches": pair_matches,
		"side": str(context.get("side", ""))
	}


func _dojo_live_adaptation_gain(profile: Dictionary, under_pressure: bool) -> int:
	var current_bonus: int = int(profile.get("current_bonus", 0))
	var ceiling: int = max(0, int(profile.get("ceiling", 10)))
	var speed: float = float(profile.get("speed", 0.5))

	var gain_multiplier: float = 1.4
	if under_pressure:
		gain_multiplier = 3.0

	var gain: int = max(1, int(round(speed * gain_multiplier)))
	if under_pressure:
		gain += 1

	return int(clamp(current_bonus + gain, 0, ceiling))


func _dojo_adaptive_exchange_damage(winner_roll: int, loser_roll: int, winner_level: int, defender_read: int) -> int:
	var margin: int = max(0, winner_roll - loser_roll)
	var raw_damage: int = margin + randi_range(8, 18) + int(round(float(winner_level) * 0.05))
	raw_damage -= int(round(float(defender_read) * 0.08))
	return int(clamp(raw_damage, 5, 38))
func _dojo_adaptive_spar_move(element: String, exchange_index: int, actor_side: bool, context: Dictionary = {}) -> String:
	var adaptation: Dictionary = _safe_dictionary(context.get("adaptation", {}))
	var bonus: int = int(adaptation.get("current_bonus", 0))
	var last_enemy_move: String = str(context.get("last_enemy_move", "")).strip_edges().to_lower()

	if bonus >= 18:
		match str(element).strip_edges().to_lower():
			"air":
				return "adaptive void-step counter"
			"water":
				return "mirror-current reversal"
			"earth":
				return "seismic answer trap"
			"fire":
				return "tempo-breaking flame feint"
			_:
				return "adaptive counter-form"

	if bonus >= 10 and last_enemy_move != "":
		match str(element).strip_edges().to_lower():
			"air":
				return "angle change against %s" % last_enemy_move
			"water":
				return "redirecting flow against %s" % last_enemy_move
			"earth":
				return "rooted counter against %s" % last_enemy_move
			"fire":
				return "pressure switch against %s" % last_enemy_move
			_:
				return "counter against %s" % last_enemy_move

	return _dojo_spar_move(element, exchange_index, actor_side, context)
func _dojo_live_adaptation_note(actor: Person, target: Person, actor_profile: Dictionary, target_profile: Dictionary, exchange_winner_side: String) -> String:
	var actor_bonus: int = int(actor_profile.get("current_bonus", 0))
	var target_bonus: int = int(target_profile.get("current_bonus", 0))

	if exchange_winner_side == "actor" and target_bonus >= 12:
		return "%s is starting to adapt. Their stance changes before the next exchange even begins." % _person_label(target)
	if exchange_winner_side == "target" and actor_bonus >= 12:
		return "%s is reading the pattern now. The next exchange will not look like the last one." % _person_label(actor)
	if actor_bonus >= 18 and target_bonus >= 18:
		return "Both benders are adapting in real time. The spar has turned into a high-level chess match."
	return ""
func _dojo_live_spar_frame(actor: Person, target: Person, _dojo: Dictionary, tier_label: String, element: String, actor_health: int, actor_health_max: int, target_health: int, target_health_max: int, context: Dictionary = {}) -> Dictionary:
	return {
		"panel_title": "DOJO LIVE SPAR — SPECTATING",
		"text": str(context.get("text", "")),
		"footer_text": str(context.get("footer_text", "Spectating live. No input needed.")),
		"combat_ui": {
			"visible": true,
			"theme": "bending_element_%s" % str(element).strip_edges().to_lower(),
			"status_text": str(context.get("status_text", tier_label)),
			"player_label": "%s • %s" % [_person_label(actor), str(element).capitalize()],
			"player_value": actor_health,
			"player_max": max(1, actor_health_max),
			"enemy_label": "%s • %s" % [_person_label(target), str(element).capitalize()],
			"enemy_value": target_health,
			"enemy_max": max(1, target_health_max),
			"impact_shake": bool(context.get("impact_shake", false)),
			"impact_shake_amount": float(context.get("impact_shake_amount", 0.0))
		},
		"opps": _safe_array(context.get("opps", []))
	}
func _dojo_spar_move(element: String, exchange_index: int, actor_side: bool, options: Dictionary = {}) -> String:
	var clean_element: String = str(element).strip_edges().to_lower()
	var move_variety: int = int(clamp(int(options.get("move_variety", 3)), 3, 8))
	var tier_id: String = str(options.get("tier_id", "beginner")).strip_edges().to_lower()
	var moves: Array = []

	match clean_element:
		"air":
			moves = ["Cyclone Step", "Vacuum Feint", "Spiral Palm", "Gale Slip", "Wind Wheel", "Pressure Redirect", "Breathless Angle", "Skyhook Redirect"]
		"water":
			moves = ["Moon-Tide Sweep", "Ice Thread", "Ripple Counter", "Mist Guard", "Wave Hook", "Frost Lock", "Undertow Step", "Pressure Current"]
		"earth":
			moves = ["Stone Gate Crash", "Rooted Counter", "Boulder Line", "Iron Stance", "Dust Step", "Seismic Guard", "Faultline Feint", "Granite Check"]
		"fire":
			moves = ["Sunfire Jab", "Dragon Burst", "Ember Rush", "Heat Veil", "Flame Wheel", "Ash Counter", "Lightning Threat", "Pressure Spark"]
		_:
			moves = ["Controlled Form", "Discipline Counter", "Balance Check", "Timing Drill", "Footwork Reset"]

	if tier_id == "master":
		move_variety = min(move_variety + 2, moves.size())
	elif tier_id == "advanced":
		move_variety = min(move_variety + 1, moves.size())

	var usable_count: int = clamp(move_variety, 1, moves.size())
	var offset: int = 0 if actor_side else 1
	var index: int = abs(exchange_index + offset + randi_range(0, usable_count - 1)) % usable_count
	return str(moves [index])
func get_dojo_sparring_tiers(actor: Person, dojo: Dictionary, _options: Dictionary = {}) -> Array:
	var out: Array = []
	for tier_id in ["beginner", "intermediate", "advanced", "master"]:
		var config: Dictionary = _dojo_sparring_tier_config(tier_id)
		var target: Person = _dojo_target_for_sparring_tier(actor, dojo, tier_id)
		var target_card: Dictionary = _person_card(target, str(dojo.get("element", _element_for_actor(actor))))
		config ["available"] = target != null
		config ["target"] = target_card.duplicate(true)
		config ["disabled_reason"] = "" if target != null else "No valid sparring partner is available for this tier yet."
		out.append(config)
	return out


func _dojo_sparring_tier_config(tier_id: String) -> Dictionary:
	var clean_tier: String = str(tier_id).strip_edges().to_lower()
	match clean_tier:
		"intermediate":
			return {
				"id": "intermediate",
				"label": "Intermediate",
				"role_label": "Top Student",
				"description": "A sharper classmate who punishes repeated habits.",
				"skill_multiplier": 1.25,
				"honor_multiplier": 1.25,
				"progress_multiplier": 1.2,
				"ai_aggression": 1.18,
				"move_variety": 4,
				"rounds": 4
			}
		"advanced":
			return {
				"id": "advanced",
				"label": "Advanced",
				"role_label": "Assistant",
				"description": "A near-sensei spar designed to expose bad timing.",
				"skill_multiplier": 1.65,
				"honor_multiplier": 1.65,
				"progress_multiplier": 1.45,
				"ai_aggression": 1.38,
				"move_variety": 6,
				"rounds": 5
			}
		"master":
			return {
				"id": "master",
				"label": "Master",
				"role_label": "Sensei",
				"description": "The sensei reads your style, teaches mid-fight, and tests your ceiling.",
				"skill_multiplier": 2.15,
				"honor_multiplier": 2.25,
				"progress_multiplier": 1.85,
				"ai_aggression": 1.7,
				"move_variety": 8,
				"rounds": 5
			}
		_:
			return {
				"id": "beginner",
				"label": "Beginner",
				"role_label": "Classmate",
				"description": "A controlled floor match against a regular classmate.",
				"skill_multiplier": 1.0,
				"honor_multiplier": 1.0,
				"progress_multiplier": 1.0,
				"ai_aggression": 1.0,
				"move_variety": 3,
				"rounds": 3
			}


func _dojo_target_for_sparring_tier(actor: Person, dojo: Dictionary, tier_id: String) -> Person:
	if actor == null:
		return null

	var clean_tier: String = str(tier_id).strip_edges().to_lower()
	var element: String = str(dojo.get("element", _element_for_actor(actor))).strip_edges().to_lower()
	var classmates: Array = _classmates_for_dojo(actor, dojo)
	var scored: Array = []

	for raw_classmate in classmates:
		if typeof(raw_classmate) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = raw_classmate
		var npc: Person = _find_living_person_by_id(int(row.get("id", -1)))
		if npc == null:
			continue

		scored.append({
			"id": int(npc.id),
			"level": _bending_level(npc, element),
			"person": npc
		})

	scored.sort_custom(func (a, b):
		return int(a.get("level", 0)) > int(b.get("level", 0))
	)

	if clean_tier == "master":
		return _teacher_for_dojo(actor, dojo)

	if scored.is_empty():
		if clean_tier in ["advanced", "intermediate"]:
			return _teacher_for_dojo(actor, dojo)
		return null

	if clean_tier == "advanced":
		return scored [0].get("person", null)

	if clean_tier == "intermediate":
		var mid_index: int = int(clamp(int(floor(float(scored.size()) * 0.35)), 0, scored.size() - 1))
		return scored [mid_index].get("person", null)

	return scored [scored.size() - 1].get("person", null)


func _dojo_sparring_tier_for_target(actor: Person, target: Person, dojo: Dictionary) -> String:
	if actor == null or target == null:
		return "beginner"

	var teacher: Person = _teacher_for_dojo(actor, dojo)
	if teacher != null and int(teacher.id) == int(target.id):
		return "master"

	var element: String = str(dojo.get("element", _element_for_actor(actor))).strip_edges().to_lower()
	var actor_level: int = _bending_level(actor, element)
	var target_level: int = _bending_level(target, element)
	var gap: int = target_level - actor_level

	if gap >= 25:
		return "advanced"
	if gap >= 10:
		return "intermediate"
	return "beginner"


func _dojo_sensei_tip(element: String, tier_id: String, round_index: int, actor_move: String, target_move: String, actor_health: int, target_health: int) -> String:
	var clean_element: String = str(element).strip_edges().to_lower()
	var clean_tier: String = str(tier_id).strip_edges().to_lower()

	if clean_tier == "beginner" and round_index <= 1:
		return "Sensei: \"Breathe first. Power follows balance.\""

	if actor_health < target_health:
		match clean_element:
			"air":
				return "Sensei: \"Stop meeting force head-on. Vanish from the line, then answer.\""
			"water":
				return "Sensei: \"Do not freeze under pressure. Redirect it.\""
			"earth":
				return "Sensei: \"Root before you strike. Your stance is leaking power.\""
			"fire":
				return "Sensei: \"Your flame is loud. Make it precise.\""
			_:
				return "Sensei: \"Read the rhythm. The next exchange is already speaking.\""

	if clean_tier in ["advanced", "master"]:
		return "Sensei: \"They have seen %s now. Change the rhythm before they adapt to it.\"" % actor_move

	return "Sensei: \"Good. Now watch the counter: %s.\"" % target_move


func _dojo_style_memory_key(actor: Person, target: Person, dojo: Dictionary) -> String:
	if actor == null or target == null:
		return ""

	var low_id: int = min(int(actor.id), int(target.id))
	var high_id: int = max(int(actor.id), int(target.id))
	return "%s:%d:%d" % [
		str(dojo.get("id", "dojo")),
		low_id,
		high_id
	]


func _dojo_style_memory_for_pair(actor: Person, target: Person, dojo: Dictionary) -> Dictionary:
	var key: String = _dojo_style_memory_key(actor, target, dojo)
	if key == "":
		return {}

	var state: Dictionary = _ensure_state()
	var memory: Dictionary = _safe_dictionary(state.get("sparring_style_memory", {}))
	return _safe_dictionary(memory.get(key, {}))


func _update_dojo_style_memory_from_match(actor: Person, target: Person, dojo: Dictionary, match_payload: Dictionary, context: Dictionary = {}) -> void:
	var key: String = _dojo_style_memory_key(actor, target, dojo)
	if key == "":
		return

	var state: Dictionary = _ensure_state()
	var memory: Dictionary = _safe_dictionary(state.get("sparring_style_memory", {}))
	var row: Dictionary = _safe_dictionary(memory.get(key, {}))
	var rounds: Array = _safe_array(match_payload.get("rounds", []))

	row ["schema"] = "eralife.bending_dojo_style_memory"
	row ["version"] = CONTRACT_VERSION
	row ["key"] = key
	row ["dojo_id"] = str(dojo.get("id", ""))
	row ["pair_matches"] = int(row.get("pair_matches", 0)) + 1
	row ["last_winner_id"] = int(match_payload.get("winner_id", -1))
	row ["last_finish_move"] = str(match_payload.get("finish_move", "Controlled Sparring Finish"))
	row ["last_context"] = context.duplicate(true)
	row ["updated_year"] = int(gs.year) if gs != null else 0

	if not rounds.is_empty():
		var first_round: Dictionary = _safe_dictionary(rounds [0])
		var last_round: Dictionary = _safe_dictionary(rounds [rounds.size() - 1])
		row ["last_actor_opener"] = str(first_round.get("actor_move", ""))
		row ["last_target_opener"] = str(first_round.get("target_move", ""))
		row ["last_actor_move"] = str(last_round.get("actor_move", ""))
		row ["last_target_move"] = str(last_round.get("target_move", ""))

	memory [key] = row.duplicate(true)
	state ["sparring_style_memory"] = memory
	dojo_state = state.duplicate(true)

func _dojo_current_era_name() -> String:
	if gs == null:
		return ""

	var era_value: Variant = null
	if "era" in gs:
		era_value = gs.get("era")

	if typeof(era_value) == TYPE_DICTIONARY:
		var era_dict: Dictionary = era_value
		return str(era_dict.get("name", era_dict.get("era_name", era_dict.get("id", ""))))

	if typeof(era_value) == TYPE_OBJECT:
		if "name" in era_value:
			return str(era_value.get("name"))

	if typeof(era_value) == TYPE_STRING:
		return str(era_value)

	if gs.has_method("_era_from_year") and "year" in gs:
		var resolved_era: Variant = gs.call("_era_from_year", int(gs.get("year")))
		if typeof(resolved_era) == TYPE_DICTIONARY:
			var resolved_dict: Dictionary = resolved_era
			return str(resolved_dict.get("name", resolved_dict.get("era_name", resolved_dict.get("id", ""))))

	return ""


func _dojo_film_study_available() -> bool:
	var clean_era: String = _dojo_current_era_name().strip_edges().to_lower()
	return clean_era in [
		"industrial",
		"industrial era",
		"modern",
		"modern era",
		"future",
		"future era"
	]


func _dojo_film_study_locked_reason() -> String:
	if _dojo_film_study_available():
		return ""

	var era_name: String = _dojo_current_era_name().strip_edges()
	if era_name == "":
		era_name = "this era"

	return "Film study requires Industrial, Modern, or Future era technology. In %s, sparring lessons are preserved through memory, oral teaching, and sensei observation." % era_name
func _dojo_film_study_row(actor: Person, dojo_id: String) -> Dictionary:
	if actor == null:
		return {}

	var state: Dictionary = _ensure_state()
	var rows: Array = _safe_array(state.get("sparring_film_study", []))
	for i in range(rows.size() - 1, -1, -1):
		if typeof(rows [i]) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = rows [i]
		if int(row.get("actor_id", -1)) != int(actor.id):
			continue
		if str(row.get("dojo_id", "")) != str(dojo_id):
			continue

		return row.duplicate(true)

	return {}


func _append_dojo_film_study_from_match(actor: Person, dojo: Dictionary, match_payload: Dictionary, context: Dictionary = {}) -> Dictionary:
	if actor == null or dojo.is_empty() or match_payload.is_empty():
		return {}

	if not _dojo_film_study_available():
		return {}

	var state: Dictionary = _ensure_state()
	var rows: Array = _safe_array(state.get("sparring_film_study", []))
	var row: Dictionary = {
		"schema": "eralife.bending_dojo_film_study_row",
		"version": CONTRACT_VERSION,
		"actor_id": int(actor.id),
		"actor_name": _person_label(actor),
		"dojo_id": str(dojo.get("id", "")),
		"dojo_name": str(dojo.get("name", "Bending Dojo")),
		"element": str(match_payload.get("element", dojo.get("element", ""))),
		"sparring_tier": str(match_payload.get("sparring_tier", context.get("tier_id", "beginner"))),
		"sparring_tier_label": str(match_payload.get("sparring_tier_label", "Beginner")),
		"winner_name": str(match_payload.get("winner_name", "Unknown")),
		"finish_move": str(match_payload.get("finish_move", "Controlled Sparring Finish")),
		"round_count": _safe_array(match_payload.get("rounds", [])).size(),
		"studied": false,
		"context": context.duplicate(true),
		"era_name": _dojo_current_era_name(),
		"year": int(gs.year) if gs != null else 0,
		"created_at_ms": int(Time.get_ticks_msec())
	}

	rows.append(row.duplicate(true))
	while rows.size() > 80:
		rows.pop_front()

	state ["sparring_film_study"] = rows
	dojo_state = state.duplicate(true)

	return row.duplicate(true)


func study_dojo_sparring_film(actor: Person, dojo_id: String = "", options: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"popup_title": "Film Study",
			"popup_text": "No bender was selected.",
			"popup_footer": "Tap anywhere to continue."
		}

	if not _dojo_film_study_available():
		return {
			"success": false,
			"popup_title": "Film Study Locked",
			"popup_text": _dojo_film_study_locked_reason(),
			"popup_footer": "Tap anywhere to continue.",
			"film_study_available": false,
			"era_name": _dojo_current_era_name()
		}

	var membership: Dictionary = get_actor_dojo_membership(actor)
	var clean_dojo_id: String = str(dojo_id).strip_edges()
	if clean_dojo_id == "":
		clean_dojo_id = str(membership.get("dojo_id", ""))

	var dojo: Dictionary = _dojo_by_id(clean_dojo_id)
	if dojo.is_empty():
		return {
			"success": false,
			"popup_title": "Film Study",
			"popup_text": "No dojo film room is available.",
			"popup_footer": "Tap anywhere to continue."
		}

	var row: Dictionary = _dojo_film_study_row(actor, clean_dojo_id)
	if row.is_empty():
		return {
			"success": false,
			"popup_title": "No Film Yet",
			"popup_text": "There is no sparring film to study yet.\n\nSpectate an NPC spar or complete a dojo spar first.",
			"popup_footer": "Tap anywhere to continue."
		}

	var element: String = str(row.get("element", dojo.get("element", _element_for_actor(actor)))).strip_edges().to_lower()
	var tier_id: String = str(row.get("sparring_tier", "beginner")).strip_edges().to_lower()
	var config: Dictionary = _dojo_sparring_tier_config(tier_id)
	var progress_gain: int = int(clamp(round(1.0 * float(config.get("progress_multiplier", 1.0))), 1, 4))
	var skill_points: int = 1 if tier_id in ["advanced", "master"] else 0

	if gs != null and gs.bending_engine != null and gs.bending_engine.has_method("gain_bending_progress"):
		gs.bending_engine.gain_bending_progress(actor, element, progress_gain, "dojo film study at %s" % str(dojo.get("name", "the dojo")))

	if skill_points > 0 and gs != null and gs.bending_engine != null and gs.bending_engine.has_method("award_bending_skill_points"):
		gs.bending_engine.award_bending_skill_points(actor, skill_points, "dojo_film_study")

	_add_dojo_honor(actor, dojo, 1, {
		"source": "dojo_film_study",
		"film_row": row.duplicate(true)
	})

	var state: Dictionary = _ensure_state()
	var rows: Array = _safe_array(state.get("sparring_film_study", []))
	for i in range(rows.size()):
		if typeof(rows [i]) != TYPE_DICTIONARY:
			continue
		if int(rows [i].get("created_at_ms", -1)) == int(row.get("created_at_ms", -2)):
			rows [i] ["studied"] = true
			rows [i] ["studied_year"] = int(gs.year) if gs != null else 0
			break

	state ["sparring_film_study"] = rows
	dojo_state = state.duplicate(true)

	return {
		"success": true,
		"popup_title": "Film Study Complete",
		"popup_text": "You studied the %s spar where %s finished the exchange with %s.\n\nTraining progress: +%d\nSkill Points: +%d\nHonor: +1" % [
			str(row.get("sparring_tier_label", "dojo")),
			str(row.get("winner_name", "Unknown")),
			str(row.get("finish_move", "Controlled Sparring Finish")),
			progress_gain,
			skill_points
		],
		"popup_footer": "Tap anywhere to continue.",
		"progress_gain": progress_gain,
		"skill_points_awarded": skill_points,
		"film_row": row.duplicate(true),
		"options": options.duplicate(true)
	}

func spectate_dojo_spar(actor: Person, dojo_id: String = "", options: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"popup_title": "Dojo Spectating",
			"popup_text": "No bender was selected.",
			"popup_footer": "Tap anywhere to continue."
		}

	var membership: Dictionary = get_actor_dojo_membership(actor)
	if membership.is_empty():
		return {
			"success": false,
			"popup_title": "Dojo Spectating Locked",
			"popup_text": "You need to be accepted into a dojo before watching live floor spars.",
			"popup_footer": "Tap anywhere to continue."
		}

	var clean_dojo_id: String = str(dojo_id).strip_edges()
	if clean_dojo_id == "":
		clean_dojo_id = str(membership.get("dojo_id", ""))

	var dojo: Dictionary = _dojo_by_id(clean_dojo_id)
	if dojo.is_empty():
		return {
			"success": false,
			"popup_title": "Dojo Missing",
			"popup_text": "That dojo could not be found.",
			"popup_footer": "Tap anywhere to continue."
		}

	_ensure_dojo_institution_state(dojo)

	var pair: Array = _dojo_npc_spar_pair(actor, dojo, options)
	if pair.size() < 2:
		return {
			"success": false,
			"popup_title": "No Live Spar Available",
			"popup_text": "No NPC sparring pair is available on the dojo floor right now.",
			"popup_footer": "Tap anywhere to continue."
		}

	var fighter_a: Person = pair [0]
	var fighter_b: Person = pair [1]
	var element: String = str(dojo.get("element", _element_for_actor(actor))).strip_edges().to_lower()
	var tier_id: String = str(options.get("tier_id", _dojo_sparring_tier_for_target(fighter_a, fighter_b, dojo))).strip_edges().to_lower()

	var sim_options: Dictionary = options.duplicate(true)
	sim_options ["source"] = str(options.get("source", "dojo_spectate_npc_spar"))
	sim_options ["tier_id"] = tier_id
	sim_options ["interactive"] = false
	sim_options ["spectated"] = true
	sim_options ["sensei_teaching_enabled"] = true
	sim_options ["style_adaptation_enabled"] = true
	sim_options ["film_study_enabled"] = true
	sim_options ["live_spectator_frames_enabled"] = true

	var match_payload: Dictionary = _simulate_dojo_spar_match(fighter_a, fighter_b, dojo, element, sim_options)

	var fighter_a_won: bool = int(match_payload.get("winner_id", -1)) == int(fighter_a.id)
	var winner: Person = fighter_a if fighter_a_won else fighter_b
	var loser: Person = fighter_b if fighter_a_won else fighter_a

	var tier_config: Dictionary = _dojo_sparring_tier_config(tier_id)
	var film_row: Dictionary = {}
	if _dojo_film_study_available():
		film_row = _append_dojo_film_study_from_match(actor, dojo, match_payload, {
			"source": "dojo_spectate_npc_spar",
			"tier_id": tier_id
		})

	_record_dojo_sparring_result(fighter_a, fighter_b, dojo, element, fighter_a_won, 0, {
		"source": "dojo_spectate_npc_spar",
		"finish_move": str(match_payload.get("finish_move", "Controlled Sparring Finish")),
		"tier_id": tier_id,
		"honor_gain": 0,
		"progress_gain": 0,
		"match_payload": match_payload.duplicate(true)
	})

	_record_dojo_sparring_result(fighter_b, fighter_a, dojo, element, not fighter_a_won, 0, {
		"source": "dojo_spectate_npc_spar",
		"finish_move": str(match_payload.get("finish_move", "Controlled Sparring Finish")),
		"tier_id": tier_id,
		"honor_gain": 0,
		"progress_gain": 0,
		"match_payload": match_payload.duplicate(true)
	})

	var state: Dictionary = _ensure_state()
	var reports: Array = _safe_array(state.get("dojo_live_spar_reports", []))
	var report: Dictionary = {
		"schema": "eralife.bending_dojo_live_spar_report",
		"version": CONTRACT_VERSION + 1,
		"success": true,
		"spectated": true,
		"dojo_id": str(dojo.get("id", "")),
		"dojo_name": str(dojo.get("name", "Bending Dojo")),
		"sparring_tier": tier_id,
		"sparring_tier_label": str(tier_config.get("label", "Beginner")),
		"fighter_a_id": int(fighter_a.id),
		"fighter_b_id": int(fighter_b.id),
		"winner_id": int(winner.id),
		"loser_id": int(loser.id),
		"finish_move": str(match_payload.get("finish_move", "Controlled Sparring Finish")),
		"film_row": film_row.duplicate(true),
		"match_payload": match_payload.duplicate(true),
		"year": int(gs.year) if gs != null else 0
	}

	reports.append(report.duplicate(true))
	while reports.size() > 60:
		reports.pop_front()

	state ["dojo_live_spar_reports"] = reports
	state ["last_report"] = report.duplicate(true)
	dojo_state = state.duplicate(true)
	last_report = report.duplicate(true)

	var frames: Array = _safe_array(match_payload.get("spectator_frames", []))

	return {
		"success": true,
		"uses_scenario_panel": true,
		"spectator_frames": frames,
		"panel_title": "DOJO LIVE SPAR — SPECTATING",
		"text": str(frames [0].get("text", "")) if not frames.is_empty() else "%s and %s begin sparring." % [_person_label(fighter_a), _person_label(fighter_b)],
		"footer_text": "Spectating live. No input needed.",
		"combat_ui": frames [0].get("combat_ui", {}) if not frames.is_empty() else {},
		"opps": frames [0].get("opps", []) if not frames.is_empty() else [],
		"popup_title": "NPC Dojo Spar Spectated",
		"popup_text": "%s defeated %s with %s.\n\n%s" % [
			_person_label(winner),
			_person_label(loser),
			str(match_payload.get("finish_move", "Controlled Sparring Finish")),
			"The exchange was saved for film study." if not film_row.is_empty() else _dojo_film_study_locked_reason()
		],
		"popup_footer": "Tap anywhere to continue.",
		"match_payload": match_payload.duplicate(true),
		"report": report.duplicate(true)
	}


func _dojo_npc_spar_pair(actor: Person, dojo: Dictionary, options: Dictionary = {}) -> Array:
	var candidates: Array = []
	var element: String = str(dojo.get("element", _element_for_actor(actor))).strip_edges().to_lower()

	for raw_classmate in _classmates_for_dojo(actor, dojo):
		if typeof(raw_classmate) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = raw_classmate
		var npc: Person = _find_living_person_by_id(int(row.get("id", -1)))
		if npc == null:
			continue
		if actor != null and int(npc.id) == int(actor.id):
			continue

		candidates.append({
			"person": npc,
			"level": _bending_level(npc, element)
		})

	var sensei: Person = _teacher_for_dojo(actor, dojo)
	if sensei != null and actor != null and int(sensei.id) != int(actor.id):
		candidates.append({
			"person": sensei,
			"level": _bending_level(sensei, element)
		})

	candidates.sort_custom(func (a, b):
		return int(a.get("level", 0)) > int(b.get("level", 0))
	)

	if candidates.size() < 2:
		return []

	var tier_id: String = str(options.get("tier_id", "intermediate")).strip_edges().to_lower()
	if tier_id == "master":
		return [
			candidates [0].get("person", null),
			candidates [min(1, candidates.size() - 1)].get("person", null)
		]

	var first_index: int = 0
	if tier_id == "beginner":
		first_index = max(0, candidates.size() - 2)
	elif tier_id == "intermediate":
		first_index = int(clamp(int(floor(float(candidates.size()) * 0.35)), 0, candidates.size() - 2))
	else:
		first_index = 0

	return [
		candidates [first_index].get("person", null),
		candidates [first_index + 1].get("person", null)
	]
func _stable_dojo_founded_year(dojo: Dictionary) -> int:
	var current_year: int = int(gs.year) if gs != null else 0
	var dojo_id: String = str(dojo.get("id", dojo.get("name", "dojo")))
	var age_span: int = 12 + abs(int(dojo_id.hash())) % 120
	return current_year - age_span


func _dojo_history_row(dojo_id: String) -> Dictionary:
	var state: Dictionary = _ensure_state()
	var history: Dictionary = _safe_dictionary(state.get("dojo_history", {}))
	return _safe_dictionary(history.get(dojo_id, {})).duplicate(true)


func _dojo_rivalry_rows(dojo_id: String) -> Array:
	var state: Dictionary = _ensure_state()
	var rivalries: Dictionary = _safe_dictionary(state.get("dojo_rivalries", {}))
	var out: Array = []

	for raw_key in rivalries.keys():
		var row: Dictionary = _safe_dictionary(rivalries.get(raw_key, {}))
		if row.is_empty():
			continue
		if str(row.get("dojo_a_id", "")) != dojo_id and str(row.get("dojo_b_id", "")) != dojo_id:
			continue
		out.append(row.duplicate(true))

	out.sort_custom(func (a, b):
		return int(a.get("heat", 0)) > int(b.get("heat", 0))
	)

	return out


func _append_dojo_history_event(dojo_id: String, event: Dictionary) -> void:
	var clean_dojo_id: String = str(dojo_id).strip_edges()
	if clean_dojo_id == "" or event.is_empty():
		return

	var state: Dictionary = _ensure_state()
	var history: Dictionary = _safe_dictionary(state.get("dojo_history", {}))
	var row: Dictionary = _safe_dictionary(history.get(clean_dojo_id, {}))

	if row.is_empty():
		var dojo: Dictionary = _dojo_by_id(clean_dojo_id)
		if dojo.is_empty():
			return

		var current_year: int = int(gs.year) if gs != null else 0
		var founded_year: int = _stable_dojo_founded_year(dojo)

		row = {
			"schema": "eralife.bending_dojo_history",
			"version": CONTRACT_VERSION,
			"dojo_id": clean_dojo_id,
			"dojo_name": str(dojo.get("name", "Bending Dojo")),
			"element": str(dojo.get("element", "")),
			"tier": str(dojo.get("tier", "local")),
			"founded_year": founded_year,
			"years_active": max(0, current_year - founded_year),
			"active_sensei_id": -1,
			"active_sensei_name": "",
			"sensei_lineage": [],
			"active_classmate_ids": [],
			"notable_events": []
		}

	var events: Array = _safe_array(row.get("notable_events", []))
	events.append(event.duplicate(true))
	while events.size() > 40:
		events.pop_front()

	row ["notable_events"] = events
	row ["updated_year"] = int(gs.year) if gs != null else 0
	history [clean_dojo_id] = row
	state ["dojo_history"] = history
	dojo_state = state.duplicate(true)


func _find_living_person_by_id(person_id: int) -> Person:
	var person: Person = _find_person_by_id(person_id)
	if person == null:
		return null
	if not bool(person.alive):
		return null
	return person
func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _merge_dict(base: Dictionary, patch: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	for key in patch.keys():
		var patch_value: Variant = patch [key]
		if typeof(patch_value) == TYPE_DICTIONARY and typeof(out.get(key, {})) == TYPE_DICTIONARY:
			out [key] = _merge_dict(out.get(key, {}), patch_value)
		else:
			out [key] = patch_value
	return out