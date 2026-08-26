extends Resource
class_name EraEngine

var gs
const TIMELINE_MIN_YEAR:= -1000000000
const TIMELINE_MAX_YEAR:= 1000000000

var era_contract_cache: Dictionary = {}
var era_contract_signature: String = ""

func _init(_gs):
	gs = _gs
	_refresh_data_driven_era_cache(true)





var eras = {
	"Ancient": {
		"name": "Ancient Era",
		"start_year": TIMELINE_MIN_YEAR,
		"end_year": 499,
		"rights": {
			"women_can_education": false,
		},
		"job_pool": [
			"Farmer",
			"Hunter",
			"Fletcher",
			"Fisher",
			"Stonecutter",
			"Caravan Merchant",
			"Scribe",
			"Soldier",
			"Potter",
			"Weaver",
			"Temple Attendant",
			"Priest",
			"Oracle",
			"Slave Laborer",
			"Chariot Maker",
			"Charioteer",
			"Bronze Smith",
			"Copper Smith",
			"Jeweler",
			"Mason",
			"Brickmaker",
			"Water Carrier",
			"Goatherd",
			"Shepherd",
			"Olive Presser",
			"Winemaker",
			"Perfume Maker",
			"Papyrus Maker",
			"Dock Worker",
			"Shipwright",
			"Tax Collector",
			"Royal Guard",
			"Palace Servant",
			"Herbal Healer",
			"Midwife",
			"Astrologer",
			"Astronomer",
			"Scholar",
			"Builder",
			"Metal Trader"
		],
		"birth_events": [
			"I was born beneath a scorching sun in the Ancient World.",
			"My birth came during a time when empires rose and fell in bloody succession."
		],
		"conception_stories": [
			"I was conceived after my parents shared watered wine during a harvest festival.",
			"I was conceived behind a temple after my parents argued about grain taxes.",
			"I was conceived the night a comet passed overhead and everyone panicked.",
			"I was conceived inside a storage hut because the oxen took the sleeping mats.",
			"I was conceived after my parents survived a sandstorm and decided life was short."
		],
		"world_events": [
			"A neighboring tribe raided your village.",
			"A local ruler demanded new taxes.",
			"You witnessed a sacred ritual performed in your town."
		],
		"modifiers": {
			"lifespan_bonus": -20,
			"disease_rate": 2.0,
			"education_access": 0.2
		}
	},

	"Medieval": {
		"name": "Medieval Era",
		"start_year": 500,
		"end_year": 1799,
		"rights": {
			"women_can_education": false,
		},
		"job_pool": [
			"Peasant Farmer",
			"Blacksmith",
			"Baker",
			"Knight",
			"Priest",
			"Mason",
			"Town Guard",
			"Herbalist",
			"Monk",
			"Nun",
			"Stable Hand",
			"Falconer",
			"Bowyer",
			"Fletcher",
			"Armorer",
			"Swordsmith",
			"Tailor",
			"Weaver",
			"Innkeeper",
			"Brewer",
			"Cook",
			"Messenger",
			"Page",
			"Squire",
			"Executioner",
			"Tax Collector",
			"Royal Servant",
			"Jester",
			"Minstrel",
			"Carpenter",
			"Wheelwright",
			"Leatherworker",
			"Chandler",
			"Fishmonger",
			"Merchant",
			"Abbey Scholar",
			"Village Healer",
			"Gravedigger",
			"Apprentice Mason",
			"Town Crier"
		],
		"birth_events": [
			"I was born in a smoky cottage beneath the shadow of a crumbling castle.",
			"My birth came during a time of wandering knights and spreading plagues."
		],
		"conception_stories": [
			"I was conceived after my parents hid together during a bandit raid.",
			"I was conceived in a barn after the festival ale ran out.",
			"I was conceived when the church bell malfunctioned and rang all night.",
			"I was conceived the night a minstrel stayed in town and everyone was in a good mood.",
			"I was conceived after my father misfired a catapult during training and needed comforting."
		],
		"world_events": [
			"A plague spread through the region.",
			"A new lord claimed power over your land.",
			"You saw a knight riding through your village."
		],
		"modifiers": {
			"lifespan_bonus": -15,
			"disease_rate": 1.75,
			"education_access": 0.3
		}
	},

	"Industrial": {
		"name": "Industrial Era",
		"start_year": 1800,
		"end_year": 1949,
		"rights": {
			"women_can_education": true,
		},
		"job_pool": [
			"Factory Worker",
			"Rail Engineer",
			"Coal Miner",
			"Seamstress",
			"Steel Worker",
			"Telegraph Operator",
			"Machinist",
			"Boilermaker",
			"Railroad Conductor",
			"Station Clerk",
			"Textile Worker",
			"Mill Worker",
			"Dock Laborer",
			"Shipbuilder",
			"Newspaper Boy",
			"Printer",
			"Bookkeeper",
			"Schoolteacher",
			"Pharmacist",
			"Doctor",
			"Nurse",
			"Factory Foreman",
			"Warehouse Laborer",
			"Street Sweeper",
			"Chimney Sweep",
			"Plumber",
			"Electrician",
			"Mechanic",
			"Barber",
			"Tailor",
			"Bank Clerk",
			"Office Typist",
			"Secretary",
			"Telephone Operator",
			"Milkman",
			"Shopkeeper",
			"Police Constable",
			"Detective",
			"Inventor",
			"Photographer"
		],
		"birth_events": [
			"I was born amid soot-darkened skies and the thunder of new machines.",
			"My birth came as the world surged into the age of industry."
		],
		"conception_stories": [
			"I was conceived when the factory whistle got stuck and everyone was released early.",
			"I was conceived after my parents celebrated my father's first steady paycheck.",
			"I was conceived during a blackout caused by overloaded power lines.",
			"I was conceived after my mother slipped on coal dust and my father helped her up.",
			"I was conceived because the apartment above theirs leaked boiling water and they had to share the only warm room."
		],
		"world_events": [
			"A factory in your town exploded.",
			"A labor strike shut down production.",
			"A traveling inventor demonstrated a new device."
		],
		"modifiers": {
			"lifespan_bonus": -5,
			"disease_rate": 1.3,
			"education_access": 0.6
		}
	},

	"Modern": {
		"name": "Modern Era",
		"start_year": 1950,
		"end_year": 2049,
		"rights": {
			"women_can_education": true,
		},
		"job_pool": [
			"Teacher",
			"Software Developer",
			"Manager",
			"Chef",
			"Mechanic",
			"Nurse",
			"Retail Worker",
			"Doctor",
			"Lawyer",
			"Police Officer",
			"Firefighter",
			"Paramedic",
			"Accountant",
			"Bank Teller",
			"Financial Analyst",
			"Journalist",
			"Content Creator",
			"Streamer",
			"Actor",
			"Music Producer",
			"Rapper",
			"Photographer",
			"Graphic Designer",
			"Video Editor",
			"Game Developer",
			"Construction Worker",
			"Electrician",
			"Plumber",
			"Truck Driver",
			"Delivery Driver",
			"Warehouse Associate",
			"Restaurant Server",
			"Fast Food Worker",
			"Sales Associate",
			"Customer Support Agent",
			"Real Estate Agent",
			"Social Worker",
			"Therapist",
			"Personal Trainer",
			"Professor",
			"Pharmacist",
			"Dentist",
			"Pilot",
			"Flight Attendant",
			"Entrepreneur"
		],
		"birth_events": [
			"I was born in the modern world, surrounded by technology and asphalt.",
			"My birth came during a time of rapid social change."
		],
		"conception_stories": [
			"I was conceived after my parents’ power went out and they had nothing else to do.",
			"I was conceived in the back of a Honda Civic after a concert.",
			"I was conceived because my parents tried 'just one more drink.'",
			"I was conceived during a hotel fire drill.",
			"I was conceived on New Year's Eve while everyone was counting down."
		],
		"world_events": [
			"Global tensions rose between major superpowers.",
			"A new piece of everyday tech was invented.",
			"A viral meme spread worldwide."
		],
		"modifiers": {
			"lifespan_bonus": 0,
			"disease_rate": 1.0,
			"education_access": 1.0
		}
	},

	"Future": {
		"name": "Future Era",
		"start_year": 2050,
		"end_year": TIMELINE_MAX_YEAR,
		"rights": {
			"women_can_education": true,
		},
		"job_pool": [
			"Cybernetic Engineer",
			"Drone Pilot",
			"Data-Harvester",
			"AI Therapist",
			"Terraformer",
			"Nanotech Surgeon",
			"Memory Architect",
			"Quantum Programmer",
			"Orbital Traffic Controller",
			"Atmosphere Technician",
			"Climate Dome Engineer",
			"Robot Rights Lawyer",
			"Synthetic Chef",
			"Genetic Sculptor",
			"Nanobot Mechanic",
			"Gravity Systems Technician",
			"Holo-Designer",
			"Neural Interface Developer",
			"Spaceport Security Officer",
			"Deep Space Miner",
			"Planetary Surveyor",
			"Asteroid Prospector",
			"Virtual World Builder",
			"Consciousness Archivist",
			"Android Psychologist",
			"Solar Grid Operator",
			"Exoplanet Botanist",
			"Biofabrication Specialist",
			"Cybercrime Investigator",
			"Quantum Courier",
			"Drone Fleet Supervisor",
			"Lunar Construction Worker",
			"Mars Habitat Planner",
			"Teleportation Safety Inspector",
			"Stellar Cartographer",
			"Augmentation Consultant",
			"Anti-Virus Systems Analyst",
			"Simulation Teacher",
			"Fusion Reactor Operator",
			"Off-World Diplomat"
		],
		"birth_events": [
			"I was born beneath neon skylines and humming starships.",
			"My birth came in an age where humans reshape planets."
		],
		"conception_stories": [
			"I was conceived when my parents' holo-pods synced incorrectly.",
			"I was conceived after a gravity malfunction trapped them in the same room.",
			"I was conceived during a teleportation outage that stranded them together.",
			"I was conceived when their nanobot assistant misread 'romantic lighting' as 'mandatory bonding protocol.'",
			"I was conceived inside a floating sky capsule during a meteor shower."
		],
		"world_events": [
			"A rogue AI attempted to seize control of transport systems.",
			"Your city upgraded its climate-dome shielding.",
			"A cyber virus forced schools to temporarily shut down."
		],
		"modifiers": {
			"lifespan_bonus": 25,
			"disease_rate": 0.6,
			"education_access": 1.5
		}
	}
}





func choose_era(
	player_settings: Dictionary
) -> Dictionary:
	if (
		gs != null
		and gs.era_contract_engine != null
	):
		return gs.era_contract_engine.choose_era(
			player_settings
		)


	_refresh_data_driven_era_cache()

	if player_settings.has("era"):
		var requested_era: String = str(
			player_settings.get(
				"era",
				""
			)
		).strip_edges()
		var requested_contract: Dictionary = (
			_get_era_contract_by_key_or_name(
				requested_era
			)
		)

		if not requested_contract.is_empty():
			return requested_contract

	if randi() % 100 < 5:
		var keys: Array = era_contract_cache.keys()

		if keys.is_empty():
			keys = eras.keys()

		var pick: String = str(
			keys [
				randi() % keys.size()
			]
		)
		var picked_contract: Dictionary = (
			_get_era_contract_by_key_or_name(
				pick
			)
		)

		if not picked_contract.is_empty():
			return picked_contract

	return _era_from_year(gs.year)





func _era_from_year(
	year: int
) -> Dictionary:
	if (
		gs != null
		and gs.era_contract_engine != null
	):
		var base_contract: Dictionary = (
			gs.era_contract_engine
			.resolve_base_era_from_year(
				year
			)
		)

		return (
			gs.era_contract_engine
			.apply_active_overlay(
				base_contract,
				{
					"source": (
						"era_engine._era_from_year"
					)
				}
			)
		)

	_refresh_data_driven_era_cache()

	for era_key in _get_ordered_era_contract_keys():
		var era: Dictionary = (
			era_contract_cache.get(
				era_key,
				{}
			)
		)

		if (
			year >= int(
				era.get(
					"start_year",
					TIMELINE_MIN_YEAR
				)
			)
			and year <= int(
				era.get(
					"end_year",
					TIMELINE_MAX_YEAR
				)
			)
		):
			return era.duplicate(true)

	if era_contract_cache.has("Modern"):
		return (
			era_contract_cache ["Modern"]
			.duplicate(true)
		)

	return eras ["Modern"].duplicate(true)




func get_job_pool() -> Array:
	var era: Dictionary = _current_era_contract()

	var raw_jobs: Array = _safe_runtime_string_array(
		era.get(
			"job_pool",
			[]
		)
	)

	var ordinary_jobs: Array = []

	for raw_job_name in raw_jobs:
		var job_name: String = str(
			raw_job_name
		).strip_edges()

		if job_name == "":
			continue

		if _ordinary_job_pool_entry_is_external_special(
			job_name
		):
			continue

		ordinary_jobs.append(
			job_name
		)

	return ordinary_jobs
func _ordinary_job_pool_entry_is_external_special(
	job_name: String
) -> bool:
	var normalized: String = str(
		job_name
	).strip_edges().to_lower()

	for token in [
		"-",
		"_"
	]:
		normalized = normalized.replace(
			token,
			" "
		)

	while "  " in normalized:
		normalized = normalized.replace(
			"  ",
			" "
		)

	return normalized in [
		"rapper",
		"singer",
		"musician",
		"music producer",
		"recording artist",
		"pop star",
		"actor",
		"streamer",
		"content creator",
		"influencer",
		"boxer",
		"prizefighter",
		"professional athlete",
		"athlete"
	]


func get_part_time_job_pool() -> Array:
	var era: Dictionary = _current_era_contract()
	var contract_jobs: Array = _safe_runtime_string_array(era.get("part_time_job_pool", []))
	if not contract_jobs.is_empty():
		return contract_jobs

	if gs == null or gs.era == null:
		return []

	match str(gs.era.get("name", "")):
		"Ancient Era":
			return [
				"Water Carrier Helper",
				"Olive Picker",
				"Market Runner",
				"Stable Hand",
				"Goatherd Helper",
				"Temple Sweeper"
			]
		"Medieval Era":
			return [
				"Stable Hand",
				"Bakery Helper",
				"Apprentice Blacksmith",
				"Messenger",
				"Farm Hand",
				"Page"
			]
		"Industrial Era":
			return [
				"Newsboy",
				"Factory Helper",
				"Rail Yard Runner",
				"Shop Assistant",
				"Mill Helper",
				"Apprentice Printer"
			]
		"Modern Era":
			return [
				"Cashier",
				"Barista",
				"Fast Food Worker",
				"Retail Worker",
				"Grocery Bagger",
				"Lifeguard",
				"Dog Walker",
				"Tutor"
			]
		"Future Era":
			return [
				"Drone Runner",
				"VR Arcade Attendant",
				"Nano Lab Assistant",
				"Cafe Server",
				"Retail Associate",
				"Courier"
			]
		_:
			return []


func get_famous_career_tracks() -> Array:
	var era: Dictionary = _current_era_contract()
	var contract_tracks: Array = _safe_runtime_string_array(era.get("famous_career_tracks", []))
	if not contract_tracks.is_empty():
		return contract_tracks

	if gs == null or gs.era == null:
		return []

	match str(gs.era.get("name", "")):
		"Ancient Era":
			return [
				"Ruler",
				"General",
				"High Priest",
				"Oracle",
				"Philosopher"
			]
		"Medieval Era":
			return [
				"King",
				"Knight Legend",
				"Master Bard",
				"Royal Court Performer",
				"Famous Explorer"
			]
		"Industrial Era":
			return [
				"Inventor",
				"Magnate",
				"Stage Performer",
				"Prizefighter",
				"Political Leader"
			]
		"Modern Era":
			return [
				"Actor",
				"Musician",
				"Athlete",
				"Boxer",
				"Politician",
				"Influencer"
			]
		"Future Era":
			return [
				"Holo Star",
				"Pro Arena Fighter",
				"Worldstream Idol",
				"Tech Mogul",
				"Galactic Politician"
			]
		_:
			return []


func get_world_events() -> Array:
	var era: Dictionary = _current_era_contract()
	return _safe_runtime_string_array(era.get("world_events", []))


func get_birth_event() -> String:
	var era: Dictionary = _current_era_contract()
	var arr: Array = _safe_runtime_string_array(era.get("birth_events", []))
	if arr.size() == 0:
		return "I was born into a world still deciding what kind of age it wanted to become."
	return arr [randi() % arr.size()]


func get_disease_rate() -> float:
	var era: Dictionary = _current_era_contract()
	var modifiers: Dictionary = era.get("modifiers", {})
	return float(modifiers.get("disease_rate", 1.0))


func get_lifespan_bonus() -> int:
	var era: Dictionary = _current_era_contract()
	var modifiers: Dictionary = era.get("modifiers", {})
	return int(modifiers.get("lifespan_bonus", 0))


func get_education_access() -> float:
	var era: Dictionary = _current_era_contract()
	var modifiers: Dictionary = era.get("modifiers", {})
	return float(modifiers.get("education_access", 1.0))


func rights() -> Dictionary:
	var era: Dictionary = _current_era_contract()
	return era.get("rights", {}).duplicate(true)





func get_birth_locations() -> Array:

	var contract_locations: Array = _safe_runtime_dictionary_array(_current_era_contract().get("birth_locations", []))
	if not contract_locations.is_empty():
		return contract_locations.duplicate(true)
	if gs.era.name == "Ancient Era":
		return [
			{ "city": "Babylon", "country": "Mesopotamia"},
			{ "city": "Ur", "country": "Mesopotamia"},
			{ "city": "Nineveh", "country": "Assyria"},
			{ "city": "Thebes", "country": "Ancient Egypt"},
			{ "city": "Memphis", "country": "Ancient Egypt"},
			{ "city": "Alexandria", "country": "Ptolemaic Egypt"},
			{ "city": "Sparta", "country": "Greece"},
			{ "city": "Athens", "country": "Greece"},
			{ "city": "Corinth", "country": "Greece"},
			{ "city": "Rome", "country": "Roman Republic"},
			{ "city": "Pompeii", "country": "Roman Empire"},
			{ "city": "Carthage", "country": "Carthaginian Empire"},
			{ "city": "Jerusalem", "country": "Judea"},
			{ "city": "Tyre", "country": "Phoenicia"},
			{ "city": "Persepolis", "country": "Persia"},
			{ "city": "Susa", "country": "Persia"},
			{ "city": "Xi'an", "country": "China"},
			{ "city": "Luoyang", "country": "China"},
			{ "city": "Pataliputra", "country": "Maurya Empire"},
			{ "city": "Mohenjo-daro", "country": "Indus Valley"},
			{ "city": "Teotihuacan", "country": "Mesoamerica"},
			{ "city": "Cusco", "country": "Andean Highlands"},
			{ "city": "Aksum", "country": "Kingdom of Aksum"},
			{ "city": "Timbuktu", "country": "Ancient Mali"},
			{ "city": "Byblos", "country": "Levant"}
		]

	if gs.era.name == "Medieval Era":
		return [
			{ "city": "Paris", "country": "Frankia"},
			{ "city": "London", "country": "England"},
			{ "city": "York", "country": "England"},
			{ "city": "Edinburgh", "country": "Scotland"},
			{ "city": "Dublin", "country": "Ireland"},
			{ "city": "Constantinople", "country": "Byzantine Empire"},
			{ "city": "Rome", "country": "Papal States"},
			{ "city": "Venice", "country": "Venetian Republic"},
			{ "city": "Florence", "country": "Italian States"},
			{ "city": "Cordoba", "country": "Al-Andalus"},
			{ "city": "Granada", "country": "Al-Andalus"},
			{ "city": "Lisbon", "country": "Portugal"},
			{ "city": "Prague", "country": "Bohemia"},
			{ "city": "Vienna", "country": "Austria"},
			{ "city": "Krakow", "country": "Poland"},
			{ "city": "Kyoto", "country": "Japan"},
			{ "city": "Kamakura", "country": "Japan"},
			{ "city": "Hangzhou", "country": "China"},
			{ "city": "Kaifeng", "country": "China"},
			{ "city": "Baghdad", "country": "Abbasid Caliphate"},
			{ "city": "Damascus", "country": "Levant"},
			{ "city": "Cairo", "country": "Mamluk Sultanate"},
			{ "city": "Timbuktu", "country": "Mali Empire"},
			{ "city": "Kilwa", "country": "Swahili Coast"},
			{ "city": "Samarkand", "country": "Timurid Realm"}
		]

	if gs.era.name == "Industrial Era":
		return [
			{ "city": "London", "country": "UK"},
			{ "city": "Manchester", "country": "UK"},
			{ "city": "Liverpool", "country": "UK"},
			{ "city": "Glasgow", "country": "UK"},
			{ "city": "New York", "country": "USA"},
			{ "city": "Boston", "country": "USA"},
			{ "city": "Chicago", "country": "USA"},
			{ "city": "Philadelphia", "country": "USA"},
			{ "city": "New Orleans", "country": "USA"},
			{ "city": "Detroit", "country": "USA"},
			{ "city": "Berlin", "country": "Germany"},
			{ "city": "Hamburg", "country": "Germany"},
			{ "city": "Munich", "country": "Germany"},
			{ "city": "Paris", "country": "France"},
			{ "city": "Lyon", "country": "France"},
			{ "city": "Moscow", "country": "Russia"},
			{ "city": "St. Petersburg", "country": "Russia"},
			{ "city": "Tokyo", "country": "Japan"},
			{ "city": "Osaka", "country": "Japan"},
			{ "city": "Shanghai", "country": "China"},
			{ "city": "Hong Kong", "country": "China"},
			{ "city": "Mumbai", "country": "India"},
			{ "city": "Cape Town", "country": "South Africa"},
			{ "city": "Buenos Aires", "country": "Argentina"},
			{ "city": "Mexico City", "country": "Mexico"}
		]

	if gs.era.name == "Modern Era":
		return [
			{ "city": "Chicago", "country": "USA"},
			{ "city": "New York", "country": "USA"},
			{ "city": "Los Angeles", "country": "USA"},
			{ "city": "Houston", "country": "USA"},
			{ "city": "Atlanta", "country": "USA"},
			{ "city": "Miami", "country": "USA"},
			{ "city": "Toronto", "country": "Canada"},
			{ "city": "Vancouver", "country": "Canada"},
			{ "city": "Mexico City", "country": "Mexico"},
			{ "city": "Sao Paulo", "country": "Brazil"},
			{ "city": "Buenos Aires", "country": "Argentina"},
			{ "city": "London", "country": "UK"},
			{ "city": "Manchester", "country": "UK"},
			{ "city": "Paris", "country": "France"},
			{ "city": "Berlin", "country": "Germany"},
			{ "city": "Madrid", "country": "Spain"},
			{ "city": "Rome", "country": "Italy"},
			{ "city": "Lagos", "country": "Nigeria"},
			{ "city": "Nairobi", "country": "Kenya"},
			{ "city": "Cairo", "country": "Egypt"},
			{ "city": "Johannesburg", "country": "South Africa"},
			{ "city": "Dubai", "country": "UAE"},
			{ "city": "Mumbai", "country": "India"},
			{ "city": "Delhi", "country": "India"},
			{ "city": "Seoul", "country": "South Korea"},
			{ "city": "Tokyo", "country": "Japan"},
			{ "city": "Osaka", "country": "Japan"},
			{ "city": "Beijing", "country": "China"},
			{ "city": "Shanghai", "country": "China"},
			{ "city": "Hong Kong", "country": "China"},
			{ "city": "Sydney", "country": "Australia"},
			{ "city": "Melbourne", "country": "Australia"},
			{ "city": "Auckland", "country": "New Zealand"}
		]

	if gs.era.name == "Future Era":
		return [
			{ "city": "Neo-Chicago", "country": "Federated Earth"},
			{ "city": "Neo-Houston", "country": "Federated Earth"},
			{ "city": "Atlantic Arcology", "country": "Pan-Ocean Union"},
			{ "city": "Pacific Spire", "country": "Pan-Ocean Union"},
			{ "city": "New Lagos Prime", "country": "Western Coalition"},
			{ "city": "Sahara Bloom", "country": "African Solar Union"},
			{ "city": "Cairo Zenith", "country": "African Solar Union"},
			{ "city": "Aurora Toronto", "country": "Northern Commonwealth"},
			{ "city": "New Kyoto", "country": "Pacific Alliance"},
			{ "city": "Shenzhen Skygrid", "country": "Eastern Nexus"},
			{ "city": "Mumbai Orbit Gate", "country": "Indian Ocean Confederacy"},
			{ "city": "Rio Verde Dome", "country": "South Atlantic League"},
			{ "city": "Andes Cloudport", "country": "South Atlantic League"},
			{ "city": "Lunaris", "country": "Moon Republic"},
			{ "city": "Sea of Tranquility Hub", "country": "Moon Republic"},
			{ "city": "Mars Sector 12", "country": "Sol Colony"},
			{ "city": "Olympus City", "country": "Sol Colony"},
			{ "city": "Valles Haven", "country": "Sol Colony"},
			{ "city": "Europa Station", "country": "Jovian Compact"},
			{ "city": "Titan Harbor", "country": "Saturn Ring Authority"},
			{ "city": "Mercury Shade Base", "country": "Inner Worlds Treaty"},
			{ "city": "Orbital Geneva", "country": "Low Earth Assembly"},
			{ "city": "Kepler Relay", "country": "Deep Space Network"},
			{ "city": "Helios Ring", "country": "Solar Accord"},
			{ "city": "Astra Vale", "country": "Western Coalition"}
		]

	return [
		{ "city": "Chicago", "country": "USA"}
	]
func _elemental_nation_birth_locations_for_era(_era_key: String) -> Array:
	if gs == null:
		return []

	var reality_mode: String = str(gs.reality_mode).strip_edges().to_lower()
	if typeof(gs.custom_settings) == TYPE_DICTIONARY:
		reality_mode = str(gs.custom_settings.get("reality_mode", reality_mode)).strip_edges().to_lower()

	if reality_mode == "realistic":
		return []

	if gs.has_method("is_feature_enabled") and not gs.is_feature_enabled("bending"):
		return []

	return [
		{ "city": "Ba Sing Se", "country": "Earth Kingdom"},
		{ "city": "Omashu", "country": "Earth Kingdom"},
		{ "city": "Zaofu", "country": "Earth Kingdom"},
		{ "city": "Gaoling", "country": "Earth Kingdom"},
		{ "city": "Makapu", "country": "Earth Kingdom"},
		{ "city": "Taku", "country": "Earth Kingdom"},
		{ "city": "Capital City", "country": "Fire Nation"},
		{ "city": "Caldera City", "country": "Fire Nation"},
		{ "city": "Ember Island", "country": "Fire Nation"},
		{ "city": "Yu Dao", "country": "Fire Nation"},
		{ "city": "Shu Jing", "country": "Fire Nation"},
		{ "city": "Hari Bulkan", "country": "Fire Nation"},
		{ "city": "Agna Qel'a", "country": "Northern Water Tribe"},
		{ "city": "Taku", "country": "Northern Water Tribe"},
		{ "city": "Ice Dock", "country": "Northern Water Tribe"},
		{ "city": "Wolf Cove", "country": "Southern Water Tribe"},
		{ "city": "Whaletail Harbor", "country": "Southern Water Tribe"},
		{ "city": "Glacier Camp", "country": "Southern Water Tribe"},
		{ "city": "Northern Monastery", "country": "Northern Air Temple"},
		{ "city": "Northern Sanctuary", "country": "Northern Air Temple"},
		{ "city": "Southern Monastery", "country": "Southern Air Temple"},
		{ "city": "Southern Sanctuary", "country": "Southern Air Temple"},
		{ "city": "Eastern Spires", "country": "Eastern Air Temple"},
		{ "city": "Eastern Sanctuary", "country": "Eastern Air Temple"},
		{ "city": "Western Cloisters", "country": "Western Air Temple"},
		{ "city": "Western Sanctuary", "country": "Western Air Temple"}
	]
func _canonical_birth_location_country_name(
	era_key: String,
	city_name: String,
	country_name: String
) -> String:
	var era: String = _normalize_era_lookup_key(era_key)
	var city_key: String = str(city_name).strip_edges().to_lower()
	var country_key: String = str(country_name).strip_edges().to_lower()

	if country_key in ["usa", "united states of america"]:
		return "United States"

	if country_key in ["uk", "great britain", "britain"]:
		return "United Kingdom"

	if country_key in ["uae", "united arab emirates"]:
		return "United Arab Emirates"

	if era == "ancient":
		if country_key in ["rome", "roman republic", "roman state"]:
			return "Roman Empire"

		if country_key in ["judea", "kingdom of israel"]:
			return "Israel"

		if country_key == "egypt":
			return "Ancient Egypt"

	if era == "medieval":
		if country_key == "byzantium":
			return "Byzantine Empire"

		if country_key == "mali":
			return "Mali Empire"

		if country_key in ["mongol realm", "mongol state"]:
			return "Mongol Empire"

	if era == "industrial":
		if country_key == "england":
			return "United Kingdom"

		if country_key == "germany":
			return "German Empire"

		if country_key == "russia":
			return "Russian Empire"

	if country_key == "":
		if era == "ancient" and city_key in ["rome", "pompeii"]:
			return "Roman Empire"

		return ""

	return str(country_name).strip_edges()


func _canonical_birth_location_expansion_for_era(
	era_key: String,
	era_contract: Dictionary = {}
) -> Array:
	var era: String = _normalize_era_lookup_key(era_key)

	if era == "":
		era = _normalize_era_lookup_key(str(era_contract.get("id", "")))

	if era == "":
		era = _normalize_era_lookup_key(str(era_contract.get("name", "")))

	var packed_rows_by_era: Dictionary = {
		"ancient": [
			"Babylon|Mesopotamia",
			"Ur|Mesopotamia",
			"Nineveh|Assyria",
			"Jerusalem|Israel",
			"Samaria|Israel",
			"Thebes|Ancient Egypt",
			"Memphis|Ancient Egypt",
			"Alexandria|Ptolemaic Egypt",
			"Athens|Greece",
			"Sparta|Greece",
			"Corinth|Greece",
			"Rome|Roman Empire",
			"Pompeii|Roman Empire",
			"Carthage|Carthaginian Empire",
			"Tyre|Phoenicia",
			"Byblos|Phoenicia",
			"Persepolis|Persia",
			"Susa|Persia",
			"Chang'an|China",
			"Luoyang|China",
			"Pataliputra|Maurya Empire",
			"Mohenjo-daro|Indus Valley",
			"Meroë|Kush",
			"Aksum|Kingdom of Aksum",
			"Petra|Nabataea",
			"Mecca|Arabia",
			"Teotihuacan|Mesoamerica",
			"Cusco|Andean Highlands",
			"Gyeongju|Ancient Korea",
			"Nara|Yamato Japan"
		],
		"medieval": [
			"London|England",
			"York|England",
			"Edinburgh|Scotland",
			"Dublin|Ireland",
			"Paris|France",
			"Orléans|France",
			"Aachen|Holy Roman Empire",
			"Vienna|Holy Roman Empire",
			"Constantinople|Byzantine Empire",
			"Rome|Papal States",
			"Venice|Venetian Republic",
			"Florence|Italian States",
			"Lisbon|Portugal",
			"Toledo|Castile",
			"Cordoba|Al-Andalus",
			"Granada|Al-Andalus",
			"Prague|Bohemia",
			"Krakow|Poland",
			"Kyiv|Kievan Rus",
			"Karakorum|Mongolia",
			"Khanbaliq|Mongol Empire",
			"Kyoto|Japan",
			"Kamakura|Japan",
			"Hangzhou|China",
			"Kaifeng|China",
			"Baghdad|Abbasid Caliphate",
			"Damascus|Levant",
			"Jerusalem|Kingdom of Jerusalem",
			"Cairo|Mamluk Sultanate",
			"Delhi|Delhi Sultanate",
			"Samarkand|Timurid Realm",
			"Timbuktu|Mali Empire",
			"Niani|Mali Empire",
			"Lalibela|Ethiopia",
			"Kilwa|Swahili Coast",
			"Angkor|Khmer Empire",
			"Tenochtitlan|Aztec Empire",
			"Cusco|Inca Empire"
		],
		"industrial": [
			"London|United Kingdom",
			"Manchester|United Kingdom",
			"Liverpool|United Kingdom",
			"Glasgow|United Kingdom",
			"New York|United States",
			"Boston|United States",
			"Chicago|United States",
			"Philadelphia|United States",
			"New Orleans|United States",
			"Detroit|United States",
			"Paris|France",
			"Lyon|France",
			"Berlin|German Empire",
			"Hamburg|German Empire",
			"Munich|German Empire",
			"Vienna|Austria-Hungary",
			"Budapest|Austria-Hungary",
			"Moscow|Russian Empire",
			"St. Petersburg|Russian Empire",
			"Istanbul|Ottoman Empire",
			"Rome|Italy",
			"Madrid|Spain",
			"Brussels|Belgium",
			"Amsterdam|Netherlands",
			"Tokyo|Japan",
			"Osaka|Japan",
			"Beijing|Qing China",
			"Shanghai|Qing China",
			"Mumbai|British India",
			"Delhi|British India",
			"Cairo|Egypt",
			"Cape Town|South Africa",
			"Johannesburg|South Africa",
			"São Paulo|Brazil",
			"Buenos Aires|Argentina",
			"Mexico City|Mexico",
			"Toronto|Canada",
			"Sydney|Australia",
			"Ulaanbaatar|Mongolia"
		],
		"modern": [
			"New York City|United States",
			"Los Angeles|United States",
			"Chicago|United States",
			"Houston|United States",
			"Atlanta|United States",
			"Toronto|Canada",
			"Vancouver|Canada",
			"Mexico City|Mexico",
			"São Paulo|Brazil",
			"Rio de Janeiro|Brazil",
			"Buenos Aires|Argentina",
			"Santiago|Chile",
			"Bogotá|Colombia",
			"Lima|Peru",
			"London|United Kingdom",
			"Dublin|Ireland",
			"Paris|France",
			"Berlin|Germany",
			"Madrid|Spain",
			"Lisbon|Portugal",
			"Rome|Italy",
			"Amsterdam|Netherlands",
			"Brussels|Belgium",
			"Oslo|Norway",
			"Stockholm|Sweden",
			"Helsinki|Finland",
			"Warsaw|Poland",
			"Kyiv|Ukraine",
			"Moscow|Russia",
			"Athens|Greece",
			"Istanbul|Turkey",
			"Jerusalem|Israel",
			"Tel Aviv|Israel",
			"Riyadh|Saudi Arabia",
			"Dubai|United Arab Emirates",
			"Cairo|Egypt",
			"Casablanca|Morocco",
			"Lagos|Nigeria",
			"Accra|Ghana",
			"Nairobi|Kenya",
			"Addis Ababa|Ethiopia",
			"Johannesburg|South Africa",
			"Mumbai|India",
			"Delhi|India",
			"Karachi|Pakistan",
			"Dhaka|Bangladesh",
			"Beijing|China",
			"Shanghai|China",
			"Ulaanbaatar|Mongolia",
			"Tokyo|Japan",
			"Osaka|Japan",
			"Seoul|South Korea",
			"Bangkok|Thailand",
			"Hanoi|Vietnam",
			"Manila|Philippines",
			"Jakarta|Indonesia",
			"Singapore|Singapore",
			"Sydney|Australia",
			"Melbourne|Australia",
			"Auckland|New Zealand"
		],
		"future": [
			"Neo-Chicago|Federated Earth",
			"Neo-Houston|Federated Earth",
			"Orbital Geneva|Low Earth Assembly",
			"Atlantic Arcology|Pan-Ocean Union",
			"Pacific Spire|Pan-Ocean Union",
			"Aurora Toronto|Northern Commonwealth",
			"New Lagos Prime|African Solar Union",
			"Sahara Bloom|African Solar Union",
			"Cairo Zenith|African Solar Union",
			"New Kyoto|Pacific Alliance",
			"Tokyo Arcology|Neo Japan",
			"Shenzhen Skygrid|Eastern Nexus",
			"Mumbai Orbit Gate|Indian Ocean Confederacy",
			"Rio Verde Dome|South Atlantic League",
			"Andes Cloudport|South Atlantic League",
			"Lunaris|Moon Republic",
			"Sea of Tranquility Hub|Moon Republic",
			"Olympus City|Sol Colony",
			"Mars Sector 12|Sol Colony",
			"Valles Haven|Sol Colony",
			"Europa Station|Jovian Compact",
			"Titan Harbor|Saturn Ring Authority",
			"Mercury Shade Base|Inner Worlds Treaty",
			"Kepler Relay|Deep Space Network",
			"Helios Ring|Solar Accord",
			"Astra Vale|Western Coalition"
		]
	}

	var packed_rows_raw: Variant = packed_rows_by_era.get(era, [])
	if typeof(packed_rows_raw) != TYPE_ARRAY:
		return []

	var out: Array = []

	for raw_pair in packed_rows_raw as Array:
		var pair: PackedStringArray = str(raw_pair).split("|", false, 1)
		if pair.size() != 2:
			continue

		var city_name: String = str(pair [0]).strip_edges()
		var country_name: String = str(pair [1]).strip_edges()

		if city_name == "" or country_name == "":
			continue

		out.append({
			"city": city_name,
			"country": country_name,
			"catalog_source": "era_engine_canonical_expansion"
		})

	return out
func _extended_canonical_birth_location_expansion_for_era(
	era_key: String,
	era_contract: Dictionary = {}
) -> Array:
	var era: String = _normalize_era_lookup_key(era_key)

	if era == "":
		era = _normalize_era_lookup_key(str(era_contract.get("id", "")))
	if era == "":
		era = _normalize_era_lookup_key(str(era_contract.get("name", "")))

	var packed_rows_by_era: Dictionary = {
		"ancient": [
			"Hattusa|Hittite Empire",
			"Kanesh|Hittite Empire",
			"Knossos|Minoan Crete",
			"Phaistos|Minoan Crete",
			"Mycenae|Mycenaean Greece",
			"Tiryns|Mycenaean Greece",
			"Syracuse|Greek Sicily",
			"Ephesus|Ionia",
			"Miletus|Ionia",
			"Antioch|Seleucid Empire",
			"Palmyra|Palmyrene Realm",
			"Sidon|Phoenicia",
			"Ugarit|Canaan",
			"Ashur|Assyria",
			"Kalhu|Assyria",
			"Lagash|Mesopotamia",
			"Eridu|Mesopotamia",
			"Nippur|Mesopotamia",
			"Mari|Mesopotamia",
			"Akkad|Akkadian Empire",
			"Ebla|Ancient Syria",
			"Jericho|Canaan",
			"Hebron|Israel",
			"Beersheba|Israel",
			"Gaza|Philistia",
			"Hecatompylos|Parthian Empire",
			"Ctesiphon|Parthian Empire",
			"Taxila|Gandhara",
			"Pushkalavati|Gandhara",
			"Varanasi|Mahajanapadas",
			"Ujjain|Avanti",
			"Madurai|Pandya Kingdom",
			"Anuradhapura|Ancient Sri Lanka",
			"Anyang|Shang China",
			"Chengdu|Shu",
			"Linzi|Qi",
			"Handan|Zhao",
			"Xianyang|Qin",
			"Pyeongyang|Goguryeo",
			"Gungnae|Goguryeo",
			"Gyeongju|Silla",
			"Izumo|Ancient Japan",
			"Monte Albán|Zapotec Civilization",
			"El Mirador|Maya Civilization",
			"Tikal|Maya Civilization",
			"Chavín de Huántar|Chavín Civilization",
			"Tiwanaku|Tiwanaku Civilization",
			"Caral|Norte Chico",
			"Great Zimbabwe|Early Southern Africa",
			"Kerma|Kingdom of Kerma"
		],
		"medieval": [
			"Fez|Morocco",
			"Marrakesh|Morocco",
			"Kairouan|Ifriqiya",
			"Tunis|Hafsid Sultanate",
			"Alexandria|Mamluk Sultanate",
			"Aleppo|Levant",
			"Mosul|Mesopotamia",
			"Isfahan|Persia",
			"Tabriz|Persia",
			"Bukhara|Central Asia",
			"Merv|Central Asia",
			"Herat|Khorasan",
			"Lahore|Delhi Sultanate",
			"Vijayanagara|Vijayanagara Empire",
			"Calicut|Kingdom of Calicut",
			"Thanjavur|Chola Realm",
			"Anuradhapura|Sri Lanka",
			"Bagan|Pagan Kingdom",
			"Ayutthaya|Ayutthaya Kingdom",
			"Trowulan|Majapahit Empire",
			"Malacca|Malacca Sultanate",
			"Thăng Long|Dai Viet",
			"Kaesong|Goryeo",
			"Seoul|Joseon",
			"Nanjing|Ming China",
			"Xi'an|China",
			"Quanzhou|China",
			"Guangzhou|China",
			"Novgorod|Novgorod Republic",
			"Moscow|Muscovy",
			"Stockholm|Sweden",
			"Bergen|Norway",
			"Reykjavík|Iceland",
			"Bruges|Flanders",
			"Ghent|Flanders",
			"Cologne|Holy Roman Empire",
			"Nuremberg|Holy Roman Empire",
			"Lübeck|Hanseatic League",
			"Seville|Castile",
			"Barcelona|Crown of Aragon",
			"Naples|Kingdom of Naples",
			"Palermo|Kingdom of Sicily",
			"Ragusa|Republic of Ragusa",
			"Sarajevo|Bosnia",
			"Belgrade|Serbia",
			"Sofia|Bulgarian Empire",
			"Vilnius|Grand Duchy of Lithuania",
			"Riga|Livonian Confederation",
			"Gao|Songhai Empire",
			"Benin City|Kingdom of Benin",
			"Ile-Ife|Yoruba Kingdoms",
			"Great Zimbabwe|Kingdom of Zimbabwe",
			"Mombasa|Swahili Coast",
			"Zanzibar|Swahili Coast",
			"Harar|Ethiopia"
		],
		"industrial": [
			"Birmingham|United Kingdom",
			"Leeds|United Kingdom",
			"Sheffield|United Kingdom",
			"Newcastle|United Kingdom",
			"Belfast|United Kingdom",
			"Pittsburgh|United States",
			"Cleveland|United States",
			"Baltimore|United States",
			"San Francisco|United States",
			"St. Louis|United States",
			"Buffalo|United States",
			"Montreal|Canada",
			"Quebec City|Canada",
			"Havana|Cuba",
			"Lima|Peru",
			"Santiago|Chile",
			"Rio de Janeiro|Brazil",
			"Recife|Brazil",
			"Salvador|Brazil",
			"Mexico City|Mexico",
			"Monterrey|Mexico",
			"Barcelona|Spain",
			"Milan|Italy",
			"Turin|Italy",
			"Naples|Italy",
			"Antwerp|Belgium",
			"Rotterdam|Netherlands",
			"Copenhagen|Denmark",
			"Stockholm|Sweden",
			"Oslo|Norway",
			"Warsaw|Russian Empire",
			"Prague|Austria-Hungary",
			"Zurich|Switzerland",
			"Geneva|Switzerland",
			"Athens|Greece",
			"Thessaloniki|Ottoman Empire",
			"Alexandria|Egypt",
			"Lagos|Nigeria",
			"Accra|Gold Coast",
			"Nairobi|British East Africa",
			"Zanzibar City|Zanzibar",
			"Kolkata|British India",
			"Chennai|British India",
			"Karachi|British India",
			"Lahore|British India",
			"Hong Kong|British Hong Kong",
			"Tianjin|Qing China",
			"Guangzhou|Qing China",
			"Wuhan|Qing China",
			"Seoul|Korea",
			"Yokohama|Japan",
			"Kyoto|Japan",
			"Melbourne|Australia",
			"Brisbane|Australia",
			"Auckland|New Zealand",
			"Christchurch|New Zealand"
		],
		"modern": [
			"Washington, DC|United States",
			"Miami|United States",
			"Seattle|United States",
			"San Francisco|United States",
			"Boston|United States",
			"Detroit|United States",
			"New Orleans|United States",
			"Phoenix|United States",
			"Denver|United States",
			"Montreal|Canada",
			"Calgary|Canada",
			"Ottawa|Canada",
			"Guadalajara|Mexico",
			"Monterrey|Mexico",
			"Havana|Cuba",
			"Kingston|Jamaica",
			"Panama City|Panama",
			"San José|Costa Rica",
			"Caracas|Venezuela",
			"Quito|Ecuador",
			"Medellín|Colombia",
			"Montevideo|Uruguay",
			"La Paz|Bolivia",
			"Asunción|Paraguay",
			"Brasília|Brazil",
			"Salvador|Brazil",
			"Recife|Brazil",
			"Manchester|United Kingdom",
			"Glasgow|United Kingdom",
			"Birmingham|United Kingdom",
			"Lyon|France",
			"Marseille|France",
			"Munich|Germany",
			"Hamburg|Germany",
			"Frankfurt|Germany",
			"Barcelona|Spain",
			"Valencia|Spain",
			"Milan|Italy",
			"Naples|Italy",
			"Vienna|Austria",
			"Zurich|Switzerland",
			"Geneva|Switzerland",
			"Copenhagen|Denmark",
			"Reykjavík|Iceland",
			"Prague|Czech Republic",
			"Budapest|Hungary",
			"Bucharest|Romania",
			"Sofia|Bulgaria",
			"Belgrade|Serbia",
			"Zagreb|Croatia",
			"Sarajevo|Bosnia and Herzegovina",
			"Tbilisi|Georgia",
			"Yerevan|Armenia",
			"Baku|Azerbaijan",
			"Beirut|Lebanon",
			"Amman|Jordan",
			"Baghdad|Iraq",
			"Basra|Iraq",
			"Tehran|Iran",
			"Isfahan|Iran",
			"Doha|Qatar",
			"Abu Dhabi|United Arab Emirates",
			"Kuwait City|Kuwait",
			"Muscat|Oman",
			"Jeddah|Saudi Arabia",
			"Damascus|Syria",
			"Tunis|Tunisia",
			"Algiers|Algeria",
			"Rabat|Morocco",
			"Dakar|Senegal",
			"Abidjan|Ivory Coast",
			"Monrovia|Liberia",
			"Freetown|Sierra Leone",
			"Kinshasa|Democratic Republic of the Congo",
			"Luanda|Angola",
			"Kampala|Uganda",
			"Kigali|Rwanda",
			"Dar es Salaam|Tanzania",
			"Harare|Zimbabwe",
			"Lusaka|Zambia",
			"Maputo|Mozambique",
			"Gaborone|Botswana",
			"Windhoek|Namibia",
			"Cape Town|South Africa",
			"Pretoria|South Africa",
			"Chennai|India",
			"Bengaluru|India",
			"Hyderabad|India",
			"Kolkata|India",
			"Lahore|Pakistan",
			"Islamabad|Pakistan",
			"Kathmandu|Nepal",
			"Colombo|Sri Lanka",
			"Yangon|Myanmar",
			"Phnom Penh|Cambodia",
			"Kuala Lumpur|Malaysia",
			"Taipei|Taiwan",
			"Hong Kong|Hong Kong",
			"Guangzhou|China",
			"Shenzhen|China",
			"Chengdu|China",
			"Wuhan|China",
			"Busan|South Korea",
			"Pyongyang|North Korea",
			"Sapporo|Japan",
			"Fukuoka|Japan",
			"Perth|Australia",
			"Brisbane|Australia",
			"Wellington|New Zealand",
			"Suva|Fiji",
			"Port Moresby|Papua New Guinea"
		],
		"future": [
			"New Rome Arcology|Mediterranean Compact",
			"Mesopotamia Restoration Zone|Fertile Crescent Union",
			"Jerusalem Vertical District|Levant Accord",
			"Ulaanbaatar Climate Dome|Mongolian Federation",
			"Neo London|Northern Commonwealth",
			"Paris Halo|European Continuum",
			"Berlin Nexus|European Continuum",
			"Alpine Vault|European Continuum",
			"New Lagos Prime|African Solar Union",
			"Accra Lightport|African Solar Union",
			"Nairobi Canopy|African Solar Union",
			"Addis Skyterrace|African Solar Union",
			"Cape Aurora|African Solar Union",
			"Kinshasa Greenbelt|African Solar Union",
			"Neo Delhi|Indian Ocean Confederacy",
			"Mumbai Orbit Gate|Indian Ocean Confederacy",
			"Bengaluru Cognition District|Indian Ocean Confederacy",
			"Colombo Sea Wall|Indian Ocean Confederacy",
			"Beijing Stratosphere|Eastern Nexus",
			"Shanghai Vertical Coast|Eastern Nexus",
			"Shenzhen Skygrid|Eastern Nexus",
			"Chengdu Habitat Ring|Eastern Nexus",
			"Seoul Quantum Ward|Pacific Alliance",
			"Busan Ocean Stack|Pacific Alliance",
			"New Kyoto|Pacific Alliance",
			"Tokyo Arcology|Neo Japan",
			"Osaka Megalattice|Neo Japan",
			"Manila Reef City|Pacific Alliance",
			"Jakarta Floating Capital|Equatorial Union",
			"Singapore Helix|Equatorial Union",
			"Bangkok Hydrospire|Southeast Asian Compact",
			"Hanoi Garden Stack|Southeast Asian Compact",
			"Sydney Orbital Terminal|Australasian Accord",
			"Melbourne Biome City|Australasian Accord",
			"Auckland Ocean Gate|Australasian Accord",
			"Neo São Paulo|South Atlantic League",
			"Rio Verde Dome|South Atlantic League",
			"Buenos Aires Climate Vault|South Atlantic League",
			"Andes Cloudport|South Atlantic League",
			"New Lima Terraces|South Atlantic League",
			"Mexico Megalopolis|North American Compact",
			"Toronto Aurora District|Northern Commonwealth",
			"Vancouver Pacific Wall|Northern Commonwealth",
			"Chicago Inland Arcology|Federated Earth",
			"Houston Launch Territory|Federated Earth",
			"New York Atlantic Stack|Federated Earth",
			"Los Angeles Solar Basin|Federated Earth",
			"Lunaris|Moon Republic",
			"Shackleton Crater City|Moon Republic",
			"Sea of Tranquility Hub|Moon Republic",
			"Tycho Research Nation|Moon Republic",
			"Olympus City|Sol Colony",
			"Valles Haven|Sol Colony",
			"Gale Crater Settlement|Sol Colony",
			"Elysium Planitia Port|Sol Colony",
			"Europa Station|Jovian Compact",
			"Ganymede Crown|Jovian Compact",
			"Callisto Deep Harbor|Jovian Compact",
			"Titan Harbor|Saturn Ring Authority",
			"Enceladus Ocean Lab|Saturn Ring Authority",
			"Mercury Shade Base|Inner Worlds Treaty",
			"Venus Cloud Habitat|Inner Worlds Treaty",
			"Ceres Freeport|Asteroid League",
			"Vesta Foundry|Asteroid League",
			"Kepler Relay|Deep Space Network",
			"Proxima Gate|Deep Space Network",
			"Helios Ring|Solar Accord"
		]
	}

	var packed_rows_raw: Variant = packed_rows_by_era.get(era, [])
	if typeof(packed_rows_raw) != TYPE_ARRAY:
		return []

	var out: Array = []

	for raw_pair in packed_rows_raw as Array:
		var pair: PackedStringArray = str(raw_pair).split("|", false, 1)
		if pair.size() != 2:
			continue

		var city_name: String = str(pair [0]).strip_edges()
		var country_name: String = str(pair [1]).strip_edges()

		if city_name == "" or country_name == "":
			continue

		out.append({
			"city": city_name,
			"country": country_name,
			"catalog_source": "era_engine_extended_canonical_expansion",
			"catalog_authority": "EraEngine"
		})

	return out
func get_birth_locations_for_era(era_key: String) -> Array:
	if gs == null:
		return []

	_refresh_data_driven_era_cache()

	var era_contract: Dictionary = _get_era_contract_by_key_or_name(era_key)
	if era_contract.is_empty():
		return []

	var previous_era: Variant = gs.era
	gs.era = era_contract

	var locations: Array = get_birth_locations().duplicate(true)

	gs.era = previous_era

	var canonical_expansion: Array = _canonical_birth_location_expansion_for_era(
		era_key,
		era_contract
	)
	var extended_expansion: Array = _extended_canonical_birth_location_expansion_for_era(
		era_key,
		era_contract
	)

	locations.append_array(canonical_expansion)
	locations.append_array(extended_expansion)
	locations.append_array(
		_elemental_nation_birth_locations_for_era(
			str(era_contract.get("id", era_key))
		)
	)

	var normalized_locations: Array = []

	for raw_location in locations:
		if typeof(raw_location) != TYPE_DICTIONARY:
			continue

		var location: Dictionary = (raw_location as Dictionary).duplicate(true)
		var city_name: String = str(location.get("city", "")).strip_edges()
		var country_name: String = str(location.get("country", "")).strip_edges()

		if city_name == "" or country_name == "":
			continue

		location ["city"] = city_name
		location ["country"] = _canonical_birth_location_country_name(
			era_key,
			city_name,
			country_name
		)
		location ["era_catalog_authority"] = "EraEngine"
		location ["era_catalog_contract_merged"] = true

		normalized_locations.append(location)

	var resolved_locations: Array = _dedupe_birth_locations(normalized_locations)

	if typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["era_location_catalog_last_era"] = str(era_key)
		gs.scenario_state ["era_location_catalog_last_count"] = resolved_locations.size()
		gs.scenario_state ["era_location_catalog_contract_merged"] = true
		gs.scenario_state ["era_location_catalog_canonical_expansion_count"] = canonical_expansion.size()
		gs.scenario_state ["era_location_catalog_updated_at_ms"] = int(Time.get_ticks_msec())
		gs.scenario_state ["era_location_catalog_extended_expansion_count"] = extended_expansion.size()
	return resolved_locations


func get_countries_for_era(
	era_key: String
) -> Array:
	var out: Array = []
	var seen: Dictionary = {}

	for entry in get_birth_locations_for_era(
		era_key
	):
		var country: String = str(
			entry.get(
				"country",
				""
			)
		).strip_edges()
		if (
			country == ""
			or seen.has(
				country
			)
		):
			continue

		seen [country] = true
		out.append(
			country
		)

	var normalized_era: String = (
		_normalize_era_lookup_key(
			era_key
		)
	)
	var required_titans: Array = []

	match normalized_era:
		"ancient":
			required_titans = [
				"China",
				"India"
			]

		"medieval":
			required_titans = [
				"China",
				"India"
			]

		"industrial":
			required_titans = [
				"United States",
				"India",
				"China",
				"Soviet Union"
			]

		"modern":
			required_titans = [
				"United States",
				"India",
				"China",
				"Russia"
			]

		"future":
			required_titans = [
				"United States",
				"India",
				"Orbital China",
				"Russia"
			]

	for raw_titan in required_titans:
		var titan_name: String = str(
			raw_titan
		)
		if seen.has(
			titan_name
		):
			continue

		seen [titan_name] = true
		out.append(
			titan_name
		)

	out.sort()
	return out

func get_cities_for_era_country(
	era_key: String,
	country: String
) -> Array:
	var out: Array = []
	var normalized_era: String = (
		_normalize_era_lookup_key(
			era_key
		)
	)
	var requested_country: String = (
		country.strip_edges()
	)
	var accepted_countries: Array = [
		requested_country
	]

	match requested_country:
		"United States":
			accepted_countries.append_array([
				"USA",
				"United States of America"
			])

		"Soviet Union":
			accepted_countries.append_array([
				"Russia",
				"Russian Empire"
			])

		"India":
			accepted_countries.append_array([
				"British India",
				"Maurya Empire",
				"Indus Valley",
				"Delhi Sultanate",
				"Indian Ocean Confederacy"
			])

		"China":
			accepted_countries.append_array([
				"Han China",
				"Qing China"
			])

		"Orbital China":
			accepted_countries.append_array([
				"China",
				"Eastern Nexus",
				"Qing China"
			])

		"Russia":
			accepted_countries.append_array([
				"Russian Empire",
				"Kievan Rus"
			])

	for entry in get_birth_locations_for_era(
		era_key
	):
		var entry_country: String = str(
			entry.get(
				"country",
				""
			)
		).strip_edges()
		if not accepted_countries.has(
			entry_country
		):
			continue

		var city: String = str(
			entry.get(
				"city",
				""
			)
		).strip_edges()
		if (
			city != ""
			and not out.has(
				city
			)
		):
			out.append(
				city
			)

	if out.is_empty():
		if (
			normalized_era == "future"
			and requested_country == "United States"
		):
			out = [
				"Neo-Chicago",
				"Neo-Houston"
			]
		elif (
			normalized_era == "future"
			and requested_country == "India"
		):
			out = [
				"Mumbai Orbit Gate"
			]
		elif (
			normalized_era == "future"
			and requested_country == "Orbital China"
		):
			out = [
				"Shenzhen Skygrid"
			]
		elif (
			normalized_era == "future"
			and requested_country == "Russia"
		):
			out = [
				"Neo-Moscow"
			]

	out.sort()
	return out

func get_country_for_era_city(era_key: String, city: String) -> String:
	for entry in get_birth_locations_for_era(era_key):
		if str(entry.get("city", "")).to_lower() == city.to_lower():
			return str(entry.get("country", ""))

	return ""


func get_era_key_from_year(year: int) -> String:
	_refresh_data_driven_era_cache()

	for era_key in _get_ordered_era_contract_keys():
		var era: Dictionary = era_contract_cache.get(era_key, {})
		if year >= int(era.get("start_year", TIMELINE_MIN_YEAR)) and year <= int(era.get("end_year", TIMELINE_MAX_YEAR)):
			return str(era.get("id", era_key))

	return "Modern"

func get_conception_story(
		era_key_or_name: String = "",
		year_value: int = -1,
		actor_id: int = -1
) -> String:
	_refresh_data_driven_era_cache()

	var clean_era: String = str(
		era_key_or_name
	).strip_edges().to_lower()
	var resolved_year: int = year_value
	var era: Dictionary = {}


	if clean_era != "":
		for raw_key in eras.keys():
			var key: String = str(
				raw_key
			)
			var era_raw: Variant = eras.get(
				raw_key,
				{}
			)

			if typeof(
				era_raw
			) != TYPE_DICTIONARY:
				continue

			var candidate: Dictionary = (
				era_raw as Dictionary
			)
			var candidates: Array = [
				key.to_lower(),
				str(
					candidate.get(
						"id",
						""
					)
				).to_lower(),
				str(
					candidate.get(
						"name",
						""
					)
				).to_lower()
			]

			if clean_era in candidates:
				era = candidate
				break


	if (
		resolved_year < TIMELINE_MIN_YEAR
		and gs != null
	):
		resolved_year = int(
			gs.year
		)

	if (
		era.is_empty()
		and resolved_year >= TIMELINE_MIN_YEAR
	):
		era = _era_from_year(
			resolved_year
		)

	if era.is_empty():
		era = _current_era_contract()

	var stories: Array = _safe_runtime_string_array(
		era.get(
			"conception_stories",
			[]
		)
	)

	if stories.is_empty():
		return (
			"I was conceived under mysterious circumstances."
		)

	var world_seed: int = 0

	if (
		gs != null
		and typeof(
			gs.scenario_state
		) == TYPE_DICTIONARY
	):
		world_seed = int(
			gs.scenario_state.get(
				"world_seed",
				0
			)
		)



	var random:= RandomNumberGenerator.new()
	random.seed = int(
		abs(
			hash(
				"%s|%d|%d|%d"
				% [
					str(
						era.get(
							"id",
							era.get(
								"name",
								"unknown"
							)
						)
					),
					resolved_year,
					actor_id,
					world_seed
				]
			)
		)
	)

	return str(
		stories [
			random.randi_range(
				0,
				stories.size() - 1
			)
		]
	)
func supports_world_title_boxing() -> bool:
	if gs.era == null:
		return false

	return gs.era.name in ["Modern Era", "Future Era"]
func _refresh_data_driven_era_cache(force: bool = false) -> void:
	var external_registry: Dictionary = {}
	if gs != null and gs.simulation_contract_engine != null:
		if gs.simulation_contract_engine.has_method("get_era_contract_registry"):
			external_registry = gs.simulation_contract_engine.get_era_contract_registry()
		elif gs.simulation_contract_engine.has_method("export_registry"):
			var exported: Dictionary = gs.simulation_contract_engine.export_registry()
			var exported_eras: Variant = exported.get("era_contract_registry", {})
			if typeof(exported_eras) == TYPE_DICTIONARY:
				external_registry = exported_eras

	var signature: String = "%s|%s" % [str(eras.keys()), str(external_registry.keys())]
	if not force and signature == era_contract_signature and not era_contract_cache.is_empty():
		return

	era_contract_cache.clear()

	for raw_key in eras.keys():
		var key: String = str(raw_key)
		var raw_era: Dictionary = eras.get(raw_key, {})
		var normalized: Dictionary = _normalize_era_contract_for_runtime(raw_era, key)
		era_contract_cache [str(normalized.get("id", key))] = normalized

	for raw_external_key in external_registry.keys():
		var external_raw: Variant = external_registry.get(raw_external_key, {})
		if typeof(external_raw) != TYPE_DICTIONARY:
			continue

		var external: Dictionary = external_raw
		var normalized_external: Dictionary = _normalize_era_contract_for_runtime(external, str(raw_external_key))
		var external_id: String = str(normalized_external.get("id", "")).strip_edges()
		if external_id == "":
			continue

		era_contract_cache [external_id] = normalized_external

	era_contract_signature = signature


func _normalize_era_contract_for_runtime(raw_era: Dictionary, fallback_key: String = "") -> Dictionary:
	var era_id: String = str(raw_era.get("id", fallback_key)).strip_edges()
	if era_id == "":
		era_id = _era_key_from_name(str(raw_era.get("name", fallback_key)))

	var name: String = str(raw_era.get("name", era_id)).strip_edges()
	if name == "":
		name = era_id

	var rules_raw: Variant = raw_era.get("rules", {})
	var rules: Dictionary = rules_raw if typeof(rules_raw) == TYPE_DICTIONARY else {}

	var modifiers_raw: Variant = raw_era.get("modifiers", rules.get("modifiers", {}))
	var modifiers: Dictionary = modifiers_raw if typeof(modifiers_raw) == TYPE_DICTIONARY else {}

	var rights_raw: Variant = raw_era.get("rights", rules.get("rights", {}))
	var era_rights: Dictionary = rights_raw if typeof(rights_raw) == TYPE_DICTIONARY else {}

	return {
		"id": era_id,
		"name": name,
		"owner_pack": str(raw_era.get("owner_pack", "")).strip_edges(),
		"start_year": int(raw_era.get("start_year", raw_era.get("year_min", TIMELINE_MIN_YEAR))),
		"end_year": int(raw_era.get("end_year", raw_era.get("year_max", TIMELINE_MAX_YEAR))),
		"rights": era_rights.duplicate(true),
		"job_pool": _safe_runtime_string_array(raw_era.get("job_pool", raw_era.get("jobs", []))),
		"part_time_job_pool": _safe_runtime_string_array(raw_era.get("part_time_job_pool", raw_era.get("part_time_jobs", []))),
		"famous_career_tracks": _safe_runtime_string_array(raw_era.get("famous_career_tracks", [])),
		"birth_events": _safe_runtime_string_array(raw_era.get("birth_events", [])),
		"conception_stories": _safe_runtime_string_array(raw_era.get("conception_stories", [])),
		"world_events": _safe_runtime_string_array(raw_era.get("world_events", [])),
		"birth_locations": _safe_runtime_dictionary_array(raw_era.get("birth_locations", [])),
		"modifiers": modifiers.duplicate(true),
		"age_bounds": raw_era.get("age_bounds", {}).duplicate(true) if typeof(raw_era.get("age_bounds", {})) == TYPE_DICTIONARY else {},
		"rules": rules.duplicate(true)
	}


func _current_era_contract() -> Dictionary:
	if (
		gs != null
		and gs.era_contract_engine != null
	):
		return (
			gs.era_contract_engine
			.current_era_contract()
		)

	_refresh_data_driven_era_cache()

	if gs == null or gs.era == null:
		return _era_from_year(0)

	if typeof(gs.era) == TYPE_DICTIONARY:
		var id_key: String = str(
			gs.era.get(
				"id",
				""
			)
		).strip_edges()

		if (
			id_key != ""
			and era_contract_cache.has(id_key)
		):
			return (
				era_contract_cache [id_key]
				.duplicate(true)
			)

		var name_key: String = str(
			gs.era.get(
				"name",
				""
			)
		).strip_edges()
		var by_name: Dictionary = (
			_get_era_contract_by_key_or_name(
				name_key
			)
		)

		if not by_name.is_empty():
			return by_name

	return _era_from_year(
		int(
			gs.year
			if gs != null
			else 0
		)
	)


func _get_era_contract_by_key_or_name(value: String) -> Dictionary:
	_refresh_data_driven_era_cache()

	var clean: String = str(value).strip_edges()
	if clean == "":
		return {}

	if era_contract_cache.has(clean):
		return era_contract_cache [clean].duplicate(true)

	var normalized_clean: String = _normalize_era_lookup_key(clean)
	for raw_key in era_contract_cache.keys():
		var era: Dictionary = era_contract_cache.get(raw_key, {})
		if _normalize_era_lookup_key(str(raw_key)) == normalized_clean:
			return era.duplicate(true)
		if _normalize_era_lookup_key(str(era.get("name", ""))) == normalized_clean:
			return era.duplicate(true)

	return {}


func _get_ordered_era_contract_keys() -> Array:
	_refresh_data_driven_era_cache()

	var keys: Array = era_contract_cache.keys()
	keys.sort_custom(func (a, b):
		var era_a: Dictionary = era_contract_cache.get(a, {})
		var era_b: Dictionary = era_contract_cache.get(b, {})
		var start_a: int = int(era_a.get("start_year", 0))
		var start_b: int = int(era_b.get("start_year", 0))
		if start_a == start_b:
			return str(a) < str(b)
		return start_a < start_b
	)

	return keys


func _era_key_from_name(value: String) -> String:
	var clean: String = str(value).strip_edges()
	match clean:
		"Ancient Era":
			return "Ancient"
		"Medieval Era":
			return "Medieval"
		"Industrial Era":
			return "Industrial"
		"Modern Era":
			return "Modern"
		"Future Era":
			return "Future"
		_:
			var out: String = clean.replace(" Era", "")
			out = out.replace(" ", "_")
			return out


func _normalize_era_lookup_key(value: String) -> String:
	var clean: String = str(value).strip_edges().to_lower()
	clean = clean.replace(" era", "")
	clean = clean.replace(" ", "_")
	clean = clean.replace("-", "_")
	while clean.find("__") >= 0:
		clean = clean.replace("__", "_")
	return clean


func _safe_runtime_string_array(value: Variant) -> Array:
	var out: Array = []

	if typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME:
		var direct: String = str(value).strip_edges()
		if direct != "":
			out.append(direct)
		return out

	if typeof(value) != TYPE_ARRAY and typeof(value) != TYPE_PACKED_STRING_ARRAY:
		return out

	for raw in value:
		var clean: String = str(raw).strip_edges()
		if clean != "":
			out.append(clean)

	return out


func _safe_runtime_dictionary_array(value: Variant) -> Array:
	var out: Array = []
	if typeof(value) != TYPE_ARRAY:
		return out

	for raw in value:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		out.append((raw as Dictionary).duplicate(true))

	return out


func _dedupe_birth_locations(locations: Array) -> Array:
	var out: Array = []
	var seen: Dictionary = {}

	for raw_entry in locations:
		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue

		var entry: Dictionary = raw_entry
		var city: String = str(entry.get("city", "")).strip_edges()
		var country: String = str(entry.get("country", "")).strip_edges()
		var key: String = "%s|%s" % [city.to_lower(), country.to_lower()]

		if key == "|" or seen.has(key):
			continue

		seen [key] = true
		out.append(entry.duplicate(true))

	return out