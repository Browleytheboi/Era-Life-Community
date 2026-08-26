extends Resource
class_name BoxingContractEngine

const CONTRACT_SCHEMA:= "eralife.boxing_contract_engine"
const CONTRACT_VERSION:= 1
const DEFAULT_MAX_FIGHTS_PER_YEAR:= 4

var gs
var active_contract: Dictionary = {}
var runtime_state: Dictionary = {}
var command_log: Array = []
var last_report: Dictionary = {}

func _init(_gs = null, contract: Dictionary = {}) -> void:
	gs = _gs
	set_contract(contract)

func set_contract(contract: Dictionary = {}) -> Dictionary:
	active_contract = _build_default_contract()
	if typeof(contract) == TYPE_DICTIONARY and not contract.is_empty():
		active_contract = _merge_dict(active_contract, contract)

	_apply_contracts_to_boxing_engines()

	last_report = {
		"schema": "eralife.boxing_contract_set_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"contract_id": str(active_contract.get("id", "")),
		"engine_count": active_contract.get("engines", {}).size() if typeof(active_contract.get("engines", {})) == TYPE_DICTIONARY else 0,
		"set_at_ms": int(Time.get_ticks_msec())
	}

	return last_report.duplicate(true)

func export_state() -> Dictionary:
	return {
		"schema": "eralife.boxing_contract_engine_state",
		"version": CONTRACT_VERSION,
		"active_contract": active_contract.duplicate(true),
		"runtime_state": runtime_state.duplicate(true),
		"command_log": command_log.duplicate(true),
		"last_report": last_report.duplicate(true),
		"exported_at_ms": int(Time.get_ticks_msec())
	}

func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "BoxingContractEngine import data must be a Dictionary."
		}

	var contract_raw: Variant = data.get("active_contract", {})
	if typeof(contract_raw) == TYPE_DICTIONARY and not (contract_raw as Dictionary).is_empty():
		active_contract = _merge_dict(_build_default_contract(), contract_raw as Dictionary)
	else:
		active_contract = _build_default_contract()

	var runtime_raw: Variant = data.get("runtime_state", {})
	if typeof(runtime_raw) == TYPE_DICTIONARY:
		runtime_state = (runtime_raw as Dictionary).duplicate(true)
	else:
		runtime_state = {}

	var command_raw: Variant = data.get("command_log", [])
	if typeof(command_raw) == TYPE_ARRAY:
		command_log = (command_raw as Array).duplicate(true)
	else:
		command_log = []

	var report_raw: Variant = data.get("last_report", {})
	if typeof(report_raw) == TYPE_DICTIONARY:
		last_report = (report_raw as Dictionary).duplicate(true)
	else:
		last_report = {}

	_apply_contracts_to_boxing_engines()

	return {
		"success": true,
		"contract_id": str(active_contract.get("id", "")),
		"command_count": command_log.size(),
		"imported_at_ms": int(Time.get_ticks_msec())
	}

func export_debug_snapshot() -> Dictionary:
	return {
		"schema": "eralife.boxing_contract_debug_snapshot",
		"version": CONTRACT_VERSION,
		"contract_id": str(active_contract.get("id", "")),
		"runtime_state": runtime_state.duplicate(true),
		"command_log_count": command_log.size(),
		"last_report": last_report.duplicate(true)
	}
func run_action_label(action_label: String, person: Person = null, args: Dictionary = {}) -> Dictionary:
	var clean_label: String = str(action_label).strip_edges()
	var action_map:= {
		"Begin Boxing Career": "boxing.career.start",
		"Begin boxing career": "boxing.career.start",
		"Start Boxing": "boxing.career.start",
		"Start Boxing Career": "boxing.career.start",
		"Boxing": "boxing.hub.view",
		"Boxing Hub": "boxing.hub.view",
		"Open Boxing Hub": "boxing.hub.view",
		"Rankings": "boxing.rankings.view",
		"View Rankings": "boxing.rankings.view",
		"Top 10 Pound-for-Pound": "boxing.rankings.pfp",
		"Award Candidates": "boxing.awards.candidates",
		"Award Winners": "boxing.awards.winners",
		"My Fight History": "boxing.history.mine",
		"Retired Boxers": "boxing.legacy.retired_boxers",
		"Retire": "boxing.career.retire",
		"Train Boxing": "boxing.training.personal",
		"Boxing Sparring": "boxing.training.sparring",
		"Book Boxing Match": "boxing.fight.book",
		"Confirm Boxing Fight": "boxing.fight.confirm",
		"Cancel Boxing Fight": "boxing.fight.cancel",
		"Opponent Preview": "boxing.fight.preview",
		"View Boxing Record": "boxing.record.view",
		"View Boxing Rivalries": "boxing.rivalries.view",
		"Call Out Opponent": "boxing.rivalries.callout",
		"Change Weight Class": "boxing.weight.change_next",
		"Review Last Fight Log": "boxing.history.last_log",
		"Enter Amateur Tournament": "boxing.amateur.enter",
		"Fight in the Golden Gloves": "boxing.amateur.enter",
		"Pound-for-Pound Rankings": "boxing.rankings.pfp",
		"Fight Economy": "boxing.economy.view",
		"+ Find a Gym": "boxing.gym.find",
		"Find a Gym": "boxing.gym.find",
		"Open Gym Hub": "boxing.gym.open",
		"Promotions": "boxing.promotions.view"
	}
	var command_id: String = str(action_map.get(clean_label, "")).strip_edges()
	if command_id == "":
		return {
			"success": false,
			"text": "\n\n Boxing action is not registered in the boxing contract.",
			"action_label": clean_label
		}
	return run_command(command_id, person, args)

func run_command(command_id: String, person: Person = null, args: Dictionary = {}) -> Dictionary:
	var clean_command: String = str(command_id).strip_edges().to_lower()
	var actor: Person = person
	if actor == null and gs != null:
		actor = gs.player

	var resolution: Dictionary = resolve_command(clean_command)
	if not bool(resolution.get("allowed", false)):
		return {
			"success": false,
			"text": "❌ Boxing contract rejected this command.",
			"command_id": clean_command,
			"resolution": resolution.duplicate(true)
		}

	if actor == null:
		return {
			"success": false,
			"text": "❌ No boxer was available for this boxing command.",
			"command_id": clean_command
		}

	_normalize_fighter_profile(actor)

	var result: Dictionary = {}
	match clean_command:
		"boxing.hub.view":
			result = build_hub_payload(actor, str(args.get("section", "fight")))
		"boxing.career.start":
			result = _command_start_career(actor, args)
		"boxing.training.personal":
			result = _command_personal_training(actor, args)
		"boxing.training.sparring":
			result = _command_sparring(actor, args)
		"boxing.fight.book":
			result = _command_book_fight(actor, args)
		"boxing.fight.confirm":
			result = _command_confirm_fight(actor, args)
		"boxing.fight.cancel":
			result = _command_cancel_fight(actor, args)
		"boxing.fight.preview":
			result = _command_opponent_preview(actor, args)
		"boxing.rankings.pfp":
			result = _command_pound_for_pound(actor, args)
		"boxing.economy.view":
			result = _command_fight_economy(actor, args)
		"boxing.promotions.view":
			result = build_hub_payload(actor, "promotions")
		"boxing.promotion.sign":
			result = _command_sign_promotion(actor, args)
		"boxing.gym.find":
			result = build_hub_payload(actor, "gym:find")
		"boxing.gym.join":
			result = _command_join_gym(actor, args)
		"boxing.gym.open":
			result = _command_open_gym(actor, args)
		"boxing.gym.tab":
			result = _command_open_gym(actor, args)
		"boxing.record.view":
			result = _command_view_record(actor, args)
		"boxing.rivalries.view":
			result = _command_view_rivalries(actor, args)
		"boxing.rivalries.callout":
			result = _command_callout(actor, args)
		"boxing.weight.change_next":
			result = _command_change_next_weight(actor, args)
		"boxing.history.last_log":
			result = _command_last_fight_log(actor, args)
		"boxing.amateur.enter":
			result = _command_enter_amateur(actor, args)
		"boxing.rankings.view":
			result = build_hub_payload(actor, str(args.get("section", "rankings")))
		"boxing.awards.candidates":
			result = build_hub_payload(actor, "awards:candidates")
		"boxing.awards.winners":
			result = build_hub_payload(actor, "awards:winners")
		"boxing.growth.upgrade":
			result = _command_upgrade_growth_skill(actor, args)
		"boxing.history.mine":
			result = build_hub_payload(actor, "history")
		"boxing.legacy.retired_boxers":
			result = build_hub_payload(actor, "legacy:retired")
		"boxing.career.retire":
			result = _command_retire(actor, args)
		_:
			result = {
				"success": false,
				"text": "❌ Boxing command has a contract but no runtime adapter yet.",
				"command_id": clean_command
			}

	_record_command(clean_command, actor, args, result)
	return result

func resolve_command(command_id: String) -> Dictionary:
	var clean_command: String = str(command_id).strip_edges().to_lower()
	var command_contracts: Dictionary = active_contract.get("commands", {}) if typeof(active_contract.get("commands", {})) == TYPE_DICTIONARY else {}
	var command_contract: Dictionary = command_contracts.get(clean_command, {}) if typeof(command_contracts.get(clean_command, {})) == TYPE_DICTIONARY else {}

	if clean_command == "":
		return {
			"allowed": false,
			"reason": "missing_command_id"
		}

	if command_contract.is_empty():
		return {
			"allowed": bool(active_contract.get("allow_unknown_future_commands", true)),
			"reason": "future_command_ack",
			"command_id": clean_command,
			"native_adapter_available": false,
			"contract": {
				"schema": "eralife.future_boxing_command_contract",
				"version": CONTRACT_VERSION,
				"command_id": clean_command,
				"execution_policy": "queued_ack_until_adapter_exists",
				"unknown_fields": "preserve"
			}
		}

	return {
		"allowed": true,
		"reason": "registered_contract",
		"command_id": clean_command,
		"native_adapter_available": bool(command_contract.get("native_adapter_available", false)),
		"contract": command_contract.duplicate(true)
	}

func build_hub_payload(person: Person = null, selected_section: String = "fight") -> Dictionary:
	var actor: Person = person
	if actor == null and gs != null:
		actor = gs.player

	if actor == null:
		return {
			"success": false,
			"text": "No boxer selected.",
			"sections": []
		}

	_normalize_fighter_profile(actor)
	_ensure_boxing_growth_profile(actor)

	var is_boxer: bool = bool(actor.boxing_profile.get("is_boxer", false))
	var is_pro: bool = bool(actor.boxing_profile.get("turned_pro", false))
	var amateur_circuit: Dictionary = actor.boxing_profile.get("amateur_circuit", {}) if typeof(actor.boxing_profile.get("amateur_circuit", {})) == TYPE_DICTIONARY else {}
	var is_amateur: bool = bool(amateur_circuit.get("is_amateur", false))
	var retired: bool = bool(actor.boxing_profile.get("retired", false))
	var division: String = str(actor.boxing_profile.get("weight_class", "Unassigned"))
	var career_stage: String = "Retired" if retired else ("Professional" if is_pro else ("Youth Amateur" if int(actor.age) < 18 else ("Adult Amateur" if is_amateur else "Unlicensed")))

	var clean_selected: String = str(selected_section).strip_edges()
	if clean_selected == "":
		clean_selected = "fight"

	var selected_root: String = clean_selected.split(":") [0].strip_edges().to_lower()
	if selected_root == "":
		selected_root = "fight"
	if selected_root == "business":
		selected_root = "promotions"

	var selected_payload: Dictionary = {}
	match selected_root:
		"fight":
			selected_payload = _boxing_hub_fight_section(actor, is_boxer, is_pro, is_amateur, retired)
		"rankings":
			selected_payload = _boxing_hub_rankings_section(actor, clean_selected)
		"awards":
			selected_payload = _boxing_hub_awards_section(actor, clean_selected)
		"legacy", "my_legacy":
			selected_payload = _boxing_hub_legacy_section(actor, clean_selected)
		"growth":
			selected_payload = _boxing_hub_growth_section(actor)
		"history", "my_fight_history":
			selected_payload = _boxing_hub_history_section(actor)
		"amateur":
			selected_payload = _boxing_hub_amateur_section(actor, is_pro, is_amateur)
		"gym":
			selected_payload = _boxing_hub_gym_section(actor, clean_selected)
		"promotions":
			selected_payload = _boxing_hub_promotions_section(actor)
		_:
			selected_root = "fight"
			selected_payload = _boxing_hub_fight_section(actor, is_boxer, is_pro, is_amateur, retired)

	var sections: Array = []
	var tab_shells: Array = _boxing_hub_light_tab_shell_sections()

	for raw_shell in tab_shells:
		if typeof(raw_shell) != TYPE_DICTIONARY:
			continue

		var shell: Dictionary = raw_shell as Dictionary
		var shell_id: String = str(shell.get("id", "")).strip_edges()
		var shell_root: String = shell_id.split(":") [0].strip_edges().to_lower()

		if shell_root == selected_root:
			sections.append(selected_payload)
		else:
			sections.append(shell)

	return {
		"success": true,
		"schema": "eralife.boxing_hub_payload",
		"version": CONTRACT_VERSION,
		"selected_section": clean_selected,
		"person_id": int(actor.id),
		"person_name": ("%s %s" % [actor.first_name, actor.last_name]).strip_edges(),
		"division": division,
		"career_stage": career_stage,
		"is_boxer": is_boxer,
		"is_pro": is_pro,
		"is_amateur": is_amateur,
		"retired": retired,
		"sections": sections,
		"built_at_ms": int(Time.get_ticks_msec())
	}
func _boxing_hub_light_tab_shell_sections() -> Array:
	return [
		{
			"id": "fight",
			"title": "Fight",
			"emoji": "🥊",
			"summary": "",
			"lines": [],
			"rows": [],
			"actions": [],
			"suppress_actions": true,
		},
		{
			"id": "rankings",
			"title": "Rankings",
			"emoji": "📈",
			"summary": "",
			"lines": [],
			"rows": [],
			"actions": [],
			"suppress_actions": true,
		},
		{
			"id": "awards",
			"title": "Awards",
			"emoji": "🏅",
			"summary": "",
			"lines": [],
			"rows": [],
			"actions": [],
			"suppress_actions": true,
		},
		{
			"id": "legacy",
			"title": "My Legacy",
			"emoji": "👑",
			"summary": "",
			"lines": [],
			"rows": [],
			"actions": [],
			"suppress_actions": true,
		},
		{
			"id": "growth",
			"title": "Growth",
			"emoji": "📊",
			"summary": "",
			"lines": [],
			"rows": [],
			"actions": [],
			"suppress_actions": true,
		},
		{
			"id": "history",
			"title": "My Fight History",
			"emoji": "📜",
			"summary": "",
			"lines": [],
			"rows": [],
			"actions": [],
			"suppress_actions": true,
		},
		{
			"id": "amateur",
			"title": "Amateur",
			"emoji": "🥇",
			"summary": "",
			"lines": [],
			"rows": [],
			"actions": [],
			"suppress_actions": true,
		},
		{
			"id": "gym",
			"title": "Gym",
			"emoji": "🥋",
			"summary": "",
			"lines": [],
			"rows": [],
			"actions": [],
			"suppress_actions": true,
		},
		{
			"id": "promotions",
			"title": "Promotions",
			"emoji": "🤝",
			"summary": "",
			"lines": [],
			"rows": [],
			"actions": [],
			"suppress_actions": true,
		}
	]
func _boxing_hub_fight_section(actor: Person, is_boxer: bool, is_pro: bool, is_amateur: bool, retired: bool) -> Dictionary:
	var fights_this_year: int = get_fights_this_year(actor)
	var max_fights: int = get_max_fights_per_year()

	return {
		"id": "fight",
		"title": "Fight",
		"emoji": "🥊",
		"summary": "Career status, fight availability, record, division, and next action.",
		"lines": [
			"Status: %s" % ("Retired" if retired else ("Professional Boxer" if is_pro else ("Amateur Boxer" if is_amateur else "Not a boxer yet"))),
			"Current Division: %s" % str(actor.boxing_profile.get("weight_class", "Unassigned")),
			"Record: %s" % _format_record(actor.boxing_profile.get("record", {})),
			"Amateur Record: %s" % _format_record(actor.boxing_profile.get("amateur_record", {})),
			"Fights This Year: %d/%d" % [fights_this_year, max_fights],
			"Career Entry: Age %d, Year %d" % [
				int(actor.boxing_profile.get("boxing_entry_age", actor.age)),
				int(actor.boxing_profile.get("boxing_entry_year", gs.year if gs != null else 0))
			]
		],
		"actions": [
			{ "label": "Begin Boxing Career", "command": "boxing.career.start", "refresh_tab": "fight"} if not is_boxer else {},
			{ "label": "Book Boxing Match", "command": "boxing.fight.book", "refresh_tab": "fight"} if is_boxer and not retired and can_fighter_take_fight_this_year(actor) else {},
			{ "label": "Opponent Preview", "command": "boxing.fight.preview", "refresh_tab": "fight"} if is_boxer and not retired else {},
			{ "label": "Review Last Fight Log", "command": "boxing.history.last_log", "refresh_tab": "history"} if is_boxer else {}
		].filter(func (row): return typeof(row) == TYPE_DICTIONARY and not (row as Dictionary).is_empty())
	}

func _boxing_weight_class_list() -> Array:
	return [
		"Flyweight",
		"Bantamweight",
		"Featherweight",
		"Lightweight",
		"Welterweight",
		"Middleweight",
		"Light Heavyweight",
		"Heavyweight"
	]


func _boxing_rankings_mode_from_section(selected_section: String) -> String:
	var clean: String = str(selected_section).strip_edges().to_lower()
	if clean.begins_with("rankings:amateur"):
		return "amateur"
	return "pro"


func _boxing_rankings_division_from_section(actor: Person, selected_section: String) -> String:
	var fallback: String = "Welterweight"
	if actor != null:
		fallback = str(actor.boxing_profile.get("weight_class", "Welterweight"))

	var clean: String = str(selected_section).strip_edges()
	if clean.begins_with("rankings:"):
		var parts: PackedStringArray = clean.split(":")
		if parts.size() >= 3:
			return str(parts [2]).replace("_", " ").strip_edges()
		if parts.size() >= 2 and str(parts [1]).strip_edges().to_lower() not in ["pro", "amateur"]:
			return str(parts [1]).replace("_", " ").strip_edges()

	return fallback


func _boxing_last_fight_text(person: Person) -> String:
	if person == null:
		return "No recent fight."

	var raw_history: Variant = person.boxing_profile.get("fight_history", [])
	if typeof(raw_history) != TYPE_ARRAY:
		return "No recent fight."

	var history: Array = raw_history
	if history.is_empty():
		return "No recent fight."

	var row: Dictionary = {}
	var raw_row: Variant = history [history.size() - 1]
	if typeof(raw_row) == TYPE_DICTIONARY:
		row = raw_row

	var result_text: String = str(row.get("result", row.get("result_type", ""))).strip_edges()
	var opponent_name: String = str(row.get("opponent_name", "Unknown Opponent")).strip_edges()
	if result_text == "":
		result_text = "Result"

	return "%s over %s" % [result_text, opponent_name]
func _boxing_title_display_label_for_body(body: String, division: String) -> String:
	var clean_body: String = str(body).strip_edges()
	var clean_division: String = str(division).strip_edges()

	if clean_body == "":
		return ""

	if clean_body == "Ring Magazine":
		clean_body = "Ring Magazine Lineal"

	if clean_division == "":
		return clean_body

	if clean_body.find(clean_division) >= 0:
		return clean_body

	return "%s %s" % [clean_body, clean_division]
func _boxing_title_labels_for_fighter(person: Person, division: String) -> Array:
	var labels: Array = []
	if person == null:
		return labels

	var clean_division: String = str(division).strip_edges()
	var person_id: int = int(person.id)

	var clean_gender: String = str(person.boxing_profile.get("boxing_gender_division", "")).strip_edges()
	if clean_gender == "":
		var gender_text: String = str(person.gender if "gender" in person else "").strip_edges().to_lower()
		clean_gender = "Female" if gender_text in ["female", "woman", "girl", "f"] else "Male"

	var raw_belts: Variant = person.boxing_profile.get("belts", [])
	if typeof(raw_belts) == TYPE_ARRAY:
		for raw_belt in raw_belts:
			var belt_text: String = str(raw_belt).strip_edges()
			if belt_text == "":
				continue

			var normalized_belt: String = belt_text.replace("Ring Magazine", "Ring Magazine Lineal")
			var label: String = normalized_belt

			if belt_text in ["WBA", "WBC", "IBF", "WBO", "Ring Magazine"]:
				label = _boxing_title_display_label_for_body(belt_text, clean_division)
			elif clean_division != "" and normalized_belt.find(clean_division) < 0:
				continue

			if label != "" and label not in labels:
				labels.append(label)

	if gs != null and gs.boxing_title_engine != null and typeof(gs.boxing_title_engine.champions) == TYPE_DICTIONARY:
		var bucket_keys: Array = []
		if clean_division != "":
			bucket_keys.append("%s:%s" % [clean_gender, clean_division])
			bucket_keys.append(clean_division)

		for raw_bucket_key in bucket_keys:
			var bucket_key: String = str(raw_bucket_key).strip_edges()
			if bucket_key == "":
				continue

			var champions_raw: Variant = gs.boxing_title_engine.champions.get(bucket_key, {})
			if typeof(champions_raw) != TYPE_DICTIONARY:
				continue

			var champions: Dictionary = champions_raw
			for raw_body in champions.keys():
				var body: String = str(raw_body).strip_edges()
				if body == "":
					continue
				if int(champions.get(raw_body, -1)) != person_id:
					continue

				var label: String = _boxing_title_display_label_for_body(body, clean_division)
				if label != "" and label not in labels:
					labels.append(label)

	return labels
func _boxing_contract_safe_array(value: Variant) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return value
	return []
func _boxing_title_body_key_from_label(title_label: String) -> String:
	var clean_label: String = str(title_label).strip_edges().to_upper()

	if clean_label.find("WBC") >= 0:
		return "WBC"
	if clean_label.find("WBA") >= 0:
		return "WBA"
	if clean_label.find("IBF") >= 0:
		return "IBF"
	if clean_label.find("WBO") >= 0:
		return "WBO"
	if clean_label.find("RING") >= 0 or clean_label.find("LINEAL") >= 0:
		return "RING"

	return ""


func _boxing_title_body_keys_from_labels(title_labels: Array) -> Array:
	var body_keys: Array = []
	var seen: Dictionary = {}

	for raw_label in title_labels:
		var label: String = str(raw_label).strip_edges()
		if label == "":
			continue

		var body_key: String = _boxing_title_body_key_from_label(label)
		if body_key == "":
			body_key = label.to_upper()

		if seen.has(body_key):
			continue

		body_keys.append(body_key)
		seen [body_key] = true

	return body_keys
func _boxing_champion_title_caption_from_labels(title_labels: Array, division: String = "") -> String:
	var body_keys: Array = _boxing_title_body_keys_from_labels(title_labels)
	var body_names: Array = []
	var weight_class: String = str(division).strip_edges()

	for raw_body in body_keys:
		var body: String = str(raw_body).strip_edges().to_upper()
		if body == "":
			continue

		var display_body: String = "Ring" if body == "RING" else body
		if display_body not in body_names:
			body_names.append(display_body)

	for raw_label in title_labels:
		var title_label: String = str(raw_label).strip_edges()
		if title_label == "":
			continue

		var body_key: String = _boxing_title_body_key_from_label(title_label)
		if body_key == "":
			continue

		var clean_weight: String = title_label
		if body_key == "RING":
			clean_weight = clean_weight.replace("Ring Magazine Lineal", "")
			clean_weight = clean_weight.replace("Ring Magazine", "")
			clean_weight = clean_weight.replace("Lineal", "")
		else:
			clean_weight = clean_weight.replace(body_key, "")

		clean_weight = clean_weight.replace("Champion", "")
		clean_weight = clean_weight.replace("Champ", "")
		clean_weight = clean_weight.replace("Title", "")
		clean_weight = clean_weight.strip_edges()

		if clean_weight != "":
			weight_class = clean_weight
			break

	if weight_class == "":
		return "Champion"

	if body_names.is_empty():
		return "%s Champion" % weight_class

	var suffix: String = "Champ" if body_names.size() == 1 else "Champion"
	return "%s %s %s" % [
		", ".join(body_names),
		weight_class,
		suffix
	]

func _boxing_champion_aura_semantic_contract(title_labels: Array, is_champion: bool, division: String = "") -> Dictionary:
	var body_keys: Array = _boxing_title_body_keys_from_labels(title_labels)
	var has_wbc: bool = "WBC" in body_keys
	var has_wba: bool = "WBA" in body_keys
	var has_ibf: bool = "IBF" in body_keys
	var has_wbo: bool = "WBO" in body_keys

	var undisputed: bool = has_wbc and has_wba and has_ibf and has_wbo
	var hybrid_red_green: bool = has_wbc and has_wba
	var dark_gold_dominance: bool = has_wbo and has_ibf

	var aura_key: String = "none"
	var aura_label: String = "None"

	if is_champion and not body_keys.is_empty():
		aura_key = "champion_aura"
		aura_label = _boxing_champion_title_caption_from_labels(title_labels, division)

		if undisputed:
			aura_key = "undisputed_god_energy"
		elif hybrid_red_green:
			aura_key = "hybrid_champion_aura"
		elif dark_gold_dominance:
			aura_key = "dark_gold_dominance"
		elif has_wbc:
			aura_key = "wbc_green_glow"
		elif has_wba:
			aura_key = "wba_maroon_glow"
		elif has_wbo:
			aura_key = "wbo_black_gold_glow"
		elif has_ibf:
			aura_key = "ibf_gold_glow"

	return {
		"enabled": is_champion and not body_keys.is_empty(),
		"belt_body_keys": body_keys,
		"belt_count": body_keys.size(),
		"key": aura_key,
		"label": aura_label,
		"is_undisputed": undisputed,
		"hybrid_red_green": hybrid_red_green,
		"dark_gold_dominance": dark_gold_dominance,
		"has_wbc": has_wbc,
		"has_wba": has_wba,
		"has_ibf": has_ibf,
		"has_wbo": has_wbo
	}
func _boxing_fighter_card_row(person: Person, mode: String, division: String, rank: int, is_champion: bool = false, explicit_title_labels: Array = []) -> Dictionary:
	if person == null:
		return {}

	var clean_mode: String = str(mode).strip_edges().to_lower()
	var clean_division: String = str(division).strip_edges()
	var record_key: String = "amateur_record" if clean_mode == "amateur" else "record"
	var raw_record: Variant = person.boxing_profile.get(record_key, {})
	var record: Dictionary = raw_record if typeof(raw_record) == TYPE_DICTIONARY else {}

	var title_labels: Array = []
	for raw_label in explicit_title_labels:
		var explicit_label: String = str(raw_label).strip_edges()
		if explicit_label != "" and explicit_label not in title_labels:
			title_labels.append(explicit_label)

	for raw_title_label in _boxing_title_labels_for_fighter(person, clean_division):
		var title_label: String = str(raw_title_label).strip_edges()
		if title_label != "" and title_label not in title_labels:
			title_labels.append(title_label)

	var belt_count: int = title_labels.size()
	var champion_card: bool = clean_mode == "pro" and (is_champion or belt_count > 0)

	var rank_heat: float = 0.0
	if not champion_card and rank > 0 and rank <= 5:
		rank_heat = clamp(float(6 - rank) / 5.0, 0.0, 1.0)

	var fame_value: int = clamp(int(person.fame) + belt_count * 14 + int(rank_heat * 8.0), 0, 100)
	var aura_contract: Dictionary = _boxing_champion_aura_semantic_contract(title_labels, champion_card, clean_division)
	var belt_body_keys: Array = _boxing_contract_safe_array(aura_contract.get("belt_body_keys", []))
	var champion_title_caption: String = str(aura_contract.get("label", "None")).strip_edges()
	if champion_title_caption == "":
		champion_title_caption = "None"

	var name_text: String = ("%s %s" % [person.first_name, person.last_name]).strip_edges()
	if name_text == "":
		name_text = "Unknown Fighter"

	var gender_division: String = str(person.boxing_profile.get("boxing_gender_division", "Male")).strip_edges()
	if gender_division == "":
		gender_division = "Male"

	var record_text: String = "%d-%d-%d (%d KOs)" % [
		int(record.get("wins", 0)),
		int(record.get("losses", 0)),
		int(record.get("draws", 0)),
		int(record.get("kos", 0))
	]

	var last_fight_text: String = _boxing_last_fight_text(person)
	var title_line: String = ", ".join(title_labels) if not title_labels.is_empty() else "None"
	var ranking_tier: String = "champion" if champion_card else ("title_contender" if clean_mode == "pro" and rank >= 1 and rank <= 5 else "ranked")
	var rank_label: String = "Champion" if champion_card else ("#%d Title Contender" % rank if clean_mode == "pro" and rank >= 1 and rank <= 5 else ("#%d Ranked Fighter" % rank if rank > 0 else "Unranked"))
	var display_title: String = "Champion • %s" % name_text if champion_card else ("#%d %s" % [rank, name_text] if rank > 0 else name_text)

	return {
		"row_type": "fighter_card",
		"mode": clean_mode,
		"person_id": int(person.id),
		"title": display_title,
		"name": name_text,
		"division": "%s %s" % [gender_division, clean_division],
		"rank": 0 if champion_card else rank,
		"rank_label": rank_label,
		"ranking_tier": ranking_tier,
		"rank_heat": 1.0 if champion_card else rank_heat,
		"is_champion": champion_card,
		"is_title_contender": clean_mode == "pro" and not champion_card and rank >= 1 and rank <= 5,
		"belt_count": belt_count,
		"title_labels": title_labels,
		"belt_body_keys": belt_body_keys,
		"champion_aura_key": str(aura_contract.get("key", "none")),
		"champion_aura_label": champion_title_caption,
		"champion_title_caption": champion_title_caption,
		"is_undisputed": bool(aura_contract.get("is_undisputed", false)),
		"hybrid_red_green": bool(aura_contract.get("hybrid_red_green", false)),
		"dark_gold_dominance": bool(aura_contract.get("dark_gold_dominance", false)),
		"record_text": record_text,
		"last_fight": last_fight_text,
		"fame": fame_value,
		"body": "%s\nStatus: %s\nTitles: %s\nChampion: %s\nLast fight: %s\nFame: %d/100" % [
			record_text,
			rank_label,
			title_line,
			champion_title_caption if champion_card else "None",
			last_fight_text,
			fame_value
		]
	}
func _boxing_division_card_rows(division: String, mode: String, gender_division: String = "Male") -> Array:
	var rows: Array = []
	if gs == null or gs.boxing_ranking_engine == null:
		return _boxing_projected_division_card_rows(division, mode, gender_division)

	var clean_division: String = str(division).strip_edges()
	var clean_mode: String = str(mode).strip_edges().to_lower()
	var clean_gender: String = str(gender_division).strip_edges()

	if clean_gender == "":
		clean_gender = "Male"
	if clean_division == "":
		return rows

	var ranking_ids: Array = gs.boxing_ranking_engine.get_division_ranked_ids(clean_division, clean_mode, 24, clean_gender)
	var champion_rows: Array = []
	var contender_rows: Array = []
	var used: Dictionary = {}

	if clean_mode == "pro" and gs.boxing_title_engine != null and typeof(gs.boxing_title_engine.champions) == TYPE_DICTIONARY:
		var title_bucket_keys: Array = [
			"%s:%s" % [clean_gender, clean_division],
			clean_division
		]

		for raw_bucket_key in title_bucket_keys:
			var bucket_key: String = str(raw_bucket_key).strip_edges()
			if bucket_key == "":
				continue

			var champions_raw: Variant = gs.boxing_title_engine.champions.get(bucket_key, {})
			if typeof(champions_raw) != TYPE_DICTIONARY:
				continue

			var champions: Dictionary = champions_raw
			for raw_body in champions.keys():
				var champion_id: int = int(champions.get(raw_body, -1))
				if champion_id <= 0:
					continue

				var champion: Person = gs.get_npc_by_id(champion_id)
				if champion == null:
					continue
				if typeof(champion.boxing_profile) != TYPE_DICTIONARY:
					continue
				if str(champion.boxing_profile.get("weight_class", "")).strip_edges() != clean_division:
					continue

				var champion_gender: String = str(champion.boxing_profile.get("boxing_gender_division", clean_gender)).strip_edges()
				if champion_gender == "":
					champion_gender = clean_gender
				if champion_gender != clean_gender:
					continue
				if not bool(champion.boxing_profile.get("turned_pro", false)):
					continue

				var champion_key: String = str(champion_id)
				if used.has(champion_key):
					continue

				var title_labels: Array = _boxing_title_labels_for_fighter(champion, clean_division)
				champion_rows.append(_boxing_fighter_card_row(champion, clean_mode, clean_division, 0, true, title_labels))
				used [champion_key] = true

	var displayed_rank: int = 1

	for i in range(ranking_ids.size()):
		var fighter_id: int = int(ranking_ids [i])
		var fighter_key: String = str(fighter_id)
		if used.has(fighter_key):
			continue

		var fighter: Person = gs.get_npc_by_id(fighter_id)
		if fighter == null:
			continue
		if typeof(fighter.boxing_profile) != TYPE_DICTIONARY:
			continue
		if str(fighter.boxing_profile.get("weight_class", "")).strip_edges() != clean_division:
			continue

		var fighter_gender: String = str(fighter.boxing_profile.get("boxing_gender_division", clean_gender)).strip_edges()
		if fighter_gender == "":
			fighter_gender = clean_gender
		if fighter_gender != clean_gender:
			continue

		if clean_mode == "pro" and not bool(fighter.boxing_profile.get("turned_pro", false)):
			continue
		if clean_mode == "amateur" and bool(fighter.boxing_profile.get("turned_pro", false)):
			continue

		var title_labels: Array = _boxing_title_labels_for_fighter(fighter, clean_division)
		var is_champion: bool = clean_mode == "pro" and not title_labels.is_empty()

		if is_champion:
			champion_rows.append(_boxing_fighter_card_row(fighter, clean_mode, clean_division, 0, true, title_labels))
		else:
			contender_rows.append(_boxing_fighter_card_row(fighter, clean_mode, clean_division, displayed_rank, false, title_labels))
			displayed_rank += 1

		used [fighter_key] = true

	if clean_mode == "pro" and champion_rows.size() < 4:
		var missing_champions: int = 4 - champion_rows.size()
		champion_rows.append_array(_boxing_projected_champion_card_rows(clean_division, clean_gender, used, missing_champions))

	var target_contenders: int = 20 if clean_mode == "pro" else 24
	if contender_rows.size() < target_contenders:
		contender_rows.append_array(_boxing_projected_contender_card_rows(clean_division, clean_mode, clean_gender, used, displayed_rank, target_contenders - contender_rows.size()))

	rows.append_array(champion_rows)
	rows.append_array(contender_rows)
	return rows
func _boxing_pfp_payload_with_projection(payload: Dictionary, mode: String, gender_division: String, priority_division: String = "") -> Dictionary:
	var out: Dictionary = payload.duplicate(true) if typeof(payload) == TYPE_DICTIONARY else {}
	var fighters: Array = out.get("fighters", []) if typeof(out.get("fighters", [])) == TYPE_ARRAY else []

	var clean_mode: String = str(mode).strip_edges().to_lower()
	if clean_mode == "":
		clean_mode = "pro"

	var clean_gender: String = str(gender_division).strip_edges()
	if clean_gender == "":
		clean_gender = "Male"

	var clean_priority_division: String = str(priority_division).strip_edges()
	if clean_priority_division == "":
		clean_priority_division = "Welterweight"

	var used_names: Dictionary = {}
	for raw_row in fighters:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = raw_row as Dictionary
		used_names [str(row.get("name", "")).strip_edges()] = true

	var rank_value: int = fighters.size() + 1
	while fighters.size() < 10:
		var division: String = _boxing_projected_pfp_division(clean_priority_division, fighters.size())
		var name_text: String = _boxing_projected_fighter_name(clean_mode, clean_gender, division, fighters.size() + 1, "pfp")
		if used_names.has(name_text):
			name_text = "%s %d" % [name_text, fighters.size() + 1]

		fighters.append({
			"rank": rank_value,
			"name": name_text,
			"division": "%s %s" % [clean_gender, division],
			"record_text": _boxing_projected_record_text(clean_mode, rank_value, false)
		})
		used_names [name_text] = true
		rank_value += 1

	out ["fighters"] = fighters
	out ["gender_division"] = clean_gender
	out ["mode"] = clean_mode
	out ["projection_filled"] = true
	out ["projection_source"] = "boxing_rankings_ui_projection"
	return out


func _boxing_projected_division_card_rows(division: String, mode: String, gender_division: String = "Male") -> Array:
	var clean_mode: String = str(mode).strip_edges().to_lower()
	var clean_division: String = str(division).strip_edges()
	var clean_gender: String = str(gender_division).strip_edges()
	var used: Dictionary = {}

	if clean_mode == "":
		clean_mode = "pro"
	if clean_division == "":
		clean_division = "Welterweight"
	if clean_gender == "":
		clean_gender = "Male"

	var rows: Array = []
	if clean_mode == "pro":
		rows.append_array(_boxing_projected_champion_card_rows(clean_division, clean_gender, used, 4))
		rows.append_array(_boxing_projected_contender_card_rows(clean_division, clean_mode, clean_gender, used, 1, 20))
	else:
		rows.append_array(_boxing_projected_contender_card_rows(clean_division, clean_mode, clean_gender, used, 1, 24))

	return rows


func _boxing_projected_champion_card_rows(division: String, gender_division: String, used: Dictionary, count: int = 4) -> Array:
	var rows: Array = []
	var clean_division: String = str(division).strip_edges()
	var clean_gender: String = str(gender_division).strip_edges()
	var sanctioning_bodies: Array = ["WBA", "WBC", "IBF", "WBO"]

	if clean_gender == "":
		clean_gender = "Male"

	for i in range(max(0, count)):
		var body: String = str(sanctioning_bodies [i % sanctioning_bodies.size()])
		var name_text: String = _boxing_projected_fighter_name("pro", clean_gender, clean_division, i + 1, "champion_%s" % body)
		var virtual_id: int = _boxing_projected_fighter_id("pro", clean_gender, clean_division, i + 1, "champion_%s" % body)

		if used.has(str(virtual_id)):
			continue

		var title_labels: Array = ["%s %s Champion" % [body, clean_division]]
		rows.append(_boxing_projected_fighter_card_row(
			virtual_id,
			name_text,
			"pro",
			clean_division,
			clean_gender,
			0,
			true,
			title_labels,
			i + 1
		))
		used [str(virtual_id)] = true

	return rows


func _boxing_projected_contender_card_rows(division: String, mode: String, gender_division: String, used: Dictionary, start_rank: int = 1, count: int = 20) -> Array:
	var rows: Array = []
	var clean_division: String = str(division).strip_edges()
	var clean_mode: String = str(mode).strip_edges().to_lower()
	var clean_gender: String = str(gender_division).strip_edges()

	if clean_mode == "":
		clean_mode = "pro"
	if clean_gender == "":
		clean_gender = "Male"

	var rank_value: int = max(1, start_rank)
	var made: int = 0

	while made < max(0, count):
		var seed_rank: int = rank_value + made
		var name_text: String = _boxing_projected_fighter_name(clean_mode, clean_gender, clean_division, seed_rank, "contender")
		var virtual_id: int = _boxing_projected_fighter_id(clean_mode, clean_gender, clean_division, seed_rank, "contender")

		if used.has(str(virtual_id)):
			made += 1
			continue

		rows.append(_boxing_projected_fighter_card_row(
			virtual_id,
			name_text,
			clean_mode,
			clean_division,
			clean_gender,
			seed_rank,
			false,
			[],
			seed_rank
		))
		used [str(virtual_id)] = true
		made += 1

	return rows


func _boxing_projected_fighter_card_row(virtual_id: int, name_text: String, mode: String, division: String, gender_division: String, rank: int, is_champion: bool = false, title_labels: Array = [], seed_rank: int = 1) -> Dictionary:
	var clean_mode: String = str(mode).strip_edges().to_lower()
	var clean_division: String = str(division).strip_edges()
	var clean_gender: String = str(gender_division).strip_edges()

	if clean_mode == "":
		clean_mode = "pro"
	if clean_gender == "":
		clean_gender = "Male"

	var champion_card: bool = clean_mode == "pro" and is_champion
	var belt_count: int = title_labels.size()
	var rank_heat: float = 0.0
	if not champion_card and rank > 0 and rank <= 5:
		rank_heat = clamp(float(6 - rank) / 5.0, 0.0, 1.0)

	var fame_value: int = clamp(28 + belt_count * 13 + int(rank_heat * 9.0) + int(abs(virtual_id) % 11), 0, 100)
	var aura_contract: Dictionary = _boxing_champion_aura_semantic_contract(title_labels, champion_card, clean_division)
	var belt_body_keys: Array = _boxing_contract_safe_array(aura_contract.get("belt_body_keys", []))
	var champion_title_caption: String = str(aura_contract.get("label", "None")).strip_edges()
	if champion_title_caption == "":
		champion_title_caption = "None"

	var record_text: String = _boxing_projected_record_text(clean_mode, seed_rank, champion_card)
	var last_fight_text: String = "No recent fight."
	var title_line: String = ", ".join(title_labels) if not title_labels.is_empty() else "None"
	var ranking_tier: String = "champion" if champion_card else ("title_contender" if clean_mode == "pro" and rank >= 1 and rank <= 5 else "ranked")
	var rank_label: String = "Champion" if champion_card else ("#%d Title Contender" % rank if clean_mode == "pro" and rank >= 1 and rank <= 5 else ("#%d Ranked Fighter" % rank if rank > 0 else "Unranked"))
	var display_title: String = "Champion • %s" % name_text if champion_card else ("#%d %s" % [rank, name_text] if rank > 0 else name_text)

	return {
		"row_type": "fighter_card",
		"mode": clean_mode,
		"person_id": virtual_id,
		"title": display_title,
		"name": name_text,
		"division": "%s %s" % [clean_gender, clean_division],
		"rank": 0 if champion_card else rank,
		"rank_label": rank_label,
		"ranking_tier": ranking_tier,
		"rank_heat": 1.0 if champion_card else rank_heat,
		"is_champion": champion_card,
		"is_title_contender": clean_mode == "pro" and not champion_card and rank >= 1 and rank <= 5,
		"belt_count": belt_count,
		"title_labels": title_labels,
		"belt_body_keys": belt_body_keys,
		"champion_aura_key": str(aura_contract.get("key", "none")),
		"champion_aura_label": champion_title_caption,
		"champion_title_caption": champion_title_caption,
		"is_undisputed": bool(aura_contract.get("is_undisputed", false)),
		"hybrid_red_green": bool(aura_contract.get("hybrid_red_green", false)),
		"dark_gold_dominance": bool(aura_contract.get("dark_gold_dominance", false)),
		"record_text": record_text,
		"last_fight": last_fight_text,
		"fame": fame_value,
		"projection_only": true,
		"projection_source": "boxing_rankings_ui_projection",
		"body": "%s\nStatus: %s\nTitles: %s\nChampion: %s\nLast fight: %s\nFame: %d/100" % [
			record_text,
			rank_label,
			title_line,
			champion_title_caption if champion_card else "None",
			last_fight_text,
			fame_value
		]
	}


func _boxing_projected_pfp_division(priority_division: String, index: int) -> String:
	var divisions: Array = _boxing_weight_class_list()
	var clean_priority: String = str(priority_division).strip_edges()

	if clean_priority != "" and divisions.has(clean_priority) and index % 3 == 0:
		return clean_priority

	if divisions.is_empty():
		return clean_priority if clean_priority != "" else "Welterweight"

	return str(divisions [abs(index) % divisions.size()])


func _boxing_projected_fighter_name(mode: String, gender_division: String, division: String, rank: int, salt: String = "") -> String:
	var first_names: Array = [
		"Ezra", "Josiah", "Devin", "Carl", "Phenix", "Elvi", "Levi", "Adrian",
		"Bennet", "Tyson", "Cameron", "Ethan", "Marcus", "Matteo", "Nolan",
		"Roman", "Marcus", "Soren", "Theo", "Tristan", "Xavier", "Asher"
	]
	var last_names: Array = [
		"Burke", "Hughes", "Torres", "Bell", "Alvarez", "West", "Foster",
		"West", "Wells", "Patel", "Cooper", "Wells", "Simon", "Ross",
		"Myers", "Barnes", "Woods", "Bailey", "Carter", "Reed", "Marshall",
		"Henderson"
	]

	var seed_text: String = "%s|%s|%s|%d|%s" % [
		str(mode),
		str(gender_division),
		str(division),
		rank,
		str(salt)
	]
	var seed_value: int = abs(hash(seed_text))
	var first_name: String = str(first_names [seed_value % first_names.size()])
	var last_name: String = str(last_names [(seed_value / max(1, first_names.size())) % last_names.size()])

	return "%s %s" % [first_name, last_name]


func _boxing_projected_fighter_id(mode: String, gender_division: String, division: String, rank: int, salt: String = "") -> int:
	var seed_text: String = "boxing_projection|%s|%s|%s|%d|%s" % [
		str(mode),
		str(gender_division),
		str(division),
		rank,
		str(salt)
	]
	return - int(abs(hash(seed_text)) % 2000000000) - 1000


func _boxing_projected_record_text(mode: String, rank: int, is_champion: bool = false) -> String:
	var clean_mode: String = str(mode).strip_edges().to_lower()
	var rank_value: int = max(1, rank)

	var wins: int = 20 + int(abs(hash("%s|wins|%d" % [clean_mode, rank_value])) % 18)
	var losses: int = int(abs(hash("%s|losses|%d" % [clean_mode, rank_value])) % 3)
	var draws: int = int(abs(hash("%s|draws|%d" % [clean_mode, rank_value])) % 2)
	var kos: int = 4 + int(abs(hash("%s|kos|%d" % [clean_mode, rank_value])) % 16)

	if clean_mode == "amateur":
		wins = 22 + int(abs(hash("amateur|wins|%d" % rank_value)) % 13)
		losses = int(abs(hash("amateur|losses|%d" % rank_value)) % 2)
		draws = 0
		kos = 3 + int(abs(hash("amateur|kos|%d" % rank_value)) % 12)

	if is_champion:
		wins += 8
		losses = min(losses, 1)
		kos += 4

	return "%d-%d-%d (%d KOs)" % [wins, losses, draws, kos]
func _boxing_seed_existing_division_fighters_for_rankings(division: String, mode: String, gender_division: String, max_scan: int = 1200, max_seed: int = 40) -> void:
	if gs == null or gs.boxing_ranking_engine == null:
		return

	var clean_division: String = str(division).strip_edges()
	var clean_mode: String = str(mode).strip_edges().to_lower()
	var clean_gender: String = str(gender_division).strip_edges()

	if clean_division == "" or clean_gender == "":
		return

	var scanned: int = 0
	var seeded: int = 0

	for raw_npc in gs.npcs:
		scanned += 1
		if scanned > max_scan:
			break
		if seeded >= max_seed:
			break

		var fighter:= raw_npc as Person
		if fighter == null:
			continue
		if typeof(fighter.boxing_profile) != TYPE_DICTIONARY:
			continue
		if str(fighter.boxing_profile.get("weight_class", "")).strip_edges() != clean_division:
			continue

		var fighter_gender: String = str(fighter.boxing_profile.get("boxing_gender_division", clean_gender)).strip_edges()
		if fighter_gender == "":
			fighter_gender = clean_gender
		if fighter_gender != clean_gender:
			continue

		if clean_mode == "pro" and not bool(fighter.boxing_profile.get("turned_pro", false)):
			continue
		if clean_mode == "amateur" and bool(fighter.boxing_profile.get("turned_pro", false)):
			continue

		gs.boxing_ranking_engine.seed_fighter(fighter)
		seeded += 1
func _boxing_opposite_gender_division(gender_division: String) -> String:
	var clean_gender: String = str(gender_division).strip_edges()
	return "Male" if clean_gender == "Female" else "Female"


func _boxing_rankings_pfp_gender_map(actor: Person, selected_section: String) -> Dictionary:
	var actor_gender: String = "Male"
	if actor != null:
		actor_gender = str(actor.boxing_profile.get("boxing_gender_division", "")).strip_edges()
		if actor_gender == "":
			var gender_text: String = str(actor.gender if "gender" in actor else "").strip_edges().to_lower()
			actor_gender = "Female" if gender_text in ["female", "woman", "girl", "f"] else "Male"

	var out: Dictionary = {
		"pro": actor_gender,
		"amateur": actor_gender
	}

	var parts: PackedStringArray = str(selected_section).strip_edges().split(":")
	for i in range(parts.size() - 1):
		var token: String = str(parts [i]).strip_edges().to_lower()
		var value: String = str(parts [i + 1]).strip_edges()
		if value not in ["Male", "Female"]:
			continue

		if token == "pro_pfp":
			out ["pro"] = value
		elif token == "amateur_pfp":
			out ["amateur"] = value

	return out


func _boxing_rankings_section_id(selected_mode: String, selected_division: String, pro_pfp_gender: String, amateur_pfp_gender: String) -> String:
	return "rankings:%s:%s:pro_pfp:%s:amateur_pfp:%s" % [
		str(selected_mode).strip_edges().to_lower(),
		str(selected_division).strip_edges().replace(" ", "_"),
		str(pro_pfp_gender).strip_edges(),
		str(amateur_pfp_gender).strip_edges()
	]
func _boxing_pfp_board_row(title: String, payload: Dictionary, board_kind: String, selected_mode: String, selected_division: String, pro_pfp_gender: String, amateur_pfp_gender: String) -> Dictionary:
	var lines: Array = []
	var rows: Array = payload.get("fighters", []) if typeof(payload.get("fighters", [])) == TYPE_ARRAY else []
	var board_gender: String = str(payload.get("gender_division", "")).strip_edges()
	if board_gender == "":
		board_gender = "Male"

	for i in range(min(10, rows.size())):
		var row: Dictionary = rows [i]
		lines.append("#%d %s — %s — %s" % [
			int(row.get("rank", i + 1)),
			str(row.get("name", "Unknown Fighter")),
			str(row.get("division", "")),
			str(row.get("record_text", "0-0-0"))
		])

	if lines.is_empty():
		lines.append("No ranked fighters yet.")

	var toggle_gender: String = _boxing_opposite_gender_division(board_gender)
	var next_pro_gender: String = pro_pfp_gender
	var next_amateur_gender: String = amateur_pfp_gender

	if str(board_kind).strip_edges().to_lower() == "pro":
		next_pro_gender = toggle_gender
	else:
		next_amateur_gender = toggle_gender

	var refresh_section: String = _boxing_rankings_section_id(selected_mode, selected_division, next_pro_gender, next_amateur_gender)

	return {
		"row_type": "pfp_board",
		"title": "%s • %s" % [title, board_gender],
		"lines": lines,
		"action": {
			"label": "Women’s rankings" if board_gender == "Male" else "Men’s Rankings",
			"command": "boxing.rankings.view",
			"args": { "section": refresh_section},
			"refresh_tab": refresh_section
		}
	}
func _boxing_hub_rankings_section(actor: Person, selected_section: String) -> Dictionary:
	var selected_mode: String = _boxing_rankings_mode_from_section(selected_section)
	var selected_division: String = _boxing_rankings_division_from_section(actor, selected_section)
	var selected_gender: String = "Male"

	if actor != null:
		selected_gender = str(actor.boxing_profile.get("boxing_gender_division", "")).strip_edges()
		if selected_gender == "":
			var gender_text: String = str(actor.gender if "gender" in actor else "").strip_edges().to_lower()
			selected_gender = "Female" if gender_text in ["female", "woman", "girl", "f"] else "Male"

	if gs != null and typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	if gs != null:
		gs.scenario_state ["boxing_roster_projection_available"] = true
		gs.scenario_state ["boxing_roster_projection_reason"] = "boxing_rankings_section_render"
		gs.scenario_state ["boxing_roster_projection_priority_division"] = selected_division
		gs.scenario_state ["boxing_roster_projection_priority_gender"] = selected_gender
		gs.scenario_state ["boxing_roster_projection_at_ms"] = int(Time.get_ticks_msec())

	var pfp_gender_map: Dictionary = _boxing_rankings_pfp_gender_map(actor, selected_section)
	var pro_pfp_gender: String = str(pfp_gender_map.get("pro", selected_gender))
	var amateur_pfp_gender: String = str(pfp_gender_map.get("amateur", selected_gender))

	var pro_pfp: Dictionary = {}
	var amateur_pfp: Dictionary = {}

	if gs != null and gs.boxing_ranking_engine != null:
		if gs.boxing_ranking_engine.has_method("build_pound_for_pound_payload"):
			pro_pfp = gs.boxing_ranking_engine.build_pound_for_pound_payload("pro", pro_pfp_gender)
			amateur_pfp = gs.boxing_ranking_engine.build_pound_for_pound_payload("amateur", amateur_pfp_gender)

	pro_pfp = _boxing_pfp_payload_with_projection(pro_pfp, "pro", pro_pfp_gender, selected_division)
	amateur_pfp = _boxing_pfp_payload_with_projection(amateur_pfp, "amateur", amateur_pfp_gender, selected_division)

	var pfp_rows: Array = [
		_boxing_pfp_board_row("Professional Top 10 P4P", pro_pfp, "pro", selected_mode, selected_division, pro_pfp_gender, amateur_pfp_gender),
		_boxing_pfp_board_row("Adult Amateur Top 10 P4P", amateur_pfp, "amateur", selected_mode, selected_division, pro_pfp_gender, amateur_pfp_gender)
	]

	var card_rows: Array = _boxing_division_card_rows(selected_division, selected_mode, selected_gender)

	var divisions: Array = _boxing_weight_class_list()
	var current_index: int = max(0, divisions.find(selected_division))
	var prev_division: String = str(divisions [(current_index - 1 + divisions.size()) % divisions.size()])
	var next_division: String = str(divisions [(current_index + 1) % divisions.size()])
	var opposite_mode: String = "amateur" if selected_mode == "pro" else "pro"
	var selected_mode_label: String = "Professional" if selected_mode == "pro" else "Adult Amateur"
	var opposite_mode_label: String = "Adult Amateur" if opposite_mode == "amateur" else "Professional"

	var prev_section: String = _boxing_rankings_section_id(selected_mode, prev_division, pro_pfp_gender, amateur_pfp_gender)
	var next_section: String = _boxing_rankings_section_id(selected_mode, next_division, pro_pfp_gender, amateur_pfp_gender)
	var opposite_section: String = _boxing_rankings_section_id(opposite_mode, selected_division, pro_pfp_gender, amateur_pfp_gender)

	var division_controls: Array = [
		{
			"role": "arrow",
			"label": "⬅",
			"command": "boxing.rankings.view",
			"args": { "section": prev_section},
			"refresh_tab": prev_section
		},
		{
			"role": "label",
			"label": "%s %s %s" % [selected_gender, selected_division, selected_mode_label]
		},
		{
			"role": "arrow",
			"label": "➡",
			"command": "boxing.rankings.view",
			"args": { "section": next_section},
			"refresh_tab": next_section
		},
		{
			"role": "mode_toggle",
			"label": "View %s" % opposite_mode_label,
			"command": "boxing.rankings.view",
			"args": { "section": opposite_section},
			"refresh_tab": opposite_section
		}
	]

	return {
		"id": "rankings",
		"title": "Rankings",
		"emoji": "📈",
		"summary": "Professional and adult amateur P4P sit side by side. Rankings render instantly from real boxing truth plus a lightweight roster projection when full NPC materialization is still deferred.",
		"lines": [],
		"pfp_rows": pfp_rows,
		"pfp_columns": 2,
		"division_controls": division_controls,
		"rows": card_rows,
		"row_columns": 4,
		"actions": [],
		"suppress_actions": true,
	}
func _boxing_hub_awards_section(_actor: Person, selected_section: String) -> Dictionary:
	var mode: String = "overview"
	if selected_section == "awards:candidates":
		mode = "candidates"
	elif selected_section == "awards:winners":
		mode = "winners"

	var lines: Array = []
	if mode == "candidates":
		lines = _boxing_award_candidate_lines()
	elif mode == "winners":
		lines = _boxing_award_winner_lines()
	else:
		lines = [
			"Award Candidates: Press the button to view next year's frontrunners.",
			"Award Winners: Press the button to view previous years' winners.",
			"Awards are built from records, belts, title wins, knockouts, and legacy score."
		]

	return {
		"id": "awards",
		"title": "Awards",
		"emoji": "🏅",
		"summary": "Award candidates and previous winners from the boxing world.",
		"lines": lines,
		"actions": [
			{ "label": "Award Candidates", "command": "boxing.awards.candidates", "refresh_tab": "awards:candidates"},
			{ "label": "Award Winners", "command": "boxing.awards.winners", "refresh_tab": "awards:winners"}
		]
	}


func _boxing_hub_legacy_section(actor: Person, selected_section: String) -> Dictionary:
	var mode: String = "overview"
	if selected_section == "legacy:retired":
		mode = "retired"

	var lines: Array = _retired_boxer_lines() if mode == "retired" else _my_legacy_lines(actor)

	return {
		"id": "legacy",
		"title": "My Legacy",
		"emoji": "👑",
		"summary": "Legacy goals, progress, all-time standing, retirement, and retired fighters.",
		"lines": lines,
		"actions": [
			{ "label": "My Fight History", "command": "boxing.history.mine", "refresh_tab": "history"},
			{ "label": "Retired Boxers", "command": "boxing.legacy.retired_boxers", "refresh_tab": "legacy:retired"},
			{ "label": "Retire", "command": "boxing.career.retire", "refresh_tab": "legacy"}
		]
	}


func _boxing_hub_growth_section(actor: Person) -> Dictionary:
	_ensure_boxing_growth_profile(actor)

	var growth: Dictionary = actor.boxing_profile ["growth"]
	var levels: Dictionary = growth.get("levels", {}) if typeof(growth.get("levels", {})) == TYPE_DICTIONARY else {}

	var xp: int = max(0, int(growth.get("xp", 0)))
	var total_levels: int = max(0, int(growth.get("total_levels", 0)))
	var max_total_levels: int = max(1, int(growth.get("max_total_levels", 220)))
	var max_skill_level: int = max(1, int(growth.get("max_skill_level", 20)))

	var skill_rows: Array = []

	for skill in _boxing_growth_skill_contracts():
		var key: String = str(skill.get("key", "")).strip_edges()
		if key == "":
			continue

		var label: String = str(skill.get("label", key)).strip_edges()
		var rating_key: String = str(skill.get("rating", "")).strip_edges()
		var current_level: int = clamp(int(levels.get(key, 0)), 0, max_skill_level)
		var next_level: int = min(current_level + 1, max_skill_level)
		var next_cost: int = _boxing_growth_level_cost(next_level, key)
		var remaining_total_slots: int = max(0, max_total_levels - total_levels)

		var boxes: Array = []

		for box_level in range(1, max_skill_level + 1):
			var box_state: String = "filled"
			var cumulative_cost: int = 0
			var levels_requested: int = max(0, box_level - current_level)
			var can_select: bool = false
			var locked_reason: String = ""

			if box_level <= current_level:
				box_state = "filled"
			else:
				for purchase_level in range(current_level + 1, box_level + 1):
					cumulative_cost += _boxing_growth_level_cost(purchase_level, key)

				if levels_requested > remaining_total_slots:
					box_state = "capped"
					locked_reason = "Build cap reached before level %d." % box_level
				elif xp >= cumulative_cost:
					box_state = "available"
					can_select = true
				else:
					box_state = "unaffordable"
					locked_reason = "Need %d XP to reach level %d." % [cumulative_cost, box_level]

			boxes.append({
				"level": box_level,
				"state": box_state,
				"filled": box_level <= current_level,
				"can_select": can_select,
				"cost_to_reach": cumulative_cost,
				"levels_requested": levels_requested,
				"is_milestone": box_level % 5 == 0,
				"locked_reason": locked_reason
			})

		skill_rows.append({
			"key": key,
			"label": label,
			"rating": rating_key,
			"base_cost": _boxing_growth_skill_base_cost(key),
			"current_level": current_level,
			"max_level": max_skill_level,
			"next_level": next_level,
			"next_cost": next_cost,
			"xp": xp,
			"total_levels": total_levels,
			"max_total_levels": max_total_levels,
			"remaining_total_slots": remaining_total_slots,
			"boxes": boxes
		})

	return {
		"id": "growth",
		"title": "Growth",
		"emoji": "📊",
		"summary": "Build your fighter. 20 levels per skill, but only 220 total levels across the entire build.",
		"lines": [
			"Current XP: %d" % xp,
			"Levels Available: %d/%d" % [total_levels, max_total_levels],
			"Overall Build Cap: %d" % max_total_levels,
			"Click any future box to buy straight to that level if you can afford it."
		],
		"rows": [],
		"row_columns": 1,
		"actions": [],
		"action_columns": 1,
		"athleticism_panel": _boxing_growth_athleticism_panel(actor),
		"growth_board": {
			"schema": "eralife.boxing_growth_board",
			"version": 2,
			"xp": xp,
			"total_levels": total_levels,
			"max_total_levels": max_total_levels,
			"max_skill_level": max_skill_level,
			"skills": skill_rows
		}
	}

func _boxing_hub_history_section(actor: Person) -> Dictionary:
	var history: Array = actor.boxing_profile.get("fight_history", []) if typeof(actor.boxing_profile.get("fight_history", [])) == TYPE_ARRAY else []
	var lines: Array = []

	if history.is_empty():
		lines.append("No fight history yet.")
	else:
		for i in range(max(0, history.size() - 12), history.size()):
			var row: Dictionary = history [i]
			lines.append("%s vs %s — %s" % [
				str(row.get("year", "?")),
				str(row.get("opponent_name", "Unknown Opponent")),
				str(row.get("result", row.get("result_type", "Result")))
			])

	return {
		"id": "history",
		"title": "My Fight History",
		"emoji": "📜",
		"summary": "Career fight memory, recent outcomes, rivalries, and last fight log.",
		"lines": lines,
		"actions": [
			{ "label": "Review Last Fight Log", "command": "boxing.history.last_log", "refresh_tab": "history"},
			{ "label": "View Boxing Rivalries", "command": "boxing.rivalries.view", "refresh_tab": "history"},
			{ "label": "Call Out Opponent", "command": "boxing.rivalries.callout", "refresh_tab": "history"}
		]
	}


func _boxing_hub_amateur_section(actor: Person, is_pro: bool, is_amateur: bool) -> Dictionary:
	var circuit: Dictionary = actor.boxing_profile.get("amateur_circuit", {}) if typeof(actor.boxing_profile.get("amateur_circuit", {})) == TYPE_DICTIONARY else {}
	var tier: String = str(circuit.get("tier", "youth_amateur" if int(actor.age) < 18 else "adult_amateur"))
	return {
		"id": "amateur",
		"title": "Amateur",
		"emoji": "🥇",
		"summary": "Amateur boxing has no division champion. Golden Gloves decides tournament glory while ranked amateurs can still book amateur fights.",
		"lines": [
			"Current Tier: %s" % tier.replace("_", " ").capitalize(),
			"Amateur Active: %s" % ("Yes" if is_amateur else "No"),
			"Professional: %s" % ("Yes" if is_pro else "No"),
			"Golden Gloves Wins: %d" % int(actor.boxing_profile.get("golden_gloves_wins", 0)),
			"Tournaments Won: %d" % int(circuit.get("tournaments_won", 0)),
			"Olympic Medals: %d" % int(circuit.get("olympic_medals", 0)),
			"Auto Turn Pro: No"
		],
		"actions": [
			{ "label": "Fight in the Golden Gloves", "command": "boxing.amateur.enter", "refresh_tab": "amateur"},
			{ "label": "Book Amateur Fight", "command": "boxing.fight.book", "refresh_tab": "fight"} if is_amateur else {}
		].filter(func (row): return typeof(row) == TYPE_DICTIONARY and not (row as Dictionary).is_empty()) if not is_pro else []
	}
func _boxing_gym_card_rows(actor: Person) -> Array:
	var rows: Array = []
	if gs == null or gs.boxing_gym_engine == null:
		return rows

	if not gs.boxing_gym_engine.has_method("get_gym_catalog"):
		return rows

	var catalog: Array = gs.boxing_gym_engine.get_gym_catalog(actor)
	for raw_gym in catalog:
		if typeof(raw_gym) != TYPE_DICTIONARY:
			continue

		var gym: Dictionary = raw_gym
		var eligible: bool = bool(gym.get("eligible", false))
		var locked_reason: String = str(gym.get("locked_reason", "")).strip_edges()
		var perks: Array = gym.get("perks", []) if typeof(gym.get("perks", [])) == TYPE_ARRAY else []

		rows.append({
			"row_type": "gym_card",
			"title": str(gym.get("name", "Unknown Gym")),
			"body": "%s • Fee: $%d/mo • Training +%d\nSparring Quality: %d/100\nPerks: %s%s" % [
				str(gym.get("tier", "local")).capitalize(),
				int(gym.get("monthly_fee", 0)),
				int(gym.get("training_bonus", 0)),
				int(gym.get("sparring_quality", 0)),
				", ".join(perks),
				("\nLocked: %s" % locked_reason) if not eligible and locked_reason != "" else ""
			],
			"glow": float(gym.get("color_heat", 0.3)),
			"eligible": eligible,
			"locked_reason": locked_reason,
			"action": {
				"label": "Enter %s" % str(gym.get("name", "Gym")),
				"command": "boxing.gym.join",
				"args": { "gym_id": str(gym.get("id", ""))},
				"refresh_tab": "gym",
				"suppress_popup": false
			} if eligible else {}
		})

	return rows


func _boxing_hub_gym_section(actor: Person, selected_section: String) -> Dictionary:
	var gym_id: String = str(actor.boxing_profile.get("gym_id", "")).strip_edges()
	var gym_name: String = str(actor.boxing_profile.get("gym_name", "No gym")).strip_edges()
	if gym_name == "":
		gym_name = "No gym"

	var selected_root: String = str(selected_section).strip_edges().to_lower()
	var finding_gym: bool = selected_root == "gym:find"

	if gym_id == "" and not finding_gym:
		return {
			"id": "gym",
			"title": "Gym",
			"emoji": "🏋️",
			"summary": "You are not automatically assigned to a gym. Find a room, enter it, and build your camp identity.",
			"lines": [
				"Current Gym: No gym",
				"Gym association affects training quality, sparring room, gym accomplishments, and camp identity."
			],
			"rows": [],
			"actions": [
				{
					"label": "+ Find a Gym",
					"command": "boxing.gym.find",
					"args": { "section": "gym:find"},
					"refresh_tab": "gym:find",
					"suppress_popup": true
				}
			],
			"action_columns": 1
		}

	if gym_id == "":
		return {
			"id": "gym",
			"title": "Gym",
			"emoji": "🏋️",
			"summary": "Choose a boxing gym to enter. Better gyms have better sparring, higher training bonuses, and stronger room identity.",
			"lines": ["Current Gym: No gym"],
			"rows": _boxing_gym_card_rows(actor),
			"row_columns": 2,
			"actions": []
		}

	return {
		"id": "gym",
		"title": "Gym",
		"emoji": "🏋️",
		"summary": "Your gym is your training room, sparring ecosystem, and championship wall.",
		"lines": [
			"Current Gym: %s" % gym_name,
			"Training Bonus: +%d" % int(actor.boxing_profile.get("gym_training_bonus", 0)),
			"Sparring Quality: %d/100" % int(actor.boxing_profile.get("gym_sparring_quality", 0))
		],
		"rows": [],
		"actions": [
			{
				"label": "Open Gym Hub",
				"command": "boxing.gym.open",
				"args": { "gym_tab": "common"},
				"refresh_tab": "gym",
				"suppress_popup": true
			},
			{
				"label": "Find Another Gym",
				"command": "boxing.gym.find",
				"args": { "section": "gym:find"},
				"refresh_tab": "gym:find",
				"suppress_popup": true
			}
		],
		"action_columns": 2
	}
func _boxing_hub_promotions_section(actor: Person) -> Dictionary:
	var rows: Array = []

	if gs != null and gs.boxing_promotion_engine != null and gs.boxing_promotion_engine.has_method("get_promotion_catalog"):
		var catalog: Array = gs.boxing_promotion_engine.get_promotion_catalog(actor)
		for raw_company in catalog:
			if typeof(raw_company) != TYPE_DICTIONARY:
				continue

			var company: Dictionary = raw_company
			var eligible: bool = bool(company.get("eligible", false))
			var locked_reason: String = str(company.get("locked_reason", "")).strip_edges()
			var perks: Array = company.get("perks", []) if typeof(company.get("perks", [])) == TYPE_ARRAY else []

			rows.append({
				"row_type": "promotion_card",
				"title": str(company.get("name", "Unknown Promotion")),
				"body": "%s • Cut: %d%% • Booking Power: %d/100\nPerks: %s%s" % [
					str(company.get("tier", "basic")).capitalize(),
					int(company.get("cut_percent", 0)),
					int(company.get("booking_power", 0)),
					", ".join(perks),
					("\nLocked: %s" % locked_reason) if not eligible and locked_reason != "" else ""
				],
				"glow": float(company.get("glow", 0.2)),
				"eligible": eligible,
				"locked_reason": locked_reason,
				"action": {
					"label": "Sign with %s" % str(company.get("name", "Promotion")),
					"command": "boxing.promotion.sign",
					"args": { "promotion_id": str(company.get("id", ""))},
					"refresh_tab": "promotions",
					"suppress_popup": false
				} if eligible else {}
			})

	var promoter_name: String = str(actor.boxing_profile.get("promoter", "Unsigned")).strip_edges()
	if promoter_name == "":
		promoter_name = "Unsigned"

	return {
		"id": "promotions",
		"title": "Promotions",
		"emoji": "📣",
		"summary": "Promotional companies can book fights, raise opportunity quality, negotiate purses, and eventually open PPV/superfight lanes.",
		"lines": [
			"Current Promoter: %s" % promoter_name,
			"Media Heat: %d" % int(actor.boxing_profile.get("media_heat", 0)),
			"Fan Favorite: %d" % int(actor.boxing_profile.get("fan_favorite", 0)),
			"Promoter Trust: %d" % int(actor.boxing_profile.get("promoter_trust", 50)),
			"Amateurs and brand-new pros usually cannot sign yet."
		],
		"rows": rows,
		"row_columns": 2,
		"actions": [
			{ "label": "Fight Economy", "command": "boxing.economy.view", "refresh_tab": "promotions"}
		]
	}
func _ensure_boxing_growth_profile(actor: Person) -> void:
	if actor == null:
		return

	if not actor.boxing_profile.has("growth") or typeof(actor.boxing_profile.get("growth", {})) != TYPE_DICTIONARY:
		actor.boxing_profile ["growth"] = {
			"xp": 0,
			"total_levels": 0,
			"max_total_levels": 220,
			"max_skill_level": 20,
			"levels": {}
		}

	var growth: Dictionary = actor.boxing_profile ["growth"]
	if typeof(growth.get("levels", {})) != TYPE_DICTIONARY:
		growth ["levels"] = {}

	if not growth.has("xp"):
		growth ["xp"] = 0
	if not growth.has("total_levels"):
		growth ["total_levels"] = 0
	if not growth.has("max_total_levels"):
		growth ["max_total_levels"] = 220
	if not growth.has("max_skill_level"):
		growth ["max_skill_level"] = 20

	var levels: Dictionary = growth ["levels"]
	for skill in _boxing_growth_skill_contracts():
		var key: String = str(skill.get("key", ""))
		if key != "" and not levels.has(key):
			levels [key] = 0

	growth ["levels"] = levels
	actor.boxing_profile ["growth"] = growth


func _boxing_growth_skill_contracts() -> Array:
	return [
		{ "key": "jab_head", "label": "Jab Head", "rating": "jab"},
		{ "key": "straight_head", "label": "Straight Head", "rating": "cross"},
		{ "key": "left_hook_head", "label": "Left Hook Head", "rating": "left_hook"},
		{ "key": "right_hook_head", "label": "Right Hook Head", "rating": "right_hook"},
		{ "key": "left_uppercut_head", "label": "Left Uppercut Head", "rating": "left_uppercut"},
		{ "key": "right_uppercut_head", "label": "Right Uppercut Head", "rating": "right_uppercut"},
		{ "key": "jab_body", "label": "Jab Body", "rating": "body_work"},
		{ "key": "straight_body", "label": "Straight Body", "rating": "body_work"},
		{ "key": "left_hook_body", "label": "Left Hook Body", "rating": "body_work"},
		{ "key": "right_hook_body", "label": "Right Hook Body", "rating": "body_work"},
		{ "key": "left_uppercut_body", "label": "Left Uppercut Body", "rating": "body_work"},
		{ "key": "right_uppercut_body", "label": "Right Uppercut Body", "rating": "body_work"},
		{ "key": "combinations", "label": "Combinations", "rating": "combinations"},
		{ "key": "blocking", "label": "Blocking", "rating": "blocking"},
		{ "key": "head_movement", "label": "Head Movement", "rating": "head_movement"},
		{ "key": "chin", "label": "Chin", "rating": "chin"},
		{ "key": "heart", "label": "Heart", "rating": "heart"}
	]


func _boxing_growth_level_cost(next_level: int, skill_key: String = "") -> int:
	var clean_level: int = clamp(int(next_level), 1, 20)
	var clean_key: String = str(skill_key).strip_edges().to_lower()

	if clean_key == "":
		return 6 + (clean_level * 2)

	var base_cost: int = _boxing_growth_skill_base_cost(clean_key)
	var level_index: int = max(0, clean_level - 1)
	var level_step: int = max(2, int(round(float(base_cost) * 0.012)))
	var tier_pressure: int = int(floor(float(level_index) / 5.0)) * max(1, int(round(float(base_cost) * 0.008)))

	return max(1, base_cost + (level_index * level_step) + tier_pressure)


func _boxing_growth_skill_base_cost(skill_key: String) -> int:
	var clean_key: String = str(skill_key).strip_edges().to_lower()

	match clean_key:
		"jab_head":
			return 265
		"straight_head":
			return 343
		"left_hook_head":
			return 187
		"right_hook_head":
			return 187
		"left_uppercut_head":
			return 405
		"right_uppercut_head":
			return 405
		"jab_body":
			return 421
		"straight_body":
			return 395
		"left_hook_body":
			return 171
		"right_hook_body":
			return 171
		"left_uppercut_body":
			return 398
		"right_uppercut_body":
			return 398
		"combinations":
			return 338
		"blocking":
			return 400
		"head_movement":
			return 504
		"chin":
			return 410
		"heart":
			return 327
		_:
			return 265


func _boxing_growth_rating_value(ratings: Dictionary, rating_key: String, fallback: int = 50) -> int:
	var clean_key: String = str(rating_key).strip_edges()
	if clean_key == "":
		return clamp(fallback, 0, 100)

	return clamp(int(ratings.get(clean_key, fallback)), 0, 100)


func _boxing_growth_average_levels(levels: Dictionary, keys: Array) -> float:
	if keys.is_empty():
		return 0.0

	var total: float = 0.0
	var count: int = 0

	for raw_key in keys:
		var key: String = str(raw_key).strip_edges()
		if key == "":
			continue

		total += float(clamp(int(levels.get(key, 0)), 0, 20))
		count += 1

	if count <= 0:
		return 0.0

	return total / float(count)


func _boxing_growth_blended_athletic_stat(base_rating: int, level_average: float, damage_penalty: int = 0) -> int:
	var value: int = int(round((float(base_rating) * 0.76) + (clamp(level_average, 0.0, 20.0) * 1.35))) - max(0, damage_penalty)
	return clamp(value, 1, 100)


func _boxing_growth_profile_damage_value(profile: Dictionary, keys: Array) -> int:
	var best_value: int = 0

	for raw_key in keys:
		var direct_key: String = str(raw_key).strip_edges()
		if direct_key == "":
			continue

		if profile.has(direct_key):
			best_value = max(best_value, int(profile.get(direct_key, 0)))

	var damage_buckets: Array = [
		"career_damage",
		"fight_damage",
		"damage",
		"medical",
		"injury_profile",
		"long_term_damage"
	]

	for raw_bucket in damage_buckets:
		var bucket_key: String = str(raw_bucket).strip_edges()
		var raw_bucket_data = profile.get(bucket_key, {})
		if typeof(raw_bucket_data) != TYPE_DICTIONARY:
			continue

		var bucket: Dictionary = raw_bucket_data
		for raw_key in keys:
			var key: String = str(raw_key).strip_edges()
			if key == "":
				continue

			best_value = max(best_value, int(bucket.get(key, 0)))

	return clamp(best_value, 0, 100)


func _boxing_growth_athleticism_panel(actor: Person) -> Dictionary:
	if actor == null:
		return {
			"schema": "eralife.boxing_athleticism_panel",
			"version": 1,
			"available": false,
			"stats": []
		}

	var profile: Dictionary = actor.boxing_profile if typeof(actor.boxing_profile) == TYPE_DICTIONARY else {}
	var ratings: Dictionary = profile.get("ratings", {}) if typeof(profile.get("ratings", {})) == TYPE_DICTIONARY else {}
	var growth: Dictionary = profile.get("growth", {}) if typeof(profile.get("growth", {})) == TYPE_DICTIONARY else {}
	var levels: Dictionary = growth.get("levels", {}) if typeof(growth.get("levels", {})) == TYPE_DICTIONARY else {}

	var punch_power_base: int = int(round(float(
		_boxing_growth_rating_value(ratings, "left_hook", 50) +
		_boxing_growth_rating_value(ratings, "right_hook", 50) +
		_boxing_growth_rating_value(ratings, "left_uppercut", 50) +
		_boxing_growth_rating_value(ratings, "right_uppercut", 50) +
		_boxing_growth_rating_value(ratings, "body_work", 50)
	) / 5.0))

	var speed_base: int = int(round(float(
		_boxing_growth_rating_value(ratings, "jab", 50) +
		_boxing_growth_rating_value(ratings, "cross", 50) +
		_boxing_growth_rating_value(ratings, "head_movement", 50) +
		_boxing_growth_rating_value(ratings, "combinations", 50)
	) / 4.0))

	var endurance_base: int = int(round(float(
		_boxing_growth_rating_value(ratings, "heart", 50) +
		_boxing_growth_rating_value(ratings, "body_work", 50) +
		_boxing_growth_rating_value(ratings, "combinations", 50)
	) / 3.0))

	var conditioning_base: int = int(round(float(
		_boxing_growth_rating_value(ratings, "heart", 50) +
		_boxing_growth_rating_value(ratings, "blocking", 50) +
		_boxing_growth_rating_value(ratings, "body_work", 50)
	) / 3.0))

	var toughness_base: int = int(round(float(
		_boxing_growth_rating_value(ratings, "chin", 50) +
		_boxing_growth_rating_value(ratings, "blocking", 50) +
		_boxing_growth_rating_value(ratings, "heart", 50)
	) / 3.0))

	var reflexes_base: int = int(round(float(
		_boxing_growth_rating_value(ratings, "head_movement", 50) +
		_boxing_growth_rating_value(ratings, "jab", 50) +
		_boxing_growth_rating_value(ratings, "blocking", 50)
	) / 3.0))

	var concussion_damage: int = _boxing_growth_profile_damage_value(profile, ["concussion", "concussions", "head_trauma", "brain_damage"])
	var body_damage: int = _boxing_growth_profile_damage_value(profile, ["body_damage", "rib_damage", "torso_damage"])
	var cut_damage: int = _boxing_growth_profile_damage_value(profile, ["cuts", "cut_damage", "scar_tissue", "facial_cuts"])
	var swelling_damage: int = _boxing_growth_profile_damage_value(profile, ["swelling", "swelling_damage", "facial_swelling"])
	var fatigue_damage: int = _boxing_growth_profile_damage_value(profile, ["fatigue", "wear", "career_wear", "ring_wear"])

	var strength: int = _boxing_growth_blended_athletic_stat(punch_power_base, _boxing_growth_average_levels(levels, [
		"left_hook_head",
		"right_hook_head",
		"left_uppercut_head",
		"right_uppercut_head",
		"left_uppercut_body",
		"right_uppercut_body"
	]), int(round(float(body_damage) * 0.1)))

	var speed: int = _boxing_growth_blended_athletic_stat(speed_base, _boxing_growth_average_levels(levels, [
		"jab_head",
		"straight_head",
		"head_movement",
		"combinations"
	]), int(round(float(fatigue_damage) * 0.08)))

	var endurance: int = _boxing_growth_blended_athletic_stat(endurance_base, _boxing_growth_average_levels(levels, [
		"heart",
		"jab_body",
		"straight_body",
		"combinations"
	]), int(round(float(fatigue_damage) * 0.16)))

	var conditioning: int = _boxing_growth_blended_athletic_stat(conditioning_base, _boxing_growth_average_levels(levels, [
		"heart",
		"blocking",
		"jab_body",
		"straight_body"
	]), int(round(float(fatigue_damage + body_damage) * 0.1)))

	var toughness: int = _boxing_growth_blended_athletic_stat(toughness_base, _boxing_growth_average_levels(levels, [
		"chin",
		"heart",
		"blocking"
	]), int(round(float(concussion_damage + body_damage) * 0.08)))

	var reflexes: int = _boxing_growth_blended_athletic_stat(reflexes_base, _boxing_growth_average_levels(levels, [
		"head_movement",
		"jab_head",
		"blocking",
		"combinations"
	]), int(round(float(concussion_damage) * 0.12)))

	var cuts: int = clamp(94 + int(round(float(_boxing_growth_rating_value(ratings, "chin", 50) - 50) * 0.1)) - cut_damage, 1, 100)
	var swelling: int = clamp(92 + int(round(float(_boxing_growth_rating_value(ratings, "chin", 50) - 50) * 0.12)) - swelling_damage, 1, 100)

	return {
		"schema": "eralife.boxing_athleticism_panel",
		"version": 1,
		"available": true,
		"title": "Athleticism",
		"summary": "Physical tools and visible damage resistance.",
		"stats": [
			{ "key": "strength", "label": "Strength", "value": strength, "description": "Power, leverage, and body force."},
			{ "key": "speed", "label": "Speed", "value": speed, "description": "Hand speed, entry speed, and tempo."},
			{ "key": "endurance", "label": "Endurance", "value": endurance, "description": "Late-round gas and long exchanges."},
			{ "key": "conditioning", "label": "Conditioning", "value": conditioning, "description": "How well the body keeps shape under stress."},
			{ "key": "toughness", "label": "Toughness", "value": toughness, "description": "Damage tolerance and refusal to fold."},
			{ "key": "reflexes", "label": "Reflexes", "value": reflexes, "description": "Reaction timing and defensive snap."},
			{ "key": "cuts", "label": "Cuts", "value": cuts, "description": "Resistance to opening up from punches."},
			{ "key": "swelling", "label": "Swelling", "value": swelling, "description": "Resistance to eye and facial swelling."}
		],
		"damage_sources": {
			"concussion": concussion_damage,
			"body": body_damage,
			"cuts": cut_damage,
			"swelling": swelling_damage,
			"fatigue": fatigue_damage
		}
	}


func _command_upgrade_growth_skill(actor: Person, args: Dictionary = {}) -> Dictionary:
	if actor == null:
		return { "success": false, "text": "\n\nNo boxer selected."}

	if not bool(actor.boxing_profile.get("is_boxer", false)):
		return { "success": false, "text": "\n\nI need to begin boxing before I can grow boxing skills."}

	_ensure_boxing_growth_profile(actor)

	var skill_key: String = str(args.get("skill", "")).strip_edges()
	if skill_key == "":
		return { "success": false, "text": "\n\nNo growth skill was selected."}

	var skill_contract: Dictionary = {}
	for row in _boxing_growth_skill_contracts():
		if str(row.get("key", "")) == skill_key:
			skill_contract = row
			break

	if skill_contract.is_empty():
		return { "success": false, "text": "\n\nThat growth skill does not exist."}

	var growth: Dictionary = actor.boxing_profile ["growth"]
	var levels: Dictionary = growth ["levels"]

	var current_level: int = int(levels.get(skill_key, 0))
	var max_skill_level: int = int(growth.get("max_skill_level", 20))
	var max_total_levels: int = int(growth.get("max_total_levels", 220))
	var total_levels: int = int(growth.get("total_levels", 0))
	var xp: int = int(growth.get("xp", 0))

	if current_level >= max_skill_level:
		return { "success": false, "text": "\n\n%s is already maxed." % str(skill_contract.get("label", skill_key))}

	if total_levels >= max_total_levels:
		return { "success": false, "text": "\n\nMy boxing build is capped. I cannot max everything."}

	var requested_target_level: int = int(args.get("target_level", 0))
	var requested_levels: int = int(args.get("levels_requested", args.get("levels", 1)))

	if requested_target_level <= 0:
		requested_target_level = current_level + max(1, requested_levels)

	requested_target_level = clamp(requested_target_level, current_level + 1, max_skill_level)

	var levels_to_buy: int = max(1, requested_target_level - current_level)
	var remaining_total_slots: int = max(0, max_total_levels - total_levels)

	if levels_to_buy > remaining_total_slots:
		return {
			"success": false,
			"text": "\n\nMy boxing build only has %d level slots left." % remaining_total_slots,
			"popup_title": "Build Cap",
			"popup_text": "My boxing build only has %d level slots left." % remaining_total_slots,
			"popup_footer": "Tap anywhere to continue."
		}

	var total_cost: int = 0
	for purchase_level in range(current_level + 1, requested_target_level + 1):
		total_cost += _boxing_growth_level_cost(purchase_level, skill_key)

	if xp < total_cost:
		return {
			"success": false,
			"text": "\n\nI need %d XP to upgrade %s to level %d." % [
				total_cost,
				str(skill_contract.get("label", skill_key)),
				requested_target_level
			],
			"popup_title": "Not Enough XP",
			"popup_text": "I need %d XP to upgrade %s to level %d." % [
				total_cost,
				str(skill_contract.get("label", skill_key)),
				requested_target_level
			],
			"popup_footer": "Tap anywhere to continue."
		}

	growth ["xp"] = xp - total_cost
	growth ["total_levels"] = total_levels + levels_to_buy
	levels [skill_key] = requested_target_level
	growth ["levels"] = levels
	actor.boxing_profile ["growth"] = growth

	var rating_key: String = str(skill_contract.get("rating", ""))
	if rating_key != "":
		var ratings: Dictionary = actor.boxing_profile.get("ratings", {}) if typeof(actor.boxing_profile.get("ratings", {})) == TYPE_DICTIONARY else {}
		ratings [rating_key] = clamp(int(ratings.get(rating_key, 50)) + levels_to_buy, 1, 100)
		actor.boxing_profile ["ratings"] = ratings

	var txt: String = "\n\n🥊 I upgraded %s to level %d." % [
		str(skill_contract.get("label", skill_key)),
		requested_target_level
	]

	if levels_to_buy > 1:
		txt = "\n\n🥊 I upgraded %s by %d levels to level %d." % [
			str(skill_contract.get("label", skill_key)),
			levels_to_buy,
			requested_target_level
		]

	return {
		"success": true,
		"text": txt,
		"popup_title": "Boxing Growth",
		"popup_text": txt.strip_edges(),
		"popup_footer": "Tap anywhere to continue.",
		"levels_bought": levels_to_buy,
		"target_level": requested_target_level,
		"xp_spent": total_cost,
		"remaining_xp": int(growth.get("xp", 0))
	}


func _command_retire(actor: Person, _args: Dictionary = {}) -> Dictionary:
	if actor == null:
		return { "success": false, "text": "\n\nNo boxer selected."}
	if not bool(actor.boxing_profile.get("is_boxer", false)):
		return { "success": false, "text": "\n\nI do not have a boxing career to retire from."}
	if bool(actor.boxing_profile.get("retired", false)):
		return { "success": false, "text": "\n\nI am already retired from boxing."}

	actor.boxing_profile ["retired"] = true
	actor.boxing_profile ["retired_year"] = int(gs.year if gs != null else 0)

	var txt: String = "\n\n🧤 I retired from boxing."

	return {
		"success": true,
		"text": txt,
		"popup_title": "Retired",
		"popup_text": "You retired from boxing. Your Boxing Hub remains available as legacy history.",
		"popup_footer": "Tap anywhere to continue."
	}
func _boxing_award_candidate_lines() -> Array:
	var lines: Array = ["Next Year Award Candidates:"]
	var rows: Array = []

	if gs == null:
		return ["No world loaded."]

	for npc in gs.npcs:
		if npc == null or not npc.alive:
			continue
		if not bool(npc.boxing_profile.get("is_boxer", false)):
			continue
		if bool(npc.boxing_profile.get("retired", false)):
			continue

		var score: int = 0
		var record: Dictionary = npc.boxing_profile.get("record", {}) if typeof(npc.boxing_profile.get("record", {})) == TYPE_DICTIONARY else {}
		score += int(record.get("wins", 0)) * 5
		score += int(record.get("kos", 0)) * 3
		score -= int(record.get("losses", 0)) * 4
		score += int(npc.fame)
		score += int(npc.boxing_profile.get("media_heat", 0))
		score += int(npc.boxing_profile.get("belts", []).size()) * 30 if typeof(npc.boxing_profile.get("belts", [])) == TYPE_ARRAY else 0

		rows.append({
			"name": ("%s %s" % [npc.first_name, npc.last_name]).strip_edges(),
			"division": str(npc.boxing_profile.get("weight_class", "")),
			"record": _format_record(record),
			"score": score
		})

	rows.sort_custom(func (a, b): return int(a.get("score", 0)) > int(b.get("score", 0)))

	for i in range(min(10, rows.size())):
		var row: Dictionary = rows [i]
		lines.append("#%d %s — %s — %s" % [
			i + 1,
			str(row.get("name", "Unknown Fighter")),
			str(row.get("division", "")),
			str(row.get("record", "0-0-0"))
		])

	if lines.size() == 1:
		lines.append("No candidates yet.")

	return lines


func _boxing_award_winner_lines() -> Array:
	var winners_raw: Variant = {}
	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		winners_raw = gs.scenario_state.get("boxing_award_winners", {})

	var winners: Dictionary = winners_raw if typeof(winners_raw) == TYPE_DICTIONARY else {}
	var lines: Array = ["Previous Award Winners:"]

	if winners.is_empty():
		lines.append("No previous boxing award winners have been recorded yet.")
		return lines

	var years: Array = winners.keys()
	years.sort()
	years.reverse()

	for raw_year in years:
		var year_rows: Array = winners.get(raw_year, []) if typeof(winners.get(raw_year, [])) == TYPE_ARRAY else []
		for raw_row in year_rows:
			if typeof(raw_row) != TYPE_DICTIONARY:
				continue
			var row: Dictionary = raw_row
			lines.append("%s — %s: %s" % [
				str(raw_year),
				str(row.get("award", "Award")),
				str(row.get("winner_name", "Unknown Fighter"))
			])

	return lines


func _my_legacy_lines(actor: Person) -> Array:
	var record: Dictionary = actor.boxing_profile.get("record", {}) if typeof(actor.boxing_profile.get("record", {})) == TYPE_DICTIONARY else {}
	var growth: Dictionary = actor.boxing_profile.get("growth", {}) if typeof(actor.boxing_profile.get("growth", {})) == TYPE_DICTIONARY else {}
	var belts: Array = actor.boxing_profile.get("belts", []) if typeof(actor.boxing_profile.get("belts", [])) == TYPE_ARRAY else []

	return [
		"Legacy Goals:",
		"Become ranked in your division.",
		"Win a world title.",
		"Become unified or undisputed.",
		"Build a distinct fighter style through Growth.",
		"",
		"My Legacy Progress:",
		"Record: %s" % _format_record(record),
		"Division Rank: %d" % int(actor.boxing_profile.get("division_rank", -1)),
		"Belts: %d" % belts.size(),
		"Undisputed: %s" % ("Yes" if bool(actor.boxing_profile.get("undisputed", false)) else "No"),
		"Growth Build: %d/%d levels" % [
			int(growth.get("total_levels", 0)),
			int(growth.get("max_total_levels", 220))
		],
		"World Tier: %s" % str(actor.boxing_profile.get("boxing_world_tier", "local")).capitalize()
	]


func _retired_boxer_lines() -> Array:
	var rows: Array = []
	if gs == null:
		return ["No world loaded."]

	for npc in gs.npcs:
		if npc == null:
			continue
		if not bool(npc.boxing_profile.get("is_boxer", false)):
			continue
		if not bool(npc.boxing_profile.get("retired", false)):
			continue

		rows.append("%s %s — %s — %s" % [
			npc.first_name,
			npc.last_name,
			str(npc.boxing_profile.get("weight_class", "")),
			_format_record(npc.boxing_profile.get("record", {}))
		])

	if rows.is_empty():
		rows.append("No retired boxers yet.")

	return rows
func get_max_fights_per_year() -> int:
	var policies: Dictionary = active_contract.get("policies", {}) if typeof(active_contract.get("policies", {})) == TYPE_DICTIONARY else {}
	return max(1, int(policies.get("max_fights_per_year", DEFAULT_MAX_FIGHTS_PER_YEAR)))

func get_fights_this_year(person: Person) -> int:
	if person == null:
		return 0

	var current_year: int = int(gs.year) if gs != null else 0
	var count: int = 0
	var history: Array = person.boxing_profile.get("fight_history", []) if typeof(person.boxing_profile.get("fight_history", [])) == TYPE_ARRAY else []

	for raw_row in history:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = raw_row
		if int(row.get("year", -999999)) == current_year:
			count += 1

	return count

func can_fighter_take_fight_this_year(person: Person) -> bool:
	if person == null:
		return false
	return get_fights_this_year(person) < get_max_fights_per_year()

func on_fight_completed(payload: Dictionary) -> void:
	if typeof(payload) != TYPE_DICTIONARY:
		return

	var year_key: String = str(int(gs.year if gs != null else 0))
	if not runtime_state.has("fight_counts_by_year"):
		runtime_state ["fight_counts_by_year"] = {}

	var counts: Dictionary = runtime_state ["fight_counts_by_year"] if typeof(runtime_state ["fight_counts_by_year"]) == TYPE_DICTIONARY else {}
	if not counts.has(year_key):
		counts [year_key] = {}

	for id_key in ["winner_id", "loser_id"]:
		var pid: int = int(payload.get(id_key, -1))
		if pid <= 0:
			continue
		var pid_key: String = str(pid)
		counts [year_key] [pid_key] = int(counts [year_key].get(pid_key, 0)) + 1

	runtime_state ["fight_counts_by_year"] = counts
func _command_join_gym(actor: Person, args: Dictionary = {}) -> Dictionary:
	if gs == null or gs.boxing_gym_engine == null:
		return { "success": false, "text": "BoxingGymEngine is unavailable."}

	var gym_id: String = str(args.get("gym_id", "")).strip_edges()
	if gym_id == "":
		return { "success": false, "text": "No gym was selected."}

	return gs.boxing_gym_engine.join_gym(actor, gym_id)


func _command_open_gym(actor: Person, args: Dictionary = {}) -> Dictionary:
	var gym_id: String = str(actor.boxing_profile.get("gym_id", "")).strip_edges()
	if gym_id == "":
		return {
			"success": false,
			"text": "\n\nI do not belong to a boxing gym yet.",
			"refresh_tab": "gym"
		}

	return {
		"success": true,
		"text": "",
		"type": "open_boxing_gym_hub",
		"gym_id": gym_id,
		"gym_tab": str(args.get("gym_tab", args.get("tab", "common"))).strip_edges(),
		"suppress_diary": true,
		"suppress_popup": true,
		"refresh_tab": "gym"
	}


func _command_sign_promotion(actor: Person, args: Dictionary = {}) -> Dictionary:
	if gs == null or gs.boxing_promotion_engine == null:
		return { "success": false, "text": "BoxingPromotionEngine is unavailable."}

	var promotion_id: String = str(args.get("promotion_id", "")).strip_edges()
	if promotion_id == "":
		return { "success": false, "text": "No promotional company was selected."}

	return gs.boxing_promotion_engine.sign_with_promotion(actor, promotion_id)
func _command_start_career(actor: Person, args: Dictionary = {}) -> Dictionary:
	if gs == null or gs.boxing_engine == null:
		return { "success": false, "text": "🥊 BoxingEngine is unavailable."}
	return gs.boxing_engine.start_boxing_career(actor, args)

func _command_personal_training(actor: Person, _args: Dictionary = {}) -> Dictionary:
	if gs == null or gs.boxing_training_engine == null:
		return { "success": false, "text": "❌ BoxingTrainingEngine is unavailable."}
	return gs.boxing_training_engine.train_fighter(actor)

func _command_sparring(actor: Person, _args: Dictionary = {}) -> Dictionary:
	if actor == null or not bool(actor.boxing_profile.get("is_boxer", false)):
		return { "success": false, "text": "🥊 I am not a boxer yet."}

	if bool(actor.boxing_profile.get("retired", false)):
		return { "success": false, "text": "🧤 I am retired from boxing."}

	var ratings: Dictionary = actor.boxing_profile.get("ratings", {}) if typeof(actor.boxing_profile.get("ratings", {})) == TYPE_DICTIONARY else {}
	var improved: Array = []

	for stat in ["defense", "ring_iq", "footwork", "chin", "cardio"]:
		if randi() % 100 < 48:
			ratings [stat] = clamp(int(ratings.get(stat, 50)) + randi_range(1, 2), 1, 100)
			improved.append(stat)

	actor.boxing_profile ["ratings"] = ratings
	actor.health = clamp(float(actor.health) - randf() * 4.0, 0.0, 100.0)
	actor.mental_health = clamp(float(actor.mental_health) - randf() * 1.5, 0.0, 100.0)

	if gs != null and gs.boxing_injury_engine != null and randi() % 100 < 14:
		gs.boxing_injury_engine.apply_training_injury(actor)

	var txt: String = "🥊 I sparred live rounds and sharpened my %s." % ", ".join(improved) if not improved.is_empty() else "🥊 I sparred live rounds and stayed sharp."

	if gs != null:
		if gs.event_bus != null:
			gs.event_bus.emit(ActionEventTypes.BOXING_TRAINED, {
				"npc_id": int(actor.id),
				"text": txt,
				"training_kind": "sparring"
			})
		if gs.narrative_engine != null:
			gs.narrative_engine.log_event(actor, { "type": "text", "text": txt})

	return {
		"success": true,
		"text": txt,
		"training_kind": "sparring",
		"improved": improved
	}

func _command_book_fight(actor: Person, _args: Dictionary = {}) -> Dictionary:
	if not can_fighter_take_fight_this_year(actor):
		return {
			"success": false,
			"text": "🥊 I have already fought %d times this year. My team will not book more than %d fights in one year." % [
				get_fights_this_year(actor),
				get_max_fights_per_year()
			]
		}

	if gs == null or gs.boxing_matchmaking_engine == null:
		return {
			"success": false,
			"text": "❌ BoxingMatchmakingEngine is unavailable."
		}

	return gs.boxing_matchmaking_engine.book_player_fight(actor)

func _command_view_record(actor: Person, _args: Dictionary = {}) -> Dictionary:
	if gs == null or gs.boxing_engine == null:
		return { "success": false, "text": "❌ BoxingEngine is unavailable."}
	return {
		"success": true,
		"text": gs.boxing_engine.describe_record(actor)
	}

func _command_view_rivalries(actor: Person, _args: Dictionary = {}) -> Dictionary:
	var rival_ids: Array = actor.boxing_profile.get("rivalries", []) if typeof(actor.boxing_profile.get("rivalries", [])) == TYPE_ARRAY else []
	if rival_ids.is_empty():
		return { "success": true, "text": "🥊 I do not have any active boxing rivalries."}

	var names: Array = []
	for raw_id in rival_ids:
		var rival = gs.get_or_reactivate_npc_by_id(int(raw_id)) if gs != null and gs.has_method("get_or_reactivate_npc_by_id") else null
		if rival != null:
			names.append("%s %s" % [rival.first_name, rival.last_name])

	if names.is_empty():
		return { "success": true, "text": "🥊 I do not have any active boxing rivalries."}

	return {
		"success": true,
		"text": "🥊 Active Rivalries: %s" % ", ".join(names)
	}

func _command_callout(actor: Person, _args: Dictionary = {}) -> Dictionary:
	if gs == null:
		return { "success": false, "text": "❌ GameState unavailable."}

	var division: String = str(actor.boxing_profile.get("weight_class", ""))
	var candidates: Array = []

	for npc in gs.npcs:
		if npc == null or npc == actor or not npc.alive:
			continue
		if not bool(npc.boxing_profile.get("is_boxer", false)):
			continue
		if str(npc.boxing_profile.get("weight_class", "")) != division:
			continue
		candidates.append(npc)

	if candidates.is_empty():
		return { "success": false, "text": "❌ No opponent is available to call out right now."}

	var target = candidates [randi() % candidates.size()]
	var callout_txt: String = "🎤 I called out %s %s for a future fight." % [target.first_name, target.last_name]

	var callouts: Array = actor.boxing_profile.get("callouts", []) if typeof(actor.boxing_profile.get("callouts", [])) == TYPE_ARRAY else []
	callouts.append({
		"target_id": int(target.id),
		"year": int(gs.year),
		"division": division
	})
	actor.boxing_profile ["callouts"] = callouts

	var actor_rivals: Array = actor.boxing_profile.get("rivalries", []) if typeof(actor.boxing_profile.get("rivalries", [])) == TYPE_ARRAY else []
	var target_rivals: Array = target.boxing_profile.get("rivalries", []) if typeof(target.boxing_profile.get("rivalries", [])) == TYPE_ARRAY else []

	if int(target.id) not in actor_rivals:
		actor_rivals.append(int(target.id))
	if int(actor.id) not in target_rivals:
		target_rivals.append(int(actor.id))

	actor.boxing_profile ["rivalries"] = actor_rivals
	target.boxing_profile ["rivalries"] = target_rivals

	if gs.event_bus != null:
		gs.event_bus.emit(ActionEventTypes.BOXING_TRASH_TALKED, {
			"npc_id": int(actor.id),
			"target_id": int(target.id),
			"text": callout_txt
		})

	if gs.narrative_engine != null:
		gs.narrative_engine.log_event(actor, { "type": "text", "text": callout_txt})

	return { "success": true, "text": callout_txt}

func _command_change_next_weight(actor: Person, _args: Dictionary = {}) -> Dictionary:
	if gs == null or gs.boxing_weight_engine == null:
		return { "success": false, "text": "❌ Boxing weight management is unavailable."}

	var current_division: String = str(actor.boxing_profile.get("weight_class", "Lightweight"))
	var target_division: String = gs.boxing_weight_engine.get_next_division(current_division)
	return gs.boxing_weight_engine.change_division(actor, target_division, "contract_player_manual")

func _command_last_fight_log(actor: Person, _args: Dictionary = {}) -> Dictionary:
	if gs == null or gs.boxing_engine == null:
		return { "success": false, "text": "❌ BoxingEngine is unavailable."}
	return {
		"success": true,
		"text": gs.boxing_engine.describe_last_fight_log(actor)
	}

func _command_enter_amateur(actor: Person, _args: Dictionary = {}) -> Dictionary:
	if gs == null:
		return { "success": false, "text": "❌ GameState unavailable."}

	if gs.era_engine == null or not gs.era_engine.supports_world_title_boxing():
		return { "success": false, "text": "\n❌\n Boxing is not available in this era."}

	if bool(actor.boxing_profile.get("turned_pro", false)):
		return { "success": false, "text": "\n❌\n I am already a professional boxer."}

	if gs.boxing_amateur_engine != null and gs.boxing_amateur_engine.has_method("enter_amateur_circuit"):
		return gs.boxing_amateur_engine.enter_amateur_circuit(actor, "player_contract")

	if not bool(actor.boxing_profile.get("is_boxer", false)) and gs.boxing_fighter_engine != null:
		gs.boxing_fighter_engine.initialize_fighter(actor)

	actor.boxing_profile ["turned_pro"] = false
	actor.boxing_profile ["amateur_circuit"] ["is_amateur"] = true
	actor.boxing_profile ["record"] = {
		"wins": 0,
		"losses": 0,
		"draws": 0,
		"kos": 0
	}

	var amateur_txt: String = "\n🥇\n I entered the amateur boxing circuit."
	if gs.narrative_engine != null:
		gs.narrative_engine.log_event(actor, { "type": "text", "text": amateur_txt})

	return { "success": true, "text": amateur_txt}

func _normalize_fighter_profile(person: Person) -> void:
	if person == null:
		return

	if typeof(person.boxing_profile) != TYPE_DICTIONARY:
		person.boxing_profile = {}

	var profile: Dictionary = person.boxing_profile

	if not profile.has("contract_schema_version"):
		profile ["contract_schema_version"] = CONTRACT_VERSION
	if not profile.has("record") or typeof(profile.get("record", {})) != TYPE_DICTIONARY:
		profile ["record"] = { "wins": 0, "losses": 0, "draws": 0, "kos": 0}
	if not profile.has("amateur_record") or typeof(profile.get("amateur_record", {})) != TYPE_DICTIONARY:
		profile ["amateur_record"] = { "wins": 0, "losses": 0, "draws": 0, "kos": 0}
	if not profile.has("amateur_circuit") or typeof(profile.get("amateur_circuit", {})) != TYPE_DICTIONARY:
		profile ["amateur_circuit"] = {
			"is_amateur": false,
			"tournaments_won": 0,
			"olympic_medals": 0,
			"olympic_gold": false
		}
	if not profile.has("fight_history") or typeof(profile.get("fight_history", [])) != TYPE_ARRAY:
		profile ["fight_history"] = []
	if not profile.has("belts") or typeof(profile.get("belts", [])) != TYPE_ARRAY:
		profile ["belts"] = []
	if not profile.has("rivalries") or typeof(profile.get("rivalries", [])) != TYPE_ARRAY:
		profile ["rivalries"] = []
	if not profile.has("callouts") or typeof(profile.get("callouts", [])) != TYPE_ARRAY:
		profile ["callouts"] = []
	if not profile.has("ratings") or typeof(profile.get("ratings", {})) != TYPE_DICTIONARY:
		profile ["ratings"] = {}
	if not profile.has("boxing_contract_flags") or typeof(profile.get("boxing_contract_flags", {})) != TYPE_DICTIONARY:
		profile ["boxing_contract_flags"] = {}

	person.boxing_profile = profile

func _record_command(command_id: String, actor: Person, args: Dictionary, result: Dictionary) -> void:
	var row:= {
		"schema": "eralife.boxing_command_log_row",
		"version": CONTRACT_VERSION,
		"command_id": command_id,
		"person_id": int(actor.id) if actor != null else -1,
		"year": int(gs.year if gs != null else 0),
		"args": args.duplicate(true),
		"success": bool(result.get("success", false)),
		"text": str(result.get("text", "")),
		"created_at_ms": int(Time.get_ticks_msec())
	}
	command_log.append(row)
	if command_log.size() > 200:
		command_log.pop_front()

func _apply_contracts_to_boxing_engines() -> void:
	if gs == null:
		return

	var engines: Dictionary = _contract_engine_map()
	var applied: Array = []
	var missing: Array = []
	var skipped: Array = []

	for raw_engine_id in engines.keys():
		var engine_id: String = str(raw_engine_id).strip_edges()
		if engine_id == "":
			continue

		var engine_contract: Dictionary = _safe_contract_dictionary(engines.get(engine_id, {}))
		if engine_contract.is_empty():
			skipped.append(engine_id)
			continue

		var engine_obj: Variant = gs.get(engine_id)
		if engine_obj == null:
			missing.append(engine_id)
			continue

		if engine_obj.has_method("set_meta"):
			engine_obj.set_meta("boxing_contract_engine_layered", true)
			engine_obj.set_meta("boxing_contract_engine_id", engine_id)
			engine_obj.set_meta("boxing_contract_schema", str(engine_contract.get("schema", "")))
			engine_obj.set_meta("boxing_contract_role", str(engine_contract.get("role", "")))
			engine_obj.set_meta("boxing_contract", engine_contract.duplicate(true))

		if engine_obj.has_method("set_contract"):
			engine_obj.set_contract(engine_contract)

		applied.append(engine_id)

	runtime_state ["last_engine_contract_apply"] = {
		"schema": "eralife.boxing_contract_apply_report",
		"version": CONTRACT_VERSION,
		"applied": applied,
		"missing": missing,
		"skipped": skipped,
		"applied_count": applied.size(),
		"missing_count": missing.size(),
		"skipped_count": skipped.size(),
		"applied_at_ms": int(Time.get_ticks_msec())
	}
func _contract_engine_map() -> Dictionary:
	var engines_raw: Variant = active_contract.get("engines", {})
	if typeof(engines_raw) == TYPE_DICTIONARY:
		return (engines_raw as Dictionary)
	return {}


func _safe_contract_dictionary(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary)
	return {}


func get_engine_contract(engine_id: String) -> Dictionary:
	var clean_id: String = str(engine_id).strip_edges()
	if clean_id == "":
		return {}

	var engines: Dictionary = _contract_engine_map()
	var contract: Dictionary = _safe_contract_dictionary(engines.get(clean_id, {}))
	return contract.duplicate(true)


func get_engine_policies(engine_id: String) -> Dictionary:
	var contract: Dictionary = get_engine_contract(engine_id)
	var policies: Dictionary = _safe_contract_dictionary(contract.get("policies", {}))
	return policies.duplicate(true)


func get_engine_policy(engine_id: String, policy_key: String, fallback: Variant = null) -> Variant:
	var policies: Dictionary = get_engine_policies(engine_id)
	var clean_key: String = str(policy_key).strip_edges()
	if clean_key == "":
		return fallback
	if policies.has(clean_key):
		return policies.get(clean_key)
	return fallback


func get_engine_rules(engine_id: String) -> Dictionary:
	var contract: Dictionary = get_engine_contract(engine_id)
	var rules: Dictionary = _safe_contract_dictionary(contract.get("rules", {}))
	return rules.duplicate(true)


func get_engine_rule(engine_id: String, rule_key: String, fallback: Variant = null) -> Variant:
	var rules: Dictionary = get_engine_rules(engine_id)
	var clean_key: String = str(rule_key).strip_edges()
	if clean_key == "":
		return fallback
	if rules.has(clean_key):
		return rules.get(clean_key)
	return fallback


func get_boxing_policy(policy_key: String, fallback: Variant = null) -> Variant:
	var policies: Dictionary = _safe_contract_dictionary(active_contract.get("policies", {}))
	var clean_key: String = str(policy_key).strip_edges()
	if clean_key == "":
		return fallback
	if policies.has(clean_key):
		return policies.get(clean_key)
	return fallback


func get_command_contract(command_id: String) -> Dictionary:
	var clean_command: String = str(command_id).strip_edges().to_lower()
	var commands: Dictionary = _safe_contract_dictionary(active_contract.get("commands", {}))
	return _safe_contract_dictionary(commands.get(clean_command, {})).duplicate(true)


func get_boxing_ui_surface(surface_id: String) -> Dictionary:
	var clean_surface: String = str(surface_id).strip_edges()
	var surfaces: Dictionary = _safe_contract_dictionary(active_contract.get("ui_surfaces", {}))
	return _safe_contract_dictionary(surfaces.get(clean_surface, {})).duplicate(true)


func record_boxing_contract_event(event_name: String, payload: Dictionary = {}) -> void:
	var event_log: Array = runtime_state.get("contract_event_log", []) if typeof(runtime_state.get("contract_event_log", [])) == TYPE_ARRAY else []
	event_log.append({
		"event_name": str(event_name).strip_edges(),
		"payload": payload.duplicate(true),
		"year": int(gs.year if gs != null else 0),
		"created_at_ms": int(Time.get_ticks_msec())
	})

	var max_events: int = int(get_boxing_policy("contract_event_log_limit", 160))
	if max_events < 20:
		max_events = 20

	if event_log.size() > max_events:
		event_log = event_log.slice(event_log.size() - max_events, event_log.size())

	runtime_state ["contract_event_log"] = event_log

func _format_record(record_raw: Variant) -> String:
	var record: Dictionary = record_raw if typeof(record_raw) == TYPE_DICTIONARY else {}
	return "%d-%d-%d (%d KOs)" % [
		int(record.get("wins", 0)),
		int(record.get("losses", 0)),
		int(record.get("draws", 0)),
		int(record.get("kos", 0))
	]

func _build_training_lines(actor: Person) -> Array:
	var ratings: Dictionary = actor.boxing_profile.get("ratings", {}) if typeof(actor.boxing_profile.get("ratings", {})) == TYPE_DICTIONARY else {}

	return [
		"Endurance: %d" % int(ratings.get("endurance", ratings.get("cardio", 0))),
		"Cardio: %d" % int(ratings.get("cardio", 0)),
		"Strength: %d" % int(ratings.get("strength", ratings.get("power", 0))),
		"Jab: %d" % int(ratings.get("jab", 0)),
		"Cross: %d" % int(ratings.get("cross", 0)),
		"Left Hook: %d" % int(ratings.get("left_hook", 0)),
		"Right Hook: %d" % int(ratings.get("right_hook", 0)),
		"Left Uppercut: %d" % int(ratings.get("left_uppercut", 0)),
		"Right Uppercut: %d" % int(ratings.get("right_uppercut", 0)),
		"Defense: %d" % int(ratings.get("defense", 0)),
		"Footwork: %d" % int(ratings.get("footwork", 0)),
		"Ring IQ: %d" % int(ratings.get("ring_iq", 0))
	]

func _build_record_lines(actor: Person) -> Array:
	return [
		"Professional Record: %s" % _format_record(actor.boxing_profile.get("record", {})),
		"Amateur Record: %s" % _format_record(actor.boxing_profile.get("amateur_record", {})),
		"Division Rank: %d" % int(actor.boxing_profile.get("division_rank", -1)),
		"Promoter: %s" % str(actor.boxing_profile.get("promoter", "Unsigned")),
		"Gym: %s" % str(actor.boxing_profile.get("gym_name", "No gym"))
	]

func _build_belt_lines(actor: Person) -> Array:
	var belts: Array = actor.boxing_profile.get("belts", []) if typeof(actor.boxing_profile.get("belts", [])) == TYPE_ARRAY else []
	var out: Array = []

	out.append("Division: %s" % str(actor.boxing_profile.get("weight_class", "Unknown")))
	out.append("Sanctioning Bodies: WBA, WBC, IBF, WBO")
	out.append("Lineal / Ring Belt: Ring Magazine")
	out.append("Special Titles: Franchise Champion, Interim Champion, Regular Champion")

	if belts.is_empty():
		out.append("No world titles yet.")
	else:
		out.append("Current Titles:")
		for belt in belts:
			out.append("- %s" % str(belt))

	if bool(actor.boxing_profile.get("undisputed", false)):
		out.append("Status: Undisputed Champion")

	return out
func _build_venue_lines(_actor: Person) -> Array:
	var venues: Array = []
	if gs != null and gs.boxing_combat_resolution_engine != null and gs.boxing_combat_resolution_engine.has_method("_boxing_venue_contracts"):
		venues = gs.boxing_combat_resolution_engine._boxing_venue_contracts()

	var out: Array = ["Contract-driven venues:"]
	for raw_venue in venues:
		if typeof(raw_venue) != TYPE_DICTIONARY:
			continue
		var venue: Dictionary = raw_venue
		out.append("- %s • %s • Capacity %d" % [
			str(venue.get("name", "Unknown Venue")),
			str(venue.get("tier", "local")).capitalize(),
			int(venue.get("capacity", 0))
		])

	if out.size() == 1:
		out.append("No venues registered yet.")

	return out


func _build_business_lines(_actor: Person) -> Array:
	var out: Array = []
	out.append("Sanctioning corporations:")
	out.append("- WBC • WBA • WBO • IBF")
	out.append("- Ring Magazine tracks the lineal champion.")
	out.append("Promotional companies:")
	out.append("- Golden Boy Promotions")
	out.append("- Top Rank")
	out.append("- Matchroom Boxing")
	out.append("- Premier Boxing Champions")
	out.append("- Mayweather Promotions")
	out.append("- Local Gym Syndicate")
	out.append("Each organization can exist as a faction-backed boxing corporation.")
	return out

func _build_history_lines(actor: Person) -> Array:
	var history: Array = actor.boxing_profile.get("fight_history", []) if typeof(actor.boxing_profile.get("fight_history", [])) == TYPE_ARRAY else []
	var out: Array = []

	if history.is_empty():
		out.append("No fight history yet.")
	else:
		var start_index: int = max(0, history.size() - 5)
		for i in range(start_index, history.size()):
			var row: Dictionary = history [i] if typeof(history [i]) == TYPE_DICTIONARY else {}
			out.append("%s vs %s by %s in %s" % [
				"Won" if bool(row.get("won", false)) else "Lost",
				str(row.get("opponent_name", "Unknown")),
				str(row.get("result_type", "Decision")),
				str(row.get("division", "Unknown"))
			])

	var rival_ids: Array = actor.boxing_profile.get("rivalries", []) if typeof(actor.boxing_profile.get("rivalries", [])) == TYPE_ARRAY else []
	out.append("Active Rivalries: %d" % rival_ids.size())
	return out

func _build_amateur_lines(actor: Person) -> Array:
	var circuit: Dictionary = actor.boxing_profile.get("amateur_circuit", {}) if typeof(actor.boxing_profile.get("amateur_circuit", {})) == TYPE_DICTIONARY else {}
	return [
		"Amateur Active: %s" % ("Yes" if bool(circuit.get("is_amateur", false)) else "No"),
		"Tournaments Won: %d" % int(circuit.get("tournaments_won", 0)),
		"Olympic Medals: %d" % int(circuit.get("olympic_medals", 0)),
		"Olympic Gold: %s" % ("Yes" if bool(circuit.get("olympic_gold", false)) else "No")
	]
func get_division_target_count(division: String) -> int:
	var policies: Dictionary = active_contract.get("policies", {}) if typeof(active_contract.get("policies", {})) == TYPE_DICTIONARY else {}
	var division_targets: Dictionary = policies.get("division_refill_targets", {}) if typeof(policies.get("division_refill_targets", {})) == TYPE_DICTIONARY else {}

	if division_targets.has(division):
		return max(4, int(division_targets.get(division, 8)))

	return 10 if division == "Heavyweight" else 8

func should_auto_fill_vacant_champion(division: String, belt: String) -> bool:
	if gs == null or gs.boxing_title_engine == null:
		return true

	var policies: Dictionary = active_contract.get("policies", {}) if typeof(active_contract.get("policies", {})) == TYPE_DICTIONARY else {}
	if not bool(policies.get("auto_fill_vacant_champions", true)):
		return false

	if gs.player != null and gs.boxing_title_engine.has_method("is_undisputed_champion"):
		if gs.boxing_title_engine.is_undisputed_champion(gs.player, division):
			return false

	if str(belt) == "Ring Magazine":
		return false

	return true

func get_title_bodies() -> Array:
	var policies: Dictionary = active_contract.get("policies", {}) if typeof(active_contract.get("policies", {})) == TYPE_DICTIONARY else {}
	var bodies: Array = policies.get("title_bodies", []) if typeof(policies.get("title_bodies", [])) == TYPE_ARRAY else []
	if bodies.is_empty():
		bodies = ["WBA", "WBC", "IBF", "WBO"]
	return bodies

func get_lineal_belt_name() -> String:
	var policies: Dictionary = active_contract.get("policies", {}) if typeof(active_contract.get("policies", {})) == TYPE_DICTIONARY else {}
	return str(policies.get("lineal_belt", "Ring Magazine"))

func _command_confirm_fight(actor: Person, _args: Dictionary = {}) -> Dictionary:
	if gs == null or gs.boxing_matchmaking_engine == null:
		return {
			"success": false,
			"text": "❌ BoxingMatchmakingEngine is unavailable."
		}

	if not gs.boxing_matchmaking_engine.has_method("confirm_player_fight"):
		return {
			"success": false,
			"text": "❌ Confirm fight adapter is unavailable."
		}

	return gs.boxing_matchmaking_engine.confirm_player_fight(actor)

func _command_cancel_fight(actor: Person, _args: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"text": "❌ No boxer selected."
		}

	actor.boxing_profile ["pending_fight_contract"] = {}
	actor.boxing_profile ["scheduled_opponent_id"] = -1
	return {
		"success": true,
		"text": "🥊 I canceled the pending fight before the contract was finalized."
	}

func _command_opponent_preview(actor: Person, _args: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"text": "❌ No boxer selected."
		}

	var pending: Dictionary = actor.boxing_profile.get("pending_fight_contract", {}) if typeof(actor.boxing_profile.get("pending_fight_contract", {})) == TYPE_DICTIONARY else {}
	if pending.is_empty():
		return {
			"success": false,
			"text": "🥊 I do not have a pending fight to preview."
		}

	var opponent_id: int = int(pending.get("opponent_id", -1))
	var opponent = gs.get_npc_by_id(opponent_id) if gs != null else null
	if opponent == null:
		return {
			"success": false,
			"text": "🥊 The pending opponent could not be found."
		}

	if gs.boxing_combat_resolution_engine != null and gs.boxing_combat_resolution_engine.has_method("build_opponent_preview"):
		return gs.boxing_combat_resolution_engine.build_opponent_preview(actor, opponent, pending.get("meta", {}))

	return {
		"success": true,
		"text": "Opponent: %s %s" % [opponent.first_name, opponent.last_name]
	}

func _command_pound_for_pound(_actor: Person, _args: Dictionary = {}) -> Dictionary:
	if gs == null or gs.boxing_ranking_engine == null:
		return {
			"success": false,
			"text": "❌ BoxingRankingEngine is unavailable."
		}

	if not gs.boxing_ranking_engine.has_method("build_pound_for_pound_payload"):
		return {
			"success": false,
			"text": "❌ Pound-for-pound adapter is unavailable."
		}

	var payload: Dictionary = gs.boxing_ranking_engine.build_pound_for_pound_payload()
	var lines: Array = []
	for row in payload.get("fighters", []):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		lines.append("#%d %s — %s, %s, score %d" % [
			int(row.get("rank", 0)),
			str(row.get("name", "")),
			str(row.get("record_text", "")),
			str(row.get("archetype_name", "")),
			int(row.get("score", 0))
		])

	return {
		"success": true,
		"text": "🥊 Pound-for-Pound Rankings\n%s" % "\n".join(lines),
		"payload": payload
	}

func _command_fight_economy(_actor: Person, _args: Dictionary = {}) -> Dictionary:
	if gs == null or gs.boxing_fight_economy_engine == null:
		return {
			"success": false,
			"text": "❌ BoxingFightEconomyEngine is unavailable."
		}

	var ledger: Array = gs.boxing_fight_economy_engine.fight_economy_ledger if typeof(gs.boxing_fight_economy_engine.fight_economy_ledger) == TYPE_ARRAY else []
	if ledger.is_empty():
		return {
			"success": true,
			"text": "💰 No boxing fight economy history yet."
		}

	var lines: Array = []
	var start_index: int = max(0, ledger.size() - 8)
	for i in range(start_index, ledger.size()):
		var row: Dictionary = ledger [i] if typeof(ledger [i]) == TYPE_DICTIONARY else {}
		lines.append("%s def. %s by %s — PPV: %d, Revenue: $%s" % [
			str(row.get("winner_name", "")),
			str(row.get("loser_name", "")),
			str(row.get("result_type", "")),
			int(row.get("ppv_buys", 0)),
			_format_compact_money(float(row.get("gross_revenue", 0.0)))
		])

	return {
		"success": true,
		"text": "💰 Boxing Fight Economy\n%s" % "\n".join(lines)
	}

func _format_compact_money(value: float) -> String:
	var abs_value: float = abs(value)
	if abs_value >= 1000000000.0:
		return "%.2fB" % (value / 1000000000.0)
	if abs_value >= 1000000.0:
		return "%.2fM" % (value / 1000000.0)
	if abs_value >= 1000.0:
		return "%.1fK" % (value / 1000.0)
	return "%.0f" % value
func actor_has_boxing_hub_access(person: Person = null) -> bool:
	var actor: Person = person
	if actor == null and gs != null:
		actor = gs.player
	if actor == null:
		return false
	if typeof(actor.boxing_profile) != TYPE_DICTIONARY:
		return false

	var profile: Dictionary = actor.boxing_profile

	if bool(profile.get("retired", false)):
		return true
	if bool(profile.get("boxing_hub_unlocked", false)):
		return true
	if bool(profile.get("boxing_career_started_by_player", false)):
		return true
	if bool(profile.get("is_boxer", false)):
		return true
	if bool(profile.get("turned_pro", false)):
		return true

	var raw_amateur: Variant = profile.get("amateur_circuit", {})
	if typeof(raw_amateur) == TYPE_DICTIONARY:
		var amateur_circuit: Dictionary = raw_amateur as Dictionary
		if bool(amateur_circuit.get("is_amateur", false)):
			return true

	return false
func _build_default_contract() -> Dictionary:
	return {
		"schema": CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": "default_boxing_contract_domain",
		"allow_unknown_future_commands": true,
		"policies": {
			"execution": "contract_adapter_only",
			"unknown_fields": "preserve",
			"max_fights_per_year": DEFAULT_MAX_FIGHTS_PER_YEAR,
			"minimum_boxing_start_age": 7,
			"maximum_ordinary_new_amateur_seed_age": 18,
			"youth_amateur_max_age": 17,
			"adult_amateur_min_age": 18,
			"auto_turn_pro_at_18": false,
			"boxing_world_population_policy": "persistent_generated_faction_loop",
			"growth_total_level_cap": 220,
			"growth_skill_level_cap": 20,
			"training_xp_gain": 8,
			"title_lineage_policy": "preserve_historical_lineage",
			"media_policy": "contract_template_driven",
			"ui_policy": "hub_payload_driven",
			"boxing_hud_visibility_rule": "player_is_boxer",
			"combat_resolution": "deterministic_stochastic_hybrid",
			"title_bodies": ["WBA", "WBC", "IBF", "WBO"],
			"lineal_belt": "Ring Magazine",
			"undisputed_requires": ["WBA", "WBC", "IBF", "WBO"],
			"auto_fill_vacant_champions": true,
			"division_refill_targets": {
				"Flyweight": 8,
				"Bantamweight": 8,
				"Featherweight": 8,
				"Lightweight": 10,
				"Welterweight": 10,
				"Middleweight": 10,
				"Light Heavyweight": 8,
				"Heavyweight": 10
			}
		},
		"engines": {
			"boxing_title_engine": {
				"schema": "eralife.boxing_title_engine_contract",
				"version": CONTRACT_VERSION,
				"role": "title_lineage_adapter"
			},
			"boxing_training_engine": {
				"schema": "eralife.boxing_training_engine_contract",
				"version": CONTRACT_VERSION,
				"role": "training_adapter",
				"policies": {
					"training_improvement_chance": 48,
					"training_injury_chance": 10,
					"unknown_fields": "preserve"
				}
			},
			"boxing_promotion_engine": {
				"schema": "eralife.boxing_promotion_engine_contract",
				"version": CONTRACT_VERSION,
				"role": "promotion_pressure_adapter",
				"policies": {
					"max_duck_chance": 55,
					"unknown_fields": "preserve"
				}
			},
			"boxing_engine": {
				"schema": "eralife.boxing_engine_contract",
				"version": CONTRACT_VERSION,
				"role": "domain_orchestrator"
			},
			"boxing_fighter_engine": {
				"schema": "eralife.boxing_fighter_engine_contract",
				"version": CONTRACT_VERSION,
				"role": "fighter_profile_factory"
			},
			"boxing_fight_sim_engine": {
				"schema": "eralife.boxing_fight_sim_engine_contract",
				"version": CONTRACT_VERSION,
				"role": "fight_resolution_orchestrator"
			},
			"boxing_injury_engine": {
				"schema": "eralife.boxing_injury_engine_contract",
				"version": CONTRACT_VERSION,
				"role": "injury_and_wear_adapter",
				"policies": {
					"wear_retirement_threshold": 75,
					"wear_retirement_chance": 20,
					"unknown_fields": "preserve"
				}
			},
			"boxing_legacy_engine": {
				"schema": "eralife.boxing_legacy_engine_contract",
				"version": CONTRACT_VERSION,
				"role": "family_legacy_adapter"
			},
			"boxing_mandatory_engine": {
				"schema": "eralife.boxing_mandatory_engine_contract",
				"version": CONTRACT_VERSION,
				"role": "mandatory_challenger_adapter",
				"policies": {
					"mandatory_deadline_years": 1,
					"unknown_fields": "preserve"
				}
			},
			"boxing_matchmaking_engine": {
				"schema": "eralife.boxing_matchmaking_engine_contract",
				"version": CONTRACT_VERSION,
				"role": "fight_booking_adapter"
			},
			"boxing_media_engine": {
				"schema": "eralife.boxing_media_engine_contract",
				"version": CONTRACT_VERSION,
				"role": "media_narrative_adapter"
			},
			"boxing_ranking_engine": {
				"schema": "eralife.boxing_ranking_engine_contract",
				"version": CONTRACT_VERSION,
				"role": "rankings_and_pfp_adapter",
				"policies": {
					"division_ranking_limit": 15,
					"pound_for_pound_limit": 15,
					"unknown_fields": "preserve"
				}
			},
			"boxing_rivalry_engine": {
				"schema": "eralife.boxing_rivalry_engine_contract",
				"version": CONTRACT_VERSION,
				"role": "rivalry_heat_adapter",
				"policies": {
					"rivalry_heat_from_fight": 15,
					"rivalry_heat_from_ko": 10,
					"rivalry_threshold": 30,
					"unknown_fields": "preserve"
				}
			},
			"boxing_weight_engine": {
				"schema": "eralife.boxing_weight_engine_contract",
				"version": CONTRACT_VERSION,
				"role": "weight_class_adapter",
				"policies": {
					"auto_division_change_chance": 12,
					"unknown_fields": "preserve"
				}
			},
			"boxing_combat_resolution_engine": {
				"schema": "eralife.boxing_combat_resolution_engine_contract",
				"version": CONTRACT_VERSION,
				"role": "exchange_resolution_adapter"
			},
			"boxing_fight_economy_engine": {
				"schema": "eralife.boxing_fight_economy_engine_contract",
				"version": CONTRACT_VERSION,
				"role": "fight_economy_adapter"
			},
			"boxing_amateur_engine": {
				"schema": "eralife.boxing_amateur_engine_contract",
				"version": CONTRACT_VERSION,
				"role": "amateur_path_adapter"
			}
		},
		"commands": {
			"boxing.hub.view": { "native_adapter_available": true, "mutates_reality": false},
			"boxing.career.start": { "native_adapter_available": true, "mutates_reality": true},
			"boxing.training.personal": { "native_adapter_available": true, "mutates_reality": true},
			"boxing.training.sparring": { "native_adapter_available": true, "mutates_reality": true},
			"boxing.fight.book": { "native_adapter_available": true, "mutates_reality": true, "yearly_cap": DEFAULT_MAX_FIGHTS_PER_YEAR},
			"boxing.fight.preview": { "native_adapter_available": true, "mutates_reality": false},
			"boxing.fight.confirm": { "native_adapter_available": true, "mutates_reality": true},
			"boxing.fight.cancel": { "native_adapter_available": true, "mutates_reality": true},
			"boxing.record.view": { "native_adapter_available": true, "mutates_reality": false},
			"boxing.rivalries.view": { "native_adapter_available": true, "mutates_reality": false},
			"boxing.rivalries.callout": { "native_adapter_available": true, "mutates_reality": true},
			"boxing.weight.change_next": { "native_adapter_available": true, "mutates_reality": true},
			"boxing.history.last_log": { "native_adapter_available": true, "mutates_reality": false},
			"boxing.amateur.enter": { "native_adapter_available": true, "mutates_reality": true},
			"boxing.rankings.pfp": { "native_adapter_available": true, "mutates_reality": false},
			"boxing.rankings.view": { "native_adapter_available": true, "mutates_reality": false},
			"boxing.awards.candidates": { "native_adapter_available": true, "mutates_reality": false},
			"boxing.awards.winners": { "native_adapter_available": true, "mutates_reality": false},
			"boxing.growth.upgrade": { "native_adapter_available": true, "mutates_reality": true},
			"boxing.history.mine": { "native_adapter_available": true, "mutates_reality": false},
			"boxing.legacy.retired_boxers": { "native_adapter_available": true, "mutates_reality": false},
			"boxing.career.retire": { "native_adapter_available": true, "mutates_reality": true},
			"boxing.gym.find": { "native_adapter_available": true, "mutates_reality": false},
			"boxing.gym.join": { "native_adapter_available": true, "mutates_reality": true},
			"boxing.gym.open": { "native_adapter_available": true, "mutates_reality": false},
			"boxing.gym.tab": { "native_adapter_available": true, "mutates_reality": false},
			"boxing.promotion.sign": { "native_adapter_available": true, "mutates_reality": true},
			"boxing.promotions.view": { "native_adapter_available": true, "mutates_reality": false},
			"boxing.economy.view": { "native_adapter_available": true, "mutates_reality": false}
		},
		"ui_surfaces": {
			"boxing_hub": {
				"surface_id": "boxing_hub",
				"surface_type": "hud_hub",
				"icon": "🥊",
				"visibility_rule": "player_is_boxer",
				"entry_action": "Begin Boxing Career",
					"sections": ["fight", "rankings", "awards", "legacy", "growth", "history", "amateur", "gym", "promotions"],
				"payload_method": "build_hub_payload",
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