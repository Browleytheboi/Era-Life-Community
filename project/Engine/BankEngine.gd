extends Resource
class_name BankEngine

const CONTRACT_SCHEMA:= "eralife.bank_engine"
const CONTRACT_VERSION:= 1
const DEFAULT_WORLD_ID:= "local.world"
const DEFAULT_CURRENCY:= "USD"
const ACCOUNT_KIND_BANK:= "bank"
const ACCOUNT_KIND_INTERWORLD:= "interworld_credit"
const ACCOUNT_STATUS_OPEN:= "open"
const ACCOUNT_STATUS_FROZEN:= "frozen"
const ACCOUNT_STATUS_SANCTIONED:= "sanctioned"
const TRANSFER_SCOPE_LOCAL:= "local"
const TRANSFER_SCOPE_ERANET:= "eranet"
const LEDGER_LIMIT:= 500

var gs
var active_contract: Dictionary = {}
var accounts: Dictionary = {}
var cash_on_hand: Dictionary = {}
var owner_index: Dictionary = {}
var world_bank_policies: Dictionary = {}
var interworld_credit_routes: Dictionary = {}
var ledger: Array = []
var last_report: Dictionary = {}
var _tx_seq: int = 0

func _init(_gs = null):
	gs = _gs
	active_contract = _build_default_contract()

func reset_runtime() -> void:
	accounts.clear()
	cash_on_hand.clear()
	owner_index.clear()
	world_bank_policies.clear()
	interworld_credit_routes.clear()
	ledger.clear()
	last_report.clear()
	_tx_seq = 0

func set_contract(contract: Dictionary = {}) -> Dictionary:
	if typeof(contract) == TYPE_DICTIONARY and not contract.is_empty():
		active_contract = _merge_dict(_build_default_contract(), contract)
	else:
		active_contract = _build_default_contract()
	return {
		"schema": "eralife.bank_contract_set_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"contract_id": str(active_contract.get("id", "eralife_default_bank_contract")),
		"set_at_ms": int(Time.get_ticks_msec())
	}

func export_state() -> Dictionary:
	return _make_binary_safe({
		"schema": "eralife.bank_engine_state",
		"version": CONTRACT_VERSION,
		"active_contract": active_contract.duplicate(true),
		"accounts": accounts.duplicate(true),
		"cash_on_hand": cash_on_hand.duplicate(true),
		"owner_index": owner_index.duplicate(true),
		"world_bank_policies": world_bank_policies.duplicate(true),
		"interworld_credit_routes": interworld_credit_routes.duplicate(true),
		"ledger": ledger.duplicate(true),
		"last_report": last_report.duplicate(true),
		"tx_seq": _tx_seq,
		"exported_at_ms": int(Time.get_ticks_msec())
	})

func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return { "success": false, "reason": "BankEngine import data must be a Dictionary."}

	var contract_raw: Variant = data.get("active_contract", {})
	if typeof(contract_raw) == TYPE_DICTIONARY:
		active_contract = _merge_dict(_build_default_contract(), contract_raw as Dictionary)
	else:
		active_contract = _build_default_contract()

	var accounts_raw: Variant = data.get("accounts", {})
	accounts = accounts_raw.duplicate(true) if typeof(accounts_raw) == TYPE_DICTIONARY else {}

	var cash_raw: Variant = data.get("cash_on_hand", {})
	cash_on_hand = cash_raw.duplicate(true) if typeof(cash_raw) == TYPE_DICTIONARY else {}

	var index_raw: Variant = data.get("owner_index", {})
	owner_index = index_raw.duplicate(true) if typeof(index_raw) == TYPE_DICTIONARY else {}

	var policy_raw: Variant = data.get("world_bank_policies", {})
	world_bank_policies = policy_raw.duplicate(true) if typeof(policy_raw) == TYPE_DICTIONARY else {}

	var routes_raw: Variant = data.get("interworld_credit_routes", {})
	interworld_credit_routes = routes_raw.duplicate(true) if typeof(routes_raw) == TYPE_DICTIONARY else {}

	var ledger_raw: Variant = data.get("ledger", [])
	ledger = ledger_raw.duplicate(true) if typeof(ledger_raw) == TYPE_ARRAY else []
	_tx_seq = int(data.get("tx_seq", ledger.size()))

	_rebuild_owner_index()
	repair_legacy_player_money_mirror()

	last_report = {
		"schema": "eralife.bank_import_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"account_count": accounts.size(),
		"wallet_count": cash_on_hand.size(),
		"ledger_count": ledger.size(),
		"imported_at_ms": int(Time.get_ticks_msec())
	}
	return last_report.duplicate(true)

func repair_legacy_player_money_mirror() -> Dictionary:
	if gs == null or gs.player == null:
		return { "success": false, "reason": "No player to repair."}

	var actor = gs.player
	var context:= {
		"source": "legacy_bank_balance_repair",
		"world_id": _resolve_world_id({}),
		"currency": DEFAULT_CURRENCY
	}
	var account: Dictionary = ensure_bank_account_for_actor(actor, context)
	var account_id: String = str(account.get("account_id", ""))
	if account_id == "":
		return { "success": false, "reason": "Could not resolve player bank account."}

	if float(accounts [account_id].get("balance", 0.0)) <= 0.0 and actor.get("bank_balance") != null:
		var legacy_amount: float = max(0.0, float(actor.bank_balance))
		if legacy_amount > 0.0:
			accounts [account_id] ["balance"] = legacy_amount
			_record_ledger("legacy_money_imported", {
				"owner_id": str(account.get("owner_id", "")),
				"account_id": account_id,
				"amount": legacy_amount,
				"currency": str(account.get("currency", DEFAULT_CURRENCY)),
				"world_id": str(account.get("world_id", DEFAULT_WORLD_ID)),
				"source": "Person.bank_balance"
			})

	_sync_actor_money_mirror(actor)
	return get_owner_summary_for_actor(actor, context)

func ensure_bank_account_for_actor(actor, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {}
	var owner_id: String = owner_key_from_actor(actor)
	var world_id: String = _resolve_world_id(context)
	var currency: String = _resolve_currency(context)
	return ensure_account(owner_id, world_id, ACCOUNT_KIND_BANK, currency, {
		"actor_id": int(actor.id) if actor.get("id") != null else -1,
		"transfer_scope": TRANSFER_SCOPE_LOCAL
	})

func ensure_interworld_account_for_actor(actor, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {}
	var owner_id: String = owner_key_from_actor(actor)
	var world_id: String = _resolve_world_id(context)
	var currency: String = _resolve_currency(context)
	return ensure_account(owner_id, world_id, ACCOUNT_KIND_INTERWORLD, currency, {
		"actor_id": int(actor.id) if actor.get("id") != null else -1,
		"transfer_scope": TRANSFER_SCOPE_ERANET
	})

func ensure_account(owner_id: String, world_id: String = "", account_kind: String = ACCOUNT_KIND_BANK, currency: String = DEFAULT_CURRENCY, options: Dictionary = {}) -> Dictionary:
	var clean_owner: String = str(owner_id).strip_edges()
	if clean_owner == "":
		clean_owner = "owner:unknown"

	var clean_world: String = str(world_id).strip_edges()
	if clean_world == "":
		clean_world = DEFAULT_WORLD_ID

	var clean_kind: String = str(account_kind).strip_edges().to_lower()
	if clean_kind == "":
		clean_kind = ACCOUNT_KIND_BANK

	var clean_currency: String = str(currency).strip_edges().to_upper()
	if clean_currency == "":
		clean_currency = DEFAULT_CURRENCY

	var account_id: String = _account_id(clean_owner, clean_world, clean_kind, clean_currency)
	if not accounts.has(account_id):
		accounts [account_id] = {
			"schema": "eralife.money_account",
			"version": CONTRACT_VERSION,
			"account_id": account_id,
			"owner_id": clean_owner,
			"world_id": clean_world,
			"balance": max(0.0, float(options.get("starting_balance", 0.0))),
			"type": clean_kind,
			"currency": clean_currency,
			"transfer_scope": str(options.get("transfer_scope", TRANSFER_SCOPE_LOCAL)),
			"status": ACCOUNT_STATUS_OPEN,
			"flags": [],
			"actor_id": int(options.get("actor_id", -1)),
			"metadata": options.get("metadata", {}).duplicate(true) if typeof(options.get("metadata", {})) == TYPE_DICTIONARY else {},
			"created_at_ms": int(Time.get_ticks_msec()),
			"updated_at_ms": int(Time.get_ticks_msec())
		}
		_index_account(account_id, clean_owner)

	return accounts.get(account_id, {}).duplicate(true)

func get_owner_summary_for_actor(actor, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {}
	ensure_bank_account_for_actor(actor, context)
	ensure_interworld_account_for_actor(actor, context)
	return get_owner_summary(owner_key_from_actor(actor), context)

func get_owner_summary(owner_id: String, context: Dictionary = {}) -> Dictionary:
	var clean_owner: String = str(owner_id).strip_edges()
	if clean_owner == "":
		return {}

	var world_id: String = _resolve_world_id(context)
	var currency: String = _resolve_currency(context)
	var wallet: Dictionary = ensure_cash_wallet(clean_owner, world_id, currency, context)
	var bank_balance: float = 0.0
	var interworld_balance: float = 0.0
	var total_secured: float = 0.0

	for account_id in _accounts_for_owner(clean_owner):
		var account_raw: Variant = accounts.get(account_id, {})
		if typeof(account_raw) != TYPE_DICTIONARY:
			continue
		var account: Dictionary = account_raw
		if str(account.get("currency", currency)).to_upper() != currency:
			continue
		var balance: float = max(0.0, float(account.get("balance", 0.0)))
		if str(account.get("type", "")) == ACCOUNT_KIND_INTERWORLD:
			interworld_balance += balance
		else:
			bank_balance += balance
		total_secured += balance

	return {
		"schema": "eralife.money_owner_summary",
		"version": CONTRACT_VERSION,
		"owner_id": clean_owner,
		"world_id": world_id,
		"currency": currency,
		"cash_on_hand": max(0.0, float(wallet.get("amount", 0.0))),
		"bank_balance": bank_balance,
		"interworld_credit": interworld_balance,
		"secured_total": total_secured,
		"total_accessible": max(0.0, float(wallet.get("amount", 0.0))) + total_secured,
		"wallet_id": str(wallet.get("wallet_id", "")),
		"account_count": _accounts_for_owner(clean_owner).size(),
		"updated_at_ms": int(Time.get_ticks_msec())
	}

func ensure_cash_wallet(owner_id: String, world_id: String = "", currency: String = DEFAULT_CURRENCY, context: Dictionary = {}) -> Dictionary:
	var clean_owner: String = str(owner_id).strip_edges()
	if clean_owner == "":
		clean_owner = "owner:unknown"
	var clean_world: String = str(world_id).strip_edges()
	if clean_world == "":
		clean_world = _resolve_world_id(context)
	var clean_currency: String = str(currency).strip_edges().to_upper()
	if clean_currency == "":
		clean_currency = DEFAULT_CURRENCY
	var wallet_id: String = _wallet_id(clean_owner, clean_world, clean_currency)
	if not cash_on_hand.has(wallet_id):
		cash_on_hand [wallet_id] = {
			"schema": "eralife.cash_wallet",
			"version": CONTRACT_VERSION,
			"wallet_id": wallet_id,
			"owner_id": clean_owner,
			"world_id": clean_world,
			"currency": clean_currency,
			"amount": max(0.0, float(context.get("starting_cash", 0.0))),
			"risk_surface": "physical",
			"created_at_ms": int(Time.get_ticks_msec()),
			"updated_at_ms": int(Time.get_ticks_msec())
		}
	return cash_on_hand.get(wallet_id, {}).duplicate(true)

func deposit_for_player(actor, payload: Dictionary = {}) -> Dictionary:
	var merged: Dictionary = payload.duplicate(true)
	merged ["action"] = "deposit"
	return request_actor_bank_action(actor, merged, payload)

func withdraw_for_player(actor, payload: Dictionary = {}) -> Dictionary:
	var merged: Dictionary = payload.duplicate(true)
	merged ["action"] = "withdraw"
	return request_actor_bank_action(actor, merged, payload)

func request_actor_bank_action(actor, payload: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return { "success": false, "reason": "No actor supplied."}

	var merged_context: Dictionary = context.duplicate(true)
	merged_context ["actor_id"] = int(actor.id) if actor.get("id") != null else -1
	merged_context ["owner_id"] = owner_key_from_actor(actor)
	merged_context ["world_id"] = _resolve_world_id(context)
	return request_bank_action(payload, merged_context)

func request_bank_action(payload: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	var action: String = str(payload.get("action", payload.get("command", ""))).strip_edges().to_lower()
	var owner_id: String = str(payload.get("owner_id", context.get("owner_id", ""))).strip_edges()
	if owner_id == "":
		owner_id = _owner_key_from_context(context)
	if owner_id == "":
		return { "success": false, "reason": "Bank action missing owner_id."}

	var amount: float = _money_amount(payload.get("amount", payload.get("value", 0.0)))
	var world_id: String = _resolve_world_id(context)
	var currency: String = _resolve_currency(context)

	match action:
		"deposit", "deposit_money":
			return deposit(owner_id, amount, world_id, currency, context)
		"deposit_all", "deposit_all_cash":
			var wallet: Dictionary = ensure_cash_wallet(owner_id, world_id, currency, context)
			return deposit(owner_id, float(wallet.get("amount", 0.0)), world_id, currency, context)
		"withdraw", "withdraw_money":
			return withdraw(owner_id, amount, world_id, currency, context)
		"credit_cash", "crime_payout_cash":
			return credit_cash(owner_id, amount, world_id, currency, payload, context)
		"transfer", "transfer_money":
			return transfer_owner_to_owner(owner_id, str(payload.get("target_owner_id", "")), amount, world_id, currency, payload, context)
		"steal_cash", "rob_cash":
			return steal_cash(str(payload.get("thief_owner_id", owner_id)), str(payload.get("victim_owner_id", "")), amount, world_id, currency, payload, context)
		"apply_justice_penalty", "justice_fine", "justice_restitution", "asset_seizure":
			return apply_justice_penalty(owner_id, amount, world_id, currency, payload, context)
		"freeze_owner_accounts":
			return freeze_owner_accounts(owner_id, payload, context)
		"freeze_account":
			return set_account_status(str(payload.get("account_id", "")), ACCOUNT_STATUS_FROZEN, payload, context)
		"unfreeze_account":
			return set_account_status(str(payload.get("account_id", "")), ACCOUNT_STATUS_OPEN, payload, context)
		"summary", "status", "balance":
			return { "success": true, "summary": get_owner_summary(owner_id, context)}
		_:
			return { "success": false, "reason": "Unsupported bank action '%s'." % action}

func route_command_envelope(envelope: Dictionary) -> Dictionary:
	if typeof(envelope) != TYPE_DICTIONARY:
		return { "success": false, "reason": "Bank command envelope must be a Dictionary."}
	var payload_raw: Variant = envelope.get("payload", envelope.get("args", {}))
	var payload: Dictionary = payload_raw.duplicate(true) if typeof(payload_raw) == TYPE_DICTIONARY else {}
	var context_raw: Variant = envelope.get("context", {})
	var context: Dictionary = context_raw.duplicate(true) if typeof(context_raw) == TYPE_DICTIONARY else {}
	context ["source"] = str(envelope.get("source", context.get("source", "command_envelope")))
	context ["world_id"] = str(context.get("world_id", envelope.get("world_container_id", envelope.get("guild_id", ""))))
	if str(context.get("owner_id", "")).strip_edges() == "":
		context ["owner_id"] = _owner_key_from_context(envelope)
	if str(payload.get("action", "")).strip_edges() == "":
		payload ["action"] = _bank_action_from_command(str(envelope.get("command", envelope.get("action_id", ""))))
	return request_bank_action(payload, context)

func deposit(owner_id: String, amount: float, world_id: String = "", currency: String = DEFAULT_CURRENCY, context: Dictionary = {}) -> Dictionary:
	amount = _money_amount(amount)
	if amount <= 0.0:
		return { "success": false, "reason": "Deposit amount must be positive."}

	var clean_owner: String = str(owner_id).strip_edges()
	var clean_world: String = _resolve_world_id({ "world_id": world_id})
	var clean_currency: String = str(currency).strip_edges().to_upper()
	var wallet: Dictionary = ensure_cash_wallet(clean_owner, clean_world, clean_currency, context)
	var wallet_id: String = str(wallet.get("wallet_id", ""))
	var available_cash: float = max(0.0, float(wallet.get("amount", 0.0)))
	if amount > available_cash:
		return { "success": false, "reason": "Not enough cash on hand.", "available_cash": available_cash}

	var account: Dictionary = ensure_account(clean_owner, clean_world, ACCOUNT_KIND_BANK, clean_currency, { "transfer_scope": TRANSFER_SCOPE_LOCAL})
	var account_id: String = str(account.get("account_id", ""))
	var gate: Dictionary = _can_credit_or_debit(account_id, amount, "credit", context)
	if not bool(gate.get("allowed", true)):
		return { "success": false, "reason": str(gate.get("reason", "Deposit blocked.")), "gate": gate}

	cash_on_hand [wallet_id] ["amount"] = max(0.0, available_cash - amount)
	cash_on_hand [wallet_id] ["updated_at_ms"] = int(Time.get_ticks_msec())
	accounts [account_id] ["balance"] = max(0.0, float(accounts [account_id].get("balance", 0.0)) + amount)
	accounts [account_id] ["updated_at_ms"] = int(Time.get_ticks_msec())
	_sync_actor_by_owner(clean_owner)

	var report: Dictionary = _finish_money_action("money_deposited", clean_owner, amount, clean_world, clean_currency, {
		"account_id": account_id,
		"wallet_id": wallet_id,
		"text": "Money moved from physical cash into the bank."
	})
	last_report = report.duplicate(true)
	return report

func withdraw(owner_id: String, amount: float, world_id: String = "", currency: String = DEFAULT_CURRENCY, context: Dictionary = {}) -> Dictionary:
	amount = _money_amount(amount)
	if amount <= 0.0:
		return { "success": false, "reason": "Withdrawal amount must be positive."}

	var clean_owner: String = str(owner_id).strip_edges()
	var clean_world: String = _resolve_world_id({ "world_id": world_id})
	var clean_currency: String = str(currency).strip_edges().to_upper()
	var account: Dictionary = ensure_account(clean_owner, clean_world, ACCOUNT_KIND_BANK, clean_currency, { "transfer_scope": TRANSFER_SCOPE_LOCAL})
	var account_id: String = str(account.get("account_id", ""))
	var balance: float = max(0.0, float(accounts [account_id].get("balance", 0.0)))
	if amount > balance:
		return { "success": false, "reason": "Not enough money in the bank.", "bank_balance": balance}
	var gate: Dictionary = _can_credit_or_debit(account_id, amount, "debit", context)
	if not bool(gate.get("allowed", true)):
		return { "success": false, "reason": str(gate.get("reason", "Withdrawal blocked.")), "gate": gate}

	var wallet: Dictionary = ensure_cash_wallet(clean_owner, clean_world, clean_currency, context)
	var wallet_id: String = str(wallet.get("wallet_id", ""))
	accounts [account_id] ["balance"] = max(0.0, balance - amount)
	accounts [account_id] ["updated_at_ms"] = int(Time.get_ticks_msec())
	cash_on_hand [wallet_id] ["amount"] = max(0.0, float(cash_on_hand [wallet_id].get("amount", 0.0)) + amount)
	cash_on_hand [wallet_id] ["updated_at_ms"] = int(Time.get_ticks_msec())
	_sync_actor_by_owner(clean_owner)

	var report: Dictionary = _finish_money_action("money_withdrawn", clean_owner, amount, clean_world, clean_currency, {
		"account_id": account_id,
		"wallet_id": wallet_id,
		"text": "Money moved from the bank into physical cash."
	})
	last_report = report.duplicate(true)
	return report
func credit_cash(owner_id: String, amount: float, world_id: String = "", currency: String = DEFAULT_CURRENCY, payload: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	amount = _money_amount(amount)
	if amount <= 0.0:
		return { "success": false, "reason": "Cash credit amount must be positive."}

	var clean_owner: String = str(owner_id).strip_edges()
	var clean_world: String = _resolve_world_id({ "world_id": world_id})
	var clean_currency: String = str(currency).strip_edges().to_upper()
	var wallet: Dictionary = ensure_cash_wallet(clean_owner, clean_world, clean_currency, context)
	var wallet_id: String = str(wallet.get("wallet_id", ""))

	cash_on_hand [wallet_id] ["amount"] = max(0.0, float(cash_on_hand [wallet_id].get("amount", 0.0)) + amount)
	cash_on_hand [wallet_id] ["updated_at_ms"] = int(Time.get_ticks_msec())
	_sync_actor_by_owner(clean_owner)

	var report: Dictionary = _finish_money_action("cash_credited", clean_owner, amount, clean_world, clean_currency, {
		"wallet_id": wallet_id,
		"case_id": str(payload.get("case_id", context.get("case_id", ""))),
		"source": str(context.get("source", payload.get("source", "bank_engine"))),
		"text": str(payload.get("text", "Physical cash was added to a wallet."))
	})
	last_report = report.duplicate(true)
	return report

func apply_justice_penalty(owner_id: String, amount: float, world_id: String = "", currency: String = DEFAULT_CURRENCY, payload: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	amount = _money_amount(amount)
	if amount <= 0.0:
		return { "success": true, "skipped": true, "reason": "No justice penalty amount."}

	var clean_owner: String = str(owner_id).strip_edges()
	var clean_world: String = _resolve_world_id({ "world_id": world_id})
	var clean_currency: String = str(currency).strip_edges().to_upper()
	var remaining: float = amount
	var paid: float = 0.0
	var debits: Array = []

	for account_id in _accounts_for_owner(clean_owner):
		if remaining <= 0.0:
			break
		var account_raw: Variant = accounts.get(account_id, {})
		if typeof(account_raw) != TYPE_DICTIONARY:
			continue
		var account: Dictionary = account_raw
		if str(account.get("currency", clean_currency)).to_upper() != clean_currency:
			continue

		var balance: float = max(0.0, float(account.get("balance", 0.0)))
		if balance <= 0.0:
			continue

		var debit: float = min(balance, remaining)
		accounts [account_id] ["balance"] = max(0.0, balance - debit)
		accounts [account_id] ["updated_at_ms"] = int(Time.get_ticks_msec())
		remaining -= debit
		paid += debit
		debits.append({
			"source": "bank_account",
			"account_id": account_id,
			"amount": debit
		})

	if remaining > 0.0:
		var wallet: Dictionary = ensure_cash_wallet(clean_owner, clean_world, clean_currency, context)
		var wallet_id: String = str(wallet.get("wallet_id", ""))
		var cash_available: float = max(0.0, float(cash_on_hand [wallet_id].get("amount", 0.0)))
		var cash_debit: float = min(cash_available, remaining)

		if cash_debit > 0.0:
			cash_on_hand [wallet_id] ["amount"] = max(0.0, cash_available - cash_debit)
			cash_on_hand [wallet_id] ["updated_at_ms"] = int(Time.get_ticks_msec())
			remaining -= cash_debit
			paid += cash_debit
			debits.append({
				"source": "cash_wallet",
				"wallet_id": wallet_id,
				"amount": cash_debit
			})

	var target_owner_id: String = str(payload.get("target_owner_id", "")).strip_edges()
	if target_owner_id != "" and paid > 0.0:
		var target_account: Dictionary = ensure_account(target_owner_id, clean_world, ACCOUNT_KIND_BANK, clean_currency, {
			"transfer_scope": TRANSFER_SCOPE_LOCAL
		})
		var target_account_id: String = str(target_account.get("account_id", ""))
		accounts [target_account_id] ["balance"] = max(0.0, float(accounts [target_account_id].get("balance", 0.0)) + paid)
		accounts [target_account_id] ["updated_at_ms"] = int(Time.get_ticks_msec())
		_sync_actor_by_owner(target_owner_id)

	_sync_actor_by_owner(clean_owner)

	var report: Dictionary = _finish_money_action("justice_economic_penalty", clean_owner, paid, clean_world, clean_currency, {
		"case_id": str(payload.get("case_id", context.get("case_id", ""))),
		"penalty_type": str(payload.get("penalty_type", "justice_penalty")),
		"requested_amount": amount,
		"paid_amount": paid,
		"unpaid_amount": max(0.0, remaining),
		"debits": debits.duplicate(true),
		"target_owner_id": target_owner_id,
		"text": "A court-ordered financial penalty was applied through BankEngine."
	})
	report ["requested_amount"] = amount
	report ["paid_amount"] = paid
	report ["unpaid_amount"] = max(0.0, remaining)
	last_report = report.duplicate(true)
	return report

func freeze_owner_accounts(owner_id: String, payload: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	var clean_owner: String = str(owner_id).strip_edges()
	if clean_owner == "":
		return { "success": false, "reason": "freeze_owner_accounts needs owner_id."}

	var frozen: Array = []
	for account_id in _accounts_for_owner(clean_owner):
		if not accounts.has(account_id):
			continue
		accounts [account_id] ["status"] = ACCOUNT_STATUS_FROZEN
		accounts [account_id] ["status_reason"] = str(payload.get("reason", context.get("reason", "justice_freeze")))
		accounts [account_id] ["updated_at_ms"] = int(Time.get_ticks_msec())
		frozen.append(account_id)

	var report: Dictionary = _finish_money_action("owner_accounts_frozen", clean_owner, 0.0, _resolve_world_id(context), _resolve_currency(context), {
		"frozen_accounts": frozen.duplicate(true),
		"case_id": str(payload.get("case_id", context.get("case_id", ""))),
		"text": "Court authority froze this owner's BankEngine accounts."
	})
	report ["frozen_accounts"] = frozen.duplicate(true)
	last_report = report.duplicate(true)
	return report
func transfer_owner_to_owner(from_owner_id: String, to_owner_id: String, amount: float, world_id: String = "", currency: String = DEFAULT_CURRENCY, payload: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	amount = _money_amount(amount)
	var clean_from: String = str(from_owner_id).strip_edges()
	var clean_to: String = str(to_owner_id).strip_edges()
	if clean_from == "" or clean_to == "":
		return { "success": false, "reason": "Transfer needs both from_owner_id and target_owner_id."}
	if clean_from == clean_to:
		return { "success": false, "reason": "Cannot transfer money to the same owner."}
	if amount <= 0.0:
		return { "success": false, "reason": "Transfer amount must be positive."}

	var clean_world: String = _resolve_world_id({ "world_id": world_id})
	var clean_currency: String = str(currency).strip_edges().to_upper()
	var scope: String = str(payload.get("transfer_scope", context.get("transfer_scope", TRANSFER_SCOPE_LOCAL))).strip_edges().to_lower()
	var account_kind: String = ACCOUNT_KIND_INTERWORLD if scope == TRANSFER_SCOPE_ERANET else ACCOUNT_KIND_BANK
	var from_account: Dictionary = ensure_account(clean_from, clean_world, account_kind, clean_currency, { "transfer_scope": scope})
	var to_world: String = str(payload.get("target_world_id", clean_world)).strip_edges()
	if to_world == "":
		to_world = clean_world
	var to_account: Dictionary = ensure_account(clean_to, to_world, account_kind, clean_currency, { "transfer_scope": scope})
	var from_account_id: String = str(from_account.get("account_id", ""))
	var to_account_id: String = str(to_account.get("account_id", ""))

	if scope == TRANSFER_SCOPE_ERANET and not _interworld_allowed(clean_world, to_world, payload, context):
		return { "success": false, "reason": "InterWorld transfer blocked by bank contract policy."}

	var balance: float = max(0.0, float(accounts [from_account_id].get("balance", 0.0)))
	if amount > balance:
		return { "success": false, "reason": "Not enough secured funds for transfer.", "bank_balance": balance}
	var gate: Dictionary = _can_credit_or_debit(from_account_id, amount, "debit", context)
	if not bool(gate.get("allowed", true)):
		return { "success": false, "reason": str(gate.get("reason", "Transfer blocked.")), "gate": gate}

	accounts [from_account_id] ["balance"] = max(0.0, balance - amount)
	accounts [from_account_id] ["updated_at_ms"] = int(Time.get_ticks_msec())
	accounts [to_account_id] ["balance"] = max(0.0, float(accounts [to_account_id].get("balance", 0.0)) + amount)
	accounts [to_account_id] ["updated_at_ms"] = int(Time.get_ticks_msec())
	_sync_actor_by_owner(clean_from)
	_sync_actor_by_owner(clean_to)

	var report: Dictionary = _finish_money_action("money_transferred", clean_from, amount, clean_world, clean_currency, {
		"from_account_id": from_account_id,
		"to_account_id": to_account_id,
		"target_owner_id": clean_to,
		"target_world_id": to_world,
		"transfer_scope": scope,
		"text": "Money moved through the Bank Engine."
	})
	last_report = report.duplicate(true)
	return report

func steal_cash(thief_owner_id: String, victim_owner_id: String, amount: float, world_id: String = "", currency: String = DEFAULT_CURRENCY, payload: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	amount = _money_amount(amount)
	var thief: String = str(thief_owner_id).strip_edges()
	var victim: String = str(victim_owner_id).strip_edges()
	if thief == "" or victim == "":
		return { "success": false, "reason": "Cash theft needs thief_owner_id and victim_owner_id."}
	if amount <= 0.0:
		return { "success": false, "reason": "Theft amount must be positive."}

	var clean_world: String = _resolve_world_id({ "world_id": world_id})
	var clean_currency: String = str(currency).strip_edges().to_upper()
	var gate: Dictionary = _can_steal_cash(thief, victim, amount, clean_world, payload, context)
	if not bool(gate.get("allowed", false)):
		return { "success": false, "reason": str(gate.get("reason", "Cash theft blocked.")), "gate": gate}

	var victim_wallet: Dictionary = ensure_cash_wallet(victim, clean_world, clean_currency, context)
	var victim_wallet_id: String = str(victim_wallet.get("wallet_id", ""))
	var victim_cash: float = max(0.0, float(cash_on_hand [victim_wallet_id].get("amount", 0.0)))
	var resolved_amount: float = min(amount, victim_cash)
	if resolved_amount <= 0.0:
		return { "success": false, "reason": "Victim has no cash on hand.", "victim_cash": victim_cash}

	var thief_wallet: Dictionary = ensure_cash_wallet(thief, clean_world, clean_currency, context)
	var thief_wallet_id: String = str(thief_wallet.get("wallet_id", ""))
	cash_on_hand [victim_wallet_id] ["amount"] = max(0.0, victim_cash - resolved_amount)
	cash_on_hand [victim_wallet_id] ["updated_at_ms"] = int(Time.get_ticks_msec())
	cash_on_hand [thief_wallet_id] ["amount"] = max(0.0, float(cash_on_hand [thief_wallet_id].get("amount", 0.0)) + resolved_amount)
	cash_on_hand [thief_wallet_id] ["updated_at_ms"] = int(Time.get_ticks_msec())

	var report: Dictionary = _finish_money_action("cash_stolen", thief, resolved_amount, clean_world, clean_currency, {
		"victim_owner_id": victim,
		"thief_wallet_id": thief_wallet_id,
		"victim_wallet_id": victim_wallet_id,
		"governed": true,
		"text": "Physical cash changed hands. Bank funds were not touched."
	})
	last_report = report.duplicate(true)
	return report

func set_account_status(account_id: String, status: String, payload: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	var clean_account_id: String = str(account_id).strip_edges()
	if clean_account_id == "" or not accounts.has(clean_account_id):
		return { "success": false, "reason": "Unknown account_id."}
	var clean_status: String = str(status).strip_edges().to_lower()
	if clean_status == "":
		clean_status = ACCOUNT_STATUS_OPEN
	accounts [clean_account_id] ["status"] = clean_status
	accounts [clean_account_id] ["status_reason"] = str(payload.get("reason", context.get("reason", ""))).strip_edges()
	accounts [clean_account_id] ["updated_at_ms"] = int(Time.get_ticks_msec())
	var report: Dictionary = _finish_money_action("account_status_changed", str(accounts [clean_account_id].get("owner_id", "")), 0.0, str(accounts [clean_account_id].get("world_id", DEFAULT_WORLD_ID)), str(accounts [clean_account_id].get("currency", DEFAULT_CURRENCY)), {
		"account_id": clean_account_id,
		"status": clean_status,
		"text": "A Bank Engine account status changed."
	})
	last_report = report.duplicate(true)
	return report

func get_player_bank_rows(context: Dictionary = {}) -> Array:
	if gs == null or gs.player == null:
		return []
	repair_legacy_player_money_mirror()
	var summary: Dictionary = get_owner_summary_for_actor(gs.player, context)
	return [
		{
			"label": "💵 Cash on hand: %s — physical, risky, stealable, droppable." % _format_money(float(summary.get("cash_on_hand", 0.0)), str(summary.get("currency", DEFAULT_CURRENCY))),
			"kind": "cash",
			"value": float(summary.get("cash_on_hand", 0.0))
		},
		{
			"label": "🏦 Bank balance: %s — secured money for rent, businesses, contracts, lawsuits, investments, and big purchases." % _format_money(float(summary.get("bank_balance", 0.0)), str(summary.get("currency", DEFAULT_CURRENCY))),
			"kind": "bank",
			"value": float(summary.get("bank_balance", 0.0))
		},
		{
			"label": "🌐 InterWorld Credit: %s — cross-server / cross-realm credit, only if policy allows it." % _format_money(float(summary.get("interworld_credit", 0.0)), str(summary.get("currency", DEFAULT_CURRENCY))),
			"kind": "interworld_credit",
			"value": float(summary.get("interworld_credit", 0.0))
		},
		{
			"label": "🧾 Total accessible money: %s" % _format_money(float(summary.get("total_accessible", 0.0)), str(summary.get("currency", DEFAULT_CURRENCY))),
			"kind": "summary",
			"value": float(summary.get("total_accessible", 0.0))
		}
	]

func get_player_cash_rows(context: Dictionary = {}) -> Array:
	if gs == null or gs.player == null:
		return []
	repair_legacy_player_money_mirror()
	var owner_id: String = owner_key_from_actor(gs.player)
	var world_id: String = _resolve_world_id(context)
	var currency: String = _resolve_currency(context)
	var wallet: Dictionary = ensure_cash_wallet(owner_id, world_id, currency, context)
	return [
		{
			"label": "Cash wallet: %s in %s. This can be robbed, dropped, seized, or lost in events." % [_format_money(float(wallet.get("amount", 0.0)), currency), world_id],
			"wallet_id": str(wallet.get("wallet_id", "")),
			"kind": "cash_wallet"
		}
	]

func get_player_account_rows(_context: Dictionary = {}) -> Array:
	if gs == null or gs.player == null:
		return []
	repair_legacy_player_money_mirror()
	var owner_id: String = owner_key_from_actor(gs.player)
	var out: Array = []
	for account_id in _accounts_for_owner(owner_id):
		var account_raw: Variant = accounts.get(account_id, {})
		if typeof(account_raw) != TYPE_DICTIONARY:
			continue
		var account: Dictionary = account_raw
		out.append({
			"label": "%s %s • %s • %s • %s" % [
				"🌐" if str(account.get("type", "")) == ACCOUNT_KIND_INTERWORLD else "🏦",
				str(account.get("type", "bank")).capitalize(),
				_format_money(float(account.get("balance", 0.0)), str(account.get("currency", DEFAULT_CURRENCY))),
				str(account.get("world_id", DEFAULT_WORLD_ID)),
				str(account.get("status", ACCOUNT_STATUS_OPEN))
			],
			"account_id": account_id,
			"kind": str(account.get("type", ACCOUNT_KIND_BANK))
		})
	return out

func get_risk_rows(_context: Dictionary = {}) -> Array:
	return [
		{ "label": "Cash can be stolen, robbed, dropped, seized, burned by disaster, or lost in world events."},
		{ "label": "Bank money is safer but can be frozen by courts, sanctions, fraud investigations, bankruptcy, war collapse, or bank failure."},
		{ "label": "InterWorld Credit can cross Discord worlds / realms only when era, route, and policy gates allow it."},
		{ "label": "Legacy Person.bank_balance is now a mirror. BankEngine owns the truth."}
	]

func _finish_money_action(event_name: String, owner_id: String, amount: float, world_id: String, currency: String, extra: Dictionary = {}) -> Dictionary:
	var tx: Dictionary = _record_ledger(event_name, {
		"owner_id": owner_id,
		"amount": amount,
		"world_id": world_id,
		"currency": currency,
		"extra": extra.duplicate(true)
	})
	var text: String = str(extra.get("text", event_name)).strip_edges()
	if gs != null and gs.event_bus != null and gs.event_bus.has_method("emit"):
		gs.event_bus.emit(event_name, {
			"source": "bank_engine",
			"owner_id": owner_id,
			"amount": amount,
			"world_id": world_id,
			"currency": currency,
			"transaction": tx.duplicate(true),
			"text": text,
			"qos_tier": "important"
		})
	if gs != null and gs.has_method("push_world_feed") and amount > 0.0:
		gs.push_world_feed(text, {
			"category": "money",
			"event_name": event_name,
			"source": "bank_engine",
			"owner_id": owner_id,
			"amount": amount,
			"currency": currency,
			"world_id": world_id
		})
	return {
		"schema": "eralife.bank_action_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"event_name": event_name,
		"owner_id": owner_id,
		"amount": amount,
		"world_id": world_id,
		"currency": currency,
		"transaction": tx.duplicate(true),
		"summary": get_owner_summary(owner_id, { "world_id": world_id, "currency": currency}),
		"completed_at_ms": int(Time.get_ticks_msec())
	}

func _record_ledger(event_name: String, data: Dictionary = {}) -> Dictionary:
	_tx_seq += 1
	var tx:= {
		"schema": "eralife.money_transaction",
		"version": CONTRACT_VERSION,
		"tx_id": "tx_%d" % _tx_seq,
		"event_name": event_name,
		"data": data.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec()),
		"year": int(gs.year) if gs != null and gs.get("year") != null else 0
	}
	ledger.append(tx)
	if ledger.size() > LEDGER_LIMIT:
		ledger = ledger.slice(ledger.size() - LEDGER_LIMIT, ledger.size())
	return tx

func owner_key_from_actor(actor) -> String:
	if actor == null:
		return ""
	if actor.get("id") != null:
		return "person:%d" % int(actor.id)
	return "person:unknown"

func _owner_key_from_context(context: Dictionary = {}) -> String:
	var direct: String = str(context.get("owner_id", "")).strip_edges()
	if direct != "":
		return direct
	var player_id: int = int(context.get("player_id", context.get("actor_id", -1)))
	if player_id > 0:
		return "person:%d" % player_id
	var user_id: String = str(context.get("user_id", context.get("external_user_id", ""))).strip_edges()
	var guild_id: String = str(context.get("guild_id", context.get("world_container_id", ""))).strip_edges()
	if user_id != "" and guild_id != "":
		return "discord:%s:%s" % [_safe_id(guild_id), _safe_id(user_id)]
	var life_node_id: String = str(context.get("life_node_id", "")).strip_edges()
	if life_node_id != "":
		return "life:%s" % _safe_id(life_node_id)
	if gs != null and gs.player != null:
		return owner_key_from_actor(gs.player)
	return ""
func settle_obligation_for_actor(
	actor,
	amount: float,
	payload: Dictionary = {},
	context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "No actor supplied."
		}

	var merged_context: Dictionary = context.duplicate(
		true
	)
	merged_context ["actor_id"] = (
		int(actor.id)
		if actor.get("id") != null
		else -1
	)
	merged_context [
		"owner_id"
	] = owner_key_from_actor(
		actor
	)
	merged_context [
		"world_id"
	] = _resolve_world_id(
		context
	)

	var account: Dictionary = ensure_bank_account_for_actor(
		actor,
		merged_context
	)
	var account_id: String = str(
		account.get(
			"account_id",
			""
		)
	)

	if account_id == "":
		return {
			"success": false,
			"reason": "Could not resolve the actor's bank account."
		}



	if (
		float(
			accounts [
				account_id
			].get(
				"balance",
				0.0
			)
		) <= 0.0
		and actor.get(
			"bank_balance"
		) != null
	):
		var legacy_amount: float = max(
			0.0,
			float(
				actor.bank_balance
			)
		)

		if legacy_amount > 0.0:
			accounts [
				account_id
			] ["balance"] = legacy_amount
			accounts [
				account_id
			] ["updated_at_ms"] = int(
				Time.get_ticks_msec()
			)

			_record_ledger(
				"legacy_money_imported",
				{
					"owner_id": owner_key_from_actor(
						actor
					),
					"account_id": account_id,
					"amount": legacy_amount,
					"currency": str(
						account.get(
							"currency",
							DEFAULT_CURRENCY
						)
					),
					"world_id": str(
						account.get(
							"world_id",
							DEFAULT_WORLD_ID
						)
					),
					"source": "Person.bank_balance"
				}
			)

	return settle_obligation(
		owner_key_from_actor(
			actor
		),
		amount,
		str(
			account.get(
				"world_id",
				_resolve_world_id(
					context
				)
			)
		),
		str(
			account.get(
				"currency",
				_resolve_currency(
					context
				)
			)
		),
		payload,
		merged_context
	)


func settle_obligation(
	owner_id: String,
	amount: float,
	world_id: String = "",
	currency: String = DEFAULT_CURRENCY,
	payload: Dictionary = {},
	context: Dictionary = {}
) -> Dictionary:
	amount = _money_amount(
		amount
	)

	if amount <= 0.0:
		return {
			"success": true,
			"skipped": true,
			"amount": 0.0,
			"reason": "No obligation amount."
		}

	var clean_owner: String = str(
		owner_id
	).strip_edges()

	if clean_owner == "":
		return {
			"success": false,
			"reason": "Obligation is missing an owner."
		}

	var resolution_context: Dictionary = context.duplicate(
		true
	)

	if str(world_id).strip_edges() != "":
		resolution_context [
			"world_id"
		] = world_id

	var clean_world: String = _resolve_world_id(
		resolution_context
	)
	var clean_currency: String = str(
		currency
	).strip_edges().to_upper()

	if clean_currency == "":
		clean_currency = _resolve_currency(
			resolution_context
		)

	var account: Dictionary = ensure_account(
		clean_owner,
		clean_world,
		ACCOUNT_KIND_BANK,
		clean_currency,
		{
			"transfer_scope": TRANSFER_SCOPE_LOCAL
		}
	)
	var account_id: String = str(
		account.get(
			"account_id",
			""
		)
	)

	if account_id == "":
		return {
			"success": false,
			"reason": "No bank account could settle the obligation."
		}

	var balance: float = max(
		0.0,
		float(
			accounts [
				account_id
			].get(
				"balance",
				0.0
			)
		)
	)

	if amount > balance:
		return {
			"success": false,
			"reason": "Not enough money in the bank.",
			"bank_balance": balance,
			"required_amount": amount
		}

	var gate: Dictionary = _can_credit_or_debit(
		account_id,
		amount,
		"debit",
		resolution_context
	)

	if not bool(
		gate.get(
			"allowed",
			true
		)
	):
		return {
			"success": false,
			"reason": str(
				gate.get(
					"reason",
					"Payment blocked."
				)
			),
			"gate": gate
		}

	accounts [
		account_id
	] ["balance"] = max(
		0.0,
		balance - amount
	)
	accounts [
		account_id
	] ["updated_at_ms"] = int(
		Time.get_ticks_msec()
	)

	_sync_actor_by_owner(
		clean_owner
	)

	var report: Dictionary = _finish_money_action(
		"money_obligation_settled",
		clean_owner,
		amount,
		clean_world,
		clean_currency,
		{
			"account_id": account_id,
			"reason": str(
				payload.get(
					"reason",
					context.get(
						"reason",
						"obligation"
					)
				)
			),
			"program_id": str(
				payload.get(
					"program_id",
					""
				)
			),
			"text": str(
				payload.get(
					"text",
					"An obligation was paid from the bank."
				)
			)
		}
	)

	last_report = report.duplicate(
		true
	)

	return report
func _resolve_world_id(context: Dictionary = {}) -> String:
	var clean: String = str(context.get("world_id", context.get("world_container_id", context.get("guild_id", "")))).strip_edges()
	if clean != "":
		return clean
	if gs != null and gs.player != null and gs.player.get("realm_id") != null and int(gs.player.realm_id) >= 0:
		return "realm:%d" % int(gs.player.realm_id)
	return DEFAULT_WORLD_ID

func _resolve_currency(context: Dictionary = {}) -> String:
	var clean: String = str(context.get("currency", DEFAULT_CURRENCY)).strip_edges().to_upper()
	if clean == "":
		clean = DEFAULT_CURRENCY
	return clean

func _bank_action_from_command(command_id: String) -> String:
	var clean: String = str(command_id).strip_edges().to_lower()
	match clean:
		"bank.deposit", "deposit_money":
			return "deposit"
		"bank.withdraw", "withdraw_money":
			return "withdraw"
		"bank.credit_cash", "bank.crime_payout_cash":
			return "credit_cash"
		"bank.transfer", "transfer_money":
			return "transfer"
		"bank.status", "bank.balance", "bank.summary":
			return "summary"
		"bank.steal_cash", "bank.rob_cash":
			return "steal_cash"
		"bank.apply_justice_penalty", "bank.justice_fine", "bank.justice_restitution", "bank.asset_seizure":
			return "apply_justice_penalty"
		"bank.freeze_owner_accounts":
			return "freeze_owner_accounts"
		_:
			return clean.replace("bank.", "")

func _account_id(owner_id: String, world_id: String, account_kind: String, currency: String) -> String:
	return "acct.%s.%s.%s.%s" % [_safe_id(owner_id), _safe_id(world_id), _safe_id(account_kind), _safe_id(currency)]

func _wallet_id(owner_id: String, world_id: String, currency: String) -> String:
	return "cash.%s.%s.%s" % [_safe_id(owner_id), _safe_id(world_id), _safe_id(currency)]

func _safe_id(value: Variant) -> String:
	var out: String = str(value).strip_edges().to_lower()
	out = out.replace(" ", "_")
	out = out.replace(":", "_")
	out = out.replace("/", "_")
	out = out.replace(".", "_")
	out = out.replace("-", "_")
	if out == "":
		out = "unknown"
	return out

func _money_amount(value: Variant) -> float:
	var amount: float = float(value)
	if amount < 0.0:
		amount = 0.0
	return amount

func _can_credit_or_debit(account_id: String, amount: float, direction: String, _context: Dictionary = {}) -> Dictionary:
	if not accounts.has(account_id):
		return { "allowed": false, "reason": "Account does not exist."}
	var account: Dictionary = accounts.get(account_id, {})
	var status: String = str(account.get("status", ACCOUNT_STATUS_OPEN)).strip_edges().to_lower()
	if status in [ACCOUNT_STATUS_FROZEN, ACCOUNT_STATUS_SANCTIONED]:
		return { "allowed": false, "reason": "Account is %s." % status, "status": status}
	return { "allowed": true, "amount": amount, "direction": direction}

func _can_steal_cash(_thief_owner_id: String, victim_owner_id: String, amount: float, world_id: String, payload: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	var permissions_raw: Variant = active_contract.get("permissions", {})
	var permissions: Dictionary = permissions_raw if typeof(permissions_raw) == TYPE_DICTIONARY else {}
	if not bool(permissions.get("allow_cash_theft", true)):
		return { "allowed": false, "reason": "Cash theft disabled by bank contract."}
	if bool(permissions.get("require_governed_theft", true)) and not bool(payload.get("governed", context.get("governed", false))):
		return { "allowed": false, "reason": "Cash theft must be routed by a governed crime/event/system."}
	var wallet: Dictionary = ensure_cash_wallet(victim_owner_id, world_id, _resolve_currency(context), context)
	var victim_cash: float = max(0.0, float(wallet.get("amount", 0.0)))
	var max_percent: float = clamp(float(permissions.get("max_cash_theft_percent", 0.35)), 0.0, 1.0)
	var max_allowed: float = max(1.0, floor(victim_cash * max_percent))
	if amount > max_allowed:
		return { "allowed": false, "reason": "Requested theft exceeds governed theft limit.", "max_allowed": max_allowed, "victim_cash": victim_cash}
	return { "allowed": true, "max_allowed": max_allowed, "victim_cash": victim_cash}

func _interworld_allowed(_from_world_id: String, _to_world_id: String, payload: Dictionary = {}, context: Dictionary = {}) -> bool:
	var permissions_raw: Variant = active_contract.get("permissions", {})
	var permissions: Dictionary = permissions_raw if typeof(permissions_raw) == TYPE_DICTIONARY else {}
	if not bool(permissions.get("allow_interworld_credit", true)):
		return false
	var from_era: String = str(payload.get("from_era", context.get("from_era", ""))).strip_edges().to_lower()
	var to_era: String = str(payload.get("to_era", context.get("to_era", from_era))).strip_edges().to_lower()
	if from_era != "" and to_era != "" and from_era != to_era:
		return bool(payload.get("allow_cross_era", false))
	return true

func _sync_actor_by_owner(owner_id: String) -> void:
	if not owner_id.begins_with("person:"):
		return
	if gs == null or not gs.has_method("get_npc_by_id"):
		return
	var id_text: String = owner_id.replace("person:", "")
	if not id_text.is_valid_int():
		return
	var actor = gs.get_npc_by_id(int(id_text))
	if actor != null:
		_sync_actor_money_mirror(actor)

func _sync_actor_money_mirror(actor) -> void:
	if actor == null or actor.get("bank_balance") == null:
		return
	var summary: Dictionary = get_owner_summary_for_actor(actor, {})
	actor.bank_balance = float(summary.get("bank_balance", 0.0))

func _accounts_for_owner(owner_id: String) -> Array:
	var clean: String = str(owner_id).strip_edges()
	if owner_index.has(clean) and typeof(owner_index.get(clean, [])) == TYPE_ARRAY:
		return owner_index.get(clean, []).duplicate(true)
	var out: Array = []
	for account_id in accounts.keys():
		var account_raw: Variant = accounts.get(account_id, {})
		if typeof(account_raw) == TYPE_DICTIONARY and str((account_raw as Dictionary).get("owner_id", "")) == clean:
			out.append(str(account_id))
	owner_index [clean] = out.duplicate(true)
	return out

func _index_account(account_id: String, owner_id: String) -> void:
	var clean_owner: String = str(owner_id).strip_edges()
	if clean_owner == "":
		return
	var arr: Array = owner_index.get(clean_owner, []) if typeof(owner_index.get(clean_owner, [])) == TYPE_ARRAY else []
	if account_id not in arr:
		arr.append(account_id)
	owner_index [clean_owner] = arr

func _rebuild_owner_index() -> void:
	owner_index.clear()
	for account_id in accounts.keys():
		var account_raw: Variant = accounts.get(account_id, {})
		if typeof(account_raw) != TYPE_DICTIONARY:
			continue
		_index_account(str(account_id), str((account_raw as Dictionary).get("owner_id", "")))

func _format_money(amount: float, currency: String = DEFAULT_CURRENCY) -> String:
	var clean_currency: String = str(currency).strip_edges().to_upper()
	if clean_currency == "":
		clean_currency = DEFAULT_CURRENCY
	return "%s %.2f" % [clean_currency, amount]

func _build_default_contract() -> Dictionary:
	return {
		"schema": "eralife.bank_contract",
		"version": CONTRACT_VERSION,
		"id": "eralife_default_bank_contract",
		"money_authority": "bank_engine",
		"legacy_money_mirror": "Person.bank_balance",
		"account_types": [ACCOUNT_KIND_BANK, ACCOUNT_KIND_INTERWORLD],
		"cash_policy": {
			"physical": true,
			"stealable": true,
			"droppable": true,
		},
		"permissions": {
			"allow_cash_theft": true,
			"require_governed_theft": true,
			"max_cash_theft_percent": 0.35,
			"allow_interworld_credit": true,
		},
		"routes": {
			"large_purchases": "bank",
			"rent": "bank",
			"businesses": "bank",
			"investments": "bank",
			"lawsuits": "bank",
			"royal_taxes": "bank",
			"contracts": "bank",
			"boxing_purses": "bank",
			"server_economies": "interworld_credit"
		},
		"metadata": {
			"save_persistent": true,
			"backwards_compatible": true
		}
	}

func _merge_dict(base: Dictionary, patch: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	for key in patch.keys():
		var patch_value: Variant = patch [key]
		if typeof(patch_value) == TYPE_DICTIONARY and typeof(out.get(key, {})) == TYPE_DICTIONARY:
			out [key] = _merge_dict(out.get(key, {}), patch_value as Dictionary)
		else:
			out [key] = patch_value
	return out

func _make_binary_safe(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var out:= {}
			for key in value.keys():
				out [str(key)] = _make_binary_safe(value [key])
			return out
		TYPE_ARRAY:
			var arr:= []
			for item in value:
				arr.append(_make_binary_safe(item))
			return arr
		TYPE_COLOR:
			var c: Color = value
			return "#%s" % c.to_html(true)
		TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_BOOL:
			return value
		TYPE_NIL:
			return null
		_:
			return str(value)