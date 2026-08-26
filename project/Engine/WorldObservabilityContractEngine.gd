extends Resource
class_name WorldObservabilityContractEngine

const ENGINE_SCHEMA:= "eralife.world_observability_contract_engine"
const CONTRACT_VERSION:= 1

signal world_browser_contract_ready(
	signature: String,
	contract: Dictionary
)

var gs = null
var last_report: Dictionary = {}



var world_browser_work_by_signature: Dictionary = {}
var world_browser_contract_by_signature: Dictionary = {}
var world_browser_step_armed_by_signature: Dictionary = {}


func _init(_gs = null) -> void:
	bind_game_state(_gs)


func bind_game_state(_gs) -> void:
	gs = _gs

func resolve_intent(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	if gs == null:
		return {
			"success": false,
			"reason": "missing_game_state",
			"schema": ENGINE_SCHEMA
		}

	if actor == null:
		return {
			"success": false,
			"reason": "missing_actor",
			"schema": ENGINE_SCHEMA
		}

	var action_id: String = str(
		payload.get(
			"action_id",
			"observe_world_browser"
		)
	).strip_edges().to_lower()
	var signature: String = str(
		payload.get(
			"signature",
			_world_browser_signature(
				actor
			)
		)
	).strip_edges()

	match action_id:
		"prewarm_world_browser", \
"refresh_world_browser", \
"observe_world_browser":
			return begin_world_browser_projection(
				actor,
				{
					"signature": signature,
					"force_refresh": (
						action_id == "refresh_world_browser"
						or bool(
							payload.get(
								"force_refresh",
								false
							)
						)
					),
					"source": str(
						payload.get(
							"source",
							"world_observability_contract_engine.resolve_intent"
						)
					),
					"ready_gate_member": false,
					"build_on_click_forbidden": true,
					"ui_is_renderer_only": true
				}.merged(
					payload,
					true
				)
			)

		_:
			return {
				"success": false,
				"reason": "unsupported_world_browser_intent",
				"action_id": action_id,
				"schema": ENGINE_SCHEMA,
				"ui_is_renderer_only": true
			}


func begin_world_browser_projection(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	if (
		gs == null
		or actor == null
	):
		return {
			"success": false,
			"reason": "missing_world_browser_authority",
			"schema": ENGINE_SCHEMA
		}

	var signature: String = str(
		context.get(
			"signature",
			_world_browser_signature(
				actor
			)
		)
	).strip_edges()
	var force_refresh: bool = bool(
		context.get(
			"force_refresh",
			false
		)
	)

	if signature == "":
		return {
			"success": false,
			"reason": "missing_world_browser_signature",
			"schema": ENGINE_SCHEMA
		}

	if (
		not force_refresh
		and world_browser_contract_by_signature.has(
			signature
		)
	):
		call_deferred(
			"_emit_cached_world_browser_contract",
			signature
		)

		return {
			"success": true,
			"complete": true,
			"cache_hit": true,
			"signature": signature,
			"contract": _world_browser_contract(
				signature
			),
			"ready_gate_member": false,
			"build_on_click_forbidden": true,
			"ui_is_renderer_only": true
		}

	if force_refresh:
		world_browser_contract_by_signature.erase(
			signature
		)
		world_browser_work_by_signature.erase(
			signature
		)
		world_browser_step_armed_by_signature.erase(
			signature
		)

	if world_browser_work_by_signature.has(
		signature
	):
		_schedule_world_browser_projection_step(
			signature
		)

		return _world_browser_projection_status(
			signature
		)

	world_browser_work_by_signature [
		signature
	] = {
		"signature": signature,
		"actor_id": int(
			actor.id
		),
		"actor_ref": actor,
		"phase": "prepare_hidden",
		"realm_registry": {},
		"realm_keys": [],
		"realm_index_cursor": 0,
		"realm_name_index": {},
		"country_names": [],
		"country_cursor": 0,
		"realm_cursor": 0,
		"hidden_registry": {},
		"hidden_keys": [],
		"hidden_cursor": 0,
		"provider_ids": [
			"vormir_engine",
			"nidavellir_engine",
			"bridge_to_terabithia_engine"
		],
		"provider_cursor": 0,
		"external_entries": [],
		"external_cursor": 0,
		"entries": [],
		"seen": {},
		"context": context.duplicate(false),
		"started_at_ms": int(
			Time.get_ticks_msec()
		),
		"last_step_at_ms": 0,
		"yield_count": 0,
		"complete": false,
		"failed": false,
		"ready_gate_member": false,
		"build_on_click_forbidden": true,
		"ui_is_renderer_only": true
	}

	if typeof(
		gs.scenario_state
	) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	gs.scenario_state [
		"world_browser_projection_pending"
	] = true
	gs.scenario_state [
		"world_browser_projection_signature"
	] = signature
	gs.scenario_state [
		"world_browser_projection_ready_gate_member"
	] = false
	gs.scenario_state [
		"world_browser_projection_build_on_click_forbidden"
	] = true
	gs.scenario_state [
		"world_browser_projection_engine_owned"
	] = true

	_schedule_world_browser_projection_step(
		signature
	)

	return _world_browser_projection_status(
		signature
	)


func _world_browser_contract(
	signature: String
) -> Dictionary:
	var contract_raw: Variant = (
		world_browser_contract_by_signature.get(
			str(
				signature
			).strip_edges(),
			{}
		)
	)

	return (
		(
			contract_raw as Dictionary
		).duplicate(false)
		if typeof(
			contract_raw
		) == TYPE_DICTIONARY
		else {}
	)


func _world_browser_projection_status(
	signature: String
) -> Dictionary:
	var clean_signature: String = str(
		signature
	).strip_edges()
	var contract: Dictionary = (
		_world_browser_contract(
			clean_signature
		)
	)

	if not contract.is_empty():
		return {
			"success": true,
			"complete": true,
			"signature": clean_signature,
			"contract": contract,
			"ready_gate_member": false,
			"ui_is_renderer_only": true
		}

	var work_raw: Variant = (
		world_browser_work_by_signature.get(
			clean_signature,
			{}
		)
	)
	var work: Dictionary = (
		work_raw as Dictionary
		if typeof(
			work_raw
		) == TYPE_DICTIONARY
		else {}
	)

	if work.is_empty():
		return {
			"success": false,
			"complete": false,
			"reason": "world_browser_projection_not_found",
			"signature": clean_signature,
			"ui_is_renderer_only": true
		}

	return {
		"success": not bool(
			work.get(
				"failed",
				false
			)
		),
		"complete": bool(
			work.get(
				"complete",
				false
			)
		),
		"failed": bool(
			work.get(
				"failed",
				false
			)
		),
		"signature": clean_signature,
		"phase": str(
			work.get(
				"phase",
				""
			)
		),
		"entry_count": (
			(
				work.get(
					"entries",
					[]
				) as Array
			).size()
			if typeof(
				work.get(
					"entries",
					[]
				)
			) == TYPE_ARRAY
			else 0
		),
		"yield_count": int(
			work.get(
				"yield_count",
				0
			)
		),
		"ready_gate_member": false,
		"build_on_click_forbidden": true,
		"ui_is_renderer_only": true
	}


func _emit_cached_world_browser_contract(
	signature: String
) -> void:
	var contract: Dictionary = _world_browser_contract(
		signature
	)

	if contract.is_empty():
		return

	world_browser_contract_ready.emit(
		signature,
		contract.duplicate(false)
	)


func _schedule_world_browser_projection_step(
	signature: String
) -> void:
	var clean_signature: String = str(
		signature
	).strip_edges()

	if clean_signature == "":
		return

	if bool(
		world_browser_step_armed_by_signature.get(
			clean_signature,
			false
		)
	):
		return

	world_browser_step_armed_by_signature [
		clean_signature
	] = true

	var tree:= Engine.get_main_loop() as SceneTree

	if tree == null:
		call_deferred(
			"_continue_world_browser_projection",
			clean_signature
		)
		return

	tree.process_frame.connect(
		Callable(
			self,
			"_continue_world_browser_projection"
		).bind(
			clean_signature
		),
		CONNECT_ONE_SHOT
	)


func _continue_world_browser_projection(
	signature: String
) -> void:
	var clean_signature: String = str(
		signature
	).strip_edges()

	world_browser_step_armed_by_signature [
		clean_signature
	] = false

	var work_raw: Variant = (
		world_browser_work_by_signature.get(
			clean_signature,
			{}
		)
	)
	var work: Dictionary = (
		work_raw as Dictionary
		if typeof(
			work_raw
		) == TYPE_DICTIONARY
		else {}
	)

	if (
		work.is_empty()
		or bool(
			work.get(
				"complete",
				false
			)
		)
		or bool(
			work.get(
				"failed",
				false
			)
		)
	):
		return

	if _world_browser_should_yield_to_ui():
		work ["yield_count"] = int(
			work.get(
				"yield_count",
				0
			)
		) + 1
		work ["last_yield_at_ms"] = int(
			Time.get_ticks_msec()
		)
		work [
			"last_yield_reason"
		] = "interactive_renderer_has_priority"

		world_browser_work_by_signature [
			clean_signature
		] = work

		_schedule_world_browser_projection_step(
			clean_signature
		)
		return

	var phase: String = str(
		work.get(
			"phase",
			"prepare_realms"
		)
	)
	var actor_raw: Variant = work.get(
		"actor_ref",
		null
	)
	var actor: Person = (
		actor_raw as Person
		if actor_raw is Person
		else null
	)

	match phase:
		"prepare_realms":
			var realm_registry: Dictionary = (
				_world_browser_realm_registry()
			)
			var realm_name_index: Dictionary = {}
			var scheduled_realm_entries: Array = []
			var section_priority: Dictionary = {
				"interrealm_authority": 0,
				"space_realms": 10,
				"imaginative_realms": 20,
				"elemental_realms": 30,
				"standard_realms": 40
			}

			for raw_realm_key in realm_registry.keys():
				var realm_raw: Variant = (
					realm_registry.get(
						raw_realm_key,
						{}
					)
				)

				if typeof(
					realm_raw
				) != TYPE_DICTIONARY:
					continue

				var realm: Dictionary = (
					realm_raw as Dictionary
				)
				var realm_name_key: String = (
					_world_browser_identity_key(
						str(
							realm.get(
								"name",
								realm.get(
									"country",
									""
								)
							)
						)
					)
				)

				if realm_name_key != "":
					realm_name_index [
						realm_name_key
					] = raw_realm_key

				var realm_entry: Dictionary = (
					_world_browser_realm_entry(
						realm,
						raw_realm_key,
						"realm_engine.resident_registry"
					)
				)

				if (
					realm_entry.is_empty()
					or not _world_browser_entry_allowed(
						realm_entry
					)
				):
					continue

				scheduled_realm_entries.append(
					realm_entry
				)

			scheduled_realm_entries.sort_custom(
				func (a, b) -> bool:
					var entry_a: Dictionary = a as Dictionary
					var entry_b: Dictionary = b as Dictionary
					var section_a: String = str(
						entry_a.get(
							"browser_section",
							"standard_realms"
						)
					)
					var section_b: String = str(
						entry_b.get(
							"browser_section",
							"standard_realms"
						)
					)
					var section_rank_a: int = int(
						section_priority.get(
							section_a,
							99
						)
					)
					var section_rank_b: int = int(
						section_priority.get(
							section_b,
							99
						)
					)

					if section_rank_a != section_rank_b:
						return section_rank_a < section_rank_b

					var priority_a: int = int(
						entry_a.get(
							"_sort_priority",
							99
						)
					)
					var priority_b: int = int(
						entry_b.get(
							"_sort_priority",
							99
						)
					)

					if priority_a != priority_b:
						return priority_a < priority_b

					return str(
						entry_a.get(
							"name",
							""
						)
					) < str(
						entry_b.get(
							"name",
							""
						)
					)
			)

			work ["realm_registry"] = realm_registry
			work ["realm_name_index"] = realm_name_index
			work ["realm_entries"] = scheduled_realm_entries
			work ["realm_cursor"] = 0
			work ["phase"] = "realms"

		"prepare_countries":
			work [
				"country_names"
			] = _world_browser_country_names(
				actor
			)
			work ["country_cursor"] = 0
			work ["phase"] = "countries"

		"countries":
			var country_names: Array = (
				work.get(
					"country_names",
					[]
				) as Array
			)
			var country_cursor: int = int(
				work.get(
					"country_cursor",
					0
				)
			)

			if country_cursor >= country_names.size():
				work ["phase"] = "prepare_external"
			else:
				var country_name: String = str(
					country_names [
						country_cursor
					]
				).strip_edges()
				var country_entry: Dictionary = (
					_world_browser_country_entry(
						country_name,
						country_cursor,
						work
					)
				)

				_world_browser_append_unique(
					work,
					country_entry
				)

				work [
					"country_cursor"
				] = country_cursor + 1

		"realms":
			var realm_entries: Array = (
				work.get(
					"realm_entries",
					[]
				) as Array
			)
			var realm_cursor: int = int(
				work.get(
					"realm_cursor",
					0
				)
			)

			if realm_cursor >= realm_entries.size():
				work ["phase"] = "prepare_countries"
			else:
				var realm_entry_raw: Variant = (
					realm_entries [
						realm_cursor
					]
				)

				if typeof(
					realm_entry_raw
				) == TYPE_DICTIONARY:
					_world_browser_append_unique(
						work,
						realm_entry_raw as Dictionary
					)

				work [
					"realm_cursor"
				] = realm_cursor + 1

		"prepare_hidden":
			var hidden_registry: Dictionary = (
				_world_browser_hidden_registry()
			)

			work [
				"hidden_registry"
			] = hidden_registry
			work [
				"hidden_keys"
			] = hidden_registry.keys()
			work ["hidden_cursor"] = 0
			work ["phase"] = "hidden"

		"hidden":
			var hidden_keys: Array = (
				work.get(
					"hidden_keys",
					[]
				) as Array
			)
			var hidden_cursor: int = int(
				work.get(
					"hidden_cursor",
					0
				)
			)

			if hidden_cursor >= hidden_keys.size():
				work ["phase"] = "providers"
			else:
				var raw_hidden_key: Variant = (
					hidden_keys [
						hidden_cursor
					]
				)
				var hidden_registry: Dictionary = (
					work.get(
						"hidden_registry",
						{}
					) as Dictionary
				)
				var hidden_raw: Variant = (
					hidden_registry.get(
						raw_hidden_key,
						{}
					)
				)

				if typeof(
					hidden_raw
				) == TYPE_DICTIONARY:
					var hidden_entry: Dictionary = (
						_world_browser_realm_entry(
							hidden_raw as Dictionary,
							raw_hidden_key,
							"many_realms_engine.resident_registry"
						)
					)

					if (
						_world_browser_entry_allowed(
							hidden_entry
						)
					):
						_world_browser_append_unique(
							work,
							hidden_entry
						)

				work [
					"hidden_cursor"
				] = hidden_cursor + 1

		"providers":
			var provider_ids: Array = (
				work.get(
					"provider_ids",
					[]
				) as Array
			)
			var provider_cursor: int = int(
				work.get(
					"provider_cursor",
					0
				)
			)

			if provider_cursor >= provider_ids.size():
				work ["phase"] = "prepare_realms"
			else:
				var provider_id: String = str(
					provider_ids [
						provider_cursor
					]
				)
				var provider_entry: Dictionary = (
					_world_browser_provider_entry(
						provider_id
					)
				)

				if (
					not provider_entry.is_empty()
					and _world_browser_entry_allowed(
						provider_entry
					)
				):
					_world_browser_append_unique(
						work,
						provider_entry
					)

				work [
					"provider_cursor"
				] = provider_cursor + 1

		"prepare_external":
			work [
				"external_entries"
			] = _world_browser_external_entries()
			work ["external_cursor"] = 0
			work ["phase"] = "external"

		"external":
			var external_entries: Array = (
				work.get(
					"external_entries",
					[]
				) as Array
			)
			var external_cursor: int = int(
				work.get(
					"external_cursor",
					0
				)
			)

			if external_cursor >= external_entries.size():
				work ["phase"] = "complete"
			else:
				var external_raw: Variant = (
					external_entries [
						external_cursor
					]
				)

				if typeof(
					external_raw
				) == TYPE_DICTIONARY:
					var external_entry: Dictionary = (
						_world_browser_normalize_entry(
							external_raw as Dictionary,
							"realm_contract_engine.external_surface"
						)
					)

					if (
						not external_entry.is_empty()
						and _world_browser_entry_allowed(
							external_entry
						)
					):
						_world_browser_append_unique(
							work,
							external_entry
						)

				work [
					"external_cursor"
				] = external_cursor + 1

		"complete":
			world_browser_work_by_signature [
				clean_signature
			] = work

			_finalize_world_browser_projection(
				clean_signature
			)
			return

		_:
			work ["failed"] = true
			work [
				"failure_reason"
			] = "unknown_world_browser_phase"

	work ["last_step_at_ms"] = int(
		Time.get_ticks_msec()
	)

	world_browser_work_by_signature [
		clean_signature
	] = work

	if bool(
		work.get(
			"failed",
			false
		)
	):
		return

	_schedule_world_browser_projection_step(
		clean_signature
	)

func _world_browser_should_yield_to_ui() -> bool:
	if (
		gs == null
		or typeof(
			gs.scenario_state
		) != TYPE_DICTIONARY
	):
		return false

	var now_ms: int = int(
		Time.get_ticks_msec()
	)
	var scenario: Dictionary = (
		gs.scenario_state
	)
	var runtime_guard_raw: Variant = scenario.get(
		"runtime_guard",
		{}
	)
	var runtime_guard: Dictionary = (
		runtime_guard_raw as Dictionary
		if typeof(
			runtime_guard_raw
		) == TYPE_DICTIONARY
		else {}
	)
	var zero_frame_surface_staged: bool = (
		bool(
			scenario.get(
				"god_mode_zero_frame_entry_surface_staged",
				false
			)
		)
		or bool(
			scenario.get(
				"god_mode_ready_aaa_life_shell_hot",
				false
			)
		)
	)
	var player_control_released: bool = bool(
		scenario.get(
			"playable_life_surface_player_control_released",
			false
		)
	)
	var first_paint_complete: bool = bool(
		scenario.get(
			"ready_door_first_paint_complete",
			false
		)
	)
	var ready_door_input_fence_until_ms: int = int(
		scenario.get(
			"ready_door_zero_frame_input_fence_until_ms",
			0
		)
	)



	if (
		zero_frame_surface_staged
		and (
			not player_control_released
			or not first_paint_complete
		)
	):
		return true

	if (
		not player_control_released
		or not first_paint_complete
	):
		var interaction_grace_until_ms: int = int(
			runtime_guard.get(
				"ui_interaction_grace_until_ms",
				0
			)
		)
		var truth_resolution_yield_until_ms: int = int(
			runtime_guard.get(
				"truth_resolution_yield_until_ms",
				0
			)
		)
		var pre_ready_yield_until_ms: int = maxi(
			maxi(
				interaction_grace_until_ms,
				truth_resolution_yield_until_ms
			),
			ready_door_input_fence_until_ms
		)

		return now_ms < pre_ready_yield_until_ms




	return false


func _world_browser_realm_registry() -> Dictionary:
	if (
		gs == null
		or gs.realm_engine == null
	):
		return {}

	var registry_raw: Variant = (
		gs.realm_engine.get(
			"realms"
		)
	)

	return (
		(
			registry_raw as Dictionary
		).duplicate(false)
		if typeof(
			registry_raw
		) == TYPE_DICTIONARY
		else {}
	)


func _world_browser_hidden_registry() -> Dictionary:
	if (
		gs == null
		or gs.many_realms_engine == null
		or not _world_browser_many_realms_allowed()
	):
		return {}

	if gs.many_realms_engine.has_method(
		"emit_world_browser_hidden_surface_registry"
	):
		var contract_raw: Variant = (
			gs.many_realms_engine
			.emit_world_browser_hidden_surface_registry({
				"source": "world_observability_contract_engine",
				"era_key": _world_browser_current_era_key(),
				"include_era_kingdom_preview": true,
				"ready_gate_member": false
			})
		)

		if typeof(contract_raw) == TYPE_DICTIONARY:
			return (
				contract_raw as Dictionary
			).duplicate(false)

	var registry_raw: Variant = (
		gs.many_realms_engine.get(
			"hidden_realms"
		)
	)

	return (
		(registry_raw as Dictionary).duplicate(false)
		if typeof(registry_raw) == TYPE_DICTIONARY
		else {}
	)


func _world_browser_country_names(
	actor: Person
) -> Array:
	var era_key: String = (
		_world_browser_current_era_key()
	)
	var names: Array = []

	if (
		gs != null
		and gs.era_engine != null
		and gs.era_engine.has_method(
			"get_countries_for_era"
		)
	):
		var countries_raw: Variant = (
			gs.era_engine.get_countries_for_era(
				era_key
			)
		)

		if typeof(
			countries_raw
		) == TYPE_ARRAY:
			names = (
				countries_raw as Array
			).duplicate(false)

	if names.is_empty():
		names = _world_browser_fallback_countries(
			era_key
		)

	var actor_country: String = (
		_world_browser_actor_country(
			actor
		)
	)

	if actor_country != "":
		var actor_country_key: String = (
			_world_browser_identity_key(
				actor_country
			)
		)
		var actor_country_present: bool = false

		for raw_name in names:
			if (
				_world_browser_identity_key(
					str(
						raw_name
					)
				)
				== actor_country_key
			):
				actor_country_present = true
				break

		if not actor_country_present:
			names.push_front(
				actor_country
			)

	var out: Array = []
	var seen: Dictionary = {}

	for raw_name in names:
		var country_name: String = str(
			raw_name
		).strip_edges()
		var identity_key: String = (
			_world_browser_identity_key(
				country_name
			)
		)

		if (
			country_name == ""
			or identity_key == ""
			or seen.has(
				identity_key
			)
		):
			continue

		seen [
			identity_key
		] = true
		out.append(
			country_name
		)

	return out


func _world_browser_country_entry(
	country_name: String,
	index: int,
	work: Dictionary
) -> Dictionary:
	var clean_name: String = str(
		country_name
	).strip_edges()

	if clean_name == "":
		return {}

	var country_key: String = (
		_world_browser_identity_key(
			clean_name
		)
	)
	var realm_name_index: Dictionary = (
		work.get(
			"realm_name_index",
			{}
		) as Dictionary
	)
	var realm_registry: Dictionary = (
		work.get(
			"realm_registry",
			{}
		) as Dictionary
	)

	if realm_name_index.has(
		country_key
	):
		var raw_realm_key: Variant = (
			realm_name_index.get(
				country_key
			)
		)
		var realm_raw: Variant = (
			realm_registry.get(
				raw_realm_key,
				{}
			)
		)

		if typeof(
			realm_raw
		) == TYPE_DICTIONARY:
			var existing_entry: Dictionary = (
				_world_browser_realm_entry(
					realm_raw as Dictionary,
					raw_realm_key,
					"era_engine.country_registry"
				)
			)

			existing_entry [
				"entry_kind"
			] = "country"
			existing_entry [
				"_sort_priority"
			] = 40 + index

			return existing_entry

	var ensured_realm_id: int = -1

	if (
		gs != null
		and gs.realm_engine != null
		and gs.realm_engine.has_method(
			"ensure_realm_for_country"
		)
	):
		ensured_realm_id = int(
			gs.realm_engine.ensure_realm_for_country(
				clean_name
			)
		)

	if (
		ensured_realm_id > 0
		and gs != null
		and gs.realm_engine != null
		and "realms" in gs.realm_engine
		and typeof(
			gs.realm_engine.realms
		) == TYPE_DICTIONARY
	):
		var ensured_raw: Variant = (
			gs.realm_engine.realms.get(
				ensured_realm_id,
				{}
			)
		)

		if typeof(
			ensured_raw
		) == TYPE_DICTIONARY:
			var ensured_entry: Dictionary = (
				_world_browser_realm_entry(
					ensured_raw as Dictionary,
					ensured_realm_id,
					"realm_engine.era_country_residency"
				)
			)

			ensured_entry [
				"entry_kind"
			] = "country"
			ensured_entry [
				"_sort_priority"
			] = 40 + index
			ensured_entry [
				"stable_population_identity_published"
			] = true
			ensured_entry [
				"country_realm_materialized_by_contract_producer"
			] = true
			ensured_entry [
				"click_path_materialization_forbidden"
			] = true

			return ensured_entry

	return {
		"entry_id": "country:%s" % country_key,
		"entry_kind": "country",
		"name": clean_name,
		"label": clean_name,
		"subtitle": "Living country surface",
		"description": (
			"A country surface whose canonical Realm identity "
			+ "has not entered residency yet."
		),
		"realm_id": -1,
		"realm": {
			"id": -1,
			"realm_id": -1,
			"name": clean_name,
			"country": clean_name,
			"era": _world_browser_current_era_key(),
			"realm_type": "country",
			"is_country_surface": true,
			"realm_browser_section": "standard_realms",
			"surface_exists": true,
			"population_surface_must_already_exist": false,
			"click_path_build_forbidden": true,
			"ui_is_renderer_only": true
		},
		"browser_section": "standard_realms",
		"source": (
			"world_observability_contract_engine.era_country"
		),
		"_sort_priority": 40 + index,
		"surface_exists": true,
		"truth_state": "observable_partial",
		"population_surface_must_already_exist": false,
		"stable_population_identity_published": false,
		"click_path_build_forbidden": true,
		"click_path_materialization_forbidden": true,
		"ui_is_renderer_only": true
	}

func _world_browser_realm_entry(
	realm_source: Dictionary,
	raw_realm_key: Variant,
	source: String
) -> Dictionary:
	var realm: Dictionary = realm_source.duplicate(false)
	var raw_key_text: String = str(raw_realm_key).strip_edges()
	var explicit_id_text: String = str(
		realm.get(
			"entry_id",
			realm.get(
				"id",
				raw_key_text
			)
		)
	).strip_edges()
	var realm_id: int = -1
	var realm_id_raw: Variant = realm.get(
		"realm_id",
		-1
	)

	if typeof(realm_id_raw) in [TYPE_INT, TYPE_FLOAT]:
		realm_id = int(realm_id_raw)
	elif explicit_id_text.is_valid_int():
		realm_id = int(explicit_id_text)

	var name: String = str(
		realm.get(
			"name",
			realm.get(
				"country",
				"Realm"
			)
		)
	).strip_edges()
	var native_element: String = (
		_world_browser_native_element(
			{
				"entry_id": explicit_id_text,
				"name": name
			},
			realm
		)
	)
	var browser_section: String = (
		_world_browser_section_for_entry(
			{
				"entry_id": (
					explicit_id_text
					if explicit_id_text != ""
					else raw_key_text
				),
				"name": name
			},
			realm
		)
	)

	if native_element != "":
		realm ["native_element"] = native_element
		realm ["elemental_realm"] = true

	realm ["realm_browser_section"] = browser_section
	realm ["surface_exists"] = true
	realm ["click_path_build_forbidden"] = true
	realm ["ui_is_renderer_only"] = true

	var entry_kind: String = "realm"

	match browser_section:
		"interrealm_authority":
			entry_kind = "interrealm_authority"
		"space_realms":
			entry_kind = "space_realm"
		"imaginative_realms":
			entry_kind = "imaginative_realm"
		"elemental_realms":
			entry_kind = "elemental_realm"

	var output_entry_id: String = explicit_id_text

	if output_entry_id == "":
		output_entry_id = raw_key_text

	if realm_id > 0:
		output_entry_id = "realm:%d" % realm_id
	elif output_entry_id == "":
		output_entry_id = "realm:%s" % (
			_world_browser_identity_key(name)
		)

	return {
		"entry_id": output_entry_id,
		"entry_kind": entry_kind,
		"name": name,
		"label": name,
		"subtitle": str(
			realm.get(
				"subtitle",
				"Resident realm surface"
			)
		),
		"description": str(
			realm.get(
				"description",
				"A contract-safe realm projection."
			)
		),
		"realm_id": realm_id,
		"realm": realm,
		"native_element": native_element,
		"browser_section": browser_section,
		"source": source,
		"_sort_priority": int(
			realm.get(
				"browser_sort_priority",
				10
			)
		),
		"surface_exists": true,
		"truth_state": str(
			realm.get(
				"truth_state",
				"hot"
			)
		),
		"population_surface_must_already_exist": true,
		"click_path_build_forbidden": true,
		"ui_is_renderer_only": true
	}


func _world_browser_provider_entry(
	provider_id: String
) -> Dictionary:
	if (
		gs == null
		or provider_id == ""
	):
		return {}

	var provider = gs.get(
		provider_id
	)

	if (
		provider == null
		or not provider.has_method(
			"get_surface_entry_for_player"
		)
	):
		return {}

	var entry_raw: Variant = (
		provider.get_surface_entry_for_player()
	)

	if typeof(
		entry_raw
	) != TYPE_DICTIONARY:
		return {}

	var forced_section: String = ""

	match provider_id:
		"bridge_to_terabithia_engine":
			forced_section = "imaginative_realms"

		"vormir_engine", \
"nidavellir_engine":
			forced_section = "space_realms"

	return _world_browser_normalize_entry(
		entry_raw as Dictionary,
		"%s.resident_surface" % provider_id,
		forced_section
	)


func _world_browser_external_entries() -> Array:
	if (
		gs == null
		or gs.realm_contract_engine == null
		or not gs.realm_contract_engine.has_method(
			"get_external_surface_entries"
		)
	):
		return []

	var entries_raw: Variant = (
		gs.realm_contract_engine
		.get_external_surface_entries()
	)

	return (
		(
			entries_raw as Array
		).duplicate(false)
		if typeof(
			entries_raw
		) == TYPE_ARRAY
		else []
	)


func _world_browser_normalize_entry(
	source_entry: Dictionary,
	source: String,
	forced_section: String = ""
) -> Dictionary:
	if source_entry.is_empty():
		return {}

	var entry: Dictionary = (
		source_entry.duplicate(false)
	)
	var realm_raw: Variant = entry.get(
		"realm",
		{}
	)
	var realm: Dictionary = (
		(
			realm_raw as Dictionary
		).duplicate(false)
		if typeof(
			realm_raw
		) == TYPE_DICTIONARY
		else {}
	)
	var name: String = str(
		entry.get(
			"name",
			entry.get(
				"label",
				realm.get(
					"name",
					realm.get(
						"country",
						"Realm"
					)
				)
			)
		)
	).strip_edges()

	if name == "":
		return {}

	if realm.is_empty():
		realm = {
			"name": name
		}

	var native_element: String = (
		_world_browser_native_element(
			entry,
			realm
		)
	)
	var browser_section: String = str(
		forced_section
	).strip_edges().to_lower()

	if browser_section == "":
		browser_section = (
			_world_browser_section_for_entry(
				entry,
				realm
			)
		)

	if native_element != "":
		realm [
			"native_element"
		] = native_element
		realm [
			"elemental_realm"
		] = true

	realm [
		"realm_browser_section"
	] = browser_section
	realm [
		"surface_exists"
	] = true
	realm [
		"click_path_build_forbidden"
	] = true
	realm [
		"ui_is_renderer_only"
	] = true

	entry ["name"] = name
	entry ["label"] = str(
		entry.get(
			"label",
			name
		)
	)
	entry ["entry_id"] = str(
		entry.get(
			"entry_id",
			"%s:%s"
			% [
				_world_browser_identity_key(
					source
				),
				_world_browser_identity_key(
					name
				)
			]
		)
	)
	entry ["entry_kind"] = str(
		entry.get(
			"entry_kind",
			"realm"
		)
	)
	entry ["realm_id"] = int(
		entry.get(
			"realm_id",
			realm.get(
				"realm_id",
				realm.get(
					"id",
					-1
				)
			)
		)
	)
	entry ["realm"] = realm
	entry ["native_element"] = native_element
	entry ["browser_section"] = browser_section
	entry ["source"] = source
	entry ["_sort_priority"] = int(
		entry.get(
			"_sort_priority",
			realm.get(
				"browser_sort_priority",
				20
			)
		)
	)
	entry ["surface_exists"] = true
	entry ["truth_state"] = "hot"
	entry [
		"population_surface_must_already_exist"
	] = true
	entry [
		"click_path_build_forbidden"
	] = true
	entry ["ui_is_renderer_only"] = true

	return entry


func _world_browser_entry_allowed(
	entry: Dictionary
) -> bool:
	if entry.is_empty():
		return false

	var browser_section: String = str(
		entry.get(
			"browser_section",
			"standard_realms"
		)
	).strip_edges().to_lower()

	if (
		browser_section == "elemental_realms"
		and not _world_browser_elemental_allowed()
	):
		return false

	if (
		browser_section in [
			"interrealm_authority",
			"space_realms",
			"imaginative_realms"
		]
		and not _world_browser_many_realms_allowed()
	):
		return false

	return true


func _world_browser_append_unique(
	work: Dictionary,
	entry: Dictionary
) -> void:
	if entry.is_empty():
		return

	var seen: Dictionary = (
		work.get(
			"seen",
			{}
		) as Dictionary
	)
	var entries: Array = (
		work.get(
			"entries",
			[]
		) as Array
	)
	var realm_id: int = int(
		entry.get(
			"realm_id",
			-1
		)
	)
	var identity_key: String = ""

	if realm_id > 0:
		identity_key = (
			"realm_id:%d"
			% realm_id
		)
	else:
		identity_key = (
			"name:%s"
			% _world_browser_identity_key(
				str(
					entry.get(
						"name",
						entry.get(
							"entry_id",
							""
						)
					)
				)
			)
		)

	if (
		identity_key == ""
		or seen.has(
			identity_key
		)
	):
		return

	seen [
		identity_key
	] = true
	entries.append(
		entry
	)

	work [
		"seen"
	] = seen
	work [
		"entries"
	] = entries

	var signature: String = str(
		work.get(
			"signature",
			""
		)
	)

	if signature != "":
		world_browser_contract_ready.emit(
			signature,
			{
				"success": true,
				"schema": (
					"eralife.world_browser_projection_contract"
				),
				"version": CONTRACT_VERSION,
				"signature": signature,
				"actor_id": int(
					work.get(
						"actor_id",
						-1
					)
				),
				"published_entry": (
					entry.duplicate(false)
				),
				"entry_count": entries.size(),
				"truth_state": "observable_partial",
				"projection_complete": false,
				"authoritative_projection": true,
				"immutable_surface_contract": true,
				"build_on_click_forbidden": true,
				"ready_gate_member": false,
				"created_at_ms": int(
					Time.get_ticks_msec()
				),
				"ui_is_renderer_only": true
			}
		)

func _finalize_world_browser_projection(
	signature: String
) -> void:
	var work_raw: Variant = world_browser_work_by_signature.get(
		signature,
		{}
	)
	var work: Dictionary = (
		work_raw as Dictionary
		if typeof(work_raw) == TYPE_DICTIONARY
		else {}
	)

	if work.is_empty():
		return

	var entries: Array = work.get(
		"entries",
		[]
	) as Array
	var section_priority: Dictionary = {
		"interrealm_authority": 0,
		"space_realms": 10,
		"imaginative_realms": 20,
		"elemental_realms": 30,
		"standard_realms": 40
	}

	entries.sort_custom(
		func (a, b) -> bool:
			var entry_a: Dictionary = a as Dictionary
			var entry_b: Dictionary = b as Dictionary
			var section_a: String = str(
				entry_a.get(
					"browser_section",
					"standard_realms"
				)
			)
			var section_b: String = str(
				entry_b.get(
					"browser_section",
					"standard_realms"
				)
			)
			var section_priority_a: int = int(
				section_priority.get(
					section_a,
					99
				)
			)
			var section_priority_b: int = int(
				section_priority.get(
					section_b,
					99
				)
			)

			if section_priority_a != section_priority_b:
				return section_priority_a < section_priority_b

			var priority_a: int = int(
				entry_a.get(
					"_sort_priority",
					99
				)
			)
			var priority_b: int = int(
				entry_b.get(
					"_sort_priority",
					99
				)
			)

			if priority_a != priority_b:
				return priority_a < priority_b

			return str(
				entry_a.get(
					"name",
					""
				)
			) < str(
				entry_b.get(
					"name",
					""
				)
			)
	)

	var section_entries: Dictionary = {
		"interrealm_authority": [],
		"space_realms": [],
		"imaginative_realms": [],
		"elemental_realms": [],
		"standard_realms": []
	}

	for raw_entry in entries:
		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue

		var entry: Dictionary = raw_entry as Dictionary
		var section_id: String = str(
			entry.get(
				"browser_section",
				"standard_realms"
			)
		).strip_edges().to_lower()

		if not section_entries.has(section_id):
			section_entries [section_id] = []

		var section_rows: Array = section_entries.get(
			section_id,
			[]
		) as Array
		section_rows.append(entry)
		section_entries [section_id] = section_rows

	var now_ms: int = int(Time.get_ticks_msec())
	var contract: Dictionary = {
		"success": true,
		"schema": "eralife.world_browser_projection_contract",
		"version": CONTRACT_VERSION,
		"signature": signature,
		"actor_id": int(
			work.get(
				"actor_id",
				-1
			)
		),
		"year": int(gs.year) if gs != null else -1,
		"era_key": _world_browser_current_era_key(),
		"entries": entries.duplicate(false),
		"section_entries": section_entries,
		"section_order": [
			"interrealm_authority",
			"space_realms",
			"imaginative_realms",
			"elemental_realms",
			"standard_realms"
		],
		"entry_count": entries.size(),
		"truth_state": "hot",
		"projection_complete": true,
		"authoritative_projection": true,
		"immutable_surface_contract": true,
		"build_on_click_forbidden": true,
		"ready_gate_member": false,
		"created_at_ms": now_ms,
		"ui_is_renderer_only": true
	}

	world_browser_contract_by_signature [
		signature
	] = contract.duplicate(false)

	work ["complete"] = true
	work ["phase"] = "complete"
	work ["completed_at_ms"] = now_ms

	world_browser_work_by_signature.erase(signature)
	world_browser_step_armed_by_signature.erase(signature)
	last_report = contract.duplicate(false)

	if gs != null:
		if typeof(gs.scenario_state) != TYPE_DICTIONARY:
			gs.scenario_state = {}

		var contracts_raw: Variant = gs.get_meta(
			"world_browser_projection_contracts_by_signature",
			{}
		)
		var contracts_by_signature: Dictionary = (
			(contracts_raw as Dictionary).duplicate(false)
			if typeof(contracts_raw) == TYPE_DICTIONARY
			else {}
		)
		contracts_by_signature [signature] = contract.duplicate(false)

		gs.set_meta(
			"world_browser_projection_contract_mailbox",
			contract.duplicate(false)
		)
		gs.set_meta(
			"world_browser_projection_contracts_by_signature",
			contracts_by_signature
		)
		gs.set_meta(
			"world_browser_projection_mailbox_revision",
			now_ms
		)
		gs.set_meta(
			"world_browser_projection_mailbox_is_crr_packet",
			true
		)
		gs.set_meta(
			"world_browser_projection_mailbox_renderer_calls_engine",
			false
		)

		gs.scenario_state [
			"world_browser_projection_pending"
		] = false
		gs.scenario_state [
			"world_browser_projection_complete"
		] = true
		gs.scenario_state [
			"world_browser_projection_signature"
		] = signature
		gs.scenario_state [
			"world_browser_projection_entry_count"
		] = entries.size()
		gs.scenario_state [
			"world_browser_projection_completed_at_ms"
		] = now_ms
		gs.scenario_state [
			"world_browser_projection_ready_gate_member"
		] = false
		gs.scenario_state [
			"world_browser_projection_ui_called_engines"
		] = false
		gs.scenario_state [
			"world_browser_projection_contract_stored_in_save_state"
		] = false

	world_browser_contract_ready.emit(
		signature,
		contract.duplicate(false)
	)

func _world_browser_current_era_key() -> String:
	if gs == null:
		return "modern"

	if typeof(
		gs.scenario_state
	) == TYPE_DICTIONARY:
		for state_key in [
			"effective_era_name",
			"selected_era",
			"era_name"
		]:
			var state_value: String = str(
				gs.scenario_state.get(
					state_key,
					""
				)
			).strip_edges()

			if state_value != "":
				return state_value

	if gs.era != null:
		var era_name_raw: Variant = (
			gs.era.get(
				"name"
			)
			if gs.era.has_method(
				"get"
			)
			else null
		)
		var era_name: String = str(
			era_name_raw
		).strip_edges()

		if era_name != "":
			return era_name

	if typeof(
		gs.custom_settings
	) == TYPE_DICTIONARY:
		var configured_era: String = str(
			gs.custom_settings.get(
				"era",
				""
			)
		).strip_edges()

		if configured_era != "":
			return configured_era

	return "modern"


func _world_browser_actor_country(
	actor: Person
) -> String:
	if actor == null:
		return ""

	for property_name in [
		"home_country",
		"birth_country",
		"country"
	]:
		var value: String = str(
			actor.get(
				property_name
			)
		).strip_edges()

		if value != "":
			return value

	return ""


func _world_browser_fallback_countries(
	era_key: String
) -> Array:
	var clean_era: String = str(
		era_key
	).strip_edges().to_lower()

	if clean_era.find(
		"ancient"
	) >= 0:
		return [
			"Roman Empire",
			"Egypt",
			"Greece",
			"Persia",
			"Carthage",
			"Han China",
			"India",
			"Gaul",
			"Britannia",
			"Germania",
			"Judea",
			"Numidia"
		]

	if clean_era.find(
		"medieval"
	) >= 0:
		return [
			"England",
			"France",
			"Holy Roman Empire",
			"Byzantine Empire",
			"Spain",
			"Portugal",
			"Venice",
			"Japan",
			"China",
			"Mali Empire",
			"Egypt",
			"Mongol Empire"
		]

	if clean_era.find(
		"industrial"
	) >= 0:
		return [
			"United Kingdom",
			"France",
			"Germany",
			"Italy",
			"Russia",
			"United States",
			"Japan",
			"China",
			"India",
			"Brazil",
			"Mexico",
			"Egypt"
		]

	if clean_era.find(
		"future"
	) >= 0:
		return [
			"United States",
			"Neo Canada",
			"European Union",
			"Pan-African Union",
			"Brazilian Federation",
			"Solar Japan",
			"New Korea",
			"Orbital China",
			"Austral Union",
			"Frontier Realm"
		]

	return [
		"United States",
		"Canada",
		"Mexico",
		"Brazil",
		"United Kingdom",
		"France",
		"Germany",
		"Italy",
		"Spain",
		"Nigeria",
		"Egypt",
		"South Africa",
		"India",
		"China",
		"Japan",
		"South Korea",
		"Australia",
		"New Zealand"
	]


func _world_browser_native_element(
	entry: Dictionary,
	realm: Dictionary
) -> String:
	var native_element: String = str(
		entry.get(
			"native_element",
			realm.get(
				"native_element",
				""
			)
		)
	).strip_edges().to_lower()

	if native_element in [
		"air",
		"water",
		"earth",
		"fire"
	]:
		return native_element

	for theme_key in [
		"browser_visual_theme",
		"overview_visual_theme"
	]:
		var theme: String = str(
			realm.get(
				theme_key,
				""
			)
		).strip_edges().to_lower()

		if theme.begins_with(
			"elemental_"
		):
			var theme_element: String = (
				theme.trim_prefix(
					"elemental_"
				)
			)

			if theme_element in [
				"air",
				"water",
				"earth",
				"fire"
			]:
				return theme_element

	var lower_name: String = str(
		entry.get(
			"name",
			realm.get(
				"name",
				""
			)
		)
	).strip_edges().to_lower()

	if lower_name.find(
		"earth kingdom"
	) >= 0:
		return "earth"

	if lower_name.find(
		"fire nation"
	) >= 0:
		return "fire"

	if lower_name.find(
		"water tribe"
	) >= 0:
		return "water"

	if (
		lower_name.find(
			"air temple"
		) >= 0
		or lower_name.find(
			"air nomads"
		) >= 0
	):
		return "air"

	return ""


func _world_browser_section_for_entry(
	entry: Dictionary,
	realm: Dictionary
) -> String:
	var explicit_section: String = str(
		entry.get(
			"browser_section",
			realm.get(
				"realm_browser_section",
				""
			)
		)
	).strip_edges().to_lower()
	var entry_id: String = str(
		entry.get(
			"entry_id",
			""
		)
	).strip_edges().to_lower()
	var entry_kind: String = str(
		entry.get(
			"entry_kind",
			""
		)
	).strip_edges().to_lower()
	var realm_type: String = str(
		realm.get(
			"realm_type",
			realm.get(
				"dimension_type",
				""
			)
		)
	).strip_edges().to_lower()
	var browser_theme: String = str(
		realm.get(
			"browser_visual_theme",
			""
		)
	).strip_edges().to_lower()
	var overview_theme: String = str(
		realm.get(
			"overview_visual_theme",
			""
		)
	).strip_edges().to_lower()
	var native_element: String = (
		_world_browser_native_element(
			entry,
			realm
		)
	)

	if (
		entry_id.find(
			"era_kingdom"
		) >= 0
		or explicit_section == "interrealm_authority"
	):
		return "interrealm_authority"

	if (
		explicit_section == "space_realms"
		or entry_kind == "space_realm"
		or browser_theme in [
			"vormir",
			"nidavellir"
		]
		or overview_theme in [
			"vormir",
			"nidavellir"
		]
	):
		return "space_realms"

	if (
		explicit_section == "imaginative_realms"
		or entry_kind == "imaginative_realm"
		or realm_type == "imagination_bound"
		or browser_theme == "terabithia"
		or overview_theme == "terabithia"
	):
		return "imaginative_realms"

	if (
		explicit_section == "elemental_realms"
		or bool(
			realm.get(
				"elemental_realm",
				false
			)
		)
		or native_element != ""
	):
		return "elemental_realms"

	if explicit_section not in [
		"",
		"ordinary",
		"ordinary_realms",
		"country",
		"countries",
		"standard_realms"
	]:
		return explicit_section

	return "standard_realms"


func _world_browser_reality_mode() -> String:
	if gs == null:
		return "chaos"

	var mode: String = str(
		gs.reality_mode
	).strip_edges().to_lower()

	if typeof(
		gs.custom_settings
	) == TYPE_DICTIONARY:
		mode = str(
			gs.custom_settings.get(
				"reality_mode",
				mode
			)
		).strip_edges().to_lower()

	if mode == "":
		mode = "chaos"

	return mode


func _world_browser_elemental_allowed() -> bool:
	if _world_browser_reality_mode() == "realistic":
		return false

	if (
		gs != null
		and gs.has_method(
			"is_feature_enabled"
		)
	):
		return bool(
			gs.is_feature_enabled(
				"bending"
			)
		)

	return true


func _world_browser_many_realms_allowed() -> bool:
	if _world_browser_reality_mode() == "realistic":
		return false

	if (
		gs != null
		and gs.has_method(
			"is_feature_enabled"
		)
	):
		return bool(
			gs.is_feature_enabled(
				"many_realms"
			)
		)

	return true


func _world_browser_identity_key(
	value: String
) -> String:
	var clean: String = str(
		value
	).strip_edges().to_lower()

	for character in [
		" ",
		"_",
		"-",
		"•",
		".",
		",",
		"'",
		"\"",
		":",
		";",
		"/",
		"\\",
		"(",
		")"
	]:
		clean = clean.replace(
			character,
			""
		)

	return clean


func _world_browser_signature(
	actor: Person
) -> String:
	return (
		"%d:%d:%s:%s:world_browser_v9"
		% [
			int(
				actor.id
			),
			(
				int(
					gs.year
				)
				if gs != null
				else -1
			),
			_world_browser_current_era_key(),
			_world_browser_reality_mode()
		]
	)
func ensure_observable_surfaces_for_realms(realm_ids: Array = [], context: Dictionary = {}) -> Dictionary:
	if gs == null:
		return {
			"success": false,
			"reason": "missing_game_state",
			"schema": ENGINE_SCHEMA
		}

	var observable_engine: ObservableNodeContractEngine = _ensure_observable_node_contract_engine()
	if observable_engine == null:
		return {
			"success": false,
			"reason": "missing_observable_node_contract_engine",
			"schema": ENGINE_SCHEMA
		}

	var ids: Array = realm_ids.duplicate(true)
	if ids.is_empty():
		ids = _essential_realm_ids()

	var ensured: Array = []
	var failed: Array = []

	for raw_realm_id in ids:
		var realm_id: int = int(raw_realm_id)
		if realm_id <= 0:
			continue

		var realm_name: String = _realm_name_for_id(realm_id)
		var population_packet: Dictionary = _population_observable_surface_packet(realm_id, realm_name, context)

		var result: Dictionary = observable_engine.ensure_surface_scope(
			"realm:%d:population" % realm_id,
			population_packet,
			{
				"source": ENGINE_SCHEMA,
				"realm_id": realm_id,
				"realm_name": realm_name,
				"truth_state": "partial",
				"hydration_optional": true,
				"ui_is_renderer_only": true
			}
		)

		if bool(result.get("success", false)):
			ensured.append(realm_id)
		else:
			failed.append({
				"realm_id": realm_id,
				"realm_name": realm_name,
				"reason": str(result.get("reason", "surface_scope_failed"))
			})

	last_report = {
		"success": failed.is_empty(),
		"schema": ENGINE_SCHEMA,
		"version": CONTRACT_VERSION,
		"reason": "observable_surface_shells_exist" if failed.is_empty() else "observable_surface_shell_failures",
		"ensured": ensured.duplicate(true),
		"failed": failed.duplicate(true),
		"truth_state": "partial",
		"hydration_optional": true,
		"ui_is_renderer_only": true,
		"at_ms": int(Time.get_ticks_msec())
	}

	_commit_report()

	if bool(context.get("queue_truth_resolution_tail", true)):
		_request_truth_resolution_for_realms_deferred(
			ids,
			{
				"source": "%s_truth_resolution_tail" % str(context.get("source", ENGINE_SCHEMA)),
				"surface_already_exists": true,
				"truth_may_complete_after_observation": true,
				"skip_runtime_materialization": true,
				"ontology_only_ready_gate": true,
				"ui_is_renderer_only": true
			}.merged(context, true)
		)

	return last_report.duplicate(true)
func ensure_realm_observable_surface(realm_id: int, realm_name: String = "", context: Dictionary = {}) -> Dictionary:
	if realm_id <= 0:
		return {
			"success": false,
			"reason": "invalid_realm_id",
			"schema": ENGINE_SCHEMA
		}

	var resolved_name: String = str(realm_name).strip_edges()
	if resolved_name == "":
		resolved_name = _realm_name_for_id(realm_id)

	return ensure_observable_surfaces_for_realms(
		[realm_id],
		{
			"source": "ensure_realm_observable_surface",
			"realm_id": realm_id,
			"realm_name": resolved_name,
			"ui_is_renderer_only": true
		}.merged(context, true)
	)


func verify_observable_surfaces_for_realms(realm_ids: Array = [], _context: Dictionary = {}) -> Dictionary:
	var ids: Array = realm_ids.duplicate(true)
	if ids.is_empty():
		ids = _essential_realm_ids()

	var observable_engine: ObservableNodeContractEngine = _ensure_observable_node_contract_engine()
	if observable_engine == null:
		return {
			"success": false,
			"reason": "missing_observable_node_contract_engine",
			"schema": ENGINE_SCHEMA
		}

	var verified: Array = []
	var failed: Array = []

	for raw_realm_id in ids:
		var realm_id: int = int(raw_realm_id)
		if realm_id <= 0:
			continue

		if observable_engine.has_surface_scope("realm:%d:population" % realm_id):
			verified.append(realm_id)
		else:
			failed.append({
				"realm_id": realm_id,
				"reason": "missing_population_observable_surface"
			})

	var success: bool = failed.is_empty()

	return {
		"success": success,
		"schema": ENGINE_SCHEMA,
		"reason": "observable_surfaces_verified" if success else "observable_surface_verification_failed",
		"verified": verified.duplicate(true),
		"failed": failed.duplicate(true),
		"ui_is_renderer_only": true,
		"at_ms": int(Time.get_ticks_msec())
	}


func _ensure_truth_resolution_for_realms(realm_ids: Array, context: Dictionary = {}) -> Dictionary:
	if gs == null:
		return {
			"success": false,
			"reason": "missing_game_state",
			"schema": ENGINE_SCHEMA
		}

	if not "truth_resolution_contract_engine" in gs or gs.truth_resolution_contract_engine == null:
		gs.truth_resolution_contract_engine = TruthResolutionContractEngine.new(gs)

	if gs.truth_resolution_contract_engine == null:
		return {
			"success": false,
			"reason": "missing_truth_resolution_contract_engine",
			"schema": ENGINE_SCHEMA
		}

	if not gs.truth_resolution_contract_engine.has_method("resolve_population_and_government_truth_for_realms"):
		return {
			"success": false,
			"reason": "truth_resolution_engine_missing_resolve_method",
			"schema": ENGINE_SCHEMA
		}

	return gs.truth_resolution_contract_engine.resolve_population_and_government_truth_for_realms(
		realm_ids,
		context
	)

func _request_truth_resolution_for_realms_deferred(realm_ids: Array, context: Dictionary = {}) -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var request_key: String = "truth_resolution_tail_requested:%s" % str(realm_ids)
	if bool(gs.scenario_state.get(request_key, false)):
		return

	gs.scenario_state [request_key] = true
	gs.scenario_state ["truth_resolution_tail_last_request"] = {
		"realm_ids": realm_ids.duplicate(true),
		"context": context.duplicate(true),
		"at_ms": int(Time.get_ticks_msec()),
		"ui_is_renderer_only": true
	}

	call_deferred("_run_truth_resolution_for_realms_deferred", realm_ids.duplicate(true), context.duplicate(true))


func _run_truth_resolution_for_realms_deferred(realm_ids: Array, context: Dictionary = {}) -> void:
	if gs == null:
		return

	if gs.population_shard_engine != null and gs.population_shard_engine.has_method("enqueue_truth_resolution_shards_for_realm"):
		var queued: Array = []

		for raw_realm_id in realm_ids:
			var realm_id: int = int(raw_realm_id)
			if realm_id <= 0:
				continue

			var realm_name: String = _realm_name_for_id(realm_id)
			var shard_report: Dictionary = gs.population_shard_engine.enqueue_truth_resolution_shards_for_realm(
				realm_id,
				realm_name,
				{
					"source": str(context.get("source", "world_observability_truth_tail")),
					"surface_already_exists": true,
					"truth_may_complete_after_observation": true,
					"ready_door_may_not_wait": true,
					"ui_is_renderer_only": true
				}.merged(context, true)
			)

			queued.append(shard_report.duplicate(true))

		if typeof(gs.scenario_state) == TYPE_DICTIONARY:
			gs.scenario_state ["truth_resolution_tail_last_report"] = {
				"success": true,
				"schema": ENGINE_SCHEMA,
				"reason": "truth_resolution_shards_queued",
				"queued": queued.duplicate(true),
				"ready_door_may_not_wait": true,
				"ui_is_renderer_only": true,
				"at_ms": int(Time.get_ticks_msec())
			}
			gs.scenario_state ["truth_resolution_tail_last_report_at_ms"] = int(Time.get_ticks_msec())

		return

	if not "truth_resolution_contract_engine" in gs or gs.truth_resolution_contract_engine == null:
		gs.truth_resolution_contract_engine = TruthResolutionContractEngine.new(gs)

	if gs.truth_resolution_contract_engine == null:
		return

	if not gs.truth_resolution_contract_engine.has_method("resolve_population_and_government_truth_for_realms"):
		return

	var report: Dictionary = gs.truth_resolution_contract_engine.resolve_population_and_government_truth_for_realms(
		realm_ids,
		{
			"source": str(context.get("source", "world_observability_truth_tail")),
			"surface_already_exists": true,
			"truth_may_complete_after_observation": true,
			"skip_runtime_materialization": true,
			"ontology_only_ready_gate": true,
			"ready_door_may_not_wait": true,
			"ui_is_renderer_only": true
		}.merged(context, true)
	)

	if typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["truth_resolution_tail_last_report"] = report.duplicate(true)
		gs.scenario_state ["truth_resolution_tail_last_report_at_ms"] = int(Time.get_ticks_msec())
func has_observable_population_surface(realm_id: int) -> bool:
	if realm_id <= 0:
		return false

	var observable_engine: ObservableNodeContractEngine = _ensure_observable_node_contract_engine()
	if observable_engine == null:
		return false

	return observable_engine.has_surface_scope("realm:%d:population" % realm_id)


func _population_observable_surface_packet(realm_id: int, realm_name: String, _context: Dictionary = {}) -> Dictionary:
	return {
		"schema": "eralife.observable_population_surface_contract",
		"version": CONTRACT_VERSION,
		"realm_id": realm_id,
		"realm_name": realm_name,
		"surface_kind": "population",
		"surface_exists": true,
		"truth_state": "partial",
		"hydrated": false,
		"hydration_optional": true,
		"categories_exist": [
			"executive",
			"cabinet",
			"senate",
			"supreme_court",
			"governors",
			"upper_class",
			"middle_class",
			"lower_class",
			"poor",
			"children",
			"retired",
			"prison",
			"military",
			"police",
			"businesses"
		],
		"node_ids": [],
		"ui_is_renderer_only": true,
		"engine_creates_no_controls": true,
	}
func _essential_realm_ids() -> Array:
	var out: Array = []
	var seen: Dictionary = {}

	if gs != null and gs.player != null:
		var player_realm_id: int = int(gs.player.realm_id)
		if player_realm_id > 0:
			out.append(player_realm_id)
			seen [player_realm_id] = true

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		var us_realm_id: int = int(gs.scenario_state.get("presidential_parent_contract_us_realm_id", -1))
		if us_realm_id > 0 and not seen.has(us_realm_id):
			out.append(us_realm_id)
			seen [us_realm_id] = true

	return out


func _realm_name_for_id(realm_id: int) -> String:
	if gs != null and gs.realm_engine != null and "realms" in gs.realm_engine and typeof(gs.realm_engine.realms) == TYPE_DICTIONARY:
		var raw: Variant = gs.realm_engine.realms.get(realm_id, {})
		if typeof(raw) == TYPE_DICTIONARY:
			var realm: Dictionary = raw
			var name: String = str(realm.get("name", realm.get("country", ""))).strip_edges()
			if name != "":
				return name

	return "Realm %d" % realm_id


func _ensure_observable_node_contract_engine() -> ObservableNodeContractEngine:
	if gs == null:
		return null

	if gs.observable_node_contract_engine != null:
		return gs.observable_node_contract_engine as ObservableNodeContractEngine

	gs.observable_node_contract_engine = ObservableNodeContractEngine.new(gs)
	return gs.observable_node_contract_engine as ObservableNodeContractEngine

func _commit_report() -> void:
	if gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	gs.scenario_state ["world_observability_contract_engine_last_report"] = last_report.duplicate(true)
	gs.scenario_state ["world_observability_contract_engine_ready_may_not_wait_for_hydration"] = true