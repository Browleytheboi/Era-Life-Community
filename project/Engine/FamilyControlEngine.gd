extends Resource
class_name FamilyControlEngine

var gs
var last_player_id: int = -1
func _init(_gs):
	gs = _gs


func _ensure_family_contract_engine() -> bool:
	if gs == null:
		return false
	if "family_contract_engine" in gs and gs.family_contract_engine != null:
		return true
	if "family_contract_engine" in gs:
		gs.family_contract_engine = FamilyContractEngine.new(gs)
		return gs.family_contract_engine != null
	return false


func _sync_family_contract_for_control_switch(previous_player: Person, target: Person, source: String) -> void:
	if not _ensure_family_contract_engine():
		return

	if previous_player != null:
		gs.family_contract_engine.ensure_family_contract(previous_player, {
			"source": source,
			"role": "previous_controlled_actor",
			"controlled_actor_id": int(previous_player.id)
		})

	if target != null:
		gs.family_contract_engine.ensure_family_contract(target, {
			"source": source,
			"role": "target_controlled_actor",
			"controlled_actor_id": int(target.id)
		})
		gs.family_contract_engine.get_household_contract(target, {
			"source": source,
		})
		gs.family_contract_engine.build_estate_contract(target, {
			"source": source,
		})





func _repair_control_switch_bidirectional_family_links(previous_player: Person, target: Person) -> void:
	if gs == null:
		return
	if previous_player == null or target == null:
		return

	var previous_id: int = int(previous_player.id)
	var target_id: int = int(target.id)

	if previous_id <= 0 or target_id <= 0 or previous_id == target_id:
		return

	if target_id in previous_player.parents:
		if previous_id not in target.children:
			target.children.append(previous_id)

	if previous_id in target.parents:
		if target_id not in previous_player.children:
			previous_player.children.append(target_id)

	if target_id in previous_player.children:
		if previous_id not in target.parents:
			target.parents.append(previous_id)

	if previous_id in target.children:
		if target_id not in previous_player.parents:
			previous_player.parents.append(target_id)


func _control_switch_safe_dictionary(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(true)
	return {}


func _control_switch_safe_array(value: Variant) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return (value as Array).duplicate(true)
	return []


func _control_switch_actor_label(actor: Person) -> String:
	if actor == null:
		return "Unknown Life"

	var direct_name: String = str(actor.name).strip_edges() if "name" in actor else ""
	if direct_name != "":
		return direct_name

	var first_name: String = str(actor.first_name).strip_edges() if "first_name" in actor else ""
	var last_name: String = str(actor.last_name).strip_edges() if "last_name" in actor else ""
	var full_name: String = ("%s %s" % [first_name, last_name]).strip_edges()
	if full_name != "":
		return full_name

	return "Unknown Life"


func _control_switch_actor_optional_dictionary(actor: Person, property_name: String) -> Dictionary:
	if actor == null:
		return {}

	var clean_property: String = str(property_name).strip_edges()
	if clean_property == "":
		return {}

	var value: Variant = actor.get(clean_property)
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(true)

	return {}


func _control_switch_dictionary_has_power_markers(profile: Dictionary) -> bool:
	if profile.is_empty():
		return false

	if not _control_switch_safe_dictionary(profile.get("powers", {})).is_empty():
		return true
	if not _control_switch_safe_dictionary(profile.get("active_powers", {})).is_empty():
		return true
	if not _control_switch_safe_dictionary(profile.get("mutated_abilities", {})).is_empty():
		return true
	if not _control_switch_safe_dictionary(profile.get("mutation_contract_packets", {})).is_empty():
		return true
	if not _control_switch_safe_dictionary(profile.get("lineage_power_seed", {})).is_empty():
		return true
	if not _control_switch_safe_dictionary(profile.get("family_legacy", {})).is_empty():
		return true

	for array_key in ["forms", "alien_forms", "saved_identity_forms", "abilities", "spells", "subskills", "unlocked_subskills"]:
		if not _control_switch_safe_array(profile.get(array_key, [])).is_empty():
			return true

	for flag_key in ["unlocked", "active", "has_power", "birth_awakened", "configured_at_birth", "birth_power_configured", "visible_in_hub", "hub_readable_while_latent", "red_bonnet_maxed"]:
		if bool(profile.get(flag_key, false)):
			return true

	for text_key in ["power_id", "primary_power", "configured_birth_power_id", "current_form", "device_id", "bloodline", "hero_identity", "villain_identity"]:
		var text_value: String = str(profile.get(text_key, "")).strip_edges()
		if text_value != "" and text_value.to_lower() not in ["none", "unknown", "null", "unregistered"]:
			return true

	for number_key in ["ki", "battle_power", "power_level", "base_power_level", "latent_potential"]:
		if float(profile.get(number_key, 0.0)) > 0.0:
			return true

	return false


func _control_switch_power_profiles_have_visible_power(profiles: Dictionary) -> bool:
	if profiles.is_empty():
		return false

	for raw_key in profiles.keys():
		var clean_key: String = str(raw_key).strip_edges().to_lower()
		if clean_key in ["", "bending", "boxing", "wizard"]:
			continue

		var profile: Dictionary = _control_switch_safe_dictionary(profiles.get(raw_key, {}))
		if profile.is_empty():
			continue

		if _control_switch_dictionary_has_power_markers(profile):
			return true

	return false


func _control_switch_actor_has_power_truth(actor: Person) -> bool:
	if actor == null:
		return false

	if gs != null and gs.power_engine != null:
		if gs.power_engine.has_method("has_superpowers"):
			if bool(gs.power_engine.has_superpowers(actor)):
				return true

		if gs.power_engine.has_method("get_person_power_state"):
			var power_state: Dictionary = _control_switch_safe_dictionary(gs.power_engine.get_person_power_state(actor))
			if _control_switch_dictionary_has_power_markers(power_state):
				return true

	var direct_power_profile: Dictionary = _control_switch_actor_optional_dictionary(actor, "power_profile")
	if _control_switch_dictionary_has_power_markers(direct_power_profile):
		return true

	var power_profiles: Dictionary = _control_switch_actor_optional_dictionary(actor, "power_profiles")
	if _control_switch_power_profiles_have_visible_power(power_profiles):
		return true

	var person_contract: Dictionary = _control_switch_actor_optional_dictionary(actor, "person_contract")
	var contract_power_profiles: Dictionary = _control_switch_safe_dictionary(person_contract.get("power_profiles", {}))
	if _control_switch_power_profiles_have_visible_power(contract_power_profiles):
		return true

	return false


func _control_switch_actor_has_superhero_truth(actor: Person) -> bool:
	if actor == null:
		return false

	if _control_switch_actor_has_power_truth(actor):
		return true

	if gs != null and gs.superhero_engine != null and gs.superhero_engine.has_method("has_superhero_hub_access"):
		if bool(gs.superhero_engine.has_superhero_hub_access(actor)):
			return true

	var direct_profile: Dictionary = _control_switch_actor_optional_dictionary(actor, "superhero_profile")
	if bool(direct_profile.get("hub_unlocked", false)):
		return true

	var alignment: String = str(direct_profile.get("alignment", "civilian")).strip_edges().to_lower()
	if alignment != "" and alignment != "civilian":
		return true

	var registration_status: String = str(direct_profile.get("registration_status", "unregistered")).strip_edges().to_lower()
	if registration_status not in ["", "unregistered", "unknown"]:
		return true

	if bool(direct_profile.get("birth_power_configured", false)):
		return true

	return false


func _control_switch_actor_has_bending_truth(actor: Person) -> bool:
	if actor == null:
		return false

	var bending_type: String = str(actor.bending_type).strip_edges().to_lower() if "bending_type" in actor else "none"
	if bending_type != "" and bending_type != "none":
		return true

	if "bending_mastery" in actor and typeof(actor.bending_mastery) == TYPE_DICTIONARY:
		for raw_key in actor.bending_mastery.keys():
			if int(actor.bending_mastery.get(raw_key, 0)) > 0:
				return true

	return false


func _control_switch_actor_has_crown_truth(actor: Person) -> bool:
	if actor == null:
		return false

	if bool(actor.is_ruler) or bool(actor.is_royal):
		return true
	if int(actor.succession_rank) > 0 and int(actor.succession_rank) < 99:
		return true
	if str(actor.royal_title).strip_edges() != "":
		return true
	if str(actor.social_class).strip_edges().to_lower() == "royal":
		return true

	return false
func _control_switch_actor_has_boxing_truth(actor: Person) -> bool:
	if actor == null:
		return false

	if typeof(actor.boxing_profile) == TYPE_DICTIONARY:
		var profile: Dictionary = actor.boxing_profile

		if bool(profile.get("boxing_hub_unlocked", false)):
			return true
		if bool(profile.get("boxing_career_started_by_player", false)):
			return true
		if bool(profile.get("is_boxer", false)):
			return true
		if bool(profile.get("retired", false)):
			return true
		if bool(profile.get("turned_pro", false)):
			return true

		var raw_amateur: Variant = profile.get("amateur_circuit", {})
		if typeof(raw_amateur) == TYPE_DICTIONARY:
			var amateur_circuit: Dictionary = raw_amateur as Dictionary
			if bool(amateur_circuit.get("is_amateur", false)):
				return true

	if gs != null and gs.boxing_contract_engine != null and gs.boxing_contract_engine.has_method("actor_has_boxing_hub_access"):
		return bool(gs.boxing_contract_engine.actor_has_boxing_hub_access(actor))

	return false

func _emit_controlled_perspective_truth(previous_player: Person, target: Person, source: String = "family_control_engine_switch") -> void:
	if gs == null or target == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	if target.has_method("apply_power_profiles_to_legacy"):
		target.apply_power_profiles_to_legacy()

	if target.has_method("ensure_person_contract"):
		target.ensure_person_contract({
			"source": "controlled_perspective_truth",
			"controlled_actor_id": int(target.id)
		})

	if gs.power_engine != null and gs.power_engine.has_method("ensure_person_power_state"):
		gs.power_engine.ensure_person_power_state(target)

	_sync_family_contract_for_control_switch(previous_player, target, source)

	var previous_id: int = int(previous_player.id) if previous_player != null else -1
	var sequence: int = int(gs.scenario_state.get("controlled_perspective_truth_sequence", 0)) + 1
	var actor_name: String = _control_switch_actor_label(target)
	var power_available: bool = _control_switch_actor_has_power_truth(target)
	var superhero_available: bool = _control_switch_actor_has_superhero_truth(target)
	var boxing_available: bool = _control_switch_actor_has_boxing_truth(target)

	var hud_truth: Dictionary = {
		"actor_id": int(target.id),
		"actor_name": actor_name,
		"belongings": true,
		"belongings_available": true,
		"bending": _control_switch_actor_has_bending_truth(target),
		"crown": _control_switch_actor_has_crown_truth(target),
		"boxing": boxing_available,
		"boxing_available": boxing_available,
		"superhero": superhero_available,
		"superpower": superhero_available,
		"power": power_available,
		"wizard": false
	}

	var packet: Dictionary = {
		"schema": "eralife.controlled_perspective_truth",
		"version": 1,
		"sequence": sequence,
		"source": source,
		"previous_actor_id": previous_id,
		"actor_id": int(target.id),
		"actor_name": actor_name,
		"camera_model": "persistent_identity_lens",
		"ui_rule": "render_huds_from_current_controlled_identity",
		"current_panel": "life",
		"hud_truth": hud_truth.duplicate(true),
		"emitted_at_ms": int(Time.get_ticks_msec())
	}

	gs.scenario_state ["controlled_perspective_truth"] = packet.duplicate(true)
	gs.scenario_state ["controlled_perspective_truth_sequence"] = sequence
	gs.scenario_state ["controlled_perspective_switch_pending_ui_refresh"] = true
	gs.scenario_state ["controlled_perspective_actor_id"] = int(target.id)
	gs.scenario_state ["controlled_perspective_actor_name"] = actor_name
	gs.scenario_state ["controlled_perspective_source"] = source
	gs.scenario_state ["runtime_hud_visibility_snapshot"] = {
		"player_id": int(target.id),
		"controlled_actor_id": int(target.id),
		"controlled_actor_name": actor_name,
		"current_panel": "life",
		"belongings_available": true,
		"bending_available": bool(hud_truth.get("bending", false)),
		"crown_available": bool(hud_truth.get("crown", false)),
		"boxing_available": boxing_available,
		"superpower_available": superhero_available,
		"power_available": power_available,
		"wizard_available": false,
		"reason": source,
		"updated_at_ms": int(Time.get_ticks_msec())
	}
	gs.scenario_state ["runtime_hud_visibility_snapshot_reason"] = source
	gs.scenario_state ["runtime_hud_visibility_snapshot_at_ms"] = int(Time.get_ticks_msec())
func _emit_controlled_perspective_truth_fast(
	previous_player: Person,
	target: Person,
	source: String = "family_control_engine_switch_fast"
) -> void:
	if (
		gs == null
		or target == null
	):
		return

	if typeof(
		gs.scenario_state
	) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var previous_id: int = (
		int(
			previous_player.id
		)
		if previous_player != null
		else -1
	)
	var sequence: int = int(
		gs.scenario_state.get(
			"controlled_perspective_truth_sequence",
			0
		)
	) + 1
	var actor_name: String = _control_switch_actor_label(
		target
	)
	var actor_alive: bool = (
		bool(
			target.alive
		)
		and float(
			target.health
		) > 0.0
	)
	var power_available: bool = (
		_control_switch_actor_has_power_truth(
			target
		)
	)
	var superhero_available: bool = (
		_control_switch_actor_has_superhero_truth(
			target
		)
	)
	var boxing_available: bool = (
		_control_switch_actor_has_boxing_truth(
			target
		)
	)
	var belongings_available: bool = actor_alive
	var rick_weapon_shop_available: bool = (
		actor_alive
		and int(
			target.age
		) >= 16
	)
	var hud_truth: Dictionary = {
		"actor_id": int(
			target.id
		),
		"actor_name": actor_name,
		"belongings": belongings_available,
		"belongings_available": belongings_available,
		"belongings_button_visible": belongings_available,
		"bending": (
			_control_switch_actor_has_bending_truth(
				target
			)
		),
		"crown": _control_switch_actor_has_crown_truth(
			target
		),
		"rick_weapon_shop_available": (
			rick_weapon_shop_available
		),
		"rick_weapon_shop_button_visible": (
			rick_weapon_shop_available
		),
		"boxing": boxing_available,
		"boxing_available": boxing_available,
		"boxing_button_visible": boxing_available,
		"superhero": superhero_available,
		"superpower": superhero_available,
		"superpower_available": superhero_available,
		"superpower_button_visible": superhero_available,
		"power": power_available,
		"power_available": power_available,
		"power_button_visible": power_available,
		"wizard": false,
		"wizard_available": false,
		"wizard_button_visible": false
	}
	var packet: Dictionary = {
		"schema": "eralife.controlled_perspective_truth",
		"version": 2,
		"sequence": sequence,
		"source": source,
		"previous_actor_id": previous_id,
		"actor_id": int(
			target.id
		),
		"actor_name": actor_name,
		"camera_model": "persistent_identity_lens",
		"ui_rule": "render_huds_from_current_controlled_identity",
		"current_panel": "life",
		"hud_truth": hud_truth.duplicate(false),
		"emitted_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	gs.scenario_state [
		"controlled_perspective_truth"
	] = packet.duplicate(false)
	gs.scenario_state [
		"controlled_perspective_truth_sequence"
	] = sequence
	gs.scenario_state [
		"controlled_perspective_switch_pending_ui_refresh"
	] = true
	gs.scenario_state [
		"controlled_perspective_actor_id"
	] = int(
		target.id
	)
	gs.scenario_state [
		"controlled_perspective_actor_name"
	] = actor_name
	gs.scenario_state [
		"controlled_perspective_source"
	] = source
	gs.scenario_state [
		"runtime_hud_visibility_snapshot"
	] = {
		"player_id": int(
			target.id
		),
		"actor_id": int(
			target.id
		),
		"controlled_actor_id": int(
			target.id
		),
		"controlled_actor_name": actor_name,
		"current_panel": "life",
		"belongings_available": belongings_available,
		"belongings_button_visible": belongings_available,
		"bending_available": bool(
			hud_truth.get(
				"bending",
				false
			)
		),
		"bending_button_visible": bool(
			hud_truth.get(
				"bending",
				false
			)
		),
		"crown_available": bool(
			hud_truth.get(
				"crown",
				false
			)
		),
		"crown_button_visible": bool(
			hud_truth.get(
				"crown",
				false
			)
		),
		"rick_weapon_shop_available": (
			rick_weapon_shop_available
		),
		"rick_weapon_shop_button_visible": (
			rick_weapon_shop_available
		),
		"boxing_available": boxing_available,
		"boxing_button_visible": boxing_available,
		"superhero_available": superhero_available,
		"superpower_available": superhero_available,
		"superpower_button_visible": superhero_available,
		"power_available": power_available,
		"power_button_visible": power_available,
		"wizard_available": false,
		"wizard_button_visible": false,
		"reason": source,
		"updated_at_ms": int(
			Time.get_ticks_msec()
		)
	}
	gs.scenario_state [
		"runtime_hud_visibility_snapshot_reason"
	] = source
	gs.scenario_state [
		"runtime_hud_visibility_snapshot_at_ms"
	] = int(
		Time.get_ticks_msec()
	)
func switch_to_character(npc: Person):
	if npc == null:
		return false
	if gs == null:
		return false

	var target_id: int = int(npc.id)
	if target_id <= 0:
		return false

	var target: Person = null
	if gs.has_method("get_npc_by_id"):
		target = gs.get_npc_by_id(target_id)

	if target == null:
		target = npc

	if target == null and gs.has_method("get_or_reactivate_npc_by_id"):
		target = gs.get_or_reactivate_npc_by_id(target_id)

	if target == null:
		return false
	if not target.alive:
		return false

	var previous_player: Person = gs.player
	var previous_id: int = int(previous_player.id) if previous_player != null else -1

	if previous_player != null and int(previous_player.id) == int(target.id):
		return true

	if gs.has_method("register_controlled_character") and previous_id > 0:
		gs.register_controlled_character(previous_id)

	gs.player = target
	gs.player_id = target.id
	last_player_id = previous_id

	if gs.has_method("register_controlled_character"):
		gs.register_controlled_character(target.id)

	_emit_controlled_perspective_truth_fast(previous_player, target, "family_control_engine_switch_to_character_fast")

	call_deferred(
		"_finish_control_switch_integrity_sync_deferred",
		previous_player,
		target,
		previous_id
	)

	return true
func _finish_control_switch_integrity_sync_deferred(previous_player: Person, target: Person, previous_id: int) -> void:
	if gs == null:
		return
	if target == null:
		return
	if not target.alive:
		return
	if gs.player == null or int(gs.player.id) != int(target.id):
		return

	var previous_fame_state: Dictionary = {}
	var target_fame_state: Dictionary = {}

	if gs.fame_engine != null:
		previous_fame_state = gs.fame_engine.snapshot_public_fame_state(previous_player)
		target_fame_state = gs.fame_engine.snapshot_public_fame_state(target)

	_repair_control_switch_bidirectional_family_links(previous_player, target)

	if target.has_method("apply_power_profiles_to_legacy"):
		target.apply_power_profiles_to_legacy()

	if target.has_method("ensure_person_contract"):
		target.ensure_person_contract({
			"source": "family_control_engine_switch_to_character_deferred_integrity",
			"controlled_actor_id": int(target.id),
			"previous_controlled_actor_id": previous_id
		})

	if gs.power_engine != null and gs.power_engine.has_method("ensure_person_power_state"):
		gs.power_engine.ensure_person_power_state(target)

	if gs.npc_factory != null:
		gs.npc_factory.ensure_family_lineage(target)

	_sync_family_contract_for_control_switch(previous_player, target, "family_control_engine_switch_to_character_deferred_integrity")

	if gs.royalty_engine != null and gs.royalty_engine.has_method("setup_seed_royal_house"):
		var should_sync_royal_house: bool = bool(target.is_ruler) or bool(target.is_royal)
		should_sync_royal_house = should_sync_royal_house or str(target.royal_title).strip_edges() != ""
		should_sync_royal_house = should_sync_royal_house or str(target.social_class).strip_edges() == "Royal"

		if not should_sync_royal_house and gs.realm_engine != null and int(target.realm_id) > 0 and gs.realm_engine.realms.has(int(target.realm_id)):
			var realm_raw: Variant = gs.realm_engine.realms.get(int(target.realm_id), {})
			var realm: Dictionary = realm_raw if typeof(realm_raw) == TYPE_DICTIONARY else {}
			should_sync_royal_house = int(realm.get("ruler_id", -1)) == int(target.id)

		var already_has_crown_identity: bool = (
			bool(target.is_ruler)
			or bool(target.is_royal)
			or int(target.succession_rank) > 0
			or str(target.royal_title).strip_edges() != ""
		)

		if should_sync_royal_house and not already_has_crown_identity:
			gs.royalty_engine.setup_seed_royal_house(target)

	gs.get_valid_partner(target, true, true)
	if previous_player != null:
		gs.get_valid_partner(previous_player, true, true)


	if gs.career_engine != null:
		gs.career_engine.sync_or_seed_existing_job_state(target)

	_repair_family_age_stack(target)
	sync_player_household_cluster_locations(target, false)

	if gs.fame_engine != null:
		gs.fame_engine.restore_public_fame_state(target, target_fame_state)
		gs.fame_engine.restore_public_fame_state(previous_player, previous_fame_state)

	_emit_controlled_perspective_truth(previous_player, target, "family_control_engine_switch_to_character_deferred_integrity")

	if gs.has_method("_ensure_loaded_player_lineage"):
		gs._ensure_loaded_player_lineage()

	if gs.has_method("_soft_unload_npcs"):
		gs._soft_unload_npcs()

func _repair_family_age_stack(root: Person) -> void:
	if root == null:
		return
	if not root.alive:
		return

	var frontier: Array = [root]
	var visited:= {}
	var depth:= 0
	while depth < 3 and not frontier.is_empty():
		var next_frontier: Array = []
		for person in frontier:
			if person == null:
				continue
			if not person.alive:
				continue
			if visited.has(person.id):
				continue
			visited [person.id] = true

			var parent_ids: Array = []
			if gs.has_method("get_npc_facts_by_id"):
				var facts: Dictionary = gs.get_npc_facts_by_id(int(person.id))
				if not facts.is_empty():
					parent_ids = facts.get("parents", [])
			if parent_ids.is_empty():
				parent_ids = person.parents

			for pid in parent_ids:
				var parent_facts: Dictionary = {}
				if gs.has_method("get_npc_facts_by_id"):
					parent_facts = gs.get_npc_facts_by_id(int(pid))
				if not parent_facts.is_empty() and not bool(parent_facts.get("alive", true)):
					continue

				var parent: Person = gs.get_or_reactivate_npc_by_id(int(pid))
				if parent == null:
					continue
				if not parent.alive:
					continue

				_repair_parent_age_against_child(parent, person)
				next_frontier.append(parent)

		frontier = next_frontier
		depth += 1


func _repair_parent_age_against_child(parent: Person, child: Person) -> void:
	if parent == null or child == null:
		return
	if not child.alive:
		return
	if not parent.alive:
		return

	var minimum_parent_age:= int(child.age) + 16
	var preferred_parent_age:= int(child.age) + 28
	if int(parent.age) < minimum_parent_age:
		parent.age = preferred_parent_age

	if int(parent.age) >= 95:
		parent.alive = false
		parent.health = 0
		parent.cause_of_death = "Old age"
	elif int(parent.age) >= 88 and parent.alive:
		parent.alive = false
		parent.health = 0
		parent.cause_of_death = "Old age"
func yearly_household_cluster_sync(_payload:= {}) -> void:
	if gs == null or gs.player == null:
		return
	sync_player_household_cluster_locations(gs.player, false)

func _resolve_household_location_anchor(anchor: Person) -> Person:
	if anchor == null:
		return null
	if not anchor.alive:
		return anchor

	if _ensure_family_contract_engine():
		var household_contract: Dictionary = gs.family_contract_engine.get_household_contract(anchor, {
			"source": "family_control_engine_resolve_household_location_anchor"
		})
		var location_anchor_id: int = int(household_contract.get("location_anchor_id", int(anchor.id)))
		if location_anchor_id > 0:
			var location_anchor: Person = gs.get_or_reactivate_npc_by_id(location_anchor_id)
			if location_anchor != null:
				return location_anchor

	if int(anchor.age) >= 18:
		return anchor

	var custodial_adult: Person = _find_custodial_adult_for(anchor)
	if custodial_adult != null:
		return custodial_adult

	return anchor

func _find_custodial_adult_for(anchor: Person) -> Person:
	if anchor == null:
		return null

	if _ensure_family_contract_engine():
		return gs.family_contract_engine.get_custodial_adult(anchor, {
			"source": "family_control_engine_find_custodial_adult"
		})

	return null
func is_minor_under_custodial_authority(npc: Person) -> bool:
	if npc == null:
		return false
	if not npc.alive:
		return false

	if _ensure_family_contract_engine():
		return gs.family_contract_engine.is_minor_under_authority(npc, {
			"source": "family_control_engine_minor_authority_query"
		})

	return false
func is_in_player_household_cluster(npc: Person) -> bool:
	if gs == null or gs.player == null or npc == null:
		return false
	if not gs.player.alive:
		return false

	var household_members: Array = _collect_household_cluster(gs.player)
	for member in household_members:
		if member != null and int(member.id) == int(npc.id):
			return true

	return false

func sync_player_household_cluster_locations(anchor: Person, emit_move_events:= false) -> void:
	if gs == null or anchor == null:
		return
	if not anchor.alive:
		return

	var household_contract: Dictionary = {}
	if _ensure_family_contract_engine():
		household_contract = gs.family_contract_engine.get_household_contract(anchor, {
			"source": "family_control_engine_sync_household_cluster_locations",
			"emit_move_events": emit_move_events
		})

	var location_anchor: Person = _resolve_household_location_anchor(anchor)
	if location_anchor == null:
		return
	if not location_anchor.alive:
		return

	var household_members: Array = _collect_household_cluster(anchor)
	if household_members.is_empty():
		return

	var location: Dictionary = _control_switch_safe_dictionary(household_contract.get("location", {}))
	var rules: Dictionary = _control_switch_safe_dictionary(household_contract.get("rules", {}))
	var target_realm_id: int = int(location.get("realm_id", int(location_anchor.realm_id)))
	var target_city: String = str(location.get("city", location_anchor.home_city))
	var target_country: String = str(location.get("country", location_anchor.home_country))
	var royal_household_locked: bool = bool(rules.get("royal_bound", false))

	if int(anchor.age) <= 1 and int(anchor.age) < 18 and location_anchor != anchor and not royal_household_locked:
		return

	if target_city == "" and target_country == "":
		return

	var household_summary_needed: bool = false
	for raw_member in household_members:
		var member: Person = raw_member
		if member == null:
			continue
		if not member.alive:
			continue
		if int(member.id) == int(location_anchor.id):
			continue

		var location_changed:= false
		if target_realm_id > 0 and int(member.realm_id) != target_realm_id:
			member.realm_id = target_realm_id
			location_changed = true
		if member.home_city != target_city:
			member.home_city = target_city
			location_changed = true
		if member.home_country != target_country:
			member.home_country = target_country
			location_changed = true
		if not location_changed:
			continue

		if emit_move_events and gs.event_bus != null:
			if int(anchor.age) < 18 and int(location_anchor.age) >= 18:
				household_summary_needed = true
			else:
				gs.event_bus.emit(ActionEventTypes.NPC_MOVED, {
					"npc_id": member.id,
					"text": "%s moved with the household to %s, %s." % [
						member.first_name,
						target_city,
						target_country
					],
					"source": "family_control_engine",
					"suppress_world_feed": true,
					"show_move_in_world_feed": false
				})

		if gs.chunk_simulation_engine != null:
			gs.chunk_simulation_engine.remove_npc(member)
		if gs.world_space_engine != null:
			gs.world_space_engine.move_npc(member)
		if gs.chunk_simulation_engine != null:
			gs.chunk_simulation_engine.assign_npc(member)

	if household_summary_needed and emit_move_events and gs.event_bus != null:
		gs.event_bus.emit(ActionEventTypes.NPC_MOVED, {
			"npc_id": anchor.id,
			"text": _format_household_move_text(anchor, location_anchor, target_city, target_country),
			"source": "family_control_engine",
			"suppress_world_feed": true,
			"show_move_in_world_feed": false
		})

	if _ensure_family_contract_engine():
		gs.family_contract_engine.rebuild_family_contract_cluster(anchor, {
			"source": "family_control_engine_after_household_location_sync"
		})

func _collect_household_cluster(anchor: Person) -> Array:
	var result: Array = []
	if anchor == null:
		return result

	if _ensure_family_contract_engine():
		return gs.family_contract_engine.get_household_members(anchor, {
			"source": "family_control_engine_collect_household_cluster"
		})

	if anchor.alive:
		result.append(anchor)

	return result

func _format_household_move_text(anchor: Person, location_anchor: Person, target_city: String, target_country: String) -> String:
	var place_text: String = ""
	if target_city != "" and target_country != "":
		place_text = "%s, %s" % [target_city, target_country]
	elif target_city != "":
		place_text = target_city
	elif target_country != "":
		place_text = target_country
	else:
		place_text = "a new place"
	if anchor != null and int(anchor.age) < 18 and location_anchor != null and int(location_anchor.age) >= 18:
		return "My parents moved us through %s." % place_text
	return "Our household moved through %s." % place_text
func handle_spousal_estate_inheritance(payload) -> void:
	if gs == null:
		return

	var dead_npc: Person = _resolve_estate_dead_npc_from_payload(payload)
	if dead_npc == null:
		return

	var explicit_heir: Person = _resolve_explicit_estate_heir_from_payload(payload)

	if _ensure_family_contract_engine():
		gs.family_contract_engine.execute_estate_contract(dead_npc, explicit_heir, {
			"source": "family_control_engine_handle_spousal_estate_inheritance",
			"payload": _control_switch_safe_dictionary(payload) if typeof(payload) == TYPE_DICTIONARY else {}
		})
		return
func _resolve_estate_dead_npc_from_payload(payload) -> Person:
	if payload is Person:
		return payload
	if typeof(payload) == TYPE_DICTIONARY:
		var npc_id: int = int(payload.get("npc_id", -1))
		if npc_id > 0:
			var resolved: Person = gs.get_or_reactivate_npc_by_id(int(npc_id))
			if resolved != null:
				return resolved
		var embedded_npc = payload.get("npc", null)
		if embedded_npc is Person:
			return embedded_npc
		var embedded_value = payload.get("value", null)
		if embedded_value is Person:
			return embedded_value
	return null

func _resolve_explicit_estate_heir_from_payload(payload) -> Person:
	if typeof(payload) != TYPE_DICTIONARY:
		return null
	var explicit_heir_id: int = int(payload.get("explicit_heir_id", payload.get("heir_id", -1)))
	if explicit_heir_id <= 0 and typeof(payload.get("data", null)) == TYPE_DICTIONARY:
		var data: Dictionary = payload.get("data", {})
		explicit_heir_id = int(data.get("explicit_heir_id", data.get("heir_id", -1)))
	if explicit_heir_id <= 0:
		return null
	return gs.get_or_reactivate_npc_by_id(explicit_heir_id)

func _resolve_preferred_estate_heir(dead_npc: Person, explicit_heir: Person = null) -> Person:
	if dead_npc == null:
		return null
	if explicit_heir != null and explicit_heir.alive:
		return explicit_heir
	var spouse: Person = gs.get_valid_partner(dead_npc, true)
	if spouse != null and spouse.alive:
		return spouse
	for cid in dead_npc.children:
		var child: Person = gs.get_or_reactivate_npc_by_id(int(cid))
		if child != null and child.alive:
			return child
	return null

func _transfer_estate_bucket(bucket: Dictionary, from_id: int, to_id: int) -> void:
	if typeof(bucket) != TYPE_DICTIONARY:
		return
	if not bucket.has(from_id):
		return
	var moved_value = bucket [from_id]
	if bucket.has(to_id) and typeof(bucket [to_id]) == TYPE_ARRAY and typeof(moved_value) == TYPE_ARRAY:
		var combined: Array = bucket [to_id].duplicate()
		for item in moved_value:
			combined.append(item)
		bucket [to_id] = combined
	else:
		bucket [to_id] = moved_value
	bucket.erase(from_id)




func get_family_members() -> Array:

	var result:= []
	var visited:= {}

	_collect_relatives(gs.player.id, result, visited)

	return result


func _collect_relatives(id, result, visited):

	if visited.has(id):
		return

	visited [id] = true

	var facts = gs.get_npc_facts_by_id(int(id))
	if facts == {}:
		return

	var p = gs.get_or_reactivate_npc_by_id(int(id))
	if p != null and p.alive:
		result.append(p)

	for parent in facts.get("parents", []):
		_collect_relatives(int(parent), result, visited)

	for child in facts.get("children", []):
		_collect_relatives(int(child), result, visited)
func switch_to_character_by_id(npc_id: int) -> bool:
	var npc = gs.get_or_reactivate_npc_by_id(npc_id)

	if npc == null:
		return false
	if not npc.alive:
		return false

	return switch_to_character(npc)



func get_nearby_strangers(limit: int = 60) -> Array:
	var out: Array = []
	if gs == null or gs.player == null:
		return out

	var player: Person = gs.player
	var candidates: Array = []

	for npc in gs.npcs:
		if npc == null:
			continue
		if not _is_valid_nearby_switch_candidate(player, npc):
			continue
		candidates.append({
			"npc": npc,
			"distance": gs._world_distance_to_player(npc)
		})

	candidates.sort_custom(func (a, b): return int(a.get("distance", 999999)) < int(b.get("distance", 999999)))

	var count: int = min(limit, candidates.size())
	for i in range(count):
		out.append(candidates [i].get("npc"))

	return out

func _is_valid_nearby_switch_candidate(player: Person, npc: Person) -> bool:
	if player == null or npc == null:
		return false
	if npc.id == player.id:
		return false
	if not npc.alive:
		return false


	if npc.id == last_player_id:
		return true

	if npc.id in player.parents:
		return false
	if npc.id in player.children:
		return false
	if npc.id in player.friends:
		return false
	if npc.id in player.ex_partners:
		return false
	if player.partner != null and player.partner.id == npc.id:
		return false
	if player.parents.size() > 0 and npc.parents == player.parents:
		return false
	if _is_ancestor_of_player(npc.id):
		return false
	if _is_school_connected_to_player(player, npc):
		return false

	return true

func _is_school_connected_to_player(player: Person, npc: Person) -> bool:
	if gs == null or gs.school_engine == null:
		return false
	if player == null or npc == null:
		return false

	gs.school_engine.sync_person_school_fields(player)
	gs.school_engine.sync_person_school_fields(npc)

	if gs.school_engine.are_classmates(player, npc):
		return true

	for teacher in gs.school_engine.get_teachers_for(player):
		if teacher != null and teacher.id == npc.id:
			return true

	return false

func _is_ancestor_of_player(target_id: int) -> bool:
	if gs == null or gs.player == null or target_id <= 0:
		return false

	var frontier: Array = gs.player.parents.duplicate()
	var visited:= {}

	while frontier.size() > 0:
		var next_frontier: Array = []
		for pid in frontier:
			var ancestor_id:= int(pid)
			if ancestor_id <= 0:
				continue
			if visited.has(ancestor_id):
				continue
			visited [ancestor_id] = true

			if ancestor_id == target_id:
				return true

			var facts: Dictionary = gs.get_npc_facts_by_id(ancestor_id)
			for gpid in facts.get("parents", []):
				next_frontier.append(int(gpid))
		frontier = next_frontier

	return false