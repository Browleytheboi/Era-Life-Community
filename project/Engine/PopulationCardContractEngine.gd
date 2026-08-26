extends Resource
class_name PopulationCardContractEngine

const ENGINE_SCHEMA:= "eralife.population_card_contract_engine"
const PACKET_SCHEMA:= "eralife.population_card_graph_packet"
const CARD_SCHEMA:= "eralife.population_card_packet"
const EDGE_SCHEMA:= "eralife.population_card_graph_edge"
const CONTRACT_VERSION:= 1

const DEFAULT_ROYAL_LIMIT:= 48
const DEFAULT_NOBLE_LIMIT:= 48
const DEFAULT_NOBLE_TARGET_MIN:= 12
const DEFAULT_MASTER_LIMIT:= 32
const DEFAULT_CITIZEN_LIMIT:= 150

const DEFAULT_US_CABINET_TARGET:= 16
const DEFAULT_US_SENATE_TARGET:= 100
const DEFAULT_US_SUPREME_COURT_TARGET:= 9
const DEFAULT_US_GOVERNOR_TARGET:= 50

const UNITED_STATES_STATE_NAMES:= [
	"Alabama",
	"Alaska",
	"Arizona",
	"Arkansas",
	"California",
	"Colorado",
	"Connecticut",
	"Delaware",
	"Florida",
	"Georgia",
	"Hawaii",
	"Idaho",
	"Illinois",
	"Indiana",
	"Iowa",
	"Kansas",
	"Kentucky",
	"Louisiana",
	"Maine",
	"Maryland",
	"Massachusetts",
	"Michigan",
	"Minnesota",
	"Mississippi",
	"Missouri",
	"Montana",
	"Nebraska",
	"Nevada",
	"New Hampshire",
	"New Jersey",
	"New Mexico",
	"New York",
	"North Carolina",
	"North Dakota",
	"Ohio",
	"Oklahoma",
	"Oregon",
	"Pennsylvania",
	"Rhode Island",
	"South Carolina",
	"South Dakota",
	"Tennessee",
	"Texas",
	"Utah",
	"Vermont",
	"Virginia",
	"Washington",
	"West Virginia",
	"Wisconsin",
	"Wyoming"
]

var gs = null
var packets_by_realm: Dictionary = {}
var alias_to_realm_key: Dictionary = {}
var dirty_realm_ids: Dictionary = {}
var game_state_subscription_ready: bool = false
var last_build_report: Dictionary = {}


func _init(_gs = null) -> void:
	bind_game_state(_gs)


func bind_game_state(_gs) -> void:
	gs = _gs
	_subscribe_to_game_state()
	_commit_registry()
func reset_runtime() -> void:
	packets_by_realm.clear()
	alias_to_realm_key.clear()
	dirty_realm_ids.clear()
	last_build_report.clear()



	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state [
			"population_card_contract_engine_runtime_reset"
		] = true
		gs.scenario_state [
			"population_card_contract_engine_runtime_reset_at_ms"
		] = int(Time.get_ticks_msec())
func register_default_prewarm_contracts(prewarm_engine, host, context: Dictionary = {}) -> Dictionary:
	if prewarm_engine == null:
		return {
			"success": false,
			"reason": "missing_prewarm_engine",
			"schema": ENGINE_SCHEMA
		}

	if host == null:
		return {
			"success": false,
			"reason": "missing_host",
			"schema": ENGINE_SCHEMA
		}

	if not prewarm_engine.has_method("register_prewarm_contract"):
		return {
			"success": false,
			"reason": "prewarm_engine_missing_register_method",
			"schema": ENGINE_SCHEMA
		}

	var realm_ids: Array = []
	if context.has("realm_ids") and typeof(context.get("realm_ids", [])) == TYPE_ARRAY:
		realm_ids = context.get("realm_ids", []).duplicate(true)

	var dependencies: Array = [
		"life_shell_snapshot"
	]

	if bool(context.get("depends_on_truth_resolution", false)):
		dependencies.append("truth_resolution_population_government")

	prewarm_engine.register_prewarm_contract("population_card_graph_packets", {
		"title": "Population Card Graph Packets",
		"group": "population",
		"lane": "population",
		"priority": 400,
		"required": false,
		"ready_gate": false,
		"can_parallelize": true,
		"owner": host,
		"execute_method": "_global_prewarm_population_card_surfaces_now",
		"execute_args": [
			str(context.get("reason", "population_card_contract_engine_default_prewarm")),
			realm_ids
		],
		"verify_method": "_global_prewarm_verify_population_card_surfaces",
		"verify_args": [
			realm_ids
		],
		"recover_method": "_global_prewarm_population_card_surfaces_now",
		"recover_args": [
			"population_card_contract_engine_default_recovery",
			realm_ids
		],
		"dependencies": dependencies.duplicate(true),
		"metadata": {
			"source_engine": ENGINE_SCHEMA,
			"population_cards_are_contract_artifacts": true,
			"population_card_contract_engine_projects_truth_only": true,
			"ui_is_renderer_only": true
		}
	})

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"registered": true,
		"contract_id": "population_card_graph_packets",
		"ready_gate": false,
		"depends_on_truth_resolution": bool(context.get("depends_on_truth_resolution", false)),
		"ui_is_renderer_only": true
	}
func _ensure_global_node_contract_engine() -> GlobalNodeContractEngine:
	if gs == null:
		return null

	if "global_node_contract_engine" in gs and gs.global_node_contract_engine != null:
		return gs.global_node_contract_engine

	var global_engine: GlobalNodeContractEngine = GlobalNodeContractEngine.new(gs)
	gs.global_node_contract_engine = global_engine

	return global_engine


func _register_population_packet_with_global_node_engine(packet: Dictionary, context: Dictionary = {}) -> Dictionary:
	if packet.is_empty():
		return {}

	var global_engine: GlobalNodeContractEngine = _ensure_global_node_contract_engine()
	if global_engine == null:
		return {}

	return global_engine.ingest_population_card_graph_packet(
		packet,
		{
			"source": ENGINE_SCHEMA,
			"domain_adapter": "PopulationCardContractEngine",
			"population_edges_are_node_edge_contracts": true,
			"ui_is_renderer_only": true,
			"ready_door_may_not_wait": true
		}.merged(context, true)
	)



func prebuild_realm_packet(realm_id: int, realm_name: String = "", options: Dictionary = {}) -> Dictionary:
	if gs == null:
		return _fail("missing_game_state", realm_id, realm_name)

	if realm_id <= 0:
		return _fail("invalid_realm_id", realm_id, realm_name)

	var resolved_realm_name: String = str(realm_name).strip_edges()
	if resolved_realm_name == "":
		resolved_realm_name = _realm_name_for_id(realm_id)

	var people: Array = _derive_realm_population_entities(
		realm_id,
		bool(options.get("include_dormant", true))
	)

	people.sort_custom(func (a, b):
		return _person_sort_score(a, realm_id) > _person_sort_score(b, realm_id)
	)

	var buckets: Dictionary = _categorize_population(people, realm_id, resolved_realm_name, options)
	var federal_republic_contract: Dictionary = _federal_republic_population_contract_for_realm(
		people,
		buckets,
		realm_id,
		resolved_realm_name,
		options
	)

	var role_label_by_person_id: Dictionary = {}
	var civic_metadata_by_person_id: Dictionary = {}

	var royals: Array = []
	var nobles: Array = []
	var masters: Array = []
	var citizens: Array = []

	var federal_executive: Array = []
	var federal_cabinet: Array = []
	var federal_senate: Array = []
	var federal_supreme_court: Array = []
	var federal_governors: Array = []

	var noble_target_min: int = int(options.get("noble_target_min", DEFAULT_NOBLE_TARGET_MIN))

	if bool(federal_republic_contract.get("enabled", false)):
		federal_executive = federal_republic_contract.get("executive", []) if typeof(federal_republic_contract.get("executive", [])) == TYPE_ARRAY else []
		federal_cabinet = federal_republic_contract.get("cabinet", []) if typeof(federal_republic_contract.get("cabinet", [])) == TYPE_ARRAY else []
		federal_senate = federal_republic_contract.get("senate", []) if typeof(federal_republic_contract.get("senate", [])) == TYPE_ARRAY else []
		federal_supreme_court = federal_republic_contract.get("supreme_court", []) if typeof(federal_republic_contract.get("supreme_court", [])) == TYPE_ARRAY else []
		federal_governors = federal_republic_contract.get("governors", []) if typeof(federal_republic_contract.get("governors", [])) == TYPE_ARRAY else []
		citizens = federal_republic_contract.get("citizens", []) if typeof(federal_republic_contract.get("citizens", [])) == TYPE_ARRAY else []

		role_label_by_person_id = federal_republic_contract.get("role_label_by_person_id", {}) if typeof(federal_republic_contract.get("role_label_by_person_id", {})) == TYPE_DICTIONARY else {}
		civic_metadata_by_person_id = federal_republic_contract.get("civic_metadata_by_person_id", {}) if typeof(federal_republic_contract.get("civic_metadata_by_person_id", {})) == TYPE_DICTIONARY else {}

		royals = federal_executive
		nobles = []
		masters = []
		noble_target_min = 0
	else:
		if not _realm_uses_noble_court(realm_id, resolved_realm_name):
			noble_target_min = 0

		buckets = _ensure_noble_court_minimum(
			buckets,
			people,
			realm_id,
			resolved_realm_name,
			noble_target_min
		)

		royals = _limit_people(buckets.get("royals", []), int(options.get("royal_limit", DEFAULT_ROYAL_LIMIT)))
		nobles = _limit_people(buckets.get("nobles", []), int(options.get("noble_limit", DEFAULT_NOBLE_LIMIT)))
		masters = _limit_people(buckets.get("masters", []), int(options.get("master_limit", DEFAULT_MASTER_LIMIT)))
		citizens = _select_citizen_wall_population(
			buckets.get("citizens", []),
			int(options.get("citizen_limit", DEFAULT_CITIZEN_LIMIT)),
			realm_id,
			resolved_realm_name
		)

	var visible_ids: Dictionary = _visible_entity_ids([
		royals,
		nobles,
		masters,
		citizens,
		federal_executive,
		federal_cabinet,
		federal_senate,
		federal_supreme_court,
		federal_governors
	])

	var packet_options: Dictionary = options.duplicate(true)
	packet_options ["role_label_by_person_id"] = role_label_by_person_id.duplicate(true)
	packet_options ["civic_metadata_by_person_id"] = civic_metadata_by_person_id.duplicate(true)
	packet_options ["federal_republic_population_contract"] = bool(federal_republic_contract.get("enabled", false))
	var cards_by_entity_id: Dictionary = {}
	var graph_node_contracts: Dictionary = {}
	var graph_edges_by_source: Dictionary = {}
	var all_edges: Array = []

	_build_card_and_graph_packets_for_group(
		cards_by_entity_id,
		graph_node_contracts,
		graph_edges_by_source,
		all_edges,
		royals,
		visible_ids,
		realm_id,
		resolved_realm_name,
		"royal",
		packet_options
	)

	_build_card_and_graph_packets_for_group(
		cards_by_entity_id,
		graph_node_contracts,
		graph_edges_by_source,
		all_edges,
		nobles,
		visible_ids,
		realm_id,
		resolved_realm_name,
		"noble",
		packet_options
	)

	_build_card_and_graph_packets_for_group(
		cards_by_entity_id,
		graph_node_contracts,
		graph_edges_by_source,
		all_edges,
		masters,
		visible_ids,
		realm_id,
		resolved_realm_name,
		"master",
		packet_options
	)

	_build_card_and_graph_packets_for_group(
		cards_by_entity_id,
		graph_node_contracts,
		graph_edges_by_source,
		all_edges,
		citizens,
		visible_ids,
		realm_id,
		resolved_realm_name,
		"citizen",
		packet_options
	)
	if bool(federal_republic_contract.get("enabled", false)):
		_build_card_and_graph_packets_for_group(
			cards_by_entity_id,
			graph_node_contracts,
			graph_edges_by_source,
			all_edges,
			federal_executive,
			visible_ids,
			realm_id,
			resolved_realm_name,
			"federal_executive",
			packet_options
		)

		_build_card_and_graph_packets_for_group(
			cards_by_entity_id,
			graph_node_contracts,
			graph_edges_by_source,
			all_edges,
			federal_cabinet,
			visible_ids,
			realm_id,
			resolved_realm_name,
			"federal_cabinet",
			packet_options
		)

		_build_card_and_graph_packets_for_group(
			cards_by_entity_id,
			graph_node_contracts,
			graph_edges_by_source,
			all_edges,
			federal_senate,
			visible_ids,
			realm_id,
			resolved_realm_name,
			"federal_senate",
			packet_options
		)

		_build_card_and_graph_packets_for_group(
			cards_by_entity_id,
			graph_node_contracts,
			graph_edges_by_source,
			all_edges,
			federal_supreme_court,
			visible_ids,
			realm_id,
			resolved_realm_name,
			"federal_supreme_court",
			packet_options
		)

		_build_card_and_graph_packets_for_group(
			cards_by_entity_id,
			graph_node_contracts,
			graph_edges_by_source,
			all_edges,
			federal_governors,
			visible_ids,
			realm_id,
			resolved_realm_name,
			"federal_governor",
			packet_options
		)
	all_edges.sort_custom(func (a, b):
		return float((a as Dictionary).get("lod_score", 0.0)) > float((b as Dictionary).get("lod_score", 0.0))
	)

	var packet: Dictionary = {
		"schema": PACKET_SCHEMA,
		"version": CONTRACT_VERSION,
		"category_contract_version": 9,
		"classification_authority": "PopulationCardContractEngine",
		"federal_republic_population_contract": bool(federal_republic_contract.get("enabled", false)),
		"federal_republic_contract_version": 1 if bool(federal_republic_contract.get("enabled", false)) else 0,
		"united_states_geographical_states": federal_republic_contract.get("state_names", []) if bool(federal_republic_contract.get("enabled", false)) else [],
		"noble_court_minimum_target": noble_target_min,
		"citizen_wall_limit_default": DEFAULT_CITIZEN_LIMIT,
		"realm_population_source_policy": "all_realm_cities_and_dormant_entities",
		"engine_schema": ENGINE_SCHEMA,
		"realm_id": realm_id,
		"realm_name": resolved_realm_name,
		"built_for_year": int(_value(gs, "year", 0)),
		"built_at_ms": int(Time.get_ticks_msec()),

		"population_reality_input_count": people.size(),
		"visible_card_count": cards_by_entity_id.size(),

		"royals": royals,
		"nobles": nobles,
		"masters": masters,
		"citizens": citizens,
		"federal_executive": federal_executive,
		"federal_cabinet": federal_cabinet,
		"federal_senate": federal_senate,
		"federal_supreme_court": federal_supreme_court,
		"federal_governors": federal_governors,
		"federal_republic_contract_packet": federal_republic_contract.duplicate(true),

		"officials": royals,

		"cards_by_entity_id": cards_by_entity_id,
		"graph_visible_entity_ids": visible_ids,
		"graph_node_contracts": graph_node_contracts,
		"graph_edges_by_source": graph_edges_by_source,
		"graph_edges": all_edges,

		"category_order": [
			"royals",
			"nobles",
			"masters",
			"citizens"
		],

		"card_layout_policy": _default_card_layout_policy(),
		"graph_projection_policy": _default_graph_projection_policy(),
		"lod_policy": _default_lod_policy(),

		"ui_is_renderer_only": true,
		"engine_creates_no_controls": true,
		"engine_creates_no_line2d": true,
		"population_cards_are_contract_artifacts": true,
		"ready_door_may_not_wait": true,
		"click_path_build_forbidden": true,
	}

	var key: String = _realm_key(realm_id)
	packets_by_realm [key] = packet
	_register_aliases_for_packet(key, packet, options)
	dirty_realm_ids.erase(realm_id)

	var global_node_graph_packet: Dictionary = _register_population_packet_with_global_node_engine(
		packet,
		{
			"source": "population_card_contract_engine.prebuild_realm_packet",
			"realm_id": realm_id,
			"realm_name": resolved_realm_name,
			"population_scope": str(options.get("population_scope", "contract_population_card_graph")),
			"tail_registry": bool(options.get("tail_registry", false)),
			"player_realm_first": bool(options.get("player_realm_first", false)),
			"ready_door_may_not_wait": true
		}
	)

	if not global_node_graph_packet.is_empty():
		packet ["global_node_graph_packet"] = global_node_graph_packet.duplicate(true)
		packet ["global_node_scope_id"] = str(global_node_graph_packet.get("scope_id", ""))
		packet ["global_node_registry_hot"] = true
		packets_by_realm [key] = packet

	last_build_report = {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"realm_id": realm_id,
		"realm_name": resolved_realm_name,
		"population_reality_input_count": people.size(),
		"visible_card_count": cards_by_entity_id.size(),
		"edge_count": all_edges.size(),
		"global_node_registry_hot": not global_node_graph_packet.is_empty(),
		"global_node_scope_id": str(global_node_graph_packet.get("scope_id", "")),
		"built_at_ms": int(Time.get_ticks_msec()),
		"ready_door_may_not_wait": true
	}

	_commit_registry()

	return packet.duplicate(true)

func view_contract_for_realm(realm_id: int, realm_name: String = "", options: Dictionary = {}) -> Dictionary:
	var packet: Dictionary = {}

	var explicit_partial_request: bool = bool(options.get("population_truth_shard_event", false)) \
or bool(options.get("surface_already_exists", false)) \
or bool(options.get("truth_may_be_partial", false)) \
or bool(options.get("population_cards_may_project_partial_truth", false))

	var must_project_observable_cards: bool = bool(options.get("force_rebuild", false)) \
or bool(options.get("view_contract_only", false)) \
or bool(options.get("population_lens_viewer", false)) \
or bool(options.get("realm_population_contract_panel", false)) \
or bool(options.get("force_materialize_for_population_lens", false)) \
or bool(options.get("crr_surface_self_heal", false)) \
or bool(options.get("browse_population_surface", false))

	var partial_read_allowed: bool = explicit_partial_request and not must_project_observable_cards

	if partial_read_allowed:
		packet = packet_for_realm(realm_id, realm_name)
		if packet.is_empty():
			packet = _partial_observable_packet_for_realm(realm_id, realm_name, options)
	else:
		packet = prebuild_realm_packet(realm_id, realm_name, options)

	if packet.is_empty() or not bool(packet.get("success", true)):
		packet = packet_for_realm(realm_id, realm_name)

	if packet.is_empty():
		packet = _partial_observable_packet_for_realm(realm_id, realm_name, options.merged({
			"crr_surface_self_heal": true,
			"population_cards_may_project_partial_truth": true
		}, true))

	if packet.is_empty() or not bool(packet.get("success", true)):
		return {}

	var global_node_graph_packet: Dictionary = {}
	if typeof(packet.get("global_node_graph_packet", {})) == TYPE_DICTIONARY:
		global_node_graph_packet = packet.get("global_node_graph_packet", {}).duplicate(true)

	if global_node_graph_packet.is_empty():
		global_node_graph_packet = _register_population_packet_with_global_node_engine(
			packet,
			{
				"source": "population_card_contract_engine.view_contract_for_realm",
				"realm_id": realm_id,
				"realm_name": str(packet.get("realm_name", realm_name)),
				"ready_door_may_not_wait": true,
				"ui_is_renderer_only": true
			}
		)

	var federal_republic_enabled: bool = bool(packet.get("federal_republic_population_contract", false))
	var federal_contract_packet: Dictionary = {}
	if typeof(packet.get("federal_republic_contract_packet", {})) == TYPE_DICTIONARY:
		federal_contract_packet = packet.get("federal_republic_contract_packet", {}).duplicate(true)

	var category_order: Array = packet.get("category_order", []) if typeof(packet.get("category_order", [])) == TYPE_ARRAY else []
	if federal_republic_enabled:
		category_order = [
			"federal_executive",
			"federal_cabinet",
			"federal_senate",
			"federal_supreme_court",
			"federal_governor",
			"citizen"
		]

	return {
		"schema": "eralife.crown_population_wall_view_contract",
		"version": 7,
		"source_engine": ENGINE_SCHEMA,
		"realm_id": int(packet.get("realm_id", realm_id)),
		"realm_name": str(packet.get("realm_name", realm_name)),
		"element": str(options.get("element", _realm_element_for_name(str(packet.get("realm_name", realm_name))))),
		"population_scope": str(options.get("population_scope", "contract_population_card_graph")),

		"federal_republic_population_contract": federal_republic_enabled,
		"federal_republic_contract_packet": federal_contract_packet.duplicate(true),
		"federal_executive": packet.get("federal_executive", []).duplicate(true) if typeof(packet.get("federal_executive", [])) == TYPE_ARRAY else [],
		"federal_cabinet": packet.get("federal_cabinet", []).duplicate(true) if typeof(packet.get("federal_cabinet", [])) == TYPE_ARRAY else [],
		"federal_senate": packet.get("federal_senate", []).duplicate(true) if typeof(packet.get("federal_senate", [])) == TYPE_ARRAY else [],
		"federal_supreme_court": packet.get("federal_supreme_court", []).duplicate(true) if typeof(packet.get("federal_supreme_court", [])) == TYPE_ARRAY else [],
		"federal_governors": packet.get("federal_governors", []).duplicate(true) if typeof(packet.get("federal_governors", [])) == TYPE_ARRAY else [],

		"royals": packet.get("royals", []).duplicate(true) if typeof(packet.get("royals", [])) == TYPE_ARRAY else [],
		"officials": packet.get("officials", packet.get("royals", [])).duplicate(true) if typeof(packet.get("officials", packet.get("royals", []))) == TYPE_ARRAY else [],
		"nobles": packet.get("nobles", []).duplicate(true) if typeof(packet.get("nobles", [])) == TYPE_ARRAY else [],
		"masters": packet.get("masters", []).duplicate(true) if typeof(packet.get("masters", [])) == TYPE_ARRAY else [],
		"citizens": packet.get("citizens", []).duplicate(true) if typeof(packet.get("citizens", [])) == TYPE_ARRAY else [],

		"population_card_packets": packet.get("cards_by_entity_id", {}).duplicate(true) if typeof(packet.get("cards_by_entity_id", {})) == TYPE_DICTIONARY else {},
		"population_card_graph_packet": packet.duplicate(true),

		"global_node_graph_packet": global_node_graph_packet.duplicate(true),
		"global_node_scope_id": str(global_node_graph_packet.get("scope_id", packet.get("global_node_scope_id", ""))),
		"global_node_registry_hot": not global_node_graph_packet.is_empty(),

		"graph_visible_entity_ids": packet.get("graph_visible_entity_ids", {}).duplicate(true) if typeof(packet.get("graph_visible_entity_ids", {})) == TYPE_DICTIONARY else {},
		"graph_node_contracts": packet.get("graph_node_contracts", {}).duplicate(true) if typeof(packet.get("graph_node_contracts", {})) == TYPE_DICTIONARY else {},
		"graph_edges_by_source": packet.get("graph_edges_by_source", {}).duplicate(true) if typeof(packet.get("graph_edges_by_source", {})) == TYPE_DICTIONARY else {},
		"graph_edges": packet.get("graph_edges", []).duplicate(true) if typeof(packet.get("graph_edges", [])) == TYPE_ARRAY else [],
		"category_order": category_order.duplicate(true),

		"card_layout_policy": packet.get("card_layout_policy", _default_card_layout_policy()),
		"graph_projection_policy": packet.get("graph_projection_policy", _default_graph_projection_policy()),
		"lod_policy": packet.get("lod_policy", _default_lod_policy()),

		"built_at_ms": int(packet.get("built_at_ms", Time.get_ticks_msec())),
		"built_for_year": int(packet.get("built_for_year", _value(gs, "year", 0))),

		"ui_is_renderer_only": true,
		"view_contract_only": true,
		"does_not_create_people": true,
		"does_not_call_realm_engine_on_press": true,
		"relationship_graph_is_authority": true,
		"hover_does_not_call_engines": true,
		"hover_only_draws_cached_truth": true,
		"population_cards_are_contract_artifacts": true,
		"population_cards_are_global_nodes": true,
		"population_edges_are_node_edge_contracts": true,
		"ready_door_may_not_wait": true,
		"click_path_build_forbidden": true,
		"crr_surface_self_heal": bool(options.get("crr_surface_self_heal", false))
	}
func _partial_observable_packet_for_realm(realm_id: int, realm_name: String = "", options: Dictionary = {}) -> Dictionary:
	var resolved_realm_name: String = str(realm_name).strip_edges()
	if resolved_realm_name == "":
		resolved_realm_name = _realm_name_for_id(realm_id)

	var federal_enabled: bool = _is_united_states_federal_realm(realm_id, resolved_realm_name)

	var federal_executive: Array = []
	var role_label_by_person_id: Dictionary = {}
	var civic_metadata_by_person_id: Dictionary = {}
	var used_ids: Dictionary = {}

	if federal_enabled:
		var executive_ids: Array = []
		var president_id: int = -1
		var first_partner_id: int = -1

		if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
			president_id = int(gs.scenario_state.get("presidential_parent_contract_president_id", -1))
			first_partner_id = int(gs.scenario_state.get("presidential_parent_contract_first_partner_id", -1))

			var scenario_executive_raw: Variant = gs.scenario_state.get("presidential_parent_contract_federal_executive_ids", [])
			if typeof(scenario_executive_raw) == TYPE_ARRAY:
				for raw_scenario_id in scenario_executive_raw:
					var scenario_id: int = int(raw_scenario_id)
					if scenario_id > 0 and not executive_ids.has(scenario_id):
						executive_ids.append(scenario_id)

		if president_id > 0 and not executive_ids.has(president_id):
			executive_ids.insert(0, president_id)

		if first_partner_id > 0 and not executive_ids.has(first_partner_id):
			executive_ids.append(first_partner_id)

		if gs != null and gs.realm_engine != null and "realms" in gs.realm_engine and typeof(gs.realm_engine.realms) == TYPE_DICTIONARY:
			var realm_raw: Variant = gs.realm_engine.realms.get(realm_id, {})
			if typeof(realm_raw) == TYPE_DICTIONARY:
				var realm: Dictionary = realm_raw
				var realm_executive_raw: Variant = realm.get("federal_executive_person_ids", [])
				if typeof(realm_executive_raw) == TYPE_ARRAY:
					for raw_realm_id in realm_executive_raw:
						var realm_person_id: int = int(raw_realm_id)
						if realm_person_id > 0 and not executive_ids.has(realm_person_id):
							executive_ids.append(realm_person_id)

		for raw_person_id in executive_ids:
			var person_id: int = int(raw_person_id)
			if person_id <= 0:
				continue

			var person = _person_by_id(person_id)
			if person == null:
				continue

			if int(_value(person, "id", -1)) <= 0:
				continue

			if used_ids.has(person_id):
				continue

			federal_executive.append(person)
			used_ids [person_id] = true

		for i in range(federal_executive.size()):
			var executive_person = federal_executive [i]
			var executive_person_id: int = int(_value(executive_person, "id", -1))
			if executive_person_id <= 0:
				continue

			var role_label: String = str(_value(executive_person, "job", _value(executive_person, "civic_title", ""))).strip_edges()
			if executive_person_id == president_id:
				role_label = "President"
			elif executive_person_id == first_partner_id:
				role_label = _federal_republic_first_partner_role_label(executive_person)
			elif role_label == "":
				role_label = "Executive Official"

			_federal_republic_mark_role(
				executive_person,
				role_label,
				"executive",
				"",
				10000 - i,
				role_label_by_person_id,
				civic_metadata_by_person_id,
				used_ids
			)

	var cards_by_entity_id: Dictionary = {}
	var graph_visible_entity_ids: Dictionary = _visible_entity_ids([
		federal_executive
	])
	var graph_node_contracts: Dictionary = {}
	var graph_edges_by_source: Dictionary = {}
	var graph_edges: Array = []

	var packet_options: Dictionary = options.duplicate(true)
	packet_options ["role_label_by_person_id"] = role_label_by_person_id.duplicate(true)
	packet_options ["civic_metadata_by_person_id"] = civic_metadata_by_person_id.duplicate(true)
	packet_options ["federal_republic_population_contract"] = federal_enabled

	if federal_enabled and not federal_executive.is_empty():
		_build_card_and_graph_packets_for_group(
			cards_by_entity_id,
			graph_node_contracts,
			graph_edges_by_source,
			graph_edges,
			federal_executive,
			graph_visible_entity_ids,
			realm_id,
			resolved_realm_name,
			"federal_executive",
			packet_options
		)

	graph_edges.sort_custom(func (a, b):
		return float((a as Dictionary).get("lod_score", 0.0)) > float((b as Dictionary).get("lod_score", 0.0))
	)

	var federal_packet: Dictionary = _federal_republic_partial_surface_contract(realm_id, resolved_realm_name, options) if federal_enabled else {}
	if federal_enabled:
		federal_packet ["executive"] = federal_executive.duplicate(true)
		federal_packet ["role_label_by_person_id"] = role_label_by_person_id.duplicate(true)
		federal_packet ["civic_metadata_by_person_id"] = civic_metadata_by_person_id.duplicate(true)
		federal_packet ["partial_surface_preserves_known_executive"] = true
		federal_packet ["known_executive_card_count"] = federal_executive.size()

	return {
		"success": true,
		"schema": "eralife.population_card_contract_engine.partial_observable_packet",
		"version": CONTRACT_VERSION,
		"realm_id": realm_id,
		"realm_name": resolved_realm_name,
		"element": str(options.get("element", _realm_element_for_name(resolved_realm_name))),
		"truth_state": "partial",
		"federal_republic_population_contract": federal_enabled,
		"federal_republic_contract_packet": federal_packet.duplicate(true),
		"federal_executive": federal_executive.duplicate(true),
		"federal_cabinet": [],
		"federal_senate": [],
		"federal_supreme_court": [],
		"federal_governors": [],
		"royals": federal_executive.duplicate(true) if federal_enabled else [],
		"officials": federal_executive.duplicate(true) if federal_enabled else [],
		"nobles": [],
		"masters": [],
		"citizens": [],
		"cards_by_entity_id": cards_by_entity_id,
		"graph_visible_entity_ids": graph_visible_entity_ids,
		"graph_node_contracts": graph_node_contracts,
		"graph_edges_by_source": graph_edges_by_source,
		"graph_edges": graph_edges,
		"category_order": [
			"federal_executive",
			"federal_cabinet",
			"federal_senate",
			"federal_supreme_court",
			"federal_governor",
			"citizen"
		] if federal_enabled else [
			"royals",
			"nobles",
			"masters",
			"citizens"
		],
		"card_layout_policy": _default_card_layout_policy(),
		"graph_projection_policy": _default_graph_projection_policy(),
		"lod_policy": _default_lod_policy(),
		"built_at_ms": int(Time.get_ticks_msec()),
		"built_for_year": int(_value(gs, "year", 0)),
		"ui_is_renderer_only": true,
		"engine_creates_no_controls": true,
		"ready_door_may_not_wait": true,
		"click_path_build_forbidden": true,
	}
func _truth_projection_group_rows(
	groups: Dictionary,
	group_key: String
) -> Array:
	var rows_raw: Variant = groups.get(
		group_key,
		[]
	)

	if typeof(rows_raw) != TYPE_ARRAY:
		return []

	return (
		rows_raw as Array
	).duplicate(false)


func _population_social_class_accent_key(
	social_class: String
) -> String:
	var key: String = str(
		social_class
	).strip_edges().to_lower()

	if (
		key.find("royal") >= 0
		or key.find("sovereign") >= 0
		or key.find("elite") >= 0
		or key.find("upper") >= 0
		or key.find("gentry") >= 0
	):
		return "social_upper"

	if (
		key.find("merchant") >= 0
		or key.find("middle") >= 0
		or key.find("professional") >= 0
	):
		return "social_middle"

	if (
		key.find("artisan") >= 0
		or key.find("guild") >= 0
		or key.find("technical") >= 0
		or key.find("skilled") >= 0
	):
		return "social_skilled"

	if (
		key.find("working") >= 0
		or key.find("commoner") >= 0
		or key.find("peasant") >= 0
		or key.find("serf") >= 0
		or key.find("service") >= 0
		or key.find("frontier") >= 0
	):
		return "social_working"

	if (
		key.find("poor") >= 0
		or key.find("servant") >= 0
		or key.find("lower") >= 0
	):
		return "social_lower"

	return "social_citizen"


func _population_social_class_section_key(
	social_class: String
) -> String:
	var clean: String = str(
		social_class
	).strip_edges().to_lower()
	var out: String = ""

	for index in range(
		clean.length()
	):
		var character: String = clean.substr(
			index,
			1
		)

		if character in [
			"a", "b", "c", "d", "e", "f", "g",
			"h", "i", "j", "k", "l", "m", "n",
			"o", "p", "q", "r", "s", "t", "u",
			"v", "w", "x", "y", "z", "0", "1",
			"2", "3", "4", "5", "6", "7", "8", "9"
		]:
			out += character
		elif not out.ends_with("_"):
			out += "_"

	out = out.trim_prefix(
		"_"
	).trim_suffix(
		"_"
	)

	if out == "":
		out = "citizen"

	return "social_%s" % out


func _truth_projection_combined_rows(
	groups: Dictionary,
	group_keys: Array
) -> Array:
	var out: Array = []
	var seen: Dictionary = {}

	for raw_group_key in group_keys:
		var rows: Array = (
			_truth_projection_group_rows(
				groups,
				str(
					raw_group_key
				)
			)
		)

		for raw_row in rows:
			var identity: String = (
				_population_renderer_row_identity(
					raw_row
				)
			)

			if (
				identity == ""
				or seen.has(
					identity
				)
			):
				continue

			seen [
				identity
			] = true
			out.append(
				raw_row
			)

	return out
func _population_section_contracts_from_truth(
		groups: Dictionary,
		truth_packet: Dictionary,
		federal_enabled: bool,
		realm_name: String,
		element: String
) -> Array:
		var sections: Array = []
		var profile_raw: Variant = truth_packet.get(
			"government_profile",
			{}
		)
		var profile: Dictionary = (
			profile_raw as Dictionary
			if typeof(profile_raw) == TYPE_DICTIONARY
			else {}
		)
		var titles_raw: Variant = profile.get(
			"section_titles",
			{}
		)
		var titles: Dictionary = (
			titles_raw as Dictionary
			if typeof(titles_raw) == TYPE_DICTIONARY
			else {}
		)
		var subtitles_raw: Variant = profile.get(
			"section_subtitles",
			{}
		)
		var subtitles: Dictionary = (
			subtitles_raw as Dictionary
			if typeof(subtitles_raw) == TYPE_DICTIONARY
			else {}
		)

		if federal_enabled:
			for raw_spec in [
				{
					"group_key": "executive",
					"key": "federal_executive",
					"title": "EXECUTIVE BRANCH",
					"subtitle": (
						"President, Vice President, and First Family."
					),
					"accent_key": "federal_executive",
					"glow": 0.36,
					"columns": 2
				},
				{
					"group_key": "cabinet",
					"key": "federal_cabinet",
					"title": "EXECUTIVE CABINET",
					"subtitle": (
						"Federal departments and executive administration."
					),
					"accent_key": "federal_cabinet",
					"glow": 0.24,
					"columns": 5
				},
				{
					"group_key": "senate",
					"key": "federal_legislative",
					"title": (
						"LEGISLATIVE BRANCH • SENATE"
					),
					"subtitle": (
						"Two senators per geographical state."
					),
					"accent_key": "federal_legislative",
					"glow": 0.2,
					"columns": 7
				},
				{
					"group_key": "supreme_court",
					"key": "federal_judicial",
					"title": (
						"JUDICIAL BRANCH • SUPREME COURT"
					),
					"subtitle": (
						"The federal constitutional judiciary."
					),
					"accent_key": "federal_judicial",
					"glow": 0.22,
					"columns": 4
				},
				{
					"group_key": "governors",
					"key": "federal_state_governors",
					"title": (
						"STATE EXECUTIVES • GOVERNORS"
					),
					"subtitle": (
						"Governors of the geographical states."
					),
					"accent_key": "federal_governor",
					"glow": 0.18,
					"columns": 7
				}
			]:
				var spec: Dictionary = (
					raw_spec as Dictionary
				)
				var rows: Array = (
					_truth_projection_group_rows(
						groups,
						str(
							spec.get(
								"group_key",
								""
							)
						)
					)
				)

				if rows.is_empty():
					continue

				var section: Dictionary = (
					spec.duplicate(false)
				)

				section.erase(
					"group_key"
				)
				section [
					"rows"
				] = rows
				section [
					"section_kind"
				] = str(
					spec.get(
						"key",
						"government"
					)
				)

				sections.append(
					section
				)
		else:
			for group_key in [
				"sovereign",
				"royal_court",
				"noble_court",
				"executive",
				"legislative",
				"judicial",
				"military_command",
				"masters"
			]:
				var rows: Array = (
					_truth_projection_group_rows(
						groups,
						group_key
					)
				)

				if rows.is_empty():
					continue

				var default_title: String = (
					group_key.replace(
						"_",
						""
					).to_upper()
				)
				var title: String = str(
					titles.get(
						group_key,
						default_title
					)
				)
				var subtitle: String = str(
					subtitles.get(
						group_key,
						"Realm government and court authority."
					)
				)
				var accent_key: String = "government"
				var glow: float = 0.2
				var columns: int = 5

				match group_key:
					"sovereign", "royal_court":
						accent_key = "royal"
						glow = 0.36
						columns = 3

					"noble_court":
						accent_key = "noble"
						glow = 0.28
						columns = 4

					"executive":
						accent_key = "executive"
						glow = 0.24

					"legislative":
						accent_key = "legislative"
						glow = 0.2

					"judicial":
						accent_key = "judicial"
						glow = 0.22
						columns = 4

					"military_command":
						accent_key = "military"
						glow = 0.24

					"masters":
						accent_key = "elemental"
						glow = 0.42

				sections.append({
					"key": group_key,
					"title": title,
					"subtitle": subtitle,
					"rows": rows,
					"accent_key": accent_key,
					"glow": glow,
					"columns": columns,
					"section_kind": group_key
				})

		var citizens: Array = (
			_truth_projection_group_rows(
				groups,
				"citizens"
			)
		)
		var citizens_by_class: Dictionary = {}
		var class_order: Array = []

		for raw_citizen in citizens:
			if typeof(raw_citizen) != TYPE_DICTIONARY:
				continue

			var citizen: Dictionary = (
				raw_citizen as Dictionary
			)
			var social_class: String = str(
				citizen.get(
					"social_class",
					"Citizens"
				)
			).strip_edges()

			if social_class == "":
				social_class = "Citizens"

			if not citizens_by_class.has(
				social_class
			):
				citizens_by_class [
					social_class
				] = []
				class_order.append(
					social_class
				)

			(
				citizens_by_class [
					social_class
				] as Array
			).append(
				citizen
			)



		class_order.sort_custom(
			Callable(
				self,
				"_population_social_class_precedes"
			)
		)

		for raw_social_class in class_order:
			var social_class: String = str(
				raw_social_class
			)
			var rows: Array = (
				citizens_by_class.get(
					social_class,
					[]
				) as Array
			).duplicate(false)

			if rows.is_empty():
				continue

			sections.append({
				"key": (
					_population_social_class_section_key(
						social_class
					)
				),
				"title": social_class.to_upper(),
				"subtitle": (
					"%s residents of %s, grouped by social class."
					% [
						social_class,
						realm_name
					]
				),
				"rows": rows,
				"accent_key": (
					_population_social_class_accent_key(
						social_class
					)
				),
				"glow": 0.14,
				"columns": 7,
				"section_kind": "citizen",
				"social_class": social_class,
				"element": element
			})

		return sections
func project_truth_packet_for_realm(
	realm_id: int,
	realm_name: String,
	truth_packet: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	if realm_id <= 0 or truth_packet.is_empty():
		return {
			"success": false,
			"reason": "invalid_projection_request",
			"schema": ENGINE_SCHEMA,
			"ui_is_renderer_only": true
		}

	var resolved_realm_name: String = str(
		realm_name
	).strip_edges()

	if resolved_realm_name == "":
		resolved_realm_name = str(
			truth_packet.get(
				"realm_name",
				_realm_name_for_id(
					realm_id
				)
			)
		).strip_edges()

	var groups_raw: Variant = truth_packet.get(
		"groups",
		{}
	)
	var groups: Dictionary = (
		groups_raw as Dictionary
		if typeof(groups_raw) == TYPE_DICTIONARY
		else {}
	)
	var federal_enabled: bool = (
		str(
			truth_packet.get(
				"government_model",
				""
			)
		).strip_edges().to_lower()
		== "federal_presidential_republic"
		or _is_united_states_federal_realm(
			realm_id,
			resolved_realm_name
		)
	)
	var element: String = str(
		context.get(
			"element",
			_realm_element_for_name(
				resolved_realm_name
			)
		)
	)
	var federal_executive: Array = (
		_truth_projection_group_rows(
			groups,
			"executive"
		)
	)
	var federal_cabinet: Array = (
		_truth_projection_group_rows(
			groups,
			"cabinet"
		)
	)
	var federal_senate: Array = (
		_truth_projection_group_rows(
			groups,
			"senate"
		)
	)
	var federal_supreme_court: Array = (
		_truth_projection_group_rows(
			groups,
			"supreme_court"
		)
	)
	var federal_governors: Array = (
		_truth_projection_group_rows(
			groups,
			"governors"
		)
	)
	var citizens: Array = (
		_truth_projection_group_rows(
			groups,
			"citizens"
		)
	)
	var royals: Array = (
		_truth_projection_combined_rows(
			groups,
			[
				"sovereign",
				"royal_court"
			]
		)
	)
	var officials: Array = (
		_truth_projection_combined_rows(
			groups,
			[
				"sovereign",
				"royal_court",
				"executive",
				"legislative",
				"judicial",
				"military_command"
			]
		)
	)
	var nobles: Array = (
		_truth_projection_group_rows(
			groups,
			"noble_court"
		)
	)
	var masters: Array = (
		_truth_projection_group_rows(
			groups,
			"masters"
		)
	)
	var section_contracts: Array = (
		_population_section_contracts_from_truth(
			groups,
			truth_packet,
			federal_enabled,
			resolved_realm_name,
			element
		)
	)
	var category_order: Array = []

	for raw_section in section_contracts:
		if typeof(raw_section) != TYPE_DICTIONARY:
			continue

		category_order.append(
			str(
				(raw_section as Dictionary).get(
					"key",
					"population"
				)
			)
		)

	var packet: Dictionary = {
		"success": true,
		"schema": (
			"eralife.population_card_contract_engine."
			+ "truth_projection_packet"
		),
		"version": CONTRACT_VERSION,
		"realm_id": realm_id,
		"realm_name": resolved_realm_name,
		"element": element,
		"government_model": str(
			truth_packet.get(
				"government_model",
				"realm_government"
			)
		),
		"government_profile": (
			truth_packet.get(
				"government_profile",
				{}
			)
			if typeof(
				truth_packet.get(
					"government_profile",
					{}
				)
			) == TYPE_DICTIONARY
			else {}
		),
		"truth_state": str(
			truth_packet.get(
				"truth_state",
				"partial"
			)
		),
		"truth_complete": bool(
			truth_packet.get(
				"truth_complete",
				false
			)
		),
		"federal_republic_population_contract": (
			federal_enabled
		),
		"federal_republic_contract_packet": {
			"enabled": federal_enabled,
			"schema": (
				"eralife.population_card_contract_engine."
				+ "federal_republic_packet.truth_projection"
			),
			"version": CONTRACT_VERSION,
			"realm_id": realm_id,
			"realm_name": resolved_realm_name,
			"government_model": (
				"federal_presidential_republic"
			),
			"executive": (
				federal_executive.duplicate(false)
			),
			"cabinet": (
				federal_cabinet.duplicate(false)
			),
			"senate": (
				federal_senate.duplicate(false)
			),
			"supreme_court": (
				federal_supreme_court.duplicate(false)
			),
			"governors": (
				federal_governors.duplicate(false)
			),
			"citizens": citizens.duplicate(false),
			"ui_is_renderer_only": true
		},
		"federal_executive": (
			federal_executive.duplicate(false)
		),
		"federal_cabinet": (
			federal_cabinet.duplicate(false)
		),
		"federal_senate": (
			federal_senate.duplicate(false)
		),
		"federal_supreme_court": (
			federal_supreme_court.duplicate(false)
		),
		"federal_governors": (
			federal_governors.duplicate(false)
		),
		"royals": (
			federal_executive.duplicate(false)
			if federal_enabled
			else royals.duplicate(false)
		),
		"officials": (
			federal_executive.duplicate(false)
			if federal_enabled
			else officials.duplicate(false)
		),
		"nobles": nobles.duplicate(false),
		"masters": masters.duplicate(false),
		"citizens": citizens.duplicate(false),
		"population_section_contracts": (
			section_contracts.duplicate(false)
		),
		"cards_by_entity_id": {},
		"graph_visible_entity_ids": {},
		"graph_node_contracts": {},
		"graph_edges_by_source": {},
		"graph_edges": [],
		"category_order": category_order.duplicate(false),
		"card_layout_policy": (
			_default_card_layout_policy()
		),
		"graph_projection_policy": (
			_default_graph_projection_policy()
		),
		"lod_policy": _default_lod_policy(),
		"built_at_ms": int(
			Time.get_ticks_msec()
		),
		"built_for_year": int(
			_value(
				gs,
				"year",
				0
			)
		),
		"ui_is_renderer_only": true,
		"engine_creates_no_controls": true,
		"ready_door_may_not_wait": true,
		"click_path_build_forbidden": true,
	}
	var key: String = _realm_key(
		realm_id
	)
	var previous_packet_raw: Variant = (
		packets_by_realm.get(
			key,
			{}
		)
	)
	var previous_packet: Dictionary = (
		previous_packet_raw as Dictionary
		if typeof(
			previous_packet_raw
		) == TYPE_DICTIONARY
		else {}
	)
	var renderer_delta: Dictionary = (
		_population_renderer_delta_from_packets(
			previous_packet,
			packet
		)
	)

	packets_by_realm [
		key
	] = packet

	_register_aliases_for_packet(
		key,
		packet,
		context
	)

	dirty_realm_ids.erase(
		realm_id
	)

	last_build_report = {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"reason": (
			"truth_packet_projected_for_realm"
		),
		"realm_id": realm_id,
		"realm_name": resolved_realm_name,
		"truth_state": str(
			packet.get(
				"truth_state",
				"partial"
			)
		),
		"visible_government_and_social_sections": (
			section_contracts.size()
		),
		"visible_citizens": citizens.size(),
		"ui_is_renderer_only": true,
		"built_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	_commit_registry()

	if (
		gs != null
		and gs.event_bus != null
	):
		gs.event_bus.emit(
			"population.card_graph_packet.updated",
			{
				"source": ENGINE_SCHEMA,
				"realm_id": realm_id,
				"realm_name": resolved_realm_name,
				"truth_state": str(
					packet.get(
						"truth_state",
						"partial"
					)
				),
				"renderer_delta": renderer_delta,
				"delta_row_count": int(
					renderer_delta.get(
						"delta_row_count",
						0
					)
				),
				"ui_is_renderer_only": true
			}
		)

	return packet.duplicate(false)
func packet_for_realm(realm_id: int, realm_name: String = "") -> Dictionary:
	var key: String = _resolve_realm_key(realm_id, realm_name)
	if key == "":
		return {}

	var packet_raw: Variant = packets_by_realm.get(key, {})
	if typeof(packet_raw) != TYPE_DICTIONARY:
		return {}

	return (packet_raw as Dictionary).duplicate(true)


func has_packet_for(realm_id: int, realm_name: String = "") -> bool:
	return not packet_for_realm(realm_id, realm_name).is_empty()


func mark_realm_dirty(realm_id: int, reason: String = "population_truth_changed") -> void:
	if realm_id <= 0:
		return

	dirty_realm_ids [realm_id] = {
		"reason": reason,
		"dirty_at_ms": int(Time.get_ticks_msec())
	}

	_commit_registry()


func export_registry() -> Dictionary:
	return {
		"schema": ENGINE_SCHEMA,
		"version": CONTRACT_VERSION,
		"packets_by_realm": packets_by_realm.duplicate(true),
		"alias_to_realm_key": alias_to_realm_key.duplicate(true),
		"dirty_realm_ids": dirty_realm_ids.duplicate(true),
		"last_build_report": last_build_report.duplicate(true),
		"registry_count": packets_by_realm.size(),
		"ready_door_may_not_wait": true,
		"ui_is_renderer_only": true
	}


func _build_card_and_graph_packets_for_group(
	cards_by_entity_id: Dictionary,
	graph_node_contracts: Dictionary,
	graph_edges_by_source: Dictionary,
	all_edges: Array,
	people: Array,
	visible_entity_ids: Dictionary,
	realm_id: int,
	realm_name: String,
	category: String,
	options: Dictionary = {}
) -> void:
	for raw_person in people:
		if raw_person == null:
			continue
		if not bool(_value(raw_person, "alive", true)):
			continue

		var entity_id: String = _entity_id_for_person(raw_person)
		if entity_id == "":
			continue

		var card_packet: Dictionary = _card_packet_for_person(
			raw_person,
			realm_id,
			realm_name,
			category,
			options
		)

		if card_packet.is_empty():
			continue

		cards_by_entity_id [entity_id] = card_packet

		var graph_contract: Dictionary = _relationship_graph_contract_for_person(
			raw_person,
			visible_entity_ids,
			realm_id,
			realm_name,
			category,
			options
		)

		if graph_contract.is_empty():
			graph_contract = {
				"success": true,
				"schema": "eralife.population_graph_hover_contract",
				"source_entity_id": entity_id,
				"source_person_id": int(_value(raw_person, "id", -1)),
				"source_name": str(card_packet.get("display_name", entity_id)),
				"edges": [],
				"edge_count": 0,
				"ui_is_renderer_only": true,
				"hover_zero_engine_calls": true
			}

		var normalized_edges: Array = []
		var edges_raw: Variant = graph_contract.get("edges", [])
		if typeof(edges_raw) == TYPE_ARRAY:
			var edge_index: int = 0
			for raw_edge in edges_raw:
				if typeof(raw_edge) != TYPE_DICTIONARY:
					continue

				var edge: Dictionary = _normalize_edge_packet(
					entity_id,
					raw_edge as Dictionary,
					edge_index,
					realm_id,
					realm_name,
					category
				)

				if edge.is_empty():
					continue

				normalized_edges.append(edge)
				all_edges.append(edge)
				edge_index += 1

		normalized_edges.sort_custom(func (a, b):
			return float((a as Dictionary).get("lod_score", 0.0)) > float((b as Dictionary).get("lod_score", 0.0))
		)

		graph_contract ["edges"] = normalized_edges
		graph_contract ["edge_count"] = normalized_edges.size()
		graph_contract ["population_card_contract_engine_normalized"] = true
		graph_contract ["source_card_packet"] = card_packet.duplicate(true)
		graph_contract ["ui_is_renderer_only"] = true
		graph_contract ["hover_zero_engine_calls"] = true

		graph_node_contracts [entity_id] = graph_contract
		graph_edges_by_source [entity_id] = normalized_edges


func _card_packet_for_person(person, realm_id: int, realm_name: String, category: String, _options: Dictionary = {}) -> Dictionary:
	var person_id: int = int(_value(person, "id", -1))
	if person_id <= 0:
		return {}

	var entity_id: String = _entity_id_for_person(person)
	var display_name: String = _display_name(person)
	var role_label_by_person_id: Dictionary = _options.get("role_label_by_person_id", {}) if typeof(_options.get("role_label_by_person_id", {})) == TYPE_DICTIONARY else {}
	var civic_metadata_by_person_id: Dictionary = _options.get("civic_metadata_by_person_id", {}) if typeof(_options.get("civic_metadata_by_person_id", {})) == TYPE_DICTIONARY else {}

	var role_label: String = str(role_label_by_person_id.get(person_id, role_label_by_person_id.get(str(person_id), ""))).strip_edges()
	if role_label == "":
		role_label = _role_label_for_person(person, realm_id, category)

	var civic_metadata: Dictionary = civic_metadata_by_person_id.get(person_id, civic_metadata_by_person_id.get(str(person_id), {})) if typeof(civic_metadata_by_person_id.get(person_id, civic_metadata_by_person_id.get(str(person_id), {}))) == TYPE_DICTIONARY else {}
	var accent_key: String = _accent_key_for_category(category, person)

	return {
		"schema": CARD_SCHEMA,
		"version": CONTRACT_VERSION,
		"entity_id": entity_id,
		"person_id": person_id,
		"display_name": display_name,
		"age": int(_value(person, "age", 0)),
		"realm_id": realm_id,
		"realm_name": realm_name,
		"category": category,
		"section_kind": _section_kind_for_category(category),
		"role_label": role_label,
		"civic_metadata": civic_metadata.duplicate(true),
		"accent_key": accent_key,

		"is_you": _is_player(person),
		"is_ruler": bool(_value(person, "is_ruler", false)),
		"is_royal": bool(_value(person, "is_royal", false)),
		"succession_rank": int(_value(person, "succession_rank", 0)),

		"layout": {
			"min_size": _card_min_size_for_person(person, realm_id, realm_name, category),
			"size_class": _card_size_class_for_person(person, realm_id, realm_name, category),
			"royal_pair_pulse_enabled": _is_realm_ruler_partner_person(person, realm_id),
			"micro_pulse_enabled": _is_realm_ruler_partner_person(person, realm_id),
		},

		"anchor_points": {
			"LEFT": "left",
			"RIGHT": "right",
			"TOP": "top",
			"BOTTOM": "bottom"
		},

		"route_policy": {
			"if_target_right": {
				"source_anchor": "RIGHT",
				"target_anchor": "LEFT"
			},
			"if_target_left": {
				"source_anchor": "LEFT",
				"target_anchor": "RIGHT"
			},
			"if_target_below": {
				"source_anchor": "BOTTOM",
				"target_anchor": "TOP"
			},
			"if_target_above": {
				"source_anchor": "TOP",
				"target_anchor": "BOTTOM"
			},
			"curve_mode": "cubic_bezier",
		},

		"stats": _stat_rows_for_person(person, realm_id, category),
		"relationship_preview_rows": _relationship_preview_rows_for_person(person),

		"ui_is_renderer_only": true,
	}


func _normalize_edge_packet(
	source_entity_id: String,
	raw_edge: Dictionary,
	edge_index: int,
	realm_id: int,
	realm_name: String,
	category: String
) -> Dictionary:
	var edge: Dictionary = raw_edge.duplicate(true)

	var target_entity_id: String = str(edge.get("target_entity_id", "")).strip_edges()
	if target_entity_id == "":
		var target_id: int = int(edge.get("target_person_id", edge.get("target_id", edge.get("person_id", -1))))
		if target_id > 0:
			target_entity_id = "human:%d" % target_id

	if target_entity_id == "" or target_entity_id == source_entity_id:
		return {}

	var line_kind: String = _line_kind_from_edge(edge)
	var bond: int = clampi(int(edge.get("bond", 50)), 0, 100)
	var importance: float = _importance_weight_for_edge(edge, line_kind)
	var weight: float = float(edge.get("weight", _line_weight_from_bond_and_kind(bond, line_kind, importance)))
	var lod_score: float = float(edge.get("lod_score", _lod_score_for_edge(bond, weight, importance)))

	edge ["schema"] = EDGE_SCHEMA
	edge ["version"] = CONTRACT_VERSION
	edge ["source_entity_id"] = source_entity_id
	edge ["target_entity_id"] = target_entity_id
	edge ["realm_id"] = realm_id
	edge ["realm_name"] = realm_name
	edge ["source_category"] = category
	edge ["line_kind"] = line_kind
	edge ["bond"] = bond
	edge ["weight"] = weight
	edge ["line_weight"] = weight
	edge ["thickness"] = weight
	edge ["importance_weight"] = importance
	edge ["lod_score"] = lod_score
	edge ["edge_index"] = edge_index
	edge ["relationship_color_key"] = _color_key_for_line_kind(line_kind)
	edge ["animated_flow"] = true
	edge ["flow_mode"] = "pulse_particles"
	edge ["flow_direction"] = "source_to_target"
	edge ["gradient_slide_enabled"] = true
	edge ["parallel_lane_key"] = "%s:%s:%s:%d" % [source_entity_id, target_entity_id, line_kind, edge_index]
	edge ["parallel_lane_separation_enabled"] = true
	edge ["curve_mode"] = "cubic_bezier"
	edge ["anchor_route_enabled"] = true
	edge ["line_weight_represents_bond"] = true
	edge ["ui_draws_line_only"] = true
	edge ["ui_does_not_calculate_relationship"] = true
	edge ["graph_is_authority"] = true

	return edge


func _relationship_graph_contract_for_person(
	person,
	visible_entity_ids: Dictionary,
	realm_id: int,
	realm_name: String,
	category: String,
	options: Dictionary = {}
) -> Dictionary:
	var fallback: Dictionary = _fallback_population_hover_contract_for_person(
		person,
		visible_entity_ids,
		realm_id,
		realm_name,
		category,
		options
	)

	if gs == null:
		return fallback

	if not (person is Person):
		fallback ["relationship_graph_contract_engine_skipped"] = true
		fallback ["skip_reason"] = "dormant_population_entity_not_full_person"
		fallback ["dormant_entities_use_population_card_hover_contract"] = true
		return fallback

	var rel_engine = _value(gs, "relationship_graph_contract_engine", null)
	if rel_engine == null:
		return fallback

	if not rel_engine.has_method("population_hover_contract_for_person"):
		return fallback

	var contract: Dictionary = rel_engine.population_hover_contract_for_person(
		person,
		visible_entity_ids,
		{
			"source": ENGINE_SCHEMA,
			"realm_id": realm_id,
			"realm_name": realm_name,
			"section_kind": _section_kind_for_category(category),
			"category": category,
			"role_label": _role_label_for_person(person, realm_id, category),
			"ui_is_renderer_only": true,
			"hover_zero_engine_calls": true,
			"population_cards_are_contract_artifacts": true,
			"ready_door_may_not_wait": true
		}.merged(options, true)
	)

	var edges_raw: Variant = contract.get("edges", [])
	if typeof(edges_raw) == TYPE_ARRAY and not (edges_raw as Array).is_empty():
		contract = _merge_population_hover_contract_edges(contract, fallback)
		contract ["hover_zero_engine_calls"] = true
		contract ["edges_prebuilt_before_hover"] = true
		return contract

	return fallback
func _merge_population_hover_contract_edges(primary: Dictionary, fallback: Dictionary) -> Dictionary:
	var out: Dictionary = primary.duplicate(true)
	var edges: Array = []
	var seen: Dictionary = {}

	var primary_edges_raw: Variant = primary.get("edges", [])
	if typeof(primary_edges_raw) == TYPE_ARRAY:
		for raw_edge in primary_edges_raw as Array:
			if typeof(raw_edge) != TYPE_DICTIONARY:
				continue

			var edge: Dictionary = raw_edge
			var target_entity_id: String = str(edge.get("target_entity_id", "")).strip_edges()
			var line_kind: String = str(edge.get("line_kind", "relationship")).strip_edges()
			var edge_key: String = "%s|%s" % [target_entity_id, line_kind]

			edges.append(edge.duplicate(true))
			seen [edge_key] = true

	var fallback_edges_raw: Variant = fallback.get("edges", [])
	if typeof(fallback_edges_raw) == TYPE_ARRAY:
		for raw_fallback_edge in fallback_edges_raw as Array:
			if typeof(raw_fallback_edge) != TYPE_DICTIONARY:
				continue

			var fallback_edge: Dictionary = raw_fallback_edge
			var fallback_target_entity_id: String = str(fallback_edge.get("target_entity_id", "")).strip_edges()
			var fallback_line_kind: String = str(fallback_edge.get("line_kind", "relationship")).strip_edges()
			var fallback_edge_key: String = "%s|%s" % [fallback_target_entity_id, fallback_line_kind]

			if fallback_target_entity_id == "":
				continue
			if seen.has(fallback_edge_key):
				continue

			edges.append(fallback_edge.duplicate(true))
			seen [fallback_edge_key] = true

			if edges.size() >= 14:
				break

	out ["edges"] = edges
	out ["edge_count"] = edges.size()
	out ["edges_prebuilt_before_hover"] = true
	out ["hover_zero_engine_calls"] = true
	out ["population_card_fallback_edges_merged"] = true
	out ["ui_is_renderer_only"] = true

	return out


func _population_card_hover_civic_contract(person) -> Dictionary:
	var raw_contract: Variant = _value(person, "civic_office_contract", {})
	if typeof(raw_contract) == TYPE_DICTIONARY:
		return (raw_contract as Dictionary).duplicate(true)

	return {}


func _population_card_hover_branch_for_person(person, fallback_category: String = "") -> String:
	var civic_contract: Dictionary = _population_card_hover_civic_contract(person)
	var branch: String = str(civic_contract.get("branch", "")).strip_edges().to_lower()

	if branch != "":
		return branch

	var clean_category: String = str(fallback_category).strip_edges().to_lower()
	match clean_category:
		"federal_executive":
			return "executive"
		"federal_cabinet":
			return "cabinet"
		"federal_senate":
			return "senate"
		"federal_supreme_court":
			return "judicial"
		"federal_governor":
			return "state_governor"
		"citizen":
			return "civilian"
		_:
			pass

	var strata: String = str(_value(person, "population_class_strata", "")).strip_edges()
	if strata != "":
		return "civilian"

	return ""


func _population_card_hover_office_for_person(person) -> String:
	var civic_contract: Dictionary = _population_card_hover_civic_contract(person)
	var office: String = str(civic_contract.get("office", "")).strip_edges()
	if office != "":
		return office

	var civic_title: String = str(_value(person, "civic_title", "")).strip_edges()
	if civic_title != "":
		return civic_title

	return str(_value(person, "job", "")).strip_edges()


func _population_card_hover_state_for_person(person) -> String:
	var civic_contract: Dictionary = _population_card_hover_civic_contract(person)
	var state_name: String = str(civic_contract.get("state_name", "")).strip_edges()
	if state_name != "":
		return state_name

	state_name = str(_value(person, "home_state", "")).strip_edges()
	if state_name != "":
		return state_name

	return str(_value(person, "birth_state", "")).strip_edges()


func _population_card_hover_target_from_entity_id(entity_id: String):
	var clean_entity_id: String = str(entity_id).strip_edges()
	if clean_entity_id == "":
		return null

	if clean_entity_id.begins_with("human:"):
		var id_text: String = clean_entity_id.substr("human:".length()).strip_edges()
		var person_id: int = int(id_text)
		if person_id > 0:
			return _person_by_id(person_id)

	return null


func _federal_republic_hover_edge_spec(
	source,
	target,
	source_branch: String,
	target_branch: String,
	source_state: String,
	target_state: String
) -> Dictionary:
	var clean_source_branch: String = str(source_branch).strip_edges().to_lower()
	var clean_target_branch: String = str(target_branch).strip_edges().to_lower()
	var source_office: String = _population_card_hover_office_for_person(source)
	var target_office: String = _population_card_hover_office_for_person(target)
	var same_state: bool = source_state != "" and source_state == target_state

	if clean_source_branch == "" or clean_target_branch == "":
		return {}

	if clean_source_branch == "executive" and clean_target_branch == "cabinet":
		return {
			"label": "Cabinet Member",
			"line_kind": "federal_executive",
			"bond": 78,
			"importance": 0.78
		}

	if clean_source_branch == "cabinet" and clean_target_branch == "executive":
		return {
			"label": "Reports to Executive Office",
			"line_kind": "federal_executive",
			"bond": 78,
			"importance": 0.78
		}

	if clean_source_branch == "executive" and clean_target_branch == "senate":
		return {
			"label": "Legislative Check",
			"line_kind": "federal_balance",
			"bond": 58,
			"importance": 0.55
		}

	if clean_source_branch == "senate" and clean_target_branch == "executive":
		return {
			"label": "Checks Executive Power",
			"line_kind": "federal_balance",
			"bond": 58,
			"importance": 0.55
		}

	if clean_source_branch == "executive" and clean_target_branch == "judicial":
		return {
			"label": "Constitutional Check",
			"line_kind": "federal_judicial",
			"bond": 54,
			"importance": 0.58
		}

	if clean_source_branch == "judicial" and clean_target_branch == "executive":
		return {
			"label": "Judicial Review",
			"line_kind": "federal_judicial",
			"bond": 54,
			"importance": 0.58
		}

	if clean_source_branch == "senate" and clean_target_branch == "judicial":
		return {
			"label": "Confirmation Power",
			"line_kind": "federal_judicial",
			"bond": 52,
			"importance": 0.5
		}

	if clean_source_branch == "judicial" and clean_target_branch == "senate":
		return {
			"label": "Constitutional Branch Tie",
			"line_kind": "federal_judicial",
			"bond": 52,
			"importance": 0.5
		}

	if clean_source_branch == "senate" and clean_target_branch == "state_governor" and same_state:
		return {
			"label": "State-Federal Link",
			"line_kind": "federal_state",
			"bond": 66,
			"importance": 0.62
		}

	if clean_source_branch == "state_governor" and clean_target_branch == "senate" and same_state:
		return {
			"label": "State-Federal Link",
			"line_kind": "federal_state",
			"bond": 66,
			"importance": 0.62
		}

	if clean_source_branch == "state_governor" and clean_target_branch == "executive":
		return {
			"label": "Federal-State Executive Tie",
			"line_kind": "federal_state",
			"bond": 50,
			"importance": 0.44
		}

	if clean_source_branch == "executive" and clean_target_branch == "state_governor":
		return {
			"label": "Federal-State Executive Tie",
			"line_kind": "federal_state",
			"bond": 50,
			"importance": 0.44
		}

	if clean_source_branch == "civilian" and clean_target_branch in ["executive", "cabinet", "senate", "judicial", "state_governor"]:
		return {
			"label": "Represented By",
			"line_kind": "constituent",
			"bond": 42,
			"importance": 0.34
		}

	if clean_target_branch == "civilian" and clean_source_branch in ["executive", "cabinet", "senate", "judicial", "state_governor"]:
		return {
			"label": "Constituent",
			"line_kind": "constituent",
			"bond": 42,
			"importance": 0.34
		}

	if clean_source_branch == clean_target_branch and source_office != "" and target_office != "":
		return {
			"label": "Same Branch",
			"line_kind": "civic_peer",
			"bond": 46,
			"importance": 0.32
		}

	return {}


func _append_federal_republic_population_hover_edge(
	edges: Array,
	seen_targets: Dictionary,
	source_entity_id: String,
	target_entity_id: String,
	target,
	spec: Dictionary
) -> void:
	if target_entity_id == "" or target_entity_id == source_entity_id:
		return
	if seen_targets.has(target_entity_id):
		return
	if typeof(spec) != TYPE_DICTIONARY or spec.is_empty():
		return

	var bond: int = clampi(int(spec.get("bond", 44)), 0, 100)
	var line_kind: String = str(spec.get("line_kind", "civic")).strip_edges()
	var importance: float = float(spec.get("importance", 0.35))

	seen_targets [target_entity_id] = true
	edges.append({
		"source_entity_id": source_entity_id,
		"target_entity_id": target_entity_id,
		"target_person_id": int(_value(target, "id", -1)),
		"target_name": _display_name(target),
		"relationship_label": str(spec.get("label", "Civic Tie")),
		"line_kind": line_kind,
		"bond": bond,
		"weight": 1.4 + float(bond) / 34.0,
		"importance_weight": importance,
		"tags": [
			line_kind,
			"federal_republic",
			"prebuilt_hover_tie",
			"dormant_population_safe"
		],
		"ui_is_renderer_only": true
	})


func _append_federal_republic_population_hover_edges(
	edges: Array,
	seen_targets: Dictionary,
	source_entity_id: String,
	source,
	visible_entity_ids: Dictionary,
	realm_id: int,
	realm_name: String,
	category: String
) -> void:
	if not _is_united_states_federal_realm(realm_id, realm_name):
		return

	var source_branch: String = _population_card_hover_branch_for_person(source, category)
	var source_state: String = _population_card_hover_state_for_person(source)

	if source_branch == "":
		return

	var additions: int = 0

	for raw_entity_id in visible_entity_ids.keys():
		if additions >= 8:
			break

		var target_entity_id: String = str(raw_entity_id).strip_edges()
		if target_entity_id == "" or target_entity_id == source_entity_id:
			continue
		if seen_targets.has(target_entity_id):
			continue

		var target = _population_card_hover_target_from_entity_id(target_entity_id)
		if target == null:
			continue
		if not bool(_value(target, "alive", true)):
			continue

		var target_branch: String = _population_card_hover_branch_for_person(target, "")
		var target_state: String = _population_card_hover_state_for_person(target)

		var spec: Dictionary = _federal_republic_hover_edge_spec(
			source,
			target,
			source_branch,
			target_branch,
			source_state,
			target_state
		)

		if spec.is_empty():
			continue

		_append_federal_republic_population_hover_edge(
			edges,
			seen_targets,
			source_entity_id,
			target_entity_id,
			target,
			spec
		)

		additions += 1
func _fallback_population_hover_contract_for_person(
	person,
	visible_entity_ids: Dictionary,
	realm_id: int,
	realm_name: String,
	category: String,
	_options: Dictionary = {}
) -> Dictionary:
	var source_entity_id: String = _entity_id_for_person(person)
	if source_entity_id == "":
		return {}

	var edges: Array = []
	var seen_targets: Dictionary = {}

	_add_fallback_population_edge(edges, seen_targets, source_entity_id, _value(person, "partner", null), "Partner", "romance", 88)
	_add_fallback_population_refs(edges, seen_targets, source_entity_id, _value(person, "parents", []), "Parent", "family", 86)
	_add_fallback_population_refs(edges, seen_targets, source_entity_id, _value(person, "children", []), "Child", "family", 84)
	_add_fallback_population_refs(edges, seen_targets, source_entity_id, _value(person, "friends", []), "Friend", "social", 62)

	_append_federal_republic_population_hover_edges(
		edges,
		seen_targets,
		source_entity_id,
		person,
		visible_entity_ids,
		realm_id,
		realm_name,
		category
	)

	if edges.size() < 3:
		for raw_entity_id in visible_entity_ids.keys():
			var target_entity_id: String = str(raw_entity_id).strip_edges()
			if target_entity_id == "" or target_entity_id == source_entity_id:
				continue
			if seen_targets.has(target_entity_id):
				continue

			seen_targets [target_entity_id] = true
			edges.append({
				"source_entity_id": source_entity_id,
				"target_entity_id": target_entity_id,
				"relationship_label": "Realm Tie",
				"line_kind": "civic",
				"bond": 36,
				"weight": 1.8,
				"importance_weight": 0.22,
				"tags": ["realm_civic", "fallback_hover_tie"],
				"ui_is_renderer_only": true
			})

			if edges.size() >= 3:
				break

	return {
		"success": true,
		"schema": "eralife.population_graph_hover_contract.fallback",
		"source_entity_id": source_entity_id,
		"source_person_id": int(_value(person, "id", -1)),
		"source_name": _display_name(person),
		"realm_id": realm_id,
		"realm_name": realm_name,
		"category": category,
		"section_kind": _section_kind_for_category(category),
		"edges": edges,
		"edge_count": edges.size(),
		"edges_prebuilt_before_hover": true,
		"hover_zero_engine_calls": true,
		"dormant_population_entity_safe": not (person is Person),
		"ui_is_renderer_only": true
	}

func _add_fallback_population_refs(
	edges: Array,
	seen_targets: Dictionary,
	source_entity_id: String,
	refs_raw: Variant,
	label: String,
	line_kind: String,
	bond: int
) -> void:
	if typeof(refs_raw) != TYPE_ARRAY:
		return

	for raw_ref in refs_raw as Array:
		_add_fallback_population_edge(edges, seen_targets, source_entity_id, raw_ref, label, line_kind, bond)


func _add_fallback_population_edge(
	edges: Array,
	seen_targets: Dictionary,
	source_entity_id: String,
	raw_ref,
	label: String,
	line_kind: String,
	bond: int
) -> void:
	var target_id: int = _person_ref_id(raw_ref)
	if target_id <= 0:
		return

	var target_entity_id: String = "human:%d" % target_id
	if target_entity_id == source_entity_id:
		return
	if seen_targets.has(target_entity_id):
		return

	seen_targets [target_entity_id] = true

	edges.append({
		"source_entity_id": source_entity_id,
		"target_entity_id": target_entity_id,
		"target_person_id": target_id,
		"relationship_label": label,
		"line_kind": line_kind,
		"bond": bond,
		"weight": 1.5 + float(bond) / 30.0,
		"importance_weight": 0.92 if line_kind == "romance" else 0.88 if line_kind == "family" else 0.46,
		"tags": [line_kind, "prebuilt_hover_tie"],
		"ui_is_renderer_only": true
	})


func _categorize_population(people: Array, realm_id: int, realm_name: String, _options: Dictionary = {}) -> Dictionary:
	var royals: Array = []
	var nobles: Array = []
	var masters: Array = []
	var citizens: Array = []
	var seen_ids: Dictionary = {}

	for raw_person in people:
		if raw_person == null:
			continue
		if not bool(_value(raw_person, "alive", true)):
			continue

		var person_id: int = int(_value(raw_person, "id", -1))
		if person_id <= 0:
			continue
		if seen_ids.has(person_id):
			continue

		seen_ids [person_id] = true

		var category: String = _population_card_category_for_person(raw_person, realm_id, realm_name)

		match category:
			"royal":
				royals.append(raw_person)
			"noble":
				nobles.append(raw_person)
			"master":
				masters.append(raw_person)
			_:
				citizens.append(raw_person)

	royals.sort_custom(func (a, b):
		return _person_sort_score(a, realm_id) > _person_sort_score(b, realm_id)
	)
	nobles.sort_custom(func (a, b):
		return _population_card_noble_sort_score(a, realm_id) > _population_card_noble_sort_score(b, realm_id)
	)
	masters.sort_custom(func (a, b):
		return _person_sort_score(a, realm_id) > _person_sort_score(b, realm_id)
	)
	citizens.sort_custom(func (a, b):
		return _population_card_citizen_wall_sort_score(a, realm_id, realm_name) > _population_card_citizen_wall_sort_score(b, realm_id, realm_name)
	)

	return {
		"royals": royals,
		"nobles": nobles,
		"masters": masters,
		"citizens": citizens
	}
func _federal_republic_people_from_id_arrays(
	realm_id: int,
	realm_keys: Array,
	scenario_keys: Array = []
) -> Array:
	var out: Array = []
	var seen: Dictionary = {}

	var realm_engine = _value(gs, "realm_engine", null)
	if realm_engine != null and "realms" in realm_engine and typeof(realm_engine.realms) == TYPE_DICTIONARY:
		var realm_raw: Variant = realm_engine.realms.get(realm_id, {})
		if typeof(realm_raw) == TYPE_DICTIONARY:
			var realm: Dictionary = realm_raw
			for raw_key in realm_keys:
				var key: String = str(raw_key)
				var raw_ids: Variant = realm.get(key, [])
				if typeof(raw_ids) != TYPE_ARRAY:
					continue

				for raw_id in raw_ids as Array:
					var person_id: int = int(raw_id)
					if person_id <= 0:
						continue
					if seen.has(person_id):
						continue

					var person = _person_by_id(person_id)
					if person == null:
						continue

					out.append(person)
					seen [person_id] = true

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		for raw_key in scenario_keys:
			var scenario_key: String = str(raw_key)
			var scenario_ids: Variant = gs.scenario_state.get(scenario_key, [])
			if typeof(scenario_ids) != TYPE_ARRAY:
				continue

			for raw_id in scenario_ids as Array:
				var person_id: int = int(raw_id)
				if person_id <= 0:
					continue
				if seen.has(person_id):
					continue

				var person = _person_by_id(person_id)
				if person == null:
					continue

				out.append(person)
				seen [person_id] = true

	return out


func _federal_republic_merge_unseen_people(primary: Array, fallback: Array, used_ids: Dictionary, limit: int) -> Array:
	var out: Array = []
	var local_seen: Dictionary = {}
	var safe_limit: int = maxi(0, limit)

	for raw_person in primary:
		if safe_limit > 0 and out.size() >= safe_limit:
			break
		if raw_person == null:
			continue

		var person_id: int = int(_value(raw_person, "id", -1))
		if person_id <= 0:
			continue
		if used_ids.has(person_id) or local_seen.has(person_id):
			continue

		out.append(raw_person)
		local_seen [person_id] = true
		used_ids [person_id] = true

	for raw_person in fallback:
		if safe_limit > 0 and out.size() >= safe_limit:
			break
		if raw_person == null:
			continue

		var person_id: int = int(_value(raw_person, "id", -1))
		if person_id <= 0:
			continue
		if used_ids.has(person_id) or local_seen.has(person_id):
			continue

		out.append(raw_person)
		local_seen [person_id] = true
		used_ids [person_id] = true

	return out
func _federal_republic_expected_contract_branch(branch: String) -> String:
	var clean_branch: String = str(branch).strip_edges().to_lower()

	match clean_branch:
		"supreme_court":
			return "judicial"
		"governor":
			return "state_governor"
		"president":
			return "executive"
		_:
			return clean_branch


func _federal_republic_person_matches_branch_contract(person, branch: String) -> bool:
	if person == null:
		return false

	var contract_raw: Variant = _value(person, "civic_office_contract", {})
	if typeof(contract_raw) != TYPE_DICTIONARY:
		return false

	var contract: Dictionary = contract_raw
	var government_model: String = str(contract.get("government_model", "")).strip_edges().to_lower()
	if government_model != "federal_presidential_republic":
		return false

	var expected_branch: String = _federal_republic_expected_contract_branch(branch)
	var actual_branch: String = str(contract.get("branch", "")).strip_edges().to_lower()

	return actual_branch == expected_branch


func _federal_republic_people_have_branch_contract(people: Array, branch: String) -> bool:
	for raw_person in people:
		if _federal_republic_person_matches_branch_contract(raw_person, branch):
			return true

	return false
func _federal_republic_pool_candidates_for_branch(
	people: Array,
	used_ids: Dictionary,
	realm_id: int,
	branch: String,
	min_age: int
) -> Array:
	var candidates: Array = []
	var require_branch_contract: bool = _federal_republic_people_have_branch_contract(people, branch)

	for raw_person in people:
		if raw_person == null:
			continue
		if not bool(_value(raw_person, "alive", true)):
			continue

		var person_id: int = int(_value(raw_person, "id", -1))
		if person_id <= 0:
			continue
		if used_ids.has(person_id):
			continue
		if _federal_republic_disallows_official_candidate(raw_person, branch, min_age):
			continue

		var contract_raw: Variant = _value(raw_person, "civic_office_contract", {})
		var has_federal_contract: bool = false
		if typeof(contract_raw) == TYPE_DICTIONARY:
			var contract: Dictionary = contract_raw
			has_federal_contract = str(contract.get("government_model", "")).strip_edges().to_lower() == "federal_presidential_republic"

		if require_branch_contract and not _federal_republic_person_matches_branch_contract(raw_person, branch):
			continue

		if has_federal_contract and not _federal_republic_person_matches_branch_contract(raw_person, branch):
			continue

		candidates.append(raw_person)

	candidates.sort_custom(func (a, b):
		return _federal_republic_official_candidate_score(a, realm_id, branch) > _federal_republic_official_candidate_score(b, realm_id, branch)
	)

	return candidates

func _federal_republic_fill_people_from_population_pool(
	current: Array,
	people: Array,
	used_ids: Dictionary,
	realm_id: int,
	branch: String,
	target_count: int,
	min_age: int
) -> Array:
	var out: Array = []
	var local_seen: Dictionary = {}
	var safe_target: int = maxi(0, target_count)

	for raw_current in current:
		if raw_current == null:
			continue

		var current_id: int = int(_value(raw_current, "id", -1))
		if current_id <= 0:
			continue
		if local_seen.has(current_id):
			continue
		if used_ids.has(current_id):
			continue
		if _federal_republic_disallows_official_candidate(raw_current, branch, min_age):
			continue

		out.append(raw_current)
		local_seen [current_id] = true
		used_ids [current_id] = true

	var candidates: Array = _federal_republic_pool_candidates_for_branch(
		people,
		used_ids,
		realm_id,
		branch,
		min_age
	)

	for raw_candidate in candidates:
		if out.size() >= safe_target:
			break

		var candidate_id: int = int(_value(raw_candidate, "id", -1))
		if candidate_id <= 0:
			continue
		if local_seen.has(candidate_id):
			continue
		if used_ids.has(candidate_id):
			continue
		if _federal_republic_disallows_official_candidate(raw_candidate, branch, min_age):
			continue

		out.append(raw_candidate)
		local_seen [candidate_id] = true
		used_ids [candidate_id] = true

	return out
func _federal_republic_fill_citizens_from_population_pool(
	current: Array,
	people: Array,
	used_ids: Dictionary,
	realm_id: int,
	realm_name: String,
	target_count: int
) -> Array:
	var source: Array = []
	var seen: Dictionary = {}
	var safe_target: int = maxi(DEFAULT_CITIZEN_LIMIT, target_count)

	for raw_current in current:
		if raw_current == null:
			continue

		var current_id: int = int(_value(raw_current, "id", -1))
		if current_id <= 0:
			continue
		if seen.has(current_id):
			continue

		source.append(raw_current)
		seen [current_id] = true

	for raw_person in people:
		if raw_person == null:
			continue
		if not bool(_value(raw_person, "alive", true)):
			continue

		var person_id: int = int(_value(raw_person, "id", -1))
		if person_id <= 0:
			continue
		if seen.has(person_id):
			continue

		if used_ids.has(person_id) and source.size() >= safe_target:
			continue

		source.append(raw_person)
		seen [person_id] = true

	var selected: Array = _select_citizen_wall_population(
		source,
		safe_target,
		realm_id,
		realm_name
	)

	return selected
func _federal_republic_projection_target_from_options(options: Dictionary, key: String, minimum_value: int) -> int:
	var raw_target: int = int(options.get(key, minimum_value))

	if raw_target <= 0:
		raw_target = minimum_value

	return maxi(minimum_value, raw_target)
func _federal_republic_government_stream_managed(realm_id: int) -> bool:
	if gs == null or realm_id <= 0:
		return false

	if typeof(_value(gs, "scenario_state", {})) == TYPE_DICTIONARY:
		var scenario: Dictionary = _value(gs, "scenario_state", {})
		if int(scenario.get("presidential_parent_contract_us_realm_id", -1)) == realm_id:
			return bool(scenario.get("presidential_parent_contract_government_contract_ready", false)) \
or scenario.has("presidential_parent_contract_federal_population_stream_total") \
or scenario.has("presidential_parent_contract_federal_population_stream_jobs_built")

	if _value(gs, "realm_engine", null) != null and "realms" in gs.realm_engine and typeof(gs.realm_engine.realms) == TYPE_DICTIONARY:
		var realm_raw: Variant = gs.realm_engine.realms.get(realm_id, {})
		if typeof(realm_raw) == TYPE_DICTIONARY:
			var realm: Dictionary = realm_raw
			return bool(realm.get("government_contract_ready", false)) \
or bool(realm.get("federal_republic_population_contract", false)) \
or str(realm.get("government_model", "")).strip_edges().to_lower() == "federal_presidential_republic"

	return false


func _federal_republic_government_stream_complete(realm_id: int) -> bool:
	if gs == null or realm_id <= 0:
		return true

	if typeof(_value(gs, "scenario_state", {})) == TYPE_DICTIONARY:
		var scenario: Dictionary = _value(gs, "scenario_state", {})
		if int(scenario.get("presidential_parent_contract_us_realm_id", -1)) == realm_id:
			return bool(scenario.get("presidential_parent_contract_federal_population_complete", false)) \
or bool(scenario.get("presidential_parent_contract_federal_population_stream_complete", false))

	if _value(gs, "realm_engine", null) != null and "realms" in gs.realm_engine and typeof(gs.realm_engine.realms) == TYPE_DICTIONARY:
		var realm_raw: Variant = gs.realm_engine.realms.get(realm_id, {})
		if typeof(realm_raw) == TYPE_DICTIONARY:
			var realm: Dictionary = realm_raw
			return bool(realm.get("federal_republic_population_complete", false)) \
or bool(realm.get("federal_republic_population_stream_complete", false))

	return true
func _federal_republic_population_contract_for_realm(
	people: Array,
	_buckets: Dictionary,
	realm_id: int,
	realm_name: String,
	options: Dictionary = {}
) -> Dictionary:
	if not _is_united_states_federal_realm(realm_id, realm_name):
		return {
			"enabled": false
		}

	var truth_packet_contract: Dictionary = _federal_republic_population_contract_from_truth_resolution_packet(
		realm_id,
		realm_name,
		options
	)

	if not truth_packet_contract.is_empty():
		return truth_packet_contract

	if bool(options.get("click_path_build_forbidden", false)) \
or bool(options.get("view_contract_only", false)) \
or bool(options.get("observable_surface_existence_pass", false)) \
or bool(options.get("population_cards_may_project_partial_truth", false)) \
or bool(options.get("truth_may_be_partial", false)):
		return _federal_republic_partial_surface_contract(
			realm_id,
			realm_name,
			options
		)

	var used_ids: Dictionary = {}
	var role_label_by_person_id: Dictionary = {}
	var civic_metadata_by_person_id: Dictionary = {}

	var executive: Array = []
	var cabinet: Array = []
	var senate: Array = []
	var supreme_court: Array = []
	var governors: Array = []

	var cabinet_titles: Array = _federal_republic_cabinet_titles()

	var cabinet_target: int = _federal_republic_projection_target_from_options(
		options,
		"us_cabinet_target",
		DEFAULT_US_CABINET_TARGET
	)
	cabinet_target = mini(cabinet_target, cabinet_titles.size())

	var senate_target: int = _federal_republic_projection_target_from_options(
		options,
		"us_senate_target",
		DEFAULT_US_SENATE_TARGET
	)

	var supreme_court_target: int = _federal_republic_projection_target_from_options(
		options,
		"us_supreme_court_target",
		DEFAULT_US_SUPREME_COURT_TARGET
	)

	var governor_target: int = _federal_republic_projection_target_from_options(
		options,
		"us_governor_target",
		DEFAULT_US_GOVERNOR_TARGET
	)

	var citizen_target: int = _federal_republic_projection_target_from_options(
		options,
		"citizen_limit",
		DEFAULT_CITIZEN_LIMIT
	)

	var government_node_report: Dictionary = _federal_republic_truth_resolution_report_for_realm(
		realm_id,
		realm_name,
		{
			"cabinet": cabinet_target,
			"senate": senate_target,
			"supreme_court": supreme_court_target,
			"governors": governor_target,
			"citizens": citizen_target
		},
		options
	)

	var managed_federal_stream: bool = _federal_republic_government_stream_managed(realm_id)
	var _federal_stream_complete: bool = _federal_republic_government_stream_complete(realm_id)
	var observable_surface_existence_pass: bool = bool(options.get("observable_surface_existence_pass", false))
	var allow_generic_pool_projection: bool = not managed_federal_stream or not _federal_stream_complete or observable_surface_existence_pass

	var president = _federal_republic_select_president(people, realm_id)
	if president != null:
		executive.append(president)
		_federal_republic_mark_role(
			president,
			"President",
			"executive",
			"",
			10000,
			role_label_by_person_id,
			civic_metadata_by_person_id,
			used_ids
		)

	var vice_president = _federal_republic_select_vice_president(people, used_ids, realm_id)
	if vice_president != null:
		executive.append(vice_president)
		_federal_republic_mark_role(
			vice_president,
			"Vice President",
			"executive",
			"",
			9950,
			role_label_by_person_id,
			civic_metadata_by_person_id,
			used_ids
		)

	var first_lady = _federal_republic_select_first_lady(people, president, realm_id)
	if first_lady != null:
		var first_lady_id: int = int(_value(first_lady, "id", -1))
		if first_lady_id > 0 and not used_ids.has(first_lady_id):
			executive.append(first_lady)
			_federal_republic_mark_role(
				first_lady,
				_federal_republic_first_partner_role_label(first_lady),
				"executive",
				"",
				9900,
				role_label_by_person_id,
				civic_metadata_by_person_id,
				used_ids
			)

	var explicit_cabinet: Array = _federal_republic_filter_people_for_federal_branch(
		_federal_republic_people_from_id_arrays(
			realm_id,
			["federal_cabinet_person_ids"],
			["presidential_parent_contract_federal_cabinet_ids"]
		),
		"cabinet",
		30
	)

	if allow_generic_pool_projection:
		cabinet = _federal_republic_fill_people_from_population_pool(
			explicit_cabinet,
			people,
			used_ids,
			realm_id,
			"cabinet",
			cabinet_target,
			30
		)
	else:
		cabinet = explicit_cabinet.duplicate(true)

	for i in range(cabinet.size()):
		var title: String = str(cabinet_titles [i % cabinet_titles.size()])
		_federal_republic_mark_role(
			cabinet [i],
			title,
			"cabinet",
			"",
			8800 - i,
			role_label_by_person_id,
			civic_metadata_by_person_id,
			used_ids
		)

	var explicit_senate: Array = _federal_republic_filter_people_for_federal_branch(
		_federal_republic_people_from_id_arrays(
			realm_id,
			["federal_senate_person_ids"],
			["presidential_parent_contract_federal_senate_ids"]
		),
		"senate",
		30
	)

	if allow_generic_pool_projection:
		senate = _federal_republic_fill_people_from_population_pool(
			explicit_senate,
			people,
			used_ids,
			realm_id,
			"senate",
			senate_target,
			30
		)
	else:
		senate = explicit_senate.duplicate(true)

	for i in range(senate.size()):
		var state_index: int = int(floor(float(i) / 2.0)) % UNITED_STATES_STATE_NAMES.size()
		var state_name: String = str(UNITED_STATES_STATE_NAMES [state_index])
		var senate_party: String = _federal_republic_senate_party_for_index(i)
		_federal_republic_mark_role(
			senate [i],
			"%s Senator of %s" % [senate_party, state_name],
			"senate",
			state_name,
			7600 - i,
			role_label_by_person_id,
			civic_metadata_by_person_id,
			used_ids,
			senate_party
		)

	var explicit_supreme_court: Array = _federal_republic_filter_people_for_federal_branch(
		_federal_republic_people_from_id_arrays(
			realm_id,
			["federal_supreme_court_person_ids"],
			["presidential_parent_contract_federal_supreme_court_ids"]
		),
		"supreme_court",
		40
	)

	if allow_generic_pool_projection:
		supreme_court = _federal_republic_fill_people_from_population_pool(
			explicit_supreme_court,
			people,
			used_ids,
			realm_id,
			"supreme_court",
			supreme_court_target,
			40
		)
	else:
		supreme_court = explicit_supreme_court.duplicate(true)

	for i in range(supreme_court.size()):
		var justice_title: String = "Chief Justice" if i == 0 else "Supreme Court Justice"
		_federal_republic_mark_role(
			supreme_court [i],
			justice_title,
			"judicial",
			"",
			7600 - i,
			role_label_by_person_id,
			civic_metadata_by_person_id,
			used_ids
		)

	var explicit_governors: Array = _federal_republic_filter_people_for_federal_branch(
		_federal_republic_people_from_id_arrays(
			realm_id,
			["federal_governor_person_ids"],
			["presidential_parent_contract_federal_governor_ids"]
		),
		"governor",
		30
	)

	if allow_generic_pool_projection:
		governors = _federal_republic_fill_people_from_population_pool(
			explicit_governors,
			people,
			used_ids,
			realm_id,
			"governor",
			governor_target,
			30
		)
	else:
		governors = explicit_governors.duplicate(true)

	for i in range(governors.size()):
		var governor_state: String = str(UNITED_STATES_STATE_NAMES [i % UNITED_STATES_STATE_NAMES.size()])
		var governor_party: String = _federal_republic_governor_party_for_index(i)
		_federal_republic_mark_role(
			governors [i],
			"%s Governor of %s" % [governor_party, governor_state],
			"state_governor",
			governor_state,
			6400 - i,
			role_label_by_person_id,
			civic_metadata_by_person_id,
			used_ids,
			governor_party
		)

	var explicit_citizens: Array = _federal_republic_people_from_id_arrays(
		realm_id,
		["federal_citizen_person_ids"],
		["presidential_parent_contract_federal_citizen_ids"]
	)

	var citizens: Array = []
	if allow_generic_pool_projection:
		citizens = _federal_republic_fill_citizens_from_population_pool(
			explicit_citizens,
			people,
			used_ids,
			realm_id,
			realm_name,
			citizen_target
		)
	else:
		citizens = explicit_citizens.duplicate(true)

	return {
		"enabled": true,
		"schema": "eralife.population_card_contract_engine.federal_republic_packet",
		"version": 4,
		"realm_id": realm_id,
		"realm_name": realm_name,
		"country": "United States",
		"government_model": "federal_presidential_republic",
		"state_names": UNITED_STATES_STATE_NAMES.duplicate(true),
		"state_count": UNITED_STATES_STATE_NAMES.size(),
		"senate_target": senate_target,
		"senate_model": "two_senators_per_state",
		"supreme_court_target": supreme_court_target,
		"governor_target": governor_target,
		"cabinet_target": cabinet_target,
		"citizen_target": citizen_target,
		"executive": executive,
		"cabinet": cabinet,
		"senate": senate,
		"supreme_court": supreme_court,
		"governors": governors,
		"citizens": citizens,
		"government_node_report": government_node_report.duplicate(true),
		"role_label_by_person_id": role_label_by_person_id,
		"civic_metadata_by_person_id": civic_metadata_by_person_id,
		"ui_is_renderer_only": true,
		"population_cards_are_contract_artifacts": true
	}
func _federal_republic_partial_surface_contract(
	realm_id: int,
	realm_name: String,
	options: Dictionary = {}
) -> Dictionary:
	var cabinet_target: int = _federal_republic_projection_target_from_options(
		options,
		"us_cabinet_target",
		DEFAULT_US_CABINET_TARGET
	)

	var senate_target: int = _federal_republic_projection_target_from_options(
		options,
		"us_senate_target",
		DEFAULT_US_SENATE_TARGET
	)

	var supreme_court_target: int = _federal_republic_projection_target_from_options(
		options,
		"us_supreme_court_target",
		DEFAULT_US_SUPREME_COURT_TARGET
	)

	var governor_target: int = _federal_republic_projection_target_from_options(
		options,
		"us_governor_target",
		DEFAULT_US_GOVERNOR_TARGET
	)

	var citizen_target: int = _federal_republic_projection_target_from_options(
		options,
		"citizen_limit",
		DEFAULT_CITIZEN_LIMIT
	)

	return {
		"enabled": true,
		"schema": "eralife.population_card_contract_engine.federal_republic_packet",
		"version": 6,
		"realm_id": realm_id,
		"realm_name": realm_name,
		"country": "United States",
		"government_model": "federal_presidential_republic",
		"state_names": UNITED_STATES_STATE_NAMES.duplicate(true),
		"state_count": UNITED_STATES_STATE_NAMES.size(),
		"senate_target": senate_target,
		"senate_model": "two_senators_per_state",
		"supreme_court_target": supreme_court_target,
		"governor_target": governor_target,
		"cabinet_target": cabinet_target,
		"citizen_target": citizen_target,
		"executive": [],
		"cabinet": [],
		"senate": [],
		"supreme_court": [],
		"governors": [],
		"citizens": [],
		"truth_state": "partial",
		"role_label_by_person_id": {},
		"civic_metadata_by_person_id": {},
		"ui_is_renderer_only": true,
		"population_cards_are_contract_artifacts": true
	}
func _federal_republic_population_contract_from_truth_resolution_packet(
	realm_id: int,
	realm_name: String,
	_options: Dictionary = {}
) -> Dictionary:
	if gs == null:
		return {}

	if not "truth_resolution_contract_engine" in gs:
		return {}

	if gs.truth_resolution_contract_engine == null:
		return {}

	if not gs.truth_resolution_contract_engine.has_method("government_truth_report_for_realm"):
		return {}

	var report: Dictionary = gs.truth_resolution_contract_engine.government_truth_report_for_realm(
		realm_id,
		realm_name
	)

	if not bool(report.get("success", false)):
		return {}

	var packet_raw: Variant = report.get("truth_packet", {})
	if typeof(packet_raw) != TYPE_DICTIONARY:
		return {}

	var packet: Dictionary = packet_raw
	if not bool(packet.get("truth_complete", false)):
		return {}

	var groups_raw: Variant = packet.get("groups", {})
	if typeof(groups_raw) != TYPE_DICTIONARY:
		return {}

	var groups: Dictionary = groups_raw

	var executive: Array = _federal_republic_truth_group_array(groups, "executive")
	var cabinet: Array = _federal_republic_truth_group_array(groups, "cabinet")
	var senate: Array = _federal_republic_truth_group_array(groups, "senate")
	var supreme_court: Array = _federal_republic_truth_group_array(groups, "supreme_court")
	var governors: Array = _federal_republic_truth_group_array(groups, "governors")
	var citizens: Array = _federal_republic_truth_group_array(groups, "citizens")

	var senate_target: int = maxi(DEFAULT_US_SENATE_TARGET, senate.size())
	var supreme_court_target: int = maxi(DEFAULT_US_SUPREME_COURT_TARGET, supreme_court.size())
	var governor_target: int = maxi(DEFAULT_US_GOVERNOR_TARGET, governors.size())

	var used_ids: Dictionary = {}
	var role_label_by_person_id: Dictionary = {}
	var civic_metadata_by_person_id: Dictionary = {}

	var president_id: int = -1
	var first_partner_id: int = -1

	if typeof(gs.scenario_state) == TYPE_DICTIONARY:
		president_id = int(gs.scenario_state.get("presidential_parent_contract_president_id", -1))
		first_partner_id = int(gs.scenario_state.get("presidential_parent_contract_first_partner_id", -1))

	var president = _person_by_id(president_id)
	if president != null:
		executive = _federal_republic_prepend_unique_person(executive, president)

	var first_partner = _person_by_id(first_partner_id)
	if first_partner != null:
		executive = _federal_republic_append_unique_person(executive, first_partner)

	for i in range(executive.size()):
		var raw_person = executive [i]
		var person_id: int = int(_value(raw_person, "id", -1))
		if person_id <= 0:
			continue

		var role_label: String = str(_value(raw_person, "job", _value(raw_person, "civic_title", "Executive Official"))).strip_edges()
		if person_id == president_id:
			role_label = "President"
		elif person_id == first_partner_id:
			role_label = _federal_republic_first_partner_role_label(raw_person)
		elif role_label == "":
			role_label = "Vice President"

		_federal_republic_mark_role(
			raw_person,
			role_label,
			"executive",
			"",
			10000 - i,
			role_label_by_person_id,
			civic_metadata_by_person_id,
			used_ids
		)

	for i in range(cabinet.size()):
		var cabinet_role: String = str(_value(cabinet [i], "job", _value(cabinet [i], "civic_title", ""))).strip_edges()
		if cabinet_role == "":
			cabinet_role = str(_federal_republic_cabinet_titles() [i % _federal_republic_cabinet_titles().size()])

		_federal_republic_mark_role(
			cabinet [i],
			cabinet_role,
			"cabinet",
			"",
			8800 - i,
			role_label_by_person_id,
			civic_metadata_by_person_id,
			used_ids
		)

	for i in range(senate.size()):
		var senator_role: String = str(_value(senate [i], "job", _value(senate [i], "civic_title", ""))).strip_edges()
		var senator_contract: Dictionary = _federal_republic_civic_contract_for_person(senate [i])
		var state_name: String = str(senator_contract.get("state_name", "")).strip_edges()
		var party_label: String = str(senator_contract.get("party", "")).strip_edges()

		if senator_role == "":
			if state_name == "":
				state_name = str(UNITED_STATES_STATE_NAMES [int(floor(float(i) / 2.0)) % UNITED_STATES_STATE_NAMES.size()])
			if party_label == "":
				party_label = _federal_republic_senate_party_for_index(i)
			senator_role = "%s Senator of %s" % [party_label, state_name]

		_federal_republic_mark_role(
			senate [i],
			senator_role,
			"senate",
			state_name,
			7600 - i,
			role_label_by_person_id,
			civic_metadata_by_person_id,
			used_ids,
			party_label
		)

	for i in range(supreme_court.size()):
		var justice_role: String = str(_value(supreme_court [i], "job", _value(supreme_court [i], "civic_title", ""))).strip_edges()
		if justice_role == "":
			justice_role = "Chief Justice" if i == 0 else "Supreme Court Justice"

		_federal_republic_mark_role(
			supreme_court [i],
			justice_role,
			"judicial",
			"",
			7600 - i,
			role_label_by_person_id,
			civic_metadata_by_person_id,
			used_ids
		)

	for i in range(governors.size()):
		var governor_contract: Dictionary = _federal_republic_civic_contract_for_person(governors [i])
		var governor_state: String = str(governor_contract.get("state_name", "")).strip_edges()
		var governor_party: String = str(governor_contract.get("party", "")).strip_edges()
		var governor_role: String = str(_value(governors [i], "job", _value(governors [i], "civic_title", ""))).strip_edges()

		if governor_state == "":
			governor_state = str(UNITED_STATES_STATE_NAMES [i % UNITED_STATES_STATE_NAMES.size()])
		if governor_party == "":
			governor_party = _federal_republic_governor_party_for_index(i)
		if governor_role == "":
			governor_role = "%s Governor of %s" % [governor_party, governor_state]

		_federal_republic_mark_role(
			governors [i],
			governor_role,
			"state_governor",
			governor_state,
			6400 - i,
			role_label_by_person_id,
			civic_metadata_by_person_id,
			used_ids,
			governor_party
		)

	return {
		"enabled": true,
		"schema": "eralife.population_card_contract_engine.federal_republic_packet",
		"version": 5,
		"realm_id": realm_id,
		"realm_name": realm_name,
		"country": "United States",
		"government_model": "federal_presidential_republic",
		"state_names": UNITED_STATES_STATE_NAMES.duplicate(true),
		"state_count": UNITED_STATES_STATE_NAMES.size(),
		"senate_target": senate_target,
		"senate_model": "two_senators_per_state",
		"supreme_court_target": supreme_court_target,
		"governor_target": governor_target,
		"cabinet_target": cabinet.size(),
		"citizen_target": citizens.size(),
		"executive": executive,
		"cabinet": cabinet,
		"senate": senate,
		"supreme_court": supreme_court,
		"governors": governors,
		"citizens": citizens,
		"population_card_contract_engine_projects_truth_only": true,
		"role_label_by_person_id": role_label_by_person_id,
		"civic_metadata_by_person_id": civic_metadata_by_person_id,
		"ui_is_renderer_only": true,
		"population_cards_are_contract_artifacts": true
	}
func _federal_republic_truth_group_array(groups: Dictionary, key: String) -> Array:
	var raw_group: Variant = groups.get(key, [])
	if typeof(raw_group) != TYPE_ARRAY:
		return []

	var out: Array = []
	var seen: Dictionary = {}

	for raw_person in raw_group as Array:
		if raw_person == null:
			continue

		var person_id: int = int(_value(raw_person, "id", -1))
		if person_id <= 0:
			continue
		if seen.has(person_id):
			continue

		out.append(raw_person)
		seen [person_id] = true

	return out


func _federal_republic_prepend_unique_person(list: Array, person) -> Array:
	var out: Array = []
	var seen: Dictionary = {}

	var person_id: int = int(_value(person, "id", -1))
	if person_id > 0:
		out.append(person)
		seen [person_id] = true

	for raw_person in list:
		var raw_id: int = int(_value(raw_person, "id", -1))
		if raw_id <= 0:
			continue
		if seen.has(raw_id):
			continue

		out.append(raw_person)
		seen [raw_id] = true

	return out


func _federal_republic_append_unique_person(list: Array, person) -> Array:
	var out: Array = []
	var seen: Dictionary = {}

	for raw_person in list:
		var raw_id: int = int(_value(raw_person, "id", -1))
		if raw_id <= 0:
			continue
		if seen.has(raw_id):
			continue

		out.append(raw_person)
		seen [raw_id] = true

	var person_id: int = int(_value(person, "id", -1))
	if person_id > 0 and not seen.has(person_id):
		out.append(person)

	return out


func _federal_republic_civic_contract_for_person(person) -> Dictionary:
	var raw_contract: Variant = _value(person, "civic_office_contract", {})
	if typeof(raw_contract) == TYPE_DICTIONARY:
		return (raw_contract as Dictionary).duplicate(true)

	return {}
func _federal_republic_truth_resolution_report_for_realm(
	realm_id: int,
	realm_name: String,
	targets: Dictionary,
	_options: Dictionary = {}
) -> Dictionary:
	if gs == null:
		return {
			"success": false,
			"reason": "missing_game_state",
			"schema": ENGINE_SCHEMA
		}

	if not "truth_resolution_contract_engine" in gs or gs.truth_resolution_contract_engine == null:
		return {
			"success": false,
			"reason": "missing_truth_resolution_contract_engine",
			"schema": ENGINE_SCHEMA,
			"realm_id": realm_id,
			"realm_name": realm_name,
			"targets": targets.duplicate(true),
			"ui_is_renderer_only": true
		}

	if gs.truth_resolution_contract_engine.has_method("government_truth_report_for_realm"):
		var report: Dictionary = gs.truth_resolution_contract_engine.government_truth_report_for_realm(
			realm_id,
			realm_name
		)

		if bool(report.get("success", false)):
			report ["targets"] = targets.duplicate(true)
			report ["population_card_contract_engine_projects_truth_only"] = true
			report ["ui_is_renderer_only"] = true
			return report

	return {
		"success": false,
		"reason": "truth_resolution_not_hot_for_realm",
		"schema": ENGINE_SCHEMA,
		"realm_id": realm_id,
		"realm_name": realm_name,
		"targets": targets.duplicate(true),
		"ui_is_renderer_only": true
	}
func _is_united_states_federal_realm(realm_id: int, realm_name: String = "") -> bool:
	var name_key: String = str(realm_name).strip_edges().to_lower()

	if name_key == "":
		name_key = _realm_name_for_id(realm_id).strip_edges().to_lower()

	var compact_name: String = name_key.replace(".", "").replace(" ", "").replace("-", "")
	var united_states_match: bool = compact_name in [
		"usa",
		"us",
		"unitedstates",
		"unitedstatesofamerica",
		"america"
	] or name_key.find("united states") >= 0

	var realm_government_match: bool = false
	if gs != null and gs.realm_engine != null and "realms" in gs.realm_engine and typeof(gs.realm_engine.realms) == TYPE_DICTIONARY:
		var realm_raw: Variant = gs.realm_engine.realms.get(realm_id, {})
		if typeof(realm_raw) == TYPE_DICTIONARY:
			var realm: Dictionary = realm_raw
			var government_model: String = str(realm.get("government_model", "")).strip_edges().to_lower()
			var government_style: String = str(realm.get("government_style", realm.get("government", ""))).strip_edges().to_lower()

			realm_government_match = bool(realm.get("federal_republic_population_contract", false)) \
or government_model in [
					"federal_presidential_republic",
					"federal_republic",
					"presidential_republic",
					"constitutional_republic"
				] \
or government_style in [
					"federal republic",
					"presidential republic",
					"constitutional republic"
				]

			if not united_states_match:
				var realm_country: String = str(realm.get("country", realm.get("name", ""))).strip_edges().to_lower()
				var compact_country: String = realm_country.replace(".", "").replace(" ", "").replace("-", "")
				united_states_match = compact_country in [
					"usa",
					"us",
					"unitedstates",
					"unitedstatesofamerica",
					"america"
				] or realm_country.find("united states") >= 0

	if not united_states_match:
		return false

	if realm_government_match:
		return true

	var era_key: String = ""
	if gs != null:
		era_key = str(_value(gs, "current_era", _value(gs, "era", ""))).strip_edges().to_lower()

		if era_key == "" and typeof(gs.scenario_state) == TYPE_DICTIONARY:
			era_key = str(gs.scenario_state.get("era", gs.scenario_state.get("current_era", ""))).strip_edges().to_lower()

	if era_key == "":
		return true

	return era_key.find("industrial") >= 0 or era_key.find("modern") >= 0 or era_key.find("future") >= 0

func _federal_republic_select_president(people: Array, realm_id: int):
	var ruler_id: int = _realm_ruler_id(realm_id)
	if ruler_id > 0:
		for raw_person in people:
			if int(_value(raw_person, "id", -1)) == ruler_id:
				return raw_person

	var best = null
	var best_score: int = -999999

	for raw_person in people:
		if raw_person == null:
			continue
		if not bool(_value(raw_person, "alive", true)):
			continue

		var score: int = _federal_republic_official_candidate_score(raw_person, realm_id, "president")
		var title_blob: String = _population_card_person_title_blob(raw_person)
		var job_key: String = str(_value(raw_person, "job", "")).strip_edges()

		var civic_title: String = str(_value(raw_person, "civic_title", "")).strip_edges()

		if _population_card_text_has_any(title_blob, ["president"]) \
or _population_card_text_has_any(job_key, ["president"]) \
or _population_card_text_has_any(civic_title, ["president"]):
			score += 5000

		if score > best_score:
			best = raw_person
			best_score = score

	return best
func _federal_republic_first_partner_role_label(person) -> String:
	if person == null:
		return "First Lady"

	var job_text: String = str(_value(person, "job", "")).strip_edges()
	if job_text in ["First Lady", "First Gentleman"]:
		return job_text

	var gender_key: String = str(_value(person, "gender", "")).strip_edges().to_lower()
	return "First Gentleman" if gender_key == "male" else "First Lady"

func _federal_republic_select_first_lady(people: Array, president, _realm_id: int):
	if president == null:
		return null

	var president_id: int = int(_value(president, "id", -1))
	if president_id <= 0:
		return null

	var partner_ref = _value(president, "partner", null)
	var partner_id: int = _person_ref_id(partner_ref)

	if partner_id > 0:
		for raw_person in people:
			if int(_value(raw_person, "id", -1)) == partner_id:
				return raw_person

	for raw_person in people:
		if raw_person == null:
			continue

		var raw_partner_id: int = _person_ref_id(_value(raw_person, "partner", null))
		if raw_partner_id == president_id:
			return raw_person

	return null


func _federal_republic_take_ranked_people(
	people: Array,
	used_ids: Dictionary,
	amount: int,
	min_age: int,
	realm_id: int,
	branch: String
) -> Array:
	var candidates: Array = []

	for raw_person in people:
		if raw_person == null:
			continue
		if not bool(_value(raw_person, "alive", true)):
			continue

		var person_id: int = int(_value(raw_person, "id", -1))
		if person_id <= 0:
			continue
		if used_ids.has(person_id):
			continue

		var age: int = int(_value(raw_person, "age", 0))
		if age < min_age:
			continue

		var score: int = _federal_republic_official_candidate_score(raw_person, realm_id, branch)
		candidates.append({
			"person": raw_person,
			"score": score
		})

	candidates.sort_custom(func (a, b):
		return int((a as Dictionary).get("score", 0)) > int((b as Dictionary).get("score", 0))
	)

	var out: Array = []
	for raw_candidate in candidates:
		if out.size() >= amount:
			break

		if typeof(raw_candidate) != TYPE_DICTIONARY:
			continue

		var candidate: Dictionary = raw_candidate
		var person = candidate.get("person", null)
		if person == null:
			continue

		var candidate_id: int = int(_value(person, "id", -1))
		if candidate_id <= 0:
			continue
		if used_ids.has(candidate_id):
			continue

		out.append(person)
		used_ids [candidate_id] = true

	return out


func _federal_republic_official_candidate_score(person, _realm_id: int, branch: String) -> int:
	if person == null:
		return -999999

	var score: int = 0
	var clean_branch: String = str(branch).strip_edges().to_lower()
	var job_key: String = str(_value(person, "job", "")).strip_edges().to_lower()
	var title_blob: String = _population_card_person_title_blob(person)
	var social_key: String = str(_value(person, "social_class", "")).strip_edges().to_lower()

	var office_contract_raw: Variant = _value(person, "civic_office_contract", {})
	var office_contract: Dictionary = office_contract_raw if typeof(office_contract_raw) == TYPE_DICTIONARY else {}
	var office_branch: String = str(office_contract.get("branch", "")).strip_edges().to_lower()
	var office_model: String = str(office_contract.get("government_model", "")).strip_edges().to_lower()
	var office_text: String = str(office_contract.get("office", "")).strip_edges().to_lower()

	score += int(_value(person, "smarts", 50)) * 5
	score += int(_value(person, "respect", 0)) * 5
	score += int(_value(person, "fame", 0)) * 4
	score += int(_value(person, "approval", 0)) * 3
	score += int(_value(person, "age", 0))

	if office_model == "federal_presidential_republic":
		score += 10000

	if social_key in ["elite", "upper class", "upper-middle class", "upper middle class", "wealthy", "rich"]:
		score += 420

	if _population_card_text_has_any(job_key, ["politician", "lawyer", "judge", "justice", "professor", "executive", "administrator", "manager", "attorney", "secretary", "senator", "governor"]):
		score += 520

	if _population_card_text_has_any(title_blob, ["senator", "justice", "judge", "governor", "secretary", "cabinet", "representative", "vice president"]):
		score += 850

	match clean_branch:
		"senate":
			if office_branch == "senate":
				score += 90000
			if office_text == "senator":
				score += 24000
			if _population_card_text_has_any(title_blob, ["senator"]):
				score += 1500
			if _population_card_text_has_any(job_key, ["senator", "politician", "lawyer"]):
				score += 900

		"supreme_court":
			if office_branch == "judicial":
				score += 90000
			if office_text in ["chief justice", "supreme court justice"]:
				score += 24000
			if _population_card_text_has_any(title_blob, ["justice", "judge"]):
				score += 1800
			if _population_card_text_has_any(job_key, ["justice", "judge", "lawyer", "attorney"]):
				score += 1100

		"governor":
			if office_branch == "state_governor":
				score += 90000
			if office_text == "governor":
				score += 24000
			if _population_card_text_has_any(title_blob, ["governor"]):
				score += 1800
			if _population_card_text_has_any(job_key, ["governor", "politician", "administrator"]):
				score += 900

		"cabinet":
			if office_branch == "cabinet":
				score += 90000
			if _population_card_text_has_any(office_text, ["secretary", "attorney general", "vice president"]):
				score += 24000
			if _population_card_text_has_any(title_blob, ["secretary", "cabinet", "attorney general", "vice president"]):
				score += 1500
			if _population_card_text_has_any(job_key, ["secretary", "director", "administrator", "executive", "attorney general", "vice president"]):
				score += 850

		"president":
			if office_branch == "executive" and office_text == "president":
				score += 90000
			if _population_card_text_has_any(title_blob, ["president"]):
				score += 2500
			if _population_card_text_has_any(job_key, ["president", "politician"]):
				score += 1250

	return score

func _federal_republic_mark_role(
	person,
	role_label: String,
	branch: String,
	state_name: String,
	priority: int,
	role_label_by_person_id: Dictionary,
	civic_metadata_by_person_id: Dictionary,
	used_ids: Dictionary,
	party_label: String = ""
) -> void:
	if person == null:
		return

	var person_id: int = int(_value(person, "id", -1))
	if person_id <= 0:
		return

	var clean_role: String = str(role_label).strip_edges()
	var clean_branch: String = str(branch).strip_edges().to_lower()
	var clean_state: String = str(state_name).strip_edges()
	var clean_party: String = str(party_label).strip_edges()

	var office_key: String = _federal_republic_office_key_for_role(clean_role, clean_branch)

	var civic_contract: Dictionary = {
		"schema": "eralife.civic_office_contract",
		"version": 1,
		"government_model": "federal_presidential_republic",
		"country": "United States",
		"role_label": clean_role,
		"office": office_key,
		"branch": clean_branch,
		"state_name": clean_state,
		"party": clean_party,
		"priority": priority,
		"person_id": person_id,
		"realm_id": int(_value(person, "realm_id", -1)),
		"ui_is_renderer_only": true
	}

	_federal_republic_set_person_value(person, "job", clean_role)
	_federal_republic_set_person_value(person, "civic_title", clean_role)
	_federal_republic_set_person_value(person, "civic_office_contract", civic_contract.duplicate(true))
	_federal_republic_set_person_value(person, "is_royal", false)
	_federal_republic_set_person_value(person, "royal_title", "")
	_federal_republic_set_person_value(person, "succession_rank", 99)

	if clean_branch in ["executive", "cabinet", "senate", "judicial", "state_governor"]:
		_federal_republic_set_person_value(person, "social_class", "Upper Class")

	role_label_by_person_id [person_id] = clean_role
	role_label_by_person_id [str(person_id)] = clean_role

	civic_metadata_by_person_id [person_id] = {
		"role_label": clean_role,
		"branch": clean_branch,
		"state_name": clean_state,
		"party": clean_party,
		"priority": priority,
	}

	civic_metadata_by_person_id [str(person_id)] = civic_metadata_by_person_id [person_id].duplicate(true)
	used_ids [person_id] = true
func _federal_republic_cabinet_titles() -> Array:
	return [
		"Secretary of State",
		"Secretary of the Treasury",
		"Secretary of Defense",
		"Attorney General",
		"Secretary of the Interior",
		"Secretary of Agriculture",
		"Secretary of Commerce",
		"Secretary of Labor",
		"Secretary of Health and Human Services",
		"Secretary of Housing and Urban Development",
		"Secretary of Transportation",
		"Secretary of Energy",
		"Secretary of Education",
		"Secretary of Veterans Affairs",
		"Secretary of Homeland Security"
	]
func _federal_republic_ensure_required_united_states_population_nodes(
	people: Array,
	realm_id: int,
	realm_name: String,
	targets: Dictionary,
	options: Dictionary = {}
) -> Dictionary:
	var report: Dictionary = {
		"success": true,
		"schema": "eralife.population_card_contract_engine.us_federal_node_materialization_report",
		"realm_id": realm_id,
		"realm_name": realm_name,
		"created_total": 0,
		"created_by_branch": {},
		"surface_existence_pass": bool(options.get("observable_surface_existence_pass", false)),
		"ui_is_renderer_only": true
	}

	if gs == null:
		report ["success"] = false
		report ["reason"] = "missing_game_state"
		return report

	if not _is_united_states_federal_realm(realm_id, realm_name):
		report ["success"] = false
		report ["reason"] = "not_united_states_federal_realm"
		return report

	var cabinet_target: int = maxi(0, int(targets.get("cabinet", _federal_republic_cabinet_titles().size())))
	var senate_target: int = maxi(DEFAULT_US_SENATE_TARGET, int(targets.get("senate", DEFAULT_US_SENATE_TARGET)))
	var supreme_court_target: int = maxi(DEFAULT_US_SUPREME_COURT_TARGET, int(targets.get("supreme_court", DEFAULT_US_SUPREME_COURT_TARGET)))
	var governor_target: int = maxi(DEFAULT_US_GOVERNOR_TARGET, int(targets.get("governors", DEFAULT_US_GOVERNOR_TARGET)))
	var citizen_target: int = maxi(DEFAULT_CITIZEN_LIMIT, int(targets.get("citizens", DEFAULT_CITIZEN_LIMIT)))

	var cabinet_titles: Array = _federal_republic_cabinet_titles()

	var created_by_branch: Dictionary = {
		"executive": 0,
		"cabinet": 0,
		"senate": 0,
		"supreme_court": 0,
		"governor": 0,
		"citizens": 0
	}

	var vice_president = _federal_republic_find_existing_official_by_office(people, "executive", "vice president")
	if vice_president == null:
		vice_president = _federal_republic_create_official_population_node(
			realm_id,
			realm_name,
			"Vice President",
			"executive",
			"",
			"Independent",
			0
		)
		if vice_president != null:
			people.append(vice_president)
			created_by_branch ["executive"] = int(created_by_branch.get("executive", 0)) + 1

	var existing_cabinet: Array = _federal_republic_existing_official_people_for_branch(people, "cabinet")
	for i in range(existing_cabinet.size(), cabinet_target):
		var title: String = str(cabinet_titles [i % cabinet_titles.size()])
		var official = _federal_republic_create_official_population_node(
			realm_id,
			realm_name,
			title,
			"cabinet",
			"",
			"",
			i
		)
		if official != null:
			people.append(official)
			created_by_branch ["cabinet"] = int(created_by_branch.get("cabinet", 0)) + 1

	var existing_senate: Array = _federal_republic_existing_official_people_for_branch(people, "senate")
	for i in range(existing_senate.size(), senate_target):
		var state_index: int = int(floor(float(i) / 2.0)) % UNITED_STATES_STATE_NAMES.size()
		var state_name: String = str(UNITED_STATES_STATE_NAMES [state_index])
		var senate_party: String = _federal_republic_senate_party_for_index(i)
		var senator = _federal_republic_create_official_population_node(
			realm_id,
			realm_name,
			"%s Senator of %s" % [senate_party, state_name],
			"senate",
			state_name,
			senate_party,
			i
		)
		if senator != null:
			people.append(senator)
			created_by_branch ["senate"] = int(created_by_branch.get("senate", 0)) + 1

	var existing_supreme_court: Array = _federal_republic_existing_official_people_for_branch(people, "supreme_court")
	for i in range(existing_supreme_court.size(), supreme_court_target):
		var justice_title: String = "Chief Justice" if i == 0 else "Supreme Court Justice"
		var justice = _federal_republic_create_official_population_node(
			realm_id,
			realm_name,
			justice_title,
			"judicial",
			"",
			"",
			i
		)
		if justice != null:
			people.append(justice)
			created_by_branch ["supreme_court"] = int(created_by_branch.get("supreme_court", 0)) + 1

	var existing_governors: Array = _federal_republic_existing_official_people_for_branch(people, "governor")
	for i in range(existing_governors.size(), governor_target):
		var governor_state: String = str(UNITED_STATES_STATE_NAMES [i % UNITED_STATES_STATE_NAMES.size()])
		var governor_party: String = _federal_republic_governor_party_for_index(i)
		var governor = _federal_republic_create_official_population_node(
			realm_id,
			realm_name,
			"%s Governor of %s" % [governor_party, governor_state],
			"state_governor",
			governor_state,
			governor_party,
			i
		)
		if governor != null:
			people.append(governor)
			created_by_branch ["governor"] = int(created_by_branch.get("governor", 0)) + 1

	var existing_citizens: int = _federal_republic_existing_citizen_count(people)
	for i in range(existing_citizens, citizen_target):
		var civilian = _federal_republic_create_civilian_population_node(
			realm_id,
			realm_name,
			i
		)
		if civilian != null:
			people.append(civilian)
			created_by_branch ["citizens"] = int(created_by_branch.get("citizens", 0)) + 1

	var created_total: int = 0
	for raw_count in created_by_branch.values():
		created_total += int(raw_count)

	report ["created_total"] = created_total
	report ["created_by_branch"] = created_by_branch.duplicate(true)
	report ["cabinet_target"] = cabinet_target
	report ["senate_target"] = senate_target
	report ["supreme_court_target"] = supreme_court_target
	report ["governor_target"] = governor_target
	report ["citizen_target"] = citizen_target

	if gs != null and "scenario_state" in gs and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["population_card_contract_engine_us_federal_node_materialization_report"] = report.duplicate(true)

	if gs != null and gs.has_method("_rebuild_npc_index"):
		gs._rebuild_npc_index()

	return report


func _federal_republic_create_official_population_node(
	realm_id: int,
	realm_name: String,
	role_label: String,
	branch: String,
	state_name: String,
	party_label: String,
	index: int
):
	if gs == null:
		return null
	if _value(gs, "npc_factory", null) == null:
		return null
	if not gs.npc_factory.has_method("create_random_npc"):
		return null

	var npc = gs.npc_factory.create_random_npc(false)
	if npc == null:
		return null

	var clean_role: String = str(role_label).strip_edges()
	var clean_branch: String = str(branch).strip_edges().to_lower()
	var clean_state: String = str(state_name).strip_edges()
	var clean_party: String = str(party_label).strip_edges()

	_federal_republic_set_person_value(npc, "age", _federal_republic_minimum_age_for_branch(clean_branch) + int(index % 24))
	_federal_republic_set_person_value(npc, "alive", true)
	_federal_republic_set_person_value(npc, "realm_id", realm_id)
	_federal_republic_set_person_value(npc, "home_country", "USA")
	_federal_republic_set_person_value(npc, "birth_country", "USA")
	_federal_republic_set_person_value(npc, "home_state", clean_state)
	_federal_republic_set_person_value(npc, "birth_state", clean_state)
	_federal_republic_set_person_value(npc, "job", clean_role)
	_federal_republic_set_person_value(npc, "civic_title", clean_role)
	_federal_republic_set_person_value(npc, "social_class", "Upper Class")
	_federal_republic_set_person_value(npc, "is_royal", false)
	_federal_republic_set_person_value(npc, "is_ruler", false)
	_federal_republic_set_person_value(npc, "royal_title", "")
	_federal_republic_set_person_value(npc, "succession_rank", 99)
	_federal_republic_set_person_value(npc, "approval", 50 + int(index % 35))
	_federal_republic_set_person_value(npc, "respect", 55 + int(index % 30))
	_federal_republic_set_person_value(npc, "smarts", 60 + int(index % 35))
	_federal_republic_set_person_value(npc, "fame", 10 + int(index % 45))

	var contract: Dictionary = {
		"schema": "eralife.civic_office_contract",
		"version": 1,
		"government_model": "federal_presidential_republic",
		"country": "United States",
		"realm_id": realm_id,
		"realm_name": realm_name,
		"role_label": clean_role,
		"office": _federal_republic_office_key_for_role(clean_role, clean_branch),
		"branch": clean_branch,
		"state_name": clean_state,
		"party": clean_party,
		"ui_is_renderer_only": true
	}

	_federal_republic_set_person_value(npc, "civic_office_contract", contract)

	if "npcs" in gs and not gs.npcs.has(npc):
		gs.npcs.append(npc)

	return npc


func _federal_republic_create_civilian_population_node(
	realm_id: int,
	_realm_name: String,
	index: int
):
	if gs == null:
		return null
	if _value(gs, "npc_factory", null) == null:
		return null
	if not gs.npc_factory.has_method("create_random_npc"):
		return null

	var npc = gs.npc_factory.create_random_npc(false)
	if npc == null:
		return null

	var classes: Array = [
		"Upper Class",
		"Middle Class",
		"Middle Class",
		"Lower Class",
		"Lower Class",
		"Poor"
	]

	var jobs: Array = [
		"Teacher",
		"Nurse",
		"Mechanic",
		"Restaurant Worker",
		"Software Developer",
		"Truck Driver",
		"Retail Worker",
		"Accountant",
		"Construction Worker",
		"Paramedic",
		"Office Worker",
		"Factory Worker"
	]

	_federal_republic_set_person_value(npc, "age", 18 + int(index % 58))
	_federal_republic_set_person_value(npc, "alive", true)
	_federal_republic_set_person_value(npc, "realm_id", realm_id)
	_federal_republic_set_person_value(npc, "home_country", "USA")
	_federal_republic_set_person_value(npc, "birth_country", "USA")
	_federal_republic_set_person_value(npc, "social_class", str(classes [index % classes.size()]))
	_federal_republic_set_person_value(npc, "job", str(jobs [index % jobs.size()]))
	_federal_republic_set_person_value(npc, "civic_title", "")
	_federal_republic_set_person_value(npc, "civic_office_contract", {})
	_federal_republic_set_person_value(npc, "is_royal", false)
	_federal_republic_set_person_value(npc, "is_ruler", false)
	_federal_republic_set_person_value(npc, "royal_title", "")
	_federal_republic_set_person_value(npc, "succession_rank", 99)

	if "npcs" in gs and not gs.npcs.has(npc):
		gs.npcs.append(npc)

	return npc


func _federal_republic_existing_official_people_for_branch(people: Array, branch: String) -> Array:
	var out: Array = []
	var seen: Dictionary = {}

	for raw_person in people:
		if raw_person == null:
			continue
		if _federal_republic_disallows_official_candidate(raw_person, branch, _federal_republic_minimum_age_for_branch(branch)):
			continue
		if not _federal_republic_person_matches_branch_contract(raw_person, branch):
			continue

		var person_id: int = int(_value(raw_person, "id", -1))
		if person_id <= 0:
			continue
		if seen.has(person_id):
			continue

		out.append(raw_person)
		seen [person_id] = true

	return out


func _federal_republic_existing_citizen_count(people: Array) -> int:
	var count: int = 0

	for raw_person in people:
		if raw_person == null:
			continue
		if not bool(_value(raw_person, "alive", true)):
			continue
		if int(_value(raw_person, "id", -1)) <= 0:
			continue

		var contract_raw: Variant = _value(raw_person, "civic_office_contract", {})
		if typeof(contract_raw) == TYPE_DICTIONARY:
			var contract: Dictionary = contract_raw
			if str(contract.get("government_model", "")).strip_edges().to_lower() == "federal_presidential_republic":
				continue

		if _federal_republic_person_is_aristocratic_leak(raw_person):
			continue

		count += 1

	return count


func _federal_republic_filter_people_for_federal_branch(people: Array, branch: String, min_age: int) -> Array:
	var out: Array = []
	var seen: Dictionary = {}

	for raw_person in people:
		if raw_person == null:
			continue

		var person_id: int = int(_value(raw_person, "id", -1))
		if person_id <= 0:
			continue
		if seen.has(person_id):
			continue
		if _federal_republic_disallows_official_candidate(raw_person, branch, min_age):
			continue

		if str(branch).strip_edges().to_lower() == "cabinet":
			var title_blob: String = _population_card_person_title_blob(raw_person)
			var job_key: String = str(_value(raw_person, "job", "")).strip_edges().to_lower()
			var civic_title: String = str(_value(raw_person, "civic_title", "")).strip_edges().to_lower()
			if _population_card_text_has_any(title_blob, ["vice president"]) \
or _population_card_text_has_any(job_key, ["vice president"]) \
or _population_card_text_has_any(civic_title, ["vice president"]):
				continue

		out.append(raw_person)
		seen [person_id] = true

	return out


func _federal_republic_select_vice_president(people: Array, used_ids: Dictionary, realm_id: int):
	var best = null
	var best_score: int = -999999

	for raw_person in people:
		if raw_person == null:
			continue
		if not bool(_value(raw_person, "alive", true)):
			continue

		var person_id: int = int(_value(raw_person, "id", -1))
		if person_id <= 0:
			continue
		if used_ids.has(person_id):
			continue
		if _federal_republic_disallows_official_candidate(raw_person, "executive", 35):
			continue

		var score: int = _federal_republic_official_candidate_score(raw_person, realm_id, "president")
		var title_blob: String = _population_card_person_title_blob(raw_person)
		var job_key: String = str(_value(raw_person, "job", "")).strip_edges().to_lower()
		var civic_title: String = str(_value(raw_person, "civic_title", "")).strip_edges().to_lower()

		var contract_raw: Variant = _value(raw_person, "civic_office_contract", {})
		if typeof(contract_raw) == TYPE_DICTIONARY:
			var contract: Dictionary = contract_raw
			var office_text: String = str(contract.get("office", "")).strip_edges().to_lower()
			var branch_text: String = str(contract.get("branch", "")).strip_edges().to_lower()
			if branch_text == "executive" and office_text == "vice president":
				score += 120000

		if _population_card_text_has_any(title_blob, ["vice president"]) \
or _population_card_text_has_any(job_key, ["vice president"]) \
or _population_card_text_has_any(civic_title, ["vice president"]):
			score += 50000

		if score > best_score:
			best = raw_person
			best_score = score

	return best


func _federal_republic_find_existing_official_by_office(people: Array, branch: String, office: String):
	var clean_branch: String = str(branch).strip_edges().to_lower()
	var clean_office: String = str(office).strip_edges().to_lower()

	for raw_person in people:
		if raw_person == null:
			continue

		var contract_raw: Variant = _value(raw_person, "civic_office_contract", {})
		if typeof(contract_raw) != TYPE_DICTIONARY:
			continue

		var contract: Dictionary = contract_raw
		if str(contract.get("government_model", "")).strip_edges().to_lower() != "federal_presidential_republic":
			continue
		if str(contract.get("branch", "")).strip_edges().to_lower() != clean_branch:
			continue
		if str(contract.get("office", "")).strip_edges().to_lower() != clean_office:
			continue

		return raw_person

	return null


func _federal_republic_disallows_official_candidate(person, branch: String, min_age: int) -> bool:
	if person == null:
		return true
	if not bool(_value(person, "alive", true)):
		return true

	var person_id: int = int(_value(person, "id", -1))
	if person_id <= 0:
		return true

	var age: int = int(_value(person, "age", 0))
	if age < min_age:
		return true

	if _federal_republic_is_player_immediate_family(person):
		return true

	if _federal_republic_person_is_aristocratic_leak(person):
		if not _federal_republic_person_matches_branch_contract(person, branch):
			return true

	var clean_branch: String = str(branch).strip_edges().to_lower()
	if clean_branch in ["cabinet", "senate", "supreme_court", "governor", "state_governor"]:
		var title_blob: String = _population_card_person_title_blob(person)
		var job_key: String = str(_value(person, "job", "")).strip_edges().to_lower()
		if _population_card_text_has_any(title_blob, ["first lady", "first gentleman", "president"]) \
or _population_card_text_has_any(job_key, ["first lady", "first gentleman", "president"]):
			return true

	return false


func _federal_republic_is_player_immediate_family(person) -> bool:
	if gs == null or person == null:
		return false

	var player = _value(gs, "player", null)
	if player == null:
		return false

	var person_id: int = int(_value(person, "id", -1))
	var player_id: int = int(_value(player, "id", -1))
	if person_id <= 0:
		return true
	if person_id == player_id:
		return true

	var player_parent_ids: Array = _value(player, "parents", []) if typeof(_value(player, "parents", [])) == TYPE_ARRAY else []
	var player_child_ids: Array = _value(player, "children", []) if typeof(_value(player, "children", [])) == TYPE_ARRAY else []
	var person_parent_ids: Array = _value(person, "parents", []) if typeof(_value(person, "parents", [])) == TYPE_ARRAY else []

	if player_parent_ids.has(person_id):
		return true
	if player_child_ids.has(person_id):
		return true

	var partner_id: int = _person_ref_id(_value(player, "partner", null))
	if partner_id > 0 and partner_id == person_id:
		return true

	for raw_parent_id in person_parent_ids:
		if player_parent_ids.has(int(raw_parent_id)):
			return true

	return false


func _federal_republic_person_is_aristocratic_leak(person) -> bool:
	if person == null:
		return true

	var contract_raw: Variant = _value(person, "civic_office_contract", {})
	if typeof(contract_raw) == TYPE_DICTIONARY:
		var contract: Dictionary = contract_raw
		if str(contract.get("government_model", "")).strip_edges().to_lower() == "federal_presidential_republic":
			return false

	var social_key: String = str(_value(person, "social_class", "")).strip_edges().to_lower()
	var royal_title: String = str(_value(person, "royal_title", "")).strip_edges().to_lower()
	var title_blob: String = _population_card_person_title_blob(person)

	if bool(_value(person, "is_royal", false)):
		return true

	if social_key in [
		"royal",
		"noble",
		"nobility",
		"aristocrat",
		"aristocracy",
		"ducal",
		"duke",
		"duchess",
		"lord",
		"lady"
	]:
		return true

	if royal_title != "":
		return true

	if _population_card_text_has_any(title_blob, [
		"king",
		"queen",
		"prince",
		"princess",
		"duke",
		"duchess",
		"lord",
		"lady",
		"baron",
		"baroness",
		"count",
		"countess"
	]):
		return true

	return false


func _federal_republic_minimum_age_for_branch(branch: String) -> int:
	var clean_branch: String = str(branch).strip_edges().to_lower()

	match clean_branch:
		"executive":
			return 35
		"senate":
			return 30
		"supreme_court":
			return 40
		"judicial":
			return 40
		"governor":
			return 30
		"state_governor":
			return 30
		"cabinet":
			return 30
		_:
			return 18


func _federal_republic_office_key_for_role(role_label: String, branch: String) -> String:
	var clean_role: String = str(role_label).strip_edges().to_lower()
	var clean_branch: String = str(branch).strip_edges().to_lower()

	if clean_role.find("vice president") >= 0:
		return "vice president"
	if clean_role.find("president") >= 0 and clean_role.find("vice") < 0:
		return "president"
	if clean_role.find("senator") >= 0:
		return "senator"
	if clean_role.find("governor") >= 0:
		return "governor"
	if clean_role.find("chief justice") >= 0:
		return "chief justice"
	if clean_role.find("supreme court justice") >= 0:
		return "supreme court justice"
	if clean_role.find("attorney general") >= 0:
		return "attorney general"
	if clean_role.find("secretary") >= 0:
		return clean_role

	match clean_branch:
		"senate":
			return "senator"
		"state_governor":
			return "governor"
		"governor":
			return "governor"
		"judicial":
			return "supreme court justice"
		"supreme_court":
			return "supreme court justice"
		"cabinet":
			return clean_role
		_:
			return clean_role


func _federal_republic_senate_party_for_index(index: int) -> String:
	return "Democratic" if index % 2 == 0 else "Republican"


func _federal_republic_governor_party_for_index(index: int) -> String:
	return "Republican" if index % 2 == 0 else "Democratic"


func _federal_republic_set_person_value(target, key: String, value) -> void:
	if target == null:
		return

	if typeof(target) == TYPE_DICTIONARY:
		var dict: Dictionary = target
		dict [key] = value
		return

	if key in target:
		target.set(key, value)
func _ensure_noble_court_minimum(
	buckets: Dictionary,
	all_people: Array,
	realm_id: int,
	realm_name: String,
	target_min: int
) -> Dictionary:
	var out: Dictionary = buckets.duplicate(true)

	if target_min <= 0:
		return out

	var nobles: Array = out.get("nobles", []) if typeof(out.get("nobles", [])) == TYPE_ARRAY else []
	var citizens: Array = out.get("citizens", []) if typeof(out.get("citizens", [])) == TYPE_ARRAY else []

	if nobles.size() >= target_min:
		return out

	var royal_ids: Dictionary = _population_card_ids_for_people(out.get("royals", []))
	var master_ids: Dictionary = _population_card_ids_for_people(out.get("masters", []))
	var noble_ids: Dictionary = _population_card_ids_for_people(nobles)

	var candidates: Array = []

	for raw_person in all_people:
		if raw_person == null:
			continue
		if not bool(_value(raw_person, "alive", true)):
			continue

		var person_id: int = int(_value(raw_person, "id", -1))
		if person_id <= 0:
			continue
		if royal_ids.has(person_id) or master_ids.has(person_id) or noble_ids.has(person_id):
			continue

		var score: int = _population_card_noble_candidate_score(raw_person, realm_id, realm_name)
		if score <= 0:
			continue

		candidates.append({
			"person": raw_person,
			"score": score
		})

	candidates.sort_custom(func (a, b):
		return int((a as Dictionary).get("score", 0)) > int((b as Dictionary).get("score", 0))
	)

	var promoted_ids: Dictionary = {}

	for raw_candidate in candidates:
		if nobles.size() >= target_min:
			break
		if typeof(raw_candidate) != TYPE_DICTIONARY:
			continue

		var candidate: Dictionary = raw_candidate
		var person = candidate.get("person", null)
		if person == null:
			continue

		var person_id: int = int(_value(person, "id", -1))
		if person_id <= 0 or promoted_ids.has(person_id):
			continue

		nobles.append(person)
		promoted_ids [person_id] = true
		noble_ids [person_id] = true

	var remaining_citizens: Array = []
	for raw_citizen in citizens:
		var citizen_id: int = int(_value(raw_citizen, "id", -1))
		if citizen_id > 0 and promoted_ids.has(citizen_id):
			continue
		remaining_citizens.append(raw_citizen)

	nobles.sort_custom(func (a, b):
		return _population_card_noble_sort_score(a, realm_id) > _population_card_noble_sort_score(b, realm_id)
	)

	remaining_citizens.sort_custom(func (a, b):
		return _population_card_citizen_wall_sort_score(a, realm_id, realm_name) > _population_card_citizen_wall_sort_score(b, realm_id, realm_name)
	)

	out ["nobles"] = nobles
	out ["citizens"] = remaining_citizens
	out ["noble_court_contract_minimum_applied"] = nobles.size() >= target_min
	out ["noble_court_contract_target_min"] = target_min
	out ["noble_court_contract_promoted_count"] = promoted_ids.size()
	out ["noble_court_contract_does_not_mutate_people"] = true

	return out


func _population_card_ids_for_people(people: Array) -> Dictionary:
	var out: Dictionary = {}

	if typeof(people) != TYPE_ARRAY:
		return out

	for raw_person in people:
		var person_id: int = int(_value(raw_person, "id", -1))
		if person_id > 0:
			out [person_id] = true

	return out
func _realm_uses_noble_court(realm_id: int, realm_name: String = "") -> bool:
	var name_key: String = str(realm_name).strip_edges().to_lower()
	var government_style: String = ""

	if gs != null and gs.realm_engine != null and "realms" in gs.realm_engine and typeof(gs.realm_engine.realms) == TYPE_DICTIONARY:
		var realm_raw: Variant = gs.realm_engine.realms.get(realm_id, {})
		if typeof(realm_raw) == TYPE_DICTIONARY:
			var realm: Dictionary = realm_raw
			government_style = str(realm.get("government_style", realm.get("government", ""))).strip_edges().to_lower()

	if government_style in [
		"monarchy",
		"empire",
		"imperial",
		"kingdom",
		"hereditary monarchy",
		"constitutional monarchy",
		"feudal monarchy"
	]:
		return true

	for token in [
		"kingdom",
		"empire",
		"nation",
		"tribe",
		"dynasty",
		"caliphate",
		"sultanate",
		"realm"
	]:
		if name_key.find(token) >= 0:
			return true

	return false

func _population_card_noble_candidate_score(person, realm_id: int, realm_name: String = "") -> int:
	if person == null:
		return -999999

	if bool(_value(person, "is_ruler", false)):
		return -999999
	if _is_realm_ruler_partner_person(person, realm_id):
		return -999999
	if _population_card_person_has_prince_or_princess_title(person):
		return -999999
	if _population_card_person_has_clear_royal_title(person):
		return -999999
	if _is_direct_royal_child_or_heir(person, realm_id):
		return -999999
	if _population_card_person_is_royal_offspring(person, realm_id):
		return -999999
	if _is_master_person(person, realm_id, realm_name):
		return -999999

	if _population_card_has_hard_commoner_marker(person):
		return -999999

	var score: int = 0

	if _population_card_person_has_clear_noble_title(person):
		score += 2500

	var social_key: String = str(_value(person, "social_class", "")).strip_edges().to_lower()
	var job_key: String = str(_value(person, "job", "")).strip_edges().to_lower()

	if social_key in [
		"noble",
		"nobility",
		"aristocrat",
		"aristocracy",
		"upper nobility",
		"high nobility",
		"high noble"
	]:
		score += 2400

	if social_key in [
		"elite",
		"ruling elite",
		"old money",
		"wealthy",
		"rich",
		"upper class",
		"upper-class",
		"upper middle class",
		"upper-middle class"
	]:
		score += 950

	if _population_card_text_has_any(job_key, [
		"court",
		"minister",
		"advisor",
		"council",
		"governor",
		"regent",
		"chancellor",
		"ambassador",
		"seneschal",
		"steward"
	]):
		score += 780

	var bank_value: int = int(_value(person, "bank_balance", 0))
	if bank_value >= 10000000:
		score += 650
	elif bank_value >= 1000000:
		score += 420
	elif bank_value >= 250000:
		score += 220

	score += int(_value(person, "fame", 0)) * 4
	score += int(_value(person, "respect", 0)) * 5
	score += int(_value(person, "approval", 0)) * 2
	score += int(_value(person, "age", 0))

	if score < 420:
		return -1

	return score

func _population_card_person_is_royal_offspring(person, realm_id: int) -> bool:
	if person == null:
		return false

	if _population_card_person_has_prince_or_princess_title(person):
		return true

	var ruler_id: int = _realm_ruler_id(realm_id)
	if ruler_id <= 0:
		return false

	var parents_raw: Variant = _value(person, "parents", [])
	if typeof(parents_raw) == TYPE_ARRAY:
		for raw_parent in parents_raw as Array:
			if _person_ref_id(raw_parent) == ruler_id:
				return true

	for raw_key in [
		"relationship_to_ruler",
		"relationship_to_monarch",
		"relationship_to_sovereign",
		"family_role",
		"lineage_role",
		"dynasty_role"
	]:
		var value_text: String = str(_value(person, str(raw_key), "")).strip_edges()
		if value_text == "":
			continue

		if _population_card_text_has_any(value_text, [
			"son",
			"daughter",
			"child",
			"offspring",
			"prince",
			"princess",
			"royal child",
			"royal son",
			"royal daughter"
		]):
			return true

	return false
func _population_card_has_hard_commoner_marker(person) -> bool:
	if person == null:
		return true

	var social_key: String = str(_value(person, "social_class", "")).strip_edges().to_lower()
	var job_key: String = str(_value(person, "job", "")).strip_edges().to_lower()
	var title_text: String = _population_card_person_title_blob(person)

	if social_key in [
		"peasant",
		"commoner",
		"merchant",
		"trader",
		"artisan",
		"craftsman",
		"shopkeeper",
		"worker",
		"working class",
		"working-class",
		"middle class",
		"middle-class",
		"bottom class",
		"bottom-class",
		"low class",
		"low-class",
		"lower class",
		"lower-class",
		"lowborn",
		"serf",
		"slave",
		"citizen",
		"civilian"
	]:
		return true

	if _population_card_text_has_any(job_key, [
		"farmer",
		"farmhand",
		"laborer",
		"servant",
		"miner",
		"fisher",
		"fisherman",
		"merchant",
		"trader",
		"artisan",
		"shopkeeper",
		"blacksmith",
		"teacher",
		"doctor",
		"lawyer",
		"engineer",
		"manager",
		"accountant",
		"nurse",
		"developer"
	]):
		return true

	if _population_card_text_has_any(title_text, [
		"commoner",
		"peasant",
		"merchant",
		"trader",
		"farmer",
		"teacher",
		"citizen",
		"civilian"
	]):
		return true

	return false


func _population_card_noble_sort_score(person, realm_id: int) -> int:
	if person == null:
		return -999999

	var score: int = _population_card_noble_candidate_score(person, realm_id, _realm_name_for_id(realm_id))
	var title: String = _population_card_noble_title_for_person(person, realm_id)
	var tier_weight: int = _population_card_noble_title_weight(title)

	score += tier_weight
	score += int(_value(person, "respect", 0)) * 6
	score += int(_value(person, "fame", 0)) * 4
	score += int(_value(person, "age", 0))

	return score


func _population_card_citizen_wall_sort_score(person, realm_id: int, realm_name: String = "") -> int:
	if person == null:
		return -999999

	var score: int = 0

	if not _population_card_is_lowest_citizen_stratum(person, realm_id, realm_name):
		score += 1000

	score += int(_value(person, "respect", 0)) * 4
	score += int(_value(person, "fame", 0)) * 3
	score += int(_value(person, "age", 0))

	var person_id: int = int(_value(person, "id", 0))
	score -= person_id % 100

	return score
func _population_card_category_for_person(person, realm_id: int, realm_name: String) -> String:
	if person == null:
		return "citizen"


	if bool(_value(person, "is_ruler", false)):
		return "royal"

	if _is_realm_ruler_partner_person(person, realm_id):
		return "royal"

	if _population_card_person_has_prince_or_princess_title(person):
		return "royal"

	if _population_card_person_has_clear_royal_title(person):
		return "royal"

	if _is_direct_royal_child_or_heir(person, realm_id):
		return "royal"


	if _population_card_person_has_clear_noble_title(person):
		return "noble"

	var social_key: String = str(_value(person, "social_class", "")).strip_edges().to_lower()
	if social_key in [
		"noble",
		"nobility",
		"aristocrat",
		"aristocracy",
		"upper nobility",
		"high nobility",
		"high noble",
		"ducal",
		"duke",
		"duchess",
		"marquess",
		"marchioness",
		"marquis",
		"marquise",
		"marquee",
		"earl",
		"count",
		"countess",
		"viscount",
		"viscountess",
		"baron",
		"baroness",
		"lord",
		"lady"
	]:
		return "noble"

	if _is_master_person(person, realm_id, realm_name):
		return "master"

	return "citizen"
func _population_card_federal_realm_needs_pool_broadening(realm_id: int, realm_name: String, current_count: int) -> bool:
	if not _is_united_states_federal_realm(realm_id, realm_name):
		return false

	var minimum_projection_pool: int = DEFAULT_US_CABINET_TARGET \
+ DEFAULT_US_SUPREME_COURT_TARGET \
+ DEFAULT_US_GOVERNOR_TARGET \
+ 24

	return current_count < minimum_projection_pool

func _population_card_civic_office_matches_realm_scope(
	person,
	realm_id: int,
	scope: Dictionary
) -> bool:
	if person == null or realm_id <= 0:
		return false

	var civic_raw: Variant = _value(person, "civic_office_contract", {})
	if typeof(civic_raw) != TYPE_DICTIONARY:
		return false

	var civic: Dictionary = civic_raw
	var civic_realm_id: int = -1

	for raw_key in [
		"realm_id",
		"jurisdiction_realm_id",
		"government_realm_id",
		"country_realm_id"
	]:
		var candidate_id: int = int(civic.get(str(raw_key), -1))
		if candidate_id > 0:
			civic_realm_id = candidate_id
			break

	if civic_realm_id > 0:
		return civic_realm_id == realm_id

	var aliases: Dictionary = (
		scope.get("aliases", {})
		if typeof(scope.get("aliases", {})) == TYPE_DICTIONARY
		else {}
	)

	for raw_key in [
		"realm_name",
		"country",
		"nation",
		"jurisdiction",
		"jurisdiction_name",
		"government_name"
	]:
		var match_key: String = _population_card_match_key(
			str(civic.get(str(raw_key), ""))
		)

		if match_key != "" and aliases.has(match_key):
			return true

	return false
func _population_card_append_unique_global_pool_candidate(
	out: Array,
	seen: Dictionary,
	person,
	realm_id: int,
	scope: Dictionary
) -> void:
	if person == null:
		return
	if not bool(_value(person, "alive", true)):
		return

	var person_id: int = int(_value(person, "id", -1))
	if person_id <= 0:
		return
	if seen.has(person_id):
		return

	var resident_matches_realm: bool = _population_card_person_matches_realm_scope(
		person,
		realm_id,
		scope
	)
	var civic_office_matches_realm: bool = _population_card_civic_office_matches_realm_scope(
		person,
		realm_id,
		scope
	)



	if not resident_matches_realm and not civic_office_matches_realm:
		return

	var civic_contract_raw: Variant = _value(person, "civic_office_contract", {})
	if typeof(civic_contract_raw) == TYPE_DICTIONARY:
		var civic_contract: Dictionary = civic_contract_raw
		if str(civic_contract.get("government_model", "")).strip_edges().to_lower() == "federal_presidential_republic":
			out.append(person)
			seen [person_id] = true
			return

	var social_key: String = str(
		_value(person, "social_class", "")
	).strip_edges().to_lower()
	var job_key: String = str(
		_value(person, "job", "")
	).strip_edges().to_lower()

	if bool(_value(person, "is_royal", false)) and social_key in ["royal", "noble"]:
		return

	if social_key in [
		"elite",
		"upper class",
		"upperclass",
		"upper middle class",
		"upper-middle class",
		"middle class",
		"middle-class",
		"lower middle class",
		"lower-middle class",
		"working class",
		"working-class",
		"bottom class",
		"bottom-class",
		"poor",
		"low class",
		"low-class",
		"commoner",
		"merchant",
		"peasant"
	]:
		out.append(person)
		seen [person_id] = true
		return

	if job_key != "":
		out.append(person)
		seen [person_id] = true
		return

	out.append(person)
	seen [person_id] = true

func _population_card_broaden_federal_realm_pool_from_world_population(
	out: Array,
	seen: Dictionary,
	realm_id: int,
	realm_name: String,
	scope: Dictionary
) -> void:
	if gs == null:
		return
	if not _population_card_federal_realm_needs_pool_broadening(realm_id, realm_name, out.size()):
		return

	var target_pool_size: int = DEFAULT_US_CABINET_TARGET \
+ DEFAULT_US_SENATE_TARGET \
+ DEFAULT_US_SUPREME_COURT_TARGET \
+ DEFAULT_US_GOVERNOR_TARGET \
+ DEFAULT_CITIZEN_LIMIT

	target_pool_size = maxi(target_pool_size, 324)

	if "npcs" in gs:
		for raw_npc in gs.npcs:
			if out.size() >= target_pool_size:
				return

			_population_card_append_unique_global_pool_candidate(
				out,
				seen,
				raw_npc,
				realm_id,
				scope
			)

	if "dormant_npcs" in gs and typeof(gs.dormant_npcs) == TYPE_DICTIONARY:
		for raw_id in gs.dormant_npcs.keys():
			if out.size() >= target_pool_size:
				return

			var dormant_raw: Variant = gs.dormant_npcs.get(raw_id, {})
			if typeof(dormant_raw) != TYPE_DICTIONARY:
				continue

			_population_card_append_unique_global_pool_candidate(
				out,
				seen,
				dormant_raw as Dictionary,
				realm_id,
				scope
			)
func _derive_realm_population_entities(realm_id: int, include_dormant: bool = true) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	if gs == null or realm_id <= 0:
		return out

	var scope: Dictionary = _population_card_realm_scope_contract(realm_id)
	var realm_name: String = str(scope.get("realm_name", _realm_name_for_id(realm_id))).strip_edges()

	var realm_engine = _value(gs, "realm_engine", null)
	if realm_engine != null and realm_engine.has_method("derive_realm_residents"):
		var engine_residents: Array = realm_engine.derive_realm_residents(realm_id, include_dormant)
		for raw_engine_person in engine_residents:
			_population_card_push_unique_realm_person(out, seen, raw_engine_person, realm_id, scope)

	var player = _value(gs, "player", null)
	if player != null:
		_population_card_push_unique_realm_person(out, seen, player, realm_id, scope)

	if "npcs" in gs:
		for raw_npc in gs.npcs:
			_population_card_push_unique_realm_person(out, seen, raw_npc, realm_id, scope)

	if include_dormant and "dormant_npcs" in gs and typeof(gs.dormant_npcs) == TYPE_DICTIONARY:
		for raw_id in gs.dormant_npcs.keys():
			var dormant_raw: Variant = gs.dormant_npcs.get(raw_id, {})
			if typeof(dormant_raw) != TYPE_DICTIONARY:
				continue
			_population_card_push_unique_realm_person(out, seen, dormant_raw as Dictionary, realm_id, scope)

	_population_card_merge_truth_resolution_nodes(
		out,
		seen,
		realm_id,
		realm_name,
		scope
	)

	_population_card_broaden_federal_realm_pool_from_world_population(
		out,
		seen,
		realm_id,
		realm_name,
		scope
	)

	out.sort_custom(func (a, b):
		return _person_sort_score(a, realm_id) > _person_sort_score(b, realm_id)
	)

	return out
func _population_card_merge_truth_resolution_nodes(
	out: Array,
	seen: Dictionary,
	realm_id: int,
	realm_name: String,
	scope: Dictionary
) -> void:
	if gs == null:
		return
	if not "truth_resolution_contract_engine" in gs:
		return
	if gs.truth_resolution_contract_engine == null:
		return
	if not gs.truth_resolution_contract_engine.has_method("population_truth_nodes_for_realm"):
		return

	var truth_nodes: Array = gs.truth_resolution_contract_engine.population_truth_nodes_for_realm(
		realm_id,
		realm_name
	)

	for raw_node in truth_nodes:
		if typeof(raw_node) != TYPE_DICTIONARY:
			continue

		_population_card_push_unique_realm_person(
			out,
			seen,
			raw_node as Dictionary,
			realm_id,
			scope
		)
func _population_card_push_unique_realm_person(
	out: Array,
	seen: Dictionary,
	person,
	realm_id: int,
	scope: Dictionary
) -> void:
	if person == null:
		return

	if not bool(_value(person, "alive", true)):
		return

	if not _population_card_person_matches_realm_scope(person, realm_id, scope):
		return

	var person_id: int = int(_value(person, "id", -1))
	if person_id <= 0:
		return

	if seen.has(person_id):
		return

	out.append(person)
	seen [person_id] = true


func _population_card_realm_scope_contract(realm_id: int) -> Dictionary:
	var sovereign_aliases: Dictionary = {}
	var cities: Dictionary = {}
	var visual_themes: Dictionary = {}
	var realm_name: String = _realm_name_for_id(realm_id)

	_population_card_add_match_key(
		sovereign_aliases,
		realm_name
	)
	_population_card_add_match_key(
		sovereign_aliases,
		str(realm_id)
	)

	var realm_engine = _value(gs, "realm_engine", null)

	if (
		realm_engine != null
		and "realms" in realm_engine
		and typeof(realm_engine.realms) == TYPE_DICTIONARY
	):
		var realm_raw: Variant = realm_engine.realms.get(realm_id, {})

		if typeof(realm_raw) == TYPE_DICTIONARY:
			var realm: Dictionary = realm_raw


			for raw_alias in [
				realm.get("name", ""),
				realm.get("country", ""),
				realm.get("realm_contract_resolved_from_country", "")
			]:
				_population_card_add_match_key(
					sovereign_aliases,
					str(raw_alias)
				)



			for raw_visual_theme in [
				realm.get("browser_visual_theme", ""),
				realm.get("overview_visual_theme", ""),
				realm.get("element", ""),
				realm.get("native_element", "")
			]:
				_population_card_add_match_key(
					visual_themes,
					str(raw_visual_theme)
				)

			for raw_city in [
				realm.get("capital_city", ""),
				realm.get("capital", ""),
				realm.get("seat_of_power", "")
			]:
				_population_card_add_match_key(
					cities,
					str(raw_city)
				)

			for raw_array_key in [
				"subzones",
				"cities",
				"major_cities",
				"notable_zones",
				"regions",
				"settlements"
			]:
				var raw_list: Variant = realm.get(raw_array_key, [])

				if typeof(raw_list) != TYPE_ARRAY:
					continue

				for raw_entry in raw_list as Array:
					_population_card_add_match_key(
						cities,
						str(raw_entry)
					)

		if realm_engine.has_method("_normalize_realm_match_aliases"):
			var normalized_aliases: Variant = realm_engine._normalize_realm_match_aliases(
				realm_name
			)

			if typeof(normalized_aliases) == TYPE_DICTIONARY:
				for raw_alias_key in (normalized_aliases as Dictionary).keys():
					_population_card_add_match_key(
						sovereign_aliases,
						str(raw_alias_key)
					)

	return {
		"realm_id": realm_id,
		"realm_name": realm_name,
		"aliases": sovereign_aliases,
		"sovereign_aliases": sovereign_aliases,
		"cities": cities,
		"visual_themes": visual_themes,
		"membership_alias_policy": "sovereign_identity_only",
	}

func _population_card_person_matches_realm_scope(
	person,
	realm_id: int,
	scope: Dictionary
) -> bool:
	if person == null or realm_id <= 0:
		return false

	var aliases: Dictionary = (
		scope.get("sovereign_aliases", scope.get("aliases", {}))
		if typeof(
			scope.get(
				"sovereign_aliases",
				scope.get("aliases", {})
			)
		) == TYPE_DICTIONARY
		else {}
	)
	var cities: Dictionary = (
		scope.get("cities", {})
		if typeof(scope.get("cities", {})) == TYPE_DICTIONARY
		else {}
	)



	var current_country_truth_observed: bool = false

	for raw_country_key in [
		"home_country",
		"current_country",
		"country",
		"realm_name",
		"nation"
	]:
		var raw_country_value: String = str(
			_value(person, raw_country_key, "")
		).strip_edges()

		if raw_country_value == "":
			continue

		current_country_truth_observed = true

		var country_key: String = _population_card_match_key(
			raw_country_value
		)

		if country_key != "" and aliases.has(country_key):
			return true




	if current_country_truth_observed:
		return false

	var explicit_realm_id: int = int(
		_value(person, "realm_id", -1)
	)

	if explicit_realm_id > 0:
		return explicit_realm_id == realm_id

	if _population_card_civic_office_matches_realm_scope(
		person,
		realm_id,
		scope
	):
		return true

	var current_city_truth_observed: bool = false

	for raw_city_key in [
		"home_city",
		"current_city",
		"city",
		"settlement",
		"district"
	]:
		var raw_city_value: String = str(
			_value(person, raw_city_key, "")
		).strip_edges()

		if raw_city_value == "":
			continue

		current_city_truth_observed = true

		var city_key: String = _population_card_match_key(
			raw_city_value
		)

		if city_key != "" and cities.has(city_key):
			return true

	if current_city_truth_observed:
		return false



	var birth_country_key: String = _population_card_match_key(
		str(_value(person, "birth_country", ""))
	)

	if birth_country_key != "":
		return aliases.has(birth_country_key)

	var birth_city_key: String = _population_card_match_key(
		str(_value(person, "birth_city", ""))
	)

	if birth_city_key != "":
		return cities.has(birth_city_key)



	return false

func _population_card_add_match_key(target: Dictionary, value: String) -> void:
	var key: String = _population_card_match_key(value)
	if key == "":
		return

	target [key] = true


func _population_card_match_key(value: String) -> String:
	var clean: String = str(value).strip_edges().to_lower()
	if clean == "":
		return ""

	for ch in [
		"\n",
		"\t",
		".",
		",",
		":",
		";",
		"!",
		"?",
		"(",
		")",
		"[",
		"]",
		"{",
		"}",
		"/",
		"\\",
		"|",
		"-",
		"_",
		"•",
		"'",
		"\""
	]:
		clean = clean.replace(ch, " ")

	while clean.find("  ") >= 0:
		clean = clean.replace("  ", " ")

	return clean.strip_edges()


func _visible_entity_ids(groups: Array) -> Dictionary:
	var out: Dictionary = {}

	for raw_group in groups:
		if typeof(raw_group) != TYPE_ARRAY:
			continue

		for raw_person in raw_group as Array:
			var entity_id: String = _entity_id_for_person(raw_person)
			if entity_id != "":
				out [entity_id] = true

	return out


func _is_royal_person(person, realm_id: int) -> bool:
	if person == null:
		return false

	if bool(_value(person, "is_ruler", false)):
		return true

	if _is_realm_ruler_partner_person(person, realm_id):
		return true

	if _population_card_person_has_clear_royal_title(person):
		return true


	if _population_card_person_has_clear_noble_title(person):
		return false


	if _population_card_person_has_clear_citizen_class(person):
		return false

	if _is_direct_royal_child_or_heir(person, realm_id):
		return true

	var social_key: String = str(_value(person, "social_class", "")).strip_edges().to_lower()
	if bool(_value(person, "is_royal", false)) and social_key == "royal":
		return true

	return false
func _is_noble_person(person, realm_id: int) -> bool:
	if person == null:
		return false

	if _is_royal_person(person, realm_id):
		return false

	if _population_card_person_has_clear_noble_title(person):
		return true

	var class_text: String = str(_value(person, "social_class", "")).strip_edges().to_lower()
	if class_text in [
		"noble",
		"nobility",
		"aristocrat",
		"aristocracy",
		"upper nobility",
		"high nobility",
		"high noble",
		"ducal",
		"duke",
		"duchess",
		"marquess",
		"marchioness",
		"marquis",
		"marquise",
		"marquee",
		"earl",
		"count",
		"countess",
		"viscount",
		"viscountess",
		"baron",
		"baroness",
		"lord",
		"lady"
	]:
		return true

	var job_text: String = str(_value(person, "job", "")).strip_edges().to_lower()
	if _population_card_text_has_any(job_text, [
		"noble courtier",
		"court noble"
	]):
		return true

	return false
func _realm_ruler_id(realm_id: int) -> int:
	if gs == null or realm_id <= 0:
		return -1

	var realm_engine = _value(gs, "realm_engine", null)
	if realm_engine != null and "realms" in realm_engine and typeof(realm_engine.realms) == TYPE_DICTIONARY:
		var realm_raw: Variant = realm_engine.realms.get(realm_id, {})
		if typeof(realm_raw) == TYPE_DICTIONARY:
			return int((realm_raw as Dictionary).get("ruler_id", -1))

	return -1


func _person_by_id(person_id: int):
	if gs == null or person_id <= 0:
		return null

	var player = _value(gs, "player", null)
	if player != null and int(_value(player, "id", -1)) == person_id:
		return player

	if "npcs" in gs:
		for raw_npc in gs.npcs:
			if raw_npc == null:
				continue
			if int(_value(raw_npc, "id", -1)) == person_id:
				return raw_npc

	if "dormant_npcs" in gs and typeof(gs.dormant_npcs) == TYPE_DICTIONARY:
		var dormant_raw: Variant = gs.dormant_npcs.get(person_id, gs.dormant_npcs.get(str(person_id), {}))
		if typeof(dormant_raw) == TYPE_DICTIONARY:
			var dormant: Dictionary = dormant_raw
			if int(dormant.get("id", -1)) == person_id:
				return dormant

	return null


func _person_ref_id(raw_ref) -> int:
	if raw_ref == null:
		return -1

	if typeof(raw_ref) == TYPE_INT:
		return int(raw_ref)

	if typeof(raw_ref) == TYPE_FLOAT:
		return int(raw_ref)

	if typeof(raw_ref) == TYPE_STRING:
		return int(str(raw_ref))

	return int(_value(raw_ref, "id", -1))


func _is_realm_ruler_partner_person(person, realm_id: int) -> bool:
	if person == null:
		return false

	var person_id: int = int(_value(person, "id", -1))
	var ruler_id: int = _realm_ruler_id(realm_id)

	if person_id <= 0 or ruler_id <= 0:
		return false

	if person_id == ruler_id:
		return true

	var partner_raw = _value(person, "partner", null)
	if _person_ref_id(partner_raw) == ruler_id:
		return true

	var ruler = _person_by_id(ruler_id)
	if ruler != null and _person_ref_id(_value(ruler, "partner", null)) == person_id:
		return true

	return false


func _is_direct_royal_child_or_heir(person, realm_id: int) -> bool:
	if person == null:
		return false

	if _population_card_person_has_clear_noble_title(person):
		return false

	if _population_card_person_has_clear_citizen_class(person):
		return false

	var succession_rank: int = int(_value(person, "succession_rank", 0))
	var social_key: String = str(_value(person, "social_class", "")).strip_edges().to_lower()
	var has_royal_evidence: bool = bool(_value(person, "is_royal", false)) or social_key == "royal" or _population_card_person_has_clear_royal_title(person)

	if succession_rank > 0 and succession_rank <= 8 and has_royal_evidence:
		return true

	var ruler_id: int = _realm_ruler_id(realm_id)
	if ruler_id <= 0:
		return false

	var parents_raw: Variant = _value(person, "parents", [])
	if typeof(parents_raw) == TYPE_ARRAY:
		for raw_parent in parents_raw as Array:
			if _person_ref_id(raw_parent) == ruler_id and has_royal_evidence:
				return true

	return false
func _population_card_person_title_blob(person) -> String:
	var office_contract_raw: Variant = _value(person, "civic_office_contract", {})
	var office_contract: Dictionary = office_contract_raw if typeof(office_contract_raw) == TYPE_DICTIONARY else {}

	return "%s %s %s %s %s %s %s %s" % [
		str(_value(person, "royal_title", "")),
		str(_value(person, "title", "")),
		str(_value(person, "court_title", "")),
		str(_value(person, "job_title", "")),
		str(_value(person, "job", "")),
		str(_value(person, "civic_title", "")),
		str(office_contract.get("office", "")),
		str(office_contract.get("office_full_title", ""))
	]


func _population_card_text_has_any(text: String, tokens: Array) -> bool:
	var haystack: String = _population_card_normalized_match_text(text)
	if haystack == "":
		return false

	for raw_token in tokens:
		var token: String = _population_card_normalized_match_text(str(raw_token))
		if token == "":
			continue

		if haystack.find(" %s " % token) >= 0:
			return true

	return false
func _population_card_normalized_match_text(text: String) -> String:
	var out: String = str(text).strip_edges().to_lower()
	if out == "":
		return ""

	for ch in [
		"\n",
		"\t",
		".",
		",",
		":",
		";",
		"!",
		"?",
		"(",
		")",
		"[",
		"]",
		"{",
		"}",
		"/",
		"\\",
		"|",
		"-",
		"_",
		"•",
		"'",
		"\""
	]:
		out = out.replace(ch, " ")

	while out.find("  ") >= 0:
		out = out.replace("  ", " ")

	return out.strip_edges()
func _population_card_person_has_prince_or_princess_title(person) -> bool:
	if person == null:
		return false

	var title_text: String = _population_card_person_title_blob(person)

	if _population_card_text_has_any(title_text, [
		"crown prince",
		"crown princess",
		"prince",
		"princess"
	]):
		return true

	for raw_key in [
		"royal_role",
		"royal_rank",
		"dynasty_role",
		"succession_title",
		"lineage_role",
		"family_role",
		"court_role",
		"relationship_to_ruler",
		"relationship_to_monarch",
		"relationship_to_sovereign"
	]:
		var value_text: String = str(_value(person, str(raw_key), "")).strip_edges()
		if value_text == "":
			continue

		if _population_card_text_has_any(value_text, [
			"crown prince",
			"crown princess",
			"prince",
			"princess",
			"son of ruler",
			"daughter of ruler",
			"son of monarch",
			"daughter of monarch",
			"royal son",
			"royal daughter"
		]):
			return true

	return false
func _population_card_person_has_clear_royal_title(person) -> bool:
	var title_text: String = _population_card_person_title_blob(person)

	return _population_card_text_has_any(title_text, [
		"king",
		"queen",
		"prince",
		"princess",
		"emperor",
		"empress",
		"pharaoh",
		"sultan",
		"sultana",
		"monarch",
		"sovereign",
		"crown prince",
		"crown princess",
		"heir apparent",
		"royal heir",
		"fire lord",
		"fire queen",
		"earth king",
		"earth queen",
		"water chief",
		"air monarch"
	])
func _population_card_person_has_clear_noble_title(person) -> bool:
	var title_text: String = _population_card_person_title_blob(person)
	var social_text: String = str(_value(person, "social_class", "")).strip_edges()

	return _population_card_noble_title_from_text(title_text) != "" or _population_card_noble_title_from_text(social_text) != ""
func _population_card_person_has_clear_citizen_class(person) -> bool:
	var social_key: String = str(_value(person, "social_class", "")).strip_edges().to_lower()
	var job_key: String = str(_value(person, "job", "")).strip_edges().to_lower()
	var title_text: String = _population_card_person_title_blob(person)

	if social_key in [
		"peasant",
		"commoner",
		"merchant",
		"trader",
		"artisan",
		"craftsman",
		"shopkeeper",
		"worker",
		"working class",
		"working-class",
		"middle class",
		"middle-class",
		"upper class",
		"upper-class",
		"upper middle class",
		"upper-middle class",
		"bottom class",
		"bottom-class",
		"low class",
		"low-class",
		"lower class",
		"lower-class",
		"lowborn",
		"serf",
		"slave",
		"citizen",
		"civilian",
		"professional",
		"elite",
		"wealthy",
		"rich"
	]:
		return true

	if _population_card_text_has_any(job_key, [
		"farmer",
		"farmhand",
		"laborer",
		"servant",
		"miner",
		"fisher",
		"fisherman",
		"merchant",
		"trader",
		"artisan",
		"shopkeeper",
		"blacksmith",
		"teacher",
		"doctor",
		"lawyer",
		"engineer",
		"manager",
		"accountant",
		"nurse",
		"developer"
	]):
		return true

	if _population_card_text_has_any(title_text, [
		"commoner",
		"peasant",
		"merchant",
		"trader",
		"farmer",
		"teacher",
		"citizen",
		"civilian"
	]):
		return true

	return false
func _is_master_person(person, _realm_id: int, _realm_name: String) -> bool:
	if person == null:
		return false

	var bending_type: String = str(_value(person, "bending_type", "")).strip_edges().to_lower()
	if bending_type == "" or bending_type == "none":
		return false

	var mastery_value: int = 0
	var mastery_raw: Variant = _value(person, "bending_mastery", {})
	if typeof(mastery_raw) == TYPE_DICTIONARY:
		mastery_value = int((mastery_raw as Dictionary).get(bending_type, 0))

	if mastery_value >= 70:
		return true

	var job_text: String = str(_value(person, "job", "")).strip_edges().to_lower()
	if job_text.find("bending") >= 0 or job_text.find("master") >= 0:
		return true

	var traits_raw: Variant = _value(person, "traits", [])
	var traits: Array = []

	if typeof(traits_raw) == TYPE_ARRAY:
		traits = traits_raw as Array
	elif typeof(traits_raw) == TYPE_DICTIONARY:
		var traits_dict: Dictionary = traits_raw as Dictionary
		traits = traits_dict.keys()

	for raw_trait in traits:
		var trait_text: String = str(raw_trait).strip_edges().to_lower()
		if trait_text.find("master") >= 0:
			return true

	return false


func _person_sort_score(person, realm_id: int) -> int:
	if person == null:
		return -999999

	var score: int = 0
	var person_id: int = int(_value(person, "id", -1))

	if int(_value(person, "realm_id", -1)) == realm_id:
		score += 1000

	if bool(_value(person, "is_ruler", false)):
		score += 20000
	elif _is_realm_ruler_partner_person(person, realm_id):
		score += 19800
	elif _is_direct_royal_child_or_heir(person, realm_id):
		score += 18500
	elif _population_card_person_has_clear_noble_title(person):
		score += 11000
	elif _is_master_person(person, realm_id, _realm_name_for_id(realm_id)):
		score += 8500
	else:
		score += 1000

	var succession_rank: int = int(_value(person, "succession_rank", 0))
	if succession_rank > 0:
		score += max(0, 1000 - succession_rank * 25)

	score += int(_value(person, "approval", 0))
	score += int(_value(person, "respect", 0))
	score += int(_value(person, "fame", 0))

	score -= person_id % 100

	return score
func _federal_republic_civic_role_label_for_person(person, realm_id: int = -1) -> String:
	if person == null:
		return ""

	var office_contract_raw: Variant = _value(person, "civic_office_contract", {})
	var office_contract: Dictionary = office_contract_raw if typeof(office_contract_raw) == TYPE_DICTIONARY else {}

	var government_model: String = str(office_contract.get("government_model", "")).strip_edges().to_lower()
	var office_text: String = str(office_contract.get("office", "")).strip_edges()
	var office_full_title: String = str(office_contract.get("office_full_title", "")).strip_edges()
	var civic_title: String = str(_value(person, "civic_title", "")).strip_edges()
	var job_text: String = str(_value(person, "job", "")).strip_edges()
	var job_key: String = job_text.to_lower()

	var federal_contract: bool = government_model in [
		"federal_presidential_republic",
		"federal_republic",
		"presidential_republic",
		"constitutional_republic"
	]

	if not federal_contract and realm_id > 0:
		federal_contract = _is_united_states_federal_realm(realm_id, _realm_name_for_id(realm_id))

	if not federal_contract and not job_key in [
		"president",
		"president of the united states",
		"first lady",
		"first gentleman",
		"vice president"
	]:
		return ""

	if office_text == "President" or civic_title == "President" or job_key == "president of the united states":
		return "President"

	if office_text in ["First Lady", "First Gentleman", "Vice President"]:
		return office_text

	if civic_title in ["First Lady", "First Gentleman", "Vice President"]:
		return civic_title

	if office_full_title != "":
		if office_full_title.begins_with("The "):
			office_full_title = office_full_title.substr(4).strip_edges()
		if office_full_title == "President of the United States":
			return "President"
		return office_full_title

	if civic_title != "":
		return civic_title

	if job_text != "":
		if job_key == "president of the united states":
			return "President"
		return job_text

	return ""
func _population_card_modern_citizen_role_label_for_person(person, realm_id: int, realm_name: String = "") -> String:
	if person == null:
		return "Citizen"

	if not _is_united_states_federal_realm(realm_id, realm_name):
		return ""

	var social_key: String = str(_value(person, "social_class", "")).strip_edges().to_lower()
	var job_text: String = str(_value(person, "job", "")).strip_edges()

	if social_key in ["elite", "ultra elite", "ruling elite", "old money", "billionaire", "one percent", "1%", "rich"]:
		return "Upper-Class Citizen"

	if social_key in ["upper middle class", "upper-middle class", "upper class", "upperclass", "wealthy"]:
		return "Upper-Middle Citizen"

	if social_key in ["middle class", "middle-class", "professional"]:
		return "Middle-Class Citizen"

	if social_key in ["lower middle class", "lower-middle class", "working class", "working-class", "commoner", "merchant", "trader", "worker"]:
		if job_text != "":
			return job_text
		return "Working-Class Citizen"

	if social_key in ["poor", "lower class", "low class", "bottom class", "bottom-class", "struggling"]:
		return "Bottom-Class Citizen"

	if job_text != "":
		return job_text

	return "Citizen"
func _role_label_for_person(person, realm_id: int, category: String) -> String:
	if person == null:
		return "Resident"

	var clean_category: String = str(category).strip_edges().to_lower()
	var federal_role: String = _federal_republic_civic_role_label_for_person(person, realm_id)

	if federal_role != "" and clean_category in [
		"federal_executive",
		"federal_cabinet",
		"federal_senate",
		"federal_supreme_court",
		"federal_governor",
		"royal"
	]:
		return federal_role

	var royal_title_text: String = str(_value(person, "royal_title", "")).strip_edges()
	var title_text: String = str(_value(person, "title", "")).strip_edges()
	var court_title_text: String = str(_value(person, "court_title", "")).strip_edges()
	var job_text: String = str(_value(person, "job", "")).strip_edges()
	var class_text: String = str(_value(person, "social_class", "")).strip_edges()

	match clean_category:
		"federal_executive":
			if federal_role != "":
				return federal_role
			if job_text != "":
				return job_text
			return "Executive Branch"

		"federal_cabinet":
			if federal_role != "":
				return federal_role
			if job_text != "":
				return job_text
			return "Cabinet Official"

		"federal_senate":
			if federal_role != "":
				return federal_role
			return "Senator"

		"federal_supreme_court":
			if federal_role != "":
				return federal_role
			return "Supreme Court Justice"

		"federal_governor":
			if federal_role != "":
				return federal_role
			return "State Governor"

		"royal":
			if royal_title_text != "":
				return royal_title_text
			if _population_card_text_has_any(title_text, [
				"crown prince",
				"crown princess",
				"prince",
				"princess"
			]):
				return title_text
			if _population_card_text_has_any(court_title_text, [
				"crown prince",
				"crown princess",
				"prince",
				"princess"
			]):
				return court_title_text
			if bool(_value(person, "is_ruler", false)):
				return "Ruler"
			if int(_value(person, "succession_rank", 0)) == 1:
				return "Heir"
			if title_text != "" and _population_card_person_has_clear_royal_title(person):
				return title_text
			if court_title_text != "" and _population_card_person_has_clear_royal_title(person):
				return court_title_text
			return "Royal"

		"noble":
			return _population_card_noble_title_for_person(person, realm_id)

		"master":
			var bending_type: String = str(_value(person, "bending_type", "")).strip_edges().capitalize()
			return "%s Master" % bending_type if bending_type != "" else "Master"

		_:
			if clean_category == "citizen":
				var modern_citizen_label: String = _population_card_modern_citizen_role_label_for_person(person, realm_id, _realm_name_for_id(realm_id))
				if modern_citizen_label != "":
					return modern_citizen_label

			if job_text != "":
				return job_text

			if class_text != "":
				var class_key: String = class_text.strip_edges().to_lower()
				if _is_united_states_federal_realm(realm_id, _realm_name_for_id(realm_id)) and class_key in ["commoner", "peasant", "merchant"]:
					return "Citizen"
				return class_text

			return "Citizen"
func _population_card_noble_title_for_person(person, realm_id: int) -> String:
	if person == null:
		return "Noble"

	var explicit_title: String = _population_card_noble_title_from_text(_population_card_person_title_blob(person))
	if explicit_title != "":
		return explicit_title

	var social_title: String = _population_card_noble_title_from_text(str(_value(person, "social_class", "")))
	if social_title != "":
		return social_title

	var gender_key: String = str(_value(person, "gender", "")).strip_edges().to_lower()
	var score: int = _population_card_noble_candidate_score(person, realm_id, _realm_name_for_id(realm_id))

	if score >= 1850:
		return "High Noble"

	if score >= 1450:
		return "Countess" if gender_key == "female" else "Count"

	if score >= 1180:
		return "Lady" if gender_key == "female" else "Lord"

	if score >= 980:
		return "Duchess" if gender_key == "female" else "Duke"

	if score >= 820:
		return "Viscountess" if gender_key == "female" else "Viscount"

	if score >= 660:
		return "Marchioness" if gender_key == "female" else "Marquess"

	return "Baroness" if gender_key == "female" else "Baron"


func _population_card_noble_title_from_text(text: String) -> String:
	if _population_card_text_has_any(text, ["high noble", "upper nobility", "high nobility", "aristocracy", "aristocrat"]):
		return "High Noble"

	if _population_card_text_has_any(text, ["countess"]):
		return "Countess"

	if _population_card_text_has_any(text, ["count"]):
		return "Count"

	if _population_card_text_has_any(text, ["lady"]):
		return "Lady"

	if _population_card_text_has_any(text, ["lord"]):
		return "Lord"

	if _population_card_text_has_any(text, ["duchess"]):
		return "Duchess"

	if _population_card_text_has_any(text, ["duke", "ducal", "archduke"]):
		return "Duke"

	if _population_card_text_has_any(text, ["viscountess"]):
		return "Viscountess"

	if _population_card_text_has_any(text, ["viscount"]):
		return "Viscount"

	if _population_card_text_has_any(text, ["marchioness"]):
		return "Marchioness"

	if _population_card_text_has_any(text, ["marquess", "marquis", "marquise", "marquee"]):
		return "Marquess"

	if _population_card_text_has_any(text, ["baroness"]):
		return "Baroness"

	if _population_card_text_has_any(text, ["baron"]):
		return "Baron"

	if _population_card_text_has_any(text, ["noble", "nobility"]):
		return "High Noble"

	return ""


func _population_card_noble_title_weight(title: String) -> int:
	match str(title).strip_edges().to_lower():
		"high noble":
			return 9000
		"count", "countess":
			return 8000
		"lord", "lady":
			return 7000
		"duke", "duchess":
			return 6000
		"viscount", "viscountess":
			return 5000
		"marquess", "marchioness":
			return 4000
		"baron", "baroness":
			return 3000
		_:
			return 1000


func _stat_rows_for_person(person, _realm_id: int, _category: String) -> Array:
	var fame_value: float = float(_value(person, "fame", 0))
	var respect_value: float = float(_value(person, "respect", 0))
	var influence_value: int = clampi(int(round((fame_value + respect_value) / 2.0)), 0, 100)

	return [
		{
			"label": "Health",
			"value": clampi(int(round(float(_value(person, "health", 100)))), 0, 100)
		},
		{
			"label": "Hunger",
			"value": clampi(int(round(float(_value(person, "hunger", 100)))), 0, 100)
		},
		{
			"label": "Mental",
			"value": clampi(int(round(float(_value(person, "mental_health", 100)))), 0, 100)
		},
		{
			"label": "Smarts",
			"value": clampi(int(round(float(_value(person, "smarts", 50)))), 0, 100)
		},
		{
			"label": "Looks",
			"value": clampi(int(round(float(_value(person, "looks", 50)))), 0, 100)
		},
		{
			"label": "Influence",
			"value": influence_value
		}
	]


func _relationship_preview_rows_for_person(person) -> Array:
	var rows: Array = []

	var parents_raw: Variant = _value(person, "parents", [])
	if typeof(parents_raw) == TYPE_ARRAY and not (parents_raw as Array).is_empty():
		rows.append({
			"label": "Parents",
			"count": (parents_raw as Array).size(),
			"line_kind": "family"
		})

	var children_raw: Variant = _value(person, "children", [])
	if typeof(children_raw) == TYPE_ARRAY and not (children_raw as Array).is_empty():
		rows.append({
			"label": "Children",
			"count": (children_raw as Array).size(),
			"line_kind": "family"
		})

	var friends_raw: Variant = _value(person, "friends", [])
	if typeof(friends_raw) == TYPE_ARRAY and not (friends_raw as Array).is_empty():
		rows.append({
			"label": "Friends",
			"count": (friends_raw as Array).size(),
			"line_kind": "social"
		})

	if _value(person, "partner", null) != null:
		rows.append({
			"label": "Partner",
			"count": 1,
			"line_kind": "romance"
		})

	return rows


func _line_kind_from_edge(edge: Dictionary) -> String:
	var line_kind: String = str(edge.get("line_kind", "relationship")).strip_edges().to_lower()
	if line_kind != "" and line_kind != "relationship":
		return line_kind

	var tags: Array = edge.get("tags", []) if typeof(edge.get("tags", [])) == TYPE_ARRAY else []
	var label: String = str(edge.get("relationship_label", edge.get("label", ""))).strip_edges().to_lower()

	if _tags_have_any(tags, ["parent", "child", "sibling", "family"]) or label in ["parent", "child", "sibling", "mother", "father", "son", "daughter"]:
		return "family"
	if _tags_have_any(tags, ["spouse", "partner", "romance", "married", "dating"]) or label in ["spouse", "partner", "wife", "husband"]:
		return "romance"
	if _tags_have_any(tags, ["succession_heir", "heir", "line_of_succession"]):
		return "succession_heir"
	if _tags_have_any(tags, ["enemy", "rival", "conflict"]):
		return "conflict"
	if _tags_have_any(tags, ["political", "royal", "court", "noble", "realm"]):
		return "political"
	if _tags_have_any(tags, ["house", "dynasty", "bloodline"]):
		return "house"
	if _tags_have_any(tags, ["friend", "ally", "social"]):
		return "social"
	if _tags_have_any(tags, ["coworker", "market", "economic", "trade"]):
		return "economic"
	if _tags_have_any(tags, ["civic", "countryfolk", "same_city", "class_tie"]):
		return "civic"

	return "relationship"


func _importance_weight_for_edge(edge: Dictionary, line_kind: String) -> float:
	var tags: Array = edge.get("tags", []) if typeof(edge.get("tags", [])) == TYPE_ARRAY else []
	var label: String = str(edge.get("relationship_label", edge.get("label", ""))).strip_edges().to_lower()

	if line_kind == "succession_heir":
		return 1.0
	if line_kind == "family" and (_tags_have_any(tags, ["parent", "child"]) or label in ["parent", "child", "mother", "father", "son", "daughter"]):
		return 0.97
	if line_kind == "romance":
		return 0.92
	if line_kind == "family":
		return 0.88
	if line_kind == "conflict":
		return 0.84
	if line_kind == "political":
		return 0.76
	if line_kind == "house":
		return 0.7
	if line_kind == "economic":
		return 0.58
	if line_kind == "social":
		return 0.46
	if line_kind == "civic":
		return 0.34

	return 0.22


func _line_weight_from_bond_and_kind(bond: int, line_kind: String, importance: float) -> float:
	var width: float = 1.15 + (float(clampi(bond, 0, 100)) / 28.0) + (importance * 0.85)

	match line_kind:
		"succession_heir":
			width += 1.2
		"family":
			width += 0.82
		"romance":
			width += 0.58
		"conflict":
			width += 0.75
		"political":
			width += 0.45
		"house":
			width += 0.35
		"economic":
			width += 0.25
		"civic":
			width -= 0.2
		_:
			pass

	return clampf(width, 1.35, 7.25)


func _lod_score_for_edge(bond: int, weight: float, importance: float) -> float:
	return float(bond) + (importance * 75.0) + (weight * 8.0)


func _default_card_layout_policy() -> Dictionary:
	return {
		"anchor_points": ["LEFT", "RIGHT", "TOP", "BOTTOM"],
		"hover_unconnected_nodes_fade_alpha": 0.4,
	}


func _default_graph_projection_policy() -> Dictionary:
	return {
		"curve_mode": "cubic_bezier",
		"line_weight_represents_bond": true,
		"gradient_slide_enabled": true,
		"pulse_travel_enabled": true,
	}


func _default_lod_policy() -> Dictionary:
	return {
		"hover_max_edges": 5,
		"expanded_max_edges": 9999,
		"default_many_connection_max_edges": 5,
		"ready_door_may_not_wait": true,
	}

func _card_min_size_for_person(person, realm_id: int, realm_name: String, category: String) -> Vector2:
	var clean_category: String = str(category).strip_edges().to_lower()

	if clean_category == "royal":
		if _is_realm_ruler_partner_person(person, realm_id):
			return Vector2(226, 176)
		return Vector2(210, 158)

	if clean_category == "noble":
		return Vector2(194, 150)

	if clean_category == "master":
		return Vector2(186, 146)
	if clean_category == "federal_executive":
		return Vector2(226, 176)

	if clean_category == "federal_cabinet":
		return Vector2(194, 150)

	if clean_category == "federal_senate":
		return Vector2(178, 138)

	if clean_category == "federal_supreme_court":
		return Vector2(190, 148)

	if clean_category == "federal_governor":
		return Vector2(174, 136)
	if _population_card_is_lowest_citizen_stratum(person, realm_id, realm_name):
		return Vector2(146, 118)

	return Vector2(172, 138)


func _card_size_class_for_person(person, realm_id: int, realm_name: String, category: String) -> String:
	var clean_category: String = str(category).strip_edges().to_lower()

	if clean_category == "royal":
		if _is_realm_ruler_partner_person(person, realm_id):
			return "royal_pair_hero"
		return "royal_large"

	if clean_category == "noble":
		return "noble_medium_large"

	if clean_category == "master":
		return "master_medium"
	if clean_category == "federal_executive":
		return "federal_executive_hero"

	if clean_category == "federal_cabinet":
		return "federal_cabinet_medium_large"

	if clean_category == "federal_senate":
		return "federal_senate_standard"

	if clean_category == "federal_supreme_court":
		return "federal_judicial_medium"

	if clean_category == "federal_governor":
		return "federal_governor_standard"
	if _population_card_is_lowest_citizen_stratum(person, realm_id, realm_name):
		return "citizen_mini"

	return "citizen_standard"


func _population_card_is_lowest_citizen_stratum(person, _realm_id: int, _realm_name: String = "") -> bool:
	if person == null:
		return false

	var social_key: String = str(_value(person, "social_class", "")).strip_edges().to_lower()
	var job_key: String = str(_value(person, "job", "")).strip_edges().to_lower()

	if social_key in [
		"peasant",
		"bottom class",
		"bottom-class",
		"low class",
		"low-class",
		"lower class",
		"lower-class",
		"lowborn",
		"serf",
		"slave"
	]:
		return true

	for token in [
		"farmer",
		"farmhand",
		"laborer",
		"servant",
		"miner",
		"fisher",
		"fisherman",
		"maid"
	]:
		if job_key.find(token) >= 0:
			return true

	return false
func _card_min_size_for_category(category: String) -> Vector2:
	match str(category).strip_edges().to_lower():
		"royal":
			return Vector2(210, 158)
		"noble":
			return Vector2(196, 152)
		"master":
			return Vector2(186, 146)
		_:
			return Vector2(172, 138)


func _section_kind_for_category(category: String) -> String:
	match str(category).strip_edges().to_lower():
		"royal":
			return "official"
		"noble":
			return "noble"
		"master":
			return "master"
		"federal_executive":
			return "federal_executive"
		"federal_cabinet":
			return "federal_cabinet"
		"federal_senate":
			return "federal_senate"
		"federal_supreme_court":
			return "federal_supreme_court"
		"federal_governor":
			return "federal_governor"
		_:
			return "citizen"
func _accent_key_for_category(category: String, person = null) -> String:
	var clean_category: String = str(category).strip_edges().to_lower()

	if person != null and bool(_value(person, "is_ruler", false)) and clean_category == "royal":
		return "royal_gold"

	match clean_category:
		"royal":
			return "royal_gold"
		"noble":
			return "noble_violet"
		"master":
			return "elemental_master"
		"federal_executive":
			return "federal_blue_gold"
		"federal_cabinet":
			return "federal_blue"
		"federal_senate":
			return "senate_blue"
		"federal_supreme_court":
			return "judicial_purple"
		"federal_governor":
			return "state_green"
		_:
			return "citizen_realm"


func _color_key_for_line_kind(line_kind: String) -> String:
	match str(line_kind).strip_edges().to_lower():
		"succession_heir":
			return "succession_gold"
		"romance":
			return "romance_pink"
		"family":
			return "family_blue"
		"house":
			return "house_violet"
		"political":
			return "political_gold"
		"economic":
			return "economic_green"
		"conflict":
			return "conflict_red"
		"civic":
			return "civic_tan"
		"social":
			return "social_sky"
		_:
			return "relationship_default"
func _population_card_modern_citizen_strata_key(person, realm_id: int, realm_name: String = "") -> String:
	if person == null:
		return "lower_middle_class"

	if not _is_united_states_federal_realm(realm_id, realm_name):
		return "legacy"

	var social_key: String = str(_value(person, "social_class", "")).strip_edges().to_lower()
	var job_key: String = str(_value(person, "job", "")).strip_edges().to_lower()
	var bank_value: int = int(_value(person, "bank_balance", 0))
	var fame_value: int = int(_value(person, "fame", 0))

	if social_key in ["elite", "ultra elite", "ruling elite", "old money", "billionaire", "one percent", "1%", "rich"] or bank_value >= 10000000 or fame_value >= 90:
		return "elite"

	if social_key in ["upper middle class", "upper-middle class", "upper class", "upperclass", "wealthy"] or bank_value >= 1000000:
		return "upper_middle_class"

	if social_key in ["middle class", "middle-class", "professional"] or job_key in ["teacher", "doctor", "lawyer", "engineer", "manager", "accountant", "nurse", "developer"]:
		return "middle_class"

	if social_key in ["poor", "lower class", "low class", "bottom class", "bottom-class", "struggling"] or bank_value < 25000:
		return "bottom_class"

	return "lower_middle_class"
func _population_card_person_excluded_from_citizen_wall(person, realm_id: int, realm_name: String = "") -> bool:
	if person == null:
		return true

	if not bool(_value(person, "alive", true)):
		return true

	var contract_raw: Variant = _value(person, "civic_office_contract", {})
	if typeof(contract_raw) == TYPE_DICTIONARY:
		var contract: Dictionary = contract_raw
		var government_model: String = str(contract.get("government_model", "")).strip_edges().to_lower()
		var branch: String = str(contract.get("branch", "")).strip_edges().to_lower()
		if government_model == "federal_presidential_republic" and branch != "":
			return true

	var job_key: String = str(_value(person, "job", "")).strip_edges().to_lower()
	var civic_title_key: String = str(_value(person, "civic_title", "")).strip_edges().to_lower()
	var title_blob: String = _population_card_person_title_blob(person)

	if _is_united_states_federal_realm(realm_id, realm_name):
		if _population_card_text_has_any(job_key, [
			"president",
			"vice president",
			"secretary of",
			"attorney general",
			"senator",
			"supreme court justice",
			"chief justice",
			"governor of"
		]):
			return true

		if _population_card_text_has_any(civic_title_key, [
			"president",
			"vice president",
			"secretary of",
			"attorney general",
			"senator",
			"supreme court justice",
			"chief justice",
			"governor of"
		]):
			return true

		if _population_card_text_has_any(title_blob, [
			"president",
			"vice president",
			"secretary of",
			"attorney general",
			"senator",
			"supreme court justice",
			"chief justice",
			"governor of"
		]):
			return true

	if not _population_card_realm_is_elemental_context(realm_id, realm_name):
		if _population_card_text_has_any(job_key, [
			"bending master",
			"firebending",
			"waterbending",
			"earthbending",
			"airbending",
			"fire lord",
			"earth king"
		]):
			return true

		if _population_card_text_has_any(title_blob, [
			"bending master",
			"firebending",
			"waterbending",
			"earthbending",
			"airbending",
			"fire lord",
			"earth king"
		]):
			return true

	return false


func _population_card_realm_is_elemental_context(realm_id: int, realm_name: String = "") -> bool:
	var key: String = str(realm_name).strip_edges().to_lower()

	if key.find("fire nation") >= 0:
		return true
	if key.find("earth kingdom") >= 0:
		return true
	if key.find("water tribe") >= 0:
		return true
	if key.find("air temple") >= 0:
		return true
	if key.find("air nomad") >= 0:
		return true
	if key.find("republic city") >= 0:
		return true

	if gs != null and gs.realm_engine != null and "realms" in gs.realm_engine and typeof(gs.realm_engine.realms) == TYPE_DICTIONARY:
		var realm_raw: Variant = gs.realm_engine.realms.get(realm_id, {})
		if typeof(realm_raw) == TYPE_DICTIONARY:
			var realm: Dictionary = realm_raw
			var native_element: String = str(realm.get("native_element", "")).strip_edges().to_lower()
			if native_element in ["fire", "water", "earth", "air"]:
				return true

			var realm_type: String = str(realm.get("realm_type", "")).strip_edges().to_lower()
			if realm_type.find("elemental") >= 0:
				return true

	return false
func _select_citizen_wall_population(people: Array, limit: int, realm_id: int, realm_name: String = "") -> Array:
	var safe_limit: int = maxi(1, limit)
	if typeof(people) != TYPE_ARRAY:
		return []

	var modern_lens: bool = _is_united_states_federal_realm(realm_id, realm_name)

	if modern_lens:
		var strata: Dictionary = {
			"bottom_class": [],
			"lower_middle_class": [],
			"middle_class": [],
			"upper_middle_class": [],
			"elite": []
		}

		for raw_person in people:
			if raw_person == null:
				continue
			if not bool(_value(raw_person, "alive", true)):
				continue

			if _population_card_person_excluded_from_citizen_wall(raw_person, realm_id, realm_name):
				continue

			var strata_key: String = _population_card_modern_citizen_strata_key(raw_person, realm_id, realm_name)
			if not strata.has(strata_key):
				strata_key = "lower_middle_class"

			var bucket: Array = strata.get(strata_key, [])
			bucket.append(raw_person)
			strata [strata_key] = bucket
		for key in strata.keys():
			var bucket_to_sort: Array = strata.get(key, [])
			bucket_to_sort.sort_custom(func (a, b):
				return _population_card_citizen_wall_sort_score(a, realm_id, realm_name) > _population_card_citizen_wall_sort_score(b, realm_id, realm_name)
			)
			strata [key] = bucket_to_sort

		var modern_out: Array = []
		var modern_seen: Dictionary = {}

		var target_by_strata: Dictionary = {
			"bottom_class": maxi(6, int(round(float(safe_limit) * 0.12))),
			"lower_middle_class": maxi(10, int(round(float(safe_limit) * 0.24))),
			"middle_class": maxi(10, int(round(float(safe_limit) * 0.26))),
			"upper_middle_class": maxi(8, int(round(float(safe_limit) * 0.22))),
			"elite": maxi(4, int(round(float(safe_limit) * 0.1)))
		}

		for key in ["bottom_class", "lower_middle_class", "middle_class", "upper_middle_class", "elite"]:
			_population_card_take_from_bucket(
				modern_out,
				modern_seen,
				strata.get(key, []),
				int(target_by_strata.get(key, 0)),
				safe_limit
			)

		if modern_out.size() < safe_limit:
			for key in ["middle_class", "lower_middle_class", "upper_middle_class", "bottom_class", "elite"]:
				if modern_out.size() >= safe_limit:
					break

				_population_card_take_from_bucket(
					modern_out,
					modern_seen,
					strata.get(key, []),
					safe_limit - modern_out.size(),
					safe_limit
				)

		modern_out.sort_custom(func (a, b):
			return _population_card_citizen_wall_sort_score(a, realm_id, realm_name) > _population_card_citizen_wall_sort_score(b, realm_id, realm_name)
		)

		return modern_out

	var children: Array = []
	var teenagers: Array = []
	var young_adults: Array = []
	var adults: Array = []
	var elders: Array = []

	for raw_person in people:
		if raw_person == null:
			continue
		if not bool(_value(raw_person, "alive", true)):
			continue

		var age: int = int(_value(raw_person, "age", 0))

		if age < 13:
			children.append(raw_person)
		elif age <= 19:
			teenagers.append(raw_person)
		elif age <= 29:
			young_adults.append(raw_person)
		elif age <= 64:
			adults.append(raw_person)
		else:
			elders.append(raw_person)

	children.sort_custom(func (a, b):
		return _population_card_citizen_wall_sort_score(a, realm_id, realm_name) > _population_card_citizen_wall_sort_score(b, realm_id, realm_name)
	)

	teenagers.sort_custom(func (a, b):
		return _population_card_citizen_wall_sort_score(a, realm_id, realm_name) > _population_card_citizen_wall_sort_score(b, realm_id, realm_name)
	)

	young_adults.sort_custom(func (a, b):
		return _population_card_citizen_wall_sort_score(a, realm_id, realm_name) > _population_card_citizen_wall_sort_score(b, realm_id, realm_name)
	)

	adults.sort_custom(func (a, b):
		return _population_card_citizen_wall_sort_score(a, realm_id, realm_name) > _population_card_citizen_wall_sort_score(b, realm_id, realm_name)
	)

	elders.sort_custom(func (a, b):
		return _population_card_citizen_wall_sort_score(a, realm_id, realm_name) > _population_card_citizen_wall_sort_score(b, realm_id, realm_name)
	)

	var out: Array = []
	var seen: Dictionary = {}

	var teen_target: int = maxi(4, int(round(float(safe_limit) * 0.12)))
	var child_target: int = maxi(4, int(round(float(safe_limit) * 0.1)))
	var young_adult_target: int = maxi(8, int(round(float(safe_limit) * 0.18)))
	var elder_target: int = maxi(5, int(round(float(safe_limit) * 0.08)))

	_population_card_take_from_bucket(out, seen, teenagers, teen_target, safe_limit)
	_population_card_take_from_bucket(out, seen, children, child_target, safe_limit)
	_population_card_take_from_bucket(out, seen, young_adults, young_adult_target, safe_limit)
	_population_card_take_from_bucket(out, seen, elders, elder_target, safe_limit)

	if out.size() < safe_limit:
		_population_card_take_from_bucket(out, seen, adults, safe_limit - out.size(), safe_limit)

	if out.size() < safe_limit:
		_population_card_take_from_bucket(out, seen, teenagers, safe_limit - out.size(), safe_limit)

	if out.size() < safe_limit:
		_population_card_take_from_bucket(out, seen, young_adults, safe_limit - out.size(), safe_limit)

	if out.size() < safe_limit:
		_population_card_take_from_bucket(out, seen, children, safe_limit - out.size(), safe_limit)

	if out.size() < safe_limit:
		_population_card_take_from_bucket(out, seen, elders, safe_limit - out.size(), safe_limit)

	out.sort_custom(func (a, b):
		return _population_card_citizen_wall_sort_score(a, realm_id, realm_name) > _population_card_citizen_wall_sort_score(b, realm_id, realm_name)
	)

	return out


func _population_card_take_from_bucket(out: Array, seen: Dictionary, bucket: Array, amount: int, max_total: int = 0) -> void:
	if amount <= 0:
		return

	var taken: int = 0

	for raw_person in bucket:
		if taken >= amount:
			break

		if max_total > 0 and out.size() >= max_total:
			break

		var person_id: int = int(_value(raw_person, "id", -1))
		if person_id <= 0:
			continue
		if seen.has(person_id):
			continue

		out.append(raw_person)
		seen [person_id] = true
		taken += 1


func _limit_people(people: Array, limit: int) -> Array:
	var safe_limit: int = maxi(1, limit)
	if people.size() <= safe_limit:
		return people.duplicate()
	return people.slice(0, safe_limit)

func _entity_id_for_person(person) -> String:
	var person_id: int = int(_value(person, "id", -1))
	if person_id <= 0:
		return ""
	return "human:%d" % person_id


func _display_name(person) -> String:
	var first_name: String = str(_value(person, "first_name", "")).strip_edges()
	var last_name: String = str(_value(person, "last_name", "")).strip_edges()
	var full_name: String = "%s %s" % [first_name, last_name]
	full_name = full_name.strip_edges()
	if full_name != "":
		return full_name
	return "Person %d" % int(_value(person, "id", -1))


func _is_player(person) -> bool:
	if gs == null or _value(gs, "player", null) == null or person == null:
		return false
	return int(_value(person, "id", -1)) == int(_value(_value(gs, "player", null), "id", -2))


func _realm_name_for_id(realm_id: int) -> String:
	if gs == null or realm_id <= 0:
		return ""

	var realm_engine = _value(gs, "realm_engine", null)
	if realm_engine != null and "realms" in realm_engine and typeof(realm_engine.realms) == TYPE_DICTIONARY:
		var realm_raw: Variant = realm_engine.realms.get(realm_id, {})
		if typeof(realm_raw) == TYPE_DICTIONARY:
			var realm: Dictionary = realm_raw
			var name: String = str(realm.get("name", realm.get("country", ""))).strip_edges()
			if name != "":
				return name

	return "Realm %d" % realm_id


func _realm_element_for_name(realm_name: String) -> String:
	var clean_name: String = str(realm_name).strip_edges()
	if clean_name == "":
		return ""

	var realm_engine = _value(gs, "realm_engine", null)
	if realm_engine != null and realm_engine.has_method("_realm_element_for_name"):
		return str(realm_engine._realm_element_for_name(clean_name)).strip_edges().to_lower()

	return ""


func _register_aliases_for_packet(key: String, packet: Dictionary, options: Dictionary = {}) -> void:
	_register_alias_for_key(key, str(packet.get("realm_name", "")))
	_register_alias_for_key(key, str(packet.get("realm_id", "")))

	var aliases_raw: Variant = options.get("surface_aliases", options.get("population_lens_aliases", []))
	if typeof(aliases_raw) == TYPE_ARRAY:
		for raw_alias in aliases_raw as Array:
			_register_alias_for_key(key, str(raw_alias))


func _register_alias_for_key(key: String, alias_value: String) -> void:
	var clean: String = str(alias_value).strip_edges()
	if clean == "":
		return

	alias_to_realm_key [_alias_key(clean)] = key


func _resolve_realm_key(realm_id: int, realm_name: String = "") -> String:
	var direct_key: String = _realm_key(realm_id)
	if packets_by_realm.has(direct_key):
		return direct_key

	var alias_key: String = _alias_key(realm_name)
	if alias_key != "" and alias_to_realm_key.has(alias_key):
		return str(alias_to_realm_key.get(alias_key, ""))

	return ""


func _realm_key(realm_id: int) -> String:
	return "realm:%d" % int(realm_id)


func _alias_key(value: String) -> String:
	var cleaned: String = str(value).strip_edges().to_lower()
	for ch in [" ", "_", "-", "•", ".", ",", "'", "\"", ":", ";", "/", "\\", "(", ")"]:
		cleaned = cleaned.replace(ch, "")
	if cleaned == "":
		return ""
	return "alias:%s" % cleaned


func _tags_have_any(tags: Array, wanted: Array) -> bool:
	for raw_tag in tags:
		var tag: String = str(raw_tag).strip_edges().to_lower()
		if wanted.has(tag):
			return true
	return false


func _value(source, key: String, fallback = null):
	if source == null:
		return fallback

	if typeof(source) == TYPE_DICTIONARY:
		return (source as Dictionary).get(key, fallback)

	if key in source:
		return source.get(key)

	return fallback


func _subscribe_to_game_state() -> void:
	if game_state_subscription_ready:
		return
	if gs == null:
		return
	if not ("event_bus" in gs):
		return
	if gs.event_bus == null:
		return
	if not gs.event_bus.has_method("subscribe"):
		return

	for raw_event_name in [
		"npc_born",
		"npc_died",
		"npc_moved",
		"year_passed",
		"era_shift",
		"population.year.tick",
		"population.shard.spawn_entity",
		"many_realms_realm_created",
		"many_realms_succession"
	]:
		var event_name: String = str(raw_event_name).strip_edges()
		if event_name == "":
			continue

		gs.event_bus.subscribe(event_name, self, "_on_population_truth_changed", {
			"allow_defer": true,
			"force_immediate": false,
			"lane": "population_card_contract_engine",
			"subscription_id": "population_card_contract_engine:%s" % event_name,
			"subscription_priority": 24,
			"replay_on_subscribe": false
		})

	game_state_subscription_ready = true

	if typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["population_card_contract_engine_subscribed_to_game_state"] = true
		gs.scenario_state ["population_card_contract_engine_subscribed_at_ms"] = int(Time.get_ticks_msec())


func _on_population_truth_changed(payload: Dictionary = {}) -> void:
	var realm_id: int = int(payload.get("realm_id", payload.get("target_realm_id", -1)))
	if realm_id > 0:
		mark_realm_dirty(realm_id, str(payload.get("event_name", "population_truth_changed")))
	else:
		for raw_key in packets_by_realm.keys():
			var packet_raw: Variant = packets_by_realm.get(raw_key, {})
			if typeof(packet_raw) != TYPE_DICTIONARY:
				continue

			var packet: Dictionary = packet_raw
			var packet_realm_id: int = int(packet.get("realm_id", -1))
			if packet_realm_id > 0:
				mark_realm_dirty(packet_realm_id, "population_truth_changed_unknown_realm")


func _commit_registry() -> void:
	if gs == null:
		return

	if typeof(
		gs.scenario_state
	) != TYPE_DICTIONARY:
		gs.scenario_state = {}




	var published_registry: Dictionary = {
		"schema": ENGINE_SCHEMA,
		"version": CONTRACT_VERSION,
		"packets_by_realm": (
			packets_by_realm.duplicate(false)
		),
		"alias_to_realm_key": (
			alias_to_realm_key.duplicate(false)
		),
		"dirty_realm_ids": (
			dirty_realm_ids.duplicate(false)
		),
		"last_build_report": (
			last_build_report.duplicate(false)
		),
		"registry_count": packets_by_realm.size(),
		"ready_door_may_not_wait": true,
		"ui_is_renderer_only": true
	}

	gs.scenario_state [
		"population_card_contract_engine_registry"
	] = published_registry
	gs.scenario_state [
		"population_lens_card_graph_registry"
	] = packets_by_realm.duplicate(false)
	gs.scenario_state [
		"population_card_contract_engine_registry_count"
	] = packets_by_realm.size()
	gs.scenario_state [
		"population_card_contract_engine_hot"
	] = (
		packets_by_realm.size() > 0
	)
	gs.scenario_state [
		"population_cards_are_contract_artifacts"
	] = true
	gs.scenario_state [
		"population_cards_are_global_nodes"
	] = true
	gs.scenario_state [
		"population_edges_are_node_edge_contracts"
	] = true
	gs.scenario_state [
		"population_cards_are_not_ready_door_latch"
	] = true
	gs.scenario_state [
		"ready_door_latch_does_not_wait_for_population_cards"
	] = true
	gs.scenario_state [
		"population_card_registry_recursive_copy_forbidden"
	] = true
	gs.scenario_state [
		"population_card_contract_engine_global_node_bridge_hot"
	] = (
		"global_node_contract_engine" in gs
		and gs.global_node_contract_engine != null
	)
func _population_renderer_row_identity(
	raw_row: Variant
) -> String:
	if raw_row is Person:
		return "person:%d" % int(
			(raw_row as Person).id
		)

	if typeof(raw_row) == TYPE_DICTIONARY:
		var row: Dictionary = (
			raw_row as Dictionary
		)

		for raw_key in [
			"entity_id",
			"node_id",
			"person_id",
			"actor_id",
			"id",
			"contract_id"
		]:
			var candidate: String = str(
				row.get(
					str(raw_key),
					""
				)
			).strip_edges()

			if candidate != "":
				return "%s:%s" % [
					str(raw_key),
					candidate
				]

	return "row:%s" % str(
		hash(
			raw_row
		)
	)


func _population_renderer_delta_from_packets(
		previous_packet: Dictionary,
		current_packet: Dictionary
) -> Dictionary:
		var category_order_raw: Variant = (
			current_packet.get(
				"category_order",
				[]
			)
		)
		var category_order: Array = (
			(category_order_raw as Array).duplicate(false)
			if typeof(category_order_raw) == TYPE_ARRAY
			else []
		)
		var delta: Dictionary = {
			"success": true,
			"schema": (
				"eralife.population_card_contract_engine."
				+ "renderer_delta"
			),
			"version": CONTRACT_VERSION,
			"realm_id": int(
				current_packet.get(
					"realm_id",
					-1
				)
			),
			"realm_name": str(
				current_packet.get(
					"realm_name",
					""
				)
			),
			"element": str(
				current_packet.get(
					"element",
					""
				)
			),
			"government_model": str(
				current_packet.get(
					"government_model",
					"realm_government"
				)
			),
			"government_profile": (
				current_packet.get(
					"government_profile",
					{}
				)
				if typeof(
					current_packet.get(
						"government_profile",
						{}
					)
				) == TYPE_DICTIONARY
				else {}
			),
			"truth_state": str(
				current_packet.get(
					"truth_state",
					"partial"
				)
			),
			"truth_complete": bool(
				current_packet.get(
					"truth_complete",
					false
				)
			),
			"federal_republic_population_contract": bool(
				current_packet.get(
					"federal_republic_population_contract",
					false
				)
			),
			"category_order": category_order,
			"built_at_ms": int(
				current_packet.get(
					"built_at_ms",
					Time.get_ticks_msec()
				)
			),
			"population_section_contracts": [],
			"removed_entity_ids": [],
			"replaced_entity_ids": [],
			"incremental_renderer_delta": true,
			"ui_is_renderer_only": true
		}
		var previous_sections_raw: Variant = (
			previous_packet.get(
				"population_section_contracts",
				[]
			)
		)
		var previous_sections: Array = (
			previous_sections_raw as Array
			if typeof(previous_sections_raw) == TYPE_ARRAY
			else []
		)
		var current_sections_raw: Variant = (
			current_packet.get(
				"population_section_contracts",
				[]
			)
		)
		var current_sections: Array = (
			current_sections_raw as Array
			if typeof(current_sections_raw) == TYPE_ARRAY
			else []
		)
		var previous_rows_by_identity: Dictionary = {}
		var current_rows_by_identity: Dictionary = {}
		var delta_sections: Array = []
		var delta_section_index_by_key: Dictionary = {}
		var removed_entity_ids: Array = []
		var replaced_entity_ids: Array = []
		var delta_count: int = 0

		for raw_previous_section in previous_sections:
			if typeof(raw_previous_section) != TYPE_DICTIONARY:
				continue

			var previous_section: Dictionary = (
				raw_previous_section as Dictionary
			)
			var section_key: String = str(
				previous_section.get(
					"key",
					""
				)
			)
			var previous_rows_raw: Variant = (
				previous_section.get(
					"rows",
					[]
				)
			)
			var previous_rows: Array = (
				previous_rows_raw as Array
				if typeof(previous_rows_raw) == TYPE_ARRAY
				else []
			)

			for raw_previous_row in previous_rows:
				var row_identity: String = (
					_population_renderer_row_identity(
						raw_previous_row
					)
				)

				if row_identity == "":
					continue

				previous_rows_by_identity [
					row_identity
				] = {
					"section_key": section_key,
					"signature": (
						_population_renderer_row_projection_signature(
							raw_previous_row,
							section_key
						)
					)
				}

		for raw_current_section in current_sections:
			if typeof(raw_current_section) != TYPE_DICTIONARY:
				continue

			var current_section: Dictionary = (
				raw_current_section as Dictionary
			)
			var section_key: String = str(
				current_section.get(
					"key",
					""
				)
			)

			if section_key == "":
				continue

			var current_rows_raw: Variant = (
				current_section.get(
					"rows",
					[]
				)
			)
			var current_rows: Array = (
				current_rows_raw as Array
				if typeof(current_rows_raw) == TYPE_ARRAY
				else []
			)

			for raw_current_row in current_rows:
				var row_identity: String = (
					_population_renderer_row_identity(
						raw_current_row
					)
				)

				if row_identity == "":
					continue

				var current_signature: String = (
					_population_renderer_row_projection_signature(
						raw_current_row,
						section_key
					)
				)

				current_rows_by_identity [
					row_identity
				] = {
					"section_key": section_key,
					"signature": current_signature
				}

				var previous_row_raw: Variant = (
					previous_rows_by_identity.get(
						row_identity,
						{}
					)
				)
				var previous_row: Dictionary = (
					previous_row_raw as Dictionary
					if typeof(previous_row_raw) == TYPE_DICTIONARY
					else {}
				)
				var new_row: bool = previous_row.is_empty()
				var replaced_row: bool = (
					not new_row
					and (
						str(
							previous_row.get(
								"section_key",
								""
							)
						) != section_key
						or str(
							previous_row.get(
								"signature",
								""
							)
						) != current_signature
					)
				)

				if not new_row and not replaced_row:
					continue

				if replaced_row:
					replaced_entity_ids.append(
						row_identity
					)

				if not delta_section_index_by_key.has(
					section_key
				):
					var created_delta_section: Dictionary = (
						current_section.duplicate(false)
					)
					created_delta_section ["rows"] = []
					delta_section_index_by_key [
						section_key
					] = delta_sections.size()
					delta_sections.append(
						created_delta_section
					)

				var delta_index: int = int(
					delta_section_index_by_key [
						section_key
					]
				)
				var delta_section: Dictionary = (
					delta_sections [
						delta_index
					]
				)
				var delta_rows: Array = (
					delta_section.get(
						"rows",
						[]
					) as Array
				)

				delta_rows.append(
					raw_current_row
				)
				delta_section [
					"rows"
				] = delta_rows
				delta_sections [
					delta_index
				] = delta_section
				delta_count += 1

		for raw_identity in previous_rows_by_identity.keys():
			var row_identity: String = str(
				raw_identity
			)

			if current_rows_by_identity.has(
				row_identity
			):
				continue

			removed_entity_ids.append(
				row_identity
			)

		var final_federal_truth_transition: bool = (
			bool(
				current_packet.get(
					"federal_republic_population_contract",
					false
				)
			)
			and bool(
				current_packet.get(
					"truth_complete",
					false
				)
			)
			and not bool(
				previous_packet.get(
					"truth_complete",
					false
				)
			)
		)
		var senate_reconciliation_rows: int = 0

		if final_federal_truth_transition:
			for raw_current_section in current_sections:
				if typeof(raw_current_section) != TYPE_DICTIONARY:
					continue

				var current_section: Dictionary = (
					raw_current_section as Dictionary
				)
				var section_key: String = str(
					current_section.get(
						"key",
						""
					)
				)

				if section_key != "federal_legislative":
					continue

				var senate_rows_raw: Variant = (
					current_section.get(
						"rows",
						[]
					)
				)
				var senate_rows: Array = (
					senate_rows_raw as Array
					if typeof(senate_rows_raw) == TYPE_ARRAY
					else []
				)

				if senate_rows.size() < DEFAULT_US_SENATE_TARGET:
					continue

				if not delta_section_index_by_key.has(
					section_key
				):
					var senate_delta_section: Dictionary = (
						current_section.duplicate(false)
					)
					senate_delta_section ["rows"] = []
					delta_section_index_by_key [
						section_key
					] = delta_sections.size()
					delta_sections.append(
						senate_delta_section
					)

				var delta_index: int = int(
					delta_section_index_by_key [
						section_key
					]
				)
				var delta_section: Dictionary = (
					delta_sections [
						delta_index
					]
				)
				var delta_rows: Array = (
					delta_section.get(
						"rows",
						[]
					) as Array
				)
				var delta_row_ids: Dictionary = {}

				for raw_delta_row in delta_rows:
					var delta_identity: String = (
						_population_renderer_row_identity(
							raw_delta_row
						)
					)

					if delta_identity != "":
						delta_row_ids [
							delta_identity
						] = true

				for raw_senator in senate_rows:
					var senate_identity: String = (
						_population_renderer_row_identity(
							raw_senator
						)
					)

					if (
						senate_identity == ""
						or delta_row_ids.has(
							senate_identity
						)
					):
						continue

					delta_rows.append(
						raw_senator
					)
					delta_row_ids [
						senate_identity
					] = true
					senate_reconciliation_rows += 1
					delta_count += 1

				delta_section [
					"rows"
				] = delta_rows
				delta_section [
					"federal_senate_cardinality_reconciliation"
				] = true
				delta_section [
					"expected_senate_count"
				] = DEFAULT_US_SENATE_TARGET
				delta_sections [
					delta_index
				] = delta_section

				break

		delta [
			"population_section_contracts"
		] = delta_sections
		delta [
			"removed_entity_ids"
		] = removed_entity_ids
		delta [
			"replaced_entity_ids"
		] = replaced_entity_ids
		delta [
			"delta_row_count"
		] = delta_count
		delta [
			"delta_removed_count"
		] = removed_entity_ids.size()
		delta [
			"delta_replaced_count"
		] = replaced_entity_ids.size()
		delta [
			"federal_senate_cardinality_reconciliation"
		] = final_federal_truth_transition
		delta [
			"senate_reconciliation_row_count"
		] = senate_reconciliation_rows
		delta [
			"expected_senate_count"
		] = (
			DEFAULT_US_SENATE_TARGET
			if final_federal_truth_transition
			else 0
		)


		for raw_category in [
			"federal_executive",
			"federal_cabinet",
			"federal_senate",
			"federal_supreme_court",
			"federal_governors",
			"royals",
			"officials",
			"nobles",
			"masters",
			"citizens"
		]:
			delta [
				str(raw_category)
			] = []

		return delta
func _population_social_class_priority(
		social_class: String
) -> int:
		var key: String = str(
			social_class
		).strip_edges().to_lower()

		if (
			key.find("elite") >= 0
			or key.find("upper") >= 0
			or key.find("aristocrat") >= 0
			or key.find("high nobility") >= 0
		):
			return 0

		if (
			key.find("professional") >= 0
			or key.find("learned") >= 0
			or key.find("clergy") >= 0
			or key.find("temple") >= 0
			or key.find("martial retainer") >= 0
		):
			return 1

		if (
			key.find("middle") >= 0
			or key.find("merchant") >= 0
		):
			return 2

		if (
			key.find("skilled") >= 0
			or key.find("artisan") >= 0
			or key.find("guild") >= 0
			or key.find("technical") >= 0
			or key.find("military class") >= 0
		):
			return 3

		if (
			key.find("working") >= 0
			or key.find("service") >= 0
			or key.find("commoner") >= 0
			or key.find("agrarian") >= 0
			or key.find("peasant") >= 0
			or key.find("frontier") >= 0
		):
			return 4

		if (
			key.find("lower") >= 0
			or key.find("poor") >= 0
			or key.find("servant") >= 0
			or key.find("labor") >= 0
		):
			return 5

		return 6
func _population_social_class_precedes(
		left: Variant,
		right: Variant
) -> bool:
		var left_name: String = str(
			left
		)
		var right_name: String = str(
			right
		)
		var left_priority: int = (
			_population_social_class_priority(
				left_name
			)
		)
		var right_priority: int = (
			_population_social_class_priority(
				right_name
			)
		)

		if left_priority != right_priority:
			return (
				left_priority
				< right_priority
			)

		return (
			left_name.to_lower()
			< right_name.to_lower()
		)
func _population_renderer_row_projection_signature(
		raw_row: Variant,
		section_key: String
) -> String:
		if raw_row is Person:
			var person: Person = raw_row as Person
			var office_raw: Variant = person.get(
				"civic_office_contract"
			)
			var office: Dictionary = (
				office_raw as Dictionary
				if typeof(office_raw) == TYPE_DICTIONARY
				else {}
			)

			return str(
				hash([
					section_key,
					int(person.id),
					bool(person.alive),
					str(person.job),
					str(person.civic_title),
					str(person.social_class),
					str(
						office.get(
							"role_label",
							""
						)
					),
					str(
						office.get(
							"office",
							""
						)
					),
					str(
						office.get(
							"branch",
							""
						)
					),
					str(
						office.get(
							"state_name",
							""
						)
					),
					str(
						office.get(
							"party",
							""
						)
					)
				])
			)

		if typeof(raw_row) == TYPE_DICTIONARY:
			var row: Dictionary = (
				raw_row as Dictionary
			)
			var office_raw: Variant = row.get(
				"civic_office_contract",
				{}
			)
			var office: Dictionary = (
				office_raw as Dictionary
				if typeof(office_raw) == TYPE_DICTIONARY
				else {}
			)

			return str(
				hash([
					section_key,
					bool(row.get("alive", true)),
					str(row.get("job", "")),
					str(row.get("civic_title", "")),
					str(row.get("role_label", "")),
					str(row.get("social_class", "")),
					str(
						office.get(
							"role_label",
							""
						)
					),
					str(
						office.get(
							"office",
							""
						)
					),
					str(
						office.get(
							"branch",
							""
						)
					),
					str(
						office.get(
							"state_name",
							""
						)
					),
					str(
						office.get(
							"party",
							""
						)
					)
				])
			)

		return str(
			hash([
				section_key,
				raw_row
			])
		)
func _fail(reason: String, realm_id: int = -1, realm_name: String = "") -> Dictionary:
	EraLog.failure(
		get_script().resource_path.get_file(),
		str(reason)
	)
	last_build_report = {
		"success": false,
		"schema": ENGINE_SCHEMA,
		"reason": reason,
		"realm_id": realm_id,
		"realm_name": realm_name,
		"reported_at_ms": int(Time.get_ticks_msec()),
		"ready_door_may_not_wait": true
	}

	_commit_registry()

	return last_build_report.duplicate(true)