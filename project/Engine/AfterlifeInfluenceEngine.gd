extends Resource
class_name AfterlifeInfluenceEngine

var gs
var death_entry_enrichment_queue: Array = []
var death_entry_enrichment_service_active: bool = false
var continue_lineage_destination_prewarm_queue: Array = []
var continue_lineage_destination_prewarm_service_active: bool = false
signal continue_lineage_commit_published(
	result: Dictionary
)

var continue_known_destination_prewarm_queue: Array = []
var continue_known_destination_prewarm_keys: Dictionary = {}
var continue_known_destination_prewarm_service_active: bool = false
var continue_lineage_destination_publication_bound: bool = false
func _init(_gs):
	gs = _gs





func on_player_died(payload:= {}) -> void:
	if gs == null or gs.player == null:
		return

	if gs.afterlife_active and int(gs.afterlife_state.get("ghost_player_id", -1)) == int(gs.player.id):
		return

	enter_afterlife_for_player(gs.player, payload)


func on_npc_born(arg:= {}) -> void:
	if gs == null or not gs.afterlife_active:
		return

	var newborn: Person = _resolve_person(arg)
	if newborn == null:
		return

	var touched: Array = _get_touched_bloodline_ids()
	for pid in newborn.parents:
		if int(pid) in touched:
			if newborn.id not in touched:
				touched.append(newborn.id)
				gs.afterlife_state ["touched_bloodline_ids"] = touched
			return


func enter_afterlife_for_player(
	player: Person,
	payload:= {}
) -> void:
	if (
		player == null
		or gs == null
	):
		return

	var ghost_name: String = (
		"%s %s"
		% [
			player.first_name,
			player.last_name
		]
	).strip_edges()

	var death_cause: String = str(
		payload.get(
			"cause",
			player.cause_of_death
		)
	)

	var death_era_name: String = ""

	if gs.era != null:
		death_era_name = str(
			gs.era.name
		)

	var lineage_key: String = (
		"ghost_%d"
		% int(
			player.id
		)
	)






	gs.afterlife_active = true
	gs.awaiting_new_life = true
	gs.transient_afterlife_biases.clear()

	gs.afterlife_state = {
		"ghost_player_id": int(
			player.id
		),
		"ghost_name": ghost_name,
		"ghost_personal_net_worth": 0.0,
		"ghost_family_net_worth": 0.0,
		"ghost_consciousness": {},
		"ghost_consciousness_mode": "pure_consciousness",
		"anchored_descendant_id": -1,



		"continue_lineage_target_id": -1,
		"continue_lineage_selection_kind": "lineage",
		"continue_lineage_transfer_estate": false,
		"continue_lineage_transfer_applied": false,
		"continue_lineage_commit_intent": {},

		"continue_lineage_destination_prewarm_pending": true,
		"continue_lineage_destination_prewarm_complete": false,
		"continue_lineage_destination_prewarm_actor_id": -1,
		"continue_lineage_destination_prewarm_failures": {},
		"continue_lineage_perspective_handoff_by_actor": {},



		"continue_known_person_candidate_contracts": [],
		"continue_known_destination_prewarm_pending": true,
		"continue_known_destination_prewarm_complete": false,

		"pending_mode": "death_prompt",
		"pending_type": "afterlife_death_prompt",
		"pending_text": (
			"Cause of death: %s\n\nChoose what happens next."
			% death_cause
		),
		"pending_lookup": {
			"The After Life": {
				"action": "enter_afterlife_overlay"
			},
			"Continue Lineage": {
				"action": "continue_lineage"
			},
			"Continue as someone you know": {
				"action": "continue_known_person"
			},
			"Random Life": {
				"action": "random_life"
			},
			"Custom Life": {
				"action": "custom_life"
			},
			"Rewind One Year": {
				"action": "rewind_one_year"
			}
		},
		"pending_options": [
			"The After Life",
			"Continue Lineage",
			"Continue as someone you know",
			"Random Life",
			"Custom Life",
			"Rewind One Year"
		],
		"selected_intervention": {},
		"selected_interventions": [],
		"round_index": 0,
		"scenario_index": 0,
		"round_scenarios": [],
		"round_results": [],
		"round_score": 0.0,
		"round_ready_to_advance": false,
		"total_rounds": 3,
		"scenarios_per_round": 3,
		"last_resolution": {},
		"reincarnation_progress": 0.0,
		"good_karma": 0.0,
		"bad_karma": 0.0,
		"generational_curse": false,
		"reincarnation_slot_candidates": [],
		"death_cause": death_cause,
		"death_era_name": death_era_name,
		"lineage_key": lineage_key,
		"touched_bloodline_ids": [],
		"manual_player_inheritance_authority": true,
		"ui_lock_tabs": true,
		"death_popup_open": true,
		"overlay_open": false,
		"death_entry_core_hot_at_ms": int(
			Time.get_ticks_msec()
		),
		"death_entry_enrichment_pending": true,
		"death_entry_enrichment_complete": false,
		"death_entry_enrichment_stage": "queued",
		"death_entry_enrichment_requires_ui_idle": false,
		"ui_is_renderer_only": true
	}

	if not gs.lineage_influence_profiles.has(
		lineage_key
	):
		gs.lineage_influence_profiles [
			lineage_key
		] = {
			"family_discipline": 0.0,
			"reckless_ambition": 0.0,
			"spiritual_sensitivity": 0.0,
			"moral_caution": 0.0,
			"criminal_attraction": 0.0,
			"emotional_volatility": 0.0,
			"reverence_for_legacy": 0.0,
			"stubborn_resistance_to_control": 0.0
		}


	_bind_continue_lineage_destination_publication()

	_queue_death_entry_enrichment(
		int(
			player.id
		),
		death_cause
	)


	_queue_continue_lineage_destination_prewarm(
		int(
			player.id
		)
	)



	_queue_continue_known_destination_prewarm(
		int(
			player.id
		)
	)

func _continuation_relationship_label(
	dead_player: Person,
	target: Person
) -> String:
	if (
		dead_player == null
		or target == null
	):
		return "Relationship"

	if (
		gs != null
		and gs.relationships_hub_contract_engine != null
		and gs.relationships_hub_contract_engine.has_method(
			"continuation_relationship_label_for_pair"
		)
	):
		var relationship_label: String = str(
			gs.relationships_hub_contract_engine
			.continuation_relationship_label_for_pair(
				dead_player,
				target
			)
		).strip_edges()

		if (
			relationship_label != ""
			and relationship_label.to_lower() not in [
				"stranger",
				"unknown"
			]
		):
			return relationship_label

	var descendant_label: String = (
		_dead_to_descendant_relationship_label(
			int(
				dead_player.id
			),
			int(
				target.id
			)
		)
	)

	if (
		descendant_label != ""
		and descendant_label != "relative"
	):
		return descendant_label

	if (
		gs != null
		and gs.has_method(
			"get_relationship_label_between"
		)
	):
		var canonical_label: String = str(
			gs.get_relationship_label_between(
				dead_player,
				target
			)
		).strip_edges()

		if (
			canonical_label != ""
			and canonical_label.to_lower() not in [
				"stranger",
				"unknown"
			]
		):
			return canonical_label

	return "Relationship"
func _queue_continue_lineage_destination_prewarm(
	dead_player_id: int
) -> void:
	if (
		gs == null
		or dead_player_id <= 0
	):
		return

	for raw_row in continue_lineage_destination_prewarm_queue:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue

		var existing_row: Dictionary = (
			raw_row as Dictionary
		)

		if int(
			existing_row.get(
				"dead_player_id",
				-1
			)
		) == dead_player_id:
			return

	continue_lineage_destination_prewarm_queue.append({
		"dead_player_id": dead_player_id,
		"candidate_index": 0,
		"active_actor_id": -1,
		"active_projection_signature": "",
		"attempt_by_actor": {},
		"failures_by_actor": {},
		"queued_at_ms": int(
			Time.get_ticks_msec()
		),
		"requires_ui_idle": false,
		"blocks_ui": false,
		"ready_gate_member": false
	})

	if typeof(
		gs.afterlife_state
	) == TYPE_DICTIONARY:
		gs.afterlife_state [
			"continue_lineage_destination_prewarm_pending"
		] = true
		gs.afterlife_state [
			"continue_lineage_destination_prewarm_complete"
		] = false
		gs.afterlife_state [
			"continue_lineage_destination_prewarm_requires_ui_idle"
		] = false
		gs.afterlife_state [
			"continue_lineage_destination_prewarm_ready_gate_member"
		] = false

	_arm_continue_lineage_destination_prewarm_service()


func _arm_continue_lineage_destination_prewarm_service() -> void:
	if (
		continue_lineage_destination_prewarm_service_active
		or continue_lineage_destination_prewarm_queue.is_empty()
	):
		return

	continue_lineage_destination_prewarm_service_active = true

	var tree:= Engine.get_main_loop() as SceneTree

	if tree == null:
		call_deferred(
			"_service_continue_lineage_destination_prewarm_quantum"
		)
		return



	var timer:= tree.create_timer(
		0.002,
		true,
		false,
		true
	)

	timer.timeout.connect(
		Callable(
			self,
			"_service_continue_lineage_destination_prewarm_quantum"
		),
		CONNECT_ONE_SHOT
	)


func _continue_lineage_prepared_switch_packet_for_actor(
	actor_id: int
) -> Dictionary:
	if (
		gs == null
		or actor_id <= 0
		or gs.relationships_hub_contract_engine == null
		or not gs.relationships_hub_contract_engine.has_method(
			"resident_core_switch_packet_for_actor"
		)
	):
		return {}

	var packet_raw: Variant = (
		gs.relationships_hub_contract_engine
		.resident_core_switch_packet_for_actor(
			actor_id
		)
	)

	if typeof(
		packet_raw
	) != TYPE_DICTIONARY:
		return {}

	var packet: Dictionary = (
		packet_raw as Dictionary
	)

	if packet.is_empty():
		return {}

	return packet.duplicate(false)

func _store_continue_lineage_perspective_handoff(
	dead_player: Person,
	continuing_actor: Person,
	switch_packet: Dictionary
) -> Dictionary:
	if (
		gs == null
		or dead_player == null
		or continuing_actor == null
		or switch_packet.is_empty()
	):
		return {}

	var relationship_label: String = ""

	if (
		gs.relationships_hub_contract_engine != null
		and gs.relationships_hub_contract_engine.has_method(
			"continuation_relationship_label_for_pair"
		)
	):
		relationship_label = str(
			gs.relationships_hub_contract_engine
			.continuation_relationship_label_for_pair(
				continuing_actor,
				dead_player
			)
		).strip_edges()

	if (
		relationship_label == ""
		and gs.has_method(
			"get_relationship_label_between"
		)
	):
		relationship_label = str(
			gs.get_relationship_label_between(
				continuing_actor,
				dead_player
			)
		).strip_edges()

	var relationship_key: String = (
		relationship_label.to_lower()
	)

	if relationship_key in [
		"",
		"stranger",
		"unknown",
		"relative"
	]:
		var descendant_direction: String = (
			_dead_to_descendant_relationship_label(
				int(
					dead_player.id
				),
				int(
					continuing_actor.id
				)
			)
		)

		relationship_label = (
			"ancestor"
			if descendant_direction != "relative"
			else "predecessor"
		)

	relationship_label = (
		relationship_label.strip_edges().to_lower()
	)

	var spirit_text: String = (
		"My %s's spirit flows through me."
		% relationship_label
	)

	var global_memory_cursor: int = 0

	if (
		gs.memory_engine != null
		and gs.memory_engine.has_method(
			"get_memories"
		)
	):
		var global_memories: Array = (
			gs.memory_engine.get_memories(
				int(
					continuing_actor.id
				)
			)
		)

		global_memory_cursor = (
			global_memories.size()
		)

	var surface_raw: Variant = switch_packet.get(
		"surface_contract",
		{}
	)
	var surface: Dictionary = (
		surface_raw as Dictionary
		if typeof(surface_raw) == TYPE_DICTIONARY
		else {}
	)
	var pointer_revision: String = str(
		switch_packet.get(
			"pointer_revision",
			surface.get(
				"pointer_revision",
				""
			)
		)
	).strip_edges()

	var press_frame_lens_raw: Variant = switch_packet.get(
		"press_frame_lens_cache",
		surface.get(
			"press_frame_lens_cache",
			{}
		)
	)
	var press_frame_lens_cache: Dictionary = (
		press_frame_lens_raw as Dictionary
		if typeof(
			press_frame_lens_raw
		) == TYPE_DICTIONARY
		else {}
	)

	var main_tab_surface_deck_hot: bool = bool(
		switch_packet.get(
			"main_tab_surface_deck_hot",
			surface.get(
				"main_tab_surface_deck_hot",
				false
			)
		)
	)
	var support_main_tab_deck_hot: bool = bool(
		switch_packet.get(
			"support_main_tab_deck_hot",
			surface.get(
				"support_main_tab_deck_hot",
				main_tab_surface_deck_hot
			)
		)
	)




	var visible_switch_packet: Dictionary = (
		switch_packet.duplicate(false)
	)

	var handoff: Dictionary = {
		"schema": (
			"eralife.afterlife."
			+ "continue_lineage_perspective_handoff"
		),
		"version": 2,
		"deceased_actor_id": int(
			dead_player.id
		),
		"actor_id": int(
			continuing_actor.id
		),
		"relationship_to_deceased": relationship_label,
		"diary_text": spirit_text,
		"pointer_revision": pointer_revision,
		"prepared_world_year": int(
			gs.year
		),
		"prepared_actor_age": int(
			continuing_actor.age
		),
		"visible_switch_packet": (
			visible_switch_packet
		),
		"press_frame_lens_cache": (
			press_frame_lens_cache.duplicate(false)
		),
		"life_diary_cursor_contract": {
			"actor_id": int(
				continuing_actor.id
			),
			"world_feed_cursor": int(
				gs.world_feed.size()
			),
			"global_memory_cursor": global_memory_cursor,
			"player_memory_cursor": (
				continuing_actor.memories.size()
				if continuing_actor.memories != null
				else 0
			),
			"source": (
				"afterlife_influence_engine."
				+ "continue_lineage_destination_prewarm"
			),
			"immutable": true,
			"ui_is_reader_only": true
		},
		"main_tab_surface_deck_hot": (
			main_tab_surface_deck_hot
		),
		"support_main_tab_deck_hot": (
			support_main_tab_deck_hot
		),
		"support_enrichment_pending": (
			not support_main_tab_deck_hot
		),
		"switch_packet_core_hot": true,
		"switch_packet_hot": true,
		"background_only": true,
		"blocks_ui": false,
		"progressive_observability": true,
		"switch_press_build_forbidden": true,
		"ready_gate_member": false,
		"immutable": true,
		"ui_is_reader_only": true,
		"prepared_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	var registry_raw: Variant = (
		gs.afterlife_state.get(
			"continue_lineage_perspective_handoff_by_actor",
			{}
		)
	)
	var registry: Dictionary = (
		(registry_raw as Dictionary).duplicate(false)
		if typeof(registry_raw) == TYPE_DICTIONARY
		else {}
	)

	registry [
		str(
			int(
				continuing_actor.id
			)
		)
	] = handoff.duplicate(false)

	gs.afterlife_state [
		"continue_lineage_perspective_handoff_by_actor"
	] = registry
	gs.afterlife_state [
		"continue_lineage_destination_last_prepared_actor_id"
	] = int(
		continuing_actor.id
	)
	gs.afterlife_state [
		"continue_lineage_destination_last_prepared_at_ms"
	] = int(
		Time.get_ticks_msec()
	)
	gs.afterlife_state [
		"continue_lineage_destination_last_prepared_core_only"
	] = not support_main_tab_deck_hot
	gs.afterlife_state [
		"continue_lineage_destination_support_enrichment_pending"
	] = not support_main_tab_deck_hot

	return handoff


func _service_continue_lineage_destination_prewarm_quantum() -> void:
	continue_lineage_destination_prewarm_service_active = false

	if (
		gs == null
		or continue_lineage_destination_prewarm_queue.is_empty()
	):
		return

	var row_raw: Variant = (
		continue_lineage_destination_prewarm_queue [
			0
		]
	)

	if typeof(
		row_raw
	) != TYPE_DICTIONARY:
		continue_lineage_destination_prewarm_queue.pop_front()

		if not continue_lineage_destination_prewarm_queue.is_empty():
			_arm_continue_lineage_destination_prewarm_service()

		return

	var row: Dictionary = (
		(row_raw as Dictionary).duplicate(false)
	)
	var dead_player_id: int = int(
		row.get(
			"dead_player_id",
			-1
		)
	)

	if (
		not gs.afterlife_active
		or typeof(
			gs.afterlife_state
		) != TYPE_DICTIONARY
		or int(
			gs.afterlife_state.get(
				"ghost_player_id",
				-1
			)
		) != dead_player_id
	):
		continue_lineage_destination_prewarm_queue.pop_front()

		if not continue_lineage_destination_prewarm_queue.is_empty():
			_arm_continue_lineage_destination_prewarm_service()

		return

	var dead_player: Person = null

	if (
		gs.player != null
		and int(
			gs.player.id
		) == dead_player_id
	):
		dead_player = gs.player
	elif gs.has_method(
		"get_or_reactivate_npc_by_id"
	):
		dead_player = (
			gs.get_or_reactivate_npc_by_id(
				dead_player_id
			)
		)

	if dead_player == null:
		continue_lineage_destination_prewarm_queue.pop_front()

		gs.afterlife_state [
			"continue_lineage_destination_prewarm_pending"
		] = false
		gs.afterlife_state [
			"continue_lineage_destination_prewarm_complete"
		] = false
		gs.afterlife_state [
			"continue_lineage_destination_prewarm_failure"
		] = "ghost_player_missing"

		return

	var bloodline_raw: Variant = (
		gs.afterlife_state.get(
			"touched_bloodline_ids",
			[]
		)
	)
	var bloodline_ids: Array = (
		(bloodline_raw as Array).duplicate(false)
		if typeof(bloodline_raw) == TYPE_ARRAY
		else []
	)
	var enrichment_stage: String = str(
		gs.afterlife_state.get(
			"death_entry_enrichment_stage",
			""
		)
	).strip_edges().to_lower()
	var bloodline_truth_published: bool = (
		not bloodline_ids.is_empty()
		or bool(
			gs.afterlife_state.get(
				"death_entry_enrichment_complete",
				false
			)
		)
		or enrichment_stage in [
			"bloodline_complete",
			"consciousness_complete",
			"complete"
		]
	)



	if not bloodline_truth_published:
		continue_lineage_destination_prewarm_queue [
			0
		] = row

		_arm_continue_lineage_destination_prewarm_service()
		return

	var candidate_index: int = int(
		row.get(
			"candidate_index",
			0
		)
	)

	if candidate_index >= bloodline_ids.size():
		gs.afterlife_state [
			"continue_lineage_destination_prewarm_pending"
		] = false
		gs.afterlife_state [
			"continue_lineage_destination_prewarm_complete"
		] = true
		gs.afterlife_state [
			"continue_lineage_destination_prewarm_actor_id"
		] = -1
		gs.afterlife_state [
			"continue_lineage_destination_prewarm_completed_at_ms"
		] = int(
			Time.get_ticks_msec()
		)

		continue_lineage_destination_prewarm_queue.pop_front()

		if not continue_lineage_destination_prewarm_queue.is_empty():
			_arm_continue_lineage_destination_prewarm_service()

		return

	var candidate_id: int = int(
		bloodline_ids [
			candidate_index
		]
	)
	var candidate: Person = (
		gs.get_or_reactivate_npc_by_id(
			candidate_id
		)
	)

	if (
		candidate == null
		or not candidate.alive
		or float(
			candidate.health
		) <= 0.0
	):
		row [
			"candidate_index"
		] = candidate_index + 1
		row [
			"active_actor_id"
		] = -1
		row [
			"active_projection_signature"
		] = ""

		continue_lineage_destination_prewarm_queue [
			0
		] = row

		_arm_continue_lineage_destination_prewarm_service()
		return

	gs.afterlife_state [
		"continue_lineage_destination_prewarm_actor_id"
	] = candidate_id


	var prepared_packet: Dictionary = (
		_continue_lineage_prepared_switch_packet_for_actor(
			candidate_id
		)
	)

	if not prepared_packet.is_empty():
		_store_continue_lineage_perspective_handoff(
			dead_player,
			candidate,
			prepared_packet
		)

		row [
			"candidate_index"
		] = candidate_index + 1
		row [
			"active_actor_id"
		] = -1
		row [
			"active_projection_signature"
		] = ""
		row [
			"pointer_core_admitted"
		] = true
		row [
			"support_deck_required_for_admission"
		] = false

		continue_lineage_destination_prewarm_queue [
			0
		] = row

		_arm_continue_lineage_destination_prewarm_service()
		return

	var attempt_raw: Variant = row.get(
		"attempt_by_actor",
		{}
	)
	var attempt_by_actor: Dictionary = (
		(attempt_raw as Dictionary).duplicate(false)
		if typeof(attempt_raw) == TYPE_DICTIONARY
		else {}
	)
	var actor_key: String = str(
		candidate_id
	)
	var attempt_count: int = int(
		attempt_by_actor.get(
			actor_key,
			0
		)
	)

	var active_actor_id: int = int(
		row.get(
			"active_actor_id",
			-1
		)
	)
	var active_signature: String = str(
		row.get(
			"active_projection_signature",
			""
		)
	).strip_edges()

	if (
		active_actor_id != candidate_id
		or active_signature == ""
	):
		if (
			gs.relationships_hub_contract_engine == null
			or gs.reality_projection_contract_engine == null
		):
			var failures_raw: Variant = row.get(
				"failures_by_actor",
				{}
			)
			var failures: Dictionary = (
				(failures_raw as Dictionary).duplicate(false)
				if typeof(failures_raw) == TYPE_DICTIONARY
				else {}
			)

			failures [
				actor_key
			] = "destination_projection_authority_unavailable"
			row [
				"failures_by_actor"
			] = failures
			row [
				"candidate_index"
			] = candidate_index + 1
			row [
				"active_actor_id"
			] = -1
			row [
				"active_projection_signature"
			] = ""

			gs.afterlife_state [
				"continue_lineage_destination_prewarm_failures"
			] = failures.duplicate(false)

			continue_lineage_destination_prewarm_queue [
				0
			] = row

			_arm_continue_lineage_destination_prewarm_service()
			return




		var queue_report: Dictionary = (
			gs.relationships_hub_contract_engine.resolve_intent(
				dead_player,
				{
					"action_id": "queue_switch_shell_stage",
					"target_id": candidate_id,
					"complete_destination_deck_required": false,
					"relationship_profile_visible_packet": false,
					"explicit_relationship_profile_observation": false,
					"profile_switch_packet_required_before_visible": false,
					"pointer_only_packet_forbidden": false,
					"allow_pointer_core_only_preparation": true,
					"visible_card_may_not_publish_complete_destination_deck": true,
					"detached_service_only": true,
					"background_only": true,
					"blocks_ui": false,
					"support_deck_blocks_switch": false,
					"progressive_observability": true,
					"switch_press_build_forbidden": true,
					"switch_press_must_not_build_surface": true,
					"ready_gate_member": false,
					"ui_is_renderer_only": true,
					"source": (
						"afterlife_influence_engine."
						+ "continue_lineage_destination_prewarm"
					)
				}
			)
		)

		if not bool(
			queue_report.get(
				"success",
				false
			)
		):
			attempt_count += 1
			attempt_by_actor [
				actor_key
			] = attempt_count
			row [
				"attempt_by_actor"
			] = attempt_by_actor

			continue_lineage_destination_prewarm_queue [
				0
			] = row

			_arm_continue_lineage_destination_prewarm_service()
			return

		active_signature = (
			"afterlife_continue_lineage:%d:%d:%d:%d"
			% [
				dead_player_id,
				candidate_id,
				int(
					gs.year
				),
				attempt_count
			]
		)




		var begin_report: Dictionary = (
			gs.reality_projection_contract_engine.begin_resident_projection(
				gs,
				{
					"signature": active_signature,
					"actor_override": candidate,
					"interactive_surfaces_only": true,
					"source": (
						"afterlife_influence_engine."
						+ "continue_lineage_destination_prewarm"
					),
					"background_only": true,
					"blocks_ui": false,
					"progressive_observability": true,
					"observation_required": false,
					"build_on_click_forbidden": true,
					"ready_gate_member": false,
					"ui_is_renderer_only": true
				}
			)
		)

		if bool(
			begin_report.get(
				"failed",
				false
			)
		):
			attempt_count += 1
			attempt_by_actor [
				actor_key
			] = attempt_count
			row [
				"attempt_by_actor"
			] = attempt_by_actor

			continue_lineage_destination_prewarm_queue [
				0
			] = row

			_arm_continue_lineage_destination_prewarm_service()
			return

		row [
			"active_actor_id"
		] = candidate_id
		row [
			"active_projection_signature"
		] = active_signature
		row [
			"last_projection_begin_report"
		] = begin_report.duplicate(false)
		row [
			"last_serviced_at_ms"
		] = int(
			Time.get_ticks_msec()
		)

		continue_lineage_destination_prewarm_queue [
			0
		] = row

		_arm_continue_lineage_destination_prewarm_service()
		return

	var step_report: Dictionary = (
		gs.reality_projection_contract_engine.step_resident_projection(
			active_signature,
			1,
			1
		)
	)

	if bool(
		step_report.get(
			"failed",
			false
		)
	):
		attempt_count += 1
		attempt_by_actor [
			actor_key
		] = attempt_count
		row [
			"attempt_by_actor"
		] = attempt_by_actor
		row [
			"active_actor_id"
		] = -1
		row [
			"active_projection_signature"
		] = ""

		if attempt_count >= 3:
			var failures_raw: Variant = row.get(
				"failures_by_actor",
				{}
			)
			var failures: Dictionary = (
				(failures_raw as Dictionary).duplicate(false)
				if typeof(failures_raw) == TYPE_DICTIONARY
				else {}
			)

			failures [
				actor_key
			] = str(
				step_report.get(
					"failure",
					"destination_projection_failed"
				)
			)
			row [
				"failures_by_actor"
			] = failures
			row [
				"candidate_index"
			] = candidate_index + 1

			gs.afterlife_state [
				"continue_lineage_destination_prewarm_failures"
			] = failures.duplicate(false)

		continue_lineage_destination_prewarm_queue [
			0
		] = row

		_arm_continue_lineage_destination_prewarm_service()
		return

	if not bool(
		step_report.get(
			"complete",
			false
		)
	):
		row [
			"last_projection_step_report"
		] = step_report.duplicate(false)
		row [
			"last_serviced_at_ms"
		] = int(
			Time.get_ticks_msec()
		)

		continue_lineage_destination_prewarm_queue [
			0
		] = row

		_arm_continue_lineage_destination_prewarm_service()
		return

	prepared_packet = (
		_continue_lineage_prepared_switch_packet_for_actor(
			candidate_id
		)
	)

	if prepared_packet.is_empty():
		attempt_count += 1
		attempt_by_actor [
			actor_key
		] = attempt_count
		row [
			"attempt_by_actor"
		] = attempt_by_actor
		row [
			"active_actor_id"
		] = -1
		row [
			"active_projection_signature"
		] = ""

		if attempt_count >= 3:
			var failures_raw: Variant = row.get(
				"failures_by_actor",
				{}
			)
			var failures: Dictionary = (
				(failures_raw as Dictionary).duplicate(false)
				if typeof(failures_raw) == TYPE_DICTIONARY
				else {}
			)

			failures [
				actor_key
			] = "pointer_core_switch_packet_not_published"
			row [
				"failures_by_actor"
			] = failures
			row [
				"candidate_index"
			] = candidate_index + 1

			gs.afterlife_state [
				"continue_lineage_destination_prewarm_failures"
			] = failures.duplicate(false)

		continue_lineage_destination_prewarm_queue [
			0
		] = row

		_arm_continue_lineage_destination_prewarm_service()
		return

	_store_continue_lineage_perspective_handoff(
		dead_player,
		candidate,
		prepared_packet
	)

	row [
		"candidate_index"
	] = candidate_index + 1
	row [
		"active_actor_id"
	] = -1
	row [
		"active_projection_signature"
	] = ""
	row [
		"pointer_core_admitted"
	] = true
	row [
		"support_deck_required_for_admission"
	] = false
	row [
		"last_serviced_at_ms"
	] = int(
		Time.get_ticks_msec()
	)

	continue_lineage_destination_prewarm_queue [
		0
	] = row

	_arm_continue_lineage_destination_prewarm_service()
func _queue_death_entry_enrichment(
	player_id: int,
	death_cause: String
) -> void:
	if player_id <= 0:
		return

	for raw_row in death_entry_enrichment_queue:
		var existing: Dictionary = (
			raw_row
			if typeof(raw_row) == TYPE_DICTIONARY
			else {}
		)

		if int(
			existing.get(
				"player_id",
				-1
			)
		) == player_id:
			return

	death_entry_enrichment_queue.append({
		"player_id": player_id,
		"death_cause": death_cause,
		"stage": 0,
		"queued_at_ms": int(
			Time.get_ticks_msec()
		),
		"requires_ui_idle": false,
		"ready_gate_member": false
	})

	_arm_death_entry_enrichment_service()


func _arm_death_entry_enrichment_service() -> void:
	if (
		death_entry_enrichment_service_active
		or death_entry_enrichment_queue.is_empty()
	):
		return

	var tree:= Engine.get_main_loop() as SceneTree

	if tree == null:
		return

	var service_callable:= Callable(
		self,
		"_service_death_entry_enrichment_quantum"
	)

	if tree.process_frame.is_connected(
		service_callable
	):
		death_entry_enrichment_service_active = true
		return

	death_entry_enrichment_service_active = true






	tree.process_frame.connect(
		service_callable,
		CONNECT_ONE_SHOT
	)
func _service_death_entry_enrichment_quantum() -> void:
	death_entry_enrichment_service_active = false

	if (
		gs == null
		or death_entry_enrichment_queue.is_empty()
	):
		return

	var row_raw: Variant = (
		death_entry_enrichment_queue [
			0
		]
	)

	if typeof(
		row_raw
	) != TYPE_DICTIONARY:
		death_entry_enrichment_queue.pop_front()

		if typeof(
			gs.afterlife_state
		) == TYPE_DICTIONARY:
			gs.afterlife_state [
				"death_entry_enrichment_last_invalid_queue_row_at_ms"
			] = int(
				Time.get_ticks_msec()
			)
			gs.afterlife_state [
				"death_entry_enrichment_last_invalid_queue_row_type"
			] = typeof(
				row_raw
			)

			if death_entry_enrichment_queue.is_empty():
				gs.afterlife_state [
					"death_entry_enrichment_pending"
				] = false
				gs.afterlife_state [
					"death_entry_enrichment_complete"
				] = false
				gs.afterlife_state [
					"death_entry_enrichment_failure"
				] = "invalid_enrichment_queue_row"

		if not death_entry_enrichment_queue.is_empty():
			_arm_death_entry_enrichment_service()

		return

	var row: Dictionary = (
		(row_raw as Dictionary).duplicate(false)
	)

	if row.is_empty():
		death_entry_enrichment_queue.pop_front()

		if typeof(
			gs.afterlife_state
		) == TYPE_DICTIONARY:
			gs.afterlife_state [
				"death_entry_enrichment_last_empty_queue_row_at_ms"
			] = int(
				Time.get_ticks_msec()
			)

			if death_entry_enrichment_queue.is_empty():
				gs.afterlife_state [
					"death_entry_enrichment_pending"
				] = false
				gs.afterlife_state [
					"death_entry_enrichment_complete"
				] = false
				gs.afterlife_state [
					"death_entry_enrichment_failure"
				] = "empty_enrichment_queue_row"

		if not death_entry_enrichment_queue.is_empty():
			_arm_death_entry_enrichment_service()

		return

	var player_id: int = int(
		row.get(
			"player_id",
			-1
		)
	)

	if (
		not gs.afterlife_active
		or typeof(
			gs.afterlife_state
		) != TYPE_DICTIONARY
		or int(
			gs.afterlife_state.get(
				"ghost_player_id",
				-1
			)
		) != player_id
	):
		death_entry_enrichment_queue.pop_front()

		if not death_entry_enrichment_queue.is_empty():
			_arm_death_entry_enrichment_service()

		return

	var player: Person = null

	if (
		gs.player != null
		and int(
			gs.player.id
		) == player_id
	):
		player = gs.player
	elif gs.has_method(
		"get_or_reactivate_npc_by_id"
	):
		player = gs.get_or_reactivate_npc_by_id(
			player_id
		)

	if player == null:
		death_entry_enrichment_queue.pop_front()

		gs.afterlife_state [
			"death_entry_enrichment_pending"
		] = false
		gs.afterlife_state [
			"death_entry_enrichment_complete"
		] = false
		gs.afterlife_state [
			"death_entry_enrichment_failure"
		] = "ghost_player_missing"
		gs.afterlife_state [
			"death_entry_enrichment_failure_at_ms"
		] = int(
			Time.get_ticks_msec()
		)

		if not death_entry_enrichment_queue.is_empty():
			_arm_death_entry_enrichment_service()

		return

	var stage: int = int(
		row.get(
			"stage",
			0
		)
	)
	var death_cause: String = str(
		row.get(
			"death_cause",
			player.cause_of_death
		)
	)
	var advance_stage: bool = true

	match stage:
		0:
			var funeral_state_raw: Variant = row.get(
				"funeral_accumulator",
				{}
			)
			var funeral_state: Dictionary = {}

			if typeof(
				funeral_state_raw
			) == TYPE_DICTIONARY:
				funeral_state = (
					funeral_state_raw as Dictionary
				)

			funeral_state = (
				_service_afterlife_funeral_accumulator_quantum(
					player,
					funeral_state
				)
			)

			row [
				"funeral_accumulator"
			] = funeral_state

			if bool(
				funeral_state.get(
					"complete",
					false
				)
			):
				var funeral_text: String = str(
					funeral_state.get(
						"text",
						"The grave received you without witnesses."
					)
				)

				gs.afterlife_state [
					"funeral_text"
				] = funeral_text
				gs.afterlife_state [
					"pending_text"
				] = (
					"Cause of death: %s\n\n%s\n\nChoose what happens next."
					% [
						death_cause,
						funeral_text
					]
				)
				gs.afterlife_state [
					"death_entry_enrichment_stage"
				] = "funeral_complete"

				row.erase(
					"funeral_accumulator"
				)
			else:
				advance_stage = false

		1:
			var personal_state_raw: Variant = row.get(
				"personal_net_worth_accumulator",
				{}
			)
			var personal_state: Dictionary = {}

			if typeof(
				personal_state_raw
			) == TYPE_DICTIONARY:
				personal_state = (
					personal_state_raw as Dictionary
				)

			if personal_state.is_empty():
				personal_state = {
					"owner_ids": [
						player_id
					],
					"total": 0.0
				}

			personal_state = (
				_service_afterlife_net_worth_accumulator_quantum(
					personal_state,
					player_id
				)
			)

			row [
				"personal_net_worth_accumulator"
			] = personal_state

			if bool(
				personal_state.get(
					"complete",
					false
				)
			):
				gs.afterlife_state [
					"ghost_personal_net_worth"
				] = float(
					personal_state.get(
						"total",
						0.0
					)
				)
				gs.afterlife_state [
					"death_entry_enrichment_stage"
				] = "personal_net_worth_complete"

				row.erase(
					"personal_net_worth_accumulator"
				)
			else:
				advance_stage = false

		2:
			var family_state_raw: Variant = row.get(
				"family_net_worth_accumulator",
				{}
			)
			var family_state: Dictionary = {}

			if typeof(
				family_state_raw
			) == TYPE_DICTIONARY:
				family_state = (
					family_state_raw as Dictionary
				)

			if family_state.is_empty():
				family_state = {
					"owner_ids": (
						_collect_afterlife_family_member_ids(
							player
						)
					),
					"total": 0.0
				}

			family_state = (
				_service_afterlife_net_worth_accumulator_quantum(
					family_state,
					player_id
				)
			)

			row [
				"family_net_worth_accumulator"
			] = family_state

			if bool(
				family_state.get(
					"complete",
					false
				)
			):
				gs.afterlife_state [
					"ghost_family_net_worth"
				] = float(
					family_state.get(
						"total",
						0.0
					)
				)
				gs.afterlife_state [
					"death_entry_enrichment_stage"
				] = "family_net_worth_complete"

				row.erase(
					"family_net_worth_accumulator"
				)
			else:
				advance_stage = false

		3:
			var bloodline_queue_raw: Variant = row.get(
				"bloodline_queue",
				[]
			)
			var bloodline_queue: Array = (
				bloodline_queue_raw as Array
				if typeof(
					bloodline_queue_raw
				) == TYPE_ARRAY
				else []
			)
			var bloodline_seen_raw: Variant = row.get(
				"bloodline_seen",
				{}
			)
			var bloodline_seen: Dictionary = (
				bloodline_seen_raw as Dictionary
				if typeof(
					bloodline_seen_raw
				) == TYPE_DICTIONARY
				else {}
			)
			var bloodline_out_raw: Variant = row.get(
				"bloodline_out",
				[]
			)
			var bloodline_out: Array = (
				bloodline_out_raw as Array
				if typeof(
					bloodline_out_raw
				) == TYPE_ARRAY
				else []
			)

			if not bool(
				row.get(
					"bloodline_initialized",
					false
				)
			):
				bloodline_queue = [
					player_id
				]
				bloodline_seen = {}
				bloodline_out = []
				row [
					"bloodline_initialized"
				] = true

			if bloodline_queue.is_empty():
				gs.afterlife_state [
					"touched_bloodline_ids"
				] = bloodline_out.duplicate(false)
				gs.afterlife_state [
					"death_entry_enrichment_stage"
				] = "bloodline_complete"

				row.erase(
					"bloodline_queue"
				)
				row.erase(
					"bloodline_seen"
				)
				row.erase(
					"bloodline_out"
				)
			else:
				var current_id: int = int(
					bloodline_queue.pop_front()
				)

				if (
					current_id > 0
					and not bloodline_seen.has(
						current_id
					)
				):
					bloodline_seen [
						current_id
					] = true

					var facts: Dictionary = (
						gs.get_npc_facts_by_id(
							current_id
						)
					)
					var children_raw: Variant = facts.get(
						"children",
						[]
					)

					if typeof(
						children_raw
					) == TYPE_ARRAY:
						for raw_child_id in children_raw as Array:
							var child_id: int = int(
								raw_child_id
							)

							if child_id <= 0:
								continue

							if bloodline_out.find(
								child_id
							) < 0:
								bloodline_out.append(
									child_id
								)

							if not bloodline_seen.has(
								child_id
							):
								bloodline_queue.append(
									child_id
								)

				row [
					"bloodline_queue"
				] = bloodline_queue
				row [
					"bloodline_seen"
				] = bloodline_seen
				row [
					"bloodline_out"
				] = bloodline_out
				row [
					"bloodline_nodes_processed"
				] = int(
					row.get(
						"bloodline_nodes_processed",
						0
					)
				) + 1

				advance_stage = false

		4:
			var ghost_consciousness: Dictionary = {}

			if gs.consciousness_engine != null:
				ghost_consciousness = (
					gs.consciousness_engine
					.project_afterlife_consciousness(
						player,
						{
							"source": (
								"afterlife_influence_engine."
								+ "death_entry_enrichment"
							),
							"cause": death_cause,
							"background_only": true,
							"blocks_ui": false,
							"ready_gate_member": false,
						}
					)
				)

			gs.afterlife_state [
				"ghost_consciousness"
			] = ghost_consciousness
			gs.afterlife_state [
				"death_entry_enrichment_stage"
			] = "consciousness_complete"

		_:
			gs.afterlife_state [
				"death_entry_enrichment_pending"
			] = false
			gs.afterlife_state [
				"death_entry_enrichment_complete"
			] = true
			gs.afterlife_state [
				"death_entry_enrichment_stage"
			] = "complete"
			gs.afterlife_state [
				"death_entry_enrichment_completed_at_ms"
			] = int(
				Time.get_ticks_msec()
			)
			gs.afterlife_state [
				"death_entry_enrichment_requires_ui_idle"
			] = false
			gs.afterlife_state [
				"death_entry_enrichment_intrinsically_bounded"
			] = true
			gs.afterlife_state [
				"death_entry_enrichment_variable_length_loop_per_frame"
			] = false

			death_entry_enrichment_queue.pop_front()

			if not death_entry_enrichment_queue.is_empty():
				_arm_death_entry_enrichment_service()

			return

	if advance_stage:
		row [
			"stage"
		] = stage + 1

	row [
		"last_serviced_at_ms"
	] = int(
		Time.get_ticks_msec()
	)
	row [
		"one_authority_quantum_per_frame"
	] = true
	row [
		"requires_ui_idle"
	] = false

	death_entry_enrichment_queue [
		0
	] = row

	_arm_death_entry_enrichment_service()
func _service_afterlife_funeral_accumulator_quantum(
	player: Person,
	state: Dictionary
) -> Dictionary:
	var out: Dictionary = state.duplicate(false)

	if (
		player == null
		or gs == null
	):
		out [
			"complete"
		] = true
		out [
			"text"
		] = "The grave received you without witnesses."
		return out

	if not bool(
		out.get(
			"initialized",
			false
		)
	):
		var score: float = 0.0

		score -= float(
			player.scandal
		) * 0.2
		score += float(
			player.fame
		) * 0.04
		score += float(
			player.satisfaction
		) * 0.08

		if "Generous" in player.traits:
			score += 8.0

		if "Kind" in player.traits:
			score += 8.0

		if "Cruel" in player.traits:
			score -= 10.0

		if "Evil" in player.traits:
			score -= 14.0

		out [
			"initialized"
		] = true
		out [
			"relation_phase"
		] = "parents"
		out [
			"relation_cursor"
		] = 0
		out [
			"moral_score"
		] = score
		out [
			"family_present"
		] = 0
		out [
			"contempt_found"
		] = false
		out [
			"complete"
		] = false
		out [
			"relations_observed"
		] = 0

	if str(
		player.cause_of_death
	).strip_edges() == "Smoked by Dwarves":
		out [
			"complete"
		] = true
		out [
			"text"
		] = (
			"The Dwarves sealed your body so nobody could ever find it."
		)
		return out

	var phase: String = str(
		out.get(
			"relation_phase",
			"parents"
		)
	)
	var cursor: int = int(
		out.get(
			"relation_cursor",
			0
		)
	)
	var relation_id: int = -1

	match phase:
		"parents":
			if cursor < player.parents.size():
				relation_id = int(
					player.parents [
						cursor
					]
				)
				out [
					"relation_cursor"
				] = cursor + 1
			else:
				out [
					"relation_phase"
				] = "children"
				out [
					"relation_cursor"
				] = 0

		"children":
			if cursor < player.children.size():
				relation_id = int(
					player.children [
						cursor
					]
				)
				out [
					"relation_cursor"
				] = cursor + 1
			else:
				out [
					"relation_phase"
				] = "partner"
				out [
					"relation_cursor"
				] = 0

		"partner":
			if (
				cursor <= 0
				and player.partner != null
			):
				relation_id = int(
					player.partner.id
				)
				out [
					"relation_cursor"
				] = 1
			else:
				out [
					"relation_phase"
				] = "complete"

		"complete":
			pass

	if relation_id > 0:
		var relation: Person = (
			gs.get_or_reactivate_npc_by_id(
				relation_id
			)
		)

		if relation != null:
			var affection_value: int = int(
				relation.affection.get(
					int(
						player.id
					),
					50
				)
			)

			out [
				"moral_score"
			] = float(
				out.get(
					"moral_score",
					0.0
				)
			) + float(
				affection_value - 50
			) * 0.25

			if relation.alive:
				out [
					"family_present"
				] = int(
					out.get(
						"family_present",
						0
					)
				) + 1

				if affection_value <= 20:
					out [
						"contempt_found"
					] = true

		out [
			"relations_observed"
		] = int(
			out.get(
				"relations_observed",
				0
			)
		) + 1

	if str(
		out.get(
			"relation_phase",
			""
		)
	) != "complete":
		return out

	var moral_score: float = float(
		out.get(
			"moral_score",
			0.0
		)
	)
	var family_present: int = int(
		out.get(
			"family_present",
			0
		)
	)
	var contempt_found: bool = bool(
		out.get(
			"contempt_found",
			false
		)
	)
	var funeral_text: String = ""

	if (
		moral_score >= 15.0
		and family_present > 0
	):
		funeral_text = (
			"You were remembered warmly. Your whole family came to your funeral."
		)
	elif (
		moral_score <= -18.0
		and contempt_found
	):
		funeral_text = (
			"No one came to your funeral. Someone in your family spat on your "
			+ "tombstone with contempt."
		)
	elif moral_score <= -10.0:
		funeral_text = (
			"Only a frog came to your funeral, and even it left before the "
			+ "service ended."
		)
	elif family_present > 0:
		funeral_text = (
			"A few grieving relatives came and stood in uneasy silence."
		)
	else:
		funeral_text = (
			"The service was thin, quiet, and easy for the wind to ignore."
		)

	out [
		"text"
	] = funeral_text
	out [
		"complete"
	] = true

	return out
func _service_afterlife_net_worth_accumulator_quantum(
	state: Dictionary,
	root_id: int
) -> Dictionary:
	var out: Dictionary = state.duplicate(false)

	if gs == null:
		out [
			"complete"
		] = true
		out [
			"failed"
		] = true
		out [
			"reason"
		] = "game_state_missing"
		return out

	var owner_ids_raw: Variant = out.get(
		"owner_ids",
		[]
	)
	var owner_ids: Array = []

	if typeof(owner_ids_raw) == TYPE_ARRAY:
		owner_ids = owner_ids_raw as Array

	var excluded_raw: Variant = out.get(
		"excluded_owner_ids",
		{}
	)
	var excluded_owner_ids: Dictionary = {}

	if typeof(excluded_raw) == TYPE_DICTIONARY:
		excluded_owner_ids = excluded_raw as Dictionary

	var seen_raw: Variant = out.get(
		"seen_asset_keys",
		{}
	)
	var seen_asset_keys: Dictionary = {}

	if typeof(seen_raw) == TYPE_DICTIONARY:
		seen_asset_keys = seen_raw as Dictionary

	if not bool(
		out.get(
			"initialized",
			false
		)
	):
		out [
			"initialized"
		] = true
		out [
			"phase"
		] = "bank"
		out [
			"owner_cursor"
		] = 0
		out [
			"entry_cursor"
		] = 0
		out [
			"inventory_owner_id"
		] = -1
		out [
			"inventory_category_keys"
		] = []
		out [
			"inventory_category_cursor"
		] = 0
		out [
			"inventory_item_cursor"
		] = 0
		out [
			"total"
		] = float(
			out.get(
				"total",
				0.0
			)
		)
		out [
			"complete"
		] = false
		out [
			"quantum_count"
		] = 0

	out [
		"quantum_count"
	] = int(
		out.get(
			"quantum_count",
			0
		)
	) + 1

	var phase: String = str(
		out.get(
			"phase",
			"bank"
		)
	)
	var owner_cursor: int = int(
		out.get(
			"owner_cursor",
			0
		)
	)
	var total: float = float(
		out.get(
			"total",
			0.0
		)
	)

	match phase:
		"bank":
			if owner_cursor >= owner_ids.size():
				out [
					"phase"
				] = "property"
				out [
					"owner_cursor"
				] = 0
				out [
					"entry_cursor"
				] = 0
			else:
				var owner_id: int = int(
					owner_ids [
						owner_cursor
					]
				)
				var owner: Person = null

				if (
					gs.player != null
					and int(
						gs.player.id
					) == owner_id
				):
					owner = gs.player
				elif gs.has_method(
					"get_or_reactivate_npc_by_id"
				):
					owner = (
						gs.get_or_reactivate_npc_by_id(
							owner_id
						)
					)

				if owner == null:
					excluded_owner_ids [
						owner_id
					] = true
				elif (
					not owner.alive
					and owner_id != root_id
				):
					excluded_owner_ids [
						owner_id
					] = true
				else:
					total += max(
						0.0,
						float(
							owner.bank_balance
						)
					)

				out [
					"owner_cursor"
				] = owner_cursor + 1

		"property":
			if gs.property_engine == null:
				out [
					"phase"
				] = "vehicle"
				out [
					"owner_cursor"
				] = 0
				out [
					"entry_cursor"
				] = 0
			elif owner_cursor >= owner_ids.size():
				out [
					"phase"
				] = "vehicle"
				out [
					"owner_cursor"
				] = 0
				out [
					"entry_cursor"
				] = 0
			else:
				var property_owner_id: int = int(
					owner_ids [
						owner_cursor
					]
				)

				if excluded_owner_ids.has(
					property_owner_id
				):
					out [
						"owner_cursor"
					] = owner_cursor + 1
					out [
						"entry_cursor"
					] = 0
				else:
					var property_entries_raw: Variant = (
						gs.property_engine.properties.get(
							property_owner_id,
							[]
						)
					)
					var property_entries: Array = []

					if typeof(
						property_entries_raw
					) == TYPE_ARRAY:
						property_entries = (
							property_entries_raw as Array
						)

					var property_cursor: int = int(
						out.get(
							"entry_cursor",
							0
						)
					)

					if property_cursor >= property_entries.size():
						out [
							"owner_cursor"
						] = owner_cursor + 1
						out [
							"entry_cursor"
						] = 0
					else:
						var property_raw: Variant = (
							property_entries [
								property_cursor
							]
						)

						if typeof(
							property_raw
						) == TYPE_DICTIONARY:
							var property_entry: Dictionary = (
								property_raw as Dictionary
							)
							var property_key: String = (
								_afterlife_net_worth_entry_key(
									"property",
									"",
									property_entry
								)
							)

							if not seen_asset_keys.has(
								property_key
							):
								seen_asset_keys [
									property_key
								] = true
								total += (
									_afterlife_net_worth_entry_value(
										property_entry
									)
								)

						out [
							"entry_cursor"
						] = property_cursor + 1

		"vehicle":
			if gs.vehicle_engine == null:
				out [
					"phase"
				] = "inventory"
				out [
					"owner_cursor"
				] = 0
				out [
					"entry_cursor"
				] = 0
			elif owner_cursor >= owner_ids.size():
				out [
					"phase"
				] = "inventory"
				out [
					"owner_cursor"
				] = 0
				out [
					"entry_cursor"
				] = 0
			else:
				var vehicle_owner_id: int = int(
					owner_ids [
						owner_cursor
					]
				)

				if excluded_owner_ids.has(
					vehicle_owner_id
				):
					out [
						"owner_cursor"
					] = owner_cursor + 1
					out [
						"entry_cursor"
					] = 0
				else:
					var vehicle_entries_raw: Variant = (
						gs.vehicle_engine.vehicles.get(
							vehicle_owner_id,
							[]
						)
					)
					var vehicle_entries: Array = []

					if typeof(
						vehicle_entries_raw
					) == TYPE_ARRAY:
						vehicle_entries = (
							vehicle_entries_raw as Array
						)

					var vehicle_cursor: int = int(
						out.get(
							"entry_cursor",
							0
						)
					)

					if vehicle_cursor >= vehicle_entries.size():
						out [
							"owner_cursor"
						] = owner_cursor + 1
						out [
							"entry_cursor"
						] = 0
					else:
						var vehicle_raw: Variant = (
							vehicle_entries [
								vehicle_cursor
							]
						)

						if typeof(
							vehicle_raw
						) == TYPE_DICTIONARY:
							var vehicle_entry: Dictionary = (
								vehicle_raw as Dictionary
							)
							var vehicle_key: String = (
								_afterlife_net_worth_entry_key(
									"vehicle",
									"",
									vehicle_entry
								)
							)

							if not seen_asset_keys.has(
								vehicle_key
							):
								seen_asset_keys [
									vehicle_key
								] = true
								total += (
									_afterlife_net_worth_entry_value(
										vehicle_entry
									)
								)

						out [
							"entry_cursor"
						] = vehicle_cursor + 1

		"inventory":
			if gs.belongings_engine == null:
				out [
					"phase"
				] = "complete"
			elif owner_cursor >= owner_ids.size():
				out [
					"phase"
				] = "complete"
			else:
				var inventory_owner_id: int = int(
					owner_ids [
						owner_cursor
					]
				)

				if excluded_owner_ids.has(
					inventory_owner_id
				):
					out [
						"owner_cursor"
					] = owner_cursor + 1
					out [
						"inventory_owner_id"
					] = -1
					out [
						"inventory_category_keys"
					] = []
					out [
						"inventory_category_cursor"
					] = 0
					out [
						"inventory_item_cursor"
					] = 0
				else:
					var inventory_raw: Variant = (
						gs.belongings_engine.belongings.get(
							inventory_owner_id,
							{}
						)
					)
					var inventory: Dictionary = {}

					if typeof(
						inventory_raw
					) == TYPE_DICTIONARY:
						inventory = (
							inventory_raw as Dictionary
						)

					var cached_inventory_owner_id: int = int(
						out.get(
							"inventory_owner_id",
							-1
						)
					)

					if cached_inventory_owner_id != inventory_owner_id:
						out [
							"inventory_owner_id"
						] = inventory_owner_id
						out [
							"inventory_category_keys"
						] = inventory.keys()
						out [
							"inventory_category_cursor"
						] = 0
						out [
							"inventory_item_cursor"
						] = 0

					var category_keys_raw: Variant = out.get(
						"inventory_category_keys",
						[]
					)
					var category_keys: Array = []

					if typeof(
						category_keys_raw
					) == TYPE_ARRAY:
						category_keys = (
							category_keys_raw as Array
						)

					var category_cursor: int = int(
						out.get(
							"inventory_category_cursor",
							0
						)
					)

					if category_cursor >= category_keys.size():
						out [
							"owner_cursor"
						] = owner_cursor + 1
						out [
							"inventory_owner_id"
						] = -1
						out [
							"inventory_category_keys"
						] = []
						out [
							"inventory_category_cursor"
						] = 0
						out [
							"inventory_item_cursor"
						] = 0
					else:
						var category_key: Variant = (
							category_keys [
								category_cursor
							]
						)
						var category: String = str(
							category_key
						)

						if category in [
							"Real Estate",
							"Vehicles",
							"Vehicle"
						]:
							out [
								"inventory_category_cursor"
							] = category_cursor + 1
							out [
								"inventory_item_cursor"
							] = 0
						else:
							var items_raw: Variant = inventory.get(
								category_key,
								[]
							)
							var items: Array = []

							if typeof(
								items_raw
							) == TYPE_ARRAY:
								items = (
									items_raw as Array
								)

							var item_cursor: int = int(
								out.get(
									"inventory_item_cursor",
									0
								)
							)

							if item_cursor >= items.size():
								out [
									"inventory_category_cursor"
								] = category_cursor + 1
								out [
									"inventory_item_cursor"
								] = 0
							else:
								var item_raw: Variant = (
									items [
										item_cursor
									]
								)

								if typeof(
									item_raw
								) == TYPE_DICTIONARY:
									var item: Dictionary = (
										item_raw as Dictionary
									)
									var item_key: String = (
										_afterlife_net_worth_entry_key(
											"item",
											category,
											item
										)
									)

									if not seen_asset_keys.has(
										item_key
									):
										seen_asset_keys [
											item_key
										] = true
										total += (
											_afterlife_net_worth_entry_value(
												item
											)
										)

								out [
									"inventory_item_cursor"
								] = item_cursor + 1

		"complete":
			out [
				"complete"
			] = true

		_:
			out [
				"phase"
			] = "complete"
			out [
				"complete"
			] = true

	if str(
		out.get(
			"phase",
			""
		)
	) == "complete":
		out [
			"complete"
		] = true

	out [
		"total"
	] = total
	out [
		"excluded_owner_ids"
	] = excluded_owner_ids
	out [
		"seen_asset_keys"
	] = seen_asset_keys

	return out
func _add_unique_afterlife_family_id(ids: Array, seen: Dictionary, npc_id: int) -> void:
	if npc_id <= 0:
		return
	if seen.has(npc_id):
		return
	seen [npc_id] = true
	ids.append(npc_id)

func _collect_afterlife_family_member_ids(root: Person) -> Array:
	var ids: Array = []
	var seen: Dictionary = {}

	if root == null or gs == null:
		return ids

	_add_unique_afterlife_family_id(
		ids,
		seen,
		int(root.id)
	)

	var partner: Person = gs.get_valid_partner(
		root,
		true,
		true
	)

	if partner != null:
		_add_unique_afterlife_family_id(
			ids,
			seen,
			int(partner.id)
		)

	for parent_id_value in root.parents:
		_add_unique_afterlife_family_id(
			ids,
			seen,
			int(parent_id_value)
		)

	for child_id_value in root.children:
		_add_unique_afterlife_family_id(
			ids,
			seen,
			int(child_id_value)
		)






	if (
		not root.parents.is_empty()
		and gs.has_method(
			"get_npc_facts_by_id"
		)
	):
		var sibling_candidates: Dictionary = {}

		for parent_id_value in root.parents:
			var parent_id: int = int(
				parent_id_value
			)

			if parent_id <= 0:
				continue

			var parent_facts: Dictionary = (
				gs.get_npc_facts_by_id(
					parent_id
				)
			)
			var parent_children_raw: Variant = (
				parent_facts.get(
					"children",
					[]
				)
			)

			if typeof(parent_children_raw) != TYPE_ARRAY:
				continue

			for raw_candidate_id in parent_children_raw as Array:
				var candidate_id: int = int(
					raw_candidate_id
				)

				if (
					candidate_id <= 0
					or candidate_id == int(root.id)
				):
					continue

				sibling_candidates [
					candidate_id
				] = true

		for candidate_id_raw in sibling_candidates.keys():
			var candidate_id: int = int(
				candidate_id_raw
			)
			var candidate_facts: Dictionary = (
				gs.get_npc_facts_by_id(
					candidate_id
				)
			)
			var candidate_parents_raw: Variant = (
				candidate_facts.get(
					"parents",
					[]
				)
			)

			if typeof(candidate_parents_raw) != TYPE_ARRAY:
				continue

			var candidate_parents: Array = (
				candidate_parents_raw as Array
			)

			if candidate_parents == root.parents:
				_add_unique_afterlife_family_id(
					ids,
					seen,
					candidate_id
				)

	return ids
func _afterlife_net_worth_entry_value(entry: Dictionary) -> float:
	if entry.is_empty():
		return 0.0
	if entry.has("value"):
		return max(0.0, float(entry.get("value", 0.0)))
	if entry.has("price"):
		return max(0.0, float(entry.get("price", 0.0)))
	if entry.has("cost"):
		return max(0.0, float(entry.get("cost", 0.0)))
	if entry.has("worth"):
		return max(0.0, float(entry.get("worth", 0.0)))
	return 0.0

func _afterlife_net_worth_entry_key(prefix: String, category: String, entry: Dictionary) -> String:
	var entry_id: int = int(entry.get("id", -1))
	if entry_id > 0:
		return "%s:%s:%d" % [prefix, category, entry_id]
	var asset_name: String = str(entry.get("name", str(entry.get("type", str(entry.get("size", "asset"))))))
	var address: String = str(entry.get("address", ""))
	var value: int = int(round(_afterlife_net_worth_entry_value(entry)))
	return "%s:%s:%s:%s:%d" % [prefix, category, asset_name, address, value]

func _sum_afterlife_unique_flat_asset_bucket(bucket: Dictionary, owner_ids: Array, prefix: String, seen_asset_keys: Dictionary) -> float:
	var total: float = 0.0
	for owner_id_value in owner_ids:
		var owner_id: int = int(owner_id_value)
		if not bucket.has(owner_id):
			continue
		var raw_entries = bucket.get(owner_id, [])
		if raw_entries is Array:
			for raw_entry in raw_entries:
				if typeof(raw_entry) != TYPE_DICTIONARY:
					continue
				var entry: Dictionary = raw_entry
				var entry_key: String = _afterlife_net_worth_entry_key(prefix, "", entry)
				if seen_asset_keys.has(entry_key):
					continue
				seen_asset_keys [entry_key] = true
				total += _afterlife_net_worth_entry_value(entry)
	return total

func _sum_afterlife_unique_inventory_value(owner_ids: Array, seen_asset_keys: Dictionary) -> float:
	var total: float = 0.0
	if gs == null or gs.belongings_engine == null:
		return total
	var excluded_categories: Dictionary = {
		"Real Estate": true,
		"Vehicles": true,
		"Vehicle": true
	}
	for owner_id_value in owner_ids:
		var owner_id: int = int(owner_id_value)
		if not gs.belongings_engine.belongings.has(owner_id):
			continue
		var inventory: Dictionary = gs.belongings_engine.belongings.get(owner_id, {})
		for category_key in inventory.keys():
			var category: String = str(category_key)
			if excluded_categories.has(category):
				continue
			var raw_items = inventory.get(category_key, [])
			if raw_items is Array:
				for raw_item in raw_items:
					if typeof(raw_item) != TYPE_DICTIONARY:
						continue
					var item: Dictionary = raw_item
					var item_key: String = _afterlife_net_worth_entry_key("item", category, item)
					if seen_asset_keys.has(item_key):
						continue
					seen_asset_keys [item_key] = true
					total += _afterlife_net_worth_entry_value(item)
	return total

func _calculate_afterlife_personal_net_worth(person: Person) -> float:
	if person == null or gs == null:
		return 0.0
	var owner_ids: Array = [int(person.id)]
	var seen_asset_keys: Dictionary = {}
	var total: float = max(0.0, float(person.bank_balance))
	if gs.property_engine != null:
		total += _sum_afterlife_unique_flat_asset_bucket(gs.property_engine.properties, owner_ids, "property", seen_asset_keys)
	if gs.vehicle_engine != null:
		total += _sum_afterlife_unique_flat_asset_bucket(gs.vehicle_engine.vehicles, owner_ids, "vehicle", seen_asset_keys)
	total += _sum_afterlife_unique_inventory_value(owner_ids, seen_asset_keys)
	return total

func _calculate_afterlife_family_net_worth(root: Person) -> float:
	if root == null or gs == null:
		return 0.0
	var member_ids: Array = _collect_afterlife_family_member_ids(root)
	var effective_ids: Array = []
	var total: float = 0.0
	for member_id_value in member_ids:
		var member_id: int = int(member_id_value)
		var member: Person = gs.get_or_reactivate_npc_by_id(member_id)
		if member == null:
			continue
		if not member.alive and member_id != int(root.id):
			continue
		effective_ids.append(member_id)
		total += max(0.0, float(member.bank_balance))
	var seen_asset_keys: Dictionary = {}
	if gs.property_engine != null:
		total += _sum_afterlife_unique_flat_asset_bucket(gs.property_engine.properties, effective_ids, "property", seen_asset_keys)
	if gs.vehicle_engine != null:
		total += _sum_afterlife_unique_flat_asset_bucket(gs.vehicle_engine.vehicles, effective_ids, "vehicle", seen_asset_keys)
	total += _sum_afterlife_unique_inventory_value(effective_ids, seen_asset_keys)
	return total
func _estimate_earthly_moral_score(player: Person) -> float:
	if player == null:
		return 0.0

	var score: float = 0.0
	score += float(player.affection.get(int(player.id), 50)) * 0.0
	score -= float(player.scandal) * 0.2
	score += float(player.fame) * 0.04
	score += float(player.satisfaction) * 0.08

	var close_ids: Array = []
	for pid in player.parents:
		close_ids.append(int(pid))
	for cid in player.children:
		close_ids.append(int(cid))
	if player.partner != null:
		close_ids.append(int(player.partner.id))

	for rid in close_ids:
		var rel: Person = gs.get_or_reactivate_npc_by_id(int(rid))
		if rel == null:
			continue
		score += float(rel.affection.get(int(player.id), 50) - 50) * 0.25

	if "Generous" in player.traits:
		score += 8.0
	if "Kind" in player.traits:
		score += 8.0
	if "Cruel" in player.traits:
		score -= 10.0
	if "Evil" in player.traits:
		score -= 14.0

	return score

func _build_funeral_summary(player: Person) -> String:
	if player == null:
		return "The grave received you without witnesses."
	if str(player.cause_of_death).strip_edges() == "Smoked by Dwarves":
		return "The Dwarves sealed your body so nobody could ever find it."
	var moral_score: float = _estimate_earthly_moral_score(player)
	var family_present: int = 0
	var contempt_found: bool = false
	var close_ids: Array = []
	for pid in player.parents:
		close_ids.append(int(pid))
	for cid in player.children:
		close_ids.append(int(cid))
	if player.partner != null:
		close_ids.append(int(player.partner.id))
	for rid in close_ids:
		var rel: Person = gs.get_or_reactivate_npc_by_id(int(rid))
		if rel == null or not rel.alive:
			continue
		family_present += 1
		if int(rel.affection.get(int(player.id), 50)) <= 20:
			contempt_found = true
	if moral_score >= 15.0 and family_present > 0:
		return "You were remembered warmly. Your whole family came to your funeral."
	if moral_score <= -18.0 and contempt_found:
		return "No one came to your funeral. Someone in your family spat on your tombstone with contempt."
	if moral_score <= -10.0:
		return "Only a frog came to your funeral, and even it left before the service ended."
	if family_present > 0:
		return "A few grieving relatives came and stood in uneasy silence."
	return "The service was thin, quiet, and easy for the wind to ignore."





func has_pending_choice() -> bool:
	if gs == null:
		return false
	return str(gs.afterlife_state.get("pending_mode", "")) != ""


func get_pending_choice_result() -> Dictionary:
	var options: Array = []
	var raw_options = gs.afterlife_state.get("pending_options", [])
	if typeof(raw_options) == TYPE_ARRAY:
		options = raw_options.duplicate()

	return {
		"type": str(gs.afterlife_state.get("pending_type", "afterlife_pending_choice")),
		"text": str(gs.afterlife_state.get("pending_text", "")),
		"opps": options
	}


func choose_pending_option(
	action_label: String
) -> Dictionary:
	if not has_pending_choice():
		return {
			"success": false,
			"text": "There is no spiritual choice waiting right now."
		}

	var lookup_raw = (
		gs.afterlife_state.get(
			"pending_lookup",
			{}
		)
	)

	var lookup: Dictionary = {}

	if typeof(
		lookup_raw
	) == TYPE_DICTIONARY:
		lookup = lookup_raw

	if not lookup.has(
		action_label
	):
		return {
			"success": false,
			"text": (
				"That whisper does not match a current afterlife choice."
			)
		}

	var mode: String = str(
		gs.afterlife_state.get(
			"pending_mode",
			""
		)
	)

	var picked: Dictionary = (
		lookup [
			action_label
		]
	)

	_clear_pending_choice()

	if mode == "afterlife_exit_choice":
		var action: String = str(
			picked.get(
				"action",
				""
			)
		)

		match action:
			"random_life":
				gs.afterlife_state [
					"manual_player_inheritance_authority"
				] = false
				gs.afterlife_active = false
				gs.afterlife_state.clear()

				return {
					"success": true,
					"type": "afterlife_exit_random_life",
					"text": (
						"Your spirit slips away from the family line."
					),
					"opps": []
				}

			"custom_life":
				gs.afterlife_state [
					"manual_player_inheritance_authority"
				] = false
				gs.afterlife_active = false
				gs.afterlife_state.clear()

				return {
					"success": true,
					"type": "afterlife_exit_custom_life",
					"text": (
						"The afterlife closes. Return to God Mode "
						+ "to shape the next life manually."
					),
					"opps": []
				}

	if mode == "death_prompt":
		var action: String = str(
			picked.get(
				"action",
				""
			)
		)

		match action:
			"enter_afterlife_overlay":
				gs.afterlife_state [
					"death_popup_open"
				] = false
				gs.afterlife_state [
					"overlay_open"
				] = true

				return build_anchor_selection_result(
					gs.player
				)

			"continue_lineage":
				gs.afterlife_state [
					"death_popup_open"
				] = false
				gs.afterlife_state [
					"overlay_open"
				] = true

				return build_continue_lineage_result(
					gs.player
				)

			"continue_known_person":
				gs.afterlife_state [
					"death_popup_open"
				] = false
				gs.afterlife_state [
					"overlay_open"
				] = true

				return build_continue_known_person_result(
					gs.player
				)

			"random_life":
				gs.afterlife_state [
					"manual_player_inheritance_authority"
				] = false
				gs.afterlife_active = false
				gs.afterlife_state.clear()

				return {
					"success": true,
					"type": "afterlife_exit_random_life",
					"text": (
						"Your spirit slips away from the family line. "
						+ "Press Age Up to begin a random new life."
					),
					"opps": []
				}

			"custom_life":
				gs.afterlife_state [
					"manual_player_inheritance_authority"
				] = false
				gs.afterlife_active = false
				gs.afterlife_state.clear()

				return {
					"success": true,
					"type": "afterlife_exit_custom_life",
					"text": (
						"The afterlife closes. Return to God Mode "
						+ "to shape the next life manually."
					),
					"opps": []
				}

			"rewind_one_year":
				var rewind_ok: bool = (
					gs.consume_rewind_one_year()
				)

				if rewind_ok:
					return {
						"success": true,
						"type": "afterlife_rewind_applied",
						"text": (
							"Time buckled backward. You returned to "
							+ "the previous mortal year.\n\n"
							+ "Rewinds left in this life: %d."
						) % int(
							gs.rewind_uses_remaining
						),
						"opps": [
							"Live the Last Year Again"
						]
					}

				return {
					"success": false,
					"type": "afterlife_rewind_unavailable",
					"text": (
						"You cannot rewind this life any further."
					),
					"opps": []
				}

	if mode == "continue_lineage_target":
		var descendant_id: int = int(
			picked.get(
				"descendant_id",
				-1
			)
		)

		gs.afterlife_state [
			"continue_lineage_target_id"
		] = descendant_id
		gs.afterlife_state [
			"continue_lineage_selection_kind"
		] = "lineage"

		return _build_continue_lineage_toggle_prompt(
			descendant_id,
			true,
			"lineage"
		)

	if mode == "continue_known_person_target":
		var target_id: int = int(
			picked.get(
				"target_id",
				-1
			)
		)

		gs.afterlife_state [
			"continue_lineage_target_id"
		] = target_id
		gs.afterlife_state [
			"continue_lineage_selection_kind"
		] = "known_person"

		return _build_continue_lineage_toggle_prompt(
			target_id,
			false,
			"known_person"
		)

	if mode == "continue_lineage_transfer_toggle":
		var descendant_id: int = int(
			gs.afterlife_state.get(
				"continue_lineage_target_id",
				-1
			)
		)

		var transfer_estate: bool = bool(
			picked.get(
				"transfer_estate",
				false
			)
		)

		return _continue_lineage_as_descendant(
			descendant_id,
			transfer_estate
		)



	if mode == "anchor":
		var descendant_id: int = int(picked.get("descendant_id", -1))
		gs.afterlife_state ["anchored_descendant_id"] = descendant_id
		gs.afterlife_state ["overlay_open"] = true

		var anchor: Person = gs.get_or_reactivate_npc_by_id(descendant_id)
		var anchor_name: String = "your bloodline"
		if anchor != null:
			anchor_name = ("%s %s" % [anchor.first_name, anchor.last_name]).strip_edges()

		if anchor != null and anchor.alive:
			return _begin_afterlife_round(anchor, 1, "You anchored yourself to %s." % anchor_name)

		return {
			"success": false,
			"type": "afterlife_anchor_lost",
			"text": "That descendant slipped out of reach before the afterlife could settle on them.",
			"opps": build_anchor_selection_result(gs.player).get("opps", [])
		}
	if mode == "reincarnation_slot_pick":
		var slot_pick: Dictionary = {}
		if typeof(picked) == TYPE_DICTIONARY:
			slot_pick = picked.duplicate(true)
		if slot_pick.is_empty():
			return {
				"success": false,
				"text": "That birth slot is no longer available."
			}
		gs.afterlife_state ["reincarnation_selected_slot"] = slot_pick
		var anchor_id: int = int(gs.afterlife_state.get("anchored_descendant_id", -1))
		var anchor: Person = gs.get_or_reactivate_npc_by_id(anchor_id)
		if gs.lineage_engine != null and gs.lineage_engine.has_method("build_afterlife_prebirth_adventure"):
			var adventure: Dictionary = gs.lineage_engine.build_afterlife_prebirth_adventure(anchor, slot_pick)
			gs.afterlife_state ["pending_mode"] = "reincarnation_prebirth_adventure"
			gs.afterlife_state ["pending_type"] = "afterlife_prebirth_lineage_adventure"
			gs.afterlife_state ["pending_text"] = str(adventure.get("text", "A final family story opens before reincarnation."))
			gs.afterlife_state ["pending_lookup"] = adventure.get("lookup", {}).duplicate(true) if typeof(adventure.get("lookup", {})) == TYPE_DICTIONARY else {}
			gs.afterlife_state ["pending_options"] = adventure.get("opps", []).duplicate(true) if typeof(adventure.get("opps", [])) == TYPE_ARRAY else []
			gs.afterlife_state ["pending_lineage_adventure"] = adventure.duplicate(true)
			gs.afterlife_state ["overlay_open"] = true
			gs.afterlife_state ["death_popup_open"] = false
			return get_pending_choice_result()
		gs.afterlife_state ["pending_mode"] = "reincarnation_identity_form"
		gs.afterlife_state ["pending_type"] = "afterlife_reincarnation_identity_form"
		gs.afterlife_state ["pending_text"] = "You are about to be reincarnated into %s.\n\nNAME YOURSELF:\nCHOOSE YOUR GENDER:\n\nPress REINCARNATE when ready." % str(slot_pick.get("label", "this family line"))
		gs.afterlife_state ["pending_lookup"] = {}
		gs.afterlife_state ["pending_options"] = []
		gs.afterlife_state ["overlay_open"] = true
		gs.afterlife_state ["death_popup_open"] = false
		return get_pending_choice_result()

	if mode == "reincarnation_slot_confirm":
		var confirmed: bool = bool(picked.get("confirmed", false))
		var slot_raw = gs.afterlife_state.get("reincarnation_selected_slot", {})
		if typeof(slot_raw) != TYPE_DICTIONARY or slot_raw.is_empty():
			return {
				"success": false,
				"text": "That birth slot is no longer available."
			}
		if not confirmed:
			var anchor_id: int = int(gs.afterlife_state.get("anchored_descendant_id", -1))
			var anchor: Person = gs.get_or_reactivate_npc_by_id(anchor_id)
			return _finalize_reincarnation_outcome(anchor, "Your spiritual years are complete.")

		gs.afterlife_state ["pending_mode"] = "reincarnation_identity_form"
		gs.afterlife_state ["pending_type"] = "afterlife_reincarnation_identity_form"
		gs.afterlife_state ["pending_text"] = "You are about to be reincarnated into %s.\n\nNAME YOURSELF:\nCHOOSE YOUR GENDER:\n\nPress REINCARNATE when ready." % str(slot_raw.get("label", "this family line"))
		gs.afterlife_state ["pending_lookup"] = {}
		gs.afterlife_state ["pending_options"] = []
		gs.afterlife_state ["overlay_open"] = true
		gs.afterlife_state ["death_popup_open"] = false
		return get_pending_choice_result()
	if mode == "reincarnation_prebirth_adventure":
		var slot_raw: Variant = gs.afterlife_state.get("reincarnation_selected_slot", {})
		var slot_pick: Dictionary = slot_raw.duplicate(true) if typeof(slot_raw) == TYPE_DICTIONARY else {}
		if slot_pick.is_empty():
			return {
				"success": false,
				"text": "That birth slot is no longer available."
			}
		var anchor_id: int = int(gs.afterlife_state.get("anchored_descendant_id", -1))
		var anchor: Person = gs.get_or_reactivate_npc_by_id(anchor_id)
		if gs.lineage_engine != null and gs.lineage_engine.has_method("apply_afterlife_prebirth_choice"):
			var birth_bias: Dictionary = gs.lineage_engine.apply_afterlife_prebirth_choice(slot_pick, picked, anchor)
			gs.afterlife_state ["reincarnation_lineage_birth_bias"] = birth_bias.duplicate(true)
			gs.afterlife_state ["reincarnation_selected_slot"] = slot_pick.duplicate(true)
		gs.afterlife_state ["pending_mode"] = "reincarnation_identity_form"
		gs.afterlife_state ["pending_type"] = "afterlife_reincarnation_identity_form"
		gs.afterlife_state ["pending_text"] = "The final ancestor-pressure scene closes.\n\nYou are about to be reincarnated into %s.\n\nNAME YOURSELF:\nCHOOSE YOUR GENDER:\n\nPress REINCARNATE when ready." % str(slot_pick.get("label", "this family line"))
		gs.afterlife_state ["pending_lookup"] = {}
		gs.afterlife_state ["pending_options"] = []
		gs.afterlife_state ["overlay_open"] = true
		gs.afterlife_state ["death_popup_open"] = false
		return get_pending_choice_result()
	if mode == "scenario":
		var anchor_id: int = int(gs.afterlife_state.get("anchored_descendant_id", -1))
		var anchor: Person = gs.get_or_reactivate_npc_by_id(anchor_id)
		if anchor == null or not anchor.alive:
			gs.afterlife_state ["anchored_descendant_id"] = -1
			return {
				"success": false,
				"type": "afterlife_anchor_lost",
				"text": "Your anchor is no longer alive. Choose another descendant.",
				"opps": build_anchor_selection_result(gs.player).get("opps", [])
			}

		var picked_copy: Dictionary = picked.duplicate(true)
		var selections: Array = gs.afterlife_state.get("selected_interventions", [])
		selections.append(picked_copy)
		gs.afterlife_state ["selected_interventions"] = selections
		gs.afterlife_state ["selected_intervention"] = picked_copy

		var score_delta: float = float(picked_copy.get("score_delta", 0.0))
		var good_delta: float = float(picked_copy.get("good_karma_delta", 0.0))
		var bad_delta: float = float(picked_copy.get("bad_karma_delta", 0.0))

		gs.afterlife_state ["round_score"] = float(gs.afterlife_state.get("round_score", 0.0)) + score_delta
		gs.afterlife_state ["good_karma"] = float(gs.afterlife_state.get("good_karma", 0.0)) + good_delta
		gs.afterlife_state ["bad_karma"] = float(gs.afterlife_state.get("bad_karma", 0.0)) + bad_delta

		var round_results: Array = gs.afterlife_state.get("round_results", [])
		round_results.append({
			"choice": action_label,
			"response": str(picked_copy.get("response", "")),
			"score_delta": score_delta
		})
		gs.afterlife_state ["round_results"] = round_results

		var scenario_index: int = int(gs.afterlife_state.get("scenario_index", 0)) + 1
		gs.afterlife_state ["scenario_index"] = scenario_index

		return _queue_afterlife_scenario(anchor, [
			str(picked_copy.get("response", "The bloodline trembles under your whisper."))
		])

	return {
		"success": false,
		"text": "Unknown afterlife choice mode."
	}
func submit_reincarnation_identity(first_name: String, last_name: String, gender: String) -> Dictionary:
	var slot_raw = gs.afterlife_state.get("reincarnation_selected_slot", {})
	if typeof(slot_raw) != TYPE_DICTIONARY or slot_raw.is_empty():
		return {
			"success": false,
			"text": "That birth slot is no longer available."
		}
	var lineage_bias_raw: Variant = gs.afterlife_state.get("reincarnation_lineage_birth_bias", {})
	var lineage_bias: Dictionary = lineage_bias_raw.duplicate(true) if typeof(lineage_bias_raw) == TYPE_DICTIONARY else {}
	var lineage_contract: Dictionary = lineage_bias.get("lineage_birth_contract", {}).duplicate(true) if typeof(lineage_bias.get("lineage_birth_contract", {})) == TYPE_DICTIONARY else {}
	var settings: Dictionary = {
		"pending_reincarnation_slot": slot_raw.duplicate(true),
		"first_name": first_name.strip_edges(),
		"last_name": last_name.strip_edges(),
		"gender": gender.strip_edges(),
		"choose_adventure_lineage_birth": not lineage_contract.is_empty(),
		"lineage_birth_contract": lineage_contract.duplicate(true),
		"narrative_birth_bias": lineage_bias.duplicate(true)
	}
	var child: Person = gs.create_custom_reincarnated_child(settings)
	if child == null:
		return {
			"success": false,
			"text": "The family line could not hold the reincarnation."
		}
	if gs.lineage_engine != null and gs.lineage_engine.has_method("apply_birth_contract_to_existing_child") and not lineage_contract.is_empty():
		gs.lineage_engine.apply_birth_contract_to_existing_child(child, lineage_contract)
	var child_name: String = ("%s %s" % [child.first_name, child.last_name]).strip_edges()
	return {
		"success": true,
		"type": "afterlife_reincarnated",
		"text": "A rare conception story wrapped itself around your return.\n\nYou were reborn as %s." % child_name,
		"opps": []
	}
func _continue_lineage_option_label(
	dead_player_id: int,
	descendant: Person
) -> String:
	if descendant == null:
		return ""

	var dead_player: Person = (
		gs.get_or_reactivate_npc_by_id(
			dead_player_id
		)
	)

	var relationship_label: String = (
		_continuation_relationship_label(
			dead_player,
			descendant
		)
	)

	var job_text: String = (
		descendant.job
		if str(
			descendant.job
		).strip_edges() != ""
		else "Unemployed"
	)

	return (
		"Continue as %s %s — %s • age %d • job: %s"
		% [
			descendant.first_name,
			descendant.last_name,
			relationship_label,
			int(
				descendant.age
			),
			job_text
		]
	)

func build_continue_lineage_result(
	player: Person
) -> Dictionary:
	if player == null:
		return {
			"type": "no_descendants",
			"options": [
				"random_life",
				"custom_life",
				"rewind_one_year"
			]
		}

	if not gs.afterlife_active:
		enter_afterlife_for_player(
			player
		)

	var dead_player_id: int = int(
		gs.afterlife_state.get(
			"ghost_player_id",
			player.id
		)
	)

	var candidates: Array = (
		_collect_living_descendant_candidates(
			dead_player_id
		)
	)

	if candidates.is_empty():
		return {
			"type": "no_descendants",
			"text": (
				"There are no living descendants available to continue as."
			),
			"opps": [
				"Random Life",
				"Custom Life"
			]
		}

	var options: Array = []
	var lookup: Dictionary = {}

	for descendant in candidates:
		if descendant == null:
			continue

		var label: String = (
			_continue_lineage_option_label(
				dead_player_id,
				descendant
			)
		)

		if label == "":
			continue

		options.append(
			label
		)

		lookup [
			label
		] = {
			"descendant_id": int(
				descendant.id
			),
			"selection_kind": "lineage"
		}

	gs.afterlife_state [
		"pending_mode"
	] = "continue_lineage_target"
	gs.afterlife_state [
		"pending_type"
	] = "afterlife_continue_lineage_target"
	gs.afterlife_state [
		"pending_text"
	] = "Choose the descendant you want to continue as."
	gs.afterlife_state [
		"pending_lookup"
	] = lookup
	gs.afterlife_state [
		"pending_options"
	] = options
	gs.afterlife_state [
		"death_popup_open"
	] = false
	gs.afterlife_state [
		"overlay_open"
	] = true

	return get_pending_choice_result()
func build_continue_known_person_result(
	player: Person
) -> Dictionary:
	if (
		player == null
		or gs == null
	):
		return {
			"success": false,
			"type": "afterlife_continue_known_unavailable",
			"text": (
				"No known-person continuation contract is available."
			),
			"opps": []
		}

	if not gs.afterlife_active:
		enter_afterlife_for_player(
			player
		)

	var dead_id: int = int(
		gs.afterlife_state.get(
			"ghost_player_id",
			int(
				player.id
			)
		)
	)

	var dead_player: Person = (
		gs.get_or_reactivate_npc_by_id(
			dead_id
		)
	)

	var contracts_raw: Variant = (
		gs.afterlife_state.get(
			"continue_known_person_candidate_contracts",
			[]
		)
	)

	var contracts: Array = (
		contracts_raw as Array
		if typeof(
			contracts_raw
		) == TYPE_ARRAY
		else []
	)




	if (
		contracts.is_empty()
		and dead_player != null
		and gs.relationships_hub_contract_engine != null
		and gs.relationships_hub_contract_engine.has_method(
			"continuation_known_person_contracts"
		)
	):
		contracts = (
			gs.relationships_hub_contract_engine
			.continuation_known_person_contracts(
				dead_player
			)
		)

		gs.afterlife_state [
			"continue_known_person_candidate_contracts"
		] = contracts.duplicate(
			true
		)

	var options: Array = []
	var lookup: Dictionary = {}

	for raw_contract in contracts:
		if typeof(
			raw_contract
		) != TYPE_DICTIONARY:
			continue

		var contract: Dictionary = (
			raw_contract as Dictionary
		)

		var target_id: int = int(
			contract.get(
				"target_id",
				-1
			)
		)

		if target_id <= 0:
			continue

		var option_label: String = str(
			contract.get(
				"option_label",
				""
			)
		).strip_edges()

		if option_label == "":
			continue

		options.append(
			option_label
		)

		lookup [
			option_label
		] = {
			"target_id": target_id,
			"selection_kind": "known_person",
			"relationship_label": str(
				contract.get(
					"relationship_label",
					"Relationship"
				)
			)
		}

	gs.afterlife_state [
		"pending_mode"
	] = "continue_known_person_target"
	gs.afterlife_state [
		"pending_type"
	] = "afterlife_continue_known_person_target"
	gs.afterlife_state [
		"pending_text"
	] = (
		"Choose someone you know. "
		+ "Friends, current romantic partners, "
		+ "and live fling relationships publish here."
	)
	gs.afterlife_state [
		"pending_lookup"
	] = lookup
	gs.afterlife_state [
		"pending_options"
	] = options
	gs.afterlife_state [
		"death_popup_open"
	] = false
	gs.afterlife_state [
		"overlay_open"
	] = true

	if options.is_empty():
		gs.afterlife_state [
			"pending_text"
		] = (
			"Nobody in your current friend or romantic orbit "
			+ "is available to continue as."
		)

	return get_pending_choice_result()


func _build_continue_lineage_toggle_prompt(
	descendant_id: int,
	allow_inheritance: bool = true,
	selection_kind: String = "lineage"
) -> Dictionary:
	if (
		gs == null
		or typeof(
			gs.afterlife_state
		) != TYPE_DICTIONARY
	):
		return {
			"success": false,
			"type": "afterlife_continue_lineage_unavailable",
			"text": "The continuation contract is unavailable.",
			"opps": []
		}

	var descendant: Person = (
		gs.get_or_reactivate_npc_by_id(
			descendant_id
		)
	)




	if (
		descendant == null
		or not bool(
			descendant.alive
		)
		or float(
			descendant.health
		) <= 0.0
	):
		if selection_kind == "known_person":
			return build_continue_known_person_result(
				gs.player
			)

		return build_continue_lineage_result(
			gs.player
		)

	var dead_id: int = int(
		gs.afterlife_state.get(
			"ghost_player_id",
			-1
		)
	)

	var dead_player: Person = (
		gs.get_or_reactivate_npc_by_id(
			dead_id
		)
	)

	var relationship_label: String = (
		_continuation_relationship_label(
			dead_player,
			descendant
		)
	)

	var full_name: String = (
		"%s %s"
		% [
			descendant.first_name,
			descendant.last_name
		]
	).strip_edges()

	var job_text: String = (
		descendant.job
		if str(
			descendant.job
		).strip_edges() != ""
		else "Unemployed"
	)

	gs.afterlife_state [
		"continue_lineage_target_id"
	] = int(
		descendant.id
	)
	gs.afterlife_state [
		"continue_lineage_selection_kind"
	] = selection_kind

	gs.afterlife_state [
		"pending_mode"
	] = "continue_lineage_transfer_toggle"
	gs.afterlife_state [
		"pending_type"
	] = "afterlife_continue_lineage_transfer_toggle"
	gs.afterlife_state [
		"pending_text"
	] = (
		"Continue as %s?\n\n"
		+ "Relationship: %s\n"
		+ "Age: %d\n"
		+ "Job: %s"
	) % [
		full_name,
		relationship_label,
		int(
			descendant.age
		),
		job_text
	]

	if allow_inheritance:
		gs.afterlife_state [
			"pending_text"
		] += (
			"\n\nShould their inheritance come with them?"
		)

		gs.afterlife_state [
			"pending_lookup"
		] = {
			"Continue Lineage": {
				"transfer_estate": false
			},
			"Continue Lineage + Inheritance": {
				"transfer_estate": true
			}
		}

		gs.afterlife_state [
			"pending_options"
		] = [
			"Continue Lineage",
			"Continue Lineage + Inheritance"
		]
	else:
		gs.afterlife_state [
			"pending_lookup"
		] = {
			"Continue as Them": {
				"transfer_estate": false
			}
		}

		gs.afterlife_state [
			"pending_options"
		] = [
			"Continue as Them"
		]

	return get_pending_choice_result()
func _continue_lineage_as_descendant(
	descendant_id: int,
	transfer_estate: bool
) -> Dictionary:
	if (
		gs == null
		or typeof(
			gs.afterlife_state
		) != TYPE_DICTIONARY
	):
		return {
			"success": false,
			"type": "afterlife_continue_lineage_unavailable",
			"text": "The lineage continuation contract is unavailable.",
			"opps": []
		}

	var dead_id: int = int(
		gs.afterlife_state.get(
			"ghost_player_id",
			-1
		)
	)

	var dead_player: Person = (
		gs.get_or_reactivate_npc_by_id(
			dead_id
		)
	)

	var descendant: Person = (
		gs.get_or_reactivate_npc_by_id(
			descendant_id
		)
	)

	var selection_kind: String = str(
		gs.afterlife_state.get(
			"continue_lineage_selection_kind",
			"lineage"
		)
	).strip_edges().to_lower()

	if (
		descendant == null
		or not descendant.alive
		or float(
			descendant.health
		) <= 0.0
	):
		if selection_kind == "known_person":
			return build_continue_known_person_result(
				dead_player
			)

		return build_continue_lineage_result(
			dead_player
		)

	var relationship_label: String = (
		_continuation_relationship_label(
			dead_player,
			descendant
		)
	)



	var intent: Dictionary = {
		"schema": (
			"eralife.afterlife."
			+ "continuation_commit_intent"
		),
		"version": 1,
		"deceased_actor_id": dead_id,
		"target_actor_id": descendant_id,
		"selection_kind": selection_kind,
		"relationship_label": relationship_label,
		"transfer_estate": transfer_estate,
		"status": "awaiting_resident_destination",
		"immutable_contract_references": true,
		"switch_press_build_forbidden": true,
		"blocks_ui": false,
		"ready_gate_member": false,
		"ui_is_renderer_only": true,
		"authored_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	gs.afterlife_state [
		"continue_lineage_target_id"
	] = descendant_id
	gs.afterlife_state [
		"continue_lineage_transfer_estate"
	] = transfer_estate
	gs.afterlife_state [
		"continue_lineage_commit_intent"
	] = intent


	gs.afterlife_state [
		"pending_mode"
	] = "continue_lineage_commit_pending"
	gs.afterlife_state [
		"pending_type"
	] = "afterlife_continue_lineage_commit_pending"
	gs.afterlife_state [
		"pending_text"
	] = (
		"Choice locked: %s (%s).\n\n"
		+ "Their already-authored viewpoint is becoming resident "
		+ "in the background. You do not need to choose again."
	) % [
		(
			"%s %s"
			% [
				descendant.first_name,
				descendant.last_name
			]
		).strip_edges(),
		relationship_label
	]
	gs.afterlife_state [
		"pending_lookup"
	] = {}
	gs.afterlife_state [
		"pending_options"
	] = []




	_queue_continuation_destination_if_needed(
		dead_player,
		descendant
	)





	var committed: Dictionary = (
		_commit_continue_lineage_intent_if_hot()
	)

	if not committed.is_empty():
		return committed

	return get_pending_choice_result()
func _queue_continuation_destination_if_needed(
	dead_player: Person,
	target: Person
) -> void:
	if (
		dead_player == null
		or target == null
		or gs == null
		or gs.relationships_hub_contract_engine == null
	):
		return



	_bind_continue_lineage_destination_publication()








	gs.relationships_hub_contract_engine.resolve_intent(
		dead_player,
		{
			"action_id": "queue_switch_shell_stage",
			"target_id": int(
				target.id
			),
			"complete_destination_deck_required": false,
			"relationship_profile_visible_packet": false,
			"explicit_relationship_profile_observation": false,
			"profile_switch_packet_required_before_visible": false,
			"pointer_only_packet_forbidden": false,
			"allow_pointer_core_only_preparation": true,
			"visible_card_may_not_publish_complete_destination_deck": true,
			"detached_service_only": true,
			"background_only": true,
			"blocks_ui": false,
			"support_deck_blocks_switch": false,
			"progressive_observability": true,
			"observation_required": false,
			"switch_press_build_forbidden": true,
			"switch_press_must_not_build_surface": true,
			"ready_gate_member": false,
			"ui_is_renderer_only": true,
			"source": (
				"afterlife_influence_engine."
				+ "continuation_destination_fallback_queue"
			)
		}
	)
func _bind_continue_lineage_destination_publication() -> void:
	if (
		gs == null
		or gs.relationships_hub_contract_engine == null
	):
		continue_lineage_destination_publication_bound = false
		return

	var callback:= Callable(
		self,
		"_on_continue_lineage_destination_packet_published"
	)

	if not (
		gs.relationships_hub_contract_engine
		.resident_switch_destination_packet_published
		.is_connected(
			callback
		)
	):
		gs.relationships_hub_contract_engine \
.resident_switch_destination_packet_published \
.connect(
				callback
			)

	continue_lineage_destination_publication_bound = (
		gs.relationships_hub_contract_engine
		.resident_switch_destination_packet_published
		.is_connected(
			callback
		)
	)


func _on_continue_lineage_destination_packet_published(
	target_id: int,
	switch_packet: Dictionary
) -> void:
	if (
		gs == null
		or not gs.afterlife_active
		or switch_packet.is_empty()
		or target_id <= 0
	):
		return

	var dead_id: int = int(
		gs.afterlife_state.get(
			"ghost_player_id",
			-1
		)
	)

	var dead_player: Person = (
		gs.get_or_reactivate_npc_by_id(
			dead_id
		)
	)

	var target: Person = (
		gs.get_or_reactivate_npc_by_id(
			target_id
		)
	)

	if (
		dead_player == null
		or target == null
	):
		return







	var prepared_packet: Dictionary = (
		_continue_lineage_prepared_switch_packet_for_actor(
			target_id
		)
	)

	if prepared_packet.is_empty():



		_queue_continuation_destination_if_needed(
			dead_player,
			target
		)
		return





	_store_continue_lineage_perspective_handoff(
		dead_player,
		target,
		prepared_packet
	)

	var intent_raw: Variant = (
		gs.afterlife_state.get(
			"continue_lineage_commit_intent",
			{}
		)
	)

	if typeof(
		intent_raw
	) != TYPE_DICTIONARY:
		return

	var intent: Dictionary = (
		intent_raw as Dictionary
	)

	if int(
		intent.get(
			"target_actor_id",
			-1
		)
	) != target_id:
		return

	var result: Dictionary = (
		_commit_continue_lineage_intent_if_hot()
	)

	if result.is_empty():
		return

	continue_lineage_commit_published.emit(
		result
	)
func _commit_continue_lineage_intent_if_hot() -> Dictionary:
	if (
		gs == null
		or typeof(
			gs.afterlife_state
		) != TYPE_DICTIONARY
	):
		return {}

	var intent_raw: Variant = (
		gs.afterlife_state.get(
			"continue_lineage_commit_intent",
			{}
		)
	)

	if typeof(
		intent_raw
	) != TYPE_DICTIONARY:
		return {}

	var intent: Dictionary = (
		intent_raw as Dictionary
	)

	if intent.is_empty():
		return {}

	var dead_id: int = int(
		intent.get(
			"deceased_actor_id",
			-1
		)
	)

	var target_id: int = int(
		intent.get(
			"target_actor_id",
			-1
		)
	)

	var transfer_estate: bool = bool(
		intent.get(
			"transfer_estate",
			false
		)
	)

	var selection_kind: String = str(
		intent.get(
			"selection_kind",
			"lineage"
		)
	).strip_edges().to_lower()

	var dead_player: Person = (
		gs.get_or_reactivate_npc_by_id(
			dead_id
		)
	)

	var target: Person = (
		gs.get_or_reactivate_npc_by_id(
			target_id
		)
	)





	if (
		target == null
		or not bool(
			target.alive
		)
		or float(
			target.health
		) <= 0.0
	):
		return {}

	var handoff_registry_raw: Variant = (
		gs.afterlife_state.get(
			"continue_lineage_perspective_handoff_by_actor",
			{}
		)
	)

	var handoff_registry: Dictionary = (
		handoff_registry_raw as Dictionary
		if typeof(
			handoff_registry_raw
		) == TYPE_DICTIONARY
		else {}
	)

	var handoff_raw: Variant = (
		handoff_registry.get(
			str(
				target_id
			),
			{}
		)
	)

	var handoff: Dictionary = (
		handoff_raw as Dictionary
		if typeof(
			handoff_raw
		) == TYPE_DICTIONARY
		else {}
	)





	var switch_packet: Dictionary = (
		_continue_lineage_prepared_switch_packet_for_actor(
			target_id
		)
	)







	if switch_packet.is_empty():
		return {}

	var surface_raw: Variant = (
		switch_packet.get(
			"surface_contract",
			{}
		)
	)

	var surface: Dictionary = (
		surface_raw as Dictionary
		if typeof(
			surface_raw
		) == TYPE_DICTIONARY
		else {}
	)

	var pointer_revision: String = str(
		switch_packet.get(
			"pointer_revision",
			surface.get(
				"pointer_revision",
				""
			)
		)
	).strip_edges()

	if (
		pointer_revision == ""
		or gs.universal_switch_contract_engine == null
		or not gs.universal_switch_contract_engine.has_method(
			"commit_profile_switch_intent"
		)
	):
		return {}













	var recovered_handoff_from_resident_packet: bool = false

	if handoff.is_empty():
		var relationship_label: String = str(
			intent.get(
				"relationship_label",
				"predecessor"
			)
		).strip_edges().to_lower()

		if relationship_label in [
			"",
			"relationship",
			"stranger",
			"unknown",
			"relative"
		]:
			relationship_label = "predecessor"

		var press_frame_lens_raw: Variant = (
			switch_packet.get(
				"press_frame_lens_cache",
				surface.get(
					"press_frame_lens_cache",
					{}
				)
			)
		)

		var press_frame_lens_cache: Dictionary = (
			(press_frame_lens_raw as Dictionary).duplicate(
				false
			)
			if typeof(
				press_frame_lens_raw
			) == TYPE_DICTIONARY
			else {}
		)

		var main_tab_surface_deck_hot: bool = bool(
			switch_packet.get(
				"main_tab_surface_deck_hot",
				surface.get(
					"main_tab_surface_deck_hot",
					false
				)
			)
		)

		var support_main_tab_deck_hot: bool = bool(
			switch_packet.get(
				"support_main_tab_deck_hot",
				surface.get(
					"support_main_tab_deck_hot",
					main_tab_surface_deck_hot
				)
			)
		)

		handoff = {
			"schema": (
				"eralife.afterlife."
				+ "continue_lineage_perspective_handoff"
			),
			"version": 2,
			"deceased_actor_id": dead_id,
			"actor_id": target_id,
			"relationship_to_deceased": relationship_label,
			"diary_text": (
				"My %s's spirit flows through me."
				% relationship_label
			),
			"pointer_revision": pointer_revision,
			"prepared_world_year": int(
				gs.year
			),
			"prepared_actor_age": int(
				target.age
			),
			"visible_switch_packet": (
				switch_packet.duplicate(
					false
				)
			),
			"press_frame_lens_cache": (
				press_frame_lens_cache
			),
			"life_diary_cursor_contract": {
				"actor_id": target_id,
				"world_feed_cursor": int(
					gs.world_feed.size()
				),
				"player_memory_cursor": (
					target.memories.size()
					if target.memories != null
					else 0
				),
				"source": (
					"afterlife_influence_engine."
					+ "continuation_resident_packet_recovery"
				),
				"immutable": true,
				"ui_is_reader_only": true
			},
			"main_tab_surface_deck_hot": (
				main_tab_surface_deck_hot
			),
			"support_main_tab_deck_hot": (
				support_main_tab_deck_hot
			),
			"support_enrichment_pending": (
				not support_main_tab_deck_hot
			),
			"switch_packet_core_hot": true,
			"switch_packet_hot": true,
			"recovered_from_already_resident_packet": true,
			"switch_press_build_forbidden": true,
			"ready_gate_member": false,
			"immutable": true,
			"ui_is_reader_only": true
		}

		recovered_handoff_from_resident_packet = true

	var spirit_text: String = str(
		handoff.get(
			"diary_text",
			"My predecessor's spirit flows through me."
		)
	).strip_edges()

	if spirit_text == "":
		spirit_text = (
			"My predecessor's spirit flows through me."
		)






	var switch_report: Dictionary = (
		gs.universal_switch_contract_engine
		.commit_profile_switch_intent(
			target,
			{
				"actor_id": target_id,
				"prepared_actor_id": target_id,
				"pointer_revision": pointer_revision,
				"source": (
					"afterlife_influence_engine."
					+ "continuation_commit"
				),
				"afterlife_continue_lineage": (
					selection_kind == "lineage"
				),
				"afterlife_continue_known_person": (
					selection_kind == "known_person"
				),
				"switch_press_build_forbidden": true,
				"ready_gate_member": false,
				"ui_is_renderer_only": true
			}
		)
	)

	if not bool(
		switch_report.get(
			"success",
			false
		)
	):



		gs.afterlife_state [
			"continue_lineage_last_switch_rejection"
		] = switch_report.duplicate(
			false
		)

		intent [
			"status"
		] = "awaiting_republished_pointer_revision"

		gs.afterlife_state [
			"continue_lineage_commit_intent"
		] = intent

		_queue_continuation_destination_if_needed(
			dead_player,
			target
		)

		return {}

	var inheritance_transferred: bool = false

	if (
		transfer_estate
		and dead_player != null
		and not bool(
			gs.afterlife_state.get(
				"continue_lineage_transfer_applied",
				false
			)
		)
	):
		_transfer_player_estate_to_descendant(
			dead_player,
			target
		)

		gs.afterlife_state [
			"continue_lineage_transfer_applied"
		] = true

		inheritance_transferred = true

	var diary_report: Dictionary = {}

	if (
		gs.life_diary_contract_engine != null
		and gs.life_diary_contract_engine.has_method(
			"emit_diary_intent"
		)
	):
		diary_report = (
			gs.life_diary_contract_engine.emit_diary_intent(
				{
					"type": "life_boundary_perspective",
					"actor_id": target_id,
					"actor_name": (
						"%s %s"
						% [
							target.first_name,
							target.last_name
						]
					).strip_edges(),
					"text": spirit_text,
					"year": int(
						gs.year
					),
					"age": int(
						target.age
					),
					"source": (
						"afterlife_influence_engine."
						+ "continuation_commit"
					),
					"dedupe_key": (
						"afterlife_continuation:%d:%d:%d"
						% [
							dead_id,
							target_id,
							int(
								gs.year
							)
						]
					),
					"perspective": "first_person",
					"narrator": "self",
					"meta": {
						"deceased_actor_id": dead_id,
						"relationship_to_deceased": str(
							handoff.get(
								"relationship_to_deceased",
								"predecessor"
							)
						),
						"continuation_kind": selection_kind,
						"inheritance_transferred": (
							inheritance_transferred
						),
						"ui_is_reader_only": true
					}
				},
				{
					"source": (
						"afterlife_influence_engine."
						+ "continuation_commit"
					),
					"afterlife_continue_lineage": (
						selection_kind == "lineage"
					),
					"afterlife_continue_known_person": (
						selection_kind == "known_person"
					),
					"ui_is_reader_only": true
				}
			)
		)

	gs.push_world_feed(
		"%s continued the story after %s died."
		% [
			(
				"%s %s"
				% [
					target.first_name,
					target.last_name
				]
			).strip_edges(),
			str(
				gs.afterlife_state.get(
					"ghost_name",
					"Someone they knew"
				)
			)
		],
		{
			"npc_id": target_id,
			"personally_relevant": false,
			"suppress_diary": true,
			"category": "afterlife",
			"event_name": (
				"afterlife_continue_known_person"
				if selection_kind == "known_person"
				else "afterlife_continue_lineage"
			),
			"source": "afterlife_influence_engine"
		}
	)

	var cursor_raw: Variant = (
		handoff.get(
			"life_diary_cursor_contract",
			{}
		)
	)

	var cursor_contract: Dictionary = (
		(cursor_raw as Dictionary).duplicate(
			false
		)
		if typeof(
			cursor_raw
		) == TYPE_DICTIONARY
		else {}
	)

	cursor_contract [
		"actor_id"
	] = target_id
	cursor_contract [
		"world_feed_cursor"
	] = int(
		gs.world_feed.size()
	)
	cursor_contract [
		"player_memory_cursor"
	] = (
		target.memories.size()
		if target.memories != null
		else 0
	)
	cursor_contract [
		"source"
	] = (
		"afterlife_influence_engine."
		+ "continuation_commit"
	)
	cursor_contract [
		"immutable"
	] = true
	cursor_contract [
		"ui_is_reader_only"
	] = true

	var diary_committed: bool = bool(
		diary_report.get(
			"success",
			false
		)
	)

	var diary_delta_contract: Dictionary = {
		"schema": "eralife.life_diary.entry_delta_contract",
		"version": 1,
		"actor_id": target_id,
		"year": int(
			gs.year
		),
		"age": int(
			target.age
		),
		"lines": [
			spirit_text
		],
		"signature": str(
			diary_report.get(
				"signature",
				(
					"afterlife_continuation:%d:%d:%d"
					% [
						dead_id,
						target_id,
						int(
							gs.year
						)
					]
				)
			)
		),
		"intent_type": "life_boundary_perspective",
		"source": (
			"afterlife_influence_engine."
			+ "continuation_commit"
		),
		"authority_committed": diary_committed,
		"immutable": true,
		"ui_is_reader_only": true
	}

	var committed_handoff: Dictionary = (
		handoff.duplicate(
			false
		)
	)




	committed_handoff [
		"visible_switch_packet"
	] = switch_packet.duplicate(
		false
	)
	committed_handoff [
		"pointer_revision"
	] = pointer_revision
	committed_handoff [
		"life_diary_cursor_contract"
	] = cursor_contract
	committed_handoff [
		"inheritance_transferred"
	] = inheritance_transferred
	committed_handoff [
		"continuation_kind"
	] = selection_kind
	committed_handoff [
		"recovered_from_already_resident_packet"
	] = recovered_handoff_from_resident_packet
	committed_handoff [
		"committed_pointer_revision"
	] = str(
		switch_report.get(
			"pointer_revision",
			pointer_revision
		)
	)
	committed_handoff [
		"controlled_actor_id"
	] = target_id
	committed_handoff [
		"previous_actor_id"
	] = int(
		switch_report.get(
			"previous_actor_id",
			dead_id
		)
	)
	committed_handoff [
		"committed_at_ms"
	] = int(
		Time.get_ticks_msec()
	)



	gs.afterlife_active = false
	gs.awaiting_new_life = false
	gs.transient_afterlife_biases.clear()
	gs.afterlife_state.clear()

	return {
		"success": true,
		"type": "continue_lineage_complete",
		"text": spirit_text,
		"controlled_actor_id": target_id,
		"previous_actor_id": int(
			switch_report.get(
				"previous_actor_id",
				dead_id
			)
		),
		"pointer_revision": str(
			switch_report.get(
				"pointer_revision",
				pointer_revision
			)
		),
		"perspective_handoff_contract": committed_handoff,
		"life_diary_cursor_contract": cursor_contract,
		"life_boundary_diary_delta_contract": (
			diary_delta_contract
		),
		"inheritance_transferred": inheritance_transferred,
		"continuation_kind": selection_kind,
		"recovered_from_already_resident_packet": (
			recovered_handoff_from_resident_packet
		),
		"ready_gate_member": false,
		"opps": []
	}
func _queue_continue_known_destination_prewarm(
	dead_player_id: int
) -> void:
	if (
		gs == null
		or dead_player_id <= 0
	):
		return

	var dead_key: String = str(
		dead_player_id
	)

	if continue_known_destination_prewarm_keys.has(
		dead_key
	):
		return

	continue_known_destination_prewarm_keys [
		dead_key
	] = true

	continue_known_destination_prewarm_queue.append({
		"dead_player_id": dead_player_id,
		"candidate_contracts": [],
		"candidate_index": 0,
		"contracts_authored": false,
		"queued_at_ms": int(
			Time.get_ticks_msec()
		),
		"requires_ui_idle": false,
		"blocks_ui": false,
		"ready_gate_member": false
	})

	_arm_continue_known_destination_prewarm_service()


func _arm_continue_known_destination_prewarm_service() -> void:
	if (
		continue_known_destination_prewarm_service_active
		or continue_known_destination_prewarm_queue.is_empty()
	):
		return

	var tree:= Engine.get_main_loop() as SceneTree

	if tree == null:
		return

	continue_known_destination_prewarm_service_active = true

	var timer:= tree.create_timer(
		0.002,
		true,
		false,
		true
	)

	timer.timeout.connect(
		Callable(
			self,
			"_service_continue_known_destination_prewarm_quantum"
		),
		CONNECT_ONE_SHOT
	)


func _service_continue_known_destination_prewarm_quantum() -> void:
	continue_known_destination_prewarm_service_active = false

	if (
		continue_known_destination_prewarm_queue.is_empty()
		or gs == null
	):
		return

	_bind_continue_lineage_destination_publication()

	var row: Dictionary = (
		continue_known_destination_prewarm_queue [
			0
		]
	)

	var dead_player_id: int = int(
		row.get(
			"dead_player_id",
			-1
		)
	)

	var dead_key: String = str(
		dead_player_id
	)

	var dead_player: Person = (
		gs.get_or_reactivate_npc_by_id(
			dead_player_id
		)
	)

	if (
		dead_player == null
		or not gs.afterlife_active
	):
		continue_known_destination_prewarm_queue.pop_front()
		continue_known_destination_prewarm_keys.erase(
			dead_key
		)

		_arm_continue_known_destination_prewarm_service()
		return

	var contracts_raw: Variant = (
		row.get(
			"candidate_contracts",
			[]
		)
	)

	var contracts: Array = (
		contracts_raw as Array
		if typeof(
			contracts_raw
		) == TYPE_ARRAY
		else []
	)

	if not bool(
		row.get(
			"contracts_authored",
			false
		)
	):
		if (
			gs.relationships_hub_contract_engine != null
			and gs.relationships_hub_contract_engine.has_method(
				"continuation_known_person_contracts"
			)
		):
			contracts = (
				gs.relationships_hub_contract_engine
				.continuation_known_person_contracts(
					dead_player
				)
			)

		row [
			"candidate_contracts"
		] = contracts
		row [
			"contracts_authored"
		] = true

		gs.afterlife_state [
			"continue_known_person_candidate_contracts"
		] = contracts.duplicate(
			true
		)

		continue_known_destination_prewarm_queue [
			0
		] = row

		_arm_continue_known_destination_prewarm_service()
		return

	var candidate_index: int = int(
		row.get(
			"candidate_index",
			0
		)
	)

	if candidate_index >= contracts.size():
		continue_known_destination_prewarm_queue.pop_front()
		continue_known_destination_prewarm_keys.erase(
			dead_key
		)

		gs.afterlife_state [
			"continue_known_destination_prewarm_pending"
		] = false
		gs.afterlife_state [
			"continue_known_destination_prewarm_complete"
		] = true

		_arm_continue_known_destination_prewarm_service()
		return

	var contract: Dictionary = {}

	var contract_raw: Variant = (
		contracts [
			candidate_index
		]
	)

	if typeof(
		contract_raw
	) == TYPE_DICTIONARY:
		contract = (
			contract_raw as Dictionary
		)

	var target_id: int = int(
		contract.get(
			"target_id",
			-1
		)
	)

	if target_id > 0:
		var target: Person = (
			gs.get_or_reactivate_npc_by_id(
				target_id
			)
		)

		if (
			target != null
			and target.alive
			and float(
				target.health
			) > 0.0
		):
			_queue_continuation_destination_if_needed(
				dead_player,
				target
			)

	row [
		"candidate_index"
	] = candidate_index + 1

	continue_known_destination_prewarm_queue [
		0
	] = row

	_arm_continue_known_destination_prewarm_service()
func _transfer_player_estate_to_descendant(
	dead_player: Person,
	heir: Person
) -> void:
	if dead_player == null or heir == null:
		return

	heir.bank_balance = float(
		heir.bank_balance
	) + float(
		dead_player.bank_balance
	)

	dead_player.bank_balance = 0.0




	var heirloom_transfer_report: Dictionary = {}

	if gs.heirloom_contract_engine != null:
		heirloom_transfer_report = (
			gs.heirloom_contract_engine.resolve_intent(
				dead_player,
				{
					"action_id": "transfer_estate",
					"target_id": int(
						heir.id
					),
					"transfer_mode": "inheritance",
					"source": (
						"afterlife_influence_engine"
						+ ".estate_transfer"
					),
					"deceased_owner_id": int(
						dead_player.id
					),
					"heir_id": int(
						heir.id
					)
				}
			)
		)

	if gs.belongings_engine != null:


		_transfer_owner_bucket(
			gs.belongings_engine.belongings,
			dead_player.id,
			heir.id
		)


	if (
		not bool(
			heirloom_transfer_report.get(
				"success",
				false
			)
		)
		and gs.heirloom_engine != null
	):
		_transfer_owner_bucket(
			gs.heirloom_engine.heirlooms,
			dead_player.id,
			heir.id
		)

	if gs.property_engine != null:
		_transfer_owner_bucket(
			gs.property_engine.properties,
			dead_player.id,
			heir.id
		)

	if gs.vehicle_engine != null:
		_transfer_owner_bucket(
			gs.vehicle_engine.vehicles,
			dead_player.id,
			heir.id
		)

	if gs.artifacts_engine != null:
		_transfer_owner_bucket(
			gs.artifacts_engine.ownership,
			dead_player.id,
			heir.id
		)

	if gs.dragonballs_engine != null:
		_transfer_owner_bucket(
			gs.dragonballs_engine.ownership,
			dead_player.id,
			heir.id
		)

	if (
		gs.red_bonnet_engine != null
		and int(
			gs.red_bonnet_engine.owner_id
		) == int(
			dead_player.id
		)
	):
		gs.red_bonnet_engine.owner_id = heir.id

	if (
		gs.many_realms_engine != null
		and int(
			gs.many_realms_engine.ring_owner_id
		) == int(
			dead_player.id
		)
	):
		gs.many_realms_engine.ring_owner_id = heir.id
		dead_player.has_many_realms_ring = false
		heir.has_many_realms_ring = true
		heir.hidden_realm_visible = (
			dead_player.hidden_realm_visible
		)
		heir.hidden_realm_title = (
			dead_player.hidden_realm_title
		)
		dead_player.hidden_realm_visible = false
		dead_player.hidden_realm_title = ""

	if typeof(
		gs.scenario_state
	) == TYPE_DICTIONARY:
		gs.scenario_state [
			"last_heirloom_estate_transfer_report"
		] = heirloom_transfer_report.duplicate(true)


func _transfer_owner_bucket(bucket: Dictionary, from_id: int, to_id: int) -> void:
	if typeof(bucket) != TYPE_DICTIONARY:
		return
	if not bucket.has(from_id):
		return

	var moved_value = bucket [from_id]

	if bucket.has(to_id) and typeof(bucket [to_id]) == TYPE_ARRAY and typeof(moved_value) == TYPE_ARRAY:
		var combined: Array = bucket [to_id].duplicate()
		for item in moved_value:
			combined.append(item)
		bucket [to_id] = combined
	else:
		bucket [to_id] = moved_value

	bucket.erase(from_id)


func _dead_to_descendant_relationship_label(dead_id: int, descendant_id: int) -> String:
	if dead_id <= 0 or descendant_id <= 0:
		return "relative"
	var frontier: Array = [descendant_id]
	var seen: Dictionary = {}
	var depth: int = 0
	while depth < 8 and frontier.size() > 0:
		var next_frontier: Array = []
		for current_id in frontier:
			var facts: Dictionary = gs.get_npc_facts_by_id(int(current_id))
			if facts.is_empty():
				continue
			var parent_ids_raw = facts.get("parents", [])
			if typeof(parent_ids_raw) != TYPE_ARRAY:
				continue
			for parent_id_raw in parent_ids_raw:
				var parent_id: int = int(parent_id_raw)
				if parent_id <= 0:
					continue
				if parent_id == dead_id:
					match depth + 1:
						1:
							return "child"
						2:
							return "grandchild"
						3:
							return "great-grandchild"
						4:
							return "great-great-grandchild"
						_:
							return "descendant"
				if seen.has(parent_id):
					continue
				seen [parent_id] = true
				next_frontier.append(parent_id)
		frontier = next_frontier
		depth += 1
	return "relative"


func _clear_pending_choice() -> void:
	gs.afterlife_state ["pending_mode"] = ""
	gs.afterlife_state ["pending_type"] = ""
	gs.afterlife_state ["pending_text"] = ""
	gs.afterlife_state ["pending_lookup"] = {}
	gs.afterlife_state ["pending_options"] = []





func build_anchor_selection_result(player: Person) -> Dictionary:
	if player == null:
		return {
			"type": "no_descendants",
			"options": ["random_life", "custom_life", "rewind_one_year"]
		}

	if not gs.afterlife_active:
		enter_afterlife_for_player(player)

	var candidates: Array = _collect_living_descendant_candidates(int(player.id))
	if candidates.is_empty():
		gs.afterlife_active = false
		return {
			"type": "no_descendants",
			"options": ["random_life", "custom_life", "rewind_one_year"]
		}

	var options: Array = []
	var lookup: Dictionary = {}

	for descendant in candidates:
		if descendant == null:
			continue

		var label: String = "Follow %s %s (age %d, %s)" % [
			descendant.first_name,
			descendant.last_name,
			int(descendant.age),
			str(descendant.social_class)
		]
		options.append(label)
		lookup [label] = {
			"descendant_id": int(descendant.id)
		}

	gs.afterlife_state ["pending_mode"] = "anchor"
	gs.afterlife_state ["pending_type"] = "afterlife_anchor_selection"
	gs.afterlife_state ["pending_text"] = "Choose the descendant you want to follow through the afterlife."
	gs.afterlife_state ["pending_lookup"] = lookup
	gs.afterlife_state ["pending_options"] = options
	gs.afterlife_state ["death_popup_open"] = false
	gs.afterlife_state ["overlay_open"] = true

	return get_pending_choice_result()





func prepare_pre_year_intervention() -> Dictionary:
	if not gs.afterlife_active:
		return {}

	if has_pending_choice():
		return get_pending_choice_result()

	var anchor_id: int = int(gs.afterlife_state.get("anchored_descendant_id", -1))
	if anchor_id <= 0:
		return build_anchor_selection_result(gs.player)

	var anchor: Person = gs.get_or_reactivate_npc_by_id(anchor_id)
	if anchor == null or not anchor.alive:
		gs.afterlife_state ["anchored_descendant_id"] = -1
		return {
			"type": "afterlife_anchor_lost",
			"text": "Your anchor slipped out of mortal reach. Choose another descendant.",
			"opps": build_anchor_selection_result(gs.player).get("opps", [])
		}

	if bool(gs.afterlife_state.get("round_ready_to_advance", false)):
		return {
			"type": "afterlife_round_waiting_for_year_advance",
			"text": "That spiritual year is complete. Press Age Up to let the mortal year unfold.",
			"opps": []
		}

	var round_index: int = int(gs.afterlife_state.get("round_index", 0))
	if round_index <= 0:
		return _begin_afterlife_round(anchor, 1)

	return _queue_afterlife_scenario(anchor)


func _build_intervention_bundle(anchor: Person) -> Dictionary:
	var text: String = ""
	var options: Array = []
	var lookup: Dictionary = {}

	var focus: String = str(anchor.strategic_focus).to_lower()
	var low_mental: bool = float(anchor.mental_health) < 40.0
	var high_fame: bool = int(anchor.fame) >= 60
	var reckless: bool = (focus == "chaos" or focus == "power")

	if low_mental:
		text = "%s is internally fraying and could spiral this year. What do you breathe into their spirit?" % anchor.first_name

		_add_intervention_option(options, lookup,
			"Whisper calm, restraint, and patience",
			{
				"bias": {
					"motivation_delta": -2,
					"ambition_delta": -1,
					"impulse_weights": {
						"StartFight": -18.0,
						"CommitCrime": -20.0,
						"SelfImprove": 14.0,
						"Train": 8.0
					},
					"goal_weights": {
						"ImproveSmarts": 14.0,
						"DisruptOrder": -18.0
					},
					"moral_resistance": 18.0,
					"legacy_pull": 8.0
				},
				"imprint_deltas": {
					"moral_caution": 2.0,
					"emotional_volatility": -1.0,
					"spiritual_sensitivity": 1.0
				}
			}
		)

		_add_intervention_option(options, lookup,
			"Press compassion and family memory into them",
			{
				"bias": {
					"motivation_delta": 1,
					"ambition_delta": 0,
					"impulse_weights": {
						"ConfessLove": 8.0,
						"SelfImprove": 12.0,
						"CommitCrime": -14.0
					},
					"goal_weights": {
						"FindPartner": 10.0,
						"HaveChild": 10.0,
						"DisruptOrder": -12.0
					},
					"moral_resistance": 10.0,
					"legacy_pull": 18.0
				},
				"imprint_deltas": {
					"reverence_for_legacy": 2.0,
					"spiritual_sensitivity": 1.0
				}
			}
		)

		_add_intervention_option(options, lookup,
			"Sharpen their suffering into disciplined growth",
			{
				"bias": {
					"motivation_delta": 4,
					"ambition_delta": 2,
					"impulse_weights": {
						"Train": 14.0,
						"SelfImprove": 16.0,
						"QuitJob": -8.0
					},
					"goal_weights": {
						"ImproveSmarts": 12.0,
						"IncreaseNetWorth": 8.0
					},
					"moral_resistance": 8.0,
					"legacy_pull": 10.0
				},
				"imprint_deltas": {
					"family_discipline": 2.0,
					"moral_caution": 1.0
				}
			}
		)

		return {
			"text": text,
			"options": options,
			"lookup": lookup
		}

	if reckless:
		text = "%s is circling a reckless decision and calling it destiny. How do you intervene?" % anchor.first_name

		_add_intervention_option(options, lookup,
			"Whisper discipline and long memory",
			{
				"bias": {
					"motivation_delta": 2,
					"ambition_delta": -1,
					"impulse_weights": {
						"CommitCrime": -24.0,
						"StartFight": -18.0,
						"SelfImprove": 12.0,
						"Train": 10.0
					},
					"goal_weights": {
						"DisruptOrder": -20.0,
						"ImproveSmarts": 10.0,
						"HaveChild": 6.0
					},
					"moral_resistance": 18.0,
					"legacy_pull": 16.0
				},
				"imprint_deltas": {
					"family_discipline": 3.0,
					"moral_caution": 2.0
				}
			}
		)

		_add_intervention_option(options, lookup,
			"Stir fear of shame, prison, and consequence",
			{
				"bias": {
					"motivation_delta": -1,
					"ambition_delta": -2,
					"impulse_weights": {
						"CommitCrime": -26.0,
						"StartFight": -12.0,
						"QuitJob": -8.0
					},
					"goal_weights": {
						"DisruptOrder": -24.0,
						"IncreaseNetWorth": 6.0
					},
					"moral_resistance": 22.0,
					"legacy_pull": 8.0,
					"reputation_sensitivity": 20.0
				},
				"imprint_deltas": {
					"moral_caution": 3.0,
					"criminal_attraction": -2.0
				}
			}
		)

		_add_intervention_option(options, lookup,
			"Redirect ambition into power without destruction",
			{
				"bias": {
					"motivation_delta": 3,
					"ambition_delta": 3,
					"impulse_weights": {
						"CommitCrime": -10.0,
						"Train": 8.0,
						"SelfImprove": 10.0
					},
					"goal_weights": {
						"GainPoliticalInfluence": 14.0,
						"IncreaseNetWorth": 10.0,
						"DisruptOrder": -12.0
					},
					"moral_resistance": 8.0,
					"legacy_pull": 8.0
				},
				"imprint_deltas": {
					"reckless_ambition": -1.0,
					"family_discipline": 1.0
				}
			}
		)

		return {
			"text": text,
			"options": options,
			"lookup": lookup
		}

	if high_fame:
		text = "%s can feel attention bending around them this year. What do you press into their legacy?" % anchor.first_name

		_add_intervention_option(options, lookup,
			"Whisper humility before the spotlight hardens them",
			{
				"bias": {
					"motivation_delta": 0,
					"ambition_delta": -1,
					"impulse_weights": {
						"BuySomething": -12.0,
						"SelfImprove": 10.0
					},
					"goal_weights": {
						"BecomeFamous": -8.0,
						"HaveChild": 8.0,
						"ImproveSmarts": 10.0
					},
					"legacy_pull": 18.0,
					"moral_resistance": 8.0
				},
				"imprint_deltas": {
					"reverence_for_legacy": 2.0,
					"spiritual_sensitivity": 1.0
				}
			}
		)

		_add_intervention_option(options, lookup,
			"Make them hungry for greatness but careful with their name",
			{
				"bias": {
					"motivation_delta": 3,
					"ambition_delta": 3,
					"impulse_weights": {
						"SelfImprove": 12.0,
						"Train": 12.0,
						"CommitCrime": -12.0
					},
					"goal_weights": {
						"BecomeFamous": 10.0,
						"ImproveSmarts": 8.0,
						"DisruptOrder": -12.0
					},
					"reputation_sensitivity": 16.0,
					"legacy_pull": 10.0
				},
				"imprint_deltas": {
					"family_discipline": 1.0,
					"reverence_for_legacy": 1.0
				}
			}
		)

		_add_intervention_option(options, lookup,
			"Pull their eyes back toward family instead of applause",
			{
				"bias": {
					"motivation_delta": 1,
					"ambition_delta": -1,
					"impulse_weights": {
						"ConfessLove": 10.0,
						"SelfImprove": 8.0
					},
					"goal_weights": {
						"FindPartner": 10.0,
						"HaveChild": 12.0,
						"BecomeFamous": -10.0
					},
					"legacy_pull": 20.0,
					"moral_resistance": 6.0
				},
				"imprint_deltas": {
					"reverence_for_legacy": 3.0
				}
			}
		)

		return {
			"text": text,
			"options": options,
			"lookup": lookup
		}

	text = "%s is moving toward another ordinary-looking year that could still define the bloodline. What do you whisper?" % anchor.first_name

	_add_intervention_option(options, lookup,
		"Whisper discipline and structure",
		{
			"bias": {
				"motivation_delta": 2,
				"ambition_delta": 1,
				"impulse_weights": {
					"Train": 12.0,
					"SelfImprove": 14.0,
					"CommitCrime": -10.0
				},
				"goal_weights": {
					"ImproveSmarts": 10.0,
					"IncreaseNetWorth": 6.0
				},
				"legacy_pull": 10.0,
				"moral_resistance": 10.0
			},
			"imprint_deltas": {
				"family_discipline": 2.0
			}
		}
	)

	_add_intervention_option(options, lookup,
		"Whisper legacy and responsibility",
		{
			"bias": {
				"motivation_delta": 1,
				"ambition_delta": 0,
				"impulse_weights": {
					"SelfImprove": 10.0,
					"ConfessLove": 8.0
				},
				"goal_weights": {
					"HaveChild": 12.0,
					"FindPartner": 10.0,
					"DisruptOrder": -8.0
				},
				"legacy_pull": 18.0,
				"moral_resistance": 8.0
			},
			"imprint_deltas": {
				"reverence_for_legacy": 2.0
			}
		}
	)

	_add_intervention_option(options, lookup,
		"Whisper caution against chaos",
		{
			"bias": {
				"motivation_delta": -1,
				"ambition_delta": -1,
				"impulse_weights": {
					"CommitCrime": -16.0,
					"StartFight": -12.0,
					"SelfImprove": 8.0
				},
				"goal_weights": {
					"DisruptOrder": -16.0,
					"ImproveSmarts": 6.0
				},
				"legacy_pull": 8.0,
				"moral_resistance": 16.0
			},
			"imprint_deltas": {
				"moral_caution": 2.0,
				"criminal_attraction": -1.0
			}
		}
	)

	return {
		"text": text,
		"options": options,
		"lookup": lookup
	}


func _add_intervention_option(options: Array, lookup: Dictionary, label: String, payload: Dictionary) -> void:
	options.append(label)
	lookup [label] = payload.duplicate(true)





func apply_committed_bias_for_year() -> void:
	var selected_raw = gs.afterlife_state.get("selected_interventions", [])
	if typeof(selected_raw) != TYPE_ARRAY or selected_raw.is_empty():
		return

	var anchor_id: int = int(gs.afterlife_state.get("anchored_descendant_id", -1))
	if anchor_id <= 0:
		return

	var final_bias: Dictionary = {
		"motivation_delta": 0,
		"ambition_delta": 0,
		"moral_resistance": 0.0,
		"legacy_pull": 0.0,
		"reputation_sensitivity": 0.0,
		"impulse_weights": {},
		"goal_weights": {}
	}

	for selection in selected_raw:
		if typeof(selection) != TYPE_DICTIONARY:
			continue

		var bias_raw = selection.get("bias", {})
		if typeof(bias_raw) != TYPE_DICTIONARY:
			continue

		final_bias ["motivation_delta"] = int(final_bias.get("motivation_delta", 0)) + int(bias_raw.get("motivation_delta", 0))
		final_bias ["ambition_delta"] = int(final_bias.get("ambition_delta", 0)) + int(bias_raw.get("ambition_delta", 0))
		final_bias ["moral_resistance"] = float(final_bias.get("moral_resistance", 0.0)) + float(bias_raw.get("moral_resistance", 0.0))
		final_bias ["legacy_pull"] = float(final_bias.get("legacy_pull", 0.0)) + float(bias_raw.get("legacy_pull", 0.0))
		final_bias ["reputation_sensitivity"] = float(final_bias.get("reputation_sensitivity", 0.0)) + float(bias_raw.get("reputation_sensitivity", 0.0))

		_merge_weight_dict(final_bias ["impulse_weights"], bias_raw.get("impulse_weights", {}))
		_merge_weight_dict(final_bias ["goal_weights"], bias_raw.get("goal_weights", {}))

		_apply_lineage_imprint_from_selection(selection)

	final_bias ["lineage_key"] = str(gs.afterlife_state.get("lineage_key", ""))
	final_bias ["ghost_player_id"] = int(gs.afterlife_state.get("ghost_player_id", -1))

	gs.transient_afterlife_biases [anchor_id] = final_bias


func resolve_post_year_result() -> Dictionary:
	var anchor_id: int = int(gs.afterlife_state.get("anchored_descendant_id", -1))
	var anchor: Person = gs.get_or_reactivate_npc_by_id(anchor_id)

	if anchor == null or not anchor.alive:
		gs.transient_afterlife_biases.clear()
		gs.afterlife_state ["selected_intervention"] = {}
		gs.afterlife_state ["selected_interventions"] = []
		gs.afterlife_state ["anchored_descendant_id"] = -1
		return {
			"type": "afterlife_anchor_lost",
			"text": "Your anchor is no longer among the living. Choose another descendant.",
			"opps": build_anchor_selection_result(gs.player).get("opps", [])
		}

	var lineage_key: String = str(gs.afterlife_state.get("lineage_key", ""))
	var profile: Dictionary = gs.lineage_influence_profiles.get(lineage_key, {})
	var spiritual: float = float(profile.get("spiritual_sensitivity", 0.0))
	var discipline: float = float(profile.get("family_discipline", 0.0))
	var resistance: float = float(profile.get("stubborn_resistance_to_control", 0.0))
	var caution: float = float(profile.get("moral_caution", 0.0))
	var round_score: float = float(gs.afterlife_state.get("round_score", 0.0))
	var round_index: int = int(gs.afterlife_state.get("round_index", 1))
	var total_rounds: int = int(gs.afterlife_state.get("total_rounds", 3))

	var heard_score: float = 0.38 + (round_score * 0.08) + (spiritual * 0.02) + (discipline * 0.015) + (caution * 0.01) - (resistance * 0.02)
	heard_score = clamp(heard_score, 0.08, 0.95)

	var roll: float = randf()
	var text: String = ""
	var progress_gain: float = 0.0

	if roll <= heard_score * 0.6:
		text = "%s really bent this year. Something in your pressure reached them cleanly." % anchor.first_name
		progress_gain = 1.5 + max(round_score, 0.0) * 0.15
	elif roll <= heard_score:
		text = "%s heard you, but unevenly. Some of the good landed. Some of it twisted on impact." % anchor.first_name
		progress_gain = 0.8 + max(round_score, 0.0) * 0.08
	elif roll <= heard_score + 0.15:
		text = "%s resisted you more than they obeyed you. The bloodline felt the pressure, but it did not fully yield." % anchor.first_name
		progress_gain = max(0.1, round_score * 0.04)
	else:
		text = "%s moved almost entirely under their own appetite this year." % anchor.first_name
		progress_gain = 0.0

	gs.afterlife_state ["reincarnation_progress"] = float(gs.afterlife_state.get("reincarnation_progress", 0.0)) + progress_gain
	gs.afterlife_state ["last_resolution"] = {
		"anchor_id": anchor_id,
		"text": text,
		"progress_gain": progress_gain,
		"round_score": round_score
	}

	var summary_text:= "%s\n\nMortal Year Result:\nInfluence score: %.1f\nReincarnation progress gained: +%.2f" % [
		text,
		round_score,
		progress_gain
	]

	gs.transient_afterlife_biases.clear()
	gs.afterlife_state ["selected_intervention"] = {}
	gs.afterlife_state ["selected_interventions"] = []
	gs.afterlife_state ["round_scenarios"] = []
	gs.afterlife_state ["round_results"] = []
	gs.afterlife_state ["scenario_index"] = 0

	if round_index >= total_rounds:
		return _finalize_reincarnation_outcome(anchor, summary_text)
	return _begin_afterlife_round(anchor, round_index + 1, "%s\n\nThe next spiritual year opens." % summary_text)
func _merge_weight_dict(target: Dictionary, source) -> void:
	if typeof(source) != TYPE_DICTIONARY:
		return

	for key in source.keys():
		var k: String = str(key)
		target [k] = float(target.get(k, 0.0)) + float(source.get(k, 0.0))


func _make_afterlife_scenario(text: String, option_defs: Array) -> Dictionary:
	var options: Array = []
	var lookup: Dictionary = {}

	for entry in option_defs:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var label: String = str(entry.get("label", "")).strip_edges()
		if label == "":
			continue

		options.append(label)
		var payload: Dictionary = entry.duplicate(true)
		payload.erase("label")
		lookup [label] = payload

	return {
		"text": text,
		"options": options,
		"lookup": lookup
	}


func _build_round_scenarios(anchor: Person, _round_number: int) -> Array:
	var out: Array = []
	var name: String = anchor.first_name
	var fame_hint: String = "publicly" if int(anchor.fame) >= 60 else "quietly"
	var school_hint: String = "school or training" if str(anchor.school_status) == "active" else "work or survival"

	out.append(_make_afterlife_scenario(
		"%s is close to doing something reckless %s this year. Which whisper reaches them?" % [name, fame_hint],
		[
			{
				"label": "Whisper restraint, conscience, and family honor",
				"response": "%s hesitates. The uglier path cools off. They do not become perfect, but they pull back." % name,
				"score_delta": 2.0,
				"good_karma_delta": 2.0,
				"bad_karma_delta": 0.0,
				"bias": {
					"motivation_delta": 1,
					"ambition_delta": -1,
					"impulse_weights": {
						"CommitCrime": -22.0,
						"StartFight": -16.0,
						"SelfImprove": 12.0,
						"Train": 8.0
					},
					"goal_weights": {
						"ImproveSmarts": 10.0,
						"DisruptOrder": -18.0
					},
					"moral_resistance": 18.0,
					"legacy_pull": 14.0
				},
				"imprint_deltas": {
					"family_discipline": 2.0,
					"moral_caution": 2.0,
					"reverence_for_legacy": 1.0
				}
			},
			{
				"label": "Inflame pride, dominance, and appetite",
				"response": "%s hardens. They feel more justified than corrected, and that energy turns dangerous fast." % name,
				"score_delta": -2.5,
				"good_karma_delta": 0.0,
				"bad_karma_delta": 2.5,
				"bias": {
					"motivation_delta": 3,
					"ambition_delta": 3,
					"impulse_weights": {
						"CommitCrime": 20.0,
						"StartFight": 18.0
					},
					"goal_weights": {
						"DisruptOrder": 18.0
					}
				},
				"imprint_deltas": {
					"reckless_ambition": 2.0,
					"criminal_attraction": 2.0,
					"emotional_volatility": 1.0
				}
			},
			{
				"label": "Stay silent and let free will swing on its own",
				"response": "%s feels nothing clear from beyond. Their own impulses take the lead." % name,
				"score_delta": -0.5,
				"good_karma_delta": 0.0,
				"bad_karma_delta": 0.5,
				"bias": {},
				"imprint_deltas": {}
			}
		]
	))

	out.append(_make_afterlife_scenario(
		"%s stands at a family crossroads. Their next move could heal the line or bruise it again. How do you lean on them?" % name,
		[
			{
				"label": "Push compassion, forgiveness, and protection of family",
				"response": "%s softens enough to choose connection over ego. The family line breathes easier." % name,
				"score_delta": 2.0,
				"good_karma_delta": 2.0,
				"bad_karma_delta": 0.0,
				"bias": {
					"motivation_delta": 1,
					"ambition_delta": 0,
					"impulse_weights": {
						"ConfessLove": 10.0,
						"SelfImprove": 8.0,
						"CommitCrime": -10.0
					},
					"goal_weights": {
						"FindPartner": 12.0,
						"HaveChild": 12.0
					},
					"legacy_pull": 18.0
				},
				"imprint_deltas": {
					"spiritual_sensitivity": 1.0,
					"reverence_for_legacy": 2.0
				}
			},
			{
				"label": "Teach them to cut people off and answer hurt with hurt",
				"response": "%s becomes sharper, colder, and more destructive in the name of self-protection." % name,
				"score_delta": -2.0,
				"good_karma_delta": 0.0,
				"bad_karma_delta": 2.0,
				"bias": {
					"motivation_delta": 2,
					"ambition_delta": 1,
					"impulse_weights": {
						"StartFight": 14.0,
						"CommitCrime": 8.0
					},
					"goal_weights": {
						"DisruptOrder": 12.0
					}
				},
				"imprint_deltas": {
					"emotional_volatility": 2.0,
					"stubborn_resistance_to_control": 1.0
				}
			},
			{
				"label": "Keep them emotionally numb and spiritually distant",
				"response": "%s goes emotionally flat. Nothing explodes, but nothing heals either." % name,
				"score_delta": -0.5,
				"good_karma_delta": 0.0,
				"bad_karma_delta": 0.5,
				"bias": {
					"motivation_delta": -1
				},
				"imprint_deltas": {
					"spiritual_sensitivity": -1.0
				}
			}
		]
	))

	out.append(_make_afterlife_scenario(
		"%s is choosing where to pour their energy into %s. What do you press into their spirit?" % [name, school_hint],
		[
			{
				"label": "Sharpen them toward discipline, growth, and earned stability",
				"response": "%s redirects energy into effort. The year gets more structured and less self-destructive." % name,
				"score_delta": 2.0,
				"good_karma_delta": 2.0,
				"bad_karma_delta": 0.0,
				"bias": {
					"motivation_delta": 3,
					"ambition_delta": 1,
					"impulse_weights": {
						"Train": 16.0,
						"SelfImprove": 18.0,
						"QuitJob": -10.0
					},
					"goal_weights": {
						"ImproveSmarts": 14.0,
						"IncreaseNetWorth": 8.0
					},
					"moral_resistance": 8.0
				},
				"imprint_deltas": {
					"family_discipline": 2.0,
					"moral_caution": 1.0
				}
			},
			{
				"label": "Tell them shortcuts matter more than character",
				"response": "%s starts chasing speed over integrity. It works fast, and it stains fast too." % name,
				"score_delta": -2.0,
				"good_karma_delta": 0.0,
				"bad_karma_delta": 2.0,
				"bias": {
					"motivation_delta": 2,
					"ambition_delta": 3,
					"impulse_weights": {
						"CommitCrime": 12.0,
						"SlackOff": 10.0
					},
					"goal_weights": {
						"IncreaseNetWorth": 12.0,
						"DisruptOrder": 8.0
					}
				},
				"imprint_deltas": {
					"reckless_ambition": 2.0,
					"moral_caution": -1.0
				}
			},
			{
				"label": "Push them to drift and waste the year",
				"response": "%s does not crash, but the year leaks away from them." % name,
				"score_delta": -1.0,
				"good_karma_delta": 0.0,
				"bad_karma_delta": 1.0,
				"bias": {
					"motivation_delta": -3
				},
				"imprint_deltas": {
					"family_discipline": -1.0
				}
			}
		]
	))

	return out


func _build_afterlife_round_summary(_anchor: Person) -> String:
	var round_number: int = int(gs.afterlife_state.get("round_index", 1))
	var total_rounds: int = int(gs.afterlife_state.get("total_rounds", 3))
	var round_score: float = float(gs.afterlife_state.get("round_score", 0.0))
	var grade: String = "mixed"

	if round_score >= 4.0:
		grade = "strongly righteous"
	elif round_score >= 1.5:
		grade = "more good than bad"
	elif round_score <= -4.0:
		grade = "heavily corrupting"
	elif round_score < 0.0:
		grade = "dangerously uneven"

	return "Spiritual Year %d of %d is complete.\nYour influence this round was %s.\n\nPress Age Up to let the mortal year unfold and reveal how much of it they actually lived out." % [
		round_number,
		total_rounds,
		grade
	]


func _queue_afterlife_scenario(anchor: Person, preface_lines: Array = []) -> Dictionary:
	var scenarios_raw = gs.afterlife_state.get("round_scenarios", [])
	if typeof(scenarios_raw) != TYPE_ARRAY or scenarios_raw.is_empty():
		return {
			"type": "afterlife_round_missing",
			"text": "The next spiritual scenario bundle is missing.",
			"opps": []
		}

	var scenario_index: int = int(gs.afterlife_state.get("scenario_index", 0))
	if scenario_index >= scenarios_raw.size():
		gs.afterlife_state ["pending_mode"] = ""
		gs.afterlife_state ["pending_type"] = "afterlife_round_complete"
		gs.afterlife_state ["pending_text"] = _build_afterlife_round_summary(anchor)
		gs.afterlife_state ["pending_lookup"] = {}
		gs.afterlife_state ["pending_options"] = []
		gs.afterlife_state ["round_ready_to_advance"] = true
		return get_pending_choice_result()

	var scenario: Dictionary = scenarios_raw [scenario_index]
	var text_lines: Array = []

	for line in preface_lines:
		var clean_line: String = str(line).strip_edges()
		if clean_line != "":
			text_lines.append(clean_line)

	if not text_lines.is_empty():
		text_lines.append("")

	text_lines.append("Scenario %d of %d" % [
		scenario_index + 1,
		int(gs.afterlife_state.get("scenarios_per_round", 3))
	])
	text_lines.append(str(scenario.get("text", "A descendant stands at a crossroads.")))

	gs.afterlife_state ["pending_mode"] = "scenario"
	gs.afterlife_state ["pending_type"] = "afterlife_scenario_prompt"
	gs.afterlife_state ["pending_text"] = "\n\n".join(text_lines)
	gs.afterlife_state ["pending_lookup"] = scenario.get("lookup", {})
	gs.afterlife_state ["pending_options"] = scenario.get("options", [])

	return get_pending_choice_result()


func _begin_afterlife_round(anchor: Person, round_number: int, preface_text: String = "") -> Dictionary:
	gs.afterlife_state ["round_index"] = round_number
	gs.afterlife_state ["scenario_index"] = 0
	gs.afterlife_state ["round_scenarios"] = _build_round_scenarios(anchor, round_number)
	gs.afterlife_state ["round_results"] = []
	gs.afterlife_state ["round_score"] = 0.0
	gs.afterlife_state ["round_ready_to_advance"] = false
	gs.afterlife_state ["selected_interventions"] = []
	gs.afterlife_state ["selected_intervention"] = {}

	var preface_lines: Array = []
	if preface_text.strip_edges() != "":
		preface_lines.append(preface_text)

	preface_lines.append("Spiritual Year %d begins around %s." % [round_number, anchor.first_name])

	return _queue_afterlife_scenario(anchor, preface_lines)


func _build_reincarnation_slot_candidates(anchor: Person) -> Array:
	var out: Array = []
	var seen:= {}

	var append_maternal_slot = func (mother: Person, priority: int) -> void:
		if mother == null or not mother.alive or mother.age < 16:
			return
		if str(mother.gender) != "Female":
			return

		var mother_key: String = "mother:%d" % int(mother.id)
		if seen.has(mother_key):
			return
		seen [mother_key] = true

		var partner: Person = gs.get_valid_partner(mother, true)
		var slot: Dictionary = {
			"mother_id": int(mother.id),
			"parent1_id": int(mother.id),
			"label": "%s %s — age %d — you will be born as their child" % [
				mother.first_name,
				mother.last_name,
				int(mother.age)
			],
			"priority": priority
		}
		if partner != null and gs.can_create_child(mother, partner, true):
			slot ["father_id"] = int(partner.id)
			slot ["parent2_id"] = int(partner.id)
			slot ["label"] = "%s %s — age %d — you will be born as their child" % [
				mother.first_name,
				mother.last_name,
				int(mother.age)
			]

		out.append(slot)

	if anchor != null:
		if str(anchor.gender) == "Female":
			append_maternal_slot.call(anchor, 0)
		else:
			var anchor_partner: Person = gs.get_valid_partner(anchor, true)
			if anchor_partner != null and str(anchor_partner.gender) == "Female":
				append_maternal_slot.call(anchor_partner, 0)

	var touched: Array = _get_touched_bloodline_ids()
	for pid in touched:
		var carrier: Person = gs.get_or_reactivate_npc_by_id(int(pid))
		append_maternal_slot.call(carrier, 1)

	out.sort_custom(func (a, b): return int(a.get("priority", 999)) < int(b.get("priority", 999)))
	return out


func _apply_reincarnation_to_slot(slot: Dictionary, preface_text: String) -> Dictionary:
	var parent1: Person = gs.get_or_reactivate_npc_by_id(int(slot.get("parent1_id", -1)))
	var parent2: Person = gs.get_or_reactivate_npc_by_id(int(slot.get("parent2_id", -1)))

	if parent1 == null or parent2 == null:
		return {
			"type": "afterlife_lineage_ended",
			"text": "%s\n\nA valid birth slot slipped away before reincarnation could lock in." % preface_text,
			"opps": []
		}

	var child: Person = gs.spawn_child(parent1, parent2, true)
	if child == null:
		return {
			"type": "afterlife_lineage_ended",
			"text": "%s\n\nThe family line had no stable birth slot to return you through." % preface_text,
			"opps": []
		}

	child.memories.append("Something ancient seemed present at my birth.")
	if bool(gs.afterlife_state.get("generational_curse", false)):
		if "GenerationalCurse" not in child.traits:
			child.traits.append("GenerationalCurse")
		child.memories.append("A generational curse lingered over my beginning.")

	var ghost_name: String = str(gs.afterlife_state.get("ghost_name", "An old spirit"))
	gs.push_world_feed(
		"%s was reborn into the family line through %s." % [ghost_name, str(slot.get("label", "the bloodline"))],
		{
			"npc_id": child.id,
			"personally_relevant": true,
			"category": "afterlife",
			"event_name": "afterlife_reincarnation",
			"source": "afterlife_influence_engine"
		}
	)

	gs.afterlife_active = false
	gs.awaiting_new_life = false
	gs.transient_afterlife_biases.clear()
	gs.afterlife_state.clear()

	if gs.family_control_engine != null:
		gs.family_control_engine.switch_to_character(child)
	else:
		gs.player = child
		gs.player_id = child.id

	return {
		"type": "afterlife_reincarnated",
		"text": "%s\n\nYou were reincarnated into your family line as a newborn child of %s." % [
			preface_text,
			str(slot.get("label", "the bloodline"))
		],
		"opps": []
	}


func _finalize_reincarnation_outcome(anchor: Person, preface_text: String) -> Dictionary:
	var progress: float = float(gs.afterlife_state.get("reincarnation_progress", 0.0))
	var good: float = float(gs.afterlife_state.get("good_karma", 0.0))
	var bad: float = float(gs.afterlife_state.get("bad_karma", 0.0))

	if bad >= good + 4.0 and progress < 2.5:
		gs.afterlife_state ["pending_mode"] = "afterlife_exit_choice"
		gs.afterlife_state ["pending_type"] = "afterlife_exit_choice"
		gs.afterlife_state ["pending_text"] = "%s\n\nYou did too much harm in death. This family line does not receive you back." % preface_text
		gs.afterlife_state ["pending_lookup"] = {
			"Start Random Life": { "action": "random_life"},
			"Start Custom Life": { "action": "custom_life"}
		}
		gs.afterlife_state ["pending_options"] = ["Start Random Life", "Start Custom Life"]
		gs.afterlife_state ["overlay_open"] = true
		gs.afterlife_state ["death_popup_open"] = false
		return get_pending_choice_result()

	if bad > good:
		gs.afterlife_state ["generational_curse"] = true

	var slots: Array = _build_reincarnation_slot_candidates(anchor)
	gs.afterlife_state ["reincarnation_slot_candidates"] = slots
	if slots.is_empty():
		gs.afterlife_state ["pending_mode"] = "afterlife_exit_choice"
		gs.afterlife_state ["pending_type"] = "afterlife_exit_choice"
		gs.afterlife_state ["pending_text"] = "%s\n\nYou can’t reincarnate because there’s nobody in your family who can give birth." % preface_text
		gs.afterlife_state ["pending_lookup"] = {
			"Start Random Life": { "action": "random_life"},
			"Start Custom Life": { "action": "custom_life"}
		}
		gs.afterlife_state ["pending_options"] = ["Start Random Life", "Start Custom Life"]
		gs.afterlife_state ["overlay_open"] = true
		gs.afterlife_state ["death_popup_open"] = false
		return get_pending_choice_result()

	var options: Array = []
	var lookup: Dictionary = {}
	for slot in slots:
		if typeof(slot) != TYPE_DICTIONARY:
			continue
		var label: String = str(slot.get("label", "the bloodline"))
		options.append(label)
		lookup [label] = slot.duplicate(true)

	gs.afterlife_state ["pending_mode"] = "reincarnation_slot_pick"
	gs.afterlife_state ["pending_type"] = "afterlife_reincarnation_slot_pick"
	gs.afterlife_state ["pending_text"] = "%s\n\nYour spiritual years are complete.\nChoose the person you want to be born through." % preface_text
	gs.afterlife_state ["pending_lookup"] = lookup
	gs.afterlife_state ["pending_options"] = options
	gs.afterlife_state ["overlay_open"] = true
	gs.afterlife_state ["death_popup_open"] = false
	return get_pending_choice_result()




func get_transient_bias_for_npc(npc_id: int) -> Dictionary:
	if gs == null or npc_id <= 0:
		return {}

	var out: Dictionary = {}
	if gs.transient_afterlife_biases.has(npc_id):
		out = gs.transient_afterlife_biases [npc_id].duplicate(true)

	var touched: Array = _get_touched_bloodline_ids()
	if npc_id in touched:
		var lineage_key: String = str(gs.afterlife_state.get("lineage_key", ""))
		var profile: Dictionary = gs.lineage_influence_profiles.get(lineage_key, {})
		if not profile.is_empty():
			out ["lineage_profile"] = profile.duplicate(true)

	return out


func apply_year_opening_bias(npc: Person, bias: Dictionary) -> void:
	if npc == null or typeof(bias) != TYPE_DICTIONARY or bias.is_empty():
		return

	npc.motivation = clamp(int(npc.motivation) + int(bias.get("motivation_delta", 0)), 0, 100)
	npc.ambition = clamp(int(npc.ambition) + int(bias.get("ambition_delta", 0)), 0, 100)


func pick_biased_impulse(npc: Person, pool: Array) -> String:
	var bias: Dictionary = get_transient_bias_for_npc(int(npc.id))
	if bias.is_empty():
		return ""

	var weights: Dictionary = {}
	for item in pool:
		weights [str(item)] = 10.0

	var impulse_weights_raw = bias.get("impulse_weights", {})
	if typeof(impulse_weights_raw) == TYPE_DICTIONARY:
		for key in impulse_weights_raw.keys():
			weights [str(key)] = float(weights.get(str(key), 10.0)) + float(impulse_weights_raw [key])

	_apply_lineage_profile_to_impulse_weights(weights, bias.get("lineage_profile", {}))
	return _weighted_pick(weights, pool)


func pick_biased_goal(npc: Person, _core: String, default_goal: String) -> String:
	var bias: Dictionary = get_transient_bias_for_npc(int(npc.id))
	if bias.is_empty():
		return default_goal

	var goals: Array = [
		"GainPoliticalInfluence",
		"IncreaseNetWorth",
		"BecomeFamous",
		"FindPartner",
		"HaveChild",
		"ImproveSmarts",
		"TravelWorld",
		"DisruptOrder"
	]

	var weights: Dictionary = {}
	for g in goals:
		weights [g] = 8.0

	if default_goal != "":
		weights [default_goal] = float(weights.get(default_goal, 8.0)) + 4.0

	var goal_weights_raw = bias.get("goal_weights", {})
	if typeof(goal_weights_raw) == TYPE_DICTIONARY:
		for key in goal_weights_raw.keys():
			weights [str(key)] = float(weights.get(str(key), 8.0)) + float(goal_weights_raw [key])

	_apply_lineage_profile_to_goal_weights(weights, bias.get("lineage_profile", {}))
	return _weighted_pick(weights, goals)





func _apply_lineage_imprint_from_selection(selected: Dictionary) -> void:
	var lineage_key: String = str(gs.afterlife_state.get("lineage_key", ""))
	if lineage_key == "":
		return

	if not gs.lineage_influence_profiles.has(lineage_key):
		gs.lineage_influence_profiles [lineage_key] = {}

	var profile: Dictionary = gs.lineage_influence_profiles [lineage_key]
	var deltas_raw = selected.get("imprint_deltas", {})
	if typeof(deltas_raw) != TYPE_DICTIONARY:
		return

	for key in deltas_raw.keys():
		var current_value: float = float(profile.get(str(key), 0.0))
		current_value += float(deltas_raw [key])
		current_value = clamp(current_value, -25.0, 25.0)
		profile [str(key)] = current_value

	gs.lineage_influence_profiles [lineage_key] = profile


func _apply_lineage_profile_to_impulse_weights(weights: Dictionary, profile_raw) -> void:
	if typeof(profile_raw) != TYPE_DICTIONARY:
		return

	var profile: Dictionary = profile_raw

	weights ["Train"] = float(weights.get("Train", 10.0)) + float(profile.get("family_discipline", 0.0)) * 0.8
	weights ["SelfImprove"] = float(weights.get("SelfImprove", 10.0)) + float(profile.get("family_discipline", 0.0)) * 0.9
	weights ["CommitCrime"] = float(weights.get("CommitCrime", 10.0)) - float(profile.get("moral_caution", 0.0)) * 1.0
	weights ["StartFight"] = float(weights.get("StartFight", 10.0)) - float(profile.get("moral_caution", 0.0)) * 0.7
	weights ["CommitCrime"] = float(weights.get("CommitCrime", 10.0)) + float(profile.get("criminal_attraction", 0.0)) * 1.1
	weights ["QuitJob"] = float(weights.get("QuitJob", 10.0)) + float(profile.get("reckless_ambition", 0.0)) * 0.8
	weights ["BuySomething"] = float(weights.get("BuySomething", 10.0)) + float(profile.get("reckless_ambition", 0.0)) * 0.6
	weights ["SelfImprove"] = float(weights.get("SelfImprove", 10.0)) + float(profile.get("spiritual_sensitivity", 0.0)) * 0.4
	weights ["ConfessLove"] = float(weights.get("ConfessLove", 10.0)) + float(profile.get("reverence_for_legacy", 0.0)) * 0.4


func _apply_lineage_profile_to_goal_weights(weights: Dictionary, profile_raw) -> void:
	if typeof(profile_raw) != TYPE_DICTIONARY:
		return

	var profile: Dictionary = profile_raw

	weights ["ImproveSmarts"] = float(weights.get("ImproveSmarts", 8.0)) + float(profile.get("family_discipline", 0.0)) * 0.7
	weights ["HaveChild"] = float(weights.get("HaveChild", 8.0)) + float(profile.get("reverence_for_legacy", 0.0)) * 0.9
	weights ["FindPartner"] = float(weights.get("FindPartner", 8.0)) + float(profile.get("reverence_for_legacy", 0.0)) * 0.6
	weights ["DisruptOrder"] = float(weights.get("DisruptOrder", 8.0)) + float(profile.get("criminal_attraction", 0.0)) * 1.0
	weights ["DisruptOrder"] = float(weights.get("DisruptOrder", 8.0)) - float(profile.get("moral_caution", 0.0)) * 1.0
	weights ["GainPoliticalInfluence"] = float(weights.get("GainPoliticalInfluence", 8.0)) + float(profile.get("reckless_ambition", 0.0)) * 0.6
	weights ["IncreaseNetWorth"] = float(weights.get("IncreaseNetWorth", 8.0)) + float(profile.get("reckless_ambition", 0.0)) * 0.5





func _resolve_person(arg) -> Person:
	if arg is Person:
		return arg

	if typeof(arg) == TYPE_INT:
		return gs.get_or_reactivate_npc_by_id(int(arg))

	if typeof(arg) == TYPE_DICTIONARY:
		var npc_id: int = int(arg.get("npc_id", -1))
		if npc_id > 0:
			return gs.get_or_reactivate_npc_by_id(npc_id)

	return null


func _collect_descendant_ids(root_id: int) -> Array:
	var out: Array = []
	if (
		root_id <= 0
		or gs == null
	):
		return out

	var queue: Array = [root_id]
	var seen: Dictionary = {}

	while not queue.is_empty():
		var current_id: int = int(
			queue.pop_front()
		)

		if current_id <= 0:
			continue
		if seen.has(current_id):
			continue

		seen [current_id] = true

		var child_ids: Array = []
		var facts: Dictionary = (
			gs.get_npc_facts_by_id(
				current_id
			)
		)

		if not facts.is_empty():
			var children_raw: Variant = facts.get(
				"children",
				[]
			)

			if typeof(children_raw) == TYPE_ARRAY:
				for raw_child_id in children_raw as Array:
					var child_id: int = int(
						raw_child_id
					)

					if child_id > 0:
						child_ids.append(
							child_id
						)









		for raw_controlled_id in gs.controlled_lineage_ids:
			var controlled_id: int = int(
				raw_controlled_id
			)

			if (
				controlled_id <= 0
				or controlled_id == current_id
			):
				continue

			var controlled_facts: Dictionary = (
				gs.get_npc_facts_by_id(
					controlled_id
				)
			)

			if controlled_facts.is_empty():
				continue

			var controlled_parent_ids: Variant = (
				controlled_facts.get(
					"parents",
					[]
				)
			)

			if typeof(controlled_parent_ids) != TYPE_ARRAY:
				continue

			for raw_parent_id in controlled_parent_ids as Array:
				if int(raw_parent_id) != current_id:
					continue

				child_ids.append(
					controlled_id
				)
				break

		for raw_child_id in child_ids:
			var child_id: int = int(
				raw_child_id
			)

			if child_id <= 0:
				continue

			if child_id not in out:
				out.append(
					child_id
				)

			queue.append(
				child_id
			)

	return out

func _collect_living_descendant_candidates(root_id: int) -> Array:
	var out: Array = []

	if (
		gs == null
		or root_id <= 0
	):
		return out

	var descendant_ids: Array = (
		_collect_descendant_ids(
			root_id
		)
	)

	for raw_descendant_id in descendant_ids:
		var descendant_id: int = int(
			raw_descendant_id
		)

		if descendant_id <= 0:
			continue

		var person: Person = (
			gs.get_or_reactivate_npc_by_id(
				descendant_id
			)
		)

		if (
			person == null
			or not bool(
				person.alive
			)
			or float(
				person.health
			) <= 0.0
		):
			continue

		out.append(
			person
		)

	return out


func _get_touched_bloodline_ids() -> Array:
	var raw = gs.afterlife_state.get("touched_bloodline_ids", [])
	if typeof(raw) == TYPE_ARRAY:
		return raw.duplicate()
	return []


func _weighted_pick(weights: Dictionary, fallback: Array) -> String:
	if fallback.is_empty():
		return ""

	var total: float = 0.0
	for item in fallback:
		total += max(0.0, float(weights.get(str(item), 0.0)))

	if total <= 0.0:
		return str(fallback [randi() % fallback.size()])

	var roll: float = randf() * total
	var cursor: float = 0.0

	for item in fallback:
		var label: String = str(item)
		cursor += max(0.0, float(weights.get(label, 0.0)))
		if roll <= cursor:
			return label

	return str(fallback.back())
func nominate_scenarios_for_player(context:= {}) -> Array:
	var out: Array = []
	if gs == null:
		return out
	if gs.afterlife_active:
		return out
	if not gs.is_feature_enabled("supernatural_events"):
		return out

	var player: Person = context.get("player", null)
	if player == null or not player.alive:
		return out

	out.append({
		"id": "afterlife_nudge_%d" % int(context.get("year", 0)),
		"category": "afterlife",
		"era_tags": ["any"],
		"reality_modes": ["enhanced", "chaos"],
		"reality_weights": {
			"enhanced": 1.0,
			"chaos": 1.15
		},
		"tone": "spiritual",
		"rarity": 0.78,
		"cooldown_key": "afterlife:nudge",
		"cooldown_years": 5,
		"priority": 8,
		"min_age": 8,
		"max_age": 130,
		"prompt": "Something ancestral seems to be pressing against the edge of my year. Do I welcome it or shut it out?",
		"followup_hooks": ["afterlife.nudge"],
		"bias_payloads": {},
		"choices": [
			{
				"id": "welcome",
				"label": "Welcome the pull.",
				"journal_line": "I chose not to shut out the strange ancestral pull I felt.",
				"followup_hooks": ["afterlife.nudge.welcome"],
				"bias_payloads": {
					"afterlife_pressure": {
						"legacy_pull": 15.0
					},
					"memory_bias": {
						"ancestral_openness": 8.0
					},
					"expiry": {
						"years": 1
					}
				}
			},
			{
				"id": "block",
				"label": "Block it and stay in the material world.",
				"journal_line": "I chose to stay rooted in the material world and block out the pull.",
				"followup_hooks": ["afterlife.nudge.block"],
				"bias_payloads": {
					"afterlife_pressure": {
						"legacy_pull": -8.0
					},
					"health_bias": {
						"stress_delta": -1.0
					},
					"expiry": {
						"years": 1
					}
				}
			}
		]
	})

	return out