extends Resource
class_name UniversalSwitchContractEngine

const ENGINE_STATE_SCHEMA:= "eralife.universal_switch_contract_engine_state"
const SWITCH_CONTRACT_SCHEMA:= "eralife.zero_frame_consciousness_switch_contract"
const SWITCH_SURFACE_SCHEMA:= "eralife.zero_frame_consciousness_surface_contract"
const CONTRACT_VERSION:= 1
const MAX_SWITCH_CONTRACTS:= 160
const MAX_SWITCH_TAIL_QUEUE:= 80

var gs
var switch_contracts: Dictionary = {}
var switch_tail_queue: Array = []
var switch_sequence: int = 0
var last_report: Dictionary = {}
var state_hydrated: bool = false
func _init(_gs = null):
	gs = _gs
	_ensure_state()


func _ensure_state() -> void:
	if gs == null:
		return




	if state_hydrated:
		return

	if typeof(
		gs.scenario_state
	) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var contracts_raw: Variant = (
		gs.scenario_state.get(
			"universal_switch_contracts",
			switch_contracts
		)
	)
	var tail_raw: Variant = (
		gs.scenario_state.get(
			"universal_switch_tail_queue",
			switch_tail_queue
		)
	)
	var report_raw: Variant = (
		gs.scenario_state.get(
			"universal_switch_last_report",
			last_report
		)
	)

	switch_contracts = (
		(
			contracts_raw as Dictionary
		).duplicate(true)
		if typeof(
			contracts_raw
		) == TYPE_DICTIONARY
		else {}
	)
	switch_tail_queue = (
		(
			tail_raw as Array
		).duplicate(true)
		if typeof(
			tail_raw
		) == TYPE_ARRAY
		else []
	)
	switch_sequence = int(
		gs.scenario_state.get(
			"universal_switch_sequence",
			switch_sequence
		)
	)
	last_report = (
		(
			report_raw as Dictionary
		).duplicate(true)
		if typeof(
			report_raw
		) == TYPE_DICTIONARY
		else {}
	)

	_repair_state()

	state_hydrated = true

	gs.scenario_state [
		"universal_switch_state_hydrated"
	] = true
	gs.scenario_state [
		"universal_switch_state_hydrated_at_ms"
	] = int(
		Time.get_ticks_msec()
	)
	gs.scenario_state [
		"universal_switch_press_rehydrates_history"
	] = false


func export_state() -> Dictionary:
	_ensure_state()
	return {
		"schema": ENGINE_STATE_SCHEMA,
		"version": CONTRACT_VERSION,
		"switch_contracts": switch_contracts.duplicate(true),
		"switch_tail_queue": switch_tail_queue.duplicate(true),
		"switch_sequence": switch_sequence,
		"last_report": last_report.duplicate(true),
		"exported_at_ms": int(Time.get_ticks_msec())
	}


func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "invalid_data"
		}

	switch_contracts = _shallow_dictionary(data.get("switch_contracts", data.get("universal_switch_contracts", {})))
	switch_tail_queue = _safe_array(data.get("switch_tail_queue", data.get("universal_switch_tail_queue", [])))
	switch_sequence = int(data.get("switch_sequence", data.get("universal_switch_sequence", 0)))
	last_report = _shallow_dictionary(data.get("last_report", {}))

	_repair_state()
	state_hydrated = true
	_commit_state()

	last_report = {
		"success": true,
		"mode": "universal_switch_contract_engine_imported",
		"schema": ENGINE_STATE_SCHEMA,
		"version": CONTRACT_VERSION,
		"contract_count": switch_contracts.size(),
		"tail_count": switch_tail_queue.size(),
		"repaired": true
	}

	return last_report.duplicate(true)


func request_zero_frame_switch(target: Person, context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	if gs == null:
		return {
			"success": false,
			"reason": "missing_game_state"
		}

	if target == null:
		return {
			"success": false,
			"reason": "missing_target"
		}

	var target_id: int = int(target.id)
	if target_id <= 0:
		return {
			"success": false,
			"reason": "invalid_target_id"
		}

	if not bool(target.alive) or float(target.health) <= 0.0:
		return {
			"success": false,
			"reason": "target_dead",
			"target_id": target_id
		}

	var press_frame_commit: bool = (
		bool(context.get("press_frame_commit", false))
		or bool(context.get("zero_frame", false))
		or str(context.get("surface", "")).strip_edges() == "full_relationship_profile_popup"
	)
	var forbid_cold_fallback_on_press: bool = bool(context.get("forbid_cold_fallback_on_press", press_frame_commit))
	var playable_life_viewer_packet_required: bool = bool(context.get("playable_life_viewer_packet_required", false))
	var previous_actor: Person = gs.player
	var previous_actor_id: int = int(previous_actor.id) if previous_actor != null else -1

	var target_surface: Dictionary = _prewarmed_zero_frame_surface_for_actor(target)
	if target_surface.is_empty():
		if press_frame_commit and forbid_cold_fallback_on_press:
			return {
				"success": false,
				"reason": "target_surface_not_prewarmed_on_press",
				"target_id": target_id,
				"zero_frame_consciousness_switch": true,
				"press_frame_build_forbidden": true
			}

		target_surface = _surface_contract_for_actor(target, {
			"source": "zero_frame_switch_target_surface_cold_fallback",
			"surface_first": true,
			"skip_pending_count": false
		})
	elif press_frame_commit:
		target_surface = target_surface.duplicate(true)
		target_surface ["press_frame_commit"] = true
		target_surface ["surface_hot"] = true
		target_surface ["switch_press_must_not_build_surface"] = true
		target_surface ["updated_at_ms"] = int(Time.get_ticks_msec())
	else:
		target_surface = _refresh_surface_contract_for_actor(target_surface, target, {
			"source": "zero_frame_switch_target_surface_from_prewarm",
			"surface_first": true
		})
	if press_frame_commit and playable_life_viewer_packet_required:
		target_surface ["playable_life_viewer_packet_required"] = true
		target_surface ["press_frame_must_consume_viewer_packet"] = true
		target_surface ["platform_renderer_must_not_build"] = true
	if previous_actor != null and int(previous_actor.id) == target_id:
		var no_op_result: Dictionary = _result_for_switch(previous_actor_id, target, target_surface, {}, context)
		return {
			"success": true,
			"mode": "zero_frame_consciousness_switch_noop",
			"zero_frame_consciousness_switch": true,
			"previous_actor_id": previous_actor_id,
			"controlled_actor_id": target_id,
			"surface_contract": target_surface.duplicate(true),
			"result": no_op_result.duplicate(true)
		}

	var previous_surface: Dictionary = {}
	if previous_actor != null:
		previous_surface = _prewarmed_zero_frame_surface_for_actor(previous_actor)

	if previous_actor != null and previous_surface.is_empty():
		if press_frame_commit and forbid_cold_fallback_on_press:
			return {
				"success": false,
				"reason": "previous_surface_not_prewarmed_on_press",
				"target_id": target_id,
				"previous_actor_id": previous_actor_id,
				"zero_frame_consciousness_switch": true,
				"press_frame_build_forbidden": true
			}

		previous_surface = _surface_contract_for_actor(previous_actor, {
			"source": "zero_frame_switch_previous_surface_cold_fallback",
			"surface_first": true,
			"skip_pending_count": false
		})
	elif press_frame_commit:
		previous_surface = previous_surface.duplicate(true)
		previous_surface ["press_frame_commit"] = true
		previous_surface ["surface_hot"] = true
		previous_surface ["switch_press_must_not_build_surface"] = true
		previous_surface ["updated_at_ms"] = int(Time.get_ticks_msec())
	elif previous_actor != null:
		previous_surface = _refresh_surface_contract_for_actor(previous_surface, previous_actor, {
			"source": "zero_frame_switch_previous_surface_from_prewarm",
			"surface_first": true
		})

	var switched: bool = _commit_zero_frame_player_pointer(previous_actor, target, context)
	if not switched:
		return {
			"success": false,
			"reason": "switch_rejected",
			"target_id": target_id
		}

	var controlled_actor: Person = gs.player
	if controlled_actor == null:
		controlled_actor = target

	var controlled_surface: Dictionary = target_surface.duplicate(true)
	controlled_surface ["actor_id"] = int(controlled_actor.id)
	controlled_surface ["actor_name"] = _actor_display_name(controlled_actor)
	controlled_surface ["bank_balance"] = max(0, int(controlled_actor.bank_balance))
	controlled_surface ["press_frame_commit"] = press_frame_commit
	controlled_surface ["surface_hot"] = true
	controlled_surface ["switch_press_must_not_build_surface"] = true
	controlled_surface ["updated_at_ms"] = int(Time.get_ticks_msec())

	if not controlled_surface.has("hud_truth"):
		controlled_surface ["hud_truth"] = {}

	switch_sequence += 1

	var contract_id: String = "zero_frame_switch_%d_%d_%d" % [
		switch_sequence,
		target_id,
		int(Time.get_ticks_msec())
	]

	var contract: Dictionary = {
		"schema": SWITCH_CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": contract_id,
		"contract_id": contract_id,
		"mode": "zero_frame_consciousness_switch",
		"switch_mode": "direct_pointer_commit_surface_first_hot_press" if press_frame_commit else "direct_pointer_commit_surface_first",
		"source": str(context.get("source", "universal_switch_contract_engine")),
		"previous_actor_id": previous_actor_id,
		"previous_actor_name": _actor_display_name(previous_actor),
		"controlled_actor_id": int(controlled_actor.id),
		"controlled_actor_name": _actor_display_name(controlled_actor),
		"target_actor_id": target_id,
		"target_actor_name": _actor_display_name(target),
		"previous_surface": previous_surface.duplicate(true),
		"target_surface": target_surface.duplicate(true),
		"controlled_surface": controlled_surface.duplicate(true),
		"visible_commit_ms": int(Time.get_ticks_msec()),
		"press_frame_commit": press_frame_commit,
		"press_frame_build_forbidden": true,
		"ui_policy": {
			"ui_is_pure_renderer": true,
			"pending_situation_count_refresh_forbidden_on_press": press_frame_commit,
			"camera_model": "instant_consciousness_shift",
			"playable_life_viewer_required": playable_life_viewer_packet_required,
			"platform_renderer_must_not_build": true,
			"viewer_packet_must_already_exist": playable_life_viewer_packet_required
		},
		"context": context.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec()),
		"updated_at_ms": int(Time.get_ticks_msec())
	}

	switch_contracts [contract_id] = contract.duplicate(true)
	_trim_contracts()

	switch_tail_queue.append({
		"contract_id": contract_id,
		"previous_actor_id": previous_actor_id,
		"controlled_actor_id": int(controlled_actor.id),
		"stage": "family_integrity_sync_queued",
		"created_at_ms": int(Time.get_ticks_msec()),
		"next_step_ms": int(Time.get_ticks_msec()) + 1200
	})

	if switch_tail_queue.size() > MAX_SWITCH_TAIL_QUEUE:
		switch_tail_queue = switch_tail_queue.slice(switch_tail_queue.size() - MAX_SWITCH_TAIL_QUEUE, switch_tail_queue.size())

	_publish_switch_contract(contract)
	_commit_state()

	var result: Dictionary = _result_for_switch(previous_actor_id, controlled_actor, controlled_surface, contract, context)

	last_report = {
		"success": true,
		"mode": "zero_frame_consciousness_switch_committed",
		"zero_frame_consciousness_switch": true,
		"contract_id": contract_id,
		"previous_actor_id": previous_actor_id,
		"controlled_actor_id": int(controlled_actor.id),
		"controlled_actor_name": _actor_display_name(controlled_actor),
		"surface_contract": controlled_surface.duplicate(true),
		"switch_contract": contract.duplicate(true),
		"result": result.duplicate(true)
	}

	_commit_state()
	return last_report.duplicate(true)
func _support_main_tab_deck_is_hot(
	deck: Dictionary,
	target_id: int
) -> bool:
	if (
		target_id <= 0
		or deck.is_empty()
	):
		return false

	for raw_tab_id in [
		"relationships",
		"school",
		"activities",
		"career",
		"mods"
	]:
		var tab_id: String = str(
			raw_tab_id
		)
		var raw_contract: Variant = deck.get(
			tab_id,
			{}
		)
		var tab_contract: Dictionary = (
			raw_contract as Dictionary
			if typeof(raw_contract) == TYPE_DICTIONARY
			else {}
		)

		if tab_contract.is_empty():
			return false

		if int(
			tab_contract.get(
				"actor_id",
				-1
			)
		) != target_id:
			return false

		var schema: String = str(
			tab_contract.get(
				"schema",
				""
			)
		).strip_edges().to_lower()
		var truth_state: String = str(
			tab_contract.get(
				"truth_state",
				""
			)
		).strip_edges().to_lower()

		if (
			schema == "eralife.pointer_only.destination_tab_contract"
			or truth_state == "pointer_only_resident_shell"
			or bool(
				tab_contract.get(
					"pointer_only",
					false
				)
			)
		):
			return false

	return true
func prewarm_profile_switch_actor_lens_core_for_actor(
	target: Person,
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	if gs == null:
		return {
			"success": false,
			"reason": "missing_game_state"
		}

	if target == null:
		return {
			"success": false,
			"reason": "missing_target"
		}

	var target_id: int = int(
		target.id
	)

	if target_id <= 0:
		return {
			"success": false,
			"reason": "invalid_target_id"
		}

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var actor_key: String = str(
		target_id
	)
	var packet_cache: Dictionary = _shallow_dictionary(
		gs.scenario_state.get(
			"profile_pointer_packet_by_actor",
			{}
		)
	)
	var cached_packet: Dictionary = _shallow_dictionary(
		packet_cache.get(
			actor_key,
			{}
		)
	)
	var cached_surface: Dictionary = _shallow_dictionary(
		cached_packet.get(
			"surface_contract",
			{}
		)
	)
	var cached_main_tab_deck: Dictionary = _shallow_dictionary(
		cached_packet.get(
			"main_tab_surface_contracts",
			cached_surface.get(
				"main_tab_surface_contracts",
				{}
			)
		)
	)
	var cached_support_packet: Dictionary = _shallow_dictionary(
		cached_packet.get(
			"control_switch_support_surface_packet",
			cached_surface.get(
				"control_switch_support_surface_packet",
				{}
			)
		)
	)
	var cached_truth: Dictionary = _profile_switch_core_packet_truth(
		cached_packet,
		target_id
	)
	var cached_destination_deck_hot: bool = _support_main_tab_deck_is_hot(
		cached_main_tab_deck,
		target_id
	)

	if (
		bool(
			cached_truth.get(
				"core_packet_hot",
				false
			)
		)
		and bool(
			cached_truth.get(
				"temporal_pointer_hot",
				false
			)
		)
		and int(
			cached_surface.get(
				"age",
				-1
			)
		) == int(
			target.age
		)
		and int(
			cached_truth.get(
				"lens_age",
				-1
			)
		) == int(
			target.age
		)
		and cached_destination_deck_hot
		and not cached_support_packet.is_empty()
	):
		return {
			"success": true,
			"mode": "profile_switch_actor_lens_complete_cache_hit",
			"actor_id": target_id,
			"viewer_packet": cached_packet.duplicate(false),
			"surface_contract": cached_surface.duplicate(false),
			"main_tab_surface_deck_hot": true,
			"control_switch_support_surface_packet": (
				cached_support_packet.duplicate(false)
			),
			"control_switch_support_surface_packet_published": true,
			"optional_support_surfaces_hot": bool(
				cached_support_packet.get(
					"support_surfaces_hot",
					false
				)
			),
			"switch_press_build_forbidden": true,
			"visible_click_work_required": false,
			"ready_gate_member": false,
			"ui_is_renderer_only": true
		}

	var source: String = str(
		context.get(
			"source",
			(
				"universal_switch_contract_engine."
				+ "profile_switch_actor_lens_core"
			)
		)
	).strip_edges()
	var complete_destination_deck_required: bool = (
		bool(
			context.get(
				"complete_destination_deck_required",
				false
			)
		)
		or bool(
			context.get(
				"relationship_profile_visible_packet",
				false
			)
		)
		or bool(
			context.get(
				"destination_support_packet_building",
				false
			)
		)
	)
	if complete_destination_deck_required:
		gs.scenario_state [
			"universal_switch_complete_packet_upgrade_active_actor_id"
		] = target_id
		gs.scenario_state [
			"universal_switch_complete_packet_upgrade_source"
		] = source
		gs.scenario_state [
			"universal_switch_complete_packet_upgrade_started_at_ms"
		] = int(
			Time.get_ticks_msec()
		)
		gs.scenario_state [
			"universal_switch_complete_packet_upgrade_authority"
		] = "UniversalSwitchContractEngine"
		gs.scenario_state [
			"universal_switch_complete_packet_upgrade_ready_gate_member"
		] = false

		EraLog.truth(
			"SWITCH_PACKET_UPGRADE_BEGIN"
				+ "|actor_id=" + str(target_id)
				+ "|source=" + source
				+ "|cached_pointer_core_hot=" + str(
					bool(
						cached_truth.get(
							"core_packet_hot",
							false
						)
					)
				)
				+ "|cached_destination_deck_hot=" + str(
					cached_destination_deck_hot
				)
				+ "|complete_destination_deck_required=true"
				+ "|authority=UniversalSwitchContractEngine"
				+ "|ready_gate_member=false"
				+ "|at_ms=" + str(Time.get_ticks_msec())
		)
	var pointer_packet: Dictionary = prepare_profile_pointer_packet(
		target,
		{
			"source": source,
			"relationship_profile_packet": true,
			"press_frame_build_forbidden": true,
			"full_surface_graph_required": false,
			"pointer_revision_authority": (
				"UniversalSwitchContractEngine"
			),
			"ready_gate_member": false,
			"ui_is_renderer_only": true
		}
	)

	if not bool(
		pointer_packet.get(
			"success",
			false
		)
	):
		return pointer_packet

	var pointer_surface: Dictionary = _shallow_dictionary(
		pointer_packet.get(
			"surface_contract",
			{}
		)
	).duplicate(false)
	var pointer_revision: String = str(
		pointer_packet.get(
			"pointer_revision",
			pointer_surface.get(
				"pointer_revision",
				""
			)
		)
	).strip_edges()

	if pointer_revision == "":
		return {
			"success": false,
			"reason": "profile_pointer_revision_missing",
			"actor_id": target_id,
			"retryable": true
		}

	if not complete_destination_deck_required:
		pointer_surface ["actor_id"] = target_id
		pointer_surface ["pointer_revision"] = pointer_revision
		pointer_surface ["surface_hot"] = true
		pointer_surface ["press_frame_ready"] = true
		pointer_surface ["main_tab_surface_deck_hot"] = false
		pointer_surface ["support_main_tab_deck_hot"] = false
		pointer_surface ["optional_support_surfaces_hot"] = false
		pointer_surface ["control_switch_support_surfaces_hot"] = false
		pointer_surface ["internal_pointer_core_only"] = true
		pointer_surface ["visible_relationship_switch_packet"] = false
		pointer_surface ["complete_actor_destination_deck"] = false
		pointer_surface ["support_packet_publication_deferred"] = true
		pointer_surface ["switch_press_must_not_build_surface"] = true
		pointer_surface ["ready_gate_member"] = false
		pointer_surface ["ui_is_renderer_only"] = true

		pointer_packet ["success"] = true
		pointer_packet ["actor_id"] = target_id
		pointer_packet ["pointer_revision"] = pointer_revision
		pointer_packet ["surface_contract"] = pointer_surface.duplicate(false)
		pointer_packet ["main_tab_surface_deck_hot"] = false
		pointer_packet ["support_main_tab_deck_hot"] = false
		pointer_packet ["optional_support_surfaces_hot"] = false
		pointer_packet ["control_switch_support_surfaces_hot"] = false
		pointer_packet ["internal_pointer_core_only"] = true
		pointer_packet ["visible_relationship_switch_packet"] = false
		pointer_packet ["complete_actor_destination_deck"] = false
		pointer_packet ["support_packet_publication_deferred"] = true
		pointer_packet ["press_frame_build_forbidden"] = true
		pointer_packet ["visible_click_work_required"] = false
		pointer_packet ["ready_gate_member"] = false
		pointer_packet ["ui_is_renderer_only"] = true

		register_profile_pointer_packet_revision(
			pointer_packet,
			{
				"source": source,
				"target_id": target_id,
				"internal_pointer_core_only": true,
				"visible_relationship_switch_packet": false,
				"support_packet_publication_deferred": true,
				"ready_gate_member": false,
				"ui_is_renderer_only": true
			}
		)

		EraLog.truth(
			"PROFILE_SWITCH_POINTER_CORE_PREWARMED"
			+ "|actor_id=" + str(target_id)
			+ "|pointer_revision=" + pointer_revision
			+ "|complete_destination_deck_required=false"
			+ "|support_packet_published=false"
			+ "|visible_relationship_switch_packet=false"
			+ "|background_only=true"
			+ "|build_on_press=false"
			+ "|ready_gate_member=false"
			+ "|at_ms=" + str(Time.get_ticks_msec())
		)

		return {
			"success": true,
			"mode": "profile_switch_actor_lens_pointer_core_prewarmed",
			"actor_id": target_id,
			"pointer_revision": pointer_revision,
			"surface_contract": pointer_surface.duplicate(false),
			"viewer_packet": pointer_packet.duplicate(false),
			"main_tab_surface_deck_hot": false,
			"support_main_tab_deck_hot": false,
			"optional_support_surfaces_hot": false,
			"complete_actor_destination_deck": false,
			"internal_pointer_core_only": true,
			"visible_relationship_switch_packet": false,
			"switch_press_build_forbidden": true,
			"visible_click_work_required": false,
			"ready_gate_member": false,
			"ui_is_renderer_only": true
		}

	var relationships_contract: Dictionary = {}
	var school_contract: Dictionary = {}
	var activities_contract: Dictionary = {}
	var career_contract: Dictionary = {}
	var mods_contract: Dictionary = {}
	var pending_payload: Dictionary = {}

	if (
		gs.relationships_hub_contract_engine != null
		and gs.relationships_hub_contract_engine.has_method(
			"emit_hub_contract"
		)
	):
		relationships_contract = _shallow_dictionary(
			gs.relationships_hub_contract_engine.emit_hub_contract(
				target,
				{
					"active_section_id": "family",
					"force_refresh": false,
					"source": source,
					"resident_projection": true,
					"cooperative_projection": true,
					"projection_read_only": true,
					"publish_card_shell_to_scenario": false,
					"recursive_switch_packet_publication_forbidden": true,
					"relationship_card_switch_packets_forbidden": true,
					"profile_switch_packet_resolution_forbidden": true,
					"switch_shell_stage_forbidden": true,
					"support_packet_publication_context": true,
					"destination_support_packet_building": true,
					"build_on_click_forbidden": true,
					"switch_press_build_forbidden": true,
					"ready_gate_member": false,
					"ui_is_renderer_only": true
				}
			)
		)

	if (
		gs.school_hub_contract_engine != null
		and gs.school_hub_contract_engine.has_method(
			"emit_hub_contract"
		)
	):
		school_contract = _shallow_dictionary(
			gs.school_hub_contract_engine.emit_hub_contract(
				target,
				{
					"active_section_id": "overview",
					"force_refresh": false,
					"source": source,
					"resident_projection": true,
					"projection_read_only": true,
					"build_on_click_forbidden": true,
					"switch_press_build_forbidden": true,
					"ready_gate_member": false,
					"ui_is_renderer_only": true
				}
			)
		)

	if (
		gs.activities_hub_contract_engine != null
		and gs.activities_hub_contract_engine.has_method(
			"emit_hub_contract"
		)
	):
		activities_contract = _shallow_dictionary(
			gs.activities_hub_contract_engine.emit_hub_contract(
				target,
				{
					"active_section": "all",
					"force_refresh": false,
					"source": source,
					"resident_projection": true,
					"prewarm_only": true,
					"read_only": true,
					"build_on_click_forbidden": true,
					"visible_click_work_forbidden": true,
					"switch_press_build_forbidden": true,
					"ready_gate_member": false,
					"ui_is_renderer_only": true
				}
			)
		)

	if (
		gs.career_hub_contract_engine != null
		and gs.career_hub_contract_engine.has_method(
			"resolve_career_hub"
		)
	):
		career_contract = _shallow_dictionary(
			gs.career_hub_contract_engine.resolve_career_hub(
				target,
				{
					"active_section": "overview",
					"career_lane": "full_time",
					"force_refresh": false,
					"source": source,
					"resident_projection": true,
					"build_on_click_forbidden": true,
					"switch_press_build_forbidden": true,
					"ready_gate_member": false,
					"ui_is_expression_only": true
				}
			)
		)

	if (
		gs.mod_menu_contract_engine != null
		and gs.mod_menu_contract_engine.has_method(
			"emit_menu_contract"
		)
	):
		mods_contract = _shallow_dictionary(
			gs.mod_menu_contract_engine.emit_menu_contract(
				target,
				{
					"active_section": "bundles",
					"force_refresh": false,
					"surface_mode": "global_hub",
					"source": source,
					"resident_projection": true,
					"default_reality_bundle_id": (
						"caveman_reality_pack"
					),
					"section_press_reveal_only": true,
					"build_on_click_forbidden": true,
					"switch_press_build_forbidden": true,
					"ready_gate_member": false,
					"ui_is_expression_only": true
				}
			)
		)

	if (
		gs.pending_situations_engine != null
		and gs.pending_situations_engine.has_method(
			"build_pending_list_payload"
		)
	):
		pending_payload = _shallow_dictionary(
			gs.pending_situations_engine.build_pending_list_payload(
				target_id
			)
		)

	if pending_payload.is_empty():
		pending_payload = {
			"success": true,
			"schema": (
				"eralife.pending_situations.empty_actor_payload"
			),
			"version": CONTRACT_VERSION,
			"actor_id": target_id,
			"actor_name": _actor_display_name(
				target
			),
			"count": 0,
			"contracts": [],
			"category_groups": [],
			"dominant_category": "none",
			"truth_state": "hot",
			"ui_is_renderer_only": true
		}

	pending_payload ["success"] = bool(
		pending_payload.get(
			"success",
			true
		)
	)
	pending_payload ["actor_id"] = target_id
	pending_payload ["actor_name"] = _actor_display_name(
		target
	)
	pending_payload ["prewarmed"] = true
	pending_payload [
		"visible_click_work_required"
	] = false
	pending_payload [
		"switch_press_build_forbidden"
	] = true
	pending_payload ["ready_gate_member"] = false
	pending_payload ["truth_state"] = "hot"
	pending_payload ["ui_is_renderer_only"] = true

	var main_tab_deck: Dictionary = {
		"relationships": relationships_contract.duplicate(false),
		"school": school_contract.duplicate(false),
		"activities": activities_contract.duplicate(false),
		"career": career_contract.duplicate(false),
		"mods": mods_contract.duplicate(false)
	}
	var missing_main_tabs: Array = []

	for raw_tab_id in [
		"relationships",
		"school",
		"activities",
		"career",
		"mods"
	]:
		var tab_id: String = str(
			raw_tab_id
		)
		var tab_contract: Dictionary = _shallow_dictionary(
			main_tab_deck.get(
				tab_id,
				{}
			)
		)

		if (
			tab_contract.is_empty()
			or int(
				tab_contract.get(
					"actor_id",
					-1
				)
			) != target_id
		):
			missing_main_tabs.append(
				tab_id
			)
			continue

		var tab_schema: String = str(
			tab_contract.get(
				"schema",
				""
			)
		).strip_edges().to_lower()
		var tab_truth_state: String = str(
			tab_contract.get(
				"truth_state",
				""
			)
		).strip_edges().to_lower()

		if (
			tab_schema == "eralife.pointer_only.destination_tab_contract"
			or tab_truth_state == "pointer_only_resident_shell"
			or bool(
				tab_contract.get(
					"pointer_only",
					false
				)
			)
		):
			missing_main_tabs.append(
				tab_id
			)

	if not missing_main_tabs.is_empty():
		EraLog.truth(
			"SWITCH_PACKET_UPGRADE_ABORT"
				+ "|actor_id=" + str(target_id)
				+ "|reason=profile_switch_actor_destination_deck_pending"
				+ "|missing_main_tabs=" + str(missing_main_tabs)
				+ "|pointer_revision=" + pointer_revision
				+ "|retryable=true"
				+ "|authority=UniversalSwitchContractEngine"
				+ "|ready_gate_member=false"
				+ "|at_ms=" + str(Time.get_ticks_msec())
		)

		return {
			"success": false,
			"reason": (
				"profile_switch_actor_destination_deck_pending"
			),
			"retryable": true,
			"actor_id": target_id,
			"missing_main_tabs": missing_main_tabs,
			"switch_press_build_forbidden": true,
			"ready_gate_member": false
		}

	var support_packet: Dictionary = publish_resident_control_switch_support_surface_packet_from_deck(
		target,
		main_tab_deck,
		{
			"source": (
				source
				+ ".complete_destination_support_packet"
			),
			"pending_situations_payload": (
				pending_payload.duplicate(false)
			),
			"relationship_profile_packet": true,
			"complete_destination_deck_required": true,
			"pointer_only_packet_forbidden": true,
			"switch_press_must_not_build_surface": true,
			"ready_gate_member": false,
			"ui_is_renderer_only": true
		}
	)

	if not bool(
		support_packet.get(
			"main_tab_surface_deck_hot",
			false
		)
	):
		EraLog.truth(
			"SWITCH_PACKET_PUBLISH_ABORT"
				+ "|actor_id=" + str(target_id)
				+ "|reason=profile_switch_support_packet_publication_failed"
				+ "|support_packet_success=" + str(
					bool(
						support_packet.get(
							"success",
							false
						)
					)
				)
				+ "|support_packet_reason=" + str(
					support_packet.get(
						"reason",
						"unknown"
					)
				)
				+ "|missing_tabs=" + str(
					_safe_array(
						support_packet.get(
							"missing_tabs",
							[]
						)
					)
				)
				+ "|pointer_only_tabs=" + str(
					_safe_array(
						support_packet.get(
							"pointer_only_tabs",
							[]
						)
					)
				)
				+ "|retryable=true"
				+ "|authority=UniversalSwitchContractEngine"
				+ "|ready_gate_member=false"
				+ "|at_ms=" + str(Time.get_ticks_msec())
		)

		return {
			"success": false,
			"reason": (
				"profile_switch_support_packet_publication_failed"
			),
			"retryable": true,
			"actor_id": target_id,
			"support_packet": support_packet.duplicate(false),
			"switch_press_build_forbidden": true,
			"ready_gate_member": false
		}

	EraLog.truth(
		"SWITCH_PACKET_UPGRADE_SUPPORT_READY"
			+ "|actor_id=" + str(target_id)
			+ "|pointer_revision=" + pointer_revision
			+ "|main_tab_surface_deck_hot=true"
			+ "|support_packet_published=true"
			+ "|support_surfaces_hot=" + str(
				bool(
					support_packet.get(
						"support_surfaces_hot",
						false
					)
				)
			)
			+ "|authority=UniversalSwitchContractEngine"
			+ "|ready_gate_member=false"
			+ "|at_ms=" + str(Time.get_ticks_msec())
	)

	pointer_surface ["actor_id"] = target_id
	pointer_surface ["pointer_revision"] = pointer_revision
	pointer_surface [
		"main_tab_surface_contracts"
	] = main_tab_deck.duplicate(false)
	pointer_surface [
		"pending_situations_payload"
	] = pending_payload.duplicate(false)
	pointer_surface [
		"control_switch_support_surface_packet"
	] = support_packet.duplicate(false)
	pointer_surface [
		"control_switch_support_surface_packet_published"
	] = true
	pointer_surface [
		"control_switch_support_packet_registry_authority"
	] = "UniversalSwitchContractEngine"
	pointer_surface [
		"control_switch_support_packet_registry_key"
	] = actor_key
	pointer_surface ["surface_hot"] = true
	pointer_surface ["press_frame_ready"] = true
	pointer_surface [
		"main_tab_surface_deck_hot"
	] = true
	pointer_surface [
		"support_main_tab_deck_hot"
	] = true
	pointer_surface [
		"pending_situations_surface_hot"
	] = true
	pointer_surface [
		"optional_support_surfaces_hot"
	] = bool(
		support_packet.get(
			"support_surfaces_hot",
			false
		)
	)
	pointer_surface [
		"control_switch_support_surfaces_hot"
	] = bool(
		support_packet.get(
			"support_surfaces_hot",
			false
		)
	)
	pointer_surface [
		"switch_press_must_not_build_surface"
	] = true
	pointer_surface [
		"created_for_zero_frame_switch"
	] = true
	pointer_surface [
		"complete_actor_destination_deck"
	] = true
	pointer_surface [
		"pointer_revision_stable_across_surface_enrichment"
	] = true
	pointer_surface [
		"switch_commit_blocked_by_support_deck"
	] = false
	pointer_surface ["ready_gate_member"] = false
	pointer_surface ["ui_is_renderer_only"] = true

	pointer_packet ["success"] = true
	pointer_packet ["actor_id"] = target_id
	pointer_packet ["pointer_revision"] = pointer_revision
	pointer_packet [
		"surface_contract"
	] = pointer_surface.duplicate(false)
	pointer_packet [
		"main_tab_surface_contracts"
	] = main_tab_deck.duplicate(false)
	pointer_packet [
		"pending_situations_payload"
	] = pending_payload.duplicate(false)
	pointer_packet [
		"control_switch_support_surface_packet"
	] = support_packet.duplicate(false)
	pointer_packet [
		"control_switch_support_surface_packet_published"
	] = true
	pointer_packet [
		"control_switch_support_packet_registry_authority"
	] = "UniversalSwitchContractEngine"
	pointer_packet [
		"control_switch_support_packet_registry_key"
	] = actor_key
	pointer_packet [
		"main_tab_surface_deck_hot"
	] = true
	pointer_packet [
		"support_main_tab_deck_hot"
	] = true
	pointer_packet [
		"pending_situations_surface_hot"
	] = true
	pointer_packet [
		"optional_support_surfaces_hot"
	] = bool(
		support_packet.get(
			"support_surfaces_hot",
			false
		)
	)
	pointer_packet [
		"control_switch_support_surfaces_hot"
	] = bool(
		support_packet.get(
			"support_surfaces_hot",
			false
		)
	)
	pointer_packet [
		"complete_actor_destination_deck"
	] = true
	pointer_packet [
		"press_frame_build_forbidden"
	] = true
	pointer_packet [
		"visible_click_work_required"
	] = false
	pointer_packet [
		"pointer_packet_enriched_without_revision_replacement"
	] = true
	pointer_packet [
		"switch_commit_blocked_by_support_deck"
	] = false
	pointer_packet ["ready_gate_member"] = false
	pointer_packet ["ui_is_renderer_only"] = true

	var core_truth: Dictionary = (
		_profile_switch_core_packet_truth(
			pointer_packet,
			target_id
		)
	)

	if not bool(
		core_truth.get(
			"core_packet_hot",
			false
		)
	):
		return {
			"success": false,
			"reason": (
				"profile_switch_actor_lens_core_not_hot"
			),
			"retryable": true,
			"actor_id": target_id,
			"core_truth": core_truth.duplicate(false),
			"switch_press_build_forbidden": true,
			"ready_gate_member": false
		}

	var registration_report: Dictionary = (
		register_profile_pointer_packet_revision(
			pointer_packet,
			{
				"source": source,
				"target_id": target_id,
				"complete_destination_deck_required": true,
				"ready_gate_member": false,
				"ui_is_renderer_only": true
			}
		)
	)

	if not bool(
		registration_report.get(
			"success",
			false
		)
	):
		return {
			"success": false,
			"reason": (
				"profile_pointer_revision_registration_failed"
			),
			"retryable": true,
			"actor_id": target_id,
			"registration_report": (
				registration_report.duplicate(false)
			)
		}

	packet_cache = _shallow_dictionary(
		gs.scenario_state.get(
			"profile_pointer_packet_by_actor",
			{}
		)
	).duplicate(false)
	packet_cache [
		actor_key
	] = pointer_packet.duplicate(false)

	gs.scenario_state [
		"profile_pointer_packet_by_actor"
	] = packet_cache
	gs.scenario_state [
		"profile_pointer_packet_last_actor_id"
	] = target_id
	gs.scenario_state [
		"profile_pointer_packet_last_revision"
	] = pointer_revision
	gs.scenario_state [
		"profile_pointer_packet_main_tab_deck_hot"
	] = true
	gs.scenario_state [
		"profile_pointer_packet_complete_destination_deck"
	] = true
	gs.scenario_state [
		"profile_pointer_packet_optional_support_hot"
	] = bool(
		support_packet.get(
			"support_surfaces_hot",
			false
		)
	)
	gs.scenario_state [
		"profile_pointer_packet_support_packet_published"
	] = true
	gs.scenario_state [
		"profile_pointer_packet_support_packet_registry_key"
	] = actor_key
	gs.scenario_state [
		"profile_pointer_packet_ready_gate_member"
	] = false
	gs.scenario_state [
		"profile_pointer_packet_completed_at_ms"
	] = int(
		Time.get_ticks_msec()
	)
	EraLog.truth(
		"SWITCH_PACKET_PUBLISH_COMPLETE"
			+ "|actor_id=" + str(target_id)
			+ "|pointer_revision=" + pointer_revision
			+ "|profile_registry=profile_pointer_packet_by_actor"
			+ "|support_registry=resident_control_switch_support_surface_packet_by_actor"
			+ "|profile_packet_enriched=true"
			+ "|pointer_revision_replaced=false"
			+ "|complete_destination_packet_visible=true"
			+ "|authority=UniversalSwitchContractEngine"
			+ "|ready_gate_member=false"
			+ "|at_ms=" + str(Time.get_ticks_msec())
	)

	EraLog.truth(
		"COMPLETE_DESTINATION_PACKET_VISIBLE"
			+ "|actor_id=" + str(target_id)
			+ "|pointer_revision=" + pointer_revision
			+ "|core_hot=true"
			+ "|main_tab_surface_deck_hot=true"
			+ "|support_packet_hot=true"
			+ "|switch_authority=UniversalSwitchContractEngine"
			+ "|build_on_press=false"
			+ "|ready_gate_member=false"
			+ "|at_ms=" + str(Time.get_ticks_msec())
	)
	EraLog.truth(
		"PROFILE_SWITCH_DESTINATION_PACKET_PUBLISHED"
		+ "|actor_id=" + str(target_id)
		+ "|pointer_revision=" + pointer_revision
		+ "|main_tab_surface_deck_hot=true"
		+ "|support_packet_registry=resident_control_switch_support_surface_packet_by_actor"
		+ "|support_packet_published=true"
		+ "|pointer_only_packet=false"
		+ "|switch_authority=true"
		+ "|switch_blocks_on_optional_support=false"
		+ "|build_on_press=false"
		+ "|ready_gate_member=false"
		+ "|at_ms=" + str(Time.get_ticks_msec())
	)

	return {
		"success": true,
		"mode": (
			"profile_switch_actor_lens_core_prewarmed"
		),
		"actor_id": target_id,
		"pointer_revision": pointer_revision,
		"surface_contract": (
			pointer_surface.duplicate(false)
		),
		"viewer_packet": (
			pointer_packet.duplicate(false)
		),
		"main_tab_surface_contracts": (
			main_tab_deck.duplicate(false)
		),
		"control_switch_support_surface_packet": (
			support_packet.duplicate(false)
		),
		"control_switch_support_surface_packet_published": true,
		"main_tab_surface_deck_hot": true,
		"support_main_tab_deck_hot": true,
		"optional_support_surfaces_hot": bool(
			support_packet.get(
				"support_surfaces_hot",
				false
			)
		),
		"switch_press_build_forbidden": true,
		"visible_click_work_required": false,
		"ready_gate_member": false,
		"ui_is_renderer_only": true
	}
func _crown_switch_support_contract_is_hot(
	contract: Dictionary,
	actor_id: int,
	crown_expected: bool
) -> bool:
	if not crown_expected:
		return true

	if (
		contract.is_empty()
		or not bool(
			contract.get(
				"success",
				false
			)
		)
		or str(
			contract.get(
				"schema",
				""
			)
		).strip_edges() != "eralife.crown_hub_contract"
		or int(
			contract.get(
				"actor_id",
				-1
			)
		) != actor_id
	):
		return false

	var summary: Dictionary = _shallow_dictionary(
		contract.get(
			"summary",
			{}
		)
	)
	var permissions: Dictionary = _shallow_dictionary(
		contract.get(
			"permissions",
			{}
		)
	)
	var section_tabs: Array = _safe_array(
		contract.get(
			"section_tabs",
			[]
		)
	)
	var section_surfaces: Dictionary = _shallow_dictionary(
		contract.get(
			"section_surfaces",
			{}
		)
	)
	var throne_rows: Array = _safe_array(
		section_surfaces.get(
			"throne",
			[]
		)
	)
	var surface_revision: String = str(
		contract.get(
			"surface_revision",
			""
		)
	).strip_edges()

	return (
		not summary.is_empty()
		and not permissions.is_empty()
		and not section_tabs.is_empty()
		and not section_surfaces.is_empty()
		and not throne_rows.is_empty()
		and surface_revision != ""
	)
func _control_switch_support_surface_packet_for_actor(
	target: Person,
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	if gs == null:
		return {
			"success": false,
			"reason": "missing_game_state",
			"support_surfaces_hot": false
		}

	if target == null:
		return {
			"success": false,
			"reason": "missing_target",
			"support_surfaces_hot": false
		}

	var target_id: int = int(
		target.id
	)

	if target_id <= 0:
		return {
			"success": false,
			"reason": "invalid_target_id",
			"support_surfaces_hot": false
		}

	var source: String = (
		"universal_switch_contract_engine."
		+ "control_switch_support_surface_packet"
	)
	var relationships_contract: Dictionary = {}
	var school_contract: Dictionary = {}
	var activities_contract: Dictionary = {}
	var career_contract: Dictionary = {}
	var mods_contract: Dictionary = {}
	var crown_contract: Dictionary = {}
	var crime_contract: Dictionary = {}
	var pet_shop_contract: Dictionary = {}
	var pending_situations_payload: Dictionary = {}

	if (
		gs.relationships_hub_contract_engine != null
		and gs.relationships_hub_contract_engine.has_method(
			"emit_hub_contract"
		)
	):
		relationships_contract = _shallow_dictionary(
			gs.relationships_hub_contract_engine.emit_hub_contract(
				target,
				{
					"active_section_id": "family",
					"force_refresh": false,
					"source": source,
					"resident_projection": true,
					"cooperative_projection": true,
					"projection_read_only": true,
					"publish_card_shell_to_scenario": false,
					"build_on_click_forbidden": true,
					"switch_press_build_forbidden": true,
					"ready_gate_member": false,
					"ui_is_renderer_only": true
				}
			)
		)

	if (
		gs.school_hub_contract_engine != null
		and gs.school_hub_contract_engine.has_method(
			"emit_hub_contract"
		)
	):
		school_contract = _shallow_dictionary(
			gs.school_hub_contract_engine.emit_hub_contract(
				target,
				{
					"active_section_id": "overview",
					"force_refresh": false,
					"source": source,
					"resident_projection": true,
					"projection_read_only": true,
					"build_on_click_forbidden": true,
					"switch_press_build_forbidden": true,
					"ready_gate_member": false,
					"ui_is_renderer_only": true
				}
			)
		)

	if (
		gs.activities_hub_contract_engine != null
		and gs.activities_hub_contract_engine.has_method(
			"emit_hub_contract"
		)
	):
		activities_contract = _shallow_dictionary(
			gs.activities_hub_contract_engine.emit_hub_contract(
				target,
				{
					"active_section": "all",
					"force_refresh": false,
					"source": source,
					"resident_projection": true,
					"prewarm_only": true,
					"read_only": true,
					"build_on_click_forbidden": true,
					"visible_click_work_forbidden": true,
					"switch_press_build_forbidden": true,
					"ready_gate_member": false,
					"ui_is_renderer_only": true
				}
			)
		)

	if (
		gs.career_hub_contract_engine != null
		and gs.career_hub_contract_engine.has_method(
			"resolve_career_hub"
		)
	):
		career_contract = _shallow_dictionary(
			gs.career_hub_contract_engine.resolve_career_hub(
				target,
				{
					"active_section": "overview",
					"career_lane": "full_time",
					"force_refresh": false,
					"source": source,
					"resident_projection": true,
					"build_on_click_forbidden": true,
					"switch_press_build_forbidden": true,
					"ready_gate_member": false,
					"ui_is_expression_only": true
				}
			)
		)

	if (
		gs.mod_menu_contract_engine != null
		and gs.mod_menu_contract_engine.has_method(
			"emit_menu_contract"
		)
	):
		mods_contract = _shallow_dictionary(
			gs.mod_menu_contract_engine.emit_menu_contract(
				target,
				{
					"active_section": "bundles",
					"force_refresh": false,
					"surface_mode": "global_hub",
					"source": source,
					"resident_projection": true,
					"default_reality_bundle_id": (
						"caveman_reality_pack"
					),
					"section_press_reveal_only": true,
					"build_on_click_forbidden": true,
					"switch_press_build_forbidden": true,
					"ready_gate_member": false,
					"ui_is_expression_only": true
				}
			)
		)

	var hud_truth: Dictionary = _surface_hud_truth_for_actor(
		target
	)
	var crown_expected: bool = bool(
		hud_truth.get(
			"crown_available",
			false
		)
	)

	if (
		crown_expected
		and gs.crown_hub_contract_engine != null
		and gs.crown_hub_contract_engine.has_method(
			"emit_crown_hub_contract"
		)
	):
		crown_contract = _shallow_dictionary(
			gs.crown_hub_contract_engine.emit_crown_hub_contract(
				target,
				{
					"active_section": "throne",
					"section_id": "throne",
					"source": source,
					"prewarm_only": true,
					"read_only": true,
					"visible_click_work_forbidden": true,
					"switch_press_build_forbidden": true,
					"ready_gate_member": false,
					"ui_is_renderer_only": true
				}
			)
		)

	if (
		gs.crime_hub_contract_engine != null
		and gs.crime_hub_contract_engine.has_method(
			"emit_hub_contract"
		)
	):
		crime_contract = _shallow_dictionary(
			gs.crime_hub_contract_engine.emit_hub_contract(
				target,
				"overview",
				{
					"refresh_all_sections": true,
					"refresh_sections": [],
					"active_section_only": false,
					"remaining_sections_are_resident_shells": false,
					"all_sections_precomposed": true,
					"source": source,
					"prewarm_only": true,
					"read_only": true,
					"visible_click_work_forbidden": true,
					"switch_press_build_forbidden": true,
					"ready_gate_member": false,
					"ui_is_renderer_only": true
				}
			)
		)

	if (
		gs.pet_shop_contract_engine != null
		and gs.pet_shop_contract_engine.has_method(
			"emit_shop_surface_contract"
		)
	):
		pet_shop_contract = _shallow_dictionary(
			gs.pet_shop_contract_engine.emit_shop_surface_contract(
				target,
				{
					"source": source,
					"prewarm_only": true,
					"read_only": true,
					"visible_click_work_forbidden": true,
					"switch_press_build_forbidden": true,
					"ready_gate_member": false,
					"ui_is_renderer_only": true
				}
			)
		)

	if (
		gs.pending_situations_engine != null
		and gs.pending_situations_engine.has_method(
			"build_pending_list_payload"
		)
	):
		pending_situations_payload = _shallow_dictionary(
			gs.pending_situations_engine.build_pending_list_payload(
				target_id
			)
		)

	if pending_situations_payload.is_empty():
		pending_situations_payload = {
			"success": true,
			"schema": "eralife.pending_situations.empty_actor_payload",
			"version": CONTRACT_VERSION,
			"actor_id": target_id,
			"actor_name": (
				_actor_display_name(
					target
				)
			),
			"count": 0,
			"contracts": [],
			"category_groups": [],
			"dominant_category": "none",
			"truth_state": "hot",
			"ui_is_renderer_only": true
		}

	pending_situations_payload ["success"] = bool(
		pending_situations_payload.get(
			"success",
			true
		)
	)
	pending_situations_payload ["actor_id"] = target_id
	pending_situations_payload ["actor_name"] = (
		_actor_display_name(
			target
		)
	)
	pending_situations_payload ["prewarmed"] = true
	pending_situations_payload [
		"visible_click_work_required"
	] = false
	pending_situations_payload [
		"switch_press_build_forbidden"
	] = true
	pending_situations_payload ["ready_gate_member"] = false
	pending_situations_payload ["truth_state"] = "hot"
	pending_situations_payload ["ui_is_renderer_only"] = true

	var asset_context: Dictionary = {
		"source": source,
		"prewarm_only": true,
		"read_only": true,
		"visible_click_work_forbidden": true,
		"switch_press_build_forbidden": true,
		"ready_gate_member": false,
		"ui_is_renderer_only": true
	}
	var asset_surface_pack: Dictionary = {}

	if gs.assets_contract_engine != null:
		if gs.assets_contract_engine.has_method(
			"cached_surface_pack_for_actor"
		):
			asset_surface_pack = _shallow_dictionary(
				gs.assets_contract_engine.cached_surface_pack_for_actor(
					target,
					asset_context
				)
			)

		var cached_asset_pack_hot: bool = (
			bool(
				asset_surface_pack.get(
					"success",
					false
				)
			)
			and int(
				asset_surface_pack.get(
					"actor_id",
					-1
				)
			) == target_id
			and not _shallow_dictionary(
				asset_surface_pack.get(
					"assets_surface_contract",
					{}
				)
			).is_empty()
			and not _shallow_dictionary(
				asset_surface_pack.get(
					"property_market_surface_contract",
					{}
				)
			).is_empty()
			and not _shallow_dictionary(
				asset_surface_pack.get(
					"vehicle_market_surface_contract",
					{}
				)
			).is_empty()
		)

		if (
			not cached_asset_pack_hot
			and gs.assets_contract_engine.has_method(
				"prewarm_actor_surface_pack"
			)
		):
			asset_surface_pack = _shallow_dictionary(
				gs.assets_contract_engine.prewarm_actor_surface_pack(
					target,
					asset_context
				)
			)

		var assets_contract_for_spaces: Dictionary = _shallow_dictionary(
			asset_surface_pack.get(
				"assets_surface_contract",
				{}
			)
		)
		var property_rows: Array = _safe_array(
			assets_contract_for_spaces.get(
				"property_asset_rows",
				[]
			)
		)

		if gs.assets_contract_engine.has_method(
			"prewarm_property_space_surface_for_actor"
		):
			for raw_prewarm_property_row in property_rows:
				var prewarm_property_row: Dictionary = _shallow_dictionary(
					raw_prewarm_property_row
				)
				var property_id: int = int(
					prewarm_property_row.get(
						"asset_id",
						prewarm_property_row.get(
							"property_id",
							prewarm_property_row.get(
								"id",
								-1
							)
						)
					)
				)

				if property_id <= 0:
					continue

				gs.assets_contract_engine.prewarm_property_space_surface_for_actor(
					target,
					{
						"actor_id": target_id,
						"property_owner_id": int(
							prewarm_property_row.get(
								"owner_id",
								target_id
							)
						),
						"property_id": property_id,
						"source": source,
						"prewarm_only": true,
						"read_only": true,
						"visible_click_work_forbidden": true,
						"switch_press_build_forbidden": true,
						"ready_gate_member": false,
						"ui_is_renderer_only": true
					}
				)

			if gs.assets_contract_engine.has_method(
				"cached_surface_pack_for_actor"
			):
				asset_surface_pack = _shallow_dictionary(
					gs.assets_contract_engine.cached_surface_pack_for_actor(
						target,
						asset_context
					)
				)

	var relationships_hot: bool = (
		not relationships_contract.is_empty()
		and int(
			relationships_contract.get(
				"actor_id",
				-1
			)
		) == target_id
	)
	var school_hot: bool = (
		not school_contract.is_empty()
		and int(
			school_contract.get(
				"actor_id",
				-1
			)
		) == target_id
	)
	var activities_hot: bool = (
		bool(
			activities_contract.get(
				"success",
				false
			)
		)
		and int(
			activities_contract.get(
				"actor_id",
				-1
			)
		) == target_id
	)
	var career_hot: bool = (
		not career_contract.is_empty()
		and int(
			career_contract.get(
				"actor_id",
				-1
			)
		) == target_id
	)
	var mods_hot: bool = (
		not mods_contract.is_empty()
		and int(
			mods_contract.get(
				"actor_id",
				-1
			)
		) == target_id
	)
	var assets_hot: bool = (
		bool(
			asset_surface_pack.get(
				"success",
				false
			)
		)
		and int(
			asset_surface_pack.get(
				"actor_id",
				-1
			)
		) == target_id
		and not _shallow_dictionary(
			asset_surface_pack.get(
				"assets_surface_contract",
				{}
			)
		).is_empty()
		and not _shallow_dictionary(
			asset_surface_pack.get(
				"property_market_surface_contract",
				{}
			)
		).is_empty()
		and not _shallow_dictionary(
			asset_surface_pack.get(
				"vehicle_market_surface_contract",
				{}
			)
		).is_empty()
	)
	var property_rows_for_hot_check: Array = _safe_array(
		_shallow_dictionary(
			asset_surface_pack.get(
				"assets_surface_contract",
				{}
			)
		).get(
			"property_asset_rows",
			[]
		)
	)
	var property_spaces_by_id: Dictionary = _shallow_dictionary(
		asset_surface_pack.get(
			"property_space_surface_contracts_by_id",
			{}
		)
	)
	var property_spaces_hot: bool = true

	for raw_validation_property_row in property_rows_for_hot_check:
		var validation_property_row: Dictionary = _shallow_dictionary(
			raw_validation_property_row
		)
		var required_property_id: int = int(
			validation_property_row.get(
				"asset_id",
				validation_property_row.get(
					"property_id",
					validation_property_row.get(
						"id",
						-1
					)
				)
			)
		)

		if (
			required_property_id > 0
			and not property_spaces_by_id.has(
				str(required_property_id)
			)
		):
			property_spaces_hot = false
			break

	var crown_hot: bool = (
		_crown_switch_support_contract_is_hot(
			crown_contract,
			target_id,
			crown_expected
		)
	)
	var crime_hot: bool = (
		str(
			crime_contract.get(
				"schema",
				""
			)
		) == "eralife.crime_hub_contract"
		and int(
			crime_contract.get(
				"actor_id",
				-1
			)
		) == target_id
		and not _shallow_dictionary(
			crime_contract.get(
				"section_surfaces",
				{}
			)
		).is_empty()
	)
	var pet_hot: bool = (
		bool(
			pet_shop_contract.get(
				"success",
				false
			)
		)
		and int(
			pet_shop_contract.get(
				"actor_id",
				-1
			)
		) == target_id
	)
	var pending_hot: bool = (
		bool(
			pending_situations_payload.get(
				"success",
				false
			)
		)
		and int(
			pending_situations_payload.get(
				"actor_id",
				-1
			)
		) == target_id
	)
	var main_tab_surfaces_hot: bool = (
		relationships_hot
		and school_hot
		and activities_hot
		and career_hot
		and mods_hot
	)
	var support_surfaces_hot: bool = (
		main_tab_surfaces_hot
		and assets_hot
		and property_spaces_hot
		and crown_hot
		and crime_hot
		and pet_hot
		and pending_hot
	)
	var main_tab_surface_contracts: Dictionary = {
		"relationships": relationships_contract.duplicate(false),
		"school": school_contract.duplicate(false),
		"activities": activities_contract.duplicate(false),
		"career": career_contract.duplicate(false),
		"mods": mods_contract.duplicate(false),
		"crown": crown_contract.duplicate(false),
		"crime": crime_contract.duplicate(false),
		"pet_shop": pet_shop_contract.duplicate(false),
		"pending_situations": (
			pending_situations_payload.duplicate(false)
		)
	}
	var support_revision: String = (
		"%d:%d:%d:%s:%s:%s:%s:%s:%s"
		% [
			target_id,
			int(gs.year),
			int(target.age),
			str(hash(main_tab_surface_contracts)),
			str(
				asset_surface_pack.get(
					"surface_signature",
					hash(asset_surface_pack)
				)
			),
			str(hash(crown_contract)),
			str(hash(crime_contract)),
			str(hash(pet_shop_contract)),
			str(hash(pending_situations_payload))
		]
	)

	return {
		"success": support_surfaces_hot,
		"schema": "eralife.control_switch.support_surface_packet",
		"version": CONTRACT_VERSION,
		"actor_id": target_id,
		"actor_name": _actor_display_name(target),
		"main_tab_surface_contracts": (
			main_tab_surface_contracts.duplicate(false)
		),
		"relationships_hub_contract": (
			relationships_contract.duplicate(false)
		),
		"school_hub_contract": (
			school_contract.duplicate(false)
		),
		"activities_hub_contract": (
			activities_contract.duplicate(false)
		),
		"career_hub_contract": (
			career_contract.duplicate(false)
		),
		"mod_menu_contract": (
			mods_contract.duplicate(false)
		),
		"crown_hub_contract": (
			crown_contract.duplicate(false)
		),
		"crime_hub_contract": (
			crime_contract.duplicate(false)
		),
		"pet_shop_surface_contract": (
			pet_shop_contract.duplicate(false)
		),
		"pending_situations_payload": (
			pending_situations_payload.duplicate(false)
		),
		"asset_surface_pack": (
			asset_surface_pack.duplicate(false)
		),
		"assets_surface_contract": _shallow_dictionary(
			asset_surface_pack.get(
				"assets_surface_contract",
				{}
			)
		),
		"property_market_surface_contract": _shallow_dictionary(
			asset_surface_pack.get(
				"property_market_surface_contract",
				{}
			)
		),
		"vehicle_market_surface_contract": _shallow_dictionary(
			asset_surface_pack.get(
				"vehicle_market_surface_contract",
				{}
			)
		),
		"vehicle_market_surface_deck": _shallow_dictionary(
			asset_surface_pack.get(
				"vehicle_market_surface_deck",
				{}
			)
		),
		"property_space_surface_contracts_by_id": (
			property_spaces_by_id.duplicate(false)
		),
		"relationships_surface_hot": relationships_hot,
		"school_surface_hot": school_hot,
		"activities_surface_hot": activities_hot,
		"career_surface_hot": career_hot,
		"mods_surface_hot": mods_hot,
		"main_tab_surface_deck_hot": main_tab_surfaces_hot,
		"asset_surface_pack_hot": assets_hot,
		"property_space_surface_deck_hot": property_spaces_hot,
		"crown_surface_expected": crown_expected,
		"crown_surface_hot": crown_hot,
		"crime_surface_hot": crime_hot,
		"pet_shop_surface_hot": pet_hot,
		"pending_situations_surface_hot": pending_hot,
		"support_surfaces_hot": support_surfaces_hot,
		"support_revision": support_revision,
		"switch_press_build_forbidden": true,
		"visible_click_work_required": false,
		"ready_gate_member": false,
		"ui_is_renderer_only": true,
		"created_at_ms": int(
			Time.get_ticks_msec()
		),
		"context": context.duplicate(false)
	}
func publish_resident_control_switch_support_surface_packet_from_deck(
	target: Person,
	main_tab_surface_contracts: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	if gs == null:
		return {
			"success": false,
			"reason": "missing_game_state",
			"main_tab_surface_deck_hot": false,
			"ready_gate_member": false
		}

	if target == null:
		return {
			"success": false,
			"reason": "missing_target",
			"main_tab_surface_deck_hot": false,
			"ready_gate_member": false
		}

	var target_id: int = int(
		target.id
	)

	if target_id <= 0:
		return {
			"success": false,
			"reason": "invalid_target_id",
			"main_tab_surface_deck_hot": false,
			"ready_gate_member": false
		}

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var real_main_tab_deck: Dictionary = {}
	var missing_tabs: Array = []
	var pointer_only_tabs: Array = []

	for raw_tab_id in [
		"relationships",
		"school",
		"activities",
		"career",
		"mods"
	]:
		var tab_id: String = str(
			raw_tab_id
		)
		var raw_contract: Variant = main_tab_surface_contracts.get(
			tab_id,
			{}
		)
		var tab_contract: Dictionary = (
			(raw_contract as Dictionary).duplicate(false)
			if typeof(raw_contract) == TYPE_DICTIONARY
			else {}
		)

		if (
			tab_contract.is_empty()
			or int(
				tab_contract.get(
					"actor_id",
					-1
				)
			) != target_id
		):
			missing_tabs.append(
				tab_id
			)
			continue

		var schema: String = str(
			tab_contract.get(
				"schema",
				""
			)
		).strip_edges().to_lower()
		var truth_state: String = str(
			tab_contract.get(
				"truth_state",
				""
			)
		).strip_edges().to_lower()

		if (
			schema == "eralife.pointer_only.destination_tab_contract"
			or truth_state == "pointer_only_resident_shell"
			or bool(
				tab_contract.get(
					"pointer_only",
					false
				)
			)
		):
			pointer_only_tabs.append(
				tab_id
			)
			continue

		real_main_tab_deck [
			tab_id
		] = tab_contract

	if (
		not missing_tabs.is_empty()
		or not pointer_only_tabs.is_empty()
		or real_main_tab_deck.size() != 5
	):
		return {
			"success": false,
			"reason": "resident_main_tab_surface_deck_not_hot",
			"actor_id": target_id,
			"missing_tabs": missing_tabs,
			"pointer_only_tabs": pointer_only_tabs,
			"main_tab_surface_deck_hot": false,
			"switch_commit_blocked_by_support_deck": false,
			"ready_gate_member": false
		}

	var actor_key: String = str(
		target_id
	)
	var registry_raw: Variant = gs.scenario_state.get(
		"resident_control_switch_support_surface_packet_by_actor",
		{}
	)
	var observable_registry_raw: Variant = gs.scenario_state.get(
		"observable_control_switch_support_surface_packet_by_actor",
		{}
	)
	var registry: Dictionary = (
		(registry_raw as Dictionary).duplicate(false)
		if typeof(registry_raw) == TYPE_DICTIONARY
		else {}
	)
	var observable_registry: Dictionary = (
		(observable_registry_raw as Dictionary).duplicate(false)
		if typeof(observable_registry_raw) == TYPE_DICTIONARY
		else {}
	)
	var existing_packet_raw: Variant = registry.get(
		actor_key,
		observable_registry.get(
			actor_key,
			{}
		)
	)
	var existing_packet: Dictionary = (
		(existing_packet_raw as Dictionary).duplicate(false)
		if typeof(existing_packet_raw) == TYPE_DICTIONARY
		else {}
	)
	var pending_payload_raw: Variant = context.get(
		"pending_situations_payload",
		existing_packet.get(
			"pending_situations_payload",
			{}
		)
	)
	var pending_situations_payload: Dictionary = (
		(pending_payload_raw as Dictionary).duplicate(false)
		if typeof(pending_payload_raw) == TYPE_DICTIONARY
		else {}
	)

	if (
		pending_situations_payload.is_empty()
		and gs.pending_situations_engine != null
		and gs.pending_situations_engine.has_method(
			"build_pending_list_payload"
		)
	):
		pending_situations_payload = _shallow_dictionary(
			gs.pending_situations_engine.build_pending_list_payload(
				target_id
			)
		)

	if pending_situations_payload.is_empty():
		pending_situations_payload = {
			"success": true,
			"schema": "eralife.pending_situations.empty_actor_payload",
			"version": CONTRACT_VERSION,
			"actor_id": target_id,
			"actor_name": _actor_display_name(
				target
			),
			"count": 0,
			"contracts": [],
			"category_groups": [],
			"dominant_category": "none",
			"truth_state": "hot",
			"ui_is_renderer_only": true
		}

	pending_situations_payload ["success"] = bool(
		pending_situations_payload.get(
			"success",
			true
		)
	)
	pending_situations_payload ["actor_id"] = target_id
	pending_situations_payload ["actor_name"] = _actor_display_name(
		target
	)
	pending_situations_payload ["prewarmed"] = true
	pending_situations_payload ["visible_click_work_required"] = false
	pending_situations_payload ["switch_press_build_forbidden"] = true
	pending_situations_payload ["ready_gate_member"] = false
	pending_situations_payload ["truth_state"] = "hot"
	pending_situations_payload ["ui_is_renderer_only"] = true

	var complete_deck: Dictionary = real_main_tab_deck.duplicate(false)
	complete_deck ["pending_situations"] = (
		pending_situations_payload.duplicate(false)
	)

	for optional_deck_key in [
		"crown",
		"crime",
		"pet_shop"
	]:
		var optional_contract_raw: Variant = _shallow_dictionary(
			existing_packet.get(
				"main_tab_surface_contracts",
				{}
			)
		).get(
			optional_deck_key,
			{}
		)

		if typeof(optional_contract_raw) == TYPE_DICTIONARY:
			complete_deck [optional_deck_key] = (
				(optional_contract_raw as Dictionary).duplicate(false)
			)

	var support_revision: String = (
		"%d:%d:%d:%s:%s"
		% [
			target_id,
			int(gs.year),
			int(target.age),
			str(hash(real_main_tab_deck)),
			str(hash(pending_situations_payload))
		]
	)
	var packet: Dictionary = existing_packet.duplicate(false)

	packet ["success"] = true
	packet ["schema"] = "eralife.control_switch.support_surface_packet"
	packet ["version"] = CONTRACT_VERSION
	packet ["actor_id"] = target_id
	packet ["actor_name"] = _actor_display_name(
		target
	)
	packet ["main_tab_surface_contracts"] = complete_deck.duplicate(false)
	packet ["relationships_hub_contract"] = _shallow_dictionary(
		real_main_tab_deck.get(
			"relationships",
			{}
		)
	)
	packet ["school_hub_contract"] = _shallow_dictionary(
		real_main_tab_deck.get(
			"school",
			{}
		)
	)
	packet ["activities_hub_contract"] = _shallow_dictionary(
		real_main_tab_deck.get(
			"activities",
			{}
		)
	)
	packet ["career_hub_contract"] = _shallow_dictionary(
		real_main_tab_deck.get(
			"career",
			{}
		)
	)
	packet ["mod_menu_contract"] = _shallow_dictionary(
		real_main_tab_deck.get(
			"mods",
			{}
		)
	)
	packet ["pending_situations_payload"] = (
		pending_situations_payload.duplicate(false)
	)
	packet ["relationships_surface_hot"] = true
	packet ["school_surface_hot"] = true
	packet ["activities_surface_hot"] = true
	packet ["career_surface_hot"] = true
	packet ["mods_surface_hot"] = true
	packet ["main_tab_surface_deck_hot"] = true
	packet ["pending_situations_surface_hot"] = true
	packet ["support_surfaces_hot"] = bool(
		packet.get(
			"support_surfaces_hot",
			false
		)
	)
	packet ["support_revision"] = support_revision
	packet ["switch_press_build_forbidden"] = true
	packet ["visible_click_work_required"] = false
	packet ["switch_commit_blocked_by_support_deck"] = false
	packet ["ready_gate_member"] = false
	packet ["ui_is_renderer_only"] = true
	packet ["created_at_ms"] = int(
		Time.get_ticks_msec()
	)
	packet ["context"] = context.duplicate(false)

	registry [actor_key] = packet.duplicate(false)
	observable_registry [actor_key] = packet.duplicate(false)

	gs.scenario_state [
		"resident_control_switch_support_surface_packet_by_actor"
	] = registry
	gs.scenario_state [
		"observable_control_switch_support_surface_packet_by_actor"
	] = observable_registry

	var pending_registry_raw: Variant = gs.scenario_state.get(
		"resident_pending_situations_payload_by_actor",
		{}
	)
	var pending_registry: Dictionary = (
		(pending_registry_raw as Dictionary).duplicate(false)
		if typeof(pending_registry_raw) == TYPE_DICTIONARY
		else {}
	)

	pending_registry [actor_key] = pending_situations_payload.duplicate(false)

	gs.scenario_state [
		"resident_pending_situations_payload_by_actor"
	] = pending_registry

	var profile_cache_raw: Variant = gs.scenario_state.get(
		"profile_pointer_packet_by_actor",
		{}
	)
	var profile_cache: Dictionary = (
		(profile_cache_raw as Dictionary).duplicate(false)
		if typeof(profile_cache_raw) == TYPE_DICTIONARY
		else {}
	)
	var profile_packet_raw: Variant = profile_cache.get(
		actor_key,
		{}
	)
	var profile_packet: Dictionary = (
		(profile_packet_raw as Dictionary).duplicate(false)
		if typeof(profile_packet_raw) == TYPE_DICTIONARY
		else {}
	)

	if not profile_packet.is_empty():
		var surface_raw: Variant = profile_packet.get(
			"surface_contract",
			{}
		)
		var surface: Dictionary = (
			(surface_raw as Dictionary).duplicate(false)
			if typeof(surface_raw) == TYPE_DICTIONARY
			else {}
		)

		profile_packet ["main_tab_surface_contracts"] = (
			complete_deck.duplicate(false)
		)
		profile_packet [
			"control_switch_support_surface_packet"
		] = packet.duplicate(false)
		profile_packet ["main_tab_surface_deck_hot"] = true
		profile_packet [
			"control_switch_support_surfaces_hot"
		] = bool(
			packet.get(
				"support_surfaces_hot",
				false
			)
		)
		profile_packet ["support_revision"] = support_revision
		profile_packet [
			"pointer_packet_enriched_without_revision_replacement"
		] = true
		profile_packet [
			"switch_commit_blocked_by_support_deck"
		] = false

		if not surface.is_empty():
			surface ["main_tab_surface_contracts"] = (
				complete_deck.duplicate(false)
			)
			surface [
				"control_switch_support_surface_packet"
			] = packet.duplicate(false)
			surface ["main_tab_surface_deck_hot"] = true
			surface ["support_revision"] = support_revision
			surface [
				"pointer_revision_stable_across_surface_enrichment"
			] = true
			profile_packet ["surface_contract"] = surface

		profile_cache [actor_key] = profile_packet

		gs.scenario_state [
			"profile_pointer_packet_by_actor"
		] = profile_cache

	gs.scenario_state [
		"resident_control_switch_support_surface_packet_last_actor_id"
	] = target_id
	gs.scenario_state [
		"resident_control_switch_support_surface_packet_last_real_main_tab_count"
	] = 5
	gs.scenario_state [
		"resident_control_switch_support_surface_packet_published_at_ms"
	] = int(
		Time.get_ticks_msec()
	)
	gs.scenario_state [
		"resident_control_switch_support_surface_packet_ready_gate_member"
	] = false
	gs.scenario_state [
		"resident_control_switch_support_surface_packet_click_path_member"
	] = false

	EraLog.truth(
		"SUPPORT_PACKET_PUBLISHED"
		+ "|actor_id=" + str(target_id)
		+ "|success=true"
		+ "|real_main_tabs=5"
		+ "|pointer_only_tabs=[]"
		+ "|main_tab_surface_deck_hot=true"
		+ "|pending_situations_hot=true"
		+ "|registry=resident_control_switch_support_surface_packet_by_actor"
		+ "|observable=true"
		+ "|pointer_revision_replaced=false"
		+ "|switch_authority=false"
		+ "|ready_gate_member=false"
		+ "|build_on_click=false"
		+ "|at_ms=" + str(Time.get_ticks_msec())
	)

	return packet
func prewarm_control_switch_support_surface_packet(
	target: Person,
	payload: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	var packet: Dictionary = (
		_control_switch_support_surface_packet_for_actor(
			target,
			payload
		)
	)
	if (
		gs != null
		and target != null
		and int(
			target.id
		) > 0
		and gs.crime_contract_engine != null
		and gs.crime_contract_engine.has_method(
			"queue_crime_target_cache_refresh"
		)
	):






		gs.crime_contract_engine.queue_crime_target_cache_refresh(
			target,
			"control_switch_support_crime_target_residency"
		)
	if (
		gs == null
		or target == null
		or int(target.id) <= 0
	):
		return packet

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var actor_id: int = int(target.id)
	var actor_key: String = str(actor_id)
	var main_tab_deck: Dictionary = _shallow_dictionary(
		packet.get(
			"main_tab_surface_contracts",
			{}
		)
	)
	var real_main_tab_count: int = 0
	var pointer_only_tabs: Array = []

	for raw_tab_id in [
		"relationships",
		"school",
		"activities",
		"career",
		"mods"
	]:
		var tab_id: String = str(raw_tab_id)
		var tab_contract: Dictionary = _shallow_dictionary(
			main_tab_deck.get(
				tab_id,
				{}
			)
		)

		if tab_contract.is_empty():
			continue

		var tab_schema: String = str(
			tab_contract.get(
				"schema",
				""
			)
		).strip_edges().to_lower()
		var tab_truth_state: String = str(
			tab_contract.get(
				"truth_state",
				""
			)
		).strip_edges().to_lower()

		if (
			tab_schema == "eralife.pointer_only.destination_tab_contract"
			or tab_truth_state == "pointer_only_resident_shell"
			or bool(
				tab_contract.get(
					"pointer_only",
					false
				)
			)
		):
			pointer_only_tabs.append(
				tab_id
			)
			continue

		if int(
			tab_contract.get(
				"actor_id",
				-1
			)
		) == actor_id:
			real_main_tab_count += 1

	var registry: Dictionary = _shallow_dictionary(
		gs.scenario_state.get(
			"resident_control_switch_support_surface_packet_by_actor",
			{}
		)
	)
	var observable_registry: Dictionary = _shallow_dictionary(
		gs.scenario_state.get(
			"observable_control_switch_support_surface_packet_by_actor",
			{}
		)
	)

	registry [
		actor_key
	] = packet.duplicate(false)
	observable_registry [
		actor_key
	] = packet.duplicate(false)

	gs.scenario_state [
		"resident_control_switch_support_surface_packet_by_actor"
	] = registry
	gs.scenario_state [
		"observable_control_switch_support_surface_packet_by_actor"
	] = observable_registry
	gs.scenario_state [
		"resident_control_switch_support_surface_packet_last_actor_id"
	] = actor_id
	gs.scenario_state [
		"resident_control_switch_support_surface_packet_last_real_main_tab_count"
	] = real_main_tab_count
	gs.scenario_state [
		"resident_control_switch_support_surface_packet_last_pointer_only_tabs"
	] = pointer_only_tabs.duplicate(false)
	gs.scenario_state [
		"resident_control_switch_support_surface_packet_published_at_ms"
	] = int(
		Time.get_ticks_msec()
	)
	gs.scenario_state [
		"resident_control_switch_support_surface_packet_ready_gate_member"
	] = false
	gs.scenario_state [
		"resident_control_switch_support_surface_packet_click_path_member"
	] = false

	EraLog.truth(
		"SUPPORT_PACKET_PUBLISHED"
		+ "|actor_id=" + str(actor_id)
		+ "|success="
		+ str(
			bool(
				packet.get(
					"success",
					false
				)
			)
		).to_lower()
		+ "|real_main_tabs=" + str(real_main_tab_count)
		+ "|pointer_only_tabs=" + str(pointer_only_tabs)
		+ "|main_tab_surface_deck_hot="
		+ str(
			bool(
				packet.get(
					"main_tab_surface_deck_hot",
					false
				)
			)
		).to_lower()
		+ "|support_surfaces_hot="
		+ str(
			bool(
				packet.get(
					"support_surfaces_hot",
					false
				)
			)
		).to_lower()
		+ "|registry=resident_control_switch_support_surface_packet_by_actor"
		+ "|observable=true"
		+ "|ready_gate_member=false"
		+ "|build_on_click=false"
		+ "|at_ms=" + str(Time.get_ticks_msec())
	)

	return packet
func prewarm_zero_frame_surface_for_actor(
	target: Person,
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()
	if gs == null:
		return {
			"success": false,
			"reason": "missing_game_state"
		}
	if target == null:
		return {
			"success": false,
			"reason": "missing_target"
		}

	var target_id: int = int(
		target.id
	)
	if target_id <= 0:
		return {
			"success": false,
			"reason": "invalid_target_id"
		}

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var prewarm_context: Dictionary = (
		context.duplicate(false)
	)
	prewarm_context ["source"] = str(
		context.get(
			"source",
			"zero_frame_surface_prewarm"
		)
	)
	prewarm_context ["surface_first"] = true
	prewarm_context ["prewarm_only"] = true
	prewarm_context ["press_frame_ready"] = true
	prewarm_context [
		"switch_press_must_not_build_surface"
	] = true
	prewarm_context ["skip_pending_count"] = bool(
		context.get(
			"skip_pending_count",
			false
		)
	)
	prewarm_context ["skip_press_frame_refresh"] = true
	prewarm_context ["ready_gate_member"] = false
	prewarm_context [
		"pointer_revision_must_remain_stable_during_enrichment"
	] = true
	prewarm_context.erase(
		"pointer_revision"
	)

	var pointer_packet: Dictionary = (
		prepare_profile_pointer_packet(
			target,
			prewarm_context
		)
	)

	if not bool(
		pointer_packet.get(
			"success",
			false
		)
	):
		return pointer_packet

	var pointer_surface: Dictionary = _shallow_dictionary(
		pointer_packet.get(
			"surface_contract",
			{}
		)
	)
	var pointer_revision: String = str(
		pointer_packet.get(
			"pointer_revision",
			pointer_surface.get(
				"pointer_revision",
				""
			)
		)
	).strip_edges()

	if pointer_revision == "":
		return {
			"success": false,
			"reason": "profile_pointer_revision_missing",
			"actor_id": target_id,
			"switch_press_build_forbidden": true,
			"ready_gate_member": false
		}

	var support_packet: Dictionary = (
		prewarm_control_switch_support_surface_packet(
			target,
			prewarm_context
		)
	)
	var support_surfaces_hot: bool = bool(
		support_packet.get(
			"support_surfaces_hot",
			false
		)
	)
	var main_tab_surface_deck_hot: bool = bool(
		support_packet.get(
			"main_tab_surface_deck_hot",
			false
		)
	)

	var surface: Dictionary = _surface_contract_for_actor(
		target,
		prewarm_context
	)

	surface [
		"control_switch_support_surface_packet"
	] = support_packet.duplicate(false)
	surface [
		"control_switch_support_surface_packet_published"
	] = true
	surface [
		"control_switch_support_packet_registry_authority"
	] = "UniversalSwitchContractEngine"
	surface [
		"control_switch_support_packet_registry_key"
	] = str(target_id)

	pointer_packet [
		"control_switch_support_surface_packet"
	] = support_packet.duplicate(false)
	pointer_packet [
		"control_switch_support_surface_packet_published"
	] = true
	pointer_packet [
		"control_switch_support_packet_registry_authority"
	] = "UniversalSwitchContractEngine"
	pointer_packet [
		"control_switch_support_packet_registry_key"
	] = str(target_id)

	gs.scenario_state [
		"profile_switch_support_packet_published_actor_id"
	] = target_id
	gs.scenario_state [
		"profile_switch_support_packet_published_revision"
	] = str(
		support_packet.get(
			"support_revision",
			""
		)
	)
	gs.scenario_state [
		"profile_switch_support_packet_published_before_switch"
	] = true
	gs.scenario_state [
		"profile_switch_support_packet_ready_gate_member"
	] = false

	EraLog.truth(
		"SUPPORT_PACKET_OBSERVABLE"
		+ "|actor_id=" + str(target_id)
		+ "|published_before_switch=true"
		+ "|main_tab_surface_deck_hot="
		+ str(main_tab_surface_deck_hot).to_lower()
		+ "|support_surfaces_hot="
		+ str(support_surfaces_hot).to_lower()
		+ "|registry=resident_control_switch_support_surface_packet_by_actor"
		+ "|switch_authority=false"
		+ "|build_on_switch=false"
		+ "|build_on_click=false"
		+ "|ready_gate_member=false"
		+ "|at_ms=" + str(Time.get_ticks_msec())
	)

	for raw_surface_key in [
		"main_tab_surface_contracts",
		"relationships_hub_contract",
		"school_hub_contract",
		"activities_hub_contract",
		"career_hub_contract",
		"mod_menu_contract",
		"crown_hub_contract",
		"crime_hub_contract",
		"pet_shop_surface_contract",
		"pending_situations_payload",
		"asset_surface_pack",
		"assets_surface_contract",
		"property_market_surface_contract",
		"vehicle_market_surface_contract",
		"vehicle_market_surface_deck",
		"property_space_surface_contracts_by_id",
		"property_makeover_surface_contracts_by_id"
	]:
		var surface_key: String = str(
			raw_surface_key
		)
		var support_value: Variant = support_packet.get(
			surface_key,
			{}
		)

		if typeof(support_value) == TYPE_DICTIONARY:
			surface [surface_key] = (
				(support_value as Dictionary).duplicate(false)
			)

	surface ["actor_id"] = target_id
	surface ["pointer_revision"] = pointer_revision




	surface ["surface_hot"] = true
	surface ["press_frame_ready"] = true
	surface ["pointer_only_profile_packet"] = true
	surface ["full_surface_graph_required"] = false
	surface [
		"switch_press_must_not_build_surface"
	] = true
	surface [
		"created_for_zero_frame_switch"
	] = true
	surface [
		"control_switch_support_surfaces_hot"
	] = support_surfaces_hot
	surface [
		"main_tab_surface_deck_hot"
	] = main_tab_surface_deck_hot
	surface [
		"support_enrichment_pending"
	] = not support_surfaces_hot
	surface [
		"switch_commit_blocked_by_support_deck"
	] = false
	surface ["relationships_surface_hot"] = bool(
		support_packet.get(
			"relationships_surface_hot",
			false
		)
	)
	surface ["school_surface_hot"] = bool(
		support_packet.get(
			"school_surface_hot",
			false
		)
	)
	surface ["activities_surface_hot"] = bool(
		support_packet.get(
			"activities_surface_hot",
			false
		)
	)
	surface ["career_surface_hot"] = bool(
		support_packet.get(
			"career_surface_hot",
			false
		)
	)
	surface ["mods_surface_hot"] = bool(
		support_packet.get(
			"mods_surface_hot",
			false
		)
	)
	surface ["asset_surface_pack_hot"] = bool(
		support_packet.get(
			"asset_surface_pack_hot",
			false
		)
	)
	surface [
		"property_space_surface_deck_hot"
	] = bool(
		support_packet.get(
			"property_space_surface_deck_hot",
			false
		)
	)
	surface [
		"property_makeover_surface_deck_hot"
	] = bool(
		support_packet.get(
			"property_makeover_surface_deck_hot",
			false
		)
	)
	surface ["crown_surface_hot"] = bool(
		support_packet.get(
			"crown_surface_hot",
			false
		)
	)
	surface ["crime_surface_hot"] = bool(
		support_packet.get(
			"crime_surface_hot",
			false
		)
	)
	surface ["pet_shop_surface_hot"] = bool(
		support_packet.get(
			"pet_shop_surface_hot",
			false
		)
	)
	surface [
		"pending_situations_surface_hot"
	] = bool(
		support_packet.get(
			"pending_situations_surface_hot",
			false
		)
	)
	surface ["support_revision"] = str(
		support_packet.get(
			"support_revision",
			""
		)
	)
	surface [
		"pointer_revision_stable_across_surface_enrichment"
	] = true
	surface ["prewarmed_at_ms"] = int(
		Time.get_ticks_msec()
	)
	surface ["ready_gate_member"] = false

	pointer_packet [
		"pointer_revision"
	] = pointer_revision
	pointer_packet [
		"surface_contract"
	] = surface.duplicate(false)
	pointer_packet [
		"pointer_only_profile_packet"
	] = true
	pointer_packet [
		"press_frame_build_forbidden"
	] = true
	pointer_packet [
		"visible_click_work_required"
	] = false
	pointer_packet [
		"ready_gate_member"
	] = false

	for raw_packet_key in [
		"main_tab_surface_contracts",
		"relationships_hub_contract",
		"school_hub_contract",
		"activities_hub_contract",
		"career_hub_contract",
		"mod_menu_contract",
		"crown_hub_contract",
		"crime_hub_contract",
		"pet_shop_surface_contract",
		"pending_situations_payload",
		"asset_surface_pack",
		"assets_surface_contract",
		"property_market_surface_contract",
		"vehicle_market_surface_contract",
		"vehicle_market_surface_deck",
		"property_space_surface_contracts_by_id",
		"property_makeover_surface_contracts_by_id"
	]:
		var packet_key: String = str(
			raw_packet_key
		)
		pointer_packet [packet_key] = _shallow_dictionary(
			support_packet.get(
				packet_key,
				{}
			)
		)

	pointer_packet [
		"main_tab_surface_deck_hot"
	] = main_tab_surface_deck_hot
	pointer_packet [
		"control_switch_support_surfaces_hot"
	] = support_surfaces_hot
	pointer_packet [
		"support_revision"
	] = str(
		support_packet.get(
			"support_revision",
			""
		)
	)
	pointer_packet [
		"pointer_revision_stable_across_surface_enrichment"
	] = true
	pointer_packet [
		"pointer_packet_enriched_without_revision_replacement"
	] = true
	pointer_packet [
		"complete_actor_destination_deck"
	] = support_surfaces_hot
	pointer_packet [
		"support_enrichment_pending"
	] = not support_surfaces_hot
	pointer_packet [
		"switch_commit_blocked_by_support_deck"
	] = false
	pointer_packet [
		"ready_gate_member"
	] = false

	var core_truth: Dictionary = (
		_profile_switch_core_packet_truth(
			pointer_packet,
			target_id
		)
	)
	var core_packet_hot: bool = bool(
		core_truth.get(
			"core_packet_hot",
			false
		)
	)

	if not core_packet_hot:
		gs.scenario_state [
			"profile_pointer_packet_preparation_pending_actor_id"
		] = target_id
		gs.scenario_state [
			"profile_pointer_packet_preparation_pending_revision"
		] = pointer_revision
		gs.scenario_state [
			"profile_pointer_packet_preparation_missing_main_tabs"
		] = _safe_array(
			core_truth.get(
				"missing_main_tabs",
				[]
			)
		)
		gs.scenario_state [
			"profile_pointer_packet_partial_publication_rejected"
		] = true
		gs.scenario_state [
			"profile_pointer_packet_partial_publication_rejected_at_ms"
		] = int(
			Time.get_ticks_msec()
		)

		EraLog.truth(
			"ERALIFE_PROFILE_SWITCH_PACKET_STABILITY_TRUTH"
			+ "|actor_id=" + str(target_id)
			+ "|pointer_revision=" + pointer_revision
			+ "|surface_enriched=false"
			+ "|pointer_core_hot=false"
			+ "|partial_packet_published=false"
			+ "|ready_gate_member=false"
			+ "|switch_press_build=false"
			+ "|at_ms=" + str(Time.get_ticks_msec())
		)

		return {
			"success": false,
			"reason": "zero_frame_pointer_core_not_hot",
			"retryable": true,
			"actor_id": target_id,
			"pointer_revision": pointer_revision,
			"core_truth": core_truth.duplicate(false),
			"switch_press_build_forbidden": true,
			"visible_click_work_required": false,
			"ready_gate_member": false
		}

	var packet_cache: Dictionary = _shallow_dictionary(
		gs.scenario_state.get(
			"profile_pointer_packet_by_actor",
			{}
		)
	).duplicate(false)
	packet_cache [
		str(target_id)
	] = pointer_packet.duplicate(false)

	gs.scenario_state [
		"profile_pointer_packet_by_actor"
	] = packet_cache
	gs.scenario_state [
		"profile_pointer_packet_last_actor_id"
	] = target_id
	gs.scenario_state [
		"profile_pointer_packet_last_revision"
	] = pointer_revision
	gs.scenario_state [
		"profile_pointer_packet_revision_stable_after_enrichment"
	] = true
	gs.scenario_state [
		"profile_pointer_packet_main_tab_deck_hot"
	] = main_tab_surface_deck_hot
	gs.scenario_state [
		"profile_pointer_packet_complete_destination_deck"
	] = support_surfaces_hot
	gs.scenario_state [
		"profile_pointer_packet_partial_publication_rejected"
	] = false
	gs.scenario_state [
		"profile_pointer_packet_switch_commit_blocked_by_support_deck"
	] = false
	gs.scenario_state [
		"profile_pointer_packet_support_enrichment_pending"
	] = not support_surfaces_hot

	var previews: Dictionary = _shallow_dictionary(
		gs.scenario_state.get(
			"zero_frame_switch_surface_preview_by_actor",
			{}
		)
	).duplicate(false)
	previews [
		str(target_id)
	] = surface.duplicate(false)

	gs.scenario_state [
		"zero_frame_switch_surface_preview_by_actor"
	] = previews
	gs.scenario_state [
		"zero_frame_switch_surface_preview_last_actor_id"
	] = target_id
	gs.scenario_state [
		"zero_frame_switch_surface_preview_last_reason"
	] = str(
		prewarm_context.get(
			"source",
			"zero_frame_surface_prewarm"
		)
	)
	gs.scenario_state [
		"zero_frame_switch_surface_preview_last_ms"
	] = int(
		Time.get_ticks_msec()
	)
	gs.scenario_state [
		"zero_frame_switch_surface_preview_press_build_forbidden"
	] = true
	gs.scenario_state [
		"zero_frame_switch_support_surfaces_hot_actor_id"
	] = target_id
	gs.scenario_state [
		"zero_frame_switch_support_surfaces_hot"
	] = support_surfaces_hot
	gs.scenario_state [
		"zero_frame_switch_main_tab_surface_deck_hot"
	] = main_tab_surface_deck_hot
	gs.scenario_state [
		"zero_frame_switch_support_ready_gate_member"
	] = false

	EraLog.truth(
		"ERALIFE_PROFILE_SWITCH_PACKET_STABILITY_TRUTH"
		+ "|actor_id=" + str(target_id)
		+ "|pointer_revision=" + pointer_revision
		+ "|pointer_core_hot=true"
		+ "|surface_enriched="
		+ str(support_surfaces_hot).to_lower()
		+ "|main_tabs_hot="
		+ str(main_tab_surface_deck_hot).to_lower()
		+ "|support_surfaces_hot="
		+ str(support_surfaces_hot).to_lower()
		+ "|complete_destination_deck="
		+ str(support_surfaces_hot).to_lower()
		+ "|revision_replaced=false"
		+ "|ready_gate_member=false"
		+ "|switch_press_build=false"
		+ "|at_ms=" + str(Time.get_ticks_msec())
	)

	return {
		"success": true,
		"mode": (
			"zero_frame_surface_prewarmed"
			if support_surfaces_hot
			else "zero_frame_pointer_prewarmed_support_tail_pending"
		),
		"actor_id": target_id,
		"pointer_revision": pointer_revision,
		"surface_contract": surface.duplicate(false),
		"viewer_packet": pointer_packet.duplicate(false),
		"main_tab_surface_deck_hot": main_tab_surface_deck_hot,
		"control_switch_support_surfaces_hot": support_surfaces_hot,
		"complete_actor_destination_deck": support_surfaces_hot,
		"support_enrichment_pending": not support_surfaces_hot,
		"switch_commit_blocked_by_support_deck": false,
		"switch_press_build_forbidden": true,
		"visible_click_work_required": false,
		"ready_gate_member": false,
		"ui_is_renderer_only": true
	}
func _prewarmed_zero_frame_surface_for_actor(actor: Person) -> Dictionary:
	if gs == null or actor == null:
		return {}

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		return {}

	var actor_id: int = int(actor.id)
	if actor_id <= 0:
		return {}

	var previews: Dictionary = _shallow_dictionary(gs.scenario_state.get("zero_frame_switch_surface_preview_by_actor", {}))
	var surface: Dictionary = _shallow_dictionary(previews.get(str(actor_id), {}))

	if surface.is_empty():
		return {}

	if int(surface.get("actor_id", -1)) != actor_id:
		return {}

	return surface.duplicate(true)


func _refresh_surface_contract_for_actor(surface: Dictionary, actor: Person, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {}

	var out: Dictionary = surface.duplicate(true)
	var actor_id: int = int(actor.id)

	out ["schema"] = SWITCH_SURFACE_SCHEMA
	out ["version"] = CONTRACT_VERSION
	out ["actor_id"] = actor_id
	out ["actor_name"] = _actor_display_name(actor)
	out ["first_name"] = str(actor.first_name)
	out ["last_name"] = str(actor.last_name)
	out ["age"] = int(actor.age)
	out ["alive"] = bool(actor.alive)
	out ["bank_balance"] = max(0, int(actor.bank_balance))

	var pending_count: int = 0
	if gs != null and gs.pending_situations_engine != null and gs.pending_situations_engine.has_method("get_pending_count"):
		pending_count = int(gs.pending_situations_engine.get_pending_count(actor_id))

	out ["pending_situations_count"] = pending_count
	out ["health"] = int(round(float(actor.health)))
	out ["hunger"] = int(round(float(_safe_actor_number(actor, "hunger", 100))))
	out ["mental_health"] = int(round(float(actor.mental_health)))
	out ["willpower"] = int(round(float(_safe_actor_number(actor, "willpower", 100))))
	out ["happiness"] = int(round(float(actor.satisfaction)))
	out ["smarts"] = int(round(float(actor.smarts)))
	out ["looks"] = int(round(float(actor.looks)))
	out ["imagination"] = int(round(float(_safe_actor_number(actor, "imagination", 0))))
	out ["fame"] = int(round(float(actor.fame)))
	out ["approval"] = int(round(float(actor.approval)))
	out ["hud_truth"] = _surface_hud_truth_for_actor(actor)
	out ["surface_policy"] = {
		"render_immediately": true,
	}
	out ["context"] = context.duplicate(true)
	out ["updated_at_ms"] = int(Time.get_ticks_msec())

	return out
func _seal_hot_surface_for_actor(surface: Dictionary, actor: Person, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {}

	var out: Dictionary = surface.duplicate(true)
	var actor_id: int = int(actor.id)

	out ["schema"] = SWITCH_SURFACE_SCHEMA
	out ["version"] = CONTRACT_VERSION
	out ["actor_id"] = actor_id
	out ["actor_name"] = _actor_display_name(actor)
	out ["first_name"] = str(actor.first_name)
	out ["last_name"] = str(actor.last_name)
	out ["age"] = int(actor.age)
	out ["alive"] = bool(actor.alive)
	out ["bank_balance"] = max(0, int(actor.bank_balance))

	if not out.has("pending_situations_count"):
		out ["pending_situations_count"] = 0

	out ["health"] = int(round(float(actor.health)))
	out ["hunger"] = int(round(float(_safe_actor_number(actor, "hunger", 100))))
	out ["mental_health"] = int(round(float(actor.mental_health)))
	out ["willpower"] = int(round(float(_safe_actor_number(actor, "willpower", 100))))
	out ["happiness"] = int(round(float(actor.satisfaction)))
	out ["smarts"] = int(round(float(actor.smarts)))
	out ["looks"] = int(round(float(actor.looks)))
	out ["imagination"] = int(round(float(_safe_actor_number(actor, "imagination", 0))))
	out ["fame"] = int(round(float(actor.fame)))
	out ["approval"] = int(round(float(actor.approval)))
	out ["hud_truth"] = _surface_hud_truth_for_actor(actor)

	out ["surface_policy"] = {
		"render_immediately": true,
	}

	out ["context"] = context.duplicate(true)
	out ["updated_at_ms"] = int(Time.get_ticks_msec())
	return out
func _commit_switch_actor_age_truth(
	target: Person,
	surface: Dictionary = {},
	source: String = "universal_switch_actor_age_truth"
) -> int:
	if target == null:
		return 0

	var target_id: int = int(
		target.id
	)





	var canonical_age: int = maxi(
		0,
		int(
			target.age
		)
	)

	var surface_actor_matches: bool = (
		not surface.is_empty()
		and int(
			surface.get(
				"actor_id",
				target_id
			)
		) == target_id
	)

	var observed_surface_age: int = -1

	if (
		surface_actor_matches
		and surface.has(
			"age"
		)
	):
		observed_surface_age = maxi(
			0,
			int(
				surface.get(
					"age",
					canonical_age
				)
			)
		)

	var surface_age_matches_person_truth: bool = (
		observed_surface_age < 0
		or observed_surface_age == canonical_age
	)

	var stale_surface_rejected: bool = (
		observed_surface_age >= 0
		and not surface_age_matches_person_truth
	)

	var committed_at_ms: int = int(
		Time.get_ticks_msec()
	)

	if gs != null:
		if typeof(gs.scenario_state) != TYPE_DICTIONARY:
			gs.scenario_state = {}

		gs.scenario_state [
			"controlled_perspective_actor_id"
		] = target_id

		gs.scenario_state [
			"controlled_perspective_actor_age"
		] = canonical_age

		gs.scenario_state [
			"controlled_perspective_actor_age_source"
		] = (
			"person_identity_truth"
		)

		gs.scenario_state [
			"controlled_perspective_actor_age_requested_source"
		] = source

		gs.scenario_state [
			"controlled_perspective_actor_age_committed"
		] = true

		gs.scenario_state [
			"controlled_perspective_actor_age_committed_at_ms"
		] = committed_at_ms

		gs.scenario_state [
			"controlled_perspective_actor_person_contract_rebuilt"
		] = false

		gs.scenario_state [
			"controlled_perspective_actor_age_scalar_commit_only"
		] = true

		gs.scenario_state [
			"controlled_perspective_actor_age_person_mutated_from_surface"
		] = false

		gs.scenario_state [
			"controlled_perspective_actor_age_surface_observed"
		] = observed_surface_age

		gs.scenario_state [
			"controlled_perspective_actor_age_surface_matches_person_truth"
		] = surface_age_matches_person_truth

		gs.scenario_state [
			"controlled_perspective_actor_age_stale_surface_rejected"
		] = stale_surface_rejected

	EraLog.truth(
		(
			"ERALIFE_ENTITY_SWITCH_AGE_TRUTH"
			+ "|actor_id=%d"
			+ "|canonical_age=%d"
			+ "|observed_surface_age=%d"
			+ "|surface_matches_person=%s"
			+ "|stale_surface_rejected=%s"
			+ "|person_mutated_from_surface=false"
			+ "|person_contract_rebuild=false"
			+ "|scalar_commit_only=true"
			+ "|source=%s"
			+ "|at_ms=%d"
		)
		% [
			target_id,
			canonical_age,
			observed_surface_age,
			str(
				surface_age_matches_person_truth
			).to_lower(),
			str(
				stale_surface_rejected
			).to_lower(),
			source,
			committed_at_ms
		]
	)

	return canonical_age
func _commit_zero_frame_player_pointer(
	previous_actor: Person,
	target: Person,
	context: Dictionary = {}
) -> bool:
	if gs == null or target == null:
		return false

	if not bool(target.alive) or float(target.health) <= 0.0:
		return false

	var previous_id: int = int(previous_actor.id) if previous_actor != null else -1
	var target_id: int = int(target.id)

	if previous_id == target_id:
		return true

	var target_surface: Dictionary = _prewarmed_zero_frame_surface_for_actor(
		target
	)
	var committed_actor_age: int = _commit_switch_actor_age_truth(
		target,
		target_surface,
		"universal_switch_contract_engine.zero_frame_pointer_commit"
	)

	gs.player = target
	gs.player_id = target_id

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var sequence: int = int(
		gs.scenario_state.get(
			"controlled_perspective_truth_sequence",
			0
		)
	) + 1
	var actor_name: String = _actor_display_name(target)
	var hud_truth: Dictionary = _surface_hud_truth_for_actor(target)

	var packet: Dictionary = {
		"schema": "eralife.controlled_perspective_truth",
		"version": 2,
		"sequence": sequence,
		"source": str(
			context.get(
				"source",
				"universal_switch_contract_engine_pointer_commit"
			)
		),
		"previous_actor_id": previous_id,
		"actor_id": target_id,
		"actor_name": actor_name,
		"actor_age": committed_actor_age,
		"camera_model": "instant_consciousness_shift",
		"ui_rule": "render_surface_snapshot_first",
		"current_panel": "life",
		"hud_truth": hud_truth.duplicate(true),
		"zero_frame_consciousness_switch": true,
		"emitted_at_ms": int(Time.get_ticks_msec())
	}

	gs.scenario_state ["controlled_perspective_truth"] = packet.duplicate(true)
	gs.scenario_state ["controlled_perspective_truth_sequence"] = sequence
	gs.scenario_state ["controlled_perspective_switch_pending_ui_refresh"] = false
	gs.scenario_state ["controlled_perspective_actor_id"] = target_id
	gs.scenario_state ["controlled_perspective_actor_name"] = actor_name
	gs.scenario_state ["controlled_perspective_actor_age"] = committed_actor_age
	gs.scenario_state ["controlled_perspective_source"] = "zero_frame_pointer_commit"
	gs.scenario_state ["runtime_hud_visibility_snapshot"] = {
		"player_id": target_id,
		"controlled_actor_id": target_id,
		"controlled_actor_name": actor_name,
		"controlled_actor_age": committed_actor_age,
		"current_panel": "life",
		"belongings_available": bool(
			hud_truth.get("belongings_available", true)
		),
		"bending_available": bool(
			hud_truth.get("bending_available", false)
		),
		"crown_available": bool(
			hud_truth.get("crown_available", false)
		),
		"food_lifestyle_available": bool(
			hud_truth.get("food_lifestyle_available", false)
		),
		"restaurant_lifestyle_available": bool(
			hud_truth.get("restaurant_lifestyle_available", false)
		),
		"rick_weapon_shop_available": bool(
			hud_truth.get("rick_weapon_shop_available", false)
		),
		"boxing_available": bool(
			hud_truth.get("boxing_available", false)
		),
		"superhero_available": bool(
			hud_truth.get(
				"superhero_available",
				hud_truth.get("superhero", false)
			)
		),
		"superpower_available": bool(
			hud_truth.get(
				"superpower_available",
				hud_truth.get("superhero_available", false)
			)
		),
		"power_available": bool(
			hud_truth.get("power_available", false)
		),
		"wizard_available": bool(
			hud_truth.get("wizard_available", false)
		),
		"shell_only": false,
		"zero_frame_switch_truth": true,
		"reason": "zero_frame_pointer_commit",
		"updated_at_ms": int(Time.get_ticks_msec())
	}
	gs.scenario_state ["runtime_hud_visibility_snapshot_reason"] = "zero_frame_pointer_commit"
	gs.scenario_state ["runtime_hud_visibility_snapshot_at_ms"] = int(
		Time.get_ticks_msec()
	)

	return true

func commit_zero_frame_viewer_pointer_only(
	target: Person,
	viewer_packet: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	if gs == null:
		return {
			"success": false,
			"reason": "missing_game_state",
			"press_frame_build_forbidden": true
		}

	if target == null:
		return {
			"success": false,
			"reason": "missing_target",
			"press_frame_build_forbidden": true
		}

	if viewer_packet.is_empty():
		return {
			"success": false,
			"reason": "missing_playable_life_viewer_packet",
			"press_frame_build_forbidden": true
		}

	var target_id: int = int(target.id)

	if target_id <= 0:
		return {
			"success": false,
			"reason": "invalid_target_id",
			"press_frame_build_forbidden": true
		}

	if (
		not bool(target.alive)
		or float(target.health) <= 0.0
	):
		return {
			"success": false,
			"reason": "target_dead",
			"target_id": target_id,
			"press_frame_build_forbidden": true
		}

	var surface_raw: Variant = viewer_packet.get(
		"surface_contract",
		{}
	)

	if typeof(surface_raw) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": (
				"viewer_packet_missing_surface_contract"
			),
			"target_id": target_id,
			"press_frame_build_forbidden": true
		}

	var surface: Dictionary = surface_raw as Dictionary

	if surface.is_empty():
		return {
			"success": false,
			"reason": (
				"viewer_packet_missing_surface_contract"
			),
			"target_id": target_id,
			"press_frame_build_forbidden": true
		}

	if int(
		surface.get(
			"actor_id",
			-1
		)
	) != target_id:
		return {
			"success": false,
			"reason": "viewer_packet_actor_mismatch",
			"target_id": target_id,
			"surface_actor_id": int(
				surface.get(
					"actor_id",
					-1
				)
			),
			"press_frame_build_forbidden": true
		}

	var render_policy_raw: Variant = viewer_packet.get(
		"render_policy",
		{}
	)
	var render_policy: Dictionary = (
		render_policy_raw as Dictionary
		if typeof(render_policy_raw) == TYPE_DICTIONARY
		else {}
	)

	if bool(
		render_policy.get(
			"viewer_waits",
			true
		)
	):
		return {
			"success": false,
			"reason": (
				"viewer_packet_wait_policy_rejected"
			),
			"target_id": target_id,
			"press_frame_build_forbidden": true
		}

	var previous_actor: Person = gs.player
	var previous_actor_id: int = (
		int(previous_actor.id)
		if previous_actor != null
		else -1
	)
	var actor_name: String = str(
		viewer_packet.get(
			"actor_name",
			surface.get(
				"actor_name",
				_actor_display_name(target)
			)
		)
	).strip_edges()

	if actor_name == "":
		actor_name = _actor_display_name(
			target
		)

	var committed_actor_age: int = (
		_commit_switch_actor_age_truth(
			target,
			surface,
			"universal_switch_contract_engine.viewer_pointer_commit"
		)
	)

	var hud_packet_raw: Variant = viewer_packet.get(
		"hud_packet",
		{}
	)
	var hud_packet: Dictionary = (
		hud_packet_raw as Dictionary
		if typeof(hud_packet_raw) == TYPE_DICTIONARY
		else {}
	)
	var hud_truth_raw: Variant = hud_packet.get(
		"hud_truth",
		surface.get(
			"hud_truth",
			{}
		)
	)
	var hud_truth: Dictionary = (
		hud_truth_raw as Dictionary
		if typeof(hud_truth_raw) == TYPE_DICTIONARY
		else {}
	)


	gs.player = target
	gs.player_id = target_id

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	switch_sequence += 1

	var now_ms: int = int(
		Time.get_ticks_msec()
	)
	var contract_id: String = (
		"zero_frame_viewer_pointer_%d_%d_%d"
		% [
			switch_sequence,
			target_id,
			now_ms
		]
	)
	var packet_signature: String = str(
		viewer_packet.get(
			"packet_signature",
			surface.get(
				"surface_signature",
				""
			)
		)
	).strip_edges()

	if packet_signature == "":
		packet_signature = "%d:%d:%d" % [
			target_id,
			committed_actor_age,
			now_ms
		]

	var result: Dictionary = {
		"success": true,
		"type": "zero_frame_consciousness_switch",
		"text": "I started living as %s." % actor_name,
		"popup_title": "Life Switched",
		"popup_text": (
			"I started living as %s." % actor_name
		),
		"popup_footer": "Tap anywhere to continue.",
		"identity_switch": true,
		"zero_frame_consciousness_switch": true,
		"previous_controlled_person_id": (
			previous_actor_id
		),
		"controlled_person_id": target_id,
		"controlled_person_name": actor_name,
		"controlled_person_age": committed_actor_age,
		"viewer_packet_signature": packet_signature,
		"source": str(
			context.get(
				"source",
				"playable_life_viewer_pointer_only"
			)
		)
	}

	var pointer_contract: Dictionary = {
		"schema": SWITCH_CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": contract_id,
		"contract_id": contract_id,
		"mode": "zero_frame_viewer_pointer_only",
		"switch_mode": (
			"playable_life_viewer_packet_pointer_commit"
		),
		"source": str(
			context.get(
				"source",
				"playable_life_viewer_pointer_only"
			)
		),
		"previous_actor_id": previous_actor_id,
		"previous_actor_name": (
			_actor_display_name(previous_actor)
		),
		"controlled_actor_id": target_id,
		"controlled_actor_name": actor_name,
		"controlled_actor_age": committed_actor_age,
		"target_actor_id": target_id,
		"target_actor_name": actor_name,
		"target_actor_age": committed_actor_age,
		"viewer_packet_signature": packet_signature,
		"surface_actor_id": int(
			surface.get(
				"actor_id",
				target_id
			)
		),
		"visible_commit_ms": now_ms,
		"press_frame_commit": true,
		"press_frame_build_forbidden": true,
		"ui_policy": {
			"ui_is_pure_renderer": true,
			"platform_renderer_must_not_build": true,
			"camera_model": "instant_consciousness_shift",
		},
		"context": context.duplicate(false),
		"created_at_ms": now_ms,
		"updated_at_ms": now_ms
	}

	switch_contracts [contract_id] = (
		pointer_contract.duplicate(false)
	)
	_trim_contracts()

	gs.scenario_state ["controlled_perspective_truth"] = {
		"schema": "eralife.controlled_perspective_truth",
		"version": 1,
		"sequence": int(
			gs.scenario_state.get(
				"controlled_perspective_truth_sequence",
				0
			)
		) + 1,
		"source": str(
			context.get(
				"source",
				"playable_life_viewer_pointer_only"
			)
		),
		"previous_actor_id": previous_actor_id,
		"actor_id": target_id,
		"actor_name": actor_name,
		"actor_age": committed_actor_age,
		"camera_model": "instant_consciousness_shift",
		"ui_rule": "consume_existing_viewer_packet",
		"current_panel": "life",
		"hud_truth": hud_truth.duplicate(false),
		"viewer_packet_signature": packet_signature,
		"zero_frame_consciousness_switch": true,
		"emitted_at_ms": now_ms
	}

	gs.scenario_state [
		"controlled_perspective_truth_sequence"
	] = int(
		gs.scenario_state [
			"controlled_perspective_truth"
		].get(
			"sequence",
			1
		)
	)
	gs.scenario_state [
		"controlled_perspective_switch_pending_ui_refresh"
	] = false
	gs.scenario_state [
		"controlled_perspective_actor_id"
	] = target_id
	gs.scenario_state [
		"controlled_perspective_actor_name"
	] = actor_name
	gs.scenario_state [
		"controlled_perspective_actor_age"
	] = committed_actor_age
	gs.scenario_state [
		"controlled_perspective_actor_age_truth_committed"
	] = true
	gs.scenario_state [
		"controlled_perspective_source"
	] = "playable_life_viewer_pointer_only"



	gs.scenario_state [
		"zero_frame_consciousness_switch_surface"
	] = surface
	gs.scenario_state [
		"zero_frame_consciousness_switch_surface_lock_active"
	] = true
	gs.scenario_state [
		"zero_frame_consciousness_switch_surface_lock_actor_id"
	] = target_id
	gs.scenario_state [
		"zero_frame_consciousness_switch_surface_lock_until_ms"
	] = now_ms + 8500
	gs.scenario_state [
		"zero_frame_consciousness_switch_full_refresh_pending"
	] = false
	gs.scenario_state [
		"zero_frame_consciousness_switch_full_refresh_stage"
	] = 0
	gs.scenario_state.erase(
		"zero_frame_consciousness_switch_full_refresh_next_ms"
	)

	gs.scenario_state ["runtime_hud_visibility_snapshot"] = {
		"player_id": target_id,
		"controlled_actor_id": target_id,
		"controlled_actor_name": actor_name,
		"controlled_actor_age": committed_actor_age,
		"current_panel": "life",
		"belongings_available": bool(
			hud_packet.get(
				"belongings_available",
				hud_truth.get(
					"belongings_available",
					true
				)
			)
		),
		"bending_available": bool(
			hud_packet.get(
				"bending_available",
				hud_truth.get(
					"bending_available",
					false
				)
			)
		),
		"crown_available": bool(
			hud_packet.get(
				"crown_available",
				hud_truth.get(
					"crown_available",
					false
				)
			)
		),
		"food_lifestyle_available": bool(
			hud_packet.get(
				"food_lifestyle_available",
				hud_truth.get(
					"food_lifestyle_available",
					false
				)
			)
		),
		"restaurant_lifestyle_available": bool(
			hud_packet.get(
				"restaurant_lifestyle_available",
				hud_truth.get(
					"restaurant_lifestyle_available",
					false
				)
			)
		),
		"rick_weapon_shop_available": bool(
			hud_packet.get(
				"rick_weapon_shop_available",
				hud_truth.get(
					"rick_weapon_shop_available",
					false
				)
			)
		),
		"boxing_available": bool(
			hud_packet.get(
				"boxing_available",
				hud_truth.get(
					"boxing_available",
					false
				)
			)
		),
		"superhero_available": bool(
			hud_packet.get(
				"superhero_available",
				hud_truth.get(
					"superhero_available",
					false
				)
			)
		),
		"superpower_available": bool(
			hud_packet.get(
				"superpower_available",
				hud_truth.get(
					"superpower_available",
					false
				)
			)
		),
		"power_available": bool(
			hud_packet.get(
				"power_available",
				hud_truth.get(
					"power_available",
					false
				)
			)
		),
		"wizard_available": bool(
			hud_packet.get(
				"wizard_available",
				hud_truth.get(
					"wizard_available",
					false
				)
			)
		),
		"age_up_button_visible": true,
		"shell_only": false,
		"zero_frame_switch_truth": true,
		"zero_frame_switch_surface_locked": true,
		"reason": "playable_life_viewer_pointer_only",
		"updated_at_ms": now_ms
	}

	gs.scenario_state [
		"runtime_hud_visibility_snapshot_reason"
	] = "playable_life_viewer_pointer_only"
	gs.scenario_state [
		"runtime_hud_visibility_snapshot_at_ms"
	] = now_ms
	gs.scenario_state [
		"playable_life_viewer_pointer_commit_contract"
	] = pointer_contract.duplicate(false)
	gs.scenario_state [
		"playable_life_viewer_pointer_commit_packet_signature"
	] = packet_signature
	gs.scenario_state [
		"playable_life_viewer_pointer_commit_packet_deep_copy_forbidden"
	] = true

	last_report = {
		"success": true,
		"mode": "zero_frame_viewer_pointer_only_committed",
		"zero_frame_consciousness_switch": true,
		"contract_id": contract_id,
		"previous_actor_id": previous_actor_id,
		"controlled_actor_id": target_id,
		"controlled_actor_name": actor_name,
		"viewer_packet_signature": packet_signature,
		"result": result
	}

	return last_report.duplicate(false)
func _pointer_only_destination_deck_for_actor(
	target: Person,
	surface: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	if target == null:
		return {}

	var target_id: int = int(
		target.id
	)
	var actor_name: String = _actor_display_name(
		target
	)
	var now_ms: int = int(
		Time.get_ticks_msec()
	)
	var pointer_revision: String = str(
		surface.get(
			"pointer_revision",
			context.get(
				"requested_pointer_revision",
				""
			)
		)
	).strip_edges()

	var out: Dictionary = {}

	for raw_tab_id in [
		"relationships",
		"school",
		"activities",
		"career",
		"mods"
	]:
		var tab_id: String = str(
			raw_tab_id
		)
		out [
			tab_id
		] = {
			"success": true,
			"schema": "eralife.pointer_only.destination_tab_contract",
			"version": CONTRACT_VERSION,
			"actor_id": target_id,
			"actor_name": actor_name,
			"surface_id": tab_id,
			"tab_id": tab_id,
			"pointer_revision": pointer_revision,
			"truth_state": "pointer_only_resident_shell",
			"press_frame_build_forbidden": true,
			"visible_click_work_required": false,
			"ready_gate_member": false,
			"ui_is_renderer_only": true,
			"created_at_ms": now_ms
		}

	return out
func claim_visible_truth_anchor_pointer_only(
	target: Person,
	viewer_packet: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	if gs == null:
		return {
			"success": false,
			"reason": "missing_game_state",
			"press_frame_build_forbidden": true
		}

	if target == null:
		return {
			"success": false,
			"reason": "missing_target",
			"press_frame_build_forbidden": true
		}

	if (
		typeof(
			viewer_packet
		) != TYPE_DICTIONARY
		or viewer_packet.is_empty()
	):
		return {
			"success": false,
			"reason": "missing_playable_life_viewer_packet",
			"press_frame_build_forbidden": true
		}

	var target_id: int = int(
		target.id
	)

	if target_id <= 0:
		return {
			"success": false,
			"reason": "invalid_target_id",
			"press_frame_build_forbidden": true
		}

	if (
		not bool(
			target.alive
		)
		or float(
			target.health
		) <= 0.0
	):
		return {
			"success": false,
			"reason": "target_dead",
			"target_id": target_id,
			"press_frame_build_forbidden": true
		}

	var surface_raw: Variant = viewer_packet.get(
		"surface_contract",
		{}
	)

	if typeof(
		surface_raw
	) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "viewer_packet_missing_surface_contract",
			"target_id": target_id,
			"press_frame_build_forbidden": true
		}

	var surface: Dictionary = (
		surface_raw as Dictionary
	).duplicate(
		false
	)

	if (
		surface.is_empty()
		or int(
			surface.get(
				"actor_id",
				-1
			)
		) != target_id
	):
		return {
			"success": false,
			"reason": "viewer_packet_actor_mismatch",
			"target_id": target_id,
			"surface_actor_id": int(
				surface.get(
					"actor_id",
					-1
				)
			),
			"press_frame_build_forbidden": true
		}

	var pointer_revision: String = str(
		viewer_packet.get(
			"pointer_revision",
			surface.get(
				"pointer_revision",
				""
			)
		)
	).strip_edges()
	var surface_revision: String = str(
		surface.get(
			"pointer_revision",
			""
		)
	).strip_edges()

	if (
		pointer_revision == ""
		or surface_revision == ""
		or pointer_revision != surface_revision
	):
		return {
			"success": false,
			"reason": "viewer_packet_pointer_revision_invalid",
			"target_id": target_id,
			"pointer_revision": pointer_revision,
			"surface_revision": surface_revision,
			"press_frame_build_forbidden": true
		}

	var main_tab_deck: Dictionary = _shallow_dictionary(
		viewer_packet.get(
			"main_tab_surface_contracts",
			surface.get(
				"main_tab_surface_contracts",
				{}
			)
		)
	)
	var destination_deck_was_missing: bool = (
		main_tab_deck.is_empty()
	)
	var missing_anchor_tabs: Array = []
	var pointer_only_anchor_tabs: Array = []

	if main_tab_deck.is_empty():
		main_tab_deck = _pointer_only_destination_deck_for_actor(
			target,
			surface,
			{
				"source": "visible_truth_anchor_pointer_normalization",
				"requested_pointer_revision": pointer_revision,
				"ready_gate_member": false,
				"ui_is_renderer_only": true
			}
		)

	for raw_tab_id in [
		"relationships",
		"school",
		"activities",
		"career",
		"mods"
	]:
		var tab_id: String = str(
			raw_tab_id
		)
		var tab_contract: Dictionary = _shallow_dictionary(
			main_tab_deck.get(
				tab_id,
				{}
			)
		)

		if (
			tab_contract.is_empty()
			or int(
				tab_contract.get(
					"actor_id",
					-1
				)
			) != target_id
		):
			missing_anchor_tabs.append(
				tab_id
			)
			continue

		var tab_schema: String = str(
			tab_contract.get(
				"schema",
				""
			)
		).strip_edges().to_lower()
		var tab_truth_state: String = str(
			tab_contract.get(
				"truth_state",
				""
			)
		).strip_edges().to_lower()

		if (
			tab_schema
			== "eralife.pointer_only.destination_tab_contract"
			or tab_truth_state
			== "pointer_only_resident_shell"
		):
			pointer_only_anchor_tabs.append(
				tab_id
			)

	if not missing_anchor_tabs.is_empty():
		return {
			"success": false,
			"reason": "viewer_packet_pointer_destination_deck_missing_tabs",
			"target_id": target_id,
			"missing_main_tabs": missing_anchor_tabs,
			"pointer_only_tabs": pointer_only_anchor_tabs,
			"press_frame_build_forbidden": true,
			"support_deck_blocks_switch": false
		}

	var previous_actor: Person = gs.player
	var previous_actor_id: int = (
		int(
			previous_actor.id
		)
		if previous_actor != null
		else -1
	)
	var actor_name: String = str(
		viewer_packet.get(
			"actor_name",
			_actor_display_name(
				target
			)
		)
	).strip_edges()

	if actor_name == "":
		actor_name = _actor_display_name(
			target
		)

	var hud_truth: Dictionary = (
		_surface_hud_truth_for_actor(
			target
		)
	)





	if (
		previous_actor != null
		and previous_actor_id > 0
		and previous_actor_id != target_id
		and gs.has_method(
			"preserve_released_controlled_actor_residency"
		)
	):
		gs.call_deferred(
			"preserve_released_controlled_actor_residency",
			previous_actor
		)



	gs.player = target
	gs.player_id = target_id

	if typeof(
		gs.scenario_state
	) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var now_ms: int = int(
		Time.get_ticks_msec()
	)
	var anchor_surface: Dictionary = {
		"schema": "eralife.visible_truth_anchor_surface",
		"version": 4,
		"actor_id": target_id,
		"actor_name": actor_name,
		"previous_actor_id": previous_actor_id,
		"current_panel": "life",
		"zero_frame_consciousness_switch": true,
		"hud_truth": hud_truth,
		"main_tab_surface_contracts": (
			main_tab_deck
		),
		"destination_deck_was_missing": destination_deck_was_missing,
		"destination_deck_was_pointer_only": (
			not pointer_only_anchor_tabs.is_empty()
		),
		"pointer_only_tabs": pointer_only_anchor_tabs,
		"support_deck_blocks_switch": false,
		"hidden_surface_projection_policy": (
			"resident_actor_renderer_page_pointer_swap"
		),
		"created_at_ms": now_ms
	}

	gs.scenario_state [
		"visible_truth_anchor_actor_id"
	] = target_id
	gs.scenario_state [
		"visible_truth_anchor_actor_name"
	] = actor_name
	gs.scenario_state [
		"visible_truth_anchor_previous_actor_id"
	] = previous_actor_id
	gs.scenario_state [
		"visible_truth_anchor_claimed_at_ms"
	] = now_ms
	gs.scenario_state [
		"visible_truth_anchor_source"
	] = str(
		context.get(
			"source",
			"visible_truth_anchor_pointer_only"
		)
	)
	gs.scenario_state [
		"controlled_perspective_actor_id"
	] = target_id
	gs.scenario_state [
		"controlled_perspective_actor_name"
	] = actor_name
	gs.scenario_state [
		"controlled_perspective_source"
	] = "visible_truth_anchor_pointer_only"
	gs.scenario_state [
		"controlled_perspective_switch_pending_ui_refresh"
	] = false
	gs.scenario_state [
		"zero_frame_consciousness_switch_surface"
	] = anchor_surface
	gs.scenario_state [
		"zero_frame_consciousness_switch_surface_lock_active"
	] = false
	gs.scenario_state [
		"zero_frame_consciousness_switch_surface_lock_actor_id"
	] = target_id
	gs.scenario_state [
		"zero_frame_consciousness_switch_surface_lock_until_ms"
	] = now_ms
	gs.scenario_state [
		"zero_frame_consciousness_switch_interaction_released"
	] = true
	gs.scenario_state [
		"zero_frame_consciousness_switch_interaction_released_actor_id"
	] = target_id
	gs.scenario_state [
		"zero_frame_consciousness_switch_full_refresh_pending"
	] = false
	gs.scenario_state [
		"zero_frame_consciousness_switch_full_refresh_stage"
	] = 0
	gs.scenario_state.erase(
		"zero_frame_consciousness_switch_full_refresh_next_ms"
	)
	gs.scenario_state [
		"switch_press_claimed_truth_anchor_before_tail_contract"
	] = true
	gs.scenario_state [
		"switch_press_visible_anchor_claim_at_ms"
	] = now_ms
	gs.scenario_state [
		"switch_press_viewer_packet_deep_copy_forbidden"
	] = true
	gs.scenario_state [
		"switch_press_surface_deep_copy_forbidden"
	] = true
	gs.scenario_state [
		"switch_press_report_packet_forbidden"
	] = true
	gs.scenario_state [
		"playable_life_viewer_last_committed_actor_id"
	] = target_id
	gs.scenario_state [
		"playable_life_viewer_last_committed_packet_ref_forbidden_on_press"
	] = true
	gs.scenario_state [
		"resident_main_tab_surface_contracts"
	] = main_tab_deck
	gs.scenario_state [
		"visible_truth_anchor_support_deck_blocks_switch"
	] = false
	gs.scenario_state [
		"visible_truth_anchor_pointer_only_tabs"
	] = pointer_only_anchor_tabs.duplicate(
		false
	)

	gs.scenario_state [
		"runtime_hud_visibility_snapshot"
	] = {
		"player_id": target_id,
		"actor_id": target_id,
		"controlled_actor_id": target_id,
		"controlled_actor_name": actor_name,
		"current_panel": "life",
		"belongings_available": bool(
			hud_truth.get(
				"belongings_available",
				true
			)
		),
		"bending_available": bool(
			hud_truth.get(
				"bending_available",
				false
			)
		),
		"crown_available": bool(
			hud_truth.get(
				"crown_available",
				false
			)
		),
		"food_lifestyle_available": bool(
			hud_truth.get(
				"food_lifestyle_available",
				false
			)
		),
		"restaurant_lifestyle_available": bool(
			hud_truth.get(
				"restaurant_lifestyle_available",
				false
			)
		),
		"rick_weapon_shop_available": bool(
			hud_truth.get(
				"rick_weapon_shop_available",
				false
			)
		),
		"boxing_available": bool(
			hud_truth.get(
				"boxing_available",
				false
			)
		),
		"superhero_available": bool(
			hud_truth.get(
				"superhero_available",
				false
			)
		),
		"superpower_available": bool(
			hud_truth.get(
				"superpower_available",
				false
			)
		),
		"power_available": bool(
			hud_truth.get(
				"power_available",
				false
			)
		),
		"wizard_available": bool(
			hud_truth.get(
				"wizard_available",
				false
			)
		),
		"age_up_button_visible": true,
		"shell_only": false,
		"zero_frame_switch_truth": true,
		"reason": "visible_truth_anchor_pointer_only",
		"updated_at_ms": now_ms
	}
	gs.scenario_state [
		"runtime_hud_visibility_snapshot_reason"
	] = "visible_truth_anchor_pointer_only"
	gs.scenario_state [
		"runtime_hud_visibility_snapshot_at_ms"
	] = now_ms
	gs.scenario_state [
		"controlled_actor_projection_rebind_pending"
	] = false
	gs.scenario_state [
		"controlled_actor_projection_rebind_queued"
	] = false
	gs.scenario_state [
		"controlled_actor_projection_rebind_actor_id"
	] = target_id
	gs.scenario_state [
		"controlled_actor_projection_rebind_previous_actor_id"
	] = previous_actor_id
	gs.scenario_state [
		"controlled_actor_projection_rebind_requested_at_ms"
	] = now_ms
	gs.scenario_state [
		"controlled_actor_projection_rebind_waits_for_presented_lens"
	] = false
	gs.scenario_state [
		"controlled_actor_projection_rebind_deferred_until_surface_intent"
	] = false
	gs.scenario_state [
		"controlled_actor_projection_rebind_ready_gate_member"
	] = false
	gs.scenario_state [
		"controlled_actor_projection_rebind_main_scene_requested"
	] = true
	gs.scenario_state [
		"controlled_actor_switch_hidden_surface_publication_automatic"
	] = true
	gs.scenario_state [
		"controlled_actor_switch_hidden_surface_rendering_automatic"
	] = true
	gs.scenario_state [
		"controlled_actor_switch_renderer_page_pointer_swap_required"
	] = true

	EraLog.truth(
		"PROFILE_PACKET_SWITCHED"
		+ "|actor_id=" + str(
			target_id
		)
		+ "|previous_actor_id=" + str(
			previous_actor_id
		)
		+ "|pointer_revision=" + pointer_revision
		+ "|pointer_only_tabs=" + str(
			pointer_only_anchor_tabs
		)
		+ "|support_deck_blocks_switch=false"
		+ "|build_on_press=false"
		+ "|at_ms=" + str(
			now_ms
		)
	)

	return {
		"success": true,
		"mode": "visible_truth_anchor_pointer_only",
		"zero_frame_consciousness_switch": true,
		"previous_actor_id": previous_actor_id,
		"controlled_actor_id": target_id,
		"controlled_actor_name": actor_name,
		"support_deck_blocks_switch": false,
		"result": {
			"success": true,
			"type": "zero_frame_consciousness_switch",
			"text": "Perspective shifted to %s." % actor_name,
			"identity_switch": true,
			"zero_frame_consciousness_switch": true,
			"previous_controlled_person_id": previous_actor_id,
			"controlled_person_id": target_id,
			"controlled_person_name": actor_name,
			"source": str(
				context.get(
					"source",
					"visible_truth_anchor_pointer_only"
				)
			),
			"support_deck_blocks_switch": false
		}
	}
func _queue_attached_actor_projection_rebind_after_visible_pointer_switch(
	target_id: int,
	previous_actor_id: int,
	source: String
) -> void:


	await RenderingServer.frame_post_draw

	if (
		gs == null
		or gs.player == null
		or int(
			gs.player.id
		) != target_id
	):
		if (
			gs != null
			and typeof(
				gs.scenario_state
			) == TYPE_DICTIONARY
		):
			gs.scenario_state [
				"controlled_actor_projection_rebind_pending"
			] = false
			gs.scenario_state [
				"controlled_actor_projection_rebind_superseded"
			] = true
			gs.scenario_state [
				"controlled_actor_projection_rebind_superseded_actor_id"
			] = target_id
			gs.scenario_state [
				"controlled_actor_projection_rebind_superseded_at_ms"
			] = int(
				Time.get_ticks_msec()
			)

		return




	if gs.has_method(
		"register_controlled_character"
	):
		if previous_actor_id > 0:
			gs.register_controlled_character(
				previous_actor_id
			)

		if target_id > 0:
			gs.register_controlled_character(
				target_id
			)







	var hunger_mirror_report: Dictionary = {
		"success": false,
		"reason": "food_engine_unavailable"
	}

	if (
		gs.food_engine != null
		and gs.food_engine.has_method(
			"sync_published_hunger_to_actor"
		)
	):
		hunger_mirror_report = (
			gs.food_engine.sync_published_hunger_to_actor(
				gs.player,
				{
					"source": (
						"universal_switch_contract_engine."
						+ "post_visible_pointer_hunger_mirror"
					),
					"target_id": target_id,
					"previous_actor_id": previous_actor_id,
					"ready_gate_member": false
				}
			)
		)

	var projection_rebind_report: Dictionary = {
		"success": false,
		"reason": "reality_residency_manager_unavailable",
		"ready_gate_member": false
	}

	if (
		gs.reality_residency_manager != null
		and gs.reality_residency_manager.has_method(
			"request_attached_actor_projection_rebind"
		)
	):
		projection_rebind_report = (
			gs.reality_residency_manager
			.request_attached_actor_projection_rebind(
				target_id,
				{
					"source": source,
					"previous_actor_id": previous_actor_id,
					"controlled_actor_id": target_id,
					"build_on_click_forbidden": true,
					"ready_gate_member": false,
					"ui_is_renderer_only": true
				}
			)
		)

	if typeof(
		gs.scenario_state
	) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	gs.scenario_state [
		"controlled_actor_projection_rebind_pending"
	] = false
	gs.scenario_state [
		"controlled_actor_projection_rebind_report"
	] = projection_rebind_report.duplicate(false)
	gs.scenario_state [
		"controlled_actor_projection_rebind_queued"
	] = bool(
		projection_rebind_report.get(
			"success",
			false
		)
	)
	gs.scenario_state [
		"controlled_actor_projection_rebind_released_after_presented_lens"
	] = true
	gs.scenario_state [
		"controlled_actor_projection_rebind_released_at_ms"
	] = int(
		Time.get_ticks_msec()
	)
	gs.scenario_state [
		"controlled_actor_projection_rebind_ready_gate_member"
	] = false
	gs.scenario_state [
		"controlled_actor_projection_rebind_main_scene_requested"
	] = false
	gs.scenario_state [
		"controlled_actor_hunger_mirror_report"
	] = hunger_mirror_report.duplicate(false)
	gs.scenario_state [
		"controlled_actor_hunger_mirror_after_presented_lens"
	] = true
	gs.scenario_state [
		"controlled_actor_identity_history_registered"
	] = true
	gs.scenario_state [
		"controlled_actor_identity_history_previous_actor_id"
	] = previous_actor_id
	gs.scenario_state [
		"controlled_actor_identity_history_actor_id"
	] = target_id
func _surface_hud_truth_for_actor(
	actor: Person
) -> Dictionary:
	if actor == null:
		return {}

	var actor_age: int = int(actor.age)
	var actor_alive: bool = (
		bool(actor.alive)
		and float(actor.health) > 0.0
	)
	var bending_available: bool = (
		actor_alive
		and str(
			actor.bending_type
		).strip_edges().to_lower() not in [
			"",
			"none",
			"null"
		]
	)
	var civic_office_raw: Variant = actor.get(
		"civic_office_contract"
	)
	var civic_office: Dictionary = (
		civic_office_raw as Dictionary
		if typeof(civic_office_raw) == TYPE_DICTIONARY
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
		actor.succession_rank
	)

	var crown_available: bool = (
		actor_alive
		and (
			bool(
				actor.is_ruler
			)
			or bool(
				actor.is_royal
			)
			or str(
				actor.royal_title
			).strip_edges() != ""
			or (
				succession_rank > 0
				and succession_rank < 99
			)
			or civic_crown_available
		)
	)
	var boxing_available: bool = false

	if actor_alive and actor.has_method("get_meta"):
		boxing_available = bool(
			actor.get_meta(
				"boxing_career_active",
				false
			)
		)

	var superpower_available: bool = false

	if (
		actor_alive
		and _actor_has_property(
			actor,
			"superpower_type"
		)
	):
		superpower_available = (
			str(
				actor.superpower_type
			).strip_edges().to_lower() not in [
				"",
				"none",
				"null"
			]
		)

	var power_available: bool = false

	if (
		actor_alive
		and _actor_has_property(
			actor,
			"power_type"
		)
	):
		power_available = (
			str(
				actor.power_type
			).strip_edges().to_lower() not in [
				"",
				"none",
				"null"
			]
		)

	var superhero_available: bool = (
		superpower_available
		or power_available
	)
	var wizard_available: bool = false

	if (
		actor_alive
		and _actor_has_property(
			actor,
			"wizard_type"
		)
	):
		wizard_available = (
			str(
				actor.get(
					"wizard_type"
				)
			).strip_edges().to_lower() not in [
				"",
				"none",
				"null"
			]
		)

	var rick_available: bool = false

	if (
		actor_alive
		and gs != null
		and gs.weapons_engine != null
		and gs.weapons_engine.has_method(
			"get_store"
		)
	):
		var weapon_store_raw: Variant = (
			gs.weapons_engine.get_store()
		)

		if typeof(
			weapon_store_raw
		) == TYPE_ARRAY:
			rick_available = not (
				weapon_store_raw as Array
			).is_empty()
	var modern_future_food_available: bool = (
		_switch_actor_can_use_modern_future_food_huds(
			actor,
			actor_alive,
			actor_age
		)
	)

	return {
		"actor_id": int(actor.id),
		"actor_name": _actor_display_name(actor),
		"belongings": actor_alive,
		"belongings_available": actor_alive,
		"bending": bending_available,
		"bending_available": bending_available,
		"crown": crown_available,
		"crown_available": crown_available,
		"civic_crown_available": civic_crown_available,
		"food_lifestyle_available": modern_future_food_available,
		"grocery_store_available": modern_future_food_available,
		"restaurant_lifestyle_available": modern_future_food_available,
		"restaurant_available": modern_future_food_available,
		"industrial_food_lifestyle_expansion_slot_reserved": true,
		"rick_weapon_shop_available": rick_available,
		"boxing": boxing_available,
		"boxing_available": boxing_available,
		"superhero": superhero_available,
		"superhero_available": superhero_available,
		"superpower": superpower_available,
		"superpower_available": (
			superpower_available
			or superhero_available
		),
		"power": power_available,
		"power_available": power_available,
		"wizard": wizard_available,
		"wizard_available": wizard_available,
		"shell_only": false,
		"zero_frame_switch_truth": true
	}
func _switch_actor_can_use_modern_future_food_huds(actor: Person, actor_alive: bool, actor_age: int) -> bool:
	if actor == null:
		return false
	if not actor_alive:
		return false
	if actor_age < 15:
		return false
	return _switch_era_supports_modern_future_food_huds(_switch_current_era_name())


func _switch_current_era_name() -> String:
	if gs == null:
		return ""

	return _switch_era_name_from_year(int(gs.year))


func _switch_era_supports_modern_future_food_huds(era_name: String) -> bool:
	var clean: String = str(era_name).strip_edges().to_lower()
	clean = clean.replace(" era", "")
	clean = clean.replace(" ", "_")
	return clean == "modern" or clean == "future"


func _switch_era_name_from_year(year_value: int) -> String:
	match _switch_era_key_from_year(year_value):
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
			return ""


func _switch_era_key_from_year(year_value: int) -> String:
	if year_value <= 499:
		return "Ancient"
	if year_value <= 1799:
		return "Medieval"
	if year_value <= 1949:
		return "Industrial"
	if year_value <= 2049:
		return "Modern"
	return "Future"
func _actor_has_property(actor: Person, property_name: String) -> bool:
	if actor == null:
		return false

	var clean_property: String = str(property_name).strip_edges()
	if clean_property == "":
		return false

	for raw_property in actor.get_property_list():
		if typeof(raw_property) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = raw_property as Dictionary
		if str(row.get("name", "")).strip_edges() == clean_property:
			return true

	return false


func _actor_by_id_for_tail(actor_id: int) -> Person:
	if gs == null or actor_id <= 0:
		return null

	if gs.player != null and int(gs.player.id) == actor_id:
		return gs.player

	if gs.has_method("get_npc_by_id"):
		var found = gs.get_npc_by_id(actor_id)
		if found != null:
			return found

	if gs.has_method("get_or_reactivate_npc_by_id"):
		var restored = gs.get_or_reactivate_npc_by_id(actor_id)
		if restored != null:
			return restored

	return null

func continue_zero_frame_switch_tail(
		max_steps: int = 1
) -> Dictionary:
	_ensure_state()

	if gs == null:
		return {
			"success": false,
			"reason": "missing_game_state",
			"is_complete": true
		}

	if switch_tail_queue.is_empty():
		return {
			"success": true,
			"mode": "zero_frame_switch_tail_empty",
			"is_complete": true
		}

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var now_ms: int = int(
		Time.get_ticks_msec()
	)
	var steps: int = 0
	var completed: Array = []
	var maintenance_deferred: Array = []

	while (
		steps < maxi(1, max_steps)
		and not switch_tail_queue.is_empty()
	):
		var row: Dictionary = _shallow_dictionary(
			switch_tail_queue [0]
		)
		var next_step_ms: int = int(
			row.get(
				"next_step_ms",
				0
			)
		)

		if next_step_ms > 0 and now_ms < next_step_ms:
			break

		switch_tail_queue.pop_front()

		var contract_id: String = str(
			row.get(
				"contract_id",
				""
			)
		).strip_edges()
		var previous_actor_id: int = int(
			row.get(
				"previous_actor_id",
				-1
			)
		)
		var controlled_actor_id: int = int(
			row.get(
				"controlled_actor_id",
				-1
			)
		)
		var contract: Dictionary = _shallow_dictionary(
			switch_contracts.get(
				contract_id,
				{}
			)
		)

		var maintenance_row: Dictionary = {
			"schema": (
				"eralife.control_switch."
				+ "detached_maintenance_request"
			),
			"version": 1,
			"contract_id": contract_id,
			"previous_actor_id": previous_actor_id,
			"controlled_actor_id": controlled_actor_id,
			"source": (
				"universal_switch_contract_engine."
				+ "switch_tail"
			),
			"created_at_ms": now_ms
		}
		maintenance_deferred.append(
			maintenance_row
		)

		if not contract.is_empty():
			contract [
				"tail_stage"
			] = "detached_maintenance_recorded"
			contract [
				"tail_completed_at_ms"
			] = now_ms
			contract [
				"updated_at_ms"
			] = now_ms
			contract [
				"family_control_integrity_sync_called"
			] = false
			contract [
				"person_contract_rebuild_called"
			] = false
			contract [
				"interactive_lens_never_waits_for_integrity_repair"
			] = true
			switch_contracts [contract_id] = contract

		completed.append(contract_id)
		steps += 1

	var queue_raw: Variant = gs.scenario_state.get(
		"detached_control_switch_maintenance_queue",
		[]
	)
	var detached_queue: Array = (
		(queue_raw as Array).duplicate(false)
		if typeof(queue_raw) == TYPE_ARRAY
		else []
	)

	for maintenance_row in maintenance_deferred:
		var controlled_actor_id: int = int(
			maintenance_row.get(
				"controlled_actor_id",
				-1
			)
		)
		var already_queued: bool = false

		for queued_raw in detached_queue:
			if typeof(queued_raw) != TYPE_DICTIONARY:
				continue

			if int(
				(queued_raw as Dictionary).get(
					"controlled_actor_id",
					-1
				)
			) == controlled_actor_id:
				already_queued = true
				break

		if not already_queued:
			detached_queue.append(
				maintenance_row
			)

	while detached_queue.size() > 64:
		detached_queue.pop_front()

	gs.scenario_state [
		"detached_control_switch_maintenance_queue"
	] = detached_queue
	gs.scenario_state [
		"control_switch_deep_integrity_sync_forbidden_while_lens_attached"
	] = true
	gs.scenario_state [
		"control_switch_tail_last_completed_at_ms"
	] = now_ms

	_commit_state()

	EraLog.truth(
		(
			"ERALIFE_ENTITY_SWITCH_TAIL_TRUTH"
			+ "|completed=%d"
			+ "|remaining=%d"
			+ "|family_integrity_sync_called=false"
			+ "|person_contract_rebuild_called=false"
			+ "|maintenance_deferred=%d"
			+ "|at_ms=%d"
		)
		% [
			completed.size(),
			switch_tail_queue.size(),
			maintenance_deferred.size(),
			now_ms
		]
	)

	return {
		"success": true,
		"mode": "zero_frame_switch_tail_stepped",
		"is_complete": switch_tail_queue.is_empty(),
		"completed": completed.duplicate(true),
		"detached_maintenance_requests": (
			maintenance_deferred.duplicate(true)
		),
		"integrity_sync_deferred_for_actor_ids": [],
		"remaining": switch_tail_queue.size(),
		"interactive_lens_blocked_ms": 0
	}
func _publish_switch_contract(contract: Dictionary) -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var now_ms: int = int(Time.get_ticks_msec())
	var controlled_actor_id: int = int(contract.get("controlled_actor_id", -1))
	var controlled_actor_name: String = str(contract.get("controlled_actor_name", ""))
	var surface: Dictionary = _shallow_dictionary(contract.get("controlled_surface", {}))

	gs.scenario_state ["zero_frame_consciousness_switch_last_contract"] = contract.duplicate(true)
	gs.scenario_state ["zero_frame_consciousness_switch_last_contract_id"] = str(contract.get("contract_id", contract.get("id", "")))
	gs.scenario_state ["zero_frame_consciousness_switch_last_actor_id"] = controlled_actor_id
	gs.scenario_state ["zero_frame_consciousness_switch_last_actor_name"] = controlled_actor_name
	gs.scenario_state ["zero_frame_consciousness_switch_surface"] = surface.duplicate(true)



	gs.scenario_state ["controlled_perspective_switch_pending_ui_refresh"] = false
	gs.scenario_state ["controlled_perspective_actor_id"] = controlled_actor_id
	gs.scenario_state ["controlled_perspective_actor_name"] = controlled_actor_name
	gs.scenario_state ["controlled_perspective_source"] = "universal_switch_contract_engine_zero_frame_surface_locked"

	gs.scenario_state ["zero_frame_consciousness_switch_tail_pending"] = true
	gs.scenario_state ["zero_frame_consciousness_switch_surface_lock_active"] = true
	gs.scenario_state ["zero_frame_consciousness_switch_surface_lock_actor_id"] = controlled_actor_id
	gs.scenario_state ["zero_frame_consciousness_switch_surface_lock_until_ms"] = now_ms + 3500
	gs.scenario_state ["zero_frame_consciousness_switch_full_refresh_pending"] = false
	gs.scenario_state ["zero_frame_consciousness_switch_full_refresh_stage"] = 0
	gs.scenario_state.erase("zero_frame_consciousness_switch_full_refresh_next_ms")

	var guard_raw: Variant = gs.scenario_state.get("runtime_guard", {})
	var guard: Dictionary = guard_raw if typeof(guard_raw) == TYPE_DICTIONARY else {}
	guard ["zero_frame_consciousness_switch"] = true
	guard ["ui_is_pure_renderer"] = true
	guard ["switch_tail_after_visible_handoff"] = true
	guard ["switch_surface_lock_active"] = true
	guard ["switch_surface_lock_until_ms"] = now_ms + 3500
	guard ["defer_noncritical_systems"] = true
	guard ["defer_full_hud_rebuild"] = true
	guard ["defer_full_life_diary_rebuild"] = true
	guard ["controlled_perspective_refresh_forbidden_on_switch_frame"] = true
	guard ["ui_tail_work_yield_to_input"] = true
	guard ["last_action"] = "zero_frame_consciousness_switch_visible_commit_locked_surface"
	guard ["last_action_ms"] = now_ms
	gs.scenario_state ["runtime_guard"] = guard


func _result_for_switch(previous_actor_id: int, controlled_actor: Person, surface_contract: Dictionary, switch_contract: Dictionary, context: Dictionary) -> Dictionary:
	var actor_name: String = _actor_display_name(controlled_actor)
	var text: String = "I started living as %s." % actor_name

	return {
		"success": true,
		"type": "zero_frame_consciousness_switch",
		"text": text,
		"popup_title": "Life Switched",
		"popup_text": text,
		"popup_footer": "Tap anywhere to continue.",
		"identity_switch": true,
		"zero_frame_consciousness_switch": true,
		"previous_controlled_person_id": previous_actor_id,
		"controlled_person_id": int(controlled_actor.id) if controlled_actor != null else -1,
		"controlled_person_name": actor_name,
		"source": str(context.get("source", "universal_switch_contract_engine")),
		"surface_contract": surface_contract.duplicate(true),
		"switch_contract": switch_contract.duplicate(true)
	}
func _switch_hunger_scalar_for_actor(
	actor: Person
) -> float:
	if actor == null:
		return 0.0

	var raw_fallback_hunger: float = float(
		_safe_actor_number(
			actor,
			"hunger",
			FoodEngine.DEFAULT_STARTING_HUNGER
		)
	)
	var fallback_hunger: float = (
		FoodEngine.DEFAULT_STARTING_HUNGER
		if raw_fallback_hunger < 0.0
		else clampf(
			raw_fallback_hunger,
			0.0,
			FoodEngine.DEFAULT_MAX_HUNGER
		)
	)

	if (
		gs == null
		or gs.food_engine == null
		or not gs.food_engine.has_method(
			"hunger_scalar_contract_for_actor"
		)
	):
		return fallback_hunger

	var hunger_contract: Dictionary = (
		gs.food_engine.hunger_scalar_contract_for_actor(
			int(actor.id)
		)
	)

	if (
		not bool(
			hunger_contract.get(
				"success",
				false
			)
		)
		or int(
			hunger_contract.get(
				"actor_id",
				-1
			)
		) != int(actor.id)
	):
		return fallback_hunger

	return clampf(
		float(
			hunger_contract.get(
				"hunger",
				fallback_hunger
			)
		),
		0.0,
		FoodEngine.DEFAULT_MAX_HUNGER
	)
func _surface_contract_for_actor(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return {}

	var actor_id: int = int(actor.id)
	var skip_pending_count: bool = bool(
		context.get(
			"skip_pending_count",
			false
		)
	)
	var press_frame_commit: bool = bool(
		context.get(
			"press_frame_commit",
			false
		)
	)
	var pending_count: int = int(
		context.get(
			"pending_situations_count",
			0
		)
	)

	if not skip_pending_count and not press_frame_commit:
		if (
			gs != null
			and gs.pending_situations_engine != null
			and gs.pending_situations_engine.has_method(
				"get_pending_count"
			)
		):
			pending_count = int(
				gs.pending_situations_engine.get_pending_count(
					actor_id
				)
			)
		elif (
			gs != null
			and gs.scenario_runtime_contract_engine != null
			and gs.scenario_runtime_contract_engine.has_method(
				"get_pending_count"
			)
		):
			pending_count = int(
				gs.scenario_runtime_contract_engine.get_pending_count(
					actor_id
				)
			)

	pending_count = maxi(
		0,
		pending_count
	)

	var hud_truth: Dictionary = (
		_surface_hud_truth_for_actor(
			actor
		)
	)
	var bank_balance: int = maxi(
		0,
		int(actor.bank_balance)
	)
	var health_value: int = int(
		round(
			float(actor.health)
		)
	)
	var hunger_value: int = int(
		round(
			_switch_hunger_scalar_for_actor(
				actor
			)
		)
	)
	var mental_value: int = int(
		round(
			float(actor.mental_health)
		)
	)
	var willpower_value: int = int(
		round(
			float(
				_safe_actor_number(
					actor,
					"willpower",
					100
				)
			)
		)
	)
	var happiness_value: int = int(
		round(
			float(actor.satisfaction)
		)
	)
	var smarts_value: int = int(
		round(
			float(actor.smarts)
		)
	)
	var looks_value: int = int(
		round(
			float(actor.looks)
		)
	)
	var imagination_value: int = int(
		round(
			float(
				_safe_actor_number(
					actor,
					"imagination",
					0
				)
			)
		)
	)
	var fame_value: int = int(
		round(
			float(actor.fame)
		)
	)
	var approval_value: int = int(
		round(
			float(actor.approval)
		)
	)
	var truth_signature_source: String = (
		"%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d"
		% [
			actor_id,
			int(actor.age),
			bank_balance,
			pending_count,
			health_value,
			hunger_value,
			mental_value,
			willpower_value,
			happiness_value,
			smarts_value,
			looks_value,
			fame_value,
			approval_value
		]
	)
	var actor_truth_signature: String = str(
		truth_signature_source.hash()
	)

	return {
		"schema": SWITCH_SURFACE_SCHEMA,
		"version": CONTRACT_VERSION,
		"actor_id": actor_id,
		"actor_name": _actor_display_name(actor),
		"first_name": str(actor.first_name),
		"last_name": str(actor.last_name),
		"age": int(actor.age),
		"alive": bool(actor.alive),
		"bank_balance": bank_balance,
		"pending_situations_count": pending_count,
		"health": health_value,
		"hunger": hunger_value,
		"mental_health": mental_value,
		"willpower": willpower_value,
		"happiness": happiness_value,
		"smarts": smarts_value,
		"looks": looks_value,
		"imagination": imagination_value,
		"fame": fame_value,
		"approval": approval_value,
		"hud_truth": hud_truth,
		"actor_truth_signature": actor_truth_signature,
		"surface_signature": (
			"switch_surface:%d:%s"
			% [
				actor_id,
				actor_truth_signature
			]
		),
		"prewarmed_playable_life_shell_candidate": bool(
			context.get(
				"prewarm_only",
				false
			)
		),
		"switch_press_must_not_build_surface": true,
		"surface_policy": {
			"render_immediately": true,
			"press_only_commits_pointer": true,
		},
		"context": context.duplicate(true),
		"created_at_ms": int(
			Time.get_ticks_msec()
		)
	}
func _safe_actor_number(actor: Person, property_name: String, fallback: float = 0.0) -> float:
	if actor == null:
		return fallback

	var clean_property: String = str(property_name).strip_edges()
	if clean_property == "":
		return fallback

	for raw_property in actor.get_property_list():
		if typeof(raw_property) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = raw_property as Dictionary
		if str(row.get("name", "")).strip_edges() == clean_property:
			return float(actor.get(clean_property))

	return fallback


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


func _repair_state() -> void:
	var repaired_contracts: Dictionary = {}
	for raw_key in switch_contracts.keys():
		var contract: Dictionary = _shallow_dictionary(switch_contracts.get(raw_key, {}))
		if contract.is_empty():
			continue
		var contract_id: String = str(contract.get("contract_id", contract.get("id", raw_key))).strip_edges()
		if contract_id == "":
			continue
		contract ["schema"] = str(contract.get("schema", SWITCH_CONTRACT_SCHEMA))
		contract ["version"] = int(contract.get("version", CONTRACT_VERSION))
		contract ["contract_id"] = contract_id
		contract ["id"] = contract_id
		repaired_contracts [contract_id] = contract

	switch_contracts = repaired_contracts

	if switch_tail_queue.size() > MAX_SWITCH_TAIL_QUEUE:
		switch_tail_queue = switch_tail_queue.slice(switch_tail_queue.size() - MAX_SWITCH_TAIL_QUEUE, switch_tail_queue.size())


func _trim_contracts() -> void:
	while switch_contracts.size() > MAX_SWITCH_CONTRACTS:
		var oldest_key: String = str(switch_contracts.keys() [0])
		switch_contracts.erase(oldest_key)


func _commit_state() -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	gs.scenario_state ["universal_switch_contracts"] = switch_contracts.duplicate(true)
	gs.scenario_state ["universal_switch_tail_queue"] = switch_tail_queue.duplicate(true)
	gs.scenario_state ["universal_switch_sequence"] = switch_sequence
	gs.scenario_state ["universal_switch_last_report"] = last_report.duplicate(true)
func register_profile_pointer_packet_revision(
	packet: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	if (
		gs == null
		or typeof(gs.scenario_state) != TYPE_DICTIONARY
	):
		return {
			"success": false,
			"reason": "profile_pointer_revision_registry_unavailable"
		}

	if packet.is_empty():
		return {
			"success": false,
			"reason": "profile_pointer_packet_empty"
		}

	var packet_actor_id: int = int(
		packet.get(
			"actor_id",
			-1
		)
	)
	var surface_contract: Dictionary = _shallow_dictionary(
		packet.get(
			"surface_contract",
			{}
		)
	)
	var surface_actor_id: int = int(
		surface_contract.get(
			"actor_id",
			-1
		)
	)
	var pointer_revision: String = str(
		packet.get(
			"pointer_revision",
			surface_contract.get(
				"pointer_revision",
				""
			)
		)
	).strip_edges()

	if (
		packet_actor_id <= 0
		or surface_actor_id != packet_actor_id
		or pointer_revision == ""
	):
		return {
			"success": false,
			"reason": "profile_pointer_packet_identity_invalid",
			"packet_actor_id": packet_actor_id,
			"surface_actor_id": surface_actor_id,
			"pointer_revision": pointer_revision
		}

	var packet_revision: String = str(
		packet.get(
			"pointer_revision",
			""
		)
	).strip_edges()
	var surface_revision: String = str(
		surface_contract.get(
			"pointer_revision",
			""
		)
	).strip_edges()

	if (
		packet_revision == ""
		or surface_revision == ""
		or packet_revision != surface_revision
	):
		return {
			"success": false,
			"reason": "profile_pointer_packet_revision_inconsistent",
			"packet_actor_id": packet_actor_id,
			"packet_revision": packet_revision,
			"surface_revision": surface_revision
		}

	var registry: Dictionary = _shallow_dictionary(
		gs.scenario_state.get(
			"profile_pointer_packet_revision_registry",
			{}
		)
	)



	if registry.has(
		pointer_revision
	):
		var existing_record: Dictionary = _shallow_dictionary(
			registry.get(
				pointer_revision,
				{}
			)
		)
		var existing_packet: Dictionary = _shallow_dictionary(
			existing_record.get(
				"viewer_packet",
				{}
			)
		)

		if (
			int(
				existing_record.get(
					"actor_id",
					-1
				)
			) == packet_actor_id
			and existing_packet == packet
		):
			return {
				"success": true,
				"mode": "profile_pointer_packet_revision_already_registered",
				"actor_id": packet_actor_id,
				"pointer_revision": pointer_revision,
				"registry_size": registry.size(),
				"ready_gate_member": false,
				"registered_at_ms": int(
					existing_record.get(
						"registered_at_ms",
						0
					)
				)
			}

	var now_ms: int = int(
		Time.get_ticks_msec()
	)

	registry [pointer_revision] = {
		"schema": "eralife.profile_pointer_packet_revision_record",
		"version": CONTRACT_VERSION,
		"actor_id": packet_actor_id,
		"pointer_revision": pointer_revision,
		"viewer_packet": packet.duplicate(false),
		"registered_at_ms": now_ms,
		"context": context.duplicate(false)
	}

	while registry.size() > MAX_SWITCH_CONTRACTS * 2:
		var revision_keys: Array = registry.keys()

		if revision_keys.is_empty():
			break

		registry.erase(
			revision_keys.front()
		)

	var revisions_by_actor: Dictionary = _shallow_dictionary(
		gs.scenario_state.get(
			"profile_pointer_revisions_by_actor",
			{}
		)
	)
	var actor_key: String = str(
		packet_actor_id
	)
	var actor_revisions: Array = _safe_array(
		revisions_by_actor.get(
			actor_key,
			[]
		)
	)

	if pointer_revision not in actor_revisions:
		actor_revisions.append(
			pointer_revision
		)

	while actor_revisions.size() > 16:
		actor_revisions.pop_front()

	revisions_by_actor [actor_key] = actor_revisions

	gs.scenario_state [
		"profile_pointer_packet_revision_registry"
	] = registry
	gs.scenario_state [
		"profile_pointer_revisions_by_actor"
	] = revisions_by_actor
	gs.scenario_state [
		"profile_pointer_revision_registry_last_actor_id"
	] = packet_actor_id
	gs.scenario_state [
		"profile_pointer_revision_registry_last_revision"
	] = pointer_revision
	gs.scenario_state [
		"profile_pointer_revision_registry_last_registered_at_ms"
	] = now_ms
	gs.scenario_state [
		"profile_pointer_revision_registry_ready_gate_member"
	] = false

	return {
		"success": true,
		"mode": "profile_pointer_packet_revision_registered",
		"actor_id": packet_actor_id,
		"pointer_revision": pointer_revision,
		"registry_size": registry.size(),
		"ready_gate_member": false,
		"registered_at_ms": now_ms
	}
func queue_resident_profile_pointer_successor_refresh_for_actor(
	actor_id: int,
	source_year: int,
	target_year: int,
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	var report: Dictionary = {
		"schema": (
			"eralife.resident_profile_pointer_actor_successor_refresh_queue_report"
		),
		"version": 1,
		"success": false,
		"queued": false,
		"actor_id": actor_id,
		"source_year": source_year,
		"target_year": target_year,
		"reason": "",
		"background_only": true,
		"blocks_ui": false,
		"requires_input_idle": false,
		"build_on_click_forbidden": true,
		"ready_gate_member": false,
	}

	if (
		gs == null
		or actor_id <= 0
		or typeof(gs.scenario_state) != TYPE_DICTIONARY
	):
		report ["reason"] = "profile_pointer_registry_unavailable"
		return report

	var packet_cache: Dictionary = _shallow_dictionary(
		gs.scenario_state.get(
			"profile_pointer_packet_by_actor",
			{}
		)
	)

	var resident_packet: Dictionary = _shallow_dictionary(
		packet_cache.get(
			str(actor_id),
			{}
		)
	)



	if resident_packet.is_empty():
		report ["success"] = true
		report ["reason"] = "actor_has_no_resident_profile_pointer"
		return report

	var resident_truth: Dictionary = (
		_profile_switch_core_packet_truth(
			resident_packet,
			actor_id
		)
	)

	if not bool(
		resident_truth.get(
			"core_packet_hot",
			false
		)
	):
		report ["success"] = true
		report ["reason"] = "actor_pointer_not_structurally_resident"
		return report

	var order_raw: Variant = get_meta(
		"resident_profile_pointer_successor_refresh_order",
		[]
	)
	var order: Array = (
		(order_raw as Array).duplicate(false)
		if typeof(order_raw) == TYPE_ARRAY
		else []
	)

	var jobs_raw: Variant = get_meta(
		"resident_profile_pointer_successor_refresh_jobs",
		{}
	)
	var jobs: Dictionary = (
		(jobs_raw as Dictionary).duplicate(false)
		if typeof(jobs_raw) == TYPE_DICTIONARY
		else {}
	)




	var request_key: String = str(
		actor_id
	)
	var refresh_context: Dictionary = (
		context.duplicate(false)
	)

	refresh_context [
		"source"
	] = str(
		context.get(
			"source",
			(
				"universal_switch_contract_engine."
				+ "resident_profile_pointer_actor_successor_refresh"
			)
		)
	)
	refresh_context [
		"reason"
	] = str(
		context.get(
			"reason",
			"canonical_actor_temporal_truth_advanced"
		)
	)
	refresh_context [
		"source_year"
	] = source_year
	refresh_context [
		"target_year"
	] = target_year
	refresh_context [
		"annual_temporal_successor_refresh"
	] = true
	refresh_context [
		"targeted_temporal_successor_refresh"
	] = true
	refresh_context [
		"preserve_existing_switch_readiness"
	] = true
	refresh_context [
		"background_only"
	] = true
	refresh_context [
		"blocks_ui"
	] = false
	refresh_context [
		"requires_input_idle"
	] = false
	refresh_context [
		"ui_interaction_grace_ignored"
	] = true
	refresh_context [
		"build_on_click_forbidden"
	] = true
	refresh_context [
		"switch_press_build_forbidden"
	] = true
	refresh_context [
		"ready_gate_member"
	] = false
	refresh_context [
		"render_boundary_required"
	] = false
	refresh_context [
		"ui_is_renderer_only"
	] = true

	jobs [
		request_key
	] = {
		"request_key": request_key,
		"actor_id": actor_id,
		"source_year": source_year,
		"target_year": target_year,
		"context": refresh_context,
		"attempt_count": 0,
		"requested_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	if not order.has(
		request_key
	):
		order.append(
			request_key
		)

	set_meta(
		"resident_profile_pointer_successor_refresh_order",
		order
	)
	set_meta(
		"resident_profile_pointer_successor_refresh_jobs",
		jobs
	)
	set_meta(
		"resident_profile_pointer_successor_refresh_requires_input_idle",
		false
	)
	set_meta(
		"resident_profile_pointer_successor_refresh_blocks_ui",
		false
	)
	set_meta(
		"resident_profile_pointer_successor_refresh_ready_gate_member",
		false
	)

	_arm_resident_profile_pointer_successor_refresh_service()

	report ["success"] = true
	report ["queued"] = true
	report ["reason"] = "resident_actor_successor_refresh_queued"
	report ["queue_size"] = order.size()

	return report
func queue_resident_profile_pointer_successor_refresh(
	source_year: int,
	target_year: int,
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	var report: Dictionary = {
		"schema": (
			"eralife.resident_profile_pointer_successor_refresh_queue_report"
		),
		"version": 1,
		"success": false,
		"queued": false,
		"source_year": source_year,
		"target_year": target_year,
		"resident_packet_count": 0,
		"queued_actor_ids": [],
		"queue_size": 0,
		"reason": "",
		"background_only": true,
		"blocks_ui": false,
		"requires_input_idle": false,
		"build_on_click_forbidden": true,
		"render_boundary_required": false,
		"ready_gate_member": false,
	}

	if (
		gs == null
		or typeof(gs.scenario_state) != TYPE_DICTIONARY
	):
		report ["reason"] = "profile_pointer_registry_unavailable"
		return report

	var packet_cache: Dictionary = _shallow_dictionary(
		gs.scenario_state.get(
			"profile_pointer_packet_by_actor",
			{}
		)
	)

	report [
		"resident_packet_count"
	] = packet_cache.size()

	if packet_cache.is_empty():
		report ["success"] = true
		report ["reason"] = "no_resident_profile_pointer_packets"
		return report

	var order_raw: Variant = get_meta(
		"resident_profile_pointer_successor_refresh_order",
		[]
	)
	var order: Array = (
		(order_raw as Array).duplicate(false)
		if typeof(order_raw) == TYPE_ARRAY
		else []
	)

	var jobs_raw: Variant = get_meta(
		"resident_profile_pointer_successor_refresh_jobs",
		{}
	)
	var jobs: Dictionary = (
		(jobs_raw as Dictionary).duplicate(false)
		if typeof(jobs_raw) == TYPE_DICTIONARY
		else {}
	)

	var queued_actor_ids: Array = []
	var now_ms: int = int(
		Time.get_ticks_msec()
	)

	for raw_actor_key in packet_cache.keys():
		var actor_id: int = int(
			raw_actor_key
		)

		if actor_id <= 0:
			continue

		var resident_packet: Dictionary = _shallow_dictionary(
			packet_cache.get(
				str(actor_id),
				{}
			)
		)

		if resident_packet.is_empty():
			continue

		var resident_truth: Dictionary = (
			_profile_switch_core_packet_truth(
				resident_packet,
				actor_id
			)
		)




		if not bool(
			resident_truth.get(
				"core_packet_hot",
				false
			)
		):
			continue




		var request_key: String = str(
			actor_id
		)
		var refresh_context: Dictionary = (
			context.duplicate(false)
		)

		refresh_context [
			"source"
		] = (
			"universal_switch_contract_engine."
			+ "resident_profile_pointer_successor_refresh"
		)
		refresh_context [
			"reason"
		] = "canonical_annual_truth_advanced"
		refresh_context [
			"source_year"
		] = source_year
		refresh_context [
			"target_year"
		] = target_year
		refresh_context [
			"annual_temporal_successor_refresh"
		] = true
		refresh_context [
			"preserve_existing_switch_readiness"
		] = true
		refresh_context [
			"background_only"
		] = true
		refresh_context [
			"blocks_ui"
		] = false
		refresh_context [
			"requires_input_idle"
		] = false
		refresh_context [
			"ui_interaction_grace_ignored"
		] = true
		refresh_context [
			"build_on_click_forbidden"
		] = true
		refresh_context [
			"switch_press_build_forbidden"
		] = true
		refresh_context [
			"ready_gate_member"
		] = false
		refresh_context [
			"render_boundary_required"
		] = false
		refresh_context [
			"ui_is_renderer_only"
		] = true

		jobs [
			request_key
		] = {
			"request_key": request_key,
			"actor_id": actor_id,
			"source_year": source_year,
			"target_year": target_year,
			"context": refresh_context,
			"attempt_count": 0,
			"requested_at_ms": now_ms
		}

		if not order.has(
			request_key
		):
			order.append(
				request_key
			)

		if not queued_actor_ids.has(
			actor_id
		):
			queued_actor_ids.append(
				actor_id
			)

	set_meta(
		"resident_profile_pointer_successor_refresh_order",
		order
	)
	set_meta(
		"resident_profile_pointer_successor_refresh_jobs",
		jobs
	)
	set_meta(
		"resident_profile_pointer_successor_refresh_requires_input_idle",
		false
	)
	set_meta(
		"resident_profile_pointer_successor_refresh_blocks_ui",
		false
	)
	set_meta(
		"resident_profile_pointer_successor_refresh_ready_gate_member",
		false
	)

	_arm_resident_profile_pointer_successor_refresh_service()

	report ["success"] = true
	report [
		"queued"
	] = not queued_actor_ids.is_empty()
	report [
		"queued_actor_ids"
	] = queued_actor_ids
	report [
		"queue_size"
	] = order.size()
	report [
		"reason"
	] = (
		"resident_successor_refresh_queued"
		if not queued_actor_ids.is_empty()
		else "no_structurally_resident_switch_pointers"
	)

	return report


func _arm_resident_profile_pointer_successor_refresh_service() -> void:
	var order_raw: Variant = get_meta(
		"resident_profile_pointer_successor_refresh_order",
		[]
	)
	var order: Array = (
		order_raw as Array
		if typeof(order_raw) == TYPE_ARRAY
		else []
	)

	if order.is_empty():
		set_meta(
			"resident_profile_pointer_successor_refresh_service_active",
			false
		)
		return

	var tree:= Engine.get_main_loop() as SceneTree

	if tree == null:
		set_meta(
			"resident_profile_pointer_successor_refresh_service_active",
			false
		)
		return

	var callback:= Callable(
		self,
		"_drive_resident_profile_pointer_successor_refresh_process_frame"
	)

	if tree.process_frame.is_connected(
		callback
	):
		set_meta(
			"resident_profile_pointer_successor_refresh_service_active",
			true
		)
		return

	tree.process_frame.connect(
		callback
	)

	set_meta(
		"resident_profile_pointer_successor_refresh_service_active",
		true
	)


func _drive_resident_profile_pointer_successor_refresh_process_frame() -> void:
	var tree:= Engine.get_main_loop() as SceneTree

	var callback:= Callable(
		self,
		"_drive_resident_profile_pointer_successor_refresh_process_frame"
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

	set_meta(
		"resident_profile_pointer_successor_refresh_service_active",
		false
	)

	_service_resident_profile_pointer_successor_refresh_queue()


func _service_resident_profile_pointer_successor_refresh_queue() -> void:
	var order_raw: Variant = get_meta(
		"resident_profile_pointer_successor_refresh_order",
		[]
	)
	var order: Array = (
		(order_raw as Array).duplicate(false)
		if typeof(order_raw) == TYPE_ARRAY
		else []
	)

	if order.is_empty():
		set_meta(
			"resident_profile_pointer_successor_refresh_service_active",
			false
		)
		return

	var request_key: String = str(
		order.pop_front()
	)

	var jobs_raw: Variant = get_meta(
		"resident_profile_pointer_successor_refresh_jobs",
		{}
	)
	var jobs: Dictionary = (
		(jobs_raw as Dictionary).duplicate(false)
		if typeof(jobs_raw) == TYPE_DICTIONARY
		else {}
	)

	var job: Dictionary = _shallow_dictionary(
		jobs.get(
			request_key,
			{}
		)
	)

	jobs.erase(
		request_key
	)

	set_meta(
		"resident_profile_pointer_successor_refresh_order",
		order
	)
	set_meta(
		"resident_profile_pointer_successor_refresh_jobs",
		jobs
	)

	if job.is_empty():
		_arm_resident_profile_pointer_successor_refresh_service()
		return

	var actor_id: int = int(
		job.get(
			"actor_id",
			-1
		)
	)

	if actor_id <= 0:
		_arm_resident_profile_pointer_successor_refresh_service()
		return



	var target: Person = null

	if (
		gs != null
		and gs.player != null
		and int(
			gs.player.id
		) == actor_id
	):
		target = gs.player
	elif (
		gs != null
		and gs.has_method(
			"get_npc_by_id"
		)
	):
		target = gs.get_npc_by_id(
			actor_id,
			false
		)

	if target == null:
		set_meta(
			"resident_profile_pointer_successor_refresh_last_actor_id",
			actor_id
		)
		set_meta(
			"resident_profile_pointer_successor_refresh_last_reason",
			"resident_actor_not_indexed"
		)
		set_meta(
			"resident_profile_pointer_successor_refresh_last_at_ms",
			int(
				Time.get_ticks_msec()
			)
		)

		_arm_resident_profile_pointer_successor_refresh_service()
		return



	if (
		not bool(
			target.alive
		)
		or float(
			target.health
		) <= 0.0
	):
		set_meta(
			"resident_profile_pointer_successor_refresh_last_actor_id",
			actor_id
		)
		set_meta(
			"resident_profile_pointer_successor_refresh_last_reason",
			"target_lifecycle_terminal"
		)
		set_meta(
			"resident_profile_pointer_successor_refresh_last_at_ms",
			int(
				Time.get_ticks_msec()
			)
		)

		_arm_resident_profile_pointer_successor_refresh_service()
		return

	var packet_cache: Dictionary = _shallow_dictionary(
		gs.scenario_state.get(
			"profile_pointer_packet_by_actor",
			{}
		)
	)

	var previous_packet: Dictionary = _shallow_dictionary(
		packet_cache.get(
			str(actor_id),
			{}
		)
	)

	var previous_revision: String = str(
		previous_packet.get(
			"pointer_revision",
			""
		)
	).strip_edges()

	var refresh_context: Dictionary = _shallow_dictionary(
		job.get(
			"context",
			{}
		)
	).duplicate(false)

	refresh_context [
		"process_frame_serviced"
	] = true
	refresh_context [
		"background_only"
	] = true
	refresh_context [
		"blocks_ui"
	] = false
	refresh_context [
		"requires_input_idle"
	] = false
	refresh_context [
		"ui_interaction_grace_ignored"
	] = true
	refresh_context [
		"build_on_click_forbidden"
	] = true
	refresh_context [
		"switch_press_build_forbidden"
	] = true
	refresh_context [
		"ready_gate_member"
	] = false
	refresh_context [
		"render_boundary_required"
	] = false
	refresh_context [
		"annual_temporal_successor_refresh"
	] = true
	refresh_context [
		"preserve_existing_switch_readiness"
	] = true
	refresh_context [
		"complete_destination_deck_required"
	] = false
	refresh_context [
		"support_deck_blocks_switch"
	] = false
	refresh_context [
		"ui_is_renderer_only"
	] = true




	var successor_packet: Dictionary = (
		prepare_profile_pointer_packet(
			target,
			refresh_context
		)
	)

	var successor_truth: Dictionary = (
		_profile_switch_core_packet_truth(
			successor_packet,
			actor_id
		)
	)

	var successor_core_hot: bool = bool(
		successor_truth.get(
			"core_packet_hot",
			false
		)
	)

	var successor_revision: String = str(
		successor_truth.get(
			"pointer_revision",
			""
		)
	).strip_edges()

	if not successor_core_hot:
		var failure_reason: String = str(
			successor_packet.get(
				"reason",
				"resident_pointer_successor_not_hot"
			)
		).strip_edges()

		var attempt_count: int = int(
			job.get(
				"attempt_count",
				0
			)
		)

		var terminal_failure: bool = failure_reason in [
			"target_dead",
			"missing_target",
			"invalid_target_id"
		]

		if (
			not terminal_failure
			and attempt_count < 3
		):
			job [
				"attempt_count"
			] = attempt_count + 1
			job [
				"last_failure_reason"
			] = failure_reason
			job [
				"last_attempt_at_ms"
			] = int(
				Time.get_ticks_msec()
			)

			jobs [
				request_key
			] = job

			if not order.has(
				request_key
			):
				order.append(
					request_key
				)

			set_meta(
				"resident_profile_pointer_successor_refresh_order",
				order
			)
			set_meta(
				"resident_profile_pointer_successor_refresh_jobs",
				jobs
			)

		set_meta(
			"resident_profile_pointer_successor_refresh_last_actor_id",
			actor_id
		)
		set_meta(
			"resident_profile_pointer_successor_refresh_last_reason",
			failure_reason
		)
		set_meta(
			"resident_profile_pointer_successor_refresh_last_success",
			false
		)
		set_meta(
			"resident_profile_pointer_successor_refresh_last_at_ms",
			int(
				Time.get_ticks_msec()
			)
		)

		_arm_resident_profile_pointer_successor_refresh_service()
		return

	set_meta(
		"resident_profile_pointer_successor_refresh_last_actor_id",
		actor_id
	)
	set_meta(
		"resident_profile_pointer_successor_refresh_last_previous_revision",
		previous_revision
	)
	set_meta(
		"resident_profile_pointer_successor_refresh_last_revision",
		successor_revision
	)
	set_meta(
		"resident_profile_pointer_successor_refresh_last_revision_changed",
		successor_revision != previous_revision
	)
	set_meta(
		"resident_profile_pointer_successor_refresh_last_world_year",
		int(
			gs.year
		)
	)
	set_meta(
		"resident_profile_pointer_successor_refresh_last_age",
		int(
			target.age
		)
	)
	set_meta(
		"resident_profile_pointer_successor_refresh_last_success",
		true
	)
	set_meta(
		"resident_profile_pointer_successor_refresh_last_reason",
		"canonical_successor_resident"
	)
	set_meta(
		"resident_profile_pointer_successor_refresh_last_blocks_ui",
		false
	)
	set_meta(
		"resident_profile_pointer_successor_refresh_last_requires_input_idle",
		false
	)
	set_meta(
		"resident_profile_pointer_successor_refresh_last_ready_gate_member",
		false
	)
	set_meta(
		"resident_profile_pointer_successor_refresh_last_at_ms",
		int(
			Time.get_ticks_msec()
		)
	)




	_arm_resident_profile_pointer_successor_refresh_service()
func prepare_profile_pointer_packet(
	target: Person,
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	if gs == null:
		return {
			"success": false,
			"reason": "missing_game_state",
			"press_frame_build_forbidden": true
		}

	if target == null:
		return {
			"success": false,
			"reason": "missing_target",
			"press_frame_build_forbidden": true
		}

	var target_id: int = int(target.id)

	if target_id <= 0:
		return {
			"success": false,
			"reason": "invalid_target_id",
			"press_frame_build_forbidden": true
		}

	if (
		not bool(target.alive)
		or float(target.health) <= 0.0
	):
		return {
			"success": false,
			"reason": "target_dead",
			"target_id": target_id,
			"press_frame_build_forbidden": true
		}

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var world_year: int = int(gs.year)
	var actor_name: String = _actor_display_name(target)
	var authoritative_hunger_value: float = (
		_switch_hunger_scalar_for_actor(
			target
		)
	)
	var diary_packet: Dictionary = {}

	if (
		gs.life_diary_contract_engine != null
		and gs.life_diary_contract_engine.has_method(
			"render_packet_for_actor"
		)
	):
		diary_packet = _shallow_dictionary(
			gs.life_diary_contract_engine.render_packet_for_actor(
				target,
				{
					"source": (
						"universal_switch_contract_engine."
						+ "prepare_profile_pointer_packet"
					),
					"prewarm_only": true,
					"read_only": true,
					"switch_press_build_forbidden": true,
					"ready_gate_member": false,
					"ui_is_renderer_only": true
				}
			)
		)

	var diary_lines: Array = _safe_array(
		diary_packet.get(
			"lines",
			[]
		)
	)
	var diary_entries: Array = _safe_array(
		diary_packet.get(
			"entries",
			[]
		)
	)
	var diary_signature: String = str(
		diary_packet.get(
			"signature",
			""
		)
	).strip_edges()

	if diary_lines.is_empty():
		var year_label: String = str(world_year)

		if world_year < 0:
			year_label = str(
				absi(world_year)
			) + " BC"
		elif world_year == 0:
			year_label = "1 BC"

		diary_lines = [
			"Year: " + year_label,
			"Age: " + str(
				maxi(
					0,
					int(target.age)
				)
			),
			"My name is " + actor_name + ".",
			"This life was already in motion before I took control."
		]

	if diary_entries.is_empty():
		diary_entries = [
			diary_lines.duplicate(true)
		]

	if diary_signature == "":
		diary_signature = (
			"switch_diary:"
			+ str(target_id)
			+ ":" + str(world_year)
			+ ":" + str(int(target.age))
			+ ":" + str(diary_lines.hash())
		)

	var default_pointer_revision: String = (
		str(target_id)
		+ ":" + str(world_year)
		+ ":" + str(int(target.age))
		+ ":" + str(
			int(
				round(
					float(target.health)
				)
			)
		)
		+ ":" + str(
			int(
				round(
					authoritative_hunger_value
				)
			)
		)
		+ ":" + str(
			int(
				round(
					float(target.mental_health)
				)
			)
		)
		+ ":" + str(
			int(
				round(
					float(target.satisfaction)
				)
			)
		)
		+ ":" + str(int(target.smarts))
		+ ":" + str(int(target.looks))
		+ ":" + diary_signature
	)
	var requested_pointer_revision: String = str(
		context.get(
			"pointer_revision",
			""
		)
	).strip_edges()
	var pointer_revision: String = default_pointer_revision
	var caller_pointer_revision_ignored: bool = (
		requested_pointer_revision != ""
		and requested_pointer_revision != pointer_revision
	)

	if caller_pointer_revision_ignored:
		gs.scenario_state [
			"profile_pointer_external_revision_ignored"
		] = true
		gs.scenario_state [
			"profile_pointer_external_revision_ignored_actor_id"
		] = target_id
		gs.scenario_state [
			"profile_pointer_external_revision_value"
		] = requested_pointer_revision
		gs.scenario_state [
			"profile_pointer_canonical_revision_value"
		] = pointer_revision
		gs.scenario_state [
			"profile_pointer_external_revision_ignored_at_ms"
		] = int(
			Time.get_ticks_msec()
		)

	var packet_cache_raw: Variant = gs.scenario_state.get(
		"profile_pointer_packet_by_actor",
		{}
	)
	var packet_cache: Dictionary = (
		(packet_cache_raw as Dictionary).duplicate(false)
		if typeof(packet_cache_raw) == TYPE_DICTIONARY
		else {}
	)
	var cached_packet_raw: Variant = packet_cache.get(
		str(target_id),
		{}
	)

	if typeof(cached_packet_raw) == TYPE_DICTIONARY:
		var cached_packet: Dictionary = (
			cached_packet_raw as Dictionary
		)
		var cached_surface_raw: Variant = cached_packet.get(
			"surface_contract",
			{}
		)

		if (
			str(
				cached_packet.get(
					"pointer_revision",
					""
				)
			) == pointer_revision
			and typeof(cached_surface_raw) == TYPE_DICTIONARY
			and int(
				(cached_surface_raw as Dictionary).get(
					"actor_id",
					-1
				)
			) == target_id
		):
			var cache_hit_packet: Dictionary = (
				cached_packet.duplicate(false)
			)
			cache_hit_packet ["cache_hit"] = true
			cache_hit_packet [
				"pointer_packet_rebuilt"
			] = false

			register_profile_pointer_packet_revision(
				cache_hit_packet,
				{
					"source": str(
						context.get(
							"source",
							"prepare_profile_pointer_packet_cache_hit"
						)
					),
					"actor_id": target_id,
					"cache_hit": true,
					"ready_gate_member": false,
					"ui_is_renderer_only": true
				}
			)

			EraLog.truth(
				"PROFILE_PACKET_OBSERVABLE"
				+ "|actor_id=" + str(target_id)
				+ "|pointer_revision=" + pointer_revision
				+ "|cache_hit=true"
				+ "|published=true"
				+ "|ready_gate_member=false"
				+ "|build_on_press=false"
				+ "|at_ms=" + str(Time.get_ticks_msec())
			)

			return cache_hit_packet

	var lens_text: String = ""

	for raw_line in diary_lines:
		var line_text: String = str(
			raw_line
		).strip_edges()

		if line_text == "":
			continue

		lens_text += line_text

		if not lens_text.ends_with("\n"):
			lens_text += "\n"

	var now_ms: int = int(
		Time.get_ticks_msec()
	)
	var press_frame_lens_cache: Dictionary = {
		"actor_id": target_id,
		"actor_name": actor_name,
		"world_year": world_year,
		"age": int(target.age),
		"life_diary_text": lens_text,
		"life_diary_lines": diary_lines.duplicate(true),
		"life_diary_entries": diary_entries.duplicate(true),
		"life_diary_signature": diary_signature,
		"health": clampi(
			int(
				round(
					float(target.health)
				)
			),
			0,
			200
		),
		"hunger": clampi(
			int(
				round(
					authoritative_hunger_value
				)
			),
			0,
			100
		),
		"mental_health": clampi(
			int(
				round(
					float(target.mental_health)
				)
			),
			0,
			100
		),
		"mental": clampi(
			int(
				round(
					float(target.mental_health)
				)
			),
			0,
			100
		),
		"happiness": clampi(
			int(
				round(
					float(target.satisfaction)
				)
			),
			0,
			100
		),
		"smarts": clampi(
			int(target.smarts),
			0,
			100
		),
		"looks": clampi(
			int(target.looks),
			0,
			100
		),
	}

	var surface_contract: Dictionary = {
		"schema": "eralife.zero_frame_switch.pointer_surface",
		"version": CONTRACT_VERSION,
		"actor_id": target_id,
		"actor_name": actor_name,
		"current_panel": "life",
		"world_year": world_year,
		"age": int(target.age),
		"pointer_revision": pointer_revision,
		"life_diary_lines": diary_lines.duplicate(true),
		"life_diary_entries": diary_entries.duplicate(true),
		"life_diary_signature": diary_signature,
		"press_frame_lens_cache": press_frame_lens_cache,
		"pointer_revision_authority": "UniversalSwitchContractEngine",
		"surface_hot": true,
		"press_frame_ready": true,
		"pointer_only": true,
		"pointer_only_profile_packet": true,
		"full_surface_graph_required": false,
		"switch_commit_blocked_by_support_deck": false,
		"switch_press_must_not_build_surface": true,
		"ready_gate_member": false,
		"created_at_ms": now_ms,
		"ui_is_renderer_only": true
	}
	var pointer_destination_deck: Dictionary = (
		_pointer_only_destination_deck_for_actor(
			target,
			surface_contract,
			{
				"source": "prepare_profile_pointer_packet.pointer_destination_deck",
				"requested_pointer_revision": pointer_revision,
				"ready_gate_member": false,
				"ui_is_renderer_only": true
			}
		)
	)

	surface_contract [
		"main_tab_surface_contracts"
	] = pointer_destination_deck.duplicate(false)
	surface_contract [
		"main_tab_surface_deck_hot"
	] = false
	surface_contract [
		"support_main_tab_deck_hot"
	] = false
	surface_contract [
		"pointer_destination_deck_hot"
	] = true
	surface_contract [
		"support_deck_blocks_switch"
	] = false

	var viewer_packet: Dictionary = {
		"success": true,
		"schema": "eralife.playable_life_viewer.render_packet",
		"version": CONTRACT_VERSION,
		"actor_id": target_id,
		"actor_name": actor_name,
		"world_year": world_year,
		"pointer_revision": pointer_revision,
		"pointer_revision_authority": "UniversalSwitchContractEngine",
		"caller_pointer_revision_ignored": caller_pointer_revision_ignored,
		"life_diary_packet": {
			"schema": "eralife.life_diary.render_packet",
			"version": 1,
			"actor_id": target_id,
			"actor_name": actor_name,
			"entries": diary_entries.duplicate(true),
			"lines": diary_lines.duplicate(true),
			"signature": diary_signature,
			"source_of_truth": "LifeDiaryContractEngine",
		},
		"life_diary_lines": diary_lines.duplicate(true),
		"life_diary_entries": diary_entries.duplicate(true),
		"life_diary_signature": diary_signature,
		"surface_contract": surface_contract,
		"press_frame_lens_cache": press_frame_lens_cache,
		"main_tab_surface_contracts": pointer_destination_deck.duplicate(false),
		"main_tab_surface_deck_hot": false,
		"pointer_destination_deck_hot": true,
		"support_main_tab_deck_hot": false,
		"support_deck_blocks_switch": false,
		"render_policy": {
			"viewer_waits": false,
			"viewer_calls_simulation": false,
			"viewer_mutates_simulation_state": false,
			"viewer_fetches_data": false,
			"viewer_rebuilds_layout": false,
			"render_immediately": true,
			"press_only_commits_pointer": true,
			"full_surface_graph_required": false,
		},
		"pointer_only_profile_packet": true,
		"press_frame_build_forbidden": true,
		"pointer_packet_rebuilt": true,
		"cache_hit": false,
		"created_at_ms": now_ms,
		"context": context.duplicate(false),
		"ready_gate_member": false,
		"ui_is_renderer_only": true
	}

	EraLog.truth(
		"PROFILE_PACKET_CREATED"
		+ "|actor_id=" + str(target_id)
		+ "|pointer_revision=" + pointer_revision
		+ "|year=" + str(world_year)
		+ "|age=" + str(int(target.age))
		+ "|diary_lines=" + str(diary_lines.size())
		+ "|pointer_destination_deck_hot=true"
		+ "|support_deck_hot=false"
		+ "|support_blocks_switch=false"
		+ "|build_on_press=false"
		+ "|at_ms=" + str(now_ms)
	)

	packet_cache [str(target_id)] = viewer_packet.duplicate(false)
	gs.scenario_state [
		"profile_pointer_packet_by_actor"
	] = packet_cache
	gs.scenario_state [
		"profile_pointer_packet_last_actor_id"
	] = target_id
	gs.scenario_state [
		"profile_pointer_packet_last_revision"
	] = pointer_revision
	gs.scenario_state [
		"profile_pointer_packet_last_created_at_ms"
	] = now_ms
	gs.scenario_state [
		"profile_pointer_packet_press_build_forbidden"
	] = true
	gs.scenario_state [
		"profile_pointer_packet_support_deck_blocks_switch"
	] = false
	gs.scenario_state [
		"profile_pointer_packet_pointer_destination_deck_hot"
	] = true

	var registration_report: Dictionary = (
		register_profile_pointer_packet_revision(
			viewer_packet,
			{
				"source": str(
					context.get(
						"source",
						"prepare_profile_pointer_packet"
					)
				),
				"actor_id": target_id,
				"relationship_profile_packet": bool(
					context.get(
						"relationship_profile_packet",
						false
					)
				),
				"ready_gate_member": false,
				"ui_is_renderer_only": true
			}
		)
	)

	EraLog.truth(
		"PROFILE_PACKET_PUBLISHED"
		+ "|actor_id=" + str(target_id)
		+ "|pointer_revision=" + pointer_revision
		+ "|cache_written=true"
		+ "|registered="
		+ str(
			bool(
				registration_report.get(
					"success",
					false
				)
			)
		).to_lower()
		+ "|observable_registry=profile_pointer_packet_by_actor"
		+ "|revision_registry=profile_pointer_packet_revision_registry"
		+ "|support_blocks_switch=false"
		+ "|ready_gate_member=false"
		+ "|build_on_press=false"
		+ "|at_ms=" + str(Time.get_ticks_msec())
	)

	EraLog.truth(
		"ERALIFE_ENTITY_SWITCH_PACKET_TRUTH"
		+ "|actor_id=" + str(target_id)
		+ "|year=" + str(world_year)
		+ "|age=" + str(int(target.age))
		+ "|diary_lines=" + str(diary_lines.size())
		+ "|diary_signature=" + diary_signature
		+ "|generic_switch_sentence=false"
		+ "|press_frame_build=false"
		+ "|at_ms=" + str(now_ms)
	)

	return viewer_packet.duplicate(false)
func _profile_switch_core_packet_truth(
	packet: Dictionary,
	target_id: int
) -> Dictionary:
	var surface_contract: Dictionary = _shallow_dictionary(
		packet.get(
			"surface_contract",
			{}
		)
	)
	var main_tab_deck: Dictionary = _shallow_dictionary(
		packet.get(
			"main_tab_surface_contracts",
			surface_contract.get(
				"main_tab_surface_contracts",
				{}
			)
		)
	)
	var pending_situations_payload: Dictionary = _shallow_dictionary(
		packet.get(
			"pending_situations_payload",
			surface_contract.get(
				"pending_situations_payload",
				main_tab_deck.get(
					"pending_situations",
					{}
				)
			)
		)
	)
	var pointer_revision: String = str(
		packet.get(
			"pointer_revision",
			surface_contract.get(
				"pointer_revision",
				""
			)
		)
	).strip_edges()
	var surface_revision: String = str(
		surface_contract.get(
			"pointer_revision",
			""
		)
	).strip_edges()
	var missing_main_tabs: Array = []
	var actor_mismatch_tabs: Array = []
	var pointer_only_tabs: Array = []

	for raw_tab_id in [
		"relationships",
		"school",
		"activities",
		"career",
		"mods"
	]:
		var tab_id: String = str(
			raw_tab_id
		)
		var tab_contract: Dictionary = _shallow_dictionary(
			main_tab_deck.get(
				tab_id,
				{}
			)
		)

		if tab_contract.is_empty():
			missing_main_tabs.append(
				tab_id
			)
			continue

		if int(
			tab_contract.get(
				"actor_id",
				-1
			)
		) != target_id:
			actor_mismatch_tabs.append(
				tab_id
			)
			missing_main_tabs.append(
				tab_id
			)
			continue

		var tab_schema: String = str(
			tab_contract.get(
				"schema",
				""
			)
		).strip_edges().to_lower()
		var tab_truth_state: String = str(
			tab_contract.get(
				"truth_state",
				""
			)
		).strip_edges().to_lower()

		if (
			tab_schema
			== "eralife.pointer_only.destination_tab_contract"
			or tab_truth_state
			== "pointer_only_resident_shell"
			or bool(
				tab_contract.get(
					"pointer_only",
					false
				)
			)
		):
			pointer_only_tabs.append(
				tab_id
			)
			missing_main_tabs.append(
				tab_id
			)

	var packet_actor_matches: bool = (
		int(
			packet.get(
				"actor_id",
				-1
			)
		) == target_id
	)
	var surface_actor_matches: bool = (
		int(
			surface_contract.get(
				"actor_id",
				-1
			)
		) == target_id
	)
	var revision_consistent: bool = (
		pointer_revision != ""
		and pointer_revision == surface_revision
	)
	var press_build_forbidden: bool = bool(
		packet.get(
			"press_frame_build_forbidden",
			packet.get(
				"switch_press_build_forbidden",
				true
			)
		)
	)
	var pointer_only_packet: bool = bool(
		packet.get(
			"pointer_only_profile_packet",
			surface_contract.get(
				"pointer_only_profile_packet",
				false
			)
		)
	)
	var full_surface_graph_required: bool = bool(
		surface_contract.get(
			"full_surface_graph_required",
			packet.get(
				"full_surface_graph_required",
				false
			)
		)
	)

	var diary_lines: Array = _safe_array(
		packet.get(
			"life_diary_lines",
			surface_contract.get(
				"life_diary_lines",
				[]
			)
		)
	)
	var diary_signature: String = str(
		packet.get(
			"life_diary_signature",
			surface_contract.get(
				"life_diary_signature",
				""
			)
		)
	).strip_edges()
	var diary_packet: Dictionary = _shallow_dictionary(
		packet.get(
			"life_diary_packet",
			surface_contract.get(
				"life_diary_packet",
				{}
			)
		)
	)
	var diary_hot: bool = (
		not diary_lines.is_empty()
		or diary_signature != ""
		or not diary_packet.is_empty()
	)

	var press_frame_lens_cache: Dictionary = _shallow_dictionary(
		packet.get(
			"press_frame_lens_cache",
			surface_contract.get(
				"press_frame_lens_cache",
				{}
			)
		)
	)
	var press_frame_lens_cache_matches: bool = (
		press_frame_lens_cache.is_empty()
		or int(
			press_frame_lens_cache.get(
				"actor_id",
				target_id
			)
		) == target_id
	)







	var current_world_year: int = -999999
	if gs != null:
		current_world_year = int(
			gs.year
		)

	var packet_world_year: int = int(
		packet.get(
			"world_year",
			-999999
		)
	)
	var surface_world_year: int = int(
		surface_contract.get(
			"world_year",
			-999999
		)
	)
	var lens_world_year: int = int(
		press_frame_lens_cache.get(
			"world_year",
			-999999
		)
	)
	var surface_age: int = int(
		surface_contract.get(
			"age",
			-1
		)
	)
	var lens_age: int = int(
		press_frame_lens_cache.get(
			"age",
			-1
		)
	)
	var lens_diary_text: String = str(
		press_frame_lens_cache.get(
			"life_diary_text",
			""
		)
	).strip_edges()

	var pointer_revision_actor_id: int = -1
	var pointer_revision_world_year: int = -999999
	var pointer_revision_age: int = -1
	var pointer_revision_parts: PackedStringArray = (
		pointer_revision.split(":")
	)

	if (
		pointer_revision_parts.size() >= 3
		and str(
			pointer_revision_parts [0]
		).is_valid_int()
		and str(
			pointer_revision_parts [1]
		).is_valid_int()
		and str(
			pointer_revision_parts [2]
		).is_valid_int()
	):
		pointer_revision_actor_id = int(
			pointer_revision_parts [0]
		)
		pointer_revision_world_year = int(
			pointer_revision_parts [1]
		)
		pointer_revision_age = int(
			pointer_revision_parts [2]
		)

	var temporal_pointer_hot: bool = (
		current_world_year != -999999
		and not press_frame_lens_cache.is_empty()
		and pointer_revision_actor_id == target_id
		and pointer_revision_world_year == current_world_year
		and packet_world_year == current_world_year
		and surface_world_year == current_world_year
		and lens_world_year == current_world_year
		and pointer_revision_age >= 0
		and surface_age == pointer_revision_age
		and lens_age == pointer_revision_age
		and lens_diary_text != ""
	)












	var viewpoint_pointer_hot: bool = (
		not packet.is_empty()
		and not surface_contract.is_empty()
		and packet_actor_matches
		and surface_actor_matches
		and revision_consistent
		and press_build_forbidden
		and press_frame_lens_cache_matches
		and (
			diary_hot
			or pointer_only_packet
		)
	)

	var support_deck_hot: bool = (
		not main_tab_deck.is_empty()
		and missing_main_tabs.is_empty()
		and actor_mismatch_tabs.is_empty()
		and pointer_only_tabs.is_empty()
	)

	var pending_situations_hot: bool = (
		pending_situations_payload.is_empty()
		or (
			bool(
				pending_situations_payload.get(
					"success",
					true
				)
			)
			and int(
				pending_situations_payload.get(
					"actor_id",
					target_id
				)
			) == target_id
		)
	)

	var actor_lens_bundle_hot: bool = (
		viewpoint_pointer_hot
		and support_deck_hot
		and pending_situations_hot
	)
	var support_enrichment_pending: bool = (
		viewpoint_pointer_hot
		and (
			not support_deck_hot
			or not pending_situations_hot
		)
	)

	return {
		"core_packet_hot": viewpoint_pointer_hot,
		"actor_lens_bundle_hot": actor_lens_bundle_hot,
		"viewpoint_pointer_hot": viewpoint_pointer_hot,
		"support_main_tab_deck_hot": support_deck_hot,
		"pending_situations_surface_hot": (
			pending_situations_hot
		),
		"support_enrichment_pending": support_enrichment_pending,
		"full_surface_graph_required_for_enrichment": (
			full_surface_graph_required
		),
		"switch_commit_blocked_by_support_deck": false,
		"actor_id": int(
			packet.get(
				"actor_id",
				-1
			)
		),
		"target_id": target_id,
		"packet_actor_matches": packet_actor_matches,
		"surface_actor_id": int(
			surface_contract.get(
				"actor_id",
				-1
			)
		),
		"surface_actor_matches": surface_actor_matches,
		"pointer_revision": pointer_revision,
		"surface_revision": surface_revision,
		"revision_consistent": revision_consistent,
		"temporal_pointer_hot": temporal_pointer_hot,
		"current_world_year": current_world_year,
		"packet_world_year": packet_world_year,
		"surface_world_year": surface_world_year,
		"lens_world_year": lens_world_year,
		"pointer_revision_actor_id": pointer_revision_actor_id,
		"pointer_revision_world_year": pointer_revision_world_year,
		"pointer_revision_age": pointer_revision_age,
		"surface_age": surface_age,
		"lens_age": lens_age,
		"main_tab_surface_contracts": main_tab_deck,
		"main_tab_surface_deck_present": (
			not main_tab_deck.is_empty()
		),
		"missing_main_tabs": missing_main_tabs,
		"actor_mismatch_tabs": actor_mismatch_tabs,
		"pointer_only_tabs": pointer_only_tabs,
		"press_frame_build_forbidden": (
			press_build_forbidden
		),
		"pointer_only_profile_packet": pointer_only_packet,
		"diary_hot": diary_hot,
		"optional_support_surfaces_hot": bool(
			packet.get(
				"optional_support_surfaces_hot",
				packet.get(
					"control_switch_support_surfaces_hot",
					surface_contract.get(
						"optional_support_surfaces_hot",
						surface_contract.get(
							"control_switch_support_surfaces_hot",
							false
						)
					)
				)
			)
		)
	}
func commit_profile_switch_intent(
	target: Person,
	payload: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	if target == null:
		return {
			"success": false,
			"reason": "missing_target",
			"press_frame_build_forbidden": true
		}

	var target_id: int = int(
		target.id
	)

	if target_id <= 0:
		return {
			"success": false,
			"reason": "invalid_target_id",
			"press_frame_build_forbidden": true
		}

	if (
		gs == null
		or typeof(gs.scenario_state) != TYPE_DICTIONARY
	):
		return {
			"success": false,
			"reason": "profile_switch_packet_cache_unavailable",
			"target_id": target_id,
			"press_frame_build_forbidden": true,
		}

	var requested_revision: String = str(
		payload.get(
			"pointer_revision",
			""
		)
	).strip_edges()
	var prepared_actor_id: int = int(
		payload.get(
			"prepared_actor_id",
			payload.get(
				"actor_id",
				target_id
			)
		)
	)

	if requested_revision == "":
		return {
			"success": false,
			"reason": "profile_switch_pointer_revision_missing",
			"target_id": target_id,
			"press_frame_build_forbidden": true,
		}

	if prepared_actor_id != target_id:
		return {
			"success": false,
			"reason": "profile_switch_prepared_actor_mismatch",
			"target_id": target_id,
			"prepared_actor_id": prepared_actor_id,
			"requested_pointer_revision": requested_revision,
			"press_frame_build_forbidden": true,
		}

	var revision_registry: Dictionary = _shallow_dictionary(
		gs.scenario_state.get(
			"profile_pointer_packet_revision_registry",
			{}
		)
	)
	var requested_record: Dictionary = _shallow_dictionary(
		revision_registry.get(
			requested_revision,
			{}
		)
	)
	var requested_packet: Dictionary = _shallow_dictionary(
		requested_record.get(
			"viewer_packet",
			{}
		)
	)
	var requested_truth: Dictionary = (
		_profile_switch_core_packet_truth(
			requested_packet,
			target_id
		)
	)
	var requested_revision_known: bool = (
		not requested_record.is_empty()
		and int(
			requested_record.get(
				"actor_id",
				-1
			)
		) == target_id
		and str(
			requested_record.get(
				"pointer_revision",
				""
			)
		).strip_edges() == requested_revision
	)

	var packet_cache: Dictionary = _shallow_dictionary(
		gs.scenario_state.get(
			"profile_pointer_packet_by_actor",
			{}
		)
	)
	var latest_packet: Dictionary = _shallow_dictionary(
		packet_cache.get(
			str(target_id),
			{}
		)
	)
	var latest_truth: Dictionary = (
		_profile_switch_core_packet_truth(
			latest_packet,
			target_id
		)
	)
	var latest_revision: String = str(
		latest_truth.get(
			"pointer_revision",
			""
		)
	).strip_edges()



	if (
		not requested_revision_known
		and latest_revision == requested_revision
		and int(
			latest_packet.get(
				"actor_id",
				-1
			)
		) == target_id
	):
		requested_revision_known = true

	var viewer_packet: Dictionary = {}
	var selected_truth: Dictionary = {}
	var selected_revision: String = ""
	var canonical_successor_used: bool = false







	if (
		requested_revision_known
		and latest_revision != ""
		and latest_revision != requested_revision
		and bool(
			latest_truth.get(
				"core_packet_hot",
				false
			)
		)
	):
		viewer_packet = latest_packet
		selected_truth = latest_truth
		selected_revision = latest_revision
		canonical_successor_used = true

	elif bool(
		requested_truth.get(
			"core_packet_hot",
			false
		)
	):
		viewer_packet = requested_packet
		selected_truth = requested_truth
		selected_revision = requested_revision

	elif (
		requested_revision_known
		and bool(
			latest_truth.get(
				"core_packet_hot",
				false
			)
		)
	):



		viewer_packet = latest_packet
		selected_truth = latest_truth
		selected_revision = latest_revision
		canonical_successor_used = (
			selected_revision != requested_revision
		)

	var core_switch_packet_hot: bool = bool(
		selected_truth.get(
			"core_packet_hot",
			false
		)
	)
	var optional_support_surfaces_hot: bool = bool(
		selected_truth.get(
			"optional_support_surfaces_hot",
			false
		)
	)

	if not core_switch_packet_hot:
		var failure_report: Dictionary = {
			"success": false,
			"reason": "profile_switch_core_packet_not_prepared",
			"target_id": target_id,
			"prepared_actor_id": prepared_actor_id,
			"requested_pointer_revision": requested_revision,
			"requested_revision_known": requested_revision_known,
			"requested_packet_core_hot": bool(
				requested_truth.get(
					"core_packet_hot",
					false
				)
			),
			"requested_packet_missing_main_tabs": _safe_array(
				requested_truth.get(
					"missing_main_tabs",
					[]
				)
			),
			"latest_pointer_revision": latest_revision,
			"latest_packet_core_hot": bool(
				latest_truth.get(
					"core_packet_hot",
					false
				)
			),
			"latest_packet_actor_id": int(
				latest_truth.get(
					"actor_id",
					-1
				)
			),
			"latest_surface_actor_id": int(
				latest_truth.get(
					"surface_actor_id",
					-1
				)
			),
			"latest_main_tab_surface_deck_present": bool(
				latest_truth.get(
					"main_tab_surface_deck_present",
					false
				)
			),
			"latest_missing_main_tabs": _safe_array(
				latest_truth.get(
					"missing_main_tabs",
					[]
				)
			),
			"optional_support_surfaces_hot": bool(
				latest_truth.get(
					"optional_support_surfaces_hot",
					false
				)
			),
			"press_frame_build_forbidden": true,
		}

		gs.scenario_state [
			"profile_switch_core_packet_last_rejection"
		] = failure_report.duplicate(true)
		gs.scenario_state [
			"profile_switch_core_packet_last_rejection_at_ms"
		] = int(
			Time.get_ticks_msec()
		)

		EraLog.truth(
			"ERALIFE_PROFILE_SWITCH_CORE_PACKET_TRUTH"
			+ "|actor_id=" + str(target_id)
			+ "|requested_revision_known="
			+ str(requested_revision_known).to_lower()
			+ "|requested_core_hot="
			+ str(
				bool(
					requested_truth.get(
						"core_packet_hot",
						false
					)
				)
			).to_lower()
			+ "|latest_core_hot="
			+ str(
				bool(
					latest_truth.get(
						"core_packet_hot",
						false
					)
				)
			).to_lower()
			+ "|main_tabs_present="
			+ str(
				bool(
					latest_truth.get(
						"main_tab_surface_deck_present",
						false
					)
				)
			).to_lower()
			+ "|missing_main_tabs="
			+ str(
				latest_truth.get(
					"missing_main_tabs",
					[]
				)
			)
			+ "|press_build=false"
			+ "|at_ms=" + str(Time.get_ticks_msec())
		)

		return failure_report

	var source: String = str(
		payload.get(
			"source",
			"relationship_profile_panel_switch"
		)
	)
	var commit_report: Dictionary = (
		claim_visible_truth_anchor_pointer_only(
			target,
			viewer_packet,
			{
				"source": source,
				"press_frame_commit": true,
				"press_frame_build_forbidden": true,
				"requested_pointer_revision": requested_revision,
				"committed_pointer_revision": selected_revision,
				"canonical_successor_used": canonical_successor_used,
				"hidden_surface_projection_policy": (
					"resident_actor_projection_publication"
				),
				"optional_support_surfaces_hot": (
					optional_support_surfaces_hot
				),
				"ui_is_renderer_only": true
			}
		)
	)

	if not bool(
		commit_report.get(
			"success",
			false
		)
	):
		return commit_report

	var result: Dictionary = _shallow_dictionary(
		commit_report.get(
			"result",
			{}
		)
	)
	var previous_actor_id: int = int(
		commit_report.get(
			"previous_actor_id",
			result.get(
				"previous_controlled_person_id",
				-1
			)
		)
	)
	var now_ms: int = int(
		Time.get_ticks_msec()
	)

	gs.scenario_state [
		"profile_switch_core_packet_last_committed_actor_id"
	] = target_id
	gs.scenario_state [
		"profile_switch_core_packet_last_requested_revision"
	] = requested_revision
	gs.scenario_state [
		"profile_switch_core_packet_last_committed_revision"
	] = selected_revision
	gs.scenario_state [
		"profile_switch_core_packet_last_canonical_successor_used"
	] = canonical_successor_used
	gs.scenario_state [
		"profile_switch_core_packet_last_committed_at_ms"
	] = now_ms




	gs.scenario_state [
		"controlled_actor_projection_rebind_pending"
	] = true
	gs.scenario_state [
		"controlled_actor_projection_rebind_actor_id"
	] = target_id
	gs.scenario_state [
		"controlled_actor_projection_rebind_previous_actor_id"
	] = previous_actor_id
	gs.scenario_state [
		"controlled_actor_projection_rebind_waits_for_presented_lens"
	] = true

	gs.scenario_state [
		"controlled_actor_projection_rebind_deferred_until_surface_intent"
	] = false
	gs.scenario_state [
		"controlled_actor_projection_rebind_ready_gate_member"
	] = false
	gs.scenario_state [
		"controlled_actor_projection_rebind_main_scene_requested"
	] = false

	call_deferred(
		"_queue_attached_actor_projection_rebind_after_visible_pointer_switch",
		target_id,
		previous_actor_id,
		source
	)

	EraLog.truth(
		"ERALIFE_PROFILE_SWITCH_CORE_PACKET_TRUTH"
		+ "|actor_id=" + str(target_id)
		+ "|requested_revision_known=true"
		+ "|requested_revision="
		+ requested_revision
		+ "|committed_revision="
		+ selected_revision
		+ "|canonical_successor_used="
		+ str(canonical_successor_used).to_lower()
		+ "|core_hot=true"
		+ "|support_main_tabs_hot="
		+ str(
			bool(
				selected_truth.get(
					"support_main_tab_deck_hot",
					false
				)
			)
		).to_lower()
		+ "|optional_support_hot="
		+ str(optional_support_surfaces_hot).to_lower()
		+ "|projection_rebind_scheduled=true"
		+ "|projection_rebind_after_presented_frame=true"
		+ "|press_build=false"
		+ "|at_ms=" + str(now_ms)
	)

	return {
		"success": true,
		"mode": "relationship_profile_pointer_switch_committed",
		"previous_actor_id": previous_actor_id,
		"controlled_actor_id": target_id,
		"controlled_actor_name": str(
			commit_report.get(
				"controlled_actor_name",
				result.get(
					"controlled_person_name",
					""
				)
			)
		),
		"requested_pointer_revision": requested_revision,
		"pointer_revision": selected_revision,
		"canonical_successor_used": canonical_successor_used,
		"surface_contract": {
			"actor_id": target_id,
			"pointer_revision": selected_revision,
			"requested_pointer_revision": requested_revision,
			"pointer_only": true,
			"surface_hot": true,
			"main_tab_surface_deck_hot": bool(
				selected_truth.get(
					"support_main_tab_deck_hot",
					false
				)
			),
			"optional_support_surfaces_hot": (
				optional_support_surfaces_hot
			),
			"canonical_successor_used": canonical_successor_used,
		},
		"result": result,
		"optional_support_surfaces_hot": (
			optional_support_surfaces_hot
		),
		"press_frame_build_forbidden": true,
		"ready_gate_member": false,
		"ui_is_renderer_only": true
	}
func _shallow_dictionary(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(false)
	return {}


func _safe_array(value: Variant) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return (value as Array).duplicate(true)
	return []