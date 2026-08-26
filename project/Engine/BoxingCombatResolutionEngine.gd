extends Resource
class_name BoxingCombatResolutionEngine

const CONTRACT_SCHEMA:= "eralife.boxing_combat_resolution_engine"
const CONTRACT_VERSION:= 1

var gs
var active_contract: Dictionary = {}
var last_report: Dictionary = {}

func _init(_gs = null, contract: Dictionary = {}) -> void:
	gs = _gs
	set_contract(contract)

func set_contract(contract: Dictionary = {}) -> Dictionary:
	active_contract = _build_default_contract()
	if typeof(contract) == TYPE_DICTIONARY and not contract.is_empty():
		active_contract = _merge_dict(active_contract, contract)

	last_report = {
		"schema": "eralife.boxing_combat_resolution_contract_set_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"contract_id": str(active_contract.get("id", "")),
		"set_at_ms": int(Time.get_ticks_msec())
	}

	return last_report.duplicate(true)

func export_state() -> Dictionary:
	return {
		"schema": "eralife.boxing_combat_resolution_engine_state",
		"version": CONTRACT_VERSION,
		"active_contract": active_contract.duplicate(true),
		"last_report": last_report.duplicate(true),
		"exported_at_ms": int(Time.get_ticks_msec())
	}

func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "BoxingCombatResolutionEngine import data must be a Dictionary."
		}

	var contract_raw: Variant = data.get("active_contract", {})
	if typeof(contract_raw) == TYPE_DICTIONARY and not (contract_raw as Dictionary).is_empty():
		active_contract = _merge_dict(_build_default_contract(), contract_raw as Dictionary)
	else:
		active_contract = _build_default_contract()

	var report_raw: Variant = data.get("last_report", {})
	if typeof(report_raw) == TYPE_DICTIONARY:
		last_report = (report_raw as Dictionary).duplicate(true)
	else:
		last_report = {}

	return {
		"success": true,
		"contract_id": str(active_contract.get("id", "")),
		"imported_at_ms": int(Time.get_ticks_msec())
	}

func build_fighter_snapshot(person: Person) -> Dictionary:
	if person == null:
		return {}

	_ensure_archetype(person)

	var record: Dictionary = person.boxing_profile.get("record", {}) if typeof(person.boxing_profile.get("record", {})) == TYPE_DICTIONARY else {}
	var amateur_record: Dictionary = person.boxing_profile.get("amateur_record", {}) if typeof(person.boxing_profile.get("amateur_record", {})) == TYPE_DICTIONARY else {}
	var ratings: Dictionary = person.boxing_profile.get("ratings", {}) if typeof(person.boxing_profile.get("ratings", {})) == TYPE_DICTIONARY else {}
	var archetype: Dictionary = person.boxing_profile.get("fighter_archetype", {}) if typeof(person.boxing_profile.get("fighter_archetype", {})) == TYPE_DICTIONARY else {}

	return {
		"person_id": int(person.id),
		"name": ("%s %s" % [person.first_name, person.last_name]).strip_edges(),
		"age": int(person.age),
		"division": str(person.boxing_profile.get("weight_class", "Unknown")),
		"rank": int(person.boxing_profile.get("division_rank", 99)),
		"record": record.duplicate(true),
		"record_text": _format_record(record),
		"amateur_record": amateur_record.duplicate(true),
		"amateur_record_text": _format_record(amateur_record),
		"belts": person.boxing_profile.get("belts", []).duplicate(true) if typeof(person.boxing_profile.get("belts", [])) == TYPE_ARRAY else [],
		"archetype": archetype.duplicate(true),
		"archetype_name": str(archetype.get("name", "Balanced Boxer")),
		"style_tags": person.boxing_profile.get("style_tags", []).duplicate(true) if typeof(person.boxing_profile.get("style_tags", [])) == TYPE_ARRAY else [],
		"ratings": ratings.duplicate(true),
		"health": float(person.health),
		"wear": int(person.boxing_profile.get("wear", 0)),
		"scar_tissue": int(person.boxing_profile.get("scar_tissue", 0)),
		"injury_count": person.boxing_profile.get("current_injuries", []).size() if typeof(person.boxing_profile.get("current_injuries", [])) == TYPE_ARRAY else 0,
		"estimated_score": _fighter_base_score(person),
		"built_at_ms": int(Time.get_ticks_msec())
	}

func build_opponent_preview(player: Person, opponent: Person, meta: Dictionary = {}) -> Dictionary:
	if player == null or opponent == null:
		return {
			"success": false,
			"text": "No opponent preview is available."
		}

	var player_snapshot: Dictionary = build_fighter_snapshot(player)
	var opponent_snapshot: Dictionary = build_fighter_snapshot(opponent)
	var a_score: int = int(player_snapshot.get("estimated_score", 0))
	var b_score: int = int(opponent_snapshot.get("estimated_score", 0))
	var diff: int = a_score - b_score
	var danger: String = "Even fight"
	if diff >= 45:
		danger = "You are heavily favored"
	elif diff >= 18:
		danger = "You are favored"
	elif diff <= -45:
		danger = "Extremely dangerous opponent"
	elif diff <= -18:
		danger = "You are the underdog"

	var title_bits: Array = []
	var belts: Array = meta.get("belts", []) if typeof(meta.get("belts", [])) == TYPE_ARRAY else []
	if belts.is_empty() and str(meta.get("belt", "")) != "":
		belts.append(str(meta.get("belt", "")))

	if bool(meta.get("title_fight", false)):
		for belt in belts:
			title_bits.append("%s %s" % [str(belt), str(meta.get("division", opponent_snapshot.get("division", "")))])

	var preview_lines:= [
		"Opponent: %s" % str(opponent_snapshot.get("name", "Unknown")),
		"Record: %s" % str(opponent_snapshot.get("record_text", "0-0-0 (0 KOs)")),
		"Amateur Record: %s" % str(opponent_snapshot.get("amateur_record_text", "0-0-0 (0 KOs)")),
		"Division Rank: #%d" % int(opponent_snapshot.get("rank", 99)),
		"Fighter Type: %s" % str(opponent_snapshot.get("archetype_name", "Balanced Boxer")),
		"Style Tags: %s" % ", ".join(opponent_snapshot.get("style_tags", [])),
		"Belts: %s" % ("None" if opponent_snapshot.get("belts", []).is_empty() else ", ".join(opponent_snapshot.get("belts", []))),
		"Fight Risk: %s" % danger
	]

	if not title_bits.is_empty():
		preview_lines.append("At Stake: %s" % ", ".join(title_bits))

	return {
		"success": true,
		"schema": "eralife.boxing_opponent_preview",
		"version": CONTRACT_VERSION,
		"text": "\n".join(preview_lines),
		"player": player_snapshot,
		"opponent": opponent_snapshot,
		"meta": meta.duplicate(true),
		"risk_label": danger,
		"score_diff": diff,
		"created_at_ms": int(Time.get_ticks_msec())
	}

func simulate_fight(a: Person, b: Person, meta: Dictionary = {}) -> Dictionary:
	if a == null or b == null:
		return {
			"success": false,
			"text": "❌ Fight could not be simulated."
		}

	_ensure_archetype(a)
	_ensure_archetype(b)

	var rules: Dictionary = active_contract.get("rules", {}) if typeof(active_contract.get("rules", {})) == TYPE_DICTIONARY else {}
	var max_rounds: int = int(meta.get("rounds", rules.get("championship_rounds", 12 if bool(meta.get("title_fight", false)) else 10)))
	var exchanges_per_round: int = clamp(int(rules.get("exchanges_per_round", 4)), 1, 8)
	var max_exchange_iterations: int = clamp(int(rules.get("max_exchange_iterations", 48)), 4, 96)

	var state:= {
		"a_id": int(a.id),
		"b_id": int(b.id),
		"a_health": 100.0,
		"b_health": 100.0,
		"a_stamina": 100.0,
		"b_stamina": 100.0,
		"a_rounds": 0,
		"b_rounds": 0,
		"a_stall_count": 0,
		"b_stall_count": 0,
		"round_logs": [],
		"exchange_count": 0,
		"knockdowns": [],
		"meta": meta.duplicate(true)
	}

	var finished: bool = false
	var result_type: String = "Decision"
	var winner_id: int = int(a.id)

	for round_num in range(1, max_rounds + 1):
		if finished:
			break

		var round_log:= {
			"round": round_num,
			"winner_id": int(a.id),
			"a_estimated_points": 9,
			"b_estimated_points": 9,
			"knockdowns": [],
			"exchanges": [],
			"summary": ""
		}

		var a_round_edge: int = 0
		var b_round_edge: int = 0

		for exchange_idx in range(1, exchanges_per_round + 1):
			if int(state.get("exchange_count", 0)) >= max_exchange_iterations:
				break

			var action_a: String = _pick_auto_action(a, b, state, "a")
			var action_b: String = _pick_auto_action(b, a, state, "b")
			var exchange: Dictionary = resolve_exchange(a, b, state, action_a, action_b, {
				"round": round_num,
				"exchange": exchange_idx
			})

			round_log ["exchanges"].append(exchange)
			state ["exchange_count"] = int(state.get("exchange_count", 0)) + 1

			if int(exchange.get("winner_id", -1)) == int(a.id):
				a_round_edge += 1
			elif int(exchange.get("winner_id", -1)) == int(b.id):
				b_round_edge += 1

			if typeof(exchange.get("knockdown", {})) == TYPE_DICTIONARY and not (exchange.get("knockdown", {}) as Dictionary).is_empty():
				round_log ["knockdowns"].append(exchange.get("knockdown", {}))
				state ["knockdowns"].append(exchange.get("knockdown", {}))

			if float(state.get("a_health", 100.0)) <= 0.0:
				finished = true
				result_type = "KO"
				winner_id = int(b.id)
				break

			if float(state.get("b_health", 100.0)) <= 0.0:
				finished = true
				result_type = "KO"
				winner_id = int(a.id)
				break

			if float(state.get("a_health", 100.0)) <= 16.0 and randi() % 100 < 18:
				finished = true
				result_type = "TKO"
				winner_id = int(b.id)
				break

			if float(state.get("b_health", 100.0)) <= 16.0 and randi() % 100 < 18:
				finished = true
				result_type = "TKO"
				winner_id = int(a.id)
				break

		if a_round_edge >= b_round_edge:
			state ["a_rounds"] = int(state.get("a_rounds", 0)) + 1
			round_log ["winner_id"] = int(a.id)
			round_log ["a_estimated_points"] = 10
			round_log ["b_estimated_points"] = 8 if round_log ["knockdowns"].size() > 0 and int(round_log ["knockdowns"] [0].get("scored_by", -1)) == int(a.id) else 9
		else:
			state ["b_rounds"] = int(state.get("b_rounds", 0)) + 1
			round_log ["winner_id"] = int(b.id)
			round_log ["a_estimated_points"] = 8 if round_log ["knockdowns"].size() > 0 and int(round_log ["knockdowns"] [0].get("scored_by", -1)) == int(b.id) else 9
			round_log ["b_estimated_points"] = 10

		round_log ["summary"] = _round_summary(a, b, round_log, state)
		state ["round_logs"].append(round_log)

	if not finished:
		if int(state.get("b_rounds", 0)) > int(state.get("a_rounds", 0)):
			winner_id = int(b.id)
		else:
			winner_id = int(a.id)

	var loser_id: int = int(b.id) if winner_id == int(a.id) else int(a.id)
	var winner_name: String = ("%s %s" % [a.first_name, a.last_name]).strip_edges() if winner_id == int(a.id) else ("%s %s" % [b.first_name, b.last_name]).strip_edges()
	var loser_name: String = ("%s %s" % [b.first_name, b.last_name]).strip_edges() if winner_id == int(a.id) else ("%s %s" % [a.first_name, a.last_name]).strip_edges()

	return {
		"success": true,
		"schema": "eralife.boxing_combat_resolution",
		"version": CONTRACT_VERSION,
		"winner_id": winner_id,
		"loser_id": loser_id,
		"winner_name": winner_name,
		"loser_name": loser_name,
		"result_type": result_type,
		"rounds": state.get("round_logs", []).size(),
		"round_logs": state.get("round_logs", []).duplicate(true),
		"knockdowns": state.get("knockdowns", []).duplicate(true),
		"a_rounds": int(state.get("a_rounds", 0)),
		"b_rounds": int(state.get("b_rounds", 0)),
		"a_final_health": float(state.get("a_health", 0.0)),
		"b_final_health": float(state.get("b_health", 0.0)),
		"a_final_stamina": float(state.get("a_stamina", 0.0)),
		"b_final_stamina": float(state.get("b_stamina", 0.0)),
		"exchange_count": int(state.get("exchange_count", 0)),
		"meta": meta.duplicate(true),
		"resolved_at_ms": int(Time.get_ticks_msec())
	}
func begin_live_exchange_fight(player: Person, opponent: Person, pending_contract: Dictionary = {}) -> Dictionary:
	if player == null or opponent == null:
		return {
			"success": false,
			"text": "\n❌\n The live fight could not start."
		}

	_ensure_archetype(player)
	_ensure_archetype(opponent)

	var pending: Dictionary = pending_contract.duplicate(true) if typeof(pending_contract) == TYPE_DICTIONARY else {}
	var meta_raw: Variant = pending.get("meta", {})
	var meta: Dictionary = meta_raw.duplicate(true) if typeof(meta_raw) == TYPE_DICTIONARY else {}
	var rules: Dictionary = active_contract.get("rules", {}) if typeof(active_contract.get("rules", {})) == TYPE_DICTIONARY else {}

	var title_fight: bool = bool(meta.get("title_fight", false))
	var max_rounds: int = int(meta.get("rounds", rules.get("championship_rounds", 12 if title_fight else rules.get("standard_rounds", 10))))
	var exchanges_per_round: int = clamp(int(meta.get("exchanges_per_round", rules.get("live_exchanges_per_round", rules.get("exchanges_per_round", 4)))), 1, 8)
	var venue_contract: Dictionary = pending.get("venue", {}) if typeof(pending.get("venue", {})) == TYPE_DICTIONARY else {}
	if venue_contract.is_empty():
		venue_contract = select_venue_contract(player, opponent, meta)

	meta ["venue"] = venue_contract.duplicate(true)

	var state:= {
		"schema": "eralife.boxing_live_exchange_state",
		"version": CONTRACT_VERSION,
		"fighter_id": int(player.id),
		"opponent_id": int(opponent.id),
		"fighter_name": ("%s %s" % [player.first_name, player.last_name]).strip_edges(),
		"opponent_name": ("%s %s" % [opponent.first_name, opponent.last_name]).strip_edges(),
		"round": 1,
		"exchange": 1,
		"max_rounds": max_rounds,
		"exchanges_per_round": exchanges_per_round,
		"a_health": 100.0,
		"b_health": 100.0,
		"a_stamina": 100.0,
		"b_stamina": 100.0,
		"a_rounds": 0,
		"b_rounds": 0,
		"a_exchange_edge": 0,
		"b_exchange_edge": 0,
		"a_stall_count": 0,
		"b_stall_count": 0,
		"exchange_count": 0,
		"knockdowns": [],
		"round_logs": [],
		"current_round_log": _new_live_round_log(1, player),
		"last_exchange": {},
		"last_crowd_reaction": "The crowd is waiting for the first bell.",
		"pending_contract": pending.duplicate(true),
		"meta": meta.duplicate(true),
		"venue": venue_contract.duplicate(true),
		"started_at_ms": int(Time.get_ticks_msec())
	}

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["boxing_live_exchange"] = state.duplicate(true)

	return _build_live_exchange_prompt(player, opponent, state, {
		"intro": true
	})


func resolve_live_exchange_action(action_label: String) -> Dictionary:
	if gs == null or typeof(gs.scenario_state) != TYPE_DICTIONARY:
		return {
			"success": false,
			"text": "\n❌\n No live boxing state is available."
		}

	var state_raw: Variant = gs.scenario_state.get("boxing_live_exchange", {})
	if typeof(state_raw) != TYPE_DICTIONARY or (state_raw as Dictionary).is_empty():
		return {
			"success": false,
			"text": "\n❌\n There is no live exchange fight active."
		}

	var state: Dictionary = (state_raw as Dictionary).duplicate(true)
	var player: Person = gs.player
	if player == null or int(player.id) != int(state.get("fighter_id", -1)):
		return {
			"success": false,
			"text": "\n❌\n The live fight lost track of the player fighter."
		}

	var opponent_id: int = int(state.get("opponent_id", -1))
	var opponent = gs.get_npc_by_id(opponent_id)
	if opponent == null or not opponent.alive:
		gs.scenario_state.erase("boxing_live_exchange")
		return {
			"success": false,
			"text": "\n❌\n The opponent is no longer available."
		}

	var action: String = _map_live_exchange_action(action_label)
	if action == "retire":
		return _finish_live_exchange_fight(player, opponent, state, int(opponent.id), "RTD")

	if action == "":
		return _build_live_exchange_prompt(player, opponent, state, {
			"warning": "Pick a valid boxing action."
		})

	var round_num: int = int(state.get("round", 1))
	var exchange_idx: int = int(state.get("exchange", 1))
	var opponent_action: String = _pick_auto_action(opponent, player, state, "b")

	var exchange: Dictionary = resolve_exchange(player, opponent, state, action, opponent_action, {
		"round": round_num,
		"exchange": exchange_idx
	})

	state ["exchange_count"] = int(state.get("exchange_count", 0)) + 1
	state ["last_exchange"] = exchange.duplicate(true)
	state ["last_crowd_reaction"] = _crowd_reaction_for_exchange(exchange, player, opponent)

	var current_round_raw: Variant = state.get("current_round_log", {})
	var current_round: Dictionary = current_round_raw.duplicate(true) if typeof(current_round_raw) == TYPE_DICTIONARY else _new_live_round_log(round_num, player)
	var exchanges: Array = current_round.get("exchanges", []) if typeof(current_round.get("exchanges", [])) == TYPE_ARRAY else []
	exchanges.append(exchange.duplicate(true))
	current_round ["exchanges"] = exchanges

	if int(exchange.get("winner_id", -1)) == int(player.id):
		state ["a_exchange_edge"] = int(state.get("a_exchange_edge", 0)) + 1
	elif int(exchange.get("winner_id", -1)) == int(opponent.id):
		state ["b_exchange_edge"] = int(state.get("b_exchange_edge", 0)) + 1

	var knockdown_raw: Variant = exchange.get("knockdown", {})
	if typeof(knockdown_raw) == TYPE_DICTIONARY and not (knockdown_raw as Dictionary).is_empty():
		var knockdown: Dictionary = (knockdown_raw as Dictionary).duplicate(true)
		var round_kds: Array = current_round.get("knockdowns", []) if typeof(current_round.get("knockdowns", [])) == TYPE_ARRAY else []
		round_kds.append(knockdown)
		current_round ["knockdowns"] = round_kds

		var state_kds: Array = state.get("knockdowns", []) if typeof(state.get("knockdowns", [])) == TYPE_ARRAY else []
		state_kds.append(knockdown)
		state ["knockdowns"] = state_kds

	state ["current_round_log"] = current_round

	var rules: Dictionary = active_contract.get("rules", {}) if typeof(active_contract.get("rules", {})) == TYPE_DICTIONARY else {}
	var ko_threshold: float = float(rules.get("ko_health_threshold", 0.0))
	var tko_threshold: float = float(rules.get("tko_health_threshold", 16.0))

	if float(state.get("a_health", 100.0)) <= ko_threshold:
		return _finish_live_exchange_fight(player, opponent, state, int(opponent.id), "KO")

	if float(state.get("b_health", 100.0)) <= ko_threshold:
		return _finish_live_exchange_fight(player, opponent, state, int(player.id), "KO")

	if float(state.get("a_health", 100.0)) <= tko_threshold and randi() % 100 < 18:
		return _finish_live_exchange_fight(player, opponent, state, int(opponent.id), "TKO")

	if float(state.get("b_health", 100.0)) <= tko_threshold and randi() % 100 < 18:
		return _finish_live_exchange_fight(player, opponent, state, int(player.id), "TKO")

	var exchanges_per_round: int = int(state.get("exchanges_per_round", 4))
	if exchange_idx >= exchanges_per_round:
		state = _score_live_round(player, opponent, state)

		if int(state.get("round", 1)) > int(state.get("max_rounds", 10)):
			var winner_id: int = int(player.id)
			if int(state.get("b_rounds", 0)) > int(state.get("a_rounds", 0)):
				winner_id = int(opponent.id)
			return _finish_live_exchange_fight(player, opponent, state, winner_id, "Decision")

		state ["exchange"] = 1
		state ["current_round_log"] = _new_live_round_log(int(state.get("round", 1)), player)
		state ["a_exchange_edge"] = 0
		state ["b_exchange_edge"] = 0
	else:
		state ["exchange"] = exchange_idx + 1

	gs.scenario_state ["boxing_live_exchange"] = state.duplicate(true)
	return _build_live_exchange_prompt(player, opponent, state, {})


func select_venue_contract(player: Person, opponent: Person, meta: Dictionary = {}) -> Dictionary:
	var venues: Array = _boxing_venue_contracts()
	var player_record: Dictionary = player.boxing_profile.get("record", {}) if player != null and typeof(player.boxing_profile.get("record", {})) == TYPE_DICTIONARY else {}
	var opponent_record: Dictionary = opponent.boxing_profile.get("record", {}) if opponent != null and typeof(opponent.boxing_profile.get("record", {})) == TYPE_DICTIONARY else {}

	var combined_wins: int = int(player_record.get("wins", 0)) + int(opponent_record.get("wins", 0))
	var title_fight: bool = bool(meta.get("title_fight", false))
	var target_tier: String = "local"

	if title_fight:
		target_tier = "championship"
	elif combined_wins >= 45:
		target_tier = "arena"
	elif combined_wins >= 20:
		target_tier = "regional"

	var candidates: Array = []
	for raw_venue in venues:
		if typeof(raw_venue) != TYPE_DICTIONARY:
			continue
		var venue: Dictionary = raw_venue
		if str(venue.get("tier", "local")) == target_tier:
			candidates.append(venue)

	if candidates.is_empty():
		candidates = venues.duplicate(true)

	if candidates.is_empty():
		return {
			"id": "local_gym",
			"name": "Your Local Gym",
			"tier": "local",
			"capacity": 120,
			"atmosphere": "sweaty, loud, close-range"
		}

	return candidates [randi() % candidates.size()].duplicate(true)
func resolve_exchange(a: Person, b: Person, state: Dictionary, action_a: String = "auto", action_b: String = "auto", context: Dictionary = {}) -> Dictionary:
	if a == null or b == null:
		return {}

	var clean_action_a: String = str(action_a).strip_edges().to_lower()
	var clean_action_b: String = str(action_b).strip_edges().to_lower()

	if clean_action_a == "" or clean_action_a == "auto":
		clean_action_a = _pick_auto_action(a, b, state, "a")
	if clean_action_b == "" or clean_action_b == "auto":
		clean_action_b = _pick_auto_action(b, a, state, "b")

	var a_score: int = _exchange_score(a, b, state, clean_action_a, clean_action_b, "a")
	var b_score: int = _exchange_score(b, a, state, clean_action_b, clean_action_a, "b")
	var winner: Person = a if a_score >= b_score else b
	var loser: Person = b if winner == a else a
	var winner_slot: String = "a" if winner == a else "b"
	var loser_slot: String = "b" if winner == a else "a"

	var margin: int = abs(a_score - b_score)
	var damage: float = _exchange_damage(winner, loser, margin, clean_action_a if winner == a else clean_action_b)
	var stamina_cost_winner: float = _action_stamina_cost(clean_action_a if winner == a else clean_action_b)
	var stamina_cost_loser: float = _action_stamina_cost(clean_action_b if winner == a else clean_action_a) + 1.5

	if clean_action_a in ["stall", "wait", "freeze"]:
		state ["a_stall_count"] = int(state.get("a_stall_count", 0)) + 1
		state ["a_stamina"] = max(0.0, float(state.get("a_stamina", 100.0)) - 2.0)
		state ["a_health"] = max(0.0, float(state.get("a_health", 100.0)) - 4.0)
	if clean_action_b in ["stall", "wait", "freeze"]:
		state ["b_stall_count"] = int(state.get("b_stall_count", 0)) + 1
		state ["b_stamina"] = max(0.0, float(state.get("b_stamina", 100.0)) - 2.0)
		state ["b_health"] = max(0.0, float(state.get("b_health", 100.0)) - 4.0)

	state ["%s_health" % loser_slot] = max(0.0, float(state.get("%s_health" % loser_slot, 100.0)) - damage)
	state ["%s_stamina" % winner_slot] = max(0.0, float(state.get("%s_stamina" % winner_slot, 100.0)) - stamina_cost_winner)
	state ["%s_stamina" % loser_slot] = max(0.0, float(state.get("%s_stamina" % loser_slot, 100.0)) - stamina_cost_loser)

	var knockdown: Dictionary = {}
	if margin >= 28 and randi() % 100 < clamp(int(damage * 4.0), 8, 55):
		knockdown = {
			"scored_by": int(winner.id),
			"round": int(context.get("round", 0)),
			"exchange": int(context.get("exchange", 0)),
			"text": "%s landed a shot that changed the whole exchange." % winner.first_name
		}
		state ["%s_health" % loser_slot] = max(0.0, float(state.get("%s_health" % loser_slot, 100.0)) - 8.0)

	return {
		"round": int(context.get("round", 0)),
		"exchange": int(context.get("exchange", 0)),
		"winner_id": int(winner.id),
		"loser_id": int(loser.id),
		"action_a": clean_action_a,
		"action_b": clean_action_b,
		"a_score": a_score,
		"b_score": b_score,
		"damage": damage,
		"knockdown": knockdown,
		"summary": _exchange_summary(winner, loser, clean_action_a if winner == a else clean_action_b, damage, knockdown)
	}
func _new_live_round_log(round_num: int, player: Person) -> Dictionary:
	return {
		"round": round_num,
		"winner_id": int(player.id) if player != null else -1,
		"a_estimated_points": 9,
		"b_estimated_points": 9,
		"knockdowns": [],
		"exchanges": [],
		"summary": ""
	}


func _score_live_round(player: Person, opponent: Person, state: Dictionary) -> Dictionary:
	var round_log_raw: Variant = state.get("current_round_log", {})
	var round_log: Dictionary = round_log_raw.duplicate(true) if typeof(round_log_raw) == TYPE_DICTIONARY else _new_live_round_log(int(state.get("round", 1)), player)

	var a_edge: int = int(state.get("a_exchange_edge", 0))
	var b_edge: int = int(state.get("b_exchange_edge", 0))
	var knockdowns: Array = round_log.get("knockdowns", []) if typeof(round_log.get("knockdowns", [])) == TYPE_ARRAY else []

	if a_edge >= b_edge:
		state ["a_rounds"] = int(state.get("a_rounds", 0)) + 1
		round_log ["winner_id"] = int(player.id)
		round_log ["a_estimated_points"] = 10
		round_log ["b_estimated_points"] = 8 if knockdowns.size() > 0 and int(knockdowns [0].get("scored_by", -1)) == int(player.id) else 9
	else:
		state ["b_rounds"] = int(state.get("b_rounds", 0)) + 1
		round_log ["winner_id"] = int(opponent.id)
		round_log ["a_estimated_points"] = 8 if knockdowns.size() > 0 and int(knockdowns [0].get("scored_by", -1)) == int(opponent.id) else 9
		round_log ["b_estimated_points"] = 10

	round_log ["summary"] = _round_summary(player, opponent, round_log, state)

	var logs: Array = state.get("round_logs", []) if typeof(state.get("round_logs", [])) == TYPE_ARRAY else []
	logs.append(round_log.duplicate(true))
	state ["round_logs"] = logs
	state ["round"] = int(state.get("round", 1)) + 1
	return state


func _finish_live_exchange_fight(player: Person, opponent: Person, state: Dictionary, winner_id: int, result_type: String) -> Dictionary:
	if gs == null:
		return {
			"success": false,
			"text": "\n❌\n The boxing runtime is unavailable."
		}

	var round_logs: Array = state.get("round_logs", []) if typeof(state.get("round_logs", [])) == TYPE_ARRAY else []
	var current_round_raw: Variant = state.get("current_round_log", {})
	if typeof(current_round_raw) == TYPE_DICTIONARY and not (current_round_raw as Dictionary).is_empty():
		var current_round: Dictionary = (current_round_raw as Dictionary).duplicate(true)
		var exchanges: Array = current_round.get("exchanges", []) if typeof(current_round.get("exchanges", [])) == TYPE_ARRAY else []
		if exchanges.size() > 0 and int(current_round.get("round", 0)) <= int(state.get("max_rounds", 10)):
			current_round ["summary"] = _round_summary(player, opponent, current_round, state)
			round_logs.append(current_round)

	var loser_id: int = int(opponent.id) if winner_id == int(player.id) else int(player.id)
	var winner_name: String = ("%s %s" % [player.first_name, player.last_name]).strip_edges() if winner_id == int(player.id) else ("%s %s" % [opponent.first_name, opponent.last_name]).strip_edges()
	var loser_name: String = ("%s %s" % [opponent.first_name, opponent.last_name]).strip_edges() if winner_id == int(player.id) else ("%s %s" % [player.first_name, player.last_name]).strip_edges()

	var meta_raw: Variant = state.get("meta", {})
	var meta: Dictionary = meta_raw.duplicate(true) if typeof(meta_raw) == TYPE_DICTIONARY else {}
	meta ["venue"] = state.get("venue", {}).duplicate(true) if typeof(state.get("venue", {})) == TYPE_DICTIONARY else {}
	meta ["prebuilt_combat_resolution"] = {
		"success": true,
		"schema": "eralife.boxing_combat_resolution",
		"version": CONTRACT_VERSION,
		"winner_id": winner_id,
		"loser_id": loser_id,
		"winner_name": winner_name,
		"loser_name": loser_name,
		"result_type": result_type,
		"rounds": round_logs.size(),
		"round_logs": round_logs.duplicate(true),
		"knockdowns": state.get("knockdowns", []).duplicate(true) if typeof(state.get("knockdowns", [])) == TYPE_ARRAY else [],
		"a_rounds": int(state.get("a_rounds", 0)),
		"b_rounds": int(state.get("b_rounds", 0)),
		"a_final_health": float(state.get("a_health", 0.0)),
		"b_final_health": float(state.get("b_health", 0.0)),
		"a_final_stamina": float(state.get("a_stamina", 0.0)),
		"b_final_stamina": float(state.get("b_stamina", 0.0)),
		"exchange_count": int(state.get("exchange_count", 0)),
		"meta": meta.duplicate(true),
		"resolved_at_ms": int(Time.get_ticks_msec())
	}

	if typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state.erase("boxing_live_exchange")

	player.boxing_profile ["pending_fight_contract"] = {}
	opponent.boxing_profile ["pending_fight_contract"] = {}

	if gs.boxing_fight_sim_engine != null:
		return gs.boxing_fight_sim_engine.simulate_fight(player, opponent, meta)

	return {
		"success": true,
		"text": "\n🥊\n %s defeated %s by %s." % [winner_name, loser_name, result_type],
		"winner_id": winner_id,
		"loser_id": loser_id,
		"result_type": result_type
	}


func _build_live_exchange_prompt(player: Person, opponent: Person, state: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var round_num: int = int(state.get("round", 1))
	var exchange_idx: int = int(state.get("exchange", 1))
	var max_rounds: int = int(state.get("max_rounds", 10))
	var exchanges_per_round: int = int(state.get("exchanges_per_round", 4))
	var venue: Dictionary = state.get("venue", {}) if typeof(state.get("venue", {})) == TYPE_DICTIONARY else {}
	var last_exchange: Dictionary = state.get("last_exchange", {}) if typeof(state.get("last_exchange", {})) == TYPE_DICTIONARY else {}

	var score_text: String = "Live Score: You %d • %s %d" % [
		int(state.get("a_rounds", 0)),
		opponent.first_name,
		int(state.get("b_rounds", 0))
	]

	var action_line: String = ""
	if not last_exchange.is_empty():
		action_line = "\n\nLast Exchange: %s" % str(last_exchange.get("summary", ""))

	var intro_text: String = ""
	if bool(extra.get("intro", false)):
		intro_text = "The bell rings. You are in the fight now.\n\n"

	var warning_text: String = ""
	if str(extra.get("warning", "")).strip_edges() != "":
		warning_text = "\n\n%s" % str(extra.get("warning", "")).strip_edges()

	var text:= "%sVenue: %s\nAtmosphere: %s\nRound %d/%d • Exchange %d/%d\n%s\n\nCrowd: %s%s%s" % [
		intro_text,
		str(venue.get("name", "Unknown Venue")),
		str(venue.get("atmosphere", "tense")),
		round_num,
		max_rounds,
		exchange_idx,
		exchanges_per_round,
		score_text,
		str(state.get("last_crowd_reaction", "The crowd is reading every movement.")),
		action_line,
		warning_text
	]

	return {
		"success": true,
		"type": "scenario_prompt",
		"panel_title": "🥊 LIVE EXCHANGE — BOXING MODE",
		"text": text,
		"footer_text": "Pick your next exchange. Stalling hurts you.",
		"opps": _live_exchange_actions(player, opponent, state),
		"combat_ui": {
			"visible": true,
			"mode": "boxing_live_exchange",
			"status_text": "Round %d/%d • Exchange %d/%d • %s" % [round_num, max_rounds, exchange_idx, exchanges_per_round, score_text],
			"player_label": "%s — Health / Stamina %.0f" % [player.first_name, float(state.get("a_stamina", 100.0))],
			"player_value": float(state.get("a_health", 100.0)),
			"player_max": 100.0,
			"enemy_label": "%s — Health / Stamina %.0f" % [opponent.first_name, float(state.get("b_stamina", 100.0))],
			"enemy_value": float(state.get("b_health", 100.0)),
			"enemy_max": 100.0,
			"round_score_text": score_text,
			"crowd_reaction": str(state.get("last_crowd_reaction", "")),
			"impact_shake": bool(last_exchange.get("knockdown", {}) != {}),
			"impact_shake_amount": clampf(float(last_exchange.get("damage", 0.0)) / 18.0, 0.0, 1.0)
		}
	}


func _live_exchange_actions(_player: Person, _opponent: Person, _state: Dictionary) -> Array:
	return [
		{ "label": "Jab", "tooltip": "Low risk. Scores clean and protects rhythm."},
		{ "label": "Cross", "tooltip": "Sharper straight shot. Higher damage than jab."},
		{ "label": "Body Work", "tooltip": "Drains stamina and slows the opponent."},
		{ "label": "Left Hook", "tooltip": "High reward, especially inside."},
		{ "label": "Right Hook", "tooltip": "Power side hook. Can swing the exchange."},
		{ "label": "Left Uppercut", "tooltip": "Dangerous inside shot."},
		{ "label": "Right Uppercut", "tooltip": "Big damage, bigger stamina cost."},
		{ "label": "Counter", "tooltip": "Punishes reckless pressure and power shots."},
		{ "label": "Defend", "tooltip": "Recover rhythm and reduce danger."},
		{ "label": "Clinch", "tooltip": "Smother action and survive rough moments."},
		{ "label": "Stall", "tooltip": "Fake pressure choice. Costs health and stamina if abused."},
		{ "label": "Retire on the stool", "tooltip": "End the fight by RTD."}
	]


func _map_live_exchange_action(action_label: String) -> String:
	var clean: String = str(action_label).strip_edges().to_lower()
	match clean:
		"jab":
			return "jab"
		"cross":
			return "cross"
		"body work":
			return "body_work"
		"left hook", "right hook":
			return "hook"
		"left uppercut", "right uppercut":
			return "uppercut"
		"counter":
			return "counter"
		"defend":
			return "defend"
		"clinch":
			return "clinch"
		"stall", "wait", "freeze":
			return "stall"
		"retire on the stool":
			return "retire"
		_:
			return ""


func _crowd_reaction_for_exchange(exchange: Dictionary, player: Person, opponent: Person) -> String:
	var damage: float = float(exchange.get("damage", 0.0))
	var winner_id: int = int(exchange.get("winner_id", -1))
	var winner_name: String = player.first_name if winner_id == int(player.id) else opponent.first_name

	if typeof(exchange.get("knockdown", {})) == TYPE_DICTIONARY and not (exchange.get("knockdown", {}) as Dictionary).is_empty():
		return "The building erupts. That shot changed the whole round."

	if damage >= 12.0:
		return "The crowd jumps out of their seats after %s lands heavy." % winner_name
	if damage >= 7.0:
		return "The arena reacts loud. %s got the better of that exchange." % winner_name
	if str(exchange.get("action_a", "")) == "stall":
		return "Boos start creeping in. The referee is watching the inactivity."
	return "The crowd murmurs as both fighters reset their feet."


func _boxing_venue_contracts() -> Array:
	var contract_venues: Array = active_contract.get("venues", []) if typeof(active_contract.get("venues", [])) == TYPE_ARRAY else []
	if not contract_venues.is_empty():
		return contract_venues

	return [
		{ "id": "your_local_gym", "name": "Your Local Gym", "tier": "local", "capacity": 120, "atmosphere": "sweaty, cramped, personal"},
		{ "id": "a_backyard", "name": "A Backyard", "tier": "local", "capacity": 80, "atmosphere": "chaotic and way too close"},
		{ "id": "aragon_ballroom", "name": "Aragon Ballroom", "tier": "regional", "capacity": 5000, "atmosphere": "loud, gritty, old-school"},
		{ "id": "state_palace_theater", "name": "State Palace Theater", "tier": "regional", "capacity": 3000, "atmosphere": "bright lights and anxious corners"},
		{ "id": "boardwalk_hall", "name": "Boardwalk Hall", "tier": "regional", "capacity": 14000, "atmosphere": "historic, sharp, pressure-heavy"},
		{ "id": "thomas_mack_center", "name": "Thomas & Mack Center", "tier": "arena", "capacity": 18000, "atmosphere": "Vegas pressure without mercy"},
		{ "id": "mgm_grand", "name": "MGM Grand", "tier": "arena", "capacity": 17000, "atmosphere": "championship neon and money"},
		{ "id": "madison_square_garden", "name": "Madison Square Garden", "tier": "championship", "capacity": 20000, "atmosphere": "legacy breathing down your neck"},
		{ "id": "times_square", "name": "Times Square", "tier": "championship", "capacity": 35000, "atmosphere": "spectacle, cameras, chaos"},
		{ "id": "hard_rock_stadium", "name": "Hard Rock Stadium", "tier": "championship", "capacity": 65000, "atmosphere": "stadium roar and humid violence"},
		{ "id": "the_big_house", "name": "The Big House (Ann Arbor, Michigan)", "tier": "championship", "capacity": 107000, "atmosphere": "football-sized pressure for a boxing night"},
		{ "id": "cowboys_stadium", "name": "Cowboys Stadium", "tier": "championship", "capacity": 80000, "atmosphere": "massive, corporate, deafening"}
	]
func _ensure_archetype(person: Person) -> void:
	if person == null:
		return

	if typeof(person.boxing_profile) != TYPE_DICTIONARY:
		person.boxing_profile = {}

	var archetype_raw: Variant = person.boxing_profile.get("fighter_archetype", {})
	if typeof(archetype_raw) == TYPE_DICTIONARY and not (archetype_raw as Dictionary).is_empty():
		return

	var ratings: Dictionary = person.boxing_profile.get("ratings", {}) if typeof(person.boxing_profile.get("ratings", {})) == TYPE_DICTIONARY else {}
	var power: int = int(ratings.get("power", 50))
	var speed: int = int(ratings.get("speed", 50))
	var defense: int = int(ratings.get("defense", 50))
	var ring_iq: int = int(ratings.get("ring_iq", 50))
	var footwork: int = int(ratings.get("footwork", 50))
	var cardio: int = int(ratings.get("cardio", 50))
	var chin: int = int(ratings.get("chin", 50))

	var archetype:= {
		"id": "balanced_boxer",
		"name": "Balanced Boxer",
		"traits": ["balanced"],
		"preferred_actions": ["jab", "body_work", "defend", "counter"],
		"strengths": ["adaptability"],
		"weaknesses": []
	}

	if power >= 70 and chin >= 62:
		archetype = {
			"id": "pressure_fighter",
			"name": "Pressure Fighter",
			"traits": ["pressure", "inside_work", "durable"],
			"preferred_actions": ["pressure", "body_work", "power_shot"],
			"strengths": ["pace", "damage"],
			"weaknesses": ["slick_movement"]
		}
	elif defense >= 68 and footwork >= 68:
		archetype = {
			"id": "slick_puncher",
			"name": "Slick Puncher",
			"traits": ["slick", "defensive", "sharp"],
			"preferred_actions": ["jab", "defend", "counter", "pivot"],
			"strengths": ["avoidance", "clean_shots"],
			"weaknesses": ["pressure_volume"]
		}
	elif ring_iq >= 70 and speed >= 62:
		archetype = {
			"id": "counterpuncher",
			"name": "Counterpuncher",
			"traits": ["patient", "technical", "counter"],
			"preferred_actions": ["counter", "defend", "jab"],
			"strengths": ["timing", "punishing_mistakes"],
			"weaknesses": ["low_volume"]
		}
	elif cardio >= 70 and speed >= 62:
		archetype = {
			"id": "volume_puncher",
			"name": "Volume Puncher",
			"traits": ["pace", "volume", "pressure"],
			"preferred_actions": ["jab", "pressure", "body_work"],
			"strengths": ["pace", "late_rounds"],
			"weaknesses": ["power_shots"]
		}

	person.boxing_profile ["fighter_archetype"] = archetype

	var tags: Array = person.boxing_profile.get("style_tags", []) if typeof(person.boxing_profile.get("style_tags", [])) == TYPE_ARRAY else []
	if str(archetype.get("name", "")) not in tags:
		tags.append(str(archetype.get("name", "")))
	person.boxing_profile ["style_tags"] = tags

func _pick_auto_action(person: Person, _opponent: Person, _state: Dictionary, _slot: String) -> String:
	_ensure_archetype(person)
	var archetype: Dictionary = person.boxing_profile.get("fighter_archetype", {}) if typeof(person.boxing_profile.get("fighter_archetype", {})) == TYPE_DICTIONARY else {}
	var actions: Array = archetype.get("preferred_actions", []) if typeof(archetype.get("preferred_actions", [])) == TYPE_ARRAY else []
	if actions.is_empty():
		actions = ["jab", "body_work", "defend", "counter"]
	return str(actions [randi() % actions.size()])

func _exchange_score(person: Person, opponent: Person, state: Dictionary, own_action: String, opponent_action: String, slot: String) -> int:
	var ratings: Dictionary = person.boxing_profile.get("ratings", {}) if typeof(person.boxing_profile.get("ratings", {})) == TYPE_DICTIONARY else {}
	var archetype: Dictionary = person.boxing_profile.get("fighter_archetype", {}) if typeof(person.boxing_profile.get("fighter_archetype", {})) == TYPE_DICTIONARY else {}
	var stamina: float = float(state.get("%s_stamina" % slot, 100.0))
	var health: float = float(state.get("%s_health" % slot, 100.0))
	var score: int = 0

	match own_action:
		"jab":
			score += int(ratings.get("jab", ratings.get("speed", 50)) * 0.42)
			score += int(ratings.get("ring_iq", 50) * 0.24)
			score += int(ratings.get("footwork", 50) * 0.22)
		"cross":
			score += int(ratings.get("cross", ratings.get("power", 50)) * 0.38)
			score += int(ratings.get("speed", 50) * 0.2)
			score += int(ratings.get("ring_iq", 50) * 0.18)
		"hook":
			score += int(max(float(ratings.get("left_hook", 50)), float(ratings.get("right_hook", 50))) * 0.36)
			score += int(ratings.get("power", 50) * 0.24)
			score += int(ratings.get("strength", ratings.get("power", 50)) * 0.16)
		"uppercut":
			score += int(max(float(ratings.get("left_uppercut", 50)), float(ratings.get("right_uppercut", 50))) * 0.4)
			score += int(ratings.get("power", 50) * 0.28)
			score += int(ratings.get("killer_instinct", 50) * 0.16)
		"pressure":
			score += int(ratings.get("power", 50) * 0.3)
			score += int(ratings.get("cardio", 50) * 0.26)
			score += int(ratings.get("chin", 50) * 0.2)
		"body_work":
			score += int(ratings.get("body_work", ratings.get("power", 50)) * 0.3)
			score += int(ratings.get("ring_iq", 50) * 0.2)
			score += int(ratings.get("endurance", ratings.get("cardio", 50)) * 0.18)
		"power_shot":
			score += int(ratings.get("power", 50) * 0.48)
			score += int(ratings.get("killer_instinct", 50) * 0.24)
		"counter":
			score += int(ratings.get("ring_iq", 50) * 0.34)
			score += int(ratings.get("speed", 50) * 0.22)
			score += int(ratings.get("defense", 50) * 0.22)
		"defend", "pivot":
			score += int(ratings.get("defense", 50) * 0.36)
			score += int(ratings.get("footwork", 50) * 0.28)
			score += int(ratings.get("ring_iq", 50) * 0.2)
		"clinch":
			score += int(ratings.get("strength", ratings.get("chin", 50)) * 0.24)
			score += int(ratings.get("ring_iq", 50) * 0.16)
		"stall", "wait", "freeze":
			score -= 24
		_:
			score += int(_fighter_base_score(person) / 10.0)

	score += _style_matchup_bonus(str(archetype.get("id", "balanced_boxer")), own_action, opponent_action, opponent)
	score += int(stamina / 8.0)
	score += int(health / 12.0)
	score -= int(person.boxing_profile.get("wear", 0) / 5.0)
	score -= person.boxing_profile.get("current_injuries", []).size() * 4
	score += randi_range(-12, 12)

	return score

func _style_matchup_bonus(archetype_id: String, own_action: String, opponent_action: String, opponent: Person) -> int:
	var opponent_archetype: Dictionary = opponent.boxing_profile.get("fighter_archetype", {}) if typeof(opponent.boxing_profile.get("fighter_archetype", {})) == TYPE_DICTIONARY else {}
	var opponent_id: String = str(opponent_archetype.get("id", "balanced_boxer"))

	if archetype_id == "pressure_fighter" and opponent_id == "slick_puncher" and own_action in ["pressure", "body_work"]:
		return -4
	if archetype_id == "slick_puncher" and opponent_id == "pressure_fighter" and own_action in ["pivot", "jab", "counter"]:
		return 8
	if archetype_id == "counterpuncher" and opponent_action in ["power_shot", "pressure"]:
		return 9
	if archetype_id == "volume_puncher" and own_action in ["jab", "pressure"]:
		return 5
	return 0

func _exchange_damage(winner: Person, loser: Person, margin: int, action: String) -> float:
	var ratings: Dictionary = winner.boxing_profile.get("ratings", {}) if typeof(winner.boxing_profile.get("ratings", {})) == TYPE_DICTIONARY else {}
	var loser_ratings: Dictionary = loser.boxing_profile.get("ratings", {}) if typeof(loser.boxing_profile.get("ratings", {})) == TYPE_DICTIONARY else {}

	var power: float = float(ratings.get("power", 50))
	var chin: float = max(1.0, float(loser_ratings.get("chin", 50)))
	var base: float = 2.0 + (power / 24.0) + (float(margin) / 10.0) - (chin / 45.0)

	match action:
		"power_shot":
			base += 4.0
		"uppercut":
			base += 3.6
		"hook":
			base += 3.0
		"cross":
			base += 2.2
		"body_work":
			base += 2.0
		"jab":
			base -= 1.0
		"defend", "pivot", "clinch":
			base -= 2.0

	return clamp(base, 1.0, 18.0)

func _action_stamina_cost(action: String) -> float:
	match action:
		"power_shot":
			return 7.0
		"uppercut":
			return 6.5
		"hook":
			return 6.0
		"cross":
			return 4.5
		"pressure":
			return 6.0
		"body_work":
			return 5.0
		"jab":
			return 3.0
		"counter":
			return 4.0
		"defend", "pivot":
			return 2.5
		"clinch":
			return 2.0
		"stall", "wait", "freeze":
			return 1.0
	return 4.0

func _fighter_base_score(person: Person) -> int:
	if person == null:
		return 0

	var ratings: Dictionary = person.boxing_profile.get("ratings", {}) if typeof(person.boxing_profile.get("ratings", {})) == TYPE_DICTIONARY else {}
	var score: int = 0

	for stat in ["power", "speed", "chin", "ring_iq", "defense", "footwork", "cardio", "killer_instinct"]:
		score += int(ratings.get(stat, 50))

	score += int(person.health / 4.0)
	score -= int(person.boxing_profile.get("wear", 0) / 3.0)
	score -= int(person.boxing_profile.get("scar_tissue", 0) / 2.0)
	score -= person.boxing_profile.get("current_injuries", []).size() * 5

	var bp: Dictionary = person.boxing_profile.get("boxing_personality", {}) if typeof(person.boxing_profile.get("boxing_personality", {})) == TYPE_DICTIONARY else {}
	score += int(bp.get("discipline", 50) / 8.0)
	score += int(bp.get("adaptability", 50) / 8.0)
	score += int(bp.get("courage", 50) / 10.0)

	return score

func _round_summary(a: Person, b: Person, round_log: Dictionary, _state: Dictionary) -> String:
	var winner_id: int = int(round_log.get("winner_id", -1))
	var winner_name: String = a.first_name if winner_id == int(a.id) else b.first_name
	var exchange_count: int = round_log.get("exchanges", []).size() if typeof(round_log.get("exchanges", [])) == TYPE_ARRAY else 0

	if round_log.get("knockdowns", []).size() > 0:
		return "Round %d exploded when %s scored a knockdown and took control." % [int(round_log.get("round", 0)), winner_name]

	return "Round %d belonged to %s, who won most of the %d key exchanges." % [
		int(round_log.get("round", 0)),
		winner_name,
		exchange_count
	]

func _exchange_summary(winner: Person, loser: Person, action: String, damage: float, knockdown: Dictionary = {}) -> String:
	if not knockdown.is_empty():
		return str(knockdown.get("text", "%s hurt %s badly." % [winner.first_name, loser.first_name]))

	match action:
		"jab":
			return "%s controlled the exchange behind clean jabs." % winner.first_name
		"pressure":
			return "%s walked %s down and forced the action." % [winner.first_name, loser.first_name]
		"body_work":
			return "%s dug to the body and slowed %s down." % [winner.first_name, loser.first_name]
		"power_shot":
			return "%s landed the heavier shot in the exchange." % winner.first_name
		"counter":
			return "%s made %s miss and answered clean." % [winner.first_name, loser.first_name]
		"defend", "pivot":
			return "%s avoided danger and stole the exchange late." % winner.first_name
		"clinch":
			return "%s smothered the work and controlled the inside." % winner.first_name

	return "%s edged the exchange and did %.1f damage." % [winner.first_name, damage]

func _format_record(record: Dictionary) -> String:
	return "%d-%d-%d (%d KOs)" % [
		int(record.get("wins", 0)),
		int(record.get("losses", 0)),
		int(record.get("draws", 0)),
		int(record.get("kos", 0))
	]

func _build_default_contract() -> Dictionary:
	return {
		"schema": CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": "default_boxing_combat_resolution_contract",
		"policies": {
			"unknown_fields": "preserve",
			"backwards_compatible": true,
		},
		"rules": {
			"championship_rounds": 12,
			"standard_rounds": 10,
			"exchanges_per_round": 4,
			"max_exchange_iterations": 48,
			"stochastic_swing": 12,
			"stall_health_penalty": 4.0,
			"stall_stamina_penalty": 2.0,
			"ko_health_threshold": 0.0,
			"tko_health_threshold": 16.0
		},
		"archetypes": {
			"pressure_fighter": {
				"beats": ["low_cardio_slugger"],
				"struggles_with": ["slick_puncher"],
				"preferred_actions": ["pressure", "body_work", "power_shot"]
			},
			"slick_puncher": {
				"beats": ["pressure_fighter"],
				"struggles_with": ["volume_puncher"],
				"preferred_actions": ["jab", "pivot", "counter"]
			},
			"counterpuncher": {
				"beats": ["reckless_power_puncher"],
				"struggles_with": ["patient_out_boxer"],
				"preferred_actions": ["counter", "defend", "jab"]
			},
			"volume_puncher": {
				"beats": ["inactive_counterpuncher"],
				"struggles_with": ["power_puncher"],
				"preferred_actions": ["jab", "pressure", "body_work"]
			}
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