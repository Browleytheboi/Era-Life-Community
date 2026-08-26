extends Resource
class_name RealmPopulationContractPanel

const PANEL_SCHEMA:= "eralife.realm_population_contract_panel"
const CONTRACT_VERSION:= 2

var gs: GameState = null
var surfaces_by_realm: Dictionary = {}
var card_graph_packets_by_realm: Dictionary = {}
var surface_key_by_alias: Dictionary = {}
var active_realm_key: String = ""
var population_lens_viewer: PopulationLensViewer = null
var game_state_subscription_ready: bool = false
var last_game_state_truth_pulse: Dictionary = {}
var incremental_projection_jobs: Dictionary = {}
var incremental_projection_order: Array = []
var incremental_projection_service_active: bool = false
var incremental_projection_generation: int = 0

func _init(_gs: GameState = null) -> void:
	bind_game_state(_gs)


func bind_game_state(_gs: GameState) -> void:
	if gs == _gs and game_state_subscription_ready:
		return

	gs = _gs
	game_state_subscription_ready = false
	_subscribe_to_game_state()


func bind_population_lens_viewer(viewer: PopulationLensViewer) -> void:
	population_lens_viewer = viewer


func _subscribe_to_game_state() -> void:
	if (
		gs == null
		or gs.event_bus == null
	):
		return

	for raw_event_name in [
		"npc_born",
		"npc_died",
		"npc_moved",
		"year_passed",
		"era_shift",
		"population.year.tick",
		"population.shard.spawn_entity",
		"population.truth.shard_resolved",
		"population.card_graph_packet.updated",
		"many_realms_realm_created",
		"many_realms_succession"
	]:
		var event_name: String = str(
			raw_event_name
		).strip_edges()

		if event_name == "":
			continue

		var renderer_delta_event: bool = (
			event_name
			== "population.card_graph_packet.updated"
		)

		gs.event_bus.subscribe(
			event_name,
			self,
			"_on_game_state_population_truth_changed",
			{
				"allow_defer": not renderer_delta_event,
				"force_immediate": renderer_delta_event,
				"lane": (
					"realm_population_contract_panel"
				),
				"subscription_id": (
					"realm_population_contract_panel:%s"
					% event_name
				),
				"subscription_priority": (
					5
					if renderer_delta_event
					else 25
				),
				"replay_on_subscribe": false
			}
		)

	game_state_subscription_ready = true

	if typeof(
		gs.scenario_state
	) == TYPE_DICTIONARY:
		gs.scenario_state [
			"realm_population_contract_panel_subscribed_to_game_state"
		] = true
		gs.scenario_state [
			"realm_population_contract_panel_subscribed_at_ms"
		] = int(
			Time.get_ticks_msec()
		)
		gs.scenario_state [
			"realm_population_contract_panel_schema"
		] = PANEL_SCHEMA
		gs.scenario_state [
			"realm_population_contract_panel_version"
		] = CONTRACT_VERSION
		gs.scenario_state [
			"realm_population_renderer_delta_delivery_immediate"
		] = true


func _on_game_state_population_truth_changed(
	payload: Dictionary = {}
) -> void:
	_refresh_surface_from_truth_shard_event(
		payload
	)

	var pulse: Dictionary = {
		"event_name": str(
			payload.get(
				"event_name",
				""
			)
		),
		"realm_id": int(
			payload.get(
				"realm_id",
				-1
			)
		),
		"at_ms": int(
			Time.get_ticks_msec()
		),
		"surface_count": surfaces_by_realm.size(),
		"ui_is_renderer_only": true,
	}

	last_game_state_truth_pulse = (
		pulse.duplicate(false)
	)

	if (
		gs != null
		and typeof(
			gs.scenario_state
		) == TYPE_DICTIONARY
	):
		gs.scenario_state [
			"realm_population_contract_panel_last_game_state_truth_pulse"
		] = pulse.duplicate(false)
		gs.scenario_state [
			"realm_population_contract_panel_surface_count_after_truth_pulse"
		] = surfaces_by_realm.size()
		gs.scenario_state [
			"realm_population_truth_event_surface_fanout_forbidden"
		] = true
func _refresh_surface_from_truth_shard_event(
	payload: Dictionary = {}
) -> void:
	if typeof(payload) != TYPE_DICTIONARY:
		return

	var event_name: String = str(
		payload.get(
			"event_name",
			payload.get(
				"event",
				""
			)
		)
	).strip_edges()

	if event_name != (
		"population.card_graph_packet.updated"
	):
		return

	var data_raw: Variant = payload.get(
		"data",
		payload
	)
	var data: Dictionary = (
		data_raw as Dictionary
		if typeof(data_raw) == TYPE_DICTIONARY
		else payload
	)
	var realm_id: int = int(
		payload.get(
			"realm_id",
			data.get(
				"realm_id",
				-1
			)
		)
	)

	if realm_id <= 0:
		return

	var realm_name: String = str(
		payload.get(
			"realm_name",
			data.get(
				"realm_name",
				"Realm %d" % realm_id
			)
		)
	).strip_edges()
	var renderer_delta_raw: Variant = payload.get(
		"renderer_delta",
		data.get(
			"renderer_delta",
			{}
		)
	)

	if typeof(
		renderer_delta_raw
	) != TYPE_DICTIONARY:
		return

	var renderer_delta: Dictionary = (
		renderer_delta_raw as Dictionary
	)

	if renderer_delta.is_empty():
		return

	var key: String = _resolve_surface_key(
		realm_id,
		realm_name
	)

	if key == "":
		key = _realm_key(
			realm_id
		)

	if not surfaces_by_realm.has(
		key
	):
		register_surface_shell(
			realm_id,
			realm_name,
			{
				"source": (
					"realm_population_contract_panel."
					+ "renderer_delta_shell"
				),
				"event_name": event_name,
				"ui_is_renderer_only": true
			}
		)

	var queue_report: Dictionary = (
		queue_incremental_projection(
			realm_id,
			realm_name,
			renderer_delta,
			{
				"source": (
					"realm_population_contract_panel."
					+ "renderer_delta_queue"
				),
				"event_name": event_name,
				"incremental_renderer": true,
				"one_card_per_timer_quantum": true,
				"ui_is_renderer_only": true
			}
		)
	)

	if (
		gs != null
		and typeof(
			gs.scenario_state
		) == TYPE_DICTIONARY
	):
		gs.scenario_state [
			"realm_population_last_incremental_projection_queue_report"
		] = queue_report.duplicate(false)
		gs.scenario_state [
			"realm_population_full_surface_replacement_from_shard_forbidden"
		] = true
		gs.scenario_state [
			"realm_population_renderer_consumed_contract_delta"
		] = true
func register_card_graph_packet(
	realm_id: int,
	realm_name: String,
	card_graph_packet: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	if realm_id <= 0:
		return {
			"success": false,
			"reason": "invalid_realm_id",
			"schema": PANEL_SCHEMA,
			"ui_is_renderer_only": true
		}

	if card_graph_packet.is_empty():
		return {
			"success": false,
			"reason": "empty_card_graph_packet",
			"schema": PANEL_SCHEMA,
			"ui_is_renderer_only": true
		}

	var key: String = _realm_key(realm_id)

	card_graph_packets_by_realm [key] = {
		"schema": "eralife.realm_population_contract_panel.card_graph_packet",
		"version": CONTRACT_VERSION,
		"realm_id": realm_id,
		"realm_name": str(realm_name).strip_edges(),
		"card_graph_packet": card_graph_packet.duplicate(true),
		"context": context.duplicate(true),
		"registered_at_ms": int(Time.get_ticks_msec()),
		"ui_is_renderer_only": true,
		"intent_is_not_action": true
	}

	_register_alias_for_key(key, str(realm_name))
	_register_alias_for_key(key, str(realm_id))

	if typeof(card_graph_packet.get("population_lens_aliases", [])) == TYPE_ARRAY:
		for raw_alias in card_graph_packet.get("population_lens_aliases", []):
			_register_alias_for_key(key, str(raw_alias))

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["realm_population_contract_panel_card_graph_packet_registered_%d" % realm_id] = true
		gs.scenario_state ["realm_population_contract_panel_card_graph_packet_registered_at_ms_%d" % realm_id] = int(Time.get_ticks_msec())
		gs.scenario_state ["realm_population_contract_panel_card_graph_packet_registry_count"] = card_graph_packets_by_realm.size()

	return {
		"success": true,
		"schema": PANEL_SCHEMA,
		"version": CONTRACT_VERSION,
		"realm_id": realm_id,
		"realm_name": str(realm_name).strip_edges(),
		"ui_is_renderer_only": true,
		"card_count": int(card_graph_packet.get("visible_card_count", 0)),
		"edge_count": (card_graph_packet.get("graph_edges", []) as Array).size() if typeof(card_graph_packet.get("graph_edges", [])) == TYPE_ARRAY else 0
	}


func card_graph_packet_for(realm_id: int, realm_name: String = "") -> Dictionary:
	var key: String = _resolve_surface_key(realm_id, realm_name)
	if key == "":
		key = _realm_key(realm_id)

	var packet_raw: Variant = card_graph_packets_by_realm.get(key, {})
	if typeof(packet_raw) != TYPE_DICTIONARY:
		return {}

	var packet: Dictionary = packet_raw
	var graph_raw: Variant = packet.get("card_graph_packet", {})
	if typeof(graph_raw) != TYPE_DICTIONARY:
		return {}

	return (graph_raw as Dictionary).duplicate(true)


func has_card_graph_packet_for(realm_id: int, realm_name: String = "") -> bool:
	return not card_graph_packet_for(realm_id, realm_name).is_empty()

func register_surface(
	realm_id: int,
	realm_name: String,
	surface: Control,
	view_contract: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	if realm_id <= 0:
		return {
			"success": false,
			"reason": "invalid_realm_id",
			"schema": PANEL_SCHEMA,
			"ui_is_renderer_only": true
		}

	if surface == null or not is_instance_valid(surface):
		return {
			"success": false,
			"reason": "missing_surface",
			"schema": PANEL_SCHEMA,
			"ui_is_renderer_only": true
		}

	var key: String = _realm_key(realm_id)
	_erase_aliases_for_surface_key(key)

	var graph_nodes: Dictionary = {}
	if surface.has_meta("population_lens_graph_nodes_prebound"):
		var graph_nodes_raw: Variant = surface.get_meta("population_lens_graph_nodes_prebound", {})
		if typeof(graph_nodes_raw) == TYPE_DICTIONARY:
			graph_nodes = graph_nodes_raw
	var card_graph_packet: Dictionary = {}
	if typeof(view_contract.get("population_card_graph_packet", {})) == TYPE_DICTIONARY:
		card_graph_packet = view_contract.get("population_card_graph_packet", {}).duplicate(true)
	elif typeof(view_contract.get("population_card_packets", {})) == TYPE_DICTIONARY:
		card_graph_packet = {
			"schema": "eralife.population_card_graph_packet.inline_from_view_contract",
			"version": CONTRACT_VERSION,
			"realm_id": realm_id,
			"realm_name": str(realm_name).strip_edges(),
			"cards_by_entity_id": view_contract.get("population_card_packets", {}).duplicate(true),
			"graph_node_contracts": view_contract.get("graph_node_contracts", {}).duplicate(true) if typeof(view_contract.get("graph_node_contracts", {})) == TYPE_DICTIONARY else {},
			"graph_edges": view_contract.get("graph_edges", []).duplicate(true) if typeof(view_contract.get("graph_edges", [])) == TYPE_ARRAY else [],
			"ui_is_renderer_only": true
		}

	if not card_graph_packet.is_empty():
		register_card_graph_packet(
			realm_id,
			realm_name,
			card_graph_packet,
			context.merged({
				"source": "register_surface_inline_card_graph_packet",
			}, true)
		)
	surface.visible = false
	surface.mouse_filter = Control.MOUSE_FILTER_PASS
	surface.set_meta("realm_population_contract_panel", true)
	surface.set_meta("realm_population_contract_panel_schema", PANEL_SCHEMA)
	surface.set_meta("realm_population_contract_panel_version", CONTRACT_VERSION)
	surface.set_meta("realm_population_realm_id", realm_id)
	surface.set_meta("realm_population_realm_name", str(realm_name).strip_edges())
	surface.set_meta("realm_population_surface_prebuilt", true)
	surface.set_meta("realm_population_ui_build_on_press_forbidden", true)
	surface.set_meta("realm_population_view_contract", view_contract.duplicate(true))
	surface.set_meta("population_lens_viewer_bound", population_lens_viewer != null)
	surface.set_meta("population_lens_alias_registry_enabled", true)
	surface.set_meta("population_lens_graph_nodes_registered_with_provider", graph_nodes.size())
	surface.set_meta("population_lens_click_path_graph_scan_forbidden", true)

	var packet: Dictionary = {
		"schema": PANEL_SCHEMA,
		"version": CONTRACT_VERSION,
		"realm_id": realm_id,
		"realm_name": str(realm_name).strip_edges(),
		"surface": surface,
		"view_contract": view_contract.duplicate(true),
		"graph_nodes": graph_nodes,
		"context": context.duplicate(true),
		"registered_at_ms": int(Time.get_ticks_msec()),
		"ui_is_renderer_only": true,
		"intent_is_not_action": true,
		"population_lens_viewer_bound": population_lens_viewer != null,
		"card_graph_packet": card_graph_packet,
		"population_card_graph_packet_prebuilt": not card_graph_packet.is_empty(),
		"population_lens_graph_nodes_prebound": true,
	}

	surfaces_by_realm [key] = packet
	_register_aliases_for_packet(key, packet)

	return {
		"success": true,
		"schema": PANEL_SCHEMA,
		"version": CONTRACT_VERSION,
		"realm_id": realm_id,
		"realm_name": str(realm_name).strip_edges(),
		"ui_is_renderer_only": true,
		"population_lens_viewer_bound": population_lens_viewer != null,
		"population_lens_graph_nodes_prebound": graph_nodes.size()
	}
func register_surface_shell(
	realm_id: int,
	realm_name: String,
	context: Dictionary = {}
) -> Dictionary:
	if realm_id <= 0:
		return {
			"success": false,
			"reason": "invalid_realm_id",
			"schema": PANEL_SCHEMA,
			"ui_is_renderer_only": true
		}

	var clean_name: String = str(
		realm_name
	).strip_edges()

	if clean_name == "":
		clean_name = "Realm %d" % realm_id

	var key: String = _realm_key(
		realm_id
	)

	if surfaces_by_realm.has(
		key
	):
		return {
			"success": true,
			"reason": "surface_shell_already_exists",
			"schema": PANEL_SCHEMA,
			"realm_id": realm_id,
			"realm_name": clean_name,
			"ui_is_renderer_only": true
		}

	var surface:= VBoxContainer.new()
	surface.name = (
		"RealmPopulationSurfaceShell_%d"
		% realm_id
	)
	surface.visible = false
	surface.mouse_filter = (
		Control.MOUSE_FILTER_PASS
	)
	surface.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	surface.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	surface.add_theme_constant_override(
		"separation",
		10
	)

	var heading:= Label.new()
	heading.text = (
		"REALM POPULATION • %s"
		% clean_name.to_upper()
	)
	heading.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	heading.add_theme_font_size_override(
		"font_size",
		20
	)
	surface.add_child(
		heading
	)

	var status_label:= Label.new()
	status_label.text = (
		"Population truth is resident and streaming. "
		+ "Cards will appear continuously."
	)
	status_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	status_label.add_theme_font_size_override(
		"font_size",
		13
	)
	surface.add_child(
		status_label
	)

	var sections_root:= VBoxContainer.new()
	sections_root.name = (
		"IncrementalPopulationSections"
	)
	sections_root.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	sections_root.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	sections_root.add_theme_constant_override(
		"separation",
		10
	)
	surface.add_child(
		sections_root
	)

	surface.set_meta(
		"realm_population_surface_shell",
		true
	)
	surface.set_meta(
		"realm_population_surface_prebuilt",
		true
	)
	surface.set_meta(
		"realm_population_truth_state",
		"partial"
	)
	surface.set_meta(
		"realm_population_runtime_hydration_pending",
		true
	)
	surface.set_meta(
		"realm_population_ui_build_on_press_forbidden",
		true
	)
	surface.set_meta(
		"population_incremental_status_label",
		status_label
	)
	surface.set_meta(
		"population_incremental_sections_root",
		sections_root
	)
	surface.set_meta(
		"population_incremental_section_grids",
		{}
	)
	surface.set_meta(
		"population_incremental_rendered_entity_ids",
		{}
	)
	surface.set_meta(
		"population_incremental_queued_entity_ids",
		{}
	)
	surface.set_meta(
		"population_incremental_pending_rows",
		[]
	)
	surface.set_meta(
		"population_incremental_contract_signature",
		""
	)
	surface.set_meta(
		"population_incremental_cards_rendered",
		0
	)
	surface.set_meta(
		"ui_is_renderer_only",
		true
	)

	var view_contract: Dictionary = {
		"schema": (
			"eralife.crown_population_wall_view_contract"
		),
		"version": CONTRACT_VERSION,
		"source_engine": PANEL_SCHEMA,
		"realm_id": realm_id,
		"realm_name": clean_name,
		"truth_state": "partial",
		"federal_republic_population_contract": false,
		"federal_executive": [],
		"federal_cabinet": [],
		"federal_senate": [],
		"federal_supreme_court": [],
		"federal_governors": [],
		"royals": [],
		"officials": [],
		"nobles": [],
		"masters": [],
		"citizens": [],
		"population_card_packets": {},
		"population_card_graph_packet": {},
		"graph_node_contracts": {},
		"graph_edges": [],
		"category_order": [
			"royals",
			"nobles",
			"masters",
			"citizens"
		],
		"ui_is_renderer_only": true,
		"click_path_build_forbidden": true
	}
	var packet: Dictionary = {
		"schema": PANEL_SCHEMA,
		"version": CONTRACT_VERSION,
		"realm_id": realm_id,
		"realm_name": clean_name,
		"surface": surface,
		"view_contract": view_contract.duplicate(true),
		"graph_nodes": {},
		"context": context.duplicate(true),
		"registered_at_ms": int(
			Time.get_ticks_msec()
		),
		"ui_is_renderer_only": true,
		"truth_state": "partial",
		"intent_is_not_action": true,
		"population_lens_viewer_bound": (
			population_lens_viewer != null
		),
	}

	surfaces_by_realm [
		key
	] = packet

	_register_aliases_for_packet(
		key,
		packet
	)

	if (
		gs != null
		and typeof(
			gs.scenario_state
		) == TYPE_DICTIONARY
	):
		gs.scenario_state [
			"realm_population_surface_shell_registered_%d"
			% realm_id
		] = true
		gs.scenario_state [
			"realm_population_surface_shell_registered_at_ms_%d"
			% realm_id
		] = int(
			Time.get_ticks_msec()
		)
		gs.scenario_state [
			"realm_population_surface_shell_registry_count"
		] = surfaces_by_realm.size()

	return {
		"success": true,
		"schema": PANEL_SCHEMA,
		"version": CONTRACT_VERSION,
		"realm_id": realm_id,
		"realm_name": clean_name,
		"truth_state": "partial",
		"ui_is_renderer_only": true
	}
func queue_incremental_projection(
	realm_id: int,
	realm_name: String,
	view_contract: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	if (
		realm_id <= 0
		or view_contract.is_empty()
	):
		return {
			"success": false,
			"reason": "invalid_incremental_projection",
			"realm_id": realm_id,
			"schema": PANEL_SCHEMA
		}

	var clean_name: String = str(
		realm_name
	).strip_edges()
	if clean_name == "":
		clean_name = "Realm %d" % realm_id

	var key: String = _realm_key(
		realm_id
	)
	if not surfaces_by_realm.has(
		key
	):
		register_surface_shell(
			realm_id,
			clean_name,
			context
		)

	var projection_context: Dictionary = (
		context.duplicate(false)
	)
	projection_context ["incremental_renderer"] = true
	projection_context [
		"one_card_per_timer_quantum"
	] = true
	projection_context [
		"renderer_delta_ingested_once"
	] = true

	var existing_job_raw: Variant = (
		incremental_projection_jobs.get(
			key,
			{}
		)
	)
	var existing_job: Dictionary = (
		existing_job_raw as Dictionary
		if typeof(existing_job_raw) == TYPE_DICTIONARY
		else {}
	)

	var pending_contracts: Array = []
	if not existing_job.is_empty():
		var pending_raw: Variant = existing_job.get(
			"pending_contracts",
			[]
		)
		if typeof(pending_raw) == TYPE_ARRAY:
			pending_contracts = pending_raw as Array
		elif existing_job.has(
			"view_contract"
		):
			var legacy_view_raw: Variant = (
				existing_job.get(
					"view_contract",
					{}
				)
			)
			if typeof(legacy_view_raw) == TYPE_DICTIONARY:
				pending_contracts.append({
					"view_contract": (
						legacy_view_raw as Dictionary
					),
					"context": existing_job.get(
						"context",
						{}
					),
					"queued_at_ms": int(
						existing_job.get(
							"queued_at_ms",
							Time.get_ticks_msec()
						)
					)
				})

	pending_contracts.append({
		"view_contract": view_contract,
		"context": projection_context,
		"queued_at_ms": int(
			Time.get_ticks_msec()
		)
	})

	incremental_projection_jobs [key] = {
		"key": key,
		"realm_id": realm_id,
		"realm_name": clean_name,
		"pending_contracts": pending_contracts,
		"attempts": int(
			existing_job.get(
				"attempts",
				0
			)
		),
		"queued_at_ms": int(
			existing_job.get(
				"queued_at_ms",
				Time.get_ticks_msec()
			)
		),
		"renderer_delta_fifo": true
	}

	if not incremental_projection_order.has(
		key
	):
		incremental_projection_order.append(
			key
		)

	if not incremental_projection_service_active:
		incremental_projection_service_active = true
		incremental_projection_generation += 1
		_schedule_incremental_projection_service(
			incremental_projection_generation
		)

	return {
		"success": true,
		"schema": PANEL_SCHEMA,
		"realm_id": realm_id,
		"realm_name": clean_name,
		"queue_size": (
			incremental_projection_order.size()
		),
		"pending_contract_count": (
			pending_contracts.size()
		),
		"renderer_delta_fifo": true,
		"renderer_delta_ingested_once": true,
		"one_card_per_timer_quantum": true,
		"deep_contract_copy_per_card": false,
		"ui_is_renderer_only": true
	}
func _schedule_incremental_projection_service(
	generation: int
) -> void:
	if generation != incremental_projection_generation:
		return

	var tree:= Engine.get_main_loop() as SceneTree
	if tree == null:
		incremental_projection_service_active = false
		return

	var timer:= tree.create_timer(
		0.032,
		true,
		false,
		true
	)
	timer.timeout.connect(
		Callable(
			self,
			"_service_incremental_projection_queue"
		).bind(
			generation
		),
		CONNECT_ONE_SHOT
	)

func _service_incremental_projection_queue(
	generation: int
) -> void:
	if generation != incremental_projection_generation:
		return

	if incremental_projection_order.is_empty():
		incremental_projection_service_active = false
		return

	var key: String = str(
		incremental_projection_order.pop_front()
	)
	var job_raw: Variant = (
		incremental_projection_jobs.get(
			key,
			{}
		)
	)
	var job: Dictionary = (
		job_raw as Dictionary
		if typeof(job_raw) == TYPE_DICTIONARY
		else {}
	)

	if job.is_empty():
		if incremental_projection_order.is_empty():
			incremental_projection_service_active = false
			return
		_schedule_incremental_projection_service(
			generation
		)
		return

	var pending_raw: Variant = job.get(
		"pending_contracts",
		[]
	)
	var pending_contracts: Array = (
		pending_raw as Array
		if typeof(pending_raw) == TYPE_ARRAY
		else []
	)

	if (
		pending_contracts.is_empty()
		and job.has(
			"view_contract"
		)
	):
		var legacy_view_raw: Variant = job.get(
			"view_contract",
			{}
		)
		if typeof(legacy_view_raw) == TYPE_DICTIONARY:
			pending_contracts.append({
				"view_contract": (
					legacy_view_raw as Dictionary
				),
				"context": job.get(
					"context",
					{}
				),
				"queued_at_ms": int(
					job.get(
						"queued_at_ms",
						Time.get_ticks_msec()
					)
				)
			})

	if pending_contracts.is_empty():
		incremental_projection_jobs.erase(
			key
		)
		if incremental_projection_order.is_empty():
			incremental_projection_service_active = false
			return
		_schedule_incremental_projection_service(
			generation
		)
		return

	var active_delta_raw: Variant = (
		pending_contracts [0]
	)
	var active_delta: Dictionary = (
		active_delta_raw as Dictionary
		if typeof(active_delta_raw) == TYPE_DICTIONARY
		else {}
	)

	var view_contract_raw: Variant = (
		active_delta.get(
			"view_contract",
			{}
		)
	)
	var view_contract: Dictionary = (
		view_contract_raw as Dictionary
		if typeof(view_contract_raw) == TYPE_DICTIONARY
		else {}
	)

	var context_raw: Variant = active_delta.get(
		"context",
		{}
	)
	var projection_context: Dictionary = (
		context_raw as Dictionary
		if typeof(context_raw) == TYPE_DICTIONARY
		else {}
	)

	var packet_raw: Variant = surfaces_by_realm.get(
		key,
		{}
	)
	var packet: Dictionary = (
		packet_raw as Dictionary
		if typeof(packet_raw) == TYPE_DICTIONARY
		else {}
	)

	var surface:= packet.get(
		"surface",
		null
	) as Control
	var result: Dictionary = {}

	if (
		population_lens_viewer != null
		and surface != null
		and is_instance_valid(
			surface
		)
		and not view_contract.is_empty()
	):
		result = (
			population_lens_viewer
			.apply_incremental_realm_population_contract(
				surface,
				int(
					job.get(
						"realm_id",
						-1
					)
				),
				str(
					job.get(
						"realm_name",
						""
					)
				),
				view_contract,
				projection_context
			)
		)

	if bool(
		result.get(
			"complete",
			false
		)
	):
		pending_contracts.pop_front()

	job ["pending_contracts"] = pending_contracts
	job ["renderer_delta_fifo"] = true

	packet ["view_contract"] = view_contract
	packet ["truth_state"] = (
		"hot"
		if (
			pending_contracts.is_empty()
			and bool(
				view_contract.get(
					"truth_complete",
					false
				)
			)
		)
		else "partial"
	)
	packet ["incremental_projection_result"] = result
	packet ["updated_at_ms"] = int(
		Time.get_ticks_msec()
	)
	packet ["deep_contract_copy_per_card"] = false
	packet ["one_card_per_timer_quantum"] = true
	packet ["renderer_delta_fifo"] = true
	packet ["pending_renderer_delta_count"] = (
		pending_contracts.size()
	)
	surfaces_by_realm [key] = packet

	if pending_contracts.is_empty():
		incremental_projection_jobs.erase(
			key
		)
	else:
		incremental_projection_jobs [key] = job
		if not incremental_projection_order.has(
			key
		):
			incremental_projection_order.append(
				key
			)

	if incremental_projection_order.is_empty():
		incremental_projection_service_active = false
		return

	_schedule_incremental_projection_service(
		generation
	)
func has_surface(realm_id: int) -> bool:
	return has_surface_for(realm_id, "")


func has_surface_for(realm_id: int, realm_name: String = "") -> bool:
	return not surface_packet_for(realm_id, realm_name).is_empty()


func surface_packet(realm_id: int) -> Dictionary:
	return surface_packet_for(realm_id, "")


func surface_packet_for(realm_id: int, realm_name: String = "") -> Dictionary:
	var key: String = _resolve_surface_key(realm_id, realm_name)
	if key == "":
		return {}

	var packet_raw: Variant = surfaces_by_realm.get(key, {})
	if typeof(packet_raw) != TYPE_DICTIONARY:
		return {}

	return packet_raw as Dictionary


func mount_surface(realm_id: int, target_parent: Control) -> Dictionary:
	return mount_surface_for(realm_id, "", target_parent)


func mount_surface_for(realm_id: int, realm_name: String, target_parent: Control) -> Dictionary:
	if target_parent == null or not is_instance_valid(target_parent):
		return {
			"success": false,
			"reason": "missing_target_parent",
			"schema": PANEL_SCHEMA,
			"ui_is_renderer_only": true
		}

	var packet: Dictionary = surface_packet_for(realm_id, realm_name)
	if packet.is_empty():
		return {
			"success": false,
			"reason": "surface_not_prebuilt",
			"schema": PANEL_SCHEMA,
			"realm_id": realm_id,
			"realm_name": realm_name,
			"ui_is_renderer_only": true
		}

	var surface:= packet.get("surface", null) as Control
	if surface == null or not is_instance_valid(surface) or surface.is_queued_for_deletion():
		return {
			"success": false,
			"reason": "surface_instance_invalid_or_queued_for_deletion",
			"schema": PANEL_SCHEMA,
			"realm_id": int(packet.get("realm_id", realm_id)),
			"realm_name": str(packet.get("realm_name", realm_name)),
			"ui_is_renderer_only": true,
		}

	var current_parent: Node = surface.get_parent()
	if current_parent != null and current_parent != target_parent:
		current_parent.remove_child(surface)

	if surface.get_parent() == null:
		target_parent.add_child(surface)

	if surface.get_parent() == target_parent:
		target_parent.move_child(surface, target_parent.get_child_count() - 1)

	surface.visible = true
	surface.show()
	surface.modulate = Color(1.0, 1.0, 1.0, 1.0)
	surface.mouse_filter = Control.MOUSE_FILTER_PASS
	surface.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	surface.size_flags_vertical = Control.SIZE_EXPAND_FILL
	surface.set_meta("population_lens_surface_mounted", true)
	surface.set_meta("population_lens_surface_mounted_at_ms", int(Time.get_ticks_msec()))
	surface.set_meta("population_lens_surface_mount_parent", str(target_parent.name))
	surface.set_meta("population_lens_surface_was_not_built_on_click", true)
	surface.update_minimum_size()
	surface.queue_redraw()

	target_parent.update_minimum_size()
	target_parent.queue_redraw()

	if surface is Container:
		(surface as Container).queue_sort()
	if target_parent is Container:
		(target_parent as Container).queue_sort()

	active_realm_key = _realm_key(int(packet.get("realm_id", realm_id)))

	return {
		"success": true,
		"schema": PANEL_SCHEMA,
		"version": CONTRACT_VERSION,
		"realm_id": int(packet.get("realm_id", realm_id)),
		"realm_name": str(packet.get("realm_name", realm_name)),
		"surface": surface,
		"view_contract": packet.get("view_contract", {}).duplicate(true) if typeof(packet.get("view_contract", {})) == TYPE_DICTIONARY else {},
		"graph_nodes": packet.get("graph_nodes", {}) if typeof(packet.get("graph_nodes", {})) == TYPE_DICTIONARY else {},
		"ui_is_renderer_only": true,
		"population_lens_viewer_bound": population_lens_viewer != null,
		"population_lens_graph_nodes_prebound": true,
	}
func detach_active_surface(cache_parent: Control) -> void:
	if active_realm_key == "":
		return

	if not surfaces_by_realm.has(active_realm_key):
		active_realm_key = ""
		return

	var packet_raw: Variant = surfaces_by_realm.get(active_realm_key, {})
	if typeof(packet_raw) != TYPE_DICTIONARY:
		active_realm_key = ""
		return

	var packet: Dictionary = packet_raw
	var surface:= packet.get("surface", null) as Control
	if surface == null or not is_instance_valid(surface):
		active_realm_key = ""
		return

	surface.visible = false

	if cache_parent != null and is_instance_valid(cache_parent):
		var current_parent: Node = surface.get_parent()
		if current_parent != null and current_parent != cache_parent:
			current_parent.remove_child(surface)

		if surface.get_parent() == null:
			cache_parent.add_child(surface)

	active_realm_key = ""


func update_contract(realm_id: int, view_contract: Dictionary, realm_name: String = "") -> void:
	var key: String = _resolve_surface_key(realm_id, realm_name)
	if key == "":
		return

	var packet_raw: Variant = surfaces_by_realm.get(key, {})
	if typeof(packet_raw) != TYPE_DICTIONARY:
		return

	var packet: Dictionary = packet_raw
	packet ["view_contract"] = view_contract.duplicate(true)
	packet ["updated_at_ms"] = int(Time.get_ticks_msec())

	var surface:= packet.get("surface", null) as Control
	if surface != null and is_instance_valid(surface):
		surface.set_meta("realm_population_view_contract", view_contract.duplicate(true))
		surface.set_meta("realm_population_surface_contract_updated_at_ms", int(Time.get_ticks_msec()))

		if surface.has_meta("population_lens_graph_nodes_prebound"):
			var graph_nodes_raw: Variant = surface.get_meta("population_lens_graph_nodes_prebound", {})
			if typeof(graph_nodes_raw) == TYPE_DICTIONARY:
				packet ["graph_nodes"] = graph_nodes_raw
				packet ["population_lens_graph_nodes_prebound"] = true

	surfaces_by_realm [key] = packet
	_register_aliases_for_packet(key, packet)


func replace_surface(
	realm_id: int,
	realm_name: String,
	surface: Control,
	view_contract: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	var key: String = _resolve_surface_key(realm_id, realm_name)
	if key == "":
		key = _realm_key(realm_id)

	if surfaces_by_realm.has(key):
		var old_packet_raw: Variant = surfaces_by_realm.get(key, {})
		if typeof(old_packet_raw) == TYPE_DICTIONARY:
			var old_packet: Dictionary = old_packet_raw
			var old_surface:= old_packet.get("surface", null) as Control
			if old_surface != null and is_instance_valid(old_surface):
				var old_parent: Node = old_surface.get_parent()
				if old_parent != null:
					old_parent.remove_child(old_surface)
				old_surface.queue_free()

	_erase_aliases_for_surface_key(key)
	surfaces_by_realm.erase(key)

	return register_surface(
		realm_id,
		realm_name,
		surface,
		view_contract,
		context
	)


func add_aliases(realm_id: int, realm_name: String, aliases: Array) -> void:
	var key: String = _resolve_surface_key(realm_id, realm_name)
	if key == "":
		return

	for raw_alias in aliases:
		_register_alias_for_key(key, str(raw_alias))


func _resolve_surface_key(realm_id: int, realm_name: String = "") -> String:
	var direct_key: String = _realm_key(realm_id)
	if realm_id > 0 and surfaces_by_realm.has(direct_key):
		return direct_key

	var alias_key: String = _alias_key(realm_name)
	if alias_key != "" and surface_key_by_alias.has(alias_key):
		return str(surface_key_by_alias.get(alias_key, ""))

	for extra_alias in _derived_name_aliases(realm_name):
		var extra_key: String = _alias_key(str(extra_alias))
		if extra_key != "" and surface_key_by_alias.has(extra_key):
			return str(surface_key_by_alias.get(extra_key, ""))

	return ""


func _register_aliases_for_packet(key: String, packet: Dictionary) -> void:
	_register_alias_for_key(key, str(packet.get("realm_name", "")))

	var realm_id: int = int(packet.get("realm_id", -1))
	if realm_id > 0:
		surface_key_by_alias [_realm_key(realm_id)] = key

	var view_contract: Dictionary = packet.get("view_contract", {}) if typeof(packet.get("view_contract", {})) == TYPE_DICTIONARY else {}
	_register_alias_for_key(key, str(view_contract.get("realm_name", "")))
	_register_alias_for_key(key, str(view_contract.get("country", "")))
	_register_alias_for_key(key, str(view_contract.get("realm_contract_resolved_from_country", "")))

	var context: Dictionary = packet.get("context", {}) if typeof(packet.get("context", {})) == TYPE_DICTIONARY else {}
	var aliases_raw: Variant = context.get("surface_aliases", context.get("aliases", []))
	if typeof(aliases_raw) == TYPE_ARRAY:
		for raw_alias in aliases_raw:
			_register_alias_for_key(key, str(raw_alias))

	var contract_aliases_raw: Variant = view_contract.get("surface_aliases", view_contract.get("population_lens_aliases", []))
	if typeof(contract_aliases_raw) == TYPE_ARRAY:
		for raw_contract_alias in contract_aliases_raw:
			_register_alias_for_key(key, str(raw_contract_alias))


func _register_alias_for_key(key: String, alias_value: String) -> void:
	var clean_alias: String = str(alias_value).strip_edges()
	if clean_alias == "":
		return

	var alias_key: String = _alias_key(clean_alias)
	if alias_key != "":
		surface_key_by_alias [alias_key] = key

	for derived_alias in _derived_name_aliases(clean_alias):
		var derived_key: String = _alias_key(str(derived_alias))
		if derived_key != "":
			surface_key_by_alias [derived_key] = key


func _erase_aliases_for_surface_key(key: String) -> void:
	var dead_aliases: Array = []
	for raw_alias in surface_key_by_alias.keys():
		if str(surface_key_by_alias.get(raw_alias, "")) == key:
			dead_aliases.append(raw_alias)

	for raw_dead in dead_aliases:
		surface_key_by_alias.erase(raw_dead)


func _derived_name_aliases(value: String) -> Array:
	var out: Array = []
	var clean: String = str(value).strip_edges()
	if clean == "":
		return out

	out.append(clean)

	var lower: String = clean.to_lower()
	for era_prefix in ["ancient ", "medieval ", "industrial ", "modern ", "future "]:
		if lower.begins_with(era_prefix):
			out.append(clean.substr(era_prefix.length()).strip_edges())

	if lower.ends_with(" nation"):
		out.append(clean.substr(0, clean.length() - " nation".length()).strip_edges())

	if lower.ends_with(" kingdom"):
		out.append(clean.substr(0, clean.length() - " kingdom".length()).strip_edges())

	return out


func _alias_key(value: String) -> String:
	var cleaned: String = str(value).strip_edges().to_lower()
	for ch in [" ", "_", "-", "•", ".", ",", "'", "\"", ":", ";", "/", "\\", "(", ")"]:
		cleaned = cleaned.replace(ch, "")
	if cleaned == "":
		return ""
	return "alias:%s" % cleaned


func _realm_key(realm_id: int) -> String:
	return "realm:%d" % int(realm_id)