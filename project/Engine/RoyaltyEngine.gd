extends Resource
class_name RoyaltyEngine

var gs
const ROYAL_SUCCESSION_CONTRACTS:= {
	"default_monarchy": {
		"schema": "eralife.royal_succession_contract",
		"id": "default.monarchy.primogeniture",
		"display_name": "Primogeniture Monarchy",
		"succession_mode": "primogeniture",
		"direct_line_first": true,
		"designated_heir_override": true,
		"single_active_ruler": true,
		"allow_deposed_claimants": false,
		"gender_priority": [],
		"weights": {
			"designated_heir": 100000.0,
			"direct_child": 35000.0,
			"descendant": 18000.0,
			"age": 120.0,
			"approval": 2.0,
			"fame": 1.0,
			"smarts": 1.0,
			"willpower": 1.0
		}
	},
	"fire_nation": {
		"schema": "eralife.royal_succession_contract",
		"id": "fire_nation.agnatic_cognatic_monarchy",
		"display_name": "Agnatic-Cognatic Monarchy",
		"succession_mode": "agnatic_cognatic_monarchy",
		"direct_line_first": true,
		"designated_heir_override": true,
		"single_active_ruler": true,
		"allow_deposed_claimants": false,
		"gender_priority": ["male", "female"],
		"weights": {
			"designated_heir": 100000.0,
			"male_preference": 26000.0,
			"direct_child": 35000.0,
			"descendant": 18000.0,
			"age": 130.0,
			"approval": 2.0,
			"fame": 1.0,
			"smarts": 1.0,
			"willpower": 1.5
		}
	},
	"water_tribe": {
		"schema": "eralife.royal_succession_contract",
		"id": "water_tribe.clan_council_inheritance",
		"display_name": "Clan Council Inheritance",
		"succession_mode": "clan_council_inheritance",
		"direct_line_first": false,
		"designated_heir_override": true,
		"single_active_ruler": true,
		"allow_deposed_claimants": false,
		"gender_priority": [],
		"weights": {
			"designated_heir": 65000.0,
			"direct_child": 12000.0,
			"descendant": 8000.0,
			"age": 55.0,
			"approval": 22.0,
			"smarts": 9.0,
			"willpower": 8.0,
			"fame": 2.0
		}
	},
	"earth_kingdom": {
		"schema": "eralife.royal_succession_contract",
		"id": "earth_kingdom.regional_noble_election",
		"display_name": "Regional Noble Election",
		"succession_mode": "regional_noble_election",
		"direct_line_first": false,
		"designated_heir_override": true,
		"single_active_ruler": true,
		"allow_deposed_claimants": false,
		"gender_priority": [],
		"weights": {
			"designated_heir": 55000.0,
			"direct_child": 8500.0,
			"descendant": 6500.0,
			"age": 35.0,
			"approval": 14.0,
			"fame": 12.0,
			"smarts": 10.0,
			"willpower": 4.0
		}
	},
	"air_nomads": {
		"schema": "eralife.royal_succession_contract",
		"id": "air_nomads.spiritual_successor_selection",
		"display_name": "Spiritual Successor Selection",
		"succession_mode": "spiritual_successor_selection",
		"direct_line_first": false,
		"designated_heir_override": true,
		"single_active_ruler": true,
		"allow_deposed_claimants": false,
		"gender_priority": [],
		"weights": {
			"designated_heir": 50000.0,
			"direct_child": 6500.0,
			"descendant": 5500.0,
			"age": 18.0,
			"approval": 8.0,
			"smarts": 12.0,
			"willpower": 16.0,
			"fame": 1.0,
			"ambition_penalty": 4.0
		}
	}
}
func _init(_gs):
	gs = _gs

	if ROYAL_TITLE_STYLES.has("pharaonic"):
		ROYAL_TITLE_STYLES ["pharaonic"] ["heir_male"] = "Crown Prince of Egypt"
		ROYAL_TITLE_STYLES ["pharaonic"] ["heir_female"] = "Crown Princess of Egypt"
		ROYAL_TITLE_STYLES ["pharaonic"] ["royal_child_male"] = "Prince of Egypt"
		ROYAL_TITLE_STYLES ["pharaonic"] ["royal_child_female"] = "Princess of Egypt"

	ROYAL_TITLE_STYLES ["court_nobility"] = {
		"ruler_male": "King",
		"ruler_female": "Queen",
		"heir_male": "Crown Prince",
		"heir_female": "Crown Princess",
		"royal_child_male": "Prince",
		"royal_child_female": "Princess",
		"lesser_royal_male": "Marquess",
		"lesser_royal_female": "Marchioness",
		"consort_male": "Prince Consort",
		"consort_female": "Queen Consort"
	}
	_install_royal_title_style_extensions()
func export_succession_contracts() -> Dictionary:
	return ROYAL_SUCCESSION_CONTRACTS.duplicate(true)


func get_succession_contract_for_ruler(
	ruler: Person
) -> Dictionary:
	return _royal_succession_contract_for_ruler(
		ruler
	)


func build_succession_line_for_ruler(
	ruler: Person
) -> Array:
	if ruler == null:
		return []

	var house_members: Array = _house_members_for(
		ruler
	)
	var contract: Dictionary = (
		_royal_succession_contract_for_ruler(
			ruler
		)
	)

	return _build_contract_succession_line(
		ruler,
		house_members,
		contract
	)


func house_members_for(
	anchor: Person
) -> Array:
	return _house_members_for(anchor)


func house_key_for(
	actor: Person
) -> String:
	return _house_key(actor)


func resolve_rank_title(
	actor: Person,
	rank_key: String
) -> String:
	return _resolve_rank_title(
		actor,
		rank_key
	)


func refresh_house_succession(
	ruler: Person
) -> void:
	_refresh_house_succession(ruler)


func set_designated_heir(
	ruler: Person,
	heir: Person
) -> void:
	if ruler == null or heir == null:
		return

	var house_members: Array = _house_members_for(
		ruler
	)

	for member in house_members:
		if member == null:
			continue

		if int(member.id) == int(heir.id):
			_set_royal_rank_seed_trait(
				member,
				"Heir Line"
			)
			member.is_royal = true
			member.social_class = "Royal"
			member.deposed = false
			member.exiled = false
			member.succession_rank = 1
			member.royal_title = _resolve_rank_title(
				member,
				"heir"
			)
		elif (
			_normalize_royal_rank_seed(
				_royal_rank_seed_for_npc(
					member
				)
			) == "Heir Line"
		):
			_set_royal_rank_seed_trait(
				member,
				"Royal Child"
			)

	_refresh_house_succession(ruler)


func commit_ruler_transition(
	new_ruler: Person,
	previous_ruler: Person = null,
	_context: Dictionary = {}
) -> void:
	if new_ruler == null:
		return

	_sync_realm_ruler_from_royal_change(
		new_ruler,
		previous_ruler
	)
	_refresh_house_succession(new_ruler)

	if (
		gs != null
		and gs.royalty_runtime_engine != null
	):
		gs.royalty_runtime_engine.ingest_actor(
			new_ruler,
			{
				"source": (
					"royalty_engine."
					+ "commit_ruler_transition"
				),
				"silent": true
			}
		)

		if previous_ruler != null:
			gs.royalty_runtime_engine.ingest_actor(
				previous_ruler,
				{
					"source": (
						"royalty_engine."
						+ "commit_ruler_transition"
					),
					"silent": true
				}
			)


func run_legacy_yearly_tick(
	_payload: Dictionary = {}
) -> void:
	var processed_houses: Dictionary = {}

	for npc in gs.npcs:
		if npc == null:
			continue
		if not npc.alive:
			continue
		if not npc.is_royal:
			continue

		var house_key: String = _house_key(npc)

		if house_key == "":
			continue
		if processed_houses.has(house_key):
			continue

		processed_houses [house_key] = true
		_yearly_house_tick(npc)
var ROYAL_TITLE_STYLES:= {
	"pharaonic": {
		"ruler_male": "Pharaoh",
		"ruler_female": "Pharaoh",
		"heir_male": "Crown Prince",
		"heir_female": "Crown Princess",
		"royal_child_male": "Prince",
		"royal_child_female": "Princess",
		"lesser_royal_male": "High Noble",
		"lesser_royal_female": "High Noble",
		"consort_male": "Royal Consort",
		"consort_female": "Royal Consort"
	},
	"empire": {
		"ruler_male": "Emperor",
		"ruler_female": "Empress",
		"heir_male": "Crown Prince",
		"heir_female": "Crown Princess",
		"royal_child_male": "Prince",
		"royal_child_female": "Princess",
		"lesser_royal_male": "Duke",
		"lesser_royal_female": "Duchess",
		"consort_male": "Prince Consort",
		"consort_female": "Empress Consort"
	},
	"kingdom": {
		"ruler_male": "King",
		"ruler_female": "Queen",
		"heir_male": "Crown Prince",
		"heir_female": "Crown Princess",
		"royal_child_male": "Prince",
		"royal_child_female": "Princess",
		"lesser_royal_male": "Duke",
		"lesser_royal_female": "Duchess",
		"consort_male": "Prince Consort",
		"consort_female": "Queen Consort"
	},
	"future": {
		"ruler_male": "Prime Sovereign",
		"ruler_female": "Prime Sovereign",
		"heir_male": "Stellar Heir",
		"heir_female": "Stellar Heir",
		"royal_child_male": "Celestial Prince",
		"royal_child_female": "Celestial Princess",
		"lesser_royal_male": "Archduke",
		"lesser_royal_female": "Archduchess",
		"consort_male": "Sovereign Consort",
		"consort_female": "Sovereign Consort"
	},
	"fire_nation": {
		"ruler_male": "Fire Lord",
		"ruler_female": "Fire Queen",
		"heir_male": "Crown Prince",
		"heir_female": "Crown Princess",
		"royal_child_male": "Prince",
		"royal_child_female": "Princess",
		"lesser_royal_male": "Lord",
		"lesser_royal_female": "Lady",
		"consort_male": "Fire Prince Consort",
		"consort_female": "Fire Queen Consort"
	},
	"water_tribe": {
		"ruler_male": "Chief",
		"ruler_female": "Chief",
		"heir_male": "Tribal Heir",
		"heir_female": "Tribal Heir",
		"royal_child_male": "Prince",
		"royal_child_female": "Princess",
		"lesser_royal_male": "Clan Lord",
		"lesser_royal_female": "Clan Lady",
		"consort_male": "Royal Consort",
		"consort_female": "Royal Consort"
	},
	"earth_kingdom": {
		"ruler_male": "Earth King",
		"ruler_female": "Earth Queen",
		"heir_male": "Crown Prince",
		"heir_female": "Crown Princess",
		"royal_child_male": "Prince",
		"royal_child_female": "Princess",
		"lesser_royal_male": "Duke",
		"lesser_royal_female": "Duchess",
		"consort_male": "Prince Consort",
		"consort_female": "Queen Consort"
	},
	"air_nomads": {
		"ruler_male": "Air Regent",
		"ruler_female": "Air Regent",
		"heir_male": "Temple Heir",
		"heir_female": "Temple Heir",
		"royal_child_male": "Sky Prince",
		"royal_child_female": "Sky Princess",
		"lesser_royal_male": "Sky Lord",
		"lesser_royal_female": "Sky Lady",
		"consort_male": "Sky Consort",
		"consort_female": "Sky Consort"
	}
}
func _install_royal_title_style_extensions() -> void:
	for raw_style_key in ROYAL_TITLE_STYLES.keys():
		var style_key:= str(raw_style_key)
		var style_raw: Variant = ROYAL_TITLE_STYLES.get(style_key, {})
		if typeof(style_raw) != TYPE_DICTIONARY:
			continue

		var style: Dictionary = style_raw

		if not style.has("ducal_royal_male"):
			style ["ducal_royal_male"] = str(style.get("lesser_royal_male", "Duke"))
		if not style.has("ducal_royal_female"):
			style ["ducal_royal_female"] = str(style.get("lesser_royal_female", "Duchess"))

		if not style.has("marcher_royal_male"):
			style ["marcher_royal_male"] = "Marquess"
		if not style.has("marcher_royal_female"):
			style ["marcher_royal_female"] = "Marchioness"

		ROYAL_TITLE_STYLES [style_key] = style

	if ROYAL_TITLE_STYLES.has("court_nobility"):
		var court: Dictionary = ROYAL_TITLE_STYLES ["court_nobility"]
		court ["ducal_royal_male"] = "Duke"
		court ["ducal_royal_female"] = "Duchess"
		court ["marcher_royal_male"] = "Marquess"
		court ["marcher_royal_female"] = "Marchioness"
		court ["lesser_royal_male"] = "Duke"
		court ["lesser_royal_female"] = "Duchess"
		ROYAL_TITLE_STYLES ["court_nobility"] = court
func assign_royal_birth(
	payload
) -> void:
	var npc: Person = null

	if payload is Person:
		npc = payload
	elif typeof(payload) == TYPE_DICTIONARY:
		var payload_npc: Variant = payload.get(
			"npc",
			null
		)

		if payload_npc is Person:
			npc = payload_npc
		else:
			var npc_id: int = int(
				payload.get(
					"npc_id",
					-1
				)
			)
			npc = gs.get_npc_by_id(npc_id)
	else:
		npc = gs.get_npc_by_id(
			int(payload)
		)

	if npc == null:
		return

	var royal_parent: Person = null

	for pid in npc.parents:
		var parent: Person = gs.get_npc_by_id(
			int(pid)
		)

		if parent == null:
			continue

		if (
			parent.is_royal
			or parent.social_class == "Royal"
		):
			royal_parent = parent
			break

	if (
		royal_parent == null
		and npc.social_class != "Royal"
		and not npc.is_royal
	):
		return

	npc.is_royal = true
	npc.social_class = "Royal"
	npc.palace_owned = true

	if royal_parent != null:
		npc.realm_id = int(
			royal_parent.realm_id
		)

		var inherited_house_origin: String = str(
			royal_parent.dynasty_origin
		).strip_edges()

		if inherited_house_origin == "":
			inherited_house_origin = _house_key(
				royal_parent
			)

		npc.dynasty_origin = inherited_house_origin

		if (
			str(
				npc.bending_nation
			).strip_edges() == ""
			and _royal_person_should_use_bending_title_style(
				royal_parent
			)
		):
			npc.bending_nation = str(
				royal_parent.bending_nation
			).strip_edges()

	npc.approval = clamp(
		max(
			int(npc.approval),
			45
		),
		0,
		100
	)

	if (
		int(npc.succession_rank) <= 0
		and not npc.is_ruler
	):
		npc.succession_rank = 99

	if str(
		npc.royal_title
	).strip_edges() == "":
		npc.royal_title = _resolve_rank_title(
			npc,
			"royal_child"
		)

	_sync_royal_job_identity(npc)
	_apply_royal_fame_floor(npc)
	_append_birth_memory_if_missing(npc)

	var house_anchor: Person = royal_parent

	if house_anchor == null:
		house_anchor = npc

	var house_members: Array = _house_members_for(
		house_anchor
	)

	if not house_members.is_empty():
		var ruler: Person = (
			_find_living_ruler_from_members(
				house_members
			)
		)

		if ruler == null:
			ruler = _pick_best_claimant(
				house_members
			)

		if ruler != null:
			_refresh_house_succession(ruler)

	if (
		gs != null
		and gs.royalty_runtime_engine != null
	):
		gs.royalty_runtime_engine.ingest_actor(
			npc,
			{
				"source": (
					"royalty_engine.assign_royal_birth"
				)
			}
		)

		if royal_parent != null:
			gs.royalty_runtime_engine.ingest_actor(
				royal_parent,
				{
					"source": (
						"royalty_engine.assign_royal_birth"
					),
					"silent": true
				}
			)

		gs.royalty_runtime_engine.repair_state({
			"source": (
				"royalty_engine.assign_royal_birth"
			)
		})
func _custom_royal_birth_origin_contract(settings: Dictionary = {}) -> Dictionary:
	var raw_contract: Variant = settings.get("_birth_origin_contract", settings.get("birth_origin_contract", {}))
	if typeof(raw_contract) == TYPE_DICTIONARY:
		return (raw_contract as Dictionary).duplicate(true)
	return {}


func _custom_royal_birth_contract_section(settings: Dictionary, section_key: String) -> Dictionary:
	var contract: Dictionary = _custom_royal_birth_origin_contract(settings)
	var raw_section: Variant = contract.get(section_key, {})
	if typeof(raw_section) == TYPE_DICTIONARY:
		return (raw_section as Dictionary).duplicate(true)
	return {}


func _resolve_custom_royal_birth_nation(player: Person, settings: Dictionary = {}) -> String:
	var nation_contract: Dictionary = _custom_royal_birth_contract_section(settings, "nation_contract")

	for key in ["royal_nation", "realm_name", "country"]:
		var contract_nation: String = str(nation_contract.get(key, "")).strip_edges()
		if contract_nation != "":
			return contract_nation

	var explicit_nation: String = str(settings.get("royal_nation", settings.get("royal_realm_country", settings.get("bending_nation", "")))).strip_edges()
	if explicit_nation != "":
		return explicit_nation

	var selected_bending: String = str(settings.get("bending_type", "none")).strip_edges().to_lower()
	var selected_country: String = str(settings.get("country", "")).strip_edges()

	if selected_bending == "avatar" and _is_elemental_royal_country_name(selected_country):
		return selected_country

	match selected_bending:
		"air":
			return "Air Nomads"
		"water":
			return "Water Tribe"
		"earth":
			return "Earth Kingdom"
		"fire":
			return "Fire Nation"

	if player != null:
		var player_nation: String = str(player.bending_nation).strip_edges()
		if player_nation != "":
			return player_nation
		if str(player.home_country).strip_edges() != "":
			return str(player.home_country).strip_edges()
		if str(player.birth_country).strip_edges() != "":
			return str(player.birth_country).strip_edges()

	return selected_country


func _select_custom_royal_parent_by_gender(parent_candidates: Array, gender_text: String) -> Person:
	var wanted_gender: String = str(gender_text).strip_edges().to_lower()
	if wanted_gender == "":
		return null

	for raw_parent in parent_candidates:
		var parent: Person = raw_parent
		if parent == null:
			continue
		if str(parent.gender).strip_edges().to_lower() == wanted_gender:
			return parent

	return null


func _resolve_custom_royal_ruling_parent(player: Person, parent_candidates: Array, settings: Dictionary = {}) -> Person:
	if player == null:
		return null

	var family_contract: Dictionary = _custom_royal_birth_contract_section(settings, "family_contract")

	var requested_parent_id: int = int(settings.get("royal_ruler_parent_id", family_contract.get("ruler_parent_id", -1)))
	if requested_parent_id > 0:
		for raw_parent in parent_candidates:
			var parent_by_id: Person = raw_parent
			if parent_by_id != null and int(parent_by_id.id) == requested_parent_id:
				return parent_by_id

	var requested: String = str(settings.get("royal_ruling_parent", settings.get("ruler_parent", settings.get("ruling_parent", family_contract.get("requested_ruling_parent", "auto"))))).strip_edges().to_lower()

	if requested in ["mother", "mom", "maternal", "matriarch", "queen", "female"]:
		var mother: Person = _select_custom_royal_parent_by_gender(parent_candidates, "female")
		if mother != null:
			return mother

	if requested in ["father", "dad", "paternal", "patriarch", "king", "male"]:
		var father: Person = _select_custom_royal_parent_by_gender(parent_candidates, "male")
		if father != null:
			return father

	if requested == "random":
		var living_candidates: Array = []
		for raw_parent in parent_candidates:
			var random_parent: Person = raw_parent
			if random_parent != null:
				living_candidates.append(random_parent)
		if not living_candidates.is_empty():
			return living_candidates.pick_random()

	if bool(settings.get("matriarchal_royal_birth", family_contract.get("prefer_maternal_ruler", false))):
		var matriarch: Person = _select_custom_royal_parent_by_gender(parent_candidates, "female")
		if matriarch != null:
			return matriarch

	for raw_parent in parent_candidates:
		var default_parent: Person = raw_parent
		if default_parent == null:
			continue
		if str(default_parent.last_name) == str(player.last_name):
			return default_parent

	if not parent_candidates.is_empty():
		return parent_candidates [0]

	return null


func _direct_line_ancestors_for_player_from_parent(player: Person, starting_parent: Person) -> Array:
	var out: Array = []
	if player == null or starting_parent == null:
		return out

	var current: Person = starting_parent
	var seen: Dictionary = {}

	for _i in range(3):
		if current == null:
			break

		var current_id: int = int(current.id)
		if current_id <= 0 or seen.has(current_id):
			break

		seen [current_id] = true
		out.append(current)

		var next_parent: Person = null
		for pid in current.parents:
			var parent: Person = gs.get_npc_by_id(int(pid))
			if parent == null:
				continue
			if next_parent == null:
				next_parent = parent
			if str(parent.last_name) == str(current.last_name):
				next_parent = parent
				break

		current = next_parent

	return out


func _apply_custom_royal_birth_nation_to_house(house_members: Array, nation: String, settings: Dictionary = {}) -> void:
	var clean_nation: String = str(nation).strip_edges()
	if clean_nation == "":
		return

	var selected_country: String = str(settings.get("country", "")).strip_edges()
	var selected_city: String = str(settings.get("city", "")).strip_edges()
	var force_elemental_house: bool = _is_elemental_royal_country_name(clean_nation)

	for raw_member in house_members:
		var member: Person = raw_member
		if member == null:
			continue

		if force_elemental_house:
			member.bending_nation = clean_nation

			match clean_nation:
				"Air Nomads":
					if str(member.bending_type).strip_edges() == "" or str(member.bending_type).strip_edges() == "none":
						member.bending_type = "air"
				"Water Tribe":
					if str(member.bending_type).strip_edges() == "" or str(member.bending_type).strip_edges() == "none":
						member.bending_type = "water"
				"Earth Kingdom":
					if str(member.bending_type).strip_edges() == "" or str(member.bending_type).strip_edges() == "none":
						member.bending_type = "earth"
				"Fire Nation":
					if str(member.bending_type).strip_edges() == "" or str(member.bending_type).strip_edges() == "none":
						member.bending_type = "fire"

			member.home_country = clean_nation
			if str(member.birth_country).strip_edges() == "" or str(member.birth_country).strip_edges() == selected_country:
				member.birth_country = clean_nation
			if str(member.home_city).strip_edges() == "" and selected_city != "":
				member.home_city = selected_city
func _enforce_custom_player_birth_rank_after_succession(player: Person, ruler: Person, rank_seed: String) -> void:
	if player == null or ruler == null:
		return

	var normalized_rank_seed:= _normalize_royal_rank_seed(rank_seed)
	if normalized_rank_seed == "":
		normalized_rank_seed = "Royal Child"

	if int(player.id) == int(ruler.id):
		return

	ruler.is_ruler = true
	ruler.is_royal = true
	ruler.social_class = "Royal"
	ruler.deposed = false
	ruler.exiled = false
	ruler.palace_owned = true
	ruler.succession_rank = 0
	ruler.royal_title = _resolve_rank_title(ruler, "ruler")

	player.is_ruler = false
	player.is_royal = true
	player.social_class = "Royal"
	player.deposed = false
	player.exiled = false
	player.palace_owned = true
	player.realm_id = int(ruler.realm_id)

	match normalized_rank_seed:
		"Heir Line":
			player.succession_rank = 1
			player.royal_title = _resolve_rank_title(player, "heir")
		"Royal Child":
			player.succession_rank = max(2, int(player.succession_rank))
			player.royal_title = _resolve_rank_title(player, "royal_child")
		"Ducal Line":
			player.succession_rank = max(4, int(player.succession_rank))
			player.royal_title = _resolve_rank_title(player, "ducal_royal")
		"Marcher Line":
			player.succession_rank = max(6, int(player.succession_rank))
			player.royal_title = _resolve_rank_title(player, "marcher_royal")
		_:
			player.succession_rank = max(10, int(player.succession_rank))
			player.royal_title = _resolve_rank_title(player, "lesser_royal")

	_sync_royal_job_identity(ruler)
	_sync_royal_job_identity(player)
	_apply_royal_fame_floor(ruler)
	_apply_royal_fame_floor(player)

	if gs != null and gs.realm_engine != null and gs.realm_engine.has_method("sync_realm_ruler_from_person"):
		gs.realm_engine.sync_realm_ruler_from_person(ruler)
func _royal_runtime_heavy_work_deferred() -> bool:
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
			"god_mode_life_prewarm_active",
			false
		)
	):
		return true

	if bool(
		gs.scenario_state.get(
			"birth_shell_first_boot_active",
			false
		)
	):
		return true

	if bool(
		gs.scenario_state.get(
			"birth_shell_deferred_boot_pending",
			false
		)
	):
		return true

	if bool(
		gs.scenario_state.get(
			"royalty_heavy_bootstrap_forbidden_during_prewarm",
			false
		)
	):
		return true

	if (
		bool(
			gs.scenario_state.get(
				"interactive_boot_requested",
				false
			)
		)
		and not bool(
			gs.scenario_state.get(
				"birth_shell_player_control_released",
				false
			)
		)
	):
		return true

	return false

func _custom_royal_approval_from_settings(settings: Dictionary, fallback_value: int = 50) -> int:
	if typeof(settings) != TYPE_DICTIONARY:
		return clamp(int(fallback_value), 0, 100)

	if not settings.has("approval"):
		return clamp(int(fallback_value), 0, 100)

	return clamp(int(round(float(settings.get("approval", fallback_value)))), 0, 100)


func _apply_custom_royal_approval_from_settings(player: Person, settings: Dictionary = {}) -> void:
	if player == null:
		return

	if typeof(settings) != TYPE_DICTIONARY:
		return

	if not settings.has("approval"):
		return

	player.approval = _custom_royal_approval_from_settings(settings, int(player.approval))
func setup_custom_player_royal_lineage(
	player: Person,
	settings: Dictionary = {}
) -> void:
	if player == null:
		return

	var defer_heavy_royal_bootstrap: bool = (
		_royal_runtime_heavy_work_deferred()
	)
	var rank_seed:= _normalize_royal_rank_seed(
		str(
			settings.get(
				"royal_rank",
				""
			)
		)
	)

	if rank_seed == "":
		rank_seed = "Royal Child"

	if defer_heavy_royal_bootstrap:
		_setup_custom_player_royal_lineage_first_frame_shell(
			player,
			settings,
			rank_seed
		)
		return

	var house_members:= _gather_player_house_members(
		player
	)

	if house_members.is_empty():
		return

	var parent_candidates: Array = []

	for pid in player.parents:
		var parent: Person = gs.get_npc_by_id(
			int(pid)
		)

		if parent != null:
			parent_candidates.append(
				parent
			)

	var primary_parent: Person = (
		_resolve_custom_royal_ruling_parent(
			player,
			parent_candidates,
			settings
		)
	)

	if primary_parent == null:
		for parent in parent_candidates:
			if primary_parent == null:
				primary_parent = parent

			if str(parent.last_name) == str(
				player.last_name
			):
				primary_parent = parent
				break

	var other_parent: Person = null

	for parent in parent_candidates:
		if (
			primary_parent != null
			and int(parent.id) == int(
				primary_parent.id
			)
		):
			continue

		other_parent = parent
		break

	var royal_nation: String = (
		_resolve_custom_royal_birth_nation(
			player,
			settings
		)
	)

	_apply_custom_royal_birth_nation_to_house(
		house_members,
		royal_nation,
		settings
	)

	var target_realm_id:= (
		_resolve_custom_royal_birth_realm_id(
			player,
			settings
		)
	)

	if target_realm_id > 0:
		for member in house_members:
			if member == null:
				continue

			member.realm_id = target_realm_id

	var lineage: Array = (
		_direct_line_ancestors_for_player_from_parent(
			player,
			primary_parent
		)
	)

	if lineage.is_empty():
		lineage = _direct_line_ancestors_for_player(
			player
		)

	var direct_grandparent: Person = (
		lineage [1]
		if lineage.size() > 1
		else null
	)
	var direct_great_grandparent: Person = (
		lineage [2]
		if lineage.size() > 2
		else null
	)
	var founder: Person = null

	match rank_seed:
		"Heir Line", "Royal Child":
			founder = primary_parent

		"Ducal Line":
			founder = direct_grandparent

		"Marcher Line":
			founder = direct_great_grandparent

	if founder == null:
		founder = _pick_throne_founder_for_player(
			player
		)

	if founder == null:
		var non_player_house_members: Array = []

		for member in house_members:
			if member == null:
				continue

			if int(member.id) == int(player.id):
				continue

			non_player_house_members.append(
				member
			)

		founder = _oldest_person_in_list(
			non_player_house_members
		)





	if (
		founder == null
		or int(founder.id) == int(player.id)
	):
		_setup_custom_player_royal_lineage_first_frame_shell(
			player,
			settings,
			rank_seed
		)

		if (
			gs != null
			and typeof(gs.scenario_state)
			== TYPE_DICTIONARY
		):
			gs.scenario_state [
				"royal_house_heavy_bootstrap_parent_authority_unresolved"
			] = true
			gs.scenario_state [
				"royal_house_heavy_bootstrap_self_promotion_forbidden"
			] = true
			gs.scenario_state [
				"royal_house_heavy_bootstrap_unresolved_at_ms"
			] = int(Time.get_ticks_msec())

		return

	var ruler: Person = founder
	var house_origin:= _royal_house_origin(
		ruler,
		player
	)

	for member in house_members:
		if member == null:
			continue

		_stamp_royal_identity(
			member,
			ruler,
			"lesser_royal",
			house_origin
		)
		member.is_ruler = false
		member.exiled = false

		if int(member.id) != int(ruler.id):
			member.deposed = false

	if royal_nation != "":
		_apply_custom_royal_birth_nation_to_house(
			house_members,
			royal_nation,
			settings
		)

	ruler.is_ruler = true
	ruler.is_royal = true
	ruler.social_class = "Royal"
	ruler.deposed = false
	ruler.exiled = false
	ruler.palace_owned = true
	ruler.succession_rank = 0
	ruler.royal_title = _resolve_rank_title(
		ruler,
		"ruler"
	)
	ruler.approval = max(
		int(ruler.approval),
		72
	)

	if other_parent != null:
		other_parent.is_ruler = false
		other_parent.is_royal = true
		other_parent.social_class = "Royal"
		other_parent.deposed = false
		other_parent.exiled = false
		other_parent.palace_owned = true
		other_parent.realm_id = int(
			ruler.realm_id
		)
		other_parent.dynasty_origin = house_origin
		other_parent.royal_title = (
			_resolve_rank_title(
				other_parent,
				"consort"
			)
		)
		_sync_royal_job_identity(
			other_parent
		)

	for member in house_members:
		if member == null:
			continue

		if int(member.id) == int(player.id):
			continue

		if (
			_normalize_royal_rank_seed(
				_royal_rank_seed_for_npc(
					member
				)
			)
			== "Heir Line"
		):
			_set_royal_rank_seed_trait(
				member,
				""
			)

	_apply_custom_player_rank_seed_hierarchy(
		player,
		ruler,
		primary_parent,
		rank_seed
	)
	_set_royal_rank_seed_trait(
		player,
		rank_seed
	)
	_apply_bending_royal_theme(
		player,
		settings
	)
	_apply_seeded_rank_bias(
		player
	)
	_apply_royal_fame_floor(
		player
	)
	_apply_royal_fame_floor(
		ruler
	)

	if primary_parent != null:
		_apply_royal_fame_floor(
			primary_parent
		)

	if other_parent != null:
		_apply_royal_fame_floor(
			other_parent
		)

	_sync_house_royal_jobs(
		house_members,
		true
	)
	_enforce_custom_player_birth_rank_after_succession(
		player,
		ruler,
		rank_seed
	)
	_apply_custom_royal_approval_from_settings(
		player,
		settings
	)

	_refresh_house_succession(
		ruler
	)
	_announce_succession(
		ruler,
		false
	)
func _setup_custom_player_royal_lineage_first_frame_shell(
	player: Person,
	settings: Dictionary = {},
	rank_seed: String = "Royal Child"
) -> void:
	if player == null:
		return

	var normalized_rank_seed:= _normalize_royal_rank_seed(
		rank_seed
	)

	if normalized_rank_seed == "":
		normalized_rank_seed = "Royal Child"

	var parent_candidates: Array = []

	if gs != null:
		for pid in player.parents:
			var parent: Person = gs.get_npc_by_id(
				int(pid)
			)

			if parent != null:
				parent_candidates.append(
					parent
				)

	var primary_parent: Person = (
		_resolve_custom_royal_ruling_parent(
			player,
			parent_candidates,
			settings
		)
	)

	if primary_parent == null:
		for parent in parent_candidates:
			if primary_parent == null:
				primary_parent = parent

			if str(parent.last_name) == str(
				player.last_name
			):
				primary_parent = parent
				break

	var other_parent: Person = null

	for parent in parent_candidates:
		if (
			primary_parent != null
			and int(parent.id) == int(
				primary_parent.id
			)
		):
			continue

		other_parent = parent
		break

	var house_members: Array = [
		player
	]

	for parent in parent_candidates:
		if (
			parent != null
			and parent not in house_members
		):
			house_members.append(
				parent
			)

	var royal_nation: String = (
		_resolve_custom_royal_birth_nation(
			player,
			settings
		)
	)

	if royal_nation != "":
		_apply_custom_royal_birth_nation_to_house(
			house_members,
			royal_nation,
			settings
		)

	var target_realm_id:= (
		_resolve_custom_royal_birth_realm_id(
			player,
			settings
		)
	)

	if target_realm_id > 0:
		for member in house_members:
			if member == null:
				continue

			member.realm_id = target_realm_id

	var ruler: Person = primary_parent





	if ruler == null:
		player.is_ruler = false
		player.is_royal = true
		player.deposed = false
		player.exiled = false
		player.palace_owned = true
		player.dynasty_origin = str(
			player.last_name
		).strip_edges()

		if target_realm_id > 0:
			player.realm_id = target_realm_id

		match normalized_rank_seed:
			"Heir Line":
				player.social_class = "Royal"
				player.succession_rank = 1
				player.royal_title = (
					_resolve_rank_title(
						player,
						"heir"
					)
				)

			"Royal Child":
				player.social_class = "Royal"
				player.succession_rank = 2
				player.royal_title = (
					_resolve_rank_title(
						player,
						"royal_child"
					)
				)

			"Ducal Line":
				player.social_class = "Noble"
				player.succession_rank = 4
				player.royal_title = (
					_resolve_rank_title(
						player,
						"ducal_royal"
					)
				)

			"Marcher Line":
				player.social_class = "Noble"
				player.succession_rank = 6
				player.royal_title = (
					_resolve_rank_title(
						player,
						"marcher_royal"
					)
				)

			_:
				player.social_class = "Noble"
				player.succession_rank = max(
					8,
					int(player.succession_rank)
				)
				player.royal_title = (
					_resolve_rank_title(
						player,
						"lesser_royal"
					)
				)

		_set_royal_rank_seed_trait(
			player,
			normalized_rank_seed
		)
		_sync_royal_job_identity(
			player
		)
		_apply_custom_royal_approval_from_settings(
			player,
			settings
		)

		if (
			gs != null
			and typeof(gs.scenario_state)
			== TYPE_DICTIONARY
		):
			gs.scenario_state [
				"royal_house_heavy_bootstrap_deferred"
			] = true
			gs.scenario_state [
				"royal_house_heavy_bootstrap_deferred_player_id"
			] = int(player.id)
			gs.scenario_state [
				"royal_house_heavy_bootstrap_deferred_ruler_id"
			] = -1
			gs.scenario_state [
				"royal_house_heavy_bootstrap_deferred_rank_seed"
			] = normalized_rank_seed
			gs.scenario_state [
				"royal_house_heavy_bootstrap_deferred_reason"
			] = (
				"first_frame_shell_waiting_for_external_ruler"
			)
			gs.scenario_state [
				"royal_first_frame_external_ruler_pending"
			] = true
			gs.scenario_state [
				"royal_first_frame_self_promotion_forbidden"
			] = true
			gs.scenario_state [
				"royal_house_heavy_bootstrap_deferred_at_ms"
			] = int(Time.get_ticks_msec())
			gs.scenario_state [
				"royal_first_frame_shell_truth_ready"
			] = true
			gs.scenario_state [
				"royal_first_frame_shell_player_title"
			] = str(player.royal_title)
			gs.scenario_state [
				"royal_first_frame_shell_succession_rank"
			] = int(player.succession_rank)

		return

	var house_origin:= _royal_house_origin(
		ruler,
		player
	)

	for member in house_members:
		if member == null:
			continue

		member.is_royal = true
		member.exiled = false
		member.deposed = false
		member.dynasty_origin = house_origin

		if (
			int(member.realm_id) <= 0
			and int(ruler.realm_id) > 0
		):
			member.realm_id = int(
				ruler.realm_id
			)

	ruler.is_ruler = true
	ruler.is_royal = true
	ruler.social_class = "Royal"
	ruler.deposed = false
	ruler.exiled = false
	ruler.palace_owned = true
	ruler.succession_rank = 0
	ruler.royal_title = _resolve_rank_title(
		ruler,
		"ruler"
	)
	ruler.approval = max(
		int(ruler.approval),
		72
	)

	if other_parent != null:
		other_parent.is_ruler = false
		other_parent.is_royal = true
		other_parent.social_class = "Royal"
		other_parent.deposed = false
		other_parent.exiled = false
		other_parent.palace_owned = true
		other_parent.realm_id = int(
			ruler.realm_id
		)
		other_parent.dynasty_origin = house_origin
		other_parent.royal_title = (
			_resolve_rank_title(
				other_parent,
				"consort"
			)
		)

	player.is_ruler = false
	player.is_royal = true
	player.deposed = false
	player.exiled = false
	player.palace_owned = true
	player.dynasty_origin = house_origin
	player.realm_id = int(
		ruler.realm_id
	)

	match normalized_rank_seed:
		"Heir Line":
			player.social_class = "Royal"
			player.succession_rank = 1
			player.royal_title = _resolve_rank_title(
				player,
				"heir"
			)

		"Royal Child":
			player.social_class = "Royal"
			player.succession_rank = 2
			player.royal_title = _resolve_rank_title(
				player,
				"royal_child"
			)

		"Ducal Line":
			player.social_class = "Noble"
			player.succession_rank = 4
			player.royal_title = _resolve_rank_title(
				player,
				"ducal_royal"
			)

		"Marcher Line":
			player.social_class = "Noble"
			player.succession_rank = 6
			player.royal_title = _resolve_rank_title(
				player,
				"marcher_royal"
			)

		_:
			player.social_class = "Noble"
			player.succession_rank = max(
				8,
				int(player.succession_rank)
			)
			player.royal_title = _resolve_rank_title(
				player,
				"lesser_royal"
			)

	_set_royal_rank_seed_trait(
		player,
		normalized_rank_seed
	)
	_sync_royal_job_identity(
		player
	)
	_sync_royal_job_identity(
		ruler
	)

	if other_parent != null:
		_sync_royal_job_identity(
			other_parent
		)

	_apply_custom_royal_approval_from_settings(
		player,
		settings
	)

	if (
		gs != null
		and typeof(gs.scenario_state)
		== TYPE_DICTIONARY
	):
		gs.scenario_state [
			"royal_house_heavy_bootstrap_deferred"
		] = true
		gs.scenario_state [
			"royal_house_heavy_bootstrap_deferred_player_id"
		] = int(player.id)
		gs.scenario_state [
			"royal_house_heavy_bootstrap_deferred_ruler_id"
		] = int(ruler.id)
		gs.scenario_state [
			"royal_house_heavy_bootstrap_deferred_rank_seed"
		] = normalized_rank_seed
		gs.scenario_state [
			"royal_house_heavy_bootstrap_deferred_reason"
		] = "first_frame_shell_fast_royal_truth"
		gs.scenario_state [
			"royal_house_heavy_bootstrap_deferred_at_ms"
		] = int(Time.get_ticks_msec())
		gs.scenario_state [
			"royal_first_frame_external_ruler_pending"
		] = false
		gs.scenario_state [
			"royal_first_frame_self_promotion_forbidden"
		] = true
		gs.scenario_state [
			"royal_first_frame_shell_truth_ready"
		] = true
		gs.scenario_state [
			"royal_first_frame_shell_player_title"
		] = str(player.royal_title)
		gs.scenario_state [
			"royal_first_frame_shell_succession_rank"
		] = int(player.succession_rank)
func _configured_bending_nation_for_royalty(player: Person, settings: Dictionary = {}) -> String:
	var contract_nation: String = _resolve_custom_royal_birth_nation(player, settings)
	if _is_elemental_royal_country_name(contract_nation):
		return contract_nation

	var selected_bending:= str(settings.get("bending_type", "none")).to_lower()
	var selected_country:= str(settings.get("country", "")).strip_edges()
	var elemental_nations:= ["Air Nomads", "Water Tribe", "Earth Kingdom", "Fire Nation"]

	if selected_bending == "avatar" and elemental_nations.has(selected_country):
		return selected_country

	if player != null:
		var birth_country:= str(player.birth_country).strip_edges()
		if selected_bending == "avatar" and elemental_nations.has(birth_country):
			return birth_country
		if str(player.bending_nation).strip_edges() != "":
			return str(player.bending_nation).strip_edges()

	match selected_bending:
		"air":
			return "Air Nomads"
		"water":
			return "Water Tribe"
		"earth":
			return "Earth Kingdom"
		"fire":
			return "Fire Nation"
		_:
			return ""

func apply_bending_royal_theme(player: Person, settings: Dictionary = {}) -> void:
	_apply_bending_royal_theme(player, settings)

func _apply_bending_royal_theme(
	player: Person,
	settings: Dictionary = {}
) -> void:
	if player == null:
		return

	var nation:= (
		_configured_bending_nation_for_royalty(
			player,
			settings
		)
	)

	if nation == "":
		return

	if not _royal_context_supports_bending_house_theme(
		player,
		nation,
		settings
	):
		if str(
			player.bending_nation
		).strip_edges() == "":
			player.bending_nation = nation

		return

	if _royal_runtime_heavy_work_deferred():




		var first_frame_members: Array = [
			player
		]

		if gs != null:
			for raw_parent_id in player.parents:
				var parent: Person = null
				var parent_id: int = int(
					raw_parent_id
				)

				if (
					parent_id > 0
					and gs.has_method(
						"get_npc_by_id"
					)
				):
					parent = gs.get_npc_by_id(
						parent_id
					)

				if (
					parent != null
					and not first_frame_members.has(
						parent
					)
				):
					first_frame_members.append(
						parent
					)

		_apply_custom_royal_birth_nation_to_house(
			first_frame_members,
			nation,
			settings
		)

		if (
			gs != null
			and typeof(gs.scenario_state) == TYPE_DICTIONARY
		):
			gs.scenario_state [
				"royal_bending_house_theme_deferred"
			] = true
			gs.scenario_state [
				"royal_bending_house_theme_nation"
			] = nation
			gs.scenario_state [
				"royal_bending_house_theme_actor_id"
			] = int(player.id)
			gs.scenario_state [
				"royal_bending_house_theme_first_frame_member_count"
			] = first_frame_members.size()
			gs.scenario_state [
				"royal_bending_house_theme_heavy_work_performed"
			] = false
			gs.scenario_state [
				"royal_bending_house_theme_ready_gate_member"
			] = false
			gs.scenario_state [
				"royal_house_heavy_bootstrap_deferred"
			] = true

		return

	var house_members: Array = (
		_house_members_for(
			player
		)
	)

	if house_members.is_empty():
		house_members = (
			_gather_player_house_members(
				player
			)
		)

	_apply_custom_royal_birth_nation_to_house(
		house_members,
		nation,
		settings
	)

	var ruler: Person = (
		_find_living_ruler_from_members(
			house_members
		)
	)

	if ruler == null:
		ruler = _pick_best_claimant(
			house_members
		)

	if ruler != null:
		_refresh_house_succession(
			ruler
		)
		_sync_house_royal_jobs(
			house_members
		)
func setup_seed_royal_house(npc: Person) -> void:
	if npc == null:
		return

	if npc.social_class != "Royal" and not npc.is_royal:
		return

	var defer_heavy_royal_bootstrap: bool = _royal_runtime_heavy_work_deferred()

	var already_has_crown_identity: bool = (
		bool(npc.is_ruler)
		or bool(npc.is_royal)
		or int(npc.succession_rank) > 0
		or str(npc.royal_title).strip_edges() != ""
	)

	if already_has_crown_identity and str(npc.royal_title).strip_edges() != "":
		_sync_royal_job_identity(npc)
		return

	if gs.class_engine != null:
		gs.class_engine.apply_family_class_seed(npc, "Royal")

	if defer_heavy_royal_bootstrap:
		var fast_house_members: Array = [npc]
		var fast_founder: Person = npc
		var fast_house_origin:= _royal_house_origin(fast_founder, npc)

		_stamp_royal_identity(npc, fast_founder, "lesser_royal", fast_house_origin)

		fast_founder.is_ruler = true
		fast_founder.is_royal = true
		fast_founder.deposed = false
		fast_founder.exiled = false
		fast_founder.succession_rank = 0
		fast_founder.royal_title = _resolve_rank_title(fast_founder, "ruler")
		fast_founder.approval = max(int(fast_founder.approval), 64)

		_sync_house_royal_jobs(fast_house_members, false)

		if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
			gs.scenario_state ["royal_house_heavy_bootstrap_deferred"] = true
			gs.scenario_state ["royal_house_heavy_bootstrap_deferred_player_id"] = int(npc.id)
			gs.scenario_state ["royal_house_heavy_bootstrap_deferred_ruler_id"] = int(fast_founder.id)
			gs.scenario_state ["royal_house_heavy_bootstrap_deferred_reason"] = "seed_royal_house_first_frame_shell_fast_path"
			gs.scenario_state ["royal_house_heavy_bootstrap_deferred_at_ms"] = int(Time.get_ticks_msec())
			gs.scenario_state ["royal_house_fast_prewarm_shell_identity_only"] = true
			gs.scenario_state ["royal_house_heavy_member_scan_forbidden_during_prewarm"] = true

		return

	var house_members:= _gather_player_house_members(npc)
	if house_members.is_empty():
		house_members = [npc]

	var founder: Person = _find_living_ruler_from_members(house_members)
	if founder == null and gs != null and gs.realm_engine != null and int(npc.realm_id) > 0 and gs.realm_engine.realms.has(int(npc.realm_id)):
		var realm_raw: Variant = gs.realm_engine.realms.get(int(npc.realm_id), {})
		var realm: Dictionary = realm_raw if typeof(realm_raw) == TYPE_DICTIONARY else {}
		var stored_ruler_id: int = int(realm.get("ruler_id", -1))
		if stored_ruler_id > 0:
			var stored_ruler: Person = gs.get_or_reactivate_npc_by_id(stored_ruler_id)
			if stored_ruler != null and stored_ruler.alive and _house_key(stored_ruler) == _house_key(npc):
				founder = stored_ruler

	if founder == null and bool(npc.is_ruler):
		founder = npc

	if founder == null:
		founder = _pick_best_claimant(house_members)

	if founder == null:
		founder = _oldest_person_in_list(house_members)

	if founder == null:
		founder = npc

	var house_origin:= _royal_house_origin(founder, npc)

	for member in house_members:
		_stamp_royal_identity(member, founder, "lesser_royal", house_origin)

	founder.is_ruler = true
	founder.is_royal = true
	founder.deposed = false
	founder.exiled = false
	founder.succession_rank = 0
	founder.royal_title = _resolve_rank_title(founder, "ruler")
	founder.approval = max(int(founder.approval), 64)

	_refresh_house_succession(founder)
	_sync_house_royal_jobs(house_members, true)
func yearly_tick(
	payload: Dictionary = {}
) -> void:
	if (
		gs != null
		and gs.royalty_runtime_engine != null
	):
		gs.royalty_runtime_engine.yearly_tick(
			payload
		)
		return



	run_legacy_yearly_tick(payload)
func marry_into_royalty(
	person: Person,
	partner: Person
) -> void:
	if person == null or partner == null:
		return

	if not partner.is_royal:
		return

	person.is_royal = true
	person.social_class = "Royal"
	person.realm_id = int(partner.realm_id)
	person.palace_owned = true
	person.dynasty_origin = _house_key(partner)
	person.royal_title = _resolve_rank_title(
		person,
		"consort"
	)
	person.succession_rank = max(
		int(person.succession_rank),
		99
	)
	person.approval = clamp(
		max(
			int(person.approval),
			45
		),
		0,
		100
	)

	_sync_royal_job_identity(person)
	_apply_royal_fame_floor(person)

	if (
		gs != null
		and gs.royalty_runtime_engine != null
	):
		gs.royalty_runtime_engine.ingest_actor(
			partner,
			{
				"source": (
					"royalty_engine.marry_into_royalty"
				),
				"silent": true
			}
		)
		gs.royalty_runtime_engine.ingest_actor(
			person,
			{
				"source": (
					"royalty_engine.marry_into_royalty"
				)
			}
		)
		gs.royalty_runtime_engine.repair_state({
			"source": (
				"royalty_engine.marry_into_royalty"
			)
		})
func _formal_royal_job_for(npc: Person) -> String:
	if npc == null:
		return ""
	if not npc.is_royal and not npc.is_ruler and int(npc.succession_rank) <= 0 and str(npc.royal_title).strip_edges() == "":
		return ""
	var title:= str(npc.royal_title).strip_edges()
	if title == "":
		if npc.is_ruler:
			title = _resolve_rank_title(npc, "ruler")
		elif int(npc.succession_rank) == 1:
			title = _resolve_rank_title(npc, "heir")
		elif npc.partner != null and npc.partner.is_ruler and not npc.deposed:
			title = _resolve_rank_title(npc, "consort")
		elif npc.deposed:
			title = "Former %s" % _resolve_rank_title(npc, "ruler")
		else:
			title = _resolve_rank_title(npc, "lesser_royal")
	return title

func _sync_royal_job_identity(npc: Person) -> void:
	if npc == null:
		return
	var formal_job:= _formal_royal_job_for(npc)
	if formal_job == "":
		return
	var current_job: String = str(npc.job).strip_edges()
	if current_job != "" and current_job != formal_job:
		var supplemental_jobs: Array = []
		if npc.has_meta("supplemental_jobs"):
			var supplemental_raw: Variant = npc.get_meta("supplemental_jobs")
			if typeof(supplemental_raw) == TYPE_ARRAY:
				supplemental_jobs = supplemental_raw.duplicate()
		if not supplemental_jobs.has(current_job):
			supplemental_jobs.append(current_job)
			npc.set_meta("supplemental_jobs", supplemental_jobs)
			npc.mental_health = clamp(float(npc.mental_health) - 2.0, 0.0, 100.0)
			npc.work_stress = min(100.0, float(npc.work_stress) + 4.0)
	npc.job = formal_job

func _sync_house_royal_jobs(house_members: Array, sync_court_faction: bool = true) -> void:
	var ruler: Person = _find_living_ruler_from_members(house_members)
	if ruler == null:
		ruler = _pick_best_claimant(house_members)

	for member in house_members:
		if member == null:
			continue
		_sync_royal_job_identity(member)

	if sync_court_faction:
		_sync_house_royal_court_faction(ruler, house_members)
func _sync_house_royal_court_faction(ruler: Person, house_members: Array) -> void:
	if gs == null or ruler == null:
		return
	var house_key: String = _house_key(ruler)
	if house_key == "":
		return

	var factions_raw: Variant = gs.scenario_state.get("royal_court_factions", {})
	var factions: Dictionary = factions_raw if typeof(factions_raw) == TYPE_DICTIONARY else {}

	var faction_id: String = "royal_court:%s" % house_key
	var faction_default: Dictionary = {
		"id": faction_id,
		"name": _royal_court_faction_name(ruler),
		"owner_id": int(ruler.id),
		"founder_id": int(ruler.id),
		"pursuit_kind": "royal_court",
		"court_kind": "royal_court",
		"house_key": house_key,
		"created_year": int(gs.year),
		"last_year_active": int(gs.year),
		"status": "active",
		"member_ids": {}
	}
	var faction_raw: Variant = factions.get(faction_id, faction_default)
	var faction: Dictionary = faction_raw if typeof(faction_raw) == TYPE_DICTIONARY else faction_default.duplicate(true)

	faction ["name"] = _royal_court_faction_name(ruler)
	faction ["owner_id"] = int(ruler.id)
	faction ["founder_id"] = int(faction.get("founder_id", int(ruler.id)))
	faction ["pursuit_kind"] = "royal_court"
	faction ["court_kind"] = "royal_court"
	faction ["house_key"] = house_key
	faction ["last_year_active"] = int(gs.year)
	faction ["status"] = "active"

	var existing_members_raw: Variant = faction.get("member_ids", {})
	var existing_members: Dictionary = existing_members_raw if typeof(existing_members_raw) == TYPE_DICTIONARY else {}
	var rebuilt_members: Dictionary = {}
	var court_roles: Dictionary = _build_royal_court_roles(ruler, house_members)

	for raw_member_id in court_roles.keys():
		var npc: Person = gs.get_or_reactivate_npc_by_id(int(raw_member_id))
		if npc == null or not npc.alive:
			continue
		_upsert_royal_court_member(
			rebuilt_members,
			existing_members,
			npc,
			str(court_roles.get(raw_member_id, "courtier")),
			true
		)

	faction ["member_ids"] = rebuilt_members
	faction ["member_count"] = _count_active_royal_court_members(rebuilt_members)
	factions [faction_id] = faction

	gs.scenario_state ["royal_court_factions"] = factions
	gs.scenario_state ["royal_court_membership_index"] = _rebuild_royal_court_membership_index(factions)


func _royal_court_faction_name(ruler: Person) -> String:
	if ruler == null:
		return "Royal Court"
	var house_label: String = str(ruler.last_name).strip_edges()
	if house_label == "":
		house_label = str(ruler.first_name).strip_edges()
	if house_label == "":
		house_label = "Royal"
	var nation_label: String = str(ruler.bending_nation).strip_edges()
	if nation_label == "":
		nation_label = str(ruler.birth_country).strip_edges()
	if nation_label == "":
		nation_label = "Realm"
	return "Court of House %s • %s" % [house_label, nation_label]


func _build_royal_court_roles(ruler: Person, house_members: Array) -> Dictionary:
	var roles: Dictionary = {}
	if ruler == null:
		return roles

	roles [int(ruler.id)] = "ruler"

	var eligible_members: Array = []
	for member in house_members:
		if member == null:
			continue
		if not member.alive:
			continue
		if member.exiled:
			continue
		if int(member.id) == int(ruler.id):
			continue
		eligible_members.append(member)

	var heir: Person = null
	for member in eligible_members:
		if int(member.succession_rank) != 1:
			continue
		if heir == null:
			heir = member
			continue
		if int(member.age) > int(heir.age):
			heir = member
		elif int(member.age) == int(heir.age) and int(member.id) < int(heir.id):
			heir = member
	if heir != null:
		roles [int(heir.id)] = "heir"

	var consort: Person = null
	if ruler.partner != null and ruler.partner.alive and not ruler.partner.exiled:
		consort = ruler.partner
	if consort != null and int(consort.id) != int(ruler.id):
		roles [int(consort.id)] = "consort"

	var taken: Dictionary = {}
	for raw_member_id in roles.keys():
		taken [int(raw_member_id)] = true

	var regent: Person = _best_royal_court_candidate(eligible_members, taken, "regent")
	if regent != null:
		roles [int(regent.id)] = "regent"
		taken [int(regent.id)] = true

	var advisor: Person = _best_royal_court_candidate(eligible_members, taken, "advisor")
	if advisor != null:
		roles [int(advisor.id)] = "advisor"
		taken [int(advisor.id)] = true

	var guard_captain: Person = _best_royal_court_candidate(eligible_members, taken, "guard_captain")
	if guard_captain != null:
		roles [int(guard_captain.id)] = "guard_captain"
		taken [int(guard_captain.id)] = true

	var spymaster: Person = _best_royal_court_candidate(eligible_members, taken, "spymaster")
	if spymaster != null:
		roles [int(spymaster.id)] = "spymaster"
		taken [int(spymaster.id)] = true

	var envoy: Person = _best_royal_court_candidate(eligible_members, taken, "envoy")
	if envoy != null:
		roles [int(envoy.id)] = "envoy"
		taken [int(envoy.id)] = true

	for member in eligible_members:
		if member == null:
			continue
		if taken.has(int(member.id)):
			continue
		roles [int(member.id)] = "courtier"

	return roles


func _best_royal_court_candidate(candidates: Array, taken: Dictionary, role: String) -> Person:
	var best: Person = null
	var best_score: int = -999999

	for member in candidates:
		if member == null:
			continue
		if not member.alive:
			continue
		if member.exiled:
			continue
		if int(member.age) < 16:
			continue
		if taken.has(int(member.id)):
			continue

		var score: int = 0
		match role:
			"regent":
				score = int(member.age) + int(member.smarts) + int(member.approval)
			"advisor":
				score = (int(member.smarts) * 2) + int(member.approval) + int(member.fame)
			"guard_captain":
				score = (int(member.health) * 2) + int(member.ambition) + int(member.fame)
			"spymaster":
				score = (int(member.smarts) * 2) + int(member.ambition) + max(0, 100 - int(member.approval))
			"envoy":
				score = int(member.fame) + int(member.looks) + int(member.smarts) + int(member.approval)
			_:
				score = int(member.smarts) + int(member.approval)

		if best == null or score > best_score:
			best = member
			best_score = score

	return best


func _upsert_royal_court_member(members: Dictionary, existing_members: Dictionary, npc: Person, role: String, active: bool) -> void:
	if npc == null:
		return
	var member_key: String = str(int(npc.id))
	var entry_raw: Variant = existing_members.get(member_key, {})
	var entry: Dictionary = entry_raw if typeof(entry_raw) == TYPE_DICTIONARY else {}
	entry ["npc_id"] = int(npc.id)
	entry ["role"] = role
	entry ["joined_year"] = int(entry.get("joined_year", gs.year))
	entry ["last_year_seen"] = int(gs.year)
	entry ["active"] = active
	members [member_key] = entry


func _count_active_royal_court_members(members: Dictionary) -> int:
	var count: int = 0
	for raw_key in members.keys():
		var entry_raw: Variant = members.get(raw_key, {})
		var entry: Dictionary = entry_raw if typeof(entry_raw) == TYPE_DICTIONARY else {}
		if bool(entry.get("active", true)):
			count += 1
	return count


func _rebuild_royal_court_membership_index(factions: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for raw_faction_id in factions.keys():
		var faction_raw: Variant = factions.get(raw_faction_id, {})
		var faction: Dictionary = faction_raw if typeof(faction_raw) == TYPE_DICTIONARY else {}
		var members_raw: Variant = faction.get("member_ids", {})
		var members: Dictionary = members_raw if typeof(members_raw) == TYPE_DICTIONARY else {}
		for raw_member_key in members.keys():
			var member_raw: Variant = members.get(raw_member_key, {})
			var member: Dictionary = member_raw if typeof(member_raw) == TYPE_DICTIONARY else {}
			var npc_key: String = str(int(member.get("npc_id", -1)))
			if npc_key == "-1":
				continue
			if not out.has(npc_key):
				out [npc_key] = {}
			out [npc_key] [str(raw_faction_id)] = {
				"owner_id": int(faction.get("owner_id", -1)),
				"faction_name": str(faction.get("name", "")),
				"role": str(member.get("role", "courtier")),
				"active": bool(member.get("active", true)),
				"status": str(faction.get("status", "active")),
				"joined_year": int(member.get("joined_year", gs.year)),
				"faction_type": "royal_court",
				"house_key": str(faction.get("house_key", ""))
			}
	return out
func _apply_seeded_ancestor_royal_variety(player: Person, ruler: Person, primary_parent: Person = null) -> void:
	if player == null or ruler == null:
		return
	var direct_line_parent: Person = primary_parent
	if direct_line_parent == null:
		for pid in player.parents:
			var candidate: Person = gs.get_npc_by_id(int(pid))
			if candidate == null:
				continue
			direct_line_parent = candidate
			if str(candidate.last_name) == str(player.last_name):
				direct_line_parent = candidate
				break
	var marked_former_grandparent:= false
	var marked_former_great_grandparent:= false
	var processed: Dictionary = {}
	for pid in player.parents:
		var parent: Person = gs.get_npc_by_id(int(pid))
		if parent == null:
			continue
		var is_direct_branch:= direct_line_parent != null and int(parent.id) == int(direct_line_parent.id)
		for gpid in parent.parents:
			var grandparent: Person = gs.get_npc_by_id(int(gpid))
			if grandparent == null:
				continue
			if processed.has(int(grandparent.id)):
				continue
			processed [int(grandparent.id)] = true
			grandparent.is_ruler = false
			if is_direct_branch and not marked_former_grandparent:
				grandparent.deposed = true
				grandparent.royal_title = "Former %s" % _resolve_rank_title(grandparent, "ruler")
				marked_former_grandparent = true
			else:
				grandparent.deposed = false
				grandparent.royal_title = _resolve_rank_title(grandparent, "lesser_royal")
			_sync_royal_job_identity(grandparent)
			for ggpid in grandparent.parents:
				var great_grandparent: Person = gs.get_npc_by_id(int(ggpid))
				if great_grandparent == null:
					continue
				if processed.has(int(great_grandparent.id)):
					continue
				processed [int(great_grandparent.id)] = true
				great_grandparent.is_ruler = false
				if is_direct_branch and not marked_former_great_grandparent:
					great_grandparent.deposed = true
					great_grandparent.royal_title = "Former %s" % _resolve_rank_title(great_grandparent, "ruler")
					marked_former_great_grandparent = true
				else:
					great_grandparent.deposed = false
					great_grandparent.royal_title = _resolve_rank_title(great_grandparent, "lesser_royal")
				_sync_royal_job_identity(great_grandparent)

func on_successful_coup(
	attacker: Person,
	defender: Person
) -> void:
	if attacker == null:
		return

	attacker.is_royal = true
	attacker.social_class = "Royal"
	attacker.is_ruler = true
	attacker.deposed = false
	attacker.exiled = false
	attacker.palace_owned = true
	attacker.royal_title = _resolve_rank_title(
		attacker,
		"ruler"
	)
	_apply_royal_fame_floor(attacker)

	if defender != null:
		defender.is_ruler = false
		defender.palace_owned = false

		if defender.alive and not defender.exiled:
			defender.deposed = true
			defender.royal_title = "Former %s" % (
				_resolve_rank_title(
					defender,
					"ruler"
				)
			)

	_sync_realm_ruler_from_royal_change(
		attacker,
		defender
	)
	_refresh_house_succession(attacker)

	if (
		gs != null
		and gs.royalty_runtime_engine != null
	):
		gs.royalty_runtime_engine.ingest_actor(
			attacker,
			{
				"source": (
					"royalty_engine.on_successful_coup"
				)
			}
		)

		if defender != null:
			gs.royalty_runtime_engine.ingest_actor(
				defender,
				{
					"source": (
						"royalty_engine.on_successful_coup"
					)
				}
			)

		gs.royalty_runtime_engine.repair_state({
			"source": (
				"royalty_engine.on_successful_coup"
			),
			"allow_legacy_mirror_repair": true
		})
func _sync_realm_ruler_from_royal_change(new_ruler: Person, previous_ruler: Person = null) -> void:
	if gs == null or gs.realm_engine == null or new_ruler == null:
		return

	var target_realm_id: int = -1
	if previous_ruler != null and int(previous_ruler.realm_id) > 0:
		target_realm_id = int(previous_ruler.realm_id)
	elif int(new_ruler.realm_id) > 0:
		target_realm_id = int(new_ruler.realm_id)

	if target_realm_id <= 0:
		var house_members:= _house_members_for(new_ruler)
		for member in house_members:
			if member == null:
				continue
			if int(member.realm_id) > 0:
				target_realm_id = int(member.realm_id)
				break

	if target_realm_id <= 0 or not gs.realm_engine.realms.has(target_realm_id):
		return

	var realm_raw: Variant = gs.realm_engine.realms.get(target_realm_id, {})
	var realm: Dictionary = realm_raw if typeof(realm_raw) == TYPE_DICTIONARY else {}
	if realm.is_empty():
		return

	var realm_previous_ruler_id: int = int(realm.get("ruler_id", -1))

	realm ["ruler_id"] = int(new_ruler.id)
	realm ["ruler_house_key"] = _house_key(new_ruler)
	gs.realm_engine.realms [target_realm_id] = realm

	new_ruler.realm_id = target_realm_id
	new_ruler.is_ruler = true
	new_ruler.is_royal = true
	new_ruler.social_class = "Royal"
	new_ruler.deposed = false
	new_ruler.exiled = false
	new_ruler.palace_owned = true
	new_ruler.succession_rank = 0
	new_ruler.royal_title = _resolve_rank_title(new_ruler, "ruler")

	if previous_ruler == null and realm_previous_ruler_id > 0:
		previous_ruler = gs.get_npc_by_id(realm_previous_ruler_id)
		if previous_ruler == null:
			previous_ruler = gs.get_or_reactivate_npc_by_id(realm_previous_ruler_id)

	if previous_ruler != null and int(previous_ruler.id) != int(new_ruler.id):
		previous_ruler.is_ruler = false
		previous_ruler.palace_owned = false
		if previous_ruler.is_royal:
			previous_ruler.deposed = true
			previous_ruler.royal_title = "Former %s" % _resolve_rank_title(previous_ruler, "ruler")

	for raw_npc in gs.npcs:
		var npc: Person = raw_npc
		if npc == null:
			continue
		if int(npc.id) == int(new_ruler.id):
			continue
		if int(npc.realm_id) != target_realm_id:
			continue
		if not bool(npc.is_ruler):
			continue

		npc.is_ruler = false
		npc.palace_owned = false
		if npc.is_royal:
			npc.deposed = true
			npc.royal_title = "Former %s" % _resolve_rank_title(npc, "ruler")

	if gs.realm_engine.has_method("sync_realm_ruler_from_person"):
		gs.realm_engine.sync_realm_ruler_from_person(new_ruler)
func perform_public_action(npc, action: String):
	match action:
		"donate":
			npc.approval = clamp(int(npc.approval) + 10, 0, 100)
			return "You donated generously. Approval increased."
		"host_games":
			npc.approval = clamp(int(npc.approval) + 15, 0, 100)
			return "Public games entertained the masses!"
		"reform":
			npc.approval = clamp(int(npc.approval) + 20, 0, 100)
			return "Reform improved your public image."
		"scandal":
			npc.approval = clamp(int(npc.approval) - 25, 0, 100)
			return "A scandal lowered your approval!"
		_:
			return "Nothing happened."

func _yearly_house_tick(anchor: Person) -> void:
	var house_members:= _house_members_for(anchor)
	if house_members.is_empty():
		return
	var previous_ruler: Person = _find_living_ruler_from_members(house_members)
	var ruler: Person = previous_ruler
	if ruler == null:
		ruler = _pick_best_claimant(house_members)
	if ruler != null:
		ruler.is_ruler = true
		ruler.deposed = false
		ruler.exiled = false
		ruler.palace_owned = true
		ruler.royal_title = _resolve_rank_title(ruler, "ruler")
	_sync_realm_ruler_from_royal_change(ruler, previous_ruler)
	if ruler != null and (previous_ruler == null or int(previous_ruler.id) != int(ruler.id)):
		_announce_succession(ruler, false)
	if ruler != null:
		_refresh_house_succession(ruler)
	var target_realm_id: int = -1
	if ruler != null and int(ruler.realm_id) > 0:
		target_realm_id = int(ruler.realm_id)
	if target_realm_id <= 0:
		for member in house_members:
			if member == null:
				continue
			if int(member.realm_id) > 0:
				target_realm_id = int(member.realm_id)
				break
	var realm: Dictionary = {}
	var treasury: int = 0
	var yearly_royal_pool: float = 0.0
	var eligible_members: Array = []
	if gs != null and gs.realm_engine != null and target_realm_id > 0 and gs.realm_engine.realms.has(target_realm_id):
		var realm_raw: Variant = gs.realm_engine.realms.get(target_realm_id, {})
		realm = realm_raw if typeof(realm_raw) == TYPE_DICTIONARY else {}
		if not realm.is_empty():
			treasury = int(realm.get("treasury", 0))
			yearly_royal_pool = max(float(house_members.size()) * 100000.0, float(treasury) * 0.05)
	for member in house_members:
		if member == null or not member.alive:
			continue
		if member.partner != null and not member.partner.is_royal:
			marry_into_royalty(member.partner, member)
		_tick_approval(member)
		_apply_royal_fame_floor(member)
		if bool(member.is_royal) or bool(member.is_ruler) or int(member.succession_rank) > 0 or str(member.royal_title).strip_edges() != "":
			eligible_members.append(member)
	if not realm.is_empty() and not eligible_members.is_empty():
		var weights: Dictionary = {}
		var total_weight: float = 0.0
		for member in eligible_members:
			var weight: float = 1.0
			if ruler != null and int(member.id) == int(ruler.id):
				weight = 8.0
			elif int(member.succession_rank) == 1:
				weight = 4.5
			elif member.partner != null and member.partner.is_ruler:
				weight = 3.5
			elif int(member.succession_rank) > 0 and int(member.succession_rank) <= 5:
				weight = 2.5
			elif int(member.succession_rank) > 0 and int(member.succession_rank) <= 12:
				weight = 1.75
			weights [int(member.id)] = weight
			total_weight += weight
		if total_weight <= 0.0:
			total_weight = 1.0
		var distributed_total: float = 0.0
		for member in eligible_members:
			var share_ratio: float = float(weights.get(int(member.id), 1.0)) / total_weight
			var stipend: float = yearly_royal_pool * share_ratio
			if ruler != null and int(member.id) == int(ruler.id):
				stipend = max(stipend, max(300000.0, float(treasury) * 0.02))
			elif int(member.succession_rank) == 1:
				stipend = max(stipend, 150000.0)
			else:
				stipend = max(stipend, 60000.0)
			member.income = max(float(member.income), stipend)
			member.bank_balance += stipend
			member.social_class = "Royal"
			distributed_total += stipend
		realm ["treasury"] = max(0, treasury - int(round(distributed_total)))
		gs.realm_engine.realms [target_realm_id] = realm
	if ruler != null and int(ruler.approval) <= 15:
		_maybe_stage_family_coup(ruler)

func _tick_approval(npc: Person) -> void:
	if npc == null or not npc.is_royal:
		return
	var drift_min:= -3
	var drift_max:= 3
	if npc.is_ruler:
		drift_min = -2
		drift_max = 2
	elif int(npc.succession_rank) == 1:
		drift_min = -1
		drift_max = 2
	npc.approval = clamp(int(npc.approval) + randi_range(drift_min, drift_max), 0, 100)

func _maybe_stage_family_coup(ruler: Person) -> void:
	if ruler == null or gs.politics_engine == null:
		return
	var challengers: Array = []
	for member in _house_members_for(ruler):
		if member == null:
			continue
		if not member.alive:
			continue
		if int(member.id) == int(ruler.id):
			continue
		if member.exiled:
			continue
		if int(member.age) < 16:
			continue
		challengers.append(member)
	if challengers.is_empty():
		return
	var ruler_dynasty_prestige: int = _dynasty_prestige_for_name(ruler.last_name)
	var best: Person = null
	var best_score:= -999999
	var best_dynasty_prestige: int = 0
	for challenger in challengers:
		var challenger_dynasty_prestige: int = _dynasty_prestige_for_name(challenger.last_name)
		var score:= int(challenger.smarts) + int(challenger.fame) + int(challenger.ambition)
		score += max(0, 100 - int(challenger.approval))
		score += max(0, 30 - (int(challenger.succession_rank) * 3))
		score += int(round(float(challenger_dynasty_prestige) * 0.08))
		score += int(round(float(max(0, int(challenger.fame) - int(ruler.fame))) * 0.35))
		score += int(round(float(max(0, int(challenger.approval) - int(ruler.approval))) * 0.45))
		score -= int(round(float(ruler_dynasty_prestige) * 0.05))
		if score > best_score:
			best_score = score
			best = challenger
			best_dynasty_prestige = challenger_dynasty_prestige
	if best == null:
		return
	var trigger_roll:= randi() % 100
	var ruler_stability: int = int(round(
		(float(int(ruler.approval)) * 0.55) +
		(float(int(ruler.fame)) * 0.2) +
		(float(ruler_dynasty_prestige) * 0.12)
	))
	var challenger_pressure: int = int(round(
		(float(int(best.fame)) * 0.28) +
		(float(int(best.approval)) * 0.18) +
		(float(best_dynasty_prestige) * 0.1)
	))
	var unrest_bonus: int = max(0, 35 - int(ruler.approval))
	var trigger_chance: int = int(clamp(
		18 + unrest_bonus + challenger_pressure - int(round(float(ruler_stability) * 0.35)),
		8,
		85
	))
	if trigger_roll >= trigger_chance:
		return
	gs.politics_engine.attempt_coup(best, ruler)
func _royal_succession_contract_for_ruler(ruler: Person) -> Dictionary:
	var realm_name: String = _royal_realm_name_for_person(ruler)
	return _royal_succession_contract_for_realm_name(realm_name)


func _royal_succession_contract_for_realm_name(realm_name: String) -> Dictionary:
	var clean_name: String = str(realm_name).strip_edges().to_lower()
	var contract_key: String = "default_monarchy"

	if clean_name.find("fire") != -1:
		contract_key = "fire_nation"
	elif clean_name.find("water") != -1:
		contract_key = "water_tribe"
	elif clean_name.find("earth") != -1:
		contract_key = "earth_kingdom"
	elif clean_name.find("air") != -1:
		contract_key = "air_nomads"

	var raw_contract: Variant = ROYAL_SUCCESSION_CONTRACTS.get(contract_key, ROYAL_SUCCESSION_CONTRACTS.get("default_monarchy", {}))
	if typeof(raw_contract) == TYPE_DICTIONARY:
		return (raw_contract as Dictionary).duplicate(true)

	return {}


func _royal_succession_anchor_above_heir(heir: Person, house_members: Array) -> Person:
	if heir == null:
		return null

	for pid in heir.parents:
		var parent: Person = gs.get_npc_by_id(int(pid))
		if parent == null:
			continue
		if not parent.alive:
			continue
		if parent.exiled:
			continue
		if not parent.is_royal and not parent.is_ruler and str(parent.royal_title).strip_edges() == "":
			continue
		if _normalize_royal_rank_seed(_royal_rank_seed_for_npc(parent)) == "Heir Line":
			continue
		return parent

	for raw_member in house_members:
		var member: Person = raw_member
		if member == null:
			continue
		if not member.alive:
			continue
		if member.exiled:
			continue
		if int(member.id) == int(heir.id):
			continue
		if bool(member.is_ruler) and _normalize_royal_rank_seed(_royal_rank_seed_for_npc(member)) != "Heir Line":
			return member

	var best: Person = null
	for raw_fallback in house_members:
		var fallback: Person = raw_fallback
		if fallback == null:
			continue
		if not fallback.alive:
			continue
		if fallback.exiled:
			continue
		if int(fallback.id) == int(heir.id):
			continue
		if _normalize_royal_rank_seed(_royal_rank_seed_for_npc(fallback)) == "Heir Line":
			continue
		if best == null:
			best = fallback
			continue
		if int(fallback.age) > int(best.age):
			best = fallback
		elif int(fallback.age) == int(best.age) and int(fallback.id) < int(best.id):
			best = fallback

	return best


func _royal_candidate_allowed_by_succession_contract(candidate: Person, contract: Dictionary) -> bool:
	if candidate == null:
		return false
	if not candidate.alive:
		return false
	if candidate.exiled:
		return false
	if candidate.deposed and not bool(contract.get("allow_deposed_claimants", false)):
		return false
	if not candidate.is_royal and not candidate.is_ruler and int(candidate.succession_rank) <= 0 and str(candidate.royal_title).strip_edges() == "":
		return false
	return true


func _royal_succession_order_for_contract(candidates: Array, ruler: Person, contract: Dictionary) -> Array:
	var remaining: Array = []
	for raw_candidate in candidates:
		var candidate: Person = raw_candidate
		if not _royal_candidate_allowed_by_succession_contract(candidate, contract):
			continue
		if ruler != null and int(candidate.id) == int(ruler.id):
			continue
		remaining.append(candidate)

	var ordered: Array = []
	while not remaining.is_empty():
		var best_index: int = -1
		var best_score: float = -999999999.0

		for i in range(remaining.size()):
			var candidate: Person = remaining [i]
			var score: float = _royal_succession_score(candidate, ruler, contract)
			if score > best_score:
				best_score = score
				best_index = i
			elif score == best_score and best_index >= 0:
				var current_best: Person = remaining [best_index]
				if int(candidate.age) > int(current_best.age):
					best_index = i
				elif int(candidate.age) == int(current_best.age) and int(candidate.id) < int(current_best.id):
					best_index = i

		if best_index < 0:
			break

		ordered.append(remaining [best_index])
		remaining.remove_at(best_index)

	return ordered


func _royal_succession_score(candidate: Person, ruler: Person, contract: Dictionary) -> float:
	if candidate == null:
		return -999999999.0

	var weights: Dictionary = {}
	var raw_weights: Variant = contract.get("weights", {})
	if typeof(raw_weights) == TYPE_DICTIONARY:
		weights = raw_weights as Dictionary

	var score: float = 0.0
	var candidate_seed: String = _normalize_royal_rank_seed(_royal_rank_seed_for_npc(candidate))
	if bool(contract.get("designated_heir_override", true)) and candidate_seed == "Heir Line":
		score += float(weights.get("designated_heir", 100000.0))

	if _royal_person_is_direct_child_of(candidate, ruler):
		score += float(weights.get("direct_child", 35000.0))
	elif _royal_person_is_descendant_of(candidate, ruler):
		score += float(weights.get("descendant", 18000.0))

	score += _royal_gender_priority_score(candidate, contract)
	score += float(candidate.age) * float(weights.get("age", 100.0))
	score += float(candidate.approval) * float(weights.get("approval", 1.0))
	score += float(candidate.fame) * float(weights.get("fame", 1.0))
	score += _royal_numeric_stat(candidate, "smarts", 50.0) * float(weights.get("smarts", 1.0))
	score += _royal_numeric_stat(candidate, "willpower", 50.0) * float(weights.get("willpower", 1.0))

	if str(contract.get("succession_mode", "")).strip_edges() == "spiritual_successor_selection":
		score -= _royal_numeric_stat(candidate, "ambition", 50.0) * float(weights.get("ambition_penalty", 0.0))

	score -= float(int(candidate.id)) * 0.001
	return score


func _royal_gender_priority_score(candidate: Person, contract: Dictionary) -> float:
	if candidate == null:
		return 0.0

	var priorities: Array = []
	var raw_priorities: Variant = contract.get("gender_priority", [])
	if typeof(raw_priorities) == TYPE_ARRAY:
		priorities = raw_priorities as Array

	if priorities.is_empty():
		return 0.0

	var gender_key: String = str(candidate.gender).strip_edges().to_lower()
	var weights: Dictionary = {}
	var raw_weights: Variant = contract.get("weights", {})
	if typeof(raw_weights) == TYPE_DICTIONARY:
		weights = raw_weights as Dictionary

	var base: float = float(weights.get("male_preference", 0.0))
	for i in range(priorities.size()):
		if gender_key == str(priorities [i]).strip_edges().to_lower():
			return max(0.0, base - (float(i) * max(1.0, base * 0.35)))

	return 0.0


func _royal_numeric_stat(candidate: Person, key: String, fallback: float = 0.0) -> float:
	if candidate == null:
		return fallback
	var value: Variant = candidate.get(key)
	if value == null:
		return fallback
	return float(value)


func _royal_person_is_direct_child_of(candidate: Person, parent: Person) -> bool:
	if candidate == null or parent == null:
		return false
	for pid in candidate.parents:
		if int(pid) == int(parent.id):
			return true
	return false


func _royal_person_is_descendant_of(candidate: Person, ancestor: Person) -> bool:
	if candidate == null or ancestor == null:
		return false

	var queue: Array = []
	for pid in candidate.parents:
		queue.append(int(pid))

	var seen: Dictionary = {}
	var guard: int = 0
	while not queue.is_empty() and guard < 48:
		var next_id: int = int(queue.pop_front())
		guard += 1

		if seen.has(next_id):
			continue
		seen [next_id] = true

		if next_id == int(ancestor.id):
			return true

		var parent: Person = gs.get_npc_by_id(next_id)
		if parent == null:
			continue

		for parent_id in parent.parents:
			queue.append(int(parent_id))

	return false


func _determine_contract_successor_child(parent: Person, contract: Dictionary) -> Person:
	if parent == null:
		return null

	var candidates: Array = []
	for child_id in parent.children:
		var child: Person = gs.get_npc_by_id(int(child_id))
		if not _royal_candidate_allowed_by_succession_contract(child, contract):
			continue
		candidates.append(child)

	var ordered: Array = _royal_succession_order_for_contract(candidates, parent, contract)
	if ordered.is_empty():
		return null

	return ordered [0]


func _collect_contract_direct_succession_line(ruler: Person, contract: Dictionary) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	var cursor: Person = ruler
	var guard:= 0

	while cursor != null and guard < 12:
		if seen.has(int(cursor.id)):
			break

		seen [int(cursor.id)] = true
		out.append(cursor)
		cursor = _determine_contract_successor_child(cursor, contract)
		guard += 1

	return out


func _resolve_contract_designated_heir(ruler: Person, house_members: Array, contract: Dictionary) -> Person:
	if ruler == null:
		return null
	if not bool(contract.get("designated_heir_override", true)):
		return null

	var candidates: Array = []
	for raw_member in house_members:
		var member: Person = raw_member
		if not _royal_candidate_allowed_by_succession_contract(member, contract):
			continue
		if int(member.id) == int(ruler.id):
			continue
		if _normalize_royal_rank_seed(_royal_rank_seed_for_npc(member)) != "Heir Line":
			continue
		candidates.append(member)

	if candidates.is_empty():
		return null

	var ordered: Array = _royal_succession_order_for_contract(candidates, ruler, contract)
	if ordered.is_empty():
		return null

	return ordered [0]


func _build_contract_succession_line(ruler: Person, house_members: Array, contract: Dictionary) -> Array:
	var out: Array = []
	if ruler == null:
		return out

	out.append(ruler)

	var designated_heir: Person = _resolve_contract_designated_heir(ruler, house_members, contract)
	if designated_heir != null:
		out.append(designated_heir)

		var seen: Dictionary = {
			int(ruler.id): true,
			int(designated_heir.id): true
		}
		var cursor: Person = _determine_contract_successor_child(designated_heir, contract)
		var guard: int = 0
		while cursor != null and guard < 10:
			if seen.has(int(cursor.id)):
				break
			seen [int(cursor.id)] = true
			out.append(cursor)
			cursor = _determine_contract_successor_child(cursor, contract)
			guard += 1

		return out

	if bool(contract.get("direct_line_first", true)):
		return _collect_contract_direct_succession_line(ruler, contract)

	var ordered: Array = _royal_succession_order_for_contract(house_members, ruler, contract)
	for raw_candidate in ordered:
		var candidate: Person = raw_candidate
		if candidate == null:
			continue
		if int(candidate.id) == int(ruler.id):
			continue
		out.append(candidate)

	return out
func _refresh_house_succession(ruler: Person) -> void:
	if ruler == null:
		return

	var house_members:= _house_members_for(ruler)
	if house_members.is_empty():
		return

	var ruler_seed:= _normalize_royal_rank_seed(_royal_rank_seed_for_npc(ruler))
	if ruler_seed == "Heir Line":
		var authority_anchor: Person = _royal_succession_anchor_above_heir(ruler, house_members)
		if authority_anchor != null:
			ruler = authority_anchor
			house_members = _house_members_for(ruler)
			if house_members.is_empty():
				return

	var succession_contract: Dictionary = _royal_succession_contract_for_ruler(ruler)
	var used_ids: Dictionary = {}

	for member in house_members:
		if member == null:
			continue

		member.is_ruler = false

		if member.exiled:
			continue

		member.succession_rank = 99

		if member.deposed:
			member.royal_title = "Former %s" % _resolve_rank_title(member, "ruler")
			continue

		var member_seed:= _normalize_royal_rank_seed(_royal_rank_seed_for_npc(member))
		match member_seed:
			"Ducal Line":
				member.royal_title = _resolve_rank_title(member, "ducal_royal")
			"Marcher Line":
				member.royal_title = _resolve_rank_title(member, "marcher_royal")
			"Royal Child":
				member.royal_title = _resolve_rank_title(member, "royal_child")
			"Heir Line":
				member.royal_title = _resolve_rank_title(member, "heir")
			_:
				member.royal_title = _resolve_rank_title(member, "lesser_royal")

	var direct_line: Array = _build_contract_succession_line(ruler, house_members, succession_contract)

	for i in range(direct_line.size()):
		var member: Person = direct_line [i]
		if member == null:
			continue

		used_ids [int(member.id)] = true
		member.deposed = false
		member.is_royal = true
		member.social_class = "Royal"
		member.palace_owned = true

		var member_seed:= _normalize_royal_rank_seed(_royal_rank_seed_for_npc(member))

		if i == 0:
			member.is_ruler = true
			member.succession_rank = 0
			member.royal_title = _resolve_rank_title(member, "ruler")
		elif member_seed == "Heir Line":
			member.is_ruler = false
			member.succession_rank = 1
			member.royal_title = _resolve_rank_title(member, "heir")
		elif member_seed == "Royal Child":
			member.is_ruler = false
			member.succession_rank = max(2, i)
			member.royal_title = _resolve_rank_title(member, "royal_child")
		elif member_seed == "Ducal Line":
			member.is_ruler = false
			member.succession_rank = max(4, i)
			member.royal_title = _resolve_rank_title(member, "ducal_royal")
		elif member_seed == "Marcher Line":
			member.is_ruler = false
			member.succession_rank = max(6, i)
			member.royal_title = _resolve_rank_title(member, "marcher_royal")
		elif i == 1:
			member.is_ruler = false
			member.succession_rank = 1
			member.royal_title = _resolve_rank_title(member, "heir")
		else:
			member.is_ruler = false
			member.succession_rank = i
			member.royal_title = _resolve_rank_title(member, "royal_child")

		_apply_royal_fame_floor(member)

	var fallback_rank:= 10
	for member in house_members:
		if member == null:
			continue
		if used_ids.has(int(member.id)):
			continue

		var member_seed:= _normalize_royal_rank_seed(_royal_rank_seed_for_npc(member))
		var assigned_rank:= fallback_rank

		if member.deposed:
			assigned_rank += 40

		if member.partner != null and member.partner.is_ruler and not member.deposed:
			member.is_ruler = false
			member.royal_title = _resolve_rank_title(member, "consort")
			member.succession_rank = 50
		elif member.deposed:
			member.is_ruler = false
			member.royal_title = "Former %s" % _resolve_rank_title(member, "ruler")
			member.succession_rank = assigned_rank
		else:
			member.is_ruler = false
			match member_seed:
				"Heir Line":
					member.succession_rank = 1
					member.royal_title = _resolve_rank_title(member, "heir")
				"Royal Child":
					member.succession_rank = max(2, assigned_rank)
					member.royal_title = _resolve_rank_title(member, "royal_child")
				"Ducal Line":
					member.succession_rank = max(4, assigned_rank)
					member.royal_title = _resolve_rank_title(member, "ducal_royal")
				"Marcher Line":
					member.succession_rank = max(6, assigned_rank)
					member.royal_title = _resolve_rank_title(member, "marcher_royal")
				_:
					member.succession_rank = assigned_rank
					member.royal_title = _resolve_rank_title(member, "lesser_royal")

		fallback_rank += 1
		_apply_royal_fame_floor(member)

	if gs != null and gs.realm_engine != null and gs.realm_engine.has_method("sync_realm_ruler_from_person"):
		var active_ruler: Person = null
		for member in direct_line:
			if member == null:
				continue
			if member.alive and member.is_ruler:
				active_ruler = member
				break

		if active_ruler != null:
			gs.realm_engine.sync_realm_ruler_from_person(active_ruler)


func _apply_seeded_rank_bias(npc: Person) -> void:
	if npc == null or not npc.is_royal or npc.is_ruler:
		return

	var rank_seed:= _normalize_royal_rank_seed(_royal_rank_seed_for_npc(npc))
	match rank_seed:
		"Heir Line":
			npc.succession_rank = min(int(npc.succession_rank), 1)
			npc.royal_title = _resolve_rank_title(npc, "heir")
		"Royal Child":
			npc.succession_rank = max(int(npc.succession_rank), 2)
			npc.royal_title = _resolve_rank_title(npc, "royal_child")
		"Ducal Line":
			npc.succession_rank = max(int(npc.succession_rank), 4)
			npc.royal_title = _resolve_rank_title(npc, "ducal_royal")
		"Marcher Line":
			npc.succession_rank = max(int(npc.succession_rank), 6)
			npc.royal_title = _resolve_rank_title(npc, "marcher_royal")
		_:
			return

	_apply_royal_fame_floor(npc)

func _collect_direct_succession_line(ruler: Person) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	var cursor: Person = ruler
	var guard:= 0
	while cursor != null and guard < 12:
		if seen.has(int(cursor.id)):
			break
		seen [int(cursor.id)] = true
		out.append(cursor)
		cursor = _determine_firstborn_child(cursor)
		guard += 1
	return out
func _dynasty_prestige_for_name(last_name: String) -> int:
	if gs == null or gs.dynasty_engine == null:
		return 0
	var dynasty_name:= str(last_name).strip_edges()
	if dynasty_name == "":
		return 0
	if not gs.dynasty_engine.dynasties.has(dynasty_name):
		return 0
	var raw_dynasty: Variant = gs.dynasty_engine.dynasties [dynasty_name]
	if typeof(raw_dynasty) != TYPE_DICTIONARY:
		return 0
	return int((raw_dynasty as Dictionary).get("prestige", 0))
func _determine_firstborn_child(parent: Person) -> Person:
	if parent == null:
		return null

	var best: Person = null
	for child_id in parent.children:
		var child: Person = gs.get_npc_by_id(int(child_id))
		if child == null:
			continue
		if not child.alive:
			continue
		if not child.is_royal:
			continue
		if child.exiled:
			continue

		if best == null:
			best = child
			continue

		var child_seed:= _royal_rank_seed_for_npc(child)
		var best_seed:= _royal_rank_seed_for_npc(best)

		if child_seed == "Heir Line" and best_seed != "Heir Line":
			best = child
			continue
		elif best_seed == "Heir Line" and child_seed != "Heir Line":
			continue

		if int(child.age) > int(best.age):
			best = child
		elif int(child.age) == int(best.age) and int(child.id) < int(best.id):
			best = child

	return best

func _pick_best_claimant(house_members: Array) -> Person:
	var best: Person = null
	for member in house_members:
		if member == null:
			continue
		if not member.alive:
			continue
		if member.exiled:
			continue
		if best == null:
			best = member
			continue
		if int(member.succession_rank) < int(best.succession_rank):
			best = member
		elif int(member.succession_rank) == int(best.succession_rank) and int(member.age) > int(best.age):
			best = member
	return best

func _find_living_ruler_from_members(house_members: Array) -> Person:
	for member in house_members:
		if member == null:
			continue
		if member.alive and member.is_ruler and not member.exiled:
			return member
	return null

func _house_members_for(anchor: Person) -> Array:
	var out: Array = []
	var house_key:= _house_key(anchor)
	if house_key == "":
		return out
	for npc in gs.npcs:
		if npc == null:
			continue
		if not npc.is_royal:
			continue
		if _house_key(npc) == house_key:
			out.append(npc)
	return out

func _house_key(npc: Person) -> String:
	if npc == null:
		return ""
	var explicit_house:= str(npc.dynasty_origin).strip_edges()
	if explicit_house.begins_with("royal_house:"):
		return explicit_house
	var last_name:= str(npc.last_name).strip_edges()
	var realm_id:= int(npc.realm_id)
	if last_name == "":
		last_name = "House"
	if realm_id > 0:
		return "royal_house:%s:%d" % [last_name, realm_id]
	return "royal_house:%s:%s" % [last_name, str(npc.home_country).strip_edges()]
func _resolve_custom_royal_birth_realm_id(player: Person, settings: Dictionary = {}) -> int:
	if player == null:
		return -1

	var country_name: String = _resolve_custom_royal_birth_nation(player, settings)

	if country_name == "":
		country_name = str(settings.get("country", "")).strip_edges()
	if country_name == "":
		country_name = str(player.home_country).strip_edges()
	if country_name == "":
		country_name = str(player.birth_country).strip_edges()

	var city_name: String = str(settings.get("city", "")).strip_edges()
	if city_name == "":
		city_name = str(player.home_city).strip_edges()
	if city_name == "":
		city_name = str(player.birth_city).strip_edges()

	if country_name == "":
		return -1

	if gs != null and gs.realm_engine != null and gs.realm_engine.has_method("ensure_realm_for_country"):
		return int(gs.realm_engine.ensure_realm_for_country(country_name, city_name))

	if int(player.realm_id) > 0:
		return int(player.realm_id)

	return -1
func _royal_house_origin(anchor: Person, fallback: Person = null) -> String:
	if anchor != null:
		return _house_key(anchor)
	if fallback != null:
		return _house_key(fallback)
	return "royal_house:Unknown:0"

func _stamp_royal_identity(member: Person, anchor: Person, default_rank: String, house_origin: String) -> void:
	if member == null:
		return

	member.is_royal = true
	member.social_class = "Royal"
	member.palace_owned = true
	member.dynasty_origin = house_origin

	if anchor != null and int(anchor.realm_id) > 0:
		member.realm_id = int(anchor.realm_id)

	member.approval = clamp(max(int(member.approval), 45), 0, 100)

	if str(member.royal_title).strip_edges() == "":
		member.royal_title = _resolve_rank_title(member, default_rank)

	if int(member.succession_rank) <= 0 and not member.is_ruler:
		member.succession_rank = 99

	_apply_royal_fame_floor(member)
	_sync_royal_job_identity(member)

func _gather_player_house_members(player: Person) -> Array:
	var out: Array = []
	var seen: Dictionary = {}

	if player == null:
		return out

	_append_unique_person(out, seen, player)

	if player.partner != null:
		_append_unique_person(out, seen, gs.get_or_reactivate_npc_by_id(int(player.partner.id)))

	for child_id in player.children:
		_append_unique_person(out, seen, gs.get_or_reactivate_npc_by_id(int(child_id)))

	for pid in player.parents:
		var parent: Person = gs.get_or_reactivate_npc_by_id(int(pid))
		if parent == null:
			continue

		_append_unique_person(out, seen, parent)

		if parent.partner != null:
			_append_unique_person(out, seen, gs.get_or_reactivate_npc_by_id(int(parent.partner.id)))

		for sid in parent.children:
			_append_unique_person(out, seen, gs.get_or_reactivate_npc_by_id(int(sid)))

		for gpid in parent.parents:
			var grandparent: Person = gs.get_or_reactivate_npc_by_id(int(gpid))
			if grandparent == null:
				continue

			_append_unique_person(out, seen, grandparent)

			if grandparent.partner != null:
				_append_unique_person(out, seen, gs.get_or_reactivate_npc_by_id(int(grandparent.partner.id)))

			for ggpid in grandparent.parents:
				_append_unique_person(out, seen, gs.get_or_reactivate_npc_by_id(int(ggpid)))

	return out

func _append_unique_person(out: Array, seen: Dictionary, person: Person) -> void:
	if person == null:
		return
	var pid:= int(person.id)
	if pid <= 0:
		return
	if seen.has(pid):
		return
	seen [pid] = true
	out.append(person)

func _pick_throne_founder_for_player(player: Person) -> Person:
	if player == null:
		return null
	var preferred_parent: Person = null
	for pid in player.parents:
		var parent: Person = gs.get_npc_by_id(int(pid))
		if parent == null:
			continue
		if str(parent.last_name) == str(player.last_name):
			preferred_parent = parent
			break
		if preferred_parent == null:
			preferred_parent = parent
	if preferred_parent == null:
		return null
	for gpid in preferred_parent.parents:
		var grandparent: Person = gs.get_npc_by_id(int(gpid))
		if grandparent == null:
			continue
		for ggpid in grandparent.parents:
			var great_grandparent: Person = gs.get_npc_by_id(int(ggpid))
			if great_grandparent != null:
				return great_grandparent
		return grandparent
	return preferred_parent

func _oldest_person_in_list(people: Array) -> Person:
	var best: Person = null
	for person in people:
		if person == null:
			continue
		if best == null:
			best = person
			continue
		if int(person.age) > int(best.age):
			best = person
		elif int(person.age) == int(best.age) and int(person.id) < int(best.id):
			best = person
	return best

func _resolve_rank_title(npc: Person, rank_key: String) -> String:
	if npc == null:
		return ""

	var style_key: String = _royal_style_for_person(npc)
	var style: Dictionary = ROYAL_TITLE_STYLES.get(style_key, ROYAL_TITLE_STYLES ["kingdom"])
	var gender_key: String = "female" if str(npc.gender).to_lower() == "female" else "male"
	var resolved_rank_key: String = str(rank_key).strip_edges()

	if resolved_rank_key == "lesser_royal":
		var rank_seed: String = _normalize_royal_rank_seed(_royal_rank_seed_for_npc(npc))
		match rank_seed:
			"Marcher Line":
				resolved_rank_key = "marcher_royal"
			"Ducal Line":
				resolved_rank_key = "ducal_royal"

	var lookup_key: String = "%s_%s" % [resolved_rank_key, gender_key]
	if style.has(lookup_key):
		return _title_case_royal_title(str(style.get(lookup_key, "Royal")))

	if resolved_rank_key == "ducal_royal":
		var fallback_ducal_key: String = "lesser_royal_%s" % gender_key
		return _title_case_royal_title(str(style.get(fallback_ducal_key, "Duke" if gender_key == "male" else "Duchess")))

	if resolved_rank_key == "marcher_royal":
		return _title_case_royal_title("Marquess" if gender_key == "male" else "Marchioness")

	return _title_case_royal_title(str(style.get(lookup_key, "Royal")))
func _title_case_royal_title(title_text: String) -> String:
	var text:= str(title_text).strip_edges()
	if text == "":
		return ""
	var words: PackedStringArray = text.split(" ", false)
	var titled_words: Array = []
	for raw_word in words:
		var word:= str(raw_word).strip_edges()
		if word == "":
			continue
		titled_words.append(word.substr(0, 1).to_upper() + word.substr(1).to_lower())
	return " ".join(titled_words)

func _royal_title_with_definite_article(title_text: String) -> String:
	var clean_title:= _title_case_royal_title(title_text)
	if clean_title == "":
		return "The Royal Child"
	return "The %s" % clean_title
func _elemental_royal_country_names() -> Array:
	return ["Air Nomads", "Water Tribe", "Earth Kingdom", "Fire Nation"]


func _is_elemental_royal_country_name(country_name: String) -> bool:
	return _elemental_royal_country_names().has(str(country_name).strip_edges())


func _royal_realm_name_for_person(npc: Person) -> String:
	if npc == null:
		return ""

	var realm_id:= int(npc.realm_id)
	if realm_id <= 0:
		return ""

	if gs == null or gs.realm_engine == null:
		return ""

	if typeof(gs.realm_engine.realms) != TYPE_DICTIONARY:
		return ""

	if not gs.realm_engine.realms.has(realm_id):
		return ""

	var realm_raw: Variant = gs.realm_engine.realms.get(realm_id, {})
	var realm: Dictionary = realm_raw if typeof(realm_raw) == TYPE_DICTIONARY else {}

	return str(realm.get("name", "")).strip_edges()


func _royal_person_should_use_bending_title_style(npc: Person) -> bool:
	if npc == null:
		return false

	var bending_nation:= str(npc.bending_nation).strip_edges()
	if bending_nation == "":
		return false

	if not _is_elemental_royal_country_name(bending_nation):
		return false

	if npc.is_royal or npc.is_ruler or int(npc.succession_rank) > 0:
		return true

	if str(npc.home_country).strip_edges() == bending_nation:
		return true

	if str(npc.birth_country).strip_edges() == bending_nation:
		return true

	if _royal_realm_name_for_person(npc) == bending_nation:
		return true

	return false

func _royal_context_supports_bending_house_theme(player: Person, nation: String, settings: Dictionary = {}) -> bool:
	if player == null:
		return false

	var clean_nation:= str(nation).strip_edges()
	if clean_nation == "":
		return false

	if _resolve_custom_royal_birth_nation(player, settings) == clean_nation:
		return true

	var birth_contract: Dictionary = _custom_royal_birth_origin_contract(settings)
	if not birth_contract.is_empty():
		var nation_contract: Dictionary = _custom_royal_birth_contract_section(settings, "nation_contract")
		if bool(nation_contract.get("use_elemental_title_style", false)) and str(nation_contract.get("royal_nation", "")).strip_edges() == clean_nation:
			return true

	var selected_country:= str(settings.get("country", "")).strip_edges()
	if selected_country == "":
		selected_country = str(player.home_country).strip_edges()
	if selected_country == "":
		selected_country = str(player.birth_country).strip_edges()

	if selected_country == clean_nation:
		return true

	if _royal_realm_name_for_person(player) == clean_nation:
		return true

	if player.is_royal and _is_elemental_royal_country_name(clean_nation):
		return true

	return false
func _royal_style_for_person(npc: Person) -> String:
	if npc == null:
		return "kingdom"

	if _royal_person_should_use_bending_title_style(npc):
		match str(npc.bending_nation).strip_edges():
			"Air Nomads":
				return "air_nomads"
			"Water Tribe":
				return "water_tribe"
			"Earth Kingdom":
				return "earth_kingdom"
			"Fire Nation":
				return "fire_nation"

	var era_key:= ""
	if gs != null and gs.era != null:
		var era_name:= str(gs.era.name).to_lower()
		if era_name.find("future") != -1:
			era_key = "Future"

	return _royal_style_key_for_location(str(npc.home_country).strip_edges(), era_key)
func _normalize_royal_rank_seed(rank_seed: String) -> String:
	var text:= str(rank_seed).strip_edges()
	if text == "" or text in ["Auto Royal Rank", "AutoRoyal Rank"]:
		return ""

	if text == "Lesser Royal":
		return "Ducal Line"

	if text in ["Heir Line", "Royal Child", "Ducal Line", "Marcher Line"]:
		return text

	var lowered:= text.to_lower()
	if lowered.find("heir") != -1 or lowered.find("crown") != -1:
		return "Heir Line"

	if lowered.find("marquess") != -1 \
or lowered.find("marchioness") != -1 \
or lowered.find("marcher") != -1 \
or lowered.find("march") != -1:
		return "Marcher Line"

	if lowered.find("lesser") != -1 \
or lowered.find("duke") != -1 \
or lowered.find("duchess") != -1 \
or lowered.find("high noble") != -1 \
or lowered.find("lord") != -1 \
or lowered.find("lady") != -1:
		return "Ducal Line"

	if lowered.find("prince") != -1 or lowered.find("princess") != -1:
		return "Royal Child"

	return text

func _royal_style_key_for_location(country_name: String, era_key: String = "") -> String:
	var text:= str(country_name).strip_edges()
	var lowered:= text.to_lower()

	if text == "Air Nomads":
		return "air_nomads"
	if text == "Water Tribe":
		return "water_tribe"
	if text == "Earth Kingdom":
		return "earth_kingdom"
	if text == "Fire Nation":
		return "fire_nation"

	if str(era_key).to_lower() == "future" and lowered.find("empire") == -1:
		return "future"

	if lowered.find("egypt") != -1:
		return "pharaonic"
	if lowered.find("japan") != -1:
		return "empire"
	if lowered.find("empire") != -1 \
or lowered.find("rome") != -1 \
or lowered.find("roman") != -1 \
or lowered.find("persia") != -1:
		return "empire"
	if lowered.find("uk") != -1 \
or lowered.find("britain") != -1 \
or lowered.find("england") != -1 \
or lowered.find("france") != -1 \
or lowered.find("spain") != -1:
		return "court_nobility"

	return "kingdom"

func get_spawnable_royal_rank_options(country_name: String = "", era_key: String = "") -> Array:
	var style_key:= _royal_style_key_for_location(country_name, era_key)
	var style: Dictionary = ROYAL_TITLE_STYLES.get(style_key, ROYAL_TITLE_STYLES ["kingdom"])

	var royal_child_male:= str(style.get("royal_child_male", "Prince"))
	var royal_child_female:= str(style.get("royal_child_female", "Princess"))
	var heir_male:= str(style.get("heir_male", "Crown Prince"))
	var heir_female:= str(style.get("heir_female", "Crown Princess"))
	var ducal_male:= str(style.get("ducal_royal_male", style.get("lesser_royal_male", "Duke")))
	var ducal_female:= str(style.get("ducal_royal_female", style.get("lesser_royal_female", "Duchess")))
	var marcher_male:= str(style.get("marcher_royal_male", "Marquess"))
	var marcher_female:= str(style.get("marcher_royal_female", "Marchioness"))

	return [
		{
			"seed": "Royal Child",
			"label": "%s / %s" % [royal_child_male, royal_child_female]
		},
		{
			"seed": "Heir Line",
			"label": "%s / %s" % [heir_male, heir_female]
		},
		{
			"seed": "Ducal Line",
			"label": "%s / %s" % [ducal_male, ducal_female]
		},
		{
			"seed": "Marcher Line",
			"label": "%s / %s" % [marcher_male, marcher_female]
		}
	]

func _direct_line_ancestors_for_player(player: Person) -> Array:
	var out: Array = []
	if player == null:
		return out

	var current: Person = player
	var seen: Dictionary = {}

	for _i in range(3):
		var preferred_parent: Person = null
		for pid in current.parents:
			var parent: Person = gs.get_npc_by_id(int(pid))
			if parent == null:
				continue
			if preferred_parent == null:
				preferred_parent = parent
			if str(parent.last_name) == str(current.last_name):
				preferred_parent = parent
				break

		if preferred_parent == null:
			break

		var parent_id:= int(preferred_parent.id)
		if parent_id <= 0 or seen.has(parent_id):
			break

		seen [parent_id] = true
		out.append(preferred_parent)
		current = preferred_parent

	return out

func _apply_custom_player_rank_seed_hierarchy(
	player: Person,
	ruler: Person,
	primary_parent: Person = null,
	rank_seed: String = "Royal Child"
) -> void:
	if player == null or ruler == null:
		return

	var normalized_rank_seed:= _normalize_royal_rank_seed(
		rank_seed
	)

	if normalized_rank_seed == "":
		normalized_rank_seed = "Royal Child"

	var lineage: Array = (
		_direct_line_ancestors_for_player_from_parent(
			player,
			primary_parent
		)
	)

	if lineage.is_empty():
		lineage = _direct_line_ancestors_for_player(
			player
		)

	var direct_parent: Person = primary_parent

	if (
		direct_parent == null
		and lineage.size() > 0
	):
		direct_parent = lineage [0]

	var direct_grandparent: Person = (
		lineage [1]
		if lineage.size() > 1
		else null
	)
	var direct_great_grandparent: Person = (
		lineage [2]
		if lineage.size() > 2
		else null
	)
	var direct_parent_is_ruler: bool = (
		direct_parent != null
		and int(direct_parent.id) == int(
			ruler.id
		)
	)

	player.deposed = false
	player.exiled = false
	player.is_ruler = false
	player.is_royal = true
	player.social_class = "Royal"
	player.palace_owned = true
	player.realm_id = int(
		ruler.realm_id
	)

	match normalized_rank_seed:
		"Heir Line":
			player.succession_rank = 1
			player.royal_title = _resolve_rank_title(
				player,
				"heir"
			)

		"Royal Child":
			player.succession_rank = 2
			player.royal_title = _resolve_rank_title(
				player,
				"royal_child"
			)

		"Ducal Line":
			player.succession_rank = 4
			player.royal_title = _resolve_rank_title(
				player,
				"ducal_royal"
			)

		"Marcher Line":
			player.succession_rank = 6
			player.royal_title = _resolve_rank_title(
				player,
				"marcher_royal"
			)

	if (
		direct_parent != null
		and int(direct_parent.id) != int(
			ruler.id
		)
	):
		direct_parent.is_ruler = false
		direct_parent.is_royal = true
		direct_parent.social_class = "Royal"
		direct_parent.realm_id = int(
			ruler.realm_id
		)
		direct_parent.deposed = false
		direct_parent.exiled = false
		direct_parent.palace_owned = true

		match normalized_rank_seed:
			"Heir Line", "Royal Child":
				direct_parent.royal_title = (
					_resolve_rank_title(
						direct_parent,
						"consort"
					)
				)

			"Ducal Line":
				direct_parent.succession_rank = 1
				direct_parent.royal_title = (
					_resolve_rank_title(
						direct_parent,
						"heir"
					)
				)
				_set_royal_rank_seed_trait(
					direct_parent,
					"Heir Line"
				)

			"Marcher Line":
				direct_parent.succession_rank = 3
				direct_parent.royal_title = (
					_resolve_rank_title(
						direct_parent,
						"ducal_royal"
					)
				)
				_set_royal_rank_seed_trait(
					direct_parent,
					"Ducal Line"
				)

	if (
		direct_grandparent != null
		and int(direct_grandparent.id) != int(
			ruler.id
		)
	):
		direct_grandparent.is_ruler = false
		direct_grandparent.is_royal = true
		direct_grandparent.social_class = "Royal"
		direct_grandparent.realm_id = int(
			ruler.realm_id
		)
		direct_grandparent.exiled = false
		direct_grandparent.palace_owned = true

		match normalized_rank_seed:
			"Heir Line", "Royal Child":
				if direct_parent_is_ruler:




					direct_grandparent.deposed = true
					direct_grandparent.succession_rank = 99
					direct_grandparent.royal_title = (
						"Former %s"
						% _resolve_rank_title(
							direct_grandparent,
							"ruler"
						)
					)
				else:
					direct_grandparent.deposed = false
					direct_grandparent.succession_rank = max(
						int(
							direct_grandparent.succession_rank
						),
						3
					)
					direct_grandparent.royal_title = (
						_resolve_rank_title(
							direct_grandparent,
							"lesser_royal"
						)
					)

			"Ducal Line":
				direct_grandparent.deposed = false
				direct_grandparent.succession_rank = 0
				direct_grandparent.royal_title = (
					_resolve_rank_title(
						direct_grandparent,
						"ruler"
					)
				)

			"Marcher Line":
				direct_grandparent.deposed = false
				direct_grandparent.succession_rank = 1
				direct_grandparent.royal_title = (
					_resolve_rank_title(
						direct_grandparent,
						"heir"
					)
				)
				_set_royal_rank_seed_trait(
					direct_grandparent,
					"Heir Line"
				)

	if (
		direct_great_grandparent != null
		and int(direct_great_grandparent.id)
		!= int(ruler.id)
	):
		direct_great_grandparent.is_ruler = false
		direct_great_grandparent.is_royal = true
		direct_great_grandparent.social_class = "Royal"
		direct_great_grandparent.realm_id = int(
			ruler.realm_id
		)
		direct_great_grandparent.exiled = false
		direct_great_grandparent.palace_owned = true

		if (
			direct_parent_is_ruler
			and normalized_rank_seed in [
				"Heir Line",
				"Royal Child"
			]
		):



			direct_great_grandparent.deposed = true
			direct_great_grandparent.succession_rank = 99
			direct_great_grandparent.royal_title = (
				"Former %s"
				% _resolve_rank_title(
					direct_great_grandparent,
					"ruler"
				)
			)
		else:
			direct_great_grandparent.deposed = true
			direct_great_grandparent.royal_title = (
				"Former %s"
				% _resolve_rank_title(
					direct_great_grandparent,
					"ruler"
				)
			)

	for subject in [
		player,
		direct_parent,
		direct_grandparent,
		direct_great_grandparent
	]:
		if subject == null:
			continue

		_sync_royal_job_identity(
			subject
		)
		_apply_royal_fame_floor(
			subject
		)
func _apply_royal_fame_floor(npc: Person) -> void:
	if npc == null or (not npc.is_royal and not npc.is_ruler):
		return
	var fame_floor:= 24
	if npc.is_ruler:
		fame_floor = 80
	elif int(npc.succession_rank) == 1:
		fame_floor = 68
	elif int(npc.succession_rank) == 2:
		fame_floor = 58
	elif int(npc.succession_rank) <= 5:
		fame_floor = 42

	var rank_seed:= _royal_rank_seed_for_npc(npc)
	if rank_seed == "Lesser Royal":
		fame_floor = min(fame_floor, 30)
	elif rank_seed == "Royal Child":
		fame_floor = max(fame_floor, 42)

	var realm_bonus:= 0
	if gs != null and gs.realm_engine != null and gs.realm_engine.has_method("get_realm_power_snapshot") and int(npc.realm_id) > 0:
		var realm_power: Dictionary = gs.realm_engine.get_realm_power_snapshot(int(npc.realm_id))
		if not realm_power.is_empty():
			var population: float = float(realm_power.get("population", 0.0))
			var land: float = float(realm_power.get("land", 0.0))
			var military_strength: float = float(realm_power.get("military_strength_score", 0.0))
			var economic_strength: float = float(realm_power.get("economic_strength_score", 0.0))
			var realm_might: float = 0.0
			realm_might += min(10.0, population / 1000000.0)
			realm_might += min(4.0, land / 250000.0)
			realm_might += min(10.0, military_strength / 5000.0)
			realm_might += min(10.0, economic_strength / 2500.0)
			if npc.is_ruler:
				realm_bonus = int(round(clamp(realm_might, 0.0, 20.0)))
			elif int(npc.succession_rank) > 0 and int(npc.succession_rank) <= 5:
				realm_bonus = int(round(clamp(realm_might * 0.5, 0.0, 10.0)))
			else:
				realm_bonus = int(round(clamp(realm_might * 0.25, 0.0, 6.0)))

	fame_floor += realm_bonus
	npc.fame = clamp(max(int(npc.fame), fame_floor), 0, 100)
	if str(npc.fame_job).strip_edges() == "" and int(npc.fame) >= 10:
		npc.fame_job = "Royal Family"
	if gs.fame_engine != null and gs.fame_engine.has_method("_update_fame_tier"):
		gs.fame_engine._update_fame_tier(npc)

func _append_birth_memory_if_missing(npc: Person) -> void:
	if npc == null:
		return
	var memory_text:= get_royal_birth_memory(npc)
	for raw_memory in npc.memories:
		if str(raw_memory).findn(memory_text) != -1:
			return
	npc.memories.append(memory_text)
func get_royal_birth_memory(npc: Person) -> String:
	if npc == null:
		return "\n👑\n A royal child entered the world under strange and ceremonial circumstances."


	var house_name: String = _royal_house_display_name(npc).strip_edges()
	if house_name == "":
		house_name = "the Crown"
	var city_name: String = str(npc.birth_city if str(npc.birth_city).strip_edges() != "" else npc.home_city).strip_edges()
	if city_name == "":
		city_name = "the capital"
	var title_name: String = str(npc.royal_title).strip_edges()
	if title_name == "":
		title_name = "Royal Child"
	title_name = _title_case_royal_title(title_name)
	var titled_reference:= _royal_title_with_definite_article(title_name)
	var templates: Array = [
		" 👑 The bells of %s nearly wore themselves out the day I arrived as %s of %s." % [city_name, titled_reference, house_name],
		" Half of %s claimed the sky changed color when I was born as %s of %s." % [city_name, titled_reference, house_name],
		" By sunset, the gossip in %s had already crowned my crib the loudest room in %s." % [city_name, house_name],
		" The palace musicians in %s swore every trumpet hit the right note the minute I arrived as %s of %s." % [city_name, titled_reference, house_name],
		" The market in %s stopped haggling for an hour just to argue about my royal cheeks." % [city_name],
		" 👑 The cooks of %s said the ovens bowed respectfully when %s of %s entered the world." % [city_name, titled_reference, house_name],
		" The guards in %s doubled their posture and tripled the rumors when I was born as %s of %s." % [city_name, titled_reference, house_name],
		" Somewhere between a royal omen and a neighborhood spectacle, %s decided my birth was the only event worth discussing." % [city_name],
		" The city of %s reacted like a festival had broken out when %s of %s was born." % [city_name, titled_reference, house_name],
		" Even the pigeons over %s seemed nosier than usual the morning %s of %s arrived." % [city_name, titled_reference, house_name],
		" The palace staff in %s started taking sides over which ancestor I looked like before I could even blink." % [city_name],
		" By dinner, %s had already turned my birth into three prophecies, seven arguments, and one suspiciously expensive toast." % [city_name]
	]
	var seed_value: int = abs(int(npc.id)) + max(0, int(npc.realm_id)) + (title_name.length() * 3) + (house_name.length() * 5) + (city_name.length() * 7)
	return templates [seed_value % max(1, templates.size())]

func _royal_house_display_name(npc: Person) -> String:
	if npc == null:
		return "the Crown"
	if npc.is_royal and str(npc.bending_nation).strip_edges() != "":
		return str(npc.bending_nation)
	if str(npc.home_country).strip_edges() != "":
		return str(npc.home_country)
	if gs.realm_engine != null and gs.realm_engine.realms.has(int(npc.realm_id)):
		var raw_realm: Variant = gs.realm_engine.realms [int(npc.realm_id)]
		if typeof(raw_realm) == TYPE_DICTIONARY:
			return str((raw_realm as Dictionary).get("name", "the Crown"))
	return "the Crown"

func _announce_succession(new_ruler: Person, initial_setup: bool) -> void:
	if new_ruler == null:
		return
	var text:= ""
	if initial_setup:
		text = "👑 %s %s now anchors the throne of %s." % [
			str(new_ruler.royal_title),
			new_ruler.last_name,
			_royal_house_display_name(new_ruler)
		]
	else:
		text = "👑 %s %s inherited the throne of %s." % [
			str(new_ruler.royal_title),
			new_ruler.last_name,
			_royal_house_display_name(new_ruler)
		]
	gs.push_world_feed(
		text,
		{
			"npc_id": new_ruler.id,
			"personally_relevant": new_ruler == gs.player,
			"category": "politics",
			"event_name": "royal_succession",
			"source": "royalty_engine"
		}
	)
	if gs.event_bus != null:
		gs.event_bus.emit(ActionEventTypes.DYNASTY_SHIFT, {
			"npc_id": new_ruler.id,
			"text": text
		})

func _set_royal_rank_seed_trait(npc: Person, rank_seed: String) -> void:
	if npc == null:
		return
	for i in range(npc.traits.size() - 1, -1, -1):
		var raw_trait:= str(npc.traits [i])
		if raw_trait.begins_with("RoyalRankSeed:"):
			npc.traits.remove_at(i)
	if rank_seed == "" or rank_seed == "Auto Royal Rank":
		return
	npc.traits.append("RoyalRankSeed:%s" % rank_seed)
func clear_royal_identity(npc: Person) -> void:
	if npc == null:
		return

	npc.is_ruler = false
	npc.is_royal = false
	npc.deposed = false
	npc.exiled = false
	npc.palace_owned = false
	npc.royal_title = ""
	npc.succession_rank = 0


func clear_custom_player_house_royal_identity(player: Person) -> void:
	if player == null:
		return

	var house_members:= _gather_player_house_members(player)
	if house_members.is_empty():
		house_members = [player]

	for member in house_members:
		clear_royal_identity(member)


func setup_custom_player_solo_crown_identity(player: Person, settings: Dictionary = {}) -> void:
	if player == null:
		return

	var requested_class:= str(settings.get("social_class", "")).strip_edges()
	var rank_seed:= _normalize_royal_rank_seed(str(settings.get("royal_rank", "")))

	if requested_class == "Noble":
		rank_seed = "Lesser Royal"
	elif rank_seed == "":
		rank_seed = "Royal Child"

	player.is_ruler = false
	player.is_royal = true
	player.deposed = false
	player.exiled = false
	player.palace_owned = requested_class == "Royal"

	match rank_seed:
		"Heir Line":
			player.social_class = "Royal"
			player.succession_rank = 1
			player.royal_title = _resolve_rank_title(player, "heir")
		"Royal Child":
			player.social_class = "Royal"
			player.succession_rank = 3
			player.royal_title = _resolve_rank_title(player, "royal_child")
		_:
			player.social_class = "Noble"
			player.succession_rank = 8
			player.royal_title = _resolve_rank_title(player, "lesser_royal")
			rank_seed = "Lesser Royal"

	_set_royal_rank_seed_trait(player, rank_seed)
	_sync_royal_job_identity(player)
	_apply_royal_fame_floor(player)
	_apply_custom_royal_approval_from_settings(player, settings)

func setup_custom_player_noble_lineage(player: Person, _settings: Dictionary = {}) -> void:
	if player == null:
		return

	var house_members:= _gather_player_house_members(player)
	if house_members.is_empty():
		house_members = [player]

	var house_origin:= _royal_house_origin(player, player)
	var player_realm_id:= int(player.realm_id)

	for member in house_members:
		if member == null:
			continue

		member.is_ruler = false
		member.is_royal = true
		member.deposed = false
		member.exiled = false
		member.palace_owned = false
		member.social_class = "Noble"
		member.realm_id = player_realm_id
		member.dynasty_origin = house_origin
		member.succession_rank = max(int(member.succession_rank), 8)
		member.royal_title = _resolve_rank_title(member, "lesser_royal")
		_set_royal_rank_seed_trait(member, "Lesser Royal")
		_sync_royal_job_identity(member)
		_apply_royal_fame_floor(member)
func _royal_rank_seed_for_npc(npc: Person) -> String:
	if npc == null:
		return ""
	for raw_trait in npc.traits:
		var trait_text:= str(raw_trait)
		if trait_text.begins_with("RoyalRankSeed:"):
			return trait_text.trim_prefix("RoyalRankSeed:")
	return ""