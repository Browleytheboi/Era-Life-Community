extends Resource
class_name RuntimeContractEngine

const CONTRACT_SCHEMA:= "eralife.runtime_contract_engine"
const CONTRACT_VERSION:= 1
const RUNTIME_CONTRACT_SCHEMA:= "eralife.runtime_contract"
const MOVIE_THEATER_CONTRACT_SCHEMA:= "eralife.runtime_contract.movie_theater_session"
const WEAPON_SHOP_CONTRACT_SCHEMA:= "eralife.runtime_contract.weapon_shop"
const SCHOOL_SESSION_CONTRACT_SCHEMA:= "eralife.runtime_contract.school_session"

var gs
var active_runtime_contracts: Dictionary = {}
var runtime_contract_index: Dictionary = {}
var runtime_contract_observations: Dictionary = {}
var runtime_contract_mutation_log: Array = []
var last_report: Dictionary = {}

func _init(_gs = null):
	gs = _gs


func export_state() -> Dictionary:
	return _make_binary_safe({
		"schema": CONTRACT_SCHEMA + "_state",
		"version": CONTRACT_VERSION,
		"active_runtime_contracts": active_runtime_contracts.duplicate(true),
		"runtime_contract_index": runtime_contract_index.duplicate(true),
		"runtime_contract_observations": runtime_contract_observations.duplicate(true),
		"runtime_contract_mutation_log": runtime_contract_mutation_log.duplicate(true),
		"last_report": last_report.duplicate(true)
	})


func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return { "success": false, "reason": "RuntimeContractEngine import_state expected a Dictionary."}

	active_runtime_contracts = _safe_dictionary(data.get("active_runtime_contracts", {}))
	runtime_contract_index = _safe_dictionary(data.get("runtime_contract_index", {}))
	runtime_contract_observations = _safe_dictionary(data.get("runtime_contract_observations", {}))
	runtime_contract_mutation_log = _safe_array(data.get("runtime_contract_mutation_log", []))
	last_report = _safe_dictionary(data.get("last_report", {}))

	_rebuild_contract_index()

	return {
		"success": true,
		"contract_count": active_runtime_contracts.size(),
		"index_count": runtime_contract_index.size()
	}

func _world_runtime_contracts_allowed(context: Dictionary = {}) -> bool:
	if bool(context.get("force_runtime_contracts", false)):
		return true

	if gs == null:
		return false

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		return true

	var source: String = str(context.get("source", "")).strip_edges().to_lower()
	var state: Dictionary = gs.scenario_state

	if bool(state.get("startup_intro_shell_only", false)):
		return false

	if bool(state.get("god_mode_candidate_seed_only", false)):
		return false

	if bool(state.get("materialize_world_seed_on_initialize", true)) == false \
and not bool(state.get("post_spawn_world_prewarm_pending", false)) \
and not bool(state.get("post_spawn_world_prewarm_complete", false)) \
and source.find("post_spawn") < 0:
		return false

	if bool(state.get("defer_static_world_bootstrap", false)) \
and not bool(state.get("post_spawn_world_prewarm_pending", false)) \
and not bool(state.get("post_spawn_world_prewarm_complete", false)) \
and source.find("post_spawn") < 0:
		return false

	if bool(state.get("life_runtime_systems_quarantined", false)) \
and not bool(state.get("post_spawn_world_prewarm_complete", false)):
		return false

	return true
func yearly_tick() -> void:
	if not _world_runtime_contracts_allowed({ "source": "yearly_tick"}):
		last_report = {
			"success": true,
			"deferred": true,
			"mode": "runtime_contract_yearly_tick_deferred",
			"reason": "world_runtime_contracts_not_allowed_yet",
			"updated_at_ms": int(Time.get_ticks_msec())
		}
		return

	lifecycle_tick({ "source": "yearly_tick"})
	advance_cultural_reality_contracts({ "source": "yearly_tick"})
	ensure_default_world_contracts({ "source": "yearly_tick"})


func route_command_envelope(envelope: Dictionary) -> Dictionary:
	if typeof(envelope) != TYPE_DICTIONARY or envelope.is_empty():
		return { "success": false, "reason": "Runtime contract command envelope is empty."}
	var command_id: String = str(envelope.get("command", envelope.get("action_id", ""))).strip_edges().to_lower()
	var payload: Dictionary = _safe_dictionary(envelope.get("payload", {}))
	match command_id:
		"runtime_contract.emit_defaults":
			return ensure_default_world_contracts(payload)
		"runtime_contract.emit_weapon_shop":
			return emit_weapon_shop_contract_for_current_world(payload)
		"runtime_contract.emit_school_sessions":
			return emit_school_session_contracts_for_current_world(payload)

		"school_session.emit":
			return emit_school_session_contracts_for_current_world(payload)
		"school.open":
			return emit_school_session_contracts_for_current_world(payload)
		"school.observe":
			var school_observer: Person = _actor_from_payload(payload)
			payload ["space_type"] = "school"
			return observe_runtime_contracts(school_observer, payload)

		"weapon_shop.emit":
			return emit_weapon_shop_contract_for_current_world(payload)
		"weapon_shop.open":
			return emit_weapon_shop_contract_for_current_world(payload)
		"weapon_shop.purchase":
			return purchase_weapon_from_contract(
				_actor_from_payload(payload),
				str(payload.get("contract_id", "")),
				str(payload.get("weapon_name", payload.get("weapon", ""))),
				payload
			)
		"runtime_contract.observe":
			var observer: Person = _actor_from_payload(payload)
			return observe_runtime_contracts(observer, payload)
		"runtime_contract.attach_actor":
			var attach_actor: Person = _actor_from_payload(payload)
			return attach_actor_to_contract(attach_actor, str(payload.get("contract_id", "")), payload)
		"runtime_contract.mutate":
			return mutate_contract(str(payload.get("contract_id", "")), _safe_dictionary(payload.get("mutation", {})), payload)
		"runtime_contract.lifecycle_tick":
			return lifecycle_tick(payload)
		_:
			return { "success": false, "reason": "No RuntimeContractEngine route claimed this command.", "command": command_id}

func ensure_default_world_contracts(context: Dictionary = {}) -> Dictionary:
	if not _world_runtime_contracts_allowed(context):
		last_report = {
			"success": true,
			"deferred": true,
			"mode": "runtime_contract_emit_defaults_deferred",
			"reason": "world_runtime_contracts_not_allowed_yet",
			"source": str(context.get("source", "")),
			"contract_count": active_runtime_contracts.size(),
			"updated_at_ms": int(Time.get_ticks_msec())
		}
		return last_report.duplicate(true)

	var emitted: Array = []
	var current_era: String = _current_era_name()

	var culture_report: Dictionary = emit_cultural_reality_contracts_for_current_world(context)
	emitted.append(culture_report)

	var school_report: Dictionary = emit_school_session_contracts_for_current_world(context)
	emitted.append(school_report)

	var weapon_shop_report: Dictionary = emit_weapon_shop_contract_for_current_world(context)
	emitted.append(weapon_shop_report)

	if current_era in ["Modern Era", "Future Era"]:
		var movie_report: Dictionary = emit_movie_theater_contracts_for_current_world(context)
		emitted.append(movie_report)

	last_report = {
		"success": true,
		"mode": "runtime_contract_emit_defaults",
		"era": current_era,
		"emitted": emitted,
		"contract_count": active_runtime_contracts.size(),
		"updated_at_ms": int(Time.get_ticks_msec())
	}
	return last_report.duplicate(true)
func emit_cultural_reality_contracts_for_current_world(context: Dictionary = {}) -> Dictionary:
	var era_name: String = _current_era_name()
	var country: String = _current_country()
	var culture: Dictionary = _culture_contract_for_world(era_name, country, context)
	var contract: Dictionary = _build_cultural_reality_runtime_contract(culture, context)
	var report: Dictionary = instantiate_contract(contract, {
		"source": str(context.get("source", "emit_cultural_reality_contracts_for_current_world")),
	})
	return {
		"success": bool(report.get("success", false)),
		"mode": "runtime_contract_emit_cultural_reality",
		"era": era_name,
		"country": country,
		"culture_id": str(culture.get("id", "")),
		"contract_id": str(report.get("contract_id", "")),
		"report": report.duplicate(true)
	}


func advance_cultural_reality_contracts(context: Dictionary = {}) -> Dictionary:
	var advanced: int = 0
	var drift_entries: Array = []

	for raw_id in active_runtime_contracts.keys():
		var contract_id: String = str(raw_id)
		var contract_data: Dictionary = _safe_dictionary(active_runtime_contracts.get(contract_id, {}))
		if contract_data.is_empty():
			continue
		if str(contract_data.get("contract_type", "")).strip_edges().to_lower() != "cultural_reality":
			continue

		var drift_report: Dictionary = _advance_single_cultural_reality_contract(contract_data, context)
		active_runtime_contracts [contract_id] = contract_data
		_sync_contract_into_world(contract_data)
		advanced += 1
		drift_entries.append(drift_report)

	return {
		"success": true,
		"mode": "runtime_contract_cultural_reality_drift",
		"advanced_count": advanced,
		"drift_entries": drift_entries
	}


func _build_cultural_reality_runtime_contract(culture: Dictionary, _context: Dictionary = {}) -> Dictionary:
	var era_name: String = _current_era_name()
	var country: String = _current_country()
	var culture_id: String = str(culture.get("id", "generic_culture")).strip_edges().to_lower()
	var runtime_key: String = "culture:%s:%s:%s" % [_current_country_key(), era_name.to_lower().replace(" ", "_"), culture_id]
	var contract_id: String = "rtc_culture_%s_%s_%s" % [_current_country_key(), culture_id, str(_current_year())]
	var behavior_bias: Dictionary = _safe_dictionary(culture.get("behavior_bias", {}))

	return {
		"schema": "eralife.runtime_contract.cultural_reality",
		"version": CONTRACT_VERSION,
		"contract_id": contract_id,
		"contract_type": "cultural_reality",
		"runtime_key": runtime_key,
		"state": "active",
		"created_year": _current_year(),
		"updated_year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec()),
		"updated_at_ms": int(Time.get_ticks_msec()),
		"culture": culture.duplicate(true),
		"reality_layer": {
			"source_of_truth": "culture",
			"pipeline": ["culture", "contracts", "npc_identity", "behavior", "history", "ui_observer"],
			"era": era_name,
			"country": country
		},
		"identity_contract": _safe_dictionary(culture.get("ruler_identity_contract", {})),
		"behavior_contract": _safe_dictionary(culture.get("behavior_contract", {})),
		"history_contract": _safe_dictionary(culture.get("history_contract", {})),
		"ui_contract": _safe_dictionary(culture.get("ui_contract", {})),
		"cultural_state": {
			"cohesion": clamp(62 + int(behavior_bias.get("loyalty", 0)), 0, 100),
			"rebellion_pressure": clamp(24 + int(behavior_bias.get("rebellion", 0)), 0, 100),
			"stability": clamp(55 + int(behavior_bias.get("stability", 0)), 0, 100),
			"diplomatic_respect": clamp(45 + int(behavior_bias.get("diplomacy", 0)), 0, 100),
			"drift_index": 0,
			"dominant_values": _safe_array(culture.get("values", [])),
			"last_history_entry": ""
		},
		"contract_mesh": {
			"tags": ["culture", "identity", "behavior", "history", "observable_reality"],
			"can_interact_with": ["realms", "relationships", "crime", "jobs", "fame", "public_space", "runtime_contracts"],
		}
	}


func _advance_single_cultural_reality_contract(contract_data: Dictionary, context: Dictionary = {}) -> Dictionary:
	var culture: Dictionary = _safe_dictionary(contract_data.get("culture", {}))
	var cultural_state: Dictionary = _safe_dictionary(contract_data.get("cultural_state", {}))
	var behavior_contract: Dictionary = _safe_dictionary(contract_data.get("behavior_contract", {}))
	var bias: Dictionary = _safe_dictionary(behavior_contract.get("bias", culture.get("behavior_bias", {})))
	var year_value: int = _current_year()
	var seed_material: String = "%s|%s|%s|%s" % [
		str(contract_data.get("contract_id", "")),
		str(year_value),
		str(cultural_state.get("drift_index", 0)),
		str(context.get("source", "cultural_tick"))
	]

	var rng:= RandomNumberGenerator.new()
	rng.seed = _stable_seed(seed_material)

	var cohesion_shift: int = int(rng.randi_range(-3, 3)) + int(round(float(bias.get("loyalty", 0)) / 10.0))
	var rebellion_shift: int = int(rng.randi_range(-2, 4)) + int(round(float(bias.get("rebellion", 0)) / 10.0))
	var stability_shift: int = int(rng.randi_range(-4, 4)) + int(round(float(bias.get("stability", 0)) / 10.0))
	var diplomacy_shift: int = int(rng.randi_range(-3, 3)) + int(round(float(bias.get("diplomacy", 0)) / 10.0))

	cultural_state ["cohesion"] = clamp(int(cultural_state.get("cohesion", 50)) + cohesion_shift, 0, 100)
	cultural_state ["rebellion_pressure"] = clamp(int(cultural_state.get("rebellion_pressure", 25)) + rebellion_shift, 0, 100)
	cultural_state ["stability"] = clamp(int(cultural_state.get("stability", 50)) + stability_shift, 0, 100)
	cultural_state ["diplomatic_respect"] = clamp(int(cultural_state.get("diplomatic_respect", 45)) + diplomacy_shift, 0, 100)
	cultural_state ["drift_index"] = int(cultural_state.get("drift_index", 0)) + 1

	var history_entry: String = _cultural_reality_history_entry(culture, cultural_state, rng)
	cultural_state ["last_history_entry"] = "%d: %s" % [year_value, history_entry]

	var history_log: Array = _safe_array(contract_data.get("history_log", []))
	history_log.append(cultural_state ["last_history_entry"])
	if history_log.size() > 40:
		history_log = history_log.slice(history_log.size() - 40, history_log.size())

	contract_data ["cultural_state"] = cultural_state
	contract_data ["history_log"] = history_log
	contract_data ["updated_year"] = year_value
	contract_data ["updated_at_ms"] = int(Time.get_ticks_msec())

	return {
		"contract_id": str(contract_data.get("contract_id", "")),
		"culture_id": str(culture.get("id", "")),
		"history_entry": cultural_state ["last_history_entry"],
		"cultural_state": cultural_state.duplicate(true)
	}


func _cultural_reality_history_entry(culture: Dictionary, cultural_state: Dictionary, rng: RandomNumberGenerator) -> String:
	var display_name: String = str(culture.get("display_name", "The culture")).strip_edges()
	var values: Array = _safe_array(culture.get("values", []))
	var cities: Array = _safe_array(culture.get("city_pool", []))
	var prefer_actions: Array = _safe_array(_safe_dictionary(culture.get("behavior_contract", {})).get("prefer_actions", []))

	var value_text: String = "identity"
	if not values.is_empty():
		value_text = str(values [int(rng.randi_range(0, values.size() - 1))])

	var city_text: String = _current_city()
	if not cities.is_empty():
		city_text = str(cities [int(rng.randi_range(0, cities.size() - 1))])

	var action_text: String = "shifted public expectations"
	if not prefer_actions.is_empty():
		action_text = str(prefer_actions [int(rng.randi_range(0, prefer_actions.size() - 1))]).replace("_", " ")

	var rebellion_pressure: int = int(cultural_state.get("rebellion_pressure", 0))
	var stability: int = int(cultural_state.get("stability", 50))

	if rebellion_pressure >= 70:
		return "%s faced open unrest in %s as %s collided with daily life." % [display_name, city_text, value_text]
	if stability >= 72:
		return "%s reinforced %s in %s and the realm felt more coherent." % [display_name, value_text, city_text]

	return "%s quietly pushed leaders to %s near %s." % [display_name, action_text, city_text]


func _culture_contract_for_world(era_name: String, country: String, _context: Dictionary = {}) -> Dictionary:
	var lower_era: String = str(era_name).strip_edges().to_lower()
	var lower_country: String = str(country).strip_edges().to_lower()

	if lower_country.find("egypt") >= 0 and lower_era.find("ancient") >= 0:
		return _make_runtime_culture_contract("ancient_egypt", "Ancient Egyptian Culture", ["order", "afterlife", "divinity", "monumentality"], ["Thebes", "Memphis", "Heliopolis", "Alexandria", "Abydos"], "divine monarchy", "Pharaoh", "of_city", { "loyalty": 20, "rebellion": -15, "stability": 16, "diplomacy": 2, "monuments": 18}, ["preserve_order", "honor_gods", "build_monuments"], ["rebellion", "desecration"])

	if lower_era.find("ancient") >= 0:
		return _make_runtime_culture_contract("ancient_dynastic", "Ancient Dynastic Culture", ["lineage", "omens", "conquest", "ritual"], ["Babylon", "Ur", "Nineveh", "Tyre", "Persepolis"], "dynastic monarchy", "King", "of_city", { "loyalty": 8, "rebellion": -3, "stability": 5, "militarism": 8, "diplomacy": 2}, ["expand_dynasty", "honor_omens", "secure_grain"], ["weak_succession", "dynastic_shame"])

	if lower_era.find("medieval") >= 0:
		return _make_runtime_culture_contract("medieval_feudal", "Medieval Feudal Culture", ["lineage", "faith", "land", "oaths"], ["York", "Winchester", "Canterbury", "London", "Norwich"], "feudal monarchy", "King", "of_city", { "loyalty": 5, "rebellion": 6, "stability": -2, "diplomacy": 8, "militarism": 10}, ["form_alliances", "defend_lineage", "wage_claim_wars"], ["break_oaths", "ignore_vassals"])

	if lower_era.find("future") >= 0:
		return _make_runtime_culture_contract("future_civic_algorithmic", "Future Civic Culture", ["efficiency", "innovation", "surveillance", "mobility"], ["Neo Tokyo", "New Shanghai", "Lagos Arcology", "Toronto Spire", "Chicago Grid"], "technocratic republic", "President", "family_name", { "loyalty": 0, "rebellion": 4, "stability": 8, "innovation": 18, "privacy": -10}, ["optimize_systems", "expand_infrastructure", "manage_risk"], ["systemic_decay", "untracked_instability"])

	return _make_runtime_culture_contract("modern_civic", "Modern Civic Culture", ["rights", "commerce", "identity", "public_opinion"], [], "civic state", "", "family_name", { "loyalty": 0, "rebellion": 2, "stability": 0, "diplomacy": 4, "commerce": 8}, ["manage_public_opinion", "grow_economy", "protect_rights"], ["public_scandal", "economic_collapse"])


func _make_runtime_culture_contract(id_text: String, display_name: String, values: Array, city_pool: Array, power_structure: String, ruler_title: String, name_format: String, behavior_bias: Dictionary, prefer_actions: Array, avoid_actions: Array) -> Dictionary:
	return {
		"schema": "eralife.cultural_reality_contract",
		"version": 1,
		"id": str(id_text).strip_edges().to_lower(),
		"display_name": str(display_name).strip_edges(),
		"values": _safe_array(values),
		"naming_rules": "contract_defined",
		"city_pool": _safe_array(city_pool),
		"power_structure": str(power_structure),
		"behavior_bias": _safe_dictionary(behavior_bias),
		"ruler_identity_contract": {
			"must_have_title": str(ruler_title).strip_edges(),
			"name_format": str(name_format).strip_edges().to_lower(),
			"valid_origin_cities": _safe_array(city_pool)
		},
		"behavior_contract": {
			"prefer_actions": _safe_array(prefer_actions),
			"avoid_actions": _safe_array(avoid_actions),
			"bias": _safe_dictionary(behavior_bias)
		},
		"history_contract": {
		},
		"ui_contract": {
			"observer_only": true,
		}
	}

func emit_movie_theater_contracts_for_current_world(context: Dictionary = {}) -> Dictionary:
	if gs == null or gs.movie_theater_engine == null:
		return { "success": false, "reason": "MovieTheaterEngine unavailable.", "emitted_count": 0}

	if not gs.movie_theater_engine.has_method("get_theaters_for_era"):
		return { "success": false, "reason": "MovieTheaterEngine cannot provide theaters.", "emitted_count": 0}

	var era_name: String = _current_era_name()
	var theaters: Array = gs.movie_theater_engine.get_theaters_for_era(era_name)
	var emitted_contracts: Array = []

	for raw_theater in theaters:
		if typeof(raw_theater) != TYPE_DICTIONARY:
			continue

		var theater: Dictionary = raw_theater as Dictionary
		var contract: Dictionary = _build_movie_theater_runtime_contract(theater, context)
		var report: Dictionary = instantiate_contract(contract, {
			"source": str(context.get("source", "emit_movie_theater_contracts_for_current_world")),
		})

		if bool(report.get("success", false)):
			emitted_contracts.append(str(report.get("contract_id", "")))

	return {
		"success": true,
		"mode": "runtime_contract_emit_movie_theaters",
		"era": era_name,
		"country": _current_country(),
		"city": _current_city(),
		"emitted_count": emitted_contracts.size(),
		"contract_ids": emitted_contracts
	}

func emit_weapon_shop_contract_for_current_world(context: Dictionary = {}) -> Dictionary:
	if gs == null:
		return { "success": false, "reason": "GameState unavailable.", "emitted_count": 0}
	if gs.weapons_engine == null:
		return { "success": false, "reason": "WeaponsEngine unavailable.", "emitted_count": 0}
	var contract: Dictionary = _build_weapon_shop_runtime_contract(context)
	var report: Dictionary = instantiate_contract(contract, {
		"source": str(context.get("source", "emit_weapon_shop_contract_for_current_world")),
	})
	var contract_id: String = str(report.get("contract_id", "")).strip_edges()
	var active_contract: Dictionary = contract.duplicate(true)
	if contract_id != "" and active_runtime_contracts.has(contract_id):
		active_contract = _safe_dictionary(active_runtime_contracts.get(contract_id, contract))
	return {
		"success": bool(report.get("success", false)),
		"mode": "runtime_contract_emit_weapon_shop",
		"era": _current_era_name(),
		"country": _current_country(),
		"city": _current_city(),
		"contract_id": contract_id,
		"runtime_key": str(report.get("runtime_key", "")),
		"vendor": _safe_dictionary(active_contract.get("vendor", {})),
		"inventory_count": _safe_array(active_contract.get("inventory", [])).size(),
		"contract": active_contract.duplicate(true),
		"report": report.duplicate(true)
	}
func _rick_weapon_shop_seed_flow_count(rng: RandomNumberGenerator, chance: float = 0.65, max_group: int = 5) -> int:
	var clean_chance: float = clamp(chance, 0.0, 1.0)
	var clean_max: int = int(clamp(max_group, 1, 5))
	if rng.randf() > clean_chance:
		return 0

	var roll: float = rng.randf()
	if clean_max >= 5 and roll >= 0.96:
		return 5
	if clean_max >= 4 and roll >= 0.9:
		return 4
	if clean_max >= 3 and roll >= 0.78:
		return 3
	if clean_max >= 2 and roll >= 0.54:
		return 2
	return 1
func _rick_weapon_shop_runtime_first_names() -> Array:
	return ["Avery", "Jordan", "Maya", "Chris", "Taylor", "Sam", "Riley", "Morgan", "Imani", "Devon", "Andre", "Nia", "Kai", "Noelle", "Talia", "Malik", "Sienna", "Jasper", "Amara", "Theo"]


func _rick_weapon_shop_runtime_last_names() -> Array:
	return ["Vale", "Cross", "Stone", "Rivera", "Chen", "Okafor", "Bennett", "Hale", "Morrow", "Reed", "Sato", "Nadir", "Brooks", "Khan", "West", "Bell", "Ashford", "Grey", "Locke", "Marin"]


func _rick_weapon_shop_inventory_name_for_runtime(rng: RandomNumberGenerator, inventory: Array) -> String:
	var weapon_names: Array = []
	for raw_weapon in inventory:
		if typeof(raw_weapon) != TYPE_DICTIONARY:
			continue
		var weapon: Dictionary = raw_weapon as Dictionary
		var weapon_name: String = str(weapon.get("name", weapon.get("display_name", ""))).strip_edges()
		if weapon_name != "":
			weapon_names.append(weapon_name)

	if weapon_names.is_empty():
		var fallback: Array = ["the front wall", "the cheap rack", "the expensive rack", "the thing Rick definitely should not be selling"]
		return str(fallback [int(rng.randi_range(0, fallback.size() - 1))])

	return str(weapon_names [int(rng.randi_range(0, weapon_names.size() - 1))])


func _rick_weapon_shop_runtime_person(rng: RandomNumberGenerator, zone_id: String, activity: String, inventory: Array = []) -> Dictionary:
	var first_names: Array = _rick_weapon_shop_runtime_first_names()
	var last_names: Array = _rick_weapon_shop_runtime_last_names()
	var first_name: String = str(first_names [int(rng.randi_range(0, first_names.size() - 1))])
	var last_name: String = str(last_names [int(rng.randi_range(0, last_names.size() - 1))])
	var target: String = _rick_weapon_shop_inventory_name_for_runtime(rng, inventory) if zone_id == "browsing" else ""

	return {
		"person_id": "rick_shop_person_%s_%d_%d" % [zone_id, int(Time.get_ticks_msec()), int(rng.randi_range(1000, 9999))],
		"first_name": first_name,
		"last_name": last_name,
		"full_name": "%s %s" % [first_name, last_name],
		"age": int(rng.randi_range(18, 74)),
		"zone_id": zone_id,
		"activity": activity,
		"eyeballing": target,
		"created_at_ms": int(Time.get_ticks_msec())
	}


func _rick_weapon_shop_runtime_people_group(rng: RandomNumberGenerator, count: int, zone_id: String, activity: String, inventory: Array = []) -> Array:
	var people: Array = []
	for i in range(max(0, count)):
		people.append(_rick_weapon_shop_runtime_person(rng, zone_id, activity, inventory))
	return people
func _build_weapon_shop_runtime_state(country: String, city: String, era_name: String, shop_id: String, _context: Dictionary = {}, inventory: Array = []) -> Dictionary:
	var rng:= RandomNumberGenerator.new()
	rng.seed = _stable_seed("rick_weapon_shop_state|%s|%s|%s|%s|%s|%s" % [
		country,
		city,
		era_name,
		shop_id,
		str(_current_year()),
		str(Time.get_ticks_msec())
	])

	var browsing_count: int = int(rng.randi_range(0, 3))
	var checkout_count: int = int(rng.randi_range(0, 1))
	var walking_by_count: int = _rick_weapon_shop_seed_flow_count(rng, 0.72, 5)
	var browsing_people: Array = _rick_weapon_shop_runtime_people_group(rng, browsing_count, "browsing", "eyeballing the weapon wall", inventory)
	var checkout_person: Dictionary = _rick_weapon_shop_runtime_person(rng, "checkout", "checking out with Rick", inventory) if checkout_count > 0 else {}

	return {
		"mode": "outside",
		"seeded_at_ms": int(Time.get_ticks_msec()),
		"outside": {
			"people_walking_by": walking_by_count,
			"people_walking_in": 0,
			"people_walking_out": 0,
			"pending_people_inside": 0,
			"next_tick_ms": int(Time.get_ticks_msec()) + int(rng.randi_range(900, 2400))
		},
		"outside_people": {
			"walking_by": _rick_weapon_shop_runtime_people_group(rng, walking_by_count, "walking_by", "walking past Rick's shop", inventory),
			"walking_in": [],
			"walking_out": []
		},
		"inside": {
			"people_browsing": browsing_people.size(),
			"person_checking_out": 1 if not checkout_person.is_empty() else 0,
			"browsers": browsing_people,
			"checking_out_person": checkout_person,
			"player_cart": [],
			"player_holding_for_checkout": false,
			"held_weapon_name": "",
			"checkout_section_open": false,
			"last_live_line": _rick_weapon_shop_checkout_line(rng) if checkout_count > 0 else "",
			"rick_live_text": "Rick is somewhere behind the counter, already aware of the door.",
			"next_tick_ms": int(Time.get_ticks_msec()) + int(rng.randi_range(1100, 3200))
		},
		"rules": {
			"max_person_checking_out": 1,
			"max_visible_walking_group": 5,
			"counter_semantics": "instantaneous_visible_flow_not_cumulative",
			"timing_style": "consistently_inconsistent",
		}
	}
func _rick_weapon_shop_checkout_line(rng: RandomNumberGenerator) -> String:
	var lines: Array = [
		"Customer: \"Thanks, Rick.\"\nRick: \"Try not to make the local guards learn your name.\"",
		"Customer: \"Is this safe?\"\nRick: \"Compared to what you were going to do without it? Sure.\"",
		"Customer: \"Do you do refunds?\"\nRick: \"Only in timelines nobody likes.\"",
		"Customer: \"Bye, Rick.\"\nRick: \"Walk slowly. Fast people explain themselves to doctors.\""
	]
	return str(lines [int(rng.randi_range(0, lines.size() - 1))])
func _weapon_shop_inventory_from_global_object_catalog(
	context: Dictionary = {}
) -> Array:
	var query: Dictionary = context.duplicate(true)
	var actor: Person = _actor_from_payload(
		query
	)

	query ["actor_id"] = (
		int(
			actor.id
		)
		if actor != null
		else int(
			query.get(
				"actor_id",
				-1
			)
		)
	)
	query ["domain"] = "weapon"
	query ["ownership_scope"] = "available"
	query ["include_catalog_definitions"] = true
	query ["include_owned_instances"] = false
	query ["include_modded"] = true
	query ["include_illegal"] = true

	var catalog_objects: Array = []

	if (
		gs != null
		and gs.global_object_catalog_system != null
		and gs.global_object_catalog_system.has_method(
			"get_available_objects"
		)
	):
		catalog_objects = _safe_array(
			gs.global_object_catalog_system.get_available_objects(
				query
			)
		)

	var out: Array = []

	for raw_object in catalog_objects:
		if typeof(
			raw_object
		) != TYPE_DICTIONARY:
			continue

		var object_contract: Dictionary = (
			raw_object as Dictionary
		).duplicate(true)
		var purchase_row: Dictionary = {}

		if (
			gs != null
			and gs.weapons_catalog_expansion != null
			and gs.weapons_catalog_expansion.has_method(
				"purchase_definition_from_object"
			)
		):
			purchase_row = _safe_dictionary(
				gs.weapons_catalog_expansion
				.purchase_definition_from_object(
					object_contract
				)
			)

		if purchase_row.is_empty():
			purchase_row = _safe_dictionary(
				object_contract.get(
					"source_payload",
					object_contract.get(
						"source_contract",
						{}
					)
				)
			)

		if purchase_row.is_empty():
			purchase_row = object_contract.duplicate(true)

		var legal_contract: Dictionary = _safe_dictionary(
			object_contract.get(
				"legal_contract",
				object_contract.get(
					"legal",
					{}
				)
			)
		)
		var ownership_contract: Dictionary = _safe_dictionary(
			object_contract.get(
				"ownership_contract",
				object_contract.get(
					"ownership",
					{}
				)
			)
		)
		var display_name: String = str(
			object_contract.get(
				"display_name",
				purchase_row.get(
					"display_name",
					purchase_row.get(
						"name",
						"Weapon"
					)
				)
			)
		).strip_edges()
		var weapon_type: String = str(
			object_contract.get(
				"subtype",
				object_contract.get(
					"asset_kind",
					purchase_row.get(
						"type",
						"weapon"
					)
				)
			)
		).strip_edges().to_lower()
		var legal: bool = bool(
			legal_contract.get(
				"legal",
				purchase_row.get(
					"legal",
					true
				)
			)
		)
		var license_required: bool = bool(
			legal_contract.get(
				"license_required",
				purchase_row.get(
					"license_required",
					false
				)
			)
		)
		var owned: bool = bool(
			ownership_contract.get(
				"owned",
				purchase_row.get(
					"owned",
					false
				)
			)
		)
		var cost: int = int(
			_safe_dictionary(
				object_contract.get(
					"value_contract",
					{}
				)
			).get(
				"base_value",
				object_contract.get(
					"cost",
					purchase_row.get(
						"cost",
						0
					)
				)
			)
		)

		purchase_row ["name"] = display_name
		purchase_row ["display_name"] = display_name
		purchase_row ["type"] = weapon_type
		purchase_row ["cost"] = cost
		purchase_row ["value"] = int(
			purchase_row.get(
				"value",
				cost
			)
		)
		purchase_row ["legal"] = legal
		purchase_row ["license_required"] = license_required
		purchase_row ["owned"] = owned
		purchase_row ["available"] = bool(
			object_contract.get(
				"available",
				purchase_row.get(
					"available",
					true
				)
			)
		)
		purchase_row ["can_afford"] = (
			float(
				actor.bank_balance
			) >= float(
				cost
			)
			if actor != null
			else false
		)
		purchase_row ["legality_label"] = str(
			legal_contract.get(
				"label",
				(
					"Illegal / Restricted"
					if not legal
					else (
						"Legal With License"
						if license_required
						else "Legal"
					)
				)
			)
		)
		purchase_row ["license_label"] = (
			"License Required"
			if license_required
			else "No License Required"
		)
		purchase_row ["catalog_object_id"] = str(
			object_contract.get(
				"catalog_object_id",
				object_contract.get(
					"object_id",
					""
				)
			)
		)
		purchase_row ["object_domains"] = _safe_array(
			object_contract.get(
				"object_domains",
				[
					"weapon"
				]
			)
		)
		purchase_row ["object_contract"] = (
			object_contract.duplicate(true)
		)
		purchase_row ["catalog_validated"] = true
		out.append(
			purchase_row
		)

	if (
		out.is_empty()
		and gs != null
		and gs.weapons_engine != null
	):
		if gs.weapons_engine.has_method(
			"get_weapons_for_context"
		):
			return _safe_array(
				gs.weapons_engine.get_weapons_for_context(
					query
				)
			)

		if gs.weapons_engine.has_method(
			"get_store"
		):
			return _safe_array(
				gs.weapons_engine.get_store()
			)

	return out
func _build_weapon_shop_runtime_contract(
	context: Dictionary = {}
) -> Dictionary:
	var era_name: String = _current_era_name()
	var country: String = _current_country()
	var city: String = _current_city()
	var shop_id: String = "rick_weapon_shop"
	var runtime_key: String = "space:%s:weapon_shop:%s" % [
		_current_country_key(),
		shop_id
	]
	var contract_id: String = "rtc_weapon_shop_%s_%s" % [
		_current_country_key(),
		str(
			_current_year()
		)
	]
	var weapon_context: Dictionary = context.duplicate(true)

	weapon_context ["era"] = era_name
	weapon_context ["country"] = country
	weapon_context ["city"] = city
	weapon_context ["shop_id"] = shop_id
	weapon_context ["vendor"] = "rick"

	var inventory: Array = (
		_weapon_shop_inventory_from_global_object_catalog(
			weapon_context
		)
	)
	var rick: Dictionary = resolve_rick_manifestation(
		country,
		era_name
	)
	var flavor: Dictionary = _rick_manifestation_flavor(
		country,
		era_name
	)
	var actor: Person = _actor_from_payload(
		context
	)
	var recognition: Dictionary = _rick_player_recognition(
		actor,
		country,
		era_name
	)
	var runtime_state: Dictionary = _build_weapon_shop_runtime_state(
		country,
		city,
		era_name,
		shop_id,
		context,
		inventory
	)

	return {
		"schema": WEAPON_SHOP_CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"contract_id": contract_id,
		"contract_type": "weapon_shop",
		"runtime_key": runtime_key,
		"state": "active",
		"created_year": _current_year(),
		"updated_year": _current_year(),
		"created_at_ms": int(
			Time.get_ticks_msec()
		),
		"updated_at_ms": int(
			Time.get_ticks_msec()
		),
		"time_model": {
			"explanation": (
				"Rick is a persistent global entity whose shop "
				+ "manifests locally through runtime contracts."
			)
		},
		"location": {
			"space_type": "weapon_shop",
			"space_id": shop_id,
			"name": _weapon_shop_name_for_context(
				era_name,
				country
			),
			"city": city,
			"country": country,
			"era": era_name
		},
		"public_space": {
			"space_type": "weapon_shop",
			"space_id": shop_id,
			"session_key": "weapon_shop:rick",
			"zone_ids": [
				"outside",
				"counter",
				"wall_racks",
				"back_room"
			]
		},
		"shop_runtime_state": runtime_state,
		"vendor": rick,
		"rick_flavor": flavor,
		"player_recognition": recognition,
		"inventory": inventory,
		"commerce": {
			"currency": _weapon_shop_currency_for_era(
				era_name
			),
			"prices_defined_by": "WeaponsEngine",
			"catalog_resolved_by": (
				"GlobalObjectCatalogSystem"
			),
			"legality_resolved_by": "WeaponsEngine",
			"vendor": "rick"
		},
		"weapon_shop_contract": {
			"type": "weapon_shop_contract",
			"vendor": "rick",
			"era": era_name,
			"location": country,
			"inventory_source": (
				"global_object_catalog_system"
				+ ".get_available_objects"
			),
			"object_domain": "weapon",
			"identity_rule": (
				"rick_global_entity_local_manifestation"
			)
		},
		"memory_echoes": _rick_memory_echoes(
			actor,
			country,
			era_name
		),
		"transaction_log": _safe_array(
			context.get(
				"transaction_log",
				[]
			)
		),
		"systems": {
			"catalog": "global_object_catalog_system",
			"weapon_catalog": "weapons_catalog_expansion",
			"specialization": "weapons_engine",
			"runtime": "runtime_contract_engine",
			"consequence": "upce_engine",
			"crime": "crime_engine",
			"reputation": "reputation_engine",
			"belongings": "belongings_engine"
		},
		"contract_mesh": {
			"tags": [
				"commerce",
				"objects",
				"weapons",
				"era_legal",
				"rick",
				"persistent_entity",
				"observable_reality"
			],
			"can_interact_with": [
				"crime",
				"belongings",
				"inventory",
				"heirlooms",
				"artifacts",
				"reputation",
				"fame",
				"runtime_contracts"
			],
		}
	}
func purchase_weapon_from_contract(
	actor: Person,
	contract_id: String,
	weapon_name: String,
	context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"popup_title": "Rick Is Gone?",
			"popup_text": (
				"No actor was supplied to the weapon shop contract."
			),
			"popup_footer": "Tap anywhere to continue."
		}

	var clean_weapon: String = str(
		weapon_name
	).strip_edges()

	if clean_weapon == "":
		return {
			"success": false,
			"popup_title": "Pick Something First",
			"popup_text": (
				"Rick waits for you to point at an actual weapon."
			),
			"popup_footer": "Tap anywhere to continue."
		}

	var clean_id: String = str(
		contract_id
	).strip_edges()

	if (
		clean_id == ""
		or not active_runtime_contracts.has(
			clean_id
		)
	):
		var emit_report: Dictionary = (
			emit_weapon_shop_contract_for_current_world(
				context
			)
		)
		clean_id = str(
			emit_report.get(
				"contract_id",
				""
			)
		).strip_edges()

	if (
		clean_id == ""
		or not active_runtime_contracts.has(
			clean_id
		)
	):
		return {
			"success": false,
			"popup_title": "Weapon Shop Contract Missing",
			"popup_text": (
				"Rick's shop could not be manifested in this reality."
			),
			"popup_footer": "Tap anywhere to continue."
		}

	var contract_data: Dictionary = _safe_dictionary(
		active_runtime_contracts.get(
			clean_id,
			{}
		)
	)

	if str(
		contract_data.get(
			"contract_type",
			""
		)
	).strip_edges().to_lower() != "weapon_shop":
		return {
			"success": false,
			"popup_title": "Wrong Contract",
			"popup_text": "That contract is not a weapon shop.",
			"popup_footer": "Tap anywhere to continue."
		}

	var inventory: Array = _safe_array(
		contract_data.get(
			"inventory",
			[]
		)
	)
	var found_weapon: Dictionary = {}
	var clean_lookup: String = clean_weapon.to_lower()

	for raw_weapon in inventory:
		if typeof(
			raw_weapon
		) != TYPE_DICTIONARY:
			continue

		var weapon: Dictionary = raw_weapon as Dictionary
		var candidate_ids: Array = [
			str(
				weapon.get(
					"name",
					""
				)
			).strip_edges().to_lower(),
			str(
				weapon.get(
					"display_name",
					""
				)
			).strip_edges().to_lower(),
			str(
				weapon.get(
					"catalog_object_id",
					""
				)
			).strip_edges().to_lower()
		]

		if clean_lookup in candidate_ids:
			found_weapon = weapon.duplicate(true)
			break

	if found_weapon.is_empty():
		return {
			"success": false,
			"popup_title": "Not On The Wall",
			"popup_text": (
				"Rick does not sell %s in this era or realm."
				% clean_weapon
			),
			"popup_footer": "Tap anywhere to continue."
		}

	if (
		gs == null
		or gs.weapons_engine == null
	):
		return {
			"success": false,
			"popup_title": "WeaponsEngine Missing",
			"popup_text": (
				"The weapon shop contract resolved, but the "
				+ "WeaponsEngine is unavailable."
			),
			"popup_footer": "Tap anywhere to continue."
		}

	var buy_report: Dictionary = {}
	var buy_context: Dictionary = {
		"actor_id": int(
			actor.id
		),
		"contract_id": clean_id,
		"weapon": found_weapon,
		"object_contract": found_weapon.get(
			"object_contract",
			{}
		),
		"vendor": contract_data.get(
			"vendor",
			{}
		),
		"location": contract_data.get(
			"location",
			{}
		),
		"era": _current_era_name(),
		"country": _current_country(),
		"city": _current_city(),
		"source": str(
			context.get(
				"source",
				"rick_weapon_shop_contract"
			)
		),
		"immutable_contract_references": true
	}

	if gs.weapons_engine.has_method(
		"buy_weapon_from_context"
	):
		var raw_report: Variant = (
			gs.weapons_engine.buy_weapon_from_context(
				str(
					found_weapon.get(
						"name",
						clean_weapon
					)
				),
				buy_context
			)
		)

		if typeof(
			raw_report
		) == TYPE_DICTIONARY:
			buy_report = (
				raw_report as Dictionary
			).duplicate(false)
		else:
			buy_report = {
				"success": false,
				"text": str(
					raw_report
				),
				"popup_text": str(
					raw_report
				)
			}
	else:
		var legacy_text: String = str(
			gs.weapons_engine.buy_weapon(
				clean_weapon
			)
		)

		buy_report = {
			"success": (
				legacy_text.find(
					"bought"
				) >= 0
				or legacy_text.find(
					"Bought"
				) >= 0
			),
			"text": legacy_text,
			"popup_title": "Rick's Counter",
			"popup_text": legacy_text,
			"popup_footer": "Tap anywhere to continue."
		}

	var transaction_log_raw: Variant = (
		contract_data.get(
			"transaction_log",
			[]
		)
	)
	var transaction_log: Array = (
		(
			transaction_log_raw as Array
		).duplicate(false)
		if typeof(
			transaction_log_raw
		) == TYPE_ARRAY
		else []
	)
	var vendor_raw: Variant = contract_data.get(
		"vendor",
		{}
	)
	var vendor: Dictionary = (
		vendor_raw as Dictionary
		if typeof(
			vendor_raw
		) == TYPE_DICTIONARY
		else {}
	)
	var transaction_row: Dictionary = {
		"year": _current_year(),
		"actor_id": int(
			actor.id
		),
		"weapon_name": str(
			found_weapon.get(
				"name",
				clean_weapon
			)
		),
		"catalog_object_id": str(
			found_weapon.get(
				"catalog_object_id",
				""
			)
		),
		"success": bool(
			buy_report.get(
				"success",
				false
			)
		),
		"vendor_id": "rick_global_entity",
		"vendor_display_name": str(
			vendor.get(
				"display_name",
				"Rick"
			)
		),
		"created_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	transaction_log.append(
		transaction_row
	)

	if transaction_log.size() > 80:
		transaction_log = transaction_log.slice(
			transaction_log.size() - 80,
			transaction_log.size()
		)

	contract_data [
		"transaction_log"
	] = transaction_log
	contract_data [
		"updated_year"
	] = _current_year()
	contract_data [
		"updated_at_ms"
	] = int(
		Time.get_ticks_msec()
	)




	active_runtime_contracts [
		clean_id
	] = contract_data

	buy_report ["contract_id"] = clean_id
	buy_report ["catalog_object_id"] = str(
		found_weapon.get(
			"catalog_object_id",
			buy_report.get(
				"catalog_object_id",
				""
			)
		)
	)
	buy_report ["transaction_delta"] = transaction_row
	buy_report ["shop_contract_refresh_required"] = false
	buy_report ["global_object_catalog_rescanned"] = false
	buy_report ["full_shop_contract_returned"] = false
	buy_report ["immutable_contract_references"] = true

	return buy_report

func resolve_weapon_shop_purchase_intent(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "missing_actor",
			"popup_title": "Rick's Weapon Shop",
			"popup_text": "No purchasing actor was supplied.",
			"popup_footer": "Tap anywhere to continue."
		}

	var bank_balance_before: int = maxi(
		0,
		int(
			round(
				float(
					actor.bank_balance
				)
			)
		)
	)

	var result: Dictionary = purchase_weapon_from_contract(
		actor,
		str(
			payload.get(
				"contract_id",
				""
			)
		),
		str(
			payload.get(
				"weapon_name",
				""
			)
		),
		payload
	)

	if bool(
		result.get(
			"success",
			false
		)
	):
		var bank_balance_after: int = maxi(
			0,
			int(
				round(
					float(
						actor.bank_balance
					)
				)
			)
		)

		result ["bank_report"] = {
			"schema": "eralife.bank_delta_contract",
			"version": 1,
			"actor_id": int(
				actor.id
			),
			"previous_balance": bank_balance_before,
			"new_balance": bank_balance_after,
			"balance": bank_balance_after,
			"bank_delta": (
				bank_balance_after
				- bank_balance_before
			),
			"transaction_kind": "weapon_purchase",
			"transaction_committed": true,
			"source": (
				"RuntimeContractEngine."
				+ "resolve_weapon_shop_purchase_intent"
			),
			"truth_state": "hot",
			"ui_is_renderer_only": true
		}

	return result

func resolve_rick_manifestation(country: String, era: String) -> Dictionary:
	return {
		"id": "rick_global_entity",
		"display_name": _rick_localized_name(country, era),
		"base_name": "Rick",
		"culture": str(country).strip_edges(),
		"era": str(era).strip_edges(),
		"role": "weapons_merchant",
		"personality_traits": ["dry", "observant", "unhurried", "impossible_to_surprise", "merchant_philosopher"],
		"identity_rules": {
		}
	}


func _rick_localized_name(country: String, era: String) -> String:
	var tag: String = _rick_cultural_tag(country, era)
	if tag == "":
		return "Rick"
	if tag == "a monk":
		return "Rick but a monk"
	if tag.begins_with("from "):
		return "Rick but %s" % tag
	return "Rick but %s" % tag


func _rick_cultural_tag(country: String, _era: String) -> String:
	var normalized: String = str(country).strip_edges().to_lower()
	var exact_map: Dictionary = {
		"china": "Chinese",
		"ancient china": "Chinese",
		"japan": "Japanese",
		"south korea": "Korean",
		"korea": "Korean",
		"greece": "Greek",
		"ancient greece": "Greek",
		"rome": "Roman",
		"roman empire": "Roman",
		"egypt": "Egyptian",
		"ancient egypt": "Egyptian",
		"assyria": "Assyrian",
		"assyrian empire": "Assyrian",
		"babylon": "Babylonian",
		"babylonian empire": "Babylonian",
		"persia": "Persian",
		"persian empire": "Persian",
		"mali": "from Mali",
		"mali empire": "from Mali",
		"kingdom of aksum": "from Aksum",
		"kingdom of askum": "from Askum",
		"aksum": "from Aksum",
		"askum": "from Askum",
		"maurya empire": "Mauryan",
		"india": "Indian",
		"united states": "American",
		"america": "American",
		"usa": "American",
		"mexico": "Mexican",
		"canada": "Canadian",
		"brazil": "Brazilian",
		"france": "French",
		"germany": "German",
		"england": "English",
		"united kingdom": "British",
		"spain": "Spanish",
		"italy": "Italian",
		"russia": "Russian",
		"nigeria": "Nigerian",
		"ghana": "Ghanaian",
		"ethiopia": "Ethiopian",
		"kenya": "Kenyan",
		"zulu kingdom": "Zulu",
		"aztec empire": "Aztec",
		"maya": "Mayan",
		"inca empire": "Incan",
		"ottoman empire": "Ottoman",
		"mongol empire": "Mongolian",
		"viking realm": "Norse"
	}
	if exact_map.has(normalized):
		return str(exact_map.get(normalized))
	if normalized.find("air temple") >= 0:
		return "a monk"
	if normalized.find("fire nation") >= 0:
		return "Fire Nation"
	if normalized.find("earth kingdom") >= 0:
		return "Earth Kingdom"
	if normalized.find("southern water") >= 0:
		return "Southern Water Nation"
	if normalized.find("northern water") >= 0:
		return "Northern Water Nation"
	if normalized.find("water tribe") >= 0:
		return "Water Tribe"
	if normalized.find("mali") >= 0:
		return "from Mali"
	if normalized.find("assyr") >= 0:
		return "Assyrian"
	if normalized.find("egypt") >= 0:
		return "Egyptian"
	if normalized.find("china") >= 0:
		return "Chinese"
	if normalized.find("greece") >= 0:
		return "Greek"
	if normalized.find("america") >= 0 or normalized.find("united states") >= 0:
		return "American"
	var clean_country: String = str(country).strip_edges()
	if clean_country == "":
		return "local"
	return "from %s" % clean_country


func _rick_manifestation_flavor(country: String, era: String) -> Dictionary:
	var normalized: String = str(country).strip_edges().to_lower()
	if normalized.find("fire nation") >= 0:
		return {
			"appearance": "Charcoal armor, ember-lit cuffs, and a slight smirk that looks older than the throne.",
			"temperament": "Warm, blunt, impossible to intimidate.",
			"quote": "Heat makes everything honest.",
			"shopkeeper_note": "Rick taps the counter once. The metal answers like it remembers war."
		}
	if normalized.find("water tribe") >= 0 or normalized.find("southern water") >= 0 or normalized.find("northern water") >= 0:
		return {
			"appearance": "A fur-lined coat, seal-bone toggles, and eyes calm enough to make storms feel loud.",
			"temperament": "Patient, observant, quietly severe.",
			"quote": "Cold preserves more than bodies... it preserves choices.",
			"shopkeeper_note": "Rick slides a wrapped blade across the counter like he is returning something borrowed by history."
		}
	if normalized.find("air temple") >= 0:
		return {
			"appearance": "Monk robes, prayer beads, and the exact face of a man pretending this is not a weapon shop.",
			"temperament": "Gentle, evasive, deeply suspicious for someone selling sharp objects.",
			"quote": "Tools are neutral. Intent is not.",
			"shopkeeper_note": "Rick insists he does not believe in weapons. The wall behind him disagrees."
		}
	if normalized.find("earth kingdom") >= 0:
		return {
			"appearance": "Heavy build, grounded stance, stone-dust on his sleeves, and boots that look legally immovable.",
			"temperament": "Practical, firm, mountain-dry.",
			"quote": "Weight matters. In weapons... and in decisions.",
			"shopkeeper_note": "Rick weighs the weapon in one hand, then weighs you with both eyes."
		}

	var culture_tag: String = _rick_cultural_tag(country, era)
	var era_lower: String = str(era).strip_edges().to_lower()
	var fallback_quote: String = "Everything has an edge. Some people just find theirs late."
	var appearance: String = "A local coat, familiar boots, and the same impossible Rick expression wearing a different century."
	if era_lower.find("ancient") >= 0:
		appearance = "Bronze clasps, dust-colored linen, and a counter that smells like oil, leather, and prophecy."
		fallback_quote = "Old metal does not forget the hand that lifted it."
	elif era_lower.find("medieval") >= 0:
		appearance = "A dark apron over travel-worn layers, iron rings on the wall, and a candle that refuses to burn down."
		fallback_quote = "A weapon is an oath you can carry badly."
	elif era_lower.find("industrial") >= 0:
		appearance = "Smoke-stained sleeves, polished counters, and a locked case that clicks before you touch it."
		fallback_quote = "Machines made fear louder. People mistook that for progress."
	elif era_lower.find("future") >= 0:
		appearance = "A matte coat with shifting seams, quiet lenses, and a display wall humming in colors nobody named yet."
		fallback_quote = "The future still wants a handle."
	return {
		"appearance": appearance,
		"temperament": "Dry, observant, locally fluent, and somehow already tired of your next question.",
		"quote": fallback_quote,
		"shopkeeper_note": "This is %s, but the eyes are still just Rick." % _rick_localized_name(country, era),
		"culture_tag": culture_tag
	}


func _weapon_shop_name_for_context(era: String, country: String) -> String:
	var normalized: String = str(country).strip_edges().to_lower()
	if normalized.find("fire nation") >= 0:
		return "Rick's Ember Arsenal"
	if normalized.find("water tribe") >= 0 or normalized.find("southern water") >= 0 or normalized.find("northern water") >= 0:
		return "Rick's Icewater Armory"
	if normalized.find("air temple") >= 0:
		return "Rick's Neutral Tools"
	if normalized.find("earth kingdom") >= 0:
		return "Rick's Stoneweight Armory"

	match str(era).strip_edges():
		"Ancient Era":
			return "Rick's Bronze Counter"
		"Medieval Era":
			return "Rick's Oath & Iron"
		"Industrial Era":
			return "Rick's Powder & Steel"
		"Modern Era":
			return "Rick's Quiet Counter"
		"Future Era":
			return "Rick's Quantum Arsenal"
		_:
			return "Rick's Weapon Counter"


func _weapon_shop_currency_for_era(era: String) -> String:
	match str(era).strip_edges():
		"Ancient Era":
			return "coins"
		"Medieval Era":
			return "coins"
		"Industrial Era":
			return "cash"
		"Modern Era":
			return "cash"
		"Future Era":
			return "credits"
		_:
			return "coins"


func _rick_player_recognition(actor: Person, country: String, era: String) -> Dictionary:
	if actor == null:
		return {
			"line": ""
		}

	var family_name: String = str(actor.last_name).strip_edges() if "last_name" in actor else ""

	return {
		"actor_id": int(actor.id),
		"actor_name": _person_name(actor),
		"family_name": family_name,
		"country": country,
		"era": era,
		"line": "Rick glances at you. \"I knew that name once. Might have been you. Might have been your bloodline. Reality gets lazy with faces.\""
	}

func _rick_memory_echoes(actor: Person, country: String, era: String) -> Array:
	var echoes: Array = []
	if actor == null:
		echoes.append("Rick remembers a shadow shaped like the player, but not the name yet.")
		return echoes
	var actor_name: String = _person_name(actor)
	echoes.append("Rick remembers %s entering a weapon shop somewhere that may not have happened yet." % actor_name)
	echoes.append("Rick remembers the same hand reaching for different weapons across different eras.")
	var family_name: String = str(actor.last_name).strip_edges() if "last_name" in actor else ""
	if family_name != "":
		echoes.append("Rick has seen the %s name before, though he refuses to say in which reality." % family_name)
	echoes.append("Current manifestation: %s in %s during the %s." % [_rick_localized_name(country, era), country, era])
	return echoes


func _person_name(person: Person) -> String:
	if person == null:
		return "Someone"
	var direct_name: String = str(person.name).strip_edges() if "name" in person else ""
	if direct_name != "":
		return direct_name
	var first_name: String = str(person.first_name).strip_edges() if "first_name" in person else ""
	var last_name: String = str(person.last_name).strip_edges() if "last_name" in person else ""
	var full_name: String = ("%s %s" % [first_name, last_name]).strip_edges()
	if full_name != "":
		return full_name
	return "Someone"
func instantiate_contract(contract: Dictionary, _context: Dictionary = {}) -> Dictionary:
	if typeof(contract) != TYPE_DICTIONARY or contract.is_empty():
		return { "success": false, "reason": "Runtime contract is empty."}

	var clean_contract: Dictionary = _normalize_runtime_contract(contract)
	var contract_id: String = str(clean_contract.get("contract_id", "")).strip_edges()
	if contract_id == "":
		contract_id = _make_contract_id(clean_contract)
		clean_contract ["contract_id"] = contract_id

	var runtime_key: String = _runtime_key_for_contract(clean_contract)
	var existing_id: String = str(runtime_contract_index.get(runtime_key, "")).strip_edges()
	if existing_id != "" and active_runtime_contracts.has(existing_id):
		var existing: Dictionary = _safe_dictionary(active_runtime_contracts.get(existing_id, {}))
		var merged: Dictionary = _merge_contract_refresh(existing, clean_contract)
		active_runtime_contracts [existing_id] = merged
		_sync_contract_into_world(merged)

		return {
			"success": true,
			"mode": "runtime_contract_refreshed",
			"contract_id": existing_id,
			"runtime_key": runtime_key
		}

	active_runtime_contracts [contract_id] = clean_contract
	runtime_contract_index [runtime_key] = contract_id
	_sync_contract_into_world(clean_contract)

	return {
		"success": true,
		"mode": "runtime_contract_instantiated",
		"contract_id": contract_id,
		"runtime_key": runtime_key
	}


func observe_runtime_contracts(observer: Person, filters: Dictionary = {}) -> Dictionary:
	var rows: Array = []
	var observer_id: int = int(observer.id) if observer != null else -1
	var contract_type_filter: String = str(filters.get("contract_type", "")).strip_edges().to_lower()
	var space_type_filter: String = str(filters.get("space_type", "")).strip_edges().to_lower()
	var include_inactive: bool = bool(filters.get("include_inactive", false))

	for raw_id in active_runtime_contracts.keys():
		var contract_id: String = str(raw_id)
		var contract: Dictionary = _safe_dictionary(active_runtime_contracts.get(contract_id, {}))
		if contract.is_empty():
			continue

		var state: String = str(contract.get("state", "active")).strip_edges().to_lower()
		if state != "active" and not include_inactive:
			continue

		var contract_type: String = str(contract.get("contract_type", "")).strip_edges().to_lower()
		if contract_type_filter != "" and contract_type != contract_type_filter:
			continue

		var public_space: Dictionary = _safe_dictionary(contract.get("public_space", {}))
		var space_type: String = str(public_space.get("space_type", "")).strip_edges().to_lower()
		if space_type_filter != "" and space_type != space_type_filter:
			continue

		rows.append(_observation_row_for_contract(contract, observer, filters))

	runtime_contract_observations [str(observer_id)] = {
		"observer_id": observer_id,
		"filters": filters.duplicate(true),
		"contract_count": rows.size(),
		"observed_at_ms": int(Time.get_ticks_msec())
	}

	return {
		"success": true,
		"mode": "runtime_contract_observe",
		"observer_id": observer_id,
		"contracts": rows
	}


func get_contract_for_space(space_type: String, space_id: String, context: Dictionary = {}) -> Dictionary:
	var clean_type: String = str(space_type).strip_edges().to_lower()
	var clean_space: String = str(space_id).strip_edges()
	if clean_type == "" or clean_space == "":
		return {}

	var runtime_key: String = "space:%s:%s:%s" % [_current_country_key(), clean_type, clean_space]
	var contract_id: String = str(runtime_contract_index.get(runtime_key, "")).strip_edges()
	if contract_id == "":
		ensure_default_world_contracts({
			"source": str(context.get("source", "get_contract_for_space")),
			"space_type": clean_type,
			"space_id": clean_space
		})
		contract_id = str(runtime_contract_index.get(runtime_key, "")).strip_edges()

	if contract_id == "":
		return {}

	return _safe_dictionary(active_runtime_contracts.get(contract_id, {}))


func get_contracts_for_space_type(space_type: String, context: Dictionary = {}) -> Array:
	var out: Array = []
	var clean_type: String = str(space_type).strip_edges().to_lower()
	if clean_type == "":
		return out

	ensure_default_world_contracts({
		"source": str(context.get("source", "get_contracts_for_space_type")),
		"space_type": clean_type
	})

	for raw_id in active_runtime_contracts.keys():
		var contract: Dictionary = _safe_dictionary(active_runtime_contracts.get(str(raw_id), {}))
		var public_space: Dictionary = _safe_dictionary(contract.get("public_space", {}))
		if str(public_space.get("space_type", "")).strip_edges().to_lower() == clean_type:
			out.append(contract.duplicate(true))

	return out


func attach_actor_to_contract(actor: Person, contract_id: String, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return { "success": false, "reason": "No actor supplied."}

	var clean_id: String = str(contract_id).strip_edges()
	if clean_id == "":
		var space_type: String = str(context.get("space_type", "")).strip_edges()
		var space_id: String = str(context.get("space_id", "")).strip_edges()
		var contract: Dictionary = get_contract_for_space(space_type, space_id, context)
		clean_id = str(contract.get("contract_id", "")).strip_edges()

	if clean_id == "" or not active_runtime_contracts.has(clean_id):
		return { "success": false, "reason": "Runtime contract not found."}

	var contract_data: Dictionary = _safe_dictionary(active_runtime_contracts.get(clean_id, {}))
	var zone_id: String = str(context.get("zone_id", "lobby")).strip_edges().to_lower()
	if zone_id == "":
		zone_id = "lobby"

	_add_actor_to_contract_zone(contract_data, int(actor.id), zone_id)
	contract_data ["updated_at_ms"] = int(Time.get_ticks_msec())
	contract_data ["updated_year"] = _current_year()
	active_runtime_contracts [clean_id] = contract_data
	_sync_contract_into_world(contract_data)

	return {
		"success": true,
		"mode": "runtime_contract_attach_actor",
		"contract_id": clean_id,
		"actor_id": int(actor.id),
		"zone_id": zone_id,
		"contract": contract_data.duplicate(true)
	}


func detach_actor_from_contract(actor: Person, contract_id: String = "", context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return { "success": false, "reason": "No actor supplied."}

	var clean_id: String = str(contract_id).strip_edges()
	if clean_id == "":
		var space_type: String = str(context.get("space_type", "")).strip_edges()
		var space_id: String = str(context.get("space_id", "")).strip_edges()
		var contract: Dictionary = get_contract_for_space(space_type, space_id, context)
		clean_id = str(contract.get("contract_id", "")).strip_edges()

	if clean_id == "" or not active_runtime_contracts.has(clean_id):
		return { "success": true, "mode": "runtime_contract_detach_no_contract", "actor_id": int(actor.id)}

	var contract_data: Dictionary = _safe_dictionary(active_runtime_contracts.get(clean_id, {}))
	_remove_actor_from_contract_zones(contract_data, int(actor.id))
	contract_data ["updated_at_ms"] = int(Time.get_ticks_msec())
	contract_data ["updated_year"] = _current_year()
	active_runtime_contracts [clean_id] = contract_data
	_sync_contract_into_world(contract_data)

	return {
		"success": true,
		"mode": "runtime_contract_detach_actor",
		"contract_id": clean_id,
		"actor_id": int(actor.id)
	}


func mutate_contract(contract_id: String, mutation: Dictionary, context: Dictionary = {}) -> Dictionary:
	var clean_id: String = str(contract_id).strip_edges()
	if clean_id == "" or not active_runtime_contracts.has(clean_id):
		return { "success": false, "reason": "Runtime contract not found."}

	var contract_data: Dictionary = _safe_dictionary(active_runtime_contracts.get(clean_id, {}))
	var mutation_type: String = str(mutation.get("type", context.get("mutation_type", "generic"))).strip_edges().to_lower()

	match mutation_type:
		"actor_zone_changed":
			var actor_id: int = int(mutation.get("actor_id", context.get("actor_id", -1)))
			var zone_id: String = str(mutation.get("zone_id", context.get("zone_id", "lobby"))).strip_edges().to_lower()
			if actor_id > 0:
				_add_actor_to_contract_zone(contract_data, actor_id, zone_id)
		"actor_detached":
			var detach_id: int = int(mutation.get("actor_id", context.get("actor_id", -1)))
			if detach_id > 0:
				_remove_actor_from_contract_zones(contract_data, detach_id)
		"friction_resolved":
			var resolved: Array = _safe_array(contract_data.get("resolved_friction_events", []))
			resolved.append(_safe_dictionary(mutation.get("event", {})))
			contract_data ["resolved_friction_events"] = resolved
		_:
			var patches: Dictionary = _safe_dictionary(mutation.get("patch", {}))
			contract_data = _merge_dictionaries(contract_data, patches)

	contract_data ["updated_at_ms"] = int(Time.get_ticks_msec())
	contract_data ["updated_year"] = _current_year()
	active_runtime_contracts [clean_id] = contract_data

	runtime_contract_mutation_log.append({
		"contract_id": clean_id,
		"mutation": mutation.duplicate(true),
		"context": context.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec())
	})
	if runtime_contract_mutation_log.size() > 200:
		runtime_contract_mutation_log = runtime_contract_mutation_log.slice(runtime_contract_mutation_log.size() - 200, runtime_contract_mutation_log.size())

	_sync_contract_into_world(contract_data)

	return {
		"success": true,
		"mode": "runtime_contract_mutated",
		"contract_id": clean_id,
		"mutation_type": mutation_type,
		"contract": contract_data.duplicate(true)
	}


func lifecycle_tick(context: Dictionary = {}) -> Dictionary:
	var advanced: int = 0
	var expired: Array = []

	for raw_id in active_runtime_contracts.keys():
		var contract_id: String = str(raw_id)
		var contract_data: Dictionary = _safe_dictionary(active_runtime_contracts.get(contract_id, {}))
		if contract_data.is_empty():
			continue

		var state: String = str(contract_data.get("state", "active")).strip_edges().to_lower()
		if state not in ["active", "paused"]:
			continue

		var lifecycle: Dictionary = _safe_dictionary(contract_data.get("lifecycle", {}))
		var tick_count: int = int(lifecycle.get("tick_count", 0)) + 1
		lifecycle ["tick_count"] = tick_count
		lifecycle ["last_tick_ms"] = int(Time.get_ticks_msec())

		var lifecycle_contract_type: String = str(contract_data.get("contract_type", "")).strip_edges().to_lower()
		if lifecycle_contract_type == "movie_theater_session":
			_update_movie_theater_lifecycle(contract_data, lifecycle, context)
		elif lifecycle_contract_type == "school_session":
			_update_school_session_lifecycle(contract_data, lifecycle, context)

		contract_data ["lifecycle"] = lifecycle
		contract_data ["updated_at_ms"] = int(Time.get_ticks_msec())
		contract_data ["updated_year"] = _current_year()

		if bool(contract_data.get("expires_when_empty", false)) and _contract_population(contract_data) <= 0:
			contract_data ["state"] = "expired"
			expired.append(contract_id)

		active_runtime_contracts [contract_id] = contract_data
		_sync_contract_into_world(contract_data)
		advanced += 1

	return {
		"success": true,
		"mode": "runtime_contract_lifecycle_tick",
		"advanced_count": advanced,
		"expired_contracts": expired
	}
func emit_school_session_contracts_for_current_world(context: Dictionary = {}) -> Dictionary:
	var era_name: String = _current_era_name()
	var country: String = _current_country()
	var city: String = _current_city()
	var catalog: Array = _school_runtime_catalog_for_current_world(context)
	var emitted_contracts: Array = []

	for raw_school in catalog:
		var school: Dictionary = _safe_dictionary(raw_school)
		if school.is_empty():
			continue

		var contract: Dictionary = _build_school_session_runtime_contract(school, context)
		var report: Dictionary = instantiate_contract(contract, {
			"source": str(context.get("source", "emit_school_session_contracts_for_current_world")),
		})

		if bool(report.get("success", false)):
			emitted_contracts.append(str(report.get("contract_id", "")))

	return {
		"success": true,
		"mode": "runtime_contract_emit_school_sessions",
		"era": era_name,
		"country": country,
		"city": city,
		"emitted_count": emitted_contracts.size(),
		"contract_ids": emitted_contracts
	}


func _school_runtime_catalog_for_current_world(context: Dictionary = {}) -> Array:
	if gs != null and gs.school_engine != null and gs.school_engine.has_method("get_runtime_school_session_catalog"):
		var provided: Variant = gs.school_engine.get_runtime_school_session_catalog({
			"source": str(context.get("source", "runtime_contract_engine")),
			"era": _current_era_name(),
			"country": _current_country(),
			"city": _current_city()
		})
		if typeof(provided) == TYPE_ARRAY:
			return _safe_array(provided)

	var era_name: String = _current_era_name()
	match era_name:
		"Ancient Era":
			return [
				{ "id": "temple_tutoring", "name": "Temple Tutoring", "institution_type": "temple_tutoring", "meal_surface_label": "Communal Meal Courtyard"},
				{ "id": "royal_academy", "name": "Royal Academy", "institution_type": "royal_academy", "meal_surface_label": "Academy Courtyard"},
				{ "id": "scribe_school", "name": "Scribe School", "institution_type": "scribe_school", "meal_surface_label": "Tablet Courtyard"},
				{ "id": "warrior_training_yard", "name": "Warrior Training Yard", "institution_type": "warrior_training_yard", "meal_surface_label": "Training Yard Meal Break"}
			]
		"Medieval Era":
			return [
				{ "id": "monastery_education", "name": "Monastery Education", "institution_type": "monastery_education", "meal_surface_label": "Hall Meal Break"},
				{ "id": "guild_apprenticeship", "name": "Guild Apprenticeship", "institution_type": "apprenticeship_hall", "meal_surface_label": "Guild Meal Bench"},
				{ "id": "court_education", "name": "Court Education", "institution_type": "royal_academy", "meal_surface_label": "Court Hall Meal"},
				{ "id": "knight_hall", "name": "Knight Hall", "institution_type": "warrior_training_yard", "meal_surface_label": "Training Hall Meal"}
			]
		"Industrial Era":
			return [
				{ "id": "public_school", "name": "Public School", "institution_type": "industrial_school", "meal_surface_label": "Lunchroom"},
				{ "id": "factory_school", "name": "Factory School", "institution_type": "factory_school", "meal_surface_label": "Factory Meal Break"},
				{ "id": "church_school", "name": "Church School", "institution_type": "church_school", "meal_surface_label": "Church Hall Lunch"},
				{ "id": "boarding_school", "name": "Boarding School", "institution_type": "boarding_school", "meal_surface_label": "Dining Hall"}
			]
		"Modern Era":
			return [
				{ "id": "public_school", "name": "Public School", "institution_type": "modern_school", "meal_surface_label": "Lunchroom"},
				{ "id": "private_school", "name": "Private School", "institution_type": "private_school", "meal_surface_label": "Dining Commons"},
				{ "id": "military_school", "name": "Military School", "institution_type": "military_school", "meal_surface_label": "Cadet Mess Hall"},
				{ "id": "boarding_school", "name": "Boarding School", "institution_type": "boarding_school", "meal_surface_label": "Boarding Hall"}
			]
		"Future Era":
			return [
				{ "id": "learning_pod", "name": "Learning Pod", "institution_type": "learning_pod", "meal_surface_label": "Nutrient Commons"},
				{ "id": "ai_academy", "name": "AI Academy", "institution_type": "ai_academy", "meal_surface_label": "Nutrient Commons"},
				{ "id": "simulation_school", "name": "Simulation School", "institution_type": "simulation_school", "meal_surface_label": "Simulation Break Deck"},
				{ "id": "orbital_academy", "name": "Orbital Academy", "institution_type": "orbital_academy", "meal_surface_label": "Orbital Commons"}
			]

	return [
		{ "id": "local_school", "name": "Local School", "institution_type": "local_school", "meal_surface_label": "Meal Break"}
	]


func _build_school_session_runtime_contract(school: Dictionary, _context: Dictionary = {}) -> Dictionary:
	var era_name: String = _current_era_name()
	var country: String = _current_country()
	var city: String = _current_city()
	var school_id: String = str(school.get("id", school.get("name", "school"))).strip_edges().to_lower().replace(" ", "_")
	var school_name: String = str(school.get("name", "School")).strip_edges()
	var runtime_key: String = "space:%s:school:%s" % [_current_country_key(), school_id]
	var contract_id: String = "rtc_school_%s_%s_%s" % [_current_country_key(), school_id, str(_current_year())]

	var rng:= RandomNumberGenerator.new()
	rng.seed = _stable_seed("runtime_school_session|%s|%s|%s|%s|%s" % [
		country,
		city,
		era_name,
		school_id,
		str(_current_year())
	])

	var zones: Dictionary = _build_school_session_zone_contract(school, rng)
	var friction: Array = _seed_school_session_friction(school, rng)

	return {
		"schema": SCHOOL_SESSION_CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"contract_id": contract_id,
		"contract_type": "school_session",
		"runtime_key": runtime_key,
		"state": "active",
		"created_year": _current_year(),
		"updated_year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec()),
		"updated_at_ms": int(Time.get_ticks_msec()),
		"time_model": {
			"explanation": "A school session exists as world reality before the player opens the School Hub."
		},
		"location": {
			"space_type": "school",
			"space_id": school_id,
			"name": school_name,
			"city": city,
			"country": country,
			"era": era_name
		},
		"public_space": {
			"space_type": "school",
			"space_id": school_id,
			"session_key": "school:%s" % school_id,
			"zone_ids": ["entrance", "classrooms", "meal_space", "hallway", "yard"]
		},
		"school_runtime_state": {
			"school_id": school_id,
			"school_name": school_name,
			"institution_type": str(school.get("institution_type", "school")),
			"meal_surface_label": str(school.get("meal_surface_label", "Meal Break")),
			"phase": _pick_school_lifecycle_phase(rng),
			"last_live_line": _school_session_live_line(school, rng)
		},
		"population": _population_from_zones(zones),
		"zones": zones,
		"active_friction_events": friction,
		"resolved_friction_events": [],
		"lifecycle": {
			"phase": _pick_school_lifecycle_phase(rng),
			"tick_count": 0,
			"last_tick_ms": int(Time.get_ticks_msec())
		},
		"systems": {
			"public_space": "shared_public_space_engine",
			"specialization": "school_engine",
			"runtime": "runtime_contract_engine",
			"consequence": "scenario_engine",
			"relationship": "relationship_engine",
			"reputation": "dynasty_legacy_engine"
		},
		"contract_mesh": {
			"tags": ["school", "education", "public_space", "social_friction", "observable_reality", "runtime_session"],
			"can_interact_with": ["relationships", "family", "jobs", "fame", "crime", "bending", "college", "scholarships"],
		}
	}


func _build_school_session_zone_contract(_school: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var era_name: String = _current_era_name()
	var base_min: int = 10
	var base_max: int = 34

	if era_name in ["Ancient Era", "Medieval Era"]:
		base_min = 6
		base_max = 18
	elif era_name == "Future Era":
		base_min = 8
		base_max = 26

	var total: int = int(rng.randi_range(base_min, base_max))
	var entrance_count: int = int(round(float(total) * rng.randf_range(0.06, 0.14)))
	var meal_count: int = int(round(float(total) * rng.randf_range(0.1, 0.28)))
	var hallway_count: int = int(round(float(total) * rng.randf_range(0.12, 0.24)))
	var yard_count: int = int(round(float(total) * rng.randf_range(0.04, 0.18)))
	var classroom_count: int = max(0, total - entrance_count - meal_count - hallway_count - yard_count)

	return {
		"entrance": _school_runtime_zone_contract("entrance", entrance_count, rng, "arriving at school"),
		"classrooms": _school_runtime_zone_contract("classrooms", classroom_count, rng, "sitting through lessons"),
		"meal_space": _school_runtime_zone_contract("meal_space", meal_count, rng, "taking a meal break"),
		"hallway": _school_runtime_zone_contract("hallway", hallway_count, rng, "moving between lessons"),
		"yard": _school_runtime_zone_contract("yard", yard_count, rng, "waiting outside class")
	}


func _school_runtime_zone_contract(zone_id: String, count: int, rng: RandomNumberGenerator, behavior: String) -> Dictionary:
	var ambient: Array = []
	for i in range(max(0, count)):
		ambient.append(_school_runtime_ambient_person(zone_id, i, rng, behavior))

	return {
		"zone_id": zone_id,
		"ambient_people": ambient,
		"actor_ids": [],
		"tension": rng.randf_range(0.05, 0.82)
	}


func _school_runtime_ambient_person(zone_id: String, index: int, rng: RandomNumberGenerator, behavior: String) -> Dictionary:
	var first_names: Array = ["Avery", "Jordan", "Maya", "Chris", "Taylor", "Sam", "Riley", "Morgan", "Imani", "Devon", "Andre", "Nia", "Kai", "Noelle", "Jalen", "Maya", "Theo", "Amara"]
	var last_names: Array = ["Cross", "Chen", "Vale", "Stone", "Rivera", "Okafor", "Bennett", "Hale", "Brooks", "Khan", "Bell", "Ashford"]
	var first_name: String = str(first_names [int(rng.randi_range(0, first_names.size() - 1))])
	var last_name: String = str(last_names [int(rng.randi_range(0, last_names.size() - 1))])

	return {
		"ambient_id": "school_%s_%d_%d" % [zone_id, index, int(rng.randi_range(1000, 9999))],
		"first_name": first_name,
		"last_name": last_name,
		"full_name": "%s %s" % [first_name, last_name],
		"age": int(rng.randi_range(6, 22)),
		"zone_id": zone_id,
		"description": behavior,
		"confidence": rng.randf_range(0.1, 0.95),
		"irritability": rng.randf_range(0.05, 0.9),
		"kindness": rng.randf_range(0.05, 0.95)
	}


func _seed_school_session_friction(school: Dictionary, rng: RandomNumberGenerator) -> Array:
	var school_name: String = str(school.get("name", "school"))
	var meal_label: String = str(school.get("meal_surface_label", "meal break"))
	var pool: Array = [
		{
			"type": "meal_embarrassment",
			"title": "Meal Break Embarrassment",
			"description": "Someone becomes the center of attention during %s at %s." % [meal_label, school_name],
			"intensity": rng.randf_range(0.25, 0.76),
			"zone_id": "meal_space",
			"participants": [],
			"state": "active"
		},
		{
			"type": "hallway_rumor",
			"title": "Hallway Rumor",
			"description": "A rumor moves through the school faster than the teachers can track.",
			"intensity": rng.randf_range(0.2, 0.72),
			"zone_id": "hallway",
			"participants": [],
			"state": "active"
		},
		{
			"type": "teacher_attention",
			"title": "Teacher Attention",
			"description": "A teacher notices one student for better or worse.",
			"intensity": rng.randf_range(0.18, 0.58),
			"zone_id": "classrooms",
			"participants": [],
			"state": "active"
		}
	]

	var picked: Dictionary = pool [int(rng.randi_range(0, pool.size() - 1))].duplicate(true)
	picked ["event_id"] = "rtc_school_friction_%s_%d" % [str(picked.get("type", "event")), int(rng.randi_range(10000, 99999))]
	return [picked]


func _pick_school_lifecycle_phase(rng: RandomNumberGenerator) -> String:
	var roll: float = rng.randf()
	if roll < 0.18:
		return "arrival"
	if roll < 0.58:
		return "in_class"
	if roll < 0.78:
		return "meal_break"
	if roll < 0.92:
		return "between_classes"
	return "dismissal"


func _school_session_live_line(school: Dictionary, rng: RandomNumberGenerator) -> String:
	var school_name: String = str(school.get("name", "school"))
	var meal_label: String = str(school.get("meal_surface_label", "meal break"))
	var lines: Array = [
		"%s is already in motion before the player sees it." % school_name,
		"Students are moving between lessons at %s." % school_name,
		"The %s has its own social weather today." % meal_label,
		"Teachers are tracking more than attendance at %s." % school_name
	]
	return str(lines [int(rng.randi_range(0, lines.size() - 1))])


func _update_school_session_lifecycle(contract_data: Dictionary, lifecycle: Dictionary, _context: Dictionary = {}) -> void:
	var phase: String = str(lifecycle.get("phase", "arrival")).strip_edges().to_lower()
	var tick_count: int = int(lifecycle.get("tick_count", 0))

	if tick_count % 3 == 0:
		match phase:
			"arrival":
				lifecycle ["phase"] = "in_class"
			"in_class":
				lifecycle ["phase"] = "meal_break"
			"meal_break":
				lifecycle ["phase"] = "between_classes"
			"between_classes":
				lifecycle ["phase"] = "dismissal"
			"dismissal":
				lifecycle ["phase"] = "arrival"
			_:
				lifecycle ["phase"] = "in_class"

	var runtime_state: Dictionary = _safe_dictionary(contract_data.get("school_runtime_state", {}))
	runtime_state ["phase"] = str(lifecycle.get("phase", "in_class"))
	runtime_state ["last_live_line"] = "The school session shifted into %s." % str(runtime_state.get("phase", "in_class")).replace("_", " ")
	contract_data ["school_runtime_state"] = runtime_state

	var active: Array = _safe_array(contract_data.get("active_friction_events", []))
	if active.is_empty() and str(lifecycle.get("phase", "")) in ["meal_break", "between_classes"]:
		var school_stub: Dictionary = _safe_dictionary(contract_data.get("location", {}))
		school_stub ["meal_surface_label"] = str(runtime_state.get("meal_surface_label", "meal break"))
		var rng:= RandomNumberGenerator.new()
		rng.seed = _stable_seed("runtime_school_lifecycle|%s|%s|%s" % [
			str(contract_data.get("contract_id", "")),
			str(tick_count),
			str(_current_year())
		])
		contract_data ["active_friction_events"] = _seed_school_session_friction(school_stub, rng)


func _build_movie_theater_runtime_contract(theater: Dictionary, _context: Dictionary = {}) -> Dictionary:
	var theater_id: String = str(theater.get("id", "")).strip_edges()
	var country: String = _current_country()
	var city: String = _current_city()
	var era_name: String = _current_era_name()
	var runtime_key: String = "space:%s:movie_theater:%s" % [_current_country_key(), theater_id]

	var rng:= RandomNumberGenerator.new()
	rng.seed = _stable_seed("runtime_movie_theater|%s|%s|%s|%s" % [country, city, era_name, theater_id])

	var movie: Dictionary = _pick_movie_for_theater(theater_id, rng)
	var zones: Dictionary = _build_movie_theater_zone_contract(theater, rng)
	var active_friction: Array = _seed_movie_theater_friction(movie, rng)

	var contract_id: String = "rtc_movie_%s_%s_%s" % [_current_country_key(), theater_id, str(_current_year())]

	return {
		"schema": MOVIE_THEATER_CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"contract_id": contract_id,
		"contract_type": "movie_theater_session",
		"runtime_key": runtime_key,
		"state": "active",
		"created_year": _current_year(),
		"updated_year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec()),
		"updated_at_ms": int(Time.get_ticks_msec()),
		"time_model": {
			"explanation": "The contract lifecycle can move without advancing the global year."
		},
		"location": {
			"space_type": "movie_theater",
			"space_id": theater_id,
			"name": str(theater.get("name", theater_id)),
			"city": city,
			"country": country,
			"era": era_name
		},
		"public_space": {
			"space_type": "movie_theater",
			"space_id": theater_id,
			"session_key": "movie_theater:%s" % theater_id,
			"zone_ids": ["lobby", "line", "concessions", "auditorium", "exit"]
		},
		"commerce": {
			"ticket_price": float(theater.get("ticket_price", 12.0)),
			"currency": "USD",
		},
		"movie": movie,
		"population": _population_from_zones(zones),
		"zones": zones,
		"active_friction_events": active_friction,
		"resolved_friction_events": [],
		"lifecycle": {
			"phase": _pick_lifecycle_phase(rng),
			"tick_count": 0,
			"last_tick_ms": int(Time.get_ticks_msec())
		},
		"systems": {
			"public_space": "shared_public_space_engine",
			"specialization": "movie_theater_engine",
			"consequence": "upce_engine",
			"reputation": "reputation_engine",
			"crime": "crime_engine",
			"relationship": "relationship_engine"
		},
		"country_profile": _country_profile(country, era_name),
		"contract_mesh": {
			"tags": ["public_space", "entertainment", "commerce", "social_friction", "observable_reality"],
			"can_interact_with": ["crime", "relationships", "jobs", "fame", "powers"],
		}
	}


func _build_movie_theater_zone_contract(theater: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var min_population: int = int(theater.get("min_population", 12))
	var max_population: int = int(theater.get("max_population", 30))
	if max_population < min_population:
		max_population = min_population

	var total: int = int(rng.randi_range(min_population, max_population))
	var lobby_count: int = int(round(float(total) * rng.randf_range(0.18, 0.34)))
	var line_count: int = int(round(float(total) * rng.randf_range(0.08, 0.2)))
	var concessions_count: int = int(round(float(total) * rng.randf_range(0.06, 0.18)))
	var auditorium_count: int = max(0, total - lobby_count - line_count - concessions_count)

	return {
		"lobby": _zone_contract("lobby", lobby_count, rng, "waiting in the lobby"),
		"line": _zone_contract("line", line_count, rng, "standing in the ticket line"),
		"concessions": _zone_contract("concessions", concessions_count, rng, "buying snacks"),
		"auditorium": _zone_contract("auditorium", auditorium_count, rng, "watching the movie"),
		"exit": _zone_contract("exit", 0, rng, "leaving the theater")
	}


func _zone_contract(zone_id: String, count: int, rng: RandomNumberGenerator, behavior: String) -> Dictionary:
	var ambient: Array = []
	for i in range(max(0, count)):
		ambient.append(_ambient_runtime_person(zone_id, i, rng, behavior))

	return {
		"zone_id": zone_id,
		"ambient_people": ambient,
		"actor_ids": [],
		"tension": rng.randf_range(0.05, 0.75)
	}


func _ambient_runtime_person(zone_id: String, index: int, rng: RandomNumberGenerator, behavior: String) -> Dictionary:
	var first_names: Array = ["Avery", "Jordan", "Maya", "Chris", "Taylor", "Sam", "Riley", "Morgan", "Imani", "Devon", "Andre", "Nia", "Kai", "Noelle"]
	var name: String = str(first_names [int(rng.randi_range(0, first_names.size() - 1))])
	return {
		"ambient_id": "rtc_%s_%d_%d" % [zone_id, index, int(rng.randi_range(1000, 9999))],
		"name": name,
		"description": behavior,
		"patience": rng.randf_range(0.15, 0.95),
		"boldness": rng.randf_range(0.1, 0.95),
		"irritability": rng.randf_range(0.05, 0.9)
	}


func _seed_movie_theater_friction(movie: Dictionary, rng: RandomNumberGenerator) -> Array:
	var genre: String = str(movie.get("genre", "Drama")).strip_edges().to_lower()
	var pool: Array = [
		{
			"type": "phone_brightness",
			"title": "Phone Brightness 100%",
			"description": "Someone nearby has their phone brightness blasting through the dark theater.",
			"intensity": rng.randf_range(0.35, 0.78),
			"zone_id": "auditorium",
			"participants": [],
			"state": "active"
		},
		{
			"type": "couple_arguing",
			"title": "Couple Arguing Next To You",
			"description": "A couple is already whisper-fighting before you even sit down.",
			"intensity": rng.randf_range(0.25, 0.66),
			"zone_id": "auditorium",
			"participants": [],
			"state": "active"
		},
		{
			"type": "tall_person_front",
			"title": "Someone Tall Sits In Front Of A Row",
			"description": "Someone tall is blocking part of the screen and a row is getting irritated.",
			"intensity": rng.randf_range(0.2, 0.58),
			"zone_id": "auditorium",
			"participants": [],
			"state": "active"
		}
	]

	if genre == "horror":
		pool.append({
			"type": "horror_scream_chain",
			"title": "Premature Scream Chain",
			"description": "People are already screaming before the scary part happens.",
			"intensity": rng.randf_range(0.45, 0.86),
			"zone_id": "auditorium",
			"participants": [],
			"state": "active"
		})
	elif genre == "romance":
		pool.append({
			"type": "romance_couple_kissing",
			"title": "Couple Kissing Loudly",
			"description": "A couple is turning the romance movie into audience participation.",
			"intensity": rng.randf_range(0.3, 0.7),
			"zone_id": "auditorium",
			"participants": [],
			"state": "active"
		})
	elif genre == "action":
		pool.append({
			"type": "action_hype_crowd",
			"title": "Hype Crowd",
			"description": "A group keeps clapping and yelling at every punch.",
			"intensity": rng.randf_range(0.4, 0.82),
			"zone_id": "auditorium",
			"participants": [],
			"state": "active"
		})

	var picked: Dictionary = pool [int(rng.randi_range(0, pool.size() - 1))].duplicate(true)
	picked ["event_id"] = "rtc_friction_%s_%d" % [str(picked.get("type", "event")), int(rng.randi_range(10000, 99999))]
	return [picked]


func _pick_movie_for_theater(theater_id: String, rng: RandomNumberGenerator) -> Dictionary:
	var movies: Array = []
	if gs != null and gs.movie_theater_engine != null and gs.movie_theater_engine.has_method("_movies_for_theater"):
		movies = gs.movie_theater_engine._movies_for_theater(theater_id)

	if movies.is_empty():
		movies = [
			{ "id": "night_house_iii", "title": "Night House III", "genre": "Horror", "description": "A haunted-house sequel."},
			{ "id": "love_after_laundry", "title": "Love After Laundry", "genre": "Romance", "description": "A soft romance movie."},
			{ "id": "hyperlane_riot", "title": "Hyperlane Riot", "genre": "Action", "description": "A loud action movie."}
		]

	var picked: Dictionary = movies [int(rng.randi_range(0, movies.size() - 1))] as Dictionary
	return picked.duplicate(true)


func _pick_lifecycle_phase(rng: RandomNumberGenerator) -> String:
	var roll: float = rng.randf()
	if roll < 0.22:
		return "pre_show"
	if roll < 0.74:
		return "mid_session"
	if roll < 0.92:
		return "final_act"
	return "intermission"


func _update_movie_theater_lifecycle(contract_data: Dictionary, lifecycle: Dictionary, _context: Dictionary = {}) -> void:
	var phase: String = str(lifecycle.get("phase", "pre_show")).strip_edges().to_lower()
	var tick_count: int = int(lifecycle.get("tick_count", 0))

	if tick_count % 4 == 0:
		match phase:
			"pre_show":
				lifecycle ["phase"] = "mid_session"
			"mid_session":
				lifecycle ["phase"] = "final_act"
			"final_act":
				lifecycle ["phase"] = "credits"
			"credits":
				lifecycle ["phase"] = "resetting"
			"resetting":
				lifecycle ["phase"] = "pre_show"
			_:
				lifecycle ["phase"] = "mid_session"

		var zones: Dictionary = _safe_dictionary(contract_data.get("zones", {}))
		if zones.has("auditorium") and lifecycle ["phase"] in ["mid_session", "final_act"]:
			var active: Array = _safe_array(contract_data.get("active_friction_events", []))
			if active.is_empty():
				active = _seed_movie_theater_friction(_safe_dictionary(contract_data.get("movie", {})), RandomNumberGenerator.new())
			contract_data ["active_friction_events"] = active


func _normalize_runtime_contract(contract: Dictionary) -> Dictionary:
	var out: Dictionary = contract.duplicate(true)
	if str(out.get("schema", "")).strip_edges() == "":
		out ["schema"] = RUNTIME_CONTRACT_SCHEMA
	out ["version"] = int(out.get("version", CONTRACT_VERSION))
	if str(out.get("state", "")).strip_edges() == "":
		out ["state"] = "active"
	if str(out.get("contract_type", "")).strip_edges() == "":
		out ["contract_type"] = str(out.get("type", "runtime_contract")).strip_edges().to_lower()
	if str(out.get("runtime_key", "")).strip_edges() == "":
		out ["runtime_key"] = _runtime_key_for_contract(out)
	return _make_binary_safe(out)


func _merge_contract_refresh(existing: Dictionary, incoming: Dictionary) -> Dictionary:
	var out: Dictionary = existing.duplicate(true)
	out ["updated_year"] = _current_year()
	out ["updated_at_ms"] = int(Time.get_ticks_msec())

	for key in ["schema", "version", "contract_type", "runtime_key", "location", "public_space", "commerce", "systems", "country_profile", "contract_mesh", "culture", "reality_layer", "identity_contract", "behavior_contract", "history_contract", "ui_contract", "vendor", "rick_flavor", "player_recognition", "inventory", "weapon_shop_contract", "memory_echoes", "shop_runtime_state"]:
		if incoming.has(key):
			out [key] = _make_binary_safe(incoming.get(key))

	if not out.has("cultural_state") or _safe_dictionary(out.get("cultural_state", {})).is_empty():
		out ["cultural_state"] = _safe_dictionary(incoming.get("cultural_state", {}))
	if not out.has("history_log") or _safe_array(out.get("history_log", [])).is_empty():
		out ["history_log"] = _safe_array(incoming.get("history_log", []))
	if not out.has("zones") or _safe_dictionary(out.get("zones", {})).is_empty():
		out ["zones"] = _safe_dictionary(incoming.get("zones", {}))
	if not out.has("movie") or _safe_dictionary(out.get("movie", {})).is_empty():
		out ["movie"] = _safe_dictionary(incoming.get("movie", {}))
	if _safe_array(out.get("active_friction_events", [])).is_empty():
		out ["active_friction_events"] = _safe_array(incoming.get("active_friction_events", []))
	if not out.has("transaction_log") or _safe_array(out.get("transaction_log", [])).is_empty():
		out ["transaction_log"] = _safe_array(incoming.get("transaction_log", []))

	return out
func _sync_contract_into_world(contract: Dictionary) -> void:
	if contract.is_empty() or gs == null:
		return

	if gs.shared_public_space_engine != null and gs.shared_public_space_engine.has_method("import_runtime_contract"):
		gs.shared_public_space_engine.import_runtime_contract(contract)


func _runtime_key_for_contract(contract: Dictionary) -> String:
	var explicit: String = str(contract.get("runtime_key", "")).strip_edges()
	if explicit != "":
		return explicit

	var public_space: Dictionary = _safe_dictionary(contract.get("public_space", {}))
	var space_type: String = str(public_space.get("space_type", "")).strip_edges().to_lower()
	var space_id: String = str(public_space.get("space_id", "")).strip_edges()
	if space_type != "" and space_id != "":
		return "space:%s:%s:%s" % [_current_country_key(), space_type, space_id]

	return "contract:%s:%s" % [str(contract.get("contract_type", "runtime")), str(contract.get("contract_id", ""))]


func _make_contract_id(contract: Dictionary) -> String:
	var material: String = "%s|%s|%s|%s" % [
		str(contract.get("contract_type", "runtime")),
		_runtime_key_for_contract(contract),
		str(_current_year()),
		str(Time.get_ticks_msec())
	]
	return "rtc_%d" % _stable_seed(material)


func _rebuild_contract_index() -> void:
	runtime_contract_index.clear()
	for raw_id in active_runtime_contracts.keys():
		var contract_id: String = str(raw_id)
		var contract: Dictionary = _safe_dictionary(active_runtime_contracts.get(contract_id, {}))
		var runtime_key: String = _runtime_key_for_contract(contract)
		if runtime_key != "":
			runtime_contract_index [runtime_key] = contract_id


func _observation_row_for_contract(contract: Dictionary, _observer: Person, _filters: Dictionary = {}) -> Dictionary:
	var contract_type: String = str(contract.get("contract_type", "")).strip_edges().to_lower()
	if contract_type == "cultural_reality":
		var culture: Dictionary = _safe_dictionary(contract.get("culture", {}))
		var cultural_state: Dictionary = _safe_dictionary(contract.get("cultural_state", {}))
		var reality_layer: Dictionary = _safe_dictionary(contract.get("reality_layer", {}))
		return {
			"contract_id": str(contract.get("contract_id", "")),
			"contract_type": str(contract.get("contract_type", "")),
			"state": str(contract.get("state", "active")),
			"space_type": "culture",
			"space_id": str(culture.get("id", "")),
			"title": str(culture.get("display_name", "Cultural Reality")),
			"subtitle": "%s • %s • Drift %s" % [
				str(reality_layer.get("era", _current_era_name())),
				str(culture.get("power_structure", "civic state")),
				str(cultural_state.get("drift_index", 0))
			],
			"population": 0,
			"zone_counts": {},
			"active_friction_events": [],
			"culture_values": _safe_array(culture.get("values", [])),
			"cultural_state": cultural_state.duplicate(true),
			"last_history_entry": str(cultural_state.get("last_history_entry", "")),
			"history_log": _safe_array(contract.get("history_log", []))
		}
	if contract_type == "weapon_shop":
		var weapon_location: Dictionary = _safe_dictionary(contract.get("location", {}))
		var vendor: Dictionary = _safe_dictionary(contract.get("vendor", {}))
		var flavor: Dictionary = _safe_dictionary(contract.get("rick_flavor", {}))
		return {
			"contract_id": str(contract.get("contract_id", "")),
			"contract_type": str(contract.get("contract_type", "")),
			"state": str(contract.get("state", "active")),
			"space_type": "weapon_shop",
			"space_id": str(_safe_dictionary(contract.get("public_space", {})).get("space_id", "rick_weapon_shop")),
			"title": str(weapon_location.get("name", "Rick's Weapon Counter")),
			"subtitle": "%s • %s • %s" % [
				str(vendor.get("display_name", "Rick")),
				str(weapon_location.get("era", _current_era_name())),
				str(flavor.get("quote", "Everything has an edge."))
			],
			"population": 1,
			"zone_counts": { "counter": 1},
			"active_friction_events": [],
			"vendor": vendor.duplicate(true),
			"rick_flavor": flavor.duplicate(true),
			"inventory": _safe_array(contract.get("inventory", [])),
			"player_recognition": _safe_dictionary(contract.get("player_recognition", {})),
			"memory_echoes": _safe_array(contract.get("memory_echoes", []))
		}
	var public_space: Dictionary = _safe_dictionary(contract.get("public_space", {}))
	var movie: Dictionary = _safe_dictionary(contract.get("movie", {}))
	var lifecycle: Dictionary = _safe_dictionary(contract.get("lifecycle", {}))
	var zones: Dictionary = _safe_dictionary(contract.get("zones", {}))
	return {
		"contract_id": str(contract.get("contract_id", "")),
		"contract_type": str(contract.get("contract_type", "")),
		"state": str(contract.get("state", "active")),
		"space_type": str(public_space.get("space_type", "")),
		"space_id": str(public_space.get("space_id", "")),
		"title": str(_safe_dictionary(contract.get("location", {})).get("name", contract.get("contract_id", "Runtime Contract"))),
		"subtitle": "%s • %s" % [str(movie.get("title", "Live reality")), str(lifecycle.get("phase", "active"))],
		"population": _population_from_zones(zones),
		"zone_counts": _zone_counts(zones),
		"active_friction_events": _safe_array(contract.get("active_friction_events", []))
	}

func _add_actor_to_contract_zone(contract_data: Dictionary, actor_id: int, zone_id: String) -> void:
	if actor_id <= 0:
		return

	var zones: Dictionary = _safe_dictionary(contract_data.get("zones", {}))
	if zones.is_empty():
		zones ["lobby"] = { "zone_id": "lobby", "actor_ids": [], "ambient_people": []}

	_remove_actor_from_contract_zones(contract_data, actor_id)
	zones = _safe_dictionary(contract_data.get("zones", zones))

	var clean_zone: String = str(zone_id).strip_edges().to_lower()
	if clean_zone == "":
		clean_zone = "lobby"
	if not zones.has(clean_zone):
		zones [clean_zone] = { "zone_id": clean_zone, "actor_ids": [], "ambient_people": []}

	var zone: Dictionary = _safe_dictionary(zones.get(clean_zone, {}))
	var actor_ids: Array = _safe_array(zone.get("actor_ids", []))
	if not actor_ids.has(actor_id):
		actor_ids.append(actor_id)
	zone ["actor_ids"] = actor_ids
	zones [clean_zone] = zone
	contract_data ["zones"] = zones
	contract_data ["population"] = _population_from_zones(zones)


func _remove_actor_from_contract_zones(contract_data: Dictionary, actor_id: int) -> void:
	if actor_id <= 0:
		return

	var zones: Dictionary = _safe_dictionary(contract_data.get("zones", {}))
	for raw_zone in zones.keys():
		var zone_id: String = str(raw_zone)
		var zone: Dictionary = _safe_dictionary(zones.get(zone_id, {}))
		var actor_ids: Array = _safe_array(zone.get("actor_ids", []))
		while actor_ids.has(actor_id):
			actor_ids.erase(actor_id)
		zone ["actor_ids"] = actor_ids
		zones [zone_id] = zone

	contract_data ["zones"] = zones
	contract_data ["population"] = _population_from_zones(zones)


func _population_from_zones(zones: Dictionary) -> int:
	var total: int = 0
	for raw_zone in zones.keys():
		var zone: Dictionary = _safe_dictionary(zones.get(str(raw_zone), {}))
		total += _safe_array(zone.get("actor_ids", [])).size()
		total += _safe_array(zone.get("ambient_people", [])).size()
	return total


func _zone_counts(zones: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for raw_zone in zones.keys():
		var zone_id: String = str(raw_zone)
		var zone: Dictionary = _safe_dictionary(zones.get(zone_id, {}))
		out [zone_id] = _safe_array(zone.get("actor_ids", [])).size() + _safe_array(zone.get("ambient_people", [])).size()
	return out


func _contract_population(contract: Dictionary) -> int:
	return _population_from_zones(_safe_dictionary(contract.get("zones", {})))


func _country_profile(country: String, era_name: String) -> Dictionary:
	var clean_country: String = str(country).strip_edges()
	var normalized: String = clean_country.to_lower()

	var profile: Dictionary = {
		"country": clean_country,
		"era": era_name,
		"crowd_density_modifier": 1.0,
		"public_conflict_modifier": 1.0,
		"commerce_price_modifier": 1.0
	}

	if normalized.find("united states") >= 0:
		profile ["crowd_density_modifier"] = 1.15
		profile ["public_conflict_modifier"] = 1.05
	elif normalized.find("japan") >= 0:
		profile ["crowd_density_modifier"] = 1.22
		profile ["public_conflict_modifier"] = 0.72
	elif normalized.find("south korea") >= 0:
		profile ["crowd_density_modifier"] = 1.18
		profile ["public_conflict_modifier"] = 0.82
	elif normalized.find("future") >= 0 or era_name == "Future Era":
		profile ["crowd_density_modifier"] = 1.35
		profile ["commerce_price_modifier"] = 1.28

	return profile


func _current_year() -> int:
	if gs == null:
		return 0
	if "year" in gs:
		return int(gs.year)
	if "scenario_state" in gs and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		return int(gs.scenario_state.get("year", 0))
	return 0


func _current_era_name() -> String:
	if gs == null:
		return "Modern Era"
	if gs.era != null:
		var era_text: String = str(gs.era.name if "name" in gs.era else gs.era).strip_edges()
		if era_text != "":
			return era_text
	var year_value: int = _current_year()
	if year_value <= 476:
		return "Ancient Era"
	if year_value <= 1492:
		return "Medieval Era"
	if year_value <= 1945:
		return "Industrial Era"
	if year_value <= 2039:
		return "Modern Era"
	return "Future Era"

func _clean_runtime_location_text(raw_value: Variant) -> String:
	if raw_value == null:
		return ""
	var text: String = str(raw_value).strip_edges()
	var lowered: String = text.to_lower()
	if text == "" or lowered in ["<null>", "null", "none", "nil", "n/a", "unknown"]:
		return ""
	return text
func _current_country() -> String:
	if gs != null and gs.player != null:
		for key in ["country", "birth_country", "current_country", "home_country"]:
			var value: String = _clean_runtime_location_text(gs.player.get(key) if gs.player.has_method("get") else "")
			if value != "":
				return value
	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		for key in ["country", "birth_country", "current_country", "home_country"]:
			var state_country: String = _clean_runtime_location_text(gs.scenario_state.get(key, ""))
			if state_country != "":
				return state_country
	return "United States"

func _current_country_key() -> String:
	var country_key: String = _clean_runtime_location_text(_current_country()).to_lower()
	if country_key == "":
		country_key = "united_states"
	return country_key.replace(" ", "_").replace(",", "")

func _current_city() -> String:
	if gs != null and gs.player != null:
		for key in ["city", "birth_city", "current_city", "home_city"]:
			var value: String = _clean_runtime_location_text(gs.player.get(key) if gs.player.has_method("get") else "")
			if value != "":
				return value
	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		for key in ["city", "birth_city", "current_city", "home_city"]:
			var state_city: String = _clean_runtime_location_text(gs.scenario_state.get(key, ""))
			if state_city != "":
				return state_city
	return "Unknown City"


func _actor_from_payload(payload: Dictionary) -> Person:
	if gs == null:
		return null
	var actor_id: int = int(payload.get("actor_id", payload.get("player_id", -1)))
	if actor_id > 0 and gs.has_method("get_npc_by_id"):
		var actor: Person = gs.get_npc_by_id(actor_id)
		if actor != null:
			return actor
	return gs.player


func _stable_seed(material: String) -> int:
	var value: int = int(hash(str(material)))
	if value < 0:
		value = - value
	if value <= 0:
		value = 1
	return value


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)


func _merge_dictionaries(base: Dictionary, patch: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	for key in patch.keys():
		var patch_value: Variant = patch.get(key)
		if typeof(patch_value) == TYPE_DICTIONARY and typeof(out.get(key, {})) == TYPE_DICTIONARY:
			out [key] = _merge_dictionaries(out.get(key, {}), patch_value)
		else:
			out [key] = patch_value
	return out


func _make_binary_safe(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var out: Dictionary = {}
			for raw_key in (value as Dictionary).keys():
				out [raw_key] = _make_binary_safe((value as Dictionary).get(raw_key))
			return out
		TYPE_ARRAY:
			var arr: Array = []
			for raw_item in (value as Array):
				arr.append(_make_binary_safe(raw_item))
			return arr
		TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_BOOL, TYPE_NIL:
			return value
		_:
			return str(value)