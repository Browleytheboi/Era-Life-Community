extends Resource
class_name CrimeContractEngine

const CONTRACT_SCHEMA:= "eralife.crime_contract_engine"
const CONTRACT_VERSION:= 2

var gs
var active_contract: Dictionary = {}
var ledger: Array = []
var last_report: Dictionary = {}
var crime_target_identity_cache: Array = []
var crime_target_identity_cache_signature: String = ""
var crime_target_offense_matrix: Dictionary = {}
var crime_target_runtime_bootstrap_service_active: bool = false
var crime_target_runtime_bootstrap_last_state: String = ""
var crime_target_truth_probe_last_actor_id: int = -1
const CRIME_TARGET_SCAN_BUDGET_PER_QUANTUM:= 32
const CRIME_TARGET_WORK_BUDGET_USEC:= 1250
const CRIME_TARGET_STRANGER_COUNT:= 2
# Minimum gap between mid-scan partial snapshot publishes, per actor.
const CRIME_TARGET_PARTIAL_PUBLISH_INTERVAL_MS:= 250
const CRIME_TARGET_REFRESH_INTERVAL_MS:= 1800

var crime_target_identity_cache_by_actor: Dictionary = {}
var crime_target_identity_signature_by_actor: Dictionary = {}
var crime_target_source_signature_by_actor: Dictionary = {}
var crime_target_refresh_state_by_actor: Dictionary = {}




var crime_target_refresh_queue: Dictionary = {}
var crime_target_refresh_queue_head: int = 0
var crime_target_refresh_queue_tail: int = 0

var crime_target_refresh_keys: Dictionary = {}
var crime_target_refresh_service_active: bool = false



var crime_target_last_refresh_ms_by_actor: Dictionary = {}
var crime_target_last_partial_publish_ms_by_actor: Dictionary = {}

var crime_target_refresh_generation: int = 0
var crime_target_event_bus_bound: bool = false






var crime_target_actor_probe_active: bool = false
var crime_target_actor_probe_last_actor_id: int = -1





var crime_target_relationship_projection_revision_by_actor: Dictionary = {}



var active_weapon_target_stream_by_actor: Dictionary = {}
func _init(
	_game_state = null
) -> void:
	gs = _game_state








	call_deferred(
		"_arm_crime_target_runtime_bootstrap_service"
	)
func _arm_crime_target_runtime_bootstrap_service() -> void:
	var tree:= Engine.get_main_loop() as SceneTree

	if tree == null:
		_crime_target_truth_probe(
			"bootstrap_scene_tree_unavailable"
		)
		return

	var callback:= Callable(
		self,
		"_service_crime_target_runtime_bootstrap"
	)

	if tree.process_frame.is_connected(
		callback
	):
		crime_target_runtime_bootstrap_service_active = true
		return

	tree.process_frame.connect(
		callback
	)

	crime_target_runtime_bootstrap_service_active = true

	_crime_target_truth_probe(
		"bootstrap_process_frame_lease_acquired"
	)


func _service_crime_target_runtime_bootstrap() -> void:
	if gs == null:
		return



	_bind_crime_target_background_runtime()
	_arm_crime_target_actor_probe()

	if (
		OS.is_debug_build()
		and crime_target_event_bus_bound
		and gs.event_bus != null
	):



		gs.event_bus.subscribe(
			"crime.target.resident_projection.published",
			self,
			"_on_crime_target_truth_probe_snapshot_published",
			{
				"lane": "important",
				"allow_defer": false,
				"force_immediate": true,
				"subscription_priority": 1,
				"subscription_id": (
					"crime_target_pipeline_truth_probe"
				)
			}
		)

	var actor_id: int = -1

	if (
		gs.player != null
		and int(
			gs.player.id
		) > 0
	):
		actor_id = int(
			gs.player.id
		)

	if (
		actor_id > 0
		and actor_id
		!= crime_target_truth_probe_last_actor_id
	):
		crime_target_truth_probe_last_actor_id = actor_id

		_crime_target_truth_probe(
			"actor_admitted",
			{
				"actor_id": actor_id
			}
		)

	var actor_key: String = str(
		actor_id
	)

	var refresh_queued: bool = (
		actor_id > 0
		and crime_target_refresh_keys.has(
			actor_key
		)
	)

	var resident_contract: Dictionary = {}

	if actor_id > 0:
		resident_contract = (
			resident_crime_target_contract(
				actor_id
			)
		)

	var projection_complete: bool = (
		not resident_contract.is_empty()
		and bool(
			resident_contract.get(
				"complete",
				false
			)
		)
	)



	if (
		actor_id > 0
		and refresh_queued
	):
		_arm_crime_target_refresh_service()

	var bootstrap_state: String = (
		"%s:%s:%d:%s:%s:%s"
		% [
			str(
				crime_target_event_bus_bound
			),
			str(
				crime_target_actor_probe_active
			),
			actor_id,
			str(
				refresh_queued
			),
			str(
				crime_target_refresh_service_active
			),
			str(
				projection_complete
			)
		]
	)

	if (
		bootstrap_state
		!= crime_target_runtime_bootstrap_last_state
	):
		crime_target_runtime_bootstrap_last_state = (
			bootstrap_state
		)

		_crime_target_truth_probe(
			"bootstrap_state",
			{
				"event_bus_bound": (
					crime_target_event_bus_bound
				),
				"actor_probe_bound": (
					crime_target_actor_probe_active
				),
				"actor_id": actor_id,
				"target_refresh_queued": (
					refresh_queued
				),
				"target_service_hot": (
					crime_target_refresh_service_active
				),
				"target_projection_complete": (
					projection_complete
				)
			}
		)





	var actor_work_owned: bool = (
		actor_id <= 0
		or projection_complete
		or refresh_queued
		or crime_target_refresh_service_active
	)

	var bootstrap_complete: bool = (
		crime_target_event_bus_bound
		and crime_target_actor_probe_active
		and actor_work_owned
	)

	if not bootstrap_complete:
		return

	var tree:= Engine.get_main_loop() as SceneTree
	var callback:= Callable(
		self,
		"_service_crime_target_runtime_bootstrap"
	)

	if (
		tree != null
		and tree.process_frame.is_connected(
			callback
		)
	):
		tree.process_frame.disconnect(
			callback
		)

	crime_target_runtime_bootstrap_service_active = false

	_crime_target_truth_probe(
		"bootstrap_process_frame_lease_released",
		{
			"actor_id": actor_id,
			"event_bus_bound": (
				crime_target_event_bus_bound
			),
			"actor_probe_bound": (
				crime_target_actor_probe_active
			)
		}
	)
func _crime_target_truth_probe(
	stage: String,
	fields: Dictionary = {}
) -> void:
	if not OS.is_debug_build():
		return

	var parts:= PackedStringArray([
		"ERALIFE_CRIME_PIPELINE_TRUTH",
		"authority=CrimeContractEngine",
		"stage=%s" % stage
	])

	for raw_key in fields.keys():
		var key: String = str(
			raw_key
		).strip_edges()

		if key == "":
			continue

		parts.append(
			"%s=%s"
			% [
				key,
				str(
					fields.get(
						raw_key
					)
				).replace(
					"|",
					"/"
				)
			]
		)

	parts.append(
		"at_ms=%d"
		% int(
			Time.get_ticks_msec()
		)
	)

	EraLog.truth(
		"|".join(
			parts
		)
	)
func _arm_crime_target_actor_probe() -> void:
	var projection_engine = null

	if gs != null:
		projection_engine = (
			gs.reality_projection_contract_engine
		)

	if (
		projection_engine != null
		and projection_engine.has_signal(
			"resident_surface_contract_ready"
		)
	):
		var resident_surface_callback:= Callable(
			self,
			"_service_crime_target_actor_probe"
		)

		if not projection_engine.is_connected(
			"resident_surface_contract_ready",
			resident_surface_callback
		):
			projection_engine.connect(
				"resident_surface_contract_ready",
				resident_surface_callback
			)





		if projection_engine.has_signal(
			"resident_relationship_section_contract_ready"
		):
			var relationship_section_callback:= Callable(
				self,
				"_on_crime_target_relationship_section_ready"
			)

			if not projection_engine.is_connected(
				"resident_relationship_section_contract_ready",
				relationship_section_callback
			):
				projection_engine.connect(
					"resident_relationship_section_contract_ready",
					relationship_section_callback
				)

		crime_target_actor_probe_active = true







		_replay_crime_target_actor_probe_from_resident_projection(
			projection_engine
		)

	if (
		gs == null
		or gs.player == null
	):
		return

	var actor_id: int = int(
		gs.player.id
	)

	if actor_id <= 0:
		return

	var actor_key: String = str(
		actor_id
	)
	var resident_contract: Dictionary = (
		resident_crime_target_contract(
			actor_id
		)
	)
	var resident_projection_complete: bool = (
		not resident_contract.is_empty()
		and bool(
			resident_contract.get(
				"complete",
				false
			)
		)
	)

	if resident_projection_complete:
		return






	if crime_target_refresh_keys.has(
		actor_key
	):
		_arm_crime_target_refresh_service()
		return

	crime_target_actor_probe_last_actor_id = actor_id

	queue_crime_target_cache_refresh(
		gs.player,
		"crime_target_controlled_actor_autonomous_residency"
	)
func _on_crime_target_relationship_section_ready(
	signature: String,
	actor_id: int,
	section_id: String,
	section_contract: Dictionary
) -> void:
	if (
		gs == null
		or gs.player == null
		or actor_id <= 0
		or int(
			gs.player.id
		) != actor_id
		or section_contract.is_empty()
	):
		return

	var clean_signature: String = str(
		signature
	).strip_edges()

	var clean_section_id: String = str(
		section_id
	).strip_edges().to_lower()

	if (
		clean_signature == ""
		or clean_section_id == ""
	):
		return

	var resident_signature: String = (
		_crime_target_resident_projection_signature_hint()
	)

	if (
		resident_signature != ""
		and clean_signature != resident_signature
	):
		return



	if not bool(
		section_contract.get(
			"section_projection_complete",
			section_contract.get(
				"projection_complete",
				false
			)
		)
	):
		return

	var previous_relationship_revision: String = str(
		crime_target_relationship_projection_revision_by_actor.get(
			actor_id,
			""
		)
	).strip_edges()





	if previous_relationship_revision == clean_signature:
		return

	crime_target_relationship_projection_revision_by_actor [
		actor_id
	] = clean_signature







	_on_crime_target_realtime_tick(
		{
			"event_name": "resident_relationship_projection_ready",
			"source": "reality_projection_contract_engine",
			"section_id": clean_section_id,
			"resident_signature": clean_signature
		}
	)
func _crime_target_resident_projection_signature_hint() -> String:
	if (
		gs == null
		or typeof(
			gs.scenario_state
		) != TYPE_DICTIONARY
	):
		return ""

	var signature: String = str(
		gs.scenario_state.get(
			"resident_runtime_signature",
			""
		)
	).strip_edges()

	if signature != "":
		return signature

	return str(
		gs.scenario_state.get(
			"resident_runtime_attached_signature",
			""
		)
	).strip_edges()


func _replay_crime_target_actor_probe_from_resident_projection(
	projection_engine
) -> void:
	if (
		gs == null
		or gs.player == null
		or projection_engine == null
		or not projection_engine.has_method(
			"latest_resident_surface_admission_packet_for_actor"
		)
	):
		return

	var actor_id: int = int(
		gs.player.id
	)

	if actor_id <= 0:
		return

	var packet_raw: Variant = projection_engine.call(
		"latest_resident_surface_admission_packet_for_actor",
		actor_id
	)

	if typeof(packet_raw) != TYPE_DICTIONARY:
		return

	var packet: Dictionary = (
		packet_raw as Dictionary
	)

	if packet.is_empty():
		return

	var surface_raw: Variant = packet.get(
		"surface_contract",
		{}
	)

	if typeof(surface_raw) != TYPE_DICTIONARY:
		return







	_service_crime_target_actor_probe(
		str(
			packet.get(
				"signature",
				""
			)
		),
		str(
			packet.get(
				"surface_id",
				""
			)
		),
		surface_raw as Dictionary
	)
func _service_crime_target_actor_probe(
	signature: String,
	surface_id: String,
	surface_contract: Dictionary
) -> void:
	if (
		gs == null
		or gs.player == null
		or signature.strip_edges() == ""
		or surface_id.strip_edges() == ""
		or surface_contract.is_empty()
	):
		return

	var actor_id: int = int(
		surface_contract.get(
			"actor_id",
			-1
		)
	)

	var controlled_actor_id: int = int(
		gs.player.id
	)

	if (
		actor_id <= 0
		or actor_id != controlled_actor_id
	):
		return

	var actor_key: String = str(
		actor_id
	)
	var refresh_already_queued: bool = (
		crime_target_refresh_keys.has(
			actor_key
		)
	)
	var resident_contract: Dictionary = (
		resident_crime_target_contract(
			actor_id
		)
	)
	var resident_projection_exists: bool = (
		not resident_contract.is_empty()
	)




	if (
		actor_id == crime_target_actor_probe_last_actor_id
		and (
			refresh_already_queued
			or resident_projection_exists
		)
	):
		return

	crime_target_actor_probe_last_actor_id = actor_id

	if refresh_already_queued:
		return

	queue_crime_target_cache_refresh(
		gs.player,
		"crime_target_controlled_actor_resident"
	)
func _bind_crime_target_background_runtime() -> void:
	if (
		crime_target_event_bus_bound
		or gs == null
		or gs.event_bus == null
	):
		return

	crime_target_event_bus_bound = true


















	for raw_event_type in [
		ActionEventTypes.REALTIME_TICK,
		ActionEventTypes.NPC_BORN,
		ActionEventTypes.NPC_DIED,
		ActionEventTypes.NPC_MARRIED,
		ActionEventTypes.NPC_DIVORCED,
		ActionEventTypes.NPC_MOVED,
		ActionEventTypes.YEAR_PASSED,
		"population.card_graph_packet.updated"
	]:
		var event_type: String = str(
			raw_event_type
		).strip_edges()

		if event_type == "":
			continue

		gs.event_bus.subscribe(
			event_type,
			self,
			"_on_crime_target_realtime_tick",
			{
				"lane": "ambient",
				"allow_defer": true,
				"subscription_priority": 136,
				"subscription_id": (
					"crime_target_resident_cache:%s"
					% event_type
				)
			}
		)






	for raw_offense_event in [
		ActionEventTypes.NPC_COMMITTED_CRIME,
		ActionEventTypes.NPC_FOUGHT,
		"weapon_crime_committed"
	]:
		var offense_event: String = str(
			raw_offense_event
		).strip_edges()

		if offense_event == "":
			continue

		gs.event_bus.subscribe(
			offense_event,
			self,
			"_on_crime_target_offense_event",
			{
				"lane": "ambient",
				"allow_defer": true,
				"subscription_priority": 137,
				"subscription_id": (
					"crime_target_offense_matrix:%s"
					% offense_event
				)
			}
		)



	_arm_crime_target_actor_probe()
func _on_crime_target_offense_event(
	payload: Dictionary = {}
) -> void:
	if payload.is_empty():
		return

	var crime_event: Dictionary = _safe_dictionary(
		payload.get(
			"crime_event",
			{}
		)
	)

	var offender_id: int = int(
		payload.get(
			"actor_id",
			payload.get(
				"npc_id",
				crime_event.get(
					"actor_id",
					crime_event.get(
						"npc_id",
						-1
					)
				)
			)
		)
	)

	var victim_id: int = int(
		payload.get(
			"target_id",
			payload.get(
				"victim_id",
				crime_event.get(
					"target_id",
					crime_event.get(
						"victim_id",
						-1
					)
				)
			)
		)
	)

	var crime_name: String = str(
		payload.get(
			"crime_name",
			crime_event.get(
				"crime_name",
				""
			)
		)
	).strip_edges().to_lower()

	var weapon_action_id: String = str(
		payload.get(
			"weapon_action_id",
			crime_event.get(
				"weapon_action_id",
				""
			)
		)
	).strip_edges().to_lower()



	if (
		crime_name == ""
		and weapon_action_id == ""
	):
		return

	if (
		offender_id <= 0
		or victim_id <= 0
		or offender_id == victim_id
	):
		return

	_increment_crime_target_offense_count(
		offender_id,
		victim_id,
		1
	)




	if (
		gs != null
		and gs.player != null
	):
		queue_crime_target_cache_refresh(
			gs.player,
			"crime_target_offense_matrix_changed"
		)


func _increment_crime_target_offense_count(
	offender_id: int,
	victim_id: int,
	amount: int = 1
) -> void:
	if (
		offender_id <= 0
		or victim_id <= 0
		or offender_id == victim_id
		or amount <= 0
	):
		return

	var offender_key: String = str(
		offender_id
	)
	var victim_key: String = str(
		victim_id
	)
	var offender_raw: Variant = (
		crime_target_offense_matrix.get(
			offender_key,
			{}
		)
	)
	var offender_row: Dictionary = (
		offender_raw as Dictionary
		if typeof(offender_raw) == TYPE_DICTIONARY
		else {}
	)

	offender_row [
		victim_key
	] = int(
		offender_row.get(
			victim_key,
			0
		)
	) + amount

	crime_target_offense_matrix [
		offender_key
	] = offender_row


func crime_target_circle_offense_count(
	offender_id: int,
	circle_target_ids: Array
) -> int:
	if offender_id <= 0:
		return 0

	var offender_raw: Variant = (
		crime_target_offense_matrix.get(
			str(
				offender_id
			),
			{}
		)
	)
	var offender_row: Dictionary = (
		offender_raw as Dictionary
		if typeof(offender_raw) == TYPE_DICTIONARY
		else {}
	)

	if offender_row.is_empty():
		return 0

	var total: int = 0



	for raw_target_id in circle_target_ids:
		var target_id: int = int(
			raw_target_id
		)

		if target_id <= 0:
			continue

		total += int(
			offender_row.get(
				str(
					target_id
				),
				0
			)
		)

	return total
func _crime_target_source_signature(
	actor: Person
) -> String:
	if (
		actor == null
		or gs == null
	):
		return ""

	var actor_id: int = int(
		actor.id
	)

	var partner_id: int = -1

	if actor.partner != null:
		partner_id = int(
			actor.partner.id
		)

	var parent_count: int = 0
	var child_count: int = 0
	var friend_count: int = 0
	var affection_edge_count: int = 0

	if typeof(actor.parents) == TYPE_ARRAY:
		parent_count = actor.parents.size()

	if typeof(actor.children) == TYPE_ARRAY:
		child_count = actor.children.size()

	if typeof(actor.friends) == TYPE_ARRAY:
		friend_count = actor.friends.size()

	if typeof(actor.affection) == TYPE_DICTIONARY:
		affection_edge_count = actor.affection.size()

	var relationship_graph_revision: String = ""

	if (
		"canonical_relationship_graph" in gs
		and typeof(
			gs.canonical_relationship_graph
		) == TYPE_DICTIONARY
	):
		var graph_contract: Dictionary = (
			gs.canonical_relationship_graph
		)

		relationship_graph_revision = (
			"%s:%s"
			% [
				str(
					graph_contract.get(
						"last_event_id",
						""
					)
				),
				str(
					graph_contract.get(
						"updated_at_ms",
						""
					)
				)
			]
		)

	var relationship_projection_revision: String = str(
		crime_target_relationship_projection_revision_by_actor.get(
			actor_id,
			""
		)
	).strip_edges()

	return (
		"%d:%d:%d:%d:%d:%d:%d:%d:%s:%s"
		% [
			actor_id,
			int(gs.year),
			int(gs.npcs.size()),
			parent_count,
			child_count,
			friend_count,
			affection_edge_count,
			partner_id,
			relationship_graph_revision,
			relationship_projection_revision
		]
	)
func _on_crime_target_realtime_tick(
	_payload: Dictionary = {}
) -> void:
	if (
		gs == null
		or gs.player == null
	):
		return

	var actor_id: int = int(
		gs.player.id
	)
	var actor_key: String = str(
		actor_id
	)

	var event_name: String = str(
		_payload.get(
			"event_name",
			""
		)
	).strip_edges()

	var force_truth_refresh: bool = (
		event_name in [
			str(ActionEventTypes.NPC_BORN),
			str(ActionEventTypes.NPC_DIED),
			str(ActionEventTypes.NPC_MARRIED),
			str(ActionEventTypes.NPC_DIVORCED),
			str(ActionEventTypes.NPC_MOVED),
			str(ActionEventTypes.YEAR_PASSED)
		]
	)

	var source_signature: String = (
		_crime_target_source_signature(
			gs.player
		)
	)



	if crime_target_refresh_keys.has(
		actor_key
	):
		var state_raw: Variant = (
			crime_target_refresh_state_by_actor.get(
				actor_key,
				{}
			)
		)

		if typeof(state_raw) == TYPE_DICTIONARY:
			var state: Dictionary = (
				state_raw as Dictionary
			)

			var queued_source_signature: String = str(
				state.get(
					"source_signature",
					""
				)
			)

			if (
				force_truth_refresh
				or source_signature
				!= queued_source_signature
			):
				state [
					"restart_requested"
				] = true
				state [
					"restart_reason"
				] = (
					event_name
					if event_name != ""
					else "crime_target_source_revision_changed"
				)

			crime_target_refresh_state_by_actor [
				actor_key
			] = state

		return

	var resident_raw: Variant = (
		crime_target_identity_cache_by_actor.get(
			actor_id,
			{}
		)
	)
	var resident_contract: Dictionary = (
		resident_raw as Dictionary
		if typeof(resident_raw) == TYPE_DICTIONARY
		else {}
	)

	var committed_source_signature: String = str(
		crime_target_source_signature_by_actor.get(
			actor_id,
			""
		)
	)







	if (
		not force_truth_refresh
		and not resident_contract.is_empty()
		and bool(
			resident_contract.get(
				"complete",
				false
			)
		)
		and source_signature
		== committed_source_signature
	):
		return

	queue_crime_target_cache_refresh(
		gs.player,
		(
			"crime_target_truth_changed:%s"
			% event_name
			if force_truth_refresh
			else "crime_target_source_revision_changed"
		)
	)
func _arm_crime_target_refresh_service() -> void:
	if crime_target_refresh_queue.is_empty():
		return

	var tree:= Engine.get_main_loop() as SceneTree

	if tree == null:
		_crime_target_truth_probe(
			"target_service_lease_failed",
			{
				"reason": "scene_tree_unavailable",
				"queue_depth": (
					crime_target_refresh_queue.size()
				)
			}
		)
		return

	var callback:= Callable(
		self,
		"_drive_crime_target_refresh_process_frame"
	)



	if tree.process_frame.is_connected(
		callback
	):
		crime_target_refresh_service_active = true
		return

	tree.process_frame.connect(
		callback
	)

	crime_target_refresh_service_active = true

	_crime_target_truth_probe(
		"target_service_lease_acquired",
		{
			"queue_depth": (
				crime_target_refresh_queue.size()
			)
		}
	)
func _drive_crime_target_refresh_process_frame() -> void:
	var tree:= Engine.get_main_loop() as SceneTree
	var callback:= Callable(
		self,
		"_drive_crime_target_refresh_process_frame"
	)

	if (
		gs == null
		or crime_target_refresh_queue.is_empty()
	):
		if (
			tree != null
			and tree.process_frame.is_connected(
				callback
			)
		):
			tree.process_frame.disconnect(
				callback
			)

		crime_target_refresh_service_active = false

		_crime_target_truth_probe(
			"target_service_lease_released",
			{
				"queue_depth": (
					crime_target_refresh_queue.size()
				)
			}
		)
		return

	var actor_id: int = int(
		crime_target_refresh_queue.get(
			crime_target_refresh_queue_head,
			-1
		)
	)

	var candidate_source_count: int = 0

	if gs != null:
		candidate_source_count = (
			gs.npcs.size()
		)

	_crime_target_truth_probe(
		"target_service_entered",
		{
			"actor_id": actor_id,
			"candidate_source_count": (
				candidate_source_count
			),
			"queue_depth": (
				crime_target_refresh_queue.size()
			)
		}
	)



	_service_crime_target_refresh_queue()

	if crime_target_refresh_queue.is_empty():
		if (
			tree != null
			and tree.process_frame.is_connected(
				callback
			)
		):
			tree.process_frame.disconnect(
				callback
			)

		crime_target_refresh_service_active = false

		_crime_target_truth_probe(
			"target_service_lease_released",
			{
				"queue_depth": 0
			}
		)
	else:
		crime_target_refresh_service_active = true
func _on_crime_target_truth_probe_snapshot_published(
	payload: Dictionary = {}
) -> void:
	var actor_id: int = int(
		payload.get(
			"actor_id",
			-1
		)
	)

	var rows_raw: Variant = payload.get(
		"rows",
		[]
	)

	var rows: Array = (
		rows_raw as Array
		if typeof(
			rows_raw
		) == TYPE_ARRAY
		else []
	)

	if not rows.is_empty():
		_crime_target_truth_probe(
			"target_admitted",
			{
				"actor_id": actor_id,
				"resident_target_count": (
					rows.size()
				),
				"relationship_target_count": int(
					payload.get(
						"relationship_target_count",
						0
					)
				),
				"random_stranger_count": int(
					payload.get(
						"random_stranger_count",
						0
					)
				)
			}
		)

	_crime_target_truth_probe(
		"snapshot_published",
		{
			"actor_id": actor_id,
			"row_count": rows.size(),
			"complete": bool(
				payload.get(
					"complete",
					false
				)
			),
			"signature": str(
				payload.get(
					"signature",
					""
				)
			)
		}
	)
func queue_crime_target_cache_refresh(
	actor: Person,
	reason: String = "crime_target_refresh"
) -> void:
	if (
		actor == null
		or gs == null
	):
		return

	var actor_id: int = int(
		actor.id
	)

	var actor_key: String = str(
		actor_id
	)

	if crime_target_refresh_keys.has(
		actor_key
	):
		return

	crime_target_refresh_generation += 1

	crime_target_refresh_keys [
		actor_key
	] = true

	crime_target_refresh_state_by_actor [
		actor_key
	] = {
		"actor_id": actor_id,
		"cursor": 0,
		"relationship_rows": [],
		"stranger_candidates": [],
		"generation": crime_target_refresh_generation,
		"reason": reason,
		"source_signature": (
			_crime_target_source_signature(
				actor
			)
		),
		"restart_requested": false,
		"restart_reason": "",
		"started_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	var queue_id: int = (
		crime_target_refresh_queue_tail
	)

	crime_target_refresh_queue_tail += 1

	crime_target_refresh_queue [
		queue_id
	] = actor_id

	_crime_target_truth_probe(
		"target_refresh_queued",
		{
			"actor_id": actor_id,
			"generation": (
				crime_target_refresh_generation
			),
			"queue_depth": (
				crime_target_refresh_queue.size()
			),
			"reason": reason
		}
	)

	_arm_crime_target_refresh_service()
func _service_crime_target_refresh_queue() -> void:
	crime_target_refresh_service_active = false

	if (
		crime_target_refresh_queue.is_empty()
		or gs == null
	):
		return

	var queue_id: int = (
		crime_target_refresh_queue_head
	)
	crime_target_refresh_queue_head += 1

	var actor_id: int = int(
		crime_target_refresh_queue.get(
			queue_id,
			-1
		)
	)

	crime_target_refresh_queue.erase(
		queue_id
	)

	if crime_target_refresh_queue.is_empty():
		crime_target_refresh_queue_head = 0
		crime_target_refresh_queue_tail = 0

	if actor_id <= 0:
		_arm_crime_target_refresh_service()
		return

	var actor_key: String = str(
		actor_id
	)

	var state_raw: Variant = (
		crime_target_refresh_state_by_actor.get(
			actor_key,
			{}
		)
	)
	var state: Dictionary = (
		state_raw as Dictionary
		if typeof(state_raw) == TYPE_DICTIONARY
		else {}
	)

	var actor: Person = _resident_actor_by_id(
		actor_id
	)

	if (
		actor == null
		or state.is_empty()
	):
		crime_target_refresh_keys.erase(
			actor_key
		)
		crime_target_refresh_state_by_actor.erase(
			actor_key
		)

		_arm_crime_target_refresh_service()
		return




	var stream_raw: Variant = (
		active_weapon_target_stream_by_actor.get(
			actor_key,
			{}
		)
	)
	var active_weapon_stream: bool = (
		typeof(stream_raw) == TYPE_DICTIONARY
		and not (stream_raw as Dictionary).is_empty()
	)
	var controlled_actor_id: int = (
		int(gs.player.id)
		if gs.player != null
		else -1
	)

	if (
		controlled_actor_id > 0
		and actor_id != controlled_actor_id
		and not active_weapon_stream
	):
		crime_target_refresh_keys.erase(
			actor_key
		)
		crime_target_refresh_state_by_actor.erase(
			actor_key
		)

		_arm_crime_target_refresh_service()
		return

	var cursor: int = int(
		state.get(
			"cursor",
			0
		)
	)

	var relationship_rows_raw: Variant = state.get(
		"relationship_rows",
		[]
	)
	var relationship_rows: Array = (
		relationship_rows_raw as Array
		if typeof(relationship_rows_raw) == TYPE_ARRAY
		else []
	)

	var stranger_candidates_raw: Variant = state.get(
		"stranger_candidates",
		[]
	)
	var stranger_candidates: Array = (
		stranger_candidates_raw as Array
		if typeof(stranger_candidates_raw) == TYPE_ARRAY
		else []
	)

	var generation: int = int(
		state.get(
			"generation",
			0
		)
	)




	var restart_requested: bool = bool(
		state.get(
			"restart_requested",
			false
		)
	)

	if (
		restart_requested
		or stranger_candidates.size()
		> CRIME_TARGET_STRANGER_COUNT
	):
		cursor = 0
		relationship_rows = []
		stranger_candidates = []
		generation += 1

		state [
			"generation"
		] = generation
		state [
			"source_signature"
		] = _crime_target_source_signature(
			actor
		)
		state [
			"restart_requested"
		] = false
		state [
			"restart_reason"
		] = ""
		state [
			"started_at_ms"
		] = int(
			Time.get_ticks_msec()
		)



	# FIX: these two lines clamped the tuned constants down to 4 NPCs and 250us per
	# quantum, which made CRIME_TARGET_SCAN_BUDGET_PER_QUANTUM (32) and
	# CRIME_TARGET_WORK_BUDGET_USEC (1250) dead values. With a 40-NPC population a
	# full scan needed ~10 quanta instead of ~2, and because every npc_born restarts
	# the scan from cursor 0, world generation could never converge -- it just
	# restarted and republished partial snapshots over and over.
	var scan_budget_this_quantum: int = CRIME_TARGET_SCAN_BUDGET_PER_QUANTUM
	var work_budget_usec: int = CRIME_TARGET_WORK_BUDGET_USEC

	var scanned_this_quantum: int = 0
	var observable_change_this_quantum: bool = false
	var quantum_started_usec: int = int(
		Time.get_ticks_usec()
	)

	while (
		cursor < gs.npcs.size()
		and scanned_this_quantum
		< scan_budget_this_quantum
	):



		if (
			scanned_this_quantum > 0
			and int(
				Time.get_ticks_usec()
			) - quantum_started_usec
			>= work_budget_usec
		):
			break

		var raw_person: Variant = gs.npcs [
			cursor
		]

		cursor += 1
		scanned_this_quantum += 1

		if not (
			raw_person is Person
		):
			continue

		var target: Person = raw_person as Person

		if (
			target == null
			or not bool(
				target.alive
			)
			or int(
				target.id
			) == actor_id
		):
			continue

		var relationship_contract: Dictionary = {}

		if (
			gs.relationship_engine != null
			and gs.relationship_engine.has_method(
				"crime_target_relationship_contract"
			)
		):
			relationship_contract = (
				gs.relationship_engine
				.crime_target_relationship_contract(
					actor,
					target
				)
			)

		if bool(
			relationship_contract.get(
				"meaningful_relationship",
				false
			)
		):
			relationship_rows.append(
				_crime_target_identity_row(
					target,
					relationship_contract,
					"relationship"
				)
			)

			observable_change_this_quantum = true
			continue

		if bool(
			relationship_contract.get(
				"unrelated_stranger",
				false
			)
		):
			var random_material: String = (
				"%d:%d:%d:%d"
				% [
					actor_id,
					generation,
					int(
						gs.year
					),
					int(
						target.id
					)
				]
			)

			var candidate: Dictionary = {
				"random_rank": absi(
					int(
						random_material.hash()
					)
				),
				"row": _crime_target_identity_row(
					target,
					relationship_contract,
					"random_stranger"
				)
			}

			if stranger_candidates.size() < CRIME_TARGET_STRANGER_COUNT:
				stranger_candidates.append(
					candidate
				)
				observable_change_this_quantum = true
			else:
				var worst_index: int = -1
				var worst_rank: int = -1



				for candidate_index in range(
					stranger_candidates.size()
				):
					var existing_raw: Variant = (
						stranger_candidates [
							candidate_index
						]
					)
					var existing: Dictionary = (
						existing_raw as Dictionary
						if typeof(existing_raw) == TYPE_DICTIONARY
						else {}
					)
					var existing_rank: int = int(
						existing.get(
							"random_rank",
							0
						)
					)

					if (
						worst_index < 0
						or existing_rank > worst_rank
					):
						worst_index = candidate_index
						worst_rank = existing_rank

				if (
					worst_index >= 0
					and int(
						candidate.get(
							"random_rank",
							0
						)
					) < worst_rank
				):
					stranger_candidates [
						worst_index
					] = candidate
					observable_change_this_quantum = true

	state [
		"cursor"
	] = cursor
	state [
		"relationship_rows"
	] = relationship_rows
	state [
		"stranger_candidates"
	] = stranger_candidates

	crime_target_refresh_state_by_actor [
		actor_key
	] = state

	var complete: bool = (
		cursor >= gs.npcs.size()
	)

	if complete:
		var current_source_signature: String = (
			_crime_target_source_signature(
				actor
			)
		)
		var scanned_source_signature: String = str(
			state.get(
				"source_signature",
				""
			)
		)



		if (
			bool(
				state.get(
					"restart_requested",
					false
				)
			)
			or current_source_signature
			!= scanned_source_signature
		):
			generation += 1

			state [
				"cursor"
			] = 0
			state [
				"relationship_rows"
			] = []
			state [
				"stranger_candidates"
			] = []
			state [
				"generation"
			] = generation
			state [
				"source_signature"
			] = current_source_signature
			state [
				"restart_requested"
			] = false
			state [
				"restart_reason"
			] = ""
			state [
				"started_at_ms"
			] = int(
				Time.get_ticks_msec()
			)

			crime_target_refresh_state_by_actor [
				actor_key
			] = state

			var restart_queue_id: int = (
				crime_target_refresh_queue_tail
			)
			crime_target_refresh_queue_tail += 1
			crime_target_refresh_queue [
				restart_queue_id
			] = actor_id

			_arm_crime_target_refresh_service()
			return




	# FIX: previously this published on EVERY quantum that changed anything, so a
	# single scan fanned out ~10 partial snapshots, each one waking CrimeHub ->
	# MainScene -> CrimePanel and repainting the same target cards. That fan-out is
	# what produced the repeated card_painted lines and the 6ms
	# ERALIFE_EVENT_BUS_SLOW_SUBSCRIBER stalls (a dropped frame at 60fps).
	# Completed scans always publish immediately; partial progress is now rate
	# limited, so the list still fills in progressively without the storm.
	var should_publish: bool = complete

	if not complete and observable_change_this_quantum:
		var now_ms: int = int(Time.get_ticks_msec())
		var last_partial_ms: int = int(
			crime_target_last_partial_publish_ms_by_actor.get(
				actor_id,
				0
			)
		)

		if now_ms - last_partial_ms >= CRIME_TARGET_PARTIAL_PUBLISH_INTERVAL_MS:
			should_publish = true
			crime_target_last_partial_publish_ms_by_actor [
				actor_id
			] = now_ms

	if should_publish:
		_publish_crime_target_cache_snapshot(
			actor,
			state,
			complete
		)

	if complete:
		crime_target_last_partial_publish_ms_by_actor.erase(
			actor_id
		)

	if complete:
		crime_target_source_signature_by_actor [
			actor_id
		] = str(
			state.get(
				"source_signature",
				""
			)
		)

		crime_target_refresh_keys.erase(
			actor_key
		)
		crime_target_refresh_state_by_actor.erase(
			actor_key
		)


		crime_target_last_refresh_ms_by_actor [
			actor_id
		] = int(
			Time.get_ticks_msec()
		)
	else:
		var next_queue_id: int = (
			crime_target_refresh_queue_tail
		)
		crime_target_refresh_queue_tail += 1

		crime_target_refresh_queue [
			next_queue_id
		] = actor_id

	_arm_crime_target_refresh_service()
func _publish_crime_target_cache_snapshot(
	actor: Person,
	state: Dictionary,
	complete: bool
) -> void:
	if actor == null:
		return

	var actor_id: int = int(
		actor.id
	)
	var actor_key: String = str(
		actor_id
	)
	var previous_signature: String = str(
		crime_target_identity_signature_by_actor.get(
			actor_id,
			""
		)
	)

	var relationship_rows_raw: Variant = state.get(
		"relationship_rows",
		[]
	)
	var relationship_rows: Array = (
		(relationship_rows_raw as Array).duplicate(false)
		if typeof(relationship_rows_raw) == TYPE_ARRAY
		else []
	)
	var stranger_candidates_raw: Variant = state.get(
		"stranger_candidates",
		[]
	)
	var stranger_candidates: Array = (
		(stranger_candidates_raw as Array).duplicate(false)
		if typeof(stranger_candidates_raw) == TYPE_ARRAY
		else []
	)



	stranger_candidates.sort_custom(
		func (
			left_raw: Variant,
			right_raw: Variant
		) -> bool:
			var left: Dictionary = (
				left_raw as Dictionary
				if typeof(left_raw) == TYPE_DICTIONARY
				else {}
			)
			var right: Dictionary = (
				right_raw as Dictionary
				if typeof(right_raw) == TYPE_DICTIONARY
				else {}
			)

			return int(
				left.get(
					"random_rank",
					0
				)
			) < int(
				right.get(
					"random_rank",
					0
				)
			)
	)

	var rows: Array = relationship_rows.duplicate(
		false
	)
	var stranger_count: int = mini(
		CRIME_TARGET_STRANGER_COUNT,
		stranger_candidates.size()
	)

	for index in range(
		stranger_count
	):
		var candidate_raw: Variant = stranger_candidates [
			index
		]
		var candidate: Dictionary = (
			candidate_raw as Dictionary
			if typeof(candidate_raw) == TYPE_DICTIONARY
			else {}
		)
		var row_raw: Variant = candidate.get(
			"row",
			{}
		)
		var row: Dictionary = (
			(row_raw as Dictionary).duplicate(false)
			if typeof(row_raw) == TYPE_DICTIONARY
			else {}
		)

		if not row.is_empty():
			rows.append(
				row
			)

	var signature_rows:= PackedStringArray()

	for raw_row in rows:
		var row: Dictionary = (
			raw_row as Dictionary
			if typeof(raw_row) == TYPE_DICTIONARY
			else {}
		)

		signature_rows.append(
			"%d:%s"
			% [
				int(
					row.get(
						"target_id",
						-1
					)
				),
				str(
					row.get(
						"target_source",
						""
					)
				)
			]
		)

	var signature: String = (
		"%d:%d:%s:%s"
		% [
			actor_id,
			int(
				gs.year
			),
			str(
				complete
			),
			"|".join(
				signature_rows
			)
		]
	)
	var resident_projection_changed: bool = (
		signature != previous_signature
	)
	var resident_contract: Dictionary = {
		"schema": "eralife.crime.resident_target_contract",
		"version": CONTRACT_VERSION,
		"actor_id": actor_id,
		"rows": rows,
		"complete": complete,
		"relationship_target_count": relationship_rows.size(),
		"random_stranger_count": stranger_count,
		"target_policy": (
			"meaningful_relationships_plus_two_unrelated_strangers"
		),
		"acquaintances_excluded": true,
		"signature": signature,
		"blocks_ui": false,
		"ready_gate_member": false,
		"published_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	crime_target_identity_cache_by_actor [
		actor_id
	] = resident_contract

	crime_target_identity_signature_by_actor [
		actor_id
	] = signature

	if (
		gs.player != null
		and int(
			gs.player.id
		) == actor_id
	):
		crime_target_identity_cache = rows.duplicate(
			false
		)
		crime_target_identity_cache_signature = signature




	if (
		resident_projection_changed
		and gs != null
		and gs.event_bus != null
	):
		gs.event_bus.emit(
			"crime.target.resident_projection.published",
			resident_contract.duplicate(
				false
			)
		)



	var stream: Dictionary = _safe_dictionary(
		active_weapon_target_stream_by_actor.get(
			actor_key,
			{}
		)
	)

	if stream.is_empty():
		return

	var shared_payload: Dictionary = _safe_dictionary(
		stream.get(
			"shared_payload",
			{}
		)
	)
	var source_item: Dictionary = _safe_dictionary(
		shared_payload.get(
			"source_item",
			{}
		)
	)
	var weapon_contract: Dictionary = _safe_dictionary(
		shared_payload.get(
			"weapon_contract",
			{}
		)
	)
	var weapon_action: Dictionary = _safe_dictionary(
		shared_payload.get(
			"weapon_action",
			{}
		)
	)
	var published_target_ids: Dictionary = _safe_dictionary(
		stream.get(
			"published_target_ids",
			{}
		)
	)
	var delta_rows: Array = []

	for raw_row in rows:
		var target_row: Dictionary = (
			(raw_row as Dictionary).duplicate(false)
			if typeof(raw_row) == TYPE_DICTIONARY
			else {}
		)
		var target_id: int = int(
			target_row.get(
				"target_id",
				-1
			)
		)

		if target_id <= 0:
			continue

		var target_key: String = str(
			target_id
		)

		if published_target_ids.has(
			target_key
		):
			continue

		target_row [
			"actions"
		] = [
			{
				"id": "choose_weapon_target",
				"label": "Select Target",
				"payload": {
					"action_id": "choose_weapon_target",
					"target_id": target_id
				}
			}
		]
		target_row [
			"body_surface_contract"
		] = _weapon_body_surface_contract(
			target_id,
			str(
				target_row.get(
					"label",
					"Target"
				)
			),
			source_item,
			weapon_contract,
			weapon_action
		)
		target_row [
			"target_projection_complete"
		] = complete
		target_row [
			"target_projection_pending"
		] = not complete
		target_row [
			"target_projection_signature"
		] = signature
		target_row [
			"progressive_publication"
		] = true

		delta_rows.append(
			target_row
		)
		published_target_ids [
			target_key
		] = true

	stream [
		"published_target_ids"
	] = published_target_ids
	stream [
		"last_signature"
	] = signature
	stream [
		"projection_complete"
	] = complete
	stream [
		"updated_at_ms"
	] = int(
		Time.get_ticks_msec()
	)

	active_weapon_target_stream_by_actor [
		actor_key
	] = stream

	if (
		gs != null
		and gs.event_bus != null
		and (
			not delta_rows.is_empty()
			or complete
		)
	):
		gs.event_bus.emit(
			"crime.weapon.target_projection.published",
			{
				"actor_id": actor_id,
				"rows": delta_rows,
				"complete": complete,
				"relationship_target_count": relationship_rows.size(),
				"random_stranger_count": stranger_count,
				"target_policy": (
					"meaningful_relationships_plus_two_unrelated_strangers"
				),
				"acquaintances_excluded": true,
				"signature": signature,
				"producer": "CrimeContractEngine",
				"ui_is_renderer_only": true,
				"published_at_ms": int(
					Time.get_ticks_msec()
				)
			}
		)

	if complete:
		active_weapon_target_stream_by_actor.erase(
			actor_key
		)
func resident_crime_target_contract(
	actor_id: int
) -> Dictionary:
	if actor_id <= 0:
		return {}

	var resident_raw: Variant = (
		crime_target_identity_cache_by_actor.get(
			actor_id,
			{}
		)
	)

	if typeof(resident_raw) != TYPE_DICTIONARY:
		return {}




	return (
		resident_raw as Dictionary
	).duplicate(false)
func _crime_target_identity_row(
	target: Person,
	relationship_contract: Dictionary,
	target_source: String
) -> Dictionary:


	var relationship_label: String = str(
		relationship_contract.get(
			"target_relationship_title",
			""
		)
	).strip_edges()


	if relationship_label == "":
		if target_source == "random_stranger":
			relationship_label = (
				"Unrelated stranger"
			)
		else:
			relationship_label = str(
				relationship_contract.get(
					"classification",
					relationship_contract.get(
						"role",
						"Relationship"
					)
				)
			).replace(
				"_",
				""
			).capitalize()

	return {
		"kind": "crime_target",
		"label": _actor_display_name(
			target
		),
		"target_id": int(
			target.id
		),
		"subtitle": (
			"Age %d • %s"
			% [
				int(
					target.age
				),
				relationship_label
			]
		),
		"relationship_label": relationship_label,
		"relationship_contract": relationship_contract,
		"target_source": target_source,




		"target_realm_id": int(
			target.realm_id
		),
		"target_home_country": str(
			target.home_country
		).strip_edges(),
		"target_residence_contract": {
			"realm_id": int(
				target.realm_id
			),
			"home_country": str(
				target.home_country
			).strip_edges(),
		},



		"actions": [],
	}
func physical_crime_target_access_contract(
	actor: Person,
	target_realm_id: int,
	target_home_country: String = ""
) -> Dictionary:
	if actor == null:
		return {
			"schema": "eralife.crime.physical_target_access_contract",
			"version": CONTRACT_VERSION,
			"allowed": false,
			"reason_code": "missing_actor",
			"reason": "Physical target access could not be resolved."
		}

	var actor_realm_id: int = int(
		actor.realm_id
	)
	var actor_home_country: String = str(
		actor.home_country
	).strip_edges()
	var clean_target_country: String = str(
		target_home_country
	).strip_edges()

	var actor_country_key: String = (
		actor_home_country.to_lower()
	)
	var target_country_key: String = (
		clean_target_country.to_lower()
	)

	var comparison_available: bool = false
	var comparison_basis: String = "unresolved"
	var same_nation: bool = true



	if (
		actor_country_key != ""
		and target_country_key != ""
	):
		comparison_available = true
		comparison_basis = "home_country"
		same_nation = (
			actor_country_key
			== target_country_key
		)




	elif (
		actor_realm_id > 0
		and target_realm_id > 0
	):
		comparison_available = true
		comparison_basis = "realm_id"
		same_nation = (
			actor_realm_id
			== target_realm_id
		)

	var allowed: bool = (
		not comparison_available
		or same_nation
	)

	return {
		"schema": "eralife.crime.physical_target_access_contract",
		"version": CONTRACT_VERSION,
		"allowed": allowed,
		"comparison_available": comparison_available,
		"comparison_basis": comparison_basis,
		"same_nation": same_nation,
		"actor_realm_id": actor_realm_id,
		"target_realm_id": target_realm_id,
		"actor_home_country": actor_home_country,
		"target_home_country": clean_target_country,
		"reason_code": (
			""
			if allowed
			else "target_lives_in_different_nation"
		),
		"reason": (
			""
			if allowed
			else (
				"Not available: this person lives in another nation."
			)
		),
		"population_scan_performed": false,
	}
func targeted_crime_requires_same_nation(
	crime_action_id: String,
	crime_method_id: String = ""
) -> bool:
	var clean_action_id: String = str(
		crime_action_id
	).strip_edges().to_lower()
	var clean_method_id: String = str(
		crime_method_id
	).strip_edges().to_lower()

	match clean_action_id:
		"assault":
			return true

		"murder":
			return clean_method_id in [
				"poison",
				"direct_attack",
				"attack"
			]

		_:
			return false
func decorate_weapon_target_row_for_physical_access(
	actor: Person,
	row: Dictionary
) -> Dictionary:
	var decorated_row: Dictionary = (
		row.duplicate(false)
	)

	if actor == null:
		return decorated_row

	var target_id: int = int(
		decorated_row.get(
			"target_id",
			-1
		)
	)

	if target_id <= 0:
		return decorated_row

	var access_contract: Dictionary = (
		physical_crime_target_access_contract(
			actor,
			int(
				decorated_row.get(
					"target_realm_id",
					-1
				)
			),
			str(
				decorated_row.get(
					"target_home_country",
					""
				)
			)
		)
	)

	var target_available: bool = bool(
		access_contract.get(
			"allowed",
			true
		)
	)
	var unavailable_reason: String = str(
		access_contract.get(
			"reason",
			""
		)
	).strip_edges()

	decorated_row [
		"physical_target_access_contract"
	] = access_contract
	decorated_row [
		"physical_target_available"
	] = target_available
	decorated_row [
		"target_unavailable_reason"
	] = unavailable_reason
	decorated_row [
		"physical_crime_same_nation_required"
	] = true

	var base_subtitle: String = str(
		decorated_row.get(
			"base_subtitle",
			decorated_row.get(
				"subtitle",
				""
			)
		)
	).strip_edges()

	decorated_row [
		"base_subtitle"
	] = base_subtitle

	if target_available:
		decorated_row [
			"subtitle"
		] = base_subtitle
	else:
		decorated_row [
			"subtitle"
		] = (
			(
				base_subtitle + "\n"
				if base_subtitle != ""
				else ""
			)
			+ "NOT AVAILABLE • Lives in another nation."
		)

	var decorated_actions: Array = []

	for raw_action in _safe_array(
		decorated_row.get(
			"actions",
			[]
		)
	):
		if typeof(raw_action) != TYPE_DICTIONARY:
			continue

		var action: Dictionary = (
			(raw_action as Dictionary).duplicate(
				false
			)
		)

		if (
			str(
				action.get(
					"id",
					""
				)
			).strip_edges().to_lower()
			== "choose_weapon_target"
		):
			action [
				"enabled"
			] = target_available
			action [
				"disabled_reason"
			] = unavailable_reason
			action [
				"physical_target_access_contract"
			] = access_contract

		decorated_actions.append(
			action
		)

	decorated_row [
		"actions"
	] = decorated_actions




	if not target_available:
		decorated_row [
			"body_surface_contract"
		] = {}

	return decorated_row
func _resident_actor_by_id(
	actor_id: int
) -> Person:
	if (
		gs == null
		or actor_id <= 0
	):
		return null

	if (
		gs.player != null
		and int(
			gs.player.id
		) == actor_id
	):
		return gs.player

	if gs.has_method(
		"get_npc_by_id"
	):



		var found: Variant = gs.get_npc_by_id(
			actor_id,
			false
		)

		if found is Person:
			return found as Person

	return null
func set_contract(contract: Dictionary = {}) -> Dictionary:
	if typeof(contract) == TYPE_DICTIONARY and not contract.is_empty():
		active_contract = _merge_dict(_build_default_contract(), contract)
	else:
		active_contract = _build_default_contract()

	last_report = {
		"schema": "eralife.crime_contract_set_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"contract_id": str(active_contract.get("id", "eralife_default_crime_justice_contract")),
		"set_at_ms": int(Time.get_ticks_msec())
	}
	return last_report.duplicate(true)

func export_state() -> Dictionary:
	return _make_binary_safe({
		"schema": "eralife.crime_contract_engine_state",
		"version": CONTRACT_VERSION,
		"active_contract": active_contract.duplicate(true),
		"ledger": ledger.duplicate(true),
		"crime_target_offense_matrix": (
			crime_target_offense_matrix.duplicate(true)
		),
		"last_report": last_report.duplicate(true),
		"exported_at_ms": int(
			Time.get_ticks_msec()
		)
	})

func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		active_contract = _build_default_contract()
		crime_target_offense_matrix = {}

		return {
			"success": false,
			"reason": (
				"CrimeContractEngine import data must be a Dictionary."
			)
		}

	var contract_raw: Variant = data.get(
		"active_contract",
		{}
	)

	if typeof(contract_raw) == TYPE_DICTIONARY:
		active_contract = _merge_dict(
			_build_default_contract(),
			contract_raw as Dictionary
		)
	else:
		active_contract = _build_default_contract()

	var ledger_raw: Variant = data.get(
		"ledger",
		[]
	)

	ledger = (
		ledger_raw.duplicate(true)
		if typeof(ledger_raw) == TYPE_ARRAY
		else []
	)

	var offense_matrix_raw: Variant = data.get(
		"crime_target_offense_matrix",
		{}
	)

	crime_target_offense_matrix = (
		(offense_matrix_raw as Dictionary).duplicate(true)
		if typeof(offense_matrix_raw) == TYPE_DICTIONARY
		else {}
	)





	if crime_target_offense_matrix.is_empty():
		for raw_ledger_row in ledger:
			if typeof(raw_ledger_row) != TYPE_DICTIONARY:
				continue

			var ledger_row: Dictionary = (
				raw_ledger_row as Dictionary
			)

			if not bool(
				ledger_row.get(
					"success",
					false
				)
			):
				continue

			var offender_id: int = int(
				ledger_row.get(
					"actor_id",
					-1
				)
			)
			var victim_id: int = int(
				ledger_row.get(
					"target_id",
					-1
				)
			)

			if (
				offender_id <= 0
				or victim_id <= 0
			):
				continue

			_increment_crime_target_offense_count(
				offender_id,
				victim_id,
				1
			)

	last_report = {
		"schema": "eralife.crime_contract_import_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"imported_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	return last_report.duplicate(true)
func legal_system_for_era(era_name: String = "") -> String:
	var clean: String = str(era_name).strip_edges()
	if clean == "" and gs != null and gs.era != null:
		clean = str(gs.era.name)

	match clean:
		"Ancient Era":
			return "ancient_imperial"
		"Medieval Era":
			return "medieval_feudal"
		"Industrial Era":
			return "industrial_court"
		"Future Era":
			return "future_tribunal"
		_:
			return "modern_democracy"

func get_legal_system(system_id: String = "") -> Dictionary:
	var legal_systems_raw: Variant = active_contract.get("legal_systems", {})
	var legal_systems: Dictionary = legal_systems_raw if typeof(legal_systems_raw) == TYPE_DICTIONARY else {}
	var clean: String = str(system_id).strip_edges()
	if clean == "":
		clean = legal_system_for_era("")
	var raw: Variant = legal_systems.get(clean, legal_systems.get("modern_democracy", {}))
	return raw.duplicate(true) if typeof(raw) == TYPE_DICTIONARY else {}

func get_case_lifecycle() -> Dictionary:
	var raw: Variant = active_contract.get("case_lifecycle", {})
	return raw.duplicate(true) if typeof(raw) == TYPE_DICTIONARY else {}

func validate_transition(from_status: String, to_status: String) -> Dictionary:
	var lifecycle: Dictionary = get_case_lifecycle()
	var transitions_raw: Variant = lifecycle.get("valid_transitions", {})
	var transitions: Dictionary = transitions_raw if typeof(transitions_raw) == TYPE_DICTIONARY else {}

	var from_clean: String = str(from_status).strip_edges()
	var to_clean: String = str(to_status).strip_edges()

	if from_clean == to_clean:
		return { "valid": true, "from": from_clean, "to": to_clean, "noop": true}

	var allowed_raw: Variant = transitions.get(from_clean, [])
	var allowed: Array = allowed_raw if typeof(allowed_raw) == TYPE_ARRAY else []
	var valid: bool = to_clean in allowed

	return {
		"valid": valid,
		"from": from_clean,
		"to": to_clean,
		"allowed": allowed.duplicate(),
		"reason": "" if valid else "Invalid case transition: %s -> %s." % [from_clean, to_clean]
	}
func resolve_intent(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _failure(
			"missing_actor",
			"Crime intent requires an actor."
		)

	var action_id: String = str(
		payload.get(
			"action_id",
			"open_hub"
		)
	).strip_edges().to_lower()

	match action_id:
		"begin_weapon_action":
			return begin_weapon_action(
				actor,
				payload
			)

		"choose_weapon_target":
			return choose_weapon_target(
				actor,
				payload
			)

		"commit_weapon_action":
			return commit_weapon_action(
				actor,
				payload
			)

		"commit_targeted_crime_action":
			return _commit_targeted_crime_action(
				actor,
				payload
			)

		"commit_bank_robbery":
			return _commit_bank_robbery(
				actor,
				payload
			)

		_:
			return _failure(
				"unsupported_crime_contract_intent",
				(
					"CrimeContractEngine does not support "
					+ "the intent '%s'."
				) % action_id
			)
func _commit_targeted_crime_action(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	if not can_actor_access_crime_hub(
		actor
	):
		return _failure(
			"crime_hub_access_unavailable",
			"Crime Hub access is unavailable."
		)

	if (
		gs == null
		or gs.relationship_activities_engine == null
	):
		return _failure(
			"relationship_activities_engine_unavailable",
			"Targeted crime authority is unavailable."
		)

	var target_id: int = int(
		payload.get(
			"target_id",
			-1
		)
	)

	var target: Person = _resident_actor_by_id(
		target_id
	)

	if target == null:
		return _failure(
			"crime_target_unavailable",
			"The selected target is no longer resident."
		)

	if int(target.id) == int(actor.id):
		return _failure(
			"self_target_not_supported",
			"This crime action cannot target its actor."
		)

	var custody_access: Dictionary = (
		_incarceration_target_access_contract(
			actor,
			int(
				target.id
			)
		)
	)

	if (
		bool(
			custody_access.get(
				"incarcerated",
				false
			)
		)
		and not bool(
			custody_access.get(
				"allowed",
				false
			)
		)
	):
		return _failure(
			"crime_target_outside_custody_reality",
			"The selected person is not resident in this facility."
		)

	var crime_action_id: String = str(
		payload.get(
			"crime_action_id",
			""
		)
	).strip_edges().to_lower()

	var method_id: String = str(
		payload.get(
			"crime_method_id",
			payload.get(
				"method_id",
				""
			)
		)
	).strip_edges().to_lower()

	var relationship_crime_id: String = ""

	match crime_action_id:
		"assault":
			relationship_crime_id = "attack"

		"murder":
			match method_id:
				"poison":
					relationship_crime_id = "poison"

				"direct_attack", "attack":
					relationship_crime_id = "attack"

				_:
					return _failure(
						"murder_method_unavailable",
						(
							"The selected murder method "
							+ "is not available."
						)
					)

		_:
			return _failure(
				"targeted_crime_action_unavailable",
				(
					"The selected crime action cannot "
					+ "use a person target."
				)
			)

	if targeted_crime_requires_same_nation(
		crime_action_id,
		method_id
	):
		var physical_access: Dictionary = (
			physical_crime_target_access_contract(
				actor,
				int(
					target.realm_id
				),
				str(
					target.home_country
				)
			)
		)

		if not bool(
			physical_access.get(
				"allowed",
				false
			)
		):
			return _failure(
				"crime_target_different_nation",
				str(
					physical_access.get(
						"reason",
						(
							"Not available: this person "
							+ "lives in another nation."
						)
					)
				)
			)

	var result_raw: Variant = (
		gs.relationship_activities_engine
		.crime_on_person(
			target,
			relationship_crime_id
		)
	)

	var result: Dictionary = (
		result_raw as Dictionary
		if typeof(result_raw) == TYPE_DICTIONARY
		else {}
	)

	var crime_succeeded: bool = (
		bool(
			result.get(
				"success",
				false
			)
		)
		or str(
			result.get(
				"result",
				""
			)
		).strip_edges().to_lower() == "success"
	)

	return {
		"success": true,
		"mode": "targeted_crime_action_committed",
		"actor_id": int(
			actor.id
		),
		"target_id": int(
			target.id
		),
		"crime_action_id": crime_action_id,
		"crime_method_id": method_id,
		"crime_engine_action_id": (
			relationship_crime_id
		),
		"crime_succeeded": crime_succeeded,
		"text": str(
			result.get(
				"text",
				"Crime action resolved."
			)
		),
		"popup_title": str(
			result.get(
				"popup_title",
				"Crime"
			)
		),
		"popup_text": str(
			result.get(
				"popup_text",
				result.get(
					"text",
					"Crime action resolved."
				)
			)
		),
		"popup_footer": str(
			result.get(
				"popup_footer",
				"Tap anywhere to continue."
			)
		),
		"result": result,
		"physical_target_access_revalidated": true,
		"population_scan_performed": false,
		"ui_is_renderer_only": false
	}


func _commit_bank_robbery(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	if not can_actor_access_crime_hub(
		actor
	):
		return _failure(
			"crime_hub_access_unavailable",
			"Crime Hub access is unavailable."
		)

	if (
		gs == null
		or gs.crime_engine == null
	):
		return _failure(
			"crime_engine_unavailable",
			"CrimeEngine is unavailable."
		)

	var weapon_name: String = str(
		payload.get(
			"weapon_name",
			""
		)
	).strip_edges()

	if weapon_name == "":
		var source_item: Dictionary = _safe_dictionary(
			payload.get(
				"source_item",
				{}
			)
		)

		weapon_name = str(
			source_item.get(
				"name",
				source_item.get(
					"display_name",
					""
				)
			)
		).strip_edges()

	if weapon_name == "":
		return _failure(
			"bank_robbery_weapon_missing",
			"Choose an owned weapon before attempting the bank robbery."
		)

	var result_raw: Variant = (
		gs.crime_engine.commit_crime(
			"Bank Robbery",
			weapon_name
		)
	)
	var result: Dictionary = (
		result_raw as Dictionary
		if typeof(result_raw) == TYPE_DICTIONARY
		else {}
	)

	var crime_succeeded: bool = (
		str(
			result.get(
				"result",
				""
			)
		).strip_edges().to_lower() == "success"
	)

	return {
		"success": true,
		"mode": "bank_robbery_committed",
		"actor_id": int(
			actor.id
		),
		"weapon_name": weapon_name,
		"crime_succeeded": crime_succeeded,
		"text": str(
			result.get(
				"text",
				"Bank robbery attempt resolved."
			)
		),
		"popup_title": str(
			result.get(
				"popup_title",
				"Bank Robbery"
			)
		),
		"popup_text": str(
			result.get(
				"popup_text",
				result.get(
					"text",
					"Bank robbery attempt resolved."
				)
			)
		),
		"popup_footer": str(
			result.get(
				"popup_footer",
				"Tap anywhere to continue."
			)
		),
		"result": result,
		"ui_is_renderer_only": false
	}

func can_actor_access_crime_hub(
	actor: Person
) -> bool:




	return (
		actor != null
		and bool(
			actor.alive
		)
	)


func begin_weapon_action(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	if not can_actor_access_crime_hub(
		actor
	):
		return _failure(
			"crime_hub_access_unavailable",
			"This actor cannot currently open the Crime Hub."
		)

	var source_item: Dictionary = _safe_dictionary(
		payload.get(
			"source_item",
			{}
		)
	)

	var weapon_name: String = str(
		payload.get(
			"weapon_name",
			source_item.get(
				"name",
				source_item.get(
					"display_name",
					""
				)
			)
		)
	).strip_edges()

	var weapon_action_id: String = str(
		payload.get(
			"weapon_action_id",
			payload.get(
				"selected_weapon_action_id",
				""
			)
		)
	).strip_edges().to_lower()

	if weapon_name == "":
		return _failure(
			"missing_weapon_name",
			"No weapon was supplied."
		)







	var weapon_contract: Dictionary = _safe_dictionary(
		payload.get(
			"weapon_contract",
			{}
		)
	)

	if weapon_contract.is_empty():
		weapon_contract = _safe_dictionary(
			source_item.get(
				"weapon_contract",
				{}
			)
		)






	if weapon_contract.is_empty():
		if (
			gs == null
			or gs.weapons_engine == null
		):
			return _failure(
				"weapons_engine_unavailable",
				"WeaponsEngine is unavailable."
			)

		weapon_contract = (
			gs.weapons_engine
			.get_weapon_action_contract(
				weapon_name,
				str(
					source_item.get(
						"origin_era",
						""
					)
				)
			)
		)

	if weapon_contract.is_empty():
		return _failure(
			"weapon_contract_unavailable",
			(
				"No runtime weapon contract exists for %s."
				% weapon_name
			)
		)

	var action_contract: Dictionary = (
		_weapon_action_from_contract(
			weapon_contract,
			weapon_action_id
		)
	)

	if action_contract.is_empty():
		return _failure(
			"weapon_action_unavailable",
			(
				"The selected action is unavailable for %s."
				% weapon_name
			)
		)

	var shared_payload: Dictionary = {
		"source_item": source_item,
		"weapon_contract": weapon_contract,
		"weapon_action": action_contract,
		"weapon_name": weapon_name,
		"weapon_action_id": str(
			action_contract.get(
				"id",
				weapon_action_id
			)
		),
		"immutable_contract_references": true
	}





	var target_contract: Dictionary = (
		_crime_target_rows(
			actor,
			0,
			0,
			shared_payload
		)
	)

	var target_rows: Array = []

	for raw_target_row in _safe_array(
		target_contract.get(
			"rows",
			[]
		)
	):
		var target_row: Dictionary = (
			_safe_dictionary(
				raw_target_row
			).duplicate(
				false
			)
		)

		if target_row.is_empty():
			continue

		var target_id: int = int(
			target_row.get(
				"target_id",
				-1
			)
		)

		if target_id <= 0:
			continue



		target_row [
			"actions"
		] = [
			{
				"id": "choose_weapon_target",
				"label": "Select Target",
				"enabled": true,
				"payload": {
					"action_id": "choose_weapon_target",
					"target_id": target_id
				}
			}
		]

		target_row [
			"body_surface_contract"
		] = _weapon_body_surface_contract(
			target_id,
			str(
				target_row.get(
					"label",
					"Target"
				)
			),
			source_item,
			weapon_contract,
			action_contract
		)

		target_row = (
			decorate_weapon_target_row_for_physical_access(
				actor,
				target_row
			)
		)

		target_rows.append(
			target_row
		)

	if target_rows.is_empty():
		target_rows.append({
			"kind": "crime_target_stream_status",
			"label": "Targets are streaming into this reality…",
			"subtitle": (
				"CrimeTarget residency is still publishing. "
				+ "The UI remains fully interactive."
			),
			"actions": []
		})

	return {
		"success": true,
		"mode": "crime_weapon_target_selection",
		"open_crime_hub": true,
		"crime_hub_section": "targets",
		"interaction_contract": {
			"schema": "eralife.crime_weapon_interaction_contract",
			"version": CONTRACT_VERSION,
			"stage": "choose_target",
			"actor_id": int(
				actor.id
			),
			"title": (
				"%s — Choose a target"
				% str(
					action_contract.get(
						"label",
						"Weapon Action"
					)
				)
			),
			"subtitle": (
				"%s is ready. Select who this action "
				+ "will be directed toward."
			) % weapon_name,
			"weapon_name": weapon_name,
			"weapon_contract": weapon_contract,
			"weapon_action": action_contract,
			"source_item": source_item,
			"shared_payload": shared_payload,
			"rows": target_rows,
			"target_projection_complete": bool(
				target_contract.get(
					"complete",
					false
				)
			),
			"target_projection_pending": bool(
				target_contract.get(
					"target_projection_pending",
					false
				)
			),
			"relationship_target_count": int(
				target_contract.get(
					"relationship_target_count",
					0
				)
			),
			"random_stranger_count": int(
				target_contract.get(
					"random_stranger_count",
					0
				)
			),
			"target_policy": (
				"relationships_plus_two_random_unrelated_strangers"
			),
			"target_access_policy": (
				"same_nation_required_for_physical_crime"
			),
			"acquaintances_excluded": true,
			"ui_is_renderer_only": true
		}
	}
func _weapon_body_surface_contract(
	target_id: int,
	target_name: String,
	source_item: Dictionary,
	weapon_contract: Dictionary,
	action_contract: Dictionary
) -> Dictionary:
	var body_rows: Array = []

	for raw_body_part in _safe_array(
		action_contract.get(
			"body_parts",
			[]
		)
	):
		var body_part: String = str(
			raw_body_part
		).strip_edges().to_lower()

		if body_part == "":
			continue

		body_rows.append({
			"kind": "crime_body_target",
			"label": body_part.capitalize(),
			"body_part": body_part,
			"target_id": target_id,
			"actions": [
				{
					"id": "commit_weapon_action",
					"label": (
						"Target %s"
						% body_part.capitalize()
					),
					"payload": {
						"action_id": (
							"commit_weapon_action"
						),
						"target_id": target_id,
						"body_part": body_part,
						"source_item": source_item,
						"weapon_contract": (
							weapon_contract
						),
						"weapon_action": (
							action_contract
						),
						"weapon_name": str(
							weapon_contract.get(
								"weapon_name",
								source_item.get(
									"name",
									""
								)
							)
						),
						"weapon_action_id": str(
							action_contract.get(
								"id",
								""
							)
						),
						"immutable_contract_references": true
					}
				}
			]
		})

	return {
		"schema": (
			"eralife.crime_weapon_body_surface_contract"
		),
		"version": CONTRACT_VERSION,
		"stage": "choose_body_part",
		"target_id": target_id,
		"target_name": target_name,
		"title": "Choose where to target",
		"subtitle": (
			"%s • %s • %s"
			% [
				target_name,
				str(
					weapon_contract.get(
						"weapon_name",
						"Weapon"
					)
				),
				str(
					action_contract.get(
						"label",
						"Action"
					)
				)
			]
		),
		"rows": body_rows,
		"immutable_contract_references": true,
		"ui_is_renderer_only": true
	}
func choose_weapon_target(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	if not can_actor_access_crime_hub(
		actor
	):
		return _failure(
			"crime_hub_access_unavailable",
			"Crime Hub access is unavailable."
		)

	var target_id: int = int(
		payload.get(
			"target_id",
			-1
		)
	)

	var target: Person = _resident_actor_by_id(
		target_id
	)

	if target == null:
		return _failure(
			"weapon_target_unavailable",
			"The selected target is unavailable."
		)

	if int(
		target.id
	) == int(
		actor.id
	):
		return _failure(
			"self_target_not_supported",
			"This crime action cannot target its actor."
		)

	var custody_access: Dictionary = (
		_incarceration_target_access_contract(
			actor,
			int(
				target.id
			)
		)
	)

	if (
		bool(
			custody_access.get(
				"incarcerated",
				false
			)
		)
		and not bool(
			custody_access.get(
				"allowed",
				false
			)
		)
	):
		return _failure(
			"crime_target_outside_custody_reality",
			"The selected person is not resident in this facility."
		)

	var physical_access: Dictionary = (
		physical_crime_target_access_contract(
			actor,
			int(
				target.realm_id
			),
			str(
				target.home_country
			)
		)
	)

	if not bool(
		physical_access.get(
			"allowed",
			false
		)
	):
		return _failure(
			"crime_target_different_nation",
			str(
				physical_access.get(
					"reason",
					(
						"Not available: this person "
						+ "lives in another nation."
					)
				)
			)
		)

	var source_item: Dictionary = _safe_dictionary(
		payload.get(
			"source_item",
			{}
		)
	)
	var weapon_contract: Dictionary = _safe_dictionary(
		payload.get(
			"weapon_contract",
			{}
		)
	)
	var action_contract: Dictionary = _safe_dictionary(
		payload.get(
			"weapon_action",
			{}
		)
	)

	if weapon_contract.is_empty():
		var weapon_name: String = str(
			payload.get(
				"weapon_name",
				source_item.get(
					"name",
					""
				)
			)
		).strip_edges()

		if (
			gs != null
			and gs.weapons_engine != null
		):
			weapon_contract = (
				gs.weapons_engine
				.get_weapon_action_contract(
					weapon_name,
					str(
						source_item.get(
							"origin_era",
							""
						)
					)
				)
			)

	if action_contract.is_empty():
		action_contract = _weapon_action_from_contract(
			weapon_contract,
			str(
				payload.get(
					"weapon_action_id",
					""
				)
			)
		)

	if action_contract.is_empty():
		return _failure(
			"weapon_action_unavailable",
			"The selected weapon action is unavailable."
		)

	var body_surface: Dictionary = (
		_weapon_body_surface_contract(
			target_id,
			_actor_display_name(
				target
			),
			source_item,
			weapon_contract,
			action_contract
		)
	)

	body_surface [
		"physical_target_access_contract"
	] = physical_access

	return {
		"success": true,
		"mode": "crime_weapon_body_selection",
		"open_crime_hub": true,
		"crime_hub_section": "targets",
		"interaction_contract": (
			body_surface
		),
		"ui_is_renderer_only": true
	}
func _incarceration_target_access_contract(
		actor: Person,
		target_id: int
) -> Dictionary:
	if (
		actor == null
		or gs == null
		or target_id <= 0
	):
		return {
			"incarcerated": false,
			"allowed": true
		}

	var actor_id: int = int(
		actor.id
	)

	for authority in [
		gs.prison_engine,
		gs.jail_engine
	]:
		if (
			authority == null
			or not authority.has_method(
				"resident_target_access_contract"
			)
		):
			continue

		var access: Dictionary = _safe_dictionary(
			authority.call(
				"resident_target_access_contract",
				actor_id,
				target_id
			)
		)

		if bool(
			access.get(
				"incarcerated",
				false
			)
		):
			return access

	return {
		"incarcerated": false,
		"allowed": true
	}
func commit_weapon_action(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	if not can_actor_access_crime_hub(
		actor
	):
		return _failure(
			"crime_hub_access_unavailable",
			"Crime Hub access is unavailable."
		)

	if (
		gs == null
		or gs.crime_engine == null
	):
		return _failure(
			"crime_engine_unavailable",
			"CrimeEngine is unavailable."
		)

	var target_id: int = int(
		payload.get(
			"target_id",
			-1
		)
	)
	var body_part: String = str(
		payload.get(
			"body_part",
			""
		)
	).strip_edges().to_lower()
	var weapon_raw: Variant = payload.get(
		"weapon_contract",
		{}
	)
	var weapon_contract: Dictionary = (
		weapon_raw as Dictionary
		if typeof(
			weapon_raw
		) == TYPE_DICTIONARY
		else {}
	)
	var action_raw: Variant = payload.get(
		"weapon_action",
		{}
	)
	var action_contract: Dictionary = (
		action_raw as Dictionary
		if typeof(
			action_raw
		) == TYPE_DICTIONARY
		else {}
	)

	if target_id <= 0:
		return _failure(
			"missing_weapon_target",
			"No target was supplied."
		)

	var target: Person = _resident_actor_by_id(
		target_id
	)

	if target == null:
		return _failure(
			"weapon_target_unavailable",
			"The selected target is no longer resident."
		)

	if int(target.id) == int(actor.id):
		return _failure(
			"self_target_not_supported",
			"This crime action cannot target its actor."
		)

	var custody_access: Dictionary = (
		_incarceration_target_access_contract(
			actor,
			target_id
		)
	)

	if (
		bool(
			custody_access.get(
				"incarcerated",
				false
			)
		)
		and not bool(
			custody_access.get(
				"allowed",
				false
			)
		)
	):
		return _failure(
			"crime_target_outside_custody_reality",
			"The selected person is not resident in this facility."
		)

	var physical_access: Dictionary = (
		physical_crime_target_access_contract(
			actor,
			int(
				target.realm_id
			),
			str(
				target.home_country
			)
		)
	)

	if not bool(
		physical_access.get(
			"allowed",
			false
		)
	):
		return _failure(
			"crime_target_different_nation",
			str(
				physical_access.get(
					"reason",
					(
						"Not available: this person "
						+ "lives in another nation."
					)
				)
			)
		)

	if body_part == "":
		return _failure(
			"missing_body_target",
			"No body area was supplied."
		)

	if (
		weapon_contract.is_empty()
		or action_contract.is_empty()
	):
		return _failure(
			"missing_weapon_runtime_contract",
			"The weapon runtime contract is incomplete."
		)

	var body_parts_raw: Variant = action_contract.get(
		"body_parts",
		[]
	)
	var valid_body_parts: Array = (
		body_parts_raw as Array
		if typeof(
			body_parts_raw
		) == TYPE_ARRAY
		else []
	)

	if body_part not in valid_body_parts:
		return _failure(
			"body_target_not_supported",
			(
				"%s cannot target %s through this action."
				% [
					str(
						action_contract.get(
							"label",
							"This action"
						)
					),
					body_part
				]
			)
		)

	var commit_payload: Dictionary = (
		payload.duplicate(false)
	)
	commit_payload ["actor_id"] = int(
		actor.id
	)
	commit_payload ["source"] = str(
		payload.get(
			"source",
			"crime_contract_engine"
		)
	)
	commit_payload [
		"contract_validated"
	] = true
	commit_payload [
		"immutable_contract_references"
	] = true
	commit_payload [
		"physical_target_access_contract"
	] = physical_access
	commit_payload [
		"physical_target_access_revalidated"
	] = true

	var report: Dictionary = (
		gs.crime_engine
		.resolve_weapon_crime_action(
			actor,
			commit_payload
		)
	)

	if bool(
		report.get(
			"success",
			false
		)
	):
		var pending_raw: Variant = report.get(
			"pending_contract_report",
			{}
		)
		var pending_report: Dictionary = (
			pending_raw as Dictionary
			if typeof(
				pending_raw
			) == TYPE_DICTIONARY
			else {}
		)
		var case_raw: Variant = report.get(
			"case_report",
			{}
		)
		var case_report: Dictionary = (
			case_raw as Dictionary
			if typeof(
				case_raw
			) == TYPE_DICTIONARY
			else {}
		)
		var event_raw: Variant = report.get(
			"crime_event",
			{}
		)
		var crime_event: Dictionary = (
			event_raw as Dictionary
			if typeof(
				event_raw
			) == TYPE_DICTIONARY
			else {}
		)
		var discovered: bool = bool(
			report.get(
				"discovered",
				false
			)
		)

		if (
			not bool(
				pending_report.get(
					"success",
					false
				)
			)
			and not case_report.is_empty()
			and not crime_event.is_empty()
			and gs.pending_situations_engine != null
		):
			if discovered:
				pending_report = (
					gs.pending_situations_engine
					.emit_crime_response_contract(
						actor,
						crime_event,
						case_report,
						{
							"response_window_ms": 75000,
							"source": (
								"crime_contract_engine.pending_repair"
							)
						}
					)
				)
			elif gs.pending_situations_engine.has_method(
				"emit_crime_aftermath_contract"
			):
				pending_report = (
					gs.pending_situations_engine
					.emit_crime_aftermath_contract(
						actor,
						crime_event,
						case_report,
						{
							"source": (
								"crime_contract_engine.undiscovered_aftermath"
							)
						}
					)
				)

			report [
				"pending_contract_report"
			] = pending_report
			report [
				"pending_contract_repaired"
			] = bool(
				pending_report.get(
					"success",
					false
				)
			)

	ledger.append({
		"mode": "weapon_crime_action_committed",
		"actor_id": int(
			actor.id
		),
		"target_id": target_id,
		"weapon_name": str(
			weapon_contract.get(
				"weapon_name",
				""
			)
		),
		"weapon_action_id": str(
			action_contract.get(
				"id",
				""
			)
		),
		"body_part": body_part,
		"success": bool(
			report.get(
				"success",
				false
			)
		),
		"pending_contract_success": bool(
			(
				report.get(
					"pending_contract_report",
					{}
				) as Dictionary
			).get(
				"success",
				false
			)
			if typeof(
				report.get(
					"pending_contract_report",
					{}
				)
			) == TYPE_DICTIONARY
			else false
		),
		"physical_target_access_revalidated": true,
		"committed_at_ms": int(
			Time.get_ticks_msec()
		)
	})

	if ledger.size() > 240:
		ledger = ledger.slice(
			ledger.size() - 240,
			ledger.size()
		)

	return report

func _crime_target_rows(
	actor: Person,
	_cursor: int = 0,
	_limit: int = 28,
	_shared_payload: Dictionary = {}
) -> Dictionary:
	if (
		gs == null
		or actor == null
	):
		return {
			"rows": [],
			"next_cursor": 0,
			"complete": true,
			"scanned": 0
		}

	var actor_id: int = int(
		actor.id
	)
	var actor_key: String = str(
		actor_id
	)



	var resident_raw: Variant = (
		crime_target_identity_cache_by_actor.get(
			actor_id,
			{}
		)
	)
	var resident_contract: Dictionary = (
		resident_raw as Dictionary
		if typeof(resident_raw) == TYPE_DICTIONARY
		else {}
	)

	var rows_raw: Variant = resident_contract.get(
		"rows",
		[]
	)
	var rows: Array = (
		rows_raw as Array
		if typeof(rows_raw) == TYPE_ARRAY
		else []
	)

	var complete: bool = bool(
		resident_contract.get(
			"complete",
			false
		)
	)




	if not _shared_payload.is_empty():
		var published_target_ids: Dictionary = {}

		for raw_row in rows:
			var row: Dictionary = (
				raw_row as Dictionary
				if typeof(raw_row) == TYPE_DICTIONARY
				else {}
			)
			var target_id: int = int(
				row.get(
					"target_id",
					-1
				)
			)

			if target_id <= 0:
				continue

			published_target_ids [
				str(target_id)
			] = true

		active_weapon_target_stream_by_actor [
			actor_key
		] = {
			"actor_id": actor_id,
			"shared_payload": (
				_shared_payload.duplicate(false)
			),
			"published_target_ids": (
				published_target_ids
			),
			"initial_target_count": rows.size(),
			"initial_projection_complete": complete,
			"started_at_ms": int(
				Time.get_ticks_msec()
			),
			"ui_is_renderer_only": true
		}






	return {
		"rows": rows,
		"next_cursor": rows.size(),
		"complete": complete,
		"scanned": 0,
		"population_scan_performed": false,
		"relationship_target_count": int(
			resident_contract.get(
				"relationship_target_count",
				0
			)
		),
		"random_stranger_count": int(
			resident_contract.get(
				"random_stranger_count",
				0
			)
		),
		"target_policy": (
			"meaningful_relationships_plus_two_unrelated_strangers"
		),
		"acquaintances_excluded": true,
		"target_projection_pending": (
			not complete
		),
		"signature": str(
			resident_contract.get(
				"signature",
				""
			)
		)
	}
func _weapon_action_from_contract(
	weapon_contract: Dictionary,
	action_id: String
) -> Dictionary:
	var clean_action_id: String = str(
		action_id
	).strip_edges().to_lower()

	for raw_action in _safe_array(
		weapon_contract.get(
			"actions",
			[]
		)
	):
		if typeof(
			raw_action
		) != TYPE_DICTIONARY:
			continue

		var action: Dictionary = (
			raw_action as Dictionary
		)

		if str(
			action.get(
				"id",
				""
			)
		).strip_edges().to_lower() == clean_action_id:
			return action.duplicate(true)

	return {}


func _actor_by_id(
	actor_id: int
) -> Person:
	if (
		gs == null
		or actor_id <= 0
	):
		return null

	if (
		gs.player != null
		and int(
			gs.player.id
		) == actor_id
	):
		return gs.player

	if gs.has_method(
		"get_npc_by_id"
	):
		var found = gs.get_npc_by_id(
			actor_id
		)

		if found is Person:
			return found as Person

	if gs.has_method(
		"get_or_reactivate_npc_by_id"
	):
		var restored = (
			gs.get_or_reactivate_npc_by_id(
				actor_id
			)
		)

		if restored is Person:
			return restored as Person

	return null


func _actor_display_name(
	actor: Person
) -> String:
	if actor == null:
		return "Unknown Person"

	var full_name: String = (
		"%s %s"
		% [
			str(
				actor.first_name
			),
			str(
				actor.last_name
			)
		]
	).strip_edges()

	if full_name == "":
		return "Person %d" % int(
			actor.id
		)

	return full_name


func _failure(
	reason: String,
	message: String
) -> Dictionary:
	EraLog.failure(
		get_script().resource_path.get_file(),
		str(reason)
	)
	return {
		"success": false,
		"reason": reason,
		"text": message,
		"popup_title": "Crime Contract",
		"popup_text": message,
		"popup_footer": "Tap anywhere to continue.",
	}


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)
func normalize_crime_event(
	raw_event: Dictionary = {}
) -> Dictionary:
	var actor_id: int = int(
		raw_event.get(
			"actor_id",
			_player_id()
		)
	)
	var victim_id: int = int(
		raw_event.get(
			"victim_id",
			raw_event.get(
				"target_id",
				-1
			)
		)
	)
	var crime_type: String = str(
		raw_event.get(
			"crime_type",
			raw_event.get(
				"crime_name",
				"unknown"
			)
		)
	).strip_edges()

	if crime_type == "":
		crime_type = "unknown"

	var era_name: String = str(
		raw_event.get(
			"era",
			""
		)
	).strip_edges()

	if (
		era_name == ""
		and gs != null
		and gs.era != null
	):
		era_name = str(
			gs.era.name
		)

	var legal_system: String = str(
		raw_event.get(
			"legal_system",
			legal_system_for_era(
				era_name
			)
		)
	).strip_edges()
	var severity: float = clampf(
		float(
			raw_event.get(
				"severity",
				raw_event.get(
					"danger",
					30
				)
			)
		) / 100.0,
		0.05,
		1.0
	)
	var witness_ids: Array = _safe_array(
		raw_event.get(
			"witness_ids",
			[]
		)
	)
	var target_died: bool = bool(
		raw_event.get(
			"target_died",
			false
		)
	)
	var target_survived: bool = bool(
		raw_event.get(
			"target_survived",
			not target_died
		)
	)
	var weapon_name: String = str(
		raw_event.get(
			"weapon_name",
			""
		)
	).strip_edges()
	var weapon_action_id: String = str(
		raw_event.get(
			"weapon_action_id",
			""
		)
	).strip_edges().to_lower()
	var body_part: String = str(
		raw_event.get(
			"body_part",
			""
		)
	).strip_edges().to_lower()

	return {
		"schema": "eralife.crime_event",
		"version": CONTRACT_VERSION,
		"crime_event_id": str(
			raw_event.get(
				"crime_event_id",
				"crime_%d_%d" % [
					actor_id,
					int(
						Time.get_ticks_msec()
					)
				]
			)
		),
		"world_id": str(
			raw_event.get(
				"world_id",
				_resolve_world_id(
					raw_event
				)
			)
		),
		"era": era_name,
		"legal_system": legal_system,
		"participants": {
			"accused": actor_id,
			"victim": victim_id,
			"officer": int(
				raw_event.get(
					"officer_id",
					-1
				)
			),
			"witnesses": witness_ids.duplicate(true)
		},
		"crime": {
			"type": crime_type,
			"name": str(
				raw_event.get(
					"crime_name",
					crime_type
				)
			),
			"severity": severity,
			"intent": str(
				raw_event.get(
					"intent",
					"unknown"
				)
			),
			"timestamp": int(
				raw_event.get(
					"timestamp",
					Time.get_unix_time_from_system()
				)
			),
			"weapon_name": weapon_name,
			"weapon_type": str(
				raw_event.get(
					"weapon_type",
					""
				)
			),
			"weapon_action_id": weapon_action_id,
			"weapon_action_label": str(
				raw_event.get(
					"weapon_action_label",
					weapon_action_id.capitalize()
				)
			),
			"body_part": body_part,
			"harm_amount": int(
				raw_event.get(
					"harm_amount",
					0
				)
			),
			"target_survived": target_survived,
			"target_died": target_died,
			"victim_reported": bool(
				raw_event.get(
					"victim_reported",
					false
				)
			),
			"witness_count": witness_ids.size(),
			"discovered": bool(
				raw_event.get(
					"discovered",
					false
				)
			),
			"success_before_arrest": bool(
				raw_event.get(
					"success_before_arrest",
					false
				)
			),
			"payout": int(
				raw_event.get(
					"payout",
					0
				)
			),
			"base_sentence_years": int(
				raw_event.get(
					"base_sentence_years",
					1
				)
			),
			"violent": bool(
				raw_event.get(
					"violent",
					weapon_name != ""
				)
			),
			"charges": (
				raw_event.get(
					"charges",
					[]
				).duplicate(true)
				if typeof(
					raw_event.get(
						"charges",
						[]
					)
				) == TYPE_ARRAY
				else []
			)
		},
		"attack_contract": {
			"weapon_name": weapon_name,
			"weapon_type": str(
				raw_event.get(
					"weapon_type",
					""
				)
			),
			"weapon_action_id": weapon_action_id,
			"weapon_action_label": str(
				raw_event.get(
					"weapon_action_label",
					weapon_action_id.capitalize()
				)
			),
			"body_part": body_part,
			"harm_amount": int(
				raw_event.get(
					"harm_amount",
					0
				)
			),
			"target_survived": target_survived,
			"target_died": target_died
		},
		"discovery_contract": {
			"victim_reported": bool(
				raw_event.get(
					"victim_reported",
					false
				)
			),
			"witness_ids": witness_ids.duplicate(true),
			"witness_count": witness_ids.size(),
			"discovered": bool(
				raw_event.get(
					"discovered",
					false
				)
			)
		},
		"context": raw_event.duplicate(true),
		"created_at_ms": int(
			Time.get_ticks_msec()
		)
	}

func create_case_object(crime_event: Dictionary, evidence_packet: Dictionary = {}) -> Dictionary:
	var participants_raw: Variant = crime_event.get("participants", {})
	var participants: Dictionary = participants_raw if typeof(participants_raw) == TYPE_DICTIONARY else {}
	var crime_raw: Variant = crime_event.get("crime", {})
	var crime: Dictionary = crime_raw if typeof(crime_raw) == TYPE_DICTIONARY else {}

	var case_id: String = "case_%d_%d" % [int(participants.get("accused", _player_id())), int(Time.get_ticks_msec())]
	var evidence_rows: Array = evidence_packet.get("evidence", []) if typeof(evidence_packet.get("evidence", [])) == TYPE_ARRAY else []

	var case_data:= {
		"schema": "eralife.case_object",
		"version": CONTRACT_VERSION,
		"case_id": case_id,
		"world_id": str(crime_event.get("world_id", _resolve_world_id(crime_event))),
		"era": str(crime_event.get("era", "")),
		"legal_system": str(crime_event.get("legal_system", legal_system_for_era(str(crime_event.get("era", ""))))),
		"participants": {
			"accused": int(participants.get("accused", -1)),
			"victim": int(participants.get("victim", -1)),
			"officer": int(participants.get("officer", -1))
		},
		"crime": crime.duplicate(true),
		"evidence": evidence_rows.duplicate(true),
		"evidence_packet": evidence_packet.duplicate(true),
		"history": [],
		"status": "pending",
		"verdict": null,
		"sentence": {
			"type": null,
			"duration": 0,
			"fine": 0,
			"restitution": 0,
			"flags": []
		},
		"execution_flags": {
			"jail_applied": false,
			"prison_applied": false,
			"economic_applied": false,
		},
		"created_at_ms": int(Time.get_ticks_msec()),
		"updated_at_ms": int(Time.get_ticks_msec())
	}

	return append_history(case_data, "case_created", {
		"crime_event_id": str(crime_event.get("crime_event_id", "")),
		"legal_system": str(case_data.get("legal_system", ""))
	})

func append_history(case_data: Dictionary, event_name: String, payload: Dictionary = {}) -> Dictionary:
	var next_case: Dictionary = case_data.duplicate(true)
	var history_raw: Variant = next_case.get("history", [])
	var history: Array = history_raw if typeof(history_raw) == TYPE_ARRAY else []

	history.append({
		"event_name": str(event_name),
		"payload": payload.duplicate(true),
		"status": str(next_case.get("status", "")),
		"year": int(gs.year) if gs != null and gs.get("year") != null else 0,
		"at_ms": int(Time.get_ticks_msec())
	})

	next_case ["history"] = history
	next_case ["updated_at_ms"] = int(Time.get_ticks_msec())
	return next_case

func _build_default_contract() -> Dictionary:
	return {
		"schema": CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": "eralife_default_crime_justice_contract",
		"case_lifecycle": {
			"valid_transitions": {
				"pending": [
					"investigating",
					"dismissed"
				],
				"investigating": [
					"interrogation",
					"charged",
					"closed"
				],
				"interrogation": [
					"charged",
					"dismissed",
					"escaped",
					"closed"
				],
				"charged": [
					"trial",
					"dismissed"
				],
				"trial": [
					"verdict"
				],
				"verdict": [
					"sentenced",
					"appealed",
					"closed"
				],
				"sentenced": [
					"incarcerated",
					"fined_only",
					"closed"
				],
				"incarcerated": [
					"released",
					"paroled",
					"escaped",
					"executed"
				],
				"fined_only": [
					"closed"
				],
				"appealed": [
					"trial",
					"closed"
				],
				"dismissed": [
					"closed"
				],
				"executed": [
					"closed"
				],
				"released": [
					"closed"
				],
				"paroled": [
					"closed"
				],
				"escaped": [
					"investigating",
					"charged",
					"closed"
				],
				"closed": []
			}
		},
		"legal_systems": {
			"ancient_imperial": {
				"burden_of_proof": 0.35,
				"sentence_multiplier": 1.55,
				"allows_execution": true,
				"allows_bail": false,
				"corruption": 0.58,
				"due_process": 0.12
			},
			"medieval_feudal": {
				"burden_of_proof": 0.42,
				"sentence_multiplier": 1.35,
				"allows_execution": true,
				"allows_bail": false,
				"corruption": 0.52,
				"due_process": 0.18
			},
			"industrial_court": {
				"burden_of_proof": 0.58,
				"sentence_multiplier": 1.1,
				"allows_execution": true,
				"allows_bail": true,
				"corruption": 0.36,
				"due_process": 0.42
			},
			"modern_democracy": {
				"burden_of_proof": 0.68,
				"sentence_multiplier": 1.0,
				"allows_execution": false,
				"allows_bail": true,
				"corruption": 0.24,
				"due_process": 0.68
			},
			"future_tribunal": {
				"burden_of_proof": 0.76,
				"sentence_multiplier": 0.9,
				"allows_execution": false,
				"allows_bail": true,
				"corruption": 0.18,
				"due_process": 0.78
			},
			"corrupt_state": {
				"burden_of_proof": 0.3,
				"sentence_multiplier": 1.75,
				"allows_execution": true,
				"allows_bail": true,
				"corruption": 0.9,
				"due_process": 0.08
			}
		}
	}

func _resolve_world_id(context: Dictionary = {}) -> String:
	var clean: String = str(context.get("world_id", context.get("guild_id", ""))).strip_edges()
	if clean != "":
		return clean
	if gs != null and gs.player != null and gs.player.get("realm_id") != null:
		return "realm:%d" % int(gs.player.realm_id)
	return "local.world"

func _player_id() -> int:
	if gs != null and gs.player != null:
		return int(gs.player.id)
	return -1

func _merge_dict(base: Dictionary, patch: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	for key in patch.keys():
		var patch_value: Variant = patch [key]
		if typeof(patch_value) == TYPE_DICTIONARY and typeof(out.get(key, {})) == TYPE_DICTIONARY:
			out [key] = _merge_dict(out.get(key, {}), patch_value as Dictionary)
		else:
			out [key] = patch_value
	return out

func _make_binary_safe(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var out:= {}
			for key in value.keys():
				out [str(key)] = _make_binary_safe(value [key])
			return out
		TYPE_ARRAY:
			var arr:= []
			for item in value:
				arr.append(_make_binary_safe(item))
			return arr
		TYPE_COLOR:
			var c: Color = value
			return "#%s" % c.to_html(true)
		TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_BOOL:
			return value
		TYPE_NIL:
			return null
		_:
			return str(value)