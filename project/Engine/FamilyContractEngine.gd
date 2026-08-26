extends Resource
class_name FamilyContractEngine

const FAMILY_CONTRACT_SCHEMA:= "eralife.family_contract"
const FAMILY_CONTRACT_VERSION:= 1
const HOUSEHOLD_CONTRACT_SCHEMA:= "eralife.family_contract.household"
const CUSTODIAL_CONTRACT_SCHEMA:= "eralife.family_contract.custodial_authority"
const ESTATE_CONTRACT_SCHEMA:= "eralife.family_contract.estate"

var gs
var family_contract_cache: Dictionary = {}
var household_contract_cache: Dictionary = {}
var estate_contract_cache: Dictionary = {}
var last_report: Dictionary = {}

func _init(_gs = null):
	gs = _gs


func export_state() -> Dictionary:
	return {
		"schema": FAMILY_CONTRACT_SCHEMA + "_state",
		"version": FAMILY_CONTRACT_VERSION,
		"family_contract_cache": family_contract_cache.duplicate(true),
		"household_contract_cache": household_contract_cache.duplicate(true),
		"estate_contract_cache": estate_contract_cache.duplicate(true),
		"last_report": last_report.duplicate(true)
	}


func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "FamilyContractEngine import_state expected a Dictionary."
		}

	family_contract_cache = _safe_dictionary(data.get("family_contract_cache", {}))
	household_contract_cache = _safe_dictionary(data.get("household_contract_cache", {}))
	estate_contract_cache = _safe_dictionary(data.get("estate_contract_cache", {}))
	last_report = _safe_dictionary(data.get("last_report", {}))

	return {
		"success": true,
		"family_contract_count": family_contract_cache.size(),
		"household_contract_count": household_contract_cache.size(),
		"estate_contract_count": estate_contract_cache.size()
	}


func yearly_tick(_payload:= {}) -> void:
	rebuild_loaded_family_contracts({
		"source": "family_contract_engine_yearly_tick",
	})


func on_family_structure_changed(payload:= {}) -> void:
	var actor: Person = _resolve_person_from_payload(payload)
	if actor == null:
		return

	rebuild_family_contract_cluster(actor, {
		"source": "family_contract_engine_family_structure_changed",
		"payload": _safe_dictionary(payload)
	})


func on_npc_born(payload:= {}) -> void:
	var actor: Person = _resolve_person_from_payload(payload)
	if actor == null:
		return

	rebuild_family_contract_cluster(actor, {
		"source": "family_contract_engine_npc_born",
		"payload": _safe_dictionary(payload)
	})


func on_npc_died(payload:= {}) -> void:
	var actor: Person = _resolve_person_from_payload(payload)
	if actor == null:
		return

	build_estate_contract(actor, {
		"source": "family_contract_engine_npc_died_snapshot",
		"payload": _safe_dictionary(payload)
	})


func rebuild_loaded_family_contracts(context: Dictionary = {}) -> Dictionary:
	var rebuilt: int = 0
	if gs == null:
		return {
			"success": false,
			"reason": "GameState unavailable.",
			"rebuilt_count": rebuilt
		}

	for raw_person in gs.npcs:
		if not raw_person is Person:
			continue
		var person: Person = raw_person
		if person == null:
			continue
		if int(person.id) <= 0:
			continue

		ensure_family_contract(person, context)
		rebuilt += 1

	if gs.player != null:
		ensure_family_contract(gs.player, context)
		rebuilt += 1

	last_report = {
		"success": true,
		"mode": "family_contract_rebuild_loaded",
		"rebuilt_count": rebuilt,
		"updated_at_ms": int(Time.get_ticks_msec())
	}

	return last_report.duplicate(true)


func rebuild_family_contract_cluster(anchor: Person, context: Dictionary = {}) -> Dictionary:
	var rebuilt_ids: Array = []
	if anchor == null:
		return {
			"success": false,
			"reason": "Anchor unavailable.",
			"rebuilt_ids": rebuilt_ids
		}

	var candidates: Array = [anchor]
	for raw_parent_id in _parent_ids_for(anchor):
		var parent: Person = _person_by_id(int(raw_parent_id))
		if parent != null:
			candidates.append(parent)

	for raw_child_id in _child_ids_for(anchor):
		var child: Person = _person_by_id(int(raw_child_id))
		if child != null:
			candidates.append(child)

	var partner: Person = _person_by_id(_partner_id_for(anchor))
	if partner != null:
		candidates.append(partner)

	for raw_person in candidates:
		if not raw_person is Person:
			continue
		var person: Person = raw_person
		if person == null:
			continue
		if rebuilt_ids.has(int(person.id)):
			continue
		ensure_family_contract(person, context)
		rebuilt_ids.append(int(person.id))

	return {
		"success": true,
		"mode": "family_contract_rebuild_cluster",
		"anchor_id": int(anchor.id),
		"rebuilt_ids": rebuilt_ids
	}


func ensure_family_contract(person: Person, context: Dictionary = {}) -> Dictionary:
	if person == null:
		return {}

	var person_id: int = int(person.id)
	if person_id <= 0:
		return {}

	if person.has_method("ensure_person_contract"):
		person.ensure_person_contract({
			"source": str(context.get("source", "family_contract_engine")),
			"family_contract_engine": true,
			"controlled_actor_id": person_id
		})

	var family_contract: Dictionary = _build_family_contract(person, context)
	family_contract_cache [person_id] = family_contract.duplicate(true)

	if typeof(person.person_contract) != TYPE_DICTIONARY:
		person.person_contract = {}

	person.person_contract ["family"] = family_contract.duplicate(true)
	person.person_contract ["family_graph"] = _safe_dictionary(family_contract.get("family_graph_legacy", {}))
	person.person_contract ["updated_at_ms"] = int(Time.get_ticks_msec())

	return family_contract.duplicate(true)


func get_family_contract(person: Person, context: Dictionary = {}) -> Dictionary:
	return ensure_family_contract(person, context)


func get_household_contract(person: Person, context: Dictionary = {}) -> Dictionary:
	if person == null:
		return {}

	var family_contract: Dictionary = ensure_family_contract(person, context)
	return _safe_dictionary(family_contract.get("household", {}))


func get_household_members(person: Person, context: Dictionary = {}) -> Array:
	var members: Array = []
	if person == null:
		return members

	var household: Dictionary = get_household_contract(person, context)
	var member_ids: Array = _safe_array(household.get("members", []))
	for raw_id in member_ids:
		var member: Person = _person_by_id(int(raw_id))
		if member == null:
			continue
		if not member.alive:
			continue
		members.append(member)

	return members


func get_custodial_contract(person: Person, context: Dictionary = {}) -> Dictionary:
	if person == null:
		return {}

	var family_contract: Dictionary = ensure_family_contract(person, context)
	return _safe_dictionary(family_contract.get("custodial_adult", {}))


func get_custodial_adult(person: Person, context: Dictionary = {}) -> Person:
	var custodial_contract: Dictionary = get_custodial_contract(person, context)
	var custodian_id: int = int(custodial_contract.get("custodian_id", -1))
	if custodian_id <= 0:
		return null

	return _person_by_id(custodian_id)


func is_minor_under_authority(person: Person, context: Dictionary = {}) -> bool:
	if person == null:
		return false
	if not person.alive:
		return false

	var custodial_contract: Dictionary = get_custodial_contract(person, context)
	if custodial_contract.is_empty():
		return false

	var expires_age: int = int(custodial_contract.get("expires_age", _era_adulthood_age(person)))
	if int(person.age) >= expires_age:
		return false

	return int(custodial_contract.get("custodian_id", -1)) > 0


func build_estate_contract(owner: Person, context: Dictionary = {}) -> Dictionary:
	if owner == null:
		return {}

	var owner_id: int = int(owner.id)
	if owner_id <= 0:
		return {}

	var heirs: Array = _build_estate_heirs(owner, context)
	var contract: Dictionary = {
		"schema": ESTATE_CONTRACT_SCHEMA,
		"version": FAMILY_CONTRACT_VERSION,
		"estate_id": "estate_%d_%d" % [owner_id, int(_current_year())],
		"owner_id": owner_id,
		"owner_name": _person_name(owner),
		"owner_alive_when_built": bool(owner.alive),
		"era": _current_era_name(),
		"year": _current_year(),
		"heirs": heirs,
		"distribution_policy": _estate_distribution_policy_for(owner),
		"asset_scope": {
			"cash": true,
			"vehicles": true,
			"property": false,
			"heirlooms": false,
			"royal_claims": bool(owner.is_royal) or bool(owner.is_ruler)
		},
		"execution": {
			"state": "prebuilt",
			"executed": false,
			"executed_at_ms": 0,
			"executor": "family_contract_engine"
		},
		"contract_mesh": {
			"source_of_truth": "family_contract_engine",
			"can_interact_with": ["family_control", "school", "food", "restaurant", "movie_theater", "power", "royalty", "property", "vehicles"]
		},
		"created_at_ms": int(Time.get_ticks_msec()),
		"updated_at_ms": int(Time.get_ticks_msec()),
		"context": context.duplicate(true)
	}

	estate_contract_cache [owner_id] = contract.duplicate(true)

	if typeof(owner.person_contract) == TYPE_DICTIONARY:
		var family_contract: Dictionary = _safe_dictionary(owner.person_contract.get("family", {}))
		family_contract ["estate"] = contract.duplicate(true)
		family_contract ["inheritance_chain"] = heirs.duplicate(true)
		owner.person_contract ["family"] = family_contract

	return contract.duplicate(true)


func execute_estate_contract(dead_person: Person, explicit_heir: Person = null, context: Dictionary = {}) -> Dictionary:
	if dead_person == null:
		return {
			"success": false,
			"reason": "Dead person unavailable."
		}

	var dead_id: int = int(dead_person.id)
	if dead_id <= 0:
		return {
			"success": false,
			"reason": "Dead person id invalid."
		}

	var contract: Dictionary = _safe_dictionary(estate_contract_cache.get(dead_id, {}))
	if contract.is_empty():
		contract = build_estate_contract(dead_person, {
			"source": "execute_estate_contract_missing_prebuilt_contract",
			"payload": context.duplicate(true)
		})

	var heir: Person = explicit_heir
	if heir == null:
		heir = _resolve_primary_living_heir(contract)

	if heir == null:
		return {
			"success": false,
			"reason": "No living heir resolved.",
			"contract": contract.duplicate(true)
		}

	if int(heir.id) == dead_id:
		return {
			"success": false,
			"reason": "Estate heir cannot be the dead person.",
			"contract": contract.duplicate(true)
		}

	var inherited_cash: float = 0.0
	if float(dead_person.bank_balance) > 0.0:
		inherited_cash = float(dead_person.bank_balance)
		heir.bank_balance = float(heir.bank_balance) + inherited_cash
		dead_person.bank_balance = 0.0

	var inherited_vehicle_count: int = 0
	if gs != null and gs.vehicle_engine != null:
		inherited_vehicle_count = _transfer_estate_bucket_count(gs.vehicle_engine.vehicles, dead_id, int(heir.id))

	var execution: Dictionary = _safe_dictionary(contract.get("execution", {}))
	execution ["state"] = "executed"
	execution ["executed"] = true
	execution ["executed_at_ms"] = int(Time.get_ticks_msec())
	execution ["heir_id"] = int(heir.id)
	execution ["heir_name"] = _person_name(heir)
	execution ["inherited_cash"] = inherited_cash
	execution ["inherited_vehicle_count"] = inherited_vehicle_count

	contract ["execution"] = execution
	contract ["updated_at_ms"] = int(Time.get_ticks_msec())
	estate_contract_cache [dead_id] = contract.duplicate(true)

	_write_estate_notice(dead_person, heir, inherited_cash, inherited_vehicle_count)

	return {
		"success": true,
		"mode": "estate_contract_executed",
		"dead_person_id": dead_id,
		"heir_id": int(heir.id),
		"inherited_cash": inherited_cash,
		"inherited_vehicle_count": inherited_vehicle_count,
		"contract": contract.duplicate(true)
	}


func _build_family_contract(person: Person, context: Dictionary = {}) -> Dictionary:
	var parent_ids: Array = _parent_ids_for(person)
	var child_ids: Array = _child_ids_for(person)
	var sibling_ids: Array = _sibling_ids_for(person, parent_ids)
	var partner_id: int = _partner_id_for(person)
	var household: Dictionary = _build_household_contract(person, parent_ids, child_ids, partner_id, context)
	var custodial_contract: Dictionary = _build_custodial_contract(person, parent_ids, context)
	var estate_contract: Dictionary = build_estate_contract(person, {
		"source": str(context.get("source", "family_contract_engine_build_family")),
	})

	var family_contract: Dictionary = {
		"schema": FAMILY_CONTRACT_SCHEMA,
		"version": FAMILY_CONTRACT_VERSION,
		"person_id": int(person.id),
		"person_name": _person_name(person),
		"era": _current_era_name(),
		"year": _current_year(),
		"parents": parent_ids,
		"children": child_ids,
		"siblings": sibling_ids,
		"partner": _partner_contract(person, partner_id),
		"household": household.duplicate(true),
		"custodial_adult": custodial_contract.duplicate(true),
		"inheritance_chain": _safe_array(estate_contract.get("heirs", [])),
		"estate": estate_contract.duplicate(true),
		"dynasty": _dynasty_contract_for(person),
		"royal_family": _royal_family_contract_for(person),
		"household_cluster": {
			"household_id": int(household.get("household_id", -1)),
			"member_ids": _safe_array(household.get("members", [])),
			"member_count": _safe_array(household.get("members", [])).size(),
			"living_arrangement": str(household.get("living_arrangement", "unknown")),
			"location_anchor_id": int(household.get("location_anchor_id", int(person.id)))
		},
		"family_graph_legacy": {
			"parent_ids": parent_ids.duplicate(true),
			"child_ids": child_ids.duplicate(true),
			"partner_id": partner_id,
			"marital_status": str(person.marital_status),
			"ex_partners": _safe_array(person.ex_partners),
			"maiden_last_name": str(person.maiden_last_name),
			"parents_exploit_fame": bool(person.parents_exploit_fame)
		},
		"contract_mesh": {
			"source_of_truth": "family_contract_engine",
			"family_generation_owner": "npc_factory",
			"control_owner": "family_control_engine",
			"can_interact_with": ["school", "food", "restaurant", "movie_theater", "power", "superhero", "royalty", "inheritance", "household_location"]
		},
		"created_at_ms": int(Time.get_ticks_msec()),
		"updated_at_ms": int(Time.get_ticks_msec()),
		"context": context.duplicate(true)
	}

	household_contract_cache [int(household.get("household_id", int(person.id)))] = household.duplicate(true)
	return family_contract


func _build_household_contract(person: Person, parent_ids: Array, child_ids: Array, partner_id: int, context: Dictionary = {}) -> Dictionary:
	var member_ids: Array = _household_member_ids_for(person, parent_ids, child_ids, partner_id)
	var location_anchor_id: int = _household_location_anchor_id_for(person, member_ids, parent_ids)
	var location_anchor: Person = _person_by_id(location_anchor_id)
	if location_anchor == null:
		location_anchor = person

	var royal_lock: Dictionary = _royal_household_lock_for(member_ids)
	var target_realm_id: int = int(location_anchor.realm_id)
	var target_city: String = str(location_anchor.home_city)
	var target_country: String = str(location_anchor.home_country)

	if bool(royal_lock.get("locked", false)):
		if int(royal_lock.get("realm_id", -1)) > 0:
			target_realm_id = int(royal_lock.get("realm_id", -1))
		if str(royal_lock.get("capital_city", "")).strip_edges() != "":
			target_city = str(royal_lock.get("capital_city", "")).strip_edges()
		if str(royal_lock.get("realm_name", "")).strip_edges() != "":
			target_country = str(royal_lock.get("realm_name", "")).strip_edges()

	var household_id: int = _stable_household_id(member_ids, target_city, target_country)

	return {
		"schema": HOUSEHOLD_CONTRACT_SCHEMA,
		"version": FAMILY_CONTRACT_VERSION,
		"household_id": household_id,
		"head_of_household_id": _head_of_household_id_for(person, member_ids, location_anchor_id, royal_lock),
		"location_anchor_id": location_anchor_id,
		"members": member_ids,
		"member_count": member_ids.size(),
		"location": {
			"realm_id": target_realm_id,
			"city": target_city,
			"country": target_country,
			"era": _current_era_name()
		},
		"wealth_tier": _wealth_tier_for_members(member_ids),
		"living_arrangement": _living_arrangement_for(person, member_ids, partner_id),
		"rules": {
			"movement_locked": bool(royal_lock.get("locked", false)),
			"royal_bound": bool(royal_lock.get("locked", false)),
			"custody_locked": int(person.age) < _era_adulthood_age(person),
		},
		"royal_lock": royal_lock.duplicate(true),
		"contract_mesh": {
			"source_of_truth": "family_contract_engine",
			"readable_by": ["school_hub", "food_hub", "restaurant_hub", "movie_theater_hub", "power_hub", "family_control_engine"],
		},
		"created_at_ms": int(Time.get_ticks_msec()),
		"updated_at_ms": int(Time.get_ticks_msec()),
		"context": context.duplicate(true)
	}


func _build_custodial_contract(person: Person, parent_ids: Array, context: Dictionary = {}) -> Dictionary:
	if person == null:
		return {}
	if not person.alive:
		return {}
	if int(person.age) >= _era_adulthood_age(person):
		return {}

	var best_parent: Person = null
	var best_score: int = -1

	for raw_parent_id in parent_ids:
		var parent: Person = _person_by_id(int(raw_parent_id))
		if parent == null:
			continue
		if not parent.alive:
			continue
		if int(parent.age) < _era_adulthood_age(parent):
			continue

		var score: int = 0
		if str(parent.home_city) == str(person.home_city):
			score += 3
		if str(parent.home_country) == str(person.home_country):
			score += 2

		var partner_id: int = _partner_id_for(parent)
		if parent_ids.has(partner_id):
			score += 1

		if bool(parent.is_ruler) or bool(parent.is_royal):
			score += 2

		if best_parent == null or score > best_score:
			best_parent = parent
			best_score = score

	if best_parent == null:
		return {}

	return {
		"schema": CUSTODIAL_CONTRACT_SCHEMA,
		"version": FAMILY_CONTRACT_VERSION,
		"child_id": int(person.id),
		"custodian_id": int(best_parent.id),
		"custodian_name": _person_name(best_parent),
		"authority_type": _custodial_authority_type_for(best_parent),
		"legal_strength": _custodial_legal_strength_for(person, best_parent),
		"expires_age": _era_adulthood_age(person),
		"shared_custody": _has_shared_parent_household(person, parent_ids, int(best_parent.id)),
		"era": _current_era_name(),
		"location": {
			"realm_id": int(best_parent.realm_id),
			"city": str(best_parent.home_city),
			"country": str(best_parent.home_country)
		},
		"contract_mesh": {
			"source_of_truth": "family_contract_engine",
		},
		"created_at_ms": int(Time.get_ticks_msec()),
		"updated_at_ms": int(Time.get_ticks_msec()),
		"context": context.duplicate(true)
	}


func _household_member_ids_for(person: Person, parent_ids: Array, child_ids: Array, partner_id: int) -> Array:
	var member_ids: Array = []
	_push_unique_int(member_ids, int(person.id))

	if int(person.age) < _era_adulthood_age(person):
		for raw_parent_id in parent_ids:
			var parent: Person = _person_by_id(int(raw_parent_id))
			if parent == null:
				continue
			if not parent.alive:
				continue

			_push_unique_int(member_ids, int(parent.id))

			for raw_child_id in _child_ids_for(parent):
				var child: Person = _person_by_id(int(raw_child_id))
				if child == null:
					continue
				if not child.alive:
					continue
				if int(child.age) >= _era_adulthood_age(child):
					continue
				_push_unique_int(member_ids, int(child.id))

		return member_ids

	if partner_id > 0:
		var partner: Person = _person_by_id(partner_id)
		if partner != null and partner.alive:
			_push_unique_int(member_ids, int(partner.id))

	for raw_child_id in child_ids:
		var child: Person = _person_by_id(int(raw_child_id))
		if child == null:
			continue
		if not child.alive:
			continue
		if int(child.age) >= _era_adulthood_age(child):
			continue
		_push_unique_int(member_ids, int(child.id))

	if partner_id > 0:
		var partner_for_children: Person = _person_by_id(partner_id)
		if partner_for_children != null:
			for raw_partner_child_id in _child_ids_for(partner_for_children):
				var partner_child: Person = _person_by_id(int(raw_partner_child_id))
				if partner_child == null:
					continue
				if not partner_child.alive:
					continue
				if int(partner_child.age) >= _era_adulthood_age(partner_child):
					continue
				_push_unique_int(member_ids, int(partner_child.id))

	return member_ids


func _household_location_anchor_id_for(person: Person, member_ids: Array, parent_ids: Array) -> int:
	if person == null:
		return -1

	if int(person.age) >= _era_adulthood_age(person):
		return int(person.id)

	var custodial_contract: Dictionary = _build_custodial_contract(person, parent_ids, {
		"source": "household_location_anchor"
	})
	var custodian_id: int = int(custodial_contract.get("custodian_id", -1))
	if custodian_id > 0:
		return custodian_id

	if not member_ids.is_empty():
		return int(member_ids [0])

	return int(person.id)


func _head_of_household_id_for(person: Person, member_ids: Array, location_anchor_id: int, royal_lock: Dictionary) -> int:
	if bool(royal_lock.get("locked", false)) and int(royal_lock.get("member_id", -1)) > 0:
		return int(royal_lock.get("member_id", -1))

	var location_anchor: Person = _person_by_id(location_anchor_id)
	if location_anchor != null and int(location_anchor.age) >= _era_adulthood_age(location_anchor):
		return int(location_anchor.id)

	for raw_id in member_ids:
		var member: Person = _person_by_id(int(raw_id))
		if member == null:
			continue
		if not member.alive:
			continue
		if int(member.age) >= _era_adulthood_age(member):
			return int(member.id)

	return int(person.id) if person != null else -1


func _royal_household_lock_for(member_ids: Array) -> Dictionary:
	for raw_member_id in member_ids:
		var member: Person = _person_by_id(int(raw_member_id))
		if member == null:
			continue
		if not member.alive:
			continue

		var member_is_court_locked: bool = bool(member.is_ruler)
		member_is_court_locked = member_is_court_locked or ((bool(member.is_royal) or str(member.royal_title).strip_edges() != "" or str(member.social_class).strip_edges() == "Royal") and not bool(member.exiled) and not bool(member.deposed))
		if not member_is_court_locked:
			continue

		var locked_realm_id: int = int(member.realm_id)
		var locked_realm_name: String = str(member.home_country).strip_edges()
		var locked_capital_city: String = str(member.home_city).strip_edges()

		if gs != null and gs.realm_engine != null and locked_realm_id > 0 and gs.realm_engine.realms.has(locked_realm_id):
			var realm_raw: Variant = gs.realm_engine.realms.get(locked_realm_id, {})
			var realm: Dictionary = realm_raw if typeof(realm_raw) == TYPE_DICTIONARY else {}
			locked_realm_name = str(realm.get("name", locked_realm_name)).strip_edges()
			locked_capital_city = str(realm.get("capital_city", realm.get("capital", locked_capital_city))).strip_edges()

		return {
			"locked": true,
			"member_id": int(member.id),
			"realm_id": locked_realm_id,
			"realm_name": locked_realm_name,
			"capital_city": locked_capital_city,
			"reason": "royal_household_bound_to_court"
		}

	return {
		"locked": false,
		"member_id": -1,
		"realm_id": -1,
		"realm_name": "",
		"capital_city": "",
		"reason": ""
	}


func _build_estate_heirs(owner: Person, context: Dictionary = {}) -> Array:
	var heirs: Array = []
	if owner == null:
		return heirs

	var explicit_heir_id: int = int(context.get("explicit_heir_id", context.get("heir_id", -1)))
	if explicit_heir_id > 0:
		_append_heir(heirs, explicit_heir_id, 0, "explicit_heir", 1.0)

	var spouse_id: int = _partner_id_for(owner)
	if spouse_id > 0:
		_append_heir(heirs, spouse_id, 1, "spouse", _spouse_estate_share_for(owner))

	var priority: int = 2
	for raw_child_id in _child_ids_for(owner):
		_append_heir(heirs, int(raw_child_id), priority, "child", _child_estate_share_for(owner))
		priority += 1

	for raw_parent_id in _parent_ids_for(owner):
		_append_heir(heirs, int(raw_parent_id), priority, "parent", 0.25)
		priority += 1

	heirs.sort_custom(func (a, b): return int(a.get("priority", 9999)) < int(b.get("priority", 9999)))
	return heirs


func _append_heir(heirs: Array, heir_id: int, priority: int, heir_type: String, share_hint: float) -> void:
	if heir_id <= 0:
		return

	for raw_heir in heirs:
		if typeof(raw_heir) != TYPE_DICTIONARY:
			continue
		if int(raw_heir.get("id", -1)) == heir_id:
			return

	var heir: Person = _person_by_id(heir_id)
	heirs.append({
		"id": heir_id,
		"name": _person_name(heir),
		"priority": priority,
		"type": heir_type,
		"alive": bool(heir.alive) if heir != null else false,
		"share_hint": share_hint
	})


func _resolve_primary_living_heir(contract: Dictionary) -> Person:
	var heirs: Array = _safe_array(contract.get("heirs", []))
	for raw_heir in heirs:
		if typeof(raw_heir) != TYPE_DICTIONARY:
			continue
		var heir_id: int = int((raw_heir as Dictionary).get("id", -1))
		if heir_id <= 0:
			continue

		var heir: Person = _person_by_id(heir_id)
		if heir == null:
			continue
		if not heir.alive:
			continue

		return heir

	return null


func _write_estate_notice(dead_person: Person, heir: Person, inherited_cash: float, inherited_vehicle_count: int) -> void:
	if gs == null or dead_person == null or heir == null:
		return
	if gs.player == null or int(heir.id) != int(gs.player.id):
		return

	var inheritance_parts: Array = []
	if inherited_cash > 0.0:
		inheritance_parts.append("$%.0f in cash" % inherited_cash)
	if inherited_vehicle_count == 1:
		inheritance_parts.append("1 vehicle")
	elif inherited_vehicle_count > 1:
		inheritance_parts.append("%d vehicles" % inherited_vehicle_count)

	if inheritance_parts.is_empty():
		return

	var inheritance_text: String = "I inherited %s from %s %s." % [
		", ".join(inheritance_parts),
		dead_person.first_name,
		dead_person.last_name
	]

	if gs.has_method("queue_player_inheritance_notice"):
		gs.queue_player_inheritance_notice(inheritance_text)

	if gs.narrative_engine != null:
		gs.narrative_engine.log_event(heir, {
			"type": "text",
			"text": inheritance_text
		})

	if gs.has_method("push_world_feed"):
		gs.push_world_feed(inheritance_text, {
			"npc_id": heir.id,
			"personally_relevant": true,
			"category": "inheritance",
			"event_name": "inheritance_received",
			"source": "family_contract_engine"
		})


func _transfer_estate_bucket_count(bucket: Dictionary, from_id: int, to_id: int) -> int:
	if typeof(bucket) != TYPE_DICTIONARY:
		return 0
	if not bucket.has(from_id):
		return 0

	var before_count: int = 0
	var before_bucket = bucket.get(to_id, [])
	if typeof(before_bucket) == TYPE_ARRAY:
		before_count = before_bucket.size()

	var moved_value = bucket [from_id]
	if bucket.has(to_id) and typeof(bucket [to_id]) == TYPE_ARRAY and typeof(moved_value) == TYPE_ARRAY:
		var combined: Array = bucket [to_id].duplicate()
		for item in moved_value:
			combined.append(item)
		bucket [to_id] = combined
	else:
		bucket [to_id] = moved_value

	bucket.erase(from_id)

	var after_count: int = 0
	var after_bucket = bucket.get(to_id, [])
	if typeof(after_bucket) == TYPE_ARRAY:
		after_count = after_bucket.size()

	return max(0, after_count - before_count)


func _parent_ids_for(person: Person) -> Array:
	var parent_ids: Array = []
	if person == null:
		return parent_ids

	if gs != null and gs.has_method("get_npc_facts_by_id"):
		var facts: Dictionary = gs.get_npc_facts_by_id(int(person.id))
		for raw_id in _safe_array(facts.get("parents", [])):
			_push_unique_int(parent_ids, int(raw_id))

	for raw_id in _safe_array(person.parents):
		_push_unique_int(parent_ids, int(raw_id))

	return parent_ids


func _child_ids_for(person: Person) -> Array:
	var child_ids: Array = []
	if person == null:
		return child_ids

	if gs != null and gs.has_method("get_npc_facts_by_id"):
		var facts: Dictionary = gs.get_npc_facts_by_id(int(person.id))
		for raw_id in _safe_array(facts.get("children", [])):
			_push_unique_int(child_ids, int(raw_id))

	for raw_id in _safe_array(person.children):
		_push_unique_int(child_ids, int(raw_id))

	return child_ids


func _sibling_ids_for(person: Person, parent_ids: Array) -> Array:
	var sibling_ids: Array = []
	if person == null:
		return sibling_ids

	for raw_parent_id in parent_ids:
		var parent: Person = _person_by_id(int(raw_parent_id))
		if parent == null:
			continue

		for raw_child_id in _child_ids_for(parent):
			var child_id: int = int(raw_child_id)
			if child_id <= 0:
				continue
			if child_id == int(person.id):
				continue
			_push_unique_int(sibling_ids, child_id)

	return sibling_ids


func _partner_id_for(person: Person) -> int:
	if person == null:
		return -1

	var raw_partner: Variant = person.get("partner")
	if raw_partner != null:
		if raw_partner is Person:
			var partner_person: Person = raw_partner as Person
			if partner_person != null:
				return int(partner_person.id)

		if typeof(raw_partner) == TYPE_OBJECT:
			var partner_object: Object = raw_partner as Object
			if partner_object != null:
				var raw_id: Variant = partner_object.get("id")
				if raw_id != null:
					return int(raw_id)

		if typeof(raw_partner) == TYPE_DICTIONARY:
			var partner_dictionary: Dictionary = raw_partner as Dictionary
			return int(partner_dictionary.get("id", -1))

		if typeof(raw_partner) == TYPE_INT or typeof(raw_partner) == TYPE_FLOAT:
			return int(raw_partner)

		if typeof(raw_partner) == TYPE_STRING:
			var partner_text: String = str(raw_partner).strip_edges()
			if partner_text.is_valid_int():
				return int(partner_text)

	if gs != null and gs.has_method("get_valid_partner"):
		var partner: Person = gs.get_valid_partner(person, true, true)
		if partner != null:
			return int(partner.id)

	return -1


func _partner_contract(person: Person, partner_id: int) -> Dictionary:
	if partner_id <= 0:
		return {
			"partner_id": -1,
			"partner_name": "",
			"marital_status": str(person.marital_status) if person != null else "",
			"active": false
		}

	var partner: Person = _person_by_id(partner_id)
	return {
		"partner_id": partner_id,
		"partner_name": _person_name(partner),
		"marital_status": str(person.marital_status) if person != null else "",
		"active": partner != null and partner.alive
	}


func _dynasty_contract_for(person: Person) -> Dictionary:
	if person == null:
		return {}

	return {
		"dynasty_origin": str(person.dynasty_origin),
		"dynasty_prestige": int(person.dynasty_prestige),
		"last_name": str(person.last_name),
		"bloodline_tags": _safe_array(_safe_dictionary(person.inherited_systems).get("bloodlines", [])) if typeof(person.inherited_systems) == TYPE_DICTIONARY else [],
		"dynasty_tags": _safe_array(_safe_dictionary(person.inherited_systems).get("dynasties", [])) if typeof(person.inherited_systems) == TYPE_DICTIONARY else []
	}


func _royal_family_contract_for(person: Person) -> Dictionary:
	if person == null:
		return {}

	var realm_name: String = str(person.home_country)
	if gs != null and gs.realm_engine != null and int(person.realm_id) > 0 and gs.realm_engine.realms.has(int(person.realm_id)):
		var realm_raw: Variant = gs.realm_engine.realms.get(int(person.realm_id), {})
		var realm: Dictionary = realm_raw if typeof(realm_raw) == TYPE_DICTIONARY else {}
		realm_name = str(realm.get("name", realm_name))

	return {
		"is_royal": bool(person.is_royal),
		"is_ruler": bool(person.is_ruler),
		"royal_title": str(person.royal_title),
		"realm_id": int(person.realm_id),
		"realm_name": realm_name,
		"succession_rank": int(person.succession_rank),
		"approval": int(person.approval),
		"exiled": bool(person.exiled),
		"deposed": bool(person.deposed),
		"palace_owned": bool(person.palace_owned)
	}


func _estate_distribution_policy_for(owner: Person) -> Dictionary:
	var era_name: String = _current_era_name().to_lower()
	var is_royal_estate: bool = owner != null and (bool(owner.is_ruler) or bool(owner.is_royal) or str(owner.royal_title).strip_edges() != "")

	if is_royal_estate and (era_name.find("ancient") >= 0 or era_name.find("medieval") >= 0):
		return {
			"policy_id": "dynastic_royal_priority",
			"spouse_priority": 1,
			"children_policy": "succession_rank_then_birth_order",
			"estate_style": "dynasty_first",
			"era_based": true
		}

	if era_name.find("ancient") >= 0 or era_name.find("medieval") >= 0:
		return {
			"policy_id": "household_patronage_priority",
			"spouse_priority": 1,
			"children_policy": "birth_order_weighted",
			"estate_style": "household_survival",
			"era_based": true
		}

	return {
		"policy_id": "modern_spouse_then_children",
		"spouse_priority": 1,
		"children_policy": "equal_priority_after_spouse",
		"estate_style": "legal_estate",
		"era_based": true
	}


func _spouse_estate_share_for(owner: Person) -> float:
	var era_name: String = _current_era_name().to_lower()
	if owner != null and (bool(owner.is_ruler) or bool(owner.is_royal)) and (era_name.find("ancient") >= 0 or era_name.find("medieval") >= 0):
		return 0.5
	return 1.0


func _child_estate_share_for(_owner: Person) -> float:
	var era_name: String = _current_era_name().to_lower()
	if era_name.find("ancient") >= 0 or era_name.find("medieval") >= 0:
		return 0.5
	return 1.0


func _custodial_authority_type_for(custodian: Person) -> String:
	if custodian == null:
		return "unknown"

	if bool(custodian.is_ruler) or bool(custodian.is_royal) or str(custodian.royal_title).strip_edges() != "":
		return "royal_parent"

	var era_name: String = _current_era_name().to_lower()
	if era_name.find("ancient") >= 0:
		return "household_parent"
	if era_name.find("medieval") >= 0:
		return "guardian_parent"
	if era_name.find("future") >= 0:
		return "registered_custodian"

	return "parent"


func _custodial_legal_strength_for(person: Person, custodian: Person) -> String:
	if person == null or custodian == null:
		return "none"

	if str(person.home_country) == str(custodian.home_country) and str(person.home_city) == str(custodian.home_city):
		return "full"

	if str(person.home_country) == str(custodian.home_country):
		return "regional"

	return "distant"


func _has_shared_parent_household(person: Person, parent_ids: Array, primary_parent_id: int) -> bool:
	if person == null:
		return false

	for raw_parent_id in parent_ids:
		var parent_id: int = int(raw_parent_id)
		if parent_id <= 0 or parent_id == primary_parent_id:
			continue

		var parent: Person = _person_by_id(parent_id)
		if parent == null:
			continue
		if not parent.alive:
			continue
		if str(parent.home_city) == str(person.home_city) and str(parent.home_country) == str(person.home_country):
			return true

	return false


func _living_arrangement_for(person: Person, member_ids: Array, partner_id: int) -> String:
	if person == null:
		return "unknown"

	var child_count: int = 0
	var adult_count: int = 0

	for raw_id in member_ids:
		var member: Person = _person_by_id(int(raw_id))
		if member == null:
			continue
		if int(member.age) >= _era_adulthood_age(member):
			adult_count += 1
		else:
			child_count += 1

	if member_ids.size() >= 6:
		return "extended_household"
	if int(person.age) < _era_adulthood_age(person) and adult_count > 0:
		return "custodial_family"
	if partner_id > 0 and child_count > 0:
		return "nuclear_family"
	if partner_id > 0:
		return "partner_household"
	if child_count > 0:
		return "single_parent_household"
	if adult_count == 1:
		return "solo_household"

	return "household_cluster"


func _wealth_tier_for_members(member_ids: Array) -> String:
	var total_cash: float = 0.0
	var total_income: float = 0.0

	for raw_id in member_ids:
		var member: Person = _person_by_id(int(raw_id))
		if member == null:
			continue
		total_cash += float(member.bank_balance)
		total_income += float(member.income)

	var score: float = total_cash + total_income
	if score >= 1000000.0:
		return "elite"
	if score >= 250000.0:
		return "upper"
	if score >= 70000.0:
		return "middle"
	if score >= 20000.0:
		return "working"
	return "poor"


func _stable_household_id(member_ids: Array, city: String, country: String) -> int:
	var sorted_ids: Array = member_ids.duplicate()
	sorted_ids.sort()

	var material: String = "%s|%s|%s" % [",".join(sorted_ids.map(func (v): return str(v))), city, country]
	var seed_value: int = _stable_seed(material)
	return max(1, seed_value)


func _era_adulthood_age(_person: Person = null) -> int:
	var era_name: String = _current_era_name().to_lower()
	if era_name.find("ancient") >= 0:
		return 16
	if era_name.find("medieval") >= 0:
		return 16
	return 18


func _current_era_name() -> String:
	if gs != null and gs.era_engine != null:
		if gs.era_engine.has_method("get_current_era_name"):
			return str(gs.era_engine.get_current_era_name())
		if "current_era" in gs.era_engine:
			return str(gs.era_engine.current_era)

	if gs != null and "era" in gs:
		var era_value: Variant = gs.era
		if str(era_value).strip_edges() != "":
			return str(era_value)

	return "Modern Era"


func _current_year() -> int:
	if gs != null and "year" in gs:
		return int(gs.year)
	return 0


func _resolve_person_from_payload(payload) -> Person:
	if payload is Person:
		return payload

	if typeof(payload) == TYPE_DICTIONARY:
		var data: Dictionary = payload as Dictionary

		var npc_id: int = int(data.get("npc_id", data.get("person_id", data.get("actor_id", -1))))
		if npc_id <= 0 and typeof(data.get("data", null)) == TYPE_DICTIONARY:
			var nested: Dictionary = data.get("data", {})
			npc_id = int(nested.get("npc_id", nested.get("person_id", nested.get("actor_id", -1))))

		if npc_id > 0:
			return _person_by_id(npc_id)

		var embedded_npc = data.get("npc", null)
		if embedded_npc is Person:
			return embedded_npc

		var embedded_value = data.get("value", null)
		if embedded_value is Person:
			return embedded_value

	return null


func _person_by_id(person_id: int) -> Person:
	if gs == null or person_id <= 0:
		return null

	if gs.has_method("get_or_reactivate_npc_by_id"):
		return gs.get_or_reactivate_npc_by_id(person_id)

	if gs.has_method("get_npc_by_id"):
		return gs.get_npc_by_id(person_id)

	if gs.player != null and int(gs.player.id) == person_id:
		return gs.player

	for raw_npc in gs.npcs:
		if not raw_npc is Person:
			continue
		var npc: Person = raw_npc
		if int(npc.id) == person_id:
			return npc

	return null


func _person_name(person: Person) -> String:
	if person == null:
		return ""

	var direct_name: String = str(person.name).strip_edges() if "name" in person else ""
	if direct_name != "":
		return direct_name

	var full_name: String = ("%s %s" % [str(person.first_name), str(person.last_name)]).strip_edges()
	if full_name != "":
		return full_name

	return "Unknown Life"


func _push_unique_int(out: Array, value: int) -> void:
	if value <= 0:
		return
	if out.has(value):
		return
	out.append(value)


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)


func _stable_seed(text: String) -> int:
	var hash_value: int = 216613626
	for i in range(text.length()):
		hash_value = int(abs((hash_value * 16777619) + text.unicode_at(i))) % 2147483647
	if hash_value <= 0:
		hash_value = 1
	return hash_value