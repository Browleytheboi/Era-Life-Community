extends Resource
class_name BridgeToTerabithiaEngine

const TERABITHIA_ID:= "terabithia"
const TERABITHIA_NAME:= "Terabithia"
const IMAGINATION_UNLOCK_THRESHOLD:= 90

var gs

func _init(_gs):
	gs = _gs

func _default_state() -> Dictionary:
	return {
		"belief_flag": false,
		"curiosity_level": 0,
		"hesitation_count": 0,
		"leslie_known": false,
		"discovered": false,
		"entered": false,
		"last_visit_year": -999999,
		"last_invitation_year": -999999,
		"emotional_resonance": 0,
		"journey_stage": "",
		"access_unlocked": false
	}

func ensure_person_imagination_state(person: Person) -> void:
	if person == null:
		return
	if int(person.imagination) <= 0:
		person.imagination = randi_range(1, 79)
	var merged:= _default_state()
	if typeof(person.terabithia_state) == TYPE_DICTIONARY:
		for key in person.terabithia_state.keys():
			merged [str(key)] = person.terabithia_state [key]
	person.terabithia_state = merged

func yearly_tick(_payload:= {}) -> void:
	if gs == null or gs.player == null or not gs.player.alive:
		return
	var player: Person = gs.player
	ensure_person_imagination_state(player)
	var state: Dictionary = player.terabithia_state
	_apply_passive_imagination_drift(player, state)
	_apply_distance_from_terabithia_effects(player, state)
	if int(player.imagination) >= IMAGINATION_UNLOCK_THRESHOLD:
		state ["access_unlocked"] = true
		_queue_leslie_invitation_if_ready(player, state)

func _apply_passive_imagination_drift(player: Person, state: Dictionary) -> void:
	var delta:= 0
	if int(player.age) <= 12:
		delta += randi_range(1, 3)
	elif int(player.age) <= 18:
		delta += randi_range(0, 2)
	elif bool(state.get("entered", false)):
		delta += 1
	if float(player.mental_health) >= 70.0:
		delta += 1
	if float(player.satisfaction) >= 70.0:
		delta += 1
	if bool(state.get("belief_flag", false)):
		delta += 1
	if delta <= 0:
		return
	player.imagination = clamp(int(player.imagination) + delta, 0, 100)

func _apply_distance_from_terabithia_effects(player: Person, state: Dictionary) -> void:
	if not bool(state.get("discovered", false)):
		return
	if int(player.imagination) >= 60:
		return
	player.satisfaction = clamp(int(player.satisfaction) - 1, 0, 100)
	player.mental_health = clamp(int(player.mental_health) - 1, 0, 100)

func _queue_leslie_invitation_if_ready(player: Person, state: Dictionary) -> void:
	if gs == null or gs.scenario_engine == null:
		return
	if bool(state.get("discovered", false)):
		return
	if int(state.get("last_invitation_year", -999999)) == int(gs.year):
		return
	if bool(gs.scenario_state.get("waiting_for_year_advance", false)):
		return
	if str(gs.scenario_state.get("pending_type", "")).strip_edges() != "":
		return
	var result: Dictionary = gs.scenario_engine.queue_external_scenario(_build_leslie_invitation_scenario(player))
	if typeof(result) == TYPE_DICTIONARY and not result.is_empty():
		state ["leslie_known"] = true
		state ["last_invitation_year"] = int(gs.year)

func get_surface_entry_for_player() -> Dictionary:
	if gs == null or gs.player == null:
		return {}
	var player: Person = gs.player
	ensure_person_imagination_state(player)
	var state: Dictionary = player.terabithia_state
	var discovered: bool = bool(state.get("discovered", false))
	var access_unlocked: bool = bool(state.get("access_unlocked", false))
	var leslie_known: bool = bool(state.get("leslie_known", false))
	var veiled: bool = not discovered
	var view_only: bool = not discovered and not access_unlocked and not leslie_known
	var imagination_ratio: float = clamp(float(player.imagination) / 100.0, 0.0, 1.0)
	var population: int = int(round(3000000000.0 + (imagination_ratio * 2000000000.0)))
	var imaginative_power: int = int(round(750000000000.0 + (imagination_ratio * 2250000000000.0)))
	var protectors: int = int(round(180000000.0 + (imagination_ratio * 520000000.0)))
	var zone_count: int = 4
	var realm:= {
		"id": TERABITHIA_ID,
		"name": TERABITHIA_NAME,
		"realm_kind": "imaginative_realm",
		"realm_type": "imagination_bound",
		"dimension_type": "imaginative_realm",
		"entry_method": "scenario_chain",
		"visibility_rule": "belief + choices + emotional_state",
		"persistence": "semi-volatile",
		"is_country_surface": true,
		"browser_visual_theme": "terabithia",
		"overview_visual_theme": "terabithia",
		"hide_country_action_migrate": true,
		"show_country_action_vacation": false,
		"show_country_action_find_date": false,
		"hide_country_actions_in_overview": true,
		"surface_view_only": view_only,
		"population": population,
		"military": protectors,
		"military_units": protectors,
		"military_stockpile": protectors,
		"military_label": "Protectors",
		"protectors": protectors,
		"treasury": imaginative_power,
		"currency_name": "Imaginative Power",
		"treasury_label": "Imaginative Power",
		"government_style": "Perception-Bound Mythic Domain",
		"ruler_name": "No fixed ruler",
		"leader_title": "Guide",
		"guide_name": "Leslie",
		"imagination_ratio": imagination_ratio,
		"browser_aura_strength": lerpf(0.2, 1.0, imagination_ratio),
		"browser_aura_bg_alpha": lerpf(0.08, 0.28, imagination_ratio),
		"browser_aura_shadow_alpha": lerpf(0.18, 0.58, imagination_ratio),
		"browser_aura_shadow_size": int(round(28.0 + (imagination_ratio * 24.0))),
		"browser_aura_pulse_low": Color(
			1.02 + (imagination_ratio * 0.08),
			1.01 + (imagination_ratio * 0.05),
			1.08 + (imagination_ratio * 0.1),
			1.0
		),
		"browser_aura_pulse_high": Color(
			1.08 + (imagination_ratio * 0.16),
			1.04 + (imagination_ratio * 0.1),
			1.16 + (imagination_ratio * 0.14),
			1.0
		),
		"overview_aura_bg_alpha": lerpf(0.9, 0.985, imagination_ratio),
		"overview_aura_shadow_alpha": lerpf(0.22, 0.46, imagination_ratio),
		"overview_aura_shadow_size": int(round(18.0 + (imagination_ratio * 16.0))),
		"overview_border_alpha": lerpf(0.72, 0.96, imagination_ratio),
		"overview_clip_bg_alpha": lerpf(0.56, 0.82, imagination_ratio),
		"overview_clip_border_alpha": lerpf(0.14, 0.34, imagination_ratio),
		"overview_title_shadow_alpha": lerpf(0.14, 0.34, imagination_ratio),
		"overview_text_alpha": lerpf(0.88, 0.99, imagination_ratio),
		"overview_marquee_gap": 0.0,
		"overview_marquee_speed": lerpf(62.0, 74.0, imagination_ratio),
		"overview_marquee_panel_min_height": lerpf(68.0, 76.0, imagination_ratio),
		"overview_marquee_title_font_size": int(round(lerpf(14.0, 15.0, imagination_ratio))),
		"overview_marquee_visible_width": lerpf(760.0, 920.0, imagination_ratio),
		"overview_marquee_clip_height": lerpf(21.0, 23.0, imagination_ratio),
		"overview_marquee_track_height": lerpf(21.0, 23.0, imagination_ratio),
		"overview_marquee_text_y": lerpf(0.0, 1.0, imagination_ratio),
		"veil_state": "veiled" if veiled else "revealed",
		"access_state": "view_only" if view_only else ("revealed" if discovered else "stirring"),
		"notable_zones": [
			"The Bridge",
			"Leslie's Room",
			"The Battlefield",
			"Broken Rope Creek"
		],
		"subzones": [
			"The Bridge",
			"Leslie's Room",
			"The Battlefield",
			"Broken Rope Creek"
		],
		"subzone_count": zone_count,
		"description": "A realm that bends around belief, memory, emotional courage, and the living force of imagination."
	}
	return {
		"entry_kind": "imaginative_realm",
		"entry_id": TERABITHIA_ID,
		"name": TERABITHIA_NAME,
		"realm": realm,
		"_sort_priority": 5
	}

func _build_leslie_invitation_scenario(_actor: Person) -> Dictionary:
	return {
		"id": "terabithia_invitation",
		"source": "bridge_to_terabithia_engine",
		"category": "social",
		"cooldown_key": "terabithia_invitation",
		"resolver_method": "_resolve_terabithia_choice",
		"prompt": "A girl named Leslie tells you about a kingdom called Terabithia. She says she felt your imagination rising.",
		"choices": [
			{
				"id": "go_with_leslie",
				"label": "Go with her",
				"journal_text": "I followed Leslie toward something I could not explain.",
				"set_belief": true,
				"curiosity_delta": 2,
				"hesitation_delta": 0,
				"imagination_delta": 2,
				"next_stage": "forest_entry"
			},
			{
				"id": "laugh_it_off",
				"label": "Laugh it off",
				"journal_text": "I laughed it off and acted like the whole thing was nonsense.",
				"set_belief": false,
				"curiosity_delta": -1,
				"hesitation_delta": 1,
				"imagination_delta": -2,
				"result_text": "Leslie studies you for a second, then lets the moment go."
			},
			{
				"id": "ask_questions",
				"label": "Ask questions",
				"journal_text": "I asked Leslie questions instead of turning away.",
				"set_belief": true,
				"curiosity_delta": 3,
				"hesitation_delta": 0,
				"imagination_delta": 1,
				"next_stage": "forest_entry"
			},
			{
				"id": "ignore_her",
				"label": "Ignore her",
				"journal_text": "I ignored Leslie even though something in me wanted to listen.",
				"set_belief": false,
				"curiosity_delta": -2,
				"hesitation_delta": 1,
				"imagination_delta": -1,
				"result_text": "You walk away, and the air around the moment goes flat."
			}
		]
	}

func _build_forest_entry_scenario(_actor: Person) -> Dictionary:
	return {
		"id": "terabithia_forest_entry",
		"source": "bridge_to_terabithia_engine",
		"category": "social",
		"cooldown_key": "terabithia_forest_entry",
		"resolver_method": "_resolve_terabithia_choice",
		"prompt": "The trees feel different here. The forest seems to listen as Leslie leads you deeper in.",
		"choices": [
			{
				"id": "stay_close",
				"label": "Stay close",
				"journal_text": "I stayed close to Leslie as the forest changed around us.",
				"set_belief": true,
				"curiosity_delta": 1,
				"hesitation_delta": 0,
				"imagination_delta": 1,
				"next_stage": "bridge_crossing"
			},
			{
				"id": "explore",
				"label": "Explore",
				"journal_text": "I let myself explore instead of clinging to what felt normal.",
				"set_belief": true,
				"curiosity_delta": 2,
				"hesitation_delta": 0,
				"imagination_delta": 2,
				"next_stage": "bridge_crossing"
			},
			{
				"id": "turn_back",
				"label": "Turn back",
				"journal_text": "I turned back before the forest could become something else.",
				"set_belief": false,
				"curiosity_delta": -1,
				"hesitation_delta": 1,
				"result_text": "The path loses its charge, and the forest becomes ordinary again."
			}
		]
	}

func _build_bridge_crossing_scenario(_actor: Person) -> Dictionary:
	return {
		"id": "terabithia_bridge_crossing",
		"source": "bridge_to_terabithia_engine",
		"category": "social",
		"cooldown_key": "terabithia_bridge_crossing",
		"resolver_method": "_resolve_terabithia_choice",
		"prompt": "A rope hangs across the creek. Leslie looks back at you. Beyond it, the world feels thinner.",
		"choices": [
			{
				"id": "cross_confidently",
				"label": "Cross confidently",
				"journal_text": "I crossed like I already believed the other side was real.",
				"set_belief": true,
				"curiosity_delta": 1,
				"hesitation_delta": 0,
				"imagination_delta": 2,
				"next_stage": "arrival_gate"
			},
			{
				"id": "hesitate",
				"label": "Hesitate",
				"journal_text": "I hesitated at the bridge, but I did not leave.",
				"set_belief": true,
				"curiosity_delta": 1,
				"hesitation_delta": 1,
				"imagination_delta": 0,
				"next_stage": "arrival_gate"
			},
			{
				"id": "refuse",
				"label": "Refuse",
				"journal_text": "I refused the crossing and let the possibility close on me.",
				"set_belief": false,
				"curiosity_delta": -2,
				"hesitation_delta": 2,
				"imagination_delta": -1,
				"result_text": "The creek becomes only a creek again."
			}
		]
	}

func _resolve_terabithia_choice(actor: Person, _scenario: Dictionary, choice: Dictionary, _committed: Dictionary) -> Dictionary:
	if actor == null:
		return {}
	ensure_person_imagination_state(actor)
	var state: Dictionary = actor.terabithia_state
	if choice.has("set_belief"):
		state ["belief_flag"] = bool(choice.get("set_belief", false))
	state ["curiosity_level"] = max(0, int(state.get("curiosity_level", 0)) + int(choice.get("curiosity_delta", 0)))
	state ["hesitation_count"] = max(0, int(state.get("hesitation_count", 0)) + int(choice.get("hesitation_delta", 0)))
	actor.imagination = clamp(int(actor.imagination) + int(choice.get("imagination_delta", 0)), 0, 100)
	var next_stage: String = str(choice.get("next_stage", "")).strip_edges()
	match next_stage:
		"forest_entry":
			state ["journey_stage"] = "forest_entry"
			return gs.scenario_engine.queue_external_scenario(_build_forest_entry_scenario(actor))
		"bridge_crossing":
			state ["journey_stage"] = "bridge_crossing"
			return gs.scenario_engine.queue_external_scenario(_build_bridge_crossing_scenario(actor))
		"arrival_gate":
			state ["journey_stage"] = "arrival_gate"
			return _resolve_arrival_gate(actor, state)
	var result_text: String = str(choice.get("result_text", "The moment passes, but something in you remembers it.")).strip_edges()
	return {
		"type": "scenario_commit_complete",
		"text": result_text,
		"opps": []
	}

func _resolve_arrival_gate(actor: Person, state: Dictionary) -> Dictionary:
	if _passes_access_gate(actor, state):
		state ["discovered"] = true
		state ["entered"] = true
		state ["last_visit_year"] = int(gs.year)
		state ["journey_stage"] = "entered"
		state ["emotional_resonance"] = int(state.get("emotional_resonance", 0)) + 15
		actor.satisfaction = clamp(int(actor.satisfaction) + 8, 0, 100)
		actor.mental_health = clamp(int(actor.mental_health) + 5, 0, 100)
		if gs != null and gs.has_method("push_world_feed"):
			gs.push_world_feed("%s %s crossed into Terabithia." % [actor.first_name, actor.last_name], {
				"category": "realm_discovery",
				"event_name": "terabithia_discovered",
				"source": "bridge_to_terabithia_engine",
				"npc_id": int(actor.id),
				"personally_relevant": int(actor.id) == int(gs.player.id)
			})
		return {
			"type": "scenario_commit_complete",
			"text": "The world shifts...\nYou are no longer in the same place.\nLeslie smiles as Terabithia opens around you.",
			"opps": []
		}
	actor.mental_health = clamp(int(actor.mental_health) - 2, 0, 100)
	return {
		"type": "scenario_commit_complete",
		"text": "You blink... and it is just a forest again.",
		"opps": []
	}

func _passes_access_gate(actor: Person, state: Dictionary) -> bool:
	if actor == null:
		return false
	if int(actor.imagination) < IMAGINATION_UNLOCK_THRESHOLD:
		return false
	if not bool(state.get("belief_flag", false)):
		return false
	if int(state.get("curiosity_level", 0)) < 2:
		return false
	if int(state.get("hesitation_count", 0)) > 1:
		return false
	return true