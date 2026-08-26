extends Resource
class_name BoxingMediaEngine

const CONTRACT_SCHEMA:= "eralife.boxing_media_engine"
const CONTRACT_VERSION:= 1

var gs
var media_state:= {}
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
		"schema": "eralife.boxing_media_contract_set_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"contract_id": str(active_contract.get("id", "")),
		"set_at_ms": int(Time.get_ticks_msec())
	}

	return last_report.duplicate(true)

func export_state() -> Dictionary:
	return {
		"schema": "eralife.boxing_media_engine_state",
		"version": CONTRACT_VERSION,
		"active_contract": active_contract.duplicate(true),
		"media_state": media_state.duplicate(true),
		"last_report": last_report.duplicate(true),
		"exported_at_ms": int(Time.get_ticks_msec())
	}

func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "BoxingMediaEngine import data must be a Dictionary."
		}

	var contract_raw: Variant = data.get("active_contract", {})
	if typeof(contract_raw) == TYPE_DICTIONARY and not (contract_raw as Dictionary).is_empty():
		active_contract = _merge_dict(_build_default_contract(), contract_raw as Dictionary)
	else:
		active_contract = _build_default_contract()

	var media_raw: Variant = data.get("media_state", {})
	if typeof(media_raw) == TYPE_DICTIONARY:
		media_state = (media_raw as Dictionary).duplicate(true)
	else:
		media_state = {}

	var report_raw: Variant = data.get("last_report", {})
	if typeof(report_raw) == TYPE_DICTIONARY:
		last_report = (report_raw as Dictionary).duplicate(true)

	return {
		"success": true,
		"media_state_count": media_state.size(),
		"imported_at_ms": int(Time.get_ticks_msec())
	}

func yearly_tick(_payload:= {}) -> void:
	for npc in gs.npcs:
		if npc == null or not npc.alive:
			continue
		if not npc.boxing_profile.get("is_boxer", false):
			continue
		if npc.boxing_profile.get("retired", false):
			continue

		if randi() % 100 < 20:
			_emit_narrative(npc)

func on_fight_completed(payload: Dictionary) -> void:
	var winner = gs.get_npc_by_id(int(payload.get("winner_id", -1)))
	var loser = gs.get_npc_by_id(int(payload.get("loser_id", -1)))
	if winner == null or loser == null:
		return

	var winner_rank: int = int(winner.boxing_profile.get("division_rank", 99))
	var loser_rank: int = int(loser.boxing_profile.get("division_rank", 99))
	var division: String = str(payload.get("division", winner.boxing_profile.get("weight_class", "")))
	var result_type: String = str(payload.get("result_type", "Decision"))
	var title_fight: bool = bool(payload.get("title_fight", false))
	var lineal_fight: bool = bool(payload.get("lineal_fight", false))
	var is_player_fight: bool = gs.player != null and (int(gs.player.id) in [int(winner.id), int(loser.id)])

	var should_feed: bool = false
	if title_fight or lineal_fight:
		should_feed = true
	elif is_player_fight:
		should_feed = true
	elif winner_rank > 0 and loser_rank > 0 and winner_rank - loser_rank >= 5:
		should_feed = true
	elif winner_rank <= 5 or loser_rank <= 5:
		should_feed = randi() % 100 < 55
	else:
		should_feed = randi() % 100 < 16

	if should_feed:
		var stakes: String = ""
		var belts: Array = payload.get("belts", []) if typeof(payload.get("belts", [])) == TYPE_ARRAY else []
		if not belts.is_empty():
			stakes = " with %s at stake" % ", ".join(belts)
		elif lineal_fight:
			stakes = " for the Ring Magazine lineal title"

		var txt:= "\n🥊\n %s %s defeated %s %s by %s in the %s division%s." % [
			winner.first_name,
			winner.last_name,
			loser.first_name,
			loser.last_name,
			result_type,
			division,
			stakes
		]

		if gs.has_method("push_world_feed"):
			gs.push_world_feed(txt, {
				"npc_id": int(winner.id),
				"target_id": int(loser.id),
				"category": "boxing",
				"event_name": "boxing_fight_result",
				"source": "boxing_media_engine",
				"title_fight": title_fight,
				"lineal_fight": lineal_fight
			})

		if gs.event_bus != null:
			gs.event_bus.emit(ActionEventTypes.BOXING_MEDIA_NARRATIVE, {
				"npc_id": int(winner.id),
				"target_id": int(loser.id),
				"text": txt,
				"event_name": "boxing_fight_result",
				"category": "boxing",
				"source": "boxing_media_engine"
			})

	var winner_key: String = str(int(winner.id))
	var row: Dictionary = media_state.get(winner_key, {}) if typeof(media_state.get(winner_key, {})) == TYPE_DICTIONARY else {}
	row ["last_fight_result_text"] = "%s beat %s by %s" % [winner.first_name, loser.first_name, result_type]
	row ["last_fight_year"] = int(gs.year)
	row ["fight_mentions"] = int(row.get("fight_mentions", 0)) + 1
	media_state [winner_key] = row

func on_title_won(payload: Dictionary) -> void:
	var npc = gs.get_npc_by_id(int(payload.get("npc_id", -1)))
	if npc == null:
		return

	npc.boxing_profile ["media_heat"] = clamp(int(npc.boxing_profile.get("media_heat", 0)) + 20, 0, 100)

func _emit_narrative(npc: Person) -> void:
	if npc == null:
		return

	var narratives: Array = _build_contract_media_narratives(npc)

	if narratives.is_empty():
		narratives.append("🥊 %s is quietly building momentum in the division." % npc.first_name)

	var txt: String = str(narratives [randi() % narratives.size()])

	if gs.event_bus != null:
		gs.event_bus.emit(ActionEventTypes.BOXING_MEDIA_NARRATIVE, {
			"npc_id": int(npc.id),
			"text": txt,
			"source": "boxing_media_engine",
			"contract_id": str(active_contract.get("id", ""))
		})

	var npc_key: String = str(int(npc.id))
	var row: Dictionary = media_state.get(npc_key, {}) if typeof(media_state.get(npc_key, {})) == TYPE_DICTIONARY else {}
	row ["last_media_text"] = txt
	row ["last_media_year"] = int(gs.year if gs != null else 0)
	row ["media_mentions"] = int(row.get("media_mentions", 0)) + 1
	media_state [npc_key] = row

func _build_contract_media_narratives(npc: Person) -> Array:
	var narratives: Array = []
	var templates: Dictionary = active_contract.get("narrative_templates", {}) if typeof(active_contract.get("narrative_templates", {})) == TYPE_DICTIONARY else {}

	if npc.boxing_profile.get("rivalries", []).size() > 0:
		narratives.append(str(templates.get("rivalry", "🥊 Media outlets say %s is the center of the sport's hottest rivalry.")) % npc.first_name)

	if int(npc.boxing_profile.get("trash_talk_reputation", 0)) >= 3:
		narratives.append(str(templates.get("trash_talk", "🎤 %s is becoming known as one of boxing's loudest personalities.")) % npc.first_name)

	if int(npc.boxing_profile.get("wear", 0)) >= 50:
		narratives.append(str(templates.get("damage", "🩹 Analysts wonder whether %s has taken too much damage.")) % npc.first_name)

	if npc.boxing_profile.get("belts", []).size() >= 2:
		narratives.append(str(templates.get("pound_for_pound", "🌟 %s is now being discussed as a possible future pound-for-pound star.")) % npc.first_name)

	if narratives.is_empty():
		narratives.append(str(templates.get("default", "🥊 %s is quietly building momentum in the division.")) % npc.first_name)

	return narratives

func _build_default_contract() -> Dictionary:
	return {
		"schema": CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": "default_boxing_media_engine_contract",
		"policies": {
			"unknown_fields": "preserve",
			"backwards_compatible": true,
			"media_generation": "contract_template_driven",
		},
		"narrative_templates": {
			"rivalry": "🥊 Media outlets say %s is the center of the sport's hottest rivalry.",
			"trash_talk": "🎤 %s is becoming known as one of boxing's loudest personalities.",
			"damage": "🩹 Analysts wonder whether %s has taken too much damage.",
			"pound_for_pound": "🌟 %s is now being discussed as a possible future pound-for-pound star.",
			"default": "🥊 %s is quietly building momentum in the division."
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