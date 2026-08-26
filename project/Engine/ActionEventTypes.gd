extends RefCounted
class_name ActionEventTypes

const YEAR_PASSED = "year_passed"
const ERA_SHIFT = "era_shift"
const REALTIME_TICK = "realtime_tick"


const SCENARIO_NOMINATED = "scenario_nominated"
const SCENARIO_SURFACED = "scenario_surfaced"
const SCENARIO_CHOICE_MADE = "scenario_choice_made"
const SCENARIO_RESOLVED = "scenario_resolved"
const NARRATIVE_NODE_SURFACED = "narrative_node_surfaced"
const NARRATIVE_CHOICE_MADE = "narrative_choice_made"
const NARRATIVE_PRESSURE_INJECTED = "narrative_pressure_injected"
const NARRATIVE_DYNAMIC_NODE_GENERATED = "narrative_dynamic_node_generated"
const NARRATIVE_BIRTH_TRIGGERED = "narrative_birth_triggered"


const REALM_WAR = "realm_war"
const TRADE_EXECUTED = "trade_executed"
const NPC_MOVED = "npc_moved"


const NPC_BORN = "npc_born"
const NPC_DIED = "npc_died"
const PLAYER_DIED = "player_died"
const PREGNANCY_STARTED = "pregnancy_started"
const CHILD_BORN_PLAYER_LINE = "child_born_player_line"


const NPC_MARRIED = "npc_married"
const NPC_DIVORCED = "npc_divorced"
const NPC_PARTNERED = "npc_partnered"
const PLAYER_GIFTED_NPC = "player_gifted_npc"
const NPC_INSULTED = "npc_insulted"
const NPC_FOUGHT = "npc_fought"
const NPC_CHEATED = "npc_cheated"
const NPC_BETRAYED = "npc_betrayed"
const HEROIC_RESCUE = "heroic_rescue"
const ROMANCE_BETRAYAL = "romance_betrayal"


const NPC_COMMITTED_CRIME = "npc_committed_crime"
const NPC_ARRESTED = "npc_arrested"
const CRIME_RUMOR_SPREAD = "crime_rumor_spread"
const CASE_CREATED = "case_created"
const CASE_TRANSITIONED = "case_transitioned"
const CASE_VERDICT_RETURNED = "case_verdict_returned"
const CASE_SENTENCED = "case_sentenced"
const JAIL_BOOKING_CREATED = "jail_booking_created"
const PRISON_INTAKE_CREATED = "prison_intake_created"
const PRISON_RELEASED = "prison_released"
const JUSTICE_ECONOMIC_PENALTY = "justice_economic_penalty"


const SCHOOL_DRAMA = "school_drama"
const DYNASTY_SHIFT = "dynasty_shift"
const DYNASTY_FEUD_STARTED = "dynasty_feud_started"


const FAME_SPIKE = "fame_spike"
const ARTIFACT_ACQUIRED = "artifact_acquired"
const DRAGONBALL_FOUND = "dragonball_found"
const GAUNTLET_FORGED = "gauntlet_forged"
const WISH_MADE = "wish_made"
const COSMIC_ENFORCER_SPAWNED = "cosmic_enforcer_spawned"
const POWER_GRANTED = "power_granted"
const POWER_ACTIVATED = "power_activated"
const POWER_TRAINED = "power_trained"
const SUPERHERO_PATROL = "superhero_patrol"
const SUPERHERO_BATTLE_COMPLETED = "superhero_battle_completed"
const SUPERHERO_TEAM_CREATED = "superhero_team_created"
const VILLAIN_IDENTITY_CREATED = "villain_identity_created"
const INFAMY_CHANGED = "infamy_changed"
const BOXING_TRAINED = "boxing_trained"
const BOXING_FIGHT_BOOKED = "boxing_fight_booked"
const BOXING_FIGHT_COMPLETED = "boxing_fight_completed"
const BOXING_TITLE_WON = "boxing_title_won"
const BOXING_TITLE_DEFENDED = "boxing_title_defended"
const BOXING_TITLE_VACATED = "boxing_title_vacated"
const BOXING_INJURY = "boxing_injury"
const BOXING_RETIREMENT = "boxing_retirement"
const BOXING_RANKING_CHANGED = "boxing_ranking_changed"
const BOXING_RIVALRY_STARTED = "boxing_rivalry_started"
const BOXING_TRASH_TALKED = "boxing_trash_talked"
const BOXING_DUCKED_FIGHT = "boxing_ducked_fight"
const BOXING_CHANGED_DIVISION = "boxing_changed_division"
const BOXING_WEIGHT_MISSED = "boxing_weight_missed"
const BOXING_MANDATORY_ORDERED = "boxing_mandatory_ordered"
const BOXING_MANDATORY_IGNORED = "boxing_mandatory_ignored"
const BOXING_AMATEUR_TOURNAMENT_WON = "boxing_amateur_tournament_won"
const BOXING_OLYMPIC_MEDAL = "boxing_olympic_medal"
const BOXING_MEDIA_NARRATIVE = "boxing_media_narrative"
const BOXING_CALL_OUT = "boxing_call_out"
const BOXING_UPSET = "boxing_upset"
const BOXING_FAMILY_LEGACY = "boxing_family_legacy"

const PROPERTY_PURCHASED = "property_purchased"
const VEHICLE_PURCHASED = "vehicle_purchased"
const HEIRLOOM_ACQUIRED = "heirloom_acquired"
const FOOD_CONSUMED = "food_consumed"
const FOOD_COOKED = "food_cooked"
const FOOD_SPOILED = "food_spoiled"
const HUNGER_CHANGED = "hunger_changed"
const GROCERIES_PURCHASED = "groceries_purchased"
const RESTAURANT_ORDERED = "restaurant_ordered"
const LUXURY_ITEM_PURCHASED = "luxury_item_purchased"
const INVENTORY_ITEM_ADDED = "inventory_item_added"
const MONEY_DEPOSITED = "money_deposited"
const MONEY_WITHDRAWN = "money_withdrawn"
const MONEY_TRANSFERRED = "money_transferred"
const CASH_STOLEN = "cash_stolen"
const ACCOUNT_STATUS_CHANGED = "account_status_changed"
const SCANDAL = "scandal"

const MANY_REALMS_RING_ACQUIRED = "many_realms_ring_acquired"
const MANY_REALMS_REALM_CREATED = "many_realms_realm_created"
const MANY_REALMS_SUCCESSION = "many_realms_succession"
const MANY_REALMS_REBELLION = "many_realms_rebellion"
const MANY_REALMS_HUNT = "many_realms_hunt"
const MANY_REALMS_BUILD = "many_realms_build"

const VAMPIRE_TURNED = "vampire_turned"
const VAMPIRE_FED = "vampire_fed"
const VAMPIRE_KILLED = "vampire_killed"
const VAMPIRE_HUNTER_ATTACK = "vampire_hunter_attack"
const VAMPIRE_EXPOSED = "vampire_exposed"
const VAMPIRE_COVEN_JOINED = "vampire_coven_joined"
const VAMPIRE_COVEN_FOUNDED = "vampire_coven_founded"
const VAMPIRE_BLOOD_BOND = "vampire_blood_bond"
const VAMPIRE_MASQUERADE_BREACH = "vampire_masquerade_breach"
const VAMPIRE_CURED = "vampire_cured"
const VAMPIRE_DAYWALKER_AWAKENED = "vampire_daywalker_awakened"
const VAMPIRE_ELDER_AWAKENED = "vampire_elder_awakened"
const VAMPIRE_HUNTER_ORDER_FOUNDED = "vampire_hunter_order_founded"
const VAMPIRE_FRENZY = "vampire_frenzy"



const JOB_APPLIED = "job_applied"
const JOB_HIRED = "job_hired"
const JOB_WORKED = "job_worked"
const JOB_PROMOTED = "job_promoted"
const JOB_RAISE_GRANTED = "job_raise_granted"
const JOB_FIRED = "job_fired"
const JOB_QUIT = "job_quit"
const COWORKER_ADDED = "coworker_added"

const FACTION_CREATED = "faction_created"
const FACTION_SPLIT = "faction_split"
const FACTION_MERGED = "faction_merged"
const FACTION_PRESSURE_SPIKE = "faction_pressure_spike"
const FACTION_RECRUITED_MEMBER = "faction_recruited_member"
const FACTION_LOST_MEMBER = "faction_lost_member"
const FACTION_LOST_TERRITORY = "faction_lost_territory"
const FACTION_DECLINED = "faction_declined"
const FACTION_PEAKED = "faction_peaked"
const FACTION_COUP = "faction_coup"
const FACTION_FEUD_STARTED = "faction_feud_started"

const MEMORY_PROPAGATION_EVENTS = [
	PLAYER_GIFTED_NPC,
	NPC_INSULTED,
	NPC_FOUGHT,
	NPC_CHEATED,
	NPC_BETRAYED,
	HEROIC_RESCUE,
	SCHOOL_DRAMA,
	CRIME_RUMOR_SPREAD,
	PREGNANCY_STARTED,
	CHILD_BORN_PLAYER_LINE,
	DYNASTY_FEUD_STARTED,
	ROMANCE_BETRAYAL,
	BOXING_RIVALRY_STARTED,
	BOXING_TRASH_TALKED,
	BOXING_DUCKED_FIGHT,
	BOXING_CHANGED_DIVISION,
	BOXING_WEIGHT_MISSED,
	BOXING_MANDATORY_ORDERED,
	BOXING_MANDATORY_IGNORED,
	BOXING_AMATEUR_TOURNAMENT_WON,
	BOXING_OLYMPIC_MEDAL,
	BOXING_MEDIA_NARRATIVE,
	BOXING_CALL_OUT,
	BOXING_UPSET,
	BOXING_FAMILY_LEGACY,
	MANY_REALMS_RING_ACQUIRED,
	MANY_REALMS_SUCCESSION,
	MANY_REALMS_REBELLION,
	MANY_REALMS_HUNT,
	VAMPIRE_TURNED,
	VAMPIRE_FED,
	VAMPIRE_HUNTER_ATTACK,
	VAMPIRE_EXPOSED,
	VAMPIRE_COVEN_JOINED,
	VAMPIRE_COVEN_FOUNDED,
	VAMPIRE_BLOOD_BOND,
	VAMPIRE_MASQUERADE_BREACH,
	VAMPIRE_CURED,
	VAMPIRE_DAYWALKER_AWAKENED,
	VAMPIRE_ELDER_AWAKENED,
	VAMPIRE_HUNTER_ORDER_FOUNDED,
	VAMPIRE_FRENZY,
]
const UPCE_INTERPRETATION_COMPLETED = "upce_interpretation_completed"
const UPCE_MYTH_SEEDED = "upce_myth_seeded"
const UPCE_RUMOR_MUTATED = "upce_rumor_mutated"

const UNIVERSAL_PERCEPTION_EVENTS = [
	PLAYER_GIFTED_NPC,
	NPC_INSULTED,
	NPC_FOUGHT,
	NPC_CHEATED,
	NPC_BETRAYED,
	HEROIC_RESCUE,
	ROMANCE_BETRAYAL,
	SCHOOL_DRAMA,
	DYNASTY_FEUD_STARTED,
	CRIME_RUMOR_SPREAD,
	NPC_COMMITTED_CRIME,
	NPC_ARRESTED,
	CASE_CREATED,
	CASE_TRANSITIONED,
	CASE_VERDICT_RETURNED,
	CASE_SENTENCED,
	FAME_SPIKE,
	SCANDAL,
	POWER_GRANTED,
	POWER_ACTIVATED,
	POWER_TRAINED,
	SUPERHERO_PATROL,
	SUPERHERO_BATTLE_COMPLETED,
	SUPERHERO_TEAM_CREATED,
	VILLAIN_IDENTITY_CREATED,
	INFAMY_CHANGED,
	BOXING_FIGHT_COMPLETED,
	BOXING_TITLE_WON,
	BOXING_MEDIA_NARRATIVE,
	BOXING_UPSET,
	VAMPIRE_EXPOSED,
	VAMPIRE_KILLED,
	VAMPIRE_MASQUERADE_BREACH
]