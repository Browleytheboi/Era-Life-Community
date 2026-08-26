extends Resource
class_name SuperHeroEngine

const CONTRACT_SCHEMA:= "eralife.superhero_engine_contract"
const CONTRACT_VERSION:= 1
const STATE_SCHEMA:= "eralife.superhero_engine_state"
const STATE_KEY:= "superhero_engine_state"
const MAX_HERO_EVENT_LEDGER:= 220

var gs
var active_contract: Dictionary = {}
var last_hero_report: Dictionary = {}

func _init(_gs = null, contract: Dictionary = {}) -> void:
	gs = _gs
	set_contract(contract)

func set_contract(contract: Dictionary = {}) -> Dictionary:
	active_contract = _default_contract()
	if typeof(contract) == TYPE_DICTIONARY and not contract.is_empty():
		active_contract = _merge_dict(active_contract, contract)

	return {
		"success": true,
		"schema": "eralife.superhero_contract_set_report",
		"version": CONTRACT_VERSION,
		"contract_id": str(active_contract.get("id", "superhero_engine.default")),
		"updated_at_ms": int(Time.get_ticks_msec())
	}

func export_state() -> Dictionary:
	return {
		"schema": STATE_SCHEMA,
		"version": CONTRACT_VERSION,
		"save_key": STATE_KEY,
		"persistent": true,
		"backwards_compatible": true,
		"preserve_unknown_fields": true,
		"active_contract": active_contract.duplicate(true),
		"world_state": _world_state().duplicate(true),
		"last_hero_report": last_hero_report.duplicate(true),
		"exported_at_ms": int(Time.get_ticks_msec())
	}

func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "SuperHeroEngine import_state expected Dictionary."
		}

	var contract_raw: Variant = data.get("active_contract", {})
	if typeof(contract_raw) == TYPE_DICTIONARY:
		active_contract = _merge_dict(_default_contract(), contract_raw as Dictionary)
	else:
		active_contract = _default_contract()

	var world_state_raw: Variant = data.get("world_state", {})
	if typeof(world_state_raw) == TYPE_DICTIONARY:
		_commit_world_state(_normalize_state(world_state_raw as Dictionary))

	var report_raw: Variant = data.get("last_hero_report", {})
	if typeof(report_raw) == TYPE_DICTIONARY:
		last_hero_report = (report_raw as Dictionary).duplicate(true)

	return {
		"success": true,
		"schema": "eralife.superhero_import_report",
		"version": CONTRACT_VERSION,
		"imported_at_ms": int(Time.get_ticks_msec())
	}

func bootstrap_world_supers(people: Array) -> Dictionary:
	var hero_candidates: int = 0
	var villain_candidates: int = 0

	for raw_person in people:
		if not (raw_person is Person):
			continue

		var person: Person = raw_person
		if gs.power_engine == null or not gs.power_engine.has_method("has_superpowers"):
			continue
		if not gs.power_engine.has_superpowers(person):
			continue

		hero_candidates += 1
		if randf() <= 0.18:
			_register_villain_seed(person, {
				"source": "bootstrap_world_supers"
			})
			villain_candidates += 1

	var state: Dictionary = _world_state()
	state ["last_bootstrap_report"] = {
		"success": true,
		"hero_candidates": hero_candidates,
		"villain_candidates": villain_candidates,
		"year": _current_year(),
		"updated_at_ms": int(Time.get_ticks_msec())
	}
	_commit_world_state(state)

	return state ["last_bootstrap_report"].duplicate(true)

func apply_birth_settings(actor: Person, settings: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "Actor missing."
		}
	if typeof(settings) != TYPE_DICTIONARY:
		settings = {}

	var sandbox_config: Dictionary = {}
	var sandbox_raw: Variant = settings.get("superpower_configurator", null)
	if typeof(sandbox_raw) == TYPE_DICTIONARY:
		sandbox_config = (sandbox_raw as Dictionary).duplicate(true)

	var path: String = str(settings.get("superhero_identity_path", "")).strip_edges().to_lower()
	var public_identity: String = str(sandbox_config.get("public_identity", "")).strip_edges().to_lower()
	var scope_id: String = str(sandbox_config.get("scope", "only_me")).strip_edges().to_lower()

	if public_identity == "government_experiment":
		scope_id = "whole_family" if scope_id in ["whole_family", "my_bloodline"] else "only_me"
		sandbox_config ["scope"] = scope_id
		sandbox_config ["origin"] = "experiment_surgery"

	if path == "" and public_identity == "":
		return {
			"success": true,
			"skipped": true
		}

	var profile: Dictionary = ensure_hero_profile(actor)
	profile ["public_identity"] = public_identity
	profile ["birth_identity_source"] = "superpower_sandbox"

	if path != "":
		profile ["alignment"] = "villain" if path == "villain" else "hero"
	elif public_identity == "registered_hero":
		profile ["alignment"] = "hero"
	elif public_identity == "wanted_villain":
		profile ["alignment"] = "villain"

	match public_identity:
		"registered_hero":
			profile ["registration_status"] = "registered_at_birth"
			profile ["hero_expectation"] = true
			profile ["public_trust"] = max(int(profile.get("public_trust", 50)), 58)
			profile ["legal_risk"] = max(0, int(profile.get("legal_risk", 0)) - 12)
		"government_experiment":
			profile ["registration_status"] = "government_file"
			profile ["government_file"] = true
			profile ["experiment_subject"] = true
			profile ["hero_expectation"] = false
			profile ["legal_risk"] = max(int(profile.get("legal_risk", 0)), 18)
		"wanted_villain":
			profile ["registration_status"] = "wanted"
		"rumored":
			profile ["registration_status"] = "rumored"
			profile ["exposure_susceptibility"] = max(float(profile.get("exposure_susceptibility", 0.0)), 0.42)
		"secret":
			profile ["registration_status"] = "unregistered_secret"
			profile ["exposure_susceptibility"] = max(float(profile.get("exposure_susceptibility", 0.0)), 0.22)
		_:
			if str(profile.get("registration_status", "")).strip_edges() == "":
				profile ["registration_status"] = "unregistered"

	profile ["public_alias"] = str(settings.get("superhero_alias", profile.get("public_alias", ""))).strip_edges()

	if not sandbox_config.is_empty():
		profile ["birth_power_configured"] = true
		profile ["birth_power_rarity"] = str(sandbox_config.get("rarity", "rare"))
		profile ["family_power_scope"] = scope_id
		profile ["family_exposure_chain"] = scope_id in ["whole_family", "my_bloodline"]
		profile ["family_power_identity_style"] = "public_legacy" if public_identity == "registered_hero" else "private_household"

		if public_identity == "government_experiment":
			profile ["family_power_identity_style"] = "contained_file" if scope_id in ["whole_family", "my_bloodline"] else "isolated_subject"

	_append_superhero_birth_identity_memory(actor, public_identity, scope_id)
	_commit_profile(actor, profile)

	return {
		"success": true,
		"actor_id": int(actor.id),
		"path": path,
		"public_identity": public_identity,
		"scope": scope_id,
		"registration_status": str(profile.get("registration_status", "unregistered"))
	}

func ensure_hero_profile(actor: Person) -> Dictionary:
	if actor == null:
		return {}

	var state: Dictionary = _world_state()
	var profiles: Dictionary = _safe_dictionary(state.get("hero_profiles", {}))
	var key: String = _person_key(actor)
	var profile: Dictionary = _safe_dictionary(profiles.get(key, {}))

	if profile.is_empty():
		profile = {
			"schema": "eralife.superhero_profile",
			"version": CONTRACT_VERSION,
			"person_id": int(actor.id),
			"person_name": _person_label(actor),
			"public_alias": "",
			"alignment": "civilian",
			"registration_status": "unregistered",
			"public_identity": "",
			"birth_identity_source": "",
			"hero_rank": "unknown",
			"hero_rep": 0,
			"public_trust": 50,
			"rescues": 0,
			"crimes_stopped": 0,
			"villains_defeated": 0,
			"losses": 0,
			"draws": 0,
			"legal_risk": 0,
			"exposure_susceptibility": 0.0,
			"family_exposure_chain": false,
			"government_file": false,
			"experiment_subject": false,
			"hero_expectation": false,
			"agency_id": "",
			"agency_name": "",
			"agency_alignment": "",
			"agency_joined_year": 0,
			"agency_leader_name": "",
			"agency_leader_power_level": 0,
			"active_disguise_id": "",
			"active_disguise_name": "",
			"team_id": "",
			"team_role": "",
			"unlocked_team_creation": false,
			"birth_power_configured": false,
			"birth_power_rarity": "",
			"family_power_scope": "",
			"family_power_identity_style": "",
			"created_year": _current_year(),
			"updated_year": _current_year()
		}

	var defaults: Dictionary = {
		"registration_status": "unregistered",
		"public_identity": "",
		"birth_identity_source": "",
		"losses": 0,
		"draws": 0,
		"legal_risk": 0,
		"exposure_susceptibility": 0.0,
		"family_exposure_chain": false,
		"government_file": false,
		"experiment_subject": false,
		"hero_expectation": false,
		"agency_id": "",
		"agency_name": "",
		"agency_alignment": "",
		"agency_joined_year": 0,
		"agency_leader_name": "",
		"agency_leader_power_level": 0,
		"active_disguise_id": "",
		"active_disguise_name": "",
		"birth_power_configured": false,
		"birth_power_rarity": "",
		"family_power_scope": "",
		"family_power_identity_style": ""
	}

	for raw_key in defaults.keys():
		var clean_key: String = str(raw_key)
		if not profile.has(clean_key):
			profile [clean_key] = defaults.get(clean_key)

	profile ["person_id"] = int(actor.id)
	profile ["person_name"] = _person_label(actor)
	profile ["updated_year"] = _current_year()

	profiles [key] = profile.duplicate(true)
	state ["hero_profiles"] = profiles
	_commit_world_state(state)

	return profile.duplicate(true)
func resolve_hub_action(actor: Person, payload: Dictionary = {}) -> Dictionary:
	var action: String = str(payload.get("action", payload.get("hero_action", ""))).strip_edges().to_lower()
	match action:
		"choose_disguise", "set_disguise", "wear_disguise":
			return _choose_super_disguise(actor, payload)
		"registration_update_file", "registration_request_clearance", "registration_show_credentials":
			return _resolve_registered_identity_action(actor, payload)
		"meet_agency_leader", "agency_leader":
			return _resolve_agency_leader_interaction(actor, payload)
		"patrol_city":
			return patrol_city(actor, payload)
		"respond_to_crime":
			return respond_to_crime(actor, payload)
		"track_villain":
			return track_villain(actor, payload)
		"resolve_villain_encounter_choice":
			return resolve_villain_encounter_choice(actor, payload)
		"resolve_power_battle_action":
			return resolve_power_battle_action(actor, payload)
		"train_powers":
			if gs != null and gs.power_engine != null and gs.power_engine.has_method("train_power"):
				return gs.power_engine.train_power(actor, payload)
			return { "success": false, "reason": "PowerEngine unavailable."}
		"register_identity":
			return register_powered_identity(actor, payload)
		"join_agency":
			return join_hero_agency(actor, payload)
		"start_team":
			return start_team(actor, payload)
		"recruit_ally":
			return recruit_ally(actor, payload)
		"search_team_candidate":
			return search_team_candidate(actor, payload)
		"accept_team_candidate":
			return accept_team_candidate(actor, payload)
		"interview_team_candidate":
			return interview_team_candidate(actor, payload)
		"watch_live_events":
			return watch_live_events(actor, payload)
		"become_hero":
			return become_hero(actor, payload)
		"become_villain":
			if gs != null and gs.infamy_engine != null and gs.infamy_engine.has_method("become_villain"):
				var villain_report: Dictionary = gs.infamy_engine.become_villain(actor, payload)
				var profile: Dictionary = ensure_hero_profile(actor)
				profile ["alignment"] = "villain"
				_commit_profile(actor, profile)
				return villain_report
			return { "success": false, "reason": "InfamyEngine unavailable."}
		_:
			return {
				"success": false,
				"reason": "Unknown superhero hub action.",
				"action": action
			}
func become_hero(actor: Person, payload: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "Actor missing."
		}

	var profile: Dictionary = ensure_hero_profile(actor)
	profile ["alignment"] = "hero"
	profile ["hub_unlocked"] = true
	profile ["hero_origin"] = str(payload.get("source", "hero_identity_choice"))

	var had_superpowers: bool = false
	if gs != null and gs.power_engine != null and gs.power_engine.has_method("has_superpowers"):
		had_superpowers = gs.power_engine.has_superpowers(actor)

	var bending_bridge_report: Dictionary = {}
	if not had_superpowers and bool(payload.get("allow_bending_power_source", false)):
		if gs != null and gs.power_engine != null and gs.power_engine.has_method("grant_bending_as_superpower"):
			bending_bridge_report = gs.power_engine.grant_bending_as_superpower(actor, {
				"source": "become_superhero_activity",
				"visibility": "public" if bool(payload.get("public_launch", true)) else "secret",
				"hero_identity": true,
			})

	var alias_name: String = str(payload.get("alias", "")).strip_edges()
	if alias_name == "":
		alias_name = str(profile.get("public_alias", "")).strip_edges()
	if alias_name == "":
		alias_name = "%s Prime" % _person_label(actor)

	profile ["public_alias"] = alias_name
	profile ["hero_rank"] = "local"
	profile ["registration_status"] = str(profile.get("registration_status", "unregistered"))
	if str(profile.get("registration_status", "unregistered")) in ["", "unknown"]:
		profile ["registration_status"] = "unregistered"
	_commit_profile(actor, profile)

	var bridge_text: String = ""
	if bool(bending_bridge_report.get("success", false)):
		bridge_text = "\n\nMy bending is now being read by the SuperHero system as my active power source."

	return {
		"success": true,
		"schema": "eralife.hero_identity_report",
		"person_id": int(actor.id),
		"alias": alias_name,
		"bending_power_bridge": bending_bridge_report.duplicate(true),
		"text": "I stepped into the public eye as %s.%s" % [
			alias_name,
			bridge_text
		],
		"popup_title": "Super Hero Identity",
		"popup_text": "You became a super hero as %s.%s" % [
			alias_name,
			bridge_text
		],
		"popup_footer": "The Super Hero Hub is now available."
	}

func patrol_city(actor: Person, payload: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "Actor missing."
		}
	if not _actor_can_super(actor):
		return {
			"success": false,
			"reason": "You need powers before the Super Hero Hub can route patrol consequences."
		}

	var profile: Dictionary = ensure_hero_profile(actor)
	if str(profile.get("alignment", "civilian")) == "civilian":
		profile ["alignment"] = "hero"

	var found_crime: bool = randf() <= 0.72
	if found_crime:
		_commit_profile(actor, profile)
		var patrol_payload: Dictionary = payload.duplicate(true)
		patrol_payload ["source"] = str(patrol_payload.get("source", "patrol_city"))
		patrol_payload ["crime_surface_mode"] = "patrol"
		return respond_to_crime(actor, patrol_payload)

	profile ["hero_rep"] = int(profile.get("hero_rep", 0)) + 1
	profile ["public_trust"] = clamp(int(profile.get("public_trust", 50)) + 1, 0, 100)
	_commit_profile(actor, profile)

	var report: Dictionary = {
		"success": true,
		"schema": "eralife.hero_patrol_report",
		"person_id": int(actor.id),
		"text": "You patrol the city. Nothing explodes this time, which somehow feels suspicious.",
		"popup_title": "Patrol Complete",
		"popup_text": "You patrol the city.\n\nNothing explodes this time, which somehow feels suspicious.",
		"popup_footer": "No active crime surfaced this pass.",
		"hero_rep": int(profile.get("hero_rep", 0)),
		"public_trust": int(profile.get("public_trust", 50))
	}
	_record_hero_event(report)
	return report


func respond_to_crime(actor: Person, payload: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "Actor missing."
		}
	if not _actor_can_super(actor):
		return {
			"success": false,
			"reason": "You need powers before responding to powered crime."
		}

	var villain: Person = _resolve_or_create_villain(payload)
	if villain == null:
		return {
			"success": false,
			"reason": "No villain could be surfaced.",
			"popup_title": "No Active Crime",
			"popup_text": "You listen for emergency signals, but nothing stable enough surfaces.",
			"popup_footer": "The city is quiet. Suspiciously quiet."
		}

	var crime_context: Dictionary = _build_superhero_crime_context(villain, "respond_to_crime", payload)
	var encounter_result: Dictionary = _build_villain_encounter_result(actor, villain, crime_context, {
		"battle_type": "crime_response",
		"stakes": str(payload.get("stakes", crime_context.get("stakes", "city_block"))),
		"public": true
	})

	return _build_superhero_search_result(actor, "respond_to_crime", villain, crime_context, encounter_result, {})


func track_villain(actor: Person, payload: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "Actor missing."
		}
	if not _actor_can_super(actor):
		return {
			"success": false,
			"reason": "You need powers before tracking powered villains."
		}

	var causality_report: Dictionary = {}
	if gs != null and gs.has_method("resolve_causality_inverted_intent") and not bool(payload.get("_cie_skip", false)):
		causality_report = gs.resolve_causality_inverted_intent(actor, {
			"action_id": "track_villain",
			"domain": "villains",
			"payload": payload.duplicate(true),
			"resolution_strategy": str(payload.get("resolution_strategy", "generate_if_missing")),
			"constraint_weights": payload.get("constraint_weights", {
				"world_density": 0.7,
				"timeline_plausibility": 0.9,
				"player_power_level": 0.8,
				"recent_activity_bias": 0.6
			}),
			"generation_policy": payload.get("generation_policy", {
				"allow_generation": true,
				"historical_backfill_depth": 3,
				"conflict_probability": 0.35
			})
		}, {
			"source": "superhero_engine.track_villain",
			"remote_truth_layer": false
		})

	var villain: Person = null
	if not causality_report.is_empty():
		var canonical_truth: Dictionary = _safe_dictionary(causality_report.get("canonical_truth", {}))
		var entity: Dictionary = _safe_dictionary(canonical_truth.get("canonical_entity", {}))
		var villain_id: int = int(entity.get("person_id", -1))
		if villain_id > 0:
			villain = _person_by_id(villain_id)

	if villain == null:
		villain = _resolve_or_create_villain(payload)

	if villain == null:
		return {
			"success": false,
			"reason": "No villain trail found.",
			"causality_inversion": causality_report.duplicate(true),
			"popup_title": "No Villain Trail",
			"popup_text": "You track the signal, but the trail collapses before reality can bind a villain to it.",
			"popup_footer": "CIE could not stabilize this encounter."
		}

	var profile: Dictionary = ensure_hero_profile(actor)
	profile ["hero_rep"] = int(profile.get("hero_rep", 0)) + 2
	_commit_profile(actor, profile)

	var crime_context: Dictionary = _build_superhero_crime_context(villain, "track_villain", payload)
	var encounter_result: Dictionary = _build_villain_encounter_result(actor, villain, crime_context, {
		"battle_type": "villain_tracking",
		"stakes": str(payload.get("stakes", crime_context.get("stakes", "city_block"))),
		"public": true,
		"causality_inversion": causality_report.duplicate(true)
	})

	return _build_superhero_search_result(actor, "track_villain", villain, crime_context, encounter_result, causality_report)

func start_team(actor: Person, payload: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "Actor missing."
		}

	var profile: Dictionary = ensure_hero_profile(actor)
	var existing_team_id: String = str(profile.get("team_id", "")).strip_edges()
	if existing_team_id != "":
		return {
			"success": true,
			"schema": "eralife.hero_team_existing_report",
			"team_id": existing_team_id,
			"text": "You already have a team.",
			"popup_title": "Team Already Active",
			"popup_text": "You already have a team.\n\nOpen My Team to recruit heroes, villains, benders, and powered weirdos from your era.",
			"popup_footer": "The My Team section is now your team command center."
		}

	var hero_rep: int = int(profile.get("hero_rep", 0))
	var villains_defeated: int = int(profile.get("villains_defeated", 0))
	if hero_rep < 40 and villains_defeated < 3 and not bool(payload.get("force", false)):
		return {
			"success": false,
			"reason": "You need more reputation or villain wins before founding a team.",
			"required": "Hero Rep 40 or 3 villains defeated.",
			"popup_title": "Team Not Ready",
			"popup_text": "You need Hero Rep 40 or 3 villains defeated before founding a full crime fighting team.",
			"popup_footer": "Keep fighting crime or force this through God/chaos settings."
		}

	var team_type: String = str(payload.get("team_type", "crime_fighting_team")).strip_edges().to_lower()
	if team_type == "":
		team_type = "crime_fighting_team"

	var state: Dictionary = _world_state()
	var teams: Dictionary = _safe_dictionary(state.get("hero_teams", {}))
	var team_id: String = "hero_team_%d_%d" % [int(actor.id), int(Time.get_ticks_msec())]
	var team_name: String = str(payload.get("team_name", "")).strip_edges()
	if team_name == "":
		match team_type:
			"street_level":
				team_name = "%s Street Watch" % _person_label(actor)
			"world_savers":
				team_name = "%s Worldguard" % _person_label(actor)
			"shadow_ops":
				team_name = "%s Shadow Cell" % _person_label(actor)
			"bender_league":
				team_name = "%s Element League" % _person_label(actor)
			"villain_reform":
				team_name = "%s Redemption Pact" % _person_label(actor)
			_:
				team_name = "%s Initiative" % _person_label(actor)

	teams [team_id] = {
		"schema": "eralife.hero_team",
		"version": CONTRACT_VERSION,
		"id": team_id,
		"name": team_name,
		"team_type": team_type,
		"founder_id": int(actor.id),
		"member_ids": [int(actor.id)],
		"team_rep": hero_rep,
		"created_year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	profile ["team_id"] = team_id
	profile ["team_role"] = "founder"
	profile ["unlocked_team_creation"] = true
	state ["hero_teams"] = teams
	_commit_world_state(state)
	_commit_profile(actor, profile)

	return {
		"success": true,
		"schema": "eralife.hero_team_created_report",
		"team_id": team_id,
		"team_name": team_name,
		"team_type": team_type,
		"text": "You create %s. This is no longer one person in a costume. This is an organization." % team_name,
		"popup_title": "Team Created",
		"popup_text": "You create %s.\n\nThis is no longer one person in a costume. This is an organization.\n\nThe My Team section is now available." % team_name,
		"popup_footer": "Recruitment can now search heroes, villains, benders, and powered NPCs from your era."
	}
func recruit_ally(actor: Person, payload: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "Actor missing."
		}

	var profile: Dictionary = ensure_hero_profile(actor)
	var team_id: String = str(profile.get("team_id", "")).strip_edges()

	if team_id == "":
		return {
			"success": false,
			"reason": "Create a crime fighting team before recruiting a sidekick.",
			"popup_title": "No Team Yet",
			"popup_text": "Create a crime fighting team before recruiting a sidekick."
		}

	var causality_report: Dictionary = {}
	if gs != null and gs.has_method("resolve_causality_inverted_intent") and not bool(payload.get("_cie_skip", false)):
		causality_report = gs.resolve_causality_inverted_intent(actor, {
			"action_id": "recruit_ally",
			"domain": "sidekicks",
			"payload": payload.duplicate(true),
			"resolution_strategy": "generate_if_missing"
		}, {
			"source": "superhero_engine.recruit_ally",
			"remote_truth_layer": false
		})

	var ally: Person = null
	if not causality_report.is_empty():
		var canonical_truth: Dictionary = _safe_dictionary(causality_report.get("canonical_truth", {}))
		var entity: Dictionary = _safe_dictionary(canonical_truth.get("canonical_entity", {}))
		var ally_id: int = int(entity.get("person_id", -1))
		if ally_id > 0:
			ally = _person_by_id(ally_id)

	if ally == null:
		ally = _resolve_or_create_sidekick_recruit(actor, payload)

	if ally == null:
		return {
			"success": false,
			"reason": "No powered sidekick was willing to join right now.",
			"causality_inversion": causality_report.duplicate(true)
		}

	var state: Dictionary = _world_state()
	var teams: Dictionary = _safe_dictionary(state.get("hero_teams", {}))
	var team: Dictionary = _safe_dictionary(teams.get(team_id, {}))
	var member_ids: Array = _safe_array(team.get("member_ids", []))

	if int(ally.id) not in member_ids:
		member_ids.append(int(ally.id))

	team ["member_ids"] = member_ids
	team ["team_rep"] = int(team.get("team_rep", 0)) + 6
	teams [team_id] = team
	state ["hero_teams"] = teams
	_commit_world_state(state)

	var report: Dictionary = {
		"success": true,
		"schema": "eralife.hero_sidekick_recruit_report",
		"team_id": team_id,
		"ally_id": int(ally.id),
		"ally_name": _person_label(ally),
		"sidekick": true,
		"causality_inversion": causality_report.duplicate(true),
		"causal_justification": _safe_dictionary(causality_report.get("cje", {})),
		"text": "%s joins the team as your sidekick." % _person_label(ally),
		"popup_title": "Sidekick Recruited",
		"popup_text": "%s joins the team as your sidekick." % _person_label(ally),
		"popup_footer": "CIE made their arrival feel pre-existing instead of reactive."
	}

	_record_hero_event(report)
	return report
func search_team_candidate(actor: Person, payload: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "Actor missing."
		}

	var profile: Dictionary = ensure_hero_profile(actor)
	var team_id: String = str(profile.get("team_id", "")).strip_edges()
	if team_id == "":
		return {
			"success": false,
			"popup_title": "No Team Yet",
			"popup_text": "Create a team before searching for recruits.",
			"popup_footer": "Team recruitment requires an active team."
		}

	var candidate_alignment: String = str(payload.get("candidate_alignment", "hero")).strip_edges().to_lower()
	var candidate: Person = null
	if candidate_alignment == "villain":
		candidate = _resolve_or_create_villain({
			"source": "team_candidate_search",
			"resolution_strategy": "force_generate" if bool(payload.get("force_new", false)) else "generate_if_missing"
		})
	else:
		candidate = _resolve_or_create_sidekick_recruit(actor, {
			"source": "team_candidate_search",
			"public": true
		})

	if candidate == null:
		return {
			"success": false,
			"popup_title": "No Candidate Found",
			"popup_text": "The search comes back empty.",
			"popup_footer": "Try again after the world has more powered pressure."
		}

	var overview_lines: Array = _team_candidate_overview_lines(candidate, candidate_alignment)
	var popup_text: String = "\n".join(overview_lines)

	return {
		"success": true,
		"schema": "eralife.hero_team_candidate_report",
		"version": CONTRACT_VERSION,
		"team_id": team_id,
		"candidate_id": int(candidate.id),
		"candidate_name": _person_label(candidate),
		"candidate_alignment": candidate_alignment,
		"text": popup_text,
		"popup_title": "Recruitment Candidate",
		"popup_text": popup_text,
		"popup_footer": "Interview them, keep searching, or accept them instantly.",
		"choices": [
			{
				"label": "Interview Them",
				"detail_action": "engine_call",
				"engine_property": "superhero_engine",
				"method": "resolve_hub_action",
				"payload": {
					"action": "interview_team_candidate",
					"candidate_id": int(candidate.id),
					"candidate_alignment": candidate_alignment
				}
			},
			{
				"label": "Look For Someone Else",
				"detail_action": "engine_call",
				"engine_property": "superhero_engine",
				"method": "resolve_hub_action",
				"payload": {
					"action": "search_team_candidate",
					"candidate_alignment": candidate_alignment,
					"force_new": true
				}
			},
			{
				"label": "Accept Them Instantly",
				"detail_action": "engine_call",
				"engine_property": "superhero_engine",
				"method": "resolve_hub_action",
				"payload": {
					"action": "accept_team_candidate",
					"candidate_id": int(candidate.id),
					"candidate_alignment": candidate_alignment
				}
			}
		]
	}


func interview_team_candidate(actor: Person, payload: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "Actor missing."
		}

	var candidate: Person = _person_by_id(int(payload.get("candidate_id", -1)))
	if candidate == null:
		return {
			"success": false,
			"popup_title": "Candidate Missing",
			"popup_text": "That recruit is no longer available.",
			"popup_footer": "Search again to surface a new candidate."
		}

	var candidate_alignment: String = str(payload.get("candidate_alignment", "hero")).strip_edges().to_lower()
	var trust_read: int = clamp(int(candidate.willpower) + int(candidate.mental_health) + randi_range(-20, 20), 0, 220)
	var answer_text: String = "%s sits across from you.\n\nThey explain what they want, what they fear, and what kind of team they refuse to join.\n\nInterview Read: %d/220\n\n%s" % [
		_person_label(candidate),
		trust_read,
		"\n".join(_team_candidate_overview_lines(candidate, candidate_alignment))
	]

	return {
		"success": true,
		"schema": "eralife.hero_team_candidate_interview_report",
		"version": CONTRACT_VERSION,
		"candidate_id": int(candidate.id),
		"candidate_alignment": candidate_alignment,
		"interview_read": trust_read,
		"text": answer_text,
		"popup_title": "Recruitment Interview",
		"popup_text": answer_text,
		"popup_footer": "The interview can still become a recruit, a refusal, or a future rivalry.",
		"choices": [
			{
				"label": "Accept Them",
				"detail_action": "engine_call",
				"engine_property": "superhero_engine",
				"method": "resolve_hub_action",
				"payload": {
					"action": "accept_team_candidate",
					"candidate_id": int(candidate.id),
					"candidate_alignment": candidate_alignment
				}
			},
			{
				"label": "Pass For Now",
				"journal_text": "I passed on recruiting %s for now." % _person_label(candidate)
			}
		]
	}


func accept_team_candidate(actor: Person, payload: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "Actor missing."
		}

	var profile: Dictionary = ensure_hero_profile(actor)
	var team_id: String = str(profile.get("team_id", "")).strip_edges()
	if team_id == "":
		return {
			"success": false,
			"popup_title": "No Team Yet",
			"popup_text": "Create a team before accepting recruits.",
			"popup_footer": "Recruitment requires a team."
		}

	var candidate: Person = _person_by_id(int(payload.get("candidate_id", -1)))
	if candidate == null:
		return {
			"success": false,
			"popup_title": "Candidate Missing",
			"popup_text": "That recruit is no longer available.",
			"popup_footer": "Search again to surface a new candidate."
		}

	var state: Dictionary = _world_state()
	var teams: Dictionary = _safe_dictionary(state.get("hero_teams", {}))
	var team: Dictionary = _safe_dictionary(teams.get(team_id, {}))
	var member_ids: Array = _safe_array(team.get("member_ids", []))
	if int(candidate.id) not in member_ids:
		member_ids.append(int(candidate.id))

	team ["member_ids"] = member_ids
	team ["team_rep"] = int(team.get("team_rep", 0)) + 6
	teams [team_id] = team
	state ["hero_teams"] = teams
	_commit_world_state(state)

	var candidate_profile: Dictionary = ensure_hero_profile(candidate)
	candidate_profile ["team_id"] = team_id
	candidate_profile ["team_role"] = "member"
	candidate_profile ["alignment"] = str(payload.get("candidate_alignment", candidate_profile.get("alignment", "hero")))
	_commit_profile(candidate, candidate_profile)

	var text: String = "%s joins %s.\n\nThe team is no longer just an idea. It has another will inside it now." % [
		_person_label(candidate),
		str(team.get("name", "your team"))
	]

	var report: Dictionary = {
		"success": true,
		"schema": "eralife.hero_team_candidate_accepted_report",
		"version": CONTRACT_VERSION,
		"team_id": team_id,
		"candidate_id": int(candidate.id),
		"candidate_name": _person_label(candidate),
		"text": text,
		"popup_title": "Recruit Accepted",
		"popup_text": text,
		"popup_footer": "My Team updated."
	}
	_record_hero_event(report)
	return report


func _team_candidate_overview_lines(candidate: Person, candidate_alignment: String = "hero") -> Array:
	var profile: Dictionary = ensure_hero_profile(candidate)
	var fighting_record: String = "%d-%d-%d" % [
		int(profile.get("villains_defeated", 0)),
		int(profile.get("losses", 0)),
		int(profile.get("draws", 0))
	]

	return [
		"Name: %s" % _person_label(candidate),
		"Gender: %s" % str(candidate.gender),
		"Alignment Read: %s" % candidate_alignment.capitalize(),
		"Fighting Record: %s" % fighting_record,
		"Power Level: %d" % _power_rating(candidate),
		"Abilities: %s" % _power_line(candidate),
		"Health: %d" % int(candidate.health),
		"Willpower: %d" % int(candidate.willpower),
		"Mental: %d" % int(candidate.mental_health),
		"Looks: %d" % int(candidate.looks),
		"Smarts: %d" % int(candidate.smarts)
	]
func watch_live_events(_actor: Person, _payload: Dictionary = {}) -> Dictionary:
	yearly_tick({})
	var state: Dictionary = _world_state()
	return {
		"success": true,
		"schema": "eralife.hero_live_events_report",
		"events": _safe_array(state.get("live_events", [])).duplicate(true),
		"text": "You watch the city move without you. Somewhere, sirens become a choice."
	}

func start_power_battle(actor: Person, villain: Person, context: Dictionary = {}) -> Dictionary:
	if actor == null or villain == null:
		return {
			"success": false,
			"reason": "Power battle requires actor and villain."
		}

	var scenario: Dictionary = _build_power_battle_scenario(actor, villain, context)

	if bool(context.get("queue_external_scenario", false)):
		if gs != null and gs.scenario_engine != null and gs.scenario_engine.has_method("queue_external_scenario"):
			scenario ["surface_timing"] = str(context.get("surface_timing", "post_age_up"))
			scenario ["blocks_age_up_before_time_resolves"] = false
			var queue_report: Dictionary = gs.scenario_engine.queue_external_scenario(scenario)
			_record_hero_event({
				"success": true,
				"schema": "eralife.power_battle_queued_report",
				"actor_id": int(actor.id),
				"villain_id": int(villain.id),
				"scenario_id": str(scenario.get("id", "")),
				"queue_report": queue_report.duplicate(true)
			})
			return queue_report

	return _power_battle_scenario_popup_result(actor, villain, scenario, context)

func _build_power_battle_scenario(actor: Person, villain: Person, context: Dictionary = {}) -> Dictionary:
	var actor_rating: int = _power_rating(actor)
	var villain_rating: int = _power_rating(villain)
	var villain_power_line: String = _power_line(villain)
	var crime_context: Dictionary = _safe_dictionary(context.get("crime_context", {}))
	var crime_line: String = str(crime_context.get("crime_label", "powered crime")).strip_edges()
	var reason_line: String = str(crime_context.get("reason", "They think nobody nearby can stop them.")).strip_edges()
	var capability_packet: Dictionary = _safe_dictionary(context.get("capability_graph", {}))
	if capability_packet.is_empty():
		capability_packet = _build_capability_graph_packet(actor, villain, crime_context, context)

	var battle_choices: Array = [
		{
			"id": "power_battle_direct_engage",
			"label": "Engage With Your Strongest Power",
			"kind": "scenario_choice",
			"button_theme": "power_action",
			"payload": {
				"battle_action": "direct_engage",
				"score_modifier": 8,
				"public_trust_modifier": -2,
				"skill_point_gain": 1,
				"style_tags": ["direct_power"]
			}
		},
		{
			"id": "power_battle_protect_civilians",
			"label": "Protect Civilians First",
			"kind": "scenario_choice",
			"button_theme": "heroic_action",
			"payload": {
				"battle_action": "protect_civilians",
				"score_modifier": -2,
				"public_trust_modifier": 8,
				"skill_point_gain": 1,
				"style_tags": ["protect_first", "heroic"]
			}
		},
		{
			"id": "power_battle_use_environment",
			"label": "Use The Environment",
			"kind": "scenario_choice",
			"button_theme": "tactical_action",
			"payload": {
				"battle_action": "use_environment",
				"score_modifier": 4,
				"public_trust_modifier": 1,
				"skill_point_gain": 1,
				"style_tags": ["tactical"]
			}
		},
		{
			"id": "power_battle_reckless_finish",
			"label": "Go For A Reckless Finish",
			"kind": "scenario_choice",
			"button_theme": "villainous_action",
			"payload": {
				"battle_action": "reckless_finish",
				"score_modifier": 14,
				"public_trust_modifier": -10,
				"corruption_gain": 0.06,
				"skill_point_gain": 2,
				"style_tags": ["reckless", "intimidation"]
			}
		},
		{
			"id": "power_battle_retreat",
			"label": "Retreat And Regroup",
			"kind": "scenario_choice",
			"button_theme": "defensive_escape",
			"payload": {
				"battle_action": "retreat",
				"score_modifier": -999,
				"public_trust_modifier": -4,
				"skill_point_gain": 0,
				"style_tags": ["retreat"]
			}
		}
	]

	battle_choices.append_array(_capability_affordance_battle_choices(actor, villain, crime_context, context, capability_packet))

	var prompt_text: String = "You arrive before the city can pretend this is normal.\n\n%s is already there.\n\nCrime: %s\nReason: %s\n\nPower Read:\nYou: %s\n%s: %s\n\nCapability Graph:\n%s\n\nThis is not a normal fight. Powers, bending, control, fatigue, corruption, civilians, reputation, relationship context, and memory of your action style all matter." % [
		_person_label(villain),
		crime_line.capitalize(),
		reason_line,
		_power_line(actor),
		_person_label(villain),
		villain_power_line,
		str(_capability_scenario_composer_packet(actor, villain, crime_context, context, capability_packet).get("summary", "No capability graph summary."))
	]

	return {
		"id": "superhero_power_battle_%d_%d_%d" % [int(actor.id), int(villain.id), int(Time.get_ticks_msec())],
		"source": "superhero_engine",
		"category": "superhero",
		"resolver_owner": "superhero_engine",
		"resolver_method": "_resolve_power_battle_choice",
		"panel_title": "SUPER POWER BATTLE",
		"footer_text": "Power battle. The outcome is contract-driven by power rating, control, fatigue, corruption, tactics, civilians, reputation, and capability affordances.",
		"prompt": prompt_text,
		"actor_id": int(actor.id),
		"target_id": int(villain.id),
		"villain_id": int(villain.id),
		"battle_type": str(context.get("battle_type", "power_battle")),
		"actor_power_rating": actor_rating,
		"villain_power_rating": villain_rating,
		"crime_context": crime_context.duplicate(true),
		"capability_graph": capability_packet.duplicate(true),
		"selected_affordance": _safe_dictionary(context.get("selected_affordance", {})),
		"surface_timing": str(context.get("surface_timing", "immediate_action")),
		"blocks_age_up_before_time_resolves": false,
		"power_battle_contract": {
			"schema": "eralife.power_battle_contract",
			"version": CONTRACT_VERSION,
			"uses_upce": true,
			"damage_reflects_on_stats": true,
		},
		"choices": battle_choices
	}
func _resolve_power_battle_choice(actor: Person, scenario: Dictionary, choice: Dictionary, _committed: Dictionary) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "Actor missing."
		}

	var villain: Person = _person_by_id(int(scenario.get("villain_id", scenario.get("target_id", -1))))
	if villain == null:
		return {
			"success": false,
			"reason": "Villain missing."
		}

	var payload: Dictionary = _safe_dictionary(choice.get("payload", {}))
	var battle_action: String = str(payload.get("battle_action", "direct_engage")).strip_edges().to_lower()
	var capability_affordance: Dictionary = _safe_dictionary(payload.get("capability_affordance", scenario.get("selected_affordance", {})))
	var profile: Dictionary = ensure_hero_profile(actor)

	if battle_action == "retreat":
		profile ["public_trust"] = clamp(int(profile.get("public_trust", 50)) - 4, 0, 100)
		profile ["losses"] = int(profile.get("losses", 0)) + 1
		_commit_profile(actor, profile)
		_record_affordance_behavior(actor, {
			"id": "retreat",
			"source": "base_battle",
			"style_tags": ["retreat"]
		}, villain, _safe_dictionary(scenario.get("crime_context", {})), "battle")
		return {
			"success": true,
			"schema": "eralife.power_battle_retreat_report",
			"title": "Retreat",
			"text": "You retreat before the battle collapses into disaster. The city survives, but people notice you left.",
			"popup_title": "Retreat",
			"popup_text": "You retreat before the battle collapses into disaster.\n\nThe city survives, but people notice you left.",
			"popup_footer": "Sometimes survival is a strategy. Sometimes it becomes a headline.",
			"hero_profile": profile.duplicate(true)
		}

	var score_modifier: int = int(payload.get("score_modifier", 0))
	if not capability_affordance.is_empty():
		score_modifier += int(round(float(capability_affordance.get("success_weight", 0.5)) * 18.0)) - 6

	var actor_score: int = _power_rating(actor) + score_modifier + randi_range(0, 24)
	var villain_score: int = _power_rating(villain) + randi_range(0, 24)

	if _has_power(actor, "probability_manipulation"):
		actor_score += randi_range(6, 36)
	if _has_power(villain, "probability_manipulation"):
		villain_score += randi_range(6, 36)

	var won: bool = actor_score >= villain_score
	var trust_delta: int = int(payload.get("public_trust_modifier", 0))
	var rep_delta: int = 4
	var skill_point_gain: int = 0
	var skill_report: Dictionary = {}
	var risk_profile: Dictionary = _safe_dictionary(payload.get("risk_profile", capability_affordance.get("risk_profile", {})))
	var social_implication: Dictionary = _safe_dictionary(payload.get("social_implication", capability_affordance.get("social_implication", {})))

	trust_delta += int(social_implication.get("public_trust", 0))
	profile ["legal_risk"] = clamp(int(profile.get("legal_risk", 0)) + int(risk_profile.get("legal_risk", 0)), 0, 100)
	profile ["power_corruption"] = clamp(float(profile.get("power_corruption", 0.0)) + float(payload.get("corruption_gain", risk_profile.get("corruption", 0.0))), 0.0, 1.0)
	profile ["identity_instability"] = clamp(float(profile.get("identity_instability", 0.0)) + float(risk_profile.get("identity_instability", 0.0)), 0.0, 1.0)

	if won:
		rep_delta += 10
		profile ["crimes_stopped"] = int(profile.get("crimes_stopped", 0)) + 1
		profile ["villains_defeated"] = int(profile.get("villains_defeated", 0)) + 1
		trust_delta += 4
		skill_point_gain = max(1, int(payload.get("skill_point_gain", 1)))
		skill_report = _grant_power_battle_skill_points(actor, skill_point_gain, battle_action)
	else:
		trust_delta -= 7
		profile ["losses"] = int(profile.get("losses", 0)) + 1

	profile ["hero_rep"] = max(0, int(profile.get("hero_rep", 0)) + rep_delta)
	profile ["public_trust"] = clamp(int(profile.get("public_trust", 50)) + trust_delta, 0, 100)
	profile ["hero_rank"] = _hero_rank(int(profile.get("hero_rep", 0)))
	profile ["unlocked_team_creation"] = int(profile.get("hero_rep", 0)) >= 40 or int(profile.get("villains_defeated", 0)) >= 3
	_commit_profile(actor, profile)

	var behavior_report: Dictionary = _record_affordance_behavior(actor, payload if capability_affordance.is_empty() else capability_affordance, villain, _safe_dictionary(scenario.get("crime_context", {})), "battle")
	var result_text: String = "You beat %s. The city has a new story about you." % _person_label(villain) if won else "%s gets away. The city has footage. So do your enemies." % _person_label(villain)

	if not capability_affordance.is_empty():
		result_text += "\n\nAction Style: %s" % str(capability_affordance.get("description", capability_affordance.get("id", battle_action)))

	if won and skill_point_gain > 0:
		result_text += "\n\nYou gained %d Power Skill Point(s)." % skill_point_gain

	var battle_report: Dictionary = {
		"success": true,
		"schema": "eralife.power_battle_result",
		"actor_id": int(actor.id),
		"villain_id": int(villain.id),
		"battle_action": battle_action,
		"actor_score": actor_score,
		"villain_score": villain_score,
		"won": won,
		"skill_point_gain": skill_point_gain,
		"skill_report": skill_report.duplicate(true),
		"hero_profile": profile.duplicate(true),
		"capability_affordance": capability_affordance.duplicate(true),
		"risk_profile": risk_profile.duplicate(true),
		"social_implication": social_implication.duplicate(true),
		"behavior_signature_report": behavior_report.duplicate(true),
		"text": result_text,
		"popup_title": "Battle Won" if won else "Villain Escaped",
		"popup_text": result_text,
		"popup_footer": "PowerEngine progression, reputation, public trust, UPCE pressure, and behavior signature were updated together."
	}

	_record_hero_event(battle_report)
	_emit_capability_affordance_upce(actor, villain, battle_report, {
		"event_name": "superhero_battle_completed",
		"source": "superhero_engine.capability_battle"
	})
	return battle_report

func _build_superhero_crime_context(villain: Person, action_id: String, payload: Dictionary = {}) -> Dictionary:
	var selected: Dictionary = _safe_dictionary(payload.get("crime_context", {}))
	var era_key: String = _current_era_key()
	var mode_key: String = _current_superhero_crime_mode_key(payload)
	var contract: Dictionary = _superhero_crime_context_contract()

	if selected.is_empty():
		var eligible_rows: Array = _eligible_superhero_crime_context_rows(contract, action_id, era_key, mode_key, payload)
		var requested_crime_id: String = str(payload.get("crime_id", "")).strip_edges().to_lower()

		if requested_crime_id != "":
			for raw_row in eligible_rows:
				if typeof(raw_row) != TYPE_DICTIONARY:
					continue
				var row: Dictionary = _safe_dictionary(raw_row)
				if str(row.get("crime_id", "")).strip_edges().to_lower() == requested_crime_id:
					selected = row.duplicate(true)
					break

		if selected.is_empty():
			selected = _pick_weighted_superhero_crime_context_row(eligible_rows)

	if selected.is_empty():
		selected = {
			"crime_id": "unstable_powered_disturbance",
			"crime_label": "powered disturbance",
			"reason": "the situation is unstable enough that the city cannot explain it cleanly",
			"stakes": "local_safety",
			"scene": "near a tense crowd where everyone keeps backing away",
			"era": era_key,
			"mode": mode_key
		}

	if str(selected.get("crime_id", "")).strip_edges() == "":
		selected ["crime_id"] = "superhero_crime_%d" % int(Time.get_ticks_msec())

	selected ["schema"] = "eralife.superhero_crime_context"
	selected ["version"] = CONTRACT_VERSION
	selected ["action_id"] = action_id
	selected ["villain_id"] = int(villain.id) if villain != null else -1
	selected ["villain_name"] = _person_label(villain)
	selected ["era"] = str(selected.get("era", era_key)).strip_edges().to_lower()
	selected ["mode"] = str(selected.get("mode", mode_key)).strip_edges().to_lower()
	selected ["created_year"] = _current_year()
	selected ["created_at_ms"] = int(Time.get_ticks_msec())

	if typeof(selected.get("tags", [])) != TYPE_ARRAY:
		selected ["tags"] = []

	return selected
func _superhero_crime_context_contract() -> Dictionary:
	var base_contract: Dictionary = _default_superhero_crime_context_contract()
	var overlay: Dictionary = _safe_dictionary(active_contract.get("crime_context_contract", {}))
	if overlay.is_empty():
		overlay = _safe_dictionary(active_contract.get("superhero_crime_context_contract", {}))

	if not overlay.is_empty():
		base_contract = _merge_dict(base_contract, overlay)

	return base_contract

func _build_capability_graph_packet(actor: Person, target: Person, crime_context: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	var capabilities: Dictionary = collect_actor_capabilities(actor, target, context)
	var tags: Array = derive_capability_tags(capabilities)
	var affordances: Array = compute_action_affordances(tags, _safe_dictionary(capabilities.get("stats", {})), {
		"actor": actor,
		"target": target,
		"crime_context": crime_context.duplicate(true),
		"context": context.duplicate(true),
		"mode": str(capabilities.get("mode", "enhanced")),
		"era": str(capabilities.get("era", "modern"))
	})
	var composed_affordances: Array = compute_composed_affordances(tags, affordances, _safe_dictionary(capabilities.get("stats", {})), {
		"actor": actor,
		"target": target,
		"crime_context": crime_context.duplicate(true),
		"context": context.duplicate(true),
		"mode": str(capabilities.get("mode", "enhanced")),
		"era": str(capabilities.get("era", "modern"))
	})
	var all_affordances: Array = []
	all_affordances.append_array(affordances)
	all_affordances.append_array(composed_affordances)

	var risk_profiles: Dictionary = compute_risk_profiles(all_affordances, _safe_dictionary(capabilities.get("identity", {})), int(_safe_dictionary(capabilities.get("stats", {})).get("control", 50)))
	var social_implications: Dictionary = compute_social_implications(all_affordances, str(crime_context.get("visibility", "public")), int(_safe_dictionary(capabilities.get("identity", {})).get("reputation", 0)))

	for index in range(all_affordances.size()):
		var row: Dictionary = _safe_dictionary(all_affordances [index])
		var row_id: String = str(row.get("id", "")).strip_edges()
		if row_id == "":
			continue
		row ["risk_profile"] = _safe_dictionary(risk_profiles.get(row_id, {}))
		row ["social_implication"] = _safe_dictionary(social_implications.get(row_id, {}))
		all_affordances [index] = row

	return {
		"schema": "eralife.capability_graph_resolver_packet",
		"version": CONTRACT_VERSION,
		"truth_layer": "actor_capability_graph",
		"actor_id": int(actor.id) if actor != null else -1,
		"target_id": int(target.id) if target != null else -1,
		"capabilities": capabilities.duplicate(true),
		"capability_tags": tags.duplicate(true),
		"affordances": affordances.duplicate(true),
		"composed_affordances": composed_affordances.duplicate(true),
		"all_affordances": all_affordances.duplicate(true),
		"risk_profiles": risk_profiles.duplicate(true),
		"social_implications": social_implications.duplicate(true),
		"crime_context": crime_context.duplicate(true),
		"context": context.duplicate(true),
		"created_year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec())
	}


func collect_actor_capabilities(actor: Person, target: Person = null, context: Dictionary = {}) -> Dictionary:
	var powers: Array = []
	if actor != null and gs != null and gs.power_engine != null and gs.power_engine.has_method("get_active_power_ids"):
		powers = gs.power_engine.get_active_power_ids(actor)

	var bending: Dictionary = _actor_bending_capability(actor)
	var profile: Dictionary = ensure_hero_profile(actor)
	var stats: Dictionary = _actor_capability_stats(actor)
	var relationship_context: Dictionary = _capability_relationship_context(actor, target)
	var behavior_signature: Dictionary = _capability_behavior_signature(actor)
	var artifacts: Array = _actor_artifact_ids(actor)
	var mode_key: String = _current_superhero_crime_mode_key(context)
	var era_key: String = _current_era_key()

	return {
		"schema": "eralife.actor_capability_truth_layer",
		"version": CONTRACT_VERSION,
		"actor_id": int(actor.id) if actor != null else -1,
		"target_id": int(target.id) if target != null else -1,
		"powers": powers.duplicate(true),
		"bending": bending.duplicate(true),
		"stats": stats.duplicate(true),
		"identity": {
			"alignment": str(profile.get("alignment", "civilian")),
			"reputation": int(profile.get("hero_rep", 0)),
			"public_trust": int(profile.get("public_trust", 50)),
			"hero_rank": str(profile.get("hero_rank", "unknown")),
			"career": str(context.get("career", "")),
			"social_class": str(context.get("social_class", ""))
		},
		"artifacts": artifacts.duplicate(true),
		"era": era_key,
		"mode": mode_key,
		"relationship_context": relationship_context.duplicate(true),
		"behavior_signature": behavior_signature.duplicate(true),
		"affordance_mutations": _affordance_mutation_state(actor).duplicate(true)
	}


func derive_capability_tags(capabilities: Dictionary) -> Array:
	var tags: Array = []
	var contract: Dictionary = _capability_graph_contract()
	var tag_rules: Dictionary = _safe_dictionary(contract.get("tag_rules", {}))
	var powers: Array = _safe_array(capabilities.get("powers", []))

	for raw_power_id in powers:
		var power_id: String = str(raw_power_id).strip_edges().to_lower()
		_append_unique_string(tags, power_id)
		var power_tags: Array = _safe_array(tag_rules.get(power_id, []))
		for raw_tag in power_tags:
			_append_unique_string(tags, str(raw_tag))

	var bending: Dictionary = _safe_dictionary(capabilities.get("bending", {}))
	var bending_element: String = str(bending.get("element", "")).strip_edges().to_lower()
	var bending_mastery: int = int(bending.get("mastery", 0))
	if bending_element != "":
		_append_unique_string(tags, "bending")
		_append_unique_string(tags, "%s_bending" % bending_element)
		if bending_mastery >= 40:
			_append_unique_string(tags, "%s_control" % bending_element)
		if bending_mastery >= 70:
			_append_unique_string(tags, "%s_mastery" % bending_element)

	var stats: Dictionary = _safe_dictionary(capabilities.get("stats", {}))
	if int(stats.get("control", 0)) >= 70:
		_append_unique_string(tags, "high_control")
	if int(stats.get("willpower", 0)) >= 70:
		_append_unique_string(tags, "high_willpower")
	if int(stats.get("health", 0)) >= 90:
		_append_unique_string(tags, "peak_health")
	if int(stats.get("fame", 0)) >= 100:
		_append_unique_string(tags, "publicly_known")

	var artifacts: Array = _safe_array(capabilities.get("artifacts", []))
	for raw_artifact in artifacts:
		var artifact_id: String = str(raw_artifact).strip_edges().to_lower()
		_append_unique_string(tags, artifact_id)
		if artifact_id == "time_stone":
			_append_unique_string(tags, "temporal_authority")

	var mutations: Dictionary = _safe_dictionary(capabilities.get("affordance_mutations", {}))
	for raw_mutation_id in mutations.keys():
		var mutation_id: String = str(raw_mutation_id).strip_edges().to_lower()
		if bool(_safe_dictionary(mutations.get(raw_mutation_id, {})).get("unlocked", false)):
			_append_unique_string(tags, mutation_id)

	return tags


func compute_action_affordances(tags: Array, stats: Dictionary, context: Dictionary = {}) -> Array:
	var contract: Dictionary = _capability_graph_contract()
	var rows: Array = _safe_array(contract.get("affordances", []))
	var out: Array = []
	var mode_key: String = str(context.get("mode", "enhanced")).strip_edges().to_lower()
	var control: int = int(stats.get("control", 50))

	for raw_row in rows:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = _safe_dictionary(raw_row)
		if row.is_empty():
			continue
		if not _capability_mode_allows(row, mode_key):
			continue
		if not _capability_requires_match(_safe_array(row.get("requires", [])), tags):
			continue

		var score_bonus: float = clamp(float(control) / 160.0, 0.0, 0.35)
		row ["success_weight"] = clamp(float(row.get("success_weight", 0.55)) + score_bonus, 0.05, 0.98)
		row ["schema"] = str(row.get("schema", "eralife.capability_affordance"))
		row ["version"] = max(1, int(row.get("version", CONTRACT_VERSION)))
		out.append(row.duplicate(true))

	return out


func compute_composed_affordances(tags: Array, affordances: Array, stats: Dictionary, context: Dictionary = {}) -> Array:
	var contract: Dictionary = _capability_graph_contract()
	var rows: Array = _safe_array(contract.get("compositions", []))
	var out: Array = []
	var affordance_ids: Array = []
	var mode_key: String = str(context.get("mode", "enhanced")).strip_edges().to_lower()
	var control_bonus: float = clamp(float(int(stats.get("control", 50))) / 220.0, 0.0, 0.25)

	for raw_affordance in affordances:
		if typeof(raw_affordance) != TYPE_DICTIONARY:
			continue
		var affordance: Dictionary = _safe_dictionary(raw_affordance)
		_append_unique_string(affordance_ids, str(affordance.get("id", "")))

	for raw_row in rows:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = _safe_dictionary(raw_row)
		if row.is_empty():
			continue
		if not _capability_mode_allows(row, mode_key):
			continue
		if not _capability_requires_match(_safe_array(row.get("requires", [])), tags):
			continue
		if not _capability_requires_match(_safe_array(row.get("requires_affordances", [])), affordance_ids):
			continue

		var produced: Dictionary = _safe_dictionary(row.get("produces", {}))
		if produced.is_empty():
			continue
		produced ["schema"] = "eralife.composed_capability_affordance"
		produced ["version"] = CONTRACT_VERSION
		produced ["composition_id"] = str(row.get("id", ""))
		produced ["source"] = "affordance_composition"
		produced ["composed"] = true
		produced ["success_weight"] = clamp(float(produced.get("success_weight", 0.7)) + control_bonus, 0.05, 0.99)
		produced ["risk_profile"] = _safe_dictionary(row.get("risk_profile", produced.get("risk_profile", {})))
		produced ["social_implication"] = _safe_dictionary(row.get("modifiers", produced.get("social_implication", {})))
		produced ["style_tags"] = _safe_array(row.get("style_tags", produced.get("style_tags", [])))
		out.append(produced.duplicate(true))

	return out


func compute_risk_profiles(affordances: Array, morality: Dictionary, power_control: int) -> Dictionary:
	var out: Dictionary = {}
	var alignment: String = str(morality.get("alignment", "civilian")).strip_edges().to_lower()
	var control_relief: float = clamp(float(power_control) / 100.0, 0.0, 1.0)

	for raw_affordance in affordances:
		if typeof(raw_affordance) != TYPE_DICTIONARY:
			continue
		var affordance: Dictionary = _safe_dictionary(raw_affordance)
		var affordance_id: String = str(affordance.get("id", "")).strip_edges()
		if affordance_id == "":
			continue

		var base_risk: Dictionary = _safe_dictionary(affordance.get("risk_profile", {}))
		var corruption: float = max(0.0, float(base_risk.get("corruption", 0.0)) - control_relief * 0.06)
		var public_trust: int = int(base_risk.get("public_trust", 0))
		var legal_risk: int = int(base_risk.get("legal_risk", 0))
		var identity_instability: float = max(0.0, float(base_risk.get("identity_instability", 0.0)) - control_relief * 0.04)

		if alignment == "villain":
			corruption += 0.03
			public_trust -= 2
		elif alignment == "hero":
			public_trust += 1

		out [affordance_id] = {
			"schema": "eralife.capability_risk_profile",
			"version": CONTRACT_VERSION,
			"affordance_id": affordance_id,
			"corruption": clamp(corruption, 0.0, 1.0),
			"public_trust": public_trust,
			"legal_risk": legal_risk,
			"identity_instability": clamp(identity_instability, 0.0, 1.0),
			"visibility_risk": float(base_risk.get("visibility_risk", 0.0)),
			"collateral_risk": float(base_risk.get("collateral_risk", 0.0))
		}

	return out


func compute_social_implications(affordances: Array, visibility: String, reputation: int) -> Dictionary:
	var out: Dictionary = {}
	var clean_visibility: String = str(visibility).strip_edges().to_lower()
	var reputation_bonus: int = 1 if reputation >= 40 else 0

	for raw_affordance in affordances:
		if typeof(raw_affordance) != TYPE_DICTIONARY:
			continue
		var affordance: Dictionary = _safe_dictionary(raw_affordance)
		var affordance_id: String = str(affordance.get("id", "")).strip_edges()
		if affordance_id == "":
			continue

		var base_social: Dictionary = _safe_dictionary(affordance.get("social_implication", {}))
		var trust_delta: int = int(base_social.get("public_trust", 0)) + reputation_bonus
		var fear_delta: int = int(base_social.get("fear", 0))
		var myth_delta: int = int(base_social.get("myth", 0))
		var witness_frame: String = str(base_social.get("witness_frame", "unclear_power_use"))

		if clean_visibility in ["phones_recording", "media", "global_stream", "citywide_live_feed", "public_money", "mass_panic"]:
			myth_delta += 2
			if trust_delta < 0:
				fear_delta += 1

		out [affordance_id] = {
			"schema": "eralife.capability_social_implication",
			"version": CONTRACT_VERSION,
			"affordance_id": affordance_id,
			"public_trust": trust_delta,
			"fear": fear_delta,
			"myth": myth_delta,
			"witness_frame": witness_frame,
			"interpretations": _safe_dictionary(base_social.get("interpretations", {}))
		}

	return out


func _capability_graph_contract() -> Dictionary:
	var base_contract: Dictionary = _default_capability_graph_contract()
	var overlay: Dictionary = _safe_dictionary(active_contract.get("capability_graph_contract", {}))
	if not overlay.is_empty():
		base_contract = _merge_dict(base_contract, overlay)
	return base_contract


func _default_capability_graph_contract() -> Dictionary:
	return {
		"schema": "eralife.capability_graph_contract",
		"version": CONTRACT_VERSION,
		"id": "superhero.capability_graph.default",
		"moddable": true,
		"preserve_unknown_fields": true,
		"max_contact_affordance_choices": 5,
		"max_battle_affordance_choices": 5,
		"tag_rules": {
			"super_speed": ["time_dominance", "mobility_supremacy"],
			"super_strength": ["force_dominance", "physical_control"],
			"telepathy": ["mind_access", "intent_reading"],
			"probability_manipulation": ["causality_pressure", "reality_bias"],
			"energy_projection": ["ranged_pressure", "collateral_risk"],
			"spider_abilities": ["agility_control", "restraint_webbing"]
		},
		"affordances": [
			{
				"id": "blitz_target",
				"source": "super_speed",
				"emoji": "⚡",
				"label": "Blitz them before they can react",
				"description": "End the encounter instantly with time dominance.",
				"requires": ["time_dominance"],
				"modes": ["enhanced", "chaos"],
				"battle_action": "blitz_target",
				"outcome_mode": "battle",
				"success_weight": 0.86,
				"score_modifier": 18,
				"public_trust_modifier": -3,
				"skill_point_gain": 1,
				"style_tags": ["blitz", "direct_power"],
				"risk_profile": {
					"corruption": 0.02,
					"public_trust": -2,
					"legal_risk": 3,
					"visibility_risk": 0.24
				},
				"social_implication": {
					"public_trust": -2,
					"fear": 4,
					"myth": 3,
					"witness_frame": "ended_it_before_anyone_could_react",
					"interpretations": {
						"heroic": "saved everyone instantly",
						"reckless": "ended it before anyone could react",
						"villainous": "no one saw what really happened"
					}
				}
			},
			{
				"id": "evacuate_civilians_instantly",
				"source": "super_speed",
				"emoji": "⚡",
				"label": "Evacuate civilians instantly first",
				"description": "Move civilians to safety before the villain understands the fight started.",
				"requires": ["time_dominance"],
				"modes": ["enhanced", "chaos"],
				"battle_action": "protect_civilians",
				"outcome_mode": "battle",
				"success_weight": 0.82,
				"score_modifier": 6,
				"public_trust_modifier": 10,
				"skill_point_gain": 1,
				"style_tags": ["protect_first", "blitz"],
				"risk_profile": {
					"corruption": 0.0,
					"public_trust": 5,
					"legal_risk": 0,
					"visibility_risk": 0.16
				},
				"social_implication": {
					"public_trust": 8,
					"fear": -2,
					"myth": 4,
					"witness_frame": "everyone_was_safe_before_they_blinked"
				}
			},
			{
				"id": "restrain_immediately",
				"source": "super_strength",
				"emoji": "💪",
				"label": "Grab and restrain immediately",
				"description": "Use raw force to end motion without escalating to a full battle.",
				"requires": ["force_dominance"],
				"modes": ["enhanced", "chaos"],
				"battle_action": "restrain_immediately",
				"outcome_mode": "battle",
				"success_weight": 0.78,
				"score_modifier": 12,
				"public_trust_modifier": 2,
				"skill_point_gain": 1,
				"style_tags": ["restraint", "direct_power"],
				"risk_profile": {
					"corruption": 0.01,
					"public_trust": 1,
					"legal_risk": 2,
					"collateral_risk": 0.12
				},
				"social_implication": {
					"public_trust": 2,
					"fear": 2,
					"myth": 1,
					"witness_frame": "raw_force_without_wasted_motion"
				}
			},
			{
				"id": "intimidate_with_raw_force",
				"source": "super_strength",
				"emoji": "💪",
				"label": "Intimidate them with raw force",
				"description": "Make the scene understand your strength before anyone moves.",
				"requires": ["force_dominance"],
				"modes": ["enhanced", "chaos"],
				"battle_action": "intimidate_raw_force",
				"outcome_mode": "social_resolution",
				"success_weight": 0.7,
				"score_modifier": 8,
				"public_trust_modifier": -1,
				"skill_point_gain": 1,
				"style_tags": ["intimidation", "direct_pressure"],
				"risk_profile": {
					"corruption": 0.03,
					"public_trust": -2,
					"legal_risk": 1
				},
				"social_implication": {
					"public_trust": -1,
					"fear": 5,
					"myth": 2,
					"witness_frame": "the_street_got_quiet_when_you_moved"
				}
			},
			{
				"id": "read_intent_before_action",
				"source": "telepathy",
				"emoji": "🧠",
				"label": "Read their intent before they act",
				"description": "Use telepathy to understand the next move before it becomes public violence.",
				"requires": ["mind_access"],
				"modes": ["enhanced", "chaos"],
				"battle_action": "read_intent",
				"outcome_mode": "social_resolution",
				"success_weight": 0.76,
				"score_modifier": 5,
				"public_trust_modifier": 4,
				"skill_point_gain": 1,
				"style_tags": ["deescalation", "mind_read"],
				"risk_profile": {
					"corruption": 0.02,
					"public_trust": 1,
					"legal_risk": 2,
					"identity_instability": 0.01
				},
				"social_implication": {
					"public_trust": 3,
					"fear": 1,
					"myth": 2,
					"witness_frame": "you_answered_the_thought_before_the_action"
				}
			},
			{
				"id": "override_decision",
				"source": "telepathy",
				"emoji": "🧠",
				"label": "Override their decision",
				"description": "Force the choice to stop inside their mind.",
				"requires": ["mind_access"],
				"modes": ["chaos"],
				"battle_action": "override_decision",
				"outcome_mode": "battle",
				"success_weight": 0.88,
				"score_modifier": 20,
				"public_trust_modifier": -8,
				"skill_point_gain": 2,
				"style_tags": ["mind_control", "corruption"],
				"risk_profile": {
					"corruption": 0.1,
					"public_trust": -8,
					"legal_risk": 8,
					"identity_instability": 0.04
				},
				"social_implication": {
					"public_trust": -7,
					"fear": 8,
					"myth": 5,
					"witness_frame": "nobody_saw_violence_but_everyone_felt_wrong"
				}
			},
			{
				"id": "weapon_jams",
				"source": "probability_manipulation",
				"emoji": "🎲",
				"label": "Make something go wrong for them",
				"description": "Rewrite the odds so their plan fails before your hand moves.",
				"requires": ["causality_pressure"],
				"modes": ["chaos"],
				"battle_action": "probability_jam",
				"outcome_mode": "battle",
				"success_weight": 0.9,
				"score_modifier": 22,
				"public_trust_modifier": 0,
				"skill_point_gain": 2,
				"style_tags": ["probability", "causality"],
				"risk_profile": {
					"corruption": 0.05,
					"public_trust": 0,
					"legal_risk": 2,
					"identity_instability": 0.06,
					"visibility_risk": 0.1
				},
				"social_implication": {
					"public_trust": 1,
					"fear": 3,
					"myth": 7,
					"witness_frame": "the_world_bent_out_of_their_way"
				}
			},
			{
				"id": "air_disarm",
				"source": "air_bending",
				"emoji": "🌪",
				"label": "Disarm with air before they react",
				"description": "Use air control to remove the threat without meeting force with force.",
				"requires": ["air_control"],
				"modes": ["enhanced", "chaos"],
				"battle_action": "air_disarm",
				"outcome_mode": "battle",
				"success_weight": 0.76,
				"score_modifier": 9,
				"public_trust_modifier": 5,
				"skill_point_gain": 1,
				"style_tags": ["disarm", "bending", "nonlethal"],
				"risk_profile": {
					"corruption": 0.0,
					"public_trust": 3,
					"legal_risk": 0
				},
				"social_implication": {
					"public_trust": 4,
					"fear": -1,
					"myth": 3,
					"witness_frame": "the_weapon_left_their_hand_like_the_air_rejected_it"
				}
			},
			{
				"id": "earth_immobilize",
				"source": "earth_bending",
				"emoji": "🪨",
				"label": "Immobilize them instantly",
				"description": "Lock the villain in place before the scene can spread.",
				"requires": ["earth_control"],
				"modes": ["enhanced", "chaos"],
				"battle_action": "earth_immobilize",
				"outcome_mode": "battle",
				"success_weight": 0.8,
				"score_modifier": 11,
				"public_trust_modifier": 4,
				"skill_point_gain": 1,
				"style_tags": ["immobilize", "bending", "control"],
				"risk_profile": {
					"corruption": 0.0,
					"public_trust": 2,
					"legal_risk": 1
				},
				"social_implication": {
					"public_trust": 3,
					"fear": 1,
					"myth": 3,
					"witness_frame": "the_ground_made_the_arrest_before_the_police_arrived"
				}
			},
			{
				"id": "fire_pressure",
				"source": "fire_bending",
				"emoji": "🔥",
				"label": "Pressure them with fire",
				"description": "Use heat and presence to force surrender.",
				"requires": ["fire_control"],
				"modes": ["enhanced", "chaos"],
				"battle_action": "fire_pressure",
				"outcome_mode": "battle",
				"success_weight": 0.74,
				"score_modifier": 13,
				"public_trust_modifier": -2,
				"skill_point_gain": 1,
				"style_tags": ["intimidation", "bending", "collateral_risk"],
				"risk_profile": {
					"corruption": 0.02,
					"public_trust": -2,
					"legal_risk": 3,
					"collateral_risk": 0.2
				},
				"social_implication": {
					"public_trust": -1,
					"fear": 4,
					"myth": 4,
					"witness_frame": "the_air_got_hot_enough_to_make_everyone_believe_you"
				}
			},
			{
				"id": "water_restrain_and_cover",
				"source": "water_bending",
				"emoji": "🌊",
				"label": "Restrain them while shielding civilians",
				"description": "Use water as restraint and protection at the same time.",
				"requires": ["water_control"],
				"modes": ["enhanced", "chaos"],
				"battle_action": "water_restrain",
				"outcome_mode": "battle",
				"success_weight": 0.78,
				"score_modifier": 8,
				"public_trust_modifier": 7,
				"skill_point_gain": 1,
				"style_tags": ["protect_first", "bending", "restraint"],
				"risk_profile": {
					"corruption": 0.0,
					"public_trust": 4,
					"legal_risk": 0
				},
				"social_implication": {
					"public_trust": 6,
					"fear": -1,
					"myth": 4,
					"witness_frame": "the_water_moved_like_a_bodyguard"
				}
			},
			{
				"id": "time_loop_warning",
				"source": "time_stone",
				"emoji": "👁️",
				"label": "Warn them like this already happened",
				"description": "Use temporal authority to make the encounter feel pre-decided.",
				"requires": ["temporal_authority"],
				"modes": ["chaos"],
				"battle_action": "time_loop_warning",
				"outcome_mode": "social_resolution",
				"success_weight": 0.84,
				"score_modifier": 18,
				"public_trust_modifier": -1,
				"skill_point_gain": 2,
				"style_tags": ["temporal", "mythic_pressure"],
				"risk_profile": {
					"corruption": 0.03,
					"public_trust": -1,
					"legal_risk": 0,
					"identity_instability": 0.08
				},
				"social_implication": {
					"public_trust": 0,
					"fear": 5,
					"myth": 10,
					"witness_frame": "you_spoke_like_you_had_already_won_in_another_second"
				}
			}
		],
		"compositions": [
			{
				"id": "speed_air_disarm_combo",
				"requires": ["time_dominance", "air_control", "high_control"],
				"requires_affordances": ["blitz_target", "air_disarm"],
				"modes": ["enhanced", "chaos"],
				"produces": {
					"id": "instant_disarm",
					"emoji": "⚡🌪",
					"label": "Disarm before they realize you moved",
					"description": "Cross the room in the space between thought and reaction, then let the air remove the threat.",
					"battle_action": "instant_disarm",
					"outcome_mode": "battle",
					"success_weight": 0.93,
					"score_modifier": 24,
					"public_trust_modifier": 5,
					"skill_point_gain": 2
				},
				"modifiers": {
					"public_trust": 3,
					"fear": 1,
					"myth": 7,
					"witness_frame": "the_weapon_was_gone_before_the_first_blink_finished"
				},
				"risk_profile": {
					"corruption": 0.01,
					"public_trust": 3,
					"legal_risk": 1,
					"visibility_risk": 0.18
				},
				"style_tags": ["blitz", "disarm", "bending", "precision"]
			},
			{
				"id": "guardian_flash_combo",
				"requires": ["guardian_flash", "time_dominance"],
				"requires_affordances": ["evacuate_civilians_instantly"],
				"modes": ["enhanced", "chaos"],
				"produces": {
					"id": "guardian_flash_response",
					"emoji": "⚡🛡",
					"label": "Guardian Flash",
					"description": "Save the civilians, disarm the threat, and make the rescue look effortless.",
					"battle_action": "guardian_flash",
					"outcome_mode": "battle",
					"success_weight": 0.95,
					"score_modifier": 26,
					"public_trust_modifier": 12,
					"skill_point_gain": 2
				},
				"modifiers": {
					"public_trust": 8,
					"fear": -3,
					"myth": 8,
					"witness_frame": "you_became_a_rescue_before_you_became_a_fight"
				},
				"risk_profile": {
					"corruption": 0.0,
					"public_trust": 8,
					"legal_risk": 0
				},
				"style_tags": ["protect_first", "blitz", "mutation"]
			},
			{
				"id": "probability_air_collapse_combo",
				"requires": ["causality_pressure", "air_control"],
				"requires_affordances": ["weapon_jams", "air_disarm"],
				"modes": ["chaos"],
				"produces": {
					"id": "variable_collapse_disarm",
					"emoji": "🎲🌪",
					"label": "Collapse the variables against them",
					"description": "Their plan fails, the weapon leaves their hand, and nobody can prove which part was you.",
					"battle_action": "variable_collapse_disarm",
					"outcome_mode": "battle",
					"success_weight": 0.94,
					"score_modifier": 30,
					"public_trust_modifier": 1,
					"skill_point_gain": 3
				},
				"modifiers": {
					"public_trust": 1,
					"fear": 4,
					"myth": 10,
					"witness_frame": "reality_removed_every_option_except_your_victory"
				},
				"risk_profile": {
					"corruption": 0.06,
					"public_trust": 0,
					"legal_risk": 2,
					"identity_instability": 0.08
				},
				"style_tags": ["probability", "causality", "disarm"]
			}
		]
	}


func _base_villain_encounter_choices(_actor: Person, villain: Person, crime_context: Dictionary, context: Dictionary = {}) -> Array:
	return [
		{
			"label": "Talk Them Down",
			"detail_action": "engine_call",
			"engine_property": "superhero_engine",
			"method": "resolve_hub_action",
			"payload": {
				"action": "resolve_villain_encounter_choice",
				"villain_id": int(villain.id),
				"encounter_choice": "talk_down",
				"crime_context": crime_context.duplicate(true),
				"battle_context": context.duplicate(true)
			}
		},
		{
			"label": "Tell Them It's Over",
			"detail_action": "engine_call",
			"engine_property": "superhero_engine",
			"method": "resolve_hub_action",
			"payload": {
				"action": "resolve_villain_encounter_choice",
				"villain_id": int(villain.id),
				"encounter_choice": "call_it_over",
				"crime_context": crime_context.duplicate(true),
				"battle_context": context.duplicate(true)
			}
		},
		{
			"label": "Battle With Your Abilities",
			"detail_action": "engine_call",
			"engine_property": "superhero_engine",
			"method": "resolve_hub_action",
			"payload": {
				"action": "resolve_villain_encounter_choice",
				"villain_id": int(villain.id),
				"encounter_choice": "battle",
				"crime_context": crime_context.duplicate(true),
				"battle_context": context.duplicate(true)
			}
		}
	]


func _capability_affordance_contact_choices(_actor: Person, villain: Person, crime_context: Dictionary, context: Dictionary, capability_packet: Dictionary) -> Array:
	var contract: Dictionary = _capability_graph_contract()
	var max_choices: int = max(0, int(contract.get("max_contact_affordance_choices", 5)))
	var rows: Array = _safe_array(capability_packet.get("all_affordances", []))
	var out: Array = []

	for raw_row in rows:
		if out.size() >= max_choices:
			break
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = _safe_dictionary(raw_row)
		if row.is_empty():
			continue
		var label_text: String = "%s %s" % [
			str(row.get("emoji", "✦")),
			str(row.get("label", row.get("description", row.get("id", "Use capability"))))
		]
		out.append({
			"label": label_text.strip_edges(),
			"detail_action": "engine_call",
			"engine_property": "superhero_engine",
			"method": "resolve_hub_action",
			"payload": {
				"action": "resolve_villain_encounter_choice",
				"villain_id": int(villain.id),
				"encounter_choice": "capability_affordance",
				"crime_context": crime_context.duplicate(true),
				"battle_context": context.duplicate(true),
				"capability_affordance": row.duplicate(true),
				"capability_graph": capability_packet.duplicate(true)
			}
		})

	return out


func _capability_affordance_battle_choices(_actor: Person, _villain: Person, _crime_context: Dictionary, _context: Dictionary, capability_packet: Dictionary) -> Array:
	var contract: Dictionary = _capability_graph_contract()
	var max_choices: int = max(0, int(contract.get("max_battle_affordance_choices", 5)))
	var rows: Array = _safe_array(capability_packet.get("all_affordances", []))
	var out: Array = []

	for raw_row in rows:
		if out.size() >= max_choices:
			break
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = _safe_dictionary(raw_row)
		if row.is_empty():
			continue
		var label_text: String = "%s %s" % [
			str(row.get("emoji", "✦")),
			str(row.get("label", row.get("description", row.get("id", "Use capability"))))
		]
		out.append({
			"id": "power_battle_%s" % str(row.get("id", "capability_affordance")),
			"label": label_text.strip_edges(),
			"kind": "scenario_choice",
			"button_theme": "capability_action",
			"payload": _capability_affordance_to_battle_payload(row, capability_packet)
		})

	return out


func _capability_affordance_to_battle_payload(affordance: Dictionary, capability_packet: Dictionary) -> Dictionary:
	return {
		"battle_action": str(affordance.get("battle_action", affordance.get("id", "capability_affordance"))),
		"score_modifier": int(affordance.get("score_modifier", 0)),
		"public_trust_modifier": int(affordance.get("public_trust_modifier", 0)),
		"corruption_gain": float(_safe_dictionary(affordance.get("risk_profile", {})).get("corruption", 0.0)),
		"skill_point_gain": int(affordance.get("skill_point_gain", 1)),
		"style_tags": _safe_array(affordance.get("style_tags", [])),
		"capability_affordance": affordance.duplicate(true),
		"capability_graph": capability_packet.duplicate(true),
		"risk_profile": _safe_dictionary(affordance.get("risk_profile", {})),
		"social_implication": _safe_dictionary(affordance.get("social_implication", {}))
	}


func _resolve_capability_affordance_choice(actor: Person, villain: Person, payload: Dictionary, crime_context: Dictionary, battle_context: Dictionary) -> Dictionary:
	var affordance: Dictionary = _safe_dictionary(payload.get("capability_affordance", {}))
	if affordance.is_empty():
		return start_power_battle(actor, villain, battle_context)

	var capability_packet: Dictionary = _safe_dictionary(payload.get("capability_graph", {}))
	if capability_packet.is_empty():
		capability_packet = _build_capability_graph_packet(actor, villain, crime_context, battle_context)

	_record_affordance_behavior(actor, affordance, villain, crime_context, "initial_contact")

	var outcome_mode: String = str(affordance.get("outcome_mode", "battle")).strip_edges().to_lower()
	if outcome_mode == "social_resolution":
		return _resolve_capability_social_resolution(actor, villain, affordance, capability_packet, crime_context, battle_context)

	battle_context ["capability_graph"] = capability_packet.duplicate(true)
	battle_context ["selected_affordance"] = affordance.duplicate(true)
	var scenario: Dictionary = _build_power_battle_scenario(actor, villain, battle_context)
	return _resolve_power_battle_choice(actor, scenario, {
		"id": "initial_contact_%s" % str(affordance.get("id", "capability_affordance")),
		"label": str(affordance.get("label", "Use capability")),
		"payload": _capability_affordance_to_battle_payload(affordance, capability_packet)
	}, {})


func _resolve_capability_social_resolution(actor: Person, villain: Person, affordance: Dictionary, capability_packet: Dictionary, crime_context: Dictionary, _battle_context: Dictionary = {}) -> Dictionary:
	var profile: Dictionary = ensure_hero_profile(actor)
	var stats: Dictionary = _safe_dictionary(_safe_dictionary(capability_packet.get("capabilities", {})).get("stats", {}))
	var risk_profile: Dictionary = _safe_dictionary(affordance.get("risk_profile", {}))
	var social_implication: Dictionary = _safe_dictionary(affordance.get("social_implication", {}))
	var actor_score: int = int(stats.get("willpower", 50)) + int(stats.get("control", 50)) + int(round(float(affordance.get("success_weight", 0.55)) * 80.0)) + randi_range(0, 30)
	var villain_resistance: int = _power_rating(villain) + int(villain.willpower) + randi_range(0, 50)
	var accepted: bool = actor_score >= villain_resistance

	profile ["legal_risk"] = clamp(int(profile.get("legal_risk", 0)) + int(risk_profile.get("legal_risk", 0)), 0, 100)
	profile ["power_corruption"] = clamp(float(profile.get("power_corruption", 0.0)) + float(risk_profile.get("corruption", 0.0)), 0.0, 1.0)
	profile ["identity_instability"] = clamp(float(profile.get("identity_instability", 0.0)) + float(risk_profile.get("identity_instability", 0.0)), 0.0, 1.0)

	if accepted:
		profile ["crimes_stopped"] = int(profile.get("crimes_stopped", 0)) + 1
		profile ["hero_rep"] = int(profile.get("hero_rep", 0)) + 8
		profile ["public_trust"] = clamp(int(profile.get("public_trust", 50)) + 5 + int(social_implication.get("public_trust", 0)), 0, 100)
		profile ["hero_rank"] = _hero_rank(int(profile.get("hero_rep", 0)))
		_commit_profile(actor, profile)

		var win_text: String = "%s stops before the scene becomes a fight.\n\n%s" % [
			_person_label(villain),
			str(affordance.get("description", "Your capability changed what this moment could become."))
		]
		var win_report: Dictionary = {
			"success": true,
			"schema": "eralife.capability_social_resolution_report",
			"version": CONTRACT_VERSION,
			"villain_id": int(villain.id),
			"affordance_id": str(affordance.get("id", "")),
			"actor_score": actor_score,
			"villain_resistance": villain_resistance,
			"accepted": true,
			"crime_context": crime_context.duplicate(true),
			"capability_affordance": affordance.duplicate(true),
			"capability_graph": capability_packet.duplicate(true),
			"hero_profile": profile.duplicate(true),
			"text": win_text,
			"popup_title": "Capability Resolved The Scene",
			"popup_text": win_text,
			"popup_footer": "The world remembers the style, not just the win."
		}
		_record_hero_event(win_report)
		_emit_capability_affordance_upce(actor, villain, win_report, {
			"event_name": "heroic_rescue",
			"source": "superhero_engine.capability_social_resolution"
		})
		return win_report

	_commit_profile(actor, profile)
	var refusal_text: String = "%s almost breaks.\n\nThen they force the moment back into violence." % _person_label(villain)
	return {
		"success": true,
		"schema": "eralife.capability_social_resolution_refused",
		"version": CONTRACT_VERSION,
		"villain_id": int(villain.id),
		"affordance_id": str(affordance.get("id", "")),
		"actor_score": actor_score,
		"villain_resistance": villain_resistance,
		"accepted": false,
		"text": refusal_text,
		"popup_title": "They Resist",
		"popup_text": refusal_text,
		"popup_footer": "The capability route failed. Battle pressure is now live.",
		"followup_result": start_power_battle(actor, villain, {
			"crime_context": crime_context.duplicate(true),
			"capability_graph": capability_packet.duplicate(true),
			"selected_affordance": affordance.duplicate(true)
		})
	}


func _capability_scenario_composer_packet(actor: Person, target: Person, crime_context: Dictionary, context: Dictionary, capability_packet: Dictionary) -> Dictionary:
	var tags: Array = _safe_array(capability_packet.get("capability_tags", []))
	var affordance_count: int = _safe_array(capability_packet.get("all_affordances", [])).size()
	var relationship_context: Dictionary = _safe_dictionary(_safe_dictionary(capability_packet.get("capabilities", {})).get("relationship_context", {}))
	var behavior_signature: Dictionary = _safe_dictionary(_safe_dictionary(capability_packet.get("capabilities", {})).get("behavior_signature", {}))
	var summary_parts: Array = []

	if not tags.is_empty():
		summary_parts.append("Tags: %s" % ", ".join(tags.slice(0, min(tags.size(), 6))))
	summary_parts.append("Affordances: %d" % affordance_count)

	var relation_label: String = str(relationship_context.get("relationship_label", "")).strip_edges()
	if relation_label != "":
		summary_parts.append("Relationship: %s" % relation_label)

	var dominant_style: String = str(behavior_signature.get("dominant_style", "")).strip_edges()
	if dominant_style != "":
		summary_parts.append("Pattern: %s" % dominant_style.replace("_", " ").capitalize())

	return {
		"schema": "eralife.capability_aware_scenario_composer_packet",
		"version": CONTRACT_VERSION,
		"actor_id": int(actor.id) if actor != null else -1,
		"target_id": int(target.id) if target != null else -1,
		"crime_context": crime_context.duplicate(true),
		"context": context.duplicate(true),
		"summary": " • ".join(summary_parts),
		"composer_steps": [
			"intent",
			"capability_graph",
			"capability_tags",
			"affordances",
			"affordance_composition",
			"risk_profiles",
			"social_implications",
			"scenario_composer",
			"player_choice",
			"outcome",
			"upce",
			"behavior_signature"
		]
	}


func _actor_capability_stats(actor: Person) -> Dictionary:
	if actor == null:
		return {
			"health": 0,
			"willpower": 0,
			"control": 0,
			"fame": 0,
			"mental_health": 0,
			"smarts": 0,
			"looks": 0,
			"age": 0
		}

	var control_score: int = int(actor.willpower)
	if gs != null and gs.power_engine != null and gs.power_engine.has_method("ensure_person_power_state"):
		var power_state: Dictionary = gs.power_engine.ensure_person_power_state(actor)
		control_score = int(power_state.get("control", power_state.get("power_control", control_score)))

	return {
		"health": int(actor.health),
		"willpower": int(actor.willpower),
		"control": clamp(control_score, 0, 100),
		"fame": int(actor.fame) if "fame" in actor else 0,
		"mental_health": int(actor.mental_health),
		"smarts": int(actor.smarts),
		"looks": int(actor.looks),
		"age": int(actor.age) if "age" in actor else 0
	}


func _actor_bending_capability(actor: Person) -> Dictionary:
	var out: Dictionary = {
		"element": "",
		"mastery": 0,
		"elements": []
	}
	if actor == null or gs == null or gs.bending_engine == null:
		return out

	var elements: Array = []
	if gs.bending_engine.has_method("get_bending_training_elements"):
		elements = gs.bending_engine.get_bending_training_elements(actor)
	out ["elements"] = elements.duplicate(true)

	var best_element: String = ""
	var best_level: int = 0
	for raw_element in elements:
		var element: String = str(raw_element).strip_edges().to_lower()
		if element == "":
			continue
		var level: int = 0
		if gs.bending_engine.has_method("get_bending_level"):
			level = int(gs.bending_engine.get_bending_level(actor, element))
		elif gs.bending_engine.has_method("get_primary_bending_level"):
			level = int(gs.bending_engine.get_primary_bending_level(actor))
		if level > best_level:
			best_level = level
			best_element = element

	if best_element == "" and gs.bending_engine.has_method("get_primary_bending_level"):
		best_level = int(gs.bending_engine.get_primary_bending_level(actor))

	out ["element"] = best_element
	out ["mastery"] = best_level
	return out


func _actor_artifact_ids(actor: Person) -> Array:
	var out: Array = []
	if actor == null:
		return out

	if gs != null and "artifacts_engine" in gs and gs.artifacts_engine != null:
		if gs.artifacts_engine.has_method("get_active_artifact_ids"):
			var active_raw: Variant = gs.artifacts_engine.call("get_active_artifact_ids", actor)
			if typeof(active_raw) == TYPE_ARRAY:
				for raw_id in active_raw:
					_append_unique_string(out, str(raw_id))
		elif gs.artifacts_engine.has_method("get_actor_artifacts"):
			var actor_artifacts_raw: Variant = gs.artifacts_engine.call("get_actor_artifacts", actor)
			if typeof(actor_artifacts_raw) == TYPE_ARRAY:
				for raw_artifact in actor_artifacts_raw:
					if typeof(raw_artifact) == TYPE_DICTIONARY:
						_append_unique_string(out, str(_safe_dictionary(raw_artifact).get("id", "")))
					else:
						_append_unique_string(out, str(raw_artifact))

	if "artifact_ids" in actor and typeof(actor.artifact_ids) == TYPE_ARRAY:
		for raw_actor_artifact in actor.artifact_ids:
			_append_unique_string(out, str(raw_actor_artifact))

	return out


func _capability_relationship_context(actor: Person, target: Person) -> Dictionary:
	var out: Dictionary = {
		"target_is_known": false,
		"relationship_label": "",
		"trust_level": 0,
		"history_tags": []
	}
	if actor == null or target == null:
		return out

	out ["target_is_known"] = true

	if gs != null and gs.has_method("get_relationship_label_between"):
		out ["relationship_label"] = str(gs.get_relationship_label_between(actor, target))
	elif gs != null and gs.relationship_engine != null and gs.relationship_engine.has_method("get_relationship_memory_summary"):
		var summary: Dictionary = gs.relationship_engine.get_relationship_memory_summary(actor, target)
		out ["relationship_label"] = str(summary.get("label", summary.get("relationship_label", "")))
		out ["trust_level"] = int(summary.get("trust", summary.get("score", 0)))

	var label: String = str(out.get("relationship_label", "")).strip_edges().to_lower()
	var history_tags: Array = []
	if label.find("girlfriend") >= 0 or label.find("boyfriend") >= 0 or label.find("partner") >= 0 or label.find("spouse") >= 0:
		history_tags.append("intimate_bond")
	if label.find("rival") >= 0 or label.find("enemy") >= 0:
		history_tags.append("rivalry")
	if label.find("family") >= 0 or label.find("mother") >= 0 or label.find("father") >= 0 or label.find("sibling") >= 0:
		history_tags.append("family")
	out ["history_tags"] = history_tags

	return out


func _capability_behavior_signature(actor: Person) -> Dictionary:
	var state: Dictionary = _world_state()
	var signatures: Dictionary = _safe_dictionary(state.get("capability_behavior_signatures", {}))
	var signature: Dictionary = _safe_dictionary(signatures.get(_person_key(actor), {}))
	if signature.is_empty():
		signature = {
			"schema": "eralife.capability_behavior_signature",
			"version": CONTRACT_VERSION,
			"person_id": int(actor.id) if actor != null else -1,
			"total_actions": 0,
			"source_counts": {},
			"style_counts": {},
			"dominant_style": "",
			"blitz_frequency": 0.0,
			"protect_first_frequency": 0.0,
			"intimidation_frequency": 0.0,
			"probability_frequency": 0.0,
			"mind_control_frequency": 0.0,
			"updated_year": _current_year()
		}
	return signature.duplicate(true)


func _record_affordance_behavior(actor: Person, affordance: Dictionary, target: Person, crime_context: Dictionary, channel: String = "unknown") -> Dictionary:
	if actor == null:
		return {}

	var state: Dictionary = _world_state()
	var signatures: Dictionary = _safe_dictionary(state.get("capability_behavior_signatures", {}))
	var signature: Dictionary = _capability_behavior_signature(actor)
	var total_actions: int = int(signature.get("total_actions", 0)) + 1
	var source_counts: Dictionary = _safe_dictionary(signature.get("source_counts", {}))
	var style_counts: Dictionary = _safe_dictionary(signature.get("style_counts", {}))
	var source_id: String = str(affordance.get("source", affordance.get("id", "unknown"))).strip_edges().to_lower()
	var style_tags: Array = _safe_array(affordance.get("style_tags", []))

	source_counts [source_id] = int(source_counts.get(source_id, 0)) + 1
	for raw_tag in style_tags:
		var tag: String = str(raw_tag).strip_edges().to_lower()
		if tag == "":
			continue
		style_counts [tag] = int(style_counts.get(tag, 0)) + 1

	signature ["total_actions"] = total_actions
	signature ["source_counts"] = source_counts
	signature ["style_counts"] = style_counts
	signature ["dominant_style"] = _dominant_behavior_style(style_counts)
	signature ["blitz_frequency"] = _behavior_frequency(style_counts, "blitz", total_actions)
	signature ["protect_first_frequency"] = _behavior_frequency(style_counts, "protect_first", total_actions)
	signature ["intimidation_frequency"] = _behavior_frequency(style_counts, "intimidation", total_actions)
	signature ["probability_frequency"] = _behavior_frequency(style_counts, "probability", total_actions)
	signature ["mind_control_frequency"] = _behavior_frequency(style_counts, "mind_control", total_actions)
	signature ["last_affordance_id"] = str(affordance.get("id", ""))
	signature ["last_channel"] = channel
	signature ["last_target_id"] = int(target.id) if target != null else -1
	signature ["updated_year"] = _current_year()
	signature ["updated_at_ms"] = int(Time.get_ticks_msec())

	signatures [_person_key(actor)] = signature.duplicate(true)
	state ["capability_behavior_signatures"] = signatures

	var ledger: Array = _safe_array(state.get("capability_affordance_ledger", []))
	ledger.append({
		"schema": "eralife.capability_affordance_action",
		"version": CONTRACT_VERSION,
		"actor_id": int(actor.id),
		"target_id": int(target.id) if target != null else -1,
		"affordance_id": str(affordance.get("id", "")),
		"source": source_id,
		"style_tags": style_tags.duplicate(true),
		"channel": channel,
		"crime_id": str(crime_context.get("crime_id", "")),
		"year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec())
	})
	while ledger.size() > 160:
		ledger.pop_front()
	state ["capability_affordance_ledger"] = ledger

	var mutation_report: Dictionary = _apply_affordance_mutation_unlocks(actor, signature, state)
	_commit_world_state(state)

	return {
		"success": true,
		"schema": "eralife.capability_behavior_signature_report",
		"version": CONTRACT_VERSION,
		"signature": signature.duplicate(true),
		"mutation_report": mutation_report.duplicate(true)
	}


func _apply_affordance_mutation_unlocks(actor: Person, signature: Dictionary, state: Dictionary) -> Dictionary:
	var mutations: Dictionary = _safe_dictionary(state.get("affordance_mutations", {}))
	var actor_mutations: Dictionary = _safe_dictionary(mutations.get(_person_key(actor), {}))
	var style_counts: Dictionary = _safe_dictionary(signature.get("style_counts", {}))
	var unlocked: Array = []

	if int(style_counts.get("blitz", 0)) >= 3 and int(style_counts.get("protect_first", 0)) >= 2:
		if not bool(_safe_dictionary(actor_mutations.get("guardian_flash", {})).get("unlocked", false)):
			actor_mutations ["guardian_flash"] = _affordance_mutation_row("guardian_flash", "Guardian Flash", "Blitz + protect-first behavior became a permanent rescue instinct.")
			unlocked.append("guardian_flash")

	if int(style_counts.get("probability", 0)) >= 5:
		if not bool(_safe_dictionary(actor_mutations.get("reality_distortion_aura", {})).get("unlocked", false)):
			actor_mutations ["reality_distortion_aura"] = _affordance_mutation_row("reality_distortion_aura", "Reality Distortion Aura", "Repeated probability manipulation made reality start expecting your interference.")
			unlocked.append("reality_distortion_aura")

	if int(style_counts.get("mind_control", 0)) >= 4:
		if not bool(_safe_dictionary(actor_mutations.get("cognitive_overlord", {})).get("unlocked", false)):
			actor_mutations ["cognitive_overlord"] = _affordance_mutation_row("cognitive_overlord", "Cognitive Overlord", "Repeated mental overrides hardened into a terrifying permanent affordance.")
			unlocked.append("cognitive_overlord")

	mutations [_person_key(actor)] = actor_mutations.duplicate(true)
	state ["affordance_mutations"] = mutations

	return {
		"success": true,
		"unlocked": unlocked.duplicate(true),
		"actor_mutations": actor_mutations.duplicate(true)
	}


func _affordance_mutation_row(mutation_id: String, label: String, description: String) -> Dictionary:
	return {
		"schema": "eralife.affordance_mutation",
		"version": CONTRACT_VERSION,
		"id": mutation_id,
		"label": label,
		"description": description,
		"unlocked": true,
		"created_year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec())
	}


func _affordance_mutation_state(actor: Person) -> Dictionary:
	var state: Dictionary = _world_state()
	var mutations: Dictionary = _safe_dictionary(state.get("affordance_mutations", {}))
	return _safe_dictionary(mutations.get(_person_key(actor), {}))


func _dominant_behavior_style(style_counts: Dictionary) -> String:
	var best_key: String = ""
	var best_value: int = -1
	for raw_key in style_counts.keys():
		var key: String = str(raw_key)
		var value: int = int(style_counts.get(raw_key, 0))
		if value > best_value:
			best_value = value
			best_key = key
	return best_key


func _behavior_frequency(style_counts: Dictionary, style_id: String, total_actions: int) -> float:
	if total_actions <= 0:
		return 0.0
	return clamp(float(style_counts.get(style_id, 0)) / float(total_actions), 0.0, 1.0)


func _capability_requires_match(required: Array, available: Array) -> bool:
	for raw_required in required:
		var required_id: String = str(raw_required).strip_edges().to_lower()
		if required_id == "":
			continue
		var found: bool = false
		for raw_available in available:
			if str(raw_available).strip_edges().to_lower() == required_id:
				found = true
				break
		if not found:
			return false
	return true


func _capability_mode_allows(row: Dictionary, mode_key: String) -> bool:
	var modes: Array = _safe_array(row.get("modes", []))
	if modes.is_empty():
		return true
	var clean_mode: String = str(mode_key).strip_edges().to_lower()
	for raw_mode in modes:
		var row_mode: String = str(raw_mode).strip_edges().to_lower()
		if row_mode == "all" or row_mode == clean_mode:
			return true
	return false


func _emit_capability_affordance_upce(actor: Person, target: Person, report: Dictionary, context: Dictionary = {}) -> Dictionary:
	if gs == null or not ("upce_engine" in gs) or gs.upce_engine == null:
		return {
			"success": false,
			"reason": "upce_engine_unavailable"
		}
	if not gs.upce_engine.has_method("interpret_event"):
		return {
			"success": false,
			"reason": "upce_interpret_event_unavailable"
		}

	var event_name: String = str(context.get("event_name", "power_usage"))
	var event_payload: Dictionary = {
		"event_name": event_name,
		"event_type": event_name,
		"actor_id": int(actor.id) if actor != null else -1,
		"target_id": int(target.id) if target != null else -1,
		"source": str(context.get("source", "superhero_engine.capability_affordance")),
		"superhero": true,
		"power": true,
		"public": true,
		"report": report.duplicate(true)
	}
	var upce_result: Variant = gs.upce_engine.call("interpret_event", event_payload, {
		"source": str(context.get("source", "superhero_engine.capability_affordance")),
		"capability_affordance": true
	})
	if typeof(upce_result) == TYPE_DICTIONARY:
		return upce_result
	return {
		"success": false,
		"reason": "upce_returned_non_dictionary"
	}


func _append_unique_string(out: Array, value: String) -> void:
	var clean_value: String = str(value).strip_edges().to_lower()
	if clean_value == "":
		return
	if clean_value not in out:
		out.append(clean_value)
func _eligible_superhero_crime_context_rows(contract: Dictionary, action_id: String, era_key: String, mode_key: String, payload: Dictionary = {}) -> Array:
	var rows: Array = _safe_array(contract.get("rows", []))
	var eligible_rows: Array = []
	var clean_action: String = str(action_id).strip_edges().to_lower()
	var clean_era: String = str(era_key).strip_edges().to_lower()
	var clean_mode: String = str(mode_key).strip_edges().to_lower()

	for raw_row in rows:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = _safe_dictionary(raw_row)
		if row.is_empty():
			continue

		if not _superhero_context_string_array_matches(row.get("actions", []), clean_action, true):
			continue
		if not _superhero_context_string_array_matches(row.get("eras", []), clean_era, true):
			continue
		if not _superhero_context_string_array_matches(row.get("modes", []), clean_mode, true):
			continue

		var min_power_rating: int = int(row.get("min_power_rating", 0))
		if min_power_rating > 0 and int(payload.get("actor_power_rating", 0)) > 0:
			if int(payload.get("actor_power_rating", 0)) < min_power_rating:
				continue

		eligible_rows.append(row.duplicate(true))

	if eligible_rows.is_empty():
		for raw_row in rows:
			if typeof(raw_row) != TYPE_DICTIONARY:
				continue

			var fallback_row: Dictionary = _safe_dictionary(raw_row)
			if fallback_row.is_empty():
				continue
			if not _superhero_context_string_array_matches(fallback_row.get("actions", []), clean_action, true):
				continue

			eligible_rows.append(fallback_row.duplicate(true))

	return eligible_rows


func _pick_weighted_superhero_crime_context_row(rows: Array) -> Dictionary:
	if rows.is_empty():
		return {}

	var total_weight: int = 0
	for raw_row in rows:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = _safe_dictionary(raw_row)
		total_weight += max(1, int(row.get("weight", 1)))

	if total_weight <= 0:
		return _safe_dictionary(rows [randi() % rows.size()])

	var roll: int = randi_range(1, total_weight)
	var cursor: int = 0

	for raw_row in rows:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = _safe_dictionary(raw_row)
		cursor += max(1, int(row.get("weight", 1)))
		if roll <= cursor:
			return row.duplicate(true)

	return _safe_dictionary(rows.back())


func _superhero_context_string_array_matches(raw_values: Variant, value: String, allow_empty: bool = true) -> bool:
	var values: Array = _safe_array(raw_values)
	if values.is_empty():
		return allow_empty

	var clean_value: String = str(value).strip_edges().to_lower()
	for raw_value in values:
		var clean_row_value: String = str(raw_value).strip_edges().to_lower()
		if clean_row_value == "all" or clean_row_value == clean_value:
			return true

	return false


func _current_superhero_crime_mode_key(payload: Dictionary = {}) -> String:
	var raw: String = str(payload.get("game_mode", payload.get("mode", payload.get("reality_mode", "")))).strip_edges().to_lower()

	if raw == "" and gs != null:
		if "game_mode" in gs:
			raw = str(gs.game_mode).strip_edges().to_lower()
		elif "current_game_mode" in gs:
			raw = str(gs.current_game_mode).strip_edges().to_lower()
		elif "mode" in gs:
			raw = str(gs.mode).strip_edges().to_lower()

	if raw.find("real") >= 0:
		return "realistic"
	if raw.find("chaos") >= 0 or raw.find("fantasy") >= 0:
		return "chaos"
	if raw.find("enhanced") >= 0 or raw.find("super") >= 0:
		return "enhanced"

	return "enhanced"


func _default_superhero_crime_context_contract() -> Dictionary:
	return {
		"schema": "eralife.superhero_crime_context_contract",
		"version": CONTRACT_VERSION,
		"id": "superhero.crime_context.default",
		"moddable": true,
		"preserve_unknown_fields": true,
		"selection_policy": {
			"era_aware": true,
		},
		"rows": [
			{
				"crime_id": "ancient_temple_relic_theft",
				"crime_label": "temple relic theft",
				"reason": "they believe the relic belongs to anyone strong enough to take it",
				"stakes": "sacred_artifact",
				"scene": "inside a candlelit temple where priests are trying to hide the inner vault keys",
				"victim_profile": "temple guardians and frightened worshippers",
				"visibility": "public_religious",
				"urgency": "high",
				"eras": ["ancient"],
				"modes": ["all"],
				"actions": ["respond_to_crime", "track_villain", "patrol_city"],
				"tags": ["artifact", "religion", "public_fear"],
				"weight": 12
			},
			{
				"crime_id": "ancient_market_tribute_extortion",
				"crime_label": "market tribute extortion",
				"reason": "they are forcing merchants to pay tribute before the city guard can organize",
				"stakes": "market_district",
				"scene": "in an open market where food stalls are overturned and guards are pretending not to see",
				"victim_profile": "merchants, families, and traveling traders",
				"visibility": "crowded_public",
				"urgency": "medium",
				"eras": ["ancient"],
				"modes": ["all"],
				"actions": ["respond_to_crime", "patrol_city"],
				"tags": ["extortion", "class_pressure", "public_fear"],
				"weight": 14
			},
			{
				"crime_id": "ancient_oracle_hostage",
				"crime_label": "oracle hostage crisis",
				"reason": "they want a prophecy changed, stolen, or silenced before it reaches the ruler",
				"stakes": "prophecy_chain",
				"scene": "beneath an oracle chamber where smoke, guards, and panic all blur together",
				"victim_profile": "oracle attendants and royal messengers",
				"visibility": "restricted_public",
				"urgency": "high",
				"eras": ["ancient"],
				"modes": ["enhanced", "chaos"],
				"actions": ["respond_to_crime", "track_villain"],
				"tags": ["hostage", "prophecy", "royalty"],
				"weight": 9
			},
			{
				"crime_id": "ancient_cursed_beast_release",
				"crime_label": "cursed beast release",
				"reason": "they released something ancient to make the city kneel before anyone understands the curse",
				"stakes": "city_survival",
				"scene": "near broken bronze gates where something huge is breathing in the dust",
				"victim_profile": "guards, civilians, and anyone too slow to run",
				"visibility": "mass_panic",
				"urgency": "critical",
				"eras": ["ancient"],
				"modes": ["chaos"],
				"actions": ["respond_to_crime", "track_villain", "patrol_city"],
				"tags": ["monster", "curse", "mass_panic"],
				"weight": 6
			},
			{
				"crime_id": "ancient_arena_blood_debt",
				"crime_label": "arena blood debt",
				"reason": "they are collecting an old debt in front of the crowd so nobody forgets who owns fear",
				"stakes": "public_execution",
				"scene": "at the edge of an arena tunnel while the crowd chants for violence",
				"victim_profile": "a marked debtor and everyone close enough to become leverage",
				"visibility": "public_spectacle",
				"urgency": "high",
				"eras": ["ancient"],
				"modes": ["all"],
				"actions": ["track_villain", "respond_to_crime"],
				"tags": ["revenge", "public_humiliation", "violence"],
				"weight": 10
			},
			{
				"crime_id": "medieval_caravan_ambush",
				"crime_label": "caravan ambush",
				"reason": "they are stealing medicine, coin, and letters before the next town can survive winter",
				"stakes": "trade_route",
				"scene": "on a muddy road where a caravan is boxed in by masked riders",
				"victim_profile": "travelers, merchants, and a wounded courier",
				"visibility": "rural_witnesses",
				"urgency": "medium",
				"eras": ["medieval"],
				"modes": ["all"],
				"actions": ["respond_to_crime", "patrol_city", "track_villain"],
				"tags": ["ambush", "trade", "survival"],
				"weight": 14
			},
			{
				"crime_id": "medieval_noble_ransom",
				"crime_label": "noble ransom",
				"reason": "they know one hostage can move more gold than a hundred robberies",
				"stakes": "political_hostage",
				"scene": "outside a stone manor where banners are torn and servants are locked outside",
				"victim_profile": "a noble heir, servants, and terrified guards",
				"visibility": "political",
				"urgency": "high",
				"eras": ["medieval"],
				"modes": ["all"],
				"actions": ["respond_to_crime", "track_villain"],
				"tags": ["hostage", "ransom", "politics"],
				"weight": 11
			},
			{
				"crime_id": "medieval_guild_vault_break",
				"crime_label": "guild vault break-in",
				"reason": "they are stealing maps, ledgers, and blackmail records from a guild that pretends it has no enemies",
				"stakes": "guild_power",
				"scene": "under a guild hall where torchlight flashes over a cracked vault door",
				"victim_profile": "guild guards and clerks who know too much",
				"visibility": "semi_private",
				"urgency": "medium",
				"eras": ["medieval"],
				"modes": ["all"],
				"actions": ["track_villain", "respond_to_crime"],
				"tags": ["theft", "guild", "blackmail"],
				"weight": 12
			},
			{
				"crime_id": "medieval_witch_hunter_raid",
				"crime_label": "witch hunter raid",
				"reason": "they are using fear of powers to justify hurting people who cannot defend themselves",
				"stakes": "persecution",
				"scene": "in a village square where accusations are moving faster than truth",
				"victim_profile": "accused villagers and anyone with visible abilities",
				"visibility": "public_mob",
				"urgency": "critical",
				"eras": ["medieval"],
				"modes": ["enhanced", "chaos"],
				"actions": ["respond_to_crime", "patrol_city"],
				"tags": ["persecution", "powers", "mob"],
				"weight": 9
			},
			{
				"crime_id": "medieval_plague_cure_blackmail",
				"crime_label": "plague cure blackmail",
				"reason": "they are hoarding the only cure and selling hope back to dying families",
				"stakes": "public_health",
				"scene": "behind an apothecary where desperate people are being turned away",
				"victim_profile": "sick families, healers, and guards afraid to intervene",
				"visibility": "public_crisis",
				"urgency": "critical",
				"eras": ["medieval"],
				"modes": ["all"],
				"actions": ["respond_to_crime", "track_villain"],
				"tags": ["medicine", "blackmail", "class_pressure"],
				"weight": 8
			},
			{
				"crime_id": "industrial_rail_yard_sabotage",
				"crime_label": "rail yard sabotage",
				"reason": "they are trying to cripple supply lines before anyone connects the explosions",
				"stakes": "transportation",
				"scene": "between smoking rail cars while workers run from a boiler starting to scream",
				"victim_profile": "rail workers, passengers, and nearby factory families",
				"visibility": "public_industrial",
				"urgency": "critical",
				"eras": ["industrial"],
				"modes": ["all"],
				"actions": ["respond_to_crime", "track_villain", "patrol_city"],
				"tags": ["sabotage", "infrastructure", "explosion"],
				"weight": 12
			},
			{
				"crime_id": "industrial_factory_hostage",
				"crime_label": "factory hostage crisis",
				"reason": "they are forcing the owner to pay while trapped workers become leverage",
				"stakes": "workers",
				"scene": "inside a factory where gears keep turning even though everyone is screaming",
				"victim_profile": "factory workers, foremen, and child laborers hiding under machines",
				"visibility": "public_industrial",
				"urgency": "high",
				"eras": ["industrial"],
				"modes": ["all"],
				"actions": ["respond_to_crime"],
				"tags": ["hostage", "labor", "class_pressure"],
				"weight": 13
			},
			{
				"crime_id": "industrial_clockwork_bank_heist",
				"crime_label": "clockwork bank heist",
				"reason": "they built a machine that can crack the vault before the police understand what they are seeing",
				"stakes": "bank_vault",
				"scene": "inside a marble bank where a hissing machine is chewing through the vault door",
				"victim_profile": "bankers, customers, and guards outmatched by technology",
				"visibility": "public_money",
				"urgency": "medium",
				"eras": ["industrial"],
				"modes": ["enhanced", "chaos"],
				"actions": ["respond_to_crime", "track_villain"],
				"tags": ["heist", "technology", "wealth"],
				"weight": 11
			},
			{
				"crime_id": "industrial_newspaper_blackmail",
				"crime_label": "newspaper blackmail",
				"reason": "they are threatening to expose secret identities unless the city pays for silence",
				"stakes": "identity_exposure",
				"scene": "behind a printing press where tomorrow's headline is already locked in metal type",
				"victim_profile": "masked heroes, witnesses, and families tied to secret identities",
				"visibility": "media",
				"urgency": "high",
				"eras": ["industrial"],
				"modes": ["enhanced", "chaos"],
				"actions": ["track_villain", "respond_to_crime"],
				"tags": ["blackmail", "identity", "media"],
				"weight": 9
			},
			{
				"crime_id": "industrial_serum_lab_breakin",
				"crime_label": "serum lab break-in",
				"reason": "they want experimental serum before the lab buries what it created",
				"stakes": "experimental_power",
				"scene": "inside a private laboratory where glass tanks are cracking one by one",
				"victim_profile": "scientists, guards, and unstable test subjects",
				"visibility": "secret_facility",
				"urgency": "critical",
				"eras": ["industrial"],
				"modes": ["enhanced", "chaos"],
				"actions": ["track_villain", "respond_to_crime"],
				"tags": ["serum", "experiment", "power_origin"],
				"weight": 7
			},
			{
				"crime_id": "modern_corner_store_hostage",
				"crime_label": "hostage robbery",
				"reason": "they need fast money and believe powered fear will freeze witnesses",
				"stakes": "civilians",
				"scene": "inside a corner store with shaking customers behind the counter",
				"victim_profile": "cashier, customers, and people recording from outside",
				"visibility": "phones_recording",
				"urgency": "high",
				"eras": ["modern"],
				"modes": ["all"],
				"actions": ["respond_to_crime", "patrol_city"],
				"tags": ["hostage", "public", "recorded"],
				"weight": 14
			},
			{
				"crime_id": "modern_armored_truck_heist",
				"crime_label": "armored truck robbery",
				"reason": "they are trying to fund a larger operation before anyone notices the pattern",
				"stakes": "city_block",
				"scene": "beside an armored truck split open in the street",
				"victim_profile": "guards, drivers, pedestrians, and trapped cars",
				"visibility": "traffic_cameras",
				"urgency": "high",
				"eras": ["modern"],
				"modes": ["all"],
				"actions": ["respond_to_crime", "track_villain", "patrol_city"],
				"tags": ["heist", "traffic", "public_damage"],
				"weight": 13
			},
			{
				"crime_id": "modern_powered_extortion",
				"crime_label": "powered extortion",
				"reason": "they think fear is easier to collect than loyalty",
				"stakes": "neighborhood",
				"scene": "outside a family business surrounded by frightened bystanders",
				"victim_profile": "shop owners, neighbors, and kids watching from windows",
				"visibility": "neighborhood",
				"urgency": "medium",
				"eras": ["modern"],
				"modes": ["enhanced", "chaos"],
				"actions": ["respond_to_crime", "track_villain", "patrol_city"],
				"tags": ["extortion", "neighborhood", "reputation"],
				"weight": 12
			},
			{
				"crime_id": "modern_subway_bomb_threat",
				"crime_label": "subway bomb threat",
				"reason": "they want the city frozen while they move something more valuable underground",
				"stakes": "mass_transit",
				"scene": "on a subway platform where the train doors keep opening and nobody knows which bag matters",
				"victim_profile": "commuters, transit workers, and police trying to clear the station",
				"visibility": "mass_panic",
				"urgency": "critical",
				"eras": ["modern"],
				"modes": ["all"],
				"actions": ["respond_to_crime", "track_villain"],
				"tags": ["bomb", "transit", "mass_panic"],
				"weight": 8
			},
			{
				"crime_id": "modern_hospital_hostage",
				"crime_label": "hospital hostage crisis",
				"reason": "they need a doctor, a cure, or leverage badly enough to risk becoming a monster in public",
				"stakes": "hospital",
				"scene": "inside an emergency room where alarms, blood, and fear all sound the same",
				"victim_profile": "patients, nurses, doctors, and families in waiting rooms",
				"visibility": "sensitive_public",
				"urgency": "critical",
				"eras": ["modern"],
				"modes": ["all"],
				"actions": ["respond_to_crime"],
				"tags": ["hostage", "hospital", "moral_pressure"],
				"weight": 9
			},
			{
				"crime_id": "modern_secret_identity_doxxing",
				"crime_label": "secret identity doxxing",
				"reason": "they are leaking hero identities to force powerful people out of hiding",
				"stakes": "identity_exposure",
				"scene": "near a server room where names, addresses, and family ties are already uploading",
				"victim_profile": "heroes, families, classmates, coworkers, and civilians connected to them",
				"visibility": "online",
				"urgency": "high",
				"eras": ["modern"],
				"modes": ["enhanced", "chaos"],
				"actions": ["track_villain", "respond_to_crime"],
				"tags": ["identity", "internet", "family_exposure"],
				"weight": 8
			},
			{
				"crime_id": "future_drone_skyjacking",
				"crime_label": "drone skyjacking",
				"reason": "they hijacked delivery drones to build a moving shield the police cannot safely shoot down",
				"stakes": "airspace",
				"scene": "under a swarm of stolen drones blinking red over a crowded avenue",
				"victim_profile": "pedestrians, drone operators, and emergency responders",
				"visibility": "citywide_live_feed",
				"urgency": "high",
				"eras": ["future"],
				"modes": ["all"],
				"actions": ["respond_to_crime", "track_villain", "patrol_city"],
				"tags": ["drones", "airspace", "technology"],
				"weight": 13
			},
			{
				"crime_id": "future_orbital_power_theft",
				"crime_label": "orbital power theft",
				"reason": "they are siphoning city power from an orbital relay before the blackout reaches hospitals",
				"stakes": "city_grid",
				"scene": "inside a relay control hub while the skyline flickers one district at a time",
				"victim_profile": "technicians, patients on life support, and districts losing power",
				"visibility": "citywide",
				"urgency": "critical",
				"eras": ["future"],
				"modes": ["enhanced", "chaos"],
				"actions": ["respond_to_crime", "track_villain"],
				"tags": ["energy", "infrastructure", "orbital"],
				"weight": 10
			},
			{
				"crime_id": "future_memory_market_abduction",
				"crime_label": "memory market abduction",
				"reason": "they are harvesting memories because identity became the most expensive thing in the city",
				"stakes": "identity_theft",
				"scene": "in a neon clinic where victims wake up missing pieces of themselves",
				"victim_profile": "abducted civilians, black-market doctors, and people who cannot remember their names",
				"visibility": "underground",
				"urgency": "high",
				"eras": ["future"],
				"modes": ["chaos"],
				"actions": ["track_villain", "respond_to_crime"],
				"tags": ["memory", "identity", "black_market"],
				"weight": 7
			},
			{
				"crime_id": "future_quantum_bank_heist",
				"crime_label": "quantum bank heist",
				"reason": "they are stealing money from probability states before the bank can prove the money existed",
				"stakes": "financial_reality",
				"scene": "inside a silent bank where every screen shows a different version of the same robbery",
				"victim_profile": "bank staff, account holders, and auditors losing track of what is real",
				"visibility": "digital_public",
				"urgency": "medium",
				"eras": ["future"],
				"modes": ["enhanced", "chaos"],
				"actions": ["track_villain", "respond_to_crime"],
				"tags": ["probability", "money", "reality_instability"],
				"weight": 8
			},
			{
				"crime_id": "future_android_rights_riot",
				"crime_label": "android rights riot",
				"reason": "they are exploiting a protest to make humans and machines blame each other",
				"stakes": "social_unrest",
				"scene": "between riot shields and android protesters while hacked speakers scream contradictory orders",
				"victim_profile": "androids, civilians, officers, and activists",
				"visibility": "global_stream",
				"urgency": "high",
				"eras": ["future"],
				"modes": ["all"],
				"actions": ["respond_to_crime", "track_villain", "patrol_city"],
				"tags": ["riot", "androids", "social_physics"],
				"weight": 9
			}
		]
	}


func _build_superhero_search_result(_actor: Person, action_id: String, villain: Person, crime_context: Dictionary, encounter_result: Dictionary, causality_report: Dictionary = {}) -> Dictionary:
	var title_text: String = "Searching For Crime" if action_id == "respond_to_crime" else "Tracking Villain"
	var scan_text: String = "You listen for emergency signals in your area." if action_id == "respond_to_crime" else "You start tracking villain movement in your area."
	var signal_text: String = "The signal sharpens around %s." % _person_label(villain)

	return {
		"success": true,
		"schema": "eralife.superhero_search_shell_report",
		"version": CONTRACT_VERSION,
		"action_id": action_id,
		"villain_id": int(villain.id),
		"villain_name": _person_label(villain),
		"crime_context": crime_context.duplicate(true),
		"causality_inversion": causality_report.duplicate(true),
		"text": "%s %s" % [scan_text, signal_text],
		"popup_title": title_text,
		"popup_text": "%s\n\nFinding local pressure...\nReading witness noise...\nChecking powered threat signatures...\n\n%s" % [
			scan_text,
			signal_text
		],
		"popup_footer": "The encounter will surface after the search resolves.",
		"choices": [
			{
				"label": "Follow The Signal",
				"journal_text": "I followed the signal toward %s." % _person_label(villain)
			}
		],
		"followup_result": encounter_result.duplicate(true)
	}


func _build_villain_encounter_result(actor: Person, villain: Person, crime_context: Dictionary, context: Dictionary = {}) -> Dictionary:
	var crime_label: String = str(crime_context.get("crime_label", "powered crime")).strip_edges()
	var reason_text: String = str(crime_context.get("reason", "they think nobody nearby can stop them")).strip_edges()
	var scene_text: String = str(crime_context.get("scene", "in the middle of a tense scene")).strip_edges()
	var capability_packet: Dictionary = _build_capability_graph_packet(actor, villain, crime_context, context)
	var scenario_packet: Dictionary = _capability_scenario_composer_packet(actor, villain, crime_context, context, capability_packet)
	var choices: Array = _base_villain_encounter_choices(actor, villain, crime_context, context)
	choices.append_array(_capability_affordance_contact_choices(actor, villain, crime_context, context, capability_packet))

	var capability_line: String = str(scenario_packet.get("summary", "")).strip_edges()
	if capability_line == "":
		capability_line = "The moment reads your identity, powers, control, era, relationship context, and action history before it offers you options."

	var prompt_text: String = "You find %s %s.\n\nCrime: %s\nReason: %s\n\nPower Read:\nYou: %s\n%s: %s\n\nCapability Read:\n%s\n\nYou can still choose a normal response, but the world now also offers actions based on who you are, what you can do, and how you usually move." % [
		_person_label(villain),
		scene_text,
		crime_label.capitalize(),
		reason_text,
		_power_line(actor),
		_person_label(villain),
		_power_line(villain),
		capability_line
	]

	return {
		"success": true,
		"schema": "eralife.superhero_villain_encounter_prompt",
		"version": CONTRACT_VERSION,
		"villain_id": int(villain.id),
		"villain_name": _person_label(villain),
		"crime_context": crime_context.duplicate(true),
		"battle_context": context.duplicate(true),
		"capability_graph": capability_packet.duplicate(true),
		"scenario_composer_packet": scenario_packet.duplicate(true),
		"text": prompt_text,
		"popup_title": "Crime In Progress",
		"popup_text": prompt_text,
		"popup_footer": "CapabilityGraphResolver → Affordance Composition → UPCE memory pressure.",
		"choices": choices
	}


func resolve_villain_encounter_choice(actor: Person, payload: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "Actor missing."
		}

	var villain: Person = _person_by_id(int(payload.get("villain_id", -1)))
	if villain == null:
		return {
			"success": false,
			"reason": "Villain missing."
		}

	var encounter_choice: String = str(payload.get("encounter_choice", "battle")).strip_edges().to_lower()
	var crime_context: Dictionary = _safe_dictionary(payload.get("crime_context", {}))
	var battle_context: Dictionary = _safe_dictionary(payload.get("battle_context", {}))
	battle_context ["crime_context"] = crime_context.duplicate(true)

	if encounter_choice == "capability_affordance":
		return _resolve_capability_affordance_choice(actor, villain, payload, crime_context, battle_context)

	if encounter_choice == "battle":
		return start_power_battle(actor, villain, battle_context)

	var profile: Dictionary = ensure_hero_profile(actor)
	var actor_rating: int = _power_rating(actor)
	var villain_rating: int = _power_rating(villain)
	var trust: int = int(profile.get("public_trust", 50))
	var talk_score: int = int(actor.willpower) + int(actor.mental_health) + randi_range(0, 40)
	var villain_resistance: int = villain_rating + randi_range(10, 70)

	if encounter_choice == "call_it_over":
		talk_score += int(round(float(actor_rating) * 0.5))
		villain_resistance += 12
		_record_affordance_behavior(actor, {
			"id": "call_it_over",
			"source": "base_contact",
			"style_tags": ["intimidation", "direct_pressure"]
		}, villain, crime_context, "initial_contact")
	else:
		talk_score += int(round(float(trust) * 0.5))
		_record_affordance_behavior(actor, {
			"id": "talk_down",
			"source": "base_contact",
			"style_tags": ["social_resolution", "deescalation"]
		}, villain, crime_context, "initial_contact")

	var accepted: bool = talk_score >= villain_resistance
	if accepted:
		profile ["crimes_stopped"] = int(profile.get("crimes_stopped", 0)) + 1
		profile ["hero_rep"] = int(profile.get("hero_rep", 0)) + 7
		profile ["public_trust"] = clamp(int(profile.get("public_trust", 50)) + 6, 0, 100)
		profile ["hero_rank"] = _hero_rank(int(profile.get("hero_rep", 0)))
		_commit_profile(actor, profile)

		var peaceful_text: String = "%s stops before the crime becomes a battle.\n\nYou win this one without turning the street into a crater." % _person_label(villain)
		var peaceful_report: Dictionary = {
			"success": true,
			"schema": "eralife.superhero_amicable_victory_report",
			"version": CONTRACT_VERSION,
			"villain_id": int(villain.id),
			"encounter_choice": encounter_choice,
			"talk_score": talk_score,
			"villain_resistance": villain_resistance,
			"hero_profile": profile.duplicate(true),
			"text": peaceful_text,
			"popup_title": "Crime Stopped",
			"popup_text": peaceful_text,
			"popup_footer": "No battle needed. Reputation and public trust increased."
		}
		_record_hero_event(peaceful_report)
		_emit_capability_affordance_upce(actor, villain, peaceful_report, {
			"event_name": "heroic_rescue",
			"source": "superhero_engine.base_contact"
		})
		return peaceful_report

	var refusal_text: String = "%s hears you out for half a second.\n\nThen their expression changes.\n\nThey are not standing down." % _person_label(villain)
	return {
		"success": true,
		"schema": "eralife.superhero_villain_refusal_report",
		"version": CONTRACT_VERSION,
		"villain_id": int(villain.id),
		"encounter_choice": encounter_choice,
		"talk_score": talk_score,
		"villain_resistance": villain_resistance,
		"text": refusal_text,
		"popup_title": "They Refuse",
		"popup_text": refusal_text,
		"popup_footer": "The peaceful route failed. Battle pressure is now live.",
		"choices": [
			{
				"label": "Battle With Your Abilities",
				"journal_text": "They refused to stand down, so I prepared to fight."
			}
		],
		"followup_result": start_power_battle(actor, villain, battle_context)
	}
func _power_battle_scenario_popup_result(_actor: Person, villain: Person, scenario: Dictionary, context: Dictionary = {}) -> Dictionary:
	var choices: Array = []
	var scenario_choices: Array = _safe_array(scenario.get("choices", []))
	for raw_choice in scenario_choices:
		if typeof(raw_choice) != TYPE_DICTIONARY:
			continue
		var scenario_choice: Dictionary = _safe_dictionary(raw_choice)
		var choice_payload: Dictionary = _safe_dictionary(scenario_choice.get("payload", {}))
		var engine_payload: Dictionary = {
			"action": "resolve_power_battle_action",
			"villain_id": int(villain.id),
			"battle_context": context.duplicate(true)
		}
		for raw_key in choice_payload.keys():
			engine_payload [raw_key] = choice_payload.get(raw_key)

		choices.append({
			"label": str(scenario_choice.get("label", "Choose")),
			"detail_action": "engine_call",
			"engine_property": "superhero_engine",
			"method": "resolve_hub_action",
			"payload": engine_payload
		})

	return {
		"success": true,
		"schema": "eralife.power_battle_popup_prompt",
		"version": CONTRACT_VERSION,
		"scenario_id": str(scenario.get("id", "")),
		"villain_id": int(villain.id),
		"villain_name": _person_label(villain),
		"text": str(scenario.get("prompt", "")),
		"popup_title": str(scenario.get("panel_title", "SUPER POWER BATTLE")),
		"popup_text": str(scenario.get("prompt", "")),
		"popup_footer": str(scenario.get("footer_text", "Choose your battle response.")),
		"choices": choices,
		"scenario": scenario.duplicate(true)
	}


func resolve_power_battle_action(actor: Person, payload: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "Actor missing."
		}

	var villain: Person = _person_by_id(int(payload.get("villain_id", -1)))
	if villain == null:
		return {
			"success": false,
			"reason": "Villain missing."
		}

	var battle_context: Dictionary = _safe_dictionary(payload.get("battle_context", {}))
	var scenario: Dictionary = _build_power_battle_scenario(actor, villain, battle_context)
	var choice_payload: Dictionary = {
		"battle_action": str(payload.get("battle_action", "direct_engage")),
		"score_modifier": int(payload.get("score_modifier", 0)),
		"public_trust_modifier": int(payload.get("public_trust_modifier", 0)),
		"legal_risk_modifier": int(payload.get("legal_risk_modifier", 0)),
		"corruption_gain": float(payload.get("corruption_gain", 0.0)),
		"skill_point_gain": int(payload.get("skill_point_gain", 1)),
		"style_tags": _safe_array(payload.get("style_tags", [])),
		"capability_affordance": _safe_dictionary(payload.get("capability_affordance", {})),
		"capability_graph": _safe_dictionary(payload.get("capability_graph", {})),
		"risk_profile": _safe_dictionary(payload.get("risk_profile", {})),
		"social_implication": _safe_dictionary(payload.get("social_implication", {}))
	}

	return _resolve_power_battle_choice(actor, scenario, {
		"id": "power_battle_direct_runtime_choice",
		"label": str(payload.get("label", "Battle")),
		"payload": choice_payload
	}, {})

func _grant_power_battle_skill_points(actor: Person, amount: int, reason: String) -> Dictionary:
	var report: Dictionary = {
		"success": false,
		"schema": "eralife.power_battle_skill_point_report",
		"version": CONTRACT_VERSION,
		"person_id": int(actor.id) if actor != null else -1,
		"amount": amount,
		"reason": reason
	}
	if actor == null or amount <= 0:
		report ["reason"] = "invalid_actor_or_amount"
		return report
	if gs == null or gs.power_engine == null:
		report ["reason"] = "power_engine_unavailable"
		return report
	if not gs.power_engine.has_method("ensure_person_power_state"):
		report ["reason"] = "power_state_unavailable"
		return report

	var power_state: Dictionary = gs.power_engine.ensure_person_power_state(actor)
	power_state ["power_skill_points"] = int(power_state.get("power_skill_points", 0)) + amount
	power_state ["updated_year"] = _current_year()

	if gs.power_engine.has_method("_world_state") and gs.power_engine.has_method("_commit_world_state"):
		var state: Dictionary = gs.power_engine.call("_world_state")
		var person_states: Dictionary = _safe_dictionary(state.get("person_power_state", {}))
		person_states [_person_key(actor)] = power_state.duplicate(true)
		state ["person_power_state"] = person_states
		gs.power_engine.call("_commit_world_state", state)
		report ["success"] = true
		report ["new_total"] = int(power_state.get("power_skill_points", 0))
	else:
		report ["reason"] = "power_engine_commit_unavailable"

	return report
func get_dashboard_rows(context: Dictionary = {}) -> Array:
	var actor: Person = _context_actor(context)
	if actor == null:
		return []

	var profile: Dictionary = ensure_hero_profile(actor)
	var powered: bool = _actor_can_super(actor)

	return [
		{
			"label": "Identity: %s • Rank: %s • Trust %d%%" % [
				str(profile.get("alignment", "civilian")).capitalize(),
				str(profile.get("hero_rank", "unknown")).capitalize(),
				int(profile.get("public_trust", 50))
			],
			"description": "Hero Rep: %d • Crimes Stopped: %d • Villains Defeated: %d • Powered: %s" % [
				int(profile.get("hero_rep", 0)),
				int(profile.get("crimes_stopped", 0)),
				int(profile.get("villains_defeated", 0)),
				"Yes" if powered else "No"
			]
		}
	]

func get_patrol_rows(_context: Dictionary = {}) -> Array:
	return [
		{
			"label": "Patrol City",
			"description": "Move through the city and let the engine surface crimes, rescues, villains, reputation pressure, and public damage."
		}
	]

func get_crime_response_rows(_context: Dictionary = {}) -> Array:
	return [
		{
			"label": "Respond To Crime",
			"description": "Jump directly into an active powered crime. This can create a power battle scenario."
		}
	]

func get_villain_rows(_context: Dictionary = {}) -> Array:
	var state: Dictionary = _world_state()
	var villains: Dictionary = _safe_dictionary(state.get("villain_index", {}))
	var out: Array = []

	if villains.is_empty():
		out.append({
			"label": "No tracked villains",
			"description": "Patrol or respond to crime to surface powered villains."
		})
		return out

	for raw_id in villains.keys():
		var row: Dictionary = _safe_dictionary(villains.get(raw_id, {}))
		out.append({
			"label": "%s • Threat %d" % [
				str(row.get("name", "Unknown Villain")),
				int(row.get("threat", 1))
			],
			"description": "Last seen: %s" % str(row.get("last_seen", "Unknown"))
		})

	return out

func get_team_rows(context: Dictionary = {}) -> Array:
	var actor: Person = _context_actor(context)
	if actor == null:
		return []

	var profile: Dictionary = ensure_hero_profile(actor)
	var team_id: String = str(profile.get("team_id", "")).strip_edges()
	if team_id == "":
		return [
			{
				"label": "No Team Yet",
				"description": "Create a team from Public Life to unlock My Team recruitment.",
				"overview_lines": [
					"You do not have a team yet.",
					"Once founded, this section becomes your team command center."
				]
			}
		]

	var state: Dictionary = _world_state()
	var teams: Dictionary = _safe_dictionary(state.get("hero_teams", {}))
	var team: Dictionary = _safe_dictionary(teams.get(team_id, {}))
	var member_ids: Array = _safe_array(team.get("member_ids", []))

	return [
		{
			"id": "my_team_command_center",
			"label": "%s • Members %d • Team Rep %d" % [
				str(team.get("name", "Hero Team")),
				member_ids.size(),
				int(team.get("team_rep", 0))
			],
			"description": "Founder: %s • Type: %s" % [
				_person_label(actor),
				str(team.get("team_type", "crime_fighting_team")).replace("_", " ").capitalize()
			],
			"overview_title": "My Team",
			"overview_lines": [
				"Team: %s" % str(team.get("name", "Hero Team")),
				"Type: %s" % str(team.get("team_type", "crime_fighting_team")).replace("_", " ").capitalize(),
				"Members: %d" % member_ids.size(),
				"Team Rep: %d" % int(team.get("team_rep", 0)),
				"Founder: %s" % _person_label(actor)
			],
			"actions": [
				{
					"id": "search_team_heroes",
					"label": "Search For Heroes",
					"engine_property": "superhero_engine",
					"method": "resolve_hub_action",
					"payload": {
						"action": "search_team_candidate",
						"candidate_alignment": "hero"
					},
					"refresh_after": true
				},
				{
					"id": "search_team_villains",
					"label": "Search For Villains",
					"engine_property": "superhero_engine",
					"method": "resolve_hub_action",
					"payload": {
						"action": "search_team_candidate",
						"candidate_alignment": "villain"
					},
					"refresh_after": true
				}
			]
		}
	]

func get_reputation_rows(context: Dictionary = {}) -> Array:
	var actor: Person = _context_actor(context)
	if actor == null:
		return []

	var profile: Dictionary = ensure_hero_profile(actor)

	return [
		{
			"label": "Hero Rep %d • Public Trust %d%% • Rank %s" % [
				int(profile.get("hero_rep", 0)),
				int(profile.get("public_trust", 50)),
				str(profile.get("hero_rank", "unknown")).capitalize()
			],
			"description": "Reputation is changed by patrols, rescues, reckless power use, team leadership, and villain battles."
		}
	]

func get_live_event_rows(_context: Dictionary = {}) -> Array:
	var state: Dictionary = _world_state()
	var events: Array = _safe_array(state.get("live_events", []))

	if events.is_empty():
		return [
			{
				"label": "No live super events",
				"description": "The city is quiet. That is usually a lie."
			}
		]

	var out: Array = []
	for raw_event in events:
		if typeof(raw_event) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = raw_event
		out.append({
			"label": str(event.get("label", "Live Event")),
			"description": str(event.get("description", ""))
		})

	return out
func build_superhero_hub_payload(actor: Person, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "Actor missing."
		}

	var profile: Dictionary = ensure_hero_profile(actor)
	var power_state: Dictionary = _power_state_for_actor(actor)
	var power_level: int = _power_rating(actor)
	var power_tier: String = _power_level_tier(power_level)

	profile ["power_level"] = power_level
	profile ["power_tier"] = power_tier
	profile ["hero_rank"] = _hero_rank(int(profile.get("hero_rep", 0)))
	_commit_profile(actor, profile)

	var fighting_record: String = "%d-%d-%d" % [
		int(profile.get("villains_defeated", 0)),
		int(profile.get("losses", 0)),
		int(profile.get("draws", 0))
	]

	var identity_packet: Dictionary = _superhero_hub_identity_packet(actor, profile, power_state)
	var power_read_rows: Array = _power_reader_rows(actor, profile, power_state, power_level, power_tier, fighting_record)
	var mutation_entries: Array = _mutated_ability_entry_rows(actor)

	var forwarded_context: Dictionary = context.duplicate(true)
	forwarded_context ["actor_id"] = int(actor.id)
	forwarded_context ["profile"] = profile.duplicate(true)

	var sections: Array = [
		{
			"id": "hero_actions",
			"title": "PUBLIC LIFE",
			"clickable": true,
			"render_mode": "action_grid",
			"rows": [],
			"actions": _superhero_hub_action_rows(forwarded_context)
		},
		{
			"id": "power_reader",
			"title": "INNER POWER READER",
			"clickable": true,
			"render_mode": "info_card",
			"info_title": "INNER POWER",
			"rows": [],
			"lines": power_read_rows
		}
	]

	if not mutation_entries.is_empty():
		sections.append({
			"id": "mutated_abilities",
			"title": "PUBLIC MUTATION FILE",
			"clickable": true,
			"rows": mutation_entries
		})

	sections.append({
		"id": "lineage_abilities",
		"title": "FAMILY EXPOSURE / LINEAGE",
		"clickable": true,
		"rows": _superhero_hub_entry_rows("lineage_abilities", _lineage_power_rows(actor))
	})

	sections.append({
		"id": "registration_laws",
		"title": "REGISTRATION LAWS",
		"clickable": true,
		"rows": _registration_law_entry_rows(forwarded_context)
	})

	sections.append({
		"id": "agencies",
		"title": "HERO / VILLAIN FACTIONS",
		"clickable": true,
		"rows": _agency_entry_rows(forwarded_context)
	})
	var active_team_id: String = str(profile.get("team_id", "")).strip_edges()
	if active_team_id != "":
		sections.append({
			"id": "my_team",
			"title": "MY TEAM",
			"clickable": true,
			"rows": _superhero_hub_entry_rows("my_team", get_team_rows(forwarded_context))
		})
	sections.append({
		"id": "live_events",
		"title": "LIVE SUPER SOCIETY",
		"clickable": true,
		"rows": _superhero_hub_entry_rows("live_events", get_live_event_rows(forwarded_context))
	})

	sections.append({
		"id": "power_levels",
		"title": "POWER LEVEL SCALE",
		"clickable": true,
		"rows": _superhero_hub_entry_rows("power_levels", get_power_level_rows(forwarded_context))
	})

	sections.append({
		"id": "bloodline_hunters",
		"title": "BLOODLINE HUNTERS",
		"clickable": true,
		"rows": _superhero_hub_entry_rows("bloodline_hunters", get_bloodline_hunter_rows(forwarded_context))
	})

	sections.append({
		"id": "awakening_payoffs",
		"title": "AWAKENING PAYOFFS",
		"clickable": true,
		"rows": _superhero_hub_entry_rows("awakening_payoffs", get_awakening_payoff_rows(forwarded_context))
	})

	if _serum_programs_available():
		sections.append({
			"id": "serum_programs",
			"title": "GOVERNMENT SERUM PROGRAMS",
			"clickable": true,
			"rows": _serum_program_entry_rows(forwarded_context)
		})

	return {
		"success": true,
		"schema": "eralife.superhero_hub_overlay_payload",
		"version": CONTRACT_VERSION,
		"actor_id": int(actor.id),
		"actor_name": _person_label(actor),
		"hub_identity": identity_packet.duplicate(true),
		"profile": profile.duplicate(true),
		"power_state": power_state.duplicate(true),
		"power_level": power_level,
		"power_tier": power_tier,
		"hero_tier": str(profile.get("hero_rank", "unknown")),
		"fighting_record": fighting_record,
		"power_level_label": "%s • %d" % [
			power_tier.replace("_", " ").capitalize(),
			power_level
		],
		"power_line": _power_line(actor),
		"power_read_rows": power_read_rows,
		"default_section_id": "hero_actions",
		"sections": sections
	}

func register_powered_identity(actor: Person, _payload: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "Actor missing."
		}

	var profile: Dictionary = ensure_hero_profile(actor)
	profile ["registration_status"] = "registered"
	profile ["legal_risk"] = max(0, int(profile.get("legal_risk", 0)) - 18)
	profile ["public_trust"] = clamp(int(profile.get("public_trust", 50)) + 6, 0, 100)
	_commit_profile(actor, profile)

	return {
		"success": true,
		"schema": "eralife.powered_registration_report",
		"text": "You register your powered identity. The government now has a file with your name on it. That is safety, leverage, and danger all at once.",
		"popup_title": "Identity Registered",
		"popup_text": "Your powered identity is now registered.\n\nPublic Trust increased.\nLegal Risk decreased.\nBloodline exposure increased.",
		"popup_footer": "Tap anywhere to continue.",
	}


func join_hero_agency(actor: Person, payload: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "Actor missing."
		}

	var agency_id: String = str(payload.get("agency_id", "city_watch_agency")).strip_edges().to_lower()
	var agency: Dictionary = _agency_row_by_id(agency_id)
	if agency.is_empty():
		return {
			"success": false,
			"reason": "Faction not found for this era.",
			"agency_id": agency_id
		}

	var profile: Dictionary = ensure_hero_profile(actor)
	var power_level: int = _power_rating(actor)
	var eligibility: Dictionary = _agency_join_eligibility(actor, profile, agency, power_level)
	if not bool(eligibility.get("eligible", false)):
		return {
			"success": false,
			"schema": "eralife.hero_agency_join_blocked",
			"agency_id": agency_id,
			"agency_name": str(agency.get("name", agency_id)),
			"reason": str(eligibility.get("reason", "You do not meet this faction's entry requirements.")),
			"popup_title": "Faction Locked",
			"popup_text": str(eligibility.get("reason", "You do not meet this faction's entry requirements.")),
			"popup_footer": "Build your record, power, tactics, or reputation first."
		}

	var agency_name: String = str(agency.get("name", _agency_name(agency_id)))
	var alignment: String = str(agency.get("alignment", "hero")).strip_edges().to_lower()

	profile ["agency_id"] = agency_id
	profile ["agency_name"] = agency_name
	profile ["agency_alignment"] = alignment
	profile ["agency_joined_year"] = _current_year()
	profile ["agency_leader_name"] = str(agency.get("leader_name", "Unknown Leader"))
	profile ["agency_leader_power_level"] = int(agency.get("leader_power_level", 0))

	if alignment == "villain":
		profile ["alignment"] = "villain"
	else:
		profile ["alignment"] = "hero"

	profile ["hero_rep"] = int(profile.get("hero_rep", 0)) + int(agency.get("join_rep_bonus", 8))
	profile ["public_trust"] = clamp(int(profile.get("public_trust", 50)) + int(agency.get("trust_delta", 2)), 0, 100)

	_commit_profile(actor, profile)

	return {
		"success": true,
		"schema": "eralife.hero_agency_join_report",
		"agency_id": agency_id,
		"agency_name": agency_name,
		"alignment": alignment,
		"leader_name": str(profile.get("agency_leader_name", "")),
		"leader_power_level": int(profile.get("agency_leader_power_level", 0)),
		"text": "You join %s. You are no longer just a powered person. You are part of a machine with history, enemies, leaders, and expectations." % agency_name,
		"popup_title": "Faction Joined",
		"popup_text": "You joined %s.\n\nLeader: %s\nLeader Power Level: %d\n\nFaction access unlocked." % [
			agency_name,
			str(profile.get("agency_leader_name", "")),
			int(profile.get("agency_leader_power_level", 0))
		],
		"popup_footer": "Tap anywhere to continue."
	}


func get_registration_law_rows(_context: Dictionary = {}) -> Array:
	var law: Dictionary = _active_registration_law()
	return [
		"Current Law: %s" % str(law.get("label", "Unregulated")).capitalize(),
		"Policy: %s" % str(law.get("description", "No active powered registration law.")),
		"Enforcement: %s" % str(law.get("enforcement", "low")).capitalize(),
		"Secret identities carry Legal Risk if exposed."
	]


func get_agency_rows(_context: Dictionary = {}) -> Array:
	var society: Dictionary = _safe_dictionary(active_contract.get("society_simulation", {}))
	var agencies: Array = _safe_array(society.get("agency_tiers", []))
	var rows: Array = []

	for raw_agency in agencies:
		if typeof(raw_agency) != TYPE_DICTIONARY:
			continue
		var agency: Dictionary = raw_agency
		rows.append("%s • Tier %s • %s" % [
			str(agency.get("name", "Unknown Agency")),
			str(agency.get("tier", "local")).capitalize(),
			str(agency.get("description", "Agency contract."))
		])

	if rows.is_empty():
		rows.append("No agencies are active in this era.")

	return rows


func get_power_level_rows(_context: Dictionary = {}) -> Array:
	var society: Dictionary = _safe_dictionary(active_contract.get("society_simulation", {}))
	var scale: Array = _safe_array(society.get("power_level_scale", []))
	var rows: Array = []

	for raw_tier in scale:
		if typeof(raw_tier) != TYPE_DICTIONARY:
			continue
		var tier: Dictionary = raw_tier
		rows.append("%s: %s-%s • %s" % [
			str(tier.get("label", "Tier")),
			str(tier.get("min", 0)),
			str(tier.get("max", 0)),
			str(tier.get("description", "Power tier."))
		])

	return rows


func get_bloodline_hunter_rows(_context: Dictionary = {}) -> Array:
	var society: Dictionary = _safe_dictionary(active_contract.get("society_simulation", {}))
	var hunters: Dictionary = _safe_dictionary(society.get("bloodline_hunters", {}))
	return [
		"Enabled: %s" % ("Yes" if bool(hunters.get("enabled", true)) else "No"),
		"Trigger: %s" % str(hunters.get("trigger", "rare_power_lineage_detected")).replace("_", " ").capitalize(),
		"Behavior: Hunters track rare bloodlines, inherited powers, exposed children, and unstable families.",
		"Risk grows when registration, fame, villain conflict, or public power use exposes the bloodline."
	]


func get_serum_program_rows(_context: Dictionary = {}) -> Array:
	if not _serum_programs_available():
		return [
			"No large-scale serum programs are active in this era.",
			"Industrial, Modern, and Future eras can develop state-backed enhancement programs."
		]

	var society: Dictionary = _safe_dictionary(active_contract.get("society_simulation", {}))
	var programs: Array = _safe_array(society.get("government_serum_programs", []))
	var rows: Array = []

	for raw_program in programs:
		if typeof(raw_program) != TYPE_DICTIONARY:
			continue
		var program: Dictionary = raw_program
		rows.append("%s • %s" % [
			str(program.get("name", "Serum Program")),
			str(program.get("description", "Government enhancement program."))
		])

	return rows


func get_awakening_payoff_rows(_context: Dictionary = {}) -> Array:
	return [
		"Age-13 awakening can convert latent lineage power into an active power event.",
		"Trauma awakening can fire when another system marks trauma_awakening_pending on the power state.",
		"Awakening reason is preserved in the PowerEngine grant context.",
		"Future hooks: schools, government watchers, family fear, bloodline hunters, and agency recruiters can all react."
	]
func _superhero_hub_entry_rows(section_id: String, rows: Array) -> Array:
	var out: Array = []
	var clean_section_id: String = str(section_id).strip_edges().to_lower()
	if clean_section_id == "":
		clean_section_id = "section"
	clean_section_id = clean_section_id.replace(" ", "_")
	clean_section_id = clean_section_id.replace(".", "_")
	clean_section_id = clean_section_id.replace("/", "_")
	clean_section_id = clean_section_id.replace(":", "_")

	var index: int = 0

	for raw_row in rows:
		var entry: Dictionary = {}
		if typeof(raw_row) == TYPE_DICTIONARY:
			entry = (raw_row as Dictionary).duplicate(true)
		elif typeof(raw_row) == TYPE_NIL:
			index += 1
			continue
		else:
			entry = {
				"label": str(raw_row),
				"description": ""
			}

		var label_text: String = str(entry.get("label", entry.get("title", "Entry"))).strip_edges()
		label_text = label_text.replace("\n", " ").replace("\t", " ").strip_edges()

		var description_text: String = str(entry.get("description", entry.get("text", ""))).strip_edges()

		if label_text == "":
			label_text = "Entry %d" % (index + 1)

		var overview_lines: Array = []
		var overview_raw: Variant = entry.get("overview_lines", entry.get("lines", []))
		if typeof(overview_raw) == TYPE_ARRAY:
			for raw_line in overview_raw:
				if typeof(raw_line) == TYPE_NIL:
					continue
				var line_text: String = str(raw_line).strip_edges()
				if line_text != "":
					overview_lines.append(line_text)
		elif typeof(overview_raw) == TYPE_PACKED_STRING_ARRAY:
			for raw_line in overview_raw:
				var packed_line_text: String = str(raw_line).strip_edges()
				if packed_line_text != "":
					overview_lines.append(packed_line_text)
		else:
			var single_line_text: String = str(overview_raw).strip_edges()
			if single_line_text != "" and single_line_text != "[]":
				overview_lines.append(single_line_text)

		if overview_lines.is_empty():
			overview_lines.append(label_text)
			if description_text != "":
				overview_lines.append(description_text)

		var entry_id: String = str(entry.get("id", "")).strip_edges()
		if entry_id == "":
			entry_id = "%s_%d" % [clean_section_id, index]
		entry_id = entry_id.replace(" ", "_")
		entry_id = entry_id.replace(".", "_")
		entry_id = entry_id.replace("/", "_")
		entry_id = entry_id.replace(":", "_")

		var overview_title_text: String = str(entry.get("overview_title", entry.get("title", label_text))).strip_edges()
		if overview_title_text == "":
			overview_title_text = label_text

		entry ["id"] = entry_id
		entry ["label"] = label_text
		entry ["description"] = description_text
		entry ["overview_title"] = overview_title_text
		entry ["overview_lines"] = overview_lines
		entry ["clickable"] = bool(entry.get("clickable", true))

		if typeof(entry.get("actions", [])) != TYPE_ARRAY:
			entry ["actions"] = []
		if typeof(entry.get("detail_actions", [])) != TYPE_ARRAY:
			entry ["detail_actions"] = []

		out.append(entry)
		index += 1

	if out.is_empty():
		out.append({
			"id": "%s_empty" % clean_section_id,
			"label": "Nothing readable yet.",
			"description": "This section has no active contract rows yet.",
			"overview_title": "Nothing readable yet",
			"overview_lines": [
				"This section has no active contract rows yet.",
				"Future systems can push packets here without rewriting the hub."
			],
			"clickable": true,
			"actions": [],
			"detail_actions": []
		})

	return out

func _registration_law_entry_rows(context: Dictionary = {}) -> Array:
	var law: Dictionary = _active_registration_law()
	var actor: Person = _context_actor(context)
	var profile: Dictionary = ensure_hero_profile(actor) if actor != null else _safe_dictionary(context.get("profile", {}))

	var label_text: String = str(law.get("label", "Unregulated")).replace("_", " ").capitalize()
	var enforcement_text: String = str(law.get("enforcement", "low")).replace("_", " ").capitalize()
	var description_text: String = str(law.get("description", "No active powered registration law."))

	var status_text: String = str(profile.get("registration_status", "unregistered")).strip_edges().to_lower()
	var is_registered: bool = status_text in ["registered", "registered_at_birth", "government_file"]

	var overview_lines: Array = [
		"Current Law: %s" % label_text,
		"Policy: %s" % description_text,
		"Enforcement: %s" % enforcement_text,
		"Secret identities carry Legal Risk if exposed.",
		"Registered identities reduce legal heat, but make agencies and governments better at tracking the powered population."
	]

	var row: Dictionary = {
		"id": "registration_law_current",
		"label": "Current Law: %s" % label_text,
		"description": "Enforcement: %s" % enforcement_text,
		"overview_title": "Registration Law",
		"overview_lines": overview_lines,
		"card_click_opens_detail": true,
		"hide_overview_button": false,
		"actions": [],
		"detail_actions": []
	}

	if not is_registered:
		row ["label"] = "Current Law: %s" % label_text
		row ["description"] = "You are not registered. This section is only showing the law."
		row ["overview_lines"] = overview_lines + [
			"",
			"Status: Not Registered",
			"Crime fighting is still possible through disguises, masks, aliases, and unofficial intervention.",
			"Registration is not required to build a villain-fighting record."
		]
		return [row]

	row ["label"] = "Registered: %s • %s" % [
		status_text.replace("_", " ").capitalize(),
		label_text
	]
	row ["description"] = "Registered public-life actions are available."
	row ["overview_title"] = "Registered Powered Identity"
	row ["overview_lines"] = overview_lines + [
		"",
		"Status: %s" % status_text.replace("_", " ").capitalize(),
		"Legal Risk: %d" % int(profile.get("legal_risk", 0)),
		"Public Trust: %d%%" % int(profile.get("public_trust", 50)),
		"Government File: %s" % ("Yes" if bool(profile.get("government_file", false)) else "No"),
		"Registered actions route through the SuperHeroEngine instead of being hard-coded to UI."
	]
	row ["detail_actions"] = _registered_identity_action_rows(profile)

	return [row]


func _agency_entry_rows(context: Dictionary = {}) -> Array:
	var actor: Person = _context_actor(context)
	var profile: Dictionary = ensure_hero_profile(actor) if actor != null else _safe_dictionary(context.get("profile", {}))
	var power_level: int = _power_rating(actor) if actor != null else int(profile.get("power_level", 0))
	var agencies: Array = _current_era_agency_rows()
	var out: Array = []

	for raw_agency in agencies:
		if typeof(raw_agency) != TYPE_DICTIONARY:
			continue

		var agency: Dictionary = raw_agency
		var agency_id: String = str(agency.get("id", agency.get("name", "agency"))).strip_edges().to_lower()
		var agency_name: String = str(agency.get("name", "Unknown Agency"))
		var era_label: String = str(agency.get("era_label", _current_era_key().capitalize()))
		var alignment_text: String = str(agency.get("alignment", "hero")).replace("_", " ").capitalize()
		var faction_word: String = str(agency.get("faction_word", "Agency"))
		var leader_name: String = str(agency.get("leader_name", "Unknown Leader"))
		var leader_power_level: int = int(agency.get("leader_power_level", 0))
		var required_power: int = int(agency.get("required_power_level", 0))
		var required_wins: int = int(agency.get("min_villain_wins", 0))
		var required_rate: float = float(agency.get("min_win_rate", 0.0))
		var allows_human_elite: bool = bool(agency.get("allows_human_elite", false))
		var eligibility: Dictionary = _agency_join_eligibility(actor, profile, agency, power_level)
		var joined_here: bool = str(profile.get("agency_id", "")).strip_edges().to_lower() == agency_id

		var requirement_lines: Array = [
			"Minimum Age: %d+" % int(agency.get("min_age", 13)),
			"Power Level Needed: %s" % ("Elite human / tactics accepted" if allows_human_elite else str(required_power)),
			"Villain Wins Needed: %d" % required_wins,
			"Win Rate Needed: %d%%" % int(round(required_rate * 100.0))
		]

		out.append({
			"id": agency_id,
			"label": "%s • %s %s" % [
				agency_name,
				era_label,
				faction_word
			],
			"description": "%s faction • Leader: %s • PL %d%s" % [
				alignment_text,
				leader_name,
				leader_power_level,
				" • Joined" if joined_here else ""
			],
			"overview_title": agency_name,
			"overview_lines": [
				"%s: %s" % [faction_word, agency_name],
				"Era: %s" % era_label,
				"Alignment: %s" % alignment_text,
				"Leader: %s" % leader_name,
				"Leader Power Level: %d" % leader_power_level,
				"Lore: %s" % str(agency.get("description", "Faction contract.")),
				"",
				"Entry Requirements:",
			] + requirement_lines + [
				"",
				"Your Power Level: %d" % power_level,
				"Your Villain Wins: %d" % int(profile.get("villains_defeated", 0)),
				"Your Win Rate: %d%%" % int(round(_profile_win_rate(profile) * 100.0)),
				"Eligibility: %s" % ("Eligible" if bool(eligibility.get("eligible", false)) else str(eligibility.get("reason", "Not eligible"))),
				"Faction Hook: Joining stores leader data on your profile so later relationship, sparring, recruitment, betrayal, faction-war, and mentor systems can bind onto the same packet."
			],
			"card_click_opens_detail": true,
			"hide_overview_button": true,
			"detail_actions": [
				{
					"id": "join_agency_%s" % agency_id,
					"label": "Join %s" % agency_name,
					"engine_property": "superhero_engine",
					"method": "resolve_hub_action",
					"disabled": joined_here or not bool(eligibility.get("eligible", false)),
					"disabled_reason": "Already joined." if joined_here else str(eligibility.get("reason", "")),
					"payload": {
						"action": "join_agency",
						"agency_id": agency_id,
						"source": "agency_detail_panel"
					},
					"refresh_after": true
				},
				{
					"id": "meet_agency_leader_%s" % agency_id,
					"label": "Meet %s" % leader_name,
					"engine_property": "superhero_engine",
					"method": "resolve_hub_action",
					"disabled": not joined_here,
					"disabled_reason": "Join this faction before directly interacting with its leader.",
					"payload": {
						"action": "meet_agency_leader",
						"agency_id": agency_id,
						"source": "agency_detail_panel"
					},
					"refresh_after": true
				}
			]
		})

	if out.is_empty():
		out.append({
			"id": "no_agencies",
			"label": "No factions are active in this era.",
			"description": "Powered society has not formalized factions yet.",
			"overview_title": "No Factions",
			"overview_lines": [
				"No hero, villain, order, guild, directorate, network, or agency structures are active in this era.",
				"Future systems can still inject faction contracts without rewriting the hub."
			],
			"clickable": true
		})

	return out

func _serum_program_entry_rows(_context: Dictionary = {}) -> Array:
	var society: Dictionary = _safe_dictionary(active_contract.get("society_simulation", {}))
	var programs: Array = _safe_array(society.get("government_serum_programs", []))
	var out: Array = []

	for raw_program in programs:
		if typeof(raw_program) != TYPE_DICTIONARY:
			continue

		var program: Dictionary = raw_program
		var program_id: String = str(program.get("id", program.get("name", "serum_program"))).strip_edges().to_lower()
		var program_name: String = str(program.get("name", "Serum Program"))
		var description_text: String = str(program.get("description", "Government enhancement program."))

		out.append({
			"id": program_id,
			"label": program_name,
			"description": description_text,
			"overview_title": program_name,
			"overview_lines": [
				"Program: %s" % program_name,
				"Lore: %s" % description_text,
				"Era Gate: Government serum programs only surface in Industrial, Modern, and Future eras.",
				"Gameplay Hook: These programs can eventually route super serum, adamantium surgery, military contracts, surveillance, consent scandals, and black-budget villain creation."
			],
			"clickable": true
		})

	if out.is_empty():
		out.append({
			"id": "no_serum_programs",
			"label": "No serum programs active.",
			"description": "No government enhancement rows are active for this era.",
			"overview_title": "No Serum Programs",
			"overview_lines": [
				"No government serum programs are active right now.",
				"Industrial, Modern, and Future eras can develop state-backed enhancement programs."
			],
			"clickable": true
		})

	return out


func _mutated_ability_entry_rows(actor: Person) -> Array:
	var rows: Array = []

	if gs != null and gs.power_engine != null and gs.power_engine.has_method("get_mutated_ability_rows"):
		var mutation_rows_raw: Array = gs.power_engine.get_mutated_ability_rows(actor, {
			"source": "superhero_hub_payload"
		})

		for raw_mutation in mutation_rows_raw:
			if typeof(raw_mutation) != TYPE_DICTIONARY:
				continue

			var mutation: Dictionary = raw_mutation
			var mutation_id: String = str(mutation.get("id", "mutation")).strip_edges()
			var display_name: String = str(mutation.get("display_name", mutation.get("label", "Mutated Ability")))
			var element_text: String = str(mutation.get("element", "elemental")).replace("_", " ").capitalize()
			var power_name: String = str(mutation.get("power_display_name", mutation.get("power_id", "power")))
			var unlocked_bending_count: int = int(mutation.get("unlocked_bending_ability_count", 0))
			var intentional_locked: bool = bool(mutation.get("intentional_use_locked", unlocked_bending_count <= 0))

			rows.append({
				"id": mutation_id,
				"label": "%s • Power %d • Guard %d" % [
					display_name,
					int(mutation.get("power", 0)),
					int(mutation.get("guard", 0))
				],
				"description": "%s mutation from %s • unlocked bending moves: %d%s" % [
					element_text,
					power_name,
					unlocked_bending_count,
					" • Intentional use locked" if intentional_locked else ""
				],
				"overview_title": display_name,
				"overview_lines": [
					"Mutation: %s" % display_name,
					"Elemental Channel: %s" % element_text,
					"Power Source: %s" % power_name,
					"Power: %d" % int(mutation.get("power", 0)),
					"Guard: %d" % int(mutation.get("guard", 0)),
					"Unlocked bending moves feeding this mutation: %d" % unlocked_bending_count,
					"Intentional Use: %s" % ("Locked until a bending move is unlocked." if intentional_locked else "Unlocked."),
					"Uncontrolled Risk: Mutations can still surge during age-up if the contract marks them unstable."
				],
				"detail_panel_mode": "mutation_overview",
				"actions": [
					{
						"id": "activate_mutation_%s" % mutation_id,
						"label": "Use Mutation",
						"engine_property": "power_engine",
						"method": "resolve_power_action",
						"requires_power_action_panel": true,
						"disabled": intentional_locked,
						"disabled_reason": "Unlock at least one bending move before intentionally using this mutation.",
						"payload": {
							"action": "activate_mutation",
							"mutation_id": mutation_id,
							"source": "superhero_mutated_ability_entry",
							"requires_power_action_panel": true
						},
						"refresh_after": true
					}
				],
				"clickable": true
			})

	return rows

func _power_reader_rows(actor: Person, profile: Dictionary, power_state: Dictionary, power_level: int, power_tier: String, fighting_record: String) -> Array:
	var rows: Array = []
	rows.append("Subject: %s" % _person_label(actor))
	rows.append("Power Level: %s • %d" % [power_tier.replace("_", " ").capitalize(), power_level])
	rows.append("Hero Tier: %s" % str(profile.get("hero_rank", "unknown")).replace("_", " ").capitalize())
	rows.append("Fighting Record: %s" % fighting_record)
	rows.append("Identity: %s" % str(profile.get("alignment", "civilian")).replace("_", " ").capitalize())
	rows.append("Registration: %s" % str(profile.get("registration_status", "unregistered")).replace("_", " ").capitalize())
	rows.append("Latent Potential: %d" % int(power_state.get("latent_potential", 0)))
	rows.append("Fame Multiplier: %.2fx" % float(power_state.get("fame_multiplier", 1.0)))
	rows.append("Hidden Identity Risk: %d%%" % int(round(float(power_state.get("hidden_identity_risk", 0.0)) * 100.0)))
	rows.append("Opponent Bias: %s" % str(power_state.get("opponent_tier_bias", "street_level")).replace("_", " ").capitalize())
	rows.append("Underdog Respect: %.2fx" % float(power_state.get("low_tier_respect_multiplier", 1.0)))
	return rows

func _superhero_hub_action_rows(_context: Dictionary = {}) -> Array:
	return [
		{
			"id": "patrol_city",
			"label": "Patrol City",
			"description": "Move through the city and let the SuperHeroEngine surface crime, quiet years, witnesses, and public trust shifts.",
			"engine_property": "superhero_engine",
			"method": "resolve_hub_action",
			"payload": {
				"action": "patrol_city",
				"source": "superhero_hub_action_section"
			},
			"refresh_after": true
		},
		{
			"id": "respond_to_crime",
			"label": "Respond To Crime",
			"description": "Fight crime without needing registration. Your mask, alias, public identity, and exposure risk decide what the world learns.",
			"engine_property": "superhero_engine",
			"method": "resolve_hub_action",
			"payload": {
				"action": "respond_to_crime",
				"source": "superhero_hub_action_section",
			},
			"refresh_after": true
		},
		{
			"id": "choose_disguise",
			"label": "Choose Disguise",
			"description": "Equip a disguise or alias before operating publicly. Registration is not required to fight crime.",
			"engine_property": "superhero_engine",
			"method": "resolve_hub_action",
			"payload": {
				"action": "choose_disguise",
				"source": "superhero_hub_action_section"
			},
			"refresh_after": true
		},
		{
			"id": "track_villain",
			"label": "Track Villain",
			"description": "Follow a villain trail and create future encounter pressure.",
			"engine_property": "superhero_engine",
			"method": "resolve_hub_action",
			"payload": {
				"action": "track_villain",
				"source": "superhero_hub_action_section"
			},
			"refresh_after": true
		},
		{
			"id": "register_identity",
			"label": "Register / Stay Legal",
			"description": "Interact with the powered registration layer for this era.",
			"engine_property": "superhero_engine",
			"method": "resolve_hub_action",
			"payload": {
				"action": "register_identity",
				"source": "superhero_hub_action_section"
			},
			"refresh_after": true
		},
		{
			"id": "start_team",
			"label": "Create Team",
			"description": "Try to create your own crime fighting organization.",
			"engine_property": "superhero_engine",
			"method": "resolve_hub_action",
			"payload": {
				"action": "start_team",
				"source": "superhero_hub_action_section"
			},
			"refresh_after": true
		},
		{
			"id": "recruit_ally",
			"label": "Recruit Ally",
			"description": "Look for powered allies who can join your team.",
			"engine_property": "superhero_engine",
			"method": "resolve_hub_action",
			"payload": {
				"action": "recruit_ally",
				"source": "superhero_hub_action_section"
			},
			"refresh_after": true
		},
		{
			"id": "watch_live_events",
			"label": "Watch Live Society",
			"description": "Read the live powered society layer without forcing it into every hub section.",
			"engine_property": "superhero_engine",
			"method": "resolve_hub_action",
			"payload": {
				"action": "watch_live_events",
				"source": "superhero_hub_action_section"
			},
			"refresh_after": true
		}
	]
func _all_power_rows(actor: Person) -> Array:
	var power_state: Dictionary = _power_state_for_actor(actor)
	var powers: Dictionary = _safe_dictionary(power_state.get("powers", {}))
	var rows: Array = []

	if powers.is_empty():
		rows.append("No powers are readable yet.")
		return rows

	for raw_power_id in powers.keys():
		var power_id: String = str(raw_power_id).strip_edges().to_lower()
		var row: Dictionary = _safe_dictionary(powers.get(raw_power_id, {}))
		var contract: Dictionary = _power_contract(power_id)

		var label: String = str(contract.get("display_name", power_id.replace("_", " ").capitalize()))
		var rarity: String = str(row.get("rarity", contract.get("rarity", "common"))).replace("_", " ").capitalize()
		var lock_label: String = "Latent / locked" if bool(row.get("latent_locked", false)) else "Awake"
		var unlocked_subskills: Array = _safe_array(row.get("unlocked_subskills", []))
		var all_subskills: Array = _safe_array(row.get("subskills", []))

		rows.append("%s • %s • Level %d • %s" % [
			label,
			rarity,
			int(row.get("level", 1)),
			lock_label
		])
		rows.append("   Power %d / Potential %d • Control %d%% • Chaos %d%%" % [
			int(row.get("base_power_level", 0)),
			int(row.get("latent_potential", 0)),
			int(round(float(row.get("control", 0.0)) * 100.0)),
			int(round(float(row.get("chaos", 0.0)) * 100.0))
		])
		rows.append("   Lore: %s" % _power_lore_description(power_id, row, contract))
		rows.append("   Sub Skills: %s / %s unlocked" % [
			unlocked_subskills.size(),
			all_subskills.size()
		])

	return rows


func _mutated_ability_section_rows(actor: Person) -> Array:
	var rows: Array = []

	if gs != null and gs.power_engine != null and gs.power_engine.has_method("get_mutated_ability_rows"):
		var mutation_rows_raw: Array = gs.power_engine.get_mutated_ability_rows(actor, {
			"source": "superhero_hub_payload"
		})
		for raw_mutation in mutation_rows_raw:
			if typeof(raw_mutation) != TYPE_DICTIONARY:
				continue
			var mutation: Dictionary = raw_mutation
			rows.append("%s • Power %d • Guard %d • %s unlocked bending moves" % [
				str(mutation.get("display_name", mutation.get("label", "Mutated Ability"))),
				int(mutation.get("power", 0)),
				int(mutation.get("guard", 0)),
				int(mutation.get("unlocked_bending_ability_count", 0))
			])

	if rows.is_empty():
		rows.append("🔒 Locked - hybrid mutations reveal after the right trigger.")
		rows.append("Potential triggers: bending fusion, trauma awakening, cosmic exposure, rare lineage instability, or reality-surge mutation.")

	return rows


func _lineage_power_rows(actor: Person) -> Array:
	var rows: Array = []
	var power_state: Dictionary = _power_state_for_actor(actor)
	var family_legacy: Dictionary = _safe_dictionary(power_state.get("family_legacy", {}))

	if not family_legacy.is_empty():
		rows.append({
			"id": "lineage_identity_header",
			"label": "Legacy Type: %s" % str(family_legacy.get("archetype", "powered_family")).replace("_", " ").capitalize(),
			"description": "Identity Style: %s" % str(family_legacy.get("identity_style", "private_household")).replace("_", " ").capitalize(),
			"hide_overview_button": true,
			"overview_title": "Lineage Identity",
			"overview_lines": [
				"Legacy Type: %s" % str(family_legacy.get("archetype", "powered_family")).replace("_", " ").capitalize(),
				"Identity Style: %s" % str(family_legacy.get("identity_style", "private_household")).replace("_", " ").capitalize()
			]
		})

	if gs == null or typeof(gs.npcs) != TYPE_ARRAY:
		if rows.is_empty():
			rows.append({
				"id": "lineage_scan_unavailable",
				"label": "No lineage scan available.",
				"description": "PowerEngine has no readable family graph for this actor yet.",
				"hide_overview_button": true
			})
		return rows

	var actor_last: String = _actor_property_text(actor, "last_name").to_lower()
	var found: int = 0

	for raw_person in gs.npcs:
		if not (raw_person is Person):
			continue

		var relative: Person = raw_person
		if actor != null and int(relative.id) == int(actor.id):
			continue
		if actor_last == "" or _actor_property_text(relative, "last_name").to_lower() != actor_last:
			continue

		var relative_state: Dictionary = _power_state_for_actor(relative)
		var relative_powers: Dictionary = _safe_dictionary(relative_state.get("powers", {}))
		if relative_powers.is_empty():
			continue

		var relative_power_names: Array = []
		for raw_power_id in relative_powers.keys():
			var power_id: String = str(raw_power_id).strip_edges().to_lower()
			var contract: Dictionary = _power_contract(power_id)
			relative_power_names.append(str(contract.get("display_name", power_id.replace("_", " ").capitalize())))

		rows.append({
			"id": "lineage_relative_%d" % int(relative.id),
			"label": "%s • Power %d" % [
				_person_label(relative),
				_power_rating(relative)
			],
			"description": "Powers: %s" % ", ".join(relative_power_names),
			"hide_overview_button": true,
			"overview_title": _person_label(relative),
			"overview_lines": [
				"Relative: %s" % _person_label(relative),
				"Power Level: %d" % _power_rating(relative),
				"Powers: %s" % ", ".join(relative_power_names),
				"Legacy Type: %s" % str(family_legacy.get("archetype", "powered_family")).replace("_", " ").capitalize(),
				"Identity Style: %s" % str(family_legacy.get("identity_style", "private_household")).replace("_", " ").capitalize()
			]
		})

		found += 1
		if found >= 16:
			break

	if found == 0 and rows.is_empty():
		rows.append({
			"id": "lineage_none_readable",
			"label": "No readable powered relatives yet.",
			"description": "Lineage powers can still appear through future birth, mutation, serum, or hidden-family contracts.",
			"hide_overview_button": true
		})

	return rows


func _power_lore_description(_power_id: String, row: Dictionary, contract: Dictionary) -> String:
	var effects: Array = _safe_array(contract.get("effects", []))
	var rarity: String = str(row.get("rarity", contract.get("rarity", "common"))).replace("_", " ").capitalize()
	var effect_text: String = ", ".join(effects) if not effects.is_empty() else "unmapped impossible expression"
	if bool(row.get("family_variant", false)):
		return "%s lineage expression shaped into %s." % [rarity, effect_text]
	if bool(row.get("configured_at_birth", false)):
		return "%s birth-configured power expressing through %s." % [rarity, effect_text]
	return "%s power expressing through %s." % [rarity, effect_text]


func _power_state_for_actor(actor: Person) -> Dictionary:
	if actor == null:
		return {}
	if gs == null or gs.power_engine == null:
		return {}
	if gs.power_engine.has_method("get_person_power_state"):
		return _safe_dictionary(gs.power_engine.get_person_power_state(actor))
	return {}


func _power_row(actor: Person, power_id: String) -> Dictionary:
	var state: Dictionary = _power_state_for_actor(actor)
	var powers: Dictionary = _safe_dictionary(state.get("powers", {}))
	return _safe_dictionary(powers.get(power_id, {}))


func _power_contract(power_id: String) -> Dictionary:
	if gs == null or gs.power_engine == null:
		return {}
	if gs.power_engine.has_method("get_power_contract"):
		return _safe_dictionary(gs.power_engine.get_power_contract(power_id))
	return {}


func _actor_property_text(actor: Person, property_name: String) -> String:
	if actor == null:
		return ""
	return str(actor.get(property_name)).strip_edges()
func _active_registration_law() -> Dictionary:
	var society: Dictionary = _safe_dictionary(active_contract.get("society_simulation", {}))
	var laws: Dictionary = _safe_dictionary(society.get("registration_laws", {}))
	var era_key: String = _current_era_key()
	var law: Dictionary = _safe_dictionary(laws.get(era_key, {}))
	if not law.is_empty():
		return law
	return _safe_dictionary(laws.get("default", {
		"label": "unregulated",
		"description": "Powered people are not formally registered.",
		"enforcement": "low"
	}))


func _append_superhero_birth_identity_memory(actor: Person, public_identity: String, scope_id: String) -> void:
	if actor == null:
		return

	var clean_identity: String = str(public_identity).strip_edges().to_lower()
	if clean_identity == "":
		return

	var family_scope: bool = str(scope_id).strip_edges().to_lower() in ["whole_family", "my_bloodline"]
	var line: String = ""

	match clean_identity:
		"secret":
			var secret_scope_text: String = "our lives" if family_scope else "my life"
			line = "🎶What you see is not what you get, living %s with a…secret (queue Thundermans theme)." % secret_scope_text
		"rumored":
			line = "Before I could explain anything, the world already had rumors about what lived in my blood."
		"registered_hero":
			line = "The world expected me to become a hero before I was old enough to understand what a hero costs."
		"government_experiment":
			line = "My power did not just wake up. It was filed, contained, and marked by people who thought a life could be an experiment."
		_:
			return

	if "memories" in actor and actor.memories is Array:
		for i in range(actor.memories.size()):
			var existing_text: String = str(actor.memories [i]).strip_edges()
			if existing_text == line:
				return

			var existing_lower: String = existing_text.to_lower()
			if clean_identity == "secret" and (
				existing_lower.find("what you see is not what you get") != -1
				or existing_lower.find("what i see is not what i get") != -1
			):
				actor.memories [i] = line
				return

		actor.memories.append(line)


func _superhero_hub_identity_packet(actor: Person, profile: Dictionary, power_state: Dictionary = {}) -> Dictionary:
	var status_text: String = str(profile.get("registration_status", "unregistered")).replace("_", " ").capitalize()
	var identity_text: String = str(profile.get("public_identity", profile.get("alignment", "civilian"))).replace("_", " ").capitalize()

	return {
		"id": "superhero_public_life",
		"title": "PUBLIC LIFE",
		"subtitle": "%s • %s" % [identity_text, status_text],
		"description": "Your visible life: masks, registration, crime fighting, fame, agencies, public trust, rumors, disguises, and legal pressure.",
		"theme": "superhero_public_life",
		"actor_id": int(actor.id) if actor != null else -1,
		"registration_status": str(profile.get("registration_status", "unregistered")),
		"public_identity": str(profile.get("public_identity", "")),
		"public_trust": int(profile.get("public_trust", 50)),
		"legal_risk": int(profile.get("legal_risk", 0)),
		"hidden_identity_risk": float(power_state.get("hidden_identity_risk", 0.0))
	}


func _registered_identity_action_rows(_profile: Dictionary) -> Array:
	return [
		{
			"id": "registration_update_file",
			"label": "Update Public File",
			"engine_property": "superhero_engine",
			"method": "resolve_hub_action",
			"payload": {
				"action": "registration_update_file",
				"source": "registered_identity_detail"
			},
			"refresh_after": true
		},
		{
			"id": "registration_request_clearance",
			"label": "Request Legal Clearance",
			"engine_property": "superhero_engine",
			"method": "resolve_hub_action",
			"payload": {
				"action": "registration_request_clearance",
				"source": "registered_identity_detail"
			},
			"refresh_after": true
		},
		{
			"id": "registration_show_credentials",
			"label": "Show Credentials",
			"engine_property": "superhero_engine",
			"method": "resolve_hub_action",
			"payload": {
				"action": "registration_show_credentials",
				"source": "registered_identity_detail"
			},
			"refresh_after": true
		}
	]


func _resolve_registered_identity_action(actor: Person, payload: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "Actor missing."
		}

	var profile: Dictionary = ensure_hero_profile(actor)
	var action: String = str(payload.get("action", "")).strip_edges().to_lower()

	match action:
		"registration_update_file":
			profile ["public_trust"] = clamp(int(profile.get("public_trust", 50)) + 2, 0, 100)
			profile ["legal_risk"] = max(0, int(profile.get("legal_risk", 0)) - 3)
		"registration_request_clearance":
			profile ["legal_risk"] = max(0, int(profile.get("legal_risk", 0)) - 7)
		"registration_show_credentials":
			profile ["public_trust"] = clamp(int(profile.get("public_trust", 50)) + 4, 0, 100)
		_:
			return {
				"success": false,
				"reason": "Unknown registered identity action.",
				"action": action
			}

	_commit_profile(actor, profile)

	return {
		"success": true,
		"schema": "eralife.registered_identity_action_report",
		"action": action,
		"profile": profile.duplicate(true),
		"text": "Your registered public life shifts. The file updates. The world keeps watching.",
		"popup_title": "Registered Identity",
		"popup_text": "Action completed.\n\nPublic Trust: %d%%\nLegal Risk: %d" % [
			int(profile.get("public_trust", 50)),
			int(profile.get("legal_risk", 0))
		],
		"popup_footer": "Registration protects you and exposes you at the same time."
	}


func _current_era_agency_rows() -> Array:
	match _current_era_key():
		"ancient":
			return [
				{ "id": "temple_oathbearers", "name": "Temple Oathbearers", "era_label": "Ancient", "faction_word": "Order", "alignment": "hero", "allows_human_elite": true, "min_age": 13, "required_power_level": 0, "min_villain_wins": 0, "min_win_rate": 0.0, "leader_name": "High Seer Amara", "leader_power_level": 640, "description": "Priest-trained guardians, elite humans, and omen-readers who protect cities from monsters, raiders, and cursed bloodlines."},
				{ "id": "bronze_mask_vow", "name": "Bronze Mask Vow", "era_label": "Ancient", "faction_word": "Vow", "alignment": "hero", "allows_human_elite": true, "min_age": 13, "required_power_level": 350, "min_villain_wins": 1, "min_win_rate": 0.45, "leader_name": "Khemet the Bronze", "leader_power_level": 2100, "description": "A masked protector tradition where discipline matters as much as power."},
				{ "id": "eclipse_cult", "name": "Eclipse Cult", "era_label": "Ancient", "faction_word": "Cult", "alignment": "villain", "min_age": 13, "required_power_level": 1200, "min_villain_wins": 0, "min_win_rate": 0.0, "leader_name": "Mother of the Dark Sun", "leader_power_level": 8200, "description": "A feared faction that interprets powers as divine permission to rule."}
			]
		"medieval":
			return [
				{ "id": "crown_writ_champions", "name": "Crown Writ Champions", "era_label": "Medieval", "faction_word": "Order", "alignment": "hero", "allows_human_elite": true, "min_age": 13, "required_power_level": 0, "min_villain_wins": 0, "min_win_rate": 0.0, "leader_name": "Sir Alaric Wyrmguard", "leader_power_level": 980, "description": "Royally sanctioned champions, knights, duelists, and trained humans who answer public threats."},
				{ "id": "lantern_friars", "name": "Lantern Friars", "era_label": "Medieval", "faction_word": "Brotherhood", "alignment": "hero", "min_age": 13, "required_power_level": 900, "min_villain_wins": 2, "min_win_rate": 0.5, "leader_name": "Sister Mave the Unburned", "leader_power_level": 5100, "description": "A rescue-first order that hides powered children from warlords."},
				{ "id": "black_banner_compact", "name": "Black Banner Compact", "era_label": "Medieval", "faction_word": "Compact", "alignment": "villain", "min_age": 13, "required_power_level": 1600, "min_villain_wins": 0, "min_win_rate": 0.0, "leader_name": "Lord Varric No-Crown", "leader_power_level": 7600, "description": "A villain compact built from mercenaries, cursed nobles, and throne-breakers."}
			]
		"industrial":
			return [
				{ "id": "smokehouse_vigil", "name": "Smokehouse Vigil", "era_label": "Industrial", "faction_word": "Vigil", "alignment": "hero", "allows_human_elite": true, "min_age": 13, "required_power_level": 0, "min_villain_wins": 0, "min_win_rate": 0.0, "leader_name": "Elias Gearwright", "leader_power_level": 740, "description": "Factory-district protectors, boxers, detectives, medics, and elite humans fighting industrial crime."},
				{ "id": "brass_sentinel_bureau", "name": "Brass Sentinel Bureau", "era_label": "Industrial", "faction_word": "Bureau", "alignment": "hero", "min_age": 13, "required_power_level": 1500, "min_villain_wins": 2, "min_win_rate": 0.5, "leader_name": "Director Ada Brass", "leader_power_level": 9200, "description": "A proto-government bureau that registers powered citizens and deploys them against city-scale threats."},
				{ "id": "red_ledger_society", "name": "Red Ledger Society", "era_label": "Industrial", "faction_word": "Society", "alignment": "villain", "min_age": 13, "required_power_level": 2200, "min_villain_wins": 0, "min_win_rate": 0.0, "leader_name": "The Accountant Saint", "leader_power_level": 12500, "description": "A criminal society that buys powers, secrets, and bloodlines like assets."}
			]
		"future":
			return [
				{ "id": "civic_exosuit_corps", "name": "Civic Exosuit Corps", "era_label": "Future", "faction_word": "Corps", "alignment": "hero", "allows_human_elite": true, "min_age": 13, "required_power_level": 0, "min_villain_wins": 0, "min_win_rate": 0.0, "leader_name": "Marshal Ion Vale", "leader_power_level": 4800, "description": "Elite trained humans, exosuit pilots, rescue tacticians, and non-powered specialists who can stand beside supers."},
				{ "id": "neon_halo_authority", "name": "Neon Halo Authority", "era_label": "Future", "faction_word": "Authority", "alignment": "hero", "min_age": 13, "required_power_level": 25000, "min_villain_wins": 5, "min_win_rate": 0.6, "leader_name": "Director Solenne Arc", "leader_power_level": 250000, "description": "A predictive-response authority built for city, national, and orbital threats."},
				{ "id": "null_crown_cartel", "name": "Null Crown Cartel", "era_label": "Future", "faction_word": "Cartel", "alignment": "villain", "min_age": 13, "required_power_level": 40000, "min_villain_wins": 0, "min_win_rate": 0.0, "leader_name": "No-King Vex", "leader_power_level": 410000, "description": "A villain cartel that trades in power suppressors, identity theft, illegal cloning, and anti-hero propaganda."},
				{ "id": "orbital_hero_accord", "name": "Orbital Hero Accord", "era_label": "Future", "faction_word": "Accord", "alignment": "hero", "min_age": 13, "required_power_level": 100000, "min_villain_wins": 10, "min_win_rate": 0.72, "leader_name": "Captain Luma Ninth", "leader_power_level": 980000, "description": "A premium faction for heroes trusted with planetary and orbital incidents."}
			]
		_:
			return [
				{ "id": "peak_human_response_league", "name": "Peak Human Response League", "era_label": "Modern", "faction_word": "League", "alignment": "hero", "allows_human_elite": true, "min_age": 13, "required_power_level": 0, "min_villain_wins": 0, "min_win_rate": 0.0, "leader_name": "Maya Cross", "leader_power_level": 860, "description": "Elite trained humans, martial artists, detectives, first responders, and tactical heroes who do not need cosmic power to matter."},
				{ "id": "street_mask_collective", "name": "Street Mask Collective", "era_label": "Modern", "faction_word": "Collective", "alignment": "hero", "allows_human_elite": true, "min_age": 13, "required_power_level": 500, "min_villain_wins": 1, "min_win_rate": 0.35, "leader_name": "Juno Mask", "leader_power_level": 3600, "description": "Neighborhood heroes, vigilantes, and rescue-first powered civilians."},
				{ "id": "city_watch_agency", "name": "City Watch Agency", "era_label": "Modern", "faction_word": "Agency", "alignment": "hero", "min_age": 13, "required_power_level": 2500, "min_villain_wins": 2, "min_win_rate": 0.45, "leader_name": "Director Hale Ward", "leader_power_level": 18000, "description": "A regulated agency that handles crime response, public damage, and hero licensing."},
				{ "id": "national_hero_directorate", "name": "National Hero Directorate", "era_label": "Modern", "faction_word": "Directorate", "alignment": "hero", "min_age": 13, "required_power_level": 25000, "min_villain_wins": 6, "min_win_rate": 0.62, "leader_name": "Commander Astra Vale", "leader_power_level": 220000, "description": "Government-backed heroes, classified operations, serum oversight, and national threat response."},
				{ "id": "black_crown_villain_network", "name": "Black Crown Villain Network", "era_label": "Modern", "faction_word": "Network", "alignment": "villain", "min_age": 13, "required_power_level": 9000, "min_villain_wins": 0, "min_win_rate": 0.0, "leader_name": "The Black Crown", "leader_power_level": 88000, "description": "A villain faction built around leverage, fear, stolen tech, and powered recruitment."},
				{ "id": "mythic_response_council", "name": "Mythic Response Council", "era_label": "Modern", "faction_word": "Council", "alignment": "hero", "min_age": 13, "required_power_level": 100000, "min_villain_wins": 12, "min_win_rate": 0.75, "leader_name": "Oracle Vey", "leader_power_level": 1250000, "description": "A world-tier organization that intervenes when powers threaten civilization."}
			]


func _agency_row_by_id(agency_id: String) -> Dictionary:
	var clean_id: String = str(agency_id).strip_edges().to_lower()
	if clean_id == "":
		return {}

	for raw_agency in _current_era_agency_rows():
		if typeof(raw_agency) != TYPE_DICTIONARY:
			continue
		var agency: Dictionary = raw_agency
		if str(agency.get("id", "")).strip_edges().to_lower() == clean_id:
			return agency.duplicate(true)

	var society: Dictionary = _safe_dictionary(active_contract.get("society_simulation", {}))
	var agencies: Array = _safe_array(society.get("agency_tiers", []))
	for raw_contract_agency in agencies:
		if typeof(raw_contract_agency) != TYPE_DICTIONARY:
			continue
		var contract_agency: Dictionary = raw_contract_agency
		if str(contract_agency.get("id", "")).strip_edges().to_lower() == clean_id:
			return contract_agency.duplicate(true)

	return {}


func _agency_join_eligibility(actor: Person, profile: Dictionary, agency: Dictionary, power_level: int) -> Dictionary:
	if actor == null:
		return {
			"eligible": false,
			"reason": "Actor missing."
		}

	var age_value: int = int(actor.get("age"))
	var min_age: int = int(agency.get("min_age", 13))
	if age_value < min_age:
		return {
			"eligible": false,
			"reason": "You must be at least %d to join this faction." % min_age
		}

	var required_power: int = int(agency.get("required_power_level", 0))
	var allows_human_elite: bool = bool(agency.get("allows_human_elite", false))
	if not allows_human_elite and power_level < required_power:
		return {
			"eligible": false,
			"reason": "Power Level %d required. Current Power Level: %d." % [required_power, power_level]
		}

	var required_wins: int = int(agency.get("min_villain_wins", 0))
	var wins: int = int(profile.get("villains_defeated", 0))
	if wins < required_wins:
		return {
			"eligible": false,
			"reason": "Defeat %d villains first. Current wins: %d." % [required_wins, wins]
		}

	var required_rate: float = float(agency.get("min_win_rate", 0.0))
	var win_rate: float = _profile_win_rate(profile)
	if win_rate < required_rate:
		return {
			"eligible": false,
			"reason": "Win rate %d%% required. Current win rate: %d%%." % [
				int(round(required_rate * 100.0)),
				int(round(win_rate * 100.0))
			]
		}

	return {
		"eligible": true,
		"reason": "Eligible."
	}


func _profile_win_rate(profile: Dictionary) -> float:
	var wins: int = int(profile.get("villains_defeated", 0))
	var losses: int = int(profile.get("losses", 0))
	var draws: int = int(profile.get("draws", 0))
	var total: int = wins + losses + draws
	if total <= 0:
		return 1.0 if wins > 0 else 0.0
	return float(wins) / float(total)


func _agency_name(agency_id: String) -> String:
	var agency: Dictionary = _agency_row_by_id(agency_id)
	if not agency.is_empty():
		return str(agency.get("name", agency_id))
	return agency_id.replace("_", " ").capitalize()


func _choose_super_disguise(actor: Person, _payload: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "Actor missing."
		}

	var profile: Dictionary = ensure_hero_profile(actor)
	var disguise_pool: Array = [
		{ "id": "hooded_mask", "name": "Hooded Mask"},
		{ "id": "borrowed_costume", "name": "Borrowed Costume"},
		{ "id": "street_alias", "name": "Street Alias"},
		{ "id": "helmeted_responder", "name": "Helmeted Responder"},
		{ "id": "shadow_cape", "name": "Shadow Cape"}
	]

	var picked: Dictionary = disguise_pool [randi_range(0, disguise_pool.size() - 1)]
	profile ["active_disguise_id"] = str(picked.get("id", "hooded_mask"))
	profile ["active_disguise_name"] = str(picked.get("name", "Hooded Mask"))
	profile ["exposure_susceptibility"] = max(0.0, float(profile.get("exposure_susceptibility", 0.0)) - 0.05)

	_commit_profile(actor, profile)

	return {
		"success": true,
		"schema": "eralife.superhero_disguise_report",
		"disguise_id": str(profile.get("active_disguise_id", "")),
		"disguise_name": str(profile.get("active_disguise_name", "")),
		"text": "You prepare a disguise: %s. You can fight crime without registering, but the risk never fully disappears." % str(profile.get("active_disguise_name", "")),
		"popup_title": "Disguise Equipped",
		"popup_text": "Active Disguise: %s\n\nYou can patrol, respond to crime, and build a fighting record without registering." % str(profile.get("active_disguise_name", "")),
		"popup_footer": "Masks buy time. They do not erase consequences."
	}


func _resolve_agency_leader_interaction(actor: Person, payload: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "Actor missing."
		}

	var agency_id: String = str(payload.get("agency_id", "")).strip_edges().to_lower()
	var agency: Dictionary = _agency_row_by_id(agency_id)
	var profile: Dictionary = ensure_hero_profile(actor)

	if agency.is_empty():
		return {
			"success": false,
			"reason": "Faction not found.",
			"agency_id": agency_id
		}

	if str(profile.get("agency_id", "")).strip_edges().to_lower() != agency_id:
		return {
			"success": false,
			"reason": "Join this faction before meeting its leader."
		}

	var leader_name: String = str(agency.get("leader_name", profile.get("agency_leader_name", "Unknown Leader")))
	var leader_power_level: int = int(agency.get("leader_power_level", profile.get("agency_leader_power_level", 0)))

	return {
		"success": true,
		"schema": "eralife.agency_leader_interaction_report",
		"agency_id": agency_id,
		"agency_name": str(agency.get("name", profile.get("agency_name", ""))),
		"leader_name": leader_name,
		"leader_power_level": leader_power_level,
		"text": "%s studies you like a future asset, ally, weapon, or problem." % leader_name,
		"popup_title": leader_name,
		"popup_text": "%s\nPower Level: %d\n\nThey are now available as a future mentor, rival, faction-order, betrayal, promotion, or sparring hook." % [
			leader_name,
			leader_power_level
		],
		"popup_footer": "Faction leaders are now real contract targets."
	}


func _serum_programs_available() -> bool:
	var era_key: String = _current_era_key()
	return era_key in ["industrial", "modern", "future"]


func _current_era_key() -> String:
	if gs == null:
		return "modern"

	var raw: String = ""
	if "era" in gs and gs.era != null:
		if "name" in gs.era:
			raw = str(gs.era.name)
		else:
			raw = str(gs.era)

	raw = raw.strip_edges().to_lower()
	if raw.find("ancient") >= 0:
		return "ancient"
	if raw.find("medieval") >= 0:
		return "medieval"
	if raw.find("industrial") >= 0:
		return "industrial"
	if raw.find("future") >= 0:
		return "future"
	return "modern"


func _power_level_tier(power_level: int) -> String:
	var society: Dictionary = _safe_dictionary(active_contract.get("society_simulation", {}))
	var scale: Array = _safe_array(society.get("power_level_scale", []))
	for raw_tier in scale:
		if typeof(raw_tier) != TYPE_DICTIONARY:
			continue
		var tier: Dictionary = raw_tier
		if power_level >= int(tier.get("min", 0)) and power_level <= int(tier.get("max", 9000000000000000000)):
			return str(tier.get("id", "unknown"))
	return "reality_break" if power_level >= 1000000000000 else "unknown"
func yearly_tick(_payload:= {}) -> Dictionary:
	var state: Dictionary = _world_state()
	var events: Array = []

	if randf() <= 0.55:
		events.append({
			"label": "Powered Crime Spike",
			"description": "A powered crime is forming somewhere in the city.",
			"year": _current_year()
		})

	if randf() <= 0.32:
		events.append({
			"label": "Hero Sighting",
			"description": "Another powered NPC was seen intervening before police arrived.",
			"year": _current_year()
		})

	var law: Dictionary = _active_registration_law()
	if randf() <= float(law.get("event_chance", 0.18)):
		events.append({
			"label": "Registration Debate",
			"description": str(law.get("headline", "Officials debate what powered people owe the public.")),
			"year": _current_year(),
			"category": "registration_law"
		})

	if _serum_programs_available() and randf() <= 0.24:
		events.append({
			"label": "Government Serum Program",
			"description": "Rumors spread about state-backed enhancement trials. Some call it defense. Others call it manufactured gods.",
			"year": _current_year(),
			"category": "serum_program"
		})

	if randf() <= 0.18:
		events.append({
			"label": "Bloodline Hunter Movement",
			"description": "A quiet network is tracking rare powered families. Secret identities feel less secret this year.",
			"year": _current_year(),
			"category": "bloodline_hunters"
		})

	if randf() <= 0.2:
		events.append({
			"label": "Agency Recruitment Wave",
			"description": "Hero and villain agencies are scouting powered people by tier, reputation, and bloodline potential.",
			"year": _current_year(),
			"category": "agency_recruitment"
		})

	state ["live_events"] = events
	state ["last_yearly_tick_report"] = {
		"success": true,
		"event_count": events.size(),
		"registration_law": law.duplicate(true),
		"serum_programs_available": _serum_programs_available(),
		"year": _current_year(),
		"updated_at_ms": int(Time.get_ticks_msec())
	}
	_commit_world_state(state)
	return state ["last_yearly_tick_report"].duplicate(true)

func _default_contract() -> Dictionary:
	return {
		"schema": CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": "superhero_engine.default",
		"hub_sections": [
			"dashboard",
			"patrol",
			"respond",
			"villains",
			"powers",
			"registration",
			"agencies",
			"bloodlines",
			"serum_programs",
			"awakening_payoffs",
			"recruit",
			"team",
			"reputation",
			"live",
			"villain_path"
		],
		"team_rules": {
			"min_hero_rep": 40,
			"min_villains_defeated": 3
		},
		"battle_rules": {
		},
		"society_simulation": {
			"registration_laws": {
				"default": {
					"label": "unregulated",
					"description": "Powered people are watched socially, but the law has not caught up yet.",
					"enforcement": "low",
					"event_chance": 0.1,
					"headline": "Rumors grow that powered people should be tracked."
				},
				"ancient": {
					"label": "mythic omen law",
					"description": "Powered people are treated as omens, champions, curses, or divine bloodline threats.",
					"enforcement": "temple_and_throne",
					"event_chance": 0.16,
					"headline": "Priests and rulers argue over whether powered bloodlines belong to the gods."
				},
				"medieval": {
					"label": "royal writ system",
					"description": "Kings, councils, and orders demand fealty from powered people.",
					"enforcement": "noble_orders",
					"event_chance": 0.18,
					"headline": "Nobles demand that powered citizens swear public oaths."
				},
				"industrial": {
					"label": "powered registry act",
					"description": "Governments begin documenting powered people, especially children, soldiers, and serum candidates.",
					"enforcement": "bureaucratic",
					"event_chance": 0.26,
					"headline": "Officials propose mandatory powered registration after a factory district incident."
				},
				"modern": {
					"label": "superhuman accountability act",
					"description": "Secret identities are tolerated until public damage, powered crime, or bloodline risk forces disclosure.",
					"enforcement": "federal",
					"event_chance": 0.3,
					"headline": "A televised debate erupts over secret identities and powered accountability."
				},
				"future": {
					"label": "metahuman biometric grid",
					"description": "Advanced states attempt predictive tracking of powers, bloodlines, and high-risk awakenings.",
					"enforcement": "predictive_surveillance",
					"event_chance": 0.36,
					"headline": "A biometric grid flags several children as future high-tier powered beings."
				}
			},
			"agency_tiers": [
				{
					"id": "street_mask_collective",
					"name": "Street Mask Collective",
					"tier": "local",
					"description": "Neighborhood heroes, vigilantes, and rescue-first powered civilians."
				},
				{
					"id": "city_watch_agency",
					"name": "City Watch Agency",
					"tier": "city",
					"description": "A regulated agency that handles crime response, public damage, and hero licensing."
				},
				{
					"id": "national_hero_directorate",
					"name": "National Hero Directorate",
					"tier": "national",
					"description": "Government-backed heroes, classified operations, serum oversight, and national threat response."
				},
				{
					"id": "black_crown_villain_network",
					"name": "Black Crown Villain Network",
					"tier": "villain",
					"description": "A villain agency built around leverage, fear, stolen tech, and powered recruitment."
				},
				{
					"id": "mythic_response_council",
					"name": "Mythic Response Council",
					"tier": "world",
					"description": "A world-tier organization that intervenes when powers threaten civilization."
				}
			],
			"power_level_scale": [
				{
					"id": "human_peak",
					"label": "Human Peak",
					"min": 0,
					"max": 899,
					"description": "Elite human or barely awakened power. Training, tactics, and luck still matter more than raw output."
				},
				{
					"id": "street_level",
					"label": "Street Level",
					"min": 900,
					"max": 9999,
					"description": "Can dominate street crime, small gangs, and local threats. Beating higher tiers creates major underdog respect."
				},
				{
					"id": "city_level",
					"label": "City Level",
					"min": 10000,
					"max": 99999,
					"description": "Can reshape city conflicts, emergency response, and public safety politics."
				},
				{
					"id": "national_level",
					"label": "National Level",
					"min": 100000,
					"max": 999999,
					"description": "Governments, agencies, and villain networks prepare files around this person."
				},
				{
					"id": "world_level",
					"label": "World Level",
					"min": 1000000,
					"max": 9999999,
					"description": "The world reacts when this power moves."
				},
				{
					"id": "moon_level",
					"label": "Moon Level",
					"min": 10000000,
					"max": 99999999,
					"description": "A single confrontation can rewrite maps, oceans, weather, or civilization-scale security."
				},
				{
					"id": "planetary_level",
					"label": "Planetary Level",
					"min": 100000000,
					"max": 999999999,
					"description": "Planetary survival becomes part of the threat model."
				},
				{
					"id": "star_level",
					"label": "Star Level",
					"min": 1000000000,
					"max": 9999999999,
					"description": "Power output enters mythic, celestial, and extinction-tier territory."
				},
				{
					"id": "cosmic_level",
					"label": "Cosmic Level",
					"min": 10000000000,
					"max": 999999999999,
					"description": "Reality, timelines, or civilization-scale survival may become the battleground."
				},
				{
					"id": "reality_break",
					"label": "Reality Break",
					"min": 1000000000000,
					"max": 9000000000000000000,
					"description": "The scouter stops being a number and starts being a prayer."
				}
			],
			"bloodline_hunters": {
				"enabled": true,
				"trigger": "rare_power_lineage_detected",
				"tracks": [
					"mythic_powers",
					"age_13_awakening",
					"trauma_awakening",
					"public_identity_exposure",
					"powered_children",
					"registered_bloodlines"
				]
			},
			"government_serum_programs": [
				{
					"id": "industrial_proto_serum",
					"name": "Proto Serum Trials",
					"era": "industrial",
					"description": "Unsafe early enhancement science with military sponsors and ugly side effects."
				},
				{
					"id": "modern_super_soldier_program",
					"name": "Super Soldier Program",
					"era": "modern",
					"description": "A classified program offering power at the cost of oversight, debt, and bodily risk."
				},
				{
					"id": "future_genome_ascension_program",
					"name": "Genome Ascension Program",
					"era": "future",
					"description": "Predictive biotech that edits candidates toward artificial power expression."
				}
			],
			"awakening_payoffs": {
				"age_13": {
					"enabled": true,
					"event_name": "power.age_13_awakening",
					"description": "Latent powers can ignite at age 13 and alter family, school, agency, and legal pressure."
				},
				"trauma": {
					"enabled": true,
					"event_name": "power.trauma_awakening",
					"description": "Trauma can awaken latent powers, but may add fear, control problems, and attention."
				}
			}
		}
	}

func _resolve_or_create_villain(payload: Dictionary = {}) -> Person:
	var villain_id: int = int(payload.get("villain_id", -1))
	if villain_id > 0:
		var existing: Person = _person_by_id(villain_id)
		if existing != null:
			return existing

	var state: Dictionary = _world_state()
	var villains: Dictionary = _safe_dictionary(state.get("villain_index", {}))
	var prefer_existing: bool = str(payload.get("resolution_strategy", "generate_if_missing")).strip_edges().to_lower() != "force_generate"

	if prefer_existing and not villains.is_empty():
		for raw_key in villains.keys():
			var row: Dictionary = _safe_dictionary(villains.get(raw_key, {}))
			var existing_id: int = int(row.get("person_id", raw_key))
			var existing_villain: Person = _person_by_id(existing_id)
			if existing_villain != null:
				return existing_villain

	var villain: Person = null
	if gs != null and gs.npc_factory != null and gs.npc_factory.has_method("create_random_npc"):
		villain = gs.npc_factory.create_random_npc(true)

	if villain == null:
		return null

	if gs != null:
		if gs.has_method("apply_reality_rules_to_person"):
			gs.apply_reality_rules_to_person(villain)
		if typeof(gs.npcs) == TYPE_ARRAY:
			gs.npcs.append(villain)
		if gs.has_method("_rebuild_npc_index"):
			gs._rebuild_npc_index()

	if gs != null and gs.power_engine != null:
		var villain_power_pool: Array = ["super_strength", "super_speed", "energy_projection", "telepathy", "spider_abilities"]
		if randf() <= 0.025:
			villain_power_pool.append("probability_manipulation")
		var power_id: String = str(villain_power_pool [randi() % villain_power_pool.size()])
		gs.power_engine.grant_power(villain, power_id, "villain_spawn", {
			"visibility": "public"
		})

	var causal_justification: Dictionary = _safe_dictionary(payload.get("causal_justification", {}))
	_register_villain_seed(villain, {
		"source": str(payload.get("source", "resolve_or_create_villain")),
		"causal_justification": causal_justification.duplicate(true)
	})

	if not causal_justification.is_empty():
		state = _world_state()
		var villain_histories: Dictionary = _safe_dictionary(state.get("villain_causal_histories", {}))
		villain_histories [str(int(villain.id))] = {
			"schema": "eralife.villain_causal_history",
			"version": CONTRACT_VERSION,
			"villain_id": int(villain.id),
			"villain_name": _person_label(villain),
			"why_now": str(causal_justification.get("why_now", "")),
			"why_here": str(causal_justification.get("why_here", "")),
			"why_you": str(causal_justification.get("why_you", "")),
			"what_was_happening_before": _safe_array(causal_justification.get("what_was_happening_before", [])),
			"created_year": _current_year(),
			"created_at_ms": int(Time.get_ticks_msec())
		}
		state ["villain_causal_histories"] = villain_histories
		_commit_world_state(state)

	return villain

func _register_villain_seed(villain: Person, context: Dictionary = {}) -> void:
	if villain == null:
		return

	var state: Dictionary = _world_state()
	var villains: Dictionary = _safe_dictionary(state.get("villain_index", {}))
	villains [str(int(villain.id))] = {
		"person_id": int(villain.id),
		"name": _person_label(villain),
		"threat": max(1, int(_power_rating(villain) / 25.0)),
		"last_seen": str(context.get("source", "Unknown")),
		"updated_year": _current_year()
	}
	state ["villain_index"] = villains
	_commit_world_state(state)

func _find_powered_recruit(actor: Person) -> Person:
	if gs == null or typeof(gs.npcs) != TYPE_ARRAY:
		return null

	var candidates: Array = []
	for raw_npc in gs.npcs:
		if not (raw_npc is Person):
			continue
		var npc: Person = raw_npc
		if actor != null and int(npc.id) == int(actor.id):
			continue
		if gs.power_engine != null and gs.power_engine.has_method("has_superpowers") and gs.power_engine.has_superpowers(npc):
			candidates.append(npc)

	if candidates.is_empty():
		return null

	return candidates [randi() % candidates.size()]
func _resolve_or_create_sidekick_recruit(actor: Person, payload: Dictionary = {}) -> Person:
	var existing: Person = _find_powered_recruit(actor)
	if existing != null:
		return existing

	if gs == null or gs.npc_factory == null or not gs.npc_factory.has_method("create_random_npc"):
		return null

	var ally: Person = gs.npc_factory.create_random_npc(true)
	if ally == null:
		return null

	if gs.has_method("apply_reality_rules_to_person"):
		gs.apply_reality_rules_to_person(ally)

	if typeof(gs.npcs) == TYPE_ARRAY:
		gs.npcs.append(ally)

	if gs.has_method("_rebuild_npc_index"):
		gs._rebuild_npc_index()

	if gs.power_engine != null and gs.power_engine.has_method("grant_power"):
		var sidekick_power_pool: Array = ["super_strength", "super_speed", "energy_projection", "spider_abilities", "telepathy"]
		var power_id: String = str(sidekick_power_pool [randi() % sidekick_power_pool.size()])
		gs.power_engine.grant_power(ally, power_id, "sidekick_causality_spawn", {
			"visibility": "public" if bool(payload.get("public", false)) else "rumored"
		})

	var profile: Dictionary = ensure_hero_profile(ally)
	profile ["alignment"] = "hero"
	profile ["hero_rank"] = "rookie"
	profile ["public_alias"] = str(payload.get("sidekick_alias", "")).strip_edges()
	if str(profile.get("public_alias", "")).strip_edges() == "":
		profile ["public_alias"] = "%s Spark" % _person_label(ally)
	profile ["sidekick_candidate"] = true
	profile ["watched_player_before_joining"] = true
	profile ["causal_backstory"] = "They had been watching your work from a distance and waiting for a team worth joining."
	_commit_profile(ally, profile)

	return ally
func has_superhero_hub_access(actor: Person) -> bool:
	if actor == null:
		return false

	if gs != null and gs.power_engine != null and gs.power_engine.has_method("has_superpowers"):
		if gs.power_engine.has_superpowers(actor):
			return true

	var state: Dictionary = _world_state()
	var profiles: Dictionary = _safe_dictionary(state.get("hero_profiles", {}))
	var profile: Dictionary = _safe_dictionary(profiles.get(_person_key(actor), {}))
	if profile.is_empty():
		return false

	if bool(profile.get("hub_unlocked", false)):
		return true

	var alignment: String = str(profile.get("alignment", "civilian")).strip_edges().to_lower()
	if alignment != "" and alignment != "civilian":
		return true

	var registration_status: String = str(profile.get("registration_status", "unregistered")).strip_edges().to_lower()
	if registration_status not in ["", "unregistered", "unknown"]:
		return true

	if bool(profile.get("birth_power_configured", false)):
		return true

	return false
func _actor_can_super(actor: Person) -> bool:
	return gs != null and gs.power_engine != null and gs.power_engine.has_method("has_superpowers") and gs.power_engine.has_superpowers(actor)

func _has_power(actor: Person, power_id: String) -> bool:
	if gs == null or gs.power_engine == null:
		return false
	return str(power_id).strip_edges().to_lower() in gs.power_engine.get_active_power_ids(actor)

func _power_rating(actor: Person) -> int:
	if gs != null and gs.power_engine != null and gs.power_engine.has_method("get_power_rating"):
		return int(gs.power_engine.get_power_rating(actor))
	return 0

func _power_line(actor: Person) -> String:
	if gs == null or gs.power_engine == null:
		return "No power read."
	if actor == null:
		return "No power read."

	if not gs.power_engine.has_method("get_active_power_ids"):
		return "PowerEngine cannot read active powers yet."

	var ids: Array = gs.power_engine.get_active_power_ids(actor)
	if ids.is_empty():
		var power_state: Dictionary = _power_state_for_actor(actor)
		var lineage_seed: Dictionary = _safe_dictionary(power_state.get("lineage_power_seed", {}))
		if not lineage_seed.is_empty():
			return "Latent lineage signal • %s" % str(lineage_seed.get("primary_power", "unknown")).replace("_", " ").capitalize()
		return "No active powers."

	var labels: Array = []
	for raw_id in ids:
		var power_id: String = str(raw_id).strip_edges().to_lower()
		var contract: Dictionary = _power_contract(power_id)
		var row: Dictionary = _power_row(actor, power_id)
		var label: String = str(contract.get("display_name", power_id.replace("_", " ").capitalize()))
		if bool(row.get("latent_locked", false)):
			label += " (latent)"
		if bool(row.get("bending_power_source", false)):
			label += " (bending)"
		labels.append(label)

	return "%s • Rating %d" % [
		", ".join(labels),
		_power_rating(actor)
	]
func _hero_rank(rep: int) -> String:
	if rep >= 180:
		return "world_icon"
	if rep >= 95:
		return "national"
	if rep >= 40:
		return "city_symbol"
	if rep >= 12:
		return "local"
	return "unknown"

func _commit_profile(actor: Person, profile: Dictionary) -> void:
	var state: Dictionary = _world_state()
	var profiles: Dictionary = _safe_dictionary(state.get("hero_profiles", {}))
	profile ["updated_year"] = _current_year()
	profiles [_person_key(actor)] = profile.duplicate(true)
	state ["hero_profiles"] = profiles
	_commit_world_state(state)

func _record_hero_event(report: Dictionary) -> void:
	var state: Dictionary = _world_state()
	var ledger: Array = _safe_array(state.get("hero_event_ledger", []))
	ledger.append(report.duplicate(true))
	while ledger.size() > MAX_HERO_EVENT_LEDGER:
		ledger.pop_front()
	state ["hero_event_ledger"] = ledger
	state ["last_hero_report"] = report.duplicate(true)
	last_hero_report = report.duplicate(true)
	_commit_world_state(state)

func _context_actor(context: Dictionary = {}) -> Person:
	if gs != null and gs.player != null:
		return gs.player

	var actor_id: int = int(context.get("player_id", context.get("actor_id", -1)))
	if actor_id > 0:
		return _person_by_id(actor_id)

	return null

func _person_by_id(person_id: int) -> Person:
	if gs == null or person_id <= 0:
		return null
	if gs.has_method("get_or_reactivate_npc_by_id"):
		var revived = gs.get_or_reactivate_npc_by_id(person_id)
		if revived is Person:
			return revived
	if gs.has_method("get_npc_by_id"):
		var found = gs.get_npc_by_id(person_id)
		if found is Person:
			return found
	return null

func _person_key(actor: Person) -> String:
	if actor == null:
		return "-1"
	return str(int(actor.id))

func _person_label(actor: Person) -> String:
	if actor == null:
		return "Unknown"
	if actor.has_method("full_name"):
		return str(actor.full_name())
	if "first_name" in actor and "last_name" in actor:
		return "%s %s" % [str(actor.first_name), str(actor.last_name)]
	return "Person %d" % int(actor.id)

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
	out ["save_key"] = str(out.get("save_key", STATE_KEY))
	out ["persistent"] = bool(out.get("persistent", true))
	out ["backwards_compatible"] = bool(out.get("backwards_compatible", true))
	out ["preserve_unknown_fields"] = bool(out.get("preserve_unknown_fields", true))
	if typeof(out.get("hero_profiles", {})) != TYPE_DICTIONARY:
		out ["hero_profiles"] = {}
	if typeof(out.get("hero_teams", {})) != TYPE_DICTIONARY:
		out ["hero_teams"] = {}
	if typeof(out.get("villain_index", {})) != TYPE_DICTIONARY:
		out ["villain_index"] = {}
	if typeof(out.get("live_events", [])) != TYPE_ARRAY:
		out ["live_events"] = []
	if typeof(out.get("hero_event_ledger", [])) != TYPE_ARRAY:
		out ["hero_event_ledger"] = []
	if typeof(out.get("capability_behavior_signatures", {})) != TYPE_DICTIONARY:
		out ["capability_behavior_signatures"] = {}
	if typeof(out.get("affordance_mutations", {})) != TYPE_DICTIONARY:
		out ["affordance_mutations"] = {}
	if typeof(out.get("capability_affordance_ledger", [])) != TYPE_ARRAY:
		out ["capability_affordance_ledger"] = []
	return out

func _commit_world_state(state: Dictionary) -> void:
	if gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	gs.scenario_state [STATE_KEY] = _normalize_state(state)

func _current_year() -> int:
	if gs == null:
		return 0
	return int(gs.year)

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