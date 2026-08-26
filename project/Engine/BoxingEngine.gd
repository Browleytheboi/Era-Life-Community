extends Resource
class_name BoxingEngine

var gs

func _init(_gs):
	gs = _gs
func _boxing_profile_contract_for_actor(person: Person, create_if_missing: bool = false) -> Dictionary:
	if person == null:
		return {}

	if typeof(person.boxing_profile) == TYPE_DICTIONARY:
		return person.boxing_profile

	if not create_if_missing:
		return {}

	person.boxing_profile = {
		"is_boxer": false,
		"boxing_hub_unlocked": false,
		"boxing_career_started_by_player": false,
		"retired": false,
		"turned_pro": false,
		"record": {
			"wins": 0,
			"losses": 0,
			"draws": 0,
			"kos": 0
		},
		"amateur_record": {
			"wins": 0,
			"losses": 0,
			"draws": 0,
			"kos": 0
		},
		"amateur_circuit": {},
		"fight_history": [],
		"rivalries": [],
		"belts": [],
		"current_injuries": [],
		"growth": {},
		"ratings": {}
	}

	return person.boxing_profile
func can_start_boxing(person: Person) -> bool:
	if person == null:
		return false
	if not bool(person.alive):
		return false
	if gs == null or gs.era_engine == null:
		return false
	if not gs.era_engine.supports_world_title_boxing():
		return false

	var profile: Dictionary = _boxing_profile_contract_for_actor(person, false)

	if bool(profile.get("is_boxer", false)):
		return false
	if bool(profile.get("boxing_hub_unlocked", false)):
		return false
	if bool(profile.get("boxing_career_started_by_player", false)):
		return false
	if bool(profile.get("retired", false)):
		return false

	var minimum_age: int = 7
	if gs.boxing_contract_engine != null and gs.boxing_contract_engine.has_method("get_boxing_policy"):
		minimum_age = int(gs.boxing_contract_engine.get_boxing_policy("minimum_boxing_start_age", 7))

	if int(person.age) < minimum_age:
		return false

	return true
func start_boxing_career(person: Person, context: Dictionary = {}) -> Dictionary:
	if not can_start_boxing(person):
		return {
			"success": false,
			"text": "\n\n   Boxing cannot be started in this era or at this age.",
			"popup_title": "Boxing Career",
			"popup_text": "Boxing is only available in Modern/Future-style world-title eras, and you must be old enough to begin.",
			"popup_footer": "Tap anywhere to continue."
		}

	var profile: Dictionary = _boxing_profile_contract_for_actor(person, true)

	if bool(profile.get("is_boxer", false)):
		profile ["boxing_hub_unlocked"] = true
		return {
			"success": false,
			"text": "\n\nI already have a boxing career.",
			"popup_title": "Boxing Career",
			"popup_text": "Your Boxing Hub is already unlocked.",
			"popup_footer": "Tap anywhere to continue."
		}

	var selected_mode: String = str(context.get("career_mode", "amateur")).strip_edges().to_lower()
	if selected_mode not in ["amateur", "pro"]:
		selected_mode = "amateur"

	var selected_division: String = str(context.get("weight_class", profile.get("weight_class", "Welterweight"))).strip_edges()
	if selected_division == "":
		selected_division = "Welterweight"

	var division_eligibility: Dictionary = {}
	if gs != null and gs.boxing_weight_engine != null and gs.boxing_weight_engine.has_method("evaluate_division_eligibility"):
		division_eligibility = gs.boxing_weight_engine.evaluate_division_eligibility(person, selected_division, {
			"source": "boxing_engine.start_boxing_career",
			"career_mode": str(context.get("career_mode", "amateur"))
		})

		if not bool(division_eligibility.get("selectable", true)):
			return {
				"success": false,
				"text": "\n\nI could not enter %s yet. %s" % [
					selected_division,
					str(division_eligibility.get("status_text", "My body is not close enough to that division."))
				],
				"popup_title": "Wrong Weight Class",
				"popup_text": str(division_eligibility.get("status_text", "You are not close enough to that boxing division yet.")),
				"popup_footer": "Change weight, choose a closer division, or build your body first.",
				"division_eligibility": division_eligibility.duplicate(true)
			}

	var gender_division: String = str(context.get("gender_division", "")).strip_edges()
	if gender_division == "":
		var gender_text: String = str(person.gender if "gender" in person else "").strip_edges().to_lower()
		gender_division = "Female" if gender_text in ["female", "woman", "girl", "f"] else "Male"

	var entering_pro: bool = selected_mode == "pro"
	var entry_context: Dictionary = {
		"source": str(context.get("source", "player_intent_begin_boxing_career")) if person == gs.player else "explicit_boxing_career_start",
		"start_age": int(person.age),
		"player_intent": person == gs.player,
		"force_amateur": not entering_pro,
		"turned_pro": entering_pro,
		"selected_division": selected_division,
		"gender_division": gender_division,
		"division_eligibility": division_eligibility.duplicate(true)
	}
	person.boxing_profile = profile
	gs.boxing_fighter_engine.initialize_fighter(person, entry_context)

	person.boxing_profile ["boxing_hub_unlocked"] = true
	person.boxing_profile ["boxing_career_started_by_player"] = bool(context.get("player_intent", person == gs.player))
	person.boxing_profile ["boxing_entry_year"] = int(gs.year)
	person.boxing_profile ["boxing_entry_age"] = int(person.age)
	person.boxing_profile ["weight_class"] = selected_division
	person.boxing_profile ["boxing_gender_division"] = gender_division
	person.boxing_profile ["turned_pro"] = entering_pro
	person.boxing_profile ["retired"] = false
	person.boxing_profile ["division_rank"] = -1
	person.boxing_profile ["amateur_division_rank"] = -1
	person.boxing_profile ["entry_path"] = selected_mode
	person.boxing_profile ["skipped_amateur_path"] = entering_pro
	person.boxing_profile ["media_heat"] = 0
	person.boxing_profile ["fame_locked_to_results"] = true

	person.boxing_profile ["gym_id"] = ""
	person.boxing_profile ["gym_name"] = "No gym"
	person.boxing_profile ["promoter_id"] = ""
	person.boxing_profile ["promoter"] = "Unsigned"
	person.boxing_profile ["promotion_signed_year"] = -1

	if person == gs.player:
		person.fame = min(int(person.fame), 2)

	if typeof(person.boxing_profile.get("record", {})) != TYPE_DICTIONARY:
		person.boxing_profile ["record"] = { "wins": 0, "losses": 0, "draws": 0, "kos": 0}
	if typeof(person.boxing_profile.get("amateur_record", {})) != TYPE_DICTIONARY:
		person.boxing_profile ["amateur_record"] = { "wins": 0, "losses": 0, "draws": 0, "kos": 0}
	if typeof(person.boxing_profile.get("amateur_circuit", {})) != TYPE_DICTIONARY:
		person.boxing_profile ["amateur_circuit"] = {}

	if entering_pro:
		person.boxing_profile ["amateur_circuit"] ["is_amateur"] = false
		person.boxing_profile ["amateur_circuit"] ["tier"] = "none"
		person.boxing_profile ["amateur_circuit"] ["may_turn_pro"] = false
		person.boxing_profile ["amateur_circuit"] ["auto_turn_pro"] = false
	else:
		person.boxing_profile ["amateur_circuit"] ["is_amateur"] = true
		person.boxing_profile ["amateur_circuit"] ["tier"] = "youth_amateur" if int(person.age) < 18 else "adult_amateur"
		person.boxing_profile ["amateur_circuit"] ["may_turn_pro"] = int(person.age) >= 18
		person.boxing_profile ["amateur_circuit"] ["auto_turn_pro"] = false

	var should_defer_world_sync: bool = bool(context.get("defer_world_sync", false))

	if should_defer_world_sync:
		person.boxing_profile ["boxing_world_sync_pending"] = true
		person.boxing_profile ["boxing_world_sync_complete"] = false
	else:
		finalize_pending_boxing_world_sync(person, {
			"source": "player_started_boxing",
			"career_mode": selected_mode,
			"weight_class": selected_division,
			"gender_division": gender_division
		})

	var entry_label: String = "Professional" if entering_pro else ("Youth Amateur" if int(person.age) < 18 else "Adult Amateur")
	var txt: String = "\n\n🥊 I began my boxing career in the %s as a %s %s %s." % [
		gs.era.name,
		gender_division,
		selected_division,
		entry_label
	]

	var actor_name: String = ("%s %s" % [
		str(person.first_name).strip_edges(),
		str(person.last_name).strip_edges()
	]).strip_edges()
	if actor_name == "":
		actor_name = str(person.name).strip_edges()
	if actor_name == "":
		actor_name = "Someone"

	var world_feed_text: String = "%s just began their boxing career at age %d in the %s %s %s division." % [
		actor_name,
		int(person.age),
		gender_division,
		selected_division,
		entry_label
	]

	if gs.narrative_engine != null:
		gs.narrative_engine.log_event(person, { "type": "text", "text": txt})

	if gs.has_method("push_world_feed"):
		gs.push_world_feed(world_feed_text, {
			"npc_id": person.id,
			"category": "boxing",
			"event_name": "boxing_started",
			"personally_relevant": person == gs.player,
			"source": "boxing_engine",
			"contract_source": "intentional_boxing_entry",
			"perspective": "third_person",
			"life_diary_text": txt,
			"world_feed_text": world_feed_text,
			"career_mode": selected_mode,
			"weight_class": selected_division,
			"gender_division": gender_division
		})

	return {
		"success": true,
		"text": txt,
		"popup_title": "Boxing Career Started",
		"popup_text": "Your Boxing Hub is now unlocked. You are starting at the bottom and will need wins, rankings, belts, and big opponents to become famous.",
		"popup_footer": "Tap anywhere to continue.",
		"unlock_boxing_hud": person == gs.player,
		"world_feed_text": world_feed_text,
		"career_mode": selected_mode,
		"weight_class": selected_division,
		"gender_division": gender_division,
		"deferred_world_sync": should_defer_world_sync,
		"world_sync_context": {
			"source": "player_started_boxing",
			"career_mode": selected_mode,
			"weight_class": selected_division,
			"gender_division": gender_division
		}
	}
func finalize_pending_boxing_world_sync(person: Person, context: Dictionary = {}) -> Dictionary:
	if gs == null:
		return {
			"success": false,
			"reason": "missing_game_state"
		}
	if person == null:
		return {
			"success": false,
			"reason": "missing_person"
		}
	if typeof(person.boxing_profile) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "missing_boxing_profile"
		}

	var profile: Dictionary = person.boxing_profile
	if not bool(profile.get("is_boxer", false)) and not bool(profile.get("boxing_hub_unlocked", false)):
		return {
			"success": false,
			"reason": "actor_not_boxer_yet"
		}

	var source: String = str(context.get("source", "deferred_boxing_entry_world_sync")).strip_edges()
	if source == "":
		source = "deferred_boxing_entry_world_sync"

	if gs.boxing_ranking_engine != null:
		gs.boxing_ranking_engine.seed_fighter(person)

	var priority_division: String = str(person.boxing_profile.get("weight_class", "")).strip_edges()
	var priority_gender: String = str(person.boxing_profile.get("boxing_gender_division", "Male")).strip_edges()
	if priority_gender == "":
		priority_gender = "Male"

	var ui_safe_tail_only: bool = bool(context.get("ui_safe_tail_only", false)) or bool(context.get("projection_only", false)) or bool(context.get("skip_heavy_world_bootstrap", false))

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	if ui_safe_tail_only:
		person.boxing_profile ["boxing_world_sync_pending"] = true
		person.boxing_profile ["boxing_world_sync_complete"] = false
		person.boxing_profile ["boxing_world_sync_deferred_heavy_world_bootstrap"] = true
		person.boxing_profile ["boxing_world_sync_reason"] = source
		person.boxing_profile ["boxing_world_sync_at_ms"] = int(Time.get_ticks_msec())

		gs.scenario_state ["boxing_roster_projection_available"] = true
		gs.scenario_state ["boxing_roster_projection_reason"] = source
		gs.scenario_state ["boxing_roster_projection_priority_division"] = priority_division
		gs.scenario_state ["boxing_roster_projection_priority_gender"] = priority_gender
		gs.scenario_state ["boxing_roster_projection_at_ms"] = int(Time.get_ticks_msec())

		gs.scenario_state ["boxing_world_sync_last_actor_id"] = int(person.id)
		gs.scenario_state ["boxing_world_sync_last_reason"] = source
		gs.scenario_state ["boxing_world_sync_last_at_ms"] = int(Time.get_ticks_msec())
		gs.scenario_state ["boxing_world_sync_heavy_bootstrap_deferred"] = true
		gs.scenario_state ["boxing_world_sync_heavy_bootstrap_deferred_reason"] = source
		gs.scenario_state ["boxing_world_sync_heavy_bootstrap_deferred_at_ms"] = int(Time.get_ticks_msec())
		gs.scenario_state ["boxing_world_factions_priority_division"] = priority_division
		gs.scenario_state ["boxing_world_factions_priority_gender"] = priority_gender

		return {
			"success": true,
			"mode": "boxing_world_sync_player_seeded_projection_available",
			"actor_id": int(person.id),
			"source": source,
			"priority_division": priority_division,
			"priority_gender": priority_gender,
		}

	ensure_world_boxing_factions(source)

	person.boxing_profile ["boxing_world_sync_pending"] = false
	person.boxing_profile ["boxing_world_sync_complete"] = true
	person.boxing_profile ["boxing_world_sync_deferred_heavy_world_bootstrap"] = false
	person.boxing_profile ["boxing_world_sync_reason"] = source
	person.boxing_profile ["boxing_world_sync_at_ms"] = int(Time.get_ticks_msec())

	gs.scenario_state ["boxing_world_sync_last_actor_id"] = int(person.id)
	gs.scenario_state ["boxing_world_sync_last_reason"] = source
	gs.scenario_state ["boxing_world_sync_last_at_ms"] = int(Time.get_ticks_msec())
	gs.scenario_state ["boxing_world_sync_heavy_bootstrap_deferred"] = false

	return {
		"success": true,
		"mode": "boxing_world_sync_finalized",
		"actor_id": int(person.id),
		"source": source
	}
func yearly_tick(_payload:= {}) -> void:
	if gs == null:
		return
	if gs.era_engine == null or not gs.era_engine.supports_world_title_boxing():
		for npc in gs.npcs:
			if npc == null:
				continue
			if not npc.boxing_profile.get("is_boxer", false):
				continue
			npc.boxing_profile ["next_fight_year"] = -1
			npc.boxing_profile ["scheduled_opponent_id"] = -1
		return

	for division in gs.boxing_ranking_engine.rankings.keys():
		_ensure_division_population(str(division), null)
	sync_boxing_division_factions()
	for npc in gs.npcs:
		if npc == null or not npc.alive:
			continue
		if not npc.boxing_profile.get("is_boxer", false):
			continue
		if npc.boxing_profile.get("retired", false):
			continue
		if gs.boxing_rivalry_engine != null:
			gs.boxing_rivalry_engine.yearly_tick()
		gs.boxing_injury_engine.yearly_recovery(npc)

		if gs != null and gs.scenario_engine != null:
			var scenario_bias: Dictionary = gs.scenario_engine.get_transient_bias_for_npc(npc.id)
			var boxing_pressure: Dictionary = scenario_bias.get("boxing_pressure", {})
			var extra_training_bias: float = float(boxing_pressure.get("extra_training_bias", 0.0))
			if extra_training_bias > 0.0 and gs.boxing_training_engine != null:
				var training_roll: float = clamp(extra_training_bias / 100.0, 0.0, 0.75)
				if randf() < training_roll:
					gs.boxing_training_engine.train_fighter(npc)
		gs.boxing_matchmaking_engine.yearly_auto_book_for_npc(npc)
func _boxing_gender_division_list() -> Array:
	return ["Male", "Female"]


func _boxing_title_bucket_key(division: String, gender_division: String) -> String:
	var clean_division: String = str(division).strip_edges()
	var clean_gender: String = str(gender_division).strip_edges()
	if clean_gender == "":
		clean_gender = "Male"
	return "%s:%s" % [clean_gender, clean_division]


func _boxing_title_seed_flag_key(division: String, gender_division: String) -> String:
	return "boxing_title_seed_distributed_%s" % _boxing_title_bucket_key(division, gender_division).replace(" ", "_").replace(":", "_").to_lower()


func _boxing_profile_belt_label(belt: String, division: String) -> String:
	return "%s %s" % [str(belt).strip_edges(), str(division).strip_edges()]


func _remove_seeded_division_belts_from_gender(division: String, gender_division: String) -> void:
	if gs == null:
		return

	var clean_division: String = str(division).strip_edges()
	var clean_gender: String = str(gender_division).strip_edges()
	if clean_gender == "":
		clean_gender = "Male"

	for raw_npc in gs.npcs:
		var npc:= raw_npc as Person
		if npc == null:
			continue
		if str(npc.boxing_profile.get("weight_class", "")).strip_edges() != clean_division:
			continue
		if str(npc.boxing_profile.get("boxing_gender_division", clean_gender)).strip_edges() != clean_gender:
			continue

		var belts: Array = npc.boxing_profile.get("belts", []) if typeof(npc.boxing_profile.get("belts", [])) == TYPE_ARRAY else []
		var kept: Array = []
		for raw_belt in belts:
			var belt_text: String = str(raw_belt).strip_edges()
			if belt_text == "":
				continue
			if belt_text.ends_with(" %s" % clean_division):
				continue
			kept.append(belt_text)
		npc.boxing_profile ["belts"] = kept


func _add_seeded_title_to_fighter(holder: Person, belt: String, division: String) -> void:
	if holder == null:
		return

	var clean_belt: String = str(belt).strip_edges()
	var clean_division: String = str(division).strip_edges()
	if clean_belt == "" or clean_division == "":
		return

	var belt_label: String = _boxing_profile_belt_label(clean_belt, clean_division)
	var belts: Array = holder.boxing_profile.get("belts", []) if typeof(holder.boxing_profile.get("belts", [])) == TYPE_ARRAY else []
	if belt_label not in belts:
		belts.append(belt_label)
	holder.boxing_profile ["belts"] = belts


func _seed_professional_champions_for_division_gender(division: String, gender_division: String) -> void:
	if gs == null or gs.boxing_title_engine == null or gs.boxing_ranking_engine == null:
		return

	var clean_division: String = str(division).strip_edges()
	var clean_gender: String = str(gender_division).strip_edges()
	if clean_gender == "":
		clean_gender = "Male"
	if clean_division == "":
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var seed_flag: String = _boxing_title_seed_flag_key(clean_division, clean_gender)
	var bucket_key: String = _boxing_title_bucket_key(clean_division, clean_gender)

	if bool(gs.scenario_state.get(seed_flag, false)):
		return

	var ranked_boxers: Array = gs.boxing_ranking_engine.get_division_ranked_ids(clean_division, "pro", 12, clean_gender)
	if ranked_boxers.is_empty():
		for raw_boxer in _active_boxers_in_division(clean_division, clean_gender, "pro"):
			ranked_boxers.append(int(raw_boxer.id))

	if ranked_boxers.is_empty():
		return

	var title_bodies: Array = ["WBA", "WBC", "IBF", "WBO"]
	if gs.boxing_contract_engine != null and gs.boxing_contract_engine.has_method("get_title_bodies"):
		title_bodies = gs.boxing_contract_engine.get_title_bodies()

	var champs: Dictionary = {}
	for belt in ["WBA", "WBC", "IBF", "WBO", "Ring Magazine"]:
		champs [str(belt)] = -1

	_remove_seeded_division_belts_from_gender(clean_division, clean_gender)

	var holder_counts: Dictionary = {}
	var cursor: int = 0

	for raw_belt in title_bodies:
		var belt: String = str(raw_belt).strip_edges()
		if belt == "" or belt == "Ring Magazine":
			continue

		var chosen: Person = null
		var safety: int = 0
		while safety < ranked_boxers.size() * 2:
			var candidate_id: int = int(ranked_boxers [cursor % ranked_boxers.size()])
			cursor += 1
			safety += 1

			var candidate: Person = gs.get_npc_by_id(candidate_id)
			if candidate == null:
				continue
			if str(candidate.boxing_profile.get("weight_class", "")).strip_edges() != clean_division:
				continue
			if str(candidate.boxing_profile.get("boxing_gender_division", clean_gender)).strip_edges() != clean_gender:
				continue
			if not bool(candidate.boxing_profile.get("turned_pro", false)):
				continue

			var count_key: String = str(candidate_id)
			var current_count: int = int(holder_counts.get(count_key, 0))
			if current_count >= 1 and ranked_boxers.size() >= title_bodies.size():
				continue
			if current_count >= 2:
				continue

			chosen = candidate
			holder_counts [count_key] = current_count + 1
			break

		if chosen == null:
			continue

		champs [belt] = int(chosen.id)
		_add_seeded_title_to_fighter(chosen, belt, clean_division)

	var lineal_holder: int = -1
	for raw_holder_id in holder_counts.keys():
		if int(holder_counts.get(raw_holder_id, 0)) >= 2:
			lineal_holder = int(raw_holder_id)
			break

	if lineal_holder > 0:
		champs ["Ring Magazine"] = lineal_holder
		var lineal_person: Person = gs.get_npc_by_id(lineal_holder)
		_add_seeded_title_to_fighter(lineal_person, "Ring Magazine", clean_division)
	else:
		champs ["Ring Magazine"] = -1

	gs.boxing_title_engine.champions [bucket_key] = champs
	gs.scenario_state [seed_flag] = true
	gs.scenario_state ["boxing_title_seed_last_bucket"] = bucket_key
	gs.scenario_state ["boxing_title_seed_last_at_ms"] = int(Time.get_ticks_msec())
func ensure_world_boxing_factions(reason: String = "boxing_world_faction_bootstrap") -> void:
	if gs == null:
		return
	if gs.era_engine == null or not gs.era_engine.supports_world_title_boxing():
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var clean_reason: String = str(reason).strip_edges()
	if clean_reason == "":
		clean_reason = "boxing_world_faction_bootstrap"

	var lower_reason: String = clean_reason.to_lower()

	var ui_open_reason: bool = (
		lower_reason.find("hub") >= 0
		or lower_reason.find("hud") >= 0
		or lower_reason.find("ui") >= 0
		or lower_reason.find("rankings_section") >= 0
		or lower_reason.find("popup") >= 0
		or lower_reason.find("action_result") >= 0
	)

	if ui_open_reason and lower_reason.find("force") < 0:
		gs.scenario_state ["boxing_world_factions_bootstrap_deferred"] = true
		gs.scenario_state ["boxing_world_factions_bootstrap_deferred_reason"] = clean_reason
		gs.scenario_state ["boxing_world_factions_bootstrap_deferred_at_ms"] = int(Time.get_ticks_msec())
		gs.scenario_state ["boxing_roster_projection_available"] = true
		gs.scenario_state ["boxing_roster_projection_reason"] = clean_reason
		gs.scenario_state ["boxing_roster_projection_at_ms"] = int(Time.get_ticks_msec())
		return

	if bool(gs.scenario_state.get("boxing_world_factions_bootstrapped", false)) and lower_reason.find("force") < 0:
		return

	var divisions: Array = [
		"Flyweight",
		"Bantamweight",
		"Featherweight",
		"Lightweight",
		"Welterweight",
		"Middleweight",
		"Light Heavyweight",
		"Heavyweight"
	]

	for division in divisions:
		_ensure_division_population(str(division), null)

	normalize_generated_boxing_faction_identity_names("ensure_world_boxing_factions:%s" % clean_reason)
	sync_boxing_division_factions()

	gs.scenario_state ["boxing_world_factions_bootstrapped"] = true
	gs.scenario_state ["boxing_world_factions_bootstrap_deferred"] = false
	gs.scenario_state ["boxing_world_factions_bootstrap_reason"] = clean_reason
	gs.scenario_state ["boxing_world_factions_bootstrapped_at_ms"] = int(Time.get_ticks_msec())
func _queue_world_boxing_factions_bootstrap_tail(reason: String = "boxing_world_faction_bootstrap_tail", priority_division: String = "", priority_gender: String = "") -> void:
	if gs == null:
		return
	if gs.era_engine == null or not gs.era_engine.supports_world_title_boxing():
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	if bool(gs.scenario_state.get("boxing_world_factions_bootstrap_tail_running", false)):
		var existing_priority_division: String = str(gs.scenario_state.get("boxing_world_factions_priority_division", "")).strip_edges()
		if existing_priority_division == "" and str(priority_division).strip_edges() != "":
			gs.scenario_state ["boxing_world_factions_priority_division"] = str(priority_division).strip_edges()
			gs.scenario_state ["boxing_world_factions_priority_gender"] = str(priority_gender).strip_edges()
		return

	gs.scenario_state ["boxing_world_factions_bootstrap_tail_running"] = true
	gs.scenario_state ["boxing_world_factions_bootstrap_tail_reason"] = reason
	gs.scenario_state ["boxing_world_factions_bootstrap_tail_started_at_ms"] = int(Time.get_ticks_msec())
	gs.scenario_state ["boxing_world_factions_priority_division"] = str(priority_division).strip_edges()
	gs.scenario_state ["boxing_world_factions_priority_gender"] = str(priority_gender).strip_edges()

	call_deferred("_run_world_boxing_factions_bootstrap_tail", reason, str(priority_division).strip_edges(), str(priority_gender).strip_edges())


func _run_world_boxing_factions_bootstrap_tail(reason: String = "boxing_world_faction_bootstrap_tail", priority_division: String = "", priority_gender: String = "") -> void:
	if gs == null:
		return
	if gs.era_engine == null or not gs.era_engine.supports_world_title_boxing():
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var clean_reason: String = str(reason).strip_edges()
	if clean_reason == "":
		clean_reason = "boxing_world_faction_bootstrap_tail"

	var tree:= Engine.get_main_loop() as SceneTree
	var work_queue: Array = _world_boxing_faction_bootstrap_work_queue(priority_division, priority_gender)
	var max_spawn_per_frame: int = 6
	var completed_steps: int = 0

	for raw_work in work_queue:
		if typeof(raw_work) != TYPE_DICTIONARY:
			continue

		var work: Dictionary = raw_work as Dictionary
		var division: String = str(work.get("division", "")).strip_edges()
		var gender_division: String = str(work.get("gender_division", "")).strip_edges()
		var mode: String = str(work.get("mode", "")).strip_edges().to_lower()

		if division == "" or gender_division == "" or mode == "":
			continue

		while not _boxing_division_population_work_complete(division, gender_division, mode):
			var completed_now: bool = _ensure_division_population_step(division, gender_division, mode, max_spawn_per_frame)
			gs.scenario_state ["boxing_world_factions_bootstrap_tail_current_division"] = division
			gs.scenario_state ["boxing_world_factions_bootstrap_tail_current_gender"] = gender_division
			gs.scenario_state ["boxing_world_factions_bootstrap_tail_current_mode"] = mode
			gs.scenario_state ["boxing_world_factions_bootstrap_tail_completed_steps"] = completed_steps
			gs.scenario_state ["boxing_world_factions_bootstrap_tail_updated_at_ms"] = int(Time.get_ticks_msec())

			if completed_now:
				break

			if tree != null:
				await tree.process_frame
			else:
				break

		if mode == "pro":
			_seed_professional_champions_for_division_gender(division, gender_division)

		completed_steps += 1

		if tree != null:
			await tree.process_frame

	normalize_generated_boxing_faction_identity_names("world_boxing_factions_bootstrap_tail:%s" % clean_reason)
	sync_boxing_division_factions()

	gs.scenario_state ["boxing_world_factions_bootstrapped"] = true
	gs.scenario_state ["boxing_world_factions_bootstrap_deferred"] = false
	gs.scenario_state ["boxing_world_factions_bootstrap_tail_running"] = false
	gs.scenario_state ["boxing_world_factions_bootstrap_reason"] = clean_reason
	gs.scenario_state ["boxing_world_factions_bootstrapped_at_ms"] = int(Time.get_ticks_msec())
	gs.scenario_state ["boxing_world_factions_bootstrap_tail_finished_at_ms"] = int(Time.get_ticks_msec())


func _world_boxing_faction_bootstrap_work_queue(priority_division: String = "", priority_gender: String = "") -> Array:
	var divisions: Array = [
		"Flyweight",
		"Bantamweight",
		"Featherweight",
		"Lightweight",
		"Welterweight",
		"Middleweight",
		"Light Heavyweight",
		"Heavyweight"
	]

	var clean_priority_division: String = str(priority_division).strip_edges()
	if clean_priority_division != "" and divisions.has(clean_priority_division):
		divisions.erase(clean_priority_division)
		divisions.push_front(clean_priority_division)

	var genders: Array = _boxing_gender_division_list()
	var clean_priority_gender: String = str(priority_gender).strip_edges()
	if clean_priority_gender != "" and genders.has(clean_priority_gender):
		genders.erase(clean_priority_gender)
		genders.push_front(clean_priority_gender)

	var queue: Array = []
	for division in divisions:
		for gender_division in genders:
			queue.append({
				"division": str(division),
				"gender_division": str(gender_division),
				"mode": "pro"
			})
			queue.append({
				"division": str(division),
				"gender_division": str(gender_division),
				"mode": "amateur"
			})

	return queue


func _boxing_division_population_work_complete(division: String, gender_division: String, mode: String) -> bool:
	var clean_division: String = str(division).strip_edges()
	var clean_gender: String = str(gender_division).strip_edges()
	var clean_mode: String = str(mode).strip_edges().to_lower()

	if clean_division == "" or clean_gender == "" or clean_mode == "":
		return true

	var target_count: int = _boxing_division_population_target_for_mode(clean_division, clean_mode)
	var current_count: int = _count_active_boxers_in_division(clean_division, clean_gender, clean_mode)
	return current_count >= target_count


func _boxing_division_population_target_for_mode(division: String, mode: String) -> int:
	var clean_division: String = str(division).strip_edges()
	var clean_mode: String = str(mode).strip_edges().to_lower()

	var minimum_pro_per_gender: int = 26
	var minimum_amateur_per_gender: int = 24

	if gs != null and gs.boxing_contract_engine != null and gs.boxing_contract_engine.has_method("get_division_target_count"):
		var contract_target: int = int(gs.boxing_contract_engine.get_division_target_count(clean_division))
		minimum_pro_per_gender = max(minimum_pro_per_gender, int(ceil(float(contract_target) * 0.52)))
		minimum_amateur_per_gender = max(minimum_amateur_per_gender, int(ceil(float(contract_target) * 0.48)))

	if clean_mode == "amateur":
		return minimum_amateur_per_gender

	return minimum_pro_per_gender


func _ensure_division_population_step(division: String, gender_division: String, mode: String, max_spawn_count: int = 6) -> bool:
	var clean_division: String = str(division).strip_edges()
	var clean_gender: String = str(gender_division).strip_edges()
	var clean_mode: String = str(mode).strip_edges().to_lower()

	if clean_division == "" or clean_gender == "" or clean_mode == "":
		return true
	if gs == null:
		return true
	if gs.era_engine == null or not gs.era_engine.supports_world_title_boxing():
		return true

	var target_count: int = _boxing_division_population_target_for_mode(clean_division, clean_mode)
	var current_count: int = _count_active_boxers_in_division(clean_division, clean_gender, clean_mode)
	var needed: int = max(0, target_count - current_count)

	if needed <= 0:
		return true

	var spawned_count: int = 0
	var spawn_limit: int = max(1, min(max_spawn_count, needed))

	while spawned_count < spawn_limit:
		var seeded_boxer: Person = _spawn_contract_boxing_faction_member(clean_division, {
			"gender_division": clean_gender,
			"force_mode": clean_mode
		})

		if seeded_boxer == null:
			break

		if gs.boxing_combat_resolution_engine != null and gs.boxing_combat_resolution_engine.has_method("build_fighter_snapshot"):
			gs.boxing_combat_resolution_engine.build_fighter_snapshot(seeded_boxer)

		if gs.boxing_ranking_engine != null:
			gs.boxing_ranking_engine.seed_fighter(seeded_boxer)

		spawned_count += 1

	return _count_active_boxers_in_division(clean_division, clean_gender, clean_mode) >= target_count
func should_seed_npc_into_boxing_amateurs(npc: Person) -> bool:
	if npc == null or not npc.alive:
		return false
	if npc == gs.player:
		return false
	if npc.boxing_profile.get("is_boxer", false):
		return false
	if npc.boxing_profile.get("retired", false):
		return false
	if gs == null or gs.era_engine == null or not gs.era_engine.supports_world_title_boxing():
		return false

	var allow_existing_world_npc_seeding: bool = false
	if gs.boxing_contract_engine != null and gs.boxing_contract_engine.has_method("get_boxing_policy"):
		allow_existing_world_npc_seeding = bool(gs.boxing_contract_engine.get_boxing_policy("allow_existing_world_npc_boxing_seeding", false))

	if not allow_existing_world_npc_seeding:
		return false

	if not bool(npc.boxing_profile.get("boxing_world_seed_candidate", false)):
		return false

	var minimum_age: int = 7
	var maximum_age: int = 18
	if gs.boxing_contract_engine != null and gs.boxing_contract_engine.has_method("get_boxing_policy"):
		minimum_age = int(gs.boxing_contract_engine.get_boxing_policy("minimum_boxing_start_age", 7))
		maximum_age = int(gs.boxing_contract_engine.get_boxing_policy("maximum_ordinary_new_amateur_seed_age", 18))

	if npc.age < minimum_age or npc.age > maximum_age:
		return false

	var target_division: String = _preferred_division_for_npc(npc)
	if target_division == "":
		return false

	return randi() % 100 < 1


func sync_boxing_division_factions() -> void:
	if gs == null:
		return

	var factions_raw: Variant = gs.scenario_state.get("boxing_division_factions", {})
	var factions: Dictionary = factions_raw if typeof(factions_raw) == TYPE_DICTIONARY else {}

	for division in gs.boxing_ranking_engine.rankings.keys():
		var division_name: String = str(division)
		var members: Array = _active_boxers_in_division(division_name)
		var faction_id: String = "boxing_division:%s" % division_name.to_lower().replace(" ", "_")
		var faction_default: Dictionary = {
			"id": faction_id,
			"name": "%s Boxing Circuit" % division_name,
			"owner_id": _division_owner_id(division_name),
			"founder_id": _division_owner_id(division_name),
			"pursuit_kind": "boxing_division",
			"division": division_name,
			"created_year": int(gs.year),
			"last_year_active": int(gs.year),
			"status": "active",
			"member_ids": {}
		}

		var faction_raw: Variant = factions.get(faction_id, faction_default)
		var faction: Dictionary = faction_raw if typeof(faction_raw) == TYPE_DICTIONARY else faction_default.duplicate(true)
		var rebuilt_members: Dictionary = {}

		for boxer in members:
			if boxer == null or not boxer.alive:
				continue
			var member_role: String = "contender"
			if _is_division_champion(boxer, division_name):
				member_role = "champion"
			elif int(boxer.boxing_profile.get("division_rank", 999)) <= 5:
				member_role = "ranked"
			rebuilt_members [str(int(boxer.id))] = {
				"npc_id": int(boxer.id),
				"role": member_role,
				"active": true,
				"joined_year": int(gs.year)
			}

		faction ["name"] = "%s Boxing Circuit" % division_name
		faction ["division"] = division_name
		faction ["owner_id"] = _division_owner_id(division_name)
		faction ["founder_id"] = int(faction.get("founder_id", _division_owner_id(division_name)))
		faction ["last_year_active"] = int(gs.year)
		faction ["status"] = "active"
		faction ["member_ids"] = rebuilt_members
		faction ["member_count"] = rebuilt_members.size()
		factions [faction_id] = faction

	gs.scenario_state ["boxing_division_factions"] = factions
	gs.scenario_state ["boxing_division_membership_index"] = _rebuild_boxing_division_membership_index(factions)


func _rebuild_boxing_division_membership_index(factions: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for raw_faction_id in factions.keys():
		var faction_raw: Variant = factions.get(raw_faction_id, {})
		var faction: Dictionary = faction_raw if typeof(faction_raw) == TYPE_DICTIONARY else {}
		var members_raw: Variant = faction.get("member_ids", {})
		var members: Dictionary = members_raw if typeof(members_raw) == TYPE_DICTIONARY else {}
		for raw_member_key in members.keys():
			var member_raw: Variant = members.get(raw_member_key, {})
			var member: Dictionary = member_raw if typeof(member_raw) == TYPE_DICTIONARY else {}
			var npc_key: String = str(int(member.get("npc_id", -1)))
			if npc_key == "-1":
				continue
			if not out.has(npc_key):
				out [npc_key] = {}
			out [npc_key] [str(raw_faction_id)] = {
				"faction_name": str(faction.get("name", "")),
				"division": str(faction.get("division", "")),
				"role": str(member.get("role", "member")),
				"active": bool(member.get("active", true)),
				"joined_year": int(member.get("joined_year", gs.year))
			}
	return out


func _ensure_division_population(division: String, _anchor_person: Person = null) -> void:
	var clean_division: String = str(division).strip_edges()
	if clean_division == "":
		return
	if gs == null:
		return
	if gs.era_engine == null or not gs.era_engine.supports_world_title_boxing():
		return

	var minimum_pro_per_gender: int = 26
	var minimum_amateur_per_gender: int = 24

	if gs.boxing_contract_engine != null and gs.boxing_contract_engine.has_method("get_division_target_count"):
		var contract_target: int = int(gs.boxing_contract_engine.get_division_target_count(clean_division))
		minimum_pro_per_gender = max(minimum_pro_per_gender, int(ceil(float(contract_target) * 0.52)))
		minimum_amateur_per_gender = max(minimum_amateur_per_gender, int(ceil(float(contract_target) * 0.48)))

	for gender_division in _boxing_gender_division_list():
		var clean_gender: String = str(gender_division)

		var needed_pro: int = max(0, minimum_pro_per_gender - _count_active_boxers_in_division(clean_division, clean_gender, "pro"))
		var seeded_pro: int = 0
		while seeded_pro < needed_pro:
			var seeded_pro_boxer: Person = _spawn_contract_boxing_faction_member(clean_division, {
				"gender_division": clean_gender,
				"force_mode": "pro"
			})
			if seeded_pro_boxer == null:
				break

			if gs.boxing_combat_resolution_engine != null and gs.boxing_combat_resolution_engine.has_method("build_fighter_snapshot"):
				gs.boxing_combat_resolution_engine.build_fighter_snapshot(seeded_pro_boxer)

			if gs.boxing_ranking_engine != null:
				gs.boxing_ranking_engine.seed_fighter(seeded_pro_boxer)

			seeded_pro += 1

		var needed_amateur: int = max(0, minimum_amateur_per_gender - _count_active_boxers_in_division(clean_division, clean_gender, "amateur"))
		var seeded_amateur: int = 0
		while seeded_amateur < needed_amateur:
			var seeded_amateur_boxer: Person = _spawn_contract_boxing_faction_member(clean_division, {
				"gender_division": clean_gender,
				"force_mode": "amateur"
			})
			if seeded_amateur_boxer == null:
				break

			if gs.boxing_combat_resolution_engine != null and gs.boxing_combat_resolution_engine.has_method("build_fighter_snapshot"):
				gs.boxing_combat_resolution_engine.build_fighter_snapshot(seeded_amateur_boxer)

			if gs.boxing_ranking_engine != null:
				gs.boxing_ranking_engine.seed_fighter(seeded_amateur_boxer)

			seeded_amateur += 1

		_seed_professional_champions_for_division_gender(clean_division, clean_gender)
func _boxing_normalized_gender_division(raw_gender: String) -> String:
	var clean_gender: String = str(raw_gender).strip_edges()
	var lower_gender: String = clean_gender.to_lower()

	if lower_gender in ["female", "woman", "girl", "f"]:
		return "Female"

	return "Male"


func _boxing_gendered_first_name(gender_division: String) -> String:
	if gs == null or gs.names_db == null:
		return ""

	var clean_gender: String = _boxing_normalized_gender_division(gender_division)
	var era_name: String = ""
	if gs.era != null:
		era_name = str(gs.era.name).strip_edges()
	if era_name == "":
		era_name = "Modern Era"

	if gs.names_db.has_method("random_first_for_era"):
		return str(gs.names_db.random_first_for_era(clean_gender, era_name)).strip_edges()

	return ""


func _apply_boxing_gender_identity_contract(person: Person, gender_division: String, reason: String = "boxing_gender_identity_contract") -> void:
	if person == null:
		return

	var clean_gender: String = _boxing_normalized_gender_division(gender_division)

	if "gender" in person:
		person.gender = clean_gender

	if typeof(person.boxing_profile) != TYPE_DICTIONARY:
		person.boxing_profile = {}

	person.boxing_profile ["boxing_gender_division"] = clean_gender

	var replacement_first_name: String = _boxing_gendered_first_name(clean_gender)
	if replacement_first_name != "":
		person.first_name = replacement_first_name
		var last_name_text: String = str(person.last_name).strip_edges() if "last_name" in person else ""
		person.name = ("%s %s" % [replacement_first_name, last_name_text]).strip_edges()

	person.boxing_profile ["boxing_gender_identity_locked"] = true
	person.boxing_profile ["boxing_gender_identity_lock_reason"] = reason
	person.boxing_profile ["boxing_gender_identity_locked_at_ms"] = int(Time.get_ticks_msec())


func normalize_generated_boxing_faction_identity_names(reason: String = "boxing_identity_sanitize") -> int:
	if gs == null:
		return 0

	var fixed_count: int = 0

	for raw_npc in gs.npcs:
		var npc:= raw_npc as Person
		if npc == null:
			continue
		if typeof(npc.boxing_profile) != TYPE_DICTIONARY:
			continue
		if not bool(npc.boxing_profile.get("generated_boxing_faction_member", false)):
			continue

		var clean_gender: String = _boxing_normalized_gender_division(str(npc.boxing_profile.get("boxing_gender_division", npc.gender if "gender" in npc else "Male")))
		var should_fix: bool = false

		if str(npc.boxing_profile.get("boxing_gender_division", "")).strip_edges() != clean_gender:
			should_fix = true
		if "gender" in npc and str(npc.gender).strip_edges() != clean_gender:
			should_fix = true
		if not bool(npc.boxing_profile.get("boxing_gender_identity_locked", false)):
			should_fix = true

		if not should_fix:
			continue

		_apply_boxing_gender_identity_contract(npc, clean_gender, reason)
		fixed_count += 1

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	gs.scenario_state ["boxing_gender_identity_last_sanitize_reason"] = reason
	gs.scenario_state ["boxing_gender_identity_last_sanitize_count"] = fixed_count
	gs.scenario_state ["boxing_gender_identity_last_sanitize_at_ms"] = int(Time.get_ticks_msec())

	return fixed_count
func _spawn_contract_boxing_faction_member(division: String, context: Dictionary = {}) -> Person:
	if gs == null or gs.npc_factory == null:
		return null

	var clean_division: String = str(division).strip_edges()
	if clean_division == "":
		return null

	var boxer: Person = gs.npc_factory.create_random_npc(false)
	if boxer == null:
		return null

	if gs.has_method("apply_reality_rules_to_person"):
		gs.apply_reality_rules_to_person(boxer)

	var forced_mode: String = str(context.get("force_mode", "")).strip_edges().to_lower()
	var stage: String = _boxing_faction_career_stage_for_seed()
	if forced_mode == "amateur":
		stage = "golden_gloves_amateur" if (randi() % 100) < 36 else "adult_amateur"
	elif forced_mode == "pro":
		var pro_roll: int = randi() % 100
		if pro_roll < 12:
			stage = "late_prime"
		elif pro_roll < 48:
			stage = "mid_career"
		else:
			stage = "prospect"

	var age_range: Vector2i = _boxing_faction_age_range_for_stage(stage)
	boxer.age = int(randi_range(age_range.x, age_range.y))
	boxer.alive = true

	var gender_division: String = _boxing_normalized_gender_division(str(context.get("gender_division", "")))
	if str(context.get("gender_division", "")).strip_edges() == "":
		var gender_text: String = str(boxer.gender if "gender" in boxer else "").strip_edges()
		gender_division = _boxing_normalized_gender_division(gender_text)

	_apply_boxing_gender_identity_contract(boxer, gender_division, "spawn_contract_boxing_faction_member")

	var is_amateur_stage: bool = stage in ["new_amateur", "adult_amateur", "golden_gloves_amateur"]

	gs.boxing_fighter_engine.initialize_fighter(boxer, {
		"source": "boxing_faction_loop",
		"generated_boxing_faction_member": true,
		"division": clean_division,
		"gender_division": gender_division,
		"career_stage": stage,
		"turned_pro": not is_amateur_stage,
		"force_amateur": is_amateur_stage
	})

	if typeof(boxer.boxing_profile.get("amateur_circuit", {})) != TYPE_DICTIONARY:
		boxer.boxing_profile ["amateur_circuit"] = {}

	boxer.boxing_profile ["weight_class"] = clean_division
	boxer.boxing_profile ["boxing_gender_division"] = gender_division
	boxer.boxing_profile ["generated_boxing_faction_member"] = true
	boxer.boxing_profile ["boxing_world_source"] = "contract_boxing_faction_loop"
	boxer.boxing_profile ["boxing_world_tier"] = _boxing_world_tier_for_stage(stage)
	boxer.boxing_profile ["division_rank"] = -1
	boxer.boxing_profile ["amateur_division_rank"] = -1

	var seeded_record: Dictionary = _boxing_faction_record_for_stage(stage)

	if is_amateur_stage:
		boxer.boxing_profile ["turned_pro"] = false
		boxer.boxing_profile ["record"] = {
			"wins": 0,
			"losses": 0,
			"draws": 0,
			"kos": 0
		}
		boxer.boxing_profile ["amateur_record"] = seeded_record
		boxer.boxing_profile ["amateur_circuit"] ["is_amateur"] = true
		boxer.boxing_profile ["amateur_circuit"] ["tier"] = "adult_amateur" if int(boxer.age) >= 18 else "youth_amateur"
		boxer.boxing_profile ["golden_gloves_wins"] = int(randi_range(1, 3)) if stage == "golden_gloves_amateur" else 0
	else:
		boxer.boxing_profile ["turned_pro"] = true
		boxer.boxing_profile ["record"] = seeded_record
		boxer.boxing_profile ["amateur_circuit"] ["is_amateur"] = false
		boxer.boxing_profile ["amateur_record"] = {
			"wins": randi_range(4, 28),
			"losses": randi_range(0, 8),
			"draws": randi_range(0, 2),
			"kos": randi_range(1, 12)
		}

	_seed_boxing_generated_fighter_experience(boxer, stage)

	if gs.has_method("register_npc"):
		gs.register_npc(boxer)
	else:
		gs.npcs.append(boxer)
		if gs.has_method("_rebuild_npc_index"):
			gs._rebuild_npc_index()

	return boxer
func _boxing_faction_career_stage_for_seed() -> String:
	var roll: int = randi() % 100
	if roll < 8:
		return "legendary"
	if roll < 22:
		return "late_prime"
	if roll < 48:
		return "mid_career"
	if roll < 76:
		return "prospect"
	if roll < 91:
		return "adult_amateur"
	return "golden_gloves_amateur"


func _boxing_faction_age_range_for_stage(stage: String) -> Vector2i:
	match stage:
		"legendary":
			return Vector2i(31, 41)
		"late_prime":
			return Vector2i(29, 36)
		"mid_career":
			return Vector2i(24, 32)
		"prospect":
			return Vector2i(18, 24)
		"adult_amateur":
			return Vector2i(18, 28)
		"golden_gloves_amateur":
			return Vector2i(18, 25)
		"new_amateur":
			return Vector2i(15, 21)
		_:
			return Vector2i(18, 30)

func _boxing_world_tier_for_stage(stage: String) -> String:
	match stage:
		"legendary":
			return "legend"
		"late_prime":
			return "champion"
		"mid_career":
			return "contender"
		"prospect":
			return "prospect"
		"adult_amateur":
			return "adult_amateur"
		"golden_gloves_amateur":
			return "golden_gloves"
		"new_amateur":
			return "local"
		_:
			return "local"


func _boxing_faction_record_for_stage(stage: String) -> Dictionary:
	match stage:
		"legendary":
			return {
				"wins": randi_range(34, 58),
				"losses": randi_range(0, 5),
				"draws": randi_range(0, 2),
				"kos": randi_range(18, 44)
			}
		"late_prime":
			return {
				"wins": randi_range(24, 40),
				"losses": randi_range(1, 8),
				"draws": randi_range(0, 2),
				"kos": randi_range(10, 29)
			}
		"mid_career":
			return {
				"wins": randi_range(12, 28),
				"losses": randi_range(1, 10),
				"draws": randi_range(0, 3),
				"kos": randi_range(4, 18)
			}
		"prospect":
			return {
				"wins": randi_range(3, 12),
				"losses": randi_range(0, 2),
				"draws": randi_range(0, 1),
				"kos": randi_range(1, 8)
			}
		"adult_amateur":
			return {
				"wins": randi_range(6, 24),
				"losses": randi_range(0, 8),
				"draws": randi_range(0, 2),
				"kos": randi_range(1, 10)
			}
		"golden_gloves_amateur":
			return {
				"wins": randi_range(12, 32),
				"losses": randi_range(0, 4),
				"draws": randi_range(0, 1),
				"kos": randi_range(4, 16)
			}
		"new_amateur":
			return {
				"wins": randi_range(0, 4),
				"losses": randi_range(0, 3),
				"draws": 0,
				"kos": randi_range(0, 2)
			}
		_:
			return {
				"wins": randi_range(0, 8),
				"losses": randi_range(0, 4),
				"draws": 0,
				"kos": randi_range(0, 5)
			}
func _seed_boxing_generated_fighter_experience(person: Person, stage: String) -> void:
	if person == null:
		return
	if typeof(person.boxing_profile) != TYPE_DICTIONARY:
		return

	var growth: Dictionary = {}
	var raw_growth: Variant = person.boxing_profile.get("growth", {})
	if typeof(raw_growth) == TYPE_DICTIONARY:
		growth = raw_growth
	else:
		growth = {
			"xp": 0,
			"total_levels": 0,
			"max_total_levels": 220,
			"max_skill_level": 20,
			"levels": {}
		}

	var levels: Dictionary = {}
	var raw_levels: Variant = growth.get("levels", {})
	if typeof(raw_levels) == TYPE_DICTIONARY:
		levels = raw_levels

	var level_floor: int = 0
	var level_ceiling: int = 3
	match stage:
		"legendary":
			level_floor = 12
			level_ceiling = 20
		"late_prime":
			level_floor = 9
			level_ceiling = 17
		"mid_career":
			level_floor = 5
			level_ceiling = 13
		"prospect":
			level_floor = 2
			level_ceiling = 8
		"golden_gloves_amateur":
			level_floor = 4
			level_ceiling = 10
		"adult_amateur":
			level_floor = 2
			level_ceiling = 7
		_:
			level_floor = 0
			level_ceiling = 4

	for skill_key in ["footwork", "jab", "defense", "power", "stamina", "ring_iq", "chin", "combinations"]:
		levels [skill_key] = int(randi_range(level_floor, level_ceiling))

	growth ["levels"] = levels
	growth ["total_levels"] = 0
	for raw_key in levels.keys():
		growth ["total_levels"] = int(growth.get("total_levels", 0)) + int(levels.get(raw_key, 0))

	person.boxing_profile ["growth"] = growth
	person.fame = clamp(int(person.fame) + int(randi_range(level_floor * 2, level_ceiling * 4)), 0, 100)

func _active_boxers_in_division(division: String, gender_division: String = "", mode: String = "") -> Array:
	var out: Array = []
	if gs == null:
		return out

	var clean_division: String = str(division).strip_edges()
	var clean_gender: String = str(gender_division).strip_edges()
	var clean_mode: String = str(mode).strip_edges().to_lower()

	for raw_npc in gs.npcs:
		var npc:= raw_npc as Person
		if npc == null or not npc.alive:
			continue
		if not bool(npc.boxing_profile.get("is_boxer", false)):
			continue
		if bool(npc.boxing_profile.get("retired", false)):
			continue
		if str(npc.boxing_profile.get("weight_class", "")).strip_edges() != clean_division:
			continue

		var npc_gender: String = str(npc.boxing_profile.get("boxing_gender_division", "")).strip_edges()
		if npc_gender == "":
			var gender_text: String = str(npc.gender if "gender" in npc else "").strip_edges().to_lower()
			npc_gender = "Female" if gender_text in ["female", "woman", "girl", "f"] else "Male"

		if clean_gender != "" and npc_gender != clean_gender:
			continue

		var turned_pro: bool = bool(npc.boxing_profile.get("turned_pro", false))
		if clean_mode == "pro" and not turned_pro:
			continue
		if clean_mode == "amateur" and turned_pro:
			continue

		out.append(npc)

	var rank_key: String = "amateur_division_rank" if clean_mode == "amateur" else "division_rank"
	out.sort_custom(func (a, b):
		return int(a.boxing_profile.get(rank_key, 999)) < int(b.boxing_profile.get(rank_key, 999))
	)

	return out

func _count_active_boxers_in_division(division: String, gender_division: String = "", mode: String = "") -> int:
	return _active_boxers_in_division(division, gender_division, mode).size()


func _preferred_division_for_npc(npc: Person) -> String:
	if npc == null:
		return ""
	var implied_weight: int = clamp(int(110 + float(npc.health) * 0.8 + float(npc.looks) * 0.35), 112, 240)
	if implied_weight <= 115:
		return "Flyweight"
	if implied_weight <= 118:
		return "Bantamweight"
	if implied_weight <= 126:
		return "Featherweight"
	if implied_weight <= 135:
		return "Lightweight"
	if implied_weight <= 147:
		return "Welterweight"
	if implied_weight <= 160:
		return "Middleweight"
	if implied_weight <= 175:
		return "Light Heavyweight"
	return "Heavyweight"


func _division_owner_id(division: String) -> int:
	if gs == null or gs.boxing_title_engine == null:
		return -1
	var champs = gs.boxing_title_engine.champions.get(division, {})
	if typeof(champs) != TYPE_DICTIONARY:
		return -1
	for belt in ["WBA", "WBC", "IBF", "WBO"]:
		var holder_id: int = int(champs.get(belt, -1))
		if holder_id != -1:
			return holder_id
	return -1


func _is_division_champion(person: Person, division: String) -> bool:
	if person == null or gs == null or gs.boxing_title_engine == null:
		return false
	var champs = gs.boxing_title_engine.champions.get(division, {})
	if typeof(champs) != TYPE_DICTIONARY:
		return false
	for belt in ["WBA", "WBC", "IBF", "WBO"]:
		if int(champs.get(belt, -1)) == int(person.id):
			return true
	return false

func describe_record(person: Person) -> String:
	if person == null or not person.boxing_profile.get("is_boxer", false):
		return "No boxing career."

	var rec = person.boxing_profile.get("record", {})
	return "🥊 Record: %d-%d-%d (%d KOs) | Division: %s | Rank: %d" % [
		int(rec.get("wins", 0)),
		int(rec.get("losses", 0)),
		int(rec.get("draws", 0)),
		int(rec.get("kos", 0)),
		str(person.boxing_profile.get("weight_class", "")),
		int(person.boxing_profile.get("division_rank", -1))
	]
func describe_last_fight_log(person: Person) -> String:
	if person == null:
		return "No fighter."

	var logs = person.boxing_profile.get("round_log_last_fight", [])
	if logs.is_empty():
		return "No recent fight log."

	var lines:= []
	for r in logs:
		lines.append("Round %d: %s" % [int(r.get("round", 0)), str(r.get("summary", ""))])

	return "\n".join(lines)
func nominate_scenarios_for_player(context:= {}) -> Array:
	var out: Array = []
	var player: Person = context.get("player", null)
	if player == null or not player.alive:
		return out
	if not player.boxing_profile.get("is_boxer", false):
		return out

	out.append({
		"id": "boxing_crossroads_%d" % int(context.get("year", 0)),
		"category": "boxing",
		"era_tags": ["Modern Era", "Future Era"],
		"reality_modes": ["realistic", "enhanced", "chaos"],
		"reality_weights": {
			"realistic": 1.2,
			"enhanced": 1.0,
			"chaos": 0.9
		},
		"tone": "ambitious",
		"rarity": 0.4,
		"cooldown_key": "boxing:crossroads",
		"cooldown_years": 2,
		"priority": 16,
		"min_age": 16,
		"max_age": 60,
		"prompt": "My boxing career feels like it could bend in a real direction this year. What do I commit to?",
		"followup_hooks": ["boxing.crossroads"],
		"bias_payloads": {},
		"choices": [
			{
				"id": "obsessive_training",
				"label": "Double down on training.",
				"journal_line": "I committed to treating boxing more seriously this year.",
				"followup_hooks": ["boxing.crossroads.training"],
				"bias_payloads": {
					"boxing_pressure": {
						"extra_training_bias": 35.0
					},
					"health_bias": {
						"stress_delta": 2.0
					},
					"reputation_bias": {
						"public_attention": 3.0
					},
					"expiry": {
						"years": 1
					}
				}
			},
			{
				"id": "chase_attention",
				"label": "Chase visibility and make noise.",
				"journal_line": "I decided to chase more attention around my boxing career.",
				"followup_hooks": ["boxing.crossroads.visibility"],
				"bias_payloads": {
					"boxing_pressure": {
						"extra_training_bias": 10.0
					},
					"reputation_bias": {
						"public_attention": 10.0
					},
					"world_feed_meta": {
						"category": "boxing"
					},
					"expiry": {
						"years": 1
					}
				}
			}
		]
	})

	return out