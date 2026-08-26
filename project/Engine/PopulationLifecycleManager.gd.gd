extends Resource
class_name PopulationLifecycleManager

var gs

const MAX_DORMANT_KEEP:= 12000
const DORMANT_TO_SHARD_BATCH:= 1000
const SHARD_SAMPLE_REBUILD_CHANCE:= 25

func _init(_gs):
	gs = _gs






func yearly_evaluate() -> void:
	_apply_population_pressure_to_factions()
	_demote_active_population()
	_trim_dormant_population()






func post_dormant_yearly_pass() -> void:
	_trim_dormant_population()
	_apply_population_pressure_to_factions()






func _demote_active_population() -> void:
	if gs == null:
		return


	gs._soft_unload_npcs()






func _trim_dormant_population() -> void:
	if gs == null:
		return
	if gs.dormant_npcs.size() <= MAX_DORMANT_KEEP:
		return
	var candidates:= []
	for npc_id in gs.dormant_npcs.keys():
		var d = gs.dormant_npcs [npc_id]
		if typeof(d) != TYPE_DICTIONARY:
			continue
		if not _can_collapse_dormant_snapshot(d):
			continue
		candidates.append({
			"id": int(npc_id),
			"score": _snapshot_relevance_score(d)
		})

	candidates.sort_custom(func (a, b): return int(a ["score"]) < int(b ["score"]))
	var overflow: int = int(gs.dormant_npcs.size()) - int(MAX_DORMANT_KEEP)
	var collapse_count: int = int(min(
		overflow,
		min(candidates.size(), DORMANT_TO_SHARD_BATCH)
	))
	if gs.year_budget_engine != null:
		collapse_count = int(min(
			collapse_count,
			gs.year_budget_engine.get_dormant_collapse_budget(overflow, candidates.size())
		))
	if collapse_count <= 0:
		return
	for i in range(collapse_count):
		var npc_id = int(candidates [i] ["id"])
		if not gs.dormant_npcs.has(npc_id):
			continue
		var snap = gs.dormant_npcs [npc_id]
		if gs.population_shard_engine != null and gs.population_shard_engine.collapse_snapshot_to_shard(snap):
			gs.dormant_npcs.erase(npc_id)






func reconstruct_or_activate_by_id(npc_id: int) -> Person:
	if gs == null:
		return null

	var active = gs.get_npc_by_id(npc_id)
	if active != null:
		return active

	if gs.dormant_npcs.has(npc_id):
		return gs.reactivate_npc(npc_id)


	var facts = {}
	if gs.population_shard_engine != null:
		facts = gs.population_shard_engine.get_lineage_facts(npc_id)

	if facts == {}:
		return null

	var snap = _reconstruct_snapshot_from_lineage(facts)
	if snap == {}:
		return null

	gs.dormant_npcs [npc_id] = snap
	return gs.reactivate_npc(npc_id)






func materialize_person_from_shard(filters:= {}) -> Person:
	if gs == null or gs.population_shard_engine == null:
		return null

	var request: Dictionary = _normalize_population_shard_spawn_contract(filters)
	var clean_filters: Dictionary = request.get("filters", {}).duplicate(true)
	var selection: String = str(request.get("selection", "weighted_sample")).strip_edges().to_lower()
	var lineage_restore: bool = bool(request.get("lineage_restore", true))
	var use_buffer_pool: bool = bool(request.get("use_buffer_pool", true))

	if use_buffer_pool:
		var buffered_person: Person = _materialize_person_from_buffer(clean_filters, selection)
		if buffered_person != null:
			return buffered_person

	if lineage_restore:
		var lineage_person: Person = _materialize_person_from_lineage(clean_filters)
		if lineage_person != null:
			return lineage_person

	var shard: Dictionary = _pick_matching_shard(clean_filters, selection)
	if shard == {}:
		return null

	var snap: Dictionary = _generate_snapshot_from_shard(shard, clean_filters)
	if snap == {}:
		return null

	var npc_id: int = int(snap.get("id", -1))
	if npc_id <= 0:
		npc_id = gs.next_id
		gs.next_id += 1

	snap ["id"] = npc_id
	gs.dormant_npcs [npc_id] = snap
	return gs.reactivate_npc(npc_id)
func _materialize_person_from_buffer(filters:= {}, selection: String = "weighted_sample") -> Person:
	if gs == null or gs.population_shard_engine == null:
		return null

	var shard: Dictionary = _pick_matching_shard(filters, selection)
	if shard == {}:
		return null

	var buffer_pool_raw: Variant = shard.get("buffer_pool", [])
	var buffer_pool: Array = buffer_pool_raw if typeof(buffer_pool_raw) == TYPE_ARRAY else []
	if buffer_pool.is_empty():
		return null

	var snap_raw: Variant = buffer_pool.pop_back()
	var snap: Dictionary = snap_raw if typeof(snap_raw) == TYPE_DICTIONARY else {}
	if snap.is_empty():
		shard ["buffer_pool"] = buffer_pool
		gs.population_shard_engine.population_shards [shard ["key"]] = shard
		return null

	shard ["buffer_pool"] = buffer_pool
	shard ["count"] = max(0, int(shard.get("count", 0)) - 1)
	gs.population_shard_engine.population_shards [shard ["key"]] = shard

	var npc_id: int = int(snap.get("id", -1))
	if npc_id <= 0:
		npc_id = gs.next_id
		gs.next_id += 1
		snap ["id"] = npc_id

	_apply_materialization_personality_and_memory(snap, filters, shard, "buffer_pool")
	snap ["_dormant"] = true
	snap ["_dormant_year"] = gs.year
	snap ["_query_facts"] = gs._extract_queryable_npc_facts(snap)

	gs.dormant_npcs [npc_id] = snap
	return gs.reactivate_npc(npc_id)
func inject_live_population_personality(npc: Person, context:= {}) -> void:
	if npc == null or gs == null:
		return

	var snap: Dictionary = gs._serialize_npc(npc)
	_apply_materialization_personality_and_memory(snap, context, {}, str(context.get("source", "live_inject")))

	var memories_raw: Variant = snap.get("memories", [])
	if typeof(memories_raw) == TYPE_ARRAY:
		npc.memories = memories_raw.duplicate(true)

	var affection_raw: Variant = snap.get("affection", {})
	if typeof(affection_raw) == TYPE_DICTIONARY:
		npc.affection = affection_raw.duplicate(true)

	npc.fate_arc = str(snap.get("fate_arc", npc.fate_arc))
	npc.strategic_focus = str(snap.get("strategic_focus", npc.strategic_focus))
	npc.motivation = int(snap.get("motivation", npc.motivation))
	npc.ambition = int(snap.get("ambition", npc.ambition))

func _apply_materialization_personality_and_memory(snap: Dictionary, filters:= {}, shard: Dictionary = {}, source: String = "synth") -> void:
	if typeof(snap) != TYPE_DICTIONARY or snap.is_empty() or gs == null:
		return

	var memories_raw: Variant = snap.get("memories", [])
	var memories: Array = memories_raw if typeof(memories_raw) == TYPE_ARRAY else []

	var affection_raw: Variant = snap.get("affection", {})
	var affection: Dictionary = affection_raw if typeof(affection_raw) == TYPE_DICTIONARY else {}

	var realm_id: int = int(filters.get("realm_id", snap.get("realm_id", shard.get("realm_id", -1))))
	var realm_name: String = str(filters.get("home_country", snap.get("home_country", shard.get("home_country", "")))).strip_edges()

	var ruler_id: int = -1
	var ruler_name: String = ""

	if realm_id > 0 and gs.realm_engine != null and gs.realm_engine.has_method("ensure_realm_defaults"):
		var realm: Dictionary = gs.realm_engine.ensure_realm_defaults(realm_id)
		if not realm.is_empty():
			realm_name = str(realm.get("name", realm_name)).strip_edges()
			ruler_id = int(realm.get("ruler_id", -1))

	if ruler_id > 0 and gs.has_method("get_npc_facts_by_id"):
		var ruler_facts: Dictionary = gs.get_npc_facts_by_id(ruler_id)
		if not ruler_facts.is_empty():
			ruler_name = ("%s %s" % [
				str(ruler_facts.get("first_name", "")),
				str(ruler_facts.get("last_name", ""))
			]).strip_edges()

	var instability: float = 0.0
	if typeof(gs.scenario_state) == TYPE_DICTIONARY:
		var pressure_store_raw: Variant = gs.scenario_state.get("realm_population_pressure", {})
		var pressure_store: Dictionary = pressure_store_raw if typeof(pressure_store_raw) == TYPE_DICTIONARY else {}
		var pressure_raw: Variant = pressure_store.get(str(realm_id), {})
		var pressure: Dictionary = pressure_raw if typeof(pressure_raw) == TYPE_DICTIONARY else {}
		instability = float(pressure.get("instability_pressure", 0.0))

	var opinion_bias: int = randi_range(-18, 18)
	if instability >= 35.0:
		opinion_bias -= randi_range(6, 18)
	elif instability <= 10.0:
		opinion_bias += randi_range(4, 12)

	if memories.is_empty():
		if ruler_name != "" and opinion_bias <= -8:
			memories.append("I never trusted how %s held power." % ruler_name)
		elif ruler_name != "" and opinion_bias >= 8:
			memories.append("I thought %s kept the realm steadier than people admitted." % ruler_name)
		elif ruler_name != "":
			memories.append("I watched %s rule from the edge of daily life." % ruler_name)

		if realm_name != "":
			memories.append("My life has been shaped by %s." % realm_name)

		match source:
			"buffer_pool":
				memories.append("Old frictions still feel close, like I never really left the crowd.")
			"lineage_reconstruct":
				memories.append("Some of my ties came back before the rest of me did.")
			"crown_fallback_synth":
				memories.append("I already had an opinion about the crown before anyone asked.")
			_:
				memories.append("I came into view with old feelings already attached to the realm.")

	if ruler_id > 0:
		affection [ruler_id] = int(clamp(50 + opinion_bias, 0, 100))

	if gs.player != null and int(gs.player.realm_id) == realm_id and int(gs.player.id) != ruler_id:
		affection [int(gs.player.id)] = int(clamp(50 + int(round(float(opinion_bias) * 0.7)), 0, 100))

	if str(snap.get("fate_arc", "")).strip_edges() == "":
		if opinion_bias <= -10:
			snap ["fate_arc"] = "Suspicious of power"
		elif opinion_bias >= 10:
			snap ["fate_arc"] = "Protective of the current order"
		else:
			snap ["fate_arc"] = "Watching the political weather"

	if str(snap.get("strategic_focus", "")).strip_edges() == "":
		if opinion_bias <= -10:
			snap ["strategic_focus"] = "Watch the ruler carefully"
		elif opinion_bias >= 10:
			snap ["strategic_focus"] = "Support the realm's stability"
		else:
			snap ["strategic_focus"] = "Stay close to local tensions"

	snap ["motivation"] = int(clamp(int(snap.get("motivation", 50)) + max(0, int(round(instability * 0.15))), 0, 100))
	snap ["ambition"] = int(clamp(int(snap.get("ambition", 50)) + randi_range(-4, 6), 0, 100))
	snap ["memories"] = memories
	snap ["affection"] = affection
func bootstrap_pre_ui_population_state(skip_faction_projection: bool = false) -> void:
	if gs == null or gs.realm_engine == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	if bool(gs.scenario_state.get("population_bootstrap_ready", false)):
		return
	if typeof(gs.realm_engine.realms) != TYPE_DICTIONARY or gs.realm_engine.realms.is_empty():
		return
	for raw_realm_id in gs.realm_engine.realms.keys():
		var realm_id: int = int(raw_realm_id)
		if realm_id <= 0:
			continue
		var realm: Dictionary = gs.realm_engine.ensure_realm_defaults(realm_id)
		if realm.is_empty():
			continue
		_seed_realm_births_backlog(realm_id, realm)
		_seed_realm_age_distribution(realm_id, realm)
		_seed_realm_occupation_spread(realm_id, realm)
	_apply_population_pressure_to_factions()
	if not skip_faction_projection and gs.universal_faction_engine != null and gs.universal_faction_engine.has_method("bootstrap_population_pressure_projection"):
		gs.universal_faction_engine.bootstrap_population_pressure_projection()
	gs.scenario_state ["population_bootstrap_ready"] = true


func _seed_realm_births_backlog(realm_id: int, realm: Dictionary) -> void:
	if gs == null or gs.realm_engine == null:
		return

	var profile: Dictionary = _build_realm_population_pressure_profile(realm_id, realm)
	var child_count: int = int(profile.get("child_count", 0))
	var child_floor: int = int(profile.get("child_floor", 0))
	var missing_children: int = max(child_floor - child_count, 0)

	for i in range(missing_children):
		var created: Person = _materialize_person_from_lineage({
			"realm_id": realm_id,
			"home_country": str(realm.get("name", "")).strip_edges(),
			"birth_mode": "backlog_child"
		})
		if created == null and gs.realm_engine.has_method("create_bootstrap_realm_resident"):
			created = gs.realm_engine.create_bootstrap_realm_resident(
				realm_id,
				str(realm.get("capital_city", "")).strip_edges(),
				"worker"
			) as Person
		if created == null:
			break
		created.age = randi_range(0, 15)


func _seed_realm_age_distribution(realm_id: int, realm: Dictionary) -> void:
	if gs == null or gs.realm_engine == null:
		return

	var profile: Dictionary = _build_realm_population_pressure_profile(realm_id, realm)
	var _total_population: int = int(profile.get("total_population", 0))
	var young_adult_count: int = int(profile.get("young_adult_count", 0))
	var elder_count: int = int(profile.get("elder_count", 0))
	var young_adult_floor: int = int(profile.get("young_adult_floor", 0))
	var elder_floor: int = int(profile.get("elder_floor", 0))

	var missing_young_adults: int = max(young_adult_floor - young_adult_count, 0)
	for i in range(missing_young_adults):
		var created: Person = null
		if gs.realm_engine.has_method("create_bootstrap_realm_resident"):
			created = gs.realm_engine.create_bootstrap_realm_resident(
				realm_id,
				str(realm.get("capital_city", "")).strip_edges(),
				["worker", "soldier"].pick_random()
			)
		if created == null:
			break
		created.age = randi_range(18, 35)

	var missing_elders: int = max(elder_floor - elder_count, 0)
	for i in range(missing_elders):
		var elder: Person = null
		if gs.realm_engine.has_method("create_bootstrap_realm_resident"):
			elder = gs.realm_engine.create_bootstrap_realm_resident(
				realm_id,
				str(realm.get("capital_city", "")).strip_edges(),
				["worker", "noble"].pick_random()
			)
		if elder == null:
			break
		elder.age = randi_range(52, 78)


func _seed_realm_occupation_spread(realm_id: int, realm: Dictionary) -> void:
	if gs == null or gs.realm_engine == null:
		return

	var profile: Dictionary = _build_realm_population_pressure_profile(realm_id, realm)
	var worker_gap: int = int(profile.get("worker_gap", 0))
	var soldier_gap: int = int(profile.get("soldier_gap", 0))
	var elite_gap: int = int(profile.get("elite_gap", 0))

	for i in range(worker_gap):
		if not gs.realm_engine.has_method("create_bootstrap_realm_resident"):
			break
		var worker: Person = gs.realm_engine.create_bootstrap_realm_resident(
			realm_id,
			str(realm.get("capital_city", "")).strip_edges(),
			"worker"
		) as Person
		if worker == null:
			break

	for i in range(soldier_gap):
		if not gs.realm_engine.has_method("create_bootstrap_realm_resident"):
			break
		var soldier: Person = gs.realm_engine.create_bootstrap_realm_resident(
			realm_id,
			str(realm.get("capital_city", "")).strip_edges(),
			"soldier"
		) as Person
		if soldier == null:
			break

	for i in range(elite_gap):
		if not gs.realm_engine.has_method("create_bootstrap_realm_resident"):
			break
		var noble: Person = gs.realm_engine.create_bootstrap_realm_resident(
			realm_id,
			str(realm.get("capital_city", "")).strip_edges(),
			"noble"
		) as Person
		if noble == null:
			break


func _apply_population_pressure_to_factions() -> void:
	if gs == null or gs.realm_engine == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var pressure_state: Dictionary = {}
	for raw_realm_id in gs.realm_engine.realms.keys():
		var realm_id: int = int(raw_realm_id)
		if realm_id <= 0:
			continue
		var realm_raw: Variant = gs.realm_engine.realms.get(raw_realm_id, {})
		var realm: Dictionary = realm_raw if typeof(realm_raw) == TYPE_DICTIONARY else {}
		if realm.is_empty():
			continue
		pressure_state [str(realm_id)] = _build_realm_population_pressure_profile(realm_id, realm)

	gs.scenario_state ["realm_population_pressure"] = pressure_state

	if gs.universal_faction_engine != null and gs.universal_faction_engine.has_method("flag_domain_projection_dirty"):
		gs.universal_faction_engine.flag_domain_projection_dirty("realm_engine")


func _build_realm_population_pressure_profile(realm_id: int, realm: Dictionary) -> Dictionary:
	var summary: Dictionary = _summarize_active_realm_population(realm_id)
	var total_population: int = int(summary.get("total", 0))
	var workers: int = int(summary.get("worker", 0))
	var soldiers: int = int(summary.get("soldier", 0))
	var elites: int = int(summary.get("elite", 0))
	var children: int = int(summary.get("child", 0))
	var young_adults: int = int(summary.get("young_adult", 0))
	var elders: int = int(summary.get("elder", 0))

	var target_population: int = max(total_population, int(realm.get("population", 0)))
	var visible_floor: int = max(12, int(realm.get("visible_resident_floor", 0)))
	var worker_floor: int = max(4, int(round(float(visible_floor) * 0.45)))
	var soldier_floor: int = max(2, int(round(float(visible_floor) * 0.2)))
	var elite_floor: int = max(1, int(round(float(visible_floor) * 0.1)))
	if str(realm.get("government_style", "State")).strip_edges() == "Monarchy":
		elite_floor = max(elite_floor, 2)
	if str(realm.get("realm_kind", "state")).strip_edges().to_lower() == "nation":
		soldier_floor = max(soldier_floor, 4)

	var child_floor: int = max(2, int(round(float(visible_floor) * 0.18)))
	var young_adult_floor: int = max(3, int(round(float(visible_floor) * 0.24)))
	var elder_floor: int = max(1, int(round(float(visible_floor) * 0.08)))

	var low_population_pressure: float = max(float(visible_floor - total_population), 0.0) * 7.5
	var overpopulation_pressure: float = max(float(total_population - max(visible_floor * 2, visible_floor + 12)), 0.0) * 2.5
	var elite_gap_pressure: float = max(float(elite_floor - elites), 0.0) * 10.0
	var military_gap_pressure: float = max(float(soldier_floor - soldiers), 0.0) * 8.5
	var worker_gap_pressure: float = max(float(worker_floor - workers), 0.0) * 5.5

	return {
		"realm_id": realm_id,
		"realm_name": str(realm.get("name", "")).strip_edges(),
		"total_population": total_population,
		"target_population": target_population,
		"worker_count": workers,
		"soldier_count": soldiers,
		"elite_count": elites,
		"child_count": children,
		"young_adult_count": young_adults,
		"elder_count": elders,
		"visible_floor": visible_floor,
		"worker_floor": worker_floor,
		"soldier_floor": soldier_floor,
		"elite_floor": elite_floor,
		"child_floor": child_floor,
		"young_adult_floor": young_adult_floor,
		"elder_floor": elder_floor,
		"worker_gap": max(worker_floor - workers, 0),
		"soldier_gap": max(soldier_floor - soldiers, 0),
		"elite_gap": max(elite_floor - elites, 0),
		"low_population_pressure": low_population_pressure,
		"overpopulation_pressure": overpopulation_pressure,
		"elite_gap_pressure": elite_gap_pressure,
		"military_gap_pressure": military_gap_pressure,
		"worker_gap_pressure": worker_gap_pressure,
		"instability_pressure": low_population_pressure + overpopulation_pressure + elite_gap_pressure + military_gap_pressure + worker_gap_pressure
	}


func _summarize_active_realm_population(realm_id: int) -> Dictionary:
	var summary: Dictionary = {
		"total": 0,
		"worker": 0,
		"soldier": 0,
		"elite": 0,
		"child": 0,
		"young_adult": 0,
		"elder": 0
	}
	if gs == null:
		return summary

	for raw_npc in gs.npcs:
		var npc: Person = raw_npc
		if npc == null or not npc.alive:
			continue
		if int(npc.realm_id) != realm_id:
			continue

		summary ["total"] = int(summary.get("total", 0)) + 1

		if int(npc.age) <= 15:
			summary ["child"] = int(summary.get("child", 0)) + 1
		elif int(npc.age) <= 35:
			summary ["young_adult"] = int(summary.get("young_adult", 0)) + 1
		elif int(npc.age) >= 52:
			summary ["elder"] = int(summary.get("elder", 0)) + 1

		var social_class: String = str(npc.social_class).strip_edges().to_lower()
		var job: String = str(npc.job).strip_edges().to_lower()
		if bool(npc.is_ruler) or bool(npc.is_royal) or str(npc.royal_title).strip_edges() != "" or social_class in ["noble", "royal"]:
			summary ["elite"] = int(summary.get("elite", 0)) + 1
			continue
		if job in ["soldier", "guard", "warrior", "militia", "watchman", "legionary", "spearman", "archer", "officer", "general"]:
			summary ["soldier"] = int(summary.get("soldier", 0)) + 1
			continue
		summary ["worker"] = int(summary.get("worker", 0)) + 1

	return summary


func _materialize_person_from_lineage(filters:= {}) -> Person:
	if gs == null or gs.population_shard_engine == null:
		return null
	if not gs.population_shard_engine.has_method("get_lineage_facts"):
		return null

	var candidate_parent_ids: Array = _pick_lineage_birth_candidates(filters)
	if candidate_parent_ids.size() < 2:
		return null

	var parent_a = gs.population_lifecycle_manager.reconstruct_or_activate_by_id(int(candidate_parent_ids [0]))
	var parent_b = gs.population_lifecycle_manager.reconstruct_or_activate_by_id(int(candidate_parent_ids [1]))
	if parent_a == null or parent_b == null:
		return null

	var child: Person = _build_lineage_child_from_parents(parent_a, parent_b, filters)
	if child == null:
		return null

	return child


func _pick_lineage_birth_candidates(filters:= {}) -> Array:
	var out: Array = []
	if gs == null or gs.population_shard_engine == null:
		return out

	var target_realm_id: int = int(filters.get("realm_id", -1))
	var seen: Dictionary = {}
	for raw_id in gs.population_shard_engine.lineage_ledger.keys():
		var npc_id: int = int(raw_id)
		var facts: Dictionary = gs.population_shard_engine.get_lineage_facts(npc_id)
		if facts.is_empty():
			continue
		if not bool(facts.get("alive", true)):
			continue
		if target_realm_id > 0 and int(facts.get("realm_id", -1)) != target_realm_id:
			continue
		var age: int = int(facts.get("age", 0))
		if age < 18 or age > 45:
			continue
		if seen.has(npc_id):
			continue
		seen [npc_id] = true
		out.append(npc_id)
		if out.size() >= 2:
			break
	return out


func _build_lineage_child_from_parents(parent_a: Person, parent_b: Person, filters:= {}) -> Person:
	if gs == null or gs.npc_factory == null:
		return null
	if parent_a == null or parent_b == null:
		return null

	var child: Person = gs.npc_factory.create_random_npc(false)
	if child == null:
		return null

	gs.apply_reality_rules_to_person(child)

	child.age = 0
	child.realm_id = int(filters.get("realm_id", parent_a.realm_id if int(parent_a.realm_id) > 0 else parent_b.realm_id))
	child.home_country = str(filters.get("home_country", parent_a.home_country if str(parent_a.home_country).strip_edges() != "" else parent_b.home_country)).strip_edges()
	child.birth_country = child.home_country
	child.home_city = str(parent_a.home_city if str(parent_a.home_city).strip_edges() != "" else parent_b.home_city).strip_edges()
	child.birth_city = child.home_city
	child.parents = [int(parent_a.id), int(parent_b.id)]
	child.last_name = str(parent_a.last_name if str(parent_a.last_name).strip_edges() != "" else parent_b.last_name)
	child.social_class = str(parent_a.social_class if str(parent_a.social_class).strip_edges() != "" else parent_b.social_class)
	child.bending_nation = str(parent_a.bending_nation if str(parent_a.bending_nation).strip_edges() != "" else parent_b.bending_nation)
	child.bending_type = "none"
	child.is_royal = false
	child.is_ruler = false
	child.royal_title = ""
	child.succession_rank = 99

	if bool(parent_a.is_royal) or bool(parent_b.is_royal):
		child.is_royal = true
		child.social_class = "Royal"

	parent_a.children.append(int(child.id))
	parent_b.children.append(int(child.id))

	if not gs.npcs.has(child):
		gs.npcs.append(child)

	if gs.event_bus != null:
		gs.event_bus.emit("npc_born", { "npc_id": int(child.id)})

	return child





func _snapshot_relevance_score(d: Dictionary) -> int:
	var score:= 0

	if int(d.get("fame", 0)) > 0:
		score += int(d.get("fame", 0))

	score += min(int(d.get("dynasty_prestige", 0)), 25)

	if bool(d.get("is_ruler", false)):
		score += 100
	if bool(d.get("is_royal", false)):
		score += 60

	if int(d.get("partner_id", -1)) != -1:
		score += 20

	score += min(d.get("children", []).size() * 4, 20)
	score += min(d.get("parents", []).size() * 3, 12)

	if "Immortal" in d.get("traits", []):
		score += 100

	if str(d.get("bending_type", "none")) != "none":
		score += 8


	if gs.player != null and int(d.get("realm_id", -1)) == gs.player.realm_id:
		score += 5

	return score


func _can_collapse_dormant_snapshot(d: Dictionary) -> bool:
	if typeof(d) != TYPE_DICTIONARY:
		return false

	if not bool(d.get("alive", true)):
		return false


	var npc_id = int(d.get("id", -1))
	if gs.player != null:
		if npc_id in gs.player.parents or npc_id in gs.player.children:
			return false
		if npc_id in gs.player.friends:
			return false
		if npc_id in gs.player.ex_partners:
			return false

	if int(d.get("partner_id", -1)) != -1:
		return false

	if bool(d.get("is_ruler", false)) or bool(d.get("is_royal", false)):
		return false

	if int(d.get("fame", 0)) >= 10:
		return false

	if int(d.get("dynasty_prestige", 0)) >= 10:
		return false

	if "Immortal" in d.get("traits", []):
		return false

	return true





func _reconstruct_snapshot_from_lineage(facts: Dictionary) -> Dictionary:
	if facts == {}:
		return {}

	var snap:= {
		"id": int(facts.get("id", -1)),
		"name": str(facts.get("name", "")),
		"first_name": str(facts.get("first_name", "")),
		"last_name": str(facts.get("last_name", "")),
		"gender": str(facts.get("gender", "")),
		"age": int(facts.get("age", 0)),
		"maiden_last_name": "",
		"health": 70.0,
		"mental_health": 70.0,
		"smarts": 50,
		"looks": 50,
		"job": "",
		"income": 0.0,
		"satisfaction": 50,
		"bank_balance": 0.0,
		"expenses": 0.0,
		"traits": facts.get("traits", []).duplicate(),
		"memories": facts.get("memories", []).duplicate(true) if facts.has("memories") else [],
		"friends": facts.get("friends", []).duplicate() if facts.has("friends") else [],
		"parents": facts.get("parents", []).duplicate(),
		"children": facts.get("children", []).duplicate(),
		"partner_id": int(facts.get("partner_id", -1)),
		"alive": bool(facts.get("alive", true)),
		"birth_city": str(facts.get("birth_city", "")),
		"birth_country": str(facts.get("birth_country", "")),
		"birthday": { "month": 1, "day": 1},
		"zodiac": "",
		"affection": facts.get("affection", {}).duplicate(true) if facts.has("affection") else {},
		"cause_of_death": str(facts.get("cause_of_death", "")),
		"fate_arc": str(facts.get("fate_arc", "")),
		"dynasty_origin": str(facts.get("dynasty_origin", "")),
		"dynasty_prestige": int(facts.get("dynasty_prestige", 0)),
		"fame": int(facts.get("fame", 0)),
		"fame_tier": str(facts.get("fame_tier", "None")),
		"fame_job": "",
		"scandal": 0,
		"paparazzi_heat": 0,
		"social_class": str(facts.get("social_class", "Commoner")),
		"class_mobility": 0,
		"is_royal": bool(facts.get("is_royal", false)),
		"royal_title": str(facts.get("royal_title", "")),
		"realm_id": int(facts.get("realm_id", -1)),
		"approval": int(facts.get("approval", 50)),
		"is_ruler": bool(facts.get("is_ruler", false)),
		"succession_rank": int(facts.get("succession_rank", 99)),
		"exiled": bool(facts.get("exiled", false)),
		"deposed": bool(facts.get("deposed", false)),
		"palace_owned": bool(facts.get("palace_owned", false)),
		"hidden_realm_id": "",
		"hidden_realm_title": "",
		"marital_status": str(facts.get("marital_status", "Single")),
		"ex_partners": [],
		"home_city": str(facts.get("home_city", "")),
		"home_country": str(facts.get("home_country", "")),
		"pregnant_by_id": -1,
		"pregnancy_progress": -1,
		"unborn_child_other_parent_id": -1,
		"pregnancy_context": "",
		"bending_type": str(facts.get("bending_type", "none")),
		"bending_mastery": {
			"air": 0,
			"earth": 0,
			"fire": 0,
			"water": 0,
			"metal": 0
		},
		"avatar_state_unlocked": false,
		"avatar_state_used": false,
		"bending_nation": str(facts.get("bending_nation", "")),
		"school_mode": "",
		"school_name": "",
		"school_status": "",
		"education_level": "None",
		"schoolmates": [],
		"desires": {
			"core": [],
			"active": [],
			"impulses": []
		},
		"motivation": int(facts.get("motivation", 50)),
		"ambition": int(facts.get("ambition", 50)),
		"long_term_goals": [],
		"strategic_focus": str(facts.get("strategic_focus", "")),
		"capabilities": {
			"nodes": {},
			"edges": {}
		}
	}

	_apply_materialization_personality_and_memory(snap, {
		"realm_id": int(facts.get("realm_id", -1)),
		"home_country": str(facts.get("home_country", "")),
		"source": "lineage_reconstruct"
	}, {}, "lineage_reconstruct")

	snap ["_dormant"] = true
	snap ["_dormant_year"] = gs.year
	snap ["_query_facts"] = gs._extract_queryable_npc_facts(snap)
	return snap





func _pick_matching_shard(filters: Dictionary, selection: String = "weighted_sample") -> Dictionary:
	var candidates:= []

	for key in gs.population_shard_engine.population_shards.keys():
		var shard = gs.population_shard_engine.population_shards [key]
		if int(shard.get("count", 0)) <= 0:
			continue
		if not _shard_matches_filters(shard, filters):
			continue
		candidates.append(shard)

	if candidates.is_empty():
		return {}

	if str(selection).strip_edges().to_lower() == "weighted_sample":
		return _weighted_population_shard_sample(candidates)

	return candidates [randi() % candidates.size()]

func _shard_matches_filters(shard: Dictionary, filters: Dictionary) -> bool:
	var ignored_keys: Dictionary = {
		"contract": true,
		"source": true,
		"selection": true,
		"lineage_restore": true,
		"use_buffer_pool": true,
		"inputs": true,
		"filters": true,
		"where": true
	}

	for k in filters.keys():
		var key: String = str(k).strip_edges()
		if key == "" or ignored_keys.has(key):
			continue

		var expected: Variant = filters [k]

		if key == "bending_type":
			var expected_bending: String = str(expected).strip_edges().to_lower()
			var shard_bending: String = str(shard.get("bending_type", "")).strip_edges().to_lower()
			if shard_bending == expected_bending:
				continue

			var bending_weights_raw: Variant = shard.get("bending_weights", {})
			var bending_weights: Dictionary = bending_weights_raw if typeof(bending_weights_raw) == TYPE_DICTIONARY else {}
			if bending_weights.has(expected_bending):
				continue

			return false

		if shard.get(key, null) != expected:
			return false

	return true


func _generate_snapshot_from_shard(shard: Dictionary, filters: Dictionary) -> Dictionary:
	var gender = str(filters.get("gender", shard.get("gender", "Male")))
	var realm_id = int(filters.get("realm_id", shard.get("realm_id", -1)))
	var social_class = str(filters.get("social_class", shard.get("social_class", "Commoner")))
	var country = str(filters.get("home_country", shard.get("home_country", ""))).strip_edges()
	var realm_name: String = ""
	var elemental_capital_city: String = ""
	var elemental_subzones: Array = []
	var native_element: String = ""

	if realm_id > 0 and gs != null and gs.realm_engine != null:
		if gs.realm_engine.has_method("ensure_realm_defaults"):
			var hydrated: Dictionary = gs.realm_engine.ensure_realm_defaults(realm_id)
			if not hydrated.is_empty():
				realm_name = str(hydrated.get("name", country)).strip_edges()
				elemental_capital_city = str(hydrated.get("capital_city", "")).strip_edges()
				var elemental_subzones_raw: Variant = hydrated.get("subzones", [])
				elemental_subzones = elemental_subzones_raw if typeof(elemental_subzones_raw) == TYPE_ARRAY else []
				if gs.realm_engine.has_method("_realm_element_for_name"):
					native_element = str(gs.realm_engine._realm_element_for_name(realm_name)).strip_edges()

	if realm_name == "" and country != "":
		realm_name = country

	var birth_locations = gs.era_engine.get_birth_locations()
	var place = birth_locations [randi() % birth_locations.size()]
	var place_city: String = str(place.get("city", "")).strip_edges()
	var place_country: String = str(place.get("country", "")).strip_edges()

	if realm_name != "":
		place_country = realm_name

	if elemental_capital_city != "":
		place_city = elemental_capital_city
	elif not elemental_subzones.is_empty():
		place_city = str(elemental_subzones [randi() % elemental_subzones.size()]).strip_edges()

	var first_name = gs.names_db.random_first_for_era(gender, gs.era.name)
	var age = _sample_age_from_band(str(shard.get("age_band", "18_25")))

	var last_name = _pick_weighted_name(shard.get("dynasty_weights", {}))
	if last_name == "":
		last_name = gs.names_db.last_name_for_birthplace(gs.era.name, place_city, place_country)
	if last_name == "":
		last_name = gs.names_db.random_last_for_era(gs.era.name)

	var resolved_bending_nation: String = str(filters.get("bending_nation", shard.get("bending_nation", ""))).strip_edges()
	var resolved_bending_type: String = str(filters.get("bending_type", shard.get("bending_type", ""))).strip_edges()

	if resolved_bending_type == "":
		var bending_weights_raw: Variant = shard.get("bending_weights", {})
		var bending_weights: Dictionary = bending_weights_raw if typeof(bending_weights_raw) == TYPE_DICTIONARY else {}
		resolved_bending_type = _pick_weighted_string(bending_weights)

	var resolved_bending_mastery: Dictionary = {
		"air": 0,
		"earth": 0,
		"fire": 0,
		"water": 0,
		"metal": 0
	}

	if native_element != "":
		if resolved_bending_nation == "":
			resolved_bending_nation = realm_name
		if resolved_bending_type == "":
			resolved_bending_type = native_element if randi() % 100 < 62 else "none"
		if resolved_bending_type == native_element:
			resolved_bending_mastery [native_element] = 1

	if resolved_bending_type == "":
		resolved_bending_type = "none"

	var snap:= {
		"id": gs.next_id,
		"name": "%s %s" % [first_name, last_name],
		"first_name": first_name,
		"last_name": last_name,
		"gender": gender,
		"age": age,
		"maiden_last_name": "",
		"health": float(shard.get("avg_health", 70.0)),
		"mental_health": float(shard.get("avg_mental_health", 70.0)),
		"smarts": randi_range(35, 75),
		"looks": randi_range(25, 85),
		"job": "",
		"income": float(shard.get("avg_income", 0.0)),
		"satisfaction": 50,
		"bank_balance": float(shard.get("avg_bank_balance", 0.0)),
		"expenses": 0.0,
		"traits": [],
		"memories": [],
		"friends": [],
		"parents": [],
		"children": [],
		"partner_id": -1,
		"alive": true,
		"birth_city": place_city,
		"birth_country": place_country,
		"birthday": { "month": 1, "day": 1},
		"zodiac": "",
		"affection": {},
		"cause_of_death": "",
		"fate_arc": "",
		"dynasty_origin": "",
		"dynasty_prestige": 0,
		"fame": 0,
		"fame_tier": "None",
		"fame_job": "",
		"scandal": 0,
		"paparazzi_heat": 0,
		"social_class": social_class,
		"class_mobility": 0,
		"is_royal": false,
		"royal_title": "",
		"realm_id": realm_id,
		"approval": 50,
		"is_ruler": false,
		"succession_rank": 99,
		"exiled": false,
		"deposed": false,
		"palace_owned": false,
		"hidden_realm_id": "",
		"hidden_realm_title": "",
		"marital_status": "Single",
		"ex_partners": [],
		"home_city": place_city,
		"home_country": realm_name if realm_name != "" else (country if country != "" else place_country),
		"pregnant_by_id": -1,
		"pregnancy_progress": -1,
		"unborn_child_other_parent_id": -1,
		"pregnancy_context": "",
		"bending_type": resolved_bending_type,
		"bending_mastery": resolved_bending_mastery,
		"avatar_state_unlocked": false,
		"avatar_state_used": false,
		"bending_nation": resolved_bending_nation,
		"school_mode": "",
		"school_name": "",
		"school_status": "",
		"education_level": "None",
		"schoolmates": [],
		"desires": {
			"core": [],
			"active": [],
			"impulses": []
		},
		"motivation": 50,
		"ambition": 50,
		"long_term_goals": [],
		"strategic_focus": "",
		"capabilities": {
			"nodes": {},
			"edges": {}
		}
	}

	_apply_materialization_personality_and_memory(snap, filters, shard, "shard_synth")

	gs.next_id += 1


	shard ["count"] = max(0, int(shard.get("count", 0)) - 1)
	gs.population_shard_engine.population_shards [shard ["key"]] = shard

	snap ["_dormant"] = true
	snap ["_dormant_year"] = gs.year
	snap ["_query_facts"] = gs._extract_queryable_npc_facts(snap)
	return snap


func _sample_age_from_band(age_band: String) -> int:
	match age_band:
		"0_4":
			return randi_range(0, 4)
		"5_12":
			return randi_range(5, 12)
		"13_17":
			return randi_range(13, 17)
		"18_25":
			return randi_range(18, 25)
		"26_40":
			return randi_range(26, 40)
		"41_60":
			return randi_range(41, 60)
		"61_80":
			return randi_range(61, 80)
		"81_plus":
			return randi_range(81, 100)
	return 18

func _normalize_population_shard_spawn_contract(filters:= {}) -> Dictionary:
	var raw: Dictionary = filters if typeof(filters) == TYPE_DICTIONARY else {}

	var contract_id: String = str(raw.get("contract", "")).strip_edges()
	var selection: String = str(raw.get("selection", "weighted_sample")).strip_edges().to_lower()
	var lineage_restore: bool = bool(raw.get("lineage_restore", true))
	var use_buffer_pool: bool = bool(raw.get("use_buffer_pool", true))

	var clean_filters: Dictionary = {}

	var nested_filters_raw: Variant = raw.get("filters", raw.get("where", {}))
	if typeof(nested_filters_raw) == TYPE_DICTIONARY:
		for key in (nested_filters_raw as Dictionary).keys():
			clean_filters [str(key)] = (nested_filters_raw as Dictionary).get(key)

	var input_filters_raw: Variant = raw.get("inputs", {})
	if typeof(input_filters_raw) == TYPE_DICTIONARY:
		var input_filters: Dictionary = input_filters_raw
		if typeof(input_filters.get("filters", {})) == TYPE_DICTIONARY:
			for key in (input_filters.get("filters", {}) as Dictionary).keys():
				clean_filters [str(key)] = (input_filters.get("filters", {}) as Dictionary).get(key)

	for key in ["realm_id", "home_country", "social_class", "gender", "age_band", "bending_type", "bending_nation", "bending_cohort"]:
		if raw.has(key) and not clean_filters.has(key):
			clean_filters [key] = raw.get(key)

	if selection == "":
		selection = "weighted_sample"

	if contract_id == "":
		contract_id = "population.shard.spawn_entity"

	return {
		"contract": contract_id,
		"selection": selection,
		"lineage_restore": lineage_restore,
		"use_buffer_pool": use_buffer_pool,
		"filters": clean_filters
	}


func _weighted_population_shard_sample(candidates: Array) -> Dictionary:
	if candidates.is_empty():
		return {}

	var total_weight: int = 0
	for raw_candidate in candidates:
		if typeof(raw_candidate) != TYPE_DICTIONARY:
			continue
		var candidate: Dictionary = raw_candidate
		total_weight += max(1, int(candidate.get("count", 1)))

	if total_weight <= 0:
		return candidates [randi() % candidates.size()]

	var roll: int = randi_range(1, total_weight)
	var running: int = 0

	for raw_candidate in candidates:
		if typeof(raw_candidate) != TYPE_DICTIONARY:
			continue

		var candidate: Dictionary = raw_candidate
		running += max(1, int(candidate.get("count", 1)))
		if roll <= running:
			return candidate

	return candidates.back()
func _pick_weighted_name(weights: Dictionary) -> String:
	if weights == {}:
		return ""

	var pool:= []
	for k in weights.keys():
		var count = int(weights [k])
		for i in range(min(count, 10)):
			pool.append(k)

	if pool.is_empty():
		return ""

	return pool [randi() % pool.size()]
func _pick_weighted_string(weights: Dictionary) -> String:
	if weights == {}:
		return ""

	var pool:= []
	for k in weights.keys():
		var count: int = int(weights [k])
		for i in range(min(count, 10)):
			pool.append(str(k))

	if pool.is_empty():
		return ""

	return str(pool [randi() % pool.size()])