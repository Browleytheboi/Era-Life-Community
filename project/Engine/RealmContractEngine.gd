extends Resource
class_name RealmContractEngine

const CONTRACT_VERSION:= 1

const SECTION_INTERREALM:= "interrealm_authority"
const SECTION_SPACE:= "space_realms"
const SECTION_IMAGINATIVE:= "imaginative_realms"
const SECTION_ELEMENTAL:= "elemental_realms"
const SECTION_STANDARD:= "standard_realms"

const ALLOWED_SECTIONS:= [
	SECTION_INTERREALM,
	SECTION_SPACE,
	SECTION_IMAGINATIVE,
	SECTION_ELEMENTAL,
	SECTION_STANDARD
]

var gs
var registry: Dictionary = {}
var validation_reports: Dictionary = {}
var external_surface_entries: Dictionary = {}
var external_pack_registry: Dictionary = {}
var external_pack_file_mtimes: Dictionary = {}
var last_hot_reload_report: Dictionary = {}

func _init(_gs = null):
	gs = _gs

func normalize_surface_entry(entry: Dictionary, source_hint: String = "") -> Dictionary:
	if typeof(entry) != TYPE_DICTIONARY or entry.is_empty():
		return {}

	var out: Dictionary = entry.duplicate(true)
	var realm_raw: Variant = out.get("realm", {})
	var realm: Dictionary = realm_raw if typeof(realm_raw) == TYPE_DICTIONARY else {}

	var context:= {
		"entry_kind": str(out.get("entry_kind", "realm")).strip_edges(),
		"entry_id": str(out.get("entry_id", realm.get("id", ""))).strip_edges(),
		"name": str(out.get("name", realm.get("name", "Realm"))).strip_edges(),
		"source_hint": source_hint
	}

	var contract: Dictionary = normalize_realm_contract(realm, context)
	var normalized_realm: Dictionary = apply_contract_to_realm(realm, contract)

	out ["entry_kind"] = str(contract.get("entry_kind", context.get("entry_kind", "realm")))
	out ["entry_id"] = str(contract.get("id", context.get("entry_id", ""))).strip_edges()
	out ["name"] = str(contract.get("name", context.get("name", "Realm"))).strip_edges()
	out ["realm_id"] = int(out.get("realm_id", out.get("entry_id", -1)))
	out ["realm"] = normalized_realm
	out ["realm_contract"] = contract.duplicate(true)
	out ["_sort_priority"] = int(contract.get("sort_priority", out.get("_sort_priority", 99)))

	var contract_id: String = str(contract.get("id", "")).strip_edges()
	if contract_id != "":
		registry [contract_id] = contract.duplicate(true)

	return out

func normalize_realm_contract(realm: Dictionary, context: Dictionary = {}) -> Dictionary:
	var entry_id: String = str(context.get("entry_id", realm.get("id", ""))).strip_edges()
	var entry_kind: String = str(context.get("entry_kind", realm.get("entry_kind", "realm"))).strip_edges()
	var realm_name: String = str(context.get("name", realm.get("display_name", realm.get("name", "")))).strip_edges()

	if realm_name == "":
		realm_name = "Unknown Realm"
	if entry_id == "":
		entry_id = _stable_id_from_name(realm_name)

	var visual_theme: String = str(realm.get("browser_visual_theme", realm.get("overview_visual_theme", ""))).strip_edges().to_lower()
	var native_element: String = str(realm.get("native_element", "")).strip_edges().to_lower()
	var realm_kind: String = str(realm.get("realm_kind", "")).strip_edges().to_lower()
	var realm_type: String = str(realm.get("realm_type", realm.get("dimension_type", ""))).strip_edges().to_lower()
	var dimension_type: String = str(realm.get("dimension_type", realm_type)).strip_edges().to_lower()
	var section: String = _resolve_browser_section(entry_id, entry_kind, realm, visual_theme, native_element, realm_kind, realm_type, dimension_type)

	var errors: Array = []
	var warnings: Array = []

	if not ALLOWED_SECTIONS.has(section):
		warnings.append("Invalid browser section '%s'. Falling back to standard realms." % section)
		section = SECTION_STANDARD

	if realm_kind == "":
		realm_kind = _fallback_realm_kind_from_section(section)
		warnings.append("Missing realm_kind. Applied '%s'." % realm_kind)

	if realm_type == "":
		realm_type = _fallback_realm_type_from_section(section)
		warnings.append("Missing realm_type. Applied '%s'." % realm_type)

	if dimension_type == "":
		dimension_type = realm_type

	var population: int = _coerce_nonnegative_int(realm.get("population", realm.get("resident_count", 0)), 0)
	var military: int = _coerce_nonnegative_int(realm.get("military", realm.get("military_stockpile", realm.get("military_units", 0))), 0)
	var military_units: int = _coerce_nonnegative_int(realm.get("military_units", military), military)
	var military_stockpile: int = _coerce_nonnegative_int(realm.get("military_stockpile", military_units), military_units)
	var treasury: int = _coerce_nonnegative_int(realm.get("treasury", 0), 0)

	var allow_non_population_military: bool = bool(realm.get("allow_non_population_military", false))
	if section == SECTION_SPACE or realm_type in ["star_forge", "soul_gate"]:
		allow_non_population_military = true

	if population <= 0 and section != SECTION_SPACE:
		population = 1
		warnings.append("Population was missing or invalid. Applied minimum population fallback.")

	if not allow_non_population_military and population > 0:
		if military > population:
			warnings.append("Military exceeded population. Clamped display military to population.")
			military = population
		if military_units > population:
			military_units = population
		if military_stockpile > population:
			military_stockpile = population

	var contract:= {
		"schema": "eralife.realm_contract",
		"version": CONTRACT_VERSION,
		"id": entry_id,
		"name": realm_name,
		"display_name": str(realm.get("display_name", realm_name)).strip_edges(),
		"entry_kind": entry_kind,
		"kind": realm_kind,
		"type": realm_type,
		"dimension_type": dimension_type,
		"browser_section": section,
		"source_engine": str(context.get("source_hint", realm.get("source_engine", ""))).strip_edges(),
		"sort_priority": _resolve_sort_priority(section, entry_id, realm),
		"identity": {
			"native_element": native_element,
			"is_elemental": section == SECTION_ELEMENTAL or native_element in ["air", "water", "earth", "fire"],
			"is_hidden": bool(realm.get("visible_to_owner_only", false)) or section == SECTION_INTERREALM,
			"is_country_surface": true
		},
		"metrics": {
			"population": population,
			"resident_count": _coerce_nonnegative_int(realm.get("resident_count", population), population),
			"military": military,
			"military_units": military_units,
			"military_stockpile": military_stockpile,
			"treasury": treasury,
			"goods_stockpile": _coerce_nonnegative_int(realm.get("goods_stockpile", 0), 0),
			"land": _coerce_nonnegative_int(realm.get("land", realm.get("land_size", 0)), 0)
		},
		"governance": {
			"government_style": str(realm.get("government_style", "Unknown")).strip_edges(),
			"ruler_id": realm.get("ruler_id", -1),
			"ruler_name": str(realm.get("ruler_name", "")).strip_edges(),
			"leader_title": str(realm.get("leader_title", "Leader")).strip_edges(),
			"guide_name": str(realm.get("guide_name", "")).strip_edges(),
			"capital_city": str(realm.get("capital_city", "")).strip_edges()
		},
		"access": {
			"entry_method": str(realm.get("entry_method", "")).strip_edges(),
			"entry_rule": str(realm.get("entry_rule", realm.get("access_rule", ""))).strip_edges(),
			"visibility_rule": str(realm.get("visibility_rule", "")).strip_edges(),
			"surface_view_only": bool(realm.get("surface_view_only", false)),
			"persistence": str(realm.get("persistence", "runtime")).strip_edges()
		},
		"actions": {
			"hide_migrate": bool(realm.get("hide_country_action_migrate", false)),
			"show_vacation": bool(realm.get("show_country_action_vacation", true)),
			"show_find_date": bool(realm.get("show_country_action_find_date", true)),
			"hide_actions_in_overview": bool(realm.get("hide_country_actions_in_overview", false)),
			"visit_label": str(realm.get("browser_visit_button_label", realm.get("action_label", "Visit"))).strip_edges(),
			"overview_label": str(realm.get("browser_overview_label", "Open Overview")).strip_edges()
		},
		"visual": {
			"browser_theme": _resolve_browser_theme(section, visual_theme, native_element, entry_id),
			"overview_theme": str(realm.get("overview_visual_theme", visual_theme)).strip_edges().to_lower(),
			"special_card_kind": str(realm.get("special_card_kind", "")).strip_edges().to_lower(),
			"aura_strength": float(realm.get("browser_aura_strength", 0.0)),
			"aura_bg_alpha": float(realm.get("browser_aura_bg_alpha", 0.0)),
			"aura_shadow_alpha": float(realm.get("browser_aura_shadow_alpha", 0.0)),
			"aura_shadow_size": int(realm.get("browser_aura_shadow_size", 0))
		},
		"content": {
			"description": str(realm.get("description", "")).strip_edges(),
			"summary_lines": _safe_string_array(realm.get("browser_summary_lines", [])),
			"subzones": _safe_string_array(realm.get("subzones", realm.get("notable_zones", []))),
			"notable_zones": _safe_string_array(realm.get("notable_zones", realm.get("subzones", [])))
		},
		"behavior": _normalize_behavior_contract(realm.get("behavior", realm), entry_id),
		"simulation_layers": _normalize_simulation_layers_contract(realm.get("simulation_layers", {}), entry_id),
		"validation": {
			"valid": errors.is_empty(),
			"errors": errors,
			"warnings": warnings
		}
	}

	validation_reports [entry_id] = contract ["validation"].duplicate(true)
	return contract

func apply_contract_to_realm(realm: Dictionary, contract: Dictionary) -> Dictionary:
	var out: Dictionary = realm.duplicate(true)

	var metrics: Dictionary = contract.get("metrics", {})
	var governance: Dictionary = contract.get("governance", {})
	var access: Dictionary = contract.get("access", {})
	var actions: Dictionary = contract.get("actions", {})
	var visual: Dictionary = contract.get("visual", {})
	var identity: Dictionary = contract.get("identity", {})
	var content: Dictionary = contract.get("content", {})
	var behavior: Dictionary = contract.get("behavior", {})
	var simulation_layers: Dictionary = contract.get("simulation_layers", {})

	out ["realm_contract_version"] = int(contract.get("version", CONTRACT_VERSION))
	out ["realm_contract"] = contract.duplicate(true)

	out ["id"] = str(contract.get("id", out.get("id", ""))).strip_edges()
	out ["name"] = str(contract.get("name", out.get("name", "Realm"))).strip_edges()
	out ["display_name"] = str(contract.get("display_name", out.get("display_name", out ["name"]))).strip_edges()

	out ["realm_kind"] = str(contract.get("kind", out.get("realm_kind", "state"))).strip_edges()
	out ["realm_type"] = str(contract.get("type", out.get("realm_type", "standard"))).strip_edges()
	out ["dimension_type"] = str(contract.get("dimension_type", out.get("dimension_type", out ["realm_type"]))).strip_edges()
	out ["realm_browser_section"] = str(contract.get("browser_section", out.get("realm_browser_section", SECTION_STANDARD))).strip_edges()

	out ["native_element"] = str(identity.get("native_element", out.get("native_element", ""))).strip_edges()
	out ["elemental_realm"] = bool(identity.get("is_elemental", out.get("elemental_realm", false)))
	out ["visible_to_owner_only"] = bool(identity.get("is_hidden", out.get("visible_to_owner_only", false)))
	out ["is_country_surface"] = bool(identity.get("is_country_surface", true))

	out ["population"] = int(metrics.get("population", out.get("population", 0)))
	out ["resident_count"] = int(metrics.get("resident_count", out.get("resident_count", out ["population"])))
	out ["military"] = int(metrics.get("military", out.get("military", 0)))
	out ["military_units"] = int(metrics.get("military_units", out.get("military_units", out ["military"])))
	out ["military_stockpile"] = int(metrics.get("military_stockpile", out.get("military_stockpile", out ["military_units"])))
	out ["treasury"] = int(metrics.get("treasury", out.get("treasury", 0)))
	out ["goods_stockpile"] = int(metrics.get("goods_stockpile", out.get("goods_stockpile", 0)))
	out ["land"] = int(metrics.get("land", out.get("land", out.get("land_size", 0))))

	out ["government_style"] = str(governance.get("government_style", out.get("government_style", "Unknown"))).strip_edges()
	out ["ruler_id"] = governance.get("ruler_id", out.get("ruler_id", -1))
	out ["ruler_name"] = str(governance.get("ruler_name", out.get("ruler_name", ""))).strip_edges()
	out ["leader_title"] = str(governance.get("leader_title", out.get("leader_title", "Leader"))).strip_edges()
	out ["guide_name"] = str(governance.get("guide_name", out.get("guide_name", ""))).strip_edges()
	out ["capital_city"] = str(governance.get("capital_city", out.get("capital_city", ""))).strip_edges()

	out ["entry_method"] = str(access.get("entry_method", out.get("entry_method", ""))).strip_edges()
	out ["entry_rule"] = str(access.get("entry_rule", out.get("entry_rule", ""))).strip_edges()
	out ["visibility_rule"] = str(access.get("visibility_rule", out.get("visibility_rule", ""))).strip_edges()
	out ["surface_view_only"] = bool(access.get("surface_view_only", out.get("surface_view_only", false)))
	out ["persistence"] = str(access.get("persistence", out.get("persistence", "runtime"))).strip_edges()

	out ["hide_country_action_migrate"] = bool(actions.get("hide_migrate", out.get("hide_country_action_migrate", false)))
	out ["show_country_action_vacation"] = bool(actions.get("show_vacation", out.get("show_country_action_vacation", true)))
	out ["show_country_action_find_date"] = bool(actions.get("show_find_date", out.get("show_country_action_find_date", true)))
	out ["hide_country_actions_in_overview"] = bool(actions.get("hide_actions_in_overview", out.get("hide_country_actions_in_overview", false)))
	out ["action_label"] = str(actions.get("visit_label", out.get("action_label", "Visit"))).strip_edges()
	out ["browser_visit_button_label"] = str(actions.get("visit_label", out.get("browser_visit_button_label", out ["action_label"]))).strip_edges()
	out ["browser_overview_label"] = str(actions.get("overview_label", out.get("browser_overview_label", "Open Overview"))).strip_edges()

	out ["browser_visual_theme"] = str(visual.get("browser_theme", out.get("browser_visual_theme", ""))).strip_edges()
	out ["overview_visual_theme"] = str(visual.get("overview_theme", out.get("overview_visual_theme", out ["browser_visual_theme"]))).strip_edges()
	out ["special_card_kind"] = str(visual.get("special_card_kind", out.get("special_card_kind", ""))).strip_edges()

	out ["browser_aura_strength"] = float(visual.get("aura_strength", out.get("browser_aura_strength", 0.0)))
	out ["browser_aura_bg_alpha"] = float(visual.get("aura_bg_alpha", out.get("browser_aura_bg_alpha", 0.0)))
	out ["browser_aura_shadow_alpha"] = float(visual.get("aura_shadow_alpha", out.get("browser_aura_shadow_alpha", 0.0)))
	out ["browser_aura_shadow_size"] = int(visual.get("aura_shadow_size", out.get("browser_aura_shadow_size", 0)))

	out ["description"] = str(content.get("description", out.get("description", ""))).strip_edges()
	out ["browser_summary_lines"] = _safe_string_array(content.get("summary_lines", out.get("browser_summary_lines", [])))
	out ["subzones"] = _safe_string_array(content.get("subzones", out.get("subzones", [])))
	out ["notable_zones"] = _safe_string_array(content.get("notable_zones", out.get("notable_zones", out ["subzones"])))
	out ["subzone_count"] = max(int(out.get("subzone_count", 0)), out ["subzones"].size())
	out ["behavior"] = behavior.duplicate(true)
	out ["simulation_layers"] = simulation_layers.duplicate(true)

	out ["time_model"] = str(behavior.get("time_model", out.get("time_model", "normal"))).strip_edges()
	out ["population_model"] = str(behavior.get("population_model", out.get("population_model", "static"))).strip_edges()
	out ["faction_pressure_model"] = str(behavior.get("faction_pressure_model", out.get("faction_pressure_model", "stable"))).strip_edges()
	out ["death_logic"] = str(behavior.get("death_logic", out.get("death_logic", "normal"))).strip_edges()

	return out

func refresh_runtime_registry() -> Dictionary:
	registry.clear()

	if gs == null:
		return registry

	if gs.realm_engine != null:
		var realms_raw: Variant = gs.realm_engine.realms
		var realms: Dictionary = realms_raw if typeof(realms_raw) == TYPE_DICTIONARY else {}
		for raw_realm_id in realms.keys():
			var realm_raw: Variant = realms.get(raw_realm_id, {})
			var realm: Dictionary = realm_raw if typeof(realm_raw) == TYPE_DICTIONARY else {}
			if realm.is_empty():
				continue
			var entry:= {
				"entry_kind": "realm",
				"entry_id": str(raw_realm_id),
				"name": str(realm.get("name", "Realm")),
				"realm_id": int(raw_realm_id),
				"realm": realm.duplicate(true)
			}
			normalize_surface_entry(entry, "realm_engine")

	if gs.many_realms_engine != null:
		var hidden_raw: Variant = gs.many_realms_engine.hidden_realms
		var hidden_realms: Dictionary = hidden_raw if typeof(hidden_raw) == TYPE_DICTIONARY else {}
		for raw_hidden_id in hidden_realms.keys():
			var hidden_id: String = str(raw_hidden_id).strip_edges()
			var hidden_realm_raw: Variant = hidden_realms.get(raw_hidden_id, {})
			var hidden_realm: Dictionary = hidden_realm_raw if typeof(hidden_realm_raw) == TYPE_DICTIONARY else {}
			if hidden_id == "" or hidden_realm.is_empty():
				continue
			var hidden_entry:= {
				"entry_kind": "hidden_realm",
				"entry_id": hidden_id,
				"name": str(hidden_realm.get("name", "Hidden Realm")),
				"hidden_realm_id": hidden_id,
				"realm": hidden_realm.duplicate(true)
			}
			normalize_surface_entry(hidden_entry, "many_realms_engine")

	_register_optional_surface_engine("bridge_to_terabithia_engine")
	_register_optional_surface_engine("vormir_engine")
	_register_optional_surface_engine("nidavellir_engine")

	for external_id in external_surface_entries.keys():
		var entry_raw: Variant = external_surface_entries.get(external_id, {})
		if typeof(entry_raw) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_raw
		var realm_raw: Variant = entry.get("realm", {})
		if typeof(realm_raw) != TYPE_DICTIONARY:
			continue
		normalize_surface_entry(entry, "external_json_pack")

	return registry

func repair_runtime_realm_maps() -> void:
	if gs == null:
		return

	if gs.realm_engine != null:
		var realms_raw: Variant = gs.realm_engine.realms
		var realms: Dictionary = realms_raw if typeof(realms_raw) == TYPE_DICTIONARY else {}
		for raw_realm_id in realms.keys():
			var realm_raw: Variant = realms.get(raw_realm_id, {})
			var realm: Dictionary = realm_raw if typeof(realm_raw) == TYPE_DICTIONARY else {}
			if realm.is_empty():
				continue
			var entry:= {
				"entry_kind": "realm",
				"entry_id": str(raw_realm_id),
				"name": str(realm.get("name", "Realm")),
				"realm_id": int(raw_realm_id),
				"realm": realm.duplicate(true)
			}
			var normalized: Dictionary = normalize_surface_entry(entry, "realm_engine")
			if not normalized.is_empty():
				realms [raw_realm_id] = normalized.get("realm", realm)
		gs.realm_engine.realms = realms

	if gs.many_realms_engine != null:
		var hidden_raw: Variant = gs.many_realms_engine.hidden_realms
		var hidden_realms: Dictionary = hidden_raw if typeof(hidden_raw) == TYPE_DICTIONARY else {}
		for raw_hidden_id in hidden_realms.keys():
			var hidden_id: String = str(raw_hidden_id).strip_edges()
			var hidden_realm_raw: Variant = hidden_realms.get(raw_hidden_id, {})
			var hidden_realm: Dictionary = hidden_realm_raw if typeof(hidden_realm_raw) == TYPE_DICTIONARY else {}
			if hidden_id == "" or hidden_realm.is_empty():
				continue
			var entry:= {
				"entry_kind": "hidden_realm",
				"entry_id": hidden_id,
				"name": str(hidden_realm.get("name", "Hidden Realm")),
				"hidden_realm_id": hidden_id,
				"realm": hidden_realm.duplicate(true)
			}
			var normalized: Dictionary = normalize_surface_entry(entry, "many_realms_engine")
			if not normalized.is_empty():
				hidden_realms [raw_hidden_id] = normalized.get("realm", hidden_realm)
		gs.many_realms_engine.hidden_realms = hidden_realms

func export_registry() -> Dictionary:
	refresh_runtime_registry()
	return _make_binary_safe({
		"schema": "eralife.realm_contract_registry",
		"version": CONTRACT_VERSION,
		"registry": registry.duplicate(true),
		"validation_reports": validation_reports.duplicate(true)
	})

func import_registry(data: Dictionary) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return

	var registry_raw: Variant = data.get("registry", data)
	var incoming_registry: Dictionary = registry_raw if typeof(registry_raw) == TYPE_DICTIONARY else {}
	registry.clear()

	for raw_id in incoming_registry.keys():
		var contract_raw: Variant = incoming_registry.get(raw_id, {})
		if typeof(contract_raw) != TYPE_DICTIONARY:
			continue
		var contract: Dictionary = (contract_raw as Dictionary).duplicate(true)
		var contract_id: String = str(contract.get("id", raw_id)).strip_edges()
		if contract_id == "":
			continue
		registry [contract_id] = contract

	var reports_raw: Variant = data.get("validation_reports", {})
	if typeof(reports_raw) == TYPE_DICTIONARY:
		validation_reports = (reports_raw as Dictionary).duplicate(true)

func get_contract(realm_id: String) -> Dictionary:
	var clean_id: String = str(realm_id).strip_edges()
	if clean_id == "":
		return {}
	var raw: Variant = registry.get(clean_id, {})
	return raw if typeof(raw) == TYPE_DICTIONARY else {}

func _register_optional_surface_engine(property_name: String) -> void:
	if gs == null:
		return
	var engine: Variant = gs.get(property_name) if gs.has_method("get") else null
	if engine == null:
		return
	if not engine.has_method("get_surface_entry_for_player"):
		return
	var entry_raw: Variant = engine.get_surface_entry_for_player()
	if typeof(entry_raw) != TYPE_DICTIONARY:
		return
	var entry: Dictionary = entry_raw
	if entry.is_empty():
		return
	normalize_surface_entry(entry, property_name)

func _resolve_browser_section(entry_id: String, entry_kind: String, realm: Dictionary, visual_theme: String, native_element: String, realm_kind: String, realm_type: String, dimension_type: String) -> String:
	var explicit_section: String = str(realm.get("realm_browser_section", "")).strip_edges().to_lower()
	if explicit_section != "":
		return explicit_section

	if entry_id == "era_kingdom":
		return SECTION_INTERREALM

	if entry_kind == "space_realm" or realm_kind == "space_realm" or dimension_type == "space_realm":
		return SECTION_SPACE

	if visual_theme in ["nidavellir", "vormir"] or realm_type in ["star_forge", "soul_gate"]:
		return SECTION_SPACE

	if entry_kind == "imaginative_realm" or realm_kind == "imaginative_realm" or realm_type == "imagination_bound" or visual_theme == "terabithia":
		return SECTION_IMAGINATIVE

	if bool(realm.get("elemental_realm", false)) or native_element in ["air", "water", "earth", "fire"] or visual_theme.begins_with("elemental_"):
		return SECTION_ELEMENTAL

	return SECTION_STANDARD

func _resolve_sort_priority(section: String, entry_id: String, realm: Dictionary) -> int:
	if realm.has("_sort_priority"):
		return int(realm.get("_sort_priority", 99))
	match section:
		SECTION_INTERREALM:
			return 0
		SECTION_SPACE:
			if entry_id == "nidavellir":
				return 3
			return 4
		SECTION_IMAGINATIVE:
			return 5
		SECTION_ELEMENTAL:
			return 6
		_:
			return 10

func _resolve_browser_theme(section: String, visual_theme: String, native_element: String, entry_id: String) -> String:
	if visual_theme != "":
		return visual_theme
	if native_element in ["air", "water", "earth", "fire"]:
		return "elemental_%s" % native_element
	match section:
		SECTION_INTERREALM:
			return "era_kingdom"
		SECTION_SPACE:
			return entry_id
		SECTION_IMAGINATIVE:
			return "terabithia"
		_:
			return ""

func _fallback_realm_kind_from_section(section: String) -> String:
	match section:
		SECTION_INTERREALM:
			return "sovereign_hidden_country"
		SECTION_SPACE:
			return "space_realm"
		SECTION_IMAGINATIVE:
			return "imaginative_realm"
		SECTION_ELEMENTAL:
			return "elemental_realm"
		_:
			return "state"

func _fallback_realm_type_from_section(section: String) -> String:
	match section:
		SECTION_INTERREALM:
			return "hidden_parallel_realm"
		SECTION_SPACE:
			return "space_realm"
		SECTION_IMAGINATIVE:
			return "imagination_bound"
		SECTION_ELEMENTAL:
			return "elemental_nation"
		_:
			return "standard_realm"

func _stable_id_from_name(name: String) -> String:
	var clean: String = str(name).strip_edges().to_lower()
	clean = clean.replace(" ", "_")
	clean = clean.replace("-", "_")
	clean = clean.replace("/", "_")
	clean = clean.replace("'", "")
	clean = clean.replace("’", "")
	clean = clean.replace("•", "_")
	clean = clean.replace("__", "_")
	if clean == "":
		return "unknown_realm"
	return clean

func _coerce_nonnegative_int(value: Variant, fallback: int = 0) -> int:
	var out: int = fallback
	match typeof(value):
		TYPE_INT:
			out = int(value)
		TYPE_FLOAT:
			out = int(round(float(value)))
		TYPE_STRING:
			var clean: String = str(value).strip_edges()
			if clean.is_valid_int():
				out = int(clean)
			elif clean.is_valid_float():
				out = int(round(float(clean)))
	return max(0, out)

func _safe_string_array(value: Variant) -> Array:
	var out: Array = []
	if typeof(value) != TYPE_ARRAY:
		return out
	for raw in value:
		var clean: String = str(raw).strip_edges()
		if clean == "":
			continue
		out.append(clean)
	return out
func ingest_external_realm_pack(pack: Dictionary) -> Dictionary:
	var report:= {
		"pack_id": str(pack.get("id", "external_pack")),
		"ingested": [],
		"failed": []
	}

	external_pack_registry [str(pack.get("id", "external_pack"))] = pack.duplicate(true)

	var realms: Array = pack.get("realms", [])
	for raw_realm in realms:
		if typeof(raw_realm) != TYPE_DICTIONARY:
			report ["failed"].append({ "reason": "Realm entry was not a Dictionary."})
			continue

		var realm: Dictionary = (raw_realm as Dictionary).duplicate(true)
		var realm_id: String = str(realm.get("id", "")).strip_edges()
		if realm_id == "":
			realm_id = _stable_id_from_name(str(realm.get("name", "external_realm")))
			realm ["id"] = realm_id

		var entry:= {
			"entry_kind": str(realm.get("entry_kind", "external_realm")),
			"entry_id": realm_id,
			"name": str(realm.get("name", realm_id)),
			"realm": realm,
			"_sort_priority": int(realm.get("_sort_priority", 12))
		}

		var normalized: Dictionary = normalize_surface_entry(entry, "external_json_pack")
		if normalized.is_empty():
			report ["failed"].append({ "realm_id": realm_id, "reason": "Normalization returned empty entry."})
			continue

		external_surface_entries [realm_id] = normalized.duplicate(true)
		report ["ingested"].append(realm_id)

	return report

func get_external_surface_entries() -> Array:
	var out: Array = []
	for realm_id in external_surface_entries.keys():
		var entry_raw: Variant = external_surface_entries.get(realm_id, {})
		if typeof(entry_raw) != TYPE_DICTIONARY:
			continue
		out.append((entry_raw as Dictionary).duplicate(true))
	return out

func clear_external_surface_entries() -> void:
	external_surface_entries.clear()

func hot_reload_external_packs(force: bool = false) -> Dictionary:
	if gs == null or gs.simulation_contract_engine == null:
		return {
			"success": false,
			"reason": "SimulationContractEngine is unavailable."
		}

	if not gs.simulation_contract_engine.has_method("hot_reload_external_packs"):
		return {
			"success": false,
			"reason": "SimulationContractEngine has no hot_reload_external_packs method."
		}

	var report: Dictionary = gs.simulation_contract_engine.hot_reload_external_packs(force)
	last_hot_reload_report = report.duplicate(true)
	return report

func get_debug_report() -> Dictionary:
	var simulation_report: Dictionary = {}
	if gs != null and gs.simulation_contract_engine != null and gs.simulation_contract_engine.has_method("get_debug_report"):
		simulation_report = gs.simulation_contract_engine.get_debug_report()

	return _make_binary_safe({
		"schema": "eralife.realm_contract_debug_report",
		"version": CONTRACT_VERSION,
		"registry_count": registry.size(),
		"external_surface_count": external_surface_entries.size(),
		"external_pack_count": external_pack_registry.size(),
		"validation_reports": validation_reports.duplicate(true),
		"external_surface_entries": external_surface_entries.duplicate(true),
		"last_hot_reload_report": last_hot_reload_report.duplicate(true),
		"simulation_contract_report": simulation_report
	})

func _normalize_behavior_contract(raw_behavior: Variant, owner_id: String = "") -> Dictionary:
	if gs != null and gs.simulation_contract_engine != null and gs.simulation_contract_engine.has_method("normalize_behavior_contract"):
		return gs.simulation_contract_engine.normalize_behavior_contract(raw_behavior, owner_id)

	var behavior: Dictionary = raw_behavior if typeof(raw_behavior) == TYPE_DICTIONARY else {}
	return {
		"owner_id": owner_id,
		"time_model": str(behavior.get("time_model", "normal")).strip_edges().to_lower(),
		"population_model": str(behavior.get("population_model", "static")).strip_edges().to_lower(),
		"faction_pressure_model": str(behavior.get("faction_pressure_model", "stable")).strip_edges().to_lower(),
		"death_logic": str(behavior.get("death_logic", "normal")).strip_edges().to_lower(),
		"growth_rate": clamp(float(behavior.get("growth_rate", 0.025)), -0.5, 0.5),
		"pressure_rate": clamp(float(behavior.get("pressure_rate", 0.08)), 0.0, 1.0),
		"validation": {
			"valid": true,
			"errors": [],
			"warnings": []
		}
	}

func _normalize_simulation_layers_contract(raw_layers: Variant, owner_id: String = "") -> Dictionary:
	if gs != null and gs.simulation_contract_engine != null and gs.simulation_contract_engine.has_method("normalize_simulation_layers"):
		return gs.simulation_contract_engine.normalize_simulation_layers(raw_layers, owner_id)

	var out: Dictionary = {}
	var layers: Dictionary = raw_layers if typeof(raw_layers) == TYPE_DICTIONARY else {}
	for raw_key in layers.keys():
		var layer_key: String = str(raw_key).strip_edges().to_lower()
		var layer_raw: Variant = layers.get(raw_key, {})
		var layer: Dictionary = layer_raw if typeof(layer_raw) == TYPE_DICTIONARY else {}
		out [layer_key] = {
			"owner_id": owner_id,
			"layer": layer_key,
			"enabled": bool(layer.get("enabled", true)),
			"model": str(layer.get("model", "default")).strip_edges().to_lower(),
			"weight": clamp(float(layer.get("weight", 1.0)), 0.0, 10.0),
			"rules": layer.get("rules", {}).duplicate(true) if typeof(layer.get("rules", {})) == TYPE_DICTIONARY else {}
		}
	return out
func _make_binary_safe(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var out:= {}
			for key in value.keys():
				out [str(key)] = _make_binary_safe(value [key])
			return out
		TYPE_ARRAY:
			var arr:= []
			for item in value:
				arr.append(_make_binary_safe(item))
			return arr
		TYPE_COLOR:
			var c: Color = value
			return "#%s" % c.to_html(true)
		TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_BOOL:
			return value
		TYPE_NIL:
			return null
		_:
			return str(value)