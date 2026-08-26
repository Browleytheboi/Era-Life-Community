extends Resource
class_name EraDataLoader

var gs

var property_templates_by_id: Dictionary = {}
var transport_templates_by_id: Dictionary = {}
var property_templates_by_era: Dictionary = {}
var transport_templates_by_era: Dictionary = {}

func _init(_gs):
	gs = _gs





func load_external_eras():
	var dir = DirAccess.open("res://data/eras")
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			var path = "res://data/eras/" + file_name
			var f = FileAccess.open(path, FileAccess.READ)
			var parsed = JSON.parse_string(f.get_as_text())
			f.close()
			if typeof(parsed) == TYPE_DICTIONARY:
				var key = parsed.get("key", file_name.get_basename())
				gs.era_engine.eras [key] = parsed
		file_name = dir.get_next()
	dir.list_dir_end()







func load_asset_catalogs() -> void:
	property_templates_by_id.clear()
	transport_templates_by_id.clear()
	property_templates_by_era.clear()
	transport_templates_by_era.clear()
	_load_asset_dir("res://data/assets/properties", "property")
	_load_asset_dir("res://data/assets/transports", "transport")

func _load_asset_dir(dir_path: String, asset_kind: String) -> void:
	var dir:= DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name:= dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			var path:= dir_path + "/" + file_name
			var f:= FileAccess.open(path, FileAccess.READ)
			if f != null:
				var parsed = JSON.parse_string(f.get_as_text())
				f.close()
				if parsed is Array:
					for raw in parsed:
						if typeof(raw) == TYPE_DICTIONARY:
							_ingest_asset_template(raw, asset_kind)
				elif typeof(parsed) == TYPE_DICTIONARY:
					if parsed.has("templates") and parsed ["templates"] is Array:
						for raw in parsed ["templates"]:
							if typeof(raw) == TYPE_DICTIONARY:
								_ingest_asset_template(raw, asset_kind)
					else:
						_ingest_asset_template(parsed, asset_kind)
		file_name = dir.get_next()
	dir.list_dir_end()

func _ingest_asset_template(raw: Dictionary, asset_kind: String) -> void:
	var template:= _normalize_asset_template(raw, asset_kind)
	var template_id:= str(template.get("template_id", ""))
	if template_id == "":
		return

	if asset_kind == "property":
		property_templates_by_id [template_id] = template
		_append_template_to_eras(template, property_templates_by_era)
	else:
		transport_templates_by_id [template_id] = template
		_append_template_to_eras(template, transport_templates_by_era)

func _normalize_asset_template(raw: Dictionary, asset_kind: String) -> Dictionary:
	var out: Dictionary = raw.duplicate(true)
	out ["asset_kind"] = asset_kind
	out ["template_id"] = str(out.get("template_id", out.get("id", "")))
	out ["archetype"] = str(out.get("archetype", "generic"))
	out ["subtype"] = str(out.get("subtype", ""))
	out ["display_name"] = str(out.get("display_name", out.get("name", out.get("type", out ["archetype"]))))
	out ["era_tags"] = _as_string_array(out.get("era_tags", out.get("eras", [])))
	out ["social_tier"] = str(out.get("social_tier", "common"))
	out ["feature_tags"] = _merge_string_arrays(
		_as_string_array(out.get("feature_tags", out.get("tags", []))),
		_as_string_array(out.get("identity_tags", []))
	)
	out ["requirement_tags"] = _merge_string_arrays(
		_as_string_array(out.get("requirement_tags", out.get("requirements", []))),
		_as_string_array(out.get("dependency_tags", []))
	)
	out ["event_hooks"] = _as_string_array(out.get("event_hooks", []))

	var prestige_signals: Dictionary = _as_dictionary(out.get("prestige_signals", out.get("social_signals", {})))
	var status_signals: Dictionary = _as_dictionary(out.get("status_signals", out.get("social_meaning", {})))
	for key in prestige_signals.keys():
		if not status_signals.has(key):
			status_signals [key] = prestige_signals [key]
	out ["prestige_signals"] = prestige_signals
	out ["status_signals"] = status_signals

	var pricing_rules: Dictionary = _as_dictionary(out.get("pricing_rules", {}))
	if not pricing_rules.has("era_multiplier"):
		pricing_rules ["era_multiplier"] = 1.0
	if not pricing_rules.has("region_multiplier"):
		pricing_rules ["region_multiplier"] = 1.0
	if not pricing_rules.has("market_climate_multiplier"):
		pricing_rules ["market_climate_multiplier"] = 1.0
	if not pricing_rules.has("class_desirability_multiplier"):
		pricing_rules ["class_desirability_multiplier"] = 1.0
	if not pricing_rules.has("scarcity_multiplier"):
		pricing_rules ["scarcity_multiplier"] = 1.0
	if not pricing_rules.has("local_variation_min"):
		pricing_rules ["local_variation_min"] = 0.9
	if not pricing_rules.has("local_variation_max"):
		pricing_rules ["local_variation_max"] = 1.12
	out ["pricing_rules"] = pricing_rules

	var upkeep_profile: Dictionary = _as_dictionary(out.get("upkeep_profile", {}))
	if not upkeep_profile.has("maintenance_intensity"):
		upkeep_profile ["maintenance_intensity"] = 1.0
	if not upkeep_profile.has("yearly_upkeep_ratio"):
		upkeep_profile ["yearly_upkeep_ratio"] = 0.015
	if not upkeep_profile.has("security_burden"):
		upkeep_profile ["security_burden"] = 0.0
	out ["upkeep_profile"] = upkeep_profile

	var operational_profile: Dictionary = _as_dictionary(out.get("operational_profile", {}))
	if not operational_profile.has("fuel"):
		operational_profile ["fuel"] = 0.0
	if not operational_profile.has("feed"):
		operational_profile ["feed"] = 0.0
	if not operational_profile.has("energy_use"):
		operational_profile ["energy_use"] = 0.0
	if not operational_profile.has("cargo_capacity"):
		operational_profile ["cargo_capacity"] = 0.0
	if not operational_profile.has("passenger_capacity"):
		operational_profile ["passenger_capacity"] = 0.0
	if not operational_profile.has("concealment"):
		operational_profile ["concealment"] = 0.0
	if not operational_profile.has("comfort"):
		operational_profile ["comfort"] = 0.0
	if not operational_profile.has("travel_range"):
		operational_profile ["travel_range"] = 0.0
	if not operational_profile.has("speed_class"):
		operational_profile ["speed_class"] = 0.0
	if not operational_profile.has("crew_burden"):
		operational_profile ["crew_burden"] = 0.0
	if not operational_profile.has("storage_pressure"):
		operational_profile ["storage_pressure"] = 0.0
	if not operational_profile.has("family_capacity"):
		operational_profile ["family_capacity"] = 0.0
	out ["operational_profile"] = operational_profile

	out ["passive_modifiers"] = _as_dictionary(out.get("passive_modifiers", out.get("passive_effects", {})))

	var pressure_profile: Dictionary = _as_dictionary(out.get("pressure_profile", out.get("story_pressure", {})))
	if not pressure_profile.has("upkeep"):
		pressure_profile ["upkeep"] = float(upkeep_profile.get("maintenance_intensity", 1.0)) - 1.0
	if not pressure_profile.has("dependency"):
		pressure_profile ["dependency"] = float(out ["requirement_tags"].size()) * 0.5
	if not pressure_profile.has("spectacle"):
		pressure_profile ["spectacle"] = 0.0
	if not pressure_profile.has("authority_suspicion"):
		pressure_profile ["authority_suspicion"] = 0.0
	if not pressure_profile.has("criminal_usefulness"):
		pressure_profile ["criminal_usefulness"] = 0.0
	if not pressure_profile.has("community_belonging"):
		pressure_profile ["community_belonging"] = 0.0
	if not pressure_profile.has("romance_signal"):
		pressure_profile ["romance_signal"] = 0.0

	if "luxury" in out ["feature_tags"] or "celebrity" in out ["feature_tags"]:
		pressure_profile ["spectacle"] = float(pressure_profile.get("spectacle", 0.0)) + 2.0
		pressure_profile ["romance_signal"] = float(pressure_profile.get("romance_signal", 0.0)) + 1.5
	if "fortified" in out ["feature_tags"] or "noble" in out ["feature_tags"] or "family_seat" in out ["feature_tags"]:
		pressure_profile ["authority_suspicion"] = float(pressure_profile.get("authority_suspicion", 0.0)) + 1.5
		pressure_profile ["community_belonging"] = float(pressure_profile.get("community_belonging", 0.0)) + 1.0
	if "hidden" in out ["feature_tags"] or "criminal" in out ["feature_tags"]:
		pressure_profile ["criminal_usefulness"] = float(pressure_profile.get("criminal_usefulness", 0.0)) + 2.0
	if "cargo" in out ["feature_tags"] or "commercial" in out ["feature_tags"]:
		pressure_profile ["upkeep"] = float(pressure_profile.get("upkeep", 0.0)) + 0.5
	out ["pressure_profile"] = pressure_profile

	var default_ownership_roles: Array = ["owner", "co_owner", "heir", "caretaker", "staff"]
	var default_access_roles: Array = ["owner", "household_user", "staff"]
	if asset_kind == "property":
		default_ownership_roles = ["owner", "co_owner", "heir", "tenant", "caretaker", "manager", "staff"]
		default_access_roles = ["owner", "tenant", "household_user", "caretaker", "manager", "staff"]
	else:
		default_ownership_roles = ["owner", "co_owner", "heir", "assigned_driver", "captain", "caretaker", "staff"]
		default_access_roles = ["owner", "household_user", "assigned_driver", "captain", "caretaker", "staff"]
	out ["ownership_roles"] = _as_string_array(out.get("ownership_roles", default_ownership_roles))
	out ["access_roles"] = _as_string_array(out.get("access_roles", default_access_roles))

	out ["portfolio_tags"] = _merge_string_arrays(
		_as_string_array(out.get("portfolio_tags", out.get("collection_tags", []))),
		_derived_portfolio_tags(asset_kind, out)
	)
	out ["action_ids"] = _normalized_action_ids(out)
	out ["rarity"] = max(0.1, float(out.get("rarity", 1.0)))

	var base_value: int = int(out.get("base_value", out.get("price", out.get("value", 0))))
	out ["base_value"] = base_value

	var derived_value_band:= "entry"
	if base_value >= 2000000:
		derived_value_band = "prestige"
	elif base_value >= 500000:
		derived_value_band = "luxury"
	elif base_value >= 100000:
		derived_value_band = "wealthy"
	elif base_value >= 25000:
		derived_value_band = "respectable"
	elif base_value >= 5000:
		derived_value_band = "working"
	out ["value_band"] = str(out.get("value_band", derived_value_band))

	out ["size"] = str(out.get("size", ""))
	out ["default_condition"] = float(out.get("default_condition", 100.0))
	out ["legacy_type"] = str(out.get("legacy_type", out.get("type", out ["display_name"])))
	return out


func template_matches_context(template: Dictionary, context:= {}) -> bool:
	return _template_matches_context(template, context)


func get_best_property_template_for_context(era_name: String, context:= {}) -> Dictionary:
	return _best_template_for_context(get_property_templates_for_era(era_name), context)


func get_best_transport_template_for_context(era_name: String, context:= {}) -> Dictionary:
	return _best_template_for_context(get_transport_templates_for_era(era_name), context)


func _best_template_for_context(templates: Array, context:= {}) -> Dictionary:
	var best_template: Dictionary = {}
	var best_score: float = -1000000000.0
	for raw_template in templates:
		if typeof(raw_template) != TYPE_DICTIONARY:
			continue
		var template: Dictionary = raw_template
		if not _template_matches_context(template, context):
			continue
		var score: float = _score_template_for_context(template, context) + randf_range(0.0, 0.25)
		if score > best_score:
			best_score = score
			best_template = template.duplicate(true)
	return best_template


func _template_matches_context(template: Dictionary, context:= {}) -> bool:
	var template_id:= str(context.get("template_id", ""))
	if template_id != "" and str(template.get("template_id", "")) != template_id:
		return false

	var archetype:= str(context.get("archetype", ""))
	if archetype != "" and str(template.get("archetype", "")) != archetype:
		return false

	var subtype:= str(context.get("subtype", ""))
	if subtype != "" and str(template.get("subtype", "")) != subtype:
		return false

	var size:= str(context.get("size", ""))
	if size != "" and str(template.get("size", "")) != size:
		return false

	var social_tier:= str(context.get("social_tier", ""))
	if social_tier != "" and str(template.get("social_tier", "")) != social_tier:
		return false

	var value_band:= str(context.get("value_band", ""))
	if value_band != "" and str(template.get("value_band", "")) != value_band:
		return false

	var desired_tags: Array = _as_string_array(context.get("desired_tags", []))
	var excluded_tags: Array = _as_string_array(context.get("excluded_tags", []))
	var required_action_ids: Array = _as_string_array(context.get("required_action_ids", []))
	var required_requirement_tags: Array = _as_string_array(context.get("required_requirement_tags", []))
	var preferred_portfolio_tags: Array = _as_string_array(context.get("preferred_portfolio_tags", []))
	var required_event_hooks: Array = _as_string_array(context.get("required_event_hooks", []))
	var required_ownership_roles: Array = _as_string_array(context.get("required_ownership_roles", []))
	var required_access_roles: Array = _as_string_array(context.get("required_access_roles", []))

	var feature_tags: Array = template.get("feature_tags", [])
	var action_ids: Array = template.get("action_ids", [])
	var requirement_tags: Array = template.get("requirement_tags", [])
	var portfolio_tags: Array = template.get("portfolio_tags", [])
	var event_hooks: Array = template.get("event_hooks", [])
	var ownership_roles: Array = template.get("ownership_roles", [])
	var access_roles: Array = template.get("access_roles", [])

	for tag in desired_tags:
		if tag not in feature_tags:
			return false

	for tag in excluded_tags:
		if tag in feature_tags:
			return false

	for action_id in required_action_ids:
		if action_id not in action_ids:
			return false

	for req in required_requirement_tags:
		if req not in requirement_tags:
			return false

	for hook_name in required_event_hooks:
		if hook_name not in event_hooks:
			return false

	for role_name in required_ownership_roles:
		if role_name not in ownership_roles:
			return false

	for role_name in required_access_roles:
		if role_name not in access_roles:
			return false

	if not preferred_portfolio_tags.is_empty():
		var any_portfolio_match:= false
		for tag in preferred_portfolio_tags:
			if tag in portfolio_tags:
				any_portfolio_match = true
				break
		if not any_portfolio_match:
			return false

	var min_base_value: int = int(context.get("min_base_value", -1))
	if min_base_value >= 0 and int(template.get("base_value", 0)) < min_base_value:
		return false

	var max_base_value: int = int(context.get("max_base_value", -1))
	if max_base_value >= 0 and int(template.get("base_value", 0)) > max_base_value:
		return false

	var min_status_signals: Dictionary = _as_dictionary(context.get("min_status_signals", {}))
	var status_signals: Dictionary = template.get("status_signals", template.get("prestige_signals", {}))
	for key in min_status_signals.keys():
		if float(status_signals.get(key, 0.0)) < float(min_status_signals.get(key, 0.0)):
			return false

	var min_operational_profile: Dictionary = _as_dictionary(context.get("min_operational_profile", {}))
	var max_operational_profile: Dictionary = _as_dictionary(context.get("max_operational_profile", {}))
	var operational_profile: Dictionary = template.get("operational_profile", {})
	for key in min_operational_profile.keys():
		if float(operational_profile.get(key, 0.0)) < float(min_operational_profile.get(key, 0.0)):
			return false
	for key in max_operational_profile.keys():
		if float(operational_profile.get(key, 0.0)) > float(max_operational_profile.get(key, 999999.0)):
			return false

	var required_pressure_keys: Array = _as_string_array(context.get("required_pressure_keys", []))
	var pressure_profile: Dictionary = template.get("pressure_profile", {})
	for key_name in required_pressure_keys:
		if not pressure_profile.has(key_name):
			return false

	return true


func _score_template_for_context(template: Dictionary, context:= {}) -> float:
	var score: float = 0.0
	var feature_tags: Array = template.get("feature_tags", [])
	var portfolio_tags: Array = template.get("portfolio_tags", [])
	var requirement_tags: Array = template.get("requirement_tags", [])
	var event_hooks: Array = template.get("event_hooks", [])
	var operational_profile: Dictionary = template.get("operational_profile", {})
	var status_signals: Dictionary = template.get("status_signals", template.get("prestige_signals", {}))
	var pressure_profile: Dictionary = template.get("pressure_profile", {})

	for tag in _as_string_array(context.get("desired_tags", [])):
		if tag in feature_tags:
			score += 4.0

	for tag in _as_string_array(context.get("preferred_portfolio_tags", [])):
		if tag in portfolio_tags:
			score += 3.5

	for req in _as_string_array(context.get("required_requirement_tags", [])):
		if req in requirement_tags:
			score += 2.25

	for hook_name in _as_string_array(context.get("required_event_hooks", [])):
		if hook_name in event_hooks:
			score += 2.0

	var archetype:= str(context.get("archetype", ""))
	if archetype != "" and str(template.get("archetype", "")) == archetype:
		score += 6.0

	var subtype:= str(context.get("subtype", ""))
	if subtype != "" and str(template.get("subtype", "")) == subtype:
		score += 6.0

	var size:= str(context.get("size", ""))
	if size != "" and str(template.get("size", "")) == size:
		score += 4.0

	var social_tier:= str(context.get("social_tier", ""))
	if social_tier != "" and str(template.get("social_tier", "")) == social_tier:
		score += 5.0

	var value_band:= str(context.get("value_band", ""))
	if value_band != "" and str(template.get("value_band", "")) == value_band:
		score += 4.5

	var query_text:= str(context.get("query_text", "")).strip_edges().to_lower()
	if query_text != "":
		var parts:= [
			str(template.get("display_name", "")).to_lower(),
			str(template.get("legacy_type", "")).to_lower(),
			str(template.get("archetype", "")).to_lower(),
			str(template.get("subtype", "")).to_lower(),
			str(template.get("size", "")).to_lower(),
			str(template.get("social_tier", "")).to_lower()
		]
		for part in parts:
			if part == "":
				continue
			if part.find(query_text) >= 0 or query_text.find(part) >= 0:
				score += 3.0
				break

	var preferred_status_signals: Dictionary = _as_dictionary(context.get("preferred_status_signals", {}))
	for key in preferred_status_signals.keys():
		var desired_value: float = float(preferred_status_signals.get(key, 0.0))
		var actual_value: float = float(status_signals.get(key, 0.0))
		score += max(0.0, 3.0 - abs(desired_value - actual_value))

	var min_operational_profile: Dictionary = _as_dictionary(context.get("min_operational_profile", {}))
	for key in min_operational_profile.keys():
		var desired_floor: float = max(0.001, float(min_operational_profile.get(key, 0.0)))
		var actual_value: float = float(operational_profile.get(key, 0.0))
		score += clamp(actual_value / desired_floor, 0.0, 1.5) * 2.0

	for pressure_key in _as_string_array(context.get("required_pressure_keys", [])):
		if pressure_profile.has(pressure_key):
			score += 1.5

	var base_value: int = int(template.get("base_value", 0))
	var min_base_value: int = int(context.get("min_base_value", -1))
	var max_base_value: int = int(context.get("max_base_value", -1))
	if min_base_value >= 0 and base_value >= min_base_value:
		score += 1.0
	if max_base_value >= 0 and base_value <= max_base_value:
		score += 1.0

	score += clamp(float(template.get("rarity", 1.0)), 0.0, 3.0)
	return score


func _normalized_action_ids(
	template: Dictionary
) -> Array:
	var asset_kind: String = str(
		template.get(
			"asset_kind",
			""
		)
	)
	var feature_tags: Array = template.get(
		"feature_tags",
		[]
	)
	var requirement_tags: Array = template.get(
		"requirement_tags",
		[]
	)
	var explicit: Array = _as_string_array(
		template.get(
			"action_ids",
			template.get(
				"actions",
				[]
			)
		)
	)

	if not explicit.is_empty():
		if (
			asset_kind == "property"
			and not explicit.has(
				"throw_party"
			)
		):
			explicit.append(
				"throw_party"
			)

		return _unique_string_array(
			explicit
		)

	var out: Array = [
		"inspect",
		"rename",
		"sell",
		"gift",
		"maintain",
		"repair"
	]

	if asset_kind == "property":
		out.append(
			"rest"
		)
		out.append(
			"use"
		)
		out.append(
			"renovate"
		)
		out.append(
			"throw_party"
		)

		if "fortified" in feature_tags:
			out.append(
				"fortify"
			)

		if (
			"ceremonial" in feature_tags
			or "family_seat" in feature_tags
			or "noble" in feature_tags
		):
			out.append(
				"hold_ceremony"
			)

		if "hidden" in feature_tags:
			out.append(
				"store_contraband"
			)

		if (
			"commercial" in feature_tags
			or "urban" in feature_tags
		):
			out.append(
				"open_to_tenants"
			)

		if (
			"family_seat" in feature_tags
			or "noble" in feature_tags
		):
			out.append(
				"host_feast"
			)
	else:
		out.append(
			"use"
		)

		if "animal" in feature_tags:
			out.append(
				"ride"
			)

		if (
			"land" in feature_tags
			and "animal" not in feature_tags
		):
			out.append(
				"drive"
			)

		if "water" in feature_tags:
			out.append(
				"sail"
			)

		if (
			"air" in feature_tags
			or "space" in feature_tags
		):
			out.append(
				"fly"
			)

		if (
			"cargo" in feature_tags
			or "commercial" in feature_tags
		):
			out.append(
				"transport_goods"
			)

		if (
			"luxury" in feature_tags
			or "family_seat" in feature_tags
		):
			out.append(
				"road_trip"
			)

		if "crew_required" in requirement_tags:
			out.append(
				"assign_captain"
			)

		if "security_sensitive" in requirement_tags:
			out.append(
				"assign_driver"
			)

		if (
			"fortified" in feature_tags
			or "military" in feature_tags
		):
			out.append(
				"activate_defense_grid"
			)

	return _unique_string_array(
		out
	)


func _derived_portfolio_tags(asset_kind: String, template: Dictionary) -> Array:
	var out: Array = []
	var feature_tags: Array = template.get("feature_tags", [])

	if asset_kind == "property":
		out.append("holdings")
		if "fortified" in feature_tags or "family_seat" in feature_tags or "noble" in feature_tags:
			out.append("dynastic_properties")
		if "hidden" in feature_tags:
			out.append("safehouses")
		if "commercial" in feature_tags:
			out.append("rentals")
	else:
		out.append("mobility_pool")
		if "animal" in feature_tags:
			out.append("stables")
		if "water" in feature_tags:
			out.append("fleets")
		if "cargo" in feature_tags:
			out.append("trade_routes")
		if "air" in feature_tags or "space" in feature_tags:
			out.append("hangars")

	return _unique_string_array(out)


func _merge_string_arrays(a: Array, b: Array) -> Array:
	var merged: Array = []
	merged.append_array(a)
	merged.append_array(b)
	return _unique_string_array(merged)


func _unique_string_array(values: Array) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for raw in values:
		var s:= str(raw)
		if s == "":
			continue
		if seen.has(s):
			continue
		seen [s] = true
		out.append(s)
	return out

func _append_template_to_eras(template: Dictionary, bucket: Dictionary) -> void:
	for era_key in _era_keys_from_template(template):
		if not bucket.has(era_key):
			bucket [era_key] = []
		bucket [era_key].append(template)

func _era_keys_from_template(template: Dictionary) -> Array:
	var out: Array = []
	for raw in template.get("era_tags", []):
		var era_name:= str(raw)
		if era_name == "":
			continue
		if era_name not in out:
			out.append(era_name)
	if out.is_empty() and gs != null and gs.era_engine != null:
		for era_name in gs.era_engine.eras.keys():
			out.append(str(era_name))
	return out

func get_property_templates_for_era(era_name: String) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	var keys: Array = []
	var normalized_name: String = str(era_name).strip_edges()

	if normalized_name != "":
		keys.append(normalized_name)

		var lower_name: String = normalized_name.to_lower()
		if lower_name not in keys:
			keys.append(lower_name)

		var snake_name: String = lower_name.replace(" ", "_")
		if snake_name not in keys:
			keys.append(snake_name)

		if lower_name.ends_with(" era"):
			var short_title: String = normalized_name.replace(" Era", "")
			var short_lower: String = lower_name.replace(" era", "")
			var short_snake: String = short_lower.replace(" ", "_")
			if short_title not in keys:
				keys.append(short_title)
			if short_lower not in keys:
				keys.append(short_lower)
			if short_snake not in keys:
				keys.append(short_snake)

	for universal_key in ["any", "Any", "all", "All", "*", "universal", "Universal"]:
		if universal_key not in keys:
			keys.append(universal_key)

	for raw_key in keys:
		var key: String = str(raw_key).strip_edges()
		if key == "":
			continue
		for raw_template in property_templates_by_era.get(key, []):
			if typeof(raw_template) != TYPE_DICTIONARY:
				continue
			var template: Dictionary = raw_template
			var template_id: String = str(template.get("template_id", ""))
			var dedupe_key: String = template_id
			if dedupe_key == "":
				dedupe_key = "%s::%s" % [str(template.get("display_name", "")), key]
			if seen.has(dedupe_key):
				continue
			seen [dedupe_key] = true
			out.append(template.duplicate(true))

	return out

func get_transport_templates_for_era(era_name: String) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	var keys: Array = []
	var normalized_name: String = str(era_name).strip_edges()

	if normalized_name != "":
		keys.append(normalized_name)

		var lower_name: String = normalized_name.to_lower()
		if lower_name not in keys:
			keys.append(lower_name)

		var snake_name: String = lower_name.replace(" ", "_")
		if snake_name not in keys:
			keys.append(snake_name)

		if lower_name.ends_with(" era"):
			var short_title: String = normalized_name.replace(" Era", "")
			var short_lower: String = lower_name.replace(" era", "")
			var short_snake: String = short_lower.replace(" ", "_")
			if short_title not in keys:
				keys.append(short_title)
			if short_lower not in keys:
				keys.append(short_lower)
			if short_snake not in keys:
				keys.append(short_snake)

	for universal_key in ["any", "Any", "all", "All", "*", "universal", "Universal"]:
		if universal_key not in keys:
			keys.append(universal_key)

	for raw_key in keys:
		var key: String = str(raw_key).strip_edges()
		if key == "":
			continue
		for raw_template in transport_templates_by_era.get(key, []):
			if typeof(raw_template) != TYPE_DICTIONARY:
				continue
			var template: Dictionary = raw_template
			var template_id: String = str(template.get("template_id", ""))
			var dedupe_key: String = template_id
			if dedupe_key == "":
				dedupe_key = "%s::%s" % [str(template.get("display_name", "")), key]
			if seen.has(dedupe_key):
				continue
			seen [dedupe_key] = true
			out.append(template.duplicate(true))

	return out

func get_property_template(template_id: String) -> Dictionary:
	return property_templates_by_id.get(template_id, {}).duplicate(true)

func get_transport_template(template_id: String) -> Dictionary:
	return transport_templates_by_id.get(template_id, {}).duplicate(true)

func _as_string_array(value) -> Array:
	var out: Array = []
	if value is Array:
		for raw in value:
			var s:= str(raw)
			if s != "":
				out.append(s)
	return out

func _as_dictionary(value) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return value.duplicate(true)
	return {}