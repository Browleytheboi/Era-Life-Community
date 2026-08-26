extends Resource
class_name CharacterCreator

var gs

func _init(_gs):
	gs = _gs
func _safe_character_creator_era_name(settings: Dictionary = {}) -> String:
	var settings_name: String = str(settings.get("era_name", "")).strip_edges()
	if settings_name != "":
		return settings_name

	var settings_era: String = str(settings.get("era", settings.get("era_key", ""))).strip_edges()
	if settings_era != "":
		if settings_era.to_lower().ends_with(" era"):
			return settings_era
		return "%s Era" % settings_era

	if gs != null:
		if typeof(gs.era) == TYPE_DICTIONARY:
			var era_data: Dictionary = gs.era
			for key in ["name", "label", "title", "era_name"]:
				var candidate: String = str(era_data.get(key, "")).strip_edges()
				if candidate != "":
					return candidate

		if typeof(gs.era) == TYPE_OBJECT:
			var era_obj: Object = gs.era
			if era_obj != null:
				for key in ["name", "label", "title", "era_name"]:
					var candidate: String = str(era_obj.get(key)).strip_edges()
					if candidate != "" and candidate != "<null>":
						return candidate

	return "Modern Era"
func _character_creator_elemental_royal_nations() -> Array:
	return ["Air Nomads", "Water Tribe", "Earth Kingdom", "Fire Nation"]


func _character_creator_royal_nation_from_settings(settings: Dictionary = {}, player: Person = null) -> String:
	var elemental_nations: Array = _character_creator_elemental_royal_nations()

	var explicit_nation: String = str(settings.get("royal_nation", settings.get("royal_realm_country", settings.get("bending_nation", "")))).strip_edges()
	if elemental_nations.has(explicit_nation):
		return explicit_nation

	var selected_country: String = str(settings.get("country", "")).strip_edges()
	var selected_bending: String = str(settings.get("bending_type", "none")).strip_edges().to_lower()

	if selected_bending == "avatar" and elemental_nations.has(selected_country):
		return selected_country

	match selected_bending:
		"air":
			return "Air Nomads"
		"water":
			return "Water Tribe"
		"earth":
			return "Earth Kingdom"
		"fire":
			return "Fire Nation"

	if player != null:
		var player_nation: String = str(player.bending_nation).strip_edges()
		if elemental_nations.has(player_nation):
			return player_nation

	if elemental_nations.has(selected_country):
		return selected_country

	return selected_country


func _build_character_birth_origin_contract(player: Person, settings: Dictionary = {}) -> Dictionary:
	var forced_social_class: String = str(settings.get("social_class", "")).strip_edges()
	if forced_social_class != "Royal" and forced_social_class != "Noble":
		return {}

	var raw_rank_seed: String = str(settings.get("royal_rank", "")).strip_edges()
	var rank_text: String = raw_rank_seed.to_lower()
	var player_position: String = "royal_child"

	if rank_text.find("heir") != -1 or rank_text.find("crown") != -1:
		player_position = "primary_heir"
	elif rank_text.find("duke") != -1 or rank_text.find("duchess") != -1 or rank_text.find("ducal") != -1:
		player_position = "ducal_line"
	elif rank_text.find("marquess") != -1 or rank_text.find("marchioness") != -1 or rank_text.find("marcher") != -1:
		player_position = "marcher_line"
	elif forced_social_class == "Noble":
		player_position = "lesser_royal"

	var royal_nation: String = _character_creator_royal_nation_from_settings(settings, player)
	var selected_country: String = str(settings.get("country", "")).strip_edges()
	var selected_city: String = str(settings.get("city", "")).strip_edges()
	var requested_ruling_parent: String = str(settings.get("royal_ruling_parent", settings.get("ruler_parent", settings.get("ruling_parent", "auto")))).strip_edges()

	return {
		"schema": "eralife.birth_origin_contract",
		"version": 1,
		"origin_type": "royal_heir_birth" if player_position == "primary_heir" else "royal_birth",
		"family_contract": {
			"generate_house": bool(settings.get("generate_family", true)),
			"succession_mode": str(settings.get("succession_mode", "primogeniture")),
			"player_position": player_position,
			"rank_seed": raw_rank_seed,
			"requested_ruling_parent": requested_ruling_parent,
		},
		"social_contract": {
			"class": forced_social_class,
			"starting_reputation": 92 if forced_social_class == "Royal" else 64,
			"public_visibility": 0.88 if forced_social_class == "Royal" else 0.52
		},
		"lineage_contract": {
			"generate_ancestors": 4,
		},
		"world_integration": {
			"inject_into_nation_ruler_chain": forced_social_class == "Royal",
			"generate_political_expectations": forced_social_class == "Royal"
		},
		"nation_contract": {
			"royal_nation": royal_nation,
			"selected_country": selected_country,
			"selected_city": selected_city,
			"use_elemental_title_style": _character_creator_elemental_royal_nations().has(royal_nation)
		}
	}



func create_custom_player(settings: Dictionary) -> Person:
	if settings.has("pending_reincarnation_slot"):
		var reincarnated_child: Person = gs.create_custom_reincarnated_child(settings)
		if reincarnated_child != null:
			return reincarnated_child

	var p = gs.npc_factory.create_random_npc(false)
	var requested_starting_age: int = int(settings.get("starting_age", settings.get("age", 0)))
	p.age = int(clamp(requested_starting_age, 0, 120))
	var era_name: String = _safe_character_creator_era_name(settings)

	if settings.has("reality_mode"):
		gs.custom_settings ["reality_mode"] = settings ["reality_mode"]
	if settings.has("feature_overrides"):
		gs.custom_settings ["feature_overrides"] = settings ["feature_overrides"].duplicate()
	gs._hydrate_reality_settings()




	if settings.has("first_name") and settings.first_name != "":
		p.first_name = settings.first_name
	else:
		p.first_name = gs.names_db.random_first_for_era(p.gender, era_name)


	if settings.has("last_name") and settings.last_name != "":
		p.last_name = settings.last_name
	else:
		var auto_city:= str(settings.get("city", "")).strip_edges()
		var auto_country:= str(settings.get("country", "")).strip_edges()
		p.last_name = gs.names_db.last_name_for_birthplace(
			era_name,
			auto_city,
			auto_country
		)
		if p.last_name.strip_edges() == "":
			p.last_name = gs.names_db.random_last_for_era(era_name)


	gs.dynasty_engine.register_dynasty(p.last_name)




	if settings.has("gender"):
		p.gender = settings.gender

	if settings.has("city"):
		p.birth_city = settings.city
		p.home_city = settings.city
	if settings.has("state"):
		p.birth_state = str(settings.get("state", "")).strip_edges()
		p.home_state = str(settings.get("state", "")).strip_edges()
	if settings.has("country"):
		p.birth_country = settings.country
		p.home_country = settings.country


	if settings.has("month"):
		p.birthday.month = settings.month
	if settings.has("day"):
		p.birthday.day = settings.day


	p.zodiac = gs.npc_factory._get_zodiac(p.birthday.month, p.birthday.day)

	if settings.has("smarts"):
		p.smarts = settings.smarts
	if settings.has("looks"):
		p.looks = settings.looks
	if settings.has("health"):
		p.health = settings.health
	if settings.has("mental_health"):
		p.mental_health = settings.mental_health
	if settings.has("satisfaction"):
		p.satisfaction = settings.satisfaction
	if settings.has("fertility"):
		p.fertility = float(settings.fertility)
	if settings.has("imagination"):
		p.imagination = int(clamp(settings ["imagination"], 0, 100))
	elif int(p.imagination) <= 0:
		p.imagination = randi_range(1, 79)
	if settings.has("bank_balance"):
		p.bank_balance = settings.bank_balance
	if settings.has("traits"):
		p.traits = settings.traits.duplicate()
	var forced_social_class:= str(settings.get("social_class", "")).strip_edges()
	if forced_social_class != "" and forced_social_class != "Random / Era Default":
		p.social_class = forced_social_class

	var birth_origin_contract: Dictionary = _build_character_birth_origin_contract(p, settings)
	if not birth_origin_contract.is_empty():
		settings ["_birth_origin_contract"] = birth_origin_contract.duplicate(true)

	gs.apply_reality_rules_to_person(p)
	if gs.bridge_to_terabithia_engine != null:
		gs.bridge_to_terabithia_engine.ensure_person_imagination_state(p)
	if bool(settings.get("choose_adventure_lineage_birth", false)) and gs.lineage_engine != null and gs.lineage_engine.has_method("create_player_from_lineage_contract"):
		var lineage_player: Person = gs.lineage_engine.create_player_from_lineage_contract(p, settings)
		if lineage_player != null:
			if settings.has("era") and gs.era_engine.eras.has(settings.era):
				gs.era = gs.era_engine.eras [settings.era]
			return lineage_player



	if settings.has("generate_family") and settings.generate_family == false:
		p.parents = []
		if forced_social_class in ["Royal", "Noble"] and gs.royalty_engine != null:
			gs.royalty_engine.setup_custom_player_solo_crown_identity(p, settings)
			if gs.royalty_engine.has_method("get_royal_birth_memory"):
				var royal_birth_memory: String = gs.royalty_engine.get_royal_birth_memory(p)
				var has_royal_birth_memory: bool = false
				for raw_memory in p.memories:
					if str(raw_memory).findn(royal_birth_memory) != -1:
						has_royal_birth_memory = true
						break
				if not has_royal_birth_memory:
					p.memories.append(royal_birth_memory)
		else:
			if gs.royalty_engine != null:
				gs.royalty_engine.clear_royal_identity(p)
			p.memories.append(gs.era_engine.get_conception_story())

		if settings.has("era"):
			gs.era = gs.era_engine.eras [settings.era]
		return p





	var family_last = p.last_name
	var father = gs.npc_factory._create_parent("Male", p.home_city, p.home_country)
	var mother = gs.npc_factory._create_parent("Female", p.home_city, p.home_country)

	if gs.npc_factory != null:
		gs.npc_factory.align_immediate_family_stats_to_child(p, father, mother)

	gs.apply_reality_rules_to_person(father)
	gs.apply_reality_rules_to_person(mother)

	mother.maiden_last_name = mother.last_name

	father.last_name = family_last
	mother.last_name = family_last
	father.partner = mother
	mother.partner = father
	father.marital_status = "Married"
	mother.marital_status = "Married"
	p.parents = [father.id, mother.id]
	gs.npcs.append(father)
	gs.npcs.append(mother)
	_generate_player_siblings(p, mother, father, settings)






	gs.npc_factory.ensure_parent_lineage(mother, mother.maiden_last_name)
	gs.npc_factory.ensure_parent_lineage(father, father.last_name)
	if gs.npc_factory.has_method("ensure_extended_family_for_controlled_person"):
		gs.npc_factory.ensure_extended_family_for_controlled_person(p, {
			"source": "character_creator_custom_player_spawn"
		})

	if forced_social_class != "" and forced_social_class != "Random / Era Default" and gs.class_engine != null:
		gs.class_engine.apply_family_class_seed(p, forced_social_class)

	if gs.royalty_engine != null:
		if forced_social_class == "Royal":
			gs.royalty_engine.setup_custom_player_royal_lineage(p, settings)
		elif forced_social_class == "Noble":
			gs.royalty_engine.setup_custom_player_noble_lineage(p, settings)
		elif forced_social_class != "" and forced_social_class != "Random / Era Default":
			gs.royalty_engine.clear_custom_player_house_royal_identity(p)

	if gs.career_engine != null:
		gs.career_engine.reseed_household_jobs_for_class(p)








	if forced_social_class in ["Royal", "Noble"] and gs.royalty_engine != null and gs.royalty_engine.has_method("get_royal_birth_memory"):
		p.memories.append(gs.royalty_engine.get_royal_birth_memory(p))
	else:
		p.memories.append(gs.era_engine.get_conception_story())





	if settings.has("era"):
		gs.era = gs.era_engine.eras [settings.era]
	if p.age >= 5 and gs.school_engine != null:
		if settings.has("school_mode"):
			match settings ["school_mode"]:
				"era_school":
					gs.school_engine.enroll_in_era_school(p)

				"bending_school":
					if gs.is_feature_enabled("supernatural_school"):
						gs.school_engine.enroll_in_bending_school(p)
					else:
						gs.school_engine.enroll_in_era_school(p)

				"dual":
					if gs.is_feature_enabled("supernatural_school"):
						gs.school_engine.enroll_dual(p)
					else:
						gs.school_engine.enroll_in_era_school(p)






	if gs.is_feature_enabled("bending") and settings.has("bending_type"):
		var bt = settings ["bending_type"]
		if bt in ["air", "earth", "fire", "water", "avatar", "none"]:
			p.bending_type = bt
			p.bending_mastery = {}
			match bt:
				"air":
					p.bending_nation = "Air Nomads"
				"earth":
					p.bending_nation = "Earth Kingdom"
				"fire":
					p.bending_nation = "Fire Nation"
				"water":
					p.bending_nation = "Water Tribe"
				"avatar":
					p.bending_nation = _avatar_birth_nation_from_settings(settings, p)
				"none":
					p.bending_nation = ""
			if bt != "none":
				p.bending_latent_potential = {}

				if bt == "avatar":
					for element in ["air", "earth", "fire", "water"]:
						p.bending_mastery [element] = 0
						p.bending_latent_potential [element] = 0

					if gs.bending_engine != null:
						gs.bending_engine.ensure_bending_level_state(p)
						for element in ["air", "earth", "fire", "water"]:
							gs.bending_engine.seed_birth_bending_potential(p, element, 2)

						var avatar_native_element:= "none"
						if gs.bending_engine.has_method("_element_from_nation"):
							avatar_native_element = str(gs.bending_engine._element_from_nation(p.bending_nation)).strip_edges().to_lower()

						if avatar_native_element in ["air", "earth", "fire", "water"]:
							var native_potential: int = gs.bending_engine.seed_birth_bending_potential(p, avatar_native_element, 3)
							p.bending_latent_potential [avatar_native_element] = max(
								int(p.bending_latent_potential.get(avatar_native_element, 0)),
								native_potential
							)
				else:
					for element in ["air", "earth", "fire", "water"]:
						p.bending_mastery [element] = 0
						p.bending_latent_potential [element] = 0

					if gs.bending_engine != null:
						gs.bending_engine.ensure_bending_level_state(p)
						gs.bending_engine.seed_birth_bending_potential(p, bt, 2)

				if gs.bending_engine != null:
					gs.bending_engine.ensure_bending_level_state(p)

			var family_members: Array = []
			var seen: Dictionary = {}
			for pid in p.parents:
				var par: Person = gs.get_npc_by_id(int(pid))
				if par != null:
					if not seen.has(par.id):
						family_members.append(par)
						seen [par.id] = true

					for sibling_id in par.children:
						var sibling: Person = gs.get_npc_by_id(int(sibling_id))
						if sibling != null and int(sibling.id) != int(p.id) and not seen.has(sibling.id):
							family_members.append(sibling)
							seen [sibling.id] = true

					for gpid in par.parents:
						var gp: Person = gs.get_npc_by_id(int(gpid))
						if gp != null:
							if not seen.has(gp.id):
								family_members.append(gp)
								seen [gp.id] = true

							for ggpid in gp.parents:
								var ggp: Person = gs.get_npc_by_id(int(ggpid))
								if ggp != null and not seen.has(ggp.id):
									family_members.append(ggp)
									seen [ggp.id] = true

			gs.bending_engine.sync_family_bending(p, family_members)
			if str(settings.get("social_class", "")).strip_edges() == "Royal" and gs.royalty_engine != null:
				gs.royalty_engine.apply_bending_royal_theme(p, settings)
			if p.bending_type == "avatar":
				p.fame = max(p.fame, 100)
				p.fame_tier = "Legend"
				p.social_class = "Mythic"
				if str(settings.get("social_class", "")).strip_edges() != "Royal":
					p.memories.append("My soul was chosen to become the next Avatar, Master of 4 Elements.")

				if gs.bending_engine != null and gs.bending_engine.has_method("mark_player_avatar_cycle_birth"):
					gs.bending_engine.mark_player_avatar_cycle_birth(p, {
						"source": "character_creator",
						"settings": settings.duplicate(true),
						"birth_city": str(p.birth_city),
						"birth_country": str(p.birth_country)
					})
		else:
			p.bending_type = "none"
			p.bending_nation = ""
			p.bending_mastery = {}
			p.avatar_state_unlocked = false
			p.avatar_state_used = false

	return p
func _avatar_birth_nation_from_settings(settings: Dictionary, player: Person = null) -> String:
	var candidate_keys: Array = [
		"avatar_base_nation",
		"avatar_birth_nation",
		"bending_nation",
		"birth_country",
		"country",
		"home_country",
		"native_nation"
	]

	for key in candidate_keys:
		var candidate: String = str(settings.get(key, "")).strip_edges()
		var normalized_candidate: String = _character_creator_normalize_avatar_birth_nation(candidate)
		if normalized_candidate != "":
			return normalized_candidate

	if player != null:
		for candidate in [player.birth_country, player.home_country, player.bending_nation]:
			var normalized_player_candidate: String = _character_creator_normalize_avatar_birth_nation(str(candidate))
			if normalized_player_candidate != "":
				return normalized_player_candidate

	if gs != null and gs.bending_engine != null:
		if gs.bending_engine.has_method("_normalize_avatar_birth_nation"):
			for key in candidate_keys:
				var engine_candidate: String = str(settings.get(key, "")).strip_edges()
				var engine_normalized: String = str(gs.bending_engine._normalize_avatar_birth_nation(engine_candidate)).strip_edges()
				if engine_normalized != "":
					return engine_normalized
		if gs.bending_engine.NATIONS.size() > 0:
			return _character_creator_normalize_avatar_birth_nation(str(gs.bending_engine.NATIONS.pick_random()))

	return ""
func _character_creator_normalize_avatar_birth_nation(nation: String) -> String:
	var clean_nation: String = str(nation).strip_edges()
	if clean_nation == "":
		return ""

	var key: String = clean_nation.to_lower()

	match clean_nation:
		"Northern Water Tribe":
			return "Northern Water Tribe"
		"Southern Water Tribe":
			return "Southern Water Tribe"
		"Water Tribe", "Water Nation":
			return "Water Tribe"
		"Fire Nation":
			return "Fire Nation"
		"Earth Kingdom", "Earth Nation":
			return "Earth Kingdom"
		"Air Nomads", "Air Temples", "Air Nation", "Northern Air Temple", "Southern Air Temple", "Eastern Air Temple", "Western Air Temple":
			return "Air Nomads"

	if key.find("northern") != -1 and key.find("water") != -1:
		return "Northern Water Tribe"
	if key.find("southern") != -1 and key.find("water") != -1:
		return "Southern Water Tribe"
	if key.find("water") != -1:
		return "Water Tribe"
	if key.find("fire") != -1:
		return "Fire Nation"
	if key.find("earth") != -1:
		return "Earth Kingdom"
	if key.find("air") != -1:
		return "Air Nomads"

	return ""
func _generate_player_siblings(player: Person, mom: Person, dad: Person, settings: Dictionary = {}) -> void:
	if player == null or mom == null or dad == null:
		return

	var max_siblings: int = 3
	match gs.era.name:
		"Ancient":
			max_siblings = 8
		"Medieval":
			max_siblings = 7
		"Industrial":
			max_siblings = 6
		_:
			max_siblings = 5

	var forced_social_class: String = str(settings.get("social_class", "")).strip_edges()
	var royal_rank_seed: String = str(settings.get("royal_rank", "")).strip_edges()
	if gs != null and gs.royalty_engine != null and gs.royalty_engine.has_method("_normalize_royal_rank_seed"):
		royal_rank_seed = str(gs.royalty_engine._normalize_royal_rank_seed(royal_rank_seed))

	var player_must_be_oldest: bool = forced_social_class == "Royal" and royal_rank_seed == "Heir Line"
	var player_should_have_older_heir_sibling: bool = forced_social_class == "Royal" and royal_rank_seed == "Royal Child"

	if player_must_be_oldest and int(player.age) <= 0:
		return

	var sibling_count: int = randi_range(0, max_siblings)
	if player_should_have_older_heir_sibling:
		sibling_count = max(1, sibling_count)
	if player_must_be_oldest:
		sibling_count = min(sibling_count, max(0, int(player.age)))

	for i in range(sibling_count):
		var sib: Person = gs.npc_factory.create_child(dad, mom)
		if sib == null:
			continue

		var max_age_gap: int = max(1, min(int(mom.age) - 16, int(dad.age) - 16))

		if player_must_be_oldest:
			var younger_ceiling: int = max(0, min(int(player.age) - 1, max_age_gap))
			if younger_ceiling <= 0:
				sib.age = 0
			else:
				sib.age = clamp(randi_range(0, younger_ceiling), 0, 40)
		else:
			sib.age = clamp(randi_range(1, max(1, max_age_gap)), 0, 40)
			if int(sib.age) <= int(player.age):
				sib.age = randi_range(1, min(25, max_age_gap))

		gs.apply_reality_rules_to_person(sib)
		gs.register_npc(sib)

		if gs.npc_factory != null and gs.npc_factory.has_method("_maybe_seed_collateral_children_for_relative"):
			gs.npc_factory._maybe_seed_collateral_children_for_relative(player, sib, {
				"source": "character_creator_player_sibling_spawn",
				"relationship_lane": "sibling"
			})