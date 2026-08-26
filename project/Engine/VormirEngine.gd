extends Resource
class_name VormirEngine

const VORMIR_ID:= "vormir"
const VORMIR_NAME:= "Vormir"
const RED_SKULL_NAME:= "Red Skull"
const SOUL_STONE_REQUIRED_BOND_YEARS:= 15
const SOUL_STONE_REQUIRED_AFFECTION:= 85
const SOUL_SACRIFICE_TRAIT:= "SoulStoneSacrifice"

var gs

func _init(_gs):
	gs = _gs
	_ensure_state()


func _ensure_state() -> Dictionary:
	if gs == null:
		return {}
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	var state_raw: Variant = gs.scenario_state.get("vormir_state", {})
	var state: Dictionary = state_raw if typeof(state_raw) == TYPE_DICTIONARY else {}
	if not state.has("bond_years"):
		state ["bond_years"] = {}
	if not state.has("visited_alone_year"):
		state ["visited_alone_year"] = -999999
	if not state.has("sacrifices"):
		state ["sacrifices"] = []
	gs.scenario_state ["vormir_state"] = state
	return state


func yearly_tick(
	_payload:= {}
) -> void:
	if (
		gs == null
		or gs.player == null
		or not gs.player.alive
	):
		return

	var payload: Dictionary = (
		_payload as Dictionary
		if typeof(
			_payload
		) == TYPE_DICTIONARY
		else {}
	)

	var runtime_managed_age_up: bool = (
		bool(
			payload.get(
				"runtime_managed",
				false
			)
		)
		and str(
			payload.get(
				"runtime_owner",
				""
			)
		).strip_edges().to_lower()
		== "age_up_runtime"
	)

	if runtime_managed_age_up:
		var target_year: int = int(
			payload.get(
				"year",
				gs.year
			)
		)

		if int(
			get_meta(
				"vormir_yearly_runtime_completed_year",
				-999999
			)
		) == target_year:
			return

		var runtime_state_raw: Variant = get_meta(
			"vormir_yearly_runtime_state",
			{}
		)

		var runtime_state: Dictionary = (
			runtime_state_raw as Dictionary
			if typeof(
				runtime_state_raw
			) == TYPE_DICTIONARY
			else {}
		)

		if (
			runtime_state.is_empty()
			or int(
				runtime_state.get(
					"year",
					-999999
				)
			) != target_year
		):
			runtime_state = {
				"year": target_year,
				"cursor": 0,
				"started_at_ms": int(
					Time.get_ticks_msec()
				)
			}

			set_meta(
				"vormir_yearly_runtime_state",
				runtime_state
			)

		_arm_vormir_yearly_runtime_service()

		return

	var state: Dictionary = _ensure_state()

	var bond_years_raw: Variant = (
		state.get(
			"bond_years",
			{}
		)
	)

	var bond_years: Dictionary = (
		bond_years_raw
		if typeof(
			bond_years_raw
		) == TYPE_DICTIONARY
		else {}
	)

	var player: Person = gs.player

	for npc in gs.npcs:
		if npc == null:
			continue

		if int(
			npc.id
		) == int(
			player.id
		):
			continue

		var key: String = str(
			npc.id
		)

		if (
			not npc.alive
			or SOUL_SACRIFICE_TRAIT
			in npc.traits
		):
			bond_years [
				key
			] = 0

			continue

		if _has_high_mutual_relationship(
			player,
			npc
		):
			bond_years [
				key
			] = int(
				bond_years.get(
					key,
					0
				)
			) + 1
		else:
			bond_years [
				key
			] = 0

	state [
		"bond_years"
	] = bond_years

	gs.scenario_state [
		"vormir_state"
	] = state
func _arm_vormir_yearly_runtime_service() -> void:
	if bool(
		get_meta(
			"vormir_yearly_runtime_service_armed",
			false
		)
	):
		return

	var state_raw: Variant = get_meta(
		"vormir_yearly_runtime_state",
		{}
	)

	if (
		typeof(
			state_raw
		) != TYPE_DICTIONARY
		or (
			state_raw as Dictionary
		).is_empty()
	):
		return

	var tree:= Engine.get_main_loop() as SceneTree

	if tree == null:
		return

	set_meta(
		"vormir_yearly_runtime_service_armed",
		true
	)

	var error: int = tree.process_frame.connect(
		Callable(
			self,
			"_service_vormir_yearly_runtime_quantum"
		),
		CONNECT_ONE_SHOT
	)

	if error != OK:
		set_meta(
			"vormir_yearly_runtime_service_armed",
			false
		)


func _service_vormir_yearly_runtime_quantum() -> void:
	set_meta(
		"vormir_yearly_runtime_service_armed",
		false
	)

	if (
		gs == null
		or gs.player == null
	):
		return

	var runtime_state_raw: Variant = get_meta(
		"vormir_yearly_runtime_state",
		{}
	)

	var runtime_state: Dictionary = (
		runtime_state_raw as Dictionary
		if typeof(
			runtime_state_raw
		) == TYPE_DICTIONARY
		else {}
	)

	if runtime_state.is_empty():
		return

	var target_year: int = int(
		runtime_state.get(
			"year",
			gs.year
		)
	)

	var cursor: int = clampi(
		int(
			runtime_state.get(
				"cursor",
				0
			)
		),
		0,
		gs.npcs.size()
	)

	var state: Dictionary = _ensure_state()

	var bond_years_raw: Variant = state.get(
		"bond_years",
		{}
	)

	var bond_years: Dictionary = (
		bond_years_raw
		if typeof(
			bond_years_raw
		) == TYPE_DICTIONARY
		else {}
	)

	var player: Person = gs.player
	var started_ms: int = int(
		Time.get_ticks_msec()
	)

	var processed: int = 0

	while (
		cursor < gs.npcs.size()
		and processed < 16
	):
		if (
			processed > 0
			and int(
				Time.get_ticks_msec()
			) - started_ms >= 1
		):
			break

		var npc: Person = (
			gs.npcs [
				cursor
			] as Person
		)

		cursor += 1
		processed += 1

		if npc == null:
			continue

		if int(
			npc.id
		) == int(
			player.id
		):
			continue

		if int(
			npc.get_meta(
				"last_vormir_yearly_runtime_year",
				-999999
			)
		) == target_year:
			continue

		var key: String = str(
			npc.id
		)

		if (
			not npc.alive
			or SOUL_SACRIFICE_TRAIT
			in npc.traits
		):
			bond_years [
				key
			] = 0
		elif _has_high_mutual_relationship(
			player,
			npc
		):
			bond_years [
				key
			] = int(
				bond_years.get(
					key,
					0
				)
			) + 1
		else:
			bond_years [
				key
			] = 0

		npc.set_meta(
			"last_vormir_yearly_runtime_year",
			target_year
		)

	state [
		"bond_years"
	] = bond_years

	gs.scenario_state [
		"vormir_state"
	] = state

	runtime_state [
		"cursor"
	] = cursor

	if cursor >= gs.npcs.size():
		set_meta(
			"vormir_yearly_runtime_completed_year",
			target_year
		)

		set_meta(
			"vormir_yearly_runtime_state",
			{}
		)

		return

	set_meta(
		"vormir_yearly_runtime_state",
		runtime_state
	)

	_arm_vormir_yearly_runtime_service()


func get_surface_entry_for_player() -> Dictionary:
	if gs == null or gs.player == null or not gs.player.alive:
		return {}

	var mode_key: String = str(gs.reality_mode).strip_edges().to_lower()
	if gs.has_method("get_reality_mode"):
		mode_key = str(gs.get_reality_mode()).strip_edges().to_lower()
	if typeof(gs.custom_settings) == TYPE_DICTIONARY:
		var custom_mode_key: String = str(gs.custom_settings.get("reality_mode", mode_key)).strip_edges().to_lower()
		if custom_mode_key != "":
			mode_key = custom_mode_key

	if mode_key in ["realistic", "enhanced"]:
		return {}
	if not gs.is_feature_enabled("artifacts"):
		return {}

	var companion: Person = get_best_soul_candidate()
	var action_label: String = "Travel alone to Vormier"
	if companion != null:
		action_label = "Travel to Vormier with %s" % _person_name(companion)
	var state: Dictionary = _ensure_state()
	var sacrifices_raw: Variant = state.get("sacrifices", [])
	var player_sacrifices: Array = sacrifices_raw if typeof(sacrifices_raw) == TYPE_ARRAY else []
	var canonical_sacrifices: int = 2
	var total_sacrifices: int = canonical_sacrifices + player_sacrifices.size()
	var realm:= {
		"id": VORMIR_ID,
		"name": "VORMIER",
		"display_name": "VORMIER",
		"card_title": "VORMIER",
		"realm_kind": "space_realm",
		"realm_type": "soul_gate",
		"dimension_type": "space_realm",
		"realm_browser_section": "space_realms",
		"entry_method": "soul_stone_sacrifice",
		"visibility_rule": "Unavailable in realistic or enhanced mode. Requires artifacts.",
		"persistence": "fixed_cosmic_realm",
		"is_country_surface": true,
		"browser_visual_theme": "vormir",
		"overview_visual_theme": "vormir",
		"special_card_kind": "vormir",
		"hide_country_action_migrate": true,
		"show_country_action_vacation": false,
		"show_country_action_find_date": false,
		"hide_country_actions_in_overview": true,
		"surface_view_only": false,
		"population": 1,
		"resident_count": 1,
		"resident_label": "Red Skull",
		"military": 0,
		"military_units": 0,
		"military_stockpile": 0,
		"military_label": "None",
		"treasury": 0,
		"currency_name": "Souls",
		"treasury_label": "No treasury",
		"government_style": "Soul Threshold",
		"ruler_name": RED_SKULL_NAME,
		"leader_title": "Guide",
		"guide_name": RED_SKULL_NAME,
		"action_label": action_label,
		"eligible_companion_id": companion.id if companion != null else -1,
		"souls_sacrificed_total": total_sacrifices,
		"souls_sacrificed_canonical": canonical_sacrifices,
		"souls_sacrificed_by_player": player_sacrifices.size(),
		"known_sacrifices": ["Black Widow", "Gamora"],
		"cosmic_silence": 100,
		"mercy": 0,
		"soul_debt": 100,
		"keeper_pressure": 92,
		"access_rule": "Travel alone, or with someone else",
		"browser_aura_strength": 1.0,
		"browser_aura_bg_alpha": 0.34,
		"browser_aura_shadow_alpha": 0.72,
		"browser_aura_shadow_size": 46,
		"browser_aura_pulse_low": Color(1.06, 0.92, 1.22, 1.0),
		"browser_aura_pulse_high": Color(1.18, 0.98, 1.42, 1.0),
		"overview_aura_bg_alpha": 0.992,
		"overview_aura_shadow_alpha": 0.68,
		"overview_aura_shadow_size": 42,
		"overview_border_alpha": 0.98,
		"overview_text_alpha": 0.99,
		"soul_stone_hex": "ff8a24",
		"notable_zones": [
			"The Mountain",
			"The Stone Gate",
			"The Silent Edge",
			"The Soul Chasm"
		],
		"subzones": [
			"The Mountain",
			"The Stone Gate",
			"The Silent Edge",
			"The Soul Chasm"
		],
		"subzone_count": 4,
		"description": "A dead cosmic world where the Soul Stone demands what cannot be bought, spawned, wished into being, or taken by force."
	}
	return {
		"entry_kind": "space_realm",
		"entry_id": VORMIR_ID,
		"name": "VORMIER",
		"realm": realm,
		"_sort_priority": 4
	}


func get_best_soul_candidate() -> Person:
	if gs == null or gs.player == null:
		return null

	var state: Dictionary = _ensure_state()
	var bond_years_raw: Variant = state.get("bond_years", {})
	var bond_years: Dictionary = bond_years_raw if typeof(bond_years_raw) == TYPE_DICTIONARY else {}

	var best: Person = null
	var best_score: int = -999999

	for npc in gs.npcs:
		if npc == null:
			continue
		if int(npc.id) == int(gs.player.id):
			continue
		if not npc.alive:
			continue
		if SOUL_SACRIFICE_TRAIT in npc.traits:
			continue

		var years: int = int(bond_years.get(str(npc.id), 0))
		if years < SOUL_STONE_REQUIRED_BOND_YEARS:
			continue

		var affection_score: int = _mutual_affection(gs.player, npc)
		if affection_score < SOUL_STONE_REQUIRED_AFFECTION:
			continue

		var relation_bonus: int = _relationship_weight(gs.player, npc)
		var score: int = affection_score + years + relation_bonus
		if score > best_score:
			best_score = score
			best = npc

	return best


func begin_vormir_travel() -> Dictionary:
	if gs == null or gs.player == null:
		return { "success": false, "text": "No active life is loaded."}

	var mode_key: String = str(gs.reality_mode).strip_edges().to_lower()
	if gs.has_method("get_reality_mode"):
		mode_key = str(gs.get_reality_mode()).strip_edges().to_lower()
	if typeof(gs.custom_settings) == TYPE_DICTIONARY:
		var custom_mode_key: String = str(gs.custom_settings.get("reality_mode", mode_key)).strip_edges().to_lower()
		if custom_mode_key != "":
			mode_key = custom_mode_key

	if mode_key in ["realistic", "enhanced"]:
		return { "success": false, "text": "Vormir does not answer in this reality mode."}
	if not gs.is_feature_enabled("artifacts"):
		return { "success": false, "text": "Cosmic artifact systems are disabled right now."}
	if gs.artifacts_engine != null and gs.artifacts_engine.has_method("person_has_stone"):
		if gs.artifacts_engine.person_has_stone(gs.player, "Soul"):
			return { "success": false, "text": "The Soul Stone has already answered you."}
	if gs.scenario_engine == null:
		return { "success": false, "text": "The scenario engine is not available right now."}
	if gs.scenario_engine.has_pending_choice():
		return { "success": false, "text": "Resolve the current scenario before approaching Vormir."}
	var companion: Person = get_best_soul_candidate()
	var queued_result: Dictionary = {}
	if companion == null:
		queued_result = gs.scenario_engine.queue_external_scenario(_build_lonely_vormir_scenario(gs.player))
	else:
		queued_result = gs.scenario_engine.queue_external_scenario(_build_vormir_arrival_scenario(gs.player, companion))
	return {
		"success": true,
		"text": "Vormir has answered.",
		"scenario_result": queued_result
	}


func _build_lonely_vormir_scenario(actor: Person) -> Dictionary:
	var actor_name: String = _person_name(actor)
	return {
		"id": "vormir_lonely_arrival_%d" % int(gs.year),
		"source": "vormir_engine",
		"category": "artifact",
		"cooldown_key": "vormir_lonely_arrival",
		"resolver_method": "_resolve_vormir_choice",
		"prompt": "%s arrives alone on Vormir. The air is black, orange, and still. %s waits at the edge of the mountain and says: \"The stone is not won by strength. It is paid for by love. Return with a soul your heart cannot replace.\"" % [actor_name, RED_SKULL_NAME],
		"choices": [
			{
				"id": "accept_lonely_return",
				"label": "Return with the knowledge",
				"journal_text": "I reached Vormir alone and learned the Soul Stone demands someone I truly love.",
				"result_text": "You are returned from Vormir with terrible knowledge: the Soul Stone cannot be bought, found, spawned, or wished into existence. It demands a soul for a soul."
			}
		]
	}


func _build_vormir_arrival_scenario(actor: Person, companion: Person) -> Dictionary:
	var actor_name: String = _person_name(actor)
	var companion_name: String = _person_name(companion)
	return {
		"id": "vormir_arrival_%d_%d" % [int(gs.year), int(companion.id)],
		"source": "vormir_engine",
		"category": "artifact",
		"cooldown_key": "vormir_arrival",
		"resolver_method": "_resolve_vormir_choice",
		"sacrifice_id": int(companion.id),
		"prompt": "%s and %s arrive on Vormir. The sky burns like an old wound. %s steps from the shadow and says: \"What you seek lies before you. As does what you fear losing.\"" % [actor_name, companion_name, RED_SKULL_NAME],
		"choices": [
			{
				"id": "approach_the_edge",
				"label": "Approach the edge",
				"journal_text": "I walked deeper into Vormir with %s beside me." % companion_name,
				"next_stage": "soul_edge"
			},
			{
				"id": "turn_back_from_vormir",
				"label": "Turn back",
				"journal_text": "I turned back from Vormir before the mountain could ask for blood.",
				"result_text": "You leave Vormir. The mountain does not chase you. It already knows whether you will return."
			}
		]
	}


func _build_vormir_edge_scenario(actor: Person, companion: Person) -> Dictionary:
	var actor_name: String = _person_name(actor)
	var companion_name: String = _person_name(companion)
	return {
		"id": "vormir_soul_edge_%d_%d" % [int(gs.year), int(companion.id)],
		"source": "vormir_engine",
		"category": "artifact",
		"cooldown_key": "vormir_soul_edge",
		"resolver_method": "_resolve_vormir_choice",
		"sacrifice_id": int(companion.id),
		"prompt": "%s stands at the edge with %s. Every shared year seems to speak at once. %s says: \"To take the stone, you must lose what your soul has chosen to keep.\"" % [actor_name, companion_name, RED_SKULL_NAME],
		"choices": [
			{
				"id": "sacrifice_for_soul_stone",
				"label": "Sacrifice %s" % companion_name,
				"journal_text": "I sacrificed %s on Vormir to obtain the Soul Stone." % companion_name
			},
			{
				"id": "refuse_soul_price",
				"label": "Refuse the price",
				"journal_text": "I refused to sacrifice %s for the Soul Stone." % companion_name,
				"result_text": "The mountain remains silent. The Soul Stone remains beyond you."
			}
		]
	}


func _resolve_vormir_choice(actor: Person, scenario: Dictionary, choice: Dictionary, _committed: Dictionary) -> Dictionary:
	if gs == null or actor == null:
		return {}

	var choice_id: String = str(choice.get("id", "")).strip_edges()
	var sacrifice_id: int = int(scenario.get("sacrifice_id", -1))
	var sacrifice: Person = gs.get_npc_by_id(sacrifice_id)

	match choice_id:
		"approach_the_edge":
			if sacrifice == null or not sacrifice.alive:
				return {
					"type": "scenario_commit_complete",
					"text": "The person you brought to Vormir is no longer here. The mountain closes.",
					"opps": []
				}
			return gs.scenario_engine.queue_external_scenario(_build_vormir_edge_scenario(actor, sacrifice))

		"sacrifice_for_soul_stone":
			if sacrifice == null or not sacrifice.alive:
				return {
					"type": "scenario_commit_complete",
					"text": "The sacrifice is gone. Vormir gives you nothing.",
					"opps": []
				}
			return _commit_soul_stone_sacrifice(actor, sacrifice)

	var result_text: String = str(choice.get("result_text", "Vormir releases you, but not cleanly.")).strip_edges()
	return {
		"type": "scenario_commit_complete",
		"text": result_text,
		"opps": []
	}


func _commit_soul_stone_sacrifice(actor: Person, sacrifice: Person) -> Dictionary:
	if actor == null or sacrifice == null:
		return {}

	var actor_name: String = _person_name(actor)
	var sacrifice_name: String = _person_name(sacrifice)

	if SOUL_SACRIFICE_TRAIT not in sacrifice.traits:
		sacrifice.traits.append(SOUL_SACRIFICE_TRAIT)

	sacrifice.alive = false
	sacrifice.health = 0
	sacrifice.cause_of_death = "Sacrificed on Vormir for the Soul Stone"
	sacrifice.memories.append("My soul was sacrificed on Vormir. No wish, bonnet, dragon, or resurrection can call me back.")

	var state: Dictionary = _ensure_state()
	var sacrifices_raw: Variant = state.get("sacrifices", [])
	var sacrifices: Array = sacrifices_raw if typeof(sacrifices_raw) == TYPE_ARRAY else []
	sacrifices.append({
		"year": int(gs.year),
		"sacrificer_id": int(actor.id),
		"sacrifice_id": int(sacrifice.id),
		"sacrificer_name": actor_name,
		"sacrifice_name": sacrifice_name
	})
	state ["sacrifices"] = sacrifices
	gs.scenario_state ["vormir_state"] = state

	if gs.event_bus != null:
		gs.event_bus.emit(ActionEventTypes.NPC_DIED, {
			"npc_id": int(sacrifice.id),
			"cause": sacrifice.cause_of_death,
			"source": "vormir_engine",
		})

	if gs.artifacts_engine != null and gs.artifacts_engine.has_method("grant_soul_stone_from_vormir"):
		gs.artifacts_engine.grant_soul_stone_from_vormir(actor, {
			"sacrifice_id": int(sacrifice.id),
			"sacrifice_name": sacrifice_name
		})

	var diary_text: String = "I sacrificed %s on Vormir. The Soul Stone answered me, but something in the world recoiled." % sacrifice_name
	actor.memories.append(diary_text)
	if gs.narrative_engine != null:
		gs.narrative_engine.log_event(actor, {
			"type": "text",
			"text": diary_text
		})

	var world_text: String = "%s sacrificed %s on Vormir and obtained the Soul Stone." % [actor_name, sacrifice_name]
	if gs.has_method("push_world_feed"):
		gs.push_world_feed(world_text, {
			"category": "artifact",
			"event_name": "soul_stone_sacrifice",
			"source": "vormir_engine",
			"npc_id": int(actor.id),
			"target_id": int(sacrifice.id),
			"personally_relevant": true,
		})

	_apply_vormir_reputation_aftermath(actor, sacrifice)

	return {
		"type": "scenario_commit_complete",
		"text": "The mountain goes quiet.\n\n%s falls beyond the edge, and the silence takes them completely.\n\nWhen you wake, the Soul Stone is in your hand. The universe knows what you paid." % sacrifice_name,
		"opps": []
	}


func _apply_vormir_reputation_aftermath(actor: Person, sacrifice: Person) -> void:
	if gs == null or actor == null or sacrifice == null:
		return

	for npc in gs.npcs:
		if npc == null:
			continue
		if int(npc.id) == int(actor.id):
			continue
		if not npc.alive:
			continue

		if typeof(npc.affection) != TYPE_DICTIONARY:
			npc.affection = {}

		var current: int = int(npc.affection.get(actor.id, 50))
		var delta: int = -18

		if int(sacrifice.id) in npc.parents or int(sacrifice.id) in npc.children:
			delta = -65
		elif npc.partner != null and int(npc.partner.id) == int(sacrifice.id):
			delta = -75
		elif _mutual_affection(npc, sacrifice) >= 80:
			delta = -45
		elif "Ruthless" in npc.traits or "Ambitious" in npc.traits:
			delta = -6
		elif current >= 90:
			delta = -24
		else:
			delta = - randi_range(12, 34)

		npc.affection [actor.id] = int(clamp(current + delta, 0, 100))


func _has_high_mutual_relationship(a: Person, b: Person) -> bool:
	return _mutual_affection(a, b) >= SOUL_STONE_REQUIRED_AFFECTION


func _mutual_affection(a: Person, b: Person) -> int:
	if a == null or b == null:
		return 0
	var a_affection: int = 50
	var b_affection: int = 50
	if typeof(a.affection) == TYPE_DICTIONARY:
		a_affection = int(a.affection.get(b.id, 50))
	if typeof(b.affection) == TYPE_DICTIONARY:
		b_affection = int(b.affection.get(a.id, 50))
	return min(a_affection, b_affection)


func _relationship_weight(player: Person, npc: Person) -> int:
	if player == null or npc == null:
		return 0
	if player.partner != null and int(player.partner.id) == int(npc.id):
		return 40
	if int(npc.id) in player.children:
		return 35
	if int(npc.id) in player.parents:
		return 35
	if int(npc.id) in player.friends:
		return 20
	return 0


func _person_name(person: Person) -> String:
	if person == null:
		return "Someone"
	return ("%s %s" % [person.first_name, person.last_name]).strip_edges()