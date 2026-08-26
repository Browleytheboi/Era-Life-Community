extends Resource
class_name RealmEngine

const ENGINE_SCHEMA:= "eralife.realm_engine"

var gs

func _init(_gs):
	gs = _gs

var realms = {}
var resident_realm_id_order: Array = []
var resident_realm_id_seen: Dictionary = {}
func bootstrap_realms_for_era(_payload:= {}):
	realms.clear()

	var payload: Dictionary = _payload.duplicate(true) if typeof(_payload) == TYPE_DICTIONARY else {}
	var era_key: String = _bootstrap_era_key(payload)
	var era: String = _bootstrap_era_name(payload, era_key)
	var starts = {
		"Ancient Era": [
			{ "name": "Egypt", "population": randi_range(180000, 950000), "land": randi_range(280, 880), "treasury": randi_range(900000, 6500000), "currency_name": "Deben", "government_style": "Monarchy"},
			{ "name": "Sparta", "population": randi_range(90000, 320000), "land": randi_range(120, 360), "treasury": randi_range(450000, 2800000), "currency_name": "Drachmae", "government_style": "Monarchy"},
			{ "name": "Babylon", "population": randi_range(160000, 780000), "land": randi_range(220, 740), "treasury": randi_range(800000, 5200000), "currency_name": "Shekels", "government_style": "Monarchy"}
		],
		"Medieval Era": [
			{ "name": "England", "population": randi_range(220000, 1400000), "land": randi_range(260, 820), "treasury": randi_range(1200000, 8200000), "currency_name": "Crowns", "government_style": "Monarchy"},
			{ "name": "Frankia", "population": randi_range(260000, 1600000), "land": randi_range(300, 980), "treasury": randi_range(1400000, 9000000), "currency_name": "Crowns", "government_style": "Monarchy"},
			{ "name": "Byzantium", "population": randi_range(240000, 1500000), "land": randi_range(300, 940), "treasury": randi_range(1500000, 9800000), "currency_name": "Solidi", "government_style": "Monarchy"}
		],
		"Industrial Era": [
			{ "name": "USA", "population": randi_range(1500000, 12000000), "land": randi_range(600, 1800), "treasury": randi_range(8000000, 52000000), "currency_name": "Dollars", "government_style": "Republic"},
			{ "name": "UK", "population": randi_range(1100000, 9000000), "land": randi_range(320, 980), "treasury": randi_range(7000000, 42000000), "currency_name": "Pounds", "government_style": "Monarchy"},
			{ "name": "Germany", "population": randi_range(1200000, 9800000), "land": randi_range(340, 1100), "treasury": randi_range(7500000, 46000000), "currency_name": "Marks", "government_style": "Monarchy"}
		],
		"Modern Era": [
			{ "name": "USA", "population": randi_range(8000000, 45000000), "land": randi_range(900, 2600), "treasury": randi_range(45000000, 220000000), "currency_name": "Dollars", "government_style": "Republic"},
			{ "name": "Japan", "population": randi_range(6000000, 26000000), "land": randi_range(320, 920), "treasury": randi_range(30000000, 160000000), "currency_name": "Yen", "government_style": "Monarchy"},
			{ "name": "Brazil", "population": randi_range(7000000, 34000000), "land": randi_range(700, 2200), "treasury": randi_range(28000000, 145000000), "currency_name": "Reais", "government_style": "Republic"}
		],
		"Future Era": [
			{ "name": "Federated Earth", "population": randi_range(25000000, 120000000), "land": randi_range(1200, 4200), "treasury": randi_range(250000000, 1500000000), "currency_name": "Credits", "government_style": "Democracy"},
			{ "name": "Sol Empire", "population": randi_range(18000000, 90000000), "land": randi_range(1000, 3600), "treasury": randi_range(220000000, 1300000000), "currency_name": "Solar Credits", "government_style": "Empire"},
			{ "name": "Lunar Republic", "population": randi_range(6000000, 28000000), "land": randi_range(260, 900), "treasury": randi_range(120000000, 640000000), "currency_name": "Lunar Credits", "government_style": "Republic"}
		]
	}
	var rows: Array = starts.get(era, [
		{ "name": "Generic Realm", "population": randi_range(50000, 400000), "land": randi_range(100, 600), "treasury": randi_range(250000, 1800000), "currency_name": "Crowns", "government_style": "Monarchy"}
	]).duplicate(true)

	var existing_by_name: Dictionary = {}
	for raw_row in rows:
		var row: Dictionary = raw_row if typeof(raw_row) == TYPE_DICTIONARY else {}
		var existing_name: String = str(row.get("name", "")).strip_edges()
		if existing_name != "":
			existing_by_name [existing_name.to_lower()] = true

	var picker_countries: Array = []
	if gs != null and gs.era_engine != null and gs.era_engine.has_method("get_countries_for_era"):
		picker_countries = gs.era_engine.get_countries_for_era(era_key)

	for raw_country in picker_countries:
		var country_name: String = str(raw_country).strip_edges()
		if country_name == "":
			continue
		var country_key: String = country_name.to_lower()
		if existing_by_name.has(country_key):
			continue
		var city_names: Array = []
		if gs != null and gs.era_engine != null and gs.era_engine.has_method("get_cities_for_era_country"):
			city_names = gs.era_engine.get_cities_for_era_country(era_key, country_name)
		rows.append(_build_realm_row_from_country(country_name, era, city_names))
		existing_by_name [country_key] = true

	var id: int = 1
	for raw_row in rows:
		var row: Dictionary = raw_row if typeof(raw_row) == TYPE_DICTIONARY else {}
		var realm_name: String = str(row.get("name", "Realm %d" % id)).strip_edges()
		var city_names_raw: Variant = row.get("subzones", [])
		var city_names: Array = city_names_raw.duplicate(true) if typeof(city_names_raw) == TYPE_ARRAY else []
		if city_names.is_empty() and gs != null and gs.era_engine != null and gs.era_engine.has_method("get_cities_for_era_country"):
			city_names = gs.era_engine.get_cities_for_era_country(era_key, realm_name)

		var normalized_row: Dictionary = _build_realm_row_from_country(realm_name, era, city_names)
		for key in row.keys():
			normalized_row [key] = row [key]

		if not normalized_row.has("subzones"):
			normalized_row ["subzones"] = city_names.duplicate(true)
		if str(normalized_row.get("capital_city", "")).strip_edges() == "" and not city_names.is_empty():
			normalized_row ["capital_city"] = str(city_names [0])

		var boot_realm:= {
			"id": str(id),
			"name": realm_name,
			"population": int(normalized_row.get("population", randi_range(50000, 400000))),
			"land": int(normalized_row.get("land", randi_range(100, 600))),
			"treasury": int(normalized_row.get("treasury", randi_range(250000, 1800000))),
			"currency_name": str(normalized_row.get("currency_name", "Crowns")),
			"government_style": str(normalized_row.get("government_style", "Monarchy")),
			"ruler_id": int(normalized_row.get("ruler_id", -1)),
			"subzones": normalized_row.get("subzones", []).duplicate(true),
			"capital_city": str(normalized_row.get("capital_city", "")),
			"country_quality": int(normalized_row.get("country_quality", randi_range(45, 88))),
			"land_label": str(normalized_row.get("land_label", "Territory")),
			"realm_kind": str(normalized_row.get("realm_kind", "state")),
			"realm_type": str(normalized_row.get("realm_type", "standard_realm")),
			"dimension_type": str(normalized_row.get("dimension_type", "standard_realm")),
			"native_element": str(normalized_row.get("native_element", "")),
			"elemental_realm": bool(normalized_row.get("elemental_realm", false)),
			"browser_visual_theme": str(normalized_row.get("browser_visual_theme", "")),
			"overview_visual_theme": str(normalized_row.get("overview_visual_theme", "")),
			"realm_browser_section": str(normalized_row.get("realm_browser_section", ""))
		}

		realms [id] = _apply_realm_contract_defaults(id, boot_realm)
		id += 1
func _bootstrap_era_name(_payload:= {}, era_key: String = "") -> String:
	var payload: Dictionary = _payload.duplicate(true) if typeof(_payload) == TYPE_DICTIONARY else {}

	var direct_name: String = str(payload.get("era_name", "")).strip_edges()
	if direct_name != "":
		return direct_name

	var direct_era: String = str(payload.get("era", "")).strip_edges()
	if direct_era != "" and direct_era.to_lower().ends_with(" era"):
		return direct_era

	var settings_raw: Variant = payload.get("settings", payload.get("custom_settings", {}))
	if typeof(settings_raw) == TYPE_DICTIONARY:
		var settings: Dictionary = settings_raw
		var settings_name: String = str(settings.get("era_name", "")).strip_edges()
		if settings_name != "":
			return settings_name

		var settings_era: String = str(settings.get("era", "")).strip_edges()
		if settings_era != "" and settings_era.to_lower().ends_with(" era"):
			return settings_era

	var state_name: String = _read_era_name_from_variant(gs.era if gs != null else null)
	if state_name != "":
		return state_name

	var clean_key: String = _normalize_era_key(era_key)
	if clean_key == "":
		clean_key = _bootstrap_era_key(payload)

	if gs != null and gs.era_engine != null:
		var eras_raw: Variant = gs.era_engine.get("eras")
		if typeof(eras_raw) == TYPE_DICTIONARY:
			var eras: Dictionary = eras_raw
			if eras.has(clean_key):
				var data_name: String = _read_era_name_from_variant(eras.get(clean_key, {}))
				if data_name != "":
					return data_name

	return _era_display_name_from_key(clean_key)


func _read_era_name_from_variant(value: Variant) -> String:
	if value == null:
		return ""

	if typeof(value) == TYPE_DICTIONARY:
		var data: Dictionary = value
		for key in ["name", "label", "title", "era_name"]:
			var candidate: String = str(data.get(key, "")).strip_edges()
			if candidate != "":
				return candidate
		return ""

	if typeof(value) == TYPE_OBJECT:
		var obj: Object = value
		if obj == null:
			return ""

		for key in ["name", "label", "title", "era_name"]:
			var candidate: String = str(obj.get(key)).strip_edges()
			if candidate != "" and candidate != "<null>":
				return candidate

	return ""


func _normalize_era_key(value: String) -> String:
	var clean: String = str(value).strip_edges()
	if clean == "":
		return ""

	clean = clean.replace(" Era", "")
	clean = clean.replace(" era", "")

	match clean.to_lower():
		"ancient":
			return "Ancient"
		"medieval":
			return "Medieval"
		"industrial":
			return "Industrial"
		"modern":
			return "Modern"
		"future":
			return "Future"

	return clean.substr(0, 1).to_upper() + clean.substr(1)


func _era_display_name_from_key(era_key: String) -> String:
	var clean: String = _normalize_era_key(era_key)

	match clean:
		"Ancient":
			return "Ancient Era"
		"Medieval":
			return "Medieval Era"
		"Industrial":
			return "Industrial Era"
		"Modern":
			return "Modern Era"
		"Future":
			return "Future Era"

	if clean == "":
		return "Modern Era"

	if clean.to_lower().ends_with(" era"):
		return clean

	return "%s Era" % clean
func _current_era_name(default_name: String = "Modern Era") -> String:
	if gs == null:
		return default_name

	var direct_name: String = _read_era_name_from_variant(gs.era)
	if direct_name != "":
		return direct_name

	if typeof(gs.custom_settings) == TYPE_DICTIONARY:
		var custom_name: String = str(gs.custom_settings.get("era_name", "")).strip_edges()
		if custom_name != "":
			return custom_name

		var custom_key: String = _normalize_era_key(str(gs.custom_settings.get("era_key", gs.custom_settings.get("era", ""))).strip_edges())
		if custom_key != "":
			return _era_display_name_from_key(custom_key)

	return default_name
func _bootstrap_era_key(_payload:= {}) -> String:
	var payload: Dictionary = _payload.duplicate(true) if typeof(_payload) == TYPE_DICTIONARY else {}

	var direct_key: String = _normalize_era_key(str(payload.get("era_key", payload.get("era", ""))).strip_edges())
	if direct_key != "":
		return direct_key

	var settings_raw: Variant = payload.get("settings", payload.get("custom_settings", {}))
	if typeof(settings_raw) == TYPE_DICTIONARY:
		var settings: Dictionary = settings_raw
		var settings_key: String = _normalize_era_key(str(settings.get("era_key", settings.get("era", ""))).strip_edges())
		if settings_key != "":
			return settings_key

	if gs == null:
		return "Modern"

	if typeof(gs.custom_settings) == TYPE_DICTIONARY and not gs.custom_settings.is_empty():
		var custom_key: String = _normalize_era_key(str(gs.custom_settings.get("era_key", gs.custom_settings.get("era", ""))).strip_edges())
		if custom_key != "":
			return custom_key

	if gs.era_engine != null and gs.era_engine.has_method("get_era_key_from_year"):
		var lookup_year: int = int(payload.get("year", gs.year))
		var from_year: String = _normalize_era_key(str(gs.era_engine.get_era_key_from_year(lookup_year)).strip_edges())
		if from_year != "":
			return from_year

	var era_name: String = _read_era_name_from_variant(gs.era)
	var from_era: String = _normalize_era_key(era_name)
	if from_era != "":
		return from_era

	return "Modern"

func _estimate_era_population_peak(
	era_name: String
) -> int:
	match era_name:
		"Ancient Era":
			return 260000000
		"Medieval Era":
			return 650000000
		"Industrial Era":
			return 2400000000
		"Modern Era":
			return 9500000000
		"Future Era":
			return 36000000000
		_:
			return 9500000000

func _estimate_era_realm_divisor(
	era_name: String
) -> int:
	match era_name:
		"Ancient Era":
			return 32
		"Medieval Era":
			return 36
		"Industrial Era":
			return 48
		"Modern Era":
			return 64
		"Future Era":
			return 72
		_:
			return 64

func _resolve_realm_population_band(
	realm_name: String,
	era_name: String,
	zone_count: int,
	realm_kind: String
) -> Dictionary:
	var clean_kind: String = (
		str(
			realm_kind
		).strip_edges().to_lower()
	)
	var era_peak: int = (
		_estimate_era_population_peak(
			era_name
		)
	)
	var divisor: int = maxi(
		1,
		_estimate_era_realm_divisor(
			era_name
		)
	)
	var base_slice: int = maxi(
		1000000,
		int(
			round(
				float(era_peak)
				/ float(divisor)
			)
		)
	)

	var min_scale: float = 0.3
	var max_scale: float = 0.68

	match clean_kind:
		"nation":
			min_scale = 0.62
			max_scale = 1.18
		"kingdom":
			min_scale = 0.78
			max_scale = 1.4
		"empire":
			min_scale = 1.25
			max_scale = 2.65
		"tribe":
			min_scale = 0.14
			max_scale = 0.38
		"temple_state":
			min_scale = 0.1
			max_scale = 0.28
		"federation":
			min_scale = 1.0
			max_scale = 1.95

	var capped_zone_count: int = clampi(
		zone_count - 1,
		0,
		10
	)
	var zone_multiplier: float = (
		1.0
		+ float(
			capped_zone_count
		) * 0.05
	)

	var population_min: int = int(
		round(
			float(base_slice)
			* min_scale
			* zone_multiplier
		)
	)
	var population_max: int = int(
		round(
			float(base_slice)
			* max_scale
			* zone_multiplier
		)
	)

	match str(
		realm_name
	).strip_edges():
		"Earth Kingdom":
			population_min = maxi(
				population_min,
				int(
					round(
						float(base_slice) * 1.6
					)
				)
			)
			population_max = maxi(
				population_max,
				int(
					round(
						float(base_slice) * 3.0
					)
				)
			)

		"Fire Nation":
			population_min = maxi(
				population_min,
				int(
					round(
						float(base_slice) * 0.95
					)
				)
			)
			population_max = maxi(
				population_max,
				int(
					round(
						float(base_slice) * 2.1
					)
				)
			)

		"Northern Water Tribe":
			population_min = maxi(
				population_min,
				int(
					round(
						float(base_slice) * 0.14
					)
				)
			)
			population_max = maxi(
				population_max,
				int(
					round(
						float(base_slice) * 0.4
					)
				)
			)

		"Southern Water Tribe":
			population_min = maxi(
				population_min,
				int(
					round(
						float(base_slice) * 0.07
					)
				)
			)
			population_max = maxi(
				population_max,
				int(
					round(
						float(base_slice) * 0.22
					)
				)
			)

		"Air Nomads":
			population_min = maxi(
				population_min,
				int(
					round(
						float(base_slice) * 0.09
					)
				)
			)
			population_max = maxi(
				population_max,
				int(
					round(
						float(base_slice) * 0.26
					)
				)
			)

	var titan_profile: Dictionary = (
		_realm_titan_profile(
			realm_name,
			era_name
		)
	)
	if bool(
		titan_profile.get(
			"active",
			false
		)
	):
		population_min = maxi(
			population_min,
			int(
				titan_profile.get(
					"population_min",
					0
				)
			)
		)
		population_max = maxi(
			population_max,
			int(
				titan_profile.get(
					"population_max",
					population_min
				)
			)
		)

	population_min = maxi(
		100000000,
		population_min
	)

	population_max = maxi(
		population_min + 1,
		population_max
	)

	return {
		"min": population_min,
		"max": population_max,
		"era_population_peak": era_peak,
		"base_realm_slice": base_slice,
		"titan_profile": titan_profile,
		"established_realm_population_floor": 100000000,
		"future_scaled": (
			era_name == "Future Era"
		)
	}

func _resolve_realm_stockpile_targets(
	realm: Dictionary,
	population: int
) -> Dictionary:
	var clean_population: int = maxi(
		1,
		population
	)
	var realm_kind: String = str(
		realm.get(
			"realm_kind",
			"state"
		)
	).strip_edges().to_lower()
	var realm_name: String = str(
		realm.get(
			"name",
			""
		)
	).strip_edges()
	var era_name: String = str(
		realm.get(
			"era_name",
			_current_era_name(
				"Modern Era"
			)
		)
	)

	if bool(
		realm.get(
			"is_new_starting_realm",
			false
		)
	):
		return {
			"military_floor": 0,
			"military_ceiling": 0,
			"goods_floor": 0,
			"goods_ceiling": 0,
		}

	var military_min_ratio: float = 0.12
	var military_max_ratio: float = 0.22
	var goods_min_ratio: float = 0.07
	var goods_max_ratio: float = 0.16

	match era_name:
		"Ancient Era":
			military_min_ratio = 0.1
			military_max_ratio = 0.19
			goods_min_ratio = 0.06
			goods_max_ratio = 0.14

		"Medieval Era":
			military_min_ratio = 0.13
			military_max_ratio = 0.24
			goods_min_ratio = 0.08
			goods_max_ratio = 0.19

		"Industrial Era":
			military_min_ratio = 0.17
			military_max_ratio = 0.3
			goods_min_ratio = 0.12
			goods_max_ratio = 0.28

		"Modern Era":
			military_min_ratio = 0.19
			military_max_ratio = 0.34
			goods_min_ratio = 0.16
			goods_max_ratio = 0.36

		"Future Era":
			military_min_ratio = 0.24
			military_max_ratio = 0.42
			goods_min_ratio = 0.24
			goods_max_ratio = 0.55

	if realm_kind in [
		"nation",
		"kingdom",
		"empire",
		"federation"
	]:
		military_min_ratio += 0.02
		military_max_ratio += 0.03
		goods_min_ratio += 0.02
		goods_max_ratio += 0.04

	var titan_profile: Dictionary = (
		_realm_titan_profile(
			realm_name,
			era_name
		)
	)
	if bool(
		titan_profile.get(
			"active",
			false
		)
	):
		military_min_ratio = maxf(
			military_min_ratio,
			float(
				titan_profile.get(
					"military_min_ratio",
					military_min_ratio
				)
			)
		)
		military_max_ratio = maxf(
			military_max_ratio,
			float(
				titan_profile.get(
					"military_max_ratio",
					military_max_ratio
				)
			)
		)
		goods_min_ratio = maxf(
			goods_min_ratio,
			float(
				titan_profile.get(
					"goods_min_ratio",
					goods_min_ratio
				)
			)
		)
		goods_max_ratio = maxf(
			goods_max_ratio,
			float(
				titan_profile.get(
					"goods_max_ratio",
					goods_max_ratio
				)
			)
		)

	var military_floor: int = maxi(
		250000,
		int(
			round(
				float(clean_population)
				* military_min_ratio
			)
		)
	)
	var military_ceiling: int = maxi(
		military_floor,
		int(
			round(
				float(clean_population)
				* military_max_ratio
			)
		)
	)
	var goods_floor: int = maxi(
		100000,
		int(
			round(
				float(clean_population)
				* goods_min_ratio
			)
		)
	)
	var goods_ceiling: int = maxi(
		goods_floor,
		int(
			round(
				float(clean_population)
				* goods_max_ratio
			)
		)
	)

	return {
		"military_floor": military_floor,
		"military_ceiling": military_ceiling,
		"goods_floor": goods_floor,
		"goods_ceiling": goods_ceiling,
		"military_min_ratio": military_min_ratio,
		"military_max_ratio": military_max_ratio,
		"goods_min_ratio": goods_min_ratio,
		"goods_max_ratio": goods_max_ratio,
		"titan_profile": titan_profile,
		"future_scaled": (
			era_name == "Future Era"
		),
	}
func _simulate_realm_population_change(
		realm: Dictionary,
		population: int
) -> Dictionary:
		var clean_population: int = max(
			1,
			population
		)
		var era_name: String = _current_era_name(
			"Modern Era"
		)
		var quality: float = float(
			realm.get(
				"country_quality",
				50
			)
		)
		var prosperity: float = float(
			realm.get(
				"prosperity",
				realm.get(
					"realm_quality",
					realm.get(
						"country_quality",
						50
					)
				)
			)
		)
		var happiness: float = float(
			realm.get(
				"happiness",
				50
			)
		)
		var stability: float = float(
			realm.get(
				"stability",
				50
			)
		)
		var sovereign_debt: float = float(
			realm.get(
				"sovereign_debt",
				max(
					0,
					- int(
						realm.get(
							"treasury",
							0
						)
					)
				)
			)
		)
		var debt_per_citizen: float = (
			sovereign_debt
			/ float(clean_population)
		)
		var approval: float = 50.0
		var ruler_id: int = int(
			realm.get(
				"ruler_id",
				-1
			)
		)
		var ruler: Person = null

		if (
			gs != null
			and gs.player != null
			and int(gs.player.id) == ruler_id
		):
			ruler = gs.player
		elif (
			gs != null
			and ruler_id > 0
		):
			ruler = gs.get_npc_by_id(
				ruler_id
			)

		if (
			ruler != null
			and ruler.alive
		):
			approval = float(
				clamp(
					int(ruler.approval),
					0,
					100
				)
			)

		var birth_rate: float = 0.01
		var death_rate: float = 0.006

		match era_name:
			"Ancient Era":
				birth_rate = 0.026
				death_rate = 0.019
			"Medieval Era":
				birth_rate = 0.022
				death_rate = 0.015
			"Industrial Era":
				birth_rate = 0.019
				death_rate = 0.011
			"Modern Era":
				birth_rate = 0.014
				death_rate = 0.006
			"Future Era":
				birth_rate = 0.01
				death_rate = 0.004

		birth_rate += (
			(happiness - 50.0) * 5e-05
			+ (prosperity - 50.0) * 4e-05
		)
		death_rate -= (
			(quality - 50.0) * 5e-05
			+ (stability - 50.0) * 4e-05
		)
		death_rate += clamp(
			debt_per_citizen / 250000.0,
			0.0,
			0.012
		)

		birth_rate = clamp(
			birth_rate,
			0.004,
			0.05
		)
		death_rate = clamp(
			death_rate,
			0.003,
			0.055
		)

		var births: int = int(
			round(
				float(clean_population)
				* birth_rate
			)
		)
		var deaths: int = int(
			round(
				float(clean_population)
				* death_rate
			)
		)

		var migration_rate: float = 0.0
		migration_rate += (
			approval - 50.0
		) * 0.0005
		migration_rate += (
			quality - 50.0
		) * 0.00035
		migration_rate += (
			happiness - 50.0
		) * 0.00055
		migration_rate += (
			stability - 50.0
		) * 0.00045
		migration_rate -= clamp(
			debt_per_citizen / 18000.0,
			0.0,
			0.075
		)

		if happiness < 35.0:
			migration_rate -= (
				(35.0 - happiness) * 0.0012
			)

		if approval < 30.0:
			migration_rate -= (
				(30.0 - approval) * 0.001
			)

		if stability < 30.0:
			migration_rate -= (
				(30.0 - stability) * 0.0011
			)

		migration_rate += randf_range(
			-0.003,
			0.003
		)
		migration_rate = clamp(
			migration_rate,
			-0.12,
			0.03
		)

		var migration: int = int(
			round(
				float(clean_population)
				* migration_rate
			)
		)
		var military_migration_loss: int = 0

		if migration < 0:
			var outward_ratio: float = clamp(
				float(- migration)
				/ float(clean_population),
				0.0,
				1.0
			)
			var current_military: int = max(
				0,
				int(
					realm.get(
						"military_stockpile",
						0
					)
				)
			)
			military_migration_loss = min(
				current_military,
				int(
					round(
						float(current_military)
						* outward_ratio
					)
				)
			)
			realm ["military_stockpile"] = (
				current_military
				- military_migration_loss
			)
			realm [
				"military_migration_loss_last_year"
			] = military_migration_loss

		var population_change: int = (
			births
			- deaths
			+ migration
		)

		return {
			"births": births,
			"deaths": deaths,
			"migration": migration,
			"migration_rate": migration_rate,
			"military_migration_loss": (
				military_migration_loss
			),
			"population_change": population_change,
			"debt_per_citizen": debt_per_citizen
		}
func _build_realm_row_from_country(country_name: String, era_name: String, city_names: Array = []) -> Dictionary:
	var source_country_name: String = str(
		country_name
	).strip_edges()
	var clean_name: String = (
		_canonical_realm_display_name(
			source_country_name,
			era_name
		)
	)
	var lower_name: String = clean_name.to_lower()
	var zone_count: int = max(1, city_names.size())

	var population_min: int = 50000
	var population_max: int = 400000
	var land_min: int = 100
	var land_max: int = 600
	var treasury_min: int = 250000
	var treasury_max: int = 1800000
	var military_min: int = 4
	var military_max: int = 24
	var goods_min: int = 1
	var goods_max: int = 6
	var currency_name: String = "Crowns"
	var government_style: String = "Monarchy"
	var land_label: String = "Border Territory"
	var realm_kind: String = "state"
	var quality_min: int = 45
	var quality_max: int = 88

	var native_element: String = ""
	var elemental_realm: bool = false
	var browser_visual_theme: String = ""
	var overview_visual_theme: String = ""
	var realm_browser_section: String = ""

	match era_name:
		"Ancient Era":
			population_min = 70000
			population_max = 900000
			land_min = 140
			land_max = 900
			treasury_min = 350000
			treasury_max = 6500000
			currency_name = "Shekels"
			government_style = "Monarchy"
			land_label = "River-State Reach"
			quality_min = 42
			quality_max = 78
		"Medieval Era":
			population_min = 120000
			population_max = 1600000
			land_min = 200
			land_max = 1100
			treasury_min = 850000
			treasury_max = 9800000
			currency_name = "Crowns"
			government_style = "Monarchy"
			land_label = "Feudal Domain"
			quality_min = 46
			quality_max = 82
		"Industrial Era":
			population_min = 900000
			population_max = 12000000
			land_min = 320
			land_max = 1800
			treasury_min = 7000000
			treasury_max = 52000000
			currency_name = "Dollars"
			government_style = "Republic"
			land_label = "Industrial Territory"
			quality_min = 50
			quality_max = 86
		"Modern Era":
			population_min = 3000000
			population_max = 45000000
			land_min = 420
			land_max = 2600
			treasury_min = 18000000
			treasury_max = 220000000
			currency_name = "Dollars"
			government_style = "Republic"
			land_label = "Sovereign Territory"
			quality_min = 55
			quality_max = 92
		"Future Era":
			population_min = 5000000
			population_max = 120000000
			land_min = 500
			land_max = 4200
			treasury_min = 100000000
			treasury_max = 1500000000
			currency_name = "Credits"
			government_style = "Democracy"
			land_label = "Orbital Sphere"
			quality_min = 60
			quality_max = 95

	if clean_name == "Earth Kingdom":
		population_min = 900000
		population_max = 4800000
		land_min = 700
		land_max = 2400
		treasury_min = 12000000
		treasury_max = 78000000
		currency_name = "Yuan"
		government_style = "Monarchy"
		land_label = "Continental Heartland"
		realm_kind = "kingdom"
		quality_min = 66
		quality_max = 90
		native_element = "earth"
	elif clean_name == "Fire Nation":
		population_min = 450000
		population_max = 2200000
		land_min = 340
		land_max = 1200
		treasury_min = 9000000
		treasury_max = 62000000
		currency_name = "Gold Pieces"
		government_style = "Monarchy"
		land_label = "Volcanic Archipelago"
		realm_kind = "nation"
		quality_min = 70
		quality_max = 96
		native_element = "fire"
	elif clean_name == "Northern Water Tribe":
		population_min = 60000
		population_max = 260000
		land_min = 120
		land_max = 360
		treasury_min = 450000
		treasury_max = 3200000
		currency_name = "Silver Marks"
		government_style = "Monarchy"
		land_label = "Polar Fortress Coast"
		realm_kind = "tribe"
		quality_min = 62
		quality_max = 88
		native_element = "water"
	elif clean_name == "Southern Water Tribe":
		population_min = 18000
		population_max = 120000
		land_min = 80
		land_max = 240
		treasury_min = 120000
		treasury_max = 1400000
		currency_name = "Silver Marks"
		government_style = "Chiefdom"
		land_label = "Polar Frontier Coast"
		realm_kind = "tribe"
		quality_min = 48
		quality_max = 78
		native_element = "water"
	elif clean_name == "Water Tribe":
		population_min = 40000
		population_max = 220000
		land_min = 100
		land_max = 320
		treasury_min = 300000
		treasury_max = 2600000
		currency_name = "Silver Marks"
		government_style = "Chiefdom"
		land_label = "Polar Tide Reach"
		realm_kind = "tribe"
		quality_min = 56
		quality_max = 84
		native_element = "water"
	elif clean_name == "Air Nomads":
		population_min = 18000
		population_max = 95000
		land_min = 90
		land_max = 280
		treasury_min = 180000
		treasury_max = 1500000
		currency_name = "Monastery Chits"
		government_style = "Theocracy"
		land_label = "Sky Monastery Network"
		realm_kind = "temple_state"
		quality_min = 64
		quality_max = 94
		native_element = "air"
	elif lower_name.find("temple") != -1:
		population_min = 12000
		population_max = 85000
		land_min = 80
		land_max = 260
		treasury_min = 120000
		treasury_max = 1200000
		currency_name = "Monastery Chits"
		government_style = "Theocracy"
		land_label = "Temple Network"
		realm_kind = "temple_state"
		quality_min = 58
		quality_max = 90
		if lower_name.find("air temple") != -1:
			native_element = "air"
	elif lower_name.find("kingdom") != -1:
		government_style = "Monarchy"
		land_label = "Kingdom Heartland"
		realm_kind = "kingdom"
	elif lower_name.find("republic") != -1 or lower_name.find("union") != -1 or lower_name.find("confederacy") != -1 or lower_name.find("assembly") != -1 or lower_name.find("coalition") != -1:
		government_style = "Republic" if era_name != "Future Era" else "Democracy"
		land_label = "Federal Reach" if era_name != "Future Era" else "Interlinked Sphere"
		realm_kind = "federation"
	elif lower_name.find("empire") != -1:
		government_style = "Empire"
		land_label = "Imperial Span"
		realm_kind = "empire"
	elif lower_name.find("nation") != -1:
		government_style = "Monarchy" if era_name in ["Ancient Era", "Medieval Era"] else "Republic"
		land_label = "National Territory"
		realm_kind = "nation"

	if native_element != "":
		elemental_realm = true
		browser_visual_theme = "elemental_%s" % native_element
		overview_visual_theme = browser_visual_theme
		realm_browser_section = "elemental_realms"

	var population_band: Dictionary = _resolve_realm_population_band(clean_name, era_name, zone_count, realm_kind)
	var population_max_candidate: int = int(population_band.get("max", population_max))
	population_min = max(population_min, int(population_band.get("min", population_min)))
	population_max = max(population_min + 1, max(population_max, population_max_candidate))

	var extra_population_min: int = max(25000, int(round(float(population_min) * 0.02)))
	var extra_population_max: int = max(extra_population_min, int(round(float(population_max) * 0.06)))
	var extra_population: int = max(0, zone_count - 1) * randi_range(extra_population_min, extra_population_max)
	var sampled_population: int = randi_range(population_min, population_max) + extra_population

	var land_min_scaled: int = max(land_min, int(round(float(sampled_population) / 80000.0)))
	var land_max_scaled: int = max(land_max, int(round(float(sampled_population) / 18000.0)))
	if land_max_scaled < land_min_scaled:
		land_max_scaled = land_min_scaled
	var extra_land: int = max(0, zone_count - 1) * randi_range(12, 140)

	var treasury_min_scaled: int = max(treasury_min, int(round(float(sampled_population) * 18.0)))
	var treasury_max_scaled: int = max(treasury_max, int(round(float(sampled_population) * 90.0)))
	if treasury_max_scaled < treasury_min_scaled:
		treasury_max_scaled = treasury_min_scaled
	var extra_treasury_min: int = max(50000, int(round(float(treasury_min_scaled) * 0.01)))
	var extra_treasury_max: int = max(extra_treasury_min, int(round(float(treasury_max_scaled) * 0.04)))
	var extra_treasury: int = max(0, zone_count - 1) * randi_range(extra_treasury_min, extra_treasury_max)

	var stockpile_targets: Dictionary = _resolve_realm_stockpile_targets({
		"name": clean_name,
		"realm_kind": realm_kind,
		"era_name": era_name
	}, sampled_population)
	var military_seed_min: int = int(stockpile_targets.get("military_floor", military_min))
	var military_seed_max: int = int(stockpile_targets.get("military_ceiling", max(military_seed_min, military_max)))
	var goods_seed_min: int = int(stockpile_targets.get("goods_floor", goods_min))
	var goods_seed_max: int = int(stockpile_targets.get("goods_ceiling", max(goods_seed_min, goods_max)))

	var capital_city: String = ""
	if not city_names.is_empty():
		capital_city = str(city_names [0])

	return {
		"name": clean_name,
		"population": sampled_population,
		"population_floor": population_min,
		"population_ceiling": max(sampled_population, population_max),
		"land": randi_range(land_min_scaled, land_max_scaled) + extra_land,
		"treasury": randi_range(treasury_min_scaled, treasury_max_scaled) + extra_treasury,
		"military_stockpile": max(military_seed_min, randi_range(military_seed_min, military_seed_max)),
		"goods_stockpile": max(goods_seed_min, randi_range(goods_seed_min, goods_seed_max)),
		"currency_name": currency_name,
		"government_style": government_style,
		"country_quality": randi_range(quality_min, quality_max),
		"land_label": land_label,
		"realm_kind": realm_kind,
		"capital_city": capital_city,
		"subzones": city_names.duplicate(true),
		"native_element": native_element,
		"elemental_realm": elemental_realm,
		"browser_visual_theme": browser_visual_theme,
		"overview_visual_theme": overview_visual_theme,
		"source_country_name": source_country_name,
		"era_name": era_name,
		"titan_identity": _realm_titan_identity(
			clean_name
		),
		"clear_geopolitical_titan": bool(
			_realm_titan_profile(
				clean_name,
				era_name
			).get(
				"active",
				false
			)
		),
		"realm_browser_section": realm_browser_section
	}
func _apply_realm_stockpile_contract_defaults(
	realm: Dictionary
) -> Dictionary:
	if realm.is_empty():
		return {}

	var out: Dictionary = realm.duplicate(true)
	var population: int = maxi(
		1,
		int(
			out.get(
				"population",
				1
			)
		)
	)
	var is_new_starting_realm: bool = bool(
		out.get(
			"is_new_starting_realm",
			false
		)
	)
	var targets: Dictionary = (
		_resolve_realm_stockpile_targets(
			out,
			population
		)
	)
	var military_floor: int = int(
		targets.get(
			"military_floor",
			0
		)
	)
	var military_ceiling: int = int(
		targets.get(
			"military_ceiling",
			military_floor
		)
	)
	var goods_floor: int = int(
		targets.get(
			"goods_floor",
			0
		)
	)
	var goods_ceiling: int = int(
		targets.get(
			"goods_ceiling",
			goods_floor
		)
	)

	out [
		"military_floor"
	] = military_floor
	out [
		"military_ceiling"
	] = maxi(
		military_floor,
		military_ceiling
	)
	out [
		"goods_floor"
	] = goods_floor
	out [
		"goods_ceiling"
	] = maxi(
		goods_floor,
		goods_ceiling
	)

	if is_new_starting_realm:
		out [
			"military_stockpile"
		] = maxi(
			0,
			int(
				out.get(
					"military_stockpile",
					0
				)
			)
		)

		out [
			"goods_stockpile"
		] = maxi(
			0,
			int(
				out.get(
					"goods_stockpile",
					0
				)
			)
		)

	else:


		out [
			"military_stockpile"
		] = maxi(
			int(
				out.get(
					"military_stockpile",
					0
				)
			),
			military_floor
		)

		out [
			"goods_stockpile"
		] = maxi(
			int(
				out.get(
					"goods_stockpile",
					0
				)
			),
			goods_floor
		)
	out [
		"military_stockpile_contract_hot"
	] = (
		is_new_starting_realm
		or int(
			out.get(
				"military_stockpile",
				0
			)
		) > 0
	)
	out [
		"goods_stockpile_contract_hot"
	] = (
		is_new_starting_realm
		or int(
			out.get(
				"goods_stockpile",
				0
			)
		) > 0
	)
	out [
		"stockpile_defaults_actor_observation_independent"
	] = true

	return out
func _stable_realm_leader_name_value(
	values: Array,
	seed_text: String,
	salt: String
) -> String:
	if values.is_empty():
		return ""

	var index: int = posmod(
		hash(
			"%s|%s"
			% [
				seed_text,
				salt
			]
		),
		values.size()
	)

	return str(
		values [index]
	).strip_edges()


func _realm_leader_name_pools(
	era_name: String,
	gender: String
) -> Dictionary:
	if (
		gs == null
		or gs.names_db == null
	):
		return {
			"first": [],
			"last": []
		}

	var male: bool = (
		gender == "Male"
	)

	match era_name:
		"Ancient Era":
			return {
				"first": (
					gs.names_db.ancient_male
					if male
					else gs.names_db.ancient_female
				),
				"last": gs.names_db.ancient_last
			}

		"Medieval Era":
			return {
				"first": (
					gs.names_db.medieval_male
					if male
					else gs.names_db.medieval_female
				),
				"last": gs.names_db.medieval_last
			}

		"Industrial Era":
			return {
				"first": (
					gs.names_db.industrial_male
					if male
					else gs.names_db.industrial_female
				),
				"last": gs.names_db.industrial_last
			}

		"Future Era":
			return {
				"first": (
					gs.names_db.future_male
					if male
					else gs.names_db.future_female
				),
				"last": gs.names_db.future_last
			}

		_:
			return {
				"first": (
					gs.names_db.male_first
					if male
					else gs.names_db.female_first
				),
				"last": gs.names_db.last_names
			}


func _realm_leader_title_for_gender(
		realm: Dictionary,
		gender: String
) -> String:
		var realm_name: String = str(
			realm.get(
				"name",
				""
			)
		).strip_edges()
		var lower_name: String = realm_name.to_lower()
		var realm_kind: String = str(
			realm.get(
				"realm_kind",
				""
			)
		).strip_edges().to_lower()
		var government_style: String = str(
			realm.get(
				"government_style",
				"State"
			)
		).strip_edges().to_lower()
		var government_model: String = str(
			realm.get(
				"government_model",
				realm.get(
					"government_type",
					""
				)
			)
		).strip_edges().to_lower()
		var female: bool = (
			str(gender).strip_edges().to_lower()
			== "female"
		)



		for raw_explicit_title in [
			realm.get("head_of_state_title", ""),
			realm.get("constitutional_office_title", ""),
			realm.get("office_title", "")
		]:
			var explicit_title: String = str(
				raw_explicit_title
			).strip_edges()

			if explicit_title != "":
				return explicit_title

		var direct_title: String = str(
			realm.get(
				"ruler_title",
				realm.get(
					"leader_title",
					""
				)
			)
		).strip_edges()

		var stale_generic_chancellor: bool = (
			direct_title.to_lower() == "chancellor"
			and government_style == "republic"
			and government_model.find("chancellor") < 0
			and government_model.find("parliamentary") < 0
			and lower_name not in [
				"germany",
				"austria"
			]
		)

		if (
			direct_title != ""
			and not stale_generic_chancellor
			and direct_title != "Head of State"
		):
			return direct_title

		if lower_name == "fire nation":
			return "Fire Lord"

		if lower_name == "earth kingdom":
			return (
				"Earth Queen"
				if female
				else "Earth King"
			)

		if lower_name.find("water tribe") >= 0:
			return "Chief"

		if (
			lower_name == "air nomads"
			or lower_name.find("air temple") >= 0
		):
			return "Monk"

		if lower_name.find("egypt") >= 0:
			return "PHARAOH"

		if lower_name.find("vatican") >= 0:
			return "Pope"

		if lower_name in [
			"united states",
			"united states of america",
			"france",
			"brazil",
			"mexico",
			"argentina",
			"indonesia",
			"south korea",
			"philippines",
			"nigeria",
			"kenya",
			"turkey"
		]:
			return "President"

		if lower_name in [
			"united kingdom",
			"canada",
			"australia",
			"new zealand",
			"india",
			"japan",
			"italy",
			"spain",
			"netherlands",
			"sweden",
			"norway",
			"denmark"
		]:
			return "Prime Minister"

		if lower_name in [
			"germany",
			"austria"
		]:
			return "Chancellor"

		if lower_name.find("saudi arabia") >= 0:
			return "King"

		if lower_name == "iran":
			return "Supreme Leader"

		if lower_name in [
			"china",
			"vietnam",
			"cuba"
		]:
			return "General Secretary"

		if lower_name.find("north korea") >= 0:
			return "Supreme Leader"

		if (
			realm_kind.find("empire") >= 0
			or government_style.find("empire") >= 0
			or lower_name.find("empire") >= 0
		):
			return (
				"Empress"
				if female
				else "Emperor"
			)

		if (
			realm_kind.find("sultanate") >= 0
			or government_style.find("sultanate") >= 0
		):
			return (
				"Sultana"
				if female
				else "Sultan"
			)

		if (
			realm_kind.find("emirate") >= 0
			or government_style.find("emirate") >= 0
		):
			return (
				"Emira"
				if female
				else "Emir"
			)

		if (
			realm_kind.find("duchy") >= 0
			or government_style.find("duchy") >= 0
		):
			return (
				"Duchess"
				if female
				else "Duke"
			)

		if (
			realm_kind.find("principality") >= 0
			or government_style.find("principality") >= 0
		):
			return (
				"Princess"
				if female
				else "Prince"
			)

		if (
			realm_kind.find("kingdom") >= 0
			or government_style.find("monarch") >= 0
			or government_style.find("kingdom") >= 0
			or lower_name.find("kingdom") >= 0
		):
			return (
				"Queen"
				if female
				else "King"
			)

		if (
			government_style.find("theocr") >= 0
			or government_model.find("theocr") >= 0
		):
			return (
				"High Priestess"
				if female
				else "High Priest"
			)

		if (
			government_style.find("dictator") >= 0
			or government_style.find("authoritarian") >= 0
			or government_style.find("autocracy") >= 0
			or government_model.find("dictator") >= 0
			or government_model.find("authoritarian") >= 0
		):
			return "Supreme Leader"

		if (
			government_style.find("commun") >= 0
			or government_model.find("commun") >= 0
		):
			return "General Secretary"

		if (
			government_style.find("chancellor") >= 0
			or government_model.find("chancellor") >= 0
		):
			return "Chancellor"

		if (
			government_style.find("parliament") >= 0
			or government_model.find("parliament") >= 0
		):
			return "Prime Minister"

		if (
			government_style.find("presidential") >= 0
			or government_model.find("presidential") >= 0
			or government_model.find("federal_republic") >= 0
			or government_style.find("republic") >= 0
			or government_style.find("democracy") >= 0
		):
			return "President"

		return _default_realm_ruler_title(
			realm
		)

func _apply_realm_leader_identity_contract_defaults(
		realm_id: int,
		realm: Dictionary
) -> Dictionary:
		if realm.is_empty():
			return {}

		const TITLE_AUTHORITY_REVISION: int = 2

		var out: Dictionary = realm.duplicate(true)
		var existing_contract_raw: Variant = out.get(
			"leader_identity_contract",
			{}
		)
		var existing_contract: Dictionary = (
			existing_contract_raw as Dictionary
			if typeof(existing_contract_raw) == TYPE_DICTIONARY
			else {}
		)
		var existing_label: String = str(
			existing_contract.get(
				"leader_label",
				""
			)
		).strip_edges()
		var existing_revision: int = int(
			existing_contract.get(
				"title_authority_revision",
				0
			)
		)
		var authoritative_person_identity: bool = (
			bool(
				existing_contract.get(
					"authoritative_ruler_identity",
					false
				)
			)
			and not bool(
				existing_contract.get(
					"deterministic_realm_identity",
					false
				)
			)
		)

		if (
			authoritative_person_identity
			and existing_label != ""
			and existing_label.find("Unassigned") < 0
		):
			return out

		if (
			not existing_contract.is_empty()
			and existing_revision >= TITLE_AUTHORITY_REVISION
			and existing_label != ""
			and existing_label.find("Unassigned") < 0
		):
			return out

		var era_name: String = (
			str(gs.era.name)
			if (
				gs != null
				and gs.era != null
			)
			else "Modern Era"
		)
		var realm_name: String = str(
			out.get(
				"name",
				"Realm %d" % realm_id
			)
		).strip_edges()
		var seed_text: String = (
			"%d|%s|%s"
			% [
				realm_id,
				realm_name,
				era_name
			]
		)
		var gender: String = (
			"Female"
			if posmod(
				hash("%s|gender" % seed_text),
				2
			) == 1
			else "Male"
		)
		var pools: Dictionary = _realm_leader_name_pools(
			era_name,
			gender
		)
		var first_name: String = _stable_realm_leader_name_value(
			pools.get("first", []),
			seed_text,
			"first"
		)
		var last_name: String = _stable_realm_leader_name_value(
			pools.get("last", []),
			seed_text,
			"last"
		)
		var direct_name: String = str(
			out.get(
				"ruler_name",
				out.get(
					"leader_name",
					""
				)
			)
		).strip_edges()

		var leader_name: String = (
			"%s %s"
			% [
				first_name,
				last_name
			]
		).strip_edges()

		if direct_name != "":
			leader_name = direct_name
			first_name = direct_name
			last_name = ""




		var leader_title: String = _realm_leader_title_for_gender(
			out,
			gender
		)
		var lower_realm_name: String = realm_name.to_lower()
		var leader_display: String = ""

		if lower_realm_name.find("egypt") >= 0:
			leader_display = (
				"PHARAOH %s OF EGYPT"
				% leader_name.to_upper()
			)
		else:
			leader_display = (
				"%s %s"
				% [
					leader_title,
					leader_name
				]
			).strip_edges()

		var leader_contract: Dictionary = {
			"schema": (
				"eralife.realm_engine."
				+ "leader_identity_contract"
			),
			"version": 2,
			"title_authority_revision": (
				TITLE_AUTHORITY_REVISION
			),
			"realm_id": realm_id,
			"realm_name": realm_name,
			"gender": gender,
			"first_name": first_name,
			"last_name": last_name,
			"leader_name": leader_name,
			"leader_title": leader_title,
			"display_name": leader_name,
			"display_label": leader_display,
			"leader_label": (
				"Leader: %s"
				% leader_display
			),
			"runtime_person_materialized": (
				int(
					out.get(
						"ruler_id",
						-1
					)
				) > 0
			),
			"deterministic_realm_identity": true,
			"head_of_state_title_authority": (
				"RealmEngine"
			),
			"ui_is_renderer_only": true
		}

		out ["leader_identity_contract"] = leader_contract
		out ["leader_identity_revision"] = (
			TITLE_AUTHORITY_REVISION
		)
		out ["leader_name"] = leader_name
		out ["leader_title"] = leader_title
		out ["leader_label"] = str(
			leader_contract.get(
				"leader_label",
				""
			)
		)
		out ["ruler_name"] = leader_name
		out ["ruler_title"] = leader_title
		out ["head_of_state_title"] = leader_title

		return out
func _realm_annual_military_unit_upkeep(
		_realm: Dictionary
) -> int:
		var era_name: String = _current_era_name(
			"Modern Era"
		)

		match era_name:
			"Ancient Era":
				return 180
			"Medieval Era":
				return 320
			"Industrial Era":
				return 1200
			"Future Era":
				return 9000
			_:
				return 4500


func _apply_annual_realm_financial_pressure(
		realm_id: int,
		realm: Dictionary
) -> Dictionary:
		if (
			gs == null
			or realm.is_empty()
		):
			return realm

		if int(
			realm.get(
				"annual_expense_applied_year",
				-1
			)
		) == int(gs.year):
			return realm

		var out: Dictionary = realm.duplicate(true)
		var population: int = max(
			1,
			int(
				out.get(
					"population",
					1
				)
			)
		)
		var military_units: int = max(
			0,
			int(
				out.get(
					"military_stockpile",
					0
				)
			)
		)
		var readiness_multiplier: float = clamp(
			float(
				out.get(
					"military_readiness_multiplier",
					1.0
				)
			),
			0.35,
			2.5
		)
		var unit_upkeep: int = (
			_realm_annual_military_unit_upkeep(
				out
			)
		)
		var military_upkeep: int = int(
			round(
				float(military_units)
				* float(unit_upkeep)
				* readiness_multiplier
			)
		)
		var administrative_cost_per_citizen: float = (
			max(
				2.0,
				float(unit_upkeep) * 0.012
			)
		)
		var civil_administration_cost: int = int(
			round(
				float(population)
				* administrative_cost_per_citizen
			)
		)
		var goods_maintenance: int = int(
			round(
				float(
					max(
						0,
						int(
							out.get(
								"goods_stockpile",
								0
							)
						)
					)
				) * 35.0
			)
		)
		var total_expense: int = (
			military_upkeep
			+ civil_administration_cost
			+ goods_maintenance
		)
		var treasury_before: int = int(
			out.get(
				"treasury",
				0
			)
		)
		var treasury_after: int = (
			treasury_before - total_expense
		)
		var sovereign_debt: int = max(
			0,
			- treasury_after
		)
		var debt_per_citizen: float = (
			float(sovereign_debt)
			/ float(population)
		)
		var debt_pressure: int = clamp(
			int(
				round(
					sqrt(
						max(
							0.0,
							debt_per_citizen
						)
					) * 0.85
				)
			),
			0,
			35
		)
		var happiness_penalty: int = clamp(
			int(
				round(
					float(debt_pressure) * 0.75
				)
			),
			0,
			28
		)
		var approval_penalty: int = clamp(
			int(
				round(
					float(debt_pressure) * 0.65
				)
			),
			0,
			24
		)
		var stability_penalty: int = clamp(
			int(
				round(
					float(debt_pressure) * 0.35
				)
			),
			0,
			14
		)

		out ["treasury"] = treasury_after
		out ["sovereign_debt"] = sovereign_debt
		out ["annual_military_upkeep"] = military_upkeep
		out [
			"annual_civil_administration_cost"
		] = civil_administration_cost
		out ["annual_goods_maintenance"] = (
			goods_maintenance
		)
		out ["annual_total_state_expense"] = (
			total_expense
		)
		out ["annual_expense_applied_year"] = int(
			gs.year
		)
		out ["debt_per_citizen"] = debt_per_citizen
		out ["debt_pressure"] = debt_pressure
		out ["happiness"] = clamp(
			int(out.get("happiness", 50))
			- happiness_penalty,
			0,
			100
		)
		out ["stability"] = clamp(
			int(out.get("stability", 50))
			- stability_penalty,
			0,
			100
		)

		var ruler_id: int = int(
			out.get(
				"ruler_id",
				-1
			)
		)
		var ruler: Person = null

		if (
			gs.player != null
			and int(gs.player.id) == ruler_id
		):
			ruler = gs.player
		elif ruler_id > 0:
			ruler = gs.get_npc_by_id(
				ruler_id
			)

		if (
			ruler != null
			and ruler.alive
		):
			ruler.approval = clamp(
				int(ruler.approval)
				- approval_penalty,
				0,
				100
			)

		out ["annual_debt_happiness_penalty"] = (
			happiness_penalty
		)
		out ["annual_debt_approval_penalty"] = (
			approval_penalty
		)
		out ["annual_debt_stability_penalty"] = (
			stability_penalty
		)
		out ["realm_id"] = realm_id

		return out
func publish_realm_leader_identity_from_person(
	leader: Person,
	context: Dictionary = {}
) -> Dictionary:
	if (
		leader == null
		or not leader.alive
	):
		return {
			"success": false,
			"reason": "missing_or_dead_realm_leader"
		}

	var realm_id: int = int(
		context.get(
			"realm_id",
			leader.realm_id
		)
	)

	if (
		realm_id <= 0
		or not realms.has(
			realm_id
		)
	):
		return {
			"success": false,
			"reason": "leader_realm_not_found",
			"leader_id": int(
				leader.id
			),
			"realm_id": realm_id
		}

	var realm_raw: Variant = realms.get(
		realm_id,
		{}
	)
	var realm: Dictionary = (
		realm_raw as Dictionary
		if typeof(realm_raw) == TYPE_DICTIONARY
		else {}
	)

	if realm.is_empty():
		return {
			"success": false,
			"reason": "leader_realm_contract_missing",
			"leader_id": int(
				leader.id
			),
			"realm_id": realm_id
		}

	var realm_name: String = str(
		realm.get(
			"name",
			"Realm %d" % realm_id
		)
	).strip_edges()
	var leader_title: String = ""

	for raw_title in [
		context.get(
			"leader_title",
			""
		),
		leader.royal_title,
		leader.civic_title,
		leader.job
	]:
		var candidate_title: String = str(
			raw_title
		).strip_edges()

		if candidate_title == "":
			continue

		leader_title = candidate_title
		break

	if leader_title == "":
		leader_title = (
			_realm_leader_title_for_gender(
				realm,
				str(
					leader.gender
				)
			)
		)

	var first_name: String = str(
		leader.first_name
	).strip_edges()
	var last_name: String = str(
		leader.last_name
	).strip_edges()
	var display_name: String = (
		"%s %s"
		% [
			first_name,
			last_name
		]
	).strip_edges()

	if display_name == "":
		display_name = str(
			leader.name
		).strip_edges()

	if display_name == "":
		display_name = (
			"Office Holder %d"
			% int(
				leader.id
			)
		)

	var leader_display: String = ""
	var lower_realm_name: String = (
		realm_name.to_lower()
	)
	var lower_leader_title: String = (
		leader_title.to_lower()
	)

	if (
		lower_realm_name.find(
			"egypt"
		) >= 0
		and lower_leader_title.find(
			"pharaoh"
		) >= 0
		and first_name != ""
	):
		leader_display = (
			"%s %s OF EGYPT"
			% [
				leader_title.to_upper(),
				first_name.to_upper()
			]
		)
	else:
		leader_display = (
			"%s %s"
			% [
				leader_title,
				display_name
			]
		).strip_edges()





	var retired_ruler_ids: Array = []
	var leader_id: int = int(
		leader.id
	)

	leader.realm_id = realm_id
	leader.is_ruler = true
	leader.deposed = false
	leader.exiled = false

	if (
		gs != null
		and gs.player != null
		and int(gs.player.id) != leader_id
		and int(gs.player.realm_id) == realm_id
		and bool(gs.player.is_ruler)
	):
		var previous_player_ruler: Person = gs.player

		previous_player_ruler.is_ruler = false
		previous_player_ruler.palace_owned = false

		if bool(
			previous_player_ruler.is_royal
		):
			previous_player_ruler.deposed = true

			if (
				gs.royalty_engine != null
				and gs.royalty_engine.has_method(
					"_resolve_rank_title"
				)
			):
				previous_player_ruler.royal_title = (
					"Former %s"
					% gs.royalty_engine._resolve_rank_title(
						previous_player_ruler,
						"ruler"
					)
				)

		retired_ruler_ids.append(
			int(previous_player_ruler.id)
		)

	if gs != null:
		for raw_npc in gs.npcs:
			var other: Person = raw_npc

			if other == null:
				continue

			var other_id: int = int(
				other.id
			)

			if other_id == leader_id:
				continue

			if int(
				other.realm_id
			) != realm_id:
				continue

			if not bool(
				other.is_ruler
			):
				continue

			other.is_ruler = false
			other.palace_owned = false

			if bool(
				other.is_royal
			):
				other.deposed = true

				if (
					gs.royalty_engine != null
					and gs.royalty_engine.has_method(
						"_resolve_rank_title"
					)
				):
					other.royal_title = (
						"Former %s"
						% gs.royalty_engine._resolve_rank_title(
							other,
							"ruler"
						)
					)

			if not retired_ruler_ids.has(
				other_id
			):
				retired_ruler_ids.append(
					other_id
				)

		if typeof(
			gs.dormant_npcs
		) == TYPE_DICTIONARY:
			for raw_npc_id in gs.dormant_npcs.keys():
				var dormant_id: int = int(
					raw_npc_id
				)

				if dormant_id == leader_id:
					continue

				var snapshot_raw: Variant = (
					gs.dormant_npcs.get(
						raw_npc_id,
						{}
					)
				)

				if typeof(
					snapshot_raw
				) != TYPE_DICTIONARY:
					continue

				var snapshot: Dictionary = (
					snapshot_raw as Dictionary
				).duplicate(true)

				if int(
					snapshot.get(
						"realm_id",
						-1
					)
				) != realm_id:
					continue

				if not bool(
					snapshot.get(
						"is_ruler",
						false
					)
				):
					continue

				snapshot [
					"is_ruler"
				] = false
				snapshot [
					"palace_owned"
				] = false

				if bool(
					snapshot.get(
						"is_royal",
						false
					)
				):
					snapshot [
						"deposed"
					] = true

					var dormant_title: String = str(
						snapshot.get(
							"royal_title",
							""
						)
					).strip_edges()

					if (
						dormant_title != ""
						and not dormant_title.begins_with(
							"Former "
						)
					):
						snapshot [
							"royal_title"
						] = (
							"Former %s"
							% dormant_title
						)

				gs.dormant_npcs [
					raw_npc_id
				] = snapshot

				if not retired_ruler_ids.has(
					dormant_id
				):
					retired_ruler_ids.append(
						dormant_id
					)

	var previous_revision: int = int(
		realm.get(
			"leader_identity_revision",
			0
		)
	)
	var leader_identity_revision: int = (
		previous_revision + 1
	)
	var leader_contract: Dictionary = {
		"schema": (
			"eralife.realm_engine."
			+ "leader_identity_contract"
		),
		"version": 1,
		"realm_id": realm_id,
		"realm_name": realm_name,
		"leader_person_id": leader_id,
		"ruler_id": leader_id,
		"gender": str(
			leader.gender
		),
		"first_name": first_name,
		"last_name": last_name,
		"leader_name": display_name,
		"leader_title": leader_title,
		"display_name": display_name,
		"display_label": leader_display,
		"leader_label": (
			"Leader: %s"
			% leader_display
		),
		"deterministic_realm_identity": false,
		"authoritative_ruler_identity": true,
		"identity_source": "runtime_person",
		"leader_identity_revision": (
			leader_identity_revision
		),
		"single_ruler_invariant_enforced": true,
		"retired_competing_ruler_ids": (
			retired_ruler_ids.duplicate()
		),
		"source": str(
			context.get(
				"source",
				"realm_engine."
				+ "publish_realm_leader_identity_from_person"
			)
		),
		"ui_is_renderer_only": true
	}

	realm [
		"ruler_id"
	] = leader_id
	realm [
		"ruler_name"
	] = display_name
	realm [
		"leader_name"
	] = display_name
	realm [
		"ruler_title"
	] = leader_title
	realm [
		"leader_title"
	] = leader_title
	realm [
		"leader_label"
	] = str(
		leader_contract.get(
			"leader_label",
			""
		)
	)
	realm [
		"leader_identity_contract"
	] = leader_contract
	realm [
		"leader_identity_revision"
	] = leader_identity_revision
	realm [
		"leader_identity_runtime_authoritative"
	] = true
	realm [
		"leader_identity_deterministic_placeholder_active"
	] = false
	realm [
		"single_ruler_invariant_enforced"
	] = true
	realm [
		"retired_competing_ruler_ids"
	] = retired_ruler_ids.duplicate()
	realm [
		"single_ruler_invariant_revision"
	] = leader_identity_revision

	realms [
		realm_id
	] = realm

	if gs != null:
		if typeof(
			gs.scenario_state
		) != TYPE_DICTIONARY:
			gs.scenario_state = {}

		var revision_by_realm: Dictionary = (
			gs.scenario_state.get(
				"realm_leader_identity_revision_by_realm",
				{}
			) as Dictionary
			if typeof(
				gs.scenario_state.get(
					"realm_leader_identity_revision_by_realm",
					{}
				)
			) == TYPE_DICTIONARY
			else {}
		)

		revision_by_realm [
			str(
				realm_id
			)
		] = leader_identity_revision

		gs.scenario_state [
			"realm_leader_identity_revision_by_realm"
		] = revision_by_realm
		gs.scenario_state [
			"realm_leader_identity_last_realm_id"
		] = realm_id
		gs.scenario_state [
			"realm_leader_identity_last_person_id"
		] = leader_id
		gs.scenario_state [
			"realm_leader_identity_last_revision"
		] = leader_identity_revision
		gs.scenario_state [
			"realm_leader_identity_updated_at_ms"
		] = int(
			Time.get_ticks_msec()
		)

		if gs.event_bus != null:
			gs.event_bus.emit(
				"realm.leader_identity.updated",
				{
					"realm_id": realm_id,
					"realm_name": realm_name,
					"leader_id": leader_id,
					"leader_name": display_name,
					"leader_title": leader_title,
					"leader_identity_revision": (
						leader_identity_revision
					),
					"single_ruler_invariant_enforced": true,
					"retired_competing_ruler_ids": (
						retired_ruler_ids.duplicate()
					),
					"source": str(
						context.get(
							"source",
							"realm_engine"
						)
					),
					"ui_is_renderer_only": true
				}
			)

	return {
		"success": true,
		"schema": (
			"eralife.realm_engine."
			+ "leader_identity_publication_report"
		),
		"realm_id": realm_id,
		"realm_name": realm_name,
		"leader_id": leader_id,
		"leader_name": display_name,
		"leader_title": leader_title,
		"leader_identity_revision": (
			leader_identity_revision
		),
		"leader_identity_contract": (
			leader_contract.duplicate(false)
		),
		"single_ruler_invariant_enforced": true,
		"retired_competing_ruler_ids": (
			retired_ruler_ids.duplicate()
		),
	}
func _realm_initial_development_tier(
	realm_name: String,
	era_name: String,
	elemental_realm: bool,
	authored_tier: String = ""
) -> String:
	var clean_authored_tier: String = authored_tier.strip_edges().to_lower()

	if clean_authored_tier in [
		"advanced",
		"developing",
		"fragile",
		"historical"
	]:
		return clean_authored_tier

	var clean_name: String = realm_name.strip_edges().to_lower()
	var clean_era: String = era_name.strip_edges().to_lower()
	var reality_mode: String = str(
		gs.reality_mode
		if gs != null and "reality_mode" in gs
		else "realistic"
	).strip_edges().to_lower()

	if elemental_realm and reality_mode in ["enhanced", "chaos"]:
		return "advanced"

	if clean_era.find("future") >= 0:
		return "advanced"

	if clean_era.find("modern") < 0:
		return "historical"

	var advanced_modern_realms: Array [String] = [
		"united states",
		"usa",
		"canada",
		"united kingdom",
		"uk",
		"ireland",
		"france",
		"germany",
		"spain",
		"portugal",
		"italy",
		"netherlands",
		"belgium",
		"norway",
		"sweden",
		"finland",
		"denmark",
		"iceland",
		"switzerland",
		"austria",
		"poland",
		"greece",
		"czech republic",
		"japan",
		"south korea",
		"singapore",
		"australia",
		"new zealand",
		"israel",
		"united arab emirates"
	]

	if clean_name in advanced_modern_realms:
		return "advanced"

	return "developing"


func _realm_initial_stability_contract(
	realm_name: String,
	era_name: String,
	country_quality: int,
	elemental_realm: bool,
	authored_tier: String = ""
) -> Dictionary:
	var development_tier: String = _realm_initial_development_tier(
		realm_name,
		era_name,
		elemental_realm,
		authored_tier
	)
	var stability_floor: int = 40
	var stability_ceiling: int = 82

	match development_tier:
		"advanced":
			stability_floor = 72
			stability_ceiling = 94
		"developing":
			stability_floor = 43
			stability_ceiling = 67
		"fragile":
			stability_floor = 22
			stability_ceiling = 45
		_:
			stability_floor = 40
			stability_ceiling = 82

	var normalized_quality: float = clampf(
		float(clampi(country_quality, 0, 100)) / 100.0,
		0.0,
		1.0
	)
	var stability: int = int(
		round(
			lerpf(
				float(stability_floor),
				float(stability_ceiling),
				normalized_quality
			)
		)
	)
	var deterministic_jitter: int = (
		abs(
			int(
				hash(
					"realm_initial_stability|%s|%s|%s|%d"
					% [
						realm_name.strip_edges().to_lower(),
						era_name.strip_edges().to_lower(),
						development_tier,
						country_quality
					]
				)
			)
		) % 7
	) - 3

	stability = clampi(
		stability + deterministic_jitter,
		stability_floor,
		stability_ceiling
	)

	return {
		"stability": stability,
		"development_tier": development_tier,
		"stability_floor": stability_floor,
		"stability_ceiling": stability_ceiling,
		"stability_authority": "realm_engine.initial_stability_contract"
	}


func _apply_realm_initial_stability_contract_defaults(
	realm: Dictionary
) -> Dictionary:
	var out: Dictionary = realm.duplicate(false)



	if out.has("stability"):
		out ["stability"] = clampi(
			int(out.get("stability", 50)),
			0,
			100
		)
		return out

	var stability_contract: Dictionary = _realm_initial_stability_contract(
		str(out.get("name", "")).strip_edges(),
		_current_era_name("Modern Era"),
		int(out.get("country_quality", 50)),
		bool(out.get("elemental_realm", false)),
		str(out.get("development_tier", ""))
	)

	out ["stability"] = int(
		stability_contract.get("stability", 50)
	)
	out ["development_tier"] = str(
		stability_contract.get("development_tier", "historical")
	)
	out ["stability_floor"] = int(
		stability_contract.get("stability_floor", 1)
	)
	out ["stability_ceiling"] = int(
		stability_contract.get("stability_ceiling", 100)
	)
	out ["stability_authority"] = str(
		stability_contract.get(
			"stability_authority",
			"realm_engine.initial_stability_contract"
		)
	)

	return out
func _apply_realm_contract_defaults(
	realm_id: int,
	realm: Dictionary
) -> Dictionary:
	_register_resident_realm_identity(
		realm_id
	)

	var out: Dictionary = realm.duplicate(false)

	if (
		realm_id > 0
		and str(
			out.get(
				"id",
				""
			)
		).strip_edges() == ""
	):
		out ["id"] = str(
			realm_id
		)

	out = _apply_realm_population_contract_defaults(
		out
	)

	out = _apply_realm_land_contract_defaults(
		out
	)

	out = _apply_realm_stockpile_contract_defaults(
		out
	)

	out = _apply_realm_leader_identity_contract_defaults(
		realm_id,
		out
	)

	out = _apply_realm_initial_stability_contract_defaults(
		out
	)

	if (
		gs == null
		or gs.realm_contract_engine == null
	):
		return out

	if not gs.realm_contract_engine.has_method(
		"normalize_surface_entry"
	):
		return out

	var entry: Dictionary = {
		"entry_kind": "realm",
		"entry_id": str(
			realm_id
		),
		"name": str(
			out.get(
				"name",
				"Realm %d" % realm_id
			)
		),
		"realm_id": realm_id,
		"realm": out.duplicate(false)
	}

	var normalized_raw: Variant = (
		gs.realm_contract_engine
		.normalize_surface_entry(
			entry,
			"realm_engine"
		)
	)

	if typeof(
		normalized_raw
	) != TYPE_DICTIONARY:
		return out

	var normalized: Dictionary = (
		normalized_raw as Dictionary
	)

	var normalized_realm_raw: Variant = (
		normalized.get(
			"realm",
			out
		)
	)

	if typeof(
		normalized_realm_raw
	) == TYPE_DICTIONARY:
		var normalized_realm: Dictionary = (
			normalized_realm_raw as Dictionary
		).duplicate(false)

		normalized_realm = (
			_apply_realm_population_contract_defaults(
				normalized_realm
			)
		)

		normalized_realm = (
			_apply_realm_land_contract_defaults(
				normalized_realm
			)
		)

		normalized_realm = (
			_apply_realm_stockpile_contract_defaults(
				normalized_realm
			)
		)

		normalized_realm = (
			_apply_realm_leader_identity_contract_defaults(
				realm_id,
				normalized_realm
			)
		)

		normalized_realm = (
			_apply_realm_initial_stability_contract_defaults(
				normalized_realm
			)
		)

		return normalized_realm

	return out
func _register_resident_realm_identity(
	realm_id: int
) -> void:
	if realm_id <= 0:
		return



	if (
		realms.is_empty()
		and not resident_realm_id_order.is_empty()
	):
		resident_realm_id_order.clear()
		resident_realm_id_seen.clear()

	var realm_key: String = str(
		realm_id
	)

	if resident_realm_id_seen.has(
		realm_key
	):
		return

	resident_realm_id_seen [
		realm_key
	] = true

	resident_realm_id_order.append(
		realm_id
	)


func resident_realm_identity_count() -> int:
	return resident_realm_id_order.size()


func resident_realm_id_at(
	cursor: int
) -> int:
	if (
		cursor < 0
		or cursor >= resident_realm_id_order.size()
	):
		return -1

	return int(
		resident_realm_id_order [
			cursor
		]
	)

func _apply_realm_land_contract_defaults(
	realm: Dictionary
) -> Dictionary:
	if realm.is_empty():
		return {}

	var out: Dictionary = (
		realm.duplicate(false)
	)

	var realm_state: String = str(
		out.get(
			"state",
			""
		)
	).strip_edges().to_lower()



	if realm_state == "annexed":
		out ["land"] = 0
		out ["land_size"] = 0
		out ["land_area_km2"] = 0
		out ["land_km2"] = 0
		out ["land_area_mi2"] = 0
		out ["land_mi2"] = 0
		out ["land_display_value"] = 0
		out ["land_display_unit"] = "km²"
		out ["land_measurement_label"] = "0 km²"
		out ["land_contract_real_units"] = true
		out ["land_measurement_authority"] = ENGINE_SCHEMA
		return out

	var realm_name: String = str(
		out.get(
			"name",
			""
		)
	).strip_edges()

	var era_name: String = str(
		out.get(
			"era_name",
			_current_era_name(
				"Modern Era"
			)
		)
	).strip_edges()

	var realm_kind: String = str(
		out.get(
			"realm_kind",
			"state"
		)
	).strip_edges().to_lower()

	var is_new_starting_realm: bool = bool(
		out.get(
			"is_new_starting_realm",
			false
		)
	)

	var population: int = maxi(
		0,
		int(
			out.get(
				"population",
				0
			)
		)
	)

	var legacy_land_value: int = maxi(
		0,
		int(
			out.get(
				"land",
				out.get(
					"land_size",
					0
				)
			)
		)
	)

	var canonical_land_km2: int = maxi(
		0,
		int(
			out.get(
				"land_area_km2",
				out.get(
					"land_km2",
					0
				)
			)
		)
	)

	var existing_land_km2: int = maxi(
		legacy_land_value,
		canonical_land_km2
	)

	var already_real_units: bool = bool(
		out.get(
			"land_contract_real_units",
			false
		)
	)

	var migrated_legacy_scale: bool = false




	if (
		not is_new_starting_realm
		and not already_real_units
		and existing_land_km2 > 0
		and existing_land_km2 < 10000
	):
		existing_land_km2 *= 1000
		migrated_legacy_scale = true

	var known_area_km2: int = (
		_known_realm_territory_area_km2(
			realm_name,
			era_name
		)
	)

	var realm_kind_floor_km2: int = 75000

	match realm_kind:
		"temple_state":
			realm_kind_floor_km2 = 10000
		"tribe":
			realm_kind_floor_km2 = 25000
		"state":
			realm_kind_floor_km2 = 75000
		"nation":
			realm_kind_floor_km2 = 150000
		"kingdom":
			realm_kind_floor_km2 = 300000
		"federation":
			realm_kind_floor_km2 = 650000
		"empire":
			realm_kind_floor_km2 = 1250000
		_:
			pass

	var population_floor_km2: int = int(
		ceil(
			float(
				population
			) / 450.0
		)
	)

	var land_floor_km2: int = (
		maxi(
			realm_kind_floor_km2,
			population_floor_km2
		)
	)



	if is_new_starting_realm:
		land_floor_km2 = 25



	if known_area_km2 > 0:
		land_floor_km2 = known_area_km2

	var resolved_land_km2: int = maxi(
		existing_land_km2,
		land_floor_km2
	)

	var resolved_land_mi2: int = int(
		round(
			float(
				resolved_land_km2
			) * 0.3861021585
		)
	)

	out [
		"land"
	] = resolved_land_km2
	out [
		"land_size"
	] = resolved_land_km2
	out [
		"land_area_km2"
	] = resolved_land_km2
	out [
		"land_km2"
	] = resolved_land_km2
	out [
		"land_area_mi2"
	] = resolved_land_mi2
	out [
		"land_mi2"
	] = resolved_land_mi2
	out [
		"land_floor_km2"
	] = land_floor_km2
	out [
		"land_display_value"
	] = resolved_land_km2
	out [
		"land_display_unit"
	] = "km²"
	out [
		"land_measurement_label"
	] = (
		"%d km²"
		% resolved_land_km2
	)
	out [
		"land_contract_real_units"
	] = true
	out [
		"land_measurement_authority"
	] = ENGINE_SCHEMA
	out [
		"legacy_land_scale_migrated"
	] = migrated_legacy_scale
	out [
		"land_can_expand_beyond_floor"
	] = true
	out [
		"known_territory_floor_applied"
	] = known_area_km2 > 0

	return out
func _known_realm_territory_area_km2(
	realm_name: String,
	era_name: String
) -> int:



	if era_name not in [
		"Modern Era",
		"Future Era"
	]:
		return 0

	match _realm_titan_identity(
		realm_name
	):
		"united_states":
			return 9833520

		"china":
			return 9596961

		"russia":
			return 17098246

		"india":
			return 3287263

		_:
			return 0

func ensure_realm_defaults(realm_id: int, preferred_city: String = "") -> Dictionary:
	if realm_id <= 0 or not realms.has(realm_id):
		return {}
	var realm_raw: Variant = realms.get(realm_id, {})
	var realm: Dictionary = realm_raw if typeof(realm_raw) == TYPE_DICTIONARY else {}
	if realm.is_empty():
		return {}

	var era_name: String = _current_era_name("Modern Era")
	var era_key: String = _bootstrap_era_key()
	var realm_name: String = str(realm.get("name", "")).strip_edges()
	var subzones_raw: Variant = realm.get("subzones", [])
	var city_names: Array = subzones_raw.duplicate(true) if typeof(subzones_raw) == TYPE_ARRAY else []
	if city_names.is_empty() and gs != null and gs.era_engine != null and gs.era_engine.has_method("get_cities_for_era_country"):
		city_names = gs.era_engine.get_cities_for_era_country(era_key, realm_name)
	if preferred_city != "" and not city_names.has(preferred_city):
		city_names.push_front(preferred_city)

	var defaults: Dictionary = _build_realm_row_from_country(realm_name, era_name, city_names)
	var live_population: int = get_total_population_for_realm(realm_id)
	var is_new_starting_realm: bool = bool(realm.get("is_new_starting_realm", false))
	var inferred_realm_kind: String = str(realm.get("realm_kind", defaults.get("realm_kind", "state"))).strip_edges()
	var population_band: Dictionary = _resolve_realm_population_band(realm_name, era_name, max(1, city_names.size()), inferred_realm_kind)

	var default_population_floor: int = int(population_band.get("min", max(600000, live_population)))
	var default_population_ceiling: int = int(population_band.get("max", max(default_population_floor, int(realm.get("population", 0)))))

	if is_new_starting_realm:
		default_population_floor = max(1, live_population)
		default_population_ceiling = max(default_population_floor, max(500000, int(realm.get("population", 1)) * 5))

	realm ["population_floor"] = max(int(realm.get("population_floor", 0)), default_population_floor)
	realm ["population_ceiling"] = max(int(realm.get("population_ceiling", 0)), max(int(realm ["population_floor"]), default_population_ceiling, int(realm.get("population", 0))))

	if int(realm.get("population", 0)) <= 0:
		if is_new_starting_realm:
			realm ["population"] = max(1, live_population)
		else:
			realm ["population"] = int(defaults.get("population", max(int(realm.get("population_floor", 0)), live_population)))

	if is_new_starting_realm:
		realm ["population"] = max(int(realm.get("population", 1)), live_population, 1)
	else:
		realm ["population"] = max(int(realm.get("population", 0)), live_population, int(realm.get("population_floor", 0)))

	if int(realm.get("land", realm.get("land_size", 0))) <= 0:
		if is_new_starting_realm:
			realm ["land"] = int(realm.get("land", randi_range(10, 100)))
		else:
			realm ["land"] = int(defaults.get("land", randi_range(100, 600)))

	if int(realm.get("treasury", 0)) <= 0:
		if is_new_starting_realm:
			realm ["treasury"] = max(25000, int(realm.get("population", 1)) * 40)
		else:
			realm ["treasury"] = int(defaults.get("treasury", max(500000, int(realm.get("population", 0)) * 18)))

	var stockpile_targets: Dictionary = _resolve_realm_stockpile_targets(realm, int(realm.get("population", 0)))
	realm ["military_floor"] = int(stockpile_targets.get("military_floor", 100000))
	realm ["military_ceiling"] = int(stockpile_targets.get("military_ceiling", realm.get("military_floor", 100000)))
	realm ["goods_floor"] = int(stockpile_targets.get("goods_floor", 25000))
	realm ["goods_ceiling"] = int(stockpile_targets.get("goods_ceiling", realm.get("goods_floor", 25000)))

	if int(realm.get("military_stockpile", 0)) <= 0:
		realm ["military_stockpile"] = int(realm.get("military_floor", stockpile_targets.get("military_floor", 100000)))
	if int(realm.get("goods_stockpile", 0)) <= 0:
		realm ["goods_stockpile"] = int(realm.get("goods_floor", stockpile_targets.get("goods_floor", 25000)))

	if str(realm.get("currency_name", "")).strip_edges() == "":
		realm ["currency_name"] = str(defaults.get("currency_name", "Crowns"))
	if str(realm.get("government_style", "")).strip_edges() == "":
		realm ["government_style"] = str(defaults.get("government_style", "Monarchy"))
	if int(realm.get("country_quality", 0)) <= 0:
		realm ["country_quality"] = int(defaults.get("country_quality", randi_range(45, 88)))
	if str(realm.get("land_label", "")).strip_edges() == "":
		realm ["land_label"] = str(defaults.get("land_label", "Territory"))
	if str(realm.get("realm_kind", "")).strip_edges() == "":
		realm ["realm_kind"] = str(defaults.get("realm_kind", "state"))

	realm ["subzones"] = city_names.duplicate(true)
	if str(realm.get("capital_city", "")).strip_edges() == "" and not city_names.is_empty():
		realm ["capital_city"] = str(city_names [0])

	realm ["population_previous_year"] = int(realm.get("population_previous_year", realm.get("population", 0)))
	realm ["population_change_last_year"] = int(realm.get("population_change_last_year", 0))
	realm ["population_births_last_year"] = int(realm.get("population_births_last_year", 0))
	realm ["population_deaths_last_year"] = int(realm.get("population_deaths_last_year", 0))
	realm ["population_migration_last_year"] = int(realm.get("population_migration_last_year", 0))
	realm ["population_change_pct_last_year"] = float(realm.get("population_change_pct_last_year", 0.0))

	realm = _apply_realm_contract_defaults(realm_id, realm)
	realms [realm_id] = realm
	_ensure_minimum_realm_stockpiles(realm_id)

	var refreshed_raw: Variant = realms.get(realm_id, realm)
	var refreshed: Dictionary = refreshed_raw if typeof(refreshed_raw) == TYPE_DICTIONARY else realm
	ensure_minimum_realm_resident_pool(realm_id, refreshed, preferred_city)
	ensure_realm_governance(realm_id, preferred_city)

	var final_raw: Variant = realms.get(realm_id, refreshed)
	var final_realm: Dictionary = final_raw if typeof(final_raw) == TYPE_DICTIONARY else refreshed
	return final_realm

func _realm_contract_only_boot_active() -> bool:
	if gs == null:
		return false

	if (
		gs.has_method(
			"resident_blocking_birth_lane_active"
		)
		and bool(
			gs.resident_blocking_birth_lane_active()
		)
	):
		return true

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		return false

	if bool(
		gs.scenario_state.get(
			"birth_shell_player_control_released",
			false
		)
	):
		return false

	return (
		bool(
			gs.scenario_state.get(
				"god_mode_life_prewarm_active",
				false
			)
		)
		or bool(
			gs.scenario_state.get(
				"god_mode_life_prewarm_background_worker",
				false
			)
		)
		or bool(
			gs.scenario_state.get(
				"birth_shell_first_boot_active",
				false
			)
		)
		or bool(
			gs.scenario_state.get(
				"birth_shell_deferred_boot_pending",
				false
			)
		)
		or bool(
			gs.scenario_state.get(
				"royalty_heavy_bootstrap_forbidden_during_prewarm",
				false
			)
		)
		or bool(
			gs.scenario_state.get(
				"royal_first_frame_shell_truth_only",
				false
			)
		)
		or bool(
			gs.scenario_state.get(
				"royal_house_heavy_bootstrap_deferred",
				false
			)
		)
		or (
			bool(
				gs.scenario_state.get(
					"prebirth_reality_locked",
					false
				)
			)
			and not bool(
				gs.scenario_state.get(
					"birth_shell_player_control_released",
					false
				)
			)
		)
	)
func ensure_realm_for_country(country_name: String, preferred_city: String = "") -> int:
	var target_name: String = str(country_name).strip_edges()
	if target_name == "":
		return -1

	var contract_only_boot: bool = _realm_contract_only_boot_active()

	for raw_realm_id in realms.keys():
		var realm_id: int = int(raw_realm_id)
		var realm_raw: Variant = realms.get(realm_id, {})
		var realm: Dictionary = realm_raw if typeof(realm_raw) == TYPE_DICTIONARY else {}
		var realm_name: String = str(realm.get("name", "")).strip_edges()
		if realm_name.to_lower() != target_name.to_lower():
			continue

		realm ["realm_contract_ready"] = true
		realm ["realm_population_surface_contract_ready"] = true
		realm ["realm_contract_resolved_from_country"] = target_name
		realm ["realm_contract_resolved_at_ms"] = int(Time.get_ticks_msec())

		if contract_only_boot:
			realm ["realm_contract_only_boot"] = true
			realm ["realm_contract_only_reason"] = "royal_first_frame_shell_truth_only"
			realm ["realm_governance_bootstrap_deferred"] = true
			realm ["realm_resident_pool_bootstrap_deferred"] = true
			realms [realm_id] = _apply_realm_contract_defaults(realm_id, realm)

			if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
				gs.scenario_state ["realm_contract_id_resolved_during_prewarm"] = realm_id
				gs.scenario_state ["realm_contract_country_resolved_during_prewarm"] = target_name
				gs.scenario_state ["realm_governance_bootstrap_deferred_during_prewarm"] = true
				gs.scenario_state ["realm_governance_bootstrap_deferred_realm_id"] = realm_id
				gs.scenario_state ["realm_governance_bootstrap_deferred_country"] = target_name
				gs.scenario_state ["realm_governance_bootstrap_deferred_reason"] = "royal_first_frame_shell_truth_only"

			return realm_id

		realms [realm_id] = _apply_realm_contract_defaults(realm_id, realm)
		ensure_realm_defaults(realm_id, preferred_city)
		ensure_realm_governance(realm_id, preferred_city)
		return realm_id

	var era_key: String = _bootstrap_era_key()
	var city_names: Array = []
	if gs != null and gs.era_engine != null and gs.era_engine.has_method("get_cities_for_era_country"):
		city_names = gs.era_engine.get_cities_for_era_country(era_key, target_name)

	if preferred_city != "" and not city_names.has(preferred_city):
		city_names.push_front(preferred_city)

	var new_id: int = 1
	if realms.size() > 0:
		new_id = int(realms.keys().max()) + 1

	var new_realm: Dictionary = _build_realm_row_from_country(target_name, _current_era_name("Modern Era"), city_names)
	new_realm ["id"] = str(new_id)
	new_realm ["realm_contract_ready"] = true
	new_realm ["realm_population_surface_contract_ready"] = true
	new_realm ["realm_contract_resolved_from_country"] = target_name
	new_realm ["realm_contract_resolved_at_ms"] = int(Time.get_ticks_msec())

	if contract_only_boot:
		new_realm ["realm_contract_only_boot"] = true
		new_realm ["realm_contract_only_reason"] = "royal_first_frame_shell_truth_only"
		new_realm ["realm_governance_bootstrap_deferred"] = true
		new_realm ["realm_resident_pool_bootstrap_deferred"] = true
		new_realm ["created_as_lightweight_realm_contract"] = true
		new_realm ["created_as_lightweight_realm_contract_at_ms"] = int(Time.get_ticks_msec())

	realms [new_id] = _apply_realm_contract_defaults(new_id, new_realm)

	if contract_only_boot:
		if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
			gs.scenario_state ["realm_creation_deferred_during_prewarm"] = true
			gs.scenario_state ["realm_creation_deferred_country"] = target_name
			gs.scenario_state ["realm_creation_deferred_preferred_city"] = preferred_city
			gs.scenario_state ["realm_creation_deferred_reason"] = "lightweight_realm_contract_created_heavy_tail_deferred"
			gs.scenario_state ["realm_creation_deferred_at_ms"] = int(Time.get_ticks_msec())
			gs.scenario_state ["realm_contract_id_created_during_prewarm"] = new_id
		return new_id

	ensure_realm_defaults(new_id, preferred_city)
	ensure_realm_governance(new_id, preferred_city)
	return new_id
func ensure_realm_population_surface_contract(realm_id: int, preferred_city: String = "", context: Dictionary = {}) -> Dictionary:
	if gs == null or realm_id <= 0 or not realms.has(realm_id):
		return {
			"success": false,
			"realm_id": realm_id,
			"reason": "missing_realm"
		}

	var contract_only_boot: bool = _realm_contract_only_boot_active()
	var realm_raw: Variant = realms.get(realm_id, {})
	var realm: Dictionary = realm_raw if typeof(realm_raw) == TYPE_DICTIONARY else {}
	if realm.is_empty():
		return {
			"success": false,
			"realm_id": realm_id,
			"reason": "empty_realm_contract"
		}

	var source: String = str(context.get("source", "realm_population_surface_contract")).strip_edges()
	var ui_is_renderer: bool = bool(context.get("ui_is_renderer", false))
	var prewarm_path: bool = bool(context.get("prewarm_path", false))
	var click_path: bool = bool(context.get("click_path", false))
	var force_materialize_for_lens: bool = bool(context.get("force_materialize_for_population_lens", false))

	var source_key: String = source.to_lower()
	var source_says_click: bool = source_key.find("open") >= 0 or source_key.find("click") >= 0
	var click_source: bool = click_path or (source_says_click and not prewarm_path)

	var allow_materialization: bool = bool(context.get("allow_resident_materialization", false))
	var allow_governance_bootstrap: bool = bool(context.get("allow_governance_bootstrap", allow_materialization))

	if force_materialize_for_lens and prewarm_path:
		allow_materialization = true
		allow_governance_bootstrap = true
		contract_only_boot = false
		ui_is_renderer = false
		click_source = false

	realm ["realm_contract_ready"] = true
	realm ["realm_population_surface_contract_ready"] = true
	realm ["realm_population_surface_contract_source"] = source
	realm ["realm_population_surface_contract_at_ms"] = int(Time.get_ticks_msec())
	realm ["realm_population_surface_is_view_contract"] = true
	realm ["realm_population_surface_ui_renderer_only"] = ui_is_renderer
	realm ["realm_population_surface_click_materialization_forbidden"] = ui_is_renderer or click_source
	realm ["realm_population_surface_prewarm_path"] = prewarm_path
	realm ["realm_population_surface_click_path"] = click_path
	realm ["realm_population_surface_force_materialize_for_lens"] = force_materialize_for_lens

	if contract_only_boot or ui_is_renderer or click_source or not allow_materialization:
		realm ["realm_contract_only_boot"] = contract_only_boot
		realm ["realm_resident_pool_bootstrap_deferred"] = true
		realm ["realm_governance_bootstrap_deferred"] = true
		realm ["realm_population_surface_deferred_reason"] = "contract_only_or_click_path"
		realms [realm_id] = _apply_realm_contract_defaults(realm_id, realm)

		return {
			"success": true,
			"realm_id": realm_id,
			"realm": realms.get(realm_id, realm),
			"deferred": true,
			"view_contract_only": true,
			"reason": "ui_renderer_or_contract_only_surface",
			"prewarm_path": prewarm_path,
			"click_path": click_path,
			"click_source": click_source,
			"source": source
		}

	var hydrated: Dictionary = ensure_realm_defaults(realm_id, preferred_city)
	if hydrated.is_empty():
		hydrated = realm

	ensure_minimum_realm_resident_pool(realm_id, hydrated, preferred_city)

	if allow_governance_bootstrap:
		ensure_realm_governance(realm_id, preferred_city)

	var final_raw: Variant = realms.get(realm_id, hydrated)
	var final_realm: Dictionary = final_raw if typeof(final_raw) == TYPE_DICTIONARY else hydrated
	final_realm ["realm_contract_ready"] = true
	final_realm ["realm_population_surface_contract_ready"] = true
	final_realm ["realm_resident_pool_bootstrap_deferred"] = false
	final_realm ["realm_governance_bootstrap_deferred"] = not allow_governance_bootstrap
	final_realm ["realm_population_surface_is_view_contract"] = true
	final_realm ["realm_population_surface_prewarm_path"] = prewarm_path
	final_realm ["realm_population_surface_click_path"] = click_path
	final_realm ["realm_population_surface_force_materialize_for_lens"] = force_materialize_for_lens
	realms [realm_id] = final_realm

	return {
		"success": true,
		"realm_id": realm_id,
		"realm": final_realm.duplicate(true),
		"governance_ready": allow_governance_bootstrap,
		"deferred": false,
		"view_contract_only": false,
		"prewarm_path": prewarm_path,
		"click_path": click_path,
		"click_source": click_source,
		"source": source
	}
func _resolve_npc(arg) -> Person:
	if arg == null:
		return null

	if arg is Person:
		return arg

	if typeof(arg) == TYPE_DICTIONARY:
		var npc_id = arg.get("npc_id", -1)
		if npc_id == -1:
			return null
		return gs.get_npc_by_id(npc_id)

	if typeof(arg) == TYPE_INT:
		return gs.get_npc_by_id(arg)

	return null

func _ambient_assignable_realm_ids() -> Array:
	var ids: Array = []

	for raw_id in realms.keys():
		var realm_id: int = int(raw_id)
		var realm_raw: Variant = realms.get(raw_id, realms.get(realm_id, {}))
		if typeof(realm_raw) != TYPE_DICTIONARY:
			continue

		var realm: Dictionary = realm_raw
		if _realm_requires_migration_contract(realm):
			continue

		ids.append(realm_id)

	return ids
func assign_realm(arg):
	var npc = _resolve_npc(arg)
	if npc == null:
		return

	var preferred_city: String = str(
		npc.home_city if str(npc.home_city).strip_edges() != "" else npc.birth_city
	).strip_edges()

	var contract_only_boot: bool = _realm_contract_only_boot_active()

	if int(npc.realm_id) > 0 and realms.has(int(npc.realm_id)):
		var existing_raw: Variant = realms.get(int(npc.realm_id), {})
		var existing_realm: Dictionary = existing_raw if typeof(existing_raw) == TYPE_DICTIONARY else {}

		if contract_only_boot:
			existing_realm ["realm_contract_ready"] = true
			existing_realm ["realm_population_surface_contract_ready"] = true
			existing_realm ["realm_contract_only_boot"] = true
			existing_realm ["realm_governance_bootstrap_deferred"] = true
			existing_realm ["realm_resident_pool_bootstrap_deferred"] = true
			realms [int(npc.realm_id)] = _apply_realm_contract_defaults(int(npc.realm_id), existing_realm)
			_apply_elemental_realm_identity_to_npc(npc, str(existing_realm.get("name", "")))
			return

		existing_realm = ensure_realm_defaults(int(npc.realm_id), preferred_city)
		_ensure_minimum_realm_stockpiles(int(npc.realm_id))
		ensure_minimum_realm_resident_pool(int(npc.realm_id), existing_realm, preferred_city)
		ensure_realm_governance(int(npc.realm_id), preferred_city)
		_apply_elemental_realm_identity_to_npc(npc, str(existing_realm.get("name", "")))
		register_npc_with_realm_military(npc)
		return

	var preferred_names: Array = []
	for raw_name in [
		str(npc.home_country).strip_edges(),
		str(npc.birth_country).strip_edges(),
		str(npc.bending_nation).strip_edges()
	]:
		var clean_name: String = str(raw_name).strip_edges()
		if clean_name == "":
			continue
		if not preferred_names.has(clean_name):
			preferred_names.append(clean_name)

	for preferred_name in preferred_names:
		var ensured_realm_id: int = ensure_realm_for_country(preferred_name, preferred_city)
		if ensured_realm_id > 0:
			npc.realm_id = ensured_realm_id

			var ensured_raw: Variant = realms.get(ensured_realm_id, {})
			var ensured_realm: Dictionary = ensured_raw if typeof(ensured_raw) == TYPE_DICTIONARY else {}

			if contract_only_boot:
				ensured_realm ["realm_contract_ready"] = true
				ensured_realm ["realm_population_surface_contract_ready"] = true
				ensured_realm ["realm_contract_only_boot"] = true
				ensured_realm ["realm_governance_bootstrap_deferred"] = true
				ensured_realm ["realm_resident_pool_bootstrap_deferred"] = true
				realms [ensured_realm_id] = _apply_realm_contract_defaults(ensured_realm_id, ensured_realm)
				_apply_elemental_realm_identity_to_npc(npc, str(ensured_realm.get("name", preferred_name)))
				return

			ensured_realm = ensure_realm_defaults(ensured_realm_id, preferred_city)
			_ensure_minimum_realm_stockpiles(ensured_realm_id)
			ensure_minimum_realm_resident_pool(ensured_realm_id, ensured_realm, preferred_city)
			ensure_realm_governance(ensured_realm_id, preferred_city)
			_apply_elemental_realm_identity_to_npc(npc, str(ensured_realm.get("name", preferred_name)))
			register_npc_with_realm_military(npc)
			return

	var ids: Array = _ambient_assignable_realm_ids()
	if ids.size() == 0:
		return

	var pick = ids [randi() % ids.size()]
	npc.realm_id = int(pick)

	var fallback_raw: Variant = realms.get(int(npc.realm_id), {})
	var fallback_realm: Dictionary = fallback_raw if typeof(fallback_raw) == TYPE_DICTIONARY else {}

	if contract_only_boot:
		fallback_realm ["realm_contract_ready"] = true
		fallback_realm ["realm_population_surface_contract_ready"] = true
		fallback_realm ["realm_contract_only_boot"] = true
		fallback_realm ["realm_governance_bootstrap_deferred"] = true
		fallback_realm ["realm_resident_pool_bootstrap_deferred"] = true
		realms [int(npc.realm_id)] = _apply_realm_contract_defaults(int(npc.realm_id), fallback_realm)
		_apply_elemental_realm_identity_to_npc(npc, str(fallback_realm.get("name", "")))
		return

	fallback_realm = ensure_realm_defaults(int(npc.realm_id), preferred_city)
	_ensure_minimum_realm_stockpiles(int(npc.realm_id))
	ensure_minimum_realm_resident_pool(int(npc.realm_id), fallback_realm, preferred_city)
	ensure_realm_governance(int(npc.realm_id), preferred_city)
	_apply_elemental_realm_identity_to_npc(npc, str(fallback_realm.get("name", "")))
	register_npc_with_realm_military(npc)
func ensure_minimum_realm_resident_pool(realm_id: int, realm: Dictionary = {}, preferred_city: String = "") -> void:
	if gs == null or gs.npc_factory == null or realm_id <= 0 or not realms.has(realm_id):
		return

	var realm_dict: Dictionary = realm if typeof(realm) == TYPE_DICTIONARY else {}
	if realm_dict.is_empty():
		var realm_raw: Variant = realms.get(realm_id, {})
		realm_dict = realm_raw if typeof(realm_raw) == TYPE_DICTIONARY else {}
	if realm_dict.is_empty():
		return

	if _realm_requires_migration_contract(realm_dict):
		realm_dict ["realm_resident_pool_bootstrap_deferred"] = true
		realm_dict ["resident_pool_authority"] = "population_movement_contract_engine"
		realm_dict ["population_is_registry_derived"] = true
		realm_dict ["visible_residents_are_view_contract"] = true
		realms [realm_id] = realm_dict
		return

	var role_summary: Dictionary = _summarize_realm_bootstrap_roles(realm_id)
	var active_population: int = int(role_summary.get("total", 0))
	var plan: Dictionary = _build_realm_bootstrap_population_plan(realm_dict, active_population)

	var minimum_residents: int = int(plan.get("minimum_residents", 12))
	var worker_target: int = int(plan.get("worker_target", 8))
	var soldier_target: int = int(plan.get("soldier_target", 2))
	var noble_target: int = int(plan.get("noble_target", 1))

	var role_queue: Array = []
	var worker_deficit: int = max(worker_target - int(role_summary.get("worker", 0)), 0)
	var soldier_deficit: int = max(soldier_target - int(role_summary.get("soldier", 0)), 0)
	var noble_deficit: int = max(noble_target - int(role_summary.get("noble", 0)), 0)

	for i in range(worker_deficit):
		role_queue.append("worker")
	for i in range(soldier_deficit):
		role_queue.append("soldier")
	for i in range(noble_deficit):
		role_queue.append("noble")

	while role_queue.size() + active_population < minimum_residents:
		role_queue.append("worker")

	var created_count: int = 0
	for raw_role in role_queue:
		var role_key: String = str(raw_role).strip_edges()
		if role_key == "":
			continue
		var created: Person = create_bootstrap_realm_resident(realm_id, preferred_city, role_key)
		if created == null:
			break
		created_count += 1

	if created_count <= 0:
		return

	var live_population: int = get_total_population_for_realm(realm_id)
	realm_dict ["population"] = max(int(realm_dict.get("population", 0)), live_population)
	realm_dict ["visible_resident_floor"] = minimum_residents
	realms [realm_id] = realm_dict

func assign_realms_to_all_living_npcs() -> void:
	if gs == null:
		return

	var touched_realms: Dictionary = {}

	for raw_npc in gs.npcs:
		var npc: Person = raw_npc
		if npc == null or not npc.alive:
			continue

		var preferred_city: String = str(
			npc.home_city if str(npc.home_city).strip_edges() != "" else npc.birth_city
		).strip_edges()

		var realm_id: int = int(npc.realm_id)
		if realm_id <= 0 or not realms.has(realm_id):
			assign_realm(npc)
			realm_id = int(npc.realm_id)
			if realm_id <= 0 or not realms.has(realm_id):
				continue
		else:
			var realm_raw: Variant = realms.get(realm_id, {})
			var realm: Dictionary = realm_raw if typeof(realm_raw) == TYPE_DICTIONARY else {}
			if not realm.is_empty():
				_apply_elemental_realm_identity_to_npc(npc, str(realm.get("name", "")))
			register_npc_with_realm_military(npc)

		if not touched_realms.has(realm_id):
			touched_realms [realm_id] = preferred_city
		elif str(touched_realms.get(realm_id, "")).strip_edges() == "" and preferred_city != "":
			touched_realms [realm_id] = preferred_city

	for raw_realm_id in touched_realms.keys():
		var stable_realm_id: int = int(raw_realm_id)
		if stable_realm_id <= 0 or not realms.has(stable_realm_id):
			continue

		var preferred_city: String = str(touched_realms.get(stable_realm_id, "")).strip_edges()
		var hydrated: Dictionary = ensure_realm_defaults(stable_realm_id, preferred_city)

		var realm_raw: Variant = realms.get(stable_realm_id, {})
		var realm: Dictionary = hydrated if not hydrated.is_empty() else (realm_raw if typeof(realm_raw) == TYPE_DICTIONARY else {})
		if realm.is_empty():
			continue

		_ensure_minimum_realm_stockpiles(stable_realm_id)
		ensure_minimum_realm_resident_pool(stable_realm_id, realm, preferred_city)
		ensure_realm_governance(stable_realm_id, preferred_city)


func ensure_realm_governance(realm_id: int, preferred_city: String = "") -> Dictionary:
	if gs == null or realm_id <= 0 or not realms.has(realm_id):
		return {}

	var realm_raw: Variant = realms.get(realm_id, {})
	var realm: Dictionary = realm_raw if typeof(realm_raw) == TYPE_DICTIONARY else {}
	if realm.is_empty():
		return {}

	_ensure_realm_military_registry(realm_id, realm)

	var living_ruler: Person = _find_living_realm_ruler(realm_id)
	if living_ruler != null:
		sync_realm_ruler_from_person(living_ruler)
		var synced_raw: Variant = realms.get(realm_id, realm)
		return synced_raw if typeof(synced_raw) == TYPE_DICTIONARY else realm

	var claimant: Person = _find_best_realm_claimant(realm_id)
	if claimant != null:
		claimant.is_ruler = true
		claimant.is_royal = true
		claimant.deposed = false
		claimant.exiled = false
		claimant.palace_owned = true
		claimant.succession_rank = 0
		if str(claimant.royal_title).strip_edges() == "":
			claimant.royal_title = _default_realm_ruler_title(realm)
		sync_realm_ruler_from_person(claimant)
		var claimant_raw: Variant = realms.get(realm_id, realm)
		return claimant_raw if typeof(claimant_raw) == TYPE_DICTIONARY else realm

	var anchor: Person = _create_realm_governance_anchor(realm_id, realm, preferred_city)
	if anchor != null:
		sync_realm_ruler_from_person(anchor)

	var final_raw: Variant = realms.get(realm_id, realm)
	return final_raw if typeof(final_raw) == TYPE_DICTIONARY else realm


func _find_living_realm_ruler(realm_id: int) -> Person:
	if gs == null or realm_id <= 0:
		return null

	var realm_raw: Variant = realms.get(
		realm_id,
		{}
	)
	var realm: Dictionary = (
		realm_raw
		if typeof(realm_raw) == TYPE_DICTIONARY
		else {}
	)
	var ruler_id: int = int(
		realm.get(
			"ruler_id",
			-1
		)
	)
	var controlled_actor: Person = gs.player




	if (
		ruler_id > 0
		and controlled_actor != null
		and int(controlled_actor.id) == ruler_id
		and controlled_actor.alive
		and int(controlled_actor.realm_id) == realm_id
		and bool(controlled_actor.is_ruler)
	):
		return controlled_actor

	if ruler_id > 0:
		var stored_ruler = (
			gs.get_or_reactivate_npc_by_id(
				ruler_id
			)
		)

		if (
			stored_ruler != null
			and stored_ruler.alive
			and int(stored_ruler.realm_id) == realm_id
			and bool(stored_ruler.is_ruler)
		):
			return stored_ruler




	if (
		controlled_actor != null
		and controlled_actor.alive
		and int(controlled_actor.realm_id) == realm_id
		and bool(controlled_actor.is_ruler)
	):
		return controlled_actor

	for raw_npc in gs.npcs:
		var npc: Person = raw_npc

		if npc == null or not npc.alive:
			continue

		if int(npc.realm_id) != realm_id:
			continue

		if bool(npc.is_ruler):
			return npc

	if typeof(gs.dormant_npcs) == TYPE_DICTIONARY:
		for raw_npc_id in gs.dormant_npcs.keys():
			var snapshot_raw: Variant = (
				gs.dormant_npcs.get(
					raw_npc_id,
					{}
				)
			)
			var snapshot: Dictionary = (
				snapshot_raw
				if typeof(snapshot_raw) == TYPE_DICTIONARY
				else {}
			)

			if snapshot.is_empty():
				continue

			if not bool(
				snapshot.get(
					"alive",
					true
				)
			):
				continue

			if int(
				snapshot.get(
					"realm_id",
					-1
				)
			) != realm_id:
				continue

			if not bool(
				snapshot.get(
					"is_ruler",
					false
				)
			):
				continue

			var npc = (
				gs.get_or_reactivate_npc_by_id(
					int(raw_npc_id)
				)
			)

			if (
				npc != null
				and npc.alive
				and int(npc.realm_id) == realm_id
			):
				return npc

	return null


func _find_best_realm_claimant(realm_id: int) -> Person:
	if gs == null or realm_id <= 0:
		return null

	var best: Person = null
	var best_rank: int = 999999
	var best_approval: float = -999999.0

	for raw_npc in gs.npcs:
		var npc: Person = raw_npc
		if npc == null or not npc.alive:
			continue
		if int(npc.realm_id) != realm_id:
			continue
		if not bool(npc.is_royal) and int(npc.succession_rank) <= 0 and str(npc.royal_title).strip_edges() == "":
			continue
		if bool(npc.exiled):
			continue
		if int(npc.succession_rank) > 0 and int(npc.succession_rank) < best_rank:
			best = npc
			best_rank = int(npc.succession_rank)
			best_approval = float(npc.approval)
			continue
		if best == null and float(npc.approval) > best_approval:
			best = npc
			best_approval = float(npc.approval)

	return best


func _create_realm_governance_anchor(realm_id: int, realm: Dictionary, preferred_city: String = "") -> Person:
	if gs == null:
		return null

	var created: Person = create_bootstrap_realm_resident(realm_id, preferred_city, "noble")
	if created == null:
		return null

	created.is_ruler = true
	created.is_royal = true
	created.social_class = "Royal"
	created.deposed = false
	created.exiled = false
	created.palace_owned = true
	created.succession_rank = 0
	created.royal_title = _default_realm_ruler_title(realm)
	if str(created.job).strip_edges() == "":
		created.job = _default_realm_governance_job(realm)
	return created


func sync_realm_ruler_from_person(
	ruler: Person
) -> void:
	if (
		ruler == null
		or not ruler.alive
	):
		return

	var realm_id: int = int(
		ruler.realm_id
	)

	if (
		realm_id <= 0
		or not realms.has(
			realm_id
		)
	):
		return

	var realm_raw: Variant = realms.get(
		realm_id,
		{}
	)
	var realm: Dictionary = (
		realm_raw as Dictionary
		if typeof(
			realm_raw
		) == TYPE_DICTIONARY
		else {}
	)

	if realm.is_empty():
		return

	realm [
		"ruler_id"
	] = int(
		ruler.id
	)

	if (
		gs != null
		and gs.royalty_engine != null
		and gs.royalty_engine.has_method(
			"_house_key"
		)
	):
		realm [
			"ruler_house_key"
		] = gs.royalty_engine._house_key(
			ruler
		)

	realms [
		realm_id
	] = realm

	if gs != null:
		for raw_npc in gs.npcs:
			var other: Person = raw_npc

			if other == null:
				continue

			if int(
				other.id
			) == int(
				ruler.id
			):
				continue

			if int(
				other.realm_id
			) != realm_id:
				continue

			if not bool(
				other.is_ruler
			):
				continue

			other.is_ruler = false
			other.palace_owned = false

			if (
				bool(
					other.is_royal
				)
				and gs.royalty_engine != null
				and gs.royalty_engine.has_method(
					"_resolve_rank_title"
				)
			):
				other.deposed = true
				other.royal_title = (
					"Former %s"
					% gs.royalty_engine._resolve_rank_title(
						other,
						"ruler"
					)
				)

	ruler.is_ruler = true
	ruler.is_royal = true
	ruler.social_class = "Royal"
	ruler.deposed = false
	ruler.exiled = false
	ruler.palace_owned = true
	ruler.succession_rank = 0
	ruler.approval = clamp(
		max(
			int(
				ruler.approval
			),
			55
		),
		0,
		100
	)

	var treasury: int = int(
		realm.get(
			"treasury",
			0
		)
	)
	var goods_stockpile: int = int(
		realm.get(
			"goods_stockpile",
			0
		)
	)
	var population: int = int(
		realm.get(
			"population",
			0
		)
	)
	var royal_cash_floor: float = max(
		5000000.0,
		float(
			max(
				treasury * 4,
				5000000
			)
		)
	)

	ruler.bank_balance = max(
		float(
			ruler.bank_balance
		),
		royal_cash_floor
	)
	ruler.income = max(
		float(
			ruler.income
		),
		max(
			250000.0,
			royal_cash_floor * 0.02
		)
	)

	if (
		gs != null
		and gs.royalty_engine != null
		and gs.royalty_engine.has_method(
			"_resolve_rank_title"
		)
	):
		ruler.royal_title = (
			gs.royalty_engine._resolve_rank_title(
				ruler,
				"ruler"
			)
		)
	elif str(
		ruler.royal_title
	).strip_edges() == "":
		ruler.royal_title = (
			_default_realm_ruler_title(
				realm
			)
		)

	if (
		gs != null
		and gs.royalty_engine != null
	):
		if gs.royalty_engine.has_method(
			"_sync_royal_job_identity"
		):
			gs.royalty_engine._sync_royal_job_identity(
				ruler
			)

		if gs.royalty_engine.has_method(
			"_apply_royal_fame_floor"
		):
			gs.royalty_engine._apply_royal_fame_floor(
				ruler
			)

		var house_members: Array = []

		if gs.royalty_engine.has_method(
			"_house_members_for"
		):
			house_members = (
				gs.royalty_engine._house_members_for(
					ruler
				)
			)

		if (
			house_members.is_empty()
			and gs.royalty_engine.has_method(
				"_gather_player_house_members"
			)
		):
			house_members = (
				gs.royalty_engine._gather_player_house_members(
					ruler
				)
			)

		var eligible_royals: Array = []

		for member in house_members:
			if (
				member == null
				or not member.alive
			):
				continue

			if int(
				member.realm_id
			) != realm_id:
				continue

			if (
				not bool(
					member.is_royal
				)
				and not bool(
					member.is_ruler
				)
				and int(
					member.succession_rank
				) <= 0
				and str(
					member.royal_title
				).strip_edges() == ""
			):
				continue

			eligible_royals.append(
				member
			)

		if eligible_royals.is_empty():
			eligible_royals.append(
				ruler
			)

		var realm_wealth_signal: float = float(
			treasury
		)

		realm_wealth_signal += (
			float(
				goods_stockpile
			) * 120.0
		)
		realm_wealth_signal += (
			float(
				population
			) * 6.0
		)

		var family_wealth_pool: float = max(
			12000000.0,
			realm_wealth_signal * 0.22
		)
		var yearly_house_income_pool: float = max(
			600000.0,
			float(
				treasury
			) * 0.05
		)
		var weight_total: float = 0.0
		var weights: Dictionary = {}

		for member in eligible_royals:
			var weight: float = 1.0

			if (
				int(
					member.id
				) == int(
					ruler.id
				)
				or bool(
					member.is_ruler
				)
			):
				weight = 8.0
			elif int(
				member.succession_rank
			) == 1:
				weight = 4.5
			elif (
				member.partner != null
				and bool(
					member.partner.is_ruler
				)
			):
				weight = 3.5
			elif (
				int(
					member.succession_rank
				) > 0
				and int(
					member.succession_rank
				) <= 5
			):
				weight = 2.5
			elif (
				int(
					member.succession_rank
				) > 0
				and int(
					member.succession_rank
				) <= 12
			):
				weight = 1.75

			weights [
				int(
					member.id
				)
			] = weight
			weight_total += weight

		if weight_total <= 0.0:
			weight_total = 1.0

		for member in eligible_royals:
			var member_weight: float = float(
				weights.get(
					int(
						member.id
					),
					1.0
				)
			)
			var share_ratio: float = (
				member_weight
				/ weight_total
			)
			var personal_wealth_floor: float = (
				family_wealth_pool
				* share_ratio
			)
			var personal_income_floor: float = (
				yearly_house_income_pool
				* share_ratio
			)

			if (
				int(
					member.id
				) == int(
					ruler.id
				)
				or bool(
					member.is_ruler
				)
			):
				personal_wealth_floor = max(
					personal_wealth_floor,
					max(
						15000000.0,
						float(
							treasury
						) * 0.3
					)
				)
				personal_income_floor = max(
					personal_income_floor,
					max(
						350000.0,
						float(
							treasury
						) * 0.025
					)
				)
			elif int(
				member.succession_rank
			) == 1:
				personal_wealth_floor = max(
					personal_wealth_floor,
					5000000.0
				)
				personal_income_floor = max(
					personal_income_floor,
					175000.0
				)
			else:
				personal_wealth_floor = max(
					personal_wealth_floor,
					1500000.0
				)
				personal_income_floor = max(
					personal_income_floor,
					80000.0
				)

			member.is_royal = true
			member.social_class = "Royal"
			member.bank_balance = max(
				float(
					member.bank_balance
				),
				personal_wealth_floor
			)
			member.income = max(
				float(
					member.income
				),
				personal_income_floor
			)

			if gs.royalty_engine.has_method(
				"_sync_royal_job_identity"
			):
				gs.royalty_engine._sync_royal_job_identity(
					member
				)

			if gs.royalty_engine.has_method(
				"_apply_royal_fame_floor"
			):
				gs.royalty_engine._apply_royal_fame_floor(
					member
				)

	if (
		gs != null
		and gs.bending_engine != null
		and gs.bending_engine.has_method(
			"ensure_realm_leader_bending_state"
		)
	):
		gs.bending_engine.ensure_realm_leader_bending_state(
			ruler,
			realm
		)

	if (
		gs != null
		and gs.npc_factory != null
		and gs.npc_factory.has_method(
			"seed_spawn_assets_for_npc"
		)
		and int(
			ruler.age
		) >= 18
	):
		gs.npc_factory.seed_spawn_assets_for_npc(
			ruler,
			true
		)




	publish_realm_leader_identity_from_person(
		ruler,
		{
			"realm_id": realm_id,
			"source": (
				"realm_engine."
				+ "sync_realm_ruler_from_person"
			)
		}
	)
func _default_realm_ruler_title(
		realm: Dictionary
) -> String:
		var government_style: String = str(
			realm.get(
				"government_style",
				"State"
			)
		).strip_edges()
		var realm_name: String = str(
			realm.get(
				"name",
				""
			)
		).strip_edges()
		var lower_name: String = realm_name.to_lower()

		if lower_name == "fire nation":
			return "Fire Lord"

		if lower_name == "water tribe":
			return "Chief"

		if lower_name == "earth kingdom":
			return "Earth King"

		if lower_name == "air nomads":
			return "Air Regent"

		match government_style.to_lower():
			"monarchy":
				return "Sovereign"
			"democracy":
				return "President"
			"republic":
				return "President"
			"parliamentary republic":
				return "Prime Minister"
			"dictatorship", "authoritarian", "autocracy":
				return "Supreme Leader"
			"communism":
				return "General Secretary"
			"theocracy":
				return "High Priest"
			"anarchy":
				return "Council Voice"
			_:
				return "Head of State"


func _default_realm_governance_job(realm: Dictionary) -> String:
	var government_style: String = str(realm.get("government_style", "State")).strip_edges()
	match government_style:
		"Monarchy":
			return "Court Official"
		"Democracy":
			return "President"
		"Republic":
			return "Chancellor"
		"Dictatorship":
			return "Supreme Leader"
		"Communism":
			return "General Secretary"
		"Anarchy":
			return "Council Official"
		_:
			return "State Official"


func _ensure_realm_military_registry(realm_id: int, realm: Dictionary = {}) -> void:
	if realm_id <= 0 or not realms.has(realm_id):
		return

	var realm_dict: Dictionary = realm if typeof(realm) == TYPE_DICTIONARY else {}
	if realm_dict.is_empty():
		var realm_raw: Variant = realms.get(realm_id, {})
		realm_dict = realm_raw if typeof(realm_raw) == TYPE_DICTIONARY else {}
	if realm_dict.is_empty():
		return

	if typeof(realm_dict.get("military_member_ids", [])) != TYPE_ARRAY:
		realm_dict ["military_member_ids"] = []
	if str(realm_dict.get("military_branch_name", "")).strip_edges() == "":
		realm_dict ["military_branch_name"] = "%s Military" % str(realm_dict.get("name", "Realm")).strip_edges()

	realms [realm_id] = realm_dict


func register_npc_with_realm_military(npc: Person) -> void:
	if npc == null:
		return
	var realm_id: int = int(npc.realm_id)
	if realm_id <= 0 or not realms.has(realm_id):
		return

	var job_key: String = str(npc.job).strip_edges().to_lower()
	var is_soldier: bool = job_key in ["soldier", "guard", "warrior", "militia", "watchman", "legionary", "spearman", "archer", "officer", "general"]
	if not is_soldier:
		return

	var realm_raw: Variant = realms.get(realm_id, {})
	var realm: Dictionary = realm_raw if typeof(realm_raw) == TYPE_DICTIONARY else {}
	if realm.is_empty():
		return

	_ensure_realm_military_registry(realm_id, realm)
	var member_ids_raw: Variant = realm.get("military_member_ids", [])
	var member_ids: Array = member_ids_raw if typeof(member_ids_raw) == TYPE_ARRAY else []
	var npc_id: int = int(npc.id)
	if not member_ids.has(npc_id):
		member_ids.append(npc_id)
	realm ["military_member_ids"] = member_ids
	realms [realm_id] = realm
func _build_realm_bootstrap_population_plan(realm: Dictionary, active_population: int) -> Dictionary:
	var realm_name: String = str(realm.get("name", "")).strip_edges()
	var realm_kind: String = str(realm.get("realm_kind", "state")).strip_edges().to_lower()
	var government_style: String = str(realm.get("government_style", "State")).strip_edges()
	var era_name: String = _current_era_name("Modern Era")
	var is_avatar_nation: bool = realm_name in ["Earth Kingdom", "Fire Nation", "Water Tribe", "Air Nomads"]

	var minimum_residents: int = 12
	if realm_kind == "nation":
		minimum_residents = 18
	if government_style == "Monarchy":
		minimum_residents = max(minimum_residents, 16)
	if is_avatar_nation:
		minimum_residents = max(minimum_residents, 28)
	if era_name == "Ancient Era" and is_avatar_nation:
		minimum_residents = max(minimum_residents, 34)

	var population_hint: int = max(active_population, int(realm.get("population", 0)))
	minimum_residents = max(minimum_residents, int(round(float(population_hint) / 45000.0)))
	minimum_residents = int(clamp(minimum_residents, 12, 48))

	var noble_target: int = 0
	if government_style == "Monarchy":
		noble_target = 2
	elif realm_kind == "nation":
		noble_target = 1

	if is_avatar_nation:
		noble_target = max(noble_target, 3)

	noble_target = min(noble_target, 6)

	var soldier_target: int = max(2, int(round(float(minimum_residents) * 0.16)))
	if realm_kind == "nation":
		soldier_target = max(soldier_target, 4)
	if is_avatar_nation:
		soldier_target = max(soldier_target, 7)

	var worker_target: int = max(12, minimum_residents - soldier_target - noble_target)
	return {
		"minimum_residents": minimum_residents,
		"worker_target": worker_target,
		"soldier_target": soldier_target,
		"noble_target": noble_target
	}


func _summarize_realm_bootstrap_roles(realm_id: int) -> Dictionary:
	var counts: Dictionary = {
		"total": 0,
		"worker": 0,
		"soldier": 0,
		"noble": 0
	}
	if gs == null:
		return counts

	for raw_npc in gs.npcs:
		var npc: Person = raw_npc
		if npc == null or not npc.alive:
			continue
		if int(npc.realm_id) != realm_id:
			continue

		counts ["total"] = int(counts.get("total", 0)) + 1

		var social_class: String = str(npc.social_class).strip_edges().to_lower()
		var job: String = str(npc.job).strip_edges().to_lower()
		if bool(npc.is_ruler) or bool(npc.is_royal) or str(npc.royal_title).strip_edges() != "" or social_class in ["noble", "royal"]:
			counts ["noble"] = int(counts.get("noble", 0)) + 1
			continue
		if job in ["soldier", "guard", "warrior", "militia", "watchman", "legionary", "spearman", "archer", "officer"]:
			counts ["soldier"] = int(counts.get("soldier", 0)) + 1
			continue

		counts ["worker"] = int(counts.get("worker", 0)) + 1

	return counts


func create_bootstrap_realm_resident(realm_id: int, preferred_city: String = "", forced_role: String = "") -> Person:
	if gs == null or gs.npc_factory == null or realm_id <= 0 or not realms.has(realm_id):
		return null
	var realm_raw: Variant = realms.get(realm_id, {})
	var realm: Dictionary = realm_raw if typeof(realm_raw) == TYPE_DICTIONARY else {}
	if realm.is_empty():
		return null
	var realm_name: String = str(realm.get("name",
	"")).strip_edges()
	var capital_city: String = preferred_city.strip_edges()
	if capital_city == "":
		capital_city = str(realm.get("capital_city",
		"")).strip_edges()
	if capital_city == "":
		var subzones_raw: Variant = realm.get("subzones", [])
		var subzones: Array = subzones_raw if typeof(subzones_raw) == TYPE_ARRAY else []
		if not subzones.is_empty():
			capital_city = str(subzones [0]).strip_edges()
	var generated: Person = gs.npc_factory.create_random_npc(false)
	if generated == null:
		return null
	gs.apply_reality_rules_to_person(generated)
	generated.realm_id = realm_id
	generated.is_ruler = false
	generated.is_royal = false
	generated.deposed = false
	generated.exiled = false
	generated.palace_owned = false
	generated.royal_title = ""
	generated.succession_rank = 99
	if int(generated.age) < 16:
		generated.age = randi_range(18, 52)
	if realm_name != "":
		generated.home_country = realm_name
		generated.birth_country = realm_name
	if capital_city != "":
		generated.home_city = capital_city
		generated.birth_city = capital_city
	_apply_elemental_realm_identity_to_npc(generated,
	realm_name)
	_apply_bootstrap_realm_role_to_npc(generated, realm,
	forced_role)
	_apply_bootstrap_realm_name_style_to_npc(generated, realm,
	capital_city, forced_role)
	audit_bootstrap_elemental_realm_population([generated])
	if not gs.npcs.has(generated):
		gs.npcs.append(generated)
	if gs.geo_engine != null and gs.geo_engine.has_method("bootstrap_person_place"):
		var preferred_settlement_id: String = ""
		if gs.geo_engine.has_method("bootstrap_for_current_era"):
			gs.geo_engine.bootstrap_for_current_era()
		var options: Array = gs.geo_engine.realm_to_settlements.get(realm_id, [])
		if not options.is_empty():
			preferred_settlement_id = str(options [0])
		if preferred_settlement_id != "":
			gs.geo_engine.bootstrap_person_place(generated, {
				"settlement_id": preferred_settlement_id
			})
	if gs.world_space_engine != null:
		gs.world_space_engine.place_npc(generated)
	if gs.chunk_simulation_engine != null:
		gs.chunk_simulation_engine.assign_npc(generated)
	register_npc_with_realm_military(generated)
	var refreshed_population: int = get_total_population_for_realm(realm_id)
	realm ["population"] = max(int(realm.get("population", 0)),
	refreshed_population)
	realms [realm_id] = realm
	return generated

func _realm_population_seed_value(npc: Person, realm: Dictionary, salt: String, min_value: int, max_value: int) -> int:
	if npc == null:
		return min_value

	var realm_name: String = str(realm.get("name", "")).strip_edges()
	var family_key: String = str(npc.last_name).strip_edges()
	if family_key == "":
		family_key = str(npc.birth_country).strip_edges()
	if family_key == "":
		family_key = realm_name

	var seed_text: String = "%s:%s:%s:%d:%d" % [
		realm_name,
		family_key,
		salt,
		int(npc.id),
		int(npc.age)
	]

	var span: int = max(1, max_value - min_value + 1)
	return min_value + (abs(int(hash(seed_text))) % span)


func _realm_population_apply_baselines_for_role(npc: Person, realm: Dictionary, role_key: String) -> void:
	if npc == null:
		return

	var normalized_role: String = str(role_key).strip_edges().to_lower()
	var social_key: String = str(npc.social_class).strip_edges().to_lower()
	var wealth: int = max(0, int(npc.bank_balance))

	var class_band: String = "commoner"

	if normalized_role == "noble" or social_key in ["noble", "high noble", "duke", "duchess", "lord", "lady", "marquess", "marchioness"]:
		class_band = "noble"
	elif social_key in ["merchant", "trader", "artisan", "shopkeeper"]:
		class_band = "merchant"
	elif social_key in ["peasant", "serf", "slave", "lowborn", "low class", "lower class"]:
		class_band = "peasant"

	match class_band:
		"noble":
			npc.health = _realm_population_seed_value(npc, realm, "health:noble", 62, 96)
			npc.mental_health = _realm_population_seed_value(npc, realm, "mental:noble", 48, 92)
			npc.smarts = _realm_population_seed_value(npc, realm, "smarts:noble", 52, 94)
			npc.looks = _realm_population_seed_value(npc, realm, "looks:noble", 42, 92)
			npc.hunger = _realm_population_seed_value(npc, realm, "hunger:noble", 0, 38)
			npc.bank_balance = max(wealth, _realm_population_seed_value(npc, realm, "wealth:noble", 15000, 280000))
		"merchant":
			npc.health = _realm_population_seed_value(npc, realm, "health:merchant", 48, 92)
			npc.mental_health = _realm_population_seed_value(npc, realm, "mental:merchant", 40, 88)
			npc.smarts = _realm_population_seed_value(npc, realm, "smarts:merchant", 48, 90)
			npc.looks = _realm_population_seed_value(npc, realm, "looks:merchant", 34, 86)
			npc.hunger = _realm_population_seed_value(npc, realm, "hunger:merchant", 4, 58)
			npc.bank_balance = max(wealth, _realm_population_seed_value(npc, realm, "wealth:merchant", 3000, 80000))
		"peasant":
			npc.health = _realm_population_seed_value(npc, realm, "health:peasant", 28, 84)
			npc.mental_health = _realm_population_seed_value(npc, realm, "mental:peasant", 22, 78)
			npc.smarts = _realm_population_seed_value(npc, realm, "smarts:peasant", 20, 74)
			npc.looks = _realm_population_seed_value(npc, realm, "looks:peasant", 22, 76)
			npc.hunger = _realm_population_seed_value(npc, realm, "hunger:peasant", 18, 88)
			npc.bank_balance = max(wealth, _realm_population_seed_value(npc, realm, "wealth:peasant", 0, 900))
		_:
			npc.health = _realm_population_seed_value(npc, realm, "health:commoner", 38, 90)
			npc.mental_health = _realm_population_seed_value(npc, realm, "mental:commoner", 32, 84)
			npc.smarts = _realm_population_seed_value(npc, realm, "smarts:commoner", 30, 86)
			npc.looks = _realm_population_seed_value(npc, realm, "looks:commoner", 28, 86)
			npc.hunger = _realm_population_seed_value(npc, realm, "hunger:commoner", 8, 72)
			npc.bank_balance = max(wealth, _realm_population_seed_value(npc, realm, "wealth:commoner", 200, 6000))

	npc.health = clampi(int(round(float(npc.health))), 1, 100)
	npc.mental_health = clampi(int(round(float(npc.mental_health))), 1, 100)
	npc.smarts = clampi(int(round(float(npc.smarts))), 1, 100)
	npc.looks = clampi(int(round(float(npc.looks))), 1, 100)
	npc.hunger = clampi(int(round(float(npc.hunger))), 0, 100)
func _apply_bootstrap_realm_role_to_npc(npc: Person, realm: Dictionary, role_key: String) -> void:
	if npc == null:
		return

	var normalized_role: String = str(role_key).strip_edges().to_lower()
	if normalized_role == "":
		normalized_role = "worker"

	var era_name: String = _current_era_name("Modern Era")
	var government_style: String = str(realm.get("government_style", "State")).strip_edges()

	npc.is_ruler = false
	npc.is_royal = false
	npc.deposed = false
	npc.exiled = false
	npc.palace_owned = false
	npc.royal_title = ""
	npc.succession_rank = 99
	npc.approval = 0

	match normalized_role:
		"soldier":
			npc.social_class = "Commoner"
			if era_name == "Ancient Era":
				npc.job = ["Warrior", "Guard", "Spearman", "Archer"].pick_random()
			elif era_name == "Medieval Era":
				npc.job = ["Guard", "Watchman", "Soldier", "Militia"].pick_random()
			else:
				npc.job = ["Soldier", "Guard", "Militia", "Officer"].pick_random()

		"noble":
			npc.social_class = "Noble"
			if era_name == "Ancient Era":
				npc.job = ["Patrician", "Landholder", "Steward"].pick_random()
			elif era_name == "Medieval Era":
				npc.job = ["Noble", "Landholder", "Steward"].pick_random()
			else:
				npc.job = ["Landholder", "Patrician", "Estate Holder"].pick_random()

			if government_style == "Monarchy":
				npc.approval = _realm_population_seed_value(npc, realm, "noble_approval", 55, 85)

		_:
			if government_style in ["Republic", "Democracy", "Federal Republic", "Constitutional Republic"]:
				var modern_class_roll: int = _realm_population_seed_value(npc, realm, "modern_class_roll", 0, 99)
				if modern_class_roll < 34:
					npc.social_class = "Low Class"
					npc.job = ["Worker", "Laborer", "Cashier", "Cleaner", "Delivery Driver", "Warehouse Worker"].pick_random()
				elif modern_class_roll < 82:
					npc.social_class = "Middle Class"
					npc.job = ["Teacher", "Nurse", "Mechanic", "Clerk", "Technician", "Office Worker"].pick_random()
				elif modern_class_roll < 96:
					npc.social_class = "Upper Class"
					npc.job = ["Manager", "Engineer", "Doctor", "Lawyer", "Business Owner"].pick_random()
				else:
					npc.social_class = "Elite"
					npc.job = ["Executive", "Investor", "Media Owner", "Political Donor"].pick_random()
			elif era_name == "Ancient Era":
				var ancient_roll: int = _realm_population_seed_value(npc, realm, "ancient_class_roll", 0, 99)
				if ancient_roll < 46:
					npc.social_class = "Peasant"
					npc.job = ["Farmer", "Laborer", "Fisher", "Servant"].pick_random()
				elif ancient_roll < 82:
					npc.social_class = "Commoner"
					npc.job = ["Builder", "Artisan", "Potter", "Mason"].pick_random()
				else:
					npc.social_class = "Merchant"
					npc.job = ["Trader", "Merchant", "Shopkeeper", "Caravan Worker"].pick_random()
			elif era_name == "Medieval Era":
				var medieval_roll: int = _realm_population_seed_value(npc, realm, "medieval_class_roll", 0, 99)
				if medieval_roll < 52:
					npc.social_class = "Peasant"
					npc.job = ["Farmer", "Serf", "Laborer", "Servant"].pick_random()
				elif medieval_roll < 83:
					npc.social_class = "Commoner"
					npc.job = ["Blacksmith", "Mason", "Guard", "Baker", "Carpenter"].pick_random()
				else:
					npc.social_class = "Merchant"
					npc.job = ["Merchant", "Trader", "Artisan", "Shopkeeper"].pick_random()
			else:
				var default_roll: int = _realm_population_seed_value(npc, realm, "default_class_roll", 0, 99)
				if default_roll < 34:
					npc.social_class = "Low Class"
					npc.job = ["Worker", "Laborer", "Cleaner", "Driver"].pick_random()
				elif default_roll < 84:
					npc.social_class = "Middle Class"
					npc.job = ["Teacher", "Nurse", "Technician", "Clerk", "Mechanic"].pick_random()
				elif default_roll < 97:
					npc.social_class = "Upper Class"
					npc.job = ["Manager", "Engineer", "Doctor", "Lawyer"].pick_random()
				else:
					npc.social_class = "Elite"
					npc.job = ["Executive", "Investor", "Magnate"].pick_random()

	_realm_population_apply_baselines_for_role(npc, realm, normalized_role)


func _apply_bootstrap_realm_name_style_to_npc(npc: Person, realm: Dictionary, capital_city: String, role_key: String = "worker") -> void:
	if npc == null:
		return

	var realm_name: String = str(realm.get("name", "")).strip_edges()
	var era_name: String = _current_era_name("Modern Era")
	var is_ancient_avatar_nation: bool = era_name == "Ancient Era" and realm_name in ["Earth Kingdom", "Fire Nation", "Water Tribe", "Air Nomads"]
	if not is_ancient_avatar_nation:
		return

	var normalized_role: String = str(role_key).strip_edges().to_lower()
	var lineage_place: String = capital_city.strip_edges()
	if normalized_role == "noble" or lineage_place == "":
		lineage_place = realm_name if realm_name != "" else lineage_place
	if lineage_place == "":
		var subzones_raw: Variant = realm.get("subzones", [])
		var subzones: Array = subzones_raw if typeof(subzones_raw) == TYPE_ARRAY else []
		if not subzones.is_empty():
			lineage_place = str(subzones [0]).strip_edges()
	if lineage_place == "":
		return

	npc.last_name = "of %s" % lineage_place


func declare_war(
	attacker: Person,
	defender_realm_id: int
):
	if (
		attacker == null
		or not attacker.alive
	):
		return (
			"No valid attacker was resolved for this war."
		)

	var attacker_realm_id: int = int(
		attacker.realm_id
	)

	if (
		attacker_realm_id <= 0
		or not realms.has(
			attacker_realm_id
		)
	):
		return (
			"You do not control a valid realm."
		)

	if (
		defender_realm_id <= 0
		or not realms.has(
			defender_realm_id
		)
	):
		return (
			"No valid target realm was resolved."
		)

	if attacker_realm_id == defender_realm_id:
		return (
			"You cannot declare war on your own realm."
		)

	if (
		gs == null
		or gs.war_contract_engine == null
	):
		return (
			"WarContractEngine is unavailable."
		)

	var preview: Dictionary = (
		gs.war_contract_engine
		.emit_war_preview_contract(
			{
				"attacker_realm_id": (
					attacker_realm_id
				),
				"defender_realm_id": (
					defender_realm_id
				),
				"year": int(
					gs.year
				),
				"era_key": (
					str(
						gs.era.name
					)
					if gs.era != null
					else ""
				),
				"declaration_source": (
					"realm_engine_compatibility_facade"
				)
			}
		)
	)

	if not bool(
		preview.get(
			"success",
			false
		)
	):
		return str(
			preview.get(
				"text",
				preview.get(
					"reason",
					"War preview failed."
				)
			)
		)

	if not bool(
		preview.get(
			"declaration_allowed",
			false
		)
	):
		var protection_raw: Variant = preview.get(
			"declaration_protection",
			{}
		)
		var declaration_protection: Dictionary = (
			(protection_raw as Dictionary).duplicate(false)
			if typeof(protection_raw) == TYPE_DICTIONARY
			else {}
		)

		return str(
			declaration_protection.get(
				"reason",
				"That war declaration is unavailable."
			)
		)

	var report: Dictionary = (
		gs.war_contract_engine
		.declare_war_contract(
			{
				"attacker_realm_id": (
					attacker_realm_id
				),
				"defender_realm_id": (
					defender_realm_id
				),
				"year": int(
					gs.year
				),
				"war_preview_contract": preview,
				"declaration_source": (
					"realm_engine_compatibility_facade"
				)
			}
		)
	)

	return str(
		report.get(
			"popup_text",
			report.get(
				"text",
				"War declaration resolved."
			)
		)
	)
func _normalize_realm_match_aliases(realm_name: String) -> Dictionary:
	var aliases: Dictionary = {}
	var clean_name: String = str(realm_name).strip_edges()
	if clean_name == "":
		return aliases

	var key: String = clean_name.to_lower()
	aliases [key] = true

	match clean_name:
		"Earth Kingdom", "Earth Nation":
			aliases ["earth kingdom"] = true
			aliases ["earth nation"] = true
			aliases ["earth"] = true
		"Fire Nation":
			aliases ["fire nation"] = true
			aliases ["fire"] = true
		"Water Tribe", "Northern Water Tribe", "Southern Water Tribe", "Water Nation":
			aliases ["water tribe"] = true
			aliases ["northern water tribe"] = true
			aliases ["southern water tribe"] = true
			aliases ["water nation"] = true
			aliases ["water"] = true
		"Air Nomads", "Air Temples", "Air Nation":
			aliases ["air nomads"] = true
			aliases ["air temples"] = true
			aliases ["air nation"] = true
			aliases ["air"] = true

	if key.find("earth") != -1:
		aliases ["earth kingdom"] = true
		aliases ["earth nation"] = true
		aliases ["earth"] = true
	if key.find("fire") != -1:
		aliases ["fire nation"] = true
		aliases ["fire"] = true
	if key.find("water") != -1:
		aliases ["water tribe"] = true
		aliases ["water nation"] = true
		aliases ["water"] = true
	if key.find("air") != -1:
		aliases ["air nomads"] = true
		aliases ["air temples"] = true
		aliases ["air nation"] = true
		aliases ["air"] = true

	return aliases


func _realm_element_for_name(realm_name: String) -> String:
	var clean_name: String = str(realm_name).strip_edges()
	var key: String = clean_name.to_lower()

	match clean_name:
		"Earth Kingdom", "Earth Nation":
			return "earth"
		"Fire Nation":
			return "fire"
		"Water Tribe", "Northern Water Tribe", "Southern Water Tribe", "Water Nation":
			return "water"
		"Air Nomads", "Air Temples", "Air Nation":
			return "air"

	if key.find("earth") != -1:
		return "earth"
	if key.find("fire") != -1:
		return "fire"
	if key.find("water") != -1:
		return "water"
	if key.find("air") != -1:
		return "air"

	return ""


func _ensure_minimum_realm_stockpiles(
		realm_id: int
) -> void:
		if (
			realm_id <= 0
			or not realms.has(
				realm_id
			)
		):
			return

		var realm_raw: Variant = realms.get(
			realm_id,
			{}
		)
		var realm: Dictionary = (
			realm_raw
			if typeof(realm_raw) == TYPE_DICTIONARY
			else {}
		)

		if realm.is_empty():
			return

		var realm_name: String = str(
			realm.get(
				"name",
				""
			)
		).strip_edges()
		var country_name: String = str(
			realm.get(
				"country",
				realm_name
			)
		).strip_edges()
		var realm_identity: String = (
			realm_name.to_lower()
			.replace(".", "")
			.replace(" ", "")
		)
		var country_identity: String = (
			country_name.to_lower()
			.replace(".", "")
			.replace(" ", "")
		)
		var is_era_kingdom: bool = (
			realm_name == "Era Kingdom"
		)
		var is_united_states: bool = (
			realm_identity in [
				"unitedstates",
				"unitedstatesofamerica",
				"usa",
				"us",
				"america"
			]
			or country_identity in [
				"unitedstates",
				"unitedstatesofamerica",
				"usa",
				"us",
				"america"
			]
		)
		var population: int = max(
			0,
			max(
				int(
					realm.get(
						"population",
						0
					)
				),
				get_total_population_for_realm(
					realm_id
				)
			)
		)

		if is_united_states:
			population = max(
				population,
				100000000
			)

			realm [
				"population_floor"
			] = 100000000
			realm [
				"population_floor_contract"
			] = (
				"united_states_100m_minimum"
			)

		if is_era_kingdom:
			population = max(
				population,
				10000000000
			)

		realm ["population"] = population

		var stockpile_targets: Dictionary = (
			_resolve_realm_stockpile_targets(
				realm,
				population
			)
		)
		var military_floor: int = int(
			stockpile_targets.get(
				"military_floor",
				100000
			)
		)
		var military_ceiling: int = int(
			stockpile_targets.get(
				"military_ceiling",
				max(
					military_floor,
					100000
				)
			)
		)
		var goods_floor: int = int(
			stockpile_targets.get(
				"goods_floor",
				25000
			)
		)
		var goods_ceiling: int = int(
			stockpile_targets.get(
				"goods_ceiling",
				max(
					goods_floor,
					25000
				)
			)
		)

		if is_era_kingdom:
			military_floor = max(
				600000000,
				int(
					round(
						float(population) * 0.06
					)
				)
			)
			military_ceiling = max(
				military_floor,
				int(
					round(
						float(population) * 0.18
					)
				)
			)
			goods_floor = max(
				goods_floor,
				int(
					round(
						float(population) * 0.02
					)
				)
			)
			goods_ceiling = max(
				goods_floor,
				int(
					round(
						float(population) * 0.07
					)
				)
			)

		military_floor = clamp(
			military_floor,
			0,
			max(
				population,
				0
			)
		)
		military_ceiling = clamp(
			max(
				military_floor,
				military_ceiling
			),
			military_floor,
			max(
				population,
				military_floor
			)
		)
		realm ["military_units"] = clamp(
			max(
				int(
					realm.get(
						"military_units",
						military_floor
					)
				),
				0
			),
			0,
			max(
				population,
				0
			)
		)
		realm ["military_floor"] = military_floor
		realm ["military_ceiling"] = max(
			military_floor,
			military_ceiling
		)
		realm ["goods_floor"] = max(
			goods_floor,
			0
		)
		realm ["goods_ceiling"] = max(
			max(
				goods_floor,
				0
			),
			goods_ceiling
		)
		realm ["military_stockpile"] = clamp(
			max(
				int(
					realm.get(
						"military_stockpile",
						realm ["military_units"]
					)
				),
				0
			),
			int(
				realm [
					"military_units"
				]
			),
			max(
				population,
				int(
					realm [
						"military_units"
					]
				)
			)
		)
		realm ["military"] = int(
			realm [
				"military_stockpile"
			]
		)
		realm ["population"] = max(
			population,
			int(
				realm [
					"military_stockpile"
				]
			)
		)
		realm ["goods_stockpile"] = clamp(
			max(
				int(
					realm.get(
						"goods_stockpile",
						0
					)
				),
				0
			),
			max(
				goods_floor,
				0
			),
			max(
				max(
					goods_floor,
					0
				),
				goods_ceiling
			)
		)

		if is_era_kingdom:
			realm ["treasury"] = max(
				int(
					realm.get(
						"treasury",
						0
					)
				),
				int(
					round(
						float(
							realm ["population"]
						) * 42000000.0
					)
				)
			)

		realms [
			realm_id
		] = realm

func _apply_elemental_realm_identity_to_npc(npc: Person, realm_name: String) -> void:
	if npc == null:
		return
	var clean_realm_name: String = str(realm_name).strip_edges()
	if clean_realm_name == "":
		return
	var native_element: String = _realm_element_for_name(clean_realm_name)
	if native_element == "":
		return
	if int(npc.realm_id) <= 0 or not realms.has(int(npc.realm_id)):
		for raw_realm_id in realms.keys():
			var candidate_realm_id: int = int(raw_realm_id)
			var candidate_raw: Variant = realms.get(candidate_realm_id, {})
			var candidate: Dictionary = candidate_raw if typeof(candidate_raw) == TYPE_DICTIONARY else {}
			if str(candidate.get("name", "")).strip_edges() == clean_realm_name:
				npc.realm_id = candidate_realm_id
				break
	var home_country: String = str(npc.home_country).strip_edges()
	var birth_country: String = str(npc.birth_country).strip_edges()
	if home_country == "":
		npc.home_country = clean_realm_name
		home_country = clean_realm_name
	if birth_country == "":
		npc.birth_country = clean_realm_name
		birth_country = clean_realm_name
	var home_matches: bool = home_country == clean_realm_name
	var birth_matches: bool = birth_country == clean_realm_name
	if str(npc.bending_nation).strip_edges() == "" and (home_matches or birth_matches):
		npc.bending_nation = clean_realm_name
	if gs == null or not gs.is_feature_enabled("bending"):
		return
	if typeof(npc.bending_mastery) != TYPE_DICTIONARY:
		npc.bending_mastery = {}
	var current_bending_type: String = str(npc.bending_type).strip_edges().to_lower()
	if current_bending_type == "avatar":
		return
	if current_bending_type in ["", "none"]:
		var native_alignment_roll: int = 58
		if int(npc.age) >= 16 and home_matches and birth_matches:
			native_alignment_roll = 84
		elif int(npc.age) >= 16 and (home_matches or birth_matches):
			native_alignment_roll = 72
		if randi() % 100 < native_alignment_roll:
			npc.bending_type = native_element
			npc.bending_nation = clean_realm_name
			npc.bending_mastery [native_element] = max(int(npc.bending_mastery.get(native_element, 0)), 1)
	elif current_bending_type == native_element:
		npc.bending_nation = clean_realm_name
		if int(npc.bending_mastery.get(native_element, 0)) <= 0:
			npc.bending_mastery [native_element] = 1
func audit_bootstrap_elemental_realm_population(target_npcs: Array = []) -> void:
	if gs == null or not gs.is_feature_enabled("bending"):
		return

	var source_npcs: Array = target_npcs if not target_npcs.is_empty() else gs.npcs
	var grouped: Dictionary = {}

	if gs.bending_engine != null and gs.bending_engine.has_method("ensure_realm_leader_bending_state"):
		for raw_realm_id in realms.keys():
			var realm_id: int = int(raw_realm_id)
			var realm_raw: Variant = realms.get(realm_id, {})
			var realm: Dictionary = realm_raw if typeof(realm_raw) == TYPE_DICTIONARY else {}

			if realm.is_empty():
				continue

			var realm_name: String = str(realm.get("name", "")).strip_edges()
			var native_element: String = _realm_element_for_name(realm_name)

			if native_element == "":
				continue

			var realm_aliases: Dictionary = _normalize_realm_match_aliases(realm_name)
			var ruler_id: int = int(realm.get("ruler_id", realm.get("ruler_npc_id", realm.get("leader_id", -1))))
			var ruler: Person = null

			if ruler_id > 0:
				ruler = gs.get_or_reactivate_npc_by_id(ruler_id)

			if ruler == null:
				var ruler_name: String = str(realm.get("ruler_name", "")).strip_edges().to_lower()
				if ruler_name != "" and ruler_name != "no fixed ruler":
					for raw_named_candidate in gs.npcs:
						var named_candidate: Person = raw_named_candidate
						if named_candidate == null or not named_candidate.alive:
							continue
						var full_name: String = ("%s %s" % [named_candidate.first_name, named_candidate.last_name]).strip_edges().to_lower()
						if full_name == ruler_name:
							ruler = named_candidate
							break

			if ruler == null:
				for raw_candidate in gs.npcs:
					var candidate: Person = raw_candidate
					if candidate == null or not candidate.alive:
						continue
					if not bool(candidate.is_ruler):
						continue

					var candidate_home: String = str(candidate.home_country).strip_edges().to_lower()
					var candidate_birth: String = str(candidate.birth_country).strip_edges().to_lower()
					var candidate_nation: String = str(candidate.bending_nation).strip_edges().to_lower()
					var candidate_matches_realm: bool = int(candidate.realm_id) == realm_id

					if not candidate_matches_realm and candidate_home != "":
						candidate_matches_realm = bool(realm_aliases.get(candidate_home, false))
					if not candidate_matches_realm and candidate_birth != "":
						candidate_matches_realm = bool(realm_aliases.get(candidate_birth, false))
					if not candidate_matches_realm and candidate_nation != "":
						candidate_matches_realm = bool(realm_aliases.get(candidate_nation, false))

					if not candidate_matches_realm:
						continue

					ruler = candidate
					break

			if ruler != null:
				ruler.is_ruler = true
				ruler.realm_id = realm_id

				if str(ruler.home_country).strip_edges() == "":
					ruler.home_country = realm_name
				if str(ruler.birth_country).strip_edges() == "":
					ruler.birth_country = realm_name

				gs.bending_engine.ensure_realm_leader_bending_state(ruler, realm)

				realm ["ruler_id"] = int(ruler.id)
				realm ["ruler_npc_id"] = int(ruler.id)
				realm ["leader_id"] = int(ruler.id)
				realm ["ruler_name"] = ("%s %s" % [ruler.first_name, ruler.last_name]).strip_edges()
				realms [realm_id] = realm

	for raw_npc in source_npcs:
		var npc: Person = raw_npc
		if npc == null or not npc.alive:
			continue
		if int(npc.id) == int(gs.player_id):
			continue
		if int(npc.age) < 16:
			continue

		var resolved_realm_name: String = ""
		var resolved_realm_id: int = int(npc.realm_id)

		if resolved_realm_id > 0 and realms.has(resolved_realm_id):
			var realm_raw: Variant = realms.get(resolved_realm_id, {})
			var realm: Dictionary = realm_raw if typeof(realm_raw) == TYPE_DICTIONARY else {}
			resolved_realm_name = str(realm.get("name", npc.home_country)).strip_edges()

		if resolved_realm_name == "":
			resolved_realm_name = str(npc.home_country).strip_edges()
		if resolved_realm_name == "":
			resolved_realm_name = str(npc.birth_country).strip_edges()

		var native_element: String = _realm_element_for_name(resolved_realm_name)
		if native_element == "":
			continue

		var home_country: String = str(npc.home_country).strip_edges()
		var birth_country: String = str(npc.birth_country).strip_edges()
		var resident_aliases: Dictionary = _normalize_realm_match_aliases(resolved_realm_name)

		var native_linked: bool = home_country == "" or birth_country == ""
		if not native_linked and home_country != "":
			native_linked = bool(resident_aliases.get(home_country.to_lower(), false))
		if not native_linked and birth_country != "":
			native_linked = bool(resident_aliases.get(birth_country.to_lower(), false))

		if not native_linked:
			continue

		_apply_elemental_realm_identity_to_npc(npc, resolved_realm_name)

		if gs.capability_graph_engine != null:
			gs.capability_graph_engine.refresh_bending_capabilities(npc)

		var group_key: String = "%d|%s" % [max(resolved_realm_id, 0), resolved_realm_name]
		var group_packet: Dictionary = grouped.get(group_key, {})

		if group_packet.is_empty():
			group_packet = {
				"realm_name": resolved_realm_name,
				"native_element": native_element,
				"resident_ids": []
			}

		var resident_ids: Array = group_packet.get("resident_ids", [])
		resident_ids.append(int(npc.id))
		group_packet ["resident_ids"] = resident_ids
		grouped [group_key] = group_packet

	for group_key in grouped.keys():
		var packet_raw: Variant = grouped.get(group_key, {})
		var packet: Dictionary = packet_raw if typeof(packet_raw) == TYPE_DICTIONARY else {}
		var realm_name: String = str(packet.get("realm_name", "")).strip_edges()
		var native_element: String = str(packet.get("native_element", "")).strip_edges().to_lower()
		var resident_ids_raw: Variant = packet.get("resident_ids", [])
		var resident_ids: Array = resident_ids_raw if typeof(resident_ids_raw) == TYPE_ARRAY else []

		if realm_name == "" or native_element == "" or resident_ids.is_empty():
			continue

		var active_residents: Array = []
		var aligned_count: int = 0
		var non_bender_candidates: Array = []
		var off_element_candidates: Array = []

		for raw_id in resident_ids:
			var resident: Person = gs.get_npc_by_id(int(raw_id))
			if resident == null or not resident.alive:
				continue

			active_residents.append(resident)

			var resident_element: String = str(resident.bending_type).strip_edges().to_lower()
			if resident_element == native_element:
				aligned_count += 1
				continue

			if resident_element == "avatar" or bool(resident.exiled) or bool(resident.deposed):
				continue

			if resident_element in ["", "none"]:
				non_bender_candidates.append(resident)
			else:
				off_element_candidates.append(resident)

		if active_residents.is_empty():
			continue

		var target_native_count: int = int(ceil(float(active_residents.size()) * 0.78))
		if aligned_count >= target_native_count:
			continue

		var ordered_candidates: Array = []
		ordered_candidates.append_array(non_bender_candidates)
		ordered_candidates.append_array(off_element_candidates)

		for raw_candidate in ordered_candidates:
			var candidate: Person = raw_candidate
			if candidate == null or not candidate.alive:
				continue
			if aligned_count >= target_native_count:
				break

			candidate.bending_type = native_element
			candidate.bending_nation = realm_name
			candidate.avatar_state_unlocked = false
			candidate.avatar_state_used = false

			if typeof(candidate.bending_mastery) != TYPE_DICTIONARY:
				candidate.bending_mastery = {}

			for element_name in ["air", "earth", "fire", "water"]:
				if element_name != native_element and candidate.bending_mastery.has(element_name):
					candidate.bending_mastery [element_name] = 0

			candidate.bending_mastery [native_element] = max(1, int(candidate.bending_mastery.get(native_element, 0)))

			if gs.capability_graph_engine != null:
				gs.capability_graph_engine.refresh_bending_capabilities(candidate)

			aligned_count += 1

func _build_realm_war_aftermath_packet(
	attacker_realm_id: int,
	defender_realm_id: int,
	result_key: String,
	attacker_land_gain: int,
	defender_land_gain: int,
	attacker_treasury_loss: int,
	defender_treasury_loss: int,
	attacker_military_loss: int,
	defender_military_loss: int,
	attacker_goods_loss: int,
	defender_goods_loss: int,
	attacker_ruler_id: int,
	defender_ruler_id: int
) -> Dictionary:
	var attacker_snapshot: Dictionary = get_realm_power_snapshot(attacker_realm_id)
	var defender_snapshot: Dictionary = get_realm_power_snapshot(defender_realm_id)

	var attacker_name: String = str(attacker_snapshot.get("name", "Attacker"))
	var defender_name: String = str(defender_snapshot.get("name", "Defender"))
	var winner_realm_id: int = attacker_realm_id if result_key == "victory" else defender_realm_id
	var loser_realm_id: int = defender_realm_id if result_key == "victory" else attacker_realm_id

	var feed_text: String = ""
	if result_key == "victory":
		feed_text = "⚔️ %s defeated %s, seized %d land, and shook the regional balance of power." % [
			attacker_name,
			defender_name,
			attacker_land_gain
		]
	else:
		feed_text = "⚔️ %s repelled %s, seized %d land, and exposed instability inside the losing realm." % [
			defender_name,
			attacker_name,
			defender_land_gain
		]

	var chronicle_text: String = "%s Treasury loss: %d/%d • Military loss: %d/%d • Goods loss: %d/%d." % [
		feed_text,
		attacker_treasury_loss,
		defender_treasury_loss,
		attacker_military_loss,
		defender_military_loss,
		attacker_goods_loss,
		defender_goods_loss
	]

	return {
		"type": "realm_war_aftermath",
		"year": int(gs.year) if gs != null else 0,
		"result": result_key,
		"winner_realm_id": winner_realm_id,
		"loser_realm_id": loser_realm_id,
		"attacker_realm_id": attacker_realm_id,
		"defender_realm_id": defender_realm_id,
		"attacker_ruler_id": attacker_ruler_id,
		"defender_ruler_id": defender_ruler_id,
		"attacker_land_gain": attacker_land_gain,
		"defender_land_gain": defender_land_gain,
		"attacker_treasury_loss": attacker_treasury_loss,
		"defender_treasury_loss": defender_treasury_loss,
		"attacker_military_loss": attacker_military_loss,
		"defender_military_loss": defender_military_loss,
		"attacker_goods_loss": attacker_goods_loss,
		"defender_goods_loss": defender_goods_loss,
		"feed_text": feed_text,
		"chronicle_text": chronicle_text
	}


func _apply_realm_war_aftershock(packet: Dictionary) -> void:
	if gs == null or typeof(gs.transient_scenario_biases) != TYPE_DICTIONARY:
		return

	var winner_ruler_id: int = int(packet.get("attacker_ruler_id", -1))
	var loser_ruler_id: int = int(packet.get("defender_ruler_id", -1))
	if str(packet.get("result", "")) == "defeat":
		winner_ruler_id = int(packet.get("defender_ruler_id", -1))
		loser_ruler_id = int(packet.get("attacker_ruler_id", -1))

	for pair in [
		{ "npc_id": winner_ruler_id, "coup_delta": -2.5, "succession_delta": -1.5, "realm_tension_delta": 1.5},
		{ "npc_id": loser_ruler_id, "coup_delta": 7.0, "succession_delta": 5.0, "realm_tension_delta": 6.0}
	]:
		var npc_id: int = int(pair.get("npc_id", -1))
		if npc_id <= 0:
			continue

		var existing_bias_raw: Variant = gs.transient_scenario_biases.get(npc_id, {})
		var existing_bias: Dictionary = existing_bias_raw if typeof(existing_bias_raw) == TYPE_DICTIONARY else {}
		var faction_bias_raw: Variant = existing_bias.get("faction_pressure", {})
		var faction_bias: Dictionary = faction_bias_raw if typeof(faction_bias_raw) == TYPE_DICTIONARY else {}

		faction_bias ["coup_pressure"] = float(faction_bias.get("coup_pressure", 0.0)) + float(pair.get("coup_delta", 0.0))
		faction_bias ["royal_succession_tension"] = float(faction_bias.get("royal_succession_tension", 0.0)) + float(pair.get("succession_delta", 0.0))
		faction_bias ["contested_realm_tension"] = float(faction_bias.get("contested_realm_tension", 0.0)) + float(pair.get("realm_tension_delta", 0.0))
		faction_bias ["expiry_year"] = int(gs.year) + 2

		existing_bias ["faction_pressure"] = faction_bias
		gs.transient_scenario_biases [npc_id] = existing_bias


func _queue_realm_war_aftermath_packet(packet: Dictionary) -> void:
	if gs == null or packet.is_empty():
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var packets_raw: Variant = gs.scenario_state.get("realm_war_aftermath_packets", [])
	var packets: Array = packets_raw if typeof(packets_raw) == TYPE_ARRAY else []
	packets.append(packet.duplicate(true))
	gs.scenario_state ["realm_war_aftermath_packets"] = packets

	var feed_text: String = str(packet.get("feed_text", "")).strip_edges()
	if feed_text != "":
		gs.push_world_feed(
			feed_text,
			{
				"npc_id": int(packet.get("winner_ruler_id", packet.get("attacker_ruler_id", -1))),
				"personally_relevant": false,
				"category": "realm",
				"event_name": "realm_war_aftermath",
				"source": "realm_engine"
			}
		)

	if gs.event_bus != null:
		gs.event_bus.emit("realm_war_aftermath", packet.duplicate(true))

	_apply_realm_war_aftershock(packet)

	if gs.universal_faction_engine != null:
		gs.universal_faction_engine.flag_domain_projection_dirty("realm")
		gs.universal_faction_engine.flag_domain_projection_dirty("dynasty")
func yearly_realm_drift(_payload:= {}):
	assign_realms_to_all_living_npcs()

	if (
		gs != null
		and "population_movement_contract_engine" in gs
		and gs.population_movement_contract_engine != null
	):
		if gs.population_movement_contract_engine.has_method(
			"run_yearly_migration_contracts"
		):
			gs.population_movement_contract_engine.run_yearly_migration_contracts({
				"source": "realm_engine_yearly_drift",
				"year": (
					int(gs.year)
					if gs != null
					else 0
				)
			})

	var live_population_map: Dictionary = (
		_build_realm_population_snapshot()
	)

	for id in realms.keys():
		var realm_id: int = int(id)
		var hydrated: Dictionary = (
			ensure_realm_defaults(
				realm_id
			)
		)
		var r: Dictionary = (
			hydrated
			if not hydrated.is_empty()
			else realms [id]
		)

		ensure_realm_governance(
			realm_id,
			str(
				r.get(
					"capital_city",
					""
				)
			).strip_edges()
		)

		var pre_allocation_posture: Dictionary = (
			_capture_realm_governance_posture(
				r
			)
		)
		r = _apply_realm_pending_tax_effects(
			realm_id,
			r
		)

		var live_population: int = int(
			live_population_map.get(
				realm_id,
				0
			)
		)

		if _realm_requires_migration_contract(
			r
		):
			var registry_previous_population: int = int(
				r.get(
					"population",
					live_population
				)
			)
			var capacity_report: Dictionary = (
				_apply_realm_capacity_constraint(
					realm_id,
					r,
					live_population
				)
			)

			r = (
				capacity_report.get(
					"realm",
					r
				)
				if typeof(
					capacity_report.get(
						"realm",
						{}
					)
				) == TYPE_DICTIONARY
				else r
			)

			var registry_next_population: int = int(
				r.get(
					"population",
					min(
						live_population,
						_realm_capacity_for(
							r
						)
					)
				)
			)
			var registry_population_change: int = (
				registry_next_population
				- registry_previous_population
			)

			r [
				"population_previous_year"
			] = registry_previous_population
			r [
				"population_births_last_year"
			] = 0
			r [
				"population_deaths_last_year"
			] = 0
			r [
				"population_migration_last_year"
			] = registry_population_change
			r [
				"population_change_last_year"
			] = registry_population_change
			r [
				"population_change_pct_last_year"
			] = (
				float(
					registry_population_change
				)
				/ float(
					max(
						1,
						registry_previous_population
					)
				)
			)
			r [
				"population_growth_mode"
			] = "registry_derived_migration_contracts"
			r [
				"population"
			] = registry_next_population
			r [
				"abstract_population_drift_disabled"
			] = true
			r [
				"random_population_drift_allowed"
			] = false

			r = _run_ai_realm_allocation_cycle(
				realm_id,
				r
			)
			realms [
				realm_id
			] = r

			_ensure_minimum_realm_stockpiles(
				realm_id
			)

			var registry_refreshed_raw: Variant = realms.get(
				realm_id,
				r
			)
			var registry_refreshed: Dictionary = (
				registry_refreshed_raw
				if typeof(
					registry_refreshed_raw
				) == TYPE_DICTIONARY
				else r
			)

			ensure_realm_governance(
				realm_id,
				str(
					registry_refreshed.get(
						"capital_city",
						""
					)
				).strip_edges()
			)

			_maybe_emit_ai_realm_allocation_posture_shift(
				realm_id,
				pre_allocation_posture,
				registry_refreshed
			)
			continue

		var population_floor: int = max(
			live_population,
			int(
				r.get(
					"population_floor",
					0
				)
			)
		)
		var base_population: int = max(
			int(
				r.get(
					"population",
					0
				)
			),
			live_population,
			population_floor
		)
		var growth_payload: Dictionary = (
			_simulate_realm_population_change(
				r,
				base_population
			)
		)

		var births: int = int(
			growth_payload.get(
				"births",
				0
			)
		)
		var deaths: int = int(
			growth_payload.get(
				"deaths",
				0
			)
		)
		var migration: int = int(
			growth_payload.get(
				"migration",
				0
			)
		)
		var simulated_population_change: int = int(
			growth_payload.get(
				"population_change",
				births - deaths + migration
			)
		)
		var simulated_next_population: int = max(
			population_floor,
			base_population
			+ simulated_population_change
		)
		var population_ceiling: int = int(
			r.get(
				"population_ceiling",
				max(
					simulated_next_population,
					base_population
				)
			)
		)

		if population_ceiling > 0:
			simulated_next_population = min(
				simulated_next_population,
				max(
					population_floor,
					population_ceiling
				)
			)

		r [
			"population_previous_year"
		] = base_population
		r [
			"population_births_last_year"
		] = births
		r [
			"population_deaths_last_year"
		] = deaths
		r [
			"population_migration_last_year"
		] = migration
		r [
			"population_change_last_year"
		] = simulated_population_change
		r [
			"population_change_pct_last_year"
		] = (
			float(
				simulated_population_change
			)
			/ float(
				max(
					1,
					base_population
				)
			)
		)
		r [
			"population_growth_mode"
		] = "births_migration_deaths"
		r [
			"population"
		] = simulated_next_population

		if (
			bool(
				r.get(
					"is_new_starting_realm",
					false
				)
			)
			and simulated_next_population
			>= 750000
		):
			r [
				"is_new_starting_realm"
			] = false

		if randi() % 10 == 0:
			var land_change = randi_range(
				-5,
				5
			)

			r [
				"land"
			] = max(
				int(
					r.get(
						"land",
						r.get(
							"land_size",
							0
						)
					)
				) + land_change,
				0
			)

		r = _run_ai_realm_allocation_cycle(
			realm_id,
			r
		)
		realms [
			realm_id
		] = r

		_ensure_minimum_realm_stockpiles(
			realm_id
		)

		var refreshed_raw: Variant = realms.get(
			realm_id,
			r
		)
		var refreshed: Dictionary = (
			refreshed_raw
			if typeof(
				refreshed_raw
			) == TYPE_DICTIONARY
			else r
		)

		ensure_realm_governance(
			realm_id,
			str(
				refreshed.get(
					"capital_city",
					""
				)
			).strip_edges()
		)

		_maybe_emit_ai_realm_allocation_posture_shift(
			realm_id,
			pre_allocation_posture,
			refreshed
		)


	if (
		gs != null
		and gs.war_contract_engine != null
		and gs.war_contract_engine.has_method(
			"yearly_tick"
		)
	):
		gs.war_contract_engine.yearly_tick({
			"year": int(
				gs.year
			),
			"source": (
				"realm_engine.yearly_realm_drift"
			),
		})
func _apply_realm_population_contract_defaults(
	realm: Dictionary
) -> Dictionary:
	if realm.is_empty():
		return {}

	var out: Dictionary = (
		realm.duplicate(false)
	)




	if bool(
		out.get(
			"is_new_starting_realm",
			false
		)
	):
		return out

	var realm_name: String = str(
		out.get(
			"name",
			""
		)
	).strip_edges()

	var era_name: String = str(
		out.get(
			"era_name",
			_current_era_name(
				"Modern Era"
			)
		)
	).strip_edges()

	var realm_kind: String = str(
		out.get(
			"realm_kind",
			"state"
		)
	).strip_edges()

	var subzones_raw: Variant = out.get(
		"subzones",
		[]
	)

	var zone_count: int = (
		maxi(
			1,
			(subzones_raw as Array).size()
		)
		if typeof(subzones_raw) == TYPE_ARRAY
		else 1
	)

	var population_band: Dictionary = (
		_resolve_realm_population_band(
			realm_name,
			era_name,
			zone_count,
			realm_kind
		)
	)

	var population_floor: int = maxi(
		100000000,
		int(
			population_band.get(
				"min",
				100000000
			)
		)
	)

	var population_ceiling: int = maxi(
		population_floor + 1,
		int(
			population_band.get(
				"max",
				population_floor + 1
			)
		)
	)

	var existing_population_ceiling: int = int(
		out.get(
			"population_ceiling",
			0
		)
	)

	var resident_population: int = int(
		out.get(
			"population",
			0
		)
	)

	out [
		"population_floor"
	] = maxi(
		int(
			out.get(
				"population_floor",
				0
			)
		),
		population_floor
	)








	out [
		"population_ceiling"
	] = maxi(
		maxi(
			existing_population_ceiling,
			population_ceiling
		),
		resident_population
	)

	out [
		"population"
	] = maxi(
		resident_population,
		int(
			out [
				"population_floor"
			]
		)
	)

	out [
		"population_contract_floor_applied"
	] = true
	out [
		"population_contract_floor"
	] = population_floor
	out [
		"population_contract_actor_observation_independent"
	] = true

	return out
func _build_realm_population_snapshot() -> Dictionary:
	var counts: Dictionary = {}
	if gs == null:
		return counts

	for raw_npc in gs.npcs:
		var npc: Person = raw_npc
		if npc == null or not npc.alive:
			continue
		var realm_id: int = int(npc.realm_id)
		if realm_id <= 0:
			continue
		counts [realm_id] = int(counts.get(realm_id, 0)) + 1

	if typeof(gs.dormant_npcs) == TYPE_DICTIONARY:
		for raw_npc_id in gs.dormant_npcs.keys():
			var snapshot_raw: Variant = gs.dormant_npcs.get(raw_npc_id, {})
			var snapshot: Dictionary = snapshot_raw if typeof(snapshot_raw) == TYPE_DICTIONARY else {}
			if snapshot.is_empty():
				continue
			if not bool(snapshot.get("alive", true)):
				continue
			var realm_id: int = int(snapshot.get("realm_id", -1))
			if realm_id <= 0:
				continue
			counts [realm_id] = int(counts.get(realm_id, 0)) + 1

	if gs.population_shard_engine != null:
		for raw_realm_id in realms.keys():
			var realm_id: int = int(raw_realm_id)
			if realm_id <= 0:
				continue
			counts [realm_id] = int(counts.get(realm_id, 0)) + int(gs.population_shard_engine.get_realm_population(realm_id))

	return counts
func _capture_realm_governance_posture(realm: Dictionary) -> Dictionary:
	if typeof(realm) != TYPE_DICTIONARY or realm.is_empty():
		return {}
	return {
		"name": str(realm.get("name", "Realm")),
		"tax_rate": float(realm.get("tax_rate", 10.0)),
		"treasury_pct": int(realm.get("allocation_treasury_pct", 34)),
		"military_pct": int(realm.get("allocation_military_pct", 33)),
		"goods_pct": int(realm.get("allocation_goods_pct", 33)),
		"treasury": int(realm.get("treasury", 0)),
		"military_stockpile": int(realm.get("military_stockpile", 0)),
		"goods_stockpile": int(realm.get("goods_stockpile", 0)),
		"happiness": int(realm.get("happiness", 50)),
		"pending_tax_happiness_delta": int(realm.get("pending_tax_happiness_delta", 0)),
		"pending_tax_approval_delta": int(realm.get("pending_tax_approval_delta", 0)),
		"pending_tax_respect_delta": int(realm.get("pending_tax_respect_delta", 0)),
		"allocation_policy_year": int(realm.get("allocation_policy_year", -1))
	}


func _resolve_realm_posture_focus_key(posture: Dictionary) -> String:
	var treasury_pct: int = int(posture.get("treasury_pct", 0))
	var military_pct: int = int(posture.get("military_pct", 0))
	var goods_pct: int = int(posture.get("goods_pct", 0))

	if military_pct >= treasury_pct and military_pct >= goods_pct:
		return "military_pct"
	if goods_pct >= treasury_pct and goods_pct >= military_pct:
		return "goods_pct"
	return "treasury_pct"


func _resolve_realm_posture_focus_label(posture: Dictionary) -> String:
	match _resolve_realm_posture_focus_key(posture):
		"military_pct":
			return "military production"
		"goods_pct":
			return "goods production"
		_:
			return "treasury reserves"


func _compact_realm_metric(value: int) -> String:
	var sign_prefix: String = "-" if value < 0 else ""
	var abs_value: float = abs(float(value))

	if abs_value >= 1000000000000.0:
		return "%s%sT" % [sign_prefix, _format_realm_compact_scaled_value(abs_value / 1000000000000.0)]
	if abs_value >= 1000000000.0:
		return "%s%sB" % [sign_prefix, _format_realm_compact_scaled_value(abs_value / 1000000000.0)]
	if abs_value >= 1000000.0:
		return "%s%sM" % [sign_prefix, _format_realm_compact_scaled_value(abs_value / 1000000.0)]
	if abs_value >= 1000.0:
		return "%s%sK" % [sign_prefix, _format_realm_compact_scaled_value(abs_value / 1000.0)]

	return "%s%d" % [sign_prefix, int(abs_value)]
func _format_realm_compact_scaled_value(scaled: float) -> String:
	var label: String = ""
	if scaled < 10.0:
		label = "%0.2f" % scaled
	elif scaled < 100.0:
		label = "%0.1f" % scaled
	else:
		label = "%0.0f" % scaled

	while label.ends_with("0"):
		label = label.substr(0, max(0, label.length() - 1))
	if label.ends_with("."):
		label = label.substr(0, max(0, label.length() - 1))
	return label

func _format_realm_metric_delta(value: int, unit_suffix: String = "") -> String:
	if value == 0:
		return "Stable"
	var sign_prefix: String = "+" if value > 0 else "-"
	var label: String = _compact_realm_metric(abs(value))
	if unit_suffix.strip_edges() != "":
		return "%s%s %s" % [sign_prefix, label, unit_suffix]
	return "%s%s" % [sign_prefix, label]

func _should_emit_ai_realm_posture_shift(before: Dictionary, after: Dictionary) -> bool:
	if before.is_empty() or after.is_empty():
		return false

	var tax_delta: float = abs(float(after.get("tax_rate", 10.0)) - float(before.get("tax_rate", 10.0)))
	var focus_before: String = _resolve_realm_posture_focus_key(before)
	var focus_after: String = _resolve_realm_posture_focus_key(after)

	var treasury_delta: int = int(after.get("treasury", 0)) - int(before.get("treasury", 0))
	var military_delta: int = int(after.get("military_stockpile", 0)) - int(before.get("military_stockpile", 0))
	var goods_delta: int = int(after.get("goods_stockpile", 0)) - int(before.get("goods_stockpile", 0))

	var severe_posture_shift: bool = false
	severe_posture_shift = severe_posture_shift or (focus_before != focus_after)
	severe_posture_shift = severe_posture_shift or (tax_delta >= 4.0)
	severe_posture_shift = severe_posture_shift or (military_delta >= 40)
	severe_posture_shift = severe_posture_shift or (goods_delta >= 2)
	severe_posture_shift = severe_posture_shift or (treasury_delta >= 250000)
	severe_posture_shift = severe_posture_shift or (abs(int(after.get("pending_tax_happiness_delta", 0))) >= 3)
	severe_posture_shift = severe_posture_shift or (abs(int(after.get("pending_tax_approval_delta", 0))) >= 4)

	if not severe_posture_shift:
		return false

	var headline_shift: bool = false
	headline_shift = headline_shift or (focus_before != focus_after)
	headline_shift = headline_shift or (tax_delta >= 6.0)
	headline_shift = headline_shift or (military_delta >= 100)
	headline_shift = headline_shift or (goods_delta >= 4)

	if headline_shift:
		return true

	return randi() % 100 < 35


func _build_ai_realm_posture_shift_text(_realm_id: int, before: Dictionary, after: Dictionary) -> String:
	var realm_name: String = str(after.get("name", before.get("name", "A realm"))).strip_edges()
	if realm_name == "":
		realm_name = "A realm"

	var focus_label: String = _resolve_realm_posture_focus_label(after)
	var tax_rate: int = int(round(float(after.get("tax_rate", 10.0))))
	var treasury_pct: int = int(after.get("treasury_pct", 34))
	var military_pct: int = int(after.get("military_pct", 33))
	var goods_pct: int = int(after.get("goods_pct", 33))

	var military_delta: int = int(after.get("military_stockpile", 0)) - int(before.get("military_stockpile", 0))
	var goods_delta: int = int(after.get("goods_stockpile", 0)) - int(before.get("goods_stockpile", 0))
	var treasury_delta: int = int(after.get("treasury", 0)) - int(before.get("treasury", 0))

	var lines: Array = []
	lines.append("🏛 %s shifted toward %s, setting taxes at %d%%." % [
		realm_name,
		focus_label,
		tax_rate
	])
	lines.append("State split: %d%% treasury • %d%% military • %d%% goods." % [
		treasury_pct,
		military_pct,
		goods_pct
	])

	if treasury_delta > 0:
		lines.append("Treasury grew by %s." % _compact_realm_metric(treasury_delta))
	if military_delta > 0:
		lines.append("Military stockpile grew by %s units." % _compact_realm_metric(military_delta))
	if goods_delta > 0:
		lines.append("Goods stockpile grew by %s units." % _compact_realm_metric(goods_delta))

	var mood_bits: Array = []
	var happiness_delta: int = int(after.get("pending_tax_happiness_delta", 0))
	var approval_delta: int = int(after.get("pending_tax_approval_delta", 0))
	var respect_delta: int = int(after.get("pending_tax_respect_delta", 0))

	if happiness_delta != 0:
		mood_bits.append("Happiness %s%d next year" % [
			"+" if happiness_delta >= 0 else "",
			happiness_delta
		])
	if approval_delta != 0:
		mood_bits.append("Approval %s%d next year" % [
			"+" if approval_delta >= 0 else "",
			approval_delta
		])
	if respect_delta != 0:
		mood_bits.append("Respect %s%d next year" % [
			"+" if respect_delta >= 0 else "",
			respect_delta
		])

	if not mood_bits.is_empty():
		lines.append("%s." % " • ".join(mood_bits))

	return "\n".join(lines)


func _maybe_emit_ai_realm_allocation_posture_shift(realm_id: int, before: Dictionary, after: Dictionary) -> void:
	if gs == null:
		return
	if before.is_empty() or after.is_empty():
		return
	if not _should_emit_ai_realm_posture_shift(before, after):
		return

	var text: String = _build_ai_realm_posture_shift_text(realm_id, before, after)
	if text.strip_edges() == "":
		return

	gs.push_world_feed(
		text,
		{
			"npc_id": int(after.get("ruler_id", -1)),
			"personally_relevant": false,
			"category": "realm",
			"event_name": "realm_ai_posture_shift",
			"source": "realm_engine"
		}
	)

func get_resident_realm_war_snapshot(
		realm_id: int
) -> Dictionary:














		if (
			gs == null
			or realm_id <= 0
			or not realms.has(
				realm_id
			)
		):
			return {}

		var realm_raw: Variant = realms.get(
			realm_id,
			{}
		)
		var realm: Dictionary = (
			(realm_raw as Dictionary).duplicate(false)
			if typeof(realm_raw) == TYPE_DICTIONARY
			else {}
		)

		if realm.is_empty():
			return {}

		var realm_name: String = str(
			realm.get(
				"name",
				"Realm"
			)
		).strip_edges()

		var population: int = maxi(
			maxi(
				0,
				int(
					realm.get(
						"population",
						0
					)
				)
			),
			int(
				realm.get(
					"population_floor",
					0
				)
			)
		)
		var previous_population: int = int(
			realm.get(
				"population_previous_year",
				population
			)
		)
		var population_change: int = int(
			realm.get(
				"population_change_last_year",
				population - previous_population
			)
		)
		var births_last_year: int = int(
			realm.get(
				"population_births_last_year",
				0
			)
		)
		var deaths_last_year: int = int(
			realm.get(
				"population_deaths_last_year",
				0
			)
		)
		var migration_last_year: int = int(
			realm.get(
				"population_migration_last_year",
				0
			)
		)
		var land: int = int(
			realm.get(
				"land",
				realm.get(
					"land_size",
					0
				)
			)
		)
		var treasury: int = int(
			realm.get(
				"treasury",
				0
			)
		)
		var military_stockpile: int = int(
			realm.get(
				"military_stockpile",
				realm.get(
					"military",
					0
				)
			)
		)
		var goods_stockpile: int = int(
			realm.get(
				"goods_stockpile",
				0
			)
		)
		var government_style: String = str(
			realm.get(
				"government_style",
				"State"
			)
		).strip_edges()
		var currency_name: String = str(
			realm.get(
				"currency_name",
				"Treasury"
			)
		).strip_edges()

		if currency_name == "":
			currency_name = "Treasury"

		var native_element: String = str(
			realm.get(
				"native_element",
				realm.get(
					"element",
					realm.get(
						"bending_element",
						""
					)
				)
			)
		).strip_edges().to_lower()

		if (
			native_element == ""
			or native_element == "none"
		):
			native_element = str(
				_realm_element_for_name(
					realm_name
				)
			).strip_edges().to_lower()

		var elemental_realm: bool = (
			native_element in [
				"air",
				"water",
				"earth",
				"fire"
			]
		)
		var ruler_id: int = int(
			realm.get(
				"ruler_id",
				realm.get(
					"leader_id",
					-1
				)
			)
		)
		var leader_mastery: int = 0

		if (
			elemental_realm
			and ruler_id > 0
		):
			var ruler: Person = null

			if (
				gs.player != null
				and int(
					gs.player.id
				) == ruler_id
			):
				ruler = gs.player
			else:
				ruler = gs.get_npc_by_id(
					ruler_id
				)

			if ruler != null:
				var mastery_raw: Variant = (
					ruler.bending_mastery
				)

				if typeof(
					mastery_raw
				) == TYPE_DICTIONARY:
					leader_mastery = int(
						(
							mastery_raw as Dictionary
						).get(
							native_element,
							0
						)
					)

			if (
				leader_mastery <= 0
				and typeof(
					gs.dormant_npcs
				) == TYPE_DICTIONARY
				and gs.dormant_npcs.has(
					ruler_id
				)
			):
				var dormant_raw: Variant = (
					gs.dormant_npcs.get(
						ruler_id,
						{}
					)
				)

				if typeof(
					dormant_raw
				) == TYPE_DICTIONARY:
					var dormant: Dictionary = (
						dormant_raw as Dictionary
					)
					var dormant_mastery_raw: Variant = (
						dormant.get(
							"bending_mastery",
							{}
						)
					)

					if typeof(
						dormant_mastery_raw
					) == TYPE_DICTIONARY:
						leader_mastery = int(
							(
								dormant_mastery_raw
								as Dictionary
							).get(
								native_element,
								0
							)
						)

		var effective_elemental_mastery: int = (
			maxi(
				leader_mastery,
				85
			)
			if elemental_realm
			else 0
		)
		var elemental_war_capability: Dictionary = {
			"schema": (
				"eralife.realm_engine."
				+ "elemental_war_capability_contract"
			),
			"version": 1,
			"enabled": elemental_realm,
			"realm_id": realm_id,
			"element": (
				native_element
				if elemental_realm
				else ""
			),
			"ruler_id": ruler_id,
			"leader_mastery": leader_mastery,
			"effective_mastery": (
				effective_elemental_mastery
			),
			"automatic_defensive_response": (
				elemental_realm
			),
			"ordinary_realm_asymmetry_applies": (
				elemental_realm
			),
			"military_targeting": elemental_realm,
			"population_targeting": elemental_realm,
			"infrastructure_targeting": elemental_realm,
			"mass_scale_bending_authorized": (
				elemental_realm
			),
			"ui_is_renderer_only": true
		}

		var treasury_label: String = (
			"%s %s"
			% [
				currency_name,
				_compact_realm_metric(
					treasury
				)
			]
		)
		var military_label: String = (
			"0, but everyone if provoked"
			if (
				native_element == "air"
				and military_stockpile <= 0
			)
			else (
				"%s units"
				% _compact_realm_metric(
					military_stockpile
				)
			)
		)
		var goods_label: String = (
			"%s units"
			% _compact_realm_metric(
				goods_stockpile
			)
		)
		var land_label: String = (
			"%s km²"
			% _compact_realm_metric(
				land
			)
		)
		var population_label: String = (
			"%s people"
			% _compact_realm_metric(
				population
			)
		)
		var population_trend_label: String = "Stable"

		if population_change > 0:
			population_trend_label = "Growing"
		elif population_change < 0:
			population_trend_label = "Declining"

		var population_change_label: String = (
			_format_realm_metric_delta(
				population_change,
				"people"
			)
		)
		var military_strength_score: float = (
			(float(military_stockpile) * 1.4)
			+ (float(population) * 0.08)
			+ (float(land) * 0.12)
		)
		var economic_strength_score: float = (
			(float(treasury) / 10000.0)
			+ (float(goods_stockpile) * 9.0)
			+ (float(population) * 0.03)
		)

		return {
			"realm_id": realm_id,
			"realm_key": str(
				realm.get(
					"realm_key",
					realm.get(
						"id",
						realm_id
					)
				)
			),
			"name": realm_name,
			"population": population,
			"population_label": population_label,
			"population_change": population_change,
			"population_change_label": (
				population_change_label
			),
			"population_change_pct_last_year": float(
				realm.get(
					"population_change_pct_last_year",
					0.0
				)
			),
			"population_trend_label": (
				population_trend_label
			),
			"births_last_year": births_last_year,
			"deaths_last_year": deaths_last_year,
			"migration_last_year": migration_last_year,
			"land": land,
			"land_label": land_label,
			"land_descriptor": str(
				realm.get(
					"land_label",
					"Territory"
				)
			).strip_edges(),
			"treasury": treasury,
			"treasury_label": treasury_label,
			"military_stockpile": military_stockpile,
			"military_label": military_label,
			"military_floor": int(
				realm.get(
					"military_floor",
					0
				)
			),
			"goods_stockpile": goods_stockpile,
			"goods_label": goods_label,
			"goods_floor": int(
				realm.get(
					"goods_floor",
					0
				)
			),
			"government_style": government_style,
			"native_element": (
				native_element
				if elemental_realm
				else ""
			),
			"is_elemental_realm": elemental_realm,
			"elemental_war_capability": (
				elemental_war_capability
			),
			"military_strength_score": (
				military_strength_score
			),
			"economic_strength_score": (
				economic_strength_score
			),
			"snapshot_source": (
				"resident_realm_truth"
			),
			"population_scan_performed": false,
			"simulation_mutation_performed": false,
			"ui_is_renderer_only": true
		}
func _realm_identity_key(
	realm_name: String
) -> String:
	return (
		realm_name
		.strip_edges()
		.to_lower()
		.replace(
			".",
			""
		)
		.replace(
			"-",
			""
		)
		.replace(
			"_",
			""
		)
		.replace(
			" ",
			""
		)
	)


func _realm_titan_identity(
	realm_name: String
) -> String:
	var key: String = _realm_identity_key(
		realm_name
	)

	if key in [
		"usa",
		"us",
		"america",
		"unitedstates",
		"unitedstatesofamerica"
	]:
		return "united_states"

	if key in [
		"india",
		"britishindia",
		"mauryaempire",
		"indusvalley",
		"delhisultanate",
		"indianoceanconfederacy"
	]:
		return "india"

	if key in [
		"china",
		"hanchina",
		"qingchina",
		"orbitalchina",
		"easternnexus"
	]:
		return "china"

	if key in [
		"russia",
		"russianempire",
		"sovietunion",
		"kievanrus"
	]:
		return "russia"

	return ""


func _canonical_realm_display_name(
	realm_name: String,
	era_name: String
) -> String:
	var clean_name: String = (
		realm_name.strip_edges()
	)
	var identity: String = _realm_titan_identity(
		clean_name
	)

	if (
		era_name == "Industrial Era"
		and identity == "russia"
	):
		return "Soviet Union"

	if identity == "united_states":
		return "United States"

	if (
		era_name == "Future Era"
		and identity == "china"
	):
		return "Orbital China"

	return clean_name


func _realm_titan_profile(
	realm_name: String,
	era_name: String
) -> Dictionary:
	var identity: String = _realm_titan_identity(
		realm_name
	)
	if identity == "":
		return {
			"active": false,
			"identity": ""
		}

	var population_min: int = 0
	var population_max: int = 0
	var military_min_ratio: float = 0.18
	var military_max_ratio: float = 0.3
	var goods_min_ratio: float = 0.14
	var goods_max_ratio: float = 0.32

	match identity:
		"united_states":
			match era_name:
				"Industrial Era":
					population_min = 120000000
					population_max = 280000000

				"Modern Era":
					population_min = 420000000
					population_max = 780000000

				"Future Era":
					population_min = 1200000000
					population_max = 3200000000

			military_min_ratio = 0.22
			military_max_ratio = 0.38
			goods_min_ratio = 0.34
			goods_max_ratio = 0.62

		"india":
			match era_name:
				"Ancient Era":
					population_min = 35000000
					population_max = 95000000
				"Medieval Era":
					population_min = 65000000
					population_max = 170000000
				"Industrial Era":
					population_min = 260000000
					population_max = 600000000
				"Modern Era":
					population_min = 900000000
					population_max = 1900000000
				"Future Era":
					population_min = 2000000000
					population_max = 5500000000
			military_min_ratio = 0.17
			military_max_ratio = 0.3
			goods_min_ratio = 0.16
			goods_max_ratio = 0.38

		"china":
			match era_name:
				"Ancient Era":
					population_min = 45000000
					population_max = 110000000
				"Medieval Era":
					population_min = 70000000
					population_max = 180000000
				"Industrial Era":
					population_min = 300000000
					population_max = 650000000
				"Modern Era":
					population_min = 950000000
					population_max = 1800000000
				"Future Era":
					population_min = 2200000000
					population_max = 5800000000
			military_min_ratio = 0.18
			military_max_ratio = 0.32
			goods_min_ratio = 0.17
			goods_max_ratio = 0.4

		"russia":
			match era_name:
				"Medieval Era":
					population_min = 22000000
					population_max = 80000000
				"Industrial Era":
					population_min = 150000000
					population_max = 340000000
				"Modern Era":
					population_min = 120000000
					population_max = 320000000
				"Future Era":
					population_min = 450000000
					population_max = 1600000000
			military_min_ratio = 0.21
			military_max_ratio = 0.36
			goods_min_ratio = 0.15
			goods_max_ratio = 0.34

	return {
		"active": population_min > 0,
		"identity": identity,
		"display_name": (
			_canonical_realm_display_name(
				realm_name,
				era_name
			)
		),
		"population_min": population_min,
		"population_max": maxi(
			population_min,
			population_max
		),
		"military_min_ratio": military_min_ratio,
		"military_max_ratio": military_max_ratio,
		"goods_min_ratio": goods_min_ratio,
		"goods_max_ratio": goods_max_ratio,
	}
func get_realm_power_snapshot(realm_id: int) -> Dictionary:
	if gs == null:
		return {}
	if realm_id <= 0:
		return {}
	if not realms.has(realm_id):
		return {}

	var realm_raw: Variant = realms.get(
		realm_id,
		{}
	)
	var realm: Dictionary = (
		realm_raw
		if typeof(realm_raw) == TYPE_DICTIONARY
		else {}
	)

	if realm.is_empty():
		return {}

	var guard_store: Dictionary = {}
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var guard_raw: Variant = (
		gs.scenario_state.get(
			"realm_power_snapshot_guard",
			{}
		)
	)
	guard_store = (
		guard_raw
		if typeof(guard_raw) == TYPE_DICTIONARY
		else {}
	)
	var guard_key: String = str(
		realm_id
	)
	var already_building: bool = bool(
		guard_store.get(
			guard_key,
			false
		)
	)

	if (
		has_method(
			"ensure_realm_defaults"
		)
		and not already_building
	):
		guard_store [
			guard_key
		] = true
		gs.scenario_state [
			"realm_power_snapshot_guard"
		] = guard_store

		var hydrated: Dictionary = (
			ensure_realm_defaults(
				realm_id
			)
		)

		guard_raw = (
			gs.scenario_state.get(
				"realm_power_snapshot_guard",
				{}
			)
		)
		guard_store = (
			guard_raw
			if typeof(guard_raw) == TYPE_DICTIONARY
			else {}
		)
		guard_store.erase(
			guard_key
		)
		gs.scenario_state [
			"realm_power_snapshot_guard"
		] = guard_store

		if not hydrated.is_empty():
			realm = hydrated

	var realm_name: String = str(
		realm.get(
			"name",
			"Realm"
		)
	).strip_edges()
	var population: int = max(
		int(
			realm.get(
				"population",
				0
			)
		),
		get_total_population_for_realm(
			realm_id
		)
	)
	var previous_population: int = int(
		realm.get(
			"population_previous_year",
			population
		)
	)
	var population_change: int = int(
		realm.get(
			"population_change_last_year",
			population - previous_population
		)
	)
	var births_last_year: int = int(
		realm.get(
			"population_births_last_year",
			0
		)
	)
	var deaths_last_year: int = int(
		realm.get(
			"population_deaths_last_year",
			0
		)
	)
	var migration_last_year: int = int(
		realm.get(
			"population_migration_last_year",
			0
		)
	)

	var land: int = int(
		realm.get(
			"land",
			realm.get(
				"land_size",
				0
			)
		)
	)
	var treasury: int = int(
		realm.get(
			"treasury",
			0
		)
	)
	var military_stockpile: int = int(
		realm.get(
			"military_stockpile",
			0
		)
	)
	var goods_stockpile: int = int(
		realm.get(
			"goods_stockpile",
			0
		)
	)
	var government_style: String = str(
		realm.get(
			"government_style",
			"State"
		)
	).strip_edges()
	var currency_name: String = str(
		realm.get(
			"currency_name",
			""
		)
	).strip_edges()

	var native_element: String = str(
		realm.get(
			"native_element",
			realm.get(
				"element",
				realm.get(
					"bending_element",
					""
				)
			)
		)
	).strip_edges().to_lower()

	if (
		native_element == ""
		or native_element == "none"
	):
		native_element = str(
			_realm_element_for_name(
				realm_name
			)
		).strip_edges().to_lower()

	var elemental_realm: bool = (
		native_element in [
			"air",
			"water",
			"earth",
			"fire"
		]
	)

	var ruler_id: int = int(
		realm.get(
			"ruler_id",
			realm.get(
				"leader_id",
				-1
			)
		)
	)
	var ruler: Person = null

	if (
		gs.player != null
		and int(
			gs.player.id
		) == ruler_id
	):
		ruler = gs.player
	elif ruler_id > 0:
		ruler = gs.get_npc_by_id(
			ruler_id
		)

	var leader_mastery: int = 0

	if (
		elemental_realm
		and ruler != null
		and gs.bending_engine != null
		and gs.bending_engine.has_method(
			"get_bending_level"
		)
	):
		leader_mastery = int(
			gs.bending_engine.get_bending_level(
				ruler,
				native_element
			)
		)

	if (
		elemental_realm
		and leader_mastery <= 0
		and ruler_id > 0
		and typeof(
			gs.dormant_npcs
		) == TYPE_DICTIONARY
		and gs.dormant_npcs.has(
			ruler_id
		)
	):
		var dormant_raw: Variant = (
			gs.dormant_npcs.get(
				ruler_id,
				{}
			)
		)

		if typeof(
			dormant_raw
		) == TYPE_DICTIONARY:
			var dormant: Dictionary = (
				dormant_raw as Dictionary
			)
			var mastery_raw: Variant = (
				dormant.get(
					"bending_mastery",
					{}
				)
			)

			if typeof(
				mastery_raw
			) == TYPE_DICTIONARY:
				leader_mastery = int(
					(mastery_raw as Dictionary).get(
						native_element,
						0
					)
				)

	var effective_elemental_mastery: int = (
		maxi(
			leader_mastery,
			85
		)
		if elemental_realm
		else 0
	)
	var elemental_war_capability: Dictionary = {
		"schema": (
			"eralife.realm_engine."
			+ "elemental_war_capability_contract"
		),
		"version": 1,
		"enabled": elemental_realm,
		"realm_id": realm_id,
		"element": (
			native_element
			if elemental_realm
			else ""
		),
		"ruler_id": ruler_id,
		"leader_mastery": leader_mastery,
		"effective_mastery": effective_elemental_mastery,
		"automatic_defensive_response": elemental_realm,
		"ordinary_realm_asymmetry_applies": elemental_realm,
		"military_targeting": elemental_realm,
		"population_targeting": elemental_realm,
		"infrastructure_targeting": elemental_realm,
		"mass_scale_bending_authorized": elemental_realm,
		"ui_is_renderer_only": true
	}

	if (
		currency_name == ""
		and gs.economy_engine != null
	):
		var currency: Variant = (
			gs.economy_engine.get_currency()
		)

		if typeof(currency) == TYPE_DICTIONARY:
			currency_name = str(
				currency.get(
					"name",
					"Treasury"
				)
			).strip_edges()

	if currency_name == "":
		currency_name = "Treasury"

	var treasury_label: String = (
		"%s %s"
		% [
			currency_name,
			_compact_realm_metric(
				treasury
			)
		]
	)
	var military_label: String = (
		"0, but everyone if provoked"
		if (
			native_element == "air"
			and military_stockpile <= 0
		)
		else (
			"%s units"
			% _compact_realm_metric(
				military_stockpile
			)
		)
	)
	var goods_label: String = (
		"%s units"
		% _compact_realm_metric(
			goods_stockpile
		)
	)
	var land_label: String = (
		"%s km²"
		% _compact_realm_metric(
			land
		)
	)
	var population_label: String = (
		"%s people"
		% _compact_realm_metric(
			population
		)
	)

	var population_trend_label: String = "Stable"

	if population_change > 0:
		population_trend_label = "Growing"
	elif population_change < 0:
		population_trend_label = "Declining"

	var population_change_label: String = (
		_format_realm_metric_delta(
			population_change,
			"people"
		)
	)
	var military_strength_score: float = (
		(float(military_stockpile) * 1.4)
		+ (float(population) * 0.08)
		+ (float(land) * 0.12)
	)
	var economic_strength_score: float = (
		(float(treasury) / 10000.0)
		+ (float(goods_stockpile) * 9.0)
		+ (float(population) * 0.03)
	)

	return {
		"realm_id": realm_id,
		"name": realm_name,
		"population": population,
		"population_label": population_label,
		"population_change": population_change,
		"population_change_label": population_change_label,
		"population_change_pct_last_year": float(
			realm.get(
				"population_change_pct_last_year",
				0.0
			)
		),
		"population_trend_label": population_trend_label,
		"births_last_year": births_last_year,
		"deaths_last_year": deaths_last_year,
		"migration_last_year": migration_last_year,
		"land": land,
		"land_label": land_label,
		"land_descriptor": str(
			realm.get(
				"land_label",
				"Territory"
			)
		).strip_edges(),
		"treasury": treasury,
		"treasury_label": treasury_label,
		"military_stockpile": military_stockpile,
		"military_label": military_label,
		"military_floor": int(
			realm.get(
				"military_floor",
				0
			)
		),
		"goods_stockpile": goods_stockpile,
		"goods_label": goods_label,
		"goods_floor": int(
			realm.get(
				"goods_floor",
				0
			)
		),
		"government_style": government_style,
		"native_element": (
			native_element
			if elemental_realm
			else ""
		),
		"is_elemental_realm": elemental_realm,
		"elemental_war_capability": (
			elemental_war_capability
		),
		"military_strength_score": military_strength_score,
		"economic_strength_score": economic_strength_score
	}

func _describe_realm_advantage(attacker_value: float, defender_value: float, category_label: String) -> String:
	if attacker_value <= 0.0 and defender_value <= 0.0:
		return "%s is unclear." % category_label

	if attacker_value >= defender_value * 1.25:
		return "You hold the %s edge." % category_label
	if defender_value >= attacker_value * 1.25:
		return "They hold the %s edge." % category_label
	return "%s looks roughly even." % category_label


func get_realm_conflict_preview(
	attacker_realm_id: int,
	defender_realm_id: int
) -> Dictionary:
	if (
		gs == null
		or gs.war_contract_engine == null
	):
		return {}

	var preview: Dictionary = (
		gs.war_contract_engine
		.emit_war_preview_contract(
			{
				"attacker_realm_id": (
					attacker_realm_id
				),
				"defender_realm_id": (
					defender_realm_id
				),
				"year": int(
					gs.year
				),
				"era_key": (
					str(
						gs.era.name
					)
					if gs.era != null
					else ""
				),
				"source": (
					"realm_engine.conflict_preview_facade"
				)
			}
		)
	)

	if not bool(
		preview.get(
			"success",
			false
		)
	):
		return {}

	var attacker_raw: Variant = preview.get(
		"attacker",
		{}
	)
	var attacker: Dictionary = (
		(attacker_raw as Dictionary).duplicate(false)
		if typeof(attacker_raw) == TYPE_DICTIONARY
		else {}
	)

	var defender_raw: Variant = preview.get(
		"defender",
		{}
	)
	var defender: Dictionary = (
		(defender_raw as Dictionary).duplicate(false)
		if typeof(defender_raw) == TYPE_DICTIONARY
		else {}
	)

	var lines: Array = [
		"Scout this before you commit.",
		"Your Realm: %s" % str(
			attacker.get(
				"name",
				"Your Realm"
			)
		),
		"Target Realm: %s" % str(
			defender.get(
				"name",
				"Target Realm"
			)
		),
		"Projected winner: %s"
		% str(
			preview.get(
				"projected_winner_name",
				"Unknown"
			)
		),
		"Projected duration: %d years"
		% int(
			preview.get(
				"projected_duration_years",
				1
			)
		),
		"This declaration is owned by WarContractEngine."
	]

	return {
		"attacker": attacker,
		"defender": defender,
		"summary_text": (
			"\n".join(
				lines
			) + "\n"
		),
		"war_preview_contract": preview,
		"source_of_truth": "WarContractEngine"
	}

func _apply_realm_pending_tax_effects(
		realm_id: int,
		realm: Dictionary
) -> Dictionary:
		if gs == null:
			return realm

		if realm.is_empty():
			return realm



		var out: Dictionary = (
			_apply_annual_realm_financial_pressure(
				realm_id,
				realm
			)
		)

		var pending_year: int = int(
			out.get(
				"pending_tax_effect_year",
				-1
			)
		)

		if (
			pending_year <= 0
			or int(gs.year) < pending_year
		):
			return out

		if int(
			out.get(
				"tax_effect_applied_year",
				-1
			)
		) == int(gs.year):
			return out

		var approval_delta: int = int(
			out.get(
				"pending_tax_approval_delta",
				0
			)
		)
		var happiness_delta: int = int(
			out.get(
				"pending_tax_happiness_delta",
				0
			)
		)
		var respect_delta: int = int(
			out.get(
				"pending_tax_respect_delta",
				0
			)
		)
		var ruler_id: int = int(
			out.get(
				"ruler_id",
				-1
			)
		)
		var ruler: Person = null

		if (
			gs.player != null
			and int(gs.player.id) == ruler_id
		):
			ruler = gs.player
		elif ruler_id > 0:
			ruler = gs.get_npc_by_id(
				ruler_id
			)

		if (
			ruler != null
			and ruler.alive
		):
			ruler.approval = clamp(
				int(ruler.approval)
				+ approval_delta,
				0,
				100
			)

		out ["happiness"] = clamp(
			int(out.get("happiness", 50))
			+ happiness_delta,
			0,
			100
		)
		out ["respect_bias"] = clamp(
			int(out.get("respect_bias", 0))
			+ respect_delta,
			-100,
			100
		)
		out ["tax_effect_applied_year"] = int(
			gs.year
		)

		return out

func _calculate_realm_tax_revenue(population: int, tax_rate: float, realm: Dictionary = {}) -> int:
	if population <= 0 or tax_rate <= 0.0:
		return 0
	var quality: float = float(realm.get("quality", realm.get("country_quality", 50.0)))
	var prosperity: float = float(realm.get("prosperity", realm.get("realm_quality", 0.0)))
	var land: float = float(realm.get("land", realm.get("land_size", 0.0)))
	var taxable_income_per_citizen: float = max(24.0, 120.0 + (quality * 6.0) + (prosperity * 2.5) + min(80.0, land * 0.04))
	return max(0, int(round(float(population) * taxable_income_per_citizen * (tax_rate / 100.0))))


func _sanitize_ai_realm_allocation_plan(plan: Dictionary) -> Dictionary:
	var out: Dictionary = {
		"tax_rate": clamp(float(plan.get("tax_rate", 10.0)), 0.0, 40.0),
		"treasury_pct": clamp(int(plan.get("treasury_pct", 34)), 0, 100),
		"military_pct": clamp(int(plan.get("military_pct", 33)), 0, 100),
		"goods_pct": clamp(int(plan.get("goods_pct", 33)), 0, 100)
	}

	var total_pct: int = int(out.get("treasury_pct", 0)) + int(out.get("military_pct", 0)) + int(out.get("goods_pct", 0))
	if total_pct <= 0:
		out ["treasury_pct"] = 34
		out ["military_pct"] = 33
		out ["goods_pct"] = 33
		return out

	if total_pct != 100:
		var pct_scale: float = 100.0 / float(total_pct)
		var treasury_pct: int = clamp(int(round(float(out.get("treasury_pct", 0)) * pct_scale)), 0, 100)
		var military_pct: int = clamp(int(round(float(out.get("military_pct", 0)) * pct_scale)), 0, 100)
		var goods_pct: int = clamp(int(round(float(out.get("goods_pct", 0)) * pct_scale)), 0, 100)
		var fixed_total: int = treasury_pct + military_pct + goods_pct
		if fixed_total != 100:
			goods_pct += 100 - fixed_total
		if goods_pct < 0:
			goods_pct = 0
		out ["treasury_pct"] = treasury_pct
		out ["military_pct"] = military_pct
		out ["goods_pct"] = goods_pct

	return out


func _get_realm_ruler_pressure_hint(ruler_id: int) -> Dictionary:
	var out: Dictionary = {
		"coup_pressure": 0.0,
		"royal_succession_tension": 0.0
	}
	if gs == null or ruler_id <= 0:
		return out
	if typeof(gs.transient_scenario_biases) != TYPE_DICTIONARY:
		return out

	var bias_raw: Variant = gs.transient_scenario_biases.get(ruler_id, {})
	var bias: Dictionary = {}

	if typeof(bias_raw) == TYPE_ARRAY:
		var bias_bucket: Array = bias_raw
		if not bias_bucket.is_empty() and typeof(bias_bucket [0]) == TYPE_DICTIONARY:
			bias = bias_bucket [0]
	elif typeof(bias_raw) == TYPE_DICTIONARY:
		bias = bias_raw

	var faction_pressure_raw: Variant = bias.get("faction_pressure", {})
	var faction_pressure: Dictionary = faction_pressure_raw if typeof(faction_pressure_raw) == TYPE_DICTIONARY else {}

	out ["coup_pressure"] = float(faction_pressure.get("coup_pressure", 0.0))
	out ["royal_succession_tension"] = float(faction_pressure.get("royal_succession_tension", 0.0))
	return out

func _get_ai_realm_government_allocation_bias(realm: Dictionary) -> Dictionary:
	var government_style: String = str(realm.get("government_style", "State")).strip_edges().to_lower()
	match government_style:
		"monarchy":
			return {
				"tax_rate": 11.0,
				"treasury_pct": 42,
				"military_pct": 36,
				"goods_pct": 22
			}
		"empire":
			return {
				"tax_rate": 13.0,
				"treasury_pct": 30,
				"military_pct": 52,
				"goods_pct": 18
			}
		"dictatorship":
			return {
				"tax_rate": 14.0,
				"treasury_pct": 24,
				"military_pct": 58,
				"goods_pct": 18
			}
		"autocracy":
			return {
				"tax_rate": 13.0,
				"treasury_pct": 28,
				"military_pct": 50,
				"goods_pct": 22
			}
		"republic":
			return {
				"tax_rate": 9.0,
				"treasury_pct": 30,
				"military_pct": 24,
				"goods_pct": 46
			}
		"democracy":
			return {
				"tax_rate": 8.0,
				"treasury_pct": 28,
				"military_pct": 20,
				"goods_pct": 52
			}
		"theocracy":
			return {
				"tax_rate": 10.0,
				"treasury_pct": 36,
				"military_pct": 28,
				"goods_pct": 36
			}
		"tribal":
			return {
				"tax_rate": 7.0,
				"treasury_pct": 24,
				"military_pct": 34,
				"goods_pct": 42
			}
		"confederation":
			return {
				"tax_rate": 8.0,
				"treasury_pct": 26,
				"military_pct": 30,
				"goods_pct": 44
			}
		_:
			return {
				"tax_rate": 10.0,
				"treasury_pct": 34,
				"military_pct": 33,
				"goods_pct": 33
			}
func _estimate_ai_realm_corruption(realm: Dictionary, ruler) -> float:
	var corruption: float = clamp(float(realm.get("corruption", -1.0)), -1.0, 100.0)
	if corruption >= 0.0:
		return corruption
	var scandal: float = 0.0
	var approval_inverse: float = 0.0
	if ruler != null:
		if "scandal" in ruler:
			scandal = clamp(float(ruler.scandal), 0.0, 100.0)
		approval_inverse = 100.0 - clamp(float(ruler.approval), 0.0, 100.0)
	var black_budget_pressure: float = clamp(float(realm.get("black_budget_pressure", 0.0)), 0.0, 100.0)
	return clamp((scandal * 0.55) + (approval_inverse * 0.25) + (black_budget_pressure * 0.2), 0.0, 100.0)
func _get_ai_realm_variance_seed(realm_id: int, realm: Dictionary) -> int:
	var realm_name: String = str(realm.get("name", realm_id))
	var government_style: String = str(realm.get("government_style", "state"))
	return abs(int(hash("%s|%s|%s|%d" % [realm_id, realm_name, government_style, int(gs.year)])))
func _apply_ai_realm_governance_variance(realm_id: int, realm: Dictionary, ruler, plan: Dictionary) -> Dictionary:
	var out: Dictionary = plan.duplicate(true)
	var corruption: float = _estimate_ai_realm_corruption(realm, ruler)
	var government_style: String = str(realm.get("government_style", "State")).strip_edges().to_lower()
	var variance_seed: int = _get_ai_realm_variance_seed(realm_id, realm)
	var treasury_swing: int = int((variance_seed % 9) - 4)
	var military_swing: int = int((floori(float(variance_seed) / 9.0) % 11) - 5)
	var goods_swing: int = int((floori(float(variance_seed) / 99.0) % 11) - 5)
	out ["treasury_pct"] = int(out.get("treasury_pct", 34)) + treasury_swing
	out ["military_pct"] = int(out.get("military_pct", 33)) + military_swing
	out ["goods_pct"] = int(out.get("goods_pct", 33)) + goods_swing
	if corruption >= 70.0:
		out ["tax_rate"] = float(out.get("tax_rate", 10.0)) + 2.0
		out ["goods_pct"] = int(out.get("goods_pct", 33)) - 12
		if government_style in ["dictatorship", "autocracy", "empire", "monarchy"]:
			out ["military_pct"] = int(out.get("military_pct", 33)) + 8
			out ["treasury_pct"] = int(out.get("treasury_pct", 34)) + 4
		else:
			out ["treasury_pct"] = int(out.get("treasury_pct", 34)) + 10
	elif corruption >= 45.0:
		out ["goods_pct"] = int(out.get("goods_pct", 33)) - 6
		out ["treasury_pct"] = int(out.get("treasury_pct", 34)) + 4
		if government_style in ["dictatorship", "autocracy", "empire"]:
			out ["military_pct"] = int(out.get("military_pct", 33)) + 3
	elif corruption <= 15.0:
		out ["goods_pct"] = int(out.get("goods_pct", 33)) + 6
		out ["tax_rate"] = float(out.get("tax_rate", 10.0)) - 1.0
		if government_style in ["democracy", "republic", "confederation"]:
			out ["goods_pct"] = int(out.get("goods_pct", 33)) + 4
			out ["military_pct"] = int(out.get("military_pct", 33)) - 2
	return _sanitize_ai_realm_allocation_plan(out)
func _build_ai_realm_allocation_plan(realm_id: int, realm: Dictionary, ruler, population: int) -> Dictionary:
	var base_bias: Dictionary = _get_ai_realm_government_allocation_bias(realm)
	var tax_rate: float = clamp(float(realm.get("tax_rate", base_bias.get("tax_rate", 10.0))), 0.0, 40.0)
	var treasury_pct: int = clamp(int(realm.get("allocation_treasury_pct", base_bias.get("treasury_pct", 34))), 0, 100)
	var military_pct: int = clamp(int(realm.get("allocation_military_pct", base_bias.get("military_pct", 33))), 0, 100)
	var goods_pct: int = clamp(int(realm.get("allocation_goods_pct", base_bias.get("goods_pct", 33))), 0, 100)
	var approval: int = clamp(int(ruler.approval), 0, 100) if ruler != null else 50
	var happiness: int = clamp(int(realm.get("happiness", 50)), 0, 100)
	var treasury: int = int(realm.get("treasury", 0))
	var military_stockpile: int = int(realm.get("military_stockpile", 0))
	var goods_stockpile: int = int(realm.get("goods_stockpile", 0))
	var reserve: int = int(realm.get("allocation_reserve", 0))
	var pressure: Dictionary = _get_realm_ruler_pressure_hint(int(realm.get("ruler_id", -1)))
	var coup_pressure: float = float(pressure.get("coup_pressure", 0.0))
	var succession_tension: float = float(pressure.get("royal_succession_tension", 0.0))
	var expected_revenue: int = _calculate_realm_tax_revenue(population, tax_rate, realm)
	var liquidity: int = treasury + reserve + expected_revenue

	if approval <= 35 or happiness <= 35:
		tax_rate -= 2.0
		goods_pct += 8
		treasury_pct -= 4
		military_pct -= 4
	if coup_pressure >= 12.0 or succession_tension >= 10.0:
		military_pct += 12
		treasury_pct -= 6
		goods_pct -= 6
	if liquidity <= max(250000, population * 4):
		treasury_pct += 10
		military_pct -= 5
		goods_pct -= 5
	if military_stockpile <= int(round(float(max(1, population)) * 0.02)):
		military_pct += 8
		treasury_pct -= 4
		goods_pct -= 4
	if goods_stockpile <= int(round(float(max(1, population)) * 0.01)):
		goods_pct += 8
		treasury_pct -= 4
		military_pct -= 4
	if approval >= 75 and happiness >= 70 and liquidity > max(1000000, population * 8):
		tax_rate += 1.0
		treasury_pct += 4
		goods_pct -= 2
		military_pct -= 2

	var out: Dictionary = {
		"realm_id": realm_id,
		"tax_rate": tax_rate,
		"treasury_pct": treasury_pct,
		"military_pct": military_pct,
		"goods_pct": goods_pct
	}
	out = _apply_ai_realm_governance_variance(realm_id, realm, ruler, out)
	return _sanitize_ai_realm_allocation_plan(out)


func _run_ai_realm_allocation_cycle(realm_id: int, realm: Dictionary) -> Dictionary:
	if gs == null:
		return realm
	if realm.is_empty():
		return realm
	if gs.player != null and int(gs.player.realm_id) == realm_id:
		return realm
	if int(realm.get("allocation_last_set_year", -1)) == int(gs.year):
		return realm

	var ruler_id: int = int(realm.get("ruler_id", -1))
	var ruler = gs.get_npc_by_id(ruler_id) if ruler_id > 0 else null
	if ruler != null and (not ruler.alive or bool(ruler.exiled) or bool(ruler.deposed)):
		return realm

	var population: int = max(int(realm.get("population", 0)), get_total_population_for_realm(realm_id))
	var plan: Dictionary = _build_ai_realm_allocation_plan(realm_id, realm, ruler, population)

	var tax_rate: float = clamp(float(plan.get("tax_rate", 10.0)), 0.0, 40.0)
	var treasury_pct: int = clamp(int(plan.get("treasury_pct", 34)), 0, 100)
	var military_pct: int = clamp(int(plan.get("military_pct", 33)), 0, 100)
	var goods_pct: int = clamp(int(plan.get("goods_pct", 33)), 0, 100)

	var tax_revenue: int = _calculate_realm_tax_revenue(population, tax_rate, realm)
	var saved_reserve: int = int(realm.get("allocation_reserve", 0))
	var available_pool: int = saved_reserve + tax_revenue

	var treasury_amount: int = int(round(float(available_pool) * (float(treasury_pct) / 100.0)))
	var military_budget: int = int(round(float(available_pool) * (float(military_pct) / 100.0)))
	var goods_budget: int = int(round(float(available_pool) * (float(goods_pct) / 100.0)))

	var military_unit_cost: int = 4500
	var goods_unit_cost: int = 200000

	var military_units: int = int(floor(float(military_budget) / float(max(1, military_unit_cost))))
	var goods_units: int = int(floor(float(goods_budget) / float(max(1, goods_unit_cost))))

	var military_amount: int = military_units * max(1, military_unit_cost)
	var goods_amount: int = goods_units * max(1, goods_unit_cost)
	var spent_total: int = treasury_amount + military_amount + goods_amount
	var carryover_amount: int = max(0, available_pool - spent_total)

	realm ["tax_rate"] = tax_rate
	realm ["allocation_treasury_pct"] = treasury_pct
	realm ["allocation_military_pct"] = military_pct
	realm ["allocation_goods_pct"] = goods_pct
	realm ["allocation_reserve"] = carryover_amount
	realm ["treasury"] = int(realm.get("treasury", 0)) + treasury_amount
	realm ["military_stockpile"] = int(realm.get("military_stockpile", 0)) + military_units
	realm ["goods_stockpile"] = int(realm.get("goods_stockpile", 0)) + goods_units
	realm ["allocation_last_set_year"] = int(gs.year)
	realm ["pending_tax_effect_year"] = int(gs.year) + 1
	realm ["pending_tax_happiness_delta"] = clamp(int(round((20.0 - tax_rate) / 7.0)), -4, 3)
	realm ["pending_tax_approval_delta"] = clamp(int(round((18.0 - tax_rate) / 4.0)), -6, 4)
	realm ["pending_tax_respect_delta"] = clamp(int(round((16.0 - tax_rate) / 5.0)), -5, 3)
	realm ["happiness"] = clamp(int(realm.get("happiness", 50)), 0, 100)
	realm ["allocation_policy_source"] = "ai_ruler"
	realm ["allocation_policy_year"] = int(gs.year)

	return realm



func create_custom_realm_for_player(owner: Person, realm_name: String) -> int:
	var contract:= {
		"schema": "eralife.realm_creation_contract",
		"version": 2,
		"contract_id": "custom_realm_create_%d_%d" % [
			int(owner.id) if owner != null else -1,
			int(Time.get_ticks_msec())
		],
		"type": "CREATE_REALM",
		"realm_type": "STANDARD",
		"realm_kind": "state",
		"dimension_type": "standard_realm",
		"name": str(realm_name).strip_edges(),
		"owner_id": int(owner.id) if owner != null else -1,
		"ruler_id": int(owner.id) if owner != null else -1,
		"capacity": 500000,
		"realm_capacity": 500000,
		"land": -1,
		"treasury_floor": 25000,
		"cost": 0,
		"bypass_payment": true,
		"governance_contract": {
			"government_style": "Monarchy",
			"governance_deferred": false,
			"ruler_id": int(owner.id) if owner != null else -1,
			"approval_floor": 60
		},
		"population_contract": {
			"population_is_registry_derived": false,
			"migration_contract_required": false,
			"max_population": 500000,
			"overflow_behavior": "soft_cap"
		},
		"source": "legacy_create_custom_realm_for_player"
	}

	var report: Dictionary = resolve_realm_creation_contract(contract, {
		"source": "legacy_create_custom_realm_for_player"
	})

	return int(report.get("realm_id", -1))



func resolve_realm_creation_contract(contract: Dictionary, context: Dictionary = {}) -> Dictionary:
	if typeof(contract) != TYPE_DICTIONARY or contract.is_empty():
		return {
			"success": false,
			"reason": "empty_realm_creation_contract",
			"authority": "realm_engine"
		}

	var contract_type: String = str(contract.get("type", "")).strip_edges().to_upper()
	if contract_type != "CREATE_REALM":
		return {
			"success": false,
			"reason": "unsupported_realm_contract_type",
			"contract_type": contract_type,
			"authority": "realm_engine"
		}

	var owner_id: int = int(contract.get("owner_id", contract.get("ruler_id", -1)))
	var owner: Person = _person_by_id_for_realm_contract(owner_id)
	if owner == null:
		return {
			"success": false,
			"reason": "realm_creation_owner_not_found",
			"owner_id": owner_id,
			"authority": "realm_engine"
		}

	var realm_name: String = str(contract.get("name", contract.get("realm_name", ""))).strip_edges()
	if realm_name == "":
		return {
			"success": false,
			"reason": "missing_realm_name",
			"owner_id": owner_id,
			"authority": "realm_engine"
		}

	var contract_id: String = str(contract.get("contract_id", "")).strip_edges()
	if contract_id != "":
		for raw_id in realms.keys():
			var existing_id: int = int(raw_id)
			var existing_raw: Variant = realms.get(raw_id, realms.get(existing_id, {}))
			var existing: Dictionary = existing_raw if typeof(existing_raw) == TYPE_DICTIONARY else {}
			if str(existing.get("creation_contract_id", "")).strip_edges() == contract_id:
				return {
					"success": true,
					"mode": "realm_creation_contract_already_committed",
					"realm_id": existing_id,
					"realm_name": str(existing.get("name", realm_name)),
					"realm": existing.duplicate(true),
					"authority": "realm_engine"
				}

	var cost: int = max(0, int(contract.get("cost", 0)))
	var bypass_payment: bool = bool(contract.get("bypass_payment", false))
	if cost > 0 and not bypass_payment and int(owner.bank_balance) < cost:
		return {
			"success": false,
			"reason": "insufficient_funds",
			"required": cost,
			"available": int(owner.bank_balance),
			"owner_id": owner_id,
			"authority": "realm_engine"
		}

	var committed: Dictionary = _commit_realm_creation_contract(owner, contract, context)
	return committed



func _commit_realm_creation_contract(owner: Person, contract: Dictionary, context: Dictionary = {}) -> Dictionary:
	var new_id: int = _next_realm_id()
	var realm_type: String = _realm_type_key(str(contract.get("realm_type", "STANDARD")))
	var is_island: bool = realm_type == "ISLAND"

	var realm_name: String = str(contract.get("name", "Realm %d" % new_id)).strip_edges()
	var capacity: int = max(1, int(contract.get("realm_capacity", contract.get("capacity", 500000))))
	var cost: int = max(0, int(contract.get("cost", 0)))
	var bypass_payment: bool = bool(contract.get("bypass_payment", false))

	if cost > 0 and not bypass_payment:
		owner.bank_balance = max(0, int(owner.bank_balance) - cost)

	var governance_contract: Dictionary = contract.get("governance_contract", {}) if typeof(contract.get("governance_contract", {})) == TYPE_DICTIONARY else {}
	var population_contract: Dictionary = contract.get("population_contract", {}) if typeof(contract.get("population_contract", {})) == TYPE_DICTIONARY else {}
	var ownership_contract: Dictionary = contract.get("ownership_contract", {}) if typeof(contract.get("ownership_contract", {})) == TYPE_DICTIONARY else {}

	var government_style: String = str(governance_contract.get("government_style", contract.get("government_style", "Monarchy"))).strip_edges()
	if government_style == "":
		government_style = "Monarchy"

	var treasury_floor: int = max(0, int(contract.get("treasury_floor", 25000)))
	var starting_treasury: int = max(treasury_floor, int(owner.bank_balance * 0.1))
	if is_island:
		starting_treasury = max(treasury_floor, int(owner.bank_balance * 0.04))

	var land_value: int = int(contract.get("land", -1))
	if land_value <= 0:
		land_value = 40 if is_island else randi_range(10, 100)

	var realm:= {
		"id": str(new_id),
		"realm_id": new_id,
		"name": realm_name,
		"population": 1,
		"population_floor": 1,
		"population_ceiling": capacity,
		"capacity": capacity,
		"realm_capacity": capacity,
		"land": land_value,
		"treasury": starting_treasury,
		"military_stockpile": 0 if is_island else randi_range(25, 120),
		"goods_stockpile": 0 if is_island else randi_range(10, 60),
		"government_style": government_style,
		"realm_kind": str(contract.get("realm_kind", "micro_nation" if is_island else "state")),
		"realm_type": realm_type,
		"dimension_type": str(contract.get("dimension_type", "island_realm" if is_island else "standard_realm")),
		"land_label": "Island Territory" if is_island else "Territory",
		"is_new_starting_realm": true,
		"ruler_id": int(owner.id),
		"owner_id": int(owner.id),
		"creation_contract_id": str(contract.get("contract_id", "")),
		"created_by_contract_type": str(contract.get("schema", "eralife.realm_creation_contract")),
		"created_from_source": str(context.get("source", contract.get("source", "realm_creation_contract"))),
		"created_at_year": int(contract.get("year_created", gs.year if gs != null else 0)),
		"created_at_ms": int(Time.get_ticks_msec()),
		"ownership_contract": ownership_contract.duplicate(true),
		"governance_contract": governance_contract.duplicate(true),
		"population_contract": population_contract.duplicate(true),
		"population_is_registry_derived": bool(population_contract.get("population_is_registry_derived", is_island)),
		"population_source": str(population_contract.get("population_source", "global_entity_registry" if is_island else "realm_engine_projection")),
		"migration_contract_required": bool(population_contract.get("migration_contract_required", is_island)),
		"overflow_behavior": str(population_contract.get("overflow_behavior", "migration_out" if is_island else "soft_cap")),
		"realm_capacity_contract_ready": true,
	}

	if is_island:
		realm ["realm_browser_section"] = "island_realms"
		realm ["browser_visual_theme"] = "island_realm"
		realm ["overview_visual_theme"] = "island_realm"
		realm ["realm_population_surface_contract_ready"] = true
		realm ["realm_resident_pool_bootstrap_deferred"] = true
		realm ["realm_governance_bootstrap_deferred"] = bool(governance_contract.get("governance_deferred", true))
		realm ["visible_residents_are_view_contract"] = true

	realms [new_id] = _apply_realm_contract_defaults(new_id, realm)

	owner.realm_id = new_id
	owner.is_ruler = true
	owner.is_royal = true
	owner.approval = max(int(owner.approval), int(governance_contract.get("approval_floor", 60)))

	if "palace_owned" in owner and is_island:
		owner.palace_owned = true

	if not is_island:
		ensure_realm_defaults(new_id)
		ensure_realm_governance(new_id, str(realms [new_id].get("capital_city", "")).strip_edges())
	else:
		var island_realm_raw: Variant = realms.get(new_id, {})
		var island_realm: Dictionary = island_realm_raw if typeof(island_realm_raw) == TYPE_DICTIONARY else realm
		island_realm ["population"] = get_total_population_for_realm(new_id)
		island_realm ["population_previous_year"] = int(island_realm.get("population", 1))
		realms [new_id] = _apply_realm_contract_defaults(new_id, island_realm)

	if gs != null and gs.has_method("push_world_feed"):
		gs.push_world_feed(
			"%s %s founded the %s of %s." % [
				owner.first_name,
				owner.last_name,
				"island realm" if is_island else "realm",
				realm_name
			],
			{
				"npc_id": int(owner.id),
				"personally_relevant": owner == gs.player,
				"category": "realm",
				"event_name": "island_realm_founded" if is_island else "realm_founded",
				"realm_id": new_id,
				"realm_type": realm_type,
				"source": "realm_engine_contract_commit"
			}
		)

	var final_raw: Variant = realms.get(new_id, realm)
	var final_realm: Dictionary = final_raw if typeof(final_raw) == TYPE_DICTIONARY else realm

	return {
		"success": true,
		"schema": "eralife.realm_creation_commit_report",
		"version": 2,
		"mode": "realm_creation_contract_committed",
		"realm_id": new_id,
		"realm_name": realm_name,
		"realm_type": realm_type,
		"owner_id": int(owner.id),
		"ruler_id": int(owner.id),
		"cost_committed": cost if not bypass_payment else 0,
		"realm": final_realm.duplicate(true),
		"authority": "realm_engine"
	}


func _next_realm_id() -> int:
	var new_id: int = 1
	for raw_id in realms.keys():
		new_id = max(new_id, int(raw_id) + 1)
	return new_id


func _realm_type_key(value: String) -> String:
	var clean: String = str(value).strip_edges().to_upper()
	if clean == "":
		return "STANDARD"

	match clean:
		"ISLAND", "ISLAND_REALM", "MICRO_NATION":
			return "ISLAND"
		"STANDARD", "STANDARD_REALM", "COUNTRY", "STATE":
			return "STANDARD"
		_:
			return clean


func _person_by_id_for_realm_contract(person_id: int) -> Person:
	if gs == null or person_id <= 0:
		return null

	if gs.player != null and int(gs.player.id) == person_id:
		return gs.player

	if gs.has_method("get_npc_by_id"):
		return gs.get_npc_by_id(person_id)

	return null


func _realm_requires_migration_contract(realm: Dictionary) -> bool:
	if typeof(realm) != TYPE_DICTIONARY:
		return false

	if bool(realm.get("migration_contract_required", false)):
		return true

	var realm_type: String = _realm_type_key(str(realm.get("realm_type", "")))
	return realm_type == "ISLAND"


func _realm_capacity_for(realm: Dictionary) -> int:
	if typeof(realm) != TYPE_DICTIONARY:
		return 0

	return max(0, int(realm.get("realm_capacity", realm.get("capacity", realm.get("population_ceiling", 0)))))


func _apply_realm_capacity_constraint(realm_id: int, realm: Dictionary, live_population: int = -1) -> Dictionary:
	if realm_id <= 0 or typeof(realm) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "invalid_realm_capacity_contract",
			"realm_id": realm_id
		}

	var capacity: int = _realm_capacity_for(realm)
	if capacity <= 0:
		return {
			"success": true,
			"realm_id": realm_id,
			"capacity": capacity,
			"population": max(0, live_population),
			"overflow": 0,
			"realm": realm.duplicate(true)
		}

	if live_population < 0:
		live_population = get_total_population_for_realm(realm_id)

	var overflow: int = max(0, live_population - capacity)
	var next_population: int = min(live_population, capacity)

	realm ["population_ceiling"] = capacity
	realm ["realm_capacity"] = capacity
	realm ["capacity"] = capacity
	realm ["population"] = next_population
	realm ["capacity_pressure"] = float(live_population) / float(max(1, capacity))
	realm ["overflow_population"] = overflow
	realm ["overflow_behavior"] = str(realm.get("overflow_behavior", "migration_out"))
	realm ["realm_capacity_contract_ready"] = true

	if overflow > 0 and gs != null and "population_movement_contract_engine" in gs and gs.population_movement_contract_engine != null:
		if gs.population_movement_contract_engine.has_method("resolve_overflow_for_realm"):
			var overflow_report: Dictionary = gs.population_movement_contract_engine.resolve_overflow_for_realm(realm_id, {
				"capacity": capacity,
				"overflow": overflow,
				"source": "realm_capacity_constraint"
			})
			realm ["last_overflow_report"] = overflow_report.duplicate(true)
			live_population = get_total_population_for_realm(realm_id)
			next_population = min(live_population, capacity)
			realm ["population"] = next_population
			realm ["overflow_population"] = max(0, live_population - capacity)

	return {
		"success": true,
		"realm_id": realm_id,
		"capacity": capacity,
		"population": next_population,
		"live_population": live_population,
		"overflow": max(0, live_population - capacity),
		"realm": realm.duplicate(true)
	}


func get_realm_id_for_owner(owner_id: int, realm_type_filter: String = "") -> int:
	if owner_id <= 0:
		return -1

	var filter_key: String = _realm_type_key(realm_type_filter) if str(realm_type_filter).strip_edges() != "" else ""

	for raw_id in realms.keys():
		var realm_id: int = int(raw_id)
		var realm_raw: Variant = realms.get(raw_id, realms.get(realm_id, {}))
		if typeof(realm_raw) != TYPE_DICTIONARY:
			continue

		var realm: Dictionary = realm_raw
		if int(realm.get("owner_id", realm.get("ruler_id", -1))) != owner_id:
			continue

		if filter_key != "" and _realm_type_key(str(realm.get("realm_type", ""))) != filter_key:
			continue

		return realm_id

	return -1


func derive_realm_residents(realm_id: int, include_dormant: bool = true) -> Array:
	var out: Array = []
	if gs == null or realm_id <= 0:
		return out

	if "npcs" in gs:
		for npc in gs.npcs:
			if npc == null:
				continue
			if "alive" in npc and not bool(npc.alive):
				continue
			if "realm_id" in npc and int(npc.realm_id) == realm_id:
				out.append(npc)

	if include_dormant and "dormant_npcs" in gs and typeof(gs.dormant_npcs) == TYPE_DICTIONARY:
		for raw_id in gs.dormant_npcs.keys():
			var d: Variant = gs.dormant_npcs.get(raw_id, {})
			if typeof(d) != TYPE_DICTIONARY:
				continue
			var row: Dictionary = d
			if not bool(row.get("alive", true)):
				continue
			if int(row.get("realm_id", -1)) != realm_id:
				continue
			out.append(row)

	return out


func get_visible_residents_for_realm(realm_id: int, limit: int = 20, offset: int = 0) -> Array:
	var residents: Array = derive_realm_residents(realm_id, false)
	var start: int = max(0, offset)
	var end: int = min(residents.size(), start + max(1, limit))
	if start >= residents.size():
		return []
	return residents.slice(start, end)
func get_total_population_for_realm(realm_id: int) -> int:
	if gs == null or realm_id <= 0:
		return 0

	var total: int = 0

	if "npcs" in gs:
		for npc in gs.npcs:
			if npc == null:
				continue
			if "alive" in npc and not bool(npc.alive):
				continue
			if "realm_id" in npc and int(npc.realm_id) == realm_id:
				total += 1

	if "dormant_npcs" in gs and typeof(gs.dormant_npcs) == TYPE_DICTIONARY:
		for id in gs.dormant_npcs.keys():
			var d: Variant = gs.dormant_npcs [id]
			if typeof(d) != TYPE_DICTIONARY:
				continue
			var row: Dictionary = d
			if bool(row.get("alive", true)) and int(row.get("realm_id", -1)) == realm_id:
				total += 1

	if "population_shard_engine" in gs and gs.population_shard_engine != null:
		if gs.population_shard_engine.has_method("get_realm_population"):
			total += int(gs.population_shard_engine.get_realm_population(realm_id))

	return total