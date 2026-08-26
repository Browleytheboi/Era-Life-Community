extends Resource
class_name DynamicWorldEventEngine

var gs

func _init(_gs):
	gs = _gs
	if gs != null and gs.event_bus != null:
		gs.event_bus.subscribe(ActionEventTypes.YEAR_PASSED, self, "yearly_world_events")




func yearly_world_events(_payload:= {}):
	var payload: Dictionary = (
		_payload as Dictionary
		if typeof(_payload) == TYPE_DICTIONARY
		else {}
	)

	if (
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
		).strip_edges() == "age_up_runtime"
	):
		return

	_era_events()
	_artifact_events()
	_bending_events()
	_bonnet_events()
	_asset_ecology_events()
func _asset_ecology_events():
	if gs == null:
		return

	var property_rollup: Dictionary = {}
	if gs.property_engine != null:
		property_rollup = gs.property_engine.get_global_asset_signal_rollup()

	var vehicle_rollup: Dictionary = {}
	if gs.vehicle_engine != null:
		vehicle_rollup = gs.vehicle_engine.get_global_asset_signal_rollup()

	var total_assets: int = int(property_rollup.get("asset_count", 0)) + int(vehicle_rollup.get("asset_count", 0))
	if total_assets <= 0:
		return

	var dependency_pressure: float = float(property_rollup.get("dependency_pressure", 0.0)) + float(vehicle_rollup.get("dependency_pressure", 0.0))
	var property_portfolios: Dictionary = property_rollup.get("portfolio_tags", {})
	var vehicle_portfolios: Dictionary = vehicle_rollup.get("portfolio_tags", {})

	if int(vehicle_portfolios.get("fleets", 0)) >= 3 and randi() % 5 == 0:
		gs.push_world_feed(
			"Merchant fleets and transport dynasties are reshaping regional trade routes.",
			{
				"category": "world",
				"event_name": "asset_fleet_pressure",
				"source": "dynamic_world_event_engine"
			}
		)

	if int(property_portfolios.get("dynastic_properties", 0)) >= 2 and randi() % 5 == 0:
		gs.push_world_feed(
			"Elite family seats and fortified estates are concentrating local influence.",
			{
				"category": "world",
				"event_name": "asset_dynastic_property_pressure",
				"source": "dynamic_world_event_engine"
			}
		)

	if dependency_pressure >= 3.0 and randi() % 4 == 0:
		gs.push_world_feed(
			"Infrastructure strain rises as ambitious ownership outpaces what regions can properly support.",
			{
				"category": "world",
				"event_name": "asset_dependency_pressure",
				"source": "dynamic_world_event_engine"
			}
		)

	var event_hooks: Dictionary = {}
	_merge_hook_counter_into(event_hooks, property_rollup.get("event_hooks", {}))
	_merge_hook_counter_into(event_hooks, vehicle_rollup.get("event_hooks", {}))

	if not event_hooks.is_empty() and randi() % 7 == 0:
		var hook_names: Array = event_hooks.keys()
		var hook_name: String = str(hook_names [randi() % hook_names.size()]).replace("_", " ")
		gs.push_world_feed(
			"Rumors spread that %s pressures are rising around the world's most notable holdings." % hook_name,
			{
				"category": "world",
				"event_name": "asset_hook_pressure",
				"source": "dynamic_world_event_engine"
			}
		)


func _merge_hook_counter_into(dest: Dictionary, raw) -> void:
	if typeof(raw) != TYPE_DICTIONARY:
		return
	for key in raw.keys():
		var k:= str(key)
		dest [k] = int(dest.get(k, 0)) + int(raw.get(key, 0))





func _era_events():

	if randi() % 200 != 0:
		return

	var events = [
		"A massive economic crisis spreads across nations.",
		"A religious movement sweeps the world.",
		"Political revolutions erupt in multiple realms.",
		"A mysterious traveler spreads rumors of hidden power."
	]

	gs.push_world_feed(events.pick_random(), {
		"category": "world",
		"event_name": "dynamic_world_event",
		"source": "dynamic_world_event_engine"
	})





func _artifact_events():

	var total = 0

	for arr in gs.artifacts_engine.ownership.values():
		total += arr.size()

	if total >= 3 and randi() % 4 == 0:
		gs.push_world_feed(
			"⚡ Multiple Infinity Stones have surfaced. Reality destabilizes.",
			{
				"category": "artifact",
				"event_name": "artifact_world_pressure",
				"source": "dynamic_world_event_engine"
			}
		)





func _bending_events():
	if gs == null:
		return

	var avatar_exists: bool = false

	if (
		gs.player != null
		and gs.player.alive
		and str(
			gs.player.bending_type
		).strip_edges().to_lower() == "avatar"
	):
		avatar_exists = true

	if (
		not avatar_exists
		and typeof(
			gs.scenario_state
		) == TYPE_DICTIONARY
	):
		avatar_exists = bool(
			gs.scenario_state.get(
				"resident_avatar_exists",
				false
			)
		)

	if (
		avatar_exists
		and randi() % 50 == 0
	):
		gs.push_world_feed(
			(
				"All Nations shift their power structures "
				+ "in response to the Avatar."
			),
			{
				"category": "bending",
				"event_name": "avatar_world_reaction",
				"source": (
					"dynamic_world_event_engine"
				)
			}
		)



func _bonnet_events():

	if randi() % 500 == 0:

		gs.push_world_feed(
			"A mysterious powerful red bonnet appeared somewhere in the world.",
			{
				"category": "artifact",
				"event_name": "red_bonnet_rumor",
				"source": "dynamic_world_event_engine"
			}
		)
func nominate_scenarios_for_player(context:= {}) -> Array:
	var out: Array = []
	if gs == null:
		return out
	var player: Person = context.get("player", null)
	if player == null or not player.alive:
		return out
	out.append_array(_asset_native_property_scenarios(context))
	out.append_array(_asset_native_vehicle_scenarios(context))
	out.append_array(_asset_native_mythic_scenarios(context))
	return out
func _asset_native_mythic_scenarios(context:= {}) -> Array:
	var out: Array = []
	var year: int = int(context.get("year", 0))

	out.append({
		"id": "asset_infinity_stone_collector_pressure_%d" % year,
		"source": "dynamic_world_event_engine",
		"category": "general",
		"era_tags": ["any"],
		"reality_modes": ["enhanced", "chaos"],
		"reality_weights": {
			"enhanced": 1.0,
			"chaos": 1.18
		},
		"tone": "ominous",
		"rarity": 0.72,
		"cooldown_key": "asset.infinity_stone.collector_pressure",
		"cooldown_years": 2,
		"priority": 15,
		"min_age": 12,
		"max_age": 130,
		"asset_namespace_preferences": { "artifact.infinity_stone": 2.75},
		"required_asset_event_hooks": ["artifact_hunters"],
		"asset_identity_mode": ["cosmic_bearer"],
		"asset_weight_status_signals": { "public_attention": 2.0},
		"asset_weight_pressure_profile": { "criminal_usefulness": 2.0, "spectacle": 1.5},
		"asset_tier_floor": 4.0,
		"asset_uniqueness_bias": 2.4,
		"asset_arc_family": "infinity_stone_attention",
		"asset_arc_step": "collector_pressure",
		"asset_repeat_group": "asset.infinity_stone.attention",
		"asset_echoes_world_feed": true,
		"asset_echoes_memory": true,
		"asset_echoes_reputation": true,
		"prompt": "The kind of people who track impossible objects are starting to circle my orbit. Do I vanish, bait them out, or study them first?",
		"followup_hooks": ["asset.infinity_stone.attention.collector_pressure"],
		"bias_payloads": {},
		"choices": [
			{
				"id": "vanish_from_view",
				"label": "Disappear from view and tighten access.",
				"journal_line": "I disappeared from view and tightened access around the thing people wanted from me.",
				"followup_hooks": ["asset.infinity_stone.attention.vanish"],
				"bias_payloads": {
					"crime_pressure": { "rumor_heat": -1.0},
					"relationship_bias": { "social_visibility": -2.0},
					"expiry": { "years": 1}
				}
			},
			{
				"id": "bait_them_out",
				"label": "Bait the watchers into revealing themselves.",
				"journal_line": "I baited the watchers into revealing themselves before they could move in the dark.",
				"followup_hooks": ["asset.infinity_stone.attention.bait"],
				"bias_payloads": {
					"reputation_bias": { "public_attention": 3.0},
					"crime_pressure": { "rumor_heat": 2.5},
					"expiry": { "years": 1}
				}
			},
			{
				"id": "study_the_pattern",
				"label": "Study the pattern before making a move.",
				"journal_line": "I studied the pattern around the object instead of reacting like panic owned me.",
				"followup_hooks": ["asset.infinity_stone.attention.study"],
				"bias_payloads": {
					"career_bias": { "ambition_weight": 2.0},
					"health_bias": { "stress_delta": 1.0},
					"expiry": { "years": 1}
				}
			}
		]
	})

	out.append({
		"id": "asset_dragon_ball_pilgrim_leak_%d" % year,
		"source": "dynamic_world_event_engine",
		"category": "general",
		"era_tags": ["any"],
		"reality_modes": ["enhanced", "chaos"],
		"reality_weights": {
			"enhanced": 1.0,
			"chaos": 1.12
		},
		"tone": "mysterious",
		"rarity": 0.74,
		"cooldown_key": "asset.dragonball.pilgrims",
		"cooldown_years": 2,
		"priority": 14,
		"min_age": 10,
		"max_age": 130,
		"asset_namespace_preferences": { "artifact.dragon_ball": 2.6},
		"required_asset_event_hooks": ["wish_seekers"],
		"asset_identity_mode": ["wish_anchor"],
		"asset_weight_pressure_profile": { "spectacle": 1.5, "criminal_usefulness": 1.0},
		"asset_tier_floor": 4.0,
		"asset_uniqueness_bias": 2.1,
		"asset_arc_family": "dragonball_visibility",
		"asset_arc_step": "pilgrim_leak",
		"asset_repeat_group": "asset.dragonball.visibility",
		"asset_echoes_world_feed": true,
		"asset_echoes_memory": true,
		"asset_echoes_reputation": true,
		"prompt": "Too many people are suddenly asking the kind of questions only seekers ask. Do I redirect the trail, gather them, or test who is lying?",
		"followup_hooks": ["asset.dragonball.visibility.pilgrim_leak"],
		"bias_payloads": {},
		"choices": [
			{
				"id": "redirect_the_trail",
				"label": "Redirect the trail somewhere else.",
				"journal_line": "I redirected the trail so the wrong people would chase the wrong light.",
				"followup_hooks": ["asset.dragonball.visibility.redirect"],
				"bias_payloads": {
					"crime_pressure": { "rumor_heat": -1.0},
					"reputation_bias": { "public_attention": 1.0},
					"expiry": { "years": 1}
				}
			},
			{
				"id": "gather_the_seekers",
				"label": "Gather the seekers and read the room.",
				"journal_line": "I gathered the seekers so I could study what kind of hunger was actually standing in front of me.",
				"followup_hooks": ["asset.dragonball.visibility.gather"],
				"bias_payloads": {
					"relationship_bias": { "social_visibility": 3.0},
					"reputation_bias": { "public_attention": 2.0},
					"expiry": { "years": 1}
				}
			},
			{
				"id": "test_the_liars",
				"label": "Test who is lying about why they came.",
				"journal_line": "I tested the room until the lies started shaking loose from the truth.",
				"followup_hooks": ["asset.dragonball.visibility.test"],
				"bias_payloads": {
					"career_bias": { "ambition_weight": 1.5},
					"crime_pressure": { "rumor_heat": 1.0},
					"expiry": { "years": 1}
				}
			}
		]
	})

	out.append({
		"id": "asset_red_bonnet_devotion_pressure_%d" % year,
		"source": "dynamic_world_event_engine",
		"category": "general",
		"era_tags": ["any"],
		"reality_modes": ["enhanced", "chaos"],
		"reality_weights": {
			"enhanced": 1.0,
			"chaos": 1.15
		},
		"tone": "sacred",
		"rarity": 0.7,
		"cooldown_key": "asset.red_bonnet.devotion",
		"cooldown_years": 2,
		"priority": 15,
		"min_age": 12,
		"max_age": 130,
		"asset_namespace_preferences": { "artifact.red_bonnet": 3.0},
		"required_asset_event_hooks": ["devotee_attention"],
		"asset_identity_mode": ["mythic_bearer"],
		"asset_weight_status_signals": { "public_attention": 2.0, "romance_signal": 2.0},
		"asset_weight_pressure_profile": { "spectacle": 2.0, "community_belonging": 1.5},
		"asset_tier_floor": 4.0,
		"asset_uniqueness_bias": 2.8,
		"asset_arc_family": "red_bonnet_devotion",
		"asset_arc_step": "devotion_pressure",
		"asset_repeat_group": "asset.red_bonnet.devotion",
		"asset_echoes_world_feed": true,
		"asset_echoes_memory": true,
		"asset_echoes_reputation": true,
		"prompt": "People are starting to project legend onto me faster than I can control it. Do I embrace the symbol, humble the image, or gate access hard?",
		"followup_hooks": ["asset.red_bonnet.devotion.pressure"],
		"bias_payloads": {},
		"choices": [
			{
				"id": "embrace_the_symbol",
				"label": "Embrace the symbol and lead from it.",
				"journal_line": "I embraced the symbol forming around me instead of pretending it wasn’t already changing the room.",
				"followup_hooks": ["asset.red_bonnet.devotion.embrace"],
				"bias_payloads": {
					"reputation_bias": { "public_attention": 4.0},
					"relationship_bias": { "social_visibility": 3.0},
					"expiry": { "years": 1}
				}
			},
			{
				"id": "humble_the_image",
				"label": "Humble the image before it swallows me.",
				"journal_line": "I humbled the image around me before myth could start speaking louder than my choices.",
				"followup_hooks": ["asset.red_bonnet.devotion.humble"],
				"bias_payloads": {
					"health_bias": { "stress_delta": -1.0},
					"reputation_bias": { "public_attention": -1.0},
					"expiry": { "years": 1}
				}
			},
			{
				"id": "gate_access_hard",
				"label": "Gate access hard and protect the center.",
				"journal_line": "I gated access hard and protected the center before the legend could turn into a crowd problem.",
				"followup_hooks": ["asset.red_bonnet.devotion.gate"],
				"bias_payloads": {
					"crime_pressure": { "rumor_heat": 1.0},
					"relationship_bias": { "social_visibility": -1.0},
					"expiry": { "years": 1}
				}
			}
		]
	})

	return out


func _asset_native_property_scenarios(context:= {}) -> Array:
	var out: Array = []
	var year: int = int(context.get("year", 0))

	out.append({
		"id": "asset_castle_siege_rumor_%d" % year,
		"source": "dynamic_world_event_engine",
		"category": "general",
		"era_tags": ["any"],
		"reality_modes": ["realistic", "enhanced", "chaos"],
		"reality_weights": {
			"realistic": 1.0,
			"enhanced": 1.05,
			"chaos": 1.1
		},
		"tone": "ominous",
		"rarity": 0.82,
		"cooldown_key": "asset.castle.fortification",
		"cooldown_years": 2,
		"priority": 14,
		"min_age": 16,
		"max_age": 130,
		"asset_namespace_preferences": { "property.castle": 2.5},
		"asset_class_filters": ["property.feature.fortified"],
		"asset_identity_mode": ["fortress", "dynasty_seat"],
		"asset_tier_floor": 3.0,
		"asset_uniqueness_bias": 2.0,
		"asset_arc_family": "castle_fortification",
		"asset_arc_step": "siege_rumor",
		"asset_repeat_group": "asset.castle.fortification",
		"asset_echoes_world_feed": true,
		"asset_echoes_memory": true,
		"asset_echoes_reputation": true,
		"prompt": "Rumors reach me that people have started studying the weak points around my seat. How do I respond?",
		"followup_hooks": ["asset.castle.fortification.siege_rumor"],
		"bias_payloads": {},
		"choices": [
			{
				"id": "reinforce_quietly",
				"label": "Quietly reinforce the grounds and question the staff.",
				"journal_line": "I quietly reinforced the grounds and started looking for the weak links around my seat.",
				"followup_hooks": ["asset.castle.fortification.reinforce"],
				"bias_payloads": {
					"reputation_bias": { "public_attention": 1.0},
					"crime_pressure": { "rumor_heat": 1.5},
					"expiry": { "years": 1}
				}
			},
			{
				"id": "make_a_show",
				"label": "Make a public display of strength.",
				"journal_line": "I made a public display of strength so nobody would mistake my seat for something soft.",
				"followup_hooks": ["asset.castle.fortification.show_of_force"],
				"bias_payloads": {
					"reputation_bias": { "public_attention": 5.0},
					"relationship_bias": { "social_visibility": 2.0},
					"expiry": { "years": 1}
				}
			}
		]
	})

	out.append({
		"id": "asset_castle_succession_scrutiny_%d" % year,
		"source": "dynamic_world_event_engine",
		"category": "general",
		"era_tags": ["any"],
		"reality_modes": ["realistic", "enhanced", "chaos"],
		"reality_weights": {
			"realistic": 1.05,
			"enhanced": 1.0,
			"chaos": 0.95
		},
		"tone": "tense",
		"rarity": 0.78,
		"cooldown_key": "asset.castle.succession",
		"cooldown_years": 2,
		"priority": 13,
		"min_age": 18,
		"max_age": 130,
		"asset_namespace_preferences": { "property.castle": 2.0},
		"asset_identity_mode": ["dynasty_seat", "inheritance_anchor"],
		"min_asset_provenance_signals": { "inherited": 1.0},
		"asset_weight_status_signals": { "dynastic_legitimacy": 4.0},
		"asset_weight_portfolio_tags": ["portfolio_mood.old_blood", "portfolio_mood.inherited_order"],
		"asset_arc_family": "castle_succession",
		"asset_arc_step": "succession_scrutiny",
		"asset_repeat_group": "asset.castle.succession",
		"asset_echoes_world_feed": true,
		"asset_echoes_memory": true,
		"asset_echoes_reputation": true,
		"prompt": "Owning this seat has people quietly re-checking bloodlines, paperwork, and loyalties. How do I answer that scrutiny?",
		"followup_hooks": ["asset.castle.succession.scrutiny"],
		"bias_payloads": {},
		"choices": [
			{
				"id": "lean_into_lineage",
				"label": "Lean into lineage, ritual, and public legitimacy.",
				"journal_line": "I leaned into ritual and legitimacy so nobody could frame my place as temporary.",
				"followup_hooks": ["asset.castle.succession.ritual_legitimacy"],
				"bias_payloads": {
					"reputation_bias": { "public_attention": 4.0},
					"expiry": { "years": 1}
				}
			},
			{
				"id": "handle_in_private",
				"label": "Handle it quietly through family channels.",
				"journal_line": "I handled the succession pressure quietly through the family itself.",
				"followup_hooks": ["asset.castle.succession.private_settlement"],
				"bias_payloads": {
					"relationship_bias": { "social_visibility": -1.0},
					"expiry": { "years": 1}
				}
			}
		]
	})

	out.append({
		"id": "asset_castle_ceremonial_pressure_%d" % year,
		"source": "dynamic_world_event_engine",
		"category": "social",
		"era_tags": ["any"],
		"reality_modes": ["realistic", "enhanced", "chaos"],
		"reality_weights": {
			"realistic": 1.05,
			"enhanced": 1.0,
			"chaos": 0.95
		},
		"tone": "formal",
		"rarity": 0.72,
		"cooldown_key": "asset.castle.ceremony",
		"cooldown_years": 2,
		"priority": 12,
		"min_age": 16,
		"max_age": 130,
		"asset_namespace_preferences": { "property.castle": 1.75},
		"asset_identity_mode": ["ceremonial_symbol", "dynasty_seat"],
		"asset_tier_floor": 3.0,
		"asset_arc_family": "castle_ceremony",
		"asset_arc_step": "noble_obligation",
		"asset_repeat_group": "asset.castle.ceremony",
		"asset_echoes_world_feed": true,
		"asset_echoes_memory": true,
		"asset_echoes_reputation": true,
		"prompt": "The place itself is pulling ceremonial obligations toward me. Do I host, defer, or weaponize the gathering?",
		"followup_hooks": ["asset.castle.ceremony.obligation"],
		"bias_payloads": {},
		"choices": [
			{
				"id": "host_banquet",
				"label": "Host the gathering and turn obligation into influence.",
				"journal_line": "I hosted the gathering and turned the burden of ceremony into influence.",
				"followup_hooks": ["asset.castle.ceremony.hosted"],
				"bias_payloads": {
					"relationship_bias": { "social_visibility": 6.0},
					"reputation_bias": { "public_attention": 3.0},
					"expiry": { "years": 1}
				}
			},
			{
				"id": "defer_respectfully",
				"label": "Defer it and preserve distance.",
				"journal_line": "I deferred the obligation and kept people from getting too comfortable around my seat.",
				"followup_hooks": ["asset.castle.ceremony.deferred"],
				"bias_payloads": {
					"relationship_bias": { "social_visibility": -1.0},
					"expiry": { "years": 1}
				}
			}
		]
	})

	out.append({
		"id": "asset_shack_repair_crisis_%d" % year,
		"source": "dynamic_world_event_engine",
		"category": "general",
		"era_tags": ["any"],
		"reality_modes": ["realistic", "enhanced", "chaos"],
		"reality_weights": {
			"realistic": 1.1,
			"enhanced": 1.0,
			"chaos": 0.95
		},
		"tone": "grounded",
		"rarity": 0.68,
		"cooldown_key": "asset.shack.repair",
		"cooldown_years": 1,
		"priority": 12,
		"min_age": 12,
		"max_age": 130,
		"asset_namespace_preferences": { "property.shack": 2.0},
		"min_asset_condition_profile": { "neglected": 1.0},
		"asset_weight_pressure_profile": { "community_belonging": 3.0},
		"asset_arc_family": "shack_fragility",
		"asset_arc_step": "repair_crisis",
		"asset_repeat_group": "asset.shack.fragility",
		"asset_echoes_world_feed": true,
		"asset_echoes_memory": true,
		"asset_echoes_reputation": false,
		"prompt": "The place is starting to demand real repair, and everybody can feel it. How do I handle the strain?",
		"followup_hooks": ["asset.shack.fragility.repair_crisis"],
		"bias_payloads": {},
		"choices": [
			{
				"id": "community_help",
				"label": "Pull in community help and patch it together.",
				"journal_line": "I pulled in help and patched things together before the place got worse.",
				"followup_hooks": ["asset.shack.fragility.community_patch"],
				"bias_payloads": {
					"relationship_bias": { "social_visibility": 3.0},
					"expiry": { "years": 1}
				}
			},
			{
				"id": "carry_it_alone",
				"label": "Try to carry it alone and keep pride intact.",
				"journal_line": "I tried to carry the repair burden alone, even though it weighed on everything else.",
				"followup_hooks": ["asset.shack.fragility.private_burden"],
				"bias_payloads": {
					"health_bias": { "stress_delta": 3.0},
					"expiry": { "years": 1}
				}
			}
		]
	})

	out.append({
		"id": "asset_shack_eviction_pressure_%d" % year,
		"source": "dynamic_world_event_engine",
		"category": "general",
		"era_tags": ["any"],
		"reality_modes": ["realistic", "enhanced", "chaos"],
		"reality_weights": {
			"realistic": 1.15,
			"enhanced": 1.0,
			"chaos": 0.9
		},
		"tone": "anxious",
		"rarity": 0.62,
		"cooldown_key": "asset.shack.eviction",
		"cooldown_years": 1,
		"priority": 13,
		"min_age": 14,
		"max_age": 130,
		"asset_namespace_preferences": { "property.shack": 2.0},
		"required_asset_event_hooks": ["eviction_risk"],
		"asset_weight_pressure_profile": { "community_belonging": 2.0},
		"asset_arc_family": "shack_fragility",
		"asset_arc_step": "eviction_threat",
		"asset_repeat_group": "asset.shack.fragility",
		"asset_echoes_world_feed": true,
		"asset_echoes_memory": true,
		"asset_echoes_reputation": false,
		"prompt": "Housing pressure is getting too loud to ignore. Do I scramble for stability, resist publicly, or lean on people?",
		"followup_hooks": ["asset.shack.fragility.eviction_threat"],
		"bias_payloads": {},
		"choices": [
			{
				"id": "scramble_for_stability",
				"label": "Scramble for money and stability.",
				"journal_line": "I scrambled for stability before housing pressure could swallow the year whole.",
				"followup_hooks": ["asset.shack.fragility.scramble"],
				"bias_payloads": {
					"career_bias": { "ambition_weight": 4.0},
					"expiry": { "years": 1}
				}
			},
			{
				"id": "lean_on_people",
				"label": "Lean on family and community.",
				"journal_line": "I leaned on family and community when the housing pressure started closing in.",
				"followup_hooks": ["asset.shack.fragility.community_support"],
				"bias_payloads": {
					"relationship_bias": { "social_visibility": 4.0},
					"expiry": { "years": 1}
				}
			}
		]
	})

	return out


func _asset_native_vehicle_scenarios(context:= {}) -> Array:
	var out: Array = []
	var year: int = int(context.get("year", 0))

	out.append({
		"id": "asset_yacht_weather_exposure_%d" % year,
		"source": "dynamic_world_event_engine",
		"category": "general",
		"era_tags": ["any"],
		"reality_modes": ["realistic", "enhanced", "chaos"],
		"reality_weights": {
			"realistic": 1.05,
			"enhanced": 1.0,
			"chaos": 1.05
		},
		"tone": "volatile",
		"rarity": 0.77,
		"cooldown_key": "asset.yacht.weather",
		"cooldown_years": 2,
		"priority": 12,
		"min_age": 16,
		"max_age": 130,
		"asset_namespace_preferences": { "vehicle.yacht": 2.5, "vehicle.maritime": 1.5},
		"asset_identity_mode": ["weather_exposed", "spectacle_carrier"],
		"asset_arc_family": "yacht_weather",
		"asset_arc_step": "storm_warning",
		"asset_repeat_group": "asset.yacht.weather",
		"asset_echoes_world_feed": true,
		"asset_echoes_memory": true,
		"asset_echoes_reputation": true,
		"prompt": "A trip tied to my vessel suddenly feels a lot riskier than it did on paper. Do I cancel, reroute, or push through?",
		"followup_hooks": ["asset.yacht.weather.warning"],
		"bias_payloads": {},
		"choices": [
			{
				"id": "reroute",
				"label": "Reroute and play it smart.",
				"journal_line": "I rerouted and treated the water like something that deserved respect.",
				"followup_hooks": ["asset.yacht.weather.rerouted"],
				"bias_payloads": {
					"health_bias": { "stress_delta": -1.0},
					"expiry": { "years": 1}
				}
			},
			{
				"id": "push_through",
				"label": "Push through and keep the appearance of control.",
				"journal_line": "I pushed through the risk because the appearance of control mattered too much to me.",
				"followup_hooks": ["asset.yacht.weather.pushed_through"],
				"bias_payloads": {
					"reputation_bias": { "public_attention": 3.0},
					"health_bias": { "stress_delta": 2.0},
					"expiry": { "years": 1}
				}
			}
		]
	})

	out.append({
		"id": "asset_yacht_smuggling_temptation_%d" % year,
		"source": "dynamic_world_event_engine",
		"category": "crime",
		"era_tags": ["any"],
		"reality_modes": ["realistic", "enhanced", "chaos"],
		"reality_weights": {
			"realistic": 1.0,
			"enhanced": 1.05,
			"chaos": 1.1
		},
		"tone": "shady",
		"rarity": 0.84,
		"cooldown_key": "asset.yacht.smuggling",
		"cooldown_years": 2,
		"priority": 14,
		"min_age": 18,
		"max_age": 130,
		"asset_namespace_preferences": { "vehicle.yacht": 2.5, "vehicle.maritime": 1.75},
		"asset_identity_mode": ["smuggling_channel"],
		"min_asset_pressure_profile": { "criminal_usefulness": 1.0},
		"asset_arc_family": "yacht_smuggling",
		"asset_arc_step": "temptation",
		"asset_repeat_group": "asset.yacht.smuggling",
		"asset_echoes_world_feed": true,
		"asset_echoes_memory": true,
		"asset_echoes_reputation": true,
		"prompt": "Someone wants to use my vessel for a movement that definitely should not feel this casual. What do I do?",
		"followup_hooks": ["asset.yacht.smuggling.temptation"],
		"bias_payloads": {},
		"choices": [
			{
				"id": "refuse_cleanly",
				"label": "Refuse cleanly and distance myself.",
				"journal_line": "I refused the offer and made sure my vessel stayed out of that kind of traffic.",
				"followup_hooks": ["asset.yacht.smuggling.refused"],
				"bias_payloads": {
					"reputation_bias": { "public_attention": 1.0},
					"expiry": { "years": 1}
				}
			},
			{
				"id": "entertain_it",
				"label": "Entertain it and see how far the opening goes.",
				"journal_line": "I entertained the opening even though I knew exactly what kind of shadow it cast.",
				"followup_hooks": ["asset.yacht.smuggling.opened_door"],
				"bias_payloads": {
					"crime_pressure": { "rumor_heat": 6.0},
					"reputation_bias": { "public_attention": 3.0},
					"expiry": { "years": 1}
				}
			}
		]
	})

	out.append({
		"id": "asset_yacht_celebrity_intrusion_%d" % year,
		"source": "dynamic_world_event_engine",
		"category": "social",
		"era_tags": ["any"],
		"reality_modes": ["realistic", "enhanced", "chaos"],
		"reality_weights": {
			"realistic": 1.0,
			"enhanced": 1.05,
			"chaos": 1.05
		},
		"tone": "glamorous",
		"rarity": 0.79,
		"cooldown_key": "asset.yacht.celebrity",
		"cooldown_years": 2,
		"priority": 12,
		"min_age": 16,
		"max_age": 130,
		"asset_namespace_preferences": { "vehicle.yacht": 2.25},
		"asset_identity_mode": ["spectacle_carrier"],
		"asset_weight_pressure_profile": { "spectacle": 5.0, "romance_signal": 3.0},
		"asset_arc_family": "yacht_social",
		"asset_arc_step": "celebrity_intrusion",
		"asset_repeat_group": "asset.yacht.social",
		"asset_echoes_world_feed": true,
		"asset_echoes_memory": true,
		"asset_echoes_reputation": true,
		"prompt": "The vessel is starting to pull exactly the kind of attention that never stays simple. Do I host it, monetize it, or shut it down?",
		"followup_hooks": ["asset.yacht.social.intrusion"],
		"bias_payloads": {},
		"choices": [
			{
				"id": "host_it",
				"label": "Host it and let the atmosphere work for me.",
				"journal_line": "I hosted the attention and let the atmosphere around the vessel do its work.",
				"followup_hooks": ["asset.yacht.social.hosted"],
				"bias_payloads": {
					"relationship_bias": { "social_visibility": 7.0},
					"reputation_bias": { "public_attention": 5.0},
					"expiry": { "years": 1}
				}
			},
			{
				"id": "shut_it_down",
				"label": "Shut it down before it mutates into gossip.",
				"journal_line": "I shut the whole thing down before the attention could mutate into gossip and obligation.",
				"followup_hooks": ["asset.yacht.social.shut_down"],
				"bias_payloads": {
					"relationship_bias": { "social_visibility": -2.0},
					"expiry": { "years": 1}
				}
			}
		]
	})

	return out