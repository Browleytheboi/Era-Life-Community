extends Resource
class_name BoxingMatchmakingEngine

var gs
var active_contract: Dictionary = {}
var last_contract_report: Dictionary = {}

func set_contract(contract: Dictionary = {}) -> Dictionary:
	active_contract = {}
	if typeof(contract) == TYPE_DICTIONARY:
		active_contract = (contract as Dictionary).duplicate(true)

	last_contract_report = {
		"schema": "eralife.boxing_subengine_contract_set_report",
		"success": true,
		"engine": get_script().resource_path.get_file() if get_script() != null else "",
		"contract_schema": str(active_contract.get("schema", "")),
		"role": str(active_contract.get("role", "")),
		"set_at_ms": int(Time.get_ticks_msec())
	}

	return last_contract_report.duplicate(true)


func _boxing_contract() -> Dictionary:
	if not active_contract.is_empty():
		return active_contract

	if has_meta("boxing_contract"):
		var raw: Variant = get_meta("boxing_contract", {})
		if typeof(raw) == TYPE_DICTIONARY:
			return (raw as Dictionary)

	return {}


func _boxing_policies() -> Dictionary:
	var contract: Dictionary = _boxing_contract()
	var raw: Variant = contract.get("policies", {})
	if typeof(raw) == TYPE_DICTIONARY:
		return (raw as Dictionary)
	return {}


func _boxing_rules() -> Dictionary:
	var contract: Dictionary = _boxing_contract()
	var raw: Variant = contract.get("rules", {})
	if typeof(raw) == TYPE_DICTIONARY:
		return (raw as Dictionary)
	return {}


func _boxing_policy(key: String, fallback: Variant = null) -> Variant:
	var policies: Dictionary = _boxing_policies()
	var clean_key: String = str(key).strip_edges()
	if clean_key != "" and policies.has(clean_key):
		return policies.get(clean_key)
	return fallback


func _boxing_rule(key: String, fallback: Variant = null) -> Variant:
	var rules: Dictionary = _boxing_rules()
	var clean_key: String = str(key).strip_edges()
	if clean_key != "" and rules.has(clean_key):
		return rules.get(clean_key)
	return fallback


func _boxing_array_policy(key: String, fallback: Array = []) -> Array:
	var raw: Variant = _boxing_policy(key, fallback)
	if typeof(raw) == TYPE_ARRAY:
		return (raw as Array).duplicate(true)
	return fallback.duplicate(true)


func _boxing_dictionary_policy(key: String, fallback: Dictionary = {}) -> Dictionary:
	var raw: Variant = _boxing_policy(key, fallback)
	if typeof(raw) == TYPE_DICTIONARY:
		return (raw as Dictionary).duplicate(true)
	return fallback.duplicate(true)
func _init(_gs):
	gs = _gs

func can_book_fight(person: Person) -> bool:
	if person == null:
		return false
	if not person.boxing_profile.get("is_boxer", false):
		return false
	if person.boxing_profile.get("retired", false):
		return false
	if person.boxing_profile.get("scheduled_opponent_id", -1) != -1:
		return false
	if person.boxing_profile.get("current_injuries", []).size() > 0:
		return false
	if gs.boxing_contract_engine != null and gs.boxing_contract_engine.has_method("can_fighter_take_fight_this_year"):
		if not gs.boxing_contract_engine.can_fighter_take_fight_this_year(person):
			return false
	return true

func book_player_fight(person: Person) -> Dictionary:
	if not can_book_fight(person):
		return { "success": false, "text": "\n❌\n I can't book a fight right now."}

	if gs.boxing_weight_engine != null:
		if not gs.boxing_weight_engine.try_make_weight(person):
			return { "success": false, "text": "\n❌\n I failed to make weight."}

	var mandatory_opp = _find_mandatory_opponent(person)
	var opp = mandatory_opp if mandatory_opp != null else _find_opponent(person)
	if opp == null:
		return { "success": false, "text": "\n❌\n No suitable opponent found."}

	if gs.boxing_promotion_engine != null:
		if gs.boxing_promotion_engine.should_duck(opp, person):
			gs.boxing_promotion_engine.register_duck(person, opp)
			if mandatory_opp != null:
				if gs.event_bus != null:
					gs.event_bus.emit(ActionEventTypes.BOXING_MANDATORY_IGNORED, {
						"npc_id": person.id,
						"target_id": opp.id,
						"text": "\n🚫\n %s ignored a mandatory fight against %s." % [
							person.first_name,
							opp.first_name
						]
					})
				return { "success": false, "text": "\n❌\n I ducked my mandatory challenger."}

			opp = _find_alternate_opponent(person, opp.id)
			if opp == null:
				return { "success": false, "text": "\n❌\n No alternate opponent found."}

	if gs.boxing_weight_engine != null:
		if not gs.boxing_weight_engine.try_make_weight(opp):
			return { "success": false, "text": "\n❌\n The opponent failed to make weight."}

	var title_meta:= _maybe_title_meta(person, opp)
	var pending_contract: Dictionary = _build_pending_fight_contract(person, opp, title_meta, mandatory_opp != null)
	person.boxing_profile ["pending_fight_contract"] = pending_contract.duplicate(true)
	person.boxing_profile ["scheduled_opponent_id"] = opp.id
	opp.boxing_profile ["scheduled_opponent_id"] = person.id

	var preview: Dictionary = {}
	if gs.boxing_combat_resolution_engine != null and gs.boxing_combat_resolution_engine.has_method("build_opponent_preview"):
		preview = gs.boxing_combat_resolution_engine.build_opponent_preview(person, opp, title_meta)

	if gs.event_bus != null:
		gs.event_bus.emit(ActionEventTypes.BOXING_FIGHT_BOOKED, {
			"npc_id": person.id,
			"target_id": opp.id,
			"text": "\n🥊\n %s booked a fight contract with %s. Review the opponent before confirming." % [
				person.first_name,
				opp.first_name
			]
		})

	return {
		"success": true,
		"text": "%s\n\nPress Confirm Boxing Fight to step into the ring." % str(preview.get("text", "Opponent preview unavailable.")),
		"pending_fight_contract": pending_contract.duplicate(true),
		"opponent_preview": preview.duplicate(true)
	}
func confirm_player_fight(person: Person) -> Dictionary:
	if person == null:
		return {
			"success": false,
			"text": "\n❌\n No fighter selected."
		}

	var pending: Dictionary = person.boxing_profile.get("pending_fight_contract", {}) if typeof(person.boxing_profile.get("pending_fight_contract", {})) == TYPE_DICTIONARY else {}
	if pending.is_empty():
		return {
			"success": false,
			"text": "\n❌\n I do not have a fight contract waiting to be confirmed."
		}

	var opponent_id: int = int(pending.get("opponent_id", -1))
	var opp = gs.get_npc_by_id(opponent_id)
	if opp == null or not opp.alive:
		person.boxing_profile ["pending_fight_contract"] = {}
		person.boxing_profile ["scheduled_opponent_id"] = -1
		return {
			"success": false,
			"text": "\n❌\n The opponent is no longer available."
		}

	if gs.boxing_combat_resolution_engine != null and gs.boxing_combat_resolution_engine.has_method("begin_live_exchange_fight"):
		return gs.boxing_combat_resolution_engine.begin_live_exchange_fight(person, opp, pending)

	var meta: Dictionary = pending.get("meta", {}) if typeof(pending.get("meta", {})) == TYPE_DICTIONARY else {}
	var result: Dictionary = gs.boxing_fight_sim_engine.simulate_fight(person, opp, meta)
	person.boxing_profile ["pending_fight_contract"] = {}
	opp.boxing_profile ["pending_fight_contract"] = {}
	return result

func _build_pending_fight_contract(person: Person, opponent: Person, meta: Dictionary, is_mandatory: bool = false) -> Dictionary:
	var economy_preview: Dictionary = {}
	if gs.boxing_fight_economy_engine != null and gs.boxing_fight_economy_engine.has_method("build_fight_economy_preview"):
		economy_preview = gs.boxing_fight_economy_engine.build_fight_economy_preview(person, opponent, meta)

	var venue_contract: Dictionary = {}
	if gs.boxing_combat_resolution_engine != null and gs.boxing_combat_resolution_engine.has_method("select_venue_contract"):
		venue_contract = gs.boxing_combat_resolution_engine.select_venue_contract(person, opponent, meta)

	var resolution_mode: String = str(_boxing_policy("player_fight_resolution_mode", "live_exchange"))
	var confirmation_required: bool = bool(_boxing_policy("fight_confirmation_required", true))

	return {
		"schema": "eralife.pending_boxing_fight_contract",
		"version": 3,
		"fighter_id": int(person.id),
		"opponent_id": int(opponent.id),
		"year": int(gs.year),
		"division": str(person.boxing_profile.get("weight_class", "")),
		"is_mandatory": is_mandatory,
		"meta": meta.duplicate(true),
		"venue": venue_contract.duplicate(true),
		"economy_preview": economy_preview.duplicate(true),
		"requires_confirmation": confirmation_required,
		"resolution_mode": resolution_mode,
		"contract_layer": "BoxingContractEngine",
		"contract_source": "boxing_matchmaking_engine",
		"created_at_ms": int(Time.get_ticks_msec())
	}
func yearly_auto_book_for_npc(npc: Person) -> void:
	if npc == gs.player:
		return
	if not can_book_fight(npc):
		return

	var auto_book_chance: int = int(_boxing_policy("npc_auto_book_chance", 18))
	if randi() % 100 >= auto_book_chance:
		return

	var opp = _find_opponent(npc)
	if opp == null:
		return

	var meta: Dictionary = _maybe_title_meta(npc, opp)
	meta ["contract_source"] = "boxing_matchmaking_engine"
	meta ["auto_booked"] = true

	gs.boxing_fight_sim_engine.simulate_fight(npc, opp, meta)

func _find_opponent(person: Person) -> Person:
	var division = str(person.boxing_profile.get("weight_class", ""))

	if gs.boxing_engine != null and division != "":
		gs.boxing_engine._ensure_division_population(division, person)
		gs.boxing_engine.sync_boxing_division_factions()

	var candidates:= []
	for npc in gs.npcs:
		if npc == person:
			continue
		if not npc.alive:
			continue
		if not npc.boxing_profile.get("is_boxer", false):
			continue
		if npc.boxing_profile.get("retired", false):
			continue
		if str(npc.boxing_profile.get("weight_class", "")) != division:
			continue
		if npc.boxing_profile.get("current_injuries", []).size() > 0:
			continue
		candidates.append(npc)

	if candidates.is_empty():
		return null

	candidates.sort_custom(func (a, b):
		var person_rank = int(person.boxing_profile.get("division_rank", 99))
		var a_diff = abs(int(a.boxing_profile.get("division_rank", 99)) - person_rank)
		var b_diff = abs(int(b.boxing_profile.get("division_rank", 99)) - person_rank)
		return a_diff < b_diff
	)
	return candidates [0]

func _maybe_title_meta(a: Person, b: Person) -> Dictionary:
	var division: String = str(a.boxing_profile.get("weight_class", ""))
	var out:= {
		"title_fight": false,
		"belt": "",
		"belts": [],
		"division": division,
		"lineal_fight": false,
		"undisputed_possible": false
	}

	if gs.boxing_title_engine == null or not gs.boxing_title_engine.champions.has(division):
		return out

	var rank_a: int = int(a.boxing_profile.get("division_rank", 99))
	var rank_b: int = int(b.boxing_profile.get("division_rank", 99))
	var title_bodies: Array = ["WBA", "WBC", "IBF", "WBO"]
	if gs.boxing_contract_engine != null and gs.boxing_contract_engine.has_method("get_title_bodies"):
		title_bodies = gs.boxing_contract_engine.get_title_bodies()

	var belts_at_stake: Array = []

	for belt in title_bodies:
		var holder_id: int = int(gs.boxing_title_engine.champions.get(division, {}).get(belt, -1))
		if holder_id in [int(a.id), int(b.id)]:
			belts_at_stake.append(belt)

	if belts_at_stake.is_empty() and min(rank_a, rank_b) <= 2 and max(rank_a, rank_b) <= 5:
		var available: Array = []
		for belt in title_bodies:
			var holder_id: int = int(gs.boxing_title_engine.champions.get(division, {}).get(belt, -1))
			if holder_id == -1:
				available.append(belt)

		if available.is_empty():
			available = title_bodies.duplicate(true)

		belts_at_stake.append(str(available [randi() % available.size()]))

	if not belts_at_stake.is_empty():
		out ["title_fight"] = true
		out ["belts"] = belts_at_stake.duplicate(true)
		out ["belt"] = str(belts_at_stake [0])

	if gs.boxing_title_engine.has_method("is_lineal_fight"):
		out ["lineal_fight"] = gs.boxing_title_engine.is_lineal_fight(a, b, division)

	if gs.boxing_title_engine.has_method("would_create_undisputed"):
		out ["undisputed_possible"] = gs.boxing_title_engine.would_create_undisputed(a, b, belts_at_stake, division)

	return out
func _find_alternate_opponent(person: Person, excluded_id: int) -> Person:
	var division = str(person.boxing_profile.get("weight_class", ""))
	var candidates:= []

	for npc in gs.npcs:
		if npc == null or npc.id == excluded_id or npc == person:
			continue
		if not npc.alive:
			continue
		if not npc.boxing_profile.get("is_boxer", false):
			continue
		if npc.boxing_profile.get("retired", false):
			continue
		if npc.boxing_profile.get("scheduled_opponent_id", -1) != -1:
			continue
		if npc.boxing_profile.get("current_injuries", []).size() > 0:
			continue
		if str(npc.boxing_profile.get("weight_class", "")) != division:
			continue

		candidates.append(npc)

	if candidates.is_empty():
		return null

	return candidates [randi() % candidates.size()]
func _find_mandatory_opponent(person: Person) -> Person:
	if gs.boxing_mandatory_engine == null:
		return null

	var mandatory = person.boxing_profile.get("mandatory_status", {})
	if mandatory == null:
		return null

	if not bool(mandatory.get("is_mandatory", false)):
		return null

	var division = str(mandatory.get("division", ""))
	var belt = str(mandatory.get("belt", ""))

	if division == "" or belt == "":
		return null

	var key = "%s_%s" % [division, belt]
	if not gs.boxing_mandatory_engine.mandatories.has(key):
		return null

	var data = gs.boxing_mandatory_engine.mandatories [key]
	var challenger_id = int(data.get("challenger_id", -1))
	var champion_id = int(data.get("champion_id", -1))


	if person.id == champion_id:
		var challenger = gs.get_npc_by_id(challenger_id)
		if challenger != null and challenger.alive:
			return challenger


	if person.id == challenger_id:
		var champion = gs.get_npc_by_id(champion_id)
		if champion != null and champion.alive:
			return champion

	return null