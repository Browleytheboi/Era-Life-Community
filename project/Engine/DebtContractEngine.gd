extends Resource
class_name DebtContractEngine

const ENGINE_SCHEMA:= "eralife.economy.debt_contract_engine"
const CONTRACT_VERSION:= 1
const STATE_KEY:= "debt_contract_engine_state"

var gs: GameState = null
var last_report: Dictionary = {}

func _init(_gs: GameState = null) -> void:
	bind_game_state(_gs)

func bind_game_state(_gs: GameState) -> void:
	gs = _gs
	_ensure_state()

func yearly_tick(_payload: Dictionary = {}) -> Dictionary:
	_ensure_state()

	if gs == null:
		return {
			"success": false,
			"reason": "missing_game_state"
		}

	var reports: Array = []
	var owners: Dictionary = _animal_owner_ids()

	for raw_owner_id in owners.keys():
		var actor: Person = _actor_by_id(int(raw_owner_id))
		if actor == null:
			continue

		var animals: Array = _safe_array(owners.get(raw_owner_id, []))
		var yearly_cost: int = _yearly_animal_maintenance_cost(animals)

		if yearly_cost <= 0:
			continue

		var before_balance: int = int(actor.bank_balance)
		var paid_amount: int = min(before_balance, yearly_cost)
		var unpaid_amount: int = yearly_cost - paid_amount

		if paid_amount > 0:
			actor.bank_balance = max(0, before_balance - paid_amount)

		var debt_report: Dictionary = {}
		if unpaid_amount > 0:
			debt_report = _add_debt(actor, unpaid_amount, {
				"reason": "animal_yearly_maintenance",
				"animal_count": animals.size(),
				"year": int(gs.year if gs != null else 0)
			})

		var text: String = "Animal maintenance cost $%d this year." % yearly_cost
		if unpaid_amount > 0:
			text += " You could not pay $%d, so it became debt." % unpaid_amount

		_emit_diary_text(actor, text, {
			"type": "animal_maintenance_cost",
			"yearly_cost": yearly_cost,
			"paid_amount": paid_amount,
			"unpaid_amount": unpaid_amount
		})

		reports.append({
			"actor_id": int(actor.id),
			"animal_count": animals.size(),
			"yearly_cost": yearly_cost,
			"paid_amount": paid_amount,
			"unpaid_amount": unpaid_amount,
			"balance_before": before_balance,
			"balance_after": int(actor.bank_balance),
			"debt_report": debt_report.duplicate(true)
		})

	last_report = {
		"success": true,
		"mode": "animal_maintenance_debt_yearly_tick",
		"owner_count": reports.size(),
		"reports": reports.duplicate(true),
		"updated_at_ms": int(Time.get_ticks_msec())
	}

	_commit_state()
	return last_report.duplicate(true)

func _yearly_animal_maintenance_cost(animals: Array) -> int:
	var total: int = 0
	for raw_entity in animals:
		var entity: Dictionary = _safe_dictionary(raw_entity)
		if entity.is_empty():
			continue

		var species_contract: Dictionary = _safe_dictionary(entity.get("species_contract", {}))
		var cost: int = int(species_contract.get("yearly_maintenance_cost", 35))

		var stats: Dictionary = _safe_dictionary(entity.get("stats", {}))
		var stress: int = clampi(int(stats.get("stress", 0)), 0, 100)
		var hunger: int = clampi(int(stats.get("hunger", 0)), 0, 100)

		if stress >= 75:
			cost += 15
		if hunger >= 75:
			cost += 20

		total += max(0, cost)

	return total

func _add_debt(actor: Person, amount: int, context: Dictionary = {}) -> Dictionary:
	if actor == null or amount <= 0:
		return {}

	var state: Dictionary = _state()
	var debts: Array = _safe_array(state.get("debts", []))
	var debt_id: String = "debt:%d:%d:%d" % [
		int(actor.id),
		int(gs.year if gs != null else 0),
		int(Time.get_ticks_msec())
	]

	var debt: Dictionary = {
		"schema": "eralife.debt_contract",
		"version": CONTRACT_VERSION,
		"id": debt_id,
		"debt_id": debt_id,
		"actor_id": int(actor.id),
		"amount": amount,
		"remaining": amount,
		"reason": str(context.get("reason", "unknown_debt")),
		"year": int(context.get("year", gs.year if gs != null else 0)),
		"state": "active",
		"created_at_ms": int(Time.get_ticks_msec()),
		"contract_authority": ENGINE_SCHEMA,
		"context": context.duplicate(true)
	}

	debts.append(debt)
	state ["debts"] = debts
	state ["last_debt"] = debt.duplicate(true)
	_set_state(state)

	return {
		"success": true,
		"debt_id": debt_id,
		"amount": amount,
		"remaining": amount
	}

func _animal_owner_ids() -> Dictionary:
	var out: Dictionary = {}
	if gs == null or typeof(gs.entity_registry) != TYPE_DICTIONARY:
		return out

	for raw_id in gs.entity_registry.keys():
		var entity: Dictionary = _safe_dictionary(gs.entity_registry.get(raw_id, {}))
		if entity.is_empty():
			continue
		if not bool(entity.get("alive", true)):
			continue
		if str(entity.get("entity_type", entity.get("entity_kind", ""))).strip_edges().to_lower() != "animal":
			continue

		var owner_id: int = int(entity.get("owner_person_id", -1))
		if owner_id <= 0:
			continue

		var rows: Array = _safe_array(out.get(owner_id, []))
		rows.append(entity.duplicate(true))
		out [owner_id] = rows

	return out

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

func _emit_diary_text(actor: Person, text: String, meta: Dictionary = {}) -> void:
	if gs == null or actor == null:
		return
	if gs.life_diary_contract_engine == null:
		return
	if not gs.life_diary_contract_engine.has_method("emit_diary_intent"):
		return

	gs.life_diary_contract_engine.emit_diary_intent({
		"type": "debt_contract",
		"actor_id": int(actor.id),
		"lines": str(text).split("\n"),
		"source": ENGINE_SCHEMA,
		"preserve_lines_exactly": true,
		"meta": meta.duplicate(true)
	}, {
		"source": ENGINE_SCHEMA
	})
func create_education_debt(
	actor: Person,
	amount: int,
	context: Dictionary = {}
) -> Dictionary:
	if (
		actor == null
		or amount <= 0
	):
		return {
			"success": false,
			"reason": "invalid_education_debt_request"
		}

	var debt_context: Dictionary = context.duplicate(
		true
	)
	debt_context [
		"reason"
	] = "education_financing"
	debt_context [
		"education_debt"
	] = true
	debt_context [
		"actor_id"
	] = int(
		actor.id
	)
	debt_context [
		"year"
	] = int(
		gs.year
		if gs != null
		else 0
	)

	return _add_debt(
		actor,
		amount,
		debt_context
	)
func _ensure_state() -> void:
	if gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	if typeof(gs.scenario_state.get(STATE_KEY, {})) != TYPE_DICTIONARY:
		gs.scenario_state [STATE_KEY] = {
			"schema": "eralife.debt_contract_engine_state",
			"version": CONTRACT_VERSION,
			"debts": [],
			"last_report": {}
		}

func _state() -> Dictionary:
	_ensure_state()
	return _safe_dictionary(gs.scenario_state.get(STATE_KEY, {})).duplicate(true)

func _set_state(state: Dictionary) -> void:
	if gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	gs.scenario_state [STATE_KEY] = state.duplicate(true)

func _commit_state() -> void:
	var state: Dictionary = _state()
	state ["last_report"] = last_report.duplicate(true)
	state ["updated_at_ms"] = int(Time.get_ticks_msec())
	_set_state(state)

func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)

func _safe_array(value: Variant) -> Array:
	return value if typeof(value) == TYPE_ARRAY else []