extends Resource
class_name PopulationMovementContractEngine

const STATE_SCHEMA:= "eralife.population_movement_contract_engine_state"
const CONTRACT_SCHEMA:= "eralife.population_movement_contract"
const CONTRACT_VERSION:= 1
const MAX_LEDGER_ROWS:= 300
const DEFAULT_YEARLY_INFLOW_LIMIT:= 6

var gs
var migration_ledger: Array = []
var last_report: Dictionary = {}

func _init(_gs = null):
	gs = _gs
	_ensure_state()


func run_yearly_migration_contracts(context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	if gs == null or gs.realm_engine == null:
		return _finish_report({
			"success": false,
			"reason": "missing_realm_engine"
		})

	var moved: Array = []
	var blocked: Array = []

	for raw_id in gs.realm_engine.realms.keys():
		var realm_id: int = int(raw_id)
		var realm_raw: Variant = gs.realm_engine.realms.get(raw_id, gs.realm_engine.realms.get(realm_id, {}))
		if typeof(realm_raw) != TYPE_DICTIONARY:
			continue

		var realm: Dictionary = realm_raw
		if not _realm_accepts_migration_contracts(realm):
			continue

		var capacity: int = _realm_capacity_for(realm)
		var current_population: int = int(gs.realm_engine.get_total_population_for_realm(realm_id))
		var open_slots: int = max(0, capacity - current_population)

		if open_slots <= 0:
			var overflow: Dictionary = resolve_overflow_for_realm(realm_id, {
				"capacity": capacity,
				"source": "yearly_migration_capacity_check"
			})
			if int(overflow.get("moved_count", 0)) > 0:
				moved.append(overflow)
			continue

		var target_count: int = min(open_slots, DEFAULT_YEARLY_INFLOW_LIMIT)
		var candidates: Array = _migration_candidates_for_realm(realm_id, realm, target_count)

		for candidate in candidates:
			var contract: Dictionary = _build_migration_contract(candidate, realm_id, realm, context)
			var result: Dictionary = commit_migration_contract(contract, {
				"source": "yearly_migration_contracts"
			})
			if bool(result.get("success", false)):
				moved.append(result)
			else:
				blocked.append(result)

	return _finish_report({
		"success": true,
		"mode": "yearly_migration_contracts_resolved",
		"moved_count": moved.size(),
		"blocked_count": blocked.size(),
		"moved": moved,
		"blocked": blocked
	})


func resolve_overflow_for_realm(realm_id: int, context: Dictionary = {}) -> Dictionary:
	if gs == null or gs.realm_engine == null or realm_id <= 0:
		return {
			"success": false,
			"reason": "invalid_overflow_realm",
			"realm_id": realm_id
		}

	var realm_raw: Variant = gs.realm_engine.realms.get(realm_id, {})
	if typeof(realm_raw) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "missing_realm",
			"realm_id": realm_id
		}

	var realm: Dictionary = realm_raw
	var capacity: int = max(0, int(context.get("capacity", _realm_capacity_for(realm))))
	var residents: Array = gs.realm_engine.derive_realm_residents(realm_id, false)
	var overflow: int = max(0, residents.size() - capacity)
	if overflow <= 0:
		return {
			"success": true,
			"mode": "no_overflow",
			"realm_id": realm_id,
			"moved_count": 0
		}

	var fallback_realm_id: int = _fallback_realm_id(realm_id)
	if fallback_realm_id <= 0:
		return {
			"success": false,
			"reason": "no_fallback_realm_for_overflow",
			"realm_id": realm_id,
			"overflow": overflow
		}

	residents.sort_custom(func (a, b): return _overflow_exit_score(a, realm_id) < _overflow_exit_score(b, realm_id))

	var moved: Array = []
	for resident in residents:
		if moved.size() >= overflow:
			break
		if resident == null:
			continue
		if int(resident.id) == int(realm.get("owner_id", realm.get("ruler_id", -1))):
			continue

		var contract: Dictionary = {
			"schema": CONTRACT_SCHEMA,
			"version": CONTRACT_VERSION,
			"type": "MOVE_POPULATION",
			"contract_id": "overflow_move_%d_%d_%d" % [
				int(resident.id),
				realm_id,
				int(gs.year) if gs != null else 0
			],
			"person_id": int(resident.id),
			"from_realm_id": realm_id,
			"to_realm_id": fallback_realm_id,
			"reason": "capacity_overflow",
			"source": str(context.get("source", "realm_capacity_constraint")),
			"deterministic": true
		}

		var result: Dictionary = commit_migration_contract(contract, {
			"source": "overflow_resolution"
		})
		if bool(result.get("success", false)):
			moved.append(result)

	return {
		"success": true,
		"mode": "overflow_resolved",
		"realm_id": realm_id,
		"capacity": capacity,
		"overflow": overflow,
		"moved_count": moved.size(),
		"moved": moved
	}


func commit_migration_contract(contract: Dictionary, context: Dictionary = {}) -> Dictionary:
	if typeof(contract) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "invalid_migration_contract"
		}

	if str(contract.get("type", "")).strip_edges().to_upper() != "MOVE_POPULATION":
		return {
			"success": false,
			"reason": "unsupported_migration_contract_type",
			"type": str(contract.get("type", ""))
		}

	var person_id: int = int(contract.get("person_id", -1))
	var to_realm_id: int = int(contract.get("to_realm_id", -1))
	var from_realm_id: int = int(contract.get("from_realm_id", -1))
	var person: Person = _person_by_id(person_id)

	if person == null:
		return {
			"success": false,
			"reason": "migration_person_not_found",
			"person_id": person_id
		}

	if to_realm_id <= 0 or gs == null or gs.realm_engine == null or not gs.realm_engine.realms.has(to_realm_id):
		return {
			"success": false,
			"reason": "target_realm_not_found",
			"to_realm_id": to_realm_id
		}

	var target_raw: Variant = gs.realm_engine.realms.get(to_realm_id, {})
	var target_realm: Dictionary = target_raw if typeof(target_raw) == TYPE_DICTIONARY else {}

	var capacity: int = _realm_capacity_for(target_realm)
	var current_population: int = int(gs.realm_engine.get_total_population_for_realm(to_realm_id))
	if capacity > 0 and current_population >= capacity:
		return {
			"success": false,
			"reason": "target_realm_at_capacity",
			"to_realm_id": to_realm_id,
			"capacity": capacity,
			"population": current_population
		}

	person.realm_id = to_realm_id

	var row:= {
		"schema": CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"contract_id": str(contract.get("contract_id", "")),
		"person_id": person_id,
		"from_realm_id": from_realm_id,
		"to_realm_id": to_realm_id,
		"reason": str(contract.get("reason", "migration")),
		"source": str(context.get("source", contract.get("source", "population_movement_contract_engine"))),
		"year": int(gs.year) if gs != null else 0,
		"committed_at_ms": int(Time.get_ticks_msec()),
		"authority": "population_movement_contract_engine"
	}

	_record(row)

	return {
		"success": true,
		"mode": "population_movement_contract_committed",
		"person_id": person_id,
		"from_realm_id": from_realm_id,
		"to_realm_id": to_realm_id,
		"contract": row.duplicate(true)
	}


func export_state() -> Dictionary:
	_ensure_state()
	return {
		"schema": STATE_SCHEMA,
		"version": CONTRACT_VERSION,
		"migration_ledger": migration_ledger.duplicate(true),
		"last_report": last_report.duplicate(true),
		"exported_at_ms": int(Time.get_ticks_msec())
	}


func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "PopulationMovementContractEngine import data must be a Dictionary."
		}

	var ledger_raw: Variant = data.get("migration_ledger", [])
	migration_ledger = ledger_raw.duplicate(true) if typeof(ledger_raw) == TYPE_ARRAY else []
	last_report = data.get("last_report", {}).duplicate(true) if typeof(data.get("last_report", {})) == TYPE_DICTIONARY else {}

	_commit_state()

	return {
		"success": true,
		"mode": "population_movement_contract_engine_imported",
		"ledger_count": migration_ledger.size()
	}


func _migration_candidates_for_realm(realm_id: int, realm: Dictionary, limit: int) -> Array:
	var candidates: Array = []
	if gs == null or not "npcs" in gs:
		return candidates

	for npc in gs.npcs:
		if npc == null:
			continue
		if "alive" in npc and not bool(npc.alive):
			continue
		if not "realm_id" in npc:
			continue
		if int(npc.realm_id) == realm_id:
			continue
		if int(npc.id) == int(realm.get("owner_id", realm.get("ruler_id", -1))):
			continue

		var score: int = _migration_interest_score(npc, realm_id, realm)
		if score < 70:
			continue

		candidates.append({
			"person": npc,
			"score": score
		})

	candidates.sort_custom(func (a, b): return int(a.get("score", 0)) > int(b.get("score", 0)))

	var out: Array = []
	for row in candidates:
		if out.size() >= limit:
			break
		out.append(row.get("person", null))

	return out


func _build_migration_contract(person: Person, to_realm_id: int, realm: Dictionary, context: Dictionary = {}) -> Dictionary:
	var from_realm_id: int = int(person.realm_id) if person != null and "realm_id" in person else -1

	return {
		"schema": CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"type": "MOVE_POPULATION",
		"contract_id": "migration_%d_%d_%d" % [
			int(person.id),
			to_realm_id,
			int(gs.year) if gs != null else 0
		],
		"person_id": int(person.id),
		"from_realm_id": from_realm_id,
		"to_realm_id": to_realm_id,
		"reason": "voluntary_migration",
		"score": _migration_interest_score(person, to_realm_id, realm),
		"source": str(context.get("source", "yearly_population_movement")),
		"deterministic": true
	}


func _migration_interest_score(
		person: Person,
		realm_id: int,
		realm: Dictionary
) -> int:
		if person == null:
			return 0

		var seed_text: String = "%d:%d:%d:%s" % [
			int(person.id),
			realm_id,
			int(gs.year) if gs != null else 0,
			str(realm.get("name", ""))
		]
		var score: int = abs(
			int(hash(seed_text))
		) % 55
		var source_realm: Dictionary = {}

		if (
			gs != null
			and gs.realm_engine != null
			and int(person.realm_id) > 0
		):
			var source_raw: Variant = (
				gs.realm_engine.realms.get(
					int(person.realm_id),
					{}
				)
			)

			if typeof(source_raw) == TYPE_DICTIONARY:
				source_realm = source_raw as Dictionary

		var source_happiness: int = int(
			source_realm.get(
				"happiness",
				50
			)
		)
		var target_happiness: int = int(
			realm.get(
				"happiness",
				50
			)
		)
		var source_debt: int = int(
			source_realm.get(
				"sovereign_debt",
				max(
					0,
					- int(
						source_realm.get(
							"treasury",
							0
						)
					)
				)
			)
		)
		var target_debt: int = int(
			realm.get(
				"sovereign_debt",
				max(
					0,
					- int(
						realm.get(
							"treasury",
							0
						)
					)
				)
			)
		)

		if int(person.realm_id) <= 0:
			score += 24

		if (
			"happiness" in person
			and int(person.happiness) < 35
		):
			score += 18

		if source_happiness < 35:
			score += 22

		if target_happiness > source_happiness:
			score += clamp(
				int(
					round(
						float(
							target_happiness
							- source_happiness
						) * 0.75
					)
				),
				0,
				24
			)

		if source_debt > 0:
			score += 18

		if (
			source_debt > target_debt
			and target_debt <= 0
		):
			score += 14

		if (
			"bank_balance" in person
			and int(person.bank_balance) > 10000
		):
			score += 5

		return clamp(
			score,
			0,
			100
		)

func _overflow_exit_score(person: Person, realm_id: int) -> int:
	if person == null:
		return 999999

	var seed_text: String = "overflow:%d:%d:%d" % [
		int(person.id),
		realm_id,
		int(gs.year) if gs != null else 0
	]

	return abs(int(hash(seed_text))) % 100000


func _fallback_realm_id(excluded_realm_id: int) -> int:
	if gs == null or gs.realm_engine == null:
		return -1

	for raw_id in gs.realm_engine.realms.keys():
		var realm_id: int = int(raw_id)
		if realm_id == excluded_realm_id:
			continue

		var realm_raw: Variant = gs.realm_engine.realms.get(raw_id, gs.realm_engine.realms.get(realm_id, {}))
		if typeof(realm_raw) != TYPE_DICTIONARY:
			continue

		var realm: Dictionary = realm_raw
		if bool(realm.get("migration_contract_required", false)):
			continue

		return realm_id

	return -1


func _realm_accepts_migration_contracts(
		realm: Dictionary
) -> bool:
		if (
			typeof(realm) != TYPE_DICTIONARY
			or realm.is_empty()
		):
			return false

		if bool(
			realm.get(
				"migration_closed",
				false
			)
		):
			return false

		if bool(
			realm.get(
				"forbids_immigration",
				false
			)
		):
			return false

		var capacity: int = _realm_capacity_for(
			realm
		)
		var population: int = int(
			realm.get(
				"population",
				0
			)
		)

		if (
			capacity > 0
			and population >= capacity
		):
			return false

		return true


func _realm_capacity_for(realm: Dictionary) -> int:
	if typeof(realm) != TYPE_DICTIONARY:
		return 0
	return max(0, int(realm.get("realm_capacity", realm.get("capacity", realm.get("population_ceiling", 0)))))


func _person_by_id(person_id: int) -> Person:
	if gs == null or person_id <= 0:
		return null

	if gs.player != null and int(gs.player.id) == person_id:
		return gs.player

	if gs.has_method("get_npc_by_id"):
		return gs.get_npc_by_id(person_id)

	return null


func _record(row: Dictionary) -> void:
	migration_ledger.append(row.duplicate(true))
	if migration_ledger.size() > MAX_LEDGER_ROWS:
		migration_ledger = migration_ledger.slice(migration_ledger.size() - MAX_LEDGER_ROWS, migration_ledger.size())
	_commit_state()


func _finish_report(report: Dictionary) -> Dictionary:
	last_report = report.duplicate(true)
	last_report ["schema"] = "eralife.population_movement_report"
	last_report ["version"] = CONTRACT_VERSION
	last_report ["reported_at_ms"] = int(Time.get_ticks_msec())
	_commit_state()
	return last_report.duplicate(true)


func _ensure_state() -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var state_raw: Variant = gs.scenario_state.get("population_movement_contract_engine_state", {})
	if typeof(state_raw) == TYPE_DICTIONARY:
		var state: Dictionary = state_raw
		var ledger_raw: Variant = state.get("migration_ledger", migration_ledger)
		if typeof(ledger_raw) == TYPE_ARRAY:
			migration_ledger = ledger_raw.duplicate(true)

		var report_raw: Variant = state.get("last_report", last_report)
		if typeof(report_raw) == TYPE_DICTIONARY:
			last_report = report_raw.duplicate(true)


func _commit_state() -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	gs.scenario_state ["population_movement_contract_engine_state"] = {
		"schema": STATE_SCHEMA,
		"version": CONTRACT_VERSION,
		"migration_ledger": migration_ledger.duplicate(true),
		"last_report": last_report.duplicate(true),
		"updated_at_ms": int(Time.get_ticks_msec())
	}