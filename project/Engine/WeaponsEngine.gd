extends Resource
class_name WeaponsEngine

var gs

func _init(_gs):
	gs = _gs
	if gs.mod_loader and gs.mod_loader.mod_data.has("weapons"):
		for era in gs.mod_loader.mod_data ["weapons"].keys():
			if not WEAPON_STORES.has(era):
				WEAPON_STORES [era] = []
			WEAPON_STORES [era].append_array(gs.mod_loader.mod_data ["weapons"] [era])




var WEAPON_STORES = {
	"Ancient Era": [
		{ "name": "Dagger", "cost": 50, "type": "blade", "legal": true, "license_required": false},
		{ "name": "Shortsword", "cost": 120, "type": "blade", "legal": true, "license_required": false},
		{ "name": "Sling", "cost": 30, "type": "ranged", "legal": true, "license_required": false},
		{ "name": "Bow", "cost": 200, "type": "ranged", "legal": true, "license_required": false},
	],

	"Medieval Era": [
		{ "name": "Dagger", "cost": 40, "type": "blade", "legal": true, "license_required": false},
		{ "name": "Longsword", "cost": 200, "type": "blade", "legal": true, "license_required": false},
		{ "name": "Crossbow", "cost": 350, "type": "ranged", "legal": true, "license_required": false},
		{ "name": "Hand Axe", "cost": 100, "type": "blade", "legal": true, "license_required": false},
	],

	"Industrial Era": [
		{ "name": "Pocket Knife", "cost": 20, "type": "blade", "legal": true, "license_required": false},
		{ "name": "Revolver", "cost": 300, "type": "gun", "legal": true, "license_required": true},
		{ "name": "Shotgun", "cost": 450, "type": "gun", "legal": true, "license_required": true},
	],

	"Modern Era": [
		{ "name": "Knife", "cost": 25, "type": "blade", "legal": true, "license_required": false},
		{ "name": "9mm Pistol", "cost": 400, "type": "gun", "legal": true, "license_required": true},
		{ "name": "Shotgun", "cost": 550, "type": "gun", "legal": true, "license_required": true},
		{ "name": "Assault Rifle", "cost": 1200, "type": "gun", "legal": false, "license_required": true},
	],

	"Future Era": [
		{ "name": "Plasma Dagger", "cost": 150, "type": "energy", "legal": true, "license_required": false},
		{ "name": "Pulse Pistol", "cost": 800, "type": "energy", "legal": true, "license_required": true},
		{ "name": "Laser Rifle", "cost": 2000, "type": "energy", "legal": false, "license_required": true},
	]
}
func get_weapon_data(name: String) -> Dictionary:
	return get_weapon_data_for_era(name, _current_era_name())


func get_weapon_data_for_era(name: String, era_name: String) -> Dictionary:
	var clean_name: String = str(name).strip_edges()
	if clean_name == "":
		return {}
	var store: Array = get_store_for_era(era_name)
	for raw_weapon in store:
		if typeof(raw_weapon) != TYPE_DICTIONARY:
			continue
		var weapon: Dictionary = raw_weapon as Dictionary
		if str(weapon.get("name", "")).strip_edges() == clean_name:
			return weapon.duplicate(true)
	return {}


func weapon_exists_in_era(name: String) -> bool:
	return get_weapon_data(name) != {}


func weapon_exists_in_context(name: String, context: Dictionary = {}) -> bool:
	return get_weapon_data_for_era(name, str(context.get("era", _current_era_name()))) != {}


func get_inventory() -> Array:
	if gs == null or gs.player == null:
		return []
	return gs.player.traits.filter(func (t): return str(t).begins_with("Weapon_"))


func owns_weapon(name: String) -> bool:
	if gs == null or gs.player == null:
		return false
	return ("Weapon_" + str(name)) in gs.player.traits


func get_store() -> Array:
	return get_store_for_era(_current_era_name())


func get_store_for_era(era_name: String) -> Array:
	var clean_era: String = str(era_name).strip_edges()
	if clean_era == "":
		clean_era = _current_era_name()
	var store_raw: Variant = WEAPON_STORES.get(clean_era, [])
	if typeof(store_raw) == TYPE_ARRAY:
		return (store_raw as Array).duplicate(true)
	return []

func get_weapon_action_contract(
	weapon_name: String,
	era_name: String = ""
) -> Dictionary:
	var clean_name: String = str(
		weapon_name
	).strip_edges()

	if clean_name == "":
		return {}

	var clean_era: String = str(
		era_name
	).strip_edges()

	if clean_era == "":
		clean_era = _current_era_name()

	var weapon_data: Dictionary = (
		get_weapon_data_for_era(
			clean_name,
			clean_era
		)
	)

	if weapon_data.is_empty():
		return {}

	var profile_id: String = _weapon_action_profile_id(
		weapon_data
	)
	var actions: Array = _weapon_action_rows_for_profile(
		profile_id
	)

	return {
		"schema": "eralife.weapon_action_contract",
		"version": 1,
		"weapon_id": str(
			weapon_data.get(
				"id",
				clean_name.to_lower().replace(
					" ",
					"_"
				)
			)
		),
		"weapon_name": clean_name,
		"weapon_type": str(
			weapon_data.get(
				"type",
				"weapon"
			)
		).strip_edges().to_lower(),
		"profile_id": profile_id,
		"era": clean_era,
		"legal": bool(
			weapon_data.get(
				"legal",
				true
			)
		),
		"license_required": bool(
			weapon_data.get(
				"license_required",
				false
			)
		),
		"actions": actions,
		"action_count": actions.size(),
	}

func _weapon_definition_from_purchase_context(
	weapon_name: String,
	era_name: String,
	context: Dictionary
) -> Dictionary:
	var clean_name: String = str(
		weapon_name
	).strip_edges()
	var candidate: Dictionary = _safe_dictionary(
		context.get(
			"weapon",
			{}
		)
	)
	var object_contract: Dictionary = _safe_dictionary(
		context.get(
			"object_contract",
			candidate.get(
				"object_contract",
				{}
			)
		)
	)

	if (
		not object_contract.is_empty()
		and gs != null
		and gs.weapons_catalog_expansion != null
		and gs.weapons_catalog_expansion.has_method(
			"purchase_definition_from_object"
		)
	):
		candidate = _safe_dictionary(
			gs.weapons_catalog_expansion
				.purchase_definition_from_object(
					object_contract
				)
		)

	var candidate_name: String = str(
		candidate.get(
			"name",
			candidate.get(
				"display_name",
				""
			)
		)
	).strip_edges()

	if (
		not candidate.is_empty()
		and candidate_name.to_lower() == clean_name.to_lower()
		and bool(
			candidate.get(
				"catalog_validated",
				false
			)
		)
	):
		return candidate.duplicate(true)

	var built_in: Dictionary = get_weapon_data_for_era(
		clean_name,
		era_name
	)

	if not built_in.is_empty():
		built_in ["catalog_object_id"] = str(
			built_in.get(
				"catalog_object_id",
				"weapon:%s" % clean_name.to_lower().replace(
					" ",
					"_"
				).replace(
					"-",
					"_"
				)
			)
		)
		built_in ["object_domains"] = [
			"weapon"
		]
		built_in ["catalog_validated"] = true
		built_in ["source_kind"] = "base_weapon_catalog"
		return built_in

	if (
		gs != null
		and gs.weapons_catalog_expansion != null
		and gs.weapons_catalog_expansion.has_method(
			"get_external_weapon_data"
		)
	):
		var external: Dictionary = _safe_dictionary(
			gs.weapons_catalog_expansion.get_external_weapon_data(
				clean_name,
				era_name,
				context
			)
		)

		if not external.is_empty():
			external ["catalog_validated"] = true
			return external

	return {}


func _weapon_contract_from_purchase_definition(
	weapon_data: Dictionary,
	weapon_name: String,
	era_name: String
) -> Dictionary:
	var embedded_contract: Dictionary = _safe_dictionary(
		weapon_data.get(
			"weapon_contract",
			{}
		)
	)

	if not embedded_contract.is_empty():
		embedded_contract ["actions"] = _safe_array(
			embedded_contract.get(
				"actions",
				weapon_data.get(
					"actions",
					[]
				)
			)
		)
		embedded_contract ["action_count"] = (
			embedded_contract ["actions"] as Array
		).size()
		return embedded_contract

	var base_contract: Dictionary = get_weapon_action_contract(
		weapon_name,
		era_name
	)

	if not base_contract.is_empty():
		return base_contract

	var actions: Array = _safe_array(
		weapon_data.get(
			"actions",
			_safe_dictionary(
				weapon_data.get(
					"damage_profile",
					{}
				)
			).get(
				"actions",
				[]
			)
		)
	)

	return {
		"schema": "eralife.weapon_action_contract",
		"version": 1,
		"weapon_id": str(
			weapon_data.get(
				"catalog_object_id",
				weapon_data.get(
					"id",
					weapon_name.to_lower().replace(
						" ",
						"_"
					)
				)
			)
		),
		"weapon_name": weapon_name,
		"weapon_type": str(
			weapon_data.get(
				"type",
				weapon_data.get(
					"weapon_type",
					"weapon"
				)
			)
		).strip_edges().to_lower(),
		"profile_id": str(
			_safe_dictionary(
				weapon_data.get(
					"damage_profile",
					{}
				)
			).get(
				"profile_id",
				"external_weapon"
			)
		),
		"era": era_name,
		"legal": bool(
			weapon_data.get(
				"legal",
				true
			)
		),
		"license_required": bool(
			weapon_data.get(
				"license_required",
				false
			)
		),
		"actions": actions,
		"action_count": actions.size(),
		"modded": bool(
			weapon_data.get(
				"modded",
				false
			)
		),
	}


func _weapon_object_domains(
	weapon_data: Dictionary
) -> Array:
	var out: Array = _safe_array(
		weapon_data.get(
			"object_domains",
			weapon_data.get(
				"domains",
				[]
			)
		)
	)

	if "weapon" not in out:
		out.append(
			"weapon"
		)

	return out
func build_weapon_belongings_actions(
	weapon_item: Dictionary,
	era_name: String = ""
) -> Array:
	var weapon_name: String = str(
		weapon_item.get(
			"name",
			weapon_item.get(
				"display_name",
				""
			)
		)
	).strip_edges()
	var contract: Dictionary = _safe_dictionary(
		weapon_item.get(
			"weapon_contract",
			{}
		)
	)

	if contract.is_empty():
		contract = get_weapon_action_contract(
			weapon_name,
			era_name
		)

	if (
		contract.is_empty()
		and gs != null
		and gs.weapons_catalog_expansion != null
		and gs.weapons_catalog_expansion.has_method(
			"resolve_weapon_definition"
		)
	):
		var definition: Dictionary = _safe_dictionary(
			gs.weapons_catalog_expansion.resolve_weapon_definition(
				weapon_name,
				{
					"era": era_name,
					"include_modded": true
				}
			)
		)

		contract = _weapon_contract_from_purchase_definition(
			definition,
			weapon_name,
			era_name
		)

	var out: Array = []

	for raw_action in _safe_array(
		contract.get(
			"actions",
			[]
		)
	):
		if typeof(
			raw_action
		) != TYPE_DICTIONARY:
			continue

		var weapon_action: Dictionary = (
			raw_action as Dictionary
		)
		var action_id: String = str(
			weapon_action.get(
				"id",
				""
			)
		).strip_edges().to_lower()

		if action_id == "":
			continue

		out.append({
			"id": "weapon_%s" % action_id,
			"label": str(
				weapon_action.get(
					"label",
					action_id.capitalize()
				)
			),
			"engine_property": "crime_hub_contract_engine",
			"method": "resolve_intent",
			"call_mode": "player_payload",
			"refresh_after": true,
			"payload": {
				"action_id": "begin_weapon_action",
				"catalog_object_id": str(
					weapon_item.get(
						"catalog_object_id",
						""
					)
				),
				"instance_object_id": str(
					weapon_item.get(
						"instance_object_id",
						""
					)
				),
				"weapon_name": weapon_name,
				"weapon_action_id": action_id,
				"source_item": (
					weapon_item.duplicate(true)
				),
				"weapon_contract": (
					contract.duplicate(true)
				),
				"source": "belongings.weapon_action"
			}
		})

	return out
func _weapon_action_profile_id(
	weapon: Dictionary
) -> String:
	var weapon_name: String = str(
		weapon.get(
			"name",
			""
		)
	).strip_edges().to_lower()
	var weapon_type: String = str(
		weapon.get(
			"type",
			"weapon"
		)
	).strip_edges().to_lower()

	if (
		"knife" in weapon_name
		or "dagger" in weapon_name
	):
		return "knife"

	if (
		"sword" in weapon_name
		or "blade" in weapon_name
		and weapon_type != "energy"
	):
		return "sword"

	if (
		"axe" in weapon_name
		or "hatchet" in weapon_name
	):
		return "axe"

	if "crossbow" in weapon_name:
		return "crossbow"

	if "bow" in weapon_name:
		return "bow"

	if "sling" in weapon_name:
		return "sling"

	if (
		"shotgun" in weapon_name
	):
		return "shotgun"

	if (
		"rifle" in weapon_name
	):
		return "rifle"

	if (
		"pistol" in weapon_name
		or "revolver" in weapon_name
	):
		return "pistol"

	if (
		weapon_type == "energy"
		and (
			"dagger" in weapon_name
			or "blade" in weapon_name
		)
	):
		return "energy_blade"

	if weapon_type == "energy":
		return "energy_firearm"

	match weapon_type:
		"blade":
			return "knife"
		"ranged":
			return "bow"
		"gun":
			return "pistol"
		_:
			return "improvised_weapon"


func _weapon_action_rows_for_profile(
	profile_id: String
) -> Array:
	match profile_id:
		"knife":
			return [
				_weapon_action(
					"stab",
					"Stab",
					8,
					32,
					0.2,
					[
						"head",
						"torso",
						"arm",
						"hand",
						"leg"
					],
					0.28,
					0.62
				),
				_weapon_action(
					"slash",
					"Slash",
					6,
					24,
					0.11,
					[
						"head",
						"torso",
						"arm",
						"hand",
						"leg"
					],
					0.34,
					0.72
				),
				_weapon_action(
					"poke",
					"Poke",
					2,
					11,
					0.02,
					[
						"arm",
						"hand",
						"leg",
						"torso"
					],
					0.16,
					0.4
				),
				_weapon_action(
					"gouge",
					"Gouge",
					5,
					18,
					0.08,
					[
						"head"
					],
					0.3,
					0.68
				)
			]

		"sword":
			return [
				_weapon_action(
					"slash",
					"Slash",
					10,
					38,
					0.24,
					[
						"head",
						"torso",
						"arm",
						"leg"
					],
					0.4,
					0.8
				),
				_weapon_action(
					"thrust",
					"Thrust",
					12,
					42,
					0.29,
					[
						"torso",
						"arm",
						"leg"
					],
					0.34,
					0.72
				),
				_weapon_action(
					"pommel_strike",
					"Pommel Strike",
					4,
					17,
					0.04,
					[
						"head",
						"torso",
						"arm"
					],
					0.24,
					0.58
				)
			]

		"axe":
			return [
				_weapon_action(
					"chop",
					"Chop",
					14,
					46,
					0.33,
					[
						"head",
						"torso",
						"arm",
						"leg"
					],
					0.46,
					0.84
				),
				_weapon_action(
					"hook",
					"Hook",
					5,
					20,
					0.07,
					[
						"arm",
						"leg",
						"torso"
					],
					0.36,
					0.7
				),
				_weapon_action(
					"blunt_strike",
					"Blunt Strike",
					5,
					22,
					0.06,
					[
						"head",
						"torso",
						"arm",
						"leg"
					],
					0.32,
					0.66
				)
			]

		"bow", "crossbow", "sling":
			return [
				_weapon_action(
					"fire_projectile",
					"Fire",
					9,
					40,
					0.23,
					[
						"head",
						"torso",
						"arm",
						"leg"
					],
					0.48,
					0.74
				),
				_weapon_action(
					"warning_shot",
					"Warning Shot",
					0,
					5,
					0.0,
					[
						"near_target"
					],
					0.64,
					0.9
				),
				_weapon_action(
					"strike_with_weapon",
					"Strike With Weapon",
					3,
					14,
					0.03,
					[
						"head",
						"torso",
						"arm"
					],
					0.24,
					0.54
				)
			]

		"pistol":
			return [
				_weapon_action(
					"fire",
					"Fire",
					15,
					52,
					0.37,
					[
						"head",
						"torso",
						"arm",
						"hand",
						"leg"
					],
					0.96,
					0.94
				),
				_weapon_action(
					"pistol_whip",
					"Pistol Whip",
					4,
					19,
					0.05,
					[
						"head",
						"torso",
						"arm"
					],
					0.34,
					0.64
				),
				_weapon_action(
					"warning_shot",
					"Warning Shot",
					0,
					5,
					0.0,
					[
						"near_target"
					],
					1.0,
					1.0
				)
			]

		"shotgun":
			return [
				_weapon_action(
					"fire",
					"Fire",
					24,
					72,
					0.56,
					[
						"head",
						"torso",
						"arm",
						"leg"
					],
					1.0,
					1.0
				),
				_weapon_action(
					"butt_strike",
					"Butt Strike",
					6,
					24,
					0.06,
					[
						"head",
						"torso",
						"arm"
					],
					0.38,
					0.7
				)
			]

		"rifle":
			return [
				_weapon_action(
					"fire",
					"Fire",
					20,
					64,
					0.48,
					[
						"head",
						"torso",
						"arm",
						"leg"
					],
					1.0,
					0.98
				),
				_weapon_action(
					"butt_strike",
					"Butt Strike",
					6,
					23,
					0.06,
					[
						"head",
						"torso",
						"arm"
					],
					0.4,
					0.72
				),
				_weapon_action(
					"warning_shot",
					"Warning Shot",
					0,
					5,
					0.0,
					[
						"near_target"
					],
					1.0,
					1.0
				)
			]

		"energy_blade":
			return [
				_weapon_action(
					"energy_cut",
					"Energy Cut",
					18,
					58,
					0.44,
					[
						"head",
						"torso",
						"arm",
						"leg"
					],
					0.58,
					0.92
				),
				_weapon_action(
					"energy_thrust",
					"Energy Thrust",
					22,
					64,
					0.5,
					[
						"torso",
						"arm",
						"leg"
					],
					0.52,
					0.86
				)
			]

		"energy_firearm":
			return [
				_weapon_action(
					"energy_discharge",
					"Energy Discharge",
					18,
					68,
					0.5,
					[
						"head",
						"torso",
						"arm",
						"leg"
					],
					0.88,
					0.96
				),
				_weapon_action(
					"stun_pulse",
					"Stun Pulse",
					2,
					16,
					0.01,
					[
						"head",
						"torso",
						"arm",
						"leg"
					],
					0.66,
					0.82
				)
			]

		_:
			return [
				_weapon_action(
					"strike",
					"Strike",
					3,
					18,
					0.04,
					[
						"head",
						"torso",
						"arm",
						"leg"
					],
					0.28,
					0.58
				)
			]


func _weapon_action(
	action_id: String,
	label: String,
	harm_min: int,
	harm_max: int,
	fatality_chance: float,
	body_parts: Array,
	noise: float,
	witness_visibility: float
) -> Dictionary:
	return {
		"id": action_id,
		"label": label,
		"harm_min": harm_min,
		"harm_max": harm_max,
		"fatality_chance": clampf(
			fatality_chance,
			0.0,
			1.0
		),
		"body_parts": body_parts.duplicate(true),
		"noise": clampf(
			noise,
			0.0,
			1.0
		),
		"witness_visibility": clampf(
			witness_visibility,
			0.0,
			1.0
		),
	}

func get_weapons_for_context(context: Dictionary = {}) -> Array:
	var era_name: String = str(context.get("era", _current_era_name())).strip_edges()
	if era_name == "":
		era_name = _current_era_name()
	var country: String = str(context.get("country", _current_country())).strip_edges()
	var city: String = str(context.get("city", _current_city())).strip_edges()
	var store: Array = get_store_for_era(era_name)
	var out: Array = []
	for raw_weapon in store:
		if typeof(raw_weapon) != TYPE_DICTIONARY:
			continue
		var weapon: Dictionary = (raw_weapon as Dictionary).duplicate(true)
		var weapon_name: String = str(weapon.get("name", "")).strip_edges()
		if weapon_name == "":
			continue
		weapon ["id"] = weapon_name.to_lower().replace(" ", "_").replace("-", "_")
		weapon ["display_name"] = weapon_name
		weapon ["era"] = era_name
		weapon ["country"] = country
		weapon ["city"] = city
		weapon ["owned"] = owns_weapon(weapon_name)
		weapon ["can_afford"] = _player_can_afford(int(weapon.get("cost", 0)))
		weapon ["legality_label"] = _weapon_legality_label(weapon)
		weapon ["license_label"] = "License Required" if bool(weapon.get("license_required", false)) else "No License Required"
		weapon ["rick_line"] = _rick_weapon_line_for_context(weapon, context)
		weapon ["contract_tags"] = ["weapon", str(weapon.get("type", "weapon")), era_name, country]
		out.append(weapon)
	return out


func buy_weapon(weapon_name: String) -> String:
	var report: Dictionary = buy_weapon_from_context(weapon_name, {
		"era": _current_era_name(),
		"country": _current_country(),
		"city": _current_city(),
		"vendor": "legacy_weapon_store"
	})
	return str(report.get("text", report.get("popup_text", "")))


func buy_weapon_from_context(
	weapon_name: String,
	context: Dictionary = {}
) -> Dictionary:
	if (
		gs == null
		or gs.player == null
	):
		return _weapon_buy_report(
			false,
			"Weapon Purchase Failed",
			"No active player exists to receive the weapon.",
			weapon_name,
			0
		)

	var clean_name: String = str(
		weapon_name
	).strip_edges()

	if clean_name == "":
		return _weapon_buy_report(
			false,
			"Weapon Purchase Failed",
			"No weapon was selected.",
			clean_name,
			0
		)

	var era_name: String = str(
		context.get(
			"era",
			_current_era_name()
		)
	).strip_edges()

	if era_name == "":
		era_name = _current_era_name()

	var weapon_data: Dictionary = (
		_weapon_definition_from_purchase_context(
			clean_name,
			era_name,
			context
		)
	)

	if weapon_data.is_empty():
		return _weapon_buy_report(
			false,
			"Not Available",
			"%s is not available in the %s." % [
				clean_name,
				era_name
			],
			clean_name,
			0
		)

	var definition_name: String = str(
		weapon_data.get(
			"name",
			weapon_data.get(
				"display_name",
				clean_name
			)
		)
	).strip_edges()

	if definition_name != "":
		clean_name = definition_name

	var cost: int = int(
		weapon_data.get(
			"cost",
			weapon_data.get(
				"value",
				0
			)
		)
	)

	if owns_weapon(
		clean_name
	):
		return _weapon_buy_report(
			false,
			"Already Owned",
			"You already own a %s." % clean_name,
			clean_name,
			cost
		)

	if float(
		gs.player.bank_balance
	) < float(
		cost
	):
		return _weapon_buy_report(
			false,
			"Rick Waits",
			(
				"You cannot afford the %s. Rick does not blink. "
				+ "Somehow that makes it worse."
			) % clean_name,
			clean_name,
			cost
		)

	gs.player.bank_balance -= float(
		cost
	)
	gs.player.traits.append(
		"Weapon_" + clean_name
	)

	var weapon_contract: Dictionary = (
		_weapon_contract_from_purchase_definition(
			weapon_data,
			clean_name,
			era_name
		)
	)
	var object_id: int = int(
		gs.next_id
	)
	var catalog_object_id: String = str(
		weapon_data.get(
			"catalog_object_id",
			weapon_data.get(
				"object_id",
				"weapon:%s" % clean_name.to_lower().replace(
					" ",
					"_"
				).replace(
					"-",
					"_"
				)
			)
		)
	).strip_edges().to_lower()
	var origin_country: String = str(
		context.get(
			"country",
			_current_country()
		)
	)
	var origin_city: String = str(
		context.get(
			"city",
			_current_city()
		)
	)
	var vendor_name: String = "Rick"
	var vendor_raw: Variant = context.get(
		"vendor",
		{}
	)

	if typeof(
		vendor_raw
	) == TYPE_DICTIONARY:
		vendor_name = str(
			(
				vendor_raw as Dictionary
			).get(
				"display_name",
				"Rick"
			)
		)
	elif str(
		vendor_raw
	).strip_edges() != "":
		vendor_name = str(
			vendor_raw
		)

	var weapon_item: Dictionary = {
		"id": object_id,
		"object_id": "object_instance:%d" % object_id,
		"instance_object_id": "object_instance:%d" % object_id,
		"catalog_object_id": catalog_object_id,
		"name": clean_name,
		"display_name": clean_name,
		"type": "Weapon",
		"asset_kind": "weapon",
		"object_domains": _weapon_object_domains(
			weapon_data
		),
		"value": cost,
		"base_value": cost,
		"ability": (
			"%s weapon. Legal: %s. License Required: %s."
			% [
				str(
					weapon_data.get(
						"type",
						"weapon"
					)
				).capitalize(),
				(
					"Yes"
					if bool(
						weapon_data.get(
							"legal",
							true
						)
					)
					else "No"
				),
				(
					"Yes"
					if bool(
						weapon_data.get(
							"license_required",
							false
						)
					)
					else "No"
				)
			]
		),
		"lore": str(
			weapon_data.get(
				"lore",
				"A %s purchased from %s during the %s." % [
					str(
						weapon_data.get(
							"type",
							"weapon"
						)
					),
					vendor_name,
					era_name
				]
			)
		),
		"origin_era": era_name,
		"origin_country": origin_country,
		"origin_city": origin_city,
		"origin_vendor": vendor_name,
		"origin_contract": {
			"era": era_name,
			"year": _current_year(),
			"country": origin_country,
			"city": origin_city,
			"vendor": vendor_name,
			"source_contract_id": str(
				context.get(
					"contract_id",
					""
				)
			)
		},
		"acquired_year": _current_year(),
		"ownership_chain": [
			{
				"owner_id": int(
					gs.player.id
				),
				"acquired_year": _current_year(),
				"mode": "purchase",
				"vendor": vendor_name
			}
		],
		"legal": bool(
			weapon_data.get(
				"legal",
				true
			)
		),
		"legal_classification": str(
			weapon_data.get(
				"legal_classification",
				"weapon"
			)
		),
		"license_required": bool(
			weapon_data.get(
				"license_required",
				false
			)
		),
		"weapon_contract": (
			weapon_contract.duplicate(true)
		),
		"damage_profile": _safe_dictionary(
			weapon_data.get(
				"damage_profile",
				{}
			)
		),
		"provider_ids": _safe_array(
			weapon_data.get(
				"provider_ids",
				[
					"weapons_engine",
					"weapons_catalog_expansion"
				]
			)
		),
		"mod_id": str(
			weapon_data.get(
				"mod_id",
				""
			)
		),
		"modded": bool(
			weapon_data.get(
				"modded",
				false
			)
		),
		"affordances": [
			"weapon_action_provider",
			"crime_method_provider",
			"heirloom_candidate",
			"artifact_candidate",
			"object_history_anchor"
		],
		"cross_reality_persistent": true,
		"object_history": [
			{
				"event_type": "object_purchased",
				"year": _current_year(),
				"owner_id": int(
					gs.player.id
				),
				"vendor": vendor_name,
				"contract_id": str(
					context.get(
						"contract_id",
						""
					)
				)
			}
		],
	}

	weapon_item ["actions"] = build_weapon_belongings_actions(
		weapon_item,
		era_name
	)
	weapon_item ["behavior_contract"] = {
		"actions": _safe_array(
			weapon_item.get(
				"actions",
				[]
			)
		),
		"mutation_authority": "weapons_engine",
		"crime_validation_authority": (
			"crime_contract_engine"
		),
		"consequence_authority": "crime_engine",
		"catalog_is_read_only": true
	}

	gs.next_id += 1

	if (
		gs.belongings_engine != null
		and not gs.belongings_engine.has_item_named(
			gs.player,
			"Weapons",
			clean_name
		)
	):
		gs.belongings_engine.add_item(
			gs.player,
			weapon_item,
			"Weapons",
			false,
			{
				"source": "weapons_engine.purchase",
				"catalog_object_id": catalog_object_id,
				"instance_object_id": str(
					weapon_item.get(
						"instance_object_id",
						""
					)
				),
				"contract_id": str(
					context.get(
						"contract_id",
						""
					)
				)
			}
		)

	var memory_text: String = "I bought a %s from %s." % [
		clean_name,
		vendor_name
	]

	gs.player.memories.append(
		memory_text
	)

	var success_text: String = (
		"%s slides the %s across the counter. "
		+ "\"Careful. The thing you buy is never just the thing.\"\n\n"
		+ "You bought a %s for %d coins."
	) % [
		vendor_name,
		clean_name,
		clean_name,
		cost
	]

	return {
		"success": true,
		"mode": "weapon_purchase",
		"weapon_name": clean_name,
		"catalog_object_id": catalog_object_id,
		"instance_object_id": str(
			weapon_item.get(
				"instance_object_id",
				""
			)
		),
		"weapon_data": weapon_data.duplicate(true),
		"weapon_contract": weapon_contract.duplicate(true),
		"belongings_item": weapon_item.duplicate(true),
		"weapon_action_count": int(
			weapon_contract.get(
				"action_count",
				0
			)
		),
		"cost": cost,
		"text": success_text,
		"popup_title": "Weapon Acquired",
		"popup_text": success_text,
		"popup_footer": "Tap anywhere to continue.",
		"memory_text": memory_text,
	}

func _weapon_buy_report(success: bool, title: String, text: String, weapon_name: String, cost: int) -> Dictionary:
	return {
		"success": success,
		"mode": "weapon_purchase",
		"weapon_name": weapon_name,
		"cost": cost,
		"text": text,
		"popup_title": title,
		"popup_text": text,
		"popup_footer": "Tap anywhere to continue."
	}


func _weapon_legality_label(weapon: Dictionary) -> String:
	if not bool(weapon.get("legal", true)):
		return "Illegal / Restricted"
	if bool(weapon.get("license_required", false)):
		return "Legal With License"
	return "Legal"


func _rick_weapon_line_for_context(weapon: Dictionary, context: Dictionary = {}) -> String:
	var weapon_type: String = str(weapon.get("type", "weapon")).strip_edges().to_lower()
	var era_name: String = str(context.get("era", _current_era_name())).strip_edges()
	match weapon_type:
		"blade":
			return "Rick rests two fingers on the flat of the blade like he is checking its pulse."
		"ranged":
			return "Rick checks the string, the balance, then your eyes."
		"gun":
			return "Rick unlocks the case before you ask. That is either service or prophecy."
		"energy":
			return "Rick lets the charge hum for exactly one second too long."
		_:
			return "Rick says this one belongs to the %s, which sounds less like salesmanship and more like a warning." % era_name


func _player_can_afford(cost: int) -> bool:
	if gs == null or gs.player == null:
		return false
	return float(gs.player.bank_balance) >= float(cost)


func _current_era_name() -> String:
	if gs != null and gs.era != null:
		return str(gs.era.name if "name" in gs.era else gs.era).strip_edges()
	return "Modern Era"


func _current_country() -> String:
	if gs != null and gs.player != null:
		for key in ["country", "birth_country", "current_country", "home_country"]:
			var value: String = str(gs.player.get(key) if gs.player.has_method("get") else "").strip_edges()
			if value != "":
				return value
	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		var state_country: String = str(gs.scenario_state.get("country", gs.scenario_state.get("birth_country", ""))).strip_edges()
		if state_country != "":
			return state_country
	return "United States"


func _current_city() -> String:
	if gs != null and gs.player != null:
		for key in ["city", "birth_city", "current_city", "home_city"]:
			var value: String = str(gs.player.get(key) if gs.player.has_method("get") else "").strip_edges()
			if value != "":
				return value
	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		var state_city: String = str(gs.scenario_state.get("city", gs.scenario_state.get("birth_city", ""))).strip_edges()
		if state_city != "":
			return state_city
	return "Unknown City"


func _current_year() -> int:
	if gs == null:
		return 0
	if "year" in gs:
		return int(gs.year)
	if "scenario_state" in gs and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		return int(gs.scenario_state.get("year", 0))
	return 0


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(
	value: Variant
) -> Array:
	if typeof(
		value
	) == TYPE_ARRAY:
		return (
			value as Array
		).duplicate(true)

	return []