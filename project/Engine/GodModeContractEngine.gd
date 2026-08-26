extends Resource
class_name GodModeContractEngine

const ENGINE_STATE_SCHEMA:= "eralife.god_mode_contract_engine_state"
const PREWARM_INTENT_SCHEMA:= "eralife.god_mode.contract_engine.prewarm_intent"
const HANDOFF_INTENT_SCHEMA:= "eralife.god_mode.contract_engine.handoff_intent"
const PLAYABLE_SURFACE_SCHEMA:= "eralife.god_mode.contract_engine.playable_surface"
const CONTRACT_VERSION:= 1
const MAX_LEDGER:= 160

var gs: GameState = null

var panel_engine: GodModePanelContractEngine = null
var tracker_engine: GodModeTrackerContractEngine = null
var firewall_engine: GodModeRuntimeFirewallEngine = null











var prelife_era_catalog_engine: EraEngine = null

var sequence: int = 0
var lifecycle: String = "idle"

var tracked_settings: Dictionary = {}
var tracked_signature: String = ""

var prewarm_contract: Dictionary = {}
var handoff_contract: Dictionary = {}
var playable_surface_contract: Dictionary = {}
var last_report: Dictionary = {}
var ledger: Array = []

var prewarmed_game_state: GameState = null
var claimed_game_state: GameState = null


func _init(_gs: GameState = null):
	bind_game_state(_gs)


func bind_game_state(_gs: GameState) -> void:
	var same_resident_binding: bool = (
		gs == _gs
		and panel_engine != null
		and tracker_engine != null
		and firewall_engine != null
	)

	if same_resident_binding:
		return

	gs = _gs
	_ensure_state()
	_ensure_wrapped_engines()
	_import_from_scenario_state()
func bind_game_state_observation_only(
		_gs: GameState
) -> void:
	if gs == _gs:
		return












	gs = _gs

func _ensure_wrapped_engines() -> void:
	if panel_engine == null:
		panel_engine = GodModePanelContractEngine.new(gs)
	else:
		panel_engine.gs = gs

	if tracker_engine == null:
		tracker_engine = GodModeTrackerContractEngine.new(gs)
	else:
		tracker_engine.gs = gs

	if firewall_engine == null:
		firewall_engine = GodModeRuntimeFirewallEngine.new(gs)
	else:
		firewall_engine.gs = gs





	if (
		gs != null
		and gs.era_engine != null
	):
		prelife_era_catalog_engine = gs.era_engine
	elif (
		gs != null
		and (
			prelife_era_catalog_engine == null
			or prelife_era_catalog_engine.gs != gs
		)
	):
		prelife_era_catalog_engine = EraEngine.new(
			gs
		)
func emit_prelife_world_catalog(
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()
	_ensure_wrapped_engines()

	var era_key: String = str(
		context.get(
			"era",
			"Modern"
		)
	).strip_edges()
	var requested_country: String = str(
		context.get(
			"country",
			""
		)
	).strip_edges()
	var reality_mode: String = str(
		context.get(
			"reality_mode",
			"chaos"
		)
	).strip_edges().to_lower()

	if era_key == "":
		era_key = "Modern"

	if reality_mode == "":
		reality_mode = "chaos"

	if prelife_era_catalog_engine == null:
		return {
			"success": false,
			"reason": "prelife_era_catalog_authority_missing",
			"era": era_key,
			"country_options": [],
			"city_options": [],
			"birth_location_rows": [],
			"catalog_is_read_only": true,
			"ready_gate_member": false,
		}

	var rows_raw: Variant = (
		prelife_era_catalog_engine
		.get_birth_locations_for_era(
			era_key
		)
	)
	var rows: Array = (
		(rows_raw as Array).duplicate(true)
		if typeof(rows_raw) == TYPE_ARRAY
		else []
	)
	var normalized_rows: Array = []
	var countries: Array = []
	var cities: Array = []
	var seen_rows: Dictionary = {}
	var seen_countries: Dictionary = {}
	var seen_cities: Dictionary = {}

	for raw_row in rows:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = (
			raw_row as Dictionary
		).duplicate(true)
		var city_name: String = str(
			row.get(
				"city",
				""
			)
		).strip_edges()
		var country_name: String = str(
			row.get(
				"country",
				""
			)
		).strip_edges()

		if (
			city_name == ""
			or country_name == ""
		):
			continue

		var row_key: String = (
			"%s|%s"
			% [
				country_name.to_lower(),
				city_name.to_lower()
			]
		)

		if seen_rows.has(row_key):
			continue

		seen_rows [row_key] = true
		row ["city"] = city_name
		row ["country"] = country_name
		row ["catalog_authority"] = "GodModeContractEngine"
		row ["prelife_catalog"] = true
		normalized_rows.append(row)

		var country_key: String = country_name.to_lower()

		if not seen_countries.has(country_key):
			seen_countries [country_key] = true
			countries.append(country_name)

		if (
			requested_country == ""
			or country_name.to_lower()
			== requested_country.to_lower()
		):
			var city_key: String = city_name.to_lower()

			if not seen_cities.has(city_key):
				seen_cities [city_key] = true
				cities.append(city_name)

	countries.sort()
	cities.sort()

	var catalog_revision: String = (
		"%s:%s:%d:%d"
		% [
			era_key,
			reality_mode,
			normalized_rows.size(),
			int(
				hash(
					str(normalized_rows)
				)
			)
		]
	)

	if (
		gs != null
		and typeof(gs.scenario_state) == TYPE_DICTIONARY
	):
		gs.scenario_state [
			"god_mode_prelife_world_catalog_ready"
		] = true
		gs.scenario_state [
			"god_mode_prelife_world_catalog_era"
		] = era_key
		gs.scenario_state [
			"god_mode_prelife_world_catalog_revision"
		] = catalog_revision
		gs.scenario_state [
			"god_mode_prelife_world_catalog_row_count"
		] = normalized_rows.size()
		gs.scenario_state [
			"god_mode_prelife_world_catalog_started_runtime"
		] = false
		gs.scenario_state [
			"god_mode_prelife_world_catalog_ready_gate_member"
		] = false

	return {
		"success": true,
		"schema": "eralife.god_mode.prelife_world_catalog",
		"version": 1,
		"era": era_key,
		"reality_mode": reality_mode,
		"requested_country": requested_country,
		"country_options": countries,
		"city_options": cities,
		"birth_location_rows": normalized_rows,
		"catalog_revision": catalog_revision,
		"catalog_authority": "GodModeContractEngine",
		"catalog_is_read_only": true,
		"ready_gate_member": false,
		"ui_is_renderer_only": true
	}
func _ensure_state() -> void:
	if gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}


func _import_from_scenario_state() -> void:
	if gs == null or typeof(gs.scenario_state) != TYPE_DICTIONARY:
		return

	sequence = int(gs.scenario_state.get("god_mode_contract_engine_sequence", sequence))
	lifecycle = str(gs.scenario_state.get("god_mode_contract_engine_lifecycle", lifecycle)).strip_edges()

	tracked_settings = _safe_dictionary(gs.scenario_state.get("god_mode_contract_engine_tracked_settings", tracked_settings))
	tracked_signature = str(gs.scenario_state.get("god_mode_contract_engine_tracked_signature", tracked_signature)).strip_edges()

	prewarm_contract = _safe_dictionary(gs.scenario_state.get("god_mode_contract_engine_prewarm_contract", prewarm_contract))
	handoff_contract = _safe_dictionary(gs.scenario_state.get("god_mode_contract_engine_handoff_contract", handoff_contract))
	playable_surface_contract = _safe_dictionary(gs.scenario_state.get("god_mode_contract_engine_playable_surface_contract", playable_surface_contract))
	last_report = _safe_dictionary(gs.scenario_state.get("god_mode_contract_engine_last_report", last_report))
	ledger = _safe_array(gs.scenario_state.get("god_mode_contract_engine_ledger", ledger))


func capture_panel_state(panel_state: Dictionary, context: Dictionary = {}) -> Dictionary:
	_ensure_state()
	_ensure_wrapped_engines()

	var settings: Dictionary = _normalize_settings(panel_state)
	if settings.is_empty():
		return _fail("invalid_panel_state", {
			"source": str(context.get("source", "god_mode_contract_engine.capture_panel_state"))
		})

	var signature: String = signature_for_settings(settings)

	var capture_report: Dictionary = panel_engine.capture_panel_state(settings.duplicate(true), {
		"source": str(context.get("source", "god_mode_contract_engine.capture_panel_state")),
		"signature": signature,
		"ui_role": "viewer_capture_only",
	})

	if not bool(capture_report.get("success", false)):
		last_report = capture_report.duplicate(true)
		_commit_state()
		return last_report.duplicate(true)

	tracked_settings = settings.duplicate(true)
	tracked_signature = signature

	tracker_engine.track_panel_settings(settings.duplicate(true), {
		"source": "god_mode_contract_engine.capture_panel_state",
		"signature": signature,
	})

	lifecycle = "panel_captured"

	return _succeed("god_mode_panel_state_captured", {
		"signature": signature,
		"settings": settings.duplicate(true),
		"capture": capture_report.duplicate(true)
	})


func emit_prewarm_contract(panel_state: Dictionary, context: Dictionary = {}) -> Dictionary:
	_ensure_state()
	_ensure_wrapped_engines()

	var settings: Dictionary = _normalize_settings(panel_state)
	if settings.is_empty():
		return _fail("invalid_prewarm_settings", {
			"source": str(context.get("source", "god_mode_contract_engine.emit_prewarm_contract"))
		})

	var signature: String = signature_for_settings(settings)

	tracked_settings = settings.duplicate(true)
	tracked_signature = signature
	prewarmed_game_state = null
	claimed_game_state = null
	playable_surface_contract = {}
	handoff_contract = {}

	var panel_report: Dictionary = panel_engine.emit_prewarm_contract(settings.duplicate(true), {
		"source": str(context.get("source", "god_mode_contract_engine.emit_prewarm_contract")),
		"signature": signature,
		"panel_role": "viewer_emit_only",
	})

	if not bool(panel_report.get("success", false)):
		last_report = panel_report.duplicate(true)
		_commit_state()
		return last_report.duplicate(true)

	sequence += 1
	var now_ms: int = int(Time.get_ticks_msec())
	var contract_id: String = "god_mode_contract_engine_prewarm_%d_%d" % [sequence, now_ms]

	prewarm_contract = {
		"schema": PREWARM_INTENT_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": contract_id,
		"contract_id": contract_id,
		"mode": "god_mode_prewarm_requested",
		"handoff_stage": "prewarm_requested",
		"signature": signature,
		"settings": settings.duplicate(true),
		"panel_contract": panel_report.duplicate(true),
		"target_consumer": "RealityOrchestrator",
		"tracker_consumer": "GodModeTrackerContractEngine",
		"ready_button_is_door": true,
		"prewarm_builds_room": true,
		"created_at_ms": now_ms,
		"updated_at_ms": now_ms,
		"context": context.duplicate(true)
	}

	tracker_engine.mark_prewarm_queued(settings.duplicate(true), signature, {
		"source": "god_mode_contract_engine.emit_prewarm_contract",
		"panel_role_after_queue": "viewer_control_surface",
	})

	lifecycle = "prewarm_requested"

	_publish_contract_to_scenario("prewarm_requested")
	_route_prewarm_intent_to_reality_orchestrator(prewarm_contract)

	return _succeed("god_mode_prewarm_contract_emitted", {
		"signature": signature,
		"settings": settings.duplicate(true),
		"prewarm_contract": prewarm_contract.duplicate(true)
	})


func accept_prewarm_report(report: Dictionary, expected_signature: String = "", context: Dictionary = {}) -> Dictionary:
	_ensure_state()
	_ensure_wrapped_engines()

	var signature: String = str(expected_signature).strip_edges()
	if signature == "":
		signature = str(report.get("signature", tracked_signature)).strip_edges()

	if signature == "":
		return _fail("missing_prewarm_signature", context)

	if signature != tracked_signature:
		var allow_bridge_signature_normalization: bool = bool(context.get("signature_normalized_for_viewer_contract", false))
		var canonical_signature: String = str(context.get("canonical_signature", "")).strip_edges()

		if allow_bridge_signature_normalization and canonical_signature == tracked_signature:
			signature = tracked_signature
		else:
			return _fail("stale_prewarm_report", {
				"expected": tracked_signature,
				"received": signature,
				"context": context.duplicate(true)
			})

	if not bool(report.get("success", false)):
		lifecycle = "prewarm_failed"
		return _fail(str(report.get("reason", "prewarm_failed")), {
			"signature": signature,
			"report": report.duplicate(true)
		})

	var raw_gs: Variant = report.get("game_state", null)
	if not (raw_gs is GameState):
		lifecycle = "prewarm_failed"
		return _fail("prewarm_report_missing_game_state", {
			"signature": signature,
			"report": report.duplicate(true)
		})

	var capsule: GameState = raw_gs as GameState
	if capsule == null or capsule.player == null:
		lifecycle = "prewarm_failed"
		return _fail("prewarm_capsule_missing_player", {
			"signature": signature
		})

	prewarmed_game_state = capsule

	var capsule_contract: Dictionary = _safe_dictionary(report.get("contract", {}))
	if capsule_contract.is_empty():
		capsule_contract = {
			"schema": "eralife.god_mode.prewarmed_capsule_contract",
			"version": 1,
			"signature": signature,
			"actor_id": int(capsule.player.id),
			"created_at_ms": int(Time.get_ticks_msec())
		}

	if typeof(prewarmed_game_state.scenario_state) != TYPE_DICTIONARY:
		prewarmed_game_state.scenario_state = {}

	prewarmed_game_state.scenario_state ["god_mode_contract_engine_prewarm_ready"] = true
	prewarmed_game_state.scenario_state ["god_mode_contract_engine_prewarm_signature"] = signature
	prewarmed_game_state.scenario_state ["god_mode_contract_engine_capsule_contract"] = capsule_contract.duplicate(true)
	prewarmed_game_state.scenario_state ["god_mode_contract_engine_ui_thread_blocking_forbidden"] = true

	var first_frame_snapshot: Dictionary = _build_playable_surface_snapshot(prewarmed_game_state)
	prewarmed_game_state.scenario_state ["prebuilt_first_frame_ui_snapshot"] = first_frame_snapshot.duplicate(true)
	prewarmed_game_state.scenario_state ["zero_frame_consciousness_switch_surface"] = first_frame_snapshot.duplicate(true)
	prewarmed_game_state.scenario_state ["birth_is_first_consciousness_switch"] = true
	prewarmed_game_state.scenario_state ["previous_actor_id"] = -1
	prewarmed_game_state.scenario_state ["previous_actor_name"] = "Nobody"
	prewarmed_game_state.scenario_state ["blank_shell_forbidden"] = true
	prewarmed_game_state.scenario_state ["loading_on_ready_forbidden"] = true

	tracker_engine.mark_prewarm_ready(tracked_settings.duplicate(true), signature, capsule_contract.duplicate(true), {
		"source": str(context.get("source", "god_mode_contract_engine.accept_prewarm_report")),
		"panel_role_after_ready": "handoff_only",
		"blank_shell_forbidden": true,
	})

	lifecycle = "prewarm_ready"

	prewarm_contract ["handoff_stage"] = "prewarm_ready"
	prewarm_contract ["prewarm_ready"] = true
	prewarm_contract ["prewarm_pending"] = false
	prewarm_contract ["capsule_contract"] = capsule_contract.duplicate(true)
	prewarm_contract ["updated_at_ms"] = int(Time.get_ticks_msec())

	_publish_contract_to_scenario("prewarm_ready")

	return _succeed("god_mode_prewarm_ready", {
		"signature": signature,
		"settings": tracked_settings.duplicate(true),
		"capsule_contract": capsule_contract.duplicate(true)
	})


func emit_handoff_contract(panel_state: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	_ensure_state()
	_ensure_wrapped_engines()

	var settings: Dictionary = tracked_settings.duplicate(true)
	if typeof(panel_state) == TYPE_DICTIONARY and not panel_state.is_empty():
		settings = _normalize_settings(panel_state)

	if settings.is_empty():
		return _fail("missing_ready_settings", context)

	var signature: String = signature_for_settings(settings)
	if signature != tracked_signature:
		return _fail("settings_changed_after_prewarm", {
			"expected": tracked_signature,
			"received": signature
		})

	if prewarmed_game_state == null or prewarmed_game_state.player == null:
		return _fail("prewarm_not_ready", {
			"signature": signature,
			"lifecycle": lifecycle
		})

	var panel_report: Dictionary = panel_engine.emit_handoff_contract(settings.duplicate(true), signature, {
		"source": str(context.get("source", "god_mode_contract_engine.emit_handoff_contract")),
		"panel_role": "handoff_emit_done",
	})

	if not bool(panel_report.get("success", false)):
		last_report = panel_report.duplicate(true)
		_commit_state()
		return last_report.duplicate(true)

	var tracker_report: Dictionary = tracker_engine.claim_handoff(settings.duplicate(true), signature, {
		"source": "god_mode_contract_engine.emit_handoff_contract",
		"panel_role": "handoff_only",
		"consume_mode": "hot_prewarmed_capsule",
		"blank_shell_forbidden": true,
	})

	firewall_engine.sever("god_mode_contract_engine_handoff_emitted", {
		"signature": signature,
	})

	sequence += 1
	var now_ms: int = int(Time.get_ticks_msec())
	var contract_id: String = "god_mode_contract_engine_handoff_%d_%d" % [sequence, now_ms]

	claimed_game_state = prewarmed_game_state

	handoff_contract = {
		"schema": HANDOFF_INTENT_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": contract_id,
		"contract_id": contract_id,
		"mode": "god_mode_handoff_emitted",
		"handoff_stage": "handoff_emitted",
		"signature": signature,
		"settings": settings.duplicate(true),
		"panel_contract": panel_report.duplicate(true),
		"tracker_contract": tracker_report.duplicate(true),
		"ready_button_is_door": true,
		"ready_opens_room": true,
		"loading_on_ready_forbidden": true,
		"blank_shell_forbidden": true,
		"created_at_ms": now_ms,
		"updated_at_ms": now_ms,
		"context": context.duplicate(true)
	}

	lifecycle = "handoff_emitted"

	claim_playable_surface(_build_playable_surface_snapshot(claimed_game_state), {
		"source": "god_mode_contract_engine.emit_handoff_contract",
		"signature": signature,
	})

	var defer_handoff_route: bool = bool(context.get("defer_reality_orchestrator_handoff_route_until_after_visible_surface", false))

	if defer_handoff_route:
		call_deferred("_route_handoff_intent_to_reality_orchestrator", handoff_contract.duplicate(true))
	else:
		_route_handoff_intent_to_reality_orchestrator(handoff_contract)

	_publish_contract_to_scenario("handoff_emitted")

	return _succeed("god_mode_handoff_contract_emitted", {
		"signature": signature,
		"settings": settings.duplicate(true),
		"handoff_contract": handoff_contract.duplicate(true),
		"playable_surface_contract": playable_surface_contract.duplicate(true)
	})


func claim_playable_surface(snapshot: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	_ensure_state()
	_ensure_wrapped_engines()

	if claimed_game_state == null:
		claimed_game_state = prewarmed_game_state

	if claimed_game_state == null or claimed_game_state.player == null:
		return _fail("missing_claimed_game_state", context)

	var clean_snapshot: Dictionary = snapshot.duplicate(true)
	if clean_snapshot.is_empty():
		clean_snapshot = _build_playable_surface_snapshot(claimed_game_state)

	var tracker_report: Dictionary = tracker_engine.claim_playable_surface(clean_snapshot.duplicate(true), {
		"source": str(context.get("source", "god_mode_contract_engine.claim_playable_surface")),
		"renderer_only": true
	})

	sequence += 1
	var now_ms: int = int(Time.get_ticks_msec())
	var contract_id: String = "god_mode_playable_surface_%d_%d" % [sequence, now_ms]

	playable_surface_contract = {
		"schema": PLAYABLE_SURFACE_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": contract_id,
		"contract_id": contract_id,
		"mode": "playable_surface_claimed",
		"handoff_stage": "surface_claimed",
		"signature": tracked_signature,
		"settings": tracked_settings.duplicate(true),
		"playable_surface_claimed": true,
		"playable_surface_claimed_at_ms": now_ms,
		"playable_surface_snapshot": clean_snapshot.duplicate(true),
		"tracker_report": tracker_report.duplicate(true),
		"render_policy": {
			"main_scene_is_renderer_only": true,
			"render_immediately": true,
			"blank_shell_forbidden": true,
			"loading_on_ready_forbidden": true,
		},
		"created_at_ms": now_ms,
		"updated_at_ms": now_ms,
		"context": context.duplicate(true)
	}

	lifecycle = "surface_claimed"
	_publish_contract_to_scenario("surface_claimed")

	return _succeed("god_mode_playable_surface_claimed", {
		"signature": tracked_signature,
		"playable_surface_contract": playable_surface_contract.duplicate(true)
	})


func mark_surface_rendered_by_renderer(
		context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	if playable_surface_contract.is_empty():
		return _fail(
			"no_playable_surface_contract_to_mark_rendered",
			context
		)

	var precomposed_surface_acknowledgment: bool = bool(
		context.get(
			"precomposed_surface_acknowledgment",
			false
		)
	)
	var now_ms: int = int(
		Time.get_ticks_msec()
	)
	var surface_id: String = str(
		playable_surface_contract.get(
			"contract_id",
			playable_surface_contract.get(
				"id",
				""
			)
		)
	).strip_edges()

	lifecycle = "entry_complete"
	playable_surface_contract [
		"handoff_stage"
	] = "entry_complete"
	playable_surface_contract [
		"entry_complete"
	] = true
	playable_surface_contract [
		"entry_complete_at_ms"
	] = now_ms








	if precomposed_surface_acknowledgment:
		var renderer_ack: Dictionary = {
			"source": str(
				context.get(
					"source",
					"god_mode_contract_engine.precomposed_surface_ack"
				)
			),
			"surface_id": surface_id,
			"renderer_only": true,
			"precomposed_surface_acknowledgment": true,
			"acknowledged_at_ms": now_ms
		}

		playable_surface_contract [
			"renderer_ack"
		] = renderer_ack
		playable_surface_contract [
			"renderer_ack_is_o1"
		] = true
		playable_surface_contract [
			"renderer_ack_recursive_copy_performed"
		] = false
		playable_surface_contract [
			"renderer_ack_tracker_work_deferred"
		] = true
		playable_surface_contract [
			"renderer_ack_full_scenario_publish_performed"
		] = false

		last_report = {
			"schema": ENGINE_STATE_SCHEMA,
			"version": CONTRACT_VERSION,
			"success": true,
			"mode": "god_mode_precomposed_surface_acknowledged_o1",
			"surface_id": surface_id,
			"signature": tracked_signature,
			"lifecycle": lifecycle,
			"precomposed_surface_acknowledgment": true,
			"acknowledged_at_ms": now_ms
		}

		if (
			gs != null
			and typeof(
				gs.scenario_state
			) == TYPE_DICTIONARY
		):
			gs.scenario_state [
				"god_mode_contract_engine_lifecycle"
			] = lifecycle
			gs.scenario_state [
				"god_mode_lifecycle"
			] = lifecycle
			gs.scenario_state [
				"god_mode_playable_surface_claimed"
			] = true
			gs.scenario_state [
				"god_mode_playable_surface_entry_complete"
			] = true
			gs.scenario_state [
				"god_mode_playable_surface_entry_complete_at_ms"
			] = now_ms
			gs.scenario_state [
				"god_mode_precomposed_surface_acknowledged_o1"
			] = true
			gs.scenario_state [
				"god_mode_precomposed_surface_ack_surface_id"
			] = surface_id
			gs.scenario_state [
				"god_mode_precomposed_surface_ack_tracker_work_performed"
			] = false
			gs.scenario_state [
				"god_mode_precomposed_surface_ack_full_publish_performed"
			] = false
			gs.scenario_state [
				"god_mode_precomposed_surface_ack_recursive_copy_performed"
			] = false

		return last_report.duplicate(false)





	_ensure_wrapped_engines()

	playable_surface_contract [
		"renderer_ack"
	] = context.duplicate(true)

	tracker_engine.mark_entry_complete({
		"source": str(
			context.get(
				"source",
				"god_mode_contract_engine.mark_surface_rendered_by_renderer"
			)
		),
		"renderer_only": true,
		"blank_shell_seen": false
	})

	_publish_contract_to_scenario(
		"entry_complete"
	)

	return _succeed(
		"god_mode_entry_complete",
		{
			"playable_surface_contract": (
				playable_surface_contract.duplicate(true)
			)
		}
	)
func is_ready_for_settings(panel_state: Dictionary = {}) -> bool:
	var settings: Dictionary = tracked_settings.duplicate(true)
	if typeof(panel_state) == TYPE_DICTIONARY and not panel_state.is_empty():
		settings = _normalize_settings(panel_state)

	if settings.is_empty():
		return false

	var signature: String = signature_for_settings(settings)
	if signature == "" or signature != tracked_signature:
		return false

	return prewarmed_game_state != null and lifecycle in ["prewarm_ready", "handoff_emitted", "surface_claimed", "entry_complete"]


func ready_settings() -> Dictionary:
	if lifecycle in ["prewarm_ready", "handoff_emitted", "surface_claimed", "entry_complete"]:
		return tracked_settings.duplicate(true)
	return {}


func ready_signature() -> String:
	if lifecycle in ["prewarm_ready", "handoff_emitted", "surface_claimed", "entry_complete"]:
		return tracked_signature
	return ""


func claimed_playable_game_state() -> GameState:
	return claimed_game_state

func reset_for_main_menu_seed_exit(reason: String = "main_menu_return", preserved_first: bool = false) -> Dictionary:
	_ensure_state()
	_ensure_wrapped_engines()

	sequence += 1
	lifecycle = "idle"
	tracked_settings = {}
	tracked_signature = ""
	prewarm_contract = {}
	handoff_contract = {}
	playable_surface_contract = {}
	prewarmed_game_state = null
	claimed_game_state = null

	last_report = {
		"schema": ENGINE_STATE_SCHEMA,
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": "god_mode_contract_engine_reset_for_main_menu_seed_exit",
		"reason": reason,
		"preserved_first": preserved_first,
		"live_seed_copy_only_if_preserved": preserved_first,
		"ready_button_is_door": true,
		"reset_at_ms": int(Time.get_ticks_msec())
	}

	ledger.append(last_report.duplicate(true))
	if ledger.size() > MAX_LEDGER:
		ledger = ledger.slice(ledger.size() - MAX_LEDGER, ledger.size())

	_commit_state()

	return last_report.duplicate(true)
func _post_visible_current_state_header() -> Dictionary:
	if (
		gs == null
		or typeof(
			gs.scenario_state
		) != TYPE_DICTIONARY
	):
		return {}

	var first_paint_complete: bool = bool(
		gs.scenario_state.get(
			"ready_door_first_paint_complete",
			false
		)
	)
	var life_lens_owns_screen: bool = (
		bool(
			gs.scenario_state.get(
				"playable_life_shell_has_visible_sovereignty",
				false
			)
		)
		or bool(
			gs.scenario_state.get(
				"playable_life_surface_has_visual_authority",
				false
			)
		)
		or bool(
			gs.scenario_state.get(
				"birth_shell_player_control_released",
				false
			)
		)
		or bool(
			gs.scenario_state.get(
				"playable_life_surface_player_control_released",
				false
			)
		)
		or bool(
			gs.scenario_state.get(
				"spawn_ready_live_ui_shell_released",
				false
			)
		)
	)

	if (
		not first_paint_complete
		or not life_lens_owns_screen
	):
		return {}

	var prewarm_is_ready: bool = (
		not tracked_settings.is_empty()
		and tracked_signature != ""
		and prewarmed_game_state != null
		and lifecycle in [
			"prewarm_ready",
			"handoff_emitted",
			"surface_claimed",
			"entry_complete"
		]
	)
	var first_visible_shell_hot: bool = (
		bool(
			gs.scenario_state.get(
				"god_mode_ready_aaa_life_shell_hot",
				false
			)
		)
		or bool(
			gs.scenario_state.get(
				"god_mode_zero_frame_entry_surface_staged",
				false
			)
		)
		or bool(
			gs.scenario_state.get(
				"first_visible_life_shell_final_composition_complete",
				false
			)
		)
	)
	var main_tab_input_hot: bool = bool(
		gs.scenario_state.get(
			"main_tab_input_contract_hot",
			false
		)
	)
	var global_gate_required: bool = bool(
		gs.scenario_state.get(
			"global_prewarm_contract_gate_required_before_ready",
			false
		)
	)
	var global_gate_hot: bool = bool(
		gs.scenario_state.get(
			"global_prewarm_contract_gate_hot",
			not global_gate_required
		)
	)
	var global_gate_satisfied: bool = (
		not global_gate_required
		or global_gate_hot
	)
	var door_latch_hot: bool = (
		prewarm_is_ready
		and prewarmed_game_state != null
		and prewarmed_game_state.player != null
		and first_visible_shell_hot
		and main_tab_input_hot
		and global_gate_satisfied
	)
	var playable_surface_header: Dictionary = {}

	if not playable_surface_contract.is_empty():
		playable_surface_header = {
			"schema": str(
				playable_surface_contract.get(
					"schema",
					PLAYABLE_SURFACE_SCHEMA
				)
			),
			"version": int(
				playable_surface_contract.get(
					"version",
					CONTRACT_VERSION
				)
			),
			"id": str(
				playable_surface_contract.get(
					"id",
					""
				)
			),
			"contract_id": str(
				playable_surface_contract.get(
					"contract_id",
					playable_surface_contract.get(
						"id",
						""
					)
				)
			),
			"mode": str(
				playable_surface_contract.get(
					"mode",
					""
				)
			),
			"handoff_stage": str(
				playable_surface_contract.get(
					"handoff_stage",
					lifecycle
				)
			),
			"signature": str(
				playable_surface_contract.get(
					"signature",
					tracked_signature
				)
			),
			"playable_surface_claimed": bool(
				playable_surface_contract.get(
					"playable_surface_claimed",
					false
				)
			),
			"entry_complete": bool(
				playable_surface_contract.get(
					"entry_complete",
					false
				)
			),
			"ui_is_renderer_only": true
		}

	return {
		"schema": ENGINE_STATE_SCHEMA,
		"version": CONTRACT_VERSION,
		"sequence": sequence,
		"lifecycle": lifecycle,
		"tracked_settings": {},
		"tracked_signature": tracked_signature,
		"prewarm_ready": prewarm_is_ready,
		"ready_door_latch_hot": door_latch_hot,
		"viewer_ready_button_enabled": door_latch_hot,
		"prewarm_ready_but_door_latch_pending": false,
		"ready_door_first_false_gate": "",
		"ready_door_latch_declared_hot": bool(
			gs.scenario_state.get(
				"ready_door_latch_hot",
				door_latch_hot
			)
		),
		"first_visible_life_shell_hot": first_visible_shell_hot,
		"main_tab_input_contract_hot": main_tab_input_hot,
		"ready_door_latch_finalized_after_input_contract": bool(
			gs.scenario_state.get(
				"ready_door_latch_finalized_after_input_contract",
				main_tab_input_hot
			)
		),
		"global_prewarm_contract_gate_required": global_gate_required,
		"global_prewarm_contract_gate_hot": global_gate_hot,
		"global_prewarm_contract_gate_satisfied": global_gate_satisfied,
		"pending_situations_button_painted": bool(
			gs.scenario_state.get(
				"pending_situations_button_painted_from_zero_frame_truth",
				false
			)
		),
		"native_tab_surface_tail_complete": bool(
			gs.scenario_state.get(
				"ready_room_native_tab_surface_prewarm_complete",
				false
			)
		),
		"has_prewarmed_game_state": (
			prewarmed_game_state != null
			and prewarmed_game_state.player != null
		),
		"has_claimed_game_state": claimed_game_state != null,
		"prewarm_contract": {
			"signature": tracked_signature,
			"ready": prewarm_is_ready,
		},
		"handoff_contract": {
			"signature": tracked_signature,
			"lifecycle": lifecycle,
		},
		"playable_surface_contract": playable_surface_header,
		"last_report": {
			"success": bool(
				last_report.get(
					"success",
					false
				)
			),
			"mode": str(
				last_report.get(
					"mode",
					""
				)
			),
			"reason": str(
				last_report.get(
					"reason",
					""
				)
			),
		},
	}

func current_state() -> Dictionary:
	_ensure_state()

	var post_visible_header: Dictionary = (
		_post_visible_current_state_header()
	)

	if not post_visible_header.is_empty():
		return post_visible_header

	var prewarm_is_ready: bool = is_ready_for_settings(
		tracked_settings
	)
	var door_latch_hot: bool = false
	var door_latch_pending: bool = false
	var latch_declared_hot: bool = false
	var first_visible_shell_hot: bool = false
	var main_tab_input_hot: bool = false
	var latch_finalized: bool = false
	var global_gate_required: bool = false
	var global_gate_hot: bool = false
	var global_gate_satisfied: bool = true
	var pending_button_painted: bool = false
	var native_tab_tail_complete: bool = false
	var has_prewarmed_game_state: bool = (
		prewarmed_game_state != null
		and prewarmed_game_state.player != null
	)
	var first_false_gate: String = ""
	var latch_reconciled: bool = false

	if (
		gs != null
		and typeof(
			gs.scenario_state
		) == TYPE_DICTIONARY
	):
		latch_declared_hot = bool(
			gs.scenario_state.get(
				"ready_door_latch_hot",
				false
			)
		)
		first_visible_shell_hot = (
			bool(
				gs.scenario_state.get(
					"god_mode_ready_aaa_life_shell_hot",
					false
				)
			)
			or bool(
				gs.scenario_state.get(
					"god_mode_zero_frame_entry_surface_staged",
					false
				)
			)
			or bool(
				gs.scenario_state.get(
					"first_visible_life_shell_final_composition_complete",
					false
				)
			)
		)
		main_tab_input_hot = bool(
			gs.scenario_state.get(
				"main_tab_input_contract_hot",
				false
			)
		)
		latch_finalized = bool(
			gs.scenario_state.get(
				"ready_door_latch_finalized_after_input_contract",
				main_tab_input_hot
			)
		)
		global_gate_required = bool(
			gs.scenario_state.get(
				"global_prewarm_contract_gate_required_before_ready",
				false
			)
		)
		global_gate_hot = bool(
			gs.scenario_state.get(
				"global_prewarm_contract_gate_hot",
				not global_gate_required
			)
		)
		global_gate_satisfied = (
			not global_gate_required
			or global_gate_hot
		)
		pending_button_painted = bool(
			gs.scenario_state.get(
				"pending_situations_button_painted_from_zero_frame_truth",
				false
			)
		)
		native_tab_tail_complete = bool(
			gs.scenario_state.get(
				"ready_room_native_tab_surface_prewarm_complete",
				false
			)
		)



	door_latch_hot = (
		prewarm_is_ready
		and has_prewarmed_game_state
		and first_visible_shell_hot
		and main_tab_input_hot
		and global_gate_satisfied
	)

	if door_latch_hot:
		latch_reconciled = (
			not latch_declared_hot
			or not latch_finalized
		)

		if (
			gs != null
			and typeof(
				gs.scenario_state
			) == TYPE_DICTIONARY
		):
			gs.scenario_state [
				"ready_door_latch_hot"
			] = true
			gs.scenario_state [
				"ready_door_latch_finalized_after_input_contract"
			] = true
			gs.scenario_state [
				"ready_door_latch_reconciled_by_contract_engine"
			] = latch_reconciled
			gs.scenario_state [
				"ready_door_latch_reconciled_by_contract_engine_at_ms"
			] = int(
				Time.get_ticks_msec()
			)

	if not prewarm_is_ready:
		first_false_gate = "prewarm_ready"
	elif not has_prewarmed_game_state:
		first_false_gate = "prewarmed_game_state_exists"
	elif not first_visible_shell_hot:
		first_false_gate = "first_visible_life_shell_hot"
	elif not main_tab_input_hot:
		first_false_gate = "main_tab_input_contract_hot"
	elif not global_gate_satisfied:
		first_false_gate = "global_prewarm_contract_gate_hot"

	door_latch_pending = (
		prewarm_is_ready
		and not door_latch_hot
	)

	if (
		gs != null
		and typeof(
			gs.scenario_state
		) == TYPE_DICTIONARY
	):
		var truth_signature: String = (
			"%s|%s|%s|%s|%s|%s|%s"
			% [
				str(prewarm_is_ready),
				str(has_prewarmed_game_state),
				str(first_visible_shell_hot),
				str(main_tab_input_hot),
				str(global_gate_satisfied),
				str(door_latch_hot),
				first_false_gate
			]
		)
		var previous_truth_signature: String = str(
			gs.scenario_state.get(
				"god_mode_contract_ready_truth_print_signature",
				""
			)
		)

		if truth_signature != previous_truth_signature:
			EraLog.truth(
				(
					"ERALIFE_GOD_MODE_CONTRACT_READY_TRUTH"
					+ "|lifecycle=%s"
					+ "|tracked_signature=%s"
					+ "|prewarm_ready=%s"
					+ "|has_prewarmed_game_state=%s"
					+ "|first_visible_shell_hot=%s"
					+ "|main_tab_input_hot=%s"
					+ "|global_gate_required=%s"
					+ "|global_gate_hot=%s"
					+ "|derived_door_hot=%s"
					+ "|cached_latch_declared_hot=%s"
					+ "|cached_latch_finalized=%s"
					+ "|first_false_gate=%s"
					+ "|latch_reconciled=%s"
				)
				% [
					lifecycle,
					tracked_signature,
					str(prewarm_is_ready),
					str(has_prewarmed_game_state),
					str(first_visible_shell_hot),
					str(main_tab_input_hot),
					str(global_gate_required),
					str(global_gate_hot),
					str(door_latch_hot),
					str(latch_declared_hot),
					str(latch_finalized),
					first_false_gate,
					str(latch_reconciled)
				]
			)

			gs.scenario_state [
				"god_mode_contract_ready_truth_print_signature"
			] = truth_signature
			gs.scenario_state [
				"god_mode_contract_ready_first_false_gate"
			] = first_false_gate
			gs.scenario_state [
				"god_mode_contract_ready_truth_checked_at_ms"
			] = int(
				Time.get_ticks_msec()
			)

	return {
		"schema": ENGINE_STATE_SCHEMA,
		"version": CONTRACT_VERSION,
		"sequence": sequence,
		"lifecycle": lifecycle,
		"tracked_settings": tracked_settings.duplicate(true),
		"tracked_signature": tracked_signature,
		"prewarm_ready": prewarm_is_ready,
		"ready_door_latch_hot": door_latch_hot,
		"viewer_ready_button_enabled": door_latch_hot,
		"prewarm_ready_but_door_latch_pending": door_latch_pending,
		"ready_door_first_false_gate": first_false_gate,
		"ready_door_latch_reconciled": latch_reconciled,
		"ready_door_latch_declared_hot": latch_declared_hot,
		"first_visible_life_shell_hot": first_visible_shell_hot,
		"main_tab_input_contract_hot": main_tab_input_hot,
		"ready_door_latch_finalized_after_input_contract": latch_finalized,
		"global_prewarm_contract_gate_required": global_gate_required,
		"global_prewarm_contract_gate_hot": global_gate_hot,
		"global_prewarm_contract_gate_satisfied": global_gate_satisfied,
		"pending_situations_button_painted": pending_button_painted,
		"native_tab_surface_tail_complete": native_tab_tail_complete,
		"has_prewarmed_game_state": has_prewarmed_game_state,
		"has_claimed_game_state": claimed_game_state != null,
		"prewarm_contract": prewarm_contract.duplicate(true),
		"handoff_contract": handoff_contract.duplicate(true),
		"playable_surface_contract": playable_surface_contract.duplicate(true),
		"last_report": last_report.duplicate(true)
	}
func export_state() -> Dictionary:
	return {
		"schema": ENGINE_STATE_SCHEMA,
		"version": CONTRACT_VERSION,
		"sequence": sequence,
		"lifecycle": lifecycle,
		"tracked_settings": tracked_settings.duplicate(true),
		"tracked_signature": tracked_signature,
		"prewarm_contract": prewarm_contract.duplicate(true),
		"handoff_contract": handoff_contract.duplicate(true),
		"playable_surface_contract": playable_surface_contract.duplicate(true),
		"last_report": last_report.duplicate(true),
		"ledger": ledger.duplicate(true),
		"exported_at_ms": int(Time.get_ticks_msec())
	}


func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return _fail("invalid_import_data", {})

	sequence = int(data.get("sequence", data.get("god_mode_contract_engine_sequence", sequence)))
	lifecycle = str(data.get("lifecycle", data.get("god_mode_contract_engine_lifecycle", lifecycle))).strip_edges()

	tracked_settings = _safe_dictionary(data.get("tracked_settings", data.get("god_mode_contract_engine_tracked_settings", {})))
	tracked_signature = str(data.get("tracked_signature", data.get("god_mode_contract_engine_tracked_signature", ""))).strip_edges()

	prewarm_contract = _safe_dictionary(data.get("prewarm_contract", data.get("god_mode_contract_engine_prewarm_contract", {})))
	handoff_contract = _safe_dictionary(data.get("handoff_contract", data.get("god_mode_contract_engine_handoff_contract", {})))
	playable_surface_contract = _safe_dictionary(data.get("playable_surface_contract", data.get("god_mode_contract_engine_playable_surface_contract", {})))
	last_report = _safe_dictionary(data.get("last_report", {}))
	ledger = _safe_array(data.get("ledger", []))

	_commit_state()

	return _succeed("god_mode_contract_engine_imported", {
		"lifecycle": lifecycle,
		"tracked_signature": tracked_signature
	})


func signature_for_settings(settings: Dictionary) -> String:
	var normalized: Dictionary = _normalize_settings(settings)
	if normalized.is_empty():
		return ""

	var stable: String = _stable_signature_value(normalized)
	return "godmode_%d_%d" % [abs(stable.hash()), stable.length()]


func _normalize_settings(
	settings: Dictionary
) -> Dictionary:
	if typeof(
		settings
	) != TYPE_DICTIONARY:
		return {}

	var out: Dictionary = settings.duplicate(true)



	var volatile_setting_keys: Array = [
		"panel_capture_ms",
		"preview_text",
		"progress_text",
		"prewarm_progress",
		"ui_hovered",
		"ui_focused",
		"button_disabled",
		"last_report",
		"debug",
		"reality_mode_canonicalized_reason",
		"reality_mode_canonicalized_at_ms"
	]

	for raw_key in volatile_setting_keys:
		out.erase(
			str(
				raw_key
			)
		)

	if not out.has(
		"_god_mode_entry_kind"
	):
		out ["_god_mode_entry_kind"] = "custom"

	out ["_god_mode_entry_kind"] = str(
		out.get(
			"_god_mode_entry_kind",
			"custom"
		)
	).strip_edges()

	if out ["_god_mode_entry_kind"] == "":
		out ["_god_mode_entry_kind"] = "custom"

	var normalized_year: int = (
		_god_mode_contract_year_from_settings(
			out
		)
	)
	var era_key: String = (
		_god_mode_contract_era_key_for_year(
			normalized_year
		)
	)

	out ["birth_year"] = normalized_year
	out ["year"] = normalized_year
	out ["era"] = era_key
	out ["era_name"] = (
		_god_mode_contract_era_name_for_key(
			era_key
		)
	)
	out ["year_era_authority"] = (
		"god_mode_contract_engine.birth_year_threshold"
	)

	var presidential_enabled: bool = bool(
		out.get(
			"presidential_parents",
			false
		)
	)
	var country_key: String = str(
		out.get(
			"country",
			""
		)
	).strip_edges().to_lower()
	var social_key: String = str(
		out.get(
			"social_class",
			""
		)
	).strip_edges().to_lower()
	var usa_selected: bool = country_key in [
		"usa",
		"u.s.a.",
		"united states",
		"united states of america"
	]
	var presidential_era_valid: bool = era_key in [
		"Industrial",
		"Modern",
		"Future"
	]

	if (
		presidential_enabled
		and usa_selected
		and social_key == "elite"
		and presidential_era_valid
	):
		out ["country"] = "United States"
		out ["birth_country"] = "United States"
		out ["home_country"] = "United States"
		out ["territory"] = "District of Columbia"
		out ["birth_territory"] = "District of Columbia"
		out ["home_territory"] = "District of Columbia"
		out ["selected_place_kind"] = "territory"
		out ["selected_place"] = "District of Columbia"
		out ["state"] = ""
		out ["birth_state"] = ""
		out ["home_state"] = ""
		out ["city"] = "Washington, DC"
		out ["birth_city"] = "Washington, DC"
		out ["home_city"] = "Washington, DC"
		out ["presidential_parent_location_contract"] = {
			"schema": (
				"eralife.presidential_parent_location_contract"
			),
			"version": 1,
			"country": "United States",
			"continent": "North America",
			"place_kind": "territory",
			"territory": "District of Columbia",
			"selected_place": "District of Columbia",
			"city": "Washington, DC",
			"ui_is_renderer_only": true
		}

		var presidential_contract: Dictionary = {}

		if typeof(
			out.get(
				"presidential_parent_contract",
				{}
			)
		) == TYPE_DICTIONARY:
			presidential_contract = (
				out.get(
					"presidential_parent_contract",
					{}
				) as Dictionary
			).duplicate(true)

		presidential_contract ["enabled"] = true
		presidential_contract ["country"] = "United States"
		presidential_contract ["continent"] = "North America"
		presidential_contract ["territory"] = "District of Columbia"
		presidential_contract ["selected_place_kind"] = "territory"
		presidential_contract ["selected_place"] = "District of Columbia"
		presidential_contract ["birth_city"] = "Washington, DC"
		presidential_contract [
			"president_gets_crown_hub_access"
		] = true
		presidential_contract [
			"family_gets_elite_jobs"
		] = true
		presidential_contract [
			"family_gets_ruling_power_by_proximity"
		] = false
		presidential_contract [
			"white_house_official_residence"
		] = true
		presidential_contract [
			"white_house_inheritable"
		] = false
		presidential_contract [
			"crown_hub_layout_variant"
		] = "federal_republic"
		presidential_contract [
			"approval_label"
		] = "Presidential Approval"
		presidential_contract [
			"ui_is_renderer_only"
		] = true
		out ["presidential_parent_contract"] = (
			presidential_contract
		)



	var candidate: Dictionary = _safe_dictionary(
		out.get(
			"_prebirth_reality_candidate",
			{}
		)
	)

	if not candidate.is_empty():
		for raw_candidate_key in [
			"revision",
			"created_reason",
			"last_reason",
			"created_at_ms",
			"last_updated_at_ms",
			"live_reshaping"
		]:
			candidate.erase(
				str(
					raw_candidate_key
				)
			)

		var candidate_seed: int = int(
			candidate.get(
				"world_seed",
				candidate.get(
					"seed",
					-1
				)
			)
		)

		if candidate_seed > 0:
			candidate ["world_seed"] = candidate_seed
			candidate.erase(
				"seed"
			)

			var candidate_id: String = str(
				candidate.get(
					"candidate_id",
					""
				)
			).strip_edges()

			if candidate_id == "":
				candidate_id = "prebirth_%s_%d" % [
					str(
						out.get(
							"_god_mode_entry_kind",
							"custom"
						)
					),
					candidate_seed
				]

			candidate ["candidate_id"] = candidate_id
			out ["_prebirth_reality_candidate"] = (
				candidate.duplicate(true)
			)
			out ["_prebirth_reality_candidate_id"] = (
				candidate_id
			)
			out ["world_seed"] = candidate_seed
		else:
			out.erase(
				"_prebirth_reality_candidate"
			)
			out.erase(
				"_prebirth_reality_candidate_id"
			)

	var seed_contract: Dictionary = _safe_dictionary(
		out.get(
			"seed_contract",
			{}
		)
	)

	for raw_seed_key in [
		"source",
		"created_at_ms",
		"updated_at_ms",
		"last_reason"
	]:
		seed_contract.erase(
			str(
				raw_seed_key
			)
		)

	var world_seed: int = int(
		out.get(
			"world_seed",
			seed_contract.get(
				"seed",
				-1
			)
		)
	)

	if world_seed > 0:
		out ["world_seed"] = world_seed
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
		seed_contract ["seed"] = world_seed
		seed_contract ["single_target_reality"] = true
		out ["seed_contract"] = seed_contract.duplicate(true)
	else:
		out.erase(
			"world_seed"
		)
		out.erase(
			"seed_contract"
		)

	return out
func _god_mode_contract_year_from_settings(settings: Dictionary) -> int:
	if settings.has("custom_year_text"):
		return _god_mode_contract_parse_year(str(settings.get("custom_year_text", "")), int(settings.get("birth_year", settings.get("year", 79))))
	if settings.has("birth_year"):
		return _god_mode_contract_parse_year(str(settings.get("birth_year", "")), 79)
	if settings.has("year"):
		return _god_mode_contract_parse_year(str(settings.get("year", "")), 79)
	return 79


func _god_mode_contract_parse_year(raw_text: String, fallback: int = 79) -> int:
	var clean: String = str(raw_text).strip_edges().replace(",", "").replace("_", "").replace(" ", "").to_lower()
	if clean == "":
		return fallback

	var year_direction: int = 1

	if clean.ends_with("bce"):
		year_direction = -1
		clean = clean.substr(0, clean.length() - 3)
	elif clean.ends_with("bc"):
		year_direction = -1
		clean = clean.substr(0, clean.length() - 2)
	elif clean.ends_with("ce"):
		clean = clean.substr(0, clean.length() - 2)
	elif clean.begins_with("ad"):
		clean = clean.substr(2)

	if clean.begins_with("-"):
		year_direction = -1
		clean = clean.substr(1)
	elif clean.begins_with("+"):
		clean = clean.substr(1)

	if clean == "":
		return fallback

	for i in range(clean.length()):
		var character: String = clean.substr(i, 1)
		if character not in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]:
			return fallback

	if clean.length() > 18:
		return year_direction * 1000000000

	return year_direction * int(clean)


func _god_mode_contract_era_key_for_year(year_value: int) -> String:
	if year_value <= 499:
		return "Ancient"
	if year_value <= 1799:
		return "Medieval"
	if year_value <= 1949:
		return "Industrial"
	if year_value <= 2049:
		return "Modern"
	return "Future"


func _god_mode_contract_era_name_for_key(era_key: String) -> String:
	match str(era_key).strip_edges():
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
			return str(era_key).strip_edges()

func _build_playable_surface_snapshot(
		state: GameState
) -> Dictionary:
	if (
		state == null
		or state.player == null
	):
		return {}

	var actor: Person = state.player
	var settings: Dictionary = (
		tracked_settings.duplicate(false)
	)
	var scenario: Dictionary = (
		state.scenario_state
		if typeof(
			state.scenario_state
		) == TYPE_DICTIONARY
		else {}
	)
	var diary_raw: Variant = scenario.get(
		"resident_first_frame_birth_intro_lines",
		[]
	)
	var canonical_diary_lines: Array = (
		(
			diary_raw as Array
		).duplicate(false)
		if typeof(
			diary_raw
		) == TYPE_ARRAY
		else []
	)

	_apply_tracked_birth_settings_to_actor(
		actor,
		settings
	)

	var actor_name: String = (
		_actor_display_name(
			actor
		)
	)
	var bank_balance: int = (
		_god_mode_contract_bank_balance(
			actor,
			settings
		)
	)

	if canonical_diary_lines.is_empty():
		canonical_diary_lines = [
			"Year: %s" % str(
				state.year
			),
			"Age: %d" % int(
				actor.age
			),
			"I was born in %s." % str(
				state.year
			),
			"My name is %s." % actor_name
		]

	var snapshot: Dictionary = {
		"schema": (
			"eralife.god_mode.playable_first_frame_snapshot"
		),
		"version": 2,
		"actor_id": int(actor.id),
		"actor_name": actor_name,
		"first_name": str(actor.first_name),
		"last_name": str(actor.last_name),
		"age": int(actor.age),
		"alive": true,
		"year": int(state.year),
		"current_panel": "life",
		"title": actor_name,
		"player_id": int(actor.id),
		"bank_balance": bank_balance,
		"money": bank_balance,
		"health": clampi(
			int(
				round(
					float(actor.health)
				)
			),
			1,
			200
		),
		"hunger": clampi(
			int(
				round(
					float(actor.hunger)
				)
			),
			0,
			100
		),
		"mental_health": clampi(
			int(
				round(
					float(actor.mental_health)
				)
			),
			0,
			100
		),
		"mental": clampi(
			int(
				round(
					float(actor.mental_health)
				)
			),
			0,
			100
		),
		"willpower": clampi(
			_god_mode_contract_willpower(actor),
			0,
			100
		),
		"happiness": clampi(
			int(
				round(
					float(actor.satisfaction)
				)
			),
			0,
			100
		),
		"smarts": clampi(
			int(
				round(
					float(actor.smarts)
				)
			),
			0,
			100
		),
		"looks": clampi(
			int(
				round(
					float(actor.looks)
				)
			),
			0,
			100
		),
		"imagination": clampi(
			int(
				round(
					float(actor.imagination)
				)
			),
			0,
			100
		),
		"fame": clampi(
			int(
				round(
					float(actor.fame)
				)
			),
			0,
			100
		),
		"life_diary_lines": (
			canonical_diary_lines.duplicate(false)
		),
		"birth_intro_ready": (
			not canonical_diary_lines.is_empty()
		),
		"birth_intro_contract_version": int(
			scenario.get(
				"resident_first_frame_birth_intro_report",
				{}
			).get(
				"birth_intro_contract_version",
				2
			)
		),
		"stats": {
			"health": clampi(
				int(
					round(
						float(actor.health)
					)
				),
				1,
				200
			),
			"hunger": clampi(
				int(
					round(
						float(actor.hunger)
					)
				),
				0,
				100
			),
			"mental": clampi(
				int(
					round(
						float(actor.mental_health)
					)
				),
				0,
				100
			),
			"mental_health": clampi(
				int(
					round(
						float(actor.mental_health)
					)
				),
				0,
				100
			),
			"willpower": clampi(
				_god_mode_contract_willpower(actor),
				0,
				100
			),
			"happiness": clampi(
				int(
					round(
						float(actor.satisfaction)
					)
				),
				0,
				100
			),
			"smarts": clampi(
				int(
					round(
						float(actor.smarts)
					)
				),
				0,
				100
			),
			"looks": clampi(
				int(
					round(
						float(actor.looks)
					)
				),
				0,
				100
			),
			"imagination": clampi(
				int(
					round(
						float(actor.imagination)
					)
				),
				0,
				100
			),
			"fame": clampi(
				int(
					round(
						float(actor.fame)
					)
				),
				0,
				100
			),
			"approval": 0,
			"bank": bank_balance
		},
		"max_values": {
			"health": 200,
			"hunger": 100,
			"mental": 100,
			"mental_health": 100,
			"willpower": 100,
			"happiness": 100,
			"smarts": 100,
			"looks": 100,
			"imagination": 100,
			"fame": 100,
			"approval": 100
		},
		"visibility": {
			"player_stats_overlay": true,
			"life_diary": true,
			"nav_tabs": true,
			"runtime_huds": true
		},
		"surface_context": {
			"source": (
				"god_mode_contract_engine."
				+ "build_playable_surface_snapshot"
			),
			"birth_is_first_consciousness_switch": true,
			"previous_actor_id": -1,
			"previous_actor_name": "Nobody",
			"main_scene_is_renderer_only": true,
			"ui_packet_consumer_only": true,
		},
		"pending_situations_count": 0,
		"life_diary_required": true,
		"player_stats_overlay_required": true,
		"nav_tabs_required": true,
		"runtime_huds_required": true,
		"blank_shell_forbidden": true,
		"loading_on_ready_forbidden": true,
		"main_scene_is_renderer_only": true,
		"birth_is_first_consciousness_switch": true,
		"previous_actor_id": -1,
		"previous_actor_name": "Nobody",
		"created_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	if typeof(
		state.scenario_state
	) == TYPE_DICTIONARY:
		var prebuilt_raw: Variant = (
			state.scenario_state.get(
				"prebuilt_first_frame_ui_snapshot",
				{}
			)
		)

		if typeof(
			prebuilt_raw
		) == TYPE_DICTIONARY:
			var prebuilt: Dictionary = (
				(
					prebuilt_raw as Dictionary
				).duplicate(false)
			)

			for key in prebuilt.keys():
				snapshot [key] = prebuilt [key]



		snapshot [
			"life_diary_lines"
		] = canonical_diary_lines.duplicate(false)
		snapshot [
			"birth_intro_ready"
		] = not canonical_diary_lines.is_empty()
		snapshot [
			"birth_intro_contract_version"
		] = 2
		snapshot [
			"placeholder_birth_intro_used"
		] = false

		state.scenario_state [
			"prebuilt_first_frame_ui_snapshot"
		] = snapshot.duplicate(true)
		state.scenario_state [
			"zero_frame_consciousness_switch_surface"
		] = snapshot.duplicate(true)

	return snapshot

func _route_prewarm_intent_to_reality_orchestrator(contract: Dictionary) -> void:
	if gs == null or gs.reality_orchestrator == null:
		return
	if not gs.reality_orchestrator.has_method("orchestrate_intent"):
		return

	gs.reality_orchestrator.orchestrate_intent({
		"id": str(contract.get("contract_id", "god_mode.prewarm")),
		"domain": "runtime",
		"authority": "reality",
		"event_payload": contract.duplicate(true),
		"effects": [
			"prewarm_world_seed",
			"build_hot_birth_capsule",
			"first_frame_snapshot",
			"ui_manifestation"
		],
		"composition_stack": [
			"god_mode_contract_engine",
			"reality_orchestrator",
			"game_state_capsule",
			"first_frame_surface_contract"
		]
	}, {
		"source": "god_mode_contract_engine.route_prewarm_intent_to_reality_orchestrator",
		"signature": str(contract.get("signature", "")),
	})


func _route_handoff_intent_to_reality_orchestrator(contract: Dictionary) -> void:
	if gs == null or gs.reality_orchestrator == null:
		return
	if not gs.reality_orchestrator.has_method("orchestrate_intent"):
		return

	gs.reality_orchestrator.orchestrate_intent({
		"id": str(contract.get("contract_id", "god_mode.handoff")),
		"domain": "runtime",
		"authority": "reality",
		"event_payload": contract.duplicate(true),
		"effects": [
			"claim_hot_capsule",
			"claim_playable_surface",
			"stream_tail_work_after_visible_surface",
			"ui_manifestation"
		],
		"composition_stack": [
			"god_mode_contract_engine",
			"god_mode_tracker_contract_engine",
			"reality_orchestrator",
			"playable_life_surface"
		]
	}, {
		"source": "god_mode_contract_engine.route_handoff_intent_to_reality_orchestrator",
		"signature": str(contract.get("signature", "")),
	})


func _publish_contract_to_scenario(reason: String) -> void:
	_ensure_state()
	if gs == null:
		return

	var state: Dictionary = current_state()

	gs.scenario_state ["god_mode_contract_engine_state"] = state.duplicate(true)
	gs.scenario_state ["god_mode_contract_engine_sequence"] = sequence
	gs.scenario_state ["god_mode_contract_engine_lifecycle"] = lifecycle
	gs.scenario_state ["god_mode_contract_engine_tracked_settings"] = tracked_settings.duplicate(true)
	gs.scenario_state ["god_mode_contract_engine_tracked_signature"] = tracked_signature
	gs.scenario_state ["god_mode_contract_engine_prewarm_contract"] = prewarm_contract.duplicate(true)
	gs.scenario_state ["god_mode_contract_engine_handoff_contract"] = handoff_contract.duplicate(true)
	gs.scenario_state ["god_mode_contract_engine_playable_surface_contract"] = playable_surface_contract.duplicate(true)
	gs.scenario_state ["god_mode_contract_engine_last_report"] = last_report.duplicate(true)
	gs.scenario_state ["god_mode_contract_engine_ledger"] = ledger.duplicate(true)

	gs.scenario_state ["god_mode_lifecycle"] = lifecycle
	gs.scenario_state ["god_mode_last_contract_reason"] = reason
	gs.scenario_state ["god_mode_main_scene_authority_removed"] = true
	gs.scenario_state ["god_mode_ui_is_viewer_only"] = true
	gs.scenario_state ["god_mode_ready_button_is_door"] = true
	gs.scenario_state ["god_mode_blank_shell_forbidden"] = true
	gs.scenario_state ["god_mode_loading_on_ready_forbidden"] = true

	if not playable_surface_contract.is_empty():
		gs.scenario_state ["god_mode_playable_surface_claimed"] = bool(playable_surface_contract.get("playable_surface_claimed", false))
		gs.scenario_state ["god_mode_playable_surface_contract"] = playable_surface_contract.duplicate(true)


func _commit_state() -> void:
	_publish_contract_to_scenario("commit_state")


func _succeed(mode: String, payload: Dictionary = {}) -> Dictionary:
	var row: Dictionary = {
		"success": true,
		"mode": mode,
		"schema": ENGINE_STATE_SCHEMA,
		"version": CONTRACT_VERSION,
		"lifecycle": lifecycle,
		"signature": tracked_signature,
		"at_ms": int(Time.get_ticks_msec())
	}

	for key in payload.keys():
		row [key] = payload [key]

	last_report = row.duplicate(true)
	_append_ledger(row)
	_publish_contract_to_scenario(mode)
	return row.duplicate(true)


func _fail(reason: String, payload: Dictionary = {}) -> Dictionary:
	EraLog.failure(
		get_script().resource_path.get_file(),
		str(reason)
	)
	var row: Dictionary = {
		"success": false,
		"reason": reason,
		"schema": ENGINE_STATE_SCHEMA,
		"version": CONTRACT_VERSION,
		"lifecycle": lifecycle,
		"signature": tracked_signature,
		"at_ms": int(Time.get_ticks_msec())
	}

	for key in payload.keys():
		row [key] = payload [key]

	last_report = row.duplicate(true)
	_append_ledger(row)
	_publish_contract_to_scenario(reason)
	return row.duplicate(true)


func _append_ledger(row: Dictionary) -> void:
	ledger.append(row.duplicate(true))
	if ledger.size() > MAX_LEDGER:
		ledger = ledger.slice(ledger.size() - MAX_LEDGER, ledger.size())


func _stable_signature_value(value: Variant) -> String:
	match typeof(value):
		TYPE_DICTIONARY:
			var dictionary: Dictionary = value
			var keys: Array = dictionary.keys()
			keys.sort()

			var parts: Array = []
			for key in keys:
				parts.append("%s:%s" % [str(key), _stable_signature_value(dictionary [key])])
			return "{%s}" % ",".join(parts)

		TYPE_ARRAY:
			var array_value: Array = value
			var parts: Array = []
			for item in array_value:
				parts.append(_stable_signature_value(item))
			return "[%s]" % ",".join(parts)

		TYPE_FLOAT:
			return "%.4f" % float(value)

		TYPE_INT:
			return str(int(value))

		TYPE_BOOL:
			return "true" if bool(value) else "false"

		_:
			return str(value)

func _apply_tracked_birth_settings_to_actor(actor: Person, settings: Dictionary) -> void:
	if actor == null:
		return

	var first_name: String = str(settings.get("first_name", "")).strip_edges()
	var last_name: String = str(settings.get("last_name", "")).strip_edges()

	if first_name != "":
		actor.first_name = first_name

	if last_name != "":
		actor.last_name = last_name

	if str(actor.first_name).strip_edges() == "" or str(actor.first_name).strip_edges().to_lower() == "unknown":
		actor.first_name = "Acrello"

	if str(actor.last_name).strip_edges() == "" or str(actor.last_name).strip_edges().to_lower() == "unknown":
		actor.last_name = "IsBack"

	actor.alive = true
	actor.cause_of_death = ""
	actor.death_year = 0

	if settings.has("health"):
		actor.health = clamp(float(settings.get("health", actor.health)), 1.0, 200.0)
	elif float(actor.health) <= 0.0:
		actor.health = 100.0

	if settings.has("mental_health"):
		actor.mental_health = clamp(float(settings.get("mental_health", actor.mental_health)), 0.0, 100.0)
	elif float(actor.mental_health) <= 0.0:
		actor.mental_health = 100.0

	if settings.has("happiness"):
		actor.satisfaction = clamp(float(settings.get("happiness", actor.satisfaction)), 0.0, 100.0)
	elif float(actor.satisfaction) <= 0.0:
		actor.satisfaction = 50.0

	if settings.has("smarts"):
		actor.smarts = clamp(float(settings.get("smarts", actor.smarts)), 0.0, 100.0)

	if settings.has("looks"):
		actor.looks = clamp(float(settings.get("looks", actor.looks)), 0.0, 100.0)

	if float(actor.hunger) <= 0.0:
		actor.hunger = 68.0

	actor.bank_balance = _god_mode_contract_bank_balance(actor, settings)


func _god_mode_contract_bank_balance(actor: Person, settings: Dictionary) -> int:
	if settings.has("bank_balance"):
		return max(0, int(settings.get("bank_balance", 0)))

	if settings.has("bank_balance_amount"):
		return max(0, int(settings.get("bank_balance_amount", 0)))

	var label: String = str(settings.get("bank_balance_label", "")).strip_edges()
	var parsed_label: int = _god_mode_contract_bank_balance_from_label(label)
	if parsed_label >= 0:
		return parsed_label

	if actor != null:
		return max(0, int(actor.bank_balance))

	return 0


func _god_mode_contract_bank_balance_from_label(label: String) -> int:
	var clean_label: String = str(label).strip_edges().replace("$", "").replace(",", "").replace(" ", "").to_upper()

	if clean_label == "":
		return -1

	var multiplier: float = 1.0

	if clean_label.ends_with("K"):
		multiplier = 1000.0
		clean_label = clean_label.substr(0, clean_label.length() - 1)
	elif clean_label.ends_with("M"):
		multiplier = 1000000.0
		clean_label = clean_label.substr(0, clean_label.length() - 1)
	elif clean_label.ends_with("B"):
		multiplier = 1000000000.0
		clean_label = clean_label.substr(0, clean_label.length() - 1)

	if not clean_label.is_valid_float():
		return -1

	return max(0, int(round(float(clean_label) * multiplier)))


func _god_mode_contract_willpower(actor: Person) -> int:
	if actor != null:
		var raw_value: Variant = actor.get("willpower")
		if typeof(raw_value) == TYPE_INT or typeof(raw_value) == TYPE_FLOAT:
			return int(raw_value)

	return 67
func _actor_display_name(actor: Person) -> String:
	if actor == null:
		return "Unknown Life"

	var first: String = str(actor.first_name).strip_edges()
	var last: String = str(actor.last_name).strip_edges()
	var full_name: String = ("%s %s" % [first, last]).strip_edges()

	if full_name == "":
		full_name = str(actor.name).strip_edges()
	if full_name == "":
		full_name = "Unknown Life"

	return full_name


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(value: Variant) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return (value as Array).duplicate(true)
	return []