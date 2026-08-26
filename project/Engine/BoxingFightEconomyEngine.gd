extends Resource
class_name BoxingFightEconomyEngine

const CONTRACT_SCHEMA:= "eralife.boxing_fight_economy_engine"
const CONTRACT_VERSION:= 1

var gs
var active_contract: Dictionary = {}
var fight_economy_ledger: Array = []
var sponsorship_registry: Dictionary = {}
var last_report: Dictionary = {}

func _init(_gs = null, contract: Dictionary = {}) -> void:
	gs = _gs
	set_contract(contract)

func set_contract(contract: Dictionary = {}) -> Dictionary:
	active_contract = _build_default_contract()
	if typeof(contract) == TYPE_DICTIONARY and not contract.is_empty():
		active_contract = _merge_dict(active_contract, contract)

	last_report = {
		"schema": "eralife.boxing_fight_economy_contract_set_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"contract_id": str(active_contract.get("id", "")),
		"set_at_ms": int(Time.get_ticks_msec())
	}

	return last_report.duplicate(true)

func export_state() -> Dictionary:
	return {
		"schema": "eralife.boxing_fight_economy_engine_state",
		"version": CONTRACT_VERSION,
		"active_contract": active_contract.duplicate(true),
		"fight_economy_ledger": fight_economy_ledger.duplicate(true),
		"sponsorship_registry": sponsorship_registry.duplicate(true),
		"last_report": last_report.duplicate(true),
		"exported_at_ms": int(Time.get_ticks_msec())
	}

func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "BoxingFightEconomyEngine import data must be a Dictionary."
		}

	var contract_raw: Variant = data.get("active_contract", {})
	if typeof(contract_raw) == TYPE_DICTIONARY and not (contract_raw as Dictionary).is_empty():
		active_contract = _merge_dict(_build_default_contract(), contract_raw as Dictionary)
	else:
		active_contract = _build_default_contract()

	var ledger_raw: Variant = data.get("fight_economy_ledger", [])
	if typeof(ledger_raw) == TYPE_ARRAY:
		fight_economy_ledger = (ledger_raw as Array).duplicate(true)
	else:
		fight_economy_ledger = []

	var sponsor_raw: Variant = data.get("sponsorship_registry", {})
	if typeof(sponsor_raw) == TYPE_DICTIONARY:
		sponsorship_registry = (sponsor_raw as Dictionary).duplicate(true)
	else:
		sponsorship_registry = {}

	var report_raw: Variant = data.get("last_report", {})
	if typeof(report_raw) == TYPE_DICTIONARY:
		last_report = (report_raw as Dictionary).duplicate(true)
	else:
		last_report = {}

	return {
		"success": true,
		"ledger_count": fight_economy_ledger.size(),
		"sponsor_count": sponsorship_registry.size(),
		"imported_at_ms": int(Time.get_ticks_msec())
	}

func build_fight_economy_preview(a: Person, b: Person, meta: Dictionary = {}) -> Dictionary:
	if a == null or b == null:
		return {}

	var rules: Dictionary = active_contract.get("rules", {}) if typeof(active_contract.get("rules", {})) == TYPE_DICTIONARY else {}
	var a_draw: float = _fighter_draw_score(a)
	var b_draw: float = _fighter_draw_score(b)
	var title_bonus: float = 1.75 if bool(meta.get("title_fight", false)) else 1.0
	var rivalry_bonus: float = 1.35 if _fighters_are_rivals(a, b) else 1.0
	var undisputed_bonus: float = 1.6 if bool(meta.get("undisputed_possible", false)) else 1.0

	var ppv_buys: int = int(max(0.0, (a_draw + b_draw) * title_bonus * rivalry_bonus * undisputed_bonus) * float(rules.get("ppv_buy_multiplier", 1300.0)))
	var ppv_price: float = float(rules.get("ppv_price", 74.99))
	var gross_revenue: float = float(ppv_buys) * ppv_price
	var purse_pool: float = gross_revenue * float(rules.get("purse_pool_share", 0.42))

	var a_share: float = clamp(a_draw / max(1.0, a_draw + b_draw), 0.25, 0.75)
	var b_share: float = 1.0 - a_share

	return {
		"schema": "eralife.boxing_fight_economy_preview",
		"version": CONTRACT_VERSION,
		"ppv_buys": ppv_buys,
		"ppv_price": ppv_price,
		"gross_revenue": gross_revenue,
		"purse_pool": purse_pool,
		"a_projected_purse": purse_pool * a_share,
		"b_projected_purse": purse_pool * b_share,
		"a_share": a_share,
		"b_share": b_share,
		"title_bonus": title_bonus,
		"rivalry_bonus": rivalry_bonus,
		"undisputed_bonus": undisputed_bonus,
		"created_at_ms": int(Time.get_ticks_msec())
	}

func settle_fight_economy(winner: Person, loser: Person, payload: Dictionary, meta: Dictionary = {}) -> Dictionary:
	if winner == null or loser == null:
		return {}

	var preview: Dictionary = build_fight_economy_preview(winner, loser, meta)
	var rules: Dictionary = active_contract.get("rules", {}) if typeof(active_contract.get("rules", {})) == TYPE_DICTIONARY else {}

	var gross_revenue: float = float(preview.get("gross_revenue", 0.0))
	var winner_purse: float = float(preview.get("a_projected_purse", 0.0))
	var loser_purse: float = float(preview.get("b_projected_purse", 0.0))
	var sponsor_bonus: float = _maybe_apply_sponsor_bonus(winner, payload, meta)

	var belts: Array = payload.get("belts", []) if typeof(payload.get("belts", [])) == TYPE_ARRAY else []
	var sanctioning_fee_total: float = 0.0
	var sanctioning_fee_rows: Array = []

	if bool(payload.get("title_fight", meta.get("title_fight", false))):
		var fee_rate: float = float(rules.get("sanctioning_fee_rate", 0.03))
		var fee_min: float = float(rules.get("sanctioning_fee_minimum", 5000.0))
		var fee_max: float = float(rules.get("sanctioning_fee_maximum", 1500000.0))

		for raw_belt in belts:
			var belt: String = str(raw_belt).strip_edges()
			if belt in ["WBA", "WBC", "IBF", "WBO"]:
				var fee: float = clamp(winner_purse * fee_rate, fee_min, fee_max)
				sanctioning_fee_total += fee
				sanctioning_fee_rows.append({
					"body": belt,
					"fee": fee,
					"reason": "world_title_sanctioning_fee"
				})

	winner.bank_balance += winner_purse + sponsor_bonus - sanctioning_fee_total
	loser.bank_balance += loser_purse

	var row:= {
		"schema": "eralife.boxing_fight_economy_row",
		"version": CONTRACT_VERSION,
		"year": int(gs.year if gs != null else 0),
		"winner_id": int(winner.id),
		"loser_id": int(loser.id),
		"winner_name": ("%s %s" % [winner.first_name, winner.last_name]).strip_edges(),
		"loser_name": ("%s %s" % [loser.first_name, loser.last_name]).strip_edges(),
		"division": str(payload.get("division", meta.get("division", ""))),
		"result_type": str(payload.get("result_type", "")),
		"title_fight": bool(payload.get("title_fight", meta.get("title_fight", false))),
		"ppv_buys": int(preview.get("ppv_buys", 0)),
		"gross_revenue": gross_revenue,
		"winner_purse": winner_purse,
		"loser_purse": loser_purse,
		"sponsor_bonus": sponsor_bonus,
		"sanctioning_fee_total": sanctioning_fee_total,
		"sanctioning_fee_rows": sanctioning_fee_rows.duplicate(true),
		"winner_net_payout": winner_purse + sponsor_bonus - sanctioning_fee_total,
		"created_at_ms": int(Time.get_ticks_msec())
	}

	fight_economy_ledger.append(row)
	if fight_economy_ledger.size() > 240:
		fight_economy_ledger.pop_front()

	last_report = row.duplicate(true)
	return row

func _fighter_draw_score(person: Person) -> float:
	if person == null:
		return 0.0

	var rec: Dictionary = person.boxing_profile.get("record", {}) if typeof(person.boxing_profile.get("record", {})) == TYPE_DICTIONARY else {}
	var wins: int = int(rec.get("wins", 0))
	var kos: int = int(rec.get("kos", 0))
	var losses: int = int(rec.get("losses", 0))
	var belts: Array = person.boxing_profile.get("belts", []) if typeof(person.boxing_profile.get("belts", [])) == TYPE_ARRAY else []

	var draw: float = 20.0
	draw += float(wins) * 3.0
	draw += float(kos) * 2.5
	draw -= float(losses) * 1.5
	draw += float(person.fame) * 0.7
	draw += max(0.0, 20.0 - float(person.boxing_profile.get("division_rank", 20))) * 3.0
	draw += float(belts.size()) * 18.0

	if bool(person.boxing_profile.get("undisputed", false)):
		draw += 65.0

	return max(1.0, draw)

func _fighters_are_rivals(a: Person, b: Person) -> bool:
	if a == null or b == null:
		return false

	var a_rivals: Array = a.boxing_profile.get("rivalries", []) if typeof(a.boxing_profile.get("rivalries", [])) == TYPE_ARRAY else []
	var b_rivals: Array = b.boxing_profile.get("rivalries", []) if typeof(b.boxing_profile.get("rivalries", [])) == TYPE_ARRAY else []
	return int(b.id) in a_rivals or int(a.id) in b_rivals

func _maybe_apply_sponsor_bonus(winner: Person, payload: Dictionary, meta: Dictionary = {}) -> float:
	if winner == null:
		return 0.0

	var rules: Dictionary = active_contract.get("rules", {}) if typeof(active_contract.get("rules", {})) == TYPE_DICTIONARY else {}
	var chance: int = int(rules.get("sponsorship_chance", 12))
	if bool(payload.get("title_fight", meta.get("title_fight", false))):
		chance += 12
	if bool(winner.boxing_profile.get("undisputed", false)):
		chance += 15
	if int(winner.fame) >= 70:
		chance += 10

	if randi() % 100 >= clamp(chance, 0, 75):
		return 0.0

	var sponsor_bonus: float = float(rules.get("base_sponsor_bonus", 25000.0)) * max(1.0, float(winner.fame) / 35.0)
	var key: String = str(int(winner.id))
	var rows: Array = sponsorship_registry.get(key, []) if typeof(sponsorship_registry.get(key, [])) == TYPE_ARRAY else []
	rows.append({
		"year": int(gs.year if gs != null else 0),
		"amount": sponsor_bonus,
		"reason": "post_fight_sponsorship",
		"result_type": str(payload.get("result_type", ""))
	})
	sponsorship_registry [key] = rows

	return sponsor_bonus

func _build_default_contract() -> Dictionary:
	return {
		"schema": CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": "default_boxing_fight_economy_contract",
		"policies": {
			"unknown_fields": "preserve",
			"backwards_compatible": true,
		},
		"rules": {
			"ppv_price": 74.99,
			"ppv_buy_multiplier": 1300.0,
			"purse_pool_share": 0.42,
			"base_sponsor_bonus": 25000.0,
			"sponsorship_chance": 12,
			"sanctioning_fee_rate": 0.03,
			"sanctioning_fee_minimum": 5000.0,
			"sanctioning_fee_maximum": 1500000.0
		}
	}

func _merge_dict(base: Dictionary, patch: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	for key in patch.keys():
		if typeof(out.get(key, null)) == TYPE_DICTIONARY and typeof(patch.get(key, null)) == TYPE_DICTIONARY:
			out [key] = _merge_dict(out [key], patch [key])
		else:
			out [key] = patch [key]
	return out