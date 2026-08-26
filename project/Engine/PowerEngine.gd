extends Resource
class_name PowerEngine

const CONTRACT_SCHEMA:= "eralife.power_engine_contract"
const CONTRACT_VERSION:= 1
const STATE_SCHEMA:= "eralife.power_engine_state"
const STATE_KEY:= "power_engine_state"
const MAX_POWER_EVENT_LEDGER:= 220

var gs
var active_contract: Dictionary = {}
var contract_registry: Dictionary = {}
var origin_registry: Dictionary = {}
var last_contract_report: Dictionary = {}
var last_power_report: Dictionary = {}

func _init(_gs = null, contract: Dictionary = {}) -> void:
	gs = _gs
	set_contract(contract)

func set_contract(contract: Dictionary = {}) -> Dictionary:
	active_contract = _default_contract()
	if typeof(contract) == TYPE_DICTIONARY and not contract.is_empty():
		active_contract = _merge_dict(active_contract, contract)

	_bootstrap_contract_registry()

	last_contract_report = {
		"schema": "eralife.power_engine_contract_set_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"contract_id": str(active_contract.get("id", "power_engine.default")),
		"registered_power_count": contract_registry.size(),
		"registered_origin_count": origin_registry.size(),
		"set_at_ms": int(Time.get_ticks_msec())
	}

	return last_contract_report.duplicate(true)

func bootstrap_default_contracts() -> Dictionary:
	_bootstrap_contract_registry()

	var state: Dictionary = _world_state()
	state ["contract_registry"] = contract_registry.duplicate(true)
	state ["origin_registry"] = origin_registry.duplicate(true)
	_commit_world_state(state)

	return {
		"success": true,
		"schema": "eralife.power_engine_bootstrap_report",
		"version": CONTRACT_VERSION,
		"registered_power_count": contract_registry.size(),
		"registered_origin_count": origin_registry.size(),
		"updated_at_ms": int(Time.get_ticks_msec())
	}

func export_state() -> Dictionary:
	return {
		"schema": STATE_SCHEMA,
		"version": CONTRACT_VERSION,
		"save_key": STATE_KEY,
		"persistent": true,
		"backwards_compatible": true,
		"preserve_unknown_fields": true,
		"active_contract": active_contract.duplicate(true),
		"contract_registry": contract_registry.duplicate(true),
		"origin_registry": origin_registry.duplicate(true),
		"world_state": _world_state().duplicate(true),
		"last_contract_report": last_contract_report.duplicate(true),
		"last_power_report": last_power_report.duplicate(true),
		"exported_at_ms": int(Time.get_ticks_msec())
	}

func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "PowerEngine import_state expected Dictionary."
		}

	var contract_raw: Variant = data.get("active_contract", {})
	if typeof(contract_raw) == TYPE_DICTIONARY:
		active_contract = _merge_dict(_default_contract(), contract_raw as Dictionary)
	else:
		active_contract = _default_contract()

	var registry_raw: Variant = data.get("contract_registry", {})
	if typeof(registry_raw) == TYPE_DICTIONARY:
		contract_registry = (registry_raw as Dictionary).duplicate(true)
	else:
		contract_registry = {}

	var origin_raw: Variant = data.get("origin_registry", {})
	if typeof(origin_raw) == TYPE_DICTIONARY:
		origin_registry = (origin_raw as Dictionary).duplicate(true)
	else:
		origin_registry = {}

	_bootstrap_contract_registry()

	var world_state_raw: Variant = data.get("world_state", {})
	if typeof(world_state_raw) == TYPE_DICTIONARY:
		_commit_world_state(_normalize_state(world_state_raw as Dictionary))

	var contract_report_raw: Variant = data.get("last_contract_report", {})
	if typeof(contract_report_raw) == TYPE_DICTIONARY:
		last_contract_report = (contract_report_raw as Dictionary).duplicate(true)

	var power_report_raw: Variant = data.get("last_power_report", {})
	if typeof(power_report_raw) == TYPE_DICTIONARY:
		last_power_report = (power_report_raw as Dictionary).duplicate(true)

	return {
		"success": true,
		"schema": "eralife.power_engine_import_report",
		"version": CONTRACT_VERSION,
		"power_count": contract_registry.size(),
		"origin_count": origin_registry.size(),
		"imported_at_ms": int(Time.get_ticks_msec())
	}

func has_superpowers(actor: Person) -> bool:
	if actor == null:
		return false

	var power_state: Dictionary = ensure_person_power_state(actor)
	var powers: Dictionary = _safe_dictionary(power_state.get("powers", {}))
	return not powers.is_empty()

func get_active_power_ids(actor: Person) -> Array:
	if actor == null:
		return []

	var power_state: Dictionary = ensure_person_power_state(actor)
	var powers: Dictionary = _safe_dictionary(power_state.get("powers", {}))
	var out: Array = []

	for raw_key in powers.keys():
		var key: String = str(raw_key).strip_edges()
		if key != "":
			out.append(key)

	return out

func get_power_contract(power_id: String) -> Dictionary:
	_bootstrap_contract_registry()

	var clean_id: String = str(power_id).strip_edges().to_lower()
	if clean_id == "":
		return {}

	if contract_registry.has(clean_id):
		return _safe_dictionary(contract_registry.get(clean_id, {}))

	return {}
func get_person_power_state(actor: Person) -> Dictionary:
	if actor == null:
		return {}

	var state: Dictionary = _world_state()
	var person_states: Dictionary = _safe_dictionary(state.get("person_power_state", {}))
	var row: Dictionary = _safe_dictionary(person_states.get(_person_key(actor), {}))

	if row.is_empty():
		return {}

	row = _refresh_life_stage_power_names(actor, row)
	person_states [_person_key(actor)] = row.duplicate(true)
	state ["person_power_state"] = person_states
	_commit_world_state(state)

	return row.duplicate(true)
func ensure_person_power_state(actor: Person) -> Dictionary:
	if actor == null:
		return {}

	var state: Dictionary = _world_state()
	var person_states: Dictionary = _safe_dictionary(state.get("person_power_state", {}))
	var key: String = _person_key(actor)

	var row: Dictionary = _safe_dictionary(person_states.get(key, {}))
	if row.is_empty():
		row = {
			"schema": "eralife.person_power_state",
			"version": CONTRACT_VERSION,
			"person_id": int(actor.id),
			"person_name": _person_label(actor),
			"origin": "none",
			"powers": {},
			"mutated_abilities": {},
			"mutation_contract_packets": {},
			"suppression": {},
			"corruption": 0.0,
			"fatigue": 0.0,
			"public_power_known": false,
			"public_visibility": "unknown",
			"hero_identity": "",
			"villain_identity": "",
			"configured_birth_power_id": "",
			"lineage_power_seed": {},
			"family_legacy": {},
			"rarity_profile": {},
			"latent_potential": 0,
			"fame_multiplier": 1.0,
			"hidden_identity_risk": 0.0,
			"opponent_tier_bias": "street_level",
			"low_tier_respect_multiplier": 1.0,
			"power_skill_points": 0,
			"power_stats": {
				"raw_force": 0,
				"control_discipline": 0,
				"speed_reaction": 0,
				"mutation_stability": 0,
				"heroic_pressure": 0
			},
			"last_mutation_sync": {},
			"updated_year": _current_year(),
			"created_at_ms": int(Time.get_ticks_msec())
		}

	if typeof(row.get("powers", {})) != TYPE_DICTIONARY:
		row ["powers"] = {}
	if typeof(row.get("mutated_abilities", {})) != TYPE_DICTIONARY:
		row ["mutated_abilities"] = {}
	if typeof(row.get("mutation_contract_packets", {})) != TYPE_DICTIONARY:
		row ["mutation_contract_packets"] = {}
	if typeof(row.get("suppression", {})) != TYPE_DICTIONARY:
		row ["suppression"] = {}
	if typeof(row.get("lineage_power_seed", {})) != TYPE_DICTIONARY:
		row ["lineage_power_seed"] = {}
	if typeof(row.get("family_legacy", {})) != TYPE_DICTIONARY:
		row ["family_legacy"] = {}
	if typeof(row.get("rarity_profile", {})) != TYPE_DICTIONARY:
		row ["rarity_profile"] = {}
	if typeof(row.get("last_mutation_sync", {})) != TYPE_DICTIONARY:
		row ["last_mutation_sync"] = {}

	if not row.has("power_skill_points"):
		row ["power_skill_points"] = 0
	if typeof(row.get("power_stats", {})) != TYPE_DICTIONARY:
		row ["power_stats"] = {}
	var power_stats: Dictionary = _safe_dictionary(row.get("power_stats", {}))
	for stat_id in ["raw_force", "control_discipline", "speed_reaction", "mutation_stability", "heroic_pressure"]:
		if not power_stats.has(stat_id):
			power_stats [stat_id] = 0
	row ["power_stats"] = power_stats
	if not row.has("latent_potential"):
		row ["latent_potential"] = 0
	if not row.has("fame_multiplier"):
		row ["fame_multiplier"] = 1.0
	if not row.has("hidden_identity_risk"):
		row ["hidden_identity_risk"] = 0.0
	if not row.has("opponent_tier_bias"):
		row ["opponent_tier_bias"] = "street_level"
	if not row.has("low_tier_respect_multiplier"):
		row ["low_tier_respect_multiplier"] = 1.0
	if not row.has("public_visibility"):
		row ["public_visibility"] = "public" if bool(row.get("public_power_known", false)) else "unknown"

	row ["person_id"] = int(actor.id)
	row ["person_name"] = _person_label(actor)
	row ["updated_year"] = _current_year()

	person_states [key] = row.duplicate(true)
	state ["person_power_state"] = person_states
	_commit_world_state(state)

	return row.duplicate(true)

func apply_birth_settings(actor: Person, settings: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "Actor missing."
		}

	if typeof(settings) != TYPE_DICTIONARY:
		settings = {}

	var report: Dictionary = {
		"success": true,
		"actor_id": int(actor.id),
		"actor_name": _person_label(actor),
		"granted": [],
		"source": "birth_settings"
	}

	var sandbox_config: Dictionary = _normalize_superpower_sandbox_config(settings.get("superpower_configurator", null))
	if not sandbox_config.is_empty():
		_store_superpower_sandbox_contract(sandbox_config, actor, settings)
		report ["sandbox_contract"] = sandbox_config.duplicate(true)

		var sandbox_report: Dictionary = _resolve_sandbox_configured_power(actor, {
			"source": "birth_settings",
			"seed_actor_id": int(actor.id),
			"settings": settings,
		})

		if bool(sandbox_report.get("success", false)) and bool(sandbox_report.get("granted_power", false)):
			report ["granted"].append(sandbox_report)
		elif bool(sandbox_report.get("seeded_power", false)):
			report ["seeded"] = sandbox_report.duplicate(true)

	if bool(settings.get("super_family", false)):
		var family_power_id: String = str(settings.get("family_power_id", "")).strip_edges().to_lower()
		if family_power_id == "":
			family_power_id = _weighted_power_pick([
				"super_strength",
				"super_speed",
				"spider_abilities",
				"energy_projection"
			])

		var grant_report: Dictionary = grant_power(actor, family_power_id, "super_family_birth", {
			"visibility": "family_known",
			"inherited": true
		})
		report ["granted"].append(grant_report)

	var starting_raw: Variant = settings.get("starting_power_ids", [])
	if typeof(starting_raw) == TYPE_ARRAY:
		for raw_power_id in starting_raw:
			var power_id: String = str(raw_power_id).strip_edges().to_lower()
			if power_id == "":
				continue

			report ["granted"].append(grant_power(actor, power_id, "custom_birth_settings", {
				"visibility": "known",
				"inherited": false
			}))

	var mutation_report: Dictionary = resolve_elemental_mutation_contract_packet(actor, {
		"source": "birth_settings",
		"settings": settings.duplicate(true),
		"persist": true
	})
	if bool(mutation_report.get("success", false)):
		report ["mutation_contract_packet"] = mutation_report.duplicate(true)

	return report

func assign_birth_powers(payload: Variant = {}) -> Dictionary:
	var actor: Person = _actor_from_payload(payload)
	if actor == null:
		return {
			"success": false,
			"reason": "No actor found for power birth assignment."
		}

	if not _mode_allows_powers():
		return {
			"success": false,
			"reason": "Superpowers only spawn in Chaos/Fantasy mode or when the superpowers feature override is enabled."
		}

	var state: Dictionary = _world_state()
	var existing: Dictionary = ensure_person_power_state(actor)
	if not _safe_dictionary(existing.get("powers", {})).is_empty():
		return {
			"success": true,
			"granted_power": false,
			"actor_id": int(actor.id)
		}

	var sandbox_report: Dictionary = _resolve_sandbox_configured_power(actor, payload)
	if bool(sandbox_report.get("success", false)):
		return sandbox_report

	var inherited_report: Dictionary = _resolve_inherited_power(actor)
	if bool(inherited_report.get("success", false)):
		return inherited_report

	var latent_chance: float = float(_safe_dictionary(active_contract.get("spawn_rules", {})).get("latent_birth_chance", 0.015))
	var chaos_bonus: float = 0.0
	if _reality_mode() == "chaos":
		chaos_bonus = 0.018
	elif _reality_mode() == "fantasy":
		chaos_bonus = 0.012

	if randf() <= latent_chance + chaos_bonus:
		var power_id: String = _weighted_power_pick([
			"super_strength",
			"super_speed",
			"energy_projection",
			"telepathy"
		])
		return grant_power(actor, power_id, "latent_birth_mutation", {
			"visibility": "unknown",
			"inherited": false
		})

	state ["last_birth_power_assignment"] = {
		"success": true,
		"actor_id": int(actor.id),
		"actor_name": _person_label(actor),
		"assigned": false,
		"granted_power": false,
		"updated_at_ms": int(Time.get_ticks_msec())
	}
	_commit_world_state(state)

	return state ["last_birth_power_assignment"].duplicate(true)

func bootstrap_spawn_power_population(people: Array) -> Dictionary:
	if not _mode_allows_powers():
		return {
			"success": false,
			"reason": "Power population bootstrap skipped outside Chaos/Fantasy mode."
		}

	var assigned: int = 0
	var scanned: int = 0

	for raw_person in people:
		if not (raw_person is Person):
			continue

		var person: Person = raw_person
		scanned += 1

		var report: Dictionary = assign_birth_powers({
			"person": person,
			"actor_id": int(person.id),
			"source": "population_bootstrap",
		})
		if bool(report.get("success", false)) and bool(report.get("granted_power", false)):
			assigned += 1

	var state: Dictionary = _world_state()
	state ["last_population_bootstrap"] = {
		"success": true,
		"scanned": scanned,
		"assigned": assigned,
		"year": _current_year(),
		"updated_at_ms": int(Time.get_ticks_msec())
	}
	_commit_world_state(state)

	return state ["last_population_bootstrap"].duplicate(true)
func grant_bending_as_superpower(actor: Person, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "Actor missing."
		}

	var bending_type: String = str(actor.bending_type).strip_edges().to_lower()
	if bending_type in ["", "none"]:
		return {
			"success": false,
			"reason": "Actor has no bending source to bridge into PowerEngine."
		}

	var is_avatar: bool = bending_type == "avatar"
	var power_id: String = "avatar_bending" if is_avatar else "%s_bending" % bending_type
	var display_name: String = "Avatar Bending" if is_avatar else "%s Bending" % bending_type.capitalize()
	var rarity_id: String = "legendary" if is_avatar else "rare"
	var rarity_profile: Dictionary = _superpower_rarity_profile(rarity_id)

	var mastery_total: int = 0
	var mastery_peak: int = 0
	var elements: Array = []
	if typeof(actor.bending_mastery) == TYPE_DICTIONARY:
		for raw_element in actor.bending_mastery.keys():
			var element_id: String = str(raw_element).strip_edges().to_lower()
			var mastery_value: int = int(actor.bending_mastery.get(raw_element, 0))
			if mastery_value <= 0:
				continue
			elements.append(element_id)
			mastery_total += mastery_value
			mastery_peak = max(mastery_peak, mastery_value)

	if elements.is_empty():
		if is_avatar:
			elements = ["fire", "water", "earth", "air"]
		else:
			elements = [bending_type]

	var base_power_level: int = int(rarity_profile.get("base_power_level", 25000))
	var latent_potential: int = int(rarity_profile.get("latent_potential", 800000))
	base_power_level += mastery_total * 850
	base_power_level += mastery_peak * 1600
	if is_avatar:
		base_power_level = max(base_power_level, 8000000)
		latent_potential = max(latent_potential, 600000000)

	var power_state: Dictionary = ensure_person_power_state(actor)
	var powers: Dictionary = _safe_dictionary(power_state.get("powers", {}))
	powers [power_id] = {
		"id": power_id,
		"display_name": display_name,
		"category": "bending_superpower",
		"rarity": rarity_id,
		"contract_rarity": rarity_id,
		"level": max(1, int(round(float(max(1, mastery_peak)) / 10.0))),
		"xp": 0,
		"control": clamp(0.28 + float(mastery_peak) / 140.0, 0.28, 0.96),
		"chaos": 0.38 if is_avatar else 0.18,
		"fatigue": 0.0,
		"corruption": 0.0,
		"suppressed": false,
		"source": str(context.get("source", "bending_superhero_bridge")),
		"inherited": false,
		"configured_at_birth": false,
		"visible_in_hub": true,
		"latent_locked": false,
		"birth_awakened": false,
		"bending_power_source": true,
		"base_power_level": base_power_level,
		"latent_potential": latent_potential,
		"hidden_identity_risk": float(rarity_profile.get("hidden_identity_risk", 0.08)),
		"fame_multiplier": float(rarity_profile.get("fame_multiplier", 1.0)),
		"opponent_tier_bias": str(rarity_profile.get("opponent_tier_bias", "city_level")),
		"low_tier_respect_multiplier": float(rarity_profile.get("low_tier_respect_multiplier", 1.0)),
		"rarity_profile": rarity_profile.duplicate(true),
		"effects": ["elemental_projection", "martial_flow", "environmental_control", "heroic_response"],
		"subskills": elements.duplicate(true),
		"unlocked_subskills": elements.duplicate(true),
		"elemental_profile": {
			"bending_type": bending_type,
			"elements": elements.duplicate(true),
			"mastery_total": mastery_total,
			"mastery_peak": mastery_peak,
			"is_avatar": is_avatar
		},
		"created_year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	power_state ["powers"] = powers
	power_state ["origin"] = str(context.get("source", "bending_superhero_bridge"))
	power_state ["public_visibility"] = str(context.get("visibility", "public"))
	power_state ["public_power_known"] = str(context.get("visibility", "public")) == "public"
	power_state ["rarity_profile"] = rarity_profile.duplicate(true)
	power_state ["latent_potential"] = max(int(power_state.get("latent_potential", 0)), latent_potential)
	power_state ["fame_multiplier"] = max(float(power_state.get("fame_multiplier", 1.0)), float(rarity_profile.get("fame_multiplier", 1.0)))
	power_state ["hidden_identity_risk"] = max(float(power_state.get("hidden_identity_risk", 0.0)), float(rarity_profile.get("hidden_identity_risk", 0.0)))
	power_state ["opponent_tier_bias"] = str(rarity_profile.get("opponent_tier_bias", "city_level"))
	power_state ["updated_year"] = _current_year()

	var state: Dictionary = _world_state()
	var person_states: Dictionary = _safe_dictionary(state.get("person_power_state", {}))
	person_states [_person_key(actor)] = power_state.duplicate(true)
	state ["person_power_state"] = person_states
	_commit_world_state(state)

	var report: Dictionary = {
		"schema": "eralife.bending_superpower_bridge_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"person_id": int(actor.id),
		"person_name": _person_label(actor),
		"power_id": power_id,
		"display_name": display_name,
		"base_power_level": base_power_level,
		"latent_potential": latent_potential,
		"bending_type": bending_type,
		"elements": elements.duplicate(true),
		"source": str(context.get("source", "bending_superhero_bridge")),
		"created_year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	_record_power_event(report)
	last_power_report = report.duplicate(true)
	return report.duplicate(true)
func grant_power(actor: Person, power_id: String, source: String = "manual", context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "Actor missing."
		}

	var clean_power_id: String = str(power_id).strip_edges().to_lower()
	var contract: Dictionary = get_power_contract(clean_power_id)
	if contract.is_empty():
		return {
			"success": false,
			"reason": "Power contract not found.",
			"power_id": clean_power_id
		}

	var state: Dictionary = _world_state()
	var person_states: Dictionary = _safe_dictionary(state.get("person_power_state", {}))
	var key: String = _person_key(actor)
	var power_state: Dictionary = ensure_person_power_state(actor)

	var sandbox_config: Dictionary = _safe_dictionary(context.get("superpower_sandbox_config", {}))
	var context_rarity: String = str(context.get("rarity", sandbox_config.get("rarity", contract.get("rarity", "common")))).strip_edges().to_lower()
	var rarity_profile: Dictionary = _safe_dictionary(context.get("rarity_profile", sandbox_config.get("rarity_profile", {})))
	if rarity_profile.is_empty():
		rarity_profile = _superpower_rarity_profile(context_rarity)

	var base_power_level: int = max(0, int(context.get("base_power_level", rarity_profile.get("base_power_level", 0))))
	var latent_potential: int = max(base_power_level, int(context.get("latent_potential", rarity_profile.get("latent_potential", base_power_level))))
	var awakening_mode: String = str(context.get("awakening_mode", "")).strip_edges().to_lower()
	var latent_locked: bool = bool(context.get("latent_locked", false)) or awakening_mode in ["latent", "trauma_triggered", "age_gate"]
	var visibility: String = str(context.get("visibility", "unknown")).strip_edges().to_lower()

	var starting_level: int = int(contract.get("starting_level", 1))
	if base_power_level >= 900:
		starting_level = max(starting_level, 8)
	elif base_power_level >= 500:
		starting_level = max(starting_level, 6)
	elif base_power_level >= 250:
		starting_level = max(starting_level, 4)
	elif base_power_level >= 100:
		starting_level = max(starting_level, 2)

	var powers: Dictionary = _safe_dictionary(power_state.get("powers", {}))
	if not powers.has(clean_power_id):
		powers [clean_power_id] = {
			"id": clean_power_id,
			"display_name": str(contract.get("display_name", clean_power_id.capitalize())),
			"category": str(contract.get("category", "superpower")),
			"rarity": context_rarity,
			"contract_rarity": str(contract.get("rarity", "common")),
			"level": starting_level,
			"xp": 0,
			"control": float(_safe_dictionary(contract.get("scaling", {})).get("control", 0.25)),
			"chaos": float(_safe_dictionary(contract.get("scaling", {})).get("chaos", 0.25)),
			"fatigue": 0.0,
			"corruption": 0.0,
			"suppressed": false,
			"source": source,
			"inherited": bool(context.get("inherited", false)),
			"family_variant": bool(context.get("family_variant", false)),
			"configured_at_birth": bool(context.get("configured_at_birth", false)),
			"visible_in_hub": bool(context.get("visible_in_hub", true)),
			"latent_locked": latent_locked,
			"awakening_mode": awakening_mode,
			"birth_awakened": bool(context.get("birth_awakened", false)),
			"base_power_level": base_power_level,
			"latent_potential": latent_potential,
			"hidden_identity_risk": float(context.get("hidden_identity_risk", rarity_profile.get("hidden_identity_risk", 0.0))),
			"fame_multiplier": float(context.get("fame_multiplier", rarity_profile.get("fame_multiplier", 1.0))),
			"opponent_tier_bias": str(context.get("opponent_tier_bias", rarity_profile.get("opponent_tier_bias", "street_level"))),
			"low_tier_respect_multiplier": float(context.get("low_tier_respect_multiplier", rarity_profile.get("low_tier_respect_multiplier", 1.0))),
			"rarity_profile": rarity_profile.duplicate(true),
			"subskills": _safe_array(contract.get("subskills", [])),
			"unlocked_subskills": _initial_subskills(contract),
			"created_year": _current_year(),
			"created_at_ms": int(Time.get_ticks_msec())
		}
	else:
		var existing_row: Dictionary = _safe_dictionary(powers.get(clean_power_id, {}))
		existing_row ["visible_in_hub"] = true
		existing_row ["rarity"] = str(existing_row.get("rarity", context_rarity))
		existing_row ["base_power_level"] = max(int(existing_row.get("base_power_level", 0)), base_power_level)
		existing_row ["latent_potential"] = max(int(existing_row.get("latent_potential", 0)), latent_potential)
		if context.has("latent_locked"):
			existing_row ["latent_locked"] = bool(context.get("latent_locked", false))
		if context.has("rarity_profile"):
			existing_row ["rarity_profile"] = rarity_profile.duplicate(true)
		powers [clean_power_id] = existing_row.duplicate(true)

	power_state ["powers"] = powers
	power_state ["origin"] = str(context.get("origin", power_state.get("origin", source)))
	power_state ["public_visibility"] = visibility
	power_state ["public_power_known"] = visibility == "public"
	power_state ["rarity_profile"] = rarity_profile.duplicate(true)
	power_state ["latent_potential"] = max(int(power_state.get("latent_potential", 0)), latent_potential)
	power_state ["fame_multiplier"] = max(float(power_state.get("fame_multiplier", 1.0)), float(context.get("fame_multiplier", rarity_profile.get("fame_multiplier", 1.0))))
	power_state ["hidden_identity_risk"] = max(float(power_state.get("hidden_identity_risk", 0.0)), float(context.get("hidden_identity_risk", rarity_profile.get("hidden_identity_risk", 0.0))))
	power_state ["opponent_tier_bias"] = str(context.get("opponent_tier_bias", rarity_profile.get("opponent_tier_bias", power_state.get("opponent_tier_bias", "street_level"))))
	power_state ["low_tier_respect_multiplier"] = max(float(power_state.get("low_tier_respect_multiplier", 1.0)), float(context.get("low_tier_respect_multiplier", rarity_profile.get("low_tier_respect_multiplier", 1.0))))
	power_state ["updated_year"] = _current_year()

	if bool(context.get("configured_at_birth", false)):
		power_state ["configured_birth_power_id"] = clean_power_id
	if typeof(context.get("superpower_sandbox_config", {})) == TYPE_DICTIONARY:
		power_state ["lineage_power_seed"] = _safe_dictionary(context.get("superpower_sandbox_config", {}))
	if typeof(context.get("family_legacy", {})) == TYPE_DICTIONARY:
		power_state ["family_legacy"] = _safe_dictionary(context.get("family_legacy", {}))

	var public_identity: String = str(context.get("public_identity", "")).strip_edges().to_lower()
	if public_identity == "registered_hero":
		power_state ["hero_identity"] = "registered_hero"
	elif public_identity == "wanted_villain":
		power_state ["villain_identity"] = "wanted_villain"

	person_states [key] = power_state.duplicate(true)
	state ["person_power_state"] = person_states

	var report: Dictionary = {
		"schema": "eralife.power_grant_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"granted_power": true,
		"person_id": int(actor.id),
		"person_name": _person_label(actor),
		"power_id": clean_power_id,
		"display_name": str(contract.get("display_name", clean_power_id.capitalize())),
		"rarity": context_rarity,
		"base_power_level": base_power_level,
		"latent_potential": latent_potential,
		"latent_locked": latent_locked,
		"visible_in_hub": true,
		"source": source,
		"context": context.duplicate(true),
		"created_year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	_maybe_append_power_birth_intro_memory(actor, contract, source, context)

	_record_power_event(report)
	last_power_report = report.duplicate(true)
	_commit_world_state(state)

	return report.duplicate(true)
func maximize_power_state_to_latent_potential(actor: Person, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "Actor missing."
		}

	var state: Dictionary = _world_state()
	var person_states: Dictionary = _safe_dictionary(state.get("person_power_state", {}))
	var key: String = _person_key(actor)
	var power_state: Dictionary = ensure_person_power_state(actor)
	var powers: Dictionary = _safe_dictionary(power_state.get("powers", {}))

	if powers.is_empty():
		return {
			"success": true,
			"schema": "eralife.power_latent_max_report",
			"version": CONTRACT_VERSION,
			"person_id": int(actor.id),
			"person_name": _person_label(actor),
			"power_count": 0,
			"reason": "No active powers to maximize."
		}

	var unlocked_power_count: int = 0
	var unlocked_subskill_count: int = 0
	var maxed_latent_total: int = 0

	for raw_power_id in powers.keys():
		var power_id: String = str(raw_power_id).strip_edges().to_lower()
		if power_id == "":
			continue

		var row: Dictionary = _safe_dictionary(powers.get(raw_power_id, {}))
		if row.is_empty():
			continue

		var contract: Dictionary = get_power_contract(power_id)
		var subskills: Array = _safe_array(row.get("subskills", contract.get("subskills", [])))
		var latent_potential: int = max(
			int(row.get("latent_potential", 0)),
			int(row.get("base_power_level", 0)),
			int(power_state.get("latent_potential", 0))
		)

		if latent_potential <= 0:
			latent_potential = 1000000000000

		row ["base_power_level"] = max(int(row.get("base_power_level", 0)), latent_potential)
		row ["latent_potential"] = latent_potential
		row ["level"] = max(int(row.get("level", 1)), 100)
		row ["xp"] = max(int(row.get("xp", 0)), 1000000)
		row ["control"] = max(float(row.get("control", 0.0)), 1.0)
		row ["chaos"] = min(float(row.get("chaos", 0.0)), 0.0)
		row ["fatigue"] = 0.0
		row ["corruption"] = 0.0
		row ["suppressed"] = false
		row ["latent_locked"] = false
		row ["birth_awakened"] = true
		row ["visible_in_hub"] = true
		row ["red_bonnet_maxed"] = true
		row ["red_bonnet_maxed_at_year"] = _current_year()

		if not subskills.is_empty():
			row ["subskills"] = subskills.duplicate(true)
			row ["unlocked_subskills"] = subskills.duplicate(true)
			unlocked_subskill_count += subskills.size()

		row ["mastery_tier"] = _power_mastery_tier(row)
		powers [raw_power_id] = row.duplicate(true)
		unlocked_power_count += 1
		maxed_latent_total = max(maxed_latent_total, latent_potential)

	power_state ["powers"] = powers
	power_state ["latent_potential"] = max(int(power_state.get("latent_potential", 0)), maxed_latent_total)
	power_state ["fatigue"] = 0.0
	power_state ["corruption"] = 0.0
	power_state ["public_power_known"] = true
	power_state ["public_visibility"] = str(context.get("visibility", power_state.get("public_visibility", "public")))
	power_state ["red_bonnet_maxed"] = true
	power_state ["updated_year"] = _current_year()

	var power_stats: Dictionary = _safe_dictionary(power_state.get("power_stats", {}))
	for stat_id in ["raw_force", "control_discipline", "speed_reaction", "mutation_stability", "heroic_pressure"]:
		power_stats [stat_id] = max(int(power_stats.get(stat_id, 0)), 100)
	power_state ["power_stats"] = power_stats

	person_states [key] = power_state.duplicate(true)
	state ["person_power_state"] = person_states
	_commit_world_state(state)

	var mutation_report: Dictionary = resolve_elemental_mutation_contract_packet(actor, {
		"source": "red_bonnet_latent_max",
		"persist": true
	})

	if bool(mutation_report.get("success", false)):
		state = _world_state()
		person_states = _safe_dictionary(state.get("person_power_state", {}))
		power_state = ensure_person_power_state(actor)

		var mutated_abilities: Dictionary = _safe_dictionary(power_state.get("mutated_abilities", {}))
		for raw_mutation_id in mutated_abilities.keys():
			var ability: Dictionary = _safe_dictionary(mutated_abilities.get(raw_mutation_id, {}))
			if ability.is_empty():
				continue
			ability ["level"] = max(int(ability.get("level", 1)), 100)
			ability ["tier"] = str(ability.get("tier", "mythic"))
			ability ["mastery_tier"] = "reality_break"
			ability ["unlocked"] = true
			ability ["red_bonnet_maxed"] = true
			mutated_abilities [raw_mutation_id] = ability.duplicate(true)

		power_state ["mutated_abilities"] = mutated_abilities.duplicate(true)
		person_states [key] = power_state.duplicate(true)
		state ["person_power_state"] = person_states
		_commit_world_state(state)

	var report: Dictionary = {
		"success": true,
		"schema": "eralife.power_latent_max_report",
		"version": CONTRACT_VERSION,
		"person_id": int(actor.id),
		"person_name": _person_label(actor),
		"power_count": unlocked_power_count,
		"unlocked_subskill_count": unlocked_subskill_count,
		"latent_potential": maxed_latent_total,
		"source": str(context.get("source", "power_engine.maximize_power_state_to_latent_potential")),
		"created_year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	_record_power_event(report)
	last_power_report = report.duplicate(true)
	return report.duplicate(true)
func _maybe_append_power_birth_intro_memory(actor: Person, contract: Dictionary, source: String, context: Dictionary = {}) -> void:
	if actor == null:
		return

	var clean_source: String = str(source).strip_edges().to_lower()
	if clean_source.find("birth") == -1:
		return

	var power_name: String = str(contract.get("display_name", contract.get("id", "power"))).strip_edges()
	if power_name == "":
		power_name = "power"

	var text: String = _power_birth_intro_flavor(actor, contract, source, context)
	if text == "":
		return

	if "memories" in actor and actor.memories is Array:
		for raw_memory in actor.memories:
			if str(raw_memory).strip_edges() == text:
				return
		actor.memories.append(text)

func _power_birth_intro_flavor(_actor: Person, contract: Dictionary, _source: String, context: Dictionary = {}) -> String:
	var power_name: String = str(contract.get("display_name", contract.get("id", "power"))).strip_edges()
	var power_id: String = str(contract.get("id", "")).strip_edges().to_lower()
	var awakening_mode: String = str(context.get("awakening_mode", "")).strip_edges().to_lower()
	var birth_awakened: bool = bool(context.get("birth_awakened", false)) or bool(contract.get("birth_awakened", false))

	var birth_flavor: Dictionary = _safe_dictionary(contract.get("birth_flavor", {}))
	if birth_awakened:
		var rare_line: String = str(birth_flavor.get("rare_line", "")).strip_edges()
		var conception_story: String = str(birth_flavor.get("conception_story", "")).strip_edges()
		if conception_story != "":
			return "%s I was born with %s already awake in me." % [conception_story, power_name]
		if rare_line != "":
			return "%s I was born with %s already awake in me." % [rare_line, power_name]
		return "Before I learned how to cry, %s was already awake in me." % power_name

	if power_id == "infant_chaos_polymorph":
		return "The first time I cried, the room forgot what shape it was supposed to be. I was born with %s." % power_name

	if awakening_mode == "latent":
		return "I was born with something quiet under my skin. Nobody knew %s was sleeping in me yet." % power_name

	return "I was born touched by %s. Whether the world knows it or not, my story started impossible." % power_name
func resolve_power_action(actor: Person, payload: Dictionary = {}) -> Dictionary:
	var action: String = str(payload.get("action", payload.get("power_action", ""))).strip_edges().to_lower()

	match action:
		"train", "train_power":
			return train_power(actor, payload)
		"train_focus", "train_power_focus", "train_supe_stat", "train_subskill":
			return train_power_focus(actor, payload)
		"activate", "activate_power":
			return activate_power(actor, payload)
		"activate_mutation", "use_mutation", "use_mutated_ability":
			return activate_mutated_ability(actor, payload)
		"sync_mutations", "refresh_mutations":
			return resolve_elemental_mutation_contract_packet(actor, {
				"source": "resolve_power_action",
				"persist": true
			})
		"upgrade_power_stat", "upgrade_stat", "power_stat_upgrade":
			return upgrade_power_stat(actor, payload)
		"origin", "origin_attempt", "attempt_origin":
			return attempt_origin_event(actor, payload)
		_:
			return {
				"success": false,
				"reason": "Unknown power action.",
				"action": action
			}

func train_power(actor: Person, payload: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "Actor missing."
		}

	var power_id: String = str(payload.get("power_id", "")).strip_edges().to_lower()
	if power_id == "":
		var ids: Array = get_active_power_ids(actor)
		if not ids.is_empty():
			power_id = str(ids [0])

	if power_id == "":
		return {
			"success": false,
			"reason": "You do not have a power to train yet."
		}

	var state: Dictionary = _world_state()
	var person_states: Dictionary = _safe_dictionary(state.get("person_power_state", {}))
	var key: String = _person_key(actor)
	var power_state: Dictionary = ensure_person_power_state(actor)
	var powers: Dictionary = _safe_dictionary(power_state.get("powers", {}))
	var row: Dictionary = _safe_dictionary(powers.get(power_id, {}))

	if row.is_empty():
		return {
			"success": false,
			"reason": "Power not found on actor.",
			"power_id": power_id
		}

	var xp_gain: int = int(payload.get("xp_gain", 16))
	var control_gain: float = float(payload.get("control_gain", 0.025))
	var fatigue_gain: float = float(payload.get("fatigue_gain", 0.04))

	row ["xp"] = int(row.get("xp", 0)) + xp_gain
	row ["control"] = clamp(float(row.get("control", 0.0)) + control_gain, 0.0, 1.0)
	row ["fatigue"] = clamp(float(row.get("fatigue", 0.0)) + fatigue_gain, 0.0, 1.0)

	var threshold: int = max(80, int(row.get("level", 1)) * 95)
	var leveled: bool = false
	if int(row.get("xp", 0)) >= threshold:
		row ["xp"] = int(row.get("xp", 0)) - threshold
		row ["level"] = int(row.get("level", 1)) + 1
		leveled = true
		power_state ["power_skill_points"] = int(power_state.get("power_skill_points", 0)) + 1
		_unlock_next_subskill(row)

	powers [power_id] = row
	power_state ["powers"] = powers
	power_state ["fatigue"] = clamp(float(power_state.get("fatigue", 0.0)) + fatigue_gain, 0.0, 1.0)
	power_state ["updated_year"] = _current_year()
	person_states [key] = power_state
	state ["person_power_state"] = person_states

	var report: Dictionary = {
		"success": true,
		"schema": "eralife.power_training_report",
		"person_id": int(actor.id),
		"power_id": power_id,
		"xp_gain": xp_gain,
		"control_gain": control_gain,
		"fatigue_gain": fatigue_gain,
		"leveled": leveled,
		"level": int(row.get("level", 1)),
		"text": "You trained %s. Control sharpened. Fatigue rose." % str(row.get("display_name", power_id.capitalize()))
	}

	_record_power_event(report)
	_commit_world_state(state)
	return report
func train_power_focus(actor: Person, payload: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "Actor missing."
		}

	var training_focus: String = str(payload.get("training_focus", "power")).strip_edges().to_lower()
	var power_id: String = str(payload.get("power_id", "")).strip_edges().to_lower()
	var stat_id: String = str(payload.get("stat_id", "")).strip_edges().to_lower()
	var subskill_id: String = str(payload.get("subskill_id", "")).strip_edges().to_lower()

	var power_state: Dictionary = ensure_person_power_state(actor)
	var powers: Dictionary = _safe_dictionary(power_state.get("powers", {}))
	if power_id == "" and not powers.is_empty():
		power_id = str(powers.keys() [0]).strip_edges().to_lower()

	var state: Dictionary = _world_state()
	var person_states: Dictionary = _safe_dictionary(state.get("person_power_state", {}))
	var key: String = _person_key(actor)

	var fatigue: float = clamp(float(power_state.get("fatigue", 0.0)), 0.0, 1.0)
	var willpower_score: float = clamp(float(actor.willpower), 0.0, 100.0)
	if gs != null and "willpower_engine" in gs and gs.willpower_engine != null and gs.willpower_engine.has_method("score"):
		willpower_score = clamp(float(gs.willpower_engine.score(actor, {
			"source": "power_training_focus"
		})), 0.0, 100.0)

	var success_chance: float = clamp(0.42 + (willpower_score / 180.0) - (fatigue * 0.34), 0.08, 0.94)
	var succeeded: bool = randf() <= success_chance
	var fatigue_gain: float = 0.035 if succeeded else 0.065
	var xp_gain: int = 16 if succeeded else 5
	var control_gain: float = 0.025 if succeeded else 0.006
	var skill_point_gain: int = 0
	var unlocked_subskill: String = ""

	var powers_changed: bool = false
	if power_id != "" and powers.has(power_id):
		var row: Dictionary = _safe_dictionary(powers.get(power_id, {}))
		row ["xp"] = int(row.get("xp", 0)) + xp_gain
		row ["control"] = clamp(float(row.get("control", 0.0)) + control_gain, 0.0, 1.0)
		row ["fatigue"] = clamp(float(row.get("fatigue", 0.0)) + fatigue_gain, 0.0, 1.0)

		if succeeded:
			var threshold: int = max(80, int(row.get("level", 1)) * 95)
			if int(row.get("xp", 0)) >= threshold:
				row ["xp"] = int(row.get("xp", 0)) - threshold
				row ["level"] = int(row.get("level", 1)) + 1
				skill_point_gain += 1
				_unlock_next_subskill(row)

			if training_focus == "subskill":
				var unlocked_subskills: Array = _safe_array(row.get("unlocked_subskills", []))
				var all_subskills: Array = _safe_array(row.get("subskills", []))
				if subskill_id != "" and subskill_id in all_subskills and not subskill_id in unlocked_subskills:
					unlocked_subskills.append(subskill_id)
					row ["unlocked_subskills"] = unlocked_subskills
					unlocked_subskill = subskill_id
					skill_point_gain += 1

		powers [power_id] = row
		power_state ["powers"] = powers
		powers_changed = true

	if training_focus == "stat" and stat_id != "":
		var valid_stats: Array = ["raw_force", "control_discipline", "speed_reaction", "mutation_stability", "heroic_pressure"]
		if stat_id not in valid_stats:
			return {
				"success": false,
				"reason": "Unknown supe stat.",
				"stat_id": stat_id
			}

		var power_stats: Dictionary = _safe_dictionary(power_state.get("power_stats", {}))
		for valid_id in valid_stats:
			if not power_stats.has(valid_id):
				power_stats [valid_id] = 0

		if succeeded:
			power_stats [stat_id] = int(power_stats.get(stat_id, 0)) + 1

		power_state ["power_stats"] = power_stats

	if not powers_changed and training_focus in ["power", "subskill"]:
		return {
			"success": false,
			"reason": "No valid power was available for this training focus.",
			"power_id": power_id
		}

	power_state ["power_skill_points"] = int(power_state.get("power_skill_points", 0)) + skill_point_gain
	power_state ["fatigue"] = clamp(float(power_state.get("fatigue", 0.0)) + fatigue_gain, 0.0, 1.0)
	power_state ["updated_year"] = _current_year()

	person_states [key] = power_state.duplicate(true)
	state ["person_power_state"] = person_states
	_commit_world_state(state)

	var focus_label: String = training_focus.replace("_", " ").capitalize()
	var report_text: String = "You trained %s." % focus_label
	if succeeded:
		report_text += " The session worked."
	else:
		report_text += " The session failed, but the strain still left a mark."
	if unlocked_subskill != "":
		report_text += " %s unlocked." % unlocked_subskill.replace("_", " ").capitalize()
	if skill_point_gain > 0:
		report_text += " You gained %d Power Skill Point(s)." % skill_point_gain

	var report: Dictionary = {
		"success": true,
		"schema": "eralife.power_focused_training_report",
		"version": CONTRACT_VERSION,
		"person_id": int(actor.id),
		"person_name": _person_label(actor),
		"training_focus": training_focus,
		"power_id": power_id,
		"stat_id": stat_id,
		"subskill_id": subskill_id,
		"succeeded": succeeded,
		"success_chance": success_chance,
		"xp_gain": xp_gain,
		"control_gain": control_gain,
		"fatigue_gain": fatigue_gain,
		"skill_point_gain": skill_point_gain,
		"unlocked_subskill": unlocked_subskill,
		"text": report_text,
		"popup_title": "Power Training",
		"popup_text": report_text,
		"popup_footer": "Training is now contract-driven by focus, willpower, fatigue, and progression.",
		"created_year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	_record_power_event(report)
	return report
func upgrade_power_stat(actor: Person, payload: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "Actor missing."
		}

	var stat_id: String = str(payload.get("stat_id", payload.get("power_stat", ""))).strip_edges().to_lower()
	var valid_stats: Array = ["raw_force", "control_discipline", "speed_reaction", "mutation_stability", "heroic_pressure"]
	if stat_id == "" or stat_id not in valid_stats:
		return {
			"success": false,
			"reason": "Unknown power stat.",
			"stat_id": stat_id
		}

	var state: Dictionary = _world_state()
	var person_states: Dictionary = _safe_dictionary(state.get("person_power_state", {}))
	var key: String = _person_key(actor)
	var power_state: Dictionary = ensure_person_power_state(actor)
	var power_stats: Dictionary = _safe_dictionary(power_state.get("power_stats", {}))

	for valid_id in valid_stats:
		if not power_stats.has(valid_id):
			power_stats [valid_id] = 0

	var current_level: int = int(power_stats.get(stat_id, 0))
	var cost: int = max(1, int(payload.get("cost", current_level + 1)))
	var available_points: int = int(power_state.get("power_skill_points", 0))

	if available_points < cost:
		return {
			"success": false,
			"reason": "Not enough Power Skill Points.",
			"required": cost,
			"available": available_points,
			"stat_id": stat_id,
			"popup_title": "Power Upgrade",
			"popup_text": "You need %d Power Skill Point(s) to upgrade %s.\n\nAvailable: %d" % [
				cost,
				stat_id.replace("_", " ").capitalize(),
				available_points
			],
			"popup_footer": "Train powers to level up and earn Power Skill Points."
		}

	power_stats [stat_id] = current_level + 1
	power_state ["power_stats"] = power_stats
	power_state ["power_skill_points"] = available_points - cost
	power_state ["updated_year"] = _current_year()

	person_states [key] = power_state.duplicate(true)
	state ["person_power_state"] = person_states
	_commit_world_state(state)

	var report: Dictionary = {
		"success": true,
		"schema": "eralife.power_stat_upgrade_report",
		"version": CONTRACT_VERSION,
		"person_id": int(actor.id),
		"person_name": _person_label(actor),
		"stat_id": stat_id,
		"new_level": int(power_stats.get(stat_id, 0)),
		"cost": cost,
		"remaining_points": int(power_state.get("power_skill_points", 0)),
		"text": "You upgraded %s to level %d." % [
			stat_id.replace("_", " ").capitalize(),
			int(power_stats.get(stat_id, 0))
		],
		"popup_title": "Power Upgrade",
		"popup_text": "%s upgraded to level %d.\n\nRemaining Power Skill Points: %d" % [
			stat_id.replace("_", " ").capitalize(),
			int(power_stats.get(stat_id, 0)),
			int(power_state.get("power_skill_points", 0))
		],
		"popup_footer": "Your powered body is becoming more specialized.",
		"created_year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	_record_power_event(report)
	return report
func activate_power(actor: Person, payload: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "Actor missing."
		}

	var power_id: String = str(payload.get("power_id", "")).strip_edges().to_lower()
	if power_id == "":
		var ids: Array = get_active_power_ids(actor)
		if not ids.is_empty():
			power_id = str(ids [0])

	var contract: Dictionary = get_power_contract(power_id)
	if contract.is_empty():
		return {
			"success": false,
			"reason": "No usable power contract found.",
			"power_id": power_id
		}

	var state: Dictionary = _world_state()
	var person_states: Dictionary = _safe_dictionary(state.get("person_power_state", {}))
	var key: String = _person_key(actor)
	var power_state: Dictionary = ensure_person_power_state(actor)
	var powers: Dictionary = _safe_dictionary(power_state.get("powers", {}))
	var row: Dictionary = _safe_dictionary(powers.get(power_id, {}))

	if row.is_empty():
		return {
			"success": false,
			"reason": "Actor does not have this power.",
			"power_id": power_id
		}

	if bool(row.get("suppressed", false)):
		return {
			"success": false,
			"reason": "This power is currently suppressed.",
			"power_id": power_id
		}

	var scaling: Dictionary = _safe_dictionary(contract.get("scaling", {}))
	var fatigue_cost: float = float(payload.get("fatigue_cost", scaling.get("fatigue", 0.15))) * 0.16
	var chaos_gain: float = float(scaling.get("chaos", 0.2)) * 0.035
	var corruption_gain: float = 0.0

	if bool(payload.get("reckless", false)):
		corruption_gain += chaos_gain

	row ["fatigue"] = clamp(float(row.get("fatigue", 0.0)) + fatigue_cost, 0.0, 1.0)
	row ["corruption"] = clamp(float(row.get("corruption", 0.0)) + corruption_gain, 0.0, 1.0)

	power_state ["fatigue"] = clamp(float(power_state.get("fatigue", 0.0)) + fatigue_cost, 0.0, 1.0)
	power_state ["corruption"] = clamp(float(power_state.get("corruption", 0.0)) + corruption_gain, 0.0, 1.0)

	powers [power_id] = row
	power_state ["powers"] = powers
	person_states [key] = power_state
	state ["person_power_state"] = person_states

	var report: Dictionary = {
		"success": true,
		"schema": "eralife.power_activation_report",
		"person_id": int(actor.id),
		"person_name": _person_label(actor),
		"power_id": power_id,
		"display_name": str(contract.get("display_name", power_id.capitalize())),
		"effects": _safe_array(contract.get("effects", [])),
		"fatigue_cost": fatigue_cost,
		"corruption_gain": corruption_gain,
		"text": _activation_text(actor, contract, payload),
		"created_year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	_record_power_event(report)
	_commit_world_state(state)
	return report

func attempt_origin_event(actor: Person, payload: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "Actor missing."
		}

	if not _mode_allows_powers():
		return {
			"success": false,
			"reason": "Origin events are only allowed in Chaos/Fantasy mode or with superpowers enabled."
		}

	var origin_id: String = str(payload.get("origin_id", payload.get("origin", ""))).strip_edges().to_lower()
	if origin_id == "":
		origin_id = "particle_accelerator_explosion"

	var origin: Dictionary = _safe_dictionary(origin_registry.get(origin_id, {}))
	if origin.is_empty():
		return {
			"success": false,
			"reason": "Origin contract not found.",
			"origin_id": origin_id
		}

	var chance: float = float(origin.get("success_chance", 0.5))
	var roll: float = randf()
	if roll > chance:
		var fail_report: Dictionary = {
			"success": false,
			"origin_id": origin_id,
			"roll": roll,
			"chance": chance,
			"text": str(origin.get("failure_text", "The origin event changes nothing obvious... yet."))
		}
		_record_power_event(fail_report)
		return fail_report

	var pool: Array = _safe_array(origin.get("power_pool", []))
	if pool.is_empty():
		pool = ["super_strength"]

	var power_id: String = _weighted_power_pick(pool)
	var grant_report: Dictionary = grant_power(actor, power_id, origin_id, {
		"origin": origin_id,
		"visibility": str(origin.get("visibility", "unknown")),
		"inherited": false
	})

	grant_report ["origin_text"] = str(origin.get("success_text", "Power wakes up inside you."))
	return grant_report
func resolve_elemental_mutation_contract_packet(actor: Person, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "Actor missing."
		}

	var power_state: Dictionary = ensure_person_power_state(actor)
	var powers: Dictionary = _safe_dictionary(power_state.get("powers", {}))
	var elements: Array = _actor_mutation_elements(actor)

	if powers.is_empty() or elements.is_empty():
		return {
			"success": false,
			"reason": "Mutation contract requires at least one active power and one bending element.",
			"person_id": int(actor.id),
			"power_count": powers.size(),
			"element_count": elements.size()
		}

	var mutated_abilities: Dictionary = {}
	var packets: Dictionary = {}

	for raw_power_id in powers.keys():
		var power_id: String = str(raw_power_id).strip_edges().to_lower()
		if power_id == "":
			continue

		var power_row: Dictionary = _safe_dictionary(powers.get(raw_power_id, {}))
		var power_contract: Dictionary = get_power_contract(power_id)
		if power_contract.is_empty():
			continue

		for raw_element in elements:
			var element: String = str(raw_element).strip_edges().to_lower()
			if element == "":
				continue

			var mutation_id: String = "mutation_%s_%s" % [element, power_id]
			var ability_packet: Dictionary = _build_elemental_mutation_ability_packet(
				actor,
				element,
				power_id,
				power_row,
				power_contract,
				context
			)

			if ability_packet.is_empty():
				continue

			mutated_abilities [mutation_id] = ability_packet.duplicate(true)
			packets [mutation_id] = {
				"schema": "eralife.elemental_power_mutation_contract_packet",
				"version": CONTRACT_VERSION,
				"id": mutation_id,
				"person_id": int(actor.id),
				"person_name": _person_label(actor),
				"element": element,
				"power_id": power_id,
				"power_display_name": str(power_contract.get("display_name", power_id.capitalize())),
				"ability": ability_packet.duplicate(true),
				"composition_stack": [
					"power_engine",
					"hybridization_engine",
					"bending_affinity_layer",
					"scaling_engine",
					"power_expression_router"
				],
				"source": str(context.get("source", "elemental_mutation_sync")),
				"created_year": _current_year(),
				"created_at_ms": int(Time.get_ticks_msec())
			}

	var state: Dictionary = _world_state()
	var person_states: Dictionary = _safe_dictionary(state.get("person_power_state", {}))
	var key: String = _person_key(actor)
	power_state = ensure_person_power_state(actor)

	power_state ["mutated_abilities"] = mutated_abilities.duplicate(true)
	power_state ["mutation_contract_packets"] = packets.duplicate(true)
	power_state ["last_mutation_sync"] = {
		"success": true,
		"ability_count": mutated_abilities.size(),
		"power_count": powers.size(),
		"element_count": elements.size(),
		"source": str(context.get("source", "elemental_mutation_sync")),
		"updated_year": _current_year(),
		"updated_at_ms": int(Time.get_ticks_msec())
	}

	person_states [key] = power_state.duplicate(true)
	state ["person_power_state"] = person_states
	_commit_world_state(state)

	return {
		"success": true,
		"schema": "eralife.elemental_power_mutation_sync_report",
		"version": CONTRACT_VERSION,
		"person_id": int(actor.id),
		"person_name": _person_label(actor),
		"ability_count": mutated_abilities.size(),
		"mutated_abilities": mutated_abilities.duplicate(true),
		"mutation_contract_packets": packets.duplicate(true)
	}


func get_mutated_ability_rows(actor: Person, context: Dictionary = {}) -> Array:
	if actor == null:
		return []

	var sync_report: Dictionary = resolve_elemental_mutation_contract_packet(actor, {
		"source": str(context.get("source", "get_mutated_ability_rows")),
		"persist": true
	})
	if not bool(sync_report.get("success", false)):
		return []

	var mutated: Dictionary = _safe_dictionary(sync_report.get("mutated_abilities", {}))
	var out: Array = []

	for raw_key in mutated.keys():
		var row: Dictionary = _safe_dictionary(mutated.get(raw_key, {}))
		if row.is_empty():
			continue

		var unlocked_count: int = int(row.get("unlocked_bending_ability_count", 0))
		row ["intentional_use_locked"] = unlocked_count <= 0
		row ["intentional_use_lock_reason"] = "Unlock at least one bending move before intentionally using this mutation." if unlocked_count <= 0 else ""
		row ["uncontrolled_age_up_risk"] = unlocked_count <= 0 or float(row.get("chaos", 0.0)) >= 0.35

		out.append(row.duplicate(true))

	out.sort_custom(func (a, b): return int(a.get("power", 0)) > int(b.get("power", 0)))
	return out


func activate_mutated_ability(actor: Person, payload: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "Actor missing."
		}

	var mutation_id: String = str(payload.get("mutation_id", payload.get("ability_id", ""))).strip_edges().to_lower()
	var rows: Array = get_mutated_ability_rows(actor, {
		"source": "activate_mutated_ability"
	})

	var selected: Dictionary = {}
	for raw_row in rows:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = raw_row
		if str(row.get("id", "")).strip_edges().to_lower() == mutation_id:
			selected = row.duplicate(true)
			break

	if selected.is_empty() and not rows.is_empty():
		selected = rows [0].duplicate(true)

	if selected.is_empty():
		return {
			"success": false,
			"reason": "No mutated ability is available."
		}

	if bool(selected.get("intentional_use_locked", false)):
		return {
			"success": false,
			"schema": "eralife.elemental_power_mutation_activation_blocked",
			"version": CONTRACT_VERSION,
			"reason": str(selected.get("intentional_use_lock_reason", "Unlock at least one bending move before intentionally using this mutation.")),
			"mutation_id": str(selected.get("id", "")),
			"display_name": str(selected.get("display_name", selected.get("label", "Mutated Ability"))),
			"popup_title": "Mutation Locked",
			"popup_text": "This mutation exists in your body, but you cannot intentionally use it yet.\n\nUnlock at least one bending move first.\n\nIt can still erupt through uncontrolled age-up surge logic if the mutation remains unstable.",
			"popup_footer": "Controlled mutation requires a trained channel."
		}

	var state: Dictionary = _world_state()
	var person_states: Dictionary = _safe_dictionary(state.get("person_power_state", {}))
	var key: String = _person_key(actor)
	var power_state: Dictionary = ensure_person_power_state(actor)
	var fatigue_gain: float = clamp(float(selected.get("fatigue_cost", 0.04)), 0.0, 0.35)

	power_state ["fatigue"] = clamp(float(power_state.get("fatigue", 0.0)) + fatigue_gain, 0.0, 1.0)
	power_state ["updated_year"] = _current_year()

	var target_report: Dictionary = _resolve_power_target_interaction(actor, payload, selected, {
		"source_type": "mutation",
		"display_name": str(selected.get("display_name", selected.get("label", "Mutated Ability"))),
		"base_power": int(selected.get("power", 0)),
		"base_guard": int(selected.get("guard", 0))
	})

	for raw_key in _safe_dictionary(target_report.get("power_state_patch", {})).keys():
		power_state [raw_key] = _safe_dictionary(target_report.get("power_state_patch", {})).get(raw_key)

	person_states [key] = power_state.duplicate(true)
	state ["person_power_state"] = person_states
	_commit_world_state(state)

	var text: String = "I used %s. My bending and mutation answered as one." % str(selected.get("display_name", selected.get("label", "a mutated ability")))
	if not target_report.is_empty():
		text = str(target_report.get("text", text))

	var report: Dictionary = {
		"success": true,
		"schema": "eralife.elemental_power_mutation_activation_report",
		"version": CONTRACT_VERSION,
		"person_id": int(actor.id),
		"person_name": _person_label(actor),
		"mutation_id": str(selected.get("id", "")),
		"display_name": str(selected.get("display_name", selected.get("label", "Mutated Ability"))),
		"element": str(selected.get("element", "")),
		"power_id": str(selected.get("power_id", "")),
		"power": int(selected.get("power", 0)),
		"guard": int(selected.get("guard", 0)),
		"fatigue_gain": fatigue_gain,
		"target_interaction": target_report.duplicate(true),
		"text": text,
		"popup_title": "Mutation Used",
		"popup_text": text,
		"popup_footer": "Mutation use is now routed through targeted consequence packets.",
		"created_year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	_record_power_event(report)
	return report
func _resolve_power_target_interaction(actor: Person, payload: Dictionary, source_packet: Dictionary, context: Dictionary = {}) -> Dictionary:
	var target_id: int = int(payload.get("target_person_id", -1))
	if target_id <= 0:
		if bool(payload.get("public_usage", false)):
			return _resolve_public_power_exposure(actor, payload, source_packet, context)
		return {}

	var target: Person = _person_by_id(target_id)
	if target == null:
		return {
			"success": false,
			"reason": "Target missing.",
			"target_person_id": target_id
		}

	var use_mode: String = str(payload.get("use_mode", "warn_target")).strip_edges().to_lower()
	var display_name: String = str(context.get("display_name", source_packet.get("display_name", source_packet.get("label", "Power"))))
	var actor_rating: int = max(1, get_power_rating(actor))
	var target_rating: int = 0
	if has_superpowers(target):
		target_rating = max(1, get_power_rating(target))

	var target_is_powered: bool = target_rating > 0
	var target_can_counter: bool = target_is_powered and target_rating >= int(float(actor_rating) * 0.72)
	var target_overwhelms_actor: bool = target_is_powered and target_rating >= int(float(actor_rating) * 1.85)

	var intensity: float = clamp(float(payload.get("target_intensity", 0.35)), 0.05, 1.0)
	var health_delta: int = 0
	var happiness_delta: int = 0
	var mental_delta: int = 0
	var relationship_delta: int = int(payload.get("relationship_delta", -4))
	var death: bool = false
	var defended: bool = false
	var countered: bool = false

	match use_mode:
		"protect_target":
			health_delta = int(round(8.0 + float(actor_rating) / 2400.0))
			happiness_delta = 8
			mental_delta = 4
			relationship_delta = int(payload.get("relationship_delta", 8))
		"warn_target":
			happiness_delta = - int(round(4.0 + intensity * 8.0))
			mental_delta = - int(round(3.0 + intensity * 6.0))
		"stun_target":
			health_delta = - int(round(6.0 + intensity * 22.0 + float(actor_rating) / 4200.0))
			happiness_delta = -14
			mental_delta = -8
		"full_attack_target":
			health_delta = - int(round(18.0 + intensity * 65.0 + float(actor_rating) / 900.0))
			happiness_delta = -35
			mental_delta = -28
			relationship_delta = int(payload.get("relationship_delta", -35))
		_:
			happiness_delta = -4
			mental_delta = -2

	if target_overwhelms_actor:
		defended = true
		countered = true
		health_delta = int(round(float(health_delta) * 0.08))
		happiness_delta = int(round(float(happiness_delta) * 0.25))
		mental_delta = int(round(float(mental_delta) * 0.25))
	elif target_can_counter:
		defended = true
		health_delta = int(round(float(health_delta) * 0.45))
		happiness_delta = int(round(float(happiness_delta) * 0.65))
		mental_delta = int(round(float(mental_delta) * 0.65))

	if use_mode == "full_attack_target" and not target_is_powered and actor_rating >= 1000000000:
		health_delta = -9999
		death = true

	target.health = clamp(int(target.health) + health_delta, 0, 200)
	target.satisfaction = clamp(int(target.satisfaction) + happiness_delta, 0, 100)
	target.mental_health = clamp(int(target.mental_health) + mental_delta, 0, 100)

	if int(target.health) <= 0:
		death = true

	if death:
		target.alive = false
		target.health = 0

	if gs != null and gs.relationship_engine != null and gs.relationship_engine.has_method("adjust_relationship"):
		gs.relationship_engine.adjust_relationship(actor, target, relationship_delta)

	if gs != null and gs.memory_engine != null and gs.memory_engine.has_method("remember"):
		gs.memory_engine.remember(int(target.id), "%s used %s on me. I remember what happened." % [_person_label(actor), display_name])
		gs.memory_engine.remember(int(actor.id), "I used %s on %s." % [display_name, _person_label(target)])

	var public_patch: Dictionary = {}
	if bool(payload.get("public_usage", false)) or death or use_mode == "full_attack_target":
		public_patch = {
			"public_power_known": true,
			"public_visibility": "exposed",
			"hidden_identity_risk": 1.0
		}

	var outcome_text: String = "%s used %s on %s." % [
		_person_label(actor),
		display_name,
		_person_label(target)
	]

	if defended and countered:
		outcome_text += " %s was powerful enough to counter the attempt." % _person_label(target)
	elif defended:
		outcome_text += " %s defended against part of it." % _person_label(target)

	if death:
		outcome_text += " %s did not survive." % _person_label(target)

	return {
		"success": true,
		"schema": "eralife.power_target_interaction_report",
		"version": CONTRACT_VERSION,
		"actor_id": int(actor.id),
		"actor_name": _person_label(actor),
		"target_id": int(target.id),
		"target_name": _person_label(target),
		"use_mode": use_mode,
		"source_type": str(context.get("source_type", "power")),
		"display_name": display_name,
		"actor_power_rating": actor_rating,
		"target_power_rating": target_rating,
		"target_is_powered": target_is_powered,
		"defended": defended,
		"countered": countered,
		"death": death,
		"health_delta": health_delta,
		"happiness_delta": happiness_delta,
		"mental_delta": mental_delta,
		"relationship_delta": relationship_delta,
		"power_state_patch": public_patch,
		"text": outcome_text
	}


func _resolve_public_power_exposure(actor: Person, payload: Dictionary, source_packet: Dictionary, context: Dictionary = {}) -> Dictionary:
	var display_name: String = str(context.get("display_name", source_packet.get("display_name", source_packet.get("label", "Power"))))
	var reckless: bool = bool(payload.get("reckless", false))
	var patch: Dictionary = {
		"public_power_known": true,
		"public_visibility": "rumored" if not reckless else "exposed",
		"hidden_identity_risk": 0.55 if not reckless else 1.0
	}

	var text: String = "%s used %s publicly. People are starting to ask if the rumors are true." % [
		_person_label(actor),
		display_name
	]
	if reckless:
		text = "%s unleashed %s in public. The secret is cracking fast." % [
			_person_label(actor),
			display_name
		]

	return {
		"success": true,
		"schema": "eralife.public_power_exposure_report",
		"version": CONTRACT_VERSION,
		"actor_id": int(actor.id),
		"actor_name": _person_label(actor),
		"display_name": display_name,
		"reckless": reckless,
		"power_state_patch": patch,
		"text": text
	}

func get_reality_fusion_duel_actions(actor: Person, context: Dictionary = {}) -> Array:
	var rows: Array = get_mutated_ability_rows(actor, context)
	var out: Array = []

	for raw_row in rows:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = raw_row.duplicate(true)
		row ["id"] = "reality_fusion_mutation_%s" % str(row.get("id", "mutation")).replace(" ", "_")
		row ["label"] = "Use %s" % str(row.get("display_name", row.get("label", "Mutated Ability")))
		row ["journal_text"] = "I used %s during a Reality Fusion duel." % str(row.get("display_name", "a mutated ability"))
		row ["choice_family"] = str(row.get("choice_family", "attack"))
		row ["power_source"] = "mutated_ability"
		row ["button_theme"] = "superpower_action"
		row ["reality_fusion_ally_duel_choice"] = true
		row ["disabled"] = false
		out.append(row)

	return out


func _build_elemental_mutation_ability_packet(
	actor: Person,
	element: String,
	power_id: String,
	power_row: Dictionary,
	power_contract: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	var clean_element: String = str(element).strip_edges().to_lower()
	var clean_power_id: String = str(power_id).strip_edges().to_lower()
	if clean_element == "" or clean_power_id == "":
		return {}

	var bending_level: int = _bending_level_for_mutation(actor, clean_element)
	var unlocked_count: int = _unlocked_bending_ability_count(actor, clean_element)
	var power_level: int = max(1, int(power_row.get("level", power_contract.get("starting_level", 1))))
	var control: float = clamp(float(power_row.get("control", _safe_dictionary(power_contract.get("scaling", {})).get("control", 0.2))), 0.0, 1.0)
	var chaos: float = clamp(float(power_row.get("chaos", _safe_dictionary(power_contract.get("scaling", {})).get("chaos", 0.2))), 0.0, 1.0)
	var unlock_multiplier: float = 1.0 + (float(unlocked_count) * 0.08)

	var body_score: float = (
		float(actor.health) * 0.16 +
		float(actor.mental_health) * 0.1 +
		float(actor.smarts) * 0.08 +
		float(actor.imagination) * 0.12
	)

	var base_power: int = int(round(
		12.0 +
		float(bending_level) * 0.42 +
		float(power_level) * 9.0 +
		control * 30.0 +
		chaos * 12.0 +
		body_score
	))

	var scaled_power: int = int(round(float(base_power) * unlock_multiplier))
	var guard_value: int = int(round(
		8.0 +
		float(bending_level) * 0.28 +
		float(power_level) * 5.0 +
		control * 22.0 +
		float(actor.health) * 0.08
	))

	var family: String = _elemental_mutation_choice_family(clean_element, clean_power_id)
	var source_power_name: String = _life_stage_power_display_name(
		actor,
		clean_power_id,
		str(power_contract.get("display_name", clean_power_id.capitalize())),
		power_row
	)
	var display_name: String = _power_mutation_display_name(actor, clean_element, clean_power_id, power_contract, power_row)

	return {
		"schema": "eralife.elemental_power_mutation_ability",
		"version": CONTRACT_VERSION,
		"id": "mutation_%s_%s" % [clean_element, clean_power_id],
		"display_name": display_name,
		"label": display_name,
		"element": clean_element,
		"power_id": clean_power_id,
		"power_display_name": source_power_name,
		"choice_family": family,
		"power_source": "mutated_ability",
		"button_theme": "superpower_action",
		"ability_type": "defense" if family == "defend" else "attack",
		"ability_level": bending_level,
		"bending_level": bending_level,
		"unlocked_bending_ability_count": unlocked_count,
		"power_level": power_level,
		"control": control,
		"chaos": chaos,
		"life_stage": _actor_life_stage_key(actor),
		"mastery_tier": _power_mastery_tier(power_row),
		"power": max(1, scaled_power),
		"guard": max(0, guard_value),
		"fatigue_cost": clamp(0.025 + chaos * 0.045, 0.025, 0.14),
		"journal_text": "I used %s, letting my %s bending and %s mutation overlap." % [
			display_name,
			clean_element,
			source_power_name
		],
		"can_use_in_bending_duels": true,
		"can_use_in_nidavellir": true,
		"source": str(context.get("source", "elemental_mutation_packet"))
	}


func _actor_mutation_elements(actor: Person) -> Array:
	var out: Array = []
	if actor == null:
		return out

	var bending_type: String = str(actor.bending_type).strip_edges().to_lower()
	if bending_type == "avatar":
		return ["air", "water", "earth", "fire"]

	if bending_type in ["air", "water", "earth", "fire"]:
		out.append(bending_type)
		return out

	if typeof(actor.bending_mastery) == TYPE_DICTIONARY:
		for raw_element in actor.bending_mastery.keys():
			var element: String = str(raw_element).strip_edges().to_lower()
			if element in ["air", "water", "earth", "fire"] and element not in out:
				out.append(element)

	return out


func _bending_level_for_mutation(actor: Person, element: String) -> int:
	if actor == null:
		return 0

	var clean_element: String = str(element).strip_edges().to_lower()
	if clean_element == "":
		return 0

	if gs != null and gs.bending_engine != null and gs.bending_engine.has_method("get_bending_level"):
		return int(gs.bending_engine.get_bending_level(actor, clean_element))

	if typeof(actor.bending_mastery) == TYPE_DICTIONARY:
		return int(actor.bending_mastery.get(clean_element, 0))

	return 0


func _unlocked_bending_ability_count(actor: Person, element: String) -> int:
	if actor == null or gs == null or gs.bending_engine == null:
		return 0

	if not gs.bending_engine.has_method("get_available_bending_abilities"):
		return 0

	var clean_element: String = str(element).strip_edges().to_lower()
	var count: int = 0

	for raw_ability in gs.bending_engine.get_available_bending_abilities(actor):
		if typeof(raw_ability) != TYPE_DICTIONARY:
			continue

		var ability: Dictionary = raw_ability
		if str(ability.get("element", "")).strip_edges().to_lower() != clean_element:
			continue
		if bool(ability.get("unlocked", false)):
			count += 1

	return count


func _elemental_mutation_choice_family(element: String, power_id: String) -> String:
	var clean_power_id: String = str(power_id).strip_edges().to_lower()
	if clean_power_id in ["adamantium_skeleton", "super_serum"]:
		return "defend"
	if clean_power_id in ["super_speed", "spider_abilities"]:
		return "attack"
	if clean_power_id == "telepathy":
		return "read"

	var clean_element: String = str(element).strip_edges().to_lower()
	if clean_element in ["earth", "water"] and clean_power_id == "infant_chaos_polymorph":
		return "defend"

	return "attack"


func _power_mutation_display_name(actor: Person, element: String, power_id: String, power_contract: Dictionary, power_row: Dictionary = {}) -> String:
	var clean_element: String = str(element).strip_edges().to_lower()
	var clean_power_id: String = str(power_id).strip_edges().to_lower()
	var power_name: String = str(power_contract.get("display_name", clean_power_id.capitalize())).strip_edges()
	var stage: String = _actor_life_stage_key(actor)
	var mastery: String = _power_mastery_tier(power_row)
	var mastered: bool = mastery in ["mastered", "legendary", "reality_break"]

	if clean_power_id == "infant_chaos_polymorph":
		var chaos_names: Dictionary = {
			"infant": {
				"fire": "Polymorph Ember Tantrum",
				"water": "Crib-Tide Polymorph",
				"earth": "Tiny Stonebody Shift",
				"air": "Blinking Airbaby Burst"
			},
			"toddler": {
				"fire": "Toddler Ember Morph",
				"water": "Toddler Tide Wobble",
				"earth": "Pebblebody Polymorph",
				"air": "Airblink Toddler Burst"
			},
			"child": {
				"fire": "Young Ember Polymorph",
				"water": "Rippleform Polymorph",
				"earth": "Stonebody Shift",
				"air": "Airblink Burst"
			},
			"teen": {
				"fire": "Volatile Ember Polymorph",
				"water": "Tideform Chaos Shift",
				"earth": "Granitebody Polymorph",
				"air": "Airstep Chaos Burst"
			},
			"adult": {
				"fire": "Polymorph Ember Blast",
				"water": "Tidal Polymorph Flow",
				"earth": "Polymorph Stonebody Shift",
				"air": "Airblink Polymorph Burst"
			},
			"elder": {
				"fire": "Elder Ember Reality-Shed",
				"water": "Ancient Tideform Polymorph",
				"earth": "Elder Mountainbody Shift",
				"air": "Elder Skyblink Polymorph"
			}
		}

		if mastered:
			match clean_element:
				"fire":
					return "Mastered Ember Reality Polymorph"
				"water":
					return "Mastered Tide Reality Polymorph"
				"earth":
					return "Mastered Stone Reality Polymorph"
				"air":
					return "Mastered Sky Reality Polymorph"

		var stage_rows: Dictionary = _safe_dictionary(chaos_names.get(stage, chaos_names.get("adult", {})))
		if stage_rows.has(clean_element):
			return str(stage_rows.get(clean_element))

	if clean_power_id == "probability_manipulation":
		match clean_element:
			"fire":
				return _stage_mutation_name(stage, mastered, "Impossible Ember Outcome")
			"water":
				return _stage_mutation_name(stage, mastered, "Lucky Tide Redirect")
			"earth":
				return _stage_mutation_name(stage, mastered, "Fated Stone Wall")
			"air":
				return _stage_mutation_name(stage, mastered, "Uncaught Airstep")

	if clean_power_id == "spider_abilities":
		match clean_element:
			"fire":
				return _stage_mutation_name(stage, mastered, "Webbed Ember Snare")
			"water":
				return _stage_mutation_name(stage, mastered, "Ripple Web Bind")
			"earth":
				return _stage_mutation_name(stage, mastered, "Stone-Wall Crawl")
			"air":
				return _stage_mutation_name(stage, mastered, "Airborne Spider Sense")

	return _stage_mutation_name(stage, mastered, "%s %s Mutation" % [
		clean_element.capitalize(),
		power_name
	])
func _refresh_life_stage_power_names(actor: Person, power_state: Dictionary) -> Dictionary:
	var out: Dictionary = power_state.duplicate(true)
	var powers: Dictionary = _safe_dictionary(out.get("powers", {}))
	var power_names_changed: bool = false

	for raw_power_id in powers.keys():
		var power_id: String = str(raw_power_id).strip_edges().to_lower()
		var row: Dictionary = _safe_dictionary(powers.get(raw_power_id, {}))
		if row.is_empty():
			continue

		var contract: Dictionary = get_power_contract(power_id)
		var base_name: String = str(contract.get("display_name", row.get("display_name", power_id.replace("_", " ").capitalize())))
		var staged_name: String = _life_stage_power_display_name(actor, power_id, base_name, row)

		row ["base_display_name"] = base_name
		row ["display_name"] = staged_name
		row ["life_stage"] = _actor_life_stage_key(actor)
		row ["mastery_tier"] = _power_mastery_tier(row)

		powers [power_id] = row.duplicate(true)
		power_names_changed = true

	if power_names_changed:
		out ["powers"] = powers
		out ["updated_year"] = _current_year()

	return out


func _life_stage_power_display_name(actor: Person, power_id: String, base_name: String, power_row: Dictionary = {}) -> String:
	var clean_power_id: String = str(power_id).strip_edges().to_lower()
	var clean_base: String = str(base_name).strip_edges()
	if clean_base == "":
		clean_base = clean_power_id.replace("_", " ").capitalize()

	var stage: String = _actor_life_stage_key(actor)
	var mastery: String = _power_mastery_tier(power_row)
	var mastered: bool = mastery in ["mastered", "legendary", "reality_break"]

	if clean_power_id == "infant_chaos_polymorph":
		if mastered:
			match stage:
				"elder":
					return "Elder Reality-Mastered Chaos Polymorph"
				"adult":
					return "Reality-Mastered Chaos Polymorph"
				"teen":
					return "Prodigy Chaos Polymorph"
				_:
					return "Impossible Chaos Polymorph"

		match stage:
			"infant":
				return "Infant Chaos Polymorph"
			"toddler":
				return "Toddler Chaos Polymorph"
			"child":
				return "Child Chaos Polymorph"
			"teen":
				return "Teen Chaos Polymorph"
			"adult":
				return "Chaos Polymorph"
			"elder":
				return "Elder Chaos Polymorph"

	if mastered:
		match stage:
			"elder":
				return "Elder Mastered %s" % clean_base
			"adult":
				return "Mastered %s" % clean_base
			"teen":
				return "Prodigy %s" % clean_base
			_:
				return "Awakened %s" % clean_base

	match stage:
		"infant":
			return "Infant %s" % clean_base
		"toddler":
			return "Toddler %s" % clean_base
		"child":
			return "Young %s" % clean_base
		"teen":
			return "Emerging %s" % clean_base
		"elder":
			return "Elder %s" % clean_base
		_:
			return clean_base


func _stage_mutation_name(stage: String, mastered: bool, base_name: String) -> String:
	var clean_base: String = str(base_name).strip_edges()
	if mastered:
		match stage:
			"elder":
				return "Elder Mastered %s" % clean_base
			"adult":
				return "Mastered %s" % clean_base
			"teen":
				return "Prodigy %s" % clean_base
			_:
				return "Awakened %s" % clean_base

	match str(stage).strip_edges().to_lower():
		"infant":
			return "Infant %s" % clean_base
		"toddler":
			return "Toddler %s" % clean_base
		"child":
			return "Young %s" % clean_base
		"teen":
			return "Teen %s" % clean_base
		"elder":
			return "Elder %s" % clean_base
		_:
			return clean_base


func _actor_life_stage_key(actor: Person) -> String:
	if actor == null:
		return "adult"

	var age_value: int = int(actor.get("age"))

	if age_value <= 1:
		return "infant"
	if age_value <= 3:
		return "toddler"
	if age_value <= 12:
		return "child"
	if age_value <= 17:
		return "teen"
	if age_value >= 65:
		return "elder"

	return "adult"


func _power_mastery_tier(power_row: Dictionary) -> String:
	var level: int = int(power_row.get("level", 1))
	var control: float = float(power_row.get("control", 0.0))
	var chaos: float = float(power_row.get("chaos", 0.0))
	var base_power: int = int(power_row.get("base_power_level", 0))
	var latent_potential: int = int(power_row.get("latent_potential", 0))

	if level >= 80 or base_power >= 1000000000000 or latent_potential >= 1000000000000:
		return "reality_break"
	if level >= 50 or control >= 0.92:
		return "legendary"
	if level >= 25 or control >= 0.72:
		return "mastered"
	if level >= 10 or control >= 0.45:
		return "trained"
	if chaos >= 0.7:
		return "unstable"

	return "raw"
func get_power_rating(actor: Person) -> int:
	if actor == null:
		return 0

	var total: float = 0.0

	var power_state: Dictionary = ensure_person_power_state(actor)
	var powers: Dictionary = _safe_dictionary(power_state.get("powers", {}))

	for raw_key in powers.keys():
		var power_id: String = str(raw_key).strip_edges().to_lower()
		var row: Dictionary = _safe_dictionary(powers.get(raw_key, {}))
		var contract: Dictionary = get_power_contract(power_id)
		var rarity_id: String = str(row.get("rarity", contract.get("rarity", "common"))).strip_edges().to_lower()
		var rarity_profile: Dictionary = _safe_dictionary(row.get("rarity_profile", {}))
		if rarity_profile.is_empty():
			rarity_profile = _superpower_rarity_profile(rarity_id)

		var rarity_weight: int = _rarity_weight(rarity_id)
		var base_power_level: float = float(row.get("base_power_level", rarity_profile.get("base_power_level", 0)))
		var latent_potential: float = max(base_power_level, float(row.get("latent_potential", rarity_profile.get("latent_potential", base_power_level))))
		var training_level: float = float(row.get("level", 1))
		var control: float = clamp(float(row.get("control", 0.0)), 0.0, 1.5)
		var chaos: float = clamp(float(row.get("chaos", 0.0)), 0.0, 1.5)

		var row_rating: float = 0.0
		row_rating += base_power_level
		row_rating += training_level * max(250.0, base_power_level * 0.025)
		row_rating += control * max(500.0, base_power_level * 0.12)
		row_rating += chaos * max(120.0, base_power_level * 0.035)
		row_rating += float(rarity_weight) * max(100.0, base_power_level * 0.008)
		row_rating += max(0.0, latent_potential - base_power_level) * 0.015

		if bool(row.get("bending_power_source", false)):
			row_rating += max(1000.0, base_power_level * 0.08)

		if bool(row.get("suppressed", false)):
			row_rating *= 0.2
		elif bool(row.get("latent_locked", false)):
			row_rating *= 0.86

		total += row_rating

	total -= float(power_state.get("fatigue", 0.0)) * max(1000.0, total * 0.035)
	total -= float(power_state.get("corruption", 0.0)) * max(500.0, total * 0.012)

	if gs != null and "dragonballs_engine" in gs and gs.dragonballs_engine != null:
		if gs.dragonballs_engine.has_method("get_saiyan_power_modifier_packet"):
			var modifier_packet: Dictionary = gs.dragonballs_engine.get_saiyan_power_modifier_packet(actor, {
				"source": "power_engine.get_power_rating"
			})
			total += float(modifier_packet.get("flat_bonus", 0.0))
			total *= max(1.0, float(modifier_packet.get("power_multiplier", 1.0)))

	return int(clamp(round(total), 0, 9000000000000000000))

func get_power_overview_rows(context: Dictionary = {}) -> Array:
	var actor: Person = _context_actor(context)
	if actor == null:
		return []

	var power_state: Dictionary = ensure_person_power_state(actor)
	var powers: Dictionary = _safe_dictionary(power_state.get("powers", {}))
	var out: Array = []

	out.append({
		"label": "Power Rating: %d • Fatigue %d%% • Corruption %d%%" % [
			get_power_rating(actor),
			int(round(float(power_state.get("fatigue", 0.0)) * 100.0)),
			int(round(float(power_state.get("corruption", 0.0)) * 100.0))
		]
	})

	if powers.is_empty():
		out.append({
			"label": "Dormant Human",
			"description": "You do not have active powers yet. In Chaos/Fantasy mode, powers can come from birth, mutation, serum, surgery, experiments, or catastrophic origin events."
		})
		return out

	for raw_power_id in powers.keys():
		var power_id: String = str(raw_power_id)
		var row: Dictionary = _safe_dictionary(powers.get(power_id, {}))
		out.append({
			"label": "%s • Lvl %d • Control %d%%" % [
				str(row.get("display_name", power_id.capitalize())),
				int(row.get("level", 1)),
				int(round(float(row.get("control", 0.0)) * 100.0))
			],
			"description": "Rarity: %s • Fatigue: %d%% • Corruption: %d%%" % [
				str(row.get("rarity", "common")).capitalize(),
				int(round(float(row.get("fatigue", 0.0)) * 100.0)),
				int(round(float(row.get("corruption", 0.0)) * 100.0))
			],
			"actions": [
				{
					"id": "power_train_%s" % power_id,
					"label": "Train %s" % str(row.get("display_name", power_id.capitalize())),
					"kind": "engine_call",
					"engine_property": "power_engine",
					"method": "resolve_power_action",
					"call_mode": "player_payload",
					"payload": {
						"action": "train",
						"power_id": power_id
					},
					"refresh_after": true
				},
				{
					"id": "power_activate_%s" % power_id,
					"label": "Use %s" % str(row.get("display_name", power_id.capitalize())),
					"kind": "engine_call",
					"engine_property": "power_engine",
					"method": "resolve_power_action",
					"call_mode": "player_payload",
					"payload": {
						"action": "activate",
						"power_id": power_id
					},
					"refresh_after": true
				}
			]
		})

	var mutation_rows: Array = get_mutated_ability_rows(actor, {
		"source": "power_overview"
	})
	if not mutation_rows.is_empty():
		out.append({
			"label": "Mutated Abilities",
			"description": "Your bending and superpower contracts are overlapping. These scale as your bending techniques unlock."
		})

		for raw_mutation in mutation_rows:
			if typeof(raw_mutation) != TYPE_DICTIONARY:
				continue

			var mutation: Dictionary = raw_mutation
			out.append({
				"label": "%s • Power %d • Guard %d" % [
					str(mutation.get("display_name", mutation.get("label", "Mutation"))),
					int(mutation.get("power", 0)),
					int(mutation.get("guard", 0))
				],
				"description": "%s mutation from %s • unlocked bending moves: %d" % [
					str(mutation.get("element", "elemental")).capitalize(),
					str(mutation.get("power_display_name", mutation.get("power_id", "power"))),
					int(mutation.get("unlocked_bending_ability_count", 0))
				],
				"actions": [
					{
						"id": "activate_%s" % str(mutation.get("id", "mutation")),
						"label": "Use %s" % str(mutation.get("display_name", "Mutation")),
						"kind": "engine_call",
						"engine_property": "power_engine",
						"method": "resolve_power_action",
						"call_mode": "player_payload",
						"payload": {
							"action": "activate_mutation",
							"mutation_id": str(mutation.get("id", ""))
						},
						"refresh_after": true
					}
				]
			})

	return out

func get_power_training_rows(context: Dictionary = {}) -> Array:
	var actor: Person = _context_actor(context)
	if actor == null:
		return []

	var power_state: Dictionary = ensure_person_power_state(actor)
	var powers: Dictionary = _safe_dictionary(power_state.get("powers", {}))
	var power_stats: Dictionary = _safe_dictionary(power_state.get("power_stats", {}))
	var rows: Array = []

	rows.append({
		"id": "training_rule",
		"label": "Training Contract",
		"description": "Training can fail. Willpower, fatigue, control, and chosen focus decide the outcome.",
		"overview_title": "Training Contract",
		"overview_lines": [
			"Training is no longer a generic button.",
			"Choose a base power, supe stat, or subskill focus.",
			"Success improves the selected layer and can still improve the base power.",
			"Failure adds fatigue and can delay progression."
		],
		"hide_overview_button": false
	})

	for raw_power_id in powers.keys():
		var power_id: String = str(raw_power_id).strip_edges().to_lower()
		if power_id == "":
			continue

		var power_row: Dictionary = _safe_dictionary(powers.get(raw_power_id, {}))
		var display_name: String = str(power_row.get("display_name", power_id.replace("_", " ").capitalize()))

		rows.append({
			"id": "train_power_%s" % power_id,
			"label": "Train Base Power • %s" % display_name,
			"description": "Improves XP/control for this power. May grant skill points on level-up.",
			"overview_title": "Train %s" % display_name,
			"overview_lines": [
				"Training Focus: Base Power",
				"Power: %s" % display_name,
				"Current Level: %d" % int(power_row.get("level", 1)),
				"Control: %d%%" % int(round(float(power_row.get("control", 0.0)) * 100.0)),
				"Fatigue: %d%%" % int(round(float(power_row.get("fatigue", 0.0)) * 100.0))
			],
			"actions": [
				{
					"id": "train_focus_%s" % power_id,
					"label": "Train",
					"engine_property": "power_engine",
					"method": "resolve_power_action",
					"payload": {
						"action": "train_power_focus",
						"training_focus": "power",
						"power_id": power_id,
						"source": "power_training_section"
					},
					"refresh_after": true
				}
			]
		})

		var unlocked_subskills: Array = _safe_array(power_row.get("unlocked_subskills", []))
		var all_subskills: Array = _safe_array(power_row.get("subskills", []))
		for raw_subskill in all_subskills:
			var subskill_id: String = str(raw_subskill).strip_edges().to_lower()
			if subskill_id == "":
				continue

			var already_unlocked: bool = subskill_id in unlocked_subskills
			rows.append({
				"id": "train_subskill_%s_%s" % [power_id, subskill_id],
				"label": "Train Subskill • %s" % subskill_id.replace("_", " ").capitalize(),
				"description": "%s • %s" % [
					display_name,
					"Unlocked" if already_unlocked else "Locked / developing"
				],
				"overview_title": "Train Subskill",
				"overview_lines": [
					"Power: %s" % display_name,
					"Subskill: %s" % subskill_id.replace("_", " ").capitalize(),
					"Status: %s" % ("Unlocked" if already_unlocked else "Locked / developing"),
					"Successful training can strengthen the base power and unlock the next subskill."
				],
				"actions": [
					{
						"id": "train_subskill_%s_%s" % [power_id, subskill_id],
						"label": "Train",
						"engine_property": "power_engine",
						"method": "resolve_power_action",
						"payload": {
							"action": "train_power_focus",
							"training_focus": "subskill",
							"power_id": power_id,
							"subskill_id": subskill_id,
							"source": "power_training_section"
						},
						"refresh_after": true
					}
				]
			})

	for stat_id in ["raw_force", "control_discipline", "speed_reaction", "mutation_stability", "heroic_pressure"]:
		var stat_label: String = stat_id.replace("_", " ").capitalize()
		rows.append({
			"id": "train_stat_%s" % stat_id,
			"label": "Train Supe Stat • %s" % stat_label,
			"description": "Current level: %d" % int(power_stats.get(stat_id, 0)),
			"overview_title": "Train %s" % stat_label,
			"overview_lines": [
				"Training Focus: Supe Stat",
				"Stat: %s" % stat_label,
				"Current Level: %d" % int(power_stats.get(stat_id, 0)),
				"Successful training can improve this stat and sharpen your base power."
			],
			"actions": [
				{
					"id": "train_stat_%s" % stat_id,
					"label": "Train",
					"engine_property": "power_engine",
					"method": "resolve_power_action",
					"payload": {
						"action": "train_power_focus",
						"training_focus": "stat",
						"stat_id": stat_id,
						"source": "power_training_section"
					},
					"refresh_after": true
				}
			]
		})

	return rows

func get_power_origin_rows(_context: Dictionary = {}) -> Array:
	var out: Array = []

	for raw_key in origin_registry.keys():
		var origin_id: String = str(raw_key)
		var origin: Dictionary = _safe_dictionary(origin_registry.get(origin_id, {}))
		out.append({
			"label": str(origin.get("display_name", origin_id.capitalize())),
			"description": str(origin.get("description", "A power origin contract.")),
			"actions": [
				{
					"id": "power_origin_%s" % origin_id,
					"label": "Attempt Origin",
					"kind": "engine_call",
					"engine_property": "power_engine",
					"method": "resolve_power_action",
					"call_mode": "player_payload",
					"payload": {
						"action": "origin_attempt",
						"origin_id": origin_id
					},
					"refresh_after": true
				}
			]
		})

	return out

func yearly_tick(_payload:= {}) -> Dictionary:
	var state: Dictionary = _world_state()
	var person_states: Dictionary = _safe_dictionary(state.get("person_power_state", {}))
	var cooled_down_count: int = 0
	var awakening_queue: Array = []

	for raw_key in person_states.keys():
		var row: Dictionary = _safe_dictionary(person_states.get(raw_key, {}))
		if row.is_empty():
			continue

		row ["fatigue"] = max(0.0, float(row.get("fatigue", 0.0)) - 0.1)
		row ["corruption"] = max(0.0, float(row.get("corruption", 0.0)) - 0.015)

		var powers: Dictionary = _safe_dictionary(row.get("powers", {}))
		for power_key in powers.keys():
			var power: Dictionary = _safe_dictionary(powers.get(power_key, {}))
			power ["fatigue"] = max(0.0, float(power.get("fatigue", 0.0)) - 0.12)
			powers [power_key] = power

		row ["powers"] = powers
		row ["updated_year"] = _current_year()

		var actor_id: int = int(row.get("person_id", raw_key))
		var actor: Person = _person_by_id(actor_id)
		var latent_config: Dictionary = _safe_dictionary(row.get("lineage_power_seed", {}))
		if actor != null and not latent_config.is_empty() and _latent_seed_should_awaken_now(actor, row, latent_config):
			awakening_queue.append({
				"actor_id": int(actor.id),
				"config": latent_config.duplicate(true),
				"reason": _latent_seed_awakening_reason(actor, row, latent_config)
			})
			row ["lineage_power_seed_awakened"] = true
			row ["lineage_power_seed_awakened_year"] = _current_year()

		person_states [raw_key] = row
		cooled_down_count += 1

	state ["person_power_state"] = person_states
	_commit_world_state(state)

	var awakened_count: int = 0
	for raw_awaken in awakening_queue:
		if typeof(raw_awaken) != TYPE_DICTIONARY:
			continue

		var awaken_row: Dictionary = raw_awaken
		var awaken_actor: Person = _person_by_id(int(awaken_row.get("actor_id", -1)))
		var awaken_config: Dictionary = _safe_dictionary(awaken_row.get("config", {}))
		var primary_power: String = str(awaken_config.get("primary_power", "")).strip_edges().to_lower()
		if awaken_actor == null or primary_power == "":
			continue

		grant_power(awaken_actor, primary_power, "latent_power_awakening", {
			"origin": str(awaken_config.get("origin", "latent_power_awakening")),
			"visibility": _sandbox_visibility_from_identity(str(awaken_config.get("public_identity", "secret"))),
			"awakening_reason": str(awaken_row.get("reason", "latent")),
			"superpower_sandbox_config": awaken_config.duplicate(true)
		})
		awakened_count += 1

	state = _world_state()
	state ["last_yearly_tick_report"] = {
		"success": true,
		"cooled_down_power_profiles": cooled_down_count,
		"latent_power_awakenings": awakened_count,
		"year": _current_year(),
		"updated_at_ms": int(Time.get_ticks_msec())
	}
	_commit_world_state(state)
	return state ["last_yearly_tick_report"].duplicate(true)
func _latent_seed_should_awaken_now(actor: Person, power_state: Dictionary, config: Dictionary) -> bool:
	if actor == null or config.is_empty():
		return false

	if bool(power_state.get("lineage_power_seed_awakened", false)):
		return false

	var powers: Dictionary = _safe_dictionary(power_state.get("powers", {}))
	if not powers.is_empty():
		return false

	var awakening: Dictionary = _safe_dictionary(config.get("awakening", {}))
	var inheritance: Dictionary = _safe_dictionary(config.get("inheritance", {}))
	var mode: String = str(awakening.get("mode", "latent")).strip_edges().to_lower()
	var minimum_age: int = max(0, int(awakening.get("minimum_age", 0)))

	if mode == "age_gate" and int(actor.age) >= minimum_age:
		return true

	if bool(inheritance.get("awakens_at_age_13", false)) and int(actor.age) >= 13:
		return true

	if mode == "trauma_triggered" and bool(power_state.get("trauma_awakening_pending", false)):
		return true

	if bool(inheritance.get("awakens_under_trauma", false)) and bool(power_state.get("trauma_awakening_pending", false)):
		return true

	return false


func _latent_seed_awakening_reason(actor: Person, power_state: Dictionary, config: Dictionary) -> String:
	var awakening: Dictionary = _safe_dictionary(config.get("awakening", {}))
	var inheritance: Dictionary = _safe_dictionary(config.get("inheritance", {}))
	var mode: String = str(awakening.get("mode", "latent")).strip_edges().to_lower()

	if bool(power_state.get("trauma_awakening_pending", false)):
		return "trauma"

	if bool(inheritance.get("awakens_at_age_13", false)) and int(actor.age) >= 13:
		return "age_13"

	if mode == "age_gate":
		return "age_gate"

	return mode

func _default_contract() -> Dictionary:
	return {
		"schema": CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": "power_engine.default",
		"runtime_policy": {
			"preserve_unknown_fields": true,
		},
		"spawn_rules": {
			"enabled_modes": ["chaos", "fantasy"],
			"latent_birth_chance": 0.015,
			"inherited_power_chance": 0.38,
			"mythic_birth_chance": 0.002,
		},
		"power_contracts": [
			{
				"schema": "eralife.power_contract",
				"id": "super_strength",
				"display_name": "Super Strength",
				"category": "superpower",
				"rarity": "common",
				"activation": { "type": "passive + active"},
				"effects": ["impact_damage", "lifting_power", "grapple_advantage"],
				"scaling": { "control": 0.35, "chaos": 0.2, "fatigue": 0.3},
				"subskills": ["brace", "shockwave_punch", "building_lift", "ground_breaker"]
			},
			{
				"schema": "eralife.power_contract",
				"id": "super_speed",
				"display_name": "Super Speed",
				"category": "superpower",
				"rarity": "rare",
				"activation": { "type": "active"},
				"effects": ["speed_blitz", "evasion_boost", "rescue_priority"],
				"scaling": { "control": 0.3, "chaos": 0.34, "fatigue": 0.46},
				"subskills": ["afterimage", "speed_rescue", "sonic_dash", "phase_step"]
			},
			{
				"schema": "eralife.power_contract",
				"id": "adamantium_skeleton",
				"display_name": "Adamantium Skeleton",
				"category": "procedure",
				"rarity": "legendary",
				"activation": { "type": "passive"},
				"effects": ["damage_resistance", "bone_integrity", "weaponized_body"],
				"scaling": { "control": 0.45, "chaos": 0.25, "fatigue": 0.38},
				"subskills": ["unbreakable_guard", "claw_strike", "pain_tolerance", "berserker_rush"]
			},
			{
				"schema": "eralife.power_contract",
				"id": "super_serum",
				"display_name": "Super Serum Enhancement",
				"category": "procedure",
				"rarity": "legendary",
				"activation": { "type": "passive"},
				"effects": ["peak_body", "healing_boost", "combat_processing"],
				"scaling": { "control": 0.55, "chaos": 0.18, "fatigue": 0.22},
				"subskills": ["perfect_form", "tactical_read", "heroic_intercept", "last_stand"]
			},
			{
				"schema": "eralife.power_contract",
				"id": "probability_manipulation",
				"display_name": "Probability Manipulation",
				"category": "superpower",
				"rarity": "mythic",
				"activation": { "type": "passive + active"},
				"effects": ["probability_shift", "outcome_bias", "event_override"],
				"scaling": { "control": 0.3, "chaos": 0.9, "fatigue": 0.7},
				"subskills": ["lucky_break", "bad_luck_field", "critical_reroll", "impossible_escape", "event_rewrite"]
			},
			{
				"schema": "eralife.power_contract",
				"id": "spider_abilities",
				"display_name": "Spider Abilities",
				"category": "mutation",
				"rarity": "rare",
				"activation": { "type": "passive + active"},
				"effects": ["danger_sense", "wall_crawl", "web_mobility", "agility_boost"],
				"scaling": { "control": 0.42, "chaos": 0.26, "fatigue": 0.32},
				"subskills": ["spider_sense", "web_swing", "web_bind", "ceiling_drop", "quips_under_pressure"]
			},
			{
				"schema": "eralife.power_contract",
				"id": "infant_chaos_polymorph",
				"display_name": "Infant Chaos Polymorph",
				"category": "mutation",
				"rarity": "mythic",
				"activation": { "type": "passive + active + instinctive"},
				"starting_level": 3,
				"birth_awakened": true,
				"effects": [
					"laser_eyes",
					"body_ignition",
					"phasing",
					"multiplication",
					"monster_form",
					"dimension_blink",
					"metal_body",
					"elastic_body",
					"chaotic_power_cycle"
				],
				"scaling": { "control": 0.06, "chaos": 0.96, "fatigue": 0.58},
				"subskills": [
					"laser_peekaboo",
					"flame_tantrum",
					"crib_phase",
					"baby_multiplication",
					"tiny_monster_shift",
					"dimension_blink",
					"metal_baby_guard",
					"elastic_reach",
					"uncontrolled_power_burst"
				],
				"birth_flavor": {
					"rare_line": "The nurses whispered that the lights bent toward your crib.",
					"conception_story": "Before you had a name, something impossible nested in your cells. By the time you cried for the first time, reality had already flinched."
				}
			},
			{
				"schema": "eralife.power_contract",
				"id": "energy_projection",
				"display_name": "Energy Projection",
				"category": "superpower",
				"rarity": "rare",
				"activation": { "type": "active"},
				"effects": ["ranged_blast", "barrier_break", "light_emission"],
				"scaling": { "control": 0.26, "chaos": 0.48, "fatigue": 0.44},
				"subskills": ["energy_bolt", "wide_beam", "shield_burst", "charged_finale"]
			},
			{
				"schema": "eralife.power_contract",
				"id": "telepathy",
				"display_name": "Telepathy",
				"category": "psychic",
				"rarity": "epic",
				"activation": { "type": "passive + active"},
				"effects": ["mind_read", "emotion_scan", "mental_pressure"],
				"scaling": { "control": 0.22, "chaos": 0.52, "fatigue": 0.4},
				"subskills": ["surface_read", "fear_echo", "memory_ping", "psychic_stun"]
			}
		],
		"origin_contracts": [
			{
				"id": "particle_accelerator_explosion",
				"display_name": "Particle Accelerator Explosion",
				"description": "A city-scale scientific accident tears open impossible biology.",
				"success_chance": 0.68,
				"power_pool": ["super_speed", "energy_projection", "telepathy", "probability_manipulation"],
				"visibility": "public",
				"success_text": "The blast does not kill you. It rewrites your impossible odds.",
				"failure_text": "The explosion scars the city, but your body stays quiet."
			},
			{
				"id": "super_serum_injection",
				"display_name": "Super Serum Injection",
				"description": "A contract-governed enhancement procedure attempts to unlock peak human potential.",
				"success_chance": 0.72,
				"power_pool": ["super_serum", "super_strength", "super_speed"],
				"visibility": "known",
				"success_text": "Your heartbeat becomes disciplined thunder.",
				"failure_text": "The serum burns through you without stabilizing."
			},
			{
				"id": "adamantium_surgery",
				"display_name": "Adamantium Skeleton Surgery",
				"description": "A brutal procedure reinforces the body and risks permanent corruption pressure.",
				"success_chance": 0.58,
				"power_pool": ["adamantium_skeleton"],
				"visibility": "unknown",
				"success_text": "Your bones become a prison and a weapon.",
				"failure_text": "The surgery fails before the metal takes."
			},
			{
				"id": "supe_family_birth",
				"display_name": "Born Into A Supe Family",
				"description": "Power arrives as inheritance, household pressure, reputation, and bloodline expectation.",
				"success_chance": 0.88,
				"power_pool": ["super_strength", "super_speed", "spider_abilities", "energy_projection", "telepathy"],
				"visibility": "family_known",
				"success_text": "The family secret is not whether you have power. It is what kind."
			}
		]
	}

func _bootstrap_contract_registry() -> void:
	if typeof(contract_registry) != TYPE_DICTIONARY:
		contract_registry = {}
	if typeof(origin_registry) != TYPE_DICTIONARY:
		origin_registry = {}

	var contracts: Array = _safe_array(active_contract.get("power_contracts", []))
	for raw_contract in contracts:
		if typeof(raw_contract) != TYPE_DICTIONARY:
			continue
		var normalized: Dictionary = _normalize_power_contract(raw_contract as Dictionary)
		var contract_id: String = str(normalized.get("id", "")).strip_edges().to_lower()
		if contract_id == "":
			continue
		if not contract_registry.has(contract_id):
			contract_registry [contract_id] = normalized.duplicate(true)

	for raw_dragonball_contract in _dragonball_power_contract_extensions():
		if typeof(raw_dragonball_contract) != TYPE_DICTIONARY:
			continue
		var dragonball_contract: Dictionary = _normalize_power_contract(raw_dragonball_contract as Dictionary)
		var dragonball_id: String = str(dragonball_contract.get("id", "")).strip_edges().to_lower()
		if dragonball_id == "":
			continue
		if not contract_registry.has(dragonball_id):
			contract_registry [dragonball_id] = dragonball_contract.duplicate(true)

	var origins: Array = _safe_array(active_contract.get("origin_contracts", []))
	for raw_origin in origins:
		if typeof(raw_origin) != TYPE_DICTIONARY:
			continue
		var origin: Dictionary = (raw_origin as Dictionary).duplicate(true)
		var origin_id: String = str(origin.get("id", "")).strip_edges().to_lower()
		if origin_id == "":
			continue
		if typeof(origin.get("power_pool", [])) != TYPE_ARRAY:
			origin ["power_pool"] = []
		if not origin_registry.has(origin_id):
			origin_registry [origin_id] = origin.duplicate(true)
func _dragonball_power_contract_extensions() -> Array:
	return [
		{
			"schema": "eralife.power_contract",
			"id": "saiyan_bloodline",
			"display_name": "Saiyan Bloodline",
			"category": "bloodline",
			"rarity": "mythic",
			"activation": { "type": "passive + active + emotional"},
			"starting_level": 8,
			"effects": [
				"combat_growth_exponential",
				"zenkai_recovery",
				"rage_scaling",
				"ki_channel",
				"limit_breaker"
			],
			"scaling": { "control": 0.38, "chaos": 0.54, "fatigue": 0.34},
			"subskills": [
				"ki_sense",
				"ki_blast",
				"rage_surge",
				"zenkai_recovery",
				"combat_adaptation",
				"limit_break"
			]
		},
		{
			"schema": "eralife.power_contract",
			"id": "ki_sense",
			"display_name": "Ki Sense",
			"category": "ki",
			"rarity": "rare",
			"activation": { "type": "passive"},
			"effects": ["threat_detection", "combat_reading", "power_level_sense"],
			"scaling": { "control": 0.48, "chaos": 0.12, "fatigue": 0.08},
			"subskills": ["sense_pressure", "read_aura", "locate_hidden_fighter"]
		},
		{
			"schema": "eralife.power_contract",
			"id": "ki_blast",
			"display_name": "Ki Blast",
			"category": "ki",
			"rarity": "rare",
			"activation": { "type": "active"},
			"effects": ["ranged_blast", "impact_damage", "battle_pressure"],
			"scaling": { "control": 0.32, "chaos": 0.32, "fatigue": 0.26},
			"subskills": ["quick_blast", "double_blast", "blast_feint"]
		},
		{
			"schema": "eralife.power_contract",
			"id": "charged_ki_beam",
			"display_name": "Charged Ki Beam",
			"category": "ki",
			"rarity": "epic",
			"activation": { "type": "active + charged"},
			"effects": ["beam_attack", "guard_break", "arena_damage"],
			"scaling": { "control": 0.28, "chaos": 0.48, "fatigue": 0.44},
			"subskills": ["charge_beam", "beam_clash", "last_second_release"]
		},
		{
			"schema": "eralife.power_contract",
			"id": "battle_flight",
			"display_name": "Battle Flight",
			"category": "ki",
			"rarity": "epic",
			"activation": { "type": "active"},
			"effects": ["flight", "aerial_evasion", "battle_mobility"],
			"scaling": { "control": 0.42, "chaos": 0.22, "fatigue": 0.3},
			"subskills": ["hover", "burst_flight", "aerial_dash"]
		},
		{
			"schema": "eralife.power_contract",
			"id": "ki_barrier",
			"display_name": "Ki Barrier",
			"category": "ki",
			"rarity": "epic",
			"activation": { "type": "active + defensive"},
			"effects": ["energy_guard", "blast_resistance", "impact_absorption"],
			"scaling": { "control": 0.5, "chaos": 0.18, "fatigue": 0.34},
			"subskills": ["bubble_guard", "impact_shell", "last_second_barrier"]
		}
	]

func _normalize_power_contract(contract: Dictionary) -> Dictionary:
	var out: Dictionary = contract.duplicate(true)
	out ["schema"] = str(out.get("schema", "eralife.power_contract"))
	out ["version"] = max(1, int(out.get("version", CONTRACT_VERSION)))
	out ["id"] = str(out.get("id", "generic_power")).strip_edges().to_lower()
	out ["display_name"] = str(out.get("display_name", out.get("id", "Power")))
	out ["category"] = str(out.get("category", "superpower")).strip_edges().to_lower()
	out ["rarity"] = str(out.get("rarity", "common")).strip_edges().to_lower()

	if typeof(out.get("activation", {})) != TYPE_DICTIONARY:
		out ["activation"] = { "type": "passive"}
	if typeof(out.get("effects", [])) != TYPE_ARRAY:
		out ["effects"] = []
	if typeof(out.get("scaling", {})) != TYPE_DICTIONARY:
		out ["scaling"] = { "control": 0.25, "chaos": 0.25, "fatigue": 0.25}
	if typeof(out.get("subskills", [])) != TYPE_ARRAY:
		out ["subskills"] = []

	return out

func _resolve_inherited_power(actor: Person) -> Dictionary:
	if actor == null:
		return {}

	var parent_ids: Array = []
	if "parents" in actor and typeof(actor.parents) == TYPE_ARRAY:
		parent_ids = actor.parents.duplicate()

	if parent_ids.is_empty():
		return {}

	var inherited_pool: Array = []
	for raw_parent_id in parent_ids:
		var parent: Person = _person_by_id(int(raw_parent_id))
		if parent == null:
			continue
		for power_id in get_active_power_ids(parent):
			inherited_pool.append(str(power_id))

	if inherited_pool.is_empty():
		return {}

	var inherited_chance: float = float(_safe_dictionary(active_contract.get("spawn_rules", {})).get("inherited_power_chance", 0.38))
	if randf() > inherited_chance:
		return {
			"success": true,
			"granted_power": false,
			"reason": "Inherited power did not express."
		}

	var picked: String = _weighted_power_pick(inherited_pool)
	return grant_power(actor, picked, "inherited_power_expression", {
		"inherited": true,
		"visibility": "family_known"
	})
func _normalize_superpower_sandbox_config(raw_config: Variant) -> Dictionary:
	if typeof(raw_config) != TYPE_DICTIONARY:
		return {}

	var raw: Dictionary = (raw_config as Dictionary).duplicate(true)
	if raw.is_empty():
		return {}

	var rarity_id: String = str(raw.get("rarity", "rare")).strip_edges().to_lower()
	var rarity_profile: Dictionary = _superpower_rarity_profile(rarity_id)
	var scope_id: String = str(raw.get("scope", "only_me")).strip_edges().to_lower()
	var public_identity_id: String = str(raw.get("public_identity", "secret")).strip_edges().to_lower()
	var origin_id: String = str(raw.get("origin", "born_hidden")).strip_edges().to_lower()

	if public_identity_id == "government_experiment":
		origin_id = "experiment_surgery"
		if scope_id not in ["only_me", "whole_family", "my_bloodline"]:
			scope_id = "only_me"

	var out: Dictionary = {
		"schema": "eralife.superpower_sandbox_config",
		"version": CONTRACT_VERSION,
		"scope": scope_id,
		"target_group": str(raw.get("target_group", "")).strip_edges(),
		"origin": origin_id,
		"primary_power": str(raw.get("primary_power", "")).strip_edges().to_lower(),
		"rarity": rarity_id,
		"public_identity": public_identity_id,
		"rarity_profile": rarity_profile.duplicate(true),
		"latent_potential": int(rarity_profile.get("latent_potential", 120)),
		"awakening": {},
		"inheritance": {},
		"family": {}
	}

	if str(out.get("primary_power", "")).strip_edges() == "":
		return {}

	var awakening_raw: Dictionary = _safe_dictionary(raw.get("awakening", {}))
	out ["awakening"] = {
		"mode": str(awakening_raw.get("mode", "latent" if str(out.get("origin", "")) == "born_hidden" else "immediate")).strip_edges().to_lower(),
		"minimum_age": max(0, int(awakening_raw.get("minimum_age", 0))),
		"public_visibility": str(awakening_raw.get("public_visibility", out.get("public_identity", "secret"))).strip_edges().to_lower(),
	}

	var inheritance_raw: Dictionary = _safe_dictionary(raw.get("inheritance", {}))
	out ["inheritance"] = {
		"mode": str(inheritance_raw.get("mode", "dominant")).strip_edges().to_lower(),
		"skips_generations": bool(inheritance_raw.get("skips_generations", false)),
		"awakens_under_trauma": bool(inheritance_raw.get("awakens_under_trauma", false)),
		"awakens_at_age_13": bool(inheritance_raw.get("awakens_at_age_13", false)),
		"only_firstborn": bool(inheritance_raw.get("only_firstborn", false)),
		"only_avatars_benders": bool(inheritance_raw.get("only_avatars_benders", false)),
		"corrupts_bloodline_over_time": bool(inheritance_raw.get("corrupts_bloodline_over_time", false)),
		"generation_strength_loss": clamp(float(inheritance_raw.get("generation_strength_loss", 0.18)), 0.0, 1.0),
		"mutation_chance": clamp(float(inheritance_raw.get("mutation_chance", 0.07)), 0.0, 1.0),
		"clone_primary_power": false
	}

	var family_raw: Dictionary = _safe_dictionary(raw.get("family", {}))
	var family_identity_style: String = "public_legacy" if public_identity_id in ["registered_hero", "government_experiment"] else "private_household"
	var family_archetype: String = "legendary_super_family" if scope_id in ["whole_family", "my_bloodline"] and rarity_id in ["legendary", "mythic"] else "powered_family"

	out ["family"] = {
		"enabled": scope_id in ["whole_family", "my_bloodline"],
		"archetype": str(family_raw.get("archetype", family_archetype)).strip_edges().to_lower(),
		"identity_style": str(family_raw.get("identity_style", family_identity_style)).strip_edges().to_lower(),
		"ability_variation": str(family_raw.get("ability_variation", "coherent_variants")).strip_edges().to_lower(),
		"retired_elder_chance": clamp(float(family_raw.get("retired_elder_chance", 0.84 if rarity_id in ["legendary", "mythic"] else 0.46)), 0.0, 1.0),
		"active_parent_chance": clamp(float(family_raw.get("active_parent_chance", 0.64 if public_identity_id == "registered_hero" else 0.28)), 0.0, 1.0),
		"auto_registered_at_birth": public_identity_id == "registered_hero"
	}

	var mutation_genes_raw: Dictionary = _safe_dictionary(raw.get("mutation_genes", {}))
	var auto_mix: bool = bool(mutation_genes_raw.get("auto_enable_when_bender_power_mix", true))

	out ["mutation_genes"] = {
		"enabled": bool(mutation_genes_raw.get("enabled", false)),
		"auto_enable_when_bender_power_mix": auto_mix,
		"intentional_use_requires_bending_moves": bool(mutation_genes_raw.get("intentional_use_requires_bending_moves", true)),
		"uncontrolled_age_up_risk": bool(mutation_genes_raw.get("uncontrolled_age_up_risk", true)),
		"age_up_instability_chance": clamp(float(mutation_genes_raw.get("age_up_instability_chance", 0.12)), 0.0, 1.0)
	}

	return out

func _store_superpower_sandbox_contract(config: Dictionary, actor: Person, settings: Dictionary = {}) -> void:
	var state: Dictionary = _world_state()
	state ["superpower_sandbox_contract"] = config.duplicate(true)
	state ["superpower_sandbox_seed_actor_id"] = int(actor.id) if actor != null else -1
	state ["superpower_sandbox_seed_actor_name"] = _person_label(actor)
	state ["superpower_sandbox_seed_country"] = str(settings.get("country", "")).strip_edges()
	_commit_world_state(state)


func _current_superpower_sandbox_contract() -> Dictionary:
	var state: Dictionary = _world_state()
	var state_contract: Dictionary = _normalize_superpower_sandbox_config(state.get("superpower_sandbox_contract", {}))
	if not state_contract.is_empty():
		return state_contract

	if gs != null and typeof(gs.custom_settings) == TYPE_DICTIONARY:
		return _normalize_superpower_sandbox_config(gs.custom_settings.get("superpower_configurator", null))

	return {}


func _sandbox_visibility_from_identity(public_identity: String) -> String:
	match str(public_identity).strip_edges().to_lower():
		"registered_hero", "wanted_villain":
			return "public"
		"government_experiment":
			return "government_file"
		"rumored":
			return "rumored"
		_:
			return "unknown"

func _actor_property_text(actor: Person, property_name: String) -> String:
	if actor == null:
		return ""
	return str(actor.get(property_name)).strip_edges()


func _actors_share_immediate_family(actor: Person, anchor: Person) -> bool:
	if actor == null or anchor == null:
		return false

	if int(actor.id) == int(anchor.id):
		return true

	var actor_parents: Variant = actor.get("parents")
	var anchor_parents: Variant = anchor.get("parents")

	if typeof(actor_parents) == TYPE_ARRAY and typeof(anchor_parents) == TYPE_ARRAY:
		for raw_parent_id in actor_parents:
			if raw_parent_id in anchor_parents:
				return true

	var actor_last:= _actor_property_text(actor, "last_name").to_lower()
	var anchor_last:= _actor_property_text(anchor, "last_name").to_lower()
	return actor_last != "" and actor_last == anchor_last


func _actors_share_bloodline(actor: Person, anchor: Person) -> bool:
	if actor == null or anchor == null:
		return false

	if int(actor.id) == int(anchor.id):
		return true

	var actor_last:= _actor_property_text(actor, "last_name").to_lower()
	var anchor_last:= _actor_property_text(anchor, "last_name").to_lower()
	if actor_last != "" and actor_last == anchor_last:
		return true

	return _actors_share_immediate_family(actor, anchor)


func _actor_group_tokens(actor: Person) -> Array:
	var out: Array = []
	var seen: Dictionary = {}

	for property_name in [
		"country",
		"nationality",
		"birth_country",
		"species",
		"clan",
		"clan_name",
		"last_name"
	]:
		var token:= _actor_property_text(actor, property_name).to_lower()
		if token == "" or seen.has(token):
			continue
		seen [token] = true
		out.append(token)

	return out


func _actor_is_firstborn(actor: Person) -> bool:
	if actor == null:
		return false

	var birth_order:= int(actor.get("birth_order"))
	if birth_order > 0:
		return birth_order == 1

	return true


func _sandbox_scope_matches_actor(actor: Person, config: Dictionary, payload: Dictionary = {}) -> bool:
	if actor == null:
		return false

	var scope: String = str(config.get("scope", "only_me")).strip_edges().to_lower()
	var anchor: Person = gs.player if gs != null else null

	if payload.has("seed_actor_id"):
		var seed_actor: Person = _person_by_id(int(payload.get("seed_actor_id", -1)))
		if seed_actor != null:
			anchor = seed_actor

	match scope:
		"only_me":
			return anchor != null and int(actor.id) == int(anchor.id)

		"whole_family":
			return _actors_share_immediate_family(actor, anchor)

		"my_bloodline":
			return _actors_share_bloodline(actor, anchor)

		"random_world_mutation":
			var inheritance_random: Dictionary = _safe_dictionary(config.get("inheritance", {}))
			return randf() <= float(inheritance_random.get("mutation_chance", 0.07))

		"nation_species_clan":
			var target_group: String = str(config.get("target_group", "")).strip_edges().to_lower()
			if target_group == "" and anchor != null:
				var anchor_tokens: Array = _actor_group_tokens(anchor)
				if not anchor_tokens.is_empty():
					target_group = str(anchor_tokens [0]).strip_edges().to_lower()

			if target_group == "":
				return false

			return target_group in _actor_group_tokens(actor)

		_:
			return anchor != null and int(actor.id) == int(anchor.id)


func _sandbox_should_seed_latent(config: Dictionary) -> bool:
	var origin: String = str(config.get("origin", "")).strip_edges().to_lower()
	var awakening: Dictionary = _safe_dictionary(config.get("awakening", {}))
	var inheritance: Dictionary = _safe_dictionary(config.get("inheritance", {}))
	var awakening_mode: String = str(awakening.get("mode", "")).strip_edges().to_lower()

	if awakening_mode == "awoken_at_birth":
		return false
	if awakening_mode == "immediate":
		return false
	if awakening_mode == "latent":
		return true
	if awakening_mode == "trauma_triggered":
		return true
	if awakening_mode == "age_gate":
		return true
	if origin == "born_hidden":
		return true
	if int(awakening.get("minimum_age", 0)) > 0:
		return true
	if bool(inheritance.get("awakens_under_trauma", false)):
		return true
	if bool(inheritance.get("awakens_at_age_13", false)):
		return true

	return false

func _seed_sandbox_lineage_power(actor: Person, config: Dictionary, source: String = "superpower_sandbox_seed") -> Dictionary:
	if actor == null:
		return {}

	var resolved_power_id: String = _resolve_sandbox_power_for_actor(actor, config, {
		"source": source
	})
	if resolved_power_id == "":
		return {}

	var rarity_profile: Dictionary = _safe_dictionary(config.get("rarity_profile", {}))
	if rarity_profile.is_empty():
		rarity_profile = _superpower_rarity_profile(str(config.get("rarity", "rare")))

	var awakening: Dictionary = _safe_dictionary(config.get("awakening", {}))
	var family: Dictionary = _safe_dictionary(config.get("family", {}))

	var grant_context: Dictionary = {
		"origin": str(config.get("origin", source)),
		"visibility": _sandbox_visibility_from_identity(str(config.get("public_identity", "secret"))),
		"public_identity": str(config.get("public_identity", "secret")),
		"inherited": true,
		"configured_at_birth": true,
		"latent_locked": true,
		"visible_in_hub": true,
		"awakening_mode": str(awakening.get("mode", "latent")),
		"birth_awakened": false,
		"rarity": str(config.get("rarity", "rare")),
		"rarity_profile": rarity_profile.duplicate(true),
		"base_power_level": int(rarity_profile.get("base_power_level", 80)),
		"latent_potential": int(config.get("latent_potential", rarity_profile.get("latent_potential", 140))),
		"hidden_identity_risk": float(rarity_profile.get("hidden_identity_risk", 0.1)),
		"fame_multiplier": float(rarity_profile.get("fame_multiplier", 1.0)),
		"opponent_tier_bias": str(rarity_profile.get("opponent_tier_bias", "street_level")),
		"low_tier_respect_multiplier": float(rarity_profile.get("low_tier_respect_multiplier", 1.0)),
		"family_legacy": family.duplicate(true),
		"superpower_sandbox_config": config.duplicate(true)
	}

	var report: Dictionary = grant_power(actor, resolved_power_id, source, grant_context)
	if bool(report.get("success", false)):
		report ["seeded_power"] = true
		report ["granted_power"] = true
		report ["sandbox_visible_while_latent"] = true

	return report


func _resolve_sandbox_configured_power(actor: Person, payload: Variant = {}) -> Dictionary:
	if actor == null:
		return {}

	var context: Dictionary = {}
	if typeof(payload) == TYPE_DICTIONARY:
		context = (payload as Dictionary).duplicate(true)

	var config: Dictionary = _current_superpower_sandbox_contract()
	if config.is_empty():
		return {}

	if not _sandbox_scope_matches_actor(actor, config, context):
		return {}

	var inheritance: Dictionary = _safe_dictionary(config.get("inheritance", {}))
	if bool(inheritance.get("only_avatars_benders", false)):
		var bending_type:= _actor_property_text(actor, "bending_type").to_lower()
		if bending_type in ["", "none"]:
			return {}

	if bool(inheritance.get("only_firstborn", false)) and not _actor_is_firstborn(actor):
		return {}

	var resolved_power_id: String = _resolve_sandbox_power_for_actor(actor, config, context)
	if resolved_power_id == "":
		return {}

	var awakening: Dictionary = _safe_dictionary(config.get("awakening", {}))
	var rarity_profile: Dictionary = _safe_dictionary(config.get("rarity_profile", {}))
	if rarity_profile.is_empty():
		rarity_profile = _superpower_rarity_profile(str(config.get("rarity", "rare")))

	var seed_actor_id: int = int(context.get("seed_actor_id", -1))
	var is_seed_actor: bool = seed_actor_id <= 0 or int(actor.id) == seed_actor_id
	var scope_id: String = str(config.get("scope", "")).strip_edges().to_lower()
	var latent_locked: bool = _sandbox_should_seed_latent(config)
	var family: Dictionary = _safe_dictionary(config.get("family", {}))
	var inherited_from_lineage: bool = scope_id in ["my_bloodline", "whole_family"]

	var grant_context: Dictionary = {
		"origin": str(config.get("origin", "superpower_sandbox_birth")),
		"visibility": _sandbox_visibility_from_identity(str(config.get("public_identity", "secret"))),
		"public_identity": str(config.get("public_identity", "secret")),
		"inherited": inherited_from_lineage,
		"configured_at_birth": true,
		"family_variant": inherited_from_lineage and not is_seed_actor,
		"lineage_anchor_id": seed_actor_id,
		"lineage_anchor_name": str(context.get("seed_actor_name", "")),
		"awakening_mode": str(awakening.get("mode", "immediate")),
		"birth_awakened": str(awakening.get("mode", "")).strip_edges().to_lower() == "awoken_at_birth",
		"latent_locked": latent_locked,
		"visible_in_hub": true,
		"rarity": str(config.get("rarity", "rare")),
		"rarity_profile": rarity_profile.duplicate(true),
		"base_power_level": int(rarity_profile.get("base_power_level", 80)),
		"latent_potential": int(config.get("latent_potential", rarity_profile.get("latent_potential", 140))),
		"hidden_identity_risk": float(rarity_profile.get("hidden_identity_risk", 0.1)),
		"fame_multiplier": float(rarity_profile.get("fame_multiplier", 1.0)),
		"opponent_tier_bias": str(rarity_profile.get("opponent_tier_bias", "street_level")),
		"low_tier_respect_multiplier": float(rarity_profile.get("low_tier_respect_multiplier", 1.0)),
		"family_legacy": family.duplicate(true),
		"superpower_sandbox_config": config.duplicate(true)
	}

	var report: Dictionary = grant_power(actor, resolved_power_id, "superpower_sandbox_birth", grant_context)
	if bool(report.get("success", false)):
		report ["sandbox_visible_while_latent"] = true
		report ["seeded_power"] = latent_locked
		report ["granted_power"] = true
		report ["rarity_profile"] = rarity_profile.duplicate(true)

	return report
func _initial_subskills(contract: Dictionary) -> Array:
	var subskills: Array = _safe_array(contract.get("subskills", []))
	if subskills.is_empty():
		return []
	return [str(subskills [0])]

func _unlock_next_subskill(power_row: Dictionary) -> void:
	var all_subskills: Array = _safe_array(power_row.get("subskills", []))
	var unlocked: Array = _safe_array(power_row.get("unlocked_subskills", []))

	for raw_skill in all_subskills:
		var skill_id: String = str(raw_skill)
		if skill_id not in unlocked:
			unlocked.append(skill_id)
			power_row ["unlocked_subskills"] = unlocked
			return

	power_row ["unlocked_subskills"] = unlocked

func _weighted_power_pick(pool: Array) -> String:
	if pool.is_empty():
		return "super_strength"

	var weighted: Array = []
	for raw_power_id in pool:
		var power_id: String = str(raw_power_id).strip_edges().to_lower()
		if power_id == "":
			continue

		var contract: Dictionary = get_power_contract(power_id)
		var rarity: String = str(contract.get("rarity", "common"))
		var weight: int = 10

		match rarity:
			"common":
				weight = 26
			"rare":
				weight = 14
			"epic":
				weight = 7
			"legendary":
				weight = 3
			"mythic":
				weight = 1
			_:
				weight = 10

		for _i in range(weight):
			weighted.append(power_id)

	if weighted.is_empty():
		return str(pool [0]).strip_edges().to_lower()

	return str(weighted [randi() % weighted.size()])
func _superpower_rarity_profile(rarity: String) -> Dictionary:
	var clean_rarity: String = str(rarity).strip_edges().to_lower()
	match clean_rarity:
		"common":
			return {
				"id": "common",
				"label": "Common",
				"base_power_level": 1200,
				"latent_potential": 40000,
				"hidden_identity_risk": 0.03,
				"fame_multiplier": 0.72,
				"opponent_tier_bias": "street_level",
				"low_tier_respect_multiplier": 3.4,
				"threat_ceiling_bias": "street_to_city",
				"description": "Street-level power. Beating stronger threats creates massive underdog respect because the math says you should not be alive."
			}
		"rare":
			return {
				"id": "rare",
				"label": "Rare",
				"base_power_level": 25000,
				"latent_potential": 800000,
				"hidden_identity_risk": 0.08,
				"fame_multiplier": 1.0,
				"opponent_tier_bias": "city_level",
				"low_tier_respect_multiplier": 2.2,
				"threat_ceiling_bias": "city",
				"description": "City-level potential. Strong enough to save blocks, districts, and eventually entire cities if trained correctly."
			}
		"epic":
			return {
				"id": "epic",
				"label": "Epic",
				"base_power_level": 350000,
				"latent_potential": 25000000,
				"hidden_identity_risk": 0.18,
				"fame_multiplier": 1.55,
				"opponent_tier_bias": "national_level",
				"low_tier_respect_multiplier": 1.55,
				"threat_ceiling_bias": "national",
				"description": "National-level potential. Agencies, militaries, and villain networks begin writing contingency plans around you."
			}
		"legendary":
			return {
				"id": "legendary",
				"label": "Legendary",
				"base_power_level": 8000000,
				"latent_potential": 600000000,
				"hidden_identity_risk": 0.36,
				"fame_multiplier": 2.35,
				"opponent_tier_bias": "world_level",
				"low_tier_respect_multiplier": 1.16,
				"threat_ceiling_bias": "planetary",
				"description": "World-level pressure. Your bloodline, enemies, governments, and cults all start acting different."
			}
		"mythic":
			return {
				"id": "mythic",
				"label": "Mythic",
				"base_power_level": 150000000,
				"latent_potential": 5000000000,
				"hidden_identity_risk": 0.62,
				"fame_multiplier": 3.8,
				"opponent_tier_bias": "cosmic_level",
				"low_tier_respect_multiplier": 0.88,
				"threat_ceiling_bias": "reality_break",
				"description": "Mythic power. You can still be the friendly neighborhood masked hero, but the neighborhood survives because you handle things that would erase it."
			}
		_:
			return _superpower_rarity_profile("rare")


func _resolve_sandbox_power_for_actor(actor: Person, config: Dictionary, context: Dictionary = {}) -> String:
	var primary_power: String = str(config.get("primary_power", "")).strip_edges().to_lower()
	if primary_power == "":
		return ""

	var seed_actor_id: int = int(context.get("seed_actor_id", -1))
	if seed_actor_id > 0 and actor != null and int(actor.id) == seed_actor_id:
		return primary_power

	var scope_id: String = str(config.get("scope", "only_me")).strip_edges().to_lower()
	if not scope_id in ["my_bloodline", "whole_family"]:
		return primary_power

	var inheritance: Dictionary = _safe_dictionary(config.get("inheritance", {}))
	if bool(inheritance.get("clone_primary_power", false)):
		return primary_power

	var family: Dictionary = _safe_dictionary(config.get("family", {}))
	if str(family.get("ability_variation", "coherent_variants")).strip_edges().to_lower() == "primary_clone":
		return primary_power

	var pool: Array = _sandbox_family_power_pool(primary_power, config)
	if pool.is_empty():
		return primary_power

	var hash_seed: String = "%s:%s:%s:%s" % [
		str(actor.id) if actor != null else "0",
		_person_label(actor),
		primary_power,
		str(config.get("rarity", "rare"))
	]
	var index: int = abs(int(hash_seed.hash())) % pool.size()
	return str(pool [index]).strip_edges().to_lower()


func _sandbox_family_power_pool(primary_power: String, config: Dictionary) -> Array:
	var clean_primary: String = str(primary_power).strip_edges().to_lower()
	var rarity_id: String = str(config.get("rarity", "rare")).strip_edges().to_lower()
	var pool: Array = []

	match clean_primary:
		"super_strength":
			pool = ["super_strength", "super_speed", "super_serum", "adamantium_skeleton"]
		"super_speed":
			pool = ["super_speed", "spider_abilities", "super_strength", "energy_projection"]
		"spider_abilities":
			pool = ["spider_abilities", "super_speed", "super_strength", "telepathy"]
		"energy_projection":
			pool = ["energy_projection", "telepathy", "super_speed", "super_strength"]
		"telepathy":
			pool = ["telepathy", "energy_projection", "probability_manipulation"]
		"super_serum":
			pool = ["super_serum", "super_strength", "super_speed", "adamantium_skeleton"]
		"adamantium_skeleton":
			pool = ["adamantium_skeleton", "super_strength", "super_serum"]
		"probability_manipulation":
			pool = ["probability_manipulation", "telepathy", "energy_projection", "spider_abilities"]
		"infant_chaos_polymorph":
			pool = ["infant_chaos_polymorph", "probability_manipulation", "energy_projection", "telepathy", "super_strength"]
		_:
			pool = [clean_primary, "super_strength", "super_speed", "energy_projection", "telepathy"]

	if rarity_id in ["legendary", "mythic"]:
		if not "probability_manipulation" in pool:
			pool.append("probability_manipulation")
		if not "adamantium_skeleton" in pool:
			pool.append("adamantium_skeleton")
		if not "super_serum" in pool:
			pool.append("super_serum")

	var filtered: Array = []
	for raw_power_id in pool:
		var power_id: String = str(raw_power_id).strip_edges().to_lower()
		if power_id == "":
			continue
		if not get_power_contract(power_id).is_empty() and not power_id in filtered:
			filtered.append(power_id)

	if filtered.is_empty() and not get_power_contract(clean_primary).is_empty():
		filtered.append(clean_primary)

	return filtered
func _rarity_weight(rarity: String) -> int:
	match str(rarity).strip_edges().to_lower():
		"common":
			return 4
		"rare":
			return 9
		"epic":
			return 16
		"legendary":
			return 28
		"mythic":
			return 48
		_:
			return 6

func _activation_text(_actor: Person, contract: Dictionary, payload: Dictionary = {}) -> String:
	var power_name: String = str(contract.get("display_name", "Power"))
	var action_context: String = str(payload.get("context", payload.get("scene", ""))).strip_edges()
	if action_context != "":
		return "You use %s. The moment bends around %s." % [power_name, action_context]
	return "You use %s. The world notices what your body can do." % power_name

func _mode_allows_powers() -> bool:
	if gs == null:
		return false

	if gs.has_method("is_feature_enabled") and gs.is_feature_enabled("superpowers"):
		return true

	var mode: String = _reality_mode()
	return mode in _safe_array(_safe_dictionary(active_contract.get("spawn_rules", {})).get("enabled_modes", ["chaos", "fantasy"]))

func _reality_mode() -> String:
	if gs == null:
		return ""
	if "reality_mode" in gs:
		return str(gs.reality_mode).strip_edges().to_lower()
	return ""

func _context_actor(context: Dictionary = {}) -> Person:
	if gs != null and gs.player != null:
		return gs.player

	var actor_id: int = int(context.get("player_id", context.get("actor_id", -1)))
	if actor_id > 0:
		return _person_by_id(actor_id)

	return null

func _actor_from_payload(payload: Variant = {}) -> Person:
	if payload is Person:
		var direct_actor: Person = payload as Person
		return direct_actor

	if typeof(payload) == TYPE_DICTIONARY:
		var payload_dict: Dictionary = payload as Dictionary

		var embedded_raw: Variant = payload_dict.get("person", null)
		if embedded_raw is Person:
			var embedded_actor: Person = embedded_raw as Person
			return embedded_actor

		var actor_id: int = int(payload_dict.get("actor_id", payload_dict.get("person_id", payload_dict.get("npc_id", payload_dict.get("child_id", -1)))))
		if actor_id > 0:
			var resolved_actor: Person = _person_by_id(actor_id)
			if resolved_actor != null:
				return resolved_actor

	if gs != null and gs.player != null and gs.player is Person:
		var player_actor: Person = gs.player as Person
		return player_actor

	return null

func _person_by_id(person_id: int) -> Person:
	if gs == null or person_id <= 0:
		return null
	if gs.has_method("get_or_reactivate_npc_by_id"):
		var revived = gs.get_or_reactivate_npc_by_id(person_id)
		if revived is Person:
			return revived
	if gs.has_method("get_npc_by_id"):
		var found = gs.get_npc_by_id(person_id)
		if found is Person:
			return found
	return null

func _person_key(actor: Person) -> String:
	if actor == null:
		return "-1"
	return str(int(actor.id))

func _person_label(actor: Person) -> String:
	if actor == null:
		return "Unknown"
	if actor.has_method("full_name"):
		return str(actor.full_name())
	if "first_name" in actor and "last_name" in actor:
		return "%s %s" % [str(actor.first_name), str(actor.last_name)]
	return "Person %d" % int(actor.id)

func _world_state() -> Dictionary:
	if gs == null:
		return _normalize_state({})
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	var raw: Variant = gs.scenario_state.get(STATE_KEY, {})
	var state: Dictionary = {}
	if typeof(raw) == TYPE_DICTIONARY:
		state = (raw as Dictionary).duplicate(true)
	state = _normalize_state(state)
	gs.scenario_state [STATE_KEY] = state
	return state

func _normalize_state(state: Dictionary) -> Dictionary:
	var out: Dictionary = state.duplicate(true)
	out ["schema"] = str(out.get("schema", STATE_SCHEMA))
	out ["version"] = max(CONTRACT_VERSION, int(out.get("version", 1)))
	out ["save_key"] = str(out.get("save_key", STATE_KEY))
	out ["persistent"] = bool(out.get("persistent", true))
	out ["backwards_compatible"] = bool(out.get("backwards_compatible", true))
	out ["preserve_unknown_fields"] = bool(out.get("preserve_unknown_fields", true))

	if typeof(out.get("person_power_state", {})) != TYPE_DICTIONARY:
		out ["person_power_state"] = {}
	if typeof(out.get("power_event_ledger", [])) != TYPE_ARRAY:
		out ["power_event_ledger"] = []
	if typeof(out.get("contract_registry", {})) != TYPE_DICTIONARY:
		out ["contract_registry"] = {}
	if typeof(out.get("origin_registry", {})) != TYPE_DICTIONARY:
		out ["origin_registry"] = {}

	return out

func _commit_world_state(state: Dictionary) -> void:
	if gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	gs.scenario_state [STATE_KEY] = _normalize_state(state)

func _record_power_event(report: Dictionary) -> void:
	var state: Dictionary = _world_state()
	var ledger: Array = _safe_array(state.get("power_event_ledger", []))
	ledger.append(report.duplicate(true))
	while ledger.size() > MAX_POWER_EVENT_LEDGER:
		ledger.pop_front()
	state ["power_event_ledger"] = ledger
	state ["last_power_report"] = report.duplicate(true)
	_commit_world_state(state)

	if gs != null and gs.event_bus != null:
		if "event_name" in report:
			gs.event_bus.emit(str(report.get("event_name", "power.event")), report)

func _current_year() -> int:
	if gs == null:
		return 0
	return int(gs.year)

func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)

func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)

func _merge_dict(base: Dictionary, overlay: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	for raw_key in overlay.keys():
		var key: Variant = raw_key
		var incoming: Variant = overlay.get(key)
		if typeof(incoming) == TYPE_DICTIONARY and typeof(out.get(key, {})) == TYPE_DICTIONARY:
			out [key] = _merge_dict(_safe_dictionary(out.get(key, {})), _safe_dictionary(incoming))
		elif typeof(incoming) == TYPE_DICTIONARY:
			out [key] = _safe_dictionary(incoming)
		elif typeof(incoming) == TYPE_ARRAY:
			out [key] = (incoming as Array).duplicate(true)
		else:
			out [key] = incoming
	return out