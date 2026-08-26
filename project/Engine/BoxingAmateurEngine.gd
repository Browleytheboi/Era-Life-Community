extends Resource
class_name BoxingAmateurEngine

const CONTRACT_SCHEMA:= "eralife.boxing_amateur_engine"
const CONTRACT_VERSION:= 1

var gs
var active_contract: Dictionary = {}
var last_report: Dictionary = {}

func _init(_gs):
	gs = _gs
	set_contract()

func set_contract(contract: Dictionary = {}) -> Dictionary:
	active_contract = _build_default_contract()
	if typeof(contract) == TYPE_DICTIONARY and not contract.is_empty():
		active_contract = _merge_dict(active_contract, contract)

	last_report = {
		"schema": "eralife.boxing_amateur_contract_set_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"contract_id": str(active_contract.get("id", "")),
		"set_at_ms": int(Time.get_ticks_msec())
	}

	return last_report.duplicate(true)

func export_state() -> Dictionary:
	return {
		"schema": "eralife.boxing_amateur_engine_state",
		"version": CONTRACT_VERSION,
		"active_contract": active_contract.duplicate(true),
		"last_report": last_report.duplicate(true),
		"exported_at_ms": int(Time.get_ticks_msec())
	}

func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "BoxingAmateurEngine import data must be a Dictionary."
		}

	var contract_raw: Variant = data.get("active_contract", {})
	if typeof(contract_raw) == TYPE_DICTIONARY and not (contract_raw as Dictionary).is_empty():
		active_contract = _merge_dict(_build_default_contract(), contract_raw as Dictionary)
	else:
		active_contract = _build_default_contract()

	var report_raw: Variant = data.get("last_report", {})
	if typeof(report_raw) == TYPE_DICTIONARY:
		last_report = (report_raw as Dictionary).duplicate(true)

	return {
		"success": true,
		"contract_id": str(active_contract.get("id", "")),
		"imported_at_ms": int(Time.get_ticks_msec())
	}

func yearly_tick(_payload:= {}) -> void:
	if not gs.era_engine.supports_world_title_boxing():
		return

	if gs.boxing_engine != null:
		gs.boxing_engine.sync_boxing_division_factions()

	for npc in gs.npcs:
		if npc == null or not npc.alive:
			continue
		if npc == gs.player:
			continue
		if npc.age < 14 or npc.age > 22:
			continue
		if npc.boxing_profile.get("turned_pro", false):
			continue

		var just_started_amateur:= false
		var should_seed_amateur: bool = false

		if not npc.boxing_profile.get("is_boxer", false):
			if gs.boxing_engine != null:
				should_seed_amateur = gs.boxing_engine.should_seed_npc_into_boxing_amateurs(npc)
			else:
				should_seed_amateur = randi() % 100 < 2

			if should_seed_amateur:
				_start_amateur_boxing(npc)
				just_started_amateur = true

		if just_started_amateur:
			continue

		if npc.boxing_profile.get("amateur_circuit", {}).get("is_amateur", false):
			_run_amateur_year(npc)

func _start_amateur_boxing(npc: Person) -> void:
	enter_amateur_circuit(npc, "npc_seed")
func enter_amateur_circuit(npc: Person, source: String = "manual") -> Dictionary:
	if gs == null:
		return {
			"success": false,
			"text": "❌ GameState unavailable."
		}

	if npc == null:
		return {
			"success": false,
			"text": "❌ No amateur boxer selected."
		}

	if gs.era_engine == null or not gs.era_engine.supports_world_title_boxing():
		return {
			"success": false,
			"text": "\n❌\n Boxing is not available in this era."
		}

	if bool(npc.boxing_profile.get("turned_pro", false)):
		return {
			"success": false,
			"text": "\n❌\n I am already a professional boxer."
		}

	if not bool(npc.boxing_profile.get("is_boxer", false)):
		gs.boxing_fighter_engine.initialize_fighter(npc)

	_normalize_amateur_profile(npc)

	npc.boxing_profile ["turned_pro"] = false
	npc.boxing_profile ["amateur_circuit"] ["is_amateur"] = true
	npc.boxing_profile ["record"] = {
		"wins": 0,
		"losses": 0,
		"draws": 0,
		"kos": 0
	}

	var division: String = str(npc.boxing_profile.get("weight_class", ""))
	var txt: String = "\n🥊\n %s started an amateur boxing career at age %d in the %s division." % [
		npc.first_name,
		npc.age,
		division
	]

	if source == "player_contract":
		txt = "\n🥇\n I entered the amateur boxing circuit."

	if gs.narrative_engine != null:
		gs.narrative_engine.log_event(npc, { "type": "text", "text": txt})

	if gs.has_method("push_world_feed"):
		gs.push_world_feed(txt, {
			"npc_id": int(npc.id),
			"category": "boxing",
			"event_name": "boxing_started",
			"source": "boxing_amateur_engine",
			"contract_source": source
		})

	if gs.event_bus != null:
		gs.event_bus.emit(ActionEventTypes.BOXING_MEDIA_NARRATIVE, {
			"npc_id": int(npc.id),
			"text": txt,
			"event_name": "boxing_started",
			"category": "boxing",
			"source": "boxing_amateur_engine",
			"contract_source": source
		})

	return {
		"success": true,
		"text": txt,
		"source": source
	}

func _normalize_amateur_profile(npc: Person) -> void:
	if npc == null:
		return

	if not npc.boxing_profile.has("amateur_record") or typeof(npc.boxing_profile.get("amateur_record", {})) != TYPE_DICTIONARY:
		npc.boxing_profile ["amateur_record"] = {
			"wins": 0,
			"losses": 0,
			"draws": 0,
			"kos": 0
		}

	if not npc.boxing_profile.has("amateur_circuit") or typeof(npc.boxing_profile.get("amateur_circuit", {})) != TYPE_DICTIONARY:
		npc.boxing_profile ["amateur_circuit"] = {}

	var circuit: Dictionary = npc.boxing_profile ["amateur_circuit"]
	if not circuit.has("is_amateur"):
		circuit ["is_amateur"] = false
	if not circuit.has("tournaments_won"):
		circuit ["tournaments_won"] = 0
	if not circuit.has("olympic_medals"):
		circuit ["olympic_medals"] = 0
	if not circuit.has("olympic_gold"):
		circuit ["olympic_gold"] = false

	npc.boxing_profile ["amateur_circuit"] = circuit

func _build_default_contract() -> Dictionary:
	return {
		"schema": CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": "default_boxing_amateur_engine_contract",
		"policies": {
			"unknown_fields": "preserve",
			"backwards_compatible": true,
			"minimum_amateur_age": 14,
			"maximum_amateur_age": 22,
			"pro_conversion_policy": "yearly_roll",
			"records": {
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

func _run_amateur_year(npc: Person) -> void:
	if npc == null:
		return

	_normalize_amateur_profile(npc)

	var amat: Dictionary = npc.boxing_profile ["amateur_record"]
	amat ["wins"] = int(amat.get("wins", 0)) + randi_range(0, 4)
	amat ["losses"] = int(amat.get("losses", 0)) + randi_range(0, 2)
	amat ["draws"] = int(amat.get("draws", 0)) + (1 if randi() % 100 < 5 else 0)
	amat ["kos"] = int(amat.get("kos", 0)) + randi_range(0, 2)

	var circuit: Dictionary = npc.boxing_profile ["amateur_circuit"]
	circuit ["tier"] = "youth_amateur" if int(npc.age) < 18 else "adult_amateur"
	circuit ["may_turn_pro"] = int(npc.age) >= 18
	circuit ["auto_turn_pro"] = false
	npc.boxing_profile ["amateur_circuit"] = circuit

	if randi() % 100 < 12:
		npc.boxing_profile ["amateur_circuit"] ["tournaments_won"] = int(npc.boxing_profile ["amateur_circuit"].get("tournaments_won", 0)) + 1
		var txt: String = "🥇 %s won a major %s boxing tournament." % [
			npc.first_name,
			"youth amateur" if int(npc.age) < 18 else "adult amateur"
		]

		if gs.event_bus != null:
			gs.event_bus.emit(ActionEventTypes.BOXING_AMATEUR_TOURNAMENT_WON, {
				"npc_id": npc.id,
				"text": txt,
				"contract_source": "boxing_amateur_engine"
			})

	if _is_olympic_year() and npc.age >= 18 and npc.age <= 30 and randi() % 100 < 8:
		npc.boxing_profile ["amateur_circuit"] ["olympic_medals"] = int(npc.boxing_profile ["amateur_circuit"].get("olympic_medals", 0)) + 1
		if randi() % 100 < 35:
			npc.boxing_profile ["amateur_circuit"] ["olympic_gold"] = true

		var txt2: String = "🥇 %s won an Olympic boxing medal." % npc.first_name

		if gs.event_bus != null:
			gs.event_bus.emit(ActionEventTypes.BOXING_OLYMPIC_MEDAL, {
				"npc_id": npc.id,
				"text": txt2,
				"contract_source": "boxing_amateur_engine"
			})

func _is_olympic_year() -> bool:
	return gs.year % 4 == 0