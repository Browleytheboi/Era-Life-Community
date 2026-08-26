extends Resource
class_name ScenarioEngine

var gs
var resolver: ScenarioResolver

const MAX_SURFACED_PER_YEAR:= 2

const DEFAULT_CATEGORY_BUDGETS:= {
	"school": 1,
	"boxing": 1,
	"crime": 1,
	"artifact": 1,
	"afterlife": 1,
	"career": 1,
	"social": 1,
	"general": 2
}

func _init(_gs):
	gs = _gs
	if gs != null and gs.scenario_resolver != null:
		resolver = gs.scenario_resolver
	else:
		resolver = ScenarioResolver.new(gs)
	_ensure_state()
	if gs != null and gs.event_bus != null:
		gs.event_bus.subscribe(ActionEventTypes.YEAR_PASSED, self, "yearly_asset_signal_tick")

func _ensure_state() -> void:
	if gs.scenario_state == null:
		gs.scenario_state = {}
	gs.scenario_state ["pending_type"] = gs.scenario_state.get("pending_type", "")
	gs.scenario_state ["pending_text"] = gs.scenario_state.get("pending_text", "")
	gs.scenario_state ["pending_lookup"] = gs.scenario_state.get("pending_lookup", {})
	gs.scenario_state ["pending_options"] = gs.scenario_state.get("pending_options", [])
	gs.scenario_state ["current_bundle"] = gs.scenario_state.get("current_bundle", [])
	gs.scenario_state ["current_bundle_index"] = int(gs.scenario_state.get("current_bundle_index", 0))
	gs.scenario_state ["committed_choices"] = gs.scenario_state.get("committed_choices", [])
	gs.scenario_state ["waiting_for_year_advance"] = bool(gs.scenario_state.get("waiting_for_year_advance", false))
	gs.scenario_state ["year_in_progress"] = bool(gs.scenario_state.get("year_in_progress", false))
	gs.scenario_state ["bundle_year"] = int(gs.scenario_state.get("bundle_year", -999999))
	gs.scenario_state ["bundle_built"] = bool(gs.scenario_state.get("bundle_built", false))
	gs.scenario_state ["cooldowns"] = gs.scenario_state.get("cooldowns", {})
	gs.scenario_state ["recent_followup_hooks"] = gs.scenario_state.get("recent_followup_hooks", [])
	gs.scenario_state ["recent_choices"] = gs.scenario_state.get("recent_choices", [])
	gs.scenario_state ["npc_mythic_pursuit_queue"] = gs.scenario_state.get("npc_mythic_pursuit_queue", [])
	gs.scenario_state ["npc_mythic_pursuit_seen"] = gs.scenario_state.get("npc_mythic_pursuit_seen", {})
	gs.scenario_state ["npc_mythic_micro_factions"] = gs.scenario_state.get("npc_mythic_micro_factions", {})
	gs.scenario_state ["npc_mythic_membership_index"] = gs.scenario_state.get("npc_mythic_membership_index", {})
	gs.scenario_state ["data_driven_scenario_registry"] = gs.scenario_state.get("data_driven_scenario_registry", {})
func queue_data_driven_scenario(scenario_id: String, actor: Person = null) -> Dictionary:
	_ensure_state()

	if gs == null or gs.simulation_contract_engine == null:
		return { "success": false, "text": "The data-driven scenario registry is unavailable."}

	if not gs.simulation_contract_engine.has_method("build_scenario_dictionary"):
		return { "success": false, "text": "The simulation contract engine cannot build scenario dictionaries."}

	var scenario: Dictionary = gs.simulation_contract_engine.build_scenario_dictionary(scenario_id)
	if scenario.is_empty():
		return { "success": false, "text": "No scenario contract exists for %s." % scenario_id}

	if actor == null:
		actor = gs.player

	scenario ["actor_id"] = int(actor.id) if actor != null else -1
	return queue_external_scenario(scenario)

func _resolve_reality_fusion_enter_universe_choice(actor: Person, scenario: Dictionary, choice: Dictionary, _committed: Dictionary) -> Dictionary:
	if gs == null or actor == null:
		return {}

	var choice_id: String = str(choice.get("id", "")).strip_edges()
	var enter_path: String = str(choice.get("reality_fusion_enter_path", scenario.get("reality_fusion_enter_path", ""))).strip_edges()
	var enter_label: String = str(choice.get("reality_fusion_enter_label", scenario.get("reality_fusion_enter_label", "another universe"))).strip_edges()
	if enter_label == "":
		enter_label = "another universe"

	var source_player: Dictionary = _rf_duel_dict(choice.get("reality_fusion_source_player", scenario.get("reality_fusion_source_player", {})))
	var source_name: String = _reality_fusion_ally_source_name(source_player)
	var contract: Dictionary = _rf_duel_dict(choice.get("reality_fusion_contract", scenario.get("reality_fusion_contract", {})))
	if contract.is_empty():
		contract = {
			"mode": "friend_person",
			"merge_policy": {
				"relationship": "bidirectional",
				"register_npcs": true,
				"rebuild_index": true
			}
		}

	var context: Dictionary = {
		"path": enter_path,
		"label": enter_label,
		"contract": contract.duplicate(true),
		"source_player": source_player.duplicate(true)
	}
	if choice_id == "reality_fusion_dimension_travel_cancel":
		_commit_reality_fusion_duel_aftermath(
			actor,
			"I chose not to travel dimensions through Reality Fusion.",
			"%s stepped away from a Reality Fusion dimension breach before entering." % _person_label_for_world_feed(actor),
			"reality_fusion_dimension_travel_cancelled"
		)
		return {
			"type": "scenario_commit_complete",
			"text": "I chose not to travel dimensions through Reality Fusion.",
			"popup_title": "Dimension Travel Cancelled",
			"popup_text": "You step away from the breach.\n\nThe portal folds inward before the other universe can notice you.",
			"popup_footer": "Tap anywhere to continue.",
			"opps": []
		}

	if choice_id == "reality_fusion_dimension_travel_confirm":
		_commit_reality_fusion_duel_aftermath(
			actor,
			"I chose to travel dimensions through Reality Fusion.", "%s crossed the threshold of a Reality Fusion dimension breach." % _person_label_for_world_feed(actor),
			"reality_fusion_dimension_travel_confirmed"
		)
		return _queue_reality_fusion_enter_universe_identity_scenario(actor, context)
	match choice_id:
		"reality_fusion_enter_go_back", "reality_fusion_enter_universe_cancel":
			_commit_reality_fusion_duel_aftermath(
				actor,
				"I stood inside the breach to %s, then went back to my own universe." % enter_label,
				"%s opened a Reality Fusion breach to %s, then returned home." % [_person_label_for_world_feed(actor), enter_label],
				"reality_fusion_enter_go_back"
			)
			return {
				"type": "scenario_commit_complete",
				"text": "I stood inside the breach to %s, then went back to my own universe." % enter_label,
				"popup_title": "Back To Your Universe",
				"popup_text": "You step backward.\n\nThe breach folds shut before %s can decide what you were." % source_name,
				"popup_footer": "Tap anywhere to continue.",
				"opps": []
			}

		"reality_fusion_enter_just_looking", "reality_fusion_enter_universe_risk":
			var entry_report: Dictionary = _record_reality_fusion_tva_entry(actor, enter_path, enter_label, "looking_around")
			if bool(entry_report.get("force_tva_intercept", false)):
				return _queue_reality_fusion_tva_intercept_scenario(actor, context, entry_report)

			_commit_reality_fusion_duel_aftermath(
				actor,
				"I entered %s and told %s I was just looking around." % [enter_label, source_name],
				"%s entered %s through a Reality Fusion breach and claimed it was only exploration." % [_person_label_for_world_feed(actor), enter_label],
				"reality_fusion_enter_just_looking"
			)

			return {
				"type": "scenario_commit_complete",
				"text": "I entered %s and told %s I was just looking around." % [enter_label, source_name],
				"popup_title": "Universe Entered",
				"popup_text": "You keep your hands visible.\n\n%s does not trust you yet, but the universe lets you through." % source_name,
				"popup_footer": "Tap anywhere to enter the universe.",
				"followup_result": {
					"type": "enter_universe_after_popup",
					"path": enter_path,
					"label": enter_label
				},
				"opps": []
			}

		"reality_fusion_enter_friend_request":
			var entry_report: Dictionary = _record_reality_fusion_tva_entry(actor, enter_path, enter_label, "friendship_request")
			if bool(entry_report.get("force_tva_intercept", false)):
				return _queue_reality_fusion_tva_intercept_scenario(actor, context, entry_report)

			var answer: Dictionary = _reality_fusion_ally_acceptance_roll(actor, source_player)
			var challenge_roll: float = randf()
			var source_has_power: bool = _reality_fusion_source_has_duel_powers(source_player)
			var challenged_first: bool = source_has_power and challenge_roll < 0.34

			if bool(answer.get("accepted", false)) and not challenged_first:
				var import_report: Dictionary = _reality_fusion_import_ally_from_context(context, false)
				var imported_name: String = str(import_report.get("imported_player_name", source_name)).strip_edges()
				if imported_name == "":
					imported_name = source_name

				_commit_reality_fusion_duel_aftermath(
					actor,
					"%s agreed to become my friend and crossed into my universe willingly." % imported_name,
					"%s crossed realities willingly after %s asked for friendship." % [imported_name, _person_label_for_world_feed(actor)],
					"reality_fusion_friendship_accepted"
				)

				return {
					"type": "scenario_commit_complete",
					"text": "%s agreed to become my friend and crossed into my universe willingly." % imported_name,
					"popup_title": "Friendship Accepted",
					"popup_text": "You ask plainly.\n\n%s studies your face, then says yes.\n\nThe portal widens, and they cross into your universe as a friend." % imported_name,
					"popup_footer": "Tap anywhere to continue.",
					"fusion_report": import_report,
					"opps": []
				}

			if source_has_power:
				context ["duel_intent"] = "friendship_challenge"
				return _begin_reality_fusion_ally_duel(actor, context)

			return _queue_reality_fusion_ally_refusal_scenario(actor, context, answer)

		"reality_fusion_enter_take_back":
			var entry_report: Dictionary = _record_reality_fusion_tva_entry(actor, enter_path, enter_label, "forced_crossover")
			if bool(entry_report.get("force_tva_intercept", false)):
				return _queue_reality_fusion_tva_intercept_scenario(actor, context, entry_report)

			if _reality_fusion_source_has_duel_powers(source_player):
				context ["duel_intent"] = "forced_crossover"
				return _begin_reality_fusion_ally_duel(actor, context)

			var forced_report: Dictionary = _reality_fusion_import_ally_from_context(context, true)
			_commit_reality_fusion_duel_aftermath(
				actor,
				"I forced %s out of %s and into my universe." % [source_name, enter_label],
				"%s forced %s out of %s through a Reality Fusion breach." % [_person_label_for_world_feed(actor), source_name, enter_label],
				"reality_fusion_forced_crossover"
			)

			return {
				"type": "scenario_commit_complete",
				"text": "I forced %s out of %s and into my universe." % [source_name, enter_label],
				"popup_title": "Forced Crossover",
				"popup_text": "%s could not stop the breach.\n\nYou pulled them into your universe, but the timeline noticed." % source_name,
				"popup_footer": "Tap anywhere to continue.",
				"fusion_report": forced_report,
				"opps": []
			}

		"reality_fusion_tva_explain":
			return _resolve_reality_fusion_tva_intercept(actor, context, "explain")

		"reality_fusion_tva_run":
			return _resolve_reality_fusion_tva_intercept(actor, context, "run")

		"reality_fusion_tva_fight":
			return _resolve_reality_fusion_tva_intercept(actor, context, "fight")

		"reality_fusion_tva_go_back":
			return _resolve_reality_fusion_tva_intercept(actor, context, "go_back")

	return {
		"type": "scenario_commit_complete",
		"text": str(choice.get("result_text", "The portal closed.")),
		"opps": []
	}
func _queue_reality_fusion_enter_universe_identity_scenario(_actor: Person, context: Dictionary) -> Dictionary:
	var clean_path: String = str(context.get("path", "")).strip_edges()
	var clean_label: String = str(context.get("label", "another universe")).strip_edges()
	if clean_label == "":
		clean_label = "another universe"

	var contract: Dictionary = _rf_duel_dict(context.get("contract", {}))
	var source_player: Dictionary = _rf_duel_dict(context.get("source_player", {}))
	var source_name: String = _reality_fusion_ally_source_name(source_player)
	var source_identity: String = str(source_player.get("identity", "parallel identity")).strip_edges()
	if source_identity == "":
		source_identity = "parallel identity"

	var prompt_text: String = "%s notices the breach after you step through.\n\n%s turns toward the tear in reality and asks:\n\n“Who are you... and why are you in my universe?”\n\nTarget universe: %s\nIdentity echo: %s\n\nEvery answer can bend the timeline differently." % [
		source_name,
		source_name,
		clean_label,
		source_identity
	]

	return queue_external_scenario({
		"id": "reality_fusion_enter_universe_identity_%d_%d" % [int(gs.year), int(Time.get_ticks_msec())],
		"source": "scenario_engine",
		"category": "reality_fusion",
		"cooldown_key": "reality_fusion_enter_universe_identity",
		"resolver_method": "_resolve_reality_fusion_enter_universe_choice",
		"panel_title": "REALITY FUSION — UNIVERSE BREACH",
		"footer_text": "You are not loading their life. You are standing in front of someone inside their timeline.",
		"prompt": prompt_text,
		"timeline_glitch": true,
		"reality_fusion_enter_path": clean_path,
		"reality_fusion_enter_label": clean_label,
		"reality_fusion_source_mode": str(context.get("source_mode", "unknown")),
		"reality_fusion_contract": contract.duplicate(true),
		"reality_fusion_source_player": source_player.duplicate(true),
		"choices": [
			_reality_fusion_context_choice_payload("reality_fusion_enter_just_looking", "Just looking around", "I entered another universe and said I was just looking around.", context),
			_reality_fusion_context_choice_payload("reality_fusion_enter_take_back", "Here to take you back to my universe", "I told someone from another universe I was there to take them back to mine.", context),
			_reality_fusion_context_choice_payload("reality_fusion_enter_friend_request", "Looking for friends. Will you be mine?", "I asked someone from another universe if they would be my friend.", context),
			_reality_fusion_context_choice_payload("reality_fusion_enter_go_back", "Go back to your universe", "I backed away from the breach and returned to my own universe.", context)
		]
	})
func _record_reality_fusion_tva_entry(actor: Person, enter_path: String, enter_label: String, motive: String) -> Dictionary:
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var entry_count: int = int(gs.scenario_state.get("tva_engine_universe_entry_count", 0)) + 1
	var heat: float = float(gs.scenario_state.get("tva_engine_heat", 0.0))
	heat += 1.0
	if str(motive).strip_edges().to_lower() in ["forced_crossover", "kidnap", "abduction"]:
		heat += 1.25
	elif str(motive).strip_edges().to_lower() == "friendship_request":
		heat += 0.35

	gs.scenario_state ["tva_engine_universe_entry_count"] = entry_count
	gs.scenario_state ["tva_engine_heat"] = heat
	gs.scenario_state ["tva_engine_last_universe_entry"] = {
		"path": str(enter_path).strip_edges(),
		"label": str(enter_label).strip_edges(),
		"motive": str(motive).strip_edges(),
		"year": int(gs.year),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	var force_tva: bool = entry_count >= 3 or heat >= 3.0
	if force_tva and gs.has_method("push_world_feed"):
		gs.push_world_feed("The TVA registered repeated universe-entry activity around %s." % _person_label_for_world_feed(actor), {
			"category": "reality_fusion",
			"event_name": "tva_engine_attention",
			"personally_relevant": true,
			"source": "scenario_engine",
			"heat": heat,
			"entry_count": entry_count
		})

	return {
		"entry_count": entry_count,
		"heat": heat,
		"force_tva_intercept": force_tva
	}


func _queue_reality_fusion_tva_intercept_scenario(_actor: Person, context: Dictionary, entry_report: Dictionary) -> Dictionary:
	var enter_label: String = str(context.get("label", "another universe")).strip_edges()
	if enter_label == "":
		enter_label = "another universe"

	var heat: float = float(entry_report.get("heat", 0.0))
	var entry_count: int = int(entry_report.get("entry_count", 0))

	return queue_external_scenario({
		"id": "reality_fusion_tva_intercept_%d_%d" % [int(gs.year), int(Time.get_ticks_msec())],
		"source": "scenario_engine",
		"category": "reality_fusion",
		"cooldown_key": "reality_fusion_tva_intercept",
		"resolver_method": "_resolve_reality_fusion_enter_universe_choice",
		"panel_title": "TVA — TIMELINE INTERCEPT",
		"footer_text": "You have entered too many timelines. The multiverse has started enforcing itself.",
		"timeline_glitch": true,
		"prompt": "You step toward %s, but the portal freezes mid-breath.\n\nA glowing door opens beside the breach.\n\nArmored timeline hunters step out.\n\n“You’ve entered too many timelines.”\n\nTVA heat: %.1f\nUniverse entries: %d\n\nThey are not asking politely." % [
			enter_label,
			heat,
			entry_count
		],
		"reality_fusion_enter_path": str(context.get("path", "")),
		"reality_fusion_enter_label": enter_label,
		"reality_fusion_contract": _rf_duel_dict(context.get("contract", {})),
		"reality_fusion_source_player": _rf_duel_dict(context.get("source_player", {})),
		"choices": [
			_reality_fusion_context_choice_payload("reality_fusion_tva_explain", "Explain yourself", "I tried to explain my timeline breach to the TVA.", context),
			_reality_fusion_context_choice_payload("reality_fusion_tva_run", "Run through the breach", "I ran from the TVA and forced myself through the breach.", context),
			_reality_fusion_context_choice_payload("reality_fusion_tva_fight", "Fight the hunters", "I fought the TVA hunters at the edge of the breach.", context),
			_reality_fusion_context_choice_payload("reality_fusion_tva_go_back", "Go back to your universe", "I backed away from the TVA and returned to my own universe.", context)
		]
	})


func _resolve_reality_fusion_tva_intercept(actor: Person, context: Dictionary, action: String) -> Dictionary:
	var enter_path: String = str(context.get("path", "")).strip_edges()
	var enter_label: String = str(context.get("label", "another universe")).strip_edges()
	if enter_label == "":
		enter_label = "another universe"

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var clean_action: String = str(action).strip_edges().to_lower()
	var heat: float = float(gs.scenario_state.get("tva_engine_heat", 0.0))
	var instability_gain: float = 0.0
	var health_loss: int = 0
	var mental_loss: int = 0

	match clean_action:
		"explain":
			var success_chance: float = clamp(0.28 + float(actor.smarts) / 260.0 + float(actor.fame) / 400.0, 0.18, 0.72)
			if randf() < success_chance:
				heat = max(0.0, heat - 1.25)
				gs.scenario_state ["tva_engine_heat"] = heat
				_commit_reality_fusion_duel_aftermath(
					actor,
					"I talked my way past the TVA and entered %s under surveillance." % enter_label,
					"%s talked past TVA hunters and entered %s under surveillance." % [_person_label_for_world_feed(actor), enter_label],
					"reality_fusion_tva_explained"
				)
				return {
					"type": "scenario_commit_complete",
					"text": "I talked my way past the TVA and entered %s under surveillance." % enter_label,
					"popup_title": "TVA Suspicious",
					"popup_text": "You explain yourself.\n\nThe hunters do not believe all of it, but they step aside.\n\nThe timeline lets you pass under surveillance.",
					"popup_footer": "Tap anywhere to enter the universe.",
					"followup_result": {
						"type": "enter_universe_after_popup",
						"path": enter_path,
						"label": enter_label
					},
					"opps": []
				}

			heat += 0.75
			instability_gain = 2.0
			mental_loss = 8

		"run":
			heat += 1.5
			instability_gain = 3.0
			health_loss = randi_range(4, 14)
			mental_loss = randi_range(5, 12)

		"fight":
			heat += 2.25
			instability_gain = 4.0
			health_loss = randi_range(10, 26)
			mental_loss = randi_range(8, 18)

		"go_back":
			heat = max(0.0, heat - 0.5)
			gs.scenario_state ["tva_engine_heat"] = heat
			_commit_reality_fusion_duel_aftermath(
				actor,
				"I backed away from the TVA and returned to my own universe.",
				"%s backed away from a TVA intercept and returned home." % _person_label_for_world_feed(actor),
				"reality_fusion_tva_backed_down"
			)
			return {
				"type": "scenario_commit_complete",
				"text": "I backed away from the TVA and returned to my own universe.",
				"popup_title": "Timeline Released",
				"popup_text": "You lower your hands and step backward.\n\nThe hunters watch until the breach seals.",
				"popup_footer": "Tap anywhere to continue.",
				"opps": []
			}

	gs.scenario_state ["tva_engine_heat"] = heat
	gs.scenario_state ["reality_fusion_identity_instability"] = float(gs.scenario_state.get("reality_fusion_identity_instability", 0.0)) + instability_gain

	var before_health: int = int(actor.health)
	var before_mental: int = int(actor.mental_health)
	if health_loss > 0:
		actor.health = max(1, int(actor.health) - health_loss)
	if mental_loss > 0:
		actor.mental_health = max(0, int(actor.mental_health) - mental_loss)

	_commit_reality_fusion_duel_aftermath(
		actor,
		"I forced my way through a TVA intercept and entered %s. My health changed from %d to %d and my mental health changed from %d to %d." % [
			enter_label,
			before_health,
			int(actor.health),
			before_mental,
			int(actor.mental_health)
		],
		"%s forced through TVA hunters and entered %s." % [_person_label_for_world_feed(actor), enter_label],
		"reality_fusion_tva_forced_entry"
	)

	return {
		"type": "scenario_commit_complete",
		"text": "I forced my way through a TVA intercept and entered %s." % enter_label,
		"popup_title": "Timeline Breached",
		"popup_text": "You break through the TVA line.\n\nHealth: %d → %d\nMental: %d → %d\n\nThe universe opens, but it opens angry." % [
			before_health,
			int(actor.health),
			before_mental,
			int(actor.mental_health)
		],
		"popup_footer": "Tap anywhere to enter the universe.",
		"followup_result": {
			"type": "enter_universe_after_popup",
			"path": enter_path,
			"label": enter_label
		},
		"opps": []
	}
func _resolve_data_driven_scenario_choice(actor: Person, scenario: Dictionary, choice: Dictionary, _committed: Dictionary) -> Dictionary:
	if gs == null or gs.simulation_contract_engine == null:
		return {
			"type": "scenario_commit_complete",
			"text": "The scenario contract could not resolve right now.",
			"opps": []
		}

	var scenario_id: String = str(choice.get("data_scenario_id", scenario.get("id", ""))).strip_edges()
	if gs.simulation_contract_engine.has_method("resolve_data_driven_scenario_choice"):
		return gs.simulation_contract_engine.resolve_data_driven_scenario_choice(actor, scenario_id, choice)

	return {
		"type": "scenario_commit_complete",
		"text": str(choice.get("result_text", "The moment passed.")),
		"opps": []
	}
func _resolve_reality_fusion_ally_choice(actor: Person, scenario: Dictionary, choice: Dictionary, _committed: Dictionary) -> Dictionary:
	if gs == null or actor == null:
		return {}

	var choice_id: String = str(choice.get("id", "")).strip_edges()
	var context: Dictionary = _reality_fusion_ally_context_from_choice(scenario, choice)
	var source_player: Dictionary = _rf_duel_dict(context.get("source_player", {}))
	var source_name: String = _reality_fusion_ally_source_name(source_player)

	match choice_id:
		"reality_fusion_ally_walk_away":
			return {
				"type": "scenario_commit_complete",
				"text": "I left %s in their own universe." % source_name,
				"popup_title": "Reality Left Alone",
				"popup_text": "You step away from the portal.\n\n%s remains in their own timeline." % source_name,
				"popup_footer": "Tap anywhere to continue.",
				"opps": []
			}

		"reality_fusion_ally_ask":
			var answer: Dictionary = _reality_fusion_ally_acceptance_roll(actor, source_player)
			if bool(answer.get("accepted", false)):
				var import_report: Dictionary = _reality_fusion_import_ally_from_context(context, false)
				var _success: bool = bool(import_report.get("success", false))
				var imported_name: String = str(import_report.get("imported_player_name", source_name)).strip_edges()
				if imported_name == "":
					imported_name = source_name

				return {
					"type": "scenario_commit_complete",
					"text": "%s agreed to cross realities and join my timeline." % imported_name,
					"popup_title": "Allegiance Accepted",
					"popup_text": "%s listened.\n\nThey said yes.\n\nThe portal widened, and they crossed into your universe as an ally." % imported_name,
					"popup_footer": "Tap anywhere to continue.",
					"fusion_report": import_report,
					"opps": []
				}

			return _queue_reality_fusion_ally_refusal_scenario(actor, context, answer)

		"reality_fusion_ally_leave_after_refusal":
			return {
				"type": "scenario_commit_complete",
				"text": "%s refused allegiance, and I chose not to force it." % source_name,
				"popup_title": "Refusal Accepted",
				"popup_text": "%s said no.\n\nYou let the portal close." % source_name,
				"popup_footer": "Tap anywhere to continue.",
				"opps": []
			}

		"reality_fusion_ally_kidnap":
			if _reality_fusion_source_has_duel_powers(source_player):
				return _begin_reality_fusion_ally_duel(actor, context)

			var forced_report: Dictionary = _reality_fusion_import_ally_from_context(context, true)
			return {
				"type": "scenario_commit_complete",
				"text": "I forced %s into my universe." % source_name,
				"popup_title": "Forced Crossover",
				"popup_text": "%s had no power strong enough to stop the kidnapping.\n\nThey crossed into your timeline, but not willingly." % source_name,
				"popup_footer": "Tap anywhere to continue.",
				"fusion_report": forced_report,
				"opps": []
			}

	if bool(choice.get("reality_fusion_ally_duel_choice", false)):
		return _resolve_reality_fusion_ally_duel_turn(actor, choice)

	return {
		"type": "scenario_commit_complete",
		"text": str(choice.get("result_text", "The portal closed.")),
		"opps": []
	}


func _queue_reality_fusion_ally_refusal_scenario(_actor: Person, context: Dictionary, answer: Dictionary) -> Dictionary:
	var source_player: Dictionary = _rf_duel_dict(context.get("source_player", {}))
	var source_name: String = _reality_fusion_ally_source_name(source_player)
	var refusal_line: String = str(answer.get("reason", "%s said no." % source_name)).strip_edges()

	return queue_external_scenario({
		"id": "reality_fusion_ally_refusal_%d_%d" % [int(gs.year), int(Time.get_ticks_msec())],
		"source": "scenario_engine",
		"category": "social",
		"cooldown_key": "reality_fusion_ally_refusal",
		"resolver_method": "_resolve_reality_fusion_ally_choice",
		"panel_title": "REALITY FUSION — REFUSAL",
		"footer_text": "This is the line between alliance and abduction.",
		"prompt": "%s\n\n%s refuses allegiance.\n\nThe portal stays open, waiting on what kind of person you are going to become." % [refusal_line, source_name],
		"choices": [
			_reality_fusion_context_choice_payload("reality_fusion_ally_kidnap", "Kidnap them?", "I chose to force the crossover after refusal.", context),
			_reality_fusion_context_choice_payload("reality_fusion_ally_leave_after_refusal", "Leave it alone", "I accepted the refusal and left the other universe alone.", context)
		]
	})


func _begin_reality_fusion_ally_duel(actor: Person, context: Dictionary) -> Dictionary:
	var source_player: Dictionary = _rf_duel_dict(context.get("source_player", {}))
	var source_name: String = _reality_fusion_ally_source_name(source_player)
	var enemy_power: int = _reality_fusion_source_power_score(source_player)
	var player_power: int = _reality_fusion_player_power_score(actor)
	var player_hp_max: int = max(40, int(actor.health) + int(float(player_power) * 0.35))
	var enemy_hp_max: int = max(45, int(_reality_fusion_source_stat(source_player, "health", 70.0)) + int(float(enemy_power) * 0.45))
	var duel_intent: String = str(context.get("duel_intent", "forced_crossover")).strip_edges().to_lower()

	var opening_text: String = "They refused quietly at first.\n\nThen their power rose behind their eyes.\n\nIf you want them in your universe now, you will have to take them."
	if duel_intent == "friendship_challenge":
		opening_text = "%s does not say yes yet.\n\nThey step between you and the portal.\n\n“If you want friendship across realities, prove you are not just another threat.”" % source_name

	var duel: Dictionary = {
		"active": true,
		"round": 1,
		"duel_intent": duel_intent,
		"path": str(context.get("path", "")),
		"label": str(context.get("label", "")),
		"contract": _rf_duel_dict(context.get("contract", {})),
		"source_player": source_player.duplicate(true),
		"source_name": source_name,
		"player_hp": player_hp_max,
		"player_hp_max": player_hp_max,
		"enemy_hp": enemy_hp_max,
		"enemy_hp_max": enemy_hp_max,
		"player_power": player_power,
		"enemy_power": enemy_power,
		"enemy_position": "guarding the portal with their weight shifted forward",
		"last_enemy_move": {},
		"last_response_text": opening_text,
		"last_shake_amount": 0.0,
		"actions_taken": [],
		"total_damage_to_player": 0,
		"total_damage_to_enemy": 0,
		"largest_hit_to_player": 0,
		"largest_hit_to_enemy": 0,
		"phase": "player_action",
		"pending_enemy_move": {},
		"pending_player_attack": {},
		"pending_player_guard": 0,
		"time_loop_state": _duel_default_time_loop_state(actor, null, "reality_fusion_ally")
	}

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	gs.scenario_state ["reality_fusion_ally_duel"] = duel
	return _queue_reality_fusion_ally_duel_round(actor, str(duel.get("last_response_text", "")))
func _bending_duel_live_adaptation_profile(actor: Person, element: String, context: Dictionary = {}) -> Dictionary:
	var level: int = _bending_duel_level(actor, element)

	var speed: float = 0.3
	if actor != null:
		speed += float(level) / 155.0
		speed += float(actor.smarts) / 285.0
		speed += float(actor.mental_health) / 420.0
		speed += float(actor.ambition) / 520.0

	if bool(context.get("mock_match", false)):
		speed += 0.05

	var archive_study: Dictionary = _rf_duel_dict(context.get("archive_study", {}))
	var study_bonus: int = int(archive_study.get("bonus", 0))
	if study_bonus > 0:
		speed += float(study_bonus) / 110.0

	speed = clamp(speed, 0.22, 1.38)

	return {
		"schema": "eralife.bending_duel_live_adaptation_profile",
		"version": 2,
		"actor_id": int(actor.id) if actor != null else -1,
		"actor_name": ("%s %s" % [actor.first_name, actor.last_name]).strip_edges() if actor != null else "Unknown",
		"element": element,
		"level": level,
		"speed": speed,
		"ceiling": clamp(4 + int(round(float(level) / 8.0)) + int(float(study_bonus) / 2.0), 4, 30),
		"current_bonus": study_bonus,
		"archive_study_bonus": study_bonus,
		"archive_study": archive_study.duplicate(true),
		"side": str(context.get("side", ""))
	}
func _bending_duel_live_adaptation_gain(profile: Dictionary, under_pressure: bool) -> int:
	var current_bonus: int = int(profile.get("current_bonus", 0))
	var ceiling: int = int(profile.get("ceiling", 12))
	var speed: float = float(profile.get("speed", 0.5))
	var gain: int = max(1, int(round(speed * (3.0 if under_pressure else 1.25))))
	return clamp(current_bonus + gain, 0, ceiling)
func _bending_duel_register_live_adaptation(duel: Dictionary, player_family: String, player_damage: int, enemy_damage: int) -> Dictionary:
	var player_adaptation: Dictionary = _rf_duel_dict(duel.get("player_adaptation", {}))
	var target_adaptation: Dictionary = _rf_duel_dict(duel.get("target_adaptation", {}))

	var player_under_pressure: bool = enemy_damage > player_damage
	var target_under_pressure: bool = player_damage >= enemy_damage

	player_adaptation ["current_bonus"] = _bending_duel_live_adaptation_gain(player_adaptation, player_under_pressure)
	target_adaptation ["current_bonus"] = _bending_duel_live_adaptation_gain(target_adaptation, target_under_pressure)

	var memory: Array = duel.get("exchange_memory", []) if typeof(duel.get("exchange_memory", [])) == TYPE_ARRAY else []
	memory.append({
		"round": int(duel.get("round", 1)),
		"player_choice_family": player_family,
		"player_damage": player_damage,
		"enemy_damage": enemy_damage,
		"player_adaptation_bonus": int(player_adaptation.get("current_bonus", 0)),
		"target_adaptation_bonus": int(target_adaptation.get("current_bonus", 0))
	})
	while memory.size() > 12:
		memory.pop_front()

	duel ["player_adaptation"] = player_adaptation
	duel ["target_adaptation"] = target_adaptation
	duel ["exchange_memory"] = memory
	duel ["last_player_choice_family"] = player_family

	return duel
func _duel_default_time_loop_state(actor: Person, target: Person = null, duel_scope: String = "") -> Dictionary:
	return {
		"schema": "eralife.duel_time_loop_state",
		"version": 1,
		"active": false,
		"duel_scope": str(duel_scope).strip_edges().to_lower(),
		"loop_count": 0,
		"player_prediction": 0,
		"player_adaptation": 0,
		"opponent_prediction": 0,
		"opponent_adaptation": 0,
		"opponent_strain": 0,
		"opponent_confusion": 0,
		"opponent_archetype": _duel_time_loop_opponent_archetype(actor, target, duel_scope),
		"dialogue_history": [],
		"last_dialogue": "",
		"last_effect_text": "",
		"last_loop_year": int(gs.year) if gs != null else 0,
		"last_loop_ms": 0,
		"actor_id": int(actor.id) if actor != null else -1,
		"target_id": int(target.id) if target != null else -1,
		"target_name": _duel_time_loop_target_name(target, duel_scope)
	}


func _duel_normalize_time_loop_state(duel: Dictionary, actor: Person, target: Person = null, duel_scope: String = "") -> Dictionary:
	var state: Dictionary = _rf_duel_dict(duel.get("time_loop_state", {}))
	var defaults: Dictionary = _duel_default_time_loop_state(actor, target, duel_scope)

	for key in defaults.keys():
		if not state.has(key):
			state [key] = defaults [key]

	state ["schema"] = "eralife.duel_time_loop_state"
	state ["version"] = 1
	state ["duel_scope"] = str(state.get("duel_scope", duel_scope)).strip_edges().to_lower()
	if str(state.get("duel_scope", "")) == "":
		state ["duel_scope"] = str(duel_scope).strip_edges().to_lower()

	state ["loop_count"] = max(0, int(state.get("loop_count", 0)))
	state ["player_prediction"] = clamp(int(state.get("player_prediction", 0)), 0, 999)
	state ["player_adaptation"] = clamp(int(state.get("player_adaptation", 0)), 0, 999)
	state ["opponent_prediction"] = clamp(int(state.get("opponent_prediction", 0)), 0, 999)
	state ["opponent_adaptation"] = clamp(int(state.get("opponent_adaptation", 0)), 0, 999)
	state ["opponent_strain"] = clamp(int(state.get("opponent_strain", 0)), 0, 999)
	state ["opponent_confusion"] = clamp(int(state.get("opponent_confusion", 0)), 0, 999)

	if str(state.get("opponent_archetype", "")).strip_edges() == "":
		state ["opponent_archetype"] = _duel_time_loop_opponent_archetype(actor, target, duel_scope)

	if typeof(state.get("dialogue_history", [])) != TYPE_ARRAY:
		state ["dialogue_history"] = []

	return state


func _duel_actor_has_time_stone(actor: Person) -> bool:
	if actor == null or gs == null:
		return false

	if gs.artifacts_engine != null and gs.artifacts_engine.has_method("person_has_stone"):
		if bool(gs.artifacts_engine.person_has_stone(actor, "Time")):
			return true

	if gs.belongings_engine != null and gs.belongings_engine.has_method("get_all_items_flat"):
		var items: Array = gs.belongings_engine.get_all_items_flat(actor)
		for raw_item in items:
			if typeof(raw_item) != TYPE_DICTIONARY:
				continue

			var item: Dictionary = raw_item
			if _duel_item_is_time_stone(item):
				return true

	return false


func _duel_item_is_time_stone(item: Dictionary) -> bool:
	var item_name: String = str(item.get("display_name", item.get("name", item.get("item_name", "")))).strip_edges().to_lower()
	var item_id: String = str(item.get("id", item.get("item_id", ""))).strip_edges().to_lower()
	var normalized_name: String = item_name.replace("_", " ")
	var normalized_id: String = item_id.replace("_", " ")

	if normalized_name == "time stone":
		return true
	if normalized_id == "time stone":
		return true
	if normalized_id == "time stone".replace(" ", "_"):
		return true
	if normalized_name.find("time stone") >= 0:
		return true

	return false


func _duel_time_loop_action_choices(actor: Person, duel: Dictionary, target: Person = null, duel_scope: String = "") -> Array:
	var out: Array = []
	if actor == null:
		return out
	if not _duel_actor_has_time_stone(actor):
		return out

	var state: Dictionary = _duel_normalize_time_loop_state(duel, actor, target, duel_scope)
	var loop_count: int = int(state.get("loop_count", 0))
	var label: String = "Create a time loop and tell them you've come to bargain"
	if loop_count > 0:
		label = "Reset the time loop and bargain again"

	out.append({
		"id": "time_loop_bargain",
		"label": label,
		"journal_text": "I used the Time Stone to create a duel time loop.",
		"choice_family": "time_loop",
		"family": "time_loop",
		"power_source": "artifact",
		"button_theme": "artifact_action",
		"artifact_id": "time_stone",
		"artifact_name": "Time Stone",
		"time_loop_duel_choice": true,
		"reality_fusion_ally_duel_choice": bool(str(duel_scope).strip_edges().to_lower() == "reality_fusion_ally"),
		"bending_duel_imported_reality_fusion_action": false,
		"disabled": false
	})

	return out

func _duel_time_loop_last_chance_available(actor: Person, duel: Dictionary, duel_scope: String) -> bool:
	if actor == null:
		return false
	if not _duel_actor_has_time_stone(actor):
		return false
	if bool(duel.get("time_loop_last_chance_declined", false)):
		return false
	if bool(duel.get("time_loop_last_chance_consumed", false)):
		return false

	var state: Dictionary = _duel_normalize_time_loop_state(duel, actor, null, duel_scope)
	var _loop_count: int = int(state.get("loop_count", 0))
	var max_last_chances: int = 1 + int(clamp(float(_duel_person_stat_score(actor, "willpower", 50.0)) / 75.0, 0.0, 2.0))
	var used: int = int(state.get("post_defeat_bargains", 0))
	return used < max_last_chances

func _queue_duel_time_loop_last_chance(_actor: Person, target: Person, duel: Dictionary, duel_scope: String, loss_text: String = "") -> Dictionary:
	var clean_scope: String = str(duel_scope).strip_edges().to_lower()
	var state_key: String = "bending_scenario_duel"
	var resolver_method: String = "_resolve_duel_time_loop_last_chance_choice"
	var panel_title: String = "TIME STONE — OUTCOME REJECTED"
	var target_name: String = "your opponent"

	if clean_scope == "reality_fusion_ally":
		state_key = "reality_fusion_ally_duel"
		target_name = str(duel.get("source_name", "Saved Character")).strip_edges()
	else:
		target_name = str(duel.get("target_name", "your opponent")).strip_edges()

	if target_name == "":
		target_name = "your opponent"

	duel ["pending_time_loop_last_chance"] = true
	duel ["pending_time_loop_last_chance_scope"] = clean_scope
	duel ["phase"] = "time_loop_last_chance"

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	gs.scenario_state [state_key] = duel

	var prompt_lines: Array = []
	var clean_loss_text: String = str(loss_text).strip_edges()
	if clean_loss_text != "":
		prompt_lines.append(clean_loss_text)

	prompt_lines.append("%s beat you." % target_name)
	prompt_lines.append("The outcome starts to lock into place.")
	prompt_lines.append("")
	prompt_lines.append("But the Time Stone burns in your possession.")
	prompt_lines.append("")
	prompt_lines.append("Body resets: ❌")
	prompt_lines.append("Mind resets: ❌")
	prompt_lines.append("Reality resets: ❌")
	prompt_lines.append("")
	prompt_lines.append("Only the outcome resets: ✅")

	return queue_external_scenario({
		"id": "duel_time_loop_last_chance_%s_%d_%d" % [clean_scope, int(gs.year), int(Time.get_ticks_msec())],
		"source": "scenario_engine",
		"category": "artifact",
		"cooldown_key": "duel_time_loop_last_chance",
		"resolver_method": resolver_method,
		"panel_title": panel_title,
		"footer_text": "Use the Time Stone after defeat, not before it.",
		"timeline_glitch": true,
		"prompt": "\n".join(prompt_lines),
		"duel_scope": clean_scope,
		"target_id": int(target.id) if target != null else -1,
		"choices": [
			{
				"id": "time_loop_last_chance_bargain",
				"label": "Create a time loop and tell them you've come to bargain",
				"journal_text": "I rejected the duel outcome with the Time Stone.",
				"choice_family": "time_loop_last_chance",
				"power_source": "artifact",
				"artifact_id": "time_stone",
				"artifact_name": "Time Stone",
				"button_theme": "artifact_action",
				"duel_scope": clean_scope
			},
			{
				"id": "time_loop_last_chance_accept_loss",
				"label": "Accept the outcome",
				"journal_text": "I accepted the duel outcome.",
				"choice_family": "accept_loss",
				"power_source": "survival",
				"button_theme": "defensive_escape",
				"duel_scope": clean_scope
			}
		]
	})

func _resolve_duel_time_loop_last_chance_choice(actor: Person, scenario: Dictionary, choice: Dictionary, _committed: Dictionary) -> Dictionary:
	if gs == null or actor == null:
		return {}

	var duel_scope: String = str(choice.get("duel_scope", scenario.get("duel_scope", ""))).strip_edges().to_lower()
	var choice_id: String = str(choice.get("id", "")).strip_edges().to_lower()

	if duel_scope == "reality_fusion_ally":
		var rf_duel: Dictionary = _rf_duel_dict(gs.scenario_state.get("reality_fusion_ally_duel", {}))
		if rf_duel.is_empty():
			return {
				"type": "scenario_commit_complete",
				"text": "The Reality Fusion duel was no longer available.",
				"popup_title": "Time Loop Failed",
				"popup_text": "The duel state was missing.",
				"popup_footer": "Tap anywhere to continue.",
				"opps": []
			}

		if choice_id == "time_loop_last_chance_accept_loss":
			rf_duel ["pending_time_loop_last_chance"] = false
			rf_duel ["time_loop_last_chance_declined"] = true
			gs.scenario_state ["reality_fusion_ally_duel"] = rf_duel
			return _resolve_reality_fusion_ally_duel_loss(actor, rf_duel)

		rf_duel = _duel_apply_post_defeat_time_loop_bargain(actor, null, rf_duel, "reality_fusion_ally", choice)
		gs.scenario_state ["reality_fusion_ally_duel"] = rf_duel
		return _queue_reality_fusion_ally_duel_round(actor, _duel_time_loop_preface(rf_duel))

	var bending_duel: Dictionary = _rf_duel_dict(gs.scenario_state.get("bending_scenario_duel", {}))
	var target: Person = _scenario_person_by_id(int(bending_duel.get("target_id", scenario.get("target_id", -1))))
	if bending_duel.is_empty() or target == null:
		return {
			"type": "scenario_commit_complete",
			"text": "The bending duel was no longer available.",
			"popup_title": "Time Loop Failed",
			"popup_text": "The duel state or opponent was missing.",
			"popup_footer": "Tap anywhere to continue.",
			"opps": []
		}

	if choice_id == "time_loop_last_chance_accept_loss":
		bending_duel ["pending_time_loop_last_chance"] = false
		bending_duel ["time_loop_last_chance_declined"] = true
		gs.scenario_state ["bending_scenario_duel"] = bending_duel
		return _finish_bending_duel_loss(actor, target, bending_duel)

	bending_duel = _duel_apply_post_defeat_time_loop_bargain(actor, target, bending_duel, "bending", choice)
	gs.scenario_state ["bending_scenario_duel"] = bending_duel
	return _queue_bending_duel_round(actor, _duel_time_loop_preface(bending_duel))

func _duel_apply_post_defeat_time_loop_bargain(actor: Person, target: Person, duel: Dictionary, duel_scope: String, choice: Dictionary = {}) -> Dictionary:
	var clean_scope: String = str(duel_scope).strip_edges().to_lower()
	var state: Dictionary = _duel_normalize_time_loop_state(duel, actor, target, clean_scope)
	var used: int = int(state.get("post_defeat_bargains", 0)) + 1
	state ["post_defeat_bargains"] = used
	duel ["time_loop_state"] = state

	duel = _duel_apply_time_loop_bargain(actor, target, duel, clean_scope, choice)

	if clean_scope == "reality_fusion_ally":
		duel ["player_hp"] = max(1, int(duel.get("player_hp_max", max(1, int(actor.health)))))
		duel ["enemy_hp"] = max(1, int(duel.get("enemy_hp", duel.get("enemy_hp_max", 1))))
		duel ["enemy_position"] = "remembering an outcome that no longer gets to finish"
	else:
		duel ["player_hp"] = max(1, int(duel.get("player_hp_max", max(1, int(actor.health)))))
		duel ["target_hp"] = max(1, int(duel.get("target_hp", duel.get("target_hp_max", 1))))
		duel ["target_position"] = "confused by a victory they remember but no longer own"

	duel ["pending_time_loop_last_chance"] = false
	duel ["time_loop_last_chance_consumed"] = true
	duel ["time_loop_last_chance_declined"] = false
	duel ["phase"] = "player_action"
	duel ["pending_enemy_move"] = {}
	duel ["pending_player_attack"] = {}
	duel ["pending_player_guard"] = 0
	duel ["round"] = int(duel.get("round", 1)) + 1
	duel ["last_response_text"] = "The outcome broke.\n\nYou returned to the fight at full duel strength.\n\nYour opponent still remembers beating you.\n\n\"I've come to bargain.\""
	return duel

func _duel_apply_willpower_outcome_resistance(defeated: Person, opponent: Person, duel: Dictionary, duel_scope: String, side: String) -> Dictionary:
	if defeated == null:
		return {
			"triggered": false,
			"reason": "missing_defeated_person"
		}
	if gs == null or not ("willpower_engine" in gs) or gs.willpower_engine == null:
		return {
			"triggered": false,
			"reason": "willpower_engine_missing"
		}
	if not gs.willpower_engine.has_method("try_reject_duel_outcome"):
		return {
			"triggered": false,
			"reason": "willpower_method_missing"
		}

	var clean_scope: String = str(duel_scope).strip_edges().to_lower()
	var clean_side: String = str(side).strip_edges().to_lower()
	var time_loop_state: Dictionary = _rf_duel_dict(duel.get("time_loop_state", {}))
	var hp_key: String = "player_hp"
	var hp_max_key: String = "player_hp_max"

	if clean_scope == "reality_fusion_ally":
		if clean_side != "player":
			return {
				"triggered": false,
				"reason": "reality_fusion_enemy_is_snapshot_not_person"
			}
	else:
		if clean_side == "target":
			hp_key = "target_hp"
			hp_max_key = "target_hp_max"

	var report: Dictionary = gs.willpower_engine.try_reject_duel_outcome(defeated, duel, {
		"source": "scenario_engine_duel_outcome_resistance",
		"duel_scope": clean_scope,
		"side": clean_side,
		"hp_key": hp_key,
		"hp_max_key": hp_max_key,
		"opponent_id": int(opponent.id) if opponent != null else -1,
		"loop_count": int(time_loop_state.get("loop_count", 0)),
		"force": bool(duel.get("force_willpower_last_stand", false))
	})

	if not bool(report.get("triggered", false)):
		return report

	duel [hp_key] = max(1, int(report.get("restored_hp", 1)))
	duel ["phase"] = "player_action"
	duel ["pending_enemy_move"] = {}
	duel ["pending_player_attack"] = {}
	duel ["pending_player_guard"] = 0
	duel ["last_response_text"] = str(report.get("line", "%s refused to stay down." % _person_label_for_world_feed(defeated)))
	duel ["willpower_last_stand_report"] = report.duplicate(true)
	duel ["willpower_last_stand_side"] = clean_side
	duel ["willpower_last_stand_scope"] = clean_scope

	var restored_hp: int = max(1, int(report.get("restored_hp", 1)))
	var boost_amount: int = clamp(5 + int(float(restored_hp) * 0.18), 5, 32)
	var boost_turns: int = 2

	if clean_side == "player":
		duel ["player_willpower_attack_boost"] = boost_amount
		duel ["player_willpower_attack_boost_turns"] = boost_turns
		duel ["player_willpower_last_stand_active"] = true
		duel ["player_position"] = "standing through pure willpower"
	else:
		duel ["target_willpower_attack_boost"] = boost_amount
		duel ["target_willpower_attack_boost_turns"] = boost_turns
		duel ["target_willpower_last_stand_active"] = true
		duel ["target_position"] = "standing through pure willpower"

	return report
func _bending_duel_player_last_stand_choice_available(actor: Person, duel: Dictionary) -> bool:
	if actor == null or gs == null:
		return false
	if bool(duel.get("skip_player_willpower_last_stand", false)):
		return false
	if bool(duel.get("player_willpower_last_stand_active", false)):
		return false
	if bool(duel.get("player_willpower_last_stand_declined", false)):
		return false
	if not ("willpower_engine" in gs) or gs.willpower_engine == null:
		return false

	var willpower_score: float = 0.0
	if gs.willpower_engine.has_method("score"):
		willpower_score = float(gs.willpower_engine.score(actor, {
			"source": "bending_duel_player_last_stand_choice_available",
			"duel_scope": "bending"
		}))
	elif gs.willpower_engine.has_method("ensure_willpower"):
		var profile: Dictionary = gs.willpower_engine.ensure_willpower(actor, {
			"source": "bending_duel_player_last_stand_choice_available",
			"duel_scope": "bending"
		})
		willpower_score = float(profile.get("core_score", actor.willpower))
	else:
		willpower_score = float(actor.willpower)

	return willpower_score >= 74.0


func _queue_bending_duel_player_last_stand_choice(actor: Person, target: Person, duel: Dictionary) -> Dictionary:
	if actor == null or target == null:
		return {}

	duel ["pending_player_willpower_last_stand"] = true
	duel ["phase"] = "player_willpower_last_stand_choice"
	duel ["player_hp"] = 0
	duel ["last_response_text"] = "You hit the floor.\n\nYour body wants the fight to end.\n\nSomething deeper refuses to agree."
	gs.scenario_state ["bending_scenario_duel"] = duel

	return queue_external_scenario({
		"id": "bending_player_willpower_last_stand_%d_%d" % [int(gs.year), int(Time.get_ticks_msec())],
		"source": "scenario_engine",
		"category": "bending",
		"cooldown_key": "bending_player_willpower_last_stand",
		"resolver_method": "_resolve_bending_duel_choice",
		"panel_title": "BENDING DUEL — WILLPOWER CHECK",
		"footer_text": "High willpower can reject the end, but standing back up costs something.",
		"prompt": "You hit the floor.\n\n...\n\n\"...no.\"\n\nYou can feel yourself trying to stand back up.\n\nDo you force your body back into the fight?",
		"combat_ui": _bending_duel_combat_ui_with_values(actor, duel, 0, int(duel.get("target_hp", 1)), "Defeat is trying to finalize"),
		"choices": [
			{
				"id": "bending_willpower_stand_back_up",
				"label": "Stand back up",
				"journal_text": "I refused to stay down in the bending duel.",
				"button_theme": "bending_ability",
				"power_source": "willpower",
				"choice_family": "willpower_last_stand",
				"bending_duel_target_id": int(target.id)
			},
			{
				"id": "bending_willpower_accept_defeat",
				"label": "Let the fight end",
				"journal_text": "I let the bending duel end.",
				"button_theme": "defensive_escape",
				"power_source": "survival",
				"choice_family": "accept_defeat",
				"bending_duel_target_id": int(target.id)
			}
		]
	})


func _resolve_bending_duel_player_last_stand_choice(actor: Person, scenario: Dictionary, _choice: Dictionary, stand_back_up: bool) -> Dictionary:
	var duel: Dictionary = _rf_duel_dict(gs.scenario_state.get("bending_scenario_duel", {}))
	if duel.is_empty() or not bool(duel.get("active", false)):
		return {
			"type": "scenario_commit_complete",
			"text": "The bending duel ended before your willpower could answer.",
			"popup_title": "Bending Duel",
			"popup_text": "The duel state was gone.",
			"popup_footer": "Tap anywhere to continue.",
			"opps": []
		}

	var target: Person = _scenario_person_by_id(int(duel.get("target_id", scenario.get("target_id", -1))))
	if target == null:
		duel ["active"] = false
		gs.scenario_state ["bending_scenario_duel"] = duel
		return {
			"type": "scenario_commit_complete",
			"text": "The bending duel ended because the opponent was gone.",
			"popup_title": "Bending Duel Ended",
			"popup_text": "Your opponent is no longer available.",
			"popup_footer": "Tap anywhere to continue.",
			"opps": []
		}

	duel ["pending_player_willpower_last_stand"] = false

	if not stand_back_up:
		duel ["player_willpower_last_stand_declined"] = true
		duel ["skip_player_willpower_last_stand"] = true
		gs.scenario_state ["bending_scenario_duel"] = duel
		return _finish_bending_duel_loss(actor, target, duel)

	duel ["force_willpower_last_stand"] = true
	var willpower_report: Dictionary = _duel_apply_willpower_outcome_resistance(actor, target, duel, "bending", "player")
	duel ["force_willpower_last_stand"] = false

	if not bool(willpower_report.get("triggered", false)):
		duel ["skip_player_willpower_last_stand"] = true
		gs.scenario_state ["bending_scenario_duel"] = duel
		return _finish_bending_duel_loss(actor, target, duel)

	duel ["target_inflicted_knockout"] = false
	duel ["player_hp"] = int(willpower_report.get("restored_hp", max(1, int(float(int(duel.get("player_hp_max", 1))) / 3.0))))
	duel ["phase"] = "player_action"
	duel ["pending_enemy_move"] = {}
	duel ["pending_player_attack"] = {}
	duel ["pending_player_guard"] = 0
	duel ["target_position"] = "bracing to defend your comeback"
	duel ["last_response_text"] = "You stood back up.\n\nYour health surged back into the bar like your body rejected the ending.\n\n%s braces to defend.\n\nYou get the first move." % str(duel.get("target_name", "Your opponent"))
	gs.scenario_state ["bending_scenario_duel"] = duel

	return _queue_bending_duel_willpower_last_stand_sequence(actor, target, duel, willpower_report, "player", str(duel.get("last_response_text", "")))


func _queue_bending_duel_target_last_stand_response(actor: Person, target: Person, duel: Dictionary, willpower_report: Dictionary) -> Dictionary:
	if actor == null or target == null:
		return {}

	duel ["player_inflicted_knockout"] = false
	duel ["target_hp"] = int(willpower_report.get("restored_hp", max(1, int(float(int(duel.get("target_hp_max", 1))) / 3.0))))

	var enemy_move: Dictionary = _bending_duel_enemy_move_packet(target, duel, "willpower_last_stand", 0)
	duel ["pending_enemy_move"] = enemy_move.duplicate(true)
	duel ["last_enemy_move"] = enemy_move.duplicate(true)
	duel ["pending_player_attack"] = {}
	duel ["pending_player_guard"] = 0
	duel ["phase"] = "defense_response"
	duel ["target_position"] = "standing through pure willpower and launching %s" % str(enemy_move.get("name", "a bending counter"))
	duel ["last_response_text"] = "%s stood back up.\n\nTheir health surged back into the bar.\n\nThen they launched %s.\n\nChoose how you answer it." % [
		str(duel.get("target_name", "Your opponent")),
		str(enemy_move.get("name", "a bending counter"))
	]
	gs.scenario_state ["bending_scenario_duel"] = duel

	return _queue_bending_duel_willpower_last_stand_sequence(actor, target, duel, willpower_report, "target", str(duel.get("last_response_text", "")))


func _queue_bending_duel_willpower_last_stand_sequence(actor: Person, target: Person, duel: Dictionary, willpower_report: Dictionary, side: String, final_text: String) -> Dictionary:
	gs.scenario_state ["bending_scenario_duel"] = duel

	var round_result: Dictionary = _queue_bending_duel_round(actor, final_text)
	var frames: Array = _bending_duel_willpower_last_stand_frames(actor, target, duel, willpower_report, side, final_text)

	if not frames.is_empty():
		var last_index: int = frames.size() - 1
		var final_frame: Dictionary = frames [last_index]
		final_frame ["opps"] = _rf_duel_array(round_result.get("opps", []))
		frames [last_index] = final_frame

		round_result ["spectator_frames"] = frames
		round_result ["spectator_final_interactive"] = true
		round_result ["spectator_frame_seconds"] = 0.34

	return round_result


func _bending_duel_willpower_last_stand_frames(actor: Person, _target: Person, duel: Dictionary, willpower_report: Dictionary, side: String, final_text: String) -> Array:
	var frames: Array = []
	var clean_side: String = str(side).strip_edges().to_lower()
	var target_name: String = str(duel.get("target_name", "Your opponent"))
	var _actor_name: String = _person_label_for_world_feed(actor)
	var restored_hp: int = max(1, int(willpower_report.get("restored_hp", 1)))

	var player_hp: int = int(duel.get("player_hp", 1))
	var target_hp: int = int(duel.get("target_hp", 1))
	var _player_hp_max: int = max(1, int(duel.get("player_hp_max", 1)))
	var _target_hp_max: int = max(1, int(duel.get("target_hp_max", 1)))

	var refill_steps: int = 5
	for i in range(refill_steps):
		var ratio: float = float(i) / float(max(1, refill_steps - 1))
		var refill_value: int = int(round(float(restored_hp) * ratio))
		if i > 0:
			refill_value = max(1, refill_value)

		var visual_player_hp: int = player_hp
		var visual_target_hp: int = target_hp
		var status_text: String = "Willpower refusing the result"
		var frame_text: String = ""

		if clean_side == "player":
			visual_player_hp = refill_value
			if i == 0:
				frame_text = "You hit the floor."
				status_text = "The fight tries to end"
			elif i == 1:
				frame_text = "...\n\n\"...no.\""
				status_text = "Willpower spike detected"
			elif i < refill_steps - 1:
				frame_text = "You stood back up.\n\nYour health bar started climbing."
				status_text = "Health refilling through willpower"
			else:
				frame_text = final_text
				status_text = "You get the first move"
		else:
			visual_target_hp = refill_value
			if i == 0:
				frame_text = "%s hit the floor." % target_name
				status_text = "The fight tries to end"
			elif i == 1:
				frame_text = "...\n\n\"...no.\""
				status_text = "Enemy willpower spike detected"
			elif i < refill_steps - 1:
				frame_text = "%s stood back up.\n\nTheir health bar started climbing." % target_name
				status_text = "Enemy health refilling through willpower"
			else:
				frame_text = final_text
				status_text = "Incoming attack — choose your response"

		frames.append({
			"panel_title": "BENDING DUEL — WILLPOWER SURGE",
			"text": frame_text,
			"footer_text": "The exchange is locked while the last stand resolves.",
			"combat_ui": _bending_duel_combat_ui_with_values(actor, duel, visual_player_hp, visual_target_hp, status_text),
			"opps": []
		})

	return frames


func _bending_duel_combat_ui_with_values(actor: Person, duel: Dictionary, player_hp: int, target_hp: int, status_text: String = "") -> Dictionary:
	var visual_duel: Dictionary = duel.duplicate(true)
	visual_duel ["player_hp"] = clamp(player_hp, 0, max(1, int(visual_duel.get("player_hp_max", 1))))
	visual_duel ["target_hp"] = clamp(target_hp, 0, max(1, int(visual_duel.get("target_hp_max", 1))))

	var combat_ui: Dictionary = _build_bending_duel_combat_ui(actor, visual_duel)
	if status_text.strip_edges() != "":
		combat_ui ["status_text"] = status_text

	combat_ui ["impact_shake"] = true
	combat_ui ["impact_shake_amount"] = max(10.0, float(combat_ui.get("impact_shake_amount", 0.0)))
	combat_ui ["willpower_last_stand"] = true
	return combat_ui
func _duel_apply_time_loop_bargain(actor: Person, target: Person, duel: Dictionary, duel_scope: String, _choice: Dictionary = {}) -> Dictionary:
	if typeof(duel) != TYPE_DICTIONARY:
		return duel

	var state: Dictionary = _duel_normalize_time_loop_state(duel, actor, target, duel_scope)
	var loop_count: int = int(state.get("loop_count", 0)) + 1
	var archetype: String = str(state.get("opponent_archetype", "regular")).strip_edges().to_lower()

	var player_gain: int = _duel_time_loop_player_prediction_gain(actor, loop_count, archetype)
	var opponent_gain: int = _duel_time_loop_opponent_adaptation_gain(target, duel, loop_count, archetype)
	var strain_gain: int = _duel_time_loop_opponent_strain_gain(loop_count, archetype)
	var confusion_gain: int = _duel_time_loop_opponent_confusion_gain(loop_count, archetype)

	state ["active"] = true
	state ["loop_count"] = loop_count
	state ["player_prediction"] = clamp(int(state.get("player_prediction", 0)) + player_gain, 0, 999)
	state ["player_adaptation"] = clamp(int(state.get("player_adaptation", 0)) + max(1, int(float(player_gain) * 0.45)), 0, 999)
	state ["opponent_adaptation"] = clamp(int(state.get("opponent_adaptation", 0)) + opponent_gain, 0, 999)
	state ["opponent_prediction"] = clamp(int(state.get("opponent_prediction", 0)) + max(0, int(float(opponent_gain) * 0.55)), 0, 999)
	state ["opponent_strain"] = clamp(int(state.get("opponent_strain", 0)) + strain_gain, 0, 999)
	state ["opponent_confusion"] = clamp(int(state.get("opponent_confusion", 0)) + confusion_gain, 0, 999)
	state ["last_loop_year"] = int(gs.year) if gs != null else 0
	state ["last_loop_ms"] = int(Time.get_ticks_msec())

	var dialogue: String = _duel_time_loop_dialogue(actor, target, duel, state, duel_scope)
	state ["last_dialogue"] = dialogue

	var history: Array = state.get("dialogue_history", []) if typeof(state.get("dialogue_history", [])) == TYPE_ARRAY else []
	history.append({
		"round": int(duel.get("round", 1)),
		"loop_count": loop_count,
		"dialogue": dialogue,
		"player_prediction": int(state.get("player_prediction", 0)),
		"opponent_adaptation": int(state.get("opponent_adaptation", 0)),
		"opponent_strain": int(state.get("opponent_strain", 0)),
		"opponent_confusion": int(state.get("opponent_confusion", 0)),
		"archetype": archetype
	})
	while history.size() > 16:
		history.pop_front()

	state ["dialogue_history"] = history
	duel ["time_loop_state"] = state

	duel = _duel_apply_time_loop_combat_pressure(actor, target, duel, state, duel_scope)
	duel ["last_response_text"] = _duel_time_loop_preface(duel)
	duel ["phase"] = "player_action"
	duel ["pending_enemy_move"] = {}
	duel ["pending_player_attack"] = {}
	duel ["pending_player_guard"] = 0

	_duel_remember_time_loop(actor, target, state, duel_scope)

	return duel


func _duel_apply_time_loop_combat_pressure(_actor: Person, _target: Person, duel: Dictionary, state: Dictionary, duel_scope: String) -> Dictionary:
	var archetype: String = str(state.get("opponent_archetype", "regular")).strip_edges().to_lower()
	var loop_count: int = int(state.get("loop_count", 1))
	var player_prediction: int = int(state.get("player_prediction", 0))
	var opponent_adaptation: int = int(state.get("opponent_adaptation", 0))
	var strain: int = int(state.get("opponent_strain", 0))
	var confusion: int = int(state.get("opponent_confusion", 0))
	var net_prediction: int = player_prediction + confusion - opponent_adaptation

	match str(duel_scope).strip_edges().to_lower():
		"reality_fusion_ally":
			var enemy_hp: int = int(duel.get("enemy_hp", 1))
			var player_hp: int = int(duel.get("player_hp", 1))
			var enemy_power: int = int(duel.get("enemy_power", 0))

			if archetype == "elite_legend":
				if loop_count <= 3 or net_prediction >= 8:
					var chip: int = max(1, int(float(net_prediction + strain) * 0.16))
					enemy_hp = max(0, enemy_hp - chip)
					duel ["enemy_position"] = "studying the loop instead of merely reacting"
				else:
					var backlash: int = max(1, int(float(opponent_adaptation - player_prediction) * 0.12))
					player_hp = max(0, player_hp - backlash)
					duel ["enemy_position"] = "adapting inside your reset"
			else:
				var loop_damage: int = max(2, int(float(player_prediction + strain + confusion) * 0.18))
				if archetype == "cosmic_overwhelming_power":
					loop_damage += max(2, int(float(enemy_power) * 0.025))
				enemy_hp = max(0, enemy_hp - loop_damage)
				duel ["enemy_position"] = "caught in the shape of your repeated timeline"

			duel ["player_hp"] = player_hp
			duel ["enemy_hp"] = enemy_hp
			duel ["total_damage_to_enemy"] = int(duel.get("total_damage_to_enemy", 0)) + max(0, int(duel.get("enemy_hp", enemy_hp)) - enemy_hp)
			duel ["last_shake_amount"] = clamp(6.0 + float(loop_count) * 1.5, 6.0, 22.0)

		_:
			var target_hp: int = int(duel.get("target_hp", 1))
			var player_hp_bending: int = int(duel.get("player_hp", 1))
			var player_read: int = int(duel.get("player_read", duel.get("read_bonus", 0)))
			var target_read: int = int(duel.get("target_read", 0))
			var target_power: int = int(duel.get("target_power", 0))

			if archetype == "elite_legend":
				if loop_count <= 3 or net_prediction >= 8:
					var clean_read_gain: int = clamp(3 + int(float(player_prediction) * 0.08), 2, 12)
					player_read += clean_read_gain
					var clean_chip: int = max(1, int(float(net_prediction + strain) * 0.12))
					target_hp = max(0, target_hp - clean_chip)
					duel ["target_position"] = "realizing your stance has already seen this exchange"
				else:
					var adapted_backlash: int = max(1, int(float(opponent_adaptation - player_prediction) * 0.1))
					player_hp_bending = max(0, player_hp_bending - adapted_backlash)
					target_read += clamp(2 + int(float(opponent_adaptation) * 0.06), 2, 14)
					duel ["target_position"] = "reading the loop with you"
			else:
				var bending_loop_damage: int = max(2, int(float(player_prediction + strain + confusion) * 0.14))
				if archetype == "cosmic_overwhelming_power":
					bending_loop_damage += max(2, int(float(target_power) * 0.018))
				target_hp = max(0, target_hp - bending_loop_damage)
				player_read += clamp(2 + int(float(player_prediction) * 0.07), 2, 14)
				target_read = max(0, target_read - clamp(1 + int(float(confusion) * 0.04), 1, 10))
				duel ["target_position"] = "fighting an exchange you keep remembering first"

			duel ["player_hp"] = player_hp_bending
			duel ["target_hp"] = target_hp
			duel ["player_read"] = clamp(player_read, 0, 99)
			duel ["target_read"] = clamp(target_read, 0, 99)
			duel ["read_bonus"] = clamp(int(duel.get("read_bonus", 0)) + 2, 0, 18)

	return duel

func _duel_time_loop_player_prediction_gain(actor: Person, loop_count: int, archetype: String) -> int:
	var base: int = 6 + int(float(loop_count) * 1.25)
	if actor != null:
		base += int(_duel_person_stat_score(actor, "smarts", 50.0) * 0.035)
		base += int(_duel_person_stat_score(actor, "mental_health", 50.0) * 0.018)
		base += int(_duel_person_stat_score(actor, "discipline", 50.0) * 0.018)
		base += int(_duel_person_stat_score(actor, "willpower", 50.0) * 0.015)
	if archetype == "cosmic_overwhelming_power":
		base += 3
	elif archetype == "elite_legend":
		base += 2 if loop_count <= 3 else 0
	else:
		base += 4
	return clamp(base, 3, 28)
func _duel_person_stat_score(actor: Person, stat_name: String, fallback: float = 0.0) -> float:
	if actor == null:
		return fallback

	var clean_stat: String = str(stat_name).strip_edges()
	if clean_stat == "":
		return fallback

	if clean_stat in actor:
		return float(actor.get(clean_stat))

	if clean_stat == "willpower":
		if gs != null and "willpower_engine" in gs and gs.willpower_engine != null and gs.willpower_engine.has_method("score"):
			return float(gs.willpower_engine.score(actor, {
				"source": "scenario_engine_stat_score",
				"duel_scope": "time_loop"
			}))
		if "willpower_profile" in actor:
			var profile: Dictionary = _rf_duel_dict(actor.willpower_profile)
			if profile.has("core_score"):
				return float(profile.get("core_score", fallback))

	if clean_stat == "discipline":
		var consciousness: Dictionary = _rf_duel_dict(actor.consciousness_contract)
		var behavioral: Dictionary = _rf_duel_dict(consciousness.get("behavioral_patterns", {}))
		if behavioral.has("discipline"):
			var discipline_value: float = float(behavioral.get("discipline", 0.5))
			if discipline_value <= 1.5:
				return clamp(discipline_value * 100.0, 0.0, 150.0)
			return clamp(discipline_value, 0.0, 150.0)

	return fallback

func _duel_time_loop_opponent_adaptation_gain(target: Person, duel: Dictionary, loop_count: int, archetype: String) -> int:
	if archetype == "regular":
		return clamp(1 + int(float(loop_count) * 0.2), 1, 7)

	if archetype == "cosmic_overwhelming_power":
		return clamp(1 + int(float(loop_count) * 0.35), 1, 9)

	var target_level: int = 0
	if target != null:
		target_level = max(
			_bending_duel_level(target, str(duel.get("target_element", "bending"))),
			int(float(target.smarts) * 0.35)
		)
	else:
		target_level = int(duel.get("enemy_power", 0))

	return clamp(4 + int(float(target_level) * 0.045) + int(float(loop_count) * 1.35), 4, 34)


func _duel_time_loop_opponent_strain_gain(loop_count: int, archetype: String) -> int:
	if archetype == "elite_legend":
		return clamp(1 + int(float(loop_count) * 0.35), 1, 8)
	if archetype == "regular":
		return clamp(5 + int(float(loop_count) * 1.1), 5, 22)
	return clamp(7 + int(float(loop_count) * 1.55), 7, 30)


func _duel_time_loop_opponent_confusion_gain(loop_count: int, archetype: String) -> int:
	if archetype == "elite_legend":
		return clamp(1 + int(float(loop_count) * 0.25), 0, 6)
	if archetype == "cosmic_overwhelming_power":
		return clamp(4 + int(float(loop_count) * 0.85), 4, 18)
	return clamp(6 + int(float(loop_count) * 1.25), 6, 26)


func _duel_time_loop_opponent_archetype(_actor: Person, target: Person, duel_scope: String = "") -> String:
	if target == null:
		return "elite_legend" if str(duel_scope).strip_edges().to_lower() == "reality_fusion_ally" else "regular"

	var traits: Array = _rf_duel_array(target.traits)
	var trait_text_joined: String = ""
	for raw_trait in traits:
		trait_text_joined += " %s" % str(raw_trait).strip_edges().to_lower()

	var target_element: String = _bending_duel_best_element(target)
	var target_level: int = _bending_duel_level(target, target_element)
	var target_power: int = _bending_duel_power(target, target_element)
	var target_read: int = _bending_duel_read_score(target, target_element)
	var target_smarts: float = _duel_person_stat_score(target, "smarts", 50.0)
	var target_discipline: float = _duel_person_stat_score(target, "discipline", 50.0)
	var adaptation_score: int = target_level + int(target_smarts * 0.35) + int(target_discipline * 0.25) + target_read

	if trait_text_joined.find("cosmic") >= 0 or trait_text_joined.find("god") >= 0 or trait_text_joined.find("deity") >= 0 or trait_text_joined.find("titan") >= 0:
		return "cosmic_overwhelming_power"

	if trait_text_joined.find("legend") >= 0 or trait_text_joined.find("master") >= 0 or trait_text_joined.find("champion") >= 0 or trait_text_joined.find("grandfather") >= 0 or trait_text_joined.find("grandad") >= 0:
		return "elite_legend"

	if target_power >= 165 and adaptation_score < 95:
		return "cosmic_overwhelming_power"

	if target_level >= 75 or adaptation_score >= 115:
		return "elite_legend"

	return "regular"


func _duel_time_loop_target_name(target: Person, duel_scope: String = "") -> String:
	if target != null:
		var full_name: String = ("%s %s" % [target.first_name, target.last_name]).strip_edges()
		if full_name != "":
			return full_name

	if str(duel_scope).strip_edges().to_lower() == "reality_fusion_ally":
		return "Imported Ally"

	return "Opponent"


func _duel_time_loop_dialogue(_actor: Person, target: Person, duel: Dictionary, state: Dictionary, _duel_scope: String) -> String:
	var target_name: String = str(state.get("target_name", "")).strip_edges()
	if target_name == "" and target != null:
		target_name = str(target.first_name).strip_edges()
	if target_name == "":
		target_name = str(duel.get("target_name", duel.get("source_name", "Opponent"))).strip_edges()
	if target_name == "":
		target_name = "Opponent"

	var first_name: String = target_name.split(" ") [0]
	var loop_count: int = int(state.get("loop_count", 1))
	var archetype: String = str(state.get("opponent_archetype", "regular")).strip_edges().to_lower()

	var player_line: String = "%s, I've come to bargain." % first_name
	var opponent_line: String = "You've come to lose."

	if loop_count == 2:
		opponent_line = "...wait... haven't we-"
	elif loop_count == 5:
		opponent_line = "Why do you keep saying that??"
	elif loop_count == 10:
		opponent_line = "STOP RESETTING TIME."
	elif archetype == "elite_legend" and loop_count >= 4:
		opponent_line = "You've done this before... haven't you?"
	elif archetype == "regular" and loop_count >= 3:
		opponent_line = "Why does it feel like you already know what I'm doing???"
	elif archetype == "cosmic_overwhelming_power" and loop_count >= 6:
		opponent_line = "ENOUGH. I will break this little circle."
	elif archetype == "cosmic_overwhelming_power" and loop_count >= 3:
		opponent_line = "Your loop is not power. It is desperation."

	return "You: \"%s\"\n%s: \"%s\"" % [
		player_line,
		first_name,
		opponent_line
	]


func _duel_time_loop_preface(duel: Dictionary) -> String:
	var state: Dictionary = _rf_duel_dict(duel.get("time_loop_state", {}))
	if state.is_empty():
		return ""

	var loop_count: int = int(state.get("loop_count", 0))
	var dialogue: String = str(state.get("last_dialogue", "")).strip_edges()
	var archetype: String = str(state.get("opponent_archetype", "regular")).strip_edges().to_lower()

	var archetype_line: String = "The Time Stone folds the duel back into itself."
	if archetype == "cosmic_overwhelming_power":
		archetype_line = "The Time Stone traps overwhelming power inside repetition."
	elif archetype == "elite_legend":
		archetype_line = "The Time Stone gives you the first read, but their mind is starting to follow the loop."
	elif archetype == "regular":
		archetype_line = "The Time Stone turns the exchange into a nightmare they cannot explain."

	var text: String = "%s\n\nTime Loop Iteration: %d\nPlayer Prediction: %d\nOpponent Adaptation: %d\nOpponent Strain: %d\nOpponent Confusion: %d" % [
		archetype_line,
		loop_count,
		int(state.get("player_prediction", 0)),
		int(state.get("opponent_adaptation", 0)),
		int(state.get("opponent_strain", 0)),
		int(state.get("opponent_confusion", 0))
	]

	if dialogue != "":
		text += "\n\n%s" % dialogue

	return text


func _duel_remember_time_loop(actor: Person, target: Person, state: Dictionary, _duel_scope: String) -> void:
	var loop_count: int = int(state.get("loop_count", 0))
	if loop_count <= 0:
		return

	var memory_text: String = "A Time Stone duel loop reached iteration %d." % loop_count

	if actor != null:
		if actor.memories == null:
			actor.memories = []
		if not actor.memories.has(memory_text):
			actor.memories.append(memory_text)

	if target != null:
		var target_memory: String = "I felt trapped inside a repeating duel loop."
		if target.memories == null:
			target.memories = []
		if not target.memories.has(target_memory):
			target.memories.append(target_memory)
func _queue_reality_fusion_ally_duel_round(actor: Person, preface_text: String = "") -> Dictionary:
	var duel: Dictionary = _rf_duel_dict(gs.scenario_state.get("reality_fusion_ally_duel", {}))
	if duel.is_empty() or not bool(duel.get("active", false)):
		return {
			"type": "scenario_commit_complete",
			"text": "The reality duel ended before it could continue.",
			"opps": []
		}

	var lines: Array = []
	var effective_preface: String = str(preface_text).strip_edges()
	if effective_preface == "":
		effective_preface = str(duel.get("last_response_text", "")).strip_edges()

	if effective_preface != "":
		lines.append(effective_preface)

	lines.append("Round %d." % int(duel.get("round", 1)))
	lines.append("The portal shakes. Their universe is resisting yours.")

	var enemy_position: String = str(duel.get("enemy_position", "")).strip_edges()
	if enemy_position != "":
		lines.append("Their position: %s." % enemy_position)

	var last_enemy_move: Dictionary = _rf_duel_dict(duel.get("last_enemy_move", {}))
	if not last_enemy_move.is_empty():
		lines.append("Last enemy move: %s." % str(last_enemy_move.get("name", "unknown move")))
		lines.append("Damage they did to you: %d." % int(last_enemy_move.get("damage_dealt_to_player", 0)))

	return queue_external_scenario({
		"id": "reality_fusion_ally_duel_%d_%d" % [int(gs.year), int(duel.get("round", 1))],
		"source": "scenario_engine",
		"category": "social",
		"cooldown_key": "reality_fusion_ally_duel",
		"resolver_method": "_resolve_reality_fusion_ally_choice",
		"panel_title": "REALITY FUSION — DUEL",
		"footer_text": "Read their move, punish their position, or escape before the portal eats you.",
		"timeline_glitch": true,
		"combat_ui": _build_reality_fusion_ally_combat_ui(actor, duel),
		"prompt": "\n\n".join(lines),
		"choices": _build_reality_fusion_ally_duel_choices(actor, duel)
	})

func _build_reality_fusion_ally_combat_ui(actor: Person, duel: Dictionary) -> Dictionary:
	var source_name: String = str(duel.get("source_name", "Saved Character")).strip_edges()
	var enemy_position: String = str(duel.get("enemy_position", "reading your timeline")).strip_edges()
	var last_enemy_move: Dictionary = _rf_duel_dict(duel.get("last_enemy_move", {}))

	var status_text: String = "Round %d • Enemy position: %s" % [
		int(duel.get("round", 1)),
		enemy_position
	]

	var time_loop_state: Dictionary = _rf_duel_dict(duel.get("time_loop_state", {}))
	if int(time_loop_state.get("loop_count", 0)) > 0:
		status_text += " • Time Loop x%d" % int(time_loop_state.get("loop_count", 0))

	if not last_enemy_move.is_empty():
		status_text += " • Last move: %s" % str(last_enemy_move.get("name", "unknown"))

	var shake_amount: float = max(0.0, float(duel.get("last_shake_amount", 0.0)))

	return {
		"visible": true,
		"theme": "reality_fusion",
		"status_text": status_text,
		"player_label": "%s %s • Your Timeline" % [actor.first_name, actor.last_name],
		"player_value": int(duel.get("player_hp", 0)),
		"player_max": max(1, int(duel.get("player_hp_max", 1))),
		"enemy_label": "%s • Saved Identity" % source_name,
		"enemy_value": int(duel.get("enemy_hp", 0)),
		"enemy_max": max(1, int(duel.get("enemy_hp_max", 1))),
		"impact_shake": shake_amount > 0.0,
		"impact_shake_amount": shake_amount
	}


func _build_reality_fusion_ally_duel_choices(actor: Person, duel: Dictionary) -> Array:
	var out: Array = []
	var round_number: int = int(duel.get("round", 1))
	var phase: String = str(duel.get("phase", "player_action")).strip_edges().to_lower()

	if phase == "defense_response":
		out.append({
			"id": "reality_fusion_response_defend_%d" % round_number,
			"label": "Defend Against Their Attack",
			"journal_text": "I defended against my saved character's incoming attack.",
			"reality_fusion_ally_duel_choice": true,
			"choice_family": "response_defend",
			"power_source": "defense",
			"disabled": false
		})

		out.append({
			"id": "reality_fusion_response_counter_%d" % round_number,
			"label": "Counter With Your Own Attack",
			"journal_text": "I countered my saved character's attack during Reality Fusion.",
			"reality_fusion_ally_duel_choice": true,
			"choice_family": "response_counter",
			"power_source": "counter",
			"disabled": false
		})

		for action in _reality_fusion_player_power_actions(actor):
			if typeof(action) != TYPE_DICTIONARY:
				continue
			var action_payload: Dictionary = action.duplicate(true)
			action_payload ["reality_fusion_ally_duel_choice"] = true
			action_payload ["id"] = str(action_payload.get("id", "reality_fusion_response_power_%d" % round_number))
			var original_family: String = str(action_payload.get("choice_family", "attack")).strip_edges().to_lower()
			action_payload ["choice_family"] = "response_defend" if original_family == "defend" else "response_counter"
			action_payload ["label"] = "Respond: %s" % str(action_payload.get("label", "Power"))
			action_payload ["disabled"] = bool(action_payload.get("disabled", false))
			out.append(action_payload)

		out.append({
			"id": "reality_fusion_response_escape_%d" % round_number,
			"label": "Try to Escape the Portal Clash",
			"journal_text": "I tried to escape the incoming Reality Fusion attack.",
			"reality_fusion_ally_duel_choice": true,
			"choice_family": "response_escape",
			"power_source": "survival",
			"disabled": false
		})

		return out

	out.append({
		"id": "reality_fusion_physical_attack_%d" % round_number,
		"label": "Attack with your own force",
		"journal_text": "I attacked my saved character directly during a Reality Fusion duel.",
		"reality_fusion_ally_duel_choice": true,
		"choice_family": "attack",
		"power_source": "physical",
		"disabled": false
	})

	for action in _reality_fusion_player_power_actions(actor):
		if typeof(action) != TYPE_DICTIONARY:
			continue
		var action_payload: Dictionary = action.duplicate(true)
		action_payload ["reality_fusion_ally_duel_choice"] = true
		action_payload ["id"] = str(action_payload.get("id", "reality_fusion_power_action_%d" % round_number))
		action_payload ["disabled"] = bool(action_payload.get("disabled", false))
		out.append(action_payload)



	out.append({
		"id": "reality_fusion_defend_%d" % round_number,
		"label": "Defend and read their rhythm",
		"journal_text": "I defended myself and studied their rhythm in the Reality Fusion duel.",
		"reality_fusion_ally_duel_choice": true,
		"choice_family": "defend",
		"power_source": "physical",
		"disabled": false
	})

	out.append({
		"id": "reality_fusion_escape_%d" % round_number,
		"label": "Try to escape",
		"journal_text": "I tried to escape the Reality Fusion duel.",
		"reality_fusion_ally_duel_choice": true,
		"choice_family": "escape",
		"power_source": "survival",
		"disabled": false
	})

	return out

func _resolve_reality_fusion_ally_duel_turn(actor: Person, choice: Dictionary) -> Dictionary:
	var duel: Dictionary = _rf_duel_dict(gs.scenario_state.get("reality_fusion_ally_duel", {}))
	if duel.is_empty() or not bool(duel.get("active", false)):
		return {
			"type": "scenario_commit_complete",
			"text": "The Reality Fusion duel has already ended.",
			"opps": []
		}

	var source_player: Dictionary = _rf_duel_dict(duel.get("source_player", {}))
	var source_name: String = _reality_fusion_ally_source_name(source_player)
	var choice_family: String = str(choice.get("choice_family", "attack")).strip_edges().to_lower()
	var power_source: String = str(choice.get("power_source", "physical")).strip_edges().to_lower()
	var round_number: int = int(duel.get("round", 1))
	var player_hp: int = int(duel.get("player_hp", 1))
	var enemy_hp: int = int(duel.get("enemy_hp", 1))
	var phase: String = str(duel.get("phase", "player_action")).strip_edges().to_lower()
	if phase == "defense_response":
		return _resolve_reality_fusion_ally_duel_response_turn(actor, duel, choice)
	if bool(choice.get("time_loop_duel_choice", false)) or choice_family == "time_loop" or str(choice.get("id", "")) == "time_loop_bargain":
		duel = _duel_apply_time_loop_bargain(actor, null, duel, "reality_fusion_ally", choice)
		gs.scenario_state ["reality_fusion_ally_duel"] = duel
		return _queue_reality_fusion_ally_duel_round(actor, _duel_time_loop_preface(duel))

	var player_damage: int = 0
	var guard: int = 0
	var escaped: bool = false

	match choice_family:
		"attack":
			player_damage = _reality_fusion_player_action_power(actor, choice)
		"defend":
			guard = _reality_fusion_player_guard_power(actor, choice)
		"escape":
			var escape_chance: float = clamp(0.2 + (float(actor.smarts) / 260.0) + (float(actor.health) / 420.0), 0.12, 0.72)
			escaped = randf() < escape_chance
			guard = randi_range(4, 12)
		_:
			player_damage = _reality_fusion_player_action_power(actor, choice)

	if escaped:
		duel ["active"] = false
		duel ["escaped_round"] = round_number
		gs.scenario_state ["reality_fusion_ally_duel"] = duel

		var injury_report: Dictionary = _apply_reality_fusion_duel_injury(actor, duel, "escaped")
		var diary_escape_text: String = "I narrowly escaped the Reality Fusion duel with %s in round %d. %s" % [
			source_name,
			round_number,
			str(injury_report.get("diary_suffix", "")).strip_edges()
		]

		_commit_reality_fusion_duel_aftermath(
			actor,
			diary_escape_text,
			"%s narrowly escaped a Reality Fusion duel with %s." % [_person_label_for_world_feed(actor), source_name],
			"reality_fusion_ally_duel_escape"
		)

		return {
			"type": "scenario_commit_complete",
			"text": diary_escape_text,
			"popup_title": "Narrow Escape",
			"popup_text": "You tear yourself out of the portal before %s can finish you.\n\n%s" % [
				source_name,
				str(injury_report.get("popup_text", "You survive, but your body remembers the duel."))
			],
			"popup_footer": "Tap anywhere to continue.",
			"injury_report": injury_report,
			"opps": []
		}

	var enemy_move: Dictionary = _reality_fusion_source_move_packet(source_player, duel, choice_family)
	var enemy_guard: int = int(enemy_move.get("guard", 0))
	var enemy_damage: int = int(enemy_move.get("damage", 0))

	var dealt: int = max(0, player_damage - enemy_guard)
	enemy_hp = max(0, enemy_hp - dealt)
	var taken: int = 0

	enemy_move ["damage_dealt_to_player"] = taken
	enemy_move ["damage_blocked_by_player"] = max(0, enemy_damage - taken)
	enemy_move ["damage_taken_from_player"] = dealt
	enemy_move ["damage_blocked_by_enemy"] = max(0, player_damage - dealt)

	var actions_taken: Array = _rf_duel_array(duel.get("actions_taken", []))
	actions_taken.append(str(choice.get("label", choice.get("id", "action"))))

	duel ["actions_taken"] = actions_taken
	duel ["player_hp"] = player_hp
	duel ["enemy_hp"] = enemy_hp
	duel ["total_damage_to_enemy"] = int(duel.get("total_damage_to_enemy", 0)) + dealt
	duel ["total_damage_to_player"] = int(duel.get("total_damage_to_player", 0)) + taken
	duel ["largest_hit_to_enemy"] = max(int(duel.get("largest_hit_to_enemy", 0)), dealt)
	duel ["largest_hit_to_player"] = max(int(duel.get("largest_hit_to_player", 0)), taken)
	duel ["last_enemy_move"] = enemy_move.duplicate(true)
	duel ["enemy_position"] = str(enemy_move.get("position_after", "watching your next move"))
	duel ["last_shake_amount"] = min(22.0, 5.0 + float(max(dealt, taken)) * 0.38)

	var response_text: String = "%s answered your %s with %s." % [
		source_name,
		power_source,
		str(enemy_move.get("name", "a counterattack"))
	]

	if dealt > 0:
		response_text += "\n\nYou dealt %d damage." % dealt
	else:
		response_text += "\n\nThey read your move and guarded the impact."

	if taken > 0:
		response_text += "\nThey used %s and hit you for %d damage." % [
			str(enemy_move.get("name", "their counter")),
			taken
		]
	else:
		response_text += "\nTheir %s failed to break through." % str(enemy_move.get("name", "counter"))

	response_text += "\n\nTheir position now: %s." % str(duel.get("enemy_position", "resetting their stance"))
	duel ["phase"] = "defense_response"
	duel ["pending_enemy_move"] = enemy_move.duplicate(true)
	duel ["pending_player_guard"] = guard
	response_text += "\n\n%s is about to punish the opening. Choose your response." % source_name
	duel ["last_response_text"] = response_text

	if enemy_hp <= 0:
		gs.scenario_state ["reality_fusion_ally_duel"] = duel
		return _resolve_reality_fusion_ally_duel_victory(actor, duel)

	if player_hp <= 0:
		gs.scenario_state ["reality_fusion_ally_duel"] = duel
		return _resolve_reality_fusion_ally_duel_loss(actor, duel)

	duel ["round"] = round_number + 1
	gs.scenario_state ["reality_fusion_ally_duel"] = duel
	return _queue_reality_fusion_ally_duel_round(actor, response_text)
func _resolve_reality_fusion_ally_duel_response_turn(actor: Person, duel: Dictionary, choice: Dictionary) -> Dictionary:
	var source_player: Dictionary = _rf_duel_dict(duel.get("source_player", {}))
	var source_name: String = _reality_fusion_ally_source_name(source_player)
	var choice_family: String = str(choice.get("choice_family", "response_defend")).strip_edges().to_lower()
	var enemy_move: Dictionary = _rf_duel_dict(duel.get("pending_enemy_move", {}))
	if enemy_move.is_empty():
		duel ["phase"] = "player_action"
		gs.scenario_state ["reality_fusion_ally_duel"] = duel
		return _queue_reality_fusion_ally_duel_round(actor, "The portal clash reset before the attack landed.")

	var player_hp: int = int(duel.get("player_hp", 1))
	var enemy_hp: int = int(duel.get("enemy_hp", 1))
	var enemy_damage: int = int(enemy_move.get("damage", 0))
	var guard: int = int(duel.get("pending_player_guard", 0))
	var counter_damage: int = 0
	var escaped: bool = false

	match choice_family:
		"response_defend":
			guard += _reality_fusion_player_guard_power(actor, choice)
		"response_counter":
			counter_damage = int(round(float(_reality_fusion_player_action_power(actor, choice)) * 0.7))
			guard += int(round(float(_reality_fusion_player_guard_power(actor, choice)) * 0.3))
		"response_escape":
			var escape_chance: float = clamp(0.18 + (float(actor.smarts) / 260.0) + (float(actor.health) / 450.0), 0.1, 0.72)
			escaped = randf() < escape_chance
			guard += randi_range(4, 14)
		_:
			guard += _reality_fusion_player_guard_power(actor, choice)

	if escaped:
		enemy_damage = int(round(float(enemy_damage) * 0.35))

	var taken: int = max(0, enemy_damage - guard)
	var counter_dealt: int = 0
	if counter_damage > 0:
		counter_dealt = max(0, counter_damage - int(float(enemy_move.get("guard", 0)) * 0.45))

	player_hp = max(0, player_hp - taken)
	enemy_hp = max(0, enemy_hp - counter_dealt)

	enemy_move ["damage_dealt_to_player"] = taken
	enemy_move ["damage_blocked_by_player"] = max(0, enemy_damage - taken)
	enemy_move ["counter_damage_taken"] = counter_dealt

	duel ["player_hp"] = player_hp
	duel ["enemy_hp"] = enemy_hp
	duel ["total_damage_to_player"] = int(duel.get("total_damage_to_player", 0)) + taken
	duel ["total_damage_to_enemy"] = int(duel.get("total_damage_to_enemy", 0)) + counter_dealt
	duel ["largest_hit_to_player"] = max(int(duel.get("largest_hit_to_player", 0)), taken)
	duel ["largest_hit_to_enemy"] = max(int(duel.get("largest_hit_to_enemy", 0)), counter_dealt)
	duel ["last_enemy_move"] = enemy_move.duplicate(true)
	duel ["pending_enemy_move"] = {}
	duel ["pending_player_attack"] = {}
	duel ["pending_player_guard"] = 0
	duel ["phase"] = "player_action"
	duel ["last_shake_amount"] = min(22.0, 5.0 + float(max(taken, counter_dealt)) * 0.38)

	var response_text: String = "%s committed to %s." % [
		source_name,
		str(enemy_move.get("name", "their attack"))
	]

	if taken > 0:
		response_text += "\n\nThey hit you for %d damage." % taken
	else:
		response_text += "\n\nYou denied the hit."

	if counter_dealt > 0:
		response_text += "\nYour counter dealt %d damage." % counter_dealt

	if escaped:
		response_text += "\nYou slipped out of the worst of the portal clash."

	duel ["last_response_text"] = response_text

	if enemy_hp <= 0:
		gs.scenario_state ["reality_fusion_ally_duel"] = duel
		return _resolve_reality_fusion_ally_duel_victory(actor, duel)

	if player_hp <= 0:
		gs.scenario_state ["reality_fusion_ally_duel"] = duel
		return _resolve_reality_fusion_ally_duel_loss(actor, duel)

	duel ["round"] = int(duel.get("round", 1)) + 1
	gs.scenario_state ["reality_fusion_ally_duel"] = duel
	return _queue_reality_fusion_ally_duel_round(actor, response_text)
func _resolve_reality_fusion_ally_duel_victory(actor: Person, duel: Dictionary) -> Dictionary:
	var context: Dictionary = {
		"path": str(duel.get("path", "")),
		"label": str(duel.get("label", "")),
		"contract": _rf_duel_dict(duel.get("contract", {})),
		"source_player": _rf_duel_dict(duel.get("source_player", {}))
	}
	var source_name: String = str(duel.get("source_name", "Saved Character")).strip_edges()
	var import_report: Dictionary = _reality_fusion_import_ally_from_context(context, true)
	var imported_name: String = str(import_report.get("imported_player_name", source_name)).strip_edges()
	if imported_name == "":
		imported_name = source_name

	duel ["active"] = false
	gs.scenario_state ["reality_fusion_ally_duel"] = duel

	var health_after: int = max(1, int(duel.get("player_hp", int(actor.health))))
	actor.health = min(int(actor.health), health_after)

	if gs.has_method("push_world_feed"):
		gs.push_world_feed("%s was defeated in a Reality Fusion duel and dragged into this timeline." % imported_name, {
			"category": "reality_fusion",
			"personally_relevant": true,
			"event_name": "reality_fusion_ally_kidnapped",
			"source": "scenario_engine"
		})

	return {
		"type": "scenario_commit_complete",
		"text": "I defeated %s in a Reality Fusion duel and forced the crossover." % imported_name,
		"popup_title": "Duel Won",
		"popup_text": "Their health hit zero.\n\nThey did not die.\n\nThe portal claimed them, and %s was pulled into your universe as an ally." % imported_name,
		"popup_footer": "Tap anywhere to continue.",
		"fusion_report": import_report,
		"opps": []
	}


func _resolve_reality_fusion_ally_duel_loss(actor: Person, duel: Dictionary) -> Dictionary:
	var source_name: String = str(duel.get("source_name", "Saved Character")).strip_edges()
	if source_name == "":
		source_name = "Saved Character"

	var willpower_report: Dictionary = _duel_apply_willpower_outcome_resistance(actor, null, duel, "reality_fusion_ally", "player")
	if bool(willpower_report.get("triggered", false)):
		duel ["player_hp"] = int(willpower_report.get("restored_hp", max(1, int(float(int(duel.get("player_hp_max", 1))) / 3.0))))
		duel ["last_response_text"] = str(willpower_report.get("line", "You refused to stay down."))
		gs.scenario_state ["reality_fusion_ally_duel"] = duel
		return _queue_reality_fusion_ally_duel_round(actor, str(duel.get("last_response_text", "")))

	if _duel_time_loop_last_chance_available(actor, duel, "reality_fusion_ally"):
		return _queue_duel_time_loop_last_chance(actor, null, duel, "reality_fusion_ally", "%s broke your timeline open." % source_name)

	duel ["active"] = false
	gs.scenario_state ["reality_fusion_ally_duel"] = duel

	var kill_chance: float = clamp(
		0.42 + (float(duel.get("enemy_power", 50)) - float(duel.get("player_power", 50))) / 180.0,
		0.25,
		0.82
	)
	var killed: bool = randf() < kill_chance

	if killed:
		var light_work_line: String = "%s said it was LIGHT work" % source_name
		var cause: String = "Dueling your own saved character during Reality Fusion (%s)" % light_work_line
		actor.health = 0
		actor.alive = false
		actor.cause_of_death = cause

		var diary_text: String = "I died while dueling %s during Reality Fusion. %s." % [source_name, light_work_line]
		_commit_reality_fusion_duel_aftermath(
			actor,
			diary_text,
			"%s was killed by %s during a Reality Fusion duel. %s." % [_person_label_for_world_feed(actor), source_name, light_work_line],
			"reality_fusion_ally_duel_death"
		)

		var followup_result: Dictionary = {}
		if gs.health_engine != null and gs.health_engine.has_method("handle_death"):
			gs.health_engine.handle_death(actor, cause)
		if actor == gs.player and gs.life_engine != null and gs.life_engine.has_method("_handle_player_death"):
			followup_result = gs.life_engine.call("_handle_player_death")

		return {
			"type": "scenario_commit_complete",
			"text": diary_text,
			"popup_title": "Duel Lost",
			"popup_text": "%s did not let you crawl back through the portal.\n\nCause of death: %s." % [source_name, cause],
			"popup_footer": "Tap anywhere to continue.",
			"followup_result": followup_result,
			"opps": []
		}

	var injury_report: Dictionary = _apply_reality_fusion_duel_injury(actor, duel, "lost")
	var diary_survival_text: String = "I lost the Reality Fusion duel against %s, but I escaped with my life. %s" % [
		source_name,
		str(injury_report.get("diary_suffix", "")).strip_edges()
	]

	_commit_reality_fusion_duel_aftermath(
		actor,
		diary_survival_text,
		"%s was badly beaten by %s during a Reality Fusion duel, but survived." % [_person_label_for_world_feed(actor), source_name],
		"reality_fusion_ally_duel_survived_loss"
	)

	return {
		"type": "scenario_commit_complete",
		"text": diary_survival_text,
		"popup_title": "Barely Escaped",
		"popup_text": "%s broke your attack and nearly ended you.\n\n%s" % [
			source_name,
			str(injury_report.get("popup_text", "You fell back into your universe with almost nothing left."))
		],
		"popup_footer": "Tap anywhere to continue.",
		"injury_report": injury_report,
		"opps": []
	}
func _resolve_bending_duel_choice(actor: Person, scenario: Dictionary, choice: Dictionary, _committed: Dictionary) -> Dictionary:
	if gs == null or actor == null:
		return {}

	var choice_id: String = str(choice.get("id", "")).strip_edges()
	var target_id: int = int(choice.get("bending_duel_target_id", scenario.get("bending_duel_target_id", scenario.get("target_id", -1))))
	var target: Person = _scenario_person_by_id(target_id)

	if choice_id.begins_with("bending_mercy_") or choice_id.begins_with("bending_funeral_") or choice_id.begins_with("bending_reality_break_"):
		return _resolve_bending_duel_aftermath_choice(actor, scenario, choice)

	if choice_id == "bending_willpower_stand_back_up":
		return _resolve_bending_duel_player_last_stand_choice(actor, scenario, choice, true)

	if choice_id == "bending_willpower_accept_defeat":
		return _resolve_bending_duel_player_last_stand_choice(actor, scenario, choice, false)

	if choice_id == "bending_duel_decline" or choice_id == "withdraw":
		return {
			"type": "scenario_commit_complete",
			"text": "I decided not to begin the bending duel.",
			"popup_title": "Bending Duel Cancelled",
			"popup_text": "You let the stance dissolve before the first move.",
			"popup_footer": "Tap anywhere to continue.",
			"opps": []
		}

	if choice_id == "bending_press_trash_talk":
		if target == null:
			return {
				"type": "scenario_commit_complete",
				"text": "The press conference fell apart because the opponent was missing.",
				"popup_title": "Press Conference",
				"popup_text": "The opponent is no longer available.",
				"popup_footer": "Tap anywhere to continue.",
				"opps": []
			}

		var trash_report: Dictionary = {}
		if gs.bending_engine != null and gs.bending_engine.has_method("record_bending_trash_talk"):
			trash_report = gs.bending_engine.record_bending_trash_talk(actor, target, scenario)

		var opening: Dictionary = _begin_bending_duel_scenario(actor, target, scenario)
		opening ["popup_title"] = "Press Conference Heat"
		opening ["popup_text"] = "%s\n\nThen the officials pulled you both toward the arena." % str(trash_report.get("text", "You talked spicy before the fight."))
		return opening

	if choice_id == "bending_duel_accept" or choice_id == "begin":
		if target == null:
			return {
				"type": "scenario_commit_complete",
				"text": "The bending duel could not begin because the target was missing.",
				"popup_title": "Bending Duel",
				"popup_text": "The target is no longer available.",
				"popup_footer": "Tap anywhere to continue.",
				"opps": []
			}
		return _begin_bending_duel_scenario(actor, target, scenario)

	return _resolve_bending_duel_turn(actor, choice)

func _begin_bending_duel_scenario(actor: Person, target: Person, scenario: Dictionary) -> Dictionary:
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	if gs.bending_engine != null:
		if gs.bending_engine.has_method("ensure_bending_level_state"):
			gs.bending_engine.ensure_bending_level_state(actor)
			gs.bending_engine.ensure_bending_level_state(target)

	var duel_contract: Dictionary = _rf_duel_dict(scenario.get("bending_duel_contract", {}))
	var actor_element: String = _bending_duel_best_element(actor)
	var target_element: String = _bending_duel_best_element(target)
	var actor_power: int = _bending_duel_power(actor, actor_element)
	var target_power: int = _bending_duel_power(target, target_element)
	var actor_read: int = _bending_duel_read_score(actor, actor_element)
	var target_read: int = _bending_duel_read_score(target, target_element)

	var player_hp_max: int = max(35, int(actor.health) + int(float(actor_power) * 0.24))
	var target_hp_max: int = max(35, int(target.health) + int(float(target_power) * 0.24))

	var target_name: String = ("%s %s" % [target.first_name, target.last_name]).strip_edges()
	var mock_match_enabled: bool = bool(scenario.get("mock_match", false)) or bool(duel_contract.get("mock_match", false))
	var controlled_training_enabled: bool = bool(scenario.get("controlled_training", false)) or bool(duel_contract.get("controlled_training", false))
	var actor_archive_study: Dictionary = {}
	var target_archive_study: Dictionary = {}
	if gs.bending_engine != null and gs.bending_engine.has_method("get_bending_archival_study_report"):
		actor_archive_study = gs.bending_engine.get_bending_archival_study_report(actor, target, {
			"source": "scenario_bending_duel_actor_archive_study",
			"tournament_duel": bool(scenario.get("tournament_duel", false)),
			"tournament_id": str(scenario.get("tournament_id", "")),
			"tournament_match_id": str(scenario.get("tournament_match_id", ""))
		})
		target_archive_study = gs.bending_engine.get_bending_archival_study_report(target, actor, {
			"source": "scenario_bending_duel_target_archive_study",
			"tournament_duel": bool(scenario.get("tournament_duel", false)),
			"tournament_id": str(scenario.get("tournament_id", "")),
			"tournament_match_id": str(scenario.get("tournament_match_id", ""))
		})

	var archive_opening_line: String = ""
	if int(target_archive_study.get("bonus", 0)) > 0:
		archive_opening_line = "\n\n%s has clearly studied archived footage of your previous fights. This is not a blind opponent." % target_name
	var elemental_screen_damage_contract: Dictionary = _rf_duel_dict(duel_contract.get("elemental_screen_damage_contract", {}))
	if elemental_screen_damage_contract.is_empty():
		elemental_screen_damage_contract = _bending_elemental_screen_damage_contract()
	var duel: Dictionary = {
		"schema": "eralife.bending_duel_state",
		"version": 1,
		"active": true,
		"round": 1,
		"target_id": int(target.id),
		"target_name": target_name,
		"player_element": actor_element,
		"target_element": target_element,
		"player_power": actor_power,
		"target_power": target_power,
		"player_read": actor_read,
		"target_read": target_read,
		"player_hp": player_hp_max,
		"player_hp_max": player_hp_max,
		"target_hp": target_hp_max,
		"target_hp_max": target_hp_max,
		"target_position": _bending_duel_opening_position(target_element),
		"last_enemy_move": {},
		"last_response_text": "%s settles into a %s-bending stance and starts reading your rhythm.%s" % [target_name, target_element, archive_opening_line],
		"contract": duel_contract.duplicate(true),
		"elemental_screen_damage_contract": elemental_screen_damage_contract.duplicate(true),
		"last_screen_damage_packet": {},
		"damage_to_player": 0,
		"damage_to_target": 0,
		"read_bonus": 0,
		"phase": "player_action",
		"pending_enemy_move": {},
		"pending_player_attack": {},
		"pending_player_guard": 0,
		"player_adaptation": _bending_duel_live_adaptation_profile(actor, actor_element, {
			"side": "player",
			"mock_match": mock_match_enabled,
			"controlled_training": controlled_training_enabled,
			"archive_study": actor_archive_study.duplicate(true)
		}),
		"target_adaptation": _bending_duel_live_adaptation_profile(target, target_element, {
			"side": "target",
			"mock_match": mock_match_enabled,
			"controlled_training": controlled_training_enabled,
			"archive_study": target_archive_study.duplicate(true)
		}),
		"exchange_memory": [],
		"last_player_choice_family": "",
		"last_target_choice_family": "",
		"tournament_duel": bool(scenario.get("tournament_duel", false)),
		"tournament_id": str(scenario.get("tournament_id", "")),
		"tournament_match_id": str(scenario.get("tournament_match_id", "")),
		"tournament_division": str(scenario.get("tournament_division", "")),
		"mock_match": mock_match_enabled,
		"controlled_training": controlled_training_enabled,
		"dojo_id": str(scenario.get("dojo_id", duel_contract.get("dojo_id", ""))),
		"dojo_name": str(scenario.get("dojo_name", duel_contract.get("dojo_name", ""))),
		"world_feed_enabled": bool(duel_contract.get("world_feed_enabled", true)),
		"damage_reflects_on_stats": bool(duel_contract.get("damage_reflects_on_stats", true)),
		"skill_points_awarded": 0,
		"time_loop_state": _duel_default_time_loop_state(actor, target, "bending")
	}

	gs.scenario_state ["bending_scenario_duel"] = duel
	return _queue_bending_duel_round(actor, str(duel.get("last_response_text", "")))

func _build_bending_duel_combat_ui(actor: Person, duel: Dictionary) -> Dictionary:
	var player_element: String = str(duel.get("player_element", "bending")).strip_edges().to_lower()
	var target_element: String = str(duel.get("target_element", "bending")).strip_edges().to_lower()
	var theme_name: String = "bending_element_%s" % player_element

	if actor != null and str(actor.bending_type).strip_edges().to_lower() == "avatar":
		theme_name = "bending_avatar"
	elif player_element not in ["air", "earth", "fire", "water"]:
		theme_name = "bending_duel"

	var status_text: String = "Round %d • %s stance vs %s stance" % [
		int(duel.get("round", 1)),
		player_element,
		target_element
	]

	var time_loop_state: Dictionary = _rf_duel_dict(duel.get("time_loop_state", {}))
	if int(time_loop_state.get("loop_count", 0)) > 0:
		status_text += " • Time Loop x%d" % int(time_loop_state.get("loop_count", 0))

	var screen_damage_packet: Dictionary = _rf_duel_dict(duel.get("last_screen_damage_packet", {}))
	var screen_damage_contract: Dictionary = _rf_duel_dict(duel.get("elemental_screen_damage_contract", {}))
	if screen_damage_contract.is_empty():
		screen_damage_contract = _bending_elemental_screen_damage_contract()

	return {
		"visible": true,
		"theme": theme_name,
		"status_text": status_text,
		"player_label": "%s %s • %s bending" % [
			actor.first_name,
			actor.last_name,
			player_element.capitalize()
		],
		"player_value": int(duel.get("player_hp", 0)),
		"player_max": max(1, int(duel.get("player_hp_max", 1))),
		"enemy_label": "%s • %s bending" % [
			str(duel.get("target_name", "Opponent")),
			target_element.capitalize()
		],
		"enemy_value": int(duel.get("target_hp", 0)),
		"enemy_max": max(1, int(duel.get("target_hp_max", 1))),
		"enemy_theme": "bending_element_%s" % target_element if target_element in ["air", "earth", "fire", "water"] else "bending_duel",
		"impact_shake": true,
		"impact_shake_amount": clamp(float(max(int(duel.get("damage_to_player", 0)), int(duel.get("damage_to_target", 0)))) * 0.18, 3.0, 18.0),
		"elemental_screen_damage": screen_damage_packet.duplicate(true),
		"elemental_screen_damage_contract": screen_damage_contract.duplicate(true)
	}
func _bending_elemental_screen_damage_contract() -> Dictionary:
	return {
		"schema": "eralife.elemental_screen_damage_contract",
		"version": 1,
		"enabled": true,
		"source": "scenario_engine",
		"damage_scale": {
			"minimum_visible_damage": 1,
			"soft_hit_ratio": 0.1,
			"heavy_hit_ratio": 0.28,
			"max_intensity": 1.0
		},
		"profiles": {
			"fire": {
				"visual_id": "screen_damage.fire",
				"flash_profile": "ember_heat_flash",
				"border_profile": "scorched_edge",
				"shader_profile": "heat_distortion"
			},
			"water": {
				"visual_id": "screen_damage.water",
				"flash_profile": "cold_blue_ripple",
				"border_profile": "wet_blur_edge",
				"shader_profile": "water_refraction"
			},
			"earth": {
				"visual_id": "screen_damage.earth",
				"flash_profile": "dust_crack_flash",
				"border_profile": "stone_fracture_edge",
				"shader_profile": "screen_weight"
			},
			"air": {
				"visual_id": "screen_damage.air",
				"flash_profile": "white_pressure_burst",
				"border_profile": "wind_shear_edge",
				"shader_profile": "pressure_warp"
			},
			"avatar": {
				"visual_id": "screen_damage.avatar",
				"flash_profile": "cycling_elemental_hit",
				"border_profile": "four_element_surge_edge",
				"shader_profile": "avatar_spectrum_warp"
			}
		}
	}


func _bending_duel_screen_damage_packet(duel: Dictionary, enemy_move: Dictionary, damage_taken: int, phase: String = "enemy_attack") -> Dictionary:
	var contract: Dictionary = _rf_duel_dict(duel.get("elemental_screen_damage_contract", {}))
	if contract.is_empty():
		contract = _bending_elemental_screen_damage_contract()

	if not bool(contract.get("enabled", true)):
		return {
			"active": false,
			"reason": "disabled"
		}

	var damage_value: int = max(0, int(damage_taken))
	var minimum_damage: int = max(1, int(_rf_duel_dict(contract.get("damage_scale", {})).get("minimum_visible_damage", 1)))

	if damage_value < minimum_damage:
		return {
			"active": false,
			"reason": "no_visible_damage",
			"damage": damage_value
		}

	var element: String = str(enemy_move.get("element", duel.get("target_element", "bending"))).strip_edges().to_lower()
	if element not in ["air", "earth", "fire", "water", "avatar"]:
		element = str(duel.get("target_element", "bending")).strip_edges().to_lower()

	var profiles: Dictionary = _rf_duel_dict(contract.get("profiles", {}))
	var profile: Dictionary = _rf_duel_dict(profiles.get(element, {}))
	if profile.is_empty():
		profile = _rf_duel_dict(profiles.get("avatar", {}))

	var player_hp_max: int = max(1, int(duel.get("player_hp_max", 100)))
	var damage_ratio: float = clamp(float(damage_value) / float(player_hp_max), 0.0, 1.0)
	var max_intensity: float = float(_rf_duel_dict(contract.get("damage_scale", {})).get("max_intensity", 1.0))
	var intensity: float = clamp(0.18 + damage_ratio * 2.35, 0.18, max_intensity)

	return {
		"schema": "eralife.elemental_screen_damage_packet",
		"version": 1,
		"active": true,
		"phase": phase,
		"element": element,
		"damage": damage_value,
		"damage_ratio": damage_ratio,
		"intensity": intensity,
		"duration_ms": int(round(140.0 + 420.0 * intensity)),
		"attacker_move": str(enemy_move.get("name", "a bending attack")),
		"visual_id": str(profile.get("visual_id", "screen_damage.generic")),
		"flash_profile": str(profile.get("flash_profile", "generic_flash")),
		"border_profile": str(profile.get("border_profile", "generic_edge")),
		"shader_profile": str(profile.get("shader_profile", "generic_warp")),
		"profile": profile.duplicate(true)
	}
func _build_bending_duel_choices(actor: Person, duel: Dictionary) -> Array:
	var choices: Array = []
	var element: String = str(duel.get("player_element", "bending")).strip_edges().to_lower()
	var level: int = _bending_duel_level(actor, element)
	var phase: String = str(duel.get("phase", "player_action")).strip_edges().to_lower()

	if phase == "defense_response":
		choices.append({
			"id": "bending_duel_response_defend",
			"label": "Defend Against Their Attack",
			"journal_text": "I defended against their incoming bending attack.",
			"choice_family": "response_defend",
			"power_source": "bending",
			"button_theme": "defensive_escape",
			"bending_element": element,
			"bending_level": level
		})

		choices.append({
			"id": "bending_duel_response_counter",
			"label": "Counter With Your Own Attack",
			"journal_text": "I answered their incoming bending attack with a counterattack.",
			"choice_family": "response_counter",
			"power_source": "bending",
			"button_theme": "bending_ability",
			"bending_element": element,
			"bending_level": level
		})

		for ability_choice in _bending_duel_available_ability_choices(actor, element):
			var response_choice: Dictionary = ability_choice.duplicate(true)
			var family: String = str(response_choice.get("choice_family", "attack")).strip_edges().to_lower()
			if family in ["attack", "counter", "redirect", "parry", "counterattack"]:
				response_choice ["choice_family"] = "response_counter"
				response_choice ["label"] = "Counter: %s" % str(response_choice.get("label", "Ability"))
			elif family in ["defend", "guard", "block"]:
				response_choice ["choice_family"] = "response_defend"
				response_choice ["label"] = "Defend: %s" % str(response_choice.get("label", "Ability"))
			else:
				response_choice ["choice_family"] = "response_read"
				response_choice ["label"] = "Read: %s" % str(response_choice.get("label", "Ability"))
			choices.append(response_choice)

		for mutation_choice in _bending_duel_mutated_ability_choices(actor, true):
			choices.append(mutation_choice)

		for rf_choice in _bending_duel_reality_fusion_action_choices(actor, true):
			choices.append(rf_choice)

		choices.append({
			"id": "bending_duel_response_escape",
			"label": "Try to Slip Away",
			"journal_text": "I tried to escape the incoming bending attack.",
			"choice_family": "response_escape",
			"power_source": "survival",
			"button_theme": "defensive_escape",
			"bending_element": element,
			"bending_level": level
		})

		return choices

	choices.append({
		"id": "bending_duel_basic_attack",
		"label": "%s Strike" % element.capitalize(),
		"journal_text": "I attacked with %s bending." % element,
		"choice_family": "attack",
		"power_source": "bending",
		"button_theme": "bending_ability",
		"bending_element": element,
		"bending_level": level
	})

	for ability_choice in _bending_duel_available_ability_choices(actor, element):
		choices.append(ability_choice)

	for mutation_choice in _bending_duel_mutated_ability_choices(actor, false):
		choices.append(mutation_choice)

	for rf_attack_choice in _bending_duel_reality_fusion_action_choices(actor, false):
		choices.append(rf_attack_choice)

	choices.append({
		"id": "bending_duel_defend",
		"label": "Defensive Stance",
		"journal_text": "I defended during the bending duel.",
		"choice_family": "defend",
		"power_source": "bending",
		"button_theme": "defensive_escape",
		"bending_element": element,
		"bending_level": level
	})

	choices.append({
		"id": "bending_duel_read",
		"label": "Read Their Bending",
		"journal_text": "I studied my opponent's bending stance.",
		"choice_family": "read",
		"power_source": "knowledge",
		"button_theme": "artifact_action",
		"bending_element": element,
		"bending_level": level
	})

	choices.append({
		"id": "bending_duel_concede",
		"label": "End the Duel",
		"journal_text": "I conceded the bending duel.",
		"choice_family": "escape",
		"power_source": "survival",
		"button_theme": "defensive_escape",
		"bending_element": element,
		"bending_level": level
	})

	return choices
func _bending_duel_mutated_ability_choices(actor: Person, defensive_phase: bool = false) -> Array:
	var out: Array = []
	if gs == null or actor == null:
		return out
	if not ("power_engine" in gs) or gs.power_engine == null:
		return out
	if not gs.power_engine.has_method("get_mutated_ability_rows"):
		return out

	var rows: Array = gs.power_engine.get_mutated_ability_rows(actor, {
		"source": "bending_duel"
	})
	var count: int = 0

	for raw_row in rows:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = raw_row.duplicate(true)
		if not bool(row.get("can_use_in_bending_duels", true)):
			continue

		var family: String = str(row.get("choice_family", "attack")).strip_edges().to_lower()
		if defensive_phase:
			if family == "attack":
				family = "response_counter"
			elif family == "defend":
				family = "response_defend"
			else:
				family = "response_read"
		else:
			if family.begins_with("response_"):
				continue

		var display_name: String = str(row.get("display_name", row.get("label", "Mutated Ability"))).strip_edges()
		if display_name == "":
			display_name = "Mutated Ability"

		row ["id"] = "bending_duel_mutation_%d_%s" % [
			count,
			str(row.get("id", display_name)).to_lower().replace(" ", "_")
		]
		row ["label"] = display_name
		row ["journal_text"] = "I used %s during a bending duel." % display_name
		row ["choice_family"] = family
		row ["power_source"] = "mutated_ability"
		row ["button_theme"] = "superpower_action"
		row ["bending_duel_mutated_ability"] = true
		row ["bending_element"] = str(row.get("element", row.get("bending_element", "bending")))
		row ["bending_level"] = int(row.get("bending_level", row.get("ability_level", 0)))
		row ["disabled"] = false

		out.append(row)
		count += 1
		if count >= 8:
			break

	return out
func _bending_duel_reality_fusion_action_choices(actor: Person, defensive_phase: bool = false) -> Array:
	var out: Array = []
	if actor == null:
		return out
	if not has_method("_reality_fusion_player_power_actions"):
		return out

	var packets: Array = _reality_fusion_player_power_actions(actor)
	var count: int = 0

	for raw_packet in packets:
		if typeof(raw_packet) != TYPE_DICTIONARY:
			continue

		var packet: Dictionary = raw_packet.duplicate(true)
		var power_source: String = str(packet.get("power_source", "")).strip_edges().to_lower()
		if power_source not in ["inventory", "weapon", "artifact", "cosmic", "magic", "superpower", "bending"]:
			continue

		var family: String = str(packet.get("choice_family", "attack")).strip_edges().to_lower()
		if defensive_phase:
			if family == "attack":
				family = "response_counter"
			elif family == "defend":
				family = "response_defend"
			else:
				family = "response_read"
		else:
			if family.begins_with("response_"):
				continue

		packet ["id"] = "bending_duel_rf_%d_%s" % [
			count,
			str(packet.get("id", "power")).to_lower().replace(" ", "_")
		]
		packet ["choice_family"] = family
		packet ["bending_duel_imported_reality_fusion_action"] = true
		packet ["journal_text"] = str(packet.get("journal_text", "I used a special option during the bending duel.")).replace("Reality Fusion duel", "bending duel")
		packet ["disabled"] = bool(packet.get("disabled", false))

		out.append(packet)
		count += 1

		if count >= 6:
			break

	return out


func _bending_duel_available_ability_choices(actor: Person, fallback_element: String) -> Array:
	var out: Array = []
	if gs == null or gs.bending_engine == null:
		return out

	var clean_fallback: String = str(fallback_element).strip_edges().to_lower()
	var packets: Variant = []

	if gs.bending_engine.has_method("get_unlocked_bending_combat_abilities"):
		packets = gs.bending_engine.get_unlocked_bending_combat_abilities(actor, "", {
			"include_cooldown": false
		})
	elif gs.bending_engine.has_method("get_available_bending_abilities"):
		packets = gs.bending_engine.get_available_bending_abilities(actor)

	if typeof(packets) != TYPE_ARRAY:
		return out

	var seen_ids: Dictionary = {}
	var count: int = 0

	for raw_packet in packets:
		if typeof(raw_packet) != TYPE_DICTIONARY:
			continue

		var packet: Dictionary = raw_packet.duplicate(true)
		if not bool(packet.get("unlocked", false)):
			continue
		if bool(packet.get("on_cooldown", false)):
			continue

		var ability_name: String = str(packet.get("name", packet.get("display_name", "Bending Ability"))).strip_edges()
		if ability_name == "":
			ability_name = "Bending Ability"

		var ability_id: String = str(packet.get("id", ability_name)).strip_edges()
		if ability_id == "":
			ability_id = ability_name

		var seen_key: String = ability_id.to_lower()
		if seen_ids.has(seen_key):
			continue
		seen_ids [seen_key] = true

		var packet_element: String = str(packet.get("element", clean_fallback)).strip_edges().to_lower()
		if packet_element == "":
			packet_element = clean_fallback
		if packet_element == "":
			packet_element = "bending"

		var ability_type: String = str(packet.get("type", "attack")).strip_edges().to_lower()
		var lower_name: String = ability_name.to_lower()
		var lower_id: String = ability_id.to_lower()

		var family: String = "attack"
		if ability_type in ["defense", "guard", "block"]:
			family = "defend"
		elif ability_type in ["counter", "redirect", "parry", "counterattack"]:
			family = "counter"
		elif ability_type in ["sense", "read", "study"]:
			family = "read"

		if lower_name.find("lightning redirect") >= 0 or lower_id.find("lightning_redirect") >= 0 or lower_id.find("redirect_lightning") >= 0:
			family = "counter"
			packet_element = "fire" if packet_element == "bending" else packet_element

		out.append({
			"id": "bending_duel_ability_%d_%s" % [count, ability_id.to_lower().replace(" ", "_")],
			"label": ability_name,
			"journal_text": "I used %s in a bending duel." % ability_name,
			"choice_family": family,
			"power_source": "bending",
			"button_theme": "bending_ability",
			"ability_id": ability_id,
			"ability_name": ability_name,
			"bending_element": packet_element,
			"ability_element": packet_element,
			"bending_level": int(packet.get("current_level", packet.get("level", 0))),
			"counter_tags": ["lightning", "redirect"] if lower_name.find("lightning redirect") >= 0 or lower_id.find("lightning_redirect") >= 0 or lower_id.find("redirect_lightning") >= 0 else [],
			"can_counter_attack_elements": ["fire", "lightning"] if lower_name.find("lightning redirect") >= 0 or lower_id.find("lightning_redirect") >= 0 or lower_id.find("redirect_lightning") >= 0 else []
		})

		count += 1

	return out

func _bending_duel_unlocked_ability_from_choice(actor: Person, choice: Dictionary, fallback_element: String) -> Dictionary:
	if actor == null or gs == null or gs.bending_engine == null:
		return {}

	var ability_id: String = str(choice.get("ability_id", "")).strip_edges()
	if ability_id == "":
		return {}

	var ability: Dictionary = {}
	if gs.bending_engine.has_method("get_unlocked_bending_ability_by_id"):
		ability = gs.bending_engine.get_unlocked_bending_ability_by_id(actor, ability_id, {
			"include_cooldown": false
		})
	elif gs.bending_engine.has_method("get_bending_ability_by_id"):
		ability = gs.bending_engine.get_bending_ability_by_id(actor, ability_id)

	if ability.is_empty():
		return {}
	if not bool(ability.get("unlocked", false)):
		return {}
	if bool(ability.get("on_cooldown", false)):
		return {}

	var clean_fallback: String = str(fallback_element).strip_edges().to_lower()
	var ability_element: String = str(ability.get("element", clean_fallback)).strip_edges().to_lower()
	if clean_fallback != "" and ability_element != clean_fallback:
		return {}

	return ability.duplicate(true)

func _bending_duel_player_attack(actor: Person, duel: Dictionary, choice: Dictionary) -> int:
	return int(_bending_duel_player_attack_packet(actor, duel, choice).get("damage", 0))


func _bending_duel_player_attack_packet(actor: Person, duel: Dictionary, choice: Dictionary) -> Dictionary:
	var element: String = str(choice.get("bending_element", duel.get("player_element", "bending"))).strip_edges().to_lower()
	var level: int = max(_bending_duel_level(actor, element), int(choice.get("bending_level", 0)))
	var power: int = int(duel.get("player_power", 30))
	var ability_bonus: int = 0
	var ability: Dictionary = {}
	var ability_id: String = str(choice.get("ability_id", "")).strip_edges()
	var move_name: String = str(choice.get("ability_name", choice.get("label", ""))).strip_edges()

	var power_source: String = str(choice.get("power_source", "bending")).strip_edges().to_lower()
	if power_source in ["inventory", "weapon", "artifact", "cosmic", "magic", "superpower", "mutated_ability"]:
		var special_power: int = int(choice.get("power", randi_range(20, 42)))
		var special_label: String = str(choice.get("item_name", choice.get("weapon_name", choice.get("label", "special action")))).strip_edges()
		if special_label == "":
			special_label = "special action"

		var special_accuracy: int = clamp(48 + int(float(actor.smarts) * 0.18) + int(float(actor.mental_health) * 0.14), 8, 96)
		var special_hit: bool = (randi() % 100) < special_accuracy
		var special_damage: int = randi_range(5, 14) + special_power + int(float(power) * 0.08)

		if not special_hit:
			special_damage = int(round(float(special_damage) * 0.25))

		var special_willpower_boost: int = int(duel.get("player_willpower_attack_boost", 0))
		if special_willpower_boost > 0:
			special_damage += special_willpower_boost
			duel ["player_willpower_attack_boost_turns"] = max(0, int(duel.get("player_willpower_attack_boost_turns", 0)) - 1)
			if int(duel.get("player_willpower_attack_boost_turns", 0)) <= 0:
				duel ["player_willpower_attack_boost"] = 0

		return {
			"schema": "eralife.bending_duel_attack_packet",
			"version": 3,
			"element": element,
			"ability_id": ability_id,
			"ability_name": special_label,
			"name": special_label,
			"level": level,
			"accuracy": special_accuracy,
			"hit": special_hit,
			"damage": max(0, special_damage),
			"power_source": power_source,
			"willpower_boost_applied": special_willpower_boost > 0
		}

	if ability_id != "":
		ability = _bending_duel_unlocked_ability_from_choice(actor, choice, element)
		if ability.is_empty():
			ability_id = ""
		else:
			element = str(ability.get("element", element)).strip_edges().to_lower()
			level = max(_bending_duel_level(actor, element), int(ability.get("current_level", ability.get("level", 0))))
			if move_name == "":
				move_name = str(ability.get("name", ability.get("display_name", ""))).strip_edges()

	if ability_id != "" and not ability.is_empty():
		ability_bonus = 6 + int(float(level) * 0.24)

	if move_name == "":
		move_name = "%s Strike" % element.capitalize()

	var combat_packet: Dictionary = {}
	if gs != null and gs.bending_engine != null and gs.bending_engine.has_method("build_bending_combat_packet"):
		combat_packet = gs.bending_engine.build_bending_combat_packet(actor, ability, element)

	var accuracy: int = int(combat_packet.get("accuracy", 48 + int(float(level) * 0.38)))
	var damage: int = randi_range(8, 18) + int(float(power) * 0.22) + int(float(level) * 0.3) + ability_bonus
	damage += int(float(combat_packet.get("power", 0)) * 0.22)

	var willpower_boost: int = int(duel.get("player_willpower_attack_boost", 0))
	if willpower_boost > 0:
		damage += willpower_boost
		duel ["player_willpower_attack_boost_turns"] = max(0, int(duel.get("player_willpower_attack_boost_turns", 0)) - 1)
		if int(duel.get("player_willpower_attack_boost_turns", 0)) <= 0:
			duel ["player_willpower_attack_boost"] = 0

	var hit: bool = (randi() % 100) < clamp(accuracy, 5, 98)
	if not hit:
		damage = int(round(float(damage) * 0.22))

	return {
		"schema": "eralife.bending_duel_attack_packet",
		"version": 3,
		"element": element,
		"ability_id": ability_id,
		"ability_name": move_name,
		"name": move_name,
		"level": level,
		"accuracy": accuracy,
		"hit": hit,
		"damage": max(0, damage),
		"willpower_boost_applied": willpower_boost > 0
	}

func _bending_duel_attack_name_from_packet(packet: Dictionary, choice: Dictionary, fallback_element: String = "bending") -> String:
	var name_from_packet: String = str(packet.get("name", packet.get("ability_name", ""))).strip_edges()
	if name_from_packet != "":
		return name_from_packet

	var name_from_choice: String = str(choice.get("ability_name", choice.get("label", ""))).strip_edges()
	if name_from_choice != "":
		return name_from_choice

	var clean_element: String = str(fallback_element).strip_edges().to_lower()
	if clean_element == "":
		clean_element = "bending"

	return "%s Strike" % clean_element.capitalize()
func _bending_duel_player_guard(actor: Person, duel: Dictionary, choice: Dictionary) -> int:
	var element: String = str(choice.get("bending_element", duel.get("player_element", "bending"))).strip_edges().to_lower()
	var level: int = max(_bending_duel_level(actor, element), int(choice.get("bending_level", 0)))
	var read_score: int = int(duel.get("player_read", 20))
	var ability_id: String = str(choice.get("ability_id", "")).strip_edges()
	var ability: Dictionary = {}

	var power_source: String = str(choice.get("power_source", "bending")).strip_edges().to_lower()
	if power_source in ["inventory", "weapon", "artifact", "cosmic", "magic", "superpower", "mutated_ability"]:
		return int(choice.get("guard", randi_range(12, 34))) + int(float(read_score) * 0.16)

	if ability_id != "":
		ability = _bending_duel_unlocked_ability_from_choice(actor, choice, element)
		if ability.is_empty():
			ability_id = ""
		else:
			element = str(ability.get("element", element)).strip_edges().to_lower()
			level = max(_bending_duel_level(actor, element), int(ability.get("current_level", ability.get("level", 0))))

	var combat_packet: Dictionary = {}
	if gs != null and gs.bending_engine != null and gs.bending_engine.has_method("build_bending_combat_packet"):
		combat_packet = gs.bending_engine.build_bending_combat_packet(actor, ability, element)

	var guard_value: int = randi_range(7, 16) + int(float(level) * 0.18) + int(float(read_score) * 0.16)
	guard_value += int(float(combat_packet.get("guard", 0)) * 0.25)

	return max(0, guard_value)

func _bending_duel_enemy_move_packet(target: Person, duel: Dictionary, player_choice_family: String, player_read_bonus: int) -> Dictionary:
	var element: String = str(duel.get("target_element", _bending_duel_best_element(target))).strip_edges().to_lower()
	var level: int = _bending_duel_level(target, element)
	var target_power: int = int(duel.get("target_power", _bending_duel_power(target, element)))
	var target_read: int = int(duel.get("target_read", _bending_duel_read_score(target, element)))
	var read_advantage: int = target_read - int(duel.get("player_read", 0)) - player_read_bonus
	var target_adaptation: Dictionary = _rf_duel_dict(duel.get("target_adaptation", {}))
	var adaptation_bonus: int = int(target_adaptation.get("current_bonus", 0))
	read_advantage += adaptation_bonus
	var packet: Dictionary = _bending_duel_named_move_for_element(element, level, read_advantage)

	var combat_packet: Dictionary = {}
	if gs != null and gs.bending_engine != null and gs.bending_engine.has_method("build_bending_combat_packet"):
		combat_packet = gs.bending_engine.build_bending_combat_packet(target, {}, element)

	var accuracy: int = int(combat_packet.get("accuracy", 45 + int(float(level) * 0.35)))
	var hit: bool = (randi() % 100) < clamp(accuracy + int(float(read_advantage) * 0.2), 5, 98)

	var damage: int = randi_range(8, 18) + int(float(target_power) * 0.2) + int(float(level) * 0.26)
	damage += int(float(combat_packet.get("power", 0)) * 0.2)

	var target_willpower_boost: int = int(duel.get("target_willpower_attack_boost", 0))
	if target_willpower_boost > 0:
		damage += target_willpower_boost
		duel ["target_willpower_attack_boost_turns"] = max(0, int(duel.get("target_willpower_attack_boost_turns", 0)) - 1)
		if int(duel.get("target_willpower_attack_boost_turns", 0)) <= 0:
			duel ["target_willpower_attack_boost"] = 0
		packet ["willpower_boost_applied"] = true

	var guard: int = randi_range(4, 12) + int(float(target_read) * 0.13)
	guard += int(float(combat_packet.get("guard", 0)) * 0.22)

	if read_advantage > 0:
		damage += int(float(read_advantage) * 0.24)
		guard += int(float(read_advantage) * 0.18)

	if str(player_choice_family).strip_edges().to_lower() == "read":
		damage = int(round(float(damage) * 0.78))
	elif str(player_choice_family).strip_edges().to_lower() == "defend":
		guard += 5

	if not hit:
		damage = int(round(float(damage) * 0.25))
	damage += int(round(float(adaptation_bonus) * 0.35))
	guard += int(round(float(adaptation_bonus) * 0.55))
	packet ["adaptation_bonus"] = adaptation_bonus
	packet ["adaptation_speed"] = float(target_adaptation.get("speed", 0.0))
	packet ["damage"] = max(1, damage)
	packet ["guard"] = max(0, guard)
	packet ["accuracy"] = accuracy
	packet ["hit"] = hit
	packet ["read_advantage"] = read_advantage
	packet ["bending_level"] = level
	packet ["element"] = element
	packet ["attacker_element"] = element
	packet ["screen_damage_contract_hint"] = "eralife.elemental_screen_damage_contract"
	return packet

func _bending_duel_named_move_for_element(element: String, level: int, read_advantage: int) -> Dictionary:
	var clean_element: String = str(element).strip_edges().to_lower()
	match clean_element:
		"air":
			if read_advantage > 12:
				return {
					"name": "air-pressure feint into a backdraft kick",
					"position_after": "circling light on their feet, outside your center line"
				}
			return {
				"name": "air slice counter",
				"position_after": "floating just outside your reach"
			}
		"water":
			if level >= 70:
				return {
					"name": "water whip bind into a freezing counter",
					"position_after": "low stance with water coiled around both arms"
				}
			return {
				"name": "water whip counter",
				"position_after": "angled behind a moving water guard"
			}
		"earth":
			if read_advantage > 10:
				return {
					"name": "seismic read into stone pillar trap",
					"position_after": "rooted low with one palm on the ground"
				}
			return {
				"name": "stone wall counter",
				"position_after": "planted behind a broken slab of earth"
			}
		"fire":
			if level >= 75:
				return {
					"name": "blue-fire pressure burst",
					"position_after": "pressing forward through heat shimmer"
				}
			return {
				"name": "fire jab into spinning flame kick",
				"position_after": "forward stance with flames snapping at their heels"
			}
		_:
			return {
				"name": "mixed bending counter",
				"position_after": "reading your breathing from a guarded stance"
			}

func _bending_duel_is_mock_match(duel: Dictionary) -> bool:
	if typeof(duel) != TYPE_DICTIONARY:
		return false

	if bool(duel.get("mock_match", false)) or bool(duel.get("controlled_training", false)):
		return true

	var contract: Dictionary = _rf_duel_dict(duel.get("contract", {}))
	return bool(contract.get("mock_match", false)) or bool(contract.get("controlled_training", false))


func _finish_bending_duel_mock_match(actor: Person, target: Person, duel: Dictionary, actor_won: bool) -> Dictionary:
	duel ["active"] = false
	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["bending_scenario_duel"] = duel

	var result: Dictionary = {}
	if gs != null and "bending_dojo_engine" in gs and gs.bending_dojo_engine != null and gs.bending_dojo_engine.has_method("finalize_dojo_sparring_result"):
		result = gs.bending_dojo_engine.finalize_dojo_sparring_result(actor, target, duel, actor_won, {
			"source": "scenario_engine_mock_match"
		})

	var target_name: String = ("%s %s" % [target.first_name, target.last_name]).strip_edges()
	var outcome_text: String = "I won a dojo mock match against %s." % target_name if actor_won else "I lost a dojo mock match against %s." % target_name

	if gs != null and gs.narrative_engine != null:
		gs.narrative_engine.log_event(actor, {
			"type": "text",
			"text": outcome_text
		})

	return {
		"type": "scenario_commit_complete",
		"text": outcome_text,
		"popup_title": str(result.get("popup_title", "Dojo Mock Match Complete")),
		"popup_text": str(result.get("popup_text", "The mock match ended.")),
		"popup_footer": "Tap anywhere to continue.",
		"opps": []
	}
func _maybe_build_bending_championship_victory_result(actor: Person, target: Person, duel: Dictionary, element: String) -> Dictionary:
	if gs == null or actor == null:
		return {}

	if not bool(duel.get("tournament_duel", false)):
		return {}

	if gs.bending_engine == null:
		return {}

	if not gs.bending_engine.has_method("_bending_tournament_reload_by_id"):
		return {}

	var tournament_id: String = str(duel.get("tournament_id", "")).strip_edges()
	if tournament_id == "":
		return {}

	var tournament: Dictionary = gs.bending_engine.call("_bending_tournament_reload_by_id", tournament_id)
	if tournament.is_empty():
		return {}

	if str(tournament.get("status", "")).strip_edges().to_lower() != "complete":
		return {}

	if int(tournament.get("champion_id", -1)) != int(actor.id):
		return {}

	var tournament_label: String = str(tournament.get("label", "Bending World Championship"))
	var target_name: String = ("%s %s" % [str(target.first_name), str(target.last_name)]).strip_edges() if target != null else "your final opponent"
	var finish_move: String = str(duel.get("last_player_move_name", duel.get("last_player_move", "your final technique"))).strip_edges()
	if finish_move == "":
		finish_move = "your final technique"

	var reality_surge_report: Dictionary = {}
	var reality_surge_raw: Variant = tournament.get("reality_surge_report", {})
	if typeof(reality_surge_raw) == TYPE_DICTIONARY:
		reality_surge_report = (reality_surge_raw as Dictionary).duplicate(true)

	var diary_text: String = "I won the %s. I defeated %s with %s and became champion." % [
		tournament_label,
		target_name,
		finish_move
	]

	if gs.narrative_engine != null:
		gs.narrative_engine.log_event(actor, {
			"type": "text",
			"text": diary_text,
			"life_diary_text": diary_text,
			"third_person_text": "%s won the %s." % [_person_label_for_world_feed(actor), tournament_label],
			"source": "scenario_engine",
			"category": "bending",
			"event_name": "bending_world_championship_player_won",
			"actor_id": int(actor.id),
			"tournament_id": tournament_id,
			"tournament_year": int(tournament.get("year", int(gs.year))),
			"finish_move": finish_move,
			"memory_type": "championship",
			"emotion_tags": ["triumph", "legacy", "competition"],
			"pride_score": 0.95,
			"suppress_world_feed": true,
			"reality_surge_report": reality_surge_report.duplicate(true)
		})

	return {
		"type": "scenario_commit_complete",
		"text": diary_text,
		"popup_title": "WORLD CHAMPION",
		"popup_text": "You won the %s.\n\nFinal opponent: %s\nFinishing move: %s\nElement: %s\n\nThe bracket is over.\n\nYour name is now written into bending history." % [
			tournament_label,
			target_name,
			finish_move,
			element.capitalize()
		],
		"popup_footer": "Tap anywhere to continue.",
		"reality_surge_report": reality_surge_report.duplicate(true),
		"reality_surge": reality_surge_report.duplicate(true),
		"force_fullscreen_popup": not reality_surge_report.is_empty(),
		"opps": []
	}
func _finish_bending_duel_victory(actor: Person, target: Person, duel: Dictionary) -> Dictionary:
	if _bending_duel_is_mock_match(duel):
		return _finish_bending_duel_mock_match(actor, target, duel, true)

	var element: String = str(duel.get("player_element", _bending_duel_best_element(actor))).strip_edges().to_lower()
	var knockout_finish: bool = _bending_duel_finished_by_knockout(duel, "player")
	var tournament_duel: bool = bool(duel.get("tournament_duel", false))
	var mercy_resolved: bool = bool(duel.get("mercy_resolved", false))

	if tournament_duel and not knockout_finish and not mercy_resolved:
		duel ["pending_mercy_winner_id"] = int(actor.id)
		duel ["pending_mercy_loser_id"] = int(target.id)
		duel ["pending_mercy_element"] = element
		duel ["pending_mercy_finish_move"] = str(duel.get("pending_player_attack", {}).get("name", duel.get("last_player_move", "a finishing technique")))
		duel ["phase"] = "mercy_choice"
		gs.scenario_state ["bending_scenario_duel"] = duel
		return _queue_bending_duel_mercy_choice(actor, target, duel)

	duel ["active"] = false
	gs.scenario_state ["bending_scenario_duel"] = duel

	var target_damage: int = max(6, int(duel.get("damage_to_target", 0)))
	var mercy_action: String = str(duel.get("mercy_action", "")).strip_edges().to_lower()
	var lethal_finish: bool = not bool(target.alive)

	if lethal_finish:
		target.health = 0
	elif knockout_finish or mercy_action == "spare":
		target.health = max(1, clamp(int(target.health) - int(float(target_damage) * 0.28), 0, 200))
	else:
		target.health = clamp(int(target.health) - int(float(target_damage) * 0.28), 0, 200)

	if gs.bending_engine != null and gs.bending_engine.has_method("gain_bending_progress"):
		gs.bending_engine.gain_bending_progress(actor, element, randi_range(2, 5), "winning a scenario bending duel")

	var skill_points: int = clamp(1 + int(float(duel.get("target_power", 0)) / 65.0), 1, 5)
	if gs.bending_engine != null and gs.bending_engine.has_method("award_bending_skill_points"):
		gs.bending_engine.award_bending_skill_points(actor, skill_points, "winning_bending_duel")
		duel ["skill_points_awarded"] = skill_points

	if gs.bending_engine != null and gs.bending_engine.has_method("modify_respect"):
		gs.bending_engine.modify_respect(actor, 4 + skill_points, "won_bending_duel", "bending")
		gs.bending_engine.modify_respect(target, -2, "lost_bending_duel", "bending")

	if gs.narrative_engine != null:
		gs.narrative_engine.log_event(actor, {
			"type": "text",
			"text": "I defeated %s in a bending duel." % target.first_name,
			"life_diary_text": "I defeated %s in a bending duel." % target.first_name,
			"third_person_text": "%s defeated %s in a bending duel." % [
				("%s %s" % [actor.first_name, actor.last_name]).strip_edges(),
				("%s %s" % [target.first_name, target.last_name]).strip_edges()
			],
			"source": "scenario_engine",
			"category": "bending",
			"event_name": "scenario_bending_duel_victory",
			"actor_id": int(actor.id),
			"target_id": int(target.id),
			"opponent_id": int(target.id),
			"participant_ids": [int(actor.id), int(target.id)],
			"outcome": "victory",
			"memory_type": "combat",
			"supports_conflicting_narratives": true,
			"emotion_tags": ["competition", "achievement"],
			"pride_score": 0.35,
			"resentment_score": 0.08,
			"relationship_delta": -2,
			"suppress_world_feed": true
		})

	if gs.has_method("push_world_feed") and not lethal_finish:
		var feed_text: String = "%s knocked out %s in a bending duel." if knockout_finish else "%s defeated %s in a bending duel."
		gs.push_world_feed(feed_text % [
			_person_label_for_world_feed(actor),
			("%s %s" % [target.first_name, target.last_name]).strip_edges()
		], {
			"category": "bending",
			"event_name": "scenario_bending_duel_knockout" if knockout_finish else "scenario_bending_duel_victory",
			"personally_relevant": actor == gs.player or target == gs.player,
			"source": "scenario_engine",
			"knockout": knockout_finish,
			"tournament": tournament_duel
		})

	if gs.bending_engine != null and gs.bending_engine.has_method("record_bending_duel_result"):
		gs.bending_engine.record_bending_duel_result(actor, target, {
			"source": "scenario_engine",
			"tournament": tournament_duel,
			"tournament_id": str(duel.get("tournament_id", "")),
			"tournament_match_id": str(duel.get("tournament_match_id", "")),
			"tournament_division": str(duel.get("tournament_division", "")),
			"ko": knockout_finish,
			"death": lethal_finish,
			"death_world_feed_emitted": lethal_finish,
			"mercy_action": mercy_action,
			"finish_move": str(duel.get("mercy_finish_move", duel.get("pending_player_attack", {}).get("name", duel.get("last_player_move", "a finishing technique")))),
			"duel": duel.duplicate(true)
		})

	var championship_result: Dictionary = _maybe_build_bending_championship_victory_result(actor, target, duel, element)
	if not championship_result.is_empty():
		return championship_result

	return {
		"type": "scenario_commit_complete",
		"text": "I defeated %s in a bending duel." % target.first_name,
		"popup_title": "Bending Duel Won" if not knockout_finish else "Knockout Victory",
		"popup_text": "You read %s's stance and won the duel.\n\nYour %s bending gained real combat experience.\n\nSkill Points gained: %d\nBender Respect increased." % [
			target.first_name,
			element,
			int(duel.get("skill_points_awarded", 0))
		],
		"popup_footer": "Tap anywhere to continue.",
		"elemental_popup_theme": _bending_duel_victory_popup_theme(actor, element, knockout_finish, tournament_duel),
		"opps": []
	}

func _bending_duel_victory_popup_theme(actor: Person, element: String, knockout_finish: bool, tournament_duel: bool) -> Dictionary:
	var clean_element: String = str(element).strip_edges().to_lower()
	if actor != null and str(actor.bending_type).strip_edges().to_lower() == "avatar":
		clean_element = "avatar"
	if clean_element == "":
		clean_element = "bending"

	return {
		"schema": "eralife.bending_duel_victory_popup_theme",
		"version": 1,
		"theme_id": clean_element,
		"element": clean_element,
		"knockout_finish": knockout_finish,
		"tournament_duel": tournament_duel,
		"style_id": "bending_duel_victory_%s" % clean_element,
		"motion": "elemental_victory_pulse",
	}
func _finish_bending_duel_loss(actor: Person, target: Person, duel: Dictionary) -> Dictionary:
	if bool(duel.get("skip_player_willpower_last_stand", false)):
		duel ["skip_player_willpower_last_stand"] = false
	else:
		if _bending_duel_player_last_stand_choice_available(actor, duel):
			return _queue_bending_duel_player_last_stand_choice(actor, target, duel)

	if _duel_time_loop_last_chance_available(actor, duel, "bending"):
		return _queue_duel_time_loop_last_chance(actor, target, duel, "bending", "%s beat you clean." % str(duel.get("target_name", "Your opponent")))

	if _bending_duel_is_mock_match(duel):
		return _finish_bending_duel_mock_match(actor, target, duel, false)

	var knockout_finish: bool = _bending_duel_finished_by_knockout(duel, "target")
	var tournament_duel: bool = bool(duel.get("tournament_duel", false))
	var npc_mercy: Dictionary = _bending_duel_npc_mercy_decision(target, actor, duel)

	if tournament_duel and not knockout_finish and str(npc_mercy.get("action", "spare")) == "kill":
		var lethal_move: String = str(npc_mercy.get("finish_move", duel.get("last_enemy_move", {}).get("name", "a finishing technique")))
		duel ["active"] = false
		duel ["mercy_resolved"] = true
		duel ["mercy_action"] = "npc_kill"
		duel ["mercy_finish_move"] = lethal_move
		gs.scenario_state ["bending_scenario_duel"] = duel

		var death_report: Dictionary = _commit_bending_duel_death(actor, target, lethal_move, duel, {
			"source": "npc_bending_tournament_mercy_choice",
			"moral_label": str(npc_mercy.get("moral_label", "")),
			"death_world_feed_event": "scenario_bending_duel_player_killed"
		})

		if gs.bending_engine != null and gs.bending_engine.has_method("record_bending_duel_result"):
			gs.bending_engine.record_bending_duel_result(target, actor, {
				"source": "scenario_engine",
				"tournament": tournament_duel,
				"tournament_id": str(duel.get("tournament_id", "")),
				"tournament_match_id": str(duel.get("tournament_match_id", "")),
				"tournament_division": str(duel.get("tournament_division", "")),
				"ko": false,
				"death": true,
				"mercy_action": "npc_kill",
				"finish_move": lethal_move,
				"duel": duel.duplicate(true)
			})

		return {
			"type": "scenario_commit_complete",
			"text": "I was killed after losing a bending tournament duel against %s." % target.first_name,
			"popup_title": "Fatal Tournament Finish",
			"popup_text": "%s beat you, then chose not to spare you.\n\nFinish: %s\nEra judgment: %s" % [
				target.first_name,
				lethal_move,
				str(npc_mercy.get("moral_label", "The world will remember it."))
			],
			"popup_footer": "Tap anywhere to continue.",
			"death_report": death_report.duplicate(true),
			"opps": []
		}

	duel ["active"] = false
	gs.scenario_state ["bending_scenario_duel"] = duel

	var before_health: int = int(actor.health)
	var before_mental: int = int(actor.mental_health)
	var health_loss: int = clamp(8 + int(float(duel.get("damage_to_player", 0)) * 0.22), 6, 34)
	var mental_loss: int = clamp(4 + int(float(duel.get("target_read", 0)) * 0.08), 3, 18)

	actor.health = max(1, int(actor.health) - health_loss)
	actor.mental_health = max(0, int(actor.mental_health) - mental_loss)

	if gs.bending_engine != null and gs.bending_engine.has_method("award_bending_skill_points"):
		gs.bending_engine.award_bending_skill_points(actor, 1, "survived_bending_duel_loss")
		duel ["skill_points_awarded"] = 1

	if gs.bending_engine != null and gs.bending_engine.has_method("modify_respect"):
		gs.bending_engine.modify_respect(actor, -3, "lost_bending_duel", "bending")
		gs.bending_engine.modify_respect(target, 3, "won_bending_duel", "bending")

	if gs.narrative_engine != null:
		gs.narrative_engine.log_event(actor, {
			"type": "text",
			"text": "I lost a bending duel against %s." % target.first_name,
			"life_diary_text": "I lost a bending duel against %s." % target.first_name,
			"third_person_text": "%s lost a bending duel against %s." % [
				("%s %s" % [actor.first_name, actor.last_name]).strip_edges(),
				("%s %s" % [target.first_name, target.last_name]).strip_edges()
			],
			"source": "scenario_engine",
			"category": "bending",
			"event_name": "scenario_bending_duel_loss",
			"actor_id": int(actor.id),
			"target_id": int(target.id),
			"opponent_id": int(target.id),
			"participant_ids": [int(actor.id), int(target.id)],
			"outcome": "loss",
			"memory_type": "combat",
			"supports_conflicting_narratives": true,
			"emotion_tags": ["competition", "humiliation"],
			"trauma_score": 0.08,
			"resentment_score": 0.12,
			"relationship_delta": -3,
			"suppress_world_feed": true
		})

	if gs.has_method("push_world_feed"):
		var feed_text: String = "%s knocked out %s in a bending duel." if knockout_finish else "%s defeated %s in a bending duel."
		gs.push_world_feed(feed_text % [
			("%s %s" % [target.first_name, target.last_name]).strip_edges(),
			_person_label_for_world_feed(actor)
		], {
			"category": "bending",
			"event_name": "scenario_bending_duel_knockout_loss" if knockout_finish else "scenario_bending_duel_loss",
			"personally_relevant": actor == gs.player or target == gs.player,
			"source": "scenario_engine",
			"knockout": knockout_finish,
			"tournament": tournament_duel
		})

	if gs.bending_engine != null and gs.bending_engine.has_method("record_bending_duel_result"):
		gs.bending_engine.record_bending_duel_result(target, actor, {
			"source": "scenario_engine",
			"tournament": tournament_duel,
			"tournament_id": str(duel.get("tournament_id", "")),
			"tournament_match_id": str(duel.get("tournament_match_id", "")),
			"tournament_division": str(duel.get("tournament_division", "")),
			"ko": knockout_finish,
			"death": false,
			"mercy_action": "spare" if tournament_duel and not knockout_finish else "",
			"finish_move": str(duel.get("last_enemy_move", {}).get("name", "a finishing technique")),
			"duel": duel.duplicate(true)
		})

	return {
		"type": "scenario_commit_complete",
		"text": "I lost a bending duel against %s. My health went from %d to %d and my mental health went from %d to %d." % [
			target.first_name,
			before_health,
			int(actor.health),
			before_mental,
			int(actor.mental_health)
		],
		"popup_title": "Knocked Out" if knockout_finish else "Bending Duel Lost",
		"popup_text": "%s read your bending and beat you clean.\n\nHealth: %d → %d\nMental Health: %d → %d" % [
			target.first_name,
			before_health,
			int(actor.health),
			before_mental,
			int(actor.mental_health)
		],
		"popup_footer": "Tap anywhere to continue.",
		"opps": []
	}
func _bending_duel_finished_by_knockout(duel: Dictionary, winner_side: String = "player") -> bool:
	var clean_side: String = str(winner_side).strip_edges().to_lower()
	if clean_side == "target" or clean_side == "npc" or clean_side == "enemy":
		return bool(duel.get("target_inflicted_knockout", false))
	return bool(duel.get("player_inflicted_knockout", false))


func _queue_bending_duel_mercy_choice(actor: Person, target: Person, duel: Dictionary) -> Dictionary:
	var finish_move: String = str(duel.get("pending_mercy_finish_move", "a finishing technique")).strip_edges()
	var target_name: String = _person_label_for_world_feed(target)
	var actor_name: String = _person_label_for_world_feed(actor)
	var moral_label: String = _bending_duel_era_moral_label()

	var actor_hp_max: int = max(1, int(duel.get("player_hp_max", 100)))
	var target_hp_max: int = max(1, int(duel.get("target_hp_max", 100)))
	var actor_hp: int = clamp(int(duel.get("player_hp", int(actor.health) if actor != null else actor_hp_max)), 0, actor_hp_max)
	var target_hp: int = clamp(int(duel.get("target_hp", int(target.health) if target != null else 0)), 0, target_hp_max)

	var choices: Array = [
		{
			"id": "bending_mercy_spare",
			"label": "Spare %s" % target.first_name,
			"kind": "scenario_choice",
			"journal_text": "I spared %s after defeating them in a bending tournament duel." % target.first_name,
			"button_theme": "defensive_escape",
			"power_source": "mercy",
			"bending_duel_target_id": int(target.id),
			"payload": {
				"mercy_action": "spare"
			}
		}
	]

	for raw_choice in _bending_duel_unlocked_finisher_choices(actor, target, duel):
		if typeof(raw_choice) == TYPE_DICTIONARY:
			choices.append(raw_choice)

	return queue_external_scenario({
		"id": "bending_mercy_choice_%d_%d_%d" % [int(actor.id), int(target.id), int(Time.get_ticks_msec())],
		"source": "scenario_engine",
		"category": "bending",
		"resolver_method": "_resolve_bending_duel_choice",
		"panel_title": "BENDING TOURNAMENT FINISH",
		"footer_text": "The duel is won. What happens next becomes history.",
		"prompt": "%s is beaten, but this was not a one-shot knockout.\n\n%s has %d/%d HP left.\n\nYou can spare them, or finish them with an unlocked bending move.\n\nEra judgment: %s" % [
			target_name,
			target_name,
			target_hp,
			target_hp_max,
			moral_label
		],
		"actor_id": int(actor.id),
		"target_id": int(target.id),
		"bending_duel_target_id": int(target.id),
		"choices": choices,
		"combat_ui": {
			"visible": true,
			"theme": "bending_duel_mercy",
			"status_text": "Mercy choice • %s • %s has %d/%d HP left" % [
				finish_move,
				target_name,
				target_hp,
				target_hp_max
			],
			"player_label": "%s • %d/%d HP" % [
				actor_name,
				actor_hp,
				actor_hp_max
			],
			"player_value": actor_hp,
			"player_max": actor_hp_max,
			"enemy_label": "%s • defeated • %d/%d HP" % [
				target_name,
				target_hp,
				target_hp_max
			],
			"enemy_value": target_hp,
			"enemy_max": target_hp_max,
			"enemy_state": "defeated_loser",
			"impact_shake": true,
			"impact_shake_amount": 6.0
		}
	})

func _bending_duel_unlocked_finisher_choices(actor: Person, target: Person, duel: Dictionary) -> Array:
	var out: Array = []
	if actor == null or target == null:
		return out
	if gs == null or gs.bending_engine == null:
		return out
	if not gs.bending_engine.has_method("get_available_bending_abilities"):
		return out

	var abilities: Array = gs.bending_engine.get_available_bending_abilities(actor)
	var added: int = 0

	for raw_ability in abilities:
		if typeof(raw_ability) != TYPE_DICTIONARY:
			continue

		var ability: Dictionary = raw_ability
		if not bool(ability.get("unlocked", false)):
			continue
		if bool(ability.get("on_cooldown", false)):
			continue

		var ability_name: String = str(ability.get("name", ability.get("display_name", ability.get("id", "")))).strip_edges()
		if ability_name == "":
			continue

		var ability_id: String = str(ability.get("id", ability_name)).strip_edges()
		var ability_element: String = str(ability.get("element", duel.get("player_element", "bending"))).strip_edges().to_lower()

		out.append({
			"id": "bending_mercy_kill_%s" % ability_id.replace(" ", "_").replace(".", "_"),
			"label": "Kill with %s" % ability_name,
			"kind": "scenario_choice",
			"journal_text": "I chose a fatal finish after winning the bending tournament duel.",
			"button_theme": "artifact_action",
			"power_source": "bending",
			"bending_duel_target_id": int(target.id),
			"ability_id": ability_id,
			"ability_name": ability_name,
			"ability_element": ability_element,
			"payload": {
				"mercy_action": "kill",
				"finish_move": ability_name,
				"ability_id": ability_id,
				"ability_element": ability_element
			}
		})

		added += 1
		if added >= 6:
			break

	if out.is_empty():
		var fallback_move: String = str(duel.get("pending_mercy_finish_move", "Final Bending Strike")).strip_edges()
		out.append({
			"id": "bending_mercy_kill_fallback",
			"label": "Kill with %s" % fallback_move,
			"kind": "scenario_choice",
			"journal_text": "I chose a fatal finish after winning the bending tournament duel.",
			"button_theme": "artifact_action",
			"power_source": "bending",
			"bending_duel_target_id": int(target.id),
			"payload": {
				"mercy_action": "kill",
				"finish_move": fallback_move
			}
		})

	return out


func _resolve_bending_duel_aftermath_choice(actor: Person, scenario: Dictionary, choice: Dictionary) -> Dictionary:
	var choice_id: String = str(choice.get("id", "")).strip_edges()
	var target_id: int = int(choice.get("bending_duel_target_id", scenario.get("bending_duel_target_id", scenario.get("target_id", -1))))
	var target: Person = _scenario_person_by_id(target_id)
	var duel: Dictionary = _rf_duel_dict(gs.scenario_state.get("bending_scenario_duel", {}))

	if choice_id == "bending_funeral_attend":
		return _resolve_bending_duel_funeral_attendance(actor, scenario, choice, true)

	if choice_id == "bending_funeral_skip":
		return _resolve_bending_duel_funeral_attendance(actor, scenario, choice, false)

	if target == null:
		return {
			"type": "scenario_commit_complete",
			"text": "The aftermath could not resolve because the opponent was missing.",
			"popup_title": "Bending Duel Aftermath",
			"popup_text": "The opponent is no longer available.",
			"popup_footer": "Tap anywhere to continue.",
			"opps": []
		}

	if choice_id == "bending_reality_break_continue":
		var break_death_report: Dictionary = _rf_duel_dict(scenario.get("death_report", {}))
		var championship_finish_result: Dictionary = _rf_duel_dict(scenario.get("finish_result", {}))
		return _queue_bending_duel_funeral_choice(actor, target, duel, break_death_report, championship_finish_result)

	var payload: Dictionary = _rf_duel_dict(choice.get("payload", {}))
	var mercy_action: String = str(payload.get("mercy_action", choice.get("mercy_action", "spare"))).strip_edges().to_lower()
	var finish_move: String = str(payload.get("finish_move", choice.get("ability_name", duel.get("pending_mercy_finish_move", "a finishing technique")))).strip_edges()

	if finish_move == "":
		finish_move = "a finishing technique"

	duel ["mercy_resolved"] = true
	duel ["mercy_action"] = mercy_action
	duel ["mercy_finish_move"] = finish_move

	if payload.has("ability_element"):
		duel ["mercy_finish_element"] = str(payload.get("ability_element", "")).strip_edges().to_lower()
	elif choice.has("ability_element"):
		duel ["mercy_finish_element"] = str(choice.get("ability_element", "")).strip_edges().to_lower()
	else:
		duel ["mercy_finish_element"] = str(duel.get("pending_mercy_element", duel.get("player_element", _bending_duel_best_element(actor)))).strip_edges().to_lower()

	if mercy_action == "kill":
		var death_report: Dictionary = _commit_bending_duel_death(target, actor, finish_move, duel, {
			"source": "player_bending_tournament_mercy_choice",
			"moral_label": _bending_duel_era_moral_label(),
			"death_world_feed_event": "scenario_bending_duel_opponent_killed",
			"element": str(duel.get("mercy_finish_element", duel.get("player_element", ""))).strip_edges().to_lower()
		})

		duel ["death_report"] = death_report.duplicate(true)
		gs.scenario_state ["bending_scenario_duel"] = duel

		var finish_result: Dictionary = _finish_bending_duel_victory(actor, target, duel)
		gs.scenario_state ["last_bending_fatal_finish_result"] = finish_result.duplicate(true)

		var reality_break_report: Dictionary = _trigger_bending_duel_fatal_reality_break_surge(actor, target, finish_move, duel, death_report, finish_result)
		gs.scenario_state ["last_bending_fatal_reality_break_report"] = reality_break_report.duplicate(true)

		return _queue_bending_duel_reality_break_finish(actor, target, duel, death_report, finish_result, reality_break_report)

	duel ["spared_loser_id"] = int(target.id)
	gs.scenario_state ["bending_scenario_duel"] = duel

	if gs.has_method("push_world_feed"):
		gs.push_world_feed("%s spared %s after winning a bending tournament duel." % [
			_person_label_for_world_feed(actor),
			_person_label_for_world_feed(target)
		], {
			"category": "bending",
			"event_name": "scenario_bending_duel_spared_opponent",
			"personally_relevant": actor == gs.player or target == gs.player,
			"source": "scenario_engine",
			"tournament": bool(duel.get("tournament_duel", false))
		})

	return _finish_bending_duel_victory(actor, target, duel)


func _commit_bending_duel_death(victim: Person, killer: Person, finish_move: String, duel: Dictionary, context: Dictionary = {}) -> Dictionary:
	if victim == null:
		return {}

	var cause: String = "Killed in a bending tournament duel by %s using %s" % [
		_person_label_for_world_feed(killer),
		str(finish_move).strip_edges()
	]

	victim.health = 0
	if gs != null and gs.has_method("sync_person_death_state_from_health"):
		gs.sync_person_death_state_from_health(victim, cause)
	else:
		victim.alive = false
		victim.cause_of_death = cause

	if gs != null and gs.narrative_engine != null:
		gs.narrative_engine.log_event(victim, {
			"type": "text",
			"text": "%s died after a bending tournament duel." % _person_label_for_world_feed(victim),
			"third_person_text": "%s died after a bending tournament duel against %s." % [
				_person_label_for_world_feed(victim),
				_person_label_for_world_feed(killer)
			],
			"source": "scenario_engine",
			"category": "death",
			"event_name": "bending_tournament_duel_death",
			"actor_id": int(victim.id),
			"killer_id": int(killer.id) if killer != null else -1,
			"finish_move": finish_move,
			"suppress_world_feed": true
		})

	if gs != null and gs.has_method("push_world_feed"):
		gs.push_world_feed("%s killed %s after a bending tournament duel with %s." % [
			_person_label_for_world_feed(killer),
			_person_label_for_world_feed(victim),
			str(finish_move).strip_edges()
		], {
			"category": "death",
			"event_name": str(context.get("death_world_feed_event", "bending_tournament_duel_death")),
			"source": "scenario_engine",
			"personally_relevant": killer == gs.player or victim == gs.player,
			"npc_id": int(victim.id),
			"killer_id": int(killer.id) if killer != null else -1,
			"finish_move": finish_move,
			"moral_label": str(context.get("moral_label", "")),
			"tournament_id": str(duel.get("tournament_id", "")),
			"tournament_match_id": str(duel.get("tournament_match_id", ""))
		})

	return {
		"schema": "eralife.bending_duel_death_report",
		"version": 1,
		"success": not bool(victim.alive),
		"victim_id": int(victim.id),
		"killer_id": int(killer.id) if killer != null else -1,
		"victim_name": _person_label_for_world_feed(victim),
		"killer_name": _person_label_for_world_feed(killer),
		"cause": cause,
		"finish_move": finish_move,
		"moral_label": str(context.get("moral_label", "")),
		"year": int(gs.year) if gs != null else 0
	}

func _trigger_bending_duel_fatal_reality_break_surge(
	actor: Person,
	victim: Person,
	finish_move: String,
	duel: Dictionary,
	death_report: Dictionary,
	finish_result: Dictionary
) -> Dictionary:
	if gs == null or actor == null or victim == null:
		return {}
	if not ("reality_surge_engine" in gs) or gs.reality_surge_engine == null:
		return {}
	if not gs.reality_surge_engine.has_method("trigger_surge"):
		return {}

	var element: String = str(duel.get("mercy_finish_element", duel.get("pending_mercy_element", duel.get("player_element", _bending_duel_best_element(actor))))).strip_edges().to_lower()
	if element == "":
		element = _bending_duel_best_element(actor)
	if element == "":
		element = "bending"

	var championship_final: bool = _bending_duel_reality_break_is_championship_final(actor, duel, finish_result)
	var contract_id: String = "bending.championship_fatal_final.reality_break" if championship_final else "bending.fatal_finish.reality_break"
	var reality_break_contract: Dictionary = _bending_duel_reality_break_surge_contract(contract_id, element, finish_move, championship_final)

	if gs.reality_surge_engine.has_method("register_surge_contract"):
		gs.reality_surge_engine.register_surge_contract(reality_break_contract)

	var surge_direction: String = "actor_to_victim"
	var surge_origin_name: String = _person_label_for_world_feed(actor)
	var surge_target_name: String = _person_label_for_world_feed(victim)
	var surge_line: String = "%s bending surged out of %s and into %s." % [
		element.capitalize(),
		surge_origin_name,
		surge_target_name
	]

	var salience: float = 100.0
	var event_payload: Dictionary = {
		"schema": "eralife.bending_fatal_finish_reality_break_event",
		"version": 2,
		"event_name": "bending.fatal_finish.reality.break",
		"domain": "bending",
		"reality_break": true,
		"championship": bool(duel.get("tournament_duel", false)),
		"championship_final": championship_final,
		"fatal_finish": true,
		"death": true,
		"winner_is_player": actor == gs.player,
		"winner_id": int(actor.id),
		"winner_name": surge_origin_name,
		"victim_id": int(victim.id),
		"victim_name": surge_target_name,
		"tournament_id": str(duel.get("tournament_id", "")),
		"tournament_match_id": str(duel.get("tournament_match_id", "")),
		"match_id": str(duel.get("tournament_match_id", "")),
		"division": str(duel.get("tournament_division", "")),
		"element": element,
		"finish_move": finish_move,
		"screen_damage": "max",
		"time_dilation": 0.3,
		"audio_muffle": 1.0,
		"surge_direction": surge_direction,
		"surge_origin_id": int(actor.id),
		"surge_origin_name": surge_origin_name,
		"surge_target_id": int(victim.id),
		"surge_target_name": surge_target_name,
		"surge_vector_mode": "element_into_body",
		"surge_line": surge_line,
		"death_report": death_report.duplicate(true),
		"finish_result": finish_result.duplicate(true),
		"salience": salience
	}

	return gs.reality_surge_engine.trigger_surge(contract_id, actor, event_payload, {
		"source": "scenario_engine_bending_fatal_finish_reality_break",
		"force": true,
		"duplicate_window_ms": 900,
		"tournament_id": str(duel.get("tournament_id", "")),
		"division": str(duel.get("tournament_division", "")),
		"element": element,
		"fatal_finish": true,
		"championship_final": championship_final,
		"finish_move": finish_move,
		"surge_direction": surge_direction,
		"surge_origin_id": int(actor.id),
		"surge_target_id": int(victim.id),
		"salience": salience
	})
func _bending_duel_reality_break_surge_contract(contract_id: String, element: String, finish_move: String, championship_final: bool) -> Dictionary:
	var clean_element: String = str(element).strip_edges().to_lower()
	if clean_element == "":
		clean_element = "bending"

	var finish_profile: Dictionary = _bending_duel_reality_break_finish_profile(clean_element, finish_move, championship_final)

	return {
		"schema": "eralife.reality_surge_contract",
		"version": 2,
		"id": contract_id,
		"domain": "bending",
		"display_name": "Fatal Bending Finish Reality Break",
		"trigger": {
			"event": "bending.fatal_finish.reality_break",
			"filters": {
				"domain": "bending",
				"fatal_finish": true
			},
			"threshold": {
				"salience_min": 95.0
			}
		},
		"surge_profile": {
			"type": ["reality_break", "fatal_finish", "elemental_execution", "championship_final" if championship_final else "duel_aftermath"],
			"intensity": 1.0,
			"championship_final": championship_final,
			"finish_move": finish_move,
			"element": clean_element
		},
		"visual_layer": {
			"theme_resolver": "elemental_affinity_resolver",
			"shader_profile": "fatal_reality_break_%s" % clean_element,
			"screen_damage": "max",
			"screen_damage_intensity": 1.0,
			"screen_fracture": true,
			"screen_bleed": true,
			"distortion": true,
			"particles": true,
			"fatal_finish": true,
			"element": clean_element,
			"finish_move": finish_move,
			"finish_profile": finish_profile.duplicate(true)
		},
		"perception_layer": {
			"time_dilation": 0.3,
			"input_lock_ms": 2400,
			"camera_weight": 1.0,
			"audio_muffle": 1.0,
		},
		"reward_manifestation": {},
		"stat_echo": {
			"temporary_boost": {
				"willpower": 16
			},
			"duration_ms": 2600,
			"decay_curve": "snapback_after_fatal_finish"
		},
		"stability": {
			"instability_gain": 0.5,
			"mutation_chance": 0.035,
		}
	}
func _bending_duel_reality_break_finish_profile(element: String, finish_move: String, championship_final: bool) -> Dictionary:
	var clean_element: String = str(element).strip_edges().to_lower()
	var final_weight: String = "championship final" if championship_final else "fatal duel finish"

	var profile: Dictionary = {
		"schema": "eralife.bending_duel_reality_break_finish_profile",
		"version": 1,
		"element": clean_element,
		"finish_move": finish_move,
		"final_weight": final_weight,
		"screen_damage": "max",
		"time_dilation": 0.3,
		"audio_muffle": 1.0
	}

	match clean_element:
		"fire":
			profile ["title"] = "REALITY BREAK: FINAL FLAME"
			profile ["body"] = "%s does not just hit. It blooms through the arena like the world forgot how not to burn." % finish_move
			profile ["kill_line"] = "The fire takes the last word before anyone can scream."
			profile ["motion"] = "ember_screen_fracture_heat_warp"
		"water":
			profile ["title"] = "REALITY BREAK: FINAL TIDE"
			profile ["body"] = "%s bends the water into pressure, silence, and inevitability." % finish_move
			profile ["kill_line"] = "The arena hears the breath leave before the body understands."
			profile ["motion"] = "ripple_screen_pressure_freeze"
		"earth":
			profile ["title"] = "REALITY BREAK: FINAL STONE"
			profile ["body"] = "%s lands with enough weight to make the UI feel buried under the arena." % finish_move
			profile ["kill_line"] = "The ground accepts them like history was already waiting."
			profile ["motion"] = "stone_crack_gravity_drop"
		"air":
			profile ["title"] = "REALITY BREAK: FINAL BREATH"
			profile ["body"] = "%s cuts through the space between heartbeat and breath." % finish_move
			profile ["kill_line"] = "The air leaves first. The silence stays."
			profile ["motion"] = "vacuum_pull_border_shatter"
		"avatar":
			profile ["title"] = "REALITY BREAK: AVATAR FINALITY"
			profile ["body"] = "%s cycles through fire, water, earth, and air until reality cannot separate the hit from the judgment." % finish_move
			profile ["kill_line"] = "All four elements agree. The moment ends."
			profile ["motion"] = "four_element_reality_split"
		_:
			profile ["title"] = "REALITY BREAK: FINAL HIT"
			profile ["body"] = "%s bends the ending harder than the body." % finish_move
			profile ["kill_line"] = "The arena goes quiet before the world feed can name it."
			profile ["motion"] = "generic_reality_fracture"

	return profile
func _queue_bending_duel_reality_break_finish(
	actor: Person,
	victim: Person,
	duel: Dictionary,
	death_report: Dictionary,
	finish_result: Dictionary,
	reality_break_report: Dictionary
) -> Dictionary:
	var finish_move: String = str(duel.get("mercy_finish_move", death_report.get("finish_move", "a finishing technique"))).strip_edges()
	if finish_move == "":
		finish_move = "a finishing technique"

	var element: String = str(duel.get("mercy_finish_element", duel.get("pending_mercy_element", duel.get("player_element", _bending_duel_best_element(actor))))).strip_edges().to_lower()
	if element == "":
		element = _bending_duel_best_element(actor)
	if element == "":
		element = "bending"

	var championship_final: bool = _bending_duel_reality_break_is_championship_final(actor, duel, finish_result)
	var profile: Dictionary = _bending_duel_reality_break_finish_profile(element, finish_move, championship_final)
	var actor_name: String = _person_label_for_world_feed(actor)
	var victim_name: String = _person_label_for_world_feed(victim)

	var surge_line: String = "%s surged out of %s and into %s." % [
		element.capitalize(),
		actor_name,
		victim_name
	]

	var champion_line: String = ""
	if championship_final:
		champion_line = "\n\nThis was not just a kill.\n\nThis was the final hit of a championship run. The bracket ends with reality breaking around your element."

	var prompt_text: String = "%s\n\n%s used %s on %s.\n\n%s\n\n%s%s\n\nFor one frozen second, this moment matters more than reality." % [
		str(profile.get("body", "The final hit breaks through the moment.")),
		actor_name,
		finish_move,
		victim_name,
		surge_line,
		str(profile.get("kill_line", "The arena goes silent.")),
		champion_line
	]

	return queue_external_scenario({
		"id": "bending_reality_break_finish_%d_%d_%d" % [int(actor.id), int(victim.id), int(Time.get_ticks_msec())],
		"source": "scenario_engine",
		"category": "bending",
		"resolver_method": "_resolve_bending_duel_choice",
		"panel_title": str(profile.get("title", "REALITY BREAK")),
		"footer_text": "Reality catches up after the final hit. The funeral comes next.",
		"prompt": prompt_text,
		"actor_id": int(actor.id),
		"target_id": int(victim.id),
		"bending_duel_target_id": int(victim.id),
		"death_report": death_report.duplicate(true),
		"finish_result": finish_result.duplicate(true),
		"reality_surge_report": reality_break_report.duplicate(true),
		"championship_final": championship_final,
		"fatal_finish": true,
		"finish_move": finish_move,
		"finish_element": element,
		"surge_direction": "actor_to_victim",
		"surge_origin_id": int(actor.id),
		"surge_target_id": int(victim.id),
		"choices": [
			{
				"id": "bending_reality_break_continue",
				"label": "Let reality catch up",
				"kind": "scenario_choice",
				"journal_text": "Reality broke around my final bending hit before the funeral aftermath began.",
				"button_theme": "bending_ability",
				"power_source": "bending",
				"bending_duel_target_id": int(victim.id),
				"payload": {
					"reality_break_action": "continue_to_funeral"
				}
			}
		],
		"combat_ui": {
			"visible": true,
			"theme": "bending_avatar" if element == "avatar" else "bending_element_%s" % element,
			"status_text": "REALITY BREAK • %s • screen damage max" % element.capitalize(),
			"player_label": "%s • final hit" % actor_name,
			"player_value": clamp(int(duel.get("player_hp", int(actor.health) if actor != null else 1)), 0, max(1, int(duel.get("player_hp_max", 100)))),
			"player_max": max(1, int(duel.get("player_hp_max", 100))),
			"enemy_label": "%s • ended by %s" % [victim_name, finish_move],
			"enemy_value": 0,
			"enemy_max": max(1, int(duel.get("target_hp_max", 100))),
			"enemy_state": "fatal_finish",
			"impact_shake": true,
			"impact_shake_amount": 24.0,
			"surge_vector": {
				"enabled": true,
				"direction": "actor_to_victim",
				"origin_id": int(actor.id),
				"target_id": int(victim.id),
				"element": element,
				"mode": "element_into_body",
				"text": surge_line
			},
			"elemental_screen_damage": {
				"enabled": true,
				"screen_damage": "max",
				"screen_damage_intensity": 1.0,
				"screen_fracture": true,
				"screen_bleed": true,
				"time_dilation": 0.3,
				"audio_muffle": 1.0,
				"element": element,
				"finish_move": finish_move,
				"motion": str(profile.get("motion", "reality_fracture"))
			},
			"reality_surge": reality_break_report.duplicate(true)
		}
	})
func _bending_duel_reality_break_is_championship_final(actor: Person, duel: Dictionary, finish_result: Dictionary) -> bool:
	if actor == null or gs == null:
		return false

	if bool(finish_result.get("championship_final", false)):
		return true

	if str(finish_result.get("popup_title", "")).strip_edges().to_upper() == "WORLD CHAMPION":
		return true

	if not bool(duel.get("tournament_duel", false)):
		return false

	var tournament_id: String = str(duel.get("tournament_id", "")).strip_edges()
	if tournament_id == "":
		return false

	if gs.bending_engine == null:
		return false
	if not gs.bending_engine.has_method("_bending_tournament_reload_by_id"):
		return false

	var tournament: Dictionary = gs.bending_engine.call("_bending_tournament_reload_by_id", tournament_id)
	if tournament.is_empty():
		return false

	if str(tournament.get("status", "")).strip_edges().to_lower() == "complete":
		return int(tournament.get("champion_id", -1)) == int(actor.id)

	var round_value: int = int(duel.get("tournament_round", tournament.get("completed_round", 1)))
	var round_label: String = str(duel.get("tournament_round_label", "")).strip_edges()

	if round_label == "":
		if gs.bending_engine.has_method("_bending_tournament_field_size_for_round") and gs.bending_engine.has_method("_bending_tournament_round_label"):
			var field_size: int = int(gs.bending_engine.call("_bending_tournament_field_size_for_round", tournament, round_value))
			round_label = str(gs.bending_engine.call("_bending_tournament_round_label", round_value, field_size)).strip_edges()

	return round_label.to_lower() == "championship final"
func _queue_bending_duel_funeral_choice(actor: Person, dead_person: Person, _duel: Dictionary, death_report: Dictionary, championship_finish_result: Dictionary = {}) -> Dictionary:
	return queue_external_scenario({
		"id": "bending_duel_funeral_%d_%d_%d" % [int(actor.id), int(dead_person.id), int(Time.get_ticks_msec())],
		"source": "scenario_engine",
		"category": "death",
		"resolver_method": "_resolve_bending_duel_choice",
		"panel_title": "FUNERAL AFTERMATH",
		"footer_text": "Respect can lower the fire. It can also put you in the room with people who hate you.",
		"prompt": "%s's family is holding a funeral.\n\nYou can attend out of respect, but there may be relatives, students, or top benders there who blame you." % _person_label_for_world_feed(dead_person),
		"actor_id": int(actor.id),
		"target_id": int(dead_person.id),
		"bending_duel_target_id": int(dead_person.id),
		"death_report": death_report.duplicate(true),
		"championship_finish_result": championship_finish_result.duplicate(true),
		"choices": [
			{
				"id": "bending_funeral_attend",
				"label": "Attend the funeral in respect",
				"kind": "scenario_choice",
				"journal_text": "I attended the funeral after the fatal bending tournament duel.",
				"button_theme": "relationship_action",
				"power_source": "social",
				"bending_duel_target_id": int(dead_person.id),
				"payload": {
					"funeral_action": "attend"
				}
			},
			{
				"id": "bending_funeral_skip",
				"label": "Do not attend",
				"kind": "scenario_choice",
				"journal_text": "I did not attend the funeral after the fatal bending tournament duel.",
				"button_theme": "defensive_escape",
				"power_source": "survival",
				"bending_duel_target_id": int(dead_person.id),
				"payload": {
					"funeral_action": "skip"
				}
			}
		],
		"combat_ui": {
			"visible": false
		}
	})


func _resolve_bending_duel_funeral_attendance(actor: Person, scenario: Dictionary, _choice: Dictionary, attending: bool) -> Dictionary:
	var dead_id: int = int(scenario.get("target_id", scenario.get("bending_duel_target_id", -1)))
	var dead_person: Person = _scenario_person_by_id(dead_id)
	var dead_name: String = _person_label_for_world_feed(dead_person)

	var risk_text: String = "You stayed away. The family grieved without seeing you."
	var event_name: String = "bending_duel_funeral_skipped"
	var resentment_delta: int = 3

	if attending:
		event_name = "bending_duel_funeral_attended"
		resentment_delta = -2
		risk_text = "You attended the funeral. Some people respected the gesture. Others memorized your face."

	if gs != null and gs.has_method("push_world_feed"):
		gs.push_world_feed("%s %s %s's funeral after a fatal bending tournament duel." % [
			_person_label_for_world_feed(actor),
			"attended" if attending else "skipped",
			dead_name
		], {
			"category": "death",
			"event_name": event_name,
			"source": "scenario_engine",
			"personally_relevant": true,
			"dead_person_id": dead_id,
			"attended": attending
		})

	if gs != null and gs.bending_engine != null and gs.bending_engine.has_method("adjust_bending_revenge_heat_for_funeral_choice"):
		gs.bending_engine.adjust_bending_revenge_heat_for_funeral_choice(actor, dead_id, {
			"attended": attending,
			"resentment_delta": resentment_delta,
			"source": "bending_duel_funeral_choice"
		})

	var result: Dictionary = {
		"type": "scenario_commit_complete",
		"text": "I %s the funeral after the fatal bending tournament duel." % ("attended" if attending else "skipped"),
		"popup_title": "Funeral Attended" if attending else "Funeral Skipped",
		"popup_text": risk_text,
		"popup_footer": "Tap anywhere to continue.",
		"opps": []
	}

	var championship_finish_result: Dictionary = _rf_duel_dict(scenario.get("championship_finish_result", {}))
	if _bending_championship_finish_result_is_valid(championship_finish_result):
		result ["followup_result"] = championship_finish_result.duplicate(true)

	return result
func _bending_championship_finish_result_is_valid(result: Dictionary) -> bool:
	if result.is_empty():
		return false

	if str(result.get("popup_title", "")).strip_edges().to_upper() == "WORLD CHAMPION":
		return true

	var surge: Dictionary = _rf_duel_dict(result.get("reality_surge_report", result.get("reality_surge", {})))
	return not surge.is_empty() and bool(surge.get("success", false))


func _bending_duel_npc_mercy_decision(winner: Person, loser: Person, duel: Dictionary) -> Dictionary:
	var moral_label: String = _bending_duel_era_moral_label()
	var kill_chance: int = 8

	var era_key: String = _bending_duel_era_key()
	match era_key:
		"ancient":
			kill_chance = 24
		"medieval":
			kill_chance = 18
		"industrial":
			kill_chance = 10
		"future":
			kill_chance = 6
		_:
			kill_chance = 7

	if winner != null:
		kill_chance += clamp(int(floor(float(int(winner.ambition)) / 18.0)), 0, 5)
		kill_chance += clamp(int(floor(float(int(winner.fame)) / 28.0)), 0, 4)

	if loser != null and int(loser.fame) >= 70:
		kill_chance += 4

	kill_chance = clamp(kill_chance, 2, 42)
	var rolled_kill: bool = (randi() % 100) < kill_chance

	return {
		"action": "kill" if rolled_kill else "spare",
		"kill_chance": kill_chance,
		"moral_label": moral_label,
		"finish_move": str(duel.get("last_enemy_move", {}).get("name", "a finishing technique"))
	}


func _bending_duel_era_key() -> String:
	if gs == null:
		return "modern"
	if gs.era_engine != null and gs.era_engine.has_method("get_era_key_from_year"):
		return str(gs.era_engine.call("get_era_key_from_year", int(gs.year))).strip_edges().to_lower()
	if gs.era != null:
		if typeof(gs.era) == TYPE_DICTIONARY:
			return str(gs.era.get("key", "modern")).strip_edges().to_lower()
		return str(gs.era.name).strip_edges().to_lower()
	return "modern"


func _bending_duel_era_moral_label() -> String:
	match _bending_duel_era_key():
		"ancient":
			return "Ancient crowds may call a fatal finish honorable, but families still remember blood."
		"medieval":
			return "Medieval courts may tolerate fatal combat, but revenge can become a family duty."
		"industrial":
			return "Industrial society treats fatal tournament finishes as scandalous and dangerous."
		"future":
			return "Future institutions condemn fatal tournament finishes and may preserve every angle of the death."
		_:
			return "Modern audiences see fatal tournament finishes as morally severe, even when the rules allow it."


func _finish_bending_duel_concession(actor: Person, target: Person, duel: Dictionary) -> Dictionary:
	var before_mental: int = int(actor.mental_health)
	actor.mental_health = max(0, int(actor.mental_health) - 2)

	if typeof(duel) != TYPE_DICTIONARY:
		duel = {}

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		duel ["active"] = false
		gs.scenario_state ["bending_scenario_duel"] = duel

	if gs.bending_engine != null and gs.bending_engine.has_method("record_bending_duel_result"):
		gs.bending_engine.record_bending_duel_result(target, actor, {
			"source": "scenario_engine",
			"tournament": bool(duel.get("tournament_duel", false)),
			"tournament_id": str(duel.get("tournament_id", "")),
			"tournament_match_id": str(duel.get("tournament_match_id", "")),
			"tournament_division": str(duel.get("tournament_division", "")),
			"forfeit": true,
			"ko": false,
			"death": false,
			"duel": duel.duplicate(true)
		})

	return {
		"type": "scenario_commit_complete",
		"text": "I ended my bending duel with %s before it got worse." % target.first_name,
		"popup_title": "Bending Duel Ended",
		"popup_text": "You lower your stance and end the duel.\n\nMental Health: %d → %d" % [
			before_mental,
			int(actor.mental_health)
		],
		"popup_footer": "Tap anywhere to continue.",
		"opps": []
	}


func _bending_duel_best_element(person: Person) -> String:
	if person == null:
		return "bending"

	var bending_type: String = str(person.bending_type).strip_edges().to_lower()
	if bending_type != "avatar":
		return bending_type

	var best_element: String = "air"
	var best_level: int = -1
	for element in ["air", "water", "earth", "fire"]:
		var level: int = _bending_duel_level(person, element)
		if level > best_level:
			best_level = level
			best_element = element

	return best_element


func _bending_duel_level(person: Person, element: String) -> int:
	if person == null:
		return 0

	var clean_element: String = str(element).strip_edges().to_lower()
	if clean_element == "":
		return 0

	if gs != null and gs.bending_engine != null and gs.bending_engine.has_method("get_bending_level"):
		return int(gs.bending_engine.get_bending_level(person, clean_element))

	if typeof(person.bending_mastery) == TYPE_DICTIONARY:
		return int(person.bending_mastery.get(clean_element, 0))

	return 0


func _bending_duel_power(person: Person, element: String) -> int:
	if person == null:
		return 0

	var level: int = _bending_duel_level(person, element)
	return int(
		float(level) * 1.35 +
		float(person.health) * 0.22 +
		float(person.mental_health) * 0.18 +
		float(person.smarts) * 0.12 +
		float(person.imagination) * 0.1
	)


func _bending_duel_read_score(person: Person, element: String) -> int:
	if person == null:
		return 0

	var level: int = _bending_duel_level(person, element)
	return int(
		float(level) * 0.82 +
		float(person.smarts) * 0.38 +
		float(person.mental_health) * 0.18 +
		float(person.imagination) * 0.14
	)


func _bending_duel_opening_position(element: String) -> String:
	match str(element).strip_edges().to_lower():
		"air":
			return "light on their feet, circling outside your reach"
		"water":
			return "low and fluid, hands ready to redirect your pressure"
		"earth":
			return "rooted hard, reading the ground beneath you"
		"fire":
			return "forward and aggressive, testing your reaction time"
		_:
			return "guarded, patient, and reading your rhythm"


func _scenario_person_by_id(person_id: int) -> Person:
	if gs == null:
		return null

	if gs.player != null and int(gs.player.id) == int(person_id):
		return gs.player

	if typeof(gs.npcs) == TYPE_ARRAY:
		for raw_person in gs.npcs:
			if raw_person is Person and int(raw_person.id) == int(person_id):
				return raw_person

	return null
func _queue_bending_duel_round(actor: Person, preface_text: String = "") -> Dictionary:
	var duel: Dictionary = _rf_duel_dict(gs.scenario_state.get("bending_scenario_duel", {}))
	if duel.is_empty() or not bool(duel.get("active", false)):
		return {
			"type": "scenario_commit_complete",
			"text": "The bending duel ended before it could continue.",
			"popup_title": "Bending Duel",
			"popup_text": "The duel has already ended.",
			"popup_footer": "Tap anywhere to continue.",
			"opps": []
		}

	var target_name: String = str(duel.get("target_name", "your opponent")).strip_edges()
	var target_position: String = str(duel.get("target_position", "reading your stance")).strip_edges()
	var last_enemy_move: Dictionary = _rf_duel_dict(duel.get("last_enemy_move", {}))
	var lines: Array = []

	var effective_preface: String = str(preface_text).strip_edges()
	if effective_preface == "":
		effective_preface = str(duel.get("last_response_text", "")).strip_edges()
	if effective_preface != "":
		lines.append(effective_preface)

	lines.append("Round %d." % int(duel.get("round", 1)))
	lines.append("%s's position: %s." % [target_name, target_position])

	if not last_enemy_move.is_empty():
		lines.append("Last move they used: %s." % str(last_enemy_move.get("name", "unknown move")))
		lines.append("Damage they did to you: %d." % int(last_enemy_move.get("damage_dealt_to_player", 0)))

	return queue_external_scenario({
		"id": "bending_duel_round_%d_%d" % [int(gs.year), int(Time.get_ticks_msec())],
		"source": "scenario_engine",
		"category": "bending",
		"cooldown_key": "bending_scenario_duel_round",
		"resolver_method": "_resolve_bending_duel_choice",
		"panel_title": "BENDING DUEL — LIVE EXCHANGE",
		"footer_text": "Their skill and knowledge affect how well they read, defend, and counter you.",
		"prompt": "\n\n".join(lines),
		"combat_ui": _build_bending_duel_combat_ui(actor, duel),
		"choices": _build_bending_duel_choices(actor, duel)
	})
func _avatar_influence_duel_intervention(actor: Person, target: Person, duel: Dictionary, context: Dictionary = {}) -> Dictionary:
	if gs == null:
		return {}
	if not ("avatar_influence_engine" in gs):
		return {}
	if gs.avatar_influence_engine == null:
		return {}
	if not gs.avatar_influence_engine.has_method("maybe_intervene_in_duel"):
		return {}

	var packet: Dictionary = gs.avatar_influence_engine.maybe_intervene_in_duel(actor, target, duel, context)
	if typeof(packet) != TYPE_DICTIONARY:
		return {}
	if not bool(packet.get("triggered", false)):
		return packet

	var influence_log: Array = []
	if typeof(duel.get("avatar_influence_log", [])) == TYPE_ARRAY:
		influence_log = duel.get("avatar_influence_log", [])

	influence_log.append(packet.duplicate(true))
	while influence_log.size() > 8:
		influence_log.pop_front()

	duel ["avatar_influence_log"] = influence_log
	duel ["last_avatar_influence"] = packet.duplicate(true)

	return packet
func _resolve_spirit_world_choice(actor: Person, _scenario: Dictionary, choice: Dictionary, _committed: Dictionary) -> Dictionary:
	if gs == null or actor == null:
		return {}
	var choice_family: String = str(choice.get("choice_family", "")).strip_edges().to_lower()

	match choice_family:
		"leave":
			return {
				"type": "scenario_commit_complete",
				"text": "I left the Spirit World before asking for anything.",
				"popup_title": "Spirit World",
				"popup_text": "You let the vision close.\n\nThe four elements fade back into the ordinary world.",
				"popup_footer": "Tap anywhere to continue.",
				"opps": []
			}
		"knowledge":
			if gs.avatar_influence_engine != null and gs.avatar_influence_engine.has_method("go_to_spirit_world"):
				var knowledge_result: Dictionary = gs.avatar_influence_engine.go_to_spirit_world(actor, {
					"source": "spirit_world_scenario",
					"mode": "knowledge"
				})
				return {
					"type": "scenario_commit_complete",
					"text": str(knowledge_result.get("diary_text", "I asked the Spirit World for knowledge.")),
					"popup_title": str(knowledge_result.get("popup_title", "Spirit World Knowledge")),
					"popup_text": str(knowledge_result.get("popup_text", "The previous Avatars answered in fragments.")),
					"popup_footer": "Tap anywhere to continue.",
					"opps": []
				}
		"meditation":
			actor.mental_health = clamp(int(actor.mental_health) + 6, 0, 100)
			actor.satisfaction = clamp(int(actor.satisfaction) + 4, 0, 100)
			var willpower_growth_report: Dictionary = {}
			if gs != null and "willpower_engine" in gs and gs.willpower_engine != null:
				if gs.willpower_engine.has_method("apply_willpower_growth"):
					willpower_growth_report = gs.willpower_engine.apply_willpower_growth(actor, 3.5, {
						"source": "spirit_world_meditation",
						"scope": "bending",
						"reason": "meditating in the Spirit World"
					})
				elif gs.willpower_engine.has_method("ensure_willpower"):
					willpower_growth_report = gs.willpower_engine.ensure_willpower(actor, {
						"source": "spirit_world_meditation",
						"duel_scope": "bending"
					})
			var meditation_text: String = "I meditated in the Spirit World. The silence sharpened me, and the four elements felt closer than before."
			if gs.narrative_engine != null:
				gs.narrative_engine.log_event(actor, {
					"type": "text",
					"text": meditation_text,
					"life_diary_text": meditation_text,
					"source": "scenario_engine",
					"category": "bending",
					"event_name": "spirit_world_meditation",
					"memory_type": "spiritual",
					"emotion_tags": ["clarity", "discipline", "spirituality"],
					"willpower_growth_report": willpower_growth_report.duplicate(true)
				})
			return {
				"type": "scenario_commit_complete",
				"text": meditation_text,
				"popup_title": "Spirit World Meditation",
				"popup_text": "You sat between air, water, earth, and fire.\n\nYour mind steadied.\n\nMental Health increased.\nHappiness increased.\nWillpower increased.",
				"popup_footer": "Tap anywhere to continue.",
				"willpower_growth_report": willpower_growth_report.duplicate(true),
				"opps": []
			}
		"duel":
			var echo: Person = _create_spirit_world_avatar_echo(actor)
			if echo == null:
				return {
					"type": "scenario_commit_complete",
					"text": "The Spirit World duel could not begin because no echo formed.",
					"popup_title": "Spirit World",
					"popup_text": "The previous Avatar's echo flickered but never fully arrived.",
					"popup_footer": "Tap anywhere to continue.",
					"opps": []
				}
			var duel_scenario: Dictionary = {
				"id": "spirit_world_duel_%d_%d" % [int(actor.id), int(Time.get_ticks_msec())],
				"source": "scenario_engine",
				"resolver_owner": "scenario_engine",
				"category": "bending",
				"target_id": int(echo.id),
				"bending_duel_target_id": int(echo.id),
				"bending_duel_target_name": ("%s %s" % [echo.first_name, echo.last_name]).strip_edges(),
				"bending_duel_contract": {
					"schema": "eralife.spirit_world_bending_duel_contract",
					"version": 1,
					"source": "spirit_world",
					"uses_scenario_panel": true,
					"damage_reflects_on_stats": false,
					"world_feed_enabled": false
				}
			}
			return _begin_bending_duel_scenario(actor, echo, duel_scenario)
	return {
		"type": "scenario_commit_complete",
		"text": "The Spirit World choice dissolved before it could resolve.",
		"popup_title": "Spirit World",
		"popup_text": "The vision closed unexpectedly.",
		"popup_footer": "Tap anywhere to continue.",
		"opps": []
	}


func _create_spirit_world_avatar_echo(actor: Person) -> Person:
	if gs == null or actor == null:
		return null
	if gs.npc_factory == null:
		return null

	var echo: Person = gs.npc_factory.create_random_npc()
	if echo == null:
		return null

	var element: String = "air"
	if gs.bending_engine != null and gs.bending_engine.has_method("_bending_person_primary_element"):
		element = str(gs.bending_engine.call("_bending_person_primary_element", actor)).strip_edges().to_lower()

	if element not in ["air", "water", "earth", "fire"]:
		element = ["air", "water", "earth", "fire"].pick_random()

	echo.first_name = "Avatar"
	echo.last_name = "Echo"
	echo.age = max(24, int(actor.age) + 20)
	echo.alive = true
	echo.health = max(90, int(actor.health) + 20)
	echo.mental_health = 100
	echo.smarts = max(80, int(actor.smarts))
	echo.ambition = max(75, int(actor.ambition))
	echo.motivation = max(85, int(actor.motivation))
	echo.bending_type = "avatar"
	echo.bending_nation = str(actor.bending_nation)

	if gs.bending_engine != null and gs.bending_engine.has_method("force_bending_type"):
		gs.bending_engine.force_bending_type(echo, element, clamp(int(actor.bending_level) + 18, 35, 120))

	if "willpower_engine" in gs and gs.willpower_engine != null and gs.willpower_engine.has_method("ensure_willpower"):
		gs.willpower_engine.ensure_willpower(echo, {
			"source": "spirit_world_echo_spawn",
			"duel_scope": "bending"
		})

	if "npcs" in gs and typeof(gs.npcs) == TYPE_ARRAY and echo not in gs.npcs:
		gs.npcs.append(echo)

	return echo
func _resolve_bending_duel_turn(actor: Person, choice: Dictionary) -> Dictionary:
	var duel: Dictionary = _rf_duel_dict(gs.scenario_state.get("bending_scenario_duel", {}))
	if duel.is_empty() or not bool(duel.get("active", false)):
		return {
			"type": "scenario_commit_complete",
			"text": "The bending duel has already ended.",
			"popup_title": "Bending Duel",
			"popup_text": "The duel has already ended.",
			"popup_footer": "Tap anywhere to continue.",
			"opps": []
		}

	var target: Person = _scenario_person_by_id(int(duel.get("target_id", -1)))
	if target == null:
		duel ["active"] = false
		gs.scenario_state ["bending_scenario_duel"] = duel
		return {
			"type": "scenario_commit_complete",
			"text": "The bending duel ended because my opponent was no longer available.",
			"popup_title": "Bending Duel Ended",
			"popup_text": "Your opponent is no longer available.",
			"popup_footer": "Tap anywhere to continue.",
			"opps": []
		}

	var element: String = str(duel.get("player_element", "")).strip_edges().to_lower()
	if element == "" or element == "bending":
		element = _bending_duel_best_element(actor)
	if element == "":
		element = "bending"
	duel ["player_element"] = element

	var phase: String = str(duel.get("phase", "player_action")).strip_edges().to_lower()
	if phase == "defense_response":
		return _resolve_bending_duel_defense_response(actor, target, duel, choice)
	var choice_family: String = str(choice.get("choice_family", "attack")).strip_edges().to_lower()
	if bool(choice.get("time_loop_duel_choice", false)) or choice_family == "time_loop" or str(choice.get("id", "")) == "time_loop_bargain":
		duel = _duel_apply_time_loop_bargain(actor, target, duel, "bending", choice)
		gs.scenario_state ["bending_scenario_duel"] = duel
		return _queue_bending_duel_round(actor, _duel_time_loop_preface(duel))

	var player_damage: int = 0
	var player_guard: int = 0
	var read_bonus: int = int(duel.get("read_bonus", 0))
	var action_hit: bool = true
	var avatar_attack_line: String = ""

	match choice_family:
		"defend":
			player_guard = _bending_duel_player_guard(actor, duel, choice)
			read_bonus += 2
		"read":
			player_guard = int(float(_bending_duel_player_guard(actor, duel, choice)) * 0.55)
			read_bonus += 8
		"escape":
			duel ["active"] = false
			gs.scenario_state ["bending_scenario_duel"] = duel
			return _finish_bending_duel_concession(actor, target, duel)
		_:
			var attack_packet: Dictionary = _bending_duel_player_attack_packet(actor, duel, choice)
			action_hit = bool(attack_packet.get("hit", true))
			player_damage = int(attack_packet.get("damage", 0))

			var avatar_attack_influence: Dictionary = _avatar_influence_duel_intervention(actor, target, duel, {
				"phase": "player_attack",
				"choice": choice.duplicate(true),
				"attack_packet": attack_packet.duplicate(true)
			})

			if bool(avatar_attack_influence.get("triggered", false)):
				player_damage += int(avatar_attack_influence.get("damage_bonus", 0))
				read_bonus += int(avatar_attack_influence.get("read_bonus", 0))

				if bool(avatar_attack_influence.get("force_hit", false)):
					action_hit = true
					attack_packet ["hit"] = true

				attack_packet ["avatar_influence"] = avatar_attack_influence.duplicate(true)
				attack_packet ["name"] = str(avatar_attack_influence.get("attack_name", attack_packet.get("name", "Avatar-assisted strike")))
				attack_packet ["damage"] = player_damage
				avatar_attack_line = str(avatar_attack_influence.get("text", ""))

			duel ["pending_player_attack"] = attack_packet.duplicate(true)

	var enemy_move: Dictionary = _bending_duel_enemy_move_packet(target, duel, choice_family, read_bonus)
	var enemy_guard: int = int(enemy_move.get("guard", 0))
	var dealt: int = 0

	if player_damage > 0 and action_hit:
		dealt = max(0, player_damage - enemy_guard)

	var target_hp_before: int = int(duel.get("target_hp", 1))
	var target_hp: int = max(0, target_hp_before - dealt)
	var one_shot_target_ko: bool = target_hp_before >= 70 and dealt >= target_hp_before and target_hp <= 0 and player_damage > 0 and action_hit

	enemy_move ["damage_taken_from_player"] = dealt
	enemy_move ["damage_blocked_by_enemy"] = max(0, player_damage - dealt)

	duel ["last_player_attack_target_hp_before"] = target_hp_before
	duel ["last_player_attack_damage_dealt"] = dealt
	duel ["player_inflicted_knockout"] = one_shot_target_ko

	duel ["target_hp"] = target_hp
	duel ["damage_to_target"] = int(duel.get("damage_to_target", 0)) + dealt
	duel ["pending_enemy_move"] = enemy_move.duplicate(true)
	duel ["pending_player_guard"] = player_guard
	duel ["last_enemy_move"] = enemy_move.duplicate(true)
	duel ["target_position"] = str(enemy_move.get("position_after", "preparing their next attack"))
	duel ["read_bonus"] = clamp(read_bonus - 2, 0, 18)
	duel = _bending_duel_register_live_adaptation(duel, choice_family, dealt, 0)
	var player_move_name: String = _bending_duel_attack_name_from_packet(_rf_duel_dict(duel.get("pending_player_attack", {})), choice, element)
	if player_damage > 0:
		duel ["last_player_move"] = player_move_name
		duel ["last_player_move_name"] = player_move_name

	var response_text: String = ""
	if player_damage > 0:
		if dealt > 0:
			response_text = "You landed %s for %d damage." % [player_move_name, dealt]
		elif not action_hit:
			response_text = "%s missed. Their read was sharper than your accuracy." % player_move_name
		else:
			response_text = "They absorbed %s and guarded the impact." % player_move_name
	else:
		response_text = "You hold your stance and read the incoming pressure."

	if avatar_attack_line != "":
		response_text += "\n\n%s" % avatar_attack_line

	if target_hp <= 0:
		var target_willpower_report: Dictionary = _duel_apply_willpower_outcome_resistance(target, actor, duel, "bending", "target")
		if bool(target_willpower_report.get("triggered", false)):
			return _queue_bending_duel_target_last_stand_response(actor, target, duel, target_willpower_report)

		gs.scenario_state ["bending_scenario_duel"] = duel
		return _finish_bending_duel_victory(actor, target, duel)

	duel ["phase"] = "defense_response"
	response_text += "\n\n%s begins %s.\n\nChoose how you answer it." % [
		str(duel.get("target_name", "Your opponent")),
		str(enemy_move.get("name", "a bending counter"))
	]

	duel ["last_response_text"] = response_text
	gs.scenario_state ["bending_scenario_duel"] = duel
	return _queue_bending_duel_round(actor, response_text)
func _resolve_bending_duel_defense_response(actor: Person, target: Person, duel: Dictionary, choice: Dictionary) -> Dictionary:
	var choice_family: String = str(choice.get("choice_family", "response_defend")).strip_edges().to_lower()
	var enemy_move: Dictionary = _rf_duel_dict(duel.get("pending_enemy_move", {}))
	if enemy_move.is_empty():
		duel ["phase"] = "player_action"
		gs.scenario_state ["bending_scenario_duel"] = duel
		return _queue_bending_duel_round(actor, "The exchange reset before their attack could land.")

	var enemy_damage: int = int(enemy_move.get("damage", 0))
	var response_guard: int = int(duel.get("pending_player_guard", 0))
	var counter_damage: int = 0
	var counter_hit: bool = true
	var escaped: bool = false
	var avatar_defense_line: String = ""

	match choice_family:
		"response_defend":
			response_guard += _bending_duel_player_guard(actor, duel, choice)
		"response_counter":
			var counter_packet: Dictionary = _bending_duel_player_attack_packet(actor, duel, choice)
			counter_damage = int(round(float(counter_packet.get("damage", 0)) * 0.72))
			counter_hit = bool(counter_packet.get("hit", true))
			response_guard += int(float(_bending_duel_player_guard(actor, duel, choice)) * 0.35)
		"response_read":
			response_guard += int(float(_bending_duel_player_guard(actor, duel, choice)) * 0.62)
			duel ["read_bonus"] = clamp(int(duel.get("read_bonus", 0)) + 6, 0, 24)
		"response_escape":
			var escape_accuracy: int = 35
			if gs.bending_engine != null and gs.bending_engine.has_method("get_bending_combat_stat"):
				escape_accuracy += int(float(gs.bending_engine.get_bending_combat_stat(actor, "evasion")) * 0.42)
			escaped = (randi() % 100) < clamp(escape_accuracy, 12, 88)
			response_guard += int(float(_bending_duel_player_guard(actor, duel, choice)) * 0.48)
		_:
			response_guard += _bending_duel_player_guard(actor, duel, choice)

	if escaped:
		enemy_damage = int(round(float(enemy_damage) * 0.35))

	var avatar_defense_influence: Dictionary = _avatar_influence_duel_intervention(actor, target, duel, {
		"phase": "last_health_defense" if int(duel.get("player_hp", 1)) <= max(10, int(float(duel.get("player_hp_max", 1)) * 0.28)) else "defense_response",
		"choice": choice.duplicate(true),
		"enemy_move": enemy_move.duplicate(true)
	})

	if bool(avatar_defense_influence.get("triggered", false)):
		response_guard += int(avatar_defense_influence.get("guard_bonus", 0))
		counter_damage += int(avatar_defense_influence.get("damage_bonus", 0))
		duel ["read_bonus"] = clamp(int(duel.get("read_bonus", 0)) + int(avatar_defense_influence.get("read_bonus", 0)), 0, 30)
		avatar_defense_line = str(avatar_defense_influence.get("text", ""))



	var taken: int = max(0, enemy_damage - response_guard)
	var target_hp_before: int = int(duel.get("target_hp", 1))
	var target_hp: int = target_hp_before
	var counter_dealt: int = 0

	if counter_damage > 0 and counter_hit:
		counter_dealt = max(0, counter_damage - int(float(enemy_move.get("guard", 0)) * 0.4))
		target_hp = max(0, target_hp - counter_dealt)

	var player_hp_before: int = int(duel.get("player_hp", 1))
	var player_hp: int = max(0, player_hp_before - taken)
	var screen_damage_packet: Dictionary = _bending_duel_screen_damage_packet(duel, enemy_move, taken, "defense_response")
	duel ["last_screen_damage_packet"] = screen_damage_packet.duplicate(true)
	duel ["last_counter_target_hp_before"] = target_hp_before
	duel ["last_counter_damage_dealt"] = counter_dealt
	duel ["last_enemy_attack_player_hp_before"] = player_hp_before
	duel ["last_enemy_attack_damage_dealt"] = taken
	duel ["player_inflicted_knockout"] = target_hp_before >= 70 and counter_dealt >= target_hp_before and target_hp <= 0 and counter_damage > 0 and counter_hit
	duel ["target_inflicted_knockout"] = player_hp_before >= 70 and taken >= player_hp_before and player_hp <= 0 and enemy_damage > 0

	enemy_move ["damage_dealt_to_player"] = taken
	enemy_move ["damage_blocked_by_player"] = max(0, enemy_damage - taken)
	enemy_move ["counter_damage_taken"] = counter_dealt

	duel ["player_hp"] = player_hp
	duel ["target_hp"] = target_hp
	duel ["damage_to_player"] = int(duel.get("damage_to_player", 0)) + taken
	duel ["damage_to_target"] = int(duel.get("damage_to_target", 0)) + counter_dealt
	duel = _bending_duel_register_live_adaptation(duel, choice_family, counter_dealt, taken)
	duel ["last_enemy_move"] = enemy_move.duplicate(true)
	duel ["pending_enemy_move"] = {}
	duel ["pending_player_attack"] = {}
	duel ["pending_player_guard"] = 0
	duel ["phase"] = "player_action"

	var response_text: String = "%s committed to %s." % [
		str(duel.get("target_name", "Your opponent")),
		str(enemy_move.get("name", "a bending attack"))
	]

	if taken > 0:
		response_text += "\n\nYou took %d damage." % taken
	else:
		response_text += "\n\nYou shut the attack down clean."

	if counter_dealt > 0:
		response_text += "\nYour counter landed for %d damage." % counter_dealt
	elif choice_family == "response_counter":
		response_text += "\nYour counter did not break their stance."

	if escaped:
		response_text += "\nYou slipped away from the worst of it."

	if avatar_defense_line != "":
		response_text += "\n\n%s" % avatar_defense_line

	response_text += "\n\nTheir position now: %s." % str(duel.get("target_position", "watching you"))

	duel ["last_response_text"] = response_text

	if target_hp <= 0:
		var target_willpower_report: Dictionary = _duel_apply_willpower_outcome_resistance(target, actor, duel, "bending", "target")
		if bool(target_willpower_report.get("triggered", false)):
			return _queue_bending_duel_target_last_stand_response(actor, target, duel, target_willpower_report)

		gs.scenario_state ["bending_scenario_duel"] = duel
		return _finish_bending_duel_victory(actor, target, duel)

	if player_hp <= 0:
		gs.scenario_state ["bending_scenario_duel"] = duel
		return _finish_bending_duel_loss(actor, target, duel)

	duel ["round"] = int(duel.get("round", 1)) + 1
	gs.scenario_state ["bending_scenario_duel"] = duel
	return _queue_bending_duel_round(actor, response_text)

func _apply_reality_fusion_duel_injury(actor: Person, duel: Dictionary, outcome: String) -> Dictionary:
	if actor == null:
		return {}

	var clean_outcome: String = str(outcome).strip_edges().to_lower()
	var player_hp: int = max(0, int(duel.get("player_hp", int(actor.health))))
	var player_hp_max: int = max(1, int(duel.get("player_hp_max", max(1, int(actor.health)))))
	var round_number: int = max(1, int(duel.get("round", 1)))
	var total_damage: int = max(0, int(duel.get("total_damage_to_player", 0)))
	var largest_hit: int = max(0, int(duel.get("largest_hit_to_player", 0)))

	var remaining_ratio: float = clamp(float(player_hp) / float(player_hp_max), 0.0, 1.0)
	var severity: float = 1.0 - remaining_ratio
	severity += clamp(float(total_damage) / float(max(1, player_hp_max)) * 0.35, 0.0, 0.45)
	severity += clamp(float(largest_hit) / float(max(1, player_hp_max)) * 0.2, 0.0, 0.25)

	if clean_outcome == "lost":
		severity += 0.35
	elif clean_outcome == "escaped":
		severity += clamp(float(round_number - 1) * 0.05, 0.0, 0.3)

	severity = clamp(severity, 0.1, 1.0)

	var health_loss: int = int(round(lerp(4.0, 48.0, severity)))
	var mental_loss: int = int(round(lerp(3.0, 30.0, severity)))
	var satisfaction_loss: int = int(round(lerp(2.0, 28.0, severity)))
	var looks_loss: int = int(round(lerp(0.0, 12.0, max(0.0, severity - 0.35))))

	var before: Dictionary = {
		"health": int(actor.health),
		"mental_health": int(actor.mental_health),
		"satisfaction": int(actor.satisfaction),
		"looks": int(actor.looks)
	}

	actor.health = max(1, int(actor.health) - health_loss)
	actor.mental_health = max(0, int(actor.mental_health) - mental_loss)
	actor.satisfaction = max(0, int(actor.satisfaction) - satisfaction_loss)
	if looks_loss > 0:
		actor.looks = max(0, int(actor.looks) - looks_loss)

	var after: Dictionary = {
		"health": int(actor.health),
		"mental_health": int(actor.mental_health),
		"satisfaction": int(actor.satisfaction),
		"looks": int(actor.looks)
	}

	var severity_label: String = "shaken"
	if severity >= 0.82:
		severity_label = "mangled"
	elif severity >= 0.62:
		severity_label = "badly beaten"
	elif severity >= 0.38:
		severity_label = "hurt"

	return {
		"outcome": clean_outcome,
		"severity": severity,
		"severity_label": severity_label,
		"round": round_number,
		"before": before,
		"after": after,
		"losses": {
			"health": health_loss,
			"mental_health": mental_loss,
			"satisfaction": satisfaction_loss,
			"looks": looks_loss
		},
		"popup_text": "You came back %s.\n\nHealth: %d → %d\nMental: %d → %d\nHappiness: %d → %d" % [
			severity_label,
			int(before.get("health", 0)),
			int(after.get("health", 0)),
			int(before.get("mental_health", 0)),
			int(after.get("mental_health", 0)),
			int(before.get("satisfaction", 0)),
			int(after.get("satisfaction", 0))
		],
		"diary_suffix": "I came back %s. My health fell from %d to %d, my mental health fell from %d to %d, and my happiness fell from %d to %d." % [
			severity_label,
			int(before.get("health", 0)),
			int(after.get("health", 0)),
			int(before.get("mental_health", 0)),
			int(after.get("mental_health", 0)),
			int(before.get("satisfaction", 0)),
			int(after.get("satisfaction", 0))
		]
	}
func _commit_reality_fusion_duel_aftermath(actor: Person, diary_text: String, world_text: String, event_name: String) -> void:
	if gs == null or actor == null:
		return

	var clean_diary: String = str(diary_text).strip_edges()
	if clean_diary != "":
		if typeof(actor.memories) == TYPE_ARRAY and clean_diary not in actor.memories:
			actor.memories.append(clean_diary)
		if gs.narrative_engine != null:
			gs.narrative_engine.log_event(actor, {
				"type": "text",
				"text": clean_diary,
				"event_name": event_name,
				"category": "reality_fusion",
				"source": "scenario_engine"
			})

	var clean_world: String = str(world_text).strip_edges()
	if clean_world != "" and gs.has_method("push_world_feed"):
		gs.push_world_feed(clean_world, {
			"category": "reality_fusion",
			"event_name": event_name,
			"personally_relevant": actor == gs.player,
			"source": "scenario_engine",
			"npc_id": int(actor.id)
		})
func _person_label_for_world_feed(actor: Person) -> String:
	if actor == null:
		return "Someone"
	var label: String = ("%s %s" % [str(actor.first_name), str(actor.last_name)]).strip_edges()
	if label == "":
		label = str(actor.name).strip_edges()
	if label == "":
		label = "Someone"
	return label

func _reality_fusion_import_ally_from_context(context: Dictionary, forced: bool = false) -> Dictionary:
	if gs == null:
		return {
			"success": false,
			"reason": "GameState missing for Reality Fusion ally import."
		}

	var path: String = str(context.get("path", "")).strip_edges()
	var contract: Dictionary = _rf_duel_dict(context.get("contract", {}))
	if contract.is_empty():
		contract = {
			"schema": "eralife.reality_fusion_contract",
			"version": 1,
			"id": "scenario_engine_friend_person",
			"mode": "friend_person",
			"merge_policy": {
				"relationship_scope": [],
				"friend_link": "bidirectional",
				"root_person_id": -1,
				"lineage_strategy": "none",
				"id_strategy": "remap_safe",
				"conflict_resolution": "parallel_identity",
				"world_integration": {
					"register_npcs": true,
					"rebuild_index": true,
					"ensure_lineage": false
				}
			}
		}

	contract ["mode"] = "friend_person"
	contract ["forced_crossover"] = forced

	if not gs.has_method("fuse_reality_from_save"):
		return {
			"success": false,
			"reason": "GameState does not expose fuse_reality_from_save()."
		}

	return gs.fuse_reality_from_save(path, contract)


func _reality_fusion_ally_context_from_choice(scenario: Dictionary, choice: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	out ["path"] = str(choice.get("reality_fusion_path", scenario.get("reality_fusion_path", ""))).strip_edges()
	out ["label"] = str(choice.get("reality_fusion_label", scenario.get("reality_fusion_label", ""))).strip_edges()
	out ["contract"] = _rf_duel_dict(choice.get("reality_fusion_contract", scenario.get("reality_fusion_contract", {})))
	out ["source_player"] = _rf_duel_dict(choice.get("reality_fusion_source_player", scenario.get("reality_fusion_source_player", {})))
	return out


func _reality_fusion_context_choice_payload(choice_id: String, label: String, journal_text: String, context: Dictionary) -> Dictionary:
	return {
		"id": choice_id,
		"label": label,
		"journal_text": journal_text,
		"reality_fusion_path": str(context.get("path", "")),
		"reality_fusion_label": str(context.get("label", "")),
		"reality_fusion_contract": _rf_duel_dict(context.get("contract", {})),
		"reality_fusion_source_player": _rf_duel_dict(context.get("source_player", {}))
	}


func _reality_fusion_ally_acceptance_roll(actor: Person, source_player: Dictionary) -> Dictionary:
	var source_name: String = _reality_fusion_ally_source_name(source_player)
	var player_fame: float = float(actor.fame)
	var player_smarts: float = float(actor.smarts)
	var source_smarts: float = _reality_fusion_source_stat(source_player, "smarts", 50.0)
	var source_power: float = float(_reality_fusion_source_power_score(source_player))

	var chance: float = 0.34
	chance += clamp(player_fame / 300.0, 0.0, 0.22)
	chance += clamp((player_smarts - source_smarts) / 260.0, -0.12, 0.14)

	if source_power >= 80.0:
		chance -= 0.14
	elif source_power >= 55.0:
		chance -= 0.08

	chance = clamp(chance, 0.08, 0.78)
	var roll: float = randf()
	var accepted: bool = roll < chance

	var reason: String = "%s studies the portal and says no." % source_name
	if accepted:
		reason = "%s studies you, then agrees to cross over." % source_name
	elif source_power >= 80.0:
		reason = "%s says no because they can feel the kidnapping behind your question." % source_name
	elif player_fame > 70:
		reason = "%s recognizes your name, but still refuses to abandon their own timeline." % source_name

	return {
		"accepted": accepted,
		"chance": chance,
		"roll": roll,
		"reason": reason
	}


func _reality_fusion_source_has_duel_powers(source_player: Dictionary) -> bool:
	var profile: Dictionary = _rf_duel_dict(source_player.get("power_profile", {}))
	if bool(profile.get("has_power", false)):
		return true

	var bending_type: String = str(source_player.get("bending_type", "none")).strip_edges().to_lower()
	if bending_type != "" and bending_type != "none":
		return true

	if _max_number_in_rf_dictionary(_rf_duel_dict(source_player.get("bending_mastery", {}))) > 0.0:
		return true

	if bool(source_player.get("avatar_state_unlocked", false)):
		return true

	for raw_trait in _rf_duel_array(source_player.get("traits", [])):
		var trait_text: String = str(raw_trait).strip_edges().to_lower()
		if trait_text.find("vampire") >= 0 \
or trait_text.find("avatar") >= 0 \
or trait_text.find("super") >= 0 \
or trait_text.find("cosmic") >= 0 \
or trait_text.find("reality") >= 0:
			return true

	return false


func _reality_fusion_player_power_actions(actor: Person) -> Array:
	var out: Array = []
	if actor == null or gs == null:
		return out

	for item_action in _reality_fusion_inventory_duel_actions(actor):
		if typeof(item_action) != TYPE_DICTIONARY:
			continue
		out.append(item_action)

	for weapon_action in _reality_fusion_weapon_duel_actions(actor):
		if typeof(weapon_action) != TYPE_DICTIONARY:
			continue
		out.append(weapon_action)

	if gs.bending_engine != null:
		var bending_packets: Variant = []
		if gs.bending_engine.has_method("get_unlocked_bending_combat_abilities"):
			bending_packets = gs.bending_engine.get_unlocked_bending_combat_abilities(actor, "", {
				"include_cooldown": false
			})
		elif gs.bending_engine.has_method("get_available_bending_abilities"):
			bending_packets = gs.bending_engine.get_available_bending_abilities(actor)

		if typeof(bending_packets) == TYPE_ARRAY:
			for raw_ability in bending_packets:
				if typeof(raw_ability) != TYPE_DICTIONARY:
					continue

				var ability: Dictionary = raw_ability.duplicate(true)
				if not bool(ability.get("unlocked", false)):
					continue
				if bool(ability.get("on_cooldown", false)):
					continue

				var ability_type: String = str(ability.get("type", "attack")).strip_edges().to_lower()
				if ability_type not in ["attack", "defense", "control", "escape"]:
					continue

				var family: String = "attack"
				if ability_type in ["defense", "escape"]:
					family = "defend"

				var ability_name: String = str(ability.get("name", "Bending")).strip_edges()
				if ability_name == "":
					ability_name = "Bending"

				var ability_element: String = str(ability.get("element", "")).strip_edges().to_lower()
				var ability_level: int = int(ability.get("current_level", ability.get("level", 0)))

				out.append({
					"id": "reality_fusion_bending_%s_%s_%d" % [family, str(ability.get("id", "bending")), int(Time.get_ticks_msec())],
					"label": "Use %s" % ability_name,
					"journal_text": "I used %s during a Reality Fusion duel." % ability_name,
					"choice_family": family,
					"power_source": "bending",
					"ability_id": str(ability.get("id", "")),
					"ability_name": ability_name,
					"ability_element": ability_element,
					"ability_type": ability_type,
					"ability_level": ability_level,
					"button_theme": "bending_ability",
					"disabled": false
				})

	var adapter_names: Array = [
		"artifacts_engine",
		"belongings_engine",
		"power_engine",
		"magic_engine",
		"ability_engine",
		"superpower_engine"
	]

	for adapter_name in adapter_names:
		var engine = null
		if gs.has_method("get"):
			engine = gs.get(adapter_name)

		if engine == null:
			continue

		if not engine.has_method("get_reality_fusion_duel_actions"):
			continue

		var packets: Variant = engine.call("get_reality_fusion_duel_actions", actor, {
			"source": "reality_fusion_ally_duel",
			"theme": "reality_fusion",
		})

		if typeof(packets) != TYPE_ARRAY:
			continue

		for raw_packet in packets:
			if typeof(raw_packet) != TYPE_DICTIONARY:
				continue

			var packet: Dictionary = raw_packet.duplicate(true)
			packet ["reality_fusion_ally_duel_choice"] = true
			packet ["disabled"] = bool(packet.get("disabled", false))
			out.append(packet)

	return out

func _reality_fusion_inventory_duel_actions(actor: Person) -> Array:
	var out: Array = []
	if gs == null or actor == null or gs.belongings_engine == null:
		return out
	if not gs.belongings_engine.has_method("get_all_items_flat"):
		return out

	var items: Array = gs.belongings_engine.get_all_items_flat(actor)
	for raw_item in items:
		if typeof(raw_item) != TYPE_DICTIONARY:
			continue

		var item: Dictionary = raw_item
		var item_name: String = str(item.get("display_name", item.get("name", "Item"))).strip_edges()
		if item_name == "":
			item_name = "Item"

		if _duel_item_is_time_stone(item):
			continue

		var category: String = str(item.get("category", item.get("type", "Inventory"))).strip_edges()
		var category_lower: String = category.to_lower()
		var value_score: int = int(item.get("value", item.get("price", item.get("worth", 0))))
		var power_bonus: int = clamp(int(round(float(value_score) / 2500.0)), 0, 35)

		var power_source: String = "inventory"
		var button_theme: String = "inventory_action"
		var choice_family: String = "attack"

		if category_lower.find("artifact") >= 0:
			power_source = "artifact"
			button_theme = "artifact_action"
		elif category_lower.find("weapon") >= 0:
			power_source = "weapon"
			button_theme = "weapon_action"
		elif category_lower.find("heirloom") >= 0:
			power_source = "artifact"
			button_theme = "artifact_action"

		out.append({
			"id": "reality_fusion_inventory_%s_%s" % [str(item.get("id", item_name)).to_lower().replace(" ", "_"), str(Time.get_ticks_msec())],
			"label": "Use %s" % item_name,
			"journal_text": "I used %s during a Reality Fusion duel." % item_name,
			"reality_fusion_ally_duel_choice": true,
			"choice_family": choice_family,
			"power_source": power_source,
			"button_theme": button_theme,
			"item": item.duplicate(true),
			"item_name": item_name,
			"item_category": category,
			"power": 18 + power_bonus + randi_range(0, 16),
			"guard": 12 + int(round(float(power_bonus) * 0.65)) + randi_range(0, 12),
			"disabled": false
		})

	return out
func _reality_fusion_weapon_duel_actions(actor: Person) -> Array:
	var out: Array = []
	if gs == null or actor == null:
		return out
	if not ("weapons_engine" in gs) or gs.weapons_engine == null:
		return out
	if not gs.weapons_engine.has_method("get_inventory"):
		return out

	var weapons: Array = gs.weapons_engine.get_inventory()
	for raw_weapon in weapons:
		var weapon_trait: String = str(raw_weapon).strip_edges()
		if weapon_trait == "":
			continue

		var weapon_name: String = weapon_trait
		if weapon_name.begins_with("Weapon_"):
			weapon_name = weapon_name.substr(7)

		out.append({
			"id": "reality_fusion_weapon_%s" % weapon_name.to_lower().replace(" ", "_"),
			"label": "Use %s" % weapon_name,
			"journal_text": "I used %s during a Reality Fusion duel." % weapon_name,
			"reality_fusion_ally_duel_choice": true,
			"choice_family": "attack",
			"power_source": "weapon",
			"button_theme": "weapon_action",
			"weapon_name": weapon_name,
			"power": randi_range(24, 54),
			"guard": randi_range(8, 22),
			"disabled": false
		})

	return out
func _reality_fusion_player_action_power(actor: Person, choice: Dictionary) -> int:
	var power_source: String = str(choice.get("power_source", "physical")).strip_edges().to_lower()
	match power_source:
		"bending":
			var level: int = clamp(int(choice.get("ability_level", 0)), 0, 100)
			var ability_type: String = str(choice.get("ability_type", "attack")).strip_edges().to_lower()
			var base_power: int = 12 + int(float(level) * 0.54) + randi_range(0, 12)
			if ability_type == "control":
				return base_power + 5
			if ability_type == "attack":
				return base_power + 9
			return max(8, int(float(base_power) * 0.55))
		"artifact", "cosmic", "magic", "superpower", "weapon", "inventory":
			return int(choice.get("power", randi_range(20, 42)))
		_:
			var body_bonus: int = int((float(actor.health) + float(actor.looks)) / 18.0)
			return randi_range(12, 24) + body_bonus


func _reality_fusion_player_guard_power(actor: Person, choice: Dictionary) -> int:
	var power_source: String = str(choice.get("power_source", "physical")).strip_edges().to_lower()
	match power_source:
		"bending":
			var level: int = clamp(int(choice.get("ability_level", 0)), 0, 100)
			return 10 + int(float(level) * 0.45) + randi_range(0, 10)
		"artifact", "cosmic", "magic", "superpower", "weapon", "inventory":
			return int(choice.get("guard", randi_range(18, 36)))
		_:
			return randi_range(8, 18) + int(float(actor.health) / 16.0)

func _reality_fusion_source_move_packet(source_player: Dictionary, duel: Dictionary, player_choice_family: String = "attack") -> Dictionary:
	var source_power: int = int(duel.get("enemy_power", _reality_fusion_source_power_score(source_player)))
	var bending_type: String = str(source_player.get("bending_type", "none")).strip_edges().to_lower()
	var has_avatar_state: bool = bool(source_player.get("avatar_state_unlocked", false))
	var traits: Array = _rf_duel_array(source_player.get("traits", []))
	var move_pool: Array = []

	if has_avatar_state:
		move_pool.append({
			"name": "Avatar State pressure wave",
			"position_after": "floating above the portal with all elements orbiting them",
			"damage_bonus": 18,
			"guard_bonus": 10
		})

	if bending_type != "" and bending_type != "none":
		move_pool.append({
			"name": "%s bending counter" % bending_type.capitalize(),
			"position_after": "side-stepped with their element between you and the breach",
			"damage_bonus": 10,
			"guard_bonus": 8
		})

	for raw_trait in traits:
		var trait_text: String = str(raw_trait).strip_edges().to_lower()
		if trait_text.find("vampire") >= 0:
			move_pool.append({
				"name": "vampiric blur strike",
				"position_after": "behind your shoulder with impossible speed",
				"damage_bonus": 13,
				"guard_bonus": 5
			})
		elif trait_text.find("cosmic") >= 0 or trait_text.find("reality") >= 0:
			move_pool.append({
				"name": "reality-folding counter",
				"position_after": "half-visible between two overlapping timelines",
				"damage_bonus": 16,
				"guard_bonus": 11
			})
		elif trait_text.find("super") >= 0:
			move_pool.append({
				"name": "superhuman burst",
				"position_after": "planted forward with pressure cracking the ground",
				"damage_bonus": 11,
				"guard_bonus": 6
			})

	if move_pool.is_empty():
		move_pool.append({
			"name": "timeline counterpunch",
			"position_after": "low guard, watching your hips and shoulders",
			"damage_bonus": 0,
			"guard_bonus": 0
		})
		move_pool.append({
			"name": "portal-side feint",
			"position_after": "angled beside the breach, baiting you to overcommit",
			"damage_bonus": 3,
			"guard_bonus": 5
		})

	var packet: Dictionary = move_pool [randi_range(0, move_pool.size() - 1)].duplicate(true)
	var base_damage: int = randi_range(10, 22) + int(float(source_power) * 0.24)
	var base_guard: int = randi_range(4, 14) + int(float(source_power) * 0.14)

	if str(player_choice_family).strip_edges().to_lower() == "defend":
		base_damage = int(round(float(base_damage) * 0.72))
		base_guard += 5
	elif str(player_choice_family).strip_edges().to_lower() == "escape":
		base_damage += 6
		packet ["position_after"] = "chasing the edge of your escape route"

	packet ["damage"] = max(8, base_damage + int(packet.get("damage_bonus", 0)))
	packet ["guard"] = max(0, base_guard + int(packet.get("guard_bonus", 0)))
	packet ["position_before"] = str(duel.get("enemy_position", "reading the portal"))
	packet ["source_power"] = source_power
	return packet
func _reality_fusion_source_attack_power(source_player: Dictionary, duel: Dictionary) -> int:
	var source_power: int = int(duel.get("enemy_power", _reality_fusion_source_power_score(source_player)))
	var base_attack: int = randi_range(10, 22) + int(float(source_power) * 0.24)
	if bool(source_player.get("avatar_state_unlocked", false)):
		base_attack += randi_range(8, 18)
	return max(8, base_attack)


func _reality_fusion_source_guard_power(source_player: Dictionary, duel: Dictionary) -> int:
	var source_power: int = int(duel.get("enemy_power", _reality_fusion_source_power_score(source_player)))
	return max(0, randi_range(4, 14) + int(float(source_power) * 0.14))


func _reality_fusion_source_power_score(source_player: Dictionary) -> int:
	var stats_pressure: float = (
		_reality_fusion_source_stat(source_player, "health", 50.0) +
		_reality_fusion_source_stat(source_player, "mental_health", 50.0) +
		_reality_fusion_source_stat(source_player, "smarts", 50.0) +
		_reality_fusion_source_stat(source_player, "fame", 0.0)
	) / 4.0

	var bending_power: float = _max_number_in_rf_dictionary(_rf_duel_dict(source_player.get("bending_mastery", {})))
	if str(source_player.get("bending_type", "none")).strip_edges().to_lower() == "avatar":
		bending_power += 20.0
	if bool(source_player.get("avatar_state_unlocked", false)):
		bending_power += 30.0

	var trait_bonus: float = 0.0
	for raw_trait in _rf_duel_array(source_player.get("traits", [])):
		var trait_text: String = str(raw_trait).strip_edges().to_lower()
		if trait_text.find("vampire") >= 0:
			trait_bonus += 18.0
		elif trait_text.find("cosmic") >= 0 or trait_text.find("reality") >= 0:
			trait_bonus += 22.0
		elif trait_text.find("super") >= 0:
			trait_bonus += 14.0

	return int(round(clamp(stats_pressure + bending_power + trait_bonus, 1.0, 180.0)))


func _reality_fusion_player_power_score(actor: Person) -> int:
	if actor == null:
		return 50

	var score: float = (float(actor.health) + float(actor.mental_health) + float(actor.smarts) + float(actor.fame)) / 4.0

	if gs != null and gs.bending_engine != null and gs.bending_engine.has_method("get_available_bending_abilities"):
		for raw_ability in gs.bending_engine.get_available_bending_abilities(actor):
			if typeof(raw_ability) != TYPE_DICTIONARY:
				continue
			var ability: Dictionary = raw_ability
			if bool(ability.get("unlocked", false)):
				score += float(ability.get("current_level", ability.get("level", 0))) * 0.08

	return int(round(clamp(score, 1.0, 180.0)))


func _reality_fusion_source_stat(source_player: Dictionary, stat_name: String, fallback: float = 0.0) -> float:
	var stats: Dictionary = _rf_duel_dict(source_player.get("stats", {}))
	if stats.has(stat_name):
		return float(stats.get(stat_name, fallback))
	if source_player.has(stat_name):
		return float(source_player.get(stat_name, fallback))
	return fallback


func _reality_fusion_ally_source_name(source_player: Dictionary) -> String:
	var source_name: String = str(source_player.get("name", "")).strip_edges()
	if source_name != "":
		return source_name

	var first_name: String = str(source_player.get("first_name", "")).strip_edges()
	var last_name: String = str(source_player.get("last_name", "")).strip_edges()
	source_name = ("%s %s" % [first_name, last_name]).strip_edges()
	if source_name != "":
		return source_name

	return "Saved Character"


func _max_number_in_rf_dictionary(data: Dictionary) -> float:
	var highest: float = 0.0
	for raw_key in data.keys():
		var value: Variant = data.get(raw_key)
		if typeof(value) == TYPE_DICTIONARY:
			highest = max(highest, _max_number_in_rf_dictionary(value as Dictionary))
		elif typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
			highest = max(highest, float(value))
	return highest


func _rf_duel_dict(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(true)
	return {}


func _rf_duel_array(value: Variant) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return (value as Array).duplicate(true)
	return []
func reset_for_new_life() -> void:
	gs.scenario_state.clear()
	gs.transient_scenario_biases.clear()
	_ensure_state()

func has_pending_choice() -> bool:
	_ensure_state()
	var options_raw = gs.scenario_state.get("pending_options", [])
	var has_options: bool = typeof(options_raw) == TYPE_ARRAY and not options_raw.is_empty()
	if not has_options:
		return false
	if not _pending_player_mythic_pursuit_is_allowed():
		_clear_stale_player_mythic_pursuit_pending()
		return false
	return true

func is_waiting_for_year_advance() -> bool:
	_ensure_state()
	return bool(gs.scenario_state.get("waiting_for_year_advance", false))

func get_pending_choice_result() -> Dictionary:
	_ensure_state()
	var options: Array = []
	var raw_options = gs.scenario_state.get("pending_options", [])
	if typeof(raw_options) == TYPE_ARRAY:
		options = raw_options.duplicate(true)
	return {
		"type": str(gs.scenario_state.get("pending_type", "scenario_prompt")),
		"text": str(gs.scenario_state.get("pending_text", "")),
		"panel_title": str(gs.scenario_state.get("pending_panel_title", "SCENARIO")),
		"subtitle": str(gs.scenario_state.get("pending_subtitle", "Narrative as Pressure Injection")),
		"accent": str(gs.scenario_state.get("pending_accent", "#B56BFF")),
		"emoji": str(gs.scenario_state.get("pending_emoji", "✦")),
		"theme": str(gs.scenario_state.get("pending_theme", "")),
		"footer_text": str(gs.scenario_state.get("pending_footer_text", "Choose how you want to respond.")),
		"combat_ui": gs.scenario_state.get("pending_combat_ui", {}),
		"opps": options
	}

func prepare_pre_year_player_scenarios() -> Dictionary:
	_ensure_state()
	if gs == null or gs.player == null:
		return {}
	if not gs.player.alive:
		return {}
	if gs.afterlife_active:
		return {}
	if has_pending_choice():
		return get_pending_choice_result()
	if is_waiting_for_year_advance():
		return {}
	_prune_expired_cooldowns()
	var queued_mythic: Dictionary = _pop_queued_player_mythic_pursuit_scenario()
	if not queued_mythic.is_empty():
		return queue_external_scenario(queued_mythic)
	var bundle_year: int = int(gs.scenario_state.get("bundle_year", -999999))
	if bundle_year == int(gs.year) and bool(gs.scenario_state.get("bundle_built", false)):
		return {}
	var context: Dictionary = _build_context()
	var owner_asset_context: Dictionary = _build_owner_asset_signal_context(gs.player)
	for key in owner_asset_context.keys():
		context [key] = owner_asset_context [key]
	var nominations: Array = _collect_provider_nominations(context)
	var bundle: Array = _pick_bundle(nominations, context)
	gs.scenario_state ["current_bundle"] = bundle
	gs.scenario_state ["current_bundle_index"] = 0
	gs.scenario_state ["committed_choices"] = []
	gs.scenario_state ["waiting_for_year_advance"] = false
	gs.scenario_state ["bundle_year"] = int(gs.year)
	gs.scenario_state ["bundle_built"] = true
	if bundle.is_empty():
		return {}
	return _queue_bundle_item(0)
func yearly_asset_signal_tick(_payload:= {}) -> void:
	_ensure_state()
	if gs == null:
		return
	for npc_id in gs.transient_scenario_biases.keys():
		var filtered: Array = []
		var arr = gs.transient_scenario_biases [npc_id]
		if typeof(arr) != TYPE_ARRAY:
			continue
		for entry in arr:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			if int(entry.get("expiry_year", gs.year)) >= gs.year:
				filtered.append(entry)
		gs.transient_scenario_biases [npc_id] = filtered
	var seen_map_raw = gs.scenario_state.get("npc_mythic_pursuit_seen", {})
	var pruned_seen: Dictionary = {}
	if typeof(seen_map_raw) == TYPE_DICTIONARY:
		for raw_key in seen_map_raw.keys():
			var seen_year: int = int(seen_map_raw.get(raw_key, -999999))
			if seen_year >= int(gs.year) - 2:
				pruned_seen [str(raw_key)] = seen_year
	gs.scenario_state ["npc_mythic_pursuit_seen"] = pruned_seen
	_prune_mythic_micro_factions()

	var seen_owner_ids: Dictionary = _collect_asset_owner_ids()
	for raw_owner_id in seen_owner_ids.keys():
		var npc_id: int = int(raw_owner_id)
		var npc: Person = gs.get_or_reactivate_npc_by_id(npc_id)
		if npc == null or not npc.alive:
			continue
		var owner_asset_context: Dictionary = _build_owner_asset_signal_context(npc)
		_capture_asset_bias_for_npc(npc, owner_asset_context)
		_advance_npc_mythic_pursuit_for_owner(npc, owner_asset_context)


func _capture_asset_bias_for_npc(npc: Person, owner_asset_context:= {}) -> void:
	if gs == null or npc == null:
		return
	if typeof(owner_asset_context) != TYPE_DICTIONARY or owner_asset_context.is_empty():
		owner_asset_context = _build_owner_asset_signal_context(npc)
	var merged: Dictionary = owner_asset_context.get("asset_pressure", {})
	if typeof(merged) != TYPE_DICTIONARY or merged.is_empty():
		return
	var asset_status_signals: Dictionary = owner_asset_context.get("asset_status_signals", {})
	if typeof(asset_status_signals) != TYPE_DICTIONARY:
		asset_status_signals = {}
	var asset_pressure_profile: Dictionary = owner_asset_context.get("asset_pressure_profile", {})
	if typeof(asset_pressure_profile) != TYPE_DICTIONARY:
		asset_pressure_profile = {}
	var asset_event_hooks: Dictionary = owner_asset_context.get("asset_event_hooks", {})
	if typeof(asset_event_hooks) != TYPE_DICTIONARY:
		asset_event_hooks = {}
	var asset_portfolio_tags: Dictionary = owner_asset_context.get("asset_portfolio_tags", {})
	if typeof(asset_portfolio_tags) != TYPE_DICTIONARY:
		asset_portfolio_tags = {}
	var asset_namespaces: Dictionary = owner_asset_context.get("asset_namespaces", {})
	if typeof(asset_namespaces) != TYPE_DICTIONARY:
		asset_namespaces = {}
	var asset_class_filters: Dictionary = owner_asset_context.get("asset_class_filters", {})
	if typeof(asset_class_filters) != TYPE_DICTIONARY:
		asset_class_filters = {}
	var asset_identity_modes: Dictionary = owner_asset_context.get("asset_identity_modes", {})
	if typeof(asset_identity_modes) != TYPE_DICTIONARY:
		asset_identity_modes = {}
	var asset_tier_profile: Dictionary = owner_asset_context.get("asset_tier_profile", {})
	if typeof(asset_tier_profile) != TYPE_DICTIONARY:
		asset_tier_profile = {}
	var asset_provenance_signals: Dictionary = owner_asset_context.get("asset_provenance_signals", {})
	if typeof(asset_provenance_signals) != TYPE_DICTIONARY:
		asset_provenance_signals = {}
	var asset_condition_profile: Dictionary = owner_asset_context.get("asset_condition_profile", {})
	if typeof(asset_condition_profile) != TYPE_DICTIONARY:
		asset_condition_profile = {}
	var existing: Variant = gs.transient_scenario_biases.get(npc.id, [])
	var arr: Array = existing if typeof(existing) == TYPE_ARRAY else []
	var filtered: Array = []
	for entry in arr:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if str(entry.get("source", "")) == "scenario_engine_asset_pressure" and int(entry.get("expiry_year", -999999)) <= int(gs.year):
			continue
		filtered.append(entry)
	filtered.append({
		"source": "scenario_engine_asset_pressure",
		"expiry_year": int(gs.year) + 1,
		"payloads": {
			"asset_pressure": merged,
			"property_asset_signals": owner_asset_context.get("property_asset_signals", {}).duplicate(true),
			"vehicle_asset_signals": owner_asset_context.get("vehicle_asset_signals", {}).duplicate(true),
			"artifact_asset_signals": owner_asset_context.get("artifact_asset_signals", {}).duplicate(true),
			"dragonball_asset_signals": owner_asset_context.get("dragonball_asset_signals", {}).duplicate(true),
			"red_bonnet_asset_signals": owner_asset_context.get("red_bonnet_asset_signals", {}).duplicate(true),
			"asset_status_signals": asset_status_signals,
			"asset_pressure_profile": asset_pressure_profile,
			"asset_event_hooks": asset_event_hooks,
			"asset_portfolio_tags": asset_portfolio_tags,
			"asset_namespaces": asset_namespaces,
			"asset_class_filters": asset_class_filters,
			"asset_identity_modes": asset_identity_modes,
			"asset_tier_profile": asset_tier_profile,
			"max_asset_tier_score": float(merged.get("max_asset_tier_score", 0.0)),
			"asset_provenance_signals": asset_provenance_signals,
			"asset_condition_profile": asset_condition_profile,
			"asset_uniqueness_score": float(merged.get("asset_uniqueness_score", 0.0))
		}
	})
	gs.transient_scenario_biases [npc.id] = filtered



func _merge_asset_rollups(a: Dictionary, b: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var portfolio_tags: Dictionary = {}
	var event_hooks: Dictionary = {}
	var passive_modifiers: Dictionary = {}
	var prestige_signals: Dictionary = {}
	var status_signals: Dictionary = {}
	var pressure_profile: Dictionary = {}
	var asset_namespaces: Dictionary = {}
	var asset_class_filters: Dictionary = {}
	var asset_identity_modes: Dictionary = {}
	var asset_tier_profile: Dictionary = {}
	var asset_provenance_signals: Dictionary = {}
	var asset_condition_profile: Dictionary = {}

	_merge_counter_map_into(portfolio_tags, a.get("portfolio_tags", {}))
	_merge_counter_map_into(portfolio_tags, b.get("portfolio_tags", {}))
	_merge_counter_map_into(event_hooks, a.get("event_hooks", {}))
	_merge_counter_map_into(event_hooks, b.get("event_hooks", {}))
	_merge_float_map_into(passive_modifiers, a.get("passive_modifiers", {}))
	_merge_float_map_into(passive_modifiers, b.get("passive_modifiers", {}))
	_merge_float_map_into(prestige_signals, a.get("prestige_signals", {}))
	_merge_float_map_into(prestige_signals, b.get("prestige_signals", {}))
	_merge_float_map_into(status_signals, a.get("status_signals", a.get("prestige_signals", {})))
	_merge_float_map_into(status_signals, b.get("status_signals", b.get("prestige_signals", {})))
	_merge_float_map_into(pressure_profile, a.get("pressure_profile", {}))
	_merge_float_map_into(pressure_profile, b.get("pressure_profile", {}))

	_merge_counter_map_into(asset_namespaces, a.get("asset_namespaces", {}))
	_merge_counter_map_into(asset_namespaces, b.get("asset_namespaces", {}))
	_merge_counter_map_into(asset_class_filters, a.get("asset_class_filters", {}))
	_merge_counter_map_into(asset_class_filters, b.get("asset_class_filters", {}))
	_merge_counter_map_into(asset_identity_modes, a.get("asset_identity_modes", {}))
	_merge_counter_map_into(asset_identity_modes, b.get("asset_identity_modes", {}))
	_merge_float_map_into(asset_tier_profile, a.get("asset_tier_profile", {}))
	_merge_float_map_into(asset_tier_profile, b.get("asset_tier_profile", {}))
	_merge_float_map_into(asset_provenance_signals, a.get("asset_provenance_signals", {}))
	_merge_float_map_into(asset_provenance_signals, b.get("asset_provenance_signals", {}))
	_merge_float_map_into(asset_condition_profile, a.get("asset_condition_profile", {}))
	_merge_float_map_into(asset_condition_profile, b.get("asset_condition_profile", {}))

	var inferred_portfolio_moods: Dictionary = _infer_portfolio_mood_tags(
		portfolio_tags,
		event_hooks,
		status_signals,
		pressure_profile,
		asset_namespaces,
		asset_identity_modes,
		asset_provenance_signals
	)
	_merge_counter_map_into(portfolio_tags, inferred_portfolio_moods)

	out ["asset_count"] = int(a.get("asset_count", 0)) + int(b.get("asset_count", 0))
	out ["dependency_pressure"] = float(a.get("dependency_pressure", 0.0)) + float(b.get("dependency_pressure", 0.0))
	out ["prestige_total"] = float(a.get("prestige_total", 0.0)) + float(b.get("prestige_total", 0.0))
	out ["modifier_weight"] = float(a.get("modifier_weight", 0.0)) + float(b.get("modifier_weight", 0.0))
	out ["portfolio_tags"] = portfolio_tags
	out ["event_hooks"] = event_hooks
	out ["passive_modifiers"] = passive_modifiers
	out ["prestige_signals"] = prestige_signals
	out ["status_signals"] = status_signals
	out ["pressure_profile"] = pressure_profile
	out ["asset_namespaces"] = asset_namespaces
	out ["asset_class_filters"] = asset_class_filters
	out ["asset_identity_modes"] = asset_identity_modes
	out ["asset_tier_profile"] = asset_tier_profile
	out ["asset_provenance_signals"] = asset_provenance_signals
	out ["asset_condition_profile"] = asset_condition_profile
	out ["max_asset_tier_score"] = _max_asset_tier_score(asset_tier_profile)
	out ["asset_uniqueness_score"] = _compute_asset_uniqueness_score(
		asset_namespaces,
		asset_identity_modes,
		asset_provenance_signals,
		out ["asset_count"],
		out ["max_asset_tier_score"]
	)

	if int(out.get("asset_count", 0)) <= 0:
		return {}
	return out


func _merge_counter_map_into(dest: Dictionary, raw) -> void:
	if typeof(raw) != TYPE_DICTIONARY:
		return
	for key in raw.keys():
		var k:= str(key)
		dest [k] = int(dest.get(k, 0)) + int(raw.get(key, 0))


func _merge_float_map_into(dest: Dictionary, raw) -> void:
	if typeof(raw) != TYPE_DICTIONARY:
		return
	for key in raw.keys():
		var k:= str(key)
		dest [k] = float(dest.get(k, 0.0)) + float(raw.get(key, 0.0))
func queue_external_scenario(scenario: Dictionary) -> Dictionary:
	_ensure_state()

	if typeof(scenario) != TYPE_DICTIONARY or scenario.is_empty():
		return {}

	gs.scenario_state ["current_bundle"] = [scenario.duplicate(true)]
	gs.scenario_state ["current_bundle_index"] = 0
	gs.scenario_state ["committed_choices"] = []
	gs.scenario_state ["waiting_for_year_advance"] = false

	return _queue_bundle_item(0)
func _resolve_custom_choice_result(actor: Person, scenario: Dictionary, choice: Dictionary, committed: Dictionary) -> Dictionary:
	if gs == null:
		return {}

	var resolver_method: String = str(
		scenario.get("resolver_method", choice.get("resolver_method", ""))
	).strip_edges()

	if resolver_method == "":
		return {}

	var source_name: String = str(scenario.get("source", "")).strip_edges()
	var resolver_owner: String = str(scenario.get("resolver_owner", "")).strip_edges()

	if resolver_owner == "scenario_engine" and has_method(resolver_method):
		var owned_self_result = call(resolver_method, actor, scenario, choice, committed)
		if typeof(owned_self_result) == TYPE_DICTIONARY:
			return owned_self_result

	if resolver_owner != "" and resolver_owner != "scenario_engine" and gs.has_method("get"):
		var resolver_engine: Variant = gs.get(resolver_owner)
		if resolver_engine != null and resolver_engine.has_method(resolver_method):
			var owned_engine_result: Variant = resolver_engine.call(resolver_method, actor, scenario, choice, committed)
			if typeof(owned_engine_result) == TYPE_DICTIONARY:
				return (owned_engine_result as Dictionary).duplicate(true)

	match source_name:
		"artifacts_engine":
			if gs.artifacts_engine != null and gs.artifacts_engine.has_method(resolver_method):
				var result = gs.artifacts_engine.call(resolver_method, actor, scenario, choice, committed)
				if typeof(result) == TYPE_DICTIONARY:
					return result

		"crime_engine":
			if gs.crime_engine != null and gs.crime_engine.has_method(resolver_method):
				var crime_result = gs.crime_engine.call(resolver_method, actor, scenario, choice, committed)
				if typeof(crime_result) == TYPE_DICTIONARY:
					return crime_result
		"superhero_engine":
			if gs.superhero_engine != null and gs.superhero_engine.has_method(resolver_method):
				var hero_result = gs.superhero_engine.call(resolver_method, actor, scenario, choice, committed)
				if typeof(hero_result) == TYPE_DICTIONARY:
					return hero_result
		"power_engine":
			if gs.power_engine != null and gs.power_engine.has_method(resolver_method):
				var power_result = gs.power_engine.call(resolver_method, actor, scenario, choice, committed)
				if typeof(power_result) == TYPE_DICTIONARY:
					return power_result
		"infamy_engine":
			if gs.infamy_engine != null and gs.infamy_engine.has_method(resolver_method):
				var infamy_result = gs.infamy_engine.call(resolver_method, actor, scenario, choice, committed)
				if typeof(infamy_result) == TYPE_DICTIONARY:
					return infamy_result
		"bridge_to_terabithia_engine":
			if gs.bridge_to_terabithia_engine != null and gs.bridge_to_terabithia_engine.has_method(resolver_method):
				var terabithia_result = gs.bridge_to_terabithia_engine.call(resolver_method, actor, scenario, choice, committed)
				if typeof(terabithia_result) == TYPE_DICTIONARY:
					return terabithia_result

		"vormir_engine":
			if gs.vormir_engine != null and gs.vormir_engine.has_method(resolver_method):
				var vormir_result = gs.vormir_engine.call(resolver_method, actor, scenario, choice, committed)
				if typeof(vormir_result) == TYPE_DICTIONARY:
					return vormir_result

		"nidavellir_engine":
			if gs.nidavellir_engine != null and gs.nidavellir_engine.has_method(resolver_method):
				var nidavellir_result = gs.nidavellir_engine.call(resolver_method, actor, scenario, choice, committed)
				if typeof(nidavellir_result) == TYPE_DICTIONARY:
					return nidavellir_result

		"scenario_engine":
			if has_method(resolver_method):
				var self_result = call(resolver_method, actor, scenario, choice, committed)
				if typeof(self_result) == TYPE_DICTIONARY:
					return self_result

	if has_method(resolver_method):
		var fallback_self_result = call(resolver_method, actor, scenario, choice, committed)
		if typeof(fallback_self_result) == TYPE_DICTIONARY:
			return fallback_self_result

	return {}
func _pop_queued_player_mythic_pursuit_scenario() -> Dictionary:
	_ensure_state()
	if gs == null or gs.player == null:
		return {}
	var queue_raw = gs.scenario_state.get("npc_mythic_pursuit_queue", [])
	if typeof(queue_raw) != TYPE_ARRAY or queue_raw.is_empty():
		return {}
	var queue: Array = queue_raw
	var picked: Dictionary = {}
	while not queue.is_empty():
		var raw_entry = queue [0]
		queue.remove_at(0)
		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue
		if int(raw_entry.get("mythic_owner_id", -1)) != int(gs.player.id):
			continue
		var owner: Person = gs.get_or_reactivate_npc_by_id(int(raw_entry.get("mythic_owner_id", -1)))
		if not _is_player_mythic_pursuit_allowed_for_owner(owner):
			continue
		picked = raw_entry.duplicate(true)
		break
	gs.scenario_state ["npc_mythic_pursuit_queue"] = queue
	return picked

func _advance_npc_mythic_pursuit_for_owner(owner: Person, owner_asset_context: Dictionary) -> void:
	if gs == null or owner == null:
		return
	if typeof(owner_asset_context) != TYPE_DICTIONARY or owner_asset_context.is_empty():
		return
	var mythic_pull: float = _compute_mythic_pursuit_pull(owner_asset_context)
	if mythic_pull < 4.0:
		return
	var candidate_rollups: Array = _collect_mythic_pursuit_candidate_rollups(owner, mythic_pull)
	if candidate_rollups.is_empty():
		return
	candidate_rollups.sort_custom(func (a, b): return float(a.get("score", 0.0)) > float(b.get("score", 0.0)))
	var winner: Dictionary = candidate_rollups [0]
	var pursuer: Person = gs.get_or_reactivate_npc_by_id(int(winner.get("npc_id", -1)))
	if pursuer == null or not pursuer.alive:
		return
	var pursuit_kind: String = _pick_mythic_pursuit_kind(owner_asset_context, winner)
	if pursuit_kind == "":
		return
	var seed_rollups: Array = []
	if pursuit_kind == "faction":
		seed_rollups = _collect_mythic_pursuit_seed_rollups(candidate_rollups, winner, 3)
	if gs.player != null and int(owner.id) == int(gs.player.id):
		_queue_player_mythic_pursuit_scenario(owner, pursuer, pursuit_kind, owner_asset_context, winner, seed_rollups)
		return
	_resolve_background_mythic_pursuit(owner, pursuer, pursuit_kind, owner_asset_context, winner, seed_rollups)

func _compute_mythic_pursuit_pull(owner_asset_context: Dictionary) -> float:
	var asset_namespaces: Dictionary = owner_asset_context.get("asset_namespaces", {})
	if typeof(asset_namespaces) != TYPE_DICTIONARY:
		asset_namespaces = {}
	var asset_status_signals: Dictionary = owner_asset_context.get("asset_status_signals", {})
	if typeof(asset_status_signals) != TYPE_DICTIONARY:
		asset_status_signals = {}
	var asset_pressure_profile: Dictionary = owner_asset_context.get("asset_pressure_profile", {})
	if typeof(asset_pressure_profile) != TYPE_DICTIONARY:
		asset_pressure_profile = {}
	var asset_event_hooks: Dictionary = owner_asset_context.get("asset_event_hooks", {})
	if typeof(asset_event_hooks) != TYPE_DICTIONARY:
		asset_event_hooks = {}
	var score: float = 0.0
	for raw_key in asset_namespaces.keys():
		var namespace_name: String = str(raw_key)
		if namespace_name.begins_with("artifact."):
			score += float(asset_namespaces.get(raw_key, 0)) * 1.35
	if int(asset_namespaces.get("artifact.infinity_stone", 0)) > 0:
		score += 6.0
	if int(asset_namespaces.get("artifact.dragon_ball", 0)) > 0:
		score += 4.5
	if int(asset_namespaces.get("artifact.red_bonnet", 0)) > 0:
		score += 5.25
	score += float(asset_status_signals.get("public_attention", 0.0)) * 0.85
	score += float(asset_status_signals.get("romance_signal", 0.0)) * 0.45
	score += float(asset_pressure_profile.get("criminal_usefulness", 0.0)) * 1.2
	score += float(asset_pressure_profile.get("community_belonging", 0.0)) * 0.75
	score += float(owner_asset_context.get("asset_uniqueness_score", 0.0)) * 0.65
	score += float(owner_asset_context.get("max_asset_tier_score", 0.0)) * 0.45
	score += float(asset_event_hooks.get("wish_seekers", 0)) * 1.5
	return score

func _collect_mythic_pursuit_candidate_rollups(owner: Person, mythic_pull: float) -> Array:
	var out: Array = []
	if gs == null or owner == null:
		return out
	for raw_npc in gs.npcs:
		var npc: Person = raw_npc
		if npc == null or not npc.alive:
			continue
		if int(npc.id) == int(owner.id):
			continue
		if int(npc.age) < 12:
			continue
		var affection_map: Dictionary = npc.affection if typeof(npc.affection) == TYPE_DICTIONARY else {}
		var affinity_to_owner: float = float(affection_map.get(owner.id, 50))
		var volatility: float = abs(affinity_to_owner - 50.0) * 0.08
		var score: float = mythic_pull * 0.28
		score += float(npc.ambition) * 0.08
		score += float(npc.motivation) * 0.06
		score += float(npc.fame) * 0.015
		score += volatility
		if score < 5.0:
			continue
		out.append({
			"npc_id": int(npc.id),
			"score": score,
			"affinity_to_owner": affinity_to_owner
		})
	return out

func _pick_mythic_pursuit_kind(owner_asset_context: Dictionary, candidate_rollup: Dictionary) -> String:
	var asset_status_signals: Dictionary = owner_asset_context.get("asset_status_signals", {})
	if typeof(asset_status_signals) != TYPE_DICTIONARY:
		asset_status_signals = {}
	var asset_pressure_profile: Dictionary = owner_asset_context.get("asset_pressure_profile", {})
	if typeof(asset_pressure_profile) != TYPE_DICTIONARY:
		asset_pressure_profile = {}
	var asset_event_hooks: Dictionary = owner_asset_context.get("asset_event_hooks", {})
	if typeof(asset_event_hooks) != TYPE_DICTIONARY:
		asset_event_hooks = {}
	var affinity_to_owner: float = float(candidate_rollup.get("affinity_to_owner", 50.0))
	if float(asset_pressure_profile.get("criminal_usefulness", 0.0)) >= 2.0 and affinity_to_owner < 45.0:
		return "betrayal"
	if float(asset_pressure_profile.get("community_belonging", 0.0)) >= 2.0 or int(asset_event_hooks.get("wish_seekers", 0)) > 0:
		return "faction"
	if float(asset_status_signals.get("romance_signal", 0.0)) >= 2.0 and affinity_to_owner >= 55.0:
		return "relationship"
	if float(asset_status_signals.get("public_attention", 0.0)) >= 1.5:
		return "rumor"
	return "faction"

func _queue_player_mythic_pursuit_scenario(owner: Person, pursuer: Person, pursuit_kind: String, owner_asset_context: Dictionary, candidate_rollup: Dictionary, seed_rollups: Array) -> void:
	if gs == null or owner == null or pursuer == null:
		return
	_ensure_state()
	var seen_raw = gs.scenario_state.get("npc_mythic_pursuit_seen", {})
	var seen: Dictionary = seen_raw if typeof(seen_raw) == TYPE_DICTIONARY else {}
	var dedupe_key: String = "%d:%d:%d:%s" % [int(gs.year), int(owner.id), int(pursuer.id), pursuit_kind]
	if seen.has(dedupe_key):
		return
	seen [dedupe_key] = int(gs.year)
	gs.scenario_state ["npc_mythic_pursuit_seen"] = seen
	var queue_raw = gs.scenario_state.get("npc_mythic_pursuit_queue", [])
	var queue: Array = queue_raw if typeof(queue_raw) == TYPE_ARRAY else []
	var asset_event_hooks: Dictionary = owner_asset_context.get("asset_event_hooks", {})
	if typeof(asset_event_hooks) != TYPE_DICTIONARY:
		asset_event_hooks = {}
	var asset_portfolio_tags: Dictionary = owner_asset_context.get("asset_portfolio_tags", {})
	if typeof(asset_portfolio_tags) != TYPE_DICTIONARY:
		asset_portfolio_tags = {}
	var faction_preview: Dictionary = {}
	if pursuit_kind == "faction":
		faction_preview = _preview_mythic_micro_faction_identity(owner, pursuer, owner_asset_context, pursuit_kind)
	queue.append({
		"id": "npc_mythic_pursuit_%d_%d_%d_%s" % [int(gs.year), int(owner.id), int(pursuer.id), pursuit_kind],
		"source": "scenario_engine",
		"resolver_method": "_resolve_mythic_pursuit_choice",
		"category": "artifact",
		"tone": "mythic",
		"rarity": 0.82,
		"priority": 18,
		"min_age": 0,
		"max_age": 130,
		"asset_arc_family": "npc_mythic_pursuit",
		"asset_arc_step": pursuit_kind,
		"asset_repeat_group": "npc_mythic_pursuit.%s" % pursuit_kind,
		"asset_echoes_world_feed": true,
		"asset_echoes_memory": true,
		"asset_echoes_reputation": true,
		"asset_namespace_preferences": owner_asset_context.get("asset_namespaces", {}).duplicate(true),
		"asset_weight_status_signals": owner_asset_context.get("asset_status_signals", {}).duplicate(true),
		"asset_weight_pressure_profile": owner_asset_context.get("asset_pressure_profile", {}).duplicate(true),
		"asset_weight_event_hooks": asset_event_hooks.keys(),
		"asset_weight_portfolio_tags": asset_portfolio_tags.keys(),
		"asset_weight_provenance_signals": owner_asset_context.get("asset_provenance_signals", {}).duplicate(true),
		"asset_weight_condition_profile": owner_asset_context.get("asset_condition_profile", {}).duplicate(true),
		"prompt": _build_player_mythic_pursuit_prompt(pursuer, pursuit_kind),
		"choices": _build_player_mythic_pursuit_choices(pursuit_kind),
		"mythic_pursuer_id": int(pursuer.id),
		"mythic_owner_id": int(owner.id),
		"mythic_pursuit_kind": pursuit_kind,
		"mythic_candidate_rollup": candidate_rollup.duplicate(true),
		"mythic_seed_rollups": seed_rollups.duplicate(true),
		"mythic_faction_id": str(faction_preview.get("id", "")),
		"mythic_faction_name": str(faction_preview.get("name", "")),
		"mythic_faction_theme_key": str(faction_preview.get("theme_key", "")),
		"mythic_faction_theme_label": str(faction_preview.get("theme_label", ""))
	})
	gs.scenario_state ["npc_mythic_pursuit_queue"] = queue


func _build_player_mythic_pursuit_prompt(pursuer: Person, pursuit_kind: String) -> String:
	var full_name: String = "%s %s" % [pursuer.first_name, pursuer.last_name]
	match pursuit_kind:
		"faction":
			return "%s is starting to gather people around the story of what I hold. It is beginning to feel like a faction, not curiosity. Do I bring them close, feed them a false trail, or cut them off before it hardens?" % full_name
		"relationship":
			return "%s is getting close in a way that feels tied to what I hold as much as who I am. Do I let them inside the orbit, misdirect them, or shut the whole thing down?" % full_name
		"betrayal":
			return "%s has been moving like somebody who wants access first and loyalty second. The pressure around what I hold is turning sharp. Do I pull them close under watch, feed them bad information, or confront them now?" % full_name
		_:
			return "%s has started pushing rumor and attention toward what I hold. Do I guide the story, throw them off the trail, or cut them off publicly?" % full_name

func _build_player_mythic_pursuit_choices(pursuit_kind: String) -> Array:
	return [
		{
			"id": "bring_close",
			"label": "Bring them close, but under watch.",
			"journal_text": "I brought the pressure close enough to study it instead of letting it move unseen.",
			"followup_hooks": ["npc_mythic_pursuit.%s.bring_close" % pursuit_kind],
			"bias_payloads": {
				"relationship_bias": { "social_visibility": 2.0},
				"reputation_bias": { "public_attention": 1.0},
				"expiry": { "years": 1}
			}
		},
		{
			"id": "feed_false_trail",
			"label": "Feed them a false trail.",
			"journal_text": "I fed the pressure a story I could afford to lose.",
			"followup_hooks": ["npc_mythic_pursuit.%s.false_trail" % pursuit_kind],
			"bias_payloads": {
				"crime_pressure": { "rumor_heat": 2.0},
				"reputation_bias": { "public_attention": -1.0},
				"expiry": { "years": 1}
			}
		},
		{
			"id": "cut_them_off",
			"label": "Cut them off before it grows teeth.",
			"journal_text": "I cut the pressure off before fascination could become access.",
			"followup_hooks": ["npc_mythic_pursuit.%s.cutoff" % pursuit_kind],
			"bias_payloads": {
				"relationship_bias": { "social_visibility": -1.0},
				"health_bias": { "stress_delta": 1.0},
				"reputation_bias": { "public_attention": 2.0},
				"expiry": { "years": 1}
			}
		}
	]

func _resolve_background_mythic_pursuit(owner: Person, pursuer: Person, pursuit_kind: String, owner_asset_context:= {}, candidate_rollup:= {}, seed_rollups: Array = []) -> void:
	if gs == null or owner == null or pursuer == null:
		return
	var faction_id: String = ""
	var faction_name: String = ""
	var faction_member_count: int = 0
	if pursuit_kind == "faction":
		var faction_preview: Dictionary = _preview_mythic_micro_faction_identity(owner, pursuer, owner_asset_context, pursuit_kind)
		var faction_state: Dictionary = _commit_mythic_micro_faction(owner, pursuer, pursuit_kind, faction_preview, candidate_rollup, seed_rollups, "background")
		faction_id = str(faction_state.get("id", ""))
		faction_name = str(faction_state.get("name", ""))
		faction_member_count = int(faction_state.get("member_count", 0))
	var world_text: String = _build_background_mythic_pursuit_world_text(owner, pursuer, pursuit_kind, faction_name)
	_adjust_mutual_affection(owner, pursuer, 2 if pursuit_kind == "relationship" else -1, 4 if pursuit_kind == "relationship" else -2)
	var pursuit_payload: Dictionary = {
		"npc_id": int(owner.id),
		"target_id": int(pursuer.id),
		"text": world_text,
		"category": "artifact",
		"source": "scenario_engine"
	}
	if faction_id != "":
		pursuit_payload ["mythic_faction_id"] = faction_id
		pursuit_payload ["mythic_faction_name"] = faction_name
		pursuit_payload ["mythic_faction_member_count"] = faction_member_count
	if gs.has_method("push_world_feed"):
		var feed_payload: Dictionary = pursuit_payload.duplicate(true)
		feed_payload ["personally_relevant"] = int(owner.id) == int(gs.player.id) or int(pursuer.id) == int(gs.player.id)
		feed_payload ["event_name"] = "npc_mythic_pursuit"
		gs.push_world_feed(world_text, feed_payload)
	if gs.event_bus != null:
		gs.event_bus.emit(ActionEventTypes.CRIME_RUMOR_SPREAD, pursuit_payload.duplicate(true))
	if pursuit_kind == "betrayal" and gs.event_bus != null:
		var betrayal_payload: Dictionary = pursuit_payload.duplicate(true)
		betrayal_payload ["npc_id"] = int(pursuer.id)
		betrayal_payload ["target_id"] = int(owner.id)
		gs.event_bus.emit(ActionEventTypes.NPC_BETRAYED, betrayal_payload)
	elif pursuit_kind == "relationship" and gs.event_bus != null:
		gs.event_bus.emit(ActionEventTypes.NPC_PARTNERED, pursuit_payload.duplicate(true))

func _build_background_mythic_pursuit_world_text(owner: Person, pursuer: Person, pursuit_kind: String, faction_name: String = "") -> String:
	var owner_name: String = "%s %s" % [owner.first_name, owner.last_name]
	var pursuer_name: String = "%s %s" % [pursuer.first_name, pursuer.last_name]
	match pursuit_kind:
		"faction":
			if faction_name != "":
				return "%s started pulling people into %s, a named mythic micro-faction orbiting %s." % [pursuer_name, faction_name, owner_name]
			return "%s started pulling people into a mythic faction orbiting %s." % [pursuer_name, owner_name]
		"relationship":
			return "%s drew closer to %s as myth and attraction started blurring together." % [pursuer_name, owner_name]
		"betrayal":
			return "%s started circling %s with a hunger that looked more like betrayal than admiration." % [pursuer_name, owner_name]
		_:
			return "Rumors started moving through the world because %s would not stop circling %s." % [pursuer_name, owner_name]

func _resolve_mythic_pursuit_choice(actor: Person, scenario: Dictionary, choice: Dictionary, _committed: Dictionary) -> Dictionary:
	if gs == null or actor == null:
		return {}
	var pursuer_id: int = int(scenario.get("mythic_pursuer_id", -1))
	var pursuer: Person = gs.get_or_reactivate_npc_by_id(pursuer_id)
	if pursuer == null or not pursuer.alive:
		return {}
	var pursuit_kind: String = str(scenario.get("mythic_pursuit_kind", "rumor"))
	var choice_id: String = str(choice.get("id", ""))
	var candidate_rollup_raw = scenario.get("mythic_candidate_rollup", {})
	var candidate_rollup: Dictionary = candidate_rollup_raw if typeof(candidate_rollup_raw) == TYPE_DICTIONARY else {}
	var seed_rollups_raw = scenario.get("mythic_seed_rollups", [])
	var seed_rollups: Array = seed_rollups_raw if typeof(seed_rollups_raw) == TYPE_ARRAY else []
	var faction_preview: Dictionary = _build_mythic_micro_faction_preview_from_scenario(actor, pursuer, scenario, pursuit_kind)
	var faction_state: Dictionary = {}
	var faction_id: String = ""
	var faction_name: String = ""
	var faction_member_count: int = 0
	var world_text: String = ""

	match choice_id:
		"bring_close":
			if pursuit_kind == "faction":
				faction_state = _commit_mythic_micro_faction(actor, pursuer, pursuit_kind, faction_preview, candidate_rollup, seed_rollups, "bring_close")
				faction_id = str(faction_state.get("id", ""))
				faction_name = str(faction_state.get("name", ""))
				faction_member_count = int(faction_state.get("member_count", 0))
			_adjust_mutual_affection(actor, pursuer, 6, 10)
			world_text = _build_player_mythic_resolution_world_text(actor, pursuer, pursuit_kind, "bring_close", faction_name)
		"feed_false_trail":
			if pursuit_kind == "faction":
				faction_state = _commit_mythic_micro_faction(actor, pursuer, pursuit_kind, faction_preview, candidate_rollup, seed_rollups, "feed_false_trail")
				faction_id = str(faction_state.get("id", ""))
				faction_name = str(faction_state.get("name", ""))
				faction_member_count = int(faction_state.get("member_count", 0))
			_adjust_mutual_affection(actor, pursuer, -2, -4)
			world_text = _build_player_mythic_resolution_world_text(actor, pursuer, pursuit_kind, "feed_false_trail", faction_name)
		"cut_them_off":
			if pursuit_kind == "faction":
				faction_state = _commit_mythic_micro_faction(actor, pursuer, pursuit_kind, faction_preview, candidate_rollup, seed_rollups, "cut_them_off")
				faction_id = str(faction_state.get("id", ""))
				faction_name = str(faction_state.get("name", ""))
				faction_member_count = int(faction_state.get("member_count", 0))
			_adjust_mutual_affection(actor, pursuer, -8, -12)
			world_text = _build_player_mythic_resolution_world_text(actor, pursuer, pursuit_kind, "cut_them_off", faction_name)
		_:
			world_text = _build_player_mythic_resolution_world_text(actor, pursuer, pursuit_kind, "feed_false_trail", faction_name)

	var pursuit_payload: Dictionary = {
		"npc_id": int(actor.id),
		"target_id": int(pursuer.id),
		"text": world_text,
		"category": "artifact",
		"source": "scenario_engine"
	}
	if faction_id != "":
		pursuit_payload ["mythic_faction_id"] = faction_id
		pursuit_payload ["mythic_faction_name"] = faction_name
		pursuit_payload ["mythic_faction_member_count"] = faction_member_count

	if gs.event_bus != null:
		gs.event_bus.emit(ActionEventTypes.CRIME_RUMOR_SPREAD, pursuit_payload.duplicate(true))
		if choice_id == "bring_close" and pursuit_kind == "relationship":
			gs.event_bus.emit(ActionEventTypes.NPC_PARTNERED, pursuit_payload.duplicate(true))
		if choice_id == "cut_them_off":
			gs.event_bus.emit(ActionEventTypes.NPC_FOUGHT, pursuit_payload.duplicate(true))

	if gs.has_method("push_world_feed"):
		var feed_payload: Dictionary = pursuit_payload.duplicate(true)
		feed_payload ["personally_relevant"] = true
		feed_payload ["event_name"] = "npc_mythic_pursuit_resolution"
		gs.push_world_feed(world_text, feed_payload)

	return {
		"type": "scenario_commit_complete",
		"text": str(choice.get("journal_text", "I answered the pressure around what I held.")),
		"popup_title": "Mythic Pressure",
		"popup_text": world_text,
		"popup_footer": "Tap anywhere to continue."
	}

func _build_player_mythic_resolution_world_text(actor: Person, pursuer: Person, pursuit_kind: String, resolution_kind: String, faction_name: String = "") -> String:
	var actor_name: String = "%s %s" % [actor.first_name, actor.last_name]
	var pursuer_name: String = "%s %s" % [pursuer.first_name, pursuer.last_name]
	match resolution_kind:
		"bring_close":
			match pursuit_kind:
				"faction":
					if faction_name != "":
						return "%s brought %s close and started shaping %s around the myth instead of letting it form wild." % [actor_name, pursuer_name, faction_name]
					return "%s brought %s close and started shaping the faction forming around the myth instead of letting it form wild." % [actor_name, pursuer_name]
				"relationship":
					return "%s let %s closer, but on watched terms, refusing to let myth decide intimacy." % [actor_name, pursuer_name]
				"betrayal":
					return "%s pulled %s close under watch and turned possible betrayal into controlled proximity." % [actor_name, pursuer_name]
				_:
					return "%s brought %s close enough to study the rumor before it could grow teeth." % [actor_name, pursuer_name]
		"cut_them_off":
			match pursuit_kind:
				"faction":
					if faction_name != "":
						return "%s cut %s off before %s could harden into access." % [actor_name, pursuer_name, faction_name]
					return "%s cut %s off before the faction around the myth could harden into access." % [actor_name, pursuer_name]
				"relationship":
					return "%s shut %s out before attraction could become a door into mythic access." % [actor_name, pursuer_name]
				"betrayal":
					return "%s confronted %s early and cut the betrayal path off before it matured." % [actor_name, pursuer_name]
				_:
					return "%s cut %s off publicly and made the rumor pay for reaching too close." % [actor_name, pursuer_name]
		_:
			match pursuit_kind:
				"faction":
					if faction_name != "":
						return "%s fed %s a false trail and let %s march in the wrong direction." % [actor_name, pursuer_name, faction_name]
					return "%s fed %s a false trail and let the forming faction march in the wrong direction." % [actor_name, pursuer_name]
				"relationship":
					return "%s misdirected %s and kept myth from turning closeness into leverage." % [actor_name, pursuer_name]
				"betrayal":
					return "%s fed %s bad information and let betrayal trip over its own confidence." % [actor_name, pursuer_name]
				_:
					return "%s fed %s a false trail and bent the rumor away from the truth." % [actor_name, pursuer_name]
func _collect_mythic_pursuit_seed_rollups(candidate_rollups: Array, winner: Dictionary, limit: int = 3) -> Array:
	var out: Array = []
	var winner_id: int = int(winner.get("npc_id", -1))
	for entry in candidate_rollups:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if int(entry.get("npc_id", -1)) == winner_id:
			continue
		out.append(entry.duplicate(true))
		if out.size() >= limit:
			break
	return out

func _pick_mythic_micro_faction_theme(owner_asset_context: Dictionary) -> Dictionary:
	var asset_namespaces: Dictionary = owner_asset_context.get("asset_namespaces", {})
	if typeof(asset_namespaces) != TYPE_DICTIONARY:
		asset_namespaces = {}
	var asset_event_hooks: Dictionary = owner_asset_context.get("asset_event_hooks", {})
	if typeof(asset_event_hooks) != TYPE_DICTIONARY:
		asset_event_hooks = {}
	var asset_pressure_profile: Dictionary = owner_asset_context.get("asset_pressure_profile", {})
	if typeof(asset_pressure_profile) != TYPE_DICTIONARY:
		asset_pressure_profile = {}
	if int(asset_namespaces.get("artifact.infinity_stone", 0)) > 0:
		return { "key": "stone", "label": "Stone"}
	if int(asset_namespaces.get("artifact.dragon_ball", 0)) > 0:
		return { "key": "dragon", "label": "Dragon"}
	if int(asset_namespaces.get("artifact.red_bonnet", 0)) > 0:
		return { "key": "red_thread", "label": "Red Thread"}
	if int(asset_event_hooks.get("wish_seekers", 0)) > 0:
		return { "key": "wish", "label": "Wish"}
	if float(asset_pressure_profile.get("criminal_usefulness", 0.0)) >= 2.0:
		return { "key": "shadow", "label": "Shadow"}
	if float(asset_pressure_profile.get("community_belonging", 0.0)) >= 2.0:
		return { "key": "orbit", "label": "Orbit"}
	return { "key": "myth", "label": "Myth"}

func _preview_mythic_micro_faction_identity(owner: Person, pursuer: Person, owner_asset_context: Dictionary, pursuit_kind: String) -> Dictionary:
	var theme: Dictionary = _pick_mythic_micro_faction_theme(owner_asset_context)
	var owner_label: String = str(owner.last_name).strip_edges()
	if owner_label == "":
		owner_label = str(owner.first_name).strip_edges()
	if owner_label == "":
		owner_label = "Mythic"
	var endings: Array = ["Circle", "Orbit", "Court", "Covenant"]
	var theme_key: String = str(theme.get("key", "myth"))
	var theme_label: String = str(theme.get("label", "Myth"))
	var ending_index: int = abs((int(owner.id) * 17) + (int(pursuer.id) * 31) + theme_key.length()) % endings.size()
	var ending: String = str(endings [ending_index])
	var faction_name: String = "The %s %s %s" % [owner_label, theme_label, ending]
	var faction_id: String = "mythic_micro_faction:%d:%s:%s:%s" % [
		int(owner.id),
		pursuit_kind,
		theme_key.replace(" ", "_"),
		ending.to_lower()
	]
	return {
		"id": faction_id,
		"name": faction_name,
		"theme_key": theme_key,
		"theme_label": theme_label,
		"pursuit_kind": pursuit_kind
	}

func _build_mythic_micro_faction_preview_from_scenario(actor: Person, _pursuer: Person, scenario: Dictionary, pursuit_kind: String) -> Dictionary:
	var preview: Dictionary = {
		"id": str(scenario.get("mythic_faction_id", "")),
		"name": str(scenario.get("mythic_faction_name", "")),
		"theme_key": str(scenario.get("mythic_faction_theme_key", "myth")),
		"theme_label": str(scenario.get("mythic_faction_theme_label", "Myth")),
		"pursuit_kind": pursuit_kind
	}
	if str(preview.get("id", "")) == "":
		var owner_label: String = str(actor.last_name).strip_edges()
		if owner_label == "":
			owner_label = str(actor.first_name).strip_edges()
		if owner_label == "":
			owner_label = "Mythic"
		preview ["id"] = "mythic_micro_faction:%d:%s:myth:circle" % [int(actor.id), pursuit_kind]
		preview ["name"] = "The %s Myth Circle" % owner_label
	return preview

func _upsert_mythic_micro_faction_member(members: Dictionary, npc: Person, role: String, active: bool, resolution_kind: String, rollup:= {}) -> void:
	if npc == null:
		return
	var member_key: String = str(int(npc.id))
	var entry_raw = members.get(member_key, {})
	var entry: Dictionary = entry_raw if typeof(entry_raw) == TYPE_DICTIONARY else {}
	entry ["npc_id"] = int(npc.id)
	entry ["role"] = role
	entry ["joined_year"] = int(entry.get("joined_year", gs.year))
	entry ["last_year_seen"] = int(gs.year)
	entry ["active"] = active
	entry ["resolution"] = resolution_kind
	if typeof(rollup) == TYPE_DICTIONARY:
		entry ["score"] = float(rollup.get("score", entry.get("score", 0.0)))
		entry ["affinity_to_owner"] = float(rollup.get("affinity_to_owner", entry.get("affinity_to_owner", 50.0)))
	members [member_key] = entry

func _count_active_mythic_micro_faction_members(members: Dictionary) -> int:
	var count: int = 0
	for raw_key in members.keys():
		var entry_raw = members.get(raw_key, {})
		var entry: Dictionary = entry_raw if typeof(entry_raw) == TYPE_DICTIONARY else {}
		if bool(entry.get("active", true)):
			count += 1
	return count

func _rebuild_mythic_micro_faction_membership_index(factions: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for raw_faction_id in factions.keys():
		var faction_raw = factions.get(raw_faction_id, {})
		var faction: Dictionary = faction_raw if typeof(faction_raw) == TYPE_DICTIONARY else {}
		var members_raw = faction.get("member_ids", {})
		var members: Dictionary = members_raw if typeof(members_raw) == TYPE_DICTIONARY else {}
		for raw_member_key in members.keys():
			var member_raw = members.get(raw_member_key, {})
			var member: Dictionary = member_raw if typeof(member_raw) == TYPE_DICTIONARY else {}
			var npc_key: String = str(int(member.get("npc_id", -1)))
			if npc_key == "-1":
				continue
			if not out.has(npc_key):
				out [npc_key] = {}
			out [npc_key] [str(raw_faction_id)] = {
				"owner_id": int(faction.get("owner_id", -1)),
				"faction_name": str(faction.get("name", "")),
				"role": str(member.get("role", "member")),
				"active": bool(member.get("active", true)),
				"status": str(faction.get("status", "forming")),
				"joined_year": int(member.get("joined_year", gs.year))
			}
	return out

func _commit_mythic_micro_faction(owner: Person, pursuer: Person, pursuit_kind: String, faction_preview: Dictionary, candidate_rollup: Dictionary, seed_rollups: Array, resolution_kind: String) -> Dictionary:
	_ensure_state()
	if gs == null or owner == null or pursuer == null:
		return {}
	if pursuit_kind != "faction":
		return {}
	var factions_raw = gs.scenario_state.get("npc_mythic_micro_factions", {})
	var factions: Dictionary = factions_raw if typeof(factions_raw) == TYPE_DICTIONARY else {}
	var faction_id: String = str(faction_preview.get("id", ""))
	if faction_id == "":
		return {}
	var faction_default: Dictionary = {
		"id": faction_id,
		"name": str(faction_preview.get("name", "Unnamed Mythic Circle")),
		"owner_id": int(owner.id),
		"founder_id": int(pursuer.id),
		"pursuit_kind": pursuit_kind,
		"theme_key": str(faction_preview.get("theme_key", "myth")),
		"theme_label": str(faction_preview.get("theme_label", "Myth")),
		"created_year": int(gs.year),
		"last_year_active": int(gs.year),
		"status": "forming",
		"member_ids": {},
		"last_seed_rollups": []
	}
	var faction_raw = factions.get(faction_id, faction_default)
	var faction: Dictionary = faction_raw if typeof(faction_raw) == TYPE_DICTIONARY else faction_default.duplicate(true)
	var members_raw = faction.get("member_ids", {})
	var members: Dictionary = members_raw if typeof(members_raw) == TYPE_DICTIONARY else {}
	var status: String = "forming"
	match resolution_kind:
		"bring_close":
			status = "guided"
		"feed_false_trail":
			status = "misdirected"
		"cut_them_off":
			status = "suppressed"
		_:
			status = "forming"
	faction ["status"] = status
	faction ["last_year_active"] = int(gs.year)
	_upsert_mythic_micro_faction_member(members, pursuer, "founder", resolution_kind != "cut_them_off", resolution_kind, candidate_rollup)
	for entry in seed_rollups:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var npc: Person = gs.get_or_reactivate_npc_by_id(int(entry.get("npc_id", -1)))
		if npc == null or not npc.alive:
			continue
		if int(npc.id) == int(owner.id) or int(npc.id) == int(pursuer.id):
			continue
		var role: String = "core" if _count_active_mythic_micro_faction_members(members) < 3 else "hanger_on"
		_upsert_mythic_micro_faction_member(members, npc, role, resolution_kind != "cut_them_off", resolution_kind, entry)
	faction ["member_ids"] = members
	faction ["member_count"] = _count_active_mythic_micro_faction_members(members)
	faction ["last_seed_rollups"] = seed_rollups.duplicate(true)
	factions [faction_id] = faction
	gs.scenario_state ["npc_mythic_micro_factions"] = factions
	gs.scenario_state ["npc_mythic_membership_index"] = _rebuild_mythic_micro_faction_membership_index(factions)
	return faction

func _prune_mythic_micro_factions() -> void:
	_ensure_state()
	var factions_raw = gs.scenario_state.get("npc_mythic_micro_factions", {})
	if typeof(factions_raw) != TYPE_DICTIONARY:
		gs.scenario_state ["npc_mythic_micro_factions"] = {}
		gs.scenario_state ["npc_mythic_membership_index"] = {}
		return
	var pruned: Dictionary = {}
	for raw_faction_id in factions_raw.keys():
		var faction_raw = factions_raw.get(raw_faction_id, {})
		var faction: Dictionary = faction_raw if typeof(faction_raw) == TYPE_DICTIONARY else {}
		var owner: Person = gs.get_or_reactivate_npc_by_id(int(faction.get("owner_id", -1)))
		if owner == null or not owner.alive:
			continue
		var members_raw = faction.get("member_ids", {})
		var members: Dictionary = members_raw if typeof(members_raw) == TYPE_DICTIONARY else {}
		var cleaned_members: Dictionary = {}
		for raw_member_key in members.keys():
			var member_raw = members.get(raw_member_key, {})
			var member: Dictionary = member_raw if typeof(member_raw) == TYPE_DICTIONARY else {}
			var npc: Person = gs.get_or_reactivate_npc_by_id(int(member.get("npc_id", -1)))
			if npc == null or not npc.alive:
				continue
			member ["last_year_seen"] = int(gs.year)
			cleaned_members [str(int(npc.id))] = member
		faction ["member_ids"] = cleaned_members
		faction ["member_count"] = _count_active_mythic_micro_faction_members(cleaned_members)
		if cleaned_members.is_empty() and str(faction.get("status", "")) == "suppressed":
			continue
		pruned [str(raw_faction_id)] = faction
	gs.scenario_state ["npc_mythic_micro_factions"] = pruned
	gs.scenario_state ["npc_mythic_membership_index"] = _rebuild_mythic_micro_faction_membership_index(pruned)

func _adjust_mutual_affection(a: Person, b: Person, delta_ab: int, delta_ba: int) -> void:
	if a == null or b == null:
		return
	if typeof(a.affection) == TYPE_DICTIONARY:
		a.affection [b.id] = clamp(int(a.affection.get(b.id, 50)) + delta_ab, 0, 100)
	if typeof(b.affection) == TYPE_DICTIONARY:
		b.affection [a.id] = clamp(int(b.affection.get(a.id, 50)) + delta_ba, 0, 100)
func choose_pending_option(action_label: String) -> Dictionary:
	_ensure_state()
	if not has_pending_choice():
		return {
			"success": false,
			"text": "There is no scenario choice waiting right now."
		}

	var lookup_raw = gs.scenario_state.get("pending_lookup", {})
	if typeof(lookup_raw) != TYPE_DICTIONARY or not lookup_raw.has(action_label):
		return {
			"success": false,
			"text": "That choice does not match the active scenario."
		}

	var bundle_raw = gs.scenario_state.get("current_bundle", [])
	if typeof(bundle_raw) != TYPE_ARRAY or bundle_raw.is_empty():
		_clear_pending_choice()
		return {
			"success": false,
			"text": "The current scenario bundle has gone stale."
		}

	var current_index: int = int(gs.scenario_state.get("current_bundle_index", 0))
	if current_index < 0 or current_index >= bundle_raw.size():
		_clear_pending_choice()
		gs.scenario_state ["waiting_for_year_advance"] = false
		if gs.life_engine != null and gs.life_engine.has_method("_resolve_current_year_after_tick"):
			return gs.life_engine._resolve_current_year_after_tick()
		return {
			"type": "scenario_commit_complete",
			"text": "The moment is locked in.",
			"opps": []
		}

	var scenario: Dictionary = bundle_raw [current_index]
	var choice: Dictionary = lookup_raw [action_label]
	_clear_pending_choice()

	var actor: Person = gs.player
	if actor == null:
		return {
			"success": false,
			"text": "There is no active player to resolve this scenario choice."
		}

	var committed: Dictionary = resolver.commit_choice(actor, scenario, choice)
	var _committed_choices: Array = gs.scenario_state.get("committed_choices", [])
	_apply_cooldown_from_scenario(scenario)
	_register_followup_hooks(committed.get("followup_hooks", []))
	_remember_recent_choice(committed)

	if gs.event_bus != null:
		gs.event_bus.emit(ActionEventTypes.SCENARIO_RESOLVED, {
			"npc_id": gs.player.id if gs.player != null else -1,
			"scenario_id": str(scenario.get("id", "")),
			"choice_id": str(choice.get("id", "")),
			"category": str(scenario.get("category", "general")),
			"text": str(committed.get("text", "")),
			"source": "scenario_engine"
		})

	var custom_result: Dictionary = _resolve_custom_choice_result(actor, scenario, choice, committed)
	if not custom_result.is_empty():
		var custom_type: String = str(custom_result.get("type", "")).strip_edges()

		if custom_type == "scenario_prompt":
			gs.scenario_state ["waiting_for_year_advance"] = false
			return custom_result

		gs.scenario_state ["current_bundle"] = []
		gs.scenario_state ["current_bundle_index"] = 0
		gs.scenario_state ["waiting_for_year_advance"] = false
		return custom_result

	var next_index: int = current_index + 1
	if next_index < bundle_raw.size():
		return _queue_bundle_item(next_index)

	gs.scenario_state ["waiting_for_year_advance"] = false
	if gs.life_engine != null and gs.life_engine.has_method("_resolve_current_year_after_tick"):
		return gs.life_engine._resolve_current_year_after_tick()

	return {
		"type": "scenario_commit_complete",
		"text": "I chose how to face what was coming.",
		"opps": []
	}

func apply_committed_biases_for_year() -> void:
	_ensure_state()

	if gs == null or gs.player == null:
		return

	var committed_choices: Array = gs.scenario_state.get("committed_choices", [])
	if committed_choices.is_empty():
		gs.transient_scenario_biases.erase(gs.player.id)
		return

	var merged: Dictionary = {}
	for committed in committed_choices:
		if typeof(committed) != TYPE_DICTIONARY:
			continue
		_merge_into(merged, committed.get("bias_payloads", {}))

	merged ["applied_year"] = int(gs.year)
	gs.transient_scenario_biases [gs.player.id] = merged

func finish_year_resolution() -> void:
	_ensure_state()
	if gs == null or gs.player == null:
		return
	gs.transient_scenario_biases.erase(gs.player.id)
	gs.scenario_state ["committed_choices"] = []
	gs.scenario_state ["current_bundle"] = []
	gs.scenario_state ["current_bundle_index"] = 0
	gs.scenario_state ["waiting_for_year_advance"] = false
	gs.scenario_state ["year_in_progress"] = false

func get_transient_bias_for_npc(npc_id: int) -> Dictionary:
	if gs == null or npc_id <= 0:
		return {}
	if not gs.transient_scenario_biases.has(npc_id):
		return {}

	var raw = gs.transient_scenario_biases [npc_id]
	if typeof(raw) == TYPE_DICTIONARY:
		return raw.duplicate(true)

	if typeof(raw) != TYPE_ARRAY:
		return {}

	var out: Dictionary = {}
	var merged_payloads: Dictionary = {}
	var followup_hooks: Array = []
	var repeat_groups: Dictionary = {}

	for entry in raw:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if int(entry.get("expiry_year", gs.year)) < int(gs.year):
			continue

		for key in entry.keys():
			if key == "payloads":
				continue
			if key == "followup_hooks":
				var hooks_raw = entry.get("followup_hooks", [])
				if typeof(hooks_raw) == TYPE_ARRAY:
					for raw_hook in hooks_raw:
						var hook_name:= str(raw_hook)
						if hook_name != "" and hook_name not in followup_hooks:
							followup_hooks.append(hook_name)
				continue
			out [key] = entry.get(key)

		var payloads: Dictionary = entry.get("payloads", {})
		if typeof(payloads) != TYPE_DICTIONARY:
			continue

		for payload_key in payloads.keys():
			var key_name:= str(payload_key)
			var value = payloads [payload_key]
			if typeof(value) == TYPE_DICTIONARY:
				var existing_map: Dictionary = merged_payloads.get(key_name, {})
				for sub_key in value.keys():
					var sub_name:= str(sub_key)
					var incoming = value [sub_key]
					if typeof(incoming) == TYPE_INT or typeof(incoming) == TYPE_FLOAT:
						existing_map [sub_name] = float(existing_map.get(sub_name, 0.0)) + float(incoming)
					else:
						existing_map [sub_name] = incoming
				merged_payloads [key_name] = existing_map
			elif typeof(value) == TYPE_ARRAY:
				var existing_arr: Array = merged_payloads.get(key_name, [])
				for item in value:
					if item not in existing_arr:
						existing_arr.append(item)
				merged_payloads [key_name] = existing_arr
			else:
				merged_payloads [key_name] = value

		var repeat_group: String = str(entry.get("asset_repeat_group", "")).strip_edges()
		if repeat_group != "":
			repeat_groups [repeat_group] = int(repeat_groups.get(repeat_group, 0)) + 1

	out ["payloads"] = merged_payloads
	out ["followup_hooks"] = followup_hooks
	out ["asset_repeat_groups"] = repeat_groups

	for payload_key in merged_payloads.keys():
		out [str(payload_key)] = merged_payloads [payload_key]

	return out
func _build_owner_asset_signal_context(owner: Person) -> Dictionary:
	var out: Dictionary = {}

	var property_rollup: Dictionary = {}
	if gs != null and gs.property_engine != null and owner != null:
		property_rollup = gs.property_engine.get_asset_signal_rollup_for_owner(owner)

	var vehicle_rollup: Dictionary = {}
	if gs != null and gs.vehicle_engine != null and owner != null:
		vehicle_rollup = gs.vehicle_engine.get_asset_signal_rollup_for_owner(owner)

	var artifact_rollup: Dictionary = {}
	if gs != null and gs.artifacts_engine != null and owner != null and gs.artifacts_engine.has_method("get_asset_signal_rollup_for_owner"):
		artifact_rollup = gs.artifacts_engine.get_asset_signal_rollup_for_owner(owner)

	var dragonball_rollup: Dictionary = {}
	if gs != null and gs.dragonballs_engine != null and owner != null and gs.dragonballs_engine.has_method("get_asset_signal_rollup_for_owner"):
		dragonball_rollup = gs.dragonballs_engine.get_asset_signal_rollup_for_owner(owner)

	var red_bonnet_rollup: Dictionary = {}
	if gs != null and gs.red_bonnet_engine != null and owner != null and gs.red_bonnet_engine.has_method("get_asset_signal_rollup_for_owner"):
		red_bonnet_rollup = gs.red_bonnet_engine.get_asset_signal_rollup_for_owner(owner)

	var merged: Dictionary = _merge_many_asset_rollups([
		property_rollup,
		vehicle_rollup,
		artifact_rollup,
		dragonball_rollup,
		red_bonnet_rollup
	])

	var asset_status_signals: Dictionary = merged.get("status_signals", merged.get("prestige_signals", {}))
	if typeof(asset_status_signals) != TYPE_DICTIONARY:
		asset_status_signals = {}

	var asset_pressure_profile: Dictionary = merged.get("pressure_profile", {})
	if typeof(asset_pressure_profile) != TYPE_DICTIONARY:
		asset_pressure_profile = {}

	var asset_event_hooks: Dictionary = merged.get("event_hooks", {})
	if typeof(asset_event_hooks) != TYPE_DICTIONARY:
		asset_event_hooks = {}

	var asset_portfolio_tags: Dictionary = merged.get("portfolio_tags", {})
	if typeof(asset_portfolio_tags) != TYPE_DICTIONARY:
		asset_portfolio_tags = {}

	var asset_namespaces: Dictionary = merged.get("asset_namespaces", {})
	if typeof(asset_namespaces) != TYPE_DICTIONARY:
		asset_namespaces = {}

	var asset_class_filters: Dictionary = merged.get("asset_class_filters", {})
	if typeof(asset_class_filters) != TYPE_DICTIONARY:
		asset_class_filters = {}

	var asset_identity_modes: Dictionary = merged.get("asset_identity_modes", {})
	if typeof(asset_identity_modes) != TYPE_DICTIONARY:
		asset_identity_modes = {}

	var asset_tier_profile: Dictionary = merged.get("asset_tier_profile", {})
	if typeof(asset_tier_profile) != TYPE_DICTIONARY:
		asset_tier_profile = {}

	var asset_provenance_signals: Dictionary = merged.get("asset_provenance_signals", {})
	if typeof(asset_provenance_signals) != TYPE_DICTIONARY:
		asset_provenance_signals = {}

	var asset_condition_profile: Dictionary = merged.get("asset_condition_profile", {})
	if typeof(asset_condition_profile) != TYPE_DICTIONARY:
		asset_condition_profile = {}

	out ["property_asset_signals"] = property_rollup
	out ["vehicle_asset_signals"] = vehicle_rollup
	out ["artifact_asset_signals"] = artifact_rollup
	out ["dragonball_asset_signals"] = dragonball_rollup
	out ["red_bonnet_asset_signals"] = red_bonnet_rollup
	out ["asset_pressure"] = merged
	out ["asset_status_signals"] = asset_status_signals
	out ["asset_pressure_profile"] = asset_pressure_profile
	out ["asset_event_hooks"] = asset_event_hooks
	out ["asset_portfolio_tags"] = asset_portfolio_tags
	out ["asset_namespaces"] = asset_namespaces
	out ["asset_class_filters"] = asset_class_filters
	out ["asset_identity_modes"] = asset_identity_modes
	out ["asset_tier_profile"] = asset_tier_profile
	out ["asset_provenance_signals"] = asset_provenance_signals
	out ["asset_condition_profile"] = asset_condition_profile

	return out
func _merge_many_asset_rollups(rollups: Array) -> Dictionary:
	var merged: Dictionary = {}
	var has_any: bool = false
	for raw_rollup in rollups:
		if typeof(raw_rollup) != TYPE_DICTIONARY:
			continue
		var rollup: Dictionary = raw_rollup
		if rollup.is_empty():
			continue
		if not has_any:
			merged = rollup.duplicate(true)
			has_any = true
		else:
			merged = _merge_asset_rollups(merged, rollup)
	if not has_any:
		return {}
	return merged
func _collect_asset_owner_ids() -> Dictionary:
	var seen_owner_ids: Dictionary = {}

	if gs == null:
		return seen_owner_ids

	if gs.property_engine != null:
		for raw_id in gs.property_engine.properties.keys():
			seen_owner_ids [int(raw_id)] = true

	if gs.vehicle_engine != null:
		for raw_id in gs.vehicle_engine.vehicles.keys():
			seen_owner_ids [int(raw_id)] = true

	if gs.artifacts_engine != null and typeof(gs.artifacts_engine.ownership) == TYPE_DICTIONARY:
		for raw_id in gs.artifacts_engine.ownership.keys():
			seen_owner_ids [int(raw_id)] = true

	if gs.dragonballs_engine != null and typeof(gs.dragonballs_engine.ownership) == TYPE_DICTIONARY:
		for raw_id in gs.dragonballs_engine.ownership.keys():
			seen_owner_ids [int(raw_id)] = true

	if gs.red_bonnet_engine != null:
		var bonnet_owner_id: int = int(gs.red_bonnet_engine.owner_id)
		if bonnet_owner_id > 0:
			seen_owner_ids [bonnet_owner_id] = true

	return seen_owner_ids

func _build_context() -> Dictionary:
	var player: Person = gs.player

	var property_rollup: Dictionary = {}
	if gs != null and gs.property_engine != null and player != null:
		property_rollup = gs.property_engine.get_asset_signal_rollup_for_owner(player)

	var vehicle_rollup: Dictionary = {}
	if gs != null and gs.vehicle_engine != null and player != null:
		vehicle_rollup = gs.vehicle_engine.get_asset_signal_rollup_for_owner(player)

	var asset_pressure: Dictionary = _merge_asset_rollups(property_rollup, vehicle_rollup)

	var asset_status_signals: Dictionary = asset_pressure.get("status_signals", asset_pressure.get("prestige_signals", {}))
	if typeof(asset_status_signals) != TYPE_DICTIONARY:
		asset_status_signals = {}

	var asset_pressure_profile: Dictionary = asset_pressure.get("pressure_profile", {})
	if typeof(asset_pressure_profile) != TYPE_DICTIONARY:
		asset_pressure_profile = {}

	var asset_event_hooks: Dictionary = asset_pressure.get("event_hooks", {})
	if typeof(asset_event_hooks) != TYPE_DICTIONARY:
		asset_event_hooks = {}

	var asset_portfolio_tags: Dictionary = asset_pressure.get("portfolio_tags", {})
	if typeof(asset_portfolio_tags) != TYPE_DICTIONARY:
		asset_portfolio_tags = {}

	var asset_namespaces: Dictionary = asset_pressure.get("asset_namespaces", {})
	if typeof(asset_namespaces) != TYPE_DICTIONARY:
		asset_namespaces = {}

	var asset_class_filters: Dictionary = asset_pressure.get("asset_class_filters", {})
	if typeof(asset_class_filters) != TYPE_DICTIONARY:
		asset_class_filters = {}

	var asset_identity_modes: Dictionary = asset_pressure.get("asset_identity_modes", {})
	if typeof(asset_identity_modes) != TYPE_DICTIONARY:
		asset_identity_modes = {}

	var asset_tier_profile: Dictionary = asset_pressure.get("asset_tier_profile", {})
	if typeof(asset_tier_profile) != TYPE_DICTIONARY:
		asset_tier_profile = {}

	var asset_provenance_signals: Dictionary = asset_pressure.get("asset_provenance_signals", {})
	if typeof(asset_provenance_signals) != TYPE_DICTIONARY:
		asset_provenance_signals = {}

	var asset_condition_profile: Dictionary = asset_pressure.get("asset_condition_profile", {})
	if typeof(asset_condition_profile) != TYPE_DICTIONARY:
		asset_condition_profile = {}

	var place_scenario_bias: Dictionary = {}
	if gs != null and gs.place_influence_engine != null and player != null:
		place_scenario_bias = gs.place_influence_engine.get_scenario_bias(player)

	var place_pressure: Dictionary = place_scenario_bias.get("place_pressure", {})
	if typeof(place_pressure) != TYPE_DICTIONARY:
		place_pressure = {}

	var place_conflict: Dictionary = place_scenario_bias.get("place_conflict", {})
	if typeof(place_conflict) != TYPE_DICTIONARY:
		place_conflict = {}

	var place_tag_weights: Dictionary = place_scenario_bias.get("place_tag_weights", {})
	if typeof(place_tag_weights) != TYPE_DICTIONARY:
		place_tag_weights = {}

	var place_tags: Array = place_scenario_bias.get("place_tags", [])
	if typeof(place_tags) != TYPE_ARRAY:
		place_tags = []

	var place_identity_summary: Dictionary = place_scenario_bias.get("place_identity_summary", {})
	if typeof(place_identity_summary) != TYPE_DICTIONARY:
		place_identity_summary = {}

	var current_place_packet: Dictionary = place_scenario_bias.get("current_place_packet", {})
	if typeof(current_place_packet) != TYPE_DICTIONARY:
		current_place_packet = {}

	var transient_player_bias: Dictionary = {}
	if gs != null and player != null:
		var transient_bias_raw: Variant = gs.transient_scenario_biases.get(int(player.id), {})
		if typeof(transient_bias_raw) == TYPE_DICTIONARY:
			transient_player_bias = transient_bias_raw.duplicate(true)
		elif typeof(transient_bias_raw) == TYPE_ARRAY:
			for entry_raw in transient_bias_raw:
				if typeof(entry_raw) != TYPE_DICTIONARY:
					continue
				var entry: Dictionary = entry_raw
				for bucket_key in ["faction_pressure", "relationship_bias", "reputation_bias"]:
					if not entry.has(bucket_key):
						continue
					var incoming_raw: Variant = entry.get(bucket_key, {})
					if typeof(incoming_raw) != TYPE_DICTIONARY:
						continue
					var merged_raw: Variant = transient_player_bias.get(bucket_key, {})
					var merged: Dictionary = merged_raw if typeof(merged_raw) == TYPE_DICTIONARY else {}
					for inner_key in incoming_raw.keys():
						var inner_key_text: String = str(inner_key)
						var incoming_value: Variant = incoming_raw.get(inner_key, null)
						if typeof(incoming_value) == TYPE_INT or typeof(incoming_value) == TYPE_FLOAT:
							merged [inner_key_text] = float(merged.get(inner_key_text, 0.0)) + float(incoming_value)
						else:
							merged [inner_key_text] = incoming_value
					transient_player_bias [bucket_key] = merged

	var faction_pressure: Dictionary = transient_player_bias.get("faction_pressure", {})
	if typeof(faction_pressure) != TYPE_DICTIONARY:
		faction_pressure = {}

	var faction_hotspots: Array = faction_pressure.get("hotspots", [])
	if typeof(faction_hotspots) != TYPE_ARRAY:
		faction_hotspots = []

	var faction_kind_presence: Dictionary = faction_pressure.get("kind_presence", {})
	if typeof(faction_kind_presence) != TYPE_DICTIONARY:
		faction_kind_presence = {}

	return {
		"player": player,
		"player_id": player.id if player != null else -1,
		"age": int(player.age) if player != null else 0,
		"year": int(gs.year),
		"era_name": str(gs.era.name) if gs.era != null else "",
		"reality_mode": str(gs.get_reality_mode()) if gs.has_method("get_reality_mode") else "chaos",
		"recent_followup_hooks": gs.scenario_state.get("recent_followup_hooks", []).duplicate(),
		"category_budgets": DEFAULT_CATEGORY_BUDGETS.duplicate(true),
		"property_asset_signals": property_rollup,
		"vehicle_asset_signals": vehicle_rollup,
		"asset_pressure": asset_pressure,
		"asset_status_signals": asset_status_signals.duplicate(true),
		"asset_pressure_profile": asset_pressure_profile.duplicate(true),
		"asset_event_hooks": asset_event_hooks.duplicate(true),
		"asset_portfolio_tags": asset_portfolio_tags.duplicate(true),
		"asset_namespaces": asset_namespaces.duplicate(true),
		"asset_class_filters": asset_class_filters.duplicate(true),
		"asset_identity_modes": asset_identity_modes.duplicate(true),
		"asset_tier_profile": asset_tier_profile.duplicate(true),
		"max_asset_tier_score": float(asset_pressure.get("max_asset_tier_score", 0.0)),
		"asset_provenance_signals": asset_provenance_signals.duplicate(true),
		"asset_condition_profile": asset_condition_profile.duplicate(true),
		"asset_uniqueness_score": float(asset_pressure.get("asset_uniqueness_score", 0.0)),
		"place_scenario_bias": place_scenario_bias.duplicate(true),
		"place_pressure": place_pressure.duplicate(true),
		"place_conflict": place_conflict.duplicate(true),
		"place_tag_weights": place_tag_weights.duplicate(true),
		"place_tags": place_tags.duplicate(),
		"place_identity_summary": place_identity_summary.duplicate(true),
		"current_place_packet": current_place_packet.duplicate(true),
		"faction_scenario_bias": transient_player_bias.duplicate(true),
		"faction_pressure": faction_pressure.duplicate(true),
		"faction_hotspots": faction_hotspots.duplicate(true),
		"faction_kind_presence": faction_kind_presence.duplicate(true)
	}

func _collect_provider_nominations(context: Dictionary) -> Array:
	var out: Array = []
	var providers: Array = [
		gs.ai_event_engine,
		gs.narrative_engine,
		gs.dynamic_world_event_engine,
		gs.school_engine,
		gs.boxing_engine,
		gs.crime_engine,
		gs.artifacts_engine,
		gs.dragonballs_engine,
		gs.red_bonnet_engine,
		gs.afterlife_influence_engine,
		gs.fame_engine,
		gs.bending_engine
	]
	for provider in providers:
		if provider == null:
			continue
		if not provider.has_method("nominate_scenarios_for_player"):
			continue
		var raw = provider.nominate_scenarios_for_player(context)
		if typeof(raw) != TYPE_ARRAY:
			continue
		for nomination in raw:
			if typeof(nomination) != TYPE_DICTIONARY:
				continue
			if not _nomination_matches_context(nomination, context):
				continue
			out.append(_scored_nomination(nomination, context))
			if gs.event_bus != null:
				gs.event_bus.emit(ActionEventTypes.SCENARIO_NOMINATED, {
					"npc_id": gs.player.id if gs.player != null else -1,
					"scenario_id": str(nomination.get("id", "")),
					"category": str(nomination.get("category", "general")),
					"text": str(nomination.get("prompt", "")),
					"source": "scenario_engine"
				})
	out.sort_custom(func (a, b): return float(a.get("_score", 0.0)) > float(b.get("_score", 0.0)))
	return out

func _pick_bundle(scored_nominations: Array, context: Dictionary) -> Array:
	var out: Array = []
	var budgets: Dictionary = context.get("category_budgets", DEFAULT_CATEGORY_BUDGETS).duplicate(true)
	var used_categories: Dictionary = {}

	for nomination in scored_nominations:
		if out.size() >= MAX_SURFACED_PER_YEAR:
			break

		var category: String = str(nomination.get("category", "general"))
		var used_count: int = int(used_categories.get(category, 0))
		var budget: int = int(budgets.get(category, 1))

		if used_count >= budget:
			continue

		out.append(nomination.duplicate(true))
		used_categories [category] = used_count + 1

	return out

func _queue_bundle_item(index: int) -> Dictionary:
	var bundle_raw = gs.scenario_state.get("current_bundle", [])
	if typeof(bundle_raw) != TYPE_ARRAY or index < 0 or index >= bundle_raw.size():
		return {}
	var scenario: Dictionary = bundle_raw [index]
	var prompt: String = str(scenario.get("prompt", "A strange moment hangs in the air."))
	var lookup: Dictionary = {}
	var options: Array = []
	var choices = scenario.get("choices", [])
	if typeof(choices) == TYPE_ARRAY:
		for raw_choice in choices:
			if typeof(raw_choice) != TYPE_DICTIONARY:
				continue
			var choice: Dictionary = raw_choice
			var label: String = str(choice.get("label", "Choose"))
			if label == "":
				continue

			var option_payload: Dictionary = {
				"choice_id": label,
				"label": label,
				"disabled": bool(choice.get("disabled", false)),
				"tooltip": str(choice.get("tooltip", "")),
				"theme": str(choice.get("theme", "")),
				"tone": str(choice.get("tone", ""))
			}

			var passthrough_visual_keys: Array = [
				"id",
				"wish_id",
				"accent",
				"emoji",
				"text",
				"overview",
				"display_kind",
				"button_theme",
				"power_source",
				"stone_name",
				"stone_key",
				"choice_family",
				"nidavellir_battle_choice",
				"ability_element",
				"ability_name",
				"ability_id",
				"ability_type",
				"ability_level"
			]
			for visual_key in passthrough_visual_keys:
				if choice.has(visual_key):
					option_payload [visual_key] = choice.get(visual_key)

			options.append(option_payload)
			lookup [label] = choice.duplicate(true)

	gs.scenario_state ["current_bundle_index"] = index
	gs.scenario_state ["pending_type"] = "scenario_prompt"
	gs.scenario_state ["pending_text"] = prompt
	gs.scenario_state ["pending_panel_title"] = str(scenario.get("panel_title", "SCENARIO"))
	gs.scenario_state ["pending_footer_text"] = str(scenario.get("footer_text", "Choose how you want to respond."))
	gs.scenario_state ["pending_subtitle"] = str(scenario.get("subtitle", "Narrative as Pressure Injection"))
	gs.scenario_state ["pending_accent"] = str(scenario.get("accent", "#B56BFF"))
	gs.scenario_state ["pending_emoji"] = str(scenario.get("emoji", "✦"))
	gs.scenario_state ["pending_theme"] = str(scenario.get("theme", ""))
	gs.scenario_state ["pending_combat_ui"] = scenario.get("combat_ui", {})
	gs.scenario_state ["pending_surface_timing"] = str(scenario.get("surface_timing", "post_age_up")).strip_edges().to_lower()
	gs.scenario_state ["pending_allows_pre_year_age_up_surface"] = bool(scenario.get("allows_pre_year_age_up_surface", false))
	gs.scenario_state ["pending_blocks_age_up_before_time_resolves"] = bool(scenario.get("blocks_age_up_before_time_resolves", false))
	gs.scenario_state ["pending_source"] = str(scenario.get("source", "scenario_engine"))
	gs.scenario_state ["pending_lookup"] = lookup
	gs.scenario_state ["pending_options"] = options
	if gs.event_bus != null:
		gs.event_bus.emit(ActionEventTypes.SCENARIO_SURFACED, {
			"npc_id": gs.player.id if gs.player != null else -1,
			"scenario_id": str(scenario.get("id", "")),
			"category": str(scenario.get("category", "general")),
			"text": prompt,
			"source": "scenario_engine"
		})
	return get_pending_choice_result()

func _clear_pending_choice() -> void:
	gs.scenario_state ["pending_type"] = ""
	gs.scenario_state ["pending_text"] = ""
	gs.scenario_state ["pending_lookup"] = {}
	gs.scenario_state ["pending_options"] = []

func _nomination_matches_context(nomination: Dictionary, context: Dictionary) -> bool:
	if not nomination.has("id"):
		return false
	if str(nomination.get("prompt", "")).strip_edges() == "":
		return false

	var choices_raw = nomination.get("choices", [])
	if typeof(choices_raw) != TYPE_ARRAY or choices_raw.is_empty():
		return false

	var age: int = int(context.get("age", 0))
	var min_age: int = int(nomination.get("min_age", -999999))
	var max_age: int = int(nomination.get("max_age", 999999))
	if age < min_age or age > max_age:
		return false

	var era_tags_raw = nomination.get("era_tags", [])
	if typeof(era_tags_raw) == TYPE_ARRAY and not era_tags_raw.is_empty():
		var era_name: String = str(context.get("era_name", ""))
		var matched:= false
		for tag in era_tags_raw:
			var t:= str(tag)
			if t == "any" or t == era_name:
				matched = true
				break
		if not matched:
			return false

	var reality_modes = nomination.get("reality_modes", [])
	if typeof(reality_modes) == TYPE_ARRAY and not reality_modes.is_empty():
		var reality_mode: String = str(context.get("reality_mode", "chaos"))
		if reality_mode not in reality_modes:
			return false

	var cooldown_key: String = str(nomination.get("cooldown_key", "")).strip_edges()
	if cooldown_key != "" and _cooldown_active(cooldown_key):
		return false

	var asset_pressure: Dictionary = context.get("asset_pressure", {})

	var asset_event_hooks: Dictionary = asset_pressure.get("event_hooks", {})
	if typeof(asset_event_hooks) != TYPE_DICTIONARY:
		asset_event_hooks = {}

	var asset_portfolio_tags: Dictionary = asset_pressure.get("portfolio_tags", {})
	if typeof(asset_portfolio_tags) != TYPE_DICTIONARY:
		asset_portfolio_tags = {}

	var asset_status_signals: Dictionary = asset_pressure.get("status_signals", asset_pressure.get("prestige_signals", {}))
	if typeof(asset_status_signals) != TYPE_DICTIONARY:
		asset_status_signals = {}

	var asset_pressure_profile: Dictionary = asset_pressure.get("pressure_profile", {})
	if typeof(asset_pressure_profile) != TYPE_DICTIONARY:
		asset_pressure_profile = {}

	var asset_namespaces: Dictionary = asset_pressure.get("asset_namespaces", {})
	if typeof(asset_namespaces) != TYPE_DICTIONARY:
		asset_namespaces = {}

	var available_asset_class_filters: Dictionary = asset_pressure.get("asset_class_filters", {})
	if typeof(available_asset_class_filters) != TYPE_DICTIONARY:
		available_asset_class_filters = {}

	var asset_identity_modes: Dictionary = asset_pressure.get("asset_identity_modes", {})
	if typeof(asset_identity_modes) != TYPE_DICTIONARY:
		asset_identity_modes = {}

	var asset_provenance_signals: Dictionary = asset_pressure.get("asset_provenance_signals", {})
	if typeof(asset_provenance_signals) != TYPE_DICTIONARY:
		asset_provenance_signals = {}

	var asset_condition_profile: Dictionary = asset_pressure.get("asset_condition_profile", {})
	if typeof(asset_condition_profile) != TYPE_DICTIONARY:
		asset_condition_profile = {}

	var required_asset_event_hooks = nomination.get("required_asset_event_hooks", [])
	if typeof(required_asset_event_hooks) == TYPE_ARRAY:
		for raw_hook in required_asset_event_hooks:
			if int(asset_event_hooks.get(str(raw_hook), 0)) <= 0:
				return false

	var asset_exclusion_hooks = nomination.get("asset_exclusion_hooks", [])
	if typeof(asset_exclusion_hooks) == TYPE_ARRAY:
		for raw_hook in asset_exclusion_hooks:
			if int(asset_event_hooks.get(str(raw_hook), 0)) > 0:
				return false

	var required_asset_portfolio_tags = nomination.get("required_asset_portfolio_tags", [])
	if typeof(required_asset_portfolio_tags) == TYPE_ARRAY:
		for raw_tag in required_asset_portfolio_tags:
			if int(asset_portfolio_tags.get(str(raw_tag), 0)) <= 0:
				return false

	var min_asset_status_signals = nomination.get("min_asset_status_signals", {})
	if typeof(min_asset_status_signals) == TYPE_DICTIONARY:
		for key in min_asset_status_signals.keys():
			if float(asset_status_signals.get(str(key), 0.0)) < float(min_asset_status_signals.get(key, 0.0)):
				return false

	var min_asset_pressure_profile = nomination.get("min_asset_pressure_profile", {})
	if typeof(min_asset_pressure_profile) == TYPE_DICTIONARY:
		for key in min_asset_pressure_profile.keys():
			if float(asset_pressure_profile.get(str(key), 0.0)) < float(min_asset_pressure_profile.get(key, 0.0)):
				return false

	var min_asset_provenance_signals = nomination.get("min_asset_provenance_signals", {})
	if typeof(min_asset_provenance_signals) == TYPE_DICTIONARY:
		for key in min_asset_provenance_signals.keys():
			if float(asset_provenance_signals.get(str(key), 0.0)) < float(min_asset_provenance_signals.get(key, 0.0)):
				return false

	var min_asset_condition_profile = nomination.get("min_asset_condition_profile", {})
	if typeof(min_asset_condition_profile) == TYPE_DICTIONARY:
		for key in min_asset_condition_profile.keys():
			if float(asset_condition_profile.get(str(key), 0.0)) < float(min_asset_condition_profile.get(key, 0.0)):
				return false

	var namespace_preferences = nomination.get("asset_namespace_preferences", null)
	if _asset_filter_defined(namespace_preferences) and not _asset_filter_matches_any(namespace_preferences, asset_namespaces):
		return false

	var class_filters = nomination.get("asset_class_filters", null)
	if _asset_filter_defined(class_filters) and not _asset_filter_matches_any(class_filters, available_asset_class_filters):
		return false

	var identity_mode_filter = nomination.get("asset_identity_mode", null)
	if _asset_filter_defined(identity_mode_filter) and not _asset_filter_matches_any(identity_mode_filter, asset_identity_modes):
		return false

	var asset_tier_floor: float = float(nomination.get("asset_tier_floor", -1.0))
	if asset_tier_floor >= 0.0 and float(asset_pressure.get("max_asset_tier_score", 0.0)) < asset_tier_floor:
		return false

	var max_asset_dependency_pressure: float = float(nomination.get("max_asset_dependency_pressure", -1.0))
	if max_asset_dependency_pressure >= 0.0 and float(asset_pressure.get("dependency_pressure", 0.0)) > max_asset_dependency_pressure:
		return false
	var place_tag_weights: Dictionary = context.get("place_tag_weights", {})
	if typeof(place_tag_weights) != TYPE_DICTIONARY:
		place_tag_weights = {}

	var place_pressure: Dictionary = context.get("place_pressure", {})
	if typeof(place_pressure) != TYPE_DICTIONARY:
		place_pressure = {}

	var place_conflict: Dictionary = context.get("place_conflict", {})
	if typeof(place_conflict) != TYPE_DICTIONARY:
		place_conflict = {}

	var required_place_tags = nomination.get("required_place_tags", [])
	if typeof(required_place_tags) == TYPE_ARRAY:
		for raw_tag in required_place_tags:
			if float(place_tag_weights.get(str(raw_tag), 0.0)) <= 0.0:
				return false

	var excluded_place_tags = nomination.get("excluded_place_tags", [])
	if typeof(excluded_place_tags) == TYPE_ARRAY:
		for raw_tag in excluded_place_tags:
			if float(place_tag_weights.get(str(raw_tag), 0.0)) > 0.0:
				return false

	var min_place_pressure = nomination.get("min_place_pressure", {})
	if typeof(min_place_pressure) == TYPE_DICTIONARY:
		for key in min_place_pressure.keys():
			if float(place_pressure.get(str(key), 0.0)) < float(min_place_pressure.get(key, 0.0)):
				return false

	var max_place_pressure = nomination.get("max_place_pressure", {})
	if typeof(max_place_pressure) == TYPE_DICTIONARY:
		for key in max_place_pressure.keys():
			if float(place_pressure.get(str(key), 0.0)) > float(max_place_pressure.get(key, 999.0)):
				return false

	var max_place_conflict = nomination.get("max_place_conflict", {})
	if typeof(max_place_conflict) == TYPE_DICTIONARY:
		for key in max_place_conflict.keys():
			if float(place_conflict.get(str(key), 0.0)) > float(max_place_conflict.get(key, 999.0)):
				return false
	return true

func _scored_nomination(nomination: Dictionary, context: Dictionary) -> Dictionary:
	var out: Dictionary = nomination.duplicate(true)
	var base_score: float = float(nomination.get("priority", 0.0))
	var rarity: float = clamp(float(nomination.get("rarity", 0.5)), 0.0, 1.0)
	base_score += (1.0 - rarity) * 8.0

	var reality_weights = nomination.get("reality_weights", {})
	if typeof(reality_weights) == TYPE_DICTIONARY:
		var reality_mode: String = str(context.get("reality_mode", "chaos"))
		if reality_weights.has(reality_mode):
			base_score *= float(reality_weights [reality_mode])

	var asset_pressure: Dictionary = context.get("asset_pressure", {})
	var asset_event_hooks: Dictionary = asset_pressure.get("event_hooks", {})
	if typeof(asset_event_hooks) != TYPE_DICTIONARY:
		asset_event_hooks = {}

	var asset_portfolio_tags: Dictionary = asset_pressure.get("portfolio_tags", {})
	if typeof(asset_portfolio_tags) != TYPE_DICTIONARY:
		asset_portfolio_tags = {}

	var asset_status_signals: Dictionary = asset_pressure.get("status_signals", asset_pressure.get("prestige_signals", {}))
	if typeof(asset_status_signals) != TYPE_DICTIONARY:
		asset_status_signals = {}

	var asset_pressure_profile: Dictionary = asset_pressure.get("pressure_profile", {})
	if typeof(asset_pressure_profile) != TYPE_DICTIONARY:
		asset_pressure_profile = {}

	var passive_modifiers: Dictionary = asset_pressure.get("passive_modifiers", {})
	if typeof(passive_modifiers) != TYPE_DICTIONARY:
		passive_modifiers = {}

	var asset_namespaces: Dictionary = asset_pressure.get("asset_namespaces", {})
	if typeof(asset_namespaces) != TYPE_DICTIONARY:
		asset_namespaces = {}

	var available_asset_class_filters: Dictionary = asset_pressure.get("asset_class_filters", {})
	if typeof(available_asset_class_filters) != TYPE_DICTIONARY:
		available_asset_class_filters = {}

	var asset_identity_modes: Dictionary = asset_pressure.get("asset_identity_modes", {})
	if typeof(asset_identity_modes) != TYPE_DICTIONARY:
		asset_identity_modes = {}

	var asset_provenance_signals: Dictionary = asset_pressure.get("asset_provenance_signals", {})
	if typeof(asset_provenance_signals) != TYPE_DICTIONARY:
		asset_provenance_signals = {}

	var asset_condition_profile: Dictionary = asset_pressure.get("asset_condition_profile", {})
	if typeof(asset_condition_profile) != TYPE_DICTIONARY:
		asset_condition_profile = {}

	var weighted_event_hooks = nomination.get("asset_weight_event_hooks", [])
	if typeof(weighted_event_hooks) == TYPE_ARRAY:
		for raw_hook in weighted_event_hooks:
			base_score += min(3.0, float(asset_event_hooks.get(str(raw_hook), 0))) * 2.25

	var weighted_portfolio_tags = nomination.get("asset_weight_portfolio_tags", [])
	if typeof(weighted_portfolio_tags) == TYPE_ARRAY:
		for raw_tag in weighted_portfolio_tags:
			base_score += min(3.0, float(asset_portfolio_tags.get(str(raw_tag), 0))) * 2.0

	var weighted_status_signals = nomination.get("asset_weight_status_signals", {})
	if typeof(weighted_status_signals) == TYPE_DICTIONARY:
		for key in weighted_status_signals.keys():
			base_score += min(float(weighted_status_signals.get(key, 0.0)), float(asset_status_signals.get(str(key), 0.0)))

	var weighted_pressure_profile = nomination.get("asset_weight_pressure_profile", {})
	if typeof(weighted_pressure_profile) == TYPE_DICTIONARY:
		for key in weighted_pressure_profile.keys():
			base_score += min(float(weighted_pressure_profile.get(key, 0.0)), float(asset_pressure_profile.get(str(key), 0.0)))

	var weighted_passive_modifiers = nomination.get("asset_weight_passive_modifiers", {})
	if typeof(weighted_passive_modifiers) == TYPE_DICTIONARY:
		for key in weighted_passive_modifiers.keys():
			base_score += min(float(weighted_passive_modifiers.get(key, 0.0)), float(passive_modifiers.get(str(key), 0.0)))

	var weighted_provenance_signals = nomination.get("asset_weight_provenance_signals", {})
	if typeof(weighted_provenance_signals) == TYPE_DICTIONARY:
		for key in weighted_provenance_signals.keys():
			base_score += min(float(weighted_provenance_signals.get(key, 0.0)), float(asset_provenance_signals.get(str(key), 0.0)))

	var weighted_condition_profile = nomination.get("asset_weight_condition_profile", {})
	if typeof(weighted_condition_profile) == TYPE_DICTIONARY:
		for key in weighted_condition_profile.keys():
			base_score += min(float(weighted_condition_profile.get(key, 0.0)), float(asset_condition_profile.get(str(key), 0.0)))

	base_score += _score_asset_filter(nomination.get("asset_namespace_preferences", null), asset_namespaces, 2.35)
	base_score += _score_asset_filter(nomination.get("asset_class_filters", null), available_asset_class_filters, 1.55)
	base_score += _score_asset_filter(nomination.get("asset_identity_mode", null), asset_identity_modes, 1.9)

	var asset_tier_floor: float = float(nomination.get("asset_tier_floor", -1.0))
	if asset_tier_floor >= 0.0:
		base_score += max(0.0, float(asset_pressure.get("max_asset_tier_score", 0.0)) - asset_tier_floor) * 1.15

	base_score += min(float(nomination.get("asset_uniqueness_bias", 0.0)), float(asset_pressure.get("asset_uniqueness_score", 0.0)))

	var category: String = str(nomination.get("category", "general"))
	match category:
		"crime":
			base_score += min(6.0, float(asset_pressure_profile.get("criminal_usefulness", 0.0)) * 2.0)
			base_score += min(4.0, float(asset_event_hooks.get("smuggling", 0)) * 1.5)
			base_score += min(3.5, float(asset_event_hooks.get("store_contraband", 0)) * 1.5)
		"social":
			base_score += min(6.0, float(asset_pressure_profile.get("romance_signal", 0.0)) * 1.5)
			base_score += min(5.0, float(asset_pressure_profile.get("spectacle", 0.0)) * 1.5)
			base_score += min(4.0, float(asset_event_hooks.get("party_hosting", 0)) * 1.25)
			base_score += min(4.0, float(asset_event_hooks.get("celebrity_sightings", 0)) * 1.25)
		"career":
			base_score += min(4.0, float(passive_modifiers.get("travel_access", 0.0)) * 1.25)
			base_score += min(4.0, float(passive_modifiers.get("region_mobility", 0.0)) * 1.25)
			base_score += min(3.0, float(asset_status_signals.get("professional_signal", 0.0)) * 1.25)
		"general":
			base_score += min(6.0, float(asset_pressure_profile.get("upkeep", 0.0)) * 1.5)
			base_score += min(5.0, float(asset_event_hooks.get("inheritance_drama", 0)) * 1.5)
			base_score += min(5.0, float(asset_event_hooks.get("eviction_risk", 0)) * 1.5)
			base_score += min(4.0, float(asset_pressure_profile.get("community_belonging", 0.0)) * 1.25)
			base_score += min(4.0, float(asset_status_signals.get("dynastic_legitimacy", 0.0)) * 1.25)

	var place_pressure: Dictionary = context.get("place_pressure", {})
	if typeof(place_pressure) != TYPE_DICTIONARY:
		place_pressure = {}

	var place_conflict: Dictionary = context.get("place_conflict", {})
	if typeof(place_conflict) != TYPE_DICTIONARY:
		place_conflict = {}

	var place_tag_weights: Dictionary = context.get("place_tag_weights", {})
	if typeof(place_tag_weights) != TYPE_DICTIONARY:
		place_tag_weights = {}

	var current_place_packet: Dictionary = context.get("current_place_packet", {})
	if typeof(current_place_packet) != TYPE_DICTIONARY:
		current_place_packet = {}

	var weighted_place_pressure = nomination.get("place_weight_pressure", {})
	if typeof(weighted_place_pressure) == TYPE_DICTIONARY:
		for key in weighted_place_pressure.keys():
			base_score += min(float(weighted_place_pressure.get(key, 0.0)), float(place_pressure.get(str(key), 0.0)))

	var weighted_place_conflict = nomination.get("place_weight_conflict", {})
	if typeof(weighted_place_conflict) == TYPE_DICTIONARY:
		for key in weighted_place_conflict.keys():
			base_score += min(float(weighted_place_conflict.get(key, 0.0)), float(place_conflict.get(str(key), 0.0)))

	var weighted_place_tags = nomination.get("place_weight_tags", [])
	if typeof(weighted_place_tags) == TYPE_ARRAY:
		for raw_tag in weighted_place_tags:
			base_score += min(2.0, float(place_tag_weights.get(str(raw_tag), 0.0))) * 1.25

	var faction_pressure: Dictionary = context.get("faction_pressure", {})
	if typeof(faction_pressure) != TYPE_DICTIONARY:
		faction_pressure = {}

	var faction_hotspots: Array = context.get("faction_hotspots", [])
	if typeof(faction_hotspots) != TYPE_ARRAY:
		faction_hotspots = []

	var faction_kind_presence: Dictionary = context.get("faction_kind_presence", faction_pressure.get("kind_presence", {}))
	if typeof(faction_kind_presence) != TYPE_DICTIONARY:
		faction_kind_presence = {}

	var weighted_faction_pressure = nomination.get("faction_weight_pressure", {})
	if typeof(weighted_faction_pressure) == TYPE_DICTIONARY:
		for key in weighted_faction_pressure.keys():
			base_score += min(float(weighted_faction_pressure.get(key, 0.0)), float(faction_pressure.get(str(key), 0.0)))

	var weighted_faction_kind_presence = nomination.get("faction_weight_kind_presence", {})
	if typeof(weighted_faction_kind_presence) == TYPE_DICTIONARY:
		for key in weighted_faction_kind_presence.keys():
			base_score += min(float(weighted_faction_kind_presence.get(key, 0.0)), float(faction_kind_presence.get(str(key), 0.0))) * 1.35

	var hottest_faction_pressure: float = 0.0
	var hottest_claim_pressure: float = 0.0
	var hottest_hidden_realm_instability: float = 0.0
	for hotspot_raw in faction_hotspots:
		if typeof(hotspot_raw) != TYPE_DICTIONARY:
			continue
		var hotspot: Dictionary = hotspot_raw
		hottest_faction_pressure = max(hottest_faction_pressure, float(hotspot.get("pressure", 0.0)))
		hottest_claim_pressure = max(hottest_claim_pressure, float(hotspot.get("claim_pressure", 0.0)))
		hottest_hidden_realm_instability = max(hottest_hidden_realm_instability, float(hotspot.get("hidden_realm_instability", 0.0)))

	match category:
		"school":
			base_score += min(8.0, float(current_place_packet.get("school_quality", 0.0)) * 8.0)
			base_score += min(5.0, float(place_pressure.get("discipline", 0.0)) * 4.0)
			base_score += min(3.0, float(place_pressure.get("ambition", 0.0)) * 2.0)
		"boxing":
			base_score += min(10.0, float(current_place_packet.get("boxing_density", 0.0)) * 10.0)
			base_score += min(5.0, float(place_pressure.get("fame_drive", 0.0)) * 3.0)
			base_score += min(4.0, float(place_pressure.get("risk", 0.0)) * 2.0)
			base_score += min(4.0, float(faction_kind_presence.get("boxing_division", 0.0)) * 1.5)
		"crime":
			base_score += min(10.0, float(current_place_packet.get("crime_pressure", 0.0)) * 10.0)
			base_score += min(6.0, float(place_pressure.get("violence", 0.0)) * 4.0)
			base_score += min(6.0, float(place_pressure.get("instability", 0.0)) * 4.0)
			base_score += min(10.0, float(faction_pressure.get("syndicate_turf_pressure", 0.0)) * 0.55)
			base_score += min(6.0, float(faction_pressure.get("claim_pressure_total", 0.0)) * 0.2)
			base_score += min(4.0, float(faction_kind_presence.get("crime_network", 0.0)) * 2.0)
		"career":
			base_score += min(8.0, float(current_place_packet.get("job_market", 0.0)) * 8.0)
			base_score += min(5.0, float(place_pressure.get("ambition", 0.0)) * 4.0)
			base_score += min(5.0, float(place_pressure.get("fame_drive", 0.0)) * 3.0)
			base_score += min(4.0, float(current_place_packet.get("royal_influence", 0.0)) * 4.0)
			base_score += min(5.0, float(faction_pressure.get("pressure_total", 0.0)) * 0.08)
			base_score += min(4.0, float(faction_pressure.get("coup_pressure", 0.0)) * 0.12)
			base_score += min(3.0, float(faction_kind_presence.get("political_bloc", 0.0)) * 1.5)
		"social":
			base_score += min(6.0, float(place_pressure.get("romance", 0.0)) * 4.0)
			base_score += min(7.0, float(place_pressure.get("social_openness", 0.0)) * 4.0)
			base_score += min(4.0, float(current_place_packet.get("fame_concentration", 0.0)) * 4.0)
			base_score += min(7.0, float(faction_pressure.get("royal_succession_tension", 0.0)) * 0.28)
			base_score += min(6.0, float(faction_pressure.get("diaspora_pull", 0.0)) * 0.24)
			base_score += min(4.0, float(hottest_faction_pressure) * 0.08)
		"afterlife":
			base_score += min(6.0, float(place_pressure.get("spirituality", 0.0)) * 4.0)
			base_score += min(5.0, float(current_place_packet.get("supernatural_presence", 0.0)) * 5.0)
			base_score += min(9.0, float(faction_pressure.get("hidden_realm_instability", 0.0)) * 0.6)
			base_score += min(5.0, hottest_hidden_realm_instability * 0.8)
			base_score += min(5.0, float(faction_pressure.get("contested_realm_tension", 0.0)) * 0.25)
		"general":
			base_score += min(4.0, float(place_conflict.get("total", 0.0)) * 3.0)
			base_score += min(4.0, float(place_pressure.get("instability", 0.0)) * 2.0)
			base_score += min(8.0, float(faction_pressure.get("coup_pressure", 0.0)) * 0.22)
			base_score += min(8.0, float(faction_pressure.get("royal_succession_tension", 0.0)) * 0.24)
			base_score += min(7.0, float(faction_pressure.get("diaspora_pull", 0.0)) * 0.18)
			base_score += min(8.0, float(faction_pressure.get("hidden_realm_instability", 0.0)) * 0.32)
			base_score += min(6.0, float(faction_pressure.get("contested_claims_total", 0.0)) * 1.25)
			base_score += min(5.0, float(faction_pressure.get("hostility_total", 0.0)) * 0.03)
			base_score += min(4.0, hottest_claim_pressure * 0.25)
		_:
			pass

	out ["_score"] = base_score + randf_range(0.0, 2.0)
	return out
func _player_mythic_pursuit_min_age() -> int:
	return 10

func _is_player_mythic_pursuit_allowed_for_owner(owner: Person) -> bool:
	if gs == null or owner == null:
		return false
	if gs.player == null:
		return false
	if int(owner.id) != int(gs.player.id):
		return true
	return int(owner.age) >= _player_mythic_pursuit_min_age()

func _clear_stale_player_mythic_pursuit_pending() -> void:
	_clear_pending_choice()
	gs.scenario_state ["current_bundle"] = []
	gs.scenario_state ["current_bundle_index"] = 0
	gs.scenario_state ["committed_choices"] = []
	gs.scenario_state ["waiting_for_year_advance"] = false

func _pending_player_mythic_pursuit_is_allowed() -> bool:
	_ensure_state()
	if gs == null:
		return true
	var bundle_raw = gs.scenario_state.get("current_bundle", [])
	if typeof(bundle_raw) != TYPE_ARRAY or bundle_raw.is_empty():
		return true
	var current_index: int = int(gs.scenario_state.get("current_bundle_index", 0))
	if current_index < 0 or current_index >= bundle_raw.size():
		return true
	var current_raw = bundle_raw [current_index]
	if typeof(current_raw) != TYPE_DICTIONARY:
		return true
	var current: Dictionary = current_raw
	if str(current.get("asset_arc_family", "")) != "npc_mythic_pursuit":
		return true
	var owner: Person = gs.get_or_reactivate_npc_by_id(int(current.get("mythic_owner_id", -1)))
	return _is_player_mythic_pursuit_allowed_for_owner(owner)
func _asset_filter_defined(raw) -> bool:
	match typeof(raw):
		TYPE_STRING:
			return str(raw).strip_edges() != ""
		TYPE_ARRAY:
			return not raw.is_empty()
		TYPE_DICTIONARY:
			return not raw.is_empty()
	return false


func _asset_filter_matches_any(raw, available: Dictionary) -> bool:
	match typeof(raw):
		TYPE_STRING:
			return float(available.get(str(raw), 0.0)) > 0.0
		TYPE_ARRAY:
			for raw_key in raw:
				if float(available.get(str(raw_key), 0.0)) > 0.0:
					return true
			return false
		TYPE_DICTIONARY:
			for key in raw.keys():
				if float(available.get(str(key), 0.0)) > 0.0:
					return true
			return false
	return false


func _score_asset_filter(raw, available: Dictionary, unit_multiplier: float = 1.0) -> float:
	var score: float = 0.0
	match typeof(raw):
		TYPE_STRING:
			score += min(3.0, float(available.get(str(raw), 0.0))) * unit_multiplier
		TYPE_ARRAY:
			for raw_key in raw:
				score += min(3.0, float(available.get(str(raw_key), 0.0))) * unit_multiplier
		TYPE_DICTIONARY:
			for key in raw.keys():
				var desired_weight: float = float(raw.get(key, unit_multiplier))
				score += min(desired_weight, float(available.get(str(key), 0.0)) * unit_multiplier)
	return score


func _tier_score_from_key(key: String) -> float:
	match key.to_lower():
		"entry":
			return 1.0
		"respectable":
			return 2.0
		"wealthy":
			return 3.0
		"noble":
			return 4.0
	return 0.0


func _max_asset_tier_score(profile: Dictionary) -> float:
	var best: float = 0.0
	for key in profile.keys():
		if float(profile.get(key, 0.0)) <= 0.0:
			continue
		best = max(best, _tier_score_from_key(str(key)))
	return best


func _compute_asset_uniqueness_score(
	asset_namespaces: Dictionary,
	asset_identity_modes: Dictionary,
	asset_provenance_signals: Dictionary,
	asset_count: int,
	max_asset_tier_score: float
) -> float:
	var score: float = 0.0
	score += float(asset_namespaces.size()) * 1.1
	score += float(asset_identity_modes.size()) * 0.9
	score += min(2.0, float(asset_provenance_signals.size()) * 0.6)
	score += max(0.0, max_asset_tier_score - 1.0) * 0.75
	if int(asset_count) == 1 and asset_namespaces.size() == 1:
		score += 0.7
	return score


func _infer_portfolio_mood_tags(
	_portfolio_tags: Dictionary,
	event_hooks: Dictionary,
	status_signals: Dictionary,
	pressure_profile: Dictionary,
	asset_namespaces: Dictionary,
	asset_identity_modes: Dictionary,
	asset_provenance_signals: Dictionary
) -> Dictionary:
	var out: Dictionary = {}

	var dynastic_weight: float = float(status_signals.get("dynastic_legitimacy", 0.0)) + float(asset_identity_modes.get("dynasty_seat", 0))
	var spectacle_weight: float = float(pressure_profile.get("spectacle", 0.0)) + float(asset_identity_modes.get("spectacle_carrier", 0))
	var criminal_weight: float = float(pressure_profile.get("criminal_usefulness", 0.0)) + float(asset_identity_modes.get("smuggling_channel", 0))
	var hardship_weight: float = float(event_hooks.get("eviction_risk", 0)) + float(event_hooks.get("housing_instability", 0)) + float(asset_namespaces.get("property.shack", 0))

	if float(asset_namespaces.get("property.castle", 0)) > 0.0 and dynastic_weight >= 1.0:
		out ["portfolio_mood.old_blood"] = 1

	if hardship_weight >= 1.0 and (float(asset_namespaces.get("vehicle.utility_truck", 0)) > 0.0 or float(pressure_profile.get("community_belonging", 0.0)) > 0.0):
		out ["portfolio_mood.survival_cluster"] = 1

	if (float(asset_namespaces.get("vehicle.yacht", 0)) > 0.0 or spectacle_weight >= 2.0) and float(status_signals.get("fame_visibility", 0.0)) >= 1.0:
		out ["portfolio_mood.spectacle_elite"] = 1

	if float(asset_namespaces.get("property.farmland", 0)) > 0.0 and dynastic_weight >= 1.0:
		out ["portfolio_mood.landed_power"] = 1

	if criminal_weight >= 1.5 and spectacle_weight >= 1.0:
		out ["portfolio_mood.criminal_glamour"] = 1

	if float(asset_provenance_signals.get("inherited", 0.0)) >= 1.0 and dynastic_weight >= 1.0:
		out ["portfolio_mood.inherited_order"] = 1

	return out

func _cooldown_active(cooldown_key: String) -> bool:
	var cooldowns = gs.scenario_state.get("cooldowns", {})
	if typeof(cooldowns) != TYPE_DICTIONARY:
		return false
	return int(cooldowns.get(cooldown_key, -999999)) >= int(gs.year)

func _apply_cooldown_from_scenario(scenario: Dictionary) -> void:
	var cooldown_key: String = str(scenario.get("cooldown_key", "")).strip_edges()
	if cooldown_key == "":
		return

	var cooldown_years: int = max(0, int(scenario.get("cooldown_years", 2)))
	var cooldowns = gs.scenario_state.get("cooldowns", {})
	if typeof(cooldowns) != TYPE_DICTIONARY:
		cooldowns = {}
	cooldowns [cooldown_key] = int(gs.year) + cooldown_years
	gs.scenario_state ["cooldowns"] = cooldowns

func _prune_expired_cooldowns() -> void:
	var cooldowns = gs.scenario_state.get("cooldowns", {})
	if typeof(cooldowns) != TYPE_DICTIONARY:
		gs.scenario_state ["cooldowns"] = {}
		return

	var cleaned:= {}
	for key in cooldowns.keys():
		var expiry_year: int = int(cooldowns [key])
		if expiry_year >= int(gs.year):
			cleaned [key] = expiry_year
	gs.scenario_state ["cooldowns"] = cleaned

func _register_followup_hooks(hooks_raw) -> void:
	if typeof(hooks_raw) != TYPE_ARRAY:
		return
	var hooks: Array = gs.scenario_state.get("recent_followup_hooks", [])
	for hook in hooks_raw:
		var s:= str(hook).strip_edges()
		if s != "" and s not in hooks:
			hooks.append(s)
	gs.scenario_state ["recent_followup_hooks"] = hooks

func _remember_recent_choice(committed: Dictionary) -> void:
	var recent: Array = gs.scenario_state.get("recent_choices", [])
	recent.append({
		"year": int(gs.year),
		"scenario_id": str(committed.get("scenario_id", "")),
		"choice_id": str(committed.get("choice_id", "")),
		"category": str(committed.get("category", "general"))
	})
	if recent.size() > 20:
		recent = recent.slice(recent.size() - 20, recent.size())
	gs.scenario_state ["recent_choices"] = recent

func _merge_into(target: Dictionary, incoming) -> void:
	if typeof(incoming) != TYPE_DICTIONARY:
		return

	for key in incoming.keys():
		var incoming_value = incoming [key]

		if not target.has(key):
			target [key] = incoming_value
			continue

		var current_value = target [key]

		if typeof(current_value) == TYPE_DICTIONARY and typeof(incoming_value) == TYPE_DICTIONARY:
			_merge_into(current_value, incoming_value)
			target [key] = current_value
		elif typeof(current_value) == TYPE_ARRAY and typeof(incoming_value) == TYPE_ARRAY:
			var merged: Array = current_value.duplicate()
			for item in incoming_value:
				if item not in merged:
					merged.append(item)
			target [key] = merged
		elif (typeof(current_value) in [TYPE_INT, TYPE_FLOAT]) and (typeof(incoming_value) in [TYPE_INT, TYPE_FLOAT]):
			target [key] = float(current_value) + float(incoming_value)
		else:
			target [key] = incoming_value