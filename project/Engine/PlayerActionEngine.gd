extends Resource
class_name PlayerActionEngine

var gs

func _init(_gs):
	gs = _gs





func perform(
	action: String,
	payload: Dictionary = {}
) -> Dictionary:
	var clean_action: String = str(
		action
	).strip_edges().to_lower()
	var safe_payload: Dictionary = payload.duplicate(false)
	var target_raw: Variant = safe_payload.get(
		"target",
		null
	)
	var target: Person = (
		target_raw as Person
		if target_raw is Person
		else null
	)
	var target_required_actions: Array = [
		"compliment",
		"talk",
		"gift",
		"insult",
		"betray",
		"heroic_rescue",
		"give_money",
		"hookup",
		"make_love",
		"counseling",
		"ask_out",
		"crime_on_person",
		"bending_attack",
		"teach_bending",
		"coup",
		"callout_boxer",
		"turn_target",
		"feed",
		"glamour",
		"blood_bond",
		"hunt_vampire"
	]

	if (
		clean_action in target_required_actions
		and target == null
	):
		return {
			"success": false,
			"reason": "selected_target_required",
			"type": "action_rejected",
			"text": "I need to select someone first.",
			"popup_title": "Select Someone",
			"popup_text": (
				"This action requires a prepared person target."
			),
			"popup_footer": (
				"Choose someone from a relationship or population lens."
			),
			"action_id": clean_action
		}

	match clean_action:
		"compliment":
			return (
				gs.relationship_activities_engine
				.compliment(target)
			)

		"talk":
			return (
				gs.relationship_activities_engine
				.converse(target)
			)

		"gift":
			return (
				gs.relationship_activities_engine
				.gift(
					target,
					safe_payload.get(
						"item",
						null
					)
				)
			)

		"insult":
			return (
				gs.relationship_activities_engine
				.insult(target)
			)

		"betray":
			return (
				gs.relationship_activities_engine
				.betray(target)
			)

		"heroic_rescue":
			return (
				gs.relationship_activities_engine
				.heroic_rescue(target)
			)

		"give_money":
			return (
				gs.relationship_activities_engine
				.give_money(
					target,
					int(
						safe_payload.get(
							"amount",
							0
						)
					)
				)
			)

		"hookup":
			return (
				gs.relationship_activities_engine
				.hookup(target)
			)

		"make_love":
			return (
				gs.relationship_activities_engine
				.make_love(target)
			)

		"counseling":
			return (
				gs.relationship_activities_engine
				.counseling(target)
			)

		"ask_out":
			return (
				gs.relationship_activities_engine
				.ask_out(target)
			)

		"crime":
			return gs.crime_engine.commit_crime(
				safe_payload.get(
					"crime",
					""
				),
				safe_payload.get(
					"weapon",
					null
				)
			)

		"crime_on_person":
			return (
				gs.relationship_activities_engine
				.crime_on_person(
					target,
					safe_payload.get(
						"crime",
						""
					)
				)
			)

		"bending_attack":
			if not gs.is_feature_enabled(
				"bending"
			):
				return {
					"success": false,
					"text": (
						"\n❌\n Bending is disabled "
						+ "in this reality mode."
					),
					"popup_title": "Bending",
					"popup_text": (
						"Bending is disabled in this reality mode."
					),
					"popup_footer": "Tap anywhere to continue."
				}

			return gs.crime_engine.commit_bending_crime(
				target,
				safe_payload.get(
					"move",
					""
				)
			)

		"train_bending":
			if not gs.is_feature_enabled(
				"bending"
			):
				return {
					"success": false,
					"text": (
						"\n❌\n Bending is disabled "
						+ "in this reality mode."
					),
					"popup_title": "Bending",
					"popup_text": (
						"Bending is disabled in this reality mode."
					),
					"popup_footer": "Tap anywhere to continue."
				}

			if gs.player.bending_type == "none":
				return {
					"success": false,
					"text": "I cannot bend.",
					"popup_title": "Bending",
					"popup_text": "You cannot bend.",
					"popup_footer": "Tap anywhere to continue."
				}

			var trained_element: String = str(
				gs.player.bending_type
			)

			gs.bending_engine.train_element(
				gs.player,
				trained_element
			)

			if trained_element == "avatar":
				return {
					"success": true,
					"text": "I trained my avatar bending.",
					"popup_title": "Progress",
					"popup_text": (
						"You trained your Avatar bending."
					),
					"popup_footer": "Tap anywhere to continue."
				}

			return {
				"success": true,
				"text": (
					"I trained my %s bending."
					% trained_element
				),
				"popup_title": "Progress",
				"popup_text": (
					"You trained your %s bending."
					% trained_element
				),
				"popup_footer": "Tap anywhere to continue."
			}

		"teach_bending":
			if not gs.is_feature_enabled(
				"bending"
			):
				return {
					"success": false,
					"text": (
						"\n❌\n Bending is disabled "
						+ "in this reality mode."
					),
					"popup_title": "Bending",
					"popup_text": (
						"Bending is disabled in this reality mode."
					),
					"popup_footer": "Tap anywhere to continue."
				}

			return (
				gs.relationship_activities_engine
					.help_bending(
						target,
						str(
							safe_payload.get(
								"element",
								""
							)
						)
					)
			)

		"buy_property":
			return gs.property_engine.buy_property(
				gs.player,
				safe_payload.get(
					"size",
					""
				),
				int(
					safe_payload.get(
						"price",
						0
					)
				)
			)

		"buy_vehicle":
			return gs.vehicle_engine.buy_vehicle(
				gs.player,
				safe_payload.get(
					"type",
					""
				),
				int(
					safe_payload.get(
						"price",
						0
					)
				)
			)

		"buy_weapon":
			return {
				"text": gs.weapons_engine.buy_weapon(
					safe_payload.get(
						"weapon",
						""
					)
				)
			}

		"buy_heirloom":
			if gs.heirloom_contract_engine == null:
				return {
					"success": false,
					"reason": (
						"heirloom_contract_engine_unavailable"
					),
					"text": (
						"Heirloom purchasing is unavailable."
					)
				}

			var heirloom_payload: Dictionary = (
				safe_payload.duplicate(false)
			)
			heirloom_payload [
				"action_id"
			] = "purchase_random"
			heirloom_payload ["source"] = str(
				heirloom_payload.get(
					"source",
					"player_action_engine.buy_heirloom"
				)
			)

			return (
				gs.heirloom_contract_engine
					.resolve_intent(
						gs.player,
						heirloom_payload
					)
			)

		"declare_war":
			return gs.realm_engine.declare_war(
				gs.player,
				safe_payload.get(
					"realm",
					null
				)
			)

		"coup":
			return gs.politics_engine.attempt_coup(
				gs.player,
				target
			)

		"wish":
			return {
				"text": gs.dragonballs_engine.make_wish(
					str(
						safe_payload.get(
							"wish",
							""
						)
					)
				)
			}

		"start_boxing":
			return (
				gs.boxing_engine
					.start_boxing_career(
						gs.player
					)
			)

		"train_boxing":
			return (
				gs.boxing_training_engine
					.train_fighter(
						gs.player
					)
			)

		"book_boxing_match":
			return (
				gs.boxing_matchmaking_engine
					.book_player_fight(
						gs.player
					)
			)

		"view_boxing_record":
			return {
				"text": gs.boxing_engine.describe_record(
					gs.player
				)
			}

		"callout_boxer":
			return (
				gs.boxing_rivalry_engine
					.manual_callout(
						gs.player,
						target
					)
			)

		"change_weight_class":
			return (
				gs.boxing_weight_engine
					.player_change_division(
						gs.player,
						safe_payload.get(
							"division",
							""
						)
					)
			)

		"view_last_fight_log":
			return {
				"text": (
					gs.boxing_engine
						.describe_last_fight_log(
							gs.player
						)
				)
			}

		"enter_amateur_tournament":
			return (
				gs.boxing_amateur_engine
					.enter_player_tournament(
						gs.player
					)
			)

		"forge_gauntlet":
			return {
				"text": str(
					gs.artifacts_engine.forge_gauntlet()
				)
			}

		"build_era_kingdom":
			return (
				gs.many_realms_engine
					.build_in_era_kingdom(
						str(
							safe_payload.get(
								"project_name",
								""
							)
						),
						int(
							safe_payload.get(
								"prosperity_gain",
								5
							)
						),
						int(
							safe_payload.get(
								"loyalty_gain",
								2
							)
						)
					)
			)

		"ask_to_be_turned":
			if (
				gs.vampire_origin_engine == null
				or not gs.vampire_origin_engine.has_method(
					"resolve_intent"
				)
			):
				return {
					"success": false,
					"reason": "vampire_origin_engine_unavailable",
					"popup_title": "Vampire Request",
					"popup_text": (
						"Vampire-origin truth is unavailable."
					),
					"popup_footer": "The request could not be routed."
				}

			var vampire_payload: Dictionary = (
				safe_payload.duplicate(false)
			)
			vampire_payload [
				"action_id"
			] = "ask_to_be_turned"
			vampire_payload ["source"] = str(
				vampire_payload.get(
					"source",
					"player_action_engine.ask_to_be_turned"
				)
			)

			if target != null:
				vampire_payload [
					"target_id"
				] = int(target.id)

			return (
				gs.vampire_origin_engine
					.resolve_intent(
						gs.player,
						vampire_payload
					)
			)

		"turn_target":
			return gs.vampire_origin_engine.turn_target(
				gs.player,
				target
			)

		"feed":
			return gs.vampire_hunger_engine.feed(
				gs.player,
				target,
				str(
					safe_payload.get(
						"feed_type",
						"hunt"
					)
				)
			)

		"blood_bag":
			return (
				gs.vampire_hunger_engine
					.use_blood_bag(
						gs.player
					)
			)

		"join_coven":
			return gs.vampire_society_engine.join_coven(
				gs.player,
				str(
					safe_payload.get(
						"coven_id",
						""
					)
				)
			)

		"found_coven":
			return gs.vampire_society_engine.found_coven(
				gs.player,
				str(
					safe_payload.get(
						"name",
						"Unnamed Coven"
					)
				)
			)

		"glamour":
			return gs.vampire_ability_engine.glamour_target(
				gs.player,
				target
			)

		"blood_bond":
			return gs.vampire_ability_engine.blood_bond_target(
				gs.player,
				target
			)

		"seek_cure":
			return (
				gs.vampire_cure_engine
					.seek_cure(
						gs.player
					)
			)

		"hunt_vampire":
			return gs.vampire_hunter_engine.hunt_target(
				gs.player,
				target
			)

		"migrate_somewhere":
			return (
				gs.migration_engine
					.open_player_migration_panel(
						gs.player
					)
			)

		"submit_migration":
			return (
				gs.migration_engine
					.submit_player_migration(
						str(
							safe_payload.get(
								"settlement_id",
								""
							)
						),
						bool(
							safe_payload.get(
								"move_household",
								true
							)
						)
					)
			)

	return {
		"success": false,
		"reason": "unknown_action",
		"type": "action_rejected",
		"text": "Unknown action: %s" % clean_action,
		"popup_title": "Action Unavailable",
		"popup_text": (
			"No action contract is registered for %s."
			% clean_action
		),
		"popup_footer": "Nothing was changed."
	}
func get_actions():
	return gs.action_discovery_engine.generate_actions(gs.player)
func execute(action):
	var engine = gs.get(action.engine)
	var method = action.method

	if engine.has_method(method):

		if action.has("args"):
			return engine.callv(method, action.args)
		else:
			return engine.call(method)