extends Resource
class_name NidavellirEngine

const NIDAVELLIR_ID:= "nidavellir"
const NIDAVELLIR_NAME:= "Niðavellir"
const DWARF_COLLECTIVE_NAME:= "The Dwarves of Niðavellir"
const MIN_STONES_REQUIRED:= 3
const REQUIRED_GATE_STONE:= "Space"
const BASE_DWARF_HP:= 260
const BASE_PLAYER_HP:= 180
const TEMP_BANISH_MIN_YEARS:= 2
const TEMP_BANISH_MAX_YEARS:= 6

var gs

func _init(_gs):
	gs = _gs
	_ensure_state()

func _ensure_state() -> Dictionary:
	if gs == null:
		return {}
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	var state_raw: Variant = gs.scenario_state.get("nidavellir_state", {})
	var state: Dictionary = state_raw if typeof(state_raw) == TYPE_DICTIONARY else {}
	if not state.has("banished_until_year"):
		state ["banished_until_year"] = {}
	if not state.has("permanent_banish_ids"):
		state ["permanent_banish_ids"] = []
	if not state.has("star_exposure_profiles"):
		state ["star_exposure_profiles"] = {}
	if not state.has("mjolnir_attunement"):
		state ["mjolnir_attunement"] = {}
	if not state.has("forged_registry"):
		state ["forged_registry"] = {}
	if not state.has("active_encounter"):
		state ["active_encounter"] = {}
	if not state.has("last_visit_year"):
		state ["last_visit_year"] = {}
	if not state.has("combat_memory_profiles"):
		state ["combat_memory_profiles"] = {}
	gs.scenario_state ["nidavellir_state"] = state
	return state

func yearly_tick(_payload:= {}) -> void:
	if gs == null or gs.player == null or not gs.player.alive:
		return

	var player: Person = gs.player
	var state: Dictionary = _ensure_state()

	_tick_star_exposure(player, state)
	_tick_mjolnir_attunement(player, state)

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
	var player: Person = gs.player
	if not _meets_surface_gate(player):
		return {}
	var state: Dictionary = _ensure_state()
	var stone_count: int = _owned_stones(player).size()
	var has_all_stones: bool = _has_all_stones(player)
	var worthy_now: bool = _is_currently_worthy(player, state)
	var can_call_bifrost: bool = _has_forged_item(player, "Stormbreaker")
	var is_banished: bool = _is_banished(player, state)
	var browser_gate_line: String = "%d Stones • Space required" % stone_count
	var browser_submission_line: String = "The forge answers only after power survives the ring."
	if has_all_stones:
		browser_submission_line = "All six stones are present. The ring can now endure a gauntlet command."
	var browser_summary_lines: Array = [
		"Forge Assembly: The Forge Assembly",
		"Heart: Fed by a dying star",
		"Gate: %s" % browser_gate_line,
		"Charge: Weapons forged here carry burden, not just power",
		"Judgment: %s" % ("Mjolnir still answers you" if worthy_now else "Mjolnir would judge you harshly right now"),
		"Path: %s" % ("Stormbreaker can call the Bifrost" if can_call_bifrost else "Stormbreaker has not yet opened the Bifrost path"),
		"State: %s" % ("The dwarves have barred you" if is_banished else "The forge is not closed to you"),
		"Law: %s" % browser_submission_line
	]
	var realm:= {
		"id": NIDAVELLIR_ID,
		"name": NIDAVELLIR_NAME,
		"display_name": NIDAVELLIR_NAME,
		"card_title": "NIDAVELLIR",
		"browser_card_title": "NIDAVELLIR • STAR FORGE",
		"browser_overview_label": "Open Overview",
		"browser_visit_button_label": "Visit",
		"browser_summary_lines": browser_summary_lines,
		"realm_kind": "space_realm",
		"realm_type": "star_forge",
		"dimension_type": "space_realm",
		"realm_browser_section": "space_realms",
		"entry_method": "space_stone_gate",
		"visibility_rule": "Unavailable in realistic or enhanced mode. Requires artifacts.",
		"persistence": "fixed_cosmic_realm",
		"is_country_surface": true,
		"browser_visual_theme": "nidavellir",
		"overview_visual_theme": "nidavellir",
		"special_card_kind": "nidavellir",
		"hide_country_action_migrate": true,
		"show_country_action_vacation": false,
		"show_country_action_find_date": false,
		"hide_country_actions_in_overview": true,
		"surface_view_only": false,
		"population": 1,
		"resident_count": 1,
		"resident_label": DWARF_COLLECTIVE_NAME,
		"military": 880,
		"military_units": 880,
		"military_stockpile": 880,
		"military_label": "Forgemasters",
		"treasury": 999999999999,
		"currency_name": "Starfire Reserves",
		"treasury_label": "Starfire Reserves",
		"government_style": "Mythic Forge Collective",
		"ruler_name": DWARF_COLLECTIVE_NAME,
		"leader_title": "Forge Assembly",
		"guide_name": "The Forge Assembly",
		"action_label": "Visit",
		"stone_gate_count": stone_count,
		"gauntlet_ready": has_all_stones,
		"mjolnir_responsive": worthy_now,
		"stormbreaker_bifrost_ready": can_call_bifrost,
		"banished_here": is_banished,
		"browser_aura_strength": 1.42,
		"browser_aura_bg_alpha": 0.52,
		"browser_aura_shadow_alpha": 0.99,
		"browser_aura_shadow_size": 82,
		"browser_aura_pulse_low": Color(1.08, 0.74, 0.54, 1.0),
		"browser_aura_pulse_high": Color(1.22, 0.9, 0.7, 1.0),
		"overview_aura_bg_alpha": 0.998,
		"overview_aura_shadow_alpha": 0.8,
		"overview_aura_shadow_size": 52,
		"overview_border_alpha": 1.0,
		"overview_text_alpha": 1.0,
		"starforge_hex": "ffb08a",
		"notable_zones": [
			"The Dying Star",
			"The Great Forge",
			"The Ring Harbor",
			"The Dwarf Assembly"
		],
		"subzones": [
			"The Dying Star",
			"The Great Forge",
			"The Ring Harbor",
			"The Dwarf Assembly"
		],
		"subzone_count": 4,
		"description": "A dreamlike ring-realm of starfire, cosmic metal, and impossible beauty, where dwarven forgemasters shape weapons that carry power, burden, and judgment."
	}
	return {
		"entry_kind": "space_realm",
		"entry_id": NIDAVELLIR_ID,
		"name": NIDAVELLIR_NAME,
		"realm": realm,
		"_sort_priority": 3
	}
func begin_nidavellir_visit() -> Dictionary:
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
		return { "success": false, "text": "Niðavellir does not answer in this reality mode."}
	if not gs.is_feature_enabled("artifacts"):
		return { "success": false, "text": "Cosmic artifact systems are disabled right now."}
	if gs.scenario_engine == null:
		return { "success": false, "text": "The scenario engine is not available right now."}
	if gs.scenario_engine.has_pending_choice():
		return { "success": false, "text": "Resolve the current scenario before approaching Niðavellir."}

	var player: Person = gs.player
	if not _meets_surface_gate(player):
		return { "success": false, "text": "Niðavellir only answers to a wielder of at least three Infinity Stones, and one of them must be the Space Stone."}

	var state: Dictionary = _ensure_state()
	if _is_permanently_banished(player, state):
		return { "success": false, "text": "The dwarves have banished you from Niðavellir forever."}

	var banished_until: int = int((state.get("banished_until_year", {}) as Dictionary).get(str(player.id), -999999))
	if banished_until >= int(gs.year):
		return { "success": false, "text": "The dwarves have barred you from Niðavellir until %s." % str(_format_year(banished_until))}
	var queued_result: Dictionary = gs.scenario_engine.queue_external_scenario(_build_visit_confirm_scenario(player))
	return {
		"success": true,
		"text": "Niðavellir shimmers at the edge of space.",
		"scenario_result": queued_result
	}

func _build_visit_confirm_scenario(_actor: Person) -> Dictionary:
	return {
		"id": "nidavellir_visit_confirm_%d" % int(gs.year),
		"source": "nidavellir_engine",
		"category": "artifact",
		"cooldown_key": "nidavellir_visit_confirm",
		"resolver_method": "_resolve_nidavellir_choice",
		"panel_title": "NIDAVELLIR",
		"footer_text": "Choose how you want to respond.",
		"prompt": "Use your Space Stone to travel there?",
		"choices": [
			{
				"id": "nidavellir_confirm_yes",
				"label": "Yes",
				"journal_text": "I used my Space Stone to reach Niðavellir."
			},
			{
				"id": "nidavellir_confirm_no",
				"label": "No",
				"journal_text": "I held back from using my Space Stone to reach Niðavellir.",
				"result_text": "You let the star-forge remain distant."
			}
		]
	}
func _build_dwarf_arrival_challenge_scenario(_actor: Person) -> Dictionary:
	return {
		"id": "nidavellir_arrival_challenge_%d" % int(gs.year),
		"source": "nidavellir_engine",
		"category": "artifact",
		"cooldown_key": "nidavellir_arrival_challenge",
		"resolver_method": "_resolve_nidavellir_choice",
		"panel_title": "NIDAVELLIR",
		"footer_text": "The dwarves are giving you one chance to leave.",
		"prompt": "You arrive in Niðavellir beneath a dying star.\n\nThe dwarves surround you in the forge-ring. They do not bow. They do not welcome you.\n\nThe Forge Assembly says: \"Leave now. This place does not exist to satisfy your hunger for power.\"",
		"choices": [
			{
				"id": "nidavellir_tell_kick_rocks",
				"label": "Tell them to kick rocks. You want power.",
				"journal_text": "I told the dwarves to kick rocks. I came to Niðavellir for power."
			},
			{
				"id": "nidavellir_leave_now",
				"label": "Leave now",
				"journal_text": "I left Niðavellir after the dwarves demanded that I go."
			}
		]
	}
func _resolve_nidavellir_choice(actor: Person, _scenario: Dictionary, choice: Dictionary, _committed: Dictionary) -> Dictionary:
	if gs == null or actor == null:
		return {}
	var choice_id: String = str(choice.get("id", "")).strip_edges()
	match choice_id:
		"nidavellir_confirm_yes":
			return gs.scenario_engine.queue_external_scenario(_build_dwarf_arrival_challenge_scenario(actor))
		"nidavellir_tell_kick_rocks":
			return _begin_dwarf_encounter(actor, "The dwarves go still.\n\nThey find your comment disrespectful.\n\nThe Forge Assembly says: \"Then give us your best shot.\"")
		"nidavellir_leave_now":
			return {
				"type": "scenario_commit_complete",
				"text": "I reached Niðavellir, heard the dwarves demand that I leave, and chose not to fight them.",
				"popup_title": "Niðavellir",
				"popup_text": "The dwarves watch you leave the star-forge ring.\n\nThe dying star keeps burning behind them.",
				"popup_footer": "Tap anywhere to continue.",
				"opps": []
			}
		"surrender_to_dwarves":
			return _resolve_battle_surrender(actor)
		"forge_gauntlet_locked":
			return {
				"type": "scenario_commit_complete",
				"text": "The dwarves refuse. The Infinity Gauntlet cannot be forged unless all six stones are already under your authority.",
				"popup_title": "Locked",
				"popup_text": "The forge ring rejects the command.\n\nYou need all six Infinity Stones before the dwarves will shape the Infinity Gauntlet.",
				"popup_footer": "Tap anywhere to continue.",
				"opps": []
			}
		"forge_infinity_gauntlet":
			return _forge_infinity_gauntlet(actor)
		"forge_mjolnir":
			return _forge_star_weapon(actor, "Mjolnir")
		"forge_stormbreaker":
			return _forge_star_weapon(actor, "Stormbreaker")
		"leave_the_forge":
			return {
				"type": "scenario_commit_complete",
				"text": "I left Niðavellir with the forge still burning behind me.",
				"popup_title": "Departure",
				"popup_text": "You leave the star-forge behind. The ring-world keeps turning around its dying sun.",
				"popup_footer": "Tap anywhere to continue.",
				"opps": []
			}
	if bool(choice.get("nidavellir_battle_choice", false)):
		return _resolve_battle_turn(actor, choice)
	var result_text: String = str(choice.get("result_text", "The forge stares back in silence.")).strip_edges()
	return {
		"type": "scenario_commit_complete",
		"text": result_text,
		"opps": []
	}

func _begin_dwarf_encounter(actor: Person, opening_text: String = "") -> Dictionary:
	var state: Dictionary = _ensure_state()
	var stones: Array = _owned_stones(actor)
	var profile: Dictionary = _get_dwarf_memory_profile(state, actor)
	var remembered_losses: int = int(profile.get("losses", 0))
	var adaptation_rank: int = clamp(remembered_losses + int(floor(float(remembered_losses) / 2.0)), 0, 12)
	var player_hp_max: int = max(BASE_PLAYER_HP, int(actor.health) + 90 + stones.size() * 12)
	var dwarf_hp_max: int = BASE_DWARF_HP + stones.size() * 18 + (adaptation_rank * 6)
	state ["active_encounter"] = {
		"actor_id": int(actor.id),
		"round": 1,
		"player_hp": player_hp_max,
		"player_hp_max": player_hp_max,
		"dwarf_hp": dwarf_hp_max,
		"dwarf_hp_max": dwarf_hp_max,
		"defense_bonus": 0,
		"visit_year": int(gs.year),
		"adaptation_rank": adaptation_rank,
		"aggression_bias": 4 + adaptation_rank,
		"last_power_source": "",
		"last_choice_family": "",
		"source_streak": 0,
		"family_streak": 0,
		"last_damage_to_player": 0,
		"last_damage_to_dwarves": 0,
		"last_shake_amount": 0.0,
		"last_response_text": "",
		"rounds_survived": 0,
		"total_damage_to_dwarves": 0,
		"total_damage_to_player": 0,
		"largest_hit_to_dwarves": 0,
		"largest_hit_to_player": 0,
		"actions_taken": [],
		"counter_modes_seen": [],
	}
	(state.get("last_visit_year", {}) as Dictionary) [str(actor.id)] = int(gs.year)
	gs.scenario_state ["nidavellir_state"] = state

	var arrival_text:= opening_text.strip_edges()
	if arrival_text == "":
		arrival_text = "You arrive in Niðavellir beneath a dying star.\n\nThe dwarves surround you, reject your presence, and demand that you leave their forge-ring at once."
	if remembered_losses > 0:
		arrival_text += "\n\nThe dwarves remember your last fight here. Their stance shifts like they already know parts of your rhythm."
	return _queue_battle_round(actor, arrival_text)

func _queue_battle_round(actor: Person, preface_text: String = "") -> Dictionary:
	var state: Dictionary = _ensure_state()
	var encounter_raw: Variant = state.get("active_encounter", {})
	if typeof(encounter_raw) != TYPE_DICTIONARY or (encounter_raw as Dictionary).is_empty():
		return {
			"type": "scenario_commit_complete",
			"text": "The forge quieted before the battle could continue.",
			"opps": []
		}
	var encounter: Dictionary = encounter_raw
	var lines: Array = []
	var effective_preface: String = preface_text.strip_edges()
	if effective_preface == "":
		effective_preface = str(encounter.get("last_response_text", "")).strip_edges()
	if effective_preface != "":
		lines.append(effective_preface)
	lines.append("Round %d." % int(encounter.get("round", 1)))
	if int(encounter.get("adaptation_rank", 0)) > 0:
		lines.append("The forge workers are no longer guessing. They are reading you in real time.")
	else:
		lines.append("The heat bends around your body as the dwarves come at you together.")
	return gs.scenario_engine.queue_external_scenario({
		"id": "nidavellir_battle_round_%d_%d" % [int(gs.year), int(encounter.get("round", 1))],
		"source": "nidavellir_engine",
		"category": "artifact",
		"cooldown_key": "nidavellir_battle_round",
		"resolver_method": "_resolve_nidavellir_choice",
		"panel_title": "NIDAVELLIR",
		"footer_text": "Read the dwarves' response, then choose yours.",
		"combat_ui": _build_combat_ui(actor, encounter),
		"prompt": "\n\n".join(lines),
		"choices": _build_battle_choices(actor, encounter)
	})

func _build_combat_ui(actor: Person, encounter: Dictionary) -> Dictionary:
	var status_text:= "Round %d • The forge ring shakes under a dying star." % int(encounter.get("round", 1))
	if int(encounter.get("adaptation_rank", 0)) > 0:
		status_text = "Round %d • The forge ring is reading your patterns." % int(encounter.get("round", 1))
	var shake_amount: float = max(0.0, float(encounter.get("last_shake_amount", 0.0)))
	return {
		"visible": true,
		"theme": "nidavellir",
		"status_text": status_text,
		"player_label": "%s %s" % [actor.first_name, actor.last_name],
		"player_value": int(encounter.get("player_hp", 0)),
		"player_max": max(1, int(encounter.get("player_hp_max", 1))),
		"enemy_label": "%s • Collective Health" % DWARF_COLLECTIVE_NAME,
		"enemy_value": int(encounter.get("dwarf_hp", 0)),
		"enemy_max": max(1, int(encounter.get("dwarf_hp_max", 1))),
		"impact_shake": shake_amount > 0.0,
		"impact_shake_amount": shake_amount
	}
func _get_dwarf_memory_profile(state: Dictionary, actor: Person) -> Dictionary:
	var profiles: Dictionary = state.get("combat_memory_profiles", {})
	var pid: String = str(actor.id) if actor != null else ""
	var profile_raw: Variant = profiles.get(pid, {})
	var profile: Dictionary = profile_raw if typeof(profile_raw) == TYPE_DICTIONARY else {}
	if not profile.has("wins"):
		profile ["wins"] = 0
	if not profile.has("losses"):
		profile ["losses"] = 0
	if not profile.has("total_fights"):
		profile ["total_fights"] = 0
	if not profile.has("source_reads"):
		profile ["source_reads"] = {}
	if not profile.has("family_reads"):
		profile ["family_reads"] = {}
	if not profile.has("last_outcome"):
		profile ["last_outcome"] = ""
	if not profile.has("last_damage_to_player"):
		profile ["last_damage_to_player"] = 0
	if not profile.has("last_damage_to_dwarves"):
		profile ["last_damage_to_dwarves"] = 0
	return profile


func _store_dwarf_memory_profile(state: Dictionary, actor: Person, profile: Dictionary) -> void:
	if actor == null:
		return
	var profiles: Dictionary = state.get("combat_memory_profiles", {})
	profiles [str(actor.id)] = profile.duplicate(true)
	state ["combat_memory_profiles"] = profiles
	gs.scenario_state ["nidavellir_state"] = state


func _build_dwarf_response_text(choice: Dictionary, power_source: String, choice_family: String, player_attack: int, damage_to_player: int, defense_bonus: int, heal_bonus: int, defense_read_bonus: int, retaliation_bonus: int, source_streak: int, family_streak: int, counter_profile: Dictionary) -> String:
	var lines: Array = []
	var journal_text: String = str(choice.get("journal_text", "I fought the dwarves of Niðavellir.")).strip_edges()
	if journal_text != "":
		lines.append(journal_text)
	if player_attack > 0:
		lines.append("My move landed for %d damage." % player_attack)
	else:
		lines.append("They read the angle and took almost nothing from it.")

	var mode: String = str(counter_profile.get("mode", "balanced")).strip_edges().to_lower()
	var stance_text: String = str(counter_profile.get("stance_text", "")).strip_edges()
	var adapted: bool = defense_read_bonus > 0 or retaliation_bonus > 0 or source_streak > 1 or family_streak > 1 or mode != "balanced"
	if adapted:
		var read_line:= "The dwarves adapted fast"
		if power_source != "":
			read_line += ", reading my %s rhythm" % power_source
		if choice_family != "":
			read_line += " and leaning against my %s pattern" % choice_family
		read_line += "."
		lines.append(read_line)
	if stance_text != "":
		lines.append(stance_text)
	if defense_bonus > 0:
		lines.append("I absorbed %d damage before their answer fully landed." % defense_bonus)
	if heal_bonus > 0:
		lines.append("The Time Stone restored %d health." % heal_bonus)
	if damage_to_player > 0:
		var counter_line:= "They answered with synchronized forge violence for %d damage." % damage_to_player
		if mode == "anti_stone":
			counter_line = "Their anti-stone formation swallowed the cosmic release and they punished the opening for %d damage." % damage_to_player
		elif mode == "anti_bending":
			counter_line = "They kept anti-bending spacing, made the technique travel long, and punished me for %d damage." % damage_to_player
		elif mode == "anti_brace":
			counter_line = "They turned my brace into a trap and poured anti-brace pressure into me for %d damage." % damage_to_player
		elif mode == "anti_force":
			counter_line = "They jammed my range, stole the reset, and hit me for %d damage." % damage_to_player
		elif mode == "anti_mutation":
			counter_line = "They read the mutation under my element and punished the unstable overlap for %d damage." % damage_to_player
		elif mode == "anti_attack":
			counter_line = "They keyed on my attacking rhythm and counter-rushed me for %d damage." % damage_to_player
		elif damage_to_player >= 22:
			counter_line = "They crashed into me in one brutal wave and dealt %d damage." % damage_to_player
		lines.append(counter_line)
	else:
		lines.append("Their counter broke against my response.")
	return "\n\n".join(lines)
func _resolve_dwarf_counter_profile(encounter: Dictionary, profile: Dictionary, choice_family: String, power_source: String) -> Dictionary:
	var source_reads_raw: Variant = profile.get("source_reads", {})
	var source_reads: Dictionary = source_reads_raw if typeof(source_reads_raw) == TYPE_DICTIONARY else {}
	var family_reads_raw: Variant = profile.get("family_reads", {})
	var family_reads: Dictionary = family_reads_raw if typeof(family_reads_raw) == TYPE_DICTIONARY else {}
	var mutation_reads: int = int(source_reads.get("mutated_ability", 0))
	var last_power_source: String = str(encounter.get("last_power_source", "")).strip_edges().to_lower()
	var last_choice_family: String = str(encounter.get("last_choice_family", "")).strip_edges().to_lower()

	var current_source_streak: int = 1 if power_source != "" else 0
	if power_source != "" and last_power_source == power_source:
		current_source_streak = int(encounter.get("source_streak", 1)) + 1

	var current_family_streak: int = 1 if choice_family != "" else 0
	if choice_family != "" and last_choice_family == choice_family:
		current_family_streak = int(encounter.get("family_streak", 1)) + 1

	var stone_reads: int = int(source_reads.get("stone", 0))
	var bending_reads: int = int(source_reads.get("bending", 0))
	var physical_reads: int = int(source_reads.get("physical", 0))
	var defend_reads: int = int(family_reads.get("defend", 0))
	var attack_reads: int = int(family_reads.get("attack", 0))

	var mode: String = "balanced"
	var defense_bias: int = 0
	var retaliation_bias: int = 0
	var stance_text: String = ""
	var warning_text: String = ""
	var diary_text: String = ""

	if choice_family == "defend" and (current_family_streak >= 2 or defend_reads >= 1):
		mode = "anti_brace"
		defense_bias = 4 + (defend_reads * 2) + (max(0, current_family_streak - 1) * 3)
		retaliation_bias = 8 + (defend_reads * 3) + (max(0, current_family_streak - 1) * 4)
		stance_text = "They smelled the brace and poured anti-brace pressure straight through my shell."
		warning_text = "Risk: anti-brace pressure"
		diary_text = "They shifted into anti-brace pressure."
	elif power_source == "stone" and (current_source_streak >= 2 or stone_reads >= 1):
		mode = "anti_stone"
		defense_bias = 6 + (stone_reads * 2) + (max(0, current_source_streak - 1) * 3)
		retaliation_bias = 10 + (stone_reads * 3) + (max(0, current_source_streak - 1) * 4)
		stance_text = "They split the ring into an anti-stone formation and staggered their line against cosmic output."
		warning_text = "Risk: anti-stone formation"
		diary_text = "They shifted into an anti-stone formation."
	elif power_source == "bending" and (current_source_streak >= 2 or bending_reads >= 1):
		mode = "anti_bending"
		defense_bias = 5 + (bending_reads * 2) + (max(0, current_source_streak - 1) * 3)
		retaliation_bias = 8 + (bending_reads * 2) + (max(0, current_source_streak - 1) * 4)
		stance_text = "They widened the ring and fought from anti-bending spacing, forcing my technique to travel farther than it wanted."
		warning_text = "Risk: anti-bending spacing"
		diary_text = "They widened into anti-bending spacing."
	elif power_source == "mutated_ability" and (current_source_streak >= 2 or mutation_reads >= 1):
		mode = "anti_mutation"
		defense_bias = 6 + (mutation_reads * 2) + (max(0, current_source_streak - 1) * 3)
		retaliation_bias = 9 + (mutation_reads * 3) + (max(0, current_source_streak - 1) * 4)
		stance_text = "They stopped treating my mutation like a miracle and started reading the contract beneath it."
		warning_text = "Risk: anti-mutation read"
		diary_text = "They began reading my mutated ability pattern."
	elif power_source == "physical" and choice_family == "attack" and (current_source_streak >= 2 or physical_reads >= 1):
		mode = "anti_force"
		defense_bias = 3 + (physical_reads * 2) + (max(0, current_source_streak - 1) * 2)
		retaliation_bias = 6 + (physical_reads * 2) + (max(0, current_source_streak - 1) * 3)
		stance_text = "They jammed my range before the swing could fully reset and punished the opening."
		warning_text = "Risk: collapsed range"
		diary_text = "They collapsed my range."
	elif choice_family == "attack" and (current_family_streak >= 2 or attack_reads >= 2):
		mode = "anti_attack"
		defense_bias = 2 + attack_reads + (max(0, current_family_streak - 1) * 2)
		retaliation_bias = 5 + (attack_reads * 2) + (max(0, current_family_streak - 1) * 3)
		stance_text = "They keyed on the attack rhythm itself and counter-rushed the beat."
		warning_text = "Risk: counter-rush"
		diary_text = "They keyed on my attack rhythm."

	return {
		"mode": mode,
		"defense_bias": min(defense_bias, 18),
		"retaliation_bias": min(retaliation_bias, 24),
		"stance_text": stance_text,
		"warning_text": warning_text,
		"diary_text": diary_text
	}


func _counter_warning_suffix(counter_profile: Dictionary) -> String:
	var warning_text: String = str(counter_profile.get("warning_text", "")).strip_edges()
	if warning_text == "":
		return ""
	return " • %s" % warning_text
func _build_battle_choices(actor: Person, encounter: Dictionary) -> Array:
	var out: Array = []
	var round_number: int = int(encounter.get("round", 1))
	var state: Dictionary = _ensure_state()
	var profile: Dictionary = _get_dwarf_memory_profile(state, actor)
	var physical_counter: Dictionary = _resolve_dwarf_counter_profile(encounter, profile, "attack", "physical")
	out.append({
		"id": "physical_attack_%d" % round_number,
		"label": "Attack with your own force%s" % _counter_warning_suffix(physical_counter),
		"journal_text": "I attacked the dwarves head-on with my own strength.",
		"nidavellir_battle_choice": true,
		"choice_family": "attack",
		"power_source": "physical",
		"disabled": false
	})

	var owned_stones: Array = _owned_stones(actor)
	var preferred_attack_stones:= ["Power", "Space", "Reality", "Time", "Mind", "Soul"]
	for stone_name in preferred_attack_stones:
		if stone_name not in owned_stones:
			continue
		var stone_counter: Dictionary = _resolve_dwarf_counter_profile(encounter, profile, "attack", "stone")
		out.append({
			"id": "stone_attack_%s_%d" % [stone_name.to_lower(), round_number],
			"label": "Attack with the %s Stone%s" % [stone_name, _counter_warning_suffix(stone_counter)],
			"journal_text": "I unleashed the %s Stone against the dwarves of Niðavellir." % stone_name,
			"nidavellir_battle_choice": true,
			"choice_family": "attack",
			"power_source": "stone",
			"stone_name": stone_name,
			"stone_key": stone_name,
			"button_theme": "infinity_stone",
			"disabled": false
		})
		if out.size() >= 3:
			break

	var unlocked_abilities: Array = _unlocked_battle_bending_choices(actor)
	for ability in unlocked_abilities:
		var ability_type: String = str(ability.get("type", "attack")).strip_edges().to_lower()
		var ability_family: String = "attack"
		if ability_type in ["defense", "escape"]:
			ability_family = "defend"

		var bending_counter: Dictionary = _resolve_dwarf_counter_profile(encounter, profile, ability_family, "bending")
		var ability_name: String = str(ability.get("name", "Bending")).strip_edges()
		var ability_element: String = str(ability.get("element", "")).strip_edges().to_lower()
		var label_prefix: String = "Attack with "
		if ability_family == "defend":
			label_prefix = "Defend with "

		out.append({
			"id": "bending_%s_%s_%d" % [ability_family, str(ability.get("id", "bending")).strip_edges(), round_number],
			"label": "%s%s%s" % [label_prefix, ability_name, _counter_warning_suffix(bending_counter)],
			"journal_text": "I used %s against the dwarves of Niðavellir." % ability_name,
			"nidavellir_battle_choice": true,
			"choice_family": ability_family,
			"power_source": "bending",
			"ability_id": str(ability.get("id", "")),
			"ability_name": ability_name,
			"ability_element": ability_element,
			"ability_type": ability_type,
			"ability_level": int(ability.get("current_level", ability.get("level", 0))),
			"button_theme": "bending_ability",
			"disabled": false
		})
	var mutation_rows: Array = _unlocked_battle_mutation_choices(actor)
	for mutation in mutation_rows:
		var mutation_family: String = str(mutation.get("choice_family", "attack")).strip_edges().to_lower()
		if mutation_family not in ["attack", "defend"]:
			mutation_family = "attack"

		var mutation_counter: Dictionary = _resolve_dwarf_counter_profile(encounter, profile, mutation_family, "mutated_ability")
		var mutation_name: String = str(mutation.get("display_name", mutation.get("label", "Mutated Ability"))).strip_edges()
		if mutation_name == "":
			mutation_name = "Mutated Ability"

		var mutation_prefix: String = "Attack with "
		if mutation_family == "defend":
			mutation_prefix = "Defend with "

		out.append({
			"id": "mutation_%s_%s_%d" % [
				mutation_family,
				str(mutation.get("id", "mutation")).strip_edges(),
				round_number
			],
			"label": "%s%s%s" % [
				mutation_prefix,
				mutation_name,
				_counter_warning_suffix(mutation_counter)
			],
			"journal_text": "I used %s against the dwarves of Niðavellir." % mutation_name,
			"nidavellir_battle_choice": true,
			"choice_family": mutation_family,
			"power_source": "mutated_ability",
			"mutation_id": str(mutation.get("id", "")),
			"ability_name": mutation_name,
			"ability_element": str(mutation.get("element", "")),
			"ability_type": str(mutation.get("ability_type", "attack")),
			"ability_level": int(mutation.get("ability_level", mutation.get("bending_level", 0))),
			"power": int(mutation.get("power", 24)),
			"guard": int(mutation.get("guard", 16)),
			"button_theme": "superpower_action",
			"disabled": false
		})
	var brace_counter: Dictionary = _resolve_dwarf_counter_profile(encounter, profile, "defend", "physical")
	out.append({
		"id": "brace_defensively_%d" % round_number,
		"label": "Defend and brace%s" % _counter_warning_suffix(brace_counter),
		"journal_text": "I braced myself and defended against the dwarves.",
		"nidavellir_battle_choice": true,
		"choice_family": "defend",
		"power_source": "physical",
		"disabled": false
	})

	if "Space" in owned_stones:
		var space_defend_counter: Dictionary = _resolve_dwarf_counter_profile(encounter, profile, "defend", "stone")
		out.append({
			"id": "space_defend_%d" % round_number,
			"label": "Defend with the Space Stone%s" % _counter_warning_suffix(space_defend_counter),
			"journal_text": "I bent space around myself to blunt the dwarves' assault.",
			"nidavellir_battle_choice": true,
			"choice_family": "defend",
			"power_source": "stone",
			"stone_name": "Space",
			"stone_key": "Space",
			"button_theme": "infinity_stone",
			"disabled": false
		})
	if "Time" in owned_stones:
		var time_defend_counter: Dictionary = _resolve_dwarf_counter_profile(encounter, profile, "defend", "stone")
		out.append({
			"id": "time_defend_%d" % round_number,
			"label": "Defend with the Time Stone%s" % _counter_warning_suffix(time_defend_counter),
			"journal_text": "I used the Time Stone to widen the moment and survive the dwarves' assault.",
			"nidavellir_battle_choice": true,
			"choice_family": "defend",
			"power_source": "stone",
			"stone_name": "Time",
			"stone_key": "Time",
			"button_theme": "infinity_stone",
			"disabled": false
		})
		out.append({
			"id": "surrender_to_dwarves",
			"label": "Surrender before they kill you",
			"journal_text": "I surrendered to the dwarves before they could finish me.",
			"nidavellir_battle_choice": false,
			"choice_family": "surrender",
			"power_source": "none",
			"disabled": false
		})
	return out
func _resolve_battle_surrender(actor: Person) -> Dictionary:
	var state: Dictionary = _ensure_state()
	var encounter_raw: Variant = state.get("active_encounter", {})
	var encounter: Dictionary = encounter_raw if typeof(encounter_raw) == TYPE_DICTIONARY else {}
	var profile: Dictionary = _get_dwarf_memory_profile(state, actor)

	profile ["total_fights"] = int(profile.get("total_fights", 0)) + 1
	profile ["last_outcome"] = "surrender"
	profile ["last_damage_to_player"] = int(encounter.get("total_damage_to_player", encounter.get("last_damage_to_player", 0)))
	profile ["last_damage_to_dwarves"] = int(encounter.get("total_damage_to_dwarves", encounter.get("last_damage_to_dwarves", 0)))
	_store_dwarf_memory_profile(state, actor, profile)

	var consequences: Dictionary = _apply_dwarf_surrender_consequences(actor, state)
	state ["active_encounter"] = {}
	gs.scenario_state ["nidavellir_state"] = state

	var stats_text: String = _build_battle_stats_summary(encounter)
	var consequence_lines: Array = consequences.get("lines", [])
	var popup_lines: Array = [
		"You surrender before the dwarves can finish you.",
		"They do not respect it. They only accept it.",
		stats_text
	]
	for line in consequence_lines:
		if str(line).strip_edges() != "":
			popup_lines.append(str(line))

	var diary_text:= "I surrendered to the dwarves of Niðavellir before they could kill me."
	for line in consequence_lines:
		diary_text += " " + str(line).strip_edges()

	_register_diary_entry(actor, diary_text)
	if gs.has_method("push_world_feed"):
		gs.push_world_feed("%s %s surrendered to the dwarves of Niðavellir." % [actor.first_name, actor.last_name], {
			"npc_id": int(actor.id),
			"personally_relevant": actor == gs.player,
			"category": "cosmic",
			"event_name": "nidavellir_battle_surrender",
			"source": "nidavellir_engine"
		})

	return {
		"type": "scenario_commit_complete",
		"text": diary_text,
		"popup_title": "Surrendered",
		"popup_text": "\n\n".join(popup_lines),
		"popup_footer": "Tap anywhere to continue.",
		"opps": []
	}


func _apply_dwarf_surrender_consequences(actor: Person, state: Dictionary) -> Dictionary:
	var lines: Array = []
	var did_anything: bool = false

	var take_stone_roll: bool = randf() < 0.72
	var banish_roll: bool = randf() < 0.68
	var permanent_banish_roll: bool = randf() < 0.12
	var cripple_roll: bool = randf() < 0.46

	if not take_stone_roll and not banish_roll and not cripple_roll:
		take_stone_roll = true

	if take_stone_roll:
		var confiscated_stone: String = _confiscate_random_stone(actor)
		if confiscated_stone != "":
			lines.append("They confiscated the %s Stone." % confiscated_stone)
			did_anything = true

	if banish_roll:
		if permanent_banish_roll:
			var permanent_ids: Array = state.get("permanent_banish_ids", [])
			if int(actor.id) not in permanent_ids:
				permanent_ids.append(int(actor.id))
			state ["permanent_banish_ids"] = permanent_ids
			lines.append("They banished you from Niðavellir forever.")
			did_anything = true
		else:
			var banish_map: Dictionary = state.get("banished_until_year", {})
			var banish_years: int = randi_range(1, 12)
			banish_map [str(actor.id)] = int(gs.year) + banish_years
			state ["banished_until_year"] = banish_map
			lines.append("They banished you from Niðavellir for %d years." % banish_years)
			did_anything = true

	if cripple_roll:
		var health_loss: int = randi_range(12, 38)
		var looks_loss: int = randi_range(6, 24)
		var mental_loss: int = randi_range(8, 30)
		var happiness_loss: int = randi_range(12, 36)
		actor.health = max(1, int(actor.health) - health_loss)
		actor.looks = max(0, int(actor.looks) - looks_loss)
		actor.mental_health = max(0, int(actor.mental_health) - mental_loss)
		actor.satisfaction = max(0, int(actor.satisfaction) - happiness_loss)
		lines.append("They crippled you badly: Health -%d, Looks -%d, Mental -%d, Happiness -%d." % [health_loss, looks_loss, mental_loss, happiness_loss])
		did_anything = true

	if not did_anything:
		lines.append("They let you crawl away, but not with dignity.")

	return {
		"lines": lines
	}
func _unlocked_battle_bending_choices(actor: Person) -> Array:
	var out: Array = []
	if gs == null or gs.bending_engine == null or actor == null:
		return out
	if not gs.bending_engine.has_method("get_available_bending_abilities"):
		return out
	for raw_ability in gs.bending_engine.get_available_bending_abilities(actor):
		if typeof(raw_ability) != TYPE_DICTIONARY:
			continue
		var ability: Dictionary = raw_ability.duplicate(true)
		if not bool(ability.get("unlocked", false)):
			continue
		var ability_type: String = str(ability.get("type", "")).strip_edges().to_lower()
		if ability_type not in ["attack", "defense", "control", "escape"]:
			continue
		out.append(ability)
	out.sort_custom(func (a, b): return int(a.get("current_level", a.get("level", 0))) > int(b.get("current_level", b.get("level", 0))))
	return out
func _unlocked_battle_mutation_choices(actor: Person) -> Array:
	var out: Array = []
	if gs == null or actor == null:
		return out
	if not ("power_engine" in gs) or gs.power_engine == null:
		return out
	if not gs.power_engine.has_method("get_mutated_ability_rows"):
		return out

	for raw_row in gs.power_engine.get_mutated_ability_rows(actor, {
		"source": "nidavellir_battle"
	}):
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = raw_row.duplicate(true)
		if not bool(row.get("can_use_in_nidavellir", true)):
			continue
		out.append(row)

	out.sort_custom(func (a, b): return int(a.get("power", 0)) > int(b.get("power", 0)))
	return out
func _resolve_battle_turn(actor: Person, choice: Dictionary) -> Dictionary:
	var state: Dictionary = _ensure_state()
	var encounter_raw: Variant = state.get("active_encounter", {})
	if typeof(encounter_raw) != TYPE_DICTIONARY or (encounter_raw as Dictionary).is_empty():
		return {
			"type": "scenario_commit_complete",
			"text": "The forge battle has already ended.",
			"opps": []
		}
	var encounter: Dictionary = encounter_raw
	var profile: Dictionary = _get_dwarf_memory_profile(state, actor)

	var choice_family: String = str(choice.get("choice_family", "attack")).strip_edges().to_lower()
	var power_source: String = str(choice.get("power_source", "physical")).strip_edges().to_lower()
	var round_number: int = int(encounter.get("round", 1))
	var last_power_source: String = str(encounter.get("last_power_source", "")).strip_edges().to_lower()
	var last_choice_family: String = str(encounter.get("last_choice_family", "")).strip_edges().to_lower()

	var source_streak: int = 1
	if last_power_source != "" and last_power_source == power_source:
		source_streak = int(encounter.get("source_streak", 1)) + 1

	var family_streak: int = 1
	if last_choice_family != "" and last_choice_family == choice_family:
		family_streak = int(encounter.get("family_streak", 1)) + 1

	var source_reads_raw: Variant = profile.get("source_reads", {})
	var source_reads: Dictionary = source_reads_raw if typeof(source_reads_raw) == TYPE_DICTIONARY else {}
	var family_reads_raw: Variant = profile.get("family_reads", {})
	var family_reads: Dictionary = family_reads_raw if typeof(family_reads_raw) == TYPE_DICTIONARY else {}

	var source_read_bonus: int = int(source_reads.get(power_source, 0))
	var family_read_bonus: int = int(family_reads.get(choice_family, 0))
	var adaptation_rank: int = int(encounter.get("adaptation_rank", 0))
	var counter_profile: Dictionary = _resolve_dwarf_counter_profile(encounter, profile, choice_family, power_source)
	var counter_defense_bias: int = int(counter_profile.get("defense_bias", 0))
	var counter_retaliation_bias: int = int(counter_profile.get("retaliation_bias", 0))
	var counter_diary_text: String = str(counter_profile.get("diary_text", "")).strip_edges()

	var defense_read_bonus: int = adaptation_rank + (source_read_bonus * 2) + family_read_bonus + (max(0, source_streak - 1) * 2) + max(0, family_streak - 1) + counter_defense_bias
	var retaliation_bonus: int = adaptation_rank + source_read_bonus + (family_read_bonus * 2) + (max(0, source_streak - 1) * 3) + (max(0, family_streak - 1) * 2) + counter_retaliation_bias

	var player_attack: int = 0
	var defense_bonus: int = 0
	var heal_bonus: int = 0

	match choice_family:
		"attack":
			player_attack = _resolve_attack_power(actor, choice, power_source)
			player_attack = max(0, player_attack - defense_read_bonus)
		"defend":
			defense_bonus = _resolve_defense_power(actor, choice, power_source)
			defense_bonus = max(0, defense_bonus - int(floor(float(defense_read_bonus) * 0.35)))
		_:
			player_attack = max(0, _resolve_attack_power(actor, choice, power_source) - defense_read_bonus)

	if str(choice.get("stone_name", "")).strip_edges() == "Time":
		heal_bonus = randi_range(6, 12)

	var current_player_hp: int = int(encounter.get("player_hp", 0))
	var current_dwarf_hp: int = int(encounter.get("dwarf_hp", 0))
	current_dwarf_hp = max(0, current_dwarf_hp - player_attack)

	encounter ["last_power_source"] = power_source
	encounter ["last_choice_family"] = choice_family
	encounter ["source_streak"] = source_streak
	encounter ["family_streak"] = family_streak
	encounter ["last_damage_to_dwarves"] = player_attack
	encounter ["last_damage_to_player"] = 0
	encounter ["last_shake_amount"] = 0.0

	var diary_text: String = str(choice.get("journal_text", "I fought the dwarves of Niðavellir.")).strip_edges()
	if player_attack > 0:
		diary_text += " I dealt %d damage." % player_attack
	else:
		diary_text += " They adapted and blunted my move."
	if defense_read_bonus > 0:
		diary_text += " They were reading my rhythm."
	if counter_diary_text != "":
		diary_text += " %s" % counter_diary_text

	if current_dwarf_hp <= 0:
		_register_diary_entry(actor, diary_text)
		encounter ["dwarf_hp"] = current_dwarf_hp
		state ["active_encounter"] = encounter
		gs.scenario_state ["nidavellir_state"] = state
		return _resolve_battle_victory(actor, diary_text)

	current_player_hp = min(int(encounter.get("player_hp_max", current_player_hp)), current_player_hp + heal_bonus)

	var dwarf_attack: int = 18 + randi_range(0, 16) + int(round_number * 1.5) + int(encounter.get("aggression_bias", 0)) + retaliation_bonus
	if player_attack >= 28:
		dwarf_attack += 4
	var reduced_dwarf_attack: int = max(0, dwarf_attack - defense_bonus)
	current_player_hp = max(0, current_player_hp - reduced_dwarf_attack)
	var actions_taken: Array = encounter.get("actions_taken", [])
	actions_taken.append(str(choice.get("label", choice.get("id", "Unknown action"))))
	encounter ["actions_taken"] = actions_taken

	var counter_modes_seen: Array = encounter.get("counter_modes_seen", [])
	var counter_mode: String = str(counter_profile.get("mode", "balanced")).strip_edges()
	if counter_mode != "" and counter_mode not in counter_modes_seen:
		counter_modes_seen.append(counter_mode)
	encounter ["counter_modes_seen"] = counter_modes_seen

	encounter ["rounds_survived"] = max(int(encounter.get("rounds_survived", 0)), round_number)
	encounter ["total_damage_to_dwarves"] = int(encounter.get("total_damage_to_dwarves", 0)) + player_attack
	encounter ["total_damage_to_player"] = int(encounter.get("total_damage_to_player", 0)) + reduced_dwarf_attack
	encounter ["largest_hit_to_dwarves"] = max(int(encounter.get("largest_hit_to_dwarves", 0)), player_attack)
	encounter ["largest_hit_to_player"] = max(int(encounter.get("largest_hit_to_player", 0)), reduced_dwarf_attack)
	encounter ["player_hp"] = current_player_hp
	encounter ["dwarf_hp"] = current_dwarf_hp
	encounter ["defense_bonus"] = defense_bonus
	encounter ["last_damage_to_player"] = reduced_dwarf_attack
	encounter ["last_shake_amount"] = 0.0
	if reduced_dwarf_attack >= 18:
		encounter ["last_shake_amount"] = min(18.0, 6.0 + float(reduced_dwarf_attack - 18) * 0.45)

	var response_text: String = _build_dwarf_response_text(choice, power_source, choice_family, player_attack, reduced_dwarf_attack, defense_bonus, heal_bonus, defense_read_bonus, retaliation_bonus, source_streak, family_streak, counter_profile)
	encounter ["last_response_text"] = response_text
	state ["active_encounter"] = encounter
	gs.scenario_state ["nidavellir_state"] = state

	if defense_bonus > 0:
		diary_text += " I absorbed %d damage." % defense_bonus
	if heal_bonus > 0:
		diary_text += " I regained %d health." % heal_bonus
	if reduced_dwarf_attack > 0:
		diary_text += " They hit me back for %d." % reduced_dwarf_attack
	else:
		diary_text += " Their counter failed to break through."

	_register_diary_entry(actor, diary_text)
	if current_player_hp <= 0:
		return _resolve_battle_loss(actor, diary_text)

	encounter ["round"] = round_number + 1
	state ["active_encounter"] = encounter
	gs.scenario_state ["nidavellir_state"] = state
	return _queue_battle_round(actor, response_text)

func _resolve_attack_power(_actor: Person, choice: Dictionary, power_source: String) -> int:
	match power_source:
		"stone":
			var stone_name: String = str(choice.get("stone_name", "")).strip_edges()
			match stone_name:
				"Power":
					return randi_range(34, 52)
				"Space":
					return randi_range(24, 38)
				"Reality":
					return randi_range(22, 36)
				"Time":
					return randi_range(18, 30)
				"Mind":
					return randi_range(20, 32)
				"Soul":
					return randi_range(22, 34)
			return randi_range(20, 30)
		"bending":
			var level: int = clamp(int(choice.get("ability_level", 0)), 0, 100)
			var ability_type: String = str(choice.get("ability_type", "attack")).strip_edges().to_lower()
			var base_power: int = 14 + int(float(level) * 0.52) + randi_range(0, 12)
			match ability_type:
				"attack":
					return base_power + 8
				"control":
					return base_power + 4
				"defense":
					return max(8, int(float(base_power) * 0.45))
				"escape":
					return max(6, int(float(base_power) * 0.35))
			return base_power
		"mutated_ability":
			return int(choice.get("power", randi_range(24, 46)))
		_:
			return randi_range(14, 24)

func _resolve_defense_power(actor: Person, choice: Dictionary, power_source: String) -> int:
	match power_source:
		"stone":
			var stone_name: String = str(choice.get("stone_name", "")).strip_edges()
			match stone_name:
				"Space":
					return randi_range(20, 34)
				"Time":
					return randi_range(18, 30)
				"Reality":
					return randi_range(16, 28)
			return randi_range(12, 22)
		"bending":
			var level: int = clamp(int(choice.get("ability_level", 0)), 0, 100)
			var ability_type: String = str(choice.get("ability_type", "defense")).strip_edges().to_lower()
			var base_guard: int = 12 + int(float(level) * 0.48) + randi_range(0, 10)
			match ability_type:
				"defense":
					return base_guard + 10
				"escape":
					return base_guard + 6
				"control":
					return base_guard + 4
				"attack":
					return max(8, int(float(base_guard) * 0.55))
			return base_guard
		"mutated_ability":
			return int(choice.get("guard", randi_range(18, 38)))
		_:
			if actor != null and actor.health >= 80:
				return randi_range(12, 20)
			return randi_range(8, 16)

func _resolve_battle_victory(actor: Person, diary_text: String) -> Dictionary:
	var state: Dictionary = _ensure_state()
	state ["active_encounter"] = {}
	gs.scenario_state ["nidavellir_state"] = state

	_grant_star_exposure(actor)

	var world_text:= "%s %s defeated the dwarves of Niðavellir and forced the star-forge to answer." % [
		actor.first_name,
		actor.last_name
	]
	if gs.has_method("push_world_feed"):
		gs.push_world_feed(world_text, {
			"npc_id": int(actor.id),
			"personally_relevant": true,
			"category": "cosmic",
			"event_name": "nidavellir_battle_won",
			"source": "nidavellir_engine"
		})

	return gs.scenario_engine.queue_external_scenario(_build_submission_scenario(actor, diary_text))

func _resolve_battle_loss(actor: Person, diary_text: String) -> Dictionary:
	var state: Dictionary = _ensure_state()
	var encounter_raw: Variant = state.get("active_encounter", {})
	var encounter: Dictionary = encounter_raw if typeof(encounter_raw) == TYPE_DICTIONARY else {}
	var profile: Dictionary = _get_dwarf_memory_profile(state, actor)

	var source_reads_raw: Variant = profile.get("source_reads", {})
	var source_reads: Dictionary = source_reads_raw if typeof(source_reads_raw) == TYPE_DICTIONARY else {}
	var family_reads_raw: Variant = profile.get("family_reads", {})
	var family_reads: Dictionary = family_reads_raw if typeof(family_reads_raw) == TYPE_DICTIONARY else {}

	var last_power_source: String = str(encounter.get("last_power_source", "physical")).strip_edges().to_lower()
	var last_choice_family: String = str(encounter.get("last_choice_family", "attack")).strip_edges().to_lower()

	source_reads [last_power_source] = int(source_reads.get(last_power_source, 0)) + 1
	family_reads [last_choice_family] = int(family_reads.get(last_choice_family, 0)) + 1
	profile ["losses"] = int(profile.get("losses", 0)) + 1
	profile ["total_fights"] = int(profile.get("total_fights", 0)) + 1
	profile ["source_reads"] = source_reads
	profile ["family_reads"] = family_reads
	profile ["last_outcome"] = "loss"
	profile ["last_damage_to_player"] = int(encounter.get("last_damage_to_player", 0))
	profile ["last_damage_to_dwarves"] = int(encounter.get("last_damage_to_dwarves", 0))
	_store_dwarf_memory_profile(state, actor, profile)

	state ["active_encounter"] = {}
	gs.scenario_state ["nidavellir_state"] = state
	var confiscated_stone: String = _confiscate_random_stone(actor)
	var permanent_banish_roll: bool = randf() < 0.15
	var temporary_banish_roll: bool = randf() < 0.62
	if permanent_banish_roll:
		var permanent_ids: Array = state.get("permanent_banish_ids", [])
		if int(actor.id) not in permanent_ids:
			permanent_ids.append(int(actor.id))
		state ["permanent_banish_ids"] = permanent_ids
	elif temporary_banish_roll:
		var banish_map: Dictionary = state.get("banished_until_year", {})
		banish_map [str(actor.id)] = int(gs.year) + randi_range(TEMP_BANISH_MIN_YEARS, TEMP_BANISH_MAX_YEARS)
		state ["banished_until_year"] = banish_map
	gs.scenario_state ["nidavellir_state"] = state

	var followup_result: Dictionary = {}
	actor.cause_of_death = "Smoked by Dwarves"
	actor.memories.append("The Dwarves sealed your body so nobody could ever find it.")
	if gs.health_engine != null and gs.health_engine.has_method("handle_death"):
		gs.health_engine.handle_death(actor, "Smoked by Dwarves")
	if actor == gs.player and gs.life_engine != null and gs.life_engine.has_method("_handle_player_death"):
		followup_result = gs.life_engine.call("_handle_player_death")

	var is_player_loss: bool = actor == gs.player
	var world_text:= "%s %s lost the forge battle in Niðavellir." % [
		actor.first_name,
		actor.last_name
	]
	if is_player_loss:
		world_text = "I lost the forge battle in Niðavellir."
	if confiscated_stone != "":
		world_text += " The dwarves confiscated the %s Stone." % confiscated_stone
	if permanent_banish_roll:
		world_text += " They banished me forever." if is_player_loss else " They banished them forever."
	elif temporary_banish_roll:
		world_text += " They cast me out for a time." if is_player_loss else " They cast them out for a time."
	world_text += " They gladly took my life." if is_player_loss else " They gladly took their life."
	if gs.has_method("push_world_feed"):
		gs.push_world_feed(world_text, {
			"npc_id": int(actor.id),
			"personally_relevant": true,
			"category": "cosmic",
			"event_name": "nidavellir_battle_lost",
			"source": "nidavellir_engine"
		})

	var popup_text: String = _build_dwarf_defeat_popup_text(actor, encounter, confiscated_stone, permanent_banish_roll, temporary_banish_roll, state)
	return {
		"type": "scenario_commit_complete",
		"text": diary_text + " They gladly took your life.",
		"popup_title": "Defeat",
		"popup_text": popup_text,
		"popup_footer": "Tap anywhere to continue.",
		"followup_result": followup_result,
		"opps": []
	}
func _build_battle_stats_summary(encounter: Dictionary) -> String:
	if encounter.is_empty():
		return "Fight Stats:\nNo battle stats were recorded."

	var actions_taken: Array = encounter.get("actions_taken", [])
	var counter_modes_seen: Array = encounter.get("counter_modes_seen", [])

	var action_line: String = "None"
	if not actions_taken.is_empty():
		action_line = ", ".join(actions_taken)

	var counter_line: String = "None"
	if not counter_modes_seen.is_empty():
		counter_line = ", ".join(counter_modes_seen)

	return "Fight Stats:\nRounds Survived: %d\nDamage You Dealt: %d\nDamage You Took: %d\nLargest Hit You Landed: %d\nLargest Hit They Landed: %d\nCounters Seen: %s\nYour Actions: %s" % [
		int(encounter.get("rounds_survived", encounter.get("round", 1))),
		int(encounter.get("total_damage_to_dwarves", encounter.get("last_damage_to_dwarves", 0))),
		int(encounter.get("total_damage_to_player", encounter.get("last_damage_to_player", 0))),
		int(encounter.get("largest_hit_to_dwarves", encounter.get("last_damage_to_dwarves", 0))),
		int(encounter.get("largest_hit_to_player", encounter.get("last_damage_to_player", 0))),
		counter_line,
		action_line
	]


func _build_dwarf_defeat_popup_text(actor: Person, encounter: Dictionary, confiscated_stone: String, permanent_banish_roll: bool, temporary_banish_roll: bool, state: Dictionary) -> String:
	var lines: Array = []
	lines.append("The dwarves overwhelmed you beneath the dying star.")
	lines.append("The forge did not go quiet. It watched.")
	lines.append(_build_battle_stats_summary(encounter))

	if confiscated_stone != "":
		lines.append("They tore the %s Stone away from you." % confiscated_stone)

	if permanent_banish_roll:
		lines.append("They banished you from Niðavellir forever.")
	elif temporary_banish_roll:
		var until_year: int = int((state.get("banished_until_year", {}) as Dictionary).get(str(actor.id), gs.year))
		lines.append("They banished you from Niðavellir until %s." % str(_format_year(until_year)))

	lines.append("They gladly took your life.")
	lines.append("The Dwarves sealed your body so nobody could ever find it.")
	return "\n\n".join(lines)
func _build_submission_scenario(actor: Person, preface_text: String = "") -> Dictionary:
	var has_all_stones: bool = _has_all_stones(actor)

	var choices: Array = []
	if has_all_stones:
		choices.append({
			"id": "forge_infinity_gauntlet",
			"label": "Forge the Infinity Gauntlet",
			"journal_text": "I ordered the dwarves of Niðavellir to forge the Infinity Gauntlet."
		})
	else:
		choices.append({
			"id": "forge_gauntlet_locked",
			"label": "Forge the Infinity Gauntlet (Need all 6 Stones)",
			"journal_text": "",
			"disabled": true
		})

	choices.append({
		"id": "forge_mjolnir",
		"label": "Ask them to forge Mjolnir",
		"journal_text": "I asked the dwarves of Niðavellir to forge Mjolnir."
	})
	choices.append({
		"id": "forge_stormbreaker",
		"label": "Ask them to forge Stormbreaker",
		"journal_text": "I asked the dwarves of Niðavellir to forge Stormbreaker."
	})
	choices.append({
		"id": "leave_the_forge",
		"label": "Leave the forge for now",
		"journal_text": "I left Niðavellir with the forge still waiting behind me."
	})

	var lines: Array = []
	if preface_text.strip_edges() != "":
		lines.append(preface_text)
	lines.append("The dwarves tremble before you.")
	lines.append("They say they will do what you ask.")
	lines.append("The forge burns with the heart of a dying star.")

	return {
		"id": "nidavellir_submission_%d" % int(gs.year),
		"source": "nidavellir_engine",
		"category": "artifact",
		"cooldown_key": "nidavellir_submission",
		"resolver_method": "_resolve_nidavellir_choice",
		"panel_title": "NIDAVELLIR",
		"footer_text": "Choose what the dwarves should forge.",
		"prompt": "\n\n".join(lines),
		"choices": choices
	}

func _forge_infinity_gauntlet(actor: Person) -> Dictionary:
	if gs == null or gs.artifacts_engine == null:
		return {
			"type": "scenario_commit_complete",
			"text": "The forge could not bind the gauntlet right now.",
			"opps": []
		}

	var forged: bool = false
	if gs.artifacts_engine.has_method("forge_gauntlet"):
		forged = bool(gs.artifacts_engine.forge_gauntlet())

	if not forged:
		return {
			"type": "scenario_commit_complete",
			"text": "The dwarves refuse. The gauntlet cannot be forged yet.",
			"popup_title": "Forge Rejected",
			"popup_text": "The ring-world rejects the command.\n\nThe Infinity Gauntlet still requires all six stones under your authority.",
			"popup_footer": "Tap anywhere to continue.",
			"opps": []
		}

	_register_forged_item(actor, "Infinity Gauntlet")
	_grant_star_exposure(actor)

	var diary_text:= "I commanded the dwarves of Niðavellir to forge the Infinity Gauntlet from the heart of a dying star."
	_register_diary_entry(actor, diary_text)

	return {
		"type": "scenario_commit_complete",
		"text": diary_text,
		"popup_title": "Forged",
		"popup_text": "The forge roared.\n\nMetal drank starlight.\n\nThe Infinity Gauntlet was shaped in Niðavellir.",
		"popup_footer": "Tap anywhere to continue.",
		"opps": []
	}

func _forge_star_weapon(actor: Person, item_name: String) -> Dictionary:
	if gs == null or gs.belongings_engine == null or actor == null:
		return {
			"type": "scenario_commit_complete",
			"text": "The forge failed to answer.",
			"opps": []
		}

	if gs.belongings_engine.has_method("has_item_named") and gs.belongings_engine.has_item_named(actor, "Artifacts", item_name):
		return {
			"type": "scenario_commit_complete",
			"text": "I already possess %s." % item_name,
			"popup_title": "Already Forged",
			"popup_text": "%s is already in your possession." % item_name,
			"popup_footer": "Tap anywhere to continue.",
			"opps": []
		}

	var item:= {
		"id": gs.next_id,
		"name": item_name,
		"display_name": item_name,
		"type": "CosmicWeapon",
		"item_family": "nidavellir_forged",
		"forged_in": NIDAVELLIR_NAME,
		"forged_year": int(gs.year),
		"worthiness_required": item_name == "Mjolnir",
		"bifrost_access": item_name == "Stormbreaker",
		"lore": "Forged in Niðavellir from the heart of a dying star."
	}
	gs.next_id += 1
	gs.belongings_engine.add_item(actor, item, "Artifacts")
	_register_forged_item(actor, item_name)
	_grant_star_exposure(actor)

	if item_name == "Mjolnir":
		if "MjolnirBearer" not in actor.traits:
			actor.traits.append("MjolnirBearer")
		_tick_mjolnir_attunement(actor, _ensure_state())
	elif item_name == "Stormbreaker":
		if "StormbreakerBearer" not in actor.traits:
			actor.traits.append("StormbreakerBearer")

	var diary_text:= "I asked the dwarves of Niðavellir to forge %s, and they did." % item_name
	_register_diary_entry(actor, diary_text)

	var world_text:= "%s %s had %s forged in Niðavellir." % [
		actor.first_name,
		actor.last_name,
		item_name
	]
	if gs.has_method("push_world_feed"):
		gs.push_world_feed(world_text, {
			"npc_id": int(actor.id),
			"personally_relevant": true,
			"category": "cosmic",
			"event_name": "nidavellir_forged_item",
			"source": "nidavellir_engine"
		})

	var popup_text:= "%s was forged in the starfire of Niðavellir." % item_name
	if item_name == "Mjolnir":
		popup_text += "\n\nIt will not stay a binary relic. It will keep judging you over time."
	if item_name == "Stormbreaker":
		popup_text += "\n\nIt carries the future path to summon the Bifrost."

	return {
		"type": "scenario_commit_complete",
		"text": diary_text,
		"popup_title": "Forged",
		"popup_text": popup_text,
		"popup_footer": "Tap anywhere to continue.",
		"opps": []
	}

func _grant_star_exposure(actor: Person) -> void:
	if actor == null:
		return

	var state: Dictionary = _ensure_state()
	var profiles: Dictionary = state.get("star_exposure_profiles", {})
	var pid: String = str(actor.id)
	var profile: Dictionary = profiles.get(pid, {})

	if profile.is_empty():
		var modes:= ["mental_clarity", "slow_health_decay", "cosmic_sensitivity"]
		profile = {
			"mode": modes [randi() % modes.size()],
			"first_year": int(gs.year),
			"last_tick_year": int(gs.year)
		}
		profiles [pid] = profile
		state ["star_exposure_profiles"] = profiles
		gs.scenario_state ["nidavellir_state"] = state

		if "StarExposed" not in actor.traits:
			actor.traits.append("StarExposed")

		var diary_text:= "I've been near a dying star. My body remembers."
		_register_diary_entry(actor, diary_text)

func _tick_star_exposure(actor: Person, state: Dictionary) -> void:
	if actor == null:
		return

	var profiles: Dictionary = state.get("star_exposure_profiles", {})
	var pid: String = str(actor.id)
	if not profiles.has(pid):
		return

	var profile: Dictionary = profiles.get(pid, {})
	var last_tick_year: int = int(profile.get("last_tick_year", -999999))
	if last_tick_year == int(gs.year):
		return

	var mode: String = str(profile.get("mode", "mental_clarity")).strip_edges()
	match mode:
		"mental_clarity":
			actor.mental_health = clamp(int(actor.mental_health) + 1, 0, 100)
			actor.smarts = clamp(int(actor.smarts) + int(randi() % 2), 0, 100)
		"slow_health_decay":
			actor.health = clamp(int(actor.health) + 1, 0, 100)
		"cosmic_sensitivity":
			actor.imagination = clamp(int(actor.imagination) + 1, 0, 100)
			actor.satisfaction = clamp(int(actor.satisfaction) + int(randi() % 2), 0, 100)

	profile ["last_tick_year"] = int(gs.year)
	profiles [pid] = profile
	state ["star_exposure_profiles"] = profiles
	gs.scenario_state ["nidavellir_state"] = state

func _tick_mjolnir_attunement(actor: Person, state: Dictionary) -> void:
	if actor == null or not _has_forged_item(actor, "Mjolnir"):
		return

	var worthy_now: bool = _estimate_worthiness_score(actor) >= 18.0
	var pid: String = str(actor.id)
	var attunement_map: Dictionary = state.get("mjolnir_attunement", {})
	var current: Dictionary = attunement_map.get(pid, {})
	var previous_responsive: bool = bool(current.get("responsive", true))

	current ["score"] = _estimate_worthiness_score(actor)
	current ["responsive"] = worthy_now
	current ["last_year"] = int(gs.year)
	attunement_map [pid] = current
	state ["mjolnir_attunement"] = attunement_map
	gs.scenario_state ["nidavellir_state"] = state

	if worthy_now == previous_responsive:
		return

	var diary_text:= ""
	if worthy_now:
		diary_text = "Mjolnir answered me cleanly again. Something in me realigned."
	else:
		diary_text = "Mjolnir felt heavier this year. It did not answer like it once did."
	_register_diary_entry(actor, diary_text)

func can_access_asgard(actor: Person) -> bool:
	if actor == null:
		return false
	var state: Dictionary = _ensure_state()
	return _has_forged_item(actor, "Stormbreaker") or _is_currently_worthy(actor, state)

func _is_currently_worthy(actor: Person, state: Dictionary) -> bool:
	if actor == null:
		return false
	var attunement_map: Dictionary = state.get("mjolnir_attunement", {})
	var current: Dictionary = attunement_map.get(str(actor.id), {})
	if current.is_empty():
		return _estimate_worthiness_score(actor) >= 18.0
	return bool(current.get("responsive", false))

func _estimate_worthiness_score(actor: Person) -> float:
	if actor == null:
		return -999999.0

	var score: float = 0.0
	if "Kind" in actor.traits:
		score += 14.0
	if "Generous" in actor.traits:
		score += 12.0
	if "Loyal" in actor.traits:
		score += 9.0
	if "Humble" in actor.traits:
		score += 10.0
	if "Cruel" in actor.traits:
		score -= 18.0
	if "Evil" in actor.traits:
		score -= 22.0
	if "Ruthless" in actor.traits:
		score -= 14.0
	if "Ambitious" in actor.traits:
		score -= 4.0

	score += float(int(actor.mental_health) - 50) * 0.12
	score += float(int(actor.satisfaction) - 50) * 0.08
	score += float(int(actor.smarts) - 50) * 0.05

	if actor.partner != null:
		score += 2.0
	if actor.children.size() > 0:
		score += 3.0

	return score

func _register_diary_entry(actor: Person, text: String) -> void:
	if actor == null:
		return
	var clean_text: String = text.strip_edges()
	if clean_text == "":
		return
	actor.memories.append(clean_text)
	if gs.narrative_engine != null:
		gs.narrative_engine.log_event(actor, {
			"type": "text",
			"text": clean_text
		})

func _register_forged_item(actor: Person, item_name: String) -> void:
	if actor == null:
		return
	var state: Dictionary = _ensure_state()
	var registry: Dictionary = state.get("forged_registry", {})
	var pid: String = str(actor.id)
	var items: Array = registry.get(pid, [])
	if item_name not in items:
		items.append(item_name)
	registry [pid] = items
	state ["forged_registry"] = registry
	gs.scenario_state ["nidavellir_state"] = state

func _has_forged_item(actor: Person, item_name: String) -> bool:
	if actor == null:
		return false
	if gs == null or gs.belongings_engine == null:
		return false
	if gs.belongings_engine.has_method("has_item_named") and gs.belongings_engine.has_item_named(actor, "Artifacts", item_name):
		return true
	var state: Dictionary = _ensure_state()
	var registry: Dictionary = state.get("forged_registry", {})
	var items: Array = registry.get(str(actor.id), [])
	return item_name in items

func _meets_surface_gate(actor: Person) -> bool:
	if actor == null or gs == null or gs.artifacts_engine == null:
		return false
	var stones: Array = _owned_stones(actor)
	return stones.size() >= MIN_STONES_REQUIRED and REQUIRED_GATE_STONE in stones

func _owned_stones(actor: Person) -> Array:
	var out: Array = []
	if actor == null or gs == null or gs.artifacts_engine == null:
		return out
	if not gs.artifacts_engine.has_method("person_has_stone"):
		return out

	for stone_name in ["Mind", "Reality", "Space", "Time", "Soul", "Power"]:
		if gs.artifacts_engine.person_has_stone(actor, stone_name):
			out.append(stone_name)
	return out

func _has_all_stones(actor: Person) -> bool:
	return _owned_stones(actor).size() >= 6

func _confiscate_random_stone(actor: Person) -> String:
	if actor == null or gs == null or gs.artifacts_engine == null:
		return ""
	var stones: Array = _owned_stones(actor)
	if stones.is_empty():
		return ""
	var stone_name: String = stones [randi() % stones.size()]
	if gs.artifacts_engine.has_method("confiscate_stone_from_person"):
		var removed: bool = bool(gs.artifacts_engine.confiscate_stone_from_person(actor, stone_name))
		if removed:
			return stone_name
	return ""

func _is_banished(actor: Person, state: Dictionary) -> bool:
	if actor == null:
		return false
	return _is_permanently_banished(actor, state) or int((state.get("banished_until_year", {}) as Dictionary).get(str(actor.id), -999999)) >= int(gs.year)

func _is_permanently_banished(actor: Person, state: Dictionary) -> bool:
	if actor == null:
		return false
	var permanent_ids: Array = state.get("permanent_banish_ids", [])
	return int(actor.id) in permanent_ids

func _format_year(year_value: int) -> String:
	if year_value < 0:
		return "%d BC" % abs(year_value)
	return "%d AD" % year_value