extends Resource
class_name LineageEngine

const CONTRACT_SCHEMA:= "eralife.lineage_engine"
const CONTRACT_VERSION:= 1

const DEFAULT_PRESSURE_KEYS:= [
	"integrity",
	"corruption",
	"trauma",
	"wealth",
	"faction_tension",
	"supernatural_affinity",
	"public_attention",
	"family_pressure"
]

var gs
var active_contract: Dictionary = {}
var lineage_registry: Dictionary = {}
var last_report: Dictionary = {}

func _init(_gs = null):
	gs = _gs
	active_contract = _build_default_contract()

func reset_runtime() -> void:
	lineage_registry.clear()
	last_report.clear()

func set_contract(contract: Dictionary = {}) -> Dictionary:
	if typeof(contract) == TYPE_DICTIONARY and not contract.is_empty():
		active_contract = _merge_dict(_build_default_contract(), contract)
	else:
		active_contract = _build_default_contract()
	return {
		"schema": "eralife.lineage_contract_set_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"contract_id": str(active_contract.get("id", "")),
		"set_at_ms": int(Time.get_ticks_msec())
	}

func export_state() -> Dictionary:
	return {
		"schema": "eralife.lineage_engine_state",
		"version": CONTRACT_VERSION,
		"active_contract": active_contract.duplicate(true),
		"lineage_registry": lineage_registry.duplicate(true),
		"last_report": last_report.duplicate(true),
		"exported_at_ms": int(Time.get_ticks_msec())
	}

func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "LineageEngine import data must be a Dictionary."
		}
	var contract_raw: Variant = data.get("active_contract", {})
	if typeof(contract_raw) == TYPE_DICTIONARY:
		active_contract = (contract_raw as Dictionary).duplicate(true)
	var registry_raw: Variant = data.get("lineage_registry", {})
	if typeof(registry_raw) == TYPE_DICTIONARY:
		lineage_registry = (registry_raw as Dictionary).duplicate(true)
	var report_raw: Variant = data.get("last_report", {})
	if typeof(report_raw) == TYPE_DICTIONARY:
		last_report = (report_raw as Dictionary).duplicate(true)
	return {
		"success": true,
		"lineage_count": lineage_registry.size(),
		"imported_at_ms": int(Time.get_ticks_msec())
	}

func begin_narrative_lineage(story: Dictionary, state: Dictionary = {}) -> Dictionary:
	var story_id: String = str(story.get("id", state.get("current_story_id", "story"))).strip_edges()
	if story_id == "":
		story_id = "story"
	var lineage_id: String = str(state.get("lineage_id", "")).strip_edges()
	if lineage_id == "":
		lineage_id = _short_id("lineage", "%s.%d.%d" % [story_id, int(Time.get_ticks_msec()), randi()])
	var ancestor_name: String = str(story.get("ancestor_name", story.get("protagonist_name", ""))).strip_edges()
	if ancestor_name == "":
		ancestor_name = _ancestor_name_from_story(story)
	var reservoir: Dictionary = {}
	for key in DEFAULT_PRESSURE_KEYS:
		reservoir [key] = 0.0
	var lineage:= {
		"schema": "eralife.lineage_contract",
		"version": CONTRACT_VERSION,
		"lineage_id": lineage_id,
		"story_id": story_id,
		"story_title": str(story.get("title", story_id)),
		"ancestor_name": ancestor_name,
		"ancestor_role": str(story.get("ancestor_role", "ancestor")),
		"pressure_reservoir": reservoir,
		"memory_packets": [],
		"birth_contract": {},
		"created_at_ms": int(Time.get_ticks_msec())
	}
	lineage_registry [lineage_id] = lineage
	last_report = {
		"schema": "eralife.lineage_begin_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"lineage_id": lineage_id,
		"story_id": story_id,
		"created_at_ms": int(Time.get_ticks_msec())
	}
	return lineage.duplicate(true)

func absorb_narrative_choice(context: Dictionary) -> Dictionary:
	var state_raw: Variant = context.get("state", {})
	var state: Dictionary = state_raw.duplicate(true) if typeof(state_raw) == TYPE_DICTIONARY else {}
	var lineage_id: String = str(state.get("lineage_id", "")).strip_edges()
	if lineage_id == "":
		return {}
	if not lineage_registry.has(lineage_id):
		lineage_registry [lineage_id] = begin_narrative_lineage({
			"id": str(state.get("current_story_id", "story")),
			"title": str(state.get("current_story_id", "Story"))
		}, state)
	var lineage: Dictionary = lineage_registry.get(lineage_id, {}).duplicate(true)
	var reservoir_raw: Variant = lineage.get("pressure_reservoir", {})
	var reservoir: Dictionary = reservoir_raw.duplicate(true) if typeof(reservoir_raw) == TYPE_DICTIONARY else {}
	var pressure_raw: Variant = context.get("pressure", {})
	var pressure: Dictionary = pressure_raw.duplicate(true) if typeof(pressure_raw) == TYPE_DICTIONARY else {}
	for raw_key in pressure.keys():
		var key: String = str(raw_key)
		reservoir [key] = float(reservoir.get(key, 0.0)) + float(pressure.get(raw_key, 0.0))
	lineage ["pressure_reservoir"] = reservoir
	var packet: Dictionary = build_narrative_memory_packet(lineage, context)
	var packets_raw: Variant = lineage.get("memory_packets", [])
	var packets: Array = packets_raw.duplicate(true) if typeof(packets_raw) == TYPE_ARRAY else []
	if not packet.is_empty():
		packets.append(packet)
	lineage ["memory_packets"] = packets
	lineage_registry [lineage_id] = lineage
	last_report = {
		"schema": "eralife.lineage_absorb_choice_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"lineage_id": lineage_id,
		"pressure": pressure.duplicate(true),
		"packet": packet.duplicate(true),
		"absorbed_at_ms": int(Time.get_ticks_msec())
	}
	return last_report.duplicate(true)

func build_narrative_memory_packet(lineage: Dictionary, context: Dictionary) -> Dictionary:
	var choice_raw: Variant = context.get("choice", {})
	var node_raw: Variant = context.get("node", {})
	var choice: Dictionary = choice_raw.duplicate(true) if typeof(choice_raw) == TYPE_DICTIONARY else {}
	var node: Dictionary = node_raw.duplicate(true) if typeof(node_raw) == TYPE_DICTIONARY else {}
	var label: String = str(choice.get("label", choice.get("id", "made a choice"))).strip_edges()
	var story_title: String = str(lineage.get("story_title", "the family story")).strip_edges()
	var ancestor_name: String = str(lineage.get("ancestor_name", "someone before me")).strip_edges()
	var node_title: String = str(node.get("panel_title", node.get("id", "a turning point"))).strip_edges()
	var text:= "In my family, people still talk about %s during %s. At %s, they chose: %s." % [
		ancestor_name,
		story_title,
		node_title,
		label
	]
	var pressure_raw: Variant = context.get("pressure", {})
	var pressure: Dictionary = pressure_raw.duplicate(true) if typeof(pressure_raw) == TYPE_DICTIONARY else {}
	var emotional_weight: float = clamp(_pressure_total(pressure) / 40.0, 0.1, 1.0)
	return {
		"schema": "eralife.narrative_memory_packet",
		"version": 1,
		"type": "narrative_memory",
		"origin": "ancestor_choice",
		"lineage_id": str(lineage.get("lineage_id", "")),
		"generation": int(context.get("generation", 0)),
		"text": text,
		"tags": ["ancestor_event", "family_history", str(context.get("story_id", ""))],
		"emotional_weight": emotional_weight,
		"truth_level": 0.82,
		"visibility": "family_only",
		"propagation_mode": "lineage",
		"age_range": [0, 80],
		"decay_rate": 0.02,
		"pressure": pressure.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec())
	}

func build_birth_bias_from_reservoir(state: Dictionary, base_bias: Dictionary = {}) -> Dictionary:
	var lineage_id: String = str(state.get("lineage_id", "")).strip_edges()
	var lineage: Dictionary = lineage_registry.get(lineage_id, {}).duplicate(true) if lineage_registry.has(lineage_id) else {}
	var reservoir_raw: Variant = lineage.get("pressure_reservoir", {})
	var reservoir: Dictionary = reservoir_raw.duplicate(true) if typeof(reservoir_raw) == TYPE_DICTIONARY else {}
	var out: Dictionary = base_bias.duplicate(true)
	var integrity: float = float(reservoir.get("integrity", out.get("integrity", 0.0)))
	var corruption: float = float(reservoir.get("corruption", out.get("corruption", 0.0)))
	var trauma: float = float(reservoir.get("trauma", out.get("trauma", 0.0)))
	var wealth: float = float(reservoir.get("wealth", out.get("wealth", 0.0)))
	var faction_tension: float = float(reservoir.get("faction_tension", out.get("faction_tension", 0.0)))
	var supernatural_affinity: float = float(reservoir.get("supernatural_affinity", out.get("supernatural_affinity", 0.0)))
	var social_class: String = str(out.get("social_class", "Random / Era Default"))
	if wealth >= 40.0 and corruption < 40.0:
		social_class = "Upper"
	elif wealth >= 40.0 and corruption >= 40.0:
		social_class = "Noble"
	elif trauma >= 45.0 and wealth < 25.0:
		social_class = "Poor"
	var birth_contract:= {
		"schema": "eralife.lineage_birth_contract",
		"version": CONTRACT_VERSION,
		"lineage_id": lineage_id,
		"story_id": str(lineage.get("story_id", state.get("current_story_id", ""))),
		"story_title": str(lineage.get("story_title", "")),
		"ancestor_name": str(lineage.get("ancestor_name", "")),
		"ancestor_role": str(lineage.get("ancestor_role", "ancestor")),
		"pressure_reservoir": reservoir.duplicate(true),
		"memory_packets": lineage.get("memory_packets", []).duplicate(true) if typeof(lineage.get("memory_packets", [])) == TYPE_ARRAY else [],
		"birth_conditions": {
			"social_class": social_class,
			"starting_money": int(max(0.0, wealth) * 125.0),
			"family_trauma_seed": trauma,
			"faction_pressure_seed": faction_tension,
			"moral_alignment_seed": integrity - corruption,
			"supernatural_affinity": supernatural_affinity,
			"bending_type": _resolve_lineage_bending_type(lineage, reservoir)
		},
		"created_at_ms": int(Time.get_ticks_msec())
	}
	lineage ["birth_contract"] = birth_contract.duplicate(true)
	if lineage_id != "":
		lineage_registry [lineage_id] = lineage
	out ["lineage_id"] = lineage_id
	out ["lineage_birth_contract"] = birth_contract.duplicate(true)
	out ["choose_adventure_lineage_birth"] = true
	out ["social_class"] = social_class
	out ["starting_money"] = int(max(0.0, wealth) * 125.0)
	out ["world_pressure"] = {
		"integrity": integrity,
		"corruption": corruption,
		"trauma": trauma,
		"wealth": wealth,
		"faction_tension": faction_tension,
		"supernatural_affinity": supernatural_affinity
	}
	out ["faction_pressure_seed"] = faction_tension
	out ["family_trauma_seed"] = trauma
	out ["moral_alignment_seed"] = integrity - corruption
	out ["bending_type"] = str(birth_contract.get("birth_conditions", {}).get("bending_type", "none"))
	return out

func create_player_from_lineage_contract(player: Person, settings: Dictionary) -> Person:
	if player == null:
		return null
	var contract_raw: Variant = settings.get("lineage_birth_contract", settings.get("narrative_birth_bias", {}).get("lineage_birth_contract", {}))
	if typeof(contract_raw) != TYPE_DICTIONARY or (contract_raw as Dictionary).is_empty():
		return null
	var contract: Dictionary = (contract_raw as Dictionary).duplicate(true)
	var conditions_raw: Variant = contract.get("birth_conditions", {})
	var conditions: Dictionary = conditions_raw.duplicate(true) if typeof(conditions_raw) == TYPE_DICTIONARY else {}
	var family_name: String = str(settings.get("last_name", player.last_name)).strip_edges()
	if family_name == "":
		family_name = _surname_from_ancestor(str(contract.get("ancestor_name", "Era")))
	player.last_name = family_name
	player.social_class = str(conditions.get("social_class", settings.get("social_class", player.social_class)))
	player.bank_balance = float(conditions.get("starting_money", settings.get("bank_balance", player.bank_balance)))
	player.traits = _lineage_traits_from_contract(contract, player.traits)
	var mother: Person = _create_lineage_parent("Female", player, contract)
	var father: Person = _create_lineage_parent("Male", player, contract)
	if mother == null or father == null:
		return null
	mother.last_name = family_name
	father.last_name = family_name
	mother.maiden_last_name = mother.last_name
	mother.partner = father
	father.partner = mother
	mother.marital_status = "Married"
	father.marital_status = "Married"
	player.parents = [father.id, mother.id]
	if player.id not in father.children:
		father.children.append(player.id)
	if player.id not in mother.children:
		mother.children.append(player.id)
	_register_family_member(father)
	_register_family_member(mother)
	if gs.npc_factory != null:
		gs.npc_factory.ensure_parent_lineage(mother, mother.maiden_last_name)
		gs.npc_factory.ensure_parent_lineage(father, father.last_name)
	if gs.class_engine != null:
		gs.class_engine.apply_family_class_seed(player, player.social_class)
	if gs.career_engine != null:
		gs.career_engine.reseed_household_jobs_for_class(player)
	_apply_contract_memories_to_family(player, [father, mother], contract)
	_apply_lineage_bending_birth(player, [father, mother], contract, settings)
	if gs.geo_engine != null:
		gs.geo_engine.bootstrap_person_place(player, {
			"source": "lineage_birth_contract"
		})
	return player

func apply_birth_contract_to_existing_child(child: Person, contract: Dictionary) -> void:
	if child == null or typeof(contract) != TYPE_DICTIONARY or contract.is_empty():
		return
	var conditions_raw: Variant = contract.get("birth_conditions", {})
	var conditions: Dictionary = conditions_raw.duplicate(true) if typeof(conditions_raw) == TYPE_DICTIONARY else {}
	child.social_class = str(conditions.get("social_class", child.social_class))
	child.bank_balance = max(float(child.bank_balance), float(conditions.get("starting_money", 0.0)))
	child.traits = _lineage_traits_from_contract(contract, child.traits)
	_apply_contract_memories_to_family(child, [], contract)
	_apply_lineage_bending_birth(child, [], contract, {})

func build_afterlife_prebirth_adventure(anchor: Person, slot: Dictionary) -> Dictionary:
	var anchor_name: String = "your descendant"
	if anchor != null:
		anchor_name = ("%s %s" % [anchor.first_name, anchor.last_name]).strip_edges()
	var lineage_id: String = str(slot.get("lineage_id", "")).strip_edges()
	if lineage_id == "":
		lineage_id = _short_id("afterlife_lineage", "%s.%d" % [anchor_name, int(Time.get_ticks_msec())])
	var options:= [
		"Leave them courage before you return",
		"Leave them ambition before you return",
		"Leave them a warning before you return"
	]
	return {
		"type": "afterlife_prebirth_lineage_adventure",
		"lineage_id": lineage_id,
		"text": "Before you are born through this family, you hover near %s one last time.\n\nThis is not full life yet. This is the final ancestor-pressure scene before reincarnation locks in." % anchor_name,
		"opps": options,
		"lookup": {
			options [0]: {
				"pressure": { "integrity": 8, "trauma": -2, "family_pressure": 4},
				"memory_text": "Before I was born, someone in my bloodline chose courage over fear."
			},
			options [1]: {
				"pressure": { "wealth": 6, "corruption": 2, "family_pressure": 5},
				"memory_text": "Before I was born, ambition was already moving through my family."
			},
			options [2]: {
				"pressure": { "trauma": 5, "integrity": 4, "faction_tension": 3},
				"memory_text": "Before I was born, my family carried a warning no one could fully explain."
			}
		}
	}

func apply_afterlife_prebirth_choice(slot: Dictionary, picked: Dictionary, anchor: Person) -> Dictionary:
	var lineage_id: String = str(slot.get("lineage_id", "")).strip_edges()
	if lineage_id == "":
		lineage_id = _short_id("afterlife_lineage", "%d.%d" % [int(anchor.id) if anchor != null else 0, int(Time.get_ticks_msec())])
	slot ["lineage_id"] = lineage_id
	var lineage: Dictionary = lineage_registry.get(lineage_id, {})
	if lineage.is_empty():
		lineage = {
			"schema": "eralife.lineage_contract",
			"version": CONTRACT_VERSION,
			"lineage_id": lineage_id,
			"story_id": "afterlife_reincarnation",
			"story_title": "Afterlife Reincarnation",
			"ancestor_name": str(gs.afterlife_state.get("ghost_name", "An old spirit")) if gs != null else "An old spirit",
			"ancestor_role": "reincarnating_ancestor",
			"pressure_reservoir": {},
			"memory_packets": [],
			"birth_contract": {},
			"created_at_ms": int(Time.get_ticks_msec())
		}
	var pressure_raw: Variant = picked.get("pressure", {})
	var pressure: Dictionary = pressure_raw.duplicate(true) if typeof(pressure_raw) == TYPE_DICTIONARY else {}
	var reservoir_raw: Variant = lineage.get("pressure_reservoir", {})
	var reservoir: Dictionary = reservoir_raw.duplicate(true) if typeof(reservoir_raw) == TYPE_DICTIONARY else {}
	for raw_key in pressure.keys():
		var key: String = str(raw_key)
		reservoir [key] = float(reservoir.get(key, 0.0)) + float(pressure.get(raw_key, 0.0))
	lineage ["pressure_reservoir"] = reservoir
	var packet:= {
		"schema": "eralife.narrative_memory_packet",
		"version": 1,
		"type": "narrative_memory",
		"origin": "afterlife_prebirth_choice",
		"lineage_id": lineage_id,
		"generation": 0,
		"text": str(picked.get("memory_text", "Something ancient moved through my family before I was born.")),
		"tags": ["afterlife", "ancestor_event", "family_history"],
		"emotional_weight": 0.85,
		"truth_level": 0.7,
		"visibility": "family_only",
		"propagation_mode": "lineage",
		"age_range": [0, 80],
		"decay_rate": 0.01,
		"pressure": pressure.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec())
	}
	var packets_raw: Variant = lineage.get("memory_packets", [])
	var packets: Array = packets_raw.duplicate(true) if typeof(packets_raw) == TYPE_ARRAY else []
	packets.append(packet)
	lineage ["memory_packets"] = packets
	lineage_registry [lineage_id] = lineage
	return build_birth_bias_from_reservoir({
		"lineage_id": lineage_id,
		"current_story_id": "afterlife_reincarnation"
	}, {
		"source": "afterlife_reincarnation"
	})

func _apply_contract_memories_to_family(player: Person, family: Array, contract: Dictionary) -> void:
	var packets_raw: Variant = contract.get("memory_packets", [])
	var packets: Array = packets_raw.duplicate(true) if typeof(packets_raw) == TYPE_ARRAY else []
	for raw_packet in packets:
		if typeof(raw_packet) != TYPE_DICTIONARY:
			continue
		var packet: Dictionary = raw_packet
		var text: String = str(packet.get("text", "")).strip_edges()
		if text == "":
			continue
		_remember_person(player, text)
		for member in family:
			if member is Person:
				_remember_person(member, text)
	if not packets.is_empty():
		var intro:= "My birth carried old family pressure from %s." % str(contract.get("story_title", "a story before me"))
		_remember_person(player, intro)

func _apply_lineage_bending_birth(player: Person, family: Array, contract: Dictionary, settings: Dictionary = {}) -> void:
	if gs == null or gs.bending_engine == null:
		return
	if not gs.is_feature_enabled("bending"):
		player.bending_type = "none"
		player.bending_nation = ""
		player.bending_mastery = {}
		return

	var conditions_raw: Variant = contract.get("birth_conditions", {})
	var conditions: Dictionary = conditions_raw.duplicate(true) if typeof(conditions_raw) == TYPE_DICTIONARY else {}
	var bt: String = str(settings.get("bending_type", conditions.get("bending_type", "none"))).strip_edges().to_lower()

	if bt not in ["air", "earth", "fire", "water", "avatar", "none"]:
		bt = "none"

	player.bending_type = bt
	player.bending_mastery = {}
	player.bending_latent_potential = {}

	match bt:
		"air":
			player.bending_nation = "Air Nomads"
		"earth":
			player.bending_nation = "Earth Kingdom"
		"fire":
			player.bending_nation = "Fire Nation"
		"water":
			player.bending_nation = _lineage_avatar_birth_nation_from_settings(player, contract, settings, conditions)
			if player.bending_nation == "":
				player.bending_nation = "Water Tribe"
			if gs.bending_engine.has_method("_element_from_nation") and str(gs.bending_engine._element_from_nation(player.bending_nation)).strip_edges().to_lower() != "water":
				player.bending_nation = "Water Tribe"
		"avatar":
			player.bending_nation = _lineage_avatar_birth_nation_from_settings(player, contract, settings, conditions)
			if player.bending_nation == "":
				player.bending_nation = "Fire Nation" if str(contract.get("story_id", "")).findn("fire") != -1 else "Air Nomads"
		_:
			player.bending_nation = ""

	if bt == "none":
		return

	if bt == "avatar":
		for element in ["air", "earth", "fire", "water"]:
			player.bending_mastery [element] = 0
			player.bending_latent_potential [element] = 0
			if gs.bending_engine.has_method("seed_birth_bending_potential"):
				gs.bending_engine.seed_birth_bending_potential(player, element, 2)

		var avatar_native_element: String = "none"
		if gs.bending_engine.has_method("_element_from_nation"):
			avatar_native_element = str(gs.bending_engine._element_from_nation(player.bending_nation)).strip_edges().to_lower()
		if avatar_native_element in ["air", "earth", "fire", "water"] and gs.bending_engine.has_method("seed_birth_bending_potential"):
			var native_potential: int = gs.bending_engine.seed_birth_bending_potential(player, avatar_native_element, 3)
			player.bending_latent_potential [avatar_native_element] = max(int(player.bending_latent_potential.get(avatar_native_element, 0)), native_potential)

		player.fame = max(player.fame, 100)
		player.fame_tier = "Legend"
		_remember_person(player, "I was born into the Avatar cycle through family history older than me.")
	else:
		for element in ["air", "earth", "fire", "water"]:
			player.bending_mastery [element] = 0
			player.bending_latent_potential [element] = 0
		if gs.bending_engine.has_method("seed_birth_bending_potential"):
			gs.bending_engine.seed_birth_bending_potential(player, bt, 2)
		_remember_person(player, "My family history carried %s bending into my birth." % bt.capitalize())

	if gs.bending_engine.has_method("ensure_bending_level_state"):
		gs.bending_engine.ensure_bending_level_state(player)
	if gs.bending_engine.has_method("sync_family_bending"):
		gs.bending_engine.sync_family_bending(player, family)
func _lineage_avatar_birth_nation_from_settings(player: Person, contract: Dictionary, settings: Dictionary = {}, conditions: Dictionary = {}) -> String:
	var candidates: Array = [
		settings.get("avatar_base_nation", ""),
		settings.get("avatar_birth_nation", ""),
		settings.get("bending_nation", ""),
		settings.get("birth_country", ""),
		settings.get("country", ""),
		settings.get("home_country", ""),
		conditions.get("avatar_base_nation", ""),
		conditions.get("avatar_birth_nation", ""),
		conditions.get("bending_nation", ""),
		conditions.get("birth_country", ""),
		conditions.get("country", ""),
		contract.get("avatar_base_nation", ""),
		contract.get("avatar_birth_nation", ""),
		contract.get("bending_nation", "")
	]

	if player != null:
		candidates.append(player.birth_country)
		candidates.append(player.home_country)
		candidates.append(player.bending_nation)

	for raw_candidate in candidates:
		var candidate: String = str(raw_candidate).strip_edges()
		if candidate == "":
			continue
		if gs != null and gs.bending_engine != null and gs.bending_engine.has_method("_normalize_avatar_birth_nation"):
			var normalized_by_engine: String = str(gs.bending_engine._normalize_avatar_birth_nation(candidate)).strip_edges()
			if normalized_by_engine != "":
				return normalized_by_engine
		var locally_normalized: String = _lineage_normalize_avatar_birth_nation(candidate)
		if locally_normalized != "":
			return locally_normalized

	return ""

func _lineage_normalize_avatar_birth_nation(nation: String) -> String:
	var clean_nation: String = str(nation).strip_edges()
	if clean_nation == "":
		return ""

	var key: String = clean_nation.to_lower()

	match clean_nation:
		"Northern Water Tribe":
			return "Northern Water Tribe"
		"Southern Water Tribe":
			return "Southern Water Tribe"
		"Water Tribe", "Water Nation":
			return "Water Tribe"
		"Fire Nation":
			return "Fire Nation"
		"Earth Kingdom", "Earth Nation":
			return "Earth Kingdom"
		"Air Nomads", "Air Temples", "Air Nation", "Northern Air Temple", "Southern Air Temple", "Eastern Air Temple", "Western Air Temple":
			return "Air Nomads"

	if key.find("northern") != -1 and key.find("water") != -1:
		return "Northern Water Tribe"
	if key.find("southern") != -1 and key.find("water") != -1:
		return "Southern Water Tribe"
	if key.find("water") != -1:
		return "Water Tribe"
	if key.find("fire") != -1:
		return "Fire Nation"
	if key.find("earth") != -1:
		return "Earth Kingdom"
	if key.find("air") != -1:
		return "Air Nomads"

	return ""
func _create_lineage_parent(gender: String, child: Person, contract: Dictionary) -> Person:
	if gs == null or gs.npc_factory == null:
		return null
	var parent: Person = gs.npc_factory._create_parent(gender, child.home_city, child.home_country)
	if parent == null:
		return null
	parent.birth_city = child.birth_city
	parent.birth_country = child.birth_country
	parent.home_city = child.home_city
	parent.home_country = child.home_country
	parent.social_class = child.social_class
	parent.bank_balance = max(float(parent.bank_balance), float(child.bank_balance) * 0.5)
	parent.traits = _lineage_traits_from_contract(contract, parent.traits)
	if gs.npc_factory != null:
		gs.npc_factory.align_immediate_family_stats_to_child(child, parent, parent)
	if gs != null:
		gs.apply_reality_rules_to_person(parent)
	return parent

func _register_family_member(person: Person) -> void:
	if gs == null or person == null:
		return
	gs.register_npc(person)

func _remember_person(person: Person, text: String) -> void:
	if person == null:
		return
	var clean_text: String = str(text).strip_edges()
	if clean_text == "":
		return
	if clean_text not in person.memories:
		person.memories.append(clean_text)
	if gs != null and gs.memory_engine != null:
		gs.memory_engine.remember(int(person.id), clean_text)

func _lineage_traits_from_contract(contract: Dictionary, existing: Array = []) -> Array:
	var out: Array = existing.duplicate(true)
	var reservoir_raw: Variant = contract.get("pressure_reservoir", {})
	var reservoir: Dictionary = reservoir_raw.duplicate(true) if typeof(reservoir_raw) == TYPE_DICTIONARY else {}
	if float(reservoir.get("integrity", 0.0)) >= 18.0 and "FamilyPrincipled" not in out:
		out.append("FamilyPrincipled")
	if float(reservoir.get("trauma", 0.0)) >= 18.0 and "InheritedPressure" not in out:
		out.append("InheritedPressure")
	if float(reservoir.get("corruption", 0.0)) >= 18.0 and "FamilySecrets" not in out:
		out.append("FamilySecrets")
	if float(reservoir.get("supernatural_affinity", 0.0)) >= 12.0 and "SupernaturalLineage" not in out:
		out.append("SupernaturalLineage")
	return out

func _resolve_lineage_bending_type(lineage: Dictionary, reservoir: Dictionary) -> String:
	var story_id: String = str(lineage.get("story_id", "")).strip_edges().to_lower()
	if story_id.find("avatar") != -1:
		return "avatar"
	if story_id.find("fire") != -1:
		return "fire"
	if story_id.find("water") != -1:
		return "water"
	if story_id.find("earth") != -1:
		return "earth"
	if story_id.find("air") != -1:
		return "air"
	if float(reservoir.get("supernatural_affinity", 0.0)) >= 30.0:
		return ["air", "earth", "fire", "water"].pick_random()
	return "none"

func _pressure_total(pressure: Dictionary) -> float:
	var total: float = 0.0
	for raw_key in pressure.keys():
		total += abs(float(pressure.get(raw_key, 0.0)))
	return total

func _ancestor_name_from_story(story: Dictionary) -> String:
	var title: String = str(story.get("title", "Family Story")).strip_edges()
	if title == "":
		title = "Family Story"
	var clean: String = title.replace("The ", "").replace("A ", "").replace("An ", "")
	return "%s Ancestor" % clean

func _surname_from_ancestor(value: String) -> String:
	var clean: String = str(value).strip_edges()
	if clean == "":
		return "Lineage"
	var parts: PackedStringArray = clean.split(" ", false)
	if parts.size() > 0:
		return str(parts [parts.size() - 1])
	return clean

func _build_default_contract() -> Dictionary:
	return {
		"schema": CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": "default_lineage_engine_contract",
		"systems": {
			"pressure_reservoir": true,
		},
		"policies": {
			"unknown_fields": "preserve",
			"memory_visibility": "family_only_default",
			"birth_router": "lineage_pressure_first",
			"bending_birth_policy": "contract_or_pressure"
		}
	}

func _merge_dict(base: Dictionary, patch: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	for key in patch.keys():
		out [key] = patch [key]
	return out

func _short_id(prefix: String, source: String) -> String:
	var value: int = abs(hash(source))
	return "%s_%s" % [prefix, String.num_int64(value, 36)]