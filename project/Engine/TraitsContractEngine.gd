extends Resource
class_name TraitsContractEngine

const ENGINE_STATE_SCHEMA:= "eralife.traits_contract_engine_state"
const TRAIT_PROFILE_SCHEMA:= "eralife.traits.actor_profile"
const TRAIT_CONTRACT_SCHEMA:= "eralife.traits.living_trait_contract"
const TRAIT_SELECTION_SCHEMA:= "eralife.traits.selection_contract"
const TRAIT_EVENT_SCHEMA:= "eralife.traits.event_contract"
const CONTRACT_VERSION:= 1

const MAX_TRAIT_EVENT_LEDGER:= 900
const MAX_TRAIT_DEVELOPMENT_LOG:= 80
const MAX_TRAIT_ACTION_OPTIONS:= 3

var gs
var actor_trait_profiles: Dictionary = {}
var trait_event_ledger: Array = []
var trait_catalog_version: int = 1
var last_report: Dictionary = {}

func _init(_gs = null):
	gs = _gs
	_ensure_state()


func _ensure_state() -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	actor_trait_profiles = _safe_dictionary(gs.scenario_state.get("traits_actor_profiles", actor_trait_profiles))
	trait_event_ledger = _safe_array(gs.scenario_state.get("traits_event_ledger", trait_event_ledger))
	trait_catalog_version = int(gs.scenario_state.get("traits_catalog_version", trait_catalog_version))

	_repair_state()
	_commit_state()


func export_state() -> Dictionary:
	_ensure_state()
	return {
		"schema": ENGINE_STATE_SCHEMA,
		"version": CONTRACT_VERSION,
		"trait_catalog_version": trait_catalog_version,
		"actor_trait_profiles": actor_trait_profiles.duplicate(true),
		"trait_event_ledger": trait_event_ledger.duplicate(true),
		"last_report": last_report.duplicate(true),
		"exported_at_ms": int(Time.get_ticks_msec())
	}


func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "invalid_data"
		}

	trait_catalog_version = int(data.get("trait_catalog_version", 1))
	actor_trait_profiles = _safe_dictionary(data.get("actor_trait_profiles", data.get("traits_actor_profiles", {})))
	trait_event_ledger = _safe_array(data.get("trait_event_ledger", data.get("traits_event_ledger", [])))
	last_report = _safe_dictionary(data.get("last_report", {}))

	_repair_state()
	_commit_state()

	last_report = {
		"success": true,
		"mode": "traits_contract_engine_imported",
		"schema": ENGINE_STATE_SCHEMA,
		"version": CONTRACT_VERSION,
		"profile_count": actor_trait_profiles.size(),
		"event_count": trait_event_ledger.size(),
		"repaired": true
	}

	return last_report.duplicate(true)


func build_trait_selection_contract(context: Dictionary = {}) -> Dictionary:
	return {
		"schema": TRAIT_SELECTION_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": "default_trait_selection_contract",
		"contract_id": "default_trait_selection_contract",
		"title": "Choose Starting Traits",
		"subtitle": "Pick 2 starting traits. They seed identity, but they do not imprison it.",
		"min_selected": 0,
		"max_selected": 2,
		"traits": _trait_catalog_rows(),
		"context": context.duplicate(true),
		"contract_mesh": {
			"source_of_truth": "TraitsContractEngine",
			"ui_owner": "GodModePanel/HouseholdCreator",
			"persistent": false,
			"ui_mutation_allowed": false
		}
	}


func apply_selected_traits(actor: Person, selected_trait_ids: Array, context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	if actor == null:
		return {
			"success": false,
			"reason": "missing_actor"
		}

	var actor_id: int = int(actor.id)
	var profile: Dictionary = ensure_actor_traits(actor, {
		"source": str(context.get("source", "apply_selected_traits")),
	})

	var clean_ids: Array = []
	for raw_trait_id in selected_trait_ids:
		var trait_id: String = _normalize_trait_id(str(raw_trait_id))
		if trait_id == "":
			continue
		if not _trait_catalog().has(trait_id):
			continue
		if trait_id not in clean_ids:
			clean_ids.append(trait_id)

	if clean_ids.size() > 2:
		clean_ids = clean_ids.slice(0, 2)

	var traits: Dictionary = _safe_dictionary(profile.get("traits", {}))
	var stage: String = _stage_for_age(actor.age)
	var changed_traits: Array = []

	for trait_id in clean_ids:
		var trait_contract: Dictionary = _trait_contract_for_actor(actor, trait_id, {
			"source": "selected",
			"stage": stage,
			"intensity": _selected_trait_start_intensity(stage),
			"selected_at_birth": bool(context.get("selected_at_birth", true)),
			"locked": false
		})
		trait_contract ["origin"] = str(context.get("origin", "player_selected"))
		trait_contract ["selected_seed"] = true
		trait_contract ["intensity"] = max(float(trait_contract.get("intensity", 0.0)), _selected_trait_start_intensity(stage))
		traits [trait_id] = trait_contract
		changed_traits.append(trait_contract.duplicate(true))

	profile ["traits"] = traits
	profile ["selected_trait_ids"] = clean_ids.duplicate(true)
	profile ["updated_at_ms"] = int(Time.get_ticks_msec())
	actor_trait_profiles [str(actor_id)] = _normalize_actor_trait_profile(actor, profile)

	_sync_legacy_person_traits(actor, actor_trait_profiles [str(actor_id)])
	_commit_state()

	return {
		"success": true,
		"mode": "selected_traits_applied",
		"actor_id": actor_id,
		"selected_trait_ids": clean_ids.duplicate(true),
		"changed_traits": changed_traits.duplicate(true),
		"profile": actor_trait_profiles [str(actor_id)].duplicate(true)
	}
func ensure_actor_traits(actor: Person, context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	if actor == null:
		return {}

	var actor_id: int = int(actor.id)
	var key: String = str(actor_id)
	var existing: Dictionary = _safe_dictionary(actor_trait_profiles.get(key, {}))

	if existing.is_empty():
		existing = _seed_actor_trait_profile(actor, context)

	existing = _refresh_profile_stage_and_decay(actor, existing, context)
	existing = _normalize_actor_trait_profile(actor, existing)

	actor_trait_profiles [key] = existing.duplicate(true)
	_sync_legacy_person_traits(actor, existing)
	_commit_state()

	return existing.duplicate(true)


func trait_action_options_for_actor(actor: Person, source_contract: Dictionary, base_options: Array, context: Dictionary = {}) -> Array:
	var out: Array = _safe_array(base_options)

	if actor == null:
		return out

	var profile: Dictionary = ensure_actor_traits(actor, {
		"source": "trait_action_options_for_actor",
		"source_contract_id": str(source_contract.get("id", source_contract.get("contract_id", "")))
	})

	var _traits: Dictionary = _safe_dictionary(profile.get("traits", {}))
	var added: int = 0

	var candidates: Array = _trait_action_candidates_for_profile(actor, profile, source_contract, context)
	for raw_option in candidates:
		if typeof(raw_option) != TYPE_DICTIONARY:
			continue
		if added >= MAX_TRAIT_ACTION_OPTIONS:
			break

		var option: Dictionary = raw_option as Dictionary
		var option_id: String = str(option.get("id", "")).strip_edges()
		if option_id == "":
			continue
		if _option_id_exists(out, option_id):
			continue

		out.append(option.duplicate(true))
		added += 1

	return out


func apply_choice_contract(actor: Person, source_contract: Dictionary, option: Dictionary, context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	if actor == null:
		return {
			"success": false,
			"reason": "missing_actor"
		}

	var actor_id: int = int(actor.id)
	var profile: Dictionary = ensure_actor_traits(actor, {
		"source": "apply_choice_contract",
		"source_contract_id": str(source_contract.get("id", source_contract.get("contract_id", "")))
	})

	var trait_delta: Dictionary = {}
	_merge_trait_delta(trait_delta, _trait_delta_from_option(option))
	_merge_trait_delta(trait_delta, _trait_delta_from_emotional_application_report(_safe_dictionary(context.get("emotional_application_report", {}))))
	_merge_trait_delta(trait_delta, _trait_delta_from_source_context(source_contract, option, context))

	if trait_delta.is_empty():
		return {
			"success": true,
			"skipped": true,
			"reason": "no_trait_delta",
			"actor_id": actor_id,
			"profile": profile.duplicate(true)
		}

	var before_profile: Dictionary = profile.duplicate(true)
	var traits: Dictionary = _safe_dictionary(profile.get("traits", {}))
	var stage: String = _stage_for_age(actor.age)
	var changed_traits: Array = []

	for raw_trait_id in trait_delta.keys():
		var trait_id: String = _normalize_trait_id(str(raw_trait_id))
		if trait_id == "":
			continue

		var delta_value: float = float(trait_delta.get(raw_trait_id, 0.0))
		if abs(delta_value) < 0.01:
			continue

		var trait_contract: Dictionary = _safe_dictionary(traits.get(trait_id, {}))
		if trait_contract.is_empty():
			trait_contract = _trait_contract_for_actor(actor, trait_id, {
				"source": "emerged_from_behavior",
				"stage": stage,
				"intensity": 0.0
			})

		var old_intensity: float = float(trait_contract.get("intensity", 0.0))
		var cap: float = _trait_stage_cap(trait_id, stage, trait_contract)
		var new_intensity: float = clamp(old_intensity + delta_value, 0.0, cap)

		trait_contract ["stage"] = stage
		trait_contract ["cap"] = cap
		trait_contract ["intensity"] = new_intensity
		trait_contract ["last_delta"] = delta_value
		trait_contract ["last_source_contract_id"] = str(source_contract.get("id", source_contract.get("contract_id", "")))
		trait_contract ["last_option_id"] = str(option.get("id", ""))
		trait_contract ["last_updated_year"] = _current_year()
		trait_contract ["last_updated_at_ms"] = int(Time.get_ticks_msec())
		trait_contract ["state"] = _trait_state_for_intensity(new_intensity)

		traits [trait_id] = trait_contract
		changed_traits.append(trait_contract.duplicate(true))

	profile ["traits"] = traits
	profile ["updated_at_ms"] = int(Time.get_ticks_msec())
	profile ["last_trait_delta"] = trait_delta.duplicate(true)

	var evolution_report: Dictionary = _apply_trait_evolutions(actor, profile, {
		"source": "apply_choice_contract",
		"source_contract": source_contract.duplicate(true),
		"option": option.duplicate(true)
	})
	profile = _safe_dictionary(evolution_report.get("profile", profile))

	actor_trait_profiles [str(actor_id)] = _normalize_actor_trait_profile(actor, profile)
	_sync_legacy_person_traits(actor, actor_trait_profiles [str(actor_id)])

	var event_contract: Dictionary = _trait_event_contract(actor, before_profile, actor_trait_profiles [str(actor_id)], trait_delta, source_contract, option, evolution_report, context)
	trait_event_ledger.append(event_contract.duplicate(true))
	if trait_event_ledger.size() > MAX_TRAIT_EVENT_LEDGER:
		trait_event_ledger = trait_event_ledger.slice(trait_event_ledger.size() - MAX_TRAIT_EVENT_LEDGER, trait_event_ledger.size())

	_commit_state()

	last_report = {
		"success": true,
		"mode": "trait_choice_contract_applied",
		"actor_id": actor_id,
		"trait_delta": trait_delta.duplicate(true),
		"changed_traits": changed_traits.duplicate(true),
		"evolution_report": evolution_report.duplicate(true),
		"profile": actor_trait_profiles [str(actor_id)].duplicate(true),
		"event_contract": event_contract.duplicate(true)
	}

	return last_report.duplicate(true)


func yearly_tick_actor(actor: Person, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "missing_actor"
		}

	var profile: Dictionary = ensure_actor_traits(actor, {
		"source": str(context.get("source", "yearly_tick_actor")),
		"force_decay": true
	})

	var evolution_report: Dictionary = _apply_trait_evolutions(actor, profile, {
		"source": "yearly_tick_actor"
	})

	profile = _safe_dictionary(evolution_report.get("profile", profile))
	actor_trait_profiles [str(int(actor.id))] = profile.duplicate(true)
	_sync_legacy_person_traits(actor, profile)
	_commit_state()

	return {
		"success": true,
		"mode": "traits_yearly_tick_actor",
		"actor_id": int(actor.id),
		"profile": profile.duplicate(true),
		"evolution_report": evolution_report.duplicate(true)
	}


func _seed_actor_trait_profile(actor: Person, context: Dictionary = {}) -> Dictionary:
	var actor_id: int = int(actor.id)
	var stage: String = _stage_for_age(actor.age)
	var traits: Dictionary = {}
	var seed_sources: Array = []
	var lineage_pressure: Dictionary = _lineage_pressure_for_actor(actor)

	var selected_ids: Array = _selected_trait_ids_from_context(actor, context)
	for raw_trait_id in selected_ids:
		var trait_id: String = _normalize_trait_id(str(raw_trait_id))
		if trait_id == "" or not _trait_catalog().has(trait_id):
			continue
		traits [trait_id] = _trait_contract_for_actor(actor, trait_id, {
			"source": "selected",
			"stage": stage,
			"intensity": _selected_trait_start_intensity(stage),
			"selected_seed": true
		})
		seed_sources.append("selected:%s" % trait_id)

	var legacy_traits: Array = _safe_array(actor.traits)
	for raw_legacy_trait in legacy_traits:
		var trait_id: String = _normalize_trait_id(str(raw_legacy_trait))
		if trait_id == "":
			continue
		if not _trait_catalog().has(trait_id):
			trait_id = _legacy_trait_to_living_trait_id(str(raw_legacy_trait))
		if trait_id == "" or not _trait_catalog().has(trait_id):
			continue
		if not traits.has(trait_id):
			traits [trait_id] = _trait_contract_for_actor(actor, trait_id, {
				"source": "legacy_person_trait",
				"stage": stage,
				"intensity": _legacy_trait_start_intensity(stage)
			})
			seed_sources.append("legacy:%s" % trait_id)

	_merge_seed_traits_from_lineage(actor, traits, lineage_pressure, seed_sources)
	_merge_seed_traits_from_age(actor, traits, seed_sources)

	var profile: Dictionary = {
		"schema": TRAIT_PROFILE_SCHEMA,
		"version": CONTRACT_VERSION,
		"actor_id": actor_id,
		"actor_name": _actor_name(actor),
		"stage": stage,
		"traits": traits.duplicate(true),
		"selected_trait_ids": selected_ids.duplicate(true),
		"lineage_pressure": lineage_pressure.duplicate(true),
		"seed_sources": seed_sources.duplicate(true),
		"development_log": [],
		"created_year": _current_year(),
		"updated_year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec()),
		"updated_at_ms": int(Time.get_ticks_msec()),
		"contract_mesh": {
			"source_of_truth": "TraitsContractEngine",
			"ui_mutation_allowed": false,
			"persistent": true,
			"save_key": "traits_actor_profiles"
		}
	}

	return _normalize_actor_trait_profile(actor, profile)


func _trait_action_candidates_for_profile(actor: Person, profile: Dictionary, source_contract: Dictionary, _context: Dictionary = {}) -> Array:
	var out: Array = []
	var traits: Dictionary = _safe_dictionary(profile.get("traits", {}))

	if _trait_intensity(traits, "charming") >= 25.0:
		out.append(_trait_action_option("trait_charm_them", "Charm them", "charming", actor, source_contract, {
			"trust": 3,
			"comfort": 3,
			"affection": 2
		}))

	if _trait_intensity(traits, "mischievous") >= 25.0:
		out.append(_trait_action_option("trait_make_mischievous_joke", "Make a mischievous joke", "mischievous", actor, source_contract, {
			"curiosity": 3,
			"comfort": 1,
			"stress": -1
		}))

	if _trait_intensity(traits, "loyal") >= 30.0:
		out.append(_trait_action_option("trait_stand_by_them", "Stand by them", "loyal", actor, source_contract, {
			"trust": 5,
			"protectiveness": 4,
			"comfort": 2
		}))

	if _trait_intensity(traits, "guarded") >= 30.0:
		out.append(_trait_action_option("trait_keep_guard_up", "Keep your guard up", "guarded", actor, source_contract, {
			"suspicion": 3,
			"comfort": -1,
			"fear": -1
		}))

	if _trait_intensity(traits, "bold") >= 30.0:
		out.append(_trait_action_option("trait_confront_directly", "Confront directly", "bold", actor, source_contract, {
			"respect": 3,
			"stress": 2,
			"fear": -2
		}))

	if _trait_intensity(traits, "calculated") >= 30.0 or _trait_intensity(traits, "strategic") >= 30.0:
		out.append(_trait_action_option("trait_read_the_angle", "Read the angle", "calculated", actor, source_contract, {
			"curiosity": 2,
			"trust": 1,
			"stress": -2
		}))

	if _trait_intensity(traits, "compassionate") >= 30.0:
		out.append(_trait_action_option("trait_comfort_them", "Comfort them", "compassionate", actor, source_contract, {
			"comfort": 5,
			"trust": 3,
			"protectiveness": 2
		}))

	if _trait_intensity(traits, "rebellious") >= 35.0:
		out.append(_trait_action_option("trait_refuse_the_script", "Refuse the script", "rebellious", actor, source_contract, {
			"respect": 2,
			"stress": 3,
			"resentment": -2
		}))

	if _trait_intensity(traits, "charming_rogue") >= 40.0:
		out.append(_trait_action_option("trait_spin_it_in_your_favor", "Spin it in your favor", "charming_rogue", actor, source_contract, {
			"trust": 2,
			"curiosity": 4,
			"suspicion": 2
		}))

	out.sort_custom(Callable(self, "_sort_trait_action_options"))
	return out


func _trait_action_option(option_id: String, label: String, trait_id: String, actor: Person, source_contract: Dictionary, emotional_impact: Dictionary) -> Dictionary:
	return {
		"id": option_id,
		"label": label,
		"source_resolves": true,
		"priority": 64,
		"trait_action": true,
		"trait_id": trait_id,
		"trait_gate": {
			"trait_id": trait_id,
			"actor_id": int(actor.id) if actor != null else -1,
			"minimum_intensity": 25.0
		},
		"trait_feed": {
			trait_id: 5.0
		},
		"emotional_impact": emotional_impact.duplicate(true),
		"journal_text": "I used my %s side while dealing with this." % _trait_display_name(trait_id).to_lower(),
		"result_text": "You lean into your %s side. The moment bends around who you are becoming." % _trait_display_name(trait_id).to_lower(),
		"popup_title": "Trait Expression",
		"popup_footer": "Tap anywhere to continue.",
		"contract_mesh": {
			"source_of_truth": "TraitsContractEngine",
			"source_contract_id": str(source_contract.get("id", source_contract.get("contract_id", ""))),
			"ui_mutation_allowed": false
		}
	}


func _apply_trait_evolutions(actor: Person, profile: Dictionary, context: Dictionary = {}) -> Dictionary:
	var traits: Dictionary = _safe_dictionary(profile.get("traits", {}))
	var unlocked: Array = []
	var replaced: Array = []

	_unlock_combo_trait(actor, traits, "charming_rogue", ["charming", "mischievous"], 55.0, unlocked)
	_unlock_combo_trait(actor, traits, "calculated", ["guarded", "curious"], 50.0, unlocked)
	_unlock_combo_trait(actor, traits, "perfectionist", ["disciplined", "anxious"], 50.0, unlocked)
	_unlock_combo_trait(actor, traits, "strategic", ["calculated", "ambitious"], 55.0, unlocked)
	_unlock_combo_trait(actor, traits, "people_pleaser", ["anxious", "compassionate"], 50.0, unlocked)
	_unlock_combo_trait(actor, traits, "independent", ["rebellious", "disciplined"], 55.0, unlocked)

	if _trait_intensity(traits, "mischievous") >= _trait_stage_cap("mischievous", _stage_for_age(actor.age), _safe_dictionary(traits.get("mischievous", {}))) - 1.0:
		if int(actor.age) >= 12:
			_unlock_trait(actor, traits, "rebellious", 18.0, "mischievous_stage_cap", unlocked)

	if _trait_intensity(traits, "resentful") >= 50.0 or _trait_intensity(traits, "bitter") >= 45.0:
		_unlock_trait(actor, traits, "guarded", 20.0, "resentment_hardened", unlocked)

	profile ["traits"] = traits
	profile ["updated_year"] = _current_year()
	profile ["updated_at_ms"] = int(Time.get_ticks_msec())

	var development_log: Array = _safe_array(profile.get("development_log", []))
	for raw_unlock in unlocked:
		if typeof(raw_unlock) != TYPE_DICTIONARY:
			continue
		development_log.append(raw_unlock)
	if development_log.size() > MAX_TRAIT_DEVELOPMENT_LOG:
		development_log = development_log.slice(development_log.size() - MAX_TRAIT_DEVELOPMENT_LOG, development_log.size())
	profile ["development_log"] = development_log

	return {
		"success": true,
		"mode": "trait_evolution_checked",
		"unlocked": unlocked.duplicate(true),
		"replaced": replaced.duplicate(true),
		"profile": profile.duplicate(true),
		"context": context.duplicate(true)
	}


func _refresh_profile_stage_and_decay(actor: Person, profile: Dictionary, context: Dictionary = {}) -> Dictionary:
	var out: Dictionary = profile.duplicate(true)
	var old_stage: String = str(out.get("stage", "")).strip_edges().to_lower()
	var new_stage: String = _stage_for_age(actor.age)
	var current_year: int = _current_year()
	var last_year: int = int(out.get("last_decay_year", out.get("updated_year", current_year)))
	var years_passed: int = max(0, current_year - last_year)

	out ["stage"] = new_stage
	out ["updated_year"] = current_year

	var traits: Dictionary = _safe_dictionary(out.get("traits", {}))
	for raw_trait_id in traits.keys():
		var trait_id: String = _normalize_trait_id(str(raw_trait_id))
		var trait_contract: Dictionary = _safe_dictionary(traits.get(raw_trait_id, {}))
		if trait_contract.is_empty():
			continue

		var intensity: float = float(trait_contract.get("intensity", 0.0))
		var decay: float = float(trait_contract.get("decay", _trait_decay_rate(trait_id)))
		var selected_seed: bool = bool(trait_contract.get("selected_seed", false))
		var force_decay: bool = bool(context.get("force_decay", false))

		if years_passed > 0 or force_decay:
			var decay_multiplier: float = 0.35 if selected_seed else 1.0
			intensity = max(0.0, intensity - (decay * float(max(1, years_passed)) * decay_multiplier))

		var cap: float = _trait_stage_cap(trait_id, new_stage, trait_contract)
		trait_contract ["stage"] = new_stage
		trait_contract ["cap"] = cap
		trait_contract ["intensity"] = clamp(intensity, 0.0, cap)
		trait_contract ["state"] = _trait_state_for_intensity(float(trait_contract.get("intensity", 0.0)))
		traits [trait_id] = trait_contract

	out ["traits"] = traits
	out ["last_decay_year"] = current_year

	if old_stage != "" and old_stage != new_stage:
		var development_log: Array = _safe_array(out.get("development_log", []))
		development_log.append({
			"type": "stage_transition",
			"from": old_stage,
			"to": new_stage,
			"year": current_year,
			"age": int(actor.age),
			"created_at_ms": int(Time.get_ticks_msec())
		})
		out ["development_log"] = development_log

	return out


func _trait_delta_from_option(option: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	if typeof(option) != TYPE_DICTIONARY:
		return out

	_merge_trait_delta(out, _safe_dictionary(option.get("trait_feed", {})))
	_merge_trait_delta(out, _safe_dictionary(option.get("trait_delta", {})))
	_merge_trait_delta(out, _safe_dictionary(option.get("trait_growth", {})))

	if bool(option.get("trait_action", false)):
		var trait_id: String = _normalize_trait_id(str(option.get("trait_id", "")))
		if trait_id != "":
			out [trait_id] = float(out.get(trait_id, 0.0)) + 4.0

	var option_id: String = str(option.get("id", "")).strip_edges().to_lower()
	var label: String = str(option.get("label", "")).strip_edges().to_lower()
	var combined: String = "%s %s" % [option_id, label]

	if combined.find("lie") >= 0 or combined.find("prank") >= 0 or combined.find("joke") >= 0:
		out ["mischievous"] = float(out.get("mischievous", 0.0)) + 3.0
	if combined.find("comfort") >= 0 or combined.find("help") >= 0 or combined.find("visit") >= 0:
		out ["compassionate"] = float(out.get("compassionate", 0.0)) + 3.0
	if combined.find("defend") >= 0 or combined.find("stand_by") >= 0:
		out ["loyal"] = float(out.get("loyal", 0.0)) + 4.0
	if combined.find("silent") >= 0 or combined.find("guard") >= 0:
		out ["guarded"] = float(out.get("guarded", 0.0)) + 2.0
	if combined.find("confront") >= 0 or combined.find("fight") >= 0:
		out ["bold"] = float(out.get("bold", 0.0)) + 3.0
	if combined.find("study") >= 0 or combined.find("train") >= 0 or combined.find("practice") >= 0:
		out ["disciplined"] = float(out.get("disciplined", 0.0)) + 3.0

	return out


func _trait_delta_from_emotional_application_report(report: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var updates: Array = _safe_array(report.get("relationship_dna_updates", []))

	for raw_update in updates:
		if typeof(raw_update) != TYPE_DICTIONARY:
			continue

		var update: Dictionary = raw_update as Dictionary
		var delta: Dictionary = _safe_dictionary(update.get("dna_delta", {}))

		out ["loyal"] = float(out.get("loyal", 0.0)) + max(0.0, float(delta.get("trust", 0.0))) * 0.18
		out ["compassionate"] = float(out.get("compassionate", 0.0)) + max(0.0, float(delta.get("comfort", 0.0))) * 0.14
		out ["curious"] = float(out.get("curious", 0.0)) + max(0.0, float(delta.get("curiosity", 0.0))) * 0.16
		out ["guarded"] = float(out.get("guarded", 0.0)) + max(0.0, float(delta.get("suspicion", 0.0))) * 0.18
		out ["anxious"] = float(out.get("anxious", 0.0)) + max(0.0, float(delta.get("fear", 0.0))) * 0.2
		out ["bitter"] = float(out.get("bitter", 0.0)) + max(0.0, float(delta.get("resentment", 0.0))) * 0.18
		out ["ambitious"] = float(out.get("ambitious", 0.0)) + max(0.0, float(delta.get("pride", 0.0))) * 0.12
		out ["competitive"] = float(out.get("competitive", 0.0)) + max(0.0, float(delta.get("envy", 0.0))) * 0.2
		out ["perfectionist"] = float(out.get("perfectionist", 0.0)) + max(0.0, float(delta.get("perceived_pressure", delta.get("stress", 0.0)))) * 0.12
		out ["people_pleaser"] = float(out.get("people_pleaser", 0.0)) + max(0.0, float(delta.get("perceived_neglect", 0.0))) * 0.1

	return _clean_trait_delta(out)


func _trait_delta_from_source_context(source_contract: Dictionary, option: Dictionary, _context: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}
	var request: String = str(source_contract.get("request", "")).strip_edges().to_lower()
	var category: String = str(source_contract.get("category", "")).strip_edges().to_lower()
	var option_id: String = str(option.get("id", "")).strip_edges().to_lower()

	if request == "newborn_sibling_attention":
		if option_id == "smile":
			out ["charming"] = 2.0
			out ["loyal"] = 1.0
		elif option_id == "stare_back":
			out ["mischievous"] = 2.0
			out ["curious"] = 2.0
		elif option_id == "start_crying":
			out ["anxious"] = 1.5

	if category in ["school", "education"]:
		out ["disciplined"] = float(out.get("disciplined", 0.0)) + 0.4
	if category in ["family", "relationships"]:
		out ["loyal"] = float(out.get("loyal", 0.0)) + 0.3

	return out


func _lineage_pressure_for_actor(actor: Person) -> Dictionary:
	var out: Dictionary = {
		"inherited_trait_biases": {},
		"environment_pressure": {},
		"inheritance_mode": "emotional_tendency_not_trait_copy"
	}

	if actor == null or gs == null:
		return out

	var inherited: Dictionary = {}
	var parent_ids: Array = _safe_array(actor.parents)

	for raw_parent_id in parent_ids:
		var parent_id: int = int(raw_parent_id)
		if parent_id <= 0:
			continue

		var parent_actor: Person = _actor_by_id(parent_id)
		if parent_actor == null:
			continue

		var parent_profile: Dictionary = _safe_dictionary(actor_trait_profiles.get(str(parent_id), {}))
		if parent_profile.is_empty():
			parent_profile = _seed_actor_trait_profile(parent_actor, {
				"source": "lineage_parent_seed_preview",
			})

		var parent_traits: Dictionary = _safe_dictionary(parent_profile.get("traits", {}))
		for raw_trait_id in parent_traits.keys():
			var trait_id: String = _normalize_trait_id(str(raw_trait_id))
			var intensity: float = float(_safe_dictionary(parent_traits.get(raw_trait_id, {})).get("intensity", 0.0))
			if intensity < 35.0:
				continue
			inherited [trait_id] = float(inherited.get(trait_id, 0.0)) + intensity * 0.08

		_merge_trait_delta(inherited, _environment_trait_pressure_from_parent_relationship(actor, parent_actor))

	out ["inherited_trait_biases"] = inherited
	out ["environment_pressure"] = _environment_pressure_summary(inherited)
	return out
func _environment_trait_pressure_from_parent_relationship(child: Person, parent: Person) -> Dictionary:
	var out: Dictionary = {}
	if child == null or parent == null:
		return out

	if gs == null or not ("contract_view_layer_contract_engine" in gs) or gs.contract_view_layer_contract_engine == null:
		return out

	var dna_index: Dictionary = _safe_dictionary(gs.contract_view_layer_contract_engine.get("relationship_dna_index"))
	var dna: Dictionary = _safe_dictionary(dna_index.get("%d:%d" % [int(child.id), int(parent.id)], {}))

	if dna.is_empty():
		return out

	out ["anxious"] = max(0.0, float(dna.get("fear", 0.0))) * 0.06
	out ["guarded"] = max(0.0, float(dna.get("suspicion", 0.0))) * 0.06
	out ["bitter"] = max(0.0, float(dna.get("resentment", 0.0))) * 0.05
	out ["perfectionist"] = max(0.0, float(dna.get("perceived_unfairness", 0.0))) * 0.05
	out ["people_pleaser"] = max(0.0, float(dna.get("perceived_neglect", 0.0))) * 0.04
	out ["loyal"] = max(0.0, float(dna.get("trust", 0.0)) - 50.0) * 0.03

	return out


func _merge_seed_traits_from_lineage(actor: Person, traits: Dictionary, lineage_pressure: Dictionary, seed_sources: Array) -> void:
	var inherited: Dictionary = _safe_dictionary(lineage_pressure.get("inherited_trait_biases", {}))
	var stage: String = _stage_for_age(actor.age)

	for raw_trait_id in inherited.keys():
		var trait_id: String = _normalize_trait_id(str(raw_trait_id))
		if trait_id == "" or not _trait_catalog().has(trait_id):
			continue

		var pressure: float = float(inherited.get(raw_trait_id, 0.0))
		if pressure < 2.0:
			continue

		var inverted: bool = _seeded_unit("%d:%s:invert" % [int(actor.id), trait_id]) < 0.18
		var final_trait_id: String = _opposite_trait_for_pressure(trait_id) if inverted else trait_id
		if final_trait_id == "" or not _trait_catalog().has(final_trait_id):
			final_trait_id = trait_id

		if not traits.has(final_trait_id):
			traits [final_trait_id] = _trait_contract_for_actor(actor, final_trait_id, {
				"source": "lineage_pressure",
				"stage": stage,
				"intensity": clamp(pressure, 4.0, _lineage_start_cap(stage))
			})
			seed_sources.append("lineage:%s" % final_trait_id)


func _merge_seed_traits_from_age(actor: Person, traits: Dictionary, seed_sources: Array) -> void:
	var desired_count: int = _desired_seed_trait_count_for_age(actor.age)
	if traits.size() >= desired_count:
		return

	var stage: String = _stage_for_age(actor.age)
	var pool: Array = _seed_pool_for_stage(stage)
	var cursor: int = 0

	while traits.size() < desired_count and cursor < pool.size():
		var trait_id: String = str(pool [cursor])
		cursor += 1

		var roll: float = _seeded_unit("%d:%s:%s" % [int(actor.id), trait_id, stage])
		if roll < 0.35 and traits.size() > 0:
			continue

		if not traits.has(trait_id):
			traits [trait_id] = _trait_contract_for_actor(actor, trait_id, {
				"source": "natural_seed",
				"stage": stage,
				"intensity": _natural_seed_intensity(stage)
			})
			seed_sources.append("natural:%s" % trait_id)


func _trait_contract_for_actor(actor: Person, trait_id: String, context: Dictionary = {}) -> Dictionary:
	var clean_id: String = _normalize_trait_id(trait_id)
	var definition: Dictionary = _safe_dictionary(_trait_catalog().get(clean_id, {}))
	var stage: String = str(context.get("stage", _stage_for_age(actor.age if actor != null else 0))).strip_edges().to_lower()
	var intensity: float = float(context.get("intensity", 0.0))
	var cap: float = _trait_stage_cap(clean_id, stage, definition)

	return {
		"schema": TRAIT_CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"trait_id": clean_id,
		"display_name": str(definition.get("name", _trait_display_name(clean_id))),
		"base_trait": str(definition.get("base_trait", clean_id)),
		"branch": str(definition.get("branch", "")),
		"stage": stage,
		"state": _trait_state_for_intensity(intensity),
		"intensity": clamp(intensity, 0.0, cap),
		"cap": cap,
		"growth": float(definition.get("growth", 1.0)),
		"decay": float(definition.get("decay", 0.45)),
		"sources": _safe_array(context.get("sources", [str(context.get("source", "unknown"))])),
		"evolution_paths": _safe_array(definition.get("evolution_paths", [])),
		"suppression_factors": _safe_array(definition.get("suppression_factors", [])),
		"expression_modifiers": _safe_dictionary(definition.get("expression_modifiers", {})),
		"selected_seed": bool(context.get("selected_seed", context.get("selected_at_birth", false))),
		"origin": str(context.get("source", "unknown")),
		"created_year": _current_year(),
		"last_updated_year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec()),
		"last_updated_at_ms": int(Time.get_ticks_msec())
	}


func _trait_catalog() -> Dictionary:
	return {
		"charming": {
			"name": "Charming",
			"base_trait": "social_gravity",
			"growth": 1.05,
			"decay": 0.35,
			"evolution_paths": ["leader", "manipulative", "charming_rogue"],
			"suppression_factors": ["social_rejection", "humiliation"],
			"expression_modifiers": { "social_success_bonus": 1.2, "persuasion": 1.2}
		},
		"mischievous": {
			"name": "Mischievous",
			"base_trait": "rule_bending",
			"growth": 1.1,
			"decay": 0.45,
			"evolution_paths": ["rebellious", "trickster", "charming_rogue"],
			"suppression_factors": ["strict_punishment", "fear"],
			"expression_modifiers": { "risk_taking": 1.25, "playfulness": 1.35}
		},
		"loyal": {
			"name": "Loyal",
			"base_trait": "attachment",
			"growth": 0.95,
			"decay": 0.3,
			"evolution_paths": ["protector", "devoted", "martyr"],
			"suppression_factors": ["betrayal", "neglect"],
			"expression_modifiers": { "defense_bonus": 1.25}
		},
		"guarded": {
			"name": "Guarded",
			"base_trait": "self_protection",
			"growth": 0.95,
			"decay": 0.25,
			"evolution_paths": ["cold", "calculated", "independent"],
			"suppression_factors": ["consistent_safety", "earned_trust"],
			"expression_modifiers": { "trust_threshold": 1.25}
		},
		"disciplined": {
			"name": "Disciplined",
			"base_trait": "self_control",
			"growth": 0.9,
			"decay": 0.28,
			"evolution_paths": ["focused", "perfectionist", "strategic"],
			"suppression_factors": ["chaos", "burnout"],
			"expression_modifiers": { "training_bonus": 1.25}
		},
		"curious": {
			"name": "Curious",
			"base_trait": "exploration",
			"growth": 1.0,
			"decay": 0.42,
			"evolution_paths": ["investigative", "inventive", "calculated"],
			"suppression_factors": ["fear", "strict_silencing"],
			"expression_modifiers": { "learning_bonus": 1.18}
		},
		"compassionate": {
			"name": "Compassionate",
			"base_trait": "care",
			"growth": 0.9,
			"decay": 0.3,
			"evolution_paths": ["healer", "protector", "people_pleaser"],
			"suppression_factors": ["betrayal", "emotional_exhaustion"],
			"expression_modifiers": { "comfort_bonus": 1.25}
		},
		"bold": {
			"name": "Bold",
			"base_trait": "approach_pressure",
			"growth": 1.0,
			"decay": 0.4,
			"evolution_paths": ["fearless", "reckless", "leader"],
			"suppression_factors": ["humiliation", "punishment"],
			"expression_modifiers": { "confrontation_bonus": 1.2}
		},
		"anxious": {
			"name": "Anxious",
			"base_trait": "threat_sensitivity",
			"growth": 0.85,
			"decay": 0.2,
			"evolution_paths": ["people_pleaser", "perfectionist", "guarded"],
			"suppression_factors": ["stable_safety", "reassurance"],
			"expression_modifiers": { "risk_avoidance": 1.25}
		},
		"ambitious": {
			"name": "Ambitious",
			"base_trait": "status_drive",
			"growth": 0.95,
			"decay": 0.38,
			"evolution_paths": ["leader", "strategic", "ruthless"],
			"suppression_factors": ["failure_spiral", "low_confidence"],
			"expression_modifiers": { "career_push": 1.25}
		},
		"competitive": {
			"name": "Competitive",
			"base_trait": "comparison_drive",
			"growth": 1.0,
			"decay": 0.36,
			"evolution_paths": ["rivalrous", "champion_minded", "resentful"],
			"suppression_factors": ["secure_identity", "shared_success"],
			"expression_modifiers": { "challenge_bonus": 1.2}
		},
		"bitter": {
			"name": "Bitter",
			"base_trait": "stored_hurt",
			"growth": 0.75,
			"decay": 0.18,
			"evolution_paths": ["cold", "resentful", "calculated"],
			"suppression_factors": ["repair", "accountability", "forgiveness"],
			"expression_modifiers": { "grudge_retention": 1.35}
		},
		"rebellious": {
			"name": "Rebellious",
			"base_trait": "resistance",
			"growth": 0.95,
			"decay": 0.32,
			"evolution_paths": ["independent", "reckless", "revolutionary"],
			"suppression_factors": ["respectful_authority", "purpose"],
			"expression_modifiers": { "authority_resistance": 1.3}
		},
		"calculated": {
			"name": "Calculated",
			"base_trait": "controlled_strategy",
			"growth": 0.8,
			"decay": 0.22,
			"evolution_paths": ["strategic", "manipulative", "cold"],
			"suppression_factors": ["emotional_safety", "impulsivity"],
			"expression_modifiers": { "planning_bonus": 1.3}
		},
		"perfectionist": {
			"name": "Perfectionist",
			"base_trait": "pressure_control",
			"growth": 0.75,
			"decay": 0.18,
			"evolution_paths": ["elite", "burned_out", "controlling"],
			"suppression_factors": ["acceptance", "failure_tolerance"],
			"expression_modifiers": { "performance_bonus": 1.25, "stress_cost": 1.2}
		},
		"people_pleaser": {
			"name": "People-Pleaser",
			"base_trait": "approval_seeking",
			"growth": 0.75,
			"decay": 0.2,
			"evolution_paths": ["diplomatic", "self_erasing", "resentful"],
			"suppression_factors": ["boundaries", "secure_attachment"],
			"expression_modifiers": { "deescalation_bonus": 1.15}
		},
		"independent": {
			"name": "Independent",
			"base_trait": "self_direction",
			"growth": 0.85,
			"decay": 0.24,
			"evolution_paths": ["self_made", "loner", "leader"],
			"suppression_factors": ["dependency", "control"],
			"expression_modifiers": { "self_reliance": 1.3}
		},
		"strategic": {
			"name": "Strategic",
			"base_trait": "long_game",
			"growth": 0.75,
			"decay": 0.2,
			"evolution_paths": ["mastermind", "statesman", "manipulative"],
			"suppression_factors": ["chaos", "panic"],
			"expression_modifiers": { "future_planning": 1.35}
		},
		"charming_rogue": {
			"name": "Charming Rogue",
			"base_trait": "social_rule_bending",
			"growth": 0.65,
			"decay": 0.16,
			"evolution_paths": ["manipulative", "legendary_trickster", "charismatic_leader"],
			"suppression_factors": ["accountability", "exposure"],
			"expression_modifiers": { "persuasion": 1.35, "risk_taking": 1.15}
		}
	}


func _trait_catalog_rows() -> Array:
	var out: Array = []
	var catalog: Dictionary = _trait_catalog()

	for raw_trait_id in catalog.keys():
		var trait_id: String = str(raw_trait_id)
		var row: Dictionary = _safe_dictionary(catalog.get(raw_trait_id, {}))
		row ["trait_id"] = trait_id
		row ["id"] = trait_id
		row ["label"] = str(row.get("name", _trait_display_name(trait_id)))
		row ["description"] = _trait_selection_description(trait_id)
		out.append(row)

	out.sort_custom(Callable(self, "_sort_trait_catalog_rows"))
	return out


func _trait_selection_description(trait_id: String) -> String:
	match _normalize_trait_id(trait_id):
		"charming":
			return "Social gravity. Starts cute, can become leadership, manipulation, or a charming rogue arc."
		"mischievous":
			return "Playful rule-bending. Can become rebellious, creative, reckless, or socially dangerous."
		"loyal":
			return "Attachment under pressure. Can become protective, devoted, or self-sacrificing."
		"guarded":
			return "Self-protection. Can become independent, cold, or calculated."
		"disciplined":
			return "Self-control. Can become focused, strategic, or perfectionistic."
		"curious":
			return "Exploration drive. Can become inventive, investigative, or too nosy for safety."
		"compassionate":
			return "Care response. Can become healing, protecting, or people-pleasing."
		"bold":
			return "Pressure approach. Can become brave, reckless, or commanding."
		"anxious":
			return "Threat sensitivity. Can become guarded, perfectionistic, or approval-seeking."
		"ambitious":
			return "Status drive. Can become leadership, strategy, or ruthlessness."
		_:
			return "A living trait seed that can grow, decay, merge, or mutate through play."


func _sort_trait_catalog_rows(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("label", "")) < str(b.get("label", ""))


func _sort_trait_action_options(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("priority", 0)) > int(b.get("priority", 0))


func _unlock_combo_trait(actor: Person, traits: Dictionary, new_trait_id: String, required_traits: Array, minimum: float, unlocked: Array) -> void:
	for raw_required in required_traits:
		var required_id: String = _normalize_trait_id(str(raw_required))
		if _trait_intensity(traits, required_id) < minimum:
			return

	_unlock_trait(actor, traits, new_trait_id, 18.0, "combo:%s" % ",".join(required_traits), unlocked)


func _unlock_trait(actor: Person, traits: Dictionary, trait_id: String, intensity: float, source: String, unlocked: Array) -> void:
	var clean_id: String = _normalize_trait_id(trait_id)
	if clean_id == "" or not _trait_catalog().has(clean_id):
		return

	var stage: String = _stage_for_age(actor.age if actor != null else 0)
	var existing: Dictionary = _safe_dictionary(traits.get(clean_id, {}))
	if not existing.is_empty() and float(existing.get("intensity", 0.0)) >= intensity:
		return

	var contract: Dictionary = _trait_contract_for_actor(actor, clean_id, {
		"source": source,
		"stage": stage,
		"intensity": max(intensity, float(existing.get("intensity", 0.0)))
	})
	contract ["mutation_unlocked"] = true
	contract ["origin"] = source
	traits [clean_id] = contract

	unlocked.append({
		"trait_id": clean_id,
		"display_name": _trait_display_name(clean_id),
		"source": source,
		"year": _current_year(),
		"age": int(actor.age) if actor != null else 0,
		"created_at_ms": int(Time.get_ticks_msec())
	})


func _normalize_actor_trait_profile(actor: Person, profile: Dictionary) -> Dictionary:
	var out: Dictionary = profile.duplicate(true)
	var actor_id: int = int(actor.id) if actor != null else int(out.get("actor_id", -1))

	out ["schema"] = str(out.get("schema", TRAIT_PROFILE_SCHEMA))
	out ["version"] = int(out.get("version", CONTRACT_VERSION))
	out ["actor_id"] = actor_id
	out ["actor_name"] = _actor_name(actor) if actor != null else str(out.get("actor_name", "Unknown"))
	out ["stage"] = _stage_for_age(actor.age) if actor != null else str(out.get("stage", "adult"))
	out ["traits"] = _safe_dictionary(out.get("traits", {}))
	out ["lineage_pressure"] = _safe_dictionary(out.get("lineage_pressure", {}))
	out ["development_log"] = _safe_array(out.get("development_log", []))
	out ["updated_at_ms"] = int(Time.get_ticks_msec())

	var traits: Dictionary = _safe_dictionary(out.get("traits", {}))
	var repaired_traits: Dictionary = {}
	for raw_trait_id in traits.keys():
		var trait_id: String = _normalize_trait_id(str(raw_trait_id))
		if trait_id == "":
			continue
		var trait_contract: Dictionary = _safe_dictionary(traits.get(raw_trait_id, {}))
		if trait_contract.is_empty():
			continue
		trait_contract ["trait_id"] = trait_id
		trait_contract ["display_name"] = str(trait_contract.get("display_name", _trait_display_name(trait_id)))
		trait_contract ["stage"] = str(trait_contract.get("stage", out ["stage"]))
		trait_contract ["intensity"] = clamp(float(trait_contract.get("intensity", 0.0)), 0.0, float(trait_contract.get("cap", 100.0)))
		trait_contract ["state"] = _trait_state_for_intensity(float(trait_contract.get("intensity", 0.0)))
		repaired_traits [trait_id] = trait_contract
	out ["traits"] = repaired_traits

	return out


func _repair_state() -> void:
	var repaired_profiles: Dictionary = {}

	for raw_key in actor_trait_profiles.keys():
		var profile: Dictionary = _safe_dictionary(actor_trait_profiles.get(raw_key, {}))
		if profile.is_empty():
			continue

		var actor_id: int = int(profile.get("actor_id", int(str(raw_key))))
		if actor_id <= 0:
			continue

		var actor: Person = _actor_by_id(actor_id)
		repaired_profiles [str(actor_id)] = _normalize_actor_trait_profile(actor, profile)

	actor_trait_profiles = repaired_profiles

	if trait_event_ledger.size() > MAX_TRAIT_EVENT_LEDGER:
		trait_event_ledger = trait_event_ledger.slice(trait_event_ledger.size() - MAX_TRAIT_EVENT_LEDGER, trait_event_ledger.size())


func _commit_state() -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	gs.scenario_state ["traits_actor_profiles"] = actor_trait_profiles.duplicate(true)
	gs.scenario_state ["traits_event_ledger"] = trait_event_ledger.duplicate(true)
	gs.scenario_state ["traits_catalog_version"] = trait_catalog_version


func _trait_event_contract(actor: Person, before_profile: Dictionary, after_profile: Dictionary, trait_delta: Dictionary, source_contract: Dictionary, option: Dictionary, evolution_report: Dictionary, context: Dictionary = {}) -> Dictionary:
	var event_id: String = "trait_event_%d_%s_%d" % [
		int(actor.id) if actor != null else -1,
		str(option.get("id", "choice")),
		int(Time.get_ticks_msec())
	]

	return {
		"schema": TRAIT_EVENT_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": event_id,
		"contract_id": event_id,
		"actor_id": int(actor.id) if actor != null else -1,
		"actor_name": _actor_name(actor),
		"source_contract_id": str(source_contract.get("id", source_contract.get("contract_id", ""))),
		"source_request": str(source_contract.get("request", "")),
		"source_category": str(source_contract.get("category", "")),
		"option_id": str(option.get("id", "")),
		"option_label": str(option.get("label", "")),
		"trait_delta": trait_delta.duplicate(true),
		"before_profile": before_profile.duplicate(true),
		"after_profile": after_profile.duplicate(true),
		"evolution_report": evolution_report.duplicate(true),
		"context": context.duplicate(true),
		"created_year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec()),
		"contract_mesh": {
			"source_of_truth": "TraitsContractEngine",
			"identity_consumer": "IdentityContractEngine",
			"ui_mutation_allowed": false,
			"persistent": true,
			"save_key": "traits_event_ledger"
		}
	}


func _sync_legacy_person_traits(actor: Person, profile: Dictionary) -> void:
	if actor == null:
		return

	if typeof(actor.traits) != TYPE_ARRAY:
		actor.traits = []

	var traits: Dictionary = _safe_dictionary(profile.get("traits", {}))
	for raw_trait_id in traits.keys():
		var trait_id: String = _normalize_trait_id(str(raw_trait_id))
		var trait_contract: Dictionary = _safe_dictionary(traits.get(raw_trait_id, {}))
		if float(trait_contract.get("intensity", 0.0)) < 18.0:
			continue

		var display_name: String = _trait_display_name(trait_id)
		if display_name not in actor.traits:
			actor.traits.append(display_name)


func _selected_trait_ids_from_context(actor: Person, context: Dictionary = {}) -> Array:
	var out: Array = _safe_array(context.get("selected_trait_ids", []))
	if not out.is_empty():
		return out

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		var selected_by_actor: Dictionary = _safe_dictionary(gs.scenario_state.get("selected_trait_contracts_by_actor_id", {}))
		var actor_rows: Array = _safe_array(selected_by_actor.get(str(int(actor.id)), []))
		if not actor_rows.is_empty():
			return actor_rows

	if gs != null and typeof(gs.custom_settings) == TYPE_DICTIONARY:
		var selected_global: Array = _safe_array(gs.custom_settings.get("selected_trait_ids", []))
		if not selected_global.is_empty() and actor != null and gs.player != null and int(actor.id) == int(gs.player.id):
			return selected_global

	return out


func _legacy_trait_to_living_trait_id(raw_trait: String) -> String:
	var text: String = str(raw_trait).strip_edges().to_lower()
	if text.find("paranoid") >= 0:
		return "guarded"
	if text.find("genius") >= 0 or text.find("logical") >= 0:
		return "calculated"
	if text.find("loyal") >= 0 or text.find("kind") >= 0:
		return "loyal"
	if text.find("jealous") >= 0:
		return "competitive"
	if text.find("religious") >= 0:
		return "disciplined"
	return _normalize_trait_id(text)


func _environment_pressure_summary(inherited: Dictionary) -> Dictionary:
	return {
		"fear_pressure": float(inherited.get("anxious", 0.0)) + float(inherited.get("guarded", 0.0)),
		"achievement_pressure": float(inherited.get("ambitious", 0.0)) + float(inherited.get("perfectionist", 0.0)),
		"attachment_pressure": float(inherited.get("loyal", 0.0)) + float(inherited.get("people_pleaser", 0.0)),
		"resentment_pressure": float(inherited.get("bitter", 0.0)) + float(inherited.get("competitive", 0.0))
	}


func _opposite_trait_for_pressure(trait_id: String) -> String:
	match _normalize_trait_id(trait_id):
		"anxious":
			return "bold"
		"guarded":
			return "compassionate"
		"bitter":
			return "loyal"
		"rebellious":
			return "disciplined"
		"people_pleaser":
			return "independent"
		"perfectionist":
			return "mischievous"
		_:
			return ""


func _seed_pool_for_stage(stage: String) -> Array:
	match str(stage).strip_edges().to_lower():
		"infancy":
			return ["curious", "charming", "anxious", "bold"]
		"childhood":
			return ["curious", "mischievous", "charming", "compassionate", "bold", "disciplined"]
		"teen":
			return ["mischievous", "rebellious", "charming", "competitive", "guarded", "ambitious", "disciplined"]
		"elder":
			return ["disciplined", "guarded", "loyal", "strategic", "compassionate", "bitter"]
		_:
			return ["charming", "disciplined", "loyal", "guarded", "ambitious", "curious", "compassionate", "bold"]


func _desired_seed_trait_count_for_age(age: int) -> int:
	if age <= 0:
		return 1
	if age < 5:
		return 2
	if age < 13:
		return 3
	if age < 20:
		return 4
	if age < 60:
		return 5
	return 6


func _stage_for_age(age_value: int) -> String:
	var age: int = int(age_value)
	if age <= 1:
		return "infancy"
	if age < 13:
		return "childhood"
	if age < 20:
		return "teen"
	if age < 60:
		return "adult"
	return "elder"


func _trait_stage_cap(_trait_id: String, stage: String, trait_contract: Dictionary = {}) -> float:
	var selected_seed: bool = bool(trait_contract.get("selected_seed", false))
	var bonus: float = 5.0 if selected_seed else 0.0

	match str(stage).strip_edges().to_lower():
		"infancy":
			return 25.0 + bonus
		"childhood":
			return 50.0 + bonus
		"teen":
			return 80.0 + bonus
		"elder":
			return 92.0 + bonus
		_:
			return 100.0


func _selected_trait_start_intensity(stage: String) -> float:
	match str(stage).strip_edges().to_lower():
		"infancy":
			return 12.0
		"childhood":
			return 22.0
		"teen":
			return 30.0
		_:
			return 35.0


func _legacy_trait_start_intensity(stage: String) -> float:
	match str(stage).strip_edges().to_lower():
		"infancy":
			return 6.0
		"childhood":
			return 16.0
		"teen":
			return 24.0
		_:
			return 32.0


func _natural_seed_intensity(stage: String) -> float:
	match str(stage).strip_edges().to_lower():
		"infancy":
			return 4.0
		"childhood":
			return 10.0
		"teen":
			return 16.0
		_:
			return 22.0


func _lineage_start_cap(stage: String) -> float:
	match str(stage).strip_edges().to_lower():
		"infancy":
			return 10.0
		"childhood":
			return 18.0
		"teen":
			return 24.0
		_:
			return 30.0


func _trait_decay_rate(trait_id: String) -> float:
	var definition: Dictionary = _safe_dictionary(_trait_catalog().get(_normalize_trait_id(trait_id), {}))
	return float(definition.get("decay", 0.45))


func _trait_state_for_intensity(intensity: float) -> String:
	if intensity <= 0.0:
		return "erased"
	if intensity < 8.0:
		return "dormant"
	if intensity < 30.0:
		return "forming"
	if intensity < 65.0:
		return "active"
	if intensity < 90.0:
		return "dominant"
	return "legacy_defining"


func _trait_intensity(traits: Dictionary, trait_id: String) -> float:
	var trait_contract: Dictionary = _safe_dictionary(traits.get(_normalize_trait_id(trait_id), {}))
	return float(trait_contract.get("intensity", 0.0))


func _merge_trait_delta(into: Dictionary, delta: Dictionary) -> void:
	if typeof(into) != TYPE_DICTIONARY or typeof(delta) != TYPE_DICTIONARY:
		return

	for raw_key in delta.keys():
		var trait_id: String = _normalize_trait_id(str(raw_key))
		if trait_id == "":
			continue
		into [trait_id] = float(into.get(trait_id, 0.0)) + float(delta.get(raw_key, 0.0))


func _clean_trait_delta(delta: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for raw_key in delta.keys():
		var trait_id: String = _normalize_trait_id(str(raw_key))
		var value: float = float(delta.get(raw_key, 0.0))
		if trait_id == "" or abs(value) < 0.01:
			continue
		out [trait_id] = value
	return out


func _normalize_trait_id(value: String) -> String:
	var out: String = str(value).strip_edges().to_lower()
	out = out.replace(" ", "_")
	out = out.replace("-", "_")
	out = out.replace("__", "_")
	return out


func _trait_display_name(trait_id: String) -> String:
	var definition: Dictionary = _safe_dictionary(_trait_catalog().get(_normalize_trait_id(trait_id), {}))
	var defined_name: String = str(definition.get("name", "")).strip_edges()
	if defined_name != "":
		return defined_name
	return _normalize_trait_id(trait_id).replace("_", " ").capitalize()


func _option_id_exists(options: Array, option_id: String) -> bool:
	for raw_option in options:
		if typeof(raw_option) != TYPE_DICTIONARY:
			continue
		if str((raw_option as Dictionary).get("id", "")).strip_edges() == option_id:
			return true
	return false


func _actor_by_id(actor_id: int) -> Person:
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


func _actor_name(actor: Person) -> String:
	if actor == null:
		return "Unknown"
	var full_name: String = ("%s %s" % [str(actor.first_name), str(actor.last_name)]).strip_edges()
	if full_name != "":
		return full_name
	return str(actor.name).strip_edges()


func _current_year() -> int:
	if gs == null:
		return 0
	return int(gs.year)


func _seeded_unit(seed_text: String) -> float:
	var seed_value: int = abs(hash(seed_text))
	return float(seed_value % 10000) / 10000.0


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(value: Variant) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return (value as Array).duplicate(true)
	return []