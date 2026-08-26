extends Resource
class_name BoxingTitleEngine

const CONTRACT_SCHEMA:= "eralife.boxing_title_engine"
const CONTRACT_VERSION:= 1

var gs
var champions:= {}
var lineages:= {}
var active_contract: Dictionary = {}
var last_report: Dictionary = {}

const SANCTIONING_BODIES = ["WBA", "WBC", "IBF", "WBO"]
const LINEAL_BELT:= "Ring Magazine"
const BELT_BODIES = ["WBA", "WBC", "IBF", "WBO", "Ring Magazine"]

func _init(_gs):
	gs = _gs
	champions = _default_champions()
	set_contract()

func set_contract(contract: Dictionary = {}) -> Dictionary:
	active_contract = _build_default_contract()
	if typeof(contract) == TYPE_DICTIONARY and not contract.is_empty():
		active_contract = _merge_dict(active_contract, contract)

	last_report = {
		"schema": "eralife.boxing_title_contract_set_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"contract_id": str(active_contract.get("id", "")),
		"set_at_ms": int(Time.get_ticks_msec())
	}

	return last_report.duplicate(true)

func export_state() -> Dictionary:
	return {
		"schema": "eralife.boxing_title_engine_state",
		"version": CONTRACT_VERSION,
		"active_contract": active_contract.duplicate(true),
		"champions": champions.duplicate(true),
		"lineages": lineages.duplicate(true),
		"last_report": last_report.duplicate(true),
		"exported_at_ms": int(Time.get_ticks_msec())
	}

func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "BoxingTitleEngine import data must be a Dictionary."
		}

	var contract_raw: Variant = data.get("active_contract", {})
	if typeof(contract_raw) == TYPE_DICTIONARY and not (contract_raw as Dictionary).is_empty():
		active_contract = _merge_dict(_build_default_contract(), contract_raw as Dictionary)
	else:
		active_contract = _build_default_contract()

	var champions_raw: Variant = data.get("champions", data)
	if typeof(champions_raw) == TYPE_DICTIONARY:
		champions = _normalize_champions(champions_raw as Dictionary)
	else:
		champions = _default_champions()

	var lineages_raw: Variant = data.get("lineages", {})
	if typeof(lineages_raw) == TYPE_DICTIONARY:
		lineages = (lineages_raw as Dictionary).duplicate(true)
	else:
		lineages = {}

	var report_raw: Variant = data.get("last_report", {})
	if typeof(report_raw) == TYPE_DICTIONARY:
		last_report = (report_raw as Dictionary).duplicate(true)

	return {
		"success": true,
		"champion_divisions": champions.size(),
		"lineage_count": lineages.size(),
		"imported_at_ms": int(Time.get_ticks_msec())
	}

func _normalize_champions(raw: Dictionary) -> Dictionary:
	var out: Dictionary = _default_champions()

	for division in raw.keys():
		var row_raw: Variant = raw.get(division, {})
		if typeof(row_raw) != TYPE_DICTIONARY:
			continue

		if not out.has(str(division)):
			out [str(division)] = {}

		var row: Dictionary = row_raw
		for belt in BELT_BODIES:
			out [str(division)] [belt] = int(row.get(belt, out [str(division)].get(belt, -1)))

	return out
func _build_default_contract() -> Dictionary:
	return {
		"schema": CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": "default_boxing_title_engine_contract",
		"policies": {
			"unknown_fields": "preserve",
			"backwards_compatible": true,
			"title_bodies": SANCTIONING_BODIES.duplicate(true),
			"lineal_belt": LINEAL_BELT,
			"lineage_mode": "preserve_historical_holder_ids",
			"vacant_holder_id": -1,
			"undisputed_requires": SANCTIONING_BODIES.duplicate(true),
			"mandatory_bodies": SANCTIONING_BODIES.duplicate(true)
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

func _default_champions() -> Dictionary:
	var out:= {}
	var divisions = [
		"Flyweight", "Bantamweight", "Featherweight", "Lightweight",
		"Welterweight", "Middleweight", "Light Heavyweight", "Heavyweight"
	]

	for d in divisions:
		out [d] = {
			"WBA": -1,
			"WBC": -1,
			"IBF": -1,
			"WBO": -1,
			"Ring Magazine": -1
		}

	return out
func _gender_division_for_person(person: Person) -> String:
	if person == null:
		return "Male"

	var direct: String = str(person.boxing_profile.get("boxing_gender_division", "")).strip_edges()
	if direct in ["Male", "Female"]:
		return direct

	var gender_text: String = str(person.gender if "gender" in person else "").strip_edges().to_lower()
	return "Female" if gender_text in ["female", "woman", "girl", "f"] else "Male"


func _title_bucket_key(division: String, gender_division: String = "") -> String:
	var clean_division: String = str(division).strip_edges()
	var clean_gender: String = str(gender_division).strip_edges()
	if clean_gender == "":
		clean_gender = "Male"
	return "%s:%s" % [clean_gender, clean_division]


func _ensure_title_bucket(division: String, gender_division: String = "") -> String:
	var bucket_key: String = _title_bucket_key(division, gender_division)
	if not champions.has(bucket_key):
		champions [bucket_key] = {
			"WBA": -1,
			"WBC": -1,
			"IBF": -1,
			"WBO": -1,
			"Ring Magazine": -1
		}
	return bucket_key
func on_fight_completed(payload: Dictionary) -> void:
	var title_fight: bool = bool(payload.get("title_fight", false))
	var lineal_fight: bool = bool(payload.get("lineal_fight", false))
	if not title_fight and not lineal_fight:
		return

	var winner_id: int = int(payload.get("winner_id", -1))
	var loser_id: int = int(payload.get("loser_id", -1))
	var division: String = str(payload.get("division", "")).strip_edges()
	if winner_id <= 0 or division == "":
		return

	var winner: Person = gs.get_npc_by_id(winner_id)
	var loser: Person = gs.get_npc_by_id(loser_id)
	var gender_division: String = str(payload.get("gender_division", "")).strip_edges()
	if gender_division == "":
		gender_division = _gender_division_for_person(winner)

	var bucket_key: String = _ensure_title_bucket(division, gender_division)

	var belts: Array = payload.get("belts", []) if typeof(payload.get("belts", [])) == TYPE_ARRAY else []
	if belts.is_empty() and str(payload.get("belt", "")) != "":
		belts.append(str(payload.get("belt", "")))
	if lineal_fight and LINEAL_BELT not in belts:
		belts.append(LINEAL_BELT)

	for belt in belts:
		var clean_belt: String = str(belt).strip_edges()
		if clean_belt == "":
			continue
		if clean_belt not in BELT_BODIES:
			continue
		_transfer_belt(clean_belt, bucket_key, winner, loser, payload)

	if winner != null:
		_sync_undisputed_state(winner, bucket_key, payload)
	if loser != null:
		_sync_undisputed_state(loser, bucket_key, payload)
func is_undisputed_champion(person: Person, division: String) -> bool:
	if person == null:
		return false

	var clean_division: String = str(division).strip_edges()
	var bucket_key: String = clean_division
	if clean_division.find(":") < 0:
		bucket_key = _title_bucket_key(clean_division, _gender_division_for_person(person))

	if not champions.has(bucket_key):
		return false

	for belt in SANCTIONING_BODIES:
		if int(champions [bucket_key].get(belt, -1)) != int(person.id):
			return false

	return true

func would_create_undisputed(a: Person, b: Person, belts_at_stake: Array, division: String) -> bool:
	if a == null or b == null:
		return false
	if not champions.has(division):
		return false

	for fighter in [a, b]:
		var owned: int = 0
		for belt in SANCTIONING_BODIES:
			if int(champions [division].get(belt, -1)) == int(fighter.id) or belt in belts_at_stake:
				owned += 1
		if owned >= SANCTIONING_BODIES.size():
			return true

	return false

func is_lineal_fight(a: Person, b: Person, division: String) -> bool:
	if a == null or b == null:
		return false

	var gender_a: String = _gender_division_for_person(a)
	var gender_b: String = _gender_division_for_person(b)
	if gender_a != gender_b:
		return false

	var bucket_key: String = _title_bucket_key(division, gender_a)
	if not champions.has(bucket_key):
		return false

	var policies: Dictionary = active_contract.get("policies", {}) if typeof(active_contract.get("policies", {})) == TYPE_DICTIONARY else {}
	var lineal_belt: String = str(policies.get("lineal_belt", LINEAL_BELT))
	var lineal_id: int = int(champions [bucket_key].get(lineal_belt, -1))

	if lineal_id in [int(a.id), int(b.id)]:
		return true

	var rank_a: int = int(a.boxing_profile.get("division_rank", 99))
	var rank_b: int = int(b.boxing_profile.get("division_rank", 99))
	return lineal_id == -1 and min(rank_a, rank_b) <= 2 and max(rank_a, rank_b) <= 3

func strip_title_for_missed_mandatory(champion: Person, division: String, belt: String, reason: String = "missed_mandatory") -> Dictionary:
	if champion == null:
		return {}
	if not champions.has(division):
		return {}

	var clean_belt: String = str(belt).strip_edges()
	if clean_belt == "" or clean_belt == LINEAL_BELT:
		return {}

	if int(champions [division].get(clean_belt, -1)) != int(champion.id):
		return {}

	champions [division] [clean_belt] = -1

	var belts: Array = champion.boxing_profile.get("belts", []) if typeof(champion.boxing_profile.get("belts", [])) == TYPE_ARRAY else []
	belts.erase("%s %s" % [clean_belt, division])
	champion.boxing_profile ["belts"] = belts
	_sync_undisputed_state(champion, division, {})

	var txt:= "\n📣\n %s was stripped of the %s %s title for %s." % [
		champion.first_name,
		clean_belt,
		division,
		reason.replace("_", " ")
	]

	if gs.event_bus != null:
		gs.event_bus.emit(ActionEventTypes.BOXING_MEDIA_NARRATIVE, {
			"npc_id": int(champion.id),
			"text": txt,
			"event_name": "boxing_title_stripped",
			"category": "boxing",
			"source": "boxing_title_engine"
		})

	return {
		"success": true,
		"text": txt,
		"belt": clean_belt,
		"division": division
	}

func _transfer_belt(belt: String, division: String, winner: Person, loser: Person, payload: Dictionary = {}) -> void:
	if winner == null:
		return

	var previous_holder: int = int(champions [division].get(belt, -1))
	champions [division] [belt] = int(winner.id)

	var winner_belts: Array = winner.boxing_profile.get("belts", []) if typeof(winner.boxing_profile.get("belts", [])) == TYPE_ARRAY else []
	var belt_name: String = "%s %s" % [belt, division]
	if belt_name not in winner_belts:
		winner_belts.append(belt_name)
	winner.boxing_profile ["belts"] = winner_belts

	if loser != null:
		var loser_belts: Array = loser.boxing_profile.get("belts", []) if typeof(loser.boxing_profile.get("belts", [])) == TYPE_ARRAY else []
		loser_belts.erase(belt_name)
		loser.boxing_profile ["belts"] = loser_belts

	lineages ["%s_%s" % [division, belt]] = {
		"holder_id": int(winner.id),
		"previous_holder_id": previous_holder,
		"won_year": int(gs.year if gs != null else 0),
		"result_type": str(payload.get("result_type", "")),
		"lineal": belt == LINEAL_BELT
	}

	var txt:= "\n🏆\n %s %s won the %s %s title." % [
		winner.first_name,
		winner.last_name,
		belt,
		division
	]

	if gs.event_bus != null:
		gs.event_bus.emit(ActionEventTypes.BOXING_TITLE_WON, {
			"npc_id": int(winner.id),
			"text": txt,
			"belt": belt,
			"division": division,
			"lineal": belt == LINEAL_BELT
		})

func _sync_undisputed_state(person: Person, division: String, _payload: Dictionary = {}) -> void:
	if person == null:
		return

	var undisputed: bool = is_undisputed_champion(person, division)
	var divisions: Array = person.boxing_profile.get("undisputed_divisions", []) if typeof(person.boxing_profile.get("undisputed_divisions", [])) == TYPE_ARRAY else []

	if undisputed:
		if division not in divisions:
			divisions.append(division)

		person.boxing_profile ["undisputed"] = true
		person.boxing_profile ["undisputed_divisions"] = divisions

		var announced_key: String = "undisputed_announced_%s" % division
		if not bool(person.boxing_profile.get(announced_key, false)):
			person.boxing_profile [announced_key] = true
			var txt:= "\n👑🥊\n %s %s became the undisputed %s champion." % [
				person.first_name,
				person.last_name,
				division
			]
			if gs.event_bus != null:
				gs.event_bus.emit(ActionEventTypes.BOXING_TITLE_WON, {
					"npc_id": int(person.id),
					"text": txt,
					"division": division,
					"undisputed": true,
					"belts": SANCTIONING_BODIES.duplicate(true)
				})
	else:
		divisions.erase(division)
		person.boxing_profile ["undisputed_divisions"] = divisions
		person.boxing_profile ["undisputed"] = not divisions.is_empty()