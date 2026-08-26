extends Resource
class_name CrimeHubContractEngine

const CONTRACT_SCHEMA:= "eralife.crime_hub_contract"
const CONTRACT_VERSION:= 1

signal resident_crime_section_contract_published(
	actor_id: int,
	section_id: String,
	section_contract: Dictionary,
	source: String
)

signal resident_crime_section_row_published(
	actor_id: int,
	section_id: String,
	row_contract: Dictionary,
	source: String
)

signal incarceration_lens_published(
	actor_id: int,
	contract: Dictionary
)

var gs
var last_contract: Dictionary = {}
var last_report: Dictionary = {}
var section_surfaces_by_actor: Dictionary = {}
var selected_crime_action_by_actor: Dictionary = {}
var resident_section_projection_queue: Dictionary = {}
var resident_section_projection_queue_head: int = 0
var resident_section_projection_queue_tail: int = 0
var resident_section_projection_keys: Dictionary = {}
var resident_section_projection_service_active: bool = false

const CRIME_HEAVY_SECTION_ITEM_BUDGET_PER_QUANTUM:= 2
const CRIME_HEAVY_SECTION_WORK_BUDGET_USEC:= 350

var resident_heavy_section_projection_state_by_key: Dictionary = {}
var resident_heavy_section_projection_queue: Dictionary = {}
var resident_heavy_section_projection_queue_head: int = 0
var resident_heavy_section_projection_queue_tail: int = 0
var resident_heavy_section_projection_keys: Dictionary = {}
var resident_heavy_section_projection_service_active: bool = false
var crime_runtime_bootstrap_service_active: bool = false
var crime_runtime_bootstrap_last_state: String = ""
var crime_truth_probe_last_actor_id: int = -1
const CRIME_OBSERVER_REPLAY_ROW_BUDGET_PER_QUANTUM:= 2
const CRIME_OBSERVER_REPLAY_WORK_BUDGET_USEC:= 250

var resident_observer_replay_state_by_key: Dictionary = {}
var resident_observer_replay_queue: Dictionary = {}
var resident_observer_replay_queue_head: int = 0
var resident_observer_replay_queue_tail: int = 0
var resident_observer_replay_keys: Dictionary = {}
var resident_observer_replay_service_active: bool = false

var crime_event_bus_bound: bool = false
var crime_observation_bus_publish_seq: int = 0
var resident_target_identity_contract_by_actor: Dictionary = {}






var crime_resident_actor_probe_active: bool = false
var crime_resident_actor_probe_last_actor_id: int = -1
func _init(
	_game_state = null
) -> void:
	gs = _game_state



	_arm_crime_runtime_bootstrap_service()
func _crime_hub_truth_probe(
	stage: String,
	fields: Dictionary = {}
) -> void:
	if not OS.is_debug_build():
		return

	var parts:= PackedStringArray([
		"ERALIFE_CRIME_PIPELINE_TRUTH",
		"authority=CrimeHubContractEngine",
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


func _bind_crime_hub_truth_probe() -> void:
	if not OS.is_debug_build():
		return

	var contract_callback:= Callable(
		self,
		"_on_crime_hub_truth_probe_section_contract_emitted"
	)

	if not is_connected(
		"resident_crime_section_contract_published",
		contract_callback
	):
		connect(
			"resident_crime_section_contract_published",
			contract_callback
		)

	var row_callback:= Callable(
		self,
		"_on_crime_hub_truth_probe_section_row_emitted"
	)

	if not is_connected(
		"resident_crime_section_row_published",
		row_callback
	):
		connect(
			"resident_crime_section_row_published",
			row_callback
		)

	if (
		gs != null
		and gs.event_bus != null
	):
		gs.event_bus.subscribe(
			"crime.target.resident_projection.published",
			self,
			"_on_crime_hub_truth_probe_target_received",
			{
				"lane": "important",
				"allow_defer": false,
				"force_immediate": true,
				"subscription_priority": 2,
				"subscription_id": (
					"crime_hub_pipeline_truth_probe"
				)
			}
		)


func _on_crime_hub_truth_probe_target_received(
	payload: Dictionary = {}
) -> void:
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

	_crime_hub_truth_probe(
		"crime_hub_received",
		{
			"actor_id": int(
				payload.get(
					"actor_id",
					-1
				)
			),
			"section": "targets",
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


func _on_crime_hub_truth_probe_section_contract_emitted(
	actor_id: int,
	section_id: String,
	section_contract: Dictionary,
	source: String
) -> void:
	var rows_raw: Variant = section_contract.get(
		"section_rows",
		[]
	)

	var rows: Array = (
		rows_raw as Array
		if typeof(
			rows_raw
		) == TYPE_ARRAY
		else []
	)

	_crime_hub_truth_probe(
		"section_contract_emitted",
		{
			"actor_id": actor_id,
			"section": section_id,
			"row_count": rows.size(),
			"truth_state": str(
				section_contract.get(
					"truth_state",
					""
				)
			),
			"hydrated": bool(
				section_contract.get(
					"hydrated",
					false
				)
			),
			"projection_pending": bool(
				section_contract.get(
					"projection_pending",
					false
				)
			),
			"completion_only": bool(
				section_contract.get(
					"stream_completion_only",
					false
				)
			),
			"source": source
		}
	)


func _on_crime_hub_truth_probe_section_row_emitted(
	actor_id: int,
	section_id: String,
	row_contract: Dictionary,
	source: String
) -> void:
	_crime_hub_truth_probe(
		"section_row_emitted",
		{
			"actor_id": actor_id,
			"section": section_id,
			"kind": str(
				row_contract.get(
					"kind",
					""
				)
			),
			"target_id": int(
				row_contract.get(
					"target_id",
					-1
				)
			),
			"source": source
		}
	)


func _arm_crime_runtime_bootstrap_service() -> void:
	var tree:= Engine.get_main_loop() as SceneTree

	if tree == null:
		_crime_hub_truth_probe(
			"bootstrap_scene_tree_unavailable"
		)
		return

	var callback:= Callable(
		self,
		"_service_crime_runtime_bootstrap"
	)

	if tree.process_frame.is_connected(
		callback
	):
		crime_runtime_bootstrap_service_active = true
		return

	tree.process_frame.connect(
		callback
	)

	crime_runtime_bootstrap_service_active = true

	_crime_hub_truth_probe(
		"bootstrap_process_frame_lease_acquired"
	)


func _service_crime_runtime_bootstrap() -> void:
	if gs == null:
		return



	_bind_crime_hub_truth_probe()

	_bind_crime_background_event_bus()
	_arm_crime_resident_actor_probe()



	_arm_resident_section_projection_service()
	_arm_resident_heavy_section_projection_service()
	_arm_resident_observer_replay_service()

	var actor_probe_connection_hot: bool = false
	var projection_engine = (
		gs.reality_projection_contract_engine
		if gs != null
		else null
	)

	if (
		projection_engine != null
		and projection_engine.has_signal(
			"resident_surface_contract_ready"
		)
	):
		var actor_probe_callback:= Callable(
			self,
			"_service_crime_resident_actor_probe"
		)

		actor_probe_connection_hot = (
			projection_engine.is_connected(
				"resident_surface_contract_ready",
				actor_probe_callback
			)
		)



	crime_resident_actor_probe_active = (
		actor_probe_connection_hot
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

	var actor_present: bool = (
		actor_id > 0
	)

	if (
		actor_present
		and actor_id
		!= crime_truth_probe_last_actor_id
	):
		crime_truth_probe_last_actor_id = actor_id

		_crime_hub_truth_probe(
			"actor_admitted",
			{
				"actor_id": actor_id
			}
		)






	var ordinary_work_owned: bool = false

	if actor_present:
		var actor_key: String = str(
			actor_id
		)

		var surfaces_raw: Variant = (
			section_surfaces_by_actor.get(
				actor_key,
				{}
			)
		)

		var surfaces: Dictionary = (
			surfaces_raw as Dictionary
			if typeof(
				surfaces_raw
			) == TYPE_DICTIONARY
			else {}
		)

		var actor: Person = (
			_resident_actor_by_id(
				actor_id
			)
		)

		var all_ordinary_sections_complete: bool = (
			actor != null
		)

		if actor != null:
			var incarcerated: bool = (
				_crime_actor_is_incarcerated_resident(
					actor
				)
			)

			for raw_tab in _section_tabs(
				incarcerated
			):
				if typeof(
					raw_tab
				) != TYPE_DICTIONARY:
					continue

				var tab: Dictionary = (
					raw_tab as Dictionary
				)

				var section_id: String = _section(
					str(
						tab.get(
							"id",
							"overview"
						)
					)
				)

				if (
					section_id == ""
					or section_id == "targets"
				):
					continue

				var resident_raw: Variant = (
					surfaces.get(
						section_id,
						{}
					)
				)

				var resident_surface: Dictionary = (
					resident_raw as Dictionary
					if typeof(
						resident_raw
					) == TYPE_DICTIONARY
					else {}
				)

				var section_complete: bool = (
					not resident_surface.is_empty()
					and str(
						resident_surface.get(
							"truth_state",
							""
						)
					).strip_edges().to_lower() == "hot"
					and bool(
						resident_surface.get(
							"hydrated",
							false
						)
					)
					and not bool(
						resident_surface.get(
							"projection_pending",
							false
						)
					)
					and not bool(
						resident_surface.get(
							"dirty",
							false
						)
					)
				)

				if not section_complete:
					all_ordinary_sections_complete = false
					break

		var lightweight_work_owned: bool = (
			resident_section_projection_queue_head
			< resident_section_projection_queue_tail
			or resident_section_projection_service_active
		)

		var heavy_work_owned: bool = (
			resident_heavy_section_projection_queue_head
			< resident_heavy_section_projection_queue_tail
			or resident_heavy_section_projection_service_active
			or not resident_heavy_section_projection_state_by_key.is_empty()
		)

		ordinary_work_owned = (
			all_ordinary_sections_complete
			or lightweight_work_owned
			or heavy_work_owned
		)

	var bootstrap_state: String = (
		"%s:%s:%s:%d:%s:%s:%s"
		% [
			str(
				crime_event_bus_bound
			),
			str(
				actor_probe_connection_hot
			),
			str(
				actor_present
			),
			actor_id,
			str(
				resident_section_projection_service_active
			),
			str(
				resident_heavy_section_projection_service_active
			),
			str(
				ordinary_work_owned
			)
		]
	)

	if (
		bootstrap_state
		!= crime_runtime_bootstrap_last_state
	):
		crime_runtime_bootstrap_last_state = (
			bootstrap_state
		)

		_crime_hub_truth_probe(
			"bootstrap_state",
			{
				"event_bus_bound": (
					crime_event_bus_bound
				),
				"actor_probe_bound": (
					actor_probe_connection_hot
				),
				"actor_present": (
					actor_present
				),
				"actor_id": actor_id,
				"section_queue_depth": (
					resident_section_projection_queue.size()
				),
				"heavy_queue_depth": (
					resident_heavy_section_projection_queue.size()
				),
				"ordinary_work_owned": (
					ordinary_work_owned
				)
			}
		)








	var bootstrap_complete: bool = (
		crime_event_bus_bound
		and actor_probe_connection_hot
		and actor_present
		and ordinary_work_owned
	)

	if not bootstrap_complete:
		return

	var tree:= Engine.get_main_loop() as SceneTree
	var callback:= Callable(
		self,
		"_service_crime_runtime_bootstrap"
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

	crime_runtime_bootstrap_service_active = false

	_crime_hub_truth_probe(
		"bootstrap_process_frame_lease_released",
		{
			"actor_id": actor_id,
			"actor_probe_bound": (
				actor_probe_connection_hot
			),
			"ordinary_work_owned": (
				ordinary_work_owned
			)
		}
	)
func bind_game_state(
	_game_state
) -> void:
	gs = _game_state

func _bind_crime_background_event_bus() -> void:






	_bind_crime_resident_observation_bus_bridge()

	if (
		crime_event_bus_bound
		or gs == null
		or gs.event_bus == null
	):
		return

	crime_event_bus_bound = true

	gs.event_bus.subscribe(
		"belongings.event",
		self,
		"_on_crime_belongings_event",
		{
			"lane": "important",
			"allow_defer": true,
			"subscription_priority": 84,
			"subscription_id": (
				"crime_hub_live_weapon_inventory"
			)
		}
	)

	gs.event_bus.subscribe(
		"crime.target.resident_projection.published",
		self,
		"_on_crime_target_resident_projection_published",
		{
			"lane": "important",
			"allow_defer": true,
			"subscription_priority": 85,
			"subscription_id": (
				"crime_hub_resident_target_projection"
			)
		}
	)

	gs.event_bus.subscribe(
		"crime.weapon.target_projection.published",
		self,
		"_on_crime_weapon_target_projection_access_guarded",
		{
			"lane": "important",
			"allow_defer": true,
			"subscription_priority": 86,
			"subscription_id": (
				"crime_hub_live_weapon_target_projection"
			)
		}
	)


	gs.event_bus.subscribe(
		"population.card_graph_packet.updated",
		self,
		"_on_crime_population_projection_updated",
		{
			"lane": "ambient",
			"allow_defer": true,
			"subscription_priority": 87,
			"subscription_id": (
				"crime_hub_population_projection_repair"
			)
		}
	)






	gs.event_bus.subscribe(
		ActionEventTypes.YEAR_PASSED,
		self,
		"_on_crime_year_passed",
		{
			"lane": "ambient",
			"allow_defer": true,
			"subscription_priority": 88,
			"subscription_id": (
				"crime_hub_temporal_projection_repair"
			)
		}
	)

	for event_name in [
		"jail_booking_created",
		"jail_release",
		"prison_intake_created",
		"prison_released"
	]:
		gs.event_bus.subscribe(
			event_name,
			self,
			"_on_crime_incarceration_event",
			{
				"lane": "important",
				"allow_defer": false,
				"force_immediate": true,
				"subscription_priority": 82,
				"subscription_id": (
					"crime_hub_incarceration_lens:%s"
					% event_name
				)
			}
		)


	_arm_crime_resident_actor_probe()







	_replay_resident_crime_target_projection_if_available()
func _on_crime_year_passed(
	_payload: Dictionary = {}
) -> void:





	_arm_crime_resident_actor_probe(
		false
	)
func _bind_crime_resident_observation_bus_bridge() -> void:
	var section_contract_callback:= Callable(
		self,
		"_relay_resident_crime_section_contract_to_event_bus"
	)

	if not is_connected(
		"resident_crime_section_contract_published",
		section_contract_callback
	):
		connect(
			"resident_crime_section_contract_published",
			section_contract_callback
		)

	var section_row_callback:= Callable(
		self,
		"_relay_resident_crime_section_row_to_event_bus"
	)

	if not is_connected(
		"resident_crime_section_row_published",
		section_row_callback
	):
		connect(
			"resident_crime_section_row_published",
			section_row_callback
		)

	var incarceration_callback:= Callable(
		self,
		"_relay_crime_incarceration_lens_to_event_bus"
	)

	if not is_connected(
		"incarceration_lens_published",
		incarceration_callback
	):
		connect(
			"incarceration_lens_published",
			incarceration_callback
		)


func _relay_resident_crime_section_contract_to_event_bus(
	actor_id: int,
	section_id: String,
	section_contract: Dictionary,
	source: String
) -> void:
	if (
		gs == null
		or gs.event_bus == null
		or actor_id <= 0
		or section_contract.is_empty()
	):
		return

	crime_observation_bus_publish_seq += 1

	var publication_id: String = (
		"crime_hub_section_contract:%d:%s:%d"
		% [
			actor_id,
			section_id,
			crime_observation_bus_publish_seq
		]
	)

	gs.event_bus.emit(
		"crime.hub.resident_section_contract.published",
		{
			"event_uid": publication_id,
			"duplicate_key": publication_id,
			"actor_id": actor_id,
			"section_id": section_id,
			"section_contract": (
				section_contract.duplicate(false)
			),
			"source": source,
			"game_state_instance_id": (
				gs.get_instance_id()
			),
			"crime_hub_authority_instance_id": (
				get_instance_id()
			),
			"qos_tier": "critical",
			"fanout_hints": {
				"force_immediate_bus": true,
				"skip_llm_bridge": true
			},
			"simulation_mutation_performed": false,
			"ui_is_renderer_only": true
		}
	)

func _relay_resident_crime_section_row_to_event_bus(
	actor_id: int,
	section_id: String,
	row_contract: Dictionary,
	source: String
) -> void:
	if (
		gs == null
		or gs.event_bus == null
		or actor_id <= 0
		or row_contract.is_empty()
	):
		return

	crime_observation_bus_publish_seq += 1

	var publication_id: String = (
		"crime_hub_section_row:%d:%s:%d"
		% [
			actor_id,
			section_id,
			crime_observation_bus_publish_seq
		]
	)

	gs.event_bus.emit(
		"crime.hub.resident_section_row.published",
		{
			"event_uid": publication_id,
			"duplicate_key": publication_id,
			"actor_id": actor_id,
			"section_id": section_id,
			"row_contract": (
				row_contract.duplicate(false)
			),
			"source": source,
			"game_state_instance_id": (
				gs.get_instance_id()
			),
			"crime_hub_authority_instance_id": (
				get_instance_id()
			),
			"qos_tier": "critical",
			"fanout_hints": {
				"force_immediate_bus": true,
				"skip_llm_bridge": true
			},
			"simulation_mutation_performed": false,
			"ui_is_renderer_only": true
		}
	)


func _relay_crime_incarceration_lens_to_event_bus(
	actor_id: int,
	contract: Dictionary
) -> void:
	if (
		gs == null
		or gs.event_bus == null
		or actor_id <= 0
		or contract.is_empty()
	):
		return

	crime_observation_bus_publish_seq += 1

	var publication_id: String = (
		"crime_hub_incarceration:%d:%d"
		% [
			actor_id,
			crime_observation_bus_publish_seq
		]
	)

	gs.event_bus.emit(
		"crime.hub.incarceration_lens.published",
		{
			"event_uid": publication_id,
			"duplicate_key": publication_id,
			"actor_id": actor_id,
			"contract": contract.duplicate(false),
			"source": (
				"crime_hub_incarceration_lens"
			),
			"game_state_instance_id": (
				gs.get_instance_id()
			),
			"crime_hub_authority_instance_id": (
				get_instance_id()
			),
			"qos_tier": "critical",
			"fanout_hints": {
				"force_immediate_bus": true,
				"skip_llm_bridge": true
			},
			"simulation_mutation_performed": false,
			"ui_is_renderer_only": true
		}
	)
func _replay_resident_crime_target_projection_if_available() -> void:
	if (
		gs == null
		or gs.player == null
		or gs.crime_contract_engine == null
		or not gs.crime_contract_engine.has_method(
			"resident_crime_target_contract"
		)
	):
		return

	var actor_id: int = int(
		gs.player.id
	)

	if actor_id <= 0:
		return

	var resident_raw: Variant = (
		gs.crime_contract_engine.call(
			"resident_crime_target_contract",
			actor_id
		)
	)

	if typeof(resident_raw) != TYPE_DICTIONARY:
		return

	var resident_contract: Dictionary = (
		resident_raw as Dictionary
	)

	if resident_contract.is_empty():
		return

	_on_crime_target_resident_projection_published(
		resident_contract
	)
func observe_resident_projection(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	if (
		actor == null
		or gs == null
		or gs.player == null
	):
		return {
			"success": false,
			"reason": "crime_resident_observer_unavailable",
			"read_only": true
		}

	var actor_id: int = int(
		actor.id
	)

	if (
		actor_id <= 0
		or int(
			gs.player.id
		) != actor_id
	):
		return {
			"success": false,
			"reason": "crime_resident_observer_actor_mismatch",
			"actor_id": actor_id,
			"read_only": true
		}

	var source: String = str(
		payload.get(
			"source",
			"crime_hub_resident_observer_replay"
		)
	).strip_edges()

	if source == "":
		source = "crime_hub_resident_observer_replay"

	var actor_key: String = str(
		actor_id
	)
	var surfaces_raw: Variant = (
		section_surfaces_by_actor.get(
			actor_key,
			{}
		)
	)
	var surfaces: Dictionary = (
		(surfaces_raw as Dictionary).duplicate(false)
		if typeof(surfaces_raw) == TYPE_DICTIONARY
		else {}
	)

	if surfaces.is_empty():
		return {
			"success": false,
			"reason": "resident_crime_projection_not_admitted_yet",
			"actor_id": actor_id,
			"read_only": true,
		}

	var replayed_sections: int = 0
	var replayed_rows: int = 0
	var replay_sections: Array = [
		"overview",
		"crime_actions",
		"targets",
		"weapons",
		"cases",
		"pending",
		"custody",
		"prison",
		"population",
		"family"
	]

	for raw_section_id in replay_sections:
		var section_id: String = str(
			raw_section_id
		).strip_edges().to_lower()

		if not surfaces.has(
			section_id
		):
			continue

		var surface_raw: Variant = surfaces.get(
			section_id,
			{}
		)
		var resident_surface: Dictionary = (
			(surface_raw as Dictionary).duplicate(false)
			if typeof(surface_raw) == TYPE_DICTIONARY
			else {}
		)

		if resident_surface.is_empty():
			continue

		if section_id == "targets":
			var target_surface: Dictionary = (
				_crime_section_surface(
					actor,
					"targets",
					{}
				)
			)

			if not target_surface.is_empty():
				resident_surface = target_surface

		var heavy_job_key: String = (
			"%d:%s"
			% [
				actor_id,
				section_id
			]
		)
		var heavy_state_raw: Variant = (
			resident_heavy_section_projection_state_by_key.get(
				heavy_job_key,
				{}
			)
		)
		var heavy_state: Dictionary = (
			heavy_state_raw as Dictionary
			if typeof(heavy_state_raw) == TYPE_DICTIONARY
			else {}
		)
		var rows_raw: Variant = resident_surface.get(
			"section_rows",
			[]
		)
		var replay_rows: Array = (
			rows_raw as Array
			if typeof(rows_raw) == TYPE_ARRAY
			else []
		)
		var emit_completion: bool = false

		if (
			section_id in [
				"weapons",
				"cases"
			]
			and not heavy_state.is_empty()
		):
			var state_rows_raw: Variant = heavy_state.get(
				"rows",
				[]
			)
			replay_rows = (
				state_rows_raw as Array
				if typeof(state_rows_raw) == TYPE_ARRAY
				else []
			)
		elif section_id in [
			"weapons",
			"cases"
		]:
			emit_completion = bool(
				resident_surface.get(
					"stream_completion_only",
					false
				)
			)

		if (
			section_id in [
				"weapons",
				"cases"
			]
			and not replay_rows.is_empty()
		):
			var opening_surface: Dictionary = (
				resident_surface.duplicate(false)
			)

			opening_surface [
				"section_rows"
			] = []
			opening_surface [
				"stream_completion_only"
			] = false
			opening_surface [
				"projection_pending"
			] = true
			opening_surface [
				"observer_replay"
			] = true
			opening_surface [
				"observation_required"
			] = false
			opening_surface [
				"status_text"
			] = (
				"Resident weapons are reconnecting live."
				if section_id == "weapons"
				else "Resident crime cases are reconnecting live."
			)

			resident_crime_section_contract_published.emit(
				actor_id,
				section_id,
				opening_surface,
				"%s:observer_replay_started" % source
			)

			_queue_resident_observer_row_replay(
				actor_id,
				section_id,
				replay_rows,
				replay_rows.size(),
				resident_surface,
				emit_completion,
				source
			)

			replayed_sections += 1
			replayed_rows += replay_rows.size()
			continue

		resident_surface [
			"observer_replay"
		] = true
		resident_surface [
			"observation_required"
		] = false

		resident_crime_section_contract_published.emit(
			actor_id,
			section_id,
			resident_surface,
			"%s:observer_replay" % source
		)

		replayed_sections += 1

	return {
		"success": replayed_sections > 0,
		"actor_id": actor_id,
		"replayed_section_count": replayed_sections,
		"queued_row_replay_count": replayed_rows,
		"read_only": true,
		"ready_gate_member": false,
		"build_on_click": false,
		"blocks_ui": false,
		"source": source
	}


func _queue_resident_observer_row_replay(
	actor_id: int,
	section_id: String,
	rows: Array,
	row_limit: int,
	completion_surface: Dictionary,
	emit_completion: bool,
	source: String
) -> void:
	var clean_section: String = _section(
		section_id
	)
	var safe_limit: int = mini(
		maxi(
			row_limit,
			0
		),
		rows.size()
	)

	if (
		actor_id <= 0
		or clean_section not in [
			"weapons",
			"cases"
		]
		or safe_limit <= 0
	):
		return

	var replay_key: String = (
		"%d:%s"
		% [
			actor_id,
			clean_section
		]
	)

	if resident_observer_replay_state_by_key.has(
		replay_key
	):
		return

	resident_observer_replay_state_by_key [
		replay_key
	] = {
		"replay_key": replay_key,
		"actor_id": actor_id,
		"section_id": clean_section,
		"rows": rows,
		"row_limit": safe_limit,
		"cursor": 0,
		"completion_surface": completion_surface.duplicate(false),
		"emit_completion": emit_completion,
		"source": source
	}

	if not resident_observer_replay_keys.has(
		replay_key
	):
		resident_observer_replay_keys [
			replay_key
		] = true

		var queue_slot: int = (
			resident_observer_replay_queue_tail
		)
		resident_observer_replay_queue_tail += 1

		resident_observer_replay_queue [
			queue_slot
		] = replay_key

	_arm_resident_observer_replay_service()


func _arm_resident_observer_replay_service() -> void:
	if (
		resident_observer_replay_queue_head
		>= resident_observer_replay_queue_tail
	):
		resident_observer_replay_service_active = false
		return

	resident_observer_replay_service_active = true
	_arm_crime_background_aggregate_service()
func _drive_resident_observer_replay_process_frame() -> void:
	var tree:= Engine.get_main_loop() as SceneTree
	var callback:= Callable(
		self,
		"_drive_resident_observer_replay_process_frame"
	)

	if (
		resident_observer_replay_queue_head
		>= resident_observer_replay_queue_tail
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

		resident_observer_replay_service_active = false
		return

	_service_resident_observer_replay_queue()

	if (
		resident_observer_replay_queue_head
		>= resident_observer_replay_queue_tail
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

		resident_observer_replay_service_active = false
	else:
		resident_observer_replay_service_active = true

func _service_resident_observer_replay_queue() -> void:
	resident_observer_replay_service_active = false

	if (
		resident_observer_replay_queue_head
		>= resident_observer_replay_queue_tail
	):
		resident_observer_replay_queue.clear()
		resident_observer_replay_queue_head = 0
		resident_observer_replay_queue_tail = 0
		return

	var queue_slot: int = (
		resident_observer_replay_queue_head
	)
	resident_observer_replay_queue_head += 1

	var replay_key: String = str(
		resident_observer_replay_queue.get(
			queue_slot,
			""
		)
	)

	resident_observer_replay_queue.erase(
		queue_slot
	)
	resident_observer_replay_keys.erase(
		replay_key
	)

	var state_raw: Variant = (
		resident_observer_replay_state_by_key.get(
			replay_key,
			{}
		)
	)

	if typeof(state_raw) != TYPE_DICTIONARY:
		_arm_resident_observer_replay_service()
		return

	var state: Dictionary = state_raw as Dictionary
	var actor_id: int = int(
		state.get(
			"actor_id",
			-1
		)
	)

	if (
		gs == null
		or gs.player == null
		or int(
			gs.player.id
		) != actor_id
	):
		resident_observer_replay_state_by_key.erase(
			replay_key
		)
		_arm_resident_observer_replay_service()
		return

	var section_id: String = _section(
		str(
			state.get(
				"section_id",
				""
			)
		)
	)
	var rows_raw: Variant = state.get(
		"rows",
		[]
	)
	var rows: Array = (
		rows_raw as Array
		if typeof(rows_raw) == TYPE_ARRAY
		else []
	)
	var row_limit: int = mini(
		int(
			state.get(
				"row_limit",
				rows.size()
			)
		),
		rows.size()
	)
	var cursor: int = int(
		state.get(
			"cursor",
			0
		)
	)
	var started_usec: int = int(
		Time.get_ticks_usec()
	)
	var serviced_rows: int = 0

	while (
		cursor < row_limit
		and serviced_rows
			< CRIME_OBSERVER_REPLAY_ROW_BUDGET_PER_QUANTUM
	):
		if (
			serviced_rows > 0
			and int(
				Time.get_ticks_usec()
			) - started_usec
				>= CRIME_OBSERVER_REPLAY_WORK_BUDGET_USEC
		):
			break

		var row_raw: Variant = rows [
			cursor
		]
		cursor += 1
		serviced_rows += 1

		if typeof(row_raw) != TYPE_DICTIONARY:
			continue

		resident_crime_section_row_published.emit(
			actor_id,
			section_id,
			(row_raw as Dictionary).duplicate(false),
			"%s:observer_row_replay" % str(
				state.get(
					"source",
					"crime_hub_resident_observer_replay"
				)
			)
		)

	state [
		"cursor"
	] = cursor

	if cursor < row_limit:
		resident_observer_replay_state_by_key [
			replay_key
		] = state

		if not resident_observer_replay_keys.has(
			replay_key
		):
			resident_observer_replay_keys [
				replay_key
			] = true

			var next_slot: int = (
				resident_observer_replay_queue_tail
			)
			resident_observer_replay_queue_tail += 1

			resident_observer_replay_queue [
				next_slot
			] = replay_key

		_arm_resident_observer_replay_service()
		return

	if bool(
		state.get(
			"emit_completion",
			false
		)
	):
		var completion_raw: Variant = state.get(
			"completion_surface",
			{}
		)
		var completion_surface: Dictionary = (
			(completion_raw as Dictionary).duplicate(false)
			if typeof(completion_raw) == TYPE_DICTIONARY
			else {}
		)

		if not completion_surface.is_empty():
			completion_surface [
				"stream_completion_only"
			] = true
			completion_surface [
				"observer_replay_completion"
			] = true

			resident_crime_section_contract_published.emit(
				actor_id,
				section_id,
				completion_surface,
				"%s:observer_replay_complete" % str(
					state.get(
						"source",
						"crime_hub_resident_observer_replay"
					)
				)
			)

	resident_observer_replay_state_by_key.erase(
		replay_key
	)

	if (
		resident_observer_replay_queue_head
		>= resident_observer_replay_queue_tail
	):
		resident_observer_replay_queue.clear()
		resident_observer_replay_queue_head = 0
		resident_observer_replay_queue_tail = 0
		return

	_arm_resident_observer_replay_service()
func _arm_crime_resident_actor_probe(
	replay_target_projection: bool = true
) -> void:
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
		var callback:= Callable(
			self,
			"_service_crime_resident_actor_probe"
		)

		if not projection_engine.is_connected(
			"resident_surface_contract_ready",
			callback
		):
			projection_engine.connect(
				"resident_surface_contract_ready",
				callback
			)

	crime_resident_actor_probe_active = true




	_replay_crime_resident_actor_probe_from_resident_projection(
		projection_engine
	)


	if (
		gs == null
		or gs.player == null
	):
		return

	var actor: Person = gs.player
	var actor_id: int = int(
		actor.id
	)

	if actor_id <= 0:
		return

	var current_world_year: int = int(
		gs.year
	)

	var current_actor_age: int = maxi(
		0,
		int(
			actor.age
		)
	)



	if replay_target_projection:
		_replay_resident_crime_target_projection_if_available()

	var actor_key: String = str(
		actor_id
	)

	var incarcerated: bool = (
		_crime_actor_is_incarcerated_resident(
			actor
		)
	)

	var surfaces_raw: Variant = (
		section_surfaces_by_actor.get(
			actor_key,
			{}
		)
	)

	var surfaces: Dictionary = (
		(surfaces_raw as Dictionary).duplicate(false)
		if typeof(surfaces_raw) == TYPE_DICTIONARY
		else {}
	)

	var sections_to_queue: Array = []
	var ordinary_projection_incomplete: bool = false

	for raw_tab in _section_tabs(
		incarcerated
	):
		if typeof(raw_tab) != TYPE_DICTIONARY:
			continue

		var tab: Dictionary = (
			raw_tab as Dictionary
		)

		var section_id: String = _section(
			str(
				tab.get(
					"id",
					"overview"
				)
			)
		)

		if section_id == "":
			continue


		if section_id == "targets":
			continue

		var resident_raw: Variant = surfaces.get(
			section_id,
			{}
		)

		var resident_surface: Dictionary = (
			(resident_raw as Dictionary).duplicate(false)
			if typeof(resident_raw) == TYPE_DICTIONARY
			else {}
		)




		var temporal_revision_required: bool = (
			section_id not in [
				"weapons",
				"cases"
			]
		)

		var temporal_projection_stale: bool = (
			temporal_revision_required
			and (
				int(
					resident_surface.get(
						"projected_world_year",
						-999999
					)
				) != current_world_year
				or int(
					resident_surface.get(
						"projected_actor_age",
						-1
					)
				) != current_actor_age
			)
		)

		if temporal_projection_stale:
			resident_surface [
				"projection_pending"
			] = true

			resident_surface [
				"dirty"
			] = true

			resident_surface [
				"dirty_reason"
			] = "temporal_truth_revision_mismatch"

			resident_surface [
				"expected_world_year"
			] = current_world_year

			resident_surface [
				"expected_actor_age"
			] = current_actor_age

			resident_surface [
				"dirty_at_ms"
			] = int(
				Time.get_ticks_msec()
			)

			surfaces [
				section_id
			] = resident_surface

		var projection_missing: bool = (
			resident_surface.is_empty()
			or str(
				resident_surface.get(
					"truth_state",
					""
				)
			).strip_edges().to_lower() != "hot"
			or not bool(
				resident_surface.get(
					"hydrated",
					false
				)
			)
			or bool(
				resident_surface.get(
					"projection_pending",
					false
				)
			)
			or bool(
				resident_surface.get(
					"dirty",
					false
				)
			)
			or temporal_projection_stale
		)

		if not projection_missing:
			continue

		ordinary_projection_incomplete = true

		var queue_key: String = (
			"%d:%s"
			% [
				actor_id,
				section_id
			]
		)

		var heavy_projection_in_flight: bool = (
			section_id in [
				"weapons",
				"cases"
			]
			and (
				resident_heavy_section_projection_state_by_key.has(
					queue_key
				)
				or resident_heavy_section_projection_keys.has(
					queue_key
				)
			)
		)

		var lightweight_projection_in_flight: bool = (
			resident_section_projection_keys.has(
				queue_key
			)
		)

		if (
			not heavy_projection_in_flight
			and not lightweight_projection_in_flight
		):
			sections_to_queue.append(
				section_id
			)

	section_surfaces_by_actor [
		actor_key
	] = surfaces

	if not ordinary_projection_incomplete:
		return

	crime_resident_actor_probe_last_actor_id = (
		actor_id
	)

	if not sections_to_queue.is_empty():
		queue_resident_section_projection(
			actor,
			sections_to_queue,
			"crime_hub_controlled_actor_autonomous_residency"
		)



		_arm_resident_section_projection_service()
		_arm_resident_heavy_section_projection_service()
func _crime_resident_projection_signature_hint() -> String:
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


func _replay_crime_resident_actor_probe_from_resident_projection(
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









	_service_crime_resident_actor_probe(
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
func _on_crime_population_projection_updated(
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

	if actor_id <= 0:
		return











	_arm_crime_resident_actor_probe(
		false
	)
func _crime_actor_is_incarcerated_resident(
		actor: Person
) -> bool:
	if (
		actor == null
		or gs == null
	):
		return false

	var actor_id: int = int(
		actor.id
	)

	if (
		gs.prison_engine != null
		and gs.prison_engine.has_method(
			"resident_incarceration_status_contract"
		)
	):
		var prison_status: Dictionary = _safe_dictionary(
			gs.prison_engine.call(
				"resident_incarceration_status_contract",
				actor_id
			)
		)

		if bool(
			prison_status.get(
				"active",
				false
			)
		):
			return true

	if (
		gs.jail_engine != null
		and gs.jail_engine.has_method(
			"resident_incarceration_status_contract"
		)
	):
		var jail_status: Dictionary = _safe_dictionary(
			gs.jail_engine.call(
				"resident_incarceration_status_contract",
				actor_id
			)
		)

		if bool(
			jail_status.get(
				"active",
				false
			)
		):
			return true



	return (
		str(
			actor.current_context
		).strip_edges().to_lower()
		== "incarcerated"
	)
func _service_crime_resident_actor_probe(
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

	var actor: Person = gs.player

	var actor_key: String = str(
		actor_id
	)

	var current_world_year: int = int(
		gs.year
	)

	var current_actor_age: int = maxi(
		0,
		int(
			actor.age
		)
	)

	var incarcerated: bool = (
		_crime_actor_is_incarcerated_resident(
			actor
		)
	)

	var first_actor_admission: bool = (
		actor_id != crime_resident_actor_probe_last_actor_id
	)

	var surfaces_raw: Variant = (
		section_surfaces_by_actor.get(
			actor_key,
			{}
		)
	)

	var surfaces: Dictionary = (
		(surfaces_raw as Dictionary).duplicate(false)
		if typeof(surfaces_raw) == TYPE_DICTIONARY
		else {}
	)

	var missing_sections: Array = []

	for raw_tab in _section_tabs(
		incarcerated
	):
		if typeof(raw_tab) != TYPE_DICTIONARY:
			continue

		var tab: Dictionary = raw_tab as Dictionary

		var section_id: String = _section(
			str(
				tab.get(
					"id",
					"overview"
				)
			)
		)

		var resident_raw: Variant = surfaces.get(
			section_id,
			{}
		)

		var resident_surface: Dictionary = (
			(resident_raw as Dictionary).duplicate(false)
			if typeof(resident_raw) == TYPE_DICTIONARY
			else {}
		)

		if resident_surface.is_empty():
			resident_surface = (
				_crime_section_shell(
					section_id,
					incarcerated
				)
			)

			resident_surface [
				"actor_id"
			] = actor_id

			resident_surface [
				"progressive_observability"
			] = true

			resident_surface [
				"observation_required"
			] = false

			resident_surface [
				"ready_gate_member"
			] = false

			resident_surface [
				"published_at_ms"
			] = int(
				Time.get_ticks_msec()
			)

		if section_id == "targets":
			surfaces [
				section_id
			] = resident_surface
			continue




		var temporal_revision_required: bool = (
			section_id not in [
				"weapons",
				"cases"
			]
		)

		var temporal_projection_stale: bool = (
			temporal_revision_required
			and (
				int(
					resident_surface.get(
						"projected_world_year",
						-999999
					)
				) != current_world_year
				or int(
					resident_surface.get(
						"projected_actor_age",
						-1
					)
				) != current_actor_age
			)
		)

		if temporal_projection_stale:
			resident_surface [
				"projection_pending"
			] = true

			resident_surface [
				"dirty"
			] = true

			resident_surface [
				"dirty_reason"
			] = "temporal_truth_revision_mismatch"

			resident_surface [
				"expected_world_year"
			] = current_world_year

			resident_surface [
				"expected_actor_age"
			] = current_actor_age

			resident_surface [
				"dirty_at_ms"
			] = int(
				Time.get_ticks_msec()
			)

		surfaces [
			section_id
		] = resident_surface

		var projection_missing: bool = (
			str(
				resident_surface.get(
					"truth_state",
					""
				)
			) != "hot"
			or not bool(
				resident_surface.get(
					"hydrated",
					false
				)
			)
			or bool(
				resident_surface.get(
					"projection_pending",
					false
				)
			)
			or bool(
				resident_surface.get(
					"dirty",
					false
				)
			)
			or temporal_projection_stale
		)

		if projection_missing:
			missing_sections.append(
				section_id
			)

	section_surfaces_by_actor [
		actor_key
	] = surfaces

	if first_actor_admission:
		var admission_surface_raw: Variant = surfaces.get(
			"overview",
			{}
		)

		var admission_surface: Dictionary = (
			(admission_surface_raw as Dictionary).duplicate(false)
			if typeof(admission_surface_raw) == TYPE_DICTIONARY
			else {}
		)

		if not admission_surface.is_empty():
			resident_crime_section_contract_published.emit(
				actor_id,
				"overview",
				admission_surface,
				"crime_hub_controlled_actor_cold_resident_admission"
			)

	if (
		actor_id == crime_resident_actor_probe_last_actor_id
		and missing_sections.is_empty()
	):
		return

	crime_resident_actor_probe_last_actor_id = actor_id

	if missing_sections.is_empty():
		return

	queue_resident_section_projection(
		actor,
		missing_sections,
		"crime_hub_controlled_actor_resident"
	)
func _decorate_crime_target_rows(
	actor: Person,
	rows: Array
) -> Array:
	var out: Array = []

	if actor == null:
		return out

	var circle_target_ids: Array = []

	for raw_row in rows:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = raw_row as Dictionary

		var target_id: int = int(
			row.get(
				"target_id",
				-1
			)
		)

		if (
			target_id > 0
			and target_id not in circle_target_ids
		):
			circle_target_ids.append(
				target_id
			)

	for raw_row in rows:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue

		var source_row: Dictionary = (
			raw_row as Dictionary
		)

		var row: Dictionary = (
			source_row.duplicate(false)
		)

		var target_id: int = int(
			row.get(
				"target_id",
				-1
			)
		)

		if target_id <= 0:
			out.append(
				row
			)
			continue

		var offense_count: int = 0

		if (
			gs != null
			and gs.crime_contract_engine != null
			and gs.crime_contract_engine.has_method(
				"crime_target_circle_offense_count"
			)
		):
			offense_count = int(
				gs.crime_contract_engine
				.crime_target_circle_offense_count(
					target_id,
					circle_target_ids
				)
			)

		var physical_access: Dictionary = {}

		if (
			gs != null
			and gs.crime_contract_engine != null
			and gs.crime_contract_engine.has_method(
				"physical_crime_target_access_contract"
			)
		):
			physical_access = (
				gs.crime_contract_engine
				.physical_crime_target_access_contract(
					actor,
					int(
						row.get(
							"target_realm_id",
							-1
						)
					),
					str(
						row.get(
							"target_home_country",
							""
						)
					)
				)
			)

		var physical_target_available: bool = bool(
			physical_access.get(
				"allowed",
				true
			)
		)
		var physical_unavailable_reason: String = str(
			physical_access.get(
				"reason",
				""
			)
		).strip_edges()

		var base_subtitle: String = str(
			row.get(
				"base_subtitle",
				row.get(
					"subtitle",
					""
				)
			)
		).strip_edges()

		row [
			"base_subtitle"
		] = base_subtitle

		row [
			"crime_against_target_circle_count"
		] = offense_count

		row [
			"crime_against_target_circle_label"
		] = (
			"%d crime%s against people in this target circle"
			% [
				offense_count,
				(
					""
					if offense_count == 1
					else "s"
				)
			]
		)

		row ["subtitle"] = (
			(
				base_subtitle + "\n"
				if base_subtitle != ""
				else ""
			)
			+ str(
				row [
					"crime_against_target_circle_label"
				]
			)
		)

		if not physical_target_available:
			row [
				"subtitle"
			] += (
				"\nNOT AVAILABLE FOR PHYSICAL CRIME"
				+ " • Lives in another nation."
			)

		row [
			"physical_target_access_contract"
		] = physical_access
		row [
			"physical_target_available"
		] = physical_target_available
		row [
			"physical_target_unavailable_reason"
		] = physical_unavailable_reason






		row [
			"target_selection_action"
		] = {
			"id": "choose_crime_target",
			"label": "TARGET",
			"enabled": true,
			"payload": {
				"action_id": "choose_crime_target",
				"target_id": target_id
			}
		}





		row [
			"physical_target_selection_action"
		] = {
			"id": "choose_crime_target",
			"label": "TARGET",
			"enabled": physical_target_available,
			"disabled_reason": physical_unavailable_reason,
			"physical_target_access_contract": physical_access,
			"payload": {
				"action_id": "choose_crime_target",
				"target_id": target_id
			}
		}

		row [
			"actions"
		] = []

		row [
			"target_selection_intent_only"
		] = true

		row [
			"target_selection_action_visible_only_when_armed"
		] = true

		out.append(
			row
		)

	return out
func _on_crime_target_resident_projection_published(
	payload: Dictionary = {}
) -> void:
	var actor_id: int = int(
		payload.get(
			"actor_id",
			-1
		)
	)

	if actor_id <= 0:
		return

	var actor: Person = _resident_actor_by_id(
		actor_id
	)

	if actor == null:
		return

	var actor_key: String = str(
		actor_id
	)

	var complete: bool = bool(
		payload.get(
			"complete",
			false
		)
	)

	var source_rows: Array = _safe_array(
		payload.get(
			"rows",
			[]
		)
	)

	var decorated_rows: Array = (
		_decorate_crime_target_rows(
			actor,
			source_rows
		)
	)

	var surfaces: Dictionary = (
		_safe_dictionary(
			section_surfaces_by_actor.get(
				actor_key,
				{}
			)
		)
	)

	var previous_target_surface: Dictionary = (
		_safe_dictionary(
			surfaces.get(
				"targets",
				{}
			)
		)
	)

	var previous_rows: Array = _safe_array(
		previous_target_surface.get(
			"section_rows",
			[]
		)
	)

	var previous_by_target_id: Dictionary = {}

	for raw_previous in previous_rows:
		if typeof(
			raw_previous
		) != TYPE_DICTIONARY:
			continue

		var previous_row: Dictionary = (
			raw_previous as Dictionary
		)

		var previous_target_id: int = int(
			previous_row.get(
				"target_id",
				-1
			)
		)

		if previous_target_id <= 0:
			continue

		previous_by_target_id [
			str(
				previous_target_id
			)
		] = previous_row

	var target_surface: Dictionary = (
		_crime_section_shell(
			"targets",
			false
		)
	)

	target_surface [
		"actor_id"
	] = actor_id

	target_surface [
		"section_id"
	] = "targets"

	target_surface [
		"title"
	] = "TARGETS"

	target_surface [
		"section_rows"
	] = decorated_rows

	target_surface [
		"interaction_contract"
	] = {}

	target_surface [
		"truth_state"
	] = "hot"

	target_surface [
		"hydrated"
	] = true

	target_surface [
		"projection_pending"
	] = not complete


	target_surface [
		"target_projection_complete"
	] = complete

	target_surface [
		"row_count"
	] = decorated_rows.size()

	target_surface [
		"relationship_target_count"
	] = int(
		payload.get(
			"relationship_target_count",
			0
		)
	)

	target_surface [
		"random_stranger_count"
	] = int(
		payload.get(
			"random_stranger_count",
			0
		)
	)

	target_surface [
		"target_policy"
	] = (
		"partner_parents_ancestors_siblings_aunts_uncles"
		+ "_plus_two_unrelated_strangers"
	)

	target_surface [
		"acquaintances_excluded"
	] = true

	target_surface [
		"descendants_excluded"
	] = true

	target_surface [
		"friends_excluded"
	] = true

	target_surface [
		"cousins_excluded"
	] = true

	target_surface [
		"target_projection_signature"
	] = str(
		payload.get(
			"signature",
			""
		)
	)

	target_surface [
		"build_on_section_click"
	] = false

	target_surface [
		"engine_call_on_section_click"
	] = false

	target_surface [
		"population_scan_on_section_click"
	] = false

	target_surface [
		"progressive_observability"
	] = true

	target_surface [
		"observation_required"
	] = false

	target_surface [
		"ui_is_renderer_only"
	] = true

	target_surface [
		"updated_at_ms"
	] = int(
		Time.get_ticks_msec()
	)

	resident_target_identity_contract_by_actor [
		actor_key
	] = target_surface.duplicate(
		false
	)

	var visible_interaction: Dictionary = (
		_safe_dictionary(
			previous_target_surface.get(
				"interaction_contract",
				{}
			)
		)
	)

	var visible_stage: String = str(
		visible_interaction.get(
			"stage",
			""
		)
	).strip_edges().to_lower()

	if visible_stage in [
		"choose_target",
		"choose_body_part"
	]:
		queue_resident_section_projection(
			actor,
			[
				"crime_actions"
			],
			"crime_target_projection_actor_resident"
		)
		return

	if visible_stage == "choose_crime_target":
		target_surface [
			"interaction_contract"
		] = visible_interaction

		target_surface [
			"interaction_stage"
		] = "choose_crime_target"

	surfaces [
		"targets"
	] = target_surface

	section_surfaces_by_actor [
		actor_key
	] = surfaces

	var first_target_surface_publication: bool = (
		previous_target_surface.is_empty()
		or not bool(
			previous_target_surface.get(
				"hydrated",
				false
			)
		)
	)

	if first_target_surface_publication:
		resident_crime_section_contract_published.emit(
			actor_id,
			"targets",
			target_surface.duplicate(
				false
			),
			"crime_target_resident_projection_started"
		)
	else:
		for raw_row in decorated_rows:
			if typeof(
				raw_row
			) != TYPE_DICTIONARY:
				continue

			var row: Dictionary = (
				raw_row as Dictionary
			)

			var target_id: int = int(
				row.get(
					"target_id",
					-1
				)
			)

			if target_id <= 0:
				continue

			var previous_raw: Variant = (
				previous_by_target_id.get(
					str(
						target_id
					),
					{}
				)
			)

			var previous_row: Dictionary = (
				previous_raw as Dictionary
				if typeof(
					previous_raw
				) == TYPE_DICTIONARY
				else {}
			)

			if (
				not previous_row.is_empty()
				and str(
					previous_row
				) == str(
					row
				)
			):
				continue

			resident_crime_section_row_published.emit(
				actor_id,
				"targets",
				row.duplicate(
					false
				),
				"crime_target_resident_projection_delta"
			)






	if (
		complete
		and not first_target_surface_publication
	):
		var completion_surface: Dictionary = (
			target_surface.duplicate(
				false
			)
		)

		completion_surface [
			"stream_completion_only"
		] = true

		completion_surface [
			"target_projection_complete"
		] = true

		completion_surface [
			"projection_pending"
		] = false

		completion_surface [
			"row_count"
		] = decorated_rows.size()

		completion_surface [
			"completed_at_ms"
		] = int(
			Time.get_ticks_msec()
		)

		resident_crime_section_contract_published.emit(
			actor_id,
			"targets",
			completion_surface,
			"crime_target_resident_projection_complete"
		)

	if (
		complete
		and decorated_rows.is_empty()
	):
		resident_crime_section_row_published.emit(
			actor_id,
			"targets",
			{
				"kind": "crime_target_stream_status",
				"label": "NO ELIGIBLE TARGETS",
				"subtitle": (
					"No family target or unrelated stranger "
					+ "is currently resident."
				),
				"actions": [],
				"target_projection_complete": true
			},
			"crime_target_resident_projection_complete_empty"
		)

	queue_resident_section_projection(
		actor,
		[
			"crime_actions"
		],
		"crime_target_projection_actor_resident"
	)
func _target_selection_section_contract(
	actor: Person,
	selection: Dictionary
) -> Dictionary:
	if actor == null:
		return {}

	var target_surface: Dictionary = (
		_crime_section_surface(
			actor,
			"targets",
			{}
		)
	)

	if target_surface.is_empty():
		target_surface = (
			_crime_section_shell(
				"targets",
				false
			)
		)

	var crime_action_id: String = str(
		selection.get(
			"crime_action_id",
			"crime"
		)
	).strip_edges().to_lower()

	var method_id: String = str(
		selection.get(
			"crime_method_id",
			""
		)
	).strip_edges().to_lower()

	var crime_action_label: String = crime_action_id.replace(
		"_",
		""
	).strip_edges().to_upper()

	if crime_action_label == "":
		crime_action_label = "CRIME"

	var same_nation_required: bool = false

	if (
		gs != null
		and gs.crime_contract_engine != null
		and gs.crime_contract_engine.has_method(
			"targeted_crime_requires_same_nation"
		)
	):
		same_nation_required = bool(
			gs.crime_contract_engine
			.targeted_crime_requires_same_nation(
				crime_action_id,
				method_id
			)
		)

	var target_action_key: String = (
		"physical_target_selection_action"
		if same_nation_required
		else "target_selection_action"
	)

	target_surface [
		"interaction_contract"
	] = {
		"schema": (
			"eralife.crime_hub.target_selection_interaction"
		),
		"version": CONTRACT_VERSION,
		"stage": "choose_crime_target",
		"actor_id": int(
			actor.id
		),
		"crime_action_id": crime_action_id,
		"crime_method_id": method_id,
		"title": "CHOOSE A TARGET",
		"subtitle": (
			"%s is armed. Choose who this action is directed at."
			% crime_action_id.replace(
				"_",
				""
			).capitalize()
		),
		"cancel_action": {
			"id": "cancel_crime_target_selection",
			"label": "CANCEL (%s)" % crime_action_label,
			"enabled": true,
			"payload": {
				"action_id": "cancel_crime_target_selection",
				"crime_action_id": crime_action_id,
				"crime_method_id": method_id
			}
		},
		"selected_action": (
			selection.duplicate(false)
		),
		"target_action_key": target_action_key,
		"same_nation_required": same_nation_required,
		"target_access_policy": (
			"same_nation_required_for_physical_crime"
			if same_nation_required
			else "resident_target_identity"
		),
		"ui_is_renderer_only": true
	}

	target_surface [
		"interaction_stage"
	] = "choose_crime_target"
	target_surface [
		"projection_pending"
	] = false
	target_surface [
		"build_on_click"
	] = false

	return target_surface
func _bank_robbery_weapon_section_contract(
	actor: Person
) -> Dictionary:
	if actor == null:
		return {}

	var actor_key: String = str(
		int(
			actor.id
		)
	)

	var surfaces: Dictionary = _safe_dictionary(
		section_surfaces_by_actor.get(
			actor_key,
			{}
		)
	)

	var weapon_surface: Dictionary = _safe_dictionary(
		surfaces.get(
			"weapons",
			{}
		)
	)

	var source_rows: Array = _safe_array(
		weapon_surface.get(
			"section_rows",
			[]
		)
	)

	var projection_pending: bool = bool(
		weapon_surface.get(
			"projection_pending",
			true
		)
	)

	var rows: Array = []

	for raw_row in source_rows:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = (
			(raw_row as Dictionary).duplicate(
				false
			)
		)

		var item: Dictionary = _safe_dictionary(
			row.get(
				"item",
				row
			)
		)

		var weapon_name: String = str(
			item.get(
				"name",
				item.get(
					"display_name",
					row.get(
						"label",
						""
					)
				)
			)
		).strip_edges()

		if weapon_name == "":
			continue

		row [
			"actions"
		] = [
			{
				"id": "commit_bank_robbery",
				"label": "ROB BANK WITH THIS",
				"payload": {
					"action_id": "commit_bank_robbery",
					"crime_action_id": "bank_robbery",
					"weapon_name": weapon_name,
					"source_item": item
				}
			}
		]

		rows.append(
			row
		)

	if rows.is_empty():
		rows.append({
			"kind": "crime_action_status",
			"label": (
				"WEAPONS ARE STILL PUBLISHING"
				if projection_pending
				else "NO OWNED WEAPON"
			),
			"subtitle": (
				"Resident weapon cards will become selectable as they arrive."
				if projection_pending
				else (
					"The current Bank Robbery system requires "
					+ "an owned weapon."
				)
			),
			"actions": []
		})

	return {
		"schema": "eralife.crime_hub_section_surface",
		"version": CONTRACT_VERSION,
		"actor_id": int(
			actor.id
		),
		"section_id": "weapons",
		"title": "BANK ROBBERY — CHOOSE A WEAPON",
		"section_rows": rows,
		"interaction_contract": {
			"stage": "choose_bank_robbery_weapon",
			"crime_action_id": "bank_robbery",
			"title": "BANK ROBBERY",
			"subtitle": (
				"Choose an owned weapon for the attempt."
			)
		},
		"truth_state": "hot",
		"projection_composed": true,
		"hydrated": true,
		"projection_pending": projection_pending,
		"build_on_click": false,
		"population_scan_performed": false,
		"ui_is_renderer_only": true
	}
func _on_crime_weapon_target_projection_access_guarded(
	payload: Dictionary = {}
) -> void:
	var actor_id: int = int(
		payload.get(
			"actor_id",
			-1
		)
	)

	if actor_id <= 0:
		return

	var actor: Person = _resident_actor_by_id(
		actor_id
	)

	if (
		actor == null
		or gs == null
		or gs.crime_contract_engine == null
		or not gs.crime_contract_engine.has_method(
			"decorate_weapon_target_row_for_physical_access"
		)
	):
		_on_crime_weapon_target_projection_published(
			payload
		)
		return

	var guarded_payload: Dictionary = (
		payload.duplicate(false)
	)
	var guarded_rows: Array = []

	for raw_row in _safe_array(
		payload.get(
			"rows",
			[]
		)
	):
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = (
			(raw_row as Dictionary).duplicate(
				false
			)
		)

		if int(
			row.get(
				"target_id",
				-1
			)
		) > 0:
			row = (
				gs.crime_contract_engine
				.decorate_weapon_target_row_for_physical_access(
					actor,
					row
				)
			)

		guarded_rows.append(
			row
		)

	guarded_payload [
		"rows"
	] = guarded_rows
	guarded_payload [
		"physical_target_access_guarded"
	] = true
	guarded_payload [
		"population_scan_performed"
	] = false

	_on_crime_weapon_target_projection_published(
		guarded_payload
	)
func _on_crime_weapon_target_projection_published(
	payload: Dictionary = {}
) -> void:
	var actor_id: int = int(
		payload.get(
			"actor_id",
			-1
		)
	)

	if actor_id <= 0:
		return

	var actor_key: String = str(
		actor_id
	)

	var surfaces: Dictionary = (
		_safe_dictionary(
			section_surfaces_by_actor.get(
				actor_key,
				{}
			)
		)
	)

	var target_surface: Dictionary = (
		_safe_dictionary(
			surfaces.get(
				"targets",
				{}
			)
		)
	)

	if target_surface.is_empty():
		return

	var interaction: Dictionary = (
		_safe_dictionary(
			target_surface.get(
				"interaction_contract",
				{}
			)
		)
	)

	if str(
		interaction.get(
			"stage",
			""
		)
	).strip_edges().to_lower() != "choose_target":
		return

	var incoming_rows: Array = _safe_array(
		payload.get(
			"rows",
			[]
		)
	)

	var complete: bool = bool(
		payload.get(
			"complete",
			false
		)
	)

	var signature: String = str(
		payload.get(
			"signature",
			""
		)
	)

	var rows: Array = _safe_array(
		interaction.get(
			"rows",
			target_surface.get(
				"section_rows",
				[]
			)
		)
	)

	if not incoming_rows.is_empty():
		var retained_rows: Array = []

		for raw_existing in rows:
			var existing: Dictionary = _safe_dictionary(
				raw_existing
			)

			if str(
				existing.get(
					"kind",
					""
				)
			).strip_edges().to_lower() == (
				"crime_target_stream_status"
			):
				continue

			retained_rows.append(
				existing
			)

		rows = retained_rows

	var rows_to_publish: Array = []

	for raw_incoming in incoming_rows:
		var incoming: Dictionary = _safe_dictionary(
			raw_incoming
		)

		var target_id: int = int(
			incoming.get(
				"target_id",
				-1
			)
		)

		if target_id <= 0:
			continue

		var replaced: bool = false

		for index in range(
			rows.size()
		):
			var existing: Dictionary = _safe_dictionary(
				rows [
					index
				]
			)

			if int(
				existing.get(
					"target_id",
					-1
				)
			) != target_id:
				continue

			rows [
				index
			] = incoming

			replaced = true
			break

		if not replaced:
			rows.append(
				incoming
			)

		rows_to_publish.append(
			incoming
		)

	if complete:
		var real_target_count: int = 0
		var completion_rows: Array = []

		for raw_existing in rows:
			var existing: Dictionary = _safe_dictionary(
				raw_existing
			)

			if int(
				existing.get(
					"target_id",
					-1
				)
			) > 0:
				real_target_count += 1

				completion_rows.append(
					existing
				)

		rows = completion_rows

		if real_target_count <= 0:
			var no_target_row: Dictionary = {
				"kind": "crime_target_stream_status",
				"label": "No eligible targets are observable.",
				"subtitle": (
					"No relationship target or unrelated "
					+ "stranger is currently available."
				),
				"actions": [],
				"target_projection_complete": true,
				"target_projection_pending": false
			}

			rows.append(
				no_target_row
			)

			rows_to_publish.append(
				no_target_row
			)

	interaction [
		"rows"
	] = rows
	interaction [
		"target_projection_complete"
	] = complete
	interaction [
		"target_projection_pending"
	] = not complete
	interaction [
		"relationship_target_count"
	] = int(
		payload.get(
			"relationship_target_count",
			interaction.get(
				"relationship_target_count",
				0
			)
		)
	)
	interaction [
		"random_stranger_count"
	] = int(
		payload.get(
			"random_stranger_count",
			interaction.get(
				"random_stranger_count",
				0
			)
		)
	)
	interaction [
		"target_projection_signature"
	] = signature

	target_surface [
		"section_rows"
	] = rows
	target_surface [
		"interaction_contract"
	] = interaction
	target_surface [
		"projection_pending"
	] = not complete
	target_surface [
		"updated_at_ms"
	] = int(
		Time.get_ticks_msec()
	)

	surfaces [
		"targets"
	] = target_surface

	section_surfaces_by_actor [
		actor_key
	] = surfaces

	for row_to_publish in rows_to_publish:
		resident_crime_section_row_published.emit(
			actor_id,
			"targets",
			row_to_publish,
			"crime_weapon_target_projection"
		)

	if complete:
		resident_crime_section_contract_published.emit(
			actor_id,
			"targets",
			target_surface.duplicate(
				false
			),
			"crime_weapon_target_projection_complete"
		)
func resolve_intent(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _failure(
			"missing_actor",
			"Crime Hub requires an actor."
		)
	var action_id: String = str(
		payload.get(
			"action_id",
			"open_hub"
		)
	).strip_edges().to_lower()
	var section_id: String = _section(
		str(
			payload.get(
				"section_id",
				"overview"
			)
		)
	)
	var actor_key: String = str(
		int(
			actor.id
		)
	)
	match action_id:
		"open_hub", "refresh", "prewarm_hub":
			var projection_context: Dictionary = (
				payload.duplicate(false)
			)
			var refresh_all_sections: bool = bool(
				payload.get(
					"refresh_all_sections",
					action_id == "prewarm_hub"
				)
			)
			var requested_sections: Array = _safe_array(
				payload.get(
					"refresh_sections",
					[]
				)
			)
			if (
				not refresh_all_sections
				and requested_sections.is_empty()
			):
				requested_sections = [
					section_id
				]
			projection_context [
				"refresh_all_sections"
			] = refresh_all_sections
			projection_context [
				"refresh_sections"
			] = requested_sections
			projection_context [
				"active_section_only"
			] = not refresh_all_sections
			projection_context [
				"remaining_sections_are_resident_shells"
			] = not refresh_all_sections
			projection_context [
				"all_sections_precomposed"
			] = refresh_all_sections
			projection_context [
				"section_projection_ready_gate_member"
			] = false
			projection_context [
				"build_on_click"
			] = false
			projection_context [
				"engine_call_on_section_click"
			] = false
			return {
				"success": true,
				"mode": (
					"crime_hub_resident_projection"
					if refresh_all_sections
					else "crime_hub_projection"
				),
				"open_crime_hub": (
					action_id != "prewarm_hub"
				),
				"prewarm_only": (
					action_id == "prewarm_hub"
				),
				"hub_contract": emit_hub_contract(
					actor,
					section_id,
					projection_context
				)
			}
		"change_section":
			return {
				"success": true,
				"mode": "crime_hub_section_observed",
				"open_crime_hub": true,
				"crime_hub_section": section_id,
				"ui_is_renderer_only": true
			}
		"select_crime_action":
			var crime_action_id: String = str(
				payload.get(
					"crime_action_id",
					""
				)
			).strip_edges().to_lower()
			var crime_method_id: String = str(
				payload.get(
					"crime_method_id",
					""
				)
			).strip_edges().to_lower()
			if crime_action_id not in [
				"murder",
				"assault"
			]:
				return _failure(
					"crime_action_not_targetable",
					(
						"The selected crime action does not "
						+ "use a person target."
					)
				)
			if (
				crime_action_id == "murder"
				and crime_method_id not in [
					"poison",
					"direct_attack",
					"attack"
				]
			):
				return _failure(
					"murder_method_unavailable",
					"Choose a valid murder method first."
				)
			var selection: Dictionary = {
				"actor_id": int(
					actor.id
				),
				"crime_action_id": crime_action_id,
				"crime_method_id": crime_method_id,
				"selected_at_ms": int(
					Time.get_ticks_msec()
				),
				"ui_is_renderer_only": false
			}
			selected_crime_action_by_actor [
				actor_key
			] = selection
			var target_surface: Dictionary = (
				_target_selection_section_contract(
					actor,
					selection
				)
			)
			var surfaces: Dictionary = _safe_dictionary(
				section_surfaces_by_actor.get(
					actor_key,
					{}
				)
			)
			surfaces [
				"targets"
			] = target_surface
			section_surfaces_by_actor [
				actor_key
			] = surfaces
			return {
				"success": true,
				"mode": "crime_action_target_selection",
				"open_crime_hub": true,
				"crime_hub_section": "targets",
				"selected_action": selection,
				"section_contract": target_surface,
				"population_scan_performed": false,
				"build_on_press": false,
				"blocks_ui": false
			}
		"cancel_crime_target_selection":
			var cancelled_selection: Dictionary = _safe_dictionary(
				selected_crime_action_by_actor.get(
					actor_key,
					{}
				)
			)
			selected_crime_action_by_actor.erase(
				actor_key
			)
			var target_surface: Dictionary = _safe_dictionary(
				resident_target_identity_contract_by_actor.get(
					actor_key,
					{}
				)
			)
			if target_surface.is_empty():
				target_surface = _crime_section_surface(
					actor,
					"targets",
					{}
				)
			target_surface [
				"interaction_contract"
			] = {}
			target_surface [
				"interaction_stage"
			] = ""
			target_surface [
				"build_on_click"
			] = false
			var surfaces: Dictionary = _safe_dictionary(
				section_surfaces_by_actor.get(
					actor_key,
					{}
				)
			)
			surfaces [
				"targets"
			] = target_surface
			section_surfaces_by_actor [
				actor_key
			] = surfaces
			return {
				"success": true,
				"mode": "crime_action_target_selection_cancelled",
				"open_crime_hub": true,
				"crime_hub_section": "targets",
				"cancelled_selection": cancelled_selection,
				"section_contract": target_surface,
				"population_scan_performed": false,
				"build_on_press": false,
				"blocks_ui": false
			}
		"choose_crime_target":
			var selection_raw: Variant = (
				selected_crime_action_by_actor.get(
					actor_key,
					{}
				)
			)
			var selection: Dictionary = (
				selection_raw as Dictionary
				if typeof(selection_raw) == TYPE_DICTIONARY
				else {}
			)
			if selection.is_empty():
				return _failure(
					"crime_action_not_selected",
					"You can’t select a target without a crime in mind"
				)
			if (
				gs == null
				or gs.crime_contract_engine == null
			):
				return _failure(
					"crime_contract_engine_unavailable",
					"CrimeContractEngine is unavailable."
				)
			var commit_payload: Dictionary = (
				payload.duplicate(false)
			)
			commit_payload [
				"action_id"
			] = "commit_targeted_crime_action"
			commit_payload [
				"crime_action_id"
			] = str(
				selection.get(
					"crime_action_id",
					""
				)
			)
			commit_payload [
				"crime_method_id"
			] = str(
				selection.get(
					"crime_method_id",
					""
				)
			)
			commit_payload [
				"immutable_contract_references"
			] = true
			var action_report: Dictionary = (
				gs.crime_contract_engine
				.resolve_intent(
					actor,
					commit_payload
				)
			)
			if bool(
				action_report.get(
					"success",
					false
				)
			):
				selected_crime_action_by_actor.erase(
					actor_key
				)
				queue_resident_section_projection(
					actor,
					[
						"targets",
						"crime_actions",
						"overview",
						"cases",
						"pending",
						"custody"
					],
					"targeted_crime_action_committed"
				)
			return {
				"success": bool(
					action_report.get(
						"success",
						false
					)
				),
				"mode": (
					"crime_hub_targeted_crime_action"
				),
				"open_crime_hub": true,
				"crime_hub_section": "targets",
				"action_report": action_report,
				"result": action_report,
				"hub_contract": {},
				"background_projection_queued": bool(
					action_report.get(
						"success",
						false
					)
				),
				"blocks_ui": false
			}
		"open_crime_weapon_picker":
			selected_crime_action_by_actor.erase(
				actor_key
			)
			var weapon_surface: Dictionary = (
				_crime_section_surface(
					actor,
					"weapons",
					{}
				)
			)
			return {
				"success": true,
				"mode": "crime_weapon_picker",
				"open_crime_hub": true,
				"crime_hub_section": "weapons",
				"section_contract": weapon_surface,
				"build_on_press": false,
				"blocks_ui": false
			}
		"open_bank_robbery_weapon_picker":
			var bank_surface: Dictionary = (
				_bank_robbery_weapon_section_contract(
					actor
				)
			)
			return {
				"success": true,
				"mode": "bank_robbery_weapon_picker",
				"open_crime_hub": true,
				"crime_hub_section": "weapons",
				"section_contract": bank_surface,
				"population_scan_performed": false,
				"blocks_ui": false
			}
		"commit_bank_robbery":
			if (
				gs == null
				or gs.crime_contract_engine == null
			):
				return _failure(
					"crime_contract_engine_unavailable",
					"CrimeContractEngine is unavailable."
				)
			var robbery_payload: Dictionary = (
				payload.duplicate(false)
			)
			robbery_payload [
				"action_id"
			] = "commit_bank_robbery"
			var robbery_report: Dictionary = (
				gs.crime_contract_engine
				.resolve_intent(
					actor,
					robbery_payload
				)
			)
			if bool(
				robbery_report.get(
					"success",
					false
				)
			):
				queue_resident_section_projection(
					actor,
					[
						"crime_actions",
						"weapons",
						"overview",
						"cases",
						"pending",
						"custody"
					],
					"bank_robbery_committed"
				)
			return {
				"success": bool(
					robbery_report.get(
						"success",
						false
					)
				),
				"mode": "crime_hub_bank_robbery",
				"open_crime_hub": true,
				"crime_hub_section": "crime_actions",
				"action_report": robbery_report,
				"result": robbery_report,
				"hub_contract": {},
				"background_projection_queued": bool(
					robbery_report.get(
						"success",
						false
					)
				),
				"blocks_ui": false
			}
		"begin_weapon_action", \
"choose_weapon_target", \
"commit_weapon_action":
			if (
				gs == null
				or gs.crime_contract_engine == null
			):
				return _failure(
					"crime_contract_engine_unavailable",
					"CrimeContractEngine is unavailable."
				)
			var action_report: Dictionary = (
				gs.crime_contract_engine
				.resolve_intent(
					actor,
					payload
				)
			)
			var interaction_contract: Dictionary = (
				_safe_dictionary(
					action_report.get(
						"interaction_contract",
						{}
					)
				)
			)
			if action_id in [
				"begin_weapon_action",
				"choose_weapon_target"
			]:
				var section_contract: Dictionary = (
					_weapon_interaction_section_contract(
						actor,
						interaction_contract,
						action_report
					)
				)
				return {
					"success": bool(
						action_report.get(
							"success",
							false
						)
					),
					"mode": (
						"crime_hub_weapon_action"
					),
					"open_crime_hub": true,
					"crime_hub_section": "targets",
					"interaction_contract": (
						interaction_contract
					),
					"section_contract": (
						section_contract
					),
					"action_report": action_report,
					"result": action_report,
					"hub_contract": {},
					"blocks_ui": false
				}
			if bool(
				action_report.get(
					"success",
					false
				)
			):
				queue_resident_section_projection(
					actor,
					[
						"targets",
						"weapons",
						"overview",
						"cases",
						"pending"
					],
					"weapon_crime_action_committed"
				)
			return {
				"success": bool(
					action_report.get(
						"success",
						false
					)
				),
				"mode": "crime_hub_weapon_action",
				"open_crime_hub": true,
				"crime_hub_section": "weapons",
				"interaction_contract": {},
				"section_contract": {},
				"action_report": action_report,
				"result": action_report,
				"hub_contract": {},
				"background_projection_queued": bool(
					action_report.get(
						"success",
						false
					)
				),
				"blocks_ui": false
			}
		"prison_activity":
			if (
				gs == null
				or gs.prison_engine == null
			):
				return _failure(
					"prison_engine_unavailable",
					"PrisonEngine is unavailable."
				)
			var prison_report: Dictionary = (
				gs.prison_engine
				.resolve_prison_activity(
					actor,
					payload
				)
			)
			if bool(
				prison_report.get(
					"success",
					false
				)
			):
				queue_resident_section_projection(
					actor,
					[
						"prison",
						"overview",
						"custody",
						"population",
						"family"
					],
					"prison_activity"
				)
			return {
				"success": bool(
					prison_report.get(
						"success",
						false
					)
				),
				"mode": "crime_hub_prison_activity",
				"open_crime_hub": true,
				"result": prison_report,
				"hub_contract": {},
				"blocks_ui": false
			}
		_:
			return _failure(
				"unsupported_crime_hub_intent",
				(
					"Crime Hub does not support '%s'."
					% action_id
				)
			)
func _weapon_interaction_section_contract(
	actor: Person,
	interaction_contract: Dictionary,
	action_report: Dictionary
) -> Dictionary:
	if actor == null:
		return {}

	var actor_key: String = str(
		int(
			actor.id
		)
	)

	var surfaces: Dictionary = (
		_safe_dictionary(
			section_surfaces_by_actor.get(
				actor_key,
				{}
			)
		)
	)

	var target_surface: Dictionary = (
		_safe_dictionary(
			surfaces.get(
				"targets",
				{}
			)
		)
	)

	if target_surface.is_empty():
		target_surface = (
			_crime_section_shell(
				"targets",
				false
			)
		)

	var interaction_stage: String = str(
		interaction_contract.get(
			"stage",
			""
		)
	).strip_edges().to_lower()

	var target_projection_pending: bool = bool(
		interaction_contract.get(
			"target_projection_pending",
			interaction_stage == "choose_target"
		)
	)

	target_surface [
		"actor_id"
	] = int(
		actor.id
	)
	target_surface [
		"section_id"
	] = "targets"
	target_surface [
		"section_rows"
	] = _safe_array(
		interaction_contract.get(
			"rows",
			[]
		)
	)
	target_surface [
		"interaction_contract"
	] = interaction_contract
	target_surface [
		"interaction_stage"
	] = interaction_stage
	target_surface [
		"action_report"
	] = action_report
	target_surface [
		"truth_state"
	] = "hot"
	target_surface [
		"hydrated"
	] = true
	target_surface [
		"projection_pending"
	] = target_projection_pending
	target_surface [
		"interaction_surface_has_sovereignty"
	] = interaction_stage in [
		"choose_target",
		"choose_body_part"
	]
	target_surface [
		"resident_generic_projection_may_not_overwrite"
	] = interaction_stage in [
		"choose_target",
		"choose_body_part"
	]
	target_surface [
		"build_on_click"
	] = false
	target_surface [
		"updated_at_ms"
	] = int(
		Time.get_ticks_msec()
	)

	surfaces [
		"targets"
	] = target_surface

	section_surfaces_by_actor [
		actor_key
	] = surfaces

	return target_surface
func queue_resident_section_projection(
	actor: Person,
	section_ids: Array,
	source: String = "crime_background_projection"
) -> void:
	if actor == null:
		return

	var actor_id: int = int(
		actor.id
	)

	if actor_id <= 0:
		return

	for raw_section_id in section_ids:
		var section_id: String = _section(
			str(
				raw_section_id
			)
		)

		if section_id == "":
			continue

		var queue_key: String = (
			"%d:%s"
			% [
				actor_id,
				section_id
			]
		)

		if resident_section_projection_keys.has(
			queue_key
		):
			continue

		resident_section_projection_keys [
			queue_key
		] = true

		var queue_slot: int = (
			resident_section_projection_queue_tail
		)

		resident_section_projection_queue_tail += 1

		resident_section_projection_queue [
			queue_slot
		] = {
			"actor_id": actor_id,
			"section_id": section_id,
			"queue_key": queue_key,
			"source": source,
			"queued_at_ms": int(
				Time.get_ticks_msec()
			)
		}

		_crime_hub_truth_probe(
			"section_projection_queued",
			{
				"actor_id": actor_id,
				"section": section_id,
				"queue_depth": (
					resident_section_projection_queue.size()
				),
				"source": source
			}
		)

	_arm_resident_section_projection_service()
func _arm_resident_section_projection_service() -> void:
	if (
		resident_section_projection_queue_head
		>= resident_section_projection_queue_tail
	):
		resident_section_projection_service_active = false
		return

	resident_section_projection_service_active = true
	_arm_crime_background_aggregate_service()

	_crime_hub_truth_probe(
		"section_service_lease_acquired",
		{
			"queue_depth": (
				resident_section_projection_queue.size()
			),
		}
	)
func _drive_resident_section_projection_process_frame() -> void:
	var tree:= Engine.get_main_loop() as SceneTree
	var callback:= Callable(
		self,
		"_drive_resident_section_projection_process_frame"
	)

	if (
		resident_section_projection_queue_head
		>= resident_section_projection_queue_tail
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

		resident_section_projection_service_active = false
		return

	var request_raw: Variant = (
		resident_section_projection_queue.get(
			resident_section_projection_queue_head,
			{}
		)
	)

	var request: Dictionary = (
		request_raw as Dictionary
		if typeof(
			request_raw
		) == TYPE_DICTIONARY
		else {}
	)

	_crime_hub_truth_probe(
		"section_service_entered",
		{
			"actor_id": int(
				request.get(
					"actor_id",
					-1
				)
			),
			"section": str(
				request.get(
					"section_id",
					""
				)
			),
			"source": str(
				request.get(
					"source",
					""
				)
			),
			"queue_depth": (
				resident_section_projection_queue.size()
			)
		}
	)

	_service_resident_section_projection_queue()

	if (
		resident_section_projection_queue_head
		>= resident_section_projection_queue_tail
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

		resident_section_projection_service_active = false
	else:
		resident_section_projection_service_active = true
func _service_resident_section_projection_queue() -> void:
	resident_section_projection_service_active = false

	if (
		resident_section_projection_queue_head
		>= resident_section_projection_queue_tail
	):
		resident_section_projection_queue.clear()
		resident_section_projection_queue_head = 0
		resident_section_projection_queue_tail = 0
		return

	var queue_slot: int = (
		resident_section_projection_queue_head
	)

	resident_section_projection_queue_head += 1

	var request_raw: Variant = (
		resident_section_projection_queue.get(
			queue_slot,
			{}
		)
	)

	resident_section_projection_queue.erase(
		queue_slot
	)

	var request: Dictionary = (
		request_raw as Dictionary
		if typeof(request_raw) == TYPE_DICTIONARY
		else {}
	)

	var queue_key: String = str(
		request.get(
			"queue_key",
			""
		)
	)

	if queue_key != "":
		resident_section_projection_keys.erase(
			queue_key
		)

	var actor_id: int = int(
		request.get(
			"actor_id",
			-1
		)
	)

	var actor: Person = _resident_actor_by_id(
		actor_id
	)

	if actor == null:
		_arm_resident_section_projection_service()
		return

	var section_id: String = _section(
		str(
			request.get(
				"section_id",
				"overview"
			)
		)
	)

	var request_source: String = str(
		request.get(
			"source",
			"crime_background_projection"
		)
	).strip_edges().to_lower()

	var actor_key: String = str(
		actor_id
	)

	var surfaces_raw: Variant = (
		section_surfaces_by_actor.get(
			actor_key,
			{}
		)
	)

	var surfaces: Dictionary = (
		(surfaces_raw as Dictionary).duplicate(false)
		if typeof(surfaces_raw) == TYPE_DICTIONARY
		else {}
	)

	if section_id == "weapons":
		var current_weapon_raw: Variant = surfaces.get(
			"weapons",
			{}
		)

		var current_weapon_surface: Dictionary = (
			(current_weapon_raw as Dictionary).duplicate(false)
			if typeof(current_weapon_raw) == TYPE_DICTIONARY
			else {}
		)

		var interaction_stage: String = str(
			current_weapon_surface.get(
				"interaction_stage",
				""
			)
		).strip_edges().to_lower()

		var interaction_has_sovereignty: bool = (
			interaction_stage in [
				"choose_target",
				"choose_body_part"
			]
		)

		if (
			interaction_has_sovereignty
			and request_source != "weapon_crime_action_committed"
		):
			_arm_resident_section_projection_service()
			return

	if section_id in [
		"weapons",
		"cases"
	]:
		_begin_resident_heavy_section_projection(
			actor,
			section_id,
			request_source
		)

		_arm_resident_section_projection_service()
		return

	var prison_contract: Dictionary = {}

	if (
		section_id in [
			"overview",
			"custody",
			"prison",
			"population",
			"family"
		]
		and _crime_actor_is_incarcerated_resident(
			actor
		)
	):
		prison_contract = (
			_prison_contract_for_actor(
				actor,
				section_id == "population"
			)
		)

	var section_contract: Dictionary = (
		_crime_section_surface(
			actor,
			section_id,
			prison_contract,
			true
		)
	)

	var projected_world_year: int = (
		int(
			gs.year
		)
		if gs != null
		else 0
	)

	var projected_actor_age: int = maxi(
		0,
		int(
			actor.age
		)
	)

	section_contract [
		"projected_world_year"
	] = projected_world_year

	section_contract [
		"projected_actor_age"
	] = projected_actor_age

	section_contract [
		"temporal_truth_revision"
	] = (
		"%d:%d:%d:%s"
		% [
			actor_id,
			projected_world_year,
			projected_actor_age,
			section_id
		]
	)

	section_contract [
		"temporal_truth_authority"
	] = "Person+GameState"

	section_contract [
		"temporal_projection_mutates_actor"
	] = false

	surfaces [
		section_id
	] = section_contract

	section_surfaces_by_actor [
		actor_key
	] = surfaces

	resident_crime_section_contract_published.emit(
		actor_id,
		section_id,
		section_contract,
		request_source
	)

	if (
		resident_section_projection_queue_head
		>= resident_section_projection_queue_tail
	):
		resident_section_projection_queue.clear()
		resident_section_projection_queue_head = 0
		resident_section_projection_queue_tail = 0

	_arm_resident_section_projection_service()
func _crime_weapon_row_from_raw_belonging(
	category: String,
	raw_item: Dictionary
) -> Dictionary:
	if raw_item.is_empty():
		return {}

	var clean_category: String = str(
		category
	).strip_edges()

	var item_type: String = str(
		raw_item.get(
			"type",
			""
		)
	).strip_edges().to_lower()

	var asset_kind: String = str(
		raw_item.get(
			"asset_kind",
			""
		)
	).strip_edges().to_lower()

	var weapon_contract: Dictionary = _safe_dictionary(
		raw_item.get(
			"weapon_contract",
			{}
		)
	)

	var is_weapon: bool = (
		clean_category.to_lower() == "weapons"
		or item_type == "weapon"
		or asset_kind == "weapon"
		or not weapon_contract.is_empty()
	)

	if not is_weapon:
		for raw_domain in _safe_array(
			raw_item.get(
				"object_domains",
				[]
			)
		):
			if str(
				raw_domain
			).strip_edges().to_lower() != "weapon":
				continue

			is_weapon = true
			break

	if not is_weapon:
		return {}

	var item: Dictionary = raw_item.duplicate(
		false
	)

	var display_name: String = str(
		item.get(
			"display_name",
			item.get(
				"name",
				"Weapon"
			)
		)
	).strip_edges()

	if display_name == "":
		display_name = "Weapon"

	var type_label: String = str(
		item.get(
			"type",
			"Weapon"
		)
	).strip_edges()

	if type_label == "":
		type_label = "Weapon"

	var value: int = int(
		item.get(
			"value",
			item.get(
				"price",
				0
			)
		)
	)

	var row: Dictionary = {
		"kind": "inventory_item",
		"category": clean_category,
		"item_id": str(
			item.get(
				"id",
				""
			)
		),
		"contract_id": str(
			item.get(
				"contract_id",
				""
			)
		),
		"value": value,
		"label": "%s • %s • value %d" % [
			display_name,
			type_label,
			value
		],
		"subtitle": str(
			item.get(
				"legal_classification",
				"Owned weapon"
			)
		).capitalize(),
		"identity": _safe_dictionary(
			item.get(
				"identity",
				item.get(
					"reality_identity",
					{}
				)
			)
		),
		"affordances": _safe_array(
			item.get(
				"affordances",
				[]
			)
		),
		"relationships": _safe_dictionary(
			item.get(
				"relationships",
				{}
			)
		),
		"item": item,
		"ui_is_renderer_only": true
	}


	var actions: Array = _safe_array(
		item.get(
			"actions",
			[]
		)
	).duplicate(
		false
	)



	if actions.is_empty():
		var behavior_contract: Dictionary = _safe_dictionary(
			item.get(
				"behavior_contract",
				{}
			)
		)

		actions = _safe_array(
			behavior_contract.get(
				"actions",
				[]
			)
		).duplicate(
			false
		)




	var projected_weapon_action_ids: Dictionary = {}

	for raw_existing_action in actions:
		if typeof(raw_existing_action) != TYPE_DICTIONARY:
			continue

		var existing_action: Dictionary = (
			raw_existing_action as Dictionary
		)

		var existing_payload: Dictionary = _safe_dictionary(
			existing_action.get(
				"payload",
				{}
			)
		)

		if str(
			existing_payload.get(
				"action_id",
				""
			)
		).strip_edges().to_lower() != "begin_weapon_action":
			continue

		var existing_weapon_action_id: String = str(
			existing_payload.get(
				"weapon_action_id",
				""
			)
		).strip_edges().to_lower()

		if existing_weapon_action_id == "":
			continue

		projected_weapon_action_ids [
			existing_weapon_action_id
		] = true








	if not weapon_contract.is_empty():
		var weapon_name: String = str(
			item.get(
				"name",
				item.get(
					"display_name",
					display_name
				)
			)
		).strip_edges()

		if weapon_name == "":
			weapon_name = display_name

		for raw_weapon_action in _safe_array(
			weapon_contract.get(
				"actions",
				[]
			)
		):
			if typeof(raw_weapon_action) != TYPE_DICTIONARY:
				continue

			var weapon_action: Dictionary = (
				raw_weapon_action as Dictionary
			)

			var weapon_action_id: String = str(
				weapon_action.get(
					"id",
					""
				)
			).strip_edges().to_lower()

			if (
				weapon_action_id == ""
				or projected_weapon_action_ids.has(
					weapon_action_id
				)
			):
				continue

			actions.append({
				"id": "weapon_%s" % weapon_action_id,
				"label": str(
					weapon_action.get(
						"label",
						weapon_action_id.capitalize()
					)
				),
				"engine_property": "crime_hub_contract_engine",
				"method": "resolve_intent",
				"call_mode": "player_payload",
				"refresh_after": true,
				"payload": {
					"action_id": "begin_weapon_action",
					"catalog_object_id": str(
						item.get(
							"catalog_object_id",
							""
						)
					),
					"instance_object_id": str(
						item.get(
							"instance_object_id",
							""
						)
					),
					"weapon_name": weapon_name,
					"weapon_action_id": weapon_action_id,
					"source_item": item.duplicate(
						false
					),
					"weapon_contract": weapon_contract.duplicate(
						false
					),
					"source": "crime_hub.weapon_contract_projection",
					"immutable_contract_references": true
				}
			})

			projected_weapon_action_ids [
				weapon_action_id
			] = true

	if not actions.is_empty():
		row [
			"actions"
		] = actions

	return row

func _crime_case_row_from_raw_case(
	actor_id: int,
	case_data: Dictionary
) -> Dictionary:
	if (
		actor_id <= 0
		or case_data.is_empty()
	):
		return {}

	var participants: Dictionary = _safe_dictionary(
		case_data.get(
			"participants",
			{}
		)
	)

	if int(
		participants.get(
			"accused",
			-1
		)
	) != actor_id:
		return {}

	var crime: Dictionary = _safe_dictionary(
		case_data.get(
			"crime",
			{}
		)
	)

	return {
		"kind": "crime_case_card",
		"label": str(
			crime.get(
				"name",
				crime.get(
					"type",
					"Crime Case"
				)
			)
		),
		"subtitle": "%s • %s" % [
			str(
				case_data.get(
					"status",
					"pending"
				)
			).capitalize(),
			str(
				case_data.get(
					"case_id",
					""
				)
			)
		],
		"case": case_data.duplicate(
			false
		),
		"ui_is_renderer_only": true
	}


func _begin_resident_heavy_section_projection(
	actor: Person,
	section_id: String,
	source: String
) -> void:
	if actor == null:
		return

	var clean_section: String = _section(
		section_id
	)

	if clean_section not in [
		"weapons",
		"cases"
	]:
		return

	var actor_id: int = int(
		actor.id
	)

	if actor_id <= 0:
		return

	var job_key: String = (
		"%d:%s"
		% [
			actor_id,
			clean_section
		]
	)

	var projection_already_in_flight: bool = (
		resident_heavy_section_projection_state_by_key.has(
			job_key
		)
	)

	var actor_key: String = str(
		actor_id
	)
	var surfaces_raw: Variant = (
		section_surfaces_by_actor.get(
			actor_key,
			{}
		)
	)
	var surfaces: Dictionary = (
		(surfaces_raw as Dictionary).duplicate(false)
		if typeof(surfaces_raw) == TYPE_DICTIONARY
		else {}
	)




	if not projection_already_in_flight:
		var pending_surface: Dictionary = (
			_crime_section_shell(
				clean_section,
				false
			)
		)

		pending_surface [
			"actor_id"
		] = actor_id
		pending_surface [
			"truth_state"
		] = "hot"
		pending_surface [
			"projection_composed"
		] = true
		pending_surface [
			"hydrated"
		] = true
		pending_surface [
			"projection_pending"
		] = true
		pending_surface [
			"progressive_observability"
		] = true
		pending_surface [
			"status_text"
		] = (
			"Resident weapons are streaming live."
			if clean_section == "weapons"
			else "Resident crime cases are streaming live."
		)
		pending_surface [
			"updated_at_ms"
		] = int(
			Time.get_ticks_msec()
		)

		surfaces [
			clean_section
		] = pending_surface
		section_surfaces_by_actor [
			actor_key
		] = surfaces

		resident_crime_section_contract_published.emit(
			actor_id,
			clean_section,
			pending_surface.duplicate(false),
			"%s:started" % source
		)

	var state: Dictionary = {
		"job_key": job_key,
		"actor_id": actor_id,
		"section_id": clean_section,
		"source": source,
		"rows": [],
		"row_keys": {},
		"started_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	if clean_section == "weapons":
		var inventory: Dictionary = {}

		if (
			gs != null
			and gs.belongings_engine != null
		):
			inventory = (
				gs.belongings_engine.get_inventory(
					actor
				)
			)

		state [
			"inventory"
		] = inventory
		state [
			"categories"
		] = inventory.keys()
		state [
			"category_cursor"
		] = 0
		state [
			"item_cursor"
		] = 0
	else:



		state [
			"case_cursor"
		] = 0




	resident_heavy_section_projection_state_by_key [
		job_key
	] = state

	_queue_resident_heavy_section_projection_job(
		job_key
	)
func _queue_resident_heavy_section_projection_job(
	job_key: String
) -> void:
	var clean_key: String = str(
		job_key
	).strip_edges()

	if clean_key == "":
		return

	if resident_heavy_section_projection_keys.has(
		clean_key
	):



		if (
			resident_heavy_section_projection_queue_head
			< resident_heavy_section_projection_queue_tail
		):
			_arm_resident_heavy_section_projection_service()
			return


		resident_heavy_section_projection_keys.erase(
			clean_key
		)

	resident_heavy_section_projection_keys [
		clean_key
	] = true

	var queue_slot: int = (
		resident_heavy_section_projection_queue_tail
	)

	resident_heavy_section_projection_queue_tail += 1

	resident_heavy_section_projection_queue [
		queue_slot
	] = clean_key

	_arm_resident_heavy_section_projection_service()


func _arm_resident_heavy_section_projection_service() -> void:
	if (
		resident_heavy_section_projection_queue_head
		>= resident_heavy_section_projection_queue_tail
	):
		resident_heavy_section_projection_service_active = false
		return

	resident_heavy_section_projection_service_active = true
	_arm_crime_background_aggregate_service()

	_crime_hub_truth_probe(
		"heavy_section_service_lease_acquired",
		{
			"queue_depth": (
				resident_heavy_section_projection_queue.size()
			),
		}
	)
func _crime_background_aggregate_has_pending_work() -> bool:
	return (
		resident_observer_replay_queue_head
		< resident_observer_replay_queue_tail
		or resident_section_projection_queue_head
		< resident_section_projection_queue_tail
		or resident_heavy_section_projection_queue_head
		< resident_heavy_section_projection_queue_tail
	)


func _arm_crime_background_aggregate_service() -> void:
	if not _crime_background_aggregate_has_pending_work():
		set_meta(
			"crime_background_aggregate_service_active",
			false
		)
		return

	var tree:= Engine.get_main_loop() as SceneTree
	if tree == null:
		set_meta(
			"crime_background_aggregate_service_active",
			false
		)
		return



	if not bool(
		get_meta(
			"crime_background_legacy_leases_retired",
			false
		)
	):
		for legacy_method in [
			"_drive_resident_observer_replay_process_frame",
			"_drive_resident_section_projection_process_frame",
			"_drive_resident_heavy_section_projection_process_frame"
		]:
			var legacy_callback:= Callable(
				self,
				str(legacy_method)
			)
			if tree.process_frame.is_connected(
				legacy_callback
			):
				tree.process_frame.disconnect(
					legacy_callback
				)

		set_meta(
			"crime_background_legacy_leases_retired",
			true
		)

	var callback:= Callable(
		self,
		"_drive_crime_background_aggregate_process_frame"
	)
	if tree.process_frame.is_connected(callback):
		set_meta(
			"crime_background_aggregate_service_active",
			true
		)
		return

	tree.process_frame.connect(callback)
	set_meta(
		"crime_background_aggregate_service_active",
		true
	)


func _drive_crime_background_aggregate_process_frame() -> void:
	var tree:= Engine.get_main_loop() as SceneTree
	var callback:= Callable(
		self,
		"_drive_crime_background_aggregate_process_frame"
	)

	if (
		tree != null
		and tree.process_frame.is_connected(callback)
	):
		tree.process_frame.disconnect(callback)

	set_meta(
		"crime_background_aggregate_service_active",
		false
	)

	var lanes: Array = [
		"observer",
		"section",
		"heavy"
	]
	var lane_cursor: int = posmod(
		int(
			get_meta(
				"crime_background_aggregate_lane_cursor",
				0
			)
		),
		lanes.size()
	)
	var serviced_lane: String = ""

	for offset in range(lanes.size()):
		var lane_index: int = posmod(
			lane_cursor + offset,
			lanes.size()
		)
		var lane_id: String = str(
			lanes [lane_index]
		)
		var lane_pending: bool = false

		match lane_id:
			"observer":
				lane_pending = (
					resident_observer_replay_queue_head
					< resident_observer_replay_queue_tail
				)
			"section":
				lane_pending = (
					resident_section_projection_queue_head
					< resident_section_projection_queue_tail
				)
			"heavy":
				lane_pending = (
					resident_heavy_section_projection_queue_head
					< resident_heavy_section_projection_queue_tail
				)

		if not lane_pending:
			continue

		serviced_lane = lane_id
		set_meta(
			"crime_background_aggregate_lane_cursor",
			posmod(
				lane_index + 1,
				lanes.size()
			)
		)

		match lane_id:
			"observer":
				_service_resident_observer_replay_queue()
			"section":
				_service_resident_section_projection_queue()
			"heavy":
				_service_resident_heavy_section_projection_queue()

		break

	set_meta(
		"crime_background_aggregate_last_lane",
		serviced_lane
	)
	set_meta(
		"crime_background_aggregate_one_lane_per_frame",
		true
	)
	set_meta(
		"crime_background_aggregate_requires_input_idle",
		false
	)
	set_meta(
		"crime_background_aggregate_uses_call_deferred",
		false
	)
	set_meta(
		"crime_background_aggregate_last_at_ms",
		int(
			Time.get_ticks_msec()
		)
	)

	_arm_crime_background_aggregate_service()
func _drive_resident_heavy_section_projection_process_frame() -> void:
	var tree:= Engine.get_main_loop() as SceneTree
	var callback:= Callable(
		self,
		"_drive_resident_heavy_section_projection_process_frame"
	)

	if (
		resident_heavy_section_projection_queue_head
		>= resident_heavy_section_projection_queue_tail
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

		resident_heavy_section_projection_service_active = false
		return

	var job_key: String = str(
		resident_heavy_section_projection_queue.get(
			resident_heavy_section_projection_queue_head,
			""
		)
	)

	var state_raw: Variant = (
		resident_heavy_section_projection_state_by_key.get(
			job_key,
			{}
		)
	)

	var state: Dictionary = (
		state_raw as Dictionary
		if typeof(
			state_raw
		) == TYPE_DICTIONARY
		else {}
	)

	_crime_hub_truth_probe(
		"heavy_section_service_entered",
		{
			"actor_id": int(
				state.get(
					"actor_id",
					-1
				)
			),
			"section": str(
				state.get(
					"section_id",
					""
				)
			),
			"job_key": job_key,
			"queue_depth": (
				resident_heavy_section_projection_queue.size()
			)
		}
	)

	_service_resident_heavy_section_projection_queue()

	if (
		resident_heavy_section_projection_queue_head
		>= resident_heavy_section_projection_queue_tail
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

		resident_heavy_section_projection_service_active = false
	else:
		resident_heavy_section_projection_service_active = true

func _service_resident_heavy_section_projection_queue() -> void:
	resident_heavy_section_projection_service_active = false

	if (
		resident_heavy_section_projection_queue_head
		>= resident_heavy_section_projection_queue_tail
	):
		resident_heavy_section_projection_queue.clear()
		resident_heavy_section_projection_queue_head = 0
		resident_heavy_section_projection_queue_tail = 0
		return

	var queue_slot: int = (
		resident_heavy_section_projection_queue_head
	)
	resident_heavy_section_projection_queue_head += 1

	var job_key: String = str(
		resident_heavy_section_projection_queue.get(
			queue_slot,
			""
		)
	)

	resident_heavy_section_projection_queue.erase(
		queue_slot
	)
	resident_heavy_section_projection_keys.erase(
		job_key
	)

	var state_raw: Variant = (
		resident_heavy_section_projection_state_by_key.get(
			job_key,
			{}
		)
	)

	if typeof(state_raw) != TYPE_DICTIONARY:
		_arm_resident_heavy_section_projection_service()
		return

	var state: Dictionary = state_raw as Dictionary
	var actor_id: int = int(
		state.get(
			"actor_id",
			-1
		)
	)
	var section_id: String = _section(
		str(
			state.get(
				"section_id",
				""
			)
		)
	)
	var actor: Person = _resident_actor_by_id(
		actor_id
	)

	if actor == null:
		resident_heavy_section_projection_state_by_key.erase(
			job_key
		)
		_arm_resident_heavy_section_projection_service()
		return

	var started_usec: int = int(
		Time.get_ticks_usec()
	)
	var serviced_items: int = 0
	var complete: bool = false

	var rows_raw: Variant = state.get(
		"rows",
		[]
	)
	var rows: Array = (
		rows_raw as Array
		if typeof(rows_raw) == TYPE_ARRAY
		else []
	)
	var row_keys_raw: Variant = state.get(
		"row_keys",
		{}
	)
	var row_keys: Dictionary = (
		row_keys_raw as Dictionary
		if typeof(row_keys_raw) == TYPE_DICTIONARY
		else {}
	)

	if section_id == "weapons":
		var inventory_raw: Variant = state.get(
			"inventory",
			{}
		)
		var inventory: Dictionary = (
			inventory_raw as Dictionary
			if typeof(inventory_raw) == TYPE_DICTIONARY
			else {}
		)
		var categories_raw: Variant = state.get(
			"categories",
			[]
		)
		var categories: Array = (
			categories_raw as Array
			if typeof(categories_raw) == TYPE_ARRAY
			else []
		)
		var category_cursor: int = int(
			state.get(
				"category_cursor",
				0
			)
		)
		var item_cursor: int = int(
			state.get(
				"item_cursor",
				0
			)
		)

		while (
			category_cursor < categories.size()
			and serviced_items
				< CRIME_HEAVY_SECTION_ITEM_BUDGET_PER_QUANTUM
		):
			if (
				serviced_items > 0
				and int(
					Time.get_ticks_usec()
				) - started_usec
					>= CRIME_HEAVY_SECTION_WORK_BUDGET_USEC
			):
				break

			var raw_category: Variant = categories [
				category_cursor
			]
			var items_raw: Variant = inventory.get(
				raw_category,
				[]
			)
			var items: Array = (
				items_raw as Array
				if typeof(items_raw) == TYPE_ARRAY
				else []
			)

			if item_cursor >= items.size():
				category_cursor += 1
				item_cursor = 0
				continue

			var raw_item: Variant = items [
				item_cursor
			]
			item_cursor += 1
			serviced_items += 1

			if typeof(raw_item) != TYPE_DICTIONARY:
				continue

			var row: Dictionary = (
				_crime_weapon_row_from_raw_belonging(
					str(
						raw_category
					),
					raw_item as Dictionary
				)
			)

			if row.is_empty():
				continue

			var row_key: String = str(
				row.get(
					"item_id",
					row.get(
						"label",
						""
					)
				)
			)

			if (
				row_key != ""
				and row_keys.has(
					row_key
				)
			):
				continue

			if row_key != "":
				row_keys [
					row_key
				] = true

			rows.append(
				row
			)

			resident_crime_section_row_published.emit(
				actor_id,
				"weapons",
				row.duplicate(false),
				"crime_weapon_resident_stream"
			)

		state [
			"category_cursor"
		] = category_cursor
		state [
			"item_cursor"
		] = item_cursor

		complete = (
			category_cursor >= categories.size()
		)
	else:
		var case_cursor: int = int(
			state.get(
				"case_cursor",
				0
			)
		)

		while serviced_items < CRIME_HEAVY_SECTION_ITEM_BUDGET_PER_QUANTUM:
			if (
				serviced_items > 0
				and int(
					Time.get_ticks_usec()
				) - started_usec
					>= CRIME_HEAVY_SECTION_WORK_BUDGET_USEC
			):
				break

			if (
				gs == null
				or gs.case_orchestrator == null
				or not gs.case_orchestrator.has_method(
					"resident_case_cursor_contract"
				)
			):
				complete = true
				break

			var cursor_raw: Variant = (
				gs.case_orchestrator.call(
					"resident_case_cursor_contract",
					case_cursor
				)
			)

			if typeof(cursor_raw) != TYPE_DICTIONARY:
				complete = true
				break

			var cursor_contract: Dictionary = (
				cursor_raw as Dictionary
			)

			if not bool(
				cursor_contract.get(
					"success",
					false
				)
			):
				complete = true
				break

			var cursor_complete: bool = bool(
				cursor_contract.get(
					"complete",
					false
				)
			)
			var next_cursor: int = int(
				cursor_contract.get(
					"next_cursor",
					case_cursor
				)
			)
			var case_raw: Variant = cursor_contract.get(
				"case_data",
				{}
			)

			if cursor_complete and typeof(case_raw) != TYPE_DICTIONARY:
				case_cursor = next_cursor
				complete = true
				break

			if cursor_complete and (case_raw as Dictionary).is_empty():
				case_cursor = next_cursor
				complete = true
				break

			case_cursor = maxi(
				case_cursor + 1,
				next_cursor
			)
			serviced_items += 1

			if typeof(case_raw) == TYPE_DICTIONARY:
				var row: Dictionary = (
					_crime_case_row_from_raw_case(
						actor_id,
						case_raw as Dictionary
					)
				)

				if not row.is_empty():
					var row_case_raw: Variant = row.get(
						"case",
						{}
					)
					var row_case: Dictionary = (
						row_case_raw as Dictionary
						if typeof(row_case_raw) == TYPE_DICTIONARY
						else {}
					)
					var row_key: String = str(
						row_case.get(
							"case_id",
							row.get(
								"label",
								""
							)
						)
					)

					if not (
						row_key != ""
						and row_keys.has(
							row_key
						)
					):
						if row_key != "":
							row_keys [
								row_key
							] = true

						rows.append(
							row
						)

						resident_crime_section_row_published.emit(
							actor_id,
							"cases",
							row.duplicate(false),
							"crime_case_resident_stream"
						)

			if cursor_complete:
				complete = true
				break

		state [
			"case_cursor"
		] = case_cursor

	state [
		"rows"
	] = rows
	state [
		"row_keys"
	] = row_keys

	if not complete:
		resident_heavy_section_projection_state_by_key [
			job_key
		] = state

		_queue_resident_heavy_section_projection_job(
			job_key
		)
		_arm_resident_heavy_section_projection_service()
		return

	var actor_key: String = str(
		actor_id
	)
	var surfaces_raw: Variant = (
		section_surfaces_by_actor.get(
			actor_key,
			{}
		)
	)
	var surfaces: Dictionary = (
		(surfaces_raw as Dictionary).duplicate(false)
		if typeof(surfaces_raw) == TYPE_DICTIONARY
		else {}
	)
	var final_surface: Dictionary = (
		_crime_section_shell(
			section_id,
			false
		)
	)

	final_surface [
		"actor_id"
	] = actor_id
	final_surface [
		"section_rows"
	] = rows
	final_surface [
		"truth_state"
	] = "hot"
	final_surface [
		"projection_composed"
	] = true
	final_surface [
		"hydrated"
	] = true
	final_surface [
		"projection_pending"
	] = false
	final_surface [
		"progressive_observability"
	] = true
	final_surface [
		"status_text"
	] = (
		""
		if not rows.is_empty()
		else (
			"No resident weapons are currently available."
			if section_id == "weapons"
			else "No active crime cases are attached to this actor."
		)
	)



	final_surface [
		"stream_completion_only"
	] = not rows.is_empty()
	final_surface [
		"row_count"
	] = rows.size()
	final_surface [
		"updated_at_ms"
	] = int(
		Time.get_ticks_msec()
	)

	surfaces [
		section_id
	] = final_surface
	section_surfaces_by_actor [
		actor_key
	] = surfaces

	resident_heavy_section_projection_state_by_key.erase(
		job_key
	)

	resident_crime_section_contract_published.emit(
		actor_id,
		section_id,
		final_surface.duplicate(false),
		"%s:complete" % str(
			state.get(
				"source",
				"crime_background_projection"
			)
		)
	)

	if (
		resident_heavy_section_projection_queue_head
		>= resident_heavy_section_projection_queue_tail
	):
		resident_heavy_section_projection_queue.clear()
		resident_heavy_section_projection_queue_head = 0
		resident_heavy_section_projection_queue_tail = 0

	_arm_resident_heavy_section_projection_service()
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
func _on_crime_belongings_event(
	payload: Dictionary = {}
) -> void:
	var event_type: String = str(
		payload.get(
			"event_type",
			""
		)
	).strip_edges().to_lower()

	if event_type not in [
		"item_acquired",
		"item_updated",
		"item_removed"
	]:
		return

	var category: String = str(
		payload.get(
			"category",
			""
		)
	).strip_edges().to_lower()

	if category != "weapons":
		return

	var actor_id: int = int(
		payload.get(
			"owner_id",
			-1
		)
	)

	var actor: Person = _resident_actor_by_id(
		actor_id
	)

	if actor == null:
		return

	var item_id: int = int(
		payload.get(
			"item_id",
			-1
		)
	)

	if event_type == "item_removed":
		var replacement_surface: Dictionary = (
			_remove_resident_weapon_row(
				actor_id,
				item_id
			)
		)

		if not replacement_surface.is_empty():
			resident_crime_section_contract_published.emit(
				actor_id,
				"weapons",
				replacement_surface,
				"belongings.event:item_removed"
			)





	queue_resident_section_projection(
		actor,
		[
			"weapons"
		],
		"belongings.event:%s" % event_type
	)

func _upsert_resident_weapon_row(
	actor_id: int,
	row: Dictionary
) -> void:
	var actor_key: String = str(
		actor_id
	)

	var surfaces: Dictionary = _safe_dictionary(
		section_surfaces_by_actor.get(
			actor_key,
			{}
		)
	)

	var weapon_surface: Dictionary = _safe_dictionary(
		surfaces.get(
			"weapons",
			{}
		)
	)

	if weapon_surface.is_empty():
		weapon_surface = _crime_section_shell(
			"weapons",
			false
		)

	var rows: Array = _safe_array(
		weapon_surface.get(
			"section_rows",
			[]
		)
	)

	var incoming_item: Dictionary = _safe_dictionary(
		row.get(
			"item",
			row
		)
	)
	var incoming_id: int = int(
		incoming_item.get(
			"id",
			row.get(
				"item_id",
				-1
			)
		)
	)

	var replaced: bool = false

	for index in range(
		rows.size()
	):
		var existing: Dictionary = _safe_dictionary(
			rows [
				index
			]
		)
		var existing_item: Dictionary = _safe_dictionary(
			existing.get(
				"item",
				existing
			)
		)
		var existing_id: int = int(
			existing_item.get(
				"id",
				existing.get(
					"item_id",
					-1
				)
			)
		)

		if (
			incoming_id <= 0
			or existing_id != incoming_id
		):
			continue

		rows [
			index
		] = row
		replaced = true
		break

	if not replaced:
		rows.append(
			row
		)

	weapon_surface [
		"actor_id"
	] = actor_id
	weapon_surface [
		"section_rows"
	] = rows
	weapon_surface [
		"truth_state"
	] = "hot"
	weapon_surface [
		"hydrated"
	] = true
	weapon_surface [
		"projection_pending"
	] = false
	weapon_surface [
		"dirty"
	] = false
	weapon_surface [
		"known_empty"
	] = false
	weapon_surface [
		"progressive_observability"
	] = true
	weapon_surface [
		"observation_required"
	] = false
	weapon_surface [
		"updated_at_ms"
	] = int(
		Time.get_ticks_msec()
	)

	surfaces [
		"weapons"
	] = weapon_surface

	section_surfaces_by_actor [
		actor_key
	] = surfaces
func _remove_resident_weapon_row(
	actor_id: int,
	item_id: int
) -> Dictionary:
	if (
		actor_id <= 0
		or item_id <= 0
	):
		return {}

	var actor_key: String = str(
		actor_id
	)

	var surfaces: Dictionary = _safe_dictionary(
		section_surfaces_by_actor.get(
			actor_key,
			{}
		)
	)

	var weapon_surface: Dictionary = _safe_dictionary(
		surfaces.get(
			"weapons",
			{}
		)
	)

	if weapon_surface.is_empty():
		weapon_surface = _crime_section_shell(
			"weapons",
			false
		)

	var rows: Array = _safe_array(
		weapon_surface.get(
			"section_rows",
			[]
		)
	)
	var retained_rows: Array = []

	for raw_row in rows:
		var existing: Dictionary = _safe_dictionary(
			raw_row
		)
		var existing_item: Dictionary = _safe_dictionary(
			existing.get(
				"item",
				existing
			)
		)
		var existing_id: int = int(
			existing_item.get(
				"id",
				existing.get(
					"item_id",
					-1
				)
			)
		)

		if existing_id == item_id:
			continue

		retained_rows.append(
			existing
		)

	weapon_surface [
		"actor_id"
	] = actor_id
	weapon_surface [
		"section_rows"
	] = retained_rows
	weapon_surface [
		"truth_state"
	] = "hot"
	weapon_surface [
		"hydrated"
	] = true
	weapon_surface [
		"projection_pending"
	] = false
	weapon_surface [
		"dirty"
	] = false
	weapon_surface [
		"known_empty"
	] = retained_rows.is_empty()
	weapon_surface [
		"progressive_observability"
	] = true
	weapon_surface [
		"observation_required"
	] = false
	weapon_surface [
		"updated_at_ms"
	] = int(
		Time.get_ticks_msec()
	)

	surfaces [
		"weapons"
	] = weapon_surface

	section_surfaces_by_actor [
		actor_key
	] = surfaces

	return weapon_surface.duplicate(false)
func emit_hub_contract(
	actor: Person,
	section_id: String = "overview",
	context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return {}

	var clean_section: String = _section(
		section_id
	)

	var prison_contract: Dictionary = (
		_prison_contract_for_actor(
			actor
		)
	)

	var incarcerated: bool = (
		not prison_contract.is_empty()
	)

	var interaction_raw: Variant = context.get(
		"interaction_contract",
		{}
	)

	var interaction_contract: Dictionary = (
		(interaction_raw as Dictionary).duplicate(false)
		if typeof(interaction_raw) == TYPE_DICTIONARY
		else {}
	)

	var section_surfaces: Dictionary = (
		_crime_section_surfaces_for_actor(
			actor,
			prison_contract,
			context
		)
	)



	if not interaction_contract.is_empty():
		var target_surface_raw: Variant = (
			section_surfaces.get(
				"targets",
				{}
			)
		)
		var target_surface: Dictionary = (
			(target_surface_raw as Dictionary).duplicate(false)
			if typeof(target_surface_raw) == TYPE_DICTIONARY
			else {}
		)
		var interaction_rows_raw: Variant = (
			interaction_contract.get(
				"rows",
				[]
			)
		)
		var interaction_rows: Array = (
			interaction_rows_raw as Array
			if typeof(interaction_rows_raw) == TYPE_ARRAY
			else []
		)

		target_surface [
			"section_id"
		] = "targets"
		target_surface [
			"section_rows"
		] = interaction_rows
		target_surface [
			"interaction_contract"
		] = interaction_contract
		target_surface [
			"interaction_stage"
		] = str(
			interaction_contract.get(
				"stage",
				""
			)
		)
		target_surface [
			"updated_at_ms"
		] = int(
			Time.get_ticks_msec()
		)

		section_surfaces [
			"targets"
		] = target_surface

	var active_surface_raw: Variant = (
		section_surfaces.get(
			clean_section,
			{}
		)
	)
	var active_surface: Dictionary = (
		active_surface_raw as Dictionary
		if typeof(active_surface_raw) == TYPE_DICTIONARY
		else {}
	)
	var rows_raw: Variant = active_surface.get(
		"section_rows",
		[]
	)
	var rows: Array = (
		rows_raw as Array
		if typeof(rows_raw) == TYPE_ARRAY
		else []
	)
	var action_report_raw: Variant = context.get(
		"action_report",
		{}
	)
	var action_report: Dictionary = (
		action_report_raw as Dictionary
		if typeof(action_report_raw) == TYPE_DICTIONARY
		else {}
	)
	var facility_raw: Variant = prison_contract.get(
		"facility",
		{}
	)
	var facility: Dictionary = (
		facility_raw as Dictionary
		if typeof(facility_raw) == TYPE_DICTIONARY
		else {}
	)

	var section_tabs: Array = _section_tabs(
		incarcerated
	)
	var resident_section_count: int = 0
	var observable_section_count: int = 0
	var complete_section_count: int = 0

	for raw_tab in section_tabs:
		if typeof(raw_tab) != TYPE_DICTIONARY:
			continue

		var tab: Dictionary = raw_tab as Dictionary
		var tab_section_id: String = _section(
			str(
				tab.get(
					"id",
					"overview"
				)
			)
		)
		var resident_surface: Dictionary = _safe_dictionary(
			section_surfaces.get(
				tab_section_id,
				{}
			)
		)

		if resident_surface.is_empty():
			continue

		resident_section_count += 1

		var observable: bool = (
			str(
				resident_surface.get(
					"truth_state",
					""
				)
			) == "hot"
			and bool(
				resident_surface.get(
					"hydrated",
					false
				)
			)
		)

		if not observable:
			continue

		observable_section_count += 1

		if (
			not bool(
				resident_surface.get(
					"projection_pending",
					false
				)
			)
			and not bool(
				resident_surface.get(
					"dirty",
					false
				)
			)
		):
			complete_section_count += 1

	var all_sections_resident: bool = (
		resident_section_count == section_tabs.size()
	)
	var all_sections_observable: bool = (
		observable_section_count == section_tabs.size()
	)
	var all_sections_precomposed: bool = (
		complete_section_count == section_tabs.size()
	)

	var contract: Dictionary = {
		"schema": CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"success": true,
		"actor_id": int(
			actor.id
		),
		"title": (
			"PRISON"
			if incarcerated
			else "CRIME & JUSTICE"
		),
		"subtitle": (
			str(
				facility.get(
					"label",
					"Incarceration"
				)
			)
			if incarcerated
			else (
				"Actions, active cases, legal pressure, "
				+ "custody, and consequences"
			)
		),
		"active_section": clean_section,
		"section_tabs": section_tabs,
		"section_rows": rows,
		"section_surfaces": section_surfaces,
		"identity": _identity_contract(
			actor
		),
		"access_contract": {
			"minimum_age": 0,
			"under_12_access": true,
		},
		"incarcerated": incarcerated,
		"prison_reality_contract": prison_contract,
		"interaction_contract": interaction_contract,
		"action_report": action_report,
		"truth_state": "hot",
		"projection_composed": true,
		"hydrated": true,
		"all_sections_resident": all_sections_resident,
		"all_sections_observable": all_sections_observable,
		"all_sections_precomposed": all_sections_precomposed,
		"resident_section_count": resident_section_count,
		"observable_section_count": observable_section_count,
		"complete_section_count": complete_section_count,
		"section_target_count": section_tabs.size(),
		"projection_pending": not all_sections_precomposed,
		"progressive_observability": true,
		"section_press_reveal_only": true,
		"build_on_section_click": false,
		"engine_call_on_section_click": false,
		"ui_is_renderer_only": true,
		"generated_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	last_contract = contract.duplicate(
		false
	)

	return contract
func _section_tabs(
		incarcerated: bool
) -> Array:
	if incarcerated:
		return [
			{
				"id": "overview",
				"label": "MY SENTENCE"
			},
			{
				"id": "prison",
				"label": "PRISON"
			},
			{
				"id": "population",
				"label": "POPULATION"
			},
			{
				"id": "targets",
				"label": "TARGETS"
			},
			{
				"id": "family",
				"label": "FAMILY"
			},
			{
				"id": "cases",
				"label": "CASE"
			}
		]

	return [
		{
			"id": "overview",
			"label": "OVERVIEW"
		},
		{
			"id": "crime_actions",
			"label": "CRIME ACTIONS"
		},
		{
			"id": "targets",
			"label": "TARGETS"
		},
		{
			"id": "weapons",
			"label": "WEAPONS"
		},
		{
			"id": "cases",
			"label": "CASES"
		},
		{
			"id": "pending",
			"label": "PENDING"
		},
		{
			"id": "custody",
			"label": "CUSTODY"
		}
	]
func _crime_section_surface(
	actor: Person,
	section_id: String,
	prison_contract: Dictionary,
	force_recompose: bool = false
) -> Dictionary:
	var clean_section: String = _section(
		section_id
	)

	if (
		clean_section == "targets"
		and actor != null
	):
		var actor_key: String = str(
			int(
				actor.id
			)
		)
		if (
			clean_section == "targets"
			and actor != null
			and not prison_contract.is_empty()
		):
			var custody_target_rows: Array = _safe_array(
				prison_contract.get(
					"crime_target_cards",
					[]
				)
			)

			var custody_target_surface: Dictionary = (
				_crime_section_shell(
					"targets",
					true
				)
			)

			custody_target_surface ["actor_id"] = int(
				actor.id
			)
			custody_target_surface ["section_id"] = "targets"
			custody_target_surface ["title"] = "TARGETS"
			custody_target_surface ["section_rows"] = (
				custody_target_rows
			)
			custody_target_surface ["truth_state"] = "hot"
			custody_target_surface ["hydrated"] = true
			custody_target_surface ["projection_pending"] = false
			custody_target_surface ["progressive_observability"] = true
			custody_target_surface ["observation_required"] = false
			custody_target_surface [
				"free_world_target_projection_suppressed"
			] = true
			custody_target_surface [
				"target_authority"
			] = "incarceration_resident_contract"
			custody_target_surface [
				"facility_id"
			] = str(
				_safe_dictionary(
					prison_contract.get(
						"facility",
						{}
					)
				).get(
					"facility_id",
					""
				)
			)

			return custody_target_surface
		var resident_surface: Dictionary = (
			_safe_dictionary(
				resident_target_identity_contract_by_actor.get(
					actor_key,
					{}
				)
			)
		)



		if (
			resident_surface.is_empty()
			and gs != null
			and gs.crime_contract_engine != null
			and gs.crime_contract_engine.has_method(
				"resident_crime_target_contract"
			)
		):
			var resident_contract: Dictionary = (
				gs.crime_contract_engine
				.resident_crime_target_contract(
					int(
						actor.id
					)
				)
			)

			if not resident_contract.is_empty():
				resident_surface = (
					_crime_section_shell(
						"targets",
						false
					)
				)

				resident_surface [
					"actor_id"
				] = int(
					actor.id
				)

				resident_surface [
					"section_id"
				] = "targets"

				resident_surface [
					"title"
				] = "TARGETS"

				resident_surface [
					"section_rows"
				] = _safe_array(
					resident_contract.get(
						"rows",
						[]
					)
				)

				resident_surface [
					"truth_state"
				] = "hot"

				resident_surface [
					"hydrated"
				] = true

				resident_surface [
					"projection_pending"
				] = not bool(
					resident_contract.get(
						"complete",
						false
					)
				)

				resident_surface [
					"target_projection_signature"
				] = str(
					resident_contract.get(
						"signature",
						""
					)
				)

				resident_surface [
					"progressive_observability"
				] = true

				resident_surface [
					"observation_required"
				] = false

				resident_target_identity_contract_by_actor [
					actor_key
				] = resident_surface.duplicate(
					false
				)

		if not resident_surface.is_empty():
			return resident_surface.duplicate(
				false
			)

		var target_shell: Dictionary = (
			_crime_section_shell(
				"targets",
				false
			)
		)

		target_shell [
			"actor_id"
		] = int(
			actor.id
		)

		target_shell [
			"section_id"
		] = "targets"

		target_shell [
			"title"
		] = "TARGETS"

		target_shell [
			"status_text"
		] = (
			"Resident target identities are publishing live."
		)

		target_shell [
			"projection_pending"
		] = true

		target_shell [
			"progressive_observability"
		] = true

		target_shell [
			"observation_required"
		] = false

		target_shell [
			"population_scan_performed"
		] = false

		return target_shell

	if (
		actor != null
		and not force_recompose
	):
		var actor_key: String = str(
			int(
				actor.id
			)
		)

		var surfaces: Dictionary = _safe_dictionary(
			section_surfaces_by_actor.get(
				actor_key,
				{}
			)
		)

		var cached_surface: Dictionary = _safe_dictionary(
			surfaces.get(
				clean_section,
				{}
			)
		)

		if (
			not cached_surface.is_empty()
			and int(
				cached_surface.get(
					"actor_id",
					int(
						actor.id
					)
				)
			) == int(
				actor.id
			)
		):
			return cached_surface.duplicate(
				false
			)

	return {
		"actor_id": (
			int(
				actor.id
			)
			if actor != null
			else -1
		),
		"section_id": clean_section,
		"section_rows": _section_rows(
			actor,
			clean_section,
			prison_contract
		),
		"interaction_contract": {},
		"truth_state": "hot",
		"projection_composed": true,
		"hydrated": true,
		"projection_pending": false,
		"ui_is_renderer_only": true,
		"built_at_ms": int(
			Time.get_ticks_msec()
		)
	}
func _crime_section_shell(
	section_id: String,
	incarcerated: bool
) -> Dictionary:
	var clean_section: String = _section(section_id)
	var label: String = clean_section.capitalize()

	for raw_tab in _section_tabs(incarcerated):
		if typeof(raw_tab) != TYPE_DICTIONARY:
			continue

		var tab: Dictionary = raw_tab as Dictionary

		if (
			_section(
				str(
					tab.get(
						"id",
						"overview"
					)
				)
			)
			== clean_section
		):
			label = str(
				tab.get(
					"label",
					label
				)
			)
			break

	return {
		"schema": "eralife.crime_hub_section_surface",
		"version": CONTRACT_VERSION,
		"section_id": clean_section,
		"title": label,
		"section_rows": [],
		"status_text": (
			"This resident Crime lens is available. Its authoritative "
			+ "rows are composing outside the interaction frame."
		),
		"truth_state": "resident_shell",
		"hydrated": false,
		"projection_pending": true,
		"build_on_section_click": false,
		"engine_call_on_section_click": false,
		"ui_is_renderer_only": true
	}
func _crime_section_surfaces_for_actor(
	actor: Person,
	prison_contract: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return {}

	var actor_key: String = str(
		int(
			actor.id
		)
	)

	var current_world_year: int = (
		int(
			gs.year
		)
		if gs != null
		else 0
	)

	var current_actor_age: int = maxi(
		0,
		int(
			actor.age
		)
	)

	var cached_raw: Variant = (
		section_surfaces_by_actor.get(
			actor_key,
			{}
		)
	)

	var surfaces: Dictionary = (
		(cached_raw as Dictionary).duplicate(false)
		if typeof(cached_raw) == TYPE_DICTIONARY
		else {}
	)

	var incarcerated: bool = (
		not prison_contract.is_empty()
	)

	var refresh_all: bool = bool(
		context.get(
			"refresh_all_sections",
			false
		)
	)

	var refresh_sections_raw: Variant = (
		context.get(
			"refresh_sections",
			[]
		)
	)

	var refresh_sections: Array = (
		(refresh_sections_raw as Array).duplicate(false)
		if typeof(refresh_sections_raw) == TYPE_ARRAY
		else []
	)

	var dirty_sections_raw: Variant = (
		context.get(
			"dirty_sections",
			[]
		)
	)

	var dirty_sections: Array = (
		(dirty_sections_raw as Array).duplicate(false)
		if typeof(dirty_sections_raw) == TYPE_ARRAY
		else []
	)

	var projection_source: String = str(
		context.get(
			"source",
			"crime_hub_resident_projection"
		)
	).strip_edges()

	if projection_source == "":
		projection_source = (
			"crime_hub_resident_projection"
		)

	var sections_to_queue: Array = []

	for raw_tab in _section_tabs(
		incarcerated
	):
		if typeof(raw_tab) != TYPE_DICTIONARY:
			continue

		var tab: Dictionary = (
			raw_tab as Dictionary
		)

		var section_id: String = _section(
			str(
				tab.get(
					"id",
					"overview"
				)
			)
		)

		if not surfaces.has(
			section_id
		):
			var resident_shell: Dictionary = (
				_crime_section_shell(
					section_id,
					incarcerated
				)
			)

			resident_shell [
				"actor_id"
			] = int(
				actor.id
			)

			resident_shell [
				"progressive_observability"
			] = true

			resident_shell [
				"observation_required"
			] = false

			resident_shell [
				"ready_gate_member"
			] = false

			surfaces [
				section_id
			] = resident_shell

		var current_surface: Dictionary = (
			_safe_dictionary(
				surfaces.get(
					section_id,
					{}
				)
			)
		)

		var explicitly_refreshed: bool = (
			section_id in refresh_sections
			or section_id in dirty_sections
		)

		if section_id in dirty_sections:
			var dirty_surface: Dictionary = (
				current_surface.duplicate(false)
			)

			dirty_surface [
				"projection_pending"
			] = true

			dirty_surface [
				"dirty"
			] = true

			dirty_surface [
				"dirty_at_ms"
			] = int(
				Time.get_ticks_msec()
			)

			surfaces [
				section_id
			] = dirty_surface

			current_surface = dirty_surface

		var temporal_revision_required: bool = (
			section_id not in [
				"targets",
				"weapons",
				"cases"
			]
		)

		var temporal_projection_stale: bool = (
			temporal_revision_required
			and (
				int(
					current_surface.get(
						"projected_world_year",
						-999999
					)
				) != current_world_year
				or int(
					current_surface.get(
						"projected_actor_age",
						-1
					)
				) != current_actor_age
			)
		)

		if temporal_projection_stale:
			var temporal_dirty_surface: Dictionary = (
				current_surface.duplicate(false)
			)

			temporal_dirty_surface [
				"projection_pending"
			] = true

			temporal_dirty_surface [
				"dirty"
			] = true

			temporal_dirty_surface [
				"dirty_reason"
			] = "temporal_truth_revision_mismatch"

			temporal_dirty_surface [
				"expected_world_year"
			] = current_world_year

			temporal_dirty_surface [
				"expected_actor_age"
			] = current_actor_age

			temporal_dirty_surface [
				"dirty_at_ms"
			] = int(
				Time.get_ticks_msec()
			)

			surfaces [
				section_id
			] = temporal_dirty_surface

			current_surface = temporal_dirty_surface

		var resident_projection_missing: bool = (
			current_surface.is_empty()
			or str(
				current_surface.get(
					"truth_state",
					""
				)
			) != "hot"
			or not bool(
				current_surface.get(
					"hydrated",
					false
				)
			)
			or bool(
				current_surface.get(
					"projection_pending",
					false
				)
			)
			or bool(
				current_surface.get(
					"dirty",
					false
				)
			)
			or temporal_projection_stale
		)

		var needs_refresh: bool = (
			refresh_all
			or explicitly_refreshed
			or resident_projection_missing
		)

		if not needs_refresh:
			continue

		if (
			refresh_all
			and not explicitly_refreshed
			and not temporal_projection_stale
			and bool(
				current_surface.get(
					"hydrated",
					false
				)
			)
			and not bool(
				current_surface.get(
					"projection_pending",
					false
				)
			)
			and not bool(
				current_surface.get(
					"dirty",
					false
				)
			)
		):
			continue

		if section_id == "targets":
			var target_surface: Dictionary = (
				_crime_section_surface(
					actor,
					section_id,
					prison_contract
				)
			)

			target_surface [
				"actor_id"
			] = int(
				actor.id
			)

			target_surface [
				"ready_gate_member"
			] = false

			target_surface [
				"build_on_section_click"
			] = false

			target_surface [
				"engine_call_on_section_click"
			] = false

			surfaces [
				section_id
			] = target_surface

			continue

		if section_id not in sections_to_queue:
			sections_to_queue.append(
				section_id
			)

	section_surfaces_by_actor [
		actor_key
	] = surfaces

	if not sections_to_queue.is_empty():
		queue_resident_section_projection(
			actor,
			sections_to_queue,
			projection_source
		)

	return surfaces.duplicate(false)
func _section_rows(
		actor: Person,
		section_id: String,
		prison_contract: Dictionary
) -> Array:
	match section_id:
		"crime_actions":
			return _crime_action_rows(
				actor
			)

		"targets":
			if not prison_contract.is_empty():
				return _safe_array(
					prison_contract.get(
						"crime_target_cards",
						[]
					)
				)



			return []

		"weapons":
			return _weapon_rows(
				actor
			)

		"cases":
			return _case_rows(
				actor
			)

		"pending":
			return _pending_rows(
				actor
			)

		"custody", "prison":
			return _prison_rows(
				prison_contract
			)

		"population":
			return _safe_array(
				prison_contract.get(
					"population_cards",
					[]
				)
			)

		"family":
			return _family_rows(
				prison_contract
			)

		_:
			return _overview_rows(
				actor,
				prison_contract
			)
func _crime_action_rows(
	actor: Person
) -> Array:
	if actor == null:
		return []

	return [
		{
			"kind": "crime_action",
			"crime_action_id": "murder",
			"label": "MURDER",
			"subtitle": (
				"Choose a method first. "
				+ "Then direct that intent at a resident target."
			),
			"danger_label": "EXTREME",
			"visual_tier": "critical",
			"actions": [
				{
					"id": "show_resident_crime_methods",
					"label": "CHOOSE METHOD",
					"enabled": true,
				}
			],


			"method_actions": [
				{
					"id": "select_crime_action",
					"label": "POISON",
					"payload": {
						"action_id": "select_crime_action",
						"crime_action_id": "murder",
						"crime_method_id": "poison"
					}
				},
				{
					"id": "select_crime_action",
					"label": "DIRECT ATTACK",
					"payload": {
						"action_id": "select_crime_action",
						"crime_action_id": "murder",
						"crime_method_id": "direct_attack"
					}
				},
				{
					"id": "open_crime_weapon_picker",
					"label": "USE A WEAPON",
					"payload": {
						"action_id": "open_crime_weapon_picker",
						"crime_action_id": "murder",
						"crime_method_id": "weapon"
					}
				}
			],
			"ui_is_renderer_only": true
		},
		{
			"kind": "crime_action",
			"crime_action_id": "use_weapon",
			"label": "USE WEAPON",
			"subtitle": (
				"Choose one of your resident weapons and "
				+ "an action supported by its weapon contract."
			),
			"danger_label": "WEAPON",
			"visual_tier": "danger",
			"actions": [
				{
					"id": "open_crime_weapon_picker",
					"label": "CHOOSE WEAPON",
					"payload": {
						"action_id": "open_crime_weapon_picker",
						"crime_action_id": "use_weapon"
					}
				}
			],
			"ui_is_renderer_only": true
		},
		{
			"kind": "crime_action",
			"crime_action_id": "bank_robbery",
			"label": "TRY TO ROB THE BANK",
			"subtitle": (
				"Choose an owned weapon, then submit the attempt "
				+ "to the existing CrimeEngine justice pipeline."
			),
			"danger_label": "HIGH RISK",
			"visual_tier": "danger",
			"actions": [
				{
					"id": "open_bank_robbery_weapon_picker",
					"label": "PLAN ROBBERY",
					"payload": {
						"action_id": (
							"open_bank_robbery_weapon_picker"
						),
						"crime_action_id": "bank_robbery"
					}
				}
			],
			"ui_is_renderer_only": true
		},
		{
			"kind": "crime_action",
			"crime_action_id": "assault",
			"label": "ASSAULT SOMEONE",
			"subtitle": (
				"Arm an assault intent, then select one of "
				+ "the already-resident target cards."
			),
			"danger_label": "VIOLENT",
			"visual_tier": "danger",
			"actions": [
				{
					"id": "select_crime_action",
					"label": "CHOOSE TARGET",
					"payload": {
						"action_id": "select_crime_action",
						"crime_action_id": "assault",
						"crime_method_id": "attack"
					}
				}
			],
			"ui_is_renderer_only": true
		}
	]

func _overview_rows(
	actor: Person,
	prison_contract: Dictionary
) -> Array:
	var rows: Array = [
		{
			"kind": "crime_identity",
			"label": _actor_name(
				actor
			),
			"subtitle": (
				"Age %d • Crime Hub access is available."
				% int(
					actor.age
				)
			)
		}
	]

	if not prison_contract.is_empty():
		var sentence: Dictionary = _safe_dictionary(
			prison_contract.get(
				"sentence",
				{}
			)
		)
		var execution_schedule: Dictionary = _safe_dictionary(
			sentence.get(
				"execution_schedule",
				{}
			)
		)

		rows.append({
			"kind": "sentence_card",
			"label": str(
				sentence.get(
					"label",
					"Sentence"
				)
			),
			"subtitle": (
				"Served %d years • %d remaining"
				% [
					int(
						sentence.get(
							"years_served",
							0
						)
					),
					int(
						sentence.get(
							"years_remaining",
							0
						)
					)
				]
			)
		})

		if not execution_schedule.is_empty():
			rows.append({
				"kind": "execution_schedule",
				"label": str(
					execution_schedule.get(
						"method_label",
						"Execution"
					)
				),
				"subtitle": "Execution year: %d" % int(
					execution_schedule.get(
						"execution_year",
						0
					)
				)
			})

	return rows


func _weapon_rows(
	actor: Person
) -> Array:
	var rows: Array = []

	if (
		gs == null
		or gs.belongings_engine == null
	):
		return rows

	for raw_row in (
		gs.belongings_engine
		.get_inventory_rows_for_actor(
			actor,
			{
				"source": "crime_hub_contract_engine"
			}
		)
	):
		if typeof(
			raw_row
		) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = (
			raw_row as Dictionary
		)
		var category: String = str(
			row.get(
				"category",
				""
			)
		).strip_edges().to_lower()
		var item: Dictionary = _safe_dictionary(
			row.get(
				"item",
				row
			)
		)
		var item_type: String = str(
			item.get(
				"type",
				row.get(
					"type",
					""
				)
			)
		).strip_edges().to_lower()

		if (
			category != "weapons"
			and item_type != "weapon"
		):
			continue

		rows.append(
			row.duplicate(false)
		)

	return rows
func _on_crime_incarceration_event(
		payload: Dictionary = {}
) -> void:
	var actor_id: int = int(
		payload.get(
			"accused_id",
			-1
		)
	)
	var actor: Person = _resident_actor_by_id(
		actor_id
	)

	if actor == null:
		return

	var custody_contract: Dictionary = (
		_prison_contract_for_actor(
			actor,
			true
		)
	)
	var active: bool = (
		not custody_contract.is_empty()
	)
	var incarceration_state: Dictionary = _safe_dictionary(
		custody_contract.get(
			"incarceration_state",
			{}
		)
	)
	var incarceration_context: Dictionary = _safe_dictionary(
		custody_contract.get(
			"incarceration_context",
			{}
		)
	)
	var incarceration_stats: Dictionary = _safe_dictionary(
		custody_contract.get(
			"incarceration_stats",
			{}
		)
	)

	var contract: Dictionary = {
		"schema": "eralife.incarceration_lens_contract",
		"version": 2,
		"actor_id": actor_id,
		"active": active,
		"incarceration_kind": str(
			custody_contract.get(
				"incarceration_kind",
				""
			)
		),
		"incarceration_state": incarceration_state,
		"incarceration_context": incarceration_context,
		"incarceration_stats": incarceration_stats,
		"navigation_labels": _safe_dictionary(
			custody_contract.get(
				"navigation_labels",
				{}
			)
		),
		"facility": _safe_dictionary(
			custody_contract.get(
				"facility",
				{}
			)
		),
		"sentence": _safe_dictionary(
			custody_contract.get(
				"sentence",
				{}
			)
		),
		"facility_surface_contract": _safe_dictionary(
			custody_contract.get(
				"facility_surface_contract",
				{}
			)
		),
		"sentence_surface_contract": _safe_dictionary(
			custody_contract.get(
				"sentence_surface_contract",
				{}
			)
		),
		"surface_contracts": _safe_dictionary(
			custody_contract.get(
				"surface_contracts",
				{}
			)
		),
		"nearby_prisoner_cards": _safe_array(
			custody_contract.get(
				"nearby_prisoner_cards",
				[]
			)
		),
		"other_facility_cards": _safe_array(
			custody_contract.get(
				"other_facility_cards",
				[]
			)
		),
		"crime_target_cards": _safe_array(
			custody_contract.get(
				"crime_target_cards",
				[]
			)
		),
		"cellmate_id": int(
			custody_contract.get(
				"cellmate_id",
				-1
			)
		),
		"cellmate_assignment_pending": bool(
			custody_contract.get(
				"cellmate_assignment_pending",
				false
			)
		),
		"source_event": str(
			payload.get(
				"event_name",
				""
			)
		),
		"truth_state": "hot",
		"projection_complete": true,
		"observation_required": false,
		"ui_is_renderer_only": true,
		"published_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	incarceration_lens_published.emit(
		actor_id,
		contract
	)

	queue_resident_section_projection(
		actor,
		(
			[
				"overview",
				"prison",
				"population",
				"targets",
				"family",
				"cases"
			]
			if active
			else [
				"overview",
				"crime_actions",
				"targets",
				"weapons",
				"cases",
				"pending",
				"custody"
			]
		),
		"incarceration_state_changed"
	)
func _case_rows(
	actor: Person
) -> Array:
	var rows: Array = []

	if (
		gs == null
		or gs.case_orchestrator == null
	):
		return rows

	for raw_case in gs.case_orchestrator.cases.values():
		if typeof(
			raw_case
		) != TYPE_DICTIONARY:
			continue

		var case_data: Dictionary = (
			raw_case as Dictionary
		)
		var participants: Dictionary = _safe_dictionary(
			case_data.get(
				"participants",
				{}
			)
		)

		if int(
			participants.get(
				"accused",
				-1
			)
		) != int(
			actor.id
		):
			continue

		var crime: Dictionary = _safe_dictionary(
			case_data.get(
				"crime",
				{}
			)
		)

		rows.append({
			"kind": "crime_case_card",
			"label": str(
				crime.get(
					"name",
					crime.get(
						"type",
						"Crime Case"
					)
				)
			),
			"subtitle": "%s • %s" % [
				str(
					case_data.get(
						"status",
						"pending"
					)
				).capitalize(),
				str(
					case_data.get(
						"case_id",
						""
					)
				)
			],
			"case": case_data.duplicate(true)
		})

	return rows


func _pending_rows(
	actor: Person
) -> Array:
	if (
		gs == null
		or typeof(
			gs.scenario_state
		) != TYPE_DICTIONARY
	):
		return []

	var summary: Dictionary = _safe_dictionary(
		gs.scenario_state.get(
			"pending_situations_last_summary_contract",
			{}
		)
	)

	if int(
		summary.get(
			"target_id",
			-1
		)
	) != int(
		actor.id
	):
		return []

	return _safe_array(
		summary.get(
			"summaries",
			[]
		)
	)


func _prison_rows(
	prison_contract: Dictionary
) -> Array:
	if prison_contract.is_empty():
		return [
			{
				"kind": "empty_state",
				"label": "Not incarcerated",
				"subtitle": (
					"No prison reality is attached to this actor."
				)
			}
		]

	var rows: Array = []
	var sentence: Dictionary = _safe_dictionary(
		prison_contract.get(
			"sentence",
			{}
		)
	)
	var facility: Dictionary = _safe_dictionary(
		prison_contract.get(
			"facility",
			{}
		)
	)

	rows.append({
		"kind": "prison_identity",
		"label": str(
			facility.get(
				"label",
				"Prison"
			)
		),
		"subtitle": "%s security • %s" % [
			str(
				facility.get(
					"security_level",
					"Medium"
				)
			),
			str(
				sentence.get(
					"label",
					"Sentence"
				)
			)
		]
	})

	for raw_action in _safe_array(
		prison_contract.get(
			"prison_activity_actions",
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

		rows.append({
			"kind": "prison_activity",
			"label": str(
				action.get(
					"label",
					"Prison Activity"
				)
			),
			"actions": [
				{
					"id": "prison_activity",
					"label": "Do activity",
					"payload": {
						"action_id": "prison_activity",
						"activity_id": str(
							action.get(
								"id",
								""
							)
						)
					}
				}
			]
		})

	return rows


func _family_rows(
	prison_contract: Dictionary
) -> Array:
	var rows: Array = []

	for raw_action in _safe_array(
		prison_contract.get(
			"family_contact_actions",
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

		rows.append({
			"kind": "prison_family_contact",
			"label": str(
				action.get(
					"label",
					"Family Contact"
				)
			),
			"actions": [
				{
					"id": "prison_activity",
					"label": "Contact family",
					"payload": {
						"action_id": "prison_activity",
						"activity_id": str(
							action.get(
								"id",
								""
							)
						)
					}
				}
			]
		})

	return rows


func _prison_contract_for_actor(
		actor: Person,
		_include_population_cards: bool = false
) -> Dictionary:
	if (
		gs == null
		or actor == null
	):
		return {}

	var actor_id: int = int(
		actor.id
	)

	if (
		gs.prison_engine != null
		and gs.prison_engine.has_method(
			"resident_prison_reality_contract"
		)
	):
		var prison_contract: Dictionary = (
			_safe_dictionary(
				gs.prison_engine.call(
					"resident_prison_reality_contract",
					actor_id
				)
			)
		)

		if not prison_contract.is_empty():
			return prison_contract

	if (
		gs.jail_engine != null
		and gs.jail_engine.has_method(
			"resident_jail_reality_contract"
		)
	):
		var jail_contract: Dictionary = (
			_safe_dictionary(
				gs.jail_engine.call(
					"resident_jail_reality_contract",
					actor_id
				)
			)
		)

		if not jail_contract.is_empty():
			return jail_contract

	return {}

func _identity_contract(
	actor: Person
) -> Dictionary:
	return {
		"actor_id": int(
			actor.id
		),
		"name": _actor_name(
			actor
		),
		"age": int(
			actor.age
		),
		"alive": bool(
			actor.alive
		)
	}


func _actor_name(
	actor: Person
) -> String:
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

	return (
		full_name
		if full_name != ""
		else "Person %d" % int(
			actor.id
		)
	)


func _section(
	value: String
) -> String:
	var clean: String = str(
		value
	).strip_edges().to_lower()

	if clean in [
		"overview",
		"crime_actions",
		"targets",
		"weapons",
		"cases",
		"pending",
		"custody",
		"prison",
		"population",
		"family"
	]:
		return clean

	return "overview"

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
		"popup_title": "Crime Hub",
		"popup_text": message,
		"popup_footer": "Tap anywhere to continue."
	}


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(
	value: Variant
) -> Array:
	if typeof(
		value
	) == TYPE_ARRAY:
		return (
			value as Array
		).duplicate(true)

	return []