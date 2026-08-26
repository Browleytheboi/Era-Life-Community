extends Resource
class_name ArtifactsEngine

var gs

func _init(_gs):
	gs = _gs
	if gs.mod_loader and gs.mod_loader.mod_data.has("artifacts"):
		for k in gs.mod_loader.mod_data ["artifacts"].keys():
			STONES [k] = gs.mod_loader.mod_data ["artifacts"] [k]



var STONES = {
	"Power": {
		"color": "violet",
		"buffs": { "health": 15, "looks": 5},
		"lore": "Said to be carved from the heart of a dying star.",
		"spawn_weight": 1,
	},
	"Mind": {
		"color": "yellow",
		"buffs": { "smarts": 20, "mental_health": 15},
		"lore": "Whispers the futures of others into the holder's dreams.",
		"spawn_weight": 1,
	},
	"Reality": {
		"color": "red",
		"buffs": { "fate_control": true},
		"lore": "Bends fate arcs around its bearer like molten metal.",
		"spawn_weight": 1,
	},
	"Space": {
		"color": "blue",
		"buffs": { "movement_chance": 100},
		"lore": "Allows the holder to vanish from any place—and appear elsewhere.",
		"spawn_weight": 1,
	},
	"Time": {
		"color": "green",
		"buffs": { "lifespan_bonus": 40},
		"lore": "Time coils itself around the one who holds it.",
		"spawn_weight": 1,
	},
	"Soul": {
		"color": "orange",
		"buffs": { "charm": 15, "relationships": 10},
		"lore": "Demands a sacrifice from every bearer across generations.",
		"spawn_weight": 1,
	}
}


var ownership = {}
var cosmic_karma:= {}
var pending_galactic_enforcer:= {}
const EXCHANGE_ARTIFACT_LEDGER_KEY:= "artifact_authority_exchange_ledger_v1"
const EXCHANGE_ARTIFACT_ANNUAL_EFFECT_STATE_KEY:= (
	"artifact_authority_exchange_annual_effect_state_v1"
)
const EXCHANGE_ARTIFACT_TERMS_SCHEMA:= "eralife.artifact_authority.extraordinary_acquisition_terms"
const EXCHANGE_ARTIFACT_ACQUISITION_SCHEMA:= "eralife.artifact_authority.exchange_acquisition"
const EXCHANGE_ARTIFACT_LINEAGE_SCAN_LIMIT:= 256

const EXCHANGE_ARTIFACT_DEFINITIONS:= {
	"acrellos_macbook": {
		"name": "Acrello’s MacBook",
		"grant_type": "exchange_artifact",
		"artifact_kind": "exchange_artifact",
		"base_value": 487300000,
		"annual_appreciation_rate": 0.005,
		"valuation_origin_year": 2013,
		"minimum_year": 2013,
		"canonical_supply": 1,
		"circulation_policy": "always_when_unclaimed",
		"classification_display": "◆ ONE OF ONE ◆",
		"classification_family": "ONE OF ONE",
		"house_text": "HISTORIC ARTIFACT · COMPUTING RELIC",
		"origin": "United States · Early 21st Century",
		"origin_country": "United States",
		"origin_era": "Early 21st Century",
		"known_owners": "1",
		"last_transfer": "Never",
		"condition": "Miraculously operational",
		"rarity": "Beyond Mythic",
		"mythic_rank": "Historical Singularity",
		"display_color_key": "gold",
		"editorial_rank": 1800,
		"description": (
			"An aging personal computer believed to be the original development machine "
			+ "upon which the earliest surviving reality architecture of EraLife was authored.\n\n"
			+ "Historical analysis remains divided on how it survived development."
		),
		"authority_note": (
			"Artifact authority does not recognize monetary consideration as sufficient."
		),
		"provenance_lines": [
			"2013 — Manufactured",
			"2020s — Acquired by Acrello",
			"EraLife development period — Primary development machine",
			"??? — Entered historical record"
		],
		"append_current_year_provenance": true,
		"extraordinary_family_lives": 3,
		"leave_label": "LEAVE THE MACBOOK."
	},

	"original_eralife_build": {
		"name": "The Original EraLife Build",
		"grant_type": "exchange_artifact",
		"artifact_kind": "exchange_artifact",
		"base_value": 1750000000,
		"annual_appreciation_rate": 0.005,
		"valuation_origin_year": 2026,
		"minimum_year": 2026,
		"canonical_supply": 1,
		"circulation_policy": "annual_probability",
		"circulation_basis_points": 400,
		"classification_display": "◆ BEYOND MYTHIC ◆",
		"classification_family": "ARTIFACT",
		"house_text": "HISTORIC ARTIFACT · SOFTWARE RELIC",
		"origin": "EraLife development period",
		"known_owners": "1",
		"last_transfer": "Never",
		"condition": "Preserved",
		"rarity": "Beyond Mythic",
		"mythic_rank": "Foundational Reality Artifact",
		"display_color_key": "gold",
		"editorial_rank": 1700,
		"description": (
			"The earliest surviving executable build recognized by Artifact Authority "
			+ "as EraLife."
		),
		"provenance_lines": [
			"EraLife development period — First surviving build",
			"Historical archive — Preserved as executable evidence"
		]
	},

	"first_development_notebook": {
		"name": "First Development Notebook",
		"grant_type": "exchange_artifact",
		"artifact_kind": "exchange_artifact",
		"base_value": 325000000,
		"annual_appreciation_rate": 0.005,
		"valuation_origin_year": 2026,
		"minimum_year": 2026,
		"canonical_supply": 1,
		"circulation_policy": "annual_probability",
		"circulation_basis_points": 650,
		"classification_display": "◆ BEYOND MYTHIC ◆",
		"classification_family": "ARTIFACT",
		"house_text": "HISTORIC ARTIFACT · DEVELOPMENT RELIC",
		"origin": "EraLife development period",
		"known_owners": "1",
		"last_transfer": "Never",
		"condition": "Archived",
		"rarity": "Beyond Mythic",
		"mythic_rank": "Foundational Reality Artifact",
		"display_color_key": "gold",
		"editorial_rank": 1630,
		"description": (
			"The earliest surviving development notebook associated with "
			+ "EraLife’s original systems planning."
		),
		"provenance_lines": [
			"EraLife development period — Active design record",
			"Historical archive — Entered preservation"
		]
	},

	"original_logo_sketch": {
		"name": "Original Logo Sketch",
		"grant_type": "exchange_artifact",
		"artifact_kind": "exchange_artifact",
		"base_value": 175000000,
		"annual_appreciation_rate": 0.005,
		"valuation_origin_year": 2026,
		"minimum_year": 2026,
		"canonical_supply": 1,
		"circulation_policy": "annual_probability",
		"circulation_basis_points": 900,
		"classification_display": "◆ BEYOND MYTHIC ◆",
		"classification_family": "ARTIFACT",
		"house_text": "HISTORIC ARTIFACT · DESIGN RELIC",
		"origin": "EraLife development period",
		"known_owners": "1",
		"last_transfer": "Never",
		"condition": "Fragile archival material",
		"rarity": "Beyond Mythic",
		"mythic_rank": "Foundational Reality Artifact",
		"display_color_key": "gold",
		"editorial_rank": 1580,
		"description": (
			"The earliest surviving visual study associated with EraLife’s identity."
		),
		"provenance_lines": [
			"EraLife development period — Initial identity study",
			"Historical archive — Preserved"
		]
	},

	"eralife_first_save_file": {
		"name": "EraLife’s First Save File",
		"grant_type": "exchange_artifact",
		"artifact_kind": "exchange_artifact",
		"base_value": 900000000,
		"annual_appreciation_rate": 0.005,
		"valuation_origin_year": 2026,
		"minimum_year": 2026,
		"canonical_supply": 1,
		"circulation_policy": "annual_probability",
		"circulation_basis_points": 300,
		"classification_display": "◆ BEYOND MYTHIC ◆",
		"classification_family": "ARTIFACT",
		"house_text": "HISTORIC ARTIFACT · REALITY RECORD",
		"origin": "EraLife development period",
		"known_owners": "1",
		"last_transfer": "Never",
		"condition": "Readable",
		"rarity": "Beyond Mythic",
		"mythic_rank": "Canonical Reality Anomaly",
		"display_color_key": "gold",
		"editorial_rank": 1740,
		"description": (
			"The earliest surviving save-state recognized as a complete "
			+ "EraLife reality record."
		),
		"provenance_lines": [
			"EraLife development period — First surviving reality state",
			"Historical archive — Preserved intact"
		]
	},

	"prototype_source_drive": {
		"name": "Prototype Source Drive",
		"grant_type": "exchange_artifact",
		"artifact_kind": "exchange_artifact",
		"base_value": 1250000000,
		"annual_appreciation_rate": 0.005,
		"valuation_origin_year": 2026,
		"minimum_year": 2026,
		"canonical_supply": 1,
		"circulation_policy": "annual_probability",
		"circulation_basis_points": 250,
		"classification_display": "◆ BEYOND MYTHIC ◆",
		"classification_family": "ARTIFACT",
		"house_text": "HISTORIC ARTIFACT · SOURCE RELIC",
		"origin": "EraLife development period",
		"known_owners": "1",
		"last_transfer": "Never",
		"condition": "Operational under archival handling",
		"rarity": "Beyond Mythic",
		"mythic_rank": "Canonical Reality Anomaly",
		"display_color_key": "gold",
		"editorial_rank": 1760,
		"description": (
			"A preserved source drive containing prototype-era EraLife development material."
		),
		"provenance_lines": [
			"EraLife development period — Prototype source storage",
			"Historical archive — Entered restricted custody"
		]
	},

	"pepe_trophy": {
		"name": "Pepe Trophy",
		"grant_type": "exchange_artifact",
		"artifact_kind": "exchange_artifact",
		"base_value": 250000000,
		"annual_appreciation_rate": 0.025,
		"valuation_origin_mode": "reality_start",
		"annual_bank_stipend": 750000,
		"exists_across_all_years": true,
		"canonical_supply": 1,
		"circulation_policy": "annual_probability",
		"circulation_basis_points": 1800,
		"classification_display": "◆ BEYOND MYTHIC ◆",
		"classification_family": "ARTIFACT",
		"house_text": "CULTURAL ARTIFACT · TROPHY RELIC",
		"origin": "Chronologically indeterminate",
		"known_owners": "Unknown",
		"last_transfer": "Unverified",
		"condition": "Excellent",
		"rarity": "Beyond Mythic",
		"mythic_rank": "Cross-Era Cultural Anomaly",
		"display_color_key": "gold",
		"editorial_rank": 1480,
		"description": (
			"A trophy whose documented appearances do not conform to ordinary chronology."
		),
		"provenance_lines": [
			"Multiple eras — Independent appearances recorded",
			"Artifact Authority — Continuity accepted"
		]
	},

	"kimanis_chrochet_needle": {
		"name": "Kimani’s Chrochet needle",
		"grant_type": "exchange_artifact",
		"artifact_kind": "exchange_artifact",
		"base_value": 200000,
		"annual_appreciation_rate": 0.0,
		"exists_across_all_years": true,
		"canonical_supply": 1,
		"circulation_policy": "annual_probability",
		"circulation_basis_points": 1800,
		"classification_display": "◆ HISTORIC ◆",
		"classification_family": "HISTORIC",
		"house_text": "CULTURAL ARTIFACT · CRAFT RELIC",
		"origin": "Undisclosed",
		"known_owners": "Unknown",
		"last_transfer": "Unverified",
		"condition": "Operational",
		"rarity": "Historic",
		"mythic_rank": "Personal Provenance Artifact",
		"display_color_key": "gold",
		"editorial_rank": 640,
		"description": (
			"A crochet needle attributed to Kimani and retained under "
			+ "Artifact Authority provenance."
		),
		"provenance_lines": [
			"Private record — Attributed to Kimani",
			"Artifact Authority — Provenance retained"
		]
	},

	"pepe_coin": {
		"name": "Pepe Coin",
		"grant_type": "exchange_artifact",
		"artifact_kind": "exchange_artifact",
		"base_value": 10000000,
		"annual_appreciation_rate": 0.0,
		"exists_across_all_years": true,
		"canonical_supply": 4,
		"circulation_policy": "pepe_coin_limited",
		"classification_display": "◆ BEYOND MYTHIC ◆",
		"classification_family": "ARTIFACT",
		"house_text": "CULTURAL ARTIFACT · NUMISMATIC ANOMALY",
		"origin": "Chronologically indeterminate",
		"known_owners": "Unknown",
		"last_transfer": "Unverified",
		"condition": "Circulated",
		"rarity": "Beyond Mythic",
		"mythic_rank": "Cross-Era Cultural Anomaly",
		"display_color_key": "gold",
		"editorial_rank": 1420,
		"description": (
			"A limited coin recognized across historical periods in which "
			+ "its manufacture cannot be satisfactorily established."
		),
		"provenance_lines": [
			"Multiple eras — Independent specimens recorded",
			"Artifact Authority — Maximum canonical supply established at four"
		]
	}
}
var extraordinary_acquisition_terms: Dictionary = {}
var extraordinary_acquisition_sequence: int = 0
const GALACTIC_ENFORCER_THRESHOLD:= 70
const GALACTIC_ENFORCER_HP:= 700
const GALACTIC_ENFORCER_WIN_CHANCE:= 0.1
const GALACTIC_ENFORCER_KILL_ON_LOSS_CHANCE:= 0.35
var SHOP_ORDER:= [
	"lucky_charm",
	"scholars_quill",
	"mirror_of_radiance",
	"vitality_idol",
	"dynasty_seal",
	"dragonball_1",
	"dragonball_2",
	"dragonball_3",
	"dragonball_4",
	"dragonball_5",
	"dragonball_6",
	"dragonball_7",
	"power_stone",
	"mind_stone",
	"reality_stone",
	"space_stone",
	"time_stone",
	"red_bonnet"
]

var SHOP_ITEMS:= {
	"lucky_charm": {
		"name": "Lucky Charm",
		"grant_type": "basic_artifact",
		"cost": 2500,
		"description": "A small relic that gently steadies the soul and improves your social ease.",
		"lore": "Old market mystics say it only finds people the world is willing to smile on.",
		"ability": "Slightly improves mental health and relationships.",
		"buffs": { "mental_health": 8, "relationships": 4},
		"color": "gold",
		"rarity": "Uncommon"
	},
	"scholars_quill": {
		"name": "Scholar's Quill",
		"grant_type": "basic_artifact",
		"cost": 12000,
		"description": "A refined writing relic that sharpens thought and insight.",
		"lore": "Ink from this quill is rumored to make ordinary ideas feel inevitable.",
		"ability": "Boosts smarts.",
		"buffs": { "smarts": 15},
		"color": "silver",
		"rarity": "Rare"
	},
	"mirror_of_radiance": {
		"name": "Mirror of Radiance",
		"grant_type": "basic_artifact",
		"cost": 18000,
		"description": "A polished hand mirror that heightens presence and beauty.",
		"lore": "Some insist the glass remembers the most admired face it has ever seen.",
		"ability": "Boosts looks.",
		"buffs": { "looks": 15},
		"color": "white",
		"rarity": "Rare"
	},
	"vitality_idol": {
		"name": "Vitality Idol",
		"grant_type": "basic_artifact",
		"cost": 26000,
		"description": "A dense carved idol that floods the body with resilient life-force.",
		"lore": "Warm to the touch even in cold rooms, as if it quietly carries a pulse.",
		"ability": "Boosts health and mental health.",
		"buffs": { "health": 20, "mental_health": 8},
		"color": "emerald",
		"rarity": "Epic"
	},
	"dynasty_seal": {
		"name": "Dynasty Seal",
		"grant_type": "basic_artifact",
		"cost": 150000,
		"description": "A noble seal used to lift a family line into greater prestige.",
		"lore": "The wax it leaves behind is said to outlive the paper it touches.",
		"ability": "Improves dynasty prestige and grants a touch of fame.",
		"buffs": { "relationships": 8},
		"dynasty_prestige_bonus": 300,
		"fame_bonus": 5,
		"color": "crimson",
		"rarity": "Legendary"
	},
	"dragonball_1": {
		"name": "1-Star Dragon Ball",
		"grant_type": "dragon_ball",
		"star": 1,
		"cost": 25000000,
		"description": "One of the seven legendary wish-orbs.",
		"lore": "Its glow feels ancient even when resting still.",
		"rarity": "Mythic"
	},
	"dragonball_2": {
		"name": "2-Star Dragon Ball",
		"grant_type": "dragon_ball",
		"star": 2,
		"cost": 50000000,
		"description": "One of the seven legendary wish-orbs.",
		"lore": "Collectors whisper that this one tends to surface near turning points in history.",
		"rarity": "Mythic"
	},
	"dragonball_3": {
		"name": "3-Star Dragon Ball",
		"grant_type": "dragon_ball",
		"star": 3,
		"cost": 100000000,
		"description": "One of the seven legendary wish-orbs.",
		"lore": "Its internal light bends like a living flame.",
		"rarity": "Mythic"
	},
	"dragonball_4": {
		"name": "4-Star Dragon Ball",
		"grant_type": "dragon_ball",
		"star": 4,
		"cost": 200000000,
		"description": "One of the seven legendary wish-orbs.",
		"lore": "The most sentimental traders refuse to name their price for this one.",
		"rarity": "Mythic"
	},
	"dragonball_5": {
		"name": "5-Star Dragon Ball",
		"grant_type": "dragon_ball",
		"star": 5,
		"cost": 350000000,
		"description": "One of the seven legendary wish-orbs.",
		"lore": "Merchants claim the room changes temperature when it is near.",
		"rarity": "Mythic"
	},
	"dragonball_6": {
		"name": "6-Star Dragon Ball",
		"grant_type": "dragon_ball",
		"star": 6,
		"cost": 600000000,
		"description": "One of the seven legendary wish-orbs.",
		"lore": "Its glow feels too intelligent to be ordinary treasure.",
		"rarity": "Mythic"
	},
	"dragonball_7": {
		"name": "7-Star Dragon Ball",
		"grant_type": "dragon_ball",
		"star": 7,
		"cost": 1000000000,
		"description": "One of the seven legendary wish-orbs.",
		"lore": "The rarest dealers won't even look directly at it for too long.",
		"rarity": "Mythic"
	},
	"power_stone": {
		"name": "Power Stone",
		"grant_type": "infinity_stone",
		"stone": "Power",
		"cost": 750000000,
		"description": "Raw force and resilience in relic form.",
		"lore": "Said to pulse like a dying star forced back to life.",
		"rarity": "Cosmic"
	},
	"mind_stone": {
		"name": "Mind Stone",
		"grant_type": "infinity_stone",
		"stone": "Mind",
		"cost": 900000000,
		"description": "A thought-amplifying cosmic stone.",
		"lore": "Its whispers are sometimes heard before it is ever seen.",
		"rarity": "Cosmic"
	},
	"reality_stone": {
		"name": "Reality Stone",
		"grant_type": "infinity_stone",
		"stone": "Reality",
		"cost": 1500000000,
		"description": "A fate-warping stone that bends reality around its bearer.",
		"lore": "Its red glow feels less like light and more like a wound in the world.",
		"rarity": "Cosmic"
	},
	"space_stone": {
		"name": "Space Stone",
		"grant_type": "infinity_stone",
		"stone": "Space",
		"cost": 1100000000,
		"description": "A cosmic stone tied to impossible movement and repositioning.",
		"lore": "Maps feel embarrassed in its presence.",
		"rarity": "Cosmic"
	},
	"time_stone": {
		"name": "Time Stone",
		"grant_type": "infinity_stone",
		"stone": "Time",
		"cost": 1400000000,
		"description": "A legendary temporal stone linked to lifespan and survival.",
		"lore": "Some say clocks become more honest when it is nearby.",
		"rarity": "Cosmic"
	},
	"soul_stone": {
		"name": "Soul Stone",
		"grant_type": "infinity_stone",
		"stone": "Soul",
		"cost": 1300000000,
		"description": "A dangerous cosmic stone tied to charm, sacrifice, and deep influence.",
		"lore": "It makes even quiet rooms feel watched.",
		"rarity": "Cosmic"
	},
	"red_bonnet": {
		"name": "Red Bonnet",
		"grant_type": "red_bonnet",
		"cost_display": "♾️",
		"description": "The impossible artifact. No shop can truly sell it.",
		"lore": "A legendary bonnet said to bend fate, wealth, and bloodlines.",
		"rarity": "Divine"
	}
}


func _get_shop_entry(item_id: String) -> Dictionary:
	if not SHOP_ITEMS.has(item_id):
		return {}

	var entry: Dictionary = SHOP_ITEMS [item_id].duplicate(true)
	entry ["id"] = item_id
	return entry


func _format_shop_cost(entry: Dictionary) -> String:
	var explicit_display: String = str(entry.get("cost_display", "")).strip_edges()
	if explicit_display != "":
		return explicit_display

	var price: int = _resolved_shop_cost(entry)
	if gs != null and gs.economy_engine != null:
		return gs.economy_engine.format_money(price)
	return str(price)


func _basic_shop_artifact_owned(npc: Person, item_name: String) -> bool:
	if gs == null or gs.belongings_engine == null or npc == null:
		return false
	return gs.belongings_engine.has_item_named(npc, "Artifacts", item_name)


func _shop_entry_availability(npc: Person, entry: Dictionary) -> Dictionary:
	if npc == null:
		return { "available": false, "status": "Unavailable", "text": "No active buyer was found."}

	var grant_type: String = str(entry.get("grant_type", ""))
	var item_name: String = str(entry.get("name", "Artifact"))

	match grant_type:
		"basic_artifact":
			if _basic_shop_artifact_owned(npc, item_name):
				return { "available": false, "status": "Owned", "text": "You already own the %s." % item_name}
			return { "available": true, "status": "Available", "text": ""}

		"dragon_ball":
			if gs == null or gs.dragonballs_engine == null or not gs.is_feature_enabled("dragonballs"):
				return { "available": false, "status": "Unavailable", "text": "Dragon Balls are not active in this reality."}

			var star: int = int(entry.get("star", 0))
			if gs.dragonballs_engine.ownership.has(npc.id) and star in gs.dragonballs_engine.ownership [npc.id]:
				return { "available": false, "status": "Owned", "text": "You already own the %s." % item_name}

			if gs.dragonballs_engine.has_method("is_ball_shop_available") and not gs.dragonballs_engine.is_ball_shop_available(star):
				return { "available": false, "status": "Sold Out", "text": "The %s has already been claimed somewhere in this world." % item_name}

			return { "available": true, "status": "Available", "text": ""}

		"infinity_stone":
			if gs == null or not gs.is_feature_enabled("artifacts"):
				return { "available": false, "status": "Unavailable", "text": "Infinity Stones are not active in this reality."}
			var stone: String = str(entry.get("stone", ""))
			if stone == "Soul":
				return {
					"available": false,
					"status": "Vormir Locked",
					"text": "The Soul Stone cannot be bought, spawned, inherited through chance, or selected from God Mode. Vormir demands a soul for a soul."
				}
			if ownership.has(npc.id) and stone in ownership.get(npc.id, []):
				return { "available": false, "status": "Owned", "text": "You already hold the %s Stone." % stone}
			if stone in _globally_owned_stones():
				return { "available": false, "status": "Sold Out", "text": "The %s Stone is already in someone else's possession." % stone}
			return { "available": true, "status": "Available", "text": ""}

		"red_bonnet":
			return {
				"available": false,
				"status": "It Chooses Its Owner",
				"text": "No Amount of wealth in the world can purchase this. Said to be a gift from Heaven. Given back once."
			}

		_:
			return { "available": false, "status": "Unavailable", "text": "That artifact is not configured for the shop."}


func shop_inventory_slot_count() -> int:
	return SHOP_ORDER.size()

func _exchange_artifact_definition(
	definition_id: String
) -> Dictionary:
	var clean_id: String = str(
		definition_id
	).strip_edges().to_lower()

	if (
		clean_id == ""
		or not EXCHANGE_ARTIFACT_DEFINITIONS.has(
			clean_id
		)
	):
		return {}

	var definition: Dictionary = (
		EXCHANGE_ARTIFACT_DEFINITIONS [
			clean_id
		] as Dictionary
	).duplicate(true)

	definition ["id"] = clean_id

	return definition


func _exchange_artifact_exists_in_year(
	definition: Dictionary,
	current_year: int
) -> bool:
	if definition.is_empty():
		return false

	if bool(
		definition.get(
			"exists_across_all_years",
			false
		)
	):
		return true

	return (
		current_year
		>= int(
			definition.get(
				"minimum_year",
				-2147483648
			)
		)
	)

func _exchange_artifact_reality_start_year(
	current_year: int
) -> int:
	if (
		gs == null
		or typeof(
			gs.scenario_state
		) != TYPE_DICTIONARY
	):
		return current_year

	var identity_raw: Variant = (
		gs.scenario_state.get(
			"life_identity",
			{}
		)
	)

	if typeof(
		identity_raw
	) != TYPE_DICTIONARY:
		return current_year

	var identity: Dictionary = (
		identity_raw as Dictionary
	)

	if not identity.has(
		"reality_start_year"
	):
		return current_year

	return int(
		identity.get(
			"reality_start_year",
			current_year
		)
	)


func _exchange_artifact_valuation_origin_year(
	definition: Dictionary,
	current_year: int
) -> int:
	var valuation_origin_mode: String = str(
		definition.get(
			"valuation_origin_mode",
			"fixed_year"
		)
	).strip_edges().to_lower()

	if valuation_origin_mode == "reality_start":
		return _exchange_artifact_reality_start_year(
			current_year
		)

	return int(
		definition.get(
			"valuation_origin_year",
			current_year
		)
	)
func _exchange_artifact_current_value(
	definition: Dictionary,
	current_year: int
) -> int:
	var base_value: int = int(
		definition.get(
			"base_value",
			0
		)
	)
	var annual_rate: float = float(
		definition.get(
			"annual_appreciation_rate",
			0.0
		)
	)

	if (
		base_value <= 0
		or annual_rate <= 0.0
	):
		return base_value

	var valuation_origin_year: int = (
		_exchange_artifact_valuation_origin_year(
			definition,
			current_year
		)
	)
	var appreciation_years: int = maxi(
		0,
		current_year - valuation_origin_year
	)

	if appreciation_years <= 0:
		return base_value

	return int(
		round(
			float(
				base_value
			)
			* pow(
				1.0 + annual_rate,
				appreciation_years
			)
		)
	)

func _format_exchange_artifact_money(
	amount: int
) -> String:
	if (
		gs != null
		and gs.economy_engine != null
		and gs.economy_engine.has_method(
			"format_money"
		)
	):
		return str(
			gs.economy_engine.format_money(
				amount
			)
		)

	return str(amount)


func _exchange_artifact_instance_id(
	definition_id: String,
	instance_index: int
) -> String:
	return "artifact:%s:%02d" % [
		str(
			definition_id
		).strip_edges().to_lower(),
		instance_index
	]


func _exchange_artifact_ledger() -> Array:
	if (
		gs == null
		or typeof(
			gs.scenario_state
		) != TYPE_DICTIONARY
	):
		return []

	var raw_ledger: Variant = gs.scenario_state.get(
		EXCHANGE_ARTIFACT_LEDGER_KEY,
		[]
	)

	if typeof(
		raw_ledger
	) != TYPE_ARRAY:
		return []

	return (
		raw_ledger as Array
	).duplicate(true)


func _append_exchange_artifact_ledger_entry(
	entry: Dictionary
) -> void:
	var ledger: Array = _exchange_artifact_ledger()

	ledger.append(
		entry.duplicate(true)
	)

	gs.scenario_state [
		EXCHANGE_ARTIFACT_LEDGER_KEY
	] = ledger


func _exchange_artifact_instance_ownership_record(
	canonical_instance_id: String
) -> Dictionary:
	var clean_instance_id: String = str(
		canonical_instance_id
	).strip_edges().to_lower()

	if clean_instance_id == "":
		return {}

	var ledger: Array = _exchange_artifact_ledger()

	for index in range(
		ledger.size() - 1,
		-1,
		-1
	):
		var raw_entry: Variant = ledger [
			index
		]

		if typeof(
			raw_entry
		) != TYPE_DICTIONARY:
			continue

		var entry: Dictionary = (
			raw_entry as Dictionary
		)

		if str(
			entry.get(
				"canonical_instance_id",
				""
			)
		).strip_edges().to_lower() != clean_instance_id:
			continue

		var event_type: String = str(
			entry.get(
				"event_type",
				""
			)
		).strip_edges().to_lower()

		if event_type not in [
			"exchange_artifact_acquisition_committed",
			"exchange_artifact_transfer_committed"
		]:
			continue

		return entry.duplicate(
			false
		)

	return {}


func _exchange_artifact_instance_owner_id(
	canonical_instance_id: String
) -> int:
	var ownership_record: Dictionary = (
		_exchange_artifact_instance_ownership_record(
			canonical_instance_id
		)
	)

	if ownership_record.is_empty():
		return -1

	return int(
		ownership_record.get(
			"owner_id",
			-1
		)
	)
func yearly_exchange_artifact_effects(
	payload: Dictionary = {}
) -> Dictionary:
	if (
		gs == null
		or typeof(
			gs.scenario_state
		) != TYPE_DICTIONARY
	):
		return {
			"success": false,
			"is_complete": true,
			"progress": 1.0,
			"reason": "artifact_annual_state_unavailable",
			"blocks_ui": false,
			"requires_input_idle": false
		}

	var target_year: int = int(
		payload.get(
			"target_year",
			payload.get(
				"year",
				gs.year
			)
		)
	)
	var state_raw: Variant = (
		gs.scenario_state.get(
			EXCHANGE_ARTIFACT_ANNUAL_EFFECT_STATE_KEY,
			{}
		)
	)
	var annual_state: Dictionary = (
		(state_raw as Dictionary).duplicate(
			true
		)
		if typeof(
			state_raw
		) == TYPE_DICTIONARY
		else {}
	)
	var total_paid: int = 0
	var paid_instances: Array = []
	var accrued_instances: int = 0
	var definition_ids: Array = (
		EXCHANGE_ARTIFACT_DEFINITIONS.keys()
	)

	definition_ids.sort()

	for raw_definition_id in definition_ids:
		var definition_id: String = str(
			raw_definition_id
		).strip_edges().to_lower()
		var definition: Dictionary = (
			_exchange_artifact_definition(
				definition_id
			)
		)
		var annual_bank_stipend: int = int(
			definition.get(
				"annual_bank_stipend",
				0
			)
		)

		if annual_bank_stipend <= 0:
			continue

		var canonical_supply: int = maxi(
			1,
			int(
				definition.get(
					"canonical_supply",
					1
				)
			)
		)

		for instance_index in range(
			1,
			canonical_supply + 1
		):
			var canonical_instance_id: String = (
				_exchange_artifact_instance_id(
					definition_id,
					instance_index
				)
			)
			var ownership_record: Dictionary = (
				_exchange_artifact_instance_ownership_record(
					canonical_instance_id
				)
			)

			if ownership_record.is_empty():
				continue

			var owner_id: int = int(
				ownership_record.get(
					"owner_id",
					-1
				)
			)

			if owner_id <= 0:
				continue

			var ownership_year: int = int(
				ownership_record.get(
					"year",
					target_year
				)
			)
			var effect_raw: Variant = (
				annual_state.get(
					canonical_instance_id,
					{}
				)
			)
			var effect_state: Dictionary = (
				(effect_raw as Dictionary).duplicate(
					true
				)
				if typeof(
					effect_raw
				) == TYPE_DICTIONARY
				else {}
			)

			if int(
				effect_state.get(
					"owner_id",
					-1
				)
			) != owner_id:
				effect_state = {
					"owner_id": owner_id,
					"definition_id": definition_id,
					"canonical_instance_id": canonical_instance_id,
					"last_accrued_year": ownership_year,
					"last_paid_year": ownership_year,
					"unpaid_years": 0,
					"total_paid": 0
				}

			var last_accrued_year: int = int(
				effect_state.get(
					"last_accrued_year",
					ownership_year
				)
			)
			var newly_accrued_years: int = maxi(
				0,
				target_year - last_accrued_year
			)

			if newly_accrued_years > 0:
				effect_state [
					"unpaid_years"
				] = (
					int(
						effect_state.get(
							"unpaid_years",
							0
						)
					)
					+ newly_accrued_years
				)
				effect_state [
					"last_accrued_year"
				] = target_year
				accrued_instances += 1

			var unpaid_years: int = int(
				effect_state.get(
					"unpaid_years",
					0
				)
			)
			var owner: Person = null

			if (
				gs.player != null
				and int(
					gs.player.id
				) == owner_id
			):
				owner = gs.player
			elif gs.has_method(
				"get_npc_by_id"
			):



				owner = gs.get_npc_by_id(
					owner_id,
					false
				)

			if (
				owner != null
				and owner.alive
				and unpaid_years > 0
			):
				var payment_amount: int = (
					unpaid_years
					* annual_bank_stipend
				)

				owner.bank_balance = (
					float(
						owner.bank_balance
					)
					+ float(
						payment_amount
					)
				)

				effect_state [
					"unpaid_years"
				] = 0
				effect_state [
					"last_paid_year"
				] = target_year
				effect_state [
					"total_paid"
				] = (
					int(
						effect_state.get(
							"total_paid",
							0
						)
					)
					+ payment_amount
				)

				total_paid += payment_amount
				paid_instances.append({
					"definition_id": definition_id,
					"canonical_instance_id": canonical_instance_id,
					"owner_id": owner_id,
					"paid_years": unpaid_years,
					"payment_amount": payment_amount
				})

			effect_state [
				"owner_id"
			] = owner_id
			effect_state [
				"definition_id"
			] = definition_id
			effect_state [
				"canonical_instance_id"
			] = canonical_instance_id
			effect_state [
				"annual_bank_stipend"
			] = annual_bank_stipend

			annual_state [
				canonical_instance_id
			] = effect_state

	gs.scenario_state [
		EXCHANGE_ARTIFACT_ANNUAL_EFFECT_STATE_KEY
	] = annual_state

	return {
		"success": true,
		"mode": "exchange_artifact_annual_effects_committed",
		"target_year": target_year,
		"accrued_instances": accrued_instances,
		"paid_instances": paid_instances,
		"total_paid": total_paid,
		"is_complete": true,
		"progress": 1.0,
		"execution_model": "constant_time",
		"population_scan_performed": false,
		"blocks_ui": false,
		"requires_input_idle": false,
		"ui_is_renderer_only": false
	}
func _exchange_artifact_unclaimed_instance_ids(
	definition_id: String,
	definition: Dictionary
) -> Array:
	var out: Array = []
	var canonical_supply: int = maxi(
		1,
		int(
			definition.get(
				"canonical_supply",
				1
			)
		)
	)

	for instance_index in range(
		1,
		canonical_supply + 1
	):
		var canonical_instance_id: String = (
			_exchange_artifact_instance_id(
				definition_id,
				instance_index
			)
		)

		if (
			_exchange_artifact_instance_owner_id(
				canonical_instance_id
			)
			> 0
		):
			continue

		out.append(
			canonical_instance_id
		)

	return out


func _artifact_exchange_reality_seed() -> int:
	if gs == null:
		return 0

	if typeof(
		gs.scenario_state
	) == TYPE_DICTIONARY:
		var scenario_seed: int = int(
			gs.scenario_state.get(
				"world_seed",
				-1
			)
		)

		if scenario_seed > 0:
			return scenario_seed

	if typeof(
		gs.custom_settings
	) == TYPE_DICTIONARY:
		var custom_seed: int = int(
			gs.custom_settings.get(
				"world_seed",
				-1
			)
		)

		if custom_seed > 0:
			return custom_seed

	if (
		gs.seed_engine != null
		and "seed_value" in gs.seed_engine
	):
		var engine_seed: int = int(
			gs.seed_engine.seed_value
		)

		if engine_seed > 0:
			return engine_seed

	return 0


func _artifact_stable_hash(
	text: String
) -> int:
	var value: int = 2166136261
	var source: String = str(text)

	for index in range(
		source.length()
	):
		value = int(
			(
				value
				^ int(
					source.unicode_at(
						index
					)
				)
			)
			* 16777619
		) & 2147483647

	return value


func _exchange_artifact_listing_count(
	definition_id: String,
	definition: Dictionary,
	current_year: int,
	unclaimed_count: int
) -> int:
	if unclaimed_count <= 0:
		return 0

	var policy: String = str(
		definition.get(
			"circulation_policy",
			"annual_probability"
		)
	).strip_edges().to_lower()
	var reality_seed: int = _artifact_exchange_reality_seed()
	var roll: int = _artifact_stable_hash(
		"%s|%d|%d|exchange_artifact_circulation"
		% [
			definition_id,
			current_year,
			reality_seed
		]
	)

	match policy:
		"always_when_unclaimed":
			return mini(
				1,
				unclaimed_count
			)

		"pepe_coin_limited":
			var bucket: int = roll % 1000
			var desired: int = 0

			if (
				bucket >= 380
				and bucket < 690
			):
				desired = 1
			elif (
				bucket >= 690
				and bucket < 860
			):
				desired = 2
			elif (
				bucket >= 860
				and bucket < 950
			):
				desired = 3
			elif bucket >= 950:
				desired = 4

			return mini(
				desired,
				unclaimed_count
			)

		_:
			var basis_points: int = clampi(
				int(
					definition.get(
						"circulation_basis_points",
						1000
					)
				),
				0,
				10000
			)

			if (
				roll % 10000
				< basis_points
			):
				return mini(
					1,
					unclaimed_count
				)

	return 0

func _exchange_artifact_provenance_text(
	definition: Dictionary,
	current_year: int
) -> String:
	var text: String = "PROVENANCE"
	var provenance_raw: Variant = definition.get(
		"provenance_lines",
		[]
	)
	var provenance_lines: Array = (
		provenance_raw as Array
		if typeof(
			provenance_raw
		) == TYPE_ARRAY
		else []
	)

	for raw_line in provenance_lines:
		var line: String = str(
			raw_line
		).strip_edges()

		if line == "":
			continue

		text += "\n" + line

	if bool(
		definition.get(
			"append_current_year_provenance",
			false
		)
	):
		text += (
			"\n%d — Admitted to the Luxury Sanctorum"
			% current_year
		)

	return text


func _exchange_artifact_catalog_row(
	definition_id: String,
	definition: Dictionary,
	canonical_instance_id: String,
	current_year: int,
	status_text: String
) -> Dictionary:
	var current_value: int = (
		_exchange_artifact_current_value(
			definition,
			current_year
		)
	)
	var origin_text: String = str(
		definition.get(
			"origin",
			"Unknown"
		)
	)
	var known_owners: String = str(
		definition.get(
			"known_owners",
			"—"
		)
	)
	var last_transfer: String = str(
		definition.get(
			"last_transfer",
			"—"
		)
	)
	var condition_text: String = str(
		definition.get(
			"condition",
			"Documented"
		)
	)

	return {
		"id": definition_id,
		"name": str(
			definition.get(
				"name",
				"Artifact"
			)
		),
		"display_name": str(
			definition.get(
				"name",
				"Artifact"
			)
		),
		"grant_type": "exchange_artifact",
		"artifact_kind": "exchange_artifact",
		"type": "Historic Artifact",
		"catalog_source": "luxury_sanctorum_artifact_authority",
		"canonical_instance_id": canonical_instance_id,
		"listing_instance_id": canonical_instance_id,
		"canonical_supply": maxi(
			1,
			int(
				definition.get(
					"canonical_supply",
					1
				)
			)
		),
		"circulation_policy": str(
			definition.get(
				"circulation_policy",
				"annual_probability"
			)
		),
		"cost": current_value,
		"price": current_value,
		"value": current_value,
		"base_value": int(
			definition.get(
				"base_value",
				current_value
			)
		),
		"annual_appreciation_rate": float(
			definition.get(
				"annual_appreciation_rate",
				0.0
			)
		),
		"valuation_origin_mode": str(
			definition.get(
				"valuation_origin_mode",
				"fixed_year"
			)
		),
		"valuation_origin_year": (
			_exchange_artifact_valuation_origin_year(
				definition,
				current_year
			)
		),
		"annual_bank_stipend": int(
			definition.get(
				"annual_bank_stipend",
				0
			)
		),
		"cost_display": (
			_format_exchange_artifact_money(
				current_value
			)
		),
		"status_text": status_text,
		"rarity": str(
			definition.get(
				"rarity",
				"Beyond Mythic"
			)
		),
		"mythic_rank": str(
			definition.get(
				"mythic_rank",
				"Historical Anomaly"
			)
		),
		"classification_display": str(
			definition.get(
				"classification_display",
				"◆ BEYOND MYTHIC ◆"
			)
		),
		"classification_family": str(
			definition.get(
				"classification_family",
				"ARTIFACT"
			)
		),
		"house_text": str(
			definition.get(
				"house_text",
				"HISTORIC ARTIFACT"
			)
		),
		"display_color_key": str(
			definition.get(
				"display_color_key",
				"gold"
			)
		),
		"editorial_rank": int(
			definition.get(
				"editorial_rank",
				1500
			)
		),
		"origin": origin_text,
		"origin_country": str(
			definition.get(
				"origin_country",
				""
			)
		),
		"origin_era": str(
			definition.get(
				"origin_era",
				""
			)
		),
		"known_owners": known_owners,
		"last_transfer": last_transfer,
		"condition_text": condition_text,
		"provenance_text": (
			"Origin · %s\n"
			+ "Known owners · %s\n"
			+ "Last transfer · %s\n"
			+ "Condition · %s"
		) % [
			origin_text,
			known_owners,
			last_transfer,
			condition_text
		],
		"history_note": (
			_exchange_artifact_provenance_text(
				definition,
				current_year
			)
		),
		"description": str(
			definition.get(
				"description",
				""
			)
		),
		"lore": str(
			definition.get(
				"description",
				""
			)
		),
		"authority_note": str(
			definition.get(
				"authority_note",
				""
			)
		),
		"extraordinary_family_lives": int(
			definition.get(
				"extraordinary_family_lives",
				0
			)
		),
		"leave_label": str(
			definition.get(
				"leave_label",
				"LEAVE."
			)
		),
		"cross_reality_persistent": true,
		"inheritable": true,
		"heirloom_candidate": true,
		"market_year": current_year
	}


func get_exchange_artifact_catalog_rows(
	_actor: Person = null
) -> Array:
	var out: Array = []

	if gs == null:
		return out

	var current_year: int = int(
		gs.year
	)
	var definition_ids: Array = (
		EXCHANGE_ARTIFACT_DEFINITIONS.keys()
	)

	definition_ids.sort()

	for raw_definition_id in definition_ids:
		var definition_id: String = str(
			raw_definition_id
		)
		var definition: Dictionary = (
			_exchange_artifact_definition(
				definition_id
			)
		)

		if not _exchange_artifact_exists_in_year(
			definition,
			current_year
		):
			continue

		var unclaimed_instances: Array = (
			_exchange_artifact_unclaimed_instance_ids(
				definition_id,
				definition
			)
		)
		var status_text: String = (
			"Available"
			if not unclaimed_instances.is_empty()
			else "Claimed"
		)
		var row: Dictionary = (
			_exchange_artifact_catalog_row(
				definition_id,
				definition,
				"",
				current_year,
				status_text
			)
		)

		row [
			"available_instance_count"
		] = unclaimed_instances.size()
		row [
			"currently_circulating"
		] = false

		out.append(
			row
		)

	return out


func get_luxury_exchange_artifact_rows(
	_actor: Person = null
) -> Array:
	var out: Array = []

	if gs == null:
		return out

	var current_year: int = int(
		gs.year
	)
	var reality_seed: int = (
		_artifact_exchange_reality_seed()
	)
	var definition_ids: Array = (
		EXCHANGE_ARTIFACT_DEFINITIONS.keys()
	)

	definition_ids.sort()

	for raw_definition_id in definition_ids:
		var definition_id: String = str(
			raw_definition_id
		)
		var definition: Dictionary = (
			_exchange_artifact_definition(
				definition_id
			)
		)

		if not _exchange_artifact_exists_in_year(
			definition,
			current_year
		):
			continue

		var unclaimed_instances: Array = (
			_exchange_artifact_unclaimed_instance_ids(
				definition_id,
				definition
			)
		)
		var listing_count: int = (
			_exchange_artifact_listing_count(
				definition_id,
				definition,
				current_year,
				unclaimed_instances.size()
			)
		)

		if listing_count <= 0:
			continue

		unclaimed_instances.sort_custom(
			func (a, b):
				var key_a: int = _artifact_stable_hash(
					"%s|%s|%d|%d|listing_instance"
					% [
						definition_id,
						str(a),
						current_year,
						reality_seed
					]
				)
				var key_b: int = _artifact_stable_hash(
					"%s|%s|%d|%d|listing_instance"
					% [
						definition_id,
						str(b),
						current_year,
						reality_seed
					]
				)

				return key_a > key_b
		)

		for index in range(
			mini(
				listing_count,
				unclaimed_instances.size()
			)
		):
			var canonical_instance_id: String = str(
				unclaimed_instances [
					index
				]
			)
			var row: Dictionary = (
				_exchange_artifact_catalog_row(
					definition_id,
					definition,
					canonical_instance_id,
					current_year,
					"Available"
				)
			)

			row [
				"currently_circulating"
			] = true

			out.append(
				row
			)

	return out

func _exchange_artifact_listing_is_live(
	definition_id: String,
	canonical_instance_id: String,
	actor: Person
) -> bool:
	for raw_row in get_luxury_exchange_artifact_rows(
		actor
	):
		if typeof(
			raw_row
		) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = raw_row as Dictionary

		if str(
			row.get(
				"id",
				""
			)
		).strip_edges().to_lower() != str(
			definition_id
		).strip_edges().to_lower():
			continue

		if str(
			row.get(
				"canonical_instance_id",
				""
			)
		).strip_edges().to_lower() == str(
			canonical_instance_id
		).strip_edges().to_lower():
			return true

	return false
func shop_inventory_entry_at(
	npc: Person,
	slot_index: int
) -> Dictionary:
	if (
		slot_index < 0
		or slot_index >= SHOP_ORDER.size()
	):
		return {}

	var item_id: String = str(
		SHOP_ORDER [
			slot_index
		]
	)
	var entry: Dictionary = _get_shop_entry(
		item_id
	)

	if entry.is_empty():
		return {}

	var grant_type: String = str(
		entry.get(
			"grant_type",
			""
		)
	)

	if (
		grant_type == "dragon_ball"
		and (
			gs == null
			or gs.dragonballs_engine == null
			or not gs.is_feature_enabled(
				"dragonballs"
			)
		)
	):
		return {}

	if (
		grant_type == "infinity_stone"
		and (
			gs == null
			or not gs.is_feature_enabled(
				"artifacts"
			)
		)
	):
		return {}

	var availability: Dictionary = (
		_shop_entry_availability(
			npc,
			entry
		)
	)
	var display_color_key: String = str(
		entry.get(
			"color",
			""
		)
	).strip_edges().to_lower()

	if display_color_key == "":
		match grant_type:
			"dragon_ball":
				display_color_key = "orange"

			"infinity_stone":
				var stone_name: String = str(
					entry.get(
						"stone",
						""
					)
				).strip_edges()

				if STONES.has(
					stone_name
				):
					display_color_key = str(
						STONES [
							stone_name
						].get(
							"color",
							""
						)
					).strip_edges().to_lower()

			"red_bonnet":
				display_color_key = "red"

	entry [
		"display_color_key"
	] = display_color_key
	entry [
		"cost_display"
	] = _format_shop_cost(
		entry
	)
	entry [
		"status_text"
	] = str(
		availability.get(
			"status",
			"Available"
		)
	)
	entry [
		"purchase_hint"
	] = str(
		availability.get(
			"text",
			""
		)
	)

	var price: int = _resolved_shop_cost(
		entry
	)

	if (
		price > 0
		and npc != null
		and float(
			npc.bank_balance
		) < float(
			price
		)
		and str(
			entry.get(
				"grant_type",
				""
			)
		) != "red_bonnet"
	):
		entry [
			"status_text"
		] = "Too Expensive"
		entry [
			"purchase_hint"
		] = (
			"You do not currently have enough money "
			+ "for this artifact."
		)

	return entry


func get_shop_inventory(
	npc: Person
) -> Array:
	var out: Array = []

	for slot_index in range(
		shop_inventory_slot_count()
	):
		var entry: Dictionary = (
			shop_inventory_entry_at(
				npc,
				slot_index
			)
		)

		if entry.is_empty():
			continue

		out.append(
			entry
		)

	return out


func purchase_shop_item(npc: Person, item_id: String) -> Dictionary:
	if npc == null:
		return { "success": false, "text": "No active life loaded."}

	var entry: Dictionary = _get_shop_entry(item_id)
	if entry.is_empty():
		return { "success": false, "text": "That artifact does not exist in the shop."}

	var availability: Dictionary = _shop_entry_availability(npc, entry)
	if not bool(availability.get("available", false)):
		var blocked_text: String = str(availability.get("text", "That artifact is unavailable."))

		var blocked_result:= {
			"success": false,
			"text": blocked_text
		}

		if str(entry.get("grant_type", "")) == "red_bonnet":
			blocked_result ["popup_title"] = "Red Bonnet"
			blocked_result ["popup_text"] = "No Amount of wealth in the world can purchase this. Said to be a gift from Heaven. Given back once."
			blocked_result ["popup_footer"] = "Tap anywhere to continue."

		return blocked_result

	var price: int = _resolved_shop_cost(entry)
	if price > 0 and float(npc.bank_balance) < float(price):
		return {
			"success": false,
			"text": "I do not have enough money to purchase the %s." % str(entry.get("name", "artifact"))
		}

	var grant_result: Dictionary = _grant_shop_entry(npc, entry)
	if not bool(grant_result.get("success", false)):
		return grant_result

	if price > 0:
		npc.bank_balance = max(0.0, float(npc.bank_balance) - float(price))

	var item_name: String = str(entry.get("name", "Artifact"))
	var cost_text: String = _format_shop_cost(entry)
	var extra_text: String = str(grant_result.get("effect_text", "")).strip_edges()

	var diary_text:= "I bought the %s from the Artifact Shop for %s." % [item_name, cost_text]
	if extra_text != "":
		diary_text += " " + extra_text

	var popup_text:= "You purchased the %s for %s." % [item_name, cost_text]
	if extra_text != "":
		popup_text += "\n\n" + extra_text

	return {
		"success": true,
		"text": diary_text,
		"popup_title": item_name,
		"popup_text": popup_text,
		"popup_footer": "Tap anywhere to continue."
	}


func _grant_shop_entry(npc: Person, entry: Dictionary) -> Dictionary:
	var grant_type: String = str(entry.get("grant_type", ""))

	match grant_type:
		"basic_artifact":
			return _grant_shop_basic_artifact(npc, entry)

		"dragon_ball":
			if gs == null or gs.dragonballs_engine == null or not gs.dragonballs_engine.has_method("grant_shop_ball"):
				return { "success": false, "text": "Dragon Ball shop fulfillment is not available right now."}
			return gs.dragonballs_engine.grant_shop_ball(npc, int(entry.get("star", 0)))

		"infinity_stone":
			return _grant_shop_stone(npc, str(entry.get("stone", "")))

		"red_bonnet":
			return { "success": false, "text": "No amount of wealth in this world can purchase this."}

		_:
			return { "success": false, "text": "That artifact cannot be granted from the shop."}


func _grant_shop_basic_artifact(
	npc: Person,
	entry: Dictionary
) -> Dictionary:
	if (
		gs == null
		or gs.belongings_engine == null
	):
		return {
			"success": false,
			"text": "Belongings are not available right now."
		}

	var item_name: String = str(
		entry.get(
			"name",
			"Artifact"
		)
	)

	if gs.belongings_engine.has_item_named(
		npc,
		"Artifacts",
		item_name
	):
		return {
			"success": false,
			"text": "You already own the %s." % item_name
		}

	var artifact_item_id: int = int(
		gs.next_id
	)
	gs.next_id += 1

	var market_fields: Dictionary = (
		_build_artifact_market_fields(
			entry
		)
	)
	var shop_item_id: String = str(
		entry.get(
			"id",
			""
		)
	).strip_edges().to_lower()
	var catalog_object_id: String = (
		"artifact:%s" % shop_item_id
		if shop_item_id != ""
		else "artifact:%s" % item_name.to_lower().replace(
			" ",
			"_"
		).replace(
			"-",
			"_"
		)
	)
	var instance_object_id: String = (
		"object_instance:%d" % artifact_item_id
	)
	var origin_era: String = (
		str(
			gs.era.name
		)
		if gs.era != null
		else ""
	)
	var artifact_item: Dictionary = {
		"id": artifact_item_id,
		"object_id": instance_object_id,
		"instance_object_id": instance_object_id,
		"catalog_object_id": catalog_object_id,
		"name": item_name,
		"display_name": item_name,
		"type": "Artifact",
		"asset_kind": "artifact",
		"object_domains": [
			"artifact"
		],
		"rarity": str(
			entry.get(
				"rarity",
				"Rare"
			)
		),
		"lore": str(
			entry.get(
				"lore",
				""
			)
		),
		"ability": str(
			entry.get(
				"ability",
				""
			)
		),
		"color": str(
			entry.get(
				"color",
				"gold"
			)
		),
		"origin_era": origin_era,
		"origin_country": str(
			entry.get(
				"origin_country",
				""
			)
		),
		"origin_contract": {
			"era": origin_era,
			"year": int(
				gs.year
			),
			"country": str(
				entry.get(
					"origin_country",
					""
				)
			),
			"source": "artifact_shop",
			"source_event": (
				ActionEventTypes.ARTIFACT_ACQUIRED
			)
		},
		"acquired_year": int(
			gs.year
		),
		"artifact_kind": str(
			entry.get(
				"artifact_kind",
				"shop_artifact"
			)
		),
		"shop_item_id": shop_item_id,
		"value": int(
			market_fields.get(
				"value",
				0
			)
		),
		"base_value": int(
			market_fields.get(
				"base_value",
				0
			)
		),
		"annual_appreciation_rate": float(
			market_fields.get(
				"annual_appreciation_rate",
				0.0
			)
		),
		"historical_value": int(
			entry.get(
				"historical_value",
				0
			)
		),
		"cultural_value": int(
			entry.get(
				"cultural_value",
				0
			)
		),
		"legal": bool(
			entry.get(
				"legal",
				true
			)
		),
		"legal_classification": str(
			entry.get(
				"legal_classification",
				"artifact"
			)
		),
		"ownership_chain": [
			{
				"owner_id": int(
					npc.id
				),
				"acquired_year": int(
					gs.year
				),
				"mode": "purchase",
				"source": "artifact_shop"
			}
		],
		"inheritable": true,
		"heirloom_candidate": true,
		"cross_reality_persistent": true,
		"affordances": [
			"artifact_action_provider",
			"heirloom_candidate",
			"historical_value_provider",
			"object_history_anchor"
		],
		"object_history": [
			{
				"event_type": "artifact_purchased",
				"year": int(
					gs.year
				),
				"owner_id": int(
					npc.id
				),
				"source": "artifact_shop"
			}
		]
	}

	gs.belongings_engine.add_item(
		npc,
		artifact_item,
		"Artifacts",
		false,
		{
			"source": "artifacts_engine.shop_purchase",
			"catalog_object_id": catalog_object_id,
			"instance_object_id": instance_object_id,
			"event_name": (
				ActionEventTypes.ARTIFACT_ACQUIRED
			)
		}
	)

	_apply_buffs(
		npc,
		entry.get(
			"buffs",
			{}
		)
	)

	var prestige_bonus: int = int(
		entry.get(
			"dynasty_prestige_bonus",
			0
		)
	)

	if prestige_bonus != 0:
		npc.dynasty_prestige = int(
			npc.dynasty_prestige
		) + prestige_bonus

	var fame_bonus: int = int(
		entry.get(
			"fame_bonus",
			0
		)
	)

	if fame_bonus != 0:
		npc.fame = clampi(
			int(
				npc.fame
			) + fame_bonus,
			0,
			100
		)

	if (
		prestige_bonus != 0
		and gs.dynasty_legacy_engine != null
	):
		gs.dynasty_legacy_engine.add_reputation(
			npc,
			int(
				round(
					prestige_bonus * 0.4
				)
			)
		)

	var msg: String = (
		"%s %s purchased the %s from the Artifact Shop."
		% [
			npc.first_name,
			npc.last_name,
			item_name
		]
	)

	gs.push_world_feed(
		msg,
		{
			"npc_id": npc.id,
			"personally_relevant": npc == gs.player,
			"category": "artifact",
			"event_name": (
				ActionEventTypes.ARTIFACT_ACQUIRED
			),
			"source": "artifacts_engine",
			"catalog_object_id": catalog_object_id,
			"instance_object_id": instance_object_id
		}
	)

	if gs.event_bus != null:
		gs.event_bus.emit(
			ActionEventTypes.ARTIFACT_ACQUIRED,
			{
				"npc_id": npc.id,
				"artifact": item_name,
				"catalog_object_id": catalog_object_id,
				"instance_object_id": instance_object_id,
				"text": msg,
				"source": "artifacts_engine"
			}
		)

	npc.memories.append(
		"I purchased the %s from the Artifact Shop."
		% item_name
	)

	return {
		"success": true,
		"catalog_object_id": catalog_object_id,
		"instance_object_id": instance_object_id,
		"belongings_item": artifact_item.duplicate(true),
		"effect_text": str(
			entry.get(
				"ability",
				""
			)
		).strip_edges()
	}


func _grant_shop_stone(npc: Person, stone: String) -> Dictionary:
	if gs == null or not gs.is_feature_enabled("artifacts"):
		return { "success": false, "text": "Infinity Stones are not active in this reality."}
	if stone == "" or not STONES.has(stone):
		return { "success": false, "text": "That Infinity Stone does not exist."}
	if stone == "Soul":
		return { "success": false, "text": "The Soul Stone cannot be purchased. It can only be claimed on Vormir."}
	if ownership.has(npc.id) and stone in ownership.get(npc.id, []):
		return { "success": false, "text": "You already hold the %s Stone." % stone}
	if stone in _globally_owned_stones():
		return { "success": false, "text": "The %s Stone is already in someone else's possession." % stone}
	_give_stone(npc, stone, {
		"source": "artifact_shop",
		"event_source": "artifacts_engine"
	})
	return {
		"success": true,
		"effect_text": _stone_acquisition_effect_text(stone)
	}
func _globally_owned_stones() -> Array:
	var owned: Array = []
	for pid in ownership.keys():
		var held: Array = ownership.get(pid, [])
		for stone_value in held:
			var stone_name: String = str(stone_value)
			if stone_name == "":
				continue
			if stone_name in owned:
				continue
			owned.append(stone_name)
	return owned

func _globally_available_stones() -> Array:
	var available: Array = []
	var owned: Array = _globally_owned_stones()
	for stone_key in STONES.keys():
		var stone_name: String = str(stone_key)
		if stone_name == "Soul":
			continue
		if stone_name in owned:
			continue
		available.append(stone_name)
	return available



func spawn_initial_artifacts():
	if gs == null or not gs.is_feature_enabled("artifacts"):
		return
	var available: Array = _globally_available_stones()
	if available.is_empty():
		return
	var attempts: int = min(randi_range(0, 2), available.size())
	for i in range(attempts):
		_spawn_stone_randomly()


func _spawn_stone_randomly():
	if gs == null or not gs.is_feature_enabled("artifacts"):
		return
	var available: Array = _globally_available_stones()
	if available.is_empty():
		return
	var stone: String = str(available [randi() % available.size()])
	var candidates = []
	for npc in gs.npcs:
		if npc.age >= 18 and npc.alive:
			candidates.append(npc)
	if candidates.size() == 0:
		return
	var holder = candidates [randi() % candidates.size()]
	_give_stone(holder, stone)





func _stone_ability_text(stone: String) -> String:
	match stone:
		"Power":
			return "Turns force into a weapon system - impact, overload, domination, and catastrophic physical pressure."
		"Mind":
			return "Rules thought itself - perception, genius, fear, awe, and direct psychic intrusion."
		"Reality":
			return "Rewrites the laws beneath flesh, fate, status, beauty, and supernatural identity."
		"Space":
			return "Folds distance, summons bodies, banishes targets, and tears openings between places and realms."
		"Time":
			return "Rewinds damage, steals years, suspends youth, and drags destiny into view."
		"Soul":
			return "Commands spirit, sacred bonds, bloodline blessing, restoration, and soul-deep ruin."
		_:
			return "Radiates unstable cosmic power."
func _stone_acquisition_effect_text(stone: String) -> String:
	match stone:
		"Power":
			return "A violent pulse of raw force settles into my bones."
		"Mind":
			return "A cold psychic hum settles behind my eyes."
		"Reality":
			return "The edges of the world suddenly feel loose around my hands."
		"Space":
			return "Distance itself starts feeling foldable."
		"Time":
			return "Every second around me suddenly feels touchable."
		"Soul":
			return "Something ancient tugs at the spirit behind my chest."
		_:
			return "Cosmic power settles into my hands."

func _artifact_build_stone_action_texts(player: Person, target: Person, item_name: String, action_name: String) -> Dictionary:
	if player == null or target == null:
		return {}

	var actor_name: String = str(player.first_name).strip_edges()
	var target_name: String = ("%s %s" % [target.first_name, target.last_name]).strip_edges()

	match item_name:
		"Mind Stone":
			match action_name:
				"Read Mind":
					return {
						"world_text": "\n \n %s slipped past %s's mental guard and read their private thoughts with the Mind Stone." % [actor_name, target_name],
						"diary_text": "\n \n I slipped past %s's mental guard and read their private thoughts with the Mind Stone." % target_name
					}
				"Soothe Mind":
					return {
						"world_text": "\n \n %s washed calm through %s's mind with the Mind Stone." % [actor_name, target_name],
						"diary_text": "\n \n I washed calm through %s's mind with the Mind Stone." % target_name
					}
				"Awaken Genius":
					return {
						"world_text": "\n \n %s ignited hidden brilliance inside %s with the Mind Stone." % [actor_name, target_name],
						"diary_text": "\n \n I ignited hidden brilliance inside %s with the Mind Stone." % target_name
					}
				"Instill Awe":
					return {
						"world_text": "\n \n %s pressed cosmic perception into %s until awe took hold." % [actor_name, target_name],
						"diary_text": "\n \n I pressed cosmic perception into %s until awe took hold." % target_name
					}
				"Erase Fear":
					return {
						"world_text": "\n \n %s stripped fear from %s's mind with the Mind Stone." % [actor_name, target_name],
						"diary_text": "\n \n I stripped fear from %s's mind with the Mind Stone." % target_name
					}
				"Reveal Truth":
					return {
						"world_text": "\n \n %s forced a terrible cosmic truth into %s's mind." % [actor_name, target_name],
						"diary_text": "\n \n I forced a terrible cosmic truth into %s's mind." % target_name
					}

		"Reality Stone":
			match action_name:
				"Warp Fate":
					return {
						"world_text": "\n \n %s bent probability against %s with the Reality Stone." % [actor_name, target_name],
						"diary_text": "\n \n I bent probability against %s with the Reality Stone." % target_name
					}
				"Curse Health":
					return {
						"world_text": "\n \n %s rewrote %s's flesh into suffering with the Reality Stone." % [actor_name, target_name],
						"diary_text": "\n \n I rewrote %s's flesh into suffering with the Reality Stone." % target_name
					}
				"Alter Trait":
					return {
						"world_text": "\n \n %s rewrote %s at the trait level with the Reality Stone." % [actor_name, target_name],
						"diary_text": "\n \n I rewrote %s at the trait level with the Reality Stone." % target_name
					}
				"Beautify Form":
					return {
						"world_text": "\n \n %s rewrote %s's form into impossible beauty." % [actor_name, target_name],
						"diary_text": "\n \n I rewrote %s's form into impossible beauty." % target_name
					}
				"Make Wealthy":
					return {
						"world_text": "\n \n %s rewrote %s's circumstances until wealth flooded into their life." % [actor_name, target_name],
						"diary_text": "\n \n I rewrote %s's circumstances until wealth flooded into their life." % target_name
					}
				"Rewrite Status":
					return {
						"world_text": "\n \n %s rewrote %s's place in the world with the Reality Stone." % [actor_name, target_name],
						"diary_text": "\n \n I rewrote %s's place in the world with the Reality Stone." % target_name
					}
				"Grant Gift":
					return {
						"world_text": "\n \n %s rewrote reality to place a supernatural gift inside %s." % [actor_name, target_name],
						"diary_text": "\n \n I rewrote reality to place a supernatural gift inside %s." % target_name
					}
				"Remove Gift":
					return {
						"world_text": "\n \n %s rewrote reality to strip supernatural favor from %s." % [actor_name, target_name],
						"diary_text": "\n \n I rewrote reality to strip supernatural favor from %s." % target_name
					}

		"Space Stone":
			match action_name:
				"Teleport To Me":
					return {
						"world_text": "\n \n %s folded distance and pulled %s across space." % [actor_name, target_name],
						"diary_text": "\n \n I folded distance and pulled %s across space." % target_name
					}
				"Banish Away":
					return {
						"world_text": "\n \n %s tore open space and cast %s away." % [actor_name, target_name],
						"diary_text": "\n \n I tore open space and cast %s away." % target_name
					}
				"Summon Before Me":
					return {
						"world_text": "\n \n %s split the distance and summoned %s before them." % [actor_name, target_name],
						"diary_text": "\n \n I split the distance and summoned %s before me." % target_name
					}
				"Shift Realm":
					return {
						"world_text": "\n \n %s bent space around %s and pushed them into another realm." % [actor_name, target_name],
						"diary_text": "\n \n I bent space around %s and pushed them into another realm." % target_name
					}

		"Time Stone":
			match action_name:
				"Restore Health":
					return {
						"world_text": "\n \n %s rewound damage from %s with the Time Stone." % [actor_name, target_name],
						"diary_text": "\n \n I rewound damage from %s with the Time Stone." % target_name
					}
				"Drain Years":
					return {
						"world_text": "\n \n %s siphoned years away from %s with the Time Stone." % [actor_name, target_name],
						"diary_text": "\n \n I siphoned years away from %s with the Time Stone." % target_name
					}
				"Freeze Youth":
					return {
						"world_text": "\n \n %s locked %s's youth in place with the Time Stone." % [actor_name, target_name],
						"diary_text": "\n \n I locked %s's youth in place with the Time Stone." % target_name
					}
				"Age Target":
					return {
						"world_text": "\n \n %s forced years onto %s in a single collapsing moment." % [actor_name, target_name],
						"diary_text": "\n \n I forced years onto %s in a single collapsing moment." % target_name
					}
				"Glimpse Destiny":
					return {
						"world_text": "\n \n %s dragged %s's sight across time and forced a glimpse of destiny." % [actor_name, target_name],
						"diary_text": "\n \n I dragged %s's sight across time and forced a glimpse of destiny." % target_name
					}

		"Soul Stone":
			match action_name:
				"Deepen Bond":
					return {
						"world_text": "\n \n %s braided their spirit more deeply to %s with the Soul Stone." % [actor_name, target_name],
						"diary_text": "\n \n I braided my spirit more deeply to %s with the Soul Stone." % target_name
					}
				"Drain Spirit":
					return {
						"world_text": "\n \n %s ripped spiritual strength out of %s with the Soul Stone." % [actor_name, target_name],
						"diary_text": "\n \n I ripped spiritual strength out of %s with the Soul Stone." % target_name
					}
				"Bless Bloodline":
					return {
						"world_text": "\n \n %s blessed %s's bloodline at the soul level." % [actor_name, target_name],
						"diary_text": "\n \n I blessed %s's bloodline at the soul level." % target_name
					}
				"Restore Spirit":
					return {
						"world_text": "\n \n %s restored %s's spirit with the Soul Stone." % [actor_name, target_name],
						"diary_text": "\n \n I restored %s's spirit with the Soul Stone." % target_name
					}
				"Bind Fate To Mine":
					return {
						"world_text": "\n \n %s tied %s's fate to their own soul." % [actor_name, target_name],
						"diary_text": "\n \n I tied %s's fate to my own soul." % target_name
					}
				"Sever Bond":
					return {
						"world_text": "\n \n %s severed a sacred soul-bond with %s." % [actor_name, target_name],
						"diary_text": "\n \n I severed a sacred soul-bond with %s." % target_name
					}

		"Power Stone":
			match action_name:
				"Empower":
					return {
						"world_text": "\n \n %s poured violent raw power into %s with the Power Stone." % [actor_name, target_name],
						"diary_text": "\n \n I poured violent raw power into %s with the Power Stone." % target_name
					}
				"Crush":
					return {
						"world_text": "\n \n %s brought the Power Stone down on %s with crushing force." % [actor_name, target_name],
						"diary_text": "\n \n I brought the Power Stone down on %s with crushing force." % target_name
					}
				"Overcharge Body":
					return {
						"world_text": "\n \n %s overloaded %s's body with more power than flesh should hold." % [actor_name, target_name],
						"diary_text": "\n \n I overloaded %s's body with more power than flesh should hold." % target_name
					}
				"Force Submission":
					return {
						"world_text": "\n \n %s buried %s beneath the will of the Power Stone." % [actor_name, target_name],
						"diary_text": "\n \n I buried %s beneath the will of the Power Stone." % target_name
					}
				"Make Legendary":
					return {
						"world_text": "\n \n %s blasted %s with enough power to make them feel untouchable." % [actor_name, target_name],
						"diary_text": "\n \n I blasted %s with enough power to make them feel untouchable." % target_name
					}

	return {}
func _stone_item_name(stone: String) -> String:
	return "%s Stone" % stone

func _normalize_artifact_item_name(item_name: String) -> String:
	var normalized: String = str(item_name).strip_edges()
	normalized = normalized.replace(" Infinity Stone", " Stone")
	return normalized

func get_artifact_action_definitions(item: Dictionary) -> Array:
	var item_name: String = _normalize_artifact_item_name(str(item.get("name", "")))

	match item_name:
		"Mind Stone":
			return [
				{ "id": "mind_soothe", "label": "Soothe Mind", "phrase": "soothe the mind of", "health_delta": 6, "bond_delta": 12},
				{ "id": "mind_overload", "label": "Overload Thoughts", "phrase": "overload the thoughts of", "health_delta": -8, "bond_delta": -12}
			]
		"Reality Stone":
			return [
				{ "id": "reality_mend", "label": "Mend Body", "phrase": "mend the body of", "health_delta": 14, "bond_delta": 6},
				{ "id": "reality_twist", "label": "Twist Fate", "phrase": "twist the fate of", "health_delta": -14, "bond_delta": -16}
			]
		"Space Stone":
			return [
				{ "id": "space_rescue", "label": "Warp To Safety", "phrase": "warp to safety", "health_delta": 10, "bond_delta": 8},
				{ "id": "space_displace", "label": "Displace Body", "phrase": "violently displace", "health_delta": -10, "bond_delta": -10}
			]
		"Time Stone":
			return [
				{ "id": "time_rewind", "label": "Rewind Wounds", "phrase": "rewind the wounds of", "health_delta": 16, "bond_delta": 10},
				{ "id": "time_age", "label": "Age Body", "phrase": "age the body of", "health_delta": -12, "bond_delta": -14}
			]
		"Soul Stone":
			return [
				{ "id": "soul_mend", "label": "Soul Mend", "phrase": "soul mend", "health_delta": 8, "bond_delta": 16},
				{ "id": "soul_drain", "label": "Soul Drain", "phrase": "drain the soul of", "health_delta": -15, "bond_delta": -18}
			]
		"Power Stone":
			return [
				{ "id": "power_empower", "label": "Empower Target", "phrase": "empower", "health_delta": 12, "bond_delta": 6},
				{ "id": "power_overwhelm", "label": "Overwhelm Target", "phrase": "overwhelm", "health_delta": -20, "bond_delta": -16}
			]
		"Infinity Gauntlet", "Gauntlet":
			return [
				{ "id": "gauntlet_perfect", "label": "Perfect Target", "phrase": "perfect", "health_delta": 24, "bond_delta": 18},
				{ "id": "gauntlet_crush", "label": "Crush Target", "phrase": "crush", "health_delta": -30, "bond_delta": -24}
			]
		_:
			return []

func use_artifact_on_target(user: Person, item: Dictionary, action_id: String, target: Person) -> Dictionary:
	if user == null or target == null:
		return { "success": false, "text": "No valid target was selected."}

	if gs == null:
		return { "success": false, "text": "The world state is not ready right now."}

	var chosen_action: Dictionary = {}
	var actions: Array = get_artifact_action_definitions(item)
	for action_entry in actions:
		if str(action_entry.get("id", "")) == action_id:
			chosen_action = action_entry
			break

	if chosen_action.is_empty():
		return { "success": false, "text": "That artifact action is not available."}

	var display_name: String = _normalize_artifact_item_name(str(item.get("name", "Artifact")))
	var phrase: String = str(chosen_action.get("phrase", "affect"))
	var health_delta: int = int(chosen_action.get("health_delta", 0))
	var bond_delta: int = int(chosen_action.get("bond_delta", 0))
	var target_ref: String = gs.get_target_reference_for_observer(user, target)

	target.health = clamp(int(target.health) + health_delta, 1, 200)
	user.affection [target.id] = clamp(int(user.affection.get(target.id, 50)) + bond_delta, 0, 100)
	target.affection [user.id] = clamp(int(target.affection.get(user.id, 50)) + bond_delta, 0, 100)

	if gs.social_graph_engine != null:
		gs.social_graph_engine.modify_affection(user.id, target.id, bond_delta)

	var world_text: String = "%s %s used the %s to %s %s %s." % [
		user.first_name,
		user.last_name,
		display_name,
		phrase,
		target.first_name,
		target.last_name
	]

	var player_text: String = "I used the %s to %s %s." % [
		display_name,
		phrase,
		target_ref
	]

	if health_delta > 0:
		player_text += " Their health improved."
	elif health_delta < 0:
		player_text += " Their health dropped."

	if bond_delta > 0:
		player_text += " Our bond grew stronger."
	elif bond_delta < 0:
		player_text += " Our bond got worse."

	gs.push_world_feed(world_text, {
		"npc_id": user.id,
		"personally_relevant": true,
		"category": "artifact",
		"event_name": "artifact_used",
		"source": "artifacts_engine"
	})

	if gs.narrative_engine != null:
		gs.narrative_engine.log_event(user, { "type": "text", "text": player_text})
	else:
		user.memories.append(player_text)

	target.memories.append("The %s was used on me by %s %s." % [
		display_name,
		user.first_name,
		user.last_name
	])

	return { "success": true, "text": player_text}
func _give_stone(npc: Person, stone: String, acquisition_context: Dictionary = {}):
	if gs == null or not gs.is_feature_enabled("artifacts"):
		return
	if stone == "Soul" and str(acquisition_context.get("source", "")).strip_edges() != "vormir_sacrifice":
		return
	if not ownership.has(npc.id):
		ownership [npc.id] = []

	if stone in ownership [npc.id]:
		return
	ownership [npc.id].append(stone)

	var stone_item_id: int = gs.next_id
	gs.next_id += 1

	var market_entry: Dictionary = {
		"grant_type": "infinity_stone",
		"stone": stone
	}
	var market_fields: Dictionary = _build_artifact_market_fields(market_entry)

	gs.belongings_engine.add_item(npc, {
		"id": stone_item_id,
		"name": "%s Stone" % stone,
		"type": "Artifact",
		"artifact_kind": "stone",
		"stone_key": stone,
		"lore": STONES [stone] ["lore"],
		"ability": _stone_ability_text(stone),
		"color": STONES [stone] ["color"],
		"origin_era": gs.era.name,
		"acquired_year": gs.year,
		"value": int(market_fields.get("value", 0)),
		"base_value": int(market_fields.get("base_value", 0)),
		"annual_appreciation_rate": float(market_fields.get("annual_appreciation_rate", 0.0))
	}, "Artifacts")

	_apply_buffs(npc, STONES [stone].buffs)

	var acquisition_source: String = str(acquisition_context.get("source", "discovery")).strip_edges()
	var event_source: String = str(acquisition_context.get("event_source", "artifacts_engine")).strip_edges()
	var skip_memory_append: bool = bool(acquisition_context.get("skip_memory_append", false))
	var skip_world_feed: bool = bool(acquisition_context.get("skip_world_feed", false))
	var suppress_fame_signal: bool = bool(acquisition_context.get("suppress_fame_signal", false))
	var skip_player_narrative_log: bool = bool(acquisition_context.get("skip_player_narrative_log", false))
	var skip_event_emit: bool = bool(acquisition_context.get("skip_event_emit", false))
	var is_player_entry: bool = gs.player != null and int(npc.id) == int(gs.player.id)
	var suppress_birth_loadout_text: bool = acquisition_source == "birth_loadout"
	var msg:= ""

	match acquisition_source:
		"vormir_sacrifice":
			if is_player_entry:
				msg = "I obtained the Soul Stone on Vormir."
			else:
				msg = "%s %s obtained the Soul Stone on Vormir." % [
					npc.first_name,
					npc.last_name
				]
		"red_bonnet_wish":
			if is_player_entry:
				msg = "I wished for the %s Stone." % stone
			else:
				msg = "%s %s wished for the %s Stone." % [
					npc.first_name,
					npc.last_name,
					stone
				]
		"inheritance":
			if is_player_entry:
				msg = "I inherited the %s Stone." % stone
			else:
				msg = "%s %s inherited the %s Stone." % [
					npc.first_name,
					npc.last_name,
					stone
				]
		"birth_loadout":
			msg = ""
		_:
			if is_player_entry:
				msg = "I have discovered the %s Stone." % stone
			else:
				msg = "%s %s has discovered the %s Stone." % [
					npc.first_name,
					npc.last_name,
					stone
				]

	if msg != "" and not skip_world_feed:
		gs.push_world_feed(msg, {
			"npc_id": npc.id,
			"personally_relevant": is_player_entry,
			"category": "artifact",
			"event_name": ActionEventTypes.ARTIFACT_ACQUIRED,
			"source": event_source
		})

	if msg != "" and gs.event_bus != null and not skip_event_emit:
		gs.event_bus.emit(ActionEventTypes.ARTIFACT_ACQUIRED, {
			"npc_id": npc.id,
			"artifact": stone,
			"text": msg,
			"acquisition_source": acquisition_source,
			"source": event_source,
			"suppress_world_feed": skip_world_feed,
			"suppress_fame_signal": suppress_fame_signal
		})

	if msg != "" and is_player_entry and not skip_player_narrative_log:
		if gs.narrative_engine != null:
			gs.narrative_engine.log_event(npc, {
				"type": "text",
				"text": msg
			})
		else:
			npc.memories.append(msg)

	if skip_memory_append or suppress_birth_loadout_text:
		return

	match acquisition_source:
		"vormir_sacrifice":
			npc.memories.append(
				"I obtained the Soul Stone on Vormir — %s" % STONES [stone].lore
			)
		"red_bonnet_wish":
			npc.memories.append(
				"I wished the %s Stone into my hands through the Red Bonnet — %s" % [
					stone,
					STONES [stone].lore
				]
			)
		"inheritance":
			npc.memories.append(
				"I inherited the legendary %s Stone — %s" % [
					stone,
					STONES [stone].lore
				]
			)
		_:
			npc.memories.append(
				"I came across the legendary %s Stone — %s" % [
					stone,
					STONES [stone].lore
				]
			)
func grant_soul_stone_from_vormir(npc: Person, acquisition_context: Dictionary = {}) -> Dictionary:
	if npc == null:
		return { "success": false, "text": "No bearer was found."}
	if gs == null or not gs.is_feature_enabled("artifacts"):
		return { "success": false, "text": "Infinity Stones are not active in this reality."}
	if ownership.has(npc.id) and "Soul" in ownership.get(npc.id, []):
		return { "success": false, "text": "You already hold the Soul Stone."}
	if "Soul" in _globally_owned_stones():
		return { "success": false, "text": "The Soul Stone has already been claimed."}

	var context: Dictionary = acquisition_context.duplicate(true)
	context ["source"] = "vormir_sacrifice"
	context ["event_source"] = "vormir_engine"
	_give_stone(npc, "Soul", context)

	return {
		"success": true,
		"effect_text": _stone_acquisition_effect_text("Soul")
	}


func person_has_stone(npc: Person, stone: String) -> bool:
	if npc == null:
		return false

	var key: String = str(stone).strip_edges()
	if key == "":
		return false

	var resolved_key: String = ""
	for raw_stone_key in STONES.keys():
		var candidate: String = str(raw_stone_key).strip_edges()
		if candidate.to_lower() == key.to_lower():
			resolved_key = candidate
			break

	if resolved_key == "":
		return false

	if ownership.has(npc.id):
		var held: Array = ownership.get(npc.id, [])
		if resolved_key in held:
			return true

	if gs == null or gs.belongings_engine == null:
		return false

	return gs.belongings_engine.has_item_named(npc, "Artifacts", "%s Stone" % resolved_key)

func confiscate_stone_from_person(npc: Person, stone: String) -> bool:
	if npc == null:
		return false

	var key: String = str(stone).strip_edges()
	if key == "":
		return false

	var resolved_key: String = ""
	for raw_stone_key in STONES.keys():
		var candidate: String = str(raw_stone_key).strip_edges()
		if candidate.to_lower() == key.to_lower():
			resolved_key = candidate
			break

	if resolved_key == "":
		return false

	return _confiscate_stone(npc, resolved_key)




func _apply_buffs(npc, buffs: Dictionary):

	for k in buffs.keys():

		match k:
			"health":
				npc.health = clamp(npc.health + buffs [k], 0, 200)

			"smarts":
				npc.smarts = clamp(npc.smarts + buffs [k], 0, 150)

			"looks":
				npc.looks = clamp(npc.looks + buffs [k], 0, 150)

			"mental_health":
				npc.mental_health = clamp(npc.mental_health + buffs [k], 0, 150)

			"lifespan_bonus":

				if not "TimeBlessed" in npc.traits:
					npc.traits.append("TimeBlessed")

			"fate_control":
				if not "RealityBender" in npc.traits:
					npc.traits.append("RealityBender")

			"movement_chance":
				if not "Teleporter" in npc.traits:
					npc.traits.append("Teleporter")

			"relationships":
				npc.satisfaction += buffs [k]

			"charm":
				npc.looks += buffs [k]

func get_asset_signal_rollup_for_owner(owner: Person) -> Dictionary:
	var out: Dictionary = {}
	if gs == null or owner == null:
		return out

	var owned_items: Array = ownership.get(int(owner.id), [])
	if typeof(owned_items) != TYPE_ARRAY or owned_items.is_empty():
		return out

	var portfolio_tags: Dictionary = {}
	var event_hooks: Dictionary = {}
	var passive_modifiers: Dictionary = {}
	var prestige_signals: Dictionary = {}
	var status_signals: Dictionary = {}
	var pressure_profile: Dictionary = {}
	var asset_namespaces: Dictionary = {}
	var asset_class_filters: Dictionary = {}
	var asset_identity_modes: Dictionary = {}
	var asset_tier_profile: Dictionary = {}
	var asset_provenance_signals: Dictionary = {}
	var asset_condition_profile: Dictionary = {}

	var asset_count: int = 0
	var max_asset_tier_score: float = 0.0
	var asset_uniqueness_score: float = 0.0

	for raw_name in owned_items:
		var item_name:= str(raw_name)
		if item_name == "":
			continue

		asset_count += 1
		asset_uniqueness_score += 2.5

		var namespace_key:= "artifact.misc"
		var tier_score: float = 4.0

		match item_name:
			"Power Stone", "Mind Stone", "Reality Stone", "Soul Stone", "Time Stone", "Space Stone":
				namespace_key = "artifact.infinity_stone"
				tier_score = 5.0
				portfolio_tags ["portfolio_mood.cosmic_power"] = int(portfolio_tags.get("portfolio_mood.cosmic_power", 0)) + 1
				event_hooks ["cosmic_attention"] = int(event_hooks.get("cosmic_attention", 0)) + 1
				event_hooks ["artifact_hunters"] = int(event_hooks.get("artifact_hunters", 0)) + 1
				status_signals ["public_attention"] = float(status_signals.get("public_attention", 0.0)) + 2.0
				status_signals ["romance_signal"] = float(status_signals.get("romance_signal", 0.0)) + 1.0
				pressure_profile ["spectacle"] = float(pressure_profile.get("spectacle", 0.0)) + 2.0
				pressure_profile ["criminal_usefulness"] = float(pressure_profile.get("criminal_usefulness", 0.0)) + 2.0
				asset_identity_modes ["cosmic_bearer"] = int(asset_identity_modes.get("cosmic_bearer", 0)) + 1

		asset_namespaces [namespace_key] = int(asset_namespaces.get(namespace_key, 0)) + 1
		asset_class_filters ["artifact"] = int(asset_class_filters.get("artifact", 0)) + 1
		asset_tier_profile ["mythic"] = float(asset_tier_profile.get("mythic", 0.0)) + 1.0
		asset_provenance_signals ["discovered"] = float(asset_provenance_signals.get("discovered", 0.0)) + 1.0
		asset_condition_profile ["pristine"] = float(asset_condition_profile.get("pristine", 0.0)) + 1.0
		prestige_signals ["legendary_presence"] = float(prestige_signals.get("legendary_presence", 0.0)) + 3.0

		max_asset_tier_score = max(max_asset_tier_score, tier_score)

	if asset_count <= 0:
		return {}

	out ["asset_count"] = asset_count
	out ["dependency_pressure"] = 0.0
	out ["prestige_total"] = float(asset_count) * 3.0
	out ["modifier_weight"] = 0.0
	out ["portfolio_tags"] = portfolio_tags
	out ["event_hooks"] = event_hooks
	out ["passive_modifiers"] = passive_modifiers
	out ["prestige_signals"] = prestige_signals
	out ["status_signals"] = status_signals
	out ["pressure_profile"] = pressure_profile
	out ["asset_namespaces"] = asset_namespaces
	out ["asset_class_filters"] = asset_class_filters
	out ["asset_identity_modes"] = asset_identity_modes
	out ["asset_tier_profile"] = asset_tier_profile
	out ["asset_provenance_signals"] = asset_provenance_signals
	out ["asset_condition_profile"] = asset_condition_profile
	out ["max_asset_tier_score"] = max_asset_tier_score
	out ["asset_uniqueness_score"] = asset_uniqueness_score
	return out
func get_yearly_event_fragments_for_owner(owner: Person) -> Array:
	var out: Array = []
	if gs == null or owner == null:
		return out

	var rollup: Dictionary = get_asset_signal_rollup_for_owner(owner)
	if rollup.is_empty():
		return out

	var namespaces: Dictionary = rollup.get("asset_namespaces", {})
	if int(namespaces.get("artifact.infinity_stone", 0)) > 0:
		out.append({
			"text": "💎 Rumors kept building around %s’s connection to strange cosmic objects." % owner.first_name,
			"category": "assets",
			"weight": 5
		})

	return out
func get_artifact_target_actions(item: Dictionary) -> Array:
	var out: Array = []
	var specs: Array = get_artifact_action_specs(item)

	for spec_value in specs:
		if typeof(spec_value) != TYPE_DICTIONARY:
			continue
		var spec: Dictionary = spec_value
		if bool(spec.get("requires_target", false)):
			out.append(str(spec.get("label", "")))

	return out
func _artifact_relationship_target_reference(player: Person, target: Person) -> String:
	if player == null or target == null:
		return "them"

	var relation_label:= ""
	if gs != null and gs.has_method("get_relationship_label_between"):
		relation_label = str(gs.get_relationship_label_between(player, target)).strip_edges()

	if relation_label == "" or relation_label == "Stranger":
		var full_name:= ("%s %s" % [target.first_name, target.last_name]).strip_edges()
		if full_name != "":
			return full_name
		return str(target.first_name).strip_edges()

	return "my %s %s" % [relation_label.to_lower(), target.first_name]


func _artifact_relationship_target_possessive(player: Person, target: Person) -> String:
	var base:= _artifact_relationship_target_reference(player, target)
	if base == "" or base == "them":
		return "their"

	if base.ends_with("s"):
		return "%s'" % base
	return "%s's" % base


func _artifact_apply_target_pov_to_diary(player: Person, target: Person, text: String) -> String:
	if text == "" or player == null or target == null:
		return text
	var out:= text
	var full_name:= ("%s %s" % [target.first_name, target.last_name]).strip_edges()
	var first_name:= str(target.first_name).strip_edges()
	var relation_ref:= _artifact_relationship_target_reference(player, target)
	var relation_possessive:= _artifact_relationship_target_possessive(player, target)
	var replaced_full:= false

	if full_name != "":
		var possessive_full:= "%s's" % full_name
		if out.find(possessive_full) != -1:
			out = out.replace(possessive_full, relation_possessive)
			replaced_full = true
		if out.find(full_name) != -1:
			out = out.replace(full_name, relation_ref)
			replaced_full = true

	if not replaced_full and first_name != "":
		var possessive_first:= "%s's" % first_name
		if out.find(possessive_first) != -1:
			out = out.replace(possessive_first, relation_possessive)
		if out.find(first_name) != -1:
			out = out.replace(first_name, relation_ref)

	return out
func _artifact_popup_target_reference(player: Person, target: Person) -> String:
	if player == null or target == null:
		return "them"
	var relation_label:= ""
	if gs != null and gs.has_method("get_relationship_label_between"):
		relation_label = str(gs.get_relationship_label_between(player, target)).strip_edges()
	if relation_label == "" or relation_label == "Stranger":
		var full_name:= ("%s %s" % [target.first_name, target.last_name]).strip_edges()
		if full_name != "":
			return full_name
		return str(target.first_name).strip_edges()
	return "your %s %s" % [relation_label, target.first_name]


func _artifact_popup_target_possessive(player: Person, target: Person) -> String:
	var base:= _artifact_popup_target_reference(player, target)
	if base == "" or base == "them":
		return "their"
	if base.ends_with("s"):
		return "%s'" % base
	return "%s's" % base

func _artifact_popup_text_is_symbol_codepoint(codepoint: int) -> bool:
	return (
		(codepoint >= 126976 and codepoint <= 129791)
		or (codepoint >= 9728 and codepoint <= 10175)
		or codepoint == 8205
		or codepoint == 65039
	)

func _artifact_popup_text_line_is_symbols_only(text: String) -> bool:
	var line:= str(text).strip_edges()
	if line == "":
		return false
	for i in range(line.length()):
		var codepoint:= line.unicode_at(i)
		if codepoint == 32 or codepoint == 9:
			continue
		if not _artifact_popup_text_is_symbol_codepoint(codepoint):
			return false
	return true

func _artifact_normalize_popup_text_layout(text: String) -> String:
	var out:= str(text).strip_edges()
	if out == "":
		return ""
	var raw_lines:= out.split("\n", false)
	var cleaned: Array = []
	for raw_line in raw_lines:
		var line:= str(raw_line).strip_edges()
		if line == "":
			continue
		cleaned.append(line)
	if cleaned.is_empty():
		return ""
	if cleaned.size() >= 2 and _artifact_popup_text_line_is_symbols_only(str(cleaned [0])):
		cleaned [0] = "%s %s" % [str(cleaned [0]).strip_edges(), str(cleaned [1]).strip_edges()]
		cleaned.remove_at(1)
	var packed_lines:= PackedStringArray()
	for line in cleaned:
		packed_lines.append(str(line))
	return "\n".join(packed_lines).strip_edges()

func _artifact_split_popup_text_prefix(text: String) -> Dictionary:
	var normalized:= _artifact_normalize_popup_text_layout(text)
	if normalized == "":
		return { "prefix": "", "body": ""}
	var idx:= 0
	while idx < normalized.length():
		var codepoint:= normalized.unicode_at(idx)
		if codepoint == 32 or codepoint == 9:
			idx += 1
			continue
		if _artifact_popup_text_is_symbol_codepoint(codepoint):
			idx += 1
			continue
		break
	if idx <= 0:
		return { "prefix": "", "body": normalized}
	var prefix:= normalized.substr(0, idx).strip_edges()
	var body:= normalized.substr(idx).strip_edges()
	if prefix == "" or body == "":
		return { "prefix": "", "body": normalized}
	return { "prefix": "%s " % prefix, "body": body}

func _artifact_apply_target_pov_to_popup(player: Person, target: Person, text: String) -> String:
	if text == "" or player == null or target == null:
		return text
	var popup_parts:= _artifact_split_popup_text_prefix(text)
	var leading_prefix:= str(popup_parts.get("prefix", ""))
	var out:= str(popup_parts.get("body", str(text).strip_edges())).strip_edges()
	var full_name:= ("%s %s" % [target.first_name, target.last_name]).strip_edges()
	var first_name:= str(target.first_name).strip_edges()
	var relation_ref:= _artifact_popup_target_reference(player, target)
	var relation_possessive:= _artifact_popup_target_possessive(player, target)
	var replaced_full:= false
	if full_name != "":
		var possessive_full:= "%s's" % full_name
		if out.find(possessive_full) != -1:
			out = out.replace(possessive_full, relation_possessive)
			replaced_full = true
		if out.find(full_name) != -1:
			out = out.replace(full_name, relation_ref)
			replaced_full = true
	if not replaced_full and first_name != "":
		var possessive_first:= "%s's" % first_name
		if out.find(possessive_first) != -1:
			out = out.replace(possessive_first, relation_possessive)
		if out.find(first_name) != -1:
			out = out.replace(first_name, relation_ref)
	if out.begins_with("I have "):
		out = "You have " + out.substr(7)
	elif out.begins_with("I’ve "):
		out = "You’ve " + out.substr(5)
	elif out.begins_with("I've "):
		out = "You've " + out.substr(5)
	elif out.begins_with("I am "):
		out = "You are " + out.substr(5)
	elif out.begins_with("I'm "):
		out = "You're " + out.substr(4)
	elif out.begins_with("I "):
		out = "You " + out.substr(2)
	out = out.replace("\nI have ", "\nYou have ")
	out = out.replace("\nI’ve ", "\nYou’ve ")
	out = out.replace("\nI've ", "\nYou've ")
	out = out.replace("\nI am ", "\nYou are ")
	out = out.replace("\nI'm ", "\nYou're ")
	out = out.replace("\nI ", "\nYou ")
	out = out.replace(". I have ", ". You have ")
	out = out.replace(". I’ve ", ". You’ve ")
	out = out.replace(". I've ", ". You've ")
	out = out.replace(". I am ", ". You are ")
	out = out.replace(". I'm ", ". You're ")
	out = out.replace(". I ", ". You ")
	out = out.replace("! I have ", "! You have ")
	out = out.replace("! I’ve ", "! You’ve ")
	out = out.replace("! I've ", "! You've ")
	out = out.replace("! I am ", "! You are ")
	out = out.replace("! I'm ", "! You're ")
	out = out.replace("! I ", "! You ")
	out = out.replace("? I have ", "? You have ")
	out = out.replace("? I’ve ", "? You’ve ")
	out = out.replace("? I've ", "? You've ")
	out = out.replace("? I am ", "? You are ")
	out = out.replace("? I'm ", "? You're ")
	out = out.replace("? I ", "? You ")
	out = out.replace(" my ", " your ")
	out = out.replace(" My ", " Your ")
	out = out.replace(" me ", " you ")
	out = out.replace(" me.", " you.")
	out = out.replace(" me!", " you!")
	out = out.replace(" me?", " you?")
	return (leading_prefix + out).strip_edges()
func perform_artifact_action(item: Dictionary, action_name: String, target: Person) -> Dictionary:
	if gs == null or gs.player == null:
		return { "success": false, "text": "No active life loaded."}
	if target == null:
		return { "success": false, "text": "No target selected."}

	var player: Person = gs.player
	var item_name: String = str(item.get("name", "")).strip_edges()
	var target_name: String = "%s %s" % [target.first_name, target.last_name]
	var world_text:= ""
	var diary_text:= ""
	var popup_text:= ""
	var category:= "artifact"
	var mythic_rank:= "major"

	if gs.relationship_engine == null or not gs.relationship_engine.has_method("adjust_relationship"):
		return { "success": false, "text": "Relationship handling for artifact actions is not available right now."}

	match item_name:
		"Mind Stone":
			match action_name:
				"Read Mind":
					target.satisfaction = clamp(int(target.satisfaction) - 6, 0, 100)
					target.mental_health = clamp(int(target.mental_health) - 4, 0, 150)
					gs.relationship_engine.adjust_relationship(player, target, -3)
					world_text = "\n🧠\n %s used the Mind Stone to read %s's thoughts." % [player.first_name, target_name]
					diary_text = "\n🧠\n I used the Mind Stone to read %s's thoughts." % target_name

				"Soothe Mind":
					target.mental_health = clamp(int(target.mental_health) + 18, 0, 150)
					target.satisfaction = clamp(int(target.satisfaction) + 6, 0, 100)
					gs.relationship_engine.adjust_relationship(player, target, 5)
					world_text = "\n🧠\n %s soothed %s's mind with the Mind Stone." % [player.first_name, target_name]
					diary_text = "\n🧠\n I soothed %s's mind with the Mind Stone." % target_name

				"Awaken Genius":
					target.smarts = clamp(int(target.smarts) + 25, 0, 150)
					target.mental_health = clamp(int(target.mental_health) + 6, 0, 150)
					gs.relationship_engine.adjust_relationship(player, target, 7)
					if gs.fame_engine != null:
						target.fame = clamp(int(target.fame) + 5, 0, 100)
					world_text = "\n🧠\n %s awakened hidden genius within %s." % [player.first_name, target_name]
					diary_text = "\n🧠\n I awakened hidden genius within %s." % target_name
					mythic_rank = "legendary"

				"Instill Awe":
					target.satisfaction = clamp(int(target.satisfaction) - 2, 0, 100)
					gs.relationship_engine.adjust_relationship(player, target, 3)
					if gs.reputation_engine != null and gs.event_bus != null:
						gs.event_bus.emit(ActionEventTypes.FAME_SPIKE, {
							"npc_id": player.id,
							"text": "%s inspired awe through forbidden perception." % player.first_name,
							"source": "artifacts_engine"
						})
					world_text = "\n🧠\n %s filled %s with awe using the Mind Stone." % [player.first_name, target_name]
					diary_text = "\n🧠\n I filled %s with awe using the Mind Stone." % target_name
					mythic_rank = "legendary"

				"Erase Fear":
					target.mental_health = clamp(int(target.mental_health) + 20, 0, 150)
					gs.relationship_engine.adjust_relationship(player, target, 6)
					world_text = "\n🧠\n %s erased fear from %s's mind." % [player.first_name, target_name]
					diary_text = "\n🧠\n I erased fear from %s's mind." % target_name

				"Reveal Truth":
					target.mental_health = clamp(int(target.mental_health) - 8, 0, 150)
					if gs.memory_engine != null:
						gs.memory_engine.remember(target.id, "A cosmic truth was revealed to me by %s." % player.first_name)
					world_text = "\n🧠\n %s revealed a terrible truth to %s." % [player.first_name, target_name]
					diary_text = "\n🧠\n I revealed a terrible truth to %s." % target_name
					mythic_rank = "legendary"

				_:
					return { "success": false, "text": "That action is not available for the Mind Stone."}

		"Reality Stone":
			match action_name:
				"Warp Fate":
					target.satisfaction = clamp(int(target.satisfaction) - 8, 0, 100)
					gs.relationship_engine.adjust_relationship(player, target, -4)
					world_text = "\n🔺\n %s twisted reality against %s." % [player.first_name, target_name]
					diary_text = "\n🔺\n I twisted reality against %s." % target_name

				"Curse Health":
					target.health = clamp(int(target.health) - 25, 0, 200)
					target.mental_health = clamp(int(target.mental_health) - 8, 0, 150)
					gs.relationship_engine.adjust_relationship(player, target, -8)
					world_text = "\n🔺\n %s cursed %s's body with the Reality Stone." % [player.first_name, target_name]
					diary_text = "\n🔺\n I cursed %s's body with the Reality Stone." % target_name

				"Alter Trait":
					if not "RealityTouched" in target.traits:
						target.traits.append("RealityTouched")
					world_text = "\n🔺\n %s altered %s at the trait level." % [player.first_name, target_name]
					diary_text = "\n🔺\n I altered %s at the trait level." % target_name
					mythic_rank = "legendary"

				"Beautify Form":
					target.looks = 150
					gs.relationship_engine.adjust_relationship(player, target, 8)
					world_text = "\n🔺\n %s perfected %s's form through reality itself." % [player.first_name, target_name]
					diary_text = "\n🔺\n I perfected %s's form through reality itself." % target_name
					mythic_rank = "legendary"

				"Make Wealthy":
					target.bank_balance = float(target.bank_balance) + 25000000.0
					if gs.fame_engine != null:
						target.fame = clamp(int(target.fame) + 8, 0, 100)
					gs.relationship_engine.adjust_relationship(player, target, 10)
					world_text = "\n🔺\n %s reshaped reality so wealth flooded into %s's life." % [player.first_name, target_name]
					diary_text = "\n🔺\n I reshaped reality so wealth flooded into %s's life." % target_name
					mythic_rank = "legendary"

				"Rewrite Status":
					target.social_class = "Mythic"
					if gs.fame_engine != null:
						target.fame = clamp(int(target.fame) + 20, 0, 100)
					world_text = "\n🔺\n %s rewrote %s's place in reality." % [player.first_name, target_name]
					diary_text = "\n🔺\n I rewrote %s's place in reality." % target_name
					mythic_rank = "legendary"

				"Grant Gift":
					if gs.bending_engine != null:
						target.bending_type = "avatar" if player.bending_type == "avatar" else player.bending_type
					world_text = "\n🔺\n %s granted a supernatural gift to %s." % [player.first_name, target_name]
					diary_text = "\n🔺\n I granted a supernatural gift to %s." % target_name
					mythic_rank = "legendary"

				"Remove Gift":
					target.bending_type = "none"
					world_text = "\n🔺\n %s stripped supernatural favor from %s." % [player.first_name, target_name]
					diary_text = "\n🔺\n I stripped supernatural favor from %s." % target_name
					mythic_rank = "legendary"

				_:
					return { "success": false, "text": "That action is not available for the Reality Stone."}

		"Space Stone":
			match action_name:
				"Teleport To Me":
					target.home_city = player.home_city
					target.home_country = player.home_country
					target.satisfaction = clamp(int(target.satisfaction) + 3, 0, 100)
					gs.relationship_engine.adjust_relationship(player, target, 5)
					world_text = "\n🔵\n %s pulled %s across space with the Space Stone." % [player.first_name, target_name]
					diary_text = "\n🔵\n I pulled %s across space with the Space Stone." % target_name

				"Banish Away":
					target.health = clamp(int(target.health) - 10, 0, 200)
					target.satisfaction = clamp(int(target.satisfaction) - 8, 0, 100)
					gs.relationship_engine.adjust_relationship(player, target, -7)
					world_text = "\n🔵\n %s banished %s away with the Space Stone." % [player.first_name, target_name]
					diary_text = "\n🔵\n I banished %s away with the Space Stone." % target_name

				"Summon Before Me":
					target.home_city = player.home_city
					target.home_country = player.home_country
					if gs.realm_engine != null:
						var target_has_realm_name: bool = false
						var player_has_realm_name: bool = false
						var target_props:= target.get_property_list()
						var player_props:= player.get_property_list()

						for prop in target_props:
							if str(prop.get("name", "")) == "realm_name":
								target_has_realm_name = true
								break

						for prop in player_props:
							if str(prop.get("name", "")) == "realm_name":
								player_has_realm_name = true
								break

						if target_has_realm_name and player_has_realm_name:
							target.realm_name = player.realm_name
					gs.relationship_engine.adjust_relationship(player, target, 4)
					world_text = "\n🔵\n %s summoned %s before them through impossible distance." % [player.first_name, target_name]
					diary_text = "\n🔵\n I summoned %s before me through impossible distance." % target_name
					mythic_rank = "legendary"

				"Shift Realm":
					if gs.realm_engine != null:
						target.realm_name = "Shifted Realm"
					world_text = "\n🔵\n %s shifted %s into another realm." % [player.first_name, target_name]
					diary_text = "\n🔵\n I shifted %s into another realm." % target_name
					mythic_rank = "legendary"

				_:
					return { "success": false, "text": "That action is not available for the Space Stone."}

		"Time Stone":
			match action_name:
				"Restore Health":
					target.health = clamp(int(target.health) + 35, 0, 200)
					target.mental_health = clamp(int(target.mental_health) + 10, 0, 150)
					gs.relationship_engine.adjust_relationship(player, target, 6)
					world_text = "\n🟢\n %s rewound harm from %s with the Time Stone." % [player.first_name, target_name]
					diary_text = "\n🟢\n I rewound harm from %s with the Time Stone." % target_name

				"Drain Years":
					target.health = clamp(int(target.health) - 22, 0, 200)
					target.age = int(target.age) + 1
					gs.relationship_engine.adjust_relationship(player, target, -10)
					world_text = "\n🟢\n %s stole time from %s with the Time Stone." % [player.first_name, target_name]
					diary_text = "\n🟢\n I stole time from %s with the Time Stone." % target_name

				"Freeze Youth":
					if not "TimeFrozenYouth" in target.traits:
						target.traits.append("TimeFrozenYouth")
					target.looks = clamp(int(target.looks) + 10, 0, 150)
					world_text = "\n🟢\n %s froze %s's youth with the Time Stone." % [player.first_name, target_name]
					diary_text = "\n🟢\n I froze %s's youth with the Time Stone." % target_name
					mythic_rank = "legendary"

				"Age Target":
					target.age = int(target.age) + 3
					target.health = clamp(int(target.health) - 18, 0, 200)
					world_text = "\n🟢\n %s forced years upon %s in an instant." % [player.first_name, target_name]
					diary_text = "\n🟢\n I forced years upon %s in an instant." % target_name
					mythic_rank = "legendary"

				"Glimpse Destiny":
					if gs.memory_engine != null:
						gs.memory_engine.remember(target.id, "I glimpsed a possible destiny through time itself.")
					if gs.scenario_engine != null:
						gs.transient_scenario_biases [target.id] = {
							"source": "time_stone",
							"glimpse_year": gs.year,
							"favorability": 8
						}
					world_text = "\n🟢\n %s forced %s to glimpse a possible destiny." % [player.first_name, target_name]
					diary_text = "\n🟢\n I forced %s to glimpse a possible destiny." % target_name
					mythic_rank = "mythic"

				_:
					return { "success": false, "text": "That action is not available for the Time Stone."}

		"Soul Stone":
			match action_name:
				"Deepen Bond":
					target.satisfaction = clamp(int(target.satisfaction) + 8, 0, 100)
					target.mental_health = clamp(int(target.mental_health) + 4, 0, 150)
					gs.relationship_engine.adjust_relationship(player, target, 12)
					world_text = "\n🟠\n %s deepened a soul-bond with %s." % [player.first_name, target_name]
					diary_text = "\n🟠\n I deepened a soul-bond with %s." % target_name

				"Drain Spirit":
					target.mental_health = clamp(int(target.mental_health) - 25, 0, 150)
					target.health = clamp(int(target.health) - 10, 0, 200)
					gs.relationship_engine.adjust_relationship(player, target, -9)
					world_text = "\n🟠\n %s drained the spirit of %s with the Soul Stone." % [player.first_name, target_name]
					diary_text = "\n🟠\n I drained the spirit of %s with the Soul Stone." % target_name

				"Bless Bloodline":
					if gs.dynasty_legacy_engine != null:
						gs.dynasty_legacy_engine.add_reputation(target, 120)
					target.satisfaction = clamp(int(target.satisfaction) + 10, 0, 100)
					world_text = "\n🟠\n %s blessed the bloodline of %s through the Soul Stone." % [player.first_name, target_name]
					diary_text = "\n🟠\n I blessed the bloodline of %s through the Soul Stone." % target_name
					mythic_rank = "legendary"

				"Restore Spirit":
					target.mental_health = clamp(int(target.mental_health) + 40, 0, 150)
					target.satisfaction = clamp(int(target.satisfaction) + 10, 0, 100)
					world_text = "\n🟠\n %s restored the spirit of %s." % [player.first_name, target_name]
					diary_text = "\n🟠\n I restored the spirit of %s." % target_name

				"Bind Fate To Mine":
					gs.relationship_engine.adjust_relationship(player, target, 18)
					if gs.memory_engine != null:
						gs.memory_engine.remember(target.id, "My fate was mystically bound to %s." % player.first_name)
					world_text = "\n🟠\n %s bound the fate of %s to their own." % [player.first_name, target_name]
					diary_text = "\n🟠\n I bound the fate of %s to my own." % target_name
					mythic_rank = "mythic"

				"Sever Bond":
					gs.relationship_engine.adjust_relationship(player, target, -22)
					target.satisfaction = clamp(int(target.satisfaction) - 15, 0, 100)
					world_text = "\n🟠\n %s severed a sacred bond with %s." % [player.first_name, target_name]
					diary_text = "\n🟠\n I severed a sacred bond with %s." % target_name
					mythic_rank = "legendary"

				_:
					return { "success": false, "text": "That action is not available for the Soul Stone."}

		"Power Stone":
			match action_name:
				"Empower":
					target.health = clamp(int(target.health) + 18, 0, 200)
					target.looks = clamp(int(target.looks) + 4, 0, 150)
					target.satisfaction = clamp(int(target.satisfaction) + 2, 0, 100)
					gs.relationship_engine.adjust_relationship(player, target, 4)
					world_text = "\n🟣\n %s surged raw power into %s." % [player.first_name, target_name]
					diary_text = "\n🟣\n I surged raw power into %s." % target_name

				"Crush":
					target.health = clamp(int(target.health) - 40, 0, 200)
					target.satisfaction = clamp(int(target.satisfaction) - 10, 0, 100)
					gs.relationship_engine.adjust_relationship(player, target, -12)
					world_text = "\n🟣\n %s crushed %s with the Power Stone." % [player.first_name, target_name]
					diary_text = "\n🟣\n I crushed %s with the Power Stone." % target_name

				"Overcharge Body":
					target.health = clamp(int(target.health) + 35, 0, 200)
					target.mental_health = clamp(int(target.mental_health) - 8, 0, 150)
					world_text = "\n🟣\n %s overloaded %s with impossible power." % [player.first_name, target_name]
					diary_text = "\n🟣\n I overloaded %s with impossible power." % target_name
					mythic_rank = "legendary"

				"Force Submission":
					target.satisfaction = clamp(int(target.satisfaction) - 20, 0, 100)
					gs.relationship_engine.adjust_relationship(player, target, -20)
					world_text = "\n🟣\n %s forced %s into terrified submission." % [player.first_name, target_name]
					diary_text = "\n🟣\n I forced %s into terrified submission." % target_name
					mythic_rank = "legendary"

				"Make Legendary":
					target.fame = clamp(int(target.fame) + 30, 0, 100)
					world_text = "\n🟣\n %s made %s feel like a legend." % [player.first_name, target_name]
					diary_text = "\n🟣\n I made %s feel like a legend." % target_name
					mythic_rank = "legendary"

				_:
					return { "success": false, "text": "That action is not available for the Power Stone."}

		"Infinity Gauntlet":
			match action_name:
				"Bless":
					target.health = clamp(int(target.health) + 40, 0, 200)
					target.mental_health = clamp(int(target.mental_health) + 30, 0, 150)
					target.satisfaction = clamp(int(target.satisfaction) + 10, 0, 100)
					gs.relationship_engine.adjust_relationship(player, target, 15)
					world_text = "\n⚡\n %s blessed %s with the Infinity Gauntlet." % [player.first_name, target_name]
					diary_text = "\n⚡\n I blessed %s with the Infinity Gauntlet." % target_name

				"Ruin":
					target.health = clamp(int(target.health) - 55, 0, 200)
					target.mental_health = clamp(int(target.mental_health) - 30, 0, 150)
					target.satisfaction = clamp(int(target.satisfaction) - 12, 0, 100)
					gs.relationship_engine.adjust_relationship(player, target, -18)
					world_text = "\n⚡\n %s ruined %s with the Infinity Gauntlet." % [player.first_name, target_name]
					diary_text = "\n⚡\n I ruined %s with the Infinity Gauntlet." % target_name

				"Kill":
					if target == player:
						return { "success": false, "text": "The Infinity Gauntlet refuses to kill its current bearer."}
					target.alive = false
					target.health = 0
					target.cause_of_death = "Killed by the Infinity Gauntlet"
					world_text = "\n⚡\n %s killed %s with the Infinity Gauntlet." % [player.first_name, target_name]
					diary_text = "\n⚡\n I killed %s with the Infinity Gauntlet." % target_name
					mythic_rank = "mythic"
					if gs.event_bus != null:
						gs.event_bus.emit(ActionEventTypes.NPC_DIED, {
							"npc_id": target.id,
							"text": "%s %s died." % [target.first_name, target.last_name],
							"cause": target.cause_of_death,
							"source": "artifacts_engine",
							"npc_facts": gs.get_npc_facts_by_id(target.id)
						})

				"Remove From Existence":
					if target == player:
						return { "success": false, "text": "The Infinity Gauntlet refuses to erase its current bearer from existence."}
					if gs != null and gs.has_method("erase_person_from_existence"):
						var removed: bool = bool(gs.erase_person_from_existence(target, "Erased from existence by the Infinity Gauntlet"))
						if not removed:
							return { "success": false, "text": "Reality resisted the erasure."}
					world_text = "\n⚡\n %s removed %s from existence." % [player.first_name, target_name]
					diary_text = "\n⚡\n I removed %s from existence." % target_name
					mythic_rank = "mythic"

				"Snap Bond":
					target.satisfaction = clamp(int(target.satisfaction) - 20, 0, 100)
					gs.relationship_engine.adjust_relationship(player, target, -30)
					world_text = "\n⚡\n %s severed their bond with %s using the Infinity Gauntlet." % [player.first_name, target_name]
					diary_text = "\n⚡\n I severed my bond with %s using the Infinity Gauntlet." % target_name

				"Restore Body":
					target.health = 200
					target.mental_health = max(int(target.mental_health), 100)
					target.satisfaction = clamp(int(target.satisfaction) + 6, 0, 100)
					gs.relationship_engine.adjust_relationship(player, target, 10)
					world_text = "\n⚡\n %s restored %s completely with the Infinity Gauntlet." % [player.first_name, target_name]
					diary_text = "\n⚡\n I restored %s completely with the Infinity Gauntlet." % target_name

				"Choose Cosmic Successor":
					target.is_heir = true
					if gs.dynasty_engine != null:
						target.dynasty_rank = "Cosmic Successor"
					world_text = "\n⚡\n %s named %s as a cosmic successor." % [player.first_name, target_name]
					diary_text = "\n⚡\n I named %s as a cosmic successor." % target_name
					mythic_rank = "mythic"

				"Erase From Relevance":
					target.fame = 0
					target.social_class = "Forgotten"
					world_text = "\n⚡\n %s erased %s from relevance." % [player.first_name, target_name]
					diary_text = "\n⚡\n I erased %s from relevance." % target_name
					mythic_rank = "mythic"

				"Judgment of Worthiness":
					var worthy:= int(target.smarts) + int(target.mental_health) + int(target.satisfaction) >= 180
					if worthy:
						target.fame = clamp(int(target.fame) + 20, 0, 100)
						world_text = "\n⚡\n %s judged %s worthy before cosmic power." % [player.first_name, target_name]
						diary_text = "\n⚡\n I judged %s worthy before cosmic power." % target_name
					else:
						target.health = clamp(int(target.health) - 45, 0, 200)
						target.mental_health = clamp(int(target.mental_health) - 20, 0, 150)
						world_text = "\n⚡\n %s judged %s unworthy and reality rejected them." % [player.first_name, target_name]
						diary_text = "\n⚡\n I judged %s unworthy and reality rejected them." % target_name
					mythic_rank = "mythic"

				"Crown As Heir":
					target.is_heir = true
					if gs.dynasty_legacy_engine != null:
						gs.dynasty_legacy_engine.add_reputation(target, 200)
					world_text = "\n⚡\n %s crowned %s as heir through the Infinity Gauntlet." % [player.first_name, target_name]
					diary_text = "\n⚡\n I crowned %s as heir through the Infinity Gauntlet." % target_name
					mythic_rank = "mythic"

				_:
					return { "success": false, "text": "That artifact cannot be used like this."}
	var flavored_texts: Dictionary = _artifact_build_stone_action_texts(player, target, item_name, action_name)
	if not flavored_texts.is_empty():
		world_text = str(flavored_texts.get("world_text", world_text))
		diary_text = str(flavored_texts.get("diary_text", diary_text))

	if item_name == "Mind Stone" and gs.consciousness_engine != null:
		gs.consciousness_engine.apply_consciousness_modifier(target, {
			"id": "mind_stone",
			"source": "artifact_action",
			"action_name": action_name,
			"intensity": 1.0
		})
		gs.consciousness_engine.remember(target, world_text, {
			"source": "mind_stone",
			"memory_type": "psychic_intrusion",
			"perspective": "third_person",
			"emotion_tags": ["mind_stone", "cosmic_pressure"]
		})

	popup_text = _artifact_apply_target_pov_to_popup(player, target, diary_text)
	_emit_mythic_echo(player, item_name, action_name, target, world_text, diary_text, mythic_rank, category)
	player.memories.append(diary_text)
	if target.memories != null:
		target.memories.append(world_text)
	var enforcer_result: Dictionary = _register_negative_stone_use(player, item, action_name, target)
	if not enforcer_result.is_empty():
		if popup_text != "":
			enforcer_result ["popup_text"] = popup_text
		return enforcer_result
	return {
		"success": true,
		"text": diary_text,
		"popup_text": popup_text
	}
func _register_negative_stone_use(player: Person, item: Dictionary, action_name: String, target: Person) -> Dictionary:
	if gs == null or player == null or target == null:
		return {}

	var item_name: String = str(item.get("name", "")).strip_edges()
	if item_name == "" or item_name == "Infinity Gauntlet":
		return {}

	var karma_delta: int = _cosmic_karma_delta_for_action(item_name, action_name)
	if karma_delta <= 0:
		return {}

	var player_id: int = int(player.id)
	var new_total: int = int(cosmic_karma.get(player_id, 0)) + karma_delta
	cosmic_karma [player_id] = new_total

	if pending_galactic_enforcer.has(player_id):
		return {}

	if new_total < GALACTIC_ENFORCER_THRESHOLD:
		return {}

	var stone_key: String = str(item.get("stone_key", "")).strip_edges()
	if stone_key == "":
		stone_key = _normalize_artifact_item_name(item_name).replace(" Stone", "")

	var encounter:= {
		"enemy_name": "Galactic Enforcers",
		"enemy_hp": GALACTIC_ENFORCER_HP,
		"triggering_stone": stone_key,
		"triggering_action": action_name,
		"target_id": int(target.id),
		"spawn_year": int(gs.year)
	}

	pending_galactic_enforcer [player_id] = encounter

	var spawn_text:= "Galactic Enforcers descended to punish %s %s for abusing the %s Stone." % [
		player.first_name,
		player.last_name,
		stone_key
	]

	gs.push_world_feed(spawn_text, {
		"npc_id": player.id,
		"personally_relevant": true,
		"category": "cosmic",
		"event_name": ActionEventTypes.COSMIC_ENFORCER_SPAWNED,
		"source": "artifacts_engine"
	})

	if gs.event_bus != null:
		gs.event_bus.emit(ActionEventTypes.COSMIC_ENFORCER_SPAWNED, {
			"npc_id": player.id,
			"text": spawn_text,
			"stone": stone_key,
			"action_name": action_name,
			"source": "artifacts_engine"
		})

	if gs.scenario_engine == null:
		return {
			"success": true,
			"text": "Galactic Enforcers have appeared.",
			"popup_title": "Galactic Enforcers",
			"popup_text": "Your hidden cosmic karma overflowed. Galactic Enforcers have come for the %s Stone." % stone_key,
			"popup_footer": "Tap anywhere to continue."
		}

	return gs.scenario_engine.queue_external_scenario(_build_galactic_enforcer_scenario(player, encounter))


func _cosmic_karma_delta_for_action(item_name: String, action_name: String) -> int:
	match item_name:
		"Mind Stone":
			match action_name:
				"Read Mind":
					return 12
				"Reveal Truth":
					return 14
		"Reality Stone":
			match action_name:
				"Warp Fate":
					return 16
				"Curse Health":
					return 22
				"Alter Trait":
					return 18
				"Remove Gift":
					return 18
		"Space Stone":
			match action_name:
				"Banish Away":
					return 15
				"Shift Realm":
					return 18
		"Time Stone":
			match action_name:
				"Drain Years":
					return 18
				"Age Target":
					return 20
		"Soul Stone":
			match action_name:
				"Drain Spirit":
					return 20
				"Bind Fate To Mine":
					return 18
		"Power Stone":
			match action_name:
				"Crush":
					return 24
				"Overcharge Body":
					return 18
				"Force Submission":
					return 22

	return 0


func _build_galactic_enforcer_scenario(player: Person, encounter: Dictionary) -> Dictionary:
	var stone_key: String = str(encounter.get("triggering_stone", "Unknown")).strip_edges()

	var prompt_text:= "My hidden cosmic karma has overflowed. Galactic Enforcers with 700HP just descended after my abuse of the %s Stone. How do I fight back?" % stone_key
	var stand_label:= "Stand my ground and trade blows."
	var stand_journal:= "I stood my ground as the Galactic Enforcers closed in."
	var channel_label:= "Channel the Stone defensively."
	var channel_journal:= "I tried to channel the Stone defensively against the Galactic Enforcers."
	var flee_label:= "Try to flee through broken space."
	var flee_journal:= "I tried to flee from the Galactic Enforcers before they could surround me."
	var beg_label:= "Beg for mercy and yield."
	var beg_journal:= "I yielded and begged the Galactic Enforcers for mercy."

	match stone_key:
		"Mind", "Mind Stone":
			prompt_text = "My hidden cosmic karma has overflowed. The air went dead silent as Galactic Enforcers with 700HP forced their way into my thoughts after my abuse of the Mind Stone. How do I resist them?"
			stand_label = "Lock eyes and push back mentally."
			stand_journal = "I locked in and tried to overpower the Galactic Enforcers mind-to-mind."
			channel_label = "Fortify my mind with the Stone."
			channel_journal = "I tried to fortify my mind with the Mind Stone against the Galactic Enforcers."
			flee_label = "Break their focus and disappear."
			flee_journal = "I tried to break the Enforcers' focus and slip away before they could pin down my mind."
			beg_label = "Lower my thoughts and submit."
			beg_journal = "I lowered my thoughts and submitted to the judgment of the Galactic Enforcers."

		"Reality", "Reality Stone":
			prompt_text = "My hidden cosmic karma has overflowed. Reality is peeling apart around me as Galactic Enforcers with 700HP step through the fractures I carved with the Reality Stone. How do I fight back?"
			stand_label = "Plant my feet inside the fracture."
			stand_journal = "I planted my feet inside the fracture and faced the Galactic Enforcers head-on."
			channel_label = "Stabilize reality around myself."
			channel_journal = "I tried to stabilize the collapsing reality around me with the Reality Stone."
			flee_label = "Slip through a false path."
			flee_journal = "I tried to slip through a false path in the broken reality before the Enforcers sealed it."
			beg_label = "Yield before reality snaps shut."
			beg_journal = "I yielded before the broken reality snapped shut around me."

		"Space", "Space Stone":
			prompt_text = "My hidden cosmic karma has overflowed. The sky split into mirrored corridors as Galactic Enforcers with 700HP triangulated my position through the Space Stone. How do I survive the breach?"
			stand_label = "Rush the breach before they surround me."
			stand_journal = "I rushed the breach and tried to hit the Galactic Enforcers before they could surround me."
			channel_label = "Fold space around my body."
			channel_journal = "I tried to fold space around my body with the Space Stone and blunt the Enforcers' assault."
			flee_label = "Blink out through a collapsing corridor."
			flee_journal = "I tried to blink out through a collapsing corridor before the Galactic Enforcers locked me in."
			beg_label = "Offer my coordinates and yield."
			beg_journal = "I gave up my position and yielded to the Galactic Enforcers."

		"Time", "Time Stone":
			prompt_text = "My hidden cosmic karma has overflowed. Seconds are stuttering around me as Galactic Enforcers with 700HP follow the temporal scars I left with the Time Stone. How do I answer them?"
			stand_label = "Strike before the moment settles."
			stand_journal = "I lunged before the moment could settle and tried to catch the Galactic Enforcers off balance."
			channel_label = "Wrap myself in stolen seconds."
			channel_journal = "I tried to wrap myself in stolen seconds with the Time Stone against the Galactic Enforcers."
			flee_label = "Run through a fractured second."
			flee_journal = "I tried to run through a fractured second before the Galactic Enforcers could anchor the timeline."
			beg_label = "Accept the timeline's judgment."
			beg_journal = "I stopped resisting and accepted the judgment waiting for me in the timeline."

		"Soul", "Soul Stone":
			prompt_text = "My hidden cosmic karma has overflowed. The room turned colder than death as Galactic Enforcers with 700HP came to weigh my spirit for what I did with the Soul Stone. How do I face judgment?"
			stand_label = "Defend my soul with everything I am."
			stand_journal = "I braced my spirit and tried to defend my soul against the Galactic Enforcers."
			channel_label = "Shield my essence with the Stone."
			channel_journal = "I tried to shield my essence with the Soul Stone against the Galactic Enforcers."
			flee_label = "Retreat behind an empty shell."
			flee_journal = "I tried to retreat behind an empty shell before the Galactic Enforcers could seize my spirit."
			beg_label = "Confess and ask for mercy."
			beg_journal = "I confessed my abuse of the Soul Stone and asked the Galactic Enforcers for mercy."

		"Power", "Power Stone":
			prompt_text = "My hidden cosmic karma has overflowed. The ground is already cracking under the pressure as Galactic Enforcers with 700HP descend to answer my violent abuse of the Power Stone. How do I stand against them?"
			stand_label = "Meet force with force."
			stand_journal = "I chose to meet the Galactic Enforcers with pure force."
			channel_label = "Overload myself with raw power."
			channel_journal = "I tried to overload myself with the Power Stone and survive the Galactic Enforcers' assault."
			flee_label = "Dive through the shockwave."
			flee_journal = "I tried to dive through the shockwave and escape before the Galactic Enforcers crushed me."
			beg_label = "Drop to my knees and yield."
			beg_journal = "I dropped to my knees and yielded before the Galactic Enforcers."

	return {
		"id": "galactic_enforcers_%s_%s" % [str(player.id), str(gs.year)],
		"source": "artifacts_engine",
		"resolver_method": "resolve_galactic_enforcer_encounter",
		"category": "artifact",
		"era_tags": ["any"],
		"reality_modes": ["enhanced", "chaos"],
		"tone": "cosmic",
		"rarity": 1.0,
		"priority": 999,
		"min_age": 0,
		"max_age": 130,
		"prompt": prompt_text,
		"choices": [
			{
				"id": "stand_and_fight",
				"label": stand_label,
				"journal_text": stand_journal
			},
			{
				"id": "defensive_channel",
				"label": channel_label,
				"journal_text": channel_journal
			},
			{
				"id": "flee",
				"label": flee_label,
				"journal_text": flee_journal
			},
			{
				"id": "beg",
				"label": beg_label,
				"journal_text": beg_journal
			}
		]
	}


func resolve_galactic_enforcer_encounter(actor: Person, _scenario: Dictionary, choice: Dictionary, _committed: Dictionary) -> Dictionary:
	if gs == null or actor == null:
		return {}
	var actor_id: int = int(actor.id)
	var pending: Dictionary = pending_galactic_enforcer.get(actor_id, {})
	if pending.is_empty():
		return {
			"type": "scenario_commit_complete",
			"text": "The Galactic Enforcers were already gone.",
			"popup_title": "Galactic Enforcers",
			"popup_text": "The confrontation has already passed.",
			"popup_footer": "Tap anywhere to continue."
		}
	pending_galactic_enforcer.erase(actor_id)
	cosmic_karma [actor_id] = 0
	var stone_key: String = str(pending.get("triggering_stone", "Unknown")).strip_edges()
	var tactic: String = str(choice.get("label", "fight back")).strip_edges()
	var win: bool = randf() < GALACTIC_ENFORCER_WIN_CHANCE
	var victory_popup_text:= "Against impossible odds, you won.\n\nYou chose to %s\n\nYou kept the %s Stone%s"
	var death_popup_text:= "You lost.\n\nThe Galactic Enforcers overpowered you, confiscated the %s Stone, and executed you."
	var survive_loss_popup_text:= "You lost.\n\nThe Galactic Enforcers overwhelmed you%s"
	var use_default_popup_formatting: bool = true
	match stone_key:
		"Mind", "Mind Stone":
			use_default_popup_formatting = false
			victory_popup_text = "Against impossible odds, your mind held.\n\nYou chose to %s\n\nThe psychic pressure broke around you. You kept the Mind Stone%s"
			death_popup_text = "You lost.\n\nThe Galactic Enforcers invaded every corner of your mind, confiscated the Mind Stone, and erased you where you stood."
			survive_loss_popup_text = "You lost.\n\nThe Galactic Enforcers crushed your thoughts and left your mind ringing%s"
		"Reality", "Reality Stone":
			use_default_popup_formatting = false
			victory_popup_text = "Against impossible odds, you forced the fracture to obey you.\n\nYou chose to %s\n\nReality bent around your will. You kept the Reality Stone%s"
			death_popup_text = "You lost.\n\nThe Galactic Enforcers sealed the fractures you opened, confiscated the Reality Stone, and snapped your existence shut."
			survive_loss_popup_text = "You lost.\n\nThe Galactic Enforcers forced reality back into place around you%s"
		"Space", "Space Stone":
			use_default_popup_formatting = false
			victory_popup_text = "Against impossible odds, you won the breach.\n\nYou chose to %s\n\nThe corridors of space folded in your favor. You kept the Space Stone%s"
			death_popup_text = "You lost.\n\nThe Galactic Enforcers collapsed every exit, confiscated the Space Stone, and left you nowhere to run."
			survive_loss_popup_text = "You lost.\n\nThe Galactic Enforcers boxed you in from every angle of space%s"
		"Time", "Time Stone":
			use_default_popup_formatting = false
			victory_popup_text = "Against impossible odds, you mastered the broken moment.\n\nYou chose to %s\n\nTime itself gave way. You kept the Time Stone%s"
			death_popup_text = "You lost.\n\nThe Galactic Enforcers anchored the timeline, confiscated the Time Stone, and ended your future on the spot."
			survive_loss_popup_text = "You lost.\n\nThe Galactic Enforcers pinned you to a dying second%s"
		"Soul", "Soul Stone":
			use_default_popup_formatting = false
			victory_popup_text = "Against impossible odds, your spirit endured.\n\nYou chose to %s\n\nYour soul was not taken. You kept the Soul Stone%s"
			death_popup_text = "You lost.\n\nThe Galactic Enforcers judged your spirit unworthy, confiscated the Soul Stone, and tore your life away."
			survive_loss_popup_text = "You lost.\n\nThe Galactic Enforcers weighed your spirit and marked it%s"
		"Power", "Power Stone":
			use_default_popup_formatting = false
			victory_popup_text = "Against impossible odds, your force broke theirs.\n\nYou chose to %s\n\nThe shockwave belonged to you. You kept the Power Stone%s"
			death_popup_text = "You lost.\n\nThe Galactic Enforcers shattered your resistance, confiscated the Power Stone, and crushed you without mercy."
			survive_loss_popup_text = "You lost.\n\nThe Galactic Enforcers overwhelmed you with raw force%s"
	if win:
		var reward_name: String = _grant_galactic_enforcer_reward(actor)
		var world_text:= "%s %s defeated the Galactic Enforcers and kept the %s Stone." % [
			actor.first_name,
			actor.last_name,
			stone_key
		]
		if reward_name != "":
			world_text += " They also claimed %s from the fallen enforcers." % reward_name
		gs.push_world_feed(world_text, {
			"npc_id": actor.id,
			"personally_relevant": true,
			"category": "cosmic",
			"event_name": ActionEventTypes.COSMIC_ENFORCER_SPAWNED,
			"source": "artifacts_engine"
		})
		var reward_suffix:= "" if reward_name == "" else "\n\nThe Enforcers also dropped: %s" % reward_name
		var resolved_victory_popup_text:= ""
		if use_default_popup_formatting:
			resolved_victory_popup_text = victory_popup_text % [tactic, stone_key, reward_suffix]
		else:
			resolved_victory_popup_text = victory_popup_text % [tactic, reward_suffix]
		return {
			"type": "scenario_commit_complete",
			"text": "I defeated the Galactic Enforcers and kept the %s Stone." % stone_key,
			"popup_title": "Victory",
			"popup_text": resolved_victory_popup_text,
			"popup_footer": "Tap anywhere to continue."
		}
	var confiscated: bool = _confiscate_stone(actor, stone_key)
	var kill_on_loss: bool = randf() < GALACTIC_ENFORCER_KILL_ON_LOSS_CHANCE
	var followup_result: Dictionary = {}
	if kill_on_loss and gs.health_engine != null and gs.health_engine.has_method("handle_death"):
		gs.health_engine.handle_death(actor, "Executed by Galactic Enforcers")
		if actor == gs.player and gs.life_engine != null and gs.life_engine.has_method("_handle_player_death"):
			followup_result = gs.life_engine.call("_handle_player_death")
		var resolved_death_popup_text:= death_popup_text % stone_key if use_default_popup_formatting else death_popup_text
		return {
			"type": "scenario_commit_complete",
			"text": "I lost to the Galactic Enforcers. They took the %s Stone and ended my life." % stone_key,
			"popup_title": "Defeat",
			"popup_text": resolved_death_popup_text,
			"popup_footer": "Tap anywhere to continue.",
			"followup_result": followup_result
		}
	var loss_world_text:= "%s %s lost to the Galactic Enforcers." % [
		actor.first_name,
		actor.last_name
	]
	if confiscated:
		loss_world_text += " They confiscated the %s Stone." % stone_key
	else:
		loss_world_text += " They left reality scarred behind them."
	gs.push_world_feed(loss_world_text, {
		"npc_id": actor.id,
		"personally_relevant": true,
		"category": "cosmic",
		"event_name": ActionEventTypes.COSMIC_ENFORCER_SPAWNED,
		"source": "artifacts_engine"
	})
	return {
		"type": "scenario_commit_complete",
		"text": "I lost to the Galactic Enforcers." + (" They took my %s Stone." % stone_key if confiscated else ""),
		"popup_title": "Defeat",
		"popup_text": survive_loss_popup_text % (
			" and confiscated your %s Stone." % stone_key if confiscated else "."
		),
		"popup_footer": "Tap anywhere to continue."
	}


func _confiscate_stone(npc: Person, stone_key: String) -> bool:
	if npc == null or stone_key.strip_edges() == "":
		return false

	var removed_any:= false

	if ownership.has(npc.id):
		var held: Array = ownership.get(npc.id, [])
		var idx:= held.find(stone_key)
		if idx != -1:
			held.remove_at(idx)
			removed_any = true
		if held.is_empty():
			ownership.erase(npc.id)
		else:
			ownership [npc.id] = held

	if gs == null or gs.belongings_engine == null:
		return removed_any

	var target_item_name:= "%s Stone" % stone_key
	var items: Array = gs.belongings_engine.get_category_items(npc, "Artifacts")
	for raw_item in items:
		if typeof(raw_item) != TYPE_DICTIONARY:
			continue
		if str(raw_item.get("name", "")) != target_item_name:
			continue

		var item_id: int = int(raw_item.get("id", -1))
		if item_id != -1:
			gs.belongings_engine.remove_item_by_id(npc, "Artifacts", item_id)
			removed_any = true
		break

	return removed_any


func _grant_galactic_enforcer_reward(npc: Person) -> String:
	if npc == null:
		return ""

	var candidates: Array = []
	for shop_id in SHOP_ORDER:
		var entry: Dictionary = SHOP_ITEMS.get(shop_id, {})
		if entry.is_empty():
			continue
		if str(entry.get("grant_type", "")) != "basic_artifact":
			continue

		var item_name: String = str(entry.get("name", "")).strip_edges()
		if item_name == "":
			continue
		if _basic_shop_artifact_owned(npc, item_name):
			continue

		candidates.append(entry)

	if candidates.is_empty():
		return ""

	candidates.shuffle()
	var chosen: Dictionary = candidates [0]
	_grant_shop_basic_artifact(npc, chosen)
	return str(chosen.get("name", "a rare artifact"))

func _emit_mythic_echo(player: Person, item_name: String, action_name: String, target: Person, world_text: String, diary_text: String, mythic_rank: String, category: String = "artifact") -> void:
	if gs == null or player == null:
		return

	var normalized_world_text:= world_text.strip_edges()
	var normalized_diary_text:= diary_text.strip_edges()

	var payload:= {
		"npc_id": player.id,
		"target_id": target.id if target != null else -1,
		"item_name": item_name,
		"action_name": action_name,
		"mythic_rank": mythic_rank,
		"text": normalized_diary_text,
		"third_person_text": normalized_world_text,
		"category": category,
		"source": "artifacts_engine",
		"suppress_world_feed": true
	}

	if normalized_world_text != "":
		gs.push_world_feed(normalized_world_text, {
			"npc_id": player.id,
			"personally_relevant": true,
			"category": category,
			"event_name": ActionEventTypes.ARTIFACT_ACQUIRED,
			"source": "artifacts_engine",
			"item_name": item_name,
			"action_name": action_name,
			"mythic_rank": mythic_rank,
			"suppress_diary": player == gs.player
		})

	if gs.event_bus != null:
		gs.event_bus.emit(ActionEventTypes.ARTIFACT_ACQUIRED, payload)

	if mythic_rank == "mythic":
		if gs.dynamic_world_event_engine != null and gs.event_bus != null:
			gs.event_bus.emit(ActionEventTypes.COSMIC_ENFORCER_SPAWNED, {
				"npc_id": player.id,
				"text": "Reality noticed the mythic use of %s." % item_name,
				"source": "artifacts_engine"
			})

	if gs.scenario_engine != null:
		gs.transient_scenario_biases [player.id] = {
			"source": "artifacts_engine",
			"item_name": item_name,
			"action_name": action_name,
			"mythic_rank": mythic_rank,
			"year": gs.year
		}
func yearly_discovery_chance():
	if gs == null or not gs.is_feature_enabled("artifacts"):
		return
	if _globally_available_stones().is_empty():
		return
	if randi() % 20000 == 0:
		_spawn_stone_randomly()





func handle_inheritance(payload):
	if gs == null or not gs.is_feature_enabled("artifacts"):
		return
	var dead_npc_id = int(payload.get("npc_id", -1))
	if gs.should_skip_manual_player_inheritance(dead_npc_id):
		return
	if dead_npc_id == -1:
		return
	if not ownership.has(dead_npc_id):
		return
	var stones = ownership [dead_npc_id]
	var dead_facts = gs.get_npc_facts_by_id(dead_npc_id)
	if dead_facts == {}:
		return
	var heir = gs.get_random_living_person_from_ids(dead_facts.get("children", []))
	if heir == null:
		return
	for stone in stones:
		_give_stone(heir, stone)
	ownership.erase(dead_npc_id)





func player_has_all() -> bool:
	var pid = gs.player.id
	if not ownership.has(pid):
		return false

	return ownership [pid].size() == 6





func forge_gauntlet():
	if not player_has_all():
		return false

	var p = gs.player
	if p == null:
		return false

	if not "GauntletBearer" in p.traits:
		p.traits.append("GauntletBearer")
	if not "CosmicAuthority" in p.traits:
		p.traits.append("CosmicAuthority")

	if gs.belongings_engine != null and not gs.belongings_engine.has_item_named(p, "Artifacts", "Infinity Gauntlet"):
		var gauntlet_item_id: int = gs.next_id
		gs.next_id += 1
		gs.belongings_engine.add_item(p, {
			"id": gauntlet_item_id,
			"name": "Infinity Gauntlet",
			"type": "Artifact",
			"lore": "A cosmic vessel forged to bind all 6 Infinity Stones into a single will.",
			"ability": "Channels all 6 Infinity Stones at once, unlocks divine authority actions, and bends history, bloodlines, and reality itself.",
			"color": "gold",
			"origin_era": gs.era.name,
			"acquired_year": gs.year,
			"mythic_rank": "mythic",
			"item_family": "gauntlet"
		}, "Artifacts")

	p.health = 500
	p.smarts += 30
	p.looks += 20
	p.mental_health += 40

	gs.push_world_feed(
		"\n⚡\n %s %s forged the Infinity Gauntlet. Reality itself now answers their will." % [p.first_name, p.last_name],
		{
			"npc_id": p.id,
			"personally_relevant": true,
			"category": "artifact",
			"event_name": ActionEventTypes.GAUNTLET_FORGED,
			"source": "artifacts_engine"
		}
	)

	if gs.event_bus != null:
		gs.event_bus.emit(ActionEventTypes.GAUNTLET_FORGED, {
			"npc_id": p.id,
			"type": "text",
			"text": "I forged the Infinity Gauntlet. Reality itself now answers my will.",
			"third_person_text": "%s %s forged the Infinity Gauntlet. Reality itself now answers their will." % [p.first_name, p.last_name],
			"suppress_world_feed": true,
			"source": "artifacts_engine"
		})

		gs.event_bus.emit(ActionEventTypes.FAME_SPIKE, {
			"npc_id": p.id,
			"text": "%s became a living cosmic authority." % p.first_name,
			"source": "artifacts_engine",
			"mythic_rank": "mythic"
		})

	if gs.memory_engine != null:
		gs.memory_engine.remember(p.id, "I forged the Infinity Gauntlet and became a living cosmic authority.")

	if gs.scenario_engine != null:
		gs.transient_scenario_biases [p.id] = {
			"source": "artifacts_engine",
			"item_name": "Infinity Gauntlet",
			"action_name": "forge",
			"mythic_rank": "mythic",
			"year": gs.year
		}

	return true





func cosmic_consequence():
	if not "GauntletBearer" in gs.player.traits:
		return

	if randi() % 500 != 0:
		return

	var enforcer = gs.npc_factory.create_random_npc()
	enforcer.first_name = "Cosmic"
	enforcer.last_name = "Enforcer"
	enforcer.health = 999
	enforcer.smarts = 150
	enforcer.looks = 150
	enforcer.traits.append("Immortal")
	gs.npcs.append(enforcer)
	gs.push_world_feed(
		"🌌 A COSMIC ENFORCER has appeared to challenge your abuse of the Gauntlet.",
		{
			"npc_id": enforcer.id,
			"personally_relevant": true,
			"category": "cosmic",
			"event_name": ActionEventTypes.COSMIC_ENFORCER_SPAWNED,
			"source": "artifacts_engine"
		}
	)
func give_random_unique_stones(npc: Person, count: int, acquisition_context: Dictionary = {}) -> Array:
	var awarded: Array = []
	if npc == null:
		return awarded
	var available: Array = _globally_available_stones()
	available.shuffle()
	count = clamp(count, 0, available.size())
	if count <= 0:
		return awarded
	for i in range(count):
		var stone_name: String = str(available [i])
		_give_stone(npc, stone_name, acquisition_context)
		awarded.append(stone_name)
	return awarded
func nominate_scenarios_for_player(context:= {}) -> Array:
	var out: Array = []
	var player: Person = context.get("player", null)
	if player == null or not player.alive:
		return out
	if gs == null or not gs.is_feature_enabled("artifacts"):
		return out

	out.append({
		"id": "artifact_curiosity_%d" % int(context.get("year", 0)),
		"category": "artifact",
		"era_tags": ["any"],
		"reality_modes": ["enhanced", "chaos"],
		"reality_weights": {
			"enhanced": 1.0,
			"chaos": 1.2
		},
		"tone": "mysterious",
		"rarity": 0.8,
		"cooldown_key": "artifact:curiosity",
		"cooldown_years": 4,
		"priority": 9,
		"min_age": 12,
		"max_age": 130,
		"prompt": "Something about the world feels cosmically off this year. Do I ignore it or lean toward it?",
		"followup_hooks": ["artifact.curiosity"],
		"bias_payloads": {},
		"choices": [
			{
				"id": "pursue",
				"label": "Lean toward the strange pull.",
				"journal_line": "I chose to lean toward the strange pull around me.",
				"followup_hooks": ["artifact.curiosity.pursue"],
				"bias_payloads": {
					"artifact_context": {
						"curiosity": 20.0
					},
					"reputation_bias": {
						"public_attention": 1.0
					},
					"expiry": {
						"years": 1
					}
				}
			},
			{
				"id": "ignore",
				"label": "Ignore it and stay grounded.",
				"journal_line": "I chose to stay grounded instead of chasing the strange feeling.",
				"followup_hooks": ["artifact.curiosity.ignore"],
				"bias_payloads": {
					"health_bias": {
						"stress_delta": -1.0
					},
					"artifact_context": {
						"curiosity": -8.0
					},
					"expiry": {
						"years": 1
					}
				}
			}
		]
	})

	out.append_array(_nominate_infinity_stone_ecology(context))
	return out

func _nominate_infinity_stone_ecology(context:= {}) -> Array:
	var out: Array = []
	var year: int = int(context.get("year", 0))

	out.append({
		"id": "artifact_stone_visibility_%d" % year,
		"source": "artifacts_engine",
		"category": "artifact",
		"era_tags": ["any"],
		"reality_modes": ["enhanced", "chaos"],
		"reality_weights": {
			"enhanced": 1.0,
			"chaos": 1.16
		},
		"tone": "ominous",
		"rarity": 0.74,
		"cooldown_key": "artifact.stone.visibility",
		"cooldown_years": 2,
		"priority": 14,
		"min_age": 12,
		"max_age": 130,
		"asset_namespace_preferences": { "artifact.infinity_stone": 2.8},
		"required_asset_event_hooks": ["artifact_hunters"],
		"asset_identity_mode": ["cosmic_bearer"],
		"asset_weight_status_signals": { "public_attention": 2.0},
		"asset_weight_pressure_profile": { "criminal_usefulness": 2.0, "spectacle": 1.5},
		"asset_tier_floor": 4.0,
		"asset_uniqueness_bias": 2.5,
		"asset_arc_family": "infinity_stone_visibility",
		"asset_arc_step": "heat_rising",
		"asset_repeat_group": "artifact.infinity_stone.visibility",
		"asset_echoes_world_feed": true,
		"asset_echoes_memory": true,
		"asset_echoes_reputation": true,
		"prompt": "Owning power like this is getting harder to hide. Do I conceal it better, weaponize the fear, or build a private doctrine around it?",
		"followup_hooks": ["artifact.infinity_stone.visibility.heat_rising"],
		"bias_payloads": {},
		"choices": [
			{
				"id": "conceal_better",
				"label": "Conceal it better and shrink the trail.",
				"journal_line": "I concealed the truth around the stone more carefully before its gravity could widen the circle.",
				"followup_hooks": ["artifact.infinity_stone.visibility.conceal"],
				"bias_payloads": {
					"crime_pressure": { "rumor_heat": -1.0},
					"relationship_bias": { "social_visibility": -1.0},
					"expiry": { "years": 1}
				}
			},
			{
				"id": "weaponize_the_fear",
				"label": "Weaponize the fear around it.",
				"journal_line": "I let people fear what I held instead of wasting time pretending it meant nothing.",
				"followup_hooks": ["artifact.infinity_stone.visibility.weaponize"],
				"bias_payloads": {
					"reputation_bias": { "public_attention": 4.0},
					"crime_pressure": { "rumor_heat": 2.0},
					"expiry": { "years": 1}
				}
			},
			{
				"id": "build_private_doctrine",
				"label": "Build a private philosophy around it.",
				"journal_line": "I started building a private doctrine around the object instead of letting raw power make all my decisions.",
				"followup_hooks": ["artifact.infinity_stone.visibility.doctrine"],
				"bias_payloads": {
					"artifact_context": { "curiosity": 10.0},
					"career_bias": { "ambition_weight": 2.0},
					"expiry": { "years": 1}
				}
			}
		]
	})

	out.append({
		"id": "artifact_stone_successor_pressure_%d" % year,
		"source": "artifacts_engine",
		"category": "artifact",
		"era_tags": ["any"],
		"reality_modes": ["enhanced", "chaos"],
		"reality_weights": {
			"enhanced": 1.0,
			"chaos": 1.12
		},
		"tone": "sacred",
		"rarity": 0.67,
		"cooldown_key": "artifact.stone.successor_pressure",
		"cooldown_years": 3,
		"priority": 13,
		"min_age": 16,
		"max_age": 130,
		"asset_namespace_preferences": { "artifact.infinity_stone": 2.6},
		"asset_identity_mode": ["cosmic_bearer"],
		"asset_weight_status_signals": { "public_attention": 1.5},
		"asset_weight_pressure_profile": { "spectacle": 1.5},
		"asset_tier_floor": 4.0,
		"asset_uniqueness_bias": 2.2,
		"asset_arc_family": "infinity_stone_lineage",
		"asset_arc_step": "successor_pressure",
		"asset_repeat_group": "artifact.infinity_stone.lineage",
		"asset_echoes_world_feed": true,
		"asset_echoes_memory": true,
		"asset_echoes_reputation": true,
		"prompt": "The question of who should be near this power is getting heavier. Do I name a trusted circle, keep everyone unworthy, or test people one by one?",
		"followup_hooks": ["artifact.infinity_stone.lineage.successor_pressure"],
		"bias_payloads": {},
		"choices": [
			{
				"id": "name_a_circle",
				"label": "Name a trusted circle.",
				"journal_line": "I named a trusted circle before power could turn every relationship into a guessing game.",
				"followup_hooks": ["artifact.infinity_stone.lineage.circle"],
				"bias_payloads": {
					"relationship_bias": { "social_visibility": 3.0},
					"expiry": { "years": 1}
				}
			},
			{
				"id": "declare_everyone_unworthy",
				"label": "Keep everyone at a distance.",
				"journal_line": "I kept everyone at a distance and refused to let desire dress itself up as worthiness.",
				"followup_hooks": ["artifact.infinity_stone.lineage.distance"],
				"bias_payloads": {
					"health_bias": { "stress_delta": 1.0},
					"relationship_bias": { "social_visibility": -2.0},
					"expiry": { "years": 1}
				}
			},
			{
				"id": "test_them_one_by_one",
				"label": "Test people one by one.",
				"journal_line": "I tested people one by one before letting anybody stand close to the thing reshaping my life.",
				"followup_hooks": ["artifact.infinity_stone.lineage.tests"],
				"bias_payloads": {
					"career_bias": { "ambition_weight": 1.5},
					"reputation_bias": { "public_attention": 2.0},
					"expiry": { "years": 1}
				}
			}
		]
	})

	return out
func get_artifact_action_specs(item: Dictionary) -> Array:
	var item_name: String = str(item.get("name", "")).strip_edges()
	var out: Array = []

	match item_name:
		"Mind Stone":
			out = [
				{
					"id": "mind_read_mind",
					"label": "Read Mind",
					"item_family": "stone",
					"category": "target",
					"tone": "ominous",
					"mythic_rank": "major",
					"requires_target": true,
					"cooldown_key": "artifact:mind:read_mind",
					"resolver_method": "perform_artifact_action"
				},
				{
					"id": "mind_awaken_genius",
					"label": "Awaken Genius",
					"item_family": "stone",
					"category": "target",
					"tone": "radiant",
					"mythic_rank": "legendary",
					"requires_target": true,
					"cooldown_key": "artifact:mind:awaken_genius",
					"resolver_method": "perform_artifact_action"
				},
				{
					"id": "mind_instill_awe",
					"label": "Instill Awe",
					"item_family": "stone",
					"category": "target",
					"tone": "radiant",
					"mythic_rank": "legendary",
					"requires_target": true,
					"cooldown_key": "artifact:mind:instill_awe",
					"resolver_method": "perform_artifact_action"
				},
				{
					"id": "mind_erase_fear",
					"label": "Erase Fear",
					"item_family": "stone",
					"category": "target",
					"tone": "merciful",
					"mythic_rank": "major",
					"requires_target": true,
					"cooldown_key": "artifact:mind:erase_fear",
					"resolver_method": "perform_artifact_action"
				},
				{
					"id": "mind_reveal_truth",
					"label": "Reveal Truth",
					"item_family": "stone",
					"category": "target",
					"tone": "ominous",
					"mythic_rank": "legendary",
					"requires_target": true,
					"cooldown_key": "artifact:mind:reveal_truth",
					"resolver_method": "perform_artifact_action"
				}
			]

		"Reality Stone":
			out = [
				{
					"id": "reality_alter_trait",
					"label": "Alter Trait",
					"item_family": "stone",
					"category": "target",
					"tone": "warping",
					"mythic_rank": "legendary",
					"requires_target": true,
					"cooldown_key": "artifact:reality:alter_trait",
					"resolver_method": "perform_artifact_action"
				},
				{
					"id": "reality_beautify_form",
					"label": "Beautify Form",
					"item_family": "stone",
					"category": "target",
					"tone": "radiant",
					"mythic_rank": "major",
					"requires_target": true,
					"cooldown_key": "artifact:reality:beautify_form",
					"resolver_method": "perform_artifact_action"
				},
				{
					"id": "reality_make_wealthy",
					"label": "Make Wealthy",
					"item_family": "stone",
					"category": "target",
					"tone": "radiant",
					"mythic_rank": "legendary",
					"requires_target": true,
					"cooldown_key": "artifact:reality:make_wealthy",
					"resolver_method": "perform_artifact_action"
				},
				{
					"id": "reality_rewrite_status",
					"label": "Rewrite Status",
					"item_family": "stone",
					"category": "target",
					"tone": "warping",
					"mythic_rank": "legendary",
					"requires_target": true,
					"cooldown_key": "artifact:reality:rewrite_status",
					"resolver_method": "perform_artifact_action"
				},
				{
					"id": "reality_grant_gift",
					"label": "Grant Gift",
					"item_family": "stone",
					"category": "target",
					"tone": "radiant",
					"mythic_rank": "legendary",
					"requires_target": true,
					"cooldown_key": "artifact:reality:grant_gift",
					"resolver_method": "perform_artifact_action"
				},
				{
					"id": "reality_remove_gift",
					"label": "Remove Gift",
					"item_family": "stone",
					"category": "target",
					"tone": "ominous",
					"mythic_rank": "legendary",
					"requires_target": true,
					"cooldown_key": "artifact:reality:remove_gift",
					"resolver_method": "perform_artifact_action"
				}
			]

		"Space Stone":
			out = [
				{
					"id": "space_teleport_to_me",
					"label": "Teleport To Me",
					"item_family": "stone",
					"category": "target",
					"tone": "cosmic",
					"mythic_rank": "major",
					"requires_target": true,
					"cooldown_key": "artifact:space:teleport_to_me",
					"resolver_method": "perform_artifact_action"
				},
				{
					"id": "space_banish_away",
					"label": "Banish Away",
					"item_family": "stone",
					"category": "target",
					"tone": "ominous",
					"mythic_rank": "major",
					"requires_target": true,
					"cooldown_key": "artifact:space:banish_away",
					"resolver_method": "perform_artifact_action"
				},
				{
					"id": "space_summon_before_me",
					"label": "Summon Before Me",
					"item_family": "stone",
					"category": "target",
					"tone": "cosmic",
					"mythic_rank": "legendary",
					"requires_target": true,
					"cooldown_key": "artifact:space:summon_before_me",
					"resolver_method": "perform_artifact_action"
				},
				{
					"id": "space_shift_realm",
					"label": "Shift Realm",
					"item_family": "stone",
					"category": "target",
					"tone": "cosmic",
					"mythic_rank": "legendary",
					"requires_target": true,
					"cooldown_key": "artifact:space:shift_realm",
					"resolver_method": "perform_artifact_action"
				}
			]

		"Time Stone":
			out = [
				{
					"id": "time_restore_health",
					"label": "Restore Health",
					"item_family": "stone",
					"category": "target",
					"tone": "merciful",
					"mythic_rank": "major",
					"requires_target": true,
					"cooldown_key": "artifact:time:restore_health",
					"resolver_method": "perform_artifact_action"
				},
				{
					"id": "time_drain_years",
					"label": "Drain Years",
					"item_family": "stone",
					"category": "target",
					"tone": "ominous",
					"mythic_rank": "major",
					"requires_target": true,
					"cooldown_key": "artifact:time:drain_years",
					"resolver_method": "perform_artifact_action"
				},
				{
					"id": "time_freeze_youth",
					"label": "Freeze Youth",
					"item_family": "stone",
					"category": "target",
					"tone": "radiant",
					"mythic_rank": "legendary",
					"requires_target": true,
					"cooldown_key": "artifact:time:freeze_youth",
					"resolver_method": "perform_artifact_action"
				},
				{
					"id": "time_age_target",
					"label": "Age Target",
					"item_family": "stone",
					"category": "target",
					"tone": "ominous",
					"mythic_rank": "legendary",
					"requires_target": true,
					"cooldown_key": "artifact:time:age_target",
					"resolver_method": "perform_artifact_action"
				},
				{
					"id": "time_glimpse_destiny",
					"label": "Glimpse Destiny",
					"item_family": "stone",
					"category": "target",
					"tone": "cosmic",
					"mythic_rank": "mythic",
					"requires_target": true,
					"cooldown_key": "artifact:time:glimpse_destiny",
					"resolver_method": "perform_artifact_action"
				},
				{
					"id": "time_loop_bargain",
					"label": "Create a time loop and tell them you've come to bargain",
					"item_family": "stone",
					"category": "duel",
					"tone": "cosmic",
					"mythic_rank": "mythic",
					"requires_target": true,
					"cooldown_key": "artifact:time:loop_bargain",
					"resolver_method": "scenario_engine_time_loop_duel",
					"duel_scopes": [
						"bending",
						"bending_sparring",
						"bending_tournament",
						"reality_fusion_ally"
					]
				}
			]

		"Soul Stone":
			out = [
				{
					"id": "soul_deepen_bond",
					"label": "Deepen Bond",
					"item_family": "stone",
					"category": "target",
					"tone": "sacred",
					"mythic_rank": "major",
					"requires_target": true,
					"cooldown_key": "artifact:soul:deepen_bond",
					"resolver_method": "perform_artifact_action"
				},
				{
					"id": "soul_drain_spirit",
					"label": "Drain Spirit",
					"item_family": "stone",
					"category": "target",
					"tone": "ominous",
					"mythic_rank": "major",
					"requires_target": true,
					"cooldown_key": "artifact:soul:drain_spirit",
					"resolver_method": "perform_artifact_action"
				},
				{
					"id": "soul_bless_bloodline",
					"label": "Bless Bloodline",
					"item_family": "stone",
					"category": "target",
					"tone": "sacred",
					"mythic_rank": "legendary",
					"requires_target": true,
					"cooldown_key": "artifact:soul:bless_bloodline",
					"resolver_method": "perform_artifact_action"
				},
				{
					"id": "soul_restore_spirit",
					"label": "Restore Spirit",
					"item_family": "stone",
					"category": "target",
					"tone": "merciful",
					"mythic_rank": "major",
					"requires_target": true,
					"cooldown_key": "artifact:soul:restore_spirit",
					"resolver_method": "perform_artifact_action"
				},
				{
					"id": "soul_bind_fate_to_mine",
					"label": "Bind Fate To Mine",
					"item_family": "stone",
					"category": "target",
					"tone": "sacred",
					"mythic_rank": "mythic",
					"requires_target": true,
					"cooldown_key": "artifact:soul:bind_fate_to_mine",
					"resolver_method": "perform_artifact_action"
				},
				{
					"id": "soul_sever_bond",
					"label": "Sever Bond",
					"item_family": "stone",
					"category": "target",
					"tone": "ominous",
					"mythic_rank": "legendary",
					"requires_target": true,
					"cooldown_key": "artifact:soul:sever_bond",
					"resolver_method": "perform_artifact_action"
				}
			]

		"Power Stone":
			out = [
				{
					"id": "power_empower",
					"label": "Empower",
					"item_family": "stone",
					"category": "target",
					"tone": "violent",
					"mythic_rank": "major",
					"requires_target": true,
					"cooldown_key": "artifact:power:empower",
					"resolver_method": "perform_artifact_action"
				},
				{
					"id": "power_crush",
					"label": "Crush",
					"item_family": "stone",
					"category": "target",
					"tone": "violent",
					"mythic_rank": "major",
					"requires_target": true,
					"cooldown_key": "artifact:power:crush",
					"resolver_method": "perform_artifact_action"
				},
				{
					"id": "power_overcharge_body",
					"label": "Overcharge Body",
					"item_family": "stone",
					"category": "target",
					"tone": "violent",
					"mythic_rank": "legendary",
					"requires_target": true,
					"cooldown_key": "artifact:power:overcharge_body",
					"resolver_method": "perform_artifact_action"
				},
				{
					"id": "power_force_submission",
					"label": "Force Submission",
					"item_family": "stone",
					"category": "target",
					"tone": "ominous",
					"mythic_rank": "legendary",
					"requires_target": true,
					"cooldown_key": "artifact:power:force_submission",
					"resolver_method": "perform_artifact_action"
				},
				{
					"id": "power_make_legendary",
					"label": "Make Legendary",
					"item_family": "stone",
					"category": "target",
					"tone": "radiant",
					"mythic_rank": "legendary",
					"requires_target": true,
					"cooldown_key": "artifact:power:make_legendary",
					"resolver_method": "perform_artifact_action"
				}
			]

		"Infinity Gauntlet":
			out = [
				{
					"id": "gauntlet_bless",
					"label": "Bless",
					"item_family": "gauntlet",
					"category": "target",
					"tone": "radiant",
					"mythic_rank": "legendary",
					"requires_target": true,
					"cooldown_key": "artifact:gauntlet:bless",
					"resolver_method": "perform_artifact_action"
				},
				{
					"id": "gauntlet_ruin",
					"label": "Ruin",
					"item_family": "gauntlet",
					"category": "target",
					"tone": "ominous",
					"mythic_rank": "legendary",
					"requires_target": true,
					"cooldown_key": "artifact:gauntlet:ruin",
					"resolver_method": "perform_artifact_action"
				},
				{
					"id": "gauntlet_kill",
					"label": "Kill",
					"item_family": "gauntlet",
					"category": "target",
					"tone": "ominous",
					"mythic_rank": "mythic",
					"requires_target": true,
					"cooldown_key": "artifact:gauntlet:kill",
					"resolver_method": "perform_artifact_action"
				},
				{
					"id": "gauntlet_remove_from_existence",
					"label": "Remove From Existence",
					"item_family": "gauntlet",
					"category": "target",
					"tone": "cosmic",
					"mythic_rank": "mythic",
					"requires_target": true,
					"cooldown_key": "artifact:gauntlet:remove_from_existence",
					"resolver_method": "perform_artifact_action"
				},
				{
					"id": "gauntlet_choose_cosmic_successor",
					"label": "Choose Cosmic Successor",
					"item_family": "gauntlet",
					"category": "target",
					"tone": "sacred",
					"mythic_rank": "mythic",
					"requires_target": true,
					"cooldown_key": "artifact:gauntlet:choose_cosmic_successor",
					"resolver_method": "perform_artifact_action"
				},
				{
					"id": "gauntlet_erase_from_relevance",
					"label": "Erase From Relevance",
					"item_family": "gauntlet",
					"category": "target",
					"tone": "ominous",
					"mythic_rank": "mythic",
					"requires_target": true,
					"cooldown_key": "artifact:gauntlet:erase_from_relevance",
					"resolver_method": "perform_artifact_action"
				},
				{
					"id": "gauntlet_judgment_of_worthiness",
					"label": "Judgment of Worthiness",
					"item_family": "gauntlet",
					"category": "target",
					"tone": "cosmic",
					"mythic_rank": "mythic",
					"requires_target": true,
					"cooldown_key": "artifact:gauntlet:judgment_of_worthiness",
					"resolver_method": "perform_artifact_action"
				},
				{
					"id": "gauntlet_crown_as_heir",
					"label": "Crown As Heir",
					"item_family": "gauntlet",
					"category": "target",
					"tone": "sacred",
					"mythic_rank": "mythic",
					"requires_target": true,
					"cooldown_key": "artifact:gauntlet:crown_as_heir",
					"resolver_method": "perform_artifact_action"
				}
			]

		_:
			out = []

	return out
func _resolved_shop_cost(entry: Dictionary) -> int:
	var grant_type: String = str(entry.get("grant_type", ""))

	match grant_type:
		"dragon_ball":
			var star: int = int(entry.get("star", 0))
			var dragon_ball_prices: Dictionary = {
				1: 1000000000,
				2: 2500000000,
				3: 5000000000,
				4: 10000000000,
				5: 15000000000,
				6: 25000000000,
				7: 40000000000
			}
			if dragon_ball_prices.has(star):
				return int(dragon_ball_prices [star])

		"infinity_stone":
			var stone: String = str(entry.get("stone", "")).strip_edges()
			var stone_prices: Dictionary = {
				"Power": 18000000000,
				"Mind": 22000000000,
				"Reality": 35000000000,
				"Space": 26000000000,
				"Time": 32000000000,
				"Soul": 30000000000
			}
			if stone_prices.has(stone):
				return int(stone_prices [stone])

	return int(entry.get("cost", 0))


func _artifact_appreciation_rate_for_entry(entry: Dictionary) -> float:
	var grant_type: String = str(entry.get("grant_type", "")).strip_edges()

	match grant_type:
		"dragon_ball":
			return 0.09
		"infinity_stone":
			return 0.075
		"basic_artifact":
			var rarity: String = str(entry.get("rarity", "")).strip_edges().to_lower()
			match rarity:
				"legendary":
					return 0.05
				"epic":
					return 0.04
				"rare":
					return 0.03
				_:
					return 0.025

	return 0.0


func _build_artifact_market_fields(entry: Dictionary) -> Dictionary:
	var base_value: int = _resolved_shop_cost(entry)
	var annual_appreciation_rate: float = _artifact_appreciation_rate_for_entry(entry)

	return {
		"value": base_value,
		"base_value": base_value,
		"annual_appreciation_rate": annual_appreciation_rate
	}


func get_item_market_profile(
	item: Dictionary
) -> Dictionary:
	if item.is_empty():
		return {}

	var entry: Dictionary = {}
	var artifact_kind: String = str(
		item.get(
			"artifact_kind",
			""
		)
	).strip_edges()

	if artifact_kind == "stone":
		var stone: String = str(
			item.get(
				"stone_key",
				""
			)
		).strip_edges()

		if stone == "":
			return {}

		if not STONES.has(
			stone
		):
			return {}

		entry = {
			"grant_type": "infinity_stone",
			"stone": stone,
			"lore": str(
				STONES [
					stone
				].get(
					"lore",
					""
				)
			)
		}
	elif artifact_kind == "exchange_artifact":
		var definition_id: String = str(
			item.get(
				"exchange_artifact_definition_id",
				item.get(
					"shop_item_id",
					""
				)
			)
		).strip_edges().to_lower()

		entry = _exchange_artifact_definition(
			definition_id
		)

		if entry.is_empty():
			return {}
	else:
		var shop_item_id: String = str(
			item.get(
				"shop_item_id",
				""
			)
		).strip_edges()

		if (
			shop_item_id == ""
			or not SHOP_ITEMS.has(
				shop_item_id
			)
		):
			return {}

		entry = _get_shop_entry(
			shop_item_id
		)

	var base_value: int = int(
		item.get(
			"base_value",
			_resolved_shop_cost(
				entry
			)
		)
	)
	var annual_appreciation_rate: float = float(
		item.get(
			"annual_appreciation_rate",
			entry.get(
				"annual_appreciation_rate",
				_artifact_appreciation_rate_for_entry(
					entry
				)
			)
		)
	)
	var acquired_year: int = int(
		item.get(
			"acquired_year",
			0
		)
	)
	var years_held: int = 0

	if (
		gs != null
		and item.has(
			"acquired_year"
		)
	):
		years_held = maxi(
			0,
			int(
				gs.year
			) - acquired_year
		)

	var valuation_origin_mode: String = str(
		item.get(
			"valuation_origin_mode",
			entry.get(
				"valuation_origin_mode",
				"fixed_year"
			)
		)
	).strip_edges().to_lower()
	var appreciation_years: int = years_held
	var valuation_origin_year: int = acquired_year

	if artifact_kind == "exchange_artifact":
		valuation_origin_year = (
			_exchange_artifact_valuation_origin_year(
				entry,
				int(
					gs.year
				)
				if gs != null
				else acquired_year
			)
		)

		if gs != null:
			appreciation_years = maxi(
				0,
				int(
					gs.year
				) - valuation_origin_year
			)
	elif item.has(
		"valuation_origin_year"
	):
		valuation_origin_year = int(
			item.get(
				"valuation_origin_year",
				acquired_year
			)
		)

		if gs != null:
			appreciation_years = maxi(
				0,
				int(
					gs.year
				) - valuation_origin_year
			)

	var current_value: int = base_value

	if (
		annual_appreciation_rate > 0.0
		and appreciation_years > 0
	):
		current_value = int(
			round(
				float(
					base_value
				)
				* pow(
					1.0 + annual_appreciation_rate,
					appreciation_years
				)
			)
		)

	return {
		"base_value": base_value,
		"current_value": current_value,
		"annual_appreciation_rate": annual_appreciation_rate,
		"years_held": years_held,
		"valuation_origin_mode": valuation_origin_mode,
		"valuation_origin_year": valuation_origin_year,
		"appreciation_years": appreciation_years,
		"lore": str(
			item.get(
				"lore",
				entry.get(
					"lore",
					""
				)
			)
		).strip_edges()
	}
func purchase_exchange_artifact(
	actor: Person,
	definition_id: String,
	canonical_instance_id: String
) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"committed": false,
			"reason": "missing_actor"
		}

	if (
		gs == null
		or gs.belongings_engine == null
	):
		return {
			"success": false,
			"committed": false,
			"reason": "belongings_engine_unavailable"
		}

	if typeof(
		gs.scenario_state
	) != TYPE_DICTIONARY:
		return {
			"success": false,
			"committed": false,
			"reason": "artifact_persistence_state_unavailable"
		}

	var definition: Dictionary = (
		_exchange_artifact_definition(
			definition_id
		)
	)

	if definition.is_empty():
		return {
			"success": false,
			"committed": false,
			"reason": "unknown_exchange_artifact"
		}

	if int(
		definition.get(
			"extraordinary_family_lives",
			0
		)
	) > 0:
		return {
			"success": false,
			"committed": false,
			"reason": "extraordinary_terms_required"
		}

	if not _exchange_artifact_exists_in_year(
		definition,
		int(gs.year)
	):
		return {
			"success": false,
			"committed": false,
			"reason": "artifact_not_yet_in_historical_record"
		}

	if (
		_exchange_artifact_instance_owner_id(
			canonical_instance_id
		)
		> 0
	):
		return {
			"success": false,
			"committed": false,
			"reason": "artifact_already_claimed"
		}

	if not _exchange_artifact_listing_is_live(
		definition_id,
		canonical_instance_id,
		actor
	):
		return {
			"success": false,
			"committed": false,
			"reason": "artifact_not_currently_circulating"
		}

	var price: int = (
		_exchange_artifact_current_value(
			definition,
			int(gs.year)
		)
	)

	if float(
		actor.bank_balance
	) < float(
		price
	):
		return {
			"success": false,
			"committed": false,
			"reason": "insufficient_funds",
			"text": (
				"You do not currently have enough money for this artifact."
			)
		}

	return _commit_exchange_artifact_transfer(
		actor,
		definition_id,
		definition,
		canonical_instance_id,
		price,
		{}
	)


func request_extraordinary_exchange_artifact_acquisition(
	actor: Person,
	definition_id: String,
	canonical_instance_id: String
) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"committed": false,
			"reason": "missing_actor"
		}

	if gs == null:
		return {
			"success": false,
			"committed": false,
			"reason": "missing_game_state"
		}

	var definition: Dictionary = (
		_exchange_artifact_definition(
			definition_id
		)
	)

	if definition.is_empty():
		return {
			"success": false,
			"committed": false,
			"reason": "unknown_exchange_artifact"
		}

	var required_lives: int = int(
		definition.get(
			"extraordinary_family_lives",
			0
		)
	)

	if required_lives <= 0:
		return {
			"success": false,
			"committed": false,
			"reason": "extraordinary_terms_not_required"
		}

	if not _exchange_artifact_exists_in_year(
		definition,
		int(gs.year)
	):
		return {
			"success": false,
			"committed": false,
			"reason": "artifact_not_yet_in_historical_record"
		}

	if (
		_exchange_artifact_instance_owner_id(
			canonical_instance_id
		)
		> 0
	):
		return {
			"success": false,
			"committed": false,
			"reason": "artifact_already_claimed"
		}

	if not _exchange_artifact_listing_is_live(
		definition_id,
		canonical_instance_id,
		actor
	):
		return {
			"success": false,
			"committed": false,
			"reason": "artifact_not_currently_circulating"
		}

	var price: int = (
		_exchange_artifact_current_value(
			definition,
			int(gs.year)
		)
	)

	if float(
		actor.bank_balance
	) < float(
		price
	):
		return {
			"success": false,
			"committed": false,
			"reason": "insufficient_funds",
			"text": (
				"You do not currently have enough money for this acquisition."
			)
		}

	var lineage_candidates: Array = (
		_living_family_lineage_candidates(
			actor
		)
	)

	if lineage_candidates.size() < required_lives:
		return {
			"success": false,
			"committed": false,
			"reason": "insufficient_living_family_lineage",
			"text": (
				"Artifact Authority could not establish sufficient "
				+ "living lineage consideration."
			)
		}

	_clear_extraordinary_terms_for_actor(
		int(actor.id)
	)

	extraordinary_acquisition_sequence += 1

	var terms_id: String = (
		"artifact_terms:%d:%s:%d:%d"
		% [
			int(actor.id),
			definition_id,
			int(gs.year),
			extraordinary_acquisition_sequence
		]
	)

	extraordinary_acquisition_terms [
		terms_id
	] = {
		"schema": EXCHANGE_ARTIFACT_TERMS_SCHEMA,
		"version": 1,
		"terms_id": terms_id,
		"actor_id": int(actor.id),
		"definition_id": definition_id,
		"canonical_instance_id": canonical_instance_id,
		"quoted_year": int(gs.year),
		"quoted_price": price,
		"family_lineage_lives": required_lives,
		"issued_sequence": extraordinary_acquisition_sequence
	}

	return {
		"success": true,
		"committed": false,
		"mode": "extraordinary_artifact_terms_issued",
		"schema": EXCHANGE_ARTIFACT_TERMS_SCHEMA,
		"terms_id": terms_id,
		"artifact_id": definition_id,
		"artifact_name": str(
			definition.get(
				"name",
				"Artifact"
			)
		),
		"canonical_instance_id": canonical_instance_id,
		"price": price,
		"family_lineage_lives": required_lives,
		"leave_label": str(
			definition.get(
				"leave_label",
				"LEAVE."
			)
		),
		"affects_market_projection": false
	}


func accept_extraordinary_exchange_artifact_acquisition(
	actor: Person,
	terms_id: String
) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"committed": false,
			"reason": "missing_actor"
		}

	if (
		gs == null
		or gs.health_engine == null
		or gs.belongings_engine == null
	):
		return {
			"success": false,
			"committed": false,
			"reason": "required_authority_unavailable"
		}

	if not gs.health_engine.has_method(
		"commit_nonblocking_mortality_core"
	):
		return {
			"success": false,
			"committed": false,
			"reason": "nonblocking_mortality_authority_unavailable"
		}

	if not gs.health_engine.has_method(
		"queue_committed_death_fanout"
	):
		return {
			"success": false,
			"committed": false,
			"reason": "mortality_fanout_authority_unavailable"
		}

	if typeof(
		gs.scenario_state
	) != TYPE_DICTIONARY:
		return {
			"success": false,
			"committed": false,
			"reason": "artifact_persistence_state_unavailable"
		}

	var clean_terms_id: String = str(
		terms_id
	).strip_edges()

	if (
		clean_terms_id == ""
		or not extraordinary_acquisition_terms.has(
			clean_terms_id
		)
	):
		return {
			"success": false,
			"committed": false,
			"reason": "extraordinary_terms_missing_or_expired"
		}

	var terms: Dictionary = (
		extraordinary_acquisition_terms [
			clean_terms_id
		] as Dictionary
	).duplicate(true)

	if int(
		terms.get(
			"actor_id",
			-1
		)
	) != int(
		actor.id
	):
		return {
			"success": false,
			"committed": false,
			"reason": "extraordinary_terms_actor_mismatch"
		}

	if int(
		terms.get(
			"quoted_year",
			int(gs.year)
		)
	) != int(
		gs.year
	):
		extraordinary_acquisition_terms.erase(
			clean_terms_id
		)

		return {
			"success": false,
			"committed": false,
			"reason": "extraordinary_terms_stale_year"
		}

	var definition_id: String = str(
		terms.get(
			"definition_id",
			""
		)
	).strip_edges().to_lower()
	var canonical_instance_id: String = str(
		terms.get(
			"canonical_instance_id",
			""
		)
	).strip_edges().to_lower()
	var definition: Dictionary = (
		_exchange_artifact_definition(
			definition_id
		)
	)

	if definition.is_empty():
		return {
			"success": false,
			"committed": false,
			"reason": "unknown_exchange_artifact"
		}

	if (
		_exchange_artifact_instance_owner_id(
			canonical_instance_id
		)
		> 0
	):
		extraordinary_acquisition_terms.erase(
			clean_terms_id
		)

		return {
			"success": false,
			"committed": false,
			"reason": "artifact_already_claimed"
		}

	if not _exchange_artifact_listing_is_live(
		definition_id,
		canonical_instance_id,
		actor
	):
		return {
			"success": false,
			"committed": false,
			"reason": "artifact_no_longer_circulating"
		}

	var current_price: int = (
		_exchange_artifact_current_value(
			definition,
			int(gs.year)
		)
	)

	if current_price != int(
		terms.get(
			"quoted_price",
			current_price
		)
	):
		extraordinary_acquisition_terms.erase(
			clean_terms_id
		)

		return {
			"success": false,
			"committed": false,
			"reason": "extraordinary_terms_quote_changed"
		}

	if float(
		actor.bank_balance
	) < float(
		current_price
	):
		return {
			"success": false,
			"committed": false,
			"reason": "insufficient_funds"
		}

	var required_lives: int = int(
		terms.get(
			"family_lineage_lives",
			0
		)
	)
	var lineage_candidates: Array = (
		_living_family_lineage_candidates(
			actor
		)
	)

	if lineage_candidates.size() < required_lives:
		return {
			"success": false,
			"committed": false,
			"reason": "insufficient_living_family_lineage"
		}

	var selected: Array = (
		_select_lineage_consideration(
			lineage_candidates,
			required_lives,
			clean_terms_id
		)
	)

	if selected.size() != required_lives:
		return {
			"success": false,
			"committed": false,
			"reason": "lineage_selection_incomplete"
		}

	var consideration_rows: Array = []

	for raw_person in selected:
		var person: Person = raw_person as Person

		if (
			person == null
			or not person.alive
		):
			return {
				"success": false,
				"committed": false,
				"reason": "lineage_candidate_became_invalid"
			}

		consideration_rows.append({
			"person_id": int(
				person.id
			),
			"full_name": (
				"%s %s"
				% [
					str(
						person.first_name
					),
					str(
						person.last_name
					)
				]
			).strip_edges(),
			"relationship_label": (
				_relationship_label_for_artifact_consideration(
					actor,
					person
				)
			)
		})



	for index in range(
		selected.size()
	):
		var person: Person = (
			selected [
				index
			] as Person
		)

		var mortality_report: Dictionary = (
			gs.health_engine.commit_nonblocking_mortality_core(
				person,
				"Artifact Authority consideration",
				{
					"source": "artifact_authority.extraordinary_acquisition",
					"request_action": "artifact_authority_consideration",
					"death_action": "artifact_authority_consideration",
					"self_inflicted": false,
					"mode": "artifact_authority_mortality_core_committed",
					"fanout_policy": {
						"suppress_known_person_death_message": true,
						"personally_relevant_death": true
					}
				}
			)
		)

		if not bool(
			mortality_report.get(
				"death_committed",
				false
			)
		):
			return {
				"success": false,
				"committed": false,
				"reason": "artifact_consideration_mortality_commit_failed",
				"failed_person_id": int(
					person.id
				)
			}

		gs.health_engine.queue_committed_death_fanout(
			person,
			mortality_report
		)

	var transfer_report: Dictionary = (
		_commit_exchange_artifact_transfer(
			actor,
			definition_id,
			definition,
			canonical_instance_id,
			current_price,
			{
				"kind": "family_lineage_lives",
				"required_count": required_lives,
				"resolved_count": consideration_rows.size(),
				"resolved_people": consideration_rows.duplicate(true),
				"terms_id": clean_terms_id
			}
		)
	)

	if not bool(
		transfer_report.get(
			"committed",
			false
		)
	):
		return transfer_report

	extraordinary_acquisition_terms.erase(
		clean_terms_id
	)

	var presentation_lines: Array = [
		"The Sanctorum has accepted consideration."
	]

	for raw_row in consideration_rows:
		var row: Dictionary = raw_row as Dictionary

		presentation_lines.append(
			"%s, your %s, has died."
			% [
				str(
					row.get(
						"full_name",
						"Relative"
					)
				),
				str(
					row.get(
						"relationship_label",
						"relative"
					)
				)
			]
		)

	presentation_lines.append(
		"%s has transferred into your collection."
		% str(
			definition.get(
				"name",
				"Artifact"
			)
		)
	)

	transfer_report ["success"] = true
	transfer_report ["committed"] = true
	transfer_report [
		"mode"
	] = "extraordinary_artifact_acquisition_committed"
	transfer_report [
		"schema"
	] = EXCHANGE_ARTIFACT_ACQUISITION_SCHEMA
	transfer_report [
		"presentation_lines"
	] = presentation_lines
	transfer_report [
		"family_lineage_consideration"
	] = consideration_rows.duplicate(true)
	transfer_report [
		"terms_id"
	] = clean_terms_id
	transfer_report [
		"affects_market_projection"
	] = false

	return transfer_report


func _clear_extraordinary_terms_for_actor(
	actor_id: int
) -> void:
	var erase_keys: Array = []

	for raw_key in extraordinary_acquisition_terms.keys():
		var key: String = str(
			raw_key
		)
		var raw_terms: Variant = (
			extraordinary_acquisition_terms.get(
				raw_key,
				{}
			)
		)

		if typeof(
			raw_terms
		) != TYPE_DICTIONARY:
			continue

		var terms: Dictionary = raw_terms as Dictionary

		if int(
			terms.get(
				"actor_id",
				-1
			)
		) == actor_id:
			erase_keys.append(
				key
			)

	for raw_key in erase_keys:
		extraordinary_acquisition_terms.erase(
			str(raw_key)
		)


func _artifact_person_from_lineage_ref(
	raw_value: Variant
) -> Person:
	if raw_value is Person:
		return raw_value

	var person_id: int = int(
		raw_value
	)

	if (
		person_id <= 0
		or gs == null
	):
		return null

	if (
		gs.player != null
		and int(
			gs.player.id
		) == person_id
	):
		return gs.player

	if gs.has_method(
		"get_npc_by_id"
	):
		return gs.get_npc_by_id(
			person_id,
			false
		)

	return null


func _living_family_lineage_candidates(
	actor: Person
) -> Array:
	var out: Array = []

	if actor == null:
		return out

	var frontier: Array = []

	for raw_parent in actor.parents:
		frontier.append(
			raw_parent
		)

	for raw_child in actor.children:
		frontier.append(
			raw_child
		)

	var seen_ids: Dictionary = {
		int(actor.id): true
	}
	var head: int = 0
	var visited_count: int = 0

	while (
		head < frontier.size()
		and visited_count < EXCHANGE_ARTIFACT_LINEAGE_SCAN_LIMIT
	):
		var person: Person = (
			_artifact_person_from_lineage_ref(
				frontier [
					head
				]
			)
		)

		head += 1

		if person == null:
			continue

		var person_id: int = int(
			person.id
		)

		if (
			person_id <= 0
			or seen_ids.has(
				person_id
			)
		):
			continue

		seen_ids [
			person_id
		] = true
		visited_count += 1

		if person.alive:
			out.append(
				person
			)

		for raw_parent in person.parents:
			frontier.append(
				raw_parent
			)

		for raw_child in person.children:
			frontier.append(
				raw_child
			)

	return out


func _select_lineage_consideration(
	candidates: Array,
	required_count: int,
	terms_id: String
) -> Array:
	var ranked: Array = candidates.duplicate(false)

	ranked.sort_custom(
		func (a, b):
			var person_a: Person = a as Person
			var person_b: Person = b as Person

			if person_a == null:
				return false

			if person_b == null:
				return true

			var key_a: int = _artifact_stable_hash(
				"%s|%d|lineage_consideration"
				% [
					terms_id,
					int(
						person_a.id
					)
				]
			)
			var key_b: int = _artifact_stable_hash(
				"%s|%d|lineage_consideration"
				% [
					terms_id,
					int(
						person_b.id
					)
				]
			)

			return key_a > key_b
	)

	var out: Array = []

	for raw_person in ranked:
		if out.size() >= required_count:
			break

		var person: Person = raw_person as Person

		if (
			person == null
			or not person.alive
		):
			continue

		out.append(
			person
		)

	return out


func _relationship_label_for_artifact_consideration(
	actor: Person,
	relative: Person
) -> String:
	var relationship_label: String = "relative"

	if (
		gs != null
		and gs.has_method(
			"get_relationship_label_between"
		)
	):
		relationship_label = str(
			gs.get_relationship_label_between(
				actor,
				relative
			)
		).strip_edges().to_lower()

	if (
		relationship_label == ""
		or relationship_label == "stranger"
	):
		relationship_label = "relative"

	return relationship_label


func _commit_exchange_artifact_transfer(
	actor: Person,
	definition_id: String,
	definition: Dictionary,
	canonical_instance_id: String,
	price: int,
	consideration: Dictionary
) -> Dictionary:
	if (
		actor == null
		or gs == null
		or gs.belongings_engine == null
	):
		return {
			"success": false,
			"committed": false,
			"reason": "transfer_authority_unavailable"
		}

	if typeof(
		gs.scenario_state
	) != TYPE_DICTIONARY:
		return {
			"success": false,
			"committed": false,
			"reason": "artifact_persistence_state_unavailable"
		}

	if (
		_exchange_artifact_instance_owner_id(
			canonical_instance_id
		)
		> 0
	):
		return {
			"success": false,
			"committed": false,
			"reason": "artifact_already_claimed"
		}

	if float(
		actor.bank_balance
	) < float(
		price
	):
		return {
			"success": false,
			"committed": false,
			"reason": "insufficient_funds"
		}

	var artifact_item: Dictionary = (
		_build_exchange_artifact_belonging(
			actor,
			definition_id,
			definition,
			canonical_instance_id,
			price,
			consideration
		)
	)

	if artifact_item.is_empty():
		return {
			"success": false,
			"committed": false,
			"reason": "artifact_instance_build_failed"
		}

	actor.bank_balance = maxf(
		0.0,
		float(
			actor.bank_balance
		) - float(
			price
		)
	)

	gs.belongings_engine.add_item(
		actor,
		artifact_item,
		"Artifacts",
		false,
		{
			"source": "artifacts_engine.luxury_sanctorum_transfer",
			"catalog_object_id": str(
				artifact_item.get(
					"catalog_object_id",
					""
				)
			),
			"instance_object_id": str(
				artifact_item.get(
					"instance_object_id",
					""
				)
			),
			"canonical_artifact_instance_id": canonical_instance_id,
			"event_name": ActionEventTypes.ARTIFACT_ACQUIRED
		}
	)

	_append_exchange_artifact_ledger_entry({
		"schema": EXCHANGE_ARTIFACT_ACQUISITION_SCHEMA,
		"version": 1,
		"event_type": "exchange_artifact_acquisition_committed",
		"definition_id": definition_id,
		"canonical_instance_id": canonical_instance_id,
		"owner_id": int(
			actor.id
		),
		"year": int(
			gs.year
		),
		"price": price,
		"consideration": consideration.duplicate(true),
		"source": "luxury_sanctorum",
		"committed": true
	})

	var artifact_name: String = str(
		definition.get(
			"name",
			"Artifact"
		)
	)

	return {
		"success": true,
		"committed": true,
		"mode": "exchange_artifact_acquisition_committed",
		"schema": EXCHANGE_ARTIFACT_ACQUISITION_SCHEMA,
		"artifact_id": definition_id,
		"artifact_name": artifact_name,
		"canonical_instance_id": canonical_instance_id,
		"price": price,
		"text": (
			"I acquired %s through the Luxury Sanctorum for %s."
			% [
				artifact_name,
				_format_exchange_artifact_money(
					price
				)
			]
		),
		"diary_text": (
			"I acquired %s through the Luxury Sanctorum."
			% artifact_name
		),
		"affects_market_projection": true
	}


func _build_exchange_artifact_belonging(
	actor: Person,
	definition_id: String,
	definition: Dictionary,
	canonical_instance_id: String,
	acquisition_price: int,
	consideration: Dictionary
) -> Dictionary:
	if (
		actor == null
		or gs == null
	):
		return {}

	var artifact_item_id: int = int(
		gs.next_id
	)

	gs.next_id += 1

	var object_instance_id: String = (
		"object_instance:%d"
		% artifact_item_id
	)
	var catalog_object_id: String = (
		"artifact:%s"
		% definition_id
	)
	var ownership_chain: Array = []
	var historical_chain_raw: Variant = (
		definition.get(
			"historical_ownership_chain",
			[]
		)
	)

	if typeof(
		historical_chain_raw
	) == TYPE_ARRAY:
		ownership_chain = (
			historical_chain_raw as Array
		).duplicate(true)

	ownership_chain.append({
		"owner_id": int(
			actor.id
		),
		"acquired_year": int(
			gs.year
		),
		"mode": "luxury_sanctorum_acquisition",
		"source": "artifact_authority"
	})

	return {
		"id": artifact_item_id,
		"object_id": object_instance_id,
		"instance_object_id": object_instance_id,
		"canonical_artifact_instance_id": canonical_instance_id,
		"catalog_object_id": catalog_object_id,
		"name": str(
			definition.get(
				"name",
				"Artifact"
			)
		),
		"display_name": str(
			definition.get(
				"name",
				"Artifact"
			)
		),
		"type": "Artifact",
		"asset_kind": "artifact",
		"object_domains": [
			"artifact"
		],
		"artifact_kind": "exchange_artifact",
		"shop_item_id": definition_id,
		"exchange_artifact_definition_id": definition_id,
		"rarity": str(
			definition.get(
				"rarity",
				"Beyond Mythic"
			)
		),
		"mythic_rank": str(
			definition.get(
				"mythic_rank",
				"Historical Anomaly"
			)
		),
		"lore": str(
			definition.get(
				"description",
				""
			)
		),
		"color": str(
			definition.get(
				"display_color_key",
				"gold"
			)
		),
		"origin_era": str(
			definition.get(
				"origin_era",
				""
			)
		),
		"origin_country": str(
			definition.get(
				"origin_country",
				""
			)
		),
		"origin_contract": {
			"era": str(
				definition.get(
					"origin_era",
					""
				)
			),
			"year": (
				_exchange_artifact_valuation_origin_year(
					definition,
					int(
						gs.year
					)
				)
			),
			"country": str(
				definition.get(
					"origin_country",
					""
				)
			),
			"source": "luxury_sanctorum_artifact_authority",
			"source_event": ActionEventTypes.ARTIFACT_ACQUIRED
		},
		"acquired_year": int(
			gs.year
		),
		"acquired_price": acquisition_price,
		"value": int(
			definition.get(
				"base_value",
				acquisition_price
			)
		),
		"base_value": int(
			definition.get(
				"base_value",
				acquisition_price
			)
		),
		"annual_appreciation_rate": float(
			definition.get(
				"annual_appreciation_rate",
				0.0
			)
		),
		"valuation_origin_mode": str(
			definition.get(
				"valuation_origin_mode",
				"fixed_year"
			)
		),
		"valuation_origin_year": (
			_exchange_artifact_valuation_origin_year(
				definition,
				int(
					gs.year
				)
			)
		),
		"annual_bank_stipend": int(
			definition.get(
				"annual_bank_stipend",
				0
			)
		),
		"historical_value": int(
			definition.get(
				"base_value",
				acquisition_price
			)
		),
		"cultural_value": int(
			definition.get(
				"base_value",
				acquisition_price
			)
		),
		"legal": true,
		"legal_classification": "artifact",
		"ownership_chain": ownership_chain,
		"inheritable": true,
		"heirloom_candidate": true,
		"cross_reality_persistent": true,
		"extraordinary_consideration": consideration.duplicate(true),
		"affordances": [
			"artifact_action_provider",
			"heirloom_candidate",
			"historical_value_provider",
			"object_history_anchor"
		],
		"object_history": [
			{
				"event_type": "luxury_sanctorum_acquisition",
				"year": int(
					gs.year
				),
				"owner_id": int(
					actor.id
				),
				"source": "artifact_authority"
			}
		]
	}