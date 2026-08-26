extends Resource
class_name IslandRealmExpansionEngine

const CONTRACT_SCHEMA:= "eralife.island_realm_creation_contract"
const CONTRACT_VERSION:= 2
const REALM_TYPE_ISLAND:= "ISLAND"
const DEFAULT_VISIBLE_RESIDENT_LIMIT:= 20

var gs




var islands = {}

var island_sizes = {
	"Small": {
		"cost": 500000,
		"capacity": 250000,
		"land": 25,
		"treasury_floor": 50000
	},
	"Medium": {
		"cost": 2000000,
		"capacity": 2000000,
		"land": 80,
		"treasury_floor": 150000
	},
	"Large": {
		"cost": 10000000,
		"capacity": 10000000,
		"land": 180,
		"treasury_floor": 750000
	},
	"Super": {
		"cost": 250000000,
		"capacity": 50000000,
		"land": 620,
		"treasury_floor": 5000000
	}
}

func _init(_gs):
	gs = _gs







func buy_island(buyer: Person, size: String, island_name: String = "") -> Dictionary:
	return submit_island_creation_contract(buyer, {
		"size": size,
		"name": island_name,
		"source": "legacy_buy_island_adapter"
	})







func submit_island_creation_contract(buyer: Person, payload: Dictionary = {}) -> Dictionary:
	var built: Dictionary = build_island_creation_contract(buyer, payload)
	if not bool(built.get("success", false)):
		return built

	if gs == null or gs.realm_engine == null:
		return _fail("realm_engine_unavailable", "Realm engine is unavailable.", {
			"contract": built.get("contract", {})
		})

	if not gs.realm_engine.has_method("resolve_realm_creation_contract"):
		return _fail("realm_engine_missing_contract_resolver", "Realm engine cannot resolve realm creation contracts yet.", {
			"contract": built.get("contract", {})
		})

	var contract: Dictionary = built.get("contract", {})
	var resolved: Dictionary = gs.realm_engine.resolve_realm_creation_contract(contract, {
		"source": "island_realm_contract_layer",
		"contract_layer": "IslandRealmExpansionEngine",
	})

	if not bool(resolved.get("success", false)):
		return resolved

	var realm_id: int = int(resolved.get("realm_id", -1))
	var realm_name: String = str(resolved.get("realm_name", contract.get("name", "Island Realm")))

	_track_island_contract_mirror(int(buyer.id), contract, resolved)

	return {
		"success": true,
		"schema": "eralife.island_realm_creation_commit_report",
		"version": CONTRACT_VERSION,
		"mode": "island_realm_created_through_realm_engine",
		"realm_id": realm_id,
		"realm_name": realm_name,
		"owner_id": int(buyer.id),
		"contract": contract.duplicate(true),
		"realm_report": resolved.duplicate(true),
		"text": "You founded the island realm of %s." % realm_name
	}









func build_island_creation_contract(buyer: Person, payload: Dictionary = {}) -> Dictionary:
	if buyer == null:
		return _fail("missing_buyer", "No buyer was supplied.")

	if "alive" in buyer and not bool(buyer.alive):
		return _fail("buyer_not_alive", "Only a living person can found an island realm.", {
			"buyer_id": int(buyer.id)
		})

	var size: String = str(payload.get("size", payload.get("island_size", ""))).strip_edges()
	if size == "":
		size = "Small"

	if not island_sizes.has(size):
		return _fail("invalid_island_size", "Invalid island size.", {
			"size": size,
			"valid_sizes": island_sizes.keys()
		})

	var blueprint: Dictionary = island_sizes.get(size, {})
	var cost: int = int(blueprint.get("cost", 0))
	var capacity: int = int(blueprint.get("capacity", 0))
	var land: int = int(blueprint.get("land", 10))
	var treasury_floor: int = int(blueprint.get("treasury_floor", 0))

	if capacity <= 0:
		return _fail("invalid_island_capacity", "Island capacity must be greater than zero.", {
			"size": size
		})

	if int(buyer.bank_balance) < cost:
		return _fail("insufficient_funds", "Not enough money.", {
			"buyer_id": int(buyer.id),
			"required": cost,
			"available": int(buyer.bank_balance),
			"size": size
		})

	var requested_name: String = str(payload.get("name", payload.get("realm_name", ""))).strip_edges()
	var resolved_name: String = _resolve_island_name(buyer, size, requested_name)

	var contract_id: String = "island_realm_create_%d_%s_%d" % [
		int(buyer.id),
		size.to_lower(),
		int(gs.year) if gs != null else 0
	]

	var contract:= {
		"schema": CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"contract_id": contract_id,
		"type": "CREATE_REALM",
		"realm_type": REALM_TYPE_ISLAND,
		"realm_kind": "micro_nation",
		"dimension_type": "island_realm",
		"name": resolved_name,
		"size": size,
		"capacity": capacity,
		"realm_capacity": capacity,
		"land": land,
		"treasury_floor": treasury_floor,
		"cost": cost,
		"owner_id": int(buyer.id),
		"ruler_id": int(buyer.id),
		"year_created": int(gs.year) if gs != null else 0,
		"ownership_contract": {
			"schema": "eralife.realm_ownership_contract",
			"version": 1,
			"owner_id": int(buyer.id),
			"current_holder_id": int(buyer.id),
			"ownership_mode": "founder_owned",
			"transferable": true,
		},
		"governance_contract": {
			"schema": "eralife.realm_governance_contract",
			"version": 1,
			"government_style": str(payload.get("government_style", "Monarchy")),
			"governance_deferred": true,
			"ruler_id": int(buyer.id),
			"approval_floor": 60
		},
		"population_contract": {
			"schema": "eralife.realm_population_constraint_contract",
			"version": 1,
			"population_is_registry_derived": true,
			"population_source": "global_entity_registry",
			"membership_field": "realm_id",
			"migration_contract_required": true,
			"max_population": capacity,
			"overflow_behavior": "migration_out",
			"visible_residents_are_view_contract": true
		},
		"payment_contract": {
			"schema": "eralife.realm_creation_payment_contract",
			"version": 1,
			"payer_id": int(buyer.id),
			"amount": cost,
			"currency_source": "Person.bank_balance",
			"validated_by": "IslandRealmExpansionEngine",
			"committed_by": "RealmEngine"
		},
		"source": str(payload.get("source", "island_realm_contract_layer")),
	}

	return {
		"success": true,
		"schema": "eralife.island_realm_creation_contract_report",
		"version": CONTRACT_VERSION,
		"mode": "island_creation_contract_built",
		"contract": contract
	}







func yearly_island_movement(_payload:= {}) -> Dictionary:
	_hydrate_legacy_islands_into_realm_engine()

	if gs != null and "population_movement_contract_engine" in gs and gs.population_movement_contract_engine != null:
		if gs.population_movement_contract_engine.has_method("run_yearly_migration_contracts"):
			return gs.population_movement_contract_engine.run_yearly_migration_contracts({
				"source": "island_realm_engine_legacy_yearly_hook",
			})

	return {
		"success": true,
		"mode": "island_movement_noop",
		"reason": "Population movement is now handled by PopulationMovementContractEngine.",
	}







func get_visible_residents(owner: Person) -> Array:
	if owner == null:
		return []

	var realm_id: int = _realm_id_for_owner(owner)
	if realm_id <= 0:
		return []

	if gs != null and "crown_population_view_contract" in gs and gs.crown_population_view_contract != null:
		if gs.crown_population_view_contract.has_method("get_visible_people_for_realm"):
			return gs.crown_population_view_contract.get_visible_people_for_realm(realm_id, {
				"limit": DEFAULT_VISIBLE_RESIDENT_LIMIT,
				"source": "island_realm_legacy_visible_residents"
			})

	if gs != null and gs.realm_engine != null and gs.realm_engine.has_method("get_visible_residents_for_realm"):
		return gs.realm_engine.get_visible_residents_for_realm(realm_id, DEFAULT_VISIBLE_RESIDENT_LIMIT)

	return []


func export_state() -> Dictionary:
	return {
		"schema": "eralife.island_realm_contract_layer_state",
		"version": CONTRACT_VERSION,
		"islands": islands.duplicate(true),
		"exported_at_ms": int(Time.get_ticks_msec())
	}


func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "IslandRealmExpansionEngine import data must be a Dictionary."
		}

	var islands_raw: Variant = data.get("islands", data)
	islands = islands_raw.duplicate(true) if typeof(islands_raw) == TYPE_DICTIONARY else {}
	_hydrate_legacy_islands_into_realm_engine()

	return {
		"success": true,
		"mode": "island_realm_contract_layer_imported",
		"island_contract_count": islands.size()
	}


func _track_island_contract_mirror(owner_id: int, contract: Dictionary, resolved: Dictionary) -> void:
	if owner_id <= 0:
		return

	islands [owner_id] = {
		"schema": "eralife.island_realm_contract_mirror",
		"version": CONTRACT_VERSION,
		"owner_id": owner_id,
		"realm_id": int(resolved.get("realm_id", -1)),
		"name": str(resolved.get("realm_name", contract.get("name", ""))),
		"size": str(contract.get("size", "")),
		"capacity": int(contract.get("capacity", contract.get("realm_capacity", 0))),
		"realm_type": REALM_TYPE_ISLAND,
		"year_created": int(contract.get("year_created", 0)),
		"population_authority": "global_entity_registry",
		"creation_contract_id": str(contract.get("contract_id", "")),
		"updated_at_ms": int(Time.get_ticks_msec())
	}


func _hydrate_legacy_islands_into_realm_engine() -> void:
	if gs == null or gs.realm_engine == null:
		return

	if not gs.realm_engine.has_method("resolve_realm_creation_contract"):
		return

	for raw_owner_id in islands.keys():
		var owner_id: int = int(raw_owner_id)
		var island_raw: Variant = islands.get(raw_owner_id, {})
		if typeof(island_raw) != TYPE_DICTIONARY:
			continue

		var island: Dictionary = island_raw
		if int(island.get("realm_id", -1)) > 0:
			continue

		var owner: Person = _person_by_id(owner_id)
		if owner == null:
			continue

		var size: String = str(island.get("size", "Small")).strip_edges()
		if not island_sizes.has(size):
			size = "Small"

		var blueprint: Dictionary = island_sizes.get(size, {})
		var legacy_name: String = str(island.get("name", "")).strip_edges()
		if legacy_name == "":
			legacy_name = _resolve_island_name(owner, size, "")

		var legacy_population: Array = []
		var legacy_population_raw: Variant = island.get("population", [])
		if typeof(legacy_population_raw) == TYPE_ARRAY:
			legacy_population = legacy_population_raw.duplicate(true)

		var contract:= {
			"schema": CONTRACT_SCHEMA,
			"version": CONTRACT_VERSION,
			"contract_id": "legacy_island_realm_repair_%d" % owner_id,
			"type": "CREATE_REALM",
			"realm_type": REALM_TYPE_ISLAND,
			"realm_kind": "micro_nation",
			"dimension_type": "island_realm",
			"name": legacy_name,
			"size": size,
			"capacity": int(island.get("capacity", blueprint.get("capacity", 250000))),
			"realm_capacity": int(island.get("capacity", blueprint.get("capacity", 250000))),
			"land": int(blueprint.get("land", 25)),
			"treasury_floor": int(blueprint.get("treasury_floor", 50000)),
			"cost": 0,
			"owner_id": owner_id,
			"ruler_id": owner_id,
			"year_created": int(island.get("year_created", gs.year)),
			"bypass_payment": true,
			"ownership_contract": {
				"owner_id": owner_id,
				"current_holder_id": owner_id,
				"ownership_mode": "legacy_founder_owned",
				"transferable": true,
			},
			"governance_contract": {
				"government_style": "Monarchy",
				"governance_deferred": true,
				"ruler_id": owner_id,
				"approval_floor": 60
			},
			"population_contract": {
				"population_is_registry_derived": true,
				"population_source": "global_entity_registry",
				"membership_field": "realm_id",
				"migration_contract_required": true,
				"max_population": int(island.get("capacity", blueprint.get("capacity", 250000))),
				"overflow_behavior": "migration_out",
				"visible_residents_are_view_contract": true
			}
		}

		var resolved: Dictionary = gs.realm_engine.resolve_realm_creation_contract(contract, {
			"source": "legacy_island_hydration",
			"legacy_population_count": legacy_population.size()
		})

		if not bool(resolved.get("success", false)):
			continue

		var realm_id: int = int(resolved.get("realm_id", -1))
		if realm_id <= 0:
			continue

		for raw_person_id in legacy_population:
			var resident: Person = _person_by_id(int(raw_person_id))
			if resident == null:
				continue
			if "alive" in resident and not bool(resident.alive):
				continue
			resident.realm_id = realm_id

		_track_island_contract_mirror(owner_id, contract, resolved)


func _realm_id_for_owner(owner: Person) -> int:
	if owner == null:
		return -1

	if gs != null and gs.realm_engine != null:
		if gs.realm_engine.has_method("get_realm_id_for_owner"):
			var direct: int = int(gs.realm_engine.get_realm_id_for_owner(int(owner.id), REALM_TYPE_ISLAND))
			if direct > 0:
				return direct

	if islands.has(owner.id):
		var mirror_raw: Variant = islands.get(owner.id, {})
		if typeof(mirror_raw) == TYPE_DICTIONARY:
			var mirror: Dictionary = mirror_raw
			var mirror_realm_id: int = int(mirror.get("realm_id", -1))
			if mirror_realm_id > 0:
				return mirror_realm_id

	return int(owner.realm_id)


func _person_by_id(person_id: int) -> Person:
	if gs == null or person_id <= 0:
		return null

	if gs.player != null and int(gs.player.id) == person_id:
		return gs.player

	if gs.has_method("get_npc_by_id"):
		return gs.get_npc_by_id(person_id)

	return null


func _resolve_island_name(owner: Person, size: String, requested_name: String = "") -> String:
	var clean: String = str(requested_name).strip_edges()
	if clean != "":
		return clean

	var names:= ["Solara", "Emerald Crest", "Dawnrise", "Azure Haven", "Starfall"]
	var seed_text: String = "%d:%s:%d" % [
		int(owner.id) if owner != null else 0,
		size,
		int(gs.year) if gs != null else 0
	]
	var index: int = abs(int(hash(seed_text))) % names.size()
	return str(names [index])


func _fail(reason: String, text: String, extra: Dictionary = {}) -> Dictionary:
	EraLog.failure(
		get_script().resource_path.get_file(),
		str(reason)
	)
	var report:= {
		"success": false,
		"schema": "eralife.island_realm_creation_rejection",
		"version": CONTRACT_VERSION,
		"reason": reason,
		"text": text,
		"authority": "island_realm_contract_layer"
	}

	for key in extra.keys():
		report [key] = extra [key]

	return report