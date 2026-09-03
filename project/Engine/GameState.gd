extends Resource
class_name GameState
signal resident_runtime_engine_became_resident(
	engine_property: StringName,
	engine_instance: Variant
)
signal world_feed_entry_contract_committed(
	contract: Dictionary
)
var runtime_health_registry
var runtime_fault_router
var dormant_runtime_sessions: Dictionary = {}
var patch_suggestion_engine
var live_patch_guard
var live_diagnostics_engine
var auto_patch_engine
var universal_faction_engine
var universal_faction_state: Dictionary = {}

var game_state_contract_engine
var game_state_hydration_runtime
var game_state_serialization_runtime
var temporal_slice_transformation_runtime
var reality_fusion_engine
var reality_orchestrator
var causality_inversion_engine
var contract_meta_governor
var game_state_contract_registry: Dictionary = {}
var game_state_contract_slices: Dictionary = {}
var game_state_runtime_guard: Dictionary = {}
var game_state_hydration_report: Dictionary = {}
var game_state_serialization_report: Dictionary = {}
var game_state_temporal_slice_report: Dictionary = {}
var preserved_unknown_save_slices: Dictionary = {}
var contract_runtime_engines: Dictionary = {}
var command_envelope_queue: Array = []
var last_command_envelope_report: Dictionary = {}
var realm_contract_engine
var simulation_contract_engine
var runtime_contract_engine
var romance_contract_engine
var live_person_editor_engine
var ui_contract_engine
var embedded_ui_contract_engine
var birth_contract_engine
var life_diary_contract_engine
var narrative_governor
var perceptual_integrity_engine
var lineage_engine
var choose_adventure_engine
var choose_adventure_scenario_engine
var choose_adventure_ai_node_generator
var family_creation_contract_engine



var binary_saves_enabled: bool = true
var archive_generations: Array = []
var compressed_memories: Dictionary = {}
var npc_graveyard: Dictionary = {}
var save_version: int = 7
var world_feed: Array = []
var event_bus
var event_bus_contract_layer
var capability_graph_engine
var emergent_story_engine
var ecs_engine
var controlled_lineage_ids: Array = []
var spatial_culling_engine
var dormant_npcs: Dictionary = {}
const DORMANT_SIM_BATCH_LIMIT:= 5000
var chunk_simulation_engine
var social_graph_engine
var action_discovery_engine
var world_space_engine
var external_era_data_loaded: bool = false
var weapon_packs_loaded: bool = false
var mods_loaded: bool = false
var npc_memory_web_engine
var agent_memory_propagation_engine
var dynamic_world_event_engine
var legacy_memory_engine
var legacy_echo_engine
var seed_engine
var soul_seed_engine
var consciousness_engine
var willpower_engine
var goal_planning_engine
const ACTIVE_MEMORY_LIMIT = 40
const WORLD_FEED_LIMIT = 5000
const NPC_ACTIVE_LIMIT = 300
const MAX_MORTAL_AGE = 130
var economy_engine
var bank_engine
var global_market_engine
var room_graph_contract_engine
var spatial_traversal_contract_engine
var presence_engine
var era_life_asset_catalog_expansion
var property_amenity_synthesis_contract_engine
var property_market_contract_engine
var dealership_contract_engine
var property_makeover_contract_engine
var card_contract_engine
var dynasty_legacy_engine


var school_engine



var school_hub_contract_engine

var school_rosters: Dictionary = {}
var red_bonnet_engine
var bending_engine
var bending_tournament_engine
var avatar_influence_engine
var bending_dojo_engine
var wizard_engine
var power_engine
var superhero_engine
var infamy_engine
var upce_engine
var world_chronicle_engine
var historical_timeline_engine
var reputation_engine
var fame_engine
var class_engine
var realm_engine




var royalty_runtime_engine


var royalty_contract_engine


var royalty_mod_contract_engine


var crown_hub_contract_engine




var royalty_engine


var royalty_institution_state: Dictionary = {}

var politics_engine



var artifacts_engine



var artifacts_catalog_contract_engine



var artifact_interaction_contract_engine



var artifact_shop_contract_engine

var dragonballs_engine
var many_realms_engine
var bridge_to_terabithia_engine
var vormir_engine
var nidavellir_engine
var family_contract_engine
var family_control_engine
var universal_switch_contract_engine



var relationships_hub_contract_engine
var global_intent_contract_engine
var checks_and_balances_contract_engine


var weapons_engine



var weapons_catalog_expansion



var crime_contract_engine



var crime_hub_contract_engine


var investigation_layer


var justice_system_engine


var jail_engine



var prison_engine


var case_orchestrator


var crime_engine
var relationship_activities_engine



var heirloom_runtime_engine



var heirloom_contract_engine


var heirloom_engine


var heirloom_catalog_contract_engine


var heirloom_hub_contract_engine

var property_engine
var vehicle_engine
var assets_contract_engine
var shared_public_space_engine
var food_engine
var food_restaurant_engine
var grocery_store_engine
var movie_theater_engine
var luxury_shop_engine
var island_realm_engine
var population_movement_contract_engine
var global_prewarm_contract_engine
var global_node_contract_engine
var truth_resolution_contract_engine
var observable_node_contract_engine
var world_observability_contract_engine
var population_card_contract_engine
var crown_population_view_contract



var belongings_engine




var global_object_catalog_system



var object_hub_contract_engine

var player_action_engine
var workplace_engine
var era_data_loader
var asset_catalogs_loaded: bool = false
var weapon_pack_loader
var ai_event_engine
var desire_behavior_bridge
var simulation_director
var year_budget_engine



var mod_loader


var mod_contract_engine



var mod_bundle_contract_engine


var mod_marketplace_contract_engine


var mod_hub_contract_engine


var mod_menu_contract_engine


var caveman_reality_runtime_engine





var mini_game_runtime_engine

var scoreboard_contract_engine

var achievement_contract_engine

var replay_contract_engine

var multiplayer_contract_engine

var adobe_flash_contract_engine

var mini_game_host_adapter_engine

var mini_game_contract_engine

var mini_game_hub_contract_engine



var mod_contract_registry: Dictionary = {}
var mod_provider_registry: Dictionary = {}
var mod_conflict_registry: Dictionary = {}
var mod_contract_runtime_report: Dictionary = {}
var llm_bridge
var population_shard_engine
var population_lifecycle_manager
var genetics_inheritance_engine
var body_type_contract_engine
var growth_curve_engine
var height_contract_engine
var weight_contract_engine
var human_contract_engine
var animal_contract_engine
var mythical_contract_engine
var relationship_graph_contract_engine
var human_relationship_contract_engine
var pets_contract_engine
var mythical_pets_contract_engine
var pet_shop_contract_engine
var breeding_contract_engine
var debt_contract_engine
var meat_market_contract_engine

var entity_registry: Dictionary = {}
var canonical_relationship_graph: Dictionary = {}
var body_contract_runtime_queue: Array = []
var body_contract_runtime_index: Dictionary = {}
var body_contract_runtime_report: Dictionary = {}
var body_contract_yearly_queue_built_for_year: int = -999999
const BODY_CONTRACT_RUNTIME_QUEUE_LIMIT:= 240
const BODY_CONTRACT_RUNTIME_DRAIN_DEFAULT:= 3


var geo_engine
var migration_engine
var settlement_presence_engine
var place_influence_engine
var boxing_contract_engine
var boxing_combat_resolution_engine
var boxing_fight_economy_engine
var boxing_engine
var boxing_fighter_engine
var boxing_training_engine
var boxing_matchmaking_engine
var boxing_fight_sim_engine
var boxing_ranking_engine
var boxing_title_engine
var boxing_injury_engine
var boxing_round_log_engine
var boxing_rivalry_engine
var boxing_gym_engine
var boxing_promotion_engine
var boxing_weight_engine
var boxing_mandatory_engine
var boxing_amateur_engine
var boxing_media_engine
var boxing_legacy_engine
var competitive_reality_runtime
var reality_surge_engine
var vampire_engine
var vampire_origin_engine
var vampire_hunger_engine
var vampire_ability_engine
var vampire_society_engine
var vampire_hunter_engine
var vampire_legacy_engine
var vampire_masquerade_engine
var vampire_cure_engine



const REALITY_REALISTIC:= "realistic"
const REALITY_ENHANCED:= "enhanced"
const REALITY_CHAOS:= "chaos"

var reality_mode: String = REALITY_CHAOS
var reality_feature_overrides: Dictionary = {}
var year_locked: bool = false
var player_bending_enabled: bool = true
var realtime_enabled: bool = false
var realtime_step_minutes: int = 1
var awaiting_new_life: bool = false




const REWIND_LIMIT:= 3
var rewind_snapshot_paths: Array = []
var rewind_uses_remaining: int = REWIND_LIMIT
var afterlife_influence_engine
var afterlife_active: bool = false
var afterlife_state: Dictionary = {}
var lineage_influence_profiles: Dictionary = {}
var transient_afterlife_biases: Dictionary = {}


var scenario_engine
var scenario_resolver
var scenario_popup_contract_engine
var scenario_runtime_contract_engine
var pending_situations_engine
var contract_view_layer_contract_engine
var traits_contract_engine
var identity_contract_engine
var email_verification_transport_engine
var mailbox_contract_engine
var messenger_contract_engine
var self_host_network_contract_engine
var search_contract_engine
var crr_contract_engine




var compression
var connection_graph_network
var eraccount_profile_contract_engine
var network_notes_contract_engine
var public_feed_contract_engine
var reality_stream_contract_engine
var life_account_transfer_contract_engine
var eralife_network_contract_engine
var military_contract_engine
var war_contract_engine
var battle_contract_engine
var battle_sim_contract_engine
var battle_ui_contract_engine
var session_contract_engine
var reality_checkpoint_contract_engine
var reality_merge_contract_engine
var reality_integrity_contract_engine
var world_contract_hydrator



var reality_snapshot_contract_engine
var reality_projection_contract_engine
var reality_residency_manager
var reality_residency_contract_engine
var scenario_state: Dictionary = {}
var scenario_history: Array = []
var transient_scenario_biases: Dictionary = {}
func _compress_person_memories(pid: int):

	if not memories.has(pid):
		return

	var arr = memories [pid]

	if arr.size() <= ACTIVE_MEMORY_LIMIT:
		return


	var recent = arr.slice(arr.size() - ACTIVE_MEMORY_LIMIT, arr.size())


	var summary = {
		"count": arr.size() - recent.size(),
		"first": arr [0],
		"last": arr [arr.size() - ACTIVE_MEMORY_LIMIT - 1]
	}

	compressed_memories [pid] = summary
	memories [pid] = recent
func _collect_player_ancestor_ids(max_depth:= 4) -> Array:
	var out: Array = []
	if player == null:
		return out

	var frontier: Array = player.parents.duplicate()
	var visited:= {}

	var depth:= 0
	while depth < max_depth and frontier.size() > 0:
		var next_frontier: Array = []
		for pid in frontier:
			var ancestor_id:= int(pid)
			if ancestor_id <= 0:
				continue
			if visited.has(ancestor_id):
				continue

			visited [ancestor_id] = true
			out.append(ancestor_id)

			var ancestor = get_npc_by_id(ancestor_id)
			if ancestor != null:
				for gpid in ancestor.parents:
					next_frontier.append(int(gpid))

		frontier = next_frontier
		depth += 1

	return out
func _prune_dead_npcs():
	var keep:= []
	var protected_ancestor_ids:= _collect_player_ancestor_ids(4)

	if world_feed.size() > WORLD_FEED_LIMIT:
		world_feed = world_feed.slice(world_feed.size() - WORLD_FEED_LIMIT, world_feed.size())

	for i in range(world_feed.size()):
		world_feed [i] = normalize_world_feed_entry(world_feed [i])

	for npc in npcs:
		if npc.alive:
			keep.append(npc)
			continue


		if npc.id in player.parents or npc.id in player.children or npc.id in protected_ancestor_ids:
			keep.append(npc)
			continue

		npc_graveyard [npc.id] = {
			"name": npc.first_name + " " + npc.last_name,
			"age": npc.age,
			"cause": npc.cause_of_death,
			"fame": npc.fame
		}

	npcs = keep
	_rebuild_npc_index()
func archive_generation():

	var snapshot = {
		"year": year,
		"player_name": player.first_name + " " + player.last_name,
		"dynasty": dynasty_engine.dynasties.duplicate(),
		"graveyard_count": npc_graveyard.size(),
		"world_feed_tail": world_feed.slice(max(0, world_feed.size() - 50), world_feed.size())
	}

	archive_generations.append(snapshot)

func _merge_remap_id(gs: GameState, id_map: Dictionary, old_id: int) -> int:
	if old_id <= 0:
		return 0
	if not id_map.has(old_id):
		id_map [old_id] = gs.next_id
		gs.next_id += 1
	return id_map [old_id]

func set_realtime_enabled(value: bool):
	realtime_enabled = value

func _merge_find_foreign(list: Array, old_id: int) -> Dictionary:
	for d in list:
		if d.id == old_id:
			return d
	return {}

func _merge_import_single(gs: GameState, foreign_npcs: Array, old_id: int, id_map: Dictionary, imported_cache: Dictionary) -> Person:
	if old_id <= 0:
		return null
	if imported_cache.has(old_id):
		return imported_cache [old_id]

	var src = _merge_find_foreign(foreign_npcs, old_id)
	if src == {}:
		return null

	var new_p = gs._deserialize_npc(src)
	new_p.id = _merge_remap_id(gs, id_map, old_id)


	new_p.parents = new_p.parents.duplicate()
	new_p.children = new_p.children.duplicate()

	imported_cache [old_id] = new_p
	return new_p






var era_engine




var era_contract_engine


var era_mod_contract_engine

var era
var year = 2000
var next_id = 1
var npcs: Array = []
var npc_index: Dictionary = {}
var memories = {}
var player: Person
var player_id: int

var names_db
var npc_factory
var character_creator
var world_engine
var event_engine
var personality_engine
var relationship_engine
var memory_engine
var health_engine





var career_engine

var career_contract_engine


var career_runtime_engine


var career_space_contract_engine

var career_hub_contract_engine



var activities_contract_engine


var activities_hub_contract_engine



var career_ecosystem_state: Dictionary = {}
var opportunity_engine
var fate_engine
var life_engine
var narrative_engine
var dynasty_engine
var world_feed_engine
var desire_engine

var custom_mode: bool = false
var custom_settings: Dictionary = {}


var pending_death_messages: Array = []
var pending_inheritance_messages: Array = []
var pending_year_resolution_popups: Array = []
var pending_player_line_birth: Dictionary = {}




static var _resident_chassis_shell_construction_depth: int = 0
static var _resident_first_life_seed_sequence: int = 0


static func create_resident_chassis_shell() -> GameState:
	_resident_chassis_shell_construction_depth += 1

	var chassis_runtime: GameState = GameState.new()

	_resident_chassis_shell_construction_depth = maxi(
		0,
		_resident_chassis_shell_construction_depth - 1
	)

	return chassis_runtime


# Every GameState records where it was constructed. A load leaves several runtimes
# alive at once and it has not been clear which one owns what -- this makes the set
# enumerable instead of guessed at.
var runtime_origin_tag: String = ""
static var _runtime_birth_serial: int = 0


func _init() -> void:
	_runtime_birth_serial += 1
	runtime_origin_tag = (
		"chassis_shell#%d" % _runtime_birth_serial
		if _resident_chassis_shell_construction_depth > 0
		else "runtime#%d" % _runtime_birth_serial
	)

	EraLog.truth(
		"ERALIFE_GS_BORN|id=%d|tag=%s|chassis_depth=%d"
		% [
			int(get_instance_id()),
			runtime_origin_tag,
			_resident_chassis_shell_construction_depth
		]
	)

	if _resident_chassis_shell_construction_depth > 0:
		return

	_ensure_reality_residency_runtime_dependencies()


func _ensure_reality_residency_runtime_dependencies() -> void:
	if reality_snapshot_contract_engine == null:
		reality_snapshot_contract_engine = (
			RealitySnapshotContractEngine.new(self)
		)
	else:
		reality_snapshot_contract_engine.bind_game_state(
			self
		)

	if reality_projection_contract_engine == null:
		reality_projection_contract_engine = (
			RealityProjectionContractEngine.new(self)
		)
	else:
		reality_projection_contract_engine.bind_game_state(
			self
		)

	if reality_residency_manager == null:
		reality_residency_manager = RealityResidencyManager.new(
			self,
			reality_snapshot_contract_engine,
			reality_projection_contract_engine
		)
	else:
		reality_residency_manager.bind_authorities(
			self,
			reality_snapshot_contract_engine,
			reality_projection_contract_engine
		)

	if reality_residency_contract_engine == null:
		reality_residency_contract_engine = (
			RealityResidencyContractEngine.new(
				self,
				reality_residency_manager,
				reality_snapshot_contract_engine,
				reality_projection_contract_engine
			)
		)
	else:
		reality_residency_contract_engine.bind_authorities(
			self,
			reality_residency_manager,
			reality_snapshot_contract_engine,
			reality_projection_contract_engine
		)







	if global_intent_contract_engine == null:
		global_intent_contract_engine = (
			GlobalIntentContractEngine.new(
				self
			)
		)
	else:
		global_intent_contract_engine.bind_game_state(
			self
		)

	if typeof(
		scenario_state
	) != TYPE_DICTIONARY:
		scenario_state = {}

	scenario_state [
		"reality_residency_intent_gateway_ready"
	] = (
		global_intent_contract_engine != null
	)

	scenario_state [
		"reality_residency_intent_gateway_scope"
	] = (
		"persistent_residency_host"
	)

	scenario_state [
		"reality_residency_intent_gateway_initialized_before_world"
	] = true

	scenario_state [
		"reality_residency_intent_gateway_requires_full_initialize"
	] = false

	reality_snapshot_contract_engine.bootstrap_default_contracts()
	reality_projection_contract_engine.bootstrap_default_contracts()
	reality_residency_manager.bootstrap_default_contracts()
	reality_residency_contract_engine.bootstrap_default_contracts()



var resident_runtime_bootstrap_plan: Array = []
var resident_runtime_bootstrap_cursor: int = 0
var resident_runtime_bootstrap_mode: String = "idle"
var resident_runtime_bootstrap_signature: String = ""
var resident_runtime_bootstrap_started_at_ms: int = 0
var resident_runtime_bootstrap_last_step_at_ms: int = 0
var resident_runtime_bootstrap_complete: bool = false
var resident_runtime_bootstrap_failed: bool = false
var resident_runtime_bootstrap_failure: Dictionary = {}
var resident_runtime_binding_pending: bool = false
var resident_runtime_binding_settings: Dictionary = {}
var resident_runtime_binding_context: Dictionary = {}




var resident_runtime_active_step_progress: float = 0.0
var resident_runtime_active_step_report: Dictionary = {}
var resident_runtime_last_step_duration_ms: int = 0


var resident_population_placement_cursor: int = 0
var resident_population_placement_finalized: bool = false
var resident_first_frame_truth_phase: int = 0
var resident_first_frame_truth_actor_cursor: int = 0
func begin_resident_runtime_chassis_bootstrap(
	context: Dictionary = {}
) -> Dictionary:
	if (
		resident_runtime_bootstrap_complete
		or not resident_runtime_bootstrap_plan.is_empty()
	):
		return resident_runtime_bootstrap_snapshot()

	var settings: Dictionary = _resident_dict(
		context.get(
			"settings",
			{}
		)
	)





	resident_runtime_bootstrap_mode = "chassis"
	resident_runtime_bootstrap_signature = str(
		context.get(
			"signature",
			""
		)
	).strip_edges()

	var constructor_context: Dictionary = (
		context.duplicate(true)
	)

	constructor_context [
		"resident_runtime_bootstrap_mode"
	] = "chassis"
	constructor_context [
		"reality_binding_requested"
	] = false
	constructor_context [
		"seed_materialization_authorized"
	] = false
	constructor_context [
		"generic_resident_chassis"
	] = true

	_resident_bind_constructor_context(
		settings,
		constructor_context
	)
	_hydrate_reality_settings()

	if typeof(
		scenario_state
	) != TYPE_DICTIONARY:
		scenario_state = {}

	resident_runtime_bootstrap_started_at_ms = int(
		Time.get_ticks_msec()
	)
	resident_runtime_bootstrap_cursor = 0
	resident_runtime_bootstrap_complete = false
	resident_runtime_bootstrap_failed = false
	resident_runtime_bootstrap_failure = {}
	resident_runtime_bootstrap_plan = (
		_resident_runtime_engine_steps()
	)

	if resident_runtime_bootstrap_plan.is_empty():
		_resident_fail_bootstrap(
			"resident_runtime_engine_plan_is_empty",
			"build_resident_runtime_engine_plan"
		)

		return resident_runtime_bootstrap_snapshot()

	if not settings.is_empty():
		resident_runtime_binding_pending = true
		resident_runtime_binding_settings = (
			settings.duplicate(true)
		)
		resident_runtime_binding_context = (
			context.duplicate(true)
		)

	scenario_state [
		"resident_runtime_chassis_bootstrap_active"
	] = true
	scenario_state [
		"resident_runtime_chassis_bootstrap_complete"
	] = false
	scenario_state [
		"resident_runtime_chassis_has_bound_reality"
	] = false
	scenario_state [
		"resident_runtime_chassis_seed_materialization_forbidden"
	] = true
	scenario_state [
		"runtime_scene_tree_access_allowed"
	] = false
	scenario_state [
		"ui_is_pure_renderer"
	] = true

	return resident_runtime_bootstrap_snapshot()

func bind_resident_reality(
	settings: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	if not resident_runtime_bootstrap_complete:
		resident_runtime_binding_pending = true
		resident_runtime_binding_settings = (
			settings.duplicate(true)
		)
		resident_runtime_binding_context = (
			context.duplicate(true)
		)

		return resident_runtime_bootstrap_snapshot()

	if typeof(scenario_state) != TYPE_DICTIONARY:
		scenario_state = {}

	resident_runtime_bootstrap_mode = (
		"reality_binding"
	)
	resident_runtime_bootstrap_signature = str(
		context.get(
			"signature",
			resident_runtime_bootstrap_signature
		)
	).strip_edges()
	resident_runtime_bootstrap_complete = false
	resident_runtime_bootstrap_failed = false
	resident_runtime_bootstrap_failure = {}
	resident_runtime_bootstrap_cursor = 0
	resident_runtime_binding_pending = false

	resident_runtime_active_step_progress = 0.0
	resident_runtime_active_step_report = {}
	resident_runtime_last_step_duration_ms = 0

	resident_population_placement_cursor = 0
	resident_population_placement_finalized = false
	resident_first_frame_truth_phase = 0
	resident_first_frame_truth_actor_cursor = 0

	resident_runtime_binding_settings = (
		settings.duplicate(true)
	)
	resident_runtime_binding_context = (
		context.duplicate(true)
	)







	resident_runtime_bootstrap_plan = [
		_resident_action_step(
			"apply_reality_settings",
			Callable(
				self,
				"_resident_apply_reality_settings"
			)
		),
		_resident_action_step(
			"spawn_shell_population",
			Callable(
				self,
				"_resident_spawn_shell_population"
			)
		),
		_resident_action_step(
			"create_player_identity",
			Callable(
				self,
				"_resident_create_player_identity"
			)
		),
		_resident_action_step(
			"apply_birth_contracts",
			Callable(
				self,
				"_resident_apply_birth_contracts"
			)
		),
		_resident_action_step(
			"seal_resident_reality",
			Callable(
				self,
				"_resident_seal_reality"
			)
		)
	]

	scenario_state [
		"resident_runtime_binding_active"
	] = true
	scenario_state [
		"resident_runtime_binding_complete"
	] = false

	scenario_state [
		"resident_ready_gate_contract"
	] = "seed_era_player_family_birth"

	scenario_state [
		"resident_ready_gate_requires_world_seed"
	] = true

	scenario_state [
		"resident_ready_gate_requires_player_identity"
	] = true

	scenario_state [
		"resident_ready_gate_requires_household_birth_truth"
	] = true

	scenario_state [
		"resident_ready_gate_requires_spatial_placement"
	] = false

	scenario_state [
		"resident_ready_gate_requires_consciousness"
	] = false

	scenario_state [
		"resident_ready_gate_requires_willpower"
	] = false

	scenario_state [
		"resident_ready_gate_requires_relationship_enrichment"
	] = false

	scenario_state [
		"resident_ready_gate_requires_family_pet"
	] = false

	scenario_state [
		"resident_ready_gate_requires_projection"
	] = false

	scenario_state [
		"resident_ready_gate_requires_snapshot"
	] = false

	scenario_state [
		"resident_post_ready_truth_tail_phase"
	] = 0

	scenario_state [
		"resident_post_ready_truth_tail_pending"
	] = true

	scenario_state [
		"resident_post_ready_truth_tail_complete"
	] = false

	scenario_state [
		"resident_post_ready_truth_tail_does_not_block_ready"
	] = true

	return resident_runtime_bootstrap_snapshot()


func step_resident_runtime_bootstrap(
	max_steps: int = 1,
	frame_budget_ms: int = 2
) -> Dictionary:
	if (
		resident_runtime_bootstrap_failed
		or resident_runtime_bootstrap_complete
	):
		return resident_runtime_bootstrap_snapshot()

	if resident_runtime_bootstrap_plan.is_empty():
		return {
			"success": false,
			"reason": (
				"resident_runtime_bootstrap_not_started"
			),
			"complete": false
		}

	if typeof(scenario_state) != TYPE_DICTIONARY:
		scenario_state = {}

	var frame_started_ms: int = int(
		Time.get_ticks_msec()
	)
	var executed_quanta: int = 0
	var requested_quantum_limit: int = maxi(
		1,
		max_steps
	)
	var requested_budget_limit_ms: int = maxi(
		1,
		frame_budget_ms
	)
	var binding_live_reality: bool = (
		resident_runtime_bootstrap_mode
		== "reality_binding"
	)
	var quantum_limit: int = (
		1
		if binding_live_reality
		else requested_quantum_limit
	)
	var budget_limit_ms: int = (
		mini(
			2,
			requested_budget_limit_ms
		)
		if binding_live_reality
		else requested_budget_limit_ms
	)

	scenario_state [
		"resident_runtime_requested_quantum_limit"
	] = requested_quantum_limit
	scenario_state [
		"resident_runtime_effective_quantum_limit"
	] = quantum_limit
	scenario_state [
		"resident_runtime_requested_budget_ms"
	] = requested_budget_limit_ms
	scenario_state [
		"resident_runtime_effective_budget_ms"
	] = budget_limit_ms
	scenario_state [
		"resident_reality_binding_one_quantum_per_service"
	] = binding_live_reality

	while (
		resident_runtime_bootstrap_cursor
		< resident_runtime_bootstrap_plan.size()
		and executed_quanta < quantum_limit
	):
		if (
			executed_quanta > 0
			and (
				int(
					Time.get_ticks_msec()
				) - frame_started_ms
			) >= budget_limit_ms
		):
			break

		var step_started_ms: int = int(
			Time.get_ticks_msec()
		)
		var step: Dictionary = (
			resident_runtime_bootstrap_plan [
				resident_runtime_bootstrap_cursor
			]
		)
		var step_id: String = str(
			step.get(
				"step_id",
				(
					"resident_step_%d"
					% resident_runtime_bootstrap_cursor
				)
			)
		)
		var runner_raw: Variant = step.get(
			"runner",
			Callable()
		)

		if typeof(runner_raw) != TYPE_CALLABLE:
			_resident_fail_bootstrap(
				"invalid_step_callable",
				step_id
			)
			break

		scenario_state [
			"resident_runtime_active_authority_step"
		] = step_id
		scenario_state [
			"resident_runtime_active_authority_step_started_at_ms"
		] = step_started_ms

		var result: Variant = (
			(runner_raw as Callable).call()
		)
		var result_report: Dictionary = (
			(result as Dictionary).duplicate(true)
			if typeof(result) == TYPE_DICTIONARY
			else {
				"success": true,
				"complete": true
			}
		)

		executed_quanta += 1

		if not result_report.has(
			"stage_id"
		):
			result_report ["stage_id"] = step_id

		result_report [
			"authority_step_id"
		] = step_id
		result_report [
			"binding_live_reality"
		] = binding_live_reality
		result_report [
			"effective_quantum_limit"
		] = quantum_limit
		result_report [
			"effective_budget_ms"
		] = budget_limit_ms

		if not bool(
			result_report.get(
				"success",
				true
			)
		):
			_resident_fail_bootstrap(
				str(
					result_report.get(
						"reason",
						"resident_step_failed"
					)
				),
				step_id,
				result_report
			)
			break

		resident_runtime_last_step_duration_ms = maxi(
			0,
			int(
				Time.get_ticks_msec()
			) - step_started_ms
		)
		resident_runtime_active_step_report = (
			result_report.duplicate(true)
		)
		resident_runtime_active_step_progress = clampf(
			float(
				result_report.get(
					"progress",
					(
						1.0
						if bool(
							result_report.get(
								"complete",
								true
							)
						)
						else 0.0
					)
				)
			),
			0.0,
			1.0
		)

		scenario_state [
			"resident_runtime_last_authority_step"
		] = step_id
		scenario_state [
			"resident_runtime_last_authority_step_duration_ms"
		] = resident_runtime_last_step_duration_ms
		scenario_state [
			"resident_runtime_last_authority_step_report"
		] = result_report.duplicate(true)

		if (
			binding_live_reality
			and resident_runtime_last_step_duration_ms
			> budget_limit_ms
		):
			scenario_state [
				"resident_runtime_binding_budget_overrun"
			] = true
			scenario_state [
				"resident_runtime_binding_budget_overrun_step"
			] = step_id
			scenario_state [
				"resident_runtime_binding_budget_overrun_ms"
			] = resident_runtime_last_step_duration_ms
			scenario_state [
				"resident_runtime_binding_budget_overrun_at_ms"
			] = int(
				Time.get_ticks_msec()
			)

		if not bool(
			result_report.get(
				"complete",
				true
			)
		):
			resident_runtime_bootstrap_last_step_at_ms = int(
				Time.get_ticks_msec()
			)




			if binding_live_reality:
				break

			if (
				executed_quanta >= quantum_limit
				or (
					int(
						Time.get_ticks_msec()
					) - frame_started_ms
				) >= budget_limit_ms
			):
				break

			continue

		resident_runtime_bootstrap_cursor += 1
		resident_runtime_bootstrap_last_step_at_ms = int(
			Time.get_ticks_msec()
		)
		resident_runtime_active_step_progress = 0.0
		resident_runtime_active_step_report = {}



		if binding_live_reality:
			break

	if (
		not resident_runtime_bootstrap_failed
		and resident_runtime_bootstrap_cursor
		>= resident_runtime_bootstrap_plan.size()
	):
		resident_runtime_bootstrap_complete = true
		resident_runtime_active_step_progress = 1.0
		scenario_state [
			"resident_runtime_active_authority_step"
		] = "complete"

	if (
		resident_runtime_bootstrap_mode == "chassis"
		and resident_runtime_binding_pending
	):
		var queued_settings: Dictionary = (
			resident_runtime_binding_settings.duplicate(true)
		)
		var queued_context: Dictionary = (
			resident_runtime_binding_context.duplicate(true)
		)

		resident_runtime_bootstrap_plan = []

		bind_resident_reality(
			queued_settings,
			queued_context
		)

	return resident_runtime_bootstrap_snapshot()


func resident_runtime_bootstrap_snapshot() -> Dictionary:
	var total: int = (
		resident_runtime_bootstrap_plan.size()
	)
	var complete_steps: int = mini(
		resident_runtime_bootstrap_cursor,
		total
	)
	var active_fraction: float = (
		0.0
		if resident_runtime_bootstrap_complete
		else clampf(
			resident_runtime_active_step_progress,
			0.0,
			0.999
		)
	)
	var fractional_steps: float = (
		float(
			complete_steps
		) + active_fraction
	)
	var local_progress: float = (
		1.0
		if resident_runtime_bootstrap_complete
		else (
			fractional_steps
			/ float(
				maxi(
					1,
					total
				)
			)
		)
	)
	var stage_id: String = "complete"

	if (
		not resident_runtime_bootstrap_complete
		and complete_steps < total
	):
		stage_id = str(
			(
				resident_runtime_bootstrap_plan [
					complete_steps
				] as Dictionary
			).get(
				"step_id",
				(
					"resident_step_%d"
					% complete_steps
				)
			)
		)

	var overall: float = local_progress

	if resident_runtime_bootstrap_mode == "chassis":
		overall = local_progress * 0.7
	elif resident_runtime_bootstrap_mode == "reality_binding":
		overall = 0.7 + local_progress * 0.2
	elif resident_runtime_bootstrap_complete:
		overall = 0.9

	return {
		"success": not resident_runtime_bootstrap_failed,
		"schema": (
			"eralife.resident_runtime_bootstrap_snapshot"
		),
		"version": 2,
		"mode": resident_runtime_bootstrap_mode,
		"signature": resident_runtime_bootstrap_signature,
		"complete": resident_runtime_bootstrap_complete,
		"failed": resident_runtime_bootstrap_failed,
		"failure": (
			resident_runtime_bootstrap_failure.duplicate(true)
		),
		"stage_id": stage_id,
		"completed_steps": complete_steps,
		"fractional_steps": fractional_steps,
		"active_step_progress": active_fraction,
		"active_step_report": (
			resident_runtime_active_step_report.duplicate(true)
		),
		"last_step_duration_ms": (
			resident_runtime_last_step_duration_ms
		),
		"total_steps": total,
		"progress": clampf(
			local_progress,
			0.0,
			1.0
		),
		"overall_progress": clampf(
			overall,
			0.0,
			0.9
		),
		"player_ready": player != null,
		"worker_thread_used": false,
		"ui_is_renderer_only": true
	}

func prepare_resident_runtime_for_checkpoint_hydration(
	context: Dictionary = {}
) -> Dictionary:



	if resident_runtime_bootstrap_failed:
		var failed_report: Dictionary = (
			resident_runtime_bootstrap_snapshot()
		)
		failed_report ["ready"] = false
		failed_report [
			"checkpoint_hydration_chassis"
		] = true
		return failed_report

	if resident_runtime_bootstrap_complete:
		var complete_report: Dictionary = (
			resident_runtime_bootstrap_snapshot()
		)
		complete_report ["success"] = true
		complete_report ["ready"] = true
		complete_report ["complete"] = true
		complete_report ["progress"] = 1.0
		complete_report ["overall_progress"] = 1.0
		complete_report ["stage_id"] = "complete"
		complete_report [
			"checkpoint_hydration_chassis"
		] = true
		complete_report [
			"runtime_engine_graph_resident"
		] = true
		return complete_report

	if resident_runtime_bootstrap_plan.is_empty():
		resident_runtime_bootstrap_mode = (
			"checkpoint_hydration_chassis"
		)
		resident_runtime_bootstrap_signature = str(
			context.get(
				"signature",
				context.get(
					"checkpoint_path",
					"checkpoint_hydration"
				)
			)
		).strip_edges()
		resident_runtime_bootstrap_started_at_ms = int(
			Time.get_ticks_msec()
		)
		resident_runtime_bootstrap_last_step_at_ms = 0
		resident_runtime_bootstrap_cursor = 0
		resident_runtime_bootstrap_complete = false
		resident_runtime_bootstrap_failed = false
		resident_runtime_bootstrap_failure = {}



		resident_runtime_binding_pending = false
		resident_runtime_binding_settings = {}
		resident_runtime_binding_context = {}

		resident_runtime_bootstrap_plan = (
			_resident_runtime_engine_steps()
		)

		if typeof(
			scenario_state
		) != TYPE_DICTIONARY:
			scenario_state = {}

		scenario_state [
			"checkpoint_hydration_chassis_active"
		] = true
		scenario_state [
			"checkpoint_hydration_chassis_complete"
		] = false
		scenario_state [
			"checkpoint_hydration_uses_resident_engine_graph"
		] = true
		scenario_state [
			"checkpoint_hydration_constructor_work_on_ui_forbidden"
		] = true
		scenario_state [
			"checkpoint_hydration_constructor_work_on_tab_click_forbidden"
		] = true
		scenario_state [
			"runtime_scene_tree_access_allowed"
		] = false
		scenario_state [
			"ui_is_pure_renderer"
		] = true

		if resident_runtime_bootstrap_plan.is_empty():
			_resident_fail_bootstrap(
				"checkpoint_resident_engine_plan_is_empty",
				"prepare_checkpoint_hydration_chassis"
			)

			var empty_plan_report: Dictionary = (
				resident_runtime_bootstrap_snapshot()
			)
			empty_plan_report ["ready"] = false
			empty_plan_report [
				"checkpoint_hydration_chassis"
			] = true
			return empty_plan_report

	var max_steps: int = clampi(
		int(
			context.get(
				"max_steps",
				1
			)
		),
		1,
		2
	)
	var frame_budget_ms: int = clampi(
		int(
			context.get(
				"frame_budget_ms",
				1
			)
		),
		1,
		2
	)

	var report: Dictionary = (
		step_resident_runtime_bootstrap(
			max_steps,
			frame_budget_ms
		)
	)
	var is_ready: bool = bool(
		report.get(
			"complete",
			false
		)
	)

	report ["ready"] = is_ready
	report [
		"checkpoint_hydration_chassis"
	] = true
	report [
		"runtime_engine_graph_resident"
	] = is_ready
	report [
		"constructor_work_on_ui_thread_unbounded"
	] = false
	report [
		"constructor_work_on_tab_click"
	] = false

	if is_ready:
		report ["progress"] = 1.0
		report ["overall_progress"] = 1.0
		report ["stage_id"] = "complete"

		if typeof(
			scenario_state
		) != TYPE_DICTIONARY:
			scenario_state = {}

		scenario_state [
			"checkpoint_hydration_chassis_active"
		] = false
		scenario_state [
			"checkpoint_hydration_chassis_complete"
		] = true
		scenario_state [
			"checkpoint_hydration_chassis_completed_at_ms"
		] = int(
			Time.get_ticks_msec()
		)
		scenario_state [
			"resident_runtime_execution_mode"
		] = "checkpoint_hydration_ready"

	return report
func _resident_engine_step(
	property_name: StringName,
	engine_class: GDScript
) -> Dictionary:
	return {
		"step_id": (
			"engine:%s"
			% str(property_name)
		),
		"runner": Callable(
			self,
			"_resident_execute_engine_step"
		).bind(
			property_name,
			engine_class
		),
		"engine_property": property_name,
		"engine_class_name": (
			engine_class.get_global_name()
			if engine_class != null
			else StringName()
		),
	}
func _resident_execute_engine_step(
	property_name: StringName,
	engine_class: GDScript
) -> Dictionary:
	var resident_instance: Variant = get(
		property_name
	)

	if resident_instance != null:







		resident_runtime_engine_became_resident.emit(
			property_name,
			resident_instance
		)

		return {
			"success": true,
			"mode": "engine_already_resident",
			"engine_property": property_name,
		}

	if engine_class == null:
		return {
			"success": false,
			"reason": "engine_class_missing",
			"engine_property": property_name
		}

	if not engine_class.can_instantiate():
		return {
			"success": false,
			"reason": "engine_class_cannot_instantiate",
			"engine_property": property_name,
			"engine_class_name": engine_class.get_global_name()
		}

	var instance: Variant = engine_class.new(self)

	if instance == null:
		return {
			"success": false,
			"reason": "engine_factory_returned_null",
			"engine_property": property_name,
			"engine_class_name": engine_class.get_global_name()
		}

	set(
		property_name,
		instance
	)






	resident_runtime_engine_became_resident.emit(
		property_name,
		instance
	)

	return {
		"success": true,
		"mode": "engine_became_resident",
		"engine_property": property_name,
		"engine_class_name": engine_class.get_global_name(),
	}
func _resident_action_step(
	step_id: String,
	runner: Callable
) -> Dictionary:
	return {
		"step_id": step_id,
		"runner": Callable(
			self,
			"_resident_execute_action_step_contract"
		).bind(
			step_id,
			runner
		),
	}
func _resident_execute_action_step_contract(
	step_id: String,
	runner: Callable
) -> Dictionary:
	if not runner.is_valid():
		return {
			"success": false,
			"complete": true,
			"reason": "invalid_action_step_callable",
			"step_id": step_id,
			"constitutional_gate_member": true
		}

	var result: Variant = runner.call()

	var report: Dictionary = (
		(result as Dictionary).duplicate(true)
		if typeof(result) == TYPE_DICTIONARY
		else {
			"success": true,
			"complete": true
		}
	)

	var constitutional_gate_member: bool = bool(
		report.get(
			"constitutional_gate_member",
			true
		)
	)

	report [
		"constitutional_gate_member"
	] = constitutional_gate_member

	if constitutional_gate_member:
		return report

	var authority_success: bool = bool(
		report.get(
			"success",
			true
		)
	)

	var authority_complete: bool = bool(
		report.get(
			"complete",
			true
		)
	)

	var authority_progress: float = clampf(
		float(
			report.get(
				"progress",
				1.0 if authority_complete else 0.0
			)
		),
		0.0,
		1.0
	)



	report [
		"authority_success"
	] = authority_success

	report [
		"authority_complete"
	] = authority_complete

	report [
		"authority_progress"
	] = authority_progress

	report [
		"optional_extension_degraded"
	] = (
		not authority_success
		or not authority_complete
		or bool(
			report.get(
				"optional_extension_degraded",
				false
			)
		)
	)




	report [
		"success"
	] = true

	report [
		"complete"
	] = true

	report [
		"resident_chassis_blocked"
	] = false

	report [
		"resident_runtime_exists_gate_member"
	] = false

	report [
		"ready_gate_member"
	] = false

	report [
		"blocks_ready_door"
	] = false

	report [
		"blocks_ui"
	] = false

	if typeof(
		scenario_state
	) != TYPE_DICTIONARY:
		scenario_state = {}

	var optional_reports_raw: Variant = (
		scenario_state.get(
			"resident_optional_extension_reports",
			{}
		)
	)

	var optional_reports: Dictionary = (
		(optional_reports_raw as Dictionary).duplicate(false)
		if typeof(optional_reports_raw) == TYPE_DICTIONARY
		else {}
	)

	optional_reports [
		step_id
	] = report.duplicate(true)

	scenario_state [
		"resident_optional_extension_reports"
	] = optional_reports

	scenario_state [
		"resident_optional_extension_last_step_id"
	] = step_id

	scenario_state [
		"resident_optional_extension_last_success"
	] = authority_success

	scenario_state [
		"resident_optional_extension_last_complete"
	] = authority_complete

	scenario_state [
		"resident_optional_extensions_block_ready"
	] = false

	return report
func _resident_runtime_engine_steps() -> Array:
	return [
		_resident_engine_step(
			"game_state_contract_engine",
			GameStateContractEngine
		),
		_resident_action_step(
			"bind_contract_meta_governor",
			Callable(
				self,
				"_resident_bind_contract_meta_governor"
			)
		),
		_resident_engine_step(
			"event_bus",
			EventBus
		),
		_resident_action_step(
			"bind_event_bus_contract_layer",
			Callable(
				self,
				"_resident_bind_event_bus_contract_layer"
			)
		),
		_resident_engine_step(
			"world_space_engine",
			WorldSpaceEngine
		),
		_resident_engine_step(
			"spatial_culling_engine",
			SpatialCullingEngine
		),
		_resident_engine_step(
			"emergent_story_engine",
			EmergentNPCStoryEngine
		),
		_resident_engine_step(
			"economy_engine",
			EconomyEngine
		),
		_resident_engine_step(
			"bank_engine",
			BankEngine
		),
		_resident_engine_step(
			"historical_timeline_engine",
			HistoricalTimelineEngine
		),
		_resident_engine_step(
			"global_market_engine",
			GlobalMarketEngine
		),
		_resident_engine_step(
			"ecs_engine",
			ECSEngine
		),
		_resident_engine_step(
			"chunk_simulation_engine",
			ChunkSimulationEngine
		),
		_resident_engine_step(
			"population_shard_engine",
			PopulationShardEngine
		),
		_resident_engine_step(
			"population_lifecycle_manager",
			PopulationLifecycleManager
		),
		_resident_engine_step(
			"geo_engine",
			GeoEngine
		),
		_resident_engine_step(
			"settlement_presence_engine",
			SettlementPresenceEngine
		),
		_resident_engine_step(
			"migration_engine",
			MigrationEngine
		),
		_resident_engine_step(
			"place_influence_engine",
			PlaceInfluenceEngine
		),
		_resident_engine_step(
			"seed_engine",
			SeedEngine
		),
		_resident_action_step(
			"initialize_seed_authority",
			Callable(
				self,
				"_resident_initialize_seed_authority"
			)
		),
		_resident_engine_step(
			"soul_seed_engine",
			SoulSeedEngine
		),
		_resident_engine_step(
			"consciousness_engine",
			ConsciousnessEngine
		),
		_resident_engine_step(
			"willpower_engine",
			WillpowerEngine
		),
		_resident_engine_step(
			"social_graph_engine",
			SocialGraphEngine
		),
		_resident_engine_step(
			"workplace_engine",
			WorkplaceEngine
		),
		_resident_engine_step(
			"player_action_engine",
			PlayerActionEngine
		),
		_resident_engine_step(
			"npc_memory_web_engine",
			NPCMemoryWebEngine
		),
		_resident_engine_step(
			"agent_memory_propagation_engine",
			AgentMemoryPropagationEngine
		),
		_resident_engine_step(
			"dynamic_world_event_engine",
			DynamicWorldEventEngine
		),
		_resident_engine_step(
			"action_discovery_engine",
			ActionDiscoveryEngine
		),
		_resident_engine_step(
			"names_db",
			NamesDB
		),
		_resident_engine_step(
			"npc_factory",
			NPCFactory
		),
		_resident_engine_step(
			"character_creator",
			CharacterCreator
		),
		_resident_engine_step(
			"legacy_memory_engine",
			LegacyMemoryEngine
		),
		_resident_engine_step(
			"legacy_echo_engine",
			LegacyEchoEngine
		),
		_resident_engine_step(
			"afterlife_influence_engine",
			AfterlifeInfluenceEngine
		),
		_resident_engine_step(
			"scenario_resolver",
			ScenarioResolver
		),
		_resident_engine_step(
			"scenario_engine",
			ScenarioEngine
		),
		_resident_engine_step(
			"scenario_popup_contract_engine",
			ScenarioPopupContractEngine
		),
		_resident_engine_step(
			"scenario_runtime_contract_engine",
			ScenarioRuntimeContractEngine
		),
		_resident_engine_step(
			"pending_situations_engine",
			PendingSituationsEngine
		),
		_resident_engine_step(
			"contract_view_layer_contract_engine",
			ContractViewLayerContractEngine
		),
		_resident_engine_step(
			"traits_contract_engine",
			TraitsContractEngine
		),
		_resident_engine_step(
			"identity_contract_engine",
			IdentityContractEngine
		),
		_resident_engine_step(
			"red_bonnet_engine",
			RedBonnetEngine
		),
		_resident_engine_step(
			"world_engine",
			WorldEngine
		),
		_resident_engine_step(
			"event_engine",
			EventEngine
		),
		_resident_engine_step(
			"personality_engine",
			PersonalityEngine
		),
		_resident_engine_step(
			"relationship_engine",
			RelationshipEngine
		),
		_resident_engine_step(
			"memory_engine",
			MemoryEngine
		),
		_resident_engine_step(
			"health_engine",
			HealthEngine
		),
		_resident_engine_step(
			"genetics_inheritance_engine",
			GeneticsInheritanceEngine
		),
		_resident_engine_step(
			"body_type_contract_engine",
			BodyTypeContractEngine
		),
		_resident_engine_step(
			"growth_curve_engine",
			GrowthCurveEngine
		),
		_resident_engine_step(
			"height_contract_engine",
			HeightContractEngine
		),
		_resident_engine_step(
			"weight_contract_engine",
			WeightContractEngine
		),
		_resident_engine_step(
			"human_contract_engine",
			HumanContractEngine
		),
		_resident_engine_step(
			"animal_contract_engine",
			AnimalContractEngine
		),
		_resident_engine_step(
			"mythical_contract_engine",
			MythicalContractEngine
		),
		_resident_engine_step(
			"relationship_graph_contract_engine",
			RelationshipGraphContractEngine
		),
		_resident_engine_step(
			"human_relationship_contract_engine",
			HumanRelationshipContractEngine
		),
		_resident_engine_step(
			"pets_contract_engine",
			PetsContractEngine
		),
		_resident_engine_step(
			"mythical_pets_contract_engine",
			MythicalPetsContractEngine
		),
		_resident_engine_step(
			"pet_shop_contract_engine",
			PetShopContractEngine
		),
		_resident_engine_step(
			"breeding_contract_engine",
			BreedingContractEngine
		),
		_resident_engine_step(
			"debt_contract_engine",
			DebtContractEngine
		),
		_resident_engine_step(
			"meat_market_contract_engine",
			MeatMarketContractEngine
		),
		_resident_engine_step(
			"career_runtime_engine",
			CareerRuntimeEngine
		),
		_resident_engine_step(
			"career_contract_engine",
			CareerContractEngine
		),
		_resident_engine_step(
			"career_space_contract_engine",
			CareerSpaceContractEngine
		),
		_resident_engine_step(
			"career_hub_contract_engine",
			CareerHubContractEngine
		),
		_resident_engine_step(
			"career_engine",
			CareerEngine
		),
		_resident_engine_step(
			"activities_contract_engine",
			ActivitiesContractEngine
		),
		_resident_engine_step(
			"activities_hub_contract_engine",
			ActivitiesHubContractEngine
		),
		_resident_engine_step(
			"mod_contract_engine",
			ModContractEngine
		),
		_resident_engine_step(
			"caveman_reality_runtime_engine",
			CavemanRealityRuntimeEngine
		),
		_resident_engine_step(
			"mod_bundle_contract_engine",
			ModBundleContractEngine
		),
		_resident_engine_step(
			"mod_marketplace_contract_engine",
			ModMarketplaceContractEngine
		),
		_resident_engine_step(
			"mod_hub_contract_engine",
			ModHubContractEngine
		),
		_resident_engine_step(
			"mod_menu_contract_engine",
			ModMenuContractEngine
		),
		_resident_action_step(
			"bootstrap_mod_bundle_contracts",
			Callable(
				self,
				"_resident_bootstrap_mod_bundle_contracts"
			)
		),
		_resident_engine_step(
			"school_engine",
			SchoolEngine
		),
		_resident_engine_step(
			"school_hub_contract_engine",
			SchoolHubContractEngine
		),
		_resident_engine_step(
			"family_contract_engine",
			FamilyContractEngine
		),
		_resident_engine_step(
			"family_control_engine",
			FamilyControlEngine
		),
		_resident_engine_step(
			"global_intent_contract_engine",
			GlobalIntentContractEngine
		),
		_resident_engine_step(
			"universal_switch_contract_engine",
			UniversalSwitchContractEngine
		),
		_resident_engine_step(
			"relationships_hub_contract_engine",
			RelationshipsHubContractEngine
		),
		_resident_engine_step(
			"crr_contract_engine",
			CRRContractEngine
		),
		_resident_engine_step(
			"opportunity_engine",
			OpportunityEngine
		),
		_resident_engine_step(
			"fate_engine",
			FateEngine
		),
		_resident_engine_step(
			"life_engine",
			LifeEngine
		),
		_resident_engine_step(
			"life_diary_contract_engine",
			LifeDiaryContractEngine
		),
		_resident_engine_step(
			"narrative_engine",
			NarrativeEngine
		),
		_resident_engine_step(
			"llm_bridge",
			LLMNarrativeBridge
		),
		_resident_engine_step(
			"bending_engine",
			BendingEngine
		),
		_resident_engine_step(
			"bending_tournament_engine",
			BendingTournamentEngine
		),
		_resident_engine_step(
			"avatar_influence_engine",
			AvatarInfluenceEngine
		),
		_resident_engine_step(
			"bending_dojo_engine",
			BendingDojoEngine
		),
		_resident_engine_step(
			"wizard_engine",
			WizardEngine
		),
		_resident_engine_step(
			"power_engine",
			PowerEngine
		),
		_resident_engine_step(
			"superhero_engine",
			SuperHeroEngine
		),
		_resident_engine_step(
			"infamy_engine",
			InfamyEngine
		),
		_resident_engine_step(
			"dynasty_engine",
			DynastyEngine
		),
		_resident_engine_step(
			"era_engine",
			EraEngine
		),
		_resident_engine_step(
			"era_mod_contract_engine",
			EraModContractEngine
		),
		_resident_engine_step(
			"era_contract_engine",
			EraContractEngine
		),
		_resident_action_step(
			"bootstrap_era_contracts",
			Callable(
				self,
				"_resident_bootstrap_era_contracts"
			)
		),
		_resident_engine_step(
			"world_feed_engine",
			WorldFeedEngine
		),
		_resident_engine_step(
			"world_chronicle_engine",
			WorldChronicleEngine
		),
		_resident_engine_step(
			"reputation_engine",
			ReputationEngine
		),
		_resident_engine_step(
			"artifacts_engine",
			ArtifactsEngine
		),
		_resident_engine_step(
			"artifacts_catalog_contract_engine",
			ArtifactsCatalogContractEngine
		),
		_resident_engine_step(
			"artifact_interaction_contract_engine",
			ArtifactInteractionContractEngine
		),
		_resident_engine_step(
			"artifact_shop_contract_engine",
			ArtifactShopContractEngine
		),
		_resident_engine_step(
			"realm_contract_engine",
			RealmContractEngine
		),
		_resident_engine_step(
			"simulation_contract_engine",
			SimulationContractEngine
		),
		_resident_engine_step(
			"runtime_contract_engine",
			RuntimeContractEngine
		),
		_resident_engine_step(
			"romance_contract_engine",
			RomanceContractEngine
		),
		_resident_engine_step(
			"ui_contract_engine",
			UIContractEngine
		),
		_resident_engine_step(
			"embedded_ui_contract_engine",
			EmbeddedUIContractEngine
		),
		_resident_engine_step(
			"birth_contract_engine",
			BirthContractEngine
		),
		_resident_engine_step(
			"many_realms_engine",
			ManyRealmsEngine
		),
		_resident_engine_step(
			"bridge_to_terabithia_engine",
			BridgeToTerabithiaEngine
		),
		_resident_engine_step(
			"vormir_engine",
			VormirEngine
		),
		_resident_engine_step(
			"nidavellir_engine",
			NidavellirEngine
		),
		_resident_engine_step(
			"dragonballs_engine",
			DragonBallsEngine
		),
		_resident_engine_step(
			"dynasty_legacy_engine",
			DynastyLegacyEngine
		),
		_resident_engine_step(
			"weapons_engine",
			WeaponsEngine
		),
		_resident_engine_step(
			"weapons_catalog_expansion",
			WeaponsCatalogExpansion
		),
		_resident_engine_step(
			"crime_contract_engine",
			CrimeContractEngine
		),
		_resident_engine_step(
			"investigation_layer",
			InvestigationLayer
		),
		_resident_engine_step(
			"justice_system_engine",
			JusticeSystemEngine
		),
		_resident_engine_step(
			"jail_engine",
			JailEngine
		),
		_resident_engine_step(
			"prison_engine",
			PrisonEngine
		),
		_resident_engine_step(
			"case_orchestrator",
			CaseOrchestrator
		),
		_resident_engine_step(
			"crime_engine",
			CrimeEngine
		),
		_resident_engine_step(
			"crime_hub_contract_engine",
			CrimeHubContractEngine
		),
		_resident_engine_step(
			"relationship_activities_engine",
			RelationshipActivitiesEngine
		),
		_resident_engine_step(
			"realm_engine",
			RealmEngine
		),
		_resident_engine_step(
			"class_engine",
			ClassEngine
		),
		_resident_engine_step(
			"fame_engine",
			FameEngine
		),
		_resident_engine_step(
			"upce_engine",
			UniversalPerceptionConsequenceEngine
		),
		_resident_action_step(
			"bootstrap_upce_contracts",
			Callable(
				self,
				"_resident_bootstrap_upce_contracts"
			)
		),
		_resident_engine_step(
			"royalty_engine",
			RoyaltyEngine
		),
		_resident_engine_step(
			"royalty_runtime_engine",
			RoyaltyRuntimeEngine
		),
		_resident_engine_step(
			"royalty_mod_contract_engine",
			RoyaltyModContractEngine
		),
		_resident_engine_step(
			"royalty_contract_engine",
			RoyaltyContractEngine
		),
		_resident_engine_step(
			"crown_hub_contract_engine",
			CrownHubContractEngine
		),
		_resident_action_step(
			"bootstrap_royalty_contracts",
			Callable(
				self,
				"_resident_bootstrap_royalty_contracts"
			)
		),
		_resident_engine_step(
			"politics_engine",
			PoliticsEngine
		),
		_resident_engine_step(
			"property_engine",
			PropertyEngine
		),
		_resident_engine_step(
			"era_life_asset_catalog_expansion",
			EraLifeAssetCatalogExpansion
		),
		_resident_engine_step(
			"assets_contract_engine",
			AssetsContractEngine
		),
		_resident_engine_step(
			"property_amenity_synthesis_contract_engine",
			PropertyAmenitySynthesisContractEngine
		),
		_resident_engine_step(
			"room_graph_contract_engine",
			RoomGraphContractEngine
		),
		_resident_engine_step(
			"presence_engine",
			PresenceEngine
		),
		_resident_engine_step(
			"property_makeover_contract_engine",
			PropertyMakeoverContractEngine
		),
		_resident_engine_step(
			"vehicle_engine",
			VehicleEngine
		),
		_resident_engine_step(
			"card_contract_engine",
			CardContractEngine
		),
		_resident_engine_step(
			"property_market_contract_engine",
			PropertyMarketContractEngine
		),
		_resident_engine_step(
			"spatial_traversal_contract_engine",
			SpatialTraversalContractEngine
		),
		_resident_engine_step(
			"dealership_contract_engine",
			DealershipContractEngine
		),
		_resident_engine_step(
			"shared_public_space_engine",
			SharedPublicSpaceEngine
		),
		_resident_engine_step(
			"food_engine",
			FoodEngine
		),
		_resident_engine_step(
			"food_restaurant_engine",
			FoodRestaurantEngine
		),
		_resident_engine_step(
			"grocery_store_engine",
			GroceryStoreEngine
		),
		_resident_engine_step(
			"movie_theater_engine",
			MovieTheaterEngine
		),
		_resident_action_step(
			"bootstrap_movie_theater_contracts",
			Callable(
				self,
				"_resident_bootstrap_movie_theater_contracts"
			)
		),
		_resident_engine_step(
			"luxury_shop_engine",
			LuxuryShopEngine
		),
		_resident_engine_step(
			"heirloom_runtime_engine",
			HeirloomRuntimeEngine
		),
		_resident_engine_step(
			"heirloom_contract_engine",
			HeirloomContractEngine
		),
		_resident_engine_step(
			"heirloom_engine",
			HeirloomEngine
		),
		_resident_engine_step(
			"heirloom_catalog_contract_engine",
			HeirloomCatalogContractEngine
		),
		_resident_engine_step(
			"heirloom_hub_contract_engine",
			HeirloomHubContractEngine
		),
		_resident_engine_step(
			"island_realm_engine",
			IslandRealmExpansionEngine
		),
		_resident_engine_step(
			"population_movement_contract_engine",
			PopulationMovementContractEngine
		),
		_resident_engine_step(
			"global_prewarm_contract_engine",
			GlobalPrewarmContractEngine
		),
		_resident_engine_step(
			"global_node_contract_engine",
			GlobalNodeContractEngine
		),
		_resident_engine_step(
			"truth_resolution_contract_engine",
			TruthResolutionContractEngine
		),
		_resident_engine_step(
			"observable_node_contract_engine",
			ObservableNodeContractEngine
		),
		_resident_engine_step(
			"world_observability_contract_engine",
			WorldObservabilityContractEngine
		),




		_resident_engine_step(
			"population_movement_contract_engine",
			PopulationMovementContractEngine
		),
		_resident_engine_step(
			"crown_population_view_contract",
			CrownPopulationViewContract
		),
		_resident_engine_step(
			"population_card_contract_engine",
			PopulationCardContractEngine
		),
		_resident_engine_step(
			"belongings_engine",
			BelongingsEngine
		),
		_resident_action_step(
			"bootstrap_heirloom_contracts",
			Callable(
				self,
				"_resident_bootstrap_heirloom_contracts"
			)
		),
		_resident_engine_step(
			"global_object_catalog_system",
			GlobalObjectCatalogSystem
		),
		_resident_engine_step(
			"object_hub_contract_engine",
			ObjectHubContractEngine
		),
		_resident_action_step(
			"bootstrap_global_object_catalog",
			Callable(
				self,
				"_resident_bootstrap_global_object_catalog"
			)
		),
		_resident_action_step(
			"bootstrap_object_projection_contracts",
			Callable(
				self,
				"_resident_bootstrap_object_projection_contracts"
			)
		),
		_resident_engine_step(
			"desire_engine",
			DesireEngine
		),
		_resident_engine_step(
			"capability_graph_engine",
			CapabilityGraphEngine
		),
		_resident_engine_step(
			"goal_planning_engine",
			GoalPlanningEngine
		),
		_resident_engine_step(
			"simulation_director",
			SimulationDirector
		),
		_resident_engine_step(
			"year_budget_engine",
			YearBudgetEngine
		),
		_resident_engine_step(
			"desire_behavior_bridge",
			DesireBehaviorBridge
		),
		_resident_engine_step(
			"ai_event_engine",
			AIEventGenerator
		),
		_resident_engine_step(
			"era_data_loader",
			EraDataLoader
		),
		_resident_engine_step(
			"weapon_pack_loader",
			WeaponPackLoader
		),
		_resident_engine_step(
			"mod_loader",
			ModLoader
		),
		_resident_engine_step(
			"boxing_contract_engine",
			BoxingContractEngine
		),
		_resident_engine_step(
			"boxing_fighter_engine",
			BoxingFighterEngine
		),
		_resident_engine_step(
			"boxing_training_engine",
			BoxingTrainingEngine
		),
		_resident_engine_step(
			"boxing_matchmaking_engine",
			BoxingMatchmakingEngine
		),
		_resident_engine_step(
			"boxing_fight_sim_engine",
			BoxingFightSimEngine
		),
		_resident_engine_step(
			"boxing_ranking_engine",
			BoxingRankingEngine
		),
		_resident_engine_step(
			"boxing_title_engine",
			BoxingTitleEngine
		),
		_resident_engine_step(
			"boxing_injury_engine",
			BoxingInjuryEngine
		),
		_resident_engine_step(
			"boxing_engine",
			BoxingEngine
		),
		_resident_engine_step(
			"boxing_round_log_engine",
			BoxingRoundLogEngine
		),
		_resident_engine_step(
			"boxing_rivalry_engine",
			BoxingRivalryEngine
		),
		_resident_engine_step(
			"boxing_promotion_engine",
			BoxingPromotionEngine
		),
		_resident_engine_step(
			"boxing_weight_engine",
			BoxingWeightEngine
		),
		_resident_engine_step(
			"boxing_mandatory_engine",
			BoxingMandatoryEngine
		),
		_resident_engine_step(
			"boxing_amateur_engine",
			BoxingAmateurEngine
		),
		_resident_engine_step(
			"boxing_media_engine",
			BoxingMediaEngine
		),
		_resident_engine_step(
			"boxing_gym_engine",
			BoxingGymEngine
		),
		_resident_engine_step(
			"boxing_legacy_engine",
			BoxingLegacyEngine
		),
		_resident_action_step(
			"bootstrap_boxing_contract",
			Callable(
				self,
				"_resident_bootstrap_boxing_contract"
			)
		),
		_resident_engine_step(
			"competitive_reality_runtime",
			CompetitiveRealityRuntime
		),
		_resident_action_step(
			"bootstrap_competitive_reality_contracts",
			Callable(
				self,
				"_resident_bootstrap_competitive_reality_contracts"
			)
		),
		_resident_engine_step(
			"reality_surge_engine",
			RealitySurgeEngine
		),
		_resident_action_step(
			"bootstrap_reality_surge_contracts",
			Callable(
				self,
				"_resident_bootstrap_reality_surge_contracts"
			)
		),
		_resident_engine_step(
			"reality_orchestrator",
			RealityOrchestrator
		),
		_resident_action_step(
			"bootstrap_reality_orchestrator_contracts",
			Callable(
				self,
				"_resident_bootstrap_reality_orchestrator_contracts"
			)
		),
		_resident_engine_step(
			"vampire_origin_engine",
			VampireOriginEngine
		),
		_resident_engine_step(
			"vampire_hunger_engine",
			VampireHungerEngine
		),
		_resident_engine_step(
			"vampire_ability_engine",
			VampireAbilityEngine
		),
		_resident_engine_step(
			"vampire_society_engine",
			VampireSocietyEngine
		),
		_resident_engine_step(
			"vampire_hunter_engine",
			VampireHunterEngine
		),
		_resident_engine_step(
			"vampire_legacy_engine",
			VampireLegacyEngine
		),
		_resident_engine_step(
			"vampire_masquerade_engine",
			VampireMasqueradeEngine
		),
		_resident_engine_step(
			"vampire_cure_engine",
			VampireCureEngine
		),
		_resident_engine_step(
			"vampire_engine",
			VampireEngine
		),
		_resident_engine_step(
			"universal_faction_engine",
			UniversalFactionEngine
		),
		_resident_engine_step(
			"runtime_health_registry",
			RuntimeHealthRegistry
		),
		_resident_engine_step(
			"runtime_fault_router",
			RuntimeFaultRouter
		),
		_resident_engine_step(
			"patch_suggestion_engine",
			PatchSuggestionEngine
		),
		_resident_engine_step(
			"live_patch_guard",
			LivePatchGuard
		),
		_resident_engine_step(
			"auto_patch_engine",
			AutoPatchEngine
		),
		_resident_engine_step(
			"live_diagnostics_engine",
			LiveDiagnosticsEngine
		),
		_resident_action_step(
			"seal_resident_chassis",
			Callable(
				self,
				"_resident_seal_chassis"
			)
		)
	]
func _resident_bootstrap_heirloom_contracts() -> Dictionary:
	var reports: Dictionary = {}

	if heirloom_contract_engine != null:
		reports ["constitution"] = (
			heirloom_contract_engine
			.bootstrap_default_contracts()
		)

	if heirloom_runtime_engine != null:
		reports ["runtime"] = (
			heirloom_runtime_engine
			.bootstrap_default_contracts()
		)

	if heirloom_engine != null:
		reports ["compatibility_facade"] = (
			heirloom_engine
			.bootstrap_default_contracts()
		)

	if heirloom_catalog_contract_engine != null:
		reports ["catalog"] = (
			heirloom_catalog_contract_engine
			.bootstrap_default_contracts()
		)

	if heirloom_hub_contract_engine != null:
		reports ["hub"] = (
			heirloom_hub_contract_engine
			.bootstrap_default_contracts()
		)

	var success: bool = (
		heirloom_runtime_engine != null
		and heirloom_contract_engine != null
		and heirloom_engine != null
		and heirloom_catalog_contract_engine != null
		and heirloom_hub_contract_engine != null
	)

	return {
		"success": success,
		"complete": true,
		"mode": (
			"heirloom_contract_ecosystem_bootstrapped"
		),
		"reports": reports.duplicate(true),
		"runtime_authority": "heirloom_runtime_engine",
		"constitutional_authority": (
			"heirloom_contract_engine"
		),
		"compatibility_facade": "heirloom_engine",
		"catalog_authority": (
			"heirloom_catalog_contract_engine"
		),
		"hub_authority": (
			"heirloom_hub_contract_engine"
		),
		"ui_is_renderer_only": true
	}
func _resident_bootstrap_object_projection_contracts() -> Dictionary:
	var reports: Dictionary = {}

	if artifact_interaction_contract_engine != null:
		reports ["artifact_interaction"] = (
			artifact_interaction_contract_engine
			.bootstrap_default_contracts()
		)

	if artifact_shop_contract_engine != null:
		reports ["artifact_shop"] = (
			artifact_shop_contract_engine
			.bootstrap_default_contracts()
		)

	if object_hub_contract_engine != null:
		reports ["object_hub"] = (
			object_hub_contract_engine
			.bootstrap_default_contracts()
		)

	return {
		"success": (
			artifact_interaction_contract_engine != null
			and artifact_shop_contract_engine != null
			and object_hub_contract_engine != null
		),
		"complete": true,
		"mode": (
			"object_projection_contracts_bootstrapped"
		),
		"reports": reports.duplicate(true),
		"ui_is_renderer_only": true
	}
func _resident_bootstrap_global_object_catalog() -> Dictionary:
	var provider_reports: Dictionary = {}

	if artifacts_catalog_contract_engine != null:
		provider_reports ["artifacts"] = (
			artifacts_catalog_contract_engine
			.bootstrap_default_contracts()
		)

	if weapons_catalog_expansion != null:
		provider_reports ["weapons"] = (
			weapons_catalog_expansion
			.bootstrap_default_contracts()
		)

	if heirloom_catalog_contract_engine != null:
		provider_reports ["heirlooms"] = (
			heirloom_catalog_contract_engine
			.bootstrap_default_contracts()
		)

	if global_object_catalog_system == null:
		return {
			"success": false,
			"complete": true,
			"reason": (
				"global_object_catalog_system_unavailable"
			),
			"provider_reports": (
				provider_reports.duplicate(true)
			),
			"ui_is_renderer_only": true
		}

	var catalog_report: Dictionary = (
		global_object_catalog_system
		.bootstrap_default_providers()
	)

	return {
		"success": bool(
			catalog_report.get(
				"success",
				true
			)
		),
		"complete": true,
		"mode": (
			"global_object_catalog_bootstrapped"
		),
		"provider_reports": (
			provider_reports.duplicate(true)
		),
		"catalog_report": (
			catalog_report.duplicate(true)
		),
		"provider_count": int(
			catalog_report.get(
				"provider_count",
				0
			)
		),
		"ui_is_renderer_only": true
	}
func _resident_bind_constructor_context(
	settings: Dictionary,
	context: Dictionary = {}
) -> void:
	if typeof(
		scenario_state
	) != TYPE_DICTIONARY:
		scenario_state = {}

	custom_mode = bool(
		context.get(
			"custom_mode",
			true
		)
	)
	awaiting_new_life = false
	afterlife_active = false
	custom_settings = settings.duplicate(true)
	year = int(
		custom_settings.get(
			"year",
			year
		)
	)

	var signature: String = str(
		context.get(
			"signature",
			resident_runtime_bootstrap_signature
		)
	).strip_edges()
	var prewarm_contract: Dictionary = _resident_dict(
		context.get(
			"prewarm_contract",
			{}
		)
	)
	var candidate: Dictionary = _resident_dict(
		custom_settings.get(
			"_prebirth_reality_candidate",
			prewarm_contract.get(
				"prebirth_candidate",
				{}
			)
		)
	)
	var seed_contract: Dictionary = _resident_dict(
		custom_settings.get(
			"seed_contract",
			prewarm_contract.get(
				"seed_contract",
				{}
			)
		)
	)
	var world_seed: int = int(
		custom_settings.get(
			"world_seed",
			seed_contract.get(
				"seed",
				prewarm_contract.get(
					"world_seed",
					-1
				)
			)
		)
	)
	var context_bootstrap_mode: String = str(
		context.get(
			"resident_runtime_bootstrap_mode",
			resident_runtime_bootstrap_mode
		)
	).strip_edges().to_lower()
	var reality_binding_requested: bool = (
		context_bootstrap_mode == "reality_binding"
		or resident_runtime_bootstrap_mode == "reality_binding"
		or bool(
			context.get(
				"reality_binding_requested",
				false
			)
		)
	)
	var seed_materialization_authorized: bool = (
		reality_binding_requested
		and bool(
			context.get(
				"seed_materialization_authorized",
				true
			)
		)
	)




	scenario_state [
		"resident_runtime_reality_binding_requested"
	] = reality_binding_requested
	scenario_state [
		"resident_runtime_generic_chassis"
	] = not reality_binding_requested
	scenario_state [
		"resident_world_seed_materialization_authorized"
	] = seed_materialization_authorized
	scenario_state [
		"resident_world_seed_materialization_authority"
	] = (
		"bound_first_life_reality"
		if seed_materialization_authorized
		else "generic_chassis_forbidden"
	)
	scenario_state [
		"god_mode_candidate_seed_only"
	] = not seed_materialization_authorized

	scenario_state [
		"god_mode_life_prewarm_active"
	] = reality_binding_requested
	scenario_state ["god_mode_life_prewarm_contract"] = (
		prewarm_contract.duplicate(true)
	)
	scenario_state ["god_mode_life_prewarm_signature"] = signature
	scenario_state ["god_mode_prebirth_reality_candidate"] = (
		candidate.duplicate(true)
	)
	scenario_state ["world_seed"] = (
		world_seed
		if reality_binding_requested
		else -1
	)
	scenario_state ["seed_contract"] = (
		seed_contract.duplicate(true)
		if reality_binding_requested
		else {}
	)
	scenario_state [
		"single_target_reality"
	] = reality_binding_requested
	scenario_state [
		"prebirth_reality_locked"
	] = reality_binding_requested
	scenario_state [
		"hydrate_player_before_surrounding_world"
	] = reality_binding_requested
	scenario_state [
		"interactive_boot_requested"
	] = reality_binding_requested
	scenario_state [
		"birth_shell_fast_first_paint"
	] = reality_binding_requested
	scenario_state ["birth_shell_first_boot"] = false
	scenario_state [
		"birth_shell_first_boot_active"
	] = reality_binding_requested
	scenario_state ["birth_shell_deferred_boot_pending"] = true
	scenario_state ["birth_shell_deferred_boot_complete"] = false
	scenario_state ["birth_shell_npc_count"] = int(
		context.get(
			"birth_shell_npc_count",
			scenario_state.get(
				"birth_shell_npc_count",
				0
			)
		)
	)
	scenario_state ["defer_static_world_bootstrap"] = true
	scenario_state [
		"royalty_heavy_bootstrap_forbidden_during_prewarm"
	] = true
	scenario_state [
		"royal_house_heavy_bootstrap_deferred"
	] = true
	scenario_state [
		"royal_first_frame_shell_truth_only"
	] = true
	scenario_state ["defer_live_runtime_watchers"] = true
	scenario_state ["deferred_data_bootstrap_pending"] = true
	scenario_state ["deferred_runtime_watchers_bootstrap"] = true
	scenario_state ["static_world_runtime_bootstrapped"] = false
	scenario_state ["post_spawn_ui_finalize_pending"] = true
	scenario_state ["soul_seed_distribution_authorized"] = false
	scenario_state ["soul_seed_distribution_reason"] = (
		"deferred_until_live_shell_control"
		if reality_binding_requested
		else "waiting_for_first_life_reality_binding"
	)
	scenario_state ["soul_seed_priority_family_first"] = true
	scenario_state [
		"soul_seed_background_distribution_deferred"
	] = true
	scenario_state [
		"soul_seed_background_distribution_pending"
	] = reality_binding_requested
	scenario_state ["soul_seed_background_stream_active"] = false
	scenario_state ["soul_seed_background_stream_complete"] = false
	scenario_state [
		"post_spawn_world_prewarm_pending"
	] = reality_binding_requested
	scenario_state ["post_spawn_world_prewarm_mode"] = (
		"idle_microtask_ui_safe"
	)
	scenario_state ["birth_shell_player_control_released"] = false
	scenario_state ["runtime_scene_tree_access_allowed"] = false
	scenario_state ["resident_runtime_signature"] = signature
	scenario_state ["resident_runtime_execution_mode"] = (
		"resident_constructing"
		if reality_binding_requested
		else "resident_chassis_constructing"
	)
	scenario_state ["ui_is_pure_renderer"] = true

func _resident_bind_contract_meta_governor() -> Dictionary:
	if game_state_contract_engine == null:
		return {
			"success": false,
			"reason": "missing_game_state_contract_engine"
		}

	contract_meta_governor = (
		game_state_contract_engine.contract_meta_governor
	)

	return {
		"success": true
	}


func _resident_bind_event_bus_contract_layer() -> Dictionary:
	if event_bus == null:
		return {
			"success": false,
			"reason": "missing_event_bus"
		}

	event_bus_contract_layer = event_bus.contract_layer

	return {
		"success": true
	}


func _resident_initialize_seed_authority() -> Dictionary:
	if seed_engine == null:
		return {
			"success": false,
			"reason": "missing_seed_engine"
		}

	if typeof(
		scenario_state
	) != TYPE_DICTIONARY:
		scenario_state = {}

	if typeof(
		custom_settings
	) != TYPE_DICTIONARY:
		custom_settings = {}

	var prewarm_contract: Dictionary = _resident_dict(
		resident_runtime_binding_context.get(
			"prewarm_contract",
			scenario_state.get(
				"god_mode_life_prewarm_contract",
				{}
			)
		)
	)
	var prewarm_settings: Dictionary = _resident_dict(
		prewarm_contract.get(
			"settings",
			{}
		)
	)
	var candidate: Dictionary = _resident_dict(
		custom_settings.get(
			"_prebirth_reality_candidate",
			prewarm_settings.get(
				"_prebirth_reality_candidate",
				scenario_state.get(
					"god_mode_prebirth_reality_candidate",
					{}
				)
			)
		)
	)
	var seed_contract: Dictionary = _resident_dict(
		custom_settings.get(
			"seed_contract",
			prewarm_settings.get(
				"seed_contract",
				scenario_state.get(
					"seed_contract",
					{}
				)
			)
		)
	)
	var signature: String = str(
		resident_runtime_binding_context.get(
			"signature",
			resident_runtime_bootstrap_signature
		)
	).strip_edges()
	var requested_seed: int = int(
		custom_settings.get(
			"world_seed",
			candidate.get(
				"world_seed",
				seed_contract.get(
					"seed",
					prewarm_settings.get(
						"world_seed",
						scenario_state.get(
							"world_seed",
							-1
						)
					)
				)
			)
		)
	)
	var reality_binding_mode_active: bool = (
		resident_runtime_bootstrap_mode == "reality_binding"
	)
	var seed_materialization_authorized: bool = bool(
		scenario_state.get(
			"resident_world_seed_materialization_authorized",
			false
		)
	)
	var reality_settings_are_bound: bool = (
		reality_binding_mode_active
		and seed_materialization_authorized
	)




	if not reality_settings_are_bound:
		scenario_state ["seed_bootstrap_deferred"] = true
		scenario_state ["seed_bootstrap_reason"] = (
			"waiting_for_first_life_reality_binding"
		)
		scenario_state [
			"seed_bootstrap_rejected_unbound_seed"
		] = requested_seed > 0
		scenario_state [
			"seed_bootstrap_rejected_unbound_seed_value"
		] = (
			requested_seed
			if requested_seed > 0
			else -1
		)
		scenario_state [
			"seed_bootstrap_reality_binding_mode_active"
		] = reality_binding_mode_active
		scenario_state [
			"seed_bootstrap_materialization_authorized"
		] = seed_materialization_authorized
		scenario_state [
			"seed_engine_world_materialized_for_generic_chassis"
		] = false

		return {
			"success": true,
			"requested_seed": requested_seed,
			"seed": -1,
			"world_seed": -1,
			"seed_bootstrap_deferred": true,
			"seed_materialization_authorized": false,
			"reality_binding_mode_active": (
				reality_binding_mode_active
			),
		}

	var generated_seed: bool = false

	if requested_seed <= 0:
		_resident_first_life_seed_sequence += 1

		var entropy_text: String = "%s|%s|%d|%d|%d|%d" % [
			signature,
			str(
				custom_settings.get(
					"_god_mode_entry_kind",
					"first_life"
				)
			),
			int(
				Time.get_unix_time_from_system()
			),
			int(
				Time.get_ticks_usec()
			),
			int(
				get_instance_id()
			),
			_resident_first_life_seed_sequence
		]

		if seed_engine.has_method(
			"derive_seed_from_text"
		):
			requested_seed = int(
				seed_engine.derive_seed_from_text(
					entropy_text
				)
			)
		else:
			requested_seed = int(
				hash(
					entropy_text
				)
			)

		requested_seed = abs(
			requested_seed
		)
		requested_seed = int(
			requested_seed % 2147483646
		) + 1
		generated_seed = true
	else:
		requested_seed = abs(
			requested_seed
		)
		requested_seed = int(
			requested_seed % 2147483646
		)

		if requested_seed <= 0:
			requested_seed = 1

	var candidate_id: String = str(
		candidate.get(
			"candidate_id",
			custom_settings.get(
				"_prebirth_reality_candidate_id",
				""
			)
		)
	).strip_edges()

	if candidate_id == "":
		candidate_id = "first_life:%s:%d" % [
			(
				signature
				if signature != ""
				else "resident"
			),
			requested_seed
		]

	candidate ["candidate_id"] = candidate_id
	candidate ["world_seed"] = requested_seed
	candidate ["single_target_reality"] = true

	seed_contract ["schema"] = str(
		seed_contract.get(
			"schema",
			"eralife.seed_contract"
		)
	)
	seed_contract ["version"] = maxi(
		1,
		int(
			seed_contract.get(
				"version",
				1
			)
		)
	)
	seed_contract ["seed"] = requested_seed
	seed_contract ["candidate_id"] = candidate_id
	seed_contract ["single_target_reality"] = true
	seed_contract ["first_life_seed"] = true

	var seed_report: Dictionary = (
		seed_engine.initialize_from_contract(
			seed_contract.duplicate(true)
		)
	)
	var committed_seed: int = int(
		seed_report.get(
			"seed",
			requested_seed
		)
	)

	if committed_seed <= 0:
		return {
			"success": false,
			"reason": (
				"seed_engine_rejected_first_life_seed"
			),
			"requested_seed": requested_seed,
			"seed_report": seed_report.duplicate(true)
		}

	candidate ["world_seed"] = committed_seed
	seed_contract ["seed"] = committed_seed

	custom_settings ["world_seed"] = committed_seed
	custom_settings ["seed_contract"] = (
		seed_contract.duplicate(true)
	)
	custom_settings ["_prebirth_reality_candidate"] = (
		candidate.duplicate(true)
	)
	custom_settings ["_prebirth_reality_candidate_id"] = (
		candidate_id
	)

	prewarm_settings ["world_seed"] = committed_seed
	prewarm_settings ["seed_contract"] = (
		seed_contract.duplicate(true)
	)
	prewarm_settings ["_prebirth_reality_candidate"] = (
		candidate.duplicate(true)
	)
	prewarm_settings ["_prebirth_reality_candidate_id"] = (
		candidate_id
	)

	prewarm_contract ["world_seed"] = committed_seed
	prewarm_contract ["seed_contract"] = (
		seed_contract.duplicate(true)
	)
	prewarm_contract ["prebirth_candidate"] = (
		candidate.duplicate(true)
	)
	prewarm_contract ["settings"] = (
		prewarm_settings.duplicate(true)
	)

	resident_runtime_binding_settings = (
		custom_settings.duplicate(true)
	)
	resident_runtime_binding_context ["world_seed"] = (
		committed_seed
	)
	resident_runtime_binding_context ["seed_contract"] = (
		seed_contract.duplicate(true)
	)
	resident_runtime_binding_context ["prewarm_contract"] = (
		prewarm_contract.duplicate(true)
	)

	scenario_state ["world_seed"] = committed_seed
	scenario_state ["seed_contract"] = (
		seed_contract.duplicate(true)
	)
	scenario_state ["god_mode_prebirth_reality_candidate"] = (
		candidate.duplicate(true)
	)
	scenario_state ["god_mode_life_prewarm_contract"] = (
		prewarm_contract.duplicate(true)
	)
	scenario_state ["seed_bootstrap_deferred"] = false
	scenario_state [
		"seed_bootstrap_rejected_unbound_seed"
	] = false
	scenario_state [
		"seed_bootstrap_rejected_unbound_seed_value"
	] = -1
	scenario_state [
		"seed_bootstrap_reality_binding_mode_active"
	] = true
	scenario_state [
		"seed_bootstrap_materialization_authorized"
	] = true
	scenario_state [
		"seed_engine_world_materialized_for_generic_chassis"
	] = false
	scenario_state.erase(
		"seed_bootstrap_reason"
	)
	scenario_state [
		"first_life_seed_contract_committed"
	] = true
	scenario_state [
		"first_life_seed_generated_by_residency"
	] = generated_seed
	scenario_state [
		"first_life_seed_committed_at_ms"
	] = int(
		Time.get_ticks_msec()
	)
	scenario_state [
		"first_life_seed_signature"
	] = signature
	scenario_state [
		"first_life_seed_report"
	] = seed_report.duplicate(true)

	return {
		"success": true,
		"requested_seed": requested_seed,
		"seed": committed_seed,
		"world_seed": committed_seed,
		"generated": generated_seed,
		"candidate": candidate.duplicate(true),
		"seed_contract": seed_contract.duplicate(true),
		"seed_report": seed_report.duplicate(true),
		"seed_materialization_authorized": true,
		"seed_bootstrap_deferred": false
	}

func _resident_bootstrap_mod_bundle_contracts() -> Dictionary:
	var mini_game_pack_report: Dictionary = {}
	var mini_game_instantiation_report: Dictionary = {}
	var adobe_flash_bootstrap_report: Dictionary = {}
	var mini_game_bootstrap_report: Dictionary = {}

	if game_state_contract_engine != null:
		mini_game_pack_report = (
			game_state_contract_engine
			.register_builtin_contract_pack_from_path(
				"res://MiniGameEcosystem/MiniGameEcosystemContractPack.gd",
				"builtin_minigame_ecosystem"
			)
		)

		mini_game_instantiation_report = (
			game_state_contract_engine
			.instantiate_contract_engine_extensions_for_ids(
				mini_game_pack_report.get(
					"engine_ids",
					[]
				)
			)
		)

	if adobe_flash_contract_engine != null:
		adobe_flash_bootstrap_report = (
			adobe_flash_contract_engine
			.bootstrap_default_contracts()
		)

	if mini_game_contract_engine != null:
		mini_game_bootstrap_report = (
			mini_game_contract_engine
			.bootstrap_default_contracts()
		)

	if caveman_reality_runtime_engine != null:
		caveman_reality_runtime_engine.bootstrap_default_contracts()

	if mod_bundle_contract_engine != null:
		mod_bundle_contract_engine.bootstrap_default_contracts()

	var required_mini_game_engine_properties: Array = [
		"mini_game_runtime_engine",
		"scoreboard_contract_engine",
		"achievement_contract_engine",
		"replay_contract_engine",
		"multiplayer_contract_engine",
		"adobe_flash_contract_engine",
		"mini_game_host_adapter_engine",
		"mini_game_contract_engine",
		"mini_game_hub_contract_engine"
	]

	var missing_mini_game_engine_properties: Array = []

	for raw_engine_property in required_mini_game_engine_properties:
		var engine_property: String = str(
			raw_engine_property
		).strip_edges()

		if engine_property == "":
			continue

		if get(engine_property) == null:
			missing_mini_game_engine_properties.append(
				engine_property
			)

	var mini_game_instantiation_failures: Array = []

	var instantiation_failures_raw: Variant = (
		mini_game_instantiation_report.get(
			"failed",
			[]
		)
	)

	if typeof(instantiation_failures_raw) == TYPE_ARRAY:
		mini_game_instantiation_failures = (
			(instantiation_failures_raw as Array)
			.duplicate(true)
		)

	var mini_game_pack_registered: bool = bool(
		mini_game_pack_report.get(
			"success",
			false
		)
	)

	var mini_game_provider_resident: bool = (
		mini_game_contract_engine != null
		and bool(
			mini_game_bootstrap_report.get(
				"success",
				false
			)
		)
	)

	var mini_game_ecosystem_resident: bool = (
		mini_game_pack_registered
		and mini_game_instantiation_failures.is_empty()
		and missing_mini_game_engine_properties.is_empty()
		and mini_game_provider_resident
	)

	var optional_extension_reason: String = ""

	if not mini_game_pack_registered:
		optional_extension_reason = str(
			mini_game_pack_report.get(
				"reason",
				"minigame_contract_pack_registration_failed"
			)
		)
	elif not mini_game_instantiation_failures.is_empty():
		optional_extension_reason = (
			"minigame_contract_engine_instantiation_failed"
		)
	elif not missing_mini_game_engine_properties.is_empty():
		optional_extension_reason = (
			"minigame_ecosystem_not_fully_resident"
		)
	elif not mini_game_provider_resident:
		optional_extension_reason = (
			"stick_fighter_provider_bootstrap_failed"
		)

	if typeof(
		scenario_state
	) != TYPE_DICTIONARY:
		scenario_state = {}

	scenario_state [
		"resident_optional_minigame_ecosystem_resident"
	] = mini_game_ecosystem_resident

	scenario_state [
		"resident_optional_minigame_ecosystem_degraded"
	] = not mini_game_ecosystem_resident

	scenario_state [
		"resident_optional_minigame_ecosystem_reason"
	] = optional_extension_reason

	scenario_state [
		"resident_optional_minigame_blocks_hot_chassis"
	] = false

	scenario_state [
		"resident_optional_minigame_blocks_runtime_exists"
	] = false

	scenario_state [
		"resident_optional_minigame_blocks_ready"
	] = false

	return {




		"success": mini_game_ecosystem_resident,
		"complete": true,
		"reason": optional_extension_reason,

		"mini_game_pack_report": (
			mini_game_pack_report.duplicate(true)
		),

		"mini_game_instantiation_report": (
			mini_game_instantiation_report.duplicate(true)
		),

		"adobe_flash_bootstrap_report": (
			adobe_flash_bootstrap_report.duplicate(true)
		),

		"mini_game_bootstrap_report": (
			mini_game_bootstrap_report.duplicate(true)
		),

		"required_mini_game_engine_properties": (
			required_mini_game_engine_properties.duplicate()
		),

		"missing_mini_game_engine_properties": (
			missing_mini_game_engine_properties.duplicate()
		),

		"mini_game_instantiation_failures": (
			mini_game_instantiation_failures.duplicate(true)
		),

		"mini_game_ecosystem_resident": (
			mini_game_ecosystem_resident
		),

		"stick_fighter_provider_resident": (
			mini_game_provider_resident
		),

		"constitutional_gate_member": false,
		"resident_runtime_exists_gate_member": false,
		"ready_gate_member": false,
		"blocks_ready_door": false,
		"blocks_ui": false,
		"ui_is_renderer_only": true
	}
func _resident_bootstrap_era_contracts() -> Dictionary:
	if era_mod_contract_engine != null:
		era_mod_contract_engine.bootstrap_default_contracts()

	if era_contract_engine != null:
		era_contract_engine.bootstrap_default_contracts()

	return {
		"success": true
	}


func _resident_bootstrap_upce_contracts() -> Dictionary:
	if upce_engine != null:
		upce_engine.bootstrap_default_contracts()

	return {
		"success": true
	}


func _resident_bootstrap_royalty_contracts() -> Dictionary:
	if royalty_mod_contract_engine != null:
		royalty_mod_contract_engine.bootstrap_default_contracts()

	if royalty_contract_engine != null:
		royalty_contract_engine.bootstrap_default_contracts()

	if royalty_runtime_engine != null:
		royalty_runtime_engine.bootstrap_default_contracts()

	if crown_hub_contract_engine != null:
		crown_hub_contract_engine.bootstrap_default_contracts()

	return {
		"success": true
	}


func _resident_bootstrap_movie_theater_contracts() -> Dictionary:
	if (
		movie_theater_engine != null
		and movie_theater_engine.has_method(
			"bootstrap_ui_contracts"
		)
	):
		movie_theater_engine.bootstrap_ui_contracts()

	return {
		"success": true
	}


func _resident_bootstrap_boxing_contract() -> Dictionary:
	if boxing_contract_engine != null:
		boxing_contract_engine.set_contract()

	return {
		"success": true
	}


func _resident_bootstrap_competitive_reality_contracts() -> Dictionary:
	if competitive_reality_runtime != null:
		competitive_reality_runtime.bootstrap_default_contracts()

	return {
		"success": true
	}


func _resident_bootstrap_reality_surge_contracts() -> Dictionary:
	if reality_surge_engine != null:
		reality_surge_engine.bootstrap_default_contracts()

	return {
		"success": true
	}


func _resident_bootstrap_reality_orchestrator_contracts() -> Dictionary:
	if reality_orchestrator != null:
		reality_orchestrator.bootstrap_default_contracts()

	return {
		"success": true
	}


func _resident_seal_chassis() -> Dictionary:
	if typeof(
		scenario_state
	) != TYPE_DICTIONARY:
		scenario_state = {}

	scenario_state [
		"resident_runtime_chassis_bootstrap_active"
	] = false
	scenario_state [
		"resident_runtime_chassis_bootstrap_complete"
	] = true
	scenario_state [
		"resident_runtime_chassis_bootstrap_completed_at_ms"
	] = int(
		Time.get_ticks_msec()
	)
	scenario_state [
		"resident_runtime_execution_mode"
	] = "resident_chassis_hot"

	return {
		"success": true,
		"signature": resident_runtime_bootstrap_signature,
		"engine_step_count": (
			resident_runtime_bootstrap_plan.size()
		)
	}
func _resident_apply_reality_settings() -> Dictionary:
	_resident_bind_constructor_context(
		resident_runtime_binding_settings,
		resident_runtime_binding_context
	)
	_hydrate_reality_settings()

	if typeof(scenario_state) != TYPE_DICTIONARY:
		scenario_state = {}

	var seed_authority_report: Dictionary = (
		_resident_initialize_seed_authority()
	)

	if (
		not bool(
			seed_authority_report.get(
				"success",
				false
			)
		)
		or int(
			seed_authority_report.get(
				"world_seed",
				seed_authority_report.get(
					"seed",
					-1
				)
			)
		) <= 0
	):
		return {
			"success": false,
			"reason": (
				"resident_first_life_seed_contract_failed"
			),
			"seed_report": (
				seed_authority_report.duplicate(true)
			)
		}

	if era_engine == null:
		return {
			"success": false,
			"reason": "resident_era_engine_missing"
		}

	if custom_settings.has(
		"year_locked"
	):
		year_locked = bool(
			custom_settings ["year_locked"]
		)

	if (
		custom_mode
		and custom_settings.has(
			"year"
		)
	):
		year = int(
			custom_settings ["year"]
		)

	if (
		custom_mode
		and custom_settings.has(
			"era"
		)
		and era_engine.eras.has(
			custom_settings ["era"]
		)
	):
		era = era_engine.eras [
			custom_settings ["era"]
		]

	if not custom_settings.has(
		"year"
	):
		if (
			not custom_settings.has(
				"era"
			)
			or not era_engine.eras.has(
				custom_settings ["era"]
			)
		):
			return {
				"success": false,
				"reason": (
					"resident_reality_era_contract_missing"
				)
			}

		var selected_era: Dictionary = era_engine.eras [
			custom_settings ["era"]
		]
		var start_year: int = int(
			selected_era.get(
				"start_year",
				year
			)
		)
		var end_year: int = int(
			selected_era.get(
				"end_year",
				year
			)
		)
		year = int(
			(
				float(start_year)
				+ float(end_year)
			) * 0.5
		)
	elif (
		custom_mode
		and custom_settings.has(
			"year"
		)
	):
		era = era_engine._era_from_year(
			year
		)
	else:
		era = era_engine._era_from_year(
			year
		)

	var world_seed: int = int(
		seed_authority_report.get(
			"world_seed",
			-1
		)
	)
	var seed_contract: Dictionary = _resident_dict(
		seed_authority_report.get(
			"seed_contract",
			{}
		)
	)
	var realm_count: int = 0

	if (
		realm_engine != null
		and realm_engine.has_method(
			"bootstrap_realms_for_era"
		)
	):
		realm_engine.bootstrap_realms_for_era({
			"era": str(
				custom_settings.get(
					"era",
					""
				)
			),
			"year": year,
			"world_seed": world_seed,
			"seed_contract": (
				seed_contract.duplicate(true)
			),
			"settings": custom_settings.duplicate(true),
			"source": (
				"resident_apply_reality_settings"
			),
		})

		if "realms" in realm_engine:
			var realms_raw: Variant = realm_engine.realms

			if typeof(realms_raw) == TYPE_DICTIONARY:
				realm_count = (
					(realms_raw as Dictionary).size()
				)

	scenario_state [
		"birth_shell_realm_bootstrap_deferred"
	] = false

	scenario_state [
		"resident_realm_contracts_ready"
	] = realm_count > 0

	scenario_state [
		"resident_realm_contract_count"
	] = realm_count

	scenario_state [
		"resident_realm_population_materialization_deferred"
	] = true

	scenario_state [
		"resident_world_exists_before_player_identity"
	] = true

	scenario_state [
		"resident_seed_committed_before_world_truth"
	] = true

	return {
		"success": true,
		"year": year,
		"year_locked": year_locked,
		"world_seed": world_seed,
		"seed_contract": seed_contract.duplicate(true),
		"seed_report": (
			seed_authority_report.duplicate(true)
		),
		"realm_count": realm_count,
		"realm_contracts_ready": realm_count > 0,
	}
func resident_blocking_birth_lane_active() -> bool:



	if (
		resident_runtime_bootstrap_mode
		== "reality_binding"
		and not resident_runtime_bootstrap_complete
	):
		return true

	if typeof(scenario_state) != TYPE_DICTIONARY:
		return false

	if (
		bool(
			scenario_state.get(
				"birth_shell_player_control_released",
				false
			)
		)
		or bool(
			scenario_state.get(
				"playable_life_surface_player_control_released",
				false
			)
		)
	):
		return false

	return (
		bool(
			scenario_state.get(
				"resident_runtime_binding_active",
				false
			)
		)
		or bool(
			scenario_state.get(
				"god_mode_life_prewarm_active",
				false
			)
		)
		or bool(
			scenario_state.get(
				"birth_shell_first_boot_active",
				false
			)
		)
		or bool(
			scenario_state.get(
				"birth_shell_deferred_boot_pending",
				false
			)
		)
		or bool(
			scenario_state.get(
				"royalty_heavy_bootstrap_forbidden_during_prewarm",
				false
			)
		)
		or bool(
			scenario_state.get(
				"royal_first_frame_shell_truth_only",
				false
			)
		)
		or (
			bool(
				scenario_state.get(
					"interactive_boot_requested",
					false
				)
			)
			and not bool(
				scenario_state.get(
					"birth_shell_player_control_released",
					false
				)
			)
		)
	)
func _resident_spawn_shell_population() -> Dictionary:
	if npc_factory == null:
		return {
			"success": false,
			"reason": "resident_npc_factory_missing"
		}

	if npcs.is_empty():
		var shell_npc_count: int = int(
			scenario_state.get(
				"birth_shell_npc_count",
				4
			)
		)
		shell_npc_count = clampi(
			shell_npc_count,
			0,
			24
		)

		for _index in range(
			shell_npc_count
		):
			var npc = npc_factory.create_random_npc(
				true
			)
			apply_reality_rules_to_person(
				npc
			)
			npcs.append(
				npc
			)

	return {
		"success": true,
		"shell_population_count": npcs.size()
	}


func _resident_create_player_identity() -> Dictionary:
	if player != null:
		return {
			"success": true,
			"mode": "player_already_created",
			"actor_id": int(
				player.id
			)
		}

	if character_creator == null:
		return {
			"success": false,
			"reason": (
				"resident_character_creator_missing"
			)
		}

	if npc_factory == null:
		return {
			"success": false,
			"reason": "resident_npc_factory_missing"
		}

	var created_player = null

	if custom_mode:
		created_player = (
			character_creator.create_custom_player(
				custom_settings
			)
		)
	else:
		created_player = npc_factory.create_player()

	if created_player == null:
		return {
			"success": false,
			"reason": (
				"resident_player_creation_failed"
			)
		}

	player = created_player
	apply_reality_rules_to_person(
		player
	)

	if (
		wizard_engine != null
		and wizard_engine.has_method(
			"apply_birth_settings"
		)
	):
		wizard_engine.apply_birth_settings(
			player,
			custom_settings
		)

	if (
		power_engine != null
		and power_engine.has_method(
			"apply_birth_settings"
		)
	):
		power_engine.apply_birth_settings(
			player,
			custom_settings
		)

	if (
		superhero_engine != null
		and superhero_engine.has_method(
			"apply_birth_settings"
		)
	):
		superhero_engine.apply_birth_settings(
			player,
			custom_settings
		)

	player_id = int(
		player.id
	)
	npcs.append(
		player
	)

	return {
		"success": true,
		"actor_id": int(
			player.id
		)
	}


func _resident_apply_birth_contracts() -> Dictionary:
	if player == null:
		return {
			"success": false,
			"reason": "resident_birth_actor_missing"
		}


	_apply_custom_household_spawn_contract(
		player
	)
	_apply_presidential_parent_contract_if_requested(
		player
	)


	_rebuild_npc_index()

	var first_frame_targets: Array = (
		_resident_first_frame_population_targets()
	)
	var soul_seed_distribution_authorized: bool = bool(
		scenario_state.get(
			"soul_seed_distribution_authorized",
			false
		)
	)
	var soul_seed_background_pending: bool = (
		soul_seed_engine != null
		and soul_seed_distribution_authorized
		and not first_frame_targets.is_empty()
	)
	var soul_seed_report: Dictionary = {
		"success": true,
		"mode": (
			"resident_soul_seed_distribution_deferred"
		),
		"actor_id": int(
			player.id
		),
		"first_frame_target_count": (
			first_frame_targets.size()
		),
		"background_distribution_pending": (
			soul_seed_background_pending
		),
	}



	scenario_state [
		"soul_seed_priority_distribution_report"
	] = soul_seed_report.duplicate(true)
	scenario_state [
		"soul_seed_background_distribution_pending"
	] = soul_seed_background_pending
	scenario_state [
		"soul_seed_distribution_deferred"
	] = soul_seed_background_pending
	scenario_state [
		"soul_seed_distribution_deferred_reason"
	] = (
		"minimum_playable_birth_truth_has_priority"
	)
	scenario_state [
		"resident_birth_contract_waits_for_soul_seed_distribution"
	] = false
	scenario_state [
		"resident_birth_contract_first_frame_target_count"
	] = first_frame_targets.size()
	scenario_state [
		"resident_birth_contract_global_population_scan_performed"
	] = false

	return {
		"success": true,
		"actor_id": int(
			player.id
		),
		"first_frame_target_count": (
			first_frame_targets.size()
		),
		"soul_seed_report": soul_seed_report,
		"background_soul_seed_distribution_pending": (
			soul_seed_background_pending
		),
	}

func _resident_first_frame_population_targets() -> Array:
	var out: Array = []
	var seen: Dictionary = {}

	for raw_target in _birth_shell_priority_soul_seed_targets():
		if not (
			raw_target is Person
		):
			continue

		_append_birth_shell_priority_soul_seed_target(
			out,
			seen,
			raw_target as Person
		)

	if player == null:
		return out

	_append_birth_shell_priority_soul_seed_target(
		out,
		seen,
		player
	)

	if player.partner != null:
		_append_birth_shell_priority_soul_seed_target(
			out,
			seen,
			player.partner
		)

	var actor_link_fields: Array = [
		"parents",
		"children",
		"friends",
		"ex_partners"
	]

	for raw_field_name in actor_link_fields:
		var field_name: String = str(
			raw_field_name
		)

		for raw_person_id in _birth_shell_safe_person_id_array(
			player,
			field_name
		):
			var person_id: int = int(
				raw_person_id
			)

			if person_id <= 0:
				continue

			_append_birth_shell_priority_soul_seed_target(
				out,
				seen,
				_birth_shell_resolve_person_by_id(
					person_id
				)
			)

	if typeof(scenario_state) == TYPE_DICTIONARY:
		var member_index_raw: Variant = scenario_state.get(
			"custom_household_member_index",
			{}
		)

		if typeof(member_index_raw) == TYPE_DICTIONARY:
			var member_index: Dictionary = (
				member_index_raw as Dictionary
			)

			for raw_member_id in member_index.values():
				var member_id: int = int(
					raw_member_id
				)

				if member_id <= 0:
					continue

				_append_birth_shell_priority_soul_seed_target(
					out,
					seen,
					_birth_shell_resolve_person_by_id(
						member_id
					)
				)

	return out
func _resident_place_population() -> Dictionary:
	if player == null:
		return {
			"success": false,
			"complete": false,
			"reason": "resident_population_actor_missing"
		}

	if typeof(scenario_state) != TYPE_DICTIONARY:
		scenario_state = {}

	var priority_targets: Array = (
		_resident_first_frame_population_targets()
	)
	var priority_id_lookup: Dictionary = {}

	for raw_target in priority_targets:
		if not (
			raw_target is Person
		):
			continue

		var target: Person = raw_target as Person
		var target_id: int = int(
			target.id
		)

		if target_id <= 0:
			continue

		priority_id_lookup [
			str(
				target_id
			)
		] = true

	var family_projection_count: int = maxi(
		0,
		priority_id_lookup.size() - 1
	)
	var background_population_count: int = maxi(
		0,
		npcs.size() - priority_id_lookup.size()
	)

	resident_population_placement_cursor = clampi(
		resident_population_placement_cursor,
		0,
		9
	)

	if resident_population_placement_cursor == 0:
		scenario_state [
			"resident_first_frame_population_ids"
		] = priority_id_lookup.keys()

		scenario_state.erase(
			"resident_background_population_ids"
		)

		scenario_state [
			"resident_family_spatial_projection_pending_count"
		] = family_projection_count

		scenario_state [
			"resident_family_spatial_projection_pending"
		] = family_projection_count > 0

		scenario_state [
			"resident_background_population_count"
		] = background_population_count

		scenario_state [
			"resident_background_population_projection_cursor"
		] = 0

		scenario_state [
			"resident_background_population_projection_pending"
		] = (
			background_population_count > 0
			or family_projection_count > 0
		)

		scenario_state [
			"resident_population_existence_is_not_spatial_projection"
		] = true

		scenario_state [
			"resident_ready_door_waits_for_observed_family_only"
		] = false

		scenario_state [
			"resident_ready_door_waits_for_player_spatial_anchor_only"
		] = true

		scenario_state [
			"resident_ready_gate_performed_global_population_scan"
		] = false

		scenario_state [
			"resident_population_placement_is_microstaged"
		] = true

		scenario_state [
			"resident_population_placement_phase"
		] = "indexed_first_frame_population"

		resident_population_placement_cursor = 1

		return {
			"success": true,
			"complete": false,
			"progress": 0.1,
			"stage_id": (
				"place_resident_population:index_population"
			),
			"actor_id": int(
				player.id
			),
			"first_frame_population_count": (
				priority_id_lookup.size()
			),
			"family_projection_count": (
				family_projection_count
			),
			"background_population_count": (
				background_population_count
			),
		}

	if resident_population_placement_cursor == 1:
		if consciousness_engine != null:
			consciousness_engine.ensure_consciousness(
				player,
				{
					"source": (
						"birth_shell_first_life_spawn_player_first"
					)
				}
			)

		scenario_state [
			"resident_population_placement_phase"
		] = "player_consciousness_ready"

		resident_population_placement_cursor = 2

		return {
			"success": true,
			"complete": false,
			"progress": 0.22,
			"stage_id": (
				"place_resident_population:player_consciousness"
			),
			"actor_id": int(
				player.id
			),
		}

	if resident_population_placement_cursor == 2:
		if (
			willpower_engine != null
			and willpower_engine.has_method(
				"ensure_willpower"
			)
		):
			willpower_engine.ensure_willpower(
				player,
				{
					"source": (
						"birth_shell_first_life_spawn_player_first"
					)
				}
			)

		scenario_state [
			"resident_population_placement_phase"
		] = "player_willpower_ready"

		resident_population_placement_cursor = 3

		return {
			"success": true,
			"complete": false,
			"progress": 0.34,
			"stage_id": (
				"place_resident_population:player_willpower"
			),
			"actor_id": int(
				player.id
			),
		}

	if resident_population_placement_cursor == 3:



		if (
			realm_engine != null
			and realm_engine.has_method(
				"assign_realm"
			)
		):
			realm_engine.assign_realm(
				player
			)

		scenario_state [
			"resident_population_placement_phase"
		] = "player_realm_contract_ready"

		resident_population_placement_cursor = 4

		return {
			"success": true,
			"complete": false,
			"progress": 0.48,
			"stage_id": (
				"place_resident_population:player_realm_contract"
			),
			"actor_id": int(
				player.id
			),
			"realm_governance_bootstrap_deferred": true
		}

	if resident_population_placement_cursor == 4:
		if world_space_engine != null:
			world_space_engine.place_npc(
				player
			)

		scenario_state [
			"resident_population_placement_phase"
		] = "player_world_space_anchor_ready"

		resident_population_placement_cursor = 5

		return {
			"success": true,
			"complete": false,
			"progress": 0.62,
			"stage_id": (
				"place_resident_population:player_world_space"
			),
			"actor_id": int(
				player.id
			),
		}

	if resident_population_placement_cursor == 5:
		if chunk_simulation_engine != null:
			chunk_simulation_engine.assign_npc(
				player
			)

		scenario_state [
			"resident_population_placement_phase"
		] = "player_chunk_anchor_ready"

		resident_population_placement_cursor = 6

		return {
			"success": true,
			"complete": false,
			"progress": 0.74,
			"stage_id": (
				"place_resident_population:player_chunk"
			),
			"actor_id": int(
				player.id
			),
		}

	if resident_population_placement_cursor == 6:
		if player_id == 0:
			player_id = int(
				player.id
			)

		if has_method(
			"register_controlled_character"
		):
			register_controlled_character(
				player.id
			)

		if dynasty_engine != null:
			dynasty_engine.register_dynasty(
				player.last_name
			)

		scenario_state [
			"resident_population_placement_phase"
		] = "controlled_identity_registered"

		resident_population_placement_cursor = 7

		return {
			"success": true,
			"complete": false,
			"progress": 0.84,
			"stage_id": (
				"place_resident_population:controlled_identity"
			),
			"actor_id": int(
				player.id
			),
		}

	if resident_population_placement_cursor == 7:
		_apply_player_starting_artifact_loadout()

		scenario_state [
			"resident_population_placement_phase"
		] = "starting_artifact_contract_applied"

		resident_population_placement_cursor = 8

		return {
			"success": true,
			"complete": false,
			"progress": 0.92,
			"stage_id": (
				"place_resident_population:starting_artifacts"
			),
			"actor_id": int(
				player.id
			),
		}

	if resident_population_placement_cursor == 8:
		for raw_parent_id in player.parents:
			var parent = get_npc_by_id(
				int(
					raw_parent_id
				)
			)

			if (
				parent != null
				and dynasty_engine != null
			):
				dynasty_engine.register_dynasty(
					parent.last_name
				)

		resident_population_placement_finalized = true
		resident_population_placement_cursor = 9

		scenario_state [
			"resident_population_placement_phase"
		] = "complete"

		scenario_state [
			"resident_population_placement_complete_at_ms"
		] = int(
			Time.get_ticks_msec()
		)

	return {
		"success": true,
		"complete": true,
		"progress": 1.0,
		"stage_id": "place_resident_population:complete",
		"actor_id": int(
			player.id
		),
		"population_count": npcs.size(),
		"first_frame_population_count": (
			priority_id_lookup.size()
		),
		"family_projection_count": (
			family_projection_count
		),
		"background_population_count": (
			background_population_count
		),
	}
func _resident_seed_first_frame_truth() -> Dictionary:
	if player == null:
		return {
			"success": false,
			"complete": false,
			"reason": "resident_first_frame_actor_missing"
		}

	if typeof(scenario_state) != TYPE_DICTIONARY:
		scenario_state = {}

	var first_frame_targets: Array = (
		_resident_first_frame_population_targets()
	)
	var first_frame_target_ids: Array = []

	for raw_actor in first_frame_targets:
		if not (
			raw_actor is Person
		):
			continue

		var actor: Person = raw_actor as Person
		var actor_id: int = int(
			actor.id
		)

		if (
			actor_id > 0
			and not first_frame_target_ids.has(
				actor_id
			)
		):
			first_frame_target_ids.append(
				actor_id
			)

	var relationship_seed_report: Dictionary = (
		_resident_dict(
			scenario_state.get(
				"resident_first_frame_relationship_seed_report",
				{}
			)
		)
	)
	var relationship_graph_report: Dictionary = (
		_resident_dict(
			scenario_state.get(
				"resident_first_frame_relationship_graph_report",
				{}
			)
		)
	)
	var family_pet_report: Dictionary = (
		_resident_dict(
			scenario_state.get(
				"resident_first_frame_family_pet_report",
				{}
			)
		)
	)

	resident_first_frame_truth_phase = clampi(
		resident_first_frame_truth_phase,
		0,
		6
	)

	if resident_first_frame_truth_phase == 0:
		scenario_state [
			"resident_first_frame_relationship_target_ids"
		] = first_frame_target_ids.duplicate()

		scenario_state [
			"resident_first_frame_truth_target_count"
		] = first_frame_target_ids.size()

		scenario_state [
			"resident_first_frame_truth_is_microstaged"
		] = true

		scenario_state [
			"resident_first_frame_truth_actor_and_family_first"
		] = true

		scenario_state [
			"resident_first_frame_truth_phase"
		] = "indexed_actor_and_family"

		resident_first_frame_truth_actor_cursor = 0
		resident_first_frame_truth_phase = 1

		return {
			"success": true,
			"complete": false,
			"progress": 0.08,
			"stage_id": (
				"seed_first_frame_truth:index_actor_family"
			),
			"actor_id": int(
				player.id
			),
			"first_frame_target_count": (
				first_frame_target_ids.size()
			),
			"deep_world_enrichment_is_background": true,
		}

	if resident_first_frame_truth_phase == 1:


		if (
			food_engine != null
			and food_engine.has_method(
				"_seed_initial_hunger_profile_for_actor"
			)
		):
			food_engine.call(
				"_seed_initial_hunger_profile_for_actor",
				player,
				false
			)

		scenario_state [
			"resident_first_frame_truth_phase"
		] = "player_hunger_ready"

		resident_first_frame_truth_phase = 2

		return {
			"success": true,
			"complete": false,
			"progress": 0.24,
			"stage_id": (
				"seed_first_frame_truth:player_hunger"
			),
			"actor_id": int(
				player.id
			),
			"first_frame_target_count": (
				first_frame_target_ids.size()
			),
			"deep_world_enrichment_is_background": true,
		}

	if resident_first_frame_truth_phase == 2:
		if (
			relationship_engine != null
			and relationship_engine.has_method(
				"seed_family_and_stranger_bonds_for_actor"
			)
		):
			relationship_seed_report = (
				relationship_engine
				.seed_family_and_stranger_bonds_for_actor(
					player,
					{
						"source": (
							"birth_shell_relationship_baseline"
						),
						"target_ids": (
							first_frame_target_ids.duplicate()
						),
						"include_strangers": false,
						"bounded_first_frame_contract": true
					}
				)
			)

		scenario_state [
			"resident_first_frame_relationship_seed_report"
		] = relationship_seed_report.duplicate(true)

		scenario_state [
			"resident_first_frame_truth_phase"
		] = "bounded_family_relationships_ready"

		resident_first_frame_truth_phase = 3

		return {
			"success": true,
			"complete": false,
			"progress": 0.5,
			"stage_id": (
				"seed_first_frame_truth:family_relationships"
			),
			"actor_id": int(
				player.id
			),
			"first_frame_target_count": (
				first_frame_target_ids.size()
			),
			"relationship_seed_report": (
				relationship_seed_report.duplicate(true)
			),
			"bounded_first_frame_contract": true,
		}

	if resident_first_frame_truth_phase == 3:
		if (
			human_relationship_contract_engine != null
			and human_relationship_contract_engine.has_method(
				"sync_actor_relationship_edges"
			)
		):
			relationship_graph_report = (
				human_relationship_contract_engine
					.sync_actor_relationship_edges(
						player,
						{
							"source": (
								"birth_shell_human_relationship_graph_sync"
							)
						}
					)
			)

		scenario_state [
			"resident_first_frame_relationship_graph_report"
		] = relationship_graph_report.duplicate(true)

		scenario_state [
			"resident_first_frame_truth_phase"
		] = "player_relationship_graph_ready"

		resident_first_frame_truth_phase = 4

		return {
			"success": true,
			"complete": false,
			"progress": 0.7,
			"stage_id": (
				"seed_first_frame_truth:relationship_graph"
			),
			"actor_id": int(
				player.id
			),
			"first_frame_target_count": (
				first_frame_target_ids.size()
			),
			"relationship_graph_report": (
				relationship_graph_report.duplicate(true)
			),
		}

	if resident_first_frame_truth_phase == 4:
		if (
			pets_contract_engine != null
			and pets_contract_engine.has_method(
				"ensure_birth_family_pet_for_actor"
			)
		):
			family_pet_report = (
				pets_contract_engine
					.ensure_birth_family_pet_for_actor(
						player,
						{
							"source": (
								"birth_shell_family_pet_seed"
							),
							"max_birth_age": 1
						}
					)
			)

		scenario_state [
			"resident_first_frame_family_pet_report"
		] = family_pet_report.duplicate(true)

		scenario_state [
			"resident_first_frame_truth_phase"
		] = "family_pet_contract_resolved"

		resident_first_frame_truth_phase = 5

		return {
			"success": true,
			"complete": false,
			"progress": 0.88,
			"stage_id": (
				"seed_first_frame_truth:family_pet"
			),
			"actor_id": int(
				player.id
			),
			"first_frame_target_count": (
				first_frame_target_ids.size()
			),
			"family_pet_report": (
				family_pet_report.duplicate(true)
			),
			"deep_world_enrichment_is_background": true,
		}

	if resident_first_frame_truth_phase == 5:
		scenario_state [
			"resident_first_frame_relationship_target_ids"
		] = first_frame_target_ids.duplicate()

		scenario_state [
			"resident_relationship_baseline_policy"
		] = "actor_scope_on_demand"

		scenario_state [
			"resident_background_stranger_relationship_seed_pending"
		] = false

		scenario_state [
			"resident_soft_unload_pending"
		] = true

		scenario_state [
			"resident_deep_population_hunger_seed_pending"
		] = (
			first_frame_target_ids.size() > 1
			or bool(
				scenario_state.get(
					"resident_background_population_projection_pending",
					false
				)
			)
		)

		scenario_state [
			"resident_runtime_first_frame_truth_seeded"
		] = true

		scenario_state [
			"resident_runtime_first_frame_truth_seeded_at_ms"
		] = int(
			Time.get_ticks_msec()
		)

		scenario_state [
			"first_frame_is_live_runtime"
		] = true

		scenario_state [
			"runtime_scene_tree_access_allowed"
		] = false

		scenario_state [
			"first_frame_truth_is_actor_and_family_complete"
		] = true

		scenario_state [
			"deep_world_enrichment_is_background"
		] = true

		scenario_state [
			"ready_gate_seeded_relationships_for_all_npcs"
		] = false

		scenario_state [
			"resident_first_frame_truth_phase"
		] = "complete"

		resident_first_frame_truth_actor_cursor = (
			first_frame_target_ids.size()
		)
		resident_first_frame_truth_phase = 6

	return {
		"success": true,
		"complete": true,
		"progress": 1.0,
		"stage_id": "seed_first_frame_truth:complete",
		"actor_id": int(
			player.id
		),
		"first_frame_target_count": (
			first_frame_target_ids.size()
		),
		"relationship_seed_report": (
			relationship_seed_report.duplicate(true)
		),
		"relationship_graph_report": (
			relationship_graph_report.duplicate(true)
		),
		"family_pet_report": (
			family_pet_report.duplicate(true)
		),
		"deep_world_enrichment_is_background": true,
	}
func step_resident_post_ready_truth_tail(
		max_steps: int = 1,
		frame_budget_ms: int = 2
) -> Dictionary:
	if player == null:
		return {
			"success": false,
			"complete": false,
			"reason": (
				"resident_post_ready_truth_actor_missing"
			),
			"stage_id": (
				"post_ready_truth_tail:missing_actor"
			)
		}

	if typeof(
		scenario_state
	) != TYPE_DICTIONARY:
		scenario_state = {}

	var requested_max_steps: int = maxi(
		1,
		max_steps
	)
	var requested_frame_budget_ms: int = maxi(
		1,
		frame_budget_ms
	)
	var phase: int = clampi(
		int(
			scenario_state.get(
				"resident_post_ready_truth_tail_phase",
				0
			)
		),
		0,
		2
	)
	var order_version: int = int(
		scenario_state.get(
			"resident_post_ready_truth_tail_order_version",
			1
		)
	)


	if order_version < 2:
		if resident_first_frame_truth_phase < 6:
			phase = 0
		elif not resident_population_placement_finalized:
			phase = 1
		else:
			phase = 2

		scenario_state [
			"resident_post_ready_truth_tail_phase"
		] = phase
		scenario_state [
			"resident_post_ready_truth_tail_order_version"
		] = 2

	scenario_state [
		"resident_post_ready_truth_tail_pending"
	] = phase < 2
	scenario_state [
		"resident_post_ready_truth_tail_complete"
	] = phase >= 2
	scenario_state [
		"resident_post_ready_truth_tail_does_not_block_ready"
	] = true
	scenario_state [
		"resident_post_ready_truth_tail_requested_max_steps"
	] = requested_max_steps
	scenario_state [
		"resident_post_ready_truth_tail_effective_max_steps"
	] = 1
	scenario_state [
		"resident_post_ready_truth_tail_requested_budget_ms"
	] = requested_frame_budget_ms
	scenario_state [
		"resident_post_ready_truth_tail_last_service_at_ms"
	] = int(
		Time.get_ticks_msec()
	)
	scenario_state [
		"resident_post_ready_truth_tail_order"
	] = (
		"actor_family_truth_before_population_placement"
	)
	scenario_state [
		"resident_post_ready_truth_tail_order_version"
	] = 2




	if phase == 0:
		var truth_report: Dictionary = (
			_resident_seed_first_frame_truth()
		)

		scenario_state [
			"resident_post_ready_first_frame_truth_report"
		] = truth_report.duplicate(true)

		if not bool(
			truth_report.get(
				"success",
				true
			)
		):
			return {
				"success": false,
				"complete": false,
				"reason": str(
					truth_report.get(
						"reason",
						"resident_post_ready_truth_failed"
					)
				),
				"stage_id": (
					"post_ready_truth_tail:first_frame_truth_failed"
				),
				"phase": 0,
				"truth_report": truth_report.duplicate(true),
			}

		if not bool(
			truth_report.get(
				"complete",
				false
			)
		):
			var truth_progress: float = clampf(
				float(
					truth_report.get(
						"progress",
						0.0
					)
				),
				0.0,
				1.0
			)

			return {
				"success": true,
				"complete": false,
				"progress": truth_progress * 0.5,
				"stage_id": str(
					truth_report.get(
						"stage_id",
						"post_ready_truth_tail:first_frame_truth"
					)
				),
				"phase": 0,
				"truth_report": truth_report.duplicate(true),
				"ready_state_preserved": true,
				"ui_is_renderer_only": true
			}

		phase = 1

		scenario_state [
			"resident_post_ready_truth_tail_phase"
		] = phase
		scenario_state [
			"resident_post_ready_actor_family_truth_complete"
		] = true
		scenario_state [
			"resident_post_ready_actor_family_truth_completed_at_ms"
		] = int(
			Time.get_ticks_msec()
		)

		return {
			"success": true,
			"complete": false,
			"progress": 0.5,
			"stage_id": (
				"post_ready_truth_tail:actor_family_truth_complete"
			),
			"phase": phase,
			"truth_report": truth_report.duplicate(true),
			"ready_state_preserved": true,
			"ui_is_renderer_only": true
		}



	if phase == 1:
		var placement_report: Dictionary = (
			_resident_place_population()
		)

		scenario_state [
			"resident_post_ready_placement_report"
		] = placement_report.duplicate(true)

		if not bool(
			placement_report.get(
				"success",
				true
			)
		):
			return {
				"success": false,
				"complete": false,
				"reason": str(
					placement_report.get(
						"reason",
						"resident_post_ready_placement_failed"
					)
				),
				"stage_id": (
					"post_ready_truth_tail:placement_failed"
				),
				"phase": 1,
				"placement_report": (
					placement_report.duplicate(true)
				),
			}

		if not bool(
			placement_report.get(
				"complete",
				false
			)
		):
			var placement_progress: float = clampf(
				float(
					placement_report.get(
						"progress",
						0.0
					)
				),
				0.0,
				1.0
			)

			return {
				"success": true,
				"complete": false,
				"progress": 0.5 + placement_progress * 0.5,
				"stage_id": str(
					placement_report.get(
						"stage_id",
						"post_ready_truth_tail:placement"
					)
				),
				"phase": 1,
				"placement_report": (
					placement_report.duplicate(true)
				),
				"ready_state_preserved": true,
				"ui_is_renderer_only": true
			}

		phase = 2

		scenario_state [
			"resident_post_ready_truth_tail_phase"
		] = phase
		scenario_state [
			"resident_post_ready_placement_complete"
		] = true
		scenario_state [
			"resident_post_ready_placement_completed_at_ms"
		] = int(
			Time.get_ticks_msec()
		)

	scenario_state [
		"resident_post_ready_truth_tail_pending"
	] = false
	scenario_state [
		"resident_post_ready_truth_tail_complete"
	] = true
	scenario_state [
		"resident_post_ready_truth_tail_completed_at_ms"
	] = int(
		Time.get_ticks_msec()
	)
	scenario_state [
		"resident_post_ready_truth_tail_does_not_block_ready"
	] = true
	scenario_state [
		"resident_post_ready_actor_family_truth_complete"
	] = resident_first_frame_truth_phase >= 6

	return {
		"success": true,
		"complete": true,
		"progress": 1.0,
		"stage_id": "post_ready_truth_tail:complete",
		"phase": 2,
		"actor_id": int(
			player.id
		),
		"placement_complete": (
			resident_population_placement_finalized
		),
		"first_frame_truth_complete": (
			resident_first_frame_truth_phase >= 6
		),
		"ready_state_preserved": true,
		"ui_is_renderer_only": true
	}
func _resident_seal_reality() -> Dictionary:
	if player == null:
		return {
			"success": false,
			"reason": (
				"resident_runtime_has_no_player"
			)
		}

	if typeof(
		scenario_state
	) != TYPE_DICTIONARY:
		scenario_state = {}

	var ready_at_ms: int = int(
		Time.get_ticks_msec()
	)
	var actor_id: int = int(
		player.id
	)
	var birth_intro_report: Dictionary = {}
	var birth_intro_lines: Array = []




	if (
		int(
			player.age
		) <= 0
		and life_diary_contract_engine != null
	):
		birth_intro_report = (
			life_diary_contract_engine
			.ensure_birth_intro_for_actor(
				player,
				{
					"source": (
						"resident_seal_reality"
					),
					"year": year,
					"age": int(
						player.age
					),
					"actor_id": actor_id,
					"resident_signature": (
						resident_runtime_bootstrap_signature
					),
				}
			)
		)

		birth_intro_lines = (
			life_diary_contract_engine
			.diary_lines_for_actor(
				actor_id,
				{
					"source": (
						"resident_first_frame_snapshot"
					)
				}
			)
		)



	if birth_intro_lines.is_empty():
		var full_name: String = (
			"%s %s"
			% [
				str(
					player.first_name
				).strip_edges(),
				str(
					player.last_name
				).strip_edges()
			]
		).strip_edges()

		if full_name == "":
			full_name = "Unknown"

		birth_intro_lines = [
			"Year: %s" % str(
				year
			),
			"Age: %d" % int(
				player.age
			),
			"My name is %s." % full_name
		]

	var currency_symbol: String = ""
	if economy_engine != null:
		var currency: Dictionary = (
			economy_engine.get_currency()
		)
		currency_symbol = str(
			currency.get(
				"symbol",
				""
			)
		)



	var runtime_hud_visibility_snapshot: Dictionary = (
		_checkpoint_resume_hud_visibility_snapshot_for_current_actor(
			{}
		)
	)
	runtime_hud_visibility_snapshot [
		"reason"
	] = "resident_seal_reality"
	runtime_hud_visibility_snapshot [
		"updated_at_ms"
	] = ready_at_ms

	scenario_state [
		"resident_first_frame_birth_intro_lines"
	] = birth_intro_lines.duplicate(true)
	scenario_state [
		"resident_first_frame_birth_intro_ready"
	] = not birth_intro_lines.is_empty()
	scenario_state [
		"resident_first_frame_birth_intro_actor_id"
	] = actor_id
	scenario_state [
		"resident_first_frame_birth_intro_report"
	] = birth_intro_report.duplicate(true)
	scenario_state [
		"resident_first_frame_currency_symbol"
	] = currency_symbol

	scenario_state [
		"runtime_hud_visibility_snapshot"
	] = runtime_hud_visibility_snapshot.duplicate(false)
	scenario_state [
		"runtime_hud_visibility_snapshot_reason"
	] = "resident_seal_reality"
	scenario_state [
		"runtime_hud_visibility_snapshot_at_ms"
	] = ready_at_ms
	scenario_state [
		"runtime_hud_visibility_snapshot_complete"
	] = not runtime_hud_visibility_snapshot.is_empty()
	scenario_state [
		"runtime_hud_visibility_snapshot_simulation_authored"
	] = true

	scenario_state [
		"birth_shell_player_created"
	] = true
	scenario_state [
		"birth_shell_player_id"
	] = actor_id
	scenario_state [
		"birth_shell_created_at_ms"
	] = ready_at_ms
	scenario_state [
		"resident_runtime_binding_active"
	] = false
	scenario_state [
		"resident_runtime_binding_complete"
	] = true
	scenario_state [
		"resident_runtime_signature"
	] = resident_runtime_bootstrap_signature
	scenario_state [
		"resident_runtime_execution_mode"
	] = "resident_detached"
	scenario_state [
		"resident_runtime_ready_at_ms"
	] = ready_at_ms
	scenario_state [
		"resident_runtime_minimum_playable_truth_ready"
	] = true
	scenario_state [
		"resident_runtime_minimum_playable_truth_contract"
	] = (
		"seed_era_player_family_birth_diary"
	)
	scenario_state [
		"resident_runtime_player_identity_ready"
	] = true
	scenario_state [
		"resident_runtime_household_birth_truth_ready"
	] = true
	scenario_state [
		"resident_runtime_birth_diary_truth_ready"
	] = not birth_intro_lines.is_empty()
	scenario_state [
		"resident_runtime_ready_before_spatial_enrichment"
	] = true
	scenario_state [
		"resident_runtime_ready_before_relationship_enrichment"
	] = true
	scenario_state [
		"resident_runtime_ready_before_projection"
	] = true
	scenario_state [
		"resident_post_ready_truth_tail_phase"
	] = 0
	scenario_state [
		"resident_post_ready_truth_tail_pending"
	] = true
	scenario_state [
		"resident_post_ready_truth_tail_complete"
	] = false
	scenario_state [
		"resident_post_ready_truth_tail_does_not_block_ready"
	] = true
	scenario_state [
		"resident_ready_door_waits_for_post_ready_truth_tail"
	] = false
	scenario_state [
		"resident_ready_door_waits_for_spatial_placement"
	] = false
	scenario_state [
		"resident_ready_door_waits_for_relationship_graph"
	] = false
	scenario_state [
		"resident_ready_door_waits_for_family_pet"
	] = false
	scenario_state [
		"god_mode_life_prewarm_active"
	] = false
	scenario_state [
		"god_mode_life_prewarm_ready"
	] = true

	return {
		"success": true,
		"complete": true,
		"actor_id": actor_id,
		"signature": (
			resident_runtime_bootstrap_signature
		),
		"minimum_playable_truth_ready": true,
		"minimum_playable_truth_contract": (
			"seed_era_player_family_birth_diary"
		),
		"birth_intro_ready": (
			not birth_intro_lines.is_empty()
		),
		"birth_intro_line_count": (
			birth_intro_lines.size()
		),
		"post_ready_truth_tail_pending": true,
		"ready_door_waits_for_post_ready_truth_tail": false,
		"runtime_hud_visibility_snapshot_ready": (
			not runtime_hud_visibility_snapshot.is_empty()
		)
	}
func _resident_fail_bootstrap(
	reason: String,
	step_id: String,
	details: Dictionary = {}
) -> void:
	resident_runtime_bootstrap_failed = true
	resident_runtime_bootstrap_complete = false
	resident_runtime_bootstrap_failure = {
		"reason": reason,
		"step_id": step_id,
		"details": details.duplicate(true),
		"failed_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	if typeof(
		scenario_state
	) != TYPE_DICTIONARY:
		scenario_state = {}

	scenario_state [
		"resident_runtime_bootstrap_failure"
	] = resident_runtime_bootstrap_failure.duplicate(true)


func _resident_dict(
	value: Variant
) -> Dictionary:
	return (
		(value as Dictionary).duplicate(true)
		if typeof(value) == TYPE_DICTIONARY
		else {}
	)



func initialize():
	_hydrate_reality_settings()

	if typeof(scenario_state) != TYPE_DICTIONARY:
		scenario_state = {}




	if bool(scenario_state.get("birth_shell_first_boot", false)):
		_initialize_birth_shell_first_life()
		return

	if game_state_contract_engine == null:
		game_state_contract_engine = GameStateContractEngine.new(self)

	var game_state_boot_report: Dictionary = game_state_contract_engine.bootstrap_kernel_contract({
		"phase": "pre_engine_boot",
		"allow_external_contracts": true
	})
	scenario_state ["game_state_contract_last_boot_report"] = game_state_boot_report.duplicate(true)

	contract_meta_governor = game_state_contract_engine.contract_meta_governor
	scenario_state ["contract_meta_governor_report"] = game_state_contract_engine.apply_contract_meta_governor({
		"phase": "post_contract_boot",
		"include_runtime": false
	}).duplicate(true)

	if not scenario_state.has("defer_static_world_bootstrap"):
		scenario_state ["defer_static_world_bootstrap"] = true
	if not scenario_state.has("defer_live_runtime_watchers"):
		scenario_state ["defer_live_runtime_watchers"] = true
	var defer_static_world_bootstrap: bool = bool(scenario_state.get("defer_static_world_bootstrap", true))
	var defer_live_runtime_watchers: bool = bool(scenario_state.get("defer_live_runtime_watchers", true))

	event_bus = EventBus.new(self)
	event_bus_contract_layer = event_bus.contract_layer

	if game_state_contract_engine != null:
		var event_bus_contract_boot_report: Dictionary = game_state_contract_engine.apply_event_bus_contracts(event_bus)
		scenario_state ["event_bus_contract_layer_report"] = event_bus_contract_boot_report.duplicate(true)

		var meta_boot_report: Dictionary = game_state_contract_engine.apply_contract_meta_governor({
			"phase": "post_event_bus_contract_boot",
			"include_runtime": true
		})
		scenario_state ["contract_meta_governor_report"] = meta_boot_report.duplicate(true)

	world_space_engine = WorldSpaceEngine.new(self)
	spatial_culling_engine = SpatialCullingEngine.new(self)
	emergent_story_engine = EmergentNPCStoryEngine.new(self)
	economy_engine = EconomyEngine.new(self)
	bank_engine = BankEngine.new(self)
	historical_timeline_engine = HistoricalTimelineEngine.new(self)
	global_market_engine = GlobalMarketEngine.new(self)
	ecs_engine = ECSEngine.new(self)
	chunk_simulation_engine = ChunkSimulationEngine.new(self)
	population_shard_engine = PopulationShardEngine.new(self)

	if event_bus != null and event_bus.contract_layer != null and event_bus.contract_layer.has_method("register_contract"):
		event_bus.contract_layer.register_contract(population_shard_engine.get_event_bus_contract())

	population_lifecycle_manager = PopulationLifecycleManager.new(self)

	geo_engine = GeoEngine.new(self)
	settlement_presence_engine = SettlementPresenceEngine.new(self)
	migration_engine = MigrationEngine.new(self)
	place_influence_engine = PlaceInfluenceEngine.new(self)
	seed_engine = SeedEngine.new(self)
	seed_engine.initialize()
	soul_seed_engine = SoulSeedEngine.new(self)
	consciousness_engine = ConsciousnessEngine.new(self)
	willpower_engine = WillpowerEngine.new(self)
	social_graph_engine = SocialGraphEngine.new(self)
	workplace_engine = WorkplaceEngine.new(self)
	player_action_engine = PlayerActionEngine.new(self)
	npc_memory_web_engine = NPCMemoryWebEngine.new(self)
	agent_memory_propagation_engine = AgentMemoryPropagationEngine.new(self)
	dynamic_world_event_engine = DynamicWorldEventEngine.new(self)
	action_discovery_engine = ActionDiscoveryEngine.new(self)
	names_db = NamesDB.new(self)
	npc_factory = NPCFactory.new(self)
	character_creator = CharacterCreator.new(self)
	legacy_memory_engine = LegacyMemoryEngine.new(self)
	legacy_echo_engine = LegacyEchoEngine.new(self)
	afterlife_influence_engine = AfterlifeInfluenceEngine.new(self)

	scenario_resolver = ScenarioResolver.new(self)
	scenario_engine = ScenarioEngine.new(self)
	scenario_popup_contract_engine = ScenarioPopupContractEngine.new(self)
	scenario_runtime_contract_engine = ScenarioRuntimeContractEngine.new(self)
	pending_situations_engine = PendingSituationsEngine.new(self)
	contract_view_layer_contract_engine = ContractViewLayerContractEngine.new(self)
	traits_contract_engine = TraitsContractEngine.new(self)
	identity_contract_engine = IdentityContractEngine.new(self)
	event_engine = EventEngine.new(self)
	relationship_engine = RelationshipEngine.new(self)
	memory_engine = MemoryEngine.new(self)
	health_engine = HealthEngine.new(self)
	genetics_inheritance_engine = GeneticsInheritanceEngine.new(self)
	body_type_contract_engine = BodyTypeContractEngine.new(self)
	growth_curve_engine = GrowthCurveEngine.new(self)
	height_contract_engine = HeightContractEngine.new(self)
	weight_contract_engine = WeightContractEngine.new(self)



	career_runtime_engine = CareerRuntimeEngine.new(self)



	career_contract_engine = CareerContractEngine.new(self)



	career_space_contract_engine = CareerSpaceContractEngine.new(self)



	career_hub_contract_engine = CareerHubContractEngine.new(self)



	activities_contract_engine = ActivitiesContractEngine.new(self)


	activities_hub_contract_engine = ActivitiesHubContractEngine.new(self)


	career_engine = CareerEngine.new(self)

	school_engine = SchoolEngine.new(
		self
	)
	school_hub_contract_engine = SchoolHubContractEngine.new(
		self
	)

	family_contract_engine = FamilyContractEngine.new(
		self
	)
	checks_and_balances_contract_engine = (
		ChecksAndBalancesContractEngine.new(
			self
		)
	)
	family_control_engine = FamilyControlEngine.new(
		self
	)
	universal_switch_contract_engine = (
		UniversalSwitchContractEngine.new(
			self
		)
	)
	relationships_hub_contract_engine = (
		RelationshipsHubContractEngine.new(
			self,
			universal_switch_contract_engine
		)
	)
	crr_contract_engine = CRRContractEngine.new(
		self
	)
	global_intent_contract_engine = (
		GlobalIntentContractEngine.new(
			self
		)
	)



	mod_contract_engine = ModContractEngine.new(self)



	caveman_reality_runtime_engine = (
		CavemanRealityRuntimeEngine.new(self)
	)


	mod_bundle_contract_engine = (
		ModBundleContractEngine.new(self)
	)



	mod_marketplace_contract_engine = (
		ModMarketplaceContractEngine.new(self)
	)



	mod_hub_contract_engine = ModHubContractEngine.new(self)



	mod_menu_contract_engine = ModMenuContractEngine.new(self)

	if caveman_reality_runtime_engine != null:
		caveman_reality_runtime_engine.bootstrap_default_contracts()

	if mod_bundle_contract_engine != null:
		mod_bundle_contract_engine.bootstrap_default_contracts()

	checks_and_balances_contract_engine = ChecksAndBalancesContractEngine.new(self)
	fate_engine = FateEngine.new(self)
	life_diary_contract_engine = LifeDiaryContractEngine.new(self)
	life_engine = LifeEngine.new(self)
	narrative_governor = NarrativeGovernor.new(self)
	perceptual_integrity_engine = PerceptualIntegrityEngine.new(self)
	choose_adventure_ai_node_generator = ChooseAdventureAINodeGenerator.new(self)
	choose_adventure_scenario_engine = ChooseAdventureScenarioEngine.new(self)
	choose_adventure_engine = ChooseAdventureEngine.new(self)
	family_creation_contract_engine = FamilyCreationContractEngine.new(self)
	narrative_engine = NarrativeEngine.new(self)
	llm_bridge = LLMNarrativeBridge.new(self)
	bending_engine = BendingEngine.new(self)
	bending_tournament_engine = BendingTournamentEngine.new(self)
	avatar_influence_engine = AvatarInfluenceEngine.new(self)
	bending_dojo_engine = BendingDojoEngine.new(self)
	wizard_engine = WizardEngine.new(self)
	power_engine = PowerEngine.new(self)
	superhero_engine = SuperHeroEngine.new(self)
	infamy_engine = InfamyEngine.new(self)
	lineage_engine = LineageEngine.new(self)
	dynasty_engine = DynastyEngine.new(self)

	era_engine = EraEngine.new(self)


	era_mod_contract_engine = EraModContractEngine.new(self)


	era_contract_engine = EraContractEngine.new(self)

	if era_mod_contract_engine != null:
		era_mod_contract_engine.bootstrap_default_contracts()

	if era_contract_engine != null:
		era_contract_engine.bootstrap_default_contracts()

	world_feed_engine = WorldFeedEngine.new(self)
	world_chronicle_engine = WorldChronicleEngine.new(self)
	reputation_engine = ReputationEngine.new(self)
	artifacts_engine = ArtifactsEngine.new(
		self
	)
	artifacts_catalog_contract_engine = (
		ArtifactsCatalogContractEngine.new(
			self
		)
	)
	artifact_interaction_contract_engine = (
		ArtifactInteractionContractEngine.new(
			self
		)
	)
	artifact_shop_contract_engine = (
		ArtifactShopContractEngine.new(
			self
		)
	)

	realm_contract_engine = RealmContractEngine.new(
		self
	)
	simulation_contract_engine = SimulationContractEngine.new(self)
	runtime_contract_engine = RuntimeContractEngine.new(self)
	romance_contract_engine = RomanceContractEngine.new(self)
	ui_contract_engine = UIContractEngine.new(self)
	embedded_ui_contract_engine = EmbeddedUIContractEngine.new(self)
	birth_contract_engine = BirthContractEngine.new(self)
	many_realms_engine = ManyRealmsEngine.new(self)
	bridge_to_terabithia_engine = BridgeToTerabithiaEngine.new(self)
	vormir_engine = VormirEngine.new(self)
	nidavellir_engine = NidavellirEngine.new(self)
	dragonballs_engine = DragonBallsEngine.new(self)
	dynasty_legacy_engine = DynastyLegacyEngine.new(self)
	weapons_engine = WeaponsEngine.new(self)
	weapons_catalog_expansion = WeaponsCatalogExpansion.new(
		self
	)
	crime_contract_engine = CrimeContractEngine.new(self)
	investigation_layer = InvestigationLayer.new(self)
	justice_system_engine = JusticeSystemEngine.new(self)
	jail_engine = JailEngine.new(self)
	prison_engine = PrisonEngine.new(self)
	case_orchestrator = CaseOrchestrator.new(self)
	crime_engine = CrimeEngine.new(self)
	crime_hub_contract_engine = CrimeHubContractEngine.new(
		self
	)
	relationship_activities_engine = RelationshipActivitiesEngine.new(self)
	human_contract_engine = HumanContractEngine.new(self)
	animal_contract_engine = AnimalContractEngine.new(self)
	mythical_contract_engine = MythicalContractEngine.new(self)
	relationship_graph_contract_engine = RelationshipGraphContractEngine.new(self)
	human_relationship_contract_engine = HumanRelationshipContractEngine.new(self)
	pets_contract_engine = PetsContractEngine.new(self)
	mythical_pets_contract_engine = MythicalPetsContractEngine.new(self)
	pet_shop_contract_engine = PetShopContractEngine.new(self)
	breeding_contract_engine = BreedingContractEngine.new(self)
	debt_contract_engine = DebtContractEngine.new(self)
	meat_market_contract_engine = MeatMarketContractEngine.new(self)
	realm_engine = RealmEngine.new(self)
	class_engine = ClassEngine.new(self)
	fame_engine = FameEngine.new(self)
	upce_engine = UniversalPerceptionConsequenceEngine.new(self)
	if upce_engine != null:
		upce_engine.bootstrap_default_contracts()

	royalty_engine = RoyaltyEngine.new(self)


	royalty_runtime_engine = RoyaltyRuntimeEngine.new(self)


	royalty_mod_contract_engine = RoyaltyModContractEngine.new(self)


	royalty_contract_engine = RoyaltyContractEngine.new(self)


	crown_hub_contract_engine = CrownHubContractEngine.new(self)

	if royalty_mod_contract_engine != null:
		royalty_mod_contract_engine.bootstrap_default_contracts()

	if royalty_contract_engine != null:
		royalty_contract_engine.bootstrap_default_contracts()

	if royalty_runtime_engine != null:
		royalty_runtime_engine.bootstrap_default_contracts()

	if crown_hub_contract_engine != null:
		crown_hub_contract_engine.bootstrap_default_contracts()

	politics_engine = PoliticsEngine.new(self)
	property_engine = PropertyEngine.new(self)
	era_life_asset_catalog_expansion = EraLifeAssetCatalogExpansion.new(self)
	property_amenity_synthesis_contract_engine = PropertyAmenitySynthesisContractEngine.new(self)
	vehicle_engine = VehicleEngine.new(self)
	card_contract_engine = CardContractEngine.new(self)
	property_market_contract_engine = PropertyMarketContractEngine.new(self)
	dealership_contract_engine = DealershipContractEngine.new(self)
	assets_contract_engine = AssetsContractEngine.new(self)
	room_graph_contract_engine = RoomGraphContractEngine.new(self)
	spatial_traversal_contract_engine = SpatialTraversalContractEngine.new(self)
	presence_engine = PresenceEngine.new(self)
	property_makeover_contract_engine = PropertyMakeoverContractEngine.new(self)
	shared_public_space_engine = SharedPublicSpaceEngine.new(self)
	food_engine = FoodEngine.new(self)
	food_restaurant_engine = FoodRestaurantEngine.new(self)
	grocery_store_engine = GroceryStoreEngine.new(self)
	movie_theater_engine = MovieTheaterEngine.new(self)
	if movie_theater_engine != null and movie_theater_engine.has_method("bootstrap_ui_contracts"):
		movie_theater_engine.bootstrap_ui_contracts()
	if runtime_contract_engine != null and runtime_contract_engine.has_method("ensure_default_world_contracts"):
		runtime_contract_engine.ensure_default_world_contracts({
			"source": "game_state_post_movie_theater_boot",
		})
	luxury_shop_engine = LuxuryShopEngine.new(self)

	heirloom_runtime_engine = HeirloomRuntimeEngine.new(
		self
	)
	heirloom_contract_engine = HeirloomContractEngine.new(
		self
	)
	heirloom_engine = HeirloomEngine.new(
		self
	)
	heirloom_catalog_contract_engine = (
		HeirloomCatalogContractEngine.new(
			self
		)
	)
	heirloom_hub_contract_engine = HeirloomHubContractEngine.new(
		self
	)

	island_realm_engine = IslandRealmExpansionEngine.new(
		self
	)
	global_prewarm_contract_engine = GlobalPrewarmContractEngine.new(self)
	global_node_contract_engine = GlobalNodeContractEngine.new(self)
	truth_resolution_contract_engine = TruthResolutionContractEngine.new(self)
	observable_node_contract_engine = ObservableNodeContractEngine.new(self)
	world_observability_contract_engine = WorldObservabilityContractEngine.new(self)
	population_movement_contract_engine = PopulationMovementContractEngine.new(self)
	crown_population_view_contract = CrownPopulationViewContract.new(self)
	population_card_contract_engine = PopulationCardContractEngine.new(self)
	belongings_engine = BelongingsEngine.new(
		self
	)

	_resident_bootstrap_heirloom_contracts()

	global_object_catalog_system = GlobalObjectCatalogSystem.new(
		self
	)
	object_hub_contract_engine = ObjectHubContractEngine.new(
		self
	)

	_resident_bootstrap_global_object_catalog()
	_resident_bootstrap_object_projection_contracts()

	desire_engine = DesireEngine.new(
		self
	)
	capability_graph_engine = CapabilityGraphEngine.new(self)
	goal_planning_engine = GoalPlanningEngine.new(self)
	simulation_director = SimulationDirector.new(self)
	year_budget_engine = YearBudgetEngine.new(self)
	desire_behavior_bridge = DesireBehaviorBridge.new(self)
	ai_event_engine = AIEventGenerator.new(self)
	if era_data_loader == null:
		era_data_loader = EraDataLoader.new(self)
	if weapon_pack_loader == null:
		weapon_pack_loader = WeaponPackLoader.new(self)
	if game_state_contract_engine == null:
		game_state_contract_engine = GameStateContractEngine.new(self)
	if mod_loader == null:
		mod_loader = ModLoader.new(self)

	if not defer_static_world_bootstrap:
		scenario_state ["deferred_data_bootstrap_pending"] = false

	if not external_era_data_loaded:
		era_data_loader.load_external_eras()
		external_era_data_loaded = true

	if not asset_catalogs_loaded:
		era_data_loader.load_asset_catalogs()
		asset_catalogs_loaded = true

	if not weapon_packs_loaded:
		weapon_pack_loader.load_weapon_packs()
		weapon_packs_loaded = true

	if not mods_loaded:


		var mod_ingestion_report: Dictionary = mod_loader.load_mods({
			"hot_apply": false,
			"source": "game_state_boot_ingestion"
		})




		var mod_platform_report: Dictionary = (
			mod_contract_engine.bootstrap_from_loader({
				"apply_runtime": true,
				"source": "game_state_boot_mod_platform"
			})
			if mod_contract_engine != null
			else {
				"success": false,
				"reason": "missing_mod_contract_engine"
			}
		)

		mod_contract_registry = (
			mod_contract_engine.export_registry()
			if (
				mod_contract_engine != null
				and mod_contract_engine.has_method("export_registry")
			)
			else {}
		)
		mod_provider_registry = (
			mod_contract_engine
				.provider_resolution_registry
				.duplicate(true)
			if mod_contract_engine != null
			else {}
		)
		mod_conflict_registry = (
			mod_contract_engine
				.provider_conflict_registry
				.duplicate(true)
			if mod_contract_engine != null
			else {}
		)

		mod_contract_runtime_report = {
			"schema": "eralife.mod_platform_runtime_report",
			"version": 1,
			"ingestion": mod_ingestion_report.duplicate(true),
			"platform": mod_platform_report.duplicate(true),
			"booted_at_ms": int(Time.get_ticks_msec())
		}
		scenario_state ["mod_contract_last_load_report"] = (
			mod_contract_runtime_report.duplicate(true)
		)
		mods_loaded = bool(
			mod_platform_report.get(
				"success",
				false
			)
		)

	if simulation_contract_engine != null and simulation_contract_engine.has_method("load_external_packs"):
		simulation_contract_engine.load_external_packs()
	else:
		scenario_state ["deferred_data_bootstrap_pending"] = true
	boxing_contract_engine = BoxingContractEngine.new(self)
	boxing_combat_resolution_engine = BoxingCombatResolutionEngine.new(self)
	boxing_fight_economy_engine = BoxingFightEconomyEngine.new(self)
	boxing_fighter_engine = BoxingFighterEngine.new(self)
	boxing_training_engine = BoxingTrainingEngine.new(self)
	boxing_matchmaking_engine = BoxingMatchmakingEngine.new(self)
	boxing_fight_sim_engine = BoxingFightSimEngine.new(self)
	boxing_ranking_engine = BoxingRankingEngine.new(self)
	boxing_title_engine = BoxingTitleEngine.new(self)
	boxing_injury_engine = BoxingInjuryEngine.new(self)
	boxing_engine = BoxingEngine.new(self)
	boxing_round_log_engine = BoxingRoundLogEngine.new(self)
	boxing_rivalry_engine = BoxingRivalryEngine.new(self)
	boxing_gym_engine = BoxingGymEngine.new(self)
	boxing_promotion_engine = BoxingPromotionEngine.new(self)
	boxing_weight_engine = BoxingWeightEngine.new(self)
	boxing_mandatory_engine = BoxingMandatoryEngine.new(self)
	boxing_amateur_engine = BoxingAmateurEngine.new(self)
	boxing_media_engine = BoxingMediaEngine.new(self)
	boxing_legacy_engine = BoxingLegacyEngine.new(self)
	if boxing_contract_engine != null:
		boxing_contract_engine.set_contract()
	competitive_reality_runtime = CompetitiveRealityRuntime.new(self)
	if competitive_reality_runtime != null:
		competitive_reality_runtime.bootstrap_default_contracts()
	reality_surge_engine = RealitySurgeEngine.new(self)
	if reality_surge_engine != null:
		reality_surge_engine.bootstrap_default_contracts()
	reality_orchestrator = RealityOrchestrator.new(self)
	if reality_orchestrator != null:
		reality_orchestrator.bootstrap_default_contracts()

	causality_inversion_engine = CausalityInversionEngine.new(self)
	if causality_inversion_engine != null:
		causality_inversion_engine.bootstrap_default_contracts()

	causality_inversion_engine = CausalityInversionEngine.new(self)
	if causality_inversion_engine != null:
		causality_inversion_engine.bootstrap_default_contracts()
	vampire_origin_engine = VampireOriginEngine.new(self)
	vampire_hunger_engine = VampireHungerEngine.new(self)
	vampire_ability_engine = VampireAbilityEngine.new(self)
	vampire_society_engine = VampireSocietyEngine.new(self)
	vampire_hunter_engine = VampireHunterEngine.new(self)
	vampire_legacy_engine = VampireLegacyEngine.new(self)
	vampire_masquerade_engine = VampireMasqueradeEngine.new(self)
	vampire_cure_engine = VampireCureEngine.new(self)
	vampire_engine = VampireEngine.new(self)
	universal_faction_engine = UniversalFactionEngine.new(self)
	runtime_health_registry = RuntimeHealthRegistry.new(self)
	runtime_fault_router = RuntimeFaultRouter.new(self)
	patch_suggestion_engine = PatchSuggestionEngine.new(self)
	live_patch_guard = LivePatchGuard.new(self)
	auto_patch_engine = AutoPatchEngine.new(self)
	live_diagnostics_engine = LiveDiagnosticsEngine.new(self)

	if game_state_contract_engine == null:
		game_state_contract_engine = GameStateContractEngine.new(self)

	game_state_contract_engine.instantiate_contract_engine_extensions()
	game_state_contract_engine.register_existing_engines_from_game_state()
	game_state_contract_engine.validate_active_contracts({
		"phase": "post_engine_boot",
		"include_runtime": true
	})
	game_state_contract_engine.recover_missing_engines({
		"phase": "post_engine_boot"
	})
	game_state_contract_engine.build_runtime_phase_budget_report({
		"phase": "post_engine_boot"
	})
	game_state_contract_engine.apply_runtime_guards({
		"phase": "post_engine_boot"
	})
	game_state_contract_engine.hydrate_runtime_state({
		"phase": "post_engine_boot"
	})

	simulation_director.register_default_runtime_listeners()
	if defer_static_world_bootstrap or defer_live_runtime_watchers:
		scenario_state ["deferred_runtime_watchers_bootstrap"] = true
	elif live_diagnostics_engine != null:
		live_diagnostics_engine.bootstrap_runtime_watchers()
		scenario_state ["deferred_runtime_watchers_bootstrap"] = false
	else:
		scenario_state ["deferred_runtime_watchers_bootstrap"] = false

	if career_runtime_engine != null:
		event_bus.subscribe(
			ActionEventTypes.YEAR_PASSED,
			career_runtime_engine,
			"yearly_tick",
			{
				"lane": "important",
				"allow_defer": true,
				"subscription_priority": 82,
				"subscription_id": "career_runtime_yearly_tick"
			}
		)

		event_bus.subscribe(
			ActionEventTypes.NPC_DIED,
			career_runtime_engine,
			"on_npc_died",
			{
				"lane": "important",
				"allow_defer": false,
				"subscription_priority": 42,
				"subscription_id": "career_runtime_position_vacancy_on_death"
			}
		)

		event_bus.subscribe(
			ActionEventTypes.ERA_SHIFT,
			career_runtime_engine,
			"on_era_shift",
			{
				"lane": "important",
				"allow_defer": true,
				"subscription_priority": 72,
				"subscription_id": "career_runtime_era_shift"
			}
		)
	if checks_and_balances_contract_engine != null:
		event_bus.subscribe("government.authority.review_outcome", checks_and_balances_contract_engine, "on_authority_review_outcome", {
			"lane": "important",
			"allow_defer": true,
			"subscription_priority": 44,
			"subscription_id": "checks_and_balances_authority_review_outcome"
		})

	if life_diary_contract_engine != null:
		event_bus.subscribe(ActionEventTypes.NPC_BORN, life_diary_contract_engine, "on_npc_born")
		event_bus.subscribe("npc_born", life_diary_contract_engine, "on_npc_born")
	if breeding_contract_engine != null:
		event_bus.subscribe(ActionEventTypes.YEAR_PASSED, breeding_contract_engine, "yearly_tick")

	if debt_contract_engine != null:
		event_bus.subscribe(ActionEventTypes.YEAR_PASSED, debt_contract_engine, "yearly_tick")
	event_bus.subscribe(ActionEventTypes.PLAYER_DIED, afterlife_influence_engine, "on_player_died")
	event_bus.subscribe(ActionEventTypes.NPC_BORN, afterlife_influence_engine, "on_npc_born")
	event_bus.subscribe(ActionEventTypes.YEAR_PASSED, global_market_engine, "yearly_market_tick")
	event_bus.subscribe(ActionEventTypes.ERA_SHIFT, global_market_engine, "on_era_shift")
	event_bus.subscribe(ActionEventTypes.REALM_WAR, global_market_engine, "on_realm_war")
	event_bus.subscribe(ActionEventTypes.TRADE_EXECUTED, global_market_engine, "on_trade_executed")
	event_bus.subscribe(ActionEventTypes.YEAR_PASSED, economy_engine, "yearly_market_update")
	event_bus.subscribe(ActionEventTypes.ERA_SHIFT, economy_engine, "on_era_shift")
	event_bus.subscribe(ActionEventTypes.NPC_DIED, red_bonnet_engine, "handle_inheritance")
	event_bus.subscribe(ActionEventTypes.NPC_DIED, artifacts_engine, "handle_inheritance")
	event_bus.subscribe(ActionEventTypes.NPC_DIED, dragonballs_engine, "handle_inheritance")
	event_bus.subscribe(ActionEventTypes.NPC_DIED, property_engine, "handle_inheritance")
	event_bus.subscribe(ActionEventTypes.NPC_DIED, dynasty_engine, "_on_npc_death")

	if dragonballs_engine != null:
		event_bus.subscribe(ActionEventTypes.NPC_BORN, dragonballs_engine, "on_npc_born")
		event_bus.subscribe(ActionEventTypes.YEAR_PASSED, dragonballs_engine, "yearly_chance")
	event_bus.subscribe(ActionEventTypes.ARTIFACT_ACQUIRED, self, "_queue_player_inheritance_popup_from_artifact_event")
	event_bus.subscribe(ActionEventTypes.NPC_DIED, bending_engine, "on_avatar_death")
	event_bus.subscribe(ActionEventTypes.NPC_DIED, bending_engine, "on_avatar_death")
	event_bus.subscribe(ActionEventTypes.NPC_BORN, bending_engine, "assign_bending")
	event_bus.subscribe(ActionEventTypes.YEAR_PASSED, bending_engine, "yearly_tick")
	if bending_tournament_engine != null:
		event_bus.subscribe(ActionEventTypes.YEAR_PASSED, bending_tournament_engine, "yearly_tick")
	if wizard_engine != null:
		event_bus.subscribe(ActionEventTypes.NPC_BORN, wizard_engine, "assign_wizard_lineage")
		event_bus.subscribe(ActionEventTypes.NPC_MARRIED, wizard_engine, "on_marriage")
		event_bus.subscribe(ActionEventTypes.YEAR_PASSED, wizard_engine, "yearly_tick")
	if power_engine != null:
		event_bus.subscribe(ActionEventTypes.NPC_BORN, power_engine, "assign_birth_powers")
		event_bus.subscribe(ActionEventTypes.YEAR_PASSED, power_engine, "yearly_tick")
	if superhero_engine != null:
		event_bus.subscribe(ActionEventTypes.YEAR_PASSED, superhero_engine, "yearly_tick")
	if infamy_engine != null:
		event_bus.subscribe(ActionEventTypes.YEAR_PASSED, infamy_engine, "yearly_tick")
	event_bus.subscribe(ActionEventTypes.YEAR_PASSED, fame_engine, "yearly_fame_tick")

	event_bus.subscribe(ActionEventTypes.YEAR_PASSED, fame_engine, "yearly_fame_tick")
	event_bus.subscribe("year_passed", realm_engine, "yearly_realm_drift")
	event_bus.subscribe("year_passed", population_movement_contract_engine, "run_yearly_migration_contracts")
	event_bus.subscribe("npc_born", dynasty_engine, "_on_birth")
	event_bus.subscribe("npc_born", class_engine, "assign_birth_class")
	event_bus.subscribe("npc_born", realm_engine, "assign_realm")
	if royalty_contract_engine != null:
		event_bus.subscribe(
			ActionEventTypes.NPC_BORN,
			royalty_contract_engine,
			"on_npc_born",
			{
				"lane": "important",
				"allow_defer": false,
				"subscription_priority": 38,
				"subscription_id": (
					"royalty_contract_birth_resolution"
				)
			}
		)

		event_bus.subscribe(
			"npc_born",
			royalty_contract_engine,
			"on_npc_born",
			{
				"lane": "important",
				"allow_defer": false,
				"subscription_priority": 38,
				"subscription_id": (
					"royalty_contract_legacy_birth_resolution"
				)
			}
		)

		event_bus.subscribe(
			ActionEventTypes.NPC_MARRIED,
			royalty_contract_engine,
			"on_npc_married",
			{
				"lane": "important",
				"allow_defer": true,
				"subscription_priority": 46,
				"subscription_id": (
					"royalty_contract_marriage_resolution"
				)
			}
		)

	if royalty_runtime_engine != null:
		event_bus.subscribe(
			ActionEventTypes.NPC_DIED,
			royalty_runtime_engine,
			"on_npc_died",
			{
				"lane": "important",
				"allow_defer": false,
				"subscription_priority": 34,
				"subscription_id": (
					"royalty_runtime_succession_on_death"
				)
			}
		)

		event_bus.subscribe(
			ActionEventTypes.YEAR_PASSED,
			royalty_runtime_engine,
			"yearly_tick",
			{
				"lane": "important",
				"allow_defer": true,
				"subscription_priority": 74,
				"subscription_id": (
					"royalty_runtime_yearly_reconciliation"
				)
			}
		)

		event_bus.subscribe(
			ActionEventTypes.ERA_SHIFT,
			royalty_runtime_engine,
			"on_era_shift",
			{
				"lane": "important",
				"allow_defer": true,
				"subscription_priority": 71,
				"subscription_id": (
					"royalty_runtime_era_shift_reconciliation"
				)
			}
		)
	event_bus.subscribe("npc_born", fame_engine, "assign_child_fame")
	event_bus.subscribe("year_passed", simulation_director, "yearly_evaluation")

	if population_lifecycle_manager != null and not defer_static_world_bootstrap:
		population_lifecycle_manager.bootstrap_pre_ui_population_state()
	elif typeof(scenario_state) == TYPE_DICTIONARY:
		scenario_state ["population_bootstrap_ready"] = false
	if population_shard_engine != null:
		event_bus.subscribe("population.year.tick", population_shard_engine, "on_population_year_tick", {
			"lane": "ambient",
			"allow_defer": true,
			"subscription_priority": 85
		})

		event_bus.subscribe("population.shard.spawn_entity", population_shard_engine, "on_population_spawn_entity", {
			"lane": "important",
			"allow_defer": false,
			"subscription_priority": 60
		})



	event_bus.subscribe(ActionEventTypes.NPC_MARRIED, relationship_engine, "on_marriage")
	event_bus.subscribe(ActionEventTypes.NPC_DIVORCED, relationship_engine, "on_divorce")
	event_bus.subscribe(ActionEventTypes.NPC_PARTNERED, relationship_engine, "on_partner")

	if family_contract_engine != null:
		event_bus.subscribe(ActionEventTypes.NPC_BORN, family_contract_engine, "on_npc_born")
		event_bus.subscribe(ActionEventTypes.NPC_MARRIED, family_contract_engine, "on_family_structure_changed")
		event_bus.subscribe(ActionEventTypes.NPC_DIVORCED, family_contract_engine, "on_family_structure_changed")
		event_bus.subscribe(ActionEventTypes.NPC_PARTNERED, family_contract_engine, "on_family_structure_changed")
		event_bus.subscribe(ActionEventTypes.NPC_DIED, family_contract_engine, "on_npc_died")
		event_bus.subscribe(ActionEventTypes.YEAR_PASSED, family_contract_engine, "yearly_tick")

	event_bus.subscribe(ActionEventTypes.NPC_DIED, family_control_engine, "handle_spousal_estate_inheritance")



	event_bus.subscribe(ActionEventTypes.NPC_COMMITTED_CRIME, reputation_engine, "on_reputation_event")
	event_bus.subscribe(ActionEventTypes.FAME_SPIKE, reputation_engine, "on_reputation_event")
	event_bus.subscribe(ActionEventTypes.NPC_DIED, reputation_engine, "on_reputation_event")
	event_bus.subscribe(ActionEventTypes.ARTIFACT_ACQUIRED, reputation_engine, "on_reputation_event")
	event_bus.subscribe(ActionEventTypes.WISH_MADE, reputation_engine, "on_reputation_event")
	event_bus.subscribe(ActionEventTypes.DYNASTY_SHIFT, reputation_engine, "on_reputation_event")



	event_bus.subscribe(ActionEventTypes.NPC_ARRESTED, fame_engine, "apply_scandal")
	event_bus.subscribe(ActionEventTypes.NPC_ARRESTED, class_engine, "yearly_class_shift")
	event_bus.subscribe(ActionEventTypes.NPC_COMMITTED_CRIME, narrative_engine, "log_event")
	event_bus.subscribe(ActionEventTypes.CASE_VERDICT_RETURNED, narrative_engine, "log_event")
	event_bus.subscribe(ActionEventTypes.CASE_SENTENCED, reputation_engine, "on_reputation_event")
	event_bus.subscribe(ActionEventTypes.PRISON_RELEASED, reputation_engine, "on_reputation_event")
	event_bus.subscribe(ActionEventTypes.JUSTICE_ECONOMIC_PENALTY, reputation_engine, "on_reputation_event")




	event_bus.subscribe(ActionEventTypes.PROPERTY_PURCHASED, class_engine, "yearly_class_shift")
	event_bus.subscribe(ActionEventTypes.VEHICLE_PURCHASED, fame_engine, "lifestyle_signal")
	event_bus.subscribe(ActionEventTypes.HEIRLOOM_ACQUIRED, dynasty_engine, "prestige_gain")




	event_bus.subscribe(ActionEventTypes.ARTIFACT_ACQUIRED, fame_engine, "legendary_signal")
	event_bus.subscribe(ActionEventTypes.DRAGONBALL_FOUND, narrative_engine, "log_event")
	event_bus.subscribe(ActionEventTypes.GAUNTLET_FORGED, narrative_engine, "log_event")
	event_bus.subscribe(ActionEventTypes.COSMIC_ENFORCER_SPAWNED, ai_event_engine, "handle_cosmic_event")




	event_bus.subscribe(ActionEventTypes.ERA_SHIFT, realm_engine, "bootstrap_realms_for_era")
	event_bus.subscribe(ActionEventTypes.ERA_SHIFT, class_engine, "global_rebalance")
	event_bus.subscribe(ActionEventTypes.NPC_MOVED, world_feed_engine, "handle_event_from_bus")




	event_bus.subscribe(ActionEventTypes.FAME_SPIKE, class_engine, "yearly_class_shift")
	event_bus.subscribe(ActionEventTypes.SCANDAL, fame_engine, "apply_scandal")




	event_bus.subscribe(ActionEventTypes.PLAYER_DIED, dynasty_engine, "handle_player_death")
	event_bus.subscribe(ActionEventTypes.DYNASTY_SHIFT, narrative_engine, "log_event")
	event_bus.subscribe(ActionEventTypes.WISH_MADE, narrative_engine, "log_event")
	event_bus.subscribe(ActionEventTypes.WISH_MADE, fame_engine, "legendary_signal")




	event_bus.subscribe(ActionEventTypes.REALTIME_TICK, relationship_engine, "update_relationships_for_npc")
	event_bus.subscribe(ActionEventTypes.REALTIME_TICK, health_engine, "update_health")
	event_bus.subscribe(ActionEventTypes.YEAR_PASSED, desire_engine, "yearly_tick")
	event_bus.subscribe(ActionEventTypes.YEAR_PASSED, food_engine, "yearly_tick")
	event_bus.subscribe(ActionEventTypes.YEAR_PASSED, food_engine, "decay_food_yearly")

	if genetics_inheritance_engine != null:
		event_bus.subscribe(ActionEventTypes.NPC_BORN, genetics_inheritance_engine, "on_npc_born", {
			"lane": "ambient",
			"allow_defer": true,
			"subscription_priority": 128
		})
		event_bus.subscribe(ActionEventTypes.YEAR_PASSED, genetics_inheritance_engine, "yearly_tick", {
			"lane": "ambient",
			"allow_defer": true,
			"subscription_priority": 128
		})

	if body_type_contract_engine != null:
		event_bus.subscribe(ActionEventTypes.NPC_BORN, body_type_contract_engine, "on_npc_born", {
			"lane": "ambient",
			"allow_defer": true,
			"subscription_priority": 129
		})
		event_bus.subscribe(ActionEventTypes.YEAR_PASSED, body_type_contract_engine, "yearly_tick", {
			"lane": "ambient",
			"allow_defer": true,
			"subscription_priority": 129
		})

	if growth_curve_engine != null:
		event_bus.subscribe(ActionEventTypes.NPC_BORN, growth_curve_engine, "on_npc_born", {
			"lane": "ambient",
			"allow_defer": true,
			"subscription_priority": 130
		})
		event_bus.subscribe(ActionEventTypes.YEAR_PASSED, growth_curve_engine, "yearly_tick", {
			"lane": "ambient",
			"allow_defer": true,
			"subscription_priority": 130
		})

	if height_contract_engine != null:
		event_bus.subscribe(ActionEventTypes.NPC_BORN, height_contract_engine, "on_npc_born", {
			"lane": "ambient",
			"allow_defer": true,
			"subscription_priority": 131
		})
		event_bus.subscribe(ActionEventTypes.YEAR_PASSED, height_contract_engine, "yearly_tick", {
			"lane": "ambient",
			"allow_defer": true,
			"subscription_priority": 131
		})

	if weight_contract_engine != null:
		event_bus.subscribe(ActionEventTypes.NPC_BORN, weight_contract_engine, "on_npc_born", {
			"lane": "ambient",
			"allow_defer": true,
			"subscription_priority": 132
		})
		event_bus.subscribe(ActionEventTypes.YEAR_PASSED, weight_contract_engine, "yearly_tick", {
			"lane": "ambient",
			"allow_defer": true,
			"subscription_priority": 132
		})
		event_bus.subscribe("body.weight.delta", weight_contract_engine, "on_weight_delta_requested", {
			"lane": "important",
			"allow_defer": true,
			"subscription_priority": 96
		})

	if runtime_contract_engine != null:
		event_bus.subscribe(ActionEventTypes.YEAR_PASSED, runtime_contract_engine, "yearly_tick")
	if romance_contract_engine != null:
		event_bus.subscribe(ActionEventTypes.YEAR_PASSED, romance_contract_engine, "yearly_tick")
	if shared_public_space_engine != null:
		event_bus.subscribe(ActionEventTypes.YEAR_PASSED, shared_public_space_engine, "yearly_tick")
	if grocery_store_engine != null:
		event_bus.subscribe(ActionEventTypes.YEAR_PASSED, grocery_store_engine, "yearly_tick")
	if movie_theater_engine != null:
		event_bus.subscribe(ActionEventTypes.YEAR_PASSED, movie_theater_engine, "yearly_tick")
	event_bus.subscribe(ActionEventTypes.YEAR_PASSED, simulation_contract_engine, "yearly_tick")
	event_bus.subscribe(ActionEventTypes.YEAR_PASSED, game_state_contract_engine, "yearly_tick")
	event_bus.subscribe(ActionEventTypes.YEAR_PASSED, bridge_to_terabithia_engine, "yearly_tick")
	event_bus.subscribe(ActionEventTypes.YEAR_PASSED, vormir_engine, "yearly_tick")
	event_bus.subscribe(ActionEventTypes.YEAR_PASSED, nidavellir_engine, "yearly_tick")
	event_bus.subscribe(ActionEventTypes.FAME_SPIKE, desire_engine, "on_fame_spike")
	event_bus.subscribe(ActionEventTypes.NPC_DIED, desire_engine, "on_npc_died")



	event_bus.subscribe(ActionEventTypes.NPC_BORN, world_chronicle_engine, "record_from_bus")
	event_bus.subscribe(ActionEventTypes.NPC_DIED, world_chronicle_engine, "record_from_bus")
	event_bus.subscribe(ActionEventTypes.NPC_MOVED, world_chronicle_engine, "record_from_bus")
	event_bus.subscribe(ActionEventTypes.ARTIFACT_ACQUIRED, world_chronicle_engine, "record_from_bus")
	event_bus.subscribe(ActionEventTypes.WISH_MADE, world_chronicle_engine, "record_from_bus")
	event_bus.subscribe(ActionEventTypes.REALM_WAR, world_chronicle_engine, "record_from_bus")
	event_bus.subscribe(ActionEventTypes.DYNASTY_SHIFT, world_chronicle_engine, "record_from_bus")
	event_bus.subscribe(ActionEventTypes.FAME_SPIKE, world_chronicle_engine, "record_from_bus")

	event_bus.subscribe(ActionEventTypes.NPC_COMMITTED_CRIME, npc_memory_web_engine, "record_memory")
	event_bus.subscribe(ActionEventTypes.NPC_DIED, npc_memory_web_engine, "record_memory")
	event_bus.subscribe(ActionEventTypes.ARTIFACT_ACQUIRED, npc_memory_web_engine, "record_memory")
	event_bus.subscribe(ActionEventTypes.WISH_MADE, npc_memory_web_engine, "record_memory")

	event_bus.subscribe(ActionEventTypes.NPC_BORN, historical_timeline_engine, "record_birth")
	event_bus.subscribe(ActionEventTypes.NPC_DIED, historical_timeline_engine, "record_death")
	event_bus.subscribe(ActionEventTypes.DYNASTY_SHIFT, historical_timeline_engine, "record_dynasty")
	event_bus.subscribe(ActionEventTypes.ERA_SHIFT, historical_timeline_engine, "record_era_shift")
	event_bus.subscribe(ActionEventTypes.YEAR_PASSED, agent_memory_propagation_engine, "yearly_tick")
	if pending_situations_engine != null:
		event_bus.subscribe("illness_minor", pending_situations_engine, "on_illness_event", {
			"lane": "important",
			"allow_defer": true,
			"subscription_priority": 42,
			"subscription_id": "pending_situations_illness_minor"
		})
		event_bus.subscribe("illness_major", pending_situations_engine, "on_illness_event", {
			"lane": "important",
			"allow_defer": true,
			"subscription_priority": 41,
			"subscription_id": "pending_situations_illness_major"
		})
	event_bus.subscribe(ActionEventTypes.NPC_DIED, agent_memory_propagation_engine, "capture_event")
	event_bus.subscribe(ActionEventTypes.NPC_COMMITTED_CRIME, agent_memory_propagation_engine, "capture_event")
	event_bus.subscribe(ActionEventTypes.ARTIFACT_ACQUIRED, agent_memory_propagation_engine, "capture_event")
	event_bus.subscribe(ActionEventTypes.WISH_MADE, agent_memory_propagation_engine, "capture_event")
	event_bus.subscribe(ActionEventTypes.FAME_SPIKE, agent_memory_propagation_engine, "capture_event")
	event_bus.subscribe(ActionEventTypes.NPC_MOVED, agent_memory_propagation_engine, "capture_event")
	event_bus.subscribe(ActionEventTypes.NPC_MARRIED, agent_memory_propagation_engine, "capture_event")
	event_bus.subscribe(ActionEventTypes.NPC_DIVORCED, agent_memory_propagation_engine, "capture_event")
	event_bus.subscribe(ActionEventTypes.NPC_PARTNERED, agent_memory_propagation_engine, "capture_event")
	event_bus.subscribe(ActionEventTypes.NPC_BORN, agent_memory_propagation_engine, "on_birth")

	event_bus.subscribe(ActionEventTypes.PLAYER_GIFTED_NPC, agent_memory_propagation_engine, "capture_event")
	event_bus.subscribe(ActionEventTypes.NPC_INSULTED, agent_memory_propagation_engine, "capture_event")
	event_bus.subscribe(ActionEventTypes.NPC_FOUGHT, agent_memory_propagation_engine, "capture_event")
	event_bus.subscribe(ActionEventTypes.NPC_CHEATED, agent_memory_propagation_engine, "capture_event")
	event_bus.subscribe(ActionEventTypes.NPC_BETRAYED, agent_memory_propagation_engine, "capture_event")
	event_bus.subscribe(ActionEventTypes.HEROIC_RESCUE, agent_memory_propagation_engine, "capture_event")
	event_bus.subscribe(ActionEventTypes.SCHOOL_DRAMA, agent_memory_propagation_engine, "capture_event")
	event_bus.subscribe(ActionEventTypes.CRIME_RUMOR_SPREAD, agent_memory_propagation_engine, "capture_event")
	event_bus.subscribe(ActionEventTypes.PREGNANCY_STARTED, agent_memory_propagation_engine, "capture_event")
	event_bus.subscribe(ActionEventTypes.CHILD_BORN_PLAYER_LINE, agent_memory_propagation_engine, "capture_event")
	event_bus.subscribe(ActionEventTypes.DYNASTY_FEUD_STARTED, agent_memory_propagation_engine, "capture_event")
	event_bus.subscribe(ActionEventTypes.ROMANCE_BETRAYAL, agent_memory_propagation_engine, "capture_event")

	for ev in ActionEventTypes.MEMORY_PROPAGATION_EVENTS:
		event_bus.subscribe(ev, world_chronicle_engine, "record_from_bus")
		event_bus.subscribe(ev, historical_timeline_engine, "record_event")
		event_bus.subscribe(ev, npc_memory_web_engine, "record_memory")
		event_bus.subscribe(ev, llm_bridge, "on_event")


	event_bus.subscribe(ActionEventTypes.CRIME_RUMOR_SPREAD, reputation_engine, "on_reputation_event")
	event_bus.subscribe(ActionEventTypes.HEROIC_RESCUE, reputation_engine, "on_reputation_event")
	event_bus.subscribe(ActionEventTypes.NPC_FOUGHT, reputation_engine, "on_reputation_event")
	event_bus.subscribe(ActionEventTypes.NPC_CHEATED, reputation_engine, "on_reputation_event")
	event_bus.subscribe(ActionEventTypes.NPC_BETRAYED, reputation_engine, "on_reputation_event")
	event_bus.subscribe(ActionEventTypes.DYNASTY_FEUD_STARTED, reputation_engine, "on_reputation_event")
	event_bus.subscribe(ActionEventTypes.ROMANCE_BETRAYAL, reputation_engine, "on_reputation_event")


	if upce_engine != null:
		for upce_event_name in ActionEventTypes.UNIVERSAL_PERCEPTION_EVENTS:
			event_bus.subscribe(str(upce_event_name), upce_engine, "on_event_from_bus")


	event_bus.subscribe(ActionEventTypes.DYNASTY_FEUD_STARTED, dynasty_legacy_engine, "record_conflict")
	event_bus.subscribe(ActionEventTypes.NPC_BETRAYED, dynasty_legacy_engine, "record_conflict")
	event_bus.subscribe(ActionEventTypes.ROMANCE_BETRAYAL, dynasty_legacy_engine, "record_conflict")


	event_bus.subscribe(ActionEventTypes.NPC_DIED, many_realms_engine, "handle_inheritance")
	event_bus.subscribe(ActionEventTypes.MANY_REALMS_RING_ACQUIRED, world_chronicle_engine, "record_from_bus")
	event_bus.subscribe(ActionEventTypes.MANY_REALMS_REALM_CREATED, world_chronicle_engine, "record_from_bus")
	event_bus.subscribe(ActionEventTypes.MANY_REALMS_SUCCESSION, world_chronicle_engine, "record_from_bus")
	event_bus.subscribe(ActionEventTypes.MANY_REALMS_REBELLION, world_chronicle_engine, "record_from_bus")
	event_bus.subscribe(ActionEventTypes.MANY_REALMS_HUNT, world_chronicle_engine, "record_from_bus")

	event_bus.subscribe(ActionEventTypes.MANY_REALMS_RING_ACQUIRED, historical_timeline_engine, "record_event")
	event_bus.subscribe(ActionEventTypes.MANY_REALMS_SUCCESSION, historical_timeline_engine, "record_event")
	event_bus.subscribe(ActionEventTypes.MANY_REALMS_REBELLION, historical_timeline_engine, "record_event")
	event_bus.subscribe(ActionEventTypes.MANY_REALMS_HUNT, historical_timeline_engine, "record_event")

	event_bus.subscribe(ActionEventTypes.MANY_REALMS_RING_ACQUIRED, npc_memory_web_engine, "record_memory")
	event_bus.subscribe(ActionEventTypes.MANY_REALMS_SUCCESSION, npc_memory_web_engine, "record_memory")
	event_bus.subscribe(ActionEventTypes.MANY_REALMS_REBELLION, npc_memory_web_engine, "record_memory")
	event_bus.subscribe(ActionEventTypes.MANY_REALMS_HUNT, npc_memory_web_engine, "record_memory")

	event_bus.subscribe(ActionEventTypes.MANY_REALMS_RING_ACQUIRED, agent_memory_propagation_engine, "capture_event")
	event_bus.subscribe(ActionEventTypes.MANY_REALMS_SUCCESSION, agent_memory_propagation_engine, "capture_event")
	event_bus.subscribe(ActionEventTypes.MANY_REALMS_REBELLION, agent_memory_propagation_engine, "capture_event")
	event_bus.subscribe(ActionEventTypes.MANY_REALMS_HUNT, agent_memory_propagation_engine, "capture_event")

	event_bus.subscribe(ActionEventTypes.MANY_REALMS_RING_ACQUIRED, fame_engine, "legendary_signal")
	event_bus.subscribe(ActionEventTypes.MANY_REALMS_HUNT, reputation_engine, "on_reputation_event")
	event_bus.subscribe(ActionEventTypes.MANY_REALMS_REBELLION, reputation_engine, "on_reputation_event")




	event_bus.subscribe(ActionEventTypes.BOXING_FIGHT_COMPLETED, boxing_contract_engine, "on_fight_completed")
	event_bus.subscribe(ActionEventTypes.BOXING_FIGHT_COMPLETED, boxing_ranking_engine, "on_fight_completed")
	event_bus.subscribe(ActionEventTypes.BOXING_FIGHT_COMPLETED, boxing_title_engine, "on_fight_completed")
	event_bus.subscribe(ActionEventTypes.BOXING_FIGHT_COMPLETED, fame_engine, "on_boxing_fight_completed")
	event_bus.subscribe(ActionEventTypes.BOXING_TITLE_WON, fame_engine, "on_boxing_title_won")
	event_bus.subscribe(ActionEventTypes.BOXING_INJURY, reputation_engine, "on_reputation_event")
	event_bus.subscribe(ActionEventTypes.BOXING_TITLE_WON, world_chronicle_engine, "record_from_bus")
	event_bus.subscribe(ActionEventTypes.BOXING_FIGHT_COMPLETED, world_chronicle_engine, "record_from_bus")
	event_bus.subscribe(ActionEventTypes.BOXING_TITLE_WON, historical_timeline_engine, "record_event")
	event_bus.subscribe(ActionEventTypes.BOXING_FIGHT_COMPLETED, historical_timeline_engine, "record_event")
	event_bus.subscribe(ActionEventTypes.BOXING_FIGHT_COMPLETED, npc_memory_web_engine, "record_memory")
	event_bus.subscribe(ActionEventTypes.BOXING_TITLE_WON, npc_memory_web_engine, "record_memory")
	event_bus.subscribe(ActionEventTypes.BOXING_FIGHT_COMPLETED, agent_memory_propagation_engine, "capture_event")
	event_bus.subscribe(ActionEventTypes.BOXING_TITLE_WON, agent_memory_propagation_engine, "capture_event")
	if competitive_reality_runtime != null:
		event_bus.subscribe(ActionEventTypes.YEAR_PASSED, competitive_reality_runtime, "yearly_tick")
		event_bus.subscribe(ActionEventTypes.BOXING_FIGHT_COMPLETED, competitive_reality_runtime, "on_boxing_fight_completed")
		event_bus.subscribe(ActionEventTypes.BOXING_TITLE_WON, competitive_reality_runtime, "on_boxing_title_won")
		event_bus.subscribe(ActionEventTypes.BOXING_MEDIA_NARRATIVE, competitive_reality_runtime, "on_media_signal")

	if reality_surge_engine != null:
		event_bus.subscribe(ActionEventTypes.YEAR_PASSED, reality_surge_engine, "yearly_tick")
		event_bus.subscribe("competitive.match.completed", reality_surge_engine, "on_competitive_match_completed", {
			"subscription_priority": 75,
			"force_immediate": true,
			"lane": "critical"
		})
	event_bus.subscribe(ActionEventTypes.ERA_SHIFT, geo_engine, "bootstrap_for_current_era")
	event_bus.subscribe(ActionEventTypes.NPC_BORN, geo_engine, "on_npc_born")
	event_bus.subscribe(ActionEventTypes.NPC_BORN, place_influence_engine, "on_npc_born")
	event_bus.subscribe(ActionEventTypes.NPC_MOVED, place_influence_engine, "on_npc_moved")
	event_bus.subscribe(ActionEventTypes.NPC_MOVED, settlement_presence_engine, "on_npc_moved")
	event_bus.subscribe(ActionEventTypes.BOXING_FIGHT_COMPLETED, boxing_rivalry_engine, "on_fight_completed")
	event_bus.subscribe(ActionEventTypes.BOXING_FIGHT_COMPLETED, boxing_media_engine, "on_fight_completed")
	event_bus.subscribe(ActionEventTypes.BOXING_FIGHT_COMPLETED, boxing_weight_engine, "on_fight_completed")
	event_bus.subscribe(ActionEventTypes.BOXING_FIGHT_COMPLETED, boxing_mandatory_engine, "on_fight_completed")
	event_bus.subscribe(ActionEventTypes.BOXING_FIGHT_COMPLETED, boxing_legacy_engine, "on_fight_completed")

	event_bus.subscribe(ActionEventTypes.BOXING_TITLE_WON, boxing_media_engine, "on_title_won")
	event_bus.subscribe(ActionEventTypes.BOXING_TITLE_WON, boxing_legacy_engine, "on_title_won")

	event_bus.subscribe(ActionEventTypes.BOXING_RIVALRY_STARTED, world_chronicle_engine, "record_from_bus")
	event_bus.subscribe(ActionEventTypes.BOXING_TRASH_TALKED, world_chronicle_engine, "record_from_bus")
	event_bus.subscribe(ActionEventTypes.BOXING_DUCKED_FIGHT, world_chronicle_engine, "record_from_bus")
	event_bus.subscribe(ActionEventTypes.BOXING_MEDIA_NARRATIVE, world_chronicle_engine, "record_from_bus")
	event_bus.subscribe(ActionEventTypes.BOXING_OLYMPIC_MEDAL, world_chronicle_engine, "record_from_bus")

	event_bus.subscribe(ActionEventTypes.BOXING_RIVALRY_STARTED, historical_timeline_engine, "record_event")
	event_bus.subscribe(ActionEventTypes.BOXING_TRASH_TALKED, historical_timeline_engine, "record_event")
	event_bus.subscribe(ActionEventTypes.BOXING_DUCKED_FIGHT, historical_timeline_engine, "record_event")
	event_bus.subscribe(ActionEventTypes.BOXING_MEDIA_NARRATIVE, historical_timeline_engine, "record_event")
	event_bus.subscribe(ActionEventTypes.BOXING_OLYMPIC_MEDAL, historical_timeline_engine, "record_event")

	event_bus.subscribe(ActionEventTypes.BOXING_RIVALRY_STARTED, npc_memory_web_engine, "record_memory")
	event_bus.subscribe(ActionEventTypes.BOXING_TRASH_TALKED, npc_memory_web_engine, "record_memory")
	event_bus.subscribe(ActionEventTypes.BOXING_DUCKED_FIGHT, npc_memory_web_engine, "record_memory")
	event_bus.subscribe(ActionEventTypes.BOXING_MEDIA_NARRATIVE, npc_memory_web_engine, "record_memory")
	event_bus.subscribe(ActionEventTypes.BOXING_OLYMPIC_MEDAL, npc_memory_web_engine, "record_memory")
	event_bus.subscribe(ActionEventTypes.BOXING_TITLE_WON, world_feed_engine, "handle_event_from_bus")
	event_bus.subscribe(ActionEventTypes.BOXING_RIVALRY_STARTED, world_feed_engine, "handle_event_from_bus")
	event_bus.subscribe(ActionEventTypes.BOXING_MEDIA_NARRATIVE, world_feed_engine, "handle_event_from_bus")
	event_bus.subscribe(ActionEventTypes.BOXING_OLYMPIC_MEDAL, world_feed_engine, "handle_event_from_bus")
	event_bus.subscribe(ActionEventTypes.BOXING_UPSET, world_feed_engine, "handle_event_from_bus")
	event_bus.subscribe(ActionEventTypes.BOXING_TRASH_TALKED, world_feed_engine, "handle_event_from_bus")
	event_bus.subscribe(ActionEventTypes.BOXING_DUCKED_FIGHT, world_feed_engine, "handle_event_from_bus")


	event_bus.subscribe(ActionEventTypes.VAMPIRE_TURNED, fame_engine, "legendary_signal")
	event_bus.subscribe(ActionEventTypes.VAMPIRE_EXPOSED, reputation_engine, "on_reputation_event")
	event_bus.subscribe(ActionEventTypes.VAMPIRE_HUNTER_ATTACK, reputation_engine, "on_reputation_event")
	event_bus.subscribe(ActionEventTypes.VAMPIRE_MASQUERADE_BREACH, reputation_engine, "on_reputation_event")
	event_bus.subscribe(ActionEventTypes.VAMPIRE_FRENZY, reputation_engine, "on_reputation_event")
	event_bus.subscribe(ActionEventTypes.VAMPIRE_TURNED, world_chronicle_engine, "record_from_bus")
	event_bus.subscribe(ActionEventTypes.VAMPIRE_FED, world_chronicle_engine, "record_from_bus")
	event_bus.subscribe(ActionEventTypes.VAMPIRE_EXPOSED, world_chronicle_engine, "record_from_bus")
	event_bus.subscribe(ActionEventTypes.VAMPIRE_COVEN_JOINED, world_chronicle_engine, "record_from_bus")
	event_bus.subscribe(ActionEventTypes.VAMPIRE_COVEN_FOUNDED, world_chronicle_engine, "record_from_bus")
	event_bus.subscribe(ActionEventTypes.VAMPIRE_HUNTER_ORDER_FOUNDED, world_chronicle_engine, "record_from_bus")
	event_bus.subscribe(ActionEventTypes.VAMPIRE_ELDER_AWAKENED, world_chronicle_engine, "record_from_bus")
	event_bus.subscribe(ActionEventTypes.VAMPIRE_CURED, world_chronicle_engine, "record_from_bus")

	event_bus.subscribe(ActionEventTypes.VAMPIRE_TURNED, historical_timeline_engine, "record_event")
	event_bus.subscribe(ActionEventTypes.VAMPIRE_FED, historical_timeline_engine, "record_event")
	event_bus.subscribe(ActionEventTypes.VAMPIRE_EXPOSED, historical_timeline_engine, "record_event")
	event_bus.subscribe(ActionEventTypes.VAMPIRE_COVEN_JOINED, historical_timeline_engine, "record_event")
	event_bus.subscribe(ActionEventTypes.VAMPIRE_COVEN_FOUNDED, historical_timeline_engine, "record_event")
	event_bus.subscribe(ActionEventTypes.VAMPIRE_HUNTER_ORDER_FOUNDED, historical_timeline_engine, "record_event")
	event_bus.subscribe(ActionEventTypes.VAMPIRE_ELDER_AWAKENED, historical_timeline_engine, "record_event")
	event_bus.subscribe(ActionEventTypes.VAMPIRE_CURED, historical_timeline_engine, "record_event")

	event_bus.subscribe(ActionEventTypes.VAMPIRE_TURNED, npc_memory_web_engine, "record_memory")
	event_bus.subscribe(ActionEventTypes.VAMPIRE_EXPOSED, npc_memory_web_engine, "record_memory")
	event_bus.subscribe(ActionEventTypes.VAMPIRE_MASQUERADE_BREACH, npc_memory_web_engine, "record_memory")
	event_bus.subscribe(ActionEventTypes.VAMPIRE_HUNTER_ATTACK, npc_memory_web_engine, "record_memory")
	event_bus.subscribe(ActionEventTypes.VAMPIRE_CURED, npc_memory_web_engine, "record_memory")

	event_bus.subscribe(ActionEventTypes.VAMPIRE_TURNED, agent_memory_propagation_engine, "capture_event")
	event_bus.subscribe(ActionEventTypes.VAMPIRE_EXPOSED, agent_memory_propagation_engine, "capture_event")
	event_bus.subscribe(ActionEventTypes.VAMPIRE_MASQUERADE_BREACH, agent_memory_propagation_engine, "capture_event")
	event_bus.subscribe(ActionEventTypes.VAMPIRE_HUNTER_ATTACK, agent_memory_propagation_engine, "capture_event")
	event_bus.subscribe(ActionEventTypes.VAMPIRE_CURED, agent_memory_propagation_engine, "capture_event")

	event_bus.subscribe(ActionEventTypes.VAMPIRE_EXPOSED, world_feed_engine, "handle_event_from_bus")
	event_bus.subscribe(ActionEventTypes.VAMPIRE_COVEN_JOINED, world_feed_engine, "handle_event_from_bus")
	event_bus.subscribe(ActionEventTypes.VAMPIRE_COVEN_FOUNDED, world_feed_engine, "handle_event_from_bus")
	event_bus.subscribe(ActionEventTypes.VAMPIRE_HUNTER_ORDER_FOUNDED, world_feed_engine, "handle_event_from_bus")
	event_bus.subscribe(ActionEventTypes.VAMPIRE_ELDER_AWAKENED, world_feed_engine, "handle_event_from_bus")
	event_bus.subscribe(ActionEventTypes.VAMPIRE_DAYWALKER_AWAKENED, world_feed_engine, "handle_event_from_bus")
	event_bus.subscribe(ActionEventTypes.VAMPIRE_CURED, world_feed_engine, "handle_event_from_bus")



	event_bus.subscribe(ActionEventTypes.PLAYER_DIED, legacy_echo_engine, "capture_player_life_echo")
	event_bus.subscribe(ActionEventTypes.YEAR_PASSED, legacy_echo_engine, "yearly_echo_evaluation")



	event_bus.subscribe(ActionEventTypes.JOB_HIRED, world_feed_engine, "handle_event_from_bus")
	event_bus.subscribe(ActionEventTypes.JOB_PROMOTED, world_feed_engine, "handle_event_from_bus")
	event_bus.subscribe(ActionEventTypes.JOB_FIRED, world_feed_engine, "handle_event_from_bus")
	event_bus.subscribe(ActionEventTypes.JOB_RAISE_GRANTED, world_feed_engine, "handle_event_from_bus")

	event_bus.subscribe(ActionEventTypes.JOB_HIRED, world_chronicle_engine, "record_from_bus")
	event_bus.subscribe(ActionEventTypes.JOB_PROMOTED, world_chronicle_engine, "record_from_bus")
	event_bus.subscribe(ActionEventTypes.JOB_FIRED, world_chronicle_engine, "record_from_bus")
	event_bus.subscribe(ActionEventTypes.JOB_RAISE_GRANTED, world_chronicle_engine, "record_from_bus")

	event_bus.subscribe(ActionEventTypes.JOB_HIRED, historical_timeline_engine, "record_event")
	event_bus.subscribe(ActionEventTypes.JOB_PROMOTED, historical_timeline_engine, "record_event")
	event_bus.subscribe(ActionEventTypes.JOB_FIRED, historical_timeline_engine, "record_event")
	event_bus.subscribe(ActionEventTypes.JOB_RAISE_GRANTED, historical_timeline_engine, "record_event")
	event_bus.subscribe(ActionEventTypes.BOXING_TITLE_WON, llm_bridge, "on_event")
	event_bus.subscribe(ActionEventTypes.BOXING_FIGHT_COMPLETED, llm_bridge, "on_event")
	event_bus.subscribe(ActionEventTypes.BOXING_RIVALRY_STARTED, llm_bridge, "on_event")
	event_bus.subscribe(ActionEventTypes.NPC_DIED, llm_bridge, "on_event")
	event_bus.subscribe(ActionEventTypes.WISH_MADE, llm_bridge, "on_event")
	event_bus.subscribe(ActionEventTypes.FAME_SPIKE, llm_bridge, "on_event")
	event_bus.subscribe(ActionEventTypes.ERA_SHIFT, llm_bridge, "on_event")
	event_bus.subscribe(ActionEventTypes.VAMPIRE_TURNED, llm_bridge, "on_event")
	event_bus.subscribe(ActionEventTypes.MANY_REALMS_SUCCESSION, llm_bridge, "on_event")



	event_bus.subscribe(ActionEventTypes.FACTION_CREATED, world_feed_engine, "handle_event_from_bus")
	event_bus.subscribe(ActionEventTypes.FACTION_SPLIT, world_feed_engine, "handle_event_from_bus")
	event_bus.subscribe(ActionEventTypes.FACTION_MERGED, world_feed_engine, "handle_event_from_bus")
	event_bus.subscribe(ActionEventTypes.FACTION_PRESSURE_SPIKE, world_feed_engine, "handle_event_from_bus")
	event_bus.subscribe(ActionEventTypes.FACTION_RECRUITED_MEMBER, world_feed_engine, "handle_event_from_bus")
	event_bus.subscribe(ActionEventTypes.FACTION_LOST_MEMBER, world_feed_engine, "handle_event_from_bus")
	event_bus.subscribe(ActionEventTypes.FACTION_LOST_TERRITORY, world_feed_engine, "handle_event_from_bus")
	event_bus.subscribe(ActionEventTypes.FACTION_DECLINED, world_feed_engine, "handle_event_from_bus")
	event_bus.subscribe(ActionEventTypes.FACTION_PEAKED, world_feed_engine, "handle_event_from_bus")
	event_bus.subscribe(ActionEventTypes.FACTION_COUP, world_feed_engine, "handle_event_from_bus")
	event_bus.subscribe(ActionEventTypes.FACTION_FEUD_STARTED, world_feed_engine, "handle_event_from_bus")

	event_bus.subscribe(ActionEventTypes.FACTION_CREATED, world_chronicle_engine, "record_from_bus")
	event_bus.subscribe(ActionEventTypes.FACTION_SPLIT, world_chronicle_engine, "record_from_bus")
	event_bus.subscribe(ActionEventTypes.FACTION_MERGED, world_chronicle_engine, "record_from_bus")
	event_bus.subscribe(ActionEventTypes.FACTION_PRESSURE_SPIKE, world_chronicle_engine, "record_from_bus")
	event_bus.subscribe(ActionEventTypes.FACTION_RECRUITED_MEMBER, world_chronicle_engine, "record_from_bus")
	event_bus.subscribe(ActionEventTypes.FACTION_LOST_MEMBER, world_chronicle_engine, "record_from_bus")
	event_bus.subscribe(ActionEventTypes.FACTION_LOST_TERRITORY, world_chronicle_engine, "record_from_bus")
	event_bus.subscribe(ActionEventTypes.FACTION_DECLINED, world_chronicle_engine, "record_from_bus")
	event_bus.subscribe(ActionEventTypes.FACTION_PEAKED, world_chronicle_engine, "record_from_bus")
	event_bus.subscribe(ActionEventTypes.FACTION_COUP, world_chronicle_engine, "record_from_bus")
	event_bus.subscribe(ActionEventTypes.FACTION_FEUD_STARTED, world_chronicle_engine, "record_from_bus")

	event_bus.subscribe(ActionEventTypes.FACTION_CREATED, historical_timeline_engine, "record_event")
	event_bus.subscribe(ActionEventTypes.FACTION_SPLIT, historical_timeline_engine, "record_event")
	event_bus.subscribe(ActionEventTypes.FACTION_MERGED, historical_timeline_engine, "record_event")
	event_bus.subscribe(ActionEventTypes.FACTION_PRESSURE_SPIKE, historical_timeline_engine, "record_event")
	event_bus.subscribe(ActionEventTypes.FACTION_RECRUITED_MEMBER, historical_timeline_engine, "record_event")
	event_bus.subscribe(ActionEventTypes.FACTION_LOST_MEMBER, historical_timeline_engine, "record_event")
	event_bus.subscribe(ActionEventTypes.FACTION_LOST_TERRITORY, historical_timeline_engine, "record_event")
	event_bus.subscribe(ActionEventTypes.FACTION_DECLINED, historical_timeline_engine, "record_event")
	event_bus.subscribe(ActionEventTypes.FACTION_PEAKED, historical_timeline_engine, "record_event")
	event_bus.subscribe(ActionEventTypes.FACTION_COUP, historical_timeline_engine, "record_event")
	event_bus.subscribe(ActionEventTypes.FACTION_FEUD_STARTED, historical_timeline_engine, "record_event")

	event_bus.subscribe(ActionEventTypes.FACTION_CREATED, npc_memory_web_engine, "record_memory")
	event_bus.subscribe(ActionEventTypes.FACTION_SPLIT, npc_memory_web_engine, "record_memory")
	event_bus.subscribe(ActionEventTypes.FACTION_MERGED, npc_memory_web_engine, "record_memory")
	event_bus.subscribe(ActionEventTypes.FACTION_PRESSURE_SPIKE, npc_memory_web_engine, "record_memory")
	event_bus.subscribe(ActionEventTypes.FACTION_RECRUITED_MEMBER, npc_memory_web_engine, "record_memory")
	event_bus.subscribe(ActionEventTypes.FACTION_LOST_MEMBER, npc_memory_web_engine, "record_memory")
	event_bus.subscribe(ActionEventTypes.FACTION_LOST_TERRITORY, npc_memory_web_engine, "record_memory")
	event_bus.subscribe(ActionEventTypes.FACTION_DECLINED, npc_memory_web_engine, "record_memory")
	event_bus.subscribe(ActionEventTypes.FACTION_PEAKED, npc_memory_web_engine, "record_memory")
	event_bus.subscribe(ActionEventTypes.FACTION_COUP, npc_memory_web_engine, "record_memory")
	event_bus.subscribe(ActionEventTypes.FACTION_FEUD_STARTED, npc_memory_web_engine, "record_memory")

	event_bus.subscribe(ActionEventTypes.FACTION_CREATED, agent_memory_propagation_engine, "capture_event")
	event_bus.subscribe(ActionEventTypes.FACTION_SPLIT, agent_memory_propagation_engine, "capture_event")
	event_bus.subscribe(ActionEventTypes.FACTION_MERGED, agent_memory_propagation_engine, "capture_event")
	event_bus.subscribe(ActionEventTypes.FACTION_PRESSURE_SPIKE, agent_memory_propagation_engine, "capture_event")
	event_bus.subscribe(ActionEventTypes.FACTION_RECRUITED_MEMBER, agent_memory_propagation_engine, "capture_event")
	event_bus.subscribe(ActionEventTypes.FACTION_LOST_MEMBER, agent_memory_propagation_engine, "capture_event")
	event_bus.subscribe(ActionEventTypes.FACTION_LOST_TERRITORY, agent_memory_propagation_engine, "capture_event")
	event_bus.subscribe(ActionEventTypes.FACTION_DECLINED, agent_memory_propagation_engine, "capture_event")
	event_bus.subscribe(ActionEventTypes.FACTION_PEAKED, agent_memory_propagation_engine, "capture_event")
	event_bus.subscribe(ActionEventTypes.FACTION_COUP, agent_memory_propagation_engine, "capture_event")
	event_bus.subscribe(ActionEventTypes.FACTION_FEUD_STARTED, agent_memory_propagation_engine, "capture_event")

	event_bus.subscribe(ActionEventTypes.FACTION_CREATED, reputation_engine, "on_reputation_event")
	event_bus.subscribe(ActionEventTypes.FACTION_PRESSURE_SPIKE, reputation_engine, "on_reputation_event")
	event_bus.subscribe(ActionEventTypes.FACTION_COUP, reputation_engine, "on_reputation_event")
	event_bus.subscribe(ActionEventTypes.FACTION_FEUD_STARTED, reputation_engine, "on_reputation_event")

	event_bus.subscribe(ActionEventTypes.FACTION_CREATED, llm_bridge, "on_event")
	event_bus.subscribe(ActionEventTypes.FACTION_SPLIT, llm_bridge, "on_event")
	event_bus.subscribe(ActionEventTypes.FACTION_MERGED, llm_bridge, "on_event")
	event_bus.subscribe(ActionEventTypes.FACTION_PRESSURE_SPIKE, llm_bridge, "on_event")
	event_bus.subscribe(ActionEventTypes.FACTION_RECRUITED_MEMBER, llm_bridge, "on_event")
	event_bus.subscribe(ActionEventTypes.FACTION_LOST_MEMBER, llm_bridge, "on_event")
	event_bus.subscribe(ActionEventTypes.FACTION_LOST_TERRITORY, llm_bridge, "on_event")
	event_bus.subscribe(ActionEventTypes.FACTION_DECLINED, llm_bridge, "on_event")
	event_bus.subscribe(ActionEventTypes.FACTION_PEAKED, llm_bridge, "on_event")
	event_bus.subscribe(ActionEventTypes.FACTION_COUP, llm_bridge, "on_event")
	event_bus.subscribe(ActionEventTypes.FACTION_FEUD_STARTED, llm_bridge, "on_event")
	if game_state_contract_engine != null:
		var event_bus_contract_runtime_report: Dictionary = game_state_contract_engine.apply_event_bus_contracts(event_bus)
		scenario_state ["event_bus_contract_layer_report"] = event_bus_contract_runtime_report.duplicate(true)

		var contract_subscription_report: Dictionary = game_state_contract_engine.apply_event_subscriptions(event_bus)
		scenario_state ["game_state_contract_event_subscription_report"] = contract_subscription_report.duplicate(true)

	if custom_settings.has("year_locked"):
		year_locked = custom_settings ["year_locked"]

	if custom_mode and custom_settings.has("year"):
		year = int(custom_settings ["year"])

	if custom_mode and custom_settings.has("era") and era_engine.eras.has(custom_settings ["era"]):
		era = era_engine.eras [custom_settings ["era"]]

		if not custom_settings.has("year"):
			var e = era_engine.eras [custom_settings ["era"]]
			year = int((e ["start_year"] + e ["end_year"]) / 2)
	elif custom_mode and custom_settings.has("year"):
		era = era_engine._era_from_year(year)
	else:
		era = era_engine._era_from_year(year)

	realm_engine.bootstrap_realms_for_era()

	for i in range(50):
		var npc = npc_factory.create_random_npc(true)
		apply_reality_rules_to_person(npc)
		npcs.append(npc)

	if custom_mode:
		player = character_creator.create_custom_player(custom_settings)
	else:
		player = npc_factory.create_player()
	apply_reality_rules_to_person(player)

	if wizard_engine != null and wizard_engine.has_method("apply_birth_settings"):
		wizard_engine.apply_birth_settings(player, custom_settings)
	if power_engine != null and power_engine.has_method("apply_birth_settings"):
		power_engine.apply_birth_settings(player, custom_settings)
	if superhero_engine != null and superhero_engine.has_method("apply_birth_settings"):
		superhero_engine.apply_birth_settings(player, custom_settings)
	player_id = player.id
	npcs.append(player)
	_apply_custom_household_spawn_contract(player)
	_apply_presidential_parent_contract_if_requested(player)
	if bank_engine != null and bank_engine.has_method("repair_legacy_player_money_mirror"):
		bank_engine.repair_legacy_player_money_mirror()
	if npc_factory != null:
		npc_factory.seed_spawn_world_assets(npcs)
	if bending_engine != null and bending_engine.has_method("bootstrap_spawn_bending_population"):
		bending_engine.bootstrap_spawn_bending_population(npcs)
	if power_engine != null and power_engine.has_method("bootstrap_spawn_power_population"):
		power_engine.bootstrap_spawn_power_population(npcs)
	if superhero_engine != null and superhero_engine.has_method("bootstrap_world_supers"):
		superhero_engine.bootstrap_world_supers(npcs)
	if realm_engine != null and realm_engine.has_method("audit_bootstrap_elemental_realm_population"):
		realm_engine.audit_bootstrap_elemental_realm_population()
	for npc in npcs:
		world_space_engine.place_npc(npc)
	for npc in npcs:
		chunk_simulation_engine.assign_npc(npc)
	if player_id == 0:
		player_id = player.id
	if has_method("register_controlled_character"):
		register_controlled_character(player.id)

	dynasty_engine.register_dynasty(player.last_name)

	_apply_player_starting_artifact_loadout()

	if is_feature_enabled("artifacts"):
		artifacts_engine.spawn_initial_artifacts()

	dynasty_engine.register_dynasty(player.last_name)

	for pid in player.parents:
		var par = get_npc_by_id(pid)
		if par != null:
			dynasty_engine.register_dynasty(par.last_name)
	if global_market_engine != null:
		global_market_engine._ensure_bootstrapped()

	if soul_seed_engine != null:
		soul_seed_engine.assign_world_soul_seeds(npcs, custom_settings, {
			"source": "full_world_spawn",
			"world_seed": custom_settings.get("world_seed", scenario_state.get("world_seed", -1)) if typeof(custom_settings) == TYPE_DICTIONARY and typeof(scenario_state) == TYPE_DICTIONARY else -1,
			"seed_contract": custom_settings.get("seed_contract", {}) if typeof(custom_settings) == TYPE_DICTIONARY else {},
			"soul_seed_contract": custom_settings.get("soul_seed_contract", {}) if typeof(custom_settings) == TYPE_DICTIONARY else {},
			"player_id": player.id if player != null else player_id
		})

	for npc in npcs:
		if npc == null:
			continue
		if consciousness_engine != null:
			consciousness_engine.ensure_consciousness(npc, {
				"source": "birth_shell_first_life_spawn"
			})
	_rebuild_npc_index()

	if food_engine != null and food_engine.has_method("seed_initial_hunger_for_population"):
		food_engine.seed_initial_hunger_for_population(npcs, {
			"source": "full_world_spawn_initial_hunger",
			"force": false
		})

	if relationship_engine != null and relationship_engine.has_method("seed_family_and_stranger_bonds_for_actor") and player != null:
		relationship_engine.seed_family_and_stranger_bonds_for_actor(player, {
			"source": "full_world_spawn_relationship_baseline"
		})

	_soft_unload_npcs()
func _initialize_birth_shell_first_life() -> void:
	_hydrate_reality_settings()

	if typeof(scenario_state) != TYPE_DICTIONARY:
		scenario_state = {}

	scenario_state ["birth_shell_first_boot"] = false
	scenario_state ["birth_shell_first_boot_active"] = true
	scenario_state ["birth_shell_deferred_boot_pending"] = true
	scenario_state ["birth_shell_deferred_boot_complete"] = false
	scenario_state ["defer_static_world_bootstrap"] = true
	scenario_state ["defer_live_runtime_watchers"] = true
	scenario_state ["deferred_data_bootstrap_pending"] = true
	scenario_state ["deferred_runtime_watchers_bootstrap"] = true
	scenario_state ["static_world_runtime_bootstrapped"] = false
	scenario_state ["post_spawn_ui_finalize_pending"] = true

	if game_state_contract_engine == null:
		game_state_contract_engine = GameStateContractEngine.new(self)
	contract_meta_governor = game_state_contract_engine.contract_meta_governor

	event_bus = EventBus.new(self)
	event_bus_contract_layer = event_bus.contract_layer

	world_space_engine = WorldSpaceEngine.new(self)
	spatial_culling_engine = SpatialCullingEngine.new(self)
	emergent_story_engine = EmergentNPCStoryEngine.new(self)
	economy_engine = EconomyEngine.new(self)
	bank_engine = BankEngine.new(self)
	historical_timeline_engine = HistoricalTimelineEngine.new(self)
	global_market_engine = GlobalMarketEngine.new(self)
	ecs_engine = ECSEngine.new(self)
	chunk_simulation_engine = ChunkSimulationEngine.new(self)
	population_shard_engine = PopulationShardEngine.new(self)
	population_lifecycle_manager = PopulationLifecycleManager.new(self)

	geo_engine = GeoEngine.new(self)
	settlement_presence_engine = SettlementPresenceEngine.new(self)
	migration_engine = MigrationEngine.new(self)
	place_influence_engine = PlaceInfluenceEngine.new(self)
	seed_engine = SeedEngine.new(self)

	var seed_contract_raw: Variant = scenario_state.get("seed_contract", {})
	if typeof(seed_contract_raw) != TYPE_DICTIONARY and typeof(custom_settings) == TYPE_DICTIONARY:
		seed_contract_raw = custom_settings.get("seed_contract", {})

	var requested_seed: int = -1
	if typeof(seed_contract_raw) == TYPE_DICTIONARY:
		requested_seed = int((seed_contract_raw as Dictionary).get("seed", -1))

	if requested_seed <= 0:
		requested_seed = int(scenario_state.get("world_seed", -1))
	if requested_seed <= 0 and typeof(custom_settings) == TYPE_DICTIONARY:
		requested_seed = int(custom_settings.get("world_seed", -1))

	if requested_seed > 0:
		seed_engine.initialize({ "seed": requested_seed})
		scenario_state ["seed_bootstrap_deferred"] = false
	else:
		scenario_state ["seed_bootstrap_deferred"] = true
		scenario_state ["seed_bootstrap_reason"] = "waiting_for_god_mode_seed_commit"
	soul_seed_engine = SoulSeedEngine.new(self)
	consciousness_engine = ConsciousnessEngine.new(self)
	willpower_engine = WillpowerEngine.new(self)
	social_graph_engine = SocialGraphEngine.new(self)
	workplace_engine = WorkplaceEngine.new(self)
	player_action_engine = PlayerActionEngine.new(self)
	npc_memory_web_engine = NPCMemoryWebEngine.new(self)
	agent_memory_propagation_engine = AgentMemoryPropagationEngine.new(self)
	dynamic_world_event_engine = DynamicWorldEventEngine.new(self)
	action_discovery_engine = ActionDiscoveryEngine.new(self)

	names_db = NamesDB.new(self)
	npc_factory = NPCFactory.new(self)
	character_creator = CharacterCreator.new(self)

	legacy_memory_engine = LegacyMemoryEngine.new(self)
	legacy_echo_engine = LegacyEchoEngine.new(self)
	afterlife_influence_engine = AfterlifeInfluenceEngine.new(self)

	scenario_resolver = ScenarioResolver.new(self)
	scenario_engine = ScenarioEngine.new(self)
	scenario_popup_contract_engine = ScenarioPopupContractEngine.new(self)
	scenario_runtime_contract_engine = ScenarioRuntimeContractEngine.new(self)
	pending_situations_engine = PendingSituationsEngine.new(self)
	contract_view_layer_contract_engine = ContractViewLayerContractEngine.new(self)
	traits_contract_engine = TraitsContractEngine.new(self)
	identity_contract_engine = IdentityContractEngine.new(self)
	red_bonnet_engine = RedBonnetEngine.new(self)
	world_engine = WorldEngine.new(self)
	event_engine = EventEngine.new(self)
	personality_engine = PersonalityEngine.new(self)
	relationship_engine = RelationshipEngine.new(self)
	memory_engine = MemoryEngine.new(self)
	health_engine = HealthEngine.new(self)
	genetics_inheritance_engine = GeneticsInheritanceEngine.new(self)
	body_type_contract_engine = BodyTypeContractEngine.new(self)
	growth_curve_engine = GrowthCurveEngine.new(self)
	height_contract_engine = HeightContractEngine.new(self)
	weight_contract_engine = WeightContractEngine.new(self)
	human_contract_engine = HumanContractEngine.new(self)
	animal_contract_engine = AnimalContractEngine.new(self)
	mythical_contract_engine = MythicalContractEngine.new(self)
	relationship_graph_contract_engine = RelationshipGraphContractEngine.new(self)
	human_relationship_contract_engine = HumanRelationshipContractEngine.new(self)
	pets_contract_engine = PetsContractEngine.new(self)
	mythical_pets_contract_engine = MythicalPetsContractEngine.new(self)
	pet_shop_contract_engine = PetShopContractEngine.new(self)
	breeding_contract_engine = BreedingContractEngine.new(self)
	debt_contract_engine = DebtContractEngine.new(self)
	meat_market_contract_engine = MeatMarketContractEngine.new(self)



	career_runtime_engine = CareerRuntimeEngine.new(self)
	career_contract_engine = CareerContractEngine.new(self)
	career_space_contract_engine = CareerSpaceContractEngine.new(self)
	career_hub_contract_engine = CareerHubContractEngine.new(self)
	career_engine = CareerEngine.new(self)



	activities_contract_engine = ActivitiesContractEngine.new(self)
	activities_hub_contract_engine = ActivitiesHubContractEngine.new(self)



	mod_contract_engine = ModContractEngine.new(self)



	caveman_reality_runtime_engine = (
		CavemanRealityRuntimeEngine.new(self)
	)



	mod_bundle_contract_engine = (
		ModBundleContractEngine.new(self)
	)

	mod_marketplace_contract_engine = (
		ModMarketplaceContractEngine.new(self)
	)
	mod_hub_contract_engine = ModHubContractEngine.new(self)
	mod_menu_contract_engine = ModMenuContractEngine.new(self)

	if caveman_reality_runtime_engine != null:
		caveman_reality_runtime_engine.bootstrap_default_contracts()

	if mod_bundle_contract_engine != null:
		mod_bundle_contract_engine.bootstrap_default_contracts()

	school_engine = SchoolEngine.new(
		self
	)
	school_hub_contract_engine = SchoolHubContractEngine.new(
		self
	)

	family_contract_engine = FamilyContractEngine.new(
		self
	)
	family_control_engine = FamilyControlEngine.new(
		self
	)
	global_intent_contract_engine = GlobalIntentContractEngine.new(
		self
	)
	universal_switch_contract_engine = (
		UniversalSwitchContractEngine.new(
			self
		)
	)
	relationships_hub_contract_engine = (
		RelationshipsHubContractEngine.new(
			self,
			universal_switch_contract_engine
		)
	)
	crr_contract_engine = CRRContractEngine.new(
		self
	)
	opportunity_engine = OpportunityEngine.new(self)
	fate_engine = FateEngine.new(self)
	life_engine = LifeEngine.new(self)
	life_diary_contract_engine = LifeDiaryContractEngine.new(self)
	narrative_engine = NarrativeEngine.new(self)
	llm_bridge = LLMNarrativeBridge.new(self)

	bending_engine = BendingEngine.new(self)
	bending_tournament_engine = BendingTournamentEngine.new(self)
	avatar_influence_engine = AvatarInfluenceEngine.new(self)
	bending_dojo_engine = BendingDojoEngine.new(self)
	wizard_engine = WizardEngine.new(self)
	power_engine = PowerEngine.new(self)
	superhero_engine = SuperHeroEngine.new(self)
	infamy_engine = InfamyEngine.new(self)
	dynasty_engine = DynastyEngine.new(self)


	era_engine = EraEngine.new(self)



	era_mod_contract_engine = EraModContractEngine.new(self)
	era_contract_engine = EraContractEngine.new(self)

	if era_mod_contract_engine != null:
		era_mod_contract_engine.bootstrap_default_contracts()

	if era_contract_engine != null:
		era_contract_engine.bootstrap_default_contracts()

	world_feed_engine = WorldFeedEngine.new(self)
	world_chronicle_engine = WorldChronicleEngine.new(self)
	reputation_engine = ReputationEngine.new(self)
	artifacts_engine = ArtifactsEngine.new(
		self
	)
	artifacts_catalog_contract_engine = (
		ArtifactsCatalogContractEngine.new(
			self
		)
	)
	artifact_interaction_contract_engine = (
		ArtifactInteractionContractEngine.new(
			self
		)
	)
	artifact_shop_contract_engine = (
		ArtifactShopContractEngine.new(
			self
		)
	)

	realm_contract_engine = RealmContractEngine.new(
		self
	)
	simulation_contract_engine = SimulationContractEngine.new(self)
	runtime_contract_engine = RuntimeContractEngine.new(self)
	romance_contract_engine = RomanceContractEngine.new(self)
	ui_contract_engine = UIContractEngine.new(self)
	embedded_ui_contract_engine = EmbeddedUIContractEngine.new(self)
	birth_contract_engine = BirthContractEngine.new(self)
	many_realms_engine = ManyRealmsEngine.new(self)
	bridge_to_terabithia_engine = BridgeToTerabithiaEngine.new(self)
	vormir_engine = VormirEngine.new(self)
	nidavellir_engine = NidavellirEngine.new(self)
	dragonballs_engine = DragonBallsEngine.new(self)

	dynasty_legacy_engine = DynastyLegacyEngine.new(self)
	weapons_engine = WeaponsEngine.new(self)
	weapons_catalog_expansion = WeaponsCatalogExpansion.new(
		self
	)
	crime_contract_engine = CrimeContractEngine.new(self)
	investigation_layer = InvestigationLayer.new(self)
	justice_system_engine = JusticeSystemEngine.new(self)
	jail_engine = JailEngine.new(self)
	prison_engine = PrisonEngine.new(self)
	case_orchestrator = CaseOrchestrator.new(self)
	crime_engine = CrimeEngine.new(self)
	crime_hub_contract_engine = CrimeHubContractEngine.new(
		self
	)
	relationship_activities_engine = RelationshipActivitiesEngine.new(self)
	realm_engine = RealmEngine.new(self)
	class_engine = ClassEngine.new(self)
	fame_engine = FameEngine.new(self)
	upce_engine = UniversalPerceptionConsequenceEngine.new(self)
	if upce_engine != null:
		upce_engine.bootstrap_default_contracts()
	royalty_engine = RoyaltyEngine.new(self)
	royalty_runtime_engine = RoyaltyRuntimeEngine.new(self)
	royalty_mod_contract_engine = RoyaltyModContractEngine.new(self)
	royalty_contract_engine = RoyaltyContractEngine.new(self)
	crown_hub_contract_engine = CrownHubContractEngine.new(self)

	if royalty_mod_contract_engine != null:
		royalty_mod_contract_engine.bootstrap_default_contracts()

	if royalty_contract_engine != null:
		royalty_contract_engine.bootstrap_default_contracts()

	if royalty_runtime_engine != null:
		royalty_runtime_engine.bootstrap_default_contracts()

	if crown_hub_contract_engine != null:
		crown_hub_contract_engine.bootstrap_default_contracts()

	politics_engine = PoliticsEngine.new(self)
	property_engine = PropertyEngine.new(self)
	era_life_asset_catalog_expansion = EraLifeAssetCatalogExpansion.new(self)
	assets_contract_engine = AssetsContractEngine.new(self)
	property_amenity_synthesis_contract_engine = PropertyAmenitySynthesisContractEngine.new(self)
	room_graph_contract_engine = RoomGraphContractEngine.new(self)
	presence_engine = PresenceEngine.new(self)
	property_makeover_contract_engine = PropertyMakeoverContractEngine.new(self)
	vehicle_engine = VehicleEngine.new(self)
	card_contract_engine = CardContractEngine.new(self)
	property_market_contract_engine = PropertyMarketContractEngine.new(self)
	spatial_traversal_contract_engine = SpatialTraversalContractEngine.new(self)
	dealership_contract_engine = DealershipContractEngine.new(self)
	shared_public_space_engine = SharedPublicSpaceEngine.new(self)
	food_engine = FoodEngine.new(self)
	food_restaurant_engine = FoodRestaurantEngine.new(self)
	grocery_store_engine = GroceryStoreEngine.new(self)
	movie_theater_engine = MovieTheaterEngine.new(self)
	if movie_theater_engine != null and movie_theater_engine.has_method("bootstrap_ui_contracts"):
		movie_theater_engine.bootstrap_ui_contracts()
	luxury_shop_engine = LuxuryShopEngine.new(self)

	heirloom_runtime_engine = HeirloomRuntimeEngine.new(
		self
	)
	heirloom_contract_engine = HeirloomContractEngine.new(
		self
	)
	heirloom_engine = HeirloomEngine.new(
		self
	)
	heirloom_catalog_contract_engine = (
		HeirloomCatalogContractEngine.new(
			self
		)
	)
	heirloom_hub_contract_engine = HeirloomHubContractEngine.new(
		self
	)

	island_realm_engine = IslandRealmExpansionEngine.new(
		self
	)
	population_movement_contract_engine = PopulationMovementContractEngine.new(self)
	global_prewarm_contract_engine = GlobalPrewarmContractEngine.new(self)
	global_node_contract_engine = GlobalNodeContractEngine.new(self)
	truth_resolution_contract_engine = TruthResolutionContractEngine.new(self)
	observable_node_contract_engine = ObservableNodeContractEngine.new(self)
	world_observability_contract_engine = WorldObservabilityContractEngine.new(self)
	population_movement_contract_engine = PopulationMovementContractEngine.new(self)
	crown_population_view_contract = CrownPopulationViewContract.new(self)
	population_card_contract_engine = PopulationCardContractEngine.new(self)
	belongings_engine = BelongingsEngine.new(
		self
	)

	_resident_bootstrap_heirloom_contracts()

	global_object_catalog_system = GlobalObjectCatalogSystem.new(
		self
	)
	object_hub_contract_engine = ObjectHubContractEngine.new(
		self
	)

	_resident_bootstrap_global_object_catalog()
	_resident_bootstrap_object_projection_contracts()

	desire_engine = DesireEngine.new(
		self
	)
	capability_graph_engine = CapabilityGraphEngine.new(self)
	goal_planning_engine = GoalPlanningEngine.new(self)
	simulation_director = SimulationDirector.new(self)
	year_budget_engine = YearBudgetEngine.new(self)
	desire_behavior_bridge = DesireBehaviorBridge.new(self)
	ai_event_engine = AIEventGenerator.new(self)
	if era_data_loader == null:
		era_data_loader = EraDataLoader.new(self)
	if weapon_pack_loader == null:
		weapon_pack_loader = WeaponPackLoader.new(self)
	if mod_loader == null:
		mod_loader = ModLoader.new(self)

	boxing_contract_engine = BoxingContractEngine.new(self)
	boxing_fighter_engine = BoxingFighterEngine.new(self)
	boxing_training_engine = BoxingTrainingEngine.new(self)
	boxing_matchmaking_engine = BoxingMatchmakingEngine.new(self)
	boxing_fight_sim_engine = BoxingFightSimEngine.new(self)
	boxing_ranking_engine = BoxingRankingEngine.new(self)
	boxing_title_engine = BoxingTitleEngine.new(self)
	boxing_injury_engine = BoxingInjuryEngine.new(self)
	boxing_engine = BoxingEngine.new(self)
	boxing_round_log_engine = BoxingRoundLogEngine.new(self)
	boxing_rivalry_engine = BoxingRivalryEngine.new(self)
	boxing_promotion_engine = BoxingPromotionEngine.new(self)
	boxing_weight_engine = BoxingWeightEngine.new(self)
	boxing_mandatory_engine = BoxingMandatoryEngine.new(self)
	boxing_amateur_engine = BoxingAmateurEngine.new(self)
	boxing_media_engine = BoxingMediaEngine.new(self)
	boxing_gym_engine = BoxingGymEngine.new(self)
	boxing_legacy_engine = BoxingLegacyEngine.new(self)
	if boxing_contract_engine != null:
		boxing_contract_engine.set_contract()
	competitive_reality_runtime = CompetitiveRealityRuntime.new(self)
	if competitive_reality_runtime != null:
		competitive_reality_runtime.bootstrap_default_contracts()
	reality_surge_engine = RealitySurgeEngine.new(self)
	if reality_surge_engine != null:
		reality_surge_engine.bootstrap_default_contracts()
	reality_orchestrator = RealityOrchestrator.new(self)
	if reality_orchestrator != null:
		reality_orchestrator.bootstrap_default_contracts()
	vampire_origin_engine = VampireOriginEngine.new(self)
	vampire_hunger_engine = VampireHungerEngine.new(self)
	vampire_ability_engine = VampireAbilityEngine.new(self)
	vampire_society_engine = VampireSocietyEngine.new(self)
	vampire_hunter_engine = VampireHunterEngine.new(self)
	vampire_legacy_engine = VampireLegacyEngine.new(self)
	vampire_masquerade_engine = VampireMasqueradeEngine.new(self)
	vampire_cure_engine = VampireCureEngine.new(self)
	vampire_engine = VampireEngine.new(self)
	universal_faction_engine = UniversalFactionEngine.new(self)
	runtime_health_registry = RuntimeHealthRegistry.new(self)
	runtime_fault_router = RuntimeFaultRouter.new(self)
	patch_suggestion_engine = PatchSuggestionEngine.new(self)
	live_patch_guard = LivePatchGuard.new(self)
	auto_patch_engine = AutoPatchEngine.new(self)
	live_diagnostics_engine = LiveDiagnosticsEngine.new(self)

	if custom_settings.has("year_locked"):
		year_locked = custom_settings ["year_locked"]
	if custom_mode and custom_settings.has("year"):
		year = int(custom_settings ["year"])
	if custom_mode and custom_settings.has("era") and era_engine.eras.has(custom_settings ["era"]):
		era = era_engine.eras [custom_settings ["era"]]
	if not custom_settings.has("year"):
		var e: Dictionary = era_engine.eras [custom_settings ["era"]]
		var start_year: int = int(e.get("start_year", year))
		var end_year: int = int(e.get("end_year", year))
		year = int((float(start_year) + float(end_year)) * 0.5)
	elif custom_mode and custom_settings.has("year"):
		era = era_engine._era_from_year(year)
	else:
		era = era_engine._era_from_year(year)

	if realm_engine != null:
		scenario_state ["birth_shell_realm_bootstrap_deferred"] = true

	var shell_npc_count: int = int(scenario_state.get("birth_shell_npc_count", 4))
	shell_npc_count = clamp(shell_npc_count, 0, 24)
	for i in range(shell_npc_count):
		var npc = npc_factory.create_random_npc(true)
		apply_reality_rules_to_person(npc)
		npcs.append(npc)

	if custom_mode:
		player = character_creator.create_custom_player(custom_settings)
	else:
		player = npc_factory.create_player()

	apply_reality_rules_to_person(player)

	if wizard_engine != null and wizard_engine.has_method("apply_birth_settings"):
		wizard_engine.apply_birth_settings(player, custom_settings)
	if power_engine != null and power_engine.has_method("apply_birth_settings"):
		power_engine.apply_birth_settings(player, custom_settings)
	if superhero_engine != null and superhero_engine.has_method("apply_birth_settings"):
		superhero_engine.apply_birth_settings(player, custom_settings)

	player_id = player.id
	npcs.append(player)
	_apply_custom_household_spawn_contract(player)
	_apply_presidential_parent_contract_if_requested(player)

	var soul_seed_distribution_authorized: bool = bool(scenario_state.get("soul_seed_distribution_authorized", false))
	var soul_seed_priority_family_first: bool = bool(scenario_state.get("soul_seed_priority_family_first", false))
	var soul_seed_targets: Array = _birth_shell_priority_soul_seed_targets() if soul_seed_priority_family_first else npcs

	if soul_seed_engine != null and soul_seed_distribution_authorized:
		var soul_seed_report: Dictionary = soul_seed_engine.assign_world_soul_seeds(soul_seed_targets, custom_settings, {
			"source": "birth_shell_first_life_spawn_priority",
			"world_seed": scenario_state.get("world_seed", custom_settings.get("world_seed", -1)) if typeof(scenario_state) == TYPE_DICTIONARY and typeof(custom_settings) == TYPE_DICTIONARY else -1,
			"seed_contract": scenario_state.get("seed_contract", custom_settings.get("seed_contract", {})) if typeof(scenario_state) == TYPE_DICTIONARY and typeof(custom_settings) == TYPE_DICTIONARY else {},
			"soul_seed_contract": custom_settings.get("soul_seed_contract", {}) if typeof(custom_settings) == TYPE_DICTIONARY else {},
			"player_id": player.id if player != null else player_id,
			"priority_family_first": soul_seed_priority_family_first,
			"background_distribution_deferred": bool(scenario_state.get("soul_seed_background_distribution_deferred", false))
		})
		scenario_state ["soul_seed_priority_distribution_report"] = soul_seed_report.duplicate(true)
		scenario_state ["soul_seed_background_distribution_pending"] = bool(scenario_state.get("soul_seed_background_distribution_deferred", false))
	else:
		scenario_state ["soul_seed_distribution_deferred"] = true
		scenario_state ["soul_seed_distribution_deferred_reason"] = "waiting_for_manual_world_seed_prewarm"

	for npc in npcs:
		if npc == null:
			continue
		if npc == player:
			if consciousness_engine != null:
				consciousness_engine.ensure_consciousness(npc, {
					"source": "birth_shell_first_life_spawn_player_first"
				})
			if willpower_engine != null and willpower_engine.has_method("ensure_willpower"):
				willpower_engine.ensure_willpower(npc, {
					"source": "birth_shell_first_life_spawn_player_first"
				})
		if world_space_engine != null:
			world_space_engine.place_npc(npc)
		if chunk_simulation_engine != null:
			chunk_simulation_engine.assign_npc(npc)

	if player_id == 0 and player != null:
		player_id = player.id
	if player != null and has_method("register_controlled_character"):
		register_controlled_character(player.id)

	if dynasty_engine != null and player != null:
		dynasty_engine.register_dynasty(player.last_name)

	_apply_player_starting_artifact_loadout()

	for pid in player.parents if player != null else []:
		var par = get_npc_by_id(pid)
		if par != null and dynasty_engine != null:
			dynasty_engine.register_dynasty(par.last_name)

	_rebuild_npc_index()

	if food_engine != null and food_engine.has_method("seed_initial_hunger_for_population"):
		food_engine.seed_initial_hunger_for_population(npcs, {
			"source": "birth_shell_initial_hunger",
			"force": false
		})

	if relationship_engine != null and relationship_engine.has_method("seed_family_and_stranger_bonds_for_actor") and player != null:
		relationship_engine.seed_family_and_stranger_bonds_for_actor(player, {
			"source": "birth_shell_relationship_baseline"
		})

	if human_relationship_contract_engine != null and human_relationship_contract_engine.has_method("sync_actor_relationship_edges") and player != null:
		human_relationship_contract_engine.sync_actor_relationship_edges(player, {
			"source": "birth_shell_human_relationship_graph_sync"
		})

	if pets_contract_engine != null and pets_contract_engine.has_method("ensure_birth_family_pet_for_actor") and player != null:
		pets_contract_engine.ensure_birth_family_pet_for_actor(player, {
			"source": "birth_shell_family_pet_seed",
			"max_birth_age": 1
		})

	_soft_unload_npcs()
	scenario_state ["birth_shell_player_created"] = player != null
	scenario_state ["birth_shell_player_id"] = player.id if player != null else 0
	scenario_state ["birth_shell_created_at_ms"] = int(Time.get_ticks_msec())
func _custom_household_spawn_contract() -> Dictionary:
	if typeof(custom_settings) == TYPE_DICTIONARY:
		var raw: Variant = custom_settings.get("household_spawn_contract", {})
		if typeof(raw) == TYPE_DICTIONARY:
			return (raw as Dictionary).duplicate(true)
	if typeof(scenario_state) == TYPE_DICTIONARY:
		var state_raw: Variant = scenario_state.get("custom_household_spawn_contract", {})
		if typeof(state_raw) == TYPE_DICTIONARY:
			return (state_raw as Dictionary).duplicate(true)
	return {}


func _apply_custom_household_spawn_contract(anchor: Person) -> void:
	if anchor == null:
		return

	var contract: Dictionary = _custom_household_spawn_contract()
	if contract.is_empty():
		return

	var members_raw: Variant = contract.get("members", [])
	if typeof(members_raw) != TYPE_ARRAY:
		return

	var members: Array = members_raw as Array
	if members.is_empty():
		return

	var relationship_policy_raw: Variant = contract.get("relationship_policy", {})
	var relationship_policy: Dictionary = relationship_policy_raw if typeof(relationship_policy_raw) == TYPE_DICTIONARY else {}
	var generate_external_family: bool = bool(relationship_policy.get("generate_external_family", false))

	var start_key: String = str(contract.get("start_person_key", "")).strip_edges()
	if start_key == "":
		start_key = str((members [0] as Dictionary).get("local_key", "person_0")) if typeof(members [0]) == TYPE_DICTIONARY else "person_0"
		contract ["start_person_key"] = start_key

	var member_index: Dictionary = {}
	var member_people: Dictionary = {}
	var start_member: Dictionary = {}

	for raw_member in members:
		if typeof(raw_member) != TYPE_DICTIONARY:
			continue
		var member: Dictionary = raw_member as Dictionary
		if str(member.get("local_key", "")).strip_edges() == start_key:
			start_member = member.duplicate(true)
			break

	if start_member.is_empty() and not members.is_empty() and typeof(members [0]) == TYPE_DICTIONARY:
		start_member = (members [0] as Dictionary).duplicate(true)
		start_key = str(start_member.get("local_key", "person_0"))
		contract ["start_person_key"] = start_key

	_apply_custom_household_member_profile(anchor, start_member, contract, true)
	member_index [start_key] = int(anchor.id)
	member_people [start_key] = anchor

	for raw_member in members:
		if typeof(raw_member) != TYPE_DICTIONARY:
			continue

		var member: Dictionary = raw_member as Dictionary
		var local_key: String = str(member.get("local_key", "")).strip_edges()
		if local_key == "" or local_key == start_key:
			continue

		var person: Person = npc_factory.create_random_npc(generate_external_family)
		_apply_custom_household_member_profile(person, member, contract, false)
		apply_reality_rules_to_person(person)
		npcs.append(person)
		member_index [local_key] = int(person.id)
		member_people [local_key] = person

	_wire_custom_household_relationships(anchor, member_people, contract)
	_rebuild_npc_index()

	if typeof(scenario_state) != TYPE_DICTIONARY:
		scenario_state = {}

	scenario_state ["custom_household_spawn_contract"] = contract.duplicate(true)
	scenario_state ["custom_household_member_index"] = member_index.duplicate(true)
	scenario_state ["custom_household_start_person_key"] = start_key
	scenario_state ["custom_household_spawned"] = true
	scenario_state ["custom_household_spawned_at_year"] = year
	scenario_state ["custom_household_spawned_at_ms"] = int(Time.get_ticks_msec())
	scenario_state ["spawn_ready_primary_birth_actor_id"] = int(anchor.id)
	scenario_state ["custom_household_existing_life_start"] = int(anchor.age) > 0
	scenario_state ["custom_household_birth_intro_suppressed"] = int(anchor.age) > 0
func _presidential_parent_contract_resolve_target_key(anchor: Person, mother: Person, father: Person) -> String:
	var requested_key: String = str(custom_settings.get("presidential_parent_target", "weighted_parent")).strip_edges().to_lower()

	if requested_key in ["mother", "mom", "female"] and mother != null:
		return "mother"

	if requested_key in ["father", "dad", "male"] and father != null:
		return "father"

	var seed_basis: String = "presidential_parent_target|%d|%d|%s|%s" % [
		int(anchor.id) if anchor != null else 0,
		int(year),
		str(anchor.first_name) if anchor != null else "",
		str(anchor.last_name) if anchor != null else ""
	]

	var rng:= RandomNumberGenerator.new()
	rng.seed = abs(int(seed_basis.hash())) % 2147483647

	var mother_roll: float = rng.randf()
	if mother != null and father != null:
		return "mother" if mother_roll < 0.58 else "father"

	if mother != null:
		return "mother"

	return "father"
func _presidential_parent_contract_register_federal_population_manifest(us_realm_id: int) -> void:
	if us_realm_id <= 0:
		return

	if typeof(scenario_state) != TYPE_DICTIONARY:
		scenario_state = {}

	var cabinet_count: int = _presidential_parent_contract_federal_cabinet_titles().size()
	var state_count: int = _presidential_parent_contract_united_states_state_names().size()
	var senate_count: int = state_count * 2
	var supreme_court_count: int = 9
	var governor_count: int = state_count
	var citizen_count: int = 150

	scenario_state ["presidential_parent_contract_federal_population_manifest_registered"] = true
	scenario_state ["presidential_parent_contract_federal_population_manifest_registered_at_ms"] = int(Time.get_ticks_msec())
	scenario_state ["presidential_parent_contract_federal_population_projection_only"] = true
	scenario_state ["presidential_parent_contract_federal_population_ui_is_renderer_only"] = true
	scenario_state ["presidential_parent_contract_federal_population_ready_gate_forbidden"] = true
	scenario_state ["presidential_parent_contract_federal_branch_roles_project_from_population_pool"] = true
	scenario_state ["presidential_parent_contract_federal_population_minimum_enforced"] = true
	scenario_state ["presidential_parent_contract_federal_cabinet_target"] = cabinet_count
	scenario_state ["presidential_parent_contract_federal_senate_target"] = senate_count
	scenario_state ["presidential_parent_contract_federal_supreme_court_target"] = supreme_court_count
	scenario_state ["presidential_parent_contract_federal_governor_target"] = governor_count
	scenario_state ["presidential_parent_contract_federal_citizen_target"] = citizen_count

	if realm_engine != null and "realms" in realm_engine and typeof(realm_engine.realms) == TYPE_DICTIONARY:
		var realm_raw: Variant = realm_engine.realms.get(us_realm_id, {})
		var realm: Dictionary = realm_raw if typeof(realm_raw) == TYPE_DICTIONARY else {}

		realm ["federal_republic_population_manifest_registered"] = true
		realm ["federal_republic_population_projection_only"] = true
		realm ["federal_republic_population_ready_gate_forbidden"] = true
		realm ["federal_republic_population_ui_is_renderer_only"] = true
		realm ["federal_republic_branch_roles_project_from_population_pool"] = true
		realm ["federal_republic_population_minimum_enforced"] = true
		realm ["federal_cabinet_target"] = cabinet_count
		realm ["federal_senate_target"] = senate_count
		realm ["federal_supreme_court_target"] = supreme_court_count
		realm ["federal_governor_target"] = governor_count
		realm ["federal_citizen_target"] = citizen_count

		realm_engine.realms [us_realm_id] = realm
func _apply_presidential_parent_contract_if_requested(anchor: Person) -> void:
	if anchor == null:
		return

	if typeof(custom_settings) != TYPE_DICTIONARY:
		return

	if not bool(custom_settings.get("presidential_parents", false)):
		return

	_canonicalize_presidential_parent_location_contract()

	if not _presidential_parent_contract_settings_are_valid():
		return

	if typeof(scenario_state) != TYPE_DICTIONARY:
		scenario_state = {}

	if bool(scenario_state.get("presidential_parent_contract_applied", false)):
		return

	_apply_presidential_parent_location_to_person(anchor)

	var mother: Person = _presidential_parent_contract_resolve_or_create_parent(anchor, "Female")
	var father: Person = _presidential_parent_contract_resolve_or_create_parent(anchor, "Male")

	if mother == null and father == null:
		return

	var target_key: String = _presidential_parent_contract_resolve_target_key(anchor, mother, father)
	var president: Person = mother if target_key == "mother" and mother != null else father
	if president == null:
		president = mother

	var first_partner: Person = null
	if president == mother:
		first_partner = father
	else:
		first_partner = mother

	var us_realm_id: int = _presidential_parent_contract_united_states_realm_id()

	_apply_presidential_parent_location_to_person(president)
	_apply_presidential_parent_location_to_person(first_partner)

	_presidential_parent_contract_apply_president_truth(president, us_realm_id)
	_presidential_parent_contract_apply_first_partner_truth(first_partner, president, us_realm_id)
	_presidential_parent_contract_apply_elite_family_jobs(anchor, president, first_partner, us_realm_id)

	_presidential_parent_contract_register_federal_population_manifest(us_realm_id)
	_presidential_parent_contract_materialize_federal_republic_population(president, first_partner, us_realm_id)
	_presidential_parent_contract_grant_white_house_residence(president, anchor, us_realm_id)

	if (
		us_realm_id > 0
		and realm_engine != null
		and "realms" in realm_engine
		and typeof(
			realm_engine.realms
		) == TYPE_DICTIONARY
	):
		var realm_raw: Variant = (
			realm_engine.realms.get(
				us_realm_id,
				{}
			)
		)
		var realm: Dictionary = (
			realm_raw as Dictionary
			if typeof(
				realm_raw
			) == TYPE_DICTIONARY
			else {}
		)

		realm [
			"ruler_id"
		] = int(
			president.id
		)
		realm [
			"government_style"
		] = "Republic"
		realm [
			"government_model"
		] = "federal_presidential_republic"
		realm [
			"federal_republic_population_contract"
		] = true
		realm [
			"presidential_parent_contract_active"
		] = true
		realm [
			"president_person_id"
		] = int(
			president.id
		)
		realm [
			"first_partner_person_id"
		] = (
			int(
				first_partner.id
			)
			if first_partner != null
			else -1
		)
		realm [
			"capital_city"
		] = "Washington, DC"
		realm [
			"capital_territory"
		] = "District of Columbia"
		realm [
			"selected_place_kind"
		] = "territory"
		realm [
			"selected_place"
		] = "District of Columbia"
		realm [
			"crown_hub_layout_variant"
		] = "federal_republic"
		realm [
			"approval_label"
		] = "Presidential Approval"
		realm [
			"royal_language_forbidden"
		] = true
		realm [
			"white_house_official_residence_active"
		] = true
		realm [
			"white_house_inheritable"
		] = false
		realm [
			"federal_republic_population_streaming"
		] = true
		realm [
			"federal_republic_population_blocks_ready"
		] = false
		realm [
			"federal_republic_population_surface_is_tail_work"
		] = true

		realm_engine.realms [
			us_realm_id
		] = realm




		if realm_engine.has_method(
			"publish_realm_leader_identity_from_person"
		):
			realm_engine.publish_realm_leader_identity_from_person(
				president,
				{
					"realm_id": us_realm_id,
					"leader_title": (
						"President of the United States"
					),
					"government_model": (
						"federal_presidential_republic"
					),
					"source": (
						"game_state."
						+ "presidential_parent_contract"
					)
				}
			)

	scenario_state ["presidential_parent_contract_applied"] = true
	scenario_state ["presidential_parent_contract_applied_at_ms"] = int(Time.get_ticks_msec())
	scenario_state ["presidential_parent_contract_player_id"] = int(anchor.id)
	scenario_state ["presidential_parent_contract_president_id"] = int(president.id)
	scenario_state ["presidential_parent_contract_first_partner_id"] = int(first_partner.id) if first_partner != null else -1
	scenario_state ["presidential_parent_contract_us_realm_id"] = us_realm_id
	scenario_state ["presidential_parent_contract_family_has_no_ruling_power_by_proximity"] = true
	scenario_state ["presidential_parent_contract_ui_is_renderer_only"] = true
	scenario_state ["presidential_parent_contract_location_canonicalized"] = true
	scenario_state ["presidential_parent_contract_birth_city"] = "Washington, DC"
	scenario_state ["presidential_parent_contract_territory"] = "District of Columbia"
	scenario_state ["white_house_official_residence_active"] = true
	scenario_state ["white_house_official_residence_inheritable"] = false
	scenario_state ["presidential_parent_contract_federal_population_forced_before_population_wall"] = false
	scenario_state ["presidential_parent_contract_federal_population_streaming"] = true
	scenario_state ["presidential_parent_contract_federal_population_blocks_ready"] = false
	scenario_state ["presidential_parent_contract_federal_population_surface_is_tail_work"] = true
func _presidential_parent_contract_settings_are_valid() -> bool:
	var country_key: String = str(custom_settings.get("country", "")).strip_edges().to_lower()
	if country_key not in [
		"usa",
		"u.s.a.",
		"united states",
		"united states of america"
	]:
		return false

	var social_key: String = str(custom_settings.get("social_class", "")).strip_edges().to_lower()
	if social_key != "elite":
		return false

	var era_key: String = str(custom_settings.get("era", "")).strip_edges()
	return era_key in ["Industrial", "Modern", "Future"]
func _canonicalize_presidential_parent_location_contract() -> void:
	if typeof(custom_settings) != TYPE_DICTIONARY:
		return

	custom_settings ["country"] = "United States"
	custom_settings ["birth_country"] = "United States"
	custom_settings ["home_country"] = "United States"

	custom_settings ["territory"] = "District of Columbia"
	custom_settings ["birth_territory"] = "District of Columbia"
	custom_settings ["home_territory"] = "District of Columbia"

	custom_settings ["selected_place_kind"] = "territory"
	custom_settings ["selected_place"] = "District of Columbia"

	custom_settings ["state"] = ""
	custom_settings ["birth_state"] = ""
	custom_settings ["home_state"] = ""

	custom_settings ["city"] = "Washington, DC"
	custom_settings ["birth_city"] = "Washington, DC"
	custom_settings ["home_city"] = "Washington, DC"

	custom_settings ["presidential_parent_location_contract"] = {
		"schema": "eralife.presidential_parent_location_contract",
		"version": 1,
		"country": "United States",
		"continent": "North America",
		"place_kind": "territory",
		"territory": "District of Columbia",
		"selected_place": "District of Columbia",
		"city": "Washington, DC",
		"ui_is_renderer_only": true
	}


func _apply_presidential_parent_location_to_person(person: Person) -> void:
	if person == null:
		return

	person.birth_country = "United States"
	person.home_country = "United States"
	person.birth_city = "Washington, DC"
	person.home_city = "Washington, DC"
	person.birth_state = ""
	person.home_state = ""

	person.set("birth_territory", "District of Columbia")
	person.set("home_territory", "District of Columbia")
	person.set("selected_place_kind", "territory")
	person.set("selected_place", "District of Columbia")

	var location_contract: Dictionary = {
		"schema": "eralife.person_geo_location_contract",
		"version": 1,
		"country": "United States",
		"continent": "North America",
		"place_kind": "territory",
		"territory": "District of Columbia",
		"city": "Washington, DC",
		"state": "",
		"source": "presidential_parent_contract",
		"ui_is_renderer_only": true
	}
	person.set("geo_location_contract", location_contract)

func _presidential_parent_contract_united_states_realm_id() -> int:
	if realm_engine == null:
		return -1

	if not ("realms" in realm_engine) or typeof(realm_engine.realms) != TYPE_DICTIONARY:
		return -1

	for raw_realm_id in realm_engine.realms.keys():
		var realm_id: int = int(raw_realm_id)
		var realm_raw: Variant = realm_engine.realms.get(raw_realm_id, {})
		if typeof(realm_raw) != TYPE_DICTIONARY:
			continue

		var realm: Dictionary = realm_raw
		var name_key: String = str(realm.get("name", "")).strip_edges().to_lower()
		var country_key: String = str(realm.get("country", "")).strip_edges().to_lower()

		if name_key in ["usa", "united states", "united states of america"] or country_key in ["usa", "united states", "united states of america"]:
			realm ["name"] = "United States"
			realm ["country"] = "United States"
			realm ["government_style"] = "Republic"
			realm ["government_model"] = "federal_presidential_republic"
			realm ["federal_republic_population_contract"] = true
			realm ["geographical_states"] = _presidential_parent_contract_united_states_state_names()
			realm ["state_count"] = 50
			realm ["capital_city"] = "Washington, DC"
			realm ["capital_territory"] = "District of Columbia"
			realm ["selected_place_kind"] = "territory"
			realm ["selected_place"] = "District of Columbia"
			realm ["crown_hub_layout_variant"] = "federal_republic"
			realm ["approval_label"] = "Presidential Approval"
			realm_engine.realms [realm_id] = realm
			return realm_id

	if realm_engine.has_method("ensure_realm_for_country"):
		var ensured_id: int = int(realm_engine.ensure_realm_for_country("United States", "Washington, DC"))
		if ensured_id > 0:
			var ensured_raw: Variant = realm_engine.realms.get(ensured_id, {})
			var ensured_realm: Dictionary = ensured_raw if typeof(ensured_raw) == TYPE_DICTIONARY else {}
			ensured_realm ["name"] = "United States"
			ensured_realm ["country"] = "United States"
			ensured_realm ["government_style"] = "Republic"
			ensured_realm ["government_model"] = "federal_presidential_republic"
			ensured_realm ["federal_republic_population_contract"] = true
			ensured_realm ["geographical_states"] = _presidential_parent_contract_united_states_state_names()
			ensured_realm ["state_count"] = 50
			ensured_realm ["capital_city"] = "Washington, DC"
			ensured_realm ["capital_territory"] = "District of Columbia"
			ensured_realm ["selected_place_kind"] = "territory"
			ensured_realm ["selected_place"] = "District of Columbia"
			ensured_realm ["crown_hub_layout_variant"] = "federal_republic"
			ensured_realm ["approval_label"] = "Presidential Approval"
			realm_engine.realms [ensured_id] = ensured_realm
			return ensured_id

	return -1
func _presidential_parent_contract_united_states_state_names() -> Array:
	return [
		"Alabama", "Alaska", "Arizona", "Arkansas", "California",
		"Colorado", "Connecticut", "Delaware", "Florida", "Georgia",
		"Hawaii", "Idaho", "Illinois", "Indiana", "Iowa",
		"Kansas", "Kentucky", "Louisiana", "Maine", "Maryland",
		"Massachusetts", "Michigan", "Minnesota", "Mississippi", "Missouri",
		"Montana", "Nebraska", "Nevada", "New Hampshire", "New Jersey",
		"New Mexico", "New York", "North Carolina", "North Dakota", "Ohio",
		"Oklahoma", "Oregon", "Pennsylvania", "Rhode Island", "South Carolina",
		"South Dakota", "Tennessee", "Texas", "Utah", "Vermont",
		"Virginia", "Washington", "West Virginia", "Wisconsin", "Wyoming"
	]

func _presidential_parent_contract_resolve_or_create_parent(anchor: Person, gender_text: String) -> Person:
	var wanted_gender: String = str(gender_text).strip_edges().to_lower()

	for raw_parent_id in anchor.parents:
		var parent_id: int = int(raw_parent_id)
		if parent_id <= 0:
			continue

		var existing_parent: Person = get_npc_by_id(parent_id)
		if existing_parent == null:
			continue

		if str(existing_parent.gender).strip_edges().to_lower() == wanted_gender:
			_apply_presidential_parent_location_to_person(existing_parent)
			return existing_parent

	var parent: Person = npc_factory.create_random_npc(false)
	parent.gender = gender_text
	parent.age = int(clamp(int(anchor.age) + 28, 35, MAX_MORTAL_AGE))
	parent.last_name = anchor.last_name
	parent.name = ("%s %s" % [parent.first_name, parent.last_name]).strip_edges()

	_apply_presidential_parent_location_to_person(parent)

	parent.social_class = "Elite"
	parent.bank_balance = max(int(parent.bank_balance), 10000000)
	parent.fame = max(int(parent.fame), 88)
	parent.respect = max(int(parent.respect), 82)
	parent.approval = max(int(parent.approval), 72)

	apply_reality_rules_to_person(parent)

	if not anchor.parents.has(int(parent.id)):
		anchor.parents.append(int(parent.id))
	if not parent.children.has(int(anchor.id)):
		parent.children.append(int(anchor.id))

	if not npcs.has(parent):
		npcs.append(parent)

	return parent
func _presidential_parent_contract_election_years_remaining() -> int:
	var current_year: int = int(year)
	var cycle_position: int = ((current_year % 4) + 4) % 4
	var remaining: int = 4 - cycle_position
	if remaining <= 0:
		remaining = 4
	return remaining


func _presidential_parent_contract_white_house_asset_id(president: Person) -> int:
	if president == null:
		return 0

	var basis: String = "white_house_official_residence_%d" % int(president.id)
	return abs(int(basis.hash()))
func _presidential_parent_contract_format_money(value: int) -> String:
	var number: int = int(value)
	var sign_text: String = ""

	if number < 0:
		sign_text = "-"
		number = abs(number)

	var raw_text: String = str(number)
	var out: String = ""
	var counter: int = 0

	for i in range(raw_text.length() - 1, -1, -1):
		if counter > 0 and counter % 3 == 0:
			out = "," + out
		out = raw_text.substr(i, 1) + out
		counter += 1

	return "%s$%s" % [sign_text, out]
func _presidential_parent_contract_white_house_value(president: Person, us_realm_id: int) -> int:
	var seed_basis: String = "white_house_value|%d|%d|%d" % [
		int(president.id) if president != null else 0,
		int(us_realm_id),
		int(year)
	]

	var rng:= RandomNumberGenerator.new()
	rng.seed = abs(int(seed_basis.hash())) % 2147483647

	var base_value: int = rng.randi_range(400000000, 625000000)
	var treasury_value: int = 0

	if us_realm_id > 0 and realm_engine != null and "realms" in realm_engine and typeof(realm_engine.realms) == TYPE_DICTIONARY:
		var realm_raw: Variant = realm_engine.realms.get(us_realm_id, {})
		if typeof(realm_raw) == TYPE_DICTIONARY:
			var realm: Dictionary = realm_raw
			treasury_value = int(realm.get("treasury", 0))

	var wealth_multiplier: float = 1.0
	if treasury_value >= 10000000000000:
		wealth_multiplier = 1.42
	elif treasury_value >= 1000000000000:
		wealth_multiplier = 1.3
	elif treasury_value >= 100000000000:
		wealth_multiplier = 1.18
	elif treasury_value >= 10000000000:
		wealth_multiplier = 1.1
	elif treasury_value >= 1000000000:
		wealth_multiplier = 1.04

	return int(round(float(base_value) * wealth_multiplier))
func _presidential_parent_contract_white_house_projected_value(current_value: int, us_realm_id: int) -> int:
	var treasury_value: int = 0

	if us_realm_id > 0 and realm_engine != null and "realms" in realm_engine and typeof(realm_engine.realms) == TYPE_DICTIONARY:
		var realm_raw: Variant = realm_engine.realms.get(us_realm_id, {})
		if typeof(realm_raw) == TYPE_DICTIONARY:
			var realm: Dictionary = realm_raw
			treasury_value = int(realm.get("treasury", 0))

	var growth_rate: float = 0.018

	if treasury_value >= 10000000000000:
		growth_rate = 0.072
	elif treasury_value >= 1000000000000:
		growth_rate = 0.058
	elif treasury_value >= 100000000000:
		growth_rate = 0.044
	elif treasury_value >= 10000000000:
		growth_rate = 0.032
	elif treasury_value >= 1000000000:
		growth_rate = 0.024

	var projected_value: int = int(round(float(current_value) * (1.0 + growth_rate)))
	return max(current_value + 1, projected_value)
func _presidential_parent_contract_white_house_belonging_entry(president: Person, visible_actor: Person, us_realm_id: int) -> Dictionary:
	var years_remaining: int = _presidential_parent_contract_election_years_remaining()
	var asset_id: int = _presidential_parent_contract_white_house_asset_id(president)
	var residence_value: int = _presidential_parent_contract_white_house_value(president, us_realm_id)
	var projected_value: int = _presidential_parent_contract_white_house_projected_value(residence_value, us_realm_id)

	return {
		"id": asset_id,
		"name": "The White House",
		"display_name": "The White House",
		"type": "Official Residence",
		"category": "Government Residences",
		"asset_kind": "official_residence",
		"contract_id": "official_residence_white_house",
		"country": "United States",
		"city": "Washington, DC",
		"territory": "District of Columbia",
		"address": "1600 Pennsylvania Avenue NW, Washington, DC",
		"value": residence_value,
		"base_value": residence_value,
		"estimated_value": residence_value,
		"projected_value_next_year": projected_value,
		"price": 0,
		"legal_owner_id": int(president.id) if president != null else -1,
		"visible_actor_id": int(visible_actor.id) if visible_actor != null else -1,
		"realm_id": us_realm_id,
		"temporary_ownership": true,
		"inheritable": false,
		"government_owned": true,
		"temporary_controlled_by_office_holder": true,
		"years_left_until_election": years_remaining,
		"overview_lines": [
			"Official residence of the President of the United States.",
			"Next year's Projected value: %s." % _presidential_parent_contract_format_money(projected_value),
			"Temporary ownership: %d year%s left until election cycle." % [years_remaining, "" if years_remaining == 1 else "s"],
			"This property is not inheritable."
		],
		"affordances": [
			"access_federal_republic_crown_hub",
			"throw_official_residence_party"
		],
		"actions": [
			{
				"id": "access_white_house_federal_republic_hub",
				"label": "Access",
				"kind": "engine_call",
				"engine_property": "belongings_engine",
				"method": "resolve_belongings_item_action",
				"call_mode": "payload",
				"payload": {
					"action": "access_federal_republic_crown_hub",
					"category": "Government Residences",
					"source_item": {}
				},
				"refresh_after": false
			},
			{
				"id": "throw_white_house_party",
				"label": "Throw Party",
				"kind": "engine_call",
				"engine_property": "belongings_engine",
				"method": "resolve_belongings_item_action",
				"call_mode": "payload",
				"payload": {
					"action": "throw_official_residence_party",
					"category": "Government Residences",
					"source_item": {}
				},
				"refresh_after": false
			}
		],
		"access_contract": {
			"type": "executive_residency",
			"granted_to": int(visible_actor.id) if visible_actor != null else int(president.id),
			"legal_office_holder_id": int(president.id),
			"expires_on": int(year) + years_remaining,
			"revocable": true,
			"owned": false,
			"authority_source": "federal_presidential_republic"
		},
		"reality_identity": {
			"source": "presidential_parent_contract",
			"official_residence": true,
			"government_owned": true,
			"temporary_controlled_by_office_holder": true,
			"ui_is_renderer_only": true
		}
	}

func _presidential_parent_contract_grant_white_house_residence(president: Person, visible_actor: Person, us_realm_id: int) -> void:
	if president == null:
		return

	var residence: Dictionary = _presidential_parent_contract_white_house_belonging_entry(president, visible_actor, us_realm_id)
	var residence_for_president: Dictionary = residence.duplicate(true)
	residence_for_president ["visible_actor_id"] = int(president.id)
	residence_for_president ["owner_id"] = int(president.id)

	if property_engine != null and property_engine.has_method("_register_property_for_owner"):
		var property_entry: Dictionary = residence_for_president.duplicate(true)
		property_entry ["asset_kind"] = "official_residence_property"
		property_entry ["category"] = "Official Residences"
		property_entry ["owners"] = [int(president.id)]
		property_entry ["share_with_partner"] = false
		property_entry ["government_owned"] = true
		property_entry ["temporary_controlled_by_office_holder"] = true
		property_entry ["inheritable"] = false
		property_engine.call("_register_property_for_owner", president, property_entry, false)

	if belongings_engine != null:
		belongings_engine.add_item(president, residence_for_president, "Government Residences", true)

		if visible_actor != null and int(visible_actor.id) != int(president.id):
			var visible_entry: Dictionary = residence.duplicate(true)
			visible_entry ["owner_id"] = int(visible_actor.id)
			visible_entry ["legal_owner_id"] = int(president.id)
			visible_entry ["visible_actor_id"] = int(visible_actor.id)
			visible_entry ["access_basis"] = "first_family_residence_access"
			belongings_engine.add_item(visible_actor, visible_entry, "Government Residences", true)

	if typeof(scenario_state) == TYPE_DICTIONARY:
		scenario_state ["white_house_official_residence_asset_id"] = int(residence.get("id", 0))
		scenario_state ["white_house_official_residence_owner_id"] = int(president.id)
		scenario_state ["white_house_official_residence_visible_actor_id"] = int(visible_actor.id) if visible_actor != null else -1
		scenario_state ["white_house_years_left_until_election"] = int(residence.get("years_left_until_election", 4))
		scenario_state ["white_house_official_residence_inheritable"] = false

func _presidential_parent_contract_apply_president_truth(president: Person, realm_id: int) -> void:
	if president == null:
		return

	president.social_class = "Elite"
	president.job = "President of the United States"
	president.civic_title = "President"
	president.civic_office_contract = {
		"schema": "eralife.civic_office_contract",
		"version": 1,
		"office": "President",
		"office_full_title": "The President of the United States",
		"country": "United States",
		"government_model": "federal_presidential_republic",
		"branch": "executive",
		"crown_hub_access": true,
		"ruling_power_by_office": true,
		"ruling_power_by_family_proximity": false,
		"is_royalty": false,
		"profile_job_label": "President of the United States",
		"fame_floor": 85,
		"recognition_scope": "global",
		"ui_is_renderer_only": true
	}
	president.set("public_identity_contract", {
		"schema": "eralife.public_identity_contract",
		"version": 1,
		"identity_kind": "world_leader",
		"public_title": "President of the United States",
		"recognition_scope": "global",
		"recognized_by_realm_id": realm_id,
		"royal_language_forbidden": true,
		"ui_is_renderer_only": true
	})

	president.bank_balance = max(int(president.bank_balance), 25000000)
	president.fame = max(int(president.fame), 85)
	president.fame_tier = _custom_household_fame_tier(president.fame)
	president.respect = max(int(president.respect), 95)
	president.approval = max(int(president.approval), 70)
	president.is_ruler = true
	president.is_royal = false
	president.royal_title = ""
	president.succession_rank = 99
	president.realm_id = realm_id

	if not president.memories.has("I became President of the United States before this life became playable. This is civic office, not royalty."):
		president.memories.append("I became President of the United States before this life became playable. This is civic office, not royalty.")

func _presidential_parent_contract_apply_first_partner_truth(first_partner: Person, president: Person, realm_id: int) -> void:
	if first_partner == null or president == null:
		return

	var partner_title: String = "First Gentleman" if str(president.gender).strip_edges().to_lower() == "female" else "First Lady"

	first_partner.social_class = "Elite"
	first_partner.job = partner_title
	first_partner.civic_title = partner_title
	first_partner.civic_office_contract = {
		"schema": "eralife.civic_office_contract",
		"version": 1,
		"office": partner_title,
		"office_full_title": "The %s" % partner_title,
		"country": "United States",
		"government_model": "federal_presidential_republic",
		"branch": "executive_family",
		"crown_hub_access": false,
		"ruling_power_by_office": false,
		"ruling_power_by_family_proximity": false,
		"is_royalty": false,
		"profile_job_label": partner_title,
		"fame_floor": 55,
		"recognition_scope": "national",
		"ui_is_renderer_only": true
	}
	first_partner.set("public_identity_contract", {
		"schema": "eralife.public_identity_contract",
		"version": 1,
		"identity_kind": "first_family_partner",
		"public_title": partner_title,
		"recognition_scope": "national",
		"recognized_by_realm_id": realm_id,
		"royal_language_forbidden": true,
		"ui_is_renderer_only": true
	})

	first_partner.bank_balance = max(int(first_partner.bank_balance), 10000000)
	first_partner.fame = max(int(first_partner.fame), 55)
	first_partner.fame_tier = _custom_household_fame_tier(first_partner.fame)
	first_partner.respect = max(int(first_partner.respect), 86)
	first_partner.approval = max(int(first_partner.approval), 64)
	first_partner.is_ruler = false
	first_partner.is_royal = false
	first_partner.royal_title = ""
	first_partner.succession_rank = 99
	first_partner.realm_id = realm_id

	president.partner = first_partner
	first_partner.partner = president
	president.marital_status = "Married"
	first_partner.marital_status = "Married"

	if not president.children.has(int(player_id)):
		president.children.append(int(player_id))
	if not first_partner.children.has(int(player_id)):
		first_partner.children.append(int(player_id))

	var memory_text: String = "I entered public life as %s. This gives visibility, not ruling power." % first_partner.job
	if not first_partner.memories.has(memory_text):
		first_partner.memories.append(memory_text)


func _presidential_parent_contract_apply_elite_family_jobs(anchor: Person, president: Person, first_partner: Person, realm_id: int) -> void:
	if anchor == null:
		return

	var family: Array = []
	var seen: Dictionary = {}

	for raw_parent_id in anchor.parents:
		var parent: Person = get_npc_by_id(int(raw_parent_id))
		if parent == null:
			continue

		if not seen.has(int(parent.id)):
			family.append(parent)
			seen [int(parent.id)] = true

		for raw_child_id in parent.children:
			var child: Person = get_npc_by_id(int(raw_child_id))
			if child != null and not seen.has(int(child.id)):
				family.append(child)
				seen [int(child.id)] = true

	if not seen.has(int(anchor.id)):
		family.append(anchor)
		seen [int(anchor.id)] = true

	for raw_person in family:
		var person: Person = raw_person
		if person == null:
			continue

		person.social_class = "Elite"
		person.bank_balance = max(int(person.bank_balance), 1000000)
		person.realm_id = realm_id
		person.is_ruler = false
		person.is_royal = false
		person.royal_title = ""
		person.succession_rank = 99

		if person == president:
			continue

		if person == first_partner:
			continue

		var is_presidential_child: bool = false
		if president != null and president.children.has(int(person.id)):
			is_presidential_child = true
		if first_partner != null and first_partner.children.has(int(person.id)):
			is_presidential_child = true
		if person.parents.has(int(president.id)) or person.parents.has(int(first_partner.id)):
			is_presidential_child = true

		if is_presidential_child:
			person.fame = max(int(person.fame), 35)
			person.fame_tier = _custom_household_fame_tier(person.fame)
			person.set("public_identity_contract", {
				"schema": "eralife.public_identity_contract",
				"version": 1,
				"identity_kind": "first_family_child",
				"public_title": "Child of the President",
				"recognition_scope": "national",
				"recognized_by_realm_id": realm_id,
				"ruling_power_by_family_proximity": false,
				"royal_language_forbidden": true,
				"ui_is_renderer_only": true
			})

		if int(person.age) >= 18:
			person.job = _presidential_parent_contract_elite_job_for_person(person)
			person.income = max(float(person.income), 250000.0)
func _presidential_parent_contract_federal_cabinet_titles() -> Array:
	return [
		"Vice President",
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


func _presidential_parent_contract_find_existing_federal_official(
	office: String,
	branch: String,
	state_name: String,
	realm_id: int,
	slot_index: int = -1
) -> Person:
	var clean_office: String = str(office).strip_edges()
	var clean_branch: String = str(branch).strip_edges()
	var clean_state: String = str(state_name).strip_edges()

	for raw_person in npcs:
		var person:= raw_person as Person
		if person == null:
			continue
		if not person.alive:
			continue
		if int(person.realm_id) != int(realm_id):
			continue

		var contract_raw: Variant = person.get("civic_office_contract")
		if typeof(contract_raw) != TYPE_DICTIONARY:
			continue

		var contract: Dictionary = contract_raw
		if str(contract.get("government_model", "")).strip_edges() != "federal_presidential_republic":
			continue
		if str(contract.get("office", "")).strip_edges() != clean_office:
			continue
		if str(contract.get("branch", "")).strip_edges() != clean_branch:
			continue
		if str(contract.get("state_name", "")).strip_edges() != clean_state:
			continue

		if slot_index >= 0:
			var existing_slot: int = int(contract.get("office_slot_index", contract.get("slot_index", -1)))
			if existing_slot != slot_index:
				continue

		return person

	return null

func _presidential_parent_contract_federal_entity_id(
	office: String,
	branch: String,
	state_name: String,
	realm_id: int,
	slot_index: int = 0
) -> int:
	var basis: String = "federal_republic_entity|%d|%s|%s|%s|%d" % [
		int(realm_id),
		str(branch).strip_edges(),
		str(office).strip_edges(),
		str(state_name).strip_edges(),
		int(slot_index)
	]
	return 900000000 + (abs(int(basis.hash())) % 90000000)


func _presidential_parent_contract_federal_name_for_id(entity_id: int, gender_text: String = "") -> Dictionary:
	var first_names_male: Array = [
		"Marcus", "Caleb", "Elliot", "Darius", "Julian", "Nathan", "Andre", "Miles",
		"Victor", "Wesley", "Dominic", "Isaiah", "Grant", "Malcolm", "Cameron", "Leon"
	]
	var first_names_female: Array = [
		"Naomi", "Talia", "Vivian", "Camille", "Elena", "Simone", "Amara", "Jasmine",
		"Rachel", "Morgan", "Alicia", "Serena", "Leah", "Nadia", "Autumn", "Imani"
	]
	var last_names: Array = [
		"Brooks", "Bennett", "Coleman", "Hayes", "Parker", "Washington", "Ellis",
		"Reed", "Foster", "Sullivan", "Hughes", "Carter", "Morgan", "Price",
		"Jefferson", "Bailey", "Sanders", "Morris", "Ward", "Bell"
	]

	var gender_key: String = str(gender_text).strip_edges().to_lower()
	if gender_key == "":
		gender_key = "female" if entity_id % 2 == 0 else "male"

	var first_pool: Array = first_names_female if gender_key == "female" else first_names_male
	var first_index: int = abs(entity_id) % first_pool.size()
	var last_index_basis: int = int(floor(float(abs(entity_id)) / 7.0))
	var last_index: int = last_index_basis % last_names.size()

	var first_name: String = str(first_pool [first_index])
	var last_name: String = str(last_names [last_index])

	return {
		"first_name": first_name,
		"last_name": last_name,
		"name": ("%s %s" % [first_name, last_name]).strip_edges(),
		"gender": "Female" if gender_key == "female" else "Male"
	}

func _presidential_parent_contract_make_dormant_federal_entity(
	office: String,
	branch: String,
	state_name: String,
	realm_id: int,
	min_age: int,
	priority: int,
	slot_index: int = 0,
	social_class_text: String = "Upper Class",
	job_text: String = ""
) -> Dictionary:
	var clean_office: String = str(office).strip_edges()
	var clean_branch: String = str(branch).strip_edges()
	var clean_state: String = str(state_name).strip_edges()
	var clean_job: String = str(job_text).strip_edges()
	if clean_job == "":
		clean_job = clean_office

	var entity_id: int = _presidential_parent_contract_federal_entity_id(clean_office, clean_branch, clean_state, realm_id, slot_index)
	var name_contract: Dictionary = _presidential_parent_contract_federal_name_for_id(entity_id)
	var age_value: int = max(min_age, 30 + (abs(entity_id) % 38))

	var smarts_value: int = 72
	var respect_value: int = 62
	var fame_value: int = 28
	var approval_value: int = 45
	var income_value: float = 185000.0
	var bank_value: int = 250000

	if clean_branch == "judicial":
		smarts_value = 88
		respect_value = 80
		fame_value = 32
		approval_value = 50
		income_value = 285000.0
		bank_value = 600000
	elif clean_branch == "senate":
		smarts_value = 78
		respect_value = 70
		fame_value = 54
		approval_value = 56
		income_value = 220000.0
		bank_value = 520000
	elif clean_branch == "state_governor":
		smarts_value = 76
		respect_value = 68
		fame_value = 58
		approval_value = 60
		income_value = 210000.0
		bank_value = 480000
	elif clean_branch == "cabinet":
		smarts_value = 82
		respect_value = 74
		fame_value = 44
		approval_value = 52
		income_value = 240000.0
		bank_value = 560000

	var entity: Dictionary = {
		"id": entity_id,
		"first_name": str(name_contract.get("first_name", "")),
		"last_name": str(name_contract.get("last_name", "")),
		"name": str(name_contract.get("name", "")),
		"gender": str(name_contract.get("gender", "Male")),
		"age": age_value,
		"alive": true,
		"social_class": social_class_text,
		"job": clean_job,
		"civic_title": clean_office,
		"civic_office_contract": {
			"schema": "eralife.civic_office_contract",
			"version": 1,
			"office": clean_office,
			"office_full_title": clean_office if clean_state == "" else "%s of %s" % [clean_office, clean_state],
			"country": "United States",
			"state_name": clean_state,
			"government_model": "federal_presidential_republic",
			"branch": clean_branch,
			"priority": priority,
			"crown_hub_access": false,
			"ruling_power_by_office": clean_branch in ["executive", "cabinet", "senate", "judicial", "state_governor"],
			"ruling_power_by_family_proximity": false,
			"is_royalty": false,
			"ui_is_renderer_only": true
		},
		"home_country": "United States",
		"birth_country": "United States",
		"home_city": "Washington, DC" if clean_state == "" else clean_state,
		"birth_city": "Washington, DC" if clean_state == "" else clean_state,
		"home_state": clean_state,
		"birth_state": clean_state,
		"home_territory": "District of Columbia" if clean_state == "" else "",
		"birth_territory": "District of Columbia" if clean_state == "" else "",
		"realm_id": realm_id,
		"is_ruler": false,
		"is_royal": false,
		"royal_title": "",
		"succession_rank": 99,
		"smarts": smarts_value,
		"respect": respect_value,
		"fame": fame_value,
		"approval": approval_value,
		"bank_balance": bank_value,
		"income": income_value,
	}

	return entity


func _presidential_parent_contract_store_dormant_federal_entity(entity: Dictionary) -> Dictionary:
	if typeof(entity) != TYPE_DICTIONARY:
		return {}

	var entity_id: int = int(entity.get("id", -1))
	if entity_id <= 0:
		return {}

	if typeof(dormant_npcs) != TYPE_DICTIONARY:
		dormant_npcs = {}

	dormant_npcs [entity_id] = entity.duplicate(true)
	dormant_npcs [str(entity_id)] = entity.duplicate(true)

	return entity
func _presidential_parent_contract_create_federal_official(
	office: String,
	branch: String,
	state_name: String,
	realm_id: int,
	min_age: int,
	priority: int,
	_slot_index: int = 0
) -> Person:
	var clean_office: String = str(office).strip_edges()
	var clean_branch: String = str(branch).strip_edges()
	var clean_state: String = str(state_name).strip_edges()
	var slot_index: int = maxi(0, int(_slot_index))

	if clean_office == "":
		return null

	var existing: Person = _presidential_parent_contract_find_existing_federal_official(
		clean_office,
		clean_branch,
		clean_state,
		realm_id,
		slot_index
	)
	if existing != null:
		return existing

	var entity_id: int = _presidential_parent_contract_federal_entity_id(
		clean_office,
		clean_branch,
		clean_state,
		realm_id,
		slot_index
	)

	for raw_person in npcs:
		var existing_person:= raw_person as Person
		if existing_person == null:
			continue
		if int(existing_person.id) == entity_id:
			return existing_person

	var name_contract: Dictionary = _presidential_parent_contract_federal_name_for_id(entity_id)
	var person:= Person.new()

	person.id = entity_id
	person.first_name = str(name_contract.get("first_name", ""))
	person.last_name = str(name_contract.get("last_name", ""))
	person.name = str(name_contract.get("name", "%s %s" % [person.first_name, person.last_name])).strip_edges()
	person.gender = str(name_contract.get("gender", "Male"))
	person.age = _presidential_parent_contract_federal_age_for_office(
		clean_office,
		clean_branch,
		clean_state,
		realm_id,
		slot_index,
		min_age
	)

	if int(person.age) > MAX_MORTAL_AGE:
		person.age = min_age

	var office_full_title: String = clean_office
	if clean_state != "":
		office_full_title = "%s of %s" % [clean_office, clean_state]

	person.alive = true
	person.social_class = "Upper Class"
	person.job = clean_office
	person.civic_title = clean_office
	person.civic_office_contract = {
		"schema": "eralife.civic_office_contract",
		"version": 3,
		"office": clean_office,
		"office_full_title": office_full_title,
		"country": "United States",
		"state_name": clean_state,
		"government_model": "federal_presidential_republic",
		"branch": clean_branch,
		"priority": priority,
		"office_slot_index": slot_index,
		"slot_index": slot_index,
		"office_unique_key": "%s|%s|%s|%d" % [clean_branch, clean_office, clean_state, slot_index],
		"crown_hub_access": false,
		"ruling_power_by_office": clean_branch in ["executive", "cabinet", "senate", "judicial", "state_governor"],
		"ruling_power_by_family_proximity": false,
		"is_royalty": false,
		"ui_is_renderer_only": true
	}

	person.home_country = "United States"
	person.birth_country = "United States"
	person.home_city = "Washington, DC" if clean_state == "" else clean_state
	person.birth_city = "Washington, DC" if clean_state == "" else clean_state
	person.home_state = clean_state
	person.birth_state = clean_state
	person.set("home_territory", "District of Columbia" if clean_state == "" else "")
	person.set("birth_territory", "District of Columbia" if clean_state == "" else "")

	person.realm_id = realm_id
	person.is_ruler = false
	person.is_royal = false
	person.royal_title = ""
	person.succession_rank = 99

	person.smarts = 72
	person.respect = 62
	person.fame = 28
	person.approval = 45
	person.income = 185000.0
	person.bank_balance = 250000

	match clean_branch:
		"judicial":
			person.smarts = 88
			person.respect = 80
			person.fame = 32
			person.approval = 50
			person.income = 285000.0
			person.bank_balance = 600000
		"senate":
			person.smarts = 78
			person.respect = 70
			person.fame = 54
			person.approval = 56
			person.income = 220000.0
			person.bank_balance = 520000
		"state_governor":
			person.smarts = 76
			person.respect = 68
			person.fame = 58
			person.approval = 60
			person.income = 210000.0
			person.bank_balance = 480000
		"cabinet":
			person.smarts = 82
			person.respect = 74
			person.fame = 44
			person.approval = 52
			person.income = 240000.0
			person.bank_balance = 560000

	person.health = max(float(person.health), 70.0)
	person.mental_health = max(float(person.mental_health), 62.0)
	person.set("federal_republic_fast_materialized", true)
	person.set("federal_republic_materialized_without_full_reality_rule_pass", true)
	person.set("federal_republic_shell_bypassed_npc_factory", true)

	if not npcs.has(person):
		npcs.append(person)

	return person
func _presidential_parent_contract_create_federal_citizen(
	strata_key: String,
	social_class_text: String,
	job_text: String,
	realm_id: int,
	_slot_index: int,
	min_age: int = 18
) -> Person:
	var clean_strata: String = str(strata_key).strip_edges()
	var clean_social: String = str(social_class_text).strip_edges()
	var clean_job: String = str(job_text).strip_edges()
	var slot_index: int = maxi(0, int(_slot_index))

	if clean_job == "":
		clean_job = "Citizen"

	var entity_id: int = _presidential_parent_contract_federal_entity_id(
		"Citizen",
		"civilian",
		clean_strata,
		realm_id,
		slot_index
	)

	for raw_person in npcs:
		var existing_person:= raw_person as Person
		if existing_person == null:
			continue
		if int(existing_person.id) == entity_id:
			return existing_person

	var name_contract: Dictionary = _presidential_parent_contract_federal_name_for_id(entity_id)
	var person:= Person.new()

	person.id = entity_id
	person.first_name = str(name_contract.get("first_name", ""))
	person.last_name = str(name_contract.get("last_name", ""))
	person.name = str(name_contract.get("name", "%s %s" % [person.first_name, person.last_name])).strip_edges()
	person.gender = str(name_contract.get("gender", "Male"))
	person.age = max(min_age, 18 + (abs(entity_id) % 54))
	if int(person.age) > MAX_MORTAL_AGE:
		person.age = min_age

	person.alive = true
	person.social_class = clean_social
	person.job = clean_job
	person.civic_title = ""
	person.civic_office_contract = {
		"schema": "eralife.civic_population_contract",
		"version": 3,
		"country": "United States",
		"government_model": "federal_presidential_republic",
		"branch": "civilian",
		"class_strata": clean_strata,
		"social_class": clean_social,
		"office_slot_index": slot_index,
		"slot_index": slot_index,
		"office_unique_key": "civilian|%s|%d" % [clean_strata, slot_index],
		"ui_is_renderer_only": true
	}

	person.set("population_class_strata", clean_strata)
	person.home_country = "United States"
	person.birth_country = "United States"
	person.home_city = "Washington, DC"
	person.birth_city = "Washington, DC"
	person.home_state = ""
	person.birth_state = ""
	person.set("home_territory", "District of Columbia")
	person.set("birth_territory", "District of Columbia")

	person.realm_id = realm_id
	person.is_ruler = false
	person.is_royal = false
	person.royal_title = ""
	person.succession_rank = 99

	match clean_strata:
		"bottom_class":
			person.bank_balance = 12000 + (abs(entity_id) % 12000)
			person.income = 28000.0 + float(abs(entity_id) % 9000)
			person.fame = 8 + (abs(entity_id) % 16)
			person.approval = 35 + (abs(entity_id) % 12)
		"lower_middle_class":
			person.bank_balance = 35000 + (abs(entity_id) % 45000)
			person.income = 52000.0 + float(abs(entity_id) % 16000)
			person.fame = 12 + (abs(entity_id) % 18)
			person.approval = 42 + (abs(entity_id) % 13)
		"middle_class":
			person.bank_balance = 90000 + (abs(entity_id) % 90000)
			person.income = 72000.0 + float(abs(entity_id) % 22000)
			person.fame = 14 + (abs(entity_id) % 20)
			person.approval = 46 + (abs(entity_id) % 12)
		"upper_middle_class":
			person.bank_balance = 450000 + (abs(entity_id) % 350000)
			person.income = 125000.0 + float(abs(entity_id) % 55000)
			person.fame = 20 + (abs(entity_id) % 22)
			person.approval = 50 + (abs(entity_id) % 13)
		"elite":
			person.bank_balance = 3000000 + (abs(entity_id) % 4000000)
			person.income = 350000.0 + float(abs(entity_id) % 250000)
			person.fame = 45 + (abs(entity_id) % 28)
			person.approval = 55 + (abs(entity_id) % 16)
		_:
			person.bank_balance = 50000 + (abs(entity_id) % 50000)
			person.income = 54000.0 + float(abs(entity_id) % 16000)
			person.fame = 15
			person.approval = 45

	person.smarts = max(int(person.smarts), 45)
	person.health = max(float(person.health), 55.0)
	person.mental_health = max(float(person.mental_health), 45.0)
	person.set("federal_republic_fast_materialized", true)
	person.set("federal_republic_materialized_without_full_reality_rule_pass", true)
	person.set("federal_republic_shell_bypassed_npc_factory", true)

	if not npcs.has(person):
		npcs.append(person)

	return person
func _presidential_parent_contract_unique_positive_ids(values: Array) -> Array:
	var out: Array = []
	var seen: Dictionary = {}

	for raw_value in values:
		var value_id: int = int(raw_value)
		if value_id <= 0:
			continue
		if seen.has(value_id):
			continue

		out.append(value_id)
		seen [value_id] = true

	return out
func _presidential_parent_contract_entity_id_from_value(raw_value) -> int:
	if raw_value == null:
		return -1

	if typeof(raw_value) == TYPE_DICTIONARY:
		var raw_dict: Dictionary = raw_value
		return int(raw_dict.get("id", -1))

	if raw_value is Person:
		return int((raw_value as Person).id)

	if typeof(raw_value) == TYPE_OBJECT:
		return int(raw_value.get("id"))

	return -1
func _presidential_parent_contract_materialize_federal_republic_population(
	_president: Person,
	_first_partner: Person,
	us_realm_id: int
) -> void:
	if us_realm_id <= 0:
		return

	if typeof(scenario_state) != TYPE_DICTIONARY:
		scenario_state = {}

	if bool(scenario_state.get("presidential_parent_contract_federal_population_complete", false)):
		return

	if bool(scenario_state.get("presidential_parent_contract_federal_population_stream_running", false)):
		return

	var defer_until_player_control: bool = _presidential_parent_contract_federal_population_should_wait_for_player_control()
	var expected_total: int = _presidential_parent_contract_federal_population_stream_expected_total()

	scenario_state ["presidential_parent_contract_federal_population_stream_running"] = not defer_until_player_control
	scenario_state ["presidential_parent_contract_federal_population_stream_complete"] = false
	scenario_state ["presidential_parent_contract_federal_population_stream_cursor"] = 0
	scenario_state ["presidential_parent_contract_federal_population_stream_total"] = expected_total
	scenario_state ["presidential_parent_contract_federal_population_stream_jobs"] = []
	scenario_state ["presidential_parent_contract_federal_population_stream_jobs_built"] = false
	scenario_state ["presidential_parent_contract_federal_population_stream_jobs_pending_after_player_control"] = defer_until_player_control
	scenario_state ["presidential_parent_contract_federal_population_blocks_ready"] = false
	scenario_state ["presidential_parent_contract_federal_population_surface_is_tail_work"] = true
	scenario_state ["presidential_parent_contract_federal_population_ui_is_renderer_only"] = true
	scenario_state ["presidential_parent_contract_federal_population_external_stream_driver"] = defer_until_player_control
	scenario_state ["presidential_parent_contract_federal_population_pending_after_player_control"] = defer_until_player_control
	scenario_state ["presidential_parent_contract_federal_population_deferred_before_ready"] = defer_until_player_control
	scenario_state ["presidential_parent_contract_federal_population_deferred_reason"] = "god_mode_prewarm_game_state_initialize" if defer_until_player_control else ""
	scenario_state ["presidential_parent_contract_federal_population_ready_gate_forbidden"] = true
	scenario_state ["presidential_parent_contract_government_contract_ready"] = true
	scenario_state ["presidential_parent_contract_government_contract_only_before_player_control"] = defer_until_player_control

	if realm_engine != null and "realms" in realm_engine and typeof(realm_engine.realms) == TYPE_DICTIONARY:
		var realm_raw: Variant = realm_engine.realms.get(us_realm_id, {})
		var realm: Dictionary = realm_raw if typeof(realm_raw) == TYPE_DICTIONARY else {}
		realm ["government_contract_ready"] = true
		realm ["government_contract_schema"] = "eralife.government_contract"
		realm ["government_contract_version"] = 1
		realm ["government_type"] = "federal_presidential_republic"
		realm ["government_style"] = "Republic"
		realm ["government_model"] = "federal_presidential_republic"
		realm ["government_branch_contract"] = {
			"schema": "eralife.government_branch_contract",
			"version": 1,
			"government_type": "federal_presidential_republic",
			"branches": {
				"executive": {
					"target": 2,
					"visible_section": "federal_executive",
					"streamed": false
				},
				"cabinet": {
					"target": _presidential_parent_contract_federal_cabinet_titles().size(),
					"visible_section": "federal_cabinet",
					"streamed": true
				},
				"senate": {
					"target": _presidential_parent_contract_united_states_state_names().size() * 2,
					"visible_section": "federal_senate",
					"streamed": true
				},
				"judicial": {
					"target": 9,
					"visible_section": "federal_supreme_court",
					"streamed": true
				},
				"state_governor": {
					"target": _presidential_parent_contract_united_states_state_names().size(),
					"visible_section": "federal_governor",
					"streamed": true
				},
				"civilian": {
					"target": 150,
					"visible_section": "citizen",
					"streamed": true
				}
			},
			"ready_door_may_not_wait": true,
			"ui_is_renderer_only": true
		}
		realm ["federal_republic_population_stream_running"] = not defer_until_player_control
		realm ["federal_republic_population_stream_complete"] = false
		realm ["federal_republic_population_stream_total"] = expected_total
		realm ["federal_republic_population_stream_jobs_built"] = false
		realm ["federal_republic_population_stream_jobs_pending_after_player_control"] = defer_until_player_control
		realm ["federal_republic_population_blocks_ready"] = false
		realm ["federal_republic_population_surface_is_tail_work"] = true
		realm ["federal_republic_population_ui_is_renderer_only"] = true
		realm ["federal_republic_population_pending_after_player_control"] = defer_until_player_control
		realm ["federal_republic_population_ready_gate_forbidden"] = true
		realm_engine.realms [us_realm_id] = realm

	if defer_until_player_control:
		return

	_presidential_parent_contract_prepare_federal_population_stream_jobs_after_player_control(us_realm_id)
	call_deferred("_presidential_parent_contract_materialize_federal_republic_population_stream_tick", us_realm_id, 0)
func _presidential_parent_contract_federal_population_stream_expected_total() -> int:
	var cabinet_count: int = _presidential_parent_contract_federal_cabinet_titles().size()
	var state_count: int = _presidential_parent_contract_united_states_state_names().size()
	var senate_count: int = state_count * 2
	var supreme_court_count: int = 9
	var governor_count: int = state_count
	var citizen_count: int = 150

	return cabinet_count + senate_count + supreme_court_count + governor_count + citizen_count


func _presidential_parent_contract_prepare_federal_population_stream_jobs_after_player_control(us_realm_id: int) -> bool:
	if us_realm_id <= 0:
		return false

	if typeof(scenario_state) != TYPE_DICTIONARY:
		scenario_state = {}

	if bool(scenario_state.get("presidential_parent_contract_federal_population_stream_jobs_built", false)):
		return true

	var stream_jobs: Array = _presidential_parent_contract_federal_population_stream_jobs(us_realm_id)
	if stream_jobs.is_empty():
		return false

	scenario_state ["presidential_parent_contract_federal_population_stream_jobs"] = stream_jobs.duplicate(true)
	scenario_state ["presidential_parent_contract_federal_population_stream_jobs_built"] = true
	scenario_state ["presidential_parent_contract_federal_population_stream_jobs_built_at_ms"] = int(Time.get_ticks_msec())
	scenario_state ["presidential_parent_contract_federal_population_stream_jobs_pending_after_player_control"] = false
	scenario_state ["presidential_parent_contract_federal_population_stream_total"] = stream_jobs.size()
	scenario_state ["presidential_parent_contract_federal_population_pending_after_player_control"] = true
	scenario_state ["presidential_parent_contract_federal_population_external_stream_driver"] = true
	scenario_state ["presidential_parent_contract_federal_population_blocks_ready"] = false
	scenario_state ["presidential_parent_contract_federal_population_surface_is_tail_work"] = true
	scenario_state ["presidential_parent_contract_federal_population_ready_gate_forbidden"] = true

	if realm_engine != null and "realms" in realm_engine and typeof(realm_engine.realms) == TYPE_DICTIONARY:
		var realm_raw: Variant = realm_engine.realms.get(us_realm_id, {})
		var realm: Dictionary = realm_raw if typeof(realm_raw) == TYPE_DICTIONARY else {}
		realm ["federal_republic_population_stream_jobs_built"] = true
		realm ["federal_republic_population_stream_jobs_built_at_ms"] = int(Time.get_ticks_msec())
		realm ["federal_republic_population_stream_jobs_pending_after_player_control"] = false
		realm ["federal_republic_population_stream_total"] = stream_jobs.size()
		realm ["federal_republic_population_pending_after_player_control"] = true
		realm ["federal_republic_population_blocks_ready"] = false
		realm ["federal_republic_population_surface_is_tail_work"] = true
		realm ["federal_republic_population_ready_gate_forbidden"] = true
		realm_engine.realms [us_realm_id] = realm

	return true
func _presidential_parent_contract_federal_population_should_wait_for_player_control() -> bool:
	if typeof(scenario_state) != TYPE_DICTIONARY:
		return false

	if bool(scenario_state.get("god_mode_life_prewarm_background_worker", false)):
		return true

	if not bool(scenario_state.get("runtime_scene_tree_access_allowed", true)):
		return true

	if bool(scenario_state.get("birth_shell_first_boot_active", false)):
		return true

	if bool(scenario_state.get("birth_shell_fast_first_paint", false)):
		return true

	if bool(scenario_state.get("presidential_parent_contract_federal_population_blocks_ready", false)):
		return false

	if bool(scenario_state.get("presidential_parent_contract_federal_population_surface_is_tail_work", false)) \
and not bool(scenario_state.get("birth_shell_player_control_released", false)):
		return true

	return false
func _presidential_parent_contract_federal_population_stream_jobs(us_realm_id: int) -> Array:
	var jobs: Array = []

	var cabinet_titles: Array = _presidential_parent_contract_federal_cabinet_titles()
	for i in range(cabinet_titles.size()):
		jobs.append({
			"kind": "official",
			"branch": "cabinet",
			"office": str(cabinet_titles [i]),
			"state_name": "",
			"realm_id": us_realm_id,
			"min_age": 32,
			"priority": 8800 - i,
			"slot_index": i
		})

	var states: Array = _presidential_parent_contract_united_states_state_names()
	for state_index in range(states.size()):
		var state_name: String = str(states [state_index])

		for senate_seat in range(2):
			var senator_slot: int = (state_index * 2) + senate_seat
			jobs.append({
				"kind": "official",
				"branch": "senate",
				"office": "Senator",
				"state_name": state_name,
				"realm_id": us_realm_id,
				"min_age": 30,
				"priority": 7600 - senator_slot,
				"slot_index": senator_slot
			})

		jobs.append({
			"kind": "official",
			"branch": "state_governor",
			"office": "Governor",
			"state_name": state_name,
			"realm_id": us_realm_id,
			"min_age": 30,
			"priority": 6400 - state_index,
			"slot_index": state_index
		})

	for i in range(9):
		jobs.append({
			"kind": "official",
			"branch": "judicial",
			"office": "Supreme Court Justice",
			"state_name": "",
			"realm_id": us_realm_id,
			"min_age": 32,
			"priority": 7600 - i,
			"slot_index": i
		})

	var citizen_templates: Array = [
		["bottom_class", "Bottom Class", "Service Worker", 36],
		["lower_middle_class", "Lower-Middle Class", "Warehouse Supervisor", 34],
		["middle_class", "Middle Class", "Teacher", 34],
		["upper_middle_class", "Upper-Middle Class", "Engineer", 30],
		["elite", "Elite", "Corporate Executive", 16]
	]

	var citizen_slot: int = 0
	for raw_template in citizen_templates:
		if typeof(raw_template) != TYPE_ARRAY:
			continue

		var template: Array = raw_template
		var strata_key: String = str(template [0])
		var social_class_text: String = str(template [1])
		var job_text: String = str(template [2])
		var count: int = int(template [3])

		for i in range(count):
			jobs.append({
				"kind": "citizen",
				"strata_key": strata_key,
				"social_class": social_class_text,
				"job": job_text,
				"realm_id": us_realm_id,
				"slot_index": citizen_slot,
				"min_age": 18
			})

			citizen_slot += 1

	return jobs


func _presidential_parent_contract_append_unique_id(target_array: Array, entity_id: int) -> void:
	if entity_id <= 0:
		return
	if target_array.has(entity_id):
		return

	target_array.append(entity_id)


func _presidential_parent_contract_materialize_federal_republic_population_stream_tick(
	us_realm_id: int,
	cursor: int = 0
) -> void:
	if us_realm_id <= 0:
		return

	if typeof(scenario_state) != TYPE_DICTIONARY:
		scenario_state = {}

	if not bool(
		scenario_state.get(
			"presidential_parent_contract_federal_population_stream_jobs_built",
			false
		)
	):
		if not _presidential_parent_contract_prepare_federal_population_stream_jobs_after_player_control(
			us_realm_id
		):
			scenario_state [
				"presidential_parent_contract_federal_population_stream_running"
			] = false
			scenario_state [
				"presidential_parent_contract_federal_population_pending_after_player_control"
			] = true
			scenario_state [
				"presidential_parent_contract_federal_population_stream_jobs_pending_after_player_control"
			] = true
			return

	var jobs: Array = (
		scenario_state.get(
			"presidential_parent_contract_federal_population_stream_jobs",
			[]
		)
		if typeof(
			scenario_state.get(
				"presidential_parent_contract_federal_population_stream_jobs",
				[]
			)
		) == TYPE_ARRAY
		else []
	)

	if jobs.is_empty():
		scenario_state [
			"presidential_parent_contract_federal_population_stream_running"
		] = false
		scenario_state [
			"presidential_parent_contract_federal_population_pending_after_player_control"
		] = true
		scenario_state [
			"presidential_parent_contract_federal_population_stream_jobs_pending_after_player_control"
		] = true
		return

	var cabinet_ids: Array = (
		scenario_state.get(
			"presidential_parent_contract_federal_cabinet_ids",
			[]
		)
		if typeof(
			scenario_state.get(
				"presidential_parent_contract_federal_cabinet_ids",
				[]
			)
		) == TYPE_ARRAY
		else []
	)
	var senate_ids: Array = (
		scenario_state.get(
			"presidential_parent_contract_federal_senate_ids",
			[]
		)
		if typeof(
			scenario_state.get(
				"presidential_parent_contract_federal_senate_ids",
				[]
			)
		) == TYPE_ARRAY
		else []
	)
	var supreme_court_ids: Array = (
		scenario_state.get(
			"presidential_parent_contract_federal_supreme_court_ids",
			[]
		)
		if typeof(
			scenario_state.get(
				"presidential_parent_contract_federal_supreme_court_ids",
				[]
			)
		) == TYPE_ARRAY
		else []
	)
	var governor_ids: Array = (
		scenario_state.get(
			"presidential_parent_contract_federal_governor_ids",
			[]
		)
		if typeof(
			scenario_state.get(
				"presidential_parent_contract_federal_governor_ids",
				[]
			)
		) == TYPE_ARRAY
		else []
	)
	var citizen_ids: Array = (
		scenario_state.get(
			"presidential_parent_contract_federal_citizen_ids",
			[]
		)
		if typeof(
			scenario_state.get(
				"presidential_parent_contract_federal_citizen_ids",
				[]
			)
		) == TYPE_ARRAY
		else []
	)

	var batch_size: int = 10
	var processed: int = 0
	var next_cursor: int = maxi(
		0,
		cursor
	)

	while (
		next_cursor < jobs.size()
		and processed < batch_size
	):
		var job_raw: Variant = jobs [
			next_cursor
		]
		next_cursor += 1

		if typeof(
			job_raw
		) != TYPE_DICTIONARY:
			continue

		var job: Dictionary = job_raw
		var kind: String = str(
			job.get(
				"kind",
				""
			)
		).strip_edges().to_lower()
		var person = null

		if kind == "official":
			person = _presidential_parent_contract_create_federal_official(
				str(
					job.get(
						"office",
						""
					)
				),
				str(
					job.get(
						"branch",
						""
					)
				),
				str(
					job.get(
						"state_name",
						""
					)
				),
				int(
					job.get(
						"realm_id",
						us_realm_id
					)
				),
				int(
					job.get(
						"min_age",
						30
					)
				),
				int(
					job.get(
						"priority",
						0
					)
				),
				int(
					job.get(
						"slot_index",
						0
					)
				)
			)

			var official_id: int = (
				_presidential_parent_contract_entity_id_from_value(
					person
				)
			)

			match str(
				job.get(
					"branch",
					""
				)
			).strip_edges().to_lower():
				"cabinet":
					_presidential_parent_contract_append_unique_id(
						cabinet_ids,
						official_id
					)
				"senate":
					_presidential_parent_contract_append_unique_id(
						senate_ids,
						official_id
					)
				"judicial":
					_presidential_parent_contract_append_unique_id(
						supreme_court_ids,
						official_id
					)
				"state_governor":
					_presidential_parent_contract_append_unique_id(
						governor_ids,
						official_id
					)

		elif kind == "citizen":
			person = _presidential_parent_contract_create_federal_citizen(
				str(
					job.get(
						"strata_key",
						""
					)
				),
				str(
					job.get(
						"social_class",
						""
					)
				),
				str(
					job.get(
						"job",
						""
					)
				),
				int(
					job.get(
						"realm_id",
						us_realm_id
					)
				),
				int(
					job.get(
						"slot_index",
						0
					)
				),
				int(
					job.get(
						"min_age",
						18
					)
				)
			)

			var citizen_id: int = (
				_presidential_parent_contract_entity_id_from_value(
					person
				)
			)
			_presidential_parent_contract_append_unique_id(
				citizen_ids,
				citizen_id
			)

		processed += 1

	scenario_state [
		"presidential_parent_contract_federal_population_stream_cursor"
	] = next_cursor
	scenario_state [
		"presidential_parent_contract_federal_population_stream_total"
	] = jobs.size()
	scenario_state [
		"presidential_parent_contract_federal_cabinet_ids"
	] = cabinet_ids.duplicate(true)
	scenario_state [
		"presidential_parent_contract_federal_senate_ids"
	] = senate_ids.duplicate(true)
	scenario_state [
		"presidential_parent_contract_federal_supreme_court_ids"
	] = supreme_court_ids.duplicate(true)
	scenario_state [
		"presidential_parent_contract_federal_governor_ids"
	] = governor_ids.duplicate(true)
	scenario_state [
		"presidential_parent_contract_federal_citizen_ids"
	] = citizen_ids.duplicate(true)
	scenario_state [
		"presidential_parent_contract_federal_population_last_stream_tick_at_ms"
	] = int(
		Time.get_ticks_msec()
	)
	scenario_state [
		"presidential_parent_contract_federal_population_stream_running"
	] = next_cursor < jobs.size()
	scenario_state [
		"presidential_parent_contract_federal_population_external_stream_driver"
	] = false
	scenario_state [
		"presidential_parent_contract_federal_population_game_state_stream_driver"
	] = next_cursor < jobs.size()

	if (
		realm_engine != null
		and "realms" in realm_engine
		and typeof(
			realm_engine.realms
		) == TYPE_DICTIONARY
	):
		var realm_raw: Variant = (
			realm_engine.realms.get(
				us_realm_id,
				{}
			)
		)
		var realm: Dictionary = (
			realm_raw
			if typeof(
				realm_raw
			) == TYPE_DICTIONARY
			else {}
		)

		realm [
			"federal_cabinet_person_ids"
		] = cabinet_ids.duplicate(true)
		realm [
			"federal_senate_person_ids"
		] = senate_ids.duplicate(true)
		realm [
			"federal_supreme_court_person_ids"
		] = supreme_court_ids.duplicate(true)
		realm [
			"federal_governor_person_ids"
		] = governor_ids.duplicate(true)
		realm [
			"federal_citizen_person_ids"
		] = citizen_ids.duplicate(true)
		realm [
			"federal_republic_population_stream_cursor"
		] = next_cursor
		realm [
			"federal_republic_population_stream_total"
		] = jobs.size()
		realm [
			"federal_republic_population_streaming"
		] = next_cursor < jobs.size()
		realm [
			"federal_republic_population_stream_complete"
		] = next_cursor >= jobs.size()
		realm [
			"federal_republic_population_ui_is_renderer_only"
		] = true

		if next_cursor >= jobs.size():
			realm [
				"federal_republic_population_materialized"
			] = true
			realm [
				"federal_republic_population_complete"
			] = true
			realm [
				"federal_republic_population_materialized_as_fast_person_shells"
			] = true
			realm [
				"federal_republic_population_shell_bypassed_npc_factory"
			] = true
			realm [
				"federal_republic_population_materialized_at_ms"
			] = int(
				Time.get_ticks_msec()
			)

		realm_engine.realms [
			us_realm_id
		] = realm

	if (
		population_card_contract_engine != null
		and population_card_contract_engine.has_method(
			"mark_realm_dirty"
		)
	):
		population_card_contract_engine.mark_realm_dirty(
			us_realm_id,
			"presidential_parent_federal_population_stream_tick"
		)

	if next_cursor >= jobs.size():
		scenario_state [
			"presidential_parent_contract_federal_population_stream_running"
		] = false
		scenario_state [
			"presidential_parent_contract_federal_population_stream_complete"
		] = true
		scenario_state [
			"presidential_parent_contract_federal_population_materialized"
		] = true
		scenario_state [
			"presidential_parent_contract_federal_population_complete"
		] = true
		scenario_state [
			"presidential_parent_contract_federal_population_materialized_as_fast_person_shells"
		] = true
		scenario_state [
			"presidential_parent_contract_federal_population_shell_bypassed_npc_factory"
		] = true
		scenario_state [
			"presidential_parent_contract_federal_population_materialized_at_ms"
		] = int(
			Time.get_ticks_msec()
		)
		scenario_state [
			"presidential_parent_contract_federal_population_pending_after_player_control"
		] = false
		scenario_state [
			"presidential_parent_contract_federal_population_external_stream_driver"
		] = false
		scenario_state [
			"presidential_parent_contract_federal_population_game_state_stream_driver"
		] = false
		return

	var next_tick: Callable = Callable(
		self,
		"_presidential_parent_contract_materialize_federal_republic_population_stream_tick"
	).bind(
		us_realm_id,
		next_cursor
	)
	var main_loop = Engine.get_main_loop()

	if main_loop is SceneTree:
		var tree: SceneTree = (
			main_loop as SceneTree
		)

		if not tree.process_frame.is_connected(
			next_tick
		):
			tree.process_frame.connect(
				next_tick,
				CONNECT_ONE_SHOT
			)
	else:
		call_deferred(
			"_presidential_parent_contract_materialize_federal_republic_population_stream_tick",
			us_realm_id,
			next_cursor
		)
func _presidential_parent_contract_federal_world_seed_value() -> int:
	var world_seed: int = -1

	if typeof(scenario_state) == TYPE_DICTIONARY:
		world_seed = int(scenario_state.get("world_seed", -1))

		if world_seed <= 0 and typeof(scenario_state.get("seed_contract", {})) == TYPE_DICTIONARY:
			world_seed = int((scenario_state.get("seed_contract", {}) as Dictionary).get("seed", -1))

	if world_seed <= 0 and typeof(custom_settings) == TYPE_DICTIONARY:
		world_seed = int(custom_settings.get("world_seed", -1))

	if world_seed <= 0:
		world_seed = int(year)

	if world_seed <= 0:
		world_seed = 1

	return world_seed


func _presidential_parent_contract_federal_age_for_office(
	office: String,
	branch: String,
	state_name: String,
	realm_id: int,
	slot_index: int,
	min_age: int
) -> int:
	var clean_office: String = str(office).strip_edges()
	var clean_branch: String = str(branch).strip_edges().to_lower()
	var clean_state: String = str(state_name).strip_edges()
	var seed_value: int = _presidential_parent_contract_federal_world_seed_value()

	var seed_basis: String = "federal_office_age|%d|%d|%s|%s|%s|%d" % [
		seed_value,
		realm_id,
		clean_branch,
		clean_office,
		clean_state,
		slot_index
	]

	var rng:= RandomNumberGenerator.new()
	rng.seed = abs(int(seed_basis.hash())) % 2147483647
	if rng.seed <= 0:
		rng.seed = 1

	match clean_branch:
		"judicial":
			return int(rng.randi_range(32, 59))
		"senate":
			return int(rng.randi_range(maxi(30, min_age), 78))
		"state_governor":
			return int(rng.randi_range(maxi(30, min_age), 72))
		"cabinet":
			return int(rng.randi_range(maxi(32, min_age), 74))
		_:
			return int(rng.randi_range(maxi(18, min_age), 74))
func _presidential_parent_contract_elite_job_for_person(person: Person) -> String:
	if person == null:
		return "Executive"

	var jobs: Array = [
		"Corporate Executive",
		"Partner at a Law Firm",
		"Investment Banker",
		"Policy Strategist",
		"University Trustee",
		"Tech Founder",
		"Media Executive",
		"Real Estate Developer"
	]

	var index: int = abs(int(person.id)) % jobs.size()
	return str(jobs [index])
func _apply_custom_household_member_profile(person: Person, member: Dictionary, contract: Dictionary, is_anchor: bool) -> void:
	if person == null:
		return

	var location_raw: Variant = contract.get("location", {})
	var location: Dictionary = location_raw if typeof(location_raw) == TYPE_DICTIONARY else {}
	var era_raw: Variant = contract.get("era", {})
	var _era_data: Dictionary = era_raw if typeof(era_raw) == TYPE_DICTIONARY else {}
	var relationship_policy_raw: Variant = contract.get("relationship_policy", {})
	var relationship_policy: Dictionary = relationship_policy_raw if typeof(relationship_policy_raw) == TYPE_DICTIONARY else {}
	var generate_external_family: bool = bool(relationship_policy.get("generate_external_family", false))

	var first_name: String = str(member.get("first_name", person.first_name)).strip_edges()
	var last_name: String = str(member.get("last_name", person.last_name)).strip_edges()
	var gender_text: String = str(member.get("gender", person.gender)).strip_edges()
	var city: String = str(member.get("city", location.get("city", person.home_city))).strip_edges()
	var country: String = str(member.get("country", location.get("country", person.home_country))).strip_edges()

	if first_name != "":
		person.first_name = first_name
	if last_name != "":
		person.last_name = last_name
	if gender_text != "" and gender_text.to_lower() != "random":
		person.gender = gender_text

	person.name = ("%s %s" % [person.first_name, person.last_name]).strip_edges()
	person.age = int(clamp(int(member.get("age", person.age)), 0, MAX_MORTAL_AGE))
	person.birth_city = city
	person.birth_country = country
	person.home_city = city
	person.home_country = country
	person.social_class = str(member.get("social_class", contract.get("default_social_class", person.social_class))).strip_edges()
	person.bank_balance = int(member.get("money", person.bank_balance))
	person.job = str(member.get("job", person.job)).strip_edges()

	if not generate_external_family:
		person.parents = []
		person.children = []
		person.friends = []
		person.ex_partners = []
		person.partner = null
		person.marital_status = "Single"

	var stats_raw: Variant = member.get("stats", {})
	var stats: Dictionary = stats_raw if typeof(stats_raw) == TYPE_DICTIONARY else {}

	person.health = int(clamp(int(stats.get("health", person.health)), 0, 100))
	person.smarts = int(clamp(int(stats.get("smarts", person.smarts)), 0, 100))
	person.looks = int(clamp(int(stats.get("looks", person.looks)), 0, 100))
	person.imagination = int(clamp(int(stats.get("imagination", person.imagination)), 0, 100))
	person.mental_health = int(clamp(int(stats.get("mental_health", person.mental_health)), 0, 100))

	person.fame = int(clamp(int(member.get("reputation", person.fame)), 0, 100))
	person.fame_tier = _custom_household_fame_tier(person.fame)

	if person.job != "" and person.income <= 0:
		person.income = _custom_household_income_for_class(person.social_class)

	person.memories = _custom_household_strip_birth_identity_leaks(person.memories)

	var trauma: String = str(member.get("trauma", "")).strip_edges()
	if trauma != "":
		person.memories.append("Before this life became playable, I carried this history: %s" % trauma)

	person.memories.append("This life was already in motion before I took control.")
	person.memories.append("I existed before the player entered the household. My life did not begin at the start button.")

	if is_anchor:
		player = person
		player_id = int(person.id)
		if typeof(custom_settings) == TYPE_DICTIONARY:
			custom_settings ["first_name"] = person.first_name
			custom_settings ["last_name"] = person.last_name
			custom_settings ["gender"] = person.gender
			custom_settings ["age"] = person.age
			custom_settings ["starting_age"] = person.age
			custom_settings ["city"] = city
			custom_settings ["country"] = country
			custom_settings ["social_class"] = person.social_class
			custom_settings ["bank_balance"] = int(person.bank_balance)
			custom_settings ["birth_intro_cry_allowed"] = person.age == 0
			custom_settings ["suppress_birth_intro_for_existing_life"] = person.age > 0
			custom_settings ["starting_infinity_stones"] = 0
			custom_settings ["start_with_red_bonnet"] = false
			custom_settings ["health"] = person.health
			custom_settings ["smarts"] = person.smarts
			custom_settings ["looks"] = person.looks
			custom_settings ["imagination"] = person.imagination
			custom_settings ["mental_health"] = person.mental_health
			custom_settings ["job"] = person.job
func _custom_household_strip_birth_identity_leaks(raw_memories: Array) -> Array:
	var cleaned: Array = []
	for raw_memory in raw_memories:
		var text: String = str(raw_memory).strip_edges()
		if text == "":
			continue

		var lower_text: String = text.to_lower()
		if lower_text.begins_with("i was born "):
			continue
		if lower_text.begins_with("i was conceived "):
			continue
		if lower_text.begins_with("i was blessed to be born with "):
			continue
		if lower_text.find(" was born with ") != -1:
			continue
		if lower_text.begins_with("my father is "):
			continue
		if lower_text.begins_with("my mother is "):
			continue
		if lower_text.find("grandfather is ") != -1:
			continue
		if lower_text.find("grandmother is ") != -1:
			continue
		if lower_text.find("great-grandfather is ") != -1:
			continue
		if lower_text.find("great-grandmother is ") != -1:
			continue

		cleaned.append(text)

	return cleaned


func _wire_custom_household_relationships(anchor: Person, member_people: Dictionary, contract: Dictionary) -> void:
	if anchor == null:
		return

	var start_key: String = str(contract.get("start_person_key", "person_0")).strip_edges()
	var members_raw: Variant = contract.get("members", [])
	var members: Array = members_raw if typeof(members_raw) == TYPE_ARRAY else []

	for raw_member in members:
		if typeof(raw_member) != TYPE_DICTIONARY:
			continue

		var member: Dictionary = raw_member as Dictionary
		var local_key: String = str(member.get("local_key", "")).strip_edges()
		if local_key == "" or local_key == start_key:
			continue
		if not member_people.has(local_key):
			continue

		var other: Person = member_people [local_key]
		if other == null:
			continue

		var anchor_key: String = str(member.get("relationship_anchor_key", start_key)).strip_edges()
		if anchor_key == "":
			anchor_key = start_key

		var anchor_person: Person = anchor
		if member_people.has(anchor_key) and member_people [anchor_key] is Person:
			anchor_person = member_people [anchor_key]

		var relation: String = str(member.get("relationship_to_anchor", member.get("relationship_to_start", "none"))).strip_edges().to_lower()
		_link_custom_household_relationship(anchor_person, other, relation)

	var explicit_relationships_raw: Variant = contract.get("relationships", [])
	if typeof(explicit_relationships_raw) == TYPE_ARRAY:
		for raw_relationship in explicit_relationships_raw:
			if typeof(raw_relationship) != TYPE_DICTIONARY:
				continue

			var relationship: Dictionary = raw_relationship as Dictionary
			var a_key: String = str(relationship.get("a", "")).strip_edges()
			var b_key: String = str(relationship.get("b", "")).strip_edges()
			var kind: String = str(relationship.get("kind", "none")).strip_edges().to_lower()

			if not member_people.has(a_key) or not member_people.has(b_key):
				continue

			_link_custom_household_relationship(member_people [a_key], member_people [b_key], kind)


func _link_custom_household_relationship(anchor: Person, other: Person, relation: String) -> void:
	if anchor == null or other == null:
		return

	match relation:
		"mother", "father", "parent":
			_append_unique_person_id(anchor.parents, int(other.id))
			_append_unique_person_id(other.children, int(anchor.id))
			_set_mutual_affection(anchor, other, 76)
			other.memories.append("%s is my child." % anchor.first_name)
			anchor.memories.append("%s raised me before this life became playable." % other.first_name)

		"child", "son", "daughter":
			_append_unique_person_id(anchor.children, int(other.id))
			_append_unique_person_id(other.parents, int(anchor.id))
			_set_mutual_affection(anchor, other, 78)
			anchor.memories.append("%s is my child." % other.first_name)
			other.memories.append("%s raised me before this life became playable." % anchor.first_name)

		"brother", "sister", "sibling":
			for parent_id in anchor.parents:
				_append_unique_person_id(other.parents, int(parent_id))
				var parent: Person = get_npc_by_id(int(parent_id))
				if parent != null:
					_append_unique_person_id(parent.children, int(other.id))
			_set_mutual_affection(anchor, other, 66)
			anchor.memories.append("%s is my sibling." % other.first_name)
			other.memories.append("%s is my sibling." % anchor.first_name)

		"husband", "wife", "spouse":
			anchor.partner = other
			other.partner = anchor
			anchor.marital_status = "Married"
			other.marital_status = "Married"
			_set_mutual_affection(anchor, other, 82)
			anchor.memories.append("%s was already my spouse when this life became playable." % other.first_name)
			other.memories.append("%s was already my spouse when this life became playable." % anchor.first_name)

		"ex":
			_append_unique_person_id(anchor.ex_partners, int(other.id))
			_append_unique_person_id(other.ex_partners, int(anchor.id))
			if anchor.marital_status == "Single":
				anchor.marital_status = "Divorced"
			if other.marital_status == "Single":
				other.marital_status = "Divorced"
			_set_mutual_affection(anchor, other, 28)
			anchor.memories.append("%s and I have history before this life became playable." % other.first_name)
			other.memories.append("%s and I have history before this life became playable." % anchor.first_name)

		"roommate", "friend", "uncle", "aunt", "cousin", "grandparent":
			_append_unique_person_id(anchor.friends, int(other.id))
			_append_unique_person_id(other.friends, int(anchor.id))
			_set_mutual_affection(anchor, other, 58)
			anchor.memories.append("%s was already part of my household orbit: %s." % [other.first_name, relation])
			other.memories.append("%s was already part of my household orbit: %s." % [anchor.first_name, relation])

		_:
			_set_mutual_affection(anchor, other, 45)


func activate_custom_household_start(local_key: String) -> Dictionary:
	var clean_key: String = str(local_key).strip_edges()
	if clean_key == "":
		return {
			"success": false,
			"reason": "Missing household start key."
		}

	if typeof(scenario_state) != TYPE_DICTIONARY:
		scenario_state = {}

	var member_index_raw: Variant = scenario_state.get("custom_household_member_index", {})
	if typeof(member_index_raw) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "Household member index is missing."
		}

	var member_index: Dictionary = member_index_raw as Dictionary
	if not member_index.has(clean_key):
		return {
			"success": false,
			"reason": "That household member was not prewarmed."
		}

	var target_id: int = int(member_index.get(clean_key, 0))
	var target: Person = get_npc_by_id(target_id)
	if target == null:
		return {
			"success": false,
			"reason": "The selected household member could not be found."
		}

	player = target
	player_id = int(target.id)

	if has_method("register_controlled_character"):
		register_controlled_character(player_id)

	if typeof(custom_settings) != TYPE_DICTIONARY:
		custom_settings = {}

	custom_settings ["first_name"] = target.first_name
	custom_settings ["last_name"] = target.last_name
	custom_settings ["gender"] = target.gender
	custom_settings ["age"] = target.age
	custom_settings ["starting_age"] = target.age
	custom_settings ["city"] = target.home_city
	custom_settings ["country"] = target.home_country
	custom_settings ["social_class"] = target.social_class
	custom_settings ["bank_balance"] = int(target.bank_balance)
	custom_settings ["birth_intro_cry_allowed"] = target.age == 0 and not target.parents.is_empty()

	var contract: Dictionary = _custom_household_spawn_contract()
	if not contract.is_empty():
		contract ["start_person_key"] = clean_key
		custom_settings ["household_spawn_contract"] = contract.duplicate(true)
		scenario_state ["custom_household_spawn_contract"] = contract.duplicate(true)

	scenario_state ["custom_household_start_person_key"] = clean_key
	scenario_state ["custom_household_active_player_id"] = player_id
	scenario_state ["custom_household_start_activated"] = true
	scenario_state ["custom_household_start_activated_at_ms"] = int(Time.get_ticks_msec())

	return {
		"success": true,
		"player_id": player_id,
		"local_key": clean_key,
		"name": "%s %s" % [target.first_name, target.last_name],
		"birth_intro_cry_allowed": bool(custom_settings.get("birth_intro_cry_allowed", false))
	}


func _append_unique_person_id(array_ref: Array, person_id_value: int) -> void:
	if person_id_value <= 0:
		return
	if array_ref.has(person_id_value):
		return
	array_ref.append(person_id_value)


func _set_mutual_affection(a: Person, b: Person, score: int) -> void:
	if a == null or b == null:
		return
	a.affection [int(b.id)] = int(clamp(score, 0, 100))
	b.affection [int(a.id)] = int(clamp(score, 0, 100))


func _custom_household_fame_tier(value: int) -> String:
	if value >= 90:
		return "Legend"
	if value >= 70:
		return "Global"
	if value >= 50:
		return "National"
	if value >= 25:
		return "Local"
	return "None"


func _custom_household_income_for_class(class_text: String) -> int:
	var normalized: String = str(class_text).strip_edges().to_lower()
	match normalized:
		"royal":
			return 250000
		"noble":
			return 120000
		"wealthy":
			return 95000
		"middle class":
			return 52000
		"working class":
			return 32000
		"poor":
			return 12000
		_:
			return 25000
func _append_birth_shell_priority_soul_seed_target(out: Array, seen: Dictionary, person: Person) -> void:
	if person == null:
		return
	var id_key: String = str(int(person.id))
	if seen.has(id_key):
		return
	seen [id_key] = true
	out.append(person)


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _birth_shell_safe_person_id_array(person: Person, property_id: String) -> Array:
	var out: Array = []
	if person == null:
		return out

	var raw_value: Variant = person.get(property_id)
	if typeof(raw_value) != TYPE_ARRAY:
		return out

	for raw_id in raw_value:
		var resolved_id: int = int(raw_id)
		if resolved_id <= 0:
			continue
		if out.has(resolved_id):
			continue
		out.append(resolved_id)

	return out


func _birth_shell_safe_sibling_ids_for_person(person: Person) -> Array:
	var out: Array = []
	if person == null:
		return out

	var explicit_siblings: Array = _birth_shell_safe_person_id_array(person, "siblings")
	for raw_sibling_id in explicit_siblings:
		var sibling_id: int = int(raw_sibling_id)
		if sibling_id <= 0:
			continue
		if sibling_id == int(person.id):
			continue
		if out.has(sibling_id):
			continue
		out.append(sibling_id)

	if not out.is_empty():
		return out

	var person_parent_ids: Array = _birth_shell_safe_person_id_array(person, "parents")
	if person_parent_ids.is_empty():
		return out

	var parent_lookup: Dictionary = {}
	for raw_parent_id in person_parent_ids:
		var parent_id: int = int(raw_parent_id)
		if parent_id > 0:
			parent_lookup [str(parent_id)] = true

	if typeof(npcs) != TYPE_ARRAY:
		return out

	for raw_npc in npcs:
		if raw_npc == null or not (raw_npc is Person):
			continue

		var npc: Person = raw_npc as Person
		var npc_id: int = int(npc.id)
		if npc_id <= 0 or npc_id == int(person.id):
			continue

		var npc_parent_ids: Array = _birth_shell_safe_person_id_array(npc, "parents")
		for raw_npc_parent_id in npc_parent_ids:
			var npc_parent_id: int = int(raw_npc_parent_id)
			if npc_parent_id <= 0:
				continue
			if not parent_lookup.has(str(npc_parent_id)):
				continue
			if out.has(npc_id):
				continue
			out.append(npc_id)
			break

	return out


func _birth_shell_safe_sibling_ids_for_player() -> Array:
	return _birth_shell_safe_sibling_ids_for_person(player)
func _birth_shell_resolve_person_by_id(person_id: int) -> Person:
	if person_id <= 0:
		return null

	var resolved: Person = get_npc_by_id(person_id) if has_method("get_npc_by_id") else null
	if resolved == null and has_method("get_or_reactivate_npc_by_id"):
		resolved = get_or_reactivate_npc_by_id(person_id)

	return resolved


func _birth_shell_safe_ancestor_ids_for_person(person: Person, max_generations: int = 3) -> Array:
	var out: Array = []
	var seen: Dictionary = {}

	if person == null:
		return out

	var frontier: Array = _birth_shell_safe_person_id_array(person, "parents")
	var generation: int = 0

	while generation < max_generations and not frontier.is_empty():
		var next_frontier: Array = []

		for raw_person_id in frontier:
			var person_id: int = int(raw_person_id)
			if person_id <= 0:
				continue

			var id_key: String = str(person_id)
			if not seen.has(id_key):
				seen [id_key] = true
				out.append(person_id)

			var ancestor: Person = _birth_shell_resolve_person_by_id(person_id)
			if ancestor == null:
				continue

			for raw_parent_id in _birth_shell_safe_person_id_array(ancestor, "parents"):
				var parent_id: int = int(raw_parent_id)
				if parent_id <= 0:
					continue
				if next_frontier.has(parent_id):
					continue
				next_frontier.append(parent_id)

		frontier = next_frontier
		generation += 1

	return out


func _birth_shell_safe_aunt_uncle_ids_for_player() -> Array:
	var out: Array = []
	var seen: Dictionary = {}

	if player == null:
		return out

	for raw_parent_id in _birth_shell_safe_person_id_array(player, "parents"):
		var parent_id: int = int(raw_parent_id)
		if parent_id <= 0:
			continue

		var parent: Person = _birth_shell_resolve_person_by_id(parent_id)
		if parent == null:
			continue

		for raw_aunt_uncle_id in _birth_shell_safe_sibling_ids_for_person(parent):
			var aunt_uncle_id: int = int(raw_aunt_uncle_id)
			if aunt_uncle_id <= 0:
				continue

			var id_key: String = str(aunt_uncle_id)
			if seen.has(id_key):
				continue

			seen [id_key] = true
			out.append(aunt_uncle_id)

	return out

func _birth_shell_priority_soul_seed_targets() -> Array:
	var out: Array = []
	var seen: Dictionary = {}

	_append_birth_shell_priority_soul_seed_target(out, seen, player)

	if player != null:
		for raw_ancestor_id in _birth_shell_safe_ancestor_ids_for_person(player, 3):
			var ancestor_id: int = int(raw_ancestor_id)
			if ancestor_id <= 0:
				continue

			var ancestor: Person = _birth_shell_resolve_person_by_id(ancestor_id)
			_append_birth_shell_priority_soul_seed_target(out, seen, ancestor)

		for raw_sibling_id in _birth_shell_safe_sibling_ids_for_player():
			var sibling_id: int = int(raw_sibling_id)
			if sibling_id <= 0:
				continue

			var sibling: Person = _birth_shell_resolve_person_by_id(sibling_id)
			_append_birth_shell_priority_soul_seed_target(out, seen, sibling)

		for raw_aunt_uncle_id in _birth_shell_safe_aunt_uncle_ids_for_player():
			var aunt_uncle_id: int = int(raw_aunt_uncle_id)
			if aunt_uncle_id <= 0:
				continue

			var aunt_uncle: Person = _birth_shell_resolve_person_by_id(aunt_uncle_id)
			_append_birth_shell_priority_soul_seed_target(out, seen, aunt_uncle)

	if out.is_empty() and player != null:
		_append_birth_shell_priority_soul_seed_target(out, seen, player)

	return out
func _soul_seed_background_stream_gate(context: Dictionary = {}) -> Dictionary:
	if typeof(scenario_state) != TYPE_DICTIONARY:
		scenario_state = {}

	if bool(scenario_state.get("god_mode_life_prewarm_active", false)) and not bool(context.get("allow_during_god_mode_life_prewarm", false)):
		return {
			"allowed": false,
			"reason": "God Mode life prewarm is still active."
		}

	if not bool(scenario_state.get("soul_seed_distribution_authorized", false)):
		return {
			"allowed": false,
			"reason": "Soul seed distribution is not authorized yet."
		}

	var settings: Dictionary = custom_settings.duplicate(true) if typeof(custom_settings) == TYPE_DICTIONARY else {}
	var world_seed: int = int(scenario_state.get("world_seed", settings.get("world_seed", -1)))

	if world_seed <= 0:
		var seed_contract_raw: Variant = scenario_state.get("seed_contract", settings.get("seed_contract", {}))
		if typeof(seed_contract_raw) == TYPE_DICTIONARY:
			world_seed = int((seed_contract_raw as Dictionary).get("seed", -1))

	if world_seed <= 0:
		return {
			"allowed": false,
			"reason": "World seed is not committed yet."
		}

	return {
		"allowed": true,
		"world_seed": world_seed
	}
func start_background_soul_seed_streaming(context: Dictionary = {}) -> Dictionary:
	if typeof(scenario_state) != TYPE_DICTIONARY:
		scenario_state = {}

	if soul_seed_engine == null:
		return {
			"success": false,
			"active": false,
			"complete": false,
			"reason": "SoulSeedEngine unavailable."
		}

	var stream_gate: Dictionary = _soul_seed_background_stream_gate(context)
	if not bool(stream_gate.get("allowed", false)):
		return {
			"success": false,
			"active": false,
			"complete": false,
			"reason": str(stream_gate.get("reason", "Soul seed background stream is gated."))
		}

	var existing: Dictionary = _soul_seed_background_stream_state()
	if bool(existing.get("active", false)):
		return {
			"success": true,
			"active": true,
			"complete": bool(existing.get("complete", false)),
			"mode": "already_active",
			"queued_count": _safe_array_size(existing.get("queue", [])),
			"state": existing.duplicate(true)
		}

	var excluded_priority_ids: Dictionary = _birth_shell_priority_soul_seed_id_lookup()
	var queue: Array = _soul_seed_background_stream_build_queue(excluded_priority_ids)

	var state: Dictionary = {
		"schema": "eralife.soul_seed_background_stream",
		"version": 1,
		"active": true,
		"complete": false,
		"queue": queue,
		"excluded_priority_ids": excluded_priority_ids.duplicate(true),
		"assigned_count": 0,
		"skipped_count": 0,
		"idle_cycles": 0,
		"started_reason": str(context.get("reason", context.get("source", "background_soul_seed_stream"))),
		"started_at_year": year,
		"started_at_ms": int(Time.get_ticks_msec()),
		"last_tick_at_ms": 0
	}

	_commit_soul_seed_background_stream_state(state)

	scenario_state ["soul_seed_background_distribution_pending"] = true
	scenario_state ["soul_seed_background_stream_active"] = true
	scenario_state ["soul_seed_background_stream_started"] = true

	return {
		"success": true,
		"active": true,
		"complete": false,
		"mode": "started",
		"queued_count": queue.size(),
		"state": state.duplicate(true)
	}


func tick_background_soul_seed_stream(max_count: int = 2, context: Dictionary = {}) -> Dictionary:
	if typeof(scenario_state) != TYPE_DICTIONARY:
		scenario_state = {}

	if soul_seed_engine == null:
		return {
			"success": false,
			"active": false,
			"complete": false,
			"reason": "SoulSeedEngine unavailable."
		}

	var stream_gate: Dictionary = _soul_seed_background_stream_gate(context)
	if not bool(stream_gate.get("allowed", false)):
		return {
			"success": false,
			"active": false,
			"complete": false,
			"reason": str(stream_gate.get("reason", "Soul seed background stream is gated."))
		}

	var state: Dictionary = _soul_seed_background_stream_state()
	if state.is_empty() or not bool(state.get("active", false)):
		var start_report: Dictionary = start_background_soul_seed_streaming({
			"source": str(context.get("source", "tick_background_soul_seed_stream")),
			"reason": str(context.get("reason", "auto_start_from_tick"))
		})
		if not bool(start_report.get("success", false)):
			return start_report
		state = _soul_seed_background_stream_state()

	var excluded_priority_ids: Dictionary = _safe_dictionary(state.get("excluded_priority_ids", {}))
	var queue_raw: Variant = state.get("queue", [])
	var queue: Array = queue_raw if typeof(queue_raw) == TYPE_ARRAY else []
	if queue.is_empty():
		queue = _soul_seed_background_stream_build_queue(excluded_priority_ids)

	if queue.is_empty():
		var world_boot_finished: bool = bool(scenario_state.get("post_spawn_world_prewarm_complete", false)) or bool(scenario_state.get("static_world_runtime_bootstrapped", false))
		state ["queue"] = []
		state ["idle_cycles"] = int(state.get("idle_cycles", 0)) + 1
		state ["last_tick_at_ms"] = int(Time.get_ticks_msec())

		if world_boot_finished:
			state ["active"] = false
			state ["complete"] = true
			state ["completed_at_ms"] = int(Time.get_ticks_msec())
			scenario_state ["soul_seed_background_distribution_pending"] = false
			scenario_state ["soul_seed_background_stream_active"] = false
			scenario_state ["soul_seed_background_stream_complete"] = true
		else:
			state ["active"] = true
			state ["complete"] = false
			scenario_state ["soul_seed_background_distribution_pending"] = true
			scenario_state ["soul_seed_background_stream_active"] = true

		_commit_soul_seed_background_stream_state(state)

		return {
			"success": true,
			"active": bool(state.get("active", false)),
			"complete": bool(state.get("complete", false)),
			"mode": "complete" if bool(state.get("complete", false)) else "idle_waiting_for_world_population",
			"queued_count": 0,
			"assigned_this_tick": 0,
			"budget_exhausted": false,
			"frame_budget_ms": int(context.get("frame_budget_ms", 2)),
			"elapsed_ms": 0,
			"state": state.duplicate(true)
		}

	var max_per_tick: int = max(1, min(2, int(context.get("max_per_tick", max_count))))
	var target_count: int = max(1, min(max_per_tick, int(max_count)))
	var frame_budget_ms: int = max(1, min(8, int(context.get("frame_budget_ms", 2))))
	var started_ms: int = int(Time.get_ticks_msec())
	var max_attempts: int = (target_count * 4) + 4
	var attempts: int = 0
	var assigned: int = 0
	var skipped: int = 0
	var streamed_ids: Array = []
	var budget_exhausted: bool = false

	var settings: Dictionary = custom_settings.duplicate(true) if typeof(custom_settings) == TYPE_DICTIONARY else {}
	var world_seed: int = int(scenario_state.get("world_seed", settings.get("world_seed", -1)))
	var seed_contract: Dictionary = _safe_dictionary(scenario_state.get("seed_contract", settings.get("seed_contract", {})))
	var soul_seed_contract: Dictionary = _safe_dictionary(settings.get("soul_seed_contract", {}))

	while not queue.is_empty() and assigned < target_count and attempts < max_attempts:
		if attempts > 0 and int(Time.get_ticks_msec()) - started_ms >= frame_budget_ms:
			budget_exhausted = true
			break

		attempts += 1

		var raw_person_id: Variant = queue.pop_front()
		var person_id: int = int(raw_person_id)
		if person_id <= 0:
			skipped += 1
			continue

		var person: Person = get_npc_by_id(person_id) if has_method("get_npc_by_id") else null
		if person == null and has_method("get_or_reactivate_npc_by_id"):
			person = get_or_reactivate_npc_by_id(person_id)

		if person == null:
			skipped += 1
			continue

		if _soul_seed_person_has_seed(person):
			skipped += 1
			continue

		var soul_seed: Dictionary = soul_seed_engine.ensure_soul_seed(person, {
			"source": str(context.get("source", "game_state.background_soul_seed_stream")),
			"world_seed": world_seed,
			"seed_contract": seed_contract.duplicate(true),
			"soul_seed_contract": soul_seed_contract.duplicate(true),
			"player_id": player.id if player != null else player_id,
			"role": "npc",
			"stream_pass_index": int(context.get("pass_index", 0)),
			"frame_budget_ms": frame_budget_ms,
			"max_per_tick": target_count,
		})

		if soul_seed.is_empty():
			skipped += 1
			continue

		assigned += 1
		streamed_ids.append(person_id)

		if int(Time.get_ticks_msec()) - started_ms >= frame_budget_ms:
			budget_exhausted = true
			break

	state ["queue"] = queue
	state ["assigned_count"] = int(state.get("assigned_count", 0)) + assigned
	state ["skipped_count"] = int(state.get("skipped_count", 0)) + skipped
	state ["last_streamed_ids"] = streamed_ids
	state ["last_tick_at_ms"] = int(Time.get_ticks_msec())
	state ["last_tick_year"] = year
	state ["last_tick_frame_budget_ms"] = frame_budget_ms
	state ["last_tick_elapsed_ms"] = int(Time.get_ticks_msec()) - started_ms
	state ["last_tick_budget_exhausted"] = budget_exhausted
	state ["last_tick_max_per_tick"] = target_count

	var complete: bool = queue.is_empty() and (bool(scenario_state.get("post_spawn_world_prewarm_complete", false)) or bool(scenario_state.get("static_world_runtime_bootstrapped", false)))
	state ["active"] = not complete
	state ["complete"] = complete

	scenario_state ["soul_seed_background_distribution_pending"] = not complete
	scenario_state ["soul_seed_background_stream_active"] = not complete
	scenario_state ["soul_seed_background_stream_complete"] = complete
	scenario_state ["soul_seed_background_stream_assigned_count"] = int(state.get("assigned_count", 0))
	scenario_state ["soul_seed_background_stream_frame_budget_ms"] = frame_budget_ms
	scenario_state ["soul_seed_background_stream_last_elapsed_ms"] = int(Time.get_ticks_msec()) - started_ms
	scenario_state ["soul_seed_background_stream_budget_exhausted"] = budget_exhausted

	if complete:
		state ["completed_at_ms"] = int(Time.get_ticks_msec())

	_commit_soul_seed_background_stream_state(state)

	return {
		"success": true,
		"active": not complete,
		"complete": complete,
		"mode": "stream_tick",
		"assigned_this_tick": assigned,
		"skipped_this_tick": skipped,
		"queued_count": queue.size(),
		"streamed_ids": streamed_ids,
		"budget_exhausted": budget_exhausted,
		"frame_budget_ms": frame_budget_ms,
		"elapsed_ms": int(Time.get_ticks_msec()) - started_ms,
		"max_per_tick": target_count,
		"state": state.duplicate(true)
	}

func _birth_shell_priority_soul_seed_id_lookup() -> Dictionary:
	var out: Dictionary = {}
	for raw_person in _birth_shell_priority_soul_seed_targets():
		if raw_person == null or not (raw_person is Person):
			continue
		var person: Person = raw_person as Person
		var person_id: int = int(person.id)
		if person_id <= 0:
			continue
		out [str(person_id)] = true
	return out


func _soul_seed_background_stream_build_queue(excluded_priority_ids: Dictionary = {}) -> Array:
	var out: Array = []
	var seen: Dictionary = {}

	if typeof(npcs) != TYPE_ARRAY:
		return out

	for raw_npc in npcs:
		if raw_npc == null or not (raw_npc is Person):
			continue

		var npc: Person = raw_npc as Person
		var npc_id: int = int(npc.id)
		if npc_id <= 0:
			continue

		var id_key: String = str(npc_id)
		if seen.has(id_key):
			continue
		if excluded_priority_ids.has(id_key):
			continue
		if player != null and npc_id == int(player.id):
			continue
		if _soul_seed_person_has_seed(npc):
			continue

		seen [id_key] = true
		out.append(npc_id)

	return out


func _soul_seed_person_has_seed(person: Person) -> bool:
	if person == null:
		return false

	var raw_seed: Variant = person.get("soul_seed_contract")
	if typeof(raw_seed) != TYPE_DICTIONARY:
		return false

	return not (raw_seed as Dictionary).is_empty()


func _soul_seed_background_stream_state() -> Dictionary:
	if typeof(scenario_state) != TYPE_DICTIONARY:
		scenario_state = {}

	var raw_state: Variant = scenario_state.get("soul_seed_background_stream_state", {})
	if typeof(raw_state) == TYPE_DICTIONARY:
		return (raw_state as Dictionary).duplicate(true)

	return {}


func _commit_soul_seed_background_stream_state(state: Dictionary) -> void:
	if typeof(scenario_state) != TYPE_DICTIONARY:
		scenario_state = {}

	scenario_state ["soul_seed_background_stream_state"] = state.duplicate(true)


func _safe_array_size(value: Variant) -> int:
	if typeof(value) == TYPE_ARRAY:
		return (value as Array).size()
	return 0
func _birth_shell_deferred_boot_mode_key() -> String:
	var mode_key: String = str(reality_mode).strip_edges().to_lower()
	if mode_key == "":
		mode_key = REALITY_CHAOS

	if typeof(custom_settings) == TYPE_DICTIONARY:
		var label_key: String = str(custom_settings.get("reality_mode_label", "")).strip_edges().to_lower()
		if label_key == "custom":
			return "custom"

		var settings_mode: String = str(custom_settings.get("reality_mode", mode_key)).strip_edges().to_lower()
		if settings_mode != "":
			mode_key = settings_mode

	if mode_key == "fantasy":
		mode_key = REALITY_CHAOS

	if not [REALITY_REALISTIC, REALITY_ENHANCED, REALITY_CHAOS, "custom"].has(mode_key):
		mode_key = REALITY_CHAOS

	return mode_key


func _birth_shell_deferred_boot_stage_contracts() -> Array:
	return [
		{
			"id": "contract_boot",
			"weight": "light",
			"priority_by_mode": {
				"realistic": 10,
				"enhanced": 10,
				"chaos": 10,
				"custom": 10
			}
		},
		{
			"id": "external_eras",
			"weight": "light",
			"priority_by_mode": {
				"realistic": 20,
				"enhanced": 20,
				"chaos": 24,
				"custom": 24
			}
		},
		{
			"id": "asset_catalogs",
			"weight": "medium",
			"priority_by_mode": {
				"realistic": 30,
				"enhanced": 30,
				"chaos": 34,
				"custom": 34
			}
		},
		{
			"id": "mods",
			"weight": "medium",
			"priority_by_mode": {
				"realistic": 42,
				"enhanced": 40,
				"chaos": 38,
				"custom": 36
			}
		},
		{
			"id": "simulation_contracts",
			"weight": "light",
			"priority_by_mode": {
				"realistic": 48,
				"enhanced": 48,
				"chaos": 46,
				"custom": 44
			}
		},
		{
			"id": "event_bus_contracts",
			"weight": "light",
			"priority_by_mode": {
				"realistic": 52,
				"enhanced": 52,
				"chaos": 50,
				"custom": 48
			}
		},
		{
			"id": "weapon_packs",
			"weight": "medium",
			"priority_by_mode": {
				"realistic": 60,
				"enhanced": 58,
				"chaos": 66,
				"custom": 62
			}
		},
		{
			"id": "market_backfill",
			"weight": "medium",
			"priority_by_mode": {
				"realistic": 70,
				"enhanced": 92,
				"chaos": 112,
				"custom": 104
			}
		},
		{
			"id": "bending_population_backfill",
			"weight": "heavy",
			"feature": "bending",
			"priority_by_mode": {
				"realistic": 180,
				"enhanced": 72,
				"chaos": 124,
				"custom": 112
			}
		},
		{
			"id": "wizard_lineage_backfill",
			"weight": "heavy",
			"feature": "wizard_magic",
			"priority_by_mode": {
				"realistic": 190,
				"enhanced": 76,
				"chaos": 132,
				"custom": 120
			}
		},
		{
			"id": "spawn_world_assets",
			"weight": "heavy",
			"priority_by_mode": {
				"realistic": 82,
				"enhanced": 102,
				"chaos": 142,
				"custom": 128
			}
		},
		{
			"id": "power_population_backfill",
			"weight": "heavy",
			"feature": "superpowers",
			"priority_by_mode": {
				"realistic": 200,
				"enhanced": 196,
				"chaos": 150,
				"custom": 134
			}
		},
		{
			"id": "superhero_population_backfill",
			"weight": "heavy",
			"feature": "superpowers",
			"priority_by_mode": {
				"realistic": 204,
				"enhanced": 200,
				"chaos": 156,
				"custom": 140
			}
		},
		{
			"id": "realm_population_backfill",
			"weight": "heavy",
			"feature": "many_realms",
			"priority_by_mode": {
				"realistic": 210,
				"enhanced": 188,
				"chaos": 164,
				"custom": 150
			}
		},
		{
			"id": "artifact_seed_backfill",
			"weight": "heavy",
			"feature": "artifacts",
			"priority_by_mode": {
				"realistic": 220,
				"enhanced": 206,
				"chaos": 172,
				"custom": 158
			}
		},
		{
			"id": "realm_backfill",
			"weight": "heavy",
			"feature": "many_realms",
			"priority_by_mode": {
				"realistic": 230,
				"enhanced": 212,
				"chaos": 182,
				"custom": 168
			}
		},
		{
			"id": "runtime_watchers",
			"weight": "light",
			"priority_by_mode": {
				"realistic": 240,
				"enhanced": 240,
				"chaos": 240,
				"custom": 240
			}
		}
	]


func _birth_shell_deferred_boot_stage_contract_by_id(stage_id: String) -> Dictionary:
	var clean_stage_id: String = str(stage_id).strip_edges()
	if clean_stage_id == "":
		return {}

	for raw_stage in _birth_shell_deferred_boot_stage_contracts():
		if typeof(raw_stage) != TYPE_DICTIONARY:
			continue

		var stage: Dictionary = (raw_stage as Dictionary).duplicate(true)
		if str(stage.get("id", "")).strip_edges() == clean_stage_id:
			return stage

	return {
		"id": clean_stage_id,
		"weight": "medium",
		"priority_by_mode": {
			"realistic": 999,
			"enhanced": 999,
			"chaos": 999,
			"custom": 999
		}
	}


func _birth_shell_deferred_boot_stages_for_mode() -> Array:
	var mode_key: String = _birth_shell_deferred_boot_mode_key()
	var out: Array = []

	for raw_stage in _birth_shell_deferred_boot_stage_contracts():
		if typeof(raw_stage) != TYPE_DICTIONARY:
			continue

		var stage: Dictionary = _birth_shell_project_deferred_boot_stage_contract(raw_stage as Dictionary, mode_key)
		out.append(stage)

	out.sort_custom(Callable(self, "_sort_birth_shell_deferred_boot_stage_rows"))
	return out


func _sort_birth_shell_deferred_boot_stage_rows(a: Variant, b: Variant) -> bool:
	var row_a: Dictionary = a if typeof(a) == TYPE_DICTIONARY else {}
	var row_b: Dictionary = b if typeof(b) == TYPE_DICTIONARY else {}

	var priority_a: int = int(row_a.get("priority", 999))
	var priority_b: int = int(row_b.get("priority", 999))
	if priority_a == priority_b:
		return str(row_a.get("id", "")) < str(row_b.get("id", ""))

	return priority_a < priority_b


func _normalize_birth_shell_deferred_boot_stage(raw_stage: Variant) -> Dictionary:
	var mode_key: String = _birth_shell_deferred_boot_mode_key()

	if typeof(raw_stage) == TYPE_DICTIONARY:
		var out: Dictionary = (raw_stage as Dictionary).duplicate(true)
		if not out.has("id"):
			out ["id"] = str(out.get("stage", ""))
		if not out.has("weight"):
			out ["weight"] = "medium"
		return _birth_shell_project_deferred_boot_stage_contract(out, mode_key)

	return _birth_shell_project_deferred_boot_stage_contract(
		_birth_shell_deferred_boot_stage_contract_by_id(str(raw_stage)),
		mode_key
	)
func _birth_shell_deferred_boot_mode_value(stage: Dictionary, key: String, mode_key: String, fallback: Variant) -> Variant:
	var by_mode_key: String = "%s_by_mode" % key
	var by_mode_raw: Variant = stage.get(by_mode_key, {})
	if typeof(by_mode_raw) == TYPE_DICTIONARY:
		var by_mode: Dictionary = by_mode_raw as Dictionary
		if by_mode.has(mode_key):
			return by_mode.get(mode_key)
		if by_mode.has("default"):
			return by_mode.get("default")

	if stage.has(key):
		return stage.get(key)

	return fallback


func _birth_shell_runtime_boot_domain_for_stage(stage_id: String) -> String:
	var clean_stage: String = str(stage_id).strip_edges().to_lower()

	match clean_stage:
		"bending_population_backfill":
			return "bending"
		"power_population_backfill":
			return "powers"
		"superhero_population_backfill":
			return "superhero"
		"artifact_seed_backfill":
			return "artifacts"
		"wizard_lineage_backfill":
			return "magic"
		"realm_population_backfill", "realm_backfill":
			return "realms"
		"spawn_world_assets", "market_backfill", "weapon_packs":
			return "world"
		"contract_boot", "external_eras", "asset_catalogs", "mods", "simulation_contracts", "event_bus_contracts", "runtime_watchers":
			return "runtime"
		_:
			return "runtime"


func _birth_shell_default_visibility_state_for_stage(stage: Dictionary, mode_key: String) -> String:
	if not _birth_shell_deferred_boot_stage_feature_enabled(stage):
		return "hidden"

	var domain_id: String = str(stage.get("domain", _birth_shell_runtime_boot_domain_for_stage(str(stage.get("id", ""))))).strip_edges().to_lower()

	if mode_key == REALITY_REALISTIC and domain_id in ["bending", "powers", "superhero", "artifacts", "magic", "realms"]:
		return "hidden"

	if domain_id in ["bending", "powers", "superhero", "artifacts", "magic", "realms"]:
		return "partial"

	return "visible"


func _birth_shell_default_interaction_state_for_stage(stage: Dictionary, mode_key: String) -> String:
	var visibility_state: String = _birth_shell_default_visibility_state_for_stage(stage, mode_key)
	if visibility_state == "hidden":
		return "locked"

	var domain_id: String = str(stage.get("domain", _birth_shell_runtime_boot_domain_for_stage(str(stage.get("id", ""))))).strip_edges().to_lower()
	var weight: String = str(stage.get("weight", "medium")).strip_edges().to_lower()

	if domain_id in ["powers", "superhero", "artifacts", "bending", "magic", "realms"]:
		return "buffered"

	if weight in ["heavy", "very_heavy"]:
		return "buffered"

	return "live"


func _birth_shell_default_execution_state_for_stage(stage: Dictionary) -> String:
	if not _birth_shell_deferred_boot_stage_feature_enabled(stage):
		return "never"

	return "deferred"


func _birth_shell_project_deferred_boot_stage_contract(stage: Dictionary, mode_key: String) -> Dictionary:
	var out: Dictionary = stage.duplicate(true)
	var stage_id: String = str(out.get("id", out.get("stage", ""))).strip_edges()
	if stage_id == "":
		stage_id = "unknown_boot_stage"

	out ["id"] = stage_id
	out ["domain"] = str(out.get("domain", _birth_shell_runtime_boot_domain_for_stage(stage_id))).strip_edges().to_lower()
	out ["display_name"] = str(out.get("display_name", stage_id.replace("_", " ").capitalize()))
	out ["resolved_reality_mode"] = mode_key

	var priorities: Dictionary = {}
	var priorities_raw: Variant = out.get("priority_by_mode", {})
	if typeof(priorities_raw) == TYPE_DICTIONARY:
		priorities = (priorities_raw as Dictionary).duplicate(true)

	out ["priority"] = int(priorities.get(mode_key, priorities.get("chaos", priorities.get("default", 999))))
	out ["feature_enabled"] = _birth_shell_deferred_boot_stage_feature_enabled(out)

	var visibility_default: String = _birth_shell_default_visibility_state_for_stage(out, mode_key)
	var interaction_default: String = _birth_shell_default_interaction_state_for_stage(out, mode_key)
	var execution_default: String = _birth_shell_default_execution_state_for_stage(out)

	out ["visibility_state"] = str(_birth_shell_deferred_boot_mode_value(out, "visibility_state", mode_key, visibility_default)).strip_edges().to_lower()
	out ["interaction_state"] = str(_birth_shell_deferred_boot_mode_value(out, "interaction_state", mode_key, interaction_default)).strip_edges().to_lower()
	out ["execution_state"] = str(_birth_shell_deferred_boot_mode_value(out, "execution_state", mode_key, execution_default)).strip_edges().to_lower()

	if not bool(out.get("feature_enabled", true)):
		out ["visibility_state"] = "hidden"
		out ["interaction_state"] = "locked"
		out ["execution_state"] = "never"

	if not out.has("buffered_title"):
		out ["buffered_title"] = "Reality is still assembling."
	if not out.has("buffered_text"):
		out ["buffered_text"] = "This system is visible, but its simulation layer is still streaming in the background."

	return out


func _birth_shell_deferred_boot_stage_feature_enabled(stage: Dictionary) -> bool:
	var feature_id: String = str(stage.get("feature", "")).strip_edges()
	if feature_id == "":
		return true

	return is_feature_enabled(feature_id)


func _birth_shell_should_pause_deferred_stage(
	stage: Dictionary,
	runtime_owner: String
) -> bool:
	var owner: String = str(
		runtime_owner
	).strip_edges().to_lower()

	if owner.find("post_spawn") == -1:
		return false

	var weight: String = str(
		stage.get(
			"weight",
			"medium"
		)
	).strip_edges().to_lower()




	if owner.find("ui_safe") != -1:
		var intrinsically_bounded: bool = bool(
			stage.get(
				"intrinsically_bounded",
				false
			)
		)
		var max_quantum_ms: int = int(
			stage.get(
				"max_quantum_ms",
				0
			)
		)
		var bounded_for_interactive_residency: bool = (
			intrinsically_bounded
			and max_quantum_ms > 0
			and max_quantum_ms <= 1
		)

		if not bounded_for_interactive_residency:
			scenario_state [
				"birth_shell_ui_safe_deferred_stage"
			] = stage.duplicate(true)
			scenario_state [
				"birth_shell_ui_safe_deferred_stage_id"
			] = str(
				stage.get(
					"id",
					""
				)
			)
			scenario_state [
				"birth_shell_ui_safe_deferred_weight"
			] = weight
			scenario_state [
				"birth_shell_ui_safe_deferred_at_ms"
			] = int(Time.get_ticks_msec())
			scenario_state [
				"birth_shell_ui_safe_deferred_requires_intrinsic_bound"
			] = true
			scenario_state [
				"birth_shell_ui_safe_deferred_declared_intrinsically_bounded"
			] = intrinsically_bounded
			scenario_state [
				"birth_shell_ui_safe_deferred_declared_max_quantum_ms"
			] = max_quantum_ms

			var boot_state_raw: Variant = scenario_state.get(
				"_birth_shell_deferred_boot_state",
				{}
			)
			var boot_state: Dictionary = (
				boot_state_raw
				if typeof(boot_state_raw) == TYPE_DICTIONARY
				else {}
			)

			boot_state ["paused_stage"] = stage.duplicate(true)



			boot_state [
				"paused_reason"
			] = "post_spawn_ui_safe_weight_deferred"
			boot_state [
				"paused_requires_intrinsic_bound"
			] = true
			boot_state [
				"paused_at_ms"
			] = int(Time.get_ticks_msec())

			scenario_state [
				"_birth_shell_deferred_boot_state"
			] = boot_state

			return true

		return false

	if weight not in [
		"heavy",
		"very_heavy"
	]:
		return false

	var now_ms: int = int(Time.get_ticks_msec())
	var allowed_at_ms: int = int(
		scenario_state.get(
			"birth_shell_heavy_deferred_boot_allowed_at_ms",
			0
		)
	)

	if allowed_at_ms <= 0:
		allowed_at_ms = now_ms + 3500
		scenario_state [
			"birth_shell_heavy_deferred_boot_allowed_at_ms"
		] = allowed_at_ms

	if now_ms < allowed_at_ms:
		return true

	var last_heavy_ms: int = int(
		scenario_state.get(
			"birth_shell_last_heavy_deferred_boot_stage_ms",
			0
		)
	)

	if (
		last_heavy_ms > 0
		and now_ms - last_heavy_ms < 850
	):
		return true

	scenario_state [
		"birth_shell_last_heavy_deferred_boot_stage_ms"
	] = now_ms

	return false
func _continue_birth_shell_deferred_boot(max_stage_count: int = 1, _runtime_owner: String = "post_spawn_idle") -> bool:
	if typeof(scenario_state) != TYPE_DICTIONARY:
		scenario_state = {}
	if not bool(scenario_state.get("birth_shell_deferred_boot_pending", false)):
		return true

	var runtime_owner: String = str(_runtime_owner).strip_edges().to_lower()
	if runtime_owner.find("post_spawn") != -1:
		max_stage_count = 1
	else:
		max_stage_count = clamp(max_stage_count, 1, 3)

	var mode_key: String = _birth_shell_deferred_boot_mode_key()
	var boot_state: Dictionary = _birth_shell_deferred_boot_state_for_mode(mode_key)
	var stages_raw: Variant = boot_state.get("stages", [])
	var stages: Array = stages_raw if typeof(stages_raw) == TYPE_ARRAY else []
	var completed_raw: Variant = boot_state.get("completed_stage_ids", [])
	var completed_stage_ids: Array = completed_raw if typeof(completed_raw) == TYPE_ARRAY else []
	var skipped_raw: Variant = boot_state.get("skipped_stage_ids", [])
	var skipped_stage_ids: Array = skipped_raw if typeof(skipped_raw) == TYPE_ARRAY else []

	var processed: int = 0
	var paused_any_stage: bool = false

	while processed < max_stage_count:
		var selected_index: int = -1
		var selected_stage: Dictionary = {}

		for i in range(stages.size()):
			var stage: Dictionary = _normalize_birth_shell_deferred_boot_stage(stages [i])
			var stage_name: String = str(stage.get("id", "")).strip_edges()
			if stage_name == "":
				continue
			if completed_stage_ids.has(stage_name):
				continue
			if skipped_stage_ids.has(stage_name):
				continue

			if not _birth_shell_deferred_boot_stage_feature_enabled(stage):
				skipped_stage_ids.append(stage_name)
				scenario_state ["birth_shell_deferred_boot_last_skipped_stage"] = {
					"id": stage_name,
					"reason": "feature_disabled",
					"feature": str(stage.get("feature", "")),
					"mode": mode_key,
					"visibility_state": "hidden",
					"interaction_state": "locked",
					"execution_state": "never",
					"skipped_at_ms": int(Time.get_ticks_msec())
				}
				processed += 1
				continue

			if _birth_shell_should_pause_deferred_stage(stage, runtime_owner):
				paused_any_stage = true
				boot_state ["paused_stage"] = stage.duplicate(true)
				boot_state ["paused_reason"] = "post_spawn_ui_safe_weight_deferred" if runtime_owner.find("ui_safe") != -1 else "post_spawn_heavy_stage_throttle"
				boot_state ["paused_at_ms"] = int(Time.get_ticks_msec())
				boot_state ["completed_stage_ids"] = completed_stage_ids.duplicate(true)
				boot_state ["skipped_stage_ids"] = skipped_stage_ids.duplicate(true)
				boot_state ["cursor"] = _birth_shell_next_unresolved_deferred_boot_stage_index(stages, completed_stage_ids, skipped_stage_ids)
				boot_state ["mode"] = mode_key
				scenario_state ["_birth_shell_deferred_boot_state"] = boot_state
				break

			selected_index = i
			selected_stage = stage.duplicate(true)
			break

		if paused_any_stage:
			break

		if selected_index < 0 or selected_stage.is_empty():
			break

		var selected_stage_name: String = str(selected_stage.get("id", "")).strip_edges()
		boot_state ["active_stage_id"] = selected_stage_name
		boot_state ["active_stage"] = selected_stage.duplicate(true)
		boot_state ["active_stage_started_at_ms"] = int(Time.get_ticks_msec())
		boot_state ["last_scheduler_tick_ms"] = int(Time.get_ticks_msec())
		scenario_state ["_birth_shell_deferred_boot_state"] = boot_state

		_execute_birth_shell_deferred_boot_stage(selected_stage_name, mode_key, runtime_owner)

		if not completed_stage_ids.has(selected_stage_name):
			completed_stage_ids.append(selected_stage_name)

		scenario_state ["birth_shell_deferred_boot_last_stage"] = {
			"id": selected_stage_name,
			"mode": mode_key,
			"priority": int(selected_stage.get("priority", 999)),
			"weight": str(selected_stage.get("weight", "medium")),
			"domain": str(selected_stage.get("domain", "runtime")),
			"visibility_state": str(selected_stage.get("visibility_state", "visible")),
			"interaction_state": "live",
			"execution_state": "complete",
			"runtime_owner": runtime_owner,
			"completed_at_ms": int(Time.get_ticks_msec())
		}

		processed += 1
		boot_state ["completed_stage_ids"] = completed_stage_ids.duplicate(true)
		boot_state ["skipped_stage_ids"] = skipped_stage_ids.duplicate(true)
		boot_state ["cursor"] = _birth_shell_next_unresolved_deferred_boot_stage_index(stages, completed_stage_ids, skipped_stage_ids)
		boot_state ["mode"] = mode_key
		boot_state.erase("active_stage_id")
		boot_state.erase("active_stage")
		boot_state.erase("active_stage_started_at_ms")
		boot_state.erase("paused_stage")
		boot_state.erase("paused_reason")
		boot_state.erase("paused_at_ms")
		scenario_state ["_birth_shell_deferred_boot_state"] = boot_state

	var finished: bool = _birth_shell_deferred_boot_unresolved_stage_ids(stages, completed_stage_ids, skipped_stage_ids).is_empty()
	if finished:
		scenario_state ["birth_shell_deferred_boot_pending"] = false
		scenario_state ["birth_shell_deferred_boot_complete"] = true
		scenario_state ["deferred_data_bootstrap_pending"] = false
		scenario_state ["deferred_runtime_watchers_bootstrap"] = false
		scenario_state.erase("_birth_shell_deferred_boot_state")
		return true

	if paused_any_stage:
		boot_state ["paused_reason"] = str(boot_state.get("paused_reason", "waiting_for_scheduler_window"))
		if str(boot_state.get("paused_reason", "")).strip_edges() == "":
			boot_state ["paused_reason"] = "waiting_for_scheduler_window"
		boot_state ["paused_at_ms"] = int(Time.get_ticks_msec())
		boot_state ["completed_stage_ids"] = completed_stage_ids.duplicate(true)
		boot_state ["skipped_stage_ids"] = skipped_stage_ids.duplicate(true)
		boot_state ["cursor"] = _birth_shell_next_unresolved_deferred_boot_stage_index(stages, completed_stage_ids, skipped_stage_ids)
		boot_state ["mode"] = mode_key
		scenario_state ["_birth_shell_deferred_boot_state"] = boot_state
		return false

	return false
func _birth_shell_deferred_boot_state_for_mode(mode_key: String) -> Dictionary:
	if typeof(scenario_state) != TYPE_DICTIONARY:
		scenario_state = {}

	var boot_state_raw: Variant = scenario_state.get("_birth_shell_deferred_boot_state", {})
	var boot_state: Dictionary = boot_state_raw if typeof(boot_state_raw) == TYPE_DICTIONARY else {}
	var needs_rebuild: bool = boot_state.is_empty()

	if not needs_rebuild and str(boot_state.get("mode", "")).strip_edges().to_lower() != mode_key and int(boot_state.get("cursor", 0)) <= 0:
		needs_rebuild = true

	if needs_rebuild:
		boot_state = {
			"schema": "eralife.contract_driven_runtime_boot_scheduler",
			"version": 1,
			"cursor": 0,
			"mode": mode_key,
			"stages": _birth_shell_deferred_boot_stages_for_mode(),
			"completed_stage_ids": [],
			"skipped_stage_ids": [],
			"active_stage_id": "",
			"created_at_ms": int(Time.get_ticks_msec()),
			"last_scheduler_tick_ms": int(Time.get_ticks_msec())
		}
	else:
		if typeof(boot_state.get("stages", [])) != TYPE_ARRAY or (boot_state.get("stages", []) as Array).is_empty():
			boot_state ["stages"] = _birth_shell_deferred_boot_stages_for_mode()

		if typeof(boot_state.get("completed_stage_ids", [])) != TYPE_ARRAY:
			boot_state ["completed_stage_ids"] = _birth_shell_legacy_completed_stage_ids_from_cursor(
				boot_state.get("stages", []),
				int(boot_state.get("cursor", 0))
			)

		if typeof(boot_state.get("skipped_stage_ids", [])) != TYPE_ARRAY:
			boot_state ["skipped_stage_ids"] = []

		boot_state ["schema"] = str(boot_state.get("schema", "eralife.contract_driven_runtime_boot_scheduler"))
		boot_state ["version"] = max(1, int(boot_state.get("version", 1)))
		boot_state ["mode"] = mode_key
		boot_state ["last_scheduler_tick_ms"] = int(Time.get_ticks_msec())

	scenario_state ["_birth_shell_deferred_boot_state"] = boot_state
	return boot_state


func _birth_shell_legacy_completed_stage_ids_from_cursor(stages_value: Variant, cursor: int) -> Array:
	var out: Array = []
	var stages: Array = stages_value if typeof(stages_value) == TYPE_ARRAY else []
	var limit: int = clamp(cursor, 0, stages.size())

	for i in range(limit):
		var stage: Dictionary = _normalize_birth_shell_deferred_boot_stage(stages [i])
		var stage_id: String = str(stage.get("id", "")).strip_edges()
		if stage_id != "" and not out.has(stage_id):
			out.append(stage_id)

	return out


func _birth_shell_deferred_boot_unresolved_stage_ids(stages: Array, completed_stage_ids: Array, skipped_stage_ids: Array) -> Array:
	var out: Array = []

	for raw_stage in stages:
		var stage: Dictionary = _normalize_birth_shell_deferred_boot_stage(raw_stage)
		var stage_id: String = str(stage.get("id", "")).strip_edges()
		if stage_id == "":
			continue
		if completed_stage_ids.has(stage_id):
			continue
		if skipped_stage_ids.has(stage_id):
			continue
		out.append(stage_id)

	return out


func _birth_shell_next_unresolved_deferred_boot_stage_index(stages: Array, completed_stage_ids: Array, skipped_stage_ids: Array) -> int:
	for i in range(stages.size()):
		var stage: Dictionary = _normalize_birth_shell_deferred_boot_stage(stages [i])
		var stage_id: String = str(stage.get("id", "")).strip_edges()
		if stage_id == "":
			continue
		if completed_stage_ids.has(stage_id):
			continue
		if skipped_stage_ids.has(stage_id):
			continue
		return i

	return stages.size()


func _execute_birth_shell_deferred_boot_stage(stage_name: String, mode_key: String, runtime_owner: String) -> Dictionary:
	match stage_name:
		"contract_boot":
			if game_state_contract_engine == null:
				game_state_contract_engine = GameStateContractEngine.new(self)

			var game_state_boot_report: Dictionary = game_state_contract_engine.bootstrap_kernel_contract({
				"phase": "birth_shell_deferred_contract_boot",
				"allow_external_contracts": true,
				"reality_mode": mode_key,
				"runtime_owner": runtime_owner
			})
			scenario_state ["game_state_contract_last_boot_report"] = game_state_boot_report.duplicate(true)

			contract_meta_governor = game_state_contract_engine.contract_meta_governor
			scenario_state ["contract_meta_governor_report"] = game_state_contract_engine.apply_contract_meta_governor({
				"phase": "birth_shell_deferred_contract_boot",
				"include_runtime": false,
				"reality_mode": mode_key,
				"runtime_owner": runtime_owner
			}).duplicate(true)

		"external_eras":
			if era_data_loader == null:
				era_data_loader = EraDataLoader.new(self)
			if not external_era_data_loaded:
				era_data_loader.load_external_eras()
			external_era_data_loaded = true

		"asset_catalogs":
			if era_data_loader == null:
				era_data_loader = EraDataLoader.new(self)
			if not asset_catalogs_loaded:
				era_data_loader.load_asset_catalogs()
			asset_catalogs_loaded = true

		"weapon_packs":
			if weapon_pack_loader == null:
				weapon_pack_loader = WeaponPackLoader.new(self)
			if not weapon_packs_loaded:
				weapon_pack_loader.load_weapon_packs()
			weapon_packs_loaded = true

		"mods":
			var caveman_runtime_created: bool = false
			var mod_bundle_created: bool = false
			var era_mod_created: bool = false
			var era_contract_created: bool = false

			if mod_loader == null:
				mod_loader = ModLoader.new(self)

			if mod_contract_engine == null:
				mod_contract_engine = ModContractEngine.new(self)

			if caveman_reality_runtime_engine == null:
				caveman_reality_runtime_engine = (
					CavemanRealityRuntimeEngine.new(self)
				)
				caveman_runtime_created = true

			if mod_bundle_contract_engine == null:
				mod_bundle_contract_engine = (
					ModBundleContractEngine.new(self)
				)
				mod_bundle_created = true

			if mod_marketplace_contract_engine == null:
				mod_marketplace_contract_engine = (
					ModMarketplaceContractEngine.new(self)
				)

			if mod_hub_contract_engine == null:
				mod_hub_contract_engine = (
					ModHubContractEngine.new(self)
				)

			if mod_menu_contract_engine == null:
				mod_menu_contract_engine = (
					ModMenuContractEngine.new(self)
				)

			if era_mod_contract_engine == null:
				era_mod_contract_engine = (
					EraModContractEngine.new(self)
				)
				era_mod_created = true

			if era_contract_engine == null:
				era_contract_engine = (
					EraContractEngine.new(self)
				)
				era_contract_created = true

			if caveman_runtime_created:
				caveman_reality_runtime_engine.bootstrap_default_contracts()

			if mod_bundle_created:
				mod_bundle_contract_engine.bootstrap_default_contracts()

			if era_mod_created:
				era_mod_contract_engine.bootstrap_default_contracts()

			if era_contract_created:
				era_contract_engine.bootstrap_default_contracts()

			if not mods_loaded:
				var mod_ingestion_report: Dictionary = (
					mod_loader.load_mods({
						"hot_apply": false,
						"source": (
							"birth_shell_deferred_boot_ingestion"
						),
						"reality_mode": mode_key,
						"runtime_owner": runtime_owner
					})
				)
				var mod_platform_report: Dictionary = (
					mod_contract_engine.bootstrap_from_loader({
						"apply_runtime": true,
						"source": (
							"birth_shell_deferred_mod_platform"
						),
						"reality_mode": mode_key,
						"runtime_owner": runtime_owner
					})
				)

				mod_contract_registry = (
					mod_contract_engine.export_registry()
				)
				mod_provider_registry = (
					mod_contract_engine
					.provider_resolution_registry
					.duplicate(true)
				)
				mod_conflict_registry = (
					mod_contract_engine
					.provider_conflict_registry
					.duplicate(true)
				)
				mod_contract_runtime_report = {
					"schema": (
						"eralife.mod_platform_runtime_report"
					),
					"version": 1,
					"ingestion": (
						mod_ingestion_report.duplicate(true)
					),
					"platform": (
						mod_platform_report.duplicate(true)
					),
					"source": "birth_shell_deferred_boot",
					"booted_at_ms": int(
						Time.get_ticks_msec()
					)
				}
				scenario_state [
					"mod_contract_last_load_report"
				] = mod_contract_runtime_report.duplicate(true)
				mods_loaded = bool(
					mod_platform_report.get(
						"success",
						false
					)
				)

			if era_mod_contract_engine != null:
				era_mod_contract_engine.rebuild_provider_cache({
					"source": (
						"birth_shell_deferred_mod_platform"
					)
				})

			if era_contract_engine != null:
				era_contract_engine.reconcile_effective_reality({
					"source": (
						"birth_shell_deferred_mod_platform"
					)
				})

		"simulation_contracts":
			if simulation_contract_engine != null and simulation_contract_engine.has_method("load_external_packs"):
				simulation_contract_engine.load_external_packs()

		"event_bus_contracts":
			if event_bus == null:
				event_bus = EventBus.new(self)
				event_bus_contract_layer = event_bus.contract_layer

			if game_state_contract_engine != null:
				var event_bus_contract_runtime_report: Dictionary = game_state_contract_engine.apply_event_bus_contracts(event_bus)
				scenario_state ["event_bus_contract_layer_report"] = event_bus_contract_runtime_report.duplicate(true)

				var contract_subscription_report: Dictionary = game_state_contract_engine.apply_event_subscriptions(event_bus)
				scenario_state ["game_state_contract_event_subscription_report"] = contract_subscription_report.duplicate(true)

		"spawn_world_assets":
			if npc_factory != null:
				npc_factory.seed_spawn_world_assets(npcs)

		"bending_population_backfill":
			if bending_engine != null and bending_engine.has_method("bootstrap_spawn_bending_population"):
				bending_engine.bootstrap_spawn_bending_population(npcs)

		"power_population_backfill":
			if power_engine != null and power_engine.has_method("bootstrap_spawn_power_population"):
				power_engine.bootstrap_spawn_power_population(npcs)

		"superhero_population_backfill":
			if superhero_engine != null and superhero_engine.has_method("bootstrap_world_supers"):
				superhero_engine.bootstrap_world_supers(npcs)

		"wizard_lineage_backfill":
			if wizard_engine != null and wizard_engine.has_method("bootstrap_wizard_lineages"):
				wizard_engine.bootstrap_wizard_lineages(npcs)

		"realm_population_backfill":
			if realm_engine != null and realm_engine.has_method("audit_bootstrap_elemental_realm_population"):
				realm_engine.audit_bootstrap_elemental_realm_population()

		"artifact_seed_backfill":
			if is_feature_enabled("artifacts") and artifacts_engine != null:
				artifacts_engine.spawn_initial_artifacts()

		"market_backfill":
			if global_market_engine != null:
				global_market_engine._ensure_bootstrapped()

		"realm_backfill":
			if realm_engine != null:
				realm_engine.bootstrap_realms_for_era()

		"runtime_watchers":
			if live_diagnostics_engine != null:
				live_diagnostics_engine.bootstrap_runtime_watchers()
			scenario_state ["deferred_runtime_watchers_bootstrap"] = false

		_:
			pass

	return {
		"success": true,
		"stage_id": stage_name,
		"mode": mode_key,
		"runtime_owner": runtime_owner,
		"completed_at_ms": int(Time.get_ticks_msec())
	}
func ensure_causality_inversion_engine() -> bool:
	if causality_inversion_engine == null:
		causality_inversion_engine = CausalityInversionEngine.new(self)
		if causality_inversion_engine != null:
			causality_inversion_engine.bootstrap_default_contracts()
	return causality_inversion_engine != null


func build_local_shell_causality_packet(actor: Person, intent: Dictionary, context: Dictionary = {}) -> Dictionary:
	if not ensure_causality_inversion_engine():
		return {
			"success": false,
			"reason": "CausalityInversionEngine unavailable."
		}

	return causality_inversion_engine.build_local_shell_packet(actor, intent, context)


func resolve_causality_inverted_intent(actor: Person, intent: Dictionary, context: Dictionary = {}) -> Dictionary:
	if not ensure_causality_inversion_engine():
		return {
			"success": false,
			"reason": "CausalityInversionEngine unavailable."
		}

	var forwarded_context: Dictionary = context.duplicate(true)
	forwarded_context ["source"] = str(forwarded_context.get("source", intent.get("source", "game_state")))
	forwarded_context ["remote_truth_layer"] = bool(forwarded_context.get("remote_truth_layer", false))

	var report: Dictionary = causality_inversion_engine.resolve_inverted_intent(actor, intent, forwarded_context)

	if typeof(scenario_state) != TYPE_DICTIONARY:
		scenario_state = {}

	scenario_state ["last_causality_inversion_report"] = report.duplicate(true)

	if reality_orchestrator != null and reality_orchestrator.has_method("orchestrate_intent"):
		var orchestration_report: Dictionary = reality_orchestrator.orchestrate_intent({
			"id": "causality.inversion.%s" % str(report.get("action_id", "runtime.intent")),
			"domain": "runtime",
			"authority": "reality",
			"event_payload": report.duplicate(true),
			"effects": [
				"stream_runtime",
				"ui_manifestation",
				"historical_storage",
				"stability_guard"
			],
			"composition_stack": [
				"local_shell",
				"intent_pressure_system",
				"contract_driven_runtime_boot_scheduler",
				"causality_inversion_engine",
				"causal_justification_engine",
				"reality_identity_anchoring_system",
				"self_host_runtime_layer",
				"ui_manifestation",
				"historical_storage"
			]
		}, {
			"source": "resolve_causality_inverted_intent",
			"domain": "runtime",
			"authority": "reality"
		})
		report ["orchestration"] = orchestration_report.duplicate(true)

	return report
func get_runtime_boot_scheduler_snapshot() -> Dictionary:
	if typeof(scenario_state) != TYPE_DICTIONARY:
		scenario_state = {}

	var save_load_snapshot: Dictionary = _save_load_runtime_scheduler_snapshot()
	if bool(save_load_snapshot.get("pending", false)):
		return save_load_snapshot

	var pending: bool = bool(scenario_state.get("birth_shell_deferred_boot_pending", false))
	if not pending:
		return {
			"schema": "eralife.contract_driven_runtime_boot_scheduler_snapshot",
			"version": 1,
			"pending": false,
			"complete": bool(scenario_state.get("birth_shell_deferred_boot_complete", false)),
			"mode": _birth_shell_deferred_boot_mode_key(),
			"stages": [],
			"domain_states": {},
			"pending_intent_count": _runtime_boot_buffered_intent_count(),
			"created_at_ms": int(Time.get_ticks_msec())
		}

	var mode_key: String = _birth_shell_deferred_boot_mode_key()
	var boot_state: Dictionary = _birth_shell_deferred_boot_state_for_mode(mode_key)
	var stages_raw: Variant = boot_state.get("stages", [])
	var stages: Array = stages_raw if typeof(stages_raw) == TYPE_ARRAY else []

	var completed_raw: Variant = boot_state.get("completed_stage_ids", [])
	var completed_stage_ids: Array = completed_raw if typeof(completed_raw) == TYPE_ARRAY else []

	var skipped_raw: Variant = boot_state.get("skipped_stage_ids", [])
	var skipped_stage_ids: Array = skipped_raw if typeof(skipped_raw) == TYPE_ARRAY else []

	var active_stage_id: String = str(boot_state.get("active_stage_id", "")).strip_edges()
	var stage_snapshots: Array = []
	var domain_states: Dictionary = {}

	for raw_stage in stages:
		var projected_stage: Dictionary = _birth_shell_runtime_boot_stage_snapshot(
			_normalize_birth_shell_deferred_boot_stage(raw_stage),
			completed_stage_ids,
			skipped_stage_ids,
			active_stage_id
		)

		stage_snapshots.append(projected_stage.duplicate(true))

		var domain_id: String = str(projected_stage.get("domain", "runtime")).strip_edges().to_lower()
		if domain_id == "":
			domain_id = "runtime"

		var current_domain: Dictionary = domain_states.get(domain_id, {}) if typeof(domain_states.get(domain_id, {})) == TYPE_DICTIONARY else {}
		domain_states [domain_id] = _birth_shell_merge_runtime_boot_domain_state(current_domain, projected_stage)

	return {
		"schema": "eralife.contract_driven_runtime_boot_scheduler_snapshot",
		"version": 1,
		"pending": true,
		"complete": false,
		"mode": mode_key,
		"stages": stage_snapshots,
		"domain_states": domain_states,
		"active_stage_id": active_stage_id,
		"cursor": int(boot_state.get("cursor", 0)),
		"pending_intent_count": _runtime_boot_buffered_intent_count(),
		"created_at_ms": int(Time.get_ticks_msec())
	}
func begin_save_load_runtime_scheduler(context: Dictionary = {}) -> Dictionary:
	if typeof(scenario_state) != TYPE_DICTIONARY:
		scenario_state = {}

	var label: String = str(context.get("label", "Saved Life")).strip_edges()
	if label == "":
		label = "Saved Life"

	var domain_states: Dictionary = {
		"identity": {
			"domain": "identity",
			"visibility_state": "visible",
			"interaction_state": "buffered",
			"execution_state": "streaming",
			"player_status_text": "Finding the saved soul anchor."
		},
		"family": {
			"domain": "family",
			"visibility_state": "partial",
			"interaction_state": "buffered",
			"execution_state": "deferred",
			"player_status_text": "Immediate family is being reconstructed first."
		},
		"ui": {
			"domain": "ui",
			"visibility_state": "visible",
			"interaction_state": "buffered",
			"execution_state": "streaming",
			"player_status_text": "The live UI shell is preparing."
		},
		"world": {
			"domain": "world",
			"visibility_state": "partial",
			"interaction_state": "buffered",
			"execution_state": "deferred",
			"player_status_text": "The wider world will stream after the playable shell is live."
		},
		"runtime": {
			"domain": "runtime",
			"visibility_state": "visible",
			"interaction_state": "buffered",
			"execution_state": "streaming",
			"player_status_text": "Runtime contracts are binding the saved life."
		},
		"powers": _save_load_optional_domain_state("powers", "Power systems are syncing from the saved timeline."),
		"superhero": _save_load_optional_domain_state("superhero", "City hero/villain systems are syncing from the saved timeline."),
		"artifacts": _save_load_optional_domain_state("artifacts", "Artifact ownership and timeline echoes are syncing."),
		"bending": _save_load_optional_domain_state("bending", "Bending records and combat systems are syncing."),
		"magic": _save_load_optional_domain_state("magic", "Magic lineage systems are syncing."),
		"realms": _save_load_optional_domain_state("realms", "Realm surfaces are syncing.")
	}

	var scheduler: Dictionary = {
		"schema": "eralife.contract_driven_runtime_boot_scheduler_snapshot",
		"version": 1,
		"source": "save_load_runtime_scheduler",
		"pending": true,
		"complete": false,
		"mode": _birth_shell_deferred_boot_mode_key(),
		"profile": str(context.get("profile", "live_saved_life_shell")),
		"label": label,
		"path": str(context.get("path", "")),
		"entry_surface": str(context.get("entry_surface", "saved_life_picker")),
		"stages": [],
		"domain_states": domain_states,
		"active_stage_id": "save_load_identity_shell",
		"pending_intent_count": _runtime_boot_buffered_intent_count(),
		"created_at_ms": int(Time.get_ticks_msec()),
		"updated_at_ms": int(Time.get_ticks_msec())
	}

	scenario_state ["save_load_runtime_scheduler"] = scheduler.duplicate(true)
	scenario_state ["save_load_runtime_scheduler_active"] = true
	scenario_state ["background_hydration_active"] = true

	return scheduler.duplicate(true)


func update_save_load_runtime_scheduler_from_report(report: Dictionary = {}) -> Dictionary:
	if typeof(scenario_state) != TYPE_DICTIONARY:
		scenario_state = {}

	var scheduler_raw: Variant = scenario_state.get("save_load_runtime_scheduler", {})
	var scheduler: Dictionary = scheduler_raw if typeof(scheduler_raw) == TYPE_DICTIONARY else {}

	if scheduler.is_empty():
		scheduler = begin_save_load_runtime_scheduler({
			"label": str(report.get("saved_life_label", "Saved Life")),
			"path": str(report.get("path", "")),
			"profile": str(report.get("profile", "live_saved_life_shell")),
			"entry_surface": str(report.get("entry_surface", "saved_life_picker"))
		})

	var domain_states: Dictionary = scheduler.get("domain_states", {}) if typeof(scheduler.get("domain_states", {})) == TYPE_DICTIONARY else {}

	domain_states ["identity"] = _save_load_live_domain_state("identity", "Saved identity is live.")
	domain_states ["family"] = _save_load_live_domain_state("family", "Immediate family shell is live.")
	domain_states ["ui"] = _save_load_live_domain_state("ui", "The UI is live.")
	domain_states ["runtime"] = _save_load_live_domain_state("runtime", "Runtime contracts are live.")

	var background_active: bool = bool(report.get("background_active", false))
	if background_active:
		domain_states ["world"] = {
			"domain": "world",
			"visibility_state": "partial",
			"interaction_state": "buffered",
			"execution_state": "streaming",
			"player_status_text": "Reality is playable. The wider world is still streaming."
		}

		for domain_id in ["powers", "superhero", "artifacts", "bending", "magic", "realms"]:
			if typeof(domain_states.get(domain_id, {})) == TYPE_DICTIONARY:
				var row: Dictionary = domain_states.get(domain_id, {}).duplicate(true)
				if str(row.get("execution_state", "deferred")) != "never":
					row ["visibility_state"] = "partial"
					row ["interaction_state"] = "buffered"
					row ["execution_state"] = "streaming"
					domain_states [domain_id] = row
	else:
		domain_states ["world"] = _save_load_live_domain_state("world", "World hydration is complete.")
		for domain_id in ["powers", "superhero", "artifacts", "bending", "magic", "realms"]:
			if typeof(domain_states.get(domain_id, {})) == TYPE_DICTIONARY:
				var optional_row: Dictionary = domain_states.get(domain_id, {}).duplicate(true)
				if str(optional_row.get("execution_state", "deferred")) != "never":
					optional_row ["visibility_state"] = "visible"
					optional_row ["interaction_state"] = "live"
					optional_row ["execution_state"] = "complete"
					domain_states [domain_id] = optional_row

	scheduler ["domain_states"] = domain_states
	scheduler ["pending"] = background_active
	scheduler ["complete"] = not background_active
	scheduler ["active_stage_id"] = "save_load_background_world" if background_active else ""
	scheduler ["background_queue_size"] = int(report.get("background_queue_size", 0))
	scheduler ["pending_intent_count"] = _runtime_boot_buffered_intent_count()
	scheduler ["updated_at_ms"] = int(Time.get_ticks_msec())

	scenario_state ["save_load_runtime_scheduler"] = scheduler.duplicate(true)
	scenario_state ["save_load_runtime_scheduler_active"] = background_active
	scenario_state ["background_hydration_active"] = background_active
	scenario_state ["background_hydration_queue_size"] = int(report.get("background_queue_size", 0))

	return scheduler.duplicate(true)


func complete_save_load_runtime_scheduler(slice_report: Dictionary = {}) -> Dictionary:
	if typeof(scenario_state) != TYPE_DICTIONARY:
		scenario_state = {}

	var scheduler_raw: Variant = scenario_state.get("save_load_runtime_scheduler", {})
	var scheduler: Dictionary = scheduler_raw if typeof(scheduler_raw) == TYPE_DICTIONARY else {}

	if scheduler.is_empty():
		return {
			"success": true,
			"complete": true,
			"reason": "no_save_load_scheduler_active"
		}

	var domain_states: Dictionary = scheduler.get("domain_states", {}) if typeof(scheduler.get("domain_states", {})) == TYPE_DICTIONARY else {}
	for raw_domain in domain_states.keys():
		var domain_id: String = str(raw_domain)
		var row: Dictionary = domain_states.get(raw_domain, {}) if typeof(domain_states.get(raw_domain, {})) == TYPE_DICTIONARY else {}
		if row.is_empty():
			continue
		if str(row.get("execution_state", "")) == "never":
			continue
		row ["visibility_state"] = "visible"
		row ["interaction_state"] = "live"
		row ["execution_state"] = "complete"
		row ["player_status_text"] = "Live."
		domain_states [domain_id] = row

	scheduler ["pending"] = false
	scheduler ["complete"] = true
	scheduler ["active_stage_id"] = ""
	scheduler ["domain_states"] = domain_states
	scheduler ["background_queue_size"] = 0
	scheduler ["last_background_report"] = slice_report.duplicate(true)
	scheduler ["completed_at_ms"] = int(Time.get_ticks_msec())
	scheduler ["updated_at_ms"] = int(Time.get_ticks_msec())

	scenario_state ["save_load_runtime_scheduler"] = scheduler.duplicate(true)
	scenario_state ["save_load_runtime_scheduler_active"] = false
	scenario_state ["background_hydration_active"] = false
	scenario_state ["background_hydration_queue_size"] = 0

	return scheduler.duplicate(true)


func _save_load_runtime_scheduler_snapshot() -> Dictionary:
	if typeof(scenario_state) != TYPE_DICTIONARY:
		scenario_state = {}

	var scheduler_raw: Variant = scenario_state.get("save_load_runtime_scheduler", {})
	if typeof(scheduler_raw) != TYPE_DICTIONARY:
		return {
			"pending": false
		}

	var scheduler: Dictionary = (scheduler_raw as Dictionary).duplicate(true)
	if scheduler.is_empty():
		return {
			"pending": false
		}

	if not bool(scheduler.get("pending", false)):
		return {
			"pending": false,
			"complete": bool(scheduler.get("complete", false))
		}

	scheduler ["pending_intent_count"] = _runtime_boot_buffered_intent_count()
	scheduler ["created_at_ms"] = int(scheduler.get("created_at_ms", Time.get_ticks_msec()))
	scheduler ["updated_at_ms"] = int(Time.get_ticks_msec())
	return scheduler.duplicate(true)


func _save_load_live_domain_state(domain_id: String, status_text: String = "Live.") -> Dictionary:
	return {
		"domain": str(domain_id).strip_edges().to_lower(),
		"visibility_state": "visible",
		"interaction_state": "live",
		"execution_state": "complete",
		"player_status_text": status_text
	}


func _save_load_optional_domain_state(domain_id: String, status_text: String) -> Dictionary:
	var clean_domain: String = str(domain_id).strip_edges().to_lower()
	var enabled: bool = true

	match clean_domain:
		"powers":
			enabled = is_feature_enabled("superpowers") or is_feature_enabled("powers")
		"superhero":
			enabled = is_feature_enabled("superheroes") or is_feature_enabled("superpowers")
		"artifacts":
			enabled = is_feature_enabled("artifacts")
		"bending":
			enabled = is_feature_enabled("bending")
		"magic":
			enabled = is_feature_enabled("magic") or is_feature_enabled("wizards")
		"realms":
			enabled = is_feature_enabled("realms") or is_feature_enabled("imaginative_realms")
		_:
			enabled = true

	if not enabled:
		return {
			"domain": clean_domain,
			"visibility_state": "hidden",
			"interaction_state": "locked",
			"execution_state": "never",
			"player_status_text": "This domain is not active in this saved reality."
		}

	return {
		"domain": clean_domain,
		"visibility_state": "partial",
		"interaction_state": "buffered",
		"execution_state": "deferred",
		"player_status_text": status_text
	}


func _birth_shell_runtime_boot_stage_snapshot(stage: Dictionary, completed_stage_ids: Array, skipped_stage_ids: Array, active_stage_id: String) -> Dictionary:
	var out: Dictionary = stage.duplicate(true)
	var stage_id: String = str(out.get("id", "")).strip_edges()

	if skipped_stage_ids.has(stage_id):
		out ["visibility_state"] = "hidden"
		out ["interaction_state"] = "locked"
		out ["execution_state"] = "never"
	elif completed_stage_ids.has(stage_id):
		out ["visibility_state"] = "visible" if str(out.get("visibility_state", "visible")) != "hidden" else "hidden"
		out ["interaction_state"] = "live" if str(out.get("visibility_state", "visible")) != "hidden" else "locked"
		out ["execution_state"] = "complete"
	elif active_stage_id == stage_id:
		out ["execution_state"] = "streaming"
		if str(out.get("interaction_state", "buffered")) == "live" and str(out.get("weight", "medium")).strip_edges().to_lower() in ["heavy", "very_heavy"]:
			out ["interaction_state"] = "buffered"

	return out


func _birth_shell_merge_runtime_boot_domain_state(current: Dictionary, stage: Dictionary) -> Dictionary:
	var out: Dictionary = current.duplicate(true)
	var stage_id: String = str(stage.get("id", "")).strip_edges()

	if out.is_empty():
		out = {
			"domain": str(stage.get("domain", "runtime")),
			"visibility_state": str(stage.get("visibility_state", "hidden")),
			"interaction_state": str(stage.get("interaction_state", "locked")),
			"execution_state": str(stage.get("execution_state", "deferred")),
			"stage_ids": [],
			"active_stage_ids": [],
			"player_status_text": str(stage.get("buffered_text", "Reality is still assembling this system."))
		}

	var stage_ids: Array = out.get("stage_ids", []) if typeof(out.get("stage_ids", [])) == TYPE_ARRAY else []
	if stage_id != "" and not stage_ids.has(stage_id):
		stage_ids.append(stage_id)
	out ["stage_ids"] = stage_ids

	var visibility_state: String = str(stage.get("visibility_state", "hidden"))
	if visibility_state == "visible":
		out ["visibility_state"] = "visible"
	elif visibility_state == "partial" and str(out.get("visibility_state", "hidden")) == "hidden":
		out ["visibility_state"] = "partial"

	var stage_interaction: String = str(stage.get("interaction_state", "locked"))
	if stage_interaction == "locked":
		out ["interaction_state"] = "locked"
	elif stage_interaction == "buffered" and str(out.get("interaction_state", "live")) != "locked":
		out ["interaction_state"] = "buffered"
	elif str(out.get("interaction_state", "locked")) == "locked" and stage_interaction == "live":
		out ["interaction_state"] = "live"

	var stage_execution: String = str(stage.get("execution_state", "deferred"))
	if stage_execution == "streaming":
		out ["execution_state"] = "streaming"
	elif stage_execution == "deferred" and str(out.get("execution_state", "complete")) != "streaming":
		out ["execution_state"] = "deferred"
	elif stage_execution == "never" and str(out.get("execution_state", "complete")) == "complete":
		out ["execution_state"] = "never"
	elif stage_execution == "complete" and str(out.get("execution_state", "complete")) == "never":
		out ["execution_state"] = "complete"

	var active_stage_ids: Array = out.get("active_stage_ids", []) if typeof(out.get("active_stage_ids", [])) == TYPE_ARRAY else []
	if stage_execution == "streaming" and stage_id != "" and not active_stage_ids.has(stage_id):
		active_stage_ids.append(stage_id)
	out ["active_stage_ids"] = active_stage_ids

	if stage_execution != "complete" and stage_execution != "never":
		out ["player_status_text"] = str(stage.get("buffered_text", out.get("player_status_text", "Reality is still assembling this system.")))

	return out


func resolve_runtime_boot_domain_gate(domain_id: String, action_id: String = "", _context: Dictionary = {}) -> Dictionary:
	var clean_domain: String = str(domain_id).strip_edges().to_lower()
	if clean_domain == "":
		clean_domain = "runtime"

	var clean_action: String = str(action_id).strip_edges().to_lower()
	if clean_action == "":
		clean_action = "runtime.intent"

	var snapshot: Dictionary = get_runtime_boot_scheduler_snapshot()
	if not bool(snapshot.get("pending", false)):
		return {
			"allowed": true,
			"buffer_intent": false,
			"domain": clean_domain,
			"action_id": clean_action,
			"reason": "runtime_boot_complete",
			"resolution_strategy": _runtime_boot_resolution_strategy_for_action(clean_domain, clean_action),
			"truth_layer_required": false
		}

	var domain_states_raw: Variant = snapshot.get("domain_states", {})
	var domain_states: Dictionary = domain_states_raw if typeof(domain_states_raw) == TYPE_DICTIONARY else {}
	var state: Dictionary = domain_states.get(clean_domain, {}) if typeof(domain_states.get(clean_domain, {})) == TYPE_DICTIONARY else {}

	if state.is_empty():
		return {
			"allowed": true,
			"buffer_intent": false,
			"domain": clean_domain,
			"action_id": clean_action,
			"reason": "domain_not_deferred",
			"resolution_strategy": _runtime_boot_resolution_strategy_for_action(clean_domain, clean_action),
			"truth_layer_required": false
		}

	var visibility_state: String = str(state.get("visibility_state", "hidden")).strip_edges().to_lower()
	var interaction_state: String = str(state.get("interaction_state", "locked")).strip_edges().to_lower()
	var execution_state: String = str(state.get("execution_state", "deferred")).strip_edges().to_lower()
	var resolution_strategy: String = _runtime_boot_resolution_strategy_for_action(clean_domain, clean_action)

	if visibility_state == "hidden" or interaction_state == "locked" or execution_state == "never":
		return {
			"allowed": false,
			"buffer_intent": false,
			"domain": clean_domain,
			"action_id": clean_action,
			"visibility_state": visibility_state,
			"interaction_state": interaction_state,
			"execution_state": execution_state,
			"popup_title": "Reality has not opened that door yet.",
			"popup_text": "That system is not active in this reality mode.",
			"reason": "domain_locked",
			"resolution_strategy": resolution_strategy,
			"truth_layer_required": false,
			"causality_inversion_allowed": false
		}

	if interaction_state == "buffered" or execution_state in ["deferred", "streaming"]:
		return {
			"allowed": false,
			"buffer_intent": true,
			"domain": clean_domain,
			"action_id": clean_action,
			"visibility_state": visibility_state,
			"interaction_state": interaction_state,
			"execution_state": execution_state,
			"popup_title": _runtime_boot_buffer_title_for_action(clean_domain, clean_action),
			"popup_text": str(state.get("player_status_text", "This intent has been buffered while reality finishes assembling the system behind it.")),
			"reason": "domain_buffering",
			"resolution_strategy": resolution_strategy,
			"truth_layer_required": resolution_strategy == "generate_if_missing",
			"causality_inversion_allowed": resolution_strategy == "generate_if_missing",
			"local_shell_confidence": 0.62
		}

	return {
		"allowed": true,
		"buffer_intent": false,
		"domain": clean_domain,
		"action_id": clean_action,
		"visibility_state": visibility_state,
		"interaction_state": interaction_state,
		"execution_state": execution_state,
		"reason": "domain_live",
		"resolution_strategy": resolution_strategy,
		"truth_layer_required": false,
		"causality_inversion_allowed": true
	}
func _runtime_boot_resolution_strategy_for_action(domain_id: String, action_id: String) -> String:
	var clean_domain: String = str(domain_id).strip_edges().to_lower()
	var clean_action: String = str(action_id).strip_edges().to_lower()

	if clean_action in ["track_villain", "respond_to_crime", "patrol_city", "recruit_ally", "recruit_sidekick", "start_team"]:
		return "generate_if_missing"

	if clean_domain in ["superhero", "powers"] and (clean_action.find("villain") >= 0 or clean_action.find("ally") >= 0 or clean_action.find("team") >= 0):
		return "generate_if_missing"

	if clean_domain == "bending" and (clean_action.find("duel") >= 0 or clean_action.find("spar") >= 0):
		return "generate_if_missing"

	if clean_domain in ["world", "runtime"] and (clean_action.find("relationship") >= 0 or clean_action.find("career") >= 0):
		return "prefer_existing_then_generate"

	return "prefer_existing_if_available"


func _runtime_boot_buffer_title_for_action(domain_id: String, action_id: String) -> String:
	var clean_action: String = str(action_id).strip_edges().to_lower()

	match clean_action:
		"track_villain":
			return "Scanning city activity..."
		"respond_to_crime":
			return "Listening for emergency signals..."
		"recruit_ally", "recruit_sidekick":
			return "Scanning compatible sidekicks..."
		"start_team":
			return "Testing team formation pressure..."
		"seek_bending_duel", "find_bending_duel", "bending_duel":
			return "Reading duel pressure..."
		_:
			if str(domain_id).strip_edges().to_lower() == "bending":
				return "Reading bending pressure..."
			return "Reality is still assembling..."


func queue_runtime_boot_intent(intent: Dictionary) -> Dictionary:
	if typeof(scenario_state) != TYPE_DICTIONARY:
		scenario_state = {}

	var queue_raw: Variant = scenario_state.get("runtime_boot_buffered_intents", [])
	var queue: Array = queue_raw if typeof(queue_raw) == TYPE_ARRAY else []

	var normalized: Dictionary = intent.duplicate(true)
	var domain_id: String = str(normalized.get("domain", "runtime")).strip_edges().to_lower()
	var action_id: String = str(normalized.get("action_id", normalized.get("action", "runtime.intent"))).strip_edges().to_lower()

	if domain_id == "":
		domain_id = "runtime"
	if action_id == "":
		action_id = "runtime.intent"

	normalized ["schema"] = str(normalized.get("schema", "eralife.runtime_boot_buffered_intent"))
	normalized ["version"] = max(1, int(normalized.get("version", 1)))
	normalized ["domain"] = domain_id
	normalized ["action_id"] = action_id
	normalized ["buffered_intent_id"] = "%s_%s_%d" % [domain_id, action_id.replace(".", "_").replace(" ", "_"), int(Time.get_ticks_msec())]
	normalized ["created_at_ms"] = int(Time.get_ticks_msec())
	normalized ["created_at_year"] = int(year)
	normalized ["causality_inversion_allowed"] = bool(normalized.get("causality_inversion_allowed", true))
	normalized ["resolution_strategy"] = str(normalized.get("resolution_strategy", _runtime_boot_resolution_strategy_for_action(domain_id, action_id)))
	normalized ["local_shell_text"] = str(normalized.get("local_shell_text", _runtime_boot_buffer_title_for_action(domain_id, action_id)))

	if not normalized.has("actor_id") and player != null:
		normalized ["actor_id"] = int(player.id)

	if bool(normalized.get("causality_inversion_allowed", true)) and ensure_causality_inversion_engine():
		var actor_ref: Person = player
		if normalized.has("actor_id") and has_method("get_or_reactivate_npc_by_id"):
			var found_actor: Person = get_or_reactivate_npc_by_id(int(normalized.get("actor_id", -1)))
			if found_actor != null:
				actor_ref = found_actor

		normalized ["local_shell_packet"] = causality_inversion_engine.build_local_shell_packet(actor_ref, {
			"action_id": action_id,
			"domain": normalized.get("cie_domain", domain_id),
			"payload": normalized.get("payload", {}),
			"resolution_strategy": normalized.get("resolution_strategy", "prefer_existing_if_available")
		}, {
			"source": str(normalized.get("source", "runtime_boot_buffer")),
			"crbs_domain": domain_id,
			"engine_property": str(normalized.get("engine_property", "")),
			"method": str(normalized.get("method", ""))
		})

	queue.append(normalized)
	while queue.size() > 32:
		queue.pop_front()

	scenario_state ["runtime_boot_buffered_intents"] = queue

	var local_shell_packet: Dictionary = {}
	var local_shell_packet_raw: Variant = normalized.get("local_shell_packet", {})
	if typeof(local_shell_packet_raw) == TYPE_DICTIONARY:
		local_shell_packet = (local_shell_packet_raw as Dictionary).duplicate(true)

	return {
		"success": true,
		"buffered": true,
		"domain": domain_id,
		"action_id": action_id,
		"queued_count": queue.size(),
		"popup_title": str(normalized.get("local_shell_text", "Intent buffered.")),
		"popup_text": "Reality heard you. The local shell accepted the intent while the truth layer catches up.",
		"local_shell_packet": local_shell_packet
	}
func consume_runtime_boot_intents_for_domain(domain_id: String) -> Array:
	if typeof(scenario_state) != TYPE_DICTIONARY:
		scenario_state = {}

	var clean_domain: String = str(domain_id).strip_edges().to_lower()
	if clean_domain == "":
		clean_domain = "runtime"

	var gate: Dictionary = resolve_runtime_boot_domain_gate(clean_domain)
	if not bool(gate.get("allowed", false)):
		return []

	var queue_raw: Variant = scenario_state.get("runtime_boot_buffered_intents", [])
	var queue: Array = queue_raw if typeof(queue_raw) == TYPE_ARRAY else []
	var ready: Array = []
	var keep: Array = []

	for raw_intent in queue:
		if typeof(raw_intent) != TYPE_DICTIONARY:
			continue

		var intent: Dictionary = (raw_intent as Dictionary).duplicate(true)
		if str(intent.get("domain", "")).strip_edges().to_lower() == clean_domain:
			ready.append(intent)
		else:
			keep.append(intent)

	scenario_state ["runtime_boot_buffered_intents"] = keep
	return ready


func _runtime_boot_buffered_intent_count() -> int:
	if typeof(scenario_state) != TYPE_DICTIONARY:
		return 0

	var queue_raw: Variant = scenario_state.get("runtime_boot_buffered_intents", [])
	var queue: Array = queue_raw if typeof(queue_raw) == TYPE_ARRAY else []
	return queue.size()
func _hydrate_reality_settings() -> void:
	if custom_settings == null:
		custom_settings = {}

	reality_mode = str(custom_settings.get("reality_mode", REALITY_CHAOS)).strip_edges().to_lower()

	if reality_mode == "fantasy":
		reality_mode = REALITY_CHAOS

	if reality_mode not in [REALITY_REALISTIC, REALITY_ENHANCED, REALITY_CHAOS]:
		reality_mode = REALITY_CHAOS

	reality_feature_overrides = custom_settings.get("feature_overrides", {}).duplicate()

	custom_settings ["reality_mode"] = reality_mode
	custom_settings ["reality_mode_label"] = reality_mode.capitalize()
	if reality_mode == REALITY_CHAOS:
		custom_settings ["reality_mode_label"] = "Chaos"

	custom_settings ["feature_overrides"] = reality_feature_overrides.duplicate()
	custom_settings ["fantasy_alias_is_chaos"] = true

	_sanitize_custom_settings_for_reality_mode()
	player_bending_enabled = is_feature_enabled("bending")
func _sanitize_custom_settings_for_reality_mode() -> void:
	if custom_settings == null:
		return

	if not is_feature_enabled("bending"):
		custom_settings ["bending_type"] = "none"

		if custom_settings.has("school_mode"):
			var sm = str(custom_settings.get("school_mode", ""))
			if sm in ["bending_school", "dual"]:
				custom_settings ["school_mode"] = "era_school"

	if not is_feature_enabled("artifacts"):
		custom_settings ["starting_infinity_stones"] = 0
		custom_settings ["start_with_red_bonnet"] = false

	if not is_feature_enabled("vampires"):
		if custom_settings.has("start_as_vampire"):
			custom_settings ["start_as_vampire"] = false
func queue_year_resolution_popup(entry: Dictionary) -> void:
	if typeof(entry) != TYPE_DICTIONARY or entry.is_empty():
		return
	var popup_entry: Dictionary = entry.duplicate(true)
	var popup_text: String = str(popup_entry.get("popup_text", popup_entry.get("text", ""))).strip_edges()
	if popup_text == "":
		return
	if not popup_entry.has("popup_title"):
		popup_entry ["popup_title"] = "Notice"
	popup_entry ["popup_text"] = popup_text
	if not popup_entry.has("popup_footer"):
		popup_entry ["popup_footer"] = "Tap anywhere to continue."
	pending_year_resolution_popups.append(popup_entry)

func pop_next_year_resolution_popup() -> Dictionary:
	if pending_year_resolution_popups.is_empty():
		return {}
	var next_popup = pending_year_resolution_popups.pop_front()
	if typeof(next_popup) != TYPE_DICTIONARY:
		return {}
	return next_popup.duplicate(true)

func queue_player_inheritance_notice(text: String, popup_title: String = "Inheritance", add_to_life_journal: bool = true) -> void:
	var clean_text: String = str(text).strip_edges()
	if clean_text == "":
		return
	if add_to_life_journal:
		pending_inheritance_messages.append(clean_text)
	queue_year_resolution_popup({
		"popup_title": popup_title,
		"popup_text": clean_text,
		"popup_footer": "Tap anywhere to continue."
	})

func _queue_player_inheritance_popup_from_artifact_event(payload) -> void:
	if typeof(payload) != TYPE_DICTIONARY:
		return
	if player == null:
		return
	var npc_id: int = int(payload.get("npc_id", -1))
	if npc_id != int(player.id):
		return
	var acquisition_source: String = str(payload.get("acquisition_source", "")).strip_edges()
	if acquisition_source != "inheritance":
		return
	var popup_text: String = str(payload.get("text", "")).strip_edges()
	if popup_text == "":
		return
	queue_year_resolution_popup({
		"popup_title": "Inheritance",
		"popup_text": popup_text,
		"popup_footer": "Tap anywhere to continue."
	})
func build_runtime_popup_mailbox_entries_from_typed_packets(delta_packets: Array) -> Array:
	var out: Array = []
	var seen: Dictionary = {}

	for raw_packet in delta_packets:
		if typeof(raw_packet) != TYPE_DICTIONARY:
			continue
		var mailbox_entry: Dictionary = _popup_mailbox_entry_from_typed_packet(raw_packet)
		if mailbox_entry.is_empty():
			continue
		var mailbox_key: String = str(mailbox_entry.get("mailbox_key", "")).strip_edges()
		if mailbox_key != "" and seen.has(mailbox_key):
			continue
		if mailbox_key != "":
			seen [mailbox_key] = true
		out.append(mailbox_entry)

	return out

func _popup_mailbox_entry_from_typed_packet(packet: Dictionary) -> Dictionary:
	if typeof(packet) != TYPE_DICTIONARY or packet.is_empty():
		return {}

	var packet_type: String = str(packet.get("type", "")).strip_edges()
	if packet_type == "":
		return {}

	if packet_type == "year_resolution_popup":
		var direct_entry = packet.get("entry", {})
		if typeof(direct_entry) == TYPE_DICTIONARY and not direct_entry.is_empty():
			return {
				"type": "year_resolution_popup",
				"entry": direct_entry.duplicate(true),
				"mailbox_key": "popups|year_resolution_popup|%s" % str(direct_entry.get("popup_text", ""))
			}

	var popup_text: String = str(packet.get("popup_text", "")).strip_edges()
	var popup_title: String = str(packet.get("popup_title", "")).strip_edges()
	var popup_footer: String = str(packet.get("popup_footer", "Tap anywhere to continue.")).strip_edges()

	if popup_text == "" and bool(packet.get("queue_popup", false)):
		popup_text = str(packet.get("text", "")).strip_edges()

	if popup_text == "":
		match packet_type:
			"death", "death_notice":
				var dead_name: String = str(packet.get("name", "Someone")).strip_edges()
				if dead_name == "":
					dead_name = "Someone"
				popup_text = "💀 %s died." % dead_name
				if popup_title == "":
					popup_title = "Death Notice"
			"inheritance_notice":
				popup_text = str(packet.get("text", "")).strip_edges()
				if popup_title == "":
					popup_title = "Inheritance"

	if popup_text == "":
		return {}

	if packet_type in ["death", "death_notice"] and popup_title == "" and not bool(packet.get("queue_popup", false)):
		return {
			"type": "death_notice",
			"text": popup_text,
			"mailbox_key": "popups|death_notice|%s" % popup_text
		}

	if packet_type == "inheritance_notice" and popup_title == "" and not bool(packet.get("queue_popup", false)):
		return {
			"type": "inheritance_notice",
			"text": popup_text,
			"mailbox_key": "popups|inheritance_notice|%s" % popup_text
		}

	if popup_title == "":
		popup_title = "Notice"

	return {
		"type": "year_resolution_popup",
		"entry": {
			"popup_title": popup_title,
			"popup_text": popup_text,
			"popup_footer": popup_footer
		},
		"mailbox_key": "popups|year_resolution_popup|%s|%s" % [
			popup_title,
			popup_text
		]
	}
func get_reality_mode() -> String:
	return reality_mode


func is_feature_enabled(feature_name: String) -> bool:
	if reality_feature_overrides.has(feature_name):
		return bool(reality_feature_overrides [feature_name])

	match reality_mode:
		REALITY_REALISTIC:
			return feature_name not in [
				"bending",
				"wizard_magic",
				"superpowers",
				"vampires",
				"artifacts",
				"dragonballs",
				"many_realms",
				"supernatural_school",
				"supernatural_events"
			]

		REALITY_ENHANCED:
			if feature_name in [
				"bending",
				"wizard_magic",
				"supernatural_school",
				"supernatural_events"
			]:
				return true

			if feature_name in [
				"superpowers",
				"vampires",
				"dragonballs",
				"many_realms",
				"artifacts"
			]:
				return false

			return true

		_:
			return true

func set_reality_mode(mode: String) -> void:
	reality_mode = str(mode).strip_edges().to_lower()

	if reality_mode == "fantasy":
		reality_mode = REALITY_CHAOS

	if reality_mode not in [REALITY_REALISTIC, REALITY_ENHANCED, REALITY_CHAOS]:
		reality_mode = REALITY_CHAOS

	if custom_settings == null:
		custom_settings = {}

	custom_settings ["reality_mode"] = reality_mode
	custom_settings ["reality_mode_label"] = reality_mode.capitalize()
	if reality_mode == REALITY_CHAOS:
		custom_settings ["reality_mode_label"] = "Chaos"

	custom_settings ["feature_overrides"] = reality_feature_overrides.duplicate()
	custom_settings ["fantasy_alias_is_chaos"] = true

	_apply_reality_mode_runtime()

func set_feature_override(feature_name: String, enabled: bool) -> void:
	reality_feature_overrides [feature_name] = enabled
	if custom_settings == null:
		custom_settings = {}
	custom_settings ["feature_overrides"] = reality_feature_overrides.duplicate()

	_apply_reality_mode_runtime()


func toggle_feature_override(feature_name: String) -> bool:
	var new_value:= not is_feature_enabled(feature_name)
	set_feature_override(feature_name, new_value)
	return new_value


func _apply_reality_mode_runtime() -> void:
	player_bending_enabled = is_feature_enabled("bending")

	for npc in npcs:
		apply_reality_rules_to_person(npc)


func apply_reality_rules_to_person(p: Person) -> void:
	if p == null:
		return
	if not is_feature_enabled("bending"):
		p.bending_type = "none"
		p.bending_nation = ""
		p.bending_mastery = {}
		p.avatar_state_unlocked = false
		p.avatar_state_used = false
	if not is_feature_enabled("supernatural_school") and p.school_mode == "bending_school":
		p.school_mode = ""
		p.school_name = ""
		p.school_status = ""
		if p.education_level == "Bending School":
			p.education_level = ""
	if not is_feature_enabled("wizard_magic"):
		p.wizard_profile = {}

	if not is_feature_enabled("vampires"):
		p.vampire_profile = {}

	sync_person_death_state_from_health(p)
func sync_person_death_state_from_health(p: Person, cause: String = "Health depleted") -> bool:
	if p == null:
		return false

	var safe_cause: String = str(cause).strip_edges()
	if safe_cause == "":
		safe_cause = "Health depleted"

	if float(p.health) > 0.0:
		return false

	p.health = 0

	if not bool(p.alive):
		if str(p.cause_of_death).strip_edges() == "":
			p.cause_of_death = safe_cause
		if "death_year" in p and int(p.death_year) <= -999000:
			p.death_year = int(year)
		return true

	if health_engine != null and health_engine.has_method("try_kill"):
		var killed_by_engine: bool = bool(health_engine.try_kill(p, safe_cause))
		if killed_by_engine and "death_year" in p and int(p.death_year) <= -999000:
			p.death_year = int(year)
		return killed_by_engine

	if "Immortal" in p.traits:
		p.alive = true
		p.health = max(float(p.health), 200.0)
		p.cause_of_death = ""
		if "death_year" in p:
			p.death_year = -999999
		return false

	p.alive = false
	p.cause_of_death = safe_cause
	if "death_year" in p:
		p.death_year = int(year)
	queue_known_person_death_message(p)
	return true
func _remember_npc_in_index(npc: Person) -> void:
	if npc == null:
		return
	npc_index [npc.id] = npc


func _forget_npc_from_index(npc_id: int) -> void:
	npc_index.erase(npc_id)


func _rebuild_npc_index() -> void:
	npc_index.clear()
	for npc in npcs:
		if npc != null:
			npc_index [npc.id] = npc



func get_npc_by_id(
	id: int,
	allow_population_scan: bool = true
) -> Person:
	if id <= 0:
		return null

	if npc_index.has(id):
		var cached: Person = npc_index [id]
		if cached != null and cached.id == id:
			return cached
		npc_index.erase(id)




	if not allow_population_scan:
		return null

	for n in npcs:
		if n != null and n.id == id:
			npc_index [id] = n
			return n

	return null
func _normalize_world_feed_text(text: String) -> String:
	var out:= str(text)

	out = out.replace("
\n", "\n")
	out = out.replace("
", "\n")

	while out.begins_with("\n"):
		out = out.substr(1)

	while out.find("\n\n") != -1:
		out = out.replace("\n\n", "\n")

	var inline_emoji_replacements:= [
		["\n👑\n ", "👑 "],
		["\n🌌\n ", "🌌 "],
		["\n🧠\n ", "🧠 "],
		["\n🔺\n ", "🔺 "],
		["\n🔵\n ", "🔵 "],
		["\n🟢\n ", "🟢 "],
		["\n🟠\n ", "🟠 "],
		["\n🟣\n ", "🟣 "],
		["\n🔴\n ", "🔴 "],
		["\n🟡\n ", "🟡 "],
		["\n⭐\n ", "⭐ "],
		["\n💀\n ", "💀 "]
	]


	for replacement in inline_emoji_replacements:
		var from_text: String = replacement [0]
		var to_text: String = replacement [1]
		while out.find(from_text) != -1:
			out = out.replace(from_text, to_text)

	out = _strip_private_first_person_tone_from_world_feed_text(out)

	return out.strip_edges()
func _strip_private_first_person_tone_from_world_feed_text(text: String) -> String:
	var out: String = str(text).strip_edges()
	if out == "":
		return ""

	var forbidden_tails: Array = [
		" I hated how much it still mattered.",
		". I hated how much it still mattered.",
		" I barely knew what to feel.",
		". I barely knew what to feel.",
		" Somehow, I still felt like this would not be the end of my story.",
		". Somehow, I still felt like this would not be the end of my story.",
		" I tried to understand it through faith.",
		". I tried to understand it through faith."
	]

	for raw_tail in forbidden_tails:
		var tail: String = str(raw_tail)
		if out.ends_with(tail):
			out = out.substr(0, out.length() - tail.length()).strip_edges()

	if out != "" and not out.ends_with(".") and not out.ends_with("!") and not out.ends_with("?"):
		out += "."

	return out
func make_world_feed_entry(text: String, meta:= {}) -> Dictionary:
	var normalized_text: String = _normalize_world_feed_text(text)
	var entry:= {
		"text": normalized_text,
		"world_text": normalized_text,
		"player_text": "",
		"year": year,
		"era": era.name if era != null else "",
		"npc_id": -1,
		"relation_label": "",
		"personally_relevant": false,
		"category": "general",
		"event_name": "",
		"source": "system"
	}
	if typeof(meta) == TYPE_DICTIONARY:
		for k in meta.keys():
			entry [k] = meta [k]

	var resolved_world_text: String = str(entry.get("world_text", entry.get("text", ""))).strip_edges()
	if resolved_world_text == "":
		resolved_world_text = normalized_text
	entry ["world_text"] = _normalize_world_feed_text(resolved_world_text)
	entry ["text"] = str(entry.get("world_text", ""))

	var resolved_player_text: String = str(entry.get("player_text", "")).strip_edges()
	if resolved_player_text != "":
		entry ["player_text"] = _normalize_world_feed_text(resolved_player_text)
	else:
		entry ["player_text"] = ""

	return entry


func normalize_world_feed_entry(entry) -> Dictionary:
	if typeof(entry) == TYPE_DICTIONARY:
		var world_seed_text: String = str(entry.get("world_text", entry.get("text", "")))
		var out = make_world_feed_entry(world_seed_text)
		for k in entry.keys():
			if k == "text" or k == "world_text" or k == "player_text":
				out [k] = _normalize_world_feed_text(str(entry [k])) if str(entry [k]).strip_edges() != "" else ""
			else:
				out [k] = entry [k]

		if str(out.get("world_text", "")).strip_edges() == "":
			out ["world_text"] = _normalize_world_feed_text(str(out.get("text", "")))
		if str(out.get("text", "")).strip_edges() == "":
			out ["text"] = str(out.get("world_text", ""))
		else:
			out ["text"] = _normalize_world_feed_text(str(out.get("text", "")))

		if str(out.get("player_text", "")).strip_edges() != "":
			out ["player_text"] = _normalize_world_feed_text(str(out.get("player_text", "")))
		else:
			out ["player_text"] = ""

		return _repair_world_feed_entry_chronology(out)

	var legacy_text:= _normalize_world_feed_text(str(entry))
	return make_world_feed_entry(legacy_text, {
		"source": "legacy_string",
		"personally_relevant": legacy_text.begins_with("My "),
		"relation_label": "legacy_prefix" if legacy_text.begins_with("My ") else ""
	})


func _repair_world_feed_entry_chronology(entry: Dictionary) -> Dictionary:
	var out: Dictionary = entry.duplicate(true)
	var event_name: String = str(out.get("event_name", "")).strip_edges().to_lower()
	var category: String = str(out.get("category", "")).strip_edges().to_lower()
	var tournament_id: String = str(out.get("tournament_id", "")).strip_edges()

	if tournament_id != "" and (event_name == "bending_tournament_champion" or category == "bending"):
		var parsed_year: int = _world_feed_year_from_tournament_id(tournament_id)
		if parsed_year != -999999:
			out ["year"] = parsed_year
			if parsed_year < int(year):
				out ["historical_backfill"] = true

	return out


func _world_feed_year_from_tournament_id(tournament_id: String) -> int:
	var clean_id: String = str(tournament_id).strip_edges()
	if clean_id == "":
		return -999999

	var pieces: PackedStringArray = clean_id.split("_")
	for i in range(pieces.size() - 1, -1, -1):
		var piece: String = str(pieces [i]).strip_edges()
		if piece.is_valid_int():
			return int(piece)

	return -999999


func push_world_feed(text: String, meta:= {}):
	if text == "":
		return

	var new_entry:= make_world_feed_entry(
		text,
		meta
	)
	var new_key: String = _world_feed_entry_dedupe_key(
		new_entry
	)
	new_entry ["_dedupe_key"] = new_key

	if world_feed.size() > 0:
		var raw_last_entry = world_feed.back()
		var last_entry: Dictionary = (
			raw_last_entry
			if typeof(raw_last_entry) == TYPE_DICTIONARY
			else {}
		)
		var last_key: String = str(
			last_entry.get(
				"_dedupe_key",
				""
			)
		).strip_edges()

		if (
			last_key == ""
			and typeof(raw_last_entry) == TYPE_DICTIONARY
		):
			last_key = _world_feed_entry_dedupe_key(
				last_entry
			)

		if (
			last_key != ""
			and last_key == new_key
		):
			return

		if last_key == "":
			var normalized_last_entry: Dictionary = (
				normalize_world_feed_entry(
					raw_last_entry
				)
			)
			if (
				_world_feed_entry_dedupe_key(
					normalized_last_entry
				) == new_key
			):
				return

	world_feed.append(
		new_entry
	)

	if world_feed.size() > WORLD_FEED_LIMIT:
		world_feed.pop_front()

	world_feed_entry_contract_committed.emit({
		"schema": "eralife.world_feed_entry_commit_contract",
		"version": 1,
		"year": int(
			new_entry.get(
				"year",
				year
			)
		),
		"entry": new_entry.duplicate(false),
		"truth_owner": "game_state",
		"publisher": "push_world_feed",
		"ui_is_renderer_only": true,
		"blocks_ui": false,
		"idle_required": false,
		"committed_at_ms": int(
			Time.get_ticks_msec()
		)
	})

func _world_feed_entry_dedupe_key(entry: Dictionary) -> String:
	if typeof(entry) != TYPE_DICTIONARY or entry.is_empty():
		return ""

	var fallback_year: int = int(year)

	return "%s|%s|%s|%s" % [
		str(entry.get("world_text", entry.get("text", ""))).strip_edges(),
		str(entry.get("player_text", "")).strip_edges(),
		str(int(entry.get("npc_id", -1))),
		str(int(entry.get("year", fallback_year)))
	]
func get_world_feed_text(entry, view: String = "world") -> String:
	var normalized: Dictionary = normalize_world_feed_entry(entry)
	var requested_view: String = str(view).strip_edges().to_lower()

	if requested_view == "player":
		var player_text: String = str(normalized.get("player_text", "")).strip_edges()
		if player_text != "":
			return player_text
		return str(normalized.get("world_text", normalized.get("text", "")))

	if requested_view == "world":
		var world_text: String = str(normalized.get("world_text", normalized.get("text", ""))).strip_edges()
		if world_text != "":
			return world_text

	return str(normalized.get("text", ""))
func ensure_body_contracts_for_person(person: Person, context: Dictionary = {}) -> Dictionary:
	if person == null:
		return {}

	var force_sync: bool = bool(context.get("force_sync", false))
	var should_defer: bool = _body_contracts_should_defer_for_context(context)

	if should_defer and not force_sync:
		queue_body_contract_refresh_for_person(person, _merge_body_runtime_context(context, {
			"source": str(context.get("source", "game_state_body_contracts")),
			"queued_because": "runtime_hot_or_spawn_handoff",
			"force_sync": false
		}))

		var cached: Dictionary = _cached_body_contract_bundle_for_person(person, {
			"source": str(context.get("source", "game_state_body_contracts")),
			"deferred": true
		})
		cached ["success"] = true
		cached ["ready"] = _body_contract_bundle_has_visible_truth(cached)
		cached ["deferred"] = true
		cached ["queued"] = true
		return cached

	return _ensure_body_contracts_for_person_sync(person, _merge_body_runtime_context(context, {
		"source": str(context.get("source", "game_state_body_contracts")),
		"force_sync": true
	}))

func yearly_tick_body_contracts_for_person(person: Person, context: Dictionary = {}) -> Dictionary:
	if person == null:
		return {}

	var force_sync: bool = bool(context.get("force_sync", false))
	var should_defer: bool = _body_contracts_should_defer_for_context(context)

	if should_defer and not force_sync:
		queue_body_contract_refresh_for_person(person, _merge_body_runtime_context(context, {
			"source": str(context.get("source", "game_state_body_yearly_tick")),
			"yearly_tick": true,
			"queued_because": "yearly_body_tick_deferred"
		}))

		var cached: Dictionary = _cached_body_contract_bundle_for_person(person, {
			"source": str(context.get("source", "game_state_body_yearly_tick")),
			"deferred": true
		})
		cached ["success"] = true
		cached ["ready"] = _body_contract_bundle_has_visible_truth(cached)
		cached ["deferred"] = true
		cached ["queued"] = true
		return cached

	if growth_curve_engine != null and growth_curve_engine.has_method("yearly_tick_person"):
		growth_curve_engine.yearly_tick_person(person, {
			"source": str(context.get("source", "game_state_body_yearly_tick"))
		})

	if height_contract_engine != null and height_contract_engine.has_method("yearly_tick_person"):
		height_contract_engine.yearly_tick_person(person, {
			"source": str(context.get("source", "game_state_body_yearly_tick"))
		})

	if weight_contract_engine != null and weight_contract_engine.has_method("yearly_tick_person"):
		weight_contract_engine.yearly_tick_person(person, {
			"source": str(context.get("source", "game_state_body_yearly_tick"))
		})

	return _ensure_body_contracts_for_person_sync(person, {
		"source": str(context.get("source", "game_state_body_yearly_tick_finalize")),
		"force_sync": true
	})
func observe_body_contracts_for_person(person: Person, context: Dictionary = {}) -> Dictionary:
	if person == null:
		return {}

	var cached: Dictionary = _cached_body_contract_bundle_for_person(person, context)
	var ready: bool = _body_contract_bundle_has_visible_truth(cached)

	if not ready and bool(context.get("queue_if_missing", true)):
		queue_body_contract_refresh_for_person(person, _merge_body_runtime_context(context, {
			"source": str(context.get("source", "observe_body_contracts_for_person")),
			"queued_because": "observer_requested_missing_body_truth"
		}))

	cached ["success"] = true
	cached ["ready"] = ready
	cached ["observer_only"] = true
	cached ["queued"] = not ready
	return cached


func queue_body_contract_refresh_from_event(payload:= {}, context: Dictionary = {}) -> void:
	var actor: Person = _body_contract_actor_from_payload(payload, false)
	if actor == null:
		return

	queue_body_contract_refresh_for_person(actor, _merge_body_runtime_context(context, {
		"source": str(context.get("source", "event_bus.body_contract_refresh")),
		"event_name": str(payload.get("event_name", payload.get("type", ""))) if typeof(payload) == TYPE_DICTIONARY else "",
		"event_bus_payload": payload if typeof(payload) == TYPE_DICTIONARY else {}
	}))


func queue_body_contract_yearly_tick_from_event(payload:= {}, context: Dictionary = {}) -> void:
	if typeof(scenario_state) != TYPE_DICTIONARY:
		scenario_state = {}

	var event_year: int = int(payload.get("year", year)) if typeof(payload) == TYPE_DICTIONARY else int(year)
	if body_contract_yearly_queue_built_for_year == event_year:
		return

	body_contract_yearly_queue_built_for_year = event_year

	var focus_people: Array = _body_contract_focus_people_for_tail_work(24)
	for raw_person in focus_people:
		if raw_person == null or not (raw_person is Person):
			continue

		queue_body_contract_refresh_for_person(raw_person as Person, _merge_body_runtime_context(context, {
			"source": str(context.get("source", "event_bus.body_contract_yearly_tick")),
			"yearly_tick": true,
			"year": event_year,
			"queued_because": "year_passed_ambient_body_tick"
		}))


func queue_body_contract_refresh_for_person(
	person: Person,
	context: Dictionary = {}
) -> Dictionary:
	if person == null:
		return {
			"success": false,
			"reason": "No person supplied."
		}

	if typeof(body_contract_runtime_queue) != TYPE_ARRAY:
		body_contract_runtime_queue = []

	if typeof(body_contract_runtime_index) != TYPE_DICTIONARY:
		body_contract_runtime_index = {}

	var actor_id: int = int(person.id)

	if actor_id <= 0:
		return {
			"success": false,
			"reason": "Person has no valid id."
		}

	var queue_key: String = str(actor_id)
	var row: Dictionary = {
		"actor_id": actor_id,
		"source": str(
			context.get(
				"source",
				"queue_body_contract_refresh_for_person"
			)
		),
		"context": context.duplicate(true),
		"queued_at_ms": int(Time.get_ticks_msec()),
		"year": int(year)
	}

	if body_contract_runtime_index.has(queue_key):
		var existing_index: int = int(
			body_contract_runtime_index.get(
				queue_key,
				-1
			)
		)

		if (
			existing_index >= 0
			and existing_index < body_contract_runtime_queue.size()
		):
			var existing_raw: Variant = (
				body_contract_runtime_queue [existing_index]
			)
			var existing: Dictionary = (
				existing_raw
				if typeof(existing_raw) == TYPE_DICTIONARY
				else {}
			)

			existing ["context"] = _merge_body_runtime_context(
				_safe_dictionary(
					existing.get(
						"context",
						{}
					)
				),
				context
			)
			existing ["source"] = str(
				context.get(
					"source",
					existing.get(
						"source",
						"queue_body_contract_refresh_for_person"
					)
				)
			)
			existing ["updated_at_ms"] = int(
				Time.get_ticks_msec()
			)

			body_contract_runtime_queue [
				existing_index
			] = existing




			_schedule_body_contract_refresh_queue_drain(
				0.12
			)

			return {
				"success": true,
				"mode": "body_contract_refresh_queue_merged",
				"actor_id": actor_id,
				"queue_size": body_contract_runtime_queue.size()
			}

	body_contract_runtime_queue.append(
		row
	)
	body_contract_runtime_index [
		queue_key
	] = body_contract_runtime_queue.size() - 1

	while (
		body_contract_runtime_queue.size()
		> BODY_CONTRACT_RUNTIME_QUEUE_LIMIT
	):
		var dropped_raw: Variant = (
			body_contract_runtime_queue.pop_front()
		)

		if typeof(dropped_raw) == TYPE_DICTIONARY:
			body_contract_runtime_index.erase(
				str(
					(dropped_raw as Dictionary).get(
						"actor_id",
						""
					)
				)
			)

		_rebuild_body_contract_runtime_index()

	_schedule_body_contract_refresh_queue_drain(
		0.12
	)

	return {
		"success": true,
		"mode": "body_contract_refresh_queued",
		"actor_id": actor_id,
		"queue_size": body_contract_runtime_queue.size()
	}
func _schedule_body_contract_refresh_queue_drain(
	delay_seconds: float = 0.12
) -> void:
	if (
		typeof(body_contract_runtime_queue) != TYPE_ARRAY
		or body_contract_runtime_queue.is_empty()
	):
		set_meta(
			"body_contract_runtime_drain_scheduled",
			false
		)
		return

	if bool(
		get_meta(
			"body_contract_runtime_drain_scheduled",
			false
		)
	):
		return

	var main_loop: MainLoop = Engine.get_main_loop()

	if (
		main_loop == null
		or not (main_loop is SceneTree)
	):
		set_meta(
			"body_contract_runtime_drain_scheduled",
			false
		)
		set_meta(
			"body_contract_runtime_drain_waiting_for_scheduler",
			true
		)
		return

	var tree: SceneTree = main_loop as SceneTree
	var safe_delay_seconds: float = clampf(
		delay_seconds,
		0.05,
		0.5
	)

	set_meta(
		"body_contract_runtime_drain_scheduled",
		true
	)
	set_meta(
		"body_contract_runtime_drain_waiting_for_scheduler",
		false
	)
	set_meta(
		"body_contract_runtime_drain_next_delay_seconds",
		safe_delay_seconds
	)
	set_meta(
		"body_contract_runtime_drain_scheduled_at_ms",
		int(Time.get_ticks_msec())
	)

	var timer:= tree.create_timer(
		safe_delay_seconds,
		false,
		false,
		true
	)

	var connect_error: int = timer.timeout.connect(
		Callable(
			self,
			"_drain_body_contract_refresh_queue_deferred"
		),
		CONNECT_ONE_SHOT
	)

	if connect_error != OK:
		set_meta(
			"body_contract_runtime_drain_scheduled",
			false
		)
		set_meta(
			"body_contract_runtime_drain_waiting_for_scheduler",
			true
		)

func _drain_body_contract_refresh_queue_deferred() -> void:
	set_meta(
		"body_contract_runtime_drain_scheduled",
		false
	)

	if (
		typeof(body_contract_runtime_queue) != TYPE_ARRAY
		or body_contract_runtime_queue.is_empty()
	):
		set_meta(
			"body_contract_runtime_drain_last_remaining",
			0
		)
		return

	var now_ms: int = int(
		Time.get_ticks_msec()
	)

	if _body_contracts_should_defer_for_context({
		"source": "body_contract_runtime_deferred_drain"
	}):
		set_meta(
			"body_contract_runtime_drain_last_yielded",
			true
		)
		set_meta(
			"body_contract_runtime_drain_last_yielded_at_ms",
			now_ms
		)
		set_meta(
			"body_contract_runtime_drain_last_remaining",
			body_contract_runtime_queue.size()
		)


		_schedule_body_contract_refresh_queue_drain(
			0.18
		)
		return

	set_meta(
		"body_contract_runtime_drain_last_yielded",
		false
	)

	var report: Dictionary = (
		drain_body_contract_refresh_queue(
			1,
			{
				"source": "body_contract_runtime_deferred_drain",
				"max_actor_rows_per_quantum": 1
			}
		)
	)

	var remaining: int = int(
		report.get(
			"remaining",
			body_contract_runtime_queue.size()
		)
	)

	set_meta(
		"body_contract_runtime_drain_last_remaining",
		remaining
	)
	set_meta(
		"body_contract_runtime_drain_last_service_at_ms",
		int(Time.get_ticks_msec())
	)
	set_meta(
		"body_contract_runtime_drain_max_actor_rows_per_quantum",
		1
	)

	if remaining > 0:
		_schedule_body_contract_refresh_queue_drain(
			0.12
		)

func drain_body_contract_refresh_queue(max_count: int = BODY_CONTRACT_RUNTIME_DRAIN_DEFAULT, context: Dictionary = {}) -> Dictionary:
	if typeof(body_contract_runtime_queue) != TYPE_ARRAY:
		body_contract_runtime_queue = []
	if typeof(body_contract_runtime_index) != TYPE_DICTIONARY:
		body_contract_runtime_index = {}

	var started_ms: int = int(Time.get_ticks_msec())
	var budget: int = clamp(max_count, 1, 16)
	var processed: int = 0
	var refreshed: Array = []
	var skipped: Array = []

	while processed < budget and not body_contract_runtime_queue.is_empty():
		if int(Time.get_ticks_msec()) - started_ms >= 2:
			break

		var row_raw: Variant = body_contract_runtime_queue.pop_front()
		if typeof(row_raw) != TYPE_DICTIONARY:
			processed += 1
			continue

		var row: Dictionary = row_raw as Dictionary
		var actor_id: int = int(row.get("actor_id", -1))
		body_contract_runtime_index.erase(str(actor_id))

		var actor: Person = _body_contract_actor_from_id(actor_id, true)
		if actor == null:
			skipped.append({
				"actor_id": actor_id,
				"reason": "actor_not_loaded"
			})
			processed += 1
			continue

		var row_context: Dictionary = _safe_dictionary(row.get("context", {}))
		var merged_context: Dictionary = _merge_body_runtime_context(row_context, context)
		merged_context ["source"] = str(row_context.get("source", context.get("source", "drain_body_contract_refresh_queue")))
		merged_context ["force_sync"] = true
		merged_context ["refresh_person_contract"] = false
		merged_context ["defer_parent_resolution"] = true

		var report: Dictionary = {}
		if bool(merged_context.get("yearly_tick", false)):
			report = yearly_tick_body_contracts_for_person(actor, merged_context)
		else:
			report = _ensure_body_contracts_for_person_sync(actor, merged_context)

		refreshed.append({
			"actor_id": actor_id,
			"ready": bool(report.get("ready", true)),
			"source": str(merged_context.get("source", ""))
		})

		processed += 1

	_rebuild_body_contract_runtime_index()

	body_contract_runtime_report = {
		"schema": "eralife.body_contract_runtime_queue_report",
		"version": 1,
		"success": true,
		"processed": processed,
		"refreshed": refreshed,
		"skipped": skipped,
		"remaining": body_contract_runtime_queue.size(),
		"duration_ms": int(Time.get_ticks_msec()) - started_ms,
		"source": str(context.get("source", "drain_body_contract_refresh_queue")),
		"updated_at_ms": int(Time.get_ticks_msec())
	}

	if typeof(scenario_state) == TYPE_DICTIONARY:
		scenario_state ["last_body_contract_runtime_report"] = body_contract_runtime_report.duplicate(true)

	return body_contract_runtime_report.duplicate(true)


func _ensure_body_contracts_for_person_sync(person: Person, context: Dictionary = {}) -> Dictionary:
	if person == null:
		return {}

	var safe_context: Dictionary = context.duplicate(true)
	safe_context ["source"] = str(safe_context.get("source", "game_state_body_contracts_sync"))

	if not safe_context.has("defer_parent_resolution"):
		safe_context ["defer_parent_resolution"] = true

	if genetics_inheritance_engine != null and genetics_inheritance_engine.has_method("ensure_genetics_contract"):
		genetics_inheritance_engine.ensure_genetics_contract(person, {
			"source": str(safe_context.get("source", "game_state_body_contracts_sync")),
			"stage": "genetics",
			"defer_parent_resolution": bool(safe_context.get("defer_parent_resolution", true))
		})

	if body_type_contract_engine != null and body_type_contract_engine.has_method("ensure_body_type_contract"):
		body_type_contract_engine.ensure_body_type_contract(person, {
			"source": str(safe_context.get("source", "game_state_body_contracts_sync")),
			"stage": "body_type"
		})

	if growth_curve_engine != null and growth_curve_engine.has_method("ensure_growth_curve_contract"):
		growth_curve_engine.ensure_growth_curve_contract(person, {
			"source": str(safe_context.get("source", "game_state_body_contracts_sync")),
			"stage": "growth_curve"
		})

	if height_contract_engine != null and height_contract_engine.has_method("ensure_height_contract"):
		height_contract_engine.ensure_height_contract(person, {
			"source": str(safe_context.get("source", "game_state_body_contracts_sync")),
			"stage": "height"
		})

	var weight_report: Dictionary = {}
	if weight_contract_engine != null and weight_contract_engine.has_method("ensure_weight_contract"):
		weight_report = weight_contract_engine.ensure_weight_contract(person, {
			"source": str(safe_context.get("source", "game_state_body_contracts_sync")),
			"stage": "weight"
		})

	if bool(safe_context.get("refresh_person_contract", false)) and person.has_method("ensure_person_contract"):
		person.ensure_person_contract({
			"source": str(safe_context.get("source", "game_state_body_contracts_sync")),
		})

	var bundle: Dictionary = _cached_body_contract_bundle_for_person(person, safe_context)
	bundle ["success"] = true
	bundle ["ready"] = _body_contract_bundle_has_visible_truth(bundle)
	bundle ["deferred"] = false
	bundle ["queued"] = false
	bundle ["weight_report"] = weight_report.duplicate(true)
	return bundle


func _cached_body_contract_bundle_for_person(person: Person, context: Dictionary = {}) -> Dictionary:
	if person == null:
		return {}

	var genetics_contract: Dictionary = person.genetics_contract.duplicate(true) if typeof(person.genetics_contract) == TYPE_DICTIONARY else {}
	var body_type_contract: Dictionary = person.body_type_contract.duplicate(true) if typeof(person.body_type_contract) == TYPE_DICTIONARY else {}
	var growth_curve_contract: Dictionary = person.growth_curve_contract.duplicate(true) if typeof(person.growth_curve_contract) == TYPE_DICTIONARY else {}
	var height_contract: Dictionary = person.height_contract.duplicate(true) if typeof(person.height_contract) == TYPE_DICTIONARY else {}
	var weight_contract: Dictionary = person.weight_contract.duplicate(true) if typeof(person.weight_contract) == TYPE_DICTIONARY else {}
	var body_contract: Dictionary = person.body_contract.duplicate(true) if typeof(person.body_contract) == TYPE_DICTIONARY else {}

	return {
		"success": true,
		"actor_id": int(person.id),
		"genetics_contract": genetics_contract,
		"body_type_contract": body_type_contract,
		"growth_curve_contract": growth_curve_contract,
		"height_contract": height_contract,
		"weight_contract": weight_contract,
		"body_contract": body_contract,
		"source": str(context.get("source", "cached_body_contract_bundle_for_person")),
	}

func body_contracts_may_run_for_ui_context(context: Dictionary = {}) -> bool:
	if typeof(scenario_state) != TYPE_DICTIONARY:
		return true

	var source: String = str(context.get("source", "")).strip_edges().to_lower()

	if bool(scenario_state.get("god_mode_open_may_not_block_ui", false)):
		return false
	if bool(scenario_state.get("god_mode_life_entry_zero_frame_required", false)):
		return false
	if bool(scenario_state.get("defer_noncritical_systems_until_player_control", false)):
		return false
	if bool(scenario_state.get("birth_shell_first_boot_active", false)):
		return false
	if bool(scenario_state.get("post_spawn_ui_finalize_pending", false)):
		return false
	if bool(scenario_state.get("ui_background_reconciliation_streaming", false)) and source.find("relationship") < 0:
		return false

	return true
func _body_contract_bundle_has_visible_truth(bundle: Dictionary) -> bool:
	var height_contract: Dictionary = _safe_dictionary(bundle.get("height_contract", {}))
	var weight_contract: Dictionary = _safe_dictionary(bundle.get("weight_contract", {}))
	var body_type_contract: Dictionary = _safe_dictionary(bundle.get("body_type_contract", {}))

	return (
		str(height_contract.get("display", "")).strip_edges() != ""
		or str(weight_contract.get("display", "")).strip_edges() != ""
		or str(body_type_contract.get("display_name", "")).strip_edges() != ""
	)


func _body_contracts_should_defer_for_context(
	context: Dictionary = {}
) -> bool:
	if bool(
		context.get(
			"force_sync",
			false
		)
	):
		return false

	if has_method(
		"body_contracts_may_run_for_ui_context"
	):
		if not body_contracts_may_run_for_ui_context(
			context
		):
			return true

	var source: String = str(
		context.get(
			"source",
			""
		)
	).strip_edges().to_lower()

	if bool(
		context.get(
			"defer",
			false
		)
	):
		return true

	if source.find(
		"boxing_fighter_engine.initialize_fighter"
	) >= 0:
		return true

	if source.find("god_mode") >= 0:
		return true

	if source.find("prewarm") >= 0:
		return true

	if source.find("spawn") >= 0:
		return true

	if source.find("boot") >= 0:
		return true

	if typeof(scenario_state) != TYPE_DICTIONARY:
		return false

	if bool(
		scenario_state.get(
			"post_spawn_ui_finalize_pending",
			false
		)
	):
		return true

	if bool(
		scenario_state.get(
			"post_spawn_world_prewarm_pending",
			false
		)
	):
		return true

	if bool(
		scenario_state.get(
			"birth_shell_first_boot",
			false
		)
	):
		return true

	if bool(
		scenario_state.get(
			"birth_shell_first_boot_active",
			false
		)
	):
		return true

	if bool(
		scenario_state.get(
			"birth_shell_deferred_boot_pending",
			false
		)
	):
		return true

	if bool(
		scenario_state.get(
			"life_runtime_systems_quarantined",
			false
		)
	):
		return true

	if (
		bool(
			scenario_state.get(
				"defer_static_world_bootstrap",
				false
			)
		)
		and not bool(
			scenario_state.get(
				"post_spawn_world_prewarm_complete",
				false
			)
		)
	):
		return true

	if (
		bool(
			scenario_state.get(
				"defer_live_runtime_watchers",
				false
			)
		)
		and not bool(
			scenario_state.get(
				"post_spawn_world_prewarm_complete",
				false
			)
		)
	):
		return true

	var guard_raw: Variant = (
		scenario_state.get(
			"runtime_guard",
			{}
		)
	)
	var guard: Dictionary = (
		guard_raw
		if typeof(guard_raw) == TYPE_DICTIONARY
		else {}
	)

	if bool(
		guard.get(
			"defer_noncritical_systems",
			false
		)
	):
		return true

	if bool(
		guard.get(
			"ui_tail_work_yield_to_input",
			false
		)
	):
		var now_ms: int = int(
			Time.get_ticks_msec()
		)
		var ui_grace_until_ms: int = int(
			guard.get(
				"ui_interaction_grace_until_ms",
				0
			)
		)




		if (
			ui_grace_until_ms <= 0
			or now_ms < ui_grace_until_ms
		):
			return true



		guard [
			"ui_tail_work_yield_to_input"
		] = false
		scenario_state [
			"runtime_guard"
		] = guard

	return false

func _body_contract_focus_people_for_tail_work(limit: int = 24) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	var clean_limit: int = clamp(limit, 1, 80)

	if player != null:
		out.append(player)
		seen [int(player.id)] = true

		for raw_id in player.parents:
			var pid: int = int(raw_id)
			if pid > 0 and not seen.has(pid):
				var parent: Person = _body_contract_actor_from_id(pid, false)
				if parent != null:
					out.append(parent)
					seen [pid] = true

		for raw_id in player.children:
			var cid: int = int(raw_id)
			if cid > 0 and not seen.has(cid):
				var child: Person = _body_contract_actor_from_id(cid, false)
				if child != null:
					out.append(child)
					seen [cid] = true

		var partner: Person = get_valid_partner(player, true) if has_method("get_valid_partner") else null
		if partner != null and not seen.has(int(partner.id)):
			out.append(partner)
			seen [int(partner.id)] = true

	for npc in npcs:
		if out.size() >= clean_limit:
			break
		if npc == null or not (npc is Person):
			continue
		var npc_id: int = int(npc.id)
		if npc_id <= 0 or seen.has(npc_id):
			continue
		out.append(npc)
		seen [npc_id] = true

	return out


func _body_contract_actor_from_payload(payload:= {}, allow_reactivate: bool = false) -> Person:
	if typeof(payload) != TYPE_DICTIONARY:
		return null

	var actor_id: int = int(payload.get("actor_id", payload.get("npc_id", payload.get("person_id", payload.get("target_id", -1)))))
	return _body_contract_actor_from_id(actor_id, allow_reactivate)


func _body_contract_actor_from_id(actor_id: int, allow_reactivate: bool = false) -> Person:
	if actor_id <= 0:
		return null

	var actor: Person = null
	if has_method("get_npc_by_id"):
		actor = get_npc_by_id(actor_id)

	if actor == null and allow_reactivate and has_method("get_or_reactivate_npc_by_id"):
		actor = get_or_reactivate_npc_by_id(actor_id)

	return actor


func _rebuild_body_contract_runtime_index() -> void:
	body_contract_runtime_index.clear()

	for i in range(body_contract_runtime_queue.size()):
		var row_raw: Variant = body_contract_runtime_queue [i]
		if typeof(row_raw) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = row_raw as Dictionary
		var actor_id: int = int(row.get("actor_id", -1))
		if actor_id > 0:
			body_contract_runtime_index [str(actor_id)] = i


func _merge_body_runtime_context(base: Dictionary, patch: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	for key in patch.keys():
		out [key] = patch [key]
	return out



func _serialize_npc(npc: Person) -> Dictionary:
	return {
		"id": npc.id,
		"name": npc.name,
		"first_name": npc.first_name,
		"last_name": npc.last_name,
		"gender": npc.gender,
		"age": npc.age,
		"maiden_last_name": npc.maiden_last_name,
		"health": npc.health,
		"hunger": npc.hunger,
		"mental_health": npc.mental_health,
		"smarts": npc.smarts,
		"looks": npc.looks,
		"imagination": npc.imagination,
		"fertility": npc.fertility,
		"job": npc.job,
		"income": npc.income,
		"satisfaction": npc.satisfaction,
		"bank_balance": npc.bank_balance,
		"expenses": npc.expenses,
		"job_performance": npc.job_performance,
		"job_experience": npc.job_experience,
		"unemployed_years": npc.unemployed_years,
		"work_stress": npc.work_stress,
		"hours_worked_last_year": npc.hours_worked_last_year,
		"current_workplace_id": npc.current_workplace_id,
		"coworkers": npc.coworkers,
		"career_profile": npc.career_profile,
		"traits": npc.traits,
		"memories": npc.memories,
		"consciousness_contract": npc.consciousness_contract,
		"consciousness_state": npc.consciousness_state,
		"consciousness_memory_index": npc.consciousness_memory_index,
		"soul_seed_contract": npc.soul_seed_contract,
		"soul_seed_state": npc.soul_seed_state,
		"friends": npc.friends,
		"parents": npc.parents,
		"children": npc.children,
		"partner_id": npc.partner.id if npc.partner != null else -1,
		"alive": npc.alive,
		"birth_city": npc.birth_city,
		"birth_country": npc.birth_country,
		"birthday": npc.birthday,
		"zodiac": npc.zodiac,
		"affection": npc.affection,
		"cause_of_death": npc.cause_of_death,
		"death_year": npc.death_year,
		"fate_arc": npc.fate_arc,
		"dynasty_origin": npc.dynasty_origin,
		"dynasty_prestige": npc.dynasty_prestige,
		"fame": npc.fame,
		"fame_tier": npc.fame_tier,
		"fame_job": npc.fame_job,
		"scandal": npc.scandal,
		"paparazzi_heat": npc.paparazzi_heat,
		"social_class": npc.social_class,
		"class_mobility": npc.class_mobility,
		"is_royal": npc.is_royal,
		"royal_title": npc.royal_title,
		"realm_id": npc.realm_id,
		"settlement_id": npc.settlement_id,
		"district_id": npc.district_id,
		"locality_id": npc.locality_id,
		"origin_settlement_id": npc.origin_settlement_id,
		"origin_district_id": npc.origin_district_id,
		"origin_locality_id": npc.origin_locality_id,
		"birthplace_settlement_id": npc.birthplace_settlement_id,
		"approval": npc.approval,
		"is_ruler": npc.is_ruler,
		"succession_rank": npc.succession_rank,
		"exiled": npc.exiled,
		"deposed": npc.deposed,
		"palace_owned": npc.palace_owned,
		"parents_exploit_fame": npc.parents_exploit_fame,
		"has_many_realms_ring": npc.has_many_realms_ring,
		"hidden_realm_id": npc.hidden_realm_id,
		"hidden_realm_title": npc.hidden_realm_title,
		"hidden_realm_visible": npc.hidden_realm_visible,
		"marital_status": npc.marital_status,
		"ex_partners": npc.ex_partners,
		"home_city": npc.home_city,
		"home_country": npc.home_country,
		"diaspora_tags": npc.diaspora_tags,
		"identity_residue": npc.identity_residue,
		"place_identity_tags": npc.place_identity_tags,
		"locality_faction_affinities": npc.locality_faction_affinities,
		"years_in_current_place": npc.years_in_current_place,
		"total_place_moves": npc.total_place_moves,
		"last_place_shift_year": npc.last_place_shift_year,
		"place_echo_stack": npc.place_echo_stack,
		"place_influence_profile": npc.place_influence_profile,
		"place_conflict_profile": npc.place_conflict_profile,
		"place_trait_drift_profile": npc.place_trait_drift_profile,
		"place_influence_strength": npc.place_influence_strength,
		"place_identity_summary": npc.place_identity_summary,
		"place_yearly_snapshots": npc.place_yearly_snapshots,
		"place_adaptation_flags": npc.place_adaptation_flags,
		"pregnant_by_id": npc.pregnant_by_id,
		"pregnancy_progress": npc.pregnancy_progress,
		"unborn_child_other_parent_id": npc.unborn_child_other_parent_id,
		"pregnancy_known": npc.pregnancy_known,
		"pregnancy_context": npc.pregnancy_context,
		"bending_type": npc.bending_type,
		"bending_mastery": npc.bending_mastery,
		"bending_latent_potential": npc.bending_latent_potential,
		"avatar_state_unlocked": npc.avatar_state_unlocked,
		"avatar_state_used": npc.avatar_state_used,
		"bending_nation": npc.bending_nation,
		"wizard_profile": npc.wizard_profile,
		"school_mode": npc.school_mode,
		"school_name": npc.school_name,
		"school_status": npc.school_status,
		"education_level": npc.education_level,
		"schoolmates": npc.schoolmates,
		"desires": npc.desires,
		"motivation": npc.motivation,
		"ambition": npc.ambition,
		"long_term_goals": npc.long_term_goals,
		"strategic_focus": npc.strategic_focus,
		"capabilities": npc.capabilities,
		"combat_sports_unlocked": npc.combat_sports_unlocked,
		"boxing_profile": npc.boxing_profile,
		"genetics_contract": npc.genetics_contract,
		"body_type_contract": npc.body_type_contract,
		"growth_curve_contract": npc.growth_curve_contract,
		"height_contract": npc.height_contract,
		"weight_contract": npc.weight_contract,
		"body_contract": npc.body_contract,
		"vampire_profile": npc.vampire_profile,
		"power_profiles": npc.power_profiles,
		"combat_profiles": npc.combat_profiles,
		"supernatural_contracts": npc.supernatural_contracts,
		"inherited_systems": npc.inherited_systems,
		"world_law_residue": npc.world_law_residue,
		"reality_fusion_identity": npc.reality_fusion_identity,
		"tap_to_play_identity": npc.tap_to_play_identity,
		"person_contract": npc.person_contract,
		"person_contract_slice": npc.call("export_contract_slice", {
			"source": "serialize_npc",
		}) if npc.has_method("export_contract_slice") else {},
		"last_minor_illness_age": npc.last_minor_illness_age,
		"terabithia_state": npc.terabithia_state,
	}
func _deserialize_npc(d: Dictionary) -> Person:
	var p = Person.new()

	for prop in p.get_property_list():
		var name = prop.name
		if d.has(name):
			p.set(name, d [name])

	if typeof(p.consciousness_contract) != TYPE_DICTIONARY:
		p.consciousness_contract = {}
	if typeof(p.consciousness_state) != TYPE_DICTIONARY:
		p.consciousness_state = {}
	if typeof(p.consciousness_memory_index) != TYPE_ARRAY:
		p.consciousness_memory_index = []
	if typeof(p.soul_seed_contract) != TYPE_DICTIONARY:
		p.soul_seed_contract = {}
	if typeof(p.soul_seed_state) != TYPE_DICTIONARY:
		p.soul_seed_state = {}

	var person_contract_slice_raw: Variant = d.get("person_contract_slice", {})
	if typeof(person_contract_slice_raw) == TYPE_DICTIONARY and p.has_method("import_contract_slice"):
		p.call("import_contract_slice", person_contract_slice_raw as Dictionary, {
			"source": "deserialize_npc",
		})
	elif p.has_method("ensure_person_contract"):
		p.call("ensure_person_contract", {
			"source": "deserialize_npc_legacy_fields",
		})

	var should_repair_consciousness: bool = consciousness_engine != null
	if should_repair_consciousness and typeof(scenario_state) == TYPE_DICTIONARY:
		should_repair_consciousness = not bool(scenario_state.get("defer_deserialize_consciousness_repair", false))

	if should_repair_consciousness:
		consciousness_engine.ensure_consciousness(p, {
			"source": "deserialize_npc"
		})

	return p
func _build_serializable_scenario_state() -> Dictionary:
	if typeof(scenario_state) != TYPE_DICTIONARY:
		return {}

	var serializable: Dictionary = scenario_state.duplicate(true)
	serializable.erase("rewind_snapshot_pipeline")
	serializable.erase("loading_runtime")
	serializable.erase("runtime_guard")
	serializable.erase("runtime_slice_guard")
	serializable.erase("game_state_contract_runtime_guard")
	serializable.erase("game_state_contract_last_boot_report")
	serializable.erase("game_state_contract_hydration_report")
	serializable.erase("game_state_contract_validation_report")
	serializable.erase("game_state_contract_migration_report")
	serializable.erase("game_state_contract_recovery_report")
	serializable.erase("runtime_phase_budget_report")
	return serializable



func resolve_title_card_identity_contract(
	context: Dictionary = {}
) -> Dictionary:
	_ensure_identity_checkpoint_runtime_dependencies()

	var identity_report: Dictionary = (
		identity_contract_engine.resolve_local_identity({
			"source": str(
				context.get(
					"source",
					"resolve_title_card_identity_contract"
				)
			),
		})
	)
	var identity_context: Dictionary = (
		identity_report.get(
			"identity_context",
			{}
		)
		if typeof(
			identity_report.get(
				"identity_context",
				{}
			)
		) == TYPE_DICTIONARY
		else {}
	)
	var is_guest: bool = bool(
		identity_context.get(
			"is_guest",
			true
		)
	)
	var continue_contract: Dictionary = (
		life_account_transfer_contract_engine.emit_title_card_continue_contract({
			"source": str(
				context.get(
					"source",
					"resolve_title_card_identity_contract"
				)
			),
			"identity_context": (
				identity_context.duplicate(true)
			)
		})
	)
	var continue_available: bool = bool(
		continue_contract.get(
			"available",
			false
		)
	)
	var report_mode: String = (
		"guest_continue_ready"
		if (
			is_guest
			and continue_available
		)
		else (
			"eraccount_continue_ready"
			if continue_available
			else (
				"guest_ready"
				if is_guest
				else "account_ready_without_life"
			)
		)
	)
	var report: Dictionary = {
		"schema": (
			"eralife.title_card.identity_contract"
		),
		"version": 2,
		"success": bool(
			identity_report.get(
				"success",
				false
			)
		),
		"mode": report_mode,
		"is_guest": is_guest,
		"continue_available": continue_available,
		"continue_contract": (
			continue_contract.duplicate(true)
		),
		"checkpoint_hydration_allowed": (
			continue_available
		),
		"legacy_life_attachment_available": bool(
			continue_contract.get(
				"legacy_attachment_available",
				false
			)
		),
		"identity_context": (
			identity_context.duplicate(true)
		),
		"context": context.duplicate(true),
		"created_at_ms": int(
			Time.get_ticks_msec()
		),
		"contract_mesh": {
			"identity_authority": (
				"IdentityContractEngine"
			),
			"continue_authority": (
				"LifeAccountTransferContractEngine"
			),
			"checkpoint_authority": (
				"RealityCheckpointContractEngine"
			),
			"ui_is_lens": true,
		}
	}

	scenario_state [
		"title_card_identity_contract"
	] = report.duplicate(true)
	scenario_state [
		"title_card_continue_contract"
	] = continue_contract.duplicate(true)

	return report
func _ensure_identity_checkpoint_runtime_dependencies() -> void:
		if typeof(scenario_state) != TYPE_DICTIONARY:
			scenario_state = {}

		if identity_contract_engine == null:
			identity_contract_engine = IdentityContractEngine.new(
				self
			)

		if email_verification_transport_engine == null:
			email_verification_transport_engine = (
				EmailVerificationTransportEngine.new(
					self
				)
			)

		if compression == null:
			compression = Compression.new(
				self
			)

		if connection_graph_network == null:
			connection_graph_network = ConnectionGraphNetwork.new(
				self
			)

		if messenger_contract_engine == null:
			messenger_contract_engine = MessengerContractEngine.new(
				self
			)

		if mailbox_contract_engine == null:
			mailbox_contract_engine = MailBoxContractEngine.new(
				self
			)

		if eraccount_profile_contract_engine == null:
			eraccount_profile_contract_engine = (
				ErAccountProfileContractEngine.new(
					self
				)
			)

		if network_notes_contract_engine == null:
			network_notes_contract_engine = (
				NetworkNotesContractEngine.new(
					self
				)
			)

		if public_feed_contract_engine == null:
			public_feed_contract_engine = (
				PublicFeedContractEngine.new(
					self
				)
			)

		if reality_stream_contract_engine == null:
			reality_stream_contract_engine = (
				RealityStreamContractEngine.new(
					self
				)
			)

		if life_account_transfer_contract_engine == null:
			life_account_transfer_contract_engine = (
				LifeAccountTransferContractEngine.new(
					self
				)
			)

		if self_host_network_contract_engine == null:
			self_host_network_contract_engine = (
				SelfHostNetworkContractEngine.new(
					self
				)
			)

		if search_contract_engine == null:
			search_contract_engine = SearchContractEngine.new(
				self
			)

		if eralife_network_contract_engine == null:
			eralife_network_contract_engine = (
				EraLifeNetworkContractEngine.new(
					self
				)
			)
		elif eralife_network_contract_engine.has_method(
			"bind_game_state"
		):
			eralife_network_contract_engine.bind_game_state(
				self
			)

		if (
			reality_stream_contract_engine != null
			and reality_stream_contract_engine.has_method(
				"bind_event_bus"
			)
		):
			reality_stream_contract_engine.bind_event_bus()

		if crr_contract_engine == null:
			crr_contract_engine = CRRContractEngine.new(
				self
			)

		if military_contract_engine == null:
			military_contract_engine = MilitaryContractEngine.new(
				self
			)




		ensure_war_contract_runtime_authority()

		if battle_contract_engine == null:
			battle_contract_engine = BattleContractEngine.new(
				self
			)

		if battle_sim_contract_engine == null:
			battle_sim_contract_engine = BattleSimContractEngine.new(
				self
			)

		if battle_ui_contract_engine == null:
			battle_ui_contract_engine = BattleUIContractEngine.new(
				self
			)

		if session_contract_engine == null:
			session_contract_engine = SessionContractEngine.new(
				self
			)

		if reality_checkpoint_contract_engine == null:
			reality_checkpoint_contract_engine = (
				RealityCheckpointContractEngine.new(
					self
				)
			)

		if reality_merge_contract_engine == null:
			reality_merge_contract_engine = (
				RealityMergeContractEngine.new(
					self
				)
			)
func resolve_boot_reality_contract(context: Dictionary = {}) -> Dictionary:
	_ensure_identity_checkpoint_runtime_dependencies()

	var identity_report: Dictionary = identity_contract_engine.resolve_local_identity({
		"source": str(context.get("source", "resolve_boot_reality_contract"))
	})
	var identity_context: Dictionary = identity_report.get("identity_context", {}) if typeof(identity_report.get("identity_context", {})) == TYPE_DICTIONARY else {}

	if bool(context.get("attach_cloud_identity", false)):
		identity_contract_engine.attach_cloud_identity_async(
			context.get("cloud_identity", {}) if typeof(context.get("cloud_identity", {})) == TYPE_DICTIONARY else {},
			{ "source": "boot_reality_contract"}
		)
		identity_context = identity_contract_engine.emit_identity_context({ "source": "boot_after_cloud_attach"})

	var allow_checkpoint_scan: bool = bool(context.get("allow_checkpoint_scan", false))
	var allow_guest_auto_enter: bool = bool(context.get("allow_guest_auto_enter", false))
	var is_guest: bool = bool(identity_context.get("is_guest", true))

	if not allow_checkpoint_scan:
		var title_report: Dictionary = {
			"schema": "eralife.boot.reality_contract",
			"version": 1,
			"success": true,
			"action": "title_card_identity_surface",
			"identity_context": identity_context.duplicate(true),
			"session_context": {},
			"checkpoint_candidates": {},
			"merge_report": {},
			"integrity_report": {},
			"resolved_checkpoint": {},
			"checkpoint_path": "",
			"fallback": "cinematic_path",
			"reason": "checkpoint_scan_deferred_until_title_card_choice",
			"created_at_ms": int(Time.get_ticks_msec()),
			"contract_mesh": {
				"source_of_truth": "GameState.resolve_boot_reality_contract",
				"ui_is_lens": true,
			}
		}
		scenario_state ["boot_reality_contract"] = title_report.duplicate(true)
		return title_report

	var session_context: Dictionary = session_contract_engine.try_restore_last_session_pointer(identity_context, {
		"source": "boot_reality_contract"
	})
	var checkpoint_candidates: Dictionary = reality_checkpoint_contract_engine.emit_checkpoint_candidates(identity_context, session_context, {
		"source": "boot_reality_contract",
	})
	var merge_report: Dictionary = reality_merge_contract_engine.resolve_truth_authority(checkpoint_candidates, identity_context, session_context)
	var resolved_checkpoint: Dictionary = merge_report.get("resolved_checkpoint", {}) if typeof(merge_report.get("resolved_checkpoint", {})) == TYPE_DICTIONARY else {}
	var integrity_report: Dictionary = reality_integrity_contract_engine.validate_snapshot(resolved_checkpoint, {
		"source": "boot_reality_contract",
	})
	var repaired_integrity: Dictionary = reality_integrity_contract_engine.repair_if_needed(integrity_report, {
		"source": "boot_reality_contract"
	})

	var can_auto_enter: bool = bool(context.get("auto_enter_enabled", false))
	can_auto_enter = can_auto_enter and bool(identity_report.get("success", false))
	can_auto_enter = can_auto_enter and bool(merge_report.get("success", false))
	can_auto_enter = can_auto_enter and bool(repaired_integrity.get("valid", false))
	can_auto_enter = can_auto_enter and (allow_guest_auto_enter or not is_guest)

	var action: String = "hydrate_reality" if can_auto_enter else "title_card_identity_surface"
	var report: Dictionary = {
		"schema": "eralife.boot.reality_contract",
		"version": 1,
		"success": true,
		"action": action,
		"silent_auto_enter": can_auto_enter,
		"skip_cinematic": can_auto_enter,
		"skip_title_card": can_auto_enter,
		"skip_main_menu": can_auto_enter,
		"identity_context": identity_context.duplicate(true),
		"session_context": session_context.duplicate(true),
		"checkpoint_candidates": checkpoint_candidates.duplicate(true),
		"merge_report": merge_report.duplicate(true),
		"integrity_report": repaired_integrity.duplicate(true),
		"resolved_checkpoint": resolved_checkpoint.duplicate(true),
		"checkpoint_path": str(resolved_checkpoint.get("checkpoint_path", "")),
		"fallback": "cinematic_path" if not can_auto_enter else "",
		"reason": "guest_auto_enter_blocked" if is_guest and not allow_guest_auto_enter else "",
		"created_at_ms": int(Time.get_ticks_msec()),
		"contract_mesh": {
			"source_of_truth": "GameState.resolve_boot_reality_contract",
			"ui_is_lens": true,
		}
	}

	scenario_state ["boot_reality_contract"] = report.duplicate(true)
	return report
func create_or_attach_eralife_account_contract(context: Dictionary = {}) -> Dictionary:
	_ensure_identity_checkpoint_runtime_dependencies()

	var identity_report: Dictionary = identity_contract_engine.create_or_attach_eralife_account(context)
	var identity_context: Dictionary = identity_report.get("identity_context", {}) if typeof(identity_report.get("identity_context", {})) == TYPE_DICTIONARY else {}

	var report: Dictionary = {
		"schema": "eralife.account.attach_report",
		"version": 1,
		"success": bool(identity_report.get("success", false)),
		"mode": str(identity_report.get("mode", "account_attach_attempted")),
		"identity_context": identity_context.duplicate(true),
		"verification_transport": identity_report.get("verification_transport", {}) if typeof(identity_report.get("verification_transport", {})) == TYPE_DICTIONARY else {},
		"context": context.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec()),
		"contract_mesh": {
			"source_of_truth": "IdentityContractEngine",
			"verification_transport_owner": "EmailVerificationTransportEngine",
			"ui_is_lens": true,
		}
	}

	scenario_state ["last_eralife_account_attach_report"] = report.duplicate(true)
	return report

func hydrate_resolved_boot_checkpoint(boot_contract: Dictionary = {}, options: Dictionary = {}) -> Dictionary:
	_ensure_load_game_runtime_dependencies()
	_ensure_identity_checkpoint_runtime_dependencies()

	var resolved_checkpoint: Dictionary = boot_contract.get("resolved_checkpoint", {}) if typeof(boot_contract.get("resolved_checkpoint", {})) == TYPE_DICTIONARY else boot_contract.duplicate(true)
	var hydrate_options: Dictionary = {
		"source": str(options.get("source", "hydrate_resolved_boot_checkpoint")),
		"profile": str(options.get("profile", "silent_auto_enter")),
		"entry_surface": str(options.get("entry_surface", "silent_auto_enter")),
		"background_enabled": true,
		"playable_npc_limit": int(options.get("playable_npc_limit", 24))
	}
	for key in options.keys():
		hydrate_options [key] = options [key]

	var report: Dictionary = world_contract_hydrator.hydrate_resolved_checkpoint(resolved_checkpoint, hydrate_options)
	scenario_state ["last_boot_checkpoint_hydration_report"] = report.duplicate(true)
	return report

func _collect_resume_engine_registry() -> Dictionary:
	# The player-visible engine stores, read defensively so a missing engine costs
	# only its own entry rather than the whole registry.
	var registry: Dictionary = {}

	if vehicle_engine != null and typeof(vehicle_engine.vehicles) == TYPE_DICTIONARY:
		registry ["vehicles"] = vehicle_engine.vehicles.duplicate(true)

	if belongings_engine != null and typeof(belongings_engine.belongings) == TYPE_DICTIONARY:
		registry ["belongings"] = belongings_engine.belongings.duplicate(true)

	if property_engine != null:
		if typeof(property_engine.properties) == TYPE_DICTIONARY:
			registry ["properties"] = property_engine.properties.duplicate(true)

		if typeof(property_engine.used_addresses) == TYPE_DICTIONARY:
			registry ["used_addresses"] = property_engine.used_addresses.duplicate(true)

	if heirloom_engine != null and typeof(heirloom_engine.heirlooms) == TYPE_DICTIONARY:
		registry ["heirlooms"] = heirloom_engine.heirlooms.duplicate(true)

	EraLog.truth(
		"ERALIFE_RESUME_REGISTRY_SAVED|keys=%d|vehicles=%s|belongings=%s"
		% [
			registry.size(),
			str(registry.has("vehicles")),
			str(registry.has("belongings"))
		]
	)

	return registry


func commit_current_life_checkpoint_contract(
	path: String,
	save_report: Dictionary = {},
	options: Dictionary = {}
) -> Dictionary:
	var checkpoint_dependencies_must_be_hot: bool = bool(
		options.get(
			"checkpoint_dependencies_must_be_hot",
			false
		)
	)

	if checkpoint_dependencies_must_be_hot:
		var missing_checkpoint_authorities: Array = []

		for authority_row in [
			[
				"identity_contract_engine",
				identity_contract_engine
			],
			[
				"life_account_transfer_contract_engine",
				life_account_transfer_contract_engine
			],
			[
				"session_contract_engine",
				session_contract_engine
			],
			[
				"reality_checkpoint_contract_engine",
				reality_checkpoint_contract_engine
			]
		]:
			if authority_row [1] == null:
				missing_checkpoint_authorities.append(
					str(authority_row [0])
				)

		if not missing_checkpoint_authorities.is_empty():
			return {
				"schema": (
					"eralife.reality_checkpoint_commit_report"
				),
				"version": 3,
				"success": false,
				"reason": (
					"checkpoint_authorities_not_resident"
				),
				"missing": missing_checkpoint_authorities,
				"created_at_ms": int(
					Time.get_ticks_msec()
				)
			}
	else:
		_ensure_identity_checkpoint_runtime_dependencies()
	var clean_path: String = str(
		path
	).strip_edges()

	if clean_path == "":
		return {
			"success": false,
			"reason": "checkpoint_path_missing"
		}

	if typeof(
		scenario_state
	) != TYPE_DICTIONARY:
		scenario_state = {}

	var identity_report: Dictionary = (
		identity_contract_engine.resolve_local_identity({
			"source": (
				"commit_current_life_checkpoint_contract"
			)
		})
	)
	var identity_raw: Variant = (
		identity_report.get(
			"identity_context",
			{}
		)
	)
	var identity_context: Dictionary = (
		identity_raw as Dictionary
		if typeof(
			identity_raw
		) == TYPE_DICTIONARY
		else {}
	)
	var is_guest: bool = bool(
		identity_context.get(
			"is_guest",
			true
		)
	)
	var local_identity_id: String = str(
		identity_context.get(
			"local_identity_id",
			identity_context.get(
				"identity_id",
				""
			)
		)
	).strip_edges()
	var cloud_identity_id: String = str(
		identity_context.get(
			"cloud_identity_id",
			""
		)
	).strip_edges()
	var effective_owner_identity_id: String = (
		local_identity_id
		if is_guest
		else cloud_identity_id
	)

	if effective_owner_identity_id == "":
		effective_owner_identity_id = (
			local_identity_id
		)

	var life_id: String = str(
		options.get(
			"life_id",
			scenario_state.get(
				"life_id",
				""
			)
		)
	).strip_edges()

	if life_id == "":
		life_id = (
			"life_%s_%d"
			% [
				(
					effective_owner_identity_id
					if effective_owner_identity_id != ""
					else "local"
				),
				int(
					Time.get_unix_time_from_system()
				)
			]
		)

	scenario_state [
		"life_id"
	] = life_id

	var actor_id: int = (
		int(
			player.id
		)
		if player != null
		else int(
			player_id
		)
	)
	var branch_id: String = str(
		options.get(
			"branch_id",
			scenario_state.get(
				"life_branch_id",
				"main"
			)
		)
	).strip_edges()

	if branch_id == "":
		branch_id = "main"

	scenario_state [
		"life_branch_id"
	] = branch_id

	var residency_signature: String = str(
		options.get(
			"residency_signature",
			options.get(
				"checkpoint_residency_signature",
				scenario_state.get(
					"resident_runtime_attached_signature",
					scenario_state.get(
						"resident_runtime_signature",
						""
					)
				)
			)
		)
	).strip_edges()
	var checkpoint_current_panel: String = str(
		options.get(
			"checkpoint_current_panel",
			options.get(
				"current_panel",
				options.get(
					"active_context",
					"life"
				)
			)
		)
	).strip_edges().to_lower()

	if checkpoint_current_panel == "":
		checkpoint_current_panel = "life"

	var first_frame_raw: Variant = (
		options.get(
			"checkpoint_first_frame_snapshot",
			scenario_state.get(
				"zero_frame_consciousness_switch_surface",
				scenario_state.get(
					"prebuilt_first_frame_ui_snapshot",
					{}
				)
			)
		)
	)
	var checkpoint_first_frame_snapshot: Dictionary = (
		(first_frame_raw as Dictionary).duplicate(false)
		if typeof(
			first_frame_raw
		) == TYPE_DICTIONARY
		else {}
	)
	var actor_snapshot: Dictionary = {}

	if player != null:
		actor_snapshot = _serialize_npc(
			player
		)

	var checkpoint_resume_contract: Dictionary = {
		"schema": (
			"eralife.reality_checkpoint.resume_contract"
		),
		"version": 1,
		"checkpoint_path": clean_path,
		"residency_signature": residency_signature,
		"life_id": life_id,
		"branch_id": branch_id,
		"actor_id": actor_id,
		"player_id": actor_id,
		"controlled_actor_id": actor_id,
		"actor_snapshot": actor_snapshot,
		# FIX: a checkpoint resume restores from THIS contract only -- the resume truth
		# line reports full_payload_hydrated=false, so the save payload is never
		# hydrated on load. Money, age and year came back because they live in
		# actor_snapshot; vehicles, belongings, property, heirlooms and pets did not,
		# because nothing carried them. Travel them with the resume contract.
		"engine_registry": _collect_resume_engine_registry(),
		"canonical_relationship_graph": (
			canonical_relationship_graph.duplicate(true)
			if typeof(canonical_relationship_graph) == TYPE_DICTIONARY
			else {}
		),
		"entity_registry": (
			entity_registry.duplicate(true)
			if typeof(entity_registry) == TYPE_DICTIONARY
			else {}
		),
		"year": int(
			year
		),
		"next_id": int(
			next_id
		),
		"current_panel": checkpoint_current_panel,
		"scene_route": str(
			options.get(
				"scene_route",
				checkpoint_current_panel
			)
		),
		"ui_surface": str(
			options.get(
				"ui_surface",
				"life"
			)
		),
		"world_seed": int(
			scenario_state.get(
				"world_seed",
				-1
			)
		),
		"seed_contract": (
			scenario_state.get(
				"seed_contract",
				{}
			)
			if typeof(
				scenario_state.get(
					"seed_contract",
					{}
				)
			) == TYPE_DICTIONARY
			else {}
		),
		"first_frame_ui_snapshot": (
			checkpoint_first_frame_snapshot
		),
		"blank_life_shell_forbidden": true,
		"created_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	var account_attachment_report: Dictionary = {}

	if not is_guest:
		account_attachment_report = (
			life_account_transfer_contract_engine
			.transfer_local_lives_to_current_account(
				[
					clean_path
				],
				{
					"source": (
						"commit_current_life_checkpoint_contract"
					),
					"life_id": life_id,
					"branch_id": branch_id,
					"actor_id": actor_id,
					"checkpoint_path": clean_path,
					"residency_signature": (
						residency_signature
					)
				}
			)
		)

	var attached_raw: Variant = (
		account_attachment_report.get(
			"attached",
			[]
		)
	)
	var attached_rows: Array = (
		attached_raw as Array
		if typeof(
			attached_raw
		) == TYPE_ARRAY
		else []
	)
	var attachment: Dictionary = {}

	if not attached_rows.is_empty():
		var attachment_raw: Variant = (
			attached_rows.front()
		)

		if typeof(
			attachment_raw
		) == TYPE_DICTIONARY:
			attachment = (
				attachment_raw as Dictionary
			).duplicate(false)

	var portable_life_packet_id: String = str(
		attachment.get(
			"portable_life_packet_id",
			scenario_state.get(
				"portable_life_packet_id",
				""
			)
		)
	).strip_edges()

	if portable_life_packet_id != "":
		scenario_state [
			"portable_life_packet_id"
		] = portable_life_packet_id

	var pointer: Dictionary = {
		"identity_id": effective_owner_identity_id,
		"local_identity_id": local_identity_id,
		"cloud_identity_id": cloud_identity_id,
		"device_identity_id": str(
			identity_context.get(
				"device_identity_id",
				""
			)
		),
		"is_guest": is_guest,
		"ownership_scope": (
			"guest_device_unclaimed"
			if is_guest
			else "current_eraccount"
		),
		"life_id": life_id,
		"portable_life_packet_id": (
			portable_life_packet_id
		),
		"branch_id": branch_id,
		"actor_id": actor_id,
		"controlled_actor_id": actor_id,
		"checkpoint_path": clean_path,
		"residency_signature": residency_signature,
		"current_panel": checkpoint_current_panel,
		"checkpoint_resume_contract": (
			checkpoint_resume_contract
		),
		"location": str(
			options.get(
				"location",
				options.get(
					"scene_route",
					checkpoint_current_panel
				)
			)
		),
		"active_context": str(
			options.get(
				"active_context",
				checkpoint_current_panel
			)
		),
		"scene_route": str(
			options.get(
				"scene_route",
				checkpoint_current_panel
			)
		),
		"ui_surface": str(
			options.get(
				"ui_surface",
				"life"
			)
		),
		"updated_at_ms": int(
			Time.get_ticks_msec()
		),
		"timestamp": int(
			Time.get_unix_time_from_system()
		)
	}

	var session_report: Dictionary = (
		session_contract_engine.update_session_pointer(
			pointer,
			{
				"source": (
					"commit_current_life_checkpoint_contract"
				),
				"identity_context": (
					identity_context.duplicate(false)
				)
			}
		)
	)
	var checkpoint_report: Dictionary = (
		reality_checkpoint_contract_engine
		.commit_local_checkpoint(
			pointer,
			{
				"source": (
					"commit_current_life_checkpoint_contract"
				),
				"identity_id": effective_owner_identity_id,
				"local_identity_id": local_identity_id,
				"cloud_identity_id": cloud_identity_id,
				"ownership_scope": (
					pointer ["ownership_scope"]
				),
				"life_id": life_id,
				"portable_life_packet_id": (
					portable_life_packet_id
				),
				"branch_id": branch_id,
				"actor_id": actor_id,
				"controlled_actor_id": actor_id,
				"checkpoint_path": clean_path,
				"residency_signature": residency_signature,
				"current_panel": checkpoint_current_panel,
				"checkpoint_resume_contract": (
					checkpoint_resume_contract
				)
			}
		)
	)
	var report: Dictionary = {
		"schema": (
			"eralife.reality_checkpoint_commit_report"
		),
		"version": 3,
		"success": (
			bool(
				session_report.get(
					"success",
					false
				)
			)
			and bool(
				checkpoint_report.get(
					"success",
					false
				)
			)
		),
		"identity_context": (
			identity_context.duplicate(false)
		),
		"is_guest": is_guest,
		"ownership_scope": (
			pointer ["ownership_scope"]
		),
		"effective_owner_identity_id": (
			effective_owner_identity_id
		),
		"session_report": (
			session_report.duplicate(false)
		),
		"checkpoint_report": (
			checkpoint_report.duplicate(false)
		),
		"account_attachment_report": (
			account_attachment_report.duplicate(false)
		),
		"portable_account_indexed": (
			not is_guest
			and bool(
				account_attachment_report.get(
					"success",
					false
				)
			)
			and int(
				account_attachment_report.get(
					"attached_count",
					0
				)
			) > 0
		),
		"guest_life_remains_unclaimed": is_guest,
		"save_report_summary": (
			save_report.get(
				"summary",
				{}
			)
			if typeof(
				save_report.get(
					"summary",
					{}
				)
			) == TYPE_DICTIONARY
			else {}
		),
		"checkpoint_path": clean_path,
		"residency_signature": residency_signature,
		"life_id": life_id,
		"portable_life_packet_id": (
			portable_life_packet_id
		),
		"branch_id": branch_id,
		"actor_id": actor_id,
		"controlled_actor_id": actor_id,
		"current_panel": checkpoint_current_panel,
		"checkpoint_resume_contract": (
			checkpoint_resume_contract
		),
		"created_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	scenario_state [
		"last_reality_checkpoint_commit_report"
	] = report.duplicate(false)
	scenario_state [
		"last_reality_checkpoint_resume_contract"
	] = checkpoint_resume_contract
	scenario_state [
		"last_reality_checkpoint_actor_id"
	] = actor_id
	scenario_state [
		"last_reality_checkpoint_signature"
	] = residency_signature

	return report
func _checkpoint_resume_authoritative_hunger_for_current_actor() -> Dictionary:
	if player == null:
		return {
			"success": false,
			"hunger": -1.0,
			"authority": "missing_actor"
		}

	var actor_id: int = int(
		player.id
	)
	var checkpoint_resume_scalar_materialized: bool = false

	if typeof(scenario_state) == TYPE_DICTIONARY:
		checkpoint_resume_scalar_materialized = (
			bool(
				scenario_state.get(
					"checkpoint_resume_not_birth",
					false
				)
			)
			or bool(
				scenario_state.get(
					"resident_runtime_restored_from_checkpoint",
					false
				)
			)
			or bool(
				scenario_state.get(
					"checkpoint_payload_hydration_tail_pending",
					false
				)
			)
			or bool(
				scenario_state.get(
					"background_hydration_active",
					false
				)
			)
		)










	if checkpoint_resume_scalar_materialized:
		return {
			"success": true,
			"hunger": clampf(
				float(
					player.hunger
				),
				0.0,
				100.0
			),
			"authority": "CheckpointResumeContract.Person.hunger",
			"actor_id": actor_id,
			"read_only": true
		}

	if (
		food_engine != null
		and food_engine.has_method(
			"hunger_scalar_contract_for_actor"
		)
	):
		var food_contract: Dictionary = (
			food_engine.hunger_scalar_contract_for_actor(
				actor_id
			)
		)

		if bool(
			food_contract.get(
				"success",
				false
			)
		):
			return {
				"success": true,
				"hunger": clampf(
					float(
						food_contract.get(
							"hunger",
							player.hunger
						)
					),
					0.0,
					100.0
				),
				"authority": "FoodEngine",
				"actor_id": actor_id,
				"read_only": true
			}

	return {
		"success": true,
		"hunger": clampf(
			float(
				player.hunger
			),
			0.0,
			100.0
		),
		"authority": "Person.hunger",
		"actor_id": actor_id,
		"read_only": true
	}
func _checkpoint_resume_first_frame_snapshot_for_current_actor(
	base_snapshot: Dictionary,
	diary_lines: Array,
	panel_id: String = "life"
) -> Dictionary:
	if player == null:
		return base_snapshot.duplicate(false)

	var snapshot: Dictionary = (
		base_snapshot.duplicate(false)
	)
	var actor_id: int = int(
		player.id
	)
	var actor_name: String = (
		"%s %s"
		% [
			str(
				player.first_name
			).strip_edges(),
			str(
				player.last_name
			).strip_edges()
		]
	).strip_edges()

	if actor_name == "":
		actor_name = "Unknown Life"

	var clean_panel: String = str(
		panel_id
	).strip_edges().to_lower()

	if clean_panel == "":
		clean_panel = "life"

	var bank_value: int = int(
		player.bank_balance
	)
	var health_value: int = clampi(
		int(
			round(
				float(
					player.health
				)
			)
		),
		0,
		200
	)
	var persisted_stats: Dictionary = (
		_safe_dictionary(
			snapshot.get(
				"stats",
				{}
			)
		)
	)
	var persisted_hunger_raw: Variant = snapshot.get(
		"hunger",
		persisted_stats.get(
			"hunger",
			-1
		)
	)
	var persisted_hunger: float = -1.0

	if typeof(
		persisted_hunger_raw
	) in [
		TYPE_INT,
		TYPE_FLOAT
	]:
		persisted_hunger = clampf(
			float(
				persisted_hunger_raw
			),
			0.0,
			100.0
		)

	var current_hunger_contract: Dictionary = (
		_checkpoint_resume_authoritative_hunger_for_current_actor()
	)
	var actor_hunger: float = float(
		current_hunger_contract.get(
			"hunger",
			-1.0
		)
	)
	var resolved_hunger: float = 0.0










	if actor_hunger >= 0.0:
		resolved_hunger = actor_hunger
	elif persisted_hunger >= 0.0:
		resolved_hunger = persisted_hunger
	var hunger_value: int = clampi(
		int(
			round(
				resolved_hunger
			)
		),
		0,
		100
	)
	var mental_value: int = clampi(
		int(
			round(
				float(
					player.mental_health
				)
			)
		),
		0,
		100
	)
	var willpower_value: int = maxi(
		0,
		int(
			round(
				float(
					player.willpower
				)
			)
		)
	)
	var happiness_value: int = clampi(
		int(
			round(
				float(
					player.satisfaction
				)
			)
		),
		0,
		100
	)
	var smarts_value: int = clampi(
		int(
			player.smarts
		),
		0,
		100
	)
	var looks_value: int = clampi(
		int(
			player.looks
		),
		0,
		100
	)
	var imagination_value: int = clampi(
		int(
			player.imagination
		),
		0,
		100
	)
	var fame_value: int = clampi(
		int(
			player.fame
		),
		0,
		100
	)
	var approval_value: int = (
		clampi(
			int(
				player.approval
			),
			0,
			100
		)
		if (
			bool(
				player.is_ruler
			)
			or bool(
				player.is_royal
			)
		)
		else 0
	)

	var stats: Dictionary = (
		_safe_dictionary(
			snapshot.get(
				"stats",
				{}
			)
		).duplicate(false)
	)

	stats ["health"] = health_value
	stats ["hunger"] = hunger_value
	stats ["mental"] = mental_value
	stats ["mental_health"] = mental_value
	stats ["willpower"] = willpower_value
	stats ["happiness"] = happiness_value
	stats ["smarts"] = smarts_value
	stats ["looks"] = looks_value
	stats ["imagination"] = imagination_value
	stats ["fame"] = fame_value
	stats ["approval"] = approval_value
	stats ["bank"] = bank_value

	var max_values: Dictionary = (
		_safe_dictionary(
			snapshot.get(
				"max_values",
				{}
			)
		).duplicate(false)
	)

	max_values ["health"] = maxi(
		200,
		health_value
	)
	max_values ["hunger"] = 100
	max_values ["mental"] = maxi(
		100,
		mental_value
	)
	max_values ["mental_health"] = maxi(
		100,
		mental_value
	)
	max_values ["willpower"] = maxi(
		150,
		willpower_value
	)
	max_values ["happiness"] = 100
	max_values ["smarts"] = 100
	max_values ["looks"] = 100
	max_values ["imagination"] = 100
	max_values ["fame"] = 100
	max_values ["approval"] = 100

	var visibility: Dictionary = (
		_safe_dictionary(
			snapshot.get(
				"visibility",
				{}
			)
		).duplicate(false)
	)

	visibility [
		"player_stats_overlay"
	] = true
	visibility [
		"life_diary"
	] = true
	visibility [
		"nav_tabs"
	] = true
	visibility [
		"runtime_huds"
	] = true

	var surface_context: Dictionary = (
		_safe_dictionary(
			snapshot.get(
				"surface_context",
				{}
			)
		).duplicate(false)
	)

	surface_context [
		"source"
	] = (
		"game_state."
		+ "checkpoint_resume_first_frame_snapshot"
	)
	surface_context [
		"checkpoint_resume"
	] = true
	surface_context [
		"resume_not_birth"
	] = true
	surface_context [
		"simulation_authored"
	] = true
	surface_context [
		"main_scene_is_renderer_only"
	] = true
	surface_context [
		"ui_packet_consumer_only"
	] = true
	surface_context [
		"actor_id"
	] = actor_id

	snapshot [
		"schema"
	] = (
		"eralife.reality_checkpoint."
		+ "first_frame_ui_snapshot"
	)
	snapshot [
		"version"
	] = 3
	snapshot [
		"reason"
	] = "checkpoint_resume"
	snapshot [
		"entry_kind"
	] = "checkpoint_resume"
	snapshot [
		"resume_not_birth"
	] = true
	snapshot [
		"birth_intro_ready"
	] = false
	snapshot [
		"birth_intro_allowed"
	] = false

	snapshot ["actor_id"] = actor_id
	snapshot ["player_id"] = actor_id
	snapshot ["actor_name"] = actor_name
	snapshot [
		"first_name"
	] = str(
		player.first_name
	)
	snapshot [
		"last_name"
	] = str(
		player.last_name
	)
	snapshot ["title"] = actor_name
	snapshot [
		"age"
	] = int(
		player.age
	)
	snapshot [
		"alive"
	] = bool(
		player.alive
	)
	snapshot ["year"] = int(
		year
	)
	snapshot [
		"current_panel"
	] = clean_panel

	snapshot [
		"bank_balance"
	] = bank_value
	snapshot ["money"] = bank_value
	snapshot ["health"] = health_value
	snapshot ["hunger"] = hunger_value
	snapshot [
		"mental_health"
	] = mental_value
	snapshot ["mental"] = mental_value
	snapshot [
		"willpower"
	] = willpower_value
	snapshot [
		"happiness"
	] = happiness_value
	snapshot ["smarts"] = smarts_value
	snapshot ["looks"] = looks_value
	snapshot [
		"imagination"
	] = imagination_value
	snapshot ["fame"] = fame_value
	snapshot [
		"approval"
	] = approval_value

	snapshot ["stats"] = stats
	snapshot [
		"max_values"
	] = max_values
	snapshot [
		"visibility"
	] = visibility
	snapshot [
		"surface_context"
	] = surface_context
	snapshot [
		"life_diary_lines"
	] = diary_lines.duplicate(false)

	snapshot [
		"life_diary_required"
	] = true
	snapshot [
		"player_stats_overlay_required"
	] = true
	snapshot [
		"nav_tabs_required"
	] = true
	snapshot [
		"runtime_huds_required"
	] = true
	snapshot [
		"blank_shell_forbidden"
	] = true
	snapshot [
		"loading_on_ready_forbidden"
	] = true
	snapshot [
		"main_scene_is_renderer_only"
	] = true
	snapshot [
		"ui_packet_consumer_only"
	] = true
	snapshot [
		"checkpoint_actor_scalar_truth_current"
	] = true
	snapshot [
		"checkpoint_actor_scalar_truth_actor_id"
	] = actor_id
	snapshot [
		"checkpoint_actor_scalar_truth_age"
	] = int(
		player.age
	)
	snapshot [
		"checkpoint_actor_scalar_truth_hunger"
	] = hunger_value
	snapshot [
		"checkpoint_actor_scalar_truth_hunger_authority"
	] = str(
		current_hunger_contract.get(
			"authority",
			"checkpoint_first_frame_fallback"
		)
	)
	snapshot [
		"captured_at_ms"
	] = int(
		Time.get_ticks_msec()
	)

	return snapshot
func _checkpoint_resume_hud_visibility_snapshot_for_current_actor(
	base_snapshot: Dictionary = {}
) -> Dictionary:
	if player == null:
		return {}

	var snapshot: Dictionary = (
		base_snapshot.duplicate(false)
	)
	var actor_id: int = int(
		player.id
	)
	var actor_age: int = int(
		player.age
	)
	var actor_alive: bool = (
		bool(
			player.alive
		)
		and float(
			player.health
		) > 0.0
	)

	var bending_available: bool = false
	var bending_type: String = str(
		player.bending_type
	).strip_edges().to_lower()

	if (
		actor_alive
		and bending_type not in [
			"",
			"none",
			"null"
		]
	):
		bending_available = true

	if (
		not bending_available
		and actor_alive
		and typeof(
			player.bending_mastery
		) == TYPE_DICTIONARY
	):
		for element in [
			"air",
			"water",
			"earth",
			"fire"
		]:
			if int(
				player.bending_mastery.get(
					element,
					0
				)
			) > 0:
				bending_available = true
				break

	if (
		not bending_available
		and actor_alive
		and typeof(
			player.bending_latent_potential
		) == TYPE_DICTIONARY
	):
		for element in [
			"air",
			"water",
			"earth",
			"fire"
		]:
			if int(
				player.bending_latent_potential.get(
					element,
					0
				)
			) > 0:
				bending_available = true
				break

	var civic_office_raw: Variant = player.get(
		"civic_office_contract"
	)
	var civic_office: Dictionary = (
		civic_office_raw as Dictionary
		if typeof(
			civic_office_raw
		) == TYPE_DICTIONARY
		else {}
	)
	var civic_crown_available: bool = (
		bool(
			civic_office.get(
				"ruling_power_by_office",
				false
			)
		)
		or bool(
			civic_office.get(
				"crown_hub_access",
				false
			)
		)
		or bool(
			civic_office.get(
				"government_command_surface_access",
				false
			)
		)
	)

	var succession_rank: int = int(
		player.succession_rank
	)
	var dynastic_crown_available: bool = (
		bool(
			player.is_royal
		)
		or str(
			player.royal_title
		).strip_edges() != ""
		or (
			succession_rank > 0
			and succession_rank < 99
		)
	)

	var public_identity_raw: Variant = player.get(
		"public_identity_contract"
	)
	var public_identity: Dictionary = (
		public_identity_raw as Dictionary
		if typeof(
			public_identity_raw
		) == TYPE_DICTIONARY
		else {}
	)
	var public_identity_kind: String = str(
		public_identity.get(
			"identity_kind",
			""
		)
	).strip_edges().to_lower()
	var proximity_explicitly_has_no_power: bool = (
		public_identity_kind in [
			"first_family_child",
			"first_family_partner"
		]
		and not bool(
			public_identity.get(
				"ruling_power_by_family_proximity",
				false
			)
		)
	)

	if proximity_explicitly_has_no_power:
		dynastic_crown_available = false

	var crown_available: bool = (
		actor_alive
		and (
			bool(
				player.is_ruler
			)
			or civic_crown_available
			or dynastic_crown_available
		)
	)

	var era_name: String = ""
	var era_authority_hot: bool = (
		era != null
	)

	if era_authority_hot:
		if typeof(
			era
		) == TYPE_DICTIONARY:
			era_name = str(
				(era as Dictionary).get(
					"name",
					""
				)
			).strip_edges()
		else:
			era_name = str(
				era.name
			).strip_edges()

	var persisted_food_available: bool = bool(
		snapshot.get(
			"food_lifestyle_available",
			snapshot.get(
				"food_lifestyle_button_visible",
				snapshot.get(
					"restaurant_lifestyle_available",
					snapshot.get(
						"restaurant_lifestyle_button_visible",
						false
					)
				)
			)
		)
	)
	var food_available: bool = (
		persisted_food_available
	)

	if not actor_alive:
		food_available = false
	elif era_authority_hot:
		food_available = (
			actor_age >= 15
			and era_name in [
				"Modern Era",
				"Future Era"
			]
		)




	var persisted_rick_available: bool = bool(
		snapshot.get(
			"rick_weapon_shop_available",
			snapshot.get(
				"rick_weapon_shop_button_visible",
				false
			)
		)
	)
	var weapons_authority_hot: bool = (
		weapons_engine != null
		and weapons_engine.has_method(
			"get_store"
		)
	)
	var rick_available: bool = (
		persisted_rick_available
	)

	if not actor_alive:
		rick_available = false
	elif weapons_authority_hot:
		var weapon_store_raw: Variant = (
			weapons_engine.get_store()
		)

		if typeof(
			weapon_store_raw
		) == TYPE_ARRAY:
			rick_available = not (
				weapon_store_raw as Array
			).is_empty()

	var boxing_available: bool = bool(
		snapshot.get(
			"boxing_available",
			snapshot.get(
				"boxing_button_visible",
				false
			)
		)
	)

	if (
		actor_alive
		and typeof(
			player.boxing_profile
		) == TYPE_DICTIONARY
	):
		var boxing_profile: Dictionary = (
			player.boxing_profile
		)
		var amateur_raw: Variant = (
			boxing_profile.get(
				"amateur_circuit",
				{}
			)
		)
		var amateur_circuit: Dictionary = (
			amateur_raw as Dictionary
			if typeof(
				amateur_raw
			) == TYPE_DICTIONARY
			else {}
		)

		boxing_available = (
			boxing_available
			or bool(
				boxing_profile.get(
					"boxing_hub_unlocked",
					false
				)
			)
			or bool(
				boxing_profile.get(
					"boxing_career_started_by_player",
					false
				)
			)
			or bool(
				boxing_profile.get(
					"is_boxer",
					false
				)
			)
			or bool(
				boxing_profile.get(
					"retired",
					false
				)
			)
			or bool(
				boxing_profile.get(
					"turned_pro",
					false
				)
			)
			or bool(
				amateur_circuit.get(
					"is_amateur",
					false
				)
			)
		)

	var superpower_available: bool = bool(
		snapshot.get(
			"superpower_available",
			snapshot.get(
				"superhero_available",
				false
			)
		)
	)

	var power_available: bool = bool(
		snapshot.get(
			"power_available",
			false
		)
	)

	var wizard_available: bool = bool(
		snapshot.get(
			"wizard_available",
			false
		)
	)

	if (
		actor_alive
		and typeof(
			player.wizard_profile
		) == TYPE_DICTIONARY
	):
		var wizard_profile: Dictionary = (
			player.wizard_profile
		)
		var magic_status: String = str(
			wizard_profile.get(
				"magic_status",
				"inactive"
			)
		).strip_edges().to_lower()

		wizard_available = (
			wizard_available
			or bool(
				wizard_profile.get(
					"is_wizard",
					false
				)
			)
			or bool(
				wizard_profile.get(
					"full_wizard",
					false
				)
			)
			or magic_status not in [
				"",
				"inactive",
				"none",
				"null"
			]
		)

	snapshot ["player_id"] = actor_id
	snapshot ["actor_id"] = actor_id
	snapshot ["controlled_actor_id"] = actor_id
	snapshot ["controlled_actor_age"] = actor_age
	snapshot ["current_panel"] = "life"
	snapshot ["belongings_available"] = actor_alive
	snapshot ["belongings_button_visible"] = actor_alive
	snapshot ["bending_available"] = bending_available
	snapshot ["bending_button_visible"] = bending_available
	snapshot ["crown_available"] = crown_available
	snapshot ["crown_button_visible"] = crown_available
	snapshot ["civic_crown_available"] = civic_crown_available
	snapshot ["dynastic_crown_available"] = (
		dynastic_crown_available
	)
	snapshot [
		"proximity_explicitly_has_no_ruling_power"
	] = proximity_explicitly_has_no_power
	snapshot ["food_lifestyle_available"] = food_available
	snapshot ["food_lifestyle_button_visible"] = food_available
	snapshot ["restaurant_lifestyle_available"] = food_available
	snapshot ["restaurant_lifestyle_button_visible"] = food_available
	snapshot ["rick_weapon_shop_available"] = rick_available
	snapshot ["rick_weapon_shop_button_visible"] = rick_available
	snapshot ["boxing_available"] = boxing_available
	snapshot ["boxing_button_visible"] = boxing_available
	snapshot ["superhero_available"] = superpower_available
	snapshot ["superpower_available"] = superpower_available
	snapshot ["superpower_button_visible"] = superpower_available
	snapshot ["power_available"] = power_available
	snapshot ["power_button_visible"] = power_available
	snapshot ["wizard_available"] = wizard_available
	snapshot ["wizard_button_visible"] = wizard_available
	snapshot ["reason"] = (
		"checkpoint_resume_actor_truth"
	)
	snapshot ["simulation_authored"] = true
	snapshot ["renderer_guessing_forbidden"] = true
	snapshot ["engine_existence_is_not_hud_truth"] = true
	snapshot ["crown_authority_by_proximity_forbidden"] = true
	snapshot ["rick_visibility_uses_store_contract"] = true
	snapshot [
		"food_visibility_preserved_until_era_authority_hot"
	] = not era_authority_hot
	snapshot [
		"rick_visibility_preserved_until_weapons_authority_hot"
	] = not weapons_authority_hot
	snapshot ["updated_at_ms"] = int(
		Time.get_ticks_msec()
	)

	return snapshot
func _checkpoint_resume_main_tab_surface_contracts_for_actor(
	actor_id: int
) -> Dictionary:
	if (
		actor_id <= 0
		or typeof(
			scenario_state
		) != TYPE_DICTIONARY
	):
		return {}

	var actor_key: String = str(
		actor_id
	)
	var merged: Dictionary = {}
	var source_decks: Array = []

	var by_actor: Dictionary = _safe_dictionary(
		scenario_state.get(
			"resident_main_tab_surface_contracts_by_actor",
			{}
		)
	)

	source_decks.append(
		_safe_dictionary(
			by_actor.get(
				actor_key,
				{}
			)
		)
	)

	source_decks.append(
		_safe_dictionary(
			scenario_state.get(
				"resident_main_tab_surface_contracts",
				{}
			)
		)
	)

	for registry_name in [
		"resident_control_switch_support_surface_packet_by_actor",
		"observable_control_switch_support_surface_packet_by_actor"
	]:
		var registry: Dictionary = _safe_dictionary(
			scenario_state.get(
				registry_name,
				{}
			)
		)
		var packet: Dictionary = _safe_dictionary(
			registry.get(
				actor_key,
				{}
			)
		)

		source_decks.append(
			_safe_dictionary(
				packet.get(
					"main_tab_surface_contracts",
					{}
				)
			)
		)

	var profile_registry: Dictionary = _safe_dictionary(
		scenario_state.get(
			"profile_pointer_packet_by_actor",
			{}
		)
	)
	var profile_packet: Dictionary = _safe_dictionary(
		profile_registry.get(
			actor_key,
			{}
		)
	)
	var profile_surface: Dictionary = _safe_dictionary(
		profile_packet.get(
			"surface_contract",
			{}
		)
	)

	source_decks.append(
		_safe_dictionary(
			profile_packet.get(
				"main_tab_surface_contracts",
				profile_surface.get(
					"main_tab_surface_contracts",
					{}
				)
			)
		)
	)

	for source_deck in source_decks:
		if typeof(
			source_deck
		) != TYPE_DICTIONARY:
			continue

		for surface_id in [
			"relationships",
			"school",
			"activities",
			"career",
			"mods"
		]:
			if merged.has(
				surface_id
			):
				continue

			var contract: Dictionary = _safe_dictionary(
				(source_deck as Dictionary).get(
					surface_id,
					{}
				)
			)

			if (
				contract.is_empty()
				or int(
					contract.get(
						"actor_id",
						-1
					)
				) != actor_id
			):
				continue

			var schema: String = str(
				contract.get(
					"schema",
					""
				)
			).strip_edges().to_lower()
			var truth_state: String = str(
				contract.get(
					"truth_state",
					""
				)
			).strip_edges().to_lower()

			if (
				schema
				== "eralife.pointer_only.destination_tab_contract"
				or truth_state
				== "pointer_only_resident_shell"
				or bool(
					contract.get(
						"pointer_only",
						false
					)
				)
			):
				continue

			merged [
				surface_id
			] = contract.duplicate(false)

	return merged
func _enrich_current_life_checkpoint_resume_presentation(
	checkpoint_commit: Dictionary,
	save_options: Dictionary = {}
) -> Dictionary:
	if (
		checkpoint_commit.is_empty()
		or not bool(
			checkpoint_commit.get(
				"success",
				false
			)
		)
		or player == null
	):
		return checkpoint_commit.duplicate(false)

	if typeof(scenario_state) != TYPE_DICTIONARY:
		scenario_state = {}

	var report: Dictionary = checkpoint_commit.duplicate(false)
	var resume_raw: Variant = report.get(
		"checkpoint_resume_contract",
		{}
	)
	var resume_contract: Dictionary = (
		(resume_raw as Dictionary).duplicate(false)
		if typeof(resume_raw) == TYPE_DICTIONARY
		else {}
	)
	var actor_id: int = int(player.id)
	var actor_key: String = str(actor_id)
	var current_panel: String = str(
		report.get(
			"current_panel",
			resume_contract.get(
				"current_panel",
				save_options.get(
					"current_panel",
					"life"
				)
			)
		)
	).strip_edges().to_lower()

	if current_panel == "":
		current_panel = "life"

	var diary_entries: Array = []
	var diary_store_raw: Variant = scenario_state.get(
		"life_diary_state_by_npc",
		{}
	)

	if typeof(diary_store_raw) == TYPE_DICTIONARY:
		var diary_store: Dictionary = diary_store_raw as Dictionary
		var diary_bucket_raw: Variant = diary_store.get(
			actor_key,
			{}
		)

		if typeof(diary_bucket_raw) == TYPE_DICTIONARY:
			var diary_bucket: Dictionary = diary_bucket_raw as Dictionary
			var entries_raw: Variant = diary_bucket.get(
				"entries",
				[]
			)

			if typeof(entries_raw) == TYPE_ARRAY:
				diary_entries = (
					entries_raw as Array
				).duplicate(true)

	if (
		diary_entries.is_empty()
		and life_diary_contract_engine != null
		and life_diary_contract_engine.has_method(
			"diary_entries_for_actor"
		)
	):
		var engine_entries_raw: Variant = (
			life_diary_contract_engine.diary_entries_for_actor(
				actor_id,
				{
					"source": (
						"checkpoint_resume_presentation_capture"
					),
					"read_only": true
				}
			)
		)

		if typeof(engine_entries_raw) == TYPE_ARRAY:
			diary_entries = (
				engine_entries_raw as Array
			).duplicate(true)

	var latest_diary_lines: Array = []

	for entry_index in range(
		diary_entries.size() - 1,
		-1,
		-1
	):
		var entry_raw: Variant = diary_entries [entry_index]

		if typeof(entry_raw) == TYPE_ARRAY:
			var entry_lines: Array = entry_raw as Array

			for raw_line in entry_lines:
				var line: String = str(raw_line).strip_edges()

				if line != "":
					latest_diary_lines.append(line)
		elif typeof(entry_raw) == TYPE_DICTIONARY:
			var entry_dict: Dictionary = entry_raw as Dictionary
			var lines_raw: Variant = entry_dict.get(
				"lines",
				[]
			)

			if typeof(lines_raw) == TYPE_ARRAY:
				var entry_lines: Array = lines_raw as Array

				for raw_line in entry_lines:
					var line: String = str(raw_line).strip_edges()

					if line != "":
						latest_diary_lines.append(line)
		else:
			var line: String = str(entry_raw).strip_edges()

			if line != "":
				latest_diary_lines.append(line)

		if not latest_diary_lines.is_empty():
			break

	if latest_diary_lines.is_empty():
		latest_diary_lines = [
			"Year: %s" % str(year),
			"Age: %d" % int(player.age),
			(
				"I stepped back into this life with my story "
				+ "already in motion."
			)
		]

	if diary_entries.is_empty():
		diary_entries = [
			latest_diary_lines.duplicate(true)
		]

	var first_frame_raw: Variant = resume_contract.get(
		"first_frame_ui_snapshot",
		{}
	)
	var first_frame_snapshot: Dictionary = (
		(first_frame_raw as Dictionary).duplicate(false)
		if typeof(first_frame_raw) == TYPE_DICTIONARY
		else {}
	)

	first_frame_snapshot = (
		_checkpoint_resume_first_frame_snapshot_for_current_actor(
			first_frame_snapshot,
			latest_diary_lines,
			current_panel
		)
	)

	first_frame_snapshot [
		"checkpoint_diary_latest_entry_preserved"
	] = true
	first_frame_snapshot [
		"checkpoint_full_diary_entry_count"
	] = diary_entries.size()

	var hud_raw: Variant = scenario_state.get(
		"runtime_hud_visibility_snapshot",
		{}
	)
	var saved_hud_snapshot: Dictionary = (
		(hud_raw as Dictionary).duplicate(false)
		if typeof(hud_raw) == TYPE_DICTIONARY
		else {}
	)
	var hud_snapshot: Dictionary = (
		_checkpoint_resume_hud_visibility_snapshot_for_current_actor(
			saved_hud_snapshot
		)
	)

	hud_snapshot ["current_panel"] = current_panel
	hud_snapshot ["reason"] = (
		"checkpoint_resume_presentation_capture"
	)
	hud_snapshot ["updated_at_ms"] = int(
		Time.get_ticks_msec()
	)

	var main_tab_surface_contracts: Dictionary = (
		_checkpoint_resume_main_tab_surface_contracts_for_actor(
			actor_id
		)
	)

	if main_tab_surface_contracts.is_empty():
		var direct_deck_raw: Variant = scenario_state.get(
			"resident_main_tab_surface_contracts",
			{}
		)

		if typeof(direct_deck_raw) == TYPE_DICTIONARY:
			main_tab_surface_contracts = (
				direct_deck_raw as Dictionary
			).duplicate(false)

	# DIAGNOSTIC: this read produces tab_packets in the resume contract. Report the
	# committing runtime's identity alongside what it found, so it can be compared
	# against ERALIFE_SURFACE_DECK_PERSIST (which reports the runtime the projection
	# engine wrote the deck to). Differing tags mean the deck is written to a
	# different GameState than the one being saved.
	EraLog.truth(
		"ERALIFE_CHECKPOINT_CONTRACT_DECK_READ|gs=%d|tag=%s|actor_id=%d|found_keys=%s|by_actor_keys=%s|direct_keys=%s"
		% [
			int(
				get_instance_id()
			),
			str(
				runtime_origin_tag
			),
			actor_id,
			str(
				main_tab_surface_contracts.keys()
			),
			str(
				_safe_dictionary(
					scenario_state.get(
						"resident_main_tab_surface_contracts_by_actor",
						{}
					)
				).keys()
			),
			str(
				_safe_dictionary(
					scenario_state.get(
						"resident_main_tab_surface_contracts",
						{}
					)
				).keys()
			)
		]
	)

	var era_name: String = ""

	if era != null:
		if typeof(era) == TYPE_DICTIONARY:
			var era_dict: Dictionary = era as Dictionary
			era_name = str(
				era_dict.get(
					"name",
					era_dict.get(
						"era_name",
						""
					)
				)
			).strip_edges()
		else:
			era_name = str(era.name).strip_edges()

	if era_name == "":
		era_name = str(
			scenario_state.get(
				"effective_era_name",
				scenario_state.get(
					"era_name",
					""
				)
			)
		).strip_edges()

	var era_key: String = era_name.to_lower().strip_edges()

	if era_key == "":
		era_key = "modern"

	var era_audio_context: Dictionary = {
		"era_key": era_key,
		"era_name": era_name,
		"year": int(year),
		"player_id": actor_id,
		"current_panel": current_panel,
		"source": "checkpoint_resume_contract",
		"checkpoint_resume": true,
		"birth_intro_audio_forbidden": true
	}

	resume_contract [
		"era_name"
	] = era_name
	resume_contract [
		"era_key"
	] = era_key

	resume_contract ["version"] = 3
	resume_contract ["actor_id"] = actor_id
	resume_contract ["player_id"] = actor_id
	resume_contract ["controlled_actor_id"] = actor_id
	resume_contract ["current_panel"] = current_panel
	resume_contract ["entry_kind"] = "checkpoint_resume"
	resume_contract ["resume_not_birth"] = true
	resume_contract ["birth_intro_allowed"] = false
	resume_contract ["first_frame_ui_snapshot"] = first_frame_snapshot
	resume_contract ["life_diary_entries"] = diary_entries
	resume_contract ["latest_life_diary_lines"] = latest_diary_lines
	resume_contract [
		"runtime_hud_visibility_snapshot"
	] = hud_snapshot
	resume_contract [
		"main_tab_surface_contracts"
	] = main_tab_surface_contracts
	resume_contract ["era_audio_context"] = era_audio_context
	resume_contract [
		"relationship_cards_packet_present"
	] = main_tab_surface_contracts.has("relationships")
	resume_contract [
		"main_tab_surface_packet_count"
	] = main_tab_surface_contracts.size()
	resume_contract [
		"presentation_contract_complete"
	] = (
		not first_frame_snapshot.is_empty()
		and not hud_snapshot.is_empty()
		and main_tab_surface_contracts.has("relationships")
		and main_tab_surface_contracts.has("school")
		and main_tab_surface_contracts.has("activities")
		and main_tab_surface_contracts.has("career")
		and main_tab_surface_contracts.has("mods")
	)
	resume_contract [
		"binary_payload_required_before_visible_lens"
	] = false
	resume_contract ["saved_at_ms"] = int(
		Time.get_ticks_msec()
	)

	var pointer: Dictionary = {
		"identity_id": str(
			report.get(
				"effective_owner_identity_id",
				""
			)
		),
		"life_id": str(
			report.get(
				"life_id",
				""
			)
		),
		"branch_id": str(
			report.get(
				"branch_id",
				"main"
			)
		),
		"checkpoint_path": str(
			report.get(
				"checkpoint_path",
				""
			)
		),
		"residency_signature": str(
			report.get(
				"residency_signature",
				""
			)
		),
		"actor_id": actor_id,
		"controlled_actor_id": actor_id,
		"current_panel": current_panel,
		"checkpoint_resume_contract": resume_contract,
		"updated_at_ms": int(Time.get_ticks_msec())
	}

	var session_recommit: Dictionary = {}
	var checkpoint_recommit: Dictionary = {}

	if session_contract_engine != null:
		session_recommit = (
			session_contract_engine.update_session_pointer(
				pointer,
				{
					"source": (
						"checkpoint_resume_presentation_enrichment"
					),
				}
			)
		)

	if reality_checkpoint_contract_engine != null:
		checkpoint_recommit = (
			reality_checkpoint_contract_engine.commit_local_checkpoint(
				pointer,
				{
					"source": (
						"checkpoint_resume_presentation_enrichment"
					),
					"checkpoint_path": str(
						pointer.get(
							"checkpoint_path",
							""
						)
					),
					"residency_signature": str(
						pointer.get(
							"residency_signature",
							""
						)
					),
					"actor_id": actor_id,
					"life_id": str(
						pointer.get(
							"life_id",
							""
						)
					)
				}
			)
		)

	var checkpoint_path: String = str(
		pointer.get(
			"checkpoint_path",
			""
		)
	).strip_edges()

	if checkpoint_path != "":
		var summary: Dictionary = _read_saved_life_summary(
			checkpoint_path
		)

		summary ["path"] = checkpoint_path
		summary ["player_id"] = actor_id
		summary ["actor_id"] = actor_id
		summary ["controlled_actor_id"] = actor_id
		summary ["age"] = int(player.age)
		summary ["year"] = int(year)
		summary ["era_name"] = era_name
		summary ["current_panel"] = current_panel
		summary ["residency_signature"] = str(
			resume_contract.get(
				"residency_signature",
				pointer.get(
					"residency_signature",
					""
				)
			)
		)
		summary ["checkpoint_resume_contract"] = resume_contract
		summary ["resume_capsule_available"] = true
		summary [
			"resume_presentation_contract_complete"
		] = bool(
			resume_contract.get(
				"presentation_contract_complete",
				false
			)
		)
		summary [
			"binary_decode_required_before_first_frame"
		] = false
		summary [
			"checkpoint_summary_schema"
		] = "eralife.saved_life.resume_summary"
		summary ["checkpoint_summary_version"] = 3

		_write_saved_life_summary_cache(
			checkpoint_path,
			summary
		)

	report ["checkpoint_resume_contract"] = resume_contract
	report ["current_panel"] = current_panel
	report ["actor_id"] = actor_id
	report ["controlled_actor_id"] = actor_id
	report ["session_report"] = session_recommit
	report ["checkpoint_report"] = checkpoint_recommit
	report [
		"checkpoint_resume_presentation_enriched"
	] = true
	report [
		"checkpoint_resume_presentation_complete"
	] = bool(
		resume_contract.get(
			"presentation_contract_complete",
			false
		)
	)
	report [
		"checkpoint_resume_presentation_enriched_at_ms"
	] = int(Time.get_ticks_msec())

	scenario_state [
		"last_reality_checkpoint_commit_report"
	] = report.duplicate(false)
	scenario_state [
		"last_reality_checkpoint_resume_contract"
	] = resume_contract
	scenario_state [
		"checkpoint_resume_presentation_contract_complete"
	] = bool(
		resume_contract.get(
			"presentation_contract_complete",
			false
		)
	)

	return report

func save_game(
	path: String = "user://savegame.bin",
	options: Dictionary = {}
) -> Dictionary:
	_ensure_load_game_runtime_dependencies()
	_ensure_identity_checkpoint_runtime_dependencies()

	if game_state_serialization_runtime == null:
		game_state_serialization_runtime = (
			GameStateSerializationRuntime.new(self)
		)

	var identity_context: Dictionary = (
		identity_contract_engine.emit_identity_context({
			"source": "save_game"
		})
	)
	var requires_account: bool = bool(
		options.get(
			"requires_eralife_account",
			false
		)
	)
	requires_account = (
		requires_account
		or bool(
			options.get(
				"portable_life_packet",
				false
			)
		)
	)
	requires_account = (
		requires_account
		or str(
			options.get(
				"ui_surface",
				""
			)
		).strip_edges().to_lower() == "world_tab"
	)

	if (
		requires_account
		and bool(
			identity_context.get(
				"is_guest",
				true
			)
		)
	):
		var blocked_report: Dictionary = {
			"schema": "eralife.save.account_required_report",
			"version": 1,
			"success": false,
			"mode": "account_required_before_portable_save",
			"reason": (
				"Create or log into an ErAccount before saving "
				+ "a portable LifePacket."
			),
			"identity_context": identity_context.duplicate(true),
			"path": path,
			"options": options.duplicate(true),
			"created_at_ms": int(Time.get_ticks_msec()),
			"contract_mesh": {
				"source_of_truth": "GameState.save_game",
				"ui_is_lens": true
			}
		}
		game_state_serialization_report = (
			blocked_report.duplicate(true)
		)
		scenario_state [
			"last_game_state_serialization_report"
		] = blocked_report.duplicate(true)
		scenario_state [
			"game_state_serialization_report"
		] = blocked_report.duplicate(true)
		scenario_state [
			"portable_save_account_required"
		] = true
		return blocked_report

	var save_options: Dictionary = {
		"source": str(
			options.get(
				"source",
				"save_game"
			)
		),
		"profile": str(
			options.get(
				"profile",
				"full_simulation"
			)
		),
		"preserve_unknown_slices": true,
		"write_structured_slices": true,
		"skip_memory_compaction": bool(
			options.get(
				"skip_memory_compaction",
				false
			)
		),
		"skip_world_feed_normalization": bool(
			options.get(
				"skip_world_feed_normalization",
				false
			)
		),
		"skip_prune": bool(
			options.get(
				"skip_prune",
				false
			)
		),
		"skip_archive": bool(
			options.get(
				"skip_archive",
				false
			)
		),
		"scene_route": str(
			options.get(
				"scene_route",
				""
			)
		),
		"ui_surface": str(
			options.get(
				"ui_surface",
				""
			)
		),
		"identity_context": identity_context.duplicate(true),
		"skip_continuity_capsule": bool(
			options.get(
				"skip_continuity_capsule",
				true
			)
		),
		"path": path
	}

	for key in options.keys():
		save_options [key] = options [key]

	var report: Dictionary = (
		game_state_serialization_runtime.serialize_to_path(
			path,
			save_options
		)
	)
	game_state_serialization_report = report.duplicate(true)

	if typeof(scenario_state) == TYPE_DICTIONARY:
		scenario_state [
			"last_game_state_serialization_report"
		] = report.duplicate(true)
		scenario_state [
			"game_state_serialization_report"
		] = report.duplicate(true)

	if bool(
		report.get(
			"success",
			false
		)
	):
		var checkpoint_commit: Dictionary = (
			commit_current_life_checkpoint_contract(
				path,
				report,
				save_options
			)
		)

		checkpoint_commit = (
			_enrich_current_life_checkpoint_resume_presentation(
				checkpoint_commit,
				save_options
			)
		)

		report ["reality_checkpoint_commit"] = (
			checkpoint_commit.duplicate(true)
		)
		game_state_serialization_report = (
			report.duplicate(true)
		)
		scenario_state [
			"last_game_state_serialization_report"
		] = report.duplicate(true)
		scenario_state [
			"game_state_serialization_report"
		] = report.duplicate(true)
	else:
		EraLog.truth(
			str(
				report.get(
					"reason",
					"Save serialization failed."
				)
			)
		)

	return report
func queue_command_envelope(envelope: Dictionary) -> Dictionary:
	if typeof(envelope) != TYPE_DICTIONARY or envelope.is_empty():
		return { "success": false, "reason": "Command envelope is empty."}

	var row: Dictionary = envelope.duplicate(true)
	row ["queued_at_ms"] = int(Time.get_ticks_msec())
	row ["queue_id"] = "cmd_%d_%d" % [int(Time.get_ticks_msec()), command_envelope_queue.size()]
	command_envelope_queue.append(row)

	var should_auto_drain: bool = bool(envelope.get("auto_drain", true))
	if typeof(scenario_state) == TYPE_DICTIONARY:
		should_auto_drain = should_auto_drain and not bool(scenario_state.get("year_in_progress", false))
		should_auto_drain = should_auto_drain and not bool(scenario_state.get("age_up_transition_busy", false))

	if should_auto_drain:
		return drain_queued_command_envelopes(1)

	last_command_envelope_report = {
		"schema": "eralife.command_envelope_queue_report",
		"version": 1,
		"success": true,
		"mode": "queued",
		"queued_count": command_envelope_queue.size(),
		"queued_at_ms": int(Time.get_ticks_msec())
	}
	return last_command_envelope_report.duplicate(true)

func drain_queued_command_envelopes(max_count: int = 8) -> Dictionary:
	var limit: int = max(1, max_count)
	var handled: Array = []
	var failed: Array = []
	var processed: int = 0

	while command_envelope_queue.size() > 0 and processed < limit:
		var raw: Variant = command_envelope_queue.pop_front()
		processed += 1
		if typeof(raw) != TYPE_DICTIONARY:
			failed.append({ "reason": "Queued command was not a Dictionary."})
			continue
		var result: Dictionary = route_command_envelope(raw as Dictionary)
		if bool(result.get("success", false)):
			handled.append(result)
		else:
			failed.append(result)

	last_command_envelope_report = {
		"schema": "eralife.command_envelope_drain_report",
		"version": 1,
		"success": failed.is_empty(),
		"handled": handled,
		"failed": failed,
		"remaining": command_envelope_queue.size(),
		"drained_at_ms": int(Time.get_ticks_msec())
	}
	return last_command_envelope_report.duplicate(true)

func route_command_envelope(envelope: Dictionary) -> Dictionary:
	if typeof(envelope) != TYPE_DICTIONARY or envelope.is_empty():
		return { "success": false, "reason": "Command envelope is empty."}

	var command_id: String = str(envelope.get("command", envelope.get("action_id", ""))).strip_edges().to_lower()
	var engine_property: String = str(envelope.get("engine_property", "")).strip_edges().to_lower()
	var target: String = str(envelope.get("target", "")).strip_edges().to_lower()

	if command_id.begins_with("bank.") or engine_property == "bank_engine" or target == "bank_engine":
		if bank_engine != null and bank_engine.has_method("route_command_envelope"):
			return bank_engine.route_command_envelope(envelope)
		return { "success": false, "reason": "BankEngine unavailable."}

	if command_id.begins_with("food.") or engine_property == "food_engine" or target == "food_engine":
		if food_engine != null and food_engine.has_method("route_command_envelope"):
			return food_engine.route_command_envelope(envelope)
		return { "success": false, "reason": "FoodEngine unavailable."}

	if command_id.begins_with("restaurant.") or engine_property == "food_restaurant_engine" or target == "food_restaurant_engine":
		if food_restaurant_engine != null and food_restaurant_engine.has_method("route_command_envelope"):
			return food_restaurant_engine.route_command_envelope(envelope)
		return { "success": false, "reason": "FoodRestaurantEngine unavailable."}

	if command_id.begins_with("runtime_contract.") or engine_property == "runtime_contract_engine" or target == "runtime_contract_engine":
		if runtime_contract_engine != null and runtime_contract_engine.has_method("route_command_envelope"):
			return runtime_contract_engine.route_command_envelope(envelope)
		return { "success": false, "reason": "RuntimeContractEngine unavailable."}
	if command_id.begins_with("romance.") or engine_property == "romance_contract_engine" or target == "romance_contract_engine":
		if romance_contract_engine != null and romance_contract_engine.has_method("route_command_envelope"):
			return romance_contract_engine.route_command_envelope(envelope)
		return { "success": false, "reason": "RomanceContractEngine unavailable."}
	if command_id.begins_with("public_space.") or engine_property == "shared_public_space_engine" or target == "shared_public_space_engine":
		if shared_public_space_engine != null and shared_public_space_engine.has_method("route_command_envelope"):
			return shared_public_space_engine.route_command_envelope(envelope)
		return { "success": false, "reason": "SharedPublicSpaceEngine unavailable."}

	if command_id.begins_with("grocery.") or engine_property == "grocery_store_engine" or target == "grocery_store_engine":
		if grocery_store_engine != null and grocery_store_engine.has_method("route_command_envelope"):
			return grocery_store_engine.route_command_envelope(envelope)
		return { "success": false, "reason": "GroceryStoreEngine unavailable."}

	if command_id.begins_with("movie.") or command_id.begins_with("movie_theater.") or engine_property == "movie_theater_engine" or target == "movie_theater_engine":
		if movie_theater_engine != null and movie_theater_engine.has_method("route_command_envelope"):
			return movie_theater_engine.route_command_envelope(envelope)
		return { "success": false, "reason": "MovieTheaterEngine unavailable."}

	if command_id.begins_with("luxury.") or engine_property == "luxury_shop_engine" or target == "luxury_shop_engine":
		if luxury_shop_engine != null and luxury_shop_engine.has_method("route_command_envelope"):
			return luxury_shop_engine.route_command_envelope(envelope)
		return { "success": false, "reason": "LuxuryShopEngine unavailable."}

	if command_id.begins_with("justice.") or command_id.begins_with("case.") or command_id.begins_with("crime.case.") \
or engine_property == "case_orchestrator" or target == "case_orchestrator":
		if case_orchestrator != null and case_orchestrator.has_method("route_command_envelope"):
			return case_orchestrator.route_command_envelope(envelope)
		return { "success": false, "reason": "CaseOrchestrator unavailable."}

	if command_id.begins_with("reality.") or command_id.begins_with("orchestrate.") \
or engine_property == "reality_orchestrator" or target == "reality_orchestrator":
		if reality_orchestrator != null and reality_orchestrator.has_method("route_command_envelope"):
			return reality_orchestrator.route_command_envelope(envelope)
		return { "success": false, "reason": "RealityOrchestrator unavailable."}
	if command_id.begins_with("email.") or command_id.begins_with("email_transport.") or engine_property == "email_verification_transport_engine" or target == "email_verification_transport_engine":
		if email_verification_transport_engine == null:
			email_verification_transport_engine = EmailVerificationTransportEngine.new(self)
		if email_verification_transport_engine != null and email_verification_transport_engine.has_method("route_command_envelope"):
			return email_verification_transport_engine.route_command_envelope(envelope)
		return { "success": false, "reason": "EmailVerificationTransportEngine unavailable."}
	if (
		command_id.begins_with("eralife_network.")
		or command_id.begins_with("reality_intake.")
		or command_id.begins_with("connection_graph.")
		or command_id.begins_with("profile.")
		or command_id.begins_with("network_notes.")
		or command_id.begins_with("public_feed.")
		or command_id.begins_with("reality_stream.")
		or command_id.begins_with("life_account_transfer.")
		or command_id.begins_with("compression.")
		or command_id.begins_with("messenger.")
		or command_id.begins_with("self_host_network.")
		or command_id.begins_with("search.")
		or command_id.begins_with("mailbox.")
		or engine_property == "eralife_network_contract_engine"
		or target == "eralife_network_contract_engine"
		or engine_property == "connection_graph_network"
		or target == "connection_graph_network"
		or engine_property == "eraccount_profile_contract_engine"
		or target == "eraccount_profile_contract_engine"
		or engine_property == "network_notes_contract_engine"
		or target == "network_notes_contract_engine"
		or engine_property == "public_feed_contract_engine"
		or target == "public_feed_contract_engine"
		or engine_property == "reality_stream_contract_engine"
		or target == "reality_stream_contract_engine"
		or engine_property == "life_account_transfer_contract_engine"
		or target == "life_account_transfer_contract_engine"
		or engine_property == "compression"
		or target == "compression"
		or engine_property == "messenger_contract_engine"
		or target == "messenger_contract_engine"
		or engine_property == "self_host_network_contract_engine"
		or target == "self_host_network_contract_engine"
		or engine_property == "search_contract_engine"
		or target == "search_contract_engine"
		or engine_property == "mailbox_contract_engine"
		or target == "mailbox_contract_engine"
	):
		_ensure_identity_checkpoint_runtime_dependencies()

		if (
			eralife_network_contract_engine != null
			and eralife_network_contract_engine.has_method(
				"route_command_envelope"
			)
		):
			return (
				eralife_network_contract_engine
				.route_command_envelope(envelope)
			)

		return {
			"success": false,
			"reason": "EraLifeNetworkContractEngine unavailable."
		}
	if command_id.begins_with("crr.") or engine_property == "crr_contract_engine" or target == "crr_contract_engine":
		if crr_contract_engine == null:
			crr_contract_engine = CRRContractEngine.new(self)
		if crr_contract_engine != null and crr_contract_engine.has_method("route_command_envelope"):
			return crr_contract_engine.route_command_envelope(envelope)
		return { "success": false, "reason": "CRRContractEngine unavailable."}
	if command_id.begins_with("military.") or engine_property == "military_contract_engine" or target == "military_contract_engine":
		if military_contract_engine == null:
			military_contract_engine = MilitaryContractEngine.new(self)
		if military_contract_engine != null and military_contract_engine.has_method("route_command_envelope"):
			return military_contract_engine.route_command_envelope(envelope)
		return { "success": false, "reason": "MilitaryContractEngine unavailable."}

	if command_id.begins_with("war.") or engine_property == "war_contract_engine" or target == "war_contract_engine":
		if war_contract_engine == null:
			war_contract_engine = WarContractEngine.new(self)
		if war_contract_engine != null and war_contract_engine.has_method("route_command_envelope"):
			return war_contract_engine.route_command_envelope(envelope)
		return { "success": false, "reason": "WarContractEngine unavailable."}

	if command_id.begins_with("battle_ui.") or engine_property == "battle_ui_contract_engine" or target == "battle_ui_contract_engine":
		if battle_ui_contract_engine == null:
			battle_ui_contract_engine = BattleUIContractEngine.new(self)
		if battle_ui_contract_engine != null and battle_ui_contract_engine.has_method("route_command_envelope"):
			return battle_ui_contract_engine.route_command_envelope(envelope)
		return { "success": false, "reason": "BattleUIContractEngine unavailable."}

	if command_id.begins_with("battle_sim.") or engine_property == "battle_sim_contract_engine" or target == "battle_sim_contract_engine":
		if battle_sim_contract_engine == null:
			battle_sim_contract_engine = BattleSimContractEngine.new(self)
		if battle_sim_contract_engine != null and battle_sim_contract_engine.has_method("route_command_envelope"):
			return battle_sim_contract_engine.route_command_envelope(envelope)
		return { "success": false, "reason": "BattleSimContractEngine unavailable."}

	if command_id.begins_with("battle.") or engine_property == "battle_contract_engine" or target == "battle_contract_engine":
		if battle_contract_engine == null:
			battle_contract_engine = BattleContractEngine.new(self)
		if battle_contract_engine != null and battle_contract_engine.has_method("route_command_envelope"):
			return battle_contract_engine.route_command_envelope(envelope)
		return { "success": false, "reason": "BattleContractEngine unavailable."}


	if command_id.begins_with("identity.") or engine_property == "identity_contract_engine" or target == "identity_contract_engine":
		if identity_contract_engine == null:
			identity_contract_engine = IdentityContractEngine.new(self)
		if identity_contract_engine != null and identity_contract_engine.has_method("route_command_envelope"):
			return identity_contract_engine.route_command_envelope(envelope)
		if command_id == "identity.create_or_attach_eralife_account" and has_method("create_or_attach_eralife_account_contract"):
			return create_or_attach_eralife_account_contract(envelope)
		return { "success": false, "reason": "IdentityContractEngine unavailable."}
	return {
		"success": true,
		"mode": "packet_only",
		"reason": "No GameState route claimed this command envelope.",
		"command": command_id,
		"envelope": envelope.duplicate(true)
	}
func delete_saved_life(path: String) -> bool:
	var normalized_path:= path.strip_edges()
	if normalized_path == "":
		return false
	if not FileAccess.file_exists(normalized_path):
		return false

	var removed_main:= DirAccess.remove_absolute(normalized_path) == OK

	var cache_path:= _saved_life_summary_cache_path(normalized_path)
	if cache_path != "" and FileAccess.file_exists(cache_path):
		DirAccess.remove_absolute(cache_path)

	return removed_main
func _ensure_loaded_player_lineage() -> void:
	if npc_factory == null or player == null:
		return

	var targets: Array = []
	var seen:= {}
	var queued:= {}
	var frontier: Array = [player]
	var depth_by_id: Dictionary = { int(player.id): 0}
	var max_depth: int = 2

	var enqueue_person = func (person: Person, depth: int) -> void:
		if person == null:
			return
		var person_id: int = int(person.id)
		if person_id <= 0:
			return
		if seen.has(person_id):
			return
		if queued.has(person_id):
			var existing_depth: int = int(depth_by_id.get(person_id, depth))
			if depth < existing_depth:
				depth_by_id [person_id] = depth
			return
		queued [person_id] = true
		depth_by_id [person_id] = depth
		frontier.append(person)

	while not frontier.is_empty():
		var current: Person = frontier.pop_front()
		if current == null:
			continue

		var current_id: int = int(current.id)
		if current_id <= 0:
			continue
		if seen.has(current_id):
			continue

		seen [current_id] = true
		targets.append(current)

		var current_depth: int = int(depth_by_id.get(current_id, 0))

		var current_partner: Person = get_valid_partner(current, true, true)
		if current_partner != null:
			enqueue_person.call(current_partner, current_depth)

		if current_depth >= max_depth:
			continue

		for pid in current.parents:
			var parent: Person = get_or_reactivate_npc_by_id(int(pid))
			if parent != null:
				enqueue_person.call(parent, current_depth + 1)

				var parent_partner: Person = get_valid_partner(parent, true, true)
				if parent_partner != null:
					enqueue_person.call(parent_partner, current_depth + 1)

				for sibling_id in parent.children:
					var sibling: Person = get_or_reactivate_npc_by_id(int(sibling_id))
					if sibling != null:
						enqueue_person.call(sibling, current_depth + 1)

						var sibling_partner: Person = get_valid_partner(sibling, true, true)
						if sibling_partner != null:
							enqueue_person.call(sibling_partner, current_depth + 1)

						for nibling_id in sibling.children:
							var nibling: Person = get_or_reactivate_npc_by_id(int(nibling_id))
							if nibling != null:
								enqueue_person.call(nibling, current_depth + 2)

		for cid in current.children:
			var child: Person = get_or_reactivate_npc_by_id(int(cid))
			if child != null:
				enqueue_person.call(child, current_depth + 1)

				var child_partner: Person = get_valid_partner(child, true, true)
				if child_partner != null:
					enqueue_person.call(child_partner, current_depth + 1)

				for grandchild_id in child.children:
					var grandchild: Person = get_or_reactivate_npc_by_id(int(grandchild_id))
					if grandchild != null:
						enqueue_person.call(grandchild, current_depth + 2)

	for npc in targets:
		if npc == null:
			continue
		if npc not in npcs:
			npcs.append(npc)

	_rebuild_npc_index()
func _normalize_loaded_realm_map(raw_realms: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(raw_realms) != TYPE_DICTIONARY:
		return out

	var incoming: Dictionary = raw_realms
	for raw_key in incoming.keys():
		var realm_raw: Variant = incoming.get(raw_key, {})
		if typeof(realm_raw) != TYPE_DICTIONARY:
			continue

		var key_string: String = str(raw_key).strip_edges()
		var stable_key: Variant = raw_key
		if key_string.is_valid_int():
			stable_key = int(key_string)

		out [stable_key] = (realm_raw as Dictionary).duplicate(true)

	return out
func _ensure_load_game_runtime_dependencies() -> void:
	if era_engine == null:
		era_engine = EraEngine.new(
			self
		)

	if realm_engine == null:
		realm_engine = RealmEngine.new(
			self
		)

	if mod_loader == null:
		mod_loader = ModLoader.new(
			self
		)

	if mod_contract_engine == null:
		mod_contract_engine = ModContractEngine.new(
			self
		)

	if dynasty_engine == null:
		dynasty_engine = DynastyEngine.new(
			self
		)

	if historical_timeline_engine == null:
		historical_timeline_engine = HistoricalTimelineEngine.new(
			self
		)

	if world_chronicle_engine == null:
		world_chronicle_engine = WorldChronicleEngine.new(
			self
		)

	if agent_memory_propagation_engine == null:
		agent_memory_propagation_engine = (
			AgentMemoryPropagationEngine.new(
				self
			)
		)

	if population_shard_engine == null:
		population_shard_engine = PopulationShardEngine.new(
			self
		)

	if game_state_contract_engine == null:
		game_state_contract_engine = GameStateContractEngine.new(
			self
		)

	if game_state_hydration_runtime == null:
		game_state_hydration_runtime = GameStateHydrationRuntime.new(
			self
		)

	if game_state_serialization_runtime == null:
		game_state_serialization_runtime = (
			GameStateSerializationRuntime.new(
				self
			)
		)

	if temporal_slice_transformation_runtime == null:
		temporal_slice_transformation_runtime = (
			TemporalSliceTransformationRuntime.new(
				self
			)
		)

	if reality_fusion_engine == null:
		reality_fusion_engine = RealityFusionEngine.new(
			self
		)

	if soul_seed_engine == null:
		soul_seed_engine = SoulSeedEngine.new(
			self
		)

	if consciousness_engine == null:
		consciousness_engine = ConsciousnessEngine.new(
			self
		)

	if perceptual_integrity_engine == null:
		perceptual_integrity_engine = PerceptualIntegrityEngine.new(
			self
		)

	if willpower_engine == null:
		willpower_engine = WillpowerEngine.new(
			self
		)

	if typeof(
		contract_runtime_engines
	) != TYPE_DICTIONARY:
		contract_runtime_engines = {}

	contract_runtime_engines ["game_state_hydration_runtime"] = (
		game_state_hydration_runtime
	)
	contract_runtime_engines ["game_state_serialization_runtime"] = (
		game_state_serialization_runtime
	)
	contract_runtime_engines ["temporal_slice_transformation_runtime"] = (
		temporal_slice_transformation_runtime
	)
	contract_runtime_engines ["reality_fusion_engine"] = (
		reality_fusion_engine
	)
	contract_runtime_engines ["soul_seed_engine"] = soul_seed_engine
	contract_runtime_engines ["consciousness_engine"] = consciousness_engine
	contract_runtime_engines ["perceptual_integrity_engine"] = (
		perceptual_integrity_engine
	)
	contract_runtime_engines ["willpower_engine"] = willpower_engine
	contract_runtime_engines ["life_diary_contract_engine"] = (
		life_diary_contract_engine
	)

	if realm_contract_engine == null:
		realm_contract_engine = RealmContractEngine.new(
			self
		)

	if simulation_contract_engine == null:
		simulation_contract_engine = SimulationContractEngine.new(
			self
		)

	if runtime_contract_engine == null:
		runtime_contract_engine = RuntimeContractEngine.new(
			self
		)

	if romance_contract_engine == null:
		romance_contract_engine = RomanceContractEngine.new(
			self
		)

	if scenario_popup_contract_engine == null:
		scenario_popup_contract_engine = (
			ScenarioPopupContractEngine.new(
				self
			)
		)

	if scenario_runtime_contract_engine == null:
		scenario_runtime_contract_engine = (
			ScenarioRuntimeContractEngine.new(
				self
			)
		)

	if pending_situations_engine == null:
		pending_situations_engine = PendingSituationsEngine.new(
			self
		)

	if live_person_editor_engine == null:
		live_person_editor_engine = LivePersonEditorEngine.new(
			self
		)

	if contract_view_layer_contract_engine == null:
		contract_view_layer_contract_engine = (
			ContractViewLayerContractEngine.new(
				self
			)
		)

	if traits_contract_engine == null:
		traits_contract_engine = TraitsContractEngine.new(
			self
		)

	if identity_contract_engine == null:
		identity_contract_engine = IdentityContractEngine.new(
			self
		)

	if family_control_engine == null:
		family_control_engine = FamilyControlEngine.new(
			self
		)

	if universal_switch_contract_engine == null:
		universal_switch_contract_engine = (
			UniversalSwitchContractEngine.new(
				self
			)
		)

	if ui_contract_engine == null:
		ui_contract_engine = UIContractEngine.new(
			self
		)

	if embedded_ui_contract_engine == null:
		embedded_ui_contract_engine = EmbeddedUIContractEngine.new(
			self
		)

	if world_engine == null:
		world_engine = WorldEngine.new(
			self
		)

	if life_diary_contract_engine == null:
		life_diary_contract_engine = LifeDiaryContractEngine.new(
			self
		)

	if life_engine == null:
		life_engine = LifeEngine.new(
			self
		)

	if shared_public_space_engine == null:
		shared_public_space_engine = SharedPublicSpaceEngine.new(
			self
		)

	if food_engine == null:
		food_engine = FoodEngine.new(
			self
		)

	if food_restaurant_engine == null:
		food_restaurant_engine = FoodRestaurantEngine.new(
			self
		)

	if grocery_store_engine == null:
		grocery_store_engine = GroceryStoreEngine.new(
			self
		)

	if movie_theater_engine == null:
		movie_theater_engine = MovieTheaterEngine.new(
			self
		)

	if (
		movie_theater_engine != null
		and movie_theater_engine.has_method(
			"bootstrap_ui_contracts"
		)
	):
		movie_theater_engine.bootstrap_ui_contracts()

	if luxury_shop_engine == null:
		luxury_shop_engine = LuxuryShopEngine.new(
			self
		)

	if artifacts_engine == null:
		artifacts_engine = ArtifactsEngine.new(
			self
		)

	if artifacts_catalog_contract_engine == null:
		artifacts_catalog_contract_engine = (
			ArtifactsCatalogContractEngine.new(
				self
			)
		)

	if weapons_engine == null:
		weapons_engine = WeaponsEngine.new(
			self
		)

	if weapons_catalog_expansion == null:
		weapons_catalog_expansion = WeaponsCatalogExpansion.new(
			self
		)

	if artifact_interaction_contract_engine == null:
		artifact_interaction_contract_engine = (
			ArtifactInteractionContractEngine.new(
				self
			)
		)

	if artifact_shop_contract_engine == null:
		artifact_shop_contract_engine = (
			ArtifactShopContractEngine.new(
				self
			)
		)

	if heirloom_runtime_engine == null:
		heirloom_runtime_engine = HeirloomRuntimeEngine.new(
			self
		)

	if heirloom_contract_engine == null:
		heirloom_contract_engine = HeirloomContractEngine.new(
			self
		)

	if heirloom_engine == null:
		heirloom_engine = HeirloomEngine.new(
			self
		)

	if heirloom_catalog_contract_engine == null:
		heirloom_catalog_contract_engine = (
			HeirloomCatalogContractEngine.new(
				self
			)
		)

	if heirloom_hub_contract_engine == null:
		heirloom_hub_contract_engine = (
			HeirloomHubContractEngine.new(
				self
			)
		)

	if belongings_engine == null:
		belongings_engine = BelongingsEngine.new(
			self
		)

	_resident_bootstrap_heirloom_contracts()

	if global_object_catalog_system == null:
		global_object_catalog_system = GlobalObjectCatalogSystem.new(
			self
		)

	if object_hub_contract_engine == null:
		object_hub_contract_engine = ObjectHubContractEngine.new(
			self
		)

	if artifacts_catalog_contract_engine != null:
		artifacts_catalog_contract_engine.bootstrap_default_contracts()

	if weapons_catalog_expansion != null:
		weapons_catalog_expansion.bootstrap_default_contracts()

	if global_object_catalog_system != null:
		global_object_catalog_system.bootstrap_default_providers()

	_resident_bootstrap_object_projection_contracts()

	if bank_engine == null:
		bank_engine = BankEngine.new(
			self
		)

	if crime_contract_engine == null:
		crime_contract_engine = CrimeContractEngine.new(
			self
		)

	if investigation_layer == null:
		investigation_layer = InvestigationLayer.new(
			self
		)

	if justice_system_engine == null:
		justice_system_engine = JusticeSystemEngine.new(
			self
		)

	if jail_engine == null:
		jail_engine = JailEngine.new(
			self
		)

	if prison_engine == null:
		prison_engine = PrisonEngine.new(
			self
		)

	if case_orchestrator == null:
		case_orchestrator = CaseOrchestrator.new(
			self
		)

	if crime_engine == null:
		crime_engine = CrimeEngine.new(
			self
		)

	if crime_hub_contract_engine == null:
		crime_hub_contract_engine = CrimeHubContractEngine.new(
			self
		)

func _resolve_loaded_era_from_save_data(data: Dictionary, loaded_year: int) -> Variant:
	var saved_era_name: String = str(data.get("era_name", "")).strip_edges()

	if era_engine == null:
		era_engine = EraEngine.new(self)

	if era_engine != null:
		if saved_era_name != "" and "eras" in era_engine and typeof(era_engine.eras) == TYPE_DICTIONARY:
			if era_engine.eras.has(saved_era_name):
				return era_engine.eras.get(saved_era_name)

		if era_engine.has_method("_era_from_year"):
			return era_engine.call("_era_from_year", loaded_year)

		if era_engine.has_method("get_era_key_from_year") and "eras" in era_engine and typeof(era_engine.eras) == TYPE_DICTIONARY:
			var era_key: String = str(era_engine.call("get_era_key_from_year", loaded_year)).strip_edges()
			if era_key != "" and era_engine.eras.has(era_key):
				return era_engine.eras.get(era_key)

	return {
		"name": saved_era_name if saved_era_name != "" else "Modern",
		"key": saved_era_name if saved_era_name != "" else "Modern",
		"start_year": loaded_year,
		"end_year": loaded_year
	}



func load_game(path: String = "user://savegame.bin", options: Dictionary = {}) -> Dictionary:
	_ensure_load_game_runtime_dependencies()
	_ensure_identity_checkpoint_runtime_dependencies()

	if game_state_hydration_runtime == null:
		game_state_hydration_runtime = GameStateHydrationRuntime.new(self)

	var load_options: Dictionary = {
		"source": "load_game",
		"profile": "playable_first",
		"load_mode": "playable_first",
		"preserve_unknown_slices": true,
		"apply_runtime_guards": true,
		"background_enabled": true,
		"playable_npc_limit": 96
	}

	for key in options.keys():
		load_options [key] = options [key]

	var load_mode: String = str(load_options.get("load_mode", "playable_first")).strip_edges().to_lower()
	var report: Dictionary = {}

	if load_mode in ["full", "blocking", "full_simulation"]:
		load_options ["profile"] = str(load_options.get("profile", "full_simulation"))
		report = game_state_hydration_runtime.hydrate_from_path(path, load_options)
	else:
		load_options ["profile"] = str(load_options.get("profile", "playable_first"))
		report = game_state_hydration_runtime.hydrate_playable_from_path(path, load_options)

	game_state_hydration_report = report.duplicate(true)
	if typeof(scenario_state) == TYPE_DICTIONARY:
		scenario_state ["last_game_state_hydration_report"] = report.duplicate(true)
		scenario_state ["background_hydration_active"] = bool(report.get("background_active", false))
		scenario_state ["background_hydration_queue_size"] = int(report.get("background_queue_size", 0))

	if not bool(report.get("success", false)):
		EraLog.truth(str(report.get("reason", "   Save hydration failed.")))
		return report

	if bool(report.get("background_active", false)):
		EraLog.truth("GAME PLAYABLE. BACKGROUND HYDRATION ACTIVE.")
	else:
		EraLog.truth("GAME LOADED.")

	return report
func _build_current_life_summary(path: String = "") -> Dictionary:
	var normalized_path:= path.strip_edges()
	var player_name:= "Unknown Life"
	var player_age:= 0
	var year_value:= int(year)
	var era_name:= "Unknown Era"
	var saved_player_id:= int(player_id)

	if player != null:
		player_name = ("%s %s" % [
			str(player.first_name),
			str(player.last_name)
		]).strip_edges()
		player_age = int(player.age)
		saved_player_id = int(player.id)

	if era != null and typeof(era) == TYPE_DICTIONARY:
		era_name = str(era.get("name", era.get("era_name", "Unknown Era")))
	elif era != null and "name" in era:
		era_name = str(era.name)

	if player_name == "":
		player_name = "Unknown Life"

	return {
		"path": normalized_path,
		"player_name": player_name,
		"age": player_age,
		"year": year_value,
		"era_name": era_name,
		"player_id": saved_player_id,
		"saved_at_unix": int(Time.get_unix_time_from_system())
	}
func _saved_life_summary_from_filename(path: String) -> Dictionary:
	var normalized_path:= path.strip_edges()
	if normalized_path == "":
		return {}

	var base_name: String = normalized_path.get_file().get_basename().strip_edges()
	if base_name == "":
		base_name = "unknown_life"

	var parts: PackedStringArray = base_name.split("_", false)
	var name_parts: Array = []
	var age_value: int = 0
	var year_value: int = 0
	var found_age: bool = false
	var found_year: bool = false

	var i: int = 0
	while i < parts.size():
		var token: String = str(parts [i]).strip_edges().to_lower()

		if token == "age" and i + 1 < parts.size():
			age_value = max(0, int(str(parts [i + 1])))
			found_age = true
			i += 2
			continue

		if token == "year" and i + 1 < parts.size():
			var raw_year: int = int(str(parts [i + 1]))
			var era_token: String = ""
			if i + 2 < parts.size():
				era_token = str(parts [i + 2]).strip_edges().to_lower()
			year_value = - abs(raw_year) if era_token in ["bc", "bce"] else raw_year
			found_year = true
			i += 3 if era_token in ["ad", "bc", "bce", "ce"] else 2
			continue

		if not found_age and token != "":
			name_parts.append(str(parts [i]))

		i += 1

	var player_name: String = " ".join(name_parts).replace("_", " ").strip_edges()
	if player_name == "":
		player_name = base_name.replace("_", " ").strip_edges()
	if player_name == "":
		player_name = "Unknown Life"

	var saved_at_unix: int = int(FileAccess.get_modified_time(normalized_path))
	var summary:= {
		"path": normalized_path,
		"player_name": player_name,
		"age": age_value if found_age else 0,
		"year": year_value if found_year else 0,
		"era_name": "Unknown Era",
		"saved_at_unix": saved_at_unix,
		"summary_status": "filename_fast_summary"
	}

	return summary
func _read_saved_life_summary(path: String) -> Dictionary:
	var normalized_path:= path.strip_edges()
	if normalized_path == "":
		return {}

	if not FileAccess.file_exists(normalized_path):
		return {}

	var cached_summary:= _read_saved_life_summary_cache(normalized_path)
	if not cached_summary.is_empty():
		return cached_summary

	var fallback_summary:= _saved_life_summary_from_filename(normalized_path)
	if fallback_summary.is_empty():
		fallback_summary = {
			"path": normalized_path,
			"player_name": "Unknown Life",
			"age": 0,
			"year": 0,
			"era_name": "Unknown Era",
			"saved_at_unix": int(FileAccess.get_modified_time(normalized_path)),
			"summary_status": "metadata_only_pending_full_cache"
		}

	var lower_path: String = normalized_path.to_lower()

	if lower_path.ends_with(".bin"):
		return fallback_summary

	var f = FileAccess.open(normalized_path, FileAccess.READ)
	if f == null:
		return fallback_summary

	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()

	if typeof(parsed) != TYPE_DICTIONARY or (parsed as Dictionary).is_empty():
		return fallback_summary

	var data: Dictionary = (parsed as Dictionary).duplicate(true)
	if not data.has("year") or not data.has("player_id"):
		return fallback_summary

	var player_name:= str(data.get("player_name", "")).strip_edges()
	var player_age:= int(data.get("last_saved_age", -1))
	var saved_player_id:= int(data.get("player_id", -1))
	var year_value:= int(data.get("year", 0))
	var era_name:= str(data.get("era_name", "Unknown Era")).strip_edges()

	var saved_at_unix:= int(data.get("saved_at_unix", 0))
	var npc_dicts: Array = data.get("npcs", [])

	if (player_name == "" or player_age < 0) and not npc_dicts.is_empty():
		for d in npc_dicts:
			if typeof(d) != TYPE_DICTIONARY:
				continue
			if int(d.get("id", -1)) != saved_player_id:
				continue
			if player_name == "":
				player_name = ("%s %s" % [
					str(d.get("first_name", "")),
					str(d.get("last_name", ""))
				]).strip_edges()
			if player_age < 0:
				player_age = int(d.get("age", 0))
			break

	if player_name == "":
		player_name = str(fallback_summary.get("player_name", "Unknown Life"))
	if player_age < 0:
		player_age = int(fallback_summary.get("age", 0))
	if era_name == "":
		era_name = "Unknown Era"
	if saved_at_unix <= 0:
		saved_at_unix = int(FileAccess.get_modified_time(normalized_path))

	var summary:= {
		"path": normalized_path,
		"player_name": player_name,
		"age": player_age,
		"year": year_value,
		"era_name": era_name,
		"player_id": saved_player_id,
		"saved_at_unix": saved_at_unix
	}

	_write_saved_life_summary_cache(normalized_path, summary)
	return summary
func _saved_life_summary_cache_path(path: String) -> String:
	var normalized_path:= path.strip_edges()
	if normalized_path == "":
		return ""
	return "%s.summary" % normalized_path

func _read_saved_life_summary_cache(path: String) -> Dictionary:
	var normalized_path:= path.strip_edges()
	if normalized_path == "":
		return {}
	if not FileAccess.file_exists(normalized_path):
		return {}

	var cache_path:= _saved_life_summary_cache_path(normalized_path)
	if cache_path == "" or not FileAccess.file_exists(cache_path):
		return {}

	var f = FileAccess.open(cache_path, FileAccess.READ)
	if f == null:
		return {}

	var parsed = JSON.parse_string(f.get_as_text())
	f.close()

	if typeof(parsed) != TYPE_DICTIONARY:
		return {}

	var source_modified_time:= int(parsed.get("source_modified_time", -1))
	var current_modified_time:= int(FileAccess.get_modified_time(normalized_path))
	if source_modified_time != current_modified_time:
		return {}

	var summary = parsed.get("summary", {})
	if typeof(summary) != TYPE_DICTIONARY or summary.is_empty():
		return {}

	summary ["path"] = normalized_path
	return summary

func _write_saved_life_summary_cache(path: String, summary: Dictionary) -> void:
	var normalized_path:= path.strip_edges()
	if normalized_path == "":
		return
	if not FileAccess.file_exists(normalized_path):
		return
	if typeof(summary) != TYPE_DICTIONARY or summary.is_empty():
		return

	var cache_path:= _saved_life_summary_cache_path(normalized_path)
	if cache_path == "":
		return

	var payload:= {
		"source_modified_time": int(FileAccess.get_modified_time(normalized_path)),
		"summary": summary.duplicate()
	}
	payload ["summary"] ["path"] = normalized_path

	var f = FileAccess.open(cache_path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(payload))
	f.close()

func list_saved_life_summaries(dir_path: String = "user://saved_lives") -> Array:
	var out: Array = []
	var normalized_dir:= dir_path.strip_edges()
	if normalized_dir == "":
		normalized_dir = "user://saved_lives"

	var root:= DirAccess.open("user://")
	if root == null:
		return out

	if normalized_dir == "user://saved_lives" and not root.dir_exists("saved_lives"):
		root.make_dir("saved_lives")

	var dir:= DirAccess.open(normalized_dir)
	if dir == null:
		return out

	dir.list_dir_begin()
	var file_name:= dir.get_next()

	while file_name != "":
		if not dir.current_is_dir():
			var lower:= file_name.to_lower()
			if lower.ends_with(".bin") or lower.ends_with(".json"):
				var full_path:= "%s/%s" % [normalized_dir, file_name]
				var summary:= _read_saved_life_summary(full_path)
				if not summary.is_empty():
					out.append(summary)
		file_name = dir.get_next()

	dir.list_dir_end()

	out.sort_custom(func (a, b): return int(a.get("saved_at_unix", 0)) > int(b.get("saved_at_unix", 0)))
	return out
func _soft_unload_npcs():

	if npcs.size() <= NPC_ACTIVE_LIMIT:
		return

	var candidates:= []

	for npc in npcs:
		if _npc_is_dormancy_protected(npc):
			continue

		candidates.append({
			"npc": npc,
			"distance": _world_distance_to_player(npc)
		})

	if candidates.is_empty():
		return


	candidates.sort_custom(func (a, b): return int(a ["distance"]) > int(b ["distance"]))

	var remove_count = min(npcs.size() - NPC_ACTIVE_LIMIT, candidates.size())

	for i in range(remove_count):
		deactivate_npc(candidates [i] ["npc"])



func merge_character_from_save(path: String, merge_contract: Dictionary = {}):
	_ensure_load_game_runtime_dependencies()
	if game_state_hydration_runtime == null:
		game_state_hydration_runtime = GameStateHydrationRuntime.new(self)

	var resolved_contract: Dictionary = _default_reality_merge_contract()
	if typeof(merge_contract) == TYPE_DICTIONARY and not merge_contract.is_empty():
		resolved_contract = merge_contract.duplicate(true)
		if not resolved_contract.has("merge_policy"):
			resolved_contract ["merge_policy"] = _default_reality_merge_contract().get("merge_policy", {})

	var report: Dictionary = game_state_hydration_runtime.merge_character_from_path(path, resolved_contract)
	var stored_report: Dictionary = report.duplicate(true)
	stored_report.erase("imported_player")
	if typeof(scenario_state) == TYPE_DICTIONARY:
		scenario_state ["last_reality_merge_report"] = stored_report
	if not bool(report.get("success", false)):
		EraLog.truth(str(report.get("reason", "❌ Reality merge failed.")))
		return null

	EraLog.truth("🌌 Multiverse: Imported %d people." % int(report.get("imported_count", 0)))
	return report.get("imported_player", null)
func fuse_reality_from_save(path: String, fusion_contract: Dictionary = {}) -> Dictionary:
	_ensure_load_game_runtime_dependencies()

	if reality_fusion_engine == null:
		reality_fusion_engine = RealityFusionEngine.new(self)

	var report: Dictionary = reality_fusion_engine.fuse_from_path(path, fusion_contract)

	if typeof(scenario_state) != TYPE_DICTIONARY:
		scenario_state = {}

	scenario_state ["last_reality_fusion_report"] = report.duplicate(true)

	if reality_fusion_engine != null and reality_fusion_engine.has_method("export_state"):
		scenario_state ["reality_fusion_engine_state"] = reality_fusion_engine.export_state()

	return report


func preview_reality_fusion_from_save(path: String, fusion_contract: Dictionary = {}) -> Dictionary:
	_ensure_load_game_runtime_dependencies()

	if reality_fusion_engine == null:
		reality_fusion_engine = RealityFusionEngine.new(self)

	return reality_fusion_engine.preview_fusion_from_path(path, fusion_contract)
func _default_reality_merge_contract() -> Dictionary:
	return {
		"schema": "eralife.reality_merge_contract",
		"version": 1,
		"id": "default_parallel_identity_family_merge",
		"merge_policy": {
			"relationship_scope": ["parents", "children", "spouse"],
			"friend_link": "bidirectional",
			"lineage_strategy": "preserve",
			"id_strategy": "remap_safe",
			"conflict_resolution": "parallel_identity",
			"world_integration": {
				"register_npcs": true,
				"rebuild_index": true,
				"ensure_lineage": true
			}
		}
	}
func ensure_war_contract_runtime_authority() -> Dictionary:
		var created: bool = false
		var rebound: bool = false

		if war_contract_engine == null:
			war_contract_engine = WarContractEngine.new(
				self
			)
			created = (
				war_contract_engine != null
			)
		elif war_contract_engine.has_method(
			"bind_game_state"
		):
			war_contract_engine.bind_game_state(
				self
			)
			rebound = true

		var authority_hot: bool = (
			war_contract_engine != null
		)

		return {
			"success": authority_hot,
			"schema": (
				"eralife.game_state."
				+ "war_contract_runtime_authority"
			),
			"version": 1,
			"engine_property": "war_contract_engine",
			"authority": "WarContractEngine",
			"created": created,
			"rebound": rebound,
			"resident_before_crown_observation": authority_hot,
			"click_path": false,
			"ready_gate_member": false,
			"ui_is_renderer_only": true,
			"at_ms": int(
				Time.get_ticks_msec()
			)
		}


func _normalize_external_birth_settings_for_runtime(settings: Dictionary) -> Dictionary:
	if birth_contract_engine == null:
		birth_contract_engine = BirthContractEngine.new(self)

	var context:= {
		"source": str(settings.get("source", "external_birth")),
		"fallback_name": str(settings.get("name", "Someone")),
		"world_mode": str(settings.get("world_mode", "solo")),
		"world_container_id": str(settings.get("world_container_id", "")),
		"life_node_id": str(settings.get("life_node_id", "")),
		"external_user_id": str(settings.get("external_user_id", ""))
	}

	var out: Dictionary = birth_contract_engine.normalize_birth_intent({
		"birth": settings.duplicate(true),
		"args": settings.duplicate(true)
	}, context)

	if not out.has("feature_overrides"):
		out ["feature_overrides"] = {}

	out ["_external_birth_intent"] = true
	out ["_god_mode_entry_kind"] = str(out.get("_god_mode_entry_kind", "external_birth_intent"))

	return out


func _normalize_external_birth_era_key(value: String) -> String:
	var clean: String = str(value).strip_edges()
	clean = clean.replace(" Era", "")
	clean = clean.replace(" era", "")

	match clean.to_lower():
		"ancient":
			return "Ancient"
		"medieval":
			return "Medieval"
		"industrial":
			return "Industrial"
		"modern":
			return "Modern"
		"future":
			return "Future"

	return "Modern"


func _external_birth_era_display_name(era_key: String) -> String:
	match _normalize_external_birth_era_key(era_key):
		"Ancient":
			return "Ancient Era"
		"Medieval":
			return "Medieval Era"
		"Industrial":
			return "Industrial Era"
		"Modern":
			return "Modern Era"
		"Future":
			return "Future Era"
		_:
			return "Modern Era"
func start_random_new_life(birth_settings: Dictionary = {}):
	_reset_runtime_state_for_fresh_life_boot(true)
	awaiting_new_life = true

	var has_external_birth: bool = typeof(birth_settings) == TYPE_DICTIONARY and not birth_settings.is_empty()

	if has_external_birth:
		custom_mode = true
		custom_settings = _normalize_external_birth_settings_for_runtime(birth_settings)
		year = int(custom_settings.get("year", year))
	else:
		custom_mode = false
		custom_settings = {}

	if typeof(scenario_state) != TYPE_DICTIONARY:
		scenario_state = {}

	scenario_state ["birth_shell_first_boot"] = true
	scenario_state ["birth_shell_deferred_boot_pending"] = true
	scenario_state ["birth_shell_deferred_boot_complete"] = false
	scenario_state ["defer_static_world_bootstrap"] = true
	scenario_state ["defer_live_runtime_watchers"] = true
	scenario_state ["deferred_data_bootstrap_pending"] = true
	scenario_state ["deferred_runtime_watchers_bootstrap"] = true
	scenario_state ["static_world_runtime_bootstrapped"] = false
	scenario_state ["post_spawn_ui_finalize_pending"] = true

	if has_external_birth:
		scenario_state ["external_birth_intent_active"] = true
		scenario_state ["external_birth_intent_source"] = str(custom_settings.get("source", "external_birth"))
		scenario_state ["external_birth_intent"] = custom_settings.duplicate(true)
	else:
		var temp_era_engine: EraEngine = era_engine
		if temp_era_engine == null:
			temp_era_engine = EraEngine.new(self)

		if temp_era_engine != null and temp_era_engine.eras.size() > 0:
			var era_keys: Array = temp_era_engine.eras.keys()
			var random_key: String = str(era_keys [randi() % era_keys.size()])
			var era_data = temp_era_engine.eras.get(random_key, {})
			var start_year: int = int(era_data.get("start_year", -3000))
			var end_year: int = int(era_data.get("end_year", 3000))
			if end_year < start_year:
				var swap_year:= start_year
				start_year = end_year
				end_year = swap_year
			year = randi_range(start_year, end_year)
		else:
			year = randi_range(-3000, 3000)

	initialize()

	if typeof(scenario_state) != TYPE_DICTIONARY:
		scenario_state = {}

	scenario_state ["defer_static_world_bootstrap"] = true
	scenario_state ["defer_live_runtime_watchers"] = true
	scenario_state ["deferred_data_bootstrap_pending"] = true
	scenario_state ["deferred_runtime_watchers_bootstrap"] = true
	scenario_state ["static_world_runtime_bootstrapped"] = false
	scenario_state ["post_spawn_ui_finalize_pending"] = true
	awaiting_new_life = false
func _bootstrap_static_world_runtime_state_for_new_life(
	max_stage_count: int = 1,
	runtime_owner: String = "boot_pre_warm"
) -> bool:
	if typeof(scenario_state) != TYPE_DICTIONARY:
		scenario_state = {}

	if bool(
		scenario_state.get(
			"static_world_runtime_bootstrapped",
			false
		)
	):
		return true

	var clean_runtime_owner: String = str(
		runtime_owner
	).strip_edges().to_lower()




	if (
		clean_runtime_owner.find("post_spawn") != -1
		and clean_runtime_owner.find("ui_safe") != -1
	):
		scenario_state [
			"static_world_runtime_bootstrap_paused_for_interactive_residency"
		] = true
		scenario_state [
			"static_world_runtime_bootstrap_pause_reason"
		] = "stage_contracts_not_intrinsically_bounded"
		scenario_state [
			"static_world_runtime_bootstrap_paused_owner"
		] = runtime_owner
		scenario_state [
			"static_world_runtime_bootstrap_paused_at_ms"
		] = int(Time.get_ticks_msec())
		return false

	if seed_engine == null:
		return false

	if int(seed_engine.seed_value) <= 0:
		var deferred_seed_contract_raw: Variant = scenario_state.get(
			"seed_contract",
			{}
		)

		if (
			typeof(deferred_seed_contract_raw) != TYPE_DICTIONARY
			and typeof(custom_settings) == TYPE_DICTIONARY
		):
			deferred_seed_contract_raw = custom_settings.get(
				"seed_contract",
				{}
			)

		var deferred_seed: int = -1

		if typeof(deferred_seed_contract_raw) == TYPE_DICTIONARY:
			deferred_seed = int(
				(deferred_seed_contract_raw as Dictionary).get(
					"seed",
					-1
				)
			)

		if deferred_seed <= 0:
			deferred_seed = int(
				scenario_state.get(
					"world_seed",
					-1
				)
			)

		if (
			deferred_seed <= 0
			and typeof(custom_settings) == TYPE_DICTIONARY
		):
			deferred_seed = int(
				custom_settings.get(
					"world_seed",
					-1
				)
			)

		if deferred_seed > 0:
			seed_engine.initialize({
				"seed": deferred_seed
			})
			scenario_state [
				"seed_bootstrap_deferred"
			] = false
		else:
			scenario_state [
				"seed_bootstrap_deferred"
			] = true
			return false

	if realm_engine == null:
		return false

	if (
		typeof(realm_engine.realms) != TYPE_DICTIONARY
		or realm_engine.realms.is_empty()
	):
		return false

	max_stage_count = clamp(
		max_stage_count,
		1,
		2
	)

	var boot_state_raw: Variant = scenario_state.get(
		"_static_world_bootstrap_state",
		{}
	)
	var boot_state: Dictionary = (
		boot_state_raw
		if typeof(boot_state_raw) == TYPE_DICTIONARY
		else {}
	)

	if boot_state.is_empty():
		boot_state = {
			"cursor": 0,
			"stages": [
				"population",
				"factions",
				"relationships",
				"pressure",
				"runtime_plan",
				"warm_snapshot"
			]
		}

	var stages_raw: Variant = boot_state.get(
		"stages",
		[]
	)
	var stages: Array = (
		stages_raw
		if typeof(stages_raw) == TYPE_ARRAY
		else []
	)
	var cursor: int = int(
		boot_state.get(
			"cursor",
			0
		)
	)
	var processed: int = 0

	while (
		processed < max_stage_count
		and cursor < stages.size()
	):
		var stage_name: String = str(
			stages [cursor]
		)

		match stage_name:
			"population":
				if (
					population_lifecycle_manager != null
					and population_lifecycle_manager.has_method(
						"bootstrap_pre_ui_population_state"
					)
				):
					population_lifecycle_manager.bootstrap_pre_ui_population_state(
						true
					)

			"factions":
				if (
					universal_faction_engine != null
					and universal_faction_engine.has_method(
						"bootstrap_static_projection_stage"
					)
				):
					universal_faction_engine.bootstrap_static_projection_stage(
						"factions"
					)

			"relationships":
				if (
					universal_faction_engine != null
					and universal_faction_engine.has_method(
						"bootstrap_static_projection_stage"
					)
				):
					universal_faction_engine.bootstrap_static_projection_stage(
						"relationships"
					)

			"pressure":
				if (
					universal_faction_engine != null
					and universal_faction_engine.has_method(
						"bootstrap_static_projection_stage"
					)
				):
					universal_faction_engine.bootstrap_static_projection_stage(
						"pressure"
					)

			"runtime_plan":
				_rebuild_npc_index()
				_soft_unload_npcs()

				if (
					simulation_director != null
					and simulation_director.has_method(
						"build_runtime_plan"
					)
					and player != null
				):
					var warm_plan: Dictionary = simulation_director.build_runtime_plan({
						"year": int(year + 1),
						"mode": "living",
						"player_id": int(player.id),
						"runtime_owner": runtime_owner
					})

					scenario_state [
						"warm_runtime_plan"
					] = {
						"year": int(year + 1),
						"mode": "living",
						"player_id": int(player.id),
						"plan": warm_plan.duplicate(true)
					}

			"warm_snapshot":
				scenario_state [
					"warm_world_runtime_snapshot"
				] = _export_warm_runtime_snapshot()

			_:
				pass

		cursor += 1
		processed += 1

	boot_state [
		"cursor"
	] = cursor
	scenario_state [
		"_static_world_bootstrap_state"
	] = boot_state

	var finished: bool = (
		cursor >= stages.size()
	)

	if finished:
		scenario_state [
			"static_world_runtime_bootstrapped"
		] = true
		scenario_state [
			"warm_world_runtime_snapshot"
		] = _export_warm_runtime_snapshot()
		scenario_state.erase(
			"_static_world_bootstrap_state"
		)
		scenario_state.erase(
			"defer_static_world_bootstrap"
		)

	return finished
func _export_warm_runtime_snapshot() -> Dictionary:
	var snapshot: Dictionary = {
		"year": int(year),
		"player_id": int(player.id) if player != null else -1,
		"population_bootstrap_ready": bool(scenario_state.get("population_bootstrap_ready", false)),
		"static_world_runtime_bootstrapped": bool(scenario_state.get("static_world_runtime_bootstrapped", false)),
		"warm_runtime_plan": scenario_state.get("warm_runtime_plan", {}).duplicate(true)
	}
	if typeof(universal_faction_state) == TYPE_DICTIONARY:
		snapshot ["universal_faction_state"] = universal_faction_state.duplicate(true)
	return snapshot

func _restore_warm_runtime_snapshot(snapshot: Dictionary) -> bool:
	if typeof(snapshot) != TYPE_DICTIONARY or snapshot.is_empty():
		return false
	if typeof(scenario_state) != TYPE_DICTIONARY:
		scenario_state = {}
	if typeof(snapshot.get("universal_faction_state", {})) == TYPE_DICTIONARY:
		universal_faction_state = snapshot.get("universal_faction_state", {}).duplicate(true)
	if typeof(snapshot.get("warm_runtime_plan", {})) == TYPE_DICTIONARY:
		scenario_state ["warm_runtime_plan"] = snapshot.get("warm_runtime_plan", {}).duplicate(true)
	scenario_state ["population_bootstrap_ready"] = bool(snapshot.get("population_bootstrap_ready", false))
	scenario_state ["static_world_runtime_bootstrapped"] = bool(snapshot.get("static_world_runtime_bootstrapped", false))
	return bool(scenario_state.get("static_world_runtime_bootstrapped", false))
func create_custom_reincarnated_child(settings: Dictionary) -> Person:
	var slot_raw = settings.get("pending_reincarnation_slot", {})
	if typeof(slot_raw) != TYPE_DICTIONARY or slot_raw.is_empty():
		return null

	var mother: Person = get_or_reactivate_npc_by_id(int(slot_raw.get("mother_id", -1)))
	if mother == null or not mother.alive or mother.age < 16:
		return null

	var father: Person = null
	var father_id: int = int(slot_raw.get("father_id", -1))
	if father_id > 0:
		father = get_or_reactivate_npc_by_id(father_id)

	if father == null:
		father = npc_factory.create_random_npc(false)
		if father == null:
			return null
		father.gender = "Male"
		father.age = max(16, int(mother.age) + randi_range(-2, 8))
		father.birth_city = mother.home_city
		father.birth_country = mother.home_country
		father.home_city = mother.home_city
		father.home_country = mother.home_country
		apply_reality_rules_to_person(father)
		register_npc(father)

	var ghost_name: String = str(afterlife_state.get("ghost_name", "An old spirit"))
	var slot_label: String = str(slot_raw.get("label", "%s %s" % [mother.first_name, mother.last_name]))
	var carry_curse: bool = bool(afterlife_state.get("generational_curse", false))

	var child: Person = spawn_child(father, mother, false)
	if child == null:
		return null

	var custom_first_name: String = str(settings.get("first_name", "")).strip_edges()
	var custom_last_name: String = str(settings.get("last_name", "")).strip_edges()
	var custom_gender: String = str(settings.get("gender", "")).strip_edges()

	if custom_first_name != "":
		child.first_name = custom_first_name
	if custom_last_name != "":
		child.last_name = custom_last_name
	if custom_gender in ["Male", "Female", "Nonbinary"]:
		child.gender = custom_gender

	child.memories.append("A rare conception surrounded my beginning.")
	child.memories.append("Something ancient seemed present at my birth.")
	if carry_curse:
		if "GenerationalCurse" not in child.traits:
			child.traits.append("GenerationalCurse")
		child.memories.append("A generational curse lingered over my beginning.")

	push_world_feed(
		"%s was reborn into the family line through %s." % [ghost_name, slot_label],
		{
			"npc_id": child.id,
			"personally_relevant": true,
			"category": "afterlife",
			"event_name": "afterlife_reincarnation",
			"source": "afterlife_influence_engine"
		}
	)

	player = child
	player_id = child.id
	awaiting_new_life = false
	afterlife_active = false
	transient_afterlife_biases.clear()
	afterlife_state.clear()
	custom_settings.erase("pending_reincarnation_slot")
	_ensure_loaded_player_lineage()
	reset_rewind_support_for_new_life()
	return child
func reset_world():
	start_random_new_life()
func _build_rewind_snapshot_base_out(saved_at_unix: int, player_name: String, player_age: int) -> Dictionary:
	return {
		"year": year,
		"next_id": next_id,
		"era_name": era.name,
		"player_id": player_id,
		"player_name": player_name,
		"last_saved_age": player_age,
		"saved_at_unix": saved_at_unix,
		"npcs": [],
	}

func _build_rewind_snapshot_collect_section(section_index: int, serializable_scenario_state: Dictionary) -> Dictionary:
	match section_index:
		0:
			return {
				"dormant_npcs": dormant_npcs,
				"memories": memories,
				"population_shards": population_shard_engine.population_shards,
				"lineage_ledger": population_shard_engine.lineage_ledger,
				"dynasties": dynasty_engine.dynasties,
				"agent_observer_memories": agent_memory_propagation_engine.observer_memories,
				"compressed_memories": compressed_memories,
				"npc_graveyard": npc_graveyard,
				"archive_generations": archive_generations,
				"save_version": save_version,
			}
		1:
			return {
				"world_chronicle": world_chronicle_engine.timeline,
				"historical_timeline": historical_timeline_engine.timeline,
				"world_feed": world_feed,
				"artifacts_ownership": artifacts_engine.ownership,
				"artifacts_cosmic_karma": artifacts_engine.cosmic_karma,
				"artifacts_pending_galactic_enforcer": artifacts_engine.pending_galactic_enforcer,
				"dragonballs_ownership": dragonballs_engine.ownership,
				"red_bonnet_owner_id": red_bonnet_engine.owner_id,
			}
		2:
			return {
				"school_enrollment": school_engine.enrollment,
				"school_rosters": school_engine.school_rosters,
				"school_teachers": school_engine.school_teachers,
				"workplace_rosters": workplace_engine.workplace_rosters,
				"workplace_meta": workplace_engine.workplace_meta,
				"npc_workplace": workplace_engine.npc_workplace,
				"properties": property_engine.properties,
				"used_addresses": property_engine.used_addresses,
				"vehicles": vehicle_engine.vehicles,
				"heirlooms": heirloom_engine.heirlooms,
				"islands": island_realm_engine.islands,
				"belongings": belongings_engine.belongings,
			}
		3:
			var rewind_realm_contract_registry: Dictionary = {}
			if realm_contract_engine != null and realm_contract_engine.has_method("export_registry"):
				rewind_realm_contract_registry = realm_contract_engine.export_registry()

			return {
				"realm_realms": realm_engine.realms,
				"realm_contract_registry": rewind_realm_contract_registry,
				"social_graph": social_graph_engine.graph,
				"world_space_tiles": world_space_engine.tiles,
				"world_space_npc_tile": world_space_engine.npc_tile,
				"chunk_sim_chunks": chunk_simulation_engine.chunks,
				"global_market": global_market_engine.goods_market,
				"dynasty_reputation": dynasty_legacy_engine.dynasty_reputation,
				"dynasty_grudges": dynasty_legacy_engine.dynasty_grudges,
				"legacy_dynasty_memories": legacy_memory_engine.dynasty_memories,
				"legacy_npc_memory_of_dynasty": legacy_memory_engine.npc_memory_of_dynasty,
				"many_realms_hidden_realms": many_realms_engine.hidden_realms,
				"many_realms_ring_owner_id": many_realms_engine.ring_owner_id,
				"npc_memory_graph": npc_memory_web_engine.memory_graph,
			}
		4:
			return {
				"boxing_rankings": boxing_ranking_engine.rankings,
				"boxing_champions": boxing_title_engine.champions,
				"boxing_lineages": boxing_title_engine.lineages,
				"boxing_rivalries": boxing_rivalry_engine.rivalries,
				"boxing_promoter_state": boxing_promotion_engine.promoter_state,
				"boxing_mandatories": boxing_mandatory_engine.mandatories,
				"boxing_media_state": boxing_media_engine.media_state,
				"boxing_family_legacy": boxing_legacy_engine.family_legacy,
				"vampire_covens": vampire_society_engine.covens,
				"vampire_hunter_orders": vampire_hunter_engine.hunter_orders,
				"vampire_bloodlines": vampire_legacy_engine.bloodlines,
				"vampire_family_legacy": vampire_legacy_engine.family_legacy,
				"vampire_global_state": vampire_engine.global_state,
				"legacy_echo_registry": legacy_echo_engine.echo_registry,
				"afterlife_active": afterlife_active,
				"afterlife_state": afterlife_state,
				"lineage_influence_profiles": lineage_influence_profiles,
				"transient_afterlife_biases": transient_afterlife_biases,
				"scenario_state": serializable_scenario_state,
				"scenario_history": scenario_history,
				"transient_scenario_biases": transient_scenario_biases,
				"custom_mode": custom_mode,
				"custom_settings": custom_settings,
				"reality_mode": reality_mode,
				"feature_overrides": reality_feature_overrides,
				"universal_faction_state": universal_faction_engine.export_state() if universal_faction_engine != null else universal_faction_state,
			}
		_:
			return {}
func _apply_player_starting_artifact_loadout():
	if player == null:
		return
	if not custom_mode:
		return
	if custom_settings == null:
		return
	if not is_feature_enabled("artifacts"):
		return

	var household_contract: Dictionary = _custom_household_spawn_contract()
	var household_artifact_policy: Dictionary = {}
	if typeof(household_contract.get("artifact_policy", {})) == TYPE_DICTIONARY:
		household_artifact_policy = household_contract.get("artifact_policy", {}).duplicate(true)

	var is_household_curated_life: bool = not household_contract.is_empty()
	var allow_random_household_artifacts: bool = bool(household_artifact_policy.get("allow_random_starting_artifacts", false))

	if is_household_curated_life and not allow_random_household_artifacts:
		custom_settings ["starting_infinity_stones"] = 0

	var stone_count:= int(custom_settings.get("starting_infinity_stones", 0))
	stone_count = clamp(stone_count, 0, 6)

	if stone_count > 0 and artifacts_engine != null:
		var existing_life_artifact_origin: bool = is_household_curated_life and int(player.age) > 0
		var awarded_stones: Array = artifacts_engine.give_random_unique_stones(player, stone_count, {
			"source": "existing_life_artifact_loadout" if existing_life_artifact_origin else "birth_loadout",
			"event_source": "custom_household_existing_life_artifact_loadout" if existing_life_artifact_origin else "god_mode_birth_loadout",
			"skip_world_feed": true,
			"skip_memory_append": true,
			"skip_player_narrative_log": true,
			"skip_event_emit": true
		})

		if not awarded_stones.is_empty():
			if fame_engine != null:
				fame_engine.give_fame(player, int(40 * awarded_stones.size()))

			var stone_display_names: Array = []
			for raw_stone in awarded_stones:
				stone_display_names.append("The %s Stone" % str(raw_stone))

			var stone_phrase:= ""
			if stone_display_names.size() == 1:
				stone_phrase = stone_display_names [0]
			elif stone_display_names.size() == 2:
				stone_phrase = "%s & %s" % [stone_display_names [0], stone_display_names [1]]
			else:
				var lead_names:= PackedStringArray()
				for i in range(stone_display_names.size() - 1):
					lead_names.append(str(stone_display_names [i]))
				stone_phrase = "%s, & %s" % [", ".join(lead_names), stone_display_names [stone_display_names.size() - 1]]

			if existing_life_artifact_origin:
				player.memories.append("Everything changed when I found %s." % stone_phrase)
				push_world_feed(
					"Rumors spread that %s %s came into contact with %s." % [player.first_name, player.last_name, stone_phrase],
					{
						"npc_id": player.id,
						"personally_relevant": true,
						"category": "artifact",
						"event_name": "artifact_existing_life_discovery_loadout",
						"source": "custom_household_existing_life_artifact_loadout",
						"suppress_diary": true
					}
				)
			else:
				player.memories.append(
					"I was blessed to be born with %s. It's made me massively famous. My mom says with \"great power, comes great responsibility\"." % stone_phrase
				)
				push_world_feed(
					"%s %s was born with %s." % [player.first_name, player.last_name, stone_phrase],
					{
						"npc_id": player.id,
						"personally_relevant": true,
						"category": "artifact",
						"event_name": "artifact_birth_loadout",
						"source": "god_mode_birth_loadout",
						"suppress_diary": true
					}
				)

	var start_with_red_bonnet:= bool(custom_settings.get("start_with_red_bonnet", false))
	if start_with_red_bonnet and red_bonnet_engine != null:
		red_bonnet_engine.give_to_npc(player)



func _is_active_person_ref(person: Person) -> bool:
	if person == null:
		return false

	return get_npc_by_id(person.id) == person


func detach_partner_ref(npc: Person) -> void:
	if npc == null:
		return

	var partner = npc.partner
	npc.partner = null

	if npc.marital_status in ["Married", "Partnered"]:
		npc.marital_status = "Single"


	if partner != null and partner.partner == npc:
		partner.partner = null
		if partner.marital_status in ["Married", "Partnered"]:
			partner.marital_status = "Single"

func _reset_runtime_state_for_fresh_life_boot(clear_custom_settings: bool = true) -> void:
	if year_budget_engine != null and year_budget_engine.has_method("cancel_year_pipeline"):
		year_budget_engine.call("cancel_year_pipeline")

	npcs.clear()
	npc_index.clear()
	memories.clear()
	world_feed.clear()
	npc_graveyard.clear()
	compressed_memories.clear()
	dormant_npcs.clear()
	pending_death_messages.clear()
	pending_inheritance_messages.clear()
	pending_year_resolution_popups.clear()
	pending_player_line_birth = {}
	archive_generations.clear()
	controlled_lineage_ids.clear()
	universal_faction_state.clear()
	school_rosters.clear()

	if agent_memory_propagation_engine != null:
		agent_memory_propagation_engine.observer_memories.clear()
	if npc_memory_web_engine != null:
		npc_memory_web_engine.memory_graph.clear()
	if simulation_director != null:
		simulation_director.runtime_cached_relevance.clear()
		simulation_director.runtime_last_report.clear()



	afterlife_active = false
	afterlife_state.clear()
	lineage_influence_profiles.clear()
	transient_afterlife_biases.clear()
	if lineage_engine != null and lineage_engine.has_method("reset_runtime"):
		lineage_engine.reset_runtime()


	scenario_history.clear()
	scenario_state.clear()
	transient_scenario_biases.clear()

	if scenario_engine != null:
		scenario_engine.reset_for_new_life()
	if world_chronicle_engine != null:
		world_chronicle_engine.timeline.clear()
	if historical_timeline_engine != null:
		historical_timeline_engine.timeline.clear()

	realtime_enabled = false
	awaiting_new_life = false

	if clear_custom_settings:
		custom_mode = false
		custom_settings = {}

	reset_rewind_support_for_new_life()
	rewind_snapshot_paths.clear()
	year_locked = false
	next_id = 1
	player = null
	player_id = 0

	scenario_state ["defer_static_world_bootstrap"] = true
	scenario_state ["deferred_data_bootstrap_pending"] = true
	scenario_state ["static_world_runtime_bootstrapped"] = false
	scenario_state ["post_spawn_ui_finalize_pending"] = true
	scenario_state.erase("_static_world_bootstrap_state")
	scenario_state.erase("warm_runtime_plan")
	scenario_state.erase("warm_world_runtime_snapshot")
	scenario_state.erase("loading_runtime")
	scenario_state.erase("post_runtime_result")
	scenario_state.erase("runtime_guard")
func end_partnership(
	npc: Person,
	add_ex_partners:= false
) -> void:
	if npc == null:
		return

	var partner: Person = npc.partner

	if partner == null:



		if str(
			npc.marital_status
		) in [
			"Widow",
			"Widower",
			"Widowed",
			"Divorced"
		]:
			return

		if (
			add_ex_partners
			and str(
				npc.marital_status
			) == "Married"
		):
			npc.marital_status = "Divorced"
		elif str(
			npc.marital_status
		) in [
			"Dating",
			"Partnered",
			"Engaged"
		]:
			npc.marital_status = "Single"

		return

	var npc_status_before: String = str(
		npc.marital_status
	)
	var partner_status_before: String = str(
		partner.marital_status
	)

	var legal_marriage: bool = (
		npc_status_before == "Married"
		or partner_status_before == "Married"
	)

	if add_ex_partners:
		if int(
			partner.id
		) not in npc.ex_partners:
			npc.ex_partners.append(
				int(
					partner.id
				)
			)

		if int(
			npc.id
		) not in partner.ex_partners:
			partner.ex_partners.append(
				int(
					npc.id
				)
			)

	npc.partner = null

	if partner.partner == npc:
		partner.partner = null

	if (
		add_ex_partners
		and legal_marriage
	):
		npc.marital_status = "Divorced"
		partner.marital_status = "Divorced"
	else:
		if npc_status_before in [
			"Dating",
			"Partnered",
			"Engaged"
		]:
			npc.marital_status = "Single"

		if partner_status_before in [
			"Dating",
			"Partnered",
			"Engaged"
		]:
			partner.marital_status = "Single"
func _widowed_marital_status_for_gender(
	gender_value: Variant
) -> String:
	var gender_text: String = str(
		gender_value
	).strip_edges().to_lower()

	match gender_text:
		"female":
			return "Widow"

		"male":
			return "Widower"

		_:
			return "Widowed"


func mark_surviving_spouse_widowed(
	deceased: Person
) -> void:
	if (
		deceased == null
		or deceased.partner == null
	):
		return

	if str(
		deceased.marital_status
	).strip_edges().to_lower() != "married":
		return

	var survivor: Person = deceased.partner

	if (
		survivor == null
		or not survivor.alive
		or str(
			survivor.marital_status
		).strip_edges().to_lower()
		!= "married"
	):
		return

	survivor.marital_status = (
		_widowed_marital_status_for_gender(
			survivor.gender
		)
	)




	if event_bus != null:
		event_bus.emit(
			"relationship.spouse_widowed",
			{
				"actor_id": int(
					survivor.id
				),
				"deceased_spouse_id": int(
					deceased.id
				),
				"marital_status": str(
					survivor.marital_status
				),
				"qos_tier": "important",
				"fanout_hints": {
					"force_defer_bus": true
				}
			}
		)


func mark_surviving_spouse_widowed_from_snapshot(
	deceased_snapshot: Dictionary,
	deceased_id: int
) -> void:
	if (
		deceased_snapshot.is_empty()
		or deceased_id <= 0
	):
		return

	var marital_status: String = str(
		deceased_snapshot.get(
			"marital_status",
			""
		)
	).strip_edges().to_lower()

	if marital_status != "married":
		return

	var partner_id: int = int(
		deceased_snapshot.get(
			"partner_id",
			-1
		)
	)

	if partner_id <= 0:
		return

	var survivor: Person = get_npc_by_id(
		partner_id,
		false
	)

	if (
		survivor == null
		or not survivor.alive
		or str(
			survivor.marital_status
		).strip_edges().to_lower()
		!= "married"
	):
		return

	survivor.marital_status = (
		_widowed_marital_status_for_gender(
			survivor.gender
		)
	)


func get_valid_partner(npc: Person, require_reciprocal:= true, allow_reactivate:= false) -> Person:
	if npc == null:
		return null
	if not npc.alive:
		return null

	var partner = npc.partner
	if partner == null:
		return null


	if partner == npc:
		detach_partner_ref(npc)
		return null

	if allow_reactivate and not _is_active_person_ref(partner):
		var reactivated_partner: Person = get_or_reactivate_npc_by_id(int(partner.id))
		if reactivated_partner != null:
			partner = reactivated_partner
			npc.partner = reactivated_partner


	if not _is_active_person_ref(partner):
		return null
	if not partner.alive:
		return null


	if require_reciprocal:
		if allow_reactivate and partner.partner != npc and partner.partner != null:
			var reciprocal_partner: Person = get_or_reactivate_npc_by_id(int(partner.partner.id))
			if reciprocal_partner != null:
				partner.partner = reciprocal_partner
		if partner.partner != npc:
			return null

	return partner


func can_create_child(parent1: Person, parent2: Person, require_reciprocal_partner:= false) -> bool:
	if parent1 == null or parent2 == null:
		return false

	if parent1 == parent2:
		return false

	if not parent1.alive or not parent2.alive:
		return false

	if not _is_active_person_ref(parent1) or not _is_active_person_ref(parent2):
		return false


	if parent1.age < 16 or parent2.age < 16:
		return false

	if require_reciprocal_partner:
		if get_valid_partner(parent1, true) != parent2:
			return false
		if get_valid_partner(parent2, true) != parent1:
			return false

	return true


func register_npc(npc: Person) -> void:
	if npc == null:
		return
	if get_npc_by_id(npc.id) == null:
		npcs.append(npc)
	_remember_npc_in_index(npc)

	if geo_engine != null:
		geo_engine.bootstrap_person_place(npc)

	if world_space_engine != null:
		world_space_engine.place_npc(npc)

	if settlement_presence_engine != null:
		settlement_presence_engine.register_active_presence(npc)

	if chunk_simulation_engine != null:
		chunk_simulation_engine.assign_npc(npc)


func spawn_child(parent1: Person, parent2: Person, require_reciprocal_partner:= false) -> Person:
	if not can_create_child(parent1, parent2, require_reciprocal_partner):
		return null

	var child = npc_factory.create_child(parent1, parent2)
	if child == null:
		return null

	register_npc(child)
	return child

func get_dormant_npc_snapshot(id: int) -> Dictionary:
	return dormant_npcs.get(id, {})


func get_or_reactivate_npc_by_id(id: int) -> Person:
	var active = get_npc_by_id(id)
	if active != null:
		return active

	if dormant_npcs.has(id):
		return reactivate_npc(id)

	if population_lifecycle_manager != null:
		return population_lifecycle_manager.reconstruct_or_activate_by_id(id)

	return null


func _world_distance_to_player(npc: Person) -> int:
	if npc == null or player == null:
		return 999999

	var a = world_space_engine.get_position(player)
	var b = world_space_engine.get_position(npc)
	return abs(a.x - b.x) + abs(a.y - b.y)


func _npc_has_artifacts(npc: Person) -> bool:
	if npc == null:
		return false

	if artifacts_engine != null and artifacts_engine.ownership.has(npc.id):
		if artifacts_engine.ownership [npc.id].size() > 0:
			return true

	if dragonballs_engine != null and dragonballs_engine.ownership.has(npc.id):
		if dragonballs_engine.ownership [npc.id].size() > 0:
			return true

	if red_bonnet_engine != null and red_bonnet_engine.owner_id == npc.id:
		return true

	if many_realms_engine != null and many_realms_engine.ring_owner_id == npc.id:
		return true

	return false


func _npc_is_dormancy_protected(
		npc: Person
) -> bool:
	if npc == null:
		return true

	if npc == player:
		return true

	if controlled_lineage_ids.has(
		int(
			npc.id
		)
	):
		return true

	if (
		family_control_engine != null
		and int(
			family_control_engine.last_player_id
		) == int(
			npc.id
		)
	):
		return true

	if not npc.alive:
		return true



	if (
		typeof(
			npc.traits
		) == TYPE_ARRAY
		and "PrisonGuard" in npc.traits
	):
		return true

	if (
		npc.id in player.parents
		or npc.id in player.children
	):
		return true


	if (
		player.parents.size() > 0
		and npc.parents == player.parents
		and npc.id != player.id
	):
		return true

	if npc.id in player.friends:
		return true

	if player.partner == npc:
		return true

	if npc.id in player.ex_partners:
		return true

	if npc.partner != null:
		return true

	if (
		npc.is_ruler
		or npc.is_royal
	):
		return true

	if npc.fame >= 25:
		return true

	if _npc_has_artifacts(
		npc
	):
		return true

	if (
		school_engine != null
		and school_engine.are_classmates(
			player,
			npc
		)
	):
		return true

	if (
		_world_distance_to_player(
			npc
		) <= spatial_culling_engine.MID_RADIUS
	):
		return true

	return false

func _remove_npc_from_active_indices(npc: Person) -> void:
	if npc == null:
		return


	if world_space_engine != null:
		var tile = world_space_engine.npc_tile.get(npc.id, null)
		if tile != null and world_space_engine.tiles.has(tile):
			world_space_engine.tiles [tile].erase(npc.id)
			if world_space_engine.tiles [tile].is_empty():
				world_space_engine.tiles.erase(tile)
		world_space_engine.npc_tile.erase(npc.id)


	if chunk_simulation_engine != null:
		chunk_simulation_engine.remove_npc(npc)


func deactivate_npc(npc: Person) -> bool:
	if npc == null:
		return false

	if _npc_is_dormancy_protected(npc):
		return false

	if dormant_npcs.has(npc.id):
		return false

	var snapshot = _serialize_npc(npc)
	snapshot ["_dormant"] = true
	snapshot ["_dormant_year"] = year
	snapshot ["_query_facts"] = _extract_queryable_npc_facts(snapshot)

	var collapsed:= false
	if population_shard_engine != null:
		collapsed = population_shard_engine.collapse_snapshot_to_shard(snapshot)

	if not collapsed:
		dormant_npcs [npc.id] = snapshot
	_remove_npc_from_active_indices(npc)
	npcs.erase(npc)
	_forget_npc_from_index(npc.id)
	return true


func reactivate_npc(npc_id: int) -> Person:
	if not dormant_npcs.has(npc_id):
		return null

	var d = dormant_npcs [npc_id]
	var npc = _deserialize_npc(d)
	var partner_id: int = int(
		d.get(
			"partner_id",
			-1
		)
	)

	npcs.append(npc)
	_remember_npc_in_index(npc)
	dormant_npcs.erase(npc_id)

	if geo_engine != null:
		geo_engine.bootstrap_person_place(npc)
	if world_space_engine != null:
		world_space_engine.place_npc(npc)
	if settlement_presence_engine != null:
		settlement_presence_engine.register_active_presence(npc)

	if chunk_simulation_engine != null:
		chunk_simulation_engine.assign_npc(npc)





	if (
		partner_id > 0
		and partner_id != npc_id
	):
		var partner: Person = get_npc_by_id(
			partner_id
		)

		if partner == null:
			partner = get_or_reactivate_npc_by_id(
				partner_id
			)

		if (
			partner != null
			and partner != npc
		):
			npc.partner = partner

			var reciprocal_facts: Dictionary = (
				get_npc_facts_by_id(
					partner_id
				)
			)

			if (
				int(
					reciprocal_facts.get(
						"partner_id",
						-1
					)
				) == npc_id
			):
				partner.partner = npc

	if (
		royalty_engine != null
		and royalty_engine.has_method(
			"_sync_royal_job_identity"
		)
	):
		if (
			bool(npc.is_ruler)
			or bool(npc.is_royal)
			or int(npc.succession_rank) > 0
			or str(
				npc.royal_title
			).strip_edges() != ""
		):
			royalty_engine._sync_royal_job_identity(
				npc
			)

	return npc
func _build_dormant_death_payload(d: Dictionary, fallback_id: int) -> Dictionary:
	var npc_id:= int(d.get("id", fallback_id))
	var first_name:= str(d.get("first_name", ""))
	var last_name:= str(d.get("last_name", ""))
	var cause:= str(d.get("cause_of_death", "Unknown"))
	var age:= int(d.get("age", 0))
	var full_name:= ("%s %s" % [first_name, last_name]).strip_edges()
	if full_name == "":
		full_name = "Someone"
	var world_feed_text:= "%s died at age %d. Cause: %s." % [
		full_name,
		age,
		cause
	]
	return {
		"type": "death",
		"npc_id": npc_id,
		"name": full_name,
		"text": "%s died." % full_name,
		"world_feed_text": world_feed_text,
		"cause": cause,
		"category": "death",
		"event_name": "death",
		"queue_world_feed": true,
		"source_state": "dormant",
		"source": "simulate_dormant_population",
		"npc_facts": _extract_queryable_npc_facts(d)
	}
func build_death_world_feed_text(dead_name: String, age_at_death: int, cause: String, npc_id: int = -1) -> String:
	var clean_name: String = str(dead_name).strip_edges()
	if clean_name == "":
		clean_name = "Someone"

	var clean_cause: String = str(cause).strip_edges()
	if clean_cause == "":
		clean_cause = "unknown causes"

	var base_text: String = "%s died at age %d. Cause: %s." % [
		clean_name,
		int(age_at_death),
		clean_cause
	]

	var flavor_text: String = _death_world_feed_flavor(clean_name, int(age_at_death), clean_cause, int(npc_id))
	if flavor_text == "":
		return base_text

	return "%s %s" % [base_text, flavor_text]


func _death_world_feed_flavor(dead_name: String, age_at_death: int, cause: String, npc_id: int = -1) -> String:
	var clean_name: String = str(dead_name).strip_edges()
	if clean_name == "":
		clean_name = "Someone"

	var options: Array = [
		"%s laughed at the circumstances." % clean_name,
		"%s left behind more questions than answers." % clean_name,
		"%s became one more rumor the town refused to let die." % clean_name,
		"%s's final chapter hit harder than anybody expected." % clean_name,
		"%s's name moved quietly through the streets afterward." % clean_name,
		"%s left people whispering in corners." % clean_name,
		"%s somehow made death feel dramatic." % clean_name,
		"%s's passing bent the mood of the whole year." % clean_name,
		"%s went out with the world still talking." % clean_name,
		"%s left behind a silence nobody knew what to do with." % clean_name,
		"%s's death became the kind of story people retell badly." % clean_name,
		"%s left memories, debts, and awkward family silence." % clean_name,
		"%s made the obituary sound underprepared." % clean_name,
		"%s's exit had everybody acting brand new." % clean_name,
		"%s left the room permanently and somehow still became the topic." % clean_name,
		"%s's passing gave the year a colder edge." % clean_name,
		"%s left the timeline looking at itself funny." % clean_name,
		"%s had people saying, 'life is short' like they just discovered math." % clean_name,
		"%s left behind grief with side quests." % clean_name,
		"%s's death did not stay private for long." % clean_name,
		"%s left the family group chat dangerously quiet." % clean_name,
		"%s's name carried different weight after that." % clean_name,
		"%s gave the world one last uncomfortable pause." % clean_name,
		"%s exited life like the credits rolled too early." % clean_name,
		"%s left people pretending they had closure." % clean_name,
		"%s became a memory with unresolved business." % clean_name,
		"%s's passing put everybody's priorities on trial." % clean_name,
		"%s made mortality feel loud for a minute." % clean_name,
		"%s left behind the kind of silence that talks." % clean_name,
		"%s died, and the year immediately got weird about it." % clean_name
	]

	if options.is_empty():
		return ""

	var seed_text: String = "%d|%d|%d|%s|death_world_feed_flavor" % [
		int(npc_id),
		int(age_at_death),
		int(year),
		str(cause)
	]
	var index: int = abs(hash(seed_text)) % options.size()
	return str(options [index])
func _family_death_notice_key(dead_id: int, observer_id: int = -1) -> String:
	var clean_observer_id: int = int(observer_id)
	if clean_observer_id <= 0 and player != null:
		clean_observer_id = int(player.id)

	return "%d|%d|family_death_pending_notice" % [clean_observer_id, int(dead_id)]


func _family_death_notice_already_queued(dead_id: int) -> bool:
	if typeof(scenario_state) != TYPE_DICTIONARY:
		return false

	var registry_raw: Variant = scenario_state.get("family_death_notice_registry", {})
	var registry: Dictionary = {}

	if typeof(registry_raw) == TYPE_DICTIONARY:
		registry = registry_raw.duplicate(true)

	return bool(registry.get(_family_death_notice_key(dead_id), false))


func _mark_family_death_notice_queued(dead_id: int) -> void:
	if typeof(scenario_state) != TYPE_DICTIONARY:
		scenario_state = {}

	var registry_raw: Variant = scenario_state.get("family_death_notice_registry", {})
	var registry: Dictionary = {}

	if typeof(registry_raw) == TYPE_DICTIONARY:
		registry = registry_raw.duplicate(true)

	registry [_family_death_notice_key(dead_id)] = true
	scenario_state ["family_death_notice_registry"] = registry


func _build_family_death_funeral_popup(
	death_text: String,
	relationship_label: String,
	dead_name: String,
	dead_id: int,
	inheritance_report: Dictionary = {},
	responsible_person: Person = null,
	cause_of_death: String = ""
) -> Dictionary:
	var clean_relation: String = str(relationship_label).strip_edges()
	if clean_relation == "":
		clean_relation = "relative"

	var clean_dead_name: String = str(dead_name).strip_edges()
	if clean_dead_name == "":
		clean_dead_name = "Someone"

	var cause: String = str(cause_of_death).strip_edges()
	if cause == "":
		cause = "unknown causes"

	var clean_death_text: String = str(death_text).strip_edges()
	if clean_death_text == "":
		clean_death_text = "My %s %s died from %s." % [clean_relation, clean_dead_name, cause]

	var viewer_id: int = int(player.id) if player != null else -1
	var responsible_id: int = int(responsible_person.id) if responsible_person != null else -1
	var viewer_is_responsible: bool = viewer_id > 0 and responsible_id == viewer_id

	var responsibility_sentence: String = ""
	if viewer_is_responsible:
		responsibility_sentence = "You are responsible for setting up the funeral. What will you do?"
	else:
		var responsible_relation: String = _family_funeral_responsible_relation_label(responsible_person)
		var responsible_name: String = str(responsible_person.first_name).strip_edges() if responsible_person != null else "someone"
		if responsible_name == "":
			responsible_name = "someone"
		responsibility_sentence = "Your %s %s is responsible for setting up their funeral. What will you do?" % [
			responsible_relation,
			responsible_name
		]

	var details: String = "Your %s %s has died of %s. %s" % [
		clean_relation,
		clean_dead_name,
		cause,
		responsibility_sentence
	]

	var inheritance_contract: Dictionary = _build_family_inheritance_pending_contract(
		clean_relation,
		clean_dead_name,
		int(dead_id),
		cause,
		inheritance_report
	)

	var options: Array = []
	if viewer_is_responsible:
		options = [
			{
				"id": "pay_for_funeral",
				"label": "Pay for the funeral",
				"source_resolves": true,
				"priority": 90,
				"journal_text": "I accepted responsibility for planning my %s %s's funeral." % [clean_relation, clean_dead_name],
				"result_text": "You begin making funeral arrangements.",
				"followup_pending_contract": _build_family_funeral_type_pending_contract(clean_relation, clean_dead_name, int(dead_id), cause, inheritance_contract)
			},
			{
				"id": "delay_funeral",
				"label": "Delay the arrangements",
				"source_resolves": true,
				"priority": 20,
				"journal_text": "I delayed planning my %s %s's funeral." % [clean_relation, clean_dead_name],
				"result_text": "You delay the arrangements. The family pressure does not disappear."
			}
		]
	else:
		options = [
			{
				"id": "go_say_nothing",
				"label": "Go and say nothing",
				"source_resolves": true,
				"priority": 45,
				"journal_text": "I went to my %s %s's funeral and said nothing." % [clean_relation, clean_dead_name],
				"result_text": "You attend quietly.",
				"followup_pending_contract": inheritance_contract
			},
			{
				"id": "go_and_speak",
				"label": "Go and speak",
				"source_resolves": true,
				"priority": 55,
				"journal_text": "I spoke at my %s %s's funeral." % [clean_relation, clean_dead_name],
				"result_text": "You speak at the funeral.",
				"followup_pending_contract": inheritance_contract
			},
			{
				"id": "skip_funeral",
				"label": "Skip it",
				"source_resolves": true,
				"priority": 10,
				"journal_text": "I skipped my %s %s's funeral." % [clean_relation, clean_dead_name],
				"result_text": "You skip the funeral."
			},
			{
				"id": "offer_to_pay_and_go",
				"label": "Offer to pay (-%s) & Go" % _format_death_money_value(_family_funeral_offer_amount_for_viewer()),
				"source_resolves": true,
				"priority": 70,
				"bank_delta": - _family_funeral_offer_amount_for_viewer(),
				"journal_text": "I offered money toward my %s %s's funeral and attended." % [clean_relation, clean_dead_name],
				"result_text": "You offer money and attend the funeral.",
				"followup_pending_contract": inheritance_contract
			}
		]

	return {
		"schema": "eralife.family_death_pending_contract",
		"version": 1,
		"id": "family_death_notice_%d_%d" % [viewer_id, int(dead_id)],
		"contract_id": "family_death_notice_%d_%d" % [viewer_id, int(dead_id)],
		"contract_type": "scenario_popup",
		"target": viewer_id,
		"target_id": viewer_id,
		"issuer": int(dead_id),
		"issuer_id": int(dead_id),
		"participant_ids": _unique_positive_ids([viewer_id, int(dead_id), responsible_id]),
		"decision_actor_ids": [viewer_id],
		"category": "family_death",
		"request": "family_death_funeral_notice",
		"title": "SOMEBODY HAS DIED",
		"overview": "SOMEBODY HAS DIED",
		"details": details,
		"state": "pending",
		"visibility": "participant_visible",
		"requires_attention": true,
		"response_options": options,
		"urgency": 74.0,
		"decay": 0.0,
		"created_year": int(year),
		"created_age": float(player.age) if player != null else -1.0,
		"created_at_ms": int(Time.get_ticks_msec()),
		"updated_at_ms": int(Time.get_ticks_msec()),
		"dead_person_id": int(dead_id),
		"dead_person_name": clean_dead_name,
		"relationship_label": clean_relation,
		"cause_of_death": cause,
		"funeral_responsible_actor_id": responsible_id,
		"viewer_is_funeral_responsible": viewer_is_responsible,
		"source": "family_death_pending_situation",
		"contract_mesh": {
			"source_of_truth": "GameState",
			"popup_contract_owner": "ScenarioPopupContractEngine",
			"runtime_owner": "ScenarioRuntimeContractEngine",
			"pending_index_owner": "PendingSituationsEngine",
			"ui_observer": "PopupViewer",
			"one_contract_multiple_views": true,
			"persistent": true,
			"ui_mutation_allowed": false
		}
	}
func _emit_family_death_pending_situation(contract: Dictionary, target_id: int) -> Dictionary:
	if typeof(contract) != TYPE_DICTIONARY or contract.is_empty():
		return { "success": false, "reason": "empty_family_death_contract"}

	_ensure_family_death_pending_engines()

	if scenario_popup_contract_engine == null:
		return { "success": false, "reason": "missing_scenario_popup_contract_engine"}

	return scenario_popup_contract_engine.emit_popup_contract(contract, {
		"source": "family_death_pending_situation",
		"target_id": target_id
	})


func _ensure_family_death_pending_engines() -> void:
	if scenario_runtime_contract_engine == null:
		scenario_runtime_contract_engine = ScenarioRuntimeContractEngine.new(self)
	if scenario_popup_contract_engine == null:
		scenario_popup_contract_engine = ScenarioPopupContractEngine.new(self)
	if pending_situations_engine == null:
		pending_situations_engine = PendingSituationsEngine.new(self)


func _family_funeral_responsible_person_for_dead(dead_person: Person) -> Person:
	if dead_person == null:
		return player

	if dead_person.partner != null and dead_person.partner.alive:
		return dead_person.partner

	for raw_child_id in dead_person.children:
		var child: Person = get_npc_by_id(int(raw_child_id))
		if child != null and child.alive and int(child.age) >= 18:
			return child

	for raw_parent_id in dead_person.parents:
		var parent: Person = get_npc_by_id(int(raw_parent_id))
		if parent != null and parent.alive:
			return parent

	for raw_parent_id in dead_person.parents:
		var parent_for_siblings: Person = get_npc_by_id(int(raw_parent_id))
		if parent_for_siblings == null:
			continue
		for raw_sibling_id in parent_for_siblings.children:
			var sibling_id: int = int(raw_sibling_id)
			if sibling_id == int(dead_person.id):
				continue
			var sibling: Person = get_npc_by_id(sibling_id)
			if sibling != null and sibling.alive and int(sibling.age) >= 18:
				return sibling

	return player


func _family_funeral_responsible_person_from_snapshot(d: Dictionary, _dead_id: int) -> Person:
	if typeof(d) != TYPE_DICTIONARY:
		return player

	var partner_id: int = int(d.get("partner_id", -1))
	var partner: Person = get_npc_by_id(partner_id)
	if partner != null and partner.alive:
		return partner

	var children_raw: Variant = d.get("children", [])
	if typeof(children_raw) == TYPE_ARRAY:
		for raw_child_id in children_raw:
			var child: Person = get_npc_by_id(int(raw_child_id))
			if child != null and child.alive and int(child.age) >= 18:
				return child

	var parents_raw: Variant = d.get("parents", [])
	if typeof(parents_raw) == TYPE_ARRAY:
		for raw_parent_id in parents_raw:
			var parent: Person = get_npc_by_id(int(raw_parent_id))
			if parent != null and parent.alive:
				return parent

	return player


func _family_funeral_responsible_relation_label(responsible_person: Person) -> String:
	if responsible_person == null or player == null:
		return "relative"

	if int(responsible_person.id) == int(player.id):
		return "self"

	var label: String = _relationship_label_to_player(responsible_person)
	if label != "":
		return label

	return "relative"


func _family_funeral_offer_amount_for_viewer() -> int:
	if player == null:
		return 250

	var class_key: String = str(player.social_class).strip_edges().to_lower()
	match class_key:
		"poor", "lower", "lower class", "working", "working class", "commoner":
			return 125
		"upper", "upper class", "wealthy", "rich":
			return 1500
		"royal", "noble", "elite", "aristocrat":
			return 5000
		_:
			return 500


func _build_family_funeral_type_pending_contract(relationship_label: String, dead_name: String, dead_id: int, cause: String, inheritance_contract: Dictionary = {}) -> Dictionary:
	var target_id: int = int(player.id) if player != null else -1
	var options: Array = []

	for spec in _family_funeral_type_specs():
		var row: Dictionary = spec as Dictionary
		var funeral_type_id: String = str(row.get("id", "standard_funeral"))
		var funeral_label: String = str(row.get("label", "Standard funeral"))
		var funeral_cost: int = int(row.get("cost", 500))

		options.append({
			"id": funeral_type_id,
			"label": "%s (%s)" % [funeral_label, _format_death_money_value(funeral_cost)],
			"source_resolves": true,
			"priority": int(row.get("priority", 50)),
			"journal_text": "I chose a %s for my %s %s." % [funeral_label.to_lower(), relationship_label, dead_name],
			"result_text": "You choose a %s. Now you need to choose the burial method." % funeral_label.to_lower(),
			"followup_pending_contract": _build_family_burial_method_pending_contract(relationship_label, dead_name, dead_id, cause, funeral_label, funeral_cost, inheritance_contract)
		})

	return {
		"schema": "eralife.family_funeral_type_pending_contract",
		"version": 1,
		"id": "family_funeral_type_%d_%d" % [target_id, dead_id],
		"contract_id": "family_funeral_type_%d_%d" % [target_id, dead_id],
		"contract_type": "scenario_popup",
		"target": target_id,
		"target_id": target_id,
		"participant_ids": _unique_positive_ids([target_id, dead_id]),
		"decision_actor_ids": [target_id],
		"category": "family_death",
		"request": "family_funeral_type_selection",
		"title": "Choose Funeral Type",
		"overview": "FUNERAL ARRANGEMENTS",
		"details": "Choose what type of funeral your %s %s will have." % [relationship_label, dead_name],
		"state": "pending",
		"visibility": "participant_visible",
		"requires_attention": true,
		"response_options": options,
		"urgency": 70.0,
		"decay": 0.0,
		"created_year": int(year),
		"created_at_ms": int(Time.get_ticks_msec()),
		"updated_at_ms": int(Time.get_ticks_msec()),
		"source": "family_funeral_type_selection"
	}


func _build_family_burial_method_pending_contract(relationship_label: String, dead_name: String, dead_id: int, _cause: String, funeral_label: String, funeral_cost: int, inheritance_contract: Dictionary = {}) -> Dictionary:
	var target_id: int = int(player.id) if player != null else -1
	var options: Array = []

	for method in _family_burial_method_specs():
		var row: Dictionary = method as Dictionary
		var method_id: String = str(row.get("id", "burial"))
		var method_label: String = str(row.get("label", "Burial"))
		var method_cost: int = int(row.get("cost", 0))
		var total_cost: int = max(0, funeral_cost + method_cost)

		options.append({
			"id": method_id,
			"label": "%s - Total %s" % [method_label, _format_death_money_value(total_cost)],
			"source_resolves": true,
			"priority": int(row.get("priority", 50)),
			"bank_delta": - total_cost,
			"journal_text": "I paid for a %s with %s for my %s %s." % [
				funeral_label.to_lower(),
				method_label.to_lower(),
				relationship_label,
				dead_name
			],
			"result_text": "You pay for the funeral and choose %s." % method_label.to_lower(),
			"followup_pending_contract": inheritance_contract
		})

	return {
		"schema": "eralife.family_burial_method_pending_contract",
		"version": 1,
		"id": "family_burial_method_%d_%d" % [target_id, dead_id],
		"contract_id": "family_burial_method_%d_%d" % [target_id, dead_id],
		"contract_type": "scenario_popup",
		"target": target_id,
		"target_id": target_id,
		"participant_ids": _unique_positive_ids([target_id, dead_id]),
		"decision_actor_ids": [target_id],
		"category": "family_death",
		"request": "family_burial_method_selection",
		"title": "Choose Burial Method",
		"overview": "BURIAL METHOD",
		"details": "Choose how your %s %s will be laid to rest." % [relationship_label, dead_name],
		"state": "pending",
		"visibility": "participant_visible",
		"requires_attention": true,
		"response_options": options,
		"urgency": 68.0,
		"decay": 0.0,
		"created_year": int(year),
		"created_at_ms": int(Time.get_ticks_msec()),
		"updated_at_ms": int(Time.get_ticks_msec()),
		"source": "family_burial_method_selection"
	}


func _build_family_inheritance_pending_contract(relationship_label: String, dead_name: String, dead_id: int, cause: String, inheritance_report: Dictionary = {}) -> Dictionary:
	if typeof(inheritance_report) != TYPE_DICTIONARY:
		return {}
	if not bool(inheritance_report.get("inherited", false)):
		return {}

	var amount: int = int(inheritance_report.get("amount", 0))
	if amount <= 0:
		return {}

	var target_id: int = int(player.id) if player != null else -1

	return {
		"schema": "eralife.family_inheritance_pending_contract",
		"version": 1,
		"id": "family_inheritance_%d_%d" % [target_id, dead_id],
		"contract_id": "family_inheritance_%d_%d" % [target_id, dead_id],
		"contract_type": "scenario_popup",
		"target": target_id,
		"target_id": target_id,
		"participant_ids": _unique_positive_ids([target_id, dead_id]),
		"decision_actor_ids": [target_id],
		"category": "inheritance",
		"request": "family_inheritance_received",
		"title": "INHERITANCE RECEIVED",
		"overview": "INHERITANCE RECEIVED",
		"details": "Your %s %s, who died of %s, has left you %s in their will. How do you react?" % [
			relationship_label,
			dead_name,
			cause,
			_format_death_money_value(amount)
		],
		"state": "pending",
		"visibility": "participant_visible",
		"requires_attention": true,
		"response_options": [
			{
				"id": "accept_scream_hallelujah",
				"label": "Accept & Scream Hallelujah",
				"source_resolves": true,
				"priority": 90,
				"bank_delta": amount,
				"journal_text": "I accepted %s from my %s %s and screamed Hallelujah." % [_format_death_money_value(amount), relationship_label, dead_name],
				"result_text": "You accept the inheritance. Your bank balance updates immediately."
			},
			{
				"id": "do_not_accept",
				"label": "Don't accept",
				"source_resolves": true,
				"priority": 25,
				"journal_text": "I refused the inheritance from my %s %s." % [relationship_label, dead_name],
				"result_text": "You refuse the inheritance."
			},
			{
				"id": "accept_visit_grave",
				"label": "Accept & visit their grave in gratitude",
				"source_resolves": true,
				"priority": 85,
				"bank_delta": amount,
				"journal_text": "I accepted %s from my %s %s and visited their grave in gratitude." % [_format_death_money_value(amount), relationship_label, dead_name],
				"result_text": "You accept the inheritance and visit their grave in gratitude. Your bank balance updates immediately."
			}
		],
		"urgency": 54.0,
		"decay": 0.0,
		"created_year": int(year),
		"created_at_ms": int(Time.get_ticks_msec()),
		"updated_at_ms": int(Time.get_ticks_msec()),
		"source": "family_inheritance_pending_situation"
	}


func _family_funeral_type_specs() -> Array:
	var class_key: String = str(player.social_class).strip_edges().to_lower() if player != null else ""
	if class_key in ["royal", "noble", "elite", "aristocrat"]:
		return [
			{ "id": "formal_funeral", "label": "Formal funeral", "cost": 5000, "priority": 70},
			{ "id": "grand_funeral", "label": "Grand funeral", "cost": 15000, "priority": 80},
			{ "id": "royal_ceremony", "label": "Royal ceremony", "cost": 50000, "priority": 95}
		]

	return [
		{ "id": "simple_funeral", "label": "Simple funeral", "cost": 750, "priority": 45},
		{ "id": "standard_funeral", "label": "Standard funeral", "cost": 3500, "priority": 60},
		{ "id": "lavish_funeral", "label": "Lavish funeral", "cost": 12000, "priority": 75}
	]


func _family_burial_method_specs() -> Array:
	var era_name: String = str(era.name).strip_edges().to_lower() if era != null else ""

	if era_name.find("ancient") >= 0:
		return [
			{ "id": "earth_burial", "label": "Earth burial", "cost": 100, "priority": 50},
			{ "id": "pyre", "label": "Funeral pyre", "cost": 300, "priority": 55},
			{ "id": "ancestral_mound", "label": "Ancestral mound", "cost": 900, "priority": 70}
		]

	if era_name.find("medieval") >= 0:
		return [
			{ "id": "church_burial", "label": "Church burial", "cost": 500, "priority": 50},
			{ "id": "family_plot", "label": "Family plot", "cost": 1200, "priority": 65},
			{ "id": "stone_tomb", "label": "Stone tomb", "cost": 6000, "priority": 80}
		]

	if era_name.find("future") >= 0:
		return [
			{ "id": "memorial_pod", "label": "Memorial pod", "cost": 2000, "priority": 60},
			{ "id": "biolight_grove", "label": "Biolight grove", "cost": 6500, "priority": 75},
			{ "id": "stellar_archive", "label": "Stellar archive", "cost": 25000, "priority": 90}
		]

	return [
		{ "id": "burial", "label": "Burial", "cost": 1000, "priority": 55},
		{ "id": "cremation", "label": "Cremation", "cost": 750, "priority": 50},
		{ "id": "mausoleum", "label": "Mausoleum", "cost": 10000, "priority": 80}
	]


func _format_death_money_value(amount: int) -> String:
	return "$%d" % max(0, int(amount))


func _unique_positive_ids(values: Array) -> Array:
	var out: Array = []
	for raw_value in values:
		var id_value: int = int(raw_value)
		if id_value > 0 and id_value not in out:
			out.append(id_value)
	return out
func queue_known_person_death_message(dead_person: Person) -> void:
	if dead_person == null or player == null:
		return
	if int(dead_person.id) == int(player.id):
		return
	if _family_death_notice_already_queued(int(dead_person.id)):
		return

	var relationship_label: String = _relationship_label_to_player(dead_person)
	if relationship_label == "":
		return

	var cause: String = str(dead_person.cause_of_death).strip_edges()
	if cause == "":
		cause = "unknown causes"

	var text: String = "My %s %s died from %s at age %d." % [
		relationship_label,
		dead_person.first_name,
		cause,
		int(dead_person.age)
	]

	var inheritance_report: Dictionary = _try_apply_family_inheritance(dead_person, relationship_label)
	var responsible_person: Person = _family_funeral_responsible_person_for_dead(dead_person)
	var death_contract: Dictionary = _build_family_death_funeral_popup(
		text,
		relationship_label,
		str(dead_person.first_name),
		int(dead_person.id),
		inheritance_report,
		responsible_person,
		cause
	)

	var emit_report: Dictionary = _emit_family_death_pending_situation(death_contract, int(player.id))
	if bool(emit_report.get("success", false)):
		_mark_family_death_notice_queued(int(dead_person.id))

func _relationship_label_to_player(person: Person) -> String:
	if person == null or player == null:
		return ""

	if int(person.id) in player.parents:
		return "parent"

	if int(person.id) in player.children:
		return "child"

	if player.partner != null and int(person.id) == int(player.partner.id):
		return "spouse"

	for pid in player.parents:
		var parent: Person = get_npc_by_id(int(pid))
		if parent == null:
			continue
		if int(person.id) in parent.parents:
			return "grandparent"

		for sibling_id in parent.children:
			if int(sibling_id) == int(player.id):
				continue
			if int(person.id) == int(sibling_id):
				return "brother" if str(person.gender).to_lower() == "male" else "sister"

	return ""

func _try_apply_family_inheritance(dead_person: Person, relationship_label: String) -> Dictionary:
	if dead_person == null or player == null:
		return { "success": false}

	if not _family_inheritance_relationship_allows_notice(relationship_label):
		return { "success": false}

	var estate_amount: int = _family_inheritance_estate_amount_from_person(dead_person)
	if estate_amount <= 0:
		return { "success": false}

	var explicit_heirs: Array = _family_inheritance_explicit_heir_ids_from_person(dead_person)
	var beneficiary_ids: Array = explicit_heirs.duplicate()
	var used_explicit_will: bool = not beneficiary_ids.is_empty()

	if beneficiary_ids.is_empty():
		beneficiary_ids = _family_inheritance_default_heir_ids_from_person(dead_person)

	var inheriting_player_id: int = int(player.id)
	var player_included: bool = inheriting_player_id in beneficiary_ids

	if not player_included:
		return {
			"success": true,
			"inherited": false,
			"amount": 0,
			"text": "My %s %s left inheritance behind, but I was not included in the will." % [
				relationship_label,
				dead_person.first_name
			],
			"used_explicit_will": used_explicit_will
		}

	var inheritance_amount: int = _family_inheritance_share_for_player(estate_amount, beneficiary_ids)
	if inheritance_amount <= 0:
		return {
			"success": true,
			"inherited": false,
			"amount": 0,
			"text": "My %s %s left inheritance behind, but there was nothing meaningful left for me to receive." % [
				relationship_label,
				dead_person.first_name
			],
			"used_explicit_will": used_explicit_will
		}

	return {
		"success": true,
		"inherited": true,
		"amount": inheritance_amount,
		"text": "My %s %s left me %s in their will." % [
			relationship_label,
			dead_person.first_name,
			_format_death_money_value(inheritance_amount)
		],
		"used_explicit_will": used_explicit_will,
	}
func _finalize_dormant_death(
	d: Dictionary,
	fallback_id: int
) -> void:
	var npc_id:= int(
		d.get(
			"id",
			fallback_id
		)
	)


	d ["_query_facts"] = (
		_extract_queryable_npc_facts(
			d
		)
	)

	dormant_npcs [
		npc_id
	] = d

	var query_facts: Dictionary = (
		d ["_query_facts"]
		if typeof(
			d.get(
				"_query_facts",
				{}
			)
		) == TYPE_DICTIONARY
		else {}
	)

	if has_method(
		"mark_surviving_spouse_widowed_from_snapshot"
	):
		mark_surviving_spouse_widowed_from_snapshot(
			query_facts,
			npc_id
		)

	if event_bus != null:
		event_bus.emit(
			ActionEventTypes.NPC_DIED,
			_build_dormant_death_payload(
				d,
				npc_id
			)
		)

	_queue_known_person_death_message_from_snapshot(
		d,
		npc_id
	)

	npc_graveyard [
		npc_id
	] = {
		"name": "%s %s" % [
			str(
				d.get(
					"first_name",
					""
				)
			),
			str(
				d.get(
					"last_name",
					""
				)
			)
		],
		"age": int(
			d.get(
				"age",
				0
			)
		),
		"cause": str(
			d.get(
				"cause_of_death",
				"Unknown"
			)
		),
		"fame": int(
			d.get(
				"fame",
				0
			)
		)
	}

	dormant_npcs.erase(
		npc_id
	)
func _queue_known_person_death_message_from_snapshot(d: Dictionary, fallback_id: int) -> void:
	if player == null or typeof(d) != TYPE_DICTIONARY:
		return

	var dead_id: int = int(d.get("id", fallback_id))
	if dead_id <= 0 or dead_id == int(player.id):
		return
	if _family_death_notice_already_queued(dead_id):
		return

	var relationship_label: String = _relationship_label_to_player_from_snapshot(d, dead_id)
	if relationship_label == "":
		return

	var first_name: String = str(d.get("first_name", "Someone")).strip_edges()
	if first_name == "":
		first_name = "Someone"

	var cause: String = str(d.get("cause_of_death", d.get("cause", "Unknown"))).strip_edges()
	if cause == "":
		cause = "Unknown"

	var age_at_death: int = int(d.get("age", 0))
	var message: String = "My %s %s died from %s at age %d." % [
		relationship_label,
		first_name,
		cause,
		age_at_death
	]

	var inheritance_report: Dictionary = _try_apply_family_inheritance_from_snapshot(d, dead_id, relationship_label)
	var responsible_person: Person = _family_funeral_responsible_person_from_snapshot(d, dead_id)
	var death_contract: Dictionary = _build_family_death_funeral_popup(
		message,
		relationship_label,
		first_name,
		dead_id,
		inheritance_report,
		responsible_person,
		cause
	)

	var emit_report: Dictionary = _emit_family_death_pending_situation(death_contract, int(player.id))
	if bool(emit_report.get("success", false)):
		_mark_family_death_notice_queued(dead_id)
func _relationship_label_to_player_from_snapshot(d: Dictionary, dead_id: int) -> String:
	if player == null:
		return ""

	if dead_id in player.parents:
		return "father" if str(d.get("gender", "")).to_lower() == "male" else "mother" if str(d.get("gender", "")).to_lower() == "female" else "parent"

	if dead_id in player.children:
		return "son" if str(d.get("gender", "")).to_lower() == "male" else "daughter" if str(d.get("gender", "")).to_lower() == "female" else "child"

	if player.partner != null and dead_id == int(player.partner.id):
		return "husband" if str(d.get("gender", "")).to_lower() == "male" else "wife" if str(d.get("gender", "")).to_lower() == "female" else "spouse"

	for raw_parent_id in player.parents:
		var parent: Person = get_npc_by_id(int(raw_parent_id))
		if parent == null:
			continue

		if dead_id in parent.parents:
			return "grandfather" if str(d.get("gender", "")).to_lower() == "male" else "grandmother" if str(d.get("gender", "")).to_lower() == "female" else "grandparent"

		if dead_id in parent.children and dead_id != int(player.id):
			return "brother" if str(d.get("gender", "")).to_lower() == "male" else "sister" if str(d.get("gender", "")).to_lower() == "female" else "sibling"

	return ""
func _try_apply_family_inheritance_from_snapshot(d: Dictionary, _dead_id: int, relationship_label: String) -> Dictionary:
	if player == null:
		return { "success": false}

	if not _family_inheritance_relationship_allows_notice(relationship_label):
		return { "success": false}

	var raw_money: float = float(d.get("bank_balance", d.get("money", d.get("cash", 0.0))))
	var estate_amount: int = max(0, int(raw_money * 0.35))
	if estate_amount <= 0:
		return { "success": false}

	var explicit_heirs: Array = _family_inheritance_explicit_heir_ids_from_snapshot(d)
	var beneficiary_ids: Array = explicit_heirs.duplicate()
	var used_explicit_will: bool = not beneficiary_ids.is_empty()

	if beneficiary_ids.is_empty():
		beneficiary_ids = _family_inheritance_default_heir_ids_from_snapshot(d)

	var inheriting_player_id: int = int(player.id)
	var player_included: bool = inheriting_player_id in beneficiary_ids

	var first_name: String = str(d.get("first_name", "Someone")).strip_edges()
	if first_name == "":
		first_name = "Someone"

	if not player_included:
		return {
			"success": true,
			"inherited": false,
			"amount": 0,
			"text": "My %s %s left inheritance behind, but I was not included in the will." % [
				relationship_label,
				first_name
			],
			"used_explicit_will": used_explicit_will
		}

	var inheritance_amount: int = _family_inheritance_share_for_player(estate_amount, beneficiary_ids)
	if inheritance_amount <= 0:
		return {
			"success": true,
			"inherited": false,
			"amount": 0,
			"text": "My %s %s left inheritance behind, but there was nothing meaningful left for me to receive." % [
				relationship_label,
				first_name
			],
			"used_explicit_will": used_explicit_will
		}

	return {
		"success": true,
		"inherited": true,
		"amount": inheritance_amount,
		"text": "My %s %s left me %s in their will." % [
			relationship_label,
			first_name,
			_format_death_money_value(inheritance_amount)
		],
		"used_explicit_will": used_explicit_will,
	}
func _family_inheritance_relationship_allows_notice(relationship_label: String) -> bool:
	var clean_label: String = str(relationship_label).strip_edges().to_lower()
	return clean_label in [
		"grandfather", "grandmother", "grandparent",
		"father", "mother", "parent",
		"husband", "wife", "spouse",
		"brother", "sister", "sibling",
		"son", "daughter", "child"
	]


func _family_inheritance_estate_amount_from_person(dead_person: Person) -> int:
	if dead_person == null:
		return 0

	var raw_bank: float = 0.0
	if "bank_balance" in dead_person:
		raw_bank += max(0.0, float(dead_person.bank_balance))
	if "cash" in dead_person:
		raw_bank += max(0.0, float(dead_person.cash))
	if "money" in dead_person:
		raw_bank += max(0.0, float(dead_person.money))

	return max(0, int(raw_bank * 0.35))


func _family_inheritance_explicit_heir_ids_from_person(dead_person: Person) -> Array:
	var out: Array = []
	if dead_person == null:
		return out

	var raw_lists: Array = []
	for prop_name in ["will_beneficiaries", "explicit_heirs", "inheritance_beneficiaries", "will_heirs"]:
		if prop_name in dead_person:
			var raw_value: Variant = dead_person.get(prop_name)
			if typeof(raw_value) == TYPE_ARRAY:
				raw_lists.append(raw_value)

	if "will" in dead_person:
		var raw_will: Variant = dead_person.get("will")
		if typeof(raw_will) == TYPE_DICTIONARY:
			raw_lists.append(raw_will.get("beneficiaries", []))

	if "inheritance_will" in dead_person:
		var raw_inheritance_will: Variant = dead_person.get("inheritance_will")
		if typeof(raw_inheritance_will) == TYPE_DICTIONARY:
			raw_lists.append(raw_inheritance_will.get("beneficiaries", []))

	for raw_list in raw_lists:
		if typeof(raw_list) != TYPE_ARRAY:
			continue
		for raw_heir in raw_list:
			var heir_id: int = _family_inheritance_heir_id_from_value(raw_heir)
			if heir_id > 0 and heir_id not in out:
				out.append(heir_id)

	return out


func _family_inheritance_explicit_heir_ids_from_snapshot(d: Dictionary) -> Array:
	var out: Array = []
	if typeof(d) != TYPE_DICTIONARY:
		return out

	var raw_lists: Array = []
	for prop_name in ["will_beneficiaries", "explicit_heirs", "inheritance_beneficiaries", "will_heirs"]:
		var raw_value: Variant = d.get(prop_name, [])
		if typeof(raw_value) == TYPE_ARRAY:
			raw_lists.append(raw_value)

	var raw_will: Variant = d.get("will", {})
	if typeof(raw_will) == TYPE_DICTIONARY:
		raw_lists.append(raw_will.get("beneficiaries", []))

	var raw_inheritance_will: Variant = d.get("inheritance_will", {})
	if typeof(raw_inheritance_will) == TYPE_DICTIONARY:
		raw_lists.append(raw_inheritance_will.get("beneficiaries", []))

	for raw_list in raw_lists:
		if typeof(raw_list) != TYPE_ARRAY:
			continue
		for raw_heir in raw_list:
			var heir_id: int = _family_inheritance_heir_id_from_value(raw_heir)
			if heir_id > 0 and heir_id not in out:
				out.append(heir_id)

	return out


func _family_inheritance_heir_id_from_value(raw_heir: Variant) -> int:
	if typeof(raw_heir) == TYPE_INT:
		return int(raw_heir)
	if typeof(raw_heir) == TYPE_FLOAT:
		return int(raw_heir)
	if typeof(raw_heir) == TYPE_DICTIONARY:
		var heir_row: Dictionary = raw_heir
		return int(heir_row.get("person_id", heir_row.get("npc_id", heir_row.get("id", -1))))
	if raw_heir is Person:
		return int(raw_heir.id)
	return -1


func _family_inheritance_default_heir_ids_from_person(dead_person: Person) -> Array:
	var out: Array = []
	if dead_person == null:
		return out

	if dead_person.partner != null and int(dead_person.partner.id) > 0:
		out.append(int(dead_person.partner.id))

	for raw_child_id in dead_person.children:
		var child_id: int = int(raw_child_id)
		if child_id > 0 and child_id not in out:
			out.append(child_id)

	for raw_parent_id in dead_person.parents:
		var parent_id: int = int(raw_parent_id)
		if parent_id > 0 and parent_id not in out:
			out.append(parent_id)

	if out.is_empty() and player != null:
		var relationship_label: String = _relationship_label_to_player(dead_person)
		if _family_inheritance_relationship_allows_notice(relationship_label):
			out.append(int(player.id))

	return out


func _family_inheritance_default_heir_ids_from_snapshot(d: Dictionary) -> Array:
	var out: Array = []
	if typeof(d) != TYPE_DICTIONARY:
		return out

	var partner_id: int = int(d.get("partner_id", -1))
	if partner_id > 0:
		out.append(partner_id)

	var children_raw: Variant = d.get("children", [])
	if typeof(children_raw) == TYPE_ARRAY:
		for raw_child_id in children_raw:
			var child_id: int = int(raw_child_id)
			if child_id > 0 and child_id not in out:
				out.append(child_id)

	var parents_raw: Variant = d.get("parents", [])
	if typeof(parents_raw) == TYPE_ARRAY:
		for raw_parent_id in parents_raw:
			var parent_id: int = int(raw_parent_id)
			if parent_id > 0 and parent_id not in out:
				out.append(parent_id)

	if out.is_empty() and player != null:
		out.append(int(player.id))

	return out


func _family_inheritance_share_for_player(estate_amount: int, beneficiary_ids: Array) -> int:
	if estate_amount <= 0:
		return 0

	var clean_beneficiaries: Array = []
	for raw_id in beneficiary_ids:
		var heir_id: int = int(raw_id)
		if heir_id > 0 and heir_id not in clean_beneficiaries:
			clean_beneficiaries.append(heir_id)

	if clean_beneficiaries.is_empty():
		return 0

	return max(0, int(float(estate_amount) / float(clean_beneficiaries.size())))


func _family_inheritance_credit_player(amount: int, dead_id: int, relationship_label: String) -> void:
	if player == null or amount <= 0:
		return

	if bank_engine != null and bank_engine.has_method("request_actor_bank_action"):
		bank_engine.request_actor_bank_action(player, {
			"action": "credit_cash",
			"amount": amount,
			"currency": "USD",
			"reason": "family_inheritance",
			"dead_person_id": int(dead_id)
		}, {
			"source": "family_inheritance",
			"dead_person_id": int(dead_id),
			"relationship_label": relationship_label
		})
	else:
		player.bank_balance += amount
func simulate_dormant_population(
	budget_override: int = -1,
	prioritized_ids: Array = [],
	delta_mailbox: Array = [],
	session_key: String = ""
) -> Dictionary:
	var active_session_key: String = str(
		session_key
	).strip_edges()

	var target_year: int = int(
		year
	)

	if population_shard_engine != null:
		if active_session_key != "":
			var shard_session_raw: Variant = (
				dormant_runtime_sessions.get(
					active_session_key,
					{}
				)
			)

			var shard_session: Dictionary = (
				shard_session_raw
				if typeof(
					shard_session_raw
				) == TYPE_DICTIONARY
				else {}
			)

			if not bool(
				shard_session.get(
					"shard_tick_done",
					false
				)
			):
				_publish_population_shard_year_tick({
					"source": "simulate_dormant_population",
					"session_key": active_session_key,
					"year": target_year
				})

				shard_session [
					"shard_tick_done"
				] = true

				dormant_runtime_sessions [
					active_session_key
				] = shard_session
		else:
			_publish_population_shard_year_tick({
				"source": "simulate_dormant_population",
				"session_key": "",
				"year": target_year
			})

	if dormant_npcs.is_empty():
		if active_session_key != "":
			dormant_runtime_sessions.erase(
				active_session_key
			)

		return {
			"is_complete": true,
			"processed": 0,
			"remaining": 0,
			"year": target_year
		}

	var dormant_budget:= DORMANT_SIM_BATCH_LIMIT

	if budget_override >= 0:
		dormant_budget = budget_override
	elif year_budget_engine != null:
		dormant_budget = (
			year_budget_engine.get_dormant_batch_limit()
		)

	if dormant_budget <= 0:
		if population_lifecycle_manager != null:
			population_lifecycle_manager.post_dormant_yearly_pass()

		if active_session_key != "":
			dormant_runtime_sessions.erase(
				active_session_key
			)

		return {
			"is_complete": true,
			"processed": 0,
			"remaining": 0,
			"year": target_year
		}

	var ids: Array = []
	var start_index: int = 0

	if active_session_key != "":
		var session_raw: Variant = (
			dormant_runtime_sessions.get(
				active_session_key,
				{}
			)
		)

		var session: Dictionary = (
			session_raw
			if typeof(
				session_raw
			) == TYPE_DICTIONARY
			else {}
		)

		var ordered_raw: Variant = session.get(
			"ids",
			[]
		)

		if (
			typeof(
				ordered_raw
			) == TYPE_ARRAY
			and not ordered_raw.is_empty()
		):
			ids = ordered_raw.duplicate()

			start_index = clamp(
				int(
					session.get(
						"cursor",
						0
					)
				),
				0,
				ids.size()
			)
		else:
			var seen_session: Dictionary = {}

			for prioritized_id in prioritized_ids:
				var pid: int = int(
					prioritized_id
				)

				if pid <= 0:
					continue

				if not dormant_npcs.has(
					pid
				):
					continue

				if seen_session.has(
					pid
				):
					continue

				ids.append(
					pid
				)

				seen_session [
					pid
				] = true

			for npc_id in dormant_npcs.keys():
				var pid: int = int(
					npc_id
				)

				if seen_session.has(
					pid
				):
					continue

				ids.append(
					pid
				)

				seen_session [
					pid
				] = true

			session [
				"ids"
			] = ids.duplicate()

			session [
				"cursor"
			] = 0

			session [
				"shard_tick_done"
			] = bool(
				session.get(
					"shard_tick_done",
					false
				)
			)

			session [
				"target_year"
			] = target_year

			dormant_runtime_sessions [
				active_session_key
			] = session
	else:
		var seen: Dictionary = {}

		for prioritized_id in prioritized_ids:
			var pid: int = int(
				prioritized_id
			)

			if pid <= 0:
				continue

			if not dormant_npcs.has(
				pid
			):
				continue

			if seen.has(
				pid
			):
				continue

			ids.append(
				pid
			)

			seen [
				pid
			] = true

		for npc_id in dormant_npcs.keys():
			var pid: int = int(
				npc_id
			)

			if seen.has(
				pid
			):
				continue

			ids.append(
				pid
			)

			seen [
				pid
			] = true

	var processed: int = 0
	var already_committed: int = 0
	var age_commits: int = 0
	var cursor: int = start_index

	while (
		cursor < ids.size()
		and processed < dormant_budget
	):
		var id: int = int(
			ids [cursor]
		)

		cursor += 1

		if not dormant_npcs.has(
			id
		):
			continue

		var d = dormant_npcs [id]

		if typeof(d) != TYPE_DICTIONARY:
			continue

		if not bool(
			d.get(
				"alive",
				true
			)
		):
			continue

		processed += 1




		var completed_year: int = int(
			d.get(
				"last_dormant_yearly_simulation_year",
				-999999
			)
		)

		if completed_year == target_year:
			already_committed += 1
			continue

		var was_alive: bool = bool(
			d.get(
				"alive",
				true
			)
		)

		var before_city: String = str(
			d.get(
				"home_city",
				""
			)
		)

		var before_country: String = str(
			d.get(
				"home_country",
				""
			)
		)

		var before_job: String = str(
			d.get(
				"job",
				""
			)
		)

		var before_bank: float = float(
			d.get(
				"bank_balance",
				0.0
			)
		)

		var temporal_year: int = int(
			d.get(
				"last_temporal_biology_year",
				target_year - 1
			)
		)

		if temporal_year < target_year:
			d ["age"] = int(
				d.get(
					"age",
					0
				)
			) + 1

			d [
				"last_temporal_biology_year"
			] = target_year

			d [
				"last_world_engine_biology_year"
			] = target_year

			age_commits += 1

		var age_now: int = int(
			d.get(
				"age",
				0
			)
		)

		var health_cap: float = 200.0
		var health_scale: float = (
			health_cap / 100.0
		)

		var health_now: float = float(
			d.get(
				"health",
				health_cap * 0.5
			)
		)

		var mental_now: float = float(
			d.get(
				"mental_health",
				100.0
			)
		)

		var dormant_age_cap: int = (
			_dormant_era_mortal_age_cap_for_snapshot(
				d
			)
		)

		var dormant_decline_start: int = max(
			28,
			dormant_age_cap - 26
		)

		var dormant_old_age_pressure: float = 0.0

		if age_now >= dormant_decline_start:
			dormant_old_age_pressure = clamp(
				float(
					age_now
					- dormant_decline_start
				) / max(
					1.0,
					float(
						dormant_age_cap
						- dormant_decline_start
					)
				),
				0.0,
				1.35
			)

		if (
			age_now >= dormant_age_cap
			and not (
				"Immortal"
				in d.get(
					"traits",
					[]
				)
			)
		):
			d ["alive"] = false
			d ["health"] = 0
			d ["cause_of_death"] = "Old age"

		if bool(
			d.get(
				"alive",
				true
			)
		):
			if age_now >= dormant_decline_start:
				health_now -= (
					randf_range(
						0.4,
						2.2
					)
					* health_scale
					* max(
						0.25,
						dormant_old_age_pressure
					)
				)

			if age_now >= dormant_age_cap - 10:
				health_now -= (
					randf_range(
						0.8,
						3.4
					)
					* health_scale
					* max(
						0.45,
						dormant_old_age_pressure
					)
				)

			mental_now = clamp(
				mental_now
				+ randf_range(
					-2.0,
					1.0
				),
				0.0,
				100.0
			)

			health_now = clamp(
				health_now,
				0.0,
				health_cap
			)

			d ["health"] = health_now
			d ["mental_health"] = mental_now

		if (
			health_now <= 0.0
			and not (
				"Immortal"
				in d.get(
					"traits",
					[]
				)
			)
		):
			d ["alive"] = false
			d ["cause_of_death"] = "Natural causes"

		if (
			bool(
				d.get(
					"alive",
					true
				)
			)
			and age_now >= 16
		):
			if (
				str(
					d.get(
						"job",
						""
					)
				) == ""
				and randi() % 100 < 20
			):
				var jobs = (
					era_engine.get_job_pool()
				)

				if jobs.size() > 0:
					d ["job"] = jobs [
						randi() % jobs.size()
					]

					d ["income"] = randf_range(
						18000,
						55000
					)
			elif randi() % 100 < 35:
				d ["income"] = max(
					0.0,
					float(
						d.get(
							"income",
							0.0
						)
					) + randf_range(
						-1500.0,
						3500.0
					)
				)

		if bool(
			d.get(
				"alive",
				true
			)
		):
			var income: float = float(
				d.get(
					"income",
					0.0
				)
			)

			var bank: float = float(
				d.get(
					"bank_balance",
					0.0
				)
			)

			bank += income * randf_range(
				0.15,
				0.55
			)

			d ["bank_balance"] = max(
				bank,
				0.0
			)

		if (
			bool(
				d.get(
					"alive",
					true
				)
			)
			and randi() % 100 < 4
		):
			var locs = (
				era_engine.get_birth_locations()
			)

			if locs.size() > 0:
				var place = locs [
					randi() % locs.size()
				]

				d ["home_city"] = place ["city"]
				d ["home_country"] = place ["country"]

		if (
			was_alive
			and not bool(
				d.get(
					"alive",
					true
				)
			)
		):
			delta_mailbox.append({
				"type": "dormant_death",
				"npc_id": int(
					d.get(
						"id",
						id
					)
				),
				"name": (
					"%s %s"
					% [
						str(
							d.get(
								"first_name",
								""
							)
						),
						str(
							d.get(
								"last_name",
								""
							)
						)
					]
				).strip_edges()
			})

		var after_city: String = str(
			d.get(
				"home_city",
				""
			)
		)

		var after_country: String = str(
			d.get(
				"home_country",
				""
			)
		)

		if (
			before_city != after_city
			or before_country != after_country
		):
			delta_mailbox.append({
				"type": "dormant_moved",
				"npc_id": int(
					d.get(
						"id",
						id
					)
				),
				"from_city": before_city,
				"to_city": after_city,
				"from_country": before_country,
				"to_country": after_country
			})

		var after_job: String = str(
			d.get(
				"job",
				""
			)
		)

		if before_job != after_job:
			delta_mailbox.append({
				"type": "dormant_job_changed",
				"npc_id": int(
					d.get(
						"id",
						id
					)
				),
				"from": before_job,
				"to": after_job
			})

		var after_bank: float = float(
			d.get(
				"bank_balance",
				0.0
			)
		)

		if abs(
			after_bank - before_bank
		) >= 5000.0:
			delta_mailbox.append({
				"type": "dormant_bank_shift",
				"npc_id": int(
					d.get(
						"id",
						id
					)
				),
				"from": before_bank,
				"to": after_bank
			})

		d [
			"last_dormant_yearly_simulation_year"
		] = target_year

		d [
			"last_dormant_yearly_simulation_completed_at_ms"
		] = int(
			Time.get_ticks_msec()
		)

		if not bool(
			d.get(
				"alive",
				true
			)
		):
			_finalize_dormant_death(
				d,
				int(id)
			)
		else:
			d ["_query_facts"] = (
				_extract_queryable_npc_facts(
					d
				)
			)

			dormant_npcs [
				int(
					d.get(
						"id",
						id
					)
				)
			] = d

	var is_complete: bool = (
		cursor >= ids.size()
	)

	var progress: float = (
		float(cursor)
		/ float(
			maxi(
				1,
				ids.size()
			)
		)
	)

	if active_session_key == "":
		if population_lifecycle_manager != null:
			population_lifecycle_manager.post_dormant_yearly_pass()

		return {
			"is_complete": true,
			"processed": processed,
			"already_committed": already_committed,
			"age_commits": age_commits,
			"remaining": max(
				0,
				ids.size() - cursor
			),
			"progress": 1.0,
			"year": target_year
		}

	if is_complete:
		dormant_runtime_sessions.erase(
			active_session_key
		)

		if population_lifecycle_manager != null:
			population_lifecycle_manager.post_dormant_yearly_pass()
	else:
		var update_session_raw: Variant = (
			dormant_runtime_sessions.get(
				active_session_key,
				{}
			)
		)

		var update_session: Dictionary = (
			update_session_raw
			if typeof(
				update_session_raw
			) == TYPE_DICTIONARY
			else {}
		)

		update_session [
			"ids"
		] = ids.duplicate()

		update_session [
			"cursor"
		] = cursor

		update_session [
			"shard_tick_done"
		] = bool(
			update_session.get(
				"shard_tick_done",
				false
			)
		)

		update_session [
			"target_year"
		] = target_year

		dormant_runtime_sessions [
			active_session_key
		] = update_session

	return {
		"is_complete": is_complete,
		"processed": processed,
		"already_committed": already_committed,
		"age_commits": age_commits,
		"remaining": max(
			0,
			ids.size() - cursor
		),
		"progress": clampf(
			progress,
			0.0,
			1.0
		),
		"year": target_year,
		"bounded_runtime": true,
		"idle_required": false
	}
func _dormant_era_mortal_age_cap_for_snapshot(d: Dictionary) -> int:
	var era_name: String = "Modern Era"
	if era != null:
		if typeof(era) == TYPE_DICTIONARY:
			era_name = str((era as Dictionary).get("name", "Modern Era"))
		elif "name" in era:
			era_name = str(era.name)

	var min_cap: int = 76
	var max_cap: int = MAX_MORTAL_AGE

	match era_name:
		"Ancient Era":
			min_cap = 48
			max_cap = 72
		"Medieval Era":
			min_cap = 52
			max_cap = 78
		"Industrial Era":
			min_cap = 62
			max_cap = 92
		"Modern Era":
			min_cap = 76
			max_cap = 108
		"Future Era":
			min_cap = 92
			max_cap = max(118, MAX_MORTAL_AGE)

	if max_cap < min_cap:
		var swap_value: int = min_cap
		min_cap = max_cap
		max_cap = swap_value

	var snapshot_id: int = int(d.get("id", 0))
	var span: int = max(1, max_cap - min_cap + 1)
	var stable_offset: int = abs((snapshot_id * 1103515245) + 12345) % span

	return min_cap + stable_offset
func _publish_population_shard_year_tick(context: Dictionary = {}) -> void:
	if population_shard_engine == null:
		return

	var payload: Dictionary = context.duplicate(true)
	payload ["type"] = "population.year.tick"
	payload ["year"] = int(payload.get("year", year))
	payload ["source"] = str(payload.get("source", "game_state"))
	payload ["shard_keys"] = population_shard_engine.population_shards.keys()
	payload ["qos_tier"] = "ambient"
	payload ["fanout_hints"] = {
		"skip_agent_memory_propagation": true,
		"skip_npc_memory_web": true,
		"skip_llm_bridge": true,
		"skip_reputation": true,
		"force_defer_bus": true
	}

	if event_bus != null and event_bus.has_method("publish"):
		event_bus.publish(payload)
		return

	if event_bus != null and event_bus.has_method("emit"):
		var event_payload: Dictionary = payload.duplicate(true)
		event_payload.erase("type")
		event_bus.emit("population.year.tick", event_payload)
		return

	population_shard_engine.yearly_tick(payload)
func _build_active_npc_facts(npc: Person) -> Dictionary:
	if npc == null:
		return {}

	return {
		"id": npc.id,
		"name": npc.first_name + " " + npc.last_name,
		"first_name": npc.first_name,
		"last_name": npc.last_name,
		"age": npc.age,
		"alive": npc.alive,
		"gender": npc.gender,
		"fame": npc.fame,
		"fame_tier": npc.fame_tier,
		"social_class": npc.social_class,
		"realm_id": npc.realm_id,


		"settlement_id": npc.settlement_id,
		"district_id": npc.district_id,
		"locality_id": npc.locality_id,
		"origin_settlement_id": npc.origin_settlement_id,
		"origin_district_id": npc.origin_district_id,
		"origin_locality_id": npc.origin_locality_id,
		"birthplace_settlement_id": npc.birthplace_settlement_id,

		"parents": npc.parents.duplicate(),
		"children": npc.children.duplicate(),
		"friends": npc.friends.duplicate(),
		"partner_id": npc.partner.id if npc.partner != null else -1,
		"is_ruler": npc.is_ruler,
		"is_royal": npc.is_royal,
		"dynasty_prestige": npc.dynasty_prestige,
		"cause_of_death": npc.cause_of_death,
		"home_city": npc.home_city,
		"home_country": npc.home_country,
		"birth_city": npc.birth_city,
		"birth_country": npc.birth_country,


		"migration_history": npc.migration_history.duplicate(true),
		"diaspora_tags": npc.diaspora_tags.duplicate(),
		"identity_residue": npc.identity_residue.duplicate(true),
		"place_identity_tags": npc.place_identity_tags.duplicate(),
		"locality_faction_affinities": npc.locality_faction_affinities.duplicate(true),
		"years_in_current_place": int(npc.years_in_current_place),
		"total_place_moves": int(npc.total_place_moves),
		"last_place_shift_year": int(npc.last_place_shift_year),
		"place_echo_stack": npc.place_echo_stack.duplicate(true),
		"place_influence_profile": npc.place_influence_profile.duplicate(true),
		"place_conflict_profile": npc.place_conflict_profile.duplicate(true),
		"place_trait_drift_profile": npc.place_trait_drift_profile.duplicate(true),
		"place_influence_strength": float(npc.place_influence_strength),
		"place_identity_summary": npc.place_identity_summary.duplicate(true),
		"place_yearly_snapshots": npc.place_yearly_snapshots.duplicate(true),
		"place_adaptation_flags": npc.place_adaptation_flags.duplicate(),
		"traits": npc.traits.duplicate(),
		"bending_type": npc.bending_type,
		"bending_nation": npc.bending_nation,
		"marital_status": npc.marital_status,
		"vampire_profile": npc.vampire_profile.duplicate(true),
		"source_state": "active"
	}


func _extract_queryable_npc_facts(d: Dictionary) -> Dictionary:
	if typeof(d) != TYPE_DICTIONARY:
		return {}

	return {
		"id": int(d.get("id", -1)),
		"name": str(d.get("first_name", "")) + " " + str(d.get("last_name", "")),
		"first_name": str(d.get("first_name", "")),
		"last_name": str(d.get("last_name", "")),
		"age": int(d.get("age", 0)),
		"alive": bool(d.get("alive", true)),
		"gender": str(d.get("gender", "")),
		"fame": int(d.get("fame", 0)),
		"fame_tier": str(d.get("fame_tier", "None")),
		"social_class": str(d.get("social_class", "Commoner")),
		"realm_id": int(d.get("realm_id", -1)),


		"settlement_id": str(d.get("settlement_id", "")),
		"district_id": str(d.get("district_id", "")),
		"locality_id": str(d.get("locality_id", "")),
		"origin_settlement_id": str(d.get("origin_settlement_id", "")),
		"origin_district_id": str(d.get("origin_district_id", "")),
		"origin_locality_id": str(d.get("origin_locality_id", "")),
		"birthplace_settlement_id": str(d.get("birthplace_settlement_id", "")),

		"parents": d.get("parents", []).duplicate(),
		"children": d.get("children", []).duplicate(),
		"friends": d.get("friends", []).duplicate(),
		"partner_id": int(d.get("partner_id", -1)),
		"is_ruler": bool(d.get("is_ruler", false)),
		"is_royal": bool(d.get("is_royal", false)),
		"dynasty_prestige": int(d.get("dynasty_prestige", 0)),
		"cause_of_death": str(d.get("cause_of_death", "")),
		"home_city": str(d.get("home_city", "")),
		"home_country": str(d.get("home_country", "")),
		"birth_city": str(d.get("birth_city", "")),
		"birth_country": str(d.get("birth_country", "")),


		"migration_history": d.get("migration_history", []).duplicate(true),
		"diaspora_tags": d.get("diaspora_tags", []).duplicate(),
		"identity_residue": d.get("identity_residue", {}).duplicate(true),
		"place_identity_tags": d.get("place_identity_tags", []).duplicate(),
		"locality_faction_affinities": d.get("locality_faction_affinities", {}).duplicate(true),
		"years_in_current_place": int(d.get("years_in_current_place", 0)),
		"total_place_moves": int(d.get("total_place_moves", 0)),
		"last_place_shift_year": int(d.get("last_place_shift_year", -999999)),
		"place_echo_stack": d.get("place_echo_stack", []).duplicate(true),
		"place_influence_profile": d.get("place_influence_profile", {}).duplicate(true),
		"place_conflict_profile": d.get("place_conflict_profile", {}).duplicate(true),
		"place_trait_drift_profile": d.get("place_trait_drift_profile", {}).duplicate(true),
		"place_influence_strength": float(d.get("place_influence_strength", 0.0)),
		"place_identity_summary": d.get("place_identity_summary", {}).duplicate(true),
		"place_yearly_snapshots": d.get("place_yearly_snapshots", []).duplicate(true),
		"place_adaptation_flags": d.get("place_adaptation_flags", []).duplicate(),
	}


func get_npc_facts_by_id(id: int) -> Dictionary:
	var active = get_npc_by_id(id)
	if active != null:
		return _build_active_npc_facts(active)

	if dormant_npcs.has(id):
		var snap = dormant_npcs [id]
		if typeof(snap) == TYPE_DICTIONARY:
			if snap.has("_query_facts") and typeof(snap ["_query_facts"]) == TYPE_DICTIONARY:
				var cached = snap ["_query_facts"].duplicate(true)
				cached ["source_state"] = "dormant"
				return cached
			return _extract_queryable_npc_facts(snap)

	if population_shard_engine != null:
		var lineage = population_shard_engine.get_lineage_facts(id)
		if lineage != {}:
			return lineage

	if npc_graveyard.has(id):
		var g = npc_graveyard [id]
		return {
			"id": id,
			"name": str(g.get("name", "Unknown")),
			"first_name": str(g.get("name", "Unknown")).split(" ") [0] if str(g.get("name", "")).find(" ") != -1 else str(g.get("name", "Unknown")),
			"last_name": str(g.get("name", "")).substr(str(g.get("name", "")).find(" ") + 1) if str(g.get("name", "")).find(" ") != -1 else "",
			"age": int(g.get("age", 0)),
			"alive": false,
			"gender": "",
			"fame": int(g.get("fame", 0)),
			"fame_tier": "None",
			"social_class": "",
			"realm_id": -1,
			"parents": [],
			"children": [],
			"friends": [],
			"partner_id": -1,
			"is_ruler": false,
			"is_royal": false,
			"dynasty_prestige": 0,
			"cause_of_death": str(g.get("cause", "Unknown")),
			"home_city": "",
			"home_country": "",
			"birth_city": "",
			"birth_country": "",
			"traits": [],
			"marital_status": "Unknown",
			"source_state": "graveyard"
		}

	return {}


func get_npc_field_by_id(id: int, field: String, default_value = null):
	var facts = get_npc_facts_by_id(id)
	if facts == {}:
		return default_value
	return facts.get(field, default_value)


func get_relationship_label_between(observer: Person, target: Person) -> String:
	if observer == null or target == null:
		return "Stranger"

	var p: Person = observer
	var my_facts: Dictionary = get_npc_facts_by_id(int(p.id))
	var target_facts: Dictionary = get_npc_facts_by_id(int(target.id))
	if my_facts == {} or target_facts == {}:
		return "Stranger"

	var my_parent_ids: Array = my_facts.get("parents", [])
	var my_child_ids: Array = my_facts.get("children", [])
	var my_partner_id: int = int(my_facts.get("partner_id", -1))
	var target_parent_ids: Array = target_facts.get("parents", [])
	var sibling_ids: Array = []

	if my_parent_ids.size() > 0:
		sibling_ids = get_npc_field_by_id(int(my_parent_ids [0]), "children", [])

	if my_parent_ids.size() > 0 and int(my_parent_ids [0]) == int(target.id):
		return "Father"
	if my_parent_ids.size() > 1 and int(my_parent_ids [1]) == int(target.id):
		return "Mother"

	if int(my_partner_id) == int(target.id):
		match str(p.marital_status):
			"Married":
				return "Husband" if str(target.gender) == "Male" else "Wife"
			"Engaged":
				return "Fiancé" if str(target.gender) == "Male" else "Fiancée"
			"Dating":
				return "Boyfriend" if str(target.gender) == "Male" else "Girlfriend"
			_:
				return "Partner"

	if int(target.id) in my_child_ids:
		return "Son" if str(target.gender) == "Male" else "Daughter"

	if my_parent_ids.size() > 0 and target_parent_ids == my_parent_ids and int(target.id) != int(p.id):
		return "Brother" if str(target.gender) == "Male" else "Sister"


	if my_partner_id > 0:
		var partner_facts: Dictionary = get_npc_facts_by_id(my_partner_id)
		var partner_parents: Array = partner_facts.get("parents", [])
		if int(target.id) in partner_parents:
			return "Father-in-Law" if str(target.gender) == "Male" else "Mother-in-Law"


	if my_partner_id > 0:
		var partner_facts_2: Dictionary = get_npc_facts_by_id(my_partner_id)
		var partner_parent_ids: Array = partner_facts_2.get("parents", [])
		if not partner_parent_ids.is_empty() and target_parent_ids == partner_parent_ids and int(target.id) != my_partner_id:
			return "Brother-in-Law" if str(target.gender) == "Male" else "Sister-in-Law"


	for sibling_id in sibling_ids:
		var sid: int = int(sibling_id)
		if sid <= 0 or sid == int(p.id):
			continue
		var sibling_facts: Dictionary = get_npc_facts_by_id(sid)
		if sibling_facts == {}:
			continue
		if int(sibling_facts.get("partner_id", -1)) == int(target.id):
			return "Brother-in-Law" if str(target.gender) == "Male" else "Sister-in-Law"


	if my_partner_id > 0:
		var partner_facts_3: Dictionary = get_npc_facts_by_id(my_partner_id)
		var partner_parents_2: Array = partner_facts_3.get("parents", [])
		for ppid in partner_parents_2:
			var spouse_parent_facts: Dictionary = get_npc_facts_by_id(int(ppid))
			if spouse_parent_facts == {}:
				continue
			var spouse_gp_ids: Array = spouse_parent_facts.get("parents", [])
			if int(target.id) in spouse_gp_ids:
				return "Grandfather-in-Law" if str(target.gender) == "Male" else "Grandmother-in-Law"

			for spgpid in spouse_gp_ids:
				var spouse_gp_facts: Dictionary = get_npc_facts_by_id(int(spgpid))
				if spouse_gp_facts == {}:
					continue
				var spouse_ggp_ids: Array = spouse_gp_facts.get("parents", [])
				if int(target.id) in spouse_ggp_ids:
					return "Great Grandfather-in-Law" if str(target.gender) == "Male" else "Great Grandmother-in-Law"


	if p.parents.size() > 1:
		var mother: Person = get_or_reactivate_npc_by_id(int(p.parents [1]))
		if mother != null and mother.parents.size() > 0:
			if int(mother.parents [0]) == int(target.id):
				return "Maternal Grandfather"
		if mother != null and mother.parents.size() > 1:
			if int(mother.parents [1]) == int(target.id):
				return "Maternal Grandmother"


	if p.parents.size() > 0:
		var father: Person = get_or_reactivate_npc_by_id(int(p.parents [0]))
		if father != null and father.parents.size() > 0:
			if int(father.parents [0]) == int(target.id):
				return "Paternal Grandfather"
		if father != null and father.parents.size() > 1:
			if int(father.parents [1]) == int(target.id):
				return "Paternal Grandmother"


	if p.parents.size() > 1:
		var mother2: Person = get_or_reactivate_npc_by_id(int(p.parents [1]))
		if mother2 != null and mother2.parents.size() > 0:
			var maternal_gf: Person = get_or_reactivate_npc_by_id(int(mother2.parents [0]))
			var maternal_gm: Person = null
			if mother2.parents.size() > 1:
				maternal_gm = get_or_reactivate_npc_by_id(int(mother2.parents [1]))

			if maternal_gf != null and maternal_gf.parents.size() > 0:
				if int(maternal_gf.parents [0]) == int(target.id) or (maternal_gf.parents.size() > 1 and int(maternal_gf.parents [1]) == int(target.id)):
					return "Maternal Great Grandfather" if str(target.gender) == "Male" else "Maternal Great Grandmother"

			if maternal_gm != null and maternal_gm.parents.size() > 0:
				if int(maternal_gm.parents [0]) == int(target.id) or (maternal_gm.parents.size() > 1 and int(maternal_gm.parents [1]) == int(target.id)):
					return "Maternal Great Grandfather" if str(target.gender) == "Male" else "Maternal Great Grandmother"


	if p.parents.size() > 0:
		var father2: Person = get_or_reactivate_npc_by_id(int(p.parents [0]))
		if father2 != null and father2.parents.size() > 0:
			var paternal_gf: Person = get_or_reactivate_npc_by_id(int(father2.parents [0]))
			var paternal_gm: Person = null
			if father2.parents.size() > 1:
				paternal_gm = get_or_reactivate_npc_by_id(int(father2.parents [1]))

			if paternal_gf != null and paternal_gf.parents.size() > 0:
				if int(paternal_gf.parents [0]) == int(target.id) or (paternal_gf.parents.size() > 1 and int(paternal_gf.parents [1]) == int(target.id)):
					return "Paternal Great Grandfather" if str(target.gender) == "Male" else "Paternal Great Grandmother"

			if paternal_gm != null and paternal_gm.parents.size() > 0:
				if int(paternal_gm.parents [0]) == int(target.id) or (paternal_gm.parents.size() > 1 and int(paternal_gm.parents [1]) == int(target.id)):
					return "Paternal Great Grandfather" if str(target.gender) == "Male" else "Paternal Great Grandmother"

	if p.partner != null and int(p.partner.id) == int(target.id):
		match str(p.marital_status):
			"Married":
				return "Husband" if str(target.gender) == "Male" else "Wife"
			"Engaged":
				return "Fiancé" if str(target.gender) == "Male" else "Fiancée"
			"Dating":
				return "Boyfriend" if str(target.gender) == "Male" else "Girlfriend"
			_:
				return "Partner"

	for cid in p.children:
		if int(cid) == int(target.id):
			return "Child"

	for fid in p.friends:
		if int(fid) == int(target.id):
			return "Friend"

	for xid in p.ex_partners:
		if int(xid) == int(target.id):
			return "Ex"

	if school_engine != null:
		school_engine.sync_person_school_fields(p)

		for c in school_engine.get_classmates(p):
			if c != null and int(c.id) == int(target.id):
				return "Classmate"

		for t in school_engine.get_teachers_for(p):
			if t != null and int(t.id) == int(target.id):
				return "Teacher"

	return "Stranger"


func get_target_reference_for_observer(observer: Person, target: Person) -> String:
	if target == null:
		return "them"

	var relation_label:= get_relationship_label_between(observer, target)
	if relation_label == "" or relation_label == "Stranger":
		if str(target.last_name).strip_edges() != "":
			return "%s %s" % [target.first_name, target.last_name]
		return target.first_name

	return "my %s %s" % [relation_label, target.first_name]


func is_npc_alive_anywhere(id: int) -> bool:
	return bool(get_npc_field_by_id(id, "alive", false))


func get_living_person_ids_from_ids(ids: Array) -> Array:
	var out:= []
	var seen:= {}

	for raw_id in ids:
		var id = int(raw_id)

		if id <= 0:
			continue
		if seen.has(id):
			continue

		seen [id] = true

		var facts = get_npc_facts_by_id(id)
		if facts == {}:
			continue
		if not bool(facts.get("alive", false)):
			continue

		out.append(id)

	return out


func get_random_living_person_from_ids(ids: Array) -> Person:
	var living_ids = get_living_person_ids_from_ids(ids)

	if living_ids.is_empty():
		return null

	var heir_id = int(living_ids [randi() % living_ids.size()])
	return get_or_reactivate_npc_by_id(heir_id)


func collect_family_ids_anywhere(root_id: int) -> Array:
	var result:= []
	var visited:= {}
	_collect_family_ids_anywhere(root_id, result, visited)
	return result

func _collect_family_ids_anywhere(id: int, result: Array, visited: Dictionary) -> void:
	if id <= 0:
		return
	if visited.has(id):
		return

	visited [id] = true

	var facts: Dictionary = get_npc_facts_by_id(id)
	if facts == {}:
		return

	result.append(id)

	var partner_id: int = int(facts.get("partner_id", -1))
	if partner_id > 0:
		_collect_family_ids_anywhere(partner_id, result, visited)

	for parent_id in facts.get("parents", []):
		var pid: int = int(parent_id)
		_collect_family_ids_anywhere(pid, result, visited)

		var parent_facts: Dictionary = get_npc_facts_by_id(pid)
		if parent_facts != {}:
			for sibling_id in parent_facts.get("children", []):
				var sid: int = int(sibling_id)
				if sid <= 0 or sid == id:
					continue
				_collect_family_ids_anywhere(sid, result, visited)

	for child_id in facts.get("children", []):
		_collect_family_ids_anywhere(int(child_id), result, visited)
func should_skip_manual_player_inheritance(dead_id: int) -> bool:
	if dead_id <= 0:
		return false
	if not afterlife_active:
		return false
	if int(afterlife_state.get("ghost_player_id", -1)) != dead_id:
		return false
	return bool(afterlife_state.get("manual_player_inheritance_authority", false))
func register_controlled_character(npc_id: int) -> void:
	npc_id = int(npc_id)
	if npc_id <= 0:
		return
	if npc_id not in controlled_lineage_ids:
		controlled_lineage_ids.append(npc_id)

func preserve_released_controlled_actor_residency(
	actor: Person
) -> void:
	if actor == null:
		return

	var actor_id: int = int(
		actor.id
	)

	if actor_id <= 0:
		return





	register_controlled_character(
		actor_id
	)
	_remember_npc_in_index(
		actor
	)

func _rewind_dir_path() -> String:
	return "user://rewind_cache"
func _ensure_rewind_dir() -> void:
	var root:= DirAccess.open("user://")
	if root != null and not root.dir_exists("rewind_cache"):
		root.make_dir("rewind_cache")

func reset_rewind_support_for_new_life() -> void:
	for path_value in rewind_snapshot_paths:
		var rewind_path: String = str(path_value)
		if FileAccess.file_exists(rewind_path):
			DirAccess.remove_absolute(rewind_path)
	rewind_snapshot_paths.clear()
	rewind_uses_remaining = REWIND_LIMIT

func capture_rewind_snapshot() -> void:
	if player == null:
		return
	if afterlife_active:
		return
	if rewind_uses_remaining <= 0:
		return
	_ensure_rewind_dir()
	var rewind_path: String = "%s/rewind_%d_%d.bin" % [
		_rewind_dir_path(),
		int(player.id),
		int(year)
	]
	if rewind_snapshot_paths.size() > 0 and str(rewind_snapshot_paths.back()) \
== rewind_path:
		return
	if typeof(scenario_state) != TYPE_DICTIONARY:
		scenario_state = {}
	scenario_state ["rewind_snapshot_pipeline"] = {
		"active": true,
		"stage": "delay",
		"delay_frames": 2,
		"path": rewind_path,
		"options": {
			"skip_memory_compaction": true,
			"skip_world_feed_normalization": true,
			"skip_prune": true,
			"skip_archive": true
		},
		"_collect_stage": "prep_memory_compaction",
		"_collect_memory_ids": [],
		"_collect_memory_idx": 0,
		"_collect_memory_batch": 8,
		"_collect_world_feed_idx": 0,
		"_collect_world_feed_batch": 48,
		"_collect_section_idx": 0,
		"_collect_section_count": 5,
		"_collect_serializable_scenario_state": {},
		"_write_session": {},
		"_write_chunk_size": 131072,
		"_write_bytes": PackedByteArray(),
		"_write_file_chunk_size": 131072,
		"_write_file_offset": 0,
		"_write_file_started": false,
		"_chunk_out": {},
		"_chunk_npc_idx": 0,
		"_chunk_npc_batch": 20
	}

func has_pending_rewind_snapshot_pipeline() -> bool:
	if typeof(scenario_state) != TYPE_DICTIONARY:
		return false
	var raw_bucket: Variant = scenario_state.get("rewind_snapshot_pipeline", {})
	var bucket: Dictionary = raw_bucket if typeof(raw_bucket) == TYPE_DICTIONARY else {}
	return bool(bucket.get("active", false))


func step_rewind_snapshot_pipeline(max_steps: int = 1) -> bool:
	if typeof(scenario_state) != TYPE_DICTIONARY:
		scenario_state = {}
	var raw_bucket: Variant = scenario_state.get("rewind_snapshot_pipeline", {})
	var bucket: Dictionary = raw_bucket if typeof(raw_bucket) == TYPE_DICTIONARY else {}
	if bucket.is_empty() or not bool(bucket.get("active", false)):
		return true

	var remaining_steps: int = max(1, max_steps)
	while remaining_steps > 0 and bool(bucket.get("active", false)):
		remaining_steps -= 1
		var stage: String = str(bucket.get("stage", ""))

		match stage:
			"delay":
				var delay_frames: int = int(bucket.get("delay_frames", 0))
				if delay_frames > 0:
					bucket ["delay_frames"] = delay_frames - 1
				else:
					bucket ["stage"] = "save_collect"

			"save_collect":
				var rewind_path: String = str(bucket.get("path", "")).strip_edges()
				if rewind_path == "":
					bucket = {}
					scenario_state ["rewind_snapshot_pipeline"] = bucket
					return true

				var options_raw: Variant = bucket.get("options", {})
				var options: Dictionary = options_raw if typeof(options_raw) == TYPE_DICTIONARY else {}
				var collect_stage: String = str(bucket.get("_collect_stage", "prep_memory_compaction"))

				match collect_stage:
					"prep_memory_compaction":
						if not bool(options.get("skip_memory_compaction", false)):
							var memory_ids_raw: Variant = bucket.get("_collect_memory_ids", [])
							var memory_ids: Array = memory_ids_raw if typeof(memory_ids_raw) == TYPE_ARRAY else []
							if memory_ids.is_empty():
								memory_ids = memories.keys()
								bucket ["_collect_memory_ids"] = memory_ids
								bucket ["_collect_memory_idx"] = 0

							var memory_idx: int = int(bucket.get("_collect_memory_idx", 0))
							var memory_batch: int = int(bucket.get("_collect_memory_batch", 8))
							var memory_end: int = min(memory_idx + memory_batch, memory_ids.size())

							while memory_idx < memory_end:
								_compress_person_memories(int(memory_ids [memory_idx]))
								memory_idx += 1

							bucket ["_collect_memory_idx"] = memory_idx
							if memory_idx < memory_ids.size():
								continue

							bucket.erase("_collect_memory_ids")
							bucket.erase("_collect_memory_idx")

						bucket ["_collect_stage"] = "prep_world_feed_normalization"

					"prep_world_feed_normalization":
						if not bool(options.get("skip_world_feed_normalization", false)):
							var world_feed_idx: int = int(bucket.get("_collect_world_feed_idx", 0))
							var world_feed_batch: int = int(bucket.get("_collect_world_feed_batch", 48))
							var world_feed_end: int = min(world_feed_idx + world_feed_batch, world_feed.size())

							while world_feed_idx < world_feed_end:
								world_feed [world_feed_idx] = normalize_world_feed_entry(world_feed [world_feed_idx])
								world_feed_idx += 1

							bucket ["_collect_world_feed_idx"] = world_feed_idx
							if world_feed_idx < world_feed.size():
								continue

							bucket.erase("_collect_world_feed_idx")

						bucket ["_collect_stage"] = "prep_prune"

					"prep_prune":
						if not bool(options.get("skip_prune", false)):
							_prune_dead_npcs()
						bucket ["_collect_stage"] = "prep_archive"

					"prep_archive":
						var should_archive:= false
						if not bool(options.get("skip_archive", false)):
							should_archive = archive_generations.size() == 0
							if not should_archive:
								var last_archive: Variant = archive_generations.back()
								var last_archive_year: int = year - 1
								if typeof(last_archive) == TYPE_DICTIONARY:
									last_archive_year = int(last_archive.get("year", year - 1))
								elif last_archive != null and typeof(last_archive) == TYPE_OBJECT:
									var archive_year_raw: Variant = last_archive.get("year")
									if archive_year_raw != null:
										last_archive_year = int(archive_year_raw)
								should_archive = last_archive_year != year
						if should_archive:
							archive_generation()
						bucket ["_collect_stage"] = "build_serializable_scenario_state"

					"build_serializable_scenario_state":
						bucket ["_collect_serializable_scenario_state"] = _build_serializable_scenario_state()
						bucket ["_collect_stage"] = "build_shell"

					"build_shell":
						var saved_at_unix: int = int(Time.get_unix_time_from_system())
						var player_name: String = ""
						var player_age: int = 0
						if player != null:
							player_name = ("%s %s" % [player.first_name, player.last_name]).strip_edges()
							player_age = int(player.age)

						bucket ["_chunk_out"] = _build_rewind_snapshot_base_out(saved_at_unix, player_name, player_age)
						bucket ["_collect_section_idx"] = 0
						bucket ["_collect_stage"] = "build_sections"

					"build_sections":
						var out_raw: Variant = bucket.get("_chunk_out", {})
						var out: Dictionary = out_raw if typeof(out_raw) == TYPE_DICTIONARY else {}

						var serializable_state_raw: Variant = bucket.get("_collect_serializable_scenario_state", {})
						var serializable_state: Dictionary = serializable_state_raw if typeof(serializable_state_raw) == TYPE_DICTIONARY else {}

						var section_idx: int = int(bucket.get("_collect_section_idx", 0))
						var section_count: int = int(bucket.get("_collect_section_count", 5))

						if section_idx < section_count:
							var section: Dictionary = _build_rewind_snapshot_collect_section(section_idx, serializable_state)
							for raw_key in section.keys():
								out [str(raw_key)] = section.get(raw_key)

							bucket ["_chunk_out"] = out
							section_idx += 1
							bucket ["_collect_section_idx"] = section_idx

							if section_idx < section_count:
								continue

						bucket.erase("_collect_serializable_scenario_state")
						bucket.erase("_collect_section_idx")
						bucket.erase("_collect_section_count")
						bucket.erase("_collect_stage")
						bucket ["_chunk_npc_idx"] = 0
						bucket ["stage"] = "save_npcs"

					_:
						bucket ["_collect_stage"] = "prep_memory_compaction"

			"save_npcs":
				var out_raw: Variant = bucket.get("_chunk_out", {})
				var out: Dictionary = out_raw if typeof(out_raw) == TYPE_DICTIONARY else {}
				var npc_arr_raw: Variant = out.get("npcs", [])
				var npc_arr: Array = npc_arr_raw if typeof(npc_arr_raw) == TYPE_ARRAY else {}
				var idx: int = int(bucket.get("_chunk_npc_idx", 0))
				var batch: int = int(bucket.get("_chunk_npc_batch", 20))
				var end: int = min(idx + batch, npcs.size())
				while idx < end:
					npc_arr.append(_serialize_npc(npcs [idx]))
					idx += 1
				out ["npcs"] = npc_arr
				bucket ["_chunk_out"] = out
				bucket ["_chunk_npc_idx"] = idx
				if idx >= npcs.size():
					bucket ["stage"] = "save_write_encode_start"

			"save_write_encode_start":
				var out_raw: Variant = bucket.get("_chunk_out", {})
				var out: Dictionary = out_raw if typeof(out_raw) == TYPE_DICTIONARY else {}
				var write_chunk_size: int = int(bucket.get("_write_chunk_size", 131072))
				bucket ["_write_session"] = BinarySaveEngine.begin_encode_session(out, true, write_chunk_size)
				bucket.erase("_chunk_out")
				bucket.erase("_chunk_npc_idx")
				bucket.erase("_chunk_npc_batch")
				bucket ["stage"] = "save_write_encode_step"

			"save_write_encode_step":
				var write_session_raw: Variant = bucket.get("_write_session", {})
				var write_session: Dictionary = write_session_raw if typeof(write_session_raw) == TYPE_DICTIONARY else {}
				write_session = BinarySaveEngine.step_encode_session(write_session, 1)
				bucket ["_write_session"] = write_session
				if bool(write_session.get("is_complete", false)):
					var bytes_raw: Variant = write_session.get("bytes", PackedByteArray())
					bucket ["_write_bytes"] = bytes_raw if typeof(bytes_raw) == TYPE_PACKED_BYTE_ARRAY else PackedByteArray()
					bucket.erase("_write_session")
					bucket ["stage"] = "save_write_flush_open"

			"save_write_flush_open":
				bucket ["_write_file_offset"] = 0
				bucket ["_write_file_started"] = false
				bucket ["stage"] = "save_write_flush_chunks"

			"save_write_flush_chunks":
				var rewind_path: String = str(bucket.get("path", "")).strip_edges()
				var bytes_raw: Variant = bucket.get("_write_bytes", PackedByteArray())
				var bytes: PackedByteArray = bytes_raw if typeof(bytes_raw) == TYPE_PACKED_BYTE_ARRAY else PackedByteArray()
				var file_offset: int = int(bucket.get("_write_file_offset", 0))
				var file_chunk_size: int = int(bucket.get("_write_file_chunk_size", 131072))
				var file_started: bool = bool(bucket.get("_write_file_started", false))

				if file_offset >= bytes.size():
					bucket ["stage"] = "save_write_flush_close"
					continue

				var chunk_end: int = min(file_offset + file_chunk_size, bytes.size())
				var chunk: PackedByteArray = bytes.slice(file_offset, chunk_end)
				var mode: int = FileAccess.WRITE_READ if not file_started else FileAccess.READ_WRITE
				var f = FileAccess.open(rewind_path, mode)
				if f != null:
					f.seek(file_offset)
					f.store_buffer(chunk)
					f.close()
					bucket ["_write_file_started"] = true
					bucket ["_write_file_offset"] = chunk_end
					if chunk_end >= bytes.size():
						bucket ["stage"] = "save_write_flush_close"
				else:
					bucket ["active"] = false
					bucket ["stage"] = "complete"

			"save_write_flush_close":
				var rewind_path: String = str(bucket.get("path", "")).strip_edges()
				bucket.erase("_write_bytes")
				bucket.erase("_write_file_offset")
				bucket.erase("_write_file_started")
				bucket.erase("_write_file_chunk_size")
				if rewind_snapshot_paths.is_empty() or str(rewind_snapshot_paths.back()) != rewind_path:
					rewind_snapshot_paths.append(rewind_path)
				bucket ["stage"] = "cleanup"

			"cleanup":
				if rewind_snapshot_paths.size() > REWIND_LIMIT:
					var oldest_path: String = str(rewind_snapshot_paths.pop_front())
					if FileAccess.file_exists(oldest_path):
						DirAccess.remove_absolute(oldest_path)
				else:
					bucket ["active"] = false
					bucket ["stage"] = "complete"

			"complete":
				bucket = {}
				scenario_state ["rewind_snapshot_pipeline"] = bucket
				return true

			_:
				bucket ["active"] = false
				bucket ["stage"] = "complete"

	scenario_state ["rewind_snapshot_pipeline"] = bucket
	var final_bucket_raw: Variant = scenario_state.get("rewind_snapshot_pipeline", {})
	var final_bucket: Dictionary = final_bucket_raw if typeof(final_bucket_raw) == TYPE_DICTIONARY else {}
	return not bool(final_bucket.get("active", false))


func can_rewind_one_year() -> bool:
	return rewind_uses_remaining > 0 and not rewind_snapshot_paths.is_empty()

func consume_rewind_one_year() -> bool:
	if not can_rewind_one_year():
		return false

	var rewind_path: String = str(rewind_snapshot_paths.pop_back())
	if not FileAccess.file_exists(rewind_path):
		return false

	rewind_uses_remaining -= 1
	load_game(rewind_path)

	if FileAccess.file_exists(rewind_path):
		DirAccess.remove_absolute(rewind_path)

	afterlife_active = false
	awaiting_new_life = false
	transient_afterlife_biases.clear()
	afterlife_state.clear()
	return true
func erase_person_from_existence(npc: Person, _cause_text: String = "Erased from existence.") -> bool:
	if npc == null:
		return false
	if player != null and npc.id == player.id:
		return false

	var target_id: int = int(npc.id)
	if target_id <= 0:
		return false

	var target_name: String = ("%s %s" % [npc.first_name, npc.last_name]).strip_edges()

	for other in npcs:
		if other == null:
			continue
		if int(other.id) == target_id:
			continue

		other.parents.erase(target_id)
		other.children.erase(target_id)
		other.friends.erase(target_id)
		other.ex_partners.erase(target_id)
		other.schoolmates.erase(target_id)

		if other.partner != null and int(other.partner.id) == target_id:
			other.partner = null
			other.marital_status = "Single"

	if social_graph_engine != null:
		if social_graph_engine.graph.has(target_id):
			social_graph_engine.graph.erase(target_id)
		for node_id in social_graph_engine.graph.keys():
			if typeof(social_graph_engine.graph [node_id]) == TYPE_DICTIONARY:
				social_graph_engine.graph [node_id].erase(target_id)

	if memories.has(target_id):
		memories.erase(target_id)
	if compressed_memories.has(target_id):
		compressed_memories.erase(target_id)

	if belongings_engine != null and belongings_engine.belongings.has(target_id):
		belongings_engine.belongings.erase(target_id)

	if artifacts_engine != null and artifacts_engine.ownership.has(target_id):
		artifacts_engine.ownership.erase(target_id)

	if dragonballs_engine != null and dragonballs_engine.ownership.has(target_id):
		dragonballs_engine.ownership.erase(target_id)

	if red_bonnet_engine != null and int(red_bonnet_engine.owner_id) == target_id:
		red_bonnet_engine.owner_id = -1

	if many_realms_engine != null and int(many_realms_engine.ring_owner_id) == target_id:
		many_realms_engine.ring_owner_id = -1

	if school_engine != null:
		school_engine.enrollment.erase(target_id)
		school_engine.school_teachers.erase(target_id)
		for school_key in school_engine.school_rosters.keys():
			var roster = school_engine.school_rosters.get(school_key, [])
			if roster is Array:
				roster.erase(target_id)
				school_engine.school_rosters [school_key] = roster
		school_rosters = school_engine.school_rosters

	if workplace_engine != null:
		workplace_engine.npc_workplace.erase(target_id)
		for work_key in workplace_engine.workplace_rosters.keys():
			var workers = workplace_engine.workplace_rosters.get(work_key, [])
			if workers is Array:
				workers.erase(target_id)
				workplace_engine.workplace_rosters [work_key] = workers

	if island_realm_engine != null:
		for owner_id in island_realm_engine.islands.keys():
			var island = island_realm_engine.islands.get(owner_id, {})
			if typeof(island) == TYPE_DICTIONARY and island.has("population"):
				var population = island.get("population", [])
				if population is Array:
					population.erase(target_id)
					island ["population"] = population
					island_realm_engine.islands [owner_id] = island

	if dormant_npcs.has(target_id):
		dormant_npcs.erase(target_id)

	if npc_graveyard.has(target_id):
		npc_graveyard.erase(target_id)

	if population_shard_engine != null and population_shard_engine.lineage_ledger.has(target_id):
		population_shard_engine.lineage_ledger.erase(target_id)

	_remove_npc_from_active_indices(npc)
	npcs.erase(npc)
	_forget_npc_from_index(target_id)

	push_world_feed(
		"\n⚡\n %s was erased from existence." % target_name,
		{
			"npc_id": -1,
			"personally_relevant": true,
			"category": "artifact",
			"event_name": "npc_erased_from_existence",
			"source": "artifacts_engine"
		}
	)

	return true