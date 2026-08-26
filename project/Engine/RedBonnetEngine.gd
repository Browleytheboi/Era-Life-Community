extends Resource
class_name RedBonnetEngine

const CONTRACT_SCHEMA:= "eralife.red_bonnet_contract"
const CONTRACT_VERSION:= 1
const STATE_SCHEMA:= "eralife.red_bonnet_state"
const STATE_KEY:= "red_bonnet_state"
const MAX_CONTRACT_LEDGER:= 240
const MAX_REWRITE_LEDGER:= 240

var gs
var active_contract: Dictionary = {}
var last_contract_resolution: Dictionary = {}
var last_rewrite_report: Dictionary = {}

func _init(_gs, contract: Dictionary = {}) -> void:
	gs = _gs
	set_contract(contract)




var BONNET = {
	"name": "Red Bonnet",
	"rarity": "Mythic",
	"lore": "A legendary bonnet said to bend fate, wealth, and bloodlines.",
}


var owner_id = -1




func set_contract(contract: Dictionary = {}) -> Dictionary:
	active_contract = _default_contract()
	if typeof(contract) == TYPE_DICTIONARY and not contract.is_empty():
		active_contract = _merge_dict(active_contract, contract)

	var report: Dictionary = {
		"success": true,
		"schema": "eralife.red_bonnet_contract_set_report",
		"version": CONTRACT_VERSION,
		"contract_id": str(active_contract.get("id", "red_bonnet.core")),
		"authority": str(active_contract.get("authority", "reality")),
		"artifact_class": str(active_contract.get("artifact_class", "mythic_artifact")),
		"bounded_reality": bool(active_contract.get("bounded_reality", true)),
		"capabilities": _safe_array(active_contract.get("capabilities", [])),
		"composition_stack": _safe_array(active_contract.get("composition_stack", [])),
		"updated_at_ms": int(Time.get_ticks_msec())
	}
	last_contract_resolution = report.duplicate(true)
	return report


func bootstrap_default_contracts() -> Dictionary:
	var state: Dictionary = _world_state()
	state ["active_contract"] = active_contract.duplicate(true)
	state ["owner_id"] = int(owner_id)
	_commit_world_state(state)
	return {
		"success": true,
		"schema": "eralife.red_bonnet_bootstrap_report",
		"version": CONTRACT_VERSION,
		"contract_id": str(active_contract.get("id", "red_bonnet.core")),
		"bootstrapped_at_ms": int(Time.get_ticks_msec())
	}


func export_contract() -> Dictionary:
	return active_contract.duplicate(true)


func export_state() -> Dictionary:
	return {
		"schema": STATE_SCHEMA,
		"version": CONTRACT_VERSION,
		"save_key": STATE_KEY,
		"persistent": true,
		"backwards_compatible": true,
		"preserve_unknown_fields": true,
		"owner_id": int(owner_id),
		"active_contract": active_contract.duplicate(true),
		"world_state": _world_state().duplicate(true),
		"last_contract_resolution": last_contract_resolution.duplicate(true),
		"last_rewrite_report": last_rewrite_report.duplicate(true),
		"exported_at_ms": int(Time.get_ticks_msec())
	}


func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "RedBonnetEngine import_state expected Dictionary."
		}

	owner_id = int(data.get("owner_id", owner_id))

	var contract_raw: Variant = data.get("active_contract", {})
	if typeof(contract_raw) == TYPE_DICTIONARY:
		active_contract = _merge_dict(_default_contract(), contract_raw as Dictionary)
	else:
		active_contract = _default_contract()

	var world_state_raw: Variant = data.get("world_state", {})
	if typeof(world_state_raw) == TYPE_DICTIONARY:
		_commit_world_state(_normalize_state(world_state_raw as Dictionary))

	var last_resolution_raw: Variant = data.get("last_contract_resolution", {})
	if typeof(last_resolution_raw) == TYPE_DICTIONARY:
		last_contract_resolution = (last_resolution_raw as Dictionary).duplicate(true)

	var last_rewrite_raw: Variant = data.get("last_rewrite_report", {})
	if typeof(last_rewrite_raw) == TYPE_DICTIONARY:
		last_rewrite_report = (last_rewrite_raw as Dictionary).duplicate(true)

	return {
		"success": true,
		"schema": "eralife.red_bonnet_import_report",
		"version": CONTRACT_VERSION,
		"owner_id": int(owner_id),
		"contract_id": str(active_contract.get("id", "red_bonnet.core")),
		"imported_at_ms": int(Time.get_ticks_msec())
	}




func yearly_spawn_check():

	if owner_id != -1:
		return

	if randi() % 1000000 != 0:
		return

	var candidates = []

	for npc in gs.npcs:
		if npc.alive and npc.age >= 18:
			candidates.append(npc)

	if candidates.size() == 0:
		return

	var holder = candidates [randi() % candidates.size()]
	_give_bonnet(holder)

func give_to_npc(npc: Person, context: Dictionary = {}) -> void:
	if npc == null:
		return
	_give_bonnet(npc, context)




func _give_bonnet(npc: Person, context: Dictionary = {}) -> void:
	if npc == null:
		return

	var is_player_birth_grant: bool = false
	if gs != null and gs.player != null:
		is_player_birth_grant = int(npc.id) == int(gs.player.id) and int(npc.age) <= 0

	var birth_shell_active: bool = false
	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		birth_shell_active = bool(gs.scenario_state.get("birth_shell_first_boot_active", false)) or bool(gs.scenario_state.get("post_spawn_ui_finalize_pending", false))

	var resolution_payload: Dictionary = context.duplicate(true)
	resolution_payload ["source"] = str(resolution_payload.get("source", "red_bonnet_engine"))
	resolution_payload ["event_type"] = str(resolution_payload.get("event_type", "red_bonnet_grant"))
	resolution_payload ["target_id"] = int(npc.id)
	resolution_payload ["grant"] = true

	if is_player_birth_grant or birth_shell_active:
		resolution_payload ["birth_loadout"] = true
		resolution_payload ["defer_reality_routing"] = true
		resolution_payload ["suppress_reality_orchestration"] = true
		resolution_payload ["suppress_belongings_myth"] = true
		resolution_payload ["suppress_player_ui_interpretation"] = true
		resolution_payload ["suppress_life_diary"] = true

	var grant_resolution: Dictionary = _red_bonnet_resolve_effect(npc, "identity_binding", resolution_payload)
	if not bool(grant_resolution.get("allowed", false)):
		return

	owner_id = npc.id
	if not "RedBonnetBearer" in npc.traits:
		npc.traits.append("RedBonnetBearer")

	var granted_new_bonnet: bool = false
	if gs.belongings_engine != null and not gs.belongings_engine.has_item_named(npc, "Artifacts", "Red Bonnet"):
		var bonnet_item_id: int = gs.next_id
		gs.next_id += 1
		gs.belongings_engine.add_item(npc, {
			"id": bonnet_item_id,
			"name": "Red Bonnet",
			"display_name": "Red Bonnet",
			"type": "Artifact",
			"contract_id": "red_bonnet",
			"rarity": str(BONNET.get("rarity", "Mythic")),
			"lore": str(BONNET.get("lore", "")),
			"ability": "Turns the wearer into a mythical legend, unlocks Avatar-level power, boosts major stats, enables reality wishes, and can summon all 7 Dragon Balls.",
			"color": "red",
			"origin_era": gs.era.name,
			"acquired_year": gs.year,
			"identity": {
				"type": "mythic_artifact",
				"authority": str(active_contract.get("authority", "reality")),
				"alignment": "fate_bloodline_wish",
				"contract_id": str(active_contract.get("id", "red_bonnet.core")),
				"contract_schema": CONTRACT_SCHEMA,
				"bounded_reality": bool(active_contract.get("bounded_reality", true))
			},
			"affordances": _safe_array(active_contract.get("capabilities", [])).duplicate(true),
			"relationships": {
				"owned_by": int(npc.id),
				"owner_name": "%s %s" % [str(npc.first_name), str(npc.last_name)],
				"recognition": "heaven_sent_mythic_artifact",
				"ownership_type": "reality_bound_artifact",
				"contract_authority": str(active_contract.get("authority", "reality"))
			},
			"red_bonnet_contract": export_contract()
		}, "Artifacts")
		granted_new_bonnet = true

	_apply_bonnet_power(npc)

	if not granted_new_bonnet:
		return

	var world_text: String = "\n\n %s %s has discovered The Legendary RED BONNET. Some say it came from HEAVEN." % [npc.first_name, npc.last_name]
	var diary_text:= "I have discovered The Legendary RED BONNET. Some say it came from HEAVEN."

	if is_player_birth_grant:
		world_text = "\n\n %s %s was born under The Legendary RED BONNET. Some say it came from HEAVEN." % [npc.first_name, npc.last_name]
		diary_text = ""

	gs.push_world_feed(
		world_text,
		{
			"npc_id": npc.id,
			"personally_relevant": npc == gs.player,
			"suppress_diary": true,
			"category": "artifact",
			"event_name": "red_bonnet_birth_loadout" if is_player_birth_grant else "red_bonnet_acquired",
			"source": "red_bonnet_engine",
			"contract_id": "red_bonnet",
			"red_bonnet_contract_id": str(active_contract.get("id", "red_bonnet.core")),
			"mythic_rank": "mythic",
			"bounded_reality": true,
			"contract_resolution": grant_resolution.duplicate(true)
		}
	)

	if diary_text != "" and gs.narrative_engine != null and npc == gs.player:
		gs.narrative_engine.log_event(npc, {
			"type": "text",
			"text": diary_text
		})

	if diary_text != "" and npc.memories != null and not npc.memories.has(diary_text):
		npc.memories.append(diary_text)

	_red_bonnet_commit_bounded_rewrite(npc, "identity_binding", grant_resolution, {
		"result_text": world_text,
		"diary_text": diary_text,
		"mythic_rank": "mythic",
		"event_type": "red_bonnet_identity_bound",
		"birth_loadout": is_player_birth_grant,
		"defer_reality_routing": bool(resolution_payload.get("defer_reality_routing", false)),
		"suppress_reality_orchestration": bool(resolution_payload.get("suppress_reality_orchestration", false)),
		"suppress_belongings_myth": bool(resolution_payload.get("suppress_belongings_myth", false))
	})




func _apply_bonnet_power(npc):
	if npc == null:
		return

	if not "Immortal" in npc.traits:
		npc.traits.append("Immortal")

	npc.health = max(int(npc.health), 200)
	npc.mental_health = max(int(npc.mental_health), 200)
	npc.satisfaction = max(int(npc.satisfaction), 200)
	npc.smarts = max(int(npc.smarts), 200)
	npc.looks = max(int(npc.looks), 200)
	npc.bank_balance = max(float(npc.bank_balance), 1000000000000)

	if typeof(npc.bending_mastery) != TYPE_DICTIONARY:
		npc.bending_mastery = {}
	if typeof(npc.bending_latent_potential) != TYPE_DICTIONARY:
		npc.bending_latent_potential = {}

	var original_bending_type: String = str(npc.bending_type).strip_edges().to_lower()
	var elements_to_max: Array = _red_bonnet_bending_elements_to_max(npc)

	for element in elements_to_max:
		var clean_element: String = str(element).strip_edges().to_lower()
		if clean_element == "":
			continue
		var realized_level: int = _red_bonnet_realized_bending_level(npc, clean_element)
		npc.bending_mastery [clean_element] = realized_level
		npc.bending_latent_potential [clean_element] = max(int(npc.bending_latent_potential.get(clean_element, 0)), realized_level)

	if original_bending_type == "avatar":
		npc.avatar_state_unlocked = true
		npc.avatar_state_used = false
		if gs != null and gs.bending_engine != null and gs.bending_engine.has_method("_check_avatar_state"):
			gs.bending_engine._check_avatar_state(npc)
	else:
		npc.avatar_state_unlocked = bool(npc.avatar_state_unlocked)
		npc.avatar_state_used = bool(npc.avatar_state_used)

	if gs != null and gs.capability_graph_engine != null:
		gs.capability_graph_engine.refresh_bending_capabilities(npc)

	if gs != null and "power_engine" in gs and gs.power_engine != null and gs.power_engine.has_method("maximize_power_state_to_latent_potential"):
		gs.power_engine.maximize_power_state_to_latent_potential(npc, {
			"source": "red_bonnet_identity_binding",
		})

	_red_bonnet_apply_willpower_and_imagination(npc)

	npc.fame = max(int(npc.fame), 100)
	npc.fame_tier = "Legend"
	npc.social_class = "Mythic"

	if gs != null and gs.dynasty_legacy_engine != null:
		gs.dynasty_legacy_engine.add_reputation(npc, 250)

	var memory_text: String = "The Red Bonnet bound itself to my life and pushed my existing gifts to mythic limits."
	if original_bending_type == "avatar":
		memory_text = "The Red Bonnet maxed out my Avatar State and every element I carried."
	elif original_bending_type in ["air", "water", "earth", "fire"]:
		memory_text = "The Red Bonnet maxed out my %s bending without rewriting me into the Avatar." % original_bending_type.capitalize()

	if npc.memories != null and not npc.memories.has(memory_text):
		npc.memories.append(memory_text)
func _red_bonnet_realized_bending_level(npc: Person, element: String) -> int:
	var clean_element: String = str(element).strip_edges().to_lower()
	var current_level: int = 0
	if npc != null and typeof(npc.bending_mastery) == TYPE_DICTIONARY:
		current_level = int(npc.bending_mastery.get(clean_element, 0))

	var realized_level: int = 100
	if gs != null and gs.bending_engine != null:
		if gs.bending_engine.has_method("ensure_bending_potential_state"):
			gs.bending_engine.ensure_bending_potential_state(npc)
		if gs.bending_engine.has_method("get_bending_latent_potential"):
			var latent_value: int = int(gs.bending_engine.get_bending_latent_potential(npc, clean_element))
			realized_level = max(realized_level, latent_value)

	return clamp(max(current_level, realized_level), 0, 100)

func _red_bonnet_bending_elements_to_max(npc: Person) -> Array:
	var out: Array = []
	if npc == null:
		return out

	var bending_type: String = str(npc.bending_type).strip_edges().to_lower()
	if bending_type == "avatar":
		return ["air", "earth", "fire", "water"]

	if bending_type in ["air", "earth", "fire", "water"]:
		out.append(bending_type)

	if typeof(npc.bending_mastery) == TYPE_DICTIONARY:
		for raw_element in npc.bending_mastery.keys():
			var element: String = str(raw_element).strip_edges().to_lower()
			if element in ["air", "earth", "fire", "water"] and int(npc.bending_mastery.get(raw_element, 0)) > 0 and not element in out:
				out.append(element)

	if typeof(npc.bending_latent_potential) == TYPE_DICTIONARY:
		for raw_potential_element in npc.bending_latent_potential.keys():
			var potential_element: String = str(raw_potential_element).strip_edges().to_lower()
			if potential_element in ["air", "earth", "fire", "water"] and int(npc.bending_latent_potential.get(raw_potential_element, 0)) > 0 and not potential_element in out:
				out.append(potential_element)

	return out


func _red_bonnet_apply_willpower_and_imagination(npc: Person) -> void:
	if npc == null:
		return

	if "imagination" in npc:
		npc.imagination = max(int(npc.imagination), 95)

	if "willpower" in npc:
		npc.willpower = max(float(npc.willpower), 9999.0)

	if "willpower_profile" in npc and typeof(npc.willpower_profile) == TYPE_DICTIONARY:
		var profile: Dictionary = npc.willpower_profile.duplicate(true)
		profile ["core_score"] = max(float(profile.get("core_score", 0.0)), 9999.0)
		profile ["active_cap"] = max(float(profile.get("active_cap", 0.0)), 9999.0)
		profile ["source"] = "red_bonnet_identity_binding"
		profile ["red_bonnet_maxed"] = true
		profile ["updated_at_year"] = _current_year()
		profile ["updated_at_ms"] = int(Time.get_ticks_msec())
		npc.willpower_profile = profile

	if gs != null and "willpower_engine" in gs and gs.willpower_engine != null and gs.willpower_engine.has_method("ensure_willpower"):
		gs.willpower_engine.ensure_willpower(npc, {
			"source": "red_bonnet_identity_binding",
			"force_red_bonnet_cap": true
		})



func get_available_wishes(npc: Person) -> Array:
	var out: Array = []
	if npc == null:
		return out
	if npc.id != owner_id:
		return out

	var wish_registry: Dictionary = _safe_dictionary(active_contract.get("wish_registry", {}))
	var wish_order: Array = _safe_array(active_contract.get("wish_order", []))

	for raw_wish_id in wish_order:
		var wish_id: String = str(raw_wish_id).strip_edges()
		if wish_id == "":
			continue
		var wish_contract: Dictionary = _safe_dictionary(wish_registry.get(wish_id, {}))
		if wish_contract.is_empty():
			continue
		if not bool(wish_contract.get("enabled", true)):
			continue

		var once_trait: String = str(wish_contract.get("once_trait", "")).strip_edges()
		if once_trait != "" and once_trait in npc.traits:
			continue

		var capability: String = str(wish_contract.get("capability", "bounded_reality_wish")).strip_edges()
		if capability != "" and not _red_bonnet_has_capability(capability):
			continue

		out.append(str(wish_contract.get("display_name", wish_id.replace("_", " ").capitalize())))

	return out
func wish_requires_target(wish_name: String) -> bool:
	var wish_contract: Dictionary = _red_bonnet_wish_contract(wish_name)
	if not wish_contract.is_empty():
		return bool(wish_contract.get("requires_target", false))

	var wish_key: String = str(wish_name).strip_edges().to_lower()
	match wish_key:
		"wealth", "grant great wealth":
			return true
		"max_fame_forever", "maximum fame forever":
			return true
		"divine protection":
			return true
		"dynasty supremacy":
			return true
		"chosen bloodline":
			return true
		"impossible luck":
			return true
		"world adoration":
			return true
		"expose every enemy":
			return true
		"family prosperity":
			return true
		"no cosmic punishment":
			return true
		"name echoes forever":
			return true
		_:
			return false


func reality_wish_on_target(owner: Person, wish: String, target: Person = null) -> String:
	if owner == null:
		return "\n❌\n No Red Bonnet bearer is active right now."
	if owner.id != owner_id:
		return " Only the Red Bonnet bearer can reshape reality."
	if target == null:
		return reality_wish(owner, wish)

	var wish_key: String = str(wish).strip_edges().to_lower()
	var wish_contract: Dictionary = _red_bonnet_wish_contract(wish_key)
	var contract_resolution: Dictionary = _red_bonnet_resolve_effect(owner, wish_key, {
		"source": "red_bonnet_engine",
		"event_type": "red_bonnet_targeted_wish",
		"wish_key": wish_key,
		"target_id": int(target.id),
		"target_name": "%s %s" % [str(target.first_name), str(target.last_name)],
		"wish_contract": wish_contract.duplicate(true)
	})

	if not bool(contract_resolution.get("allowed", false)):
		return str(contract_resolution.get("text", "The Red Bonnet refused to reshape reality under this contract."))

	var result_text:= ""
	var world_text:= ""
	var diary_text:= ""
	var mythic_rank:= "legendary"

	match wish_key:
		"wealth", "grant great wealth":
			target.bank_balance += 1000000000
			if gs.relationship_engine != null:
				gs.relationship_engine.adjust_relationship(owner, target, 10)
			result_text = "\n💰\n Wealth floods into %s's accounts." % target.first_name
			world_text = "\n💰\n %s %s used the Red Bonnet to call down immense wealth for %s %s." % [
				owner.first_name,
				owner.last_name,
				target.first_name,
				target.last_name
			]
			diary_text = "I used the Red Bonnet to call down immense wealth for %s %s." % [
				target.first_name,
				target.last_name
			]

		"max_fame_forever", "maximum fame forever":
			if "RedBonnetMaxFameWishUsed" in owner.traits:
				return "\n❌\n You already used the Maximum Fame Forever wish."
			owner.traits.append("RedBonnetMaxFameWishUsed")
			if not "RedBonnetFameForever" in target.traits:
				target.traits.append("RedBonnetFameForever")
			target.fame = 100
			target.fame_tier = "Legend"
			if gs.relationship_engine != null:
				gs.relationship_engine.adjust_relationship(owner, target, 8)
			result_text = "\n⭐\n %s's fame is PERMANENTLY etched in time." % target.first_name
			world_text = "\n⭐\n %s %s used the Red Bonnet and made %s %s permanently legendary." % [
				owner.first_name,
				owner.last_name,
				target.first_name,
				target.last_name
			]
			diary_text = "I used the Red Bonnet to lock %s %s's fame at the maximum forever." % [
				target.first_name,
				target.last_name
			]
			mythic_rank = "mythic"

		"divine protection":
			if not "RedBonnetProtected" in target.traits:
				target.traits.append("RedBonnetProtected")
			target.health = max(int(target.health), 200)
			target.mental_health = max(int(target.mental_health), 150)
			if gs.relationship_engine != null:
				gs.relationship_engine.adjust_relationship(owner, target, 8)
			result_text = "\n🛡\n A sacred covering now rests over %s." % target.first_name
			world_text = "\n🛡\n %s %s wished divine protection over %s %s through the Red Bonnet." % [
				owner.first_name,
				owner.last_name,
				target.first_name,
				target.last_name
			]
			diary_text = "I wished divine protection over %s %s through the Red Bonnet." % [
				target.first_name,
				target.last_name
			]

		"dynasty supremacy":
			target.dynasty_prestige = max(int(target.dynasty_prestige), 15000)
			if gs.dynasty_legacy_engine != null:
				gs.dynasty_legacy_engine.add_reputation(target, 900)
			if gs.relationship_engine != null:
				gs.relationship_engine.adjust_relationship(owner, target, 6)
			result_text = "\n👑\n %s's bloodline now walks above all others." % target.first_name
			world_text = "\n👑\n %s %s wished for dynasty supremacy over %s %s." % [
				owner.first_name,
				owner.last_name,
				target.first_name,
				target.last_name
			]
			diary_text = "I wished for dynasty supremacy over %s %s." % [
				target.first_name,
				target.last_name
			]
			mythic_rank = "mythic"

		"chosen bloodline":
			if not "RedBonnetChosenBloodline" in target.traits:
				target.traits.append("RedBonnetChosenBloodline")
			if gs.relationship_engine != null:
				gs.relationship_engine.adjust_relationship(owner, target, 5)
			result_text = "\n🩸\n %s's bloodline has been marked as chosen." % target.first_name
			world_text = "\n🩸\n %s %s marked %s %s's bloodline as chosen through the Red Bonnet." % [
				owner.first_name,
				owner.last_name,
				target.first_name,
				target.last_name
			]
			diary_text = "I marked %s %s's bloodline as chosen through the Red Bonnet." % [
				target.first_name,
				target.last_name
			]
			mythic_rank = "mythic"

		"impossible luck":
			if gs.fate_engine != null:
				gs.transient_afterlife_biases [target.id] = {
					"source": "red_bonnet_engine",
					"luck_bonus": 25,
					"year": gs.year
				}
			if gs.relationship_engine != null:
				gs.relationship_engine.adjust_relationship(owner, target, 4)
			result_text = "\n🍀\n Impossible favor now bends toward %s." % target.first_name
			world_text = "\n🍀\n %s %s wished for impossible luck over %s %s." % [
				owner.first_name,
				owner.last_name,
				target.first_name,
				target.last_name
			]
			diary_text = "I wished for impossible luck over %s %s." % [
				target.first_name,
				target.last_name
			]

		"world adoration":
			target.fame = 100
			target.fame_tier = "Legend"
			if gs.relationship_engine != null:
				gs.relationship_engine.adjust_relationship(owner, target, 6)
			result_text = "\n🌍\n The world turns its face toward %s with love." % target.first_name
			world_text = "\n🌍\n %s %s wished for the world to adore %s %s." % [
				owner.first_name,
				owner.last_name,
				target.first_name,
				target.last_name
			]
			diary_text = "I wished for the world to adore %s %s." % [
				target.first_name,
				target.last_name
			]
			mythic_rank = "mythic"

		"expose every enemy":
			result_text = "\n🔥\n Hidden enemies around %s are dragged into the light." % target.first_name
			world_text = "\n🔥\n %s %s wished for every enemy of %s %s to be exposed." % [
				owner.first_name,
				owner.last_name,
				target.first_name,
				target.last_name
			]
			diary_text = "I wished for every enemy of %s %s to be exposed." % [
				target.first_name,
				target.last_name
			]
			mythic_rank = "mythic"

		"family prosperity":
			target.bank_balance += 25000000
			if gs.relationship_engine != null:
				gs.relationship_engine.adjust_relationship(owner, target, 8)
			result_text = "\n🏡\n Prosperity spreads across %s's family line." % target.first_name
			world_text = "\n🏡\n %s %s wished for %s %s's family to prosper." % [
				owner.first_name,
				owner.last_name,
				target.first_name,
				target.last_name
			]
			diary_text = "I wished for %s %s's family to prosper." % [
				target.first_name,
				target.last_name
			]

		"no cosmic punishment":
			if not "RedBonnetCosmicShield" in target.traits:
				target.traits.append("RedBonnetCosmicShield")
			if gs.relationship_engine != null:
				gs.relationship_engine.adjust_relationship(owner, target, 5)
			result_text = "\n🌌\n Even the heavens hesitate to punish %s." % target.first_name
			world_text = "\n🌌\n %s %s wished for no cosmic punishment over %s %s." % [
				owner.first_name,
				owner.last_name,
				target.first_name,
				target.last_name
			]
			diary_text = "I wished for no cosmic punishment over %s %s." % [
				target.first_name,
				target.last_name
			]
			mythic_rank = "mythic"

		"name echoes forever":
			if not "RedBonnetEchoForever" in target.traits:
				target.traits.append("RedBonnetEchoForever")
			target.fame = max(int(target.fame), 100)
			if gs.relationship_engine != null:
				gs.relationship_engine.adjust_relationship(owner, target, 5)
			result_text = "\n📜\n %s's name now echoes through the ages." % target.first_name
			world_text = "\n📜\n %s %s wished for %s %s's name to echo forever." % [
				owner.first_name,
				owner.last_name,
				target.first_name,
				target.last_name
			]
			diary_text = "I wished for %s %s's name to echo forever." % [
				target.first_name,
				target.last_name
			]
			mythic_rank = "mythic"

		_:
			return reality_wish(owner, wish)

	_emit_targeted_bonnet_echo(owner, target, wish_key, world_text, diary_text, mythic_rank)
	_red_bonnet_commit_bounded_rewrite(owner, wish_key, contract_resolution, {
		"result_text": result_text,
		"world_text": world_text,
		"diary_text": diary_text,
		"mythic_rank": mythic_rank,
		"target_id": int(target.id),
		"target_name": "%s %s" % [str(target.first_name), str(target.last_name)],
		"wish_contract": wish_contract.duplicate(true)
	})
	return result_text if result_text != "" else diary_text


func _emit_targeted_bonnet_echo(owner: Person, target: Person, wish_key: String, world_text: String, diary_text: String, mythic_rank: String, emit_fame_spike: bool = true) -> void:
	if owner == null or gs == null:
		return

	if world_text != "":
		gs.push_world_feed(world_text, {
			"npc_id": owner.id,
			"personally_relevant": owner == gs.player or target == gs.player,
			"category": "artifact",
			"event_name": ActionEventTypes.WISH_MADE,
			"source": "red_bonnet_engine",
			"wish_name": wish_key,
			"target_id": target.id if target != null else -1,
			"mythic_rank": mythic_rank,
			"suppress_diary": owner == gs.player
		})

	var emitted_to_bus:= false
	if gs.event_bus != null:
		emitted_to_bus = true
		gs.event_bus.emit(ActionEventTypes.WISH_MADE, {
			"npc_id": owner.id,
			"target_id": target.id if target != null else -1,
			"event_name": ActionEventTypes.WISH_MADE,
			"type": "text",
			"text": diary_text,
			"third_person_text": world_text.strip_edges(),
			"suppress_world_feed": true,
			"source": "red_bonnet_engine",
			"wish_name": wish_key,
			"mythic_rank": mythic_rank,
			"suppress_fame_signal": true
		})

	if diary_text != "":
		if owner == gs.player:
			if not emitted_to_bus:
				if gs.narrative_engine != null:
					gs.narrative_engine.log_event(owner, {
						"type": "text",
						"text": diary_text
					})
				elif owner.memories != null and not owner.memories.has(diary_text):
					owner.memories.append(diary_text)
			elif owner.memories != null and not owner.memories.has(diary_text):
				owner.memories.append(diary_text)

	if emit_fame_spike and mythic_rank in ["legendary", "mythic"] and gs.event_bus != null:
		gs.event_bus.emit(ActionEventTypes.FAME_SPIKE, {
			"npc_id": owner.id,
			"text": "%s made a mythic Red Bonnet wish." % owner.first_name,
			"source": "red_bonnet_engine",
			"wish_name": wish_key,
			"target_id": target.id if target != null else -1,
			"mythic_rank": mythic_rank
		})

	if gs.memory_engine != null and target != null:
		gs.memory_engine.remember(target.id, "Red Bonnet Wish: %s" % wish_key)

	if target != null and target.memories != null and world_text != "":
		target.memories.append(world_text.strip_edges())
func summon_dragon_balls_to_inventory(payload: Dictionary = {}) -> Dictionary:
	if gs == null:
		return { "success": false, "text": "The Red Bonnet cannot hear reality right now."}

	var actor: Person = payload.get("actor", null) as Person
	if actor == null:
		actor = gs.player

	var actor_id: int = int(payload.get("actor_id", actor.id if actor != null else -1))
	if actor != null and actor_id > 0 and int(actor.id) != actor_id:
		actor = null

	if actor == null and actor_id > 0:
		if gs.has_method("get_or_reactivate_npc_by_id"):
			actor = gs.get_or_reactivate_npc_by_id(actor_id)
		elif gs.has_method("get_npc_by_id"):
			actor = gs.get_npc_by_id(actor_id)

	if actor == null:
		return { "success": false, "text": "No valid Red Bonnet bearer was found."}

	if int(actor.id) != int(owner_id):
		return { "success": false, "text": "Only the Red Bonnet bearer can summon the Dragon Balls."}

	var contract_resolution: Dictionary = _safe_dictionary(payload.get("contract_resolution", {}))
	if contract_resolution.is_empty():
		contract_resolution = _red_bonnet_resolve_effect(actor, "summon_dragon_balls", {
			"source": str(payload.get("source", "red_bonnet_engine")),
			"event_type": "red_bonnet_dragon_ball_summon",
			"wish_key": str(payload.get("wish_key", "summon_dragon_balls")),
			"target_id": int(actor.id)
		})

	if not bool(contract_resolution.get("allowed", false)):
		return {
			"success": false,
			"text": str(contract_resolution.get("text", "The Red Bonnet contract refused the Dragon Ball summon.")),
			"contract_resolution": contract_resolution.duplicate(true)
		}

	if gs.dragonballs_engine == null:
		return { "success": false, "text": "Dragon Balls do not exist in this runtime yet."}

	if not gs.dragonballs_engine.has_method("grant_all_balls_to_person"):
		return { "success": false, "text": "DragonBallsEngine does not expose grant_all_balls_to_person yet."}

	var source_item: Dictionary = _safe_dictionary(payload.get("source_item", {}))
	var skip_runtime_surge: bool = bool(payload.get("skip_runtime_reality_surge", false)) or bool(payload.get("visual_transition_already_presented", false))
	var defer_post_summon_effects: bool = bool(payload.get("defer_post_summon_effects", false)) or bool(payload.get("defer_bounded_rewrite", false)) or bool(payload.get("defer_memory_echoes", false))

	var surge_report: Dictionary = {}
	if skip_runtime_surge:
		surge_report = _red_bonnet_visual_only_dragon_ball_surge_report(actor, payload, contract_resolution)
	else:
		surge_report = _trigger_dragon_ball_relocation_reality_surge(actor, payload, contract_resolution)

	var report: Dictionary = gs.dragonballs_engine.grant_all_balls_to_person(actor, {
		"source": str(payload.get("source", "red_bonnet_engine")),
		"wish_key": str(payload.get("wish_key", "summon_dragon_balls")),
		"source_item": source_item,
		"red_bonnet_contract": active_contract.duplicate(true),
		"contract_resolution": contract_resolution.duplicate(true),
		"reality_surge_report": surge_report.duplicate(true),
		"defer_memory_echoes": defer_post_summon_effects,
		"manual_flush_deferred_echoes": bool(payload.get("manual_flush_deferred_effects", false)) or bool(payload.get("manual_flush_deferred_echoes", false))
	})

	report ["contract_resolution"] = contract_resolution.duplicate(true)
	report ["reality_surge_report"] = surge_report.duplicate(true)
	report ["uses_scenario_panel"] = true
	report ["spectator_frames"] = _build_dragon_ball_summon_transition_frames(actor, report, surge_report)
	report ["spectator_final_interactive"] = false
	report ["spectator_frame_seconds"] = 0.72
	report ["panel_title"] = "RED BONNET • DRAGON BALL SUMMON"
	report ["theme"] = "dragonball"
	report ["accent"] = "#F7B733"
	report ["emoji"] = "🐉"
	report ["popup_title"] = "Dragon Balls Summoned"
	report ["popup_text"] = str(report.get("text", "All 7 Dragon Balls answered the Red Bonnet."))
	report ["popup_footer"] = "The Dragon Balls are now bound to your belongings until a wish scatters them."

	if bool(report.get("success", false)):
		if defer_post_summon_effects:
			_queue_deferred_red_bonnet_dragonball_post_summon_effects(actor, report, payload, contract_resolution, surge_report)
			report ["post_summon_effects_deferred"] = true
		else:
			if gs.belongings_engine != null and gs.belongings_engine.has_method("record_item_use_by_contract"):
				gs.belongings_engine.record_item_use_by_contract(actor, "red_bonnet", "Artifacts", {
					"event_type": "red_bonnet_summoned_dragon_balls",
					"source": "red_bonnet_engine",
					"public_visibility": true,
					"dragonballs_report": report.duplicate(true),
					"contract_resolution": contract_resolution.duplicate(true),
					"reality_surge_report": surge_report.duplicate(true)
				})

			_red_bonnet_record_dragon_ball_synergy(actor, report, payload)
			_red_bonnet_commit_bounded_rewrite(actor, str(payload.get("wish_key", "summon_dragon_balls")), contract_resolution, {
				"result_text": str(report.get("text", "All 7 Dragon Balls answered the Red Bonnet.")),
				"world_text": "     %s used the Red Bonnet to summon all 7 Dragon Balls." % _person_label(actor),
				"diary_text": "I used the Red Bonnet to summon all 7 Dragon Balls.",
				"mythic_rank": "mythic",
				"dragonballs_report": report.duplicate(true),
				"reality_surge_report": surge_report.duplicate(true)
			})

	return report
func _red_bonnet_visual_only_dragon_ball_surge_report(actor: Person, payload: Dictionary = {}, contract_resolution: Dictionary = {}) -> Dictionary:
	return {
		"success": true,
		"schema": "eralife.red_bonnet_dragon_ball_relocation_visual_runtime_proxy",
		"version": CONTRACT_VERSION,
		"source": str(payload.get("source", "red_bonnet_engine")),
		"wish_key": str(payload.get("wish_key", "summon_dragon_balls")),
		"visual_transition_already_presented": true,
		"actor_id": int(actor.id) if actor != null else -1,
		"actor_name": _person_label(actor),
		"contract_resolution": contract_resolution.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec())
	}


func _queue_deferred_red_bonnet_dragonball_post_summon_effects(actor: Person, report: Dictionary, payload: Dictionary = {}, contract_resolution: Dictionary = {}, surge_report: Dictionary = {}) -> void:
	if gs == null or actor == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var queue: Array = _safe_array(gs.scenario_state.get("red_bonnet_deferred_effect_queue", []))
	queue.append({
		"effect_type": "red_bonnet_dragonball_post_summon",
		"actor_id": int(actor.id),
		"actor_name": _person_label(actor),
		"wish_key": str(payload.get("wish_key", "summon_dragon_balls")),
		"report": report.duplicate(true),
		"payload": payload.duplicate(true),
		"contract_resolution": contract_resolution.duplicate(true),
		"reality_surge_report": surge_report.duplicate(true),
		"created_at_year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec())
	})
	gs.scenario_state ["red_bonnet_deferred_effect_queue"] = queue
	gs.scenario_state ["red_bonnet_deferred_effect_queue_size"] = queue.size()

	if bool(payload.get("manual_flush_deferred_effects", false)) or bool(payload.get("manual_flush_deferred_echoes", false)):
		gs.scenario_state ["red_bonnet_deferred_effect_manual_flush_required"] = true
		gs.scenario_state ["red_bonnet_deferred_effect_manual_flush_reason"] = str(payload.get("source", "red_bonnet_engine"))
		return

	call_deferred("_flush_deferred_red_bonnet_dragonball_effects", 1)

func _flush_deferred_red_bonnet_dragonball_effects(max_count: int = 1) -> Dictionary:
	if gs == null:
		return {
			"success": false,
			"reason": "GameState missing."
		}

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var queue: Array = _safe_array(gs.scenario_state.get("red_bonnet_deferred_effect_queue", []))
	if queue.is_empty():
		gs.scenario_state ["red_bonnet_deferred_effect_queue_size"] = 0
		return {
			"success": true,
			"processed": 0,
			"remaining": 0
		}

	var processed: int = 0
	var budget: int = max(1, int(max_count))

	while processed < budget and not queue.is_empty():
		var row: Dictionary = _safe_dictionary(queue.pop_front())
		var effect_type: String = str(row.get("effect_type", "")).strip_edges()
		if effect_type != "red_bonnet_dragonball_post_summon":
			processed += 1
			continue

		var actor_id: int = int(row.get("actor_id", -1))
		var actor: Person = null
		if actor_id > 0:
			if gs.has_method("get_or_reactivate_npc_by_id"):
				actor = gs.get_or_reactivate_npc_by_id(actor_id)
			elif gs.has_method("get_npc_by_id"):
				actor = gs.get_npc_by_id(actor_id)

		if actor == null and gs.player != null and int(gs.player.id) == actor_id:
			actor = gs.player

		if actor != null:
			var report: Dictionary = _safe_dictionary(row.get("report", {}))
			var payload: Dictionary = _safe_dictionary(row.get("payload", {}))
			var contract_resolution: Dictionary = _safe_dictionary(row.get("contract_resolution", {}))
			var surge_report: Dictionary = _safe_dictionary(row.get("reality_surge_report", {}))
			var wish_key: String = str(row.get("wish_key", payload.get("wish_key", "summon_dragon_balls")))

			if gs.belongings_engine != null and gs.belongings_engine.has_method("record_item_use_by_contract"):
				gs.belongings_engine.record_item_use_by_contract(actor, "red_bonnet", "Artifacts", {
					"event_type": "red_bonnet_summoned_dragon_balls",
					"source": "red_bonnet_engine",
					"public_visibility": true,
					"dragonballs_report": report.duplicate(true),
					"contract_resolution": contract_resolution.duplicate(true),
					"reality_surge_report": surge_report.duplicate(true),
					"deferred": true
				})

			_red_bonnet_record_dragon_ball_synergy(actor, report, payload)
			_red_bonnet_commit_bounded_rewrite(actor, wish_key, contract_resolution, {
				"result_text": str(report.get("text", "All 7 Dragon Balls answered the Red Bonnet.")),
				"world_text": "     %s used the Red Bonnet to summon all 7 Dragon Balls." % _person_label(actor),
				"diary_text": "I used the Red Bonnet to summon all 7 Dragon Balls.",
				"mythic_rank": "mythic",
				"dragonballs_report": report.duplicate(true),
				"reality_surge_report": surge_report.duplicate(true),
				"deferred": true
			})

		processed += 1

	gs.scenario_state ["red_bonnet_deferred_effect_queue"] = queue
	gs.scenario_state ["red_bonnet_deferred_effect_queue_size"] = queue.size()
	gs.scenario_state ["red_bonnet_deferred_effect_last_flush"] = {
		"processed": processed,
		"remaining": queue.size(),
		"flushed_at_ms": int(Time.get_ticks_msec())
	}

	if not queue.is_empty():
		call_deferred("_flush_deferred_red_bonnet_dragonball_effects", budget)

	return {
		"success": true,
		"processed": processed,
		"remaining": queue.size()
	}
func build_dragon_ball_summon_transition_packet(actor: Person, payload: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {}

	var contract_resolution: Dictionary = _safe_dictionary(payload.get("contract_resolution", {}))
	var surge_report: Dictionary = {
		"success": true,
		"schema": "eralife.red_bonnet_dragon_ball_summon_visual_preflight",
		"version": CONTRACT_VERSION,
		"source": str(payload.get("source", "red_bonnet_engine")),
		"wish_key": str(payload.get("wish_key", "summon_dragon_balls")),
		"visual_only": true,
		"contract_resolution": contract_resolution.duplicate(true),
		"theme": {
			"theme_id": "dragonball",
			"element": "dragonball"
		},
		"created_at_ms": int(Time.get_ticks_msec())
	}

	return {
		"success": true,
		"uses_scenario_panel": true,
		"schema": "eralife.red_bonnet_dragon_ball_summon_transition_packet",
		"version": CONTRACT_VERSION,
		"panel_title": "RED BONNET • DRAGON BALL SUMMON",
		"theme": "dragonball",
		"accent": "#F7B733",
		"emoji": " ",
		"subtitle": "Bounded Reality Relocation • Visual Preflight",
		"text": "The Red Bonnet does not instantly hand you the Dragon Balls.\n\nIt opens a bounded mythic relocation seam first.",
		"popup_title": "Dragon Balls Answering",
		"popup_text": "The Red Bonnet is calling the Dragon Balls across the world.",
		"popup_footer": "Reality is relocating seven artifacts...",
		"spectator_frames": _build_dragon_ball_summon_transition_frames(actor, {}, surge_report),
		"spectator_final_interactive": false,
		"spectator_frame_seconds": 0.84,
		"dragonball_arrival_animation": _dragon_ball_summon_arrival_animation_packet(actor, payload),
		"reality_surge_report": surge_report.duplicate(true),
		"opps": []
	}
func _dragon_ball_summon_arrival_animation_packet(actor: Person, payload: Dictionary = {}) -> Dictionary:
	return {
		"active": true,
		"schema": "eralife.red_bonnet_dragon_ball_arrival_animation_packet",
		"version": CONTRACT_VERSION,
		"source": str(payload.get("source", "red_bonnet_engine")),
		"actor_id": int(actor.id) if actor != null else -1,
		"stars": [1, 2, 3, 4, 5, 6, 7],
		"origin_surface": "screen_edges",
		"target_surface": "belongings_hud_button",
		"duration_seconds": 2.25,
		"created_at_ms": int(Time.get_ticks_msec())
	}
func _build_dragon_ball_summon_transition_frames(actor: Person, report: Dictionary = {}, _surge_report: Dictionary = {}) -> Array:
	var actor_name: String = _person_label(actor)
	var acquired: Array = _safe_array(report.get("acquired", []))
	var acquired_text: String = "seven"
	if not acquired.is_empty():
		acquired_text = str(acquired.size())

	return [
		{
			"panel_title": "RED BONNET • REALITY SURGE",
			"theme": "dragonball",
			"text": "The Red Bonnet lifts from %s's belongings like it heard a voice behind the sky.\n\nA reality surge opens — not to summon Shenron yet, but to move the Dragon Balls themselves." % actor_name,
			"footer_text": "Artifact relocation contract opening..."
		},
		{
			"panel_title": "RED BONNET • SEVEN SIGNALS",
			"theme": "dragonball",
			"text": "Across the world, seven orange lights answer.\n\nOne sleeps under stone.\nOne hums inside a collector's vault.\nOne rolls out of history like it was never lost.\n\nThe Red Bonnet pulls their coordinates into one orbit.",
			"footer_text": "Dragon Ball relocation seam stabilizing..."
		},
		{
			"panel_title": "RED BONNET • INVENTORY MANIFESTATION",
			"theme": "dragonball",
			"text": "The Dragon Balls do not simply appear.\n\nThey arrive one after another, each impact pressing gold light through your belongings.\n\n%s Dragon Ball signal%s now bind%s to %s." % [
				acquired_text.capitalize(),
				"" if acquired_text == "one" else "s",
				"s" if acquired_text == "one" else "",
				actor_name
			],
			"footer_text": "The Dragon Balls can now be used to summon Shenron."
		}
	]
func _trigger_dragon_ball_relocation_reality_surge(actor: Person, payload: Dictionary = {}, contract_resolution: Dictionary = {}) -> Dictionary:
	if gs == null or actor == null:
		return {}
	if not ("reality_surge_engine" in gs) or gs.reality_surge_engine == null:
		return {}
	if not gs.reality_surge_engine.has_method("trigger_surge"):
		return {}

	var contract_id: String = "red_bonnet.dragon_ball_relocation.reality_surge"
	if gs.reality_surge_engine.has_method("register_surge_contract"):
		gs.reality_surge_engine.register_surge_contract(_dragon_ball_relocation_reality_surge_contract(contract_id))

	var event_payload: Dictionary = {
		"event_name": "red_bonnet.dragon_ball_relocation",
		"domain": "red_bonnet",
		"source": "red_bonnet_engine",
		"wish_key": str(payload.get("wish_key", "summon_dragon_balls")),
		"contract_resolution": contract_resolution.duplicate(true),
		"salience": 94.0,
		"screen_damage": "mythic",
		"time_dilation": 0.55,
		"audio_muffle": 0.82,
	}

	var result: Variant = gs.reality_surge_engine.trigger_surge(contract_id, actor, event_payload, {
		"source": "red_bonnet_engine.summon_dragon_balls_to_inventory",
		"force": true,
		"duplicate_window_ms": 1800
	})

	if typeof(result) == TYPE_DICTIONARY:
		return (result as Dictionary).duplicate(true)

	return {}
func _dragon_ball_relocation_reality_surge_contract(contract_id: String) -> Dictionary:
	return {
		"schema": "eralife.reality_surge_contract",
		"version": 2,
		"id": contract_id,
		"domain": "red_bonnet",
		"display_name": "Red Bonnet Dragon Ball Relocation Surge",
		"trigger": {
			"event": "red_bonnet.dragon_ball_relocation",
			"filters": {
				"domain": "red_bonnet"
			},
			"threshold": {
				"salience_min": 80.0
			}
		},
		"surge_profile": {
			"type": ["artifact_relocation", "wish_authority", "bounded_reality"],
			"intensity": 0.92
		},
		"visual_layer": {
			"theme_resolver": "dragonball_relocation_resolver",
			"shader_profile": "red_bonnet_dragon_ball_relocation",
			"screen_damage": "mythic",
			"distortion": true,
			"particles": true
		},
		"perception_layer": {
			"time_dilation": 0.55,
			"input_lock_ms": 900,
			"camera_weight": 0.85,
			"audio_muffle": 0.82,
		},
		"stability": {
			"instability_gain": 0.16,
			"mutation_chance": 0.01,
		}
	}
func _red_bonnet_record_dragon_ball_synergy(actor: Person, dragon_report: Dictionary = {}, payload: Dictionary = {}) -> void:
	if gs == null or actor == null:
		return
	if gs.belongings_engine == null:
		return
	if not gs.belongings_engine.has_method("record_item_relationship"):
		return

	var relationship_report: Dictionary = gs.belongings_engine.record_item_relationship(actor, {
		"category": "Artifacts",
		"contract_id": "red_bonnet",
		"max_results": 1
	}, {
		"category": "Dragon Balls",
		"contract_id": "dragonball"
	}, "artifact_synergy", {
		"source": "red_bonnet_engine",
		"event_type": "red_bonnet_dragon_ball_synergy",
		"relationship_weight": 0.2,
		"public_visibility": true,
		"dragonballs_report": dragon_report.duplicate(true),
		"payload": payload.duplicate(true),
		"world_feed_text": "The Red Bonnet and the Dragon Balls began answering the same bearer."
	})

	if not "RedBonnetDragonBallSynergy" in actor.traits:
		actor.traits.append("RedBonnetDragonBallSynergy")

	if actor.memories != null:
		var memory_text: String = "The Red Bonnet felt stronger after the Dragon Balls answered."
		if not actor.memories.has(memory_text):
			actor.memories.append(memory_text)

	if gs.belongings_engine.has_method("record_item_use_by_contract"):
		gs.belongings_engine.record_item_use_by_contract(actor, "red_bonnet", "Artifacts", {
			"event_type": "red_bonnet_empowered_by_dragon_balls",
			"source": "red_bonnet_engine",
			"public_visibility": true,
			"relationship_report": relationship_report.duplicate(true)
		})


func _red_bonnet_record_cosmic_artifact_synergy(actor: Person, wish_key: String = "summon_cosmic_artifacts") -> void:
	if gs == null or actor == null:
		return
	if gs.belongings_engine == null:
		return
	if not gs.belongings_engine.has_method("record_item_relationship"):
		return

	var relationship_report: Dictionary = gs.belongings_engine.record_item_relationship(actor, {
		"category": "Artifacts",
		"contract_id": "red_bonnet",
		"max_results": 1
	}, {
		"category": "Artifacts",
		"artifact_kind": "stone",
		"name_contains": "stone"
	}, "artifact_synergy", {
		"source": "red_bonnet_engine",
		"event_type": "red_bonnet_infinity_stone_synergy",
		"relationship_weight": 0.28,
		"public_visibility": true,
		"wish_key": wish_key,
		"world_feed_text": "The Red Bonnet drank in the pressure of the Infinity Stones and became harder to ignore."
	})

	if not "RedBonnetCosmicSynergy" in actor.traits:
		actor.traits.append("RedBonnetCosmicSynergy")

	actor.health = max(int(actor.health), 240)
	actor.mental_health = max(int(actor.mental_health), 240)
	actor.satisfaction = max(int(actor.satisfaction), 240)
	actor.smarts = max(int(actor.smarts), 240)
	actor.looks = max(int(actor.looks), 240)

	if actor.memories != null:
		var memory_text: String = "The Red Bonnet grew stronger when the Infinity Stones entered my orbit."
		if not actor.memories.has(memory_text):
			actor.memories.append(memory_text)

	if gs.belongings_engine.has_method("record_item_use_by_contract"):
		gs.belongings_engine.record_item_use_by_contract(actor, "red_bonnet", "Artifacts", {
			"event_type": "red_bonnet_empowered_by_infinity_stones",
			"source": "red_bonnet_engine",
			"public_visibility": true,
			"relationship_report": relationship_report.duplicate(true)
		})


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)
func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)


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


func _default_contract() -> Dictionary:
	return {
		"schema": CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": "red_bonnet.core",
		"authority": "reality",
		"artifact_class": "mythic_artifact",
		"bounded_reality": true,
		"capabilities": [
			"bounded_reality_wish",
			"artifact_summoning",
			"myth_amplification",
			"identity_binding",
			"cross_artifact_resonance",
			"dynasty_rewrite",
			"cosmic_pressure_shielding"
		],
		"effect_negotiation": {
			"requires_reality_orchestrator": true,
			"fallback_policy": "soft_allow_packet_only",
			"max_rewrite_strength": 0.65,
			"identity_risk_threshold": 0.22,
			"block_unregistered_effects": false,
			"preserve_unknown_fields": true
		},
		"composition_stack": [
			"red_bonnet_engine",
			"reality_authority_boundary",
			"artifact_context",
			"myth_formation",
			"upce_interpretation",
			"identity_anchor",
			"world_feed_echo",
			"bounded_rewrite_ledger"
		],
		"rewrite_outputs": {
			"emit_world_feed": true,
			"emit_event_bus": true,
			"emit_belongings_myth": true,
		},
		"wish_order": [
			"revive_all",
			"max_dynasty",
			"spawn_artifacts",
			"summon_dragon_balls",
			"wealth",
			"max_fame_forever",
			"divine_protection",
			"dynasty_supremacy",
			"chosen_bloodline",
			"impossible_luck",
			"world_adoration",
			"expose_every_enemy",
			"family_prosperity",
			"no_cosmic_punishment",
			"name_echoes_forever"
		],
		"wish_registry": {
			"revive_all": {
				"display_name": "Revive All Souls",
				"aliases": ["revive_all", "revive all souls"],
				"capability": "bounded_reality_wish",
				"requires_target": false,
				"rewrite_strength": 0.65,
				"identity_risk": 0.16,
				"causal_debt": 0.42,
				"effects": ["soul_reentry", "death_state_mutation", "world_feed_echo", "myth_amplification"]
			},
			"max_dynasty": {
				"display_name": "Crown My Dynasty",
				"aliases": ["max_dynasty", "crown my dynasty"],
				"capability": "dynasty_rewrite",
				"requires_target": false,
				"rewrite_strength": 0.58,
				"identity_risk": 0.12,
				"causal_debt": 0.34,
				"effects": ["dynasty_prestige_rewrite", "reputation_amplification", "myth_amplification"]
			},
			"spawn_artifacts": {
				"display_name": "Summon Cosmic Artifacts",
				"aliases": ["spawn_artifacts", "summon cosmic artifacts"],
				"capability": "artifact_summoning",
				"requires_target": false,
				"rewrite_strength": 0.64,
				"identity_risk": 0.18,
				"causal_debt": 0.47,
				"effects": ["artifact_manifestation", "cross_artifact_resonance", "cosmic_pressure"]
			},
			"summon_dragon_balls": {
				"display_name": "Summon Dragon Balls",
				"aliases": ["summon_dragon_balls", "summon dragon balls", "summon all dragon balls"],
				"capability": "artifact_summoning",
				"requires_target": false,
				"rewrite_strength": 0.6,
				"identity_risk": 0.14,
				"causal_debt": 0.39,
				"effects": ["artifact_manifestation", "dragon_ball_relocation", "cross_artifact_resonance"]
			},
			"wealth": {
				"display_name": "Grant Great Wealth",
				"aliases": ["wealth", "grant great wealth"],
				"capability": "bounded_reality_wish",
				"requires_target": true,
				"rewrite_strength": 0.44,
				"identity_risk": 0.08,
				"causal_debt": 0.22,
				"effects": ["bank_balance_rewrite", "relationship_update"]
			},
			"max_fame_forever": {
				"display_name": "Maximum Fame Forever",
				"aliases": ["max_fame_forever", "maximum fame forever"],
				"capability": "myth_amplification",
				"requires_target": true,
				"once_trait": "RedBonnetMaxFameWishUsed",
				"rewrite_strength": 0.52,
				"identity_risk": 0.13,
				"causal_debt": 0.32,
				"effects": ["fame_lock", "reputation_amplification", "historical_echo"]
			},
			"divine_protection": {
				"display_name": "Divine Protection",
				"aliases": ["divine protection"],
				"capability": "cosmic_pressure_shielding",
				"requires_target": true,
				"rewrite_strength": 0.42,
				"identity_risk": 0.09,
				"causal_debt": 0.18,
				"effects": ["health_floor", "protection_trait", "relationship_update"]
			},
			"dynasty_supremacy": {
				"display_name": "Dynasty Supremacy",
				"aliases": ["dynasty supremacy"],
				"capability": "dynasty_rewrite",
				"requires_target": true,
				"rewrite_strength": 0.62,
				"identity_risk": 0.16,
				"causal_debt": 0.41,
				"effects": ["dynasty_prestige_rewrite", "reputation_amplification"]
			},
			"chosen_bloodline": {
				"display_name": "Chosen Bloodline",
				"aliases": ["chosen bloodline"],
				"capability": "identity_binding",
				"requires_target": true,
				"rewrite_strength": 0.5,
				"identity_risk": 0.17,
				"causal_debt": 0.29,
				"effects": ["bloodline_marker", "identity_binding"]
			},
			"impossible_luck": {
				"display_name": "Impossible Luck",
				"aliases": ["impossible luck"],
				"capability": "bounded_reality_wish",
				"requires_target": true,
				"rewrite_strength": 0.46,
				"identity_risk": 0.1,
				"causal_debt": 0.23,
				"effects": ["luck_bias", "fate_pressure"]
			},
			"world_adoration": {
				"display_name": "World Adoration",
				"aliases": ["world adoration"],
				"capability": "myth_amplification",
				"requires_target": true,
				"rewrite_strength": 0.52,
				"identity_risk": 0.13,
				"causal_debt": 0.31,
				"effects": ["fame_rewrite", "social_signal_amplification"]
			},
			"expose_every_enemy": {
				"display_name": "Expose Every Enemy",
				"aliases": ["expose every enemy"],
				"capability": "bounded_reality_wish",
				"requires_target": true,
				"rewrite_strength": 0.48,
				"identity_risk": 0.1,
				"causal_debt": 0.26,
				"effects": ["enemy_exposure", "scenario_hook"]
			},
			"family_prosperity": {
				"display_name": "Family Prosperity",
				"aliases": ["family prosperity"],
				"capability": "bounded_reality_wish",
				"requires_target": true,
				"rewrite_strength": 0.42,
				"identity_risk": 0.08,
				"causal_debt": 0.2,
				"effects": ["bank_balance_rewrite", "family_signal"]
			},
			"no_cosmic_punishment": {
				"display_name": "No Cosmic Punishment",
				"aliases": ["no cosmic punishment"],
				"capability": "cosmic_pressure_shielding",
				"requires_target": true,
				"rewrite_strength": 0.56,
				"identity_risk": 0.15,
				"causal_debt": 0.36,
				"effects": ["cosmic_shield", "punishment_suppression"]
			},
			"name_echoes_forever": {
				"display_name": "Name Echoes Forever",
				"aliases": ["name echoes forever"],
				"capability": "myth_amplification",
				"requires_target": true,
				"rewrite_strength": 0.54,
				"identity_risk": 0.13,
				"causal_debt": 0.34,
				"effects": ["historical_echo", "fame_floor", "myth_amplification"]
			},
			"identity_binding": {
				"display_name": "Bind Red Bonnet Bearer",
				"aliases": ["identity_binding", "red_bonnet_grant"],
				"capability": "identity_binding",
				"requires_target": false,
				"rewrite_strength": 0.45,
				"identity_risk": 0.12,
				"causal_debt": 0.18,
				"effects": ["identity_binding", "artifact_manifestation", "myth_anchor"]
			}
		}
	}


func _red_bonnet_has_capability(capability: String) -> bool:
	var clean_capability: String = str(capability).strip_edges()
	if clean_capability == "":
		return true
	return clean_capability in _safe_array(active_contract.get("capabilities", []))


func _red_bonnet_wish_contract(wish_name: String) -> Dictionary:
	var wish_key: String = str(wish_name).strip_edges().to_lower()
	var normalized_key: String = wish_key.replace(" ", "_")
	var registry: Dictionary = _safe_dictionary(active_contract.get("wish_registry", {}))

	if registry.has(wish_key):
		return _safe_dictionary(registry.get(wish_key, {}))
	if registry.has(normalized_key):
		return _safe_dictionary(registry.get(normalized_key, {}))

	for raw_key in registry.keys():
		var row: Dictionary = _safe_dictionary(registry.get(raw_key, {}))
		if row.is_empty():
			continue
		for raw_alias in _safe_array(row.get("aliases", [])):
			if str(raw_alias).strip_edges().to_lower() == wish_key:
				return row.duplicate(true)

	return {}


func _red_bonnet_resolve_effect(actor: Person, effect_id: String, payload: Dictionary = {}) -> Dictionary:
	var clean_effect: String = str(effect_id).strip_edges().to_lower()
	if clean_effect == "":
		clean_effect = "bounded_reality_wish"

	var contract: Dictionary = active_contract.duplicate(true)
	var negotiation: Dictionary = _safe_dictionary(contract.get("effect_negotiation", {}))
	var wish_contract: Dictionary = _safe_dictionary(payload.get("wish_contract", {}))
	if wish_contract.is_empty():
		wish_contract = _red_bonnet_wish_contract(clean_effect)

	var capability: String = str(wish_contract.get("capability", payload.get("capability", "bounded_reality_wish"))).strip_edges()
	var max_strength: float = float(negotiation.get("max_rewrite_strength", 0.65))
	var threshold: float = float(negotiation.get("identity_risk_threshold", 0.22))
	var rewrite_strength: float = clamp(float(wish_contract.get("rewrite_strength", payload.get("rewrite_strength", 0.25))), 0.0, max_strength)
	var identity_risk: float = clamp(float(wish_contract.get("identity_risk", payload.get("identity_risk", rewrite_strength * 0.25))), 0.0, 1.0)
	var causal_debt: float = clamp(float(wish_contract.get("causal_debt", rewrite_strength * 0.55)), 0.0, 1.0)

	var allowed: bool = true
	var reasons: Array = []

	if not bool(contract.get("bounded_reality", true)):
		allowed = false
		reasons.append("contract_not_bounded")

	if capability != "" and not _red_bonnet_has_capability(capability):
		allowed = false
		reasons.append("missing_capability:%s" % capability)

	if identity_risk > threshold:
		allowed = false
		reasons.append("identity_risk_threshold_exceeded")

	if bool(negotiation.get("block_unregistered_effects", false)) and wish_contract.is_empty():
		allowed = false
		reasons.append("unregistered_effect")

	var defer_runtime_orchestration: bool = bool(payload.get("defer_reality_routing", false)) or bool(payload.get("suppress_reality_orchestration", false)) or bool(payload.get("birth_loadout", false))
	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		defer_runtime_orchestration = defer_runtime_orchestration or bool(gs.scenario_state.get("birth_shell_first_boot_active", false)) or bool(gs.scenario_state.get("post_spawn_ui_finalize_pending", false))

	var intent: Dictionary = {
		"id": "red_bonnet.%s" % clean_effect.replace(" ", "_"),
		"domain": "red_bonnet",
		"authority": str(contract.get("authority", "reality")),
		"target": "red_bonnet_engine",
		"engine_property": "red_bonnet_engine",
		"event_payload": payload.duplicate(true),
		"effects": _safe_array(wish_contract.get("effects", [])),
		"composition_stack": _safe_array(contract.get("composition_stack", [])),
		"red_bonnet_contract": contract.duplicate(true),
		"rewrite_strength": rewrite_strength,
		"identity_risk": identity_risk,
		"causal_debt": causal_debt
	}

	var orchestration: Dictionary = {}
	var orchestrator_available: bool = gs != null and "reality_orchestrator" in gs and gs.reality_orchestrator != null and gs.reality_orchestrator.has_method("orchestrate_intent")

	if orchestrator_available and not defer_runtime_orchestration:
		orchestration = gs.reality_orchestrator.orchestrate_intent(intent, {
			"source": "red_bonnet_engine",
			"domain": "red_bonnet",
			"authority": str(contract.get("authority", "reality")),
			"contract_id": str(contract.get("id", "red_bonnet.core"))
		})
	elif bool(negotiation.get("requires_reality_orchestrator", true)) and str(negotiation.get("fallback_policy", "soft_allow_packet_only")) != "soft_allow_packet_only" and not defer_runtime_orchestration:
		allowed = false
		reasons.append("reality_orchestrator_unavailable")
	else:
		orchestration = {
			"success": allowed,
			"mode": "packet_only",
			"deferred": defer_runtime_orchestration,
			"reason": "birth_shell_or_runtime_handoff_deferred" if defer_runtime_orchestration else "reality_orchestrator_unavailable_soft_authority"
		}

	var resolution: Dictionary = {
		"success": allowed,
		"allowed": allowed,
		"schema": "eralife.red_bonnet_contract_resolution",
		"version": CONTRACT_VERSION,
		"contract_id": str(contract.get("id", "red_bonnet.core")),
		"authority": str(contract.get("authority", "reality")),
		"artifact_class": str(contract.get("artifact_class", "mythic_artifact")),
		"effect_id": clean_effect,
		"capability": capability,
		"actor_id": int(actor.id) if actor != null else -1,
		"actor_name": _person_label(actor),
		"target_id": int(payload.get("target_id", -1)),
		"bounded_reality": bool(contract.get("bounded_reality", true)),
		"rewrite_strength": rewrite_strength,
		"identity_risk": identity_risk,
		"identity_risk_threshold": threshold,
		"causal_debt": causal_debt,
		"effects": _safe_array(wish_contract.get("effects", [])),
		"composition_stack": _safe_array(contract.get("composition_stack", [])),
		"orchestration": orchestration.duplicate(true),
		"deferred_runtime_orchestration": defer_runtime_orchestration,
		"reasons": reasons,
		"text": "The Red Bonnet contract refused this rewrite." if not allowed else "The Red Bonnet contract accepted the bounded rewrite.",
		"payload": payload.duplicate(true),
		"created_at_year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	_record_contract_resolution(resolution)
	last_contract_resolution = resolution.duplicate(true)
	return resolution


func _red_bonnet_commit_bounded_rewrite(actor: Person, effect_id: String, resolution: Dictionary, result_payload: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {}
	if not bool(resolution.get("allowed", false)):
		return resolution.duplicate(true)

	var outputs: Dictionary = _safe_dictionary(active_contract.get("rewrite_outputs", {}))
	var resolution_payload: Dictionary = _safe_dictionary(resolution.get("payload", {}))

	var defer_runtime_side_effects: bool = bool(result_payload.get("defer_reality_routing", false)) \
or bool(result_payload.get("suppress_reality_orchestration", false)) \
or bool(result_payload.get("birth_loadout", false)) \
or bool(resolution.get("deferred_runtime_orchestration", false)) \
or bool(resolution_payload.get("defer_reality_routing", false)) \
or bool(resolution_payload.get("suppress_reality_orchestration", false)) \
or bool(resolution_payload.get("birth_loadout", false))

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		defer_runtime_side_effects = defer_runtime_side_effects \
or bool(gs.scenario_state.get("birth_shell_first_boot_active", false)) \
or bool(gs.scenario_state.get("post_spawn_ui_finalize_pending", false))

	var rewrite_report: Dictionary = {
		"success": true,
		"schema": "eralife.red_bonnet_bounded_rewrite_report",
		"version": CONTRACT_VERSION,
		"contract_id": str(active_contract.get("id", "red_bonnet.core")),
		"authority": str(active_contract.get("authority", "reality")),
		"effect_id": str(effect_id).strip_edges().to_lower(),
		"actor_id": int(actor.id),
		"actor_name": _person_label(actor),
		"target_id": int(result_payload.get("target_id", resolution.get("target_id", -1))),
		"rewrite_strength": float(resolution.get("rewrite_strength", 0.0)),
		"identity_risk": float(resolution.get("identity_risk", 0.0)),
		"causal_debt": float(resolution.get("causal_debt", 0.0)),
		"mythic_rank": str(result_payload.get("mythic_rank", "legendary")),
		"composition_stack": _safe_array(resolution.get("composition_stack", [])),
		"contract_resolution": resolution.duplicate(true),
		"result_payload": result_payload.duplicate(true),
		"deferred_runtime_side_effects": defer_runtime_side_effects,
		"created_at_year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	var state: Dictionary = _world_state()
	var ledger: Array = _safe_array(state.get("bounded_rewrite_ledger", []))
	ledger.append(rewrite_report.duplicate(true))
	while ledger.size() > MAX_REWRITE_LEDGER:
		ledger.pop_front()
	state ["bounded_rewrite_ledger"] = ledger
	state ["last_rewrite_report"] = rewrite_report.duplicate(true)
	_commit_world_state(state)

	last_rewrite_report = rewrite_report.duplicate(true)

	if not defer_runtime_side_effects and bool(outputs.get("emit_belongings_myth", true)) and gs != null and gs.belongings_engine != null and gs.belongings_engine.has_method("record_item_use_by_contract"):
		gs.belongings_engine.record_item_use_by_contract(actor, "red_bonnet", "Artifacts", {
			"event_type": "red_bonnet_bounded_rewrite",
			"source": "red_bonnet_engine",
			"public_visibility": true,
			"effect_id": str(effect_id).strip_edges().to_lower(),
			"contract_resolution": resolution.duplicate(true),
			"rewrite_report": rewrite_report.duplicate(true)
		})

	if not defer_runtime_side_effects and bool(outputs.get("emit_event_bus", true)) and gs != null and "event_bus" in gs and gs.event_bus != null:
		gs.event_bus.emit("red_bonnet.bounded_rewrite.committed", rewrite_report.duplicate(true))

	return rewrite_report


func _record_contract_resolution(resolution: Dictionary) -> void:
	var state: Dictionary = _world_state()
	var ledger: Array = _safe_array(state.get("contract_resolution_ledger", []))
	ledger.append(resolution.duplicate(true))
	while ledger.size() > MAX_CONTRACT_LEDGER:
		ledger.pop_front()
	state ["contract_resolution_ledger"] = ledger
	state ["last_contract_resolution"] = resolution.duplicate(true)
	_commit_world_state(state)


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
	if typeof(out.get("contract_resolution_ledger", [])) != TYPE_ARRAY:
		out ["contract_resolution_ledger"] = []
	if typeof(out.get("bounded_rewrite_ledger", [])) != TYPE_ARRAY:
		out ["bounded_rewrite_ledger"] = []
	if typeof(out.get("last_contract_resolution", {})) != TYPE_DICTIONARY:
		out ["last_contract_resolution"] = {}
	if typeof(out.get("last_rewrite_report", {})) != TYPE_DICTIONARY:
		out ["last_rewrite_report"] = {}
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


func _person_label(person: Person) -> String:
	if person == null:
		return "Unknown"
	var full_name: String = ("%s %s" % [str(person.first_name), str(person.last_name)]).strip_edges()
	if full_name == "":
		full_name = str(person.name).strip_edges() if "name" in person else "Unknown"
	return full_name
func reality_wish(npc: Person, wish: String) -> String:
	if npc == null:
		return "\n👑\n No Red Bonnet bearer is active right now."
	if npc.id != owner_id:
		return " Only the Red Bonnet bearer can reshape reality."

	var wish_key: String = str(wish).strip_edges().to_lower()
	var wish_contract: Dictionary = _red_bonnet_wish_contract(wish_key)
	var contract_resolution: Dictionary = _red_bonnet_resolve_effect(npc, wish_key, {
		"source": "red_bonnet_engine",
		"event_type": "red_bonnet_wish",
		"wish_key": wish_key,
		"wish_contract": wish_contract.duplicate(true),
		"target_id": -1
	})

	if not bool(contract_resolution.get("allowed", false)):
		return str(contract_resolution.get("text", "The Red Bonnet refused to reshape reality under this contract."))

	var result_text:= ""
	var world_text:= ""
	var diary_text:= ""
	var mythic_rank:= "legendary"

	match wish_key:
		"revive_all", "revive all souls":
			result_text = _revive_all()
			world_text = "\n👑\n %s %s used the Red Bonnet to call souls back into the world." % [
				npc.first_name,
				npc.last_name
			]
			diary_text = "I used the Red Bonnet to call souls back into the world."
			mythic_rank = "mythic"
		"max_dynasty", "crown my dynasty":
			npc.dynasty_prestige = 9999
			if gs.dynasty_legacy_engine != null:
				gs.dynasty_legacy_engine.add_reputation(npc, 500)
			result_text = "\n👑\n Your dynasty becomes eternal."
			world_text = "\n👑\n %s %s used the Red Bonnet to crown their dynasty forever." % [
				npc.first_name,
				npc.last_name
			]
			diary_text = "I used the Red Bonnet to crown my dynasty forever."
			mythic_rank = "mythic"
		"spawn_artifacts", "summon cosmic artifacts":
			result_text = "\n \n All cosmic artifacts appear before me."
			world_text = "\n \n %s %s used the Red Bonnet to summon cosmic artifacts." % [
				npc.first_name,
				npc.last_name
			]
			diary_text = "I used the Red Bonnet to summon cosmic artifacts."
			mythic_rank = "mythic"

			_emit_targeted_bonnet_echo(npc, null, wish_key, world_text, diary_text, mythic_rank, false)

			if gs.artifacts_engine != null:
				for s in gs.artifacts_engine.STONES.keys():
					gs.artifacts_engine._give_stone(npc, s, {
						"source": "red_bonnet_wish",
						"event_source": "red_bonnet_engine",
						"skip_memory_append": true,
						"skip_world_feed": true,
						"suppress_fame_signal": true,
						"contract_resolution": contract_resolution.duplicate(true)
					})
				_red_bonnet_record_cosmic_artifact_synergy(npc, wish_key)

			if gs.event_bus != null:
				gs.event_bus.emit(ActionEventTypes.FAME_SPIKE, {
					"npc_id": npc.id,
					"artifact": "Infinity Stone",
					"text": "%s discovered impossible cosmic relics." % npc.first_name,
					"source": "red_bonnet_engine",
					"wish_name": wish_key,
					"mythic_rank": "mythic",
					"use_payload_text": true,
					"force_world_feed_only": true,
					"contract_resolution": contract_resolution.duplicate(true)
				})
				gs.event_bus.emit(ActionEventTypes.FAME_SPIKE, {
					"npc_id": npc.id,
					"text": "%s made a mythic Red Bonnet wish." % npc.first_name,
					"source": "red_bonnet_engine",
					"wish_name": wish_key,
					"mythic_rank": "mythic",
					"force_non_stone_text": true,
					"use_payload_text": true,
					"force_world_feed_only": true,
					"contract_resolution": contract_resolution.duplicate(true)
				})

			_red_bonnet_commit_bounded_rewrite(npc, wish_key, contract_resolution, {
				"result_text": result_text,
				"world_text": world_text,
				"diary_text": diary_text,
				"mythic_rank": mythic_rank,
				"wish_contract": wish_contract.duplicate(true)
			})
			return result_text
		"summon_dragon_balls", "summon dragon balls", "summon all dragon balls":
			var dragon_report: Dictionary = summon_dragon_balls_to_inventory({
				"actor": npc,
				"source": "red_bonnet_wish",
				"wish_key": wish_key,
				"contract_resolution": contract_resolution.duplicate(true)
			})
			if not bool(dragon_report.get("success", false)):
				return str(dragon_report.get("text", "The Dragon Balls refused to answer."))
			result_text = "\n🐉\n All 7 Dragon Balls appear in my inventory."
			world_text = "\n🐉\n %s %s used the Red Bonnet to summon all 7 Dragon Balls." % [
				npc.first_name,
				npc.last_name
			]
			diary_text = "I used the Red Bonnet to summon all 7 Dragon Balls."
			mythic_rank = "mythic"
			_emit_bonnet_echo(npc, wish_key, world_text, diary_text, mythic_rank)
			_red_bonnet_commit_bounded_rewrite(npc, wish_key, contract_resolution, {
				"result_text": result_text,
				"world_text": world_text,
				"diary_text": diary_text,
				"mythic_rank": mythic_rank,
				"dragonballs_report": dragon_report.duplicate(true),
				"wish_contract": wish_contract.duplicate(true)
			})
			return result_text
		_:
			return "Reality trembles, but nothing happened."

	_emit_bonnet_echo(npc, wish_key, world_text, diary_text, mythic_rank)
	_red_bonnet_commit_bounded_rewrite(npc, wish_key, contract_resolution, {
		"result_text": result_text,
		"world_text": world_text,
		"diary_text": diary_text,
		"mythic_rank": mythic_rank,
		"wish_contract": wish_contract.duplicate(true)
	})
	return result_text if result_text != "" else diary_text
func _emit_bonnet_echo(npc: Person, wish_key: String, world_text: String, diary_text: String, mythic_rank: String, emit_fame_spike: bool = true) -> void:
	if npc == null or gs == null:
		return

	if world_text != "":
		gs.push_world_feed(world_text, {
			"npc_id": npc.id,
			"personally_relevant": npc == gs.player,
			"category": "artifact",
			"event_name": ActionEventTypes.WISH_MADE,
			"source": "red_bonnet_engine",
			"wish_name": wish_key,
			"mythic_rank": mythic_rank,
			"suppress_diary": npc == gs.player
		})

	var emitted_to_bus:= false
	if gs.event_bus != null:
		emitted_to_bus = true
		gs.event_bus.emit(ActionEventTypes.WISH_MADE, {
			"npc_id": npc.id,
			"event_name": ActionEventTypes.WISH_MADE,
			"type": "text",
			"text": diary_text,
			"third_person_text": world_text.strip_edges(),
			"suppress_world_feed": true,
			"source": "red_bonnet_engine",
			"wish_name": wish_key,
			"mythic_rank": mythic_rank,
			"suppress_fame_signal": true
		})

	if emit_fame_spike and mythic_rank in ["legendary", "mythic"] and gs.event_bus != null:
		gs.event_bus.emit(ActionEventTypes.FAME_SPIKE, {
			"npc_id": npc.id,
			"text": "%s made a mythic Red Bonnet wish." % npc.first_name,
			"source": "red_bonnet_engine",
			"wish_name": wish_key,
			"mythic_rank": mythic_rank
		})

	if npc == gs.player:
		if not emitted_to_bus:
			if gs.narrative_engine != null:
				gs.narrative_engine.log_event(npc, {
					"type": "text",
					"text": diary_text
				})
			elif npc.memories != null and not npc.memories.has(diary_text):
				npc.memories.append(diary_text)
	else:
		if gs.memory_engine != null:
			gs.memory_engine.remember(npc.id, "Red Bonnet Wish: %s" % wish_key)
		if npc.memories != null and not npc.memories.has(diary_text):
			npc.memories.append(diary_text)

	if mythic_rank == "mythic" and gs.scenario_engine != null:
		gs.transient_scenario_biases [npc.id] = {
			"source": "red_bonnet_engine",
			"wish_name": wish_key,
			"mythic_rank": mythic_rank,
			"year": gs.year
		}

func get_asset_signal_rollup_for_owner(owner: Person) -> Dictionary:
	var out: Dictionary = {}
	if gs == null or owner == null:
		return out
	if int(owner_id) != int(owner.id):
		return out

	out ["asset_count"] = 1
	out ["dependency_pressure"] = 0.0
	out ["prestige_total"] = 6.0
	out ["modifier_weight"] = 0.0
	out ["portfolio_tags"] = {
		"portfolio_mood.mythic_style": 1,
		"portfolio_mood.folk_legend": 1
	}
	out ["event_hooks"] = {
		"devotee_attention": 1,
		"artifact_hunters": 1,
		"wish_seekers": 1
	}
	out ["passive_modifiers"] = {}
	out ["prestige_signals"] = {
		"legendary_presence": 5.0
	}
	out ["status_signals"] = {
		"public_attention": 4.0,
		"romance_signal": 4.0
	}
	out ["pressure_profile"] = {
		"spectacle": 4.0,
		"community_belonging": 2.0
	}
	out ["asset_namespaces"] = {
		"artifact.red_bonnet": 1
	}
	out ["asset_class_filters"] = {
		"artifact": 1
	}
	out ["asset_identity_modes"] = {
		"mythic_bearer": 1
	}
	out ["asset_tier_profile"] = {
		"mythic": 1.0
	}
	out ["asset_provenance_signals"] = {
		"chosen": 1.0
	}
	out ["asset_condition_profile"] = {
		"pristine": 1.0
	}
	out ["max_asset_tier_score"] = 5.0
	out ["asset_uniqueness_score"] = 5.0
	return out
func get_yearly_event_fragments_for_owner(owner: Person) -> Array:
	var out: Array = []
	if gs == null or owner == null:
		return out
	if int(owner_id) != int(owner.id):
		return out
	if int(owner.age) < 4:
		return out
	if int(owner.age) % 4 != 0:
		return out
	var yearly_text: String = "A near-mythic aura kept building around %s’s image this year." % owner.first_name
	if gs.player != null and int(owner.id) == int(gs.player.id):
		yearly_text = "A near-mythic aura kept building around my image this year."
	out.append({
		"text": "\n👑\n %s" % yearly_text,
		"category": "assets",
		"weight": 5
	})
	return out




func _revive_all():
	var revived:= 0
	var sealed:= 0
	for npc in gs.npcs:
		if npc == null:
			continue
		if npc.alive:
			continue
		if "SoulStoneSacrifice" in npc.traits:
			sealed += 1
			continue
		npc.alive = true
		npc.health = 100
		revived += 1

	if sealed > 0:
		return "%d souls returned to life. %d soul(s) sacrificed on Vormir remained beyond every wish." % [revived, sealed]
	return "%d souls returned to life." % revived






func handle_inheritance(payload):
	if owner_id == -1:
		return
	var dead_id = int(payload.get("npc_id", -1))
	if gs.should_skip_manual_player_inheritance(dead_id):
		return
	if dead_id != owner_id:
		return
	var dead_facts = gs.get_npc_facts_by_id(dead_id)
	if dead_facts == {}:
		return
	var dead = gs.get_npc_by_id(dead_id)
	if dead != null:
		dead.has_many_realms_ring = false
		dead.hidden_realm_visible = false
		dead.hidden_realm_title = ""
	var heir = gs.get_random_living_person_from_ids(dead_facts.get("children", []))
	if heir == null:
		owner_id = -1
		gs.push_world_feed("\nThe Red Bonnet vanishes from the world. All Smoke Shops Mourn lol.", {
			"npc_id": -1,
			"category": "artifact",
			"event_name": "red_bonnet_lost",
			"source": "red_bonnet_engine"
		})
		return
	_give_bonnet(heir)
func get_red_bonnet_action_specs(item: Dictionary) -> Array:
	var out: Array = []

	if gs == null or gs.player == null:
		return out

	var item_name: String = str(item.get("name", "")).strip_edges()
	if item_name != "Red Bonnet":
		return out

	var wishes: Array = get_available_wishes(gs.player)
	for wish_value in wishes:
		var wish_name: String = str(wish_value).strip_edges()
		if wish_name == "":
			continue
		out.append({
			"id": "red_bonnet_%s" % wish_name.to_lower().replace(" ", "_"),
			"label": wish_name,
			"item_family": "bonnet",
			"category": "self",
			"tone": "mythic",
			"mythic_rank": "mythic",
			"requires_target": false,
			"cooldown_key": "red_bonnet:%s" % wish_name.to_lower().replace(" ", "_"),
			"resolver_method": "perform_red_bonnet_action"
		})

	return out


func perform_red_bonnet_action(_item: Dictionary, action_name: String, _target: Person = null) -> Dictionary:
	if gs == null or gs.player == null:
		return { "success": false, "text": "No active life loaded."}

	var result_text: String = str(reality_wish(gs.player, action_name)).strip_edges()
	return {
		"success": result_text != "",
		"text": result_text,
		"popup_title": "Red Bonnet",
		"popup_text": result_text,
		"popup_footer": "Tap anywhere to continue."
	}
func nominate_scenarios_for_player(context:= {}) -> Array:
	var out: Array = []
	var player: Person = context.get("player", null)
	if gs == null or player == null or not player.alive:
		return out

	var player_has_bonnet: bool = int(owner_id) == int(player.id)

	if not player_has_bonnet and typeof(player.traits) == TYPE_ARRAY:
		player_has_bonnet = "RedBonnetBearer" in player.traits

	if not player_has_bonnet and gs.belongings_engine != null and gs.belongings_engine.has_method("has_item_named"):
		player_has_bonnet = bool(gs.belongings_engine.has_item_named(player, "Artifacts", "Red Bonnet"))

	if not player_has_bonnet:
		return out

	var year: int = int(context.get("year", 0))
	out.append({
		"id": "red_bonnet_devotee_surge_%d" % year,
		"source": "red_bonnet_engine",
		"category": "artifact",
		"era_tags": ["any"],
		"reality_modes": ["enhanced", "chaos"],
		"reality_weights": {
			"enhanced": 1.0,
			"chaos": 1.15
		},
		"tone": "sacred",
		"rarity": 0.71,
		"cooldown_key": "red_bonnet.devotees",
		"cooldown_years": 2,
		"priority": 15,
		"min_age": 12,
		"max_age": 130,
		"asset_namespace_preferences": { "artifact.red_bonnet": 3.0},
		"required_asset_event_hooks": ["devotee_attention"],
		"asset_identity_mode": ["mythic_bearer"],
		"asset_weight_status_signals": { "public_attention": 2.0, "romance_signal": 2.0},
		"asset_weight_pressure_profile": { "spectacle": 2.0, "community_belonging": 2.0},
		"asset_tier_floor": 4.0,
		"asset_uniqueness_bias": 2.9,
		"asset_arc_family": "red_bonnet_devotion",
		"asset_arc_step": "devotee_surge",
		"asset_repeat_group": "artifact.red_bonnet.devotion",
		"asset_echoes_world_feed": true,
		"asset_echoes_memory": true,
		"asset_echoes_reputation": true,
		"prompt": "A wave of attention around the bonnet is starting to feel devotional instead of normal. Do I shepherd it, soften it, or cut it off before it grows teeth?",
		"followup_hooks": ["artifact.red_bonnet.devotion.devotee_surge"],
		"bias_payloads": {},
		"choices": [
			{
				"id": "shepherd_it",
				"label": "Shepherd it and give it shape.",
				"journal_line": "I shepherded the attention around the bonnet before raw devotion could become something sloppy and dangerous.",
				"followup_hooks": ["artifact.red_bonnet.devotion.shepherd"],
				"bias_payloads": {
					"reputation_bias": { "public_attention": 4.0},
					"relationship_bias": { "social_visibility": 3.0},
					"expiry": { "years": 1}
				}
			},
			{
				"id": "soften_it",
				"label": "Soften the image and lower the heat.",
				"journal_line": "I softened the image around the bonnet before myth could start outrunning judgment.",
				"followup_hooks": ["artifact.red_bonnet.devotion.soften"],
				"bias_payloads": {
					"reputation_bias": { "public_attention": -1.0},
					"health_bias": { "stress_delta": -1.0},
					"expiry": { "years": 1}
				}
			},
			{
				"id": "cut_it_off",
				"label": "Cut it off and protect the center.",
				"journal_line": "I cut the devotion wave off before people could turn legend into access.",
				"followup_hooks": ["artifact.red_bonnet.devotion.cutoff"],
				"bias_payloads": {
					"crime_pressure": { "rumor_heat": 1.0},
					"relationship_bias": { "social_visibility": -1.0},
					"expiry": { "years": 1}
				}
			}
		]
	})
	out.append({
		"id": "red_bonnet_bloodline_claims_%d" % year,
		"source": "red_bonnet_engine",
		"category": "artifact",
		"era_tags": ["any"],
		"reality_modes": ["enhanced", "chaos"],
		"reality_weights": {
			"enhanced": 1.0,
			"chaos": 1.12
		},
		"tone": "mythic",
		"rarity": 0.66,
		"cooldown_key": "red_bonnet.bloodline_claims",
		"cooldown_years": 3,
		"priority": 14,
		"min_age": 14,
		"max_age": 130,
		"asset_namespace_preferences": { "artifact.red_bonnet": 3.0},
		"required_asset_event_hooks": ["wish_seekers"],
		"asset_identity_mode": ["mythic_bearer"],
		"asset_weight_status_signals": { "public_attention": 1.5},
		"asset_weight_pressure_profile": { "community_belonging": 2.0},
		"asset_tier_floor": 4.0,
		"asset_uniqueness_bias": 2.7,
		"asset_arc_family": "red_bonnet_lineage",
		"asset_arc_step": "bloodline_claims",
		"asset_repeat_group": "artifact.red_bonnet.lineage",
		"asset_echoes_world_feed": true,
		"asset_echoes_memory": true,
		"asset_echoes_reputation": true,
		"prompt": "People are starting to talk like the bonnet should belong to a bloodline, not a person. Do I reject that story, exploit it, or rewrite it on my terms?",
		"followup_hooks": ["artifact.red_bonnet.lineage.claims"],
		"bias_payloads": {},
		"choices": [
			{
				"id": "reject_the_story",
				"label": "Reject the bloodline story.",
				"journal_line": "I rejected the bloodline story before inheritance theater could start writing my life for me.",
				"followup_hooks": ["artifact.red_bonnet.lineage.reject"],
				"bias_payloads": {
					"reputation_bias": { "public_attention": 1.0},
					"expiry": { "years": 1}
				}
			},
			{
				"id": "exploit_it",
				"label": "Exploit it while the room believes.",
				"journal_line": "I exploited the story while belief was already doing half the work for me.",
				"followup_hooks": ["artifact.red_bonnet.lineage.exploit"],
				"bias_payloads": {
					"career_bias": { "ambition_weight": 3.0},
					"reputation_bias": { "public_attention": 3.0},
					"expiry": { "years": 1}
				}
			},
			{
				"id": "rewrite_it",
				"label": "Rewrite the story on my terms.",
				"journal_line": "I rewrote the story around the bonnet before other people could turn it into a cage with velvet on it.",
				"followup_hooks": ["artifact.red_bonnet.lineage.rewrite"],
				"bias_payloads": {
					"relationship_bias": { "social_visibility": 2.0},
					"health_bias": { "stress_delta": 1.0},
					"expiry": { "years": 1}
				}
			}
		]
	})
	return out