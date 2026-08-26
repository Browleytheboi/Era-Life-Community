extends Resource
class_name CrimeEngine

var gs
var weapons_engine

func _init(_gs):
	gs = _gs
	weapons_engine = gs.weapons_engine

var ERA_CRIME_MODIFIERS = {
	"Ancient Era": { "police_strength": 20, "forensics": 0, "brutality": 60},
	"Medieval Era": { "police_strength": 30, "forensics": 5, "brutality": 70},
	"Industrial Era": { "police_strength": 50, "forensics": 20, "brutality": 60},
	"Modern Era": { "police_strength": 75, "forensics": 60, "brutality": 40},
	"Future Era": { "police_strength": 95, "forensics": 90, "brutality": 30}
}

var CRIMES = [
	{ "name": "Rob a Store", "base_success": 40, "danger": 20},
	{ "name": "Mug a Stranger", "base_success": 50, "danger": 15},
	{ "name": "Bank Robbery", "base_success": 20, "danger": 60},
	{ "name": "Assassination", "base_success": 25, "danger": 70},
	{ "name": "Break Into a Home", "base_success": 55, "danger": 10},
]





func commit_crime(crime_name: String, weapon_name: String) -> Dictionary:
	var crime: Dictionary = _find_crime_definition(crime_name)
	if crime.is_empty():
		return {
			"result": "fail",
			"text": "\n \n Unknown crime.",
			"popup_title": "Crime",
			"popup_text": "Unknown crime.",
			"popup_footer": "Tap anywhere to continue."
		}

	if not weapons_engine.weapon_exists_in_era(weapon_name):
		return {
			"result": "fail",
			"text": "\n \n %s does not exist in the %s." % [weapon_name, gs.era.name],
			"popup_title": "Crime",
			"popup_text": "%s does not exist in the %s." % [weapon_name, gs.era.name],
			"popup_footer": "Tap anywhere to continue."
		}

	if not weapons_engine.owns_weapon(weapon_name):
		return {
			"result": "fail",
			"text": "\n \n You do not own a %s." % weapon_name,
			"popup_title": "Crime",
			"popup_text": "You do not own a %s." % weapon_name,
			"popup_footer": "Tap anywhere to continue."
		}

	var weapon_data_raw = weapons_engine.get_weapon_data(weapon_name)
	var weapon_data: Dictionary = weapon_data_raw if typeof(weapon_data_raw) == TYPE_DICTIONARY else {}
	var era_mod: Dictionary = _justice_profile_for_era(gs.era.name)

	var base: int = int(crime.get("base_success", 0))
	var danger: int = int(crime.get("danger", 0))

	base -= int(float(era_mod.get("police_strength", 50.0)) / 5.0)
	danger += int(float(era_mod.get("forensics", 50.0)) / 4.0)

	if not bool(weapon_data.get("legal", true)):
		base -= 15
		danger += 25

	if bool(weapon_data.get("license_required", false)) and not ("Licensed_" + weapon_name in gs.player.traits):
		base -= 10
		danger += 15

	if str(weapon_data.get("type", "")) == "gun" and gs.era.name in ["Ancient Era", "Medieval Era"]:
		base -= 40
		danger += 50

	var skill: int = 0
	if gs.capability_graph_engine != null:
		skill = int(gs.capability_graph_engine.level(gs.player, "Robbery"))
	base += skill * 5

	var roll: int = randi() % 100
	var success: bool = roll < base

	if success:
		var min_payout: int = int(crime.get("min_payout", 200))
		var max_payout: int = int(crime.get("max_payout", 2000))
		var payout: int = randi_range(min_payout, max_payout)
		if gs.bank_engine != null and gs.bank_engine.has_method("request_actor_bank_action"):
			gs.bank_engine.request_actor_bank_action(gs.player, {
				"action": "crime_payout_cash",
				"amount": payout,
				"currency": "USD",
				"source": "crime_engine",
				"text": "Crime payout became physical cash."
			}, {
				"source": "crime_engine",
				"crime_name": crime_name
			})
		else:
			gs.player.bank_balance += payout

		var msg: String = "\n \n I committed %s using a %s and escaped with %d coins." % [
			crime_name,
			weapon_name,
			payout
		]
		_record_justice_event(msg, ActionEventTypes.NPC_COMMITTED_CRIME, {
			"crime_name": crime_name,
			"weapon_name": weapon_name,
			"payout": payout
		})

		if gs.event_bus != null:
			gs.event_bus.emit(ActionEventTypes.CRIME_RUMOR_SPREAD, {
				"npc_id": gs.player.id,
				"text": "Rumors spread that %s pulled off a %s." % [
					gs.player.first_name,
					crime_name
				],
				"crime_name": crime_name
			})

		var caught_after_success_threshold: int = max(
			5,
			danger - int(float(skill) * 1.5) + int(float(era_mod.get("forensics", 50.0)) * 0.2)
		)
		if (randi() % 100) < caught_after_success_threshold:
			return _start_justice_flow(
				crime_name,
				weapon_name,
				crime,
				era_mod,
				weapon_data,
				true,
				payout,
				msg
			)

		return {
			"result": "success",
			"text": msg,
			"popup_title": "Crime",
			"popup_text": "You committed %s using a %s and escaped with %d coins." % [
				crime_name,
				weapon_name,
				payout
			],
			"popup_footer": "Tap anywhere to continue."
		}

	var arrest_roll: int = randi() % 100
	if arrest_roll < danger:
		return _start_justice_flow(
			crime_name,
			weapon_name,
			crime,
			era_mod,
			weapon_data,
			false,
			0,
			""
		)

	var fail_text: String = "\n \n I failed to commit %s but escaped." % crime_name
	_record_justice_event(fail_text, ActionEventTypes.NPC_COMMITTED_CRIME, {
		"crime_name": crime_name,
		"weapon_name": weapon_name,
		"escaped": true
	})
	return {
		"result": "fail",
		"text": fail_text,
		"popup_title": "Crime",
		"popup_text": "You failed to commit %s but escaped." % crime_name,
		"popup_footer": "Tap anywhere to continue."
	}





func _handle_arrest_scaled(crime_name: String, era_mod: Dictionary) -> Dictionary:
	var crime: Dictionary = _find_crime_definition(crime_name)
	if gs != null and gs.scenario_engine != null:
		return _start_justice_flow(
			crime_name,
			"",
			crime,
			era_mod,
			{},
			false,
			0,
			""
		)

	var case_data: Dictionary = _build_justice_case(
		crime_name,
		"",
		crime,
		era_mod,
		{},
		false,
		0,
		""
	)
	return _finalize_sentence(case_data, 1.0, "summary_judgment")



func reduce_prison_time():
	if gs != null and gs.prison_engine != null and gs.prison_engine.has_method("yearly_tick_actor"):
		var report: Dictionary = gs.prison_engine.yearly_tick_actor(gs.player)
		if bool(report.get("released", false)):
			if gs.player != null:
				gs.player.memories.append(str(report.get("text", "I finished my prison sentence.")))
			gs.queue_year_resolution_popup({
				"popup_title": str(report.get("popup_title", "Release")),
				"popup_text": str(report.get("popup_text", report.get("text", "I finished my prison sentence."))),
				"popup_footer": str(report.get("popup_footer", "Tap anywhere to continue."))
			})
			_clear_player_from_justice_institutions(int(gs.player.id))
			_flag_justice_projection_dirty()
		return

	_ensure_justice_state()
	if gs == null or gs.player == null:
		return

	var profile: Dictionary = _justice_profile_for_era(gs.era.name)
	var new_traits: Array = []
	var release_text: String = ""
	var prison_event_text: String = ""
	var prison_id: String = str(gs.scenario_state.get("justice_prison_id", "")).strip_edges()

	for raw_trait in gs.player.traits:
		var t: String = str(raw_trait)

		if t.begins_with("InPrison_"):
			var left: int = int(t.split("_") [1])
			left -= 1

			if left > 0:
				var parole_window: bool = left <= 2
				var parole_chance: int = int(profile.get("parole_chance", 0))
				if parole_window and parole_chance > 0 and (randi() % 100) < parole_chance:
					new_traits.append("OnParole_1")
					release_text = "I was released on parole."
					continue

				if (randi() % 100) < int(profile.get("prison_harm_chance", 0)):
					gs.player.health = max(0, int(gs.player.health) - randi_range(1, 6))
					prison_event_text = "Prison took a toll on my body this year."

				new_traits.append("InPrison_%d" % left)
			else:
				release_text = "I finished my prison sentence."

		elif t.begins_with("OnParole_"):
			var parole_left: int = int(t.split("_") [1]) - 1
			if parole_left > 0:
				new_traits.append("OnParole_%d" % parole_left)
		else:
			new_traits.append(t)

	gs.player.traits = new_traits

	if prison_event_text != "":
		gs.player.memories.append(prison_event_text)
		gs.queue_year_resolution_popup({
			"popup_title": "Prison",
			"popup_text": prison_event_text,
			"popup_footer": "Tap anywhere to continue."
		})

	if release_text != "":
		gs.player.memories.append(release_text)
		gs.queue_year_resolution_popup({
			"popup_title": "Release",
			"popup_text": release_text,
			"popup_footer": "Tap anywhere to continue."
		})
		if prison_id != "":
			gs.scenario_state ["justice_prison_id"] = ""
		_clear_player_from_justice_institutions(int(gs.player.id))
		_flag_justice_projection_dirty()
func _ensure_justice_state() -> void:
	if gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	gs.scenario_state ["crime_justice_case"] = gs.scenario_state.get("crime_justice_case", {})
	gs.scenario_state ["justice_institutions"] = gs.scenario_state.get("justice_institutions", {})
	gs.scenario_state ["justice_prison_id"] = str(gs.scenario_state.get("justice_prison_id", ""))
	gs.scenario_state ["justice_record"] = gs.scenario_state.get("justice_record", [])

func get_justice_institutions() -> Dictionary:
	_ensure_justice_state()
	var raw: Variant = gs.scenario_state.get("justice_institutions", {})
	return raw.duplicate(true) if typeof(raw) == TYPE_DICTIONARY else {}

func _set_justice_institutions(data: Dictionary) -> void:
	_ensure_justice_state()
	gs.scenario_state ["justice_institutions"] = data.duplicate(true)

func _set_active_justice_case(case_data: Dictionary) -> void:
	_ensure_justice_state()
	gs.scenario_state ["crime_justice_case"] = case_data.duplicate(true)

func _get_active_justice_case() -> Dictionary:
	_ensure_justice_state()
	var raw: Variant = gs.scenario_state.get("crime_justice_case", {})
	return raw.duplicate(true) if typeof(raw) == TYPE_DICTIONARY else {}

func _clear_active_justice_case() -> void:
	_ensure_justice_state()
	gs.scenario_state ["crime_justice_case"] = {}

func _justice_key(text: String) -> String:
	var out: String = str(text).to_lower().strip_edges()
	for ch in [" ", "/", "\\", ":", ".", ",", "-", "'", "\"", "(", ")", "[", "]", "{", "}"]:
		out = out.replace(ch, "_")
	while out.find("__") != -1:
		out = out.replace("__", "_")
	return out

func _justice_realm_id(npc) -> String:
	if npc == null:
		return ""
	if str(npc.hidden_realm_id).strip_edges() != "":
		return "hidden:%s" % str(npc.hidden_realm_id).strip_edges()
	if int(npc.realm_id) > 0:
		return "realm:%d" % int(npc.realm_id)
	if str(npc.home_country).strip_edges() != "":
		return "country:%s" % _justice_key(str(npc.home_country))
	return ""

func _justice_profile_for_era(era_name: String) -> Dictionary:
	var profiles: Dictionary = {
		"Ancient Era": {
			"police_strength": 20.0,
			"forensics": 0.0,
			"brutality": 80.0,
			"due_process": 12.0,
			"corruption": 58.0,
			"jury_fairness": 8.0,
			"lawyer_quality": 12.0,
			"parole_chance": 0,
			"prison_harm_chance": 38,
		},
		"Medieval Era": {
			"police_strength": 30.0,
			"forensics": 5.0,
			"brutality": 76.0,
			"due_process": 18.0,
			"corruption": 52.0,
			"jury_fairness": 12.0,
			"lawyer_quality": 16.0,
			"parole_chance": 2,
			"prison_harm_chance": 34,
		},
		"Industrial Era": {
			"police_strength": 50.0,
			"forensics": 20.0,
			"brutality": 60.0,
			"due_process": 42.0,
			"corruption": 36.0,
			"jury_fairness": 42.0,
			"lawyer_quality": 40.0,
			"parole_chance": 10,
			"prison_harm_chance": 22,
		},
		"Modern Era": {
			"police_strength": 75.0,
			"forensics": 60.0,
			"brutality": 42.0,
			"due_process": 68.0,
			"corruption": 24.0,
			"jury_fairness": 62.0,
			"lawyer_quality": 70.0,
			"parole_chance": 18,
			"prison_harm_chance": 12,
		},
		"Future Era": {
			"police_strength": 95.0,
			"forensics": 92.0,
			"brutality": 34.0,
			"due_process": 78.0,
			"corruption": 18.0,
			"jury_fairness": 72.0,
			"lawyer_quality": 86.0,
			"parole_chance": 24,
			"prison_harm_chance": 8,
		}
	}
	return profiles.get(era_name, profiles ["Modern Era"]).duplicate(true)

func _crime_catalog() -> Array:
	return [
		{
			"name": "Rob a Store",
			"base_success": 40,
			"danger": 20,
			"severity": 1,
			"violent": false,
			"charge_success": "robbery",
			"charge_fail": "attempted robbery",
			"sentence_success": 4,
			"sentence_fail": 2,
			"min_payout": 200,
			"max_payout": 2000
		},
		{
			"name": "Mug a Stranger",
			"base_success": 50,
			"danger": 15,
			"severity": 2,
			"violent": true,
			"charge_success": "robbery and assault",
			"charge_fail": "attempted robbery and assault",
			"sentence_success": 6,
			"sentence_fail": 3,
			"min_payout": 100,
			"max_payout": 900
		},
		{
			"name": "Bank Robbery",
			"base_success": 20,
			"danger": 60,
			"severity": 4,
			"violent": true,
			"charge_success": "armed bank robbery",
			"charge_fail": "attempted armed bank robbery",
			"sentence_success": 14,
			"sentence_fail": 7,
			"min_payout": 5000,
			"max_payout": 50000
		},
		{
			"name": "Assassination",
			"base_success": 25,
			"danger": 70,
			"severity": 5,
			"violent": true,
			"charge_success": "murder",
			"charge_fail": "attempted murder",
			"sentence_success": 30,
			"sentence_fail": 18,
			"min_payout": 2500,
			"max_payout": 15000
		},
		{
			"name": "Break Into a Home",
			"base_success": 55,
			"danger": 10,
			"severity": 2,
			"violent": false,
			"charge_success": "burglary",
			"charge_fail": "attempted burglary",
			"sentence_success": 7,
			"sentence_fail": 4,
			"min_payout": 300,
			"max_payout": 3000
		}
	]

func _find_crime_definition(crime_name: String) -> Dictionary:
	for raw_crime in _crime_catalog():
		var crime: Dictionary = raw_crime if typeof(raw_crime) == TYPE_DICTIONARY else {}
		if str(crime.get("name", "")) == crime_name:
			return crime.duplicate(true)
	return {}

func _justice_faction_bias_snapshot() -> Dictionary:
	if gs == null or gs.player == null:
		return {}
	if gs.scenario_engine == null:
		return {}
	var transient: Dictionary = gs.scenario_engine.get_transient_bias_for_npc(int(gs.player.id))
	var raw: Variant = transient.get("faction_pressure", {})
	return raw.duplicate(true) if typeof(raw) == TYPE_DICTIONARY else {}

func _count_prior_convictions() -> int:
	_ensure_justice_state()
	var raw: Variant = gs.scenario_state.get("justice_record", [])
	if typeof(raw) != TYPE_ARRAY:
		return 0
	var total: int = 0
	for entry_raw in raw:
		if typeof(entry_raw) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_raw
		if bool(entry.get("convicted", false)):
			total += 1
	return total

func _build_member_map(member_ids: Array, role: String) -> Dictionary:
	var out: Dictionary = {}
	var seen: Dictionary = {}
	for raw_member_id in member_ids:
		var npc_id: int = int(raw_member_id)
		if npc_id <= 0 or seen.has(npc_id):
			continue
		seen [npc_id] = true
		out [str(npc_id)] = {
			"npc_id": npc_id,
			"role": role
		}
	return out

func _collect_local_adults(city: String, country: String, max_count: int = 4) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for raw_npc in gs.npcs:
		var npc: Person = raw_npc
		if npc == null or not npc.alive:
			continue
		if int(npc.age) < 18:
			continue
		var npc_city: String = str(npc.home_city if str(npc.home_city).strip_edges() != "" else npc.birth_city).strip_edges()
		var npc_country: String = str(npc.home_country if str(npc.home_country).strip_edges() != "" else npc.birth_country).strip_edges()
		if city != "" and npc_city != city:
			continue
		if country != "" and npc_country != country:
			continue
		if seen.has(int(npc.id)):
			continue
		seen [int(npc.id)] = true
		out.append(int(npc.id))
		if out.size() >= max_count:
			break
	return out

func _job_matches_any(job_text: String, keywords: Array) -> bool:
	var lowered: String = job_text.to_lower()
	for raw_keyword in keywords:
		var keyword: String = str(raw_keyword).to_lower().strip_edges()
		if keyword != "" and lowered.find(keyword) != -1:
			return true
	return false

func _collect_local_justice_staff(city: String, country: String, keywords: Array,
max_count: int = 5) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for raw_npc in gs.npcs:
		var npc: Person = raw_npc
		if npc == null or not npc.alive:
			continue
		var npc_city: String = str(npc.home_city if str(npc.home_city).strip_edges() != "" else npc.birth_city).strip_edges()
		var npc_country: String = str(npc.home_country if str(npc.home_country).strip_edges() != "" else npc.birth_country).strip_edges()
		if city != "" and npc_city != city:
			continue
		if country != "" and npc_country != country:
			continue
		if not _job_matches_any(str(npc.job).strip_edges(), keywords):
			continue
		if seen.has(int(npc.id)):
			continue
		seen [int(npc.id)] = true
		out.append(int(npc.id))
		if out.size() >= max_count:
			break
	if out.is_empty():
		var fallback_count: int = max(2, int(ceil(float(max_count) * 0.5)))
		out = _collect_local_adults(city, country, fallback_count)
	return out

func _upsert_institution_member(institutions: Dictionary, institution_id: String, npc_id: int, role: String) -> void:
	if institution_id == "" or npc_id <= 0:
		return
	var entry_raw: Variant = institutions.get(institution_id, {})
	var entry: Dictionary = entry_raw if typeof(entry_raw) == TYPE_DICTIONARY else {}
	var members_raw: Variant = entry.get("members", {})
	var members: Dictionary = members_raw if typeof(members_raw) == TYPE_DICTIONARY else {}
	members [str(npc_id)] = {
		"npc_id": npc_id,
		"role": role
	}
	entry ["members"] = members
	institutions [institution_id] = entry

func _remove_institution_member(institutions: Dictionary, institution_id: String, npc_id: int) -> void:
	if institution_id == "" or npc_id <= 0:
		return
	var entry_raw: Variant = institutions.get(institution_id, {})
	var entry: Dictionary = entry_raw if typeof(entry_raw) == TYPE_DICTIONARY else {}
	var members_raw: Variant = entry.get("members", {})
	var members: Dictionary = members_raw if typeof(members_raw) == TYPE_DICTIONARY else {}
	members.erase(str(npc_id))
	entry ["members"] = members
	institutions [institution_id] = entry

func _clear_player_from_justice_institutions(player_id: int) -> void:
	if player_id <= 0:
		return
	var institutions: Dictionary = get_justice_institutions()
	for raw_institution_id in institutions.keys():
		_remove_institution_member(institutions, str(raw_institution_id), player_id)
	_set_justice_institutions(institutions)

func _flag_justice_projection_dirty() -> void:
	if gs != null and gs.universal_faction_engine != null:
		gs.universal_faction_engine.flag_domain_projection_dirty("crime_engine")

func _ensure_local_justice_institutions(npc, profile: Dictionary) -> Dictionary:
	var institutions: Dictionary = get_justice_institutions()

	var city: String = str(npc.home_city if str(npc.home_city).strip_edges() != "" else npc.birth_city).strip_edges()
	var country: String = str(npc.home_country if str(npc.home_country).strip_edges() != "" else npc.birth_country).strip_edges()
	var locality_id: String = str(npc.locality_id).strip_edges()
	var era_name: String = str(gs.era.name)
	var location_key: String = "%s:%s:%s" % [
		_justice_key(era_name),
		_justice_key(city if city != "" else "wilds"),
		_justice_key(country if country != "" else "unknown")
	]
	var realm_id: String = _justice_realm_id(npc)

	var police_id: String = "justice_police:%s" % location_key
	var court_id: String = "justice_court:%s" % location_key
	var prison_id: String = "justice_prison:%s" % location_key

	var defense_a_id: String = "justice_firm_a:%s" % location_key
	var defense_b_id: String = "justice_firm_b:%s" % location_key
	var public_id: String = "justice_public:%s" % location_key

	var police_names: Dictionary = {
		"Ancient Era": "%s City Watch",
		"Medieval Era": "%s Sheriff's Levy",
		"Industrial Era": "%s Constabulary",
		"Modern Era": "%s Police Department",
		"Future Era": "%s Civic Security Grid"
	}
	var court_names: Dictionary = {
		"Ancient Era": "%s Magistrate Court",
		"Medieval Era": "%s King's Bench",
		"Industrial Era": "%s Crown Court",
		"Modern Era": "%s District Court",
		"Future Era": "%s Civic Tribunal"
	}
	var prison_names: Dictionary = {
		"Ancient Era": "%s Dungeon",
		"Medieval Era": "%s Gaol",
		"Industrial Era": "%s Penitentiary",
		"Modern Era": "%s State Prison",
		"Future Era": "%s Detention Complex"
	}

	var police_staff: Array = _collect_local_justice_staff(
		city,
		country,
		["police", "officer", "detective", "guard", "constable", "sheriff", "watch", "security"],
		6
	)
	var court_staff: Array = _collect_local_justice_staff(
		city,
		country,
		["judge", "magistrate", "lawyer", "attorney", "barrister", "clerk", "prosecutor"],
		5
	)
	var prison_staff: Array = _collect_local_justice_staff(
		city,
		country,
		["warden", "guard", "jailer", "officer", "security"],
		5
	)
	var firm_a_staff: Array = _collect_local_justice_staff(
		city,
		country,
		["lawyer", "attorney", "barrister", "advocate"],
		3
	)
	var firm_b_staff: Array = _collect_local_justice_staff(
		city,
		country,
		["lawyer", "attorney", "barrister", "advocate"],
		3
	)

	var place_name: String = city if city != "" else (country if country != "" else "Local")

	institutions [police_id] = {
		"id": police_id,
		"name": str(police_names.get(era_name, "%s Police")).format([place_name]),
		"institution_type": "police",
		"leader_id": int(police_staff [0]) if not police_staff.is_empty() else -1,
		"members": _build_member_map(police_staff, "officer"),
		"city": city,
		"country": country,
		"locality_id": locality_id,
		"realm_id": realm_id,
		"pressure": float(profile.get("police_strength", 50.0)) * 0.45,
		"heat": float(profile.get("police_strength", 50.0)) * 0.45,
		"population": float(max(1, police_staff.size())),
		"territory": 1.0,
		"approval": 52.0 + (float(profile.get("due_process", 50.0)) * 0.2)
	}

	institutions [court_id] = {
		"id": court_id,
		"name": str(court_names.get(era_name, "%s Court")).format([place_name]),
		"institution_type": "court",
		"leader_id": int(court_staff [0]) if not court_staff.is_empty() else -1,
		"members": _build_member_map(court_staff, "court_staff"),
		"city": city,
		"country": country,
		"locality_id": locality_id,
		"realm_id": realm_id,
		"pressure": float(profile.get("due_process", 50.0)) * 0.35,
		"heat": float(profile.get("jury_fairness", 50.0)) * 0.25,
		"population": float(max(1, court_staff.size())),
		"territory": 1.0,
		"approval": 48.0 + (float(profile.get("due_process", 50.0)) * 0.28)
	}

	institutions [prison_id] = {
		"id": prison_id,
		"name": str(prison_names.get(era_name, "%s Prison")).format([place_name]),
		"institution_type": "prison",
		"leader_id": int(prison_staff [0]) if not prison_staff.is_empty() else -1,
		"members": _build_member_map(prison_staff, "guard"),
		"city": city,
		"country": country,
		"locality_id": locality_id,
		"realm_id": realm_id,
		"pressure": float(profile.get("brutality", 50.0)) * 0.3,
		"heat": float(profile.get("brutality", 50.0)) * 0.35,
		"population": float(max(1, prison_staff.size())),
		"territory": 1.0,
		"approval": 35.0 + (float(profile.get("police_strength", 50.0)) * 0.15)
	}

	institutions [defense_a_id] = {
		"id": defense_a_id,
		"name": "S. & Eliana",
		"institution_type": "defense_firm",
		"leader_id": int(firm_a_staff [0]) if not firm_a_staff.is_empty() else -1,
		"members": _build_member_map(firm_a_staff, "defense_attorney"),
		"city": city,
		"country": country,
		"locality_id": locality_id,
		"realm_id": realm_id,
		"pressure": float(profile.get("lawyer_quality", 50.0)) * 0.2,
		"heat": 12.0,
		"population": float(max(1, firm_a_staff.size())),
		"territory": 0.6,
		"approval": 45.0
	}

	institutions [defense_b_id] = {
		"id": defense_b_id,
		"name": "Layne & Associates",
		"institution_type": "defense_firm",
		"leader_id": int(firm_b_staff [0]) if not firm_b_staff.is_empty() else -1,
		"members": _build_member_map(firm_b_staff, "defense_attorney"),
		"city": city,
		"country": country,
		"locality_id": locality_id,
		"realm_id": realm_id,
		"pressure": float(profile.get("lawyer_quality", 50.0)) * 0.28,
		"heat": 16.0,
		"population": float(max(1, firm_b_staff.size())),
		"territory": 0.6,
		"approval": 49.0
	}

	institutions [public_id] = {
		"id": public_id,
		"name": "Public Defender",
		"institution_type": "public_defender",
		"leader_id": int(court_staff [0]) if not court_staff.is_empty() else -1,
		"members": _build_member_map(court_staff, "public_defender"),
		"city": city,
		"country": country,
		"locality_id": locality_id,
		"realm_id": realm_id,
		"pressure": 10.0,
		"heat": 8.0,
		"population": float(max(1, court_staff.size())),
		"territory": 0.4,
		"approval": 40.0
	}

	_set_justice_institutions(institutions)

	return {
		"police_id": police_id,
		"court_id": court_id,
		"prison_id": prison_id,
		"defense_ids": [defense_a_id, defense_b_id, public_id]
	}

func _record_justice_event(
	text: String,
	event_name: String,
	payload: Dictionary = {}
) -> void:
	if gs == null:
		return

	var actor_id: int = int(
		payload.get(
			"actor_id",
			payload.get(
				"npc_id",
				gs.player.id
				if gs.player != null
				else -1
			)
		)
	)
	var actor: Person = _crime_actor_by_id(
		actor_id
	)

	if actor == null:
		return

	var clean_text: String = str(
		text
	).strip_edges()

	if clean_text == "":
		return

	var world_text: String = str(
		payload.get(
			"world_text",
			clean_text
		)
	).strip_edges()

	if world_text == "":
		world_text = clean_text

	var memory_text: String = str(
		payload.get(
			"memory_text",
			world_text
		)
	).strip_edges()

	if memory_text == "":
		memory_text = world_text

	var publish_world_feed: bool = bool(
		payload.get(
			"publish_world_feed",
			true
		)
	)
	var high_profile: bool = bool(
		payload.get(
			"high_profile",
			false
		)
	)
	var world_metadata: Dictionary = {
		"npc_id": int(actor.id),
		"actor_id": int(actor.id),
		"personally_relevant": (
			gs.player != null
			and int(gs.player.id) == int(actor.id)
		),
		"category": "Crime",
		"event_name": event_name,
		"source": "crime_engine",
		"high_profile": high_profile,
		"featured": high_profile,
		"fame": int(actor.fame),
		"fame_tier": str(actor.fame_tier),
		"witness_count": int(
			payload.get(
				"witness_count",
				0
			)
		),
		"case_id": str(
			payload.get(
				"case_id",
				""
			)
		),
		"crime_event_id": str(
			payload.get(
				"crime_event_id",
				""
			)
		)
	}

	if gs.narrative_engine != null:
		gs.narrative_engine.log_event(
			actor,
			{
				"type": "text",
				"text": clean_text,
				"category": "crime",
				"event_name": event_name,
				"case_id": str(
					payload.get(
						"case_id",
						""
					)
				)
			}
		)

	if publish_world_feed:
		gs.push_world_feed(
			world_text,
			world_metadata
		)

	if gs.event_bus != null and event_name != "":
		var event_payload: Dictionary = payload.duplicate(true)

		event_payload ["npc_id"] = int(actor.id)
		event_payload ["actor_id"] = int(actor.id)
		event_payload ["text"] = memory_text
		event_payload ["world_text"] = world_text
		event_payload ["publish_world_feed"] = publish_world_feed
		event_payload ["high_profile"] = high_profile

		gs.event_bus.emit(
			event_name,
			event_payload
		)

func _build_defense_options(case_data: Dictionary) -> Array:
	var out: Array = []
	var defense_ids: Array = case_data.get("defense_ids", [])
	var severity: int = int(case_data.get("severity", 1))
	var lawyer_quality: float = float(case_data.get("lawyer_quality", 40.0))
	var institutions: Dictionary = get_justice_institutions()
	var market_profile: Dictionary = _build_defense_market_profile(case_data)
	var pricing_multiplier: float = float(market_profile.get("pricing_multiplier", 1.0))
	var private_quality_bonus: float = float(market_profile.get("quality_bonus", 0.0))

	for raw_id in defense_ids:
		var institution_id: String = str(raw_id)
		var inst_raw: Variant = institutions.get(institution_id, {})
		var inst: Dictionary = inst_raw if typeof(inst_raw) == TYPE_DICTIONARY else {}
		if inst.is_empty():
			continue

		var institution_type: String = str(inst.get("institution_type", ""))
		var name: String = str(inst.get("name", "Defense"))
		var cost: int = 0
		var quality: float = 20.0

		if institution_type == "defense_firm":
			var base_cost: int = max(500, int(2500.0 * float(severity)) + int(lawyer_quality * 120.0) + randi_range(0, 1200))
			cost = int(round(float(base_cost) * pricing_multiplier))
			quality = lawyer_quality + (8.0 if name.find("Layne") != -1 else 2.0) + private_quality_bonus
		elif institution_type == "public_defender":
			cost = 0
			quality = max(12.0, (lawyer_quality * 0.45) - ((pricing_multiplier - 1.0) * 5.0))

		out.append({
			"id": institution_id,
			"name": name,
			"cost": cost,
			"quality": quality,
			"public": institution_type == "public_defender"
		})
	return out

func _build_justice_case(
	crime_name: String,
	weapon_name: String,
	crime: Dictionary,
	era_mod: Dictionary,
	_weapon_data: Dictionary,
	success: bool,
	payout: int,
	success_text: String
) -> Dictionary:
	_ensure_justice_state()

	var faction_bias: Dictionary = _justice_faction_bias_snapshot()
	var prior_convictions: int = _count_prior_convictions()
	var institutions: Dictionary = _ensure_local_justice_institutions(gs.player, era_mod)

	var target_political_pressure: float = float(crime.get("target_political_pressure", 0.0))
	var target_organized_pressure: float = float(crime.get("target_organized_pressure", 0.0))
	var target_claim_pressure: float = float(crime.get("target_claim_pressure", 0.0))
	var target_justice_pressure: float = float(crime.get("target_justice_pressure", 0.0))
	var target_court_heat: float = float(crime.get("target_court_heat", 0.0))
	var target_sentence_bonus: int = int(round(float(crime.get("target_sentence_bonus", 0.0))))
	var target_severity_bonus: int = int(round(float(crime.get("target_severity_bonus", 0.0))))
	var target_context_label: String = str(crime.get("target_context_label", "")).strip_edges()
	var target_funny_police_line: String = str(crime.get("target_funny_police_line", "")).strip_edges()
	var target_pressure_trace: Array = crime.get("target_pressure_trace", []).duplicate(true)

	var severity: int = int(crime.get("severity", 1))
	if success and bool(crime.get("violent", false)):
		severity += 1
	severity += target_severity_bonus

	var organized_crime_pressure: float = float(faction_bias.get("syndicate_turf_pressure", 0.0)) + target_organized_pressure
	var political_pressure: float = float(faction_bias.get("coup_pressure", 0.0)) + float(faction_bias.get("royal_succession_tension", 0.0)) + target_political_pressure
	var claim_pressure: float = float(faction_bias.get("claim_pressure_total", 0.0)) + target_claim_pressure
	var court_heat: float = target_court_heat + (target_justice_pressure * 0.35)

	var due_process: float = clamp(
		float(era_mod.get("due_process", 50.0)) - (political_pressure * 0.18) - (court_heat * 0.1),
		4.0,
		95.0
	)
	var police_corruption: float = clamp(
		float(era_mod.get("corruption", 25.0)) + (organized_crime_pressure * 0.22) + (claim_pressure * 0.05),
		0.0,
		95.0
	)
	var police_professionalism: float = clamp(
		float(era_mod.get("police_strength", 50.0)) + (float(era_mod.get("forensics", 0.0)) * 0.35) + (target_justice_pressure * 0.22) + (court_heat * 0.06) - (police_corruption * 0.2),
		8.0,
		99.0
	)
	var jury_fairness: float = clamp(
		float(era_mod.get("jury_fairness", 50.0)) - (political_pressure * 0.1) - (court_heat * 0.12),
		4.0,
		95.0
	)

	var charges: Array = [
		str(crime.get("charge_success", crime_name)) if success else str(crime.get("charge_fail", crime_name))
	]

	var base_sentence_years: int = int(crime.get("sentence_success", 4)) if success else int(crime.get("sentence_fail", 2))
	base_sentence_years += max(0, prior_convictions * 2)
	base_sentence_years += target_sentence_bonus
	base_sentence_years += int(round(court_heat * 0.04))

	var death_eligible: bool = bool(crime.get("violent", false)) and severity >= 5 and float(era_mod.get("brutality", 50.0)) >= 60.0

	var arrest_text: String = ""
	if success:
		arrest_text = "The authorities tracked me down for %s after the crime was completed." % crime_name
	else:
		arrest_text = "I was arrested before I could get away with %s." % crime_name

	if target_context_label != "":
		arrest_text += " The case is hotter because this touched %s." % target_context_label

	return {
		"case_id": "justice_case_%s_%d" % [_justice_key(crime_name), int(Time.get_ticks_msec())],
		"crime_name": crime_name,
		"weapon_name": weapon_name,
		"success_before_arrest": success,
		"payout": payout,
		"success_text": success_text,
		"arrest_text": arrest_text,
		"charges": charges,
		"severity": severity,
		"violent": bool(crime.get("violent", false)),
		"base_sentence_years": base_sentence_years,
		"possible_sentence": _possible_sentence_text({
			"death_eligible": death_eligible,
			"base_sentence_years": base_sentence_years
		}),
		"police_professionalism": police_professionalism,
		"police_corruption": police_corruption,
		"due_process": due_process,
		"jury_fairness": jury_fairness,
		"lawyer_quality": float(era_mod.get("lawyer_quality", 40.0)),
		"brutality": float(era_mod.get("brutality", 50.0)),
		"organized_crime_pressure": organized_crime_pressure,
		"political_pressure": political_pressure,
		"claim_pressure": claim_pressure,
		"court_heat": court_heat,
		"target_justice_pressure": target_justice_pressure,
		"target_arrest_pressure": float(crime.get("target_arrest_pressure", 0.0)),
		"target_sentence_bonus": float(crime.get("target_sentence_bonus", 0.0)),
		"target_context_label": target_context_label,
		"target_funny_police_line": target_funny_police_line,
		"target_pressure_trace": target_pressure_trace.duplicate(true),
		"prior_convictions": prior_convictions,
		"death_eligible": death_eligible,
		"police_id": str(institutions.get("police_id", "")),
		"court_id": str(institutions.get("court_id", "")),
		"prison_id": str(institutions.get("prison_id", "")),
		"defense_ids": institutions.get("defense_ids", []),
		"lawyer_options": [],
		"selected_lawyer_id": "",
		"selected_lawyer_name": "",
		"selected_lawyer_quality": 0.0,
		"plea": "",
		"era_name": str(gs.era.name)
	}

func _format_charge_list(charges: Array) -> String:
	var clean: Array = []
	for raw_charge in charges:
		var charge: String = str(raw_charge).strip_edges()
		if charge != "":
			clean.append(charge)
	if clean.is_empty():
		return "unknown charges"
	if clean.size() == 1:
		return clean [0]
	if clean.size() == 2:
		return "%s and %s" % [clean [0], clean [1]]
	var head: Array = clean.slice(0, clean.size() - 1)
	return "%s, and %s" % [", ".join(head), clean [clean.size() - 1]]

func _possible_sentence_text(case_data: Dictionary) -> String:
	if bool(case_data.get("death_eligible", false)):
		return "Death or %d years" % int(case_data.get("base_sentence_years", 1))
	return "%d years" % int(case_data.get("base_sentence_years", 1))

func _append_case_charge(case_data: Dictionary, charge_text: String, sentence_bonus: int = 0) -> Dictionary:
	var next_case: Dictionary = case_data.duplicate(true)
	var charges: Array = next_case.get("charges", []).duplicate()
	if str(charge_text).strip_edges() != "":
		charges.append(str(charge_text).strip_edges())
	next_case ["charges"] = charges
	next_case ["base_sentence_years"] = int(next_case.get("base_sentence_years", 0)) + sentence_bonus
	next_case ["possible_sentence"] = _possible_sentence_text(next_case)
	return next_case

func _set_sentence_trait(years: int) -> void:
	var next_traits: Array = []
	for raw_trait in gs.player.traits:
		var t: String = str(raw_trait)
		if t.begins_with("InPrison_") or t.begins_with("OnParole_"):
			continue
		next_traits.append(t)
	next_traits.append("InPrison_%d" % max(1, years))
	gs.player.traits = next_traits

func _record_case_history(case_data: Dictionary, convicted: bool, outcome: String, sentence_years: int = 0) -> void:
	_ensure_justice_state()
	var record_raw: Variant = gs.scenario_state.get("justice_record", [])
	var record: Array = record_raw if typeof(record_raw) == TYPE_ARRAY else []
	record.append({
		"year": int(gs.year),
		"crime_name": str(case_data.get("crime_name", "")),
		"charges": case_data.get("charges", []).duplicate(),
		"convicted": convicted,
		"outcome": outcome,
		"sentence_years": sentence_years
	})
	gs.scenario_state ["justice_record"] = record

func _start_justice_flow(
	crime_name: String,
	weapon_name: String,
	crime: Dictionary,
	era_mod: Dictionary,
	weapon_data: Dictionary,
	success: bool,
	payout: int,
	success_text: String
) -> Dictionary:
	if gs != null and gs.case_orchestrator != null and gs.case_orchestrator.has_method("start_player_crime_case"):
		return gs.case_orchestrator.start_player_crime_case({
			"crime_name": crime_name,
			"weapon_name": weapon_name,
			"crime": crime.duplicate(true),
			"era_mod": era_mod.duplicate(true),
			"weapon_data": weapon_data.duplicate(true),
			"success_before_arrest": success,
			"payout": payout,
			"success_text": success_text,
			"intent": "financial_gain"
		})

	var case_data: Dictionary = _build_justice_case(
		crime_name,
		weapon_name,
		crime,
		era_mod,
		weapon_data,
		success,
		payout,
		success_text
	)

	var institutions: Dictionary = get_justice_institutions()
	_upsert_institution_member(institutions, str(case_data.get("police_id", "")), int(gs.player.id), "suspect")
	_set_justice_institutions(institutions)

	_flag_justice_projection_dirty()
	_set_active_justice_case(case_data)

	var arrest_text: String = str(case_data.get("arrest_text", "I was arrested."))
	_record_justice_event(arrest_text, ActionEventTypes.NPC_ARRESTED, {
		"crime_name": crime_name,
		"weapon_name": weapon_name,
		"charges": case_data.get("charges", []).duplicate()
	})

	if gs.event_bus != null:
		gs.event_bus.emit(ActionEventTypes.CRIME_RUMOR_SPREAD, {
			"npc_id": gs.player.id,
			"text": "Everyone heard that %s was arrested for %s." % [
				gs.player.first_name,
				_format_charge_list(case_data.get("charges", []))
			],
			"crime_name": crime_name
		})

	if gs.scenario_engine == null:
		return _finalize_sentence(case_data, 1.0, "summary_judgment")

	return gs.scenario_engine.queue_external_scenario(_build_police_scenario(case_data))
func _targeted_crime_case_definition(crime_name: String, target_died: bool = false, pressure_profile: Dictionary = {}) -> Dictionary:
	var base_case: Dictionary = {}

	match crime_name:
		"pickpocket":
			base_case = {
				"name": "Pickpocket",
				"base_success": 60,
				"danger": 18,
				"severity": 1,
				"violent": false,
				"charge_success": "theft",
				"charge_fail": "attempted theft",
				"sentence_success": 2,
				"sentence_fail": 1,
				"min_payout": 0,
				"max_payout": 0
			}
		"attack":
			if target_died:
				base_case = {
					"name": "Attack",
					"base_success": 40,
					"danger": 48,
					"severity": 5,
					"violent": true,
					"charge_success": "murder",
					"charge_fail": "attempted assault",
					"sentence_success": 22,
					"sentence_fail": 4,
					"min_payout": 0,
					"max_payout": 0
				}
			else:
				base_case = {
					"name": "Attack",
					"base_success": 40,
					"danger": 34,
					"severity": 3,
					"violent": true,
					"charge_success": "assault",
					"charge_fail": "attempted assault",
					"sentence_success": 6,
					"sentence_fail": 3,
					"min_payout": 0,
					"max_payout": 0
				}
		"poison":
			if target_died:
				base_case = {
					"name": "Poison",
					"base_success": 25,
					"danger": 58,
					"severity": 5,
					"violent": true,
					"charge_success": "murder by poisoning",
					"charge_fail": "attempted poisoning",
					"sentence_success": 30,
					"sentence_fail": 8,
					"min_payout": 0,
					"max_payout": 0
				}
			else:
				base_case = {
					"name": "Poison",
					"base_success": 25,
					"danger": 45,
					"severity": 4,
					"violent": true,
					"charge_success": "poisoning and attempted murder",
					"charge_fail": "attempted poisoning",
					"sentence_success": 14,
					"sentence_fail": 7,
					"min_payout": 0,
					"max_payout": 0
				}
		_:
			return {}

	var out: Dictionary = base_case.duplicate(true)
	var target_arrest_pressure: int = int(round(float(pressure_profile.get("arrest_pressure", 0.0))))
	var target_sentence_bonus: int = int(round(float(pressure_profile.get("sentence_bonus", 0.0))))
	var target_severity_bonus: int = int(round(float(pressure_profile.get("severity_bonus", 0.0))))
	var fail_sentence_bonus: int = int(round(float(target_sentence_bonus) * 0.5))

	out ["danger"] = int(out.get("danger", 0)) + target_arrest_pressure
	out ["severity"] = int(out.get("severity", 1)) + target_severity_bonus
	out ["sentence_success"] = int(out.get("sentence_success", 0)) + target_sentence_bonus
	out ["sentence_fail"] = int(out.get("sentence_fail", 0)) + fail_sentence_bonus

	out ["target_arrest_pressure"] = float(pressure_profile.get("arrest_pressure", 0.0))
	out ["target_sentence_bonus"] = float(pressure_profile.get("sentence_bonus", 0.0))
	out ["target_severity_bonus"] = float(pressure_profile.get("severity_bonus", 0.0))
	out ["target_political_pressure"] = float(pressure_profile.get("political_pressure", 0.0))
	out ["target_organized_pressure"] = float(pressure_profile.get("organized_pressure", 0.0))
	out ["target_claim_pressure"] = float(pressure_profile.get("claim_pressure", 0.0))
	out ["target_justice_pressure"] = float(pressure_profile.get("justice_pressure", 0.0))
	out ["target_court_heat"] = float(pressure_profile.get("court_heat", 0.0))
	out ["target_context_label"] = str(pressure_profile.get("context_label", ""))
	out ["target_funny_police_line"] = str(pressure_profile.get("funny_police_line", ""))
	out ["target_pressure_trace"] = pressure_profile.get("pressure_trace", []).duplicate(true)

	return out
func _target_faction_pressure_snapshot(target: Person) -> Dictionary:
	if gs == null or target == null or gs.scenario_engine == null:
		return {}

	var transient: Dictionary = gs.scenario_engine.get_transient_bias_for_npc(int(target.id))
	var raw: Variant = transient.get("faction_pressure", {})
	return raw.duplicate(true) if typeof(raw) == TYPE_DICTIONARY else {}

func _target_local_justice_pressure(target: Person) -> Dictionary:
	var out: Dictionary = {
		"police_pressure": 0.0,
		"court_heat": 0.0
	}

	if gs == null or target == null:
		return out

	var institutions: Dictionary = get_justice_institutions()
	if institutions.is_empty():
		return out

	var locality_id: String = str(target.locality_id).strip_edges()
	var city: String = str(target.home_city if str(target.home_city).strip_edges() != "" else target.birth_city).strip_edges()
	var country: String = str(target.home_country if str(target.home_country).strip_edges() != "" else target.birth_country).strip_edges()

	for raw_institution_id in institutions.keys():
		var inst_raw: Variant = institutions.get(raw_institution_id, {})
		var inst: Dictionary = inst_raw if typeof(inst_raw) == TYPE_DICTIONARY else {}
		if inst.is_empty():
			continue

		var same_location: bool = false
		if locality_id != "" and str(inst.get("locality_id", "")).strip_edges() == locality_id:
			same_location = true
		elif city != "" and str(inst.get("city", "")).strip_edges() == city:
			same_location = true
		elif country != "" and str(inst.get("country", "")).strip_edges() == country:
			same_location = true

		if not same_location:
			continue

		var institution_type: String = str(inst.get("institution_type", ""))
		var pressure: float = float(inst.get("pressure", 0.0))
		var heat: float = float(inst.get("heat", pressure))

		if institution_type in ["police", "watch", "security"]:
			out ["police_pressure"] = float(out.get("police_pressure", 0.0)) + (pressure * 0.25) + (heat * 0.2)
		elif institution_type in ["court", "tribunal", "magistrate"]:
			out ["court_heat"] = float(out.get("court_heat", 0.0)) + (pressure * 0.3) + (heat * 0.25)

	return out

func _targeted_crime_pressure_profile(target: Person, crime_name: String, target_died: bool = false) -> Dictionary:
	var out: Dictionary = {
		"arrest_pressure": 0.0,
		"court_heat": 0.0,
		"sentence_bonus": 0.0,
		"severity_bonus": 0.0,
		"political_pressure": 0.0,
		"organized_pressure": 0.0,
		"claim_pressure": 0.0,
		"justice_pressure": 0.0,
		"context_label": "",
		"funny_police_line": "",
		"pressure_trace": []
	}
	if gs == null or target == null:
		return out

	var target_bias: Dictionary = _target_faction_pressure_snapshot(target)
	var local_justice: Dictionary = _target_local_justice_pressure(target)
	var kind_presence_raw: Variant = target_bias.get("kind_presence", {})
	var kind_presence: Dictionary = kind_presence_raw if typeof(kind_presence_raw) == TYPE_DICTIONARY else {}

	var boxing_profile_raw: Variant = target.boxing_profile
	var boxing_profile: Dictionary = boxing_profile_raw if typeof(boxing_profile_raw) == TYPE_DICTIONARY else {}

	var target_royal_pressure: float = float(target_bias.get("royal_succession_tension", 0.0))
	var target_syndicate_pressure: float = float(target_bias.get("syndicate_turf_pressure", 0.0))
	var target_claim_pressure: float = float(target_bias.get("claim_pressure_total", 0.0))
	var target_coup_pressure: float = float(target_bias.get("coup_pressure", 0.0))
	var target_justice_pressure: float = float(target_bias.get("justice_pressure", 0.0))
	var local_police_pressure: float = float(local_justice.get("police_pressure", 0.0))
	var local_court_heat: float = float(local_justice.get("court_heat", 0.0))
	var pressure_trace: Array = []

	var fame_tier: String = str(target.fame_tier)
	var fame_pressure: float = 0.0
	match fame_tier:
		"Legend":
			fame_pressure = 22.0
		"Global":
			fame_pressure = 16.0
		"National":
			fame_pressure = 10.0
		"Regional":
			fame_pressure = 5.0

	var target_is_royal: bool = bool(target.is_ruler) or int(target.succession_rank) > 0 or bool(target.deposed) or bool(target.exiled)
	var target_has_crime_orbit: bool = int(kind_presence.get("crime_network", 0)) > 0 or target_syndicate_pressure > 0.0
	var target_is_boxer: bool = bool(boxing_profile.get("is_boxer", false))
	var target_boxing_rank: int = int(boxing_profile.get("division_rank", 999))
	var target_is_boxing_headliner: bool = target_is_boxer and ((target_boxing_rank > 0 and target_boxing_rank <= 10) or fame_tier in ["National", "Global", "Legend"])
	var target_is_public_figure: bool = fame_pressure > 0.0
	var hyper_policed_district: bool = local_police_pressure >= 18.0 or target_justice_pressure >= 20.0 or local_court_heat >= 14.0

	if target_is_royal:
		out ["political_pressure"] = float(out.get("political_pressure", 0.0)) + 12.0 + (target_royal_pressure * 0.55) + (target_coup_pressure * 0.25)
		out ["claim_pressure"] = float(out.get("claim_pressure", 0.0)) + 6.0 + (target_claim_pressure * 0.3)
		out ["arrest_pressure"] = float(out.get("arrest_pressure", 0.0)) + 12.0 + (target_royal_pressure * 0.18)
		out ["court_heat"] = float(out.get("court_heat", 0.0)) + 10.0 + (target_royal_pressure * 0.16)
		out ["sentence_bonus"] = float(out.get("sentence_bonus", 0.0)) + (4.0 if crime_name in ["attack", "poison"] or target_died else 2.0)
		out ["severity_bonus"] = float(out.get("severity_bonus", 0.0)) + 1.0
		if str(out.get("context_label", "")).strip_edges() == "":
			out ["context_label"] = "royal blood / succession orbit"
		if str(out.get("funny_police_line", "")).strip_edges() == "":
			out ["funny_police_line"] = "The palace is acting like I touched the family tree and the crown at the same time."
		pressure_trace.append("royal_orbit")

	if target_is_boxing_headliner:
		out ["arrest_pressure"] = float(out.get("arrest_pressure", 0.0)) + 7.0 + (fame_pressure * 0.18)
		out ["court_heat"] = float(out.get("court_heat", 0.0)) + 9.0 + (fame_pressure * 0.35)
		out ["justice_pressure"] = float(out.get("justice_pressure", 0.0)) + 4.0 + (fame_pressure * 0.22)
		out ["sentence_bonus"] = float(out.get("sentence_bonus", 0.0)) + (3.0 if target_died else 1.0)
		if str(out.get("context_label", "")).strip_edges() == "":
			out ["context_label"] = "boxing spotlight"
		if str(out.get("funny_police_line", "")).strip_edges() == "":
			out ["funny_police_line"] = "Half the city is acting like fight week got replaced by an indictment."
		pressure_trace.append("boxing_spotlight")

	if target_is_public_figure:
		out ["arrest_pressure"] = float(out.get("arrest_pressure", 0.0)) + 3.0 + (fame_pressure * 0.2)
		out ["court_heat"] = float(out.get("court_heat", 0.0)) + 5.0 + (fame_pressure * 0.45)
		out ["justice_pressure"] = float(out.get("justice_pressure", 0.0)) + 2.0 + (fame_pressure * 0.15)
		out ["sentence_bonus"] = float(out.get("sentence_bonus", 0.0)) + (2.0 if target_died else 1.0)
		if str(out.get("context_label", "")).strip_edges() == "":
			out ["context_label"] = "public figure / media orbit"
		if str(out.get("funny_police_line", "")).strip_edges() == "":
			out ["funny_police_line"] = "Every camera in town suddenly remembered how zoom lenses work."
		pressure_trace.append("public_figure_orbit")

	if target_has_crime_orbit:
		out ["organized_pressure"] = float(out.get("organized_pressure", 0.0)) + 10.0 + (target_syndicate_pressure * 0.65)
		out ["claim_pressure"] = float(out.get("claim_pressure", 0.0)) + (target_claim_pressure * 0.2)
		out ["arrest_pressure"] = float(out.get("arrest_pressure", 0.0)) + 8.0 + (target_syndicate_pressure * 0.12)
		out ["court_heat"] = float(out.get("court_heat", 0.0)) + 4.0 + (target_syndicate_pressure * 0.1)
		out ["sentence_bonus"] = float(out.get("sentence_bonus", 0.0)) + (3.0 if target_died else 1.0)
		if str(out.get("context_label", "")).strip_edges() == "":
			out ["context_label"] = "syndicate orbit"
		if str(out.get("funny_police_line", "")).strip_edges() == "":
			out ["funny_police_line"] = "Too many unmarked cars pulled up for this to be a normal arrest."
		pressure_trace.append("crime_network_orbit")

	if hyper_policed_district:
		out ["justice_pressure"] = float(out.get("justice_pressure", 0.0)) + 8.0 + (local_police_pressure * 0.7)
		out ["arrest_pressure"] = float(out.get("arrest_pressure", 0.0)) + 6.0 + (local_police_pressure * 0.45)
		out ["court_heat"] = float(out.get("court_heat", 0.0)) + 5.0 + (local_court_heat * 0.6)
		out ["sentence_bonus"] = float(out.get("sentence_bonus", 0.0)) + (2.0 if crime_name in ["attack", "poison"] else 1.0)
		if str(out.get("context_label", "")).strip_edges() == "":
			out ["context_label"] = "hyper-policed district"
		if str(out.get("funny_police_line", "")).strip_edges() == "":
			out ["funny_police_line"] = "This district already had cameras, paperwork, and three people named Officer Something waiting for me."
		pressure_trace.append("hyper_policed_district")

	if target_died:
		out ["court_heat"] = float(out.get("court_heat", 0.0)) + 6.0
		out ["sentence_bonus"] = float(out.get("sentence_bonus", 0.0)) + 4.0
		pressure_trace.append("target_died")

	out ["pressure_trace"] = pressure_trace
	return out
func _pressure_trace_has(trace: Array, trace_key: String) -> bool:
	for raw_entry in trace:
		if str(raw_entry).strip_edges() == trace_key:
			return true
	return false

func _case_has_pressure_trace(case_data: Dictionary, trace_key: String) -> bool:
	return _pressure_trace_has(case_data.get("target_pressure_trace", []), trace_key)

func _target_pressure_descriptor_from_case(case_data: Dictionary) -> Dictionary:
	var out: Dictionary = {
		"descriptor": "low-pressure street case",
		"headline_tag": "local street case",
		"trace_summary": "ordinary civic pressure"
	}
	if _case_has_pressure_trace(case_data, "royal_orbit"):
		out ["descriptor"] = "palace case"
		out ["headline_tag"] = "succession crisis case"
	elif _case_has_pressure_trace(case_data, "boxing_spotlight"):
		out ["descriptor"] = "headline boxing case"
		out ["headline_tag"] = "fight-world headline case"
	elif _case_has_pressure_trace(case_data, "public_figure_orbit"):
		out ["descriptor"] = "high-publicity case"
		out ["headline_tag"] = "media-swarmed case"
	elif _case_has_pressure_trace(case_data, "crime_network_orbit"):
		out ["descriptor"] = "connected underworld case"
		out ["headline_tag"] = "syndicate-heated case"
	elif _case_has_pressure_trace(case_data, "hyper_policed_district"):
		out ["descriptor"] = "high-surveillance district case"
		out ["headline_tag"] = "camera-heavy district case"

	var trace_parts: Array = []
	for raw_trace in case_data.get("target_pressure_trace", []):
		var trace_key: String = str(raw_trace).strip_edges()
		match trace_key:
			"royal_orbit":
				trace_parts.append("royal succession heat")
			"boxing_spotlight":
				trace_parts.append("boxing spotlight heat")
			"public_figure_orbit":
				trace_parts.append("media heat")
			"crime_network_orbit":
				trace_parts.append("underworld pressure")
			"hyper_policed_district":
				trace_parts.append("district surveillance")
			"target_died":
				trace_parts.append("dead-victim escalation")
	if not trace_parts.is_empty():
		out ["trace_summary"] = ", ".join(trace_parts)
	return out

func _build_defense_market_profile(case_data: Dictionary) -> Dictionary:
	var descriptor: Dictionary = _target_pressure_descriptor_from_case(case_data)
	var multiplier: float = 1.0
	var quality_bonus: float = 0.0
	var notes: Array = []

	if _case_has_pressure_trace(case_data, "royal_orbit"):
		multiplier += 0.55
		quality_bonus += 10.0
		notes.append("Palace attention is inflating elite counsel pricing.")
	if _case_has_pressure_trace(case_data, "boxing_spotlight"):
		multiplier += 0.22
		quality_bonus += 4.0
		notes.append("Fight-world media is making this a prestige defense job.")
	if _case_has_pressure_trace(case_data, "public_figure_orbit"):
		multiplier += 0.16
		quality_bonus += 3.0
		notes.append("Publicity pressure is pushing private firms up-market.")
	if _case_has_pressure_trace(case_data, "crime_network_orbit"):
		multiplier += 0.28
		quality_bonus += 3.0
		notes.append("Connected money and fear are distorting the defense market.")
	if _case_has_pressure_trace(case_data, "hyper_policed_district"):
		multiplier += 0.18
		notes.append("This district's surveillance trail makes clean wins harder.")
	if _case_has_pressure_trace(case_data, "target_died"):
		multiplier += 0.24
		quality_bonus += 2.0
		notes.append("A dead victim makes every serious firm price this like a crisis.")

	return {
		"pricing_multiplier": multiplier,
		"quality_bonus": quality_bonus,
		"descriptor": str(descriptor.get("descriptor", "case")),
		"trace_summary": str(descriptor.get("trace_summary", "")),
		"notes": notes
	}

func _build_plea_profile(case_data: Dictionary) -> Dictionary:
	var descriptor: Dictionary = _target_pressure_descriptor_from_case(case_data)
	var guilty_multiplier: float = 0.7
	var no_contest_multiplier: float = 0.84
	var stance_lines: Array = []

	if _case_has_pressure_trace(case_data, "royal_orbit"):
		guilty_multiplier = max(guilty_multiplier, 0.82)
		no_contest_multiplier = max(no_contest_multiplier, 0.91)
		stance_lines.append("The prosecution is hard-balling this because the target sat inside a succession orbit.")
	if _case_has_pressure_trace(case_data, "boxing_spotlight"):
		guilty_multiplier = max(guilty_multiplier, 0.78)
		no_contest_multiplier = max(no_contest_multiplier, 0.88)
		stance_lines.append("Fight media attention is making the state reluctant to look soft.")
	if _case_has_pressure_trace(case_data, "public_figure_orbit"):
		guilty_multiplier = max(guilty_multiplier, 0.76)
		no_contest_multiplier = max(no_contest_multiplier, 0.87)
		stance_lines.append("Publicity pressure is shrinking the normal plea discount.")
	if _case_has_pressure_trace(case_data, "crime_network_orbit"):
		guilty_multiplier = max(guilty_multiplier, 0.79)
		no_contest_multiplier = max(no_contest_multiplier, 0.89)
		stance_lines.append("The court wants a fast resolution before the network leans any harder on the case.")
	if _case_has_pressure_trace(case_data, "hyper_policed_district"):
		guilty_multiplier = max(guilty_multiplier, 0.75)
		no_contest_multiplier = max(no_contest_multiplier, 0.86)
		stance_lines.append("The surveillance trail gives prosecutors less reason to bargain.")
	if _case_has_pressure_trace(case_data, "target_died"):
		guilty_multiplier = max(guilty_multiplier, 0.86)
		no_contest_multiplier = max(no_contest_multiplier, 0.93)
		stance_lines.append("Because the target died, the court is offering only a narrow plea break.")

	return {
		"guilty_multiplier": guilty_multiplier,
		"no_contest_multiplier": no_contest_multiplier,
		"descriptor": str(descriptor.get("descriptor", "case")),
		"trace_summary": str(descriptor.get("trace_summary", "")),
		"stance_text": "\n".join(stance_lines)
	}

func build_targeted_crime_public_narration(actor: Person, target: Person, crime_name: String, target_died: bool = false) -> Dictionary:
	var actor_name: String = "Someone"
	if actor != null:
		actor_name = ("%s %s" % [actor.first_name, actor.last_name]).strip_edges()
		if actor_name == "":
			actor_name = actor.first_name

	var pressure_profile: Dictionary = _targeted_crime_pressure_profile(target, crime_name, target_died)
	var trace: Array = pressure_profile.get("pressure_trace", [])
	var world_text: String = ""
	var memory_text: String = ""

	if target_died:
		if _pressure_trace_has(trace, "royal_orbit"):
			world_text = "News broke that %s killed a royal heir, turning the case into a succession crisis." % actor_name
			memory_text = "Rumors spread that %s killed a royal heir." % actor_name
		elif _pressure_trace_has(trace, "boxing_spotlight"):
			world_text = "News broke that %s killed a famous boxer, sending the fight world into panic." % actor_name
			memory_text = "Rumors spread that %s killed a famous boxer." % actor_name
		elif _pressure_trace_has(trace, "crime_network_orbit"):
			world_text = "Whispers exploded that %s killed a gang-connected figure, and the case immediately picked up syndicate heat." % actor_name
			memory_text = "Rumors spread that %s killed a gang-connected figure." % actor_name
		elif _pressure_trace_has(trace, "public_figure_orbit"):
			world_text = "News broke that %s killed a public figure, pushing the case into a media frenzy." % actor_name
			memory_text = "Rumors spread that %s killed a public figure." % actor_name
		else:
			world_text = "Word spread that %s killed a local citizen." % actor_name
			memory_text = "Rumors spread that %s killed a local citizen." % actor_name
	else:
		if _pressure_trace_has(trace, "royal_orbit"):
			world_text = "Word spread that %s targeted a royal heir, and the case immediately turned political." % actor_name
			memory_text = "Rumors spread that %s targeted a royal heir." % actor_name
		elif _pressure_trace_has(trace, "boxing_spotlight"):
			world_text = "Word spread that %s targeted a famous boxer, turning the case into fight-week headline news." % actor_name
			memory_text = "Rumors spread that %s targeted a famous boxer." % actor_name
		elif _pressure_trace_has(trace, "crime_network_orbit"):
			world_text = "Word spread that %s targeted a gang-connected figure, and the case started picking up underworld pressure." % actor_name
			memory_text = "Rumors spread that %s targeted a gang-connected figure." % actor_name
		elif _pressure_trace_has(trace, "public_figure_orbit"):
			world_text = "Word spread that %s targeted a public figure, and the case started drawing cameras." % actor_name
			memory_text = "Rumors spread that %s targeted a public figure." % actor_name
		else:
			world_text = "Word spread that %s targeted a local citizen." % actor_name
			memory_text = "Rumors spread that %s targeted a local citizen." % actor_name

	return {
		"world_text": world_text,
		"memory_text": memory_text,
		"pressure_profile": pressure_profile
	}

func _justice_case_public_line(case_data: Dictionary, outcome_key: String, sentence_years: int = 0) -> String:
	var descriptor: Dictionary = _target_pressure_descriptor_from_case(case_data)
	var headline_tag: String = str(descriptor.get("headline_tag", "local case"))
	var actor_name: String = "The defendant"
	if gs != null and gs.player != null:
		actor_name = ("%s %s" % [gs.player.first_name, gs.player.last_name]).strip_edges()
		if actor_name == "":
			actor_name = gs.player.first_name

	match outcome_key:
		"convicted":
			return "%s was convicted in a %s and sentenced to %d years." % [actor_name, headline_tag, sentence_years]
		"acquitted":
			return "%s beat a %s at trial." % [actor_name, headline_tag]
		"hired_counsel":
			return "%s hired counsel after the %s heated up." % [actor_name, headline_tag]
		"public_defender":
			return "%s was forced onto a public defender in a %s." % [actor_name, headline_tag]
		"accepted_public_defender":
			return "%s accepted a public defender in a %s." % [actor_name, headline_tag]
	return ""
func resolve_targeted_crime_outcome(target: Person, crime_name: String, succeeded: bool, outcome_text: String, target_died: bool = false) -> Dictionary:
	if gs == null or gs.player == null:
		return {
			"result": "fail",
			"text": outcome_text,
			"popup_title": "Crime",
			"popup_text": str(outcome_text).strip_edges(),
			"popup_footer": "Tap anywhere to continue."
		}

	var pressure_profile: Dictionary = _targeted_crime_pressure_profile(target, crime_name, target_died)
	var crime: Dictionary = _targeted_crime_case_definition(crime_name, target_died, pressure_profile)
	if crime.is_empty():
		return {
			"result": "fail",
			"text": outcome_text,
			"popup_title": "Crime",
			"popup_text": str(outcome_text).strip_edges(),
			"popup_footer": "Tap anywhere to continue."
		}

	var era_mod: Dictionary = _justice_profile_for_era(gs.era.name)
	var danger: int = int(crime.get("danger", 0))
	danger += int(float(era_mod.get("forensics", 50.0)) / 4.0)
	danger += int(float(era_mod.get("police_strength", 50.0)) / 10.0)
	if target_died:
		danger += 20

	var public_narration: Dictionary = build_targeted_crime_public_narration(gs.player, target, crime_name, target_died)

	_record_justice_event(outcome_text, "", {
		"crime_name": crime_name,
		"target_id": target.id if target != null else -1,
		"target_context_label": str(crime.get("target_context_label", "")),
		"target_pressure_trace": crime.get("target_pressure_trace", []).duplicate(true),
		"world_text": str(public_narration.get("world_text", "")).strip_edges(),
		"memory_text": str(public_narration.get("memory_text", "")).strip_edges()
	})

	if succeeded:
		var caught_after_success_threshold: int = clamp(
			danger + int(float(era_mod.get("forensics", 50.0)) * 0.1) + int(round(float(crime.get("target_arrest_pressure", 0.0)) * 0.15)),
			5,
			95
		)
		if (randi() % 100) < caught_after_success_threshold:
			return _start_justice_flow(
				str(crime.get("name", crime_name)),
				"",
				crime,
				era_mod,
				{},
				true,
				0,
				outcome_text
			)
		return {
			"result": "success",
			"text": outcome_text,
			"popup_title": "Crime",
			"popup_text": str(outcome_text).strip_edges(),
			"popup_footer": "Tap anywhere to continue."
		}

	var arrest_roll: int = randi() % 100
	if arrest_roll < danger:
		return _start_justice_flow(
			str(crime.get("name", crime_name)),
			"",
			crime,
			era_mod,
			{},
			false,
			0,
			outcome_text
		)
	return {
		"result": "fail",
		"text": outcome_text,
		"popup_title": "Crime",
		"popup_text": str(outcome_text).strip_edges(),
		"popup_footer": "Tap anywhere to continue."
	}
func _build_police_scenario(case_data: Dictionary) -> Dictionary:
	var severity: int = int(case_data.get("severity", 1))
	var professionalism: int = int(round(float(case_data.get("police_professionalism", 50.0))))
	var target_arrest_pressure: float = float(case_data.get("target_arrest_pressure", 0.0))
	var court_heat: float = float(case_data.get("court_heat", 0.0))
	var officers: int = 2 + severity + int(professionalism / 25.0) + int(round(target_arrest_pressure / 12.0))
	var detectives: int = 0
	if severity >= 3:
		detectives = 1 + int(float(case_data.get("organized_crime_pressure", 0.0)) / 8.0) + int(round(court_heat / 18.0))
	elif court_heat >= 10.0:
		detectives = max(detectives, 1 + int(round(court_heat / 20.0)))

	var prompt: String = "⚖ Police\nYou are being arrested by the police.\n\n%d officers%s are on the scene.\n\nCharges so far: %s" % [
		officers,
		", %d detectives" % detectives if detectives > 0 else "",
		_format_charge_list(case_data.get("charges", []))
	]

	var target_context_label: String = str(case_data.get("target_context_label", "")).strip_edges()
	if target_context_label != "":
		prompt += "\n\nTarget context: %s" % target_context_label

	var funny_police_line: String = str(case_data.get("target_funny_police_line", "")).strip_edges()
	if funny_police_line != "":
		prompt += "\n\n" + funny_police_line

	prompt += "\n\nTheir professionalism: %d%%\n\nHow will you behave?" % professionalism

	return {
		"id": "justice_police_%s" % str(case_data.get("case_id", "")),
		"category": "crime",
		"source": "crime_engine",
		"prompt": prompt,
		"choices": [
			{
				"id": "justice_police_bribe",
				"choice_key": "bribe",
				"label": "Try to bribe them",
				"resolver_method": "resolve_justice_police_choice"
			},
			{
				"id": "justice_police_cooperate",
				"choice_key": "cooperate",
				"label": "Cooperate with them",
				"resolver_method": "resolve_justice_police_choice"
			},
			{
				"id": "justice_police_flirt",
				"choice_key": "flirt",
				"label": "Flirt with them",
				"resolver_method": "resolve_justice_police_choice"
			},
			{
				"id": "justice_police_run",
				"choice_key": "run",
				"label": "Run for it",
				"resolver_method": "resolve_justice_police_choice"
			}
		]
	}

func _build_defense_scenario(case_data: Dictionary) -> Dictionary:
	var next_case: Dictionary = case_data.duplicate(true)
	var lawyer_options: Array = _build_defense_options(next_case)
	var market_profile: Dictionary = _build_defense_market_profile(next_case)
	next_case ["lawyer_options"] = lawyer_options
	_set_active_justice_case(next_case)

	var option_lines: Array = []
	var choices: Array = []
	for option_raw in lawyer_options:
		if typeof(option_raw) != TYPE_DICTIONARY:
			continue
		var option: Dictionary = option_raw
		option_lines.append("%s: $%d" % [
			str(option.get("name", "Defense")),
			int(option.get("cost", 0))
		])
		choices.append({
			"id": "justice_defense_%s" % _justice_key(str(option.get("id", ""))),
			"choice_key": str(option.get("id", "")),
			"label": str(option.get("name", "Defense")),
			"resolver_method": "resolve_justice_defense_choice"
		})

	var prompt: String = "⚖ Criminal Charges\nYou've been charged with %s.\n\nPossible sentence: %s" % [
		_format_charge_list(next_case.get("charges", [])),
		str(next_case.get("possible_sentence", ""))
	]

	var descriptor: String = str(market_profile.get("descriptor", "")).strip_edges()
	if descriptor != "":
		prompt += "\n\nPressure profile: %s" % descriptor

	var trace_summary: String = str(market_profile.get("trace_summary", "")).strip_edges()
	if trace_summary != "":
		prompt += "\nTrace: %s" % trace_summary

	var notes: Array = market_profile.get("notes", [])
	if not notes.is_empty():
		prompt += "\n\n" + "\n".join(notes)

	prompt += "\n\nWhich lawyer will defend you?\n\n%s" % "\n".join(option_lines)

	return {
		"id": "justice_defense_%s" % str(next_case.get("case_id", "")),
		"category": "crime",
		"source": "crime_engine",
		"prompt": prompt,
		"choices": choices
	}

func _build_plea_scenario(case_data: Dictionary) -> Dictionary:
	var plea_profile: Dictionary = _build_plea_profile(case_data)
	var guilty_pct: int = int(round(float(plea_profile.get("guilty_multiplier", 0.7)) * 100.0))
	var no_contest_pct: int = int(round(float(plea_profile.get("no_contest_multiplier", 0.84)) * 100.0))

	var prompt: String = "⚖ Plea\nThe court asks how you plead regarding %s.\n\nPossible sentence: %s" % [
		_format_charge_list(case_data.get("charges", [])),
		str(case_data.get("possible_sentence", ""))
	]

	var descriptor: String = str(plea_profile.get("descriptor", "")).strip_edges()
	if descriptor != "":
		prompt += "\n\nPressure profile: %s" % descriptor

	var trace_summary: String = str(plea_profile.get("trace_summary", "")).strip_edges()
	if trace_summary != "":
		prompt += "\nTrace: %s" % trace_summary

	var stance_text: String = str(plea_profile.get("stance_text", "")).strip_edges()
	if stance_text != "":
		prompt += "\n\n" + stance_text

	prompt += "\n\nExpected plea break:"
	prompt += "\n- Guilty: about %d%% of the full sentence" % guilty_pct
	prompt += "\n- No contest: about %d%% of the full sentence" % no_contest_pct
	prompt += "\n\nHow will you plead?"

	return {
		"id": "justice_plea_%s" % str(case_data.get("case_id", "")),
		"category": "crime",
		"source": "crime_engine",
		"prompt": prompt,
		"choices": [
			{
				"id": "justice_plea_guilty",
				"choice_key": "guilty",
				"label": "Guilty (%d%% sentence)" % guilty_pct,
				"resolver_method": "resolve_justice_plea_choice"
			},
			{
				"id": "justice_plea_not_guilty",
				"choice_key": "not_guilty",
				"label": "Not guilty (go to trial)",
				"resolver_method": "resolve_justice_plea_choice"
			},
			{
				"id": "justice_plea_no_contest",
				"choice_key": "no_contest",
				"label": "No contest (%d%% sentence)" % no_contest_pct,
				"resolver_method": "resolve_justice_plea_choice"
			}
		]
	}
func resolve_justice_police_choice(actor: Person, _scenario: Dictionary, choice: Dictionary, _committed: Dictionary) -> Dictionary:
	var case_data: Dictionary = _get_active_justice_case()
	if case_data.is_empty():
		return {
			"text": "The justice case has gone stale.",
			"popup_title": "Justice",
			"popup_text": "The justice case has gone stale.",
			"popup_footer": "Tap anywhere to continue."
		}

	var choice_key: String = str(choice.get("choice_key", choice.get("id", ""))).strip_edges()
	var next_case: Dictionary = case_data.duplicate(true)

	match choice_key:
		"bribe":
			var bribe_cost: int = max(250, int(actor.bank_balance * 0.04) + int(next_case.get("severity", 1)) * 200)
			if int(actor.bank_balance) < bribe_cost:
				next_case = _append_case_charge(next_case, "attempted bribery", 1)
				_record_justice_event(
					"I tried to bribe the police, but I didn't have enough money to make it stick.",
					ActionEventTypes.CRIME_RUMOR_SPREAD,
					{ "crime_name": str(next_case.get("crime_name", ""))}
				)
			else:
				actor.bank_balance -= bribe_cost
				var bribe_score: float = float(next_case.get("police_corruption", 0.0))
				bribe_score += max(0.0, float(actor.looks) - 50.0) * 0.12
				bribe_score -= float(next_case.get("police_professionalism", 0.0)) * 0.45
				bribe_score -= float(int(next_case.get("severity", 1))) * 6.0
				if randf() * 100.0 < bribe_score:
					_clear_active_justice_case()
					_clear_player_from_justice_institutions(int(actor.id))
					_flag_justice_projection_dirty()
					_record_case_history(next_case, false, "bribed_police", 0)
					return {
						"result": "escaped_justice",
						"text": "I bribed the police and walked free.",
						"popup_title": "Police",
						"popup_text": "You bribed the police and walked free.",
						"popup_footer": "Tap anywhere to continue."
					}
				next_case = _append_case_charge(next_case, "bribery", 2)
				_record_justice_event(
					"I tried to bribe the police, but they pushed the case harder.",
					ActionEventTypes.CRIME_RUMOR_SPREAD,
					{ "crime_name": str(next_case.get("crime_name", ""))}
				)

		"flirt":
			var flirt_score: float = max(0.0, float(actor.looks) - 40.0) * 0.35
			flirt_score += float(next_case.get("police_corruption", 0.0)) * 0.3
			flirt_score -= float(next_case.get("police_professionalism", 0.0)) * 0.35
			flirt_score -= float(int(next_case.get("severity", 1))) * 7.0
			if randf() * 100.0 < flirt_score and int(next_case.get("severity", 1)) <= 2:
				_clear_active_justice_case()
				_clear_player_from_justice_institutions(int(actor.id))
				_flag_justice_projection_dirty()
				_record_case_history(next_case, false, "sweet_talked_police", 0)
				return {
					"result": "escaped_justice",
					"text": "I charmed the officers and slipped out of the case.",
					"popup_title": "Police",
					"popup_text": "You charmed the officers and slipped out of the case.",
					"popup_footer": "Tap anywhere to continue."
				}
			_record_justice_event(
				"I tried to flirt with the police, but they weren't moved.",
				ActionEventTypes.CRIME_RUMOR_SPREAD,
				{ "crime_name": str(next_case.get("crime_name", ""))}
			)

		"run":
			var run_score: float = float(actor.health) * 0.28
			run_score += max(0.0, float(actor.looks) - 50.0) * 0.04
			run_score -= float(next_case.get("police_professionalism", 0.0)) * 0.42
			run_score -= float(next_case.get("severity", 1)) * 8.0
			if randf() * 100.0 < run_score:
				_clear_active_justice_case()
				_clear_player_from_justice_institutions(int(actor.id))
				_flag_justice_projection_dirty()
				_record_case_history(next_case, false, "escaped_arrest", 0)
				return {
					"result": "escaped_justice",
					"text": "I ran for it and escaped the police.",
					"popup_title": "Police",
					"popup_text": "You ran for it and escaped the police.",
					"popup_footer": "Tap anywhere to continue."
				}
			next_case = _append_case_charge(next_case, "evading arrest", 2)
			_record_justice_event(
				"I ran from the police, but they caught me and added another charge.",
				ActionEventTypes.CRIME_RUMOR_SPREAD,
				{ "crime_name": str(next_case.get("crime_name", ""))}
			)

		_:
			_record_justice_event(
				"I cooperated with the police during my arrest.",
				ActionEventTypes.CRIME_RUMOR_SPREAD,
				{ "crime_name": str(next_case.get("crime_name", ""))}
			)

	var institutions: Dictionary = get_justice_institutions()
	_remove_institution_member(institutions, str(next_case.get("police_id", "")), int(actor.id))
	_upsert_institution_member(institutions, str(next_case.get("court_id", "")), int(actor.id), "defendant")
	_set_justice_institutions(institutions)
	_flag_justice_projection_dirty()

	_set_active_justice_case(next_case)
	return gs.scenario_engine.queue_external_scenario(_build_defense_scenario(next_case))

func resolve_justice_defense_choice(actor: Person, _scenario: Dictionary, choice: Dictionary, _committed: Dictionary) -> Dictionary:
	var case_data: Dictionary = _get_active_justice_case()
	if case_data.is_empty():
		return {
			"text": "The justice case has gone stale.",
			"popup_title": "Justice",
			"popup_text": "The justice case has gone stale.",
			"popup_footer": "Tap anywhere to continue."
		}

	var picked_id: String = str(choice.get("choice_key", "")).strip_edges()
	var options: Array = case_data.get("lawyer_options", [])
	var picked: Dictionary = {}
	for option_raw in options:
		if typeof(option_raw) != TYPE_DICTIONARY:
			continue
		var option: Dictionary = option_raw
		if str(option.get("id", "")) == picked_id:
			picked = option.duplicate(true)
			break

	if picked.is_empty():
		return {
			"text": "That legal option is no longer available.",
			"popup_title": "Justice",
			"popup_text": "That legal option is no longer available.",
			"popup_footer": "Tap anywhere to continue."
		}

	var cost: int = int(picked.get("cost", 0))
	var quality: float = float(picked.get("quality", 0.0))
	var picked_name: String = str(picked.get("name", "Defense"))
	var trace: Array = case_data.get("target_pressure_trace", []).duplicate(true)

	if cost > 0 and int(actor.bank_balance) < cost:
		picked_name = "Public Defender"
		quality = max(12.0, float(case_data.get("lawyer_quality", 40.0)) * 0.45)
		cost = 0
		var public_line: String = _justice_case_public_line(case_data, "public_defender")
		_record_justice_event(
			"I couldn't afford private counsel, so I was assigned a public defender.",
			ActionEventTypes.CRIME_RUMOR_SPREAD,
			{
				"crime_name": str(case_data.get("crime_name", "")),
				"target_pressure_trace": trace,
				"world_text": public_line,
				"memory_text": public_line
			}
		)
	elif cost > 0:
		actor.bank_balance -= cost
		var hire_line: String = _justice_case_public_line(case_data, "hired_counsel")
		_record_justice_event(
			"I hired %s to defend me in court." % picked_name,
			ActionEventTypes.CRIME_RUMOR_SPREAD,
			{
				"crime_name": str(case_data.get("crime_name", "")),
				"target_pressure_trace": trace,
				"world_text": hire_line,
				"memory_text": hire_line
			}
		)
	else:
		var accepted_line: String = _justice_case_public_line(case_data, "accepted_public_defender")
		_record_justice_event(
			"I accepted a public defender.",
			ActionEventTypes.CRIME_RUMOR_SPREAD,
			{
				"crime_name": str(case_data.get("crime_name", "")),
				"target_pressure_trace": trace,
				"world_text": accepted_line,
				"memory_text": accepted_line
			}
		)

	case_data ["selected_lawyer_id"] = picked_id
	case_data ["selected_lawyer_name"] = picked_name
	case_data ["selected_lawyer_quality"] = quality
	_set_active_justice_case(case_data)
	return gs.scenario_engine.queue_external_scenario(_build_plea_scenario(case_data))

func resolve_justice_plea_choice(actor: Person, _scenario: Dictionary, choice: Dictionary, _committed: Dictionary) -> Dictionary:
	var case_data: Dictionary = _get_active_justice_case()
	if case_data.is_empty():
		return {
			"text": "The justice case has gone stale.",
			"popup_title": "Justice",
			"popup_text": "The justice case has gone stale.",
			"popup_footer": "Tap anywhere to continue."
		}

	var plea_key: String = str(choice.get("choice_key", "")).strip_edges()
	var plea_profile: Dictionary = _build_plea_profile(case_data)
	case_data ["plea"] = plea_key
	_set_active_justice_case(case_data)

	match plea_key:
		"guilty":
			return _finalize_sentence(case_data, float(plea_profile.get("guilty_multiplier", 0.7)), "guilty_plea")
		"no_contest":
			return _finalize_sentence(case_data, float(plea_profile.get("no_contest_multiplier", 0.84)), "no_contest")
		_:
			return _resolve_trial_verdict(actor, case_data)
func _resolve_trial_verdict(actor: Person, case_data: Dictionary) -> Dictionary:
	var conviction_score: float = 22.0
	conviction_score += float(int(case_data.get("severity", 1))) * 11.0
	conviction_score += float(case_data.get("police_professionalism", 0.0)) * 0.2
	conviction_score += float(case_data.get("organized_crime_pressure", 0.0)) * 0.12
	conviction_score += float(case_data.get("court_heat", 0.0)) * 0.18
	conviction_score += float(case_data.get("political_pressure", 0.0)) * 0.04
	conviction_score += float(case_data.get("claim_pressure", 0.0)) * 0.03
	conviction_score += float(case_data.get("target_justice_pressure", 0.0)) * 0.05
	conviction_score += float(case_data.get("prior_convictions", 0)) * 6.0
	conviction_score -= float(case_data.get("selected_lawyer_quality", 0.0)) * 0.55
	conviction_score -= float(case_data.get("jury_fairness", 0.0)) * 0.2
	conviction_score -= float(case_data.get("due_process", 0.0)) * 0.1
	conviction_score -= max(0.0, float(actor.smarts) - 50.0) * 0.08

	var roll: float = randf() * 100.0
	if roll > conviction_score:
		return _finalize_acquittal(case_data, "jury")
	return _finalize_sentence(case_data, 1.0, "trial")

func _finalize_acquittal(case_data: Dictionary, verdict_source: String) -> Dictionary:
	_clear_active_justice_case()
	_clear_player_from_justice_institutions(int(gs.player.id))
	_flag_justice_projection_dirty()
	_record_case_history(case_data, false, "acquitted", 0)

	var title: String = "A just jury" if verdict_source == "jury" else "Acquitted"
	var diary_text: String = "I was found not guilty of %s." % _format_charge_list(case_data.get("charges", []))
	var public_line: String = _justice_case_public_line(case_data, "acquitted")

	_record_justice_event(diary_text, ActionEventTypes.CRIME_RUMOR_SPREAD, {
		"crime_name": str(case_data.get("crime_name", "")),
		"verdict": "acquitted",
		"target_pressure_trace": case_data.get("target_pressure_trace", []).duplicate(true),
		"world_text": public_line,
		"memory_text": public_line
	})

	return {
		"result": "acquitted",
		"text": diary_text,
		"popup_title": title,
		"popup_text": "You were found not guilty of %s." % _format_charge_list(case_data.get("charges", [])),
		"popup_footer": "Tap anywhere to continue."
	}
func resolve_weapon_crime_action(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	if (
		actor == null
		or not bool(
			actor.alive
		)
	):
		return _weapon_crime_failure(
			"missing_actor",
			"No living actor is available."
		)

	if gs == null:
		return _weapon_crime_failure(
			"missing_game_state",
			"GameState is unavailable."
		)

	var target_id: int = int(
		payload.get(
			"target_id",
			-1
		)
	)
	var target: Person = _crime_actor_by_id(
		target_id
	)

	if (
		target == null
		or not bool(
			target.alive
		)
	):
		return _weapon_crime_failure(
			"target_unavailable",
			"The selected target is unavailable."
		)

	var weapon_contract: Dictionary = _crime_safe_dictionary(
		payload.get(
			"weapon_contract",
			{}
		)
	)
	var action_contract: Dictionary = _crime_safe_dictionary(
		payload.get(
			"weapon_action",
			{}
		)
	)
	var weapon_name: String = str(
		weapon_contract.get(
			"weapon_name",
			payload.get(
				"weapon_name",
				"Weapon"
			)
		)
	).strip_edges()
	var action_id: String = str(
		action_contract.get(
			"id",
			payload.get(
				"weapon_action_id",
				"weapon_attack"
			)
		)
	).strip_edges().to_lower()
	var action_label: String = str(
		action_contract.get(
			"label",
			action_id.capitalize()
		)
	).strip_edges()
	var body_part: String = str(
		payload.get(
			"body_part",
			"torso"
		)
	).strip_edges().to_lower()
	var harm_min: int = maxi(
		0,
		int(
			action_contract.get(
				"harm_min",
				1
			)
		)
	)
	var harm_max: int = maxi(
		harm_min,
		int(
			action_contract.get(
				"harm_max",
				harm_min
			)
		)
	)
	var harm_amount: int = randi_range(
		harm_min,
		harm_max
	)
	var body_scale: float = (
		_weapon_body_part_harm_scale(
			body_part,
			weapon_contract,
			action_contract
		)
	)

	harm_amount = maxi(
		0,
		int(
			round(
				float(
					harm_amount
				) * body_scale
			)
		)
	)

	var health_before: float = clampf(
		float(
			target.health
		),
		0.0,
		100.0
	)
	var health_after: float = clampf(
		health_before - float(
			harm_amount
		),
		0.0,
		100.0
	)

	target.health = health_after

	var fatality_chance: float = clampf(
		float(
			action_contract.get(
				"fatality_chance",
				0.0
			)
		) * body_scale,
		0.0,
		0.95
	)
	var target_died: bool = false

	if (
		health_after <= 0.0
		or (
			randf() <= fatality_chance
			and health_after <= 28.0
		)
	):
		if (
			gs.health_engine != null
			and gs.health_engine.has_method(
				"try_kill"
			)
		):
			target_died = bool(
				gs.health_engine.try_kill(
					target,
					"%s attack with %s" % [
						action_label,
						weapon_name
					]
				)
			)

		if not target_died:
			target.health = maxf(
				1.0,
				float(
					target.health
				)
			)

	var target_survived: bool = (
		not target_died
		and bool(
			target.alive
		)
	)
	var witness_visibility: float = clampf(
		float(
			action_contract.get(
				"witness_visibility",
				0.55
			)
		),
		0.0,
		1.0
	)
	var noise: float = clampf(
		float(
			action_contract.get(
				"noise",
				0.35
			)
		),
		0.0,
		1.0
	)
	var witness_ids: Array = _collect_weapon_crime_witness_ids(
		actor,
		target,
		witness_visibility,
		noise
	)
	var victim_reported: bool = (
		target_survived
		and randf() <= clampf(
			0.68
			+ witness_visibility * 0.16
			+ noise * 0.1,
			0.0,
			0.96
		)
	)
	var discovered: bool = (
		victim_reported
		or not witness_ids.is_empty()
	)
	var crime_name: String = (
		"Homicide"
		if target_died
		else "Weapon Assault"
	)
	var severity: float = clampf(
		0.38
		+ fatality_chance * 0.4
		+ float(
			harm_amount
		) / 180.0
		+ (
			0.2
			if target_died
			else 0.0
		),
		0.1,
		1.0
	)
	var charges: Array = [
		"homicide"
		if target_died
		else "weapon_assault"
	]

	if bool(
		weapon_contract.get(
			"legal",
			true
		)
	) == false:
		charges.append(
			"illegal_weapon_possession"
		)

	var crime_event: Dictionary = (
		gs.crime_contract_engine
		.normalize_crime_event({
			"actor_id": int(
				actor.id
			),
			"victim_id": int(
				target.id
			),
			"crime_name": crime_name,
			"crime_type": (
				"homicide"
				if target_died
				else "weapon_assault"
			),
			"severity": severity * 100.0,
			"intent": str(
				payload.get(
					"intent",
					"intentional_weapon_use"
				)
			),
			"weapon_name": weapon_name,
			"weapon_type": str(
				weapon_contract.get(
					"weapon_type",
					"weapon"
				)
			),
			"weapon_action_id": action_id,
			"weapon_action_label": action_label,
			"body_part": body_part,
			"harm_amount": harm_amount,
			"target_survived": target_survived,
			"target_died": target_died,
			"victim_reported": victim_reported,
			"witness_ids": witness_ids.duplicate(true),
			"discovered": discovered,
			"violent": true,
			"base_sentence_years": (
				18
				if target_died
				else maxi(
					1,
					int(
						round(
							severity * 9.0
						)
					)
				)
			),
			"charges": charges.duplicate(true),
			"source_item": _crime_safe_dictionary(
				payload.get(
					"source_item",
					{}
				)
			)
		})
	)
	var case_report: Dictionary = {}

	if (
		gs.case_orchestrator != null
		and gs.case_orchestrator.has_method(
			"register_crime_event"
		)
	):
		case_report = (
			gs.case_orchestrator
			.register_crime_event(
				crime_event,
				{
					"discovered": discovered,
					"victim_reported": victim_reported,
					"witness_ids": (
						witness_ids.duplicate(true)
					),
					"source": (
						"crime_engine.weapon_action"
					)
				}
			)
		)

	var pending_report: Dictionary = {}

	if (
		discovered
		and gs.pending_situations_engine != null
		and gs.pending_situations_engine.has_method(
			"emit_crime_response_contract"
		)
	):
		pending_report = (
			gs.pending_situations_engine
			.emit_crime_response_contract(
				actor,
				crime_event,
				case_report,
				{
					"response_window_ms": 75000,
					"source": (
						"crime_engine.weapon_action"
					)
				}
			)
		)

	var target_name: String = _crime_actor_name(
		target
	)
	var body_part_label: String = body_part.replace(
		"_",
		" "
	)
	var location_name: String = str(
		payload.get(
			"location_name",
			payload.get(
				"location",
				""
			)
		)
	).strip_edges()

	if location_name == "":
		var location_city: String = str(
			actor.home_city
		).strip_edges()
		var location_country: String = str(
			actor.home_country
		).strip_edges()

		location_name = (
			"%s, %s"
			% [
				location_city,
				location_country
			]
		).strip_edges().trim_prefix(",").trim_suffix(",")

	if location_name == "":
		location_name = "an unrecorded location"

	crime_event ["context"] ["location_name"] = location_name
	crime_event ["context"] ["location"] = location_name

	var result_text: String = (
		"You used %s to %s %s, targeting the %s at %s."
		% [
			weapon_name,
			action_label.to_lower(),
			target_name,
			body_part_label,
			location_name
		]
	)

	if target_died:
		result_text += (
			"\n\n%s died from the attack."
			% target_name
		)
	elif target_survived:
		result_text += (
			"\n\n%s survived with %d health remaining."
			% [
				target_name,
				int(
					round(
						float(target.health)
					)
				)
			]
		)

	if victim_reported:
		result_text += (
			"\n\nThe survivor reported what happened."
		)
	elif not witness_ids.is_empty():
		result_text += "\n\nThere were witnesses."
	elif not discovered:
		result_text += (
			"\n\nNo immediate report was made, but the event "
			+ "still exists in world truth."
		)

	if actor.memories != null:
		actor.memories.append(
			"I used %s to %s %s at %s."
			% [
				weapon_name,
				action_label.to_lower(),
				target_name,
				location_name
			]
		)

	var actor_name: String = _crime_actor_name(
		actor
	)
	var famous_tiers: Array = [
		"national",
		"global",
		"legend",
		"legendary",
		"icon",
		"iconic"
	]
	var fame_tier_key: String = str(
		actor.fame_tier
	).strip_edges().to_lower()
	var high_profile: bool = (
		int(actor.fame) >= 60
		or fame_tier_key in famous_tiers
	)
	var world_text: String = (
		"%s used %s to %s %s, targeting the %s at %s."
		% [
			actor_name,
			weapon_name,
			action_label.to_lower(),
			target_name,
			body_part_label,
			location_name
		]
	)

	if target_died:
		world_text += " %s died." % target_name
	else:
		world_text += " %s survived." % target_name

	if witness_ids.size() == 1:
		world_text += " One witness saw what happened."
	elif witness_ids.size() > 1:
		world_text += (
			" %d witnesses saw what happened."
			% witness_ids.size()
		)
	elif victim_reported:
		world_text += " The survivor reported the crime."

	if high_profile:
		world_text = (
			"HIGH-PROFILE CRIME — %s"
			% world_text
		)

	var case_id: String = str(
		case_report.get(
			"case_id",
			_crime_safe_dictionary(
				case_report.get(
					"case",
					{}
				)
			).get(
				"case_id",
				""
			)
		)
	)
	var crime_event_id: String = str(
		crime_event.get(
			"crime_event_id",
			""
		)
	)
	var publish_world_feed: bool = (
		victim_reported
		or not witness_ids.is_empty()
	)

	_record_justice_event(
		result_text,
		"weapon_crime_committed",
		{
			"actor_id": int(actor.id),
			"target_id": int(target.id),
			"case_id": case_id,
			"crime_event_id": crime_event_id,
			"crime_name": crime_name,
			"weapon_name": weapon_name,
			"weapon_action_id": action_id,
			"weapon_action_label": action_label,
			"body_part": body_part,
			"location_name": location_name,
			"witness_count": witness_ids.size(),
			"witness_ids": witness_ids.duplicate(true),
			"victim_reported": victim_reported,
			"target_died": target_died,
			"high_profile": high_profile,
			"publish_world_feed": publish_world_feed,
			"world_text": world_text,
			"memory_text": result_text,
			"crime_event": crime_event.duplicate(true)
		}
	)

	return {
		"success": true,
		"mode": "weapon_crime_action_committed",
		"text": result_text,
		"popup_title": crime_name,
		"popup_text": result_text,
		"popup_footer": (
			"Consequences now continue through world truth."
		),
		"actor_id": int(actor.id),
		"target_id": int(target.id),
		"weapon_name": weapon_name,
		"weapon_action_id": action_id,
		"body_part": body_part,
		"location_name": location_name,
		"harm_amount": harm_amount,
		"health_before": health_before,
		"health_after": float(target.health),
		"target_survived": target_survived,
		"target_died": target_died,
		"victim_reported": victim_reported,
		"witness_ids": witness_ids.duplicate(true),
		"discovered": discovered,
		"crime_event": crime_event.duplicate(true),
		"case_report": case_report.duplicate(true),
		"pending_contract_report": pending_report.duplicate(true),
		"crime_world_feed_published": publish_world_feed,
		"crime_world_feed_high_profile": high_profile,
		"hub_contract_refresh_required": true,



		"log_to_diary": false
	}
func _collect_weapon_crime_witness_ids(
	actor: Person,
	target: Person,
	visibility: float,
	noise: float
) -> Array:
	var out: Array = []

	if (
		gs == null
		or actor == null
		or target == null
		or gs.npcs.is_empty()
	):
		return out

	var observation_chance: float = clampf(
		0.06
		+ visibility * 0.24
		+ noise * 0.18,
		0.0,
		0.72
	)

	const MAX_WITNESSES:= 6
	const MAX_WITNESS_PROBES:= 48

	var population_size: int = (
		gs.npcs.size()
	)

	var probe_budget: int = mini(
		MAX_WITNESS_PROBES,
		population_size
	)

	var seed_material: String = (
		"%d:%d:%d:%d:%d"
		% [
			int(
				actor.id
			),
			int(
				target.id
			),
			int(
				gs.year
			),
			int(
				round(
					visibility * 100.0
				)
			),
			int(
				round(
					noise * 100.0
				)
			)
		]
	)

	var start_index: int = (
		absi(
			int(
				seed_material.hash()
			)
		)
		% population_size
	)

	var visited: Dictionary = {}
	var probe: int = 0

	while (
		probe < probe_budget
		and out.size() < MAX_WITNESSES
	):
		var candidate_index: int = (
			(
				start_index
				+ probe * 37
			)
			% population_size
		)

		probe += 1

		if visited.has(
			candidate_index
		):
			continue

		visited [
			candidate_index
		] = true

		var raw_person: Variant = gs.npcs [
			candidate_index
		]

		if not (
			raw_person is Person
		):
			continue

		var candidate: Person = (
			raw_person as Person
		)

		if (
			candidate == null
			or not bool(
				candidate.alive
			)
			or int(
				candidate.id
			) in [
				int(
					actor.id
				),
				int(
					target.id
				)
			]
		):
			continue

		if randf() > observation_chance:
			continue

		out.append(
			int(
				candidate.id
			)
		)

	return out
func _weapon_body_part_harm_scale(
	body_part: String,
	weapon_contract: Dictionary = {},
	action_contract: Dictionary = {}
) -> float:
	var clean_body_part: String = str(
		body_part
	).strip_edges().to_lower()
	var profile_id: String = str(
		weapon_contract.get(
			"profile_id",
			""
		)
	).strip_edges().to_lower()
	var weapon_type: String = str(
		weapon_contract.get(
			"weapon_type",
			""
		)
	).strip_edges().to_lower()
	var action_id: String = str(
		action_contract.get(
			"id",
			""
		)
	).strip_edges().to_lower()

	var base_scale: float = 1.0

	match clean_body_part:
		"head":
			base_scale = 1.3
		"torso":
			base_scale = 1.15
		"arm":
			base_scale = 0.84
		"hand":
			base_scale = 0.66
		"leg":
			base_scale = 0.88
		"foot":
			base_scale = 0.6
		"near_target":
			return 0.1
		_:
			base_scale = 1.0

	var projectile_discharge: bool = action_id in [
		"fire",
		"fire_projectile",
		"energy_discharge"
	]

	if not projectile_discharge:
		return base_scale




	match profile_id:
		"shotgun":
			match clean_body_part:
				"head":
					return 3.0
				"torso":
					return 1.55
				"arm":
					return 1.12
				"leg":
					return 1.08

		"rifle":
			match clean_body_part:
				"head":
					return 3.6
				"torso":
					return 1.48
				"arm":
					return 1.05
				"leg":
					return 1.02

		"pistol":
			match clean_body_part:
				"head":
					return 4.8
				"torso":
					return 1.35
				"arm":
					return 0.96
				"hand":
					return 0.74
				"leg":
					return 0.94

		"energy_firearm":
			match clean_body_part:
				"head":
					return 4.0
				"torso":
					return 1.6
				"arm":
					return 1.12
				"leg":
					return 1.08

		"crossbow":
			match clean_body_part:
				"head":
					return 8.0
				"torso":
					return 2.1
				"arm":
					return 1.1
				"leg":
					return 1.06

		"bow":
			match clean_body_part:
				"head":
					return 5.0
				"torso":
					return 1.75
				"arm":
					return 1.0
				"leg":
					return 0.96

		"sling":
			match clean_body_part:
				"head":
					return 1.8
				"torso":
					return 1.05

	if weapon_type in [
		"gun",
		"firearm"
	]:
		match clean_body_part:
			"head":
				return 4.0
			"torso":
				return 1.4

	return base_scale


func _crime_actor_by_id(
	actor_id: int
) -> Person:
	if (
		gs == null
		or actor_id <= 0
	):
		return null

	if (
		gs.player != null
		and int(
			gs.player.id
		) == actor_id
	):
		return gs.player

	if gs.has_method(
		"get_npc_by_id"
	):
		var actor = gs.get_npc_by_id(
			actor_id
		)

		if actor is Person:
			return actor as Person

	if gs.has_method(
		"get_or_reactivate_npc_by_id"
	):
		var restored = (
			gs.get_or_reactivate_npc_by_id(
				actor_id
			)
		)

		if restored is Person:
			return restored as Person

	return null


func _crime_actor_name(
	actor: Person
) -> String:
	if actor == null:
		return "the target"

	var full_name: String = (
		"%s %s"
		% [
			str(
				actor.first_name
			),
			str(
				actor.last_name
			)
		]
	).strip_edges()

	return (
		full_name
		if full_name != ""
		else "Person %d" % int(
			actor.id
		)
	)


func _weapon_crime_failure(
	reason: String,
	message: String
) -> Dictionary:
	return {
		"success": false,
		"reason": reason,
		"text": message,
		"popup_title": "Weapon Action",
		"popup_text": message,
		"popup_footer": "Tap anywhere to continue."
	}


func _crime_safe_dictionary(
	value: Variant
) -> Dictionary:
	if typeof(
		value
	) == TYPE_DICTIONARY:
		return (
			value as Dictionary
		).duplicate(true)

	return {}
func _finalize_sentence(case_data: Dictionary, sentence_multiplier: float, verdict_source: String) -> Dictionary:
	var years: int = max(1, int(round(float(case_data.get("base_sentence_years", 1)) * sentence_multiplier)))
	years -= int(round(float(case_data.get("selected_lawyer_quality", 0.0)) / 28.0))
	years = max(1, years)

	var death_chance: float = 0.0
	if bool(case_data.get("death_eligible", false)):
		death_chance += float(case_data.get("brutality", 0.0)) * 0.5
		death_chance += float(int(case_data.get("severity", 1))) * 6.0
		death_chance -= float(case_data.get("selected_lawyer_quality", 0.0)) * 0.18
		death_chance -= float(case_data.get("due_process", 0.0)) * 0.08
		death_chance = clamp(death_chance, 0.0, 92.0)

	if death_chance > 0.0 and (randf() * 100.0) < death_chance:
		_clear_active_justice_case()
		_clear_player_from_justice_institutions(int(gs.player.id))
		_flag_justice_projection_dirty()
		var died: bool = gs.health_engine.try_kill(gs.player, "Execution")
		if died:
			_record_case_history(case_data, true, "executed", 0)
			return {
				"result": "death",
				"text": "I was executed for %s." % _format_charge_list(case_data.get("charges", [])),
				"popup_title": "Justice",
				"popup_text": "You were executed for %s." % _format_charge_list(case_data.get("charges", [])),
				"popup_footer": "Tap anywhere to continue."
			}
		_record_case_history(case_data, true, "execution_survived", 0)
		return {
			"result": "survived",
			"text": "I was sentenced to death for %s, but death could not claim me." % _format_charge_list(case_data.get("charges", [])),
			"popup_title": "Justice",
			"popup_text": "You were sentenced to death for %s, but death could not claim you." % _format_charge_list(case_data.get("charges", [])),
			"popup_footer": "Tap anywhere to continue."
		}

	_set_sentence_trait(years)
	gs.scenario_state ["justice_prison_id"] = str(case_data.get("prison_id", ""))
	var institutions: Dictionary = get_justice_institutions()
	_remove_institution_member(institutions, str(case_data.get("court_id", "")), int(gs.player.id))
	_upsert_institution_member(institutions, str(case_data.get("prison_id", "")), int(gs.player.id), "inmate")
	_set_justice_institutions(institutions)
	_clear_active_justice_case()
	_flag_justice_projection_dirty()
	_record_case_history(case_data, true, verdict_source, years)

	var diary_text: String = "I was convicted of %s and sentenced to %d years in prison." % [
		_format_charge_list(case_data.get("charges", [])),
		years
	]
	var public_line: String = _justice_case_public_line(case_data, "convicted", years)

	_record_justice_event(diary_text, ActionEventTypes.NPC_ARRESTED, {
		"crime_name": str(case_data.get("crime_name", "")),
		"verdict": "convicted",
		"sentence_years": years,
		"target_pressure_trace": case_data.get("target_pressure_trace", []).duplicate(true),
		"world_text": public_line,
		"memory_text": public_line
	})

	return {
		"result": "convicted",
		"years": years,
		"text": diary_text,
		"popup_title": "Justice",
		"popup_text": "You were convicted of %s and sentenced to %d years in prison." % [
			_format_charge_list(case_data.get("charges", [])),
			years
		],
		"popup_footer": "Tap anywhere to continue."
	}




func commit_bending_crime(target: Person, move: String) -> Dictionary:

	if gs.player.bending_type == "none":
		return { "text": "❌ You cannot bend."}

	var _power = gs.bending_engine._bending_power(gs.player)

	match move:

		"Fire Blast":
			target.health -= randi_range(20, 40)

		"Earth Crush":
			target.health -= randi_range(15, 50)

		"Water Whip":
			target.health -= randi_range(10, 30)

		"Air Strike":
			target.health -= randi_range(5, 25)

		_:
			return { "text": "Unknown bending move."}

	gs.event_bus.emit(ActionEventTypes.NPC_COMMITTED_CRIME, {
		"npc_id": gs.player.id,
		"type": ActionEventTypes.NPC_COMMITTED_CRIME
	})

	return { "text": "You attacked %s with %s." % [target.first_name, move]}