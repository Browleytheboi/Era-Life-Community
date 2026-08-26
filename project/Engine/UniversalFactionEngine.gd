extends Resource
class_name UniversalFactionEngine

var gs
var faction_registry: Dictionary = {}
var membership_index: Dictionary = {}
var territory_index: Dictionary = {}
var relationship_graph: Dictionary = {}
var pressure_model: Dictionary = {}
var pending_delta_packets: Array = []
var pending_bus_events: Array = []
var domain_dirty_flags: Dictionary = {}
var faction_contract_registry: Dictionary = {}
var faction_contract_layer_state: Dictionary = {}

func _init(_gs):
	gs = _gs
	_ensure_state()

func _ensure_state() -> void:
	if gs == null:
		return

	if typeof(gs.universal_faction_state) != TYPE_DICTIONARY:
		gs.universal_faction_state = {}

	var root: Dictionary = gs.universal_faction_state
	root ["faction_registry"] = root.get("faction_registry", {})
	root ["membership_index"] = root.get("membership_index", {})
	root ["territory_index"] = root.get("territory_index", {})
	root ["relationship_graph"] = root.get("relationship_graph", {})
	root ["pressure_model"] = root.get("pressure_model", {})
	root ["domain_dirty_flags"] = root.get("domain_dirty_flags", {})
	root ["faction_contract_registry"] = root.get("faction_contract_registry", {})
	root ["faction_contract_layer_state"] = root.get("faction_contract_layer_state", {})

	faction_registry = root.get("faction_registry", {})
	membership_index = root.get("membership_index", {})
	territory_index = root.get("territory_index", {})
	relationship_graph = root.get("relationship_graph", {})
	pressure_model = root.get("pressure_model", {})
	domain_dirty_flags = root.get("domain_dirty_flags", {})
	faction_contract_registry = root.get("faction_contract_registry", {})
	faction_contract_layer_state = root.get("faction_contract_layer_state", {})

func export_state() -> Dictionary:
	_commit_state()
	return {
		"faction_registry": faction_registry.duplicate(true),
		"membership_index": membership_index.duplicate(true),
		"territory_index": territory_index.duplicate(true),
		"relationship_graph": relationship_graph.duplicate(true),
		"pressure_model": pressure_model.duplicate(true),
		"domain_dirty_flags": domain_dirty_flags.duplicate(true),
		"faction_contract_registry": faction_contract_registry.duplicate(true),
		"faction_contract_layer_state": faction_contract_layer_state.duplicate(true)
	}

func import_state(data: Dictionary) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return

	faction_registry = data.get("faction_registry", {})
	membership_index = data.get("membership_index", {})
	territory_index = data.get("territory_index", {})
	relationship_graph = data.get("relationship_graph", {})
	pressure_model = data.get("pressure_model", {})
	domain_dirty_flags = data.get("domain_dirty_flags", {})
	faction_contract_registry = data.get("faction_contract_registry", {})
	faction_contract_layer_state = data.get("faction_contract_layer_state", {})

	_commit_state()
func _commit_state() -> void:
	if gs == null:
		return

	if typeof(gs.universal_faction_state) != TYPE_DICTIONARY:
		gs.universal_faction_state = {}

	var root: Dictionary = gs.universal_faction_state
	root ["faction_registry"] = faction_registry
	root ["membership_index"] = membership_index
	root ["territory_index"] = territory_index
	root ["relationship_graph"] = relationship_graph
	root ["pressure_model"] = pressure_model
	root ["domain_dirty_flags"] = domain_dirty_flags
	root ["faction_contract_registry"] = faction_contract_registry
	root ["faction_contract_layer_state"] = faction_contract_layer_state

func flag_domain_projection_dirty(domain_key: String) -> void:
	if domain_key == "":
		return
	var normalized_domain_key: String = str(domain_key).strip_edges()
	if normalized_domain_key == "":
		return
	var dirty_year: int = int(gs.year) if gs != null else 0
	if int(domain_dirty_flags.get(normalized_domain_key, -1)) == dirty_year:
		return
	domain_dirty_flags [normalized_domain_key] = dirty_year
	if gs != null and typeof(gs.universal_faction_state) == TYPE_DICTIONARY:
		gs.universal_faction_state ["domain_dirty_flags"] = domain_dirty_flags

func yearly_core_resolution(_plan:= {}, _metrics:= {}) -> void:
	if gs == null:
		return
	_ensure_state()
	_ingest_faction_contracts_from_simulation_registry()

	var previous_registry: Dictionary = faction_registry.duplicate(false)
	var dirty_projection_keys: Array = _consume_dirty_projection_keys()
	var force_index_rebuild: bool = membership_index.is_empty() or territory_index.is_empty() or relationship_graph.is_empty()
	var requires_full_rebuild: bool = previous_registry.is_empty() or dirty_projection_keys.has("*") or dirty_projection_keys.has("all")

	var touched_faction_ids: Dictionary = {}

	if requires_full_rebuild:
		faction_registry.clear()
		_project_all_domains()
		for raw_faction_id in faction_registry.keys():
			touched_faction_ids [str(raw_faction_id)] = true
	else:
		faction_registry = previous_registry.duplicate(true)
		for raw_domain_key in dirty_projection_keys:
			var domain_key: String = str(raw_domain_key).strip_edges()
			if domain_key == "":
				continue
			_remove_domain_factions_for_domain(domain_key, touched_faction_ids)
			_project_domain_if_dirty(domain_key, touched_faction_ids)

	var dead_member_touches: Dictionary = _cleanup_dead_members_and_collect_touched_factions()
	for raw_faction_id in dead_member_touches.keys():
		touched_faction_ids [str(raw_faction_id)] = true

	var structure_dirty: bool = requires_full_rebuild or force_index_rebuild or not touched_faction_ids.is_empty()

	if structure_dirty:
		if requires_full_rebuild or force_index_rebuild:
			_rebuild_membership_index()
			_rebuild_territory_index()
			_rebuild_relationship_graph()
		else:
			_refresh_membership_index_for_factions(touched_faction_ids)
			_refresh_territory_index_for_factions(touched_faction_ids)
			_rebuild_relationship_graph(touched_faction_ids, true)
		_detect_structural_changes(previous_registry)

	_commit_state()

func yearly_identity_drift(_plan:= {}, _metrics:= {}) -> void:
	if gs == null:
		return
	_ensure_state()

	var current_year: int = int(gs.year)
	var drift_cache: Dictionary = _build_identity_drift_runtime_cache()

	for raw_faction_id in faction_registry.keys():
		var faction_id: String = str(raw_faction_id)
		var faction_raw: Variant = faction_registry.get(faction_id, {})
		var faction: Dictionary = faction_raw if typeof(faction_raw) == TYPE_DICTIONARY else {}
		if faction.is_empty():
			continue

		var prev_profile_raw: Variant = pressure_model.get(faction_id, {})
		var prev_profile: Dictionary = prev_profile_raw if typeof(prev_profile_raw) == TYPE_DICTIONARY else {}
		var prev_pressure: float = float(prev_profile.get("pressure", 0.0))
		var member_count: int = int(faction.get("member_count", 0))

		var signatures_raw: Variant = drift_cache.get("signatures", {})
		var signatures: Dictionary = signatures_raw if typeof(signatures_raw) == TYPE_DICTIONARY else {}
		var faction_signature: String = str(signatures.get(faction_id, ""))

		var drift_metrics: Dictionary = {}
		if _can_reuse_identity_drift_profile(prev_profile, faction_signature, current_year):
			drift_metrics = {
				"legitimacy": float(prev_profile.get("legitimacy", faction.get("legitimacy", 50.0))),
				"cohesion": float(prev_profile.get("cohesion", faction.get("cohesion", 50.0))),
				"hostility": float(prev_profile.get("hostility", faction.get("hostility", 0.0))),
				"visibility": float(prev_profile.get("visibility", faction.get("visibility", 0.0))),
				"pressure": float(prev_profile.get("pressure", faction.get("pressure", 0.0)))
			}
		else:
			drift_metrics = _build_identity_drift_metrics_from_cache(faction, drift_cache)

		var legitimacy: float = float(drift_metrics.get("legitimacy", 0.0))
		var cohesion: float = float(drift_metrics.get("cohesion", 0.0))
		var hostility: float = float(drift_metrics.get("hostility", 0.0))
		var visibility: float = float(drift_metrics.get("visibility", 0.0))
		var pressure: float = float(drift_metrics.get("pressure", 0.0))

		var peaked: bool = member_count >= 20 and legitimacy >= 70.0 and cohesion >= 65.0
		var declining: bool = member_count <= 2 or legitimacy <= 25.0 or cohesion <= 20.0

		pressure_model [faction_id] = {
			"pressure": pressure,
			"legitimacy": legitimacy,
			"cohesion": cohesion,
			"hostility": hostility,
			"visibility": visibility,
			"year": current_year,
			"signature": faction_signature
		}

		faction ["pressure"] = pressure
		faction ["legitimacy"] = legitimacy
		faction ["cohesion"] = cohesion
		faction ["hostility"] = hostility
		faction ["visibility"] = visibility

		if prev_pressure < 35.0 and pressure >= 35.0:
			_queue_pressure_spike_packets(faction, prev_pressure, pressure)
		if peaked and not bool(faction.get("has_peaked_once", false)):
			faction ["has_peaked_once"] = true
			_queue_peak_packets(faction)
		if declining:
			faction ["status"] = "declining"
			_queue_decline_packets(faction)

		faction_registry [faction_id] = faction

	_commit_state()
func _build_identity_drift_runtime_cache() -> Dictionary:
	var hostility_totals: Dictionary = {}
	var hostility_seen_pairs: Dictionary = {}
	var loyalty_totals: Dictionary = {}
	var signatures: Dictionary = {}

	for raw_faction_id in faction_registry.keys():
		var faction_id: String = str(raw_faction_id)
		hostility_totals [faction_id] = 0.0

	for raw_faction_id in relationship_graph.keys():
		var faction_id: String = str(raw_faction_id)
		var edges_raw: Variant = relationship_graph.get(faction_id, {})
		var edges: Dictionary = edges_raw if typeof(edges_raw) == TYPE_DICTIONARY else {}

		for raw_other_id in edges.keys():
			var other_id: String = str(raw_other_id)
			if faction_id == other_id:
				continue

			var pair_key: String = _relationship_pair_key(faction_id, other_id)
			if hostility_seen_pairs.has(pair_key):
				continue
			hostility_seen_pairs [pair_key] = true

			var edge_raw: Variant = edges.get(other_id, {})
			var edge: Dictionary = edge_raw if typeof(edge_raw) == TYPE_DICTIONARY else {}
			var hostility_value: float = float(edge.get("hostility", 0.0))

			hostility_totals [faction_id] = float(hostility_totals.get(faction_id, 0.0)) + hostility_value
			hostility_totals [other_id] = float(hostility_totals.get(other_id, 0.0)) + hostility_value

	for raw_faction_id in faction_registry.keys():
		var faction_id: String = str(raw_faction_id)
		var faction_raw: Variant = faction_registry.get(faction_id, {})
		var faction: Dictionary = faction_raw if typeof(faction_raw) == TYPE_DICTIONARY else {}
		if faction.is_empty():
			continue

		var members_raw: Variant = faction.get("member_ids", {})
		var members: Dictionary = members_raw if typeof(members_raw) == TYPE_DICTIONARY else {}
		var loyalty_total: float = 0.0

		for raw_member_key in members.keys():
			var member_raw: Variant = members.get(raw_member_key, {})
			var member: Dictionary = member_raw if typeof(member_raw) == TYPE_DICTIONARY else {}
			loyalty_total += float(member.get("loyalty", 50.0))

		loyalty_totals [faction_id] = loyalty_total
		signatures [faction_id] = _build_identity_drift_signature(
			faction,
			loyalty_total,
			float(hostility_totals.get(faction_id, 0.0))
		)

	return {
		"hostility_totals": hostility_totals,
		"loyalty_totals": loyalty_totals,
		"signatures": signatures
	}

func _build_identity_drift_signature(faction: Dictionary, loyalty_total: float, hostility_total: float) -> String:
	var resources_raw: Variant = faction.get("resource_ledger", {})
	var resources: Dictionary = resources_raw if typeof(resources_raw) == TYPE_DICTIONARY else {}

	return "%s|%s|%d|%d|%.4f|%.4f|%.4f|%.4f|%.4f|%.4f|%.4f|%.4f|%.4f|%.4f|%.4f|%.4f" % [
		str(faction.get("kind", "")),
		str(faction.get("status", "")),
		int(faction.get("member_count", 0)),
		int(faction.get("leader_id", -1)),
		float(faction.get("prestige", 0.0)),
		loyalty_total,
		hostility_total,
		float(resources.get("territory_span", 0.0)),
		float(resources.get("approval_pool", 0.0)),
		float(resources.get("population", 0.0)),
		float(resources.get("land", 0.0)),
		float(resources.get("low_population_pressure", 0.0)),
		float(resources.get("overpopulation_pressure", 0.0)),
		float(resources.get("elite_gap_pressure", 0.0)),
		float(resources.get("military_gap_pressure", 0.0)),
		float(resources.get("worker_gap_pressure", 0.0))
	]

func _can_reuse_identity_drift_profile(prev_profile: Dictionary, signature: String, current_year: int) -> bool:
	if prev_profile.is_empty():
		return false
	if signature == "":
		return false
	if int(prev_profile.get("year", -999999)) != current_year - 1:
		return false
	return str(prev_profile.get("signature", "")) == signature

func _build_identity_drift_metrics_from_cache(faction: Dictionary, drift_cache: Dictionary) -> Dictionary:
	var faction_id: String = str(faction.get("id", ""))
	var member_count: int = int(faction.get("member_count", 0))

	var loyalty_totals_raw: Variant = drift_cache.get("loyalty_totals", {})
	var loyalty_totals: Dictionary = loyalty_totals_raw if typeof(loyalty_totals_raw) == TYPE_DICTIONARY else {}
	var hostility_totals_raw: Variant = drift_cache.get("hostility_totals", {})
	var hostility_totals: Dictionary = hostility_totals_raw if typeof(hostility_totals_raw) == TYPE_DICTIONARY else {}

	var loyalty_total: float = float(loyalty_totals.get(faction_id, 0.0))
	var cohesion: float = 0.0
	if member_count > 0:
		cohesion = clamp(loyalty_total / float(max(1, member_count)), 0.0, 100.0)

	var hostility: float = clamp(float(hostility_totals.get(faction_id, 0.0)), 0.0, 100.0)

	var resource_metrics: Dictionary = _estimate_identity_resource_metrics(faction)
	var legitimacy: float = float(resource_metrics.get("legitimacy", 0.0))
	var visibility: float = float(resource_metrics.get("visibility", 0.0))

	var pressure: float = 0.0
	pressure += max(0.0, 6.0 - float(member_count)) * 2.0
	pressure += max(0.0, 50.0 - cohesion) * 0.3
	pressure += hostility * 0.2
	pressure += max(0.0, 45.0 - legitimacy) * 0.35
	pressure += visibility * 0.08

	return {
		"legitimacy": legitimacy,
		"cohesion": cohesion,
		"hostility": hostility,
		"visibility": visibility,
		"pressure": pressure
	}

func _estimate_identity_resource_metrics(faction: Dictionary) -> Dictionary:
	var resources_raw: Variant = faction.get("resource_ledger", {})
	var resources: Dictionary = resources_raw if typeof(resources_raw) == TYPE_DICTIONARY else {}

	var legitimacy: float = 40.0
	legitimacy += float(faction.get("prestige", 0.0)) * 0.25
	legitimacy += min(20.0, float(int(faction.get("member_count", 0))) * 1.2)
	if int(faction.get("leader_id", -1)) > 0:
		legitimacy += 8.0
	legitimacy += min(8.0, float(resources.get("approval_pool", 0.0)) * 0.04)
	legitimacy += min(10.0, float(resources.get("population", 0.0)) * 2e-05)
	legitimacy += min(8.0, float(resources.get("land", 0.0)) * 0.05)
	legitimacy -= min(16.0, float(resources.get("low_population_pressure", 0.0)) * 0.18)
	legitimacy -= min(14.0, float(resources.get("overpopulation_pressure", 0.0)) * 0.12)
	legitimacy -= min(18.0, float(resources.get("elite_gap_pressure", 0.0)) * 0.22)
	legitimacy -= min(14.0, float(resources.get("military_gap_pressure", 0.0)) * 0.18)
	legitimacy -= min(8.0, float(resources.get("worker_gap_pressure", 0.0)) * 0.1)

	var visibility: float = 8.0
	visibility += float(int(faction.get("member_count", 0))) * 1.5
	if str(faction.get("kind", "")) in ["boxing_division", "dynasty", "vampire_coven"]:
		visibility += 10.0
	if str(faction.get("kind", "")) in ["realm_power", "royal_house", "political_bloc", "many_realms_circle"]:
		visibility += 8.0
	visibility += min(10.0, float(resources.get("territory_span", 0.0)) * 1.5)
	visibility += min(8.0, float(resources.get("population", 0.0)) * 1e-05)
	visibility += min(8.0, float(resources.get("overpopulation_pressure", 0.0)) * 0.08)
	visibility += min(6.0, float(resources.get("elite_gap_pressure", 0.0)) * 0.06)
	visibility += min(6.0, float(resources.get("military_gap_pressure", 0.0)) * 0.05)

	return {
		"legitimacy": clamp(legitimacy, 0.0, 100.0),
		"visibility": clamp(visibility, 0.0, 100.0)
	}
func _insert_ranked_hotspot(hotspots: Array, hotspot: Dictionary, max_hotspots: int = 5) -> void:
	if max_hotspots <= 0:
		return
	var hotspot_sort: float = float(hotspot.get("_sort", 0.0))
	var inserted: bool = false
	for index in range(hotspots.size()):
		if hotspot_sort > float(hotspots [index].get("_sort", 0.0)):
			hotspots.insert(index, hotspot)
			inserted = true
			break
	if not inserted and hotspots.size() < max_hotspots:
		hotspots.append(hotspot)
	if hotspots.size() > max_hotspots:
		hotspots.resize(max_hotspots)
func yearly_choice_surface(plan:= {}, _metrics:= {}) -> void:
	if gs == null:
		return
	_ensure_state()
	var prioritized_npc_ids: Array = _build_choice_surface_npc_priority_list(plan, _metrics)
	var global_pressure_hooks: Array = _build_global_pressure_hooks()
	var player_hotspots_snapshot: Array = []
	var player_hook_rows_snapshot: Array = []
	for raw_npc_id in prioritized_npc_ids:
		var npc_id: int = int(raw_npc_id)
		if npc_id <= 0:
			continue
		var npc_key: String = str(npc_id)
		var memberships_raw: Variant = membership_index.get(npc_key, {})
		var memberships: Dictionary = memberships_raw if typeof(memberships_raw) == TYPE_DICTIONARY else {}
		if memberships.is_empty():
			continue
		var npc = gs.get_npc_by_id(npc_id)
		if npc == null or not npc.alive:
			continue
		var total_pressure: float = 0.0
		var max_visibility: float = 0.0
		var faction_count: int = 0
		var contested_claims_total: int = 0
		var claim_pressure_total: float = 0.0
		var hostility_total: float = 0.0
		var contested_realm_tension: float = 0.0
		var coup_pressure: float = 0.0
		var syndicate_turf_pressure: float = 0.0
		var royal_succession_tension: float = 0.0
		var diaspora_pull: float = 0.0
		var hidden_realm_instability: float = 0.0
		var justice_pressure: float = 0.0
		var court_pressure: float = 0.0
		var prison_pressure: float = 0.0
		var kind_presence: Dictionary = {}
		var hotspots: Array = []
		var player_is_current: bool = gs.player != null and int(gs.player.id) == npc_id
		var workplace_pressure: float = 0.0
		var dynasty_pressure: float = 0.0
		var neighborhood_pressure: float = 0.0
		var housing_pressure: float = 0.0
		var surveillance_pressure: float = 0.0
		var player_hook_rows: Array = []
		var player_consequence_rows: Array = []
		var player_hook_seen: Dictionary = {}
		var strongest_workplace_name: String = ""
		var strongest_dynasty_name: String = ""
		var strongest_neighborhood_name: String = ""
		var strongest_workplace_score: float = -1.0
		var strongest_dynasty_score: float = -1.0
		var strongest_neighborhood_score: float = -1.0
		for faction_id in memberships.keys():
			var faction_key: String = str(faction_id)
			var membership_raw: Variant = memberships.get(faction_key, {})
			var membership: Dictionary = membership_raw if typeof(membership_raw) == TYPE_DICTIONARY else {}
			var profile_raw: Variant = pressure_model.get(faction_key, {})
			var profile: Dictionary = profile_raw if typeof(profile_raw) == TYPE_DICTIONARY else {}
			var faction_raw: Variant = faction_registry.get(faction_key, {})
			var faction: Dictionary = faction_raw if typeof(faction_raw) == TYPE_DICTIONARY else {}
			var edges_raw: Variant = relationship_graph.get(faction_key, {})
			var edges: Dictionary = edges_raw if typeof(edges_raw) == TYPE_DICTIONARY else {}
			var faction_pressure_value: float = float(profile.get("pressure", 0.0))
			var faction_visibility: float = float(profile.get("visibility", 0.0))
			var faction_hostility: float = float(profile.get("hostility", 0.0))
			var faction_kind: String = str(faction.get("kind", ""))
			var institution_type: String = str(faction.get("institution_type", ""))
			var membership_role: String = str(membership.get("role", "member"))
			total_pressure += faction_pressure_value
			max_visibility = max(max_visibility, faction_visibility)
			faction_count += 1
			kind_presence [faction_kind] = int(kind_presence.get(faction_kind, 0)) + 1
			var local_contested_claims: int = 0
			var local_claim_pressure: float = 0.0
			var local_hidden_realm_instability: float = 0.0
			var local_realm_tension: float = 0.0
			for raw_other_id in edges.keys():
				var edge_raw: Variant = edges.get(raw_other_id, {})
				var edge: Dictionary = edge_raw if typeof(edge_raw) == TYPE_DICTIONARY else {}
				local_contested_claims += int(edge.get("contested_claims", 0))
				local_claim_pressure += float(edge.get("claim_pressure", 0.0))
				if bool(edge.get("contested_realm", false)):
					local_realm_tension += 1.0 + (float(edge.get("hostility", 0.0)) * 0.04)
				if bool(edge.get("contested_hidden_realm", false)):
					local_hidden_realm_instability += 1.0 + (float(edge.get("hostility", 0.0)) * 0.05)
			contested_claims_total += local_contested_claims
			claim_pressure_total += local_claim_pressure
			hostility_total += faction_hostility
			contested_realm_tension += local_realm_tension
			hidden_realm_instability += local_hidden_realm_instability
			if faction_kind in ["political_bloc", "royal_claim", "royal_court", "realm_power", "realm_power_bloc"]:
				coup_pressure += (local_realm_tension * 1.25) + (local_claim_pressure * 0.35) + (faction_pressure_value * 0.15)
			if faction_kind in ["crime_network", "locality", "locality_affinity"]:
				syndicate_turf_pressure += local_claim_pressure + (faction_hostility * 0.2) + (local_contested_claims * 1.5)
			if faction_kind in ["royal_claim", "royal_court", "dynasty"]:
				royal_succession_tension += local_claim_pressure + (local_contested_claims * 2.0) + (local_realm_tension * 1.5)
			if faction_kind == "diaspora":
				diaspora_pull += (faction_pressure_value * 0.6) + (faction_visibility * 0.25) + (local_claim_pressure * 0.25)
			if faction_kind in ["many_realms_circle", "realm_power", "royal_claim"] or str(faction.get("hidden_realm_id", "")) != "":
				hidden_realm_instability += local_hidden_realm_instability
			var local_justice_pressure: float = 0.0
			if faction_kind == "justice_institution":
				local_justice_pressure = faction_pressure_value + local_claim_pressure + (faction_visibility * 0.12) + (faction_hostility * 0.08)
			justice_pressure += local_justice_pressure
			if institution_type in ["court", "tribunal", "magistrate"]:
				court_pressure += local_justice_pressure + (local_claim_pressure * 0.35)
			elif institution_type in ["prison", "gaol", "dungeon", "detention"]:
				prison_pressure += local_justice_pressure + (local_contested_claims * 0.5)
			var hook_text: String = ""
			if local_hidden_realm_instability > 0.0:
				hook_text = "%s is straining around hidden-realm instability this year." % str(faction.get("name", "A faction"))
			elif faction_kind == "diaspora" and (faction_pressure_value > 0.0 or local_claim_pressure > 0.0):
				hook_text = "%s is pulling on identity, belonging, and return this year." % str(faction.get("name", "A faction"))
			elif faction_kind in ["crime_network", "locality", "locality_affinity"] and (local_claim_pressure > 0.0 or local_contested_claims > 0):
				hook_text = "%s is feeling turf pressure around overlapping claims this year." % str(faction.get("name", "A faction"))
			elif faction_kind in ["royal_claim", "royal_court", "dynasty"] and (local_claim_pressure > 0.0 or local_contested_claims > 0):
				hook_text = "%s is under succession tension from competing claims this year." % str(faction.get("name", "A faction"))
			elif faction_kind in ["political_bloc", "realm_power", "realm_power_bloc"] and local_realm_tension > 0.0:
				hook_text = "%s is heating up around contested control this year." % str(faction.get("name", "A faction"))
			elif faction_kind == "justice_institution" and (faction_pressure_value > 0.0 or local_claim_pressure > 0.0 or local_contested_claims > 0):
				if institution_type in ["police", "watch", "security"]:
					hook_text = "%s is tightening its grip as law pressure rises this year." % str(faction.get("name", "A faction"))
				elif institution_type in ["court", "tribunal", "magistrate"]:
					hook_text = "%s is weighing heavy cases and contested law this year." % str(faction.get("name", "A faction"))
				elif institution_type in ["prison", "gaol", "dungeon", "detention"]:
					hook_text = "%s is carrying the strain of punishment and confinement this year." % str(faction.get("name", "A faction"))
				else:
					hook_text = "%s is exerting legal pressure on the world around it this year." % str(faction.get("name", "A faction"))
			_insert_ranked_hotspot(hotspots, {
				"faction_id": str(faction.get("id", faction_key)),
				"name": str(faction.get("name", "A faction")),
				"kind": faction_kind,
				"institution_type": institution_type,
				"pressure": faction_pressure_value,
				"visibility": faction_visibility,
				"hostility": faction_hostility,
				"claim_pressure": local_claim_pressure,
				"contested_claims": local_contested_claims,
				"realm_tension": local_realm_tension,
				"hidden_realm_instability": local_hidden_realm_instability,
				"hook_text": hook_text,
				"_sort": faction_pressure_value + local_claim_pressure + (faction_hostility * 0.15) + (local_hidden_realm_instability * 8.0) + (local_realm_tension * 4.0)
			}, 5)
			if player_is_current:
				var local_pressure_score: float = faction_pressure_value + local_claim_pressure + (faction_hostility * 0.15) + (float(local_contested_claims) * 1.25)
				if faction_kind == "workplace":
					workplace_pressure += local_pressure_score
					var workplace_label: String = str(faction.get("company_name", faction.get("name", "Your workplace"))).strip_edges()
					var leader = gs.get_npc_by_id(int(faction.get("leader_id", -1)))
					if leader != null and leader.alive and int(leader.id) != npc_id:
						workplace_label = "%s %s's company" % [str(leader.first_name), str(leader.last_name)]
					if workplace_label == "":
						workplace_label = "Your workplace"
					if local_pressure_score > strongest_workplace_score:
						strongest_workplace_score = local_pressure_score
						strongest_workplace_name = workplace_label
				elif faction_kind == "dynasty" and membership_role in ["player_line", "ruler", "royal", "member"]:
					dynasty_pressure += local_pressure_score
					var dynasty_label: String = str(faction.get("name", "Your family dynasty")).strip_edges()
					if dynasty_label == "":
						dynasty_label = "Your family dynasty"
					if local_pressure_score > strongest_dynasty_score:
						strongest_dynasty_score = local_pressure_score
						strongest_dynasty_name = dynasty_label
				elif faction_kind in ["locality", "locality_affinity"]:
					neighborhood_pressure += local_pressure_score
					housing_pressure += local_claim_pressure + (float(local_contested_claims) * 1.2) + (faction_hostility * 0.1)
					var neighborhood_label: String = str(faction.get("name", "Your neighborhood")).strip_edges()
					if neighborhood_label == "":
						neighborhood_label = "Your neighborhood"
					if local_pressure_score > strongest_neighborhood_score:
						strongest_neighborhood_score = local_pressure_score
						strongest_neighborhood_name = neighborhood_label
				elif faction_kind == "justice_institution":
					surveillance_pressure += local_justice_pressure
		if faction_count <= 0:
			continue
		var existing_bias_raw: Variant = gs.transient_scenario_biases.get(npc_id, {})
		var existing_bias_bucket: Array = []
		var existing_bias: Dictionary = {}
		if typeof(existing_bias_raw) == TYPE_ARRAY:
			existing_bias_bucket = existing_bias_raw.duplicate(true)
			if not existing_bias_bucket.is_empty() and typeof(existing_bias_bucket [0]) == TYPE_DICTIONARY:
				existing_bias = existing_bias_bucket [0]
		elif typeof(existing_bias_raw) == TYPE_DICTIONARY:
			existing_bias = existing_bias_raw.duplicate(true)
		var faction_bias_raw: Variant = existing_bias.get("faction_pressure", {})
		var faction_bias: Dictionary = faction_bias_raw if typeof(faction_bias_raw) == TYPE_DICTIONARY else {}
		faction_bias ["pressure_total"] = float(faction_bias.get("pressure_total", 0.0)) + total_pressure
		faction_bias ["membership_count"] = int(faction_count)
		faction_bias ["visibility"] = max_visibility
		faction_bias ["contested_claims_total"] = int(faction_bias.get("contested_claims_total", 0)) + contested_claims_total
		faction_bias ["claim_pressure_total"] = float(faction_bias.get("claim_pressure_total", 0.0)) + claim_pressure_total
		faction_bias ["hostility_total"] = float(faction_bias.get("hostility_total", 0.0)) + hostility_total
		faction_bias ["contested_realm_tension"] = float(faction_bias.get("contested_realm_tension", 0.0)) + contested_realm_tension
		faction_bias ["coup_pressure"] = float(faction_bias.get("coup_pressure", 0.0)) + coup_pressure
		faction_bias ["syndicate_turf_pressure"] = float(faction_bias.get("syndicate_turf_pressure", 0.0)) + syndicate_turf_pressure
		faction_bias ["royal_succession_tension"] = float(faction_bias.get("royal_succession_tension", 0.0)) + royal_succession_tension
		faction_bias ["diaspora_pull"] = float(faction_bias.get("diaspora_pull", 0.0)) + diaspora_pull
		faction_bias ["hidden_realm_instability"] = float(faction_bias.get("hidden_realm_instability", 0.0)) + hidden_realm_instability
		faction_bias ["justice_pressure"] = float(faction_bias.get("justice_pressure", 0.0)) + justice_pressure
		faction_bias ["court_pressure"] = float(faction_bias.get("court_pressure", 0.0)) + court_pressure
		faction_bias ["prison_pressure"] = float(faction_bias.get("prison_pressure", 0.0)) + prison_pressure
		faction_bias ["kind_presence"] = kind_presence.duplicate(true)
		faction_bias ["hotspots"] = hotspots.slice(0, min(5, hotspots.size()))
		faction_bias ["expiry_year"] = int(gs.year) + 1
		if player_is_current:
			if workplace_pressure > 20.0:
				var workplace_text: String = "%s is under visible pressure this year." % (strongest_workplace_name if strongest_workplace_name != "" else "Your workplace")
				if strongest_workplace_score >= 55.0:
					workplace_text = "%s is losing stability this year." % (strongest_workplace_name if strongest_workplace_name != "" else "Your workplace")
				if not player_hook_seen.has(workplace_text):
					player_hook_seen [workplace_text] = true
					player_hook_rows.append({
						"type": "player_faction_workplace_hook",
						"text": workplace_text,
						"category": "faction"
					})
				player_consequence_rows.append({
					"key": "career_instability",
					"weight": workplace_pressure,
					"source_kind": "workplace",
					"faction_name": strongest_workplace_name,
					"expiry_year": int(gs.year) + 1
				})
			if dynasty_pressure > 18.0:
				var dynasty_text: String = "%s is losing power this year." % (strongest_dynasty_name if strongest_dynasty_name != "" else "Your family dynasty")
				if not player_hook_seen.has(dynasty_text):
					player_hook_seen [dynasty_text] = true
					player_hook_rows.append({
						"type": "player_faction_dynasty_hook",
						"text": dynasty_text,
						"category": "faction"
					})
				player_consequence_rows.append({
					"key": "dynasty_instability",
					"weight": dynasty_pressure,
					"source_kind": "dynasty",
					"faction_name": strongest_dynasty_name,
					"expiry_year": int(gs.year) + 1
				})
			if neighborhood_pressure > 16.0:
				var neighborhood_text: String = "Pressure is building around %s this year." % (strongest_neighborhood_name if strongest_neighborhood_name != "" else "your neighborhood")
				if strongest_neighborhood_score >= 45.0:
					neighborhood_text = "%s is getting tense this year." % (strongest_neighborhood_name if strongest_neighborhood_name != "" else "Your neighborhood")
				if not player_hook_seen.has(neighborhood_text):
					player_hook_seen [neighborhood_text] = true
					player_hook_rows.append({
						"type": "player_faction_neighborhood_hook",
						"text": neighborhood_text,
						"category": "faction"
					})
				player_consequence_rows.append({
					"key": "housing_instability",
					"weight": housing_pressure if housing_pressure > 0.0 else neighborhood_pressure,
					"source_kind": "locality",
					"faction_name": strongest_neighborhood_name,
					"expiry_year": int(gs.year) + 1
				})
			if surveillance_pressure > 14.0 or court_pressure > 10.0 or prison_pressure > 10.0:
				var justice_text: String = "Faction pressure is making the law feel closer to home this year."
				if not player_hook_seen.has(justice_text):
					player_hook_seen [justice_text] = true
					player_hook_rows.append({
						"type": "player_faction_justice_hook",
						"text": justice_text,
						"category": "faction"
					})
				player_consequence_rows.append({
					"key": "local_surveillance",
					"weight": surveillance_pressure + court_pressure + prison_pressure,
					"source_kind": "justice_institution",
					"faction_name": "Justice Orbit",
					"expiry_year": int(gs.year) + 1
				})
			faction_bias ["player_consequences"] = player_consequence_rows.slice(0, min(6, player_consequence_rows.size()))
			faction_bias ["personal_hooks"] = player_hook_rows.slice(0, min(5, player_hook_rows.size()))
			faction_bias ["workplace_pressure"] = workplace_pressure
			faction_bias ["dynasty_pressure"] = dynasty_pressure
			faction_bias ["neighborhood_pressure"] = neighborhood_pressure
			faction_bias ["housing_pressure"] = housing_pressure
			faction_bias ["surveillance_pressure"] = surveillance_pressure
			player_hotspots_snapshot = hotspots.slice(0, min(3, hotspots.size()))
			player_hook_rows_snapshot = player_hook_rows.duplicate(true)
		existing_bias ["faction_pressure"] = faction_bias
		var relationship_bias_raw: Variant = existing_bias.get("relationship_bias", {})
		var relationship_bias: Dictionary = relationship_bias_raw if typeof(relationship_bias_raw) == TYPE_DICTIONARY else {}
		relationship_bias ["social_visibility"] = float(relationship_bias.get("social_visibility", 0.0)) + (max_visibility * 0.05) + (diaspora_pull * 0.02)
		existing_bias ["relationship_bias"] = relationship_bias
		if player_is_current:
			var economy_bias_raw: Variant = existing_bias.get("economy_bias", {})
			var economy_bias: Dictionary = economy_bias_raw if typeof(economy_bias_raw) == TYPE_DICTIONARY else {}
			economy_bias ["career_instability"] = float(economy_bias.get("career_instability", 0.0)) + (workplace_pressure * 0.15)
			economy_bias ["housing_instability"] = float(economy_bias.get("housing_instability", 0.0)) + (housing_pressure * 0.12)
			existing_bias ["economy_bias"] = economy_bias
			var dynasty_bias_raw: Variant = existing_bias.get("dynasty_bias", {})
			var dynasty_bias: Dictionary = dynasty_bias_raw if typeof(dynasty_bias_raw) == TYPE_DICTIONARY else {}
			dynasty_bias ["power_decline"] = float(dynasty_bias.get("power_decline", 0.0)) + (dynasty_pressure * 0.2)
			existing_bias ["dynasty_bias"] = dynasty_bias
			var justice_bias_raw: Variant = existing_bias.get("justice_bias", {})
			var justice_bias: Dictionary = justice_bias_raw if typeof(justice_bias_raw) == TYPE_DICTIONARY else {}
			justice_bias ["local_surveillance"] = float(justice_bias.get("local_surveillance", 0.0)) + (surveillance_pressure * 0.18) + (court_pressure * 0.08) + (prison_pressure * 0.08)
			existing_bias ["justice_bias"] = justice_bias
		if existing_bias_bucket.is_empty():
			gs.transient_scenario_biases [npc_id] = existing_bias
		else:
			existing_bias_bucket [0] = existing_bias
			gs.transient_scenario_biases [npc_id] = existing_bias_bucket
	if typeof(plan) == TYPE_DICTIONARY:
		var mailboxes_raw: Variant = plan.get("mailboxes", {})
		var mailboxes: Dictionary = mailboxes_raw if typeof(mailboxes_raw) == TYPE_DICTIONARY else {}
		if typeof(mailboxes) == TYPE_DICTIONARY:
			var scenario_box_raw: Variant = mailboxes.get("scenario", [])
			var scenario_box: Array = scenario_box_raw if typeof(scenario_box_raw) == TYPE_ARRAY else []
			for raw_hook in global_pressure_hooks:
				if typeof(raw_hook) != TYPE_DICTIONARY:
					continue
				scenario_box.append((raw_hook as Dictionary).duplicate(true))
			for hotspot_index in range(min(3, player_hotspots_snapshot.size())):
				var hotspot: Dictionary = player_hotspots_snapshot [hotspot_index]
				var hook_text: String = str(hotspot.get("hook_text", "")).strip_edges()
				if hook_text == "":
					continue
				scenario_box.append({
					"type": "faction_hotspot_hook",
					"faction_id": str(hotspot.get("faction_id", "")),
					"text": hook_text,
					"category": "faction"
				})
			for raw_hook in player_hook_rows_snapshot:
				if typeof(raw_hook) != TYPE_DICTIONARY:
					continue
				scenario_box.append((raw_hook as Dictionary).duplicate(true))
			mailboxes ["scenario"] = scenario_box
			plan ["mailboxes"] = mailboxes
func _project_all_domains() -> void:
	_project_dynasties()
	_project_schools()
	_project_workplaces()
	_project_boxing_divisions()
	_project_vampire_covens()
	_project_realm_power_blocs()
	_project_royal_courts()
	_project_royal_claimants()
	_project_political_blocs()
	_project_crime_networks()
	_project_justice_institutions()
	_project_locality_factions()
	_project_many_realms_circles()
	_project_contract_defined_factions()

func _consume_dirty_projection_keys() -> Array:
	var keys: Array = []
	for raw_domain_key in domain_dirty_flags.keys():
		var domain_key: String = str(raw_domain_key).strip_edges()
		if domain_key == "":
			continue
		keys.append(domain_key)
	domain_dirty_flags.clear()
	return keys

func _remove_domain_factions_for_domain(domain_key: String, touched_faction_ids: Dictionary) -> void:
	var faction_ids: Array = faction_registry.keys()
	for raw_faction_id in faction_ids:
		var faction_id: String = str(raw_faction_id)
		var faction_raw: Variant = faction_registry.get(faction_id, {})
		var faction: Dictionary = faction_raw if typeof(faction_raw) == TYPE_DICTIONARY else {}
		if str(faction.get("domain", "")) != domain_key:
			continue
		touched_faction_ids [faction_id] = true
		faction_registry.erase(faction_id)

func _project_domain_if_dirty(domain_key: String, touched_faction_ids: Dictionary) -> void:
	match domain_key:
		"dynasty_engine":
			_project_dynasties()
		"school_engine":
			_project_schools()
		"workplace_engine":
			_project_workplaces()
		"boxing_engine":
			_project_boxing_divisions()
		"vampire_society_engine":
			_project_vampire_covens()
		"realm_engine":
			_project_realm_power_blocs()
		"royalty_engine":
			_project_royal_courts()
			_project_royal_claimants()
		"politics_engine":
			_project_political_blocs()
		"crime_engine":
			_project_crime_networks()
		"justice_engine":
			_project_justice_institutions()
		"place_influence_engine":
			_project_locality_factions()
		"many_realms_engine":
			_project_many_realms_circles()
		"faction_contract_layer", "faction_contracts":
			_project_contract_defined_factions(touched_faction_ids)
		"all", "*":
			_project_all_domains()
		_:
			return

	_collect_domain_faction_ids(domain_key, touched_faction_ids)

func _collect_domain_faction_ids(domain_key: String, touched_faction_ids: Dictionary) -> void:
	for raw_faction_id in faction_registry.keys():
		var faction_id: String = str(raw_faction_id)
		var faction_raw: Variant = faction_registry.get(faction_id, {})
		var faction: Dictionary = faction_raw if typeof(faction_raw) == TYPE_DICTIONARY else {}
		if faction.is_empty():
			continue
		if domain_key in ["all", "*"] or str(faction.get("domain", "")) == domain_key:
			touched_faction_ids [faction_id] = true

func _cleanup_dead_members_and_collect_touched_factions() -> Dictionary:
	var touched_faction_ids: Dictionary = {}
	for raw_faction_id in faction_registry.keys():
		var faction_id: String = str(raw_faction_id)
		var faction_raw: Variant = faction_registry.get(faction_id, {})
		var faction: Dictionary = faction_raw if typeof(faction_raw) == TYPE_DICTIONARY else {}
		var members_raw: Variant = faction.get("member_ids", {})
		var members: Dictionary = members_raw if typeof(members_raw) == TYPE_DICTIONARY else {}
		var cleaned: Dictionary = {}
		var removed_any: bool = false

		for raw_member_key in members.keys():
			var member: Dictionary = members.get(raw_member_key, {})
			var npc_id: int = int(member.get("npc_id", -1))
			var npc = gs.get_npc_by_id(npc_id)
			if npc == null or not npc.alive:
				removed_any = true
				continue
			cleaned [str(npc_id)] = member

		if removed_any:
			faction ["member_ids"] = cleaned
			_finalize_faction(faction)
			faction_registry [faction_id] = faction
			touched_faction_ids [faction_id] = true

	return touched_faction_ids

func _refresh_membership_index_for_factions(touched_faction_ids: Dictionary = {}) -> void:
	if touched_faction_ids.is_empty() or membership_index.is_empty():
		_rebuild_membership_index()
		return

	for raw_npc_key in membership_index.keys().duplicate():
		var npc_key: String = str(raw_npc_key)
		var bucket_raw: Variant = membership_index.get(npc_key, {})
		var bucket: Dictionary = bucket_raw if typeof(bucket_raw) == TYPE_DICTIONARY else {}
		var bucket_changed: bool = false

		for raw_faction_id in touched_faction_ids.keys():
			var faction_id: String = str(raw_faction_id)
			if bucket.has(faction_id):
				bucket.erase(faction_id)
				bucket_changed = true

		if bucket_changed:
			if bucket.is_empty():
				membership_index.erase(npc_key)
			else:
				membership_index [npc_key] = bucket

	for raw_faction_id in touched_faction_ids.keys():
		var faction_id: String = str(raw_faction_id)
		var faction_raw: Variant = faction_registry.get(faction_id, {})
		var faction: Dictionary = faction_raw if typeof(faction_raw) == TYPE_DICTIONARY else {}
		var members_raw: Variant = faction.get("member_ids", {})
		var members: Dictionary = members_raw if typeof(members_raw) == TYPE_DICTIONARY else {}

		for raw_member_key in members.keys():
			var member: Dictionary = members.get(raw_member_key, {})
			var npc_id: int = int(member.get("npc_id", -1))
			if npc_id <= 0:
				continue
			var npc_key: String = str(npc_id)
			if not membership_index.has(npc_key):
				membership_index [npc_key] = {}
			membership_index [npc_key] [faction_id] = {
				"faction_name": str(faction.get("name", "")),
				"kind": str(faction.get("kind", "")),
				"role": str(member.get("role", "member")),
				"active": bool(member.get("active", true)),
				"joined_year": int(member.get("joined_year", gs.year))
			}

func _refresh_territory_index_for_factions(touched_faction_ids: Dictionary = {}) -> void:
	if touched_faction_ids.is_empty() or territory_index.is_empty():
		_rebuild_territory_index()
		return

	for raw_territory_id in territory_index.keys().duplicate():
		var territory_id: String = str(raw_territory_id)
		var bucket_raw: Variant = territory_index.get(territory_id, {})
		var bucket: Dictionary = bucket_raw if typeof(bucket_raw) == TYPE_DICTIONARY else {}
		var bucket_changed: bool = false

		for raw_faction_id in touched_faction_ids.keys():
			var faction_id: String = str(raw_faction_id)
			if bucket.has(faction_id):
				bucket.erase(faction_id)
				bucket_changed = true

		if bucket_changed:
			if bucket.is_empty():
				territory_index.erase(territory_id)
			else:
				territory_index [territory_id] = bucket

	for raw_faction_id in touched_faction_ids.keys():
		var faction_id: String = str(raw_faction_id)
		var faction_raw: Variant = faction_registry.get(faction_id, {})
		var faction: Dictionary = faction_raw if typeof(faction_raw) == TYPE_DICTIONARY else {}
		var territories_raw: Variant = faction.get("territories", {})
		var territories: Dictionary = territories_raw if typeof(territories_raw) == TYPE_DICTIONARY else {}

		for raw_territory_id in territories.keys():
			var territory_id: String = str(raw_territory_id)
			if not territory_index.has(territory_id):
				territory_index [territory_id] = {}
			territory_index [territory_id] [faction_id] = float(territories.get(territory_id, 0.0))

func _ensure_relationship_graph_nodes_for_active_factions() -> void:
	for raw_faction_id in relationship_graph.keys().duplicate():
		var faction_id: String = str(raw_faction_id)
		if faction_registry.has(faction_id):
			continue
		relationship_graph.erase(faction_id)

	for raw_faction_id in faction_registry.keys():
		var faction_id: String = str(raw_faction_id)
		if not relationship_graph.has(faction_id):
			relationship_graph [faction_id] = {}

func _clear_relationship_edges_for_factions(faction_ids: Dictionary) -> void:
	for raw_faction_id in faction_ids.keys():
		var faction_id: String = str(raw_faction_id)
		var existing_edges_raw: Variant = relationship_graph.get(faction_id, {})
		var existing_edges: Dictionary = existing_edges_raw if typeof(existing_edges_raw) == TYPE_DICTIONARY else {}

		for raw_other_id in existing_edges.keys():
			var other_id: String = str(raw_other_id)
			var other_edges_raw: Variant = relationship_graph.get(other_id, {})
			var other_edges: Dictionary = other_edges_raw if typeof(other_edges_raw) == TYPE_DICTIONARY else {}
			if other_edges.has(faction_id):
				other_edges.erase(faction_id)
				relationship_graph [other_id] = other_edges

		relationship_graph [faction_id] = {}

func _relationship_pair_matches_target_filter(target_filter: Dictionary, a_id: String, b_id: String) -> bool:
	if target_filter.is_empty():
		return true
	return target_filter.has(a_id) or target_filter.has(b_id)

func _build_relationship_graph_target_set(touched_faction_ids: Dictionary, prioritize_player_orbit: bool = false) -> Dictionary:
	var target: Dictionary = {}

	for raw_faction_id in touched_faction_ids.keys():
		target [str(raw_faction_id)] = true

	if prioritize_player_orbit and gs != null and gs.player != null:
		var player_memberships_raw: Variant = membership_index.get(str(int(gs.player.id)), {})
		var player_memberships: Dictionary = player_memberships_raw if typeof(player_memberships_raw) == TYPE_DICTIONARY else {}
		for raw_faction_id in player_memberships.keys():
			target [str(raw_faction_id)] = true

	if target.is_empty():
		return target

	_expand_relationship_graph_target_set_from_memberships(target)
	_expand_relationship_graph_target_set_from_territories(target)
	_expand_relationship_graph_target_set_from_realm_links(target)
	_expand_relationship_graph_target_set_from_claims(target)

	return target

func _expand_relationship_graph_target_set_from_memberships(target: Dictionary) -> void:
	for raw_member_key in membership_index.keys():
		var memberships_raw: Variant = membership_index.get(raw_member_key, {})
		var memberships: Dictionary = memberships_raw if typeof(memberships_raw) == TYPE_DICTIONARY else {}
		var include_group: bool = false

		for raw_faction_id in memberships.keys():
			if target.has(str(raw_faction_id)):
				include_group = true
				break

		if not include_group:
			continue

		for raw_faction_id in memberships.keys():
			target [str(raw_faction_id)] = true

func _expand_relationship_graph_target_set_from_territories(target: Dictionary) -> void:
	for raw_territory_id in territory_index.keys():
		var territory_raw: Variant = territory_index.get(raw_territory_id, {})
		var territory_factions: Dictionary = territory_raw if typeof(territory_raw) == TYPE_DICTIONARY else {}
		var include_group: bool = false

		for raw_faction_id in territory_factions.keys():
			if target.has(str(raw_faction_id)):
				include_group = true
				break

		if not include_group:
			continue

		for raw_faction_id in territory_factions.keys():
			target [str(raw_faction_id)] = true

func _expand_relationship_graph_target_set_from_realm_links(target: Dictionary) -> void:
	var realm_ids: Dictionary = {}
	var hidden_realm_ids: Dictionary = {}
	var special_kinds: Dictionary = {}

	for raw_faction_id in target.keys():
		var faction_id: String = str(raw_faction_id)
		var faction_raw: Variant = faction_registry.get(faction_id, {})
		var faction: Dictionary = faction_raw if typeof(faction_raw) == TYPE_DICTIONARY else {}
		if faction.is_empty():
			continue

		var realm_id: String = str(faction.get("realm_id", "")).strip_edges()
		var hidden_realm_id: String = str(faction.get("hidden_realm_id", "")).strip_edges()
		var kind: String = str(faction.get("kind", "")).strip_edges()

		if realm_id != "":
			realm_ids [realm_id] = true
		if hidden_realm_id != "":
			hidden_realm_ids [hidden_realm_id] = true
		if kind in ["boxing_division", "vampire_coven"]:
			special_kinds [kind] = true

	for raw_faction_id in faction_registry.keys():
		var faction_id: String = str(raw_faction_id)
		var faction_raw: Variant = faction_registry.get(faction_id, {})
		var faction: Dictionary = faction_raw if typeof(faction_raw) == TYPE_DICTIONARY else {}
		if faction.is_empty():
			continue

		var realm_id: String = str(faction.get("realm_id", "")).strip_edges()
		var hidden_realm_id: String = str(faction.get("hidden_realm_id", "")).strip_edges()
		var kind: String = str(faction.get("kind", "")).strip_edges()

		if realm_id != "" and realm_ids.has(realm_id):
			target [faction_id] = true
		if hidden_realm_id != "" and hidden_realm_ids.has(hidden_realm_id):
			target [faction_id] = true
		if special_kinds.has(kind):
			target [faction_id] = true

func _expand_relationship_graph_target_set_from_claims(target: Dictionary) -> void:
	var claim_index: Dictionary = _build_claim_resource_index()
	for raw_claim_key in claim_index.keys():
		var claimants_raw: Variant = claim_index.get(raw_claim_key, [])
		var claimants: Array = claimants_raw if typeof(claimants_raw) == TYPE_ARRAY else []
		var include_group: bool = false

		for raw_claimant in claimants:
			var claimant: Dictionary = raw_claimant if typeof(raw_claimant) == TYPE_DICTIONARY else {}
			if target.has(str(claimant.get("faction_id", ""))):
				include_group = true
				break

		if not include_group:
			continue

		for raw_claimant in claimants:
			var claimant: Dictionary = raw_claimant if typeof(raw_claimant) == TYPE_DICTIONARY else {}
			var faction_id: String = str(claimant.get("faction_id", ""))
			if faction_id == "":
				continue
			target [faction_id] = true

func _rebuild_relationship_graph_pairs(target_filter: Dictionary = {}) -> void:
	var pair_edges: Dictionary = {}
	var realm_groups: Dictionary = {}
	var hidden_realm_groups: Dictionary = {}
	var special_kind_groups: Dictionary = {}

	for raw_faction_id in faction_registry.keys():
		var faction_id: String = str(raw_faction_id)
		if target_filter.is_empty():
			relationship_graph [faction_id] = {}
		elif not relationship_graph.has(faction_id):
			relationship_graph [faction_id] = {}

		var faction_raw: Variant = faction_registry.get(faction_id, {})
		var faction: Dictionary = faction_raw if typeof(faction_raw) == TYPE_DICTIONARY else {}
		if faction.is_empty():
			continue

		var realm_id: String = str(faction.get("realm_id", "")).strip_edges()
		if realm_id != "":
			if not realm_groups.has(realm_id):
				realm_groups [realm_id] = []
			realm_groups [realm_id].append(faction_id)

		var hidden_realm_id: String = str(faction.get("hidden_realm_id", "")).strip_edges()
		if hidden_realm_id != "":
			if not hidden_realm_groups.has(hidden_realm_id):
				hidden_realm_groups [hidden_realm_id] = []
			hidden_realm_groups [hidden_realm_id].append(faction_id)

		var kind: String = str(faction.get("kind", "")).strip_edges()
		if kind in ["boxing_division", "vampire_coven"]:
			if not special_kind_groups.has(kind):
				special_kind_groups [kind] = []
			special_kind_groups [kind].append(faction_id)

	for raw_member_key in membership_index.keys():
		var memberships_raw: Variant = membership_index.get(raw_member_key, {})
		var memberships: Dictionary = memberships_raw if typeof(memberships_raw) == TYPE_DICTIONARY else {}
		var member_faction_ids: Array = memberships.keys()

		for i in range(member_faction_ids.size()):
			for j in range(i + 1, member_faction_ids.size()):
				var a_id: String = str(member_faction_ids [i])
				var b_id: String = str(member_faction_ids [j])
				if not _relationship_pair_matches_target_filter(target_filter, a_id, b_id):
					continue
				_bump_relationship_pair_metric(pair_edges, a_id, b_id, "shared_members", 1.0)

	for raw_territory_id in territory_index.keys():
		var territory_raw: Variant = territory_index.get(raw_territory_id, {})
		var territory_factions: Dictionary = territory_raw if typeof(territory_raw) == TYPE_DICTIONARY else {}
		var territory_faction_ids: Array = territory_factions.keys()

		for i in range(territory_faction_ids.size()):
			for j in range(i + 1, territory_faction_ids.size()):
				var a_id: String = str(territory_faction_ids [i])
				var b_id: String = str(territory_faction_ids [j])
				if not _relationship_pair_matches_target_filter(target_filter, a_id, b_id):
					continue
				_bump_relationship_pair_metric(pair_edges, a_id, b_id, "shared_territories", 1.0)

	var claim_index: Dictionary = _build_claim_resource_index()
	for raw_claim_key in claim_index.keys():
		var claimants_raw: Variant = claim_index.get(raw_claim_key, [])
		var claimants: Array = claimants_raw if typeof(claimants_raw) == TYPE_ARRAY else []

		for i in range(claimants.size()):
			var a_raw: Variant = claimants [i]
			var a: Dictionary = a_raw if typeof(a_raw) == TYPE_DICTIONARY else {}
			var a_id: String = str(a.get("faction_id", ""))
			var a_value: float = float(a.get("value", 0.0))
			if a_id == "" or a_value <= 0.0:
				continue

			for j in range(i + 1, claimants.size()):
				var b_raw: Variant = claimants [j]
				var b: Dictionary = b_raw if typeof(b_raw) == TYPE_DICTIONARY else {}
				var b_id: String = str(b.get("faction_id", ""))
				var b_value: float = float(b.get("value", 0.0))
				if b_id == "" or b_value <= 0.0:
					continue
				if not _relationship_pair_matches_target_filter(target_filter, a_id, b_id):
					continue

				_bump_relationship_pair_metric(pair_edges, a_id, b_id, "contested_claims", 1.0)
				_bump_relationship_pair_metric(pair_edges, a_id, b_id, "claim_pressure", min(a_value, b_value) * 4.0)

	for raw_realm_id in realm_groups.keys():
		var faction_ids: Array = realm_groups.get(raw_realm_id, [])
		for i in range(faction_ids.size()):
			for j in range(i + 1, faction_ids.size()):
				var a_id: String = str(faction_ids [i])
				var b_id: String = str(faction_ids [j])
				if not _relationship_pair_matches_target_filter(target_filter, a_id, b_id):
					continue
				_set_relationship_pair_flag(pair_edges, a_id, b_id, "contested_realm", true)

	for raw_hidden_realm_id in hidden_realm_groups.keys():
		var faction_ids: Array = hidden_realm_groups.get(raw_hidden_realm_id, [])
		for i in range(faction_ids.size()):
			for j in range(i + 1, faction_ids.size()):
				var a_id: String = str(faction_ids [i])
				var b_id: String = str(faction_ids [j])
				if not _relationship_pair_matches_target_filter(target_filter, a_id, b_id):
					continue
				_set_relationship_pair_flag(pair_edges, a_id, b_id, "contested_hidden_realm", true)

	for raw_kind in special_kind_groups.keys():
		var faction_ids: Array = special_kind_groups.get(raw_kind, [])
		for i in range(faction_ids.size()):
			for j in range(i + 1, faction_ids.size()):
				var a_id: String = str(faction_ids [i])
				var b_id: String = str(faction_ids [j])
				if not _relationship_pair_matches_target_filter(target_filter, a_id, b_id):
					continue
				_set_relationship_pair_flag(pair_edges, a_id, b_id, "special_kind_pair", true)

	for raw_pair_key in pair_edges.keys():
		var bucket_raw: Variant = pair_edges.get(raw_pair_key, {})
		var bucket: Dictionary = bucket_raw if typeof(bucket_raw) == TYPE_DICTIONARY else {}
		var a_id: String = str(bucket.get("a_id", ""))
		var b_id: String = str(bucket.get("b_id", ""))
		if a_id == "" or b_id == "":
			continue

		var a_raw: Variant = faction_registry.get(a_id, {})
		var a: Dictionary = a_raw if typeof(a_raw) == TYPE_DICTIONARY else {}
		var b_raw: Variant = faction_registry.get(b_id, {})
		var b: Dictionary = b_raw if typeof(b_raw) == TYPE_DICTIONARY else {}
		if a.is_empty() or b.is_empty():
			continue

		var same_kind: bool = str(a.get("kind", "")) == str(b.get("kind", ""))
		var same_domain: bool = str(a.get("domain", "")) == str(b.get("domain", ""))
		var contested_realm: bool = bool(bucket.get("contested_realm", false))
		var contested_hidden_realm: bool = bool(bucket.get("contested_hidden_realm", false))
		var shared_members: int = int(round(float(bucket.get("shared_members", 0.0))))
		var shared_territories: int = int(round(float(bucket.get("shared_territories", 0.0))))
		var contested_claims: int = int(round(float(bucket.get("contested_claims", 0.0))))
		var claim_pressure: float = float(bucket.get("claim_pressure", 0.0))
		var hostility: float = 0.0

		if str(a.get("kind", "")) == "boxing_division" and str(b.get("kind", "")) == "boxing_division":
			hostility += 20.0
		if str(a.get("kind", "")) == "vampire_coven" and str(b.get("kind", "")) == "vampire_coven":
			hostility += 12.0
		if contested_realm:
			hostility += 10.0
		if contested_hidden_realm:
			hostility += 14.0
		hostility += float(shared_territories) * 3.0
		hostility += float(contested_claims) * 9.0
		hostility += claim_pressure

		var edge: Dictionary = {
			"shared_members": shared_members,
			"shared_territories": shared_territories,
			"contested_claims": contested_claims,
			"claim_pressure": claim_pressure,
			"same_kind": same_kind,
			"same_domain": same_domain,
			"contested_realm": contested_realm,
			"contested_hidden_realm": contested_hidden_realm,
			"hostility": hostility
		}

		if not relationship_graph.has(a_id):
			relationship_graph [a_id] = {}
		if not relationship_graph.has(b_id):
			relationship_graph [b_id] = {}

		relationship_graph [a_id] [b_id] = edge
		relationship_graph [b_id] [a_id] = edge

func _should_prioritize_player_orbit_for_choice_surface(plan:= {}, _metrics:= {}) -> bool:
	var prioritize_player_orbit: bool = membership_index.size() >= 180 or faction_registry.size() >= 140

	var runtime_guard_raw: Variant = gs.scenario_state.get("runtime_guard", {}) if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY else {}
	var runtime_guard: Dictionary = runtime_guard_raw if typeof(runtime_guard_raw) == TYPE_DICTIONARY else {}
	if bool(runtime_guard.get("defer_noncritical_systems", false)) or bool(runtime_guard.get("reduce_scenario_density", false)):
		prioritize_player_orbit = true

	if typeof(plan) == TYPE_DICTIONARY:
		var execution_manifest_raw: Variant = plan.get("execution_manifest", {})
		var execution_manifest: Dictionary = execution_manifest_raw if typeof(execution_manifest_raw) == TYPE_DICTIONARY else {}
		if bool(execution_manifest.get("compressed_execution", false)) or bool(execution_manifest.get("prioritize_player_orbit", false)):
			prioritize_player_orbit = true

	return prioritize_player_orbit

func _add_choice_surface_npc_candidate(ordered: Array, seen: Dictionary, npc_id: int) -> void:
	if npc_id <= 0:
		return
	var npc_key: String = str(npc_id)
	if seen.has(npc_key):
		return
	seen [npc_key] = true
	ordered.append(npc_id)

func _append_choice_surface_candidates_from_faction(faction_id: String, ordered: Array, seen: Dictionary) -> void:
	var faction_raw: Variant = faction_registry.get(faction_id, {})
	var faction: Dictionary = faction_raw if typeof(faction_raw) == TYPE_DICTIONARY else {}
	var members_raw: Variant = faction.get("member_ids", {})
	var members: Dictionary = members_raw if typeof(members_raw) == TYPE_DICTIONARY else {}

	for raw_member_key in members.keys():
		var member: Dictionary = members.get(raw_member_key, {})
		_add_choice_surface_npc_candidate(ordered, seen, int(member.get("npc_id", -1)))

func _build_choice_surface_npc_priority_list(plan:= {}, _metrics:= {}) -> Array:
	var ordered: Array = []
	var seen: Dictionary = {}
	var prioritize_player_orbit: bool = _should_prioritize_player_orbit_for_choice_surface(plan, _metrics)

	if gs != null and gs.player != null:
		_add_choice_surface_npc_candidate(ordered, seen, int(gs.player.id))

	if not prioritize_player_orbit:
		for raw_npc_key in membership_index.keys():
			_add_choice_surface_npc_candidate(ordered, seen, int(raw_npc_key))
		return ordered

	if gs != null and gs.player != null:
		var player_memberships_raw: Variant = membership_index.get(str(int(gs.player.id)), {})
		var player_memberships: Dictionary = player_memberships_raw if typeof(player_memberships_raw) == TYPE_DICTIONARY else {}
		for raw_faction_id in player_memberships.keys():
			_append_choice_surface_candidates_from_faction(str(raw_faction_id), ordered, seen)

	var max_candidates: int = max(24, min(96, int(membership_index.size())))
	for raw_npc_key in membership_index.keys():
		if ordered.size() >= max_candidates:
			break
		_add_choice_surface_npc_candidate(ordered, seen, int(raw_npc_key))

	return ordered

func _insert_ranked_hook(ranked_hooks: Array, row: Dictionary, max_hooks: int) -> void:
	if max_hooks <= 0:
		return
	var row_sort: float = float(row.get("_sort", 0.0))
	var inserted: bool = false
	for index in range(ranked_hooks.size()):
		if row_sort > float(ranked_hooks [index].get("_sort", 0.0)):
			ranked_hooks.insert(index, row)
			inserted = true
			break
	if not inserted and ranked_hooks.size() < max_hooks:
		ranked_hooks.append(row)
	if ranked_hooks.size() > max_hooks:
		ranked_hooks.resize(max_hooks)

func _build_global_pressure_hooks(max_hooks: int = 18) -> Array:
	var ranked_hooks: Array = []
	for raw_faction_id in faction_registry.keys():
		var faction_id: String = str(raw_faction_id)
		var faction_raw: Variant = faction_registry.get(faction_id, {})
		var faction: Dictionary = faction_raw if typeof(faction_raw) == TYPE_DICTIONARY else {}
		var pressure_value: float = float(faction.get("pressure", 0.0))
		if pressure_value < 40.0:
			continue
		_insert_ranked_hook(ranked_hooks, {
			"_sort": pressure_value,
			"hook": {
				"type": "faction_pressure_hook",
				"faction_id": str(faction.get("id", "")),
				"text": "%s is exerting visible pressure on its orbit this year." %
				str(faction.get("name", "A faction")),
				"category": "faction"
			}
		}, max_hooks)
	var hooks: Array = []
	for index in range(ranked_hooks.size()):
		var hook_raw: Variant = ranked_hooks [index].get("hook", {})
		if typeof(hook_raw) != TYPE_DICTIONARY:
			continue
		hooks.append((hook_raw as Dictionary).duplicate(true))
	return hooks

func yearly_narrative_surface(plan:= {}, _metrics:= {}) -> void:
	if gs == null:
		return
	_ensure_state()

	var compacted_bundle: Dictionary = _drain_compacted_pending_packet_bundles()

	if typeof(plan) == TYPE_DICTIONARY:
		var mailboxes: Dictionary = plan.get("mailboxes", {})
		if typeof(mailboxes) == TYPE_DICTIONARY:
			var delta_packets: Array = mailboxes.get("delta_packets", [])

			for packet in pending_delta_packets:
				delta_packets.append(packet)

			var compacted_delta_raw: Variant = compacted_bundle.get("delta_packets", [])
			var compacted_delta_packets: Array = compacted_delta_raw if typeof(compacted_delta_raw) == TYPE_ARRAY else []
			for packet in compacted_delta_packets:
				delta_packets.append(packet)

			mailboxes ["delta_packets"] = delta_packets
			plan ["mailboxes"] = mailboxes

	_emit_pending_bus_events()

	var compacted_bus_raw: Variant = compacted_bundle.get("bus_events", [])
	var compacted_bus_events: Array = compacted_bus_raw if typeof(compacted_bus_raw) == TYPE_ARRAY else []
	_emit_compacted_pending_bus_events(compacted_bus_events)

	pending_delta_packets.clear()
	pending_bus_events.clear()
func _should_compact_pending_faction_event(event_name: String, player_relevant: bool) -> bool:
	if player_relevant:
		return false

	if event_name not in [
		ActionEventTypes.FACTION_PRESSURE_SPIKE,
		ActionEventTypes.FACTION_PEAKED,
		ActionEventTypes.FACTION_DECLINED
	]:
		return false

	return pending_delta_packets.size() >= 24 or pending_bus_events.size() >= 12


func _get_pending_packet_compaction_state() -> Dictionary:
	if gs == null:
		return {}

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var state_raw: Variant = gs.scenario_state.get("_universal_faction_pending_compaction", {})
	var state: Dictionary = state_raw if typeof(state_raw) == TYPE_DICTIONARY else {}

	if state.is_empty():
		state = {
			"buckets": {}
		}
		gs.scenario_state ["_universal_faction_pending_compaction"] = state

	return state


func _set_pending_packet_compaction_state(state: Dictionary) -> void:
	if gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	gs.scenario_state ["_universal_faction_pending_compaction"] = state


func _queue_compacted_packet_bundle(faction: Dictionary, event_name: String, _text: String, relevant_npc_id: int, player_relevant: bool) -> void:
	var state: Dictionary = _get_pending_packet_compaction_state()
	var buckets_raw: Variant = state.get("buckets", {})
	var buckets: Dictionary = buckets_raw if typeof(buckets_raw) == TYPE_DICTIONARY else {}

	var bucket_key: String = "%s|%s|%d" % [
		event_name,
		str(faction.get("kind", "")),
		1 if player_relevant else 0
	]

	var bucket_raw: Variant = buckets.get(bucket_key, {})
	var bucket: Dictionary = bucket_raw if typeof(bucket_raw) == TYPE_DICTIONARY else {}

	if bucket.is_empty():
		bucket = {
			"event_name": event_name,
			"faction_kind": str(faction.get("kind", "")),
			"count": 0,
			"year": int(gs.year),
			"player_relevant": player_relevant,
			"representative_npc_id": relevant_npc_id,
			"max_pressure": 0.0,
			"faction_names": []
		}

	bucket ["count"] = int(bucket.get("count", 0)) + 1

	if int(bucket.get("representative_npc_id", -1)) <= 0 and relevant_npc_id > 0:
		bucket ["representative_npc_id"] = relevant_npc_id

	bucket ["max_pressure"] = max(
		float(bucket.get("max_pressure", 0.0)),
		float(faction.get("pressure", 0.0))
	)

	var names_raw: Variant = bucket.get("faction_names", [])
	var faction_names: Array = names_raw if typeof(names_raw) == TYPE_ARRAY else []
	var faction_name: String = str(faction.get("name", "A faction")).strip_edges()
	if faction_name != "" and not faction_names.has(faction_name) and faction_names.size() < 5:
		faction_names.append(faction_name)
	bucket ["faction_names"] = faction_names

	buckets [bucket_key] = bucket
	state ["buckets"] = buckets
	_set_pending_packet_compaction_state(state)


func _format_compacted_faction_name_preview(names: Array, total_count: int) -> String:
	var safe_names: Array = []
	for raw_name in names:
		var faction_name: String = str(raw_name).strip_edges()
		if faction_name == "":
			continue
		safe_names.append(faction_name)

	if safe_names.is_empty():
		return "%d factions" % total_count

	if safe_names.size() == 1 and total_count <= 1:
		return safe_names [0]

	if total_count > safe_names.size():
		return "%s, and %d others" % [", ".join(safe_names), max(0, total_count - safe_names.size())]

	return ", ".join(safe_names)


func _build_compacted_pending_packet_text(bucket: Dictionary) -> String:
	var event_name: String = str(bucket.get("event_name", ""))
	var count: int = int(bucket.get("count", 0))
	var names_raw: Variant = bucket.get("faction_names", [])
	var faction_names: Array = names_raw if typeof(names_raw) == TYPE_ARRAY else []
	var preview: String = _format_compacted_faction_name_preview(faction_names, count)

	match event_name:
		ActionEventTypes.FACTION_PRESSURE_SPIKE:
			return "\n🔥\n Pressure surged across %s this year." % preview
		ActionEventTypes.FACTION_PEAKED:
			return "\n🌟\n %s reached the height of their influence this year." % preview
		ActionEventTypes.FACTION_DECLINED:
			return "\n🕯\n %s began to decline this year." % preview
		_:
			return "\n🏛\n Major faction movement spread across %s this year." % preview


func _drain_compacted_pending_packet_bundles() -> Dictionary:
	var state: Dictionary = _get_pending_packet_compaction_state()
	var buckets_raw: Variant = state.get("buckets", {})
	var buckets: Dictionary = buckets_raw if typeof(buckets_raw) == TYPE_DICTIONARY else {}

	var delta_packets: Array = []
	var bus_events: Array = []

	for raw_bucket_key in buckets.keys():
		var bucket_raw: Variant = buckets.get(raw_bucket_key, {})
		var bucket: Dictionary = bucket_raw if typeof(bucket_raw) == TYPE_DICTIONARY else {}
		if bucket.is_empty():
			continue

		var text: String = _build_compacted_pending_packet_text(bucket)
		var representative_npc_id: int = int(bucket.get("representative_npc_id", -1))
		var event_name: String = str(bucket.get("event_name", ""))
		var count: int = int(bucket.get("count", 0))

		delta_packets.append({
			"type": "world_feed_entry",
			"entry": {
				"text": text,
				"year": int(bucket.get("year", gs.year)),
				"npc_id": representative_npc_id,
				"personally_relevant": bool(bucket.get("player_relevant", false)),
				"category": "faction",
				"event_name": event_name,
				"source": "universal_faction_engine"
			}
		})
		delta_packets.append({
			"type": "chronicle_entry",
			"text": text,
			"year": int(bucket.get("year", gs.year)),
			"source": "universal_faction_engine"
		})

		bus_events.append({
			"event_name": event_name,
			"payload": {
				"npc_id": representative_npc_id,
				"text": text,
				"faction_id": "",
				"faction_name": _format_compacted_faction_name_preview(
					bucket.get("faction_names", []),
					count
				),
				"faction_kind": str(bucket.get("faction_kind", "")),
				"member_count": 0,
				"pressure": float(bucket.get("max_pressure", 0.0)),
				"burst_count": count,
				"compacted_burst": true,
				"source": "universal_faction_engine"
			}
		})

	state ["buckets"] = {}
	_set_pending_packet_compaction_state(state)

	return {
		"delta_packets": delta_packets,
		"bus_events": bus_events
	}


func _emit_compacted_pending_bus_events(bus_events: Array) -> void:
	if gs == null or gs.event_bus == null:
		return
	for raw_entry in bus_events:
		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = raw_entry
		var event_name: String = str(entry.get("event_name", "")).strip_edges()
		var payload_raw: Variant = entry.get("payload", {})
		var payload: Dictionary = payload_raw if typeof(payload_raw) == TYPE_DICTIONARY else {}
		if event_name == "":
			continue
		payload ["event_name"] = event_name
		payload ["year"] = int(payload.get("year", gs.year))
		payload ["category"] = "faction"
		payload ["player_relevant"] = bool(payload.get("player_relevant", false))
		payload = _apply_event_bus_qos_defaults(payload, bool(payload.get("compacted_burst", false)))
		gs.event_bus.emit(event_name, payload)
func _resolve_payload_qos_tier(payload: Dictionary, compacted_burst: bool = false) -> String:
	var explicit_qos: String = str(payload.get("qos_tier", "")).strip_edges().to_lower()
	if explicit_qos in ["critical", "important", "ambient"]:
		return explicit_qos

	if compacted_burst:
		return "ambient"

	var fanout_priority: String = str(payload.get("fanout_priority", "")).strip_edges().to_lower()
	if fanout_priority in ["critical", "high"]:
		return "critical"
	if fanout_priority in ["ambient", "low"]:
		return "ambient"

	if bool(payload.get("player_relevant", false)):
		return "critical"
	return "important"


func _apply_event_bus_qos_defaults(payload: Dictionary, compacted_burst: bool = false) -> Dictionary:
	var normalized: Dictionary = payload.duplicate(true)
	var qos_tier: String = _resolve_payload_qos_tier(normalized, compacted_burst)
	normalized ["qos_tier"] = qos_tier

	match qos_tier:
		"critical":
			normalized ["fanout_priority"] = "high"
		"important":
			normalized ["fanout_priority"] = "normal"
		"ambient":
			normalized ["fanout_priority"] = "low"
		_:
			normalized ["fanout_priority"] = "normal"

	var fanout_hints_raw: Variant = normalized.get("fanout_hints", {})
	var fanout_hints: Dictionary = fanout_hints_raw if typeof(fanout_hints_raw) == TYPE_DICTIONARY else {}

	match qos_tier:
		"critical":
			fanout_hints ["skip_agent_memory_propagation"] = bool(fanout_hints.get("skip_agent_memory_propagation", false))
			fanout_hints ["skip_npc_memory_web"] = bool(fanout_hints.get("skip_npc_memory_web", false))
			fanout_hints ["skip_llm_bridge"] = bool(fanout_hints.get("skip_llm_bridge", false))
			fanout_hints ["skip_reputation"] = bool(fanout_hints.get("skip_reputation", false))
			fanout_hints ["allow_partial_propagation"] = false
		"important":
			fanout_hints ["skip_agent_memory_propagation"] = bool(fanout_hints.get("skip_agent_memory_propagation", false))
			fanout_hints ["skip_npc_memory_web"] = bool(fanout_hints.get("skip_npc_memory_web", false))
			fanout_hints ["skip_llm_bridge"] = bool(fanout_hints.get("skip_llm_bridge", false))
			fanout_hints ["skip_reputation"] = bool(fanout_hints.get("skip_reputation", false))
			fanout_hints ["allow_partial_propagation"] = true
		"ambient":
			fanout_hints ["skip_agent_memory_propagation"] = bool(fanout_hints.get("skip_agent_memory_propagation", true))
			fanout_hints ["skip_npc_memory_web"] = bool(fanout_hints.get("skip_npc_memory_web", true))
			fanout_hints ["skip_llm_bridge"] = bool(fanout_hints.get("skip_llm_bridge", true))
			fanout_hints ["skip_reputation"] = bool(fanout_hints.get("skip_reputation", true))
			fanout_hints ["allow_partial_propagation"] = false
		_:
			fanout_hints ["allow_partial_propagation"] = false

	normalized ["fanout_hints"] = fanout_hints
	return normalized

func _project_dynasties() -> void:
	if gs == null or gs.dynasty_engine == null:
		return

	var surname_index: Dictionary = _build_living_last_name_index()

	for raw_last_name in gs.dynasty_engine.dynasties.keys():
		var last_name: String = str(raw_last_name).strip_edges()
		if last_name == "":
			continue

		var dynasty_data: Dictionary = gs.dynasty_engine.dynasties.get(last_name, {})
		var faction_id: String = "dynasty:%s" % _normalize_key(last_name)
		var faction: Dictionary = _ensure_faction_shell(
			faction_id,
			"%s Dynasty" % last_name,
			"dynasty",
			"dynasty_engine",
			["dynasty", "lineage", "surname_power"]
		)

		faction ["created_year"] = int(faction.get("created_year", gs.year))
		faction ["origin"] = str(dynasty_data.get("origin", ""))
		faction ["root"] = str(dynasty_data.get("root", ""))
		faction ["prestige"] = float(dynasty_data.get("prestige", 0.0))
		faction ["age"] = int(dynasty_data.get("age", 0))
		faction ["mutation_count"] = int(dynasty_data.get("mutation_count", 0))

		var members: Array = surname_index.get(last_name, [])
		for raw_member in members:
			var npc: Person = raw_member
			if npc == null or not npc.alive:
				continue

			var role:= "member"
			if npc == gs.player:
				role = "player_line"
			elif bool(npc.is_ruler):
				role = "ruler"
			elif bool(npc.is_royal):
				role = "royal"

			_upsert_member(faction, int(npc.id), role, int(gs.year), _estimate_member_loyalty(npc, faction))
			_absorb_place_into_faction(faction, npc)

		_finalize_faction(faction)
		faction_registry [faction_id] = faction

func _project_schools() -> void:
	if gs == null or gs.school_engine == null:
		return
	for raw_school_key in gs.school_engine.school_rosters.keys():
		var school_key: String = str(raw_school_key)
		var member_ids: Array = gs.school_engine.school_rosters.get(school_key, [])
		var faction_id: String = "school:%s" % _normalize_key(school_key)
		var faction: Dictionary = _ensure_faction_shell(
			faction_id,
			school_key,
			"school",
			"school_engine",
			["institution", "education", "cohort"]
		)

		var teachers: Array = gs.school_engine.school_teachers.get(school_key, [])
		if not teachers.is_empty():
			faction ["leader_id"] = int(teachers [0])

		for raw_member_id in member_ids:
			var npc_id: int = int(raw_member_id)
			var npc = gs.get_npc_by_id(npc_id)
			if npc == null or not npc.alive:
				continue
			_upsert_member(faction, npc_id, "student", int(gs.year), _estimate_member_loyalty(npc, faction))
			_absorb_place_into_faction(faction, npc)

		for raw_teacher_id in teachers:
			var teacher_id: int = int(raw_teacher_id)
			var teacher = gs.get_npc_by_id(teacher_id)
			if teacher == null or not teacher.alive:
				continue
			_upsert_member(faction, teacher_id, "teacher", int(gs.year), _estimate_member_loyalty(teacher, faction))
			_absorb_place_into_faction(faction, teacher)

		_finalize_faction(faction)
		faction_registry [faction_id] = faction

func _project_workplaces() -> void:
	if gs == null or gs.workplace_engine == null:
		return
	for raw_workplace_id in gs.workplace_engine.workplace_rosters.keys():
		var workplace_id: String = str(raw_workplace_id)
		var roster: Array = gs.workplace_engine.workplace_rosters.get(workplace_id, [])
		var meta: Dictionary = gs.workplace_engine.workplace_meta.get(workplace_id, {})
		var faction_id: String = "workplace:%s" % _normalize_key(workplace_id)
		var faction: Dictionary = _ensure_faction_shell(
			faction_id,
			str(meta.get("job_name", workplace_id)),
			"workplace",
			"workplace_engine",
			["institution", "workplace", "economic"]
		)
		faction ["era_name"] = str(meta.get("era_name", ""))
		faction ["workplace_id"] = workplace_id
		faction ["company_name"] = str(meta.get("company_name", faction.get("name", "")))
		var leader_id: int = int(meta.get("leader_id", meta.get("owner_id", -1)))
		if leader_id > 0:
			faction ["leader_id"] = leader_id
			faction ["owner_id"] = int(meta.get("owner_id", leader_id))
		for raw_member_id in roster:
			var npc_id: int = int(raw_member_id)
			var npc = gs.get_npc_by_id(npc_id)
			if npc == null or not npc.alive:
				continue
			_upsert_member(faction, npc_id, "worker", int(gs.year), _estimate_member_loyalty(npc, faction))
			_absorb_place_into_faction(faction, npc)
		_finalize_faction(faction)
		faction_registry [faction_id] = faction

func _project_boxing_divisions() -> void:
	if gs == null:
		return
	var factions_raw: Variant = gs.scenario_state.get("boxing_division_factions", {})
	var projected: Dictionary = factions_raw if typeof(factions_raw) == TYPE_DICTIONARY else {}
	for raw_faction_id in projected.keys():
		var source_faction: Dictionary = projected.get(raw_faction_id, {})
		if typeof(source_faction) != TYPE_DICTIONARY or source_faction.is_empty():
			continue
		var faction_id: String = str(source_faction.get("id", raw_faction_id))
		var faction: Dictionary = _ensure_faction_shell(
			faction_id,
			str(source_faction.get("name", "Boxing Circuit")),
			"boxing_division",
			"boxing_engine",
			["boxing", "sport", "competitive_circuit"]
		)
		faction ["division"] = str(source_faction.get("division", ""))
		faction ["owner_id"] = int(source_faction.get("owner_id", -1))
		faction ["founder_id"] = int(source_faction.get("founder_id", -1))
		faction ["created_year"] = int(source_faction.get("created_year", gs.year))
		faction ["last_year_active"] = int(source_faction.get("last_year_active", gs.year))
		faction ["status"] = str(source_faction.get("status", "active"))

		var members_raw: Variant = source_faction.get("member_ids", {})
		var members: Dictionary = members_raw if typeof(members_raw) == TYPE_DICTIONARY else {}
		for raw_member_key in members.keys():
			var member: Dictionary = members.get(raw_member_key, {})
			var npc_id: int = int(member.get("npc_id", -1))
			var npc = gs.get_npc_by_id(npc_id)
			if npc == null or not npc.alive:
				continue
			_upsert_member(
				faction,
				npc_id,
				str(member.get("role", "member")),
				int(member.get("joined_year", gs.year)),
				_estimate_member_loyalty(npc, faction)
			)
			_absorb_place_into_faction(faction, npc)

		_finalize_faction(faction)
		faction_registry [faction_id] = faction

func _project_vampire_covens() -> void:
	if gs == null or gs.vampire_society_engine == null:
		return
	for raw_coven_id in gs.vampire_society_engine.covens.keys():
		var coven: Dictionary = gs.vampire_society_engine.covens.get(raw_coven_id, {})
		if typeof(coven) != TYPE_DICTIONARY or coven.is_empty():
			continue
		var coven_id: String = str(coven.get("id", raw_coven_id))
		var faction_id: String = "vampire_coven:%s" % _normalize_key(coven_id)
		var faction: Dictionary = _ensure_faction_shell(
			faction_id,
			str(coven.get("name", "Vampire Coven")),
			"vampire_coven",
			"vampire_society_engine",
			["vampire", "occult", "coven"]
		)
		faction ["founder_id"] = int(coven.get("founder_id", -1))
		faction ["realm_id"] = str(coven.get("realm_id", ""))
		faction ["prestige"] = float(coven.get("prestige", 0.0))
		faction ["created_year"] = int(faction.get("created_year", gs.year))

		var members: Array = coven.get("members", [])
		for raw_member_id in members:
			var npc_id: int = int(raw_member_id)
			var npc = gs.get_npc_by_id(npc_id)
			if npc == null or not npc.alive:
				continue
			var role:= "member"
			if npc_id == int(coven.get("founder_id", -1)):
				role = "founder"
			_upsert_member(faction, npc_id, role, int(gs.year), _estimate_member_loyalty(npc, faction))
			_absorb_place_into_faction(faction, npc)

		_finalize_faction(faction)
		faction_registry [faction_id] = faction

func _ensure_faction_shell(faction_id: String, name: String, kind: String, domain: String, tags: Array = []) -> Dictionary:
	var existing_raw: Variant = faction_registry.get(faction_id, {})
	var existing: Dictionary = existing_raw if typeof(existing_raw) == TYPE_DICTIONARY else {}

	if existing.is_empty():
		existing = {
			"id": faction_id,
			"name": name,
			"kind": kind,
			"domain": domain,
			"tags": tags.duplicate(),
			"status": "active",
			"created_year": int(gs.year),
			"last_year_active": int(gs.year),
			"member_ids": {},
			"territories": {},
			"resource_ledger": {},
			"leader_id": -1,
			"founder_id": -1,
			"owner_id": -1,
			"member_count": 0,
			"visibility": 0.0,
			"cohesion": 50.0,
			"hostility": 0.0,
			"legitimacy": 50.0,
			"pressure": 0.0
		}
	else:
		existing ["name"] = name
		existing ["kind"] = kind
		existing ["domain"] = domain
		existing ["tags"] = tags.duplicate()
		existing ["last_year_active"] = int(gs.year)
		existing ["member_ids"] = existing.get("member_ids", {})
		existing ["territories"] = existing.get("territories", {})
		existing ["resource_ledger"] = existing.get("resource_ledger", {})

	return existing
func ingest_faction_contract_pack(pack: Dictionary) -> Dictionary:
	var report:= {
		"pack_id": str(pack.get("id", "runtime_pack")),
		"loaded": [],
		"failed": []
	}

	var contracts: Array = []
	contracts.append_array(_safe_dictionary_array(pack.get("faction_contracts", [])))
	contracts.append_array(_safe_dictionary_array(pack.get("factions", [])))

	for raw_contract in contracts:
		var contract: Dictionary = normalize_faction_contract(raw_contract, str(pack.get("id", "runtime_pack")))
		var validation: Dictionary = contract.get("validation", {})
		var contract_id: String = str(contract.get("id", "")).strip_edges()

		if contract_id == "" or not bool(validation.get("valid", false)):
			report ["failed"].append({
				"id": contract_id,
				"validation": validation
			})
			continue

		faction_contract_registry [contract_id] = contract
		report ["loaded"].append(contract_id)

	if not report ["loaded"].is_empty():
		flag_domain_projection_dirty("faction_contract_layer")

	_commit_state()
	return report


func normalize_faction_contract(raw_contract: Dictionary, owner_pack: String = "") -> Dictionary:
	var contract_id: String = str(raw_contract.get("id", raw_contract.get("faction_id", ""))).strip_edges()
	var faction_id: String = str(raw_contract.get("faction_id", contract_id)).strip_edges()
	var projection_raw: Variant = raw_contract.get("projection", {})
	var projection: Dictionary = projection_raw if typeof(projection_raw) == TYPE_DICTIONARY else {}
	var resources_raw: Variant = raw_contract.get("resources", raw_contract.get("resource_ledger", {}))
	var resources: Dictionary = resources_raw if typeof(resources_raw) == TYPE_DICTIONARY else {}
	var metrics_raw: Variant = raw_contract.get("metrics", {})
	var metrics: Dictionary = metrics_raw if typeof(metrics_raw) == TYPE_DICTIONARY else {}

	return {
		"id": contract_id,
		"faction_id": faction_id,
		"name": str(raw_contract.get("name", faction_id)).strip_edges(),
		"owner_pack": str(raw_contract.get("owner_pack", owner_pack)).strip_edges(),
		"domain": str(raw_contract.get("domain", projection.get("domain", "faction_contract_layer"))).strip_edges(),
		"kind": str(raw_contract.get("kind", raw_contract.get("type", "contract_faction"))).strip_edges(),
		"enabled": bool(raw_contract.get("enabled", true)),
		"visibility_rule": raw_contract.get("visibility_rule", "always"),
		"tags": _safe_string_array(raw_contract.get("tags", [])),
		"members": _safe_dictionary_array(raw_contract.get("members", [])),
		"member_rules": _safe_dictionary_array(raw_contract.get("member_rules", raw_contract.get("membership_rules", []))),
		"territories": _safe_dictionary_array(raw_contract.get("territories", [])),
		"territory_rules": _safe_dictionary_array(raw_contract.get("territory_rules", [])),
		"resources": resources.duplicate(true),
		"resource_rules": _safe_dictionary_array(raw_contract.get("resource_rules", [])),
		"metrics": metrics.duplicate(true),
		"pressure_rules": _safe_dictionary_array(raw_contract.get("pressure_rules", [])),
		"relationship_rules": _safe_dictionary_array(raw_contract.get("relationship_rules", [])),
		"scenario_hooks": _safe_dictionary_array(raw_contract.get("scenario_hooks", [])),
		"projection": projection.duplicate(true),
		"metadata": raw_contract.get("metadata", {}).duplicate(true) if typeof(raw_contract.get("metadata", {})) == TYPE_DICTIONARY else {},
		"validation": {
			"valid": contract_id != "" and faction_id != "",
			"errors": [] if contract_id != "" and faction_id != "" else ["Faction contract missing id or faction_id."],
			"warnings": []
		}
	}


func _ingest_faction_contracts_from_simulation_registry() -> void:
	if gs == null or gs.simulation_contract_engine == null:
		return

	var external_registry: Dictionary = {}
	if gs.simulation_contract_engine.has_method("get_faction_contract_registry"):
		external_registry = gs.simulation_contract_engine.get_faction_contract_registry()
	elif gs.simulation_contract_engine.has_method("export_registry"):
		var exported: Dictionary = gs.simulation_contract_engine.export_registry()
		var raw_factions: Variant = exported.get("faction_contract_registry", {})
		if typeof(raw_factions) == TYPE_DICTIONARY:
			external_registry = raw_factions

	var signature: String = str(external_registry.keys())
	var previous_signature: String = str(faction_contract_layer_state.get("external_registry_signature", ""))
	if signature == previous_signature:
		return

	for raw_id in external_registry.keys():
		var raw_contract: Variant = external_registry.get(raw_id, {})
		if typeof(raw_contract) != TYPE_DICTIONARY:
			continue

		var contract: Dictionary = normalize_faction_contract(raw_contract, str((raw_contract as Dictionary).get("owner_pack", "simulation_contract_engine")))
		var contract_id: String = str(contract.get("id", "")).strip_edges()
		if contract_id == "":
			continue

		faction_contract_registry [contract_id] = contract

	faction_contract_layer_state ["external_registry_signature"] = signature
	flag_domain_projection_dirty("faction_contract_layer")


func _project_contract_defined_factions(touched_faction_ids: Dictionary = {}) -> void:
	_ingest_faction_contracts_from_simulation_registry()

	for raw_contract_id in faction_contract_registry.keys():
		var contract_id: String = str(raw_contract_id)
		var contract_raw: Variant = faction_contract_registry.get(contract_id, {})
		if typeof(contract_raw) != TYPE_DICTIONARY:
			continue

		var contract: Dictionary = contract_raw
		if not bool(contract.get("enabled", true)):
			continue
		if not _passes_faction_contract_rule(contract.get("visibility_rule", "always"), contract):
			continue

		var faction_id: String = str(contract.get("faction_id", contract.get("id", ""))).strip_edges()
		if faction_id == "":
			continue

		var faction: Dictionary = _ensure_faction_shell(
			faction_id,
			str(contract.get("name", faction_id)),
			str(contract.get("kind", "contract_faction")),
			str(contract.get("domain", "faction_contract_layer")),
			_safe_string_array(contract.get("tags", []))
		)

		faction ["contract_id"] = contract_id
		faction ["contract_layer"] = true
		faction ["owner_pack"] = str(contract.get("owner_pack", ""))
		faction ["metadata"] = contract.get("metadata", {}).duplicate(true) if typeof(contract.get("metadata", {})) == TYPE_DICTIONARY else {}

		_apply_faction_contract_static_payload(faction, contract)
		_apply_faction_contract_members(faction, contract)
		_apply_faction_contract_territories(faction, contract)
		_apply_faction_contract_resources(faction, contract)
		_apply_faction_contract_metrics(faction, contract)
		_apply_faction_contract_pressure_rules(faction, contract)

		_finalize_faction(faction)
		faction_registry [faction_id] = faction
		touched_faction_ids [faction_id] = true


func _apply_faction_contract_static_payload(faction: Dictionary, contract: Dictionary) -> void:
	var projection_raw: Variant = contract.get("projection", {})
	var projection: Dictionary = projection_raw if typeof(projection_raw) == TYPE_DICTIONARY else {}

	for key in ["realm_id", "hidden_realm_id", "institution_type", "leader_id", "founder_id", "owner_id", "status", "prestige"]:
		if contract.has(key):
			faction [key] = contract.get(key)
		elif projection.has(key):
			faction [key] = projection.get(key)


func _apply_faction_contract_members(faction: Dictionary, contract: Dictionary) -> void:
	for raw_member in _safe_dictionary_array(contract.get("members", [])):
		var npc_id: int = int(raw_member.get("npc_id", raw_member.get("id", -1)))
		if npc_id <= 0:
			continue

		var npc = gs.get_npc_by_id(npc_id) if gs != null and gs.has_method("get_npc_by_id") else null
		if npc == null or not npc.alive:
			continue

		_upsert_member(
			faction,
			npc_id,
			str(raw_member.get("role", "member")),
			int(raw_member.get("joined_year", gs.year)),
			float(raw_member.get("loyalty", _estimate_member_loyalty(npc, faction)))
		)
		_absorb_place_into_faction(faction, npc)

	for raw_rule in _safe_dictionary_array(contract.get("member_rules", [])):
		var member_ids: Array = _resolve_faction_contract_member_rule(raw_rule)
		for raw_member_id in member_ids:
			var npc_id: int = int(raw_member_id)
			if npc_id <= 0:
				continue

			var npc = gs.get_npc_by_id(npc_id) if gs != null and gs.has_method("get_npc_by_id") else null
			if npc == null or not npc.alive:
				continue

			_upsert_member(
				faction,
				npc_id,
				str(raw_rule.get("role", "member")),
				int(raw_rule.get("joined_year", gs.year)),
				float(raw_rule.get("loyalty", _estimate_member_loyalty(npc, faction)))
			)
			_absorb_place_into_faction(faction, npc)


func _resolve_faction_contract_member_rule(rule: Dictionary) -> Array:
	var out: Array = []
	if gs == null:
		return out

	var source: String = str(rule.get("source", rule.get("kind", "all_living"))).strip_edges().to_lower()
	var limit: int = int(rule.get("limit", 250))
	var seen: Dictionary = {}

	for npc in gs.npcs:
		if npc == null or not npc.alive:
			continue

		if not _npc_passes_faction_contract_member_rule(npc, source, rule):
			continue

		var npc_id: int = int(npc.id)
		if npc_id <= 0 or seen.has(npc_id):
			continue

		seen [npc_id] = true
		out.append(npc_id)

		if limit > 0 and out.size() >= limit:
			break

	return out


func _npc_passes_faction_contract_member_rule(npc, source: String, rule: Dictionary) -> bool:
	if npc == null:
		return false

	match source:
		"all_living":
			return true

		"realm_population", "realm":
			var realm_id: String = str(rule.get("realm_id", "")).strip_edges()
			if realm_id == "":
				return true

			var npc_realm_id: String = str(_get_contract_npc_value(npc, "realm_id", "")).strip_edges()
			var npc_birth_realm_id: String = str(_get_contract_npc_value(npc, "birth_realm_id", "")).strip_edges()
			return npc_realm_id == realm_id or npc_birth_realm_id == realm_id

		"country", "birth_country":
			var country: String = str(rule.get("country", "")).strip_edges()
			if country == "":
				return true

			var home_country: String = str(_get_contract_npc_value(npc, "home_country", "")).strip_edges()
			var birth_country: String = str(_get_contract_npc_value(npc, "birth_country", "")).strip_edges()
			return home_country == country or birth_country == country

		"city", "birth_city":
			var city: String = str(rule.get("city", "")).strip_edges()
			if city == "":
				return true

			var home_city: String = str(_get_contract_npc_value(npc, "home_city", "")).strip_edges()
			var birth_city: String = str(_get_contract_npc_value(npc, "birth_city", "")).strip_edges()
			return home_city == city or birth_city == city

		"job":
			var job_key: String = str(rule.get("job", rule.get("job_key", ""))).strip_edges()
			if job_key == "":
				return true

			var npc_job: String = str(_get_contract_npc_value(npc, "job", "")).strip_edges()
			var npc_career: String = str(_get_contract_npc_value(npc, "career", "")).strip_edges()
			return npc_job == job_key or npc_career == job_key

		"trait":
			var trait_key: String = str(rule.get("trait", "")).strip_edges()
			if trait_key == "":
				return true

			var npc_traits: Array = _get_contract_npc_traits(npc)
			return trait_key in npc_traits

		"royalty":
			return bool(_get_contract_npc_value(npc, "is_royal", false)) or bool(_get_contract_npc_value(npc, "is_ruler", false))

		_:
			return true
func _get_contract_npc_value(npc, key: String, fallback: Variant = null) -> Variant:
	if npc == null:
		return fallback

	if npc.has_method("get"):
		var value: Variant = npc.get(key)
		if value != null:
			return value

	return fallback


func _get_contract_npc_traits(npc) -> Array:
	var raw_traits: Variant = _get_contract_npc_value(npc, "traits", [])
	if typeof(raw_traits) == TYPE_ARRAY:
		return raw_traits

	if typeof(raw_traits) == TYPE_PACKED_STRING_ARRAY:
		var out: Array = []
		for raw_trait in raw_traits:
			out.append(str(raw_trait))
		return out

	return []

func _apply_faction_contract_territories(faction: Dictionary, contract: Dictionary) -> void:
	for raw_territory in _safe_dictionary_array(contract.get("territories", [])):
		var territory_id: String = str(raw_territory.get("id", raw_territory.get("territory_id", ""))).strip_edges()
		if territory_id == "":
			continue
		_add_territory_weight(faction, territory_id, float(raw_territory.get("weight", raw_territory.get("amount", 1.0))))

	for raw_rule in _safe_dictionary_array(contract.get("territory_rules", [])):
		var source: String = str(raw_rule.get("source", "members")).strip_edges().to_lower()
		match source:
			"members":
				var members_raw: Variant = faction.get("member_ids", {})
				var members: Dictionary = members_raw if typeof(members_raw) == TYPE_DICTIONARY else {}
				for raw_member_key in members.keys():
					var member: Dictionary = members.get(raw_member_key, {})
					var npc = gs.get_npc_by_id(int(member.get("npc_id", -1))) if gs != null and gs.has_method("get_npc_by_id") else null
					if npc != null and npc.alive:
						_absorb_place_into_faction(faction, npc)

			"fixed":
				var territory_id: String = str(raw_rule.get("territory_id", raw_rule.get("id", ""))).strip_edges()
				if territory_id != "":
					_add_territory_weight(faction, territory_id, float(raw_rule.get("weight", 1.0)))


func _apply_faction_contract_resources(faction: Dictionary, contract: Dictionary) -> void:
	var resources_raw: Variant = faction.get("resource_ledger", {})
	var resources: Dictionary = resources_raw if typeof(resources_raw) == TYPE_DICTIONARY else {}

	var contract_resources_raw: Variant = contract.get("resources", {})
	var contract_resources: Dictionary = contract_resources_raw if typeof(contract_resources_raw) == TYPE_DICTIONARY else {}
	for raw_key in contract_resources.keys():
		resources [str(raw_key)] = float(contract_resources.get(raw_key, 0.0))

	for raw_rule in _safe_dictionary_array(contract.get("resource_rules", [])):
		var resource_key: String = str(raw_rule.get("resource", raw_rule.get("key", ""))).strip_edges()
		if resource_key == "":
			continue

		var mode: String = str(raw_rule.get("mode", "add")).strip_edges().to_lower()
		var amount: float = float(raw_rule.get("amount", raw_rule.get("value", 0.0)))

		match mode:
			"set":
				resources [resource_key] = amount
			"multiply":
				resources [resource_key] = float(resources.get(resource_key, 0.0)) * amount
			_:
				resources [resource_key] = float(resources.get(resource_key, 0.0)) + amount

	faction ["resource_ledger"] = resources


func _apply_faction_contract_metrics(faction: Dictionary, contract: Dictionary) -> void:
	var metrics_raw: Variant = contract.get("metrics", {})
	var metrics: Dictionary = metrics_raw if typeof(metrics_raw) == TYPE_DICTIONARY else {}

	for metric_key in ["visibility", "cohesion", "hostility", "legitimacy", "pressure", "prestige"]:
		if not metrics.has(metric_key):
			continue
		faction [metric_key] = float(metrics.get(metric_key, faction.get(metric_key, 0.0)))


func _apply_faction_contract_pressure_rules(faction: Dictionary, contract: Dictionary) -> void:
	var pressure_delta: float = 0.0

	for raw_rule in _safe_dictionary_array(contract.get("pressure_rules", [])):
		var kind: String = str(raw_rule.get("kind", raw_rule.get("rule", "flat"))).strip_edges().to_lower()
		var amount: float = float(raw_rule.get("amount", raw_rule.get("value", 0.0)))

		match kind:
			"member_count_below":
				var threshold: int = int(raw_rule.get("threshold", 0))
				var member_count: int = int(faction.get("member_count", 0))
				if member_count < threshold:
					pressure_delta += amount * float(threshold - member_count)

			"member_count_above":
				var threshold: int = int(raw_rule.get("threshold", 0))
				var member_count: int = int(faction.get("member_count", 0))
				if member_count > threshold:
					pressure_delta += amount * float(member_count - threshold)

			"resource_below":
				var resource_key: String = str(raw_rule.get("resource", "")).strip_edges()
				var threshold: float = float(raw_rule.get("threshold", 0.0))
				var resources_raw: Variant = faction.get("resource_ledger", {})
				var resources: Dictionary = resources_raw if typeof(resources_raw) == TYPE_DICTIONARY else {}
				var current: float = float(resources.get(resource_key, 0.0))
				if current < threshold:
					pressure_delta += amount * (threshold - current)

			"flat":
				pressure_delta += amount

			_:
				pressure_delta += amount

	faction ["pressure"] = max(0.0, float(faction.get("pressure", 0.0)) + pressure_delta)


func _passes_faction_contract_rule(rule: Variant, _contract: Dictionary = {}) -> bool:
	if typeof(rule) == TYPE_BOOL:
		return bool(rule)

	if typeof(rule) == TYPE_DICTIONARY:
		var kind: String = str(rule.get("kind", rule.get("rule", "always"))).strip_edges().to_lower()
		match kind:
			"feature_enabled":
				return gs != null and gs.has_method("is_feature_enabled") and gs.is_feature_enabled(str(rule.get("feature", "")))
			"era":
				if gs == null or gs.era == null:
					return false
				var era_name: String = str(gs.era.get("name", "") if typeof(gs.era) == TYPE_DICTIONARY else "")
				return era_name == str(rule.get("name", rule.get("era", "")))
			"year_at_least":
				return gs != null and int(gs.year) >= int(rule.get("value", 0))
			"year_before":
				return gs != null and int(gs.year) < int(rule.get("value", 0))
			_:
				return true

	var clean: String = str(rule).strip_edges().to_lower()
	match clean:
		"", "always", "true":
			return true
		"player_alive":
			return gs != null and gs.player != null and gs.player.alive
		"bending_enabled":
			return gs != null and gs.has_method("is_feature_enabled") and gs.is_feature_enabled("bending")
		_:
			return true


func _safe_dictionary_array(value: Variant) -> Array:
	var out: Array = []
	if typeof(value) != TYPE_ARRAY:
		return out

	for raw in value:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		out.append((raw as Dictionary).duplicate(true))

	return out


func _safe_string_array(value: Variant) -> Array:
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
func _upsert_member(faction: Dictionary, npc_id: int, role: String = "member", joined_year: int = -1, loyalty: float = 50.0) -> void:
	if npc_id <= 0:
		return
	var members_raw: Variant = faction.get("member_ids", {})
	var members: Dictionary = members_raw if typeof(members_raw) == TYPE_DICTIONARY else {}
	var existing: Dictionary = members.get(str(npc_id), {})
	existing ["npc_id"] = npc_id
	existing ["role"] = role
	existing ["active"] = true
	existing ["joined_year"] = joined_year if joined_year >= 0 else int(gs.year)
	existing ["loyalty"] = loyalty
	members [str(npc_id)] = existing
	faction ["member_ids"] = members
	if faction.get("leader_id", -1) == -1 and role in ["leader", "founder", "ruler", "champion"]:
		faction ["leader_id"] = npc_id

func _absorb_place_into_faction(faction: Dictionary, npc) -> void:
	if npc == null:
		return
	var city: String = str(npc.home_city if str(npc.home_city) != "" else npc.birth_city)
	var country: String = str(npc.home_country if str(npc.home_country) != "" else npc.birth_country)
	var settlement_id: String = str(npc.settlement_id).strip_edges()
	var district_id: String = str(npc.district_id).strip_edges()
	var locality_payload: Dictionary = _get_effective_locality_id(npc)
	var locality_id: String = str(locality_payload.get("locality_id", "")).strip_edges()
	var locality_source: String = str(locality_payload.get("source", "")).strip_edges()

	if settlement_id != "":
		_add_territory_weight(faction, "settlement:%s" % _normalize_key(settlement_id), 1.1)
	if district_id != "":
		_add_territory_weight(faction, "district:%s" % _normalize_key(district_id), 0.9)
	if locality_id != "":
		_add_territory_weight(faction, "locality:%s" % _normalize_key(locality_id), 1.2)
		if locality_source == "address_neighborhood":
			_add_territory_weight(faction, "address_neighborhood:%s" % _normalize_key(locality_id), 1.15)
	if city != "":
		_add_territory_weight(faction, "city:%s" % _normalize_key(city), 1.0)
	if country != "":
		_add_territory_weight(faction, "country:%s" % _normalize_key(country), 0.6)

func _add_territory_weight(faction: Dictionary, territory_id: String, amount: float) -> void:
	var territories_raw: Variant = faction.get("territories", {})
	var territories: Dictionary = territories_raw if typeof(territories_raw) == TYPE_DICTIONARY else {}
	territories [territory_id] = float(territories.get(territory_id, 0.0)) + amount
	faction ["territories"] = territories

func _finalize_faction(faction: Dictionary) -> void:
	var members_raw: Variant = faction.get("member_ids", {})
	var members: Dictionary = members_raw if typeof(members_raw) == TYPE_DICTIONARY else {}
	faction ["member_count"] = int(members.size())

	var resources_raw: Variant = faction.get("resource_ledger", {})
	var resources: Dictionary = resources_raw if typeof(resources_raw) == TYPE_DICTIONARY else {}
	var territories_raw: Variant = faction.get("territories", {})
	var territories: Dictionary = territories_raw if typeof(territories_raw) == TYPE_DICTIONARY else {}

	resources ["membership_mass"] = float(members.size())
	resources ["territory_span"] = float(territories.size())
	resources ["prestige"] = float(faction.get("prestige", 0.0))
	if int(faction.get("leader_id", -1)) > 0:
		resources ["leadership_weight"] = max(1.0, float(resources.get("leadership_weight", 0.0)))

	faction ["resource_ledger"] = resources

	if int(faction.get("member_count", 0)) <= 0:
		faction ["status"] = "collapsed"

func _cleanup_dead_members() -> void:
	for raw_faction_id in faction_registry.keys():
		var faction: Dictionary = faction_registry.get(raw_faction_id, {})
		var members_raw: Variant = faction.get("member_ids", {})
		var members: Dictionary = members_raw if typeof(members_raw) == TYPE_DICTIONARY else {}
		var cleaned: Dictionary = {}
		for raw_member_key in members.keys():
			var member: Dictionary = members.get(raw_member_key, {})
			var npc_id: int = int(member.get("npc_id", -1))
			var npc = gs.get_npc_by_id(npc_id)
			if npc == null or not npc.alive:
				continue
			cleaned [str(npc_id)] = member
		faction ["member_ids"] = cleaned
		_finalize_faction(faction)
		faction_registry [str(raw_faction_id)] = faction

func _rebuild_membership_index() -> void:
	membership_index.clear()
	for raw_faction_id in faction_registry.keys():
		var faction: Dictionary = faction_registry.get(raw_faction_id, {})
		var members: Dictionary = faction.get("member_ids", {})
		for raw_member_key in members.keys():
			var member: Dictionary = members.get(raw_member_key, {})
			var npc_id: int = int(member.get("npc_id", -1))
			if npc_id <= 0:
				continue
			var npc_key: String = str(npc_id)
			if not membership_index.has(npc_key):
				membership_index [npc_key] = {}
			membership_index [npc_key] [str(raw_faction_id)] = {
				"faction_name": str(faction.get("name", "")),
				"kind": str(faction.get("kind", "")),
				"role": str(member.get("role", "member")),
				"active": bool(member.get("active", true)),
				"joined_year": int(member.get("joined_year", gs.year))
			}

func _rebuild_territory_index() -> void:
	territory_index.clear()
	for raw_faction_id in faction_registry.keys():
		var faction: Dictionary = faction_registry.get(raw_faction_id, {})
		var territories: Dictionary = faction.get("territories", {})
		for raw_territory_id in territories.keys():
			var territory_id: String = str(raw_territory_id)
			if not territory_index.has(territory_id):
				territory_index [territory_id] = {}
			territory_index [territory_id] [str(raw_faction_id)] = float(territories.get(territory_id, 0.0))

func _rebuild_relationship_graph(touched_faction_ids: Dictionary = {}, prioritize_player_orbit: bool = false) -> void:
	var do_full_rebuild: bool = touched_faction_ids.is_empty() or relationship_graph.is_empty()

	if not do_full_rebuild:
		var touched_count: int = touched_faction_ids.size()
		var faction_count: int = faction_registry.size()
		if touched_count >= max(12, int(ceil(float(max(1, faction_count)) * 0.3))):
			do_full_rebuild = true

	if do_full_rebuild:
		relationship_graph.clear()
		_rebuild_relationship_graph_pairs({})
		return

	_ensure_relationship_graph_nodes_for_active_factions()
	var target_filter: Dictionary = _build_relationship_graph_target_set(touched_faction_ids, prioritize_player_orbit)
	_clear_relationship_edges_for_factions(target_filter)
	_rebuild_relationship_graph_pairs(target_filter)
func _build_living_last_name_index() -> Dictionary:
	var index: Dictionary = {}
	if gs == null:
		return index

	for raw_npc in gs.npcs:
		var npc: Person = raw_npc
		if npc == null or not npc.alive:
			continue
		var last_name: String = str(npc.last_name).strip_edges()
		if last_name == "":
			continue
		if not index.has(last_name):
			index [last_name] = []
		index [last_name].append(npc)

	return index


func _build_living_realm_member_index() -> Dictionary:
	var index: Dictionary = {}
	if gs == null:
		return index

	for raw_npc in gs.npcs:
		var npc: Person = raw_npc
		if npc == null or not npc.alive:
			continue
		var realm_id: int = int(npc.realm_id)
		if realm_id <= 0:
			continue
		if not index.has(realm_id):
			index [realm_id] = []
		index [realm_id].append(npc)

	return index


func _is_realm_court_office_job(job_key: String) -> bool:
	return job_key in [
		"president",
		"prime minister",
		"governor",
		"mayor",
		"senator",
		"judge",
		"minister",
		"court official",
		"general",
		"chancellor",
		"secretary",
		"councilor",
		"councillor",
		"ambassador"
	]


func _build_dormant_realm_official_snapshot_index() -> Dictionary:
	var index: Dictionary = {}
	if gs == null or typeof(gs.dormant_npcs) != TYPE_DICTIONARY:
		return index

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

		var office_job: String = str(snapshot.get("job", "")).strip_edges().to_lower()
		var snapshot_is_official: bool = bool(snapshot.get("is_ruler", false))
		snapshot_is_official = snapshot_is_official or bool(snapshot.get("is_royal", false))
		snapshot_is_official = snapshot_is_official or int(snapshot.get("succession_rank", 0)) > 0
		snapshot_is_official = snapshot_is_official or bool(snapshot.get("deposed", false)) or bool(snapshot.get("exiled", false))
		snapshot_is_official = snapshot_is_official or str(snapshot.get("royal_title", "")).strip_edges() != ""
		snapshot_is_official = snapshot_is_official or _is_realm_court_office_job(office_job)

		if not snapshot_is_official:
			continue

		if not index.has(realm_id):
			index [realm_id] = []
		index [realm_id].append({
			"npc_id": int(raw_npc_id),
			"snapshot": snapshot.duplicate(true)
		})

	return index


func _relationship_pair_key(a_id: String, b_id: String) -> String:
	if a_id == b_id:
		return a_id
	return "%s|%s" % [a_id, b_id] if a_id < b_id else "%s|%s" % [b_id, a_id]


func _get_relationship_pair_bucket(pair_edges: Dictionary, a_id: String, b_id: String) -> Dictionary:
	var key: String = _relationship_pair_key(a_id, b_id)
	var bucket_raw: Variant = pair_edges.get(key, {})
	var bucket: Dictionary = bucket_raw if typeof(bucket_raw) == TYPE_DICTIONARY else {}

	if bucket.is_empty():
		var first_id: String = a_id if a_id < b_id else b_id
		var second_id: String = b_id if a_id < b_id else a_id
		bucket = {
			"a_id": first_id,
			"b_id": second_id,
			"shared_members": 0.0,
			"shared_territories": 0.0,
			"contested_claims": 0.0,
			"claim_pressure": 0.0,
			"contested_realm": false,
			"contested_hidden_realm": false
		}

	return bucket


func _store_relationship_pair_bucket(pair_edges: Dictionary, bucket: Dictionary) -> void:
	var a_id: String = str(bucket.get("a_id", ""))
	var b_id: String = str(bucket.get("b_id", ""))
	if a_id == "" or b_id == "" or a_id == b_id:
		return
	pair_edges [_relationship_pair_key(a_id, b_id)] = bucket


func _bump_relationship_pair_metric(pair_edges: Dictionary, a_id: String, b_id: String, key: String, amount: float) -> void:
	if a_id == "" or b_id == "" or a_id == b_id or amount == 0.0:
		return

	var bucket: Dictionary = _get_relationship_pair_bucket(pair_edges, a_id, b_id)
	bucket [key] = float(bucket.get(key, 0.0)) + amount
	_store_relationship_pair_bucket(pair_edges, bucket)


func _set_relationship_pair_flag(pair_edges: Dictionary, a_id: String, b_id: String, key: String, value: bool) -> void:
	if a_id == "" or b_id == "" or a_id == b_id:
		return

	var bucket: Dictionary = _get_relationship_pair_bucket(pair_edges, a_id, b_id)
	bucket [key] = value
	_store_relationship_pair_bucket(pair_edges, bucket)


func _build_claim_resource_index() -> Dictionary:
	var claim_index: Dictionary = {}

	for raw_faction_id in faction_registry.keys():
		var faction_id: String = str(raw_faction_id)
		var faction_raw: Variant = faction_registry.get(faction_id, {})
		var faction: Dictionary = faction_raw if typeof(faction_raw) == TYPE_DICTIONARY else {}
		if faction.is_empty():
			continue

		var resources_raw: Variant = faction.get("resource_ledger", {})
		var resources: Dictionary = resources_raw if typeof(resources_raw) == TYPE_DICTIONARY else {}
		for raw_resource_key in resources.keys():
			var resource_key: String = str(raw_resource_key)
			if not resource_key.begins_with("claim:"):
				continue

			var value: float = float(resources.get(resource_key, 0.0))
			if value <= 0.0:
				continue

			if not claim_index.has(resource_key):
				claim_index [resource_key] = []

			claim_index [resource_key].append({
				"faction_id": faction_id,
				"value": value
			})

	return claim_index

func _detect_structural_changes(previous_registry: Dictionary) -> void:
	for raw_faction_id in faction_registry.keys():
		var faction_id: String = str(raw_faction_id)
		var faction_raw: Variant = faction_registry.get(faction_id, {})
		var faction: Dictionary = faction_raw if typeof(faction_raw) == TYPE_DICTIONARY else {}
		var previous_raw: Variant = previous_registry.get(faction_id, {})
		var previous: Dictionary = previous_raw if typeof(previous_raw) == TYPE_DICTIONARY else {}

		if previous.is_empty():
			_queue_created_packets(faction)
			continue

		var prev_members_raw: Variant = previous.get("member_ids", {})
		var prev_members: Dictionary = prev_members_raw if typeof(prev_members_raw) == TYPE_DICTIONARY else {}
		var next_members_raw: Variant = faction.get("member_ids", {})
		var next_members: Dictionary = next_members_raw if typeof(next_members_raw) == TYPE_DICTIONARY else {}

		for raw_member_key in next_members.keys():
			if not prev_members.has(raw_member_key):
				_queue_member_join_packets(faction, int(raw_member_key))

		for raw_member_key in prev_members.keys():
			if not next_members.has(raw_member_key):
				_queue_member_loss_packets(faction, int(raw_member_key))

		var prev_territories_raw: Variant = previous.get("territories", {})
		var prev_territories: Dictionary = prev_territories_raw if typeof(prev_territories_raw) == TYPE_DICTIONARY else {}
		var next_territories_raw: Variant = faction.get("territories", {})
		var next_territories: Dictionary = next_territories_raw if typeof(next_territories_raw) == TYPE_DICTIONARY else {}
		for raw_territory_id in prev_territories.keys():
			if not next_territories.has(raw_territory_id):
				_queue_territory_loss_packets(faction, str(raw_territory_id))
				break

		var prev_leader_id: int = int(previous.get("leader_id", -1))
		var next_leader_id: int = int(faction.get("leader_id", -1))
		if prev_leader_id > 0 and next_leader_id > 0 and prev_leader_id != next_leader_id:
			if str(faction.get("kind", "")) in ["realm_power", "royal_house", "political_bloc", "many_realms_circle"]:
				_queue_coup_packets(faction, prev_leader_id, next_leader_id)

	for raw_prev_id in previous_registry.keys():
		var faction_id: String = str(raw_prev_id)
		if faction_registry.has(faction_id):
			continue
		var previous_raw: Variant = previous_registry.get(faction_id, {})
		var previous: Dictionary = previous_raw if typeof(previous_raw) == TYPE_DICTIONARY else {}
		if typeof(previous) == TYPE_DICTIONARY and not previous.is_empty():
			_queue_decline_packets(previous)

func _estimate_legitimacy(faction: Dictionary) -> float:
	var legitimacy: float = 40.0
	legitimacy += float(faction.get("prestige", 0.0)) * 0.25
	legitimacy += min(20.0, float(int(faction.get("member_count", 0))) * 1.2)
	if int(faction.get("leader_id", -1)) > 0:
		legitimacy += 8.0
	var resources_raw: Variant = faction.get("resource_ledger", {})
	var resources: Dictionary = resources_raw if typeof(resources_raw) == TYPE_DICTIONARY else {}
	legitimacy += min(8.0, float(resources.get("approval_pool", 0.0)) * 0.04)
	legitimacy += min(10.0, float(resources.get("population", 0.0)) * 2e-05)
	legitimacy += min(8.0, float(resources.get("land", 0.0)) * 0.05)

	legitimacy -= min(16.0, float(resources.get("low_population_pressure", 0.0)) * 0.18)
	legitimacy -= min(14.0, float(resources.get("overpopulation_pressure", 0.0)) * 0.12)
	legitimacy -= min(18.0, float(resources.get("elite_gap_pressure", 0.0)) * 0.22)
	legitimacy -= min(14.0, float(resources.get("military_gap_pressure", 0.0)) * 0.18)
	legitimacy -= min(8.0, float(resources.get("worker_gap_pressure", 0.0)) * 0.1)

	return clamp(legitimacy, 0.0, 100.0)

func _estimate_cohesion(faction: Dictionary) -> float:
	var members: Dictionary = faction.get("member_ids", {})
	if members.is_empty():
		return 0.0
	var total: float = 0.0
	for raw_member_key in members.keys():
		total += float((members.get(raw_member_key, {}) as Dictionary).get("loyalty", 50.0))
	return clamp(total / float(max(1, members.size())), 0.0, 100.0)

func _estimate_visibility(faction: Dictionary) -> float:
	var visibility: float = 8.0
	visibility += float(int(faction.get("member_count", 0))) * 1.5
	if str(faction.get("kind", "")) in ["boxing_division", "dynasty", "vampire_coven"]:
		visibility += 10.0
	if str(faction.get("kind", "")) in ["realm_power", "royal_house", "political_bloc", "many_realms_circle"]:
		visibility += 8.0
	var resources_raw: Variant = faction.get("resource_ledger", {})
	var resources: Dictionary = resources_raw if typeof(resources_raw) == TYPE_DICTIONARY else {}
	visibility += min(10.0, float(resources.get("territory_span", 0.0)) * 1.5)
	visibility += min(8.0, float(resources.get("population", 0.0)) * 1e-05)
	visibility += min(8.0, float(resources.get("overpopulation_pressure", 0.0)) * 0.08)
	visibility += min(6.0, float(resources.get("elite_gap_pressure", 0.0)) * 0.06)
	visibility += min(6.0, float(resources.get("military_gap_pressure", 0.0)) * 0.05)
	return clamp(visibility, 0.0, 100.0)


func _estimate_hostility(faction: Dictionary) -> float:
	var faction_id: String = str(faction.get("id", ""))
	var edges: Dictionary = relationship_graph.get(faction_id, {})
	var hostility: float = 0.0
	for raw_other_id in edges.keys():
		var edge: Dictionary = edges.get(raw_other_id, {})
		hostility += float(edge.get("hostility", 0.0))
	return clamp(hostility, 0.0, 100.0)

func _estimate_member_loyalty(npc, faction: Dictionary) -> float:
	if npc == null:
		return 50.0
	var loyalty: float = 45.0
	loyalty += float(npc.ambition) * 0.1
	if str(faction.get("kind", "")) == "dynasty" and str(npc.last_name) in str(faction.get("name", "")):
		loyalty += 20.0
	if str(faction.get("kind", "")) == "vampire_coven" and npc.vampire_profile.get("is_vampire", false):
		loyalty += 18.0
	if str(faction.get("kind", "")) == "boxing_division" and npc.boxing_profile.get("is_boxer", false):
		loyalty += 16.0
	return clamp(loyalty, 0.0, 100.0)

func _queue_created_packets(faction: Dictionary) -> void:
	var text: String = "🏛 %s emerged as an organized force in the world." % str(faction.get("name", "A faction"))
	_queue_packet_bundle(faction, ActionEventTypes.FACTION_CREATED, text)

func _queue_member_join_packets(faction: Dictionary, npc_id: int) -> void:
	var npc = gs.get_npc_by_id(npc_id)
	if npc == null:
		return
	var text: String = "🤝 %s joined %s." % [npc.first_name, str(faction.get("name", "a faction"))]
	_queue_packet_bundle(faction, ActionEventTypes.FACTION_RECRUITED_MEMBER, text, npc_id)

func _queue_member_loss_packets(faction: Dictionary, npc_id: int) -> void:
	var text: String = "📉 %s lost a member." % str(faction.get("name", "A faction"))
	_queue_packet_bundle(faction, ActionEventTypes.FACTION_LOST_MEMBER, text, npc_id)

func _queue_pressure_spike_packets(faction: Dictionary, _previous_pressure: float, _new_pressure: float) -> void:
	var text: String = "🔥 Pressure surged inside %s." % str(faction.get("name", "a faction"))
	_queue_packet_bundle(faction, ActionEventTypes.FACTION_PRESSURE_SPIKE, text)

func _queue_peak_packets(faction: Dictionary) -> void:
	var text: String = "🌟 %s reached the height of its influence." % str(faction.get("name", "A faction"))
	_queue_packet_bundle(faction, ActionEventTypes.FACTION_PEAKED, text)

func _queue_decline_packets(faction: Dictionary) -> void:
	var text: String = "🕯 %s began to decline." % str(faction.get("name", "A faction"))
	_queue_packet_bundle(faction, ActionEventTypes.FACTION_DECLINED, text)

func _queue_packet_bundle(faction: Dictionary, event_name: String, text: String, npc_id: int = -1) -> void:
	var relevant_npc_id: int = npc_id
	if relevant_npc_id <= 0:
		relevant_npc_id = int(faction.get("leader_id", -1))
	if relevant_npc_id <= 0:
		relevant_npc_id = int(faction.get("founder_id", -1))

	var player_relevant: bool = _is_player_relevant(faction)
	if _should_compact_pending_faction_event(event_name, player_relevant):
		_queue_compacted_packet_bundle(faction, event_name, text, relevant_npc_id, player_relevant)
		return

	var qos_tier: String = "critical" if player_relevant else "important"
	var fanout_hints: Dictionary = {
		"skip_agent_memory_propagation": false,
		"skip_npc_memory_web": false,
		"skip_llm_bridge": false,
		"skip_reputation": false,
		"allow_partial_propagation": qos_tier == "important"
	}

	pending_delta_packets.append({
		"type": "world_feed_entry",
		"entry": {
			"text": text,
			"year": int(gs.year),
			"npc_id": relevant_npc_id,
			"personally_relevant": player_relevant,
			"category": "faction",
			"event_name": event_name,
			"source": "universal_faction_engine"
		}
	})
	pending_delta_packets.append({
		"type": "chronicle_entry",
		"text": text,
		"year": int(gs.year),
		"source": "universal_faction_engine"
	})
	pending_bus_events.append({
		"event_name": event_name,
		"payload": {
			"npc_id": relevant_npc_id,
			"text": text,
			"faction_id": str(faction.get("id", "")),
			"faction_name": str(faction.get("name", "")),
			"faction_kind": str(faction.get("kind", "")),
			"member_count": int(faction.get("member_count", 0)),
			"pressure": float(faction.get("pressure", 0.0)),
			"year": int(gs.year),
			"event_name": event_name,
			"category": "faction",
			"player_relevant": player_relevant,
			"qos_tier": qos_tier,
			"fanout_priority": "high" if qos_tier == "critical" else "normal",
			"fanout_hints": fanout_hints,
			"source": "universal_faction_engine"
		}
	})

func _emit_pending_bus_events() -> void:
	if gs == null or gs.event_bus == null:
		return
	for entry in pending_bus_events:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var event_name: String = str(entry.get("event_name", "")).strip_edges()
		var payload_raw: Variant = entry.get("payload", {})
		var payload: Dictionary = payload_raw if typeof(payload_raw) == TYPE_DICTIONARY else {}
		if event_name == "":
			continue
		if not payload.has("event_name"):
			payload ["event_name"] = event_name
		if not payload.has("year"):
			payload ["year"] = int(gs.year)
		if str(payload.get("category", "")).strip_edges() == "":
			payload ["category"] = "faction"
		if not payload.has("player_relevant"):
			payload ["player_relevant"] = false
		payload = _apply_event_bus_qos_defaults(payload, bool(payload.get("compacted_burst", false)))
		gs.event_bus.emit(event_name, payload)

func _is_player_relevant(faction: Dictionary) -> bool:
	if gs == null or gs.player == null:
		return false
	var player_key: String = str(int(gs.player.id))
	var members: Dictionary = faction.get("member_ids", {})
	if members.has(player_key):
		return true
	if str(faction.get("kind", "")) == "dynasty" and str(gs.player.last_name) in str(faction.get("name", "")):
		return true
	return false

func _normalize_key(text: String) -> String:
	return str(text).to_lower().strip_edges().replace(" ", "_").replace(":", "_").replace("/", "_")
func _project_realm_power_blocs() -> void:
	if gs == null or gs.realm_engine == null:
		return

	var realm_members_index: Dictionary = _build_living_realm_member_index()

	for raw_realm_id in gs.realm_engine.realms.keys():
		var realm_raw: Variant = gs.realm_engine.realms.get(raw_realm_id, {})
		var realm: Dictionary = realm_raw if typeof(realm_raw) == TYPE_DICTIONARY else {}
		if realm.is_empty():
			continue

		var realm_id: String = str(realm.get("id", raw_realm_id))
		var faction_id: String = "realm_power:%s" % _normalize_key(realm_id)
		var faction: Dictionary = _ensure_faction_shell(
			faction_id,
			str(realm.get("name", "Realm Power Bloc")),
			"realm_power",
			"realm_engine",
			["realm", "sovereignty", "power_bloc"]
		)

		faction ["realm_id"] = realm_id
		faction ["owner_id"] = int(realm.get("ruler_id", -1))
		faction ["leader_id"] = int(realm.get("ruler_id", -1))
		_add_resource_value(faction, "population", float(realm.get("population", 0.0)))
		_add_resource_value(faction, "land", float(realm.get("land", realm.get("land_size", 0.0))))
		_add_resource_value(faction, "claim:realm:%s" % _normalize_key(realm_id), 1.0)
		_inject_realm_population_pressure_resources(faction, int(raw_realm_id), realm)

		var members: Array = realm_members_index.get(int(raw_realm_id), [])
		for raw_member in members:
			var npc: Person = raw_member
			if npc == null or not npc.alive:
				continue
			if int(npc.id) != int(faction.get("leader_id", -1)) and not bool(npc.is_royal) and int(npc.succession_rank) <= 0:
				continue

			var role:= "realm_member"
			if int(npc.id) == int(faction.get("leader_id", -1)):
				role = "ruler"
			elif bool(npc.is_royal):
				role = "royal"
			elif int(npc.succession_rank) > 0 or bool(npc.deposed) or bool(npc.exiled):
				role = "claimant"

			_upsert_member(faction, int(npc.id), role, int(gs.year), _estimate_member_loyalty(npc, faction))
			_absorb_place_into_faction(faction, npc)
			_add_resource_value(faction, "approval_pool", float(npc.approval))
			if bool(npc.palace_owned):
				_add_resource_value(faction, "palace_holdings", 1.0)

		_finalize_faction(faction)
		faction_registry [faction_id] = faction

func _project_royal_courts() -> void:
	if gs == null or gs.realm_engine == null:
		return

	var live_realm_members_index: Dictionary = _build_living_realm_member_index()
	var dormant_realm_official_index: Dictionary = _build_dormant_realm_official_snapshot_index()

	for raw_realm_id in gs.realm_engine.realms.keys():
		var realm_id: int = int(raw_realm_id)
		var realm_raw: Variant = gs.realm_engine.realms.get(raw_realm_id, {})
		var realm: Dictionary = realm_raw if typeof(realm_raw) == TYPE_DICTIONARY else {}
		if realm.is_empty():
			continue

		var government_style: String = str(realm.get("government_style", "State")).strip_edges()
		var realm_key: String = str(realm.get("id", raw_realm_id))
		var realm_name: String = str(realm.get("name", "Realm")).strip_edges()
		var ruler_id: int = int(realm.get("ruler_id", -1))
		var faction_id: String = "royal_court:%s" % _normalize_key(realm_key)
		var faction_name: String = "%s %s" % [
			realm_name,
			"Royal Court" if government_style == "Monarchy" else "State Office"
		]

		var faction: Dictionary = _ensure_faction_shell(
			faction_id,
			faction_name,
			"royal_court",
			"realm_engine",
			["court", "officials", "state", government_style.to_lower()]
		)

		faction ["realm_id"] = realm_key
		faction ["leader_id"] = ruler_id
		faction ["owner_id"] = ruler_id
		_add_resource_value(faction, "claim:realm:%s" % _normalize_key(realm_key), 1.0)

		var projection_state: Dictionary = { "projected_any": false}
		var seen: Dictionary = {}

		var _project_member = func (npc: Person) -> void:
			if npc == null or not npc.alive:
				return
			if int(npc.realm_id) != realm_id:
				return

			var npc_id: int = int(npc.id)
			if npc_id <= 0 or seen.has(npc_id):
				return

			var office_job: String = str(npc.job).strip_edges().to_lower()
			var role:= ""

			if npc_id == ruler_id:
				role = "ruler"
			elif bool(npc.is_royal) or int(npc.succession_rank) > 0 or bool(npc.deposed) or bool(npc.exiled):
				role = "court"
			elif _is_realm_court_office_job(office_job):
				role = "official"
			else:
				return

			projection_state ["projected_any"] = true
			seen [npc_id] = true
			_upsert_member(faction, npc_id, role, int(gs.year), _estimate_member_loyalty(npc, faction))
			_absorb_place_into_faction(faction, npc)
			_add_resource_value(faction, "approval_pool", float(npc.approval))
			if bool(npc.palace_owned):
				_add_resource_value(faction, "palace_holdings", 1.0)

		if ruler_id > 0:
			var ruler = gs.get_or_reactivate_npc_by_id(ruler_id)
			if ruler != null and ruler.alive:
				_project_member.call(ruler)

		var live_members: Array = live_realm_members_index.get(realm_id, [])
		for raw_member in live_members:
			var npc: Person = raw_member
			_project_member.call(npc)

		var dormant_members: Array = dormant_realm_official_index.get(realm_id, [])
		for raw_entry in dormant_members:
			var entry: Dictionary = raw_entry if typeof(raw_entry) == TYPE_DICTIONARY else {}
			var npc_id: int = int(entry.get("npc_id", -1))
			if npc_id <= 0 or seen.has(npc_id):
				continue
			var npc = gs.get_or_reactivate_npc_by_id(npc_id)
			if npc != null and npc.alive:
				_project_member.call(npc)

		if not bool(projection_state.get("projected_any", false)):
			continue

		_finalize_faction(faction)
		faction_registry [faction_id] = faction


func get_realm_court_member_ids(realm_id: int) -> Array:
	var out: Array = []
	if realm_id <= 0:
		return out

	for raw_faction_id in faction_registry.keys():
		var faction_raw: Variant = faction_registry.get(raw_faction_id, {})
		var faction: Dictionary = faction_raw if typeof(faction_raw) == TYPE_DICTIONARY else {}
		if faction.is_empty():
			continue
		if str(faction.get("kind", "")) != "royal_court":
			continue
		if int(faction.get("realm_id", -1)) != realm_id and str(faction.get("realm_id", "")) != str(realm_id):
			continue

		var members_raw: Variant = faction.get("member_ids", {})
		var members: Dictionary = members_raw if typeof(members_raw) == TYPE_DICTIONARY else {}
		for raw_member_key in members.keys():
			out.append(int(raw_member_key))
		break

	return out
func _project_royal_claimants() -> void:
	if gs == null or gs.royalty_engine == null:
		return

	var houses: Dictionary = {}
	for raw_npc in gs.npcs:
		var npc: Person = raw_npc
		if npc == null or not npc.alive:
			continue
		if not bool(npc.is_royal) and int(npc.succession_rank) <= 0 and not bool(npc.deposed) and not bool(npc.exiled):
			continue

		var house_name: String = str(npc.last_name).strip_edges()
		if house_name == "":
			continue

		var realm_key: String = _resolve_realm_group_key(npc)
		var house_key: String = "%s:%s" % [realm_key, _normalize_key(house_name)]
		if not houses.has(house_key):
			houses [house_key] = []
		houses [house_key].append(int(npc.id))

	for raw_house_key in houses.keys():
		var member_ids: Array = houses.get(raw_house_key, [])
		if member_ids.is_empty():
			continue

		var anchor_id: int = _pick_best_claimant_member(member_ids)
		var anchor: Person = gs.get_npc_by_id(anchor_id)
		var house_name: String = anchor.last_name if anchor != null else "Royal House"
		var realm_key: String = _resolve_realm_group_key(anchor) if anchor != null else ""

		var faction_id: String = "royal_house:%s:%s" % [_normalize_key(realm_key), _normalize_key(house_name)]
		var faction: Dictionary = _ensure_faction_shell(
			faction_id,
			"%s House" % house_name,
			"royal_house",
			"royalty_engine",
			["royal", "house", "claimant", "noble"]
		)
		faction ["realm_id"] = realm_key
		if anchor != null:
			faction ["leader_id"] = int(anchor.id)

		_add_resource_value(faction, "claim:house:%s" % _normalize_key(house_name), 1.0)
		if realm_key != "":
			_add_resource_value(faction, "claim:realm:%s" % _normalize_key(realm_key), 0.75)

		for raw_member_id in member_ids:
			var npc_id: int = int(raw_member_id)
			var npc = gs.get_npc_by_id(npc_id)
			if npc == null or not npc.alive:
				continue

			var role:= "royal"
			if bool(npc.is_ruler):
				role = "ruler"
			elif bool(npc.deposed) or bool(npc.exiled) or int(npc.succession_rank) > 0:
				role = "claimant"
			if int(npc.id) == int(faction.get("leader_id", -1)) and role == "royal":
				role = "leader"

			_upsert_member(faction, npc_id, role, int(gs.year), _estimate_member_loyalty(npc, faction))
			_absorb_place_into_faction(faction, npc)
			_add_resource_value(faction, "approval_pool", float(npc.approval))
			if int(npc.succession_rank) > 0:
				_add_resource_value(faction, "succession_weight", max(1.0, 12.0 - float(int(npc.succession_rank))))
			if bool(npc.palace_owned):
				_add_resource_value(faction, "palace_holdings", 1.0)

		_finalize_faction(faction)
		faction_registry [faction_id] = faction


func _project_political_blocs() -> void:
	if gs == null or gs.politics_engine == null:
		return

	var projected_any: bool = false
	for property_name in ["parties", "coalitions", "coup_blocs"]:
		var collection: Dictionary = _read_engine_collection(gs.politics_engine, [property_name])
		if collection.is_empty():
			continue
		projected_any = true
		_project_generic_collection_factions(
			collection,
			"political_bloc",
			"political_bloc",
			"politics_engine",
			["political", "coalition", "coup_bloc"]
		)

	if projected_any:
		return

	var grouped: Dictionary = {}
	for raw_npc in gs.npcs:
		var npc: Person = raw_npc
		if npc == null or not npc.alive:
			continue
		if not bool(npc.is_ruler) and not bool(npc.is_royal) and int(npc.succession_rank) <= 0 and not bool(npc.deposed) and not bool(npc.exiled):
			continue

		var group_key: String = _resolve_realm_group_key(npc)
		if group_key == "":
			continue
		if not grouped.has(group_key):
			grouped [group_key] = []
		grouped [group_key].append(int(npc.id))

	for raw_group_key in grouped.keys():
		var member_ids: Array = grouped.get(raw_group_key, [])
		if member_ids.size() < 2:
			continue

		var leader_id: int = _pick_best_claimant_member(member_ids)
		var leader = gs.get_npc_by_id(leader_id)
		var display_name: String = str(raw_group_key)
		if leader != null and str(leader.home_country) != "":
			display_name = str(leader.home_country)

		var faction_id: String = "political_bloc:%s" % _normalize_key(str(raw_group_key))
		var faction: Dictionary = _ensure_faction_shell(
			faction_id,
			"%s Coalition" % display_name,
			"political_bloc",
			"politics_engine",
			["political", "coalition", "coup_bloc"]
		)
		faction ["realm_id"] = str(raw_group_key)
		faction ["leader_id"] = leader_id
		_add_resource_value(faction, "claim:realm:%s" % _normalize_key(str(raw_group_key)), 1.0)

		for raw_member_id in member_ids:
			var npc_id: int = int(raw_member_id)
			var npc = gs.get_npc_by_id(npc_id)
			if npc == null or not npc.alive:
				continue

			var role:= "operator"
			if int(npc.id) == leader_id:
				role = "leader"
			elif bool(npc.is_ruler):
				role = "ruler"
			elif bool(npc.deposed) or bool(npc.exiled) or int(npc.succession_rank) > 0:
				role = "claimant"

			_upsert_member(faction, npc_id, role, int(gs.year), _estimate_member_loyalty(npc, faction))
			_absorb_place_into_faction(faction, npc)
			_add_resource_value(faction, "approval_pool", float(npc.approval))
			if bool(npc.palace_owned):
				_add_resource_value(faction, "palace_holdings", 1.0)

		_finalize_faction(faction)
		faction_registry [faction_id] = faction


func _project_crime_networks() -> void:
	if gs == null or gs.crime_engine == null:
		return

	var collection: Dictionary = _read_engine_collection(
		gs.crime_engine,
		["crews", "syndicates", "crime_groups", "organizations", "families"]
	)
	if collection.is_empty():
		return

	_project_generic_collection_factions(
		collection,
		"crime_network",
		"crime_network",
		"crime_engine",
		["crime", "crew", "syndicate"]
	)
func _project_justice_institutions() -> void:
	if gs == null or gs.crime_engine == null:
		return
	if not gs.crime_engine.has_method("get_justice_institutions"):
		return

	var collection_raw: Variant = gs.crime_engine.get_justice_institutions()
	var collection: Dictionary = collection_raw if typeof(collection_raw) == TYPE_DICTIONARY else {}
	if collection.is_empty():
		return

	for raw_institution_id in collection.keys():
		var entry_raw: Variant = collection.get(raw_institution_id, {})
		var entry: Dictionary = entry_raw if typeof(entry_raw) == TYPE_DICTIONARY else {}
		if entry.is_empty():
			continue

		var group_id: String = str(entry.get("id", raw_institution_id))
		var institution_type: String = str(entry.get("institution_type", "justice"))
		var faction_id: String = "justice_institution:%s" % _normalize_key(group_id)

		var tags: Array = ["justice", institution_type, "law"]
		var faction: Dictionary = _ensure_faction_shell(
			faction_id,
			str(entry.get("name", group_id)),
			"justice_institution",
			"crime_engine",
			tags
		)

		faction ["institution_type"] = institution_type
		faction ["leader_id"] = int(entry.get("leader_id", -1))
		faction ["owner_id"] = int(entry.get("owner_id", faction.get("leader_id", -1)))
		faction ["founder_id"] = int(entry.get("founder_id", -1))
		faction ["realm_id"] = str(entry.get("realm_id", ""))
		faction ["hidden_realm_id"] = str(entry.get("hidden_realm_id", ""))
		faction ["locality_id"] = str(entry.get("locality_id", ""))

		_add_resource_value(faction, "treasury", float(entry.get("treasury", 0.0)))
		_add_resource_value(faction, "population", float(entry.get("population", entry.get("size", 0.0))))
		_add_resource_value(faction, "land", float(entry.get("territory", 1.0)))
		_add_resource_value(faction, "heat", float(entry.get("heat", entry.get("pressure", 0.0))))
		_add_resource_value(faction, "approval_pool", float(entry.get("approval", 0.0)))

		var realm_id: String = str(entry.get("realm_id", ""))
		if realm_id != "":
			_add_resource_value(faction, "claim:realm:%s" % _normalize_key(realm_id), 1.0)

		var locality_id: String = str(entry.get("locality_id", ""))
		if locality_id != "":
			_add_resource_value(faction, "claim:locality:%s" % _normalize_key(locality_id), 1.0)

		var city: String = str(entry.get("city", ""))
		if city != "":
			_add_resource_value(faction, "claim:city:%s" % _normalize_key(city), 1.0)

		var country: String = str(entry.get("country", ""))
		if country != "":
			_add_resource_value(faction, "claim:country:%s" % _normalize_key(country), 1.0)

		var member_ids: Array = _extract_member_ids(entry.get("members", entry.get("member_ids", [])))
		for raw_member_id in member_ids:
			var npc_id: int = int(raw_member_id)
			var npc = gs.get_npc_by_id(npc_id)
			if npc == null or not npc.alive:
				continue

			var role: String = "member"
			var members_raw: Variant = entry.get("members", {})
			if typeof(members_raw) == TYPE_DICTIONARY and (members_raw as Dictionary).has(str(npc_id)):
				var member_entry_raw: Variant = (members_raw as Dictionary).get(str(npc_id), {})
				var member_entry: Dictionary = member_entry_raw if typeof(member_entry_raw) == TYPE_DICTIONARY else {}
				role = str(member_entry.get("role", role))

			if npc_id == int(faction.get("leader_id", -1)) and role == "member":
				role = "leader"

			_upsert_member(
				faction,
				npc_id,
				role,
				int(gs.year),
				_estimate_member_loyalty(npc, faction)
			)
			_absorb_place_into_faction(faction, npc)

		_finalize_faction(faction)
		faction_registry [faction_id] = faction

func _project_locality_factions() -> void:
	if gs == null or gs.place_influence_engine == null:
		return
	var touched: Dictionary = {}
	for raw_npc in gs.npcs:
		var npc: Person = raw_npc
		if npc == null or not npc.alive:
			continue

		var locality_payload: Dictionary = _get_effective_locality_id(npc)
		var locality_id: String = str(locality_payload.get("locality_id", "")).strip_edges()
		var locality_source: String = str(locality_payload.get("source", "")).strip_edges()
		var locality_address: String = str(locality_payload.get("address", "")).strip_edges()

		if locality_id != "":
			var locality_city: String = str(npc.home_city if str(npc.home_city) != "" else npc.birth_city)
			var locality_country: String = str(npc.home_country if str(npc.home_country) != "" else npc.birth_country)
			var locality_name: String = "Locality %s" % locality_id
			if locality_source == "district_id":
				locality_name = "%s District" % locality_id
			elif locality_source == "address_neighborhood":
				locality_name = "%s Neighborhood" % locality_id
			if locality_city != "":
				locality_name = "%s, %s" % [locality_name, locality_city]

			var locality_faction_id: String = "locality:%s" % _normalize_key(locality_id)
			var locality_faction: Dictionary = _ensure_faction_shell(
				locality_faction_id,
				locality_name,
				"locality",
				"place_influence_engine",
				["place", "neighborhood", "locality"]
			)
			locality_faction ["locality_id"] = locality_id
			locality_faction ["locality_source"] = locality_source
			locality_faction ["district_id"] = str(npc.district_id).strip_edges()
			locality_faction ["settlement_id"] = str(npc.settlement_id).strip_edges()
			locality_faction ["city"] = locality_city
			locality_faction ["country"] = locality_country
			if locality_address != "":
				locality_faction ["sample_address"] = locality_address

			_upsert_member(locality_faction, int(npc.id), "resident", int(gs.year), _estimate_member_loyalty(npc, locality_faction))
			_absorb_place_into_faction(locality_faction, npc)
			_add_resource_value(locality_faction, "claim:locality:%s" % _normalize_key(locality_id), 1.0)
			if locality_source == "address_neighborhood":
				_add_resource_value(locality_faction, "claim:address_neighborhood:%s" % _normalize_key(locality_id), 1.0)
			faction_registry [locality_faction_id] = locality_faction
			touched [locality_faction_id] = true

		var diaspora_tags_raw: Variant = npc.diaspora_tags
		var diaspora_tags: Array = diaspora_tags_raw if typeof(diaspora_tags_raw) == TYPE_ARRAY else []
		for raw_tag in diaspora_tags:
			var tag: String = str(raw_tag).strip_edges()
			if tag == "":
				continue
			var diaspora_faction_id: String = "diaspora:%s" % _normalize_key(tag)
			var diaspora_faction: Dictionary = _ensure_faction_shell(
				diaspora_faction_id,
				"%s Diaspora" % tag,
				"diaspora",
				"place_influence_engine",
				["place", "diaspora", "migration"]
			)
			_upsert_member(diaspora_faction, int(npc.id), "diaspora_member", int(gs.year), _estimate_member_loyalty(npc, diaspora_faction))
			_absorb_place_into_faction(diaspora_faction, npc)
			_add_resource_value(diaspora_faction, "claim:diaspora:%s" % _normalize_key(tag), 1.0)
			faction_registry [diaspora_faction_id] = diaspora_faction
			touched [diaspora_faction_id] = true

		var affinities_raw: Variant = npc.locality_faction_affinities
		var affinities: Dictionary = affinities_raw if typeof(affinities_raw) == TYPE_DICTIONARY else {}
		for raw_affinity_key in affinities.keys():
			var affinity_key: String = str(raw_affinity_key).strip_edges()
			if affinity_key == "":
				continue
			var affinity_value: float = float(affinities.get(raw_affinity_key, 0.0))
			if affinity_value <= 0.0:
				continue
			var affinity_faction_id: String = "locality_affinity:%s" % _normalize_key(affinity_key)
			var affinity_faction: Dictionary = _ensure_faction_shell(
				affinity_faction_id,
				affinity_key,
				"locality_affinity",
				"place_influence_engine",
				["place", "locality_affinity", "identity"]
			)
			_upsert_member(affinity_faction, int(npc.id), "aligned_local", int(gs.year), _estimate_member_loyalty(npc, affinity_faction))
			_absorb_place_into_faction(affinity_faction, npc)
			_add_resource_value(affinity_faction, "claim:locality_affinity:%s" % _normalize_key(affinity_key), max(1.0, affinity_value))
			faction_registry [affinity_faction_id] = affinity_faction
			touched [affinity_faction_id] = true

	for raw_faction_id in touched.keys():
		var faction_id: String = str(raw_faction_id)
		var faction_raw: Variant = faction_registry.get(faction_id, {})
		var faction: Dictionary = faction_raw if typeof(faction_raw) == TYPE_DICTIONARY else {}
		_finalize_faction(faction)
		faction_registry [faction_id] = faction
func _project_many_realms_circles() -> void:
	if gs == null or gs.many_realms_engine == null:
		return

	var realms_raw: Variant = gs.many_realms_engine.hidden_realms
	var hidden_realms: Dictionary = realms_raw if typeof(realms_raw) == TYPE_DICTIONARY else {}
	for raw_realm_id in hidden_realms.keys():
		var realm_raw: Variant = hidden_realms.get(raw_realm_id, {})
		var realm: Dictionary = realm_raw if typeof(realm_raw) == TYPE_DICTIONARY else {}
		if realm.is_empty():
			continue

		var realm_id: String = str(realm.get("id", raw_realm_id))
		var faction_id: String = "many_realms_circle:%s" % _normalize_key(realm_id)
		var faction: Dictionary = _ensure_faction_shell(
			faction_id,
			str(realm.get("name", "Hidden Order")),
			"many_realms_circle",
			"many_realms_engine",
			["many_realms", "hidden_order", "realm_circle"]
		)
		faction ["hidden_realm_id"] = realm_id
		faction ["leader_id"] = int(realm.get("ruler_id", -1))
		faction ["owner_id"] = int(realm.get("ruler_id", -1))

		_add_resource_value(faction, "population", float(realm.get("population", 0.0)))
		_add_resource_value(faction, "treasury", float(realm.get("treasury", 0.0)))
		_add_resource_value(faction, "loyalty", float(realm.get("loyalty", 0.0)))
		_add_resource_value(faction, "prosperity", float(realm.get("prosperity", 0.0)))
		_add_resource_value(faction, "stability", float(realm.get("stability", 0.0)))
		_add_resource_value(faction, "military_pressure", float(realm.get("military_pressure", 0.0)))
		_add_resource_value(faction, "rebel_pressure", float(realm.get("rebel_pressure", 0.0)))
		_add_resource_value(faction, "claim:hidden_realm:%s" % _normalize_key(realm_id), 1.0)
		_add_resource_value(faction, "land", float(realm.get("land", realm.get("land_size", 0.0))))
		_add_resource_value(faction, "military_units", float(realm.get("military_units", 0.0)))
		_add_resource_value(faction, "military_stockpile", float(realm.get("military_stockpile", 0.0)))
		_add_resource_value(faction, "goods_stockpile", float(realm.get("goods_stockpile", 0.0)))
		_add_resource_value(faction, "country_quality", float(realm.get("country_quality", 100.0)))
		if bool((realm.get("trade_rules", {}) as Dictionary).get("rare_artifacts_only", false)):
			_add_resource_value(faction, "artifact_trade_only", 1.0)
		if not bool((realm.get("trade_rules", {}) as Dictionary).get("accepts_bribes", true)):
			_add_resource_value(faction, "anti_bribery_lock", 1.0)
		var services_raw: Variant = realm.get("services", {})
		var services: Dictionary = services_raw if typeof(services_raw) == TYPE_DICTIONARY else {}
		var loan_block: Dictionary = services.get("massive_loans", {})
		_add_resource_value(faction, "loan_capacity", float(loan_block.get("max_loan_value", 0.0)))
		faction ["institution_type"] = "hidden_tribunal"
		faction ["ui_population_browse_allowed"] = not bool(realm.get("hide_people_button", false))
		var existing_tags_raw: Variant = faction.get("tags", [])
		var existing_tags: Array = existing_tags_raw if typeof(existing_tags_raw) == TYPE_ARRAY else []
		if "artifact_trade_only" not in existing_tags and bool((realm.get("trade_rules", {}) as Dictionary).get("rare_artifacts_only", false)):
			existing_tags.append("artifact_trade_only")
		if "balance_arbiter" not in existing_tags and bool((services.get("war_resolution", {}) as Dictionary).get("enabled", false)):
			existing_tags.append("balance_arbiter")
		faction ["tags"] = existing_tags
		_project_many_realms_internal_factions(realm_id, realm)
		var ruler = gs.get_npc_by_id(int(realm.get("ruler_id", -1)))
		if ruler != null and ruler.alive:
			_upsert_member(faction, int(ruler.id), "sovereign", int(gs.year), _estimate_member_loyalty(ruler, faction))
			_absorb_place_into_faction(faction, ruler)

		var houses_raw: Variant = realm.get("ruling_houses", [])
		var houses: Array = houses_raw if typeof(houses_raw) == TYPE_ARRAY else []
		for raw_house in houses:
			var house_name: String = str(raw_house).strip_edges()
			if house_name == "":
				continue
			_add_resource_value(faction, "claim:house:%s" % _normalize_key(house_name), 1.0)
			for raw_npc in gs.npcs:
				var npc: Person = raw_npc
				if npc == null or not npc.alive:
					continue
				if str(npc.last_name) != house_name:
					continue
				_upsert_member(faction, int(npc.id), "house_member", int(gs.year), _estimate_member_loyalty(npc, faction))
				_absorb_place_into_faction(faction, npc)

		_finalize_faction(faction)
		faction_registry [faction_id] = faction
func _project_many_realms_internal_factions(realm_id: String, realm: Dictionary) -> void:
	if realm_id == "":
		return
	var rows_raw: Variant = realm.get("faction_matrix", [])
	var rows: Array = rows_raw if typeof(rows_raw) == TYPE_ARRAY else []
	for raw_row in rows:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = raw_row
		var row_name: String = str(row.get("name", "Era Kingdom Faction")).strip_edges()
		if row_name == "":
			continue
		var internal_id: String = "many_realms_internal:%s:%s" % [
			_normalize_key(realm_id),
			_normalize_key(str(row.get("id", row_name)))
		]
		var internal: Dictionary = _ensure_faction_shell(
			internal_id,
			row_name,
			str(row.get("kind", "many_realms_internal")),
			"many_realms_engine",
			["many_realms", "hidden_order", "internal_circle", str(row.get("purpose", "")).strip_edges()]
		)
		internal ["hidden_realm_id"] = realm_id
		internal ["leader_id"] = int(row.get("leader_id", realm.get("ruler_id", -1)))
		internal ["owner_id"] = int(row.get("leader_id", realm.get("ruler_id", -1)))
		_add_resource_value(internal, "standing", float(row.get("standing", 50.0)))
		_add_resource_value(internal, "represented_population", float(row.get("represented_population", 0.0)))
		_add_resource_value(internal, "claim:hidden_realm:%s" % _normalize_key(realm_id), 1.0)
		_finalize_faction(internal)
		faction_registry [internal_id] = internal

func _project_generic_collection_factions(collection: Dictionary, prefix: String, kind: String, domain: String, tags: Array) -> void:
	if collection.is_empty():
		return

	for raw_group_id in collection.keys():
		var entry_raw: Variant = collection.get(raw_group_id, {})
		var entry: Dictionary = entry_raw if typeof(entry_raw) == TYPE_DICTIONARY else {}
		if entry.is_empty():
			continue

		var group_id: String = str(entry.get("id", raw_group_id))
		var faction_id: String = "%s:%s" % [prefix, _normalize_key(group_id)]
		var faction: Dictionary = _ensure_faction_shell(
			faction_id,
			str(entry.get("name", group_id)),
			kind,
			domain,
			tags
		)

		faction ["leader_id"] = int(entry.get("leader_id", entry.get("owner_id", -1)))
		faction ["owner_id"] = int(entry.get("owner_id", entry.get("leader_id", -1)))
		faction ["founder_id"] = int(entry.get("founder_id", -1))
		faction ["realm_id"] = str(entry.get("realm_id", ""))
		faction ["hidden_realm_id"] = str(entry.get("hidden_realm_id", ""))

		_add_resource_value(faction, "treasury", float(entry.get("treasury", entry.get("cash", 0.0))))
		_add_resource_value(faction, "population", float(entry.get("population", entry.get("size", 0.0))))
		_add_resource_value(faction, "land", float(entry.get("land", entry.get("territory", 0.0))))
		_add_resource_value(faction, "heat", float(entry.get("heat", entry.get("pressure", 0.0))))

		var realm_id: String = str(entry.get("realm_id", ""))
		if realm_id != "":
			_add_resource_value(faction, "claim:realm:%s" % _normalize_key(realm_id), 1.0)

		var hidden_realm_id: String = str(entry.get("hidden_realm_id", ""))
		if hidden_realm_id != "":
			_add_resource_value(faction, "claim:hidden_realm:%s" % _normalize_key(hidden_realm_id), 1.0)

		var locality_id: String = str(entry.get("locality_id", ""))
		if locality_id != "":
			_add_resource_value(faction, "claim:locality:%s" % _normalize_key(locality_id), 1.0)

		var turf_city: String = str(entry.get("turf_city", entry.get("city", "")))
		if turf_city != "":
			_add_resource_value(faction, "claim:city:%s" % _normalize_key(turf_city), 1.0)

		var turf_country: String = str(entry.get("turf_country", entry.get("country", "")))
		if turf_country != "":
			_add_resource_value(faction, "claim:country:%s" % _normalize_key(turf_country), 1.0)

		var member_ids: Array = _extract_member_ids(entry.get("members", entry.get("member_ids", [])))
		for raw_member_id in member_ids:
			var npc_id: int = int(raw_member_id)
			var npc = gs.get_npc_by_id(npc_id)
			if npc == null or not npc.alive:
				continue

			var role:= "member"
			if npc_id == int(faction.get("leader_id", -1)):
				role = "leader"

			_upsert_member(faction, npc_id, role, int(gs.year), _estimate_member_loyalty(npc, faction))
			_absorb_place_into_faction(faction, npc)

		_finalize_faction(faction)
		faction_registry [faction_id] = faction


func _read_engine_collection(engine, candidate_keys: Array) -> Dictionary:
	if engine == null:
		return {}
	for raw_key in candidate_keys:
		var key: String = str(raw_key).strip_edges()
		if key == "":
			continue
		if not _engine_has_property(engine, key):
			continue
		var value = engine.get(key)
		if typeof(value) == TYPE_DICTIONARY:
			return value
	return {}


func _engine_has_property(engine, property_name: String) -> bool:
	if engine == null or property_name == "":
		return false
	for raw_prop in engine.get_property_list():
		var prop: Dictionary = raw_prop if typeof(raw_prop) == TYPE_DICTIONARY else {}
		if str(prop.get("name", "")) == property_name:
			return true
	return false


func _extract_member_ids(raw_members: Variant) -> Array:
	var out: Array = []
	var seen: Dictionary = {}

	if typeof(raw_members) == TYPE_ARRAY:
		var raw_array: Array = raw_members
		for raw_member_id in raw_array:
			var npc_id: int = int(raw_member_id)
			if npc_id <= 0 or seen.has(npc_id):
				continue
			seen [npc_id] = true
			out.append(npc_id)
		return out

	if typeof(raw_members) == TYPE_DICTIONARY:
		var raw_dict: Dictionary = raw_members
		for raw_key in raw_dict.keys():
			var entry: Variant = raw_dict.get(raw_key, {})
			var npc_id: int = -1
			if typeof(entry) == TYPE_DICTIONARY:
				var entry_dict: Dictionary = entry
				npc_id = int(entry_dict.get("npc_id", raw_key))
			else:
				npc_id = int(raw_key)
			if npc_id <= 0 or seen.has(npc_id):
				continue
			seen [npc_id] = true
			out.append(npc_id)

	return out


func _resolve_realm_group_key(npc) -> String:
	if npc == null:
		return ""
	if str(npc.hidden_realm_id) != "":
		return "hidden:%s" % str(npc.hidden_realm_id)
	if int(npc.realm_id) > 0:
		return "realm:%d" % int(npc.realm_id)
	if str(npc.home_country) != "":
		return "country:%s" % _normalize_key(str(npc.home_country))
	return ""


func _pick_best_claimant_member(member_ids: Array) -> int:
	var best_id: int = -1
	var best_rank: int = 999999
	var best_approval: float = -999999.0

	for raw_member_id in member_ids:
		var npc_id: int = int(raw_member_id)
		var npc = gs.get_npc_by_id(npc_id)
		if npc == null or not npc.alive:
			continue
		if bool(npc.is_ruler):
			return int(npc.id)

		var rank: int = int(npc.succession_rank)
		if rank > 0 and rank < best_rank:
			best_rank = rank
			best_id = int(npc.id)
			best_approval = float(npc.approval)
			continue

		if best_id <= 0 and float(npc.approval) > best_approval:
			best_id = int(npc.id)
			best_approval = float(npc.approval)

	return best_id


func _add_resource_value(faction: Dictionary, resource_key: String, amount: float) -> void:
	if resource_key == "":
		return
	var resources_raw: Variant = faction.get("resource_ledger", {})
	var resources: Dictionary = resources_raw if typeof(resources_raw) == TYPE_DICTIONARY else {}
	resources [resource_key] = float(resources.get(resource_key, 0.0)) + amount
	faction ["resource_ledger"] = resources

func bootstrap_population_pressure_projection() -> void:
	bootstrap_static_projection_stage("factions")
	bootstrap_static_projection_stage("relationships")
	bootstrap_static_projection_stage("pressure")

	if typeof(gs.universal_faction_state) != TYPE_DICTIONARY:
		gs.universal_faction_state = {}
	gs.universal_faction_state ["bootstrap_projection_ready"] = true

func bootstrap_static_projection_stage(stage_name: String) -> void:
	if gs == null:
		return
	_ensure_state()

	match stage_name:
		"factions":
			if not faction_registry.is_empty():
				return
			faction_registry.clear()
			_project_all_domains()
			_commit_state()

		"relationships":
			if membership_index.is_empty():
				_rebuild_membership_index()
			if territory_index.is_empty():
				_rebuild_territory_index()
			if relationship_graph.is_empty():
				_rebuild_relationship_graph()
			_commit_state()

		"pressure":
			yearly_identity_drift({ "bootstrap_static_projection": true}, {})

		_:
			return
func _inject_realm_population_pressure_resources(faction: Dictionary, realm_numeric_id: int, _realm: Dictionary) -> void:
	if gs == null:
		return

	var scenario_state_raw: Variant = gs.scenario_state.get("realm_population_pressure", {})
	var scenario_state: Dictionary = scenario_state_raw if typeof(scenario_state_raw) == TYPE_DICTIONARY else {}
	var profile_raw: Variant = scenario_state.get(str(realm_numeric_id), {})
	var profile: Dictionary = profile_raw if typeof(profile_raw) == TYPE_DICTIONARY else {}
	if profile.is_empty():
		return

	_add_resource_value(faction, "low_population_pressure", float(profile.get("low_population_pressure", 0.0)))
	_add_resource_value(faction, "overpopulation_pressure", float(profile.get("overpopulation_pressure", 0.0)))
	_add_resource_value(faction, "elite_gap_pressure", float(profile.get("elite_gap_pressure", 0.0)))
	_add_resource_value(faction, "military_gap_pressure", float(profile.get("military_gap_pressure", 0.0)))
	_add_resource_value(faction, "worker_gap_pressure", float(profile.get("worker_gap_pressure", 0.0)))
	_add_resource_value(faction, "court_capacity", float(profile.get("elite_count", 0)))
	_add_resource_value(faction, "military_capacity", float(profile.get("soldier_count", 0)))
	_add_resource_value(faction, "labor_capacity", float(profile.get("worker_count", 0)))
	_add_resource_value(faction, "youth_cohort", float(profile.get("child_count", 0)))
	_add_resource_value(faction, "young_adult_cohort", float(profile.get("young_adult_count", 0)))
	_add_resource_value(faction, "elder_cohort", float(profile.get("elder_count", 0)))
func _queue_territory_loss_packets(faction: Dictionary, territory_id: String = "") -> void:
	var suffix: String = ""
	if territory_id != "":
		suffix = " around %s" % territory_id
	var text: String = "\n🗺\n %s lost territory%s." % [
		str(faction.get("name", "A faction")),
		suffix
	]
	_queue_packet_bundle(faction, ActionEventTypes.FACTION_LOST_TERRITORY, text)


func _queue_coup_packets(faction: Dictionary, previous_leader_id: int, next_leader_id: int) -> void:
	var previous_leader = gs.get_npc_by_id(previous_leader_id)
	var next_leader = gs.get_npc_by_id(next_leader_id)

	var previous_name: String = previous_leader.first_name if previous_leader != null else "the old leader"
	var next_name: String = next_leader.first_name if next_leader != null else "a new leader"

	var text: String = "\n⚔\n %s displaced %s inside %s." % [
		next_name,
		previous_name,
		str(faction.get("name", "a faction"))
	]
	_queue_packet_bundle(faction, ActionEventTypes.FACTION_COUP, text, next_leader_id)
func _get_npc_primary_residence_address(npc: Person) -> String:
	if npc == null or gs == null or gs.property_engine == null:
		return ""
	var owned_raw: Variant = gs.property_engine.properties.get(int(npc.id), [])
	var owned: Array = owned_raw if typeof(owned_raw) == TYPE_ARRAY else []
	var best_address: String = ""
	var best_score: float = -1.0
	for raw_prop in owned:
		if typeof(raw_prop) != TYPE_DICTIONARY:
			continue
		var prop: Dictionary = raw_prop
		var address: String = str(prop.get("address", "")).strip_edges()
		if address == "":
			continue
		var score: float = float(prop.get("value", prop.get("worth", prop.get("price", 0))))
		if str(prop.get("archetype", "")) == "residence":
			score += 1000000.0
		if score > best_score:
			best_score = score
			best_address = address
	return best_address


func _extract_neighborhood_from_address(address: String) -> String:
	var text: String = str(address).strip_edges()
	if text == "":
		return ""
	var parts: Array = text.split(",")
	if parts.size() >= 2:
		return str(parts [parts.size() - 2]).strip_edges()
	return ""


func _get_effective_locality_id(npc: Person) -> Dictionary:
	if npc == null:
		return {
			"locality_id": "",
			"source": "",
			"address": ""
		}

	var locality_id: String = str(npc.locality_id).strip_edges()
	if locality_id != "":
		return {
			"locality_id": locality_id,
			"source": "locality_id",
			"address": ""
		}

	var district_id: String = str(npc.district_id).strip_edges()
	if district_id != "":
		return {
			"locality_id": district_id,
			"source": "district_id",
			"address": ""
		}

	var address: String = _get_npc_primary_residence_address(npc)
	var address_neighborhood: String = _extract_neighborhood_from_address(address)
	if address_neighborhood != "":
		return {
			"locality_id": address_neighborhood,
			"source": "address_neighborhood",
			"address": address
		}

	return {
		"locality_id": "",
		"source": "",
		"address": address
	}