extends Resource
class_name EraLifeAssetCatalogExpansion

const ENGINE_SCHEMA:= "eralife.asset_catalog_expansion"
const CONTRACT_VERSION:= 1

var gs: GameState = null
var vehicle_template_index: Dictionary = {}
var property_template_index: Dictionary = {}
var dealership_index: Dictionary = {}
var catalog_built: bool = false


func _init(_gs: GameState = null) -> void:
	bind_game_state(_gs)


func bind_game_state(_gs: GameState) -> void:
	gs = _gs
	_ensure_catalog()


func reset_runtime() -> void:


	pass


func vehicle_template_by_id(template_id: String) -> Dictionary:
	_ensure_catalog()

	var clean_id: String = str(template_id).strip_edges()
	if not vehicle_template_index.has(clean_id):
		return {}

	return (
		vehicle_template_index [clean_id] as Dictionary
	).duplicate(true)


func property_template_by_id(template_id: String) -> Dictionary:
	_ensure_catalog()

	var clean_id: String = str(template_id).strip_edges()
	if not property_template_index.has(clean_id):
		return {}

	return (
		property_template_index [clean_id] as Dictionary
	).duplicate(true)


func dealership_contract_by_id(dealership_id: String) -> Dictionary:
	_ensure_catalog()

	var clean_id: String = str(dealership_id).strip_edges()
	if not dealership_index.has(clean_id):
		return {}

	return (
		dealership_index [clean_id] as Dictionary
	).duplicate(true)


func vehicle_templates_for_actor(
	_actor: Person,
	context: Dictionary = {}
) -> Array:
	_ensure_catalog()

	var era_key: String = _current_era_key()
	var reality_key: String = _current_reality_key()
	var selected_dealership_id: String = str(
		context.get("selected_dealership_id", "")
	).strip_edges()
	var out: Array = []

	for raw_template in vehicle_template_index.values():
		var template: Dictionary = (
			raw_template as Dictionary
		).duplicate(true)

		if not _allows_era(template, era_key):
			continue

		if not _allows_reality(template, reality_key):
			continue

		if selected_dealership_id != "":
			var dealership_ids: Array = _safe_array(
				template.get("dealership_ids", [])
			)

			if not dealership_ids.has(selected_dealership_id):
				continue

		template ["catalog_authority"] = ENGINE_SCHEMA
		template ["catalog_version"] = CONTRACT_VERSION
		template ["availability"] = str(
			template.get("availability", "available")
		)
		template ["ownership_status"] = str(
			template.get("ownership_status", "available")
		)

		out.append(template)

	out.sort_custom(func (left_raw, right_raw) -> bool:
		var left: Dictionary = left_raw as Dictionary
		var right: Dictionary = right_raw as Dictionary
		var left_category: String = str(left.get("category", ""))
		var right_category: String = str(right.get("category", ""))

		if left_category == right_category:
			return int(left.get("base_value", 0)) < int(
				right.get("base_value", 0)
			)

		return left_category < right_category
	)

	return out


func property_templates_for_actor(
	_actor: Person,
	context: Dictionary = {}
) -> Array:
	_ensure_catalog()

	var era_key: String = _current_era_key()
	var reality_key: String = _current_reality_key()
	var requested_category: String = str(
		context.get("property_category", "all")
	).strip_edges().to_lower()
	var out: Array = []

	for raw_template in property_template_index.values():
		var template: Dictionary = (
			raw_template as Dictionary
		).duplicate(true)

		if not _allows_era(template, era_key):
			continue

		if not _allows_reality(template, reality_key):
			continue

		if (
			requested_category != ""
			and requested_category != "all"
		):
			var filter_tags: Array = _safe_array(
				template.get("filter_tags", [])
			)

			if not filter_tags.has(requested_category):
				continue

		template ["catalog_authority"] = ENGINE_SCHEMA
		template ["catalog_version"] = CONTRACT_VERSION
		template ["availability"] = str(
			template.get("availability", "available")
		)
		template ["ownership_status"] = str(
			template.get("ownership_status", "available")
		)

		out.append(template)

	out.sort_custom(func (left_raw, right_raw) -> bool:
		var left: Dictionary = left_raw as Dictionary
		var right: Dictionary = right_raw as Dictionary
		var left_category: String = str(left.get("category", ""))
		var right_category: String = str(right.get("category", ""))

		if left_category == right_category:
			return int(left.get("base_value", 0)) < int(
				right.get("base_value", 0)
			)

		return left_category < right_category
	)

	return out


func dealership_contracts_for_actor(
	_actor: Person,
	_context: Dictionary = {}
) -> Array:
	_ensure_catalog()

	var era_key: String = _current_era_key()
	var reality_key: String = _current_reality_key()
	var out: Array = []

	for raw_contract in dealership_index.values():
		var contract: Dictionary = (
			raw_contract as Dictionary
		).duplicate(true)

		if not _allows_era(contract, era_key):
			continue

		if not _allows_reality(contract, reality_key):
			continue

		out.append(contract)

	out.sort_custom(func (left_raw, right_raw) -> bool:
		return int(
			(left_raw as Dictionary).get("display_order", 0)
		) < int(
			(right_raw as Dictionary).get("display_order", 0)
		)
	)

	return out


func vehicle_filter_contracts() -> Array:
	match _current_era_key():
		"ancient":
			return [
				_filter("all", "All", "✦", ["all"]),
				_filter("wagons", "Carts & Wagons", "🛞", [
					"cart",
					"wagon",
					"carriage",
					"land"
				]),
				_filter("mounts", "Mounts", "🐎", [
					"mount",
					"animal",
					"living_transport"
				]),
				_filter("chariots", "Chariots", "🏺", [
					"chariot"
				]),
				_filter("watercraft", "Watercraft", "⛵", [
					"watercraft",
					"water",
					"boat",
					"ship"
				]),
				_filter("military", "Military", "🛡️", [
					"military",
					"war"
				]),
				_filter("mythical", "Mythical", "🐉", [
					"mythical",
					"fantasy",
					"super_vehicle"
				]),
				_filter("owned", "Owned", "🔑", ["owned"])
			]

		"medieval":
			return [
				_filter("all", "All", "✦", ["all"]),
				_filter("carriages", "Carriages", "🛞", [
					"carriage",
					"wagon",
					"cart"
				]),
				_filter("mounts", "Mounts", "🐎", [
					"mount",
					"animal",
					"living_transport"
				]),
				_filter("military", "War Transport", "⚔️", [
					"military",
					"war",
					"siege"
				]),
				_filter("watercraft", "Watercraft", "⛵", [
					"watercraft",
					"water",
					"ship",
					"boat"
				]),
				_filter("royal", "Royal", "👑", [
					"royal",
					"luxury"
				]),
				_filter("fantasy", "Fantasy", "🐉", [
					"fantasy",
					"mythical"
				]),
				_filter("owned", "Owned", "🔑", ["owned"])
			]

		"industrial":
			return [
				_filter("all", "All", "✦", ["all"]),
				_filter("carriages", "Carriages", "🛞", [
					"carriage",
					"wagon"
				]),
				_filter("rail", "Rail & Steam", "🚂", [
					"rail",
					"steam",
					"train"
				]),
				_filter("motor", "Early Motor", "🚙", [
					"car",
					"motor",
					"automobile"
				]),
				_filter("commercial", "Commercial", "🚚", [
					"commercial",
					"utility"
				]),
				_filter("watercraft", "Watercraft", "🚢", [
					"watercraft",
					"water",
					"ship"
				]),
				_filter("aircraft", "Aircraft", "✈️", [
					"aircraft",
					"air"
				]),
				_filter("luxury", "Luxury", "💎", ["luxury"]),
				_filter("owned", "Owned", "🔑", ["owned"]),
				_filter("financing", "Financing", "💳", ["financed"])
			]

		"future":
			return [
				_filter("all", "All", "✦", ["all"]),
				_filter("ground", "Ground", "🚘", [
					"car",
					"suv",
					"ground",
					"land"
				]),
				_filter("autonomous", "Autonomous", "🤖", [
					"autonomous",
					"smart_vehicle"
				]),
				_filter("aircraft", "Aircraft", "✈️", [
					"aircraft",
					"air",
					"flying"
				]),
				_filter("watercraft", "Watercraft", "🚤", [
					"watercraft",
					"water"
				]),
				_filter("spaceships", "Spacecraft", "🚀", [
					"spaceship",
					"space",
					"orbital"
				]),
				_filter("commercial", "Commercial", "🚚", [
					"commercial",
					"utility"
				]),
				_filter("luxury", "Luxury", "💎", ["luxury"]),
				_filter("mythical", "Mythical", "🐉", [
					"mythical",
					"fantasy",
					"super_vehicle"
				]),
				_filter("owned", "Owned", "🔑", ["owned"]),
				_filter("financing", "Financing", "💳", ["financed"]),
				_filter("lease", "Lease", "🧾", ["leased"])
			]

		_:
			return [
				_filter("all", "All", "✦", ["all"]),
				_filter("cars", "Cars", "🚗", [
					"car",
					"sedan",
					"hatchback",
					"compact",
					"sports",
					"supercar",
					"grand_tourer"
				]),
				_filter("suvs", "SUVs", "🚙", ["suv"]),
				_filter("luxury", "Luxury", "💎", ["luxury"]),
				_filter("commercial", "Commercial", "🚚", [
					"commercial",
					"utility"
				]),
				_filter("emergency", "Emergency", "🚑", ["emergency"]),
				_filter("watercraft", "Watercraft", "🚤", [
					"watercraft",
					"water"
				]),
				_filter("aircraft", "Aircraft", "✈️", [
					"aircraft",
					"air"
				]),
				_filter("mounts", "Mounts", "🐎", [
					"mount",
					"animal",
					"living_transport"
				]),
				_filter("mythical", "Mythical", "🐉", [
					"mythical",
					"fantasy",
					"super_vehicle"
				]),
				_filter("owned", "Owned", "🔑", ["owned"]),
				_filter("financing", "Financing", "💳", ["financed"]),
				_filter("lease", "Lease", "🧾", ["leased"])
			]


func property_filter_contracts() -> Array:
	match _current_era_key():
		"ancient":
			return [
				_filter("all", "All", "✦", ["all"]),
				_filter("residential", "Dwellings", "🏠", ["residential"]),
				_filter("villa", "Domus & Villas", "🏛️", [
					"villa",
					"domus",
					"noble_villa"
				]),
				_filter("insula", "Insulae", "🏢", [
					"insula",
					"tenement",
					"apartment"
				]),
				_filter("agricultural", "Farms", "🌾", [
					"farm",
					"agricultural"
				]),
				_filter("commercial", "Commercial", "🏺", ["commercial"]),
				_filter("government", "Government", "🏛️", ["government"]),
				_filter("military", "Military", "🛡️", ["military"]),
				_filter("royal", "Royal", "👑", ["royal"]),
				_filter("religious", "Religious", "🕯️", ["religious"]),
				_filter("fantasy", "Mythical", "🐉", [
					"fantasy",
					"mythical"
				]),
				_filter("rental", "Rental", "🧾", [
					"rental",
					"rented"
				]),
				_filter("owned", "Owned", "🔑", ["owned"]),
				_filter("available", "Available", "✅", ["available"])
			]

		"medieval":
			return [
				_filter("all", "All", "✦", ["all"]),
				_filter("residential", "Homes", "🏠", ["residential"]),
				_filter("castle", "Castles & Forts", "🏰", [
					"castle",
					"fortress",
					"military"
				]),
				_filter("estate", "Manors & Estates", "🏡", [
					"manor",
					"estate",
					"villa"
				]),
				_filter("agricultural", "Farms", "🌾", [
					"farm",
					"agricultural"
				]),
				_filter("commercial", "Commercial", "🛒", ["commercial"]),
				_filter("royal", "Royal", "👑", ["royal"]),
				_filter("religious", "Religious", "⛪", ["religious"]),
				_filter("military", "Military", "⚔️", ["military"]),
				_filter("fantasy", "Fantasy", "🐉", [
					"fantasy",
					"mythical"
				]),
				_filter("rental", "Rental", "🧾", [
					"rental",
					"rented"
				]),
				_filter("owned", "Owned", "🔑", ["owned"]),
				_filter("available", "Available", "✅", ["available"])
			]

		"industrial":
			return [
				_filter("all", "All", "✦", ["all"]),
				_filter("residential", "Residential", "🏠", ["residential"]),
				_filter("tenement", "Tenements", "🏢", [
					"tenement",
					"apartment"
				]),
				_filter("townhouse", "Townhouses", "🏘️", [
					"townhouse"
				]),
				_filter("estate", "Estates", "🏡", [
					"estate",
					"manor",
					"luxury"
				]),
				_filter("commercial", "Commercial", "🏪", ["commercial"]),
				_filter("industrial", "Industrial", "🏭", ["industrial"]),
				_filter("government", "Government", "🏛️", ["government"]),
				_filter("religious", "Religious", "⛪", ["religious"]),
				_filter("rental", "Rental", "🧾", [
					"rental",
					"rented"
				]),
				_filter("owned", "Owned", "🔑", ["owned"]),
				_filter("available", "Available", "✅", ["available"])
			]

		"future":
			return [
				_filter("all", "All", "✦", ["all"]),
				_filter("residential", "Habitats", "🏠", ["residential"]),
				_filter("apartment", "Apartments", "🏢", [
					"apartment",
					"micro_apartment",
					"penthouse"
				]),
				_filter("smart_home", "Smart Homes", "🤖", [
					"smart_home",
					"adaptive"
				]),
				_filter("orbital", "Orbital & Space", "🛰️", [
					"orbital",
					"space",
					"station"
				]),
				_filter("commercial", "Commercial", "🏪", ["commercial"]),
				_filter("government", "Government", "🏛️", ["government"]),
				_filter("military", "Military", "🛡️", ["military"]),
				_filter("luxury", "Luxury", "💎", ["luxury"]),
				_filter("fantasy", "Mythical", "🐉", [
					"fantasy",
					"mythical"
				]),
				_filter("rental", "Rental", "🧾", [
					"rental",
					"rented"
				]),
				_filter("owned", "Owned", "🔑", ["owned"]),
				_filter("available", "Available", "✅", ["available"])
			]

		_:
			return [
				_filter("all", "All", "✦", ["all"]),
				_filter("residential", "Residential", "🏠", ["residential"]),
				_filter("apartment", "Apartments", "🏢", [
					"apartment",
					"penthouse",
					"loft"
				]),
				_filter("house", "Houses", "🏡", [
					"house",
					"townhouse",
					"cabin"
				]),
				_filter("luxury", "Luxury", "💎", ["luxury"]),
				_filter("commercial", "Commercial", "🏪", ["commercial"]),
				_filter("government", "Government", "🏛️", ["government"]),
				_filter("military", "Military", "🛡️", ["military"]),
				_filter("religious", "Religious", "⛪", ["religious"]),
				_filter("fantasy", "Fantasy", "🐉", [
					"fantasy",
					"mythical"
				]),
				_filter("rental", "Rental", "🧾", [
					"rental",
					"rented"
				]),
				_filter("owned", "Owned", "🔑", ["owned"]),
				_filter("available", "Available", "✅", ["available"])
			]


func _ensure_catalog() -> void:
	if catalog_built:
		return

	vehicle_template_index.clear()
	property_template_index.clear()
	dealership_index.clear()

	var dealership_rows: Array = _dealership_rows()
	dealership_rows.append_array(
		_expanded_dealership_rows()
	)

	for raw_row in dealership_rows:
		var dealership_contract: Dictionary = (
			_dealership_from_row(
				str(raw_row)
			)
		)
		var dealership_id: String = str(
			dealership_contract.get(
				"dealership_id",
				""
			)
		)

		if dealership_id != "":
			dealership_index [dealership_id] = (
				dealership_contract
			)

	var vehicle_rows: Array = _vehicle_rows()
	vehicle_rows.append_array(
		_expanded_vehicle_rows()
	)

	for raw_row in vehicle_rows:
		var vehicle_template: Dictionary = (
			_vehicle_from_row(
				str(raw_row)
			)
		)
		var vehicle_template_id: String = str(
			vehicle_template.get(
				"template_id",
				""
			)
		)

		if vehicle_template_id != "":
			vehicle_template_index [
				vehicle_template_id
			] = vehicle_template

	var property_rows: Array = _property_rows()
	property_rows.append_array(
		_expanded_property_rows()
	)

	for raw_row in property_rows:
		var property_template: Dictionary = (
			_property_from_row(
				str(raw_row)
			)
		)
		var property_template_id: String = str(
			property_template.get(
				"template_id",
				""
			)
		)

		if property_template_id != "":
			property_template_index [
				property_template_id
			] = property_template

	catalog_built = true


func _dealership_rows() -> Array:
	return [
		"ancient_common_mounts|Bronze Road Mount Exchange|Affordable|🐎|ancient|mount,animal,utility|all|1|7B4F26|FFB34C",
		"ancient_chariot_house|Imperial Chariot House|Regular|🏺|ancient|chariot,carriage,land|all|2|A34B22|FF7A2E",
		"ancient_river_boatworks|River & Reed Boatworks|Watercraft|⛵|ancient|watercraft,water|all|3|237FAE|39C5FF",
		"ancient_royal_beast_pavilion|Royal Beast Pavilion|Luxury|🐘|ancient|mount,animal,luxury|all|4|C18A24|FFD34D",
		"ancient_mythic_stables|Oracle Mythic Stables|Fantasy|🐉|ancient|fantasy,mythical,mount|chaos,fantasy|5|6725A6|D55CFF",

		"medieval_common_tack|Common Wheel & Tack|Affordable|🛞|medieval|mount,animal,carriage,utility|all|1|6C5032|B78B4D",
		"medieval_crown_carriage|Crown Carriage Guild|Regular|🛞|medieval|carriage,luxury,land|all|2|8A3529|ED703B",
		"medieval_harborwrights|Harborwrights Exchange|Watercraft|⚓|medieval|watercraft,water|all|3|236AA5|3AB7FF",
		"medieval_royal_menagerie|Royal Menagerie|Luxury|🦁|medieval|mount,animal,luxury|all|4|B78B28|FFD34C",
		"medieval_arcane_aerie|Arcane Aerie|Fantasy|🦅|medieval|fantasy,mythical,mount,air|chaos,fantasy|5|642B9C|C95FFF",

		"industrial_workers_motors|Foundry Workers Motor Lot|Affordable|🚘|industrial|car,utility,commercial|all|1|59656B|9CBBCB",
		"industrial_continental_motors|Continental Motor & Coach|Regular|🚗|industrial|car,luxury,commercial|all|2|803920|DC6A34",
		"industrial_aero_marine|Empire Aero & Marine Exchange|Air & Water|🛩️|industrial|aircraft,watercraft,air,water|all|3|187693|35C6EC",
		"industrial_elite_coachworks|Gilded Age Coachworks|Luxury|🎩|industrial|luxury,car,carriage|all|4|B38A2B|FFD151",

		"modern_affordable|Horizon Value Motors|Affordable|🚗|modern|economy,car,compact,sedan,hatchback|all|1|197FC2|32D1FF",
		"modern_regular|Metro Auto Gallery|Regular|🚙|modern|car,suv,sports|all|2|2C65C0|58ADFF",
		"modern_luxury|Sovereign Luxury House|Luxury|💎|modern|luxury,sports,suv|all|3|9D3BB4|F66BFF",
		"modern_fleet|Vanguard Utility & Fleet|Commercial|🚚|modern|utility,commercial,emergency|all|4|9E531A|FF932E",
		"modern_marine|Harborline Marine|Watercraft|🛥️|modern|watercraft,water|all|5|11799B|20C8F6",
		"modern_aviation|Altitude Aviation|Aircraft|✈️|modern|aircraft,air|all|6|4D77AD|84C7FF",
		"modern_mythic|Mythic Dynamics|Fantasy|🦇|modern|fantasy,mythical,super_vehicle|chaos,fantasy|7|7C21AA|D64CFF",

		"future_civic|Nova Civic Mobility|Affordable|🛸|future|economy,hover,car|all|1|149DBB|29F3FF",
		"future_regular|Aetheris Mobility Nexus|Regular|🚘|future|car,suv,hover,air|all|2|396BD6|6BB8FF",
		"future_luxury|Celestial Crown Motors|Luxury|💠|future|luxury,sports,air,space|all|3|922FC7|EF5CFF",
		"future_fleet|Titan Industrial Mobility|Commercial|🚛|future|utility,commercial,emergency|all|4|A95016|FF991F",
		"future_marine|Pelagic Futurecraft|Watercraft|🌊|future|watercraft,water,submersible|all|5|0A6BA8|1BD7FF",
		"future_aerospace|Orbital Gate Aerospace|Aircraft & Space|🚀|future|aircraft,spaceship,air,space|all|6|4047B4|8494FF",
		"future_mythic|Spirit-Tech Menagerie|Fantasy|🐉|future|fantasy,mythical,mount,space|chaos,fantasy|7|7B1AB8|E347FF"
	]

func _expanded_dealership_rows() -> Array:
	return [
		"industrial_mass_motors|Mass Production Motor Hall|Regular|🚘|industrial|car,sedan,truck,utility|all|5|5D6670|B9C8D8",
		"industrial_grand_touring|Gilded Grand Touring House|Luxury|🏛️|industrial|luxury,car,sports|all|6|7D4D20|F3C46B",
		"industrial_heavy_mobility|Continental Heavy Mobility|Commercial|🏭|industrial|truck,military,utility|all|7|4C555B|D78845",

		"modern_truck_center|American Truck Center|Trucks|🛻|modern|truck,pickup,utility,commercial|all|8|8B3A24|FF8552",
		"modern_cadillac_custom|Cadillac Custom & Lowrider House|Custom Luxury|✨|modern|cadillac,lowrider,luxury,sedan|all|9|4D2C66|CF8CFF",
		"modern_ultra_luxury|Apex Hypercar Exchange|Ultra Luxury|💎|modern|hypercar,supercar,luxury,collector|all|10|5E247D|FF60E6",
		"modern_defense_mobility|Federal Defense Mobility Depot|Restricted|🛡️|modern|tank,military,restricted,government|all|11|46533D|A7C95A",
		"modern_superyacht_broker|Crown Harbor Superyacht Brokerage|Superyachts|🛥️|modern|yacht,superyacht,watercraft,luxury|all|12|0B567A|42DAFF",

		"future_hover_gallery|Skyway Hover Gallery|Hover Mobility|🛸|future|hover,car,suv,air|all|8|245EAC|5ECAFF",
		"future_retro_future|Retro-Future Motor Vault|Retro Future|⌛|future|retro_future,car,hover,collector|all|9|6A3E88|E79BFF",
		"future_defense_mobility|Orbital Defense Mobility Command|Restricted|🛡️|future|tank,military,restricted,hover|all|10|364846|75F0B1",
		"future_superyacht_broker|Pelagic Crown Megayacht Nexus|Megayachts|🛥️|future|yacht,submersible,watercraft,luxury|all|11|075B88|34EAFF"
	]
func _vehicle_rows() -> Array:
	return [


		"ancient_horse|Living Mount|Horse|mount|animal|1|ancient|road,trail,field|feed|18|650|mount,animal,living_transport,economy|ancient_common_mounts|true|horse|all",
		"ancient_camel|Living Mount|Camel|mount|animal|1|ancient|desert,road,trail|feed|22|820|mount,animal,living_transport,utility|ancient_common_mounts|true|camel|all",
		"ancient_donkey|Living Mount|Donkey|mount|animal|1|ancient|road,trail,farm|feed|12|380|mount,animal,living_transport,economy|ancient_common_mounts|true|donkey|all",
		"ancient_elephant|Royal Beast Pavilion|War Elephant|mount|animal|4|ancient|road,field,battlefield|feed|110|8200|mount,animal,living_transport,luxury,utility|ancient_royal_beast_pavilion|true|elephant|all",
		"ancient_ox_cart|Bronze Road|Ox Cart|cart|animal_powered|3|ancient|road,trail,farm|feed|28|1100|utility,commercial,mount|ancient_common_mounts|false||all",
		"ancient_light_chariot|Imperial Chariot House|Light Chariot|chariot|animal_powered|2|ancient|road,field,battlefield|feed|34|2400|carriage,chariot,sports,land|ancient_chariot_house|false||all",
		"ancient_royal_chariot|Imperial Chariot House|Royal Chariot|chariot|animal_powered|3|ancient|road,ceremonial,battlefield|feed|58|7200|carriage,chariot,luxury,royal|ancient_chariot_house,ancient_royal_beast_pavilion|false||all",
		"ancient_canoe|River & Reed|Reed Canoe|canoe|human_powered|3|ancient|river,lake,coast|none|4|420|watercraft,water,economy|ancient_river_boatworks|false||all",
		"ancient_fishing_boat|River & Reed|Fishing Boat|fishing_boat|sail|6|ancient|river,coast,sea|wind|22|2600|watercraft,water,commercial|ancient_river_boatworks|false||all",
		"ancient_merchant_galley|River & Reed|Merchant Galley|galley|sail_and_oar|24|ancient|coast,sea|wind|180|18000|watercraft,water,commercial,luxury|ancient_river_boatworks|false||all",

		"medieval_riding_horse|Common Wheel & Tack|Riding Horse|mount|animal|1|medieval|road,trail,field|feed|20|900|mount,animal,living_transport,economy|medieval_common_tack|true|horse|all",
		"medieval_warhorse|Royal Menagerie|Warhorse|mount|animal|1|medieval|road,trail,battlefield|feed|46|4800|mount,animal,living_transport,luxury,military|medieval_royal_menagerie|true|horse|all",
		"medieval_donkey_cart|Common Wheel & Tack|Donkey Cart|cart|animal_powered|3|medieval|road,trail,farm|feed|22|760|utility,commercial,carriage|medieval_common_tack|false||all",
		"medieval_merchant_wagon|Common Wheel & Tack|Merchant Wagon|wagon|animal_powered|5|medieval|road,trail|feed|40|2600|utility,commercial,carriage|medieval_common_tack|false||all",
		"medieval_noble_carriage|Crown Carriage Guild|Noble Carriage|carriage|animal_powered|4|medieval|road,ceremonial|feed|72|9500|carriage,luxury,royal|medieval_crown_carriage|false||all",
		"medieval_rowboat|Harborwrights|Rowboat|rowboat|human_powered|4|medieval|river,lake,coast|none|8|620|watercraft,water,economy|medieval_harborwrights|false||all",
		"medieval_cog|Harborwrights|Merchant Cog|ship|sail|28|medieval|coast,sea|wind|220|28000|watercraft,water,commercial|medieval_harborwrights|false||all",
		"medieval_galleon|Harborwrights|Royal Galleon|ship|sail|80|medieval|sea,ocean|wind|620|120000|watercraft,water,luxury,royal|medieval_harborwrights,medieval_crown_carriage|false||all",

		"industrial_model_t|Ford|Model T|sedan|combustion|5|industrial|road,city|gasoline|36|8500|car,sedan,economy|industrial_workers_motors|false||all",
		"industrial_benz_motorwagen|Benz|Patent-Motorwagen|compact|combustion|2|industrial|road,city|gasoline|42|14000|car,compact,historic|industrial_continental_motors|false||all",
		"industrial_rolls_silver_ghost|Rolls-Royce|Silver Ghost|luxury_sedan|combustion|5|industrial|road,city|gasoline|210|125000|car,luxury,sedan|industrial_elite_coachworks|false||all",
		"industrial_delivery_truck|Foundry Fleet|Delivery Truck|cargo_truck|combustion|2|industrial|road,industrial|gasoline|95|18000|commercial,utility,truck|industrial_workers_motors|false||all",
		"industrial_fire_engine|Metropolitan Works|Fire Engine|fire_truck|steam|8|industrial|road,city|coal|180|42000|emergency,commercial,utility|industrial_workers_motors|false||all",
		"industrial_steam_yacht|Empire Marine|Steam Yacht|yacht|steam|18|industrial|coast,sea|coal|540|175000|watercraft,water,luxury|industrial_aero_marine|false||all",
		"industrial_ferry|Empire Marine|Passenger Ferry|ferry|steam|120|industrial|river,coast|coal|760|240000|watercraft,water,commercial|industrial_aero_marine|false||all",
		"industrial_biplane|Wright Aeronautics|Biplane|biplane|propeller|2|industrial|air,field|aviation_fuel|260|95000|aircraft,air,sports|industrial_aero_marine|false||all",
		"industrial_zeppelin|Imperial Aero|Passenger Zeppelin|airship|lighter_than_air|40|industrial|air|hydrogen|900|480000|aircraft,air,luxury,commercial|industrial_aero_marine,industrial_elite_coachworks|false||all",

		"modern_toyota_corolla|Toyota|Corolla|sedan|combustion|5|modern|road,city|gasoline|180|24000|car,sedan,economy|modern_affordable,modern_regular|false||all",
		"modern_honda_civic|Honda|Civic|sedan|combustion|5|modern|road,city|gasoline|190|26000|car,sedan,economy|modern_affordable,modern_regular|false||all",
		"modern_hyundai_elantra|Hyundai|Elantra|sedan|combustion|5|modern|road,city|gasoline|175|23000|car,sedan,economy|modern_affordable|false||all",
		"modern_kia_rio|Kia|Rio|compact|combustion|5|modern|road,city|gasoline|155|19500|car,compact,economy|modern_affordable|false||all",
		"modern_nissan_versa|Nissan|Versa|compact|combustion|5|modern|road,city|gasoline|160|20500|car,compact,economy|modern_affordable|false||all",
		"modern_vw_golf|Volkswagen|Golf|hatchback|combustion|5|modern|road,city|gasoline|210|29000|car,hatchback,economy|modern_affordable,modern_regular|false||all",
		"modern_mazda3|Mazda|Mazda3 Hatchback|hatchback|combustion|5|modern|road,city|gasoline|205|28500|car,hatchback,economy|modern_affordable,modern_regular|false||all",
		"modern_mini_cooper|MINI|Cooper|compact|combustion|4|modern|road,city|gasoline|230|32000|car,compact,premium|modern_regular|false||all",

		"modern_toyota_rav4|Toyota|RAV4|suv|hybrid|5|modern|road,trail|hybrid|270|36000|suv,car,utility|modern_regular|false||all",
		"modern_honda_crv|Honda|CR-V|suv|combustion|5|modern|road,trail|gasoline|260|35000|suv,car,utility|modern_regular|false||all",
		"modern_ford_expedition|Ford|Expedition|suv|combustion|8|modern|road,trail|gasoline|460|72000|suv,utility,premium|modern_regular|false||all",
		"modern_range_rover|Land Rover|Range Rover|luxury_suv|combustion|5|modern|road,trail|gasoline|820|145000|suv,luxury|modern_luxury|false||all",

		"modern_rolls_phantom|Rolls-Royce|Phantom|luxury_sedan|combustion|5|modern|road,city|gasoline|2100|520000|car,sedan,luxury|modern_luxury|false||all",
		"modern_rolls_ghost|Rolls-Royce|Ghost|luxury_sedan|combustion|5|modern|road,city|gasoline|1700|390000|car,sedan,luxury|modern_luxury|false||all",
		"modern_rolls_cullinan|Rolls-Royce|Cullinan|luxury_suv|combustion|5|modern|road,trail|gasoline|1900|430000|suv,luxury|modern_luxury|false||all",
		"modern_rolls_spectre|Rolls-Royce|Spectre|luxury_coupe|electric|4|modern|road,city|electric|1500|420000|car,luxury,electric|modern_luxury|false||all",
		"modern_bentley_continental|Bentley|Continental GT|luxury_coupe|combustion|4|modern|road,city|gasoline|1250|275000|car,luxury,sports|modern_luxury|false||all",
		"modern_bentley_flying_spur|Bentley|Flying Spur|luxury_sedan|combustion|5|modern|road,city|gasoline|1350|285000|car,sedan,luxury|modern_luxury|false||all",
		"modern_bentley_bentayga|Bentley|Bentayga|luxury_suv|combustion|5|modern|road,trail|gasoline|1450|305000|suv,luxury|modern_luxury|false||all",
		"modern_maybach_s|Mercedes-Maybach|S-Class|luxury_sedan|combustion|5|modern|road,city|gasoline|1200|240000|car,sedan,luxury|modern_luxury|false||all",
		"modern_maybach_gls|Mercedes-Maybach|GLS|luxury_suv|combustion|5|modern|road,trail|gasoline|1300|260000|suv,luxury|modern_luxury|false||all",
		"modern_aston_db12|Aston Martin|DB12|grand_tourer|combustion|4|modern|road,track|gasoline|1150|275000|car,sports,luxury|modern_luxury|false||all",
		"modern_aston_dbx|Aston Martin|DBX|luxury_suv|combustion|5|modern|road,trail|gasoline|1100|245000|suv,luxury,sports|modern_luxury|false||all",
		"modern_maserati_granturismo|Maserati|GranTurismo|grand_tourer|combustion|4|modern|road,track|gasoline|850|190000|car,sports,luxury|modern_luxury|false||all",
		"modern_tesla_cybertruck|Tesla|Cybertruck|pickup|electric|5|modern|road,trail,worksite|electric|680|120000|truck,utility,luxury,electric|modern_regular,modern_luxury,modern_fleet|false||all",

		"modern_ferrari_296|Ferrari|296 GTB|supercar|hybrid|2|modern|road,track|hybrid|1450|355000|car,sports,luxury|modern_luxury|false||all",
		"modern_ferrari_roma|Ferrari|Roma|grand_tourer|combustion|4|modern|road,track|gasoline|1300|330000|car,sports,luxury|modern_luxury|false||all",
		"modern_ferrari_sf90|Ferrari|SF90 Stradale|supercar|hybrid|2|modern|road,track|hybrid|1900|590000|car,sports,luxury|modern_luxury|false||all",
		"modern_lambo_huracan|Lamborghini|Huracán|supercar|combustion|2|modern|road,track|gasoline|1500|350000|car,sports,luxury|modern_luxury|false||all",
		"modern_lambo_revuelto|Lamborghini|Revuelto|supercar|hybrid|2|modern|road,track|hybrid|2100|650000|car,sports,luxury|modern_luxury|false||all",
		"modern_lambo_urus|Lamborghini|Urus|luxury_suv|combustion|5|modern|road,trail|gasoline|1400|290000|suv,sports,luxury|modern_luxury|false||all",
		"modern_mclaren_artura|McLaren|Artura|supercar|hybrid|2|modern|road,track|hybrid|1350|260000|car,sports,luxury|modern_luxury|false||all",
		"modern_mclaren_720s|McLaren|720S|supercar|combustion|2|modern|road,track|gasoline|1600|380000|car,sports,luxury|modern_luxury|false||all",
		"modern_mclaren_gt|McLaren|GT|grand_tourer|combustion|2|modern|road,track|gasoline|1250|250000|car,sports,luxury|modern_luxury|false||all",
		"modern_porsche_911|Porsche|911 Carrera|sports_coupe|combustion|4|modern|road,track|gasoline|850|145000|car,sports,luxury|modern_regular,modern_luxury|false||all",
		"modern_porsche_cayman|Porsche|718 Cayman|sports_coupe|combustion|2|modern|road,track|gasoline|650|92000|car,sports,premium|modern_regular,modern_luxury|false||all",
		"modern_porsche_taycan|Porsche|Taycan|sports_sedan|electric|5|modern|road,track|electric|780|135000|car,sports,luxury,electric|modern_luxury|false||all",

		"modern_pickup|Vanguard|Heavy-Duty Pickup|pickup|combustion|5|modern|road,trail,worksite|diesel|520|68000|truck,utility,commercial|modern_fleet|false||all",
		"modern_cargo_van|Vanguard|Cargo Van|cargo_van|combustion|2|modern|road,city,worksite|diesel|430|54000|utility,commercial|modern_fleet|false||all",
		"modern_dump_truck|Titan Works|Dump Truck|dump_truck|combustion|2|modern|road,worksite|diesel|1200|180000|truck,utility,commercial|modern_fleet|false||all",
		"modern_tow_truck|Titan Works|Tow Truck|tow_truck|combustion|2|modern|road,worksite|diesel|840|130000|truck,utility,commercial|modern_fleet|false||all",
		"modern_ambulance|Vanguard Emergency|Ambulance|ambulance|combustion|6|modern|road,city|diesel|780|145000|emergency,commercial,utility|modern_fleet|false||all",
		"modern_fire_truck|Vanguard Emergency|Fire Truck|fire_truck|combustion|8|modern|road,city|diesel|2200|520000|emergency,commercial,utility|modern_fleet|false||all",
		"modern_police_cruiser|Vanguard Emergency|Police Cruiser|police_cruiser|combustion|5|modern|road,city|gasoline|520|72000|emergency,car,sedan|modern_fleet|false||all",

		"modern_canoe|Harborline|Canoe|canoe|human_powered|3|modern|river,lake|none|8|1200|watercraft,water,economy|modern_marine|false||all",
		"modern_fishing_boat|Harborline|Fishing Boat|fishing_boat|motor|6|modern|river,coast,sea|gasoline|260|42000|watercraft,water,commercial|modern_marine|false||all",
		"modern_speedboat|Harborline|Speedboat|speedboat|motor|6|modern|lake,coast,sea|gasoline|520|98000|watercraft,water,sports,luxury|modern_marine|false||all",
		"modern_yacht|Harborline|Luxury Yacht|yacht|motor|18|modern|coast,sea,ocean|diesel|4200|1800000|watercraft,water,luxury|modern_marine|false||all",
		"modern_ferry|Harborline|Passenger Ferry|ferry|motor|160|modern|river,coast,sea|diesel|7800|6200000|watercraft,water,commercial|modern_marine|false||all",

		"modern_glider|Altitude|Glider|glider|glide|2|modern|air,mountain|none|180|68000|aircraft,air,sports|modern_aviation|false||all",
		"modern_helicopter|Altitude|Executive Helicopter|helicopter|rotor|6|modern|air,helipad|aviation_fuel|3800|1800000|aircraft,air,luxury|modern_aviation|false||all",
		"modern_business_jet|Altitude|Business Jet|jet|jet|12|modern|air,airport|aviation_fuel|26000|18000000|aircraft,air,luxury|modern_aviation|false||all",
		"modern_airship|Altitude|Luxury Airship|airship|lighter_than_air|40|modern|air|helium|9500|9500000|aircraft,air,luxury|modern_aviation|false||all",

		"future_city_hovercar|Nova|City Hovercar|hovercar|anti_gravity|5|future|road,air,city|electric|260|68000|car,hover,economy|future_civic,future_regular|false||all",
		"future_family_sky_suv|Aetheris|Sky SUV|hover_suv|anti_gravity|7|future|road,air,trail|fusion_cell|480|145000|suv,hover,utility|future_regular|false||all",
		"future_quantum_supercar|Celestial|Quantum Supercar|supercar|quantum_drive|2|future|road,air,track|quantum_cell|2600|1250000|car,sports,luxury,hover|future_luxury|false||all",
		"future_autonomous_freighter|Titan|Autonomous Freighter|cargo_truck|autonomous_hover|2|future|road,air,worksite|fusion_cell|1200|520000|commercial,utility,hover|future_fleet|false||all",
		"future_medical_response|Titan|Medical Response Skimmer|ambulance|anti_gravity|8|future|road,air,city|fusion_cell|1600|780000|emergency,commercial,hover|future_fleet|false||all",
		"future_hydrofoil_yacht|Pelagic|Hydrofoil Yacht|yacht|hydrofoil|20|future|coast,sea,ocean|fusion_cell|5200|3200000|watercraft,water,luxury|future_marine|false||all",
		"future_submersible|Pelagic|Private Submersible|submersible|submersible|8|future|underwater,ocean|fusion_cell|7800|6500000|watercraft,water,luxury|future_marine|false||all",
		"future_orbital_shuttle|Orbital Gate|Orbital Shuttle|spaceship|fusion_rocket|18|future|air,space,orbit|fusion_cell|18000|12000000|spaceship,space,aircraft|future_aerospace|false||all",
		"future_private_starship|Orbital Gate|Private Starship|spaceship|warp_drive|24|future|space,deep_space|antimatter|68000|98000000|spaceship,space,luxury|future_aerospace,future_luxury|false||all",

		"fantasy_flying_bison|Air Nomad|Flying Bison|mount|animal_flight|8|ancient,medieval,industrial,modern,future|air,mountain,sky|feed|140|28000|mount,animal,living_transport,fantasy,mythical,air|ancient_mythic_stables,medieval_arcane_aerie,modern_mythic,future_mythic|true|flying_bison|chaos,fantasy",
		"fantasy_dragon|Mythic Menagerie|Dragon|mount|mythic_flight|3|ancient,medieval,industrial,modern,future|air,mountain,volcanic|feed|520|180000|mount,living_transport,fantasy,mythical,air|ancient_mythic_stables,medieval_arcane_aerie,modern_mythic,future_mythic|true|dragon|chaos,fantasy",
		"fantasy_griffin|Mythic Menagerie|Griffin|mount|mythic_flight|2|ancient,medieval,industrial,modern,future|air,mountain,field|feed|310|92000|mount,living_transport,fantasy,mythical,air|ancient_mythic_stables,medieval_arcane_aerie,modern_mythic,future_mythic|true|griffin|chaos,fantasy",
		"fantasy_phoenix|Mythic Menagerie|Phoenix|mount|spirit_flight|1|ancient,medieval,industrial,modern,future|air,spirit|spirit_energy|420|150000|mount,living_transport,fantasy,mythical,air|ancient_mythic_stables,medieval_arcane_aerie,modern_mythic,future_mythic|true|phoenix|chaos,fantasy",
		"fantasy_spirit_wolf|Spirit-Tech|Spirit Wolf|mount|spirit_run|2|ancient,medieval,industrial,modern,future|road,trail,spirit|spirit_energy|160|52000|mount,living_transport,fantasy,mythical|ancient_mythic_stables,medieval_arcane_aerie,modern_mythic,future_mythic|true|spirit_wolf|chaos,fantasy",
		"fantasy_night_vigilante_car|Mythic Dynamics|Night Vigilante Car|super_vehicle|turbine|2|modern,future|road,city,armored|synthetic_fuel|2400|2800000|car,mythical,fantasy,luxury,super_vehicle|modern_mythic,future_mythic|false||chaos,fantasy"
	]


func _property_rows() -> Array:
	return [


		"ancient_shared_hut|Shared Hut|residential|shared_hut|900|ancient|residential,rental,available|tribal,shared,basic|1|0|0|rent|all",
		"ancient_tribal_longhouse|Tribal Longhouse|residential|tribal_longhouse|5200|ancient|residential,available|tribal,community,large|4|0|2|buy,rent|all",
		"ancient_stone_dwelling|Stone Dwelling|residential|stone_dwelling|7800|ancient|residential,available|stone,urban,ancient|2|0|1|buy,rent|all",
		"ancient_noble_villa|Noble Villa|residential|noble_villa|65000|ancient|residential,royal,luxury,available|villa,courtyard,luxury|8|2|6|buy,government_grant|all",
		"ancient_palace_wing|Palace Wing|royal|palace_wing|180000|ancient|royal,government,luxury,available|palace,ceremonial,royal|12|4|10|government_grant|all",
		"ancient_farmstead|Farmstead|commercial|farmstead|12000|ancient|commercial,residential,available|farm,grain,rural|3|0|4|buy,rent|all",
		"ancient_temple_compound|Temple Compound|religious|temple_compound|110000|ancient|religious,luxury,available|temple,ceremonial|10|2|6|institutional,government_grant|all",

		"medieval_peasant_cottage|Peasant Cottage|residential|peasant_cottage|4800|medieval|residential,rental,available|cottage,rural,basic|2|0|1|buy,rent|all",
		"medieval_town_house|Town House|residential|town_house|18000|medieval|residential,rental,available|urban,timber|3|1|2|buy,rent|all",
		"medieval_manor|Manor House|residential|manor|120000|medieval|residential,luxury,available|estate,landed,wealthy|8|3|8|buy,mortgage|all",
		"medieval_castle|Castle|royal|castle|950000|medieval|royal,military,luxury,available|fortified,royal,large|24|8|20|buy,government_grant|all",
		"medieval_palace|Royal Palace|royal|palace|2800000|medieval|royal,government,luxury,available|palace,ceremonial,royal|40|20|30|government_grant|all",
		"medieval_monastery|Monastery|religious|monastery|260000|medieval|religious,available|religious,community,stone|30|8|10|institutional|all",
		"medieval_merchant_warehouse|Merchant Warehouse|commercial|warehouse|95000|medieval|commercial,available|warehouse,harbor,trade|0|1|12|buy,rent|all",

		"industrial_tenement|Tenement Flat|residential|tenement|18000|industrial|residential,rental,available|urban,brick,basic|2|1|0|rent|all",
		"industrial_row_house|Row House|residential|row_house|42000|industrial|residential,available|urban,brick|3|1|1|buy,rent,mortgage|all",
		"industrial_victorian_home|Victorian Home|residential|victorian_home|160000|industrial|residential,luxury,available|historic,urban,wealthy|5|2|3|buy,mortgage|all",
		"industrial_country_estate|Country Estate|residential|country_estate|780000|industrial|residential,luxury,available|estate,rural,luxury|12|6|12|buy,mortgage|all",
		"industrial_factory|Factory|commercial|factory|420000|industrial|commercial,available|factory,industrial,brick|0|4|30|buy,mortgage|all",
		"industrial_warehouse|Warehouse|commercial|warehouse|180000|industrial|commercial,available|warehouse,industrial|0|2|24|buy,rent,mortgage|all",
		"industrial_grand_hotel|Grand Hotel|commercial|hotel|950000|industrial|commercial,luxury,available|hotel,hospitality,luxury|50|40|18|buy,mortgage|all",
		"industrial_train_depot|Train Depot|commercial|train_depot|1100000|industrial|commercial,government,available|rail,transit,industrial|0|6|40|buy,government_grant|all",

		"modern_studio_apartment|Studio Apartment|residential|studio_apartment|62000|modern|residential,rental,available|apartment,urban,compact|1|1|0|rent|all",
		"modern_loft_apartment|Loft Apartment|residential|loft_apartment|185000|modern|residential,rental,luxury,available|apartment,urban,loft|2|2|1|rent,mortgage|all",
		"modern_micro_apartment|Micro Apartment|residential|micro_apartment|48000|modern|residential,rental,available|apartment,urban,micro|1|1|0|rent|all",
		"modern_duplex|Duplex|residential|duplex|280000|modern|residential,rental,available|suburban,multi_unit|5|3|3|buy,rent,mortgage|all",
		"modern_townhouse|Townhouse|residential|townhouse|320000|modern|residential,available|urban,family|3|3|2|buy,rent,mortgage|all",
		"modern_mobile_home|Mobile Home|residential|mobile_home|85000|modern|residential,available|mobile,compact|2|1|2|buy,rent,mortgage|all",
		"modern_tiny_house|Tiny House|residential|tiny_house|110000|modern|residential,available|compact,eco|1|1|1|buy,mortgage|all",
		"modern_victorian_home|Victorian Home|residential|victorian_home|480000|modern|residential,luxury,available|historic,family|5|3|3|buy,mortgage|all",
		"modern_ranch_home|Ranch Home|residential|ranch_home|340000|modern|residential,available|suburban,single_story|4|3|4|buy,mortgage|all",
		"modern_colonial_home|Colonial Home|residential|colonial_home|560000|modern|residential,luxury,available|historic,suburban|5|4|4|buy,mortgage|all",
		"modern_craftsman_home|Craftsman Home|residential|craftsman_home|420000|modern|residential,available|suburban,workshop|4|3|4|buy,mortgage|all",
		"modern_lake_house|Lake House|residential|lake_house|720000|modern|residential,luxury,available|waterfront,lake|5|4|5|buy,mortgage|all",
		"modern_beach_house|Beach House|residential|beach_house|980000|modern|residential,luxury,available|waterfront,beach|6|5|5|buy,mortgage|all",
		"modern_penthouse|Penthouse|residential|penthouse|2400000|modern|residential,luxury,available|apartment,urban,skyline,luxury|5|6|5|buy,rent,mortgage|all",
		"modern_smart_home|Smart Home|residential|smart_home|780000|modern|residential,luxury,available|smart,suburban|5|4|5|buy,mortgage|all",
		"modern_eco_home|Eco Home|residential|eco_home|510000|modern|residential,available|eco,solar|4|3|3|buy,mortgage|all",
		"modern_cabin|Cabin|residential|cabin|210000|modern|residential,available|rural,forest|3|2|2|buy,rent,mortgage|all",
		"modern_castle|Castle|royal|castle|7800000|modern|residential,royal,luxury,available|fortified,historic,luxury|18|14|20|buy,mortgage|all",
		"modern_palace|Palace|royal|palace|28000000|modern|royal,government,luxury,available|royal,ceremonial,luxury|42|32|40|buy,government_grant|all",
		"modern_floating_house|Floating House|residential|floating_house|680000|modern|residential,luxury,available|waterfront,floating|4|3|2|buy,mortgage|all",
		"modern_underground_bunker|Underground Bunker|military|underground_bunker|1400000|modern|residential,military,luxury,available|underground,fortified,navigable|8|5|12|buy,mortgage|all",
		"modern_cave_dwelling|Cave Dwelling|residential|cave_dwelling|390000|modern|residential,available|cave,hidden,eco|3|2|2|buy,mortgage|all",
		"modern_tree_house|Tree House|residential|tree_house|270000|modern|residential,available|forest,elevated,eco|3|2|1|buy,mortgage|all",

		"modern_hotel|Hotel|commercial|hotel|4800000|modern|commercial,luxury,available|hotel,hospitality|80|90|24|buy,mortgage|all",
		"modern_motel|Motel|commercial|motel|1300000|modern|commercial,available|motel,hospitality|36|40|30|buy,mortgage|all",
		"modern_casino|Casino|commercial|casino|32000000|modern|commercial,luxury,available|casino,entertainment,luxury|120|80|120|buy,mortgage|all",
		"modern_office_building|Office Building|commercial|office_building|7200000|modern|commercial,available|office,urban|2|18|80|buy,rent,mortgage|all",
		"modern_warehouse|Warehouse|commercial|warehouse|2100000|modern|commercial,available|warehouse,industrial|0|4|60|buy,rent,mortgage|all",
		"modern_factory|Factory|commercial|factory|6800000|modern|commercial,available|factory,industrial|0|12|100|buy,mortgage|all",
		"modern_shopping_mall|Shopping Mall|commercial|shopping_mall|52000000|modern|commercial,luxury,available|retail,mall|0|80|400|buy,mortgage|all",
		"modern_hospital|Hospital|commercial|hospital|95000000|modern|commercial,government,available|medical,hospital|30|120|120|buy,institutional|all",
		"modern_pharmacy|Pharmacy|commercial|pharmacy|820000|modern|commercial,available|medical,retail|0|2|10|buy,rent,mortgage|all",
		"modern_car_wash|Car Wash|commercial|car_wash|620000|modern|commercial,available|automotive,service|0|2|20|buy,mortgage|all",
		"modern_grocery_store|Grocery Store|commercial|grocery_store|1800000|modern|commercial,available|retail,food|0|4|40|buy,rent,mortgage|all",
		"modern_gas_station|Gas Station|commercial|gas_station|950000|modern|commercial,available|automotive,fuel|0|2|18|buy,mortgage|all",
		"modern_cinema|Cinema|commercial|cinema|6400000|modern|commercial,available|entertainment,cinema|0|16|120|buy,mortgage|all",
		"modern_gym|Gym|commercial|gym|1200000|modern|commercial,available|fitness,service|0|8|30|buy,rent,mortgage|all",
		"modern_arcade|Arcade|commercial|arcade|780000|modern|commercial,available|entertainment,arcade|0|4|18|buy,rent,mortgage|all",
		"modern_farm|Farm|commercial|farm|1100000|modern|commercial,residential,available|farm,rural|4|3|12|buy,mortgage|all",
		"modern_airport_hangar|Airport Hangar|commercial|airport_hangar|3400000|modern|commercial,military,available|aircraft_storage,airport|0|4|18|buy,rent,mortgage|all",
		"modern_government_complex|Government Complex|government|government_complex|85000000|modern|government,available|government,secure|10|40|100|government_grant|all",
		"modern_military_base|Military Base|military|military_base|140000000|modern|military,government,available|military,fortified|80|60|240|government_grant|all",
		"modern_cathedral|Cathedral|religious|cathedral|18000000|modern|religious,luxury,available|religious,ceremonial|8|20|30|buy,institutional|all",

		"future_micro_pod|Micro Habitat Pod|residential|micro_habitat|140000|future|residential,rental,available|compact,smart|1|1|0|rent,mortgage|all",
		"future_sky_loft|Sky Loft|residential|sky_loft|520000|future|residential,luxury,available|elevated,smart,skyline|2|2|2|buy,rent,mortgage|all",
		"future_smart_habitat|Smart Habitat|residential|smart_habitat|880000|future|residential,luxury,available|smart,autonomous|4|4|5|buy,mortgage|all",
		"future_eco_arcology|Eco Arcology Unit|residential|eco_arcology|760000|future|residential,available|eco,arcology|4|3|3|buy,rent,mortgage|all",
		"future_floating_estate|Floating Estate|residential|floating_estate|6200000|future|residential,luxury,available|floating,luxury,smart|10|9|10|buy,mortgage|all",
		"future_orbital_penthouse|Orbital Penthouse|residential|orbital_penthouse|18000000|future|residential,luxury,available|space,orbital,luxury|8|8|8|buy,mortgage|all",
		"future_moon_base|Private Moon Base|military|moon_base|85000000|future|residential,military,luxury,available|space,fortified,offworld|24|18|30|buy,government_grant|all",
		"future_arcology_hotel|Arcology Hotel|commercial|arcology_hotel|120000000|future|commercial,luxury,available|hotel,arcology|200|240|160|buy,mortgage|all",
		"future_orbital_hangar|Orbital Hangar|commercial|orbital_hangar|220000000|future|commercial,military,luxury,available|space,aircraft_storage|0|24|80|buy,government_grant|all",

		"fantasy_fire_palace|Fire Kingdom Palace|royal|fire_kingdom_palace|9000000|ancient,medieval,industrial,modern,future|royal,fantasy,luxury,available|fire,palace,volcanic|24|18|24|buy,government_grant|chaos,fantasy",
		"fantasy_earth_fortress|Earth Fortress|military|earth_fortress|7200000|ancient,medieval,industrial,modern,future|military,royal,fantasy,luxury,available|earth,fortified,stone|18|10|30|buy,government_grant|chaos,fantasy",
		"fantasy_air_temple|Floating Air Temple|religious|floating_air_temple|8500000|ancient,medieval,industrial,modern,future|religious,fantasy,luxury,available|air,floating,temple|20|12|16|institutional,government_grant|chaos,fantasy",
		"fantasy_water_harbor|Water Tribe Harbor Estate|royal|water_tribe_harbor|6800000|ancient,medieval,industrial,modern,future|residential,royal,fantasy,luxury,available|water,harbor,ice|16|14|30|buy,government_grant|chaos,fantasy",
		"fantasy_dragon_sanctuary|Dragon Sanctuary|religious|dragon_sanctuary|12000000|ancient,medieval,industrial,modern,future|religious,fantasy,luxury,available|dragon,mountain,sanctuary|10|8|40|buy,institutional|chaos,fantasy",
		"fantasy_wizard_tower|Wizard Tower|residential|wizard_tower|3400000|ancient,medieval,industrial,modern,future|residential,fantasy,luxury,available|wizard,tower,arcane|8|6|6|buy,mortgage|chaos,fantasy",
		"fantasy_sky_castle|Sky Castle|royal|sky_castle|22000000|ancient,medieval,industrial,modern,future|royal,fantasy,luxury,available|air,floating,castle|32|24|30|buy,government_grant|chaos,fantasy",
		"fantasy_spirit_shrine|Spirit Shrine|religious|spirit_shrine|1600000|ancient,medieval,industrial,modern,future|religious,fantasy,available|spirit,shrine,hidden|4|2|2|institutional,buy|chaos,fantasy",
		"fantasy_crystal_cavern|Crystal Cavern Estate|residential|crystal_cavern_estate|5200000|ancient,medieval,industrial,modern,future|residential,fantasy,luxury,available|earth,crystal,cavern|12|9|12|buy,mortgage|chaos,fantasy"
	]


func _dealership_from_row(row: String) -> Dictionary:
	var parts: PackedStringArray = row.split("|", false)

	return {
		"schema": "eralife.market.dealership_selector_contract",
		"version": CONTRACT_VERSION,
		"dealership_id": _part(parts, 0),
		"name": _part(parts, 1),
		"category_label": _part(parts, 2),
		"icon": _part(parts, 3),
		"era_keys": _csv(_part(parts, 4)),
		"inventory_tags": _csv(_part(parts, 5)),
		"reality_modes": _csv(_part(parts, 6)),
		"display_order": int(_part(parts, 7, "0")),
		"accent_color": Color.from_string(
			"#%s" % _part(parts, 8, "4A90E2"),
			Color(0.3, 0.6, 1.0)
		),
		"bloom_color": Color.from_string(
			"#%s" % _part(parts, 9, "64B5F6"),
			Color(0.4, 0.7, 1.0)
		),
		"description": "%s mobility inventory resolved for the current era." % _part(
			parts,
			2
		),
		"ui_is_renderer_only": true
	}


func _vehicle_from_row(
	row: String
) -> Dictionary:
	var parts: PackedStringArray = row.split(
		"|",
		false
	)
	var tags: Array = _csv(
		_part(
			parts,
			11
		)
	)
	var reality_modes: Array = _csv(
		_part(
			parts,
			15,
			"all"
		)
	)
	var living_transport: bool = (
		_part(
			parts,
			13,
			"false"
		) == "true"
	)
	var species_id: String = _part(
		parts,
		14
	)
	var base_value: int = int(
		_part(
			parts,
			10,
			"1"
		)
	)
	var category: String = _part(
		parts,
		3
	)
	var seats: int = int(
		_part(
			parts,
			5,
			"1"
		)
	)
	var color_name: String = _part(
		parts,
		16,
		"Factory Finish"
	)
	var color_hex: String = _part(
		parts,
		17,
		"7A8494"
	).trim_prefix("#")
	var value_band: String = "entry"

	if base_value >= 1000000:
		value_band = "ultra_luxury"
	elif base_value >= 150000:
		value_band = "luxury"
	elif base_value >= 50000:
		value_band = "premium"

	var mythical_species: bool = (
		reality_modes.has("fantasy")
		or reality_modes.has("chaos")
	)
	var restricted_vehicle: bool = (
		tags.has("restricted")
		or tags.has("military_clearance")
		or tags.has("tank")
		or tags.has("missile_platform")
	)
	var requires_bunker: bool = (
		tags.has("bunker_storage_required")
		or tags.has("tank")
	)
	var requirement_tags: Array = []

	if restricted_vehicle:
		requirement_tags.append(
			"strategic_military_vehicle_clearance"
		)

	if requires_bunker:
		requirement_tags.append(
			"underground_bunker_storage"
		)

	var action_ids: Array = (
		_default_vehicle_action_ids(
			tags,
			category,
			seats,
			base_value,
			living_transport
		)
	)

	return {
		"template_id": _part(parts, 0),
		"asset_kind": "transport",
		"brand": _part(parts, 1),
		"model": _part(parts, 2),
		"display_name": "%s %s" % [
			_part(parts, 1),
			_part(parts, 2)
		],
		"legacy_type": _part(parts, 2),
		"category": category,
		"archetype": category,
		"subtype": category,
		"movement_type": _part(parts, 4),
		"seats": seats,
		"era_keys": _csv(
			_part(
				parts,
				6
			)
		),
		"era_tags": _csv(
			_part(
				parts,
				6
			)
		),
		"terrain": _csv(
			_part(
				parts,
				7
			)
		),
		"fuel": _part(parts, 8),
		"monthly_cost": int(
			_part(
				parts,
				9,
				"0"
			)
		),
		"base_value": base_value,
		"filter_tags": tags.duplicate(true),
		"feature_tags": tags.duplicate(true),
		"portfolio_tags": [
			"expanded_asset_catalog"
		],
		"dealership_ids": _csv(
			_part(
				parts,
				12
			)
		),
		"living_transport": living_transport,
		"condition_applicable": not living_transport,
		"animal_species_id": (
			""
			if mythical_species
			else species_id
		),
		"mythical_species_id": (
			species_id
			if mythical_species
			else ""
		),
		"reality_modes": reality_modes,
		"availability": "available",
		"ownership_status": "available",
		"social_tier": (
			"ultra_luxury"
			if value_band == "ultra_luxury"
			else "wealthy"
			if value_band == "luxury"
			else "respectable"
			if value_band == "premium"
			else "working_class"
		),
		"value_band": value_band,
		"rarity": (
			1.0
			+ minf(
				1.5,
				float(base_value)
				/ 50000000.0
			)
		),
		"color_name": color_name,
		"color_hex": color_hex,
		"color_visual_contract": {
			"name": color_name,
			"hex": color_hex,
			"swatch_visible": true,
			"ui_is_renderer_only": true
		},
		"restricted_vehicle": restricted_vehicle,
		"weapon_platform": (
			tags.has("missile_platform")
			or tags.has("weapon_platform")
		),
		"requires_underground_bunker": requires_bunker,
		"storage_requirement": (
			"underground_bunker"
			if requires_bunker
			else "standard_vehicle_storage"
		),
		"upkeep_profile": {
			"maintenance_intensity": (
				0.0
				if living_transport
				else 1.0
				+ minf(
					1.4,
					float(base_value)
					/ 5000000.0
				)
			)
		},
		"requirement_tags": requirement_tags,
		"operational_profile": {
			"movement_type": _part(parts, 4),
			"passenger_capacity": seats,
			"terrain": _csv(
				_part(
					parts,
					7
				)
			),
			"fuel": _part(parts, 8),
			"monthly_cost": int(
				_part(
					parts,
					9,
					"0"
				)
			),
			"cargo_capacity": (
				12
				if tags.has("truck")
				else 6
				if tags.has("yacht")
				else 1
			),
			"speed_class": (
				7
				if tags.has("hypercar")
				else 5
				if tags.has("sports")
				else 3
			),
			"travel_range": (
				10
				if tags.has("yacht")
				or tags.has("spaceship")
				else 4
			),
			"weapon_platform": (
				tags.has("missile_platform")
				or tags.has("weapon_platform")
			)
		},
		"passive_modifiers": {},
		"event_hooks": [],
		"action_ids": action_ids,
		"prestige_signals": {
			"class_respect": (
				1.0
				if value_band == "entry"
				else 2.0
				if value_band == "premium"
				else 4.0
			)
		},
		"pricing_rules": {},
		"default_condition": 100.0
	}
func _default_vehicle_action_ids(
	tags: Array,
	category: String,
	seats: int,
	base_value: int,
	living_transport: bool
) -> Array:
	var actions: Array = [
		"inspect",
		"rename",
		"sell",
		"gift",
		"use"
	]

	if not living_transport:
		actions.append("maintain")
		actions.append("repair")

	var watercraft: bool = (
		tags.has("watercraft")
		or tags.has("yacht")
		or category in [
			"canoe",
			"fishing_boat",
			"speedboat",
			"yacht",
			"superyacht",
			"mega_yacht",
			"casino_yacht",
			"ship",
			"ferry",
			"submersible_yacht"
		]
	)

	if watercraft:
		actions.append("cruise")
		actions.append("go_fishing")

		if seats >= 10:
			actions.append(
				"host_boat_gathering"
			)

		if (
			seats >= 18
			or base_value >= 1000000
		):
			actions.append(
				"host_yacht_party"
			)

		if (
			tags.has("casino")
			or category == "casino_yacht"
		):
			actions.append(
				"operate_casino_night"
			)

	if (
		tags.has("tank")
		or tags.has("missile_platform")
	):
		actions.append(
			"launch_missiles"
		)

	return actions
func _expanded_vehicle_rows() -> Array:
	return [

		"industrial_ford_model_a|Ford|Model A|sedan|combustion|5|industrial|road,city|gasoline|42|12000|car,sedan,economy,historic|industrial_workers_motors,industrial_mass_motors|false||all|Washington Blue|1D3E67",
		"industrial_cadillac_type_51|Cadillac|Type 51|luxury_sedan|combustion|5|industrial|road,city|gasoline|95|42000|car,sedan,luxury,historic|industrial_continental_motors,industrial_grand_touring|false||all|Deep Maroon|641E2A",
		"industrial_packard_twin_six|Packard|Twin Six|luxury_sedan|combustion|7|industrial|road,city|gasoline|115|58000|car,sedan,luxury,historic|industrial_grand_touring|false||all|Coach Green|214C38",
		"industrial_duesenberg_model_j|Duesenberg|Model J|luxury_sedan|combustion|5|industrial|road,city|gasoline|180|125000|car,sedan,luxury,collector|industrial_elite_coachworks,industrial_grand_touring|false||all|Midnight Black|111318",
		"industrial_mack_ac|Mack|AC Bulldog Truck|cargo_truck|combustion|2|industrial|road,worksite|gasoline|120|28000|truck,commercial,utility|industrial_workers_motors,industrial_heavy_mobility|false||all|Foundry Red|8A2F26",
		"industrial_pierce_arrow_48|Pierce-Arrow|Model 48|grand_tourer|combustion|7|industrial|road,city|gasoline|145|88000|car,luxury,collector|industrial_grand_touring|false||all|Ivory Cream|E6D8B8",
		"industrial_steam_launch|Empire Marine|Private Steam Launch|boat|steam|10|industrial|river,coast,lake|coal|260|68000|watercraft,water,luxury|industrial_aero_marine|false||all|Brass Navy|173B5E",
		"industrial_ocean_liner|Continental Marine|Grand Ocean Liner|ship|steam|850|industrial|sea,ocean|coal|22000|12000000|watercraft,water,luxury,commercial|industrial_aero_marine|false||all|Atlantic Black|1B232C",
		"industrial_landship|Continental Heavy Works|Armored Landship|tank|tracked|10|industrial|road,field,battlefield|diesel|3800|780000|tank,military,restricted,military_clearance,bunker_storage_required,weapon_platform|industrial_heavy_mobility|false||all|Field Olive|4C5635",


		"modern_toyota_camry|Toyota|Camry|sedan|combustion|5|modern|road,city|gasoline|210|32000|car,sedan,economy|modern_affordable,modern_regular|false||all|Celestial Silver|AAB0B5",
		"modern_honda_civic_type_r|Honda|Civic Type R|sports_hatchback|combustion|4|modern|road,track|gasoline|360|49000|car,hatchback,sports,premium|modern_regular|false||all|Championship White|F2F1E9",
		"modern_honda_odyssey|Honda|Odyssey|minivan|combustion|8|modern|road,city|gasoline|310|44000|car,minivan,family|modern_affordable,modern_regular|false||all|Modern Steel|555B61",
		"modern_smart_fortwo|Smart|Fortwo|compact|combustion|2|modern|road,city|gasoline|110|18000|car,compact,economy|modern_affordable|false||all|Electric Orange|E66B2D",
		"modern_chevrolet_malibu|Chevrolet|Malibu|sedan|combustion|5|modern|road,city|gasoline|205|29000|car,sedan,economy|modern_affordable,modern_regular|false||all|Summit White|E9ECEE",
		"modern_nissan_altima|Nissan|Altima|sedan|combustion|5|modern|road,city|gasoline|205|30000|car,sedan,economy|modern_affordable,modern_regular|false||all|Gun Metallic|4F5358",
		"modern_subaru_outback|Subaru|Outback|wagon|combustion|5|modern|road,trail|gasoline|270|39000|car,wagon,utility|modern_regular|false||all|Autumn Green|485D48",
		"modern_toyota_rav4|Toyota|RAV4|suv|hybrid|5|modern|road,trail|hybrid|260|39000|suv,family,hybrid|modern_regular|false||all|Lunar Rock|788179",
		"modern_honda_crv|Honda|CR-V|suv|hybrid|5|modern|road,trail|hybrid|255|38000|suv,family,hybrid|modern_regular|false||all|Canyon River Blue|3A5C70",
		"modern_jeep_wrangler|Jeep|Wrangler Rubicon|suv|combustion|5|modern|road,trail,offroad|gasoline|390|59000|suv,utility,offroad|modern_regular|false||all|Sarge Green|4B563A",


		"modern_ram_1500|Ram|1500 Limited|pickup|combustion|5|modern|road,trail,worksite|gasoline|520|76000|truck,pickup,utility,premium|modern_truck_center,modern_regular|false||all|Diamond Black|15181C",
		"modern_ram_2500|Ram|2500 Power Wagon|heavy_pickup|combustion|5|modern|road,trail,worksite|diesel|690|92000|truck,pickup,utility,commercial|modern_truck_center,modern_fleet|false||all|Patriot Blue|153D66",
		"modern_ram_trx|Ram|1500 TRX|performance_pickup|combustion|5|modern|road,trail,offroad|gasoline|780|118000|truck,pickup,sports,luxury|modern_truck_center,modern_luxury|false||all|Flame Red|A72624",
		"modern_ford_f150|Ford|F-150 Lariat|pickup|combustion|5|modern|road,trail,worksite|gasoline|480|69000|truck,pickup,utility|modern_truck_center,modern_regular|false||all|Antimatter Blue|10293C",
		"modern_ford_f150_raptor|Ford|F-150 Raptor|performance_pickup|combustion|5|modern|road,trail,offroad|gasoline|720|112000|truck,pickup,sports,offroad|modern_truck_center,modern_luxury|false||all|Code Orange|D85D28",
		"modern_ford_f150_lightning|Ford|F-150 Lightning|electric_pickup|electric|5|modern|road,trail,worksite|electric|420|82000|truck,pickup,electric,utility|modern_truck_center,modern_regular|false||all|Atlas Blue|215C94",


		"modern_chrysler_300|Chrysler|300C|luxury_sedan|combustion|5|modern|road,city|gasoline|420|57000|car,sedan,luxury|modern_regular,modern_cadillac_custom|false||all|Gloss Black|101113",
		"modern_cadillac_ct4|Cadillac|CT4-V Blackwing|sports_sedan|combustion|5|modern|road,track|gasoline|590|78000|car,sedan,sports,luxury,cadillac|modern_luxury,modern_cadillac_custom|false||all|Electric Blue|2057A7",
		"modern_cadillac_ct5|Cadillac|CT5-V Blackwing|sports_sedan|combustion|5|modern|road,track|gasoline|720|118000|car,sedan,sports,luxury,cadillac|modern_luxury,modern_cadillac_custom|false||all|Black Raven|121317",
		"modern_cadillac_escalade|Cadillac|Escalade-V|luxury_suv|combustion|7|modern|road,city,trail|gasoline|850|165000|suv,luxury,cadillac|modern_luxury,modern_cadillac_custom|false||all|Crystal White|EAE9E3",
		"modern_cadillac_deville_lowrider|Cadillac|DeVille Lowrider|custom_sedan|combustion|6|modern|road,city,show|gasoline|420|88000|car,sedan,luxury,cadillac,lowrider,custom|modern_cadillac_custom|false||all|Candy Apple Red|A11629",
		"modern_cadillac_eldorado_lowrider|Cadillac|Eldorado Lowrider|custom_coupe|combustion|5|modern|road,city,show|gasoline|450|96000|car,coupe,luxury,cadillac,lowrider,custom|modern_cadillac_custom|false||all|Royal Purple|5A267B",


		"modern_tesla_model_3|Tesla|Model 3 Performance|sports_sedan|electric|5|modern|road,city,track|electric|310|58000|car,sedan,electric,sports|modern_regular,modern_luxury|false||all|Ultra Red|A51E28",
		"modern_tesla_model_y|Tesla|Model Y Performance|electric_suv|electric|5|modern|road,city,trail|electric|330|65000|suv,electric,family|modern_regular,modern_luxury|false||all|Quicksilver|A3A7A8",
		"modern_tesla_model_s|Tesla|Model S Plaid|luxury_sedan|electric|5|modern|road,city,track|electric|480|110000|car,sedan,electric,luxury,sports|modern_luxury|false||all|Deep Blue Metallic|203A63",
		"modern_tesla_model_x|Tesla|Model X Plaid|luxury_suv|electric|7|modern|road,city,trail|electric|510|122000|suv,electric,luxury|modern_luxury|false||all|Pearl White|E9EAE7",
		"modern_tesla_roadster|Tesla|Roadster|electric_supercar|electric|2|modern|road,track|electric|760|260000|car,electric,supercar,luxury|modern_ultra_luxury|false||all|Founders Red|9F1C27",


		"modern_mercedes_g550|Mercedes-Benz|G 550|luxury_suv|combustion|5|modern|road,trail,offroad|gasoline|980|165000|suv,luxury,offroad|modern_luxury|false||all|Obsidian Black|111416",
		"modern_mercedes_g63|Mercedes-AMG|G 63|performance_suv|combustion|5|modern|road,trail,offroad|gasoline|1250|235000|suv,luxury,sports,offroad|modern_luxury,modern_ultra_luxury|false||all|Magno Olive|42483B",
		"modern_range_rover_evoque|Range Rover|Evoque|luxury_suv|combustion|5|modern|road,trail|gasoline|520|72000|suv,luxury|modern_regular,modern_luxury|false||all|Seoul Pearl Silver|A2A5A4",
		"modern_range_rover_sport|Range Rover|Sport SV|performance_suv|combustion|5|modern|road,trail,track|gasoline|980|145000|suv,luxury,sports|modern_luxury|false||all|Firenze Red|8D2028",
		"modern_range_rover_autobiography|Range Rover|Autobiography|luxury_suv|combustion|5|modern|road,trail|gasoline|1150|195000|suv,luxury,ultra_luxury|modern_luxury,modern_ultra_luxury|false||all|British Racing Green|173D2D",
		"modern_range_rover_velar|Range Rover|Velar|luxury_suv|combustion|5|modern|road,trail|gasoline|610|89000|suv,luxury|modern_luxury|false||all|Varesine Blue|335878",


		"modern_bugatti_veyron|Bugatti|Veyron Super Sport|hypercar|combustion|2|modern|road,track|gasoline|5200|3200000|car,hypercar,luxury,collector|modern_ultra_luxury|false||all|Black Carbon Orange|281A16",
		"modern_bugatti_chiron|Bugatti|Chiron Super Sport|hypercar|combustion|2|modern|road,track|gasoline|6200|4200000|car,hypercar,luxury,collector|modern_ultra_luxury|false||all|French Racing Blue|1E5FA5",
		"modern_bugatti_divo|Bugatti|Divo|hypercar|combustion|2|modern|road,track|gasoline|6800|5800000|car,hypercar,luxury,collector|modern_ultra_luxury|false||all|Divo Silver Blue|566D82",
		"modern_bugatti_bolide|Bugatti|Bolide|track_hypercar|combustion|2|modern|track|gasoline|7500|6400000|car,hypercar,luxury,collector,track|modern_ultra_luxury|false||all|Black French Blue|172637",
		"modern_bugatti_mistral|Bugatti|W16 Mistral|hyper_roadster|combustion|2|modern|road,track|gasoline|7100|5900000|car,hypercar,luxury,collector|modern_ultra_luxury|false||all|Mistral Yellow|D6A529",
		"modern_bugatti_tourbillon|Bugatti|Tourbillon|hybrid_hypercar|hybrid|2|modern|road,track|hybrid|7900|4800000|car,hypercar,hybrid,luxury,collector|modern_ultra_luxury|false||all|Tourbillon Blue|18456C",


		"modern_center_console_boat|Harborline|Offshore Fishing Center Console|fishing_boat|motor|8|modern|coast,sea,ocean|gasoline|620|145000|watercraft,water,fishing,sports|modern_marine|false||all|Ocean White|E3EDF0",
		"modern_expedition_yacht|Crown Harbor|Expedition Yacht|yacht|motor|24|modern|coast,sea,ocean|diesel|6500|4200000|watercraft,water,yacht,luxury,expedition|modern_superyacht_broker,modern_marine|false||all|Arctic White|E7EBEA",
		"modern_superyacht|Crown Harbor|Superyacht|superyacht|motor|42|modern|sea,ocean|diesel|18000|42000000|watercraft,water,yacht,superyacht,luxury|modern_superyacht_broker|false||all|Pearl White Navy|E8E7E0",
		"modern_mega_yacht|Crown Harbor|Megayacht|mega_yacht|motor|85|modern|sea,ocean|diesel|42000|160000000|watercraft,water,yacht,superyacht,mega_yacht,luxury|modern_superyacht_broker|false||all|Midnight Hull|17212B",
		"modern_casino_yacht|Crown Harbor|Casino Yacht|casino_yacht|motor|240|modern|sea,ocean|diesel|68000|280000000|watercraft,water,yacht,casino,mega_yacht,luxury,commercial|modern_superyacht_broker|false||all|Royal Gold White|E6D5A5",


		"modern_aegis_missile_tank|Aegis Defense|Strategic Missile Tank|tank|tracked|4|modern|road,field,battlefield|diesel|28000|18000000|tank,military,restricted,military_clearance,bunker_storage_required,weapon_platform,missile_platform|modern_defense_mobility|false||all|Military Olive|4B563A",
		"modern_titan_heavy_tank|Titan Defense|Heavy Battle Tank|tank|tracked|4|modern|road,field,battlefield|diesel|24000|12500000|tank,military,restricted,military_clearance,bunker_storage_required,weapon_platform|modern_defense_mobility|false||all|NATO Green|46503A",


		"future_delorean_dmc12|DMC|DeLorean DMC-12 Temporal Edition|retro_future_coupe|hover_conversion|2|future|road,air,city|fusion_cell|480|185000|car,coupe,retro_future,hover,collector|future_retro_future,future_regular|false||all|Stainless Steel|A7AAAB",
		"future_hover_sedan|Nova|Aurora Hover Sedan|hover_sedan|anti_gravity|5|future|road,air,city|electric|310|88000|car,sedan,hover|future_civic,future_hover_gallery|false||all|Aurora Cyan|32BBD3",
		"future_hover_coupe|Aetheris|Rift Hover Coupe|hover_coupe|anti_gravity|2|future|road,air,city|electric|520|165000|car,coupe,hover,sports|future_regular,future_hover_gallery|false||all|Ion Violet|6746A7",
		"future_hover_suv|Aetheris|Atlas Hover SUV|hover_suv|anti_gravity|7|future|road,air,trail|electric|610|195000|suv,hover,luxury|future_regular,future_hover_gallery|false||all|Nebula Gray|59636E",
		"future_hover_minivan|Nova|Family Halo Hovervan|hover_minivan|anti_gravity|9|future|road,air,city|electric|390|112000|car,minivan,hover,family|future_civic,future_hover_gallery|false||all|Solar Pearl|E7E1C7",
		"future_hover_pickup|Titan|GravHaul Hover Pickup|hover_pickup|anti_gravity|5|future|road,air,worksite|fusion_cell|580|175000|truck,hover,utility|future_fleet,future_hover_gallery|false||all|Titan Bronze|7A5736",
		"future_autonomous_pod|Nova|City Autonomous Pod|mobility_pod|autonomous|4|future|road,city|electric|140|42000|car,economy,autonomous|future_civic|false||all|Transit Teal|2B7F82",
		"future_sky_limo|Celestial|Crown Sky Limousine|hover_limo|anti_gravity|10|future|road,air,city|fusion_cell|1100|680000|car,luxury,hover,limousine|future_luxury,future_hover_gallery|false||all|Crown Black Gold|1A1713",
		"future_quantum_roadster|Celestial|Quantum Roadster|hypercar|quantum_drive|2|future|road,air,track|quantum_cell|2200|4800000|car,hypercar,luxury,hover|future_luxury|false||all|Quantum Magenta|8B2E86",
		"future_orbital_rover|Titan|Orbital Surface Rover|space_rover|fusion|8|future|road,moon,mars,space|fusion_cell|1900|2400000|utility,space,rover|future_fleet,future_aerospace|false||all|Lunar White|C7CAC6",


		"future_hydrofoil_yacht|Pelagic|Aerofoil Yacht|yacht|hydrofoil|20|future|coast,sea,ocean|fusion_cell|4200|3500000|watercraft,water,yacht,luxury|future_marine,future_superyacht_broker|false||all|Pelagic Blue|176F9C",
		"future_submersible_yacht|Pelagic|Abyss Submersible Yacht|submersible_yacht|submersible|30|future|sea,ocean,deep_ocean|fusion_cell|9800|22000000|watercraft,water,yacht,submersible,luxury|future_marine,future_superyacht_broker|false||all|Abyssal Black|101B26",
		"future_mega_yacht|Pelagic Crown|Levitation Megayacht|mega_yacht|anti_gravity_hydro|110|future|sea,ocean,air|fusion_cell|38000|240000000|watercraft,water,yacht,mega_yacht,hover,luxury|future_superyacht_broker|false||all|Celestial Pearl|DDE6E7",
		"future_casino_yacht|Pelagic Crown|Orbital Casino Yacht|casino_yacht|anti_gravity_hydro|300|future|sea,ocean,air|fusion_cell|76000|420000000|watercraft,water,yacht,casino,mega_yacht,luxury,commercial|future_superyacht_broker|false||all|Casino Gold|C9A14A",


		"future_aegis_hover_tank|Aegis Defense|Hover Missile Tank|hover_tank|anti_gravity|4|future|road,air,field,battlefield|fusion_cell|36000|38000000|tank,hover,military,restricted,military_clearance,bunker_storage_required,weapon_platform,missile_platform|future_defense_mobility|false||all|Stealth Graphite|2C3437",
		"future_titan_siege_tank|Titan Defense|Siege Tank|tank|grav_track|6|future|road,field,battlefield,moon|fusion_cell|52000|62000000|tank,military,restricted,military_clearance,bunker_storage_required,weapon_platform,missile_platform|future_defense_mobility|false||all|Siege Gunmetal|3A4448"
	]
func _expanded_property_rows() -> Array:
	return [

		"industrial_worker_flat|Factory Worker Flat|residential|worker_flat|12000|industrial|residential,rental,available|brick,urban,working_class|2|1|0|rent|all",
		"industrial_brownstone|Brownstone Townhouse|residential|brownstone|95000|industrial|residential,available|brick,urban,wealthy|4|2|2|buy,rent,mortgage|all",
		"industrial_motor_estate|Early Motor Estate|residential|motor_estate|420000|industrial|residential,luxury,available|estate,motor_house,collector|8|4|12|buy,mortgage|all",
		"industrial_shipyard|Private Shipyard|commercial|shipyard|820000|industrial|commercial,waterfront,available|shipyard,harbor,industrial|0|4|30|buy,mortgage|all",
		"industrial_private_rail_estate|Private Rail Estate|residential|rail_estate|1600000|industrial|residential,luxury,available|estate,rail,collector|14|7|22|buy,mortgage|all",


		"modern_starter_bungalow|Starter Bungalow|residential|bungalow|165000|modern|residential,available|suburban,starter,compact|2|1|1|buy,rent,mortgage|all",
		"modern_suburban_ranch|Suburban Ranch House|residential|ranch_house|320000|modern|residential,available|suburban,family,garage|3|2|2|buy,mortgage|all",
		"modern_duplex|Duplex|residential|duplex|460000|modern|residential,rental,available|urban,rental,multi_unit|6|4|4|buy,mortgage|all",
		"modern_townhouse|Modern Townhouse|residential|townhouse|380000|modern|residential,available|urban,family,garage|3|3|2|buy,rent,mortgage|all",
		"modern_luxury_penthouse|Luxury Penthouse|residential|penthouse|4200000|modern|residential,luxury,available|penthouse,urban,skyline|5|7|6|buy,mortgage|all",
		"modern_gated_mansion|Gated Mansion|residential|modern_mansion|7800000|modern|residential,luxury,available|mansion,gated,pool,estate|12|14|18|buy,mortgage|all",
		"modern_collector_compound|Automotive Collector Compound|residential|collector_compound|12500000|modern|residential,luxury,available|collector,garage,vehicle_vault|8|10|60|buy,mortgage|all",
		"modern_supercar_vault_estate|Supercar Vault Estate|residential|supercar_vault_estate|28000000|modern|residential,luxury,available|mansion,vehicle_vault,underground_garage|14|18|120|buy,mortgage|all",
		"modern_bunker_complex|Strategic Underground Bunker Complex|military|underground_bunker|8500000|modern|residential,military,luxury,available|underground_bunker,fortified,vehicle_bunker,military_storage|18|12|40|buy,government_grant|all",
		"modern_marina_villa|Private Marina Villa|residential|marina_villa|6200000|modern|residential,luxury,waterfront,available|villa,marina,yacht_dock|10|12|16|buy,mortgage|all",
		"modern_private_island_estate|Private Island Estate|residential|private_island|42000000|modern|residential,luxury,waterfront,available|island,marina,airstrip,estate|24|30|40|buy,mortgage|all",
		"modern_yacht_club|Private Yacht Club|commercial|yacht_club|18000000|modern|commercial,luxury,waterfront,available|marina,yacht_dock,hospitality|8|16|80|buy,mortgage|all",
		"modern_air_hangar_estate|Private Aviation Estate|residential|aviation_estate|24000000|modern|residential,luxury,available|hangar,airstrip,mansion|12|16|30|buy,mortgage|all",
		"modern_defense_motor_pool|Restricted Defense Motor Pool|military|defense_motor_pool|38000000|modern|military,government,available|fortified,underground_bunker,military_storage,vehicle_bunker|4|8|180|government_grant|all",


		"future_smart_habitat_pod|Smart Habitat Pod|residential|smart_pod|140000|future|residential,available|smart_home,compact,modular|1|1|1|buy,rent,mortgage|all",
		"future_hover_garage_townhouse|Hover-Garage Townhouse|residential|hover_townhouse|680000|future|residential,available|hover_garage,smart_home,urban|4|4|6|buy,mortgage|all",
		"future_vertical_villa|Vertical Sky Villa|residential|vertical_villa|4200000|future|residential,luxury,available|skyline,hover_dock,smart_home|7|9|12|buy,mortgage|all",
		"future_arcology_penthouse|Arcology Crown Penthouse|residential|arcology_penthouse|15000000|future|residential,luxury,available|arcology,skyline,hover_dock|10|14|24|buy,mortgage|all",
		"future_orbital_residence|Orbital Ring Residence|residential|orbital_residence|68000000|future|residential,luxury,space,available|orbital,space_dock,zero_gravity|14|18|30|buy,mortgage|all",
		"future_lunar_estate|Lunar Crater Estate|residential|lunar_estate|88000000|future|residential,luxury,space,available|lunar,pressurized,rover_hangar|18|20|50|buy,mortgage|all",
		"future_underwater_habitat|Abyssal Habitat Estate|residential|underwater_habitat|42000000|future|residential,luxury,waterfront,available|underwater,submersible_dock,pressurized|16|20|36|buy,mortgage|all",
		"future_quantum_vault_estate|Quantum Vault Estate|residential|quantum_vault_estate|120000000|future|residential,luxury,available|quantum_vault,hover_hangar,fortified|20|24|120|buy,mortgage|all",
		"future_strategic_bunker|Future Strategic Bunker|military|underground_bunker|95000000|future|residential,military,luxury,available|underground_bunker,fortified,vehicle_bunker,military_storage|24|18|160|buy,government_grant|all",
		"future_starship_hangar|Private Starship Hangar|commercial|starship_hangar|180000000|future|commercial,luxury,space,available|hangar,space_dock,orbital_logistics|4|12|240|buy,government_grant|all"
	]

func _property_from_row(row: String) -> Dictionary:
	var parts: PackedStringArray = row.split("|", false)
	var base_value: int = int(_part(parts, 4, "1"))
	var category: String = _part(parts, 2)
	var filter_tags: Array = _csv(_part(parts, 6))
	var feature_tags: Array = _csv(_part(parts, 7))
	var ownership_modes: Array = _csv(_part(parts, 11))
	var value_band: String = "entry"

	if base_value >= 10000000:
		value_band = "ultra_luxury"
	elif base_value >= 1000000:
		value_band = "luxury"
	elif base_value >= 350000:
		value_band = "premium"

	if not filter_tags.has(category):
		filter_tags.append(category)

	if (
		value_band in ["luxury", "ultra_luxury"]
		and not filter_tags.has("luxury")
	):
		filter_tags.append("luxury")

	if (
		ownership_modes.has("rent")
		and not filter_tags.has("rental")
	):
		filter_tags.append("rental")

	return {
		"template_id": _part(parts, 0),
		"asset_kind": "property",
		"display_name": _part(parts, 1),
		"legacy_type": _part(parts, 1),
		"category": category,
		"archetype": category,
		"subtype": _part(parts, 3),
		"base_value": base_value,
		"size": _property_size_from_value(base_value),
		"era_keys": _csv(_part(parts, 5)),
		"era_tags": _csv(_part(parts, 5)),
		"filter_tags": filter_tags,
		"feature_tags": feature_tags,
		"portfolio_tags": ["expanded_asset_catalog"],
		"requirement_tags": [],
		"ownership_modes": ownership_modes,
		"ownership_status": "available",
		"availability": "available",
		"reality_modes": _csv(
			_part(parts, 12, "all")
		),
		"social_tier": (
			"ultra_luxury"
			if value_band == "ultra_luxury"
			else "wealthy"
			if value_band == "luxury"
			else "respectable"
			if value_band == "premium"
			else "working_class"
		),
		"value_band": value_band,
		"rarity": (
			1.0
			+ minf(
				1.2,
				float(base_value) / 100000000.0
			)
		),
		"upkeep_profile": {
			"maintenance_intensity": (
				1.0
				+ minf(
					1.8,
					float(base_value) / 50000000.0
				)
			)
		},
		"operational_profile": {
			"bedrooms": int(_part(parts, 8, "0")),
			"bathrooms": int(_part(parts, 9, "0")),
			"family_capacity": maxi(
				1,
				int(_part(parts, 8, "0")) * 2
			),
			"comfort": (
				1
				if value_band == "entry"
				else 3
				if value_band == "premium"
				else 5
			),
			"storage_pressure": maxi(
				1,
				int(_part(parts, 10, "0"))
			),
			"vehicle_storage_capacity": int(
				_part(parts, 10, "0")
			)
		},
		"vehicle_storage_capacity": int(
			_part(parts, 10, "0")
		),
		"passive_modifiers": {},
		"event_hooks": [],
		"action_ids": [
			"inspect",
			"rename",
			"sell",
			"gift",
			"maintain",
			"repair",
			"rest"
		],
		"prestige_signals": {
			"class_respect": (
				1.0
				if value_band == "entry"
				else 2.5
				if value_band == "premium"
				else 5.0
			)
		},
		"pricing_rules": {},
		"default_condition": 100.0
	}


func _allows_era(
	contract: Dictionary,
	era_key: String
) -> bool:
	var eras: Array = _safe_array(
		contract.get("era_keys", ["all"])
	)

	return eras.has("all") or eras.has(era_key)


func _allows_reality(
	contract: Dictionary,
	reality_key: String
) -> bool:
	var modes: Array = _safe_array(
		contract.get("reality_modes", ["all"])
	)

	if modes.has("all") or modes.has(reality_key):
		return true

	return (
		reality_key == "chaos"
		and modes.has("fantasy")
	)


func _filter(
	filter_id: String,
	label: String,
	icon: String,
	match_tags: Array
) -> Dictionary:
	return {
		"filter_id": filter_id,
		"label": label,
		"icon": icon,
		"match_tags": match_tags.duplicate(true),
		"ui_is_renderer_only": true
	}


func _current_era_key() -> String:
	var era_text: String = "modern"

	if gs != null and gs.era != null:
		era_text = str(
			gs.era.name
		).strip_edges().to_lower()

	if era_text.find("ancient") >= 0:
		return "ancient"

	if era_text.find("medieval") >= 0:
		return "medieval"

	if era_text.find("industrial") >= 0:
		return "industrial"

	if era_text.find("future") >= 0:
		return "future"

	return "modern"


func _current_reality_key() -> String:
	if gs == null:
		return "realistic"

	var mode: String = str(
		gs.reality_mode
	).strip_edges().to_lower()

	if mode in ["realistic", "enhanced", "chaos"]:
		return mode

	return "realistic"


func _property_size_from_value(base_value: int) -> String:
	if base_value >= 10000000:
		return "Mansion"

	if base_value >= 1000000:
		return "Large"

	if base_value >= 250000:
		return "Medium"

	return "Small"


func _part(
	parts: PackedStringArray,
	index: int,
	fallback: String = ""
) -> String:
	if index < 0 or index >= parts.size():
		return fallback

	return str(parts [index]).strip_edges()


func _csv(value: String) -> Array:
	var out: Array = []

	for raw_part in value.split(",", false):
		var clean: String = str(
			raw_part
		).strip_edges().to_lower()

		if clean != "" and not out.has(clean):
			out.append(clean)

	return out


func _safe_array(value: Variant) -> Array:
	return (
		(value as Array).duplicate(true)
		if typeof(value) == TYPE_ARRAY
		else []
	)