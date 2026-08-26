extends Resource
class_name NPCFactory

var gs

func _init(_gs):
	gs = _gs


func _get_random_conception_story() -> String:
	var _stories = [
		"I was conceived under mysterious circumstances."
	]
	return gs.era_engine.get_conception_story()




func _get_zodiac(month: int, day: int) -> String:
	if (month == 3 and day >= 21) or (month == 4 and day <= 19): return "Aries"
	if (month == 4 and day >= 20) or (month == 5 and day <= 20): return "Taurus"
	if (month == 5 and day >= 21) or (month == 6 and day <= 20): return "Gemini"
	if (month == 6 and day >= 21) or (month == 7 and day <= 22): return "Cancer"
	if (month == 7 and day >= 23) or (month == 8 and day <= 22): return "Leo"
	if (month == 8 and day >= 23) or (month == 9 and day <= 22): return "Virgo"
	if (month == 9 and day >= 23) or (month == 10 and day <= 22): return "Libra"
	if (month == 10 and day >= 23) or (month == 11 and day <= 21): return "Scorpio"
	if (month == 11 and day >= 22) or (month == 12 and day <= 21): return "Sagittarius"
	if (month == 12 and day >= 22) or (month == 1 and day <= 19): return "Capricorn"
	if (month == 1 and day >= 20) or (month == 2 and day <= 18): return "Aquarius"
	if (month == 2 and day >= 19) or (month == 3 and day <= 20): return "Pisces"
	return "Unknown"





func _era_min_age() -> int:
	match gs.era.name:
		"Ancient Era": return 20
		"Medieval Era": return 20
		"Industrial Era": return 25
		"Modern Era": return 30
		"Future Era": return 40
	return 20

func _era_max_age() -> int:
	match gs.era.name:
		"Ancient Era": return 80
		"Medieval Era": return 85
		"Industrial Era": return 90
		"Modern Era": return 100
		"Future Era": return 140
	return 100

func _clamp_age_by_era(age: int) -> int:
	return clamp(age, _era_min_age(), _era_max_age())
func _realm_generation_profile(realm_id: Variant) -> Dictionary:
	if gs == null or gs.simulation_contract_engine == null:
		return {}
	if not gs.simulation_contract_engine.has_method("get_npc_generation_profile_for_realm"):
		return {}
	return gs.simulation_contract_engine.get_npc_generation_profile_for_realm(realm_id)

func _weighted_key(weights: Dictionary, fallback: String = "") -> String:
	if weights.is_empty():
		return fallback
	var total: float = 0.0
	for key in weights.keys():
		total += max(0.0, float(weights [key]))
	if total <= 0.0:
		return fallback
	var roll: float = randf() * total
	var cursor: float = 0.0
	for key in weights.keys():
		cursor += max(0.0, float(weights [key]))
		if roll <= cursor:
			return str(key)
	return fallback

func _apply_realm_generation_profile(npc: Person, realm_id: Variant, profile: Dictionary) -> void:
	if npc == null or profile.is_empty():
		return

	var realm_key: String = str(realm_id).strip_edges()
	var realm_id_int: int = int(realm_key) if realm_key.is_valid_int() else -1
	if realm_id_int >= 0:
		npc.realm_id = realm_id_int

	var age_bounds_raw: Variant = profile.get("age_bounds", {})
	var age_bounds: Dictionary = age_bounds_raw if typeof(age_bounds_raw) == TYPE_DICTIONARY else {}
	if not age_bounds.is_empty():
		var min_age: int = int(age_bounds.get("min", age_bounds.get("minimum", _era_min_age())))
		var max_age: int = int(age_bounds.get("max", age_bounds.get("maximum", _era_max_age())))
		if max_age < min_age:
			max_age = min_age
		npc.age = clamp(int(npc.age), min_age, max_age)

	var social_class_weights_raw: Variant = profile.get("social_class_weights", {})
	var social_class_weights: Dictionary = social_class_weights_raw if typeof(social_class_weights_raw) == TYPE_DICTIONARY else {}
	var social_class: String = _weighted_key(social_class_weights, "")
	if social_class != "":
		npc.social_class = social_class

	var trait_weights_raw: Variant = profile.get("trait_weights", {})
	var trait_weights: Dictionary = trait_weights_raw if typeof(trait_weights_raw) == TYPE_DICTIONARY else {}
	if not trait_weights.is_empty():
		var trait_name: String = _weighted_key(trait_weights, "")
		if trait_name != "" and trait_name not in npc.traits:
			npc.traits.append(trait_name)

	var job_weights_raw: Variant = profile.get("job_weights", {})
	var job_weights: Dictionary = job_weights_raw if typeof(job_weights_raw) == TYPE_DICTIONARY else {}
	if not job_weights.is_empty() and int(npc.age) >= 18:
		var job_name: String = _weighted_key(job_weights, "")
		if job_name != "":
			npc.job = job_name

	var bending_profile_raw: Variant = profile.get("bending_profile", {})
	var bending_profile: Dictionary = bending_profile_raw if typeof(bending_profile_raw) == TYPE_DICTIONARY else {}
	if not bending_profile.is_empty() and gs != null and gs.bending_engine != null:
		if gs.bending_engine.has_method("apply_generation_profile_to_npc"):
			gs.bending_engine.apply_generation_profile_to_npc(npc, bending_profile)




func _create_base_npc() -> Person:
	var npc:= Person.new()
	npc.id = gs.next_id
	gs.next_id += 1
	npc.gender = ["Male", "Female"] [randi() % 2]
	npc.first_name = gs.names_db.random_first_for_era(npc.gender, gs.era.name)
	var locs = gs.era_engine.get_birth_locations()
	var place = locs [randi() % locs.size()]
	npc.birth_city = place ["city"]
	npc.birth_country = place ["country"]
	npc.home_city = npc.birth_city
	npc.home_country = npc.birth_country
	npc.last_name = gs.names_db.last_name_for_birthplace(
		gs.era.name,
		npc.birth_city,
		npc.birth_country
	)
	npc.age = randi_range(_era_min_age(), _era_max_age())
	npc.traits = []
	npc.smarts = randi() % 100
	npc.looks = randi() % 100
	npc.health = randf() * 100
	npc.mental_health = randf() * 100
	npc.parents = []
	npc.children = []
	npc.memories = []
	npc.job = ""
	npc.bank_balance = randf_range(1000, 500000) if npc.age >= 18 else 0.0
	gs.capability_graph_engine.initialize_npc(npc)
	gs.event_bus.emit(ActionEventTypes.NPC_BORN, { "npc_id": npc.id})
	return npc


func _append_unique_npc(npc: Person) -> void:
	if npc == null:
		return
	if gs.get_npc_by_id(npc.id) == null:
		gs.npcs.append(npc)


func _link_parent_child(parent: Person, child: Person) -> void:
	if parent == null or child == null:
		return

	if parent.id not in child.parents:
		child.parents.append(parent.id)

	if child.id not in parent.children:
		parent.children.append(child.id)

	if gs.social_graph_engine != null:
		gs.social_graph_engine.connect_people(child.id, parent.id)


func _create_great_grandparent(gender: String, last_name: String, grandparent_age: int) -> Person:
	var ggp:= Person.new()
	ggp.id = gs.next_id
	gs.next_id += 1
	ggp.gender = gender
	ggp.last_name = last_name
	ggp.children = []
	ggp.parents = []
	ggp.memories = []
	var used_names:= []
	for npc in gs.npcs:
		if npc.age > 35:
			used_names.append(npc.first_name)
	var tries:= 0
	while tries < 20:
		var candidate = gs.names_db.random_first_for_era(gender, gs.era.name)
		if not used_names.has(candidate):
			ggp.first_name = candidate
			break
		tries += 1
	if ggp.first_name == "" or ggp.first_name == null:
		ggp.first_name = gs.names_db.random_first_for_era(gender, gs.era.name)

	var effective_grandparent_age: int = maxi(18, grandparent_age + randi_range(-6, 6))
	var min_age = effective_grandparent_age + 18
	var max_age = min(effective_grandparent_age + 40, _era_max_age())
	if max_age < min_age:
		max_age = min_age

	ggp.age = randi_range(min_age, max_age)
	var pool = gs.era_engine.get_job_pool()
	if ggp.age < 65:
		ggp.job = pool [randi() % pool.size()]
	else:
		ggp.job = "Retired" if randi() % 100 >= 20 else pool [randi() % pool.size()]


	var death_roll:= randi() % 100
	if ggp.age >= 95:
		if death_roll < 85:
			ggp.alive = false
			ggp.health = 0
			ggp.cause_of_death = "Old age"
	elif ggp.age >= 85:
		if death_roll < 55:
			ggp.alive = false
			ggp.health = 0
			ggp.cause_of_death = "Old age"
		else:
			ggp.alive = true
	if ggp.alive:
		ggp.health = max(ggp.health, randf_range(20.0, 75.0))
		ggp.mental_health = max(ggp.mental_health, randf_range(20.0, 80.0))
	return ggp


func _attach_generated_great_grandparents_to_grandparent(grandparent: Person, family_last_name: String = "") -> void:
	if grandparent == null:
		return

	if grandparent.parents.size() >= 2:
		return

	var last_name_to_use:= family_last_name
	if last_name_to_use == "":
		if grandparent.gender == "Female" and grandparent.maiden_last_name != "":
			last_name_to_use = grandparent.maiden_last_name
		else:
			last_name_to_use = grandparent.last_name

	var ggp_father:= _create_great_grandparent("Male", last_name_to_use, grandparent.age)
	var ggp_mother:= _create_great_grandparent("Female", last_name_to_use, grandparent.age)
	ggp_father.home_city = grandparent.home_city
	ggp_father.home_country = grandparent.home_country
	ggp_father.birth_city = grandparent.home_city
	ggp_father.birth_country = grandparent.home_country
	ggp_mother.home_city = grandparent.home_city
	ggp_mother.home_country = grandparent.home_country
	ggp_mother.birth_city = grandparent.home_city
	ggp_mother.birth_country = grandparent.home_country
	ggp_father.partner = ggp_mother
	ggp_mother.partner = ggp_father
	ggp_father.marital_status = "Married"
	ggp_mother.marital_status = "Married"
	gs.apply_reality_rules_to_person(ggp_father)
	gs.apply_reality_rules_to_person(ggp_mother)
	_append_unique_npc(ggp_father)
	_append_unique_npc(ggp_mother)
	grandparent.parents = []
	_link_parent_child(ggp_father, grandparent)
	_link_parent_child(ggp_mother, grandparent)


func _attach_generated_grandparents_to_parent(parent: Person, family_last_name: String = "") -> void:
	if parent == null:
		return

	if parent.parents.size() >= 2:

		for gpid in parent.parents:
			var existing_gp: Person = gs.get_npc_by_id(int(gpid))
			if existing_gp != null:
				var gp_ln:= existing_gp.last_name
				if existing_gp.gender == "Female" and existing_gp.maiden_last_name != "":
					gp_ln = existing_gp.maiden_last_name
				_attach_generated_great_grandparents_to_grandparent(existing_gp, gp_ln)
		return

	var last_name_to_use:= family_last_name
	if last_name_to_use == "":
		if parent.gender == "Female" and parent.maiden_last_name != "":
			last_name_to_use = parent.maiden_last_name
		else:
			last_name_to_use = parent.last_name

	var gp_father:= _create_grandparent("Male", last_name_to_use, parent.age)
	var gp_mother:= _create_grandparent("Female", last_name_to_use, parent.age)
	gp_father.home_city = parent.home_city
	gp_father.home_country = parent.home_country
	gp_father.birth_city = parent.home_city
	gp_father.birth_country = parent.home_country
	gp_mother.home_city = parent.home_city
	gp_mother.home_country = parent.home_country
	gp_mother.birth_city = parent.home_city
	gp_mother.birth_country = parent.home_country
	gp_father.partner = gp_mother
	gp_mother.partner = gp_father
	gp_father.marital_status = "Married"
	gp_mother.marital_status = "Married"
	gs.apply_reality_rules_to_person(gp_father)
	gs.apply_reality_rules_to_person(gp_mother)
	_append_unique_npc(gp_father)
	_append_unique_npc(gp_mother)
	parent.parents = []
	_link_parent_child(gp_father, parent)
	_link_parent_child(gp_mother, parent)

	var gp_father_last:= gp_father.last_name
	if gp_father.gender == "Female" and gp_father.maiden_last_name != "":
		gp_father_last = gp_father.maiden_last_name

	var gp_mother_last:= gp_mother.last_name
	if gp_mother.gender == "Female" and gp_mother.maiden_last_name != "":
		gp_mother_last = gp_mother.maiden_last_name

	_attach_generated_great_grandparents_to_grandparent(gp_father, gp_father_last)
	_attach_generated_great_grandparents_to_grandparent(gp_mother, gp_mother_last)


func ensure_family_lineage(npc: Person) -> void:
	if npc == null:
		return

	if npc.parents.size() < 2:
		var father:= _create_parent_for_child("Male", npc)
		var mother:= _create_parent_for_child("Female", npc)
		father.last_name = npc.last_name
		mother.maiden_last_name = mother.last_name
		mother.last_name = npc.last_name
		father.home_city = npc.home_city
		father.home_country = npc.home_country
		father.birth_city = npc.home_city
		father.birth_country = npc.home_country
		mother.home_city = npc.home_city
		mother.home_country = npc.home_country
		mother.birth_city = npc.home_city
		mother.birth_country = npc.home_country
		gs.apply_reality_rules_to_person(father)
		gs.apply_reality_rules_to_person(mother)
		_register_extended_family_npc(father)
		_register_extended_family_npc(mother)
		npc.parents = []
		_link_parent_child(father, npc)
		_link_parent_child(mother, npc)
		father.partner = mother
		mother.partner = father
		father.marital_status = "Married"
		mother.marital_status = "Married"
		_attach_generated_grandparents_to_parent(mother, mother.maiden_last_name)
		_attach_generated_grandparents_to_parent(father, father.last_name)
		ensure_extended_family_for_controlled_person(npc, {
			"source": "ensure_family_lineage_created_parent_pair"
		})
		return

	for pid in npc.parents:
		var parent: Person = gs.get_or_reactivate_npc_by_id(int(pid))
		if parent != null:
			if int(parent.age) < int(npc.age) + 16:
				parent.age = int(npc.age) + 28
			if int(parent.age) >= 95:
				parent.alive = false
				parent.health = 0
				parent.cause_of_death = "Old age"
			var ln: String = parent.last_name
			if parent.gender == "Female" and parent.maiden_last_name != "":
				ln = parent.maiden_last_name
			_attach_generated_grandparents_to_parent(parent, ln)

	ensure_extended_family_for_controlled_person(npc, {
		"source": "ensure_family_lineage_existing_parent_pair"
	})
func _birth_shell_lineage_identity_only_active() -> bool:
	if gs == null:
		return false

	if (
		gs.has_method(
			"resident_blocking_birth_lane_active"
		)
		and bool(
			gs.resident_blocking_birth_lane_active()
		)
	):
		return true

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		return false

	if (
		bool(
			gs.scenario_state.get(
				"birth_shell_player_control_released",
				false
			)
		)
		or bool(
			gs.scenario_state.get(
				"playable_life_surface_player_control_released",
				false
			)
		)
	):
		return false

	return (
		bool(
			gs.scenario_state.get(
				"god_mode_life_prewarm_active",
				false
			)
		)
		or bool(
			gs.scenario_state.get(
				"birth_shell_first_boot_active",
				false
			)
		)
		or bool(
			gs.scenario_state.get(
				"birth_shell_deferred_boot_pending",
				false
			)
		)
		or bool(
			gs.scenario_state.get(
				"royalty_heavy_bootstrap_forbidden_during_prewarm",
				false
			)
		)
		or (
			bool(
				gs.scenario_state.get(
					"interactive_boot_requested",
					false
				)
			)
			and not bool(
				gs.scenario_state.get(
					"birth_shell_player_control_released",
					false
				)
			)
		)
	)
func _register_birth_shell_relative_identity(
	person: Person,
	source: String
) -> void:
	if (
		person == null
		or gs == null
	):
		return

	_append_unique_npc(
		person
	)

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var pending_raw: Variant = gs.scenario_state.get(
		"resident_relative_identity_shell_enrichment_ids",
		[]
	)
	var pending_ids: Array = (
		(pending_raw as Array).duplicate()
		if typeof(pending_raw) == TYPE_ARRAY
		else []
	)

	if not pending_ids.has(int(person.id)):
		pending_ids.append(
			int(person.id)
		)

	gs.scenario_state [
		"resident_relative_identity_shell_enrichment_ids"
	] = pending_ids
	gs.scenario_state [
		"resident_relative_identity_shell_enrichment_pending"
	] = true
	gs.scenario_state [
		"resident_relative_identity_shell_last_actor_id"
	] = int(person.id)
	gs.scenario_state [
		"resident_relative_identity_shell_last_source"
	] = source
	gs.scenario_state [
		"resident_relative_identity_shell_ready_gate_member"
	] = false
func _create_birth_shell_relative_identity(
	gender: String,
	last_name: String,
	age_value: int,
	home_city: String,
	home_country: String,
	social_class: String,
	source: String
) -> Person:
	if gs == null:
		return null

	var relative:= Person.new()

	relative.id = int(
		gs.next_id
	)
	gs.next_id += 1

	relative.gender = gender
	relative.first_name = (
		gs.names_db.random_first_for_era(
			gender,
			gs.era.name
		)
		if gs.names_db != null
		else (
			"Relative %d"
			% int(relative.id)
		)
	)
	relative.last_name = last_name
	relative.age = clampi(
		age_value,
		0,
		130
	)
	relative.home_city = home_city
	relative.birth_city = home_city
	relative.home_country = home_country
	relative.birth_country = home_country
	relative.social_class = social_class
	relative.parents = []
	relative.children = []
	relative.memories = []
	relative.alive = true
	relative.health = 100.0
	relative.mental_health = 100.0
	relative.satisfaction = 70.0
	relative.job = "Unresolved"

	_register_birth_shell_relative_identity(
		relative,
		source
	)

	return relative
func _attach_birth_shell_direct_lineage_to_parent(
	parent: Person,
	lineage_last_name: String
) -> int:
	if (
		parent == null
		or gs == null
	):
		return 0

	if parent.parents.size() >= 2:
		return 0

	var last_name_to_use: String = (
		lineage_last_name.strip_edges()
	)

	if last_name_to_use == "":
		last_name_to_use = (
			parent.maiden_last_name
			if (
				parent.gender == "Female"
				and parent.maiden_last_name != ""
			)
			else parent.last_name
		)

	var grandparent_age: int = clampi(
		int(parent.age) + 24,
		18,
		110
	)
	var grandfather: Person = (
		_create_birth_shell_relative_identity(
			"Male",
			last_name_to_use,
			grandparent_age + 2,
			parent.home_city,
			parent.home_country,
			parent.social_class,
			"birth_shell_grandfather_identity"
		)
	)
	var grandmother: Person = (
		_create_birth_shell_relative_identity(
			"Female",
			last_name_to_use,
			grandparent_age,
			parent.home_city,
			parent.home_country,
			parent.social_class,
			"birth_shell_grandmother_identity"
		)
	)

	if (
		grandfather == null
		or grandmother == null
	):
		return 0

	grandfather.partner = grandmother
	grandmother.partner = grandfather
	grandfather.marital_status = "Married"
	grandmother.marital_status = "Married"

	parent.parents = []
	_link_parent_child(
		grandfather,
		parent
	)
	_link_parent_child(
		grandmother,
		parent
	)

	var seeded: int = 2

	for grandparent in [
		grandfather,
		grandmother
	]:
		var great_age: int = clampi(
			int(grandparent.age) + 24,
			36,
			130
		)
		var great_grandfather: Person = (
			_create_birth_shell_relative_identity(
				"Male",
				grandparent.last_name,
				great_age + 2,
				grandparent.home_city,
				grandparent.home_country,
				grandparent.social_class,
				"birth_shell_great_grandfather_identity"
			)
		)
		var great_grandmother: Person = (
			_create_birth_shell_relative_identity(
				"Female",
				grandparent.last_name,
				great_age,
				grandparent.home_city,
				grandparent.home_country,
				grandparent.social_class,
				"birth_shell_great_grandmother_identity"
			)
		)

		if (
			great_grandfather == null
			or great_grandmother == null
		):
			continue

		great_grandfather.partner = great_grandmother
		great_grandmother.partner = great_grandfather
		great_grandfather.marital_status = "Married"
		great_grandmother.marital_status = "Married"

		grandparent.parents = []
		_link_parent_child(
			great_grandfather,
			grandparent
		)
		_link_parent_child(
			great_grandmother,
			grandparent
		)
		seeded += 2

	return seeded
func _attach_birth_shell_parent_sibling_identity(
	parent: Person,
	anchor: Person,
	lineage_last_name: String,
	side_label: String
) -> int:
	if (
		parent == null
		or anchor == null
		or gs == null
	):
		return 0

	if not (
		_npc_factory_sibling_ids_for_person_by_shared_parent(
			parent
		)
	).is_empty():
		return 0

	if parent.parents.is_empty():
		return 0

	var relative_gender: String = (
		"Female"
		if (
			(
				int(parent.id)
				+ int(anchor.id)
			) % 2
			== 0
		)
		else "Male"
	)
	var age_offset: int = (
		-5
		if int(parent.id) % 2 == 0
		else 6
	)
	var relative: Person = (
		_create_birth_shell_relative_identity(
			relative_gender,
			lineage_last_name,
			clampi(
				int(parent.age) + age_offset,
				16,
				120
			),
			parent.home_city,
			parent.home_country,
			parent.social_class,
			(
				"birth_shell_%s_parent_sibling_identity"
				% side_label
			)
		)
	)

	if relative == null:
		return 0

	for raw_grandparent_id in parent.parents:
		var grandparent: Person = (
			_npc_factory_resolve_person(
				int(raw_grandparent_id)
			)
		)

		if grandparent == null:
			continue

		_link_parent_child(
			grandparent,
			relative
		)

	return 1
func ensure_parent_lineage(
	parent: Person,
	lineage_last_name: String = "",
	context: Dictionary = {}
) -> void:
	if parent == null:
		return

	var ln: String = lineage_last_name.strip_edges()

	if ln == "":
		if (
			parent.gender == "Female"
			and parent.maiden_last_name != ""
		):
			ln = parent.maiden_last_name
		else:
			ln = parent.last_name

	var force_full_generation: bool = bool(
		context.get(
			"force_full_generation",
			false
		)
	)
	var identity_shell_only: bool = (
		_birth_shell_lineage_identity_only_active()
		and not force_full_generation
	)
	var seeded_identity_shells: int = 0

	if identity_shell_only:
		seeded_identity_shells = (
			_attach_birth_shell_direct_lineage_to_parent(
				parent,
				ln
			)
		)
	else:
		_attach_generated_grandparents_to_parent(
			parent,
			ln
		)

	if (
		gs != null
		and typeof(gs.scenario_state) == TYPE_DICTIONARY
	):
		gs.scenario_state [
			"parent_lineage_contract_ready"
		] = true
		gs.scenario_state [
			"parent_lineage_contract_last_parent_id"
		] = int(parent.id)
		gs.scenario_state [
			"parent_lineage_contract_last_reason"
		] = (
			"lightweight_first_frame_identity_shell"
			if identity_shell_only
			else "bounded_direct_ancestor_generation"
		)
		gs.scenario_state [
			"parent_lineage_generation_deferred_for_birth_shell"
		] = identity_shell_only
		gs.scenario_state [
			"parent_lineage_identity_shell_seeded"
		] = seeded_identity_shells
		gs.scenario_state [
			"parent_lineage_heavy_npc_generation_performed"
		] = not identity_shell_only
		gs.scenario_state [
			"parent_lineage_ready_gate_may_not_wait_for_enrichment"
		] = true
func _ensure_birth_shell_royal_visibility_family_contract(anchor: Person, context: Dictionary = {}) -> Dictionary:
	if anchor == null or gs == null:
		return {
			"success": false,
			"seeded": 0,
			"reason": "Missing anchor or GameState."
		}

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var contract_key: String = "birth_shell_royal_visibility_family_contract:%d" % int(anchor.id)
	var registry_raw: Variant = gs.scenario_state.get("birth_shell_royal_visibility_family_contracts", {})
	var registry: Dictionary = registry_raw if typeof(registry_raw) == TYPE_DICTIONARY else {}

	if registry.has(contract_key) and not bool(context.get("force", false)):
		var cached_report: Dictionary = registry.get(contract_key, {})
		return cached_report.duplicate(true)

	var seeded: int = 0
	var inspected_parent_count: int = 0
	var skipped_parent_count: int = 0
	var seeded_parent_sibling_count: int = 0
	var seeded_collateral_child_count: int = 0
	var seeded_niece_nephew_count: int = 0

	for raw_parent_id in _npc_factory_safe_person_id_array(anchor, "parents"):
		var parent: Person = _npc_factory_resolve_person(int(raw_parent_id))
		if parent == null:
			skipped_parent_count += 1
			continue

		inspected_parent_count += 1

		var lineage_last_name: String = _lineage_last_name_for_parent(parent)
		ensure_parent_lineage(parent, lineage_last_name)

		var side_label: String = _parent_side_label_for_anchor(anchor, parent)
		var shard_report: Dictionary = _ensure_parent_sibling_shard(parent, anchor, side_label, lineage_last_name, {
			"source": str(context.get("source", "birth_shell_royal_visibility_family_contract")),
			"relationship_lane": "aunt_uncle",
			"side": side_label,
			"bounded": true
		})

		var shard_seeded: int = int(shard_report.get("seeded", 0))
		seeded += shard_seeded
		seeded_parent_sibling_count += shard_seeded

	for raw_sibling_id in _npc_factory_sibling_ids_for_person_by_shared_parent(anchor):
		var sibling: Person = _npc_factory_resolve_person(int(raw_sibling_id))
		if sibling == null or not sibling.alive:
			continue

		if int(sibling.age) < 18:
			continue

		if not _npc_factory_safe_person_id_array(sibling, "children").is_empty():
			continue

		var sibling_partner: Person = _ensure_collateral_partner_for_relative(sibling)
		if sibling_partner == null:
			continue

		var max_child_age: int = max(0, int(sibling.age) - 18)
		var niece_nephew: Person = create_child(sibling, sibling_partner)
		if niece_nephew == null:
			continue

		niece_nephew.age = clampi(randi_range(0, max_child_age), 0, max_child_age)
		niece_nephew.home_city = sibling.home_city
		niece_nephew.home_country = sibling.home_country
		niece_nephew.birth_city = sibling.home_city
		niece_nephew.birth_country = sibling.home_country
		gs.apply_reality_rules_to_person(niece_nephew)
		_register_extended_family_npc(niece_nephew)

		if gs.social_graph_engine != null:
			gs.social_graph_engine.connect_people(niece_nephew.id, anchor.id)

		seeded += 1
		seeded_niece_nephew_count += 1
		seeded_collateral_child_count += 1

	var report: Dictionary = {
		"success": true,
		"schema": "eralife.birth_shell_royal_visibility_family_contract",
		"version": 1,
		"anchor_id": int(anchor.id),
		"inspected_parent_count": inspected_parent_count,
		"skipped_parent_count": skipped_parent_count,
		"seeded": seeded,
		"seeded_parent_sibling_count": seeded_parent_sibling_count,
		"seeded_collateral_child_count": seeded_collateral_child_count,
		"seeded_niece_nephew_count": seeded_niece_nephew_count,
		"bounded": true,
		"source": str(context.get("source", "birth_shell_royal_visibility_family_contract")),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	registry [contract_key] = report.duplicate(true)
	gs.scenario_state ["birth_shell_royal_visibility_family_contracts"] = registry
	gs.scenario_state ["birth_shell_royal_visibility_family_contract_ready"] = true
	gs.scenario_state ["birth_shell_royal_visibility_family_contract_anchor_id"] = int(anchor.id)
	gs.scenario_state ["birth_shell_royal_visibility_family_contract_seeded"] = seeded

	return report
func ensure_extended_family_for_controlled_person(
	anchor: Person,
	context: Dictionary = {}
) -> Dictionary:
	if anchor == null or gs == null:
		return {
			"success": false,
			"seeded": 0,
			"reason": "Missing anchor or GameState."
		}

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var identity_shell_only: bool = (
		_birth_shell_lineage_identity_only_active()
		and not bool(
			context.get(
				"force_full_generation",
				false
			)
		)
	)
	var seeded: int = 0
	var inspected_parent_count: int = 0
	var skipped_parent_count: int = 0
	var identity_shell_parent_siblings: int = 0

	for raw_parent_id in (
		_npc_factory_safe_person_id_array(
			anchor,
			"parents"
		)
	):
		var parent: Person = (
			_npc_factory_resolve_person(
				int(raw_parent_id)
			)
		)

		if parent == null:
			skipped_parent_count += 1
			continue

		inspected_parent_count += 1

		var lineage_last_name: String = (
			_lineage_last_name_for_parent(
				parent
			)
		)
		var side_label: String = (
			_parent_side_label_for_anchor(
				anchor,
				parent
			)
		)

		ensure_parent_lineage(
			parent,
			lineage_last_name,
			{
				"source": str(
					context.get(
						"source",
						"extended_family_contract"
					)
				),
				"force_full_generation": (
					not identity_shell_only
				)
			}
		)

		if identity_shell_only:
			var shell_seeded: int = (
				_attach_birth_shell_parent_sibling_identity(
					parent,
					anchor,
					lineage_last_name,
					side_label
				)
			)

			seeded += shell_seeded
			identity_shell_parent_siblings += shell_seeded
			continue

		var shard_report: Dictionary = (
			_ensure_parent_sibling_shard(
				parent,
				anchor,
				side_label,
				lineage_last_name,
				context
			)
		)

		seeded += int(
			shard_report.get(
				"seeded",
				0
			)
		)

	gs.scenario_state [
		"extended_family_generation_deferred_for_birth_shell"
	] = identity_shell_only
	gs.scenario_state [
		"extended_family_generation_contract_ready_for_birth_shell"
	] = true
	gs.scenario_state [
		"extended_family_generation_contract_anchor_id"
	] = int(anchor.id)
	gs.scenario_state [
		"extended_family_generation_contract_reason"
	] = (
		"lightweight_relative_identity_shells"
		if identity_shell_only
		else "complete_extended_family_generation"
	)
	gs.scenario_state [
		"extended_family_generation_contract_at_ms"
	] = int(
		Time.get_ticks_msec()
	)
	gs.scenario_state [
		"extended_family_heavy_npc_generation_performed"
	] = not identity_shell_only
	gs.scenario_state [
		"extended_family_ready_gate_may_not_wait_for_enrichment"
	] = true

	return {
		"success": true,
		"schema": "eralife.extended_family_generation_report",
		"version": 2,
		"anchor_id": int(anchor.id),
		"inspected_parent_count": inspected_parent_count,
		"skipped_parent_count": skipped_parent_count,
		"seeded": seeded,
		"identity_shell_only": identity_shell_only,
		"identity_shell_parent_sibling_count": (
			identity_shell_parent_siblings
		),
		"heavy_npc_generation_performed": (
			not identity_shell_only
		),
		"enrichment_pending": identity_shell_only,
		"ready_gate_member": false,
		"source": str(
			context.get(
				"source",
				"ensure_extended_family_for_controlled_person"
			)
		)
	}
func _extended_family_generation_contract() -> Dictionary:
	return {
		"schema": "eralife.extended_family_generation_contract",
		"version": 1,
		"parent_sibling_shards": {
			"only_child_chance": 0.28,
			"base_spawn_chance": 0.72,
			"additional_sibling_chance": 0.34,
			"max_parent_siblings": 4,
			"ancient_era_max_bonus": 2,
			"medieval_era_max_bonus": 2,
			"industrial_era_max_bonus": 1,
			"royal_family_max_bonus": 2,
			"noble_family_max_bonus": 1
		},
		"collateral_descendants": {
			"child_chance": 0.46,
			"additional_child_chance": 0.24,
			"max_children": 3,
			"min_parent_age": 18,
			"max_child_age": 32
		}
	}

func _ensure_parent_sibling_shard(parent: Person, anchor_child: Person, side_label: String, lineage_last_name: String = "", context: Dictionary = {}) -> Dictionary:
	if parent == null or gs == null:
		return {
			"success": false,
			"seeded": 0,
			"reason": "Missing parent or GameState."
		}

	if _npc_factory_safe_person_id_array(parent, "parents").is_empty():
		return {
			"success": false,
			"seeded": 0,
			"reason": "Parent has no known parents."
		}

	var existing_sibling_ids: Array = _npc_factory_sibling_ids_for_person_by_shared_parent(parent)
	if not existing_sibling_ids.is_empty():
		return {
			"success": true,
			"seeded": 0,
			"existing_sibling_count": existing_sibling_ids.size(),
			"reason": "Parent already has siblings."
		}

	var attempt_key: String = _extended_family_attempt_key(parent, anchor_child, side_label)
	if _extended_family_attempt_has_run(attempt_key) and not bool(context.get("force", false)):
		return {
			"success": true,
			"seeded": 0,
			"reason": "Extended family shard was already evaluated.",
			"attempt_key": attempt_key
		}

	_mark_extended_family_attempt(attempt_key)

	var contract: Dictionary = _extended_family_generation_contract()
	var shard_raw: Variant = contract.get("parent_sibling_shards", {})
	var shard_contract: Dictionary = shard_raw if typeof(shard_raw) == TYPE_DICTIONARY else {}

	var spawn_chance: float = clamp(float(shard_contract.get("base_spawn_chance", 0.72)), 0.0, 1.0)
	var only_child_chance: float = clamp(float(shard_contract.get("only_child_chance", 0.28)), 0.0, 1.0)
	var roll: float = _extended_family_roll(parent, "%s_spawn" % side_label)

	if roll < only_child_chance or roll > spawn_chance:
		return {
			"success": true,
			"seeded": 0,
			"reason": "Parent was resolved as an only child on this side.",
			"attempt_key": attempt_key,
			"roll": roll
		}

	var sibling_count: int = _extended_family_parent_sibling_count(parent, anchor_child, side_label, shard_contract)
	var seeded: int = 0
	var seeded_ids: Array = []

	for i in range(sibling_count):
		var relative: Person = _create_parent_sibling_for_extended_family(parent, anchor_child, side_label, i, lineage_last_name)
		if relative == null:
			continue

		seeded += 1
		seeded_ids.append(int(relative.id))

		_maybe_seed_collateral_children_for_relative(anchor_child, relative, {
			"source": "parent_sibling_shard",
			"relationship_lane": "aunt_uncle",
			"side": side_label
		})

	return {
		"success": true,
		"seeded": seeded,
		"seeded_ids": seeded_ids,
		"attempt_key": attempt_key,
		"side": side_label,
		"parent_id": int(parent.id),
		"anchor_id": int(anchor_child.id) if anchor_child != null else -1
	}

func _create_parent_sibling_for_extended_family(parent: Person, anchor_child: Person, side_label: String, ordinal: int, lineage_last_name: String = "") -> Person:
	if parent == null or gs == null:
		return null

	var relative: Person = create_random_npc(false)
	if relative == null:
		return null

	relative.gender = ["Male", "Female"] [randi() % 2]
	relative.first_name = gs.names_db.random_first_for_era(relative.gender, gs.era.name)

	var resolved_last_name: String = str(lineage_last_name).strip_edges()
	if resolved_last_name == "":
		resolved_last_name = _lineage_last_name_for_parent(parent)
	if resolved_last_name == "":
		resolved_last_name = str(parent.last_name).strip_edges()

	relative.last_name = resolved_last_name
	if relative.gender == "Female":
		relative.maiden_last_name = resolved_last_name

	var age_floor: int = int(anchor_child.age) + 16 if anchor_child != null else 16
	var target_age: int = int(parent.age) + int(_extended_family_jitter(parent, "%s_age_%d" % [side_label, ordinal], -8.0, 8.0))
	relative.age = _clamp_age_by_era(max(age_floor, target_age))

	relative.home_city = parent.home_city
	relative.home_country = parent.home_country
	relative.birth_city = parent.birth_city if str(parent.birth_city).strip_edges() != "" else parent.home_city
	relative.birth_country = parent.birth_country if str(parent.birth_country).strip_edges() != "" else parent.home_country
	relative.social_class = parent.social_class

	if gs.career_engine != null and int(relative.age) >= 18:
		relative.job = gs.career_engine.pick_job_for(relative)
		gs.career_engine.sync_or_seed_existing_job_state(relative, false)

	relative.parents = []
	for raw_grandparent_id in _npc_factory_safe_person_id_array(parent, "parents"):
		var grandparent: Person = _npc_factory_resolve_person(int(raw_grandparent_id))
		if grandparent == null:
			continue
		_link_parent_child(grandparent, relative)

	if gs.social_graph_engine != null:
		gs.social_graph_engine.connect_people(relative.id, parent.id)

	_apply_old_age_state(relative)
	gs.apply_reality_rules_to_person(relative)
	_register_extended_family_npc(relative)

	return relative

func _maybe_seed_collateral_children_for_relative(anchor: Person, relative: Person, context: Dictionary = {}) -> Dictionary:
	if anchor == null or relative == null or gs == null:
		return {
			"success": false,
			"seeded": 0,
			"reason": "Missing anchor or relative."
		}

	if not bool(relative.alive):
		return {
			"success": true,
			"seeded": 0,
			"reason": "Relative is not alive."
		}

	if int(relative.age) < 18:
		return {
			"success": true,
			"seeded": 0,
			"reason": "Relative is too young for collateral children."
		}

	if not _npc_factory_safe_person_id_array(relative, "children").is_empty():
		return {
			"success": true,
			"seeded": 0,
			"reason": "Relative already has children."
		}

	var contract: Dictionary = _extended_family_generation_contract()
	var raw_descendants: Variant = contract.get("collateral_descendants", {})
	var descendant_contract: Dictionary = raw_descendants if typeof(raw_descendants) == TYPE_DICTIONARY else {}

	var chance: float = clamp(float(descendant_contract.get("child_chance", 0.46)), 0.0, 1.0)
	var roll: float = _extended_family_roll(relative, "%s_child_spawn" % str(context.get("relationship_lane", "collateral")))

	if roll > chance:
		return {
			"success": true,
			"seeded": 0,
			"reason": "No collateral child shard spawned.",
			"roll": roll
		}

	var partner: Person = _ensure_collateral_partner_for_relative(relative)
	if partner == null:
		return {
			"success": false,
			"seeded": 0,
			"reason": "Could not resolve collateral partner."
		}

	var max_children: int = int(descendant_contract.get("max_children", 3))
	var additional_chance: float = clamp(float(descendant_contract.get("additional_child_chance", 0.24)), 0.0, 1.0)
	var child_count: int = 1

	for i in range(1, max_children):
		if _extended_family_roll(relative, "extra_child_%d" % i) <= additional_chance:
			child_count += 1

	var max_child_age: int = min(int(descendant_contract.get("max_child_age", 32)), max(0, int(relative.age) - 18))
	if max_child_age < 0:
		max_child_age = 0

	var seeded: int = 0
	var seeded_ids: Array = []

	for i in range(child_count):
		var child: Person = create_child(relative, partner)
		if child == null:
			break

		child.age = clamp(randi_range(0, max(0, max_child_age)), 0, max_child_age)
		child.home_city = relative.home_city
		child.home_country = relative.home_country
		child.birth_city = relative.home_city
		child.birth_country = relative.home_country
		gs.apply_reality_rules_to_person(child)
		_register_extended_family_npc(child)

		if gs.social_graph_engine != null:
			gs.social_graph_engine.connect_people(child.id, anchor.id)

		seeded += 1
		seeded_ids.append(int(child.id))

	return {
		"success": true,
		"seeded": seeded,
		"seeded_ids": seeded_ids,
		"relative_id": int(relative.id),
		"partner_id": int(partner.id)
	}

func _ensure_collateral_partner_for_relative(relative: Person) -> Person:
	if relative == null or gs == null:
		return null

	var existing_partner: Person = gs.get_valid_partner(relative, true, true) if gs.has_method("get_valid_partner") else null
	if existing_partner != null:
		return existing_partner

	var partner: Person = create_random_npc(false)
	if partner == null:
		return null

	partner.gender = "Female" if str(relative.gender) == "Male" else "Male"
	partner.first_name = gs.names_db.random_first_for_era(partner.gender, gs.era.name)
	partner.age = _clamp_age_by_era(max(18, int(relative.age) + randi_range(-5, 5)))
	partner.home_city = relative.home_city
	partner.home_country = relative.home_country
	partner.birth_city = relative.birth_city
	partner.birth_country = relative.birth_country
	partner.social_class = relative.social_class

	if str(partner.gender) == "Male":
		partner.last_name = relative.last_name
	else:
		partner.maiden_last_name = partner.last_name

	relative.partner = partner
	partner.partner = relative
	relative.marital_status = "Married"
	partner.marital_status = "Married"

	if gs.career_engine != null and int(partner.age) >= 18:
		partner.job = gs.career_engine.pick_job_for(partner)
		gs.career_engine.sync_or_seed_existing_job_state(partner, false)

	gs.apply_reality_rules_to_person(partner)
	_register_extended_family_npc(partner)

	if gs.social_graph_engine != null:
		gs.social_graph_engine.connect_people(relative.id, partner.id)

	return partner

func _extended_family_parent_sibling_count(parent: Person, _anchor_child: Person, side_label: String, shard_contract: Dictionary) -> int:
	var max_count: int = int(shard_contract.get("max_parent_siblings", 4))
	var era_name: String = str(gs.era.name).strip_edges().to_lower() if gs != null and gs.era != null else ""

	if era_name.find("ancient") != -1:
		max_count += int(shard_contract.get("ancient_era_max_bonus", 2))
	elif era_name.find("medieval") != -1:
		max_count += int(shard_contract.get("medieval_era_max_bonus", 2))
	elif era_name.find("industrial") != -1:
		max_count += int(shard_contract.get("industrial_era_max_bonus", 1))

	var class_key: String = str(parent.social_class).strip_edges().to_lower()
	if class_key.find("royal") != -1:
		max_count += int(shard_contract.get("royal_family_max_bonus", 2))
	elif class_key.find("noble") != -1:
		max_count += int(shard_contract.get("noble_family_max_bonus", 1))

	max_count = clamp(max_count, 1, 8)

	var count: int = 1
	var additional_chance: float = clamp(float(shard_contract.get("additional_sibling_chance", 0.34)), 0.0, 1.0)

	for i in range(1, max_count):
		if _extended_family_roll(parent, "%s_extra_parent_sibling_%d" % [side_label, i]) <= additional_chance:
			count += 1
		else:
			break

	return count

func _npc_factory_sibling_ids_for_person_by_shared_parent(person: Person) -> Array:
	var out: Array = []
	var seen: Dictionary = {}

	if person == null or gs == null:
		return out

	var parent_ids: Array = _npc_factory_safe_person_id_array(person, "parents")
	if parent_ids.is_empty():
		return out

	for raw_npc in gs.npcs:
		if raw_npc == null or not (raw_npc is Person):
			continue

		var other: Person = raw_npc as Person
		if int(other.id) == int(person.id):
			continue

		if _npc_factory_people_share_parent_ids(parent_ids, _npc_factory_safe_person_id_array(other, "parents")):
			var other_id: int = int(other.id)
			if other_id > 0 and not seen.has(other_id):
				seen [other_id] = true
				out.append(other_id)

	return out

func _npc_factory_people_share_parent_ids(a_parent_ids: Array, b_parent_ids: Array) -> bool:
	if a_parent_ids.is_empty() or b_parent_ids.is_empty():
		return false

	for raw_id in a_parent_ids:
		if int(raw_id) in b_parent_ids:
			return true

	return false

func _lineage_last_name_for_parent(parent: Person) -> String:
	if parent == null:
		return ""

	if str(parent.gender) == "Female" and str(parent.maiden_last_name).strip_edges() != "":
		return str(parent.maiden_last_name).strip_edges()

	return str(parent.last_name).strip_edges()

func _parent_side_label_for_anchor(anchor: Person, parent: Person) -> String:
	if anchor == null or parent == null:
		return "unknown_side"

	var parent_index: int = _npc_factory_safe_person_id_array(anchor, "parents").find(int(parent.id))
	if parent_index == 0:
		return "paternal"
	if parent_index == 1:
		return "maternal"

	return "parent_%d" % int(parent.id)

func _extended_family_attempt_key(parent: Person, anchor_child: Person, side_label: String) -> String:
	var anchor_id: int = int(anchor_child.id) if anchor_child != null else -1
	var parent_id: int = int(parent.id) if parent != null else -1
	return "%s:%s:%s" % [str(anchor_id), str(parent_id), str(side_label)]

func _extended_family_attempt_registry() -> Dictionary:
	if gs == null:
		return {}

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var raw_registry: Variant = gs.scenario_state.get("extended_family_generation_attempts", {})
	if typeof(raw_registry) != TYPE_DICTIONARY:
		raw_registry = {}

	gs.scenario_state ["extended_family_generation_attempts"] = raw_registry
	return raw_registry

func _extended_family_attempt_has_run(attempt_key: String) -> bool:
	var registry: Dictionary = _extended_family_attempt_registry()
	return registry.has(str(attempt_key))

func _mark_extended_family_attempt(attempt_key: String) -> void:
	var registry: Dictionary = _extended_family_attempt_registry()
	registry [str(attempt_key)] = {
		"attempt_key": str(attempt_key),
		"year": int(gs.year) if gs != null else 0,
		"created_at_ms": int(Time.get_ticks_msec())
	}
	gs.scenario_state ["extended_family_generation_attempts"] = registry

func _extended_family_roll(person: Person, salt: String) -> float:
	if person == null:
		return randf()

	var material: String = "%s|%s|%s|%s|%s" % [
		str(int(person.id)),
		str(person.first_name),
		str(person.last_name),
		str(person.age),
		str(salt)
	]

	var seed_value: int = int(hash(material))
	if seed_value < 0:
		seed_value = - seed_value
	if seed_value <= 0:
		seed_value = 1

	var rng:= RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng.randf()

func _extended_family_jitter(person: Person, salt: String, low: float, high: float) -> float:
	if person == null:
		return randf_range(low, high)

	var material: String = "%s|%s|%s|%s|%s" % [
		str(int(person.id)),
		str(person.first_name),
		str(person.last_name),
		str(person.age),
		str(salt)
	]

	var seed_value: int = int(hash(material))
	if seed_value < 0:
		seed_value = - seed_value
	if seed_value <= 0:
		seed_value = 1

	var rng:= RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng.randf_range(low, high)

func _npc_factory_safe_person_id_array(person: Person, property_id: String) -> Array:
	var out: Array = []

	if person == null:
		return out

	var raw_value: Variant = person.get(property_id)
	if typeof(raw_value) != TYPE_ARRAY:
		return out

	for raw_id in raw_value:
		var resolved_id: int = int(raw_id)
		if resolved_id <= 0:
			continue
		if resolved_id in out:
			continue
		out.append(resolved_id)

	return out

func _npc_factory_resolve_person(person_id: int) -> Person:
	if gs == null or person_id <= 0:
		return null

	if gs.has_method("get_or_reactivate_npc_by_id"):
		return gs.get_or_reactivate_npc_by_id(person_id)
	if gs.has_method("get_npc_by_id"):
		return gs.get_npc_by_id(person_id)

	return null

func _register_extended_family_npc(npc: Person) -> void:
	if npc == null or gs == null:
		return

	if gs.has_method("register_npc"):
		gs.register_npc(npc)
	else:
		_append_unique_npc(npc)
func create_random_npc(generate_family_lineage:= false) -> Person:
	var npc:= _create_base_npc()
	if generate_family_lineage:
		ensure_family_lineage(npc)
	if npc.social_class == "Royal" and gs.royalty_engine != null:
		gs.royalty_engine.setup_seed_royal_house(npc)
	return npc
func seed_spawn_world_assets(seed_npcs: Array) -> void:
	for npc in seed_npcs:
		seed_spawn_assets_for_npc(npc, true)

func seed_spawn_assets_for_npc(npc: Person, include_vehicle:= true) -> void:
	if npc == null or gs == null:
		return
	if not npc.alive:
		return
	if int(npc.age) < 18:
		return

	if gs.property_engine != null and not _has_any_property(npc):
		var property_context: Dictionary = {}
		if gs.property_engine.has_method("_build_npc_property_market_context"):
			property_context = gs.property_engine._build_npc_property_market_context(npc)

		var property_pick: Dictionary = _resolve_spawn_property_pick_for_npc(npc, property_context)
		if not property_pick.is_empty():
			var property_template: Dictionary = property_pick.get("template", {})
			var resolved_property_context: Dictionary = property_pick.get("context", {})
			var property_price: int = gs.property_engine._calculate_property_value(
				property_template,
				npc,
				resolved_property_context
			)
			if float(npc.bank_balance) < float(property_price):
				npc.bank_balance = float(property_price) + randf_range(250.0, 5000.0)
			gs.property_engine.buy_property(
				npc,
				property_template,
				property_price,
				resolved_property_context
			)

	if not include_vehicle:
		return

	if gs.vehicle_engine != null and not _has_any_vehicle(npc):
		var vehicle_context: Dictionary = {}
		if gs.vehicle_engine.has_method("_build_npc_vehicle_market_context"):
			vehicle_context = gs.vehicle_engine._build_npc_vehicle_market_context(npc)

		var vehicle_pick: Dictionary = _resolve_spawn_vehicle_pick_for_npc(npc, vehicle_context)
		if not vehicle_pick.is_empty():
			var vehicle_template: Dictionary = vehicle_pick.get("template", {})
			var resolved_vehicle_context: Dictionary = vehicle_pick.get("context", {})
			var vehicle_price: int = gs.vehicle_engine._calculate_vehicle_value(
				vehicle_template,
				npc,
				resolved_vehicle_context
			)
			if float(npc.bank_balance) < float(vehicle_price):
				npc.bank_balance = float(vehicle_price) + randf_range(250.0, 5000.0)
			var luxury_level: int = int(
				resolved_vehicle_context.get("luxury_level", int(vehicle_template.get("luxury", 0)))
			)
			gs.vehicle_engine.buy_vehicle(
				npc,
				vehicle_template,
				vehicle_price,
				luxury_level,
				resolved_vehicle_context
			)
func _resolve_spawn_property_pick_for_npc(npc: Person,
base_context: Dictionary) -> Dictionary:
	var contexts_to_try: Array = []
	var exact_context: Dictionary = base_context.duplicate(true)
	contexts_to_try.append(exact_context)
	var no_desired_tags_context: Dictionary = base_context.duplicate(true)
	no_desired_tags_context.erase("desired_tags")
	contexts_to_try.append(no_desired_tags_context)
	var no_social_tier_context: Dictionary = base_context.duplicate(true)
	no_social_tier_context.erase("social_tier")
	contexts_to_try.append(no_social_tier_context)
	var relaxed_context: Dictionary = base_context.duplicate(true)
	relaxed_context.erase("desired_tags")
	relaxed_context.erase("social_tier")
	contexts_to_try.append(relaxed_context)
	for raw_context in contexts_to_try:
		if typeof(raw_context) != TYPE_DICTIONARY:
			continue
		var ctx: Dictionary = raw_context
		var desired_tags: Array = []
		if ctx.has("desired_tags"):
			desired_tags = ctx.get("desired_tags", []).duplicate()
		var property_options: Array = gs.property_engine.get_buyable_property_templates_for_person(
				npc,
				desired_tags,
				ctx
			)
		if not property_options.is_empty():
			return {
				"template": property_options [randi() %
					property_options.size()],
				"context": ctx
			}
	if gs != null and gs.era_data_loader != null:
		var fallback_template: Dictionary = gs.era_data_loader.get_best_property_template_for_context(
				gs.era.name,
				{}
			)
		if fallback_template.is_empty():
			var all_templates: Array = gs.era_data_loader.get_property_templates_for_era(gs.era.name)
			if not all_templates.is_empty():
				var raw_template: Variant = all_templates [randi() %
					all_templates.size()]
				if typeof(raw_template) == TYPE_DICTIONARY:
					fallback_template = raw_template.duplicate(true)
		if not fallback_template.is_empty():
			return {
				"template": fallback_template,
				"context": {}
			}
	if gs != null and gs.property_engine != null:
		var legacy_size: String = "Medium"
		var social_tier: String = str(base_context.get("social_tier", "")).to_lower()
		match social_tier:
			"poor", "working", "low", "common", "working_class":
				legacy_size = "Small"
			"upper", "wealthy", "rich", "high":
				legacy_size = "Large"
			"royal":
				legacy_size = "Royal"
			"elite", "noble", "aristocrat":
				legacy_size = "Mansion"
			_:
				legacy_size = "Medium"
		var legacy_template: Dictionary = gs.property_engine._legacy_property_from_size(legacy_size)
		if not legacy_template.is_empty():
			return {
				"template": legacy_template,
				"context": {}
			}
	return {}


func _resolve_spawn_vehicle_pick_for_npc(npc: Person,
base_context: Dictionary) -> Dictionary:
	var contexts_to_try: Array = []

	var exact_context: Dictionary = base_context.duplicate(true)
	contexts_to_try.append(exact_context)
	var no_desired_tags_context: Dictionary = base_context.duplicate(true)
	no_desired_tags_context.erase("desired_tags")
	contexts_to_try.append(no_desired_tags_context)
	var no_social_tier_context: Dictionary = base_context.duplicate(true)
	no_social_tier_context.erase("social_tier")
	contexts_to_try.append(no_social_tier_context)
	var no_network_context: Dictionary = base_context.duplicate(true)
	no_network_context.erase("network_type")
	contexts_to_try.append(no_network_context)
	var relaxed_context: Dictionary = base_context.duplicate(true)
	relaxed_context.erase("desired_tags")
	relaxed_context.erase("social_tier")
	relaxed_context.erase("network_type")
	contexts_to_try.append(relaxed_context)
	for raw_context in contexts_to_try:
		if typeof(raw_context) != TYPE_DICTIONARY:
			continue
		var ctx: Dictionary = raw_context
		var desired_tags: Array = []
		if ctx.has("desired_tags"):
			desired_tags = ctx.get("desired_tags", []).duplicate()
		var vehicle_options: Array = gs.vehicle_engine.get_buyable_transport_templates_for_person(
				npc,
				desired_tags,
				ctx
			)
		if not vehicle_options.is_empty():
			return {
				"template": vehicle_options [randi() %
					vehicle_options.size()],
				"context": ctx
			}
	if gs != null and gs.era_data_loader != null:
		var fallback_template: Dictionary = gs.era_data_loader.get_best_transport_template_for_context(
				gs.era.name,
				{}
			)
		if fallback_template.is_empty():
			var all_templates: Array = gs.era_data_loader.get_transport_templates_for_era(gs.era.name)
			if not all_templates.is_empty():
				var raw_template: Variant = all_templates [randi() %
					all_templates.size()]
				if typeof(raw_template) == TYPE_DICTIONARY:
					fallback_template = raw_template.duplicate(true)
		if not fallback_template.is_empty():
			return {
				"template": fallback_template,
				"context": {}
			}
	if gs != null and gs.vehicle_engine != null:
		var legacy_type: String = _default_buyable_vehicle_type_for_current_era()
		var legacy_luxury_level: int = int(base_context.get("luxury_level", 0))
		var legacy_template: Dictionary = gs.vehicle_engine._legacy_vehicle_template(legacy_type, legacy_luxury_level)
		if not legacy_template.is_empty():
			return {
				"template": legacy_template,
				"context": {
					"luxury_level": legacy_luxury_level
				}
			}
	return {}

func _has_any_vehicle(npc: Person) -> bool:
	if npc == null or gs.vehicle_engine == null:
		return false
	if not gs.vehicle_engine.vehicles.has(npc.id):
		return false
	return not gs.vehicle_engine.vehicles [npc.id].is_empty()

func _has_any_property(npc: Person) -> bool:
	if npc == null or gs.property_engine == null:
		return false
	if not gs.property_engine.properties.has(npc.id):
		return false
	return not gs.property_engine.properties [npc.id].is_empty()

func _default_buyable_vehicle_type_for_current_era() -> String:
	match gs.era.name:
		"Ancient Era":
			return "Chariot"
		"Medieval Era":
			return "Cart"
		"Industrial Era":
			return "Car"
		"Modern Era":
			return "Car"
		"Future Era":
			return "Hovercar"
		_:
			return "Car"

func _default_buyable_vehicle_price_for_current_era() -> int:
	match gs.era.name:
		"Ancient Era":
			return 2500
		"Medieval Era":
			return 1800
		"Industrial Era":
			return 4500
		"Modern Era":
			return 9000
		"Future Era":
			return 22000
		_:
			return 9000

func _create_parent(gender: String, anchor_city: String = "", anchor_country: String = "") -> Person:
	var parent:= create_random_npc(false)
	parent.gender = gender
	parent.first_name = gs.names_db.random_first_for_era(gender, gs.era.name)
	parent.age = randi_range(22, 45)
	if anchor_city != "":
		parent.home_city = anchor_city
	if anchor_country != "":
		parent.home_country = anchor_country
	if gs.career_engine != null:
		parent.job = gs.career_engine.pick_job_for(parent)
		gs.career_engine.sync_or_seed_existing_job_state(parent, false)
	else:
		var pool = gs.era_engine.get_job_pool()
		if not pool.is_empty():
			parent.job = pool [randi() % pool.size()]
	return parent

func _create_parent_for_child(gender: String, child: Person) -> Person:
	var parent:= create_random_npc(false)
	parent.gender = gender
	parent.first_name = gs.names_db.random_first_for_era(gender, gs.era.name)
	var target_age:= int(child.age) + randi_range(16, 40)
	parent.age = _clamp_age_by_era(target_age)
	if parent.age < 65:
		if gs.career_engine != null:
			parent.job = gs.career_engine.pick_job_for(parent)
		else:
			var pool = gs.era_engine.get_job_pool()
			if not pool.is_empty():
				parent.job = pool [randi() % pool.size()]
	else:
		if gs.career_engine != null and randi() % 100 < 20:
			parent.job = gs.career_engine.pick_job_for(parent)
		else:
			parent.job = "Retired"
	_apply_old_age_state(parent)
	if gs.career_engine != null:
		gs.career_engine.sync_or_seed_existing_job_state(parent, false)
	return parent


func _apply_old_age_state(person: Person) -> void:
	if person == null:
		return

	var death_roll:= randi() % 100
	if person.age >= 95:
		if death_roll < 92:
			person.alive = false
			person.health = 0
			person.cause_of_death = "Old age"
	elif person.age >= 85:
		if death_roll < 65:
			person.alive = false
			person.health = 0
			person.cause_of_death = "Old age"
	else:
		person.alive = true

	if person.alive:
		person.health = max(float(person.health), randf_range(20.0, 80.0))
		person.mental_health = max(float(person.mental_health), randf_range(20.0, 85.0))




func _create_grandparent(gender: String, last_name: String, parent_age: int) -> Person:
	var gp:= create_random_npc(false)
	gp.gender = gender
	gp.last_name = last_name
	gp.first_name = gs.names_db.random_first_for_era(gender, gs.era.name)
	var min_age = max(parent_age + 16, _era_min_age())
	var max_age = min(parent_age + 40, _era_max_age())
	if min_age > max_age:
		max_age = min_age
	gp.age = randi_range(min_age, max_age)
	if gp.age < 65:
		if gs.career_engine != null:
			gp.job = gs.career_engine.pick_job_for(gp)
		else:
			var pool = gs.era_engine.get_job_pool()
			if not pool.is_empty():
				gp.job = pool [randi() % pool.size()]
	else:
		if gs.career_engine != null and randi() % 100 < 20:
			gp.job = gs.career_engine.pick_job_for(gp)
		else:
			gp.job = "Retired"
	if gs.career_engine != null:
		gs.career_engine.sync_or_seed_existing_job_state(gp, false)
	return gp





func create_player() -> Person:
	var player:= create_random_npc(false)
	player.age = 0

	player.birthday = {
		"month": randi_range(1, 12),
		"day": randi_range(1, 28)
	}
	player.zodiac = _get_zodiac(player.birthday.month, player.birthday.day)

	var locs = gs.era_engine.get_birth_locations()
	var place = locs [randi() % locs.size()]
	player.birth_city = place ["city"]
	player.birth_country = place ["country"]
	player.home_city = player.birth_city
	player.home_country = player.birth_country
	player.imagination = randi_range(1, 79)

	var father:= _create_parent("Male", player.home_city, player.home_country)
	var mother:= _create_parent("Female", player.home_city, player.home_country)
	mother.maiden_last_name = mother.last_name
	var family_last = gs.names_db.last_name_for_birthplace(
		gs.era.name,
		player.birth_city,
		player.birth_country
	)
	father.last_name = family_last
	mother.last_name = family_last
	player.last_name = family_last
	player.parents = [father.id, mother.id]
	gs.npcs.append(father)
	gs.npcs.append(mother)
	gs.social_graph_engine.connect_people(player.id, father.id)
	gs.social_graph_engine.connect_people(player.id, mother.id)





	father.partner = mother
	mother.partner = father
	father.marital_status = "Married"
	mother.marital_status = "Married"

	ensure_parent_lineage(mother, mother.maiden_last_name)
	ensure_parent_lineage(father, father.last_name)

	ensure_extended_family_for_controlled_person(player, {
		"source": "npc_factory_create_player"
	})


	if randi() % 100 < 50:
		var sibling:= create_random_npc(false)
		sibling.age = randi_range(1, 10)
		sibling.last_name = family_last
		sibling.home_city = player.home_city
		sibling.home_country = player.home_country
		sibling.parents = [father.id, mother.id]
		_register_extended_family_npc(sibling)
		gs.social_graph_engine.connect_people(player.id, sibling.id)

	player.memories.append(gs.era_engine.get_conception_story())
	if gs.player_bending_enabled:
		gs.bending_engine.assign_bending({ "npc_id": player.id})
	var family_to_sync: Array = [father, mother]

	for pid in father.parents:
		var grandparent: Person = gs.get_npc_by_id(int(pid))
		if grandparent != null and grandparent not in family_to_sync:
			family_to_sync.append(grandparent)
	for pid in mother.parents:
		var grandparent: Person = gs.get_npc_by_id(int(pid))
		if grandparent != null and grandparent not in family_to_sync:
			family_to_sync.append(grandparent)

	for npc in gs.npcs:
		if npc.id != player.id and npc.parents == player.parents:
			family_to_sync.append(npc)
	gs.bending_engine.sync_family_bending(player, family_to_sync)
	if gs.bridge_to_terabithia_engine != null:
		gs.bridge_to_terabithia_engine.ensure_person_imagination_state(player)
	return player

func _ordered_birth_parents(a: Person, b: Person) -> Array:
	if a.gender == "Male" and b.gender == "Female":
		return [a, b]

	if b.gender == "Male" and a.gender == "Female":
		return [b, a]


	if a.id <= b.id:
		return [a, b]

	return [b, a]



func create_child(parent1: Person, parent2: Person) -> Person:
	if not gs.can_create_child(parent1, parent2, false):
		return null
	var ordered: Array = _ordered_birth_parents(parent1, parent2)
	parent1 = ordered [0]
	parent2 = ordered [1]
	var child:= Person.new()
	child.id = gs.next_id
	gs.next_id += 1
	gs.class_engine.assign_birth_class(child)
	gs.realm_engine.assign_realm(child)
	child.gender = ["Male", "Female"] [randi() % 2]
	child.first_name = gs.names_db.random_first_for_era(child.gender, gs.era.name)
	child.age = 0

	child.birth_city = parent1.home_city if parent1 != null and parent1.home_city != "" else parent2.home_city
	child.birth_country = parent1.home_country if parent1 != null and parent1.home_country != "" else parent2.home_country
	child.home_city = child.birth_city
	child.home_country = child.birth_country
	if gs.geo_engine != null:
		gs.geo_engine.bootstrap_person_place(child, {
			"settlement_id": parent1.settlement_id if str(parent1.settlement_id).strip_edges() != "" else parent2.settlement_id
		})

	child.last_name = parent1.last_name if parent1 != null and parent1.last_name != "" else parent2.last_name
	_inherit_family_identity(child, parent1, parent2)
	child.smarts = int(round(_inherit(parent1.smarts, parent2.smarts, 100.0, 1.0, 9.0, 0.08, 18.0)))
	child.looks = int(round(_inherit(parent1.looks, parent2.looks, 100.0, 1.0, 9.0, 0.08, 18.0)))
	var health_floor: float = max(55.0, (float(parent1.health) + float(parent2.health)) * 0.35)
	child.health = _inherit(parent1.health, parent2.health, 200.0, health_floor, 14.0, 0.1, 28.0)
	child.mental_health = _inherit(parent1.mental_health, parent2.mental_health, 100.0, 25.0, 8.0, 0.1, 18.0)
	child.imagination = int(round(_inherit(parent1.imagination, parent2.imagination, 100.0, 1.0, 9.0, 0.1, 18.0)))
	child.traits = []
	child.parents = [parent1.id, parent2.id]
	child.children = []
	child.memories = []
	if child.id not in parent1.children:
		parent1.children.append(child.id)
	if child.id not in parent2.children:
		parent2.children.append(child.id)
	gs.social_graph_engine.connect_people(child.id, parent1.id)
	gs.social_graph_engine.connect_people(child.id, parent2.id)
	child.memories.append(gs.era_engine.get_conception_story())
	if gs.bridge_to_terabithia_engine != null:
		gs.bridge_to_terabithia_engine.ensure_person_imagination_state(child)
	gs.capability_graph_engine.initialize_npc(child)
	if gs.bending_engine != null and gs.is_feature_enabled("bending"):
		gs.bending_engine.assign_bending(child)
	if gs.event_bus != null:
		gs.event_bus.emit(ActionEventTypes.NPC_BORN, {
			"npc_id": child.id,
			"npc": child
		})
	return child





func _inherit(a, b, max_value:= 100.0, min_value:= 1.0, jitter:= 10.0, outlier_chance:= 0.08, outlier_jitter:= 22.0):
	var avg:= (float(a) + float(b)) / 2.0
	var working_jitter:= jitter
	if randf() < outlier_chance:
		working_jitter = outlier_jitter
	return clamp(avg + randf_range(- working_jitter, working_jitter), min_value, max_value)
func _inherit_family_identity(child: Person, father: Person, mother: Person) -> void:
	if child == null:
		return

	var family_last:= ""
	if father != null and father.last_name != "":
		family_last = father.last_name
	elif mother != null and mother.last_name != "":
		family_last = mother.last_name
	if family_last != "":
		child.last_name = family_last


	var base_city:= ""
	var base_country:= ""
	if father != null and father.home_city != "":
		base_city = father.home_city
		base_country = father.home_country
	elif mother != null and mother.home_city != "":
		base_city = mother.home_city
		base_country = mother.home_country
	if base_city != "":
		child.birth_city = base_city
		child.birth_country = base_country
		child.home_city = base_city
		child.home_country = base_country

	child.parents = []
	if father != null:
		child.parents.append(father.id)
		if child.id not in father.children:
			father.children.append(child.id)
	if mother != null:
		child.parents.append(mother.id)
		if child.id not in mother.children:
			mother.children.append(child.id)

	var royal_parent: Person = null
	if father != null and father.is_royal:
		royal_parent = father
	elif mother != null and mother.is_royal:
		royal_parent = mother

	if royal_parent != null:
		child.is_royal = true
		child.social_class = "Royal"
		child.palace_owned = true
		child.realm_id = int(royal_parent.realm_id)
		child.dynasty_origin = str(royal_parent.dynasty_origin)
		if str(child.bending_nation).strip_edges() == "":
			child.bending_nation = str(royal_parent.bending_nation)
func align_immediate_family_stats_to_child(child: Person, father: Person, mother: Person) -> void:
	if child == null:
		return

	_seed_parent_stats_from_child(father, child)
	_seed_parent_stats_from_child(mother, child)


func _seed_parent_stats_from_child(parent: Person, child: Person) -> void:
	if parent == null or child == null:
		return
	var smarts_target: float = clamp(float(child.smarts), 0.0, 100.0)
	var looks_target: float = clamp(float(child.looks), 0.0, 100.0)
	var health_target: float = clamp(float(child.health), 0.0, 200.0)
	var mental_target: float = clamp(float(child.mental_health), 0.0, 100.0)
	var imagination_target: float = clamp(float(child.imagination), 0.0, 100.0)
	var smarts_floor: float = max(22.0, smarts_target * 0.62)
	var looks_floor: float = max(18.0, looks_target * 0.58)
	var health_floor: float = max(70.0, health_target * 0.65)
	var mental_floor: float = max(35.0, mental_target * 0.55)
	var imagination_floor: float = max(12.0, imagination_target * 0.48)
	parent.smarts = int(round(_roll_family_stat_near_target(smarts_target, 100.0, smarts_floor, 10.0, 0.12, 24.0)))
	parent.looks = int(round(_roll_family_stat_near_target(looks_target, 100.0, looks_floor, 10.0, 0.12, 24.0)))
	parent.health = _roll_family_stat_near_target(health_target, 200.0, health_floor, 16.0, 0.14, 34.0)
	parent.mental_health = _roll_family_stat_near_target(mental_target, 100.0, mental_floor, 10.0, 0.14, 24.0)
	parent.imagination = int(round(_roll_family_stat_near_target(imagination_target, 100.0, imagination_floor, 10.0, 0.14, 24.0)))


func _roll_family_stat_near_target(target: float, max_value: float, min_value: float, jitter:= 10.0, outlier_chance:= 0.12, outlier_jitter:= 24.0) -> float:
	var working_jitter:= jitter
	if randf() < outlier_chance:
		working_jitter = outlier_jitter
	return clamp(target + randf_range(- working_jitter, working_jitter), min_value, max_value)