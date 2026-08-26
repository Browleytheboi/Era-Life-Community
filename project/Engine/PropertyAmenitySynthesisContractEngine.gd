extends Resource
class_name PropertyAmenitySynthesisContractEngine

const ENGINE_SCHEMA:= "eralife.property_amenity_synthesis_contract_engine"
const CONTRACT_VERSION:= 1
const MAX_SYNTHESIZED_AMENITIES:= 12
const MAX_RESOLVED_CACHE_ENTRIES:= 4096

var gs: GameState = null
var resolved_contract_cache: Dictionary = {}


func _init(_gs: GameState = null) -> void:
	bind_game_state(_gs)


func bind_game_state(_gs: GameState) -> void:
	gs = _gs


func reset_runtime() -> void:
	resolved_contract_cache.clear()


func resolve_property_contract(
	actor: Person,
	property_source: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	var source: Dictionary = property_source.duplicate(true)
	var era_key: String = _resolve_era_key(
		source,
		context
	)
	var realm_key: String = _resolve_realm_key(
		actor,
		source,
		context
	)
	var property_type: String = str(
		source.get(
			"subtype",
			source.get("archetype", "dwelling")
		)
	).strip_edges().to_lower()
	var category: String = str(
		source.get(
			"category",
			source.get("archetype", "residential")
		)
	).strip_edges().to_lower()
	var price: int = maxi(
		0,
		int(
			context.get(
				"resolved_price",
				source.get(
					"price",
					source.get(
						"base_value",
						source.get("value", 0)
					)
				)
			)
		)
	)
	var economic_tier: String = _economic_tier_for_price(
		price,
		source
	)
	var neighborhood: String = _resolve_neighborhood(
		source,
		context
	)
	var construction_quality: String = _resolve_construction_quality(
		source,
		context,
		economic_tier
	)
	var historical_technology_level: String = _historical_technology_level(
		era_key,
		source
	)
	var lifestyle_modifiers: Array = _resolve_lifestyle_modifiers(
		actor,
		source,
		context
	)
	var cache_key: String = _contract_cache_key(
		actor,
		source,
		era_key,
		realm_key,
		property_type,
		economic_tier,
		neighborhood,
		construction_quality,
		price
	)

	if resolved_contract_cache.has(cache_key):
		return (
			resolved_contract_cache [cache_key] as Dictionary
		).duplicate(true)

	if (
		resolved_contract_cache.size()
		>= MAX_RESOLVED_CACHE_ENTRIES
	):
		resolved_contract_cache.clear()

	var candidate_pool: Array = []
	candidate_pool.append_array(
		_era_amenity_pool(era_key)
	)
	candidate_pool.append_array(
		_property_type_amenity_pool(
			property_type,
			category,
			era_key
		)
	)
	candidate_pool.append_array(
		_economic_tier_amenity_pool(
			economic_tier,
			era_key
		)
	)
	candidate_pool.append_array(
		_realm_amenity_pool(
			realm_key,
			era_key
		)
	)
	candidate_pool.append_array(
		_neighborhood_amenity_pool(
			neighborhood,
			era_key
		)
	)
	candidate_pool.append_array(
		_construction_quality_amenity_pool(
			construction_quality,
			era_key
		)
	)
	candidate_pool.append_array(
		_lifestyle_amenity_pool(
			lifestyle_modifiers,
			era_key
		)
	)

	var compatible_pool: Array = _compatible_amenities(
		candidate_pool,
		era_key,
		property_type,
		category,
		economic_tier,
		realm_key,
		neighborhood,
		construction_quality
	)
	var target_count: int = _amenity_target_count(
		price,
		economic_tier,
		category,
		source
	)
	var resolved_amenities: Array = _deterministic_amenity_selection(
		compatible_pool,
		target_count,
		cache_key
	)

	var amenity_names: Array = []
	var amenity_ids: Array = []
	var amenity_tags: Array = []
	var operational_profile: Dictionary = _safe_dictionary(
		source.get("operational_profile", {})
	)
	var vehicle_storage_capacity: int = int(
		source.get(
			"vehicle_storage_capacity",
			operational_profile.get(
				"vehicle_storage_capacity",
				0
			)
		)
	)
	var property_value_delta: int = 0
	var monthly_cost_delta: int = 0
	var comfort_delta: float = 0.0

	for raw_amenity in resolved_amenities:
		var amenity: Dictionary = _safe_dictionary(
			raw_amenity
		)

		if amenity.is_empty():
			continue

		var amenity_name: String = str(
			amenity.get("display_name", "Amenity")
		)
		var amenity_id: String = str(
			amenity.get("amenity_id", "")
		)

		if amenity_name != "":
			amenity_names.append(amenity_name)

		if amenity_id != "":
			amenity_ids.append(amenity_id)

		property_value_delta += int(
			amenity.get("property_value_delta", 0)
		)
		monthly_cost_delta += int(
			amenity.get("monthly_cost_delta", 0)
		)
		comfort_delta += float(
			amenity.get("comfort_delta", 0.0)
		)
		vehicle_storage_capacity += int(
			amenity.get(
				"vehicle_storage_capacity_delta",
				0
			)
		)

		for raw_tag in _safe_array(
			amenity.get("tags", [])
		):
			var tag: String = str(
				raw_tag
			).strip_edges().to_lower()

			if tag != "" and not amenity_tags.has(tag):
				amenity_tags.append(tag)

	var resolved_contract: Dictionary = {
		"schema": "eralife.property.resolved_amenity_contract",
		"version": CONTRACT_VERSION,
		"success": true,
		"source_engine": ENGINE_SCHEMA,
		"actor_id": (
			int(actor.id)
			if actor != null
			else -1
		),
		"property_template_id": str(
			source.get("template_id", "")
		),
		"property_id": int(
			source.get("id", -1)
		),
		"era_key": era_key,
		"realm_key": realm_key,
		"property_type": property_type,
		"property_category": category,
		"economic_tier": economic_tier,
		"neighborhood": neighborhood,
		"construction_quality": construction_quality,
		"historical_technology_level": historical_technology_level,
		"lifestyle_modifiers": lifestyle_modifiers.duplicate(true),
		"resolved_price": price,
		"amenity_contracts": resolved_amenities.duplicate(true),
		"amenities": amenity_names,
		"amenity_ids": amenity_ids,
		"amenity_tags": amenity_tags,
		"amenity_count": resolved_amenities.size(),
		"amenity_summary": _amenity_summary(
			amenity_names
		),
		"vehicle_storage_capacity": maxi(
			0,
			vehicle_storage_capacity
		),
		"property_value_delta": property_value_delta,
		"monthly_cost_delta": monthly_cost_delta,
		"comfort_delta": comfort_delta,
		"synthesis_order": [
			"era",
			"region_or_realm",
			"property_type",
			"economic_tier",
			"neighborhood",
			"construction_quality",
			"historical_technology_level",
			"lifestyle_modifiers",
			"amenity_pool",
			"resolved_property_contract"
		],
		"ui_is_renderer_only": true
	}

	resolved_contract_cache [cache_key] = (
		resolved_contract.duplicate(true)
	)

	return resolved_contract


func makeover_path_contracts_for_property(
	actor: Person,
	property_contract: Dictionary,
	context: Dictionary = {}
) -> Array:
	var resolved: Dictionary = resolve_property_contract(
		actor,
		property_contract,
		context
	)
	var era_key: String = str(
		resolved.get("era_key", "modern")
	)
	var realm_key: String = str(
		resolved.get("realm_key", "")
	)
	var economic_tier: String = str(
		resolved.get("economic_tier", "working")
	)
	var property_type: String = str(
		resolved.get("property_type", "dwelling")
	)
	var category: String = str(
		resolved.get(
			"property_category",
			"residential"
		)
	)
	var existing_ids: Array = _safe_array(
		property_contract.get("amenity_ids", [])
	)
	var pool: Array = []

	pool.append_array(
		_era_amenity_pool(era_key)
	)
	pool.append_array(
		_property_type_amenity_pool(
			property_type,
			category,
			era_key
		)
	)
	pool.append_array(
		_economic_tier_amenity_pool(
			economic_tier,
			era_key
		)
	)
	pool.append_array(
		_realm_amenity_pool(
			realm_key,
			era_key
		)
	)

	var compatible: Array = _compatible_amenities(
		pool,
		era_key,
		property_type,
		category,
		economic_tier,
		realm_key,
		str(
			resolved.get(
				"neighborhood",
				"mixed"
			)
		),
		str(
			resolved.get(
				"construction_quality",
				"standard"
			)
		)
	)
	var paths: Array = []

	for raw_amenity in compatible:
		var amenity: Dictionary = _safe_dictionary(
			raw_amenity
		)
		var amenity_id: String = str(
			amenity.get("amenity_id", "")
		)

		if (
			amenity_id == ""
			or existing_ids.has(amenity_id)
			or bool(
				amenity.get("included_only", false)
			)
		):
			continue

		var cost: int = _makeover_cost_for_amenity(
			amenity,
			property_contract,
			economic_tier
		)
		var duration_days: int = maxi(
			1,
			int(
				amenity.get(
					"installation_days",
					3
				)
			)
		)
		var amenity_title: String = str(
			amenity.get(
				"display_name",
				"Property Amenity"
			)
		)
		var spatial_mutation: Dictionary = _safe_dictionary(
			amenity.get("spatial_mutation", {})
		)

		paths.append({
			"path_id": "amenity:%s" % amenity_id,
			"title": "Add %s" % amenity_title,
			"description": str(
				amenity.get(
					"description",
					"Add %s through an era-valid property contract." % amenity_title.to_lower()
				)
			),
			"cost": cost,
			"cost_text": _format_money(cost),
			"duration_days": duration_days,
			"disruption_level": str(
				amenity.get(
					"disruption_level",
					"moderate"
				)
			),
			"era_key": era_key,
			"realm_key": realm_key,
			"economic_tier": economic_tier,
			"amenity_id": amenity_id,
			"effects": {
				"property_value_delta": int(
					amenity.get(
						"property_value_delta",
						int(
							round(
								float(cost) * 0.72
							)
						)
					)
				),
				"household_happiness_delta": float(
					amenity.get(
						"household_happiness_delta",
						1.0
					)
				),
				"comfort_delta": float(
					amenity.get(
						"comfort_delta",
						1.0
					)
				),
				"condition_delta": float(
					amenity.get(
						"condition_delta",
						4.0
					)
				),
				"identity_shift": str(
					amenity.get(
						"identity_shift",
						amenity_id
					)
				),
				"status_signal": str(
					amenity.get(
						"status_signal",
						economic_tier
					)
				),
				"spatial_mutation": spatial_mutation,
				"amenity_contract": amenity.duplicate(true),
				"vehicle_storage_capacity_delta": int(
					amenity.get(
						"vehicle_storage_capacity_delta",
						0
					)
				)
			},
			"options": [],
			"truth_source": ENGINE_SCHEMA,
			"ui_is_renderer_only": true
		})

	paths.sort_custom(func (left_raw, right_raw) -> bool:
		return int(
			(left_raw as Dictionary).get("cost", 0)
		) < int(
			(right_raw as Dictionary).get("cost", 0)
		)
	)

	return paths


func _era_amenity_pool(era_key: String) -> Array:
	match era_key:
		"ancient":
			return [
				_amenity(
					"fire_pit",
					"🔥 Fire Pit",
					"A central fire pit for warmth, cooking, and gathering.",
					["ancient"],
					[
						"residential",
						"royal",
						"commercial"
					],
					[
						"working",
						"comfortable",
						"wealthy",
						"elite"
					],
					140,
					2,
					["heat", "cooking"],
					1.0
				),
				_amenity(
					"straw_bedding",
					"🛏️ Straw Bedding",
					"Era-valid bedding for an ordinary ancient dwelling.",
					["ancient"],
					["residential"],
					["working", "comfortable"],
					45,
					1,
					["sleep", "basic"],
					0.5
				),
				_amenity(
					"grain_storage",
					"🌾 Grain Storage",
					"Protected storage for grain and preserved food.",
					["ancient"],
					["residential", "commercial"],
					[
						"working",
						"comfortable",
						"wealthy",
						"elite"
					],
					210,
					2,
					["storage", "food"],
					0.7
				),
				_amenity(
					"stable",
					"🐎 Stable",
					"A protected stable for mounts and animal-powered transport.",
					["ancient"],
					[
						"residential",
						"royal",
						"commercial",
						"military"
					],
					[
						"comfortable",
						"wealthy",
						"elite"
					],
					900,
					5,
					["vehicle_storage", "mount"],
					1.0,
					2
				),
				_amenity(
					"water_well",
					"🪣 Water Well",
					"A private or shared well appropriate to ancient technology.",
					["ancient"],
					[
						"residential",
						"commercial",
						"royal"
					],
					[
						"working",
						"comfortable",
						"wealthy",
						"elite"
					],
					650,
					6,
					["water", "utility"],
					1.0
				),
				_amenity(
					"guard_patrol",
					"🛡️ Guard Patrol",
					"A rotating guard patrol protects the grounds.",
					["ancient"],
					[
						"royal",
						"military",
						"residential"
					],
					["wealthy", "elite"],
					1800,
					2,
					["security", "status"],
					0.5
				),
				_amenity(
					"community_oven",
					"🍞 Community Oven",
					"A communal masonry oven supports neighborhood food production.",
					["ancient"],
					["residential", "commercial"],
					[
						"working",
						"comfortable",
						"wealthy"
					],
					420,
					4,
					["cooking", "community"],
					0.8
				),
				_amenity(
					"courtyard_cistern",
					"🏺 Courtyard Cistern",
					"A stone cistern captures and protects household water.",
					["ancient"],
					["residential", "royal"],
					[
						"comfortable",
						"wealthy",
						"elite"
					],
					1200,
					7,
					["water", "courtyard"],
					1.0
				),
				_amenity(
					"mosaic_courtyard",
					"🏛️ Mosaic Courtyard",
					"A decorated central courtyard signals wealth and civic taste.",
					["ancient"],
					["royal", "residential"],
					["wealthy", "elite"],
					4200,
					12,
					[
						"luxury",
						"courtyard",
						"status"
					],
					2.0
				)
			]

		"medieval":
			return [
				_amenity(
					"stone_fireplace",
					"🔥 Stone Fireplace",
					"A masonry fireplace provides era-valid heating and cooking support.",
					["medieval"],
					[
						"residential",
						"royal",
						"religious"
					],
					[
						"working",
						"comfortable",
						"wealthy",
						"elite"
					],
					780,
					4,
					["heat", "cooking"],
					1.0
				),
				_amenity(
					"blacksmith_nearby",
					"⚒️ Blacksmith Nearby",
					"Nearby smithing supports tools, armor, and transport maintenance.",
					["medieval"],
					[
						"residential",
						"commercial",
						"military"
					],
					[
						"working",
						"comfortable",
						"wealthy",
						"elite"
					],
					600,
					2,
					["service", "maintenance"],
					0.4
				),
				_amenity(
					"chapel_access",
					"⛪ Chapel Access",
					"A chapel or nearby sacred space supports religious life.",
					["medieval"],
					[
						"residential",
						"royal",
						"religious"
					],
					[
						"working",
						"comfortable",
						"wealthy",
						"elite"
					],
					900,
					5,
					["religious", "community"],
					0.6
				),
				_amenity(
					"medieval_courtyard",
					"🏰 Courtyard",
					"A protected courtyard supports household, trade, and ceremony.",
					["medieval"],
					[
						"residential",
						"royal",
						"commercial",
						"military"
					],
					[
						"comfortable",
						"wealthy",
						"elite"
					],
					2100,
					9,
					["courtyard", "social"],
					1.3
				),
				_amenity(
					"horse_stable",
					"🐎 Horse Stable",
					"A stable stores and maintains horses and carriages.",
					["medieval"],
					[
						"residential",
						"royal",
						"commercial",
						"military"
					],
					[
						"comfortable",
						"wealthy",
						"elite"
					],
					1700,
					8,
					[
						"vehicle_storage",
						"mount",
						"carriage"
					],
					1.0,
					3
				),
				_amenity(
					"defensive_walls",
					"🧱 Defensive Walls",
					"Fortified perimeter walls protect the property.",
					["medieval"],
					[
						"royal",
						"military",
						"residential"
					],
					["wealthy", "elite"],
					8500,
					30,
					["security", "fortified"],
					1.0
				),
				_amenity(
					"wine_cellar",
					"🍷 Wine Cellar",
					"A cool underground cellar stores wine and preserved goods.",
					["medieval"],
					[
						"residential",
						"royal",
						"commercial",
						"religious"
					],
					["wealthy", "elite"],
					3600,
					14,
					[
						"luxury",
						"storage",
						"cellar"
					],
					1.2
				),
				_amenity(
					"castle_protection",
					"🛡️ Castle Protection",
					"The residence sits within a protected castle district.",
					["medieval"],
					[
						"residential",
						"commercial",
						"religious"
					],
					[
						"comfortable",
						"wealthy",
						"elite"
					],
					2600,
					3,
					["security", "district"],
					0.6
				)
			]

		"industrial":
			return [
				_amenity(
					"indoor_plumbing",
					"🚿 Indoor Plumbing",
					"Piped water and sanitation replace wells and chamber pots.",
					["industrial"],
					[
						"residential",
						"commercial",
						"government",
						"religious"
					],
					[
						"comfortable",
						"wealthy",
						"elite"
					],
					2400,
					14,
					["water", "sanitation"],
					1.8
				),
				_amenity(
					"gas_lighting",
					"🕯️ Gas Lighting",
					"Gas fixtures illuminate the building after dark.",
					["industrial"],
					[
						"residential",
						"commercial",
						"government"
					],
					[
						"working",
						"comfortable",
						"wealthy",
						"elite"
					],
					1100,
					8,
					["lighting", "technology"],
					0.8
				),
				_amenity(
					"coal_heating",
					"🔥 Coal Heating",
					"Coal-fired heating supports colder industrial cities.",
					["industrial"],
					[
						"residential",
						"commercial",
						"government"
					],
					[
						"working",
						"comfortable",
						"wealthy",
						"elite"
					],
					1600,
					9,
					["heat", "technology"],
					1.0
				),
				_amenity(
					"telegraph_access",
					"📨 Telegraph Access",
					"Nearby telegraph service connects the property to distant contacts.",
					["industrial"],
					[
						"residential",
						"commercial",
						"government"
					],
					[
						"comfortable",
						"wealthy",
						"elite"
					],
					1400,
					4,
					[
						"communications",
						"technology"
					],
					0.5
				),
				_amenity(
					"streetcar_stop",
					"🚋 Streetcar Stop",
					"A nearby streetcar stop improves urban mobility.",
					["industrial"],
					["residential", "commercial"],
					[
						"working",
						"comfortable",
						"wealthy",
						"elite"
					],
					900,
					2,
					["transit", "neighborhood"],
					0.4
				),
				_amenity(
					"factory_district_nearby",
					"🏭 Factory District Nearby",
					"Industrial employment and freight access sit nearby.",
					["industrial"],
					["residential", "commercial"],
					["working", "comfortable"],
					400,
					1,
					[
						"industrial",
						"employment"
					],
					-0.2
				),
				_amenity(
					"brick_construction",
					"🧱 Brick Construction",
					"Durable brick construction improves fire resistance.",
					["industrial"],
					[
						"residential",
						"commercial",
						"government"
					],
					[
						"working",
						"comfortable",
						"wealthy",
						"elite"
					],
					3200,
					18,
					[
						"construction",
						"durability"
					],
					0.8
				),
				_amenity(
					"carriage_house",
					"🛞 Carriage House",
					"A carriage house stores coaches, early automobiles, and equipment.",
					["industrial"],
					[
						"residential",
						"royal",
						"commercial"
					],
					["wealthy", "elite"],
					5200,
					20,
					[
						"vehicle_storage",
						"carriage",
						"garage"
					],
					1.2,
					4
				)
			]

		"future":
			return [
				_amenity(
					"ai_home_assistant",
					"🤖 AI Home Assistant",
					"A local intelligence coordinates the property without becoming simulation authority.",
					["future"],
					[
						"residential",
						"commercial",
						"government",
						"military",
						"royal"
					],
					[
						"working",
						"comfortable",
						"wealthy",
						"elite"
					],
					18000,
					3,
					["ai", "smart"],
					2.0
				),
				_amenity(
					"medical_scanner",
					"🩺 Medical Scanner",
					"A non-invasive scanner monitors household health and injuries.",
					["future"],
					[
						"residential",
						"commercial",
						"government",
						"military"
					],
					[
						"comfortable",
						"wealthy",
						"elite"
					],
					42000,
					7,
					["medical", "technology"],
					2.0
				),
				_amenity(
					"holographic_walls",
					"🪩 Holographic Walls",
					"Programmable walls transform atmosphere and interior identity.",
					["future"],
					[
						"residential",
						"commercial",
						"royal"
					],
					["wealthy", "elite"],
					65000,
					9,
					[
						"holographic",
						"luxury"
					],
					2.4
				),
				_amenity(
					"atmospheric_climate_control",
					"🌤️ Atmospheric Climate Control",
					"Localized control stabilizes temperature, pressure, and air quality.",
					["future"],
					[
						"residential",
						"commercial",
						"government",
						"military",
						"royal"
					],
					[
						"comfortable",
						"wealthy",
						"elite"
					],
					72000,
					12,
					[
						"climate",
						"life_support"
					],
					3.0
				),
				_amenity(
					"drone_delivery_pad",
					"🚁 Drone Delivery Pad",
					"A secured autonomous delivery pad handles cargo.",
					["future"],
					[
						"residential",
						"commercial",
						"government"
					],
					[
						"comfortable",
						"wealthy",
						"elite"
					],
					26000,
					6,
					["delivery", "air"],
					1.2
				),
				_amenity(
					"autonomous_garage",
					"🛸 Autonomous Garage",
					"A robotic garage stores, charges, and dispatches mobility assets.",
					["future"],
					[
						"residential",
						"commercial",
						"government",
						"military",
						"royal"
					],
					[
						"comfortable",
						"wealthy",
						"elite"
					],
					84000,
					15,
					[
						"vehicle_storage",
						"garage",
						"autonomous"
					],
					2.0,
					8
				),
				_amenity(
					"nanite_repair_system",
					"🧬 Nanite Repair System",
					"Nanites maintain structural surfaces and installed fixtures.",
					["future"],
					[
						"residential",
						"commercial",
						"government",
						"military",
						"royal"
					],
					["wealthy", "elite"],
					140000,
					18,
					["repair", "nanite"],
					2.5
				),
				_amenity(
					"personal_energy_shield",
					"🛡️ Personal Energy Shield",
					"A localized energy barrier protects the property perimeter.",
					["future"],
					[
						"residential",
						"government",
						"military",
						"royal"
					],
					["wealthy", "elite"],
					220000,
					24,
					["security", "energy"],
					1.5
				),
				_amenity(
					"quantum_internet",
					"🌐 Quantum Internet",
					"Entanglement-backed communications provide near-instant access.",
					["future"],
					[
						"residential",
						"commercial",
						"government",
						"military",
						"royal"
					],
					[
						"comfortable",
						"wealthy",
						"elite"
					],
					38000,
					5,
					[
						"communications",
						"quantum"
					],
					1.2
				),
				_amenity(
					"robot_housekeeper",
					"🧹 Robot Housekeeper",
					"An autonomous unit manages routine cleaning and organization.",
					["future"],
					["residential", "royal"],
					[
						"comfortable",
						"wealthy",
						"elite"
					],
					32000,
					2,
					["robot", "cleaning"],
					1.8
				)
			]

		_:
			return _modern_amenity_pool()


func _modern_amenity_pool() -> Array:
	return [
		_amenity(
			"one_bathroom",
			"🚿 One Bathroom",
			"A basic single-bathroom layout.",
			["modern"],
			["residential"],
			["working", "comfortable"],
			0,
			1,
			["bathroom", "basic"],
			0.2,
			0,
			true
		),
		_amenity(
			"carpet_floors",
			"🧶 Carpet Floors",
			"Standard carpet flooring throughout the primary living areas.",
			["modern"],
			["residential"],
			["working", "comfortable"],
			1800,
			3,
			["flooring", "basic"],
			0.4
		),
		_amenity(
			"shared_laundry",
			"🧺 Shared Laundry",
			"Laundry facilities are shared with neighboring residents.",
			["modern"],
			["residential"],
			["working", "comfortable"],
			0,
			1,
			["laundry", "shared"],
			0.2,
			0,
			true
		),
		_amenity(
			"street_parking",
			"🅿️ Street Parking",
			"Vehicles rely on street parking rather than dedicated storage.",
			["modern"],
			["residential", "commercial"],
			["working", "comfortable"],
			0,
			1,
			["parking", "street"],
			0.0,
			0,
			true
		),
		_amenity(
			"older_appliances",
			"🍳 Older Appliances",
			"The included appliances are functional but dated.",
			["modern"],
			["residential"],
			["working", "comfortable"],
			0,
			1,
			["appliance", "basic"],
			0.0,
			0,
			true
		),
		_amenity(
			"private_laundry",
			"🧺 Private Laundry",
			"Private washer and dryer access inside the property.",
			["modern"],
			["residential"],
			[
				"comfortable",
				"wealthy",
				"elite"
			],
			4200,
			3,
			["laundry", "private"],
			0.8
		),
		_amenity(
			"garage",
			"🚗 Garage",
			"An enclosed garage stores and protects vehicles.",
			["modern"],
			["residential", "commercial"],
			[
				"comfortable",
				"wealthy",
				"elite"
			],
			18000,
			14,
			[
				"vehicle_storage",
				"garage"
			],
			1.0,
			2
		),
		_amenity(
			"multi_car_garage",
			"🚘 Multi-Car Garage",
			"A larger enclosed garage stores several vehicles.",
			["modern"],
			[
				"residential",
				"commercial",
				"royal"
			],
			["wealthy", "elite"],
			48000,
			24,
			[
				"vehicle_storage",
				"garage",
				"luxury"
			],
			1.5,
			5
		),
		_amenity(
			"rooftop_pool",
			"🏊 Rooftop Pool",
			"A rooftop pool creates a premium leisure space.",
			["modern"],
			["residential", "commercial"],
			["wealthy", "elite"],
			95000,
			30,
			[
				"pool",
				"luxury",
				"rooftop"
			],
			2.4
		),
		_amenity(
			"concierge",
			"🛎️ Concierge",
			"A staffed concierge provides security and resident support.",
			["modern"],
			["residential", "commercial"],
			["wealthy", "elite"],
			22000,
			2,
			[
				"service",
				"security",
				"luxury"
			],
			1.0
		),
		_amenity(
			"smart_locks",
			"🔐 Smart Locks",
			"Networked locks improve controlled access and security.",
			["modern"],
			[
				"residential",
				"commercial",
				"government"
			],
			[
				"comfortable",
				"wealthy",
				"elite"
			],
			2600,
			2,
			["smart", "security"],
			0.5
		),
		_amenity(
			"fitness_gym",
			"🏋️ Gym",
			"A dedicated fitness room or shared building gym.",
			["modern"],
			[
				"residential",
				"commercial",
				"government"
			],
			[
				"comfortable",
				"wealthy",
				"elite"
			],
			28000,
			12,
			["fitness", "luxury"],
			1.2
		),
		_amenity(
			"underground_parking",
			"🚘 Underground Parking",
			"Secure underground parking protects mobility assets.",
			["modern"],
			[
				"residential",
				"commercial",
				"government"
			],
			["wealthy", "elite"],
			72000,
			28,
			[
				"vehicle_storage",
				"parking",
				"underground"
			],
			1.0,
			4
		),
		_amenity(
			"skyline_view",
			"🌆 Skyline View",
			"Elevated sightlines provide a premium urban view.",
			["modern"],
			["residential", "commercial"],
			["wealthy", "elite"],
			36000,
			1,
			[
				"view",
				"luxury",
				"urban"
			],
			1.0,
			0,
			true
		),
		_amenity(
			"wine_cellar_modern",
			"🍷 Wine Cellar",
			"A climate-controlled wine cellar supports collection and entertaining.",
			["modern"],
			[
				"residential",
				"commercial",
				"royal"
			],
			["wealthy", "elite"],
			42000,
			14,
			[
				"storage",
				"luxury",
				"cellar"
			],
			1.2
		),
		_amenity(
			"guest_suite",
			"🛏️ Guest Suite",
			"A private guest suite expands household capacity.",
			["modern"],
			["residential", "royal"],
			["wealthy", "elite"],
			68000,
			30,
			[
				"bedroom",
				"guest",
				"luxury"
			],
			1.6
		),
		_amenity(
			"fiber_internet",
			"🌐 Fiber Internet",
			"High-bandwidth internet supports work and entertainment.",
			["modern"],
			[
				"residential",
				"commercial",
				"government"
			],
			[
				"comfortable",
				"wealthy",
				"elite"
			],
			1800,
			2,
			[
				"communications",
				"technology"
			],
			0.6
		),
		_amenity(
			"heated_floors",
			"♨️ Heated Floors",
			"Radiant floor heating improves winter comfort.",
			["modern"],
			[
				"residential",
				"commercial",
				"royal"
			],
			["wealthy", "elite"],
			24000,
			16,
			["heat", "luxury"],
			1.4
		),
		_amenity(
			"solar_panels",
			"☀️ Solar Panels",
			"Solar generation reduces long-term energy cost.",
			["modern"],
			[
				"residential",
				"commercial",
				"government"
			],
			[
				"comfortable",
				"wealthy",
				"elite"
			],
			18000,
			9,
			["eco", "energy"],
			0.8
		),
		_amenity(
			"finished_basement",
			"🧱 Finished Basement",
			"A finished basement adds flexible navigable living space.",
			["modern"],
			["residential"],
			[
				"comfortable",
				"wealthy",
				"elite"
			],
			42000,
			24,
			[
				"basement",
				"spatial"
			],
			1.4
		),
		_amenity(
			"workshop",
			"🛠️ Workshop",
			"A dedicated workshop supports repairs, craft, and projects.",
			["modern"],
			[
				"residential",
				"commercial"
			],
			[
				"comfortable",
				"wealthy",
				"elite"
			],
			24000,
			14,
			[
				"workshop",
				"craft"
			],
			0.8
		),
		_amenity(
			"fenced_yard",
			"🏡 Fenced Yard",
			"A fenced yard supports privacy, play, and animals.",
			["modern"],
			["residential"],
			[
				"working",
				"comfortable",
				"wealthy",
				"elite"
			],
			9000,
			7,
			[
				"yard",
				"family"
			],
			0.8
		),
		_amenity(
			"garden",
			"🌿 Garden",
			"A cultivated garden supports food, leisure, or landscaping.",
			["modern"],
			[
				"residential",
				"commercial",
				"religious"
			],
			[
				"working",
				"comfortable",
				"wealthy",
				"elite"
			],
			6500,
			7,
			[
				"garden",
				"eco"
			],
			0.8
		)
	]


func _property_type_amenity_pool(
	property_type: String,
	category: String,
	era_key: String
) -> Array:
	var type_key: String = property_type.to_lower()
	var out: Array = []
	var era_pool: Array = _era_amenity_pool(
		era_key
	)

	if (
		type_key.find("apartment") >= 0
		or type_key.find("loft") >= 0
		or type_key.find("penthouse") >= 0
	):
		out.append_array(
			_amenities_by_ids(
				era_pool,
				[
					"one_bathroom",
					"shared_laundry",
					"street_parking",
					"concierge",
					"rooftop_pool",
					"underground_parking",
					"skyline_view",
					"fiber_internet",
					"smart_locks"
				]
			)
		)

	if (
		type_key.find("farm") >= 0
		or type_key.find("ranch") >= 0
		or type_key.find("longhouse") >= 0
	):
		out.append_array(
			_amenities_by_ids(
				era_pool,
				[
					"grain_storage",
					"stable",
					"water_well",
					"horse_stable",
					"workshop",
					"garden",
					"fenced_yard"
				]
			)
		)

	if (
		type_key.find("castle") >= 0
		or type_key.find("palace") >= 0
		or category == "royal"
	):
		out.append_array(
			_amenities_by_ids(
				era_pool,
				[
					"guard_patrol",
					"mosaic_courtyard",
					"defensive_walls",
					"wine_cellar",
					"castle_protection",
					"multi_car_garage",
					"personal_energy_shield"
				]
			)
		)

	if (
		type_key.find("bunker") >= 0
		or category == "military"
	):
		out.append(
			_amenity(
				"secure_vehicle_bay",
				"🛡️ Secure Vehicle Bay",
				"A hardened vehicle bay stores protected mobility assets.",
				[era_key],
				[category],
				[
					"comfortable",
					"wealthy",
					"elite"
				],
				90000,
				20,
				[
					"vehicle_storage",
					"military",
					"secure"
				],
				0.8,
				6
			)
		)

	if type_key.find("hangar") >= 0:
		out.append(
			_amenity(
				"aircraft_hangar_bays",
				"✈️ Aircraft Hangar Bays",
				"Dedicated hangar bays store aircraft and large mobility assets.",
				[era_key],
				[category],
				[
					"comfortable",
					"wealthy",
					"elite"
				],
				180000,
				30,
				[
					"vehicle_storage",
					"aircraft",
					"hangar"
				],
				0.5,
				12
			)
		)

	if (
		type_key.find("harbor") >= 0
		or type_key.find("floating") >= 0
		or type_key.find("beach") >= 0
		or type_key.find("lake") >= 0
	):
		out.append(
			_amenity(
				"private_dock",
				"⚓ Private Dock",
				"A private dock stores and launches watercraft.",
				[era_key],
				[category],
				[
					"comfortable",
					"wealthy",
					"elite"
				],
				48000,
				16,
				[
					"vehicle_storage",
					"watercraft",
					"dock"
				],
				1.0,
				4
			)
		)

	return out


func _economic_tier_amenity_pool(
	economic_tier: String,
	era_key: String
) -> Array:
	var pool: Array = _era_amenity_pool(era_key)
	var out: Array = []

	for raw_amenity in pool:
		var amenity: Dictionary = _safe_dictionary(
			raw_amenity
		)
		var tiers: Array = _safe_array(
			amenity.get("economic_tiers", [])
		)

		if tiers.has(economic_tier):
			out.append(amenity)

	return out


func _realm_amenity_pool(
	realm_key: String,
	_era_key: String
) -> Array:
	var key: String = realm_key.to_lower()
	var all_eras: Array = [
		"ancient",
		"medieval",
		"industrial",
		"modern",
		"future"
	]

	if key.find("earth") >= 0:
		return [
			_amenity(
				"stone_forging_workshop",
				"⚒️ Stone Forging Workshop",
				"A workshop shaped around stone, ore, and earthcraft.",
				all_eras,
				[
					"residential",
					"royal",
					"commercial",
					"military"
				],
				[
					"comfortable",
					"wealthy",
					"elite"
				],
				34000,
				16,
				["earth", "workshop"],
				1.2
			),
			_amenity(
				"crystal_garden",
				"💎 Crystal Garden",
				"A cultivated garden of mineral formations.",
				all_eras,
				[
					"residential",
					"royal",
					"religious"
				],
				["wealthy", "elite"],
				52000,
				18,
				[
					"earth",
					"garden",
					"luxury"
				],
				1.6
			),
			_amenity(
				"earth_meditation_hall",
				"🪨 Earth Meditation Hall",
				"A grounded chamber supports discipline and earth meditation.",
				all_eras,
				[
					"residential",
					"royal",
					"religious"
				],
				[
					"comfortable",
					"wealthy",
					"elite"
				],
				28000,
				12,
				[
					"earth",
					"meditation"
				],
				1.2
			),
			_amenity(
				"reinforced_stone_walls",
				"🧱 Reinforced Stone Walls",
				"Dense stone walls resist weather, intrusion, and bending impact.",
				all_eras,
				[
					"residential",
					"royal",
					"military"
				],
				[
					"comfortable",
					"wealthy",
					"elite"
				],
				46000,
				20,
				["earth", "security"],
				0.8
			),
			_amenity(
				"quarry_access",
				"⛏️ Quarry Access",
				"Nearby quarry rights support construction, trade, and craft.",
				all_eras,
				[
					"residential",
					"commercial",
					"royal"
				],
				[
					"working",
					"comfortable",
					"wealthy",
					"elite"
				],
				18000,
				4,
				["earth", "resource"],
				0.4
			)
		]

	if (
		key.find("air") >= 0
		or key.find("nomad") >= 0
	):
		return [
			_amenity(
				"sky_dock",
				"☁️ Sky Dock",
				"An elevated dock receives gliders, flying mounts, and air vehicles.",
				all_eras,
				[
					"residential",
					"royal",
					"religious",
					"commercial"
				],
				[
					"comfortable",
					"wealthy",
					"elite"
				],
				42000,
				14,
				[
					"air",
					"vehicle_storage",
					"sky_dock"
				],
				1.0,
				4
			),
			_amenity(
				"meditation_platform",
				"🧘 Meditation Platform",
				"An open-air platform supports contemplation and training.",
				all_eras,
				[
					"residential",
					"religious",
					"royal"
				],
				[
					"working",
					"comfortable",
					"wealthy",
					"elite"
				],
				12000,
				7,
				["air", "meditation"],
				1.0
			),
			_amenity(
				"wind_chimes",
				"🎐 Wind Chimes",
				"Responsive chimes turn wind into a living ambient signal.",
				all_eras,
				["residential", "religious"],
				[
					"working",
					"comfortable",
					"wealthy",
					"elite"
				],
				900,
				1,
				["air", "ambient"],
				0.4
			),
			_amenity(
				"cloud_garden",
				"☁️ Cloud Garden",
				"A high-altitude garden uses mist, airflow, and suspended planters.",
				all_eras,
				[
					"residential",
					"royal",
					"religious"
				],
				[
					"comfortable",
					"wealthy",
					"elite"
				],
				26000,
				12,
				["air", "garden"],
				1.2
			),
			_amenity(
				"glider_storage",
				"🪂 Glider Storage",
				"A protected rack stores personal gliders and lightweight air mobility.",
				all_eras,
				[
					"residential",
					"religious",
					"royal"
				],
				[
					"working",
					"comfortable",
					"wealthy",
					"elite"
				],
				8000,
				4,
				[
					"air",
					"vehicle_storage",
					"glider"
				],
				0.5,
				3
			)
		]

	if (
		key.find("water") >= 0
		or key.find("tribe") >= 0
	):
		return [
			_amenity(
				"private_harbor",
				"⚓ Private Harbor",
				"A protected harbor supports boats, fishing, and travel.",
				all_eras,
				[
					"residential",
					"royal",
					"commercial",
					"military"
				],
				["wealthy", "elite"],
				78000,
				24,
				[
					"water",
					"vehicle_storage",
					"harbor"
				],
				1.2,
				8
			),
			_amenity(
				"heated_bath_house",
				"♨️ Heated Bath House",
				"A heated bath house suits a cold-water culture.",
				all_eras,
				[
					"residential",
					"royal",
					"religious"
				],
				[
					"comfortable",
					"wealthy",
					"elite"
				],
				36000,
				15,
				[
					"water",
					"bath",
					"heat"
				],
				1.8
			),
			_amenity(
				"fishing_dock",
				"🎣 Fishing Dock",
				"A working dock supports household fishing and small craft.",
				all_eras,
				["residential", "commercial"],
				[
					"working",
					"comfortable",
					"wealthy",
					"elite"
				],
				16000,
				8,
				[
					"water",
					"vehicle_storage",
					"fishing"
				],
				0.8,
				2
			),
			_amenity(
				"tide_observatory",
				"🌊 Tide Observatory",
				"A dedicated lookout tracks tides, storms, and sea conditions.",
				all_eras,
				[
					"residential",
					"royal",
					"government",
					"military"
				],
				[
					"comfortable",
					"wealthy",
					"elite"
				],
				28000,
				11,
				[
					"water",
					"observatory"
				],
				1.0
			)
		]

	if key.find("fire") >= 0:
		return [
			_amenity(
				"volcanic_heat_channel",
				"🌋 Volcanic Heat Channel",
				"Controlled geothermal channels provide heat and industrial power.",
				all_eras,
				[
					"residential",
					"royal",
					"commercial",
					"military"
				],
				[
					"comfortable",
					"wealthy",
					"elite"
				],
				42000,
				18,
				[
					"fire",
					"heat",
					"energy"
				],
				1.4
			),
			_amenity(
				"fire_training_court",
				"🔥 Fire Training Court",
				"A fire-resistant court supports controlled training and ceremony.",
				all_eras,
				[
					"residential",
					"royal",
					"military"
				],
				[
					"comfortable",
					"wealthy",
					"elite"
				],
				36000,
				15,
				[
					"fire",
					"training"
				],
				1.0
			),
			_amenity(
				"ember_garden",
				"🌺 Ember Garden",
				"Heat-tolerant plants and glowing stone create a Fire Nation garden.",
				all_eras,
				[
					"residential",
					"royal",
					"religious"
				],
				["wealthy", "elite"],
				30000,
				12,
				[
					"fire",
					"garden",
					"luxury"
				],
				1.2
			)
		]

	return []


func _neighborhood_amenity_pool(
	neighborhood: String,
	era_key: String
) -> Array:
	var key: String = neighborhood.to_lower()
	var pool: Array = _era_amenity_pool(era_key)
	var ids: Array = []

	if key in ["urban", "city_center", "dense"]:
		ids = [
			"streetcar_stop",
			"shared_laundry",
			"street_parking",
			"concierge",
			"fiber_internet",
			"skyline_view"
		]
	elif key in ["suburban", "residential_district"]:
		ids = [
			"garage",
			"fenced_yard",
			"garden",
			"private_laundry",
			"solar_panels"
		]
	elif key in ["rural", "farm", "frontier"]:
		ids = [
			"grain_storage",
			"stable",
			"water_well",
			"horse_stable",
			"workshop",
			"garden"
		]
	elif key in [
		"waterfront",
		"coastal",
		"lake",
		"harbor"
	]:
		ids = [
			"private_dock",
			"private_harbor",
			"fishing_dock",
			"tide_observatory"
		]

	return _amenities_by_ids(
		pool + _realm_amenity_pool(key, era_key),
		ids
	)


func _construction_quality_amenity_pool(
	construction_quality: String,
	era_key: String
) -> Array:
	var pool: Array = _era_amenity_pool(era_key)
	var out: Array = []

	for raw_amenity in pool:
		var amenity: Dictionary = _safe_dictionary(
			raw_amenity
		)
		var cost: int = int(
			amenity.get("base_cost", 0)
		)

		if (
			construction_quality == "basic"
			and cost <= 5000
		):
			out.append(amenity)
		elif (
			construction_quality == "standard"
			and cost <= 35000
		):
			out.append(amenity)
		elif construction_quality in [
			"premium",
			"masterwork"
		]:
			out.append(amenity)

	return out


func _lifestyle_amenity_pool(
	lifestyle_modifiers: Array,
	era_key: String
) -> Array:
	var pool: Array = _era_amenity_pool(era_key)
	var ids: Array = []

	if lifestyle_modifiers.has("family"):
		ids.append_array([
			"guest_suite",
			"fenced_yard",
			"garden",
			"community_oven"
		])

	if lifestyle_modifiers.has("technology"):
		ids.append_array([
			"smart_locks",
			"fiber_internet",
			"ai_home_assistant",
			"quantum_internet"
		])

	if lifestyle_modifiers.has("luxury"):
		ids.append_array([
			"rooftop_pool",
			"concierge",
			"heated_floors",
			"holographic_walls"
		])

	if lifestyle_modifiers.has("craft"):
		ids.append_array([
			"workshop",
			"blacksmith_nearby",
			"stone_forging_workshop"
		])

	if lifestyle_modifiers.has("eco"):
		ids.append_array([
			"garden",
			"solar_panels",
			"water_well",
			"atmospheric_climate_control"
		])

	return _amenities_by_ids(
		pool + _realm_amenity_pool(
			" ".join(lifestyle_modifiers),
			era_key
		),
		ids
	)


func _compatible_amenities(
	candidate_pool: Array,
	era_key: String,
	_property_type: String,
	category: String,
	economic_tier: String,
	_realm_key: String,
	_neighborhood: String,
	_construction_quality: String
) -> Array:
	var out: Array = []
	var seen: Dictionary = {}

	for raw_amenity in candidate_pool:
		var amenity: Dictionary = _safe_dictionary(
			raw_amenity
		)
		var amenity_id: String = str(
			amenity.get("amenity_id", "")
		)

		if (
			amenity_id == ""
			or seen.has(amenity_id)
		):
			continue

		var era_keys: Array = _safe_array(
			amenity.get("era_keys", [])
		)

		if (
			not era_keys.has("all")
			and not era_keys.has(era_key)
		):
			continue

		var categories: Array = _safe_array(
			amenity.get(
				"property_categories",
				[]
			)
		)

		if (
			not categories.is_empty()
			and not categories.has(category)
		):
			continue

		var tiers: Array = _safe_array(
			amenity.get("economic_tiers", [])
		)

		if (
			not tiers.is_empty()
			and not tiers.has(economic_tier)
		):
			continue

		seen [amenity_id] = true
		out.append(amenity)

	return out


func _deterministic_amenity_selection(
	pool: Array,
	target_count: int,
	seed_key: String
) -> Array:
	var scored: Array = []

	for raw_amenity in pool:
		var amenity: Dictionary = _safe_dictionary(
			raw_amenity
		)
		var amenity_id: String = str(
			amenity.get("amenity_id", "")
		)
		var score: int = abs(
			str(
				"%s|%s" % [
					seed_key,
					amenity_id
				]
			).hash()
		)

		scored.append({
			"score": score,
			"amenity": amenity
		})

	scored.sort_custom(func (left_raw, right_raw) -> bool:
		return int(
			(left_raw as Dictionary).get("score", 0)
		) < int(
			(right_raw as Dictionary).get("score", 0)
		)
	)

	var out: Array = []
	var safe_target: int = mini(
		MAX_SYNTHESIZED_AMENITIES,
		maxi(1, target_count)
	)

	for raw_scored in scored:
		if out.size() >= safe_target:
			break

		var scored_row: Dictionary = (
			raw_scored as Dictionary
		)
		out.append(
			_safe_dictionary(
				scored_row.get("amenity", {})
			)
		)

	return out


func _amenity(
	amenity_id: String,
	display_name: String,
	description: String,
	era_keys: Array,
	property_categories: Array,
	economic_tiers: Array,
	base_cost: int,
	installation_days: int,
	tags: Array,
	comfort_delta: float,
	vehicle_storage_capacity_delta: int = 0,
	included_only: bool = false
) -> Dictionary:
	return {
		"schema": "eralife.property.amenity_contract",
		"version": CONTRACT_VERSION,
		"amenity_id": amenity_id,
		"display_name": display_name,
		"description": description,
		"era_keys": era_keys.duplicate(true),
		"property_categories": property_categories.duplicate(true),
		"economic_tiers": economic_tiers.duplicate(true),
		"base_cost": base_cost,
		"installation_days": installation_days,
		"disruption_level": (
			"minor"
			if installation_days <= 3
			else "moderate"
			if installation_days <= 14
			else "major"
		),
		"tags": tags.duplicate(true),
		"comfort_delta": comfort_delta,
		"household_happiness_delta": maxf(
			0.0,
			comfort_delta * 0.6
		),
		"property_value_delta": int(
			round(float(base_cost) * 0.72)
		),
		"monthly_cost_delta": maxi(
			0,
			int(
				round(
					float(base_cost) * 0.0015
				)
			)
		),
		"condition_delta": 4.0,
		"vehicle_storage_capacity_delta": vehicle_storage_capacity_delta,
		"included_only": included_only,
		"identity_shift": amenity_id,
		"status_signal": (
			"luxury"
			if tags.has("luxury")
			else "improved"
		),
		"spatial_mutation": {},
		"truth_source": ENGINE_SCHEMA,
		"ui_is_renderer_only": true
	}


func _amenities_by_ids(
	pool: Array,
	ids: Array
) -> Array:
	var out: Array = []

	for raw_amenity in pool:
		var amenity: Dictionary = _safe_dictionary(
			raw_amenity
		)

		if ids.has(
			str(amenity.get("amenity_id", ""))
		):
			out.append(amenity)

	return out


func _economic_tier_for_price(
	price: int,
	source: Dictionary
) -> String:
	var value_band: String = str(
		source.get("value_band", "")
	).strip_edges().to_lower()

	if (
		value_band in ["ultra_luxury", "elite"]
		or price >= 2500000
	):
		return "elite"

	if (
		value_band == "luxury"
		or price >= 750000
	):
		return "wealthy"

	if (
		value_band == "premium"
		or price >= 250000
	):
		return "comfortable"

	return "working"


func _amenity_target_count(
	price: int,
	economic_tier: String,
	category: String,
	source: Dictionary
) -> int:
	var count: int = 4

	match economic_tier:
		"comfortable":
			count = 6
		"wealthy":
			count = 9
		"elite":
			count = 12

	if category in [
		"commercial",
		"government",
		"military",
		"royal"
	]:
		count += 1

	if price <= 0:
		count = maxi(3, count - 1)

	if bool(
		source.get(
			"minimal_amenity_contract",
			false
		)
	):
		count = mini(count, 4)

	return mini(
		MAX_SYNTHESIZED_AMENITIES,
		count
	)


func _resolve_era_key(
	source: Dictionary,
	context: Dictionary
) -> String:
	var text: String = "%s %s %s" % [
		str(context.get("era_key", "")),
		str(source.get("era", "")),
		str(source.get("era_keys", []))
	]
	text = text.to_lower()

	if text.find("ancient") >= 0:
		return "ancient"

	if text.find("medieval") >= 0:
		return "medieval"

	if text.find("industrial") >= 0:
		return "industrial"

	if text.find("future") >= 0:
		return "future"

	if gs != null and gs.era != null:
		var current_text: String = str(
			gs.era.name
		).to_lower()

		if current_text.find("ancient") >= 0:
			return "ancient"

		if current_text.find("medieval") >= 0:
			return "medieval"

		if current_text.find("industrial") >= 0:
			return "industrial"

		if current_text.find("future") >= 0:
			return "future"

	return "modern"


func _resolve_realm_key(
	actor: Person,
	source: Dictionary,
	context: Dictionary
) -> String:
	var parts: Array = [
		str(context.get("realm_name", "")),
		str(context.get("region", "")),
		str(source.get("realm_name", "")),
		str(source.get("region", "")),
		str(source.get("country", ""))
	]

	if actor != null:
		parts.append(str(actor.home_country))
		parts.append(str(actor.home_city))
		parts.append(str(actor.bending_nation))

	return " ".join(parts).strip_edges().to_lower()


func _resolve_neighborhood(
	source: Dictionary,
	context: Dictionary
) -> String:
	var explicit: String = str(
		context.get(
			"neighborhood",
			source.get("neighborhood", "")
		)
	).strip_edges().to_lower()

	if explicit != "":
		return explicit

	var tags: Array = _safe_array(
		source.get("feature_tags", [])
	)

	for candidate in [
		"urban",
		"suburban",
		"rural",
		"waterfront",
		"industrial",
		"forest",
		"coastal",
		"farm"
	]:
		if tags.has(candidate):
			return candidate

	return "mixed"


func _resolve_construction_quality(
	source: Dictionary,
	context: Dictionary,
	economic_tier: String
) -> String:
	var explicit: String = str(
		context.get(
			"construction_quality",
			source.get(
				"construction_quality",
				""
			)
		)
	).strip_edges().to_lower()

	if explicit != "":
		return explicit

	if economic_tier == "elite":
		return "masterwork"

	if economic_tier == "wealthy":
		return "premium"

	if economic_tier == "comfortable":
		return "standard"

	return "basic"


func _historical_technology_level(
	era_key: String,
	source: Dictionary
) -> String:
	var explicit: String = str(
		source.get(
			"historical_technology_level",
			""
		)
	).strip_edges()

	if explicit != "":
		return explicit

	match era_key:
		"ancient":
			return "handcraft_fire_well_and_animal_power"
		"medieval":
			return "masonry_forge_waterwheel_and_animal_power"
		"industrial":
			return "steam_gas_telegraph_and_early_electricity"
		"future":
			return "autonomous_quantum_nanite_and_offworld"
		_:
			return "electric_digital_networked_and_motorized"


func _resolve_lifestyle_modifiers(
	actor: Person,
	source: Dictionary,
	context: Dictionary
) -> Array:
	var out: Array = _safe_array(
		context.get("lifestyle_modifiers", [])
	)
	var tags: Array = _safe_array(
		source.get("feature_tags", [])
	)

	for candidate in [
		"family",
		"technology",
		"luxury",
		"craft",
		"eco",
		"religious",
		"military"
	]:
		if (
			tags.has(candidate)
			and not out.has(candidate)
		):
			out.append(candidate)

	if actor != null:
		if (
			actor.children.size() > 0
			and not out.has("family")
		):
			out.append("family")

		if (
			int(actor.bank_balance) >= 750000
			and not out.has("luxury")
		):
			out.append("luxury")

	return out


func _makeover_cost_for_amenity(
	amenity: Dictionary,
	property_contract: Dictionary,
	economic_tier: String
) -> int:
	var base_cost: int = maxi(
		0,
		int(amenity.get("base_cost", 0))
	)
	var property_value: int = maxi(
		0,
		int(
			property_contract.get(
				"value",
				property_contract.get("price", 0)
			)
		)
	)
	var scale: float = 1.0

	match economic_tier:
		"comfortable":
			scale = 1.15
		"wealthy":
			scale = 1.35
		"elite":
			scale = 1.65

	var value_floor: int = int(
		round(
			float(property_value) * 0.004
		)
	)

	return maxi(
		1,
		int(
			round(
				float(
					maxi(
						base_cost,
						value_floor
					)
				) * scale
			)
		)
	)


func _contract_cache_key(
	actor: Person,
	source: Dictionary,
	era_key: String,
	realm_key: String,
	property_type: String,
	economic_tier: String,
	neighborhood: String,
	construction_quality: String,
	price: int
) -> String:
	return "%d|%s|%s|%s|%s|%s|%s|%d|%d|%s" % [
		int(actor.id) if actor != null else -1,
		str(
			source.get(
				"template_id",
				source.get("id", "")
			)
		),
		era_key,
		realm_key,
		property_type,
		economic_tier,
		neighborhood,
		price,
		int(gs.year) if gs != null else 0,
		construction_quality
	]


func _amenity_summary(amenity_names: Array) -> String:
	if amenity_names.is_empty():
		return "No resolved amenities"

	var visible: Array = amenity_names.slice(
		0,
		mini(5, amenity_names.size())
	)
	var summary: String = " • ".join(visible)

	if amenity_names.size() > visible.size():
		summary += " • +%d more" % (
			amenity_names.size()
			- visible.size()
		)

	return summary


func _format_money(value: int) -> String:
	var digits: String = str(maxi(0, value))
	var out: String = ""

	while digits.length() > 3:
		out = ",%s%s" % [
			digits.right(3),
			out
		]
		digits = digits.left(
			digits.length() - 3
		)

	return "$%s%s" % [digits, out]


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(value: Variant) -> Array:
	return (
		(value as Array).duplicate(true)
		if typeof(value) == TYPE_ARRAY
		else []
	)