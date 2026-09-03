extends Resource
class_name RelationshipsHubContractEngine
signal resident_switch_destination_packet_published(
	target_id: int,
	switch_packet: Dictionary
)
const ENGINE_SCHEMA:= "eralife.relationships_hub_contract_engine"
const HUB_CONTRACT_SCHEMA:= "eralife.relationships_hub.contract"
const GROUP_CONTRACT_SCHEMA:= "eralife.relationships_hub.group_contract"
const CARD_CONTRACT_SCHEMA:= "eralife.relationships_hub.card_contract"
const PROFILE_CONTRACT_SCHEMA:= "eralife.relationships_hub.profile_contract"
const CONTRACT_VERSION:= 2
const MAX_CACHE_SIZE:= 360

var gs: GameState = null
var switch_engine: UniversalSwitchContractEngine = null
var playable_life_viewer: PlayableLifeViewer = null

var sequence: int = 0
var hub_contract_cache: Dictionary = {}
var group_contract_cache: Dictionary = {}
var card_contract_cache: Dictionary = {}
var profile_contract_cache: Dictionary = {}
const SWITCH_DESTINATION_UPGRADE_PUMP_MIN_DELAY_SECONDS: float = 0.016
const SWITCH_DESTINATION_UPGRADE_PUMP_MAX_DELAY_SECONDS: float = 0.22

var switch_shell_stage_queue: Array = []
var switch_shell_stage_seen: Dictionary = {}



var switch_shell_stage_pump_armed: bool = false





var switch_destination_upgrade_queue: Array = []
var switch_destination_upgrade_seen: Dictionary = {}
var switch_destination_upgrade_pump_armed: bool = false
var switch_destination_upgrade_pump_generation: int = 0






var resident_projection_work_by_signature: Dictionary = {}

var last_report: Dictionary = {}


func _init(
	game_state: GameState = null,
	universal_switch_engine: UniversalSwitchContractEngine = null,
	viewer: PlayableLifeViewer = null
) -> void:
	bind(game_state, universal_switch_engine, viewer)

func _resolve_canonical_switch_engine() -> UniversalSwitchContractEngine:
	if gs == null:
		return switch_engine

	var previous_authority_missing: bool = (
		switch_engine == null
	)
	var canonical_authority: UniversalSwitchContractEngine = (
		gs.universal_switch_contract_engine
		as UniversalSwitchContractEngine
	)




	if canonical_authority == null:
		canonical_authority = UniversalSwitchContractEngine.new(
			gs
		)
		gs.universal_switch_contract_engine = (
			canonical_authority
		)

	switch_engine = canonical_authority

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	gs.scenario_state [
		"relationships_hub_switch_authority_bound"
	] = (
		switch_engine != null
	)
	gs.scenario_state [
		"relationships_hub_switch_authority"
	] = (
		"UniversalSwitchContractEngine"
		if switch_engine != null
		else "missing"
	)
	gs.scenario_state [
		"relationships_hub_switch_authority_is_game_state_canonical"
	] = (
		switch_engine
		== gs.universal_switch_contract_engine
	)
	gs.scenario_state [
		"relationships_hub_switch_authority_main_scene_binding_required"
	] = false
	gs.scenario_state [
		"relationships_hub_switch_authority_ready_gate_member"
	] = false

	if (
		previous_authority_missing
		and switch_engine != null
	):
		gs.scenario_state [
			"relationships_hub_switch_authority_repaired_at_ms"
		] = int(
			Time.get_ticks_msec()
		)

		EraLog.truth(
			"SWITCH_DESTINATION_UPGRADE_AUTHORITY_REBOUND"
			+ "|authority=UniversalSwitchContractEngine"
			+ "|canonical_game_state_authority=true"
			+ "|main_scene_binding_required=false"
			+ "|ready_gate_member=false"
			+ "|at_ms=" + str(Time.get_ticks_msec())
		)

	return switch_engine
func bind(
	game_state: GameState,
	universal_switch_engine: UniversalSwitchContractEngine = null,
	viewer: PlayableLifeViewer = null
) -> void:
	gs = game_state
	playable_life_viewer = viewer

	if (
		gs != null
		and gs.universal_switch_contract_engine != null
	):
		switch_engine = (
			gs.universal_switch_contract_engine
			as UniversalSwitchContractEngine
		)
	elif universal_switch_engine != null:
		switch_engine = universal_switch_engine

		if gs != null:
			gs.universal_switch_contract_engine = (
				universal_switch_engine
			)
	else:
		switch_engine = null

	_ensure_state()


func bind_game_state(
	game_state: GameState
) -> void:
	gs = game_state



	_resolve_canonical_switch_engine()
	_ensure_state()


func bind_switch_engine(
	universal_switch_engine: UniversalSwitchContractEngine
) -> void:
	if (
		gs != null
		and gs.universal_switch_contract_engine != null
	):
		switch_engine = (
			gs.universal_switch_contract_engine
			as UniversalSwitchContractEngine
		)
		return

	if universal_switch_engine != null:
		switch_engine = universal_switch_engine

		if gs != null:
			gs.universal_switch_contract_engine = (
				universal_switch_engine
			)

		return

	_resolve_canonical_switch_engine()


func bind_playable_life_viewer(viewer: PlayableLifeViewer) -> void:
	playable_life_viewer = viewer
func _resident_switch_packet_is_temporally_current_for_actor(
	packet: Dictionary,
	target_id: int
) -> bool:
	if (
		packet.is_empty()
		or target_id <= 0
		or gs == null
	):
		return false

	var canonical_target: Person = null

	if (
		gs.player != null
		and int(gs.player.id) == target_id
	):
		canonical_target = gs.player
	elif gs.has_method(
		"get_npc_by_id"
	):
		canonical_target = gs.get_npc_by_id(
			target_id,
			false
		)

	if canonical_target == null:
		return false

	var surface: Dictionary = _shallow_dictionary(
		packet.get(
			"surface_contract",
			{}
		)
	)
	var lens: Dictionary = _shallow_dictionary(
		packet.get(
			"press_frame_lens_cache",
			surface.get(
				"press_frame_lens_cache",
				{}
			)
		)
	)

	if (
		surface.is_empty()
		or lens.is_empty()
	):
		return false

	var current_year: int = int(
		gs.year
	)
	var current_age: int = int(
		canonical_target.age
	)
	var switch_authority = switch_engine

	if (
		switch_authority == null
		and gs.universal_switch_contract_engine != null
	):
		switch_authority = (
			gs.universal_switch_contract_engine
		)

	if (
		switch_authority != null
		and switch_authority.has_method(
			"_profile_switch_core_packet_truth"
		)
	):
		var core_truth: Dictionary = _shallow_dictionary(
			switch_authority._profile_switch_core_packet_truth(
				packet,
				target_id
			)
		)

		if not bool(
			core_truth.get(
				"temporal_pointer_hot",
				false
			)
		):
			return false

	return (
		int(
			packet.get(
				"actor_id",
				-1
			)
		) == target_id
		and int(
			surface.get(
				"actor_id",
				-1
			)
		) == target_id
		and int(
			packet.get(
				"world_year",
				surface.get(
					"world_year",
					-999999
				)
			)
		) == current_year
		and int(
			surface.get(
				"world_year",
				-999999
			)
		) == current_year
		and int(
			lens.get(
				"world_year",
				-999999
			)
		) == current_year
		and int(
			surface.get(
				"age",
				-1
			)
		) == current_age
		and int(
			lens.get(
				"age",
				-1
			)
		) == current_age
		and str(
			lens.get(
				"life_diary_text",
				""
			)
		).strip_edges() != ""
	)
func _resident_switch_packet_is_structurally_complete_for_actor(
	packet: Dictionary,
	target_id: int
) -> bool:
	if (
		target_id <= 0
		or packet.is_empty()
	):
		return false

	var surface: Dictionary = _shallow_dictionary(
		packet.get(
			"surface_contract",
			{}
		)
	)

	if surface.is_empty():
		return false

	var press_frame_lens_cache: Dictionary = _shallow_dictionary(
		packet.get(
			"press_frame_lens_cache",
			surface.get(
				"press_frame_lens_cache",
				{}
			)
		)
	)

	var lens_structurally_hot: bool = (
		not press_frame_lens_cache.is_empty()
		and int(
			press_frame_lens_cache.get(
				"actor_id",
				-1
			)
		) == target_id
		and str(
			press_frame_lens_cache.get(
				"life_diary_text",
				""
			)
		).strip_edges() != ""
	)

	if not lens_structurally_hot:
		return false

	var main_tab_deck: Dictionary = _shallow_dictionary(
		packet.get(
			"main_tab_surface_contracts",
			surface.get(
				"main_tab_surface_contracts",
				{}
			)
		)
	)

	var support_packet: Dictionary = _shallow_dictionary(
		packet.get(
			"control_switch_support_surface_packet",
			surface.get(
				"control_switch_support_surface_packet",
				{}
			)
		)
	)

	return (
		_profile_switch_packet_core_hot(
			packet,
			target_id
		)
		and _resident_switch_main_tab_deck_is_hot_for_actor(
			main_tab_deck,
			target_id
		)
		and not support_packet.is_empty()
		and int(
			support_packet.get(
				"actor_id",
				-1
			)
		) == target_id
		and bool(
			support_packet.get(
				"main_tab_surface_deck_hot",
				false
			)
		)
	)
func _resident_complete_switch_packet_for_actor(
	target_id: int
) -> Dictionary:
	if (
		target_id <= 0
		or gs == null
		or typeof(gs.scenario_state) != TYPE_DICTIONARY
	):
		return {}

	var canonical_target: Person = null

	if (
		gs.player != null
		and int(
			gs.player.id
		) == target_id
	):
		canonical_target = gs.player
	elif gs.has_method(
		"get_npc_by_id"
	):
		canonical_target = gs.get_npc_by_id(
			target_id,
			false
		)

	if canonical_target == null:
		return {}






	if (
		not bool(
			canonical_target.alive
		)
		or float(
			canonical_target.health
		) <= 0.0
	):
		return {}

	var actor_key: String = str(
		target_id
	)
	var packet_cache: Dictionary = _shallow_dictionary(
		gs.scenario_state.get(
			"profile_pointer_packet_by_actor",
			{}
		)
	)
	var latest_packet: Dictionary = _shallow_dictionary(
		packet_cache.get(
			actor_key,
			{}
		)
	)

	if (
		_resident_switch_packet_is_structurally_complete_for_actor(
			latest_packet,
			target_id
		)
		and _resident_switch_packet_is_temporally_current_for_actor(
			latest_packet,
			target_id
		)
	):
		return latest_packet.duplicate(false)

	var revisions_by_actor: Dictionary = _shallow_dictionary(
		gs.scenario_state.get(
			"profile_pointer_revisions_by_actor",
			{}
		)
	)
	var actor_revisions: Array = _shallow_array(
		revisions_by_actor.get(
			actor_key,
			[]
		)
	)
	var revision_registry: Dictionary = _shallow_dictionary(
		gs.scenario_state.get(
			"profile_pointer_packet_revision_registry",
			{}
		)
	)
	var latest_revision: String = str(
		latest_packet.get(
			"pointer_revision",
			""
		)
	).strip_edges()

	for index in range(
		actor_revisions.size() - 1,
		-1,
		-1
	):
		var revision: String = str(
			actor_revisions [index]
		).strip_edges()

		if (
			revision == ""
			or revision == latest_revision
		):
			continue

		var revision_record: Dictionary = _shallow_dictionary(
			revision_registry.get(
				revision,
				{}
			)
		)

		if (
			revision_record.is_empty()
			or int(
				revision_record.get(
					"actor_id",
					-1
				)
			) != target_id
		):
			continue

		var historical_packet: Dictionary = _shallow_dictionary(
			revision_record.get(
				"viewer_packet",
				{}
			)
		)

		if (
			_resident_switch_packet_is_structurally_complete_for_actor(
				historical_packet,
				target_id
			)
			and _resident_switch_packet_is_temporally_current_for_actor(
				historical_packet,
				target_id
			)
		):
			return historical_packet.duplicate(false)

	return {}
func resident_complete_switch_packet_for_actor(
	target_id: int
) -> Dictionary:
	return _resident_complete_switch_packet_for_actor(
		target_id
	)
func emit_hub_contract(
		actor: Person,
		context: Dictionary = {}
) -> Dictionary:
		_ensure_state()

		if actor == null:
			return _fail(
				"missing_actor",
				context
			)

		var section: String = _resolve_section_id(
			str(
				context.get(
					"active_section_id",
					context.get(
						"section",
						"family"
					)
				)
			)
		)
		var force_refresh: bool = bool(
			context.get(
				"force_refresh",
				false
			)
		)
		var signature: String = _hub_signature(
			actor,
			section,
			context
		)
		var cached: Dictionary = _shallow_dictionary(
			hub_contract_cache.get(
				signature,
				{}
			)
		)

		if (
			not force_refresh
			and not cached.is_empty()
		):
			cached ["cache_hit"] = true
			cached ["requested_at_ms"] = int(
				Time.get_ticks_msec()
			)
			last_report = cached.duplicate(false)

			return cached.duplicate(false)

		if force_refresh:
			resident_projection_work_by_signature.erase(
				signature
			)

		if (
			bool(
				context.get(
					"resident_projection",
					false
				)
			)
			and bool(
				context.get(
					"cooperative_projection",
					false
				)
			)
		):
			var resident_projection: Dictionary = (
				_step_resident_hub_projection(
					actor,
					section,
					signature,
					context
				)
			)
			var switch_support_projection: bool = (
				_switch_support_projection_requires_complete(
					context
				)
			)

			if (
				switch_support_projection
				and not _switch_support_projection_ready_for_destination(
					resident_projection
				)
			):
				last_report = (
					resident_projection.duplicate(false)
				)

				return {}

			if switch_support_projection:
				resident_projection = (
					resident_projection.duplicate(false)
				)
				resident_projection [
					"switch_destination_relationship_core_ready"
				] = true
				resident_projection [
					"switch_destination_required_sections"
				] = [
					"family",
					"household",
					"partner"
				]
				resident_projection [
					"switch_destination_does_not_require_all_relationship_tabs"
				] = true
				resident_projection [
					"remaining_relationship_projection_may_continue_in_residency"
				] = not bool(
					resident_projection.get(
						"projection_complete",
						false
					)
				)
				resident_projection [
					"switch_press_build_forbidden"
				] = true
				resident_projection [
					"ready_gate_member"
				] = false
				resident_projection [
					"ui_is_renderer_only"
				] = true

			last_report = (
				resident_projection.duplicate(false)
			)

			return resident_projection

		sequence += 1

		var now_ms: int = int(
			Time.get_ticks_msec()
		)
		var climate: Dictionary = (
			_relationship_climate_contract(
				actor
			)
		)
		var tabs: Array = _tab_contracts(
			section
		)
		var section_contracts: Dictionary = {}

		for raw_tab in tabs:
			var tab: Dictionary = _shallow_dictionary(
				raw_tab
			)
			var section_id: String = _resolve_section_id(
				str(
					tab.get(
						"key",
						"family"
					)
				)
			)
			var groups: Array = _hub_group_contracts(
				actor,
				section_id,
				context
			)

			section_contracts [
				section_id
			] = {
				"success": true,
				"schema": HUB_CONTRACT_SCHEMA,
				"version": CONTRACT_VERSION,
				"actor_id": int(
					actor.id
				),
				"actor_name": _actor_display_name(
					actor
				),
				"title": "RELATIONSHIPS HUB",
				"subtitle": (
					"%s's complete relationship graph."
					% _actor_display_name(
						actor
					)
				),
				"header_chip_text": str(
					climate.get(
						"label",
						"Climate: Mixed · 50"
					)
				),
				"active_section_id": section_id,
				"tabs": _tab_contracts(
					section_id
				),
				"groups": groups,
				"climate": climate.duplicate(false),
				"status_text": (
					"Relationship reality is live. "
					+ "Tabs reveal resident projections."
				),
				"truth_state": "hot",
				"projection_complete": true,
				"authoritative_projection": true,
				# NOTE: groups.size() is 1 for the "pets" section whether that single
				# group holds 0 cards or 20, and _affection_signature() hashes
				# actor.affection (humans only). This revision is therefore blind to
				# pet content. Left AS-IS deliberately: the live post-load path is
				# the resident/cooperative projection in _step_resident_hub_projection(),
				# whose revision uses _resident_relationship_section_stream_signature().
				# Fixing that one function covers the bug; changing this producer too
				# was reverted while a crash is being bisected.
				"surface_revision": (
					"%d:%d:%s:%d:%s"
					% [
						int(
							actor.id
						),
						_current_year(),
						section_id,
						groups.size(),
						_affection_signature(
							actor
						)
					]
				),
				"immutable_surface_contract": true,
				"ui_is_renderer_only": true
			}

		var active_projection: Dictionary = (
			_shallow_dictionary(
				section_contracts.get(
					section,
					{}
				)
			)
		)

		if active_projection.is_empty():
			active_projection = {
				"success": true,
				"schema": HUB_CONTRACT_SCHEMA,
				"version": CONTRACT_VERSION,
				"actor_id": int(
					actor.id
				),
				"actor_name": _actor_display_name(
					actor
				),
				"title": "RELATIONSHIPS HUB",
				"subtitle": (
					"%s's relationship graph."
					% _actor_display_name(
						actor
					)
				),
				"header_chip_text": str(
					climate.get(
						"label",
						"Climate: Mixed · 50"
					)
				),
				"active_section_id": section,
				"tabs": tabs,
				"groups": [],
				"climate": climate.duplicate(false),
				"status_text": (
					"Relationship reality is observable."
				),
				"truth_state": "hot",
				"projection_complete": true,
				"authoritative_projection": true,
				"surface_revision": (
					"%d:%d:%s:0"
					% [
						int(
							actor.id
						),
						_current_year(),
						section
					]
				),
				"immutable_surface_contract": true,
				"ui_is_renderer_only": true
			}

		active_projection ["id"] = (
			"relationships_hub_%d_%d_%d"
			% [
				sequence,
				int(
					actor.id
				),
				now_ms
			]
		)
		active_projection ["sequence"] = sequence
		active_projection [
			"section_contracts"
		] = section_contracts.duplicate(false)
		active_projection ["render_policy"] = {
			"ui_is_pure_renderer": true,
			"render_immediately": true
		}
		active_projection [
			"context"
		] = context.duplicate(false)
		active_projection [
			"signature"
		] = signature
		active_projection [
			"created_at_ms"
		] = now_ms
		active_projection [
			"cache_hit"
		] = false
		active_projection [
			"immutable_surface_contract"
		] = true
		active_projection [
			"ui_is_renderer_only"
		] = true

		_store_hub_contract(
			signature,
			active_projection
		)

		last_report = (
			active_projection.duplicate(false)
		)

		return active_projection.duplicate(false)
func _switch_support_projection_requires_complete(
	context: Dictionary
) -> bool:
	var source: String = str(
		context.get(
			"source",
			""
		)
	).strip_edges().to_lower()

	return (
		bool(
			context.get(
				"destination_support_packet_building",
				false
			)
		)
		or bool(
			context.get(
				"support_packet_publication_context",
				false
			)
		)
		or bool(
			context.get(
				"complete_destination_deck_required",
				false
			)
		)
		or source.find(
			"control_switch_support_surface_packet"
		) >= 0
	)
func _resident_relationship_group_quantum_count(
	section: String
) -> int:
	match _resolve_section_id(section):
		"family":
			return 4
		"ancestors":
			return 2
		"household":
			return 2
		"partner":
			return 3
		"pets":
			return 1
		"descendants":
			return 3
		"dead":
			return 6
		"social":
			return 3
		"exes":
			return 1
		_:
			return 1
func _switch_support_projection_ready_for_destination(
		projection: Dictionary
) -> bool:
		if projection.is_empty():
			return false

		if bool(
			projection.get(
				"projection_complete",
				false
			)
		):
			return true

		var section_contracts: Dictionary = _shallow_dictionary(
			projection.get(
				"section_contracts",
				{}
			)
		)

		if section_contracts.is_empty():
			return false

		for raw_section_id in [
			"family",
			"household",
			"partner"
		]:
			var section_id: String = str(
				raw_section_id
			)
			var section_contract: Dictionary = _shallow_dictionary(
				section_contracts.get(
					section_id,
					{}
				)
			)

			if section_contract.is_empty():
				return false

			if not bool(
				section_contract.get(
					"section_projection_complete",
					section_contract.get(
						"projection_complete",
						false
					)
				)
			):
				return false

			if int(
				section_contract.get(
					"actor_id",
					-1
				)
			) != int(
				projection.get(
					"actor_id",
					-1
				)
			):
				return false

		return true
func _resident_relationship_group_quantum(
	actor: Person,
	section: String,
	group_cursor: int,
	context: Dictionary
) -> Dictionary:
	var clean_section: String = _resolve_section_id(
		section
	)

	match clean_section:
		"family":
			match group_cursor:
				0:
					return emit_group_contract(
						actor,
						"Immediate Family",
						_filter_person_ids_by_alive(
							_immediate_family_ids(
								actor
							),
							true
						),
						"No immediate family is visible right now.",
						{
							"premium": true,
							"subtitle": (
								"Parents and siblings stay pinned as the "
								+ "top-priority relationship lane."
							),
							"highlight_cards": true,
							"columns": 2,
							"section_key": "family"
						},
						context
					)
				1:
					return emit_group_contract(
						actor,
						"In-Laws",
						_filter_person_ids_by_alive(
							_in_law_ids(
								actor
							),
							true
						),
						"None yet.",
						{
							"section_key": "family"
						},
						context
					)
				2:
					return emit_group_contract(
						actor,
						"Aunts / Uncles",
						_filter_person_ids_by_alive(
							_aunt_uncle_ids(
								actor
							),
							true
						),
						"None yet.",
						{
							"section_key": "family"
						},
						context
					)
				3:
					return emit_group_contract(
						actor,
						"Nieces / Nephews",
						_filter_person_ids_by_alive(
							_niece_nephew_ids(
								actor
							),
							true
						),
						"None yet.",
						{
							"section_key": "family"
						},
						context
					)

		"ancestors":
			match group_cursor:
				0:
					return emit_group_contract(
						actor,
						"Grandparents",
						_filter_person_ids_by_alive(
							_ancestor_generation_ids(
								actor,
								2
							),
							true
						),
						"No grandparents are currently observable.",
						{
							"premium": true,
							"columns": 2,
							"section_key": "ancestors"
						},
						context
					)
				1:
					return emit_group_contract(
						actor,
						"Great-Grandparents",
						_filter_person_ids_by_alive(
							_ancestor_generation_ids(
								actor,
								3
							),
							true
						),
						"No great-grandparents are currently observable.",
						{
							"section_key": "ancestors"
						},
						context
					)

		"household":
			match group_cursor:
				0:
					return {
						"row_kind": "information",
						"title": "Household State",
						"lines": _household_status_lines(
							actor
						)
					}
				1:
					return emit_group_contract(
						actor,
						"Household Members",
						_filter_person_ids_by_alive(
							_household_member_ids(
								actor
							),
							true
						),
						"No household members are observable.",
						{
							"premium": true,
							"columns": 2,
							"section_key": "household"
						},
						context
					)

		"partner":
			match group_cursor:
				0:
					var partner_ids: Array = []
					var partner: Person = _valid_partner(
						actor
					)

					if _person_is_canonically_living(
						partner
					):
						partner_ids.append(
							int(
								partner.id
							)
						)

					return emit_group_contract(
						actor,
						"Partner",
						partner_ids,
						"No current partner.",
						{
							"premium": true,
							"columns": 2,
							"section_key": "partner"
						},
						context
					)
				1:
					return emit_group_contract(
						actor,
						"Flings",
						_filter_person_ids_by_alive(
							_safe_person_id_array(
								actor,
								"flings"
							),
							true
						),
						"No active flings.",
						{
							"premium": true,
							"section_key": "partner"
						},
						context
					)
				2:
					return emit_group_contract(
						actor,
						"In-Laws",
						_filter_person_ids_by_alive(
							_in_law_ids(
								actor
							),
							true
						),
						"None yet.",
						{
							"section_key": "partner"
						},
						context
					)

		"pets":
			return _pet_group_contract(
				actor,
				context
			)

		"descendants":
			match group_cursor:
				0:
					return emit_group_contract(
						actor,
						"Children",
						_filter_person_ids_by_alive(
							_safe_person_id_array(
								actor,
								"children"
							),
							true
						),
						"No living children.",
						{
							"columns": 2,
							"section_key": "descendants"
						},
						context
					)
				1:
					return emit_group_contract(
						actor,
						"Grandchildren",
						_filter_person_ids_by_alive(
							_descendant_generation_ids(
								actor,
								2
							),
							true
						),
						"No living grandchildren.",
						{
							"section_key": "descendants"
						},
						context
					)
				2:
					return emit_group_contract(
						actor,
						"Great-Grandchildren",
						_filter_person_ids_by_alive(
							_descendant_generation_ids(
								actor,
								3
							),
							true
						),
						"No living great-grandchildren.",
						{
							"section_key": "descendants"
						},
						context
					)

		"dead":
			match group_cursor:
				0:
					return emit_group_contract(
						actor,
						"Dead Great-Grandparents",
						_filter_person_ids_by_alive(
							_ancestor_generation_ids(
								actor,
								3
							),
							false
						),
						"None.",
						{
							"section_key": "dead"
						},
						context
					)
				1:
					return emit_group_contract(
						actor,
						"Dead Grandparents",
						_filter_person_ids_by_alive(
							_ancestor_generation_ids(
								actor,
								2
							),
							false
						),
						"None.",
						{
							"section_key": "dead"
						},
						context
					)
				2:
					return emit_group_contract(
						actor,
						"Dead Parents",
						_filter_person_ids_by_alive(
							_safe_person_id_array(
								actor,
								"parents"
							),
							false
						),
						"None.",
						{
							"section_key": "dead"
						},
						context
					)
				3:
					return emit_group_contract(
						actor,
						"Dead Siblings",
						_filter_person_ids_by_alive(
							_sibling_ids_for_person(
								actor
							),
							false
						),
						"None.",
						{
							"section_key": "dead"
						},
						context
					)
				4:
					return emit_group_contract(
						actor,
						"Dead Children",
						_filter_person_ids_by_alive(
							_safe_person_id_array(
								actor,
								"children"
							),
							false
						),
						"None.",
						{
							"section_key": "dead"
						},
						context
					)
				5:
					return emit_group_contract(
						actor,
						"Other Dead Relationships",
						_dead_other_relationship_ids(
							actor
						),
						"None.",
						{
							"section_key": "dead"
						},
						context
					)

		"social":
			match group_cursor:
				0:
					return emit_group_contract(
						actor,
						"Friends",
						_filter_person_ids_by_alive(
							_safe_person_id_array(
								actor,
								"friends"
							),
							true
						),
						"No visible friends.",
						{
							"premium": true,
							"section_key": "social"
						},
						context
					)
				1:
					return emit_group_contract(
						actor,
						"Aunts / Uncles",
						_filter_person_ids_by_alive(
							_aunt_uncle_ids(
								actor
							),
							true
						),
						"None yet.",
						{
							"section_key": "social"
						},
						context
					)
				2:
					return emit_group_contract(
						actor,
						"Nieces / Nephews",
						_filter_person_ids_by_alive(
							_niece_nephew_ids(
								actor
							),
							true
						),
						"None yet.",
						{
							"section_key": "social"
						},
						context
					)

		"exes":
			return emit_group_contract(
				actor,
				"Exes",
				_filter_person_ids_by_alive(
					_safe_person_id_array(
						actor,
						"exes"
					),
					true
				),
				"No visible exes.",
				{
					"premium": true,
					"section_key": "exes"
				},
				context
			)

	return {}
func _resident_relationship_section_stream_signature(
	groups: Array
) -> String:
	var parts: PackedStringArray = PackedStringArray()

	for raw_group in groups:
		var group: Dictionary = _shallow_dictionary(
			raw_group
		)

		if group.is_empty():
			continue

		var card_ids: Array = []
		var card_revisions: Array = []

		for raw_card in _array(
			group.get(
				"cards",
				[]
			)
		):
			var card: Dictionary = _shallow_dictionary(
				raw_card
			)

			# FIX: pet and other entity cards carry no int "target_id" -- they are
			# keyed by the String "target_entity_id" ("pet:3"). The old `target_id
			# <= 0: continue` guard therefore skipped EVERY pet card, so this
			# signature was byte-identical for a pets group holding 0 cards and one
			# holding 2. The panel gates surface rebuilds solely on surface_revision
			# (InstitutionHubPanelBase._service_next_section_surface_contract), so a
			# correct contract carrying 2 restored pets was discarded as unchanged
			# and the empty surface built during the load stayed on screen.
			var card_key: String = ""
			var target_id: int = int(
				card.get(
					"target_id",
					-1
				)
			)

			if target_id > 0:
				card_key = "person:%d" % target_id
			else:
				card_key = str(
					card.get(
						"target_entity_id",
						""
					)
				).strip_edges()

			if card_key == "":
				continue

			card_ids.append(
				card_key
			)

			var age_raw: Variant = card.get(
				"target_age",
				-1
			)
			var age_value: int = -1

			if (
				typeof(
					age_raw
				) == TYPE_INT
				or typeof(
					age_raw
				) == TYPE_FLOAT
			):
				age_value = int(
					age_raw
				)

			var bond_raw: Variant = card.get(
				"bond",
				-1
			)
			var bond_value: int = -1

			if (
				typeof(
					bond_raw
				) == TYPE_INT
				or typeof(
					bond_raw
				) == TYPE_FLOAT
			):
				bond_value = int(
					bond_raw
				)

			card_revisions.append(
				"%s:%d:%d:%s"
				% [
					card_key,
					age_value,
					bond_value,
					str(
						card.get(
							"signature",
							""
						)
					)
				]
			)

		var unresolved_ids: Array = _array(
			group.get(
				"unresolved_target_ids",
				[]
			)
		)

		parts.append(
			"%s:%s:%s:%s:%s"
			% [
				str(
					group.get(
						"row_kind",
						"relationship_group"
					)
				),
				str(
					group.get(
						"title",
						""
					)
				),
				_stable_array_signature(
					card_ids
				),
				_stable_array_signature(
					card_revisions
				),
				_stable_array_signature(
					unresolved_ids
				)
			]
		)

	return "||".join(
		parts
	)
func _step_resident_hub_projection(
	actor: Person,
	active_section: String,
	signature: String,
	context: Dictionary
) -> Dictionary:
	var work_raw: Variant = (
		resident_projection_work_by_signature.get(
			signature,
			{}
		)
	)
	var work: Dictionary = (
		(work_raw as Dictionary).duplicate(false)
		if typeof(work_raw) == TYPE_DICTIONARY
		else {}
	)

	if work.is_empty():
		var initial_projection_context: Dictionary = (
			context.duplicate(false)
		)
		var ordered_tabs: Array = _tab_contracts(
			active_section
		)
		var switch_destination_projection: bool = (
			_switch_support_projection_requires_complete(
				context
			)
		)
		var active_tab_index: int = -1

		initial_projection_context [
			"resident_projection"
		] = true
		initial_projection_context [
			"cooperative_projection"
		] = true
		initial_projection_context [
			"projection_read_only"
		] = true
		initial_projection_context [
			"publish_card_shell_to_scenario"
		] = false
		initial_projection_context [
			"projection_bond_cache"
		] = {}
		initial_projection_context [
			"one_complete_section_per_service_quantum"
		] = true
		initial_projection_context [
			"switch_destination_relationship_priority"
		] = switch_destination_projection

		if switch_destination_projection:
			ordered_tabs = (
				_switch_destination_priority_tab_order(
					ordered_tabs
				)
			)
		else:
			for index in range(
				ordered_tabs.size()
			):
				var candidate: Dictionary = _shallow_dictionary(
					ordered_tabs [index]
				)

				if (
					_resolve_section_id(
						str(
							candidate.get(
								"key",
								"family"
							)
						)
					)
					== active_section
				):
					active_tab_index = index
					break

			if active_tab_index > 0:
				var active_tab: Variant = (
					ordered_tabs [
						active_tab_index
					]
				)

				ordered_tabs.remove_at(
					active_tab_index
				)
				ordered_tabs.push_front(
					active_tab
				)

		work = {
			"signature": signature,
			"actor_id": int(
				actor.id
			),
			"active_section_id": active_section,
			"tabs": ordered_tabs,
			"section_contracts": {},
			"section_groups": {},
			"section_cursor": 0,
			"group_cursor": 0,
			"projection_context": initial_projection_context,
			"climate": (
				_relationship_climate_contract_read_only(
					actor,
					initial_projection_context
				)
			),
			"started_at_ms": int(
				Time.get_ticks_msec()
			),
			"last_step_at_ms": 0,
			"complete": false,
			"failed": false,
			"switch_destination_relationship_priority": (
				switch_destination_projection
			)
		}

	var tabs_raw: Variant = work.get(
		"tabs",
		[]
	)
	var tabs: Array = (
		(tabs_raw as Array).duplicate(false)
		if typeof(tabs_raw) == TYPE_ARRAY
		else []
	)
	var section_cursor: int = int(
		work.get(
			"section_cursor",
			0
		)
	)
	var group_cursor: int = int(
		work.get(
			"group_cursor",
			0
		)
	)
	var section_contracts: Dictionary = _shallow_dictionary(
		work.get(
			"section_contracts",
			{}
		)
	)
	var section_groups: Dictionary = _shallow_dictionary(
		work.get(
			"section_groups",
			{}
		)
	)
	var climate: Dictionary = _shallow_dictionary(
		work.get(
			"climate",
			{}
		)
	)
	var projection_context: Dictionary = _shallow_dictionary(
		work.get(
			"projection_context",
			{}
		)
	)

	if section_cursor < tabs.size():
		var tab: Dictionary = _shallow_dictionary(
			tabs [
				section_cursor
			]
		)
		var section_id: String = _resolve_section_id(
			str(
				tab.get(
					"key",
					"family"
				)
			)
		)
		var required_group_count: int = (
			_resident_relationship_group_quantum_count(
				section_id
			)
		)
		var current_groups_raw: Variant = (
			section_groups.get(
				section_id,
				[]
			)
		)
		var current_groups: Array = (
			(current_groups_raw as Array).duplicate(false)
			if typeof(current_groups_raw) == TYPE_ARRAY
			else []
		)
		var active_group_cursor: int = clampi(
			group_cursor,
			0,
			required_group_count
		)

		projection_context [
			"section_key"
		] = section_id
		projection_context [
			"section_group_count"
		] = required_group_count
		projection_context [
			"one_complete_section_per_service_quantum"
		] = false
		projection_context [
			"one_group_per_service_quantum"
		] = true

		if active_group_cursor < required_group_count:
			projection_context [
				"section_group_cursor"
			] = active_group_cursor

			var group_contract: Dictionary = (
				_resident_relationship_group_quantum(
					actor,
					section_id,
					active_group_cursor,
					projection_context
				)
			)
			var group_projection_pending: bool = bool(
				group_contract.get(
					"projection_pending",
					false
				)
			)

			if not group_contract.is_empty():



				while (
					current_groups.size()
					< active_group_cursor
				):
					current_groups.append(
						{}
					)

				if (
					current_groups.size()
					== active_group_cursor
				):
					current_groups.append(
						group_contract
					)
				else:
					current_groups [
						active_group_cursor
					] = group_contract





			if not group_projection_pending:
				active_group_cursor += 1
		var section_complete: bool = (
			active_group_cursor
			>= required_group_count
		)
		var section_progress: float = clampf(
			float(
				active_group_cursor
			)
			/ float(
				maxi(
					1,
					required_group_count
				)
			),
			0.0,
			1.0
		)

		var section_contract: Dictionary = {
			"success": true,
			"schema": HUB_CONTRACT_SCHEMA,
			"version": CONTRACT_VERSION,
			"actor_id": int(
				actor.id
			),
			"actor_name": _actor_display_name(
				actor
			),
			"title": "RELATIONSHIPS HUB",
			"subtitle": (
				"%s's complete relationship graph."
				% _actor_display_name(
					actor
				)
			),
			"header_chip_text": str(
				climate.get(
					"label",
					"Climate: Mixed · 50"
				)
			),
			"active_section_id": section_id,
			"tabs": _tab_contracts(
				section_id
			),
			"groups": current_groups,
			"climate": climate.duplicate(false),
			"status_text": (
				"Relationship cards are live. Extended groups continue "
				+ "streaming without blocking this lens."
			),
			"truth_state": (
				"hot"
				if section_complete
				else "streaming"
			),
			"projection_pending": not section_complete,
			"projection_complete": section_complete,
			"section_projection_complete": section_complete,
			"section_projection_progress": section_progress,
			"authoritative_projection": true,
			"one_group_per_service_quantum": true,
			"ready_gate_member": false,
				"surface_revision": (
					"%d:%d:%s:%s:%s"
					% [
						int(
							actor.id
						),
						_current_year(),
						section_id,
						_resident_relationship_section_stream_signature(
							current_groups
						),
						_affection_signature(
							actor
						)
					]
				),
			"immutable_surface_contract": true,
			"ui_is_renderer_only": true
		}

		section_groups [
			section_id
		] = current_groups
		section_contracts [
			section_id
		] = section_contract

		work [
			"stream_section_id"
		] = section_id
		work [
			"stream_section_contract"
		] = section_contract.duplicate(false)
		work [
			"stream_group_cursor"
		] = active_group_cursor
		work [
			"stream_group_count"
		] = required_group_count
		work [
			"stream_group_complete"
		] = section_complete

		if section_complete:
			section_cursor += 1
			group_cursor = 0
		else:
			group_cursor = active_group_cursor

		work [
			"section_cursor"
		] = section_cursor
		work [
			"group_cursor"
		] = group_cursor
		work [
			"section_contracts"
		] = section_contracts
		work [
			"section_groups"
		] = section_groups
		work [
			"projection_context"
		] = projection_context
		work [
			"last_step_at_ms"
		] = int(
			Time.get_ticks_msec()
		)

		resident_projection_work_by_signature [
			signature
		] = work

	var active_projection: Dictionary = _shallow_dictionary(
		section_contracts.get(
			active_section,
			{}
		)
	)

	if (
		active_projection.is_empty()
		and not section_contracts.is_empty()
	):
		var first_key: Variant = (
			section_contracts.keys() [0]
		)

		active_projection = _shallow_dictionary(
			section_contracts.get(
				first_key,
				{}
			)
		)

	if active_projection.is_empty():
		return {
			"success": true,
			"schema": HUB_CONTRACT_SCHEMA,
			"version": CONTRACT_VERSION,
			"actor_id": int(
				actor.id
			),
			"actor_name": _actor_display_name(
				actor
			),
			"title": "RELATIONSHIPS HUB",
			"subtitle": (
				"%s's relationship graph."
				% _actor_display_name(
					actor
				)
			),
			"header_chip_text": str(
				climate.get(
					"label",
					"Climate: Mixed · 50"
				)
			),
			"active_section_id": active_section,
			"tabs": _tab_contracts(
				active_section
			),
			"groups": [],
			"climate": climate.duplicate(false),
			"status_text": (
				"Relationship cards are entering the resident lens."
			),
			"truth_state": "warming",
			"projection_pending": true,
			"projection_complete": false,
			"cooperative_projection": true,
			"projection_read_only": true,
			"one_complete_section_per_service_quantum": true,
			"ready_gate_member": false,
			"ui_is_renderer_only": true
		}

	var complete: bool = (
		section_cursor >= tabs.size()
	)
	var total_group_count: int = 0
	var completed_group_count: int = 0

	for raw_tab in tabs:
		var count_section: String = _resolve_section_id(
			str(
				_shallow_dictionary(
					raw_tab
				).get(
					"key",
					"family"
				)
			)
		)

		total_group_count += (
			_resident_relationship_group_quantum_count(
				count_section
			)
		)

		var groups_raw: Variant = section_groups.get(
			count_section,
			[]
		)

		if typeof(groups_raw) == TYPE_ARRAY:
			for raw_group in groups_raw as Array:
				var projected_group: Dictionary = (
					_shallow_dictionary(
						raw_group
					)
				)

				if projected_group.is_empty():
					continue

				if bool(
					projected_group.get(
						"projection_pending",
						false
					)
				):
					continue

				completed_group_count += 1

	active_projection = (
		active_projection.duplicate(false)
	)

	active_projection [
		"section_contracts"
	] = section_contracts
	active_projection [
		"projection_pending"
	] = not complete
	active_projection [
		"projection_complete"
	] = complete
	active_projection [
		"projection_progress"
	] = clampf(
		float(
			completed_group_count
		)
		/ float(
			maxi(
				1,
				total_group_count
			)
		),
		0.0,
		1.0
	)
	active_projection [
		"projected_group_count"
	] = completed_group_count
	active_projection [
		"required_group_count"
	] = total_group_count
	active_projection [
		"projected_section_count"
	] = section_cursor
	active_projection [
		"required_section_count"
	] = tabs.size()
	active_projection [
		"cooperative_projection"
	] = true
	active_projection [
		"projection_read_only"
	] = true
	active_projection [
		"one_group_per_service_quantum"
	] = true
	active_projection [
		"one_complete_section_per_service_quantum"
	] = false
	active_projection [
		"stream_section_id"
	] = str(
		work.get(
			"stream_section_id",
			""
		)
	)
	active_projection [
		"stream_section_contract"
	] = _shallow_dictionary(
		work.get(
			"stream_section_contract",
			{}
		)
	)
	active_projection [
		"ready_gate_member"
	] = false
	active_projection [
		"ui_is_renderer_only"
	] = true
	active_projection [
		"render_policy"
	] = {
		"ui_is_pure_renderer": true,
		"one_group_per_service_quantum": true,
		"one_complete_section_per_service_quantum": false,
		"switch_destination_priority_sections": [
			"family",
			"household",
			"partner"
		],
		"render_immediately": true
	}
	active_projection [
		"context"
	] = context.duplicate(false)
	active_projection [
		"signature"
	] = signature
	active_projection [
		"cache_hit"
	] = false
	active_projection [
		"immutable_surface_contract"
	] = true








	var switch_shell_quantum_serviced: bool = false
	var switch_shell_report: Dictionary = {}
	var actor_scalar_truth_report: Dictionary = {}

	if not switch_shell_stage_queue.is_empty():
		var switch_shell_head: Dictionary = _shallow_dictionary(
			switch_shell_stage_queue [
				0
			]
		)
		var switch_shell_target_id: int = int(
			switch_shell_head.get(
				"target_id",
				-1
			)
		)



		actor_scalar_truth_report = (
			_prepare_switch_destination_actor_scalar_truth(
				switch_shell_target_id
			)
		)

		switch_shell_report = (
			flush_switch_shell_stage_queue(
				1,
				{
					"source": (
						"relationships_hub_contract_engine."
						+ "resident_projection_switch_shell_tail"
					),
					"continuous_destination_preparation": true,
					"ui_interaction_grace_ignored": true,
					"background_only": true,
					"blocks_ui": false,
					"switch_press_must_not_build_surface": true,
					"complete_destination_deck_required": false,
					"support_deck_blocks_switch": false,
					"ready_gate_member": false,
					"ui_is_renderer_only": true
				}
			)
		)

		switch_shell_quantum_serviced = true

	active_projection [
		"switch_shell_background_quantum_serviced"
	] = switch_shell_quantum_serviced
	active_projection [
		"switch_shell_background_quantum_report"
	] = switch_shell_report.duplicate(false)
	active_projection [
		"switch_shell_background_actor_scalar_truth_report"
	] = actor_scalar_truth_report.duplicate(false)
	active_projection [
		"switch_shell_background_quantum_renderer_thread"
	] = false
	active_projection [
		"switch_shell_background_service_lane"
	] = "detached_resident_projection_worker"

	var switch_destination_upgrade_report: Dictionary = (
		_service_resident_switch_destination_upgrade_quantum()
	)

	active_projection [
		"switch_destination_upgrade_quantum_serviced"
	] = bool(
		switch_destination_upgrade_report.get(
			"serviced",
			false
		)
	)
	active_projection [
		"switch_destination_upgrade_quantum_report"
	] = switch_destination_upgrade_report.duplicate(false)
	active_projection [
		"switch_destination_upgrade_renderer_thread"
	] = false
	active_projection [
		"switch_destination_upgrade_ui_idle_required"
	] = false

	var relationship_surface_complete: bool = complete
	var switch_shell_background_complete: bool = (
		switch_shell_stage_queue.is_empty()
	)
	var switch_destination_upgrade_complete: bool = (
		switch_destination_upgrade_queue.is_empty()
	)
	var relationship_authority_lane_complete: bool = (
		relationship_surface_complete
		and switch_shell_background_complete
		and switch_destination_upgrade_complete
	)





	active_projection [
		"surface_projection_complete"
	] = relationship_surface_complete
	active_projection [
		"surface_projection_pending"
	] = not relationship_surface_complete
	active_projection [
		"switch_shell_background_complete"
	] = switch_shell_background_complete
	active_projection [
		"switch_shell_background_remaining"
	] = switch_shell_stage_queue.size()
	active_projection [
		"switch_destination_upgrade_complete"
	] = switch_destination_upgrade_complete
	active_projection [
		"switch_destination_upgrade_remaining"
	] = switch_destination_upgrade_queue.size()
	active_projection [
		"relationship_authority_lane_complete"
	] = relationship_authority_lane_complete

	active_projection [
		"projection_complete"
	] = relationship_authority_lane_complete
	active_projection [
		"projection_pending"
	] = not relationship_authority_lane_complete

	switch_shell_stage_pump_armed = (
		not switch_shell_background_complete
	)
	switch_destination_upgrade_pump_armed = (
		not switch_destination_upgrade_complete
	)

	if not relationship_authority_lane_complete:
		last_report = (
			active_projection.duplicate(false)
		)
		return active_projection











	sequence += 1

	var now_ms: int = int(
		Time.get_ticks_msec()
	)

	active_projection ["id"] = (
		"relationships_hub_%d_%d_%d"
		% [
			sequence,
			int(
				actor.id
			),
			now_ms
		]
	)
	active_projection [
		"sequence"
	] = sequence
	active_projection [
		"created_at_ms"
	] = now_ms
	active_projection [
		"relationship_authority_lane_complete"
	] = true
	active_projection [
		"projection_complete"
	] = true
	active_projection [
		"projection_pending"
	] = false
	active_projection [
		"switch_shell_background_complete"
	] = true
	active_projection [
		"switch_shell_background_remaining"
	] = 0
	active_projection [
		"switch_destination_upgrade_complete"
	] = true
	active_projection [
		"switch_destination_upgrade_remaining"
	] = 0

	_store_hub_contract(
		signature,
		active_projection
	)

	resident_projection_work_by_signature.erase(
		signature
	)

	last_report = (
		active_projection.duplicate(false)
	)

	return active_projection.duplicate(false)
func _switch_destination_priority_tab_order(
		tabs: Array
) -> Array:
		var out: Array = []
		var consumed: Dictionary = {}

		for raw_priority_section in [
			"family",
			"household",
			"partner"
		]:
			var priority_section: String = str(
				raw_priority_section
			)

			for raw_tab in tabs:
				var tab: Dictionary = _shallow_dictionary(
					raw_tab
				)
				var tab_section: String = _resolve_section_id(
					str(
						tab.get(
							"key",
							"family"
						)
					)
				)

				if (
					tab_section != priority_section
					or consumed.has(
						tab_section
					)
				):
					continue

				out.append(
					raw_tab
				)
				consumed [
					tab_section
				] = true
				break

		for raw_tab in tabs:
			var tab: Dictionary = _shallow_dictionary(
				raw_tab
			)
			var tab_section: String = _resolve_section_id(
				str(
					tab.get(
						"key",
						"family"
					)
				)
			)

			if consumed.has(
				tab_section
			):
				continue

			out.append(
				raw_tab
			)
			consumed [
				tab_section
			] = true

		return out
func _projection_bond_score_for_pair(
	observer: Person,
	target: Person,
	context: Dictionary = {}
) -> int:
	if (
		observer == null
		or target == null
	):
		return 0

	if int(observer.id) == int(target.id):
		return 100

	var bond_cache_raw: Variant = context.get(
		"projection_bond_cache",
		{}
	)
	var bond_cache: Dictionary = (
		bond_cache_raw as Dictionary
		if typeof(bond_cache_raw) == TYPE_DICTIONARY
		else {}
	)
	var cache_key: String = (
		"%d:%d"
		% [
			int(observer.id),
			int(target.id)
		]
	)

	if bond_cache.has(cache_key):
		return clampi(
			int(
				bond_cache.get(
					cache_key,
					0
				)
			),
			0,
			100
		)

	var resolved_bond: int = -1


	if (
		gs != null
		and gs.relationship_graph_contract_engine != null
		and gs.relationship_graph_contract_engine.has_method(
			"human_entity_id"
		)
		and gs.relationship_graph_contract_engine.has_method(
			"bond_for_pair"
		)
	):
		var observer_entity_id: String = str(
			gs.relationship_graph_contract_engine.human_entity_id(
				observer
			)
		)
		var target_entity_id: String = str(
			gs.relationship_graph_contract_engine.human_entity_id(
				target
			)
		)

		resolved_bond = int(
			gs.relationship_graph_contract_engine.bond_for_pair(
				observer_entity_id,
				target_entity_id,
				-1
			)
		)



	if (
		resolved_bond < 0
		and typeof(observer.affection) == TYPE_DICTIONARY
		and observer.affection.has(int(target.id))
	):
		resolved_bond = int(
			observer.affection.get(
				int(target.id),
				0
			)
		)




	if (
		resolved_bond < 0
		and gs != null
		and gs.relationship_engine != null
		and gs.relationship_engine.has_method(
			"observe_pair_relationship_baseline"
		)
	):
		resolved_bond = int(
			gs.relationship_engine.observe_pair_relationship_baseline(
				observer,
				target
			)
		)



	if resolved_bond < 0:
		var stable_material: String = (
			"%d:%d:%s:%s:relationship_projection"
			% [
				int(observer.id),
				int(target.id),
				str(observer.first_name),
				str(target.first_name)
			]
		)
		var stable_hash: int = int(hash(stable_material))

		if stable_hash < 0:
			stable_hash = - stable_hash

		resolved_bond = 35 + int(stable_hash % 46)

	resolved_bond = clampi(
		resolved_bond,
		0,
		100
	)

	bond_cache [cache_key] = resolved_bond
	context ["projection_bond_cache"] = bond_cache

	return resolved_bond

func _relationship_climate_contract_read_only(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	var ids: Array = _clean_unique_ids(
		_immediate_family_ids(
			actor
		),
		[]
	)
	var partner: Person = _valid_partner(
		actor
	)

	if partner != null:
		ids.append(
			int(
				partner.id
			)
		)

	ids.append_array(
		_safe_person_id_array(
			actor,
			"friends"
		)
	)
	ids = _clean_unique_ids(
		ids,
		[]
	)

	var total: int = 0
	var count: int = 0

	for raw_id in ids:
		var target: Person = _person_by_id(
			int(
				raw_id
			)
		)

		if target == null:
			continue

		total += _projection_bond_score_for_pair(
			actor,
			target,
			context
		)
		count += 1

	var score: int = (
		50
		if count <= 0
		else clampi(
			int(
				round(
					float(
						total
					) / float(
						count
					)
				)
			),
			0,
			100
		)
	)
	var climate_name: String = "Mixed"

	if score >= 80:
		climate_name = "Deeply Connected"
	elif score >= 65:
		climate_name = "Warm"
	elif score >= 45:
		climate_name = "Mixed"
	elif score >= 25:
		climate_name = "Strained"
	else:
		climate_name = "Hostile"

	return {
		"score": score,
		"state": (
			climate_name
			.to_lower()
			.replace(
				" ",
				"_"
			)
		),
		"label": (
			"Climate: %s · %d"
			% [
				climate_name,
				score
			]
		),
		"sample_size": count,
		"projection_read_only": true,
		"simulation_mutation_performed": false,
		"ui_is_renderer_only": true
	}
func resolve_intent(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	if actor == null:
		return _fail(
			"missing_actor",
			payload
		)

	var action_id: String = str(
		payload.get(
			"action_id",
			"refresh"
		)
	).strip_edges().to_lower()
	if action_id.begins_with(
		"relationship_contract:"
	):
		var target_id: int = int(
			payload.get(
				"target_id",
				-1
			)
		)
		var target: Person = _person_by_id(
			target_id
		)

		if target == null:
			return _fail(
				"relationship_action_target_missing",
				payload
			)

		if (
			gs == null
			or gs.relationship_activities_engine == null
			or not gs.relationship_activities_engine.has_method(
				"resolve_relationship_action"
			)
		):
			return _fail(
				"relationship_action_authority_missing",
				payload
			)

		var result: Dictionary = (
			gs.relationship_activities_engine
			.resolve_relationship_action(
				actor,
				target,
				action_id,
				payload
			)
		)

		return {
			"success": (
				not result.is_empty()
				and bool(
					result.get(
						"success",
						true
					)
				)
			),
			"schema": ENGINE_SCHEMA,
			"version": CONTRACT_VERSION,
			"mode": (
				"relationship_activity_contract_resolved"
			),
			"action_id": action_id,
			"actor_id": int(
				actor.id
			),
			"target_id": target_id,
			"result": result,
			"reality_mutation_authority": (
				"RelationshipActivitiesEngine"
			),
			"ui_is_renderer_only": true
		}
	match action_id:
		"refresh", "open_hub", "change_section", "observe_partial":
			return {
				"success": true,
				"schema": ENGINE_SCHEMA,
				"version": CONTRACT_VERSION,
				"mode": (
					"relationships_hub_projection_refreshed"
				),
				"hub_contract": emit_hub_contract(
					actor,
					{
						"active_section_id": str(
							payload.get(
								"section_id",
								payload.get(
									"active_section_id",
									"family"
								)
							)
						),
						"source": (
							"relationships_hub_contract_engine."
							+ "resolve_intent"
						),
						"force_refresh": bool(
							payload.get(
								"force_refresh",
								false
							)
						)
					}
				),
				"ui_is_renderer_only": true
			}

		"queue_switch_shell_stage", "observe_actor_lens":
			var target_id: int = int(
				payload.get(
					"target_id",
					-1
				)
			)
			var target: Person = _person_by_id(
				target_id
			)

			if target == null:
				return _fail(
					"switch_shell_target_missing",
					payload
				)

			var complete_destination_required: bool = (
				bool(
					payload.get(
						"complete_destination_deck_required",
						false
					)
				)
				or bool(
					payload.get(
						"relationship_profile_visible_packet",
						false
					)
				)
				or bool(
					payload.get(
						"explicit_relationship_profile_observation",
						false
					)
				)
				or bool(
					payload.get(
						"profile_switch_packet_required_before_visible",
						false
					)
				)
			)

			var pointer_core_hot_before_queue: bool = false
			var complete_packet_hot_before_queue: bool = false
			var destination_deck_hot_before_queue: bool = false

			if (
				gs != null
				and typeof(
					gs.scenario_state
				) == TYPE_DICTIONARY
			):
				var packet_cache: Dictionary = _shallow_dictionary(
					gs.scenario_state.get(
						"profile_pointer_packet_by_actor",
						{}
					)
				)
				var resident_packet: Dictionary = _shallow_dictionary(
					packet_cache.get(
						str(target_id),
						{}
					)
				)

				pointer_core_hot_before_queue = (
					_profile_switch_packet_core_hot(
						resident_packet,
						target_id
					)
				)

				var complete_packet: Dictionary = (
					_resident_complete_switch_packet_for_actor(
						target_id
					)
				)
				complete_packet_hot_before_queue = (
					not complete_packet.is_empty()
				)

				destination_deck_hot_before_queue = (
					_resident_switch_main_tab_deck_is_hot_for_actor(
						_resident_switch_main_tab_deck_for_actor(
							target_id
						),
						target_id
					)
				)

			var already_hot: bool = (
				complete_packet_hot_before_queue
				if complete_destination_required
				else pointer_core_hot_before_queue
			)

			if not already_hot:
				var queue_payload: Dictionary = payload.duplicate(false)
				queue_payload [
					"complete_destination_deck_required"
				] = complete_destination_required
				queue_payload [
					"relationship_profile_visible_packet"
				] = complete_destination_required
				queue_payload [
					"explicit_relationship_profile_observation"
				] = complete_destination_required
				queue_payload [
					"allow_pointer_core_only_preparation"
				] = not complete_destination_required
				queue_payload [
					"visible_card_may_not_publish_complete_destination_deck"
				] = not complete_destination_required
				queue_payload [
					"switch_press_build_forbidden"
				] = true
				queue_payload [
					"ready_gate_member"
				] = false
				queue_payload [
					"ui_is_renderer_only"
				] = true

				_queue_switch_shell_stage_for_target(
					target,
					queue_payload
				)

			return {
				"success": true,
				"schema": ENGINE_SCHEMA,
				"version": CONTRACT_VERSION,
				"mode": (
					"switch_shell_stage_queue_acknowledged"
				),
				"actor_id": int(
					actor.id
				),
				"target_id": target_id,
				"pointer_core_hot": pointer_core_hot_before_queue,
				"destination_deck_hot": destination_deck_hot_before_queue,
				"complete_destination_packet_hot": complete_packet_hot_before_queue,
				"complete_destination_deck_required": complete_destination_required,
				"already_hot": already_hot,
				"queued": not already_hot,
				"remaining": (
					switch_destination_upgrade_queue.size()
					+ switch_shell_stage_queue.size()
				),
				"switch_destination_upgrade_remaining": (
					switch_destination_upgrade_queue.size()
				),
				"background_switch_shell_remaining": (
					switch_shell_stage_queue.size()
				),
				"switch_destination_upgrade_pump_armed": (
					switch_destination_upgrade_pump_armed
				),
				"switch_destination_upgrade_service_owner": (
					"RelationshipsHubContractEngine"
				),
				"pointer_core_is_not_completion_authority": true,
				"ready_gate_member": false,
				"ui_is_renderer_only": true
			}
		"flush_switch_shells":
			return flush_switch_shell_stage_queue(
				int(
					payload.get(
						"max_count",
						1
					)
				),
				payload
			)

		_:
			return _fail(
				"unknown_relationships_hub_intent",
				payload
			)

func emit_group_contract(
	actor: Person,
	title_text: String,
	ids: Array,
	empty_text: String = "None",
	options: Dictionary = {},
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	if actor == null:
		return _fail(
			"missing_actor_for_group",
			context
		)

	var section_key: String = _resolve_section_id(
		str(
			options.get(
				"section_key",
				context.get(
					"section_key",
					"family"
				)
			)
		)
	)

	var featured: bool = bool(
		options.get(
			"highlight_cards",
			false
		)
	)

	var columns: int = int(
		options.get(
			"columns",
			0
		)
	)

	var projection_read_only: bool = bool(
		context.get(
			"projection_read_only",
			false
		)
	)
	var resident_projection: bool = bool(
		context.get(
			"resident_projection",
			false
		)
	)

	if columns <= 0:
		columns = 2 if featured else 3

	var clean_ids: Array = _clean_unique_ids(
		ids,
		_array(
			options.get(
				"exclude_ids",
				[]
			)
		)
	)




	var signature: String = _group_signature(
		actor,
		title_text,
		clean_ids,
		options,
		context
	)

	var cached: Dictionary = _shallow_dictionary(
		group_contract_cache.get(
			signature,
			{}
		)
	)

	if not cached.is_empty():
		cached [
			"cache_hit"
		] = true
		cached [
			"requested_at_ms"
		] = int(
			Time.get_ticks_msec()
		)

		last_report = cached.duplicate(false)

		return cached.duplicate(false)

	var sorted_ids: Array = []
	var unresolved_target_ids: Array = []
	var bond_by_target_id: Dictionary = {}

	for raw_id in clean_ids:
		var target_id: int = int(
			raw_id
		)

		if target_id <= 0:
			continue

		var target: Person = _person_by_id(
			target_id
		)

		if target == null:
			unresolved_target_ids.append(
				target_id
			)
			continue

		var bond_value: int = (
			_projection_bond_score_for_pair(
				actor,
				target,
				context
			)
			if projection_read_only
			else bond_score_for_pair(
				actor,
				target
			)
		)

		bond_by_target_id [
			str(
				target_id
			)
		] = bond_value

		sorted_ids.append(
			target_id
		)

	sorted_ids.sort_custom(
		func (
			a: Variant,
			b: Variant
		) -> bool:
			var left_id: int = int(
				a
			)
			var right_id: int = int(
				b
			)
			var left_bond: int = int(
				bond_by_target_id.get(
					str(
						left_id
					),
					0
				)
			)
			var right_bond: int = int(
				bond_by_target_id.get(
					str(
						right_id
					),
					0
				)
			)

			if left_bond == right_bond:
				return left_id < right_id

			return left_bond > right_bond
	)

	var cards: Array = []
	var card_by_id: Dictionary = {}

	for raw_id in sorted_ids:
		var target_id: int = int(
			raw_id
		)

		var target: Person = _person_by_id(
			target_id
		)

		if target == null:
			continue

		var card_context: Dictionary = (
			context.duplicate(false)
		)

		card_context [
			"section_key"
		] = section_key
		card_context [
			"featured"
		] = featured
		card_context [
			"group_title"
		] = title_text
		card_context [
			"group_contract"
		] = true
		card_context [
			"stage_switch_shell"
		] = false
		card_context [
			"queue_switch_shell_stage"
		] = bool(
			options.get(
				"queue_switch_shell_stage",
				false
			)
		)
		card_context [
			"precomputed_bond"
		] = int(
			bond_by_target_id.get(
				str(
					target_id
				),
				50
			)
		)
		card_context [
			"source"
		] = str(
			context.get(
				"source",
				"relationships_hub_contract_engine.emit_group_contract"
			)
		)

		var card_contract: Dictionary = emit_card_contract(
			actor,
			target,
			card_context
		)

		if card_contract.is_empty():
			continue

		cards.append(
			card_contract
		)

		card_by_id [
			str(
				target_id
			)
		] = card_contract.duplicate(false)

	var household_pet_count: int = 0

	if (
		section_key == "household"
		and title_text.strip_edges().to_lower()
		== "household members"
	):
		var household_merge: Dictionary = (
			_merge_household_pet_cards(
				actor,
				cards,
				card_by_id,
				context
			)
		)

		cards = _array(
			household_merge.get(
				"cards",
				cards
			)
		)

		card_by_id = _shallow_dictionary(
			household_merge.get(
				"card_by_id",
				card_by_id
			)
		)

		household_pet_count = int(
			household_merge.get(
				"pet_count",
				0
			)
		)

	var hydration_may_still_publish: bool = (
		_resident_person_hydration_may_still_publish()
	)
	var group_projection_pending: bool = (
		resident_projection
		and projection_read_only
		and not unresolved_target_ids.is_empty()
		and hydration_may_still_publish
	)

	var contract: Dictionary = {
		"success": true,
		"schema": GROUP_CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"row_kind": "relationship_group",
		"actor_id": int(
			actor.id
		),
		"title": title_text,
		"subtitle": str(
			options.get(
				"subtitle",
				""
			)
		),
		"empty_text": (
			"Relationship identities are entering residency."
			if (
				group_projection_pending
				and cards.is_empty()
			)
			else empty_text
		),
		"section_key": section_key,
		"featured": featured,
		"premium": bool(
			options.get(
				"premium",
				false
			)
		),
		"columns": clampi(
			columns,
			1,
			4
		),
		"requested_ids": clean_ids.duplicate(),
		"requested_id_count": clean_ids.size(),
		"ids": sorted_ids.duplicate(),
		"cards": cards,
		"card_by_id": card_by_id,
		"card_count": cards.size(),
		"unresolved_target_ids": (
			unresolved_target_ids.duplicate()
		),
		"unresolved_target_count": (
			unresolved_target_ids.size()
		),
		"projection_pending": group_projection_pending,
		"projection_complete": (
			not group_projection_pending
		),
		"truth_state": (
			"streaming"
			if group_projection_pending
			else "hot"
		),
		"cacheable_terminal_contract": (
			not group_projection_pending
		),
		"hydration_may_still_publish": (
			hydration_may_still_publish
		),
		"household_pet_count": household_pet_count,
		"household_pets_embedded_under_owner": (
			household_pet_count > 0
		),
		"projection_read_only": projection_read_only,
		"simulation_mutation_performed": false,
		"signature": signature,
		"created_at_ms": int(
			Time.get_ticks_msec()
		),
		"cache_hit": false,
		"ui_is_renderer_only": true
	}




	if not group_projection_pending:
		_store_group_contract(
			signature,
			contract
		)

	last_report = contract.duplicate(false)

	return contract.duplicate(false)
func _merge_household_pet_cards(
	actor: Person,
	person_cards: Array,
	card_by_id: Dictionary,
	context: Dictionary
) -> Dictionary:
	var household_context: Dictionary = (
		context.duplicate(false)
	)

	household_context [
		"household_embedding"
	] = true
	household_context [
		"section_key"
	] = "household"
	household_context [
		"projection_read_only"
	] = true

	var pet_group: Dictionary = (
		_pet_group_contract(
			actor,
			household_context
		)
	)

	var pet_cards: Array = _array(
		pet_group.get(
			"cards",
			[]
		)
	)

	if pet_cards.is_empty():
		return {
			"cards": person_cards,
			"card_by_id": card_by_id,
			"pet_count": 0
		}

	var pets_by_owner: Dictionary = {}

	for raw_pet_card in pet_cards:
		var pet_card: Dictionary = _shallow_dictionary(
			raw_pet_card
		)

		if pet_card.is_empty():
			continue

		var owner_person_id: int = int(
			pet_card.get(
				"owner_person_id",
				-1
			)
		)

		var owner_key: String = str(
			owner_person_id
		)

		var owner_bucket: Array = _array(
			pets_by_owner.get(
				owner_key,
				[]
			)
		).duplicate(false)

		owner_bucket.append(
			pet_card.duplicate(false)
		)

		pets_by_owner [
			owner_key
		] = owner_bucket

	var merged_cards: Array = []
	var consumed_pet_ids: Dictionary = {}

	for raw_person_card in person_cards:
		var person_card: Dictionary = _shallow_dictionary(
			raw_person_card
		)

		if person_card.is_empty():
			continue

		merged_cards.append(
			person_card
		)

		var person_id: int = int(
			person_card.get(
				"target_id",
				person_card.get(
					"person_id",
					-1
				)
			)
		)

		var owned_pets: Array = _array(
			pets_by_owner.get(
				str(
					person_id
				),
				[]
			)
		)

		for raw_owned_pet in owned_pets:
			var owned_pet: Dictionary = _shallow_dictionary(
				raw_owned_pet
			)

			if owned_pet.is_empty():
				continue

			var pet_entity_id: String = str(
				owned_pet.get(
					"target_entity_id",
					""
				)
			).strip_edges()

			if (
				pet_entity_id != ""
				and consumed_pet_ids.has(
					pet_entity_id
				)
			):
				continue

			merged_cards.append(
				owned_pet
			)

			if pet_entity_id != "":
				consumed_pet_ids [
					pet_entity_id
				] = true

	for raw_pet_card in pet_cards:
		var pet_card: Dictionary = _shallow_dictionary(
			raw_pet_card
		)

		if pet_card.is_empty():
			continue

		var pet_entity_id: String = str(
			pet_card.get(
				"target_entity_id",
				""
			)
		).strip_edges()

		if (
			pet_entity_id != ""
			and consumed_pet_ids.has(
				pet_entity_id
			)
		):
			continue

		merged_cards.append(
			pet_card
		)

		if pet_entity_id != "":
			consumed_pet_ids [
				pet_entity_id
			] = true

	var merged_card_by_id: Dictionary = (
		card_by_id.duplicate(false)
	)

	for raw_pet_card in pet_cards:
		var pet_card: Dictionary = _shallow_dictionary(
			raw_pet_card
		)

		var pet_entity_id: String = str(
			pet_card.get(
				"target_entity_id",
				""
			)
		).strip_edges()

		if pet_entity_id == "":
			continue

		merged_card_by_id [
			pet_entity_id
		] = pet_card.duplicate(false)

	return {
		"cards": merged_cards,
		"card_by_id": merged_card_by_id,
		"pet_count": pet_cards.size(),
	}
func emit_card_contract(
	actor: Person,
	target: Person,
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	if actor == null or target == null:
		return _fail(
			"missing_actor_or_target_for_card",
			context
		)

	var section_key: String = _resolve_section_id(
		str(
			context.get(
				"section_key",
				"family"
			)
		)
	)
	var featured: bool = bool(
		context.get(
			"featured",
			false
		)
	)
	var target_id: int = int(
		target.id
	)
	var actor_id: int = int(
		actor.id
	)
	var is_self: bool = actor_id == target_id
	var target_is_switchable: bool = (
		not is_self
		and bool(target.alive)
		and float(target.health) > 0.0
	)
	var signature: String = _card_signature(
		actor,
		target,
		section_key,
		featured,
		context
	)
	var cached: Dictionary = _shallow_dictionary(
		card_contract_cache.get(
			signature,
			{}
		)
	)




	if not cached.is_empty():
		if (
			target_is_switchable
			and not _context_forbids_switch_packet_resolution(
				context
			)
		):
			var cached_complete_packet: Dictionary = (
				_resident_complete_switch_packet_for_actor(
					target_id
				)
			)
			var cached_switch_packet: Dictionary = _shallow_dictionary(
				cached.get(
					"switch_packet",
					{}
				)
			)

			if cached_switch_packet.is_empty():
				cached_switch_packet = cached_complete_packet

			var cached_surface: Dictionary = _shallow_dictionary(
				cached_switch_packet.get(
					"surface_contract",
					{}
				)
			)
			var cached_main_tab_deck: Dictionary = _shallow_dictionary(
				cached_switch_packet.get(
					"main_tab_surface_contracts",
					cached_surface.get(
						"main_tab_surface_contracts",
						{}
					)
				)
			)
			var cached_support_packet: Dictionary = _shallow_dictionary(
				cached_switch_packet.get(
					"control_switch_support_surface_packet",
					cached_surface.get(
						"control_switch_support_surface_packet",
						{}
					)
				)
			)
			var cached_switch_ready: bool = (
				int(
					cached_switch_packet.get(
						"actor_id",
						-1
					)
				) == target_id
				and int(
					cached_surface.get(
						"actor_id",
						-1
					)
				) == target_id
				and _resident_switch_main_tab_deck_is_hot_for_actor(
					cached_main_tab_deck,
					target_id
				)
				and not cached_support_packet.is_empty()
			)

			if cached_switch_ready:
				cached [
					"switch_packet"
				] = cached_switch_packet.duplicate(false)
				cached [
					"switch_destination_queue_considered"
				] = false
				cached [
					"switch_destination_reused_existing_packet"
				] = true
			else:
				var cached_queue_context: Dictionary = (
					context.duplicate(false)
				)
				cached_queue_context [
					"source"
				] = (
					"relationships_hub_contract_engine."
					+ "emit_card_contract.cache_hit_pointer_core_queue"
				)
				cached_queue_context [
					"card_signature"
				] = signature
				cached_queue_context [
					"pointer_revision"
				] = str(
					cached_switch_packet.get(
						"pointer_revision",
						cached_surface.get(
							"pointer_revision",
							""
						)
					)
				).strip_edges()
				cached_queue_context [
					"relationship_card_surface_only"
				] = true
				cached_queue_context [
					"visible_card_may_not_publish_complete_destination_deck"
				] = true
				cached_queue_context [
					"complete_destination_deck_required"
				] = false
				cached_queue_context [
					"relationship_profile_visible_packet"
				] = false
				cached_queue_context [
					"allow_pointer_core_only_preparation"
				] = true
				cached_queue_context [
					"continuous_destination_preparation"
				] = true
				cached_queue_context [
					"switch_press_build_forbidden"
				] = true
				cached_queue_context [
					"ready_gate_member"
				] = false
				cached_queue_context [
					"ui_is_renderer_only"
				] = true

				_queue_switch_shell_stage_for_target(
					target,
					cached_queue_context
				)

				cached [
					"switch_destination_queue_considered"
				] = true
				cached [
					"switch_destination_queue_kind"
				] = "pointer_core_only"
				cached [
					"relationship_card_may_publish_complete_destination_deck"
				] = false

		cached ["cache_hit"] = true
		cached ["requested_at_ms"] = int(
			Time.get_ticks_msec()
		)
		last_report = cached.duplicate(false)

		return cached.duplicate(false)

	var projection_read_only: bool = bool(
		context.get(
			"projection_read_only",
			false
		)
	)
	var resident_projection: bool = bool(
		context.get(
			"resident_projection",
			false
		)
	)
	var bond_value: int = int(
		context.get(
			"precomputed_bond",
			-1
		)
	)

	if bond_value < 0:
		bond_value = (
			_projection_bond_score_for_pair(
				actor,
				target,
				context
			)
			if projection_read_only
			else bond_score_for_pair(
				actor,
				target
			)
		)

	var health_max: int = maxi(
		1,
		_health_base_display_max(
			int(
				round(
					float(target.health)
				)
			)
		)
	)
	var health_value: int = clampi(
		int(
			round(
				float(target.health)
			)
		),
		0,
		health_max
	)
	var state_name: String = _card_state_for(
		actor,
		target,
		bond_value
	)
	var role_text: String = (
		"You"
		if is_self
		else _relationship_label_for_pair(
			actor,
			target
		)
	)

	if role_text == "Stranger":
		role_text = ""

	var target_name: String = _actor_display_name(
		target
	)
	var target_name_with_age: String = (
		_relationship_display_name_with_age(
			target
		)
	)
	var switch_shell: Dictionary = {}
	var staged_viewer_packet: Dictionary = {}
	var switch_ready: bool = false
	var card_switch_queue_context: Dictionary = {}

	if target_is_switchable:
		staged_viewer_packet = (
			_resident_complete_switch_packet_for_actor(
				target_id
			)
		)

		if (
			staged_viewer_packet.is_empty()
			and not _context_forbids_switch_packet_resolution(
				context
			)
		):
			card_switch_queue_context = (
				context.duplicate(false)
			)
			card_switch_queue_context [
				"source"
			] = (
				"relationships_hub_contract_engine."
				+ "emit_card_contract.visible_card_pointer_core_queue"
			)
			card_switch_queue_context [
				"card_signature"
			] = signature
			card_switch_queue_context [
				"relationship_card_surface_only"
			] = true
			card_switch_queue_context [
				"visible_card_may_not_publish_complete_destination_deck"
			] = true
			card_switch_queue_context [
				"complete_destination_deck_required"
			] = false
			card_switch_queue_context [
				"relationship_profile_visible_packet"
			] = false
			card_switch_queue_context [
				"allow_pointer_core_only_preparation"
			] = true
			card_switch_queue_context [
				"continuous_destination_preparation"
			] = true
			card_switch_queue_context [
				"switch_press_build_forbidden"
			] = true
			card_switch_queue_context [
				"ready_gate_member"
			] = false
			card_switch_queue_context [
				"ui_is_renderer_only"
			] = true

			_queue_switch_shell_stage_for_target(
				target,
				card_switch_queue_context
			)

		var staged_surface: Dictionary = _shallow_dictionary(
			staged_viewer_packet.get(
				"surface_contract",
				{}
			)
		)
		var staged_main_tab_deck: Dictionary = _shallow_dictionary(
			staged_viewer_packet.get(
				"main_tab_surface_contracts",
				staged_surface.get(
					"main_tab_surface_contracts",
					{}
				)
			)
		)
		var staged_support_packet: Dictionary = _shallow_dictionary(
			staged_viewer_packet.get(
				"control_switch_support_surface_packet",
				staged_surface.get(
					"control_switch_support_surface_packet",
					{}
				)
			)
		)

		switch_ready = (
			int(
				staged_viewer_packet.get(
					"actor_id",
					-1
				)
			) == target_id
			and int(
				staged_surface.get(
					"actor_id",
					-1
				)
			) == target_id
			and _resident_switch_main_tab_deck_is_hot_for_actor(
				staged_main_tab_deck,
				target_id
			)
			and not staged_support_packet.is_empty()
		)

	var style_contract: Dictionary = (
		_card_visual_surface_contract(
			state_name,
			featured,
			section_key,
			bond_value
		)
	)
	var profile_context: Dictionary = (
		context.duplicate(false)
	)

	profile_context ["source"] = (
		"relationships_hub_card_contract"
	)
	profile_context ["section_key"] = section_key
	profile_context ["card_signature"] = signature
	profile_context ["bond"] = bond_value
	profile_context ["health"] = health_value
	profile_context ["health_max"] = health_max
	profile_context ["relationship_role"] = role_text
	profile_context ["relationship_state"] = state_name
	profile_context ["switch_packet"] = (
		staged_viewer_packet.duplicate(false)
		if switch_ready
		else {}
	)
	profile_context [
		"switch_packet_core_hot"
	] = switch_ready
	profile_context [
		"visible_card_switch_destination_required"
	] = target_is_switchable
	profile_context [
		"relationship_card_surface_only"
	] = true
	profile_context [
		"relationship_card_switch_packets_forbidden"
	] = true
	profile_context [
		"profile_switch_packet_resolution_forbidden"
	] = true
	profile_context [
		"switch_shell_stage_forbidden"
	] = true
	profile_context [
		"visible_card_may_not_publish_complete_destination_deck"
	] = true
	profile_context [
		"complete_destination_deck_required"
	] = false

	var profile_contract: Dictionary = (
		emit_profile_contract(
			actor,
			target,
			profile_context
		)
	)
	var surface_context: Dictionary = {
		"schema": "eralife.relationships_hub.card_surface_context",
		"version": 2,
		"surface_family": "relationship_hub_panel",
		"hub": "relationships",
		"actor_id": actor_id,
		"actor_name": _actor_display_name(actor),
		"target_id": target_id,
		"target_name": target_name,
		"target_name_with_age": target_name_with_age,
		"target_age": int(target.age),
		"relationship_role": role_text,
		"relationship_state": state_name,
		"relationship_bond": bond_value,
		"section_key": section_key,
		"featured": featured,
		"narrative_perspective": "third_person",
		"descriptor_title_mode": "bond_pov",
		"relationship_card_stat_header_mode": (
			"centered_label_descriptor_subtext"
		),
		"relationship_card_labels_are_contract_owned": true,
		"ui_is_renderer_only": true
	}
	var contract: Dictionary = {
		"success": true,
		"schema": CARD_CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"actor_id": actor_id,
		"actor_name": _actor_display_name(actor),
		"target_id": target_id,
		"target_name": target_name,
		"target_name_with_age": target_name_with_age,
		"target_age": int(target.age),
		"role": role_text,
		"relationship_type": role_text,
		"bond": bond_value,
		"health": health_value,
		"health_max": health_max,
		"state": state_name,
		"is_self": is_self,
		"featured": featured,
		"section_key": section_key,
		"profile_contract": profile_contract.duplicate(false),
		"card_minimum_height": (
			146
			if is_self
			else (
				226
				if featured
				else 194
			)
		),
		"surface_context": surface_context.duplicate(false),
		"surface_contract": {
			"card_title": target_name_with_age,
			"raw_card_title": target_name,
			"subtitle": "You" if is_self else role_text,
			"relationship_role": role_text,
			"target_age": int(target.age),
			"bond_label": "BOND",
			"health_label": "HEALTH",
			"bond_value": bond_value,
			"health_value": health_value,
			"health_max": health_max,
			"state": state_name,
			"featured": featured,
			"section_key": section_key,
			"glow_intensity": clampf(
				float(bond_value) / 100.0,
				0.0,
				1.0
			),
			"pulse_mode": _pulse_mode_for_state(
				state_name,
				bond_value
			),
			"color_signature": style_contract.duplicate(false),
			"button_text": "Open full relationship profile",
			"numbers_live_inside_bars_only": true
		},
		"dynamic_state": {
			"conflict": state_name == "conflict",
			"strained": state_name == "strained",
			"warm": state_name == "warm",
			"self": is_self,
			"drift": false,
			"attachment_style": _attachment_style_for_bond(
				bond_value
			)
		},
		"interaction_contract": {
			"can_open_profile": not is_self,
			"can_switch": (
				target_is_switchable
				and switch_ready
			),
			"switch_shell_ready": switch_ready,
			"switch_destination_queued": (
				target_is_switchable
				and not switch_ready
			),
			"visible_card_switch_destination_required": (
				target_is_switchable
			),
			"actions": (
				["open_full_relationship_profile"]
				if is_self
				else (
					[
						"open_full_relationship_profile",
						"switch_to_character"
					]
					if switch_ready
					else [
						"open_full_relationship_profile"
					]
				)
			)
		},
		"prewarmed_shell": {},
		"switch_packet_reference": {
			"actor_id": target_id,
			"pointer_revision": str(
				staged_viewer_packet.get(
					"pointer_revision",
					""
				)
			),
			"complete_destination_packet_hot": switch_ready,
			"relationship_card_may_publish_complete_destination_deck": false,
			"pointer_core_queue_requested": (
				target_is_switchable
				and not card_switch_queue_context.is_empty()
			),
			"ui_is_renderer_only": true
		},
		"render_policy": {
			"ui_is_pure_renderer": true,
			"switch_shell_precomputed": switch_ready,
			"switch_destination_queued_automatically": (
				target_is_switchable
				and not switch_ready
			),
			"switch_destination_queue_kind": (
				"pointer_core_only"
				if target_is_switchable and not switch_ready
				else "none"
			),
		},
		"signature": signature,
		"created_at_ms": int(
			Time.get_ticks_msec()
		),
		"cache_hit": false,
		"ui_is_renderer_only": true
	}

	_store_card_contract(
		signature,
		contract
	)

	if (
		not resident_projection
		or bool(
			context.get(
				"publish_card_shell_to_scenario",
				false
			)
		)
	):
		_publish_card_shell_to_scenario(
			target_id,
			switch_shell,
			contract
		)

	last_report = contract.duplicate(false)

	return contract.duplicate(false)
func emit_external_resident_profile_contract(
	observer: Person,
	target: Person,
	context: Dictionary = {}
) -> Dictionary:
	if (
		observer == null
		or target == null
	):
		return {}

	var projection_context: Dictionary = (
		context.duplicate(false)
	)

	projection_context [
		"source"
	] = str(
		projection_context.get(
			"source",
			(
				"relationships_hub_contract_engine."
				+ "external_resident_profile_projection"
			)
		)
	)

	projection_context [
		"projection_read_only"
	] = true
	projection_context [
		"relationship_card_switch_packets_forbidden"
	] = true
	projection_context [
		"profile_switch_packet_resolution_forbidden"
	] = true
	projection_context [
		"switch_shell_stage_forbidden"
	] = true
	projection_context [
		"complete_destination_deck_required"
	] = false
	projection_context [
		"build_on_click_forbidden"
	] = true
	projection_context [
		"ready_gate_member"
	] = false
	projection_context [
		"ui_is_renderer_only"
	] = true

	var profile_contract: Dictionary = (
		emit_profile_contract(
			observer,
			target,
			projection_context
		)
	)

	if profile_contract.is_empty():
		return {}

	profile_contract [
		"external_surface_profile_projection"
	] = true
	profile_contract [
		"switch_packet_preparation_deferred"
	] = true
	profile_contract [
		"profile_click_build_required"
	] = false

	return profile_contract
func _profile_switch_packet_core_hot(
	packet: Dictionary,
	target_id: int
) -> bool:
	if (
		packet.is_empty()
		or target_id <= 0
	):
		return false

	var packet_surface_raw: Variant = packet.get(
		"surface_contract",
		{}
	)
	var packet_surface: Dictionary = (
		(packet_surface_raw as Dictionary).duplicate(false)
		if typeof(packet_surface_raw) == TYPE_DICTIONARY
		else {}
	)
	var observable_revision: String = str(
		packet.get(
			"pointer_revision",
			packet_surface.get(
				"pointer_revision",
				""
			)
		)
	).strip_edges()

	var switch_authority = switch_engine

	if (
		switch_authority == null
		and gs != null
		and gs.universal_switch_contract_engine != null
	):
		switch_authority = gs.universal_switch_contract_engine

	if (
		switch_authority != null
		and switch_authority.has_method(
			"_profile_switch_core_packet_truth"
		)
	):
		var core_truth: Dictionary = _shallow_dictionary(
			switch_authority._profile_switch_core_packet_truth(
				packet,
				target_id
			)
		)
		var core_hot: bool = bool(
			core_truth.get(
				"core_packet_hot",
				false
			)
		)
		var viewpoint_pointer_hot: bool = bool(
			core_truth.get(
				"viewpoint_pointer_hot",
				false
			)
		)
		var authority_support_deck_hot: bool = bool(
			core_truth.get(
				"support_main_tab_deck_hot",
				false
			)
		)
		var support_blocks_switch: bool = bool(
			core_truth.get(
				"switch_commit_blocked_by_support_deck",
				false
			)
		)

		_trace_profile_packet_observable_once(
			target_id,
			observable_revision,
			core_hot,
			viewpoint_pointer_hot,
			authority_support_deck_hot,
			support_blocks_switch,
			"UniversalSwitchContractEngine"
		)

		return core_hot

	var surface: Dictionary = packet_surface
	var packet_revision: String = observable_revision
	var surface_revision: String = str(
		surface.get(
			"pointer_revision",
			""
		)
	).strip_edges()
	var pointer_only_packet: bool = bool(
		packet.get(
			"pointer_only_profile_packet",
			surface.get(
				"pointer_only",
				false
			)
		)
	)
	var press_frame_lens_cache: Dictionary = _shallow_dictionary(
		packet.get(
			"press_frame_lens_cache",
			surface.get(
				"press_frame_lens_cache",
				{}
			)
		)
	)
	var diary_lines: Array = _shallow_array(
		packet.get(
			"life_diary_lines",
			surface.get(
				"life_diary_lines",
				[]
			)
		)
	)
	var diary_signature: String = str(
		packet.get(
			"life_diary_signature",
			surface.get(
				"life_diary_signature",
				""
			)
		)
	).strip_edges()

	var pointer_core_hot: bool = (
		not surface.is_empty()
		and int(
			packet.get(
				"actor_id",
				-1
			)
		) == target_id
		and int(
			surface.get(
				"actor_id",
				-1
			)
		) == target_id
		and packet_revision != ""
		and packet_revision == surface_revision
		and bool(
			packet.get(
				"press_frame_build_forbidden",
				true
			)
		)
		and (
			press_frame_lens_cache.is_empty()
			or int(
				press_frame_lens_cache.get(
					"actor_id",
					target_id
				)
			) == target_id
		)
		and (
			pointer_only_packet
			or not diary_lines.is_empty()
			or diary_signature != ""
		)
	)
	var fallback_support_deck_hot: bool = bool(
		packet.get(
			"main_tab_surface_deck_hot",
			surface.get(
				"main_tab_surface_deck_hot",
				false
			)
		)
	)

	_trace_profile_packet_observable_once(
		target_id,
		packet_revision,
		pointer_core_hot,
		pointer_core_hot,
		fallback_support_deck_hot,
		false,
		"fallback_pointer_validator"
	)

	return pointer_core_hot
func _trace_profile_packet_observable_once(
	target_id: int,
	pointer_revision: String,
	core_hot: bool,
	viewpoint_pointer_hot: bool,
	support_deck_hot: bool,
	support_blocks_switch: bool,
	authority: String
) -> void:
	var observable_signature: String = (
		"%d::%s::%s::%s::%s::%s::%s"
		% [
			target_id,
			pointer_revision,
			str(core_hot),
			str(viewpoint_pointer_hot),
			str(support_deck_hot),
			str(support_blocks_switch),
			authority
		]
	)
	var registry_raw: Variant = get_meta(
		"profile_packet_observable_signature_by_actor",
		{}
	)
	var registry: Dictionary = (
		(registry_raw as Dictionary).duplicate(false)
		if typeof(registry_raw) == TYPE_DICTIONARY
		else {}
	)
	var actor_key: String = str(
		target_id
	)

	if str(
		registry.get(
			actor_key,
			""
		)
	) == observable_signature:
		return

	registry [
		actor_key
	] = observable_signature

	set_meta(
		"profile_packet_observable_signature_by_actor",
		registry
	)

	EraLog.truth(
		"PROFILE_PACKET_OBSERVABLE"
		+ "|actor_id=" + str(target_id)
		+ "|pointer_revision=" + pointer_revision
		+ "|core_hot=" + str(core_hot).to_lower()
		+ "|viewpoint_pointer_hot="
		+ str(viewpoint_pointer_hot).to_lower()
		+ "|support_deck_hot="
		+ str(support_deck_hot).to_lower()
		+ "|support_blocks_switch="
		+ str(support_blocks_switch).to_lower()
		+ "|authority=" + authority
		+ "|duplicate_observation_log_suppressed=true"
		+ "|at_ms=" + str(Time.get_ticks_msec())
	)
func _person_snapshot_value(
	target: Person,
	keys: Array,
	default_value = null
):
	if target == null:
		return default_value

	for raw_key in keys:
		var clean_key: String = str(
			raw_key
		).strip_edges()

		if clean_key == "":
			continue

		if clean_key in target:
			var value = target.get(
				clean_key
			)

			if value != null:
				return value

	return default_value


func _person_snapshot_int(
	target: Person,
	keys: Array,
	default_value: int = 0
) -> int:
	var value = _person_snapshot_value(
		target,
		keys,
		default_value
	)

	if value == null:
		return default_value

	return int(
		value
	)


func _person_snapshot_string(
	target: Person,
	keys: Array,
	default_value: String = ""
) -> String:
	var value = _person_snapshot_value(
		target,
		keys,
		default_value
	)

	if value == null:
		return default_value

	return str(
		value
	)
func _modification_contract_for_target(
	target: Person,
	context: Dictionary = {}
) -> Dictionary:
	if (
		gs == null
		or target == null
		or int(target.id) <= 0
	):
		return {}

	var target_id: int = int(
		target.id
	)
	var source: String = str(
		context.get(
			"source",
			"relationships_hub_contract_engine.profile_modification"
		)
	)
	var surface_contract: Dictionary = {}

	if gs.live_person_editor_engine == null:
		gs.live_person_editor_engine = (
			LivePersonEditorEngine.new(
				gs
			)
		)

	if (
		gs.live_person_editor_engine != null
		and gs.live_person_editor_engine.has_method(
			"bind_game_state"
		)
	):
		gs.live_person_editor_engine.bind_game_state(
			gs
		)

	if (
		gs.live_person_editor_engine != null
		and gs.live_person_editor_engine.has_method(
			"emit_modification_surface_contract"
		)
	):
		var report: Dictionary = _shallow_dictionary(
			gs.live_person_editor_engine.emit_modification_surface_contract(
				target,
				{
					"source": source,
					"target_id": target_id,
					"prewarm_only": true,
					"read_only": true,
					"visible_click_work_forbidden": true,
					"ready_gate_member": false,
					"ui_is_renderer_only": true
				}
			)
		)
		surface_contract = _shallow_dictionary(
			report.get(
				"surface_contract",
				report.get(
					"open_contract",
					{}
				)
			)
		)

	if surface_contract.is_empty():
		var first_name: String = _person_snapshot_string(
			target,
			[
				"first_name"
			],
			""
		)
		var last_name: String = _person_snapshot_string(
			target,
			[
				"last_name"
			],
			""
		)
		var actor_name: String = (
			"%s %s"
			% [
				first_name,
				last_name
			]
		).strip_edges()

		if actor_name == "":
			actor_name = "Entity %d" % target_id

		var health_value: int = _person_snapshot_int(
			target,
			[
				"health"
			],
			100
		)
		var mental_value: int = _person_snapshot_int(
			target,
			[
				"mental_health",
				"mental"
			],
			100
		)

		surface_contract = {
			"success": true,
			"schema": "eralife.modification.surface_contract",
			"version": CONTRACT_VERSION,
			"actor_id": target_id,
			"target_id": target_id,
			"actor_name": actor_name,
			"title": "MODIFY • %s" % actor_name.to_upper(),
			"snapshot": {
				"actor_id": target_id,
				"actor_name": actor_name,
				"first_name": first_name,
				"last_name": last_name,
				"bank_balance": _person_snapshot_int(
					target,
					[
						"bank_balance",
						"money",
						"cash"
					],
					0
				),
				"happiness": _person_snapshot_int(
					target,
					[
						"happiness",
						"happy",
						"morale",
						"life_satisfaction"
					],
					mental_value
				),
				"health": health_value,
				"hunger": _person_snapshot_int(
					target,
					[
						"hunger"
					],
					0
				),
				"smarts": _person_snapshot_int(
					target,
					[
						"smarts",
						"intelligence"
					],
					50
				),
				"looks": _person_snapshot_int(
					target,
					[
						"looks",
						"appearance"
					],
					50
				),
				"mental_health": mental_value,
				"willpower": _person_snapshot_int(
					target,
					[
						"willpower"
					],
					0
				),
				"imagination": _person_snapshot_int(
					target,
					[
						"imagination"
					],
					0
				),
				"fame": _person_snapshot_int(
					target,
					[
						"fame"
					],
					0
				),
				"fertility": _person_snapshot_int(
					target,
					[
						"fertility"
					],
					0
				)
			},
			"relationship_profile_modification_contract": true,
			"visible_click_work_forbidden": true,
			"ready_gate_member": false,
			"ui_is_renderer_only": true,
			"created_at_ms": int(
				Time.get_ticks_msec()
			)
		}

	if (
		int(
			surface_contract.get(
				"actor_id",
				-1
			)
		) != target_id
	):
		return {}

	surface_contract [
		"relationship_profile_modification_contract"
	] = true
	surface_contract [
		"visible_click_work_forbidden"
	] = true
	surface_contract [
		"ready_gate_member"
	] = false
	surface_contract [
		"ui_is_renderer_only"
	] = true

	return surface_contract
func _profile_stat_phrase_third_person(text: String) -> String:
	var out: String = str(text).strip_edges()

	if out == "":
		return out

	var replacements: Array = [
		["Your ", "Their "],
		["your ", "their "],
		["your.", "their."],
		["your,", "their,"],
		["your!", "their!"],
		["your?", "their?"],
		["You are ", "They are "],
		["You feel ", "They feel "],
		["You can ", "They can "],
		["You look ", "They look "],
		["You process ", "They process "],
		["You think ", "They think "],
		["You carry ", "They carry "],
		["You ", "They "],
		[" you are ", " they are "],
		[" you feel ", " they feel "],
		[" you can ", " they can "],
		[" you look ", " they look "],
		[" you process ", " they process "],
		[" you think ", " they think "],
		[" you carry ", " they carry "],
		[" you do.", " they do."],
		[" you do,", " they do,"],
		[" whether you ", " whether they "],
		[" when you ", " when they "],
		[" if you ", " if they "],
		[" before you ", " before they "],
		[" while you ", " while they "],
		[" know you,", " know them,"],
		[" know you.", " know them."],
		[" toward you", " toward them"],
		[" away from you", " away from them"],
		[" around you", " around them"],
		[" under you", " under them"],
		[" above you", " above them"],
		[" beside you", " beside them"],
		[" with you", " with them"],
		[" for you", " for them"],
		[" from you", " from them"],
		[" to you", " to them"]
	]

	for pair in replacements:
		if pair.size() < 2:
			continue

		out = out.replace(
			str(pair [0]),
			str(pair [1])
		)

	return out


func _profile_bond_descriptor_for_ratio(ratio: float) -> String:
	var safe_ratio: float = clampf(
		float(ratio),
		0.0,
		1.0
	)

	if safe_ratio >= 0.85:
		return "Devoted"
	elif safe_ratio >= 0.7:
		return "Warm"
	elif safe_ratio >= 0.5:
		return "Open"
	elif safe_ratio >= 0.3:
		return "Guarded"
	elif safe_ratio >= 0.15:
		return "Cold"

	return "Hostile"


func _profile_bond_flavor_for_descriptor(
	descriptor: String,
	posthumous: bool
) -> String:
	var clean_descriptor: String = str(
		descriptor
	).strip_edges()

	if posthumous:
		match clean_descriptor:
			"Devoted":
				return (
					"They trusted you deeply and felt safest when "
					+ "they were close to you."
				)
			"Warm":
				return (
					"They felt genuinely close to you and usually read "
					+ "you as safe, welcome company."
				)
			"Open":
				return (
					"They were comfortable around you, even if some "
					+ "emotional distance was still there."
				)
			"Guarded":
				return (
					"They recognized you, but they were still protecting "
					+ "part of themselves around you."
				)
			"Cold":
				return (
					"They did not feel fully settled around you and kept "
					+ "their trust pulled back."
				)
			"Hostile":
				return (
					"They felt tense around you and would rather keep "
					+ "distance than closeness."
				)

		return (
			"Their relationship with you ended with unresolved "
			+ "emotional distance."
		)

	match clean_descriptor:
		"Devoted":
			return (
				"They trust you deeply and feel safest when they "
				+ "are close to you."
			)
		"Warm":
			return (
				"They feel genuinely close to you and usually read "
				+ "you as safe, welcome company."
			)
		"Open":
			return (
				"They are comfortable around you, even if some "
				+ "emotional distance is still there."
			)
		"Guarded":
			return (
				"They recognize you, but they are still protecting "
				+ "part of themselves around you."
			)
		"Cold":
			return (
				"They do not feel fully settled around you and keep "
				+ "their trust pulled back."
			)
		"Hostile":
			return (
				"They feel tense around you and would rather keep "
				+ "distance than closeness."
			)

	return ""


func _profile_death_year_label(target: Person) -> String:
	if target == null:
		return "an unknown year"

	var death_year: int = -999999

	if "death_year" in target:
		death_year = int(
			target.death_year
		)


	if (
		death_year <= -999000
		and gs != null
	):
		death_year = int(
			gs.year
		)

	if death_year <= -999000:
		return "an unknown year"

	if death_year < 0:
		return "%d BCE" % absi(
			death_year
		)

	return str(
		death_year
	)


func _profile_dead_health_description(target: Person) -> String:
	if target == null:
		return (
			"They died from unknown causes in an unknown year."
		)

	var cause_text: String = str(
		target.cause_of_death
	).strip_edges()

	if cause_text == "":
		cause_text = "unknown causes"

	return (
		"They died from %s in the year %s."
		% [
			cause_text,
			_profile_death_year_label(
				target
			)
		]
	)


func _profile_stat_context_signature(target: Person) -> String:
	if target == null:
		return "missing"

	return (
		"%s:%s:%d:%d:%d:%s:%s:%d:%s"
		% [
			(
				"living"
				if _person_is_canonically_living(
					target
				)
				else "dead"
			),
			str(
				target.cause_of_death
			).strip_edges(),
			int(
				target.death_year
			),
			int(
				round(
					float(
						target.fame
					)
				)
			),
			int(
				round(
					float(
						target.approval
					)
				)
			),
			str(
				bool(
					target.is_ruler
				)
			),
			str(
				bool(
					target.is_royal
				)
			),
			int(
				target.succession_rank
			),
			str(
				target.royal_title
			).strip_edges()
		]
	)


func _profile_stat_surface_contract(
	_actor: Person,
	target: Person,
	stat_id: String,
	label: String,
	raw_value: int,
	maximum: int
) -> Dictionary:
	var clean_stat_id: String = str(
		stat_id
	).strip_edges().to_lower()
	var clean_label: String = str(
		label
	).strip_edges()
	var safe_maximum: int = maxi(
		1,
		int(
			maximum
		)
	)
	var canonical_title: String = (
		"Mental"
		if clean_stat_id == "mental"
		else clean_label
	)
	var target_alive: bool = (
		_person_is_canonically_living(
			target
		)
	)
	var clamped_raw_value: int = clampi(
		int(
			raw_value
		),
		0,
		safe_maximum
	)
	var display_value: int = clamped_raw_value
	var descriptor: String = ""
	var description: String = ""
	var bar_text: String = str(
		clamped_raw_value
	)

	if clean_stat_id == "bond":
		var bond_ratio: float = clampf(
			float(
				clamped_raw_value
			)
			/ float(
				safe_maximum
			),
			0.0,
			1.0
		)
		var living_descriptor: String = (
			_profile_bond_descriptor_for_ratio(
				bond_ratio
			)
		)

		descriptor = living_descriptor
		description = (
			_profile_bond_flavor_for_descriptor(
				living_descriptor,
				not target_alive
			)
		)

		if not target_alive:
			descriptor = (
				"%s, Now Dead"
				% living_descriptor
			)
			bar_text = "DEAD"

	elif not target_alive:


		display_value = 0
		descriptor = "Dead"
		bar_text = "DEAD"

		if clean_stat_id == "health":
			description = (
				_profile_dead_health_description(
					target
				)
			)
		else:
			description = "This life has ended."

	else:
		var ratio: float = clampf(
			float(
				clamped_raw_value
			)
			/ float(
				safe_maximum
			),
			0.0,
			1.0
		)

		match clean_stat_id:
			"health":
				if clamped_raw_value >= 180:
					descriptor = "Mythic Body"
					description = (
						"Your body is operating beyond anything ordinary "
						+ "people are built to survive."
					)
				elif clamped_raw_value >= 150:
					descriptor = "Superhuman"
					description = (
						"Your body is past peak condition and starting "
						+ "to feel unreal."
					)
				elif clamped_raw_value >= 125:
					descriptor = "Enhanced"
					description = (
						"Your body is stronger than normal limits, but "
						+ "still recognizably human."
					)
				elif clamped_raw_value >= 100:
					descriptor = "Peak Condition"
					description = (
						"Your body is at the kind of health most people "
						+ "dream about."
					)
				elif clamped_raw_value >= 85:
					descriptor = "Excellent"
					description = (
						"Your body feels strong, responsive, and dependable."
					)
				elif clamped_raw_value >= 70:
					descriptor = "Strong"
					description = (
						"You feel durable, steady, and ready for impact."
					)
				elif clamped_raw_value >= 50:
					descriptor = "Stable"
					description = (
						"You are holding together without obvious strain."
					)
				elif clamped_raw_value >= 30:
					descriptor = "Injured"
					description = (
						"Your body is asking for recovery whether you "
						+ "listen or not."
					)
				elif clamped_raw_value >= 15:
					descriptor = "Critical"
					description = (
						"Your body is refusing to give up, but it is close."
					)
				else:
					descriptor = "Near Death"
					description = (
						"Every movement feels like it could be your last."
					)

			"hunger":
				if clamped_raw_value <= 5:
					descriptor = "Critical Starvation"
					description = (
						"Your body is running on almost nothing. "
						+ "This is dangerous."
					)
				elif clamped_raw_value <= 18:
					descriptor = "Starving"
					description = (
						"Your body urgently needs food. Every moment "
						+ "without sustenance matters."
					)
				elif clamped_raw_value <= 35:
					descriptor = "Malnourished"
					description = (
						"You have gone too long without enough food."
					)
				elif clamped_raw_value <= 55:
					descriptor = "Hungry"
					description = "Your body is asking for food."
				elif clamped_raw_value <= 72:
					descriptor = "Peckish"
					description = (
						"You could eat, but you are still holding steady."
					)
				elif clamped_raw_value <= 92:
					descriptor = "Satisfied"
					description = "You feel fed and steady."
				else:
					descriptor = "Full"
					description = (
						"You are fully fed. Food is not pressing on "
						+ "your body right now."
					)

			"mental":
				var approval_value: int = clampi(
					int(
						round(
							float(
								target.approval
							)
						)
					),
					0,
					100
				)
				var fame_value: int = maxi(
					0,
					int(
						round(
							float(
								target.fame
							)
						)
					)
				)
				var royal_pressure: bool = (
					(
						bool(
							target.is_ruler
						)
						or bool(
							target.is_royal
						)
						or int(
							target.succession_rank
						) <= 12
						or str(
							target.royal_title
						).strip_edges() != ""
					)
					and approval_value < 45
				)
				var public_pressure: bool = (
					fame_value >= 60
				)

				if royal_pressure:
					if ratio >= 0.75:
						descriptor = "Commanding"
						description = (
							"Pressure is real, but your mind is still above it."
						)
					elif ratio >= 0.45:
						descriptor = "Siege-Minded"
						description = (
							"Responsibility is crowding your thoughts."
						)
					else:
						descriptor = "Overrun"
						description = (
							"The crown is louder than your control."
						)
				elif public_pressure:
					if ratio >= 0.75:
						descriptor = "Focused"
						description = (
							"The world is loud, but your inner signal is still clean."
						)
					elif ratio >= 0.45:
						descriptor = "Crowded"
						description = (
							"Too much attention is living in your head rent-free."
						)
					else:
						descriptor = "Overwhelmed"
						description = (
							"The noise outside is starting to win."
						)
				elif ratio >= 0.9:
					descriptor = "Locked In"
					description = (
						"Your thoughts feel sharp, quiet, and fully under you."
					)
				elif ratio >= 0.72:
					descriptor = "Focused"
					description = (
						"Your mind is steady and responsive."
					)
				elif ratio >= 0.5:
					descriptor = "Steady"
					description = (
						"You are carrying your thoughts without slipping."
					)
				elif ratio >= 0.3:
					descriptor = "Overloaded"
					description = (
						"Your thoughts are louder than your control."
					)
				elif ratio >= 0.15:
					descriptor = "Fractured"
					description = (
						"Your mind is splitting under pressure."
					)
				else:
					descriptor = "Overwhelmed"
					description = (
						"You are barely holding the inside together."
					)

			"smarts":
				if ratio >= 0.95:
					descriptor = "Gifted"
					description = (
						"Your mind is operating above the room."
					)
				elif ratio >= 0.8:
					descriptor = "Brilliant"
					description = (
						"You process patterns faster than most people "
						+ "can explain them."
					)
				elif ratio >= 0.6:
					descriptor = "Sharp"
					description = (
						"You are thinking clearly and catching things quickly."
					)
				elif ratio >= 0.4:
					descriptor = "Clever"
					description = (
						"You can work your way through things with effort."
					)
				elif ratio >= 0.2:
					descriptor = "Foggy"
					description = (
						"Your thinking works, but it feels heavy."
					)
				else:
					descriptor = "Lost"
					description = (
						"Nothing is clicking the way it should."
					)

			"looks":
				if ratio >= 0.9:
					descriptor = "Striking"
					description = (
						"Your presence lands before you even say anything."
					)
				elif ratio >= 0.72:
					descriptor = "Attractive"
					description = (
						"You are carrying yourself well and it shows."
					)
				elif ratio >= 0.5:
					descriptor = "Presentable"
					description = (
						"You look fine, even if it is not commanding the room."
					)
				elif ratio >= 0.3:
					descriptor = "Plain"
					description = (
						"Nothing is wrong, but nothing is turning heads either."
					)
				elif ratio >= 0.15:
					descriptor = "Rough"
					description = (
						"You look like life has been leaving fingerprints."
					)
				else:
					descriptor = "Haggard"
					description = (
						"You look visibly worn down."
					)

		if description != "":
			description = (
				_profile_stat_phrase_third_person(
					description
				)
			)

	var title_text: String = canonical_title

	if descriptor != "":
		title_text = (
			"%s: %s"
			% [
				canonical_title,
				descriptor
			]
		)

	return {
		"stat_id": clean_stat_id,
		"id": clean_stat_id,
		"label": clean_label,
		"surface_title": canonical_title,
		"raw_value": clamped_raw_value,
		"value": display_value,
		"display_value": display_value,
		"maximum": safe_maximum,
		"descriptor": descriptor,
		"title_text": title_text,
		"description": description,
		"sub_description": description,
		"bar_text": bar_text,
		"target_alive": target_alive,
		"lifecycle_terminal": not target_alive,
		"canonical_stat_surface_source": (
			"RelationshipsHubContractEngine"
		),
		"narrative_perspective": "third_person",
		"ui_is_renderer_only": true
	}


func _profile_stats_contract(
	actor: Person,
	target: Person,
	bond_value: int,
	hunger_value: int,
	health_value: int,
	health_max: int,
	mental_value: int,
	smarts_value: int,
	looks_value: int,
	hunger_authority: String,
	hunger_profile_hot: bool,
	hunger_observation_provisional: bool
) -> Array:
	var bond_contract: Dictionary = (
		_profile_stat_surface_contract(
			actor,
			target,
			"bond",
			"Bond",
			bond_value,
			100
		)
	)
	var hunger_stat_contract: Dictionary = (
		_profile_stat_surface_contract(
			actor,
			target,
			"hunger",
			"Hunger",
			hunger_value,
			100
		)
	)
	var health_contract: Dictionary = (
		_profile_stat_surface_contract(
			actor,
			target,
			"health",
			"Health",
			health_value,
			health_max
		)
	)
	var mental_contract: Dictionary = (
		_profile_stat_surface_contract(
			actor,
			target,
			"mental",
			"Mental Health",
			mental_value,
			100
		)
	)
	var smarts_contract: Dictionary = (
		_profile_stat_surface_contract(
			actor,
			target,
			"smarts",
			"Smarts",
			smarts_value,
			100
		)
	)
	var looks_contract: Dictionary = (
		_profile_stat_surface_contract(
			actor,
			target,
			"looks",
			"Looks",
			looks_value,
			100
		)
	)

	hunger_stat_contract [
		"authority"
	] = hunger_authority
	hunger_stat_contract [
		"published_profile"
	] = hunger_profile_hot
	hunger_stat_contract [
		"provisional"
	] = hunger_observation_provisional

	return [
		bond_contract,
		hunger_stat_contract,
		health_contract,
		mental_contract,
		smarts_contract,
		looks_contract
	]
func emit_profile_contract(
	actor: Person,
	target: Person,
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	if (
		actor == null
		or target == null
	):
		return _fail(
			"missing_actor_or_target_for_profile",
			context
		)

	var actor_id: int = int(
		actor.id
	)
	var target_id: int = int(
		target.id
	)
	var projection_read_only: bool = bool(
		context.get(
			"projection_read_only",
			false
		)
	)
	var relation_label: String = str(
		context.get(
			"relationship_role",
			_relationship_label_for_pair(
				actor,
				target
			)
		)
	)
	var bond_value: int = int(
		context.get(
			"bond",
			-1
		)
	)

	if bond_value < 0:
		bond_value = (
			_projection_bond_score_for_pair(
				actor,
				target,
				context
			)
			if projection_read_only
			else bond_score_for_pair(
				actor,
				target
			)
		)

	var health_max: int = maxi(
		1,
		int(
			context.get(
				"health_max",
				_health_base_display_max(
					int(
						round(
							float(
								target.health
							)
						)
					)
				)
			)
		)
	)
	var health_value: int = clampi(
		int(
			round(
				float(
					target.health
				)
			)
		),
		0,
		health_max
	)




	var hunger_contract: Dictionary = {}

	if (
		gs != null
		and gs.food_engine != null
		and gs.food_engine.has_method(
			"hunger_scalar_contract_for_actor"
		)
	):
		hunger_contract = (
			gs.food_engine.hunger_scalar_contract_for_actor(
				target_id
			)
		)

	var hunger_profile_hot: bool = (
		bool(
			hunger_contract.get(
				"success",
				false
			)
		)
		and int(
			hunger_contract.get(
				"actor_id",
				-1
			)
		) == target_id
	)
	var raw_person_hunger: float = float(
		target.hunger
	)
	var hunger_source_value: float = raw_person_hunger
	var hunger_authority: String = "Person.hunger_mirror"
	var hunger_observation_provisional: bool = false

	if hunger_profile_hot:
		hunger_source_value = float(
			hunger_contract.get(
				"hunger",
				raw_person_hunger
			)
		)
		hunger_authority = "FoodEngine.hunger_scalar_contract"
	elif hunger_source_value < 0.0:
		hunger_source_value = FoodEngine.DEFAULT_STARTING_HUNGER
		hunger_authority = "FoodEngine.default_starting_hunger"
		hunger_observation_provisional = true

	var hunger_value: int = clampi(
		int(
			round(
				hunger_source_value
			)
		),
		0,
		int(
			FoodEngine.DEFAULT_MAX_HUNGER
		)
	)
	var mental_value: int = clampi(
		int(
			round(
				float(
					target.mental_health
				)
			)
		),
		0,
		100
	)
	var smarts_value: int = clampi(
		int(
			target.smarts
		),
		0,
		100
	)
	var looks_value: int = clampi(
		int(
			target.looks
		),
		0,
		100
	)



	var target_alive: bool = (
		_person_is_canonically_living(
			target
		)
	)
	var semantic_can_switch: bool = (
		actor_id != target_id
		and target_alive
	)
	var stat_context_signature: String = (
		_profile_stat_context_signature(
			target
		)
	)




	var signature: String = (
		"%d:%d:%d:%d:%d:%d:%d:%d:%d:%s:%s:%s:%s:%s"
		% [
			actor_id,
			target_id,
			int(
				target.age
			),
			bond_value,
			health_value,
			hunger_value,
			mental_value,
			smarts_value,
			looks_value,
			relation_label,
			hunger_authority,
			str(
				hunger_observation_provisional
			),
			stat_context_signature,
			str(
				projection_read_only
			)
		]
	)
	var cached: Dictionary = _shallow_dictionary(
		profile_contract_cache.get(
			signature,
			{}
		)
	)

	if not cached.is_empty():




		if not semantic_can_switch:
			cached [
				"switch_packet"
			] = {}
			cached [
				"switch_packet_hot"
			] = false
			cached [
				"switch_packet_core_hot"
			] = false
			cached [
				"can_switch"
			] = false
			cached [
				"switch_semantically_available"
			] = false
			cached [
				"switch_packet_successor_installed"
			] = false
			cached [
				"switch_packet_resolution_attempted"
			] = false
			cached [
				"status_text"
			] = (
				"Deceased. Viewpoint switching is unavailable."
				if not target_alive
				else ""
			)
			cached [
				"target_alive"
			] = target_alive
			cached [
				"target_lifecycle_state"
			] = (
				"living"
				if target_alive
				else "dead"
			)
			cached [
				"cache_hit"
			] = true
			cached [
				"requested_at_ms"
			] = int(
				Time.get_ticks_msec()
			)

			profile_contract_cache [
				signature
			] = cached.duplicate(false)

			return cached.duplicate(false)

		var cached_switch_packet: Dictionary = _shallow_dictionary(
			cached.get(
				"switch_packet",
				{}
			)
		)
		var latest_switch_packet: Dictionary = {}

		if not _context_forbids_switch_packet_resolution(
			context
		):
			latest_switch_packet = (
				_profile_switch_packet_for_target(
					actor,
					target,
					context
				)
			)

		var cached_core_hot: bool = (
			_profile_switch_packet_core_hot(
				cached_switch_packet,
				target_id
			)
		)
		var latest_core_hot: bool = (
			_profile_switch_packet_core_hot(
				latest_switch_packet,
				target_id
			)
		)

		if latest_core_hot:
			cached_switch_packet = (
				latest_switch_packet.duplicate(false)
			)
			cached [
				"switch_packet"
			] = cached_switch_packet
			cached [
				"switch_packet_hot"
			] = true
			cached [
				"can_switch"
			] = true
			cached [
				"switch_semantically_available"
			] = true
			cached [
				"switch_packet_successor_installed"
			] = true

		elif cached_core_hot:
			cached [
				"switch_packet"
			] = cached_switch_packet.duplicate(false)
			cached [
				"switch_packet_hot"
			] = true
			cached [
				"can_switch"
			] = true
			cached [
				"switch_semantically_available"
			] = true
			cached [
				"switch_packet_successor_installed"
			] = false

		else:
			cached [
				"switch_packet"
			] = {}
			cached [
				"switch_packet_hot"
			] = false
			cached [
				"can_switch"
			] = false
			cached [
				"switch_semantically_available"
			] = true
			cached [
				"switch_packet_successor_installed"
			] = false
			cached [
				"switch_packet_resolution_attempted"
			] = true

		cached [
			"switch_packet_core_hot"
		] = bool(
			cached.get(
				"switch_packet_hot",
				false
			)
		)
		cached [
			"target_alive"
		] = true
		cached [
			"target_lifecycle_state"
		] = "living"
		cached [
			"status_text"
		] = ""
		cached [
			"cache_hit"
		] = true
		cached [
			"requested_at_ms"
		] = int(
			Time.get_ticks_msec()
		)

		profile_contract_cache [
			signature
		] = cached.duplicate(false)

		return cached.duplicate(false)

	var switch_packet: Dictionary = _shallow_dictionary(
		context.get(
			"switch_packet",
			{}
		)
	)




	if not semantic_can_switch:
		switch_packet = {}

	elif (
		switch_packet.is_empty()
		and not _context_forbids_switch_packet_resolution(
			context
		)
	):
		switch_packet = (
			_profile_switch_packet_for_target(
				actor,
				target,
				context
			)
		)

	var switch_packet_core_hot: bool = (
		semantic_can_switch
		and _profile_switch_packet_core_hot(
			switch_packet,
			target_id
		)
	)
	var profile_lines: Array = (
		_profile_lines_for_target(
			actor,
			target,
			relation_label,
			bond_value
		)
	)
	var stats: Array = (
		_profile_stats_contract(
			actor,
			target,
			bond_value,
			hunger_value,
			health_value,
			health_max,
			mental_value,
			smarts_value,
			looks_value,
			hunger_authority,
			hunger_profile_hot,
			hunger_observation_provisional
		)
	)
	var profile_actions: Array = (
		_profile_actions_for_target(
			actor,
			target,
			relation_label
		)
	)
	var modification_contract: Dictionary = {}

	if target_alive:
		modification_contract = (
			_modification_contract_for_target(
				target,
				{
					"source": (
						"relationships_hub_contract_engine."
						+ "emit_profile_contract"
					),
					"viewer_actor_id": actor_id,
					"target_id": target_id,
					"profile_signature": signature,
					"ready_gate_member": false,
					"ui_is_renderer_only": true
				}
			)
		)

	var modification_hot: bool = (
		target_alive
		and not modification_contract.is_empty()
		and int(
			modification_contract.get(
				"actor_id",
				-1
			)
		) == target_id
	)
	var contract: Dictionary = {
		"success": true,
		"schema": PROFILE_CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"actor_id": actor_id,
		"target_id": target_id,
		"title": _actor_display_name(
			target
		),
		"target_name": _actor_display_name(
			target
		),
		"target_name_with_age": (
			_relationship_display_name_with_age(
				target
			)
		),
		"relationship_role": relation_label,
		"bank_text": _profile_bank_text(
			target
		),
		"target_alive": target_alive,
		"target_lifecycle_state": (
			"living"
			if target_alive
			else "dead"
		),
		"status_text": (
			""
			if target_alive
			else "Deceased. Viewpoint switching is unavailable."
		),
		"can_switch": (
			semantic_can_switch
			and switch_packet_core_hot
		),
		"switch_semantically_available": semantic_can_switch,
		"can_edit": (
			target_alive
			and modification_hot
		),
		"edit_semantically_available": target_alive,
		"modification_contract": (
			modification_contract.duplicate(false)
			if modification_hot
			else {}
		),
		"modification_contract_hot": modification_hot,
		"switch_label": (
			_profile_switch_label_for_target(
				target
			)
		),
		"edit_label": "EDIT THEM",
		"stats": stats,
		"canonical_stat_surface_source": (
			"relationships_hub_contract_engine"
		),
		"dead_profile_stats_terminal": not target_alive,
		"hunger_authority": hunger_authority,
		"hunger_profile_hot": hunger_profile_hot,
		"hunger_observation_provisional": hunger_observation_provisional,
		"profile_lines": profile_lines,
		"profile_text": (
			"===== PROFILE =====\n%s\n==================="
			% _join_strings(
				profile_lines,
				"\n"
			)
		),
		"actions": profile_actions,
		"switch_packet": (
			switch_packet.duplicate(false)
			if switch_packet_core_hot
			else {}
		),
		"switch_packet_hot": switch_packet_core_hot,
		"switch_packet_core_hot": switch_packet_core_hot,
		"switch_packet_resolution_attempted": semantic_can_switch,
		"switch_press_build_forbidden": true,
		"age_contextual_action_count": profile_actions.size(),
		"projection_read_only": projection_read_only,
		"simulation_mutation_performed": false,
		"truth_state": "hot",
		"authoritative_projection": true,
		"immutable_surface_contract": true,
		"signature": signature,
		"created_at_ms": int(
			Time.get_ticks_msec()
		),
		"cache_hit": false,
		"ui_is_renderer_only": true
	}

	profile_contract_cache [
		signature
	] = contract.duplicate(false)

	_trim_cache(
		profile_contract_cache
	)

	return contract.duplicate(false)
func _profile_switch_label_for_target(
	target: Person
) -> String:
	if target == null:
		return "SWITCH TO THEM"

	var gender_text: String = str(
		target.gender
	).strip_edges().to_lower()

	if gender_text == "male":
		return "SWITCH TO HIM"

	if gender_text == "female":
		return "SWITCH TO HER"

	return "SWITCH TO THEM"

func bond_score_for_pair(observer: Person, target: Person) -> int:
	if observer == null or target == null:
		return 0

	if int(observer.id) == int(target.id):
		return 100

	if (
		gs != null
		and gs.relationship_graph_contract_engine != null
		and gs.relationship_graph_contract_engine.has_method("ensure_person_entity")
		and gs.relationship_graph_contract_engine.has_method("bond_for_pair")
	):
		var observer_entity: Dictionary = _shallow_dictionary(
			gs.relationship_graph_contract_engine.ensure_person_entity(
				observer,
				{ "source": "relationships_hub_contract_engine.bond_score_for_pair.observer"}
			)
		)
		var target_entity: Dictionary = _shallow_dictionary(
			gs.relationship_graph_contract_engine.ensure_person_entity(
				target, { "source": "relationships_hub_contract_engine.bond_score_for_pair.target"}
			)
		)
		var graph_bond: int = int(
			gs.relationship_graph_contract_engine.bond_for_pair(
				str(observer_entity.get("entity_id", "")),
				str(target_entity.get("entity_id", "")),
				-1
			)
		)

		if graph_bond >= 0:
			return clampi(graph_bond, 0, 100)

	var backfill_report: Dictionary = legacy_pair_graph_backfill(
		observer, target, { "source": "relationships_hub_contract_engine.bond_score_for_pair"}
	)

	if bool(backfill_report.get("success", false)):
		var edge: Dictionary = _shallow_dictionary(backfill_report.get("edge", {}))

		if not edge.is_empty():
			return clampi(int(edge.get("bond", 50)), 0, 100)

	if typeof(observer.affection) == TYPE_DICTIONARY and observer.affection.has(int(target.id)):
		return clampi(int(observer.affection.get(int(target.id), 0)), 0, 100)

	if (
		gs != null
		and gs.relationship_engine != null
		and gs.relationship_engine.has_method("ensure_pair_relationship_baseline")
	):
		return clampi(
			int(gs.relationship_engine.ensure_pair_relationship_baseline(observer, target)), 0, 100
		)

	if _is_parent_of(target, observer) or _is_parent_of(observer, target):
		return 72

	var partner: Person = _valid_partner(observer)

	if partner != null and int(partner.id) == int(target.id):
		return 86

	if _id_in_array(_safe_person_id_array(observer, "friends"), int(target.id)):
		return 62

	return 50


func sorted_ids_by_bond(ids: Array, observer: Person) -> Array:
	if ids.is_empty():
		return []

	var ranked: Array = []
	var order: int = 0

	for raw_id in ids:
		var target_id: int = int(raw_id)

		if target_id <= 0:
			continue

		var target: Person = _person_by_id(target_id)
		var bond_value: int = bond_score_for_pair(observer, target) if target != null else 0
		ranked.append({ "id": target_id, "bond": bond_value, "order": order})
		order += 1

	ranked.sort_custom(Callable(self, "_ranked_person_sort"))

	var out: Array = []

	for raw_rank in ranked:
		var rank: Dictionary = _shallow_dictionary(raw_rank)
		var ranked_id: int = int(rank.get("id", 0))

		if ranked_id > 0:
			out.append(ranked_id)

	return out


func legacy_pair_graph_backfill(
	observer: Person, target: Person, context: Dictionary = {}
) -> Dictionary:
	if (
		observer == null
		or target == null
		or gs == null
		or gs.human_relationship_contract_engine == null
		or not gs.human_relationship_contract_engine.has_method("ensure_pair_edge")
	):
		return { "success": false, "reason": "human_relationship_contract_engine_unavailable"}

	return _shallow_dictionary(
		gs.human_relationship_contract_engine.ensure_pair_edge(observer, target, context)
	)


func flush_switch_shell_stage_queue(
	max_count: int = 1,
	context: Dictionary = {}
) -> Dictionary:
	var limit: int = maxi(
		1,
		max_count
	)
	var processed: int = 0
	var staged: int = 0
	var requeued: int = 0
	var failures: Array = []
	var staged_packets_by_actor: Dictionary = {}
	var delayed_rows: Array = []
	var now_ms: int = int(
		Time.get_ticks_msec()
	)

	while (
		processed < limit
		and not switch_shell_stage_queue.is_empty()
	):
		var row: Dictionary = _shallow_dictionary(
			switch_shell_stage_queue.pop_front()
		).duplicate(true)

		processed += 1

		var target_id: int = int(
			row.get(
				"target_id",
				-1
			)
		)
		var target: Person = _person_by_id(
			target_id
		)

		if target == null:
			switch_shell_stage_seen.erase(
				target_id
			)
			failures.append(
				{
					"target_id": target_id,
					"reason": "target_missing",
					"retryable": false
				}
			)
			continue

		var next_allowed_ms: int = int(
			row.get(
				"next_allowed_at_ms",
				0
			)
		)

		if next_allowed_ms > now_ms:
			delayed_rows.append(
				row
			)
			requeued += 1
			continue

		var queued_context: Dictionary = _shallow_dictionary(
			row.get(
				"context",
				{}
			)
		)
		var complete_destination_required: bool = (
			bool(
				row.get(
					"complete_destination_deck_required",
					false
				)
			)
			or bool(
				row.get(
					"relationship_profile_visible_packet",
					false
				)
			)
			or bool(
				row.get(
					"explicit_relationship_profile_observation",
					false
				)
			)
			or bool(
				queued_context.get(
					"complete_destination_deck_required",
					false
				)
			)
			or bool(
				queued_context.get(
					"relationship_profile_visible_packet",
					false
				)
			)
			or bool(
				queued_context.get(
					"explicit_relationship_profile_observation",
					false
				)
			)
		)
		var stage_context: Dictionary = queued_context.duplicate(false)

		stage_context [
			"source"
		] = str(
			context.get(
				"source",
				queued_context.get(
					"source",
					(
						"relationships_hub_contract_engine."
						+ "flush_switch_shell_stage_queue"
					)
				)
			)
		)
		stage_context [
			"queued_context"
		] = row.duplicate(false)
		stage_context [
			"actor_lens_bundle_required"
		] = true
		stage_context [
			"background_only"
		] = true
		stage_context [
			"complete_destination_deck_required"
		] = complete_destination_required
		stage_context [
			"relationship_profile_visible_packet"
		] = complete_destination_required
		stage_context [
			"explicit_relationship_profile_observation"
		] = complete_destination_required
		stage_context [
			"allow_pointer_core_only_preparation"
		] = not complete_destination_required
		stage_context [
			"visible_card_may_not_publish_complete_destination_deck"
		] = not complete_destination_required
		stage_context [
			"ready_gate_member"
		] = false
		stage_context [
			"ui_is_renderer_only"
		] = true

		var shell: Dictionary = (
			_stage_switch_shell_for_target(
				null,
				target,
				stage_context
			)
		)

		if bool(
			shell.get(
				"producer_pending",
				false
			)
		):
			var producer_attempt_count: int = int(
				row.get(
					"producer_attempt_count",
					0
				)
			) + 1
			var producer_reason: String = str(
				shell.get(
					"reason",
					"universal_switch_complete_destination_packet_pending"
				)
			).strip_edges()
			var producer_retry_delay_ms: int = 220

			if producer_reason in [
				"universal_switch_complete_producer_missing",
				"missing_game_state",
				"missing_target"
			]:
				producer_retry_delay_ms = 1600
			elif producer_reason == "profile_switch_support_packet_publication_failed":
				producer_retry_delay_ms = 360
			elif producer_reason == "profile_switch_actor_destination_deck_pending":
				producer_retry_delay_ms = 220
			elif not bool(
				shell.get(
					"retryable",
					true
				)
			):
				switch_shell_stage_seen.erase(
					target_id
				)
				failures.append(
					{
						"target_id": target_id,
						"reason": producer_reason,
						"retryable": false,
						"producer_report": shell.duplicate(false)
					}
				)
				continue

			row [
				"producer_attempt_count"
			] = producer_attempt_count
			row [
				"last_attempt_at_ms"
			] = now_ms
			row [
				"next_allowed_at_ms"
			] = now_ms + producer_retry_delay_ms
			row [
				"last_reason"
			] = producer_reason
			row [
				"universal_switch_producer_invoked"
			] = true
			row [
				"complete_destination_deck_required"
			] = true
			row [
				"relationship_profile_visible_packet"
			] = true
			row [
				"explicit_relationship_profile_observation"
			] = true
			row [
				"pointer_core_only_allowed"
			] = false
			row [
				"producer_pending"
			] = true
			row [
				"producer_retry_delay_ms"
			] = producer_retry_delay_ms
			row [
				"producer_report"
			] = shell.duplicate(false)
			row [
				"ready_gate_member"
			] = false

			delayed_rows.append(
				row
			)
			requeued += 1
			failures.append(
				{
					"target_id": target_id,
					"reason": producer_reason,
					"retryable": true,
					"producer_attempt_count": producer_attempt_count,
					"missing_main_tabs": _shallow_array(
						shell.get(
							"missing_main_tabs",
							[]
						)
					),
					"pointer_core_hot": bool(
						shell.get(
							"pointer_core_hot",
							false
						)
					),
					"main_tab_surface_deck_hot": bool(
						shell.get(
							"main_tab_surface_deck_hot",
							false
						)
					),
					"support_packet_hot": bool(
						shell.get(
							"support_packet_hot",
							false
						)
					)
				}
			)
			continue

		if bool(
			shell.get(
				"projection_pending",
				false
			)
		):
			var projection_attempt_count: int = int(
				row.get(
					"projection_attempt_count",
					0
				)
			) + 1

			row ["projection_attempt_count"] = projection_attempt_count
			row ["last_attempt_at_ms"] = now_ms
			row ["next_allowed_at_ms"] = now_ms + 900
			row ["last_reason"] = "resident_interactive_projection_pending"
			row ["projection_retry_is_background_throttled"] = true
			row ["projection_retry_may_not_consume_player_frames"] = true
			row ["projection_signature"] = str(
				shell.get(
					"projection_signature",
					row.get(
						"projection_signature",
						""
					)
				)
			)
			row ["projection_stage_id"] = str(
				shell.get(
					"projection_stage_id",
					"unknown"
				)
			)
			row ["projection_progress"] = float(
				shell.get(
					"projection_progress",
					0.0
				)
			)
			row ["background_retry"] = true
			row ["ready_gate_member"] = false

			delayed_rows.append(
				row
			)
			requeued += 1
			continue

		if shell.is_empty():
			var attempt_count: int = int(
				row.get(
					"attempt_count",
					0
				)
			) + 1

			row ["attempt_count"] = attempt_count
			row ["last_attempt_at_ms"] = now_ms
			row ["next_allowed_at_ms"] = now_ms + mini(
				720,
				96 * attempt_count
			)
			row ["last_reason"] = (
				"zero_frame_core_surface_not_hot"
			)
			row ["background_retry"] = true
			row ["ready_gate_member"] = false

			delayed_rows.append(
				row
			)
			requeued += 1
			failures.append(
				{
					"target_id": target_id,
					"reason": "switch_shell_stage_pending",
					"retryable": true,
					"attempt_count": attempt_count
				}
			)
			continue

		if bool(
			shell.get(
				"pointer_core_only",
				false
			)
		):
			var row_requires_complete_packet: bool = (
				bool(
					row.get(
						"complete_destination_deck_required",
						false
					)
				)
				or bool(
					row.get(
						"relationship_profile_visible_packet",
						false
					)
				)
				or bool(
					row.get(
						"explicit_relationship_profile_observation",
						false
					)
				)
				or bool(
					queued_context.get(
						"complete_destination_deck_required",
						false
					)
				)
				or bool(
					queued_context.get(
						"relationship_profile_visible_packet",
						false
					)
				)
				or bool(
					queued_context.get(
						"explicit_relationship_profile_observation",
						false
					)
				)
			)

			if row_requires_complete_packet:
				row [
					"complete_destination_deck_required"
				] = true
				row [
					"relationship_profile_visible_packet"
				] = true
				row [
					"explicit_relationship_profile_observation"
				] = true
				row [
					"pointer_core_only_allowed"
				] = false
				row [
					"pointer_core_is_not_completion_authority"
				] = true
				row [
					"last_reason"
				] = "pointer_core_hot_but_complete_profile_packet_required"
				row [
					"next_allowed_at_ms"
				] = now_ms + 140
				row [
					"background_retry"
				] = true
				row [
					"background_retry_is_profile_upgrade"
				] = true
				row [
					"ready_gate_member"
				] = false

				delayed_rows.append(
					row
				)
				requeued += 1
				continue

			var pointer_viewer_packet: Dictionary = _shallow_dictionary(
				shell.get(
					"viewer_packet",
					shell.get(
						"playable_life_viewer_render_packet",
						shell.get(
							"viewer_render_packet",
							{}
						)
					)
				)
			)

			staged += 1

			switch_shell_stage_seen.erase(
				target_id
			)





			staged_packets_by_actor [
				str(
					target_id
				)
			] = (
				pointer_viewer_packet.duplicate(false)
				if not pointer_viewer_packet.is_empty()
				else {}
			)

			continue

		var viewer_packet: Dictionary = _shallow_dictionary(
			shell.get(
				"viewer_packet",
				shell.get(
					"playable_life_viewer_render_packet",
					shell.get(
						"viewer_render_packet",
						{}
					)
				)
			)
		)
		var viewer_surface: Dictionary = _shallow_dictionary(
			viewer_packet.get(
				"surface_contract",
				{}
			)
		)
		var main_tab_deck: Dictionary = _shallow_dictionary(
			viewer_packet.get(
				"main_tab_surface_contracts",
				viewer_surface.get(
					"main_tab_surface_contracts",
					{}
				)
			)
		)
		var destination_deck_hot: bool = (
			_resident_switch_main_tab_deck_is_hot_for_actor(
				main_tab_deck,
				target_id
			)
		)
		var core_hot: bool = false
		var core_truth: Dictionary = {}

		if (
			switch_engine != null
			and switch_engine.has_method(
				"_profile_switch_core_packet_truth"
			)
		):
			core_truth = _shallow_dictionary(
				switch_engine._profile_switch_core_packet_truth(
					viewer_packet,
					target_id
				)
			)
			core_hot = bool(
				core_truth.get(
					"core_packet_hot",
					false
				)
			)

		if (
			not core_hot
			or not destination_deck_hot
		):
			var attempt_count_not_hot: int = int(
				row.get(
					"attempt_count",
					0
				)
			) + 1

			row ["attempt_count"] = attempt_count_not_hot
			row ["last_attempt_at_ms"] = now_ms
			row ["next_allowed_at_ms"] = (
				now_ms + 1400
				if core_hot
				else now_ms + 420
			)
			row ["last_reason"] = (
				"staged_destination_deck_not_hot"
				if core_hot
				else "staged_packet_core_not_hot"
			)
			row ["core_truth"] = core_truth.duplicate(false)
			row ["background_retry"] = true
			row ["background_retry_is_throttled"] = true
			row ["destination_deck_retry_may_not_consume_player_frames"] = true
			row ["ready_gate_member"] = false

			delayed_rows.append(
				row
			)
			requeued += 1
			continue

		staged += 1

		switch_shell_stage_seen.erase(
			target_id
		)
		staged_packets_by_actor [
			str(
				target_id
			)
		] = (
			viewer_packet.duplicate(false)
			if destination_deck_hot
			else {}
		)

	for delayed_row in delayed_rows:
		var delayed_target_id: int = int(
			_shallow_dictionary(
				delayed_row
			).get(
				"target_id",
				-1
			)
		)

		if delayed_target_id <= 0:
			continue

		switch_shell_stage_seen [
			delayed_target_id
		] = true
		switch_shell_stage_queue.append(
			_shallow_dictionary(
				delayed_row
			).duplicate(false)
		)

	var flush_source: String = str(
		context.get(
			"source",
			""
		)
	).strip_edges().to_lower()
	var detached_resident_projection_lane: bool = (
		flush_source.find(
			"resident_projection_switch_shell_tail"
		) >= 0
	)
	var continuation_observer_publication_required: bool = false

	if gs != null:
		continuation_observer_publication_required = bool(
			gs.afterlife_active
		)

		if typeof(gs.scenario_state) == TYPE_DICTIONARY:
			continuation_observer_publication_required = (
				continuation_observer_publication_required
				or bool(
					gs.scenario_state.get(
						"checkpoint_resume_not_birth",
						false
					)
				)
				or bool(
					gs.scenario_state.get(
						"resident_runtime_restored_from_checkpoint",
						false
					)
				)
			)









	var staged_packets_pushed_to_observers: int = 0

	if (
		detached_resident_projection_lane
		and continuation_observer_publication_required
		and not staged_packets_by_actor.is_empty()
	):
		call_deferred(
			"_publish_resident_switch_destination_upgrade_packets",
			staged_packets_by_actor.duplicate(false)
		)

		staged_packets_pushed_to_observers = (
			staged_packets_by_actor.size()
		)

	return {
		"success": (
			failures.is_empty()
			or staged > 0
			or requeued > 0
		),
		"schema": ENGINE_SCHEMA,
		"version": CONTRACT_VERSION,
		"mode": "switch_shell_stage_queue_flushed",
		"processed": processed,
		"staged": staged,
		"requeued": requeued,
		"remaining": switch_shell_stage_queue.size(),
		"staged_packets_by_actor": (
			staged_packets_by_actor.duplicate(false)
		),
		"failures": failures,
		"staged_packets_pushed_to_observers": (
			staged_packets_pushed_to_observers
		),
		"continuation_observer_publication_required": (
			continuation_observer_publication_required
		),
		"detached_resident_projection_lane": (
			detached_resident_projection_lane
		),
		"ready_gate_member": false,
		"ui_is_renderer_only": true
	}
func _hub_group_contracts(
	actor: Person,
	section: String,
	context: Dictionary
) -> Array:
	var groups: Array = []
	var siblings: Array = _sibling_ids_for_person(
		actor
	)
	var grandparents: Array = _ancestor_generation_ids(
		actor,
		2
	)
	var great_grandparents: Array = _ancestor_generation_ids(
		actor,
		3
	)
	var in_laws: Array = _in_law_ids(
		actor
	)
	var aunts_uncles: Array = _aunt_uncle_ids(
		actor
	)
	var nieces_nephews: Array = _niece_nephew_ids(
		actor
	)

	match section:
		"family":
			groups.append(
				emit_group_contract(
					actor,
					"Immediate Family",
					_filter_person_ids_by_alive(
						_immediate_family_ids(
							actor
						),
						true
					),
					"No immediate family is visible right now.",
					{
						"premium": true,
						"subtitle": (
							"Parents and siblings stay pinned as the "
							+ "top-priority relationship lane."
						),
						"highlight_cards": true,
						"columns": 2,
						"section_key": "family"
					},
					context
				)
			)
			groups.append(
				emit_group_contract(
					actor,
					"In-Laws",
					_filter_person_ids_by_alive(
						in_laws,
						true
					),
					"None yet.",
					{
						"section_key": "family"
					},
					context
				)
			)
			groups.append(
				emit_group_contract(
					actor,
					"Aunts / Uncles",
					_filter_person_ids_by_alive(
						aunts_uncles,
						true
					),
					"None yet.",
					{
						"section_key": "family"
					},
					context
				)
			)
			groups.append(
				emit_group_contract(
					actor,
					"Nieces / Nephews",
					_filter_person_ids_by_alive(
						nieces_nephews,
						true
					),
					"None yet.",
					{
						"section_key": "family"
					},
					context
				)
			)

		"ancestors":
			groups.append(
				emit_group_contract(
					actor,
					"Grandparents",
					_filter_person_ids_by_alive(
						grandparents,
						true
					),
					"No grandparents are currently observable.",
					{
						"premium": true,
						"columns": 2,
						"section_key": "ancestors"
					},
					context
				)
			)
			groups.append(
				emit_group_contract(
					actor,
					"Great-Grandparents",
					_filter_person_ids_by_alive(
						great_grandparents,
						true
					),
					"No great-grandparents are currently observable.",
					{
						"section_key": "ancestors"
					},
					context
				)
			)

		"household":
			groups.append({
				"row_kind": "information",
				"title": "Household State",
				"lines": _household_status_lines(
					actor
				)
			})
			groups.append(
				emit_group_contract(
					actor,
					"Household Members",
					_filter_person_ids_by_alive(
						_household_member_ids(
							actor
						),
						true
					),
					"No household members are observable.",
					{
						"premium": true,
						"columns": 2,
						"section_key": "household"
					},
					context
				)
			)

		"partner":
			var partner_ids: Array = []
			var partner: Person = _valid_partner(
				actor
			)

			if _person_is_canonically_living(
				partner
			):
				partner_ids.append(
					int(
						partner.id
					)
				)

			groups.append(
				emit_group_contract(
					actor,
					"Partner",
					partner_ids,
					"No current partner.",
					{
						"premium": true,
						"columns": 2,
						"section_key": "partner"
					},
					context
				)
			)

			if (
				_person_is_canonically_living(
					partner
				)
				and gs != null
				and gs.relationship_activities_engine != null
				and gs.relationship_activities_engine.has_method(
					"get_resident_marriage_planner_row"
				)
			):
				var planner_row: Dictionary = (
					gs.relationship_activities_engine
					.get_resident_marriage_planner_row(
						actor,
						partner
					)
				)

				if not planner_row.is_empty():
					groups.append(
						planner_row
					)

			groups.append(
				emit_group_contract(
					actor,
					"Flings",
					_filter_person_ids_by_alive(
						_safe_person_id_array(
							actor,
							"flings"
						),
						true
					),
					"No active flings.",
					{
						"premium": true,
						"section_key": "partner"
					},
					context
				)
			)

			groups.append(
				emit_group_contract(
					actor,
					"In-Laws",
					_filter_person_ids_by_alive(
						in_laws,
						true
					),
					"None yet.",
					{
						"section_key": "partner"
					},
					context
				)
			)

		"pets":
			groups.append(
				_pet_group_contract(
					actor,
					context
				)
			)

		"descendants":
			groups.append(
				emit_group_contract(
					actor,
					"Children",
					_filter_person_ids_by_alive(
						_safe_person_id_array(
							actor,
							"children"
						),
						true
					),
					"No living children.",
					{
						"columns": 2,
						"section_key": "descendants"
					},
					context
				)
			)
			groups.append(
				emit_group_contract(
					actor,
					"Grandchildren",
					_filter_person_ids_by_alive(
						_descendant_generation_ids(
							actor,
							2
						),
						true
					),
					"No living grandchildren.",
					{
						"section_key": "descendants"
					},
					context
				)
			)
			groups.append(
				emit_group_contract(
					actor,
					"Great-Grandchildren",
					_filter_person_ids_by_alive(
						_descendant_generation_ids(
							actor,
							3
						),
						true
					),
					"No living great-grandchildren.",
					{
						"section_key": "descendants"
					},
					context
				)
			)

		"dead":
			groups.append(
				emit_group_contract(
					actor,
					"Dead Great-Grandparents",
					_filter_person_ids_by_alive(
						_ancestor_generation_ids(
							actor,
							3
						),
						false
					),
					"None.",
					{
						"section_key": "dead"
					},
					context
				)
			)
			groups.append(
				emit_group_contract(
					actor,
					"Dead Grandparents",
					_filter_person_ids_by_alive(
						_ancestor_generation_ids(
							actor,
							2
						),
						false
					),
					"None.",
					{
						"section_key": "dead"
					},
					context
				)
			)
			groups.append(
				emit_group_contract(
					actor,
					"Dead Parents",
					_filter_person_ids_by_alive(
						_safe_person_id_array(
							actor,
							"parents"
						),
						false
					),
					"None.",
					{
						"section_key": "dead"
					},
					context
				)
			)
			groups.append(
				emit_group_contract(
					actor,
					"Dead Siblings",
					_filter_person_ids_by_alive(
						siblings,
						false
					),
					"None.",
					{
						"section_key": "dead"
					},
					context
				)
			)
			groups.append(
				emit_group_contract(
					actor,
					"Dead Children",
					_filter_person_ids_by_alive(
						_safe_person_id_array(
							actor,
							"children"
						),
						false
					),
					"None.",
					{
						"section_key": "dead"
					},
					context
				)
			)
			groups.append(
				emit_group_contract(
					actor,
					"Other Dead Relationships",
					_dead_other_relationship_ids(
						actor
					),
					"None.",
					{
						"section_key": "dead"
					},
					context
				)
			)

		"social":
			groups.append(
				emit_group_contract(
					actor,
					"Friends",
					_filter_person_ids_by_alive(
						_safe_person_id_array(
							actor,
							"friends"
						),
						true
					),
					"No visible friends.",
					{
						"premium": true,
						"section_key": "social"
					},
					context
				)
			)
			groups.append(
				emit_group_contract(
					actor,
					"Aunts / Uncles",
					_filter_person_ids_by_alive(
						aunts_uncles,
						true
					),
					"None yet.",
					{
						"section_key": "social"
					},
					context
				)
			)
			groups.append(
				emit_group_contract(
					actor,
					"Nieces / Nephews",
					_filter_person_ids_by_alive(
						nieces_nephews,
						true
					),
					"None yet.",
					{
						"section_key": "social"
					},
					context
				)
			)

		"exes":
			groups.append(
				emit_group_contract(
					actor,
					"Exes",
					_filter_person_ids_by_alive(
						_safe_person_id_array(
							actor,
							"exes"
						),
						true
					),
					"No visible exes.",
					{
						"premium": true,
						"section_key": "exes"
					},
					context
				)
			)

	return groups


func _profile_switch_packet_for_target(
	actor: Person,
	target: Person,
	context: Dictionary = {}
) -> Dictionary:
	if (
		actor == null
		or target == null
		or int(actor.id) == int(target.id)
		or not bool(target.alive)
		or float(target.health) <= 0.0
	):
		return {}

	if _context_forbids_switch_packet_resolution(
		context
	):
		return {}

	var switch_authority = switch_engine

	if (
		switch_authority == null
		and gs != null
		and gs.universal_switch_contract_engine != null
	):
		switch_authority = gs.universal_switch_contract_engine

	if (
		switch_authority == null
		or not switch_authority.has_method(
			"prewarm_profile_switch_actor_lens_core_for_actor"
		)
		or not switch_authority.has_method(
			"register_profile_pointer_packet_revision"
		)
	):
		return {}

	var target_id: int = int(
		target.id
	)
	var actor_key: String = str(
		target_id
	)
	var source: String = str(
		context.get(
			"source",
			"relationships_hub_contract_engine.profile"
		)
	).strip_edges()
	var complete_destination_required: bool = (
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
				"explicit_relationship_profile_observation",
				false
			)
		)
		or (
			source.find(
				"relationship_profile"
			) >= 0
			and source.find(
				"card"
			) < 0
		)
	)

	if bool(
		context.get(
			"relationship_card_surface_only",
			false
		)
	):
		complete_destination_required = false

	var registration_context: Dictionary = {
		"source": source,
		"observer_id": int(actor.id),
		"target_id": target_id,
		"relationship_profile_packet": true,
		"relationship_profile_visible_packet": complete_destination_required,
		"complete_destination_deck_required": complete_destination_required,
		"pointer_only_packet_forbidden": complete_destination_required,
		"relationship_card_surface_only": not complete_destination_required,
		"allow_pointer_core_only_preparation": not complete_destination_required,
		"ready_gate_member": false,
		"ui_is_renderer_only": true
	}

	if (
		gs != null
		and typeof(gs.scenario_state) == TYPE_DICTIONARY
	):
		var packet_cache_raw: Variant = gs.scenario_state.get(
			"profile_pointer_packet_by_actor",
			{}
		)

		if typeof(packet_cache_raw) == TYPE_DICTIONARY:
			var cached_packet_raw: Variant = (
				packet_cache_raw as Dictionary
			).get(
				actor_key,
				{}
			)

			if typeof(cached_packet_raw) == TYPE_DICTIONARY:
				var cached_packet: Dictionary = (
					cached_packet_raw as Dictionary
				)
				var cached_surface: Dictionary = _shallow_dictionary(
					cached_packet.get(
						"surface_contract",
						{}
					)
				)
				var cached_revision: String = str(
					cached_packet.get(
						"pointer_revision",
						""
					)
				).strip_edges()
				var cached_surface_revision: String = str(
					cached_surface.get(
						"pointer_revision",
						""
					)
				).strip_edges()
				var cached_deck: Dictionary = _shallow_dictionary(
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
				var cached_destination_hot: bool = (
					bool(
						cached_packet.get(
							"main_tab_surface_deck_hot",
							cached_surface.get(
								"main_tab_surface_deck_hot",
								false
							)
						)
					)
					and _resident_switch_main_tab_deck_is_hot_for_actor(
						cached_deck,
						target_id
					)
					and not cached_support_packet.is_empty()
				)

				if (
					bool(
						cached_packet.get(
							"success",
							false
						)
					)
					and int(
						cached_packet.get(
							"actor_id",
							-1
						)
					) == target_id
					and int(
						cached_surface.get(
							"actor_id",
							-1
						)
					) == target_id
					and cached_revision != ""
					and cached_revision == cached_surface_revision
					and cached_destination_hot
					and _resident_switch_packet_is_temporally_current_for_actor(
						cached_packet,
						target_id
					)
				):
					switch_authority.register_profile_pointer_packet_revision(
						cached_packet,
						registration_context
					)
					return cached_packet.duplicate(false)
	var packet_report: Dictionary = _shallow_dictionary(
		switch_authority.prewarm_profile_switch_actor_lens_core_for_actor(
			target,
			{
				"source": registration_context ["source"],
				"observer_id": int(actor.id),
				"target_id": target_id,
				"relationship_profile_packet": true,
				"relationship_profile_visible_packet": true,
				"complete_destination_deck_required": true,
				"pointer_only_packet_forbidden": true,
				"press_frame_build_forbidden": true,
				"full_surface_graph_required": false,
				"pointer_revision_authority": (
					"UniversalSwitchContractEngine"
				),
				"ready_gate_member": false,
				"ui_is_renderer_only": true
			}
		)
	)

	if not bool(
		packet_report.get(
			"success",
			false
		)
	):
		_queue_switch_shell_stage_for_target(
			target,
			{
				"source": registration_context ["source"],
				"relationship_priority": true,
				"complete_destination_deck_required": true,
				"pointer_only_packet_forbidden": true,
				"switch_press_build_forbidden": true,
				"ready_gate_member": false,
				"ui_is_renderer_only": true
			}
		)
		return {}

	var packet: Dictionary = _shallow_dictionary(
		packet_report.get(
			"viewer_packet",
			packet_report
		)
	)
	var surface: Dictionary = _shallow_dictionary(
		packet.get(
			"surface_contract",
			packet_report.get(
				"surface_contract",
				{}
			)
		)
	)
	var packet_revision: String = str(
		packet.get(
			"pointer_revision",
			packet_report.get(
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
	var main_tab_deck: Dictionary = _shallow_dictionary(
		packet.get(
			"main_tab_surface_contracts",
			surface.get(
				"main_tab_surface_contracts",
				{}
			)
		)
	)
	var support_packet: Dictionary = _shallow_dictionary(
		packet.get(
			"control_switch_support_surface_packet",
			surface.get(
				"control_switch_support_surface_packet",
				{}
			)
		)
	)
	if not complete_destination_required:
		var pointer_packet: Dictionary = _shallow_dictionary(
			packet_report.get(
				"viewer_packet",
				packet_report
			)
		)

		if _profile_switch_packet_core_hot(
			pointer_packet,
			target_id
		):
			return pointer_packet.duplicate(false)

		return {}
	var destination_hot: bool = (
		bool(
			packet.get(
				"main_tab_surface_deck_hot",
				surface.get(
					"main_tab_surface_deck_hot",
					false
				)
			)
		)
		and _resident_switch_main_tab_deck_is_hot_for_actor(
			main_tab_deck,
			target_id
		)
		and not support_packet.is_empty()
	)

	if (
		packet.is_empty()
		or not bool(
			packet.get(
				"success",
				false
			)
		)
		or int(
			packet.get(
				"actor_id",
				-1
			)
		) != target_id
		or surface.is_empty()
		or int(
			surface.get(
				"actor_id",
				-1
			)
		) != target_id
		or packet_revision == ""
		or packet_revision != surface_revision
		or not destination_hot
	):
		_queue_switch_shell_stage_for_target(
			target,
			{
				"source": registration_context ["source"],
				"relationship_priority": true,
				"complete_destination_deck_required": true,
				"pointer_only_packet_forbidden": true,
				"switch_press_build_forbidden": true,
				"ready_gate_member": false,
				"ui_is_renderer_only": true
			}
		)
		return {}

	var registration_report: Dictionary = (
		switch_authority.register_profile_pointer_packet_revision(
			packet,
			registration_context
		)
	)

	if not bool(
		registration_report.get(
			"success",
			false
		)
	):
		return {}

	return packet.duplicate(false)
func _stage_switch_shell_for_target(
	_observer: Person,
	target: Person,
	context: Dictionary = {}
) -> Dictionary:
	if target == null:
		return {
			"success": false,
			"producer_pending": false,
			"reason": "switch_destination_target_missing",
			"retryable": false,
			"actor_id": -1,
			"ready_gate_member": false,
			"ui_is_renderer_only": true
		}

	var target_id: int = int(
		target.id
	)

	if target_id <= 0:
		return {
			"success": false,
			"producer_pending": false,
			"reason": "switch_destination_target_id_invalid",
			"retryable": false,
			"actor_id": target_id,
			"ready_gate_member": false,
			"ui_is_renderer_only": true
		}

	var switch_authority: UniversalSwitchContractEngine = (
		_resolve_canonical_switch_engine()
	)

	if switch_authority == null:
		EraLog.truth(
			"SWITCH_PACKET_UPGRADE_ABORT"
			+ "|actor_id=" + str(target_id)
			+ "|reason=canonical_universal_switch_authority_missing"
			+ "|retryable=true"
			+ "|main_scene_binding_required=false"
			+ "|ready_gate_member=false"
			+ "|at_ms=" + str(Time.get_ticks_msec())
		)

		return {
			"success": false,
			"producer_pending": true,
			"reason": (
				"canonical_universal_switch_authority_missing"
			),
			"retryable": true,
			"actor_id": target_id,
			"complete_destination_deck_required": bool(
				context.get(
					"complete_destination_deck_required",
					false
				)
			),
			"ready_gate_member": false,
			"ui_is_renderer_only": true
		}

	var queued_context: Dictionary = _shallow_dictionary(
		context.get(
			"queued_context",
			{}
		)
	)
	var original_context: Dictionary = _shallow_dictionary(
		queued_context.get(
			"context",
			{}
		)
	)

	var explicit_complete_destination_request: bool = (
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
				"explicit_relationship_profile_observation",
				false
			)
		)
		or bool(
			context.get(
				"profile_switch_packet_required_before_visible",
				false
			)
		)
		or bool(
			context.get(
				"pointer_only_packet_forbidden",
				false
			)
		)
		or bool(
			queued_context.get(
				"complete_destination_deck_required",
				false
			)
		)
		or bool(
			queued_context.get(
				"relationship_profile_visible_packet",
				false
			)
		)
		or bool(
			queued_context.get(
				"explicit_relationship_profile_observation",
				false
			)
		)
		or bool(
			queued_context.get(
				"profile_switch_packet_required_before_visible",
				false
			)
		)
		or bool(
			queued_context.get(
				"pointer_only_packet_forbidden",
				false
			)
		)
		or bool(
			original_context.get(
				"complete_destination_deck_required",
				false
			)
		)
		or bool(
			original_context.get(
				"relationship_profile_visible_packet",
				false
			)
		)
		or bool(
			original_context.get(
				"explicit_relationship_profile_observation",
				false
			)
		)
		or bool(
			original_context.get(
				"profile_switch_packet_required_before_visible",
				false
			)
		)
		or bool(
			original_context.get(
				"pointer_only_packet_forbidden",
				false
			)
		)
	)

	var complete_destination_deck_required: bool = (
		explicit_complete_destination_request
	)




	if (
		_context_forbids_switch_packet_resolution(
			context
		)
		and not complete_destination_deck_required
	):
		return {}

	var background_only: bool = bool(
		context.get(
			"background_only",
			false
		)
	)

	if not background_only:
		var queue_context: Dictionary = (
			context.duplicate(false)
		)
		queue_context [
			"relationship_priority"
		] = true
		queue_context [
			"complete_destination_deck_required"
		] = complete_destination_deck_required
		queue_context [
			"relationship_profile_visible_packet"
		] = complete_destination_deck_required
		queue_context [
			"explicit_relationship_profile_observation"
		] = complete_destination_deck_required
		queue_context [
			"profile_switch_packet_required_before_visible"
		] = complete_destination_deck_required
		queue_context [
			"pointer_only_packet_forbidden"
		] = complete_destination_deck_required
		queue_context [
			"allow_pointer_core_only_preparation"
		] = not complete_destination_deck_required
		queue_context [
			"visible_card_may_not_publish_complete_destination_deck"
		] = not complete_destination_deck_required
		queue_context [
			"profile_switch_packet_resolution_forbidden"
		] = false
		queue_context [
			"recursive_switch_packet_publication_forbidden"
		] = false
		queue_context [
			"relationship_card_switch_packets_forbidden"
		] = false
		queue_context [
			"switch_press_build_forbidden"
		] = true
		queue_context [
			"ready_gate_member"
		] = false
		queue_context [
			"ui_is_renderer_only"
		] = true

		_queue_switch_shell_stage_for_target(
			target,
			queue_context
		)

		return {}

	var source: String = str(
		context.get(
			"source",
			(
				"relationships_hub_contract_engine."
				+ "switch_shell_background_producer"
			)
		)
	).strip_edges()

	if source == "":
		source = (
			"relationships_hub_contract_engine."
			+ "switch_shell_background_producer"
		)

	var actor_key: String = str(
		target_id
	)
	var packet_cache: Dictionary = {}

	if (
		gs != null
		and typeof(gs.scenario_state) == TYPE_DICTIONARY
	):
		packet_cache = _shallow_dictionary(
			gs.scenario_state.get(
				"profile_pointer_packet_by_actor",
				{}
			)
		)

	var resident_packet: Dictionary = _shallow_dictionary(
		packet_cache.get(
			actor_key,
			{}
		)
	)

	if complete_destination_deck_required:
		if not switch_authority.has_method(
			"prewarm_profile_switch_actor_lens_core_for_actor"
		):
			EraLog.truth(
				"SWITCH_PACKET_UPGRADE_ABORT"
				+ "|actor_id=" + str(target_id)
				+ "|reason=universal_switch_complete_producer_missing"
				+ "|pointer_core_hot=" + str(
					_profile_switch_packet_core_hot(
						resident_packet,
						target_id
					)
				)
				+ "|complete_destination_deck_required=true"
				+ "|retryable=true"
				+ "|authority=UniversalSwitchContractEngine"
				+ "|ready_gate_member=false"
				+ "|at_ms=" + str(Time.get_ticks_msec())
			)

			return {
				"success": false,
				"producer_pending": true,
				"reason": "universal_switch_complete_producer_missing",
				"retryable": true,
				"actor_id": target_id,
				"complete_destination_deck_required": true,
				"ready_gate_member": false,
				"ui_is_renderer_only": true
			}

		var producer_started_at_ms: int = int(
			Time.get_ticks_msec()
		)

		EraLog.truth(
			"SWITCH_PACKET_UPGRADE_BEGIN"
			+ "|actor_id=" + str(target_id)
			+ "|pointer_core_hot_before=" + str(
				_profile_switch_packet_core_hot(
					resident_packet,
					target_id
				)
			)
			+ "|complete_destination_deck_required=true"
			+ "|authority=UniversalSwitchContractEngine"
			+ "|background_only=true"
			+ "|build_on_press=false"
			+ "|ready_gate_member=false"
			+ "|at_ms=" + str(producer_started_at_ms)
		)

		var producer_context: Dictionary = {
			"source": (
				source
				+ ".complete_destination_upgrade"
			),
			"relationship_hub_target_id": target_id,
			"relationship_profile_packet": true,
			"relationship_profile_visible_packet": true,
			"explicit_relationship_profile_observation": true,
			"profile_switch_packet_required_before_visible": true,
			"complete_destination_deck_required": true,
			"pointer_only_packet_forbidden": true,
			"allow_pointer_core_only_preparation": false,
			"continuous_destination_preparation": true,
			"profile_switch_packet_resolution_forbidden": false,
			"recursive_switch_packet_publication_forbidden": false,
			"relationship_card_switch_packets_forbidden": false,
			"visible_card_may_not_publish_complete_destination_deck": false,
			"switch_shell_stage_forbidden": true,
			"support_packet_publication_context": true,
			"destination_support_packet_building": true,
			"switch_press_must_not_build_surface": true,
			"press_frame_build_forbidden": true,
			"build_on_click_forbidden": true,
			"ready_gate_member": false,
			"ui_is_renderer_only": true
		}

		var producer_report: Dictionary = _shallow_dictionary(
			switch_authority.prewarm_profile_switch_actor_lens_core_for_actor(
				target,
				producer_context
			)
		)
		var producer_packet: Dictionary = _shallow_dictionary(
			producer_report.get(
				"viewer_packet",
				producer_report
			)
		)
		var producer_surface: Dictionary = _shallow_dictionary(
			producer_packet.get(
				"surface_contract",
				producer_report.get(
					"surface_contract",
					{}
				)
			)
		)
		var producer_main_tab_deck: Dictionary = _shallow_dictionary(
			producer_packet.get(
				"main_tab_surface_contracts",
				producer_surface.get(
					"main_tab_surface_contracts",
					producer_report.get(
						"main_tab_surface_contracts",
						{}
					)
				)
			)
		)
		var producer_support_packet: Dictionary = _shallow_dictionary(
			producer_packet.get(
				"control_switch_support_surface_packet",
				producer_surface.get(
					"control_switch_support_surface_packet",
					producer_report.get(
						"control_switch_support_surface_packet",
						{}
					)
				)
			)
		)

		var producer_core_hot: bool = (
			_profile_switch_packet_core_hot(
				producer_packet,
				target_id
			)
		)
		var producer_main_tab_deck_hot: bool = (
			_resident_switch_main_tab_deck_is_hot_for_actor(
				producer_main_tab_deck,
				target_id
			)
		)
		var producer_support_packet_hot: bool = (
			not producer_support_packet.is_empty()
			and bool(
				producer_support_packet.get(
					"main_tab_surface_deck_hot",
					producer_report.get(
						"main_tab_surface_deck_hot",
						false
					)
				)
			)
		)
		var producer_destination_hot: bool = (
			bool(
				producer_report.get(
					"success",
					false
				)
			)
			and producer_core_hot
			and producer_main_tab_deck_hot
			and producer_support_packet_hot
		)

		if not producer_destination_hot:
			var producer_reason: String = str(
				producer_report.get(
					"reason",
					(
						"universal_switch_complete_destination_packet_pending"
						if producer_core_hot
						else "universal_switch_pointer_core_pending"
					)
				)
			).strip_edges()

			if producer_reason == "":
				producer_reason = (
					"universal_switch_complete_destination_packet_pending"
				)

			EraLog.truth(
				"SWITCH_PACKET_UPGRADE_ABORT"
				+ "|actor_id=" + str(target_id)
				+ "|reason=" + producer_reason
				+ "|pointer_core_hot=" + str(producer_core_hot)
				+ "|main_tab_surface_deck_hot=" + str(
					producer_main_tab_deck_hot
				)
				+ "|support_packet_hot=" + str(
					producer_support_packet_hot
				)
				+ "|missing_main_tabs=" + str(
					_shallow_array(
						producer_report.get(
							"missing_main_tabs",
							[]
						)
					)
				)
				+ "|retryable=" + str(
					bool(
						producer_report.get(
							"retryable",
							true
						)
					)
				)
				+ "|duration_ms=" + str(
					maxi(
						0,
						int(
							Time.get_ticks_msec()
						) - producer_started_at_ms
					)
				)
				+ "|authority=UniversalSwitchContractEngine"
				+ "|ready_gate_member=false"
				+ "|at_ms=" + str(Time.get_ticks_msec())
			)

			return {
				"success": false,
				"producer_pending": true,
				"reason": producer_reason,
				"retryable": bool(
					producer_report.get(
						"retryable",
						true
					)
				),
				"actor_id": target_id,
				"pointer_core_hot": producer_core_hot,
				"main_tab_surface_deck_hot": producer_main_tab_deck_hot,
				"support_packet_hot": producer_support_packet_hot,
				"missing_main_tabs": _shallow_array(
					producer_report.get(
						"missing_main_tabs",
						[]
					)
				),
				"producer_report": producer_report.duplicate(false),
				"complete_destination_deck_required": true,
				"switch_readiness_authority": (
					"UniversalSwitchContractEngine"
				),
				"ready_gate_member": false,
				"ui_is_renderer_only": true
			}

		EraLog.truth(
			"SWITCH_PACKET_UPGRADE_SUPPORT_READY"
			+ "|actor_id=" + str(target_id)
			+ "|pointer_core_hot=true"
			+ "|main_tab_surface_deck_hot=true"
			+ "|support_packet_hot=true"
			+ "|authority=UniversalSwitchContractEngine"
			+ "|build_on_press=false"
			+ "|ready_gate_member=false"
			+ "|at_ms=" + str(Time.get_ticks_msec())
		)

		EraLog.truth(
			"SWITCH_PACKET_PUBLISH_COMPLETE"
			+ "|actor_id=" + str(target_id)
			+ "|registry=profile_pointer_packet_by_actor"
			+ "|support_registry=resident_control_switch_support_surface_packet_by_actor"
			+ "|complete_destination_packet_visible=true"
			+ "|authority=UniversalSwitchContractEngine"
			+ "|duration_ms=" + str(
				maxi(
					0,
					int(
						Time.get_ticks_msec()
					) - producer_started_at_ms
				)
			)
			+ "|ready_gate_member=false"
			+ "|at_ms=" + str(Time.get_ticks_msec())
		)

		return {
			"success": true,
			"mode": "universal_switch_complete_destination_packet_hot",
			"actor_id": target_id,
			"viewer_packet": producer_packet.duplicate(false),
			"surface_contract": producer_surface.duplicate(false),
			"main_tab_surface_contracts": (
				producer_main_tab_deck.duplicate(false)
			),
			"control_switch_support_surface_packet": (
				producer_support_packet.duplicate(false)
			),
			"main_tab_surface_deck_hot": true,
			"complete_destination_deck_required": true,
			"switch_readiness_authority": (
				"UniversalSwitchContractEngine"
			),
			"ready_gate_member": false,
			"ui_is_renderer_only": true
		}

	if not _profile_switch_packet_core_hot(
		resident_packet,
		target_id
	):
		if not switch_authority.has_method(
			"prewarm_profile_switch_actor_lens_core_for_actor"
		):
			return {
				"success": false,
				"producer_pending": true,
				"reason": (
					"universal_switch_pointer_core_producer_missing"
				),
				"retryable": true,
				"actor_id": target_id,
				"complete_destination_deck_required": false,
				"ready_gate_member": false,
				"ui_is_renderer_only": true
			}

		var pointer_report: Dictionary = _shallow_dictionary(
			switch_authority.prewarm_profile_switch_actor_lens_core_for_actor(
				target,
				{
					"source": (
						source
						+ ".pointer_core_only"
					),
					"relationship_hub_target_id": target_id,
					"relationship_card_surface_only": true,
					"complete_destination_deck_required": false,
					"relationship_profile_visible_packet": false,
					"profile_switch_packet_required_before_visible": false,
					"pointer_only_packet_forbidden": false,
					"allow_pointer_core_only_preparation": true,
					"switch_press_must_not_build_surface": true,
					"ready_gate_member": false,
					"ui_is_renderer_only": true
				}
			)
		)

		if not bool(
			pointer_report.get(
				"success",
				false
			)
		):
			return {}

		if (
			gs != null
			and typeof(gs.scenario_state) == TYPE_DICTIONARY
		):
			packet_cache = _shallow_dictionary(
				gs.scenario_state.get(
					"profile_pointer_packet_by_actor",
					{}
				)
			)
			resident_packet = _shallow_dictionary(
				packet_cache.get(
					actor_key,
					pointer_report.get(
						"viewer_packet",
						pointer_report
					)
				)
			)
		else:
			resident_packet = _shallow_dictionary(
				pointer_report.get(
					"viewer_packet",
					pointer_report
				)
			)

	if not _profile_switch_packet_core_hot(
		resident_packet,
		target_id
	):
		return {}

	return {
		"success": true,
		"mode": "resident_switch_pointer_core_only_hot",
		"pointer_core_only": true,
		"actor_id": target_id,
		"viewer_packet": resident_packet.duplicate(false),
		"surface_contract": _shallow_dictionary(
			resident_packet.get(
				"surface_contract",
				{}
			)
		),
		"main_tab_surface_deck_hot": false,
		"complete_destination_deck_required": false,
		"relationship_card_surface_only": true,
		"switch_readiness_authority": (
			"UniversalSwitchContractEngine"
		),
		"ready_gate_member": false,
		"ui_is_renderer_only": true
	}
func _resident_switch_main_tab_deck_is_hot_for_actor(
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
		var tab_contract: Dictionary = _shallow_dictionary(
			deck.get(
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


func _resident_switch_main_tab_deck_for_actor(
	target_id: int
) -> Dictionary:
	if (
		gs == null
		or target_id <= 0
		or typeof(gs.scenario_state) != TYPE_DICTIONARY
	):
		return {}

	var actor_key: String = str(
		target_id
	)
	var deck_by_actor: Dictionary = _shallow_dictionary(
		gs.scenario_state.get(
			"resident_main_tab_surface_contracts_by_actor",
			{}
		)
	)
	var resident_deck: Dictionary = _shallow_dictionary(
		deck_by_actor.get(
			actor_key,
			{}
		)
	)

	if _resident_switch_main_tab_deck_is_hot_for_actor(
		resident_deck,
		target_id
	):
		return resident_deck

	for raw_registry_name in [
		"resident_control_switch_support_surface_packet_by_actor",
		"observable_control_switch_support_surface_packet_by_actor"
	]:
		var registry_name: String = str(
			raw_registry_name
		)
		var registry: Dictionary = _shallow_dictionary(
			gs.scenario_state.get(
				registry_name,
				{}
			)
		)
		var packet: Dictionary = _shallow_dictionary(
			registry.get(
				actor_key,
				{}
			)
		)
		var packet_deck: Dictionary = _shallow_dictionary(
			packet.get(
				"main_tab_surface_contracts",
				{}
			)
		)

		if _resident_switch_main_tab_deck_is_hot_for_actor(
			packet_deck,
			target_id
		):
			return packet_deck

	var profile_cache: Dictionary = _shallow_dictionary(
		gs.scenario_state.get(
			"profile_pointer_packet_by_actor",
			{}
		)
	)
	var profile_packet: Dictionary = _shallow_dictionary(
		profile_cache.get(
			actor_key,
			{}
		)
	)
	var profile_surface: Dictionary = _shallow_dictionary(
		profile_packet.get(
			"surface_contract",
			{}
		)
	)
	var profile_deck: Dictionary = _shallow_dictionary(
		profile_packet.get(
			"main_tab_surface_contracts",
			profile_surface.get(
				"main_tab_surface_contracts",
				{}
			)
		)
	)

	if _resident_switch_main_tab_deck_is_hot_for_actor(
		profile_deck,
		target_id
	):
		return profile_deck

	return {}
func _complete_switch_destination_upgrade_requested(
	context: Dictionary
) -> bool:
	if context.is_empty():
		return false

	return (
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
				"explicit_relationship_profile_observation",
				false
			)
		)
		or bool(
			context.get(
				"profile_switch_packet_required_before_visible",
				false
			)
		)
		or bool(
			context.get(
				"pointer_only_packet_forbidden",
				false
			)
		)
	)


func _queue_switch_destination_upgrade_for_target(
	target: Person,
	context: Dictionary = {}
) -> void:
	if target == null:
		return

	var target_id: int = int(
		target.id
	)

	if target_id <= 0:
		return

	var complete_packet: Dictionary = (
		_resident_complete_switch_packet_for_actor(
			target_id
		)
	)

	if not complete_packet.is_empty():
		switch_destination_upgrade_seen.erase(
			target_id
		)
		return

	var now_ms: int = int(
		Time.get_ticks_msec()
	)
	var upgrade_context: Dictionary = (
		context.duplicate(false)
	)



	upgrade_context [
		"complete_destination_deck_required"
	] = true
	upgrade_context [
		"relationship_profile_visible_packet"
	] = true
	upgrade_context [
		"explicit_relationship_profile_observation"
	] = true
	upgrade_context [
		"profile_switch_packet_required_before_visible"
	] = true
	upgrade_context [
		"pointer_only_packet_forbidden"
	] = true
	upgrade_context [
		"allow_pointer_core_only_preparation"
	] = false
	upgrade_context [
		"visible_card_may_not_publish_complete_destination_deck"
	] = false
	upgrade_context [
		"profile_switch_packet_resolution_forbidden"
	] = false
	upgrade_context [
		"recursive_switch_packet_publication_forbidden"
	] = false
	upgrade_context [
		"relationship_card_switch_packets_forbidden"
	] = false
	upgrade_context [
		"switch_shell_stage_forbidden"
	] = false
	upgrade_context [
		"support_packet_publication_context"
	] = false
	upgrade_context [
		"destination_support_packet_building"
	] = false
	upgrade_context [
		"relationship_priority"
	] = true
	upgrade_context [
		"switch_destination_upgrade_lane"
	] = true
	upgrade_context [
		"background_only"
	] = true
	upgrade_context [
		"blocks_ui"
	] = false
	upgrade_context [
		"switch_press_build_forbidden"
	] = true
	upgrade_context [
		"switch_press_must_not_build_surface"
	] = true
	upgrade_context [
		"ready_gate_member"
	] = false
	upgrade_context [
		"ui_is_renderer_only"
	] = true

	if switch_destination_upgrade_seen.has(
		target_id
	):
		var upgraded_existing_row: bool = false

		for index in range(
			switch_destination_upgrade_queue.size()
		):
			var existing_row: Dictionary = _shallow_dictionary(
				switch_destination_upgrade_queue [
					index
				]
			)

			if int(
				existing_row.get(
					"target_id",
					-1
				)
			) != target_id:
				continue

			existing_row [
				"context"
			] = upgrade_context.duplicate(false)
			existing_row [
				"complete_destination_deck_required"
			] = true
			existing_row [
				"relationship_profile_visible_packet"
			] = true
			existing_row [
				"explicit_relationship_profile_observation"
			] = true
			existing_row [
				"pointer_only_packet_forbidden"
			] = true
			existing_row [
				"pointer_core_only_allowed"
			] = false
			existing_row [
				"pointer_core_is_not_completion_authority"
			] = true
			existing_row [
				"next_allowed_at_ms"
			] = mini(
				int(
					existing_row.get(
						"next_allowed_at_ms",
						now_ms
					)
				),
				now_ms
			)
			existing_row [
				"last_observed_at_ms"
			] = now_ms
			existing_row [
				"critical_lane"
			] = true
			existing_row [
				"ready_gate_member"
			] = false

			switch_destination_upgrade_queue [
				index
			] = existing_row
			upgraded_existing_row = true
			break

		if upgraded_existing_row:
			_ensure_switch_destination_upgrade_pump()
			return

		switch_destination_upgrade_seen.erase(
			target_id
		)

	var row: Dictionary = {
		"target_id": target_id,
		"context": upgrade_context.duplicate(false),
		"queued_at_ms": now_ms,
		"next_allowed_at_ms": now_ms,
		"attempt_count": 0,
		"complete_destination_deck_required": true,
		"relationship_profile_visible_packet": true,
		"explicit_relationship_profile_observation": true,
		"pointer_only_packet_forbidden": true,
		"pointer_core_only_allowed": false,
		"pointer_core_is_not_completion_authority": true,
		"critical_lane": true,
		"switch_destination_upgrade_lane": true,
		"switch_readiness_authority": (
			"UniversalSwitchContractEngine"
		),
		"switch_press_build_forbidden": true,
		"ready_gate_member": false,
		"ui_is_renderer_only": true
	}

	switch_destination_upgrade_seen [
		target_id
	] = true
	switch_destination_upgrade_queue.append(
		row
	)

	if (
		gs != null
		and typeof(gs.scenario_state) == TYPE_DICTIONARY
	):
		gs.scenario_state [
			"relationship_switch_destination_upgrade_queue_size"
		] = switch_destination_upgrade_queue.size()
		gs.scenario_state [
			"relationship_switch_destination_upgrade_last_actor_id"
		] = target_id
		gs.scenario_state [
			"relationship_switch_destination_upgrade_last_queued_at_ms"
		] = now_ms
		gs.scenario_state [
			"relationship_switch_destination_upgrade_service_owner"
		] = "RelationshipsHubContractEngine"
		gs.scenario_state [
			"relationship_switch_destination_upgrade_main_scene_service_required"
		] = false
		gs.scenario_state [
			"relationship_switch_destination_upgrade_ready_gate_member"
		] = false

	EraLog.truth(
		"SWITCH_DESTINATION_UPGRADE_LANE_QUEUED"
		+ "|actor_id=" + str(target_id)
		+ "|queue_size=" + str(
			switch_destination_upgrade_queue.size()
		)
		+ "|service_owner=RelationshipsHubContractEngine"
		+ "|producer_authority=UniversalSwitchContractEngine"
		+ "|main_scene_service_required=false"
		+ "|blocks_ui=false"
		+ "|ready_gate_member=false"
		+ "|at_ms=" + str(now_ms)
	)

	_ensure_switch_destination_upgrade_pump()
func _switch_destination_upgrade_pump_delay_seconds() -> float:
	if switch_destination_upgrade_queue.is_empty():
		return (
			SWITCH_DESTINATION_UPGRADE_PUMP_MIN_DELAY_SECONDS
		)

	var now_ms: int = int(
		Time.get_ticks_msec()
	)
	var earliest_allowed_ms: int = now_ms
	var found_row: bool = false

	for raw_row in switch_destination_upgrade_queue:
		var row: Dictionary = _shallow_dictionary(
			raw_row
		)
		var target_id: int = int(
			row.get(
				"target_id",
				-1
			)
		)

		if target_id <= 0:
			continue

		var row_allowed_ms: int = int(
			row.get(
				"next_allowed_at_ms",
				now_ms
			)
		)

		if not found_row:
			earliest_allowed_ms = row_allowed_ms
			found_row = true
		else:
			earliest_allowed_ms = mini(
				earliest_allowed_ms,
				row_allowed_ms
			)

	if not found_row:
		return (
			SWITCH_DESTINATION_UPGRADE_PUMP_MIN_DELAY_SECONDS
		)

	var remaining_ms: int = maxi(
		0,
		earliest_allowed_ms - now_ms
	)




	if remaining_ms <= 0:
		return 0.0

	return clampf(
		float(remaining_ms) / 1000.0,
		SWITCH_DESTINATION_UPGRADE_PUMP_MIN_DELAY_SECONDS,
		SWITCH_DESTINATION_UPGRADE_PUMP_MAX_DELAY_SECONDS
	)

func _ensure_switch_destination_upgrade_pump() -> void:
	if switch_destination_upgrade_queue.is_empty():
		switch_destination_upgrade_pump_armed = false
		return

	if switch_destination_upgrade_pump_armed:
		return

	var head_row: Dictionary = _shallow_dictionary(
		switch_destination_upgrade_queue [
			0
		]
	)
	var head_context: Dictionary = _shallow_dictionary(
		head_row.get(
			"context",
			{}
		)
	)
	var detached_service_only: bool = bool(
		head_context.get(
			"detached_service_only",
			false
		)
	)







	if detached_service_only:
		switch_destination_upgrade_pump_armed = false

		if (
			gs != null
			and typeof(gs.scenario_state) == TYPE_DICTIONARY
		):
			gs.scenario_state [
				"relationship_switch_destination_upgrade_pump_armed"
			] = false
			gs.scenario_state [
				"relationship_switch_destination_upgrade_service_owner"
			] = (
				"RelationshipsHubContractEngine."
				+ "detached_resident_projection_worker"
			)
			gs.scenario_state [
				"relationship_switch_destination_upgrade_scene_tree_service_forbidden"
			] = true
			gs.scenario_state [
				"relationship_switch_destination_upgrade_detached_service_only"
			] = true
			gs.scenario_state [
				"relationship_switch_destination_upgrade_waiting_for_detached_worker"
			] = true
			gs.scenario_state [
				"relationship_switch_destination_upgrade_ui_gated"
			] = false
			gs.scenario_state [
				"relationship_switch_destination_upgrade_requires_input_idle"
			] = false
			gs.scenario_state [
				"relationship_switch_destination_upgrade_ready_gate_member"
			] = false

		return






	if not resident_projection_work_by_signature.is_empty():
		switch_destination_upgrade_pump_armed = true

		if (
			gs != null
			and typeof(gs.scenario_state) == TYPE_DICTIONARY
		):
			gs.scenario_state [
				"relationship_switch_destination_upgrade_pump_armed"
			] = true
			gs.scenario_state [
				"relationship_switch_destination_upgrade_service_owner"
			] = (
				"RelationshipsHubContractEngine."
				+ "detached_resident_projection_worker"
			)
			gs.scenario_state [
				"relationship_switch_destination_upgrade_scene_tree_service_forbidden"
			] = true
			gs.scenario_state [
				"relationship_switch_destination_upgrade_ui_gated"
			] = false
			gs.scenario_state [
				"relationship_switch_destination_upgrade_requires_input_idle"
			] = false
			gs.scenario_state [
				"relationship_switch_destination_upgrade_ready_gate_member"
			] = false

		return




	var tree:= Engine.get_main_loop() as SceneTree

	if tree == null:
		call_deferred(
			"_ensure_switch_destination_upgrade_pump"
		)
		return

	var delay_seconds: float = (
		_switch_destination_upgrade_pump_delay_seconds()
	)

	switch_destination_upgrade_pump_generation += 1

	var generation: int = (
		switch_destination_upgrade_pump_generation
	)

	switch_destination_upgrade_pump_armed = true

	if (
		gs != null
		and typeof(gs.scenario_state) == TYPE_DICTIONARY
	):
		gs.scenario_state [
			"relationship_switch_destination_upgrade_pump_armed"
		] = true
		gs.scenario_state [
			"relationship_switch_destination_upgrade_pump_generation"
		] = generation
		gs.scenario_state [
			"relationship_switch_destination_upgrade_pump_delay_ms"
		] = int(
			round(
				delay_seconds * 1000.0
			)
		)
		gs.scenario_state [
			"relationship_switch_destination_upgrade_pump_one_quantum"
		] = true
		gs.scenario_state [
			"relationship_switch_destination_upgrade_pump_ui_gated"
		] = false
		gs.scenario_state [
			"relationship_switch_destination_upgrade_pump_ready_gate_member"
		] = false
		gs.scenario_state [
			"relationship_switch_destination_upgrade_first_quantum_deferred_immediately"
		] = (
			delay_seconds <= 0.0
		)
		gs.scenario_state [
			"relationship_switch_destination_upgrade_legacy_nonresident_fallback"
		] = true

	if delay_seconds <= 0.0:
		call_deferred(
			"_switch_destination_upgrade_pump_frame",
			generation
		)
		return

	var timer:= tree.create_timer(
		delay_seconds,
		true,
		false,
		true
	)
	var callback: Callable = Callable(
		self,
		"_switch_destination_upgrade_pump_frame"
	).bind(
		generation
	)
	var connection_error: int = timer.timeout.connect(
		callback,
		CONNECT_ONE_SHOT
	)

	if connection_error != OK:
		switch_destination_upgrade_pump_armed = false
		call_deferred(
			"_ensure_switch_destination_upgrade_pump"
		)
func _publish_resident_switch_destination_upgrade_packets(
	staged_packets: Dictionary
) -> void:
	if staged_packets.is_empty():
		return

	for raw_target_key in staged_packets.keys():
		var published_target_id: int = int(
			raw_target_key
		)
		var packet_raw: Variant = staged_packets.get(
			raw_target_key,
			{}
		)
		var published_packet: Dictionary = (
			packet_raw as Dictionary
			if typeof(packet_raw) == TYPE_DICTIONARY
			else {}
		)

		if (
			published_target_id <= 0
			or published_packet.is_empty()
		):
			continue

		resident_switch_destination_packet_published.emit(
			published_target_id,
			published_packet.duplicate(false)
		)
func _service_resident_switch_destination_upgrade_quantum() -> Dictionary:
	var out: Dictionary = {
		"success": true,
		"serviced": false,
		"complete": switch_destination_upgrade_queue.is_empty(),
		"remaining": switch_destination_upgrade_queue.size(),
		"service_lane": "detached_resident_projection_worker",
		"ready_gate_member": false,
		"max_full_destination_upgrades_per_process_frame": 1,
		"min_process_frames_between_full_destination_upgrades": 2
	}

	if switch_destination_upgrade_queue.is_empty():
		switch_destination_upgrade_pump_armed = false
		return out




	if not switch_shell_stage_queue.is_empty():
		out ["yielded_to_pointer_core_lane"] = true
		out ["complete"] = false
		return out

	var head_row: Dictionary = _shallow_dictionary(
		switch_destination_upgrade_queue [0]
	)
	var target_id: int = int(
		head_row.get(
			"target_id",
			-1
		)
	)
	var next_allowed_at_ms: int = int(
		head_row.get(
			"next_allowed_at_ms",
			0
		)
	)
	var now_ms: int = int(
		Time.get_ticks_msec()
	)

	if next_allowed_at_ms > now_ms:
		out ["waiting_for_retry_window"] = true
		out ["next_allowed_at_ms"] = next_allowed_at_ms
		return out




	var process_frame_id: int = int(
		Engine.get_process_frames()
	)
	var last_service_frame: int = int(
		get_meta(
			"resident_switch_destination_upgrade_last_service_frame",
			-1
		)
	)

	var min_frame_gap: int = 2
	if (
		last_service_frame >= 0
		and process_frame_id - last_service_frame < min_frame_gap
	):
		out ["yielded_to_process_frame_budget"] = true
		out ["process_frame_id"] = process_frame_id
		out ["min_process_frames_between_upgrades"] = min_frame_gap
		return out

	set_meta(
		"resident_switch_destination_upgrade_last_service_frame",
		process_frame_id
	)

	var actor_scalar_truth_report: Dictionary = (
		_prepare_switch_destination_actor_scalar_truth(
			target_id
		)
	)

	var flush_report: Dictionary = (
		flush_switch_destination_upgrade_queue(
			1,
			{
				"source": (
					"relationships_hub_contract_engine."
					+ "resident_projection_destination_upgrade_tail"
				),
				"critical_switch_destination_lane": true,
				"ui_interaction_grace_ignored": true,
				"background_only": true,
				"blocks_ui": false,
				"switch_press_must_not_build_surface": true,
				"ready_gate_member": false,
				"ui_is_renderer_only": true
			}
		)
	)

	var staged_packets_raw: Variant = flush_report.get(
		"staged_packets_by_actor",
		{}
	)
	var staged_packets: Dictionary = (
		(staged_packets_raw as Dictionary).duplicate(false)
		if typeof(staged_packets_raw) == TYPE_DICTIONARY
		else {}
	)






	if not staged_packets.is_empty():
		call_deferred(
			"_publish_resident_switch_destination_upgrade_packets",
			staged_packets
		)

	out ["serviced"] = true
	out ["actor_id"] = target_id
	out ["actor_scalar_truth_report"] = actor_scalar_truth_report.duplicate(false)
	out ["flush_report"] = flush_report.duplicate(false)
	out ["complete"] = switch_destination_upgrade_queue.is_empty()
	out ["remaining"] = switch_destination_upgrade_queue.size()
	out ["process_frame_id"] = process_frame_id

	switch_destination_upgrade_pump_armed = (
		not switch_destination_upgrade_queue.is_empty()
	)

	return out
func _prepare_switch_destination_actor_scalar_truth(
	target_id: int
) -> Dictionary:
	if (
		target_id <= 0
		or gs == null
	):
		return {
			"success": false,
			"reason": "invalid_switch_destination_actor"
		}

	var target: Person = _person_by_id(
		target_id
	)

	if target == null:
		return {
			"success": false,
			"reason": "switch_destination_actor_unavailable",
			"actor_id": target_id
		}

	var legacy_person_hunger: float = float(
		target.hunger
	)
	var hunger_contract: Dictionary = {}

	if (
		gs.food_engine != null
		and gs.food_engine.has_method(
			"hunger_scalar_contract_for_actor"
		)
	):
		hunger_contract = (
			gs.food_engine.hunger_scalar_contract_for_actor(
				target_id
			)
		)

	var food_profile_hot: bool = (
		bool(
			hunger_contract.get(
				"success",
				false
			)
		)
		and int(
			hunger_contract.get(
				"actor_id",
				-1
			)
		) == target_id
	)
	var published_hunger: float = legacy_person_hunger

	if food_profile_hot:
		published_hunger = float(
			hunger_contract.get(
				"hunger",
				legacy_person_hunger
			)
		)

	return {
		"success": food_profile_hot or published_hunger >= 0.0,
		"schema": "eralife.switch_destination_actor_scalar_truth",
		"actor_id": target_id,
		"hunger_before": legacy_person_hunger,
		"hunger_after": published_hunger,
		"hunger_resolved": published_hunger >= 0.0,
		"food_profile_hot": food_profile_hot,
		"simulation_mutation_performed": false,
		"simulation_authority": (
			"FoodEngine.hunger_scalar_contract"
			if food_profile_hot
			else "Person.hunger_fallback"
		),
		"observation_authority": "RelationshipsHubContractEngine",
		"background_only": true,
		"ready_gate_member": false,
		"prepared_at_ms": int(
			Time.get_ticks_msec()
		)
	}
func _switch_destination_upgrade_pump_frame(
	generation: int
) -> void:
	if generation != switch_destination_upgrade_pump_generation:
		return

	switch_destination_upgrade_pump_armed = false

	var target_id: int = -1

	if not switch_destination_upgrade_queue.is_empty():
		var head_row: Dictionary = _shallow_dictionary(
			switch_destination_upgrade_queue [
				0
			]
		)
		target_id = int(
			head_row.get(
				"target_id",
				-1
			)
		)




	var actor_scalar_truth_report: Dictionary = (
		_prepare_switch_destination_actor_scalar_truth(
			target_id
		)
	)

	var report: Dictionary = (
		flush_switch_destination_upgrade_queue(
			1,
			{
				"source": (
					"relationships_hub_contract_engine."
					+ "switch_destination_upgrade_pump"
				),
				"critical_switch_destination_lane": true,
				"ui_interaction_grace_ignored": true,
				"background_only": true,
				"blocks_ui": false,
				"switch_press_must_not_build_surface": true,
				"ready_gate_member": false,
				"ui_is_renderer_only": true
			}
		)
	)

	report [
		"actor_scalar_truth_report"
	] = actor_scalar_truth_report.duplicate(false)
	report [
		"actor_scalar_truth_prepared_before_packet"
	] = true






	var staged_packets_raw: Variant = report.get(
		"staged_packets_by_actor",
		{}
	)
	var staged_packets: Dictionary = (
		staged_packets_raw as Dictionary
		if typeof(
			staged_packets_raw
		) == TYPE_DICTIONARY
		else {}
	)

	for raw_target_key in staged_packets.keys():
		var published_target_id: int = int(
			raw_target_key
		)
		var published_packet: Dictionary = _shallow_dictionary(
			staged_packets.get(
				raw_target_key,
				{}
			)
		)

		if (
			published_target_id <= 0
			or published_packet.is_empty()
		):
			continue

		resident_switch_destination_packet_published.emit(
			published_target_id,
			published_packet.duplicate(false)
		)

	report [
		"complete_destination_packets_pushed_to_observers"
	] = staged_packets.size()
	report [
		"destination_publication_is_push_based"
	] = true
	report [
		"profile_press_required_for_publication"
	] = false

	if (
		gs != null
		and typeof(gs.scenario_state) == TYPE_DICTIONARY
	):
		gs.scenario_state [
			"relationship_switch_destination_upgrade_last_pump_report"
		] = report.duplicate(true)
		gs.scenario_state [
			"relationship_switch_destination_upgrade_last_pump_at_ms"
		] = int(
			Time.get_ticks_msec()
		)
		gs.scenario_state [
			"relationship_switch_destination_upgrade_pump_armed"
		] = false

	if not switch_destination_upgrade_queue.is_empty():
		_ensure_switch_destination_upgrade_pump()
func flush_switch_destination_upgrade_queue(
	max_count: int = 1,
	context: Dictionary = {}
) -> Dictionary:
	var limit: int = maxi(
		1,
		max_count
	)
	var processed: int = 0
	var staged: int = 0
	var requeued: int = 0
	var failures: Array = []
	var staged_packets_by_actor: Dictionary = {}
	var delayed_rows: Array = []
	var now_ms: int = int(
		Time.get_ticks_msec()
	)

	while (
		processed < limit
		and not switch_destination_upgrade_queue.is_empty()
	):
		var row: Dictionary = _shallow_dictionary(
			switch_destination_upgrade_queue.pop_front()
		).duplicate(true)

		processed += 1

		var target_id: int = int(
			row.get(
				"target_id",
				-1
			)
		)
		var target: Person = _person_by_id(
			target_id
		)

		if target == null:
			switch_destination_upgrade_seen.erase(
				target_id
			)
			failures.append(
				{
					"target_id": target_id,
					"reason": "target_missing",
					"retryable": false
				}
			)
			continue

		var next_allowed_ms: int = int(
			row.get(
				"next_allowed_at_ms",
				0
			)
		)

		if next_allowed_ms > now_ms:
			delayed_rows.append(
				row
			)
			requeued += 1
			continue

		var already_complete_packet: Dictionary = (
			_resident_complete_switch_packet_for_actor(
				target_id
			)
		)

		if not already_complete_packet.is_empty():
			switch_destination_upgrade_seen.erase(
				target_id
			)
			staged += 1
			staged_packets_by_actor [
				str(target_id)
			] = already_complete_packet.duplicate(false)

			EraLog.truth(
				"SWITCH_DESTINATION_UPGRADE_LANE_FINISH"
				+ "|actor_id=" + str(target_id)
				+ "|mode=authoritative_registry_cache_hit"
				+ "|complete_destination_packet_visible=true"
				+ "|producer_authority=UniversalSwitchContractEngine"
				+ "|ready_gate_member=false"
				+ "|at_ms=" + str(Time.get_ticks_msec())
			)
			continue

		var row_context: Dictionary = _shallow_dictionary(
			row.get(
				"context",
				{}
			)
		)
		var stage_context: Dictionary = (
			row_context.duplicate(false)
		)



		stage_context [
			"source"
		] = str(
			context.get(
				"source",
				row_context.get(
					"source",
					(
						"relationships_hub_contract_engine."
						+ "switch_destination_upgrade_queue"
					)
				)
			)
		)
		stage_context [
			"queued_context"
		] = row.duplicate(false)
		stage_context [
			"complete_destination_deck_required"
		] = true
		stage_context [
			"relationship_profile_visible_packet"
		] = true
		stage_context [
			"explicit_relationship_profile_observation"
		] = true
		stage_context [
			"profile_switch_packet_required_before_visible"
		] = true
		stage_context [
			"pointer_only_packet_forbidden"
		] = true
		stage_context [
			"allow_pointer_core_only_preparation"
		] = false
		stage_context [
			"visible_card_may_not_publish_complete_destination_deck"
		] = false
		stage_context [
			"profile_switch_packet_resolution_forbidden"
		] = false
		stage_context [
			"recursive_switch_packet_publication_forbidden"
		] = false
		stage_context [
			"relationship_card_switch_packets_forbidden"
		] = false
		stage_context [
			"switch_shell_stage_forbidden"
		] = false
		stage_context [
			"support_packet_publication_context"
		] = false
		stage_context [
			"destination_support_packet_building"
		] = false
		stage_context [
			"critical_switch_destination_lane"
		] = true
		stage_context [
			"background_only"
		] = true
		stage_context [
			"blocks_ui"
		] = false
		stage_context [
			"switch_press_build_forbidden"
		] = true
		stage_context [
			"switch_press_must_not_build_surface"
		] = true
		stage_context [
			"ready_gate_member"
		] = false
		stage_context [
			"ui_is_renderer_only"
		] = true

		EraLog.truth(
			"SWITCH_DESTINATION_UPGRADE_LANE_SERVICE_BEGIN"
			+ "|actor_id=" + str(target_id)
			+ "|attempt=" + str(
				int(
					row.get(
						"attempt_count",
						0
					)
				) + 1
			)
			+ "|profile_visible_may_not_block=true"
			+ "|interaction_grace_may_not_block=true"
			+ "|producer_authority=UniversalSwitchContractEngine"
			+ "|ready_gate_member=false"
			+ "|at_ms=" + str(Time.get_ticks_msec())
		)

		var shell: Dictionary = (
			_stage_switch_shell_for_target(
				null,
				target,
				stage_context
			)
		)

		var authoritative_packet: Dictionary = (
			_resident_complete_switch_packet_for_actor(
				target_id
			)
		)

		if not authoritative_packet.is_empty():
			switch_destination_upgrade_seen.erase(
				target_id
			)
			staged += 1
			staged_packets_by_actor [
				str(target_id)
			] = authoritative_packet.duplicate(false)

			if (
				gs != null
				and typeof(gs.scenario_state) == TYPE_DICTIONARY
			):
				gs.scenario_state [
					"relationship_switch_destination_upgrade_completed_actor_id"
				] = target_id
				gs.scenario_state [
					"relationship_switch_destination_upgrade_completed_at_ms"
				] = int(
					Time.get_ticks_msec()
				)
				gs.scenario_state [
					"relationship_switch_destination_upgrade_packet_authority"
				] = "UniversalSwitchContractEngine"
				gs.scenario_state [
					"relationship_switch_destination_upgrade_support_deck_hot"
				] = true
				gs.scenario_state [
					"relationship_switch_destination_upgrade_ready_gate_member"
				] = false

			EraLog.truth(
				"SWITCH_DESTINATION_UPGRADE_LANE_FINISH"
				+ "|actor_id=" + str(target_id)
				+ "|complete_destination_packet_visible=true"
				+ "|support_deck_hot=true"
				+ "|producer_authority=UniversalSwitchContractEngine"
				+ "|main_scene_service_required=false"
				+ "|ready_gate_member=false"
				+ "|at_ms=" + str(Time.get_ticks_msec())
			)
			continue

		var retryable: bool = true
		var failure_reason: String = (
			"complete_destination_packet_not_published"
		)

		if shell.is_empty():
			failure_reason = (
				"switch_destination_stage_returned_empty"
			)
		elif bool(
			shell.get(
				"pointer_core_only",
				false
			)
		):
			failure_reason = (
				"pointer_core_returned_in_complete_destination_lane"
			)
		elif bool(
			shell.get(
				"producer_pending",
				false
			)
		):
			failure_reason = str(
				shell.get(
					"reason",
					"universal_switch_destination_producer_pending"
				)
			).strip_edges()
			retryable = bool(
				shell.get(
					"retryable",
					true
				)
			)
		elif not bool(
			shell.get(
				"success",
				false
			)
		):
			failure_reason = str(
				shell.get(
					"reason",
					"universal_switch_destination_upgrade_failed"
				)
			).strip_edges()
			retryable = bool(
				shell.get(
					"retryable",
					true
				)
			)

		if failure_reason == "":
			failure_reason = (
				"complete_destination_packet_not_published"
			)

		if not retryable:
			switch_destination_upgrade_seen.erase(
				target_id
			)
			failures.append(
				{
					"target_id": target_id,
					"reason": failure_reason,
					"retryable": false,
					"producer_report": shell.duplicate(false)
				}
			)

			EraLog.truth(
				"SWITCH_DESTINATION_UPGRADE_LANE_ABORT"
				+ "|actor_id=" + str(target_id)
				+ "|reason=" + failure_reason
				+ "|retryable=false"
				+ "|producer_authority=UniversalSwitchContractEngine"
				+ "|ready_gate_member=false"
				+ "|at_ms=" + str(Time.get_ticks_msec())
			)
			continue

		var attempt_count: int = int(
			row.get(
				"attempt_count",
				0
			)
		) + 1
		var retry_delay_ms: int = mini(
			220,
			maxi(
				32,
				32 * attempt_count
			)
		)

		if failure_reason == (
			"profile_switch_support_packet_publication_failed"
		):
			retry_delay_ms = 96
		elif failure_reason == (
			"profile_switch_actor_destination_deck_pending"
		):
			retry_delay_ms = 48
		elif failure_reason == (
			"universal_switch_complete_producer_missing"
		):
			retry_delay_ms = 220

		row [
			"attempt_count"
		] = attempt_count
		row [
			"last_attempt_at_ms"
		] = now_ms
		row [
			"next_allowed_at_ms"
		] = now_ms + retry_delay_ms
		row [
			"last_reason"
		] = failure_reason
		row [
			"last_producer_report"
		] = shell.duplicate(false)
		row [
			"complete_destination_deck_required"
		] = true
		row [
			"relationship_profile_visible_packet"
		] = true
		row [
			"explicit_relationship_profile_observation"
		] = true
		row [
			"pointer_only_packet_forbidden"
		] = true
		row [
			"pointer_core_only_allowed"
		] = false
		row [
			"critical_lane"
		] = true
		row [
			"ready_gate_member"
		] = false

		delayed_rows.append(
			row
		)
		requeued += 1

		failures.append(
			{
				"target_id": target_id,
				"reason": failure_reason,
				"retryable": true,
				"attempt_count": attempt_count,
				"retry_delay_ms": retry_delay_ms,
				"producer_report": shell.duplicate(false)
			}
		)

		EraLog.truth(
			"SWITCH_DESTINATION_UPGRADE_LANE_REQUEUED"
				+ "|actor_id=" + str(target_id)
				+ "|reason=" + failure_reason
				+ "|attempt=" + str(attempt_count)
				+ "|retry_delay_ms=" + str(retry_delay_ms)
				+ "|profile_visible_may_not_block=true"
				+ "|interaction_grace_may_not_block=true"
				+ "|ready_gate_member=false"
				+ "|at_ms=" + str(Time.get_ticks_msec())
		)

	for delayed_row_raw in delayed_rows:
		var delayed_row: Dictionary = _shallow_dictionary(
			delayed_row_raw
		)
		var delayed_target_id: int = int(
			delayed_row.get(
				"target_id",
				-1
			)
		)

		if delayed_target_id <= 0:
			continue

		switch_destination_upgrade_seen [
			delayed_target_id
		] = true
		switch_destination_upgrade_queue.append(
			delayed_row.duplicate(false)
		)

	if (
		gs != null
		and typeof(gs.scenario_state) == TYPE_DICTIONARY
	):
		gs.scenario_state [
			"relationship_switch_destination_upgrade_queue_size"
		] = switch_destination_upgrade_queue.size()
		gs.scenario_state [
			"relationship_switch_destination_upgrade_last_processed"
		] = processed
		gs.scenario_state [
			"relationship_switch_destination_upgrade_last_staged"
		] = staged
		gs.scenario_state [
			"relationship_switch_destination_upgrade_last_requeued"
		] = requeued
		gs.scenario_state [
			"relationship_switch_destination_upgrade_last_service_at_ms"
		] = int(
			Time.get_ticks_msec()
		)

	return {
		"success": (
			failures.is_empty()
			or staged > 0
			or requeued > 0
		),
		"schema": ENGINE_SCHEMA,
		"version": CONTRACT_VERSION,
		"mode": "switch_destination_upgrade_queue_flushed",
		"processed": processed,
		"staged": staged,
		"requeued": requeued,
		"remaining": switch_destination_upgrade_queue.size(),
		"staged_packets_by_actor": (
			staged_packets_by_actor.duplicate(false)
		),
		"failures": failures,
		"critical_switch_destination_lane": true,
		"switch_readiness_authority": (
			"UniversalSwitchContractEngine"
		),
		"ready_gate_member": false,
		"ui_is_renderer_only": true
	}
func _queue_switch_shell_stage_for_target(
	target: Person,
	context: Dictionary = {}
) -> void:
	if target == null:
		return

	var target_id: int = int(
		target.id
	)

	if target_id <= 0:
		return

	var complete_destination_required: bool = (
		_complete_switch_destination_upgrade_requested(
			context
		)
	)




	if complete_destination_required:
		_queue_switch_destination_upgrade_for_target(
			target,
			context
		)
		return

	if _context_forbids_switch_packet_resolution(
		context
	):
		if (
			gs != null
			and typeof(gs.scenario_state) == TYPE_DICTIONARY
		):
			gs.scenario_state [
				"relationship_switch_shell_queue_skipped_for_support_packet_publication"
			] = true
			gs.scenario_state [
				"relationship_switch_shell_queue_skipped_actor_id"
			] = target_id
			gs.scenario_state [
				"relationship_switch_shell_queue_skipped_ready_gate_member"
			] = false

		return

	if bool(
		context.get(
			"visible_card_may_not_publish_complete_destination_deck",
			false
		)
	):
		complete_destination_required = false

	var complete_packet: Dictionary = (
		_resident_complete_switch_packet_for_actor(
			target_id
		)
	)

	if (
		complete_destination_required
		and not complete_packet.is_empty()
	):
		switch_shell_stage_seen.erase(
			target_id
		)
		return

	var packet_cache: Dictionary = {}

	if (
		gs != null
		and typeof(gs.scenario_state) == TYPE_DICTIONARY
	):
		packet_cache = _shallow_dictionary(
			gs.scenario_state.get(
				"profile_pointer_packet_by_actor",
				{}
			)
		)

	var resident_packet: Dictionary = _shallow_dictionary(
		packet_cache.get(
			str(target_id),
			{}
		)
	)
	var pointer_core_hot: bool = _profile_switch_packet_core_hot(
		resident_packet,
		target_id
	)

	if (
		not complete_destination_required
		and pointer_core_hot
	):
		switch_shell_stage_seen.erase(
			target_id
		)
		return

	var now_ms: int = int(
		Time.get_ticks_msec()
	)
	var source: String = str(
		context.get(
			"source",
			""
		)
	).strip_edges().to_lower()
	var explicit_profile_priority: bool = (
		source.find(
			"relationship_profile"
		) >= 0
		or source.find(
			"explicit_profile"
		) >= 0
	)
	var relationship_priority: bool = (
		bool(
			context.get(
				"relationship_priority",
				false
			)
		)
		or bool(
			context.get(
				"top_priority",
				false
			)
		)
		or complete_destination_required
		or explicit_profile_priority
		or source.find(
			"first_life_relationship"
		) >= 0
		or source.find(
			"family"
		) >= 0
		or source.find(
			"household"
		) >= 0
	)

	if switch_shell_stage_seen.has(
		target_id
	):
		var upgraded_existing_row: bool = false

		for index in range(
			switch_shell_stage_queue.size()
		):
			var existing_row: Dictionary = _shallow_dictionary(
				switch_shell_stage_queue [index]
			)

			if int(
				existing_row.get(
					"target_id",
					-1
				)
			) != target_id:
				continue

			var existing_context: Dictionary = _shallow_dictionary(
				existing_row.get(
					"context",
					{}
				)
			)

			if complete_destination_required:
				existing_context [
					"complete_destination_deck_required"
				] = true
				existing_context [
					"relationship_profile_visible_packet"
				] = true
				existing_context [
					"explicit_relationship_profile_observation"
				] = true
				existing_context [
					"profile_switch_packet_required_before_visible"
				] = true
				existing_context [
					"allow_pointer_core_only_preparation"
				] = false
				existing_context [
					"visible_card_may_not_publish_complete_destination_deck"
				] = false

				existing_row [
					"complete_destination_deck_required"
				] = true
				existing_row [
					"relationship_profile_visible_packet"
				] = true
				existing_row [
					"explicit_relationship_profile_observation"
				] = true
				existing_row [
					"pointer_core_only_allowed"
				] = false
				existing_row [
					"pointer_core_is_not_completion_authority"
				] = true
				existing_row [
					"relationship_priority"
				] = true
				existing_row [
					"next_allowed_at_ms"
				] = mini(
					int(
						existing_row.get(
							"next_allowed_at_ms",
							now_ms
						)
					),
					now_ms + 96
				)
				existing_row [
					"upgraded_from_pointer_core_to_complete_profile_packet"
				] = true
				existing_row [
					"upgraded_at_ms"
				] = now_ms

				existing_context [
					"switch_press_build_forbidden"
				] = true
				existing_context [
					"ready_gate_member"
				] = false
				existing_context [
					"ui_is_renderer_only"
				] = true
				existing_row [
					"context"
				] = existing_context.duplicate(false)

				switch_shell_stage_queue [index] = existing_row
				upgraded_existing_row = true
				break

		if upgraded_existing_row:
			_arm_switch_shell_stage_pump()
			return

		switch_shell_stage_seen.erase(
			target_id
		)

	var resident_signature: String = "resident"

	if (
		gs != null
		and typeof(gs.scenario_state) == TYPE_DICTIONARY
	):
		resident_signature = str(
			gs.scenario_state.get(
				"resident_runtime_attached_signature",
				gs.scenario_state.get(
					"resident_runtime_signature",
					"resident"
				)
			)
		).strip_edges()

	if resident_signature == "":
		resident_signature = "resident"

	var row_context: Dictionary = context.duplicate(false)

	row_context [
		"complete_destination_deck_required"
	] = complete_destination_required
	row_context [
		"relationship_profile_visible_packet"
	] = complete_destination_required
	row_context [
		"explicit_relationship_profile_observation"
	] = complete_destination_required
	row_context [
		"allow_pointer_core_only_preparation"
	] = not complete_destination_required
	row_context [
		"visible_card_may_not_publish_complete_destination_deck"
	] = not complete_destination_required
	row_context [
		"switch_press_build_forbidden"
	] = true
	row_context [
		"ready_gate_member"
	] = false
	row_context [
		"ui_is_renderer_only"
	] = true

	var row: Dictionary = {
		"target_id": target_id,
		"context": row_context.duplicate(false),
		"projection_signature": (
			"%s::control_switch_actor_%d"
			% [
				resident_signature,
				target_id
			]
		),
		"queued_at_ms": now_ms,
		"relationship_priority": relationship_priority,
		"continuous_destination_preparation": true,
		"complete_destination_deck_required": complete_destination_required,
		"relationship_profile_visible_packet": complete_destination_required,
		"explicit_relationship_profile_observation": (
			complete_destination_required
		),
		"pointer_core_only_allowed": not complete_destination_required,
		"pointer_core_is_not_completion_authority": true,
		"ready_gate_member": false
	}

	switch_shell_stage_seen [
		target_id
	] = true



	if explicit_profile_priority:
		switch_shell_stage_queue.insert(
			0,
			row
		)
		_arm_switch_shell_stage_pump()
		return

	if relationship_priority:
		var insert_index: int = 0

		while insert_index < switch_shell_stage_queue.size():
			var existing_row: Dictionary = _shallow_dictionary(
				switch_shell_stage_queue [
					insert_index
				]
			)

			if not bool(
				existing_row.get(
					"relationship_priority",
					false
				)
			):
				break

			insert_index += 1

		switch_shell_stage_queue.insert(
			insert_index,
			row
		)
		_arm_switch_shell_stage_pump()
		return

	switch_shell_stage_queue.append(
		row
	)

	_arm_switch_shell_stage_pump()
func _arm_switch_shell_stage_pump() -> void:
	if switch_shell_stage_queue.is_empty():
		switch_shell_stage_pump_armed = false
		return







	switch_shell_stage_pump_armed = true

	if (
		gs != null
		and typeof(gs.scenario_state) == TYPE_DICTIONARY
	):
		gs.scenario_state [
			"relationship_switch_shell_stage_pump_armed"
		] = true
		gs.scenario_state [
			"relationship_switch_shell_stage_service_owner"
		] = "RelationshipsHubContractEngine"
		gs.scenario_state [
			"relationship_switch_shell_stage_service_lane"
		] = "detached_resident_projection_worker"
		gs.scenario_state [
			"relationship_switch_shell_stage_scene_tree_service_forbidden"
		] = true
		gs.scenario_state [
			"relationship_switch_shell_stage_ui_interaction_pauses_service"
		] = false
func _service_switch_shell_stage_pump_quantum() -> void:
	switch_shell_stage_pump_armed = false

	if switch_shell_stage_queue.is_empty():
		return

	var head_row: Dictionary = _shallow_dictionary(
		switch_shell_stage_queue [
			0
		]
	)
	var target_id: int = int(
		head_row.get(
			"target_id",
			-1
		)
	)




	var actor_scalar_truth_report: Dictionary = (
		_prepare_switch_destination_actor_scalar_truth(
			target_id
		)
	)

	var report: Dictionary = (
		flush_switch_shell_stage_queue(
			1,
			{
				"source": (
					"relationships_hub_contract_engine."
					+ "switch_shell_stage_pointer_core_pump"
				),
				"continuous_destination_preparation": true,
				"ui_interaction_grace_ignored": true,
				"background_only": true,
				"blocks_ui": false,
				"switch_press_must_not_build_surface": true,
				"complete_destination_deck_required": false,
				"support_deck_blocks_switch": false,
				"ready_gate_member": false,
				"ui_is_renderer_only": true
			}
		)
	)

	report [
		"actor_scalar_truth_report"
	] = actor_scalar_truth_report.duplicate(false)
	report [
		"actor_scalar_truth_prepared_before_pointer_revision"
	] = true
	report [
		"hunger_authority"
	] = "FoodEngine"




	if (
		target_id > 0
		and gs != null
		and typeof(gs.scenario_state) == TYPE_DICTIONARY
	):
		var packet_cache: Dictionary = _shallow_dictionary(
			gs.scenario_state.get(
				"profile_pointer_packet_by_actor",
				{}
			)
		)
		var resident_packet: Dictionary = _shallow_dictionary(
			packet_cache.get(
				str(target_id),
				{}
			)
		)

		if _profile_switch_packet_core_hot(
			resident_packet,
			target_id
		):
			resident_switch_destination_packet_published.emit(
				target_id,
				resident_packet.duplicate(false)
			)

			gs.scenario_state [
				"relationship_switch_pointer_core_last_published_actor_id"
			] = target_id
			gs.scenario_state [
				"relationship_switch_pointer_core_last_published_at_ms"
			] = int(
				Time.get_ticks_msec()
			)

	if (
		gs != null
		and typeof(gs.scenario_state) == TYPE_DICTIONARY
	):
		gs.scenario_state [
			"relationship_switch_shell_stage_last_pump_report"
		] = report.duplicate(false)
		gs.scenario_state [
			"relationship_switch_shell_stage_service_owner"
		] = "RelationshipsHubContractEngine"
		gs.scenario_state [
			"relationship_switch_shell_stage_main_scene_service_required"
		] = false
		gs.scenario_state [
			"relationship_switch_shell_stage_ui_interaction_pauses_service"
		] = false
		gs.scenario_state [
			"relationship_switch_pointer_core_scalar_truth_prepared"
		] = bool(
			actor_scalar_truth_report.get(
				"success",
				false
			)
		)

	if not switch_shell_stage_queue.is_empty():
		_arm_switch_shell_stage_pump()
func _publish_card_shell_to_scenario(
	target_id: int, switch_shell: Dictionary, card_contract: Dictionary
) -> void:
	if gs == null or typeof(gs.scenario_state) != TYPE_DICTIONARY or target_id <= 0:
		return

	var card_registry: Dictionary = _shallow_dictionary(
		gs.scenario_state.get("relationships_hub_card_contracts", {})
	)
	card_registry [str(target_id)] = card_contract.duplicate(true)
	gs.scenario_state ["relationships_hub_card_contracts"] = card_registry

	if not switch_shell.is_empty():
		var shell_registry: Dictionary = _shallow_dictionary(
			gs.scenario_state.get("relationships_hub_switch_shells", {})
		)
		shell_registry [str(target_id)] = switch_shell.duplicate(true)
		gs.scenario_state ["relationships_hub_switch_shells"] = shell_registry


func _tab_contracts(active_section: String) -> Array:
	var rows: Array = []
	var definitions: Array = [
		{ "key": "family", "label": "FAMILY"},
		{ "key": "ancestors", "label": "ANCESTORS"},
		{ "key": "household", "label": "MY HOUSEHOLD"},
		{ "key": "partner", "label": "PARTNER"},
		{ "key": "pets", "label": "PETS"},
		{ "key": "descendants", "label": "DESCENDANTS"},
		{ "key": "dead", "label": "DEAD"},
		{ "key": "social", "label": "SOCIAL"},
		{ "key": "exes", "label": "EXES"}
	]

	for raw_definition in definitions:
		var definition: Dictionary = _shallow_dictionary(raw_definition)
		var key: String = str(definition.get("key", "family"))
		rows.append(
			{
				"key": key,
				"id": key,
				"label": str(definition.get("label", key.capitalize())),
				"selected": key == active_section,
				"palette": _section_palette(key),
				"ui_is_renderer_only": true
			}
		)

	return rows


func _relationship_climate_contract(actor: Person) -> Dictionary:
	var ids: Array = _clean_unique_ids(_immediate_family_ids(actor), [])
	var partner: Person = _valid_partner(actor)

	if partner != null:
		ids.append(int(partner.id))

	ids.append_array(_safe_person_id_array(actor, "friends"))
	ids = _clean_unique_ids(ids, [])

	var total: int = 0
	var count: int = 0

	for raw_id in ids:
		var target: Person = _person_by_id(int(raw_id))

		if target == null:
			continue

		total += bond_score_for_pair(actor, target)
		count += 1

	var score: int = 50 if count <= 0 else clampi(int(round(float(total) / float(count))), 0, 100)
	var climate_name: String = "Mixed"

	if score >= 80:
		climate_name = "Deeply Connected"
	elif score >= 65:
		climate_name = "Warm"
	elif score >= 45:
		climate_name = "Mixed"
	elif score >= 25:
		climate_name = "Strained"
	else:
		climate_name = "Hostile"

	return {
		"score": score,
		"state": climate_name.to_lower().replace(" ", "_"),
		"label": "Climate: %s · %d" % [climate_name, score],
		"sample_size": count,
		"ui_is_renderer_only": true
	}


func _card_visual_surface_contract(
	state_name: String, featured: bool, section_key: String, bond_value: int
) -> Dictionary:
	var palette: Dictionary = _section_palette(section_key)
	var accent: Color = palette.get("accent", Color(1.0, 0.48, 0.72, 1.0))

	if state_name == "conflict":
		accent = Color(1.0, 0.3, 0.32, 1.0)
	elif state_name == "strained":
		accent = Color(1.0, 0.62, 0.28, 1.0)

	return {
		"accent": accent,
		"border_color": accent,
		"fill": palette.get("active_fill", Color(0.05, 0.054, 0.092, 0.98)),
		"background_color": palette.get("active_fill", Color(0.05, 0.054, 0.092, 0.98)),
		"font_color": palette.get("font_color", Color.WHITE),
		"glow_intensity": clampf(float(bond_value) / 100.0, 0.0, 1.0),
		"featured": featured,
		"state": state_name
	}


func _section_palette(section_id: String) -> Dictionary:
	match _resolve_section_id(section_id):
		"family":
			return {
				"accent": Color(1.0, 0.44, 0.7, 1.0),
				"active_fill": Color(0.105, 0.038, 0.08, 0.98),
				"inactive_fill": Color(0.05, 0.024, 0.048, 0.95),
				"hover_fill": Color(0.145, 0.052, 0.11, 0.98),
				"font_color": Color.WHITE
			}
		"ancestors":
			return {
				"accent": Color(0.9, 0.72, 0.36, 1.0),
				"active_fill": Color(0.105, 0.075, 0.03, 0.98),
				"inactive_fill": Color(0.052, 0.04, 0.02, 0.95),
				"hover_fill": Color(0.14, 0.1, 0.04, 0.98),
				"font_color": Color.WHITE
			}
		"household":
			return {
				"accent": Color(0.52, 0.88, 1.0, 1.0),
				"active_fill": Color(0.035, 0.08, 0.112, 0.98),
				"inactive_fill": Color(0.022, 0.046, 0.062, 0.95),
				"hover_fill": Color(0.05, 0.11, 0.15, 0.98),
				"font_color": Color.WHITE
			}
		"partner":
			return {
				"accent": Color(1.0, 0.34, 0.46, 1.0),
				"active_fill": Color(0.115, 0.03, 0.05, 0.98),
				"inactive_fill": Color(0.058, 0.018, 0.032, 0.95),
				"hover_fill": Color(0.155, 0.046, 0.074, 0.98),
				"font_color": Color.WHITE
			}
		"pets":
			return {
				"accent": Color(0.52, 0.95, 0.62, 1.0),
				"active_fill": Color(0.03, 0.095, 0.05, 0.98),
				"inactive_fill": Color(0.02, 0.05, 0.03, 0.95),
				"hover_fill": Color(0.045, 0.13, 0.07, 0.98),
				"font_color": Color.WHITE
			}
		"descendants":
			return {
				"accent": Color(0.88, 0.6, 1.0, 1.0),
				"active_fill": Color(0.102, 0.052, 0.13, 0.98),
				"inactive_fill": Color(0.052, 0.028, 0.072, 0.95),
				"hover_fill": Color(0.13, 0.062, 0.165, 0.98),
				"font_color": Color.WHITE
			}
		"dead":
			return {
				"accent": Color(0.62, 0.66, 0.74, 1.0),
				"active_fill": Color(0.06, 0.064, 0.074, 0.98),
				"inactive_fill": Color(0.032, 0.034, 0.04, 0.95),
				"hover_fill": Color(0.082, 0.086, 0.1, 0.98),
				"font_color": Color.WHITE
			}
		"social":
			return {
				"accent": Color(0.48, 0.82, 1.0, 1.0),
				"active_fill": Color(0.036, 0.07, 0.115, 0.98),
				"inactive_fill": Color(0.022, 0.04, 0.062, 0.95),
				"hover_fill": Color(0.05, 0.095, 0.15, 0.98),
				"font_color": Color.WHITE
			}
		"exes":
			return {
				"accent": Color(0.98, 0.46, 0.36, 1.0),
				"active_fill": Color(0.11, 0.05, 0.038, 0.98),
				"inactive_fill": Color(0.056, 0.028, 0.022, 0.95),
				"hover_fill": Color(0.145, 0.068, 0.052, 0.98),
				"font_color": Color.WHITE
			}
		_:
			return {
				"accent": Color(1.0, 0.48, 0.72, 1.0),
				"active_fill": Color(0.1, 0.04, 0.085, 0.98),
				"inactive_fill": Color(0.05, 0.022, 0.045, 0.95),
				"hover_fill": Color(0.135, 0.05, 0.095, 0.98),
				"font_color": Color.WHITE
			}
func _profile_body_observation_contracts_for_target(
	target: Person
) -> Dictionary:
	if target == null:
		return {}

	var now_ms: int = int(
		Time.get_ticks_msec()
	)
	var height_contract: Dictionary = _shallow_dictionary(
		target.height_contract
	)
	var weight_contract: Dictionary = _shallow_dictionary(
		target.weight_contract
	)
	var body_type_contract: Dictionary = _shallow_dictionary(
		target.body_type_contract
	)
	var growth_curve_contract: Dictionary = _shallow_dictionary(
		target.growth_curve_contract
	)
	var genetics_contract: Dictionary = _shallow_dictionary(
		target.genetics_contract
	)
	var body_contract: Dictionary = _shallow_dictionary(
		target.body_contract
	)
	var cached_bundle: Dictionary = {}




	if (
		gs != null
		and gs.has_method(
			"_cached_body_contract_bundle_for_person"
		)
	):
		cached_bundle = _shallow_dictionary(
			gs._cached_body_contract_bundle_for_person(
				target,
				{
					"source": (
						"relationships_hub_contract_engine."
						+ "profile_body_observation"
					),
					"ready_gate_member": false,
					"ui_is_renderer_only": true
				}
			)
		)

	if height_contract.is_empty():
		height_contract = _shallow_dictionary(
			cached_bundle.get(
				"height_contract",
				{}
			)
		)

	if weight_contract.is_empty():
		weight_contract = _shallow_dictionary(
			cached_bundle.get(
				"weight_contract",
				{}
			)
		)

	if body_type_contract.is_empty():
		body_type_contract = _shallow_dictionary(
			cached_bundle.get(
				"body_type_contract",
				{}
			)
		)

	if growth_curve_contract.is_empty():
		growth_curve_contract = _shallow_dictionary(
			cached_bundle.get(
				"growth_curve_contract",
				{}
			)
		)

	if genetics_contract.is_empty():
		genetics_contract = _shallow_dictionary(
			cached_bundle.get(
				"genetics_contract",
				{}
			)
		)

	if body_contract.is_empty():
		body_contract = _shallow_dictionary(
			cached_bundle.get(
				"body_contract",
				{}
			)
		)

	if height_contract.is_empty():
		height_contract = _shallow_dictionary(
			body_contract.get(
				"height",
				{}
			)
		)

	if weight_contract.is_empty():
		weight_contract = _shallow_dictionary(
			body_contract.get(
				"weight",
				{}
			)
		)

	if body_type_contract.is_empty():
		body_type_contract = _shallow_dictionary(
			body_contract.get(
				"body_type",
				{}
			)
		)

	if growth_curve_contract.is_empty():
		growth_curve_contract = _shallow_dictionary(
			body_contract.get(
				"growth_curve",
				{}
			)
		)

	var summary: Dictionary = _shallow_dictionary(
		body_contract.get(
			"summary",
			{}
		)
	)

	if str(
		height_contract.get(
			"display",
			""
		)
	).strip_edges() == "":
		var summary_height: String = str(
			summary.get(
				"height",
				""
			)
		).strip_edges()

		if summary_height != "":
			height_contract [
				"display"
			] = summary_height

	if str(
		weight_contract.get(
			"display",
			""
		)
	).strip_edges() == "":
		var summary_weight: String = str(
			summary.get(
				"weight",
				""
			)
		).strip_edges()

		if summary_weight != "":
			weight_contract [
				"display"
			] = summary_weight

	if str(
		body_type_contract.get(
			"display_name",
			""
		)
	).strip_edges() == "":
		var summary_body_type: String = str(
			summary.get(
				"body_type",
				""
			)
		).strip_edges()

		if summary_body_type != "":
			body_type_contract [
				"display_name"
			] = summary_body_type

	var body_type_key: String = str(
		body_type_contract.get(
			"type",
			genetics_contract.get(
				"dominant_body_type",
				""
			)
		)
	).strip_edges().to_lower()

	if body_type_key not in [
		"ectomorph",
		"mesomorph",
		"endomorph"
	]:
		var body_type_seed: int = (
			abs(
				hash(
					"profile_body_type|%d|%s|%s"
					% [
						int(
							target.id
						),
						str(
							target.gender
						),
						str(
							target.first_name
						)
					]
				)
			)
			% 3
		)

		match body_type_seed:
			0:
				body_type_key = "ectomorph"

			2:
				body_type_key = "endomorph"

			_:
				body_type_key = "mesomorph"

	var body_type_display: String = ""

	match body_type_key:
		"ectomorph":
			body_type_display = "Ectomorph"

		"endomorph":
			body_type_display = "Endomorph"

		_:
			body_type_display = "Mesomorph"

	if str(
		body_type_contract.get(
			"display_name",
			""
		)
	).strip_edges() == "":
		body_type_contract = body_type_contract.duplicate(true)
		body_type_contract [
			"schema"
		] = "eralife.person.body_type_contract.observation"
		body_type_contract [
			"version"
		] = 1
		body_type_contract [
			"actor_id"
		] = int(
			target.id
		)
		body_type_contract [
			"type"
		] = body_type_key
		body_type_contract [
			"display_name"
		] = body_type_display
		body_type_contract [
			"observation_fallback"
		] = true
		body_type_contract [
			"simulation_mutation_performed"
		] = false
		body_type_contract [
			"source"
		] = (
			"relationships_hub_contract_engine."
			+ "profile_body_observation"
		)
		body_type_contract [
			"created_at_ms"
		] = now_ms
		body_type_contract [
			"updated_at_ms"
		] = now_ms

	var age_value: int = maxi(
		0,
		int(
			target.age
		)
	)
	var growth_factor: float = float(
		growth_curve_contract.get(
			"height_growth_factor",
			growth_curve_contract.get(
				"growth_factor",
				0.0
			)
		)
	)

	if growth_factor <= 0.0:
		if age_value <= 0:
			growth_factor = 0.305
		elif age_value < 2:
			growth_factor = lerpf(
				0.305,
				0.485,
				float(
					age_value
				) / 2.0
			)
		elif age_value < 6:
			growth_factor = lerpf(
				0.485,
				0.655,
				float(
					age_value - 2
				) / 4.0
			)
		elif age_value < 12:
			growth_factor = lerpf(
				0.655,
				0.815,
				float(
					age_value - 6
				) / 6.0
			)
		elif age_value < 18:
			growth_factor = lerpf(
				0.815,
				1.0,
				float(
					age_value - 12
				) / 6.0
			)
		elif age_value >= 65:
			growth_factor = clampf(
				1.0
				- (
					float(
						age_value - 65
					)
					* 0.0012
				),
				0.955,
				1.0
			)
		else:
			growth_factor = 1.0

	var height_in: float = float(
		height_contract.get(
			"height_in",
			height_contract.get(
				"height_inches",
				0.0
			)
		)
	)

	if height_in <= 0.0:
		for raw_height_key in [
			"height_in",
			"height_inches",
			"height"
		]:
			var height_key: String = str(
				raw_height_key
			)

			if not (
				height_key in target
			):
				continue

			var raw_height_value: Variant = target.get(
				height_key
			)

			if typeof(
				raw_height_value
			) not in [
				TYPE_INT,
				TYPE_FLOAT
			]:
				continue

			var direct_height: float = float(
				raw_height_value
			)

			if direct_height > 0.0:
				height_in = direct_height
				break

	if height_in <= 0.0:
		var gender_key: String = str(
			target.gender
		).strip_edges().to_lower()
		var adult_height: float = (
			64.0
			if gender_key in [
				"female",
				"woman",
				"girl",
				"f"
			]
			else 69.0
		)
		var identity_height_offset: float = (
			float(
				(
					abs(
						hash(
							"profile_height|%d|%s|%s"
							% [
								int(
									target.id
								),
								str(
									target.gender
								),
								str(
									target.last_name
								)
							]
						)
					)
					% 61
				)
				- 30
			)
			/ 10.0
		)

		adult_height = clampf(
			adult_height + identity_height_offset,
			48.0,
			86.0
		)
		height_in = clampf(
			adult_height * growth_factor,
			16.0,
			90.0
		)

	var rounded_height: int = int(
		round(
			height_in
		)
	)
	var height_feet: int = int(
		floor(
			float(
				rounded_height
			) / 12.0
		)
	)
	var height_inches: int = int(
		rounded_height % 12
	)
	var height_cm: float = (
		height_in * 2.54
	)

	if str(
		height_contract.get(
			"display",
			""
		)
	).strip_edges() == "":
		height_contract = height_contract.duplicate(true)
		height_contract [
			"schema"
		] = "eralife.person.height_contract.observation"
		height_contract [
			"version"
		] = 1
		height_contract [
			"actor_id"
		] = int(
			target.id
		)
		height_contract [
			"height_in"
		] = height_in
		height_contract [
			"height_cm"
		] = height_cm
		height_contract [
			"display"
		] = (
			"%d'%d\""
			% [
				height_feet,
				height_inches
			]
		)
		height_contract [
			"display_metric"
		] = "%.1f cm" % height_cm
		height_contract [
			"observation_fallback"
		] = true
		height_contract [
			"simulation_mutation_performed"
		] = false
		height_contract [
			"source"
		] = (
			"relationships_hub_contract_engine."
			+ "profile_body_observation"
		)
		height_contract [
			"created_at_ms"
		] = now_ms
		height_contract [
			"updated_at_ms"
		] = now_ms

	var weight_lbs: float = float(
		weight_contract.get(
			"weight_lbs",
			weight_contract.get(
				"walkaround_weight_lbs",
				0.0
			)
		)
	)

	if weight_lbs <= 0.0:
		for raw_weight_key in [
			"weight_lbs",
			"walkaround_weight_lbs",
			"weight"
		]:
			var weight_key: String = str(
				raw_weight_key
			)

			if not (
				weight_key in target
			):
				continue

			var raw_weight_value: Variant = target.get(
				weight_key
			)

			if typeof(
				raw_weight_value
			) not in [
				TYPE_INT,
				TYPE_FLOAT
			]:
				continue

			var direct_weight: float = float(
				raw_weight_value
			)

			if direct_weight > 0.0:
				weight_lbs = direct_weight
				break

	if weight_lbs <= 0.0:
		var height_m: float = maxf(
			0.3,
			height_in * 0.0254
		)
		var adult_healthy_weight: float = (
			22.0
			* height_m
			* height_m
			* 2.20462
		)
		var weight_growth_factor: float = float(
			growth_curve_contract.get(
				"weight_growth_factor",
				0.0
			)
		)

		if weight_growth_factor <= 0.0:
			weight_growth_factor = clampf(
				growth_factor * growth_factor,
				0.1,
				1.06
			)

		var frame_multiplier: float = 1.02

		match body_type_key:
			"ectomorph":
				frame_multiplier = 0.92

			"endomorph":
				frame_multiplier = 1.1

			_:
				frame_multiplier = 1.02

		var identity_weight_offset: float = (
			float(
				(
					abs(
						hash(
							"profile_weight|%d|%s|%s"
							% [
								int(
									target.id
								),
								str(
									target.age
								),
								body_type_key
							]
						)
					)
					% 101
				)
				- 50
			)
			/ 10.0
		)

		weight_lbs = clampf(
			(
				adult_healthy_weight
				* weight_growth_factor
				* frame_multiplier
			)
			+ identity_weight_offset,
			5.0,
			850.0
		)

	var safe_height: float = maxf(
		12.0,
		height_in
	)
	var bmi: float = (
		weight_lbs
		/ (
			safe_height
			* safe_height
		)
	) * 703.0
	var weight_category: String = "obese"

	if bmi < 18.5:
		weight_category = "lean"
	elif bmi < 25.0:
		weight_category = "average"
	elif bmi < 30.0:
		weight_category = "overweight"

	var weight_kg: float = (
		weight_lbs * 0.45359237
	)

	if str(
		weight_contract.get(
			"display",
			""
		)
	).strip_edges() == "":
		weight_contract = weight_contract.duplicate(true)
		weight_contract [
			"schema"
		] = "eralife.person.weight_contract.observation"
		weight_contract [
			"version"
		] = 1
		weight_contract [
			"actor_id"
		] = int(
			target.id
		)
		weight_contract [
			"weight_lbs"
		] = weight_lbs
		weight_contract [
			"weight_kg"
		] = weight_kg
		weight_contract [
			"walkaround_weight_lbs"
		] = weight_lbs
		weight_contract [
			"bmi"
		] = bmi
		weight_contract [
			"category"
		] = weight_category
		weight_contract [
			"display"
		] = (
			"%d lb"
			% int(
				round(
					weight_lbs
				)
			)
		)
		weight_contract [
			"display_metric"
		] = "%.1f kg" % weight_kg
		weight_contract [
			"observation_fallback"
		] = true
		weight_contract [
			"simulation_mutation_performed"
		] = false
		weight_contract [
			"source"
		] = (
			"relationships_hub_contract_engine."
			+ "profile_body_observation"
		)
		weight_contract [
			"created_at_ms"
		] = now_ms
		weight_contract [
			"updated_at_ms"
		] = now_ms

	return {
		"success": true,
		"actor_id": int(
			target.id
		),
		"height_contract": height_contract,
		"weight_contract": weight_contract,
		"body_type_contract": body_type_contract,
		"cached_bundle_observed": (
			not cached_bundle.is_empty()
		),
		"simulation_mutation_performed": false,
		"ready_gate_member": false,
		"ui_is_renderer_only": true
	}

func _profile_lines_for_target(
	actor: Person,
	target: Person,
	relation_label: String,
	_bond_value: int
) -> Array:
	var lines: Array = []

	if target == null:
		return lines

	var body_observation: Dictionary = (
		_profile_body_observation_contracts_for_target(
			target
		)
	)
	var height_contract: Dictionary = _shallow_dictionary(
		body_observation.get(
			"height_contract",
			{}
		)
	)
	var weight_contract: Dictionary = _shallow_dictionary(
		body_observation.get(
			"weight_contract",
			{}
		)
	)
	var body_type_contract: Dictionary = _shallow_dictionary(
		body_observation.get(
			"body_type_contract",
			{}
		)
	)

	var height_text: String = str(
		height_contract.get(
			"display",
			""
		)
	).strip_edges()

	if height_text == "":
		var height_in: float = float(
			height_contract.get(
				"height_in",
				height_contract.get(
					"height_inches",
					67.0
				)
			)
		)
		var rounded_height: int = int(
			round(
				maxf(
					16.0,
					height_in
				)
			)
		)

		height_text = (
			"%d'%d\""
			% [
				int(
					floor(
						float(
							rounded_height
						) / 12.0
					)
				),
				int(
					rounded_height % 12
				)
			]
		)

	var weight_text: String = str(
		weight_contract.get(
			"display",
			""
		)
	).strip_edges()

	if weight_text == "":
		weight_text = (
			"%d lb"
			% int(
				round(
					maxf(
						5.0,
						float(
							weight_contract.get(
								"weight_lbs",
								weight_contract.get(
									"walkaround_weight_lbs",
									150.0
								)
							)
						)
					)
				)
			)
		)

	var body_type_text: String = str(
		body_type_contract.get(
			"display_name",
			body_type_contract.get(
				"type",
				"Mesomorph"
			)
		)
	).strip_edges()

	if body_type_text == "":
		body_type_text = "Mesomorph"
	elif body_type_text == body_type_text.to_lower():
		body_type_text = body_type_text.capitalize()

	lines.append(
		"Name: %s"
		% _actor_display_name(
			target
		)
	)
	lines.append(
		"Age: %d"
		% int(
			target.age
		)
	)

	if relation_label.strip_edges() != "":
		lines.append(
			"Relationship: %s"
			% relation_label
		)

	lines.append(
		"Height: %s"
		% height_text
	)

	var weight_category: String = str(
		weight_contract.get(
			"category",
			""
		)
	).strip_edges().capitalize()

	if weight_category != "":
		lines.append(
			"Weight: %s • %s"
			% [
				weight_text,
				weight_category
			]
		)
	else:
		lines.append(
			"Weight: %s"
			% weight_text
		)

	lines.append(
		"Body type: %s"
		% body_type_text
	)
	lines.append(
		"Alive: %s"
		% (
			"Yes"
			if bool(
				target.alive
			)
			else "No"
		)
	)
	lines.append(
		"Home: %s, %s"
		% [
			str(
				target.home_city
			),
			str(
				target.home_country
			)
		]
	)
	lines.append(
		"School: %s"
		% (
			str(
				target.school_name
			)
			if str(
				target.school_name
			).strip_edges() != ""
			else "None"
		)
	)
	lines.append(
		"Observed by: %s"
		% _actor_display_name(
			actor
		)
	)

	return lines

func _profile_actions_for_target(
	actor: Person,
	target: Person,
	relation_label: String
) -> Array:
	if (
		actor == null
		or target == null
	):
		return []

	var actions: Array = []
	var seen_action_ids: Dictionary = {}
	var actor_can_speak: bool = (
		int(actor.age) >= 2
	)




	if (
		int(actor.id) != int(target.id)
		and actor_can_speak
	):
		for raw_base_action in [
			{
				"id": "converse",
				"action_id": "converse",
				"label": "Converse",
				"section": "relationship"
			},
			{
				"id": "compliment",
				"action_id": "compliment",
				"label": "Compliment",
				"section": "relationship"
			}
		]:
			var base_action: Dictionary = (
				raw_base_action as Dictionary
			).duplicate(false)
			var base_action_id: String = str(
				base_action.get(
					"action_id",
					""
				)
			).strip_edges().to_lower()

			base_action ["target_id"] = int(target.id)
			base_action ["enabled"] = bool(target.alive)
			base_action ["ui_is_expression_only"] = true
			base_action ["age_capability_validated"] = true

			actions.append(base_action)
			seen_action_ids [base_action_id] = true

	if (
		actor_can_speak
		and relation_label.to_lower().find("partner") >= 0
	):
		actions.append(
			{
				"id": "spend_time",
				"action_id": "spend_time",
				"label": "Spend Time Together",
				"section": "relationship",
				"target_id": int(target.id),
				"enabled": bool(target.alive),
				"ui_is_expression_only": true,
				"age_capability_validated": true
			}
		)
		seen_action_ids ["spend_time"] = true




	if (
		gs != null
		and gs.relationship_activities_engine != null
		and gs.relationship_activities_engine.has_method(
			"get_contextual_relationship_actions"
		)
	):
		var contextual_raw: Variant = (
			gs.relationship_activities_engine
			.get_contextual_relationship_actions(
				actor,
				target,
				{
					"source": (
						"relationships_hub_contract_engine.profile"
					),
					"relationship_role": relation_label,
					"actor_can_speak": actor_can_speak,
					"ui_is_renderer_only": true
				}
			)
		)
		var contextual_actions: Array = (
			contextual_raw as Array
			if typeof(contextual_raw) == TYPE_ARRAY
			else []
		)

		for raw_action in contextual_actions:
			if typeof(raw_action) != TYPE_DICTIONARY:
				continue

			var action: Dictionary = (
				raw_action as Dictionary
			).duplicate(false)
			var action_id: String = str(
				action.get(
					"action_id",
					action.get(
						"id",
						""
					)
				)
			).strip_edges().to_lower()

			if (
				action_id == ""
				or bool(
					seen_action_ids.get(
						action_id,
						false
					)
				)
			):
				continue

			action ["id"] = str(
				action.get(
					"id",
					action_id
				)
			)
			action ["action_id"] = action_id
			action ["target_id"] = int(target.id)
			action ["enabled"] = bool(
				action.get(
					"enabled",
					target.alive
				)
			)
			action ["ui_is_expression_only"] = true
			action ["age_capability_validated"] = true

			actions.append(action)
			seen_action_ids [action_id] = true

	return actions


func _profile_bank_text(
	target: Person
) -> String:
	if target == null:
		return "Bank: Unknown"

	var amount: int = int(
		round(
			float(target.bank_balance)
		)
	)

	if (
		gs != null
		and gs.economy_engine != null
		and gs.economy_engine.has_method(
			"format_money"
		)
	):
		return (
			"Bank: %s"
			% gs.economy_engine.format_money(
				amount,
				target
			)
		)

	return (
		"Bank: %s"
		% _format_integer_with_commas(
			amount
		)
	)
func _format_integer_with_commas(
	amount: int
) -> String:
	var negative: bool = amount < 0
	var digits: String = str(
		abs(amount)
	)
	var grouped: String = ""

	while digits.length() > 3:
		grouped = (
			","
			+ digits.substr(
				digits.length() - 3,
				3
			)
			+ grouped
		)
		digits = digits.substr(
			0,
			digits.length() - 3
		)

	grouped = digits + grouped

	if negative:
		grouped = "-" + grouped

	return grouped


func _relationship_label_for_pair(
	observer: Person,
	target: Person
) -> String:
	if observer == null or target == null:
		return "Stranger"

	var observer_id: int = int(observer.id)
	var target_id: int = int(target.id)
	var target_is_female: bool = (
		_person_gender_text(target) == "female"
	)

	if observer_id == target_id:
		return "You"

	if _id_in_array(
		_safe_person_id_array(observer, "parents"),
		target_id
	):
		return _parent_gender_label(target)

	if _id_in_array(
		_safe_person_id_array(observer, "children"),
		target_id
	):
		return _child_gender_label(target)

	if _id_in_array(
		_sibling_ids_for_person(observer),
		target_id
	):
		return _sibling_gender_label(target)

	var partner: Person = _valid_partner(
		observer
	)

	if (
		partner != null
		and int(
			partner.id
		) == target_id
	):
		if (
			gs != null
			and gs.has_method(
				"get_relationship_label_between"
			)
		):
			var canonical_partner_label: String = str(
				gs.get_relationship_label_between(
					observer,
					target
				)
			).strip_edges()

			if canonical_partner_label in [
				"Husband",
				"Wife",
				"Fiancé",
				"Fiancée",
				"Boyfriend",
				"Girlfriend"
			]:
				return canonical_partner_label

		return (
			"Girlfriend"
			if target_is_female
			else "Boyfriend"
		)

	var casual_romance_label: String = (
		_casual_romance_label_for_pair(
			observer,
			target
		)
	)

	if casual_romance_label != "":
		return casual_romance_label

	var observer_parent_ids: Array = (
		_safe_person_id_array(
			observer,
			"parents"
		)
	)


	for raw_parent_id in observer_parent_ids:
		var parent: Person = _person_by_id(
			int(raw_parent_id)
		)

		if parent == null:
			continue

		if _id_in_array(
			_safe_person_id_array(parent, "parents"),
			target_id
		):
			var parent_is_female: bool = (
				_person_gender_text(parent) == "female"
			)
			var lineage_side: String = (
				"Maternal"
				if parent_is_female
				else "Paternal"
			)
			var parent_name: String = (
				"Mom"
				if parent_is_female
				else "Dad"
			)
			var target_parent_role: String = (
				"mother"
				if target_is_female
				else "father"
			)
			var grandparent_role: String = (
				"Grandmother"
				if target_is_female
				else "Grandfather"
			)

			return (
				"%s %s (%s's %s)"
				% [
					lineage_side,
					grandparent_role,
					parent_name,
					target_parent_role
				]
			)


	for raw_parent_id in observer_parent_ids:
		var parent: Person = _person_by_id(
			int(raw_parent_id)
		)

		if parent == null:
			continue

		var parent_is_female: bool = (
			_person_gender_text(parent) == "female"
		)
		var lineage_side: String = (
			"Maternal"
			if parent_is_female
			else "Paternal"
		)
		var parent_name: String = (
			"Mom"
			if parent_is_female
			else "Dad"
		)

		for raw_grandparent_id in _safe_person_id_array(
			parent,
			"parents"
		):
			var grandparent: Person = _person_by_id(
				int(raw_grandparent_id)
			)

			if grandparent == null:
				continue

			if _id_in_array(
				_safe_person_id_array(
					grandparent,
					"parents"
				),
				target_id
			):
				var great_role: String = (
					"Great-Grandmother"
					if target_is_female
					else "Great-Grandfather"
				)
				var parent_grand_role: String = (
					"grandmother"
					if target_is_female
					else "grandfather"
				)

				return (
					"%s %s (%s's %s)"
					% [
						lineage_side,
						great_role,
						parent_name,
						parent_grand_role
					]
				)



	for raw_parent_id in observer_parent_ids:
		var parent: Person = _person_by_id(
			int(raw_parent_id)
		)

		if parent == null:
			continue

		var parent_sibling_ids: Array = (
			_sibling_ids_for_person(parent)
		)

		if not _id_in_array(
			parent_sibling_ids,
			target_id
		):
			continue

		var side_name: String = (
			"Mom's"
			if _person_gender_text(parent) == "female"
			else "Dad's"
		)
		var sibling_role: String = (
			"sister"
			if target_is_female
			else "brother"
		)
		var birth_order: String = (
			"older"
			if int(target.age) > int(parent.age)
			else "younger"
		)

		if int(target.age) == int(parent.age):
			birth_order = "twin"
		else:
			var sibling_family_ids: Array = (
				parent_sibling_ids.duplicate()
			)

			sibling_family_ids.append(
				int(parent.id)
			)

			var oldest_age: int = -1
			var youngest_age: int = 999999

			for raw_sibling_id in sibling_family_ids:
				var sibling: Person = _person_by_id(
					int(raw_sibling_id)
				)

				if sibling == null:
					continue

				oldest_age = maxi(
					oldest_age,
					int(sibling.age)
				)
				youngest_age = mini(
					youngest_age,
					int(sibling.age)
				)

			if int(target.age) >= oldest_age:
				birth_order = "oldest"
			elif int(target.age) <= youngest_age:
				birth_order = "youngest"

		return (
			"%s %s %s"
			% [
				side_name,
				birth_order,
				sibling_role
			]
		)


	if _id_in_array(
		_ancestor_generation_ids(observer, 2),
		target_id
	):
		return (
			"Grandmother"
			if target_is_female
			else "Grandfather"
		)

	if _id_in_array(
		_ancestor_generation_ids(observer, 3),
		target_id
	):
		return (
			"Great-Grandmother"
			if target_is_female
			else "Great-Grandfather"
		)

	if _id_in_array(
		_descendant_generation_ids(observer, 2),
		target_id
	):
		return (
			"Granddaughter"
			if target_is_female
			else "Grandson"
		)

	if _id_in_array(
		_aunt_uncle_ids(observer),
		target_id
	):
		return (
			"Aunt"
			if target_is_female
			else "Uncle"
		)

	if _id_in_array(
		_niece_nephew_ids(observer),
		target_id
	):
		return (
			"Niece"
			if target_is_female
			else "Nephew"
		)

	if _id_in_array(
		_safe_person_id_array(observer, "friends"),
		target_id
	):
		return "Friend"

	if _id_in_array(
		_safe_person_id_array(observer, "exes"),
		target_id
	):
		return "Ex"

	return "Stranger"
func continuation_relationship_label_for_pair(
	observer: Person,
	target: Person
) -> String:





	return _relationship_label_for_pair(
		observer,
		target
	)
func continuation_known_person_contracts(
	actor: Person
) -> Array:
	if (
		actor == null
		or gs == null
	):
		return []

	var friend_ids: Array = (
		_safe_person_id_array(
			actor,
			"friends"
		)
	)

	var romantic_ids: Array = (
		_safe_person_id_array(
			actor,
			"flings"
		)
	)

	var partner: Person = _valid_partner(
		actor
	)

	var partner_id: int = -1

	if partner != null:
		partner_id = int(
			partner.id
		)

		if (
			partner_id > 0
			and partner_id not in romantic_ids
		):
			romantic_ids.append(
				partner_id
			)

	var candidate_ids: Array = []

	candidate_ids.append_array(
		friend_ids
	)
	candidate_ids.append_array(
		romantic_ids
	)

	candidate_ids = _clean_unique_ids(
		candidate_ids,
		[
			int(
				actor.id
			)
		]
	)

	var out: Array = []

	for raw_target_id in candidate_ids:
		var target_id: int = int(
			raw_target_id
		)

		var target: Person = _person_by_id(
			target_id
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
			continue

		var relationship_label: String = (
			_relationship_label_for_pair(
				actor,
				target
			)
		)

		if (
			relationship_label.strip_edges() == ""
			or relationship_label == "Stranger"
		):
			continue

		var job_text: String = str(
			target.job
		).strip_edges()

		if job_text == "":
			job_text = "Unemployed"

		var candidate_kind: String = "friend"

		if (
			target_id in romantic_ids
			or target_id == partner_id
		):
			candidate_kind = "romantic"

		out.append({
			"schema": (
				"eralife.relationships_hub."
				+ "continuation_candidate_contract"
			),
			"version": CONTRACT_VERSION,
			"actor_id": int(
				actor.id
			),
			"target_id": target_id,
			"target_name": _actor_display_name(
				target
			),
			"relationship_label": relationship_label,
			"age": int(
				target.age
			),
			"job": job_text,
			"option_label": (
				"Continue as %s — %s • age %d • job: %s"
				% [
					_actor_display_name(
						target
					),
					relationship_label,
					int(
						target.age
					),
					job_text
				]
			),
			"candidate_kind": candidate_kind,
			"alive": true,
			"immutable": true,
			"read_only": true,
			"ui_is_renderer_only": true
		})

	return out
func _casual_romance_label_for_pair(
	observer: Person,
	target: Person
) -> String:
	if (
		observer == null
		or target == null
		or gs == null
	):
		return ""

	if (
		gs.relationship_graph_contract_engine != null
		and gs.relationship_graph_contract_engine.has_method(
			"relationships_for_entity"
		)
	):
		var observer_entity_id: String = (
			"human:%d"
			% int(
				observer.id
			)
		)
		var target_entity_id: String = (
			"human:%d"
			% int(
				target.id
			)
		)
		var edges: Array = (
			gs.relationship_graph_contract_engine
			.relationships_for_entity(
				observer_entity_id
			)
		)

		for raw_edge in edges:
			var edge: Dictionary = (
				_shallow_dictionary(
					raw_edge
				)
			)

			if edge.is_empty():
				continue

			var entity_a: String = str(
				edge.get(
					"entity_a",
					""
				)
			)
			var entity_b: String = str(
				edge.get(
					"entity_b",
					""
				)
			)

			if (
				entity_a != target_entity_id
				and entity_b != target_entity_id
			):
				continue

			var relationship_types: Dictionary = (
				_shallow_dictionary(
					edge.get(
						"relationship_types",
						{}
					)
				)
			)
			var relationship_tags: Array = _array(
				edge.get(
					"relationship_tags",
					[]
				)
			)

			if (
				bool(
					relationship_types.get(
						"friends_with_benefits",
						false
					)
				)
				or relationship_tags.has(
					"friends_with_benefits"
				)
				or relationship_tags.has(
					"fwb"
				)
			):
				return "FWB"

			if (
				bool(
					relationship_types.get(
						"fling",
						false
					)
				)
				or bool(
					relationship_types.get(
						"foreign_writing_fling",
						false
					)
				)
				or relationship_tags.has(
					"fling"
				)
			):
				return "Fling"


	if typeof(
		gs.scenario_state
	) == TYPE_DICTIONARY:
		var foreign_contracts: Dictionary = (
			_shallow_dictionary(
				gs.scenario_state.get(
					"foreign_romance_fling_contracts",
					{}
				)
			)
		)
		var foreign_row: Dictionary = (
			_shallow_dictionary(
				foreign_contracts.get(
					str(
						target.id
					),
					{}
				)
			)
		)

		if (
			int(
				foreign_row.get(
					"actor_id",
					-1
				)
			) == int(
				observer.id
			)
		):
			return "Fling"

		var restaurant_fling: Dictionary = (
			_shallow_dictionary(
				gs.scenario_state.get(
					"last_restaurant_fling",
					{}
				)
			)
		)

		if (
			int(
				restaurant_fling.get(
					"actor_id",
					-1
				)
			) == int(
				observer.id
			)
			and int(
				restaurant_fling.get(
					"partner_id",
					-1
				)
			) == int(
				target.id
			)
		):
			return "Fling"

	return ""
func _relationship_display_name_with_age(person: Person) -> String:
	if person == null:
		return "Unknown Life"

	return "%s (Age %d)" % [_actor_display_name(person), int(person.age)]


func _card_state_for(_actor: Person, target: Person, bond_value: int) -> String:
	if target == null:
		return "conflict"

	if not _person_is_canonically_living(
		target
	):
		return "dead"

	if bond_value <= 20:
		return "conflict"

	if bond_value <= 42:
		return "strained"

	if bond_value >= 76:
		return "close"

	return "warm"

func _pulse_mode_for_state(state_name: String, bond_value: int) -> String:
	match state_name:
		"conflict":
			return "conflict_pulse"
		"strained":
			return "strained_breathe"
		"close":
			return "bond_glow"
		"dead":
			return "memorial_still"
		_:
			return "warm_breathe" if bond_value >= 55 else "idle"


func _attachment_style_for_bond(bond_value: int) -> String:
	if bond_value >= 85:
		return "secure"
	if bond_value >= 60:
		return "connected"
	if bond_value >= 35:
		return "uncertain"
	return "fractured"


func _immediate_family_ids(
		actor: Person
) -> Array:
		if actor == null:
			return []

		var ids: Array = []

		ids.append_array(
			_safe_person_id_array(
				actor,
				"parents"
			)
		)
		ids.append_array(
			_sibling_ids_for_person(
				actor
			)
		)
		ids.append_array(
			_safe_person_id_array(
				actor,
				"children"
			)
		)

		if (
			str(
				actor.marital_status
			).strip_edges().to_lower()
			== "married"
		):
			var spouse: Person = _valid_partner(
				actor
			)

			if (
				spouse != null
				and int(
					spouse.id
				) > 0
				and int(
					spouse.id
				) != int(
					actor.id
				)
			):
				ids.append(
					int(
						spouse.id
					)
				)

		return _clean_unique_ids(
			ids,
			[
				int(
					actor.id
				)
			]
		)

func _household_member_ids(actor: Person) -> Array:
	if actor == null:
		return []

	var ids: Array = []

	if (
		gs != null
		and gs.family_contract_engine != null
		and gs.family_contract_engine.has_method(
			"get_household_members"
		)
	):
		var household_raw: Variant = (
			gs.family_contract_engine
			.get_household_members(
				actor,
				{
					"source": (
						"relationships_hub_contract_engine."
						+ "household_projection"
					),
					"projection_read_only": true,
					"ui_is_renderer_only": true
				}
			)
		)

		if typeof(
			household_raw
		) == TYPE_ARRAY:
			for raw_member in household_raw as Array:
				var member_id: int = (
					_person_id_from_value(
						raw_member
					)
				)

				if member_id > 0:
					ids.append(
						member_id
					)




	if ids.is_empty():
		ids = _immediate_family_ids(
			actor
		)

		var partner: Person = _valid_partner(
			actor
		)

		if partner != null:
			ids.append(
				int(
					partner.id
				)
			)

		ids.append(
			int(
				actor.id
			)
		)

	return _clean_unique_ids(
		ids,
		[]
	)

func _household_status_lines(actor: Person) -> Array:
	var member_ids: Array = _filter_person_ids_by_alive(
		_household_member_ids(
			actor
		),
		true
	)

	return [
		"Household perspective: %s" % _actor_display_name(actor),
		"Observable members: %d" % member_ids.size(),
		"This section is a relationship projection. Household mutations remain contract-owned."
	]


func _pet_group_contract(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	var pet_rows: Array = []
	var household_embedding: bool = bool(
		context.get(
			"household_embedding",
			false
		)
	)

	if (
		gs != null
		and gs.pets_contract_engine != null
		and gs.pets_contract_engine.has_method(
			"get_pet_cards_for_actor"
		)
	):
		var pet_context: Dictionary = (
			context.duplicate(false)
		)

		pet_context [
			"source"
		] = "relationships_hub_contract_engine.pet_group"
		pet_context [
			"projection_read_only"
		] = true
		pet_context [
			"seed_if_missing"
		] = false
		pet_context [
			"ui_is_renderer_only"
		] = true

		var canonical_pet_rows: Variant = (
			gs.pets_contract_engine
			.get_pet_cards_for_actor(
				actor,
				pet_context
			)
		)

		if typeof(
			canonical_pet_rows
		) == TYPE_ARRAY:
			var canonical_pet_cards: Array = (
				canonical_pet_rows as Array
			)

			for raw_card in canonical_pet_cards:
				if typeof(
					raw_card
				) != TYPE_DICTIONARY:
					continue

				var pet_card: Dictionary = (
					raw_card as Dictionary
				).duplicate(false)

				var target_entity: Dictionary = (
					_shallow_dictionary(
						pet_card.get(
							"target_entity",
							{}
						)
					)
				)

				var owner_person_id: int = int(
					target_entity.get(
						"owner_person_id",
						target_entity.get(
							"household_access_actor_id",
							-1
						)
					)
				)

				var owner: Person = (
					_person_by_id(
						owner_person_id
					)
					if owner_person_id > 0
					else null
				)

				var owner_name: String = (
					_actor_display_name(
						owner
					)
					if owner != null
					else ""
				)

				pet_card [
					"card_kind"
				] = "entity"
				pet_card [
					"owner_person_id"
				] = owner_person_id
				pet_card [
					"owner_name"
				] = owner_name
				pet_card [
					"household_member_kind"
				] = "pet"
				pet_card [
					"section_key"
				] = (
					"household"
					if household_embedding
					else "pets"
				)
				pet_card [
					"ui_is_renderer_only"
				] = true

				if household_embedding:
					pet_card [
						"role"
					] = (
						"Pet of %s"
						% owner_name
						if owner_name != ""
						else "Household Pet"
					)

					var surface_contract: Dictionary = (
						_shallow_dictionary(
							pet_card.get(
								"surface_contract",
								{}
							)
						).duplicate(false)
					)

					if not surface_contract.is_empty():
						surface_contract [
							"section_key"
						] = "household"
						surface_contract [
							"subtitle"
						] = pet_card.get(
							"role",
							"Household Pet"
						)

						pet_card [
							"surface_contract"
						] = surface_contract

				pet_rows.append(
					pet_card
				)

	return {
		"row_kind": "entity_group",
		"title": "Pets",
		"subtitle": (
			"Animal and mythical-pet relationships remain "
			+ "first-class relationship cards."
		),
		"cards": pet_rows,
		"columns": 3,
		"empty_text": "No pets are currently observable.",
		"projection_read_only": true,
		"seed_if_missing": false,
		"household_embedding": household_embedding,
		"ui_is_renderer_only": true
	}
func _sibling_ids_for_person(person: Person) -> Array:
	if person == null:
		return []

	var parent_ids: Array = _safe_person_id_array(person, "parents")
	var siblings: Array = []

	for parent_id in parent_ids:
		var parent: Person = _person_by_id(int(parent_id))

		if parent == null:
			continue

		siblings.append_array(_safe_person_id_array(parent, "children"))

	return _clean_unique_ids(siblings, [int(person.id)])


func _ancestor_generation_ids(person: Person, generation: int) -> Array:
	if person == null or generation <= 0:
		return []

	var frontier: Array = _safe_person_id_array(person, "parents")
	var depth: int = 1

	while depth < generation:
		var next_frontier: Array = []

		for raw_id in frontier:
			var ancestor: Person = _person_by_id(int(raw_id))

			if ancestor == null:
				continue

			next_frontier.append_array(_safe_person_id_array(ancestor, "parents"))

		frontier = _clean_unique_ids(next_frontier, [])
		depth += 1

	return frontier


func _descendant_generation_ids(person: Person, generation: int) -> Array:
	if person == null or generation <= 0:
		return []

	var frontier: Array = _safe_person_id_array(person, "children")
	var depth: int = 1

	while depth < generation:
		var next_frontier: Array = []

		for raw_id in frontier:
			var descendant: Person = _person_by_id(int(raw_id))

			if descendant == null:
				continue

			next_frontier.append_array(_safe_person_id_array(descendant, "children"))

		frontier = _clean_unique_ids(next_frontier, [])
		depth += 1

	return frontier


func _aunt_uncle_ids(person: Person) -> Array:
	var out: Array = []

	for raw_parent_id in _safe_person_id_array(person, "parents"):
		var parent: Person = _person_by_id(int(raw_parent_id))

		if parent == null:
			continue

		out.append_array(_sibling_ids_for_person(parent))

	return _clean_unique_ids(out, [])


func _niece_nephew_ids(person: Person) -> Array:
	var out: Array = []

	for raw_sibling_id in _sibling_ids_for_person(person):
		var sibling: Person = _person_by_id(int(raw_sibling_id))

		if sibling == null:
			continue

		out.append_array(_safe_person_id_array(sibling, "children"))

	return _clean_unique_ids(out, [])


func _in_law_ids(person: Person) -> Array:
	var out: Array = []
	var partner: Person = _valid_partner(person)

	if partner != null:
		out.append_array(_safe_person_id_array(partner, "parents"))
		out.append_array(_sibling_ids_for_person(partner))

	for raw_sibling_id in _sibling_ids_for_person(person):
		var sibling: Person = _person_by_id(int(raw_sibling_id))

		if sibling == null:
			continue

		var sibling_partner: Person = _valid_partner(sibling)

		if sibling_partner != null:
			out.append(int(sibling_partner.id))

	return _clean_unique_ids(out, [])

func _resident_person_hydration_may_still_publish() -> bool:
	if (
		gs == null
		or typeof(
			gs.scenario_state
		) != TYPE_DICTIONARY
	):
		return false

	return (
		bool(
			gs.scenario_state.get(
				"checkpoint_payload_hydration_tail_pending",
				false
			)
		)
		or bool(
			gs.scenario_state.get(
				"checkpoint_spatial_hydration_active",
				false
			)
		)
	)
func _filter_person_ids_by_alive(
	ids: Array,
	alive_required: bool
) -> Array:
	var out: Array = []
	var resident_projection_active: bool = (
		not resident_projection_work_by_signature.is_empty()
	)
	var hydration_may_still_publish: bool = (
		resident_projection_active
		and _resident_person_hydration_may_still_publish()
	)

	for raw_id in ids:
		var target_id: int = int(
			raw_id
		)

		if target_id <= 0:
			continue





		var target: Person = null

		if (
			gs != null
			and gs.has_method(
				"get_npc_by_id"
			)
		):
			target = gs.get_npc_by_id(
				target_id,
				false
			)

		if target != null:
			if (
				_person_is_canonically_living(
					target
				)
				== alive_required
			):
				out.append(
					target_id
				)

			continue



		var facts: Dictionary = {}

		if (
			gs != null
			and gs.has_method(
				"get_npc_facts_by_id"
			)
		):
			facts = _shallow_dictionary(
				gs.get_npc_facts_by_id(
					target_id
				)
			)

		if (
			not facts.is_empty()
			and facts.has(
				"alive"
			)
		):
			if (
				_facts_are_canonically_living(
					facts
				)
				== alive_required
			):
				out.append(
					target_id
				)

			continue






		if hydration_may_still_publish:
			out.append(
				target_id
			)

	return _clean_unique_ids(
		out,
		[]
	)
func _valid_partner(person: Person) -> Person:
	if person == null:
		return null

	if gs != null and gs.has_method("get_valid_partner"):
		return gs.get_valid_partner(person, true, true)

	return person.partner


func _parent_gender_label(person: Person) -> String:
	return "Mother" if _person_gender_text(person) == "female" else "Father"


func _child_gender_label(person: Person) -> String:
	return "Daughter" if _person_gender_text(person) == "female" else "Son"


func _sibling_gender_label(person: Person) -> String:
	return "Sister" if _person_gender_text(person) == "female" else "Brother"


func _person_gender_text(person: Person) -> String:
	if person == null:
		return ""

	return str(person.gender).strip_edges().to_lower()


func _ranked_person_sort(a: Variant, b: Variant) -> bool:
	var left: Dictionary = _shallow_dictionary(a)
	var right: Dictionary = _shallow_dictionary(b)
	var left_bond: int = int(left.get("bond", 0))
	var right_bond: int = int(right.get("bond", 0))

	if left_bond == right_bond:
		return int(left.get("order", 0)) < int(right.get("order", 0))

	return left_bond > right_bond


func _resolve_section_id(raw_section: String) -> String:
	var clean_section: String = str(raw_section).strip_edges().to_lower()

	if clean_section == "overview" or clean_section == "":
		clean_section = "family"

	if (
		clean_section
		in [
			"family",
			"ancestors",
			"household",
			"partner",
			"pets",
			"descendants",
			"dead",
			"social",
			"exes"
		]
	):
		return clean_section

	return "family"


func _clean_unique_ids(
	ids: Array,
	exclude_ids: Array
) -> Array:
	var excluded: Dictionary = {}

	for raw_excluded in exclude_ids:
		var excluded_id: int = _person_id_from_value(
			raw_excluded
		)

		if excluded_id <= 0:
			continue

		excluded [
			excluded_id
		] = true

	var out: Array = []
	var seen: Dictionary = {}

	for raw_id in ids:
		var clean_id: int = _person_id_from_value(
			raw_id
		)

		if clean_id <= 0:
			continue

		if excluded.has(
			clean_id
		):
			continue

		if seen.has(
			clean_id
		):
			continue

		seen [
			clean_id
		] = true
		out.append(
			clean_id
		)

	return out


func _safe_person_id_array(
	person: Person,
	property_name: String
) -> Array:
	if person == null:
		return []

	var clean_property_name: String = str(
		property_name
	).strip_edges().to_lower()

	if clean_property_name == "flings":
		return _casual_romance_person_ids(
			person
		)

	var value: Variant = person.get(
		property_name
	)
	var out: Array = []

	if typeof(
		value
	) == TYPE_ARRAY:
		for raw_id in value as Array:
			var clean_id: int = (
				_person_id_from_value(
					raw_id
				)
			)

			if clean_id > 0:
				out.append(
					clean_id
				)











	if (
		gs != null
		and clean_property_name in [
			"parents",
			"children"
		]
	):
		var person_id: int = int(
			person.id
		)

		for raw_controlled_id in gs.controlled_lineage_ids:
			var controlled_id: int = int(
				raw_controlled_id
			)

			if (
				controlled_id <= 0
				or controlled_id == person_id
			):
				continue

			var controlled_person: Person = (
				_person_by_id(
					controlled_id
				)
			)

			if controlled_person == null:
				continue

			var reciprocal_property_name: String = (
				"parents"
				if clean_property_name == "children"
				else "children"
			)
			var reciprocal_raw: Variant = (
				controlled_person.get(
					reciprocal_property_name
				)
			)

			if typeof(
				reciprocal_raw
			) != TYPE_ARRAY:
				continue

			if _id_in_array(
				reciprocal_raw as Array,
				person_id
			):
				out.append(
					controlled_id
				)

	return _clean_unique_ids(
		out,
		[]
	)
func resident_core_switch_packet_for_actor(
	target_id: int
) -> Dictionary:
	if (
		target_id <= 0
		or gs == null
		or typeof(
			gs.scenario_state
		) != TYPE_DICTIONARY
	):
		return {}

	var packet_cache_raw: Variant = (
		gs.scenario_state.get(
			"profile_pointer_packet_by_actor",
			{}
		)
	)
	var packet_cache: Dictionary = (
		packet_cache_raw as Dictionary
		if typeof(
			packet_cache_raw
		) == TYPE_DICTIONARY
		else {}
	)
	var packet_raw: Variant = packet_cache.get(
		str(
			target_id
		),
		{}
	)
	var packet: Dictionary = (
		packet_raw as Dictionary
		if typeof(
			packet_raw
		) == TYPE_DICTIONARY
		else {}
	)

	if packet.is_empty():
		return {}




	if not _profile_switch_packet_core_hot(
		packet,
		target_id
	):
		return {}

	return packet.duplicate(false)
func _person_is_canonically_living(person: Person) -> bool:
	if person == null:
		return false

	return (
		bool(person.alive)
		and float(person.health) > 0.0
	)


func _facts_are_canonically_living(facts: Dictionary) -> bool:
	if facts.is_empty():
		return false

	if not bool(
		facts.get(
			"alive",
			false
		)
	):
		return false

	if facts.has(
		"health"
	):
		return float(
			facts.get(
				"health",
				0.0
			)
		) > 0.0




	return true


func _relationship_person_ids_for_lifecycle_classification(
	actor: Person
) -> Array:
	if actor == null:
		return []

	var ids: Array = []

	ids.append_array(
		_immediate_family_ids(
			actor
		)
	)
	ids.append_array(
		_ancestor_generation_ids(
			actor,
			2
		)
	)
	ids.append_array(
		_ancestor_generation_ids(
			actor,
			3
		)
	)
	ids.append_array(
		_household_member_ids(
			actor
		)
	)
	ids.append_array(
		_safe_person_id_array(
			actor,
			"flings"
		)
	)
	ids.append_array(
		_safe_person_id_array(
			actor,
			"friends"
		)
	)
	ids.append_array(
		_safe_person_id_array(
			actor,
			"exes"
		)
	)
	ids.append_array(
		_descendant_generation_ids(
			actor,
			2
		)
	)
	ids.append_array(
		_descendant_generation_ids(
			actor,
			3
		)
	)
	ids.append_array(
		_in_law_ids(
			actor
		)
	)
	ids.append_array(
		_aunt_uncle_ids(
			actor
		)
	)
	ids.append_array(
		_niece_nephew_ids(
			actor
		)
	)





	var direct_partner_id: int = _person_id_from_value(
		actor.partner
	)

	if direct_partner_id > 0:
		ids.append(
			direct_partner_id
		)

	return _clean_unique_ids(
		ids,
		[
			int(actor.id)
		]
	)


func _relationship_lifecycle_ids_for_section(
	actor: Person,
	section: String
) -> Array:
	if actor == null:
		return []

	var ids: Array = []

	match _resolve_section_id(
		section
	):
		"family":
			ids.append_array(
				_immediate_family_ids(
					actor
				)
			)
			ids.append_array(
				_in_law_ids(
					actor
				)
			)
			ids.append_array(
				_aunt_uncle_ids(
					actor
				)
			)
			ids.append_array(
				_niece_nephew_ids(
					actor
				)
			)

		"ancestors":
			ids.append_array(
				_ancestor_generation_ids(
					actor,
					2
				)
			)
			ids.append_array(
				_ancestor_generation_ids(
					actor,
					3
				)
			)

		"household":
			ids.append_array(
				_household_member_ids(
					actor
				)
			)

		"partner":
			var direct_partner_id: int = _person_id_from_value(
				actor.partner
			)

			if direct_partner_id > 0:
				ids.append(
					direct_partner_id
				)

			ids.append_array(
				_safe_person_id_array(
					actor,
					"flings"
				)
			)
			ids.append_array(
				_in_law_ids(
					actor
				)
			)

		"descendants":
			ids.append_array(
				_safe_person_id_array(
					actor,
					"children"
				)
			)
			ids.append_array(
				_descendant_generation_ids(
					actor,
					2
				)
			)
			ids.append_array(
				_descendant_generation_ids(
					actor,
					3
				)
			)

		"dead":
			ids.append_array(
				_relationship_person_ids_for_lifecycle_classification(
					actor
				)
			)

		"social":
			ids.append_array(
				_safe_person_id_array(
					actor,
					"friends"
				)
			)
			ids.append_array(
				_aunt_uncle_ids(
					actor
				)
			)
			ids.append_array(
				_niece_nephew_ids(
					actor
				)
			)

		"exes":
			ids.append_array(
				_safe_person_id_array(
					actor,
					"exes"
				)
			)

	return _clean_unique_ids(
		ids,
		[
			int(actor.id)
		]
	)


func _dead_other_relationship_ids(actor: Person) -> Array:
	if actor == null:
		return []

	var already_grouped_dead_ids: Array = []

	already_grouped_dead_ids.append_array(
		_filter_person_ids_by_alive(
			_ancestor_generation_ids(
				actor,
				3
			),
			false
		)
	)
	already_grouped_dead_ids.append_array(
		_filter_person_ids_by_alive(
			_ancestor_generation_ids(
				actor,
				2
			),
			false
		)
	)
	already_grouped_dead_ids.append_array(
		_filter_person_ids_by_alive(
			_safe_person_id_array(
				actor,
				"parents"
			),
			false
		)
	)
	already_grouped_dead_ids.append_array(
		_filter_person_ids_by_alive(
			_sibling_ids_for_person(
				actor
			),
			false
		)
	)
	already_grouped_dead_ids.append_array(
		_filter_person_ids_by_alive(
			_safe_person_id_array(
				actor,
				"children"
			),
			false
		)
	)

	return _clean_unique_ids(
		_filter_person_ids_by_alive(
			_relationship_person_ids_for_lifecycle_classification(
				actor
			),
			false
		),
		already_grouped_dead_ids
	)


func _relationship_lifecycle_signature(
	actor: Person,
	section: String
) -> String:
	if actor == null or gs == null:
		return ""

	var ids: Array = _relationship_lifecycle_ids_for_section(
		actor,
		section
	)
	ids.sort()

	var parts: PackedStringArray = PackedStringArray()

	for raw_id in ids:
		var target_id: int = int(
			raw_id
		)

		if target_id <= 0:
			continue

		var target: Person = null

		if gs.has_method(
			"get_npc_by_id"
		):
			target = gs.get_npc_by_id(
				target_id,
				false
			)

		if target != null:
			parts.append(
				"%d:%s"
				% [
					target_id,
					(
						"living"
						if _person_is_canonically_living(
							target
						)
						else "dead"
					)
				]
			)
			continue

		var facts: Dictionary = {}

		if gs.has_method(
			"get_npc_facts_by_id"
		):
			facts = _shallow_dictionary(
				gs.get_npc_facts_by_id(
					target_id
				)
			)

		if facts.is_empty():
			parts.append(
				"%d:unknown"
				% [
					target_id
				]
			)
			continue

		parts.append(
			"%d:%s"
			% [
				target_id,
				(
					"living"
					if _facts_are_canonically_living(
						facts
					)
					else "dead"
				)
			]
		)

	return "|".join(
		parts
	)
func _casual_romance_person_ids(
	actor: Person
) -> Array:
	if (
		actor == null
		or gs == null
	):
		return []

	var ids: Array = []
	var actor_entity_id: String = (
		"human:%d"
		% int(
			actor.id
		)
	)

	if (
		gs.relationship_graph_contract_engine != null
		and gs.relationship_graph_contract_engine.has_method(
			"relationships_for_entity"
		)
	):
		var edges: Array = (
			gs.relationship_graph_contract_engine
			.relationships_for_entity(
				actor_entity_id
			)
		)

		for raw_edge in edges:
			var edge: Dictionary = (
				_shallow_dictionary(
					raw_edge
				)
			)

			if edge.is_empty():
				continue

			var relationship_types: Dictionary = (
				_shallow_dictionary(
					edge.get(
						"relationship_types",
						{}
					)
				)
			)
			var relationship_tags: Array = _array(
				edge.get(
					"relationship_tags",
					[]
				)
			)
			var casual_romance: bool = (
				bool(
					relationship_types.get(
						"friends_with_benefits",
						false
					)
				)
				or bool(
					relationship_types.get(
						"fling",
						false
					)
				)
				or bool(
					relationship_types.get(
						"foreign_writing_fling",
						false
					)
				)
				or relationship_tags.has(
					"fwb"
				)
				or relationship_tags.has(
					"friends_with_benefits"
				)
				or relationship_tags.has(
					"fling"
				)
			)

			if not casual_romance:
				continue

			var entity_a: String = str(
				edge.get(
					"entity_a",
					""
				)
			)
			var entity_b: String = str(
				edge.get(
					"entity_b",
					""
				)
			)
			var other_entity_id: String = (
				entity_b
				if entity_a == actor_entity_id
				else entity_a
			)

			if not other_entity_id.begins_with(
				"human:"
			):
				continue

			var other_id: int = int(
				other_entity_id.trim_prefix(
					"human:"
				)
			)

			if (
				other_id > 0
				and other_id != int(
					actor.id
				)
			):
				ids.append(
					other_id
				)



	if typeof(
		gs.scenario_state
	) == TYPE_DICTIONARY:
		var foreign_contracts: Dictionary = (
			_shallow_dictionary(
				gs.scenario_state.get(
					"foreign_romance_fling_contracts",
					{}
				)
			)
		)

		for raw_key in foreign_contracts.keys():
			var row: Dictionary = (
				_shallow_dictionary(
					foreign_contracts.get(
						raw_key,
						{}
					)
				)
			)

			if (
				int(
					row.get(
						"actor_id",
						-1
					)
				) == int(
					actor.id
				)
			):
				var candidate_id: int = int(
					row.get(
						"candidate_id",
						-1
					)
				)

				if candidate_id > 0:
					ids.append(
						candidate_id
					)

		var restaurant_fling: Dictionary = (
			_shallow_dictionary(
				gs.scenario_state.get(
					"last_restaurant_fling",
					{}
				)
			)
		)

		if (
			int(
				restaurant_fling.get(
					"actor_id",
					-1
				)
			) == int(
				actor.id
			)
		):
			var restaurant_partner_id: int = int(
				restaurant_fling.get(
					"partner_id",
					-1
				)
			)

			if restaurant_partner_id > 0:
				ids.append(
					restaurant_partner_id
				)

	var official_partner: Person = _valid_partner(
		actor
	)

	if official_partner != null:
		ids.erase(
			int(
				official_partner.id
			)
		)

	return _clean_unique_ids(
		ids,
		[
			int(
				actor.id
			)
		]
	)


func _person_id_from_value(
	value: Variant
) -> int:
	if value == null:
		return -1

	if value is Person:
		var person_value: Person = value as Person

		if person_value == null:
			return -1

		return int(
			person_value.id
		)

	match typeof(
		value
	):
		TYPE_INT:
			return int(
				value
			)

		TYPE_FLOAT:
			return int(
				value
			)

		TYPE_STRING:
			var text_value: String = str(
				value
			).strip_edges()

			if text_value.is_valid_int():
				return text_value.to_int()

			return -1

		TYPE_STRING_NAME:
			var name_value: String = str(
				value
			).strip_edges()

			if name_value.is_valid_int():
				return name_value.to_int()

			return -1

		TYPE_DICTIONARY:
			var row: Dictionary = value as Dictionary

			for key in [
				"id",
				"person_id",
				"actor_id",
				"target_id",
				"partner_id"
			]:
				if not row.has(
					key
				):
					continue

				var nested_value: Variant = row.get(
					key,
					null
				)





				if nested_value is Person:
					var nested_person: Person = nested_value as Person

					if nested_person == null:
						continue

					return int(
						nested_person.id
					)

				match typeof(
					nested_value
				):
					TYPE_INT:
						return int(
							nested_value
						)

					TYPE_FLOAT:
						return int(
							nested_value
						)

					TYPE_STRING:
						var nested_text: String = str(
							nested_value
						).strip_edges()

						if nested_text.is_valid_int():
							return nested_text.to_int()

					TYPE_STRING_NAME:
						var nested_name: String = str(
							nested_value
						).strip_edges()

						if nested_name.is_valid_int():
							return nested_name.to_int()

					_:
						continue

			return -1

		_:
			return -1


func _person_by_id(person_id: int) -> Person:
	if person_id <= 0 or gs == null:
		return null

	if gs.has_method("get_or_reactivate_npc_by_id"):
		return gs.get_or_reactivate_npc_by_id(person_id)

	if gs.has_method("get_npc_by_id"):
		return gs.get_npc_by_id(person_id)

	return null
func _relationship_civic_contract_preempts_royal_interpretation(
	contract: Dictionary
) -> bool:
	if contract.is_empty():
		return false

	if (
		contract.has("is_royalty")
		and bool(
			contract.get(
				"is_royalty",
				false
			)
		)
	):
		return false

	var government_model: String = str(
		contract.get(
			"government_model",
			""
		)
	).strip_edges().to_lower()
	var office: String = str(
		contract.get(
			"office",
			""
		)
	).strip_edges().to_lower()
	var explicitly_non_royal: bool = (
		contract.has(
			"is_royalty"
		)
		and not bool(
			contract.get(
				"is_royalty",
				false
			)
		)
	)

	return (
		government_model.contains(
			"republic"
		)
		or bool(
			contract.get(
				"elected_office",
				false
			)
		)
		or (
			explicitly_non_royal
			and (
				bool(
					contract.get(
						"ruling_power_by_office",
						false
					)
				)
				or office.contains(
					"president"
				)
			)
		)
	)


func _relationship_constitutional_non_royal_identity(
	actor: Person
) -> bool:
	if actor == null:
		return false

	var public_identity_raw: Variant = actor.get(
		"public_identity_contract"
	)

	if typeof(
		public_identity_raw
	) == TYPE_DICTIONARY:
		var public_identity: Dictionary = (
			public_identity_raw as Dictionary
		)

		if bool(
			public_identity.get(
				"royal_language_forbidden",
				false
			)
		):
			return true

	var civic_raw: Variant = actor.get(
		"civic_office_contract"
	)

	if typeof(
		civic_raw
	) != TYPE_DICTIONARY:
		return false

	return _relationship_civic_contract_preempts_royal_interpretation(
		civic_raw as Dictionary
	)


func _relationship_person_has_royal_identity_truth(
	actor: Person
) -> bool:
	if (
		actor == null
		or _relationship_constitutional_non_royal_identity(
			actor
		)
	):
		return false

	var succession_rank: int = int(
		actor.succession_rank
	)

	return (
		bool(
			actor.is_royal
		)
		or str(
			actor.royal_title
		).strip_edges() != ""
		or str(
			actor.social_class
		).strip_edges().to_lower() in [
			"royal",
			"noble"
		]
		or (
			succession_rank > 0
			and succession_rank < 99
		)
	)
func _relationship_royalty_state_view_read_only() -> Dictionary:
	if gs == null:
		return {}

	var runtime_state_raw: Variant = (
		gs.royalty_institution_state
	)

	if typeof(runtime_state_raw) == TYPE_DICTIONARY:
		var runtime_state: Dictionary = (
			runtime_state_raw as Dictionary
		)

		if not runtime_state.is_empty():
			return runtime_state

	if typeof(gs.scenario_state) == TYPE_DICTIONARY:
		var scenario_state: Dictionary = (
			gs.scenario_state as Dictionary
		)
		var scenario_state_raw: Variant = (
			scenario_state.get(
				"royalty_institution_state",
				{}
			)
		)

		if typeof(scenario_state_raw) == TYPE_DICTIONARY:
			return (
				scenario_state_raw as Dictionary
			)

	return {}
func _relationship_royalty_institution_observation_for_actor(
		actor: Person
) -> Dictionary:
	if (
		actor == null
		or gs == null
	):
		return {}











	var state: Dictionary = (
		_relationship_royalty_state_view_read_only()
	)

	if state.is_empty():
		return {}

	var actor_id: int = int(
		actor.id
	)

	var person_index_raw: Variant = state.get(
		"person_index",
		{}
	)

	if typeof(person_index_raw) != TYPE_DICTIONARY:
		return {}

	var person_index: Dictionary = (
		person_index_raw as Dictionary
	)
	var person_row_raw: Variant = person_index.get(
		str(
			actor_id
		),
		{}
	)
	var person_row: Dictionary = (
		person_row_raw as Dictionary
		if typeof(person_row_raw) == TYPE_DICTIONARY
		else {}
	)

	var institution_id: String = str(
		person_row.get(
			"institution_id",
			""
		)
	).strip_edges()

	if institution_id == "":
		var realm_index_raw: Variant = state.get(
			"realm_institution_index",
			{}
		)

		if typeof(realm_index_raw) == TYPE_DICTIONARY:
			institution_id = str(
				(realm_index_raw as Dictionary).get(
					str(
						int(
							actor.realm_id
						)
					),
					""
				)
			).strip_edges()

	if institution_id == "":
		return {}

	var institutions_raw: Variant = state.get(
		"institutions",
		{}
	)

	if typeof(institutions_raw) != TYPE_DICTIONARY:
		return {}

	var institution_raw: Variant = (
		(institutions_raw as Dictionary).get(
			institution_id,
			{}
		)
	)

	if typeof(institution_raw) != TYPE_DICTIONARY:
		return {}

	var institution: Dictionary = (
		institution_raw as Dictionary
	)

	if institution.is_empty():
		return {}

	var monarch_id: int = int(
		institution.get(
			"monarch_id",
			-1
		)
	)
	var consort_id: int = int(
		institution.get(
			"consort_id",
			-1
		)
	)
	var succession_rank: int = int(
		person_row.get(
			"succession_rank",
			actor.succession_rank
		)
	)



	var monarch_row_raw: Variant = person_index.get(
		str(
			monarch_id
		),
		{}
	)
	var monarch_row: Dictionary = (
		monarch_row_raw as Dictionary
		if typeof(monarch_row_raw) == TYPE_DICTIONARY
		else {}
	)
	var monarch_succession_rank: int = int(
		monarch_row.get(
			"succession_rank",
			99
		)
	)
	var canonical_monarch_has_royal_truth: bool = (
		monarch_id > 0
		and (
			bool(
				monarch_row.get(
					"is_royal",
					false
				)
			)
			or str(
				monarch_row.get(
					"title",
					""
				)
			).strip_edges() != ""
			or (
				monarch_succession_rank > 0
				and monarch_succession_rank < 99
			)
		)
	)

	return {
		"success": true,
		"actor_id": actor_id,
		"institution_id": institution_id,
		"realm_id": int(
			institution.get(
				"realm_id",
				person_row.get(
					"realm_id",
					actor.realm_id
				)
			)
		),
		"realm_name": str(
			institution.get(
				"realm_name",
				""
			)
		).strip_edges(),
		"monarch_id": monarch_id,
		"consort_id": consort_id,
		"actor_is_canonical_monarch": (
			canonical_monarch_has_royal_truth
			and actor_id == monarch_id
		),
		"actor_is_canonical_consort": (
			canonical_monarch_has_royal_truth
			and consort_id > 0
			and actor_id == consort_id
		),
		"role": str(
			person_row.get(
				"role",
				""
			)
		).strip_edges().to_lower(),
		"succession_rank": succession_rank,
		"canonical_monarch_has_royal_truth": (
			canonical_monarch_has_royal_truth
		),
		"canonical_monarch_available": (
			canonical_monarch_has_royal_truth
		),
		"runtime_revision": int(
			state.get(
				"runtime_revision",
				0
			)
		),
		"ui_is_renderer_only": true
	}
func _relationship_institutional_title_for_actor(
	actor: Person
) -> String:
	if actor == null:
		return ""

	var civic_title: String = str(
		actor.civic_title
	).strip_edges()
	var job_text: String = str(
		actor.job
	).strip_edges()
	var job_key: String = job_text.to_lower()
	var explicit_royal_title: String = str(
		actor.royal_title
	).strip_edges()
	var explicit_title_key: String = (
		explicit_royal_title.to_lower()
	)
	var gender_key: String = str(
		actor.gender
	).strip_edges().to_lower()
	var female: bool = (
		gender_key == "female"
	)



	if civic_title != "":
		return civic_title

	if job_key in [
		"president",
		"president of the united states",
		"u.s. president"
	]:
		return "President"

	if job_key in [
		"first lady",
		"first gentleman",
		"first partner"
	]:
		if job_key == "first partner":
			return (
				"First Lady"
				if female
				else "First Gentleman"
			)

		return job_text





	if _relationship_constitutional_non_royal_identity(
		actor
	):
		return ""

	var institutional_observation: Dictionary = (
		_relationship_royalty_institution_observation_for_actor(
			actor
		)
	)
	var canonical_monarch_available: bool = bool(
		institutional_observation.get(
			"canonical_monarch_available",
			false
		)
	)
	var canonical_monarch_id: int = int(
		institutional_observation.get(
			"monarch_id",
			-1
		)
	)
	var succession_rank: int = int(
		institutional_observation.get(
			"succession_rank",
			actor.succession_rank
		)
	)
	var valid_succession_rank: bool = (
		succession_rank > 0
		and succession_rank < 99
	)
	var _social_class_key: String = str(
		actor.social_class
	).strip_edges().to_lower()
	var actor_has_royal_identity_truth: bool = (
		_relationship_person_has_royal_identity_truth(
			actor
		)
	)
	var actor_is_ruler: bool = (
		bool(
			institutional_observation.get(
				"actor_is_canonical_monarch",
				false
			)
		)
		if canonical_monarch_available
		else (
			bool(
				actor.is_ruler
			)
			and actor_has_royal_identity_truth
		)
	)
	var actor_is_canonical_consort: bool = bool(
		institutional_observation.get(
			"actor_is_canonical_consort",
			false
		)
	)

	var home_key: String = str(
		actor.home_country
	).strip_edges().to_lower()
	var birth_key: String = str(
		actor.birth_country
	).strip_edges().to_lower()
	var bending_key: String = str(
		actor.bending_nation
	).strip_edges().to_lower()
	var canonical_realm_key: String = str(
		institutional_observation.get(
			"realm_name",
			""
		)
	).strip_edges().to_lower()
	var institutional_realm_key: String = (
		canonical_realm_key
	)

	if institutional_realm_key == "":
		institutional_realm_key = home_key

	if (
		canonical_realm_key == ""
		and bending_key in [
			"fire",
			"fire nation",
			"fire_nation",
			"earth",
			"earth kingdom",
			"earth_kingdom",
			"water",
			"water tribe",
			"water_tribe",
			"air",
			"air nomads",
			"air_nomads"
		]
	):
		institutional_realm_key = bending_key
	elif institutional_realm_key == "":
		institutional_realm_key = birth_key

	var fire_nation: bool = (
		institutional_realm_key == "fire"
		or "fire nation" in institutional_realm_key
		or "fire_nation" in institutional_realm_key
	)
	var earth_kingdom: bool = (
		institutional_realm_key == "earth"
		or "earth kingdom" in institutional_realm_key
		or "earth_kingdom" in institutional_realm_key
	)
	var water_tribe: bool = (
		institutional_realm_key == "water"
		or "water tribe" in institutional_realm_key
		or "water_tribe" in institutional_realm_key
	)
	var air_nomads: bool = (
		institutional_realm_key == "air"
		or "air nomad" in institutional_realm_key
		or "air_nomads" in institutional_realm_key
	)
	var egyptian_realm: bool = (
		"egypt" in institutional_realm_key
	)
	var partner_id: int = _person_id_from_value(
		actor.partner
	)
	var partner_is_ruler: bool = false

	if canonical_monarch_available:
		partner_is_ruler = (
			partner_id > 0
			and partner_id == canonical_monarch_id
		)
	else:
		var partner: Person = _person_by_id(
			partner_id
		)

		partner_is_ruler = (
			partner != null
			and bool(
				partner.is_ruler
			)
			and _relationship_person_has_royal_identity_truth(
				partner
			)
		)

	var actor_is_monarch_child: bool = (
		canonical_monarch_available
		and canonical_monarch_id > 0
		and _id_in_array(
			_safe_person_id_array(
				actor,
				"parents"
			),
			canonical_monarch_id
		)
	)




	var actor_is_royal_member: bool = (
		actor_has_royal_identity_truth
		or actor_is_monarch_child
	)
	var actor_is_consort: bool = (
		actor_is_canonical_consort
		or partner_is_ruler
	)
	var royal_title_evidence: bool = (
		actor_is_ruler
		or actor_is_consort
		or actor_is_royal_member
	)

	if not royal_title_evidence:
		return ""

	if (
		(
			"egypt" in explicit_title_key
			or explicit_title_key == "pharaoh"
		)
		and not egyptian_realm
	):
		explicit_royal_title = ""
		explicit_title_key = ""

	if (
		explicit_title_key.begins_with(
			"fire "
		)
		and not fire_nation
	):
		explicit_royal_title = ""
		explicit_title_key = ""

	if (
		explicit_title_key.begins_with(
			"earth "
		)
		and not earth_kingdom
	):
		explicit_royal_title = ""
		explicit_title_key = ""

	if (
		(
			explicit_title_key.begins_with(
				"sky "
			)
			or explicit_title_key == "air regent"
		)
		and not air_nomads
	):
		explicit_royal_title = ""
		explicit_title_key = ""

	var explicit_title_is_ruler_only: bool = (
		explicit_title_key in [
			"king",
			"queen",
			"emperor",
			"empress",
			"pharaoh",
			"fire lord",
			"fire queen",
			"earth king",
			"earth queen",
			"chief",
			"air regent",
			"prime sovereign"
		]
	)

	if (
		explicit_title_is_ruler_only
		and not actor_is_ruler
	):
		explicit_royal_title = ""
		explicit_title_key = ""

	if fire_nation:
		if actor_is_ruler:
			return (
				"Fire Queen"
				if female
				else "Fire Lord"
			)

		if actor_is_consort:
			return (
				"Fire Queen Consort"
				if female
				else "Fire Prince Consort"
			)

		if explicit_royal_title != "":
			return explicit_royal_title

		if succession_rank == 1:
			return (
				"Crown Princess of the Fire Nation"
				if female
				else "Crown Prince of the Fire Nation"
			)

		if (
			valid_succession_rank
			or actor_is_royal_member
		):
			return (
				"Fire Princess"
				if female
				else "Fire Prince"
			)

		return ""

	if earth_kingdom:
		if actor_is_ruler:
			return (
				"Earth Queen"
				if female
				else "Earth King"
			)

		if actor_is_consort:
			return (
				"Earth Queen Consort"
				if female
				else "Earth Prince Consort"
			)

		if explicit_royal_title != "":
			return explicit_royal_title

		if succession_rank == 1:
			return (
				"Crown Princess of the Earth Kingdom"
				if female
				else "Crown Prince of the Earth Kingdom"
			)

		if (
			valid_succession_rank
			or actor_is_royal_member
		):
			return (
				"Earth Princess"
				if female
				else "Earth Prince"
			)

		return ""

	if egyptian_realm:
		if actor_is_ruler:
			return "Pharaoh"

		if actor_is_consort:
			return "Royal Consort of Egypt"

		if explicit_royal_title != "":
			return explicit_royal_title

		if succession_rank == 1:
			return (
				"Crown Princess of Egypt"
				if female
				else "Crown Prince of Egypt"
			)

		if (
			valid_succession_rank
			or actor_is_royal_member
		):
			return (
				"Princess of Egypt"
				if female
				else "Prince of Egypt"
			)

		return ""

	if water_tribe:
		if actor_is_ruler:
			return "Chief"

		if actor_is_consort:
			return "Tribal Consort"

		if explicit_royal_title != "":
			return explicit_royal_title

		if succession_rank == 1:
			return "Tribal Heir"

		if (
			valid_succession_rank
			or actor_is_royal_member
		):
			return (
				"Water Princess"
				if female
				else "Water Prince"
			)

		return ""

	if air_nomads:
		if actor_is_ruler:
			return "Air Regent"

		if actor_is_consort:
			return "Sky Consort"

		if explicit_royal_title != "":
			return explicit_royal_title

		if succession_rank == 1:
			return "Temple Heir"

		if (
			valid_succession_rank
			or actor_is_royal_member
		):
			return (
				"Sky Princess"
				if female
				else "Sky Prince"
			)

		return ""

	if actor_is_ruler:
		return (
			"Queen"
			if female
			else "King"
		)

	if actor_is_consort:
		return (
			"Queen Consort"
			if female
			else "Prince Consort"
		)

	if explicit_royal_title != "":
		return explicit_royal_title

	if succession_rank == 1:
		return (
			"Crown Princess"
			if female
			else "Crown Prince"
		)

	if (
		valid_succession_rank
		or actor_is_royal_member
	):
		return (
			"Princess"
			if female
			else "Prince"
		)

	return ""
func _actor_display_name(
	actor: Person
) -> String:
	if actor == null:
		return "Unknown Life"

	var first_name: String = str(
		actor.first_name
	).strip_edges()
	var last_name: String = str(
		actor.last_name
	).strip_edges()
	var full_name: String = (
		"%s %s"
		% [
			first_name,
			last_name
		]
	)

	full_name = full_name.strip_edges()

	if full_name == "":
		full_name = str(actor.name).strip_edges()

	if full_name == "":
		full_name = "Life %d" % int(actor.id)

	var institutional_title: String = (
		_relationship_institutional_title_for_actor(
			actor
		)
	)

	if institutional_title == "":
		return full_name

	if full_name.to_lower().begins_with(
		institutional_title.to_lower()
	):
		return full_name

	return "%s (%s)" % [
		institutional_title,
		full_name
	]


func _health_base_display_max(_health_value: int) -> int:
	return 100


func _is_parent_of(parent: Person, child: Person) -> bool:
	if parent == null or child == null:
		return false

	return _id_in_array(_safe_person_id_array(child, "parents"), int(parent.id))


func _id_in_array(values: Array, person_id: int) -> bool:
	for raw_value in values:
		if _person_id_from_value(raw_value) == person_id:
			return true

	return false

func _relationship_temporal_frontier_signature() -> String:
	if gs == null:
		return "world:unbound|npc_age:unbound"

	var current_year: int = int(
		gs.year
	)

	if typeof(
		gs.scenario_state
	) != TYPE_DICTIONARY:
		return (
			"world:%d|npc_age:state_unavailable"
			% current_year
		)

	var report: Dictionary = _shallow_dictionary(
		gs.scenario_state.get(
			"last_world_engine_age_npcs_report",
			{}
		)
	)
	var report_year: int = int(
		report.get(
			"year",
			-999999
		)
	)
	var source_year: int = int(
		report.get(
			"source_year",
			-999999
		)
	)
	var receipt_key: String = str(
		report.get(
			"receipt_key",
			""
		)
	).strip_edges()
	var complete: bool = (
		str(
			report.get(
				"schema",
				""
			)
		).strip_edges()
		== "eralife.world_engine_age_npcs_report"
		and str(
			report.get(
				"authority",
				""
			)
		).strip_edges()
		== "world_engine"
		and str(
			report.get(
				"task",
				""
			)
		).strip_edges()
		== "age_npcs"
		and report_year == current_year
		and bool(
			report.get(
				"is_complete",
				false
			)
		)
		and bool(
			report.get(
				"completion_receipt",
				false
			)
		)
	)

	return (
		"world:%d|npc_source:%d|npc_year:%d|npc_complete:%s|receipt:%s"
		% [
			current_year,
			source_year,
			report_year,
			str(complete),
			receipt_key
		]
	)
func _hub_signature(
	actor: Person,
	section: String,
	context: Dictionary
) -> String:
	var romance_projection_revision: int = 0

	if (
		section == "partner"
		and actor != null
		and gs != null
		and gs.relationship_activities_engine != null
		and gs.relationship_activities_engine.has_method(
			"resident_romance_projection_revision_for_pair"
		)
	):
		var partner: Person = _valid_partner(
			actor
		)

		if partner != null:
			romance_projection_revision = int(
				gs.relationship_activities_engine
				.resident_romance_projection_revision_for_pair(
					actor,
					partner
				)
			)

	var lifecycle_signature: String = (
		_relationship_lifecycle_signature(
			actor,
			section
		)
	)
	var temporal_frontier_signature: String = (
		_relationship_temporal_frontier_signature()
	)

	return (
		"%d:%d:%s:%s:%s:%s:%s:romance%d:%s"
		% [
			int(
				actor.id
			),
			_current_year(),
			section,
			_affection_signature(
				actor
			),
			_relationship_graph_revision(),
			lifecycle_signature,
			str(
				context.get(
					"reality_revision",
					""
				)
			),
			romance_projection_revision,
			temporal_frontier_signature
		]
	)
func _relationship_graph_revision() -> String:
	if (
		gs == null
		or gs.relationship_graph_contract_engine == null
		or not gs.relationship_graph_contract_engine.has_method(
			"graph"
		)
	):
		return ""

	var graph_contract: Dictionary = (
		_shallow_dictionary(
			gs.relationship_graph_contract_engine.graph()
		)
	)

	return str(
		graph_contract.get(
			"last_event_id",
			graph_contract.get(
				"updated_at_ms",
				""
			)
		)
	)

func _group_signature(
	actor: Person,
	title_text: String,
	ids: Array,
	options: Dictionary,
	context: Dictionary
) -> String:
	return (
		"%d:%d:%s:%s:%s:%s:%s:%s"
		% [
			int(
				actor.id
			),
			_current_year(),
			title_text,
			_stable_array_signature(
				ids
			),
			_relationship_graph_revision(),
			str(
				context.get(
					"reality_revision",
					""
				)
			),
			str(
				options.hash()
			),
			_relationship_temporal_frontier_signature()
		]
	)
func _card_signature(
	actor: Person,
	target: Person,
	section_key: String,
	featured: bool,
	context: Dictionary
) -> String:
	var bond_value: int = int(
		context.get(
			"precomputed_bond",
			-1
		)
	)

	if bond_value < 0:
		bond_value = (
			_projection_bond_score_for_pair(
				actor,
				target,
				context
			)
			if bool(
				context.get(
					"projection_read_only",
					false
				)
			)
			else bond_score_for_pair(
				actor,
				target
			)
		)

	return (
		"%d:%d:%d:%d:%s:%s:%d:%d:%s"
		% [
			int(
				actor.id
			),
			int(
				target.id
			),
			_current_year(),
			int(
				target.age
			),
			section_key,
			str(
				featured
			),
			bond_value,
			int(
				round(
					float(
						target.health
					)
				)
			),
			str(
				bool(
					target.alive
				)
			)
		]
	)

func _affection_signature(actor: Person) -> String:
	if actor == null:
		return ""

	return str(actor.affection.hash())


func _stable_array_signature(values: Array) -> String:
	var clean: PackedStringArray = PackedStringArray()

	for value in values:
		clean.append(str(value))

	return "|".join(clean)


func _store_hub_contract(
	signature: String,
	contract: Dictionary
) -> void:
	hub_contract_cache [
		signature
	] = contract.duplicate(false)
	_trim_cache(
		hub_contract_cache
	)


func _store_group_contract(
	signature: String,
	contract: Dictionary
) -> void:
	group_contract_cache [
		signature
	] = contract.duplicate(false)
	_trim_cache(
		group_contract_cache
	)


func _store_card_contract(
	signature: String,
	contract: Dictionary
) -> void:
	card_contract_cache [
		signature
	] = contract.duplicate(false)
	_trim_cache(
		card_contract_cache
	)


func _trim_cache(cache: Dictionary) -> void:
	while cache.size() > MAX_CACHE_SIZE:
		var keys: Array = cache.keys()

		if keys.is_empty():
			break

		cache.erase(keys.front())


func _current_year() -> int:
	return int(gs.year) if gs != null else 0


func _ensure_state() -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var canonical_switch_authority: UniversalSwitchContractEngine = (
		_resolve_canonical_switch_engine()
	)

	gs.scenario_state [
		"relationships_hub_contract_engine_resident"
	] = true
	gs.scenario_state [
		"relationships_hub_contract_engine_schema"
	] = ENGINE_SCHEMA
	gs.scenario_state [
		"relationships_hub_contract_engine_version"
	] = CONTRACT_VERSION
	gs.scenario_state [
		"relationships_hub_switch_destination_lane_resident"
	] = true
	gs.scenario_state [
		"relationships_hub_switch_destination_lane_service_owner"
	] = "RelationshipsHubContractEngine"
	gs.scenario_state [
		"relationships_hub_switch_destination_lane_producer_authority"
	] = (
		"UniversalSwitchContractEngine"
		if canonical_switch_authority != null
		else "missing"
	)
	gs.scenario_state [
		"relationships_hub_switch_destination_lane_authority_hot"
	] = (
		canonical_switch_authority != null
	)
	gs.scenario_state [
		"relationships_hub_switch_destination_lane_main_scene_service_required"
	] = false
	gs.scenario_state [
		"relationships_hub_switch_destination_lane_ready_gate_member"
	] = false


func _fail(reason: String, context: Dictionary = {}) -> Dictionary:
	EraLog.failure(
		get_script().resource_path.get_file(),
		str(reason)
	)
	return {
		"success": false,
		"schema": ENGINE_SCHEMA,
		"version": CONTRACT_VERSION,
		"reason": reason,
		"context": context.duplicate(true),
		"ui_is_renderer_only": true
	}


func _join_strings(values: Array, separator: String = ", ") -> String:
	var clean: PackedStringArray = PackedStringArray()

	for raw_value in values:
		var text: String = str(raw_value).strip_edges()

		if text != "":
			clean.append(text)

	return separator.join(clean)


func _shallow_dictionary(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(false)
	return {}


func _shallow_array(
	value: Variant
) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return (
			value as Array
		).duplicate(false)

	return []
func _context_forbids_switch_packet_resolution(
	context: Dictionary
) -> bool:
	if context.is_empty():
		return false

	return (
		bool(
			context.get(
				"recursive_switch_packet_publication_forbidden",
				false
			)
		)
		or bool(
			context.get(
				"relationship_card_switch_packets_forbidden",
				false
			)
		)
		or bool(
			context.get(
				"profile_switch_packet_resolution_forbidden",
				false
			)
		)
		or bool(
			context.get(
				"switch_shell_stage_forbidden",
				false
			)
		)
		or bool(
			context.get(
				"support_packet_publication_context",
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

func _array(
	value: Variant
) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return (
			value as Array
		).duplicate(false)

	return []