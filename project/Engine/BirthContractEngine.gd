extends Resource
class_name BirthContractEngine

const BIRTH_CONTRACT_VERSION:= 1

const BIRTH_BLOCKED_REALM_KEYS:= [
	"terabithia",
	"era_kingdom",
	"vormir",
	"nidavellir",
	"soul_world",
	"afterlife"
]

var gs


func _init(_gs = null):
	gs = _gs


func normalize_birth_intent(intent: Dictionary, context: Dictionary = {}) -> Dictionary:
	var birth_raw: Variant = intent.get("birth", intent)
	var birth: Dictionary = birth_raw.duplicate(true) if typeof(birth_raw) == TYPE_DICTIONARY else {}

	var args_raw: Variant = intent.get("args", {})
	var args: Dictionary = args_raw.duplicate(true) if typeof(args_raw) == TYPE_DICTIONARY else {}

	var source: String = str(context.get("source", birth.get("source", args.get("source", "unknown_birth_surface")))).strip_edges()
	var name: String = str(birth.get("name", args.get("name", context.get("fallback_name", "Someone")))).strip_edges()
	if name == "":
		name = "Someone"

	var gender: String = str(birth.get("gender", args.get("gender", ""))).strip_edges().to_lower()
	var requested_gender: String = str(birth.get("requested_gender", args.get("requested_gender", "random"))).strip_edges().to_lower()

	if requested_gender not in ["male", "female", "random"]:
		requested_gender = "random"
	if gender not in ["male", "female"]:
		gender = ""

	var month: int = clamp(int(birth.get("month", args.get("month", 1))), 1, 12)
	# FIX: this was clamp(day, 1, 31) with no regard for the month, so February 31st
	# and April 31st were accepted. Clamp to the actual length of the month, with
	# leap years handled.
	var birth_year_for_day: int = int(birth.get("year", args.get("year", 0)))
	var day: int = EraUtils.clamp_day_for_month(
		int(birth.get("day", args.get("day", 1))),
		month,
		birth_year_for_day
	)

	var era_key: String = _normalize_era_key(str(birth.get("era_key", args.get("era_key", args.get("era", "Modern")))))
	var reality_mode: String = str(birth.get("reality_mode", args.get("reality_mode", "realistic"))).strip_edges().to_lower()

	if reality_mode not in ["realistic", "enhanced", "fantasy"]:
		reality_mode = "realistic"

	var country: String = str(birth.get("country", args.get("country", ""))).strip_edges()
	var city: String = str(birth.get("city", args.get("city", ""))).strip_edges()

	if _is_blocked_birth_realm(country):
		country = ""
		city = ""

	var year: int = int(birth.get("year", args.get("year", 0)))
	var seed_source: String = str(birth.get("birth_seed", args.get("birth_seed", "%s.%s.%s.%s" % [
		str(context.get("life_node_id", birth.get("life_node_id", ""))),
		era_key,
		name,
		str(context.get("external_user_id", birth.get("external_user_id", "unknown_user")))
	])))

	if year == 0:
		year = _year_for_era(era_key, seed_source)

	var social_class: String = str(birth.get("social_class", args.get("social_class", birth.get("class", args.get("class", ""))))).strip_edges()
	if social_class == "" or social_class == "Random / Era Default":
		social_class = _pick_social_class(era_key, reality_mode, seed_source, birth, args)

	var allow_royal_birth: bool = bool(birth.get("allow_royal_birth", args.get("allow_royal_birth", false)))
	if social_class in ["Royal", "Noble"]:
		allow_royal_birth = true

	var royal_rank: String = str(birth.get("royal_rank", args.get("royal_rank", ""))).strip_edges()
	if not allow_royal_birth:
		royal_rank = ""

	var contract:= {
		"schema": "eralife.birth_contract",
		"version": BIRTH_CONTRACT_VERSION,
		"source": source,
		"_external_birth_intent": true,
		"_god_mode_entry_kind": str(birth.get("_god_mode_entry_kind", args.get("_god_mode_entry_kind", "external_birth_intent"))),

		"name": name,
		"first_name": _first_name(name),
		"last_name": _last_name(name),

		"gender": gender,
		"requested_gender": requested_gender,

		"era": era_key,
		"era_key": era_key,
		"era_name": str(birth.get("era_name", args.get("era_name", _era_display_name(era_key)))),

		"reality_mode": reality_mode,
		"reality_name": str(birth.get("reality_name", args.get("reality_name", reality_mode.capitalize() + " Mode"))),

		"year": year,
		"year_locked": false,

		"month": month,
		"day": day,
		"birthday_text": str(birth.get("birthday_text", args.get("birthday_text", _month_name(month) + " " + str(day)))),
		"zodiac_sign": str(birth.get("zodiac_sign", args.get("zodiac_sign", _zodiac_sign(month, day)))),

		"country": country,
		"city": city,

		"generate_family": true,
		"social_class": social_class,
		"discord_birth_social_class_forced": true,
		"allow_royal_birth": allow_royal_birth,
		"force_common_birth": not allow_royal_birth,
		"royal_rank": royal_rank,

		"parent_job_policy": {
			"mode": "social_class_weighted",
			"allow_royal_titles": allow_royal_birth,
			"social_class": social_class
		},

		"family_generation_policy": {
			"mode": "contract_birth_family",
			"stats_blend": "parents_and_grandparents",
			"clear_accidental_royalty": not allow_royal_birth
		},

		"world_mode": str(context.get("world_mode", birth.get("world_mode", args.get("mode", "solo")))),
		"world_container_id": str(context.get("world_container_id", birth.get("world_container_id", ""))),
		"life_node_id": str(context.get("life_node_id", birth.get("life_node_id", ""))),
		"external_user_id": str(context.get("external_user_id", birth.get("external_user_id", ""))),

		"birth_seed": seed_source,
		"bank_balance": int(birth.get("bank_balance", args.get("bank_balance", _starting_money_for_class(social_class, seed_source)))),
		"starting_money": int(birth.get("starting_money", args.get("starting_money", _starting_money_for_class(social_class, seed_source))))
	}

	if country != "":
		contract ["birth_country"] = country
		contract ["home_country"] = country

	if city != "":
		contract ["birth_city"] = city
		contract ["home_city"] = city

	return contract


func _pick_social_class(era_key: String, reality_mode: String, seed_source: String, birth: Dictionary, args: Dictionary) -> String:
	var allow_royal_birth: bool = bool(birth.get("allow_royal_birth", args.get("allow_royal_birth", false)))
	var roll: int = abs(hash("%s.%s.%s.social_class" % [seed_source, era_key, reality_mode])) % 1000

	match era_key:
		"Ancient":
			if allow_royal_birth and roll < 8:
				return "Royal"
			if allow_royal_birth and roll < 24:
				return "Noble"
			if roll < 80:
				return "Merchant"
			if roll < 260:
				return "Commoner"
			if roll < 700:
				return "Peasant"
			return "Lower Class"
		"Medieval":
			if allow_royal_birth and roll < 10:
				return "Royal"
			if allow_royal_birth and roll < 34:
				return "Noble"
			if roll < 95:
				return "Merchant"
			if roll < 300:
				return "Commoner"
			if roll < 735:
				return "Peasant"
			return "Lower Class"
		"Industrial":
			if roll < 70:
				return "Upperclass"
			if roll < 250:
				return "Merchant"
			if roll < 640:
				return "Working Class"
			return "Commoner"
		"Future":
			if roll < 95:
				return "Elite"
			if roll < 275:
				return "Upperclass"
			if roll < 675:
				return "Middle Class"
			return "Working Class"
		_:
			if roll < 80:
				return "Elite"
			if roll < 240:
				return "Upperclass"
			if roll < 620:
				return "Middle Class"
			if roll < 850:
				return "Working Class"
			return "Commoner"


func _starting_money_for_class(social_class: String, seed_source: String) -> int:
	var roll: int = abs(hash("%s.starting_money" % seed_source)) % 1000

	match str(social_class).strip_edges():
		"Royal":
			return 50000 + roll * 200
		"Noble":
			return 15000 + roll * 75
		"Elite":
			return 8000 + roll * 40
		"Upperclass", "Upper Class":
			return 3000 + roll * 20
		"Merchant":
			return 1000 + roll * 12
		"Middle Class":
			return 500 + roll * 6
		"Working Class":
			return 100 + roll * 2
		"Commoner":
			return roll
		"Peasant", "Lower Class":
			return int(floor(float(roll) / 4.0))
		_:
			return roll


func _year_for_era(era_key: String, seed_source: String) -> int:
	if gs != null and gs.has_method("get"):
		var era_engine = gs.get("era_engine")
		if era_engine != null:
			var eras_raw: Variant = era_engine.get("eras") if era_engine.has_method("get") else {}
			if typeof(eras_raw) == TYPE_DICTIONARY:
				var eras: Dictionary = eras_raw
				if eras.has(era_key):
					var era_data_raw: Variant = eras.get(era_key, {})
					if typeof(era_data_raw) == TYPE_DICTIONARY:
						var era_data: Dictionary = era_data_raw
						var start_year: int = int(era_data.get("start_year", 2000))
						var end_year: int = int(era_data.get("end_year", start_year))
						if end_year < start_year:
							var swap_year: int = start_year
							start_year = end_year
							end_year = swap_year
						var span: int = max(1, end_year - start_year + 1)
						return start_year + (abs(hash(seed_source)) % span)

	return 2000


func _is_blocked_birth_realm(value: String) -> bool:
	var clean: String = str(value).strip_edges().to_lower()
	if clean == "":
		return false

	clean = clean.replace(" ", "_")
	return clean in BIRTH_BLOCKED_REALM_KEYS


func _normalize_era_key(value: String) -> String:
	var clean: String = str(value).strip_edges().replace(" Era", "").replace(" era", "")

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
		_:
			return "Modern"


func _era_display_name(era_key: String) -> String:
	match _normalize_era_key(era_key):
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
		_:
			return "Modern Era"


func _first_name(full_name: String) -> String:
	var parts: PackedStringArray = str(full_name).split(" ", false)
	if parts.size() <= 0:
		return "Someone"
	return str(parts [0]).strip_edges()


func _last_name(full_name: String) -> String:
	var parts: PackedStringArray = str(full_name).split(" ", false)
	if parts.size() <= 1:
		return ""

	var rest: Array = []
	for i in range(1, parts.size()):
		rest.append(str(parts [i]).strip_edges())

	return " ".join(rest).strip_edges()


func _month_name(month: int) -> String:
	var names:= [
		"January",
		"February",
		"March",
		"April",
		"May",
		"June",
		"July",
		"August",
		"September",
		"October",
		"November",
		"December"
	]

	return str(names [clamp(month, 1, 12) - 1])


func _zodiac_sign(month: int, day: int) -> String:
	match month:
		1:
			return "Capricorn" if day <= 19 else "Aquarius"
		2:
			return "Aquarius" if day <= 18 else "Pisces"
		3:
			return "Pisces" if day <= 20 else "Aries"
		4:
			return "Aries" if day <= 19 else "Taurus"
		5:
			return "Taurus" if day <= 20 else "Gemini"
		6:
			return "Gemini" if day <= 20 else "Cancer"
		7:
			return "Cancer" if day <= 22 else "Leo"
		8:
			return "Leo" if day <= 22 else "Virgo"
		9:
			return "Virgo" if day <= 22 else "Libra"
		10:
			return "Libra" if day <= 22 else "Scorpio"
		11:
			return "Scorpio" if day <= 21 else "Sagittarius"
		12:
			return "Sagittarius" if day <= 21 else "Capricorn"
		_:
			return "Capricorn"