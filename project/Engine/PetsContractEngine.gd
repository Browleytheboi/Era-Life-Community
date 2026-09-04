extends Resource
class_name PetsContractEngine

const ENGINE_SCHEMA:= "eralife.relationship_producer.pets_contract_engine"
const CONTRACT_VERSION:= 1

var gs: GameState = null

func _init(_gs: GameState = null) -> void:
	bind_game_state(_gs)

func bind_game_state(_gs: GameState) -> void:
	gs = _gs

func ensure_birth_family_pet_for_actor(actor: Person, context: Dictionary = {}) -> Dictionary:
	if gs == null or actor == null:
		return { "success": false, "reason": "missing_actor_or_game_state"}

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var anchor: Person = actor
	if not bool(context.get("actor_is_resolved_household_anchor", false)):
		anchor = _household_pet_anchor_for_actor(actor)
		if anchor == null:
			anchor = actor

		if int(anchor.id) != int(actor.id):
			var anchor_context: Dictionary = context.duplicate(true)
			anchor_context ["source_actor_id"] = int(actor.id)
			anchor_context ["household_seed_origin_age"] = int(actor.age)
			anchor_context ["actor_is_resolved_household_anchor"] = true
			return ensure_birth_family_pet_for_actor(anchor, anchor_context)

	var origin_age: int = _safe_int_value(context.get("household_seed_origin_age", int(anchor.age)), int(anchor.age))
	if origin_age > int(context.get("max_birth_age", 1)) and not bool(context.get("force", false)):
		return { "success": false, "reason": "actor_not_birth_age"}

	var seeded_key: String = _birth_family_pet_seeded_key(anchor)
	var entity_key: String = _birth_family_pet_entity_key(anchor)
	var legacy_seeded_key: String = "birth_family_pet_seeded_for_actor_%d" % int(anchor.id)
	var legacy_entity_key: String = "birth_family_pet_entity_for_actor_%d" % int(anchor.id)

	var existing_card: Dictionary = _existing_family_pet_card_for_anchor(anchor)
	if not existing_card.is_empty():
		var existing_entity_id: String = str(existing_card.get("target_entity_id", "")).strip_edges()
		gs.scenario_state [seeded_key] = true
		gs.scenario_state [entity_key] = existing_entity_id
		gs.scenario_state [legacy_seeded_key] = true
		gs.scenario_state [legacy_entity_key] = existing_entity_id
		return {
			"success": true,
			"reason": "already_seeded_existing_family_pet",
			"entity_id": existing_entity_id,
			"household_pet_anchor_id": int(anchor.id),
			"card": existing_card.duplicate(true)
		}

	if bool(gs.scenario_state.get(seeded_key, false)):
		return {
			"success": true,
			"reason": "already_seeded",
			"entity_id": str(gs.scenario_state.get(entity_key, "")),
			"household_pet_anchor_id": int(anchor.id)
		}

	if bool(gs.scenario_state.get(legacy_seeded_key, false)):
		var legacy_entity_id: String = str(gs.scenario_state.get(legacy_entity_key, "")).strip_edges()
		if legacy_entity_id != "" and not _entity(legacy_entity_id).is_empty():
			gs.scenario_state [seeded_key] = true
			gs.scenario_state [entity_key] = legacy_entity_id
			return {
				"success": true,
				"reason": "already_seeded_legacy_actor_key_promoted_to_household_anchor",
				"entity_id": legacy_entity_id,
				"household_pet_anchor_id": int(anchor.id)
			}

	if not bool(context.get("force", false)) and not _birth_family_pet_roll_passes(anchor):
		gs.scenario_state [seeded_key] = true
		gs.scenario_state [legacy_seeded_key] = true
		return { "success": false, "reason": "birth_family_pet_roll_failed"}

	if gs.animal_contract_engine == null:
		return { "success": false, "reason": "missing_animal_contract_engine"}

	var entity_seed: String = "birth_family_pet:%d:%d:%d" % [
		int(anchor.id),
		int(gs.year if gs != null else 0),
		_world_seed_value()
	]

	var species_id: String = gs.animal_contract_engine.default_birth_family_species({
		"source": ENGINE_SCHEMA,
		"seed_key": entity_seed,
		"household_pet_anchor_id": int(anchor.id),
		"anchor_id": int(anchor.id),
		"world_seed": _world_seed_value()
	})

	var used_names: Array = _household_pet_names_for_anchor(anchor)
	var requested_name: String = str(context.get("name", "")).strip_edges()
	var pet_name: String = requested_name
	if pet_name == "" or _name_already_used_in_list(pet_name, used_names):
		pet_name = _unique_birth_family_pet_name(species_id, entity_seed, used_names)

	var pet_age: int = _birth_family_pet_age_for_species(species_id, entity_seed, context)

	var entity: Dictionary = gs.animal_contract_engine.create_animal_entity(species_id, int(anchor.id), {
		"source": ENGINE_SCHEMA,
		"name": pet_name,
		"age": pet_age,
		"age_years": pet_age,
		"household_pet_anchor_id": int(anchor.id),
		"hunger": 18,
		"trust": 55,
		"family_pet_seed": entity_seed
	})

	if entity.is_empty():
		return { "success": false, "reason": "entity_creation_failed"}

	var report: Dictionary = _commit_pet_edge(anchor, entity, "family_pet", ["pet", "animal", "family_pet", "birth_family_pet", "household_pet"], "Family", "Family Pet", 58, context)

	gs.scenario_state [seeded_key] = true
	gs.scenario_state [entity_key] = str(entity.get("entity_id", ""))
	gs.scenario_state [legacy_seeded_key] = true
	gs.scenario_state [legacy_entity_key] = str(entity.get("entity_id", ""))

	report ["household_pet_anchor_id"] = int(anchor.id)
	report ["entity_id"] = str(entity.get("entity_id", ""))
	report ["entity"] = entity.duplicate(true)
	report ["reason"] = "family_pet_seeded_for_household_anchor"
	return report

func get_pet_cards_for_actor(
	actor: Person,
	_context: Dictionary = {}
) -> Array:
	if (
		gs == null
		or actor == null
		or gs.relationship_graph_contract_engine == null
	):
		return []

	var anchor: Person = _household_pet_anchor_for_actor(
		actor
	)

	if anchor == null:
		anchor = actor

	var projection_read_only: bool = bool(
		_context.get(
			"projection_read_only",
			false
		)
	)
	var seed_if_missing: bool = bool(
		_context.get(
			"seed_if_missing",
			not projection_read_only
		)
	)
	# Resolve every owned animal's age and alive state BEFORE any card is built.
	#
	# The card's displayed age is baked from the ENTITY at build time --
	# _pet_name_with_age() and card_contract_for_edge()'s _entity_name_with_age()
	# both read entity["age"] -- so resolving afterwards updated the registry but
	# handed back cards already stamped with the stale age. That is why pets still
	# showed a frozen age with the derivation in place.
	_refresh_owned_animal_lifecycles(
		actor,
		anchor
	)

	var cards: Array = []
	var seen_entity_ids: Dictionary = {}
	var anchor_cards: Array = []

	if projection_read_only:



		anchor_cards = (
			gs.relationship_graph_contract_engine.cards_for_entity(
				"human:%d" % int(
					anchor.id
				),
				{
					"tag_any": [
						"pet",
						"family_pet",
						"mythical_pet"
					]
				}
			)
		)

		for card_index in range(
			anchor_cards.size()
		):
			var anchor_card: Dictionary = _safe_dictionary(
				anchor_cards [
					card_index
				]
			)
			anchor_card [
				"household_pet_anchor_id"
			] = int(
				anchor.id
			)
			anchor_card [
				"household_access_actor_id"
			] = int(
				actor.id
			)
			anchor_card [
				"access_by_household_association"
			] = int(
				anchor.id
			) != int(
				actor.id
			)
			anchor_card [
				"role"
			] = (
				"Household Pet"
				if int(
					anchor.id
				) != int(
					actor.id
				)
				else str(
					anchor_card.get(
						"role",
						"Pet"
					)
				)
			)
			anchor_cards [
				card_index
			] = anchor_card
	else:
		anchor_cards = _pet_cards_for_household_anchor(
			actor,
			anchor,
			seed_if_missing
		)

	_append_unique_pet_cards(
		cards,
		seen_entity_ids,
		anchor_cards
	)

	if int(
		anchor.id
	) != int(
		actor.id
	):
		var legacy_actor_cards: Array = []

		if projection_read_only:
			legacy_actor_cards = (
				gs.relationship_graph_contract_engine.cards_for_entity(
					"human:%d" % int(
						actor.id
					),
					{
						"tag_any": [
							"pet",
							"family_pet",
							"mythical_pet"
						]
					}
				)
			)

			for card_index in range(
				legacy_actor_cards.size()
			):
				var legacy_card: Dictionary = _safe_dictionary(
					legacy_actor_cards [
						card_index
					]
				)
				legacy_card [
					"household_pet_anchor_id"
				] = int(
					actor.id
				)
				legacy_card [
					"household_access_actor_id"
				] = int(
					actor.id
				)
				legacy_card [
					"access_by_household_association"
				] = false
				legacy_card [
					"role"
				] = str(
					legacy_card.get(
						"role",
						"Pet"
					)
				)
				legacy_actor_cards [
					card_index
				] = legacy_card
		else:
			legacy_actor_cards = _pet_cards_for_household_anchor(
				actor,
				actor,
				false
			)

		_append_unique_pet_cards(
			cards,
			seen_entity_ids,
			legacy_actor_cards
		)

	cards = _repair_duplicate_pet_names_for_cards(
		cards
	)

	# DIAGNOSTIC: the acquisition tail confirms both relationship edges commit
	# (owner_edge=true, household_edge=true), so if the tab still shows nothing the
	# break is on the READ side. Report what this query actually resolved.
	# FIX: this query runs on whichever runtime the relationships hub was built with,
	# and after a load that can be a runtime whose graph is empty (graph_edges_total=0)
	# while the player's runtime holds the edges. Rather than depend on which of the
	# three runtimes this engine happens to hold, fall back to the residency manager's
	# attached runtime when this one has no edges.
	if gs != null and typeof(gs.canonical_relationship_graph) == TYPE_DICTIONARY:
		var local_edges: int = _safe_dictionary(
			gs.canonical_relationship_graph.get("edges", {})
		).size()

		if local_edges == 0 and gs.reality_residency_manager != null:
			for raw_signature in gs.reality_residency_manager.resident_records.keys():
				var record_row: Dictionary = _safe_dictionary(
					gs.reality_residency_manager.resident_records.get(raw_signature, {})
				)
				var other_runtime = record_row.get("runtime_ref", null)

				if not (other_runtime is GameState) or other_runtime == gs:
					continue

				if typeof(other_runtime.canonical_relationship_graph) != TYPE_DICTIONARY:
					continue

				if _safe_dictionary(other_runtime.canonical_relationship_graph.get("edges", {})).size() > 0:
					gs.canonical_relationship_graph = (
						other_runtime.canonical_relationship_graph.duplicate(true)
					)

					if typeof(other_runtime.entity_registry) == TYPE_DICTIONARY:
						gs.entity_registry = other_runtime.entity_registry.duplicate(true)

					EraLog.truth(
						"ERALIFE_PET_GRAPH_BORROWED|from_gs=%d|to_gs=%d"
						% [
							int(other_runtime.get_instance_id()),
							int(gs.get_instance_id())
						]
					)
					break

	# DIAGNOSTIC: anchor_cards=0 while the acquisition tail reported household_edge=true.
	# Report UNFILTERED edge counts too, so we can tell whether the edges are missing
	# from the graph entirely (rebuild wiped them) or present but not matching the
	# pet tag filter.
	var unfiltered_actor: int = 0
	var unfiltered_anchor: int = 0

	if gs != null and gs.relationship_graph_contract_engine != null:
		unfiltered_actor = gs.relationship_graph_contract_engine.relationships_for_entity(
			"human:%d" % int(actor.id), {}
		).size()
		unfiltered_anchor = gs.relationship_graph_contract_engine.relationships_for_entity(
			"human:%d" % int(anchor.id), {}
		).size()

	# Resolve age and alive from birth_year before the cards are reported. This is
	# the choke point every pet card passes through, so it is where derivation and
	# the once-only death latch belong -- no yearly tick to starve.
	# Lifecycle RESOLUTION happens in _refresh_owned_animal_lifecycles() before any
	# card is built -- a card's displayed age is baked from the entity at
	# construction time, so resolving afterwards would stamp nothing. What remains
	# here is presentation only: a dead pet's card cannot be decorated until the
	# card exists. No age or alive state is computed below.
	for raw_pet_card in cards:
		if typeof(raw_pet_card) != TYPE_DICTIONARY:
			continue

		var pet_entity_id: String = str(
			raw_pet_card.get("target_entity_id", "")
		).strip_edges()

		if pet_entity_id == "" or not pet_entity_id.begins_with("animal:"):
			continue

		var pet_entity: Dictionary = _entity(pet_entity_id)

		if pet_entity.is_empty() or bool(pet_entity.get("alive", true)):
			continue

		# Dead pets stay in the pets section rather than moving to "dead": that
		# section is built from person ids via _filter_person_ids_by_alive() and
		# has no entity lane, so adding one would mean new group builders in two
		# paths plus a group-count change that shifts the section revision.
		raw_pet_card["health"] = 0
		raw_pet_card["alive"] = false
		raw_pet_card["is_dead"] = true
		raw_pet_card["role"] = "In Memory"
		raw_pet_card["death_year"] = int(
			pet_entity.get("death_year", -1)
		)
		raw_pet_card["subtitle"] = (
			"Died at %d, in %d."
			% [
				int(
					pet_entity.get("death_age", 0)
				),
				int(
					pet_entity.get("death_year", 0)
				)
			]
		)

	EraLog.truth(
		"ERALIFE_PET_CARDS_READ|gs=%d|tag=%s|graph_edges_total=%d|actor_id=%d|anchor_id=%d|read_only=%s|anchor_cards=%d|final_cards=%d|edges_actor=%d|edges_anchor=%d|source=%s"
		% [
			int(gs.get_instance_id()),
			str(gs.runtime_origin_tag),
			_safe_dictionary(gs.canonical_relationship_graph.get("edges", {})).size(),
			int(actor.id),
			int(anchor.id),
			str(projection_read_only),
			anchor_cards.size(),
			cards.size(),
			unfiltered_actor,
			unfiltered_anchor,
			str(_context.get("source", ""))
		]
	)

	return cards
func get_pet_profile_contract(actor: Person, entity_id: String, context: Dictionary = {}) -> Dictionary:
	if gs == null:
		return {}

	var entity: Dictionary = _entity(entity_id)
	if entity.is_empty():
		return {}

	var cards: Array = get_pet_cards_for_actor(actor, context)
	var card: Dictionary = {}
	for raw_card in cards:
		var candidate: Dictionary = _safe_dictionary(raw_card)
		if str(candidate.get("target_entity_id", "")) == entity_id:
			card = candidate
			break

	var actions: Array = pet_action_contracts(actor, entity_id, context)

	return {
		"schema": "eralife.pet.profile_contract",
		"version": CONTRACT_VERSION,
		"entity_id": entity_id,
		"entity": entity.duplicate(true),
		"card": card.duplicate(true),

		"profile_identity": _profile_identity_contract(entity, card),
		"bond_contract": _bond_contract(entity, card),
		"trait_chips": _trait_chip_contracts(entity, card),

		"profile_lines": _profile_lines(entity, card),
		"stat_rows": _stat_rows(entity, card),

		"action_groups": _action_groups(actions),
		"actions": actions.duplicate(true),

		"render_policy": {
			"ui_is_pure_renderer": true,
			"graph_is_authority": true,
		}
	}
func pet_action_contracts(_actor: Person, entity_id: String, _context: Dictionary = {}) -> Array:
	var entity: Dictionary = _entity(entity_id)
	if entity.is_empty():
		return []

	var feed_contract: Dictionary = _feed_contract_for_entity(entity, _actor, _context)

	var actions: Array = [
		{
			"id": "pet:feed",
			"label": str(feed_contract.get("button_label", "Feed")),
			"group": "CARE",
			"bond_delta": 2,
			"trust_delta": 2,
			"health_delta": 1,
			"hunger_delta": -24,
			"food_contract": feed_contract.duplicate(true),
			"summary": "Offer species-appropriate food."
		},
		{
			"id": "pet:groom",
			"label": "Groom",
			"group": "CARE",
			"bond_delta": 2,
			"trust_delta": 2,
			"health_delta": 2,
			"summary": "Clean and calm your companion."
		},
		{
			"id": "pet:pet",
			"label": "Pet",
			"group": "BOND",
			"bond_delta": 2,
			"trust_delta": 3,
			"summary": "Offer direct affection."
		},
		{
			"id": "pet:play",
			"label": "Play",
			"group": "BOND",
			"bond_delta": 3,
			"trust_delta": 4,
			"summary": "Build comfort through activity."
		}
	]

	if bool(entity.get("trainable", false)):
		actions.append({
			"id": "pet:train",
			"label": "Train",
			"group": "GROWTH",
			"bond_delta": 4,
			"trust_delta": 1,
			"training_delta": 8,
			"smarts_delta": 1,
			"summary": "Improve discipline and response."
		})

	if str(entity.get("social_type", "")).find("pack") != -1 or str(entity.get("species_id", "")) == "dog":
		actions.append({
			"id": "pet:walk",
			"label": "Walk",
			"group": "BOND",
			"bond_delta": 3,
			"trust_delta": 3,
			"summary": "Reinforce connection through shared movement."
		})

	if int(entity.get("danger_level", 0)) >= 4:
		actions.append({
			"id": "pet:observe",
			"label": "Observe Carefully",
			"group": "SAFETY",
			"bond_delta": 1,
			"summary": "Respect their danger and body language."
		})

	var reproduction_contract: Dictionary = _safe_dictionary(entity.get("reproduction_contract", _safe_dictionary(entity.get("species_contract", {})).get("reproduction", {})))
	var reproduction_type: String = str(reproduction_contract.get("type", "")).strip_edges().to_lower()
	var species_id: String = str(entity.get("species_id", "")).strip_edges().to_lower()
	var gender: String = str(entity.get("gender", "")).strip_edges().to_lower()

	if reproduction_type == "egg_layer" and gender == "female":
		actions.append({
			"id": "pet:scare_for_eggs",
			"label": "Scare For Eggs",
			"group": "REPRODUCTION",
			"bond_delta": -7,
			"trust_delta": -14,
			"stress_delta": 22,
			"summary": "Force eggs out through stress. It can work, but it damages trust and can kill fragile animals."
		})
		actions.append({
			"id": "pet:sing_for_eggs",
			"label": "Sing For Eggs",
			"group": "REPRODUCTION",
			"bond_delta": 3,
			"trust_delta": 5,
			"stress_delta": -8,
			"summary": "Calm the animal and improve the yearly egg/hatching outcome."
		})
	elif species_id != "":
		actions.append({
			"id": "pet:breed",
			"label": "Breed",
			"group": "REPRODUCTION",
			"summary": "Open a contract-rendered list of compatible owned animals."
		})

	return actions
func _available_pet_food_options_for_actor(actor: Person, _animal_entity: Dictionary, diet_profile: Dictionary) -> Array:
	var out: Array = []
	if gs == null or actor == null or gs.belongings_engine == null:
		return out

	var valid_tags: Array = _safe_array(diet_profile.get("valid_food_tags", []))
	var rows: Array = gs.belongings_engine.get_inventory_rows_for_actor(actor, { "source": ENGINE_SCHEMA}) if gs.belongings_engine.has_method("get_inventory_rows_for_actor") else []

	for raw_row in rows:
		var row: Dictionary = _safe_dictionary(raw_row)
		if row.is_empty() or str(row.get("kind", "")) != "inventory_item":
			continue

		var item: Dictionary = _safe_dictionary(row.get("item", {}))
		var tags: Array = _safe_array(item.get("tags", item.get("food_tags", [])))
		var matched: bool = false

		for raw_tag in tags:
			if str(raw_tag) in valid_tags:
				matched = true
				break

		if not matched:
			continue

		out.append({
			"item_id": str(item.get("id", row.get("item_id", ""))),
			"display_name": str(item.get("display_name", item.get("name", "food"))),
			"quantity": max(1, int(item.get("quantity", 1))),
			"tags": tags.duplicate(true),
			"bloodthirst_delta": int(item.get("bloodthirst_delta", 0)),
			"source_item": item.duplicate(true)
		})

	return out
func _rotating_pet_food_choice(entity: Dictionary, preferred_foods: Array, available_foods: Array) -> Dictionary:
	if available_foods.is_empty():
		var fallback_name: String = str(preferred_foods [0]) if not preferred_foods.is_empty() else "food"
		return { "display_name": fallback_name, "quantity": 0, "item_id": "", "missing": true}

	var last_food_id: String = str(entity.get("last_fed_food_id", ""))
	if available_foods.size() == 1:
		return _safe_dictionary(available_foods [0]).duplicate(true)

	for raw_food in available_foods:
		var food: Dictionary = _safe_dictionary(raw_food)
		if str(food.get("item_id", "")) != last_food_id:
			return food.duplicate(true)

	return _safe_dictionary(available_foods [0]).duplicate(true)
func commit_pet_profile_action(actor: Person, entity_id: String, action_id: String, context: Dictionary = {}) -> Dictionary:
	if gs == null or actor == null or gs.relationship_graph_contract_engine == null:
		return {
			"success": false,
			"text": "The pet action could not be resolved.",
			"reason": "missing_graph_or_actor"
		}

	var entity: Dictionary = _entity(entity_id)
	if entity.is_empty():
		return {
			"success": false,
			"text": "That pet is no longer available.",
			"reason": "missing_entity"
		}
	if action_id == "pet:breed":
		if gs.breeding_contract_engine == null:
			return {
				"success": false,
				"text": "Breeding is not available right now.",
				"reason": "missing_breeding_contract_engine"
			}
		return gs.breeding_contract_engine.breeding_partner_selector_contract(actor, entity_id, context)

	if action_id in ["pet:scare_for_eggs", "pet:sing_for_eggs"]:
		if gs.breeding_contract_engine == null:
			return {
				"success": false,
				"text": "Egg actions are not available right now.",
				"reason": "missing_breeding_contract_engine"
			}
		return gs.breeding_contract_engine.commit_egg_action(actor, entity_id, action_id, context)
	var actions: Array = pet_action_contracts(actor, entity_id, context)
	var action: Dictionary = {}
	for raw_action in actions:
		var candidate: Dictionary = _safe_dictionary(raw_action)
		if str(candidate.get("id", "")) == action_id:
			action = candidate
			break

	if action.is_empty():
		return {
			"success": false,
			"text": "That pet action is not available right now.",
			"reason": "action_unavailable"
		}

	var feed_attempt: Dictionary = {}
	if action_id == "pet:feed":
		feed_attempt = _resolve_feed_attempt(actor, entity, action, context)

	var state_delta: Dictionary = _apply_pet_action_state_delta(entity_id, action_id, action, feed_attempt)
	var updated_entity: Dictionary = _safe_dictionary(state_delta.get("entity", entity))

	var accepted_action: bool = bool(feed_attempt.get("accepted", true))
	var attack_happened: bool = bool(feed_attempt.get("attack_happened", false))
	var committed_bond_delta: int = int(action.get("bond_delta", 0))
	if action_id == "pet:feed" and not accepted_action:
		committed_bond_delta = int(feed_attempt.get("bond_delta", 0))

	var actor_entity: Dictionary = gs.relationship_graph_contract_engine.ensure_person_entity(actor, { "source": ENGINE_SCHEMA})
	var event_type: String = "pet_profile_action"
	var relationship_type: String = "pet_action"
	var relationship_tags: Array = ["pet", "pet_action"]

	if action_id == "pet:feed":
		event_type = "pet_feed_accepted" if accepted_action else "pet_feed_refused"
		relationship_type = "pet_feed"
		relationship_tags = ["pet", "pet_action", "pet_feed"]
		if attack_happened:
			event_type = "pet_feed_attack"
			relationship_tags.append("pet_attack")

	var report: Dictionary = gs.relationship_graph_contract_engine.commit_relationship_event({
		"producer": ENGINE_SCHEMA,
		"event_type": event_type,
		"relationship_type": relationship_type,
		"relationship_tags": relationship_tags.duplicate(true),
		"subject_entity_id": str(actor_entity.get("entity_id", "")),
		"object_entity_id": entity_id,
		"subject_role": "Caretaker",
		"object_role": "Pet",
		"bond_delta": committed_bond_delta,
		"action_id": action_id,
		"accepted": accepted_action,
		"attack_happened": attack_happened,
		"feed_attempt": feed_attempt.duplicate(true),
		"context": context.duplicate(true)
	}, { "producer": ENGINE_SCHEMA})

	var text: String = _action_result_text(
		updated_entity,
		action,
		state_delta,
		committed_bond_delta
	)

	report ["success"] = bool(report.get("success", false))
	report ["committed"] = bool(report.get("success", false))
	report ["accepted"] = accepted_action
	report ["attack_happened"] = attack_happened
	report ["text"] = text
	report ["diary_text"] = text
	report ["popup_title"] = str(action.get("label", "Pet Action"))
	report ["popup_text"] = text
	report ["popup_footer"] = "Tap anywhere to continue."
	report ["feedback_lines"] = _action_feedback_lines(
		updated_entity,
		action,
		state_delta,
		committed_bond_delta
	)
	report ["state_delta"] = state_delta.duplicate(true)
	report ["bond_delta"] = committed_bond_delta
	report ["affected_stats"] = _safe_array(state_delta.get("affected_stats", []))
	report ["food_contract"] = _safe_dictionary(action.get("food_contract", {})).duplicate(true)
	report ["feed_attempt"] = feed_attempt.duplicate(true)
	return report
func _commit_pet_edge(actor: Person, entity: Dictionary, relationship_type: String, tags: Array, subject_role: String, object_role: String, bond: int, context: Dictionary) -> Dictionary:
	if gs == null or gs.relationship_graph_contract_engine == null:
		return { "success": false, "reason": "missing_relationship_graph"}
	var actor_entity: Dictionary = gs.relationship_graph_contract_engine.ensure_person_entity(actor, { "source": ENGINE_SCHEMA})
	var entity_contract: Dictionary = gs.relationship_graph_contract_engine.ensure_entity(entity, { "source": ENGINE_SCHEMA})
	return gs.relationship_graph_contract_engine.commit_relationship_event({
		"producer": ENGINE_SCHEMA,
		"event_type": relationship_type,
		"relationship_type": relationship_type,
		"relationship_tags": tags.duplicate(true),
		"subject_entity_id": str(actor_entity.get("entity_id", "")),
		"object_entity_id": str(entity_contract.get("entity_id", "")),
		"subject_role": subject_role,
		"object_role": object_role,
		"bond": bond,
		"context": context.duplicate(true)
	}, { "producer": ENGINE_SCHEMA})

func _birth_family_pet_roll_passes(actor: Person) -> bool:
	var chance: int = 24
	var mode_text: String = ""
	if gs != null and typeof(gs.custom_settings) == TYPE_DICTIONARY:
		mode_text = str(gs.custom_settings.get("reality_mode", gs.custom_settings.get("mode", ""))).to_lower()
	if mode_text.find("enhanced") != -1:
		chance = 30
	elif mode_text.find("chaos") != -1 or mode_text.find("fantasy") != -1:
		chance = 38
	var rng:= RandomNumberGenerator.new()
	rng.seed = abs(("birth_pet:%d:%d" % [int(actor.id), int(gs.year if gs != null else 0)]).hash())
	return rng.randi_range(1, 100) <= chance
func _birth_family_pet_seeded_key(anchor: Person) -> String:
	if anchor == null:
		return "birth_family_pet_seeded_for_household_anchor_-1"
	return "birth_family_pet_seeded_for_household_anchor_%d" % int(anchor.id)


func _birth_family_pet_entity_key(anchor: Person) -> String:
	if anchor == null:
		return "birth_family_pet_entity_for_household_anchor_-1"
	return "birth_family_pet_entity_for_household_anchor_%d" % int(anchor.id)


func _existing_family_pet_card_for_anchor(anchor: Person) -> Dictionary:
	if gs == null or anchor == null or gs.relationship_graph_contract_engine == null:
		return {}

	var anchor_entity: Dictionary = gs.relationship_graph_contract_engine.ensure_person_entity(anchor, { "source": ENGINE_SCHEMA})
	var cards: Array = gs.relationship_graph_contract_engine.cards_for_entity(str(anchor_entity.get("entity_id", "")), {
		"tag_any": ["family_pet", "birth_family_pet", "household_pet"]
	})

	for raw_card in cards:
		var card: Dictionary = _safe_dictionary(raw_card)
		if card.is_empty():
			continue

		var edge: Dictionary = _safe_dictionary(card.get("edge", {}))
		var tags: Array = _safe_array(edge.get("relationship_tags", []))
		if tags.has("family_pet") or tags.has("birth_family_pet") or tags.has("household_pet"):
			return card.duplicate(true)

	return {}


func _household_pet_names_for_anchor(anchor: Person) -> Array:
	var out: Array = []
	if gs == null or anchor == null:
		return out

	if gs.relationship_graph_contract_engine != null:
		var anchor_entity: Dictionary = gs.relationship_graph_contract_engine.ensure_person_entity(anchor, { "source": ENGINE_SCHEMA})
		var cards: Array = gs.relationship_graph_contract_engine.cards_for_entity(str(anchor_entity.get("entity_id", "")), {
			"tag_any": ["pet", "family_pet", "mythical_pet", "birth_family_pet", "household_pet"]
		})

		for raw_card in cards:
			var card: Dictionary = _safe_dictionary(raw_card)
			var name_text: String = str(card.get("target_name", "")).strip_edges()
			if name_text != "":
				out.append(name_text)

	if typeof(gs.entity_registry) == TYPE_DICTIONARY:
		for raw_entity_id in gs.entity_registry.keys():
			var entity: Dictionary = _safe_dictionary(gs.entity_registry.get(raw_entity_id, {}))
			if entity.is_empty():
				continue

			var entity_kind: String = str(entity.get("entity_kind", entity.get("entity_type", ""))).strip_edges().to_lower()
			if entity_kind not in ["animal", "mythical"]:
				continue

			var owner_id: int = _safe_int_value(entity.get("owner_person_id", -1), -1)
			var household_anchor_id: int = _safe_int_value(entity.get("household_pet_anchor_id", owner_id), owner_id)
			if owner_id != int(anchor.id) and household_anchor_id != int(anchor.id):
				continue

			var entity_name: String = str(entity.get("display_name", "")).strip_edges()
			if entity_name != "":
				out.append(entity_name)

	return out


func _unique_birth_family_pet_name(species_id: String, seed_key: String, used_names: Array) -> String:
	var local_used: Dictionary = {}
	for raw_name in used_names:
		var used_name: String = str(raw_name).strip_edges().to_lower()
		if used_name != "":
			local_used [used_name] = true

	if gs != null and gs.animal_contract_engine != null:
		for attempt in range(24):
			var candidate: String = gs.animal_contract_engine.default_name_for_species(species_id, "%s:name:%d" % [seed_key, attempt])
			var clean_candidate: String = candidate.strip_edges()
			if clean_candidate == "":
				continue
			if not bool(local_used.get(clean_candidate.to_lower(), false)):
				return clean_candidate

	var species_label: String = str(species_id).strip_edges().capitalize()
	for attempt in range(2, 100):
		var fallback_name: String = "%s %d" % [species_label, attempt]
		if not bool(local_used.get(fallback_name.to_lower(), false)):
			return fallback_name

	return "%s %d" % [species_label, int(Time.get_ticks_msec())]


func _name_already_used_in_list(name_text: String, used_names: Array) -> bool:
	var clean_name: String = str(name_text).strip_edges().to_lower()
	if clean_name == "":
		return false

	for raw_name in used_names:
		if str(raw_name).strip_edges().to_lower() == clean_name:
			return true

	return false


func _birth_family_pet_age_for_species(species_id: String, seed_key: String, context: Dictionary = {}) -> int:
	var forced_age: int = _safe_int_value(context.get("age", context.get("age_years", null)), -1)
	if forced_age >= 0:
		return forced_age

	if gs == null or gs.animal_contract_engine == null:
		return 0

	var species: Dictionary = gs.animal_contract_engine.define_species(species_id, { "source": ENGINE_SCHEMA})
	if species.is_empty():
		return 0

	var lifespan_max: int = max(1, int(species.get("lifespan_max", 12)))
	var max_seed_age: int = max(0, lifespan_max - 1)

	if bool(context.get("allow_elder_family_pet", false)):
		max_seed_age = max(0, lifespan_max - 1)
	else:
		max_seed_age = min(max_seed_age, 12)

	return _stable_roll_between(0, max_seed_age, "%s:age" % seed_key)


func _repair_duplicate_pet_names_for_cards(cards: Array) -> Array:
	if gs == null or typeof(gs.entity_registry) != TYPE_DICTIONARY:
		return cards

	var used_names: Dictionary = {}
	var repaired_cards: Array = []

	for raw_card in cards:
		var card: Dictionary = _safe_dictionary(raw_card).duplicate(true)
		if card.is_empty():
			continue

		var target_entity_id: String = str(card.get("target_entity_id", "")).strip_edges()
		var entity: Dictionary = _safe_dictionary(card.get("target_entity", {})).duplicate(true)
		if target_entity_id != "":
			var registry_entity: Dictionary = _safe_dictionary(gs.entity_registry.get(target_entity_id, {}))
			if not registry_entity.is_empty():
				entity = registry_entity.duplicate(true)

		var current_name: String = str(entity.get("display_name", card.get("target_name", ""))).strip_edges()
		if current_name == "":
			current_name = str(card.get("target_name", "Pet")).strip_edges()

		var current_key: String = current_name.to_lower()
		if current_key != "" and bool(used_names.get(current_key, false)):
			var species_id: String = str(entity.get("species_id", card.get("entity_type", "animal"))).strip_edges().to_lower()
			var replacement_name: String = _unique_birth_family_pet_name(species_id, "duplicate_repair:%s" % target_entity_id, used_names.keys())

			entity ["display_name"] = replacement_name
			entity ["updated_at_ms"] = int(Time.get_ticks_msec())

			if target_entity_id != "":
				gs.entity_registry [target_entity_id] = entity.duplicate(true)
				if gs.relationship_graph_contract_engine != null and gs.relationship_graph_contract_engine.has_method("ensure_entity"):
					gs.relationship_graph_contract_engine.ensure_entity(entity, { "source": "duplicate_pet_name_repair"})

			card ["target_entity"] = entity.duplicate(true)
			card ["target_name"] = replacement_name
			card ["target_name_with_age"] = _pet_name_with_age(entity)

			var surface_contract: Dictionary = _safe_dictionary(card.get("surface_contract", {}))
			if not surface_contract.is_empty():
				surface_contract ["card_title"] = _pet_name_with_age(entity)
				card ["surface_contract"] = surface_contract

			current_name = replacement_name
			current_key = current_name.to_lower()

		if current_key != "":
			used_names [current_key] = true

		repaired_cards.append(card.duplicate(true))

	return repaired_cards


func _pet_name_with_age(entity: Dictionary) -> String:
	var name_text: String = str(entity.get("display_name", "Unknown")).strip_edges()
	var age_value: int = _safe_int_value(entity.get("age", entity.get("age_years", -1)), -1)
	if age_value >= 0:
		return "%s (Age %d)" % [name_text, age_value]
	return name_text


func _world_seed_value() -> int:
	if gs == null:
		return 0

	if typeof(gs.scenario_state) == TYPE_DICTIONARY:
		var scenario_seed: int = _safe_int_value(gs.scenario_state.get("world_seed", -1), -1)
		if scenario_seed > 0:
			return scenario_seed

	if typeof(gs.custom_settings) == TYPE_DICTIONARY:
		var custom_seed: int = _safe_int_value(gs.custom_settings.get("world_seed", -1), -1)
		if custom_seed > 0:
			return custom_seed

	return 0


func _stable_roll_between(min_value: int, max_value: int, seed_key: String) -> int:
	var low: int = min(min_value, max_value)
	var high: int = max(min_value, max_value)
	if low == high:
		return low

	var rng:= RandomNumberGenerator.new()
	rng.seed = abs(str(seed_key).hash())
	return rng.randi_range(low, high)
func _profile_lines(entity: Dictionary, card: Dictionary) -> Array:
	var species_name: String = str(entity.get("species_name", entity.get("species_id", "Animal")))
	var sub_species_name: String = str(entity.get("sub_species_name", "")).strip_edges()
	var role_text: String = str(card.get("role", "Companion")).strip_edges()
	var bond_value: int = clampi(int(card.get("bond", 50)), 0, 100)
	var feed_contract: Dictionary = _feed_contract_for_entity(entity, _actor_by_id(int(card.get("household_access_actor_id", card.get("actor_id", -1)))))
	var gender_text: String = str(entity.get("gender", "unknown")).strip_edges().capitalize()
	var reproduction_contract: Dictionary = _safe_dictionary(entity.get("reproduction_contract", _safe_dictionary(entity.get("species_contract", {})).get("reproduction", {})))
	var reproduction_type: String = str(reproduction_contract.get("type", "unknown")).replace("_", " ").capitalize()
	var offspring_label: String = str(reproduction_contract.get("offspring_label", entity.get("offspring_label", "baby animal")))
	var can_get_pregnant: bool = gender_text.to_lower() == "female" and str(reproduction_contract.get("type", "")).find("egg_layer") < 0

	var lines: Array = [
		"%s is a %s in your life." % [str(entity.get("display_name", "Unknown")), role_text.to_lower()],
		"Species: %s" % species_name,
		"Subspecies: %s" % (sub_species_name if sub_species_name != "" else species_name),
		"Bond State: %s" % _bond_description(bond_value),
		"Eats: %s" % str(feed_contract.get("diet_display", "species-appropriate food")),
		"Current Feed: %s" % str(feed_contract.get("button_label", "No available food")),
		"Social Type: %s" % str(entity.get("social_type", "unknown")).replace("_", " ").capitalize(),
		"Trainable: %s" % ("Yes" if bool(entity.get("trainable", false)) else "No"),
		"Sex: %s" % gender_text,
		"Reproduction: %s" % reproduction_type,
		"Offspring: %s" % offspring_label
	]

	if can_get_pregnant:
		lines.append("Pregnant: %s" % ("Yes" if bool(entity.get("pregnant", false)) else "No"))

	lines.append("Danger Level: %d / 10" % int(entity.get("danger_level", 0)))
	return lines
func _stat_rows(entity: Dictionary, card: Dictionary) -> Array:
	var stats: Dictionary = _safe_dictionary(entity.get("stats", {}))
	var bond_value: int = clampi(int(card.get("bond", 50)), 0, 100)
	var health_max: int = max(1, int(stats.get("health_max", 100)))
	var health_value: int = clampi(int(stats.get("health", 100)), 0, health_max)
	var trust_value: int = clampi(int(stats.get("trust", 50)), 0, 100)
	var training_value: int = clampi(int(stats.get("training", 0)), 0, 100)
	var smarts_value: int = clampi(int(stats.get("smarts", 50)), 0, 100)
	var instinct_value: int = clampi(int(stats.get("instinct", 50)), 0, 100)
	var danger_value: int = clampi(int(entity.get("danger_level", 0)), 0, 10)
	var hunger_value: int = clampi(int(stats.get("hunger", 0)), 0, 100)
	var stress_value: int = clampi(int(stats.get("stress", 0)), 0, 100)
	var fertility_value: int = clampi(int(stats.get("fertility", 50)), 0, 100)
	var bloodthirst_value: int = clampi(int(stats.get("bloodthirst", 0)), 0, 100)

	return [
		{ "title": "Bond", "key": "bond", "value": bond_value, "max": 100, "description": _bond_description(bond_value), "gradient_mode": "bond", "pulse_when_high": bond_value >= 76, "positive_delta_is_good": true},
		{ "title": "Health", "key": "health", "value": health_value, "max": health_max, "description": _health_description(health_value), "gradient_mode": "health", "pulse_when_high": health_value >= 85, "positive_delta_is_good": true},
		{ "title": "Trust", "key": "trust", "value": trust_value, "max": 100, "description": _trust_description(trust_value), "gradient_mode": "trust", "pulse_when_high": trust_value >= 76, "shake_when_low": trust_value <= 28, "positive_delta_is_good": true},
		{ "title": "Training", "key": "training", "value": training_value, "max": 100, "description": _training_description(entity, training_value), "gradient_mode": "training", "pulse_when_high": training_value >= 72, "positive_delta_is_good": true},
		{ "title": "Smarts", "key": "smarts", "value": smarts_value, "max": 100, "description": _smarts_description(smarts_value), "gradient_mode": "smarts", "positive_delta_is_good": true},
		{ "title": "Instinct", "key": "instinct", "value": instinct_value, "max": 100, "description": _instinct_description(instinct_value), "gradient_mode": "smarts", "pulse_when_high": instinct_value >= 82, "positive_delta_is_good": true},
		{ "title": "Hunger", "key": "hunger", "value": hunger_value, "max": 100, "description": _hunger_description(entity, hunger_value), "gradient_mode": "hunger", "shake_when_low": hunger_value >= 92, "positive_delta_is_good": false},
		{ "title": "Stress", "key": "stress", "value": stress_value, "max": 100, "description": _stress_description(stress_value), "gradient_mode": "danger", "shake_when_low": stress_value >= 75, "positive_delta_is_good": false},
		{ "title": "Fertility", "key": "fertility", "value": fertility_value, "max": 100, "description": _fertility_description(fertility_value), "gradient_mode": "health", "pulse_when_high": fertility_value >= 78, "positive_delta_is_good": true},
		{ "title": "Bloodthirst", "key": "bloodthirst", "value": bloodthirst_value, "max": 100, "description": _bloodthirst_description(bloodthirst_value), "gradient_mode": "danger", "pulse_when_high": bloodthirst_value >= 70, "positive_delta_is_good": false},
		{ "title": "Danger", "key": "danger", "value": danger_value, "max": 10, "description": _danger_description(danger_value), "gradient_mode": "danger", "pulse_when_high": danger_value >= 7, "danger_reactive": true, "positive_delta_is_good": false}
	]
func _health_description(value: int) -> String:
	if value >= 90:
		return "They are thriving."
	if value >= 70:
		return "They seem healthy."
	if value >= 45:
		return "They seem a little worn down."
	if value >= 20:
		return "They are in rough condition."
	return "THEY ARE BARELY HOLDING ON"

func _smarts_description(value: int) -> String:
	if value >= 90:
		return "They understand things almost too well."
	if value >= 70:
		return "They are sharp and quick to learn."
	if value >= 45:
		return "They understand simple patterns."
	if value >= 20:
		return "They get confused easily."
	return "They are running on vibes."

func _training_description(entity: Dictionary, value: int) -> String:
	var gender_text: String = str(entity.get("gender", "")).to_lower()
	if value >= 95:
		return "THEY ARE A GOOD GIRL" if gender_text == "female" else "THEY ARE A GOOD BOY"
	if value >= 75:
		return "They listen almost every time."
	if value >= 50:
		return "They kinda listen, but still do what they want."
	if value >= 25:
		return "They barely follow instructions."
	return "They remain wildly untrained."

func _instinct_description(value: int) -> String:
	if value >= 90:
		return "Their instincts are terrifyingly sharp."
	if value >= 70:
		return "They sense danger before it arrives."
	if value >= 45:
		return "They react naturally to their surroundings."
	if value >= 20:
		return "Their instincts are dull but present."
	return "They would not survive long alone."

func _hunger_description(entity: Dictionary, value: int) -> String:
	if bool(entity.get("stuffed", false)):
		return "They are stuffed."
	if value <= 0:
		return "They are full."
	if value <= 25:
		return "They could eat, but they are fine."
	if value <= 55:
		return "They are hungry."
	if value <= 85:
		return "They are extremely hungry."
	return "THEY ARE STARVING"

func _stress_description(value: int) -> String:
	if value >= 90:
		return "They are dangerously stressed."
	if value >= 70:
		return "They are tense and unstable."
	if value >= 40:
		return "They are uneasy."
	if value >= 15:
		return "They are mostly calm."
	return "They are relaxed."

func _fertility_description(value: int) -> String:
	if value >= 85:
		return "Their breeding potential is very strong."
	if value >= 60:
		return "Their breeding potential is stable."
	if value >= 35:
		return "Their breeding potential is uncertain."
	return "Their breeding potential is weak."

func _bloodthirst_description(value: int) -> String:
	if value >= 90:
		return "They crave blood and prey."
	if value >= 70:
		return "They are developing a dangerous taste for meat."
	if value >= 40:
		return "Raw meat is changing their temperament."
	if value >= 15:
		return "They show mild prey interest."
	return "They are not especially bloodthirsty."

func _danger_description(value: int) -> String:
	if value >= 10:
		return "THEY WILL KILL YOU IF THEY WANT"
	if value >= 8:
		return "They are extremely dangerous."
	if value >= 5:
		return "They could hurt you badly."
	if value >= 2:
		return "They are mostly manageable."
	return "They are harmless."
func _apply_pet_action_state_delta(entity_id: String, action_id: String, action: Dictionary = {}, feed_attempt: Dictionary = {}) -> Dictionary:
	if gs == null or typeof(gs.entity_registry) != TYPE_DICTIONARY:
		return {}

	var entity: Dictionary = _safe_dictionary(gs.entity_registry.get(entity_id, {}))
	if entity.is_empty():
		return {}

	var stats: Dictionary = _safe_dictionary(entity.get("stats", {}))
	var before_stats: Dictionary = stats.duplicate(true)
	var health_max: int = max(1, int(stats.get("health_max", 100)))

	if action_id == "pet:feed" and not bool(feed_attempt.get("accepted", true)):
		return {
			"before": before_stats.duplicate(true),
			"after": stats.duplicate(true),
			"entity": entity.duplicate(true),
			"accepted": false,
			"attack_happened": bool(feed_attempt.get("attack_happened", false)),
			"affected_stats": []
		}

	match action_id:
		"pet:feed":
			stats ["hunger"] = clampi(int(stats.get("hunger", 0)) + int(action.get("hunger_delta", -24)), 0, 100)
			var selected_food: Dictionary = _safe_dictionary(_safe_dictionary(feed_attempt.get("food_contract", {})).get("selected_food", {}))
			entity ["last_fed_food_id"] = str(selected_food.get("item_id", ""))
			entity ["last_fed_food_name"] = str(selected_food.get("display_name", "food"))
			entity ["stuffed"] = int(before_stats.get("hunger", 0)) <= 0
			stats ["bloodthirst"] = clampi(int(stats.get("bloodthirst", 0)) + int(selected_food.get("bloodthirst_delta", 0)), 0, 100)
			stats ["trust"] = clampi(int(stats.get("trust", 50)) + int(action.get("trust_delta", 2)), 0, 100)
			stats ["health"] = clampi(int(stats.get("health", 100)) + int(action.get("health_delta", 1)), 0, health_max)
		"pet:groom":
			stats ["trust"] = clampi(int(stats.get("trust", 50)) + int(action.get("trust_delta", 2)), 0, 100)
			stats ["health"] = clampi(int(stats.get("health", 100)) + int(action.get("health_delta", 2)), 0, health_max)
		"pet:pet":
			stats ["trust"] = clampi(int(stats.get("trust", 50)) + int(action.get("trust_delta", 3)), 0, 100)
		"pet:play":
			stats ["trust"] = clampi(int(stats.get("trust", 50)) + int(action.get("trust_delta", 4)), 0, 100)
		"pet:walk":
			stats ["trust"] = clampi(int(stats.get("trust", 50)) + int(action.get("trust_delta", 3)), 0, 100)
		"pet:train":
			stats ["training"] = clampi(int(stats.get("training", 0)) + int(action.get("training_delta", 8)), 0, 100)
			stats ["smarts"] = clampi(int(stats.get("smarts", 50)) + int(action.get("smarts_delta", 1)), 0, 100)
			stats ["trust"] = clampi(int(stats.get("trust", 50)) + int(action.get("trust_delta", 1)), 0, 100)
		"pet:observe":
			stats ["smarts"] = clampi(int(stats.get("smarts", 50)) + 1, 0, 100)
		_:
			pass

	entity ["stats"] = stats
	entity ["updated_at_ms"] = int(Time.get_ticks_msec())
	gs.entity_registry [entity_id] = entity.duplicate(true)

	if gs.relationship_graph_contract_engine != null:
		gs.relationship_graph_contract_engine.ensure_entity(entity, { "source": "pet_action_state_delta"})

	return {
		"before": before_stats.duplicate(true),
		"after": stats.duplicate(true),
		"entity": entity.duplicate(true),
		"accepted": true,
		"attack_happened": false,
		"affected_stats": _changed_stat_keys(before_stats, stats)
	}
func _action_result_text(entity: Dictionary, action: Dictionary, state_delta: Dictionary = {}, bond_delta: int = 0) -> String:
	return "\n".join(_action_feedback_lines(entity, action, state_delta, bond_delta))
func _profile_identity_contract(entity: Dictionary, card: Dictionary) -> Dictionary:
	# Prefer the card's resolved age (set from resolve_animal_lifecycle) so the
	# profile cannot disagree with the card the player clicked through from.
	var age_value: int = int(
		card.get(
			"target_age",
			entity.get("age", entity.get("age_years", 0))
		)
	)

	if age_value < 0:
		age_value = int(entity.get("age", entity.get("age_years", 0)))
	var role_text: String = str(card.get("role", "Companion")).strip_edges()
	if role_text == "":
		role_text = "Companion"

	var species_name: String = str(entity.get("species_name", entity.get("species_id", "Animal")))
	var sub_species_name: String = str(entity.get("sub_species_name", "")).strip_edges()
	var lineage_name: String = sub_species_name if sub_species_name != "" else species_name

	return {
		"display_name": str(entity.get("display_name", "Unknown")),
		"species_badge": lineage_name.to_upper(),
		"species_label": "The %s" % lineage_name,
		"age_label": str(age_value),
		"relationship_role": role_text
	}


func _bond_contract(_entity_contract: Dictionary, card: Dictionary) -> Dictionary:
	var bond_value: int = clampi(int(card.get("bond", 50)), 0, 100)
	var bond_color: Color = Color(1.0, 0.36, 0.62, 1.0)

	if bond_value <= 35:
		bond_color = Color(1.0, 0.34, 0.34, 1.0)
	elif bond_value <= 74:
		bond_color = Color(1.0, 0.84, 0.22, 1.0)

	return {
		"value": bond_value,
		"max": 100,
		"description": _bond_description(bond_value),
		"color": bond_color,
		"pulse_when_high": bond_value >= 76
	}

func _trait_chip_contracts(entity: Dictionary, _card: Dictionary) -> Array:
	var out: Array = []
	var stats: Dictionary = _safe_dictionary(entity.get("stats", {}))
	var trust_value: int = clampi(int(stats.get("trust", 50)), 0, 100)
	var training_value: int = clampi(int(stats.get("training", 0)), 0, 100)

	for raw_trait in _safe_array(entity.get("behavior_traits", [])):
		var trait_text: String = str(raw_trait).strip_edges()
		if trait_text == "":
			continue

		var trait_id: String = trait_text.to_lower().replace(" ", "_")
		var icon_text: String = "◆"
		var chip_color: Color = Color(0.66, 0.9, 1.0, 1.0)
		var state: String = "steady"

		match trait_id:
			"strong":
				icon_text = "✦"
				chip_color = Color(1.0, 0.7, 0.4, 1.0)
			"sensitive":
				icon_text = "❤"
				chip_color = Color(1.0, 0.55, 0.68, 1.0)
				if trust_value <= 35:
					state = "pulse"
			"trainable":
				icon_text = "⬆"
				chip_color = Color(0.76, 1.0, 0.54, 1.0)
				if training_value >= 50:
					state = "glow"
			"protective":
				icon_text = "🛡"
				chip_color = Color(0.78, 0.9, 1.0, 1.0)
			"playful":
				icon_text = "★"
				chip_color = Color(1.0, 0.92, 0.46, 1.0)
			"loyal":
				icon_text = "✚"
				chip_color = Color(0.74, 1.0, 0.84, 1.0)
			"gentle":
				icon_text = "❀"
				chip_color = Color(0.92, 0.86, 1.0, 1.0)
			"alert":
				icon_text = "⚑"
				chip_color = Color(1.0, 0.76, 0.38, 1.0)
			_:
				pass

		out.append({
			"id": trait_id,
			"label": trait_text.to_upper(),
			"icon": icon_text,
			"color": chip_color,
			"state": state
		})

	return out


func _action_groups(actions: Array) -> Array:
	var order: Array = ["CARE", "BOND", "GROWTH", "REPRODUCTION", "SAFETY", "MYSTICAL"]
	var buckets: Dictionary = {}
	for group_name in order:
		buckets [group_name] = []

	for raw_action in actions:
		var action: Dictionary = _safe_dictionary(raw_action)
		var group_name: String = str(action.get("group", "BOND")).strip_edges().to_upper()
		if not buckets.has(group_name):
			buckets [group_name] = []
		var rows: Array = _safe_array(buckets.get(group_name, []))
		rows.append(action.duplicate(true))
		buckets [group_name] = rows

	var out: Array = []
	for group_name in order:
		var group_actions: Array = _safe_array(buckets.get(group_name, []))
		if group_actions.is_empty():
			continue

		out.append({
			"title": group_name,
			"description": _action_group_description(group_name),
			"actions": group_actions.duplicate(true)
		})

	for raw_key in buckets.keys():
		var key_text: String = str(raw_key)
		if key_text in order:
			continue
		var extra_actions: Array = _safe_array(buckets.get(key_text, []))
		if extra_actions.is_empty():
			continue
		out.append({
			"title": key_text,
			"description": "",
			"actions": extra_actions.duplicate(true)
		})

	return out


func _action_group_description(group_name: String) -> String:
	match group_name:
		"CARE":
			return "Maintain comfort and physical wellbeing."
		"BOND":
			return "Deepen affection and shared trust."
		"GROWTH":
			return "Build discipline, responsiveness, and development."
		"REPRODUCTION":
			return "Breed, hatch, lay, or collect offspring through committed animal contracts."
		"SAFETY":
			return "Handle higher-risk animals carefully."
		"MYSTICAL":
			return "Actions tied to unusual or magical companions."
		_:
			return ""


func _bond_description(value: int) -> String:
	if value >= 86:
		return "They clearly trust your presence."
	if value >= 70:
		return "Comfort and familiarity are well established."
	if value >= 45:
		return "They are warming up to you."
	return "This relationship still needs patience and care."


func _trust_description(value: int) -> String:
	if value >= 85:
		return "Very trusting — your presence feels safe."
	if value >= 60:
		return "Steady trust — they usually relax around you."
	if value >= 35:
		return "Guarded trust — progress is being made."
	return "Low trust — move gently and avoid pressure."




func _action_feedback_lines(entity: Dictionary, action: Dictionary, state_delta: Dictionary = {}, bond_delta: int = 0) -> Array:
	var name_text: String = str(entity.get("display_name", "your pet"))
	var species_text: String = str(entity.get("species_name", entity.get("species_id", "animal"))).to_lower()
	var action_id: String = str(action.get("id", ""))
	var feed_attempt: Dictionary = _safe_dictionary(state_delta.get("feed_attempt", {}))
	var line_one: String = ""
	var line_two: String = ""

	if action_id == "pet:feed" and not bool(state_delta.get("accepted", true)):
		if bool(state_delta.get("attack_happened", false)):
			line_one = "%s refuses the food and attacks." % name_text
			line_two = "%s the %s was too dangerous to feed casually." % [name_text, species_text]
		else:
			line_one = "%s refuses the food." % name_text
			line_two = "%s the %s does not feel safe enough to eat from you right now." % [name_text, species_text]
	elif action_id == "pet:feed":
		var food_name: String = str(_safe_dictionary(action.get("food_contract", {})).get("display_food", "food"))
		line_one = "You feed %s %s." % [name_text, food_name]
		line_two = "%s the %s accepts the food and settles down." % [name_text, species_text]
	else:
		match action_id:
			"pet:groom":
				line_one = "You carefully groom %s." % name_text
				line_two = "%s the %s seems calmer and better cared for." % [name_text, species_text]
			"pet:pet":
				line_one = "You gently pet %s." % name_text
				line_two = "%s the %s leans into you, clearly comfortable." % [name_text, species_text]
			"pet:play":
				line_one = "You play with %s." % name_text
				line_two = "%s the %s becomes more animated and engaged with you." % [name_text, species_text]
			"pet:walk":
				line_one = "You take %s for a walk." % name_text
				line_two = "%s the %s moves with you and seems more connected afterward." % [name_text, species_text]
			"pet:train":
				line_one = "You spend time training %s." % name_text
				line_two = "%s the %s responds with more focus and discipline." % [name_text, species_text]
			"pet:observe":
				line_one = "You observe %s carefully." % name_text
				line_two = "You give %s the %s space while learning their behavior." % [name_text, species_text]
			_:
				line_one = "You interact with %s." % name_text
				line_two = "%s the %s responds to your attention." % [name_text, species_text]

	var delta_line_bits: Array = []
	if bond_delta != 0:
		delta_line_bits.append("%+d Bond" % bond_delta)

	var before_stats: Dictionary = _safe_dictionary(state_delta.get("before", {}))
	var after_stats: Dictionary = _safe_dictionary(state_delta.get("after", {}))
	for stat_key in ["hunger", "trust", "training", "health", "smarts"]:
		var before_value: int = int(before_stats.get(stat_key, 0))
		var after_value: int = int(after_stats.get(stat_key, before_value))
		var delta_value: int = after_value - before_value
		if delta_value == 0:
			continue
		delta_line_bits.append("%+d %s" % [delta_value, stat_key.capitalize()])

	if int(feed_attempt.get("actor_health_delta", 0)) != 0:
		delta_line_bits.append("%+d Your Health" % int(feed_attempt.get("actor_health_delta", 0)))

	if bool(feed_attempt.get("actor_died", false)):
		delta_line_bits.append("You died")

	if not delta_line_bits.is_empty():
		return [
			line_one,
			line_two,
			"(%s)" % ", ".join(delta_line_bits)
		]

	return [
		line_one,
		line_two
	]
func _feed_contract_for_entity(entity: Dictionary, actor: Person = null, _context: Dictionary = {}) -> Dictionary:
	var diet_profile: Dictionary = _pet_diet_profile(entity)
	var preferred_foods: Array = _safe_array(diet_profile.get("preferred_foods", []))
	var available_foods: Array = _available_pet_food_options_for_actor(actor, entity, diet_profile)
	var selected_food: Dictionary = _rotating_pet_food_choice(entity, preferred_foods, available_foods)

	var display_food: String = str(selected_food.get("display_name", "food"))
	var quantity: int = int(selected_food.get("quantity", 0))
	var button_label: String = "Feed %s (%d left)" % [display_food, quantity] if quantity > 0 else "Buy Food"

	return {
		"diet_type": str(diet_profile.get("diet_type", "omnivore")),
		"diet_display": str(diet_profile.get("diet_display", "species-appropriate food")),
		"display_food": display_food,
		"button_label": button_label,
		"selected_food": selected_food.duplicate(true),
		"has_available_food": quantity > 0,
		"preferred_foods": preferred_foods.duplicate(true),
		"available_foods": available_foods.duplicate(true),
		"valid_food_tags": _safe_array(diet_profile.get("valid_food_tags", [])).duplicate(true),
	}

func _pet_diet_profile(entity: Dictionary) -> Dictionary:
	var species_id: String = str(entity.get("species_id", "")).strip_edges().to_lower()
	var species_name: String = str(entity.get("species_name", species_id)).strip_edges().to_lower()

	match species_id:
		"horse":
			return {
				"diet_type": "herbivore",
				"diet_display": "apples, hay, oats, grass, and other plants",
				"preferred_foods": ["apple", "hay", "oats", "grass"],
				"valid_food_tags": ["plant", "fruit", "grain", "grass", "hay"]
			}
		"camel":
			return {
				"diet_type": "herbivore",
				"diet_display": "grass, hay, grains, and tough desert plants",
				"preferred_foods": ["grass", "hay", "desert plants", "grain"],
				"valid_food_tags": ["plant", "grass", "hay", "grain", "desert_plant"]
			}
		"rabbit":
			return {
				"diet_type": "herbivore",
				"diet_display": "greens, hay, grass, and vegetables",
				"preferred_foods": ["greens", "hay", "grass", "vegetables"],
				"valid_food_tags": ["plant", "greens", "hay", "grass", "vegetable"]
			}
		"falcon":
			return {
				"diet_type": "carnivore",
				"diet_display": "meat and small prey",
				"preferred_foods": ["meat", "small prey"],
				"valid_food_tags": ["meat", "prey"]
			}
		"cat":
			return {
				"diet_type": "carnivore",
				"diet_display": "fish, meat, and small prey",
				"preferred_foods": ["fish", "meat"],
				"valid_food_tags": ["fish", "meat", "prey"]
			}
		"dog":
			return {
				"diet_type": "omnivore",
				"diet_display": "meat scraps, safe table food, and dog food",
				"preferred_foods": ["meat scraps", "dog food"],
				"valid_food_tags": ["meat", "prepared_food", "dog_food"]
			}
		_:
			pass

	if species_name.find("dragon") >= 0:
		return {
			"diet_type": "carnivore",
			"diet_display": "raw meat, livestock, and dangerous prey",
			"preferred_foods": ["raw meat", "livestock"],
			"valid_food_tags": ["meat", "livestock", "prey"]
		}

	if species_name.find("unicorn") >= 0:
		return {
			"diet_type": "herbivore",
			"diet_display": "apples, enchanted grasses, and pure plants",
			"preferred_foods": ["apple", "enchanted grass"],
			"valid_food_tags": ["plant", "fruit", "grass", "enchanted_plant"]
		}

	if species_name.find("phoenix") >= 0:
		return {
			"diet_type": "mythic_omnivore",
			"diet_display": "berries, seeds, and warm magical essence",
			"preferred_foods": ["berries", "seeds"],
			"valid_food_tags": ["fruit", "seed", "magic"]
		}

	return {
		"diet_type": "omnivore",
		"diet_display": "species-appropriate food",
		"preferred_foods": ["food"],
		"valid_food_tags": ["food"]
	}


func _resolve_feed_attempt(actor: Person, entity: Dictionary, action: Dictionary, _context: Dictionary = {}) -> Dictionary:
	var stats: Dictionary = _safe_dictionary(entity.get("stats", {}))
	var trust_value: int = clampi(int(stats.get("trust", 50)), 0, 100)
	var health_max: int = max(1, int(stats.get("health_max", 100)))
	var health_value: int = clampi(int(stats.get("health", 100)), 0, health_max)
	var health_ratio: float = float(health_value) / float(health_max)
	var entity_id: String = str(entity.get("entity_id", "")).strip_edges()
	var bond_value: int = _bond_for_actor_entity(actor, entity_id)
	var danger_value: int = clampi(int(entity.get("danger_level", 0)), 0, 10)
	var feed_contract: Dictionary = _safe_dictionary(action.get("food_contract", _feed_contract_for_entity(entity)))
	var selected_food: Dictionary = _safe_dictionary(feed_contract.get("selected_food", {}))
	if not bool(feed_contract.get("has_available_food", false)):
		if bool(_context.get("quick_buy", false)) and gs.meat_market_contract_engine != null:
			var quick_buy_id: String = str(selected_food.get("listing_id", "meat_scraps"))
			var quick_buy_report: Dictionary = gs.meat_market_contract_engine.quick_buy_pet_food(actor, quick_buy_id, {
				"source": ENGINE_SCHEMA,
				"entity_id": entity_id
			})
			if not bool(quick_buy_report.get("success", false)):
				return {
					"accepted": false,
					"attack_happened": false,
					"bond_delta": 0,
					"reason": "missing_food",
					"food_contract": feed_contract.duplicate(true),
					"quick_buy_report": quick_buy_report.duplicate(true)
				}
		else:
			return {
				"accepted": false,
				"attack_happened": false,
				"bond_delta": 0,
				"reason": "missing_food",
				"food_contract": feed_contract.duplicate(true)
			}
	var diet_type: String = str(feed_contract.get("diet_type", "omnivore")).strip_edges().to_lower()
	var ill: bool = health_ratio <= 0.32 or bool(entity.get("ill", false))
	var low_relationship: bool = trust_value <= 18 or bond_value <= 18
	var carnivorous: bool = diet_type.find("carnivore") >= 0 or diet_type.find("meat") >= 0
	var actor_health_delta: int = 0
	var actor_died: bool = false

	if carnivorous and danger_value >= 7 and (trust_value <= 28 or bond_value <= 28):
		var attack_report: Dictionary = _apply_actor_pet_attack_damage(actor, entity, danger_value)
		actor_health_delta = int(attack_report.get("actor_health_delta", 0))
		actor_died = bool(attack_report.get("actor_died", false))

		return {
			"accepted": false,
			"attack_happened": true,
			"actor_health_delta": actor_health_delta,
			"actor_died": actor_died,
			"bond_delta": -8,
			"reason": "dangerous_carnivore_low_trust",
			"food_contract": feed_contract.duplicate(true)
		}

	if ill:
		return {
			"accepted": false,
			"attack_happened": false,
			"bond_delta": 0,
			"reason": "ill_refusal",
			"food_contract": feed_contract.duplicate(true)
		}

	if low_relationship:
		return {
			"accepted": false,
			"attack_happened": false,
			"bond_delta": -1,
			"reason": "low_bond_or_trust",
			"food_contract": feed_contract.duplicate(true)
		}

	return {
		"accepted": true,
		"attack_happened": false,
		"bond_delta": int(action.get("bond_delta", 2)),
		"reason": "accepted",
		"food_contract": feed_contract.duplicate(true)
	}

func _bond_for_actor_entity(actor: Person, entity_id: String) -> int:
	if gs == null or actor == null or gs.relationship_graph_contract_engine == null:
		return 50

	var actor_entity: Dictionary = gs.relationship_graph_contract_engine.ensure_person_entity(actor, { "source": ENGINE_SCHEMA})
	var actor_entity_id: String = str(actor_entity.get("entity_id", "")).strip_edges()
	if actor_entity_id == "" or entity_id == "":
		return 50

	if gs.relationship_graph_contract_engine.has_method("bond_for_pair"):
		return clampi(int(gs.relationship_graph_contract_engine.bond_for_pair(actor_entity_id, entity_id, 50)), 0, 100)

	return 50


func _apply_actor_pet_attack_damage(actor: Person, entity: Dictionary, danger_value: int) -> Dictionary:
	if actor == null:
		return {}

	var damage: int = clampi(8 + (danger_value * 7), 12, 92)
	var before_health: int = clampi(int(actor.get("health")), 0, 100)
	var after_health: int = clampi(before_health - damage, 0, 100)
	actor.set("health", after_health)

	var actor_died: bool = after_health <= 0
	if actor_died:
		actor.set("alive", false)

	return {
		"attacker_entity_id": str(entity.get("entity_id", "")),
		"actor_health_before": before_health,
		"actor_health_after": after_health,
		"actor_health_delta": after_health - before_health,
		"actor_died": actor_died
	}


func _changed_stat_keys(before_stats: Dictionary, after_stats: Dictionary) -> Array:
	var out: Array = []
	for raw_key in after_stats.keys():
		var key_text: String = str(raw_key)
		if int(after_stats.get(key_text, 0)) == int(before_stats.get(key_text, after_stats.get(key_text, 0))):
			continue
		out.append(key_text)
	return out
func _entity(entity_id: String) -> Dictionary:
	if gs == null or typeof(gs.entity_registry) != TYPE_DICTIONARY:
		return {}
	return _safe_dictionary(gs.entity_registry.get(entity_id, {})).duplicate(true)
func _household_pet_anchor_for_actor(actor: Person) -> Person:
	if gs == null or actor == null:
		return actor

	var household_id: int = _household_anchor_id_for_actor(actor)
	if household_id <= 0:
		return actor

	var found: Person = _actor_by_id(household_id)
	return found if found != null else actor

func _household_anchor_id_for_actor(actor: Person) -> int:
	if actor == null:
		return -1

	var explicit_anchor: int = _safe_person_int_property(actor, "household_pet_anchor_id", -1)
	if explicit_anchor > 0:
		return explicit_anchor

	var household_anchor: int = _safe_person_int_property(actor, "household_anchor_id", -1)
	if household_anchor > 0:
		return household_anchor

	var family_id: int = _safe_person_int_property(actor, "family_anchor_id", -1)
	if family_id > 0:
		return family_id

	var custom_household_anchor: int = _custom_household_anchor_id_for_actor(actor)
	if custom_household_anchor > 0:
		return custom_household_anchor

	var parent_anchor: int = _parent_household_anchor_id_for_actor(actor)
	if parent_anchor > 0:
		return parent_anchor

	var partner_anchor: int = _partner_household_anchor_id_for_actor(actor)
	if partner_anchor > 0:
		return partner_anchor

	return int(actor.id)
func _pet_cards_for_household_anchor(access_actor: Person, anchor: Person, seed_if_primary_anchor: bool) -> Array:
	if gs == null or access_actor == null or anchor == null or gs.relationship_graph_contract_engine == null:
		return []

	if seed_if_primary_anchor:
		ensure_birth_family_pet_for_actor(anchor, {
			"source": "pets_tab_lazy_birth_family_seed_household_anchor",
			"max_birth_age": 999
		})

	var anchor_entity: Dictionary = gs.relationship_graph_contract_engine.ensure_person_entity(anchor, { "source": ENGINE_SCHEMA})
	var cards: Array = gs.relationship_graph_contract_engine.cards_for_entity(str(anchor_entity.get("entity_id", "")), {
		"tag_any": ["pet", "family_pet", "mythical_pet"]
	})

	for i in range(cards.size()):
		var card: Dictionary = _safe_dictionary(cards [i])
		card ["household_pet_anchor_id"] = int(anchor.id)
		card ["household_access_actor_id"] = int(access_actor.id)
		card ["access_by_household_association"] = int(anchor.id) != int(access_actor.id)
		card ["role"] = "Household Pet" if int(anchor.id) != int(access_actor.id) else str(card.get("role", "Pet"))
		cards [i] = card

	return cards


func _append_unique_pet_cards(out: Array, seen_entity_ids: Dictionary, cards: Array) -> void:
	for raw_card in cards:
		var card: Dictionary = _safe_dictionary(raw_card)
		if card.is_empty():
			continue

		var target_entity_id: String = str(card.get("target_entity_id", "")).strip_edges()
		if target_entity_id == "":
			continue

		if bool(seen_entity_ids.get(target_entity_id, false)):
			continue

		seen_entity_ids [target_entity_id] = true
		out.append(card.duplicate(true))


func _custom_household_anchor_id_for_actor(actor: Person) -> int:
	if gs == null or actor == null or typeof(gs.scenario_state) != TYPE_DICTIONARY:
		return -1

	var actor_id: int = int(actor.id)
	var member_index: Dictionary = _safe_dictionary(gs.scenario_state.get("custom_household_member_index", {}))
	if member_index.is_empty():
		return -1

	var actor_is_custom_household_member: bool = false
	for raw_key in member_index.keys():
		var member_id: int = _safe_int_value(member_index.get(raw_key, -1), -1)
		if member_id == actor_id:
			actor_is_custom_household_member = true
			break

	if not actor_is_custom_household_member:
		return -1

	var start_key: String = str(gs.scenario_state.get("custom_household_start_person_key", "")).strip_edges()
	if start_key != "" and member_index.has(start_key):
		var start_id: int = _safe_int_value(member_index.get(start_key, -1), -1)
		if start_id > 0:
			return start_id

	var active_player_id: int = _safe_int_value(gs.scenario_state.get("custom_household_active_player_id", -1), -1)
	if active_player_id > 0:
		return active_player_id

	if gs.player != null:
		return int(gs.player.id)

	return actor_id


func _parent_household_anchor_id_for_actor(actor: Person) -> int:
	if actor == null:
		return -1

	var parent_ids: Array = _safe_person_id_array(actor, "parents")
	if parent_ids.is_empty():
		return -1

	for raw_parent_id in parent_ids:
		var parent_id: int = _safe_int_value(raw_parent_id, -1)
		if parent_id <= 0:
			continue

		var parent: Person = _actor_by_id(parent_id)
		if parent == null:
			continue

		if int(actor.age) < 18:
			return parent_id

		if _people_share_home_location(actor, parent):
			return parent_id

	return -1


func _partner_household_anchor_id_for_actor(actor: Person) -> int:
	if actor == null or actor.partner == null:
		return -1

	var partner: Person = actor.partner
	if partner == null:
		return -1

	if int(partner.id) <= 0:
		return -1

	if _people_share_home_location(actor, partner):
		return int(partner.id)

	return -1


func _people_share_home_location(left: Person, right: Person) -> bool:
	if left == null or right == null:
		return false

	if int(left.id) == int(right.id):
		return true

	var left_city: String = str(left.home_city).strip_edges().to_lower()
	var right_city: String = str(right.home_city).strip_edges().to_lower()
	var left_country: String = str(left.home_country).strip_edges().to_lower()
	var right_country: String = str(right.home_country).strip_edges().to_lower()

	if left_city == "" or right_city == "":
		return false
	if left_country == "" or right_country == "":
		return false

	return left_city == right_city and left_country == right_country


func _safe_person_id_array(person: Person, property_name: String) -> Array:
	var out: Array = []
	var raw_value: Variant = _safe_person_variant_property(person, property_name, [])
	if typeof(raw_value) != TYPE_ARRAY:
		return out

	for raw_id in raw_value:
		var clean_id: int = _safe_int_value(raw_id, -1)
		if clean_id > 0:
			out.append(clean_id)

	return out


func _safe_person_int_property(person: Person, property_name: String, fallback: int = -1) -> int:
	var raw_value: Variant = _safe_person_variant_property(person, property_name, null)
	return _safe_int_value(raw_value, fallback)


func _safe_person_variant_property(person: Person, property_name: String, fallback: Variant = null) -> Variant:
	if person == null:
		return fallback

	var clean_name: String = str(property_name).strip_edges()
	if clean_name == "":
		return fallback

	if not person.has_method("get_property_list") or not person.has_method("get"):
		return fallback

	for raw_property_info in person.get_property_list():
		if typeof(raw_property_info) != TYPE_DICTIONARY:
			continue

		var property_info: Dictionary = raw_property_info
		if str(property_info.get("name", "")) == clean_name:
			var value: Variant = person.get(clean_name)
			return fallback if value == null else value

	return fallback


func _safe_int_value(value: Variant, fallback: int = -1) -> int:
	if value == null:
		return fallback

	match typeof(value):
		TYPE_INT:
			return int(value)
		TYPE_FLOAT:
			return int(value)
		TYPE_BOOL:
			return 1 if bool(value) else 0
		TYPE_STRING:
			var text_value: String = str(value).strip_edges()
			if text_value == "":
				return fallback
			if not text_value.is_valid_int():
				return fallback
			return int(text_value)
		_:
			return fallback

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
func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)

func _safe_array(value: Variant) -> Array:
	return value if typeof(value) == TYPE_ARRAY else []

func _refresh_owned_animal_lifecycles(
	actor: Person,
	anchor: Person
) -> void:
	# Derives age/alive for every animal linked to the actor or the household
	# anchor, BEFORE cards are built from those entities. Must run first: card
	# display ages are baked from the entity, not from a field the caller can
	# patch afterwards.
	if (
		gs == null
		or gs.animal_contract_engine == null
		or gs.relationship_graph_contract_engine == null
		or not gs.animal_contract_engine.has_method(
			"resolve_animal_lifecycle"
		)
	):
		return

	var owner_entity_ids: Array = []

	for owner in [actor, anchor]:
		if owner == null:
			continue

		var owner_key: String = "human:%d" % int(owner.id)

		if owner_entity_ids.has(owner_key):
			continue

		owner_entity_ids.append(owner_key)

	var resolved_count: int = 0

	for owner_key in owner_entity_ids:
		for raw_edge in _safe_array(
			gs.relationship_graph_contract_engine.relationships_for_entity(
				owner_key,
				{}
			)
		):
			if typeof(raw_edge) != TYPE_DICTIONARY:
				continue

			# FIX: graph edges are keyed entity_a / entity_b -- there is no
			# target_entity_id on an edge. The previous walk looked for keys that
			# do not exist and matched nothing (resolved=0), so the refresh never
			# ran before card construction.
			var edge: Dictionary = raw_edge
			var side_a: String = str(
				edge.get("entity_a", "")
			).strip_edges()
			var side_b: String = str(
				edge.get("entity_b", "")
			).strip_edges()
			var other_id: String = (
				side_b
				if side_a == owner_key
				else side_a
			)

			if other_id == "" or not other_id.begins_with("animal:"):
				continue

			var lifecycle: Dictionary = _safe_dictionary(
				gs.animal_contract_engine.resolve_animal_lifecycle(
					other_id
				)
			)

			if lifecycle.is_empty():
				continue

			resolved_count += 1

			if bool(lifecycle.get("alive", true)):
				continue

			# Announce the death once. Latched on pet_death_diarised, separate from
			# the resolver's pet_death_recorded, so the diary entry and the
			# ERALIFE_PET_DEATH line cannot double-fire independently.
			var dead_entity: Dictionary = _entity(other_id)

			if (
				actor == null
				or not bool(dead_entity.get("pet_death_recorded", false))
				or bool(dead_entity.get("pet_death_diarised", false))
			):
				continue

			var memorial_text: String = (
				"%s, my %s, died of old age at %d."
				% [
					str(
						dead_entity.get("display_name", "My pet")
					),
					str(
						dead_entity.get(
							"species_name",
							dead_entity.get("species_id", "companion")
						)
					).to_lower(),
					int(
						dead_entity.get("death_age", 0)
					)
				]
			)

			if typeof(actor.memories) == TYPE_ARRAY:
				actor.memories.append(memorial_text)

			if gs.narrative_engine != null:
				gs.narrative_engine.log_event(actor, {
					"type": "pet_death",
					"text": memorial_text,
					"life_diary_text": memorial_text
				})

			if typeof(gs.entity_registry) == TYPE_DICTIONARY:
				var stored_raw = gs.entity_registry.get(other_id, {})

				if typeof(stored_raw) == TYPE_DICTIONARY:
					var stored: Dictionary = stored_raw
					stored["pet_death_diarised"] = true
					gs.entity_registry[other_id] = stored

	EraLog.truth(
		"ERALIFE_PET_LIFECYCLE|stage=refresh_complete|owners=%d|resolved=%d|year=%d"
		% [
			owner_entity_ids.size(),
			resolved_count,
			int(gs.year)
		]
	)
