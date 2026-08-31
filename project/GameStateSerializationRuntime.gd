extends Resource
class_name GameStateSerializationRuntime

const SERIALIZATION_RUNTIME_VERSION:= 1
const SAVE_SCHEMA:= "eralife.save"
const SAVE_FORMAT_VERSION:= 1
const FRAME_SCHEMA:= "eralife.live_slice_frame"
const PHASE_CORE_IDENTITY:= "core_identity"
const PHASE_STRUCTURAL_SYSTEMS:= "structural_systems"
const PHASE_ENTITY_GRAPH:= "entity_graph"
const PHASE_SYSTEM_STATE:= "system_state"
const PHASE_DERIVED_SYSTEMS:= "derived_systems"
const PHASE_FINALIZATION:= "finalization"

const PHASE_ORDER:= [
	PHASE_CORE_IDENTITY,
	PHASE_STRUCTURAL_SYSTEMS,
	PHASE_ENTITY_GRAPH,
	PHASE_SYSTEM_STATE,
	PHASE_DERIVED_SYSTEMS,
	PHASE_FINALIZATION
]

var gs
var last_serialization_report: Dictionary = {}
var last_payload: Dictionary = {}


func _init(_gs = null):
	gs = _gs


func serialize_to_path(path: String = "user://savegame.bin", options: Dictionary = {}) -> Dictionary:
	var started_at: int = int(Time.get_ticks_msec())
	var normalized_path: String = str(path).strip_edges()
	if normalized_path == "":
		normalized_path = "user://savegame.bin"

	var payload_report: Dictionary = serialize_to_payload(options)
	if not bool(payload_report.get("success", false)):
		return payload_report

	var payload_raw: Variant = payload_report.get("payload", {})
	if typeof(payload_raw) != TYPE_DICTIONARY:
		return _fail_report("payload_missing", "Serialization produced no payload.", {
			"path": normalized_path,
			"started_at_ms": started_at
		})

	var payload: Dictionary = payload_raw
	var lower_path: String = normalized_path.to_lower()

	if lower_path.begins_with("user://saved_lives/"):
		var root:= DirAccess.open("user://")
		if root != null and not root.dir_exists("saved_lives"):
			root.make_dir("saved_lives")

	var write_binary: bool = true
	if gs != null and "binary_saves_enabled" in gs:
		write_binary = bool(gs.binary_saves_enabled)

	if lower_path.ends_with(".json"):
		write_binary = false
	elif lower_path.ends_with(".bin"):
		write_binary = true

	if write_binary:
		var bytes: PackedByteArray = BinarySaveEngine.encode(payload)
		var f_bin = FileAccess.open(normalized_path, FileAccess.WRITE)
		if f_bin == null:
			return _fail_report("write_failed", "Failed to write save file.", {
				"path": normalized_path
			})
		f_bin.store_buffer(bytes)
		f_bin.close()
	else:
		var f_json = FileAccess.open(normalized_path, FileAccess.WRITE)
		if f_json == null:
			return _fail_report("write_failed", "Failed to write save file.", {
				"path": normalized_path
			})
		f_json.store_string(JSON.stringify(payload, "\t"))
		f_json.close()

	var summary: Dictionary = _build_save_summary(normalized_path, payload)
	if not bool(options.get("skip_summary_cache", false)):
		_write_summary_cache(normalized_path, summary)

	var report: Dictionary = payload_report.duplicate(true)
	report.erase("payload")
	report ["path"] = normalized_path
	report ["format"] = "binary" if write_binary else "json"
	report ["wrote_file"] = true
	report ["summary"] = summary.duplicate(true)
	report ["finished_at_ms"] = int(Time.get_ticks_msec())
	report ["duration_ms"] = int(report ["finished_at_ms"]) - started_at
	report ["interactive_save"] = bool(options.get("interactive_save", false))
	report ["summary_cache_skipped"] = bool(options.get("skip_summary_cache", false))
	report ["cross_device_checkpoint_skipped"] = bool(options.get("skip_cross_device_checkpoint", false))

	_store_last_report(report)

	if not bool(options.get("skip_cross_device_checkpoint", false)):
		_build_cross_device_checkpoint(normalized_path, options)

	EraLog.truth("💾 GAME SAVED → ", normalized_path)
	return report.duplicate(true)


func serialize_to_payload(
		options: Dictionary = {}
) -> Dictionary:
	var started_at: int = int(
		Time.get_ticks_msec()
	)

	if gs == null:
		return _fail_report(
			"game_state_missing",
			"GameState unavailable for serialization.",
			{}
		)

	var interactive_checkpoint: bool = (
		bool(
			options.get(
				"fast_interactive_universe_save",
				false
			)
		)
		and bool(
			options.get(
				"checkpoint_save",
				false
			)
		)
	)

	if interactive_checkpoint:
		var checkpoint_payload: Dictionary = (
			_build_interactive_checkpoint_payload(
				options
			)
		)
		var finished_at_ms: int = int(
			Time.get_ticks_msec()
		)
		var checkpoint_report: Dictionary = {
			"schema": (
				"eralife.game_state_serialization_report"
			),
			"version": SERIALIZATION_RUNTIME_VERSION,
			"success": not checkpoint_payload.is_empty(),
			"source": str(
				options.get(
					"source",
					"serialize_to_payload"
				)
			),
			"profile": str(
				options.get(
					"profile",
					"interactive_checkpoint"
				)
			),
			"payload_schema": SAVE_SCHEMA,
			"save_version": int(
				checkpoint_payload.get(
					"save_version",
					0
				)
			),
			"year": int(
				checkpoint_payload.get(
					"year",
					0
				)
			),
			"player_id": int(
				checkpoint_payload.get(
					"player_id",
					-1
				)
			),
			"npc_count": _safe_array(
				checkpoint_payload.get(
					"npcs",
					[]
				)
			).size(),
			"slice_count": 0,
			"preserved_unknown_slice_count": 0,
			"warnings": [],
			"failed_slices": [],
			"exported_slices": [],
			"structured_slices_deferred": true,
			"seed_contract_saved": (
				checkpoint_payload.has(
					"seed_contract"
				)
			),
			"world_seed": int(
				checkpoint_payload.get(
					"world_seed",
					0
				)
			),
			"interactive_checkpoint": true,
			"full_universe_walk_performed": false,
			"started_at_ms": started_at,
			"finished_at_ms": finished_at_ms,
			"duration_ms": maxi(
				0,
				finished_at_ms - started_at
			),
			"payload": checkpoint_payload
		}

		_store_last_report(
			checkpoint_report
		)
		return checkpoint_report.duplicate(false)


	_ensure_runtime_dependencies()
	_prepare_runtime_for_save(options)

	var write_structured_slices: bool = bool(
		options.get(
			"write_structured_slices",
			true
		)
	)
	var skip_last_payload_cache: bool = bool(
		options.get(
			"skip_last_payload_cache",
			false
		)
	)

	var legacy_payload: Dictionary = (
		_build_legacy_payload(options)
	)
	var slice_bundle: Dictionary = (
		_empty_contract_slice_bundle(options)
	)

	if write_structured_slices:
		slice_bundle = _export_contract_slice_bundle(
			options
		)

	var payload: Dictionary = legacy_payload.duplicate(true)
	payload ["schema"] = SAVE_SCHEMA
	payload ["version"] = SAVE_FORMAT_VERSION
	payload [
		"serialization_runtime_version"
	] = SERIALIZATION_RUNTIME_VERSION
	payload ["saved_at_ms"] = int(
		Time.get_ticks_msec()
	)
	payload ["slices"] = {}
	payload ["migration_hints"] = _build_migration_hints(
		slice_bundle,
		options
	)
	payload ["meta"] = _build_payload_meta(
		options,
		slice_bundle
	)

	var seed_contract: Dictionary = (
		_export_seed_contract_for_payload()
	)

	if not seed_contract.is_empty():
		payload ["seed_contract"] = (
			seed_contract.duplicate(true)
		)
		payload ["world_seed"] = int(
			seed_contract.get(
				"seed",
				0
			)
		)

	if write_structured_slices:
		_apply_slice_bundle_to_payload(
			payload,
			slice_bundle
		)
	else:
		payload [
			"game_state_contract_slices"
		] = slice_bundle.duplicate(true)
		payload [
			"structured_slices_deferred"
		] = true

	_apply_preserved_unknown_slices_to_payload(
		payload
	)
	payload ["life_packet"] = (
		_build_life_packet_for_payload(
			payload,
			options
		)
	)
	payload = _make_binary_safe(payload)

	if skip_last_payload_cache:
		last_payload = {}
	else:
		last_payload = payload.duplicate(true)

	var report: Dictionary = {
		"schema": (
			"eralife.game_state_serialization_report"
		),
		"version": SERIALIZATION_RUNTIME_VERSION,
		"success": true,
		"source": str(
			options.get(
				"source",
				"serialize_to_payload"
			)
		),
		"profile": str(
			options.get(
				"profile",
				"full_simulation"
			)
		),
		"payload_schema": SAVE_SCHEMA,
		"save_version": int(
			payload.get(
				"save_version",
				0
			)
		),
		"year": int(
			payload.get(
				"year",
				0
			)
		),
		"player_id": int(
			payload.get(
				"player_id",
				-1
			)
		),
		"npc_count": _safe_array(
			payload.get(
				"npcs",
				[]
			)
		).size(),
		"slice_count": _safe_dictionary(
			payload.get(
				"slices",
				{}
			)
		).size(),
		"preserved_unknown_slice_count": (
			_collect_preserved_unknown_slices().size()
		),
		"warnings": _safe_array(
			slice_bundle.get(
				"warnings",
				[]
			)
		),
		"failed_slices": _safe_array(
			slice_bundle.get(
				"failed_slices",
				[]
			)
		),
		"exported_slices": _safe_array(
			slice_bundle.get(
				"exported_slices",
				[]
			)
		),
		"structured_slices_deferred": (
			not write_structured_slices
		),
		"seed_contract_saved": payload.has(
			"seed_contract"
		),
		"world_seed": int(
			payload.get(
				"world_seed",
				0
			)
		),
		"started_at_ms": started_at,
		"finished_at_ms": int(
			Time.get_ticks_msec()
		),
		"duration_ms": 0,
		"payload": payload
	}
	report ["duration_ms"] = (
		int(report ["finished_at_ms"])
		- started_at
	)
	report ["success"] = _safe_array(
		report.get(
			"failed_slices",
			[]
		)
	).is_empty()

	_store_last_report(report)
	return report.duplicate(true)
func _interactive_checkpoint_actor_snapshot(
		actor: Person
) -> Dictionary:
	if actor == null:
		return {}

	var snapshot: Dictionary = {}
	var skipped_properties: Array = [
		"script",
		"partner"
	]

	for property_row in actor.get_property_list():
		var property_name: String = str(
			property_row.get(
				"name",
				""
			)
		)
		var property_usage: int = int(
			property_row.get(
				"usage",
				0
			)
		)

		if (
			property_name == ""
			or property_name in skipped_properties
			or (
				property_usage
				& PROPERTY_USAGE_STORAGE
			) == 0
		):
			continue

		snapshot [property_name] = actor.get(
			property_name
		)

	# DIAGNOSTIC: age is not restoring on load. Confirm whether the save even captures
	# it -- the generic property loop should, but PROPERTY_USAGE_STORAGE may exclude it.
	EraLog.truth(
		"ERALIFE_SNAPSHOT_ACTOR|has_age=%s|age=%s|has_money=%s|keys=%d"
		% [
			str(snapshot.has("age")),
			str(snapshot.get("age", "-")),
			str(snapshot.has("money")),
			snapshot.size()
		]
	)

	snapshot ["id"] = int(actor.id)
	snapshot ["partner_id"] = (
		int(actor.partner.id)
		if actor.partner != null
		else -1
	)
	snapshot [
		"checkpoint_snapshot_read_only"
	] = true
	snapshot [
		"checkpoint_snapshot_contract_rebuild"
	] = false

	return snapshot


func _interactive_checkpoint_actor_ids(
		max_actor_count: int = 256
) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	var queue: Array = []

	if gs == null or gs.player == null:
		return out

	queue.append(
		int(gs.player.id)
	)

	if typeof(
		gs.controlled_lineage_ids
	) == TYPE_ARRAY:
		for raw_id in gs.controlled_lineage_ids:
			queue.append(
				int(raw_id)
			)

	while (
		not queue.is_empty()
		and out.size() < maxi(
			1,
			max_actor_count
		)
	):
		var actor_id: int = int(
			queue.pop_front()
		)

		if actor_id <= 0 or seen.has(actor_id):
			continue

		seen [actor_id] = true

		var actor: Person = gs.get_npc_by_id(
			actor_id
		)

		if actor == null:
			continue

		out.append(actor_id)

		for parent_id in actor.parents:
			queue.append(
				int(parent_id)
			)

		for child_id in actor.children:
			queue.append(
				int(child_id)
			)

		if actor.partner != null:
			queue.append(
				int(actor.partner.id)
			)

	return out


func _interactive_checkpoint_scenario_capsule(
	actor_ids: Array = []
) -> Dictionary:
	if (
		gs == null
		or typeof(gs.scenario_state) != TYPE_DICTIONARY
	):
		return {}

	var allowed_keys: Array = [
		"world_seed",
		"seed_contract",
		"life_id",
		"life_branch_id",
		"resident_runtime_signature",
		"resident_runtime_attached_signature",
		"portable_life_packet_id",
		"prebuilt_first_frame_ui_snapshot",
		"zero_frame_consciousness_switch_surface",
		"effective_era_contract",
		"era_contract",
		"era_overlay_contract",
		"current_realm_id",
		"current_settlement_id",
		"current_district_id",
		"current_locality_id",
		"royalty_institution_state",
		"career_ecosystem_state",
		"reality_mode",
		"reality_feature_overrides"
	]
	var capsule: Dictionary = {}

	for raw_key in allowed_keys:
		var key: String = str(raw_key)
		if gs.scenario_state.has(key):
			capsule [key] = gs.scenario_state [key]




	var switch_actor_keys: Dictionary = {}
	for raw_actor_id in actor_ids:
		var actor_id: int = int(raw_actor_id)
		if actor_id > 0:
			switch_actor_keys [str(actor_id)] = true

	var packet_cache_raw: Variant = gs.scenario_state.get(
		"profile_pointer_packet_by_actor",
		{}
	)
	var packet_cache: Dictionary = (
		packet_cache_raw as Dictionary
		if typeof(packet_cache_raw) == TYPE_DICTIONARY
		else {}
	)
	var filtered_packet_cache: Dictionary = {}

	var revisions_raw: Variant = gs.scenario_state.get(
		"profile_pointer_revisions_by_actor",
		{}
	)
	var revisions_by_actor: Dictionary = (
		revisions_raw as Dictionary
		if typeof(revisions_raw) == TYPE_DICTIONARY
		else {}
	)
	var filtered_revisions_by_actor: Dictionary = {}
	var required_revision_keys: Dictionary = {}

	for raw_actor_key in switch_actor_keys.keys():
		var actor_key: String = str(raw_actor_key)

		var packet_raw: Variant = packet_cache.get(
			actor_key,
			{}
		)
		if (
			typeof(packet_raw) == TYPE_DICTIONARY
			and not (packet_raw as Dictionary).is_empty()
		):
			filtered_packet_cache [actor_key] = (
				packet_raw as Dictionary
			).duplicate(false)

			var latest_revision: String = str(
				(packet_raw as Dictionary).get(
					"pointer_revision",
					""
				)
			).strip_edges()
			if latest_revision != "":
				required_revision_keys [latest_revision] = true

		var actor_revisions_raw: Variant = revisions_by_actor.get(
			actor_key,
			[]
		)
		if typeof(actor_revisions_raw) != TYPE_ARRAY:
			continue

		var source_actor_revisions: Array = (
			actor_revisions_raw as Array
		)
		var actor_revisions: Array = []
		for raw_revision in source_actor_revisions:
			var revision: String = str(raw_revision).strip_edges()
			if revision == "":
				continue
			actor_revisions.append(revision)
			required_revision_keys [revision] = true

		if not actor_revisions.is_empty():
			filtered_revisions_by_actor [actor_key] = actor_revisions.duplicate(false)

	var revision_registry_raw: Variant = gs.scenario_state.get(
		"profile_pointer_packet_revision_registry",
		{}
	)
	var revision_registry: Dictionary = (
		revision_registry_raw as Dictionary
		if typeof(revision_registry_raw) == TYPE_DICTIONARY
		else {}
	)
	var filtered_revision_registry: Dictionary = {}

	for raw_revision_key in required_revision_keys.keys():
		var revision_key: String = str(raw_revision_key)
		var record_raw: Variant = revision_registry.get(
			revision_key,
			{}
		)
		if typeof(record_raw) != TYPE_DICTIONARY:
			continue

		var record: Dictionary = record_raw as Dictionary
		var actor_id: int = int(
			record.get(
				"actor_id",
				-1
			)
		)
		if not switch_actor_keys.has(str(actor_id)):
			continue

		var viewer_packet_raw: Variant = record.get(
			"viewer_packet",
			{}
		)
		if (
			typeof(viewer_packet_raw) != TYPE_DICTIONARY
			or (viewer_packet_raw as Dictionary).is_empty()
		):
			continue

		filtered_revision_registry [revision_key] = {
			"schema": str(
				record.get(
					"schema",
					"eralife.profile_pointer_packet_revision_record"
				)
			),
			"version": int(
				record.get(
					"version",
					1
				)
			),
			"actor_id": actor_id,
			"pointer_revision": str(
				record.get(
					"pointer_revision",
					revision_key
				)
			),
			"viewer_packet": (
				viewer_packet_raw as Dictionary
			).duplicate(false),
			"registered_at_ms": int(
				record.get(
					"registered_at_ms",
					0
				)
			)
		}

	if not filtered_packet_cache.is_empty():
		capsule [
			"profile_pointer_packet_by_actor"
		] = filtered_packet_cache

	if not filtered_revisions_by_actor.is_empty():
		capsule [
			"profile_pointer_revisions_by_actor"
		] = filtered_revisions_by_actor

	if not filtered_revision_registry.is_empty():
		capsule [
			"profile_pointer_packet_revision_registry"
		] = filtered_revision_registry

	capsule ["checkpoint_capsule_only"] = true
	capsule ["full_universe_archive_deferred"] = true
	capsule ["checkpoint_switch_residency_preserved"] = (
		not filtered_packet_cache.is_empty()
	)
	capsule ["checkpoint_switch_resident_actor_count"] = (
		filtered_packet_cache.size()
	)
	capsule ["checkpoint_switch_revision_count"] = (
		filtered_revision_registry.size()
	)
	capsule ["checkpoint_switch_rebuild_performed"] = false
	capsule ["checkpoint_switch_readiness_invalidated"] = false
	capsule ["ui_is_renderer_only"] = true

	return capsule

func _collect_engine_registry_sections() -> Dictionary:
	# Capture the engine stores the player can actually lose: vehicles, belongings,
	# property, heirlooms. GameState's rewind collector gathers these too, but it
	# dereferences a whole group of engines per section and throws if any one is
	# absent -- losing every store in that section. Read each one directly so a
	# missing engine costs only its own entry.
	var registry: Dictionary = {}

	if gs == null:
		return registry

	if gs.vehicle_engine != null and typeof(gs.vehicle_engine.vehicles) == TYPE_DICTIONARY:
		registry ["vehicles"] = gs.vehicle_engine.vehicles.duplicate(true)

	if gs.belongings_engine != null and typeof(gs.belongings_engine.belongings) == TYPE_DICTIONARY:
		registry ["belongings"] = gs.belongings_engine.belongings.duplicate(true)

	if gs.property_engine != null:
		if typeof(gs.property_engine.properties) == TYPE_DICTIONARY:
			registry ["properties"] = gs.property_engine.properties.duplicate(true)

		if typeof(gs.property_engine.used_addresses) == TYPE_DICTIONARY:
			registry ["used_addresses"] = gs.property_engine.used_addresses.duplicate(true)

	if gs.heirloom_engine != null and typeof(gs.heirloom_engine.heirlooms) == TYPE_DICTIONARY:
		registry ["heirlooms"] = gs.heirloom_engine.heirlooms.duplicate(true)

	EraLog.truth(
		"ERALIFE_REGISTRY_COLLECTED|keys=%d|vehicles=%s|belongings=%s|properties=%s|heirlooms=%s"
		% [
			registry.size(),
			str(registry.has("vehicles")),
			str(registry.has("belongings")),
			str(registry.has("properties")),
			str(registry.has("heirlooms"))
		]
	)

	return registry


func _build_interactive_checkpoint_payload(
	options: Dictionary = {}
) -> Dictionary:
	var actor_ids: Array = _interactive_checkpoint_actor_ids(
		int(
			options.get(
				"checkpoint_actor_limit",
				256
			)
		)
	)
	var npc_rows: Array = []

	for raw_actor_id in actor_ids:
		var actor: Person = gs.get_npc_by_id(
			int(raw_actor_id)
		)

		if actor == null:
			continue

		var actor_snapshot: Dictionary = (
			_interactive_checkpoint_actor_snapshot(
				actor
			)
		)

		if not actor_snapshot.is_empty():
			npc_rows.append(
				actor_snapshot
			)

	var player_name: String = (
		(
			"%s %s"
			% [
				gs.player.first_name,
				gs.player.last_name
			]
		).strip_edges()
		if gs.player != null
		else ""
	)
	var scenario_capsule: Dictionary = (
		_interactive_checkpoint_scenario_capsule(
			actor_ids
		)
	)
	var seed_contract: Dictionary = _safe_dictionary(
		scenario_capsule.get(
			"seed_contract",
			{}
		)
	)
	var payload: Dictionary = {
		"schema": SAVE_SCHEMA,
		"version": SAVE_FORMAT_VERSION,
		"serialization_runtime_version": (
			SERIALIZATION_RUNTIME_VERSION
		),
		"save_version": int(gs.save_version),
		"saved_at_ms": int(
			Time.get_ticks_msec()
		),
		"saved_at_unix": int(
			Time.get_unix_time_from_system()
		),
		"year": int(gs.year),
		"next_id": int(gs.next_id),
		"era_name": _era_name(),
		"player_id": int(gs.player_id),
		"player_name": player_name,
		"last_saved_age": (
			int(gs.player.age)
			if gs.player != null
			else 0
		),
		"npcs": npc_rows,
		"controlled_lineage_ids": (
			gs.controlled_lineage_ids.duplicate()
			if typeof(
				gs.controlled_lineage_ids
			) == TYPE_ARRAY
			else []
		),
		"scenario_state": scenario_capsule,
		"custom_mode": bool(gs.custom_mode),
		"custom_settings": gs.custom_settings,
		"reality_mode": gs.reality_mode,
		"feature_overrides": (
			gs.reality_feature_overrides
		),
		"world_seed": int(
			scenario_capsule.get(
				"world_seed",
				seed_contract.get(
					"seed",
					0
				)
			)
		),
		"seed_contract": seed_contract,
		# FIX: the interactive checkpoint captured actors and world scalars but NO
		# engine state, so vehicles, property, belongings, heirlooms, pets and market
		# data were simply never saved -- they vanished on load because they were never
		# written. GameState already assembles exactly these stores for its rewind
		# snapshot, so reuse that rather than duplicating the field list.
		"engine_registry": _collect_engine_registry_sections(),
		"canonical_relationship_graph": (
			gs.canonical_relationship_graph.duplicate(true)
			if typeof(gs.canonical_relationship_graph) == TYPE_DICTIONARY
			else {}
		),
		"entity_registry": (
			gs.entity_registry.duplicate(true)
			if typeof(gs.entity_registry) == TYPE_DICTIONARY
			else {}
		),
		"life_packet": {
			"schema": "eralife.life_packet",
			"version": 1,
			"actor_id": int(gs.player_id),
			"year": int(gs.year),
			"lineage_actor_ids": actor_ids.duplicate(),
		},
		"slices": {},
		"game_state_contract_slices": {},
		"structured_slices_deferred": true,
		"full_universe_archive_deferred": true,
		"checkpoint_actor_count": npc_rows.size(),
		"meta": {
			"source": str(
				options.get(
					"source",
					"interactive_checkpoint"
				)
			),
			"profile": str(
				options.get(
					"profile",
					"interactive_checkpoint"
				)
			),
			"checkpoint_save": true,
			"full_universe_walk_performed": false,
			"bounded_switch_residency_registry_export_performed": bool(
				scenario_capsule.get(
					"checkpoint_switch_residency_preserved",
					false
				)
			)
		}
	}

	return _make_binary_safe(payload)
func save_interactive_reality_checkpoint(
		path: String,
		options: Dictionary = {}
) -> Dictionary:
	var started_at_ms: int = int(
		Time.get_ticks_msec()
	)
	var clean_path: String = str(
		path
	).strip_edges()

	if clean_path == "":
		return _fail_report(
			"checkpoint_path_missing",
			"Checkpoint path is missing.",
			{}
		)

	if gs == null or gs.player == null:
		return _fail_report(
			"checkpoint_actor_missing",
			"No active life is available to preserve.",
			{}
		)

	# FIX: these four engines are created lazily by
	# GameState._ensure_identity_checkpoint_runtime_dependencies(), which is called
	# from save_game() and four other paths -- but NOT from this checkpoint save
	# route. Arriving here directly left them null and the save was rejected with
	# "Checkpoint authorities were not resident before save intent." Build them
	# BEFORE the check below, or the list is computed from stale nulls.
	if gs != null and gs.has_method("_ensure_identity_checkpoint_runtime_dependencies"):
		gs._ensure_identity_checkpoint_runtime_dependencies()

	var missing_authorities: Array = []

	for authority_row in [
		[
			"identity_contract_engine",
			gs.identity_contract_engine
		],
		[
			"life_account_transfer_contract_engine",
			gs.life_account_transfer_contract_engine
		],
		[
			"session_contract_engine",
			gs.session_contract_engine
		],
		[
			"reality_checkpoint_contract_engine",
			gs.reality_checkpoint_contract_engine
		]
	]:
		if authority_row [1] == null:
			missing_authorities.append(
				str(authority_row [0])
			)

	if not missing_authorities.is_empty():
		return _fail_report(
			"checkpoint_authorities_not_resident",
			(
				"Checkpoint authorities were not resident "
				+ "before save intent."
			),
			{
				"missing": missing_authorities,
				"build_on_click_forbidden": true
			}
		)

	var live_options: Dictionary = (
		options.duplicate(false)
	)
	live_options ["interactive_save"] = true
	live_options [
		"fast_interactive_universe_save"
	] = true
	live_options ["checkpoint_save"] = true
	live_options [
		"checkpoint_dependencies_must_be_hot"
	] = true
	live_options [
		"write_structured_slices"
	] = false
	live_options [
		"preserve_unknown_slices"
	] = false
	live_options [
		"skip_last_payload_cache"
	] = true
	live_options [
		"skip_cross_device_checkpoint"
	] = true
	live_options [
		"skip_summary_cache"
	] = false

	var save_report: Dictionary = serialize_to_path(
		clean_path,
		live_options
	)

	if not bool(
		save_report.get(
			"success",
			false
		)
	):
		return save_report

	var checkpoint_report: Dictionary = (
		gs.commit_current_life_checkpoint_contract(
			clean_path,
			save_report,
			live_options
		)
	)
	save_report [
		"reality_checkpoint_commit"
	] = checkpoint_report.duplicate(false)

	# FIX: this path sets skip_cross_device_checkpoint = true, so
	# _build_cross_device_checkpoint() never runs -- and that is the ONLY place the
	# <save>.bin.summary cache is written. Without it a load falls back to
	# filename-derived metadata with no checkpoint_resume_contract, the resume shell
	# is never materialised, the residency record never reaches "ready", and the load
	# polls forever. The checkpoint itself IS committed here, so the resume contract
	# exists; it just was not being persisted. Write the summary cache now.
	if (
		bool(checkpoint_report.get("success", false))
		and gs.has_method("_read_saved_life_summary")
		and gs.has_method("_write_saved_life_summary_cache")
	):
		var interactive_summary: Dictionary = _safe_dictionary(
			gs._read_saved_life_summary(clean_path)
		)
		var interactive_resume_raw: Variant = checkpoint_report.get(
			"checkpoint_resume_contract",
			{}
		)

		if typeof(interactive_resume_raw) == TYPE_DICTIONARY:
			interactive_summary ["checkpoint_resume_contract"] = (
				(interactive_resume_raw as Dictionary).duplicate(false)
			)

		interactive_summary ["path"] = clean_path
		interactive_summary ["checkpoint_summary_schema"] = (
			"eralife.saved_life.resume_summary"
		)

		gs._write_saved_life_summary_cache(
			clean_path,
			interactive_summary
		)

		EraLog.truth(
			"ERALIFE_SAVE_SUMMARY|path=%s|keys=%d|has_resume=%s|cache_written=%s"
			% [
				clean_path,
				interactive_summary.size(),
				str(interactive_summary.has("checkpoint_resume_contract")),
				str(FileAccess.file_exists("%s.summary" % clean_path))
			]
		)

	save_report ["success"] = bool(
		checkpoint_report.get(
			"success",
			false
		)
	)
	save_report [
		"interactive_checkpoint"
	] = true
	save_report [
		"full_universe_walk_performed"
	] = false
	save_report [
		"renderer_called_simulation_directly"
	] = false
	save_report ["finished_at_ms"] = int(
		Time.get_ticks_msec()
	)
	save_report ["duration_ms"] = maxi(
		0,
		int(
			save_report ["finished_at_ms"]
		) - started_at_ms
	)

	# FIX: "%" binds tighter than "+", so only the final "|at_ms=%d" was formatted and
	# every earlier placeholder printed literally as %s / %d. Parenthesise the
	# concatenation so the format applies to the whole string.
	EraLog.truth(
		(
			"ERALIFE_LINEAGE_SAVE_TRUTH"
			+ "|success=%s"
			+ "|actor_id=%d"
			+ "|checkpoint_committed=%s"
			+ "|full_universe_walk=false"
			+ "|engine_registry_export=false"
			+ "|duration_ms=%d"
			+ "|at_ms=%d"
		)
		% [
			str(
				save_report.get(
					"success",
					false
				)
			).to_lower(),
			int(gs.player.id),
			str(
				checkpoint_report.get(
					"success",
					false
				)
			).to_lower(),
			int(
				save_report.get(
					"duration_ms",
					0
				)
			),
			int(Time.get_ticks_msec())
		]
	)

	return save_report
func _empty_contract_slice_bundle(options: Dictionary = {}) -> Dictionary:
	return {
		"schema": "eralife.game_state_contract_save_slices",
		"version": SERIALIZATION_RUNTIME_VERSION,
		"state_id": _active_state_id(),
		"save_contract": {},
		"slices": {},
		"orphaned_slices": {},
		"warnings": [],
		"failed_slices": [],
		"exported_slices": [],
		"deferred": true,
		"deferred_reason": str(options.get("deferred_reason", "interactive_fast_save")),
		"exported_at_ms": int(Time.get_ticks_msec())
	}

func _export_seed_contract_for_payload() -> Dictionary:
	if gs == null:
		return {}

	if gs.seed_engine == null:
		return {}

	if gs.seed_engine.has_method("export_state"):
		var exported: Variant = gs.seed_engine.export_state()
		if typeof(exported) == TYPE_DICTIONARY:
			return _make_binary_safe(exported as Dictionary)

	if "seed_value" in gs.seed_engine:
		return {
			"schema": "eralife.seed_contract",
			"version": 1,
			"seed": int(gs.seed_engine.seed_value),
			"random_domains": {},
			"world_rules": {}
		}

	return {}

func serialize_live_slice_frame(options: Dictionary = {}) -> Dictionary:
	var started_at: int = int(Time.get_ticks_msec())

	if gs == null:
		return _fail_report("game_state_missing", "GameState unavailable for live slice serialization.", {})

	_ensure_runtime_dependencies()

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var target_year: int = int(options.get("target_year", int(gs.year) + 1))
	var player_id: int = int(options.get("player_id", int(gs.player.id) if gs.player != null else int(gs.player_id)))
	var entity_scope: String = str(options.get("entity_scope", "player_bubble")).strip_edges()

	var slice_bundle: Dictionary = _export_contract_slice_bundle({
		"source": str(options.get("source", "serialize_live_slice_frame")),
		"profile": "live_slice_stream",
		"skip_memory_compaction": true,
		"skip_prune": true,
		"skip_archive": true,
		"target_year": target_year,
		"player_id": player_id
	})

	var raw_slices: Dictionary = _safe_dictionary(slice_bundle.get("slices", {}))
	var filtered_slices: Dictionary = _filter_live_slice_rows(raw_slices, options)
	var entity_rows: Array = _build_live_entity_graph_subset(player_id, entity_scope, options)

	var frame: Dictionary = {
		"schema": FRAME_SCHEMA,
		"version": SERIALIZATION_RUNTIME_VERSION,
		"source": str(options.get("source", "serialize_live_slice_frame")),
		"profile": "live_slice_stream",
		"source_year": int(gs.year),
		"target_year": target_year,
		"player_id": player_id,
		"entity_scope": entity_scope,
		"core_identity": {
			"year": int(gs.year),
			"target_year": target_year,
			"next_id": int(gs.next_id),
			"player_id": player_id,
			"player_age": int(gs.player.age) if gs.player != null else -1,
			"save_version": int(gs.save_version),
			"era_name": _era_name()
		},
		"entity_graph_subset": entity_rows,
		"slices": filtered_slices,
		"slice_bundle_meta": {
			"exported_slice_count": raw_slices.size(),
			"streamed_slice_count": filtered_slices.size(),
			"entity_subset_count": entity_rows.size()
		},
		"created_at_ms": int(Time.get_ticks_msec())
	}

	var report: Dictionary = {
		"schema": "eralife.live_slice_serialization_report",
		"version": SERIALIZATION_RUNTIME_VERSION,
		"success": true,
		"source_year": int(gs.year),
		"target_year": target_year,
		"player_id": player_id,
		"slice_count": filtered_slices.size(),
		"entity_subset_count": entity_rows.size(),
		"started_at_ms": started_at,
		"finished_at_ms": int(Time.get_ticks_msec()),
		"frame": _make_binary_safe(frame)
	}
	report ["duration_ms"] = int(report ["finished_at_ms"]) - started_at

	if typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["last_live_slice_serialization_report"] = report.duplicate(true)
		gs.scenario_state ["last_live_slice_frame_meta"] = {
			"source_year": int(gs.year),
			"target_year": target_year,
			"player_id": player_id,
			"slice_count": filtered_slices.size(),
			"entity_subset_count": entity_rows.size()
		}

	return report.duplicate(true)


func _filter_live_slice_rows(slice_rows: Dictionary, options: Dictionary) -> Dictionary:
	var out: Dictionary = {}

	var filter_raw: Variant = options.get("slice_filter", [])
	var filter: Array = filter_raw if typeof(filter_raw) == TYPE_ARRAY else []

	for save_key in slice_rows.keys():
		var clean_key: String = str(save_key).strip_edges()
		if clean_key == "":
			continue

		var row_raw: Variant = slice_rows.get(save_key, {})
		if typeof(row_raw) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = row_raw

		if not filter.is_empty() and not filter.has(clean_key):
			var metadata: Dictionary = _safe_dictionary(row.get("metadata", {}))
			var temporal_stream_enabled: bool = bool(metadata.get("temporal_stream", false))
			var stream_on_demand: bool = bool(row.get("stream_on_demand", false))
			var key_lower: String = clean_key.to_lower()
			var likely_temporal: bool = key_lower.find("market") >= 0 \
or key_lower.find("economy") >= 0 \
or key_lower.find("relationship") >= 0 \
or key_lower.find("social") >= 0 \
or key_lower.find("bank") >= 0 \
or key_lower.find("world") >= 0

			if not temporal_stream_enabled and not stream_on_demand and not likely_temporal:
				continue

		out [clean_key] = row.duplicate(true)

	return _make_binary_safe(out)


func _build_live_entity_graph_subset(player_id: int, entity_scope: String, options: Dictionary) -> Array:
	var out: Array = []
	if gs == null:
		return out

	var ids: Dictionary = {}
	var explicit_ids_raw: Variant = options.get("entity_ids", [])
	if typeof(explicit_ids_raw) == TYPE_ARRAY:
		for raw_id in explicit_ids_raw:
			var clean_id: int = int(raw_id)
			if clean_id > 0:
				ids [clean_id] = true

	if player_id > 0:
		ids [player_id] = true

	if entity_scope in ["player_bubble", "near", "family", "relationships"]:
		var player = gs.get_npc_by_id(player_id) if gs.has_method("get_npc_by_id") else null
		if player != null:
			for pid in player.parents:
				ids [int(pid)] = true
			for cid in player.children:
				ids [int(cid)] = true
			for fid in player.friends:
				ids [int(fid)] = true
			for exid in player.ex_partners:
				ids [int(exid)] = true

			var partner = gs.get_valid_partner(player, true) if gs.has_method("get_valid_partner") else null
			if partner != null:
				ids [int(partner.id)] = true

	if typeof(gs.scenario_state) == TYPE_DICTIONARY:
		var active_groups_raw: Variant = gs.scenario_state.get("active_age_up_groups", {})
		if typeof(active_groups_raw) == TYPE_DICTIONARY:
			for group_key in ["near", "player_bubble", "lane_a"]:
				var group_raw: Variant = (active_groups_raw as Dictionary).get(group_key, [])
				if typeof(group_raw) == TYPE_ARRAY:
					for raw_id in group_raw:
						var clean_group_id: int = int(raw_id)
						if clean_group_id > 0:
							ids [clean_group_id] = true

	for id_key in ids.keys():
		var npc = null
		if gs.has_method("get_or_reactivate_npc_by_id"):
			npc = gs.get_or_reactivate_npc_by_id(int(id_key))
		elif gs.has_method("get_npc_by_id"):
			npc = gs.get_npc_by_id(int(id_key))

		if npc == null:
			continue

		out.append(gs._serialize_npc(npc))

	return out
func _ensure_runtime_dependencies() -> void:
	if gs == null:
		return

	if gs.has_method("_ensure_load_game_runtime_dependencies"):
		gs._ensure_load_game_runtime_dependencies()

	if gs.game_state_contract_engine == null:
		gs.game_state_contract_engine = GameStateContractEngine.new(gs)

	if gs.game_state_hydration_runtime == null:
		gs.game_state_hydration_runtime = GameStateHydrationRuntime.new(gs)


func _prepare_runtime_for_save(options: Dictionary) -> void:
	if gs == null:
		return

	var skip_memory_compaction: bool = bool(options.get("skip_memory_compaction", false))
	var skip_world_feed_normalization: bool = bool(options.get("skip_world_feed_normalization", false))
	var skip_prune: bool = bool(options.get("skip_prune", false))
	var skip_archive: bool = bool(options.get("skip_archive", false))
	var skip_warm_runtime_snapshot: bool = bool(options.get("skip_warm_runtime_snapshot", false))
	var skip_runtime_registry_refresh: bool = bool(options.get("skip_runtime_registry_refresh", false))
	var interactive_save: bool = bool(options.get("interactive_save", false))

	if interactive_save:
		skip_memory_compaction = true
		skip_world_feed_normalization = true
		skip_prune = true
		skip_archive = true
		skip_warm_runtime_snapshot = true
		skip_runtime_registry_refresh = true

	if not skip_memory_compaction:
		for pid_value in gs.memories.keys():
			gs._compress_person_memories(int(pid_value))

	if not skip_world_feed_normalization:
		for i in range(gs.world_feed.size()):
			gs.world_feed [i] = gs.normalize_world_feed_entry(gs.world_feed [i])

	if not skip_prune:
		gs._prune_dead_npcs()

	var should_archive: bool = false
	if not skip_archive:
		should_archive = gs.archive_generations.size() == 0
		if not should_archive:
			var last_archive: Variant = gs.archive_generations.back()
			var last_archive_year: int = int(gs.year) - 1
			if typeof(last_archive) == TYPE_DICTIONARY:
				last_archive_year = int(last_archive.get("year", int(gs.year) - 1))
			elif last_archive != null and typeof(last_archive) == TYPE_OBJECT:
				var archive_year_raw: Variant = last_archive.get("year")
				if archive_year_raw != null:
					last_archive_year = int(archive_year_raw)
			should_archive = last_archive_year != int(gs.year)

	if should_archive:
		gs.archive_generation()

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	if not skip_warm_runtime_snapshot:
		_refresh_warm_runtime_snapshot()

	if not skip_runtime_registry_refresh:
		if gs.realm_contract_engine != null and gs.realm_contract_engine.has_method("refresh_runtime_registry"):
			gs.realm_contract_engine.refresh_runtime_registry()
		if gs.game_state_contract_engine != null and gs.game_state_contract_engine.has_method("refresh_runtime_registry"):
			gs.game_state_contract_engine.refresh_runtime_registry()


func _refresh_warm_runtime_snapshot() -> void:
	if gs == null or typeof(gs.scenario_state) != TYPE_DICTIONARY:
		return

	var warm_snapshot_raw: Variant = gs.scenario_state.get("warm_world_runtime_snapshot", {})
	var warm_snapshot: Dictionary = warm_snapshot_raw if typeof(warm_snapshot_raw) == TYPE_DICTIONARY else {}

	var warm_plan_raw: Variant = gs.scenario_state.get("warm_runtime_plan", {})
	var warm_plan: Dictionary = warm_plan_raw if typeof(warm_plan_raw) == TYPE_DICTIONARY else {}

	var can_refresh_warm_runtime: bool = bool(gs.scenario_state.get("static_world_runtime_bootstrapped", false))
	can_refresh_warm_runtime = can_refresh_warm_runtime and not bool(gs.scenario_state.get("year_in_progress", false))

	if not can_refresh_warm_runtime:
		return

	if gs.player == null or not bool(gs.player.alive):
		return

	if warm_plan.is_empty() and gs.simulation_director != null and gs.simulation_director.has_method("build_runtime_plan"):
		gs._rebuild_npc_index()
		gs._soft_unload_npcs()
		var save_warm_plan: Dictionary = gs.simulation_director.build_runtime_plan({
			"year": int(gs.year + 1),
			"mode": "living",
			"player_id": int(gs.player.id),
			"runtime_owner": "save_snapshot"
		})
		gs.scenario_state ["warm_runtime_plan"] = {
			"year": int(gs.year + 1),
			"mode": "living",
			"player_id": int(gs.player.id),
			"plan": save_warm_plan.duplicate(true)
		}
		warm_plan = gs.scenario_state ["warm_runtime_plan"]

	if warm_snapshot.is_empty() or not bool(warm_snapshot.get("static_world_runtime_bootstrapped", false)):
		gs.scenario_state ["warm_world_runtime_snapshot"] = gs._export_warm_runtime_snapshot()


func _build_legacy_payload(_options: Dictionary = {}) -> Dictionary:
	var saved_at_unix: int = int(Time.get_unix_time_from_system())
	var player_name: String = ""
	var player_age: int = 0

	if gs.player != null:
		player_name = ("%s %s" % [gs.player.first_name, gs.player.last_name]).strip_edges()
		player_age = int(gs.player.age)

	var serializable_scenario_state: Dictionary = gs._build_serializable_scenario_state()

	var serializable_realm_contract_registry: Dictionary = {}
	if gs.realm_contract_engine != null and gs.realm_contract_engine.has_method("export_registry"):
		serializable_realm_contract_registry = gs.realm_contract_engine.export_registry()

	var serializable_world_engine_contract_registry: Dictionary = {}
	if gs.world_engine != null and gs.world_engine.has_method("export_registry"):
		serializable_world_engine_contract_registry = gs.world_engine.export_registry()

	var serializable_life_engine_contract_registry: Dictionary = {}
	if gs.life_engine != null and gs.life_engine.has_method("export_registry"):
		serializable_life_engine_contract_registry = gs.life_engine.export_registry()

	var serializable_mod_contract_registry: Dictionary = {}
	if gs.mod_loader != null and gs.mod_loader.has_method("export_registry"):
		serializable_mod_contract_registry = gs.mod_loader.export_registry()

	var serializable_game_state_contract_registry: Dictionary = {}
	var serializable_game_state_contract_slices: Dictionary = {}
	var serializable_game_state_runtime_guard: Dictionary = {}

	if gs.game_state_contract_engine != null:
		if gs.game_state_contract_engine.has_method("export_registry"):
			serializable_game_state_contract_registry = gs.game_state_contract_engine.export_registry()
		if gs.game_state_contract_engine.has_method("export_runtime_guard"):
			serializable_game_state_runtime_guard = gs.game_state_contract_engine.export_runtime_guard()

	var warm_snapshot_raw: Variant = gs.scenario_state.get("warm_world_runtime_snapshot", {}) if typeof(gs.scenario_state) == TYPE_DICTIONARY else {}
	var warm_snapshot: Dictionary = warm_snapshot_raw if typeof(warm_snapshot_raw) == TYPE_DICTIONARY else {}

	var out: Dictionary = {
		"year": int(gs.year),
		"next_id": int(gs.next_id),
		"era_name": _era_name(),
		"player_id": int(gs.player_id),
		"player_name": player_name,
		"last_saved_age": player_age,
		"saved_at_unix": saved_at_unix,
		"npcs": [],
		"dormant_npcs": gs.dormant_npcs,
		"memories": gs.memories,
		"population_shards": _engine_field(gs.population_shard_engine, "population_shards", {}),
		"lineage_ledger": _engine_field(gs.population_shard_engine, "lineage_ledger", {}),
		"dynasties": _engine_field(gs.dynasty_engine, "dynasties", {}),
		"agent_observer_memories": _engine_field(gs.agent_memory_propagation_engine, "observer_memories", {}),
		"compressed_memories": gs.compressed_memories,
		"npc_graveyard": gs.npc_graveyard,
		"archive_generations": gs.archive_generations,
		"save_version": int(gs.save_version),
		"world_chronicle": _engine_field(gs.world_chronicle_engine, "timeline", []),
		"historical_timeline": _engine_field(gs.historical_timeline_engine, "timeline", []),
		"world_feed": gs.world_feed,
		"artifacts_ownership": _engine_field(gs.artifacts_engine, "ownership", {}),
		"artifacts_cosmic_karma": _engine_field(gs.artifacts_engine, "cosmic_karma", 0),
		"artifacts_pending_galactic_enforcer": _engine_field(gs.artifacts_engine, "pending_galactic_enforcer", {}),
		"dragonballs_ownership": _engine_field(gs.dragonballs_engine, "ownership", {}),
		"red_bonnet_owner_id": _engine_field(gs.red_bonnet_engine, "owner_id", -1),
		"school_enrollment": _engine_field(gs.school_engine, "enrollment", {}),
		"school_rosters": _engine_field(gs.school_engine, "school_rosters", {}),
		"school_teachers": _engine_field(gs.school_engine, "school_teachers", {}),
		"workplace_rosters": _engine_field(gs.workplace_engine, "workplace_rosters", {}),
		"workplace_meta": _engine_field(gs.workplace_engine, "workplace_meta", {}),
		"npc_workplace": _engine_field(gs.workplace_engine, "npc_workplace", {}),
		"properties": _engine_field(gs.property_engine, "properties", {}),
		"used_addresses": _engine_field(gs.property_engine, "used_addresses", {}),
		"vehicles": _engine_field(gs.vehicle_engine, "vehicles", {}),
		"heirlooms": _engine_field(gs.heirloom_engine, "heirlooms", {}),
		"islands": _engine_field(gs.island_realm_engine, "islands", {}),
		"belongings": _engine_field(gs.belongings_engine, "belongings", {}),
		"geo_engine_state": _engine_export_state(gs.geo_engine),
		"scenario_popup_contract_engine_state": _engine_export_state(gs.scenario_popup_contract_engine),
		"scenario_runtime_contract_engine_state": _engine_export_state(gs.scenario_runtime_contract_engine),
		"pending_situations_engine_state": _engine_export_state(gs.pending_situations_engine),
		"contract_view_layer_contract_engine_state": _engine_export_state(gs.contract_view_layer_contract_engine),
		"traits_contract_engine_state": _engine_export_state(gs.traits_contract_engine),
		"identity_contract_engine_state": _engine_export_state(gs.identity_contract_engine),
		"universal_switch_contract_engine_state": _engine_export_state(gs.universal_switch_contract_engine),
		"runtime_contract_engine_state": _engine_export_state(gs.runtime_contract_engine),
		"romance_contract_engine_state": _engine_export_state(gs.romance_contract_engine),
		"shared_public_space_engine_state": _engine_export_state(gs.shared_public_space_engine),
		"genetics_inheritance_engine_state": _engine_export_state(gs.genetics_inheritance_engine),
		"body_type_contract_engine_state": _engine_export_state(gs.body_type_contract_engine),
		"growth_curve_engine_state": _engine_export_state(gs.growth_curve_engine),
		"height_contract_engine_state": _engine_export_state(gs.height_contract_engine),
		"weight_contract_engine_state": _engine_export_state(gs.weight_contract_engine),
		"food_engine_state": _engine_export_state(gs.food_engine),
		"food_restaurant_engine_state": _engine_export_state(gs.food_restaurant_engine),
		"grocery_store_engine_state": _engine_export_state(gs.grocery_store_engine),
		"movie_theater_engine_state": _engine_export_state(gs.movie_theater_engine),
		"luxury_shop_engine_state": _engine_export_state(gs.luxury_shop_engine),
		"realm_realms": _engine_field(gs.realm_engine, "realms", {}),
		"realm_contract_registry": serializable_realm_contract_registry,
		"simulation_contract_registry": gs.simulation_contract_engine.export_registry() if gs.simulation_contract_engine != null and gs.simulation_contract_engine.has_method("export_registry") else {},
		"ui_contract_registry": gs.ui_contract_engine.export_registry() if gs.ui_contract_engine != null and gs.ui_contract_engine.has_method("export_registry") else {},
		"world_engine_contract_registry": serializable_world_engine_contract_registry,
		"life_engine_contract_registry": serializable_life_engine_contract_registry,
		"mod_contract_registry": serializable_mod_contract_registry,
		"game_state_contract_registry": serializable_game_state_contract_registry,
		"game_state_contract_slices": serializable_game_state_contract_slices,
		"game_state_runtime_guard": serializable_game_state_runtime_guard,
		"contract_runtime_engines": gs.contract_runtime_engines.keys() if typeof(gs.contract_runtime_engines) == TYPE_DICTIONARY else [],
		"social_graph": _engine_field(gs.social_graph_engine, "graph", {}),
		"world_space_tiles": _engine_field(gs.world_space_engine, "tiles", {}),
		"world_space_npc_tile": _engine_field(gs.world_space_engine, "npc_tile", {}),
		"chunk_sim_chunks": _engine_field(gs.chunk_simulation_engine, "chunks", {}),
		"global_market": _engine_field(gs.global_market_engine, "goods_market", {}),
		"bank_engine_state": _engine_export_state(gs.bank_engine),
		"crime_contract_engine_state": _engine_export_state(gs.crime_contract_engine),
		"investigation_layer_state": _engine_export_state(gs.investigation_layer),
		"justice_system_engine_state": _engine_export_state(gs.justice_system_engine),
		"jail_engine_state": _engine_export_state(gs.jail_engine),
		"prison_engine_state": _engine_export_state(gs.prison_engine),
		"case_orchestrator_state": _engine_export_state(gs.case_orchestrator),
		"dynasty_reputation": _engine_field(gs.dynasty_legacy_engine, "dynasty_reputation", {}),
		"dynasty_grudges": _engine_field(gs.dynasty_legacy_engine, "dynasty_grudges", {}),
		"legacy_dynasty_memories": _engine_field(gs.legacy_memory_engine, "dynasty_memories", {}),
		"legacy_npc_memory_of_dynasty": _engine_field(gs.legacy_memory_engine, "npc_memory_of_dynasty", {}),
		"many_realms_hidden_realms": _engine_field(gs.many_realms_engine, "hidden_realms", {}),
		"many_realms_ring_owner_id": _engine_field(gs.many_realms_engine, "ring_owner_id", -1),
		"npc_memory_graph": _engine_field(gs.npc_memory_web_engine, "memory_graph", {}),
		"boxing_rankings": _engine_field(gs.boxing_ranking_engine, "rankings", {}),
		"boxing_champions": _engine_field(gs.boxing_title_engine, "champions", {}),
		"boxing_lineages": _engine_field(gs.boxing_title_engine, "lineages", {}),
		"boxing_rivalries": _engine_field(gs.boxing_rivalry_engine, "rivalries", {}),
		"boxing_promoter_state": _engine_field(gs.boxing_promotion_engine, "promoter_state", {}),
		"boxing_mandatories": _engine_field(gs.boxing_mandatory_engine, "mandatories", {}),
		"boxing_media_state": _engine_field(gs.boxing_media_engine, "media_state", {}),
		"boxing_family_legacy": _engine_field(gs.boxing_legacy_engine, "family_legacy", {}),
		"vampire_covens": _engine_field(gs.vampire_society_engine, "covens", {}),
		"vampire_hunter_orders": _engine_field(gs.vampire_hunter_engine, "hunter_orders", {}),
		"vampire_bloodlines": _engine_field(gs.vampire_legacy_engine, "bloodlines", {}),
		"vampire_family_legacy": _engine_field(gs.vampire_legacy_engine, "family_legacy", {}),
		"vampire_global_state": _engine_field(gs.vampire_engine, "global_state", {}),
		"legacy_echo_registry": _engine_field(gs.legacy_echo_engine, "echo_registry", {}),
		"consciousness_engine_state": _engine_export_state(gs.consciousness_engine),
		"perceptual_integrity_engine_state": _engine_export_state(gs.perceptual_integrity_engine),
		"afterlife_active": bool(gs.afterlife_active),
		"afterlife_state": gs.afterlife_state,
		"lineage_influence_profiles": gs.lineage_influence_profiles,
		"transient_afterlife_biases": gs.transient_afterlife_biases,
		"lineage_engine_state": _engine_export_state(gs.lineage_engine),
		"scenario_state": serializable_scenario_state,
		"scenario_history": gs.scenario_history,
		"transient_scenario_biases": gs.transient_scenario_biases,
		"custom_mode": bool(gs.custom_mode),
		"custom_settings": gs.custom_settings,
		"reality_mode": gs.reality_mode,
		"feature_overrides": gs.reality_feature_overrides,
		"warm_world_runtime_snapshot": warm_snapshot.duplicate(true),
		"universal_faction_state": gs.universal_faction_engine.export_state() if gs.universal_faction_engine != null and gs.universal_faction_engine.has_method("export_state") else gs.universal_faction_state
	}

	for npc in gs.npcs:
		if npc == null:
			continue
		out ["npcs"].append(gs._serialize_npc(npc))

	return out


func _export_contract_slice_bundle(options: Dictionary = {}) -> Dictionary:
	var save_contract: Dictionary = {}
	if gs != null and gs.game_state_contract_engine != null and gs.game_state_contract_engine.has_method("build_active_save_contract"):
		save_contract = gs.game_state_contract_engine.build_active_save_contract({
			"phase": "game_state_serialization_runtime",
			"source": str(options.get("source", "save_game"))
		})

	var out: Dictionary = {
		"schema": "eralife.game_state_contract_save_slices",
		"version": SERIALIZATION_RUNTIME_VERSION,
		"state_id": _active_state_id(),
		"save_contract": save_contract.duplicate(true),
		"slices": {},
		"orphaned_slices": {},
		"warnings": [],
		"failed_slices": [],
		"exported_slices": [],
		"exported_at_ms": int(Time.get_ticks_msec())
	}

	var contracts: Array = _resolve_save_slice_contracts()
	for raw_contract in contracts:
		if typeof(raw_contract) != TYPE_DICTIONARY:
			continue

		var slice_contract: Dictionary = raw_contract
		if not bool(slice_contract.get("enabled", true)):
			continue

		var row: Dictionary = _export_engine_slice(slice_contract, out)
		if row.is_empty():
			continue

		var save_key: String = str(row.get("save_key", "")).strip_edges()
		if save_key == "":
			continue

		out ["slices"] [save_key] = row
		out ["exported_slices"].append({
			"id": str(row.get("id", save_key)),
			"save_key": save_key,
			"engine_id": str(row.get("engine_id", "")),
			"fallback": bool(row.get("fallback", false))
		})

	var preserved: Dictionary = _collect_preserved_unknown_slices()
	for key in preserved.keys():
		var row_raw: Variant = preserved.get(key, {})
		var row: Dictionary = _normalize_preserved_unknown_row(str(key), row_raw)
		if row.is_empty():
			continue

		var save_key: String = str(row.get("save_key", key)).strip_edges()
		if save_key == "":
			continue

		if not out ["slices"].has(save_key):
			out ["slices"] [save_key] = row

		out ["orphaned_slices"] [save_key] = row

	if gs != null:
		gs.game_state_contract_slices = _make_binary_safe(out)
		if typeof(gs.scenario_state) == TYPE_DICTIONARY:
			gs.scenario_state ["last_serialized_game_state_contract_slices"] = _make_binary_safe(out)

	return _make_binary_safe(out)


func _export_engine_slice(slice_contract: Dictionary, report: Dictionary) -> Dictionary:
	var slice_id: String = str(slice_contract.get("id", slice_contract.get("save_key", ""))).strip_edges()
	var save_key: String = str(slice_contract.get("save_key", slice_id)).strip_edges()
	var engine_id: String = str(slice_contract.get("engine_id", "")).strip_edges()
	var export_method: String = str(slice_contract.get("export_method", "export_state")).strip_edges()
	var required: bool = bool(slice_contract.get("required", false))

	if slice_id == "" or save_key == "":
		return {}

	var fallback_data: Variant = slice_contract.get("fallback_data", {})
	var target = _resolve_engine(engine_id)

	if engine_id == "" or target == null:
		if required:
			report ["failed_slices"].append({
				"id": slice_id,
				"save_key": save_key,
				"engine_id": engine_id,
				"reason": "engine_unavailable"
			})
		else:
			report ["warnings"].append({
				"id": slice_id,
				"save_key": save_key,
				"engine_id": engine_id,
				"reason": "engine_unavailable"
			})

		if _has_fallback_data(fallback_data):
			return _build_slice_row(slice_contract, fallback_data, true, "engine_unavailable")

		return {}

	if export_method == "" or not target.has_method(export_method):
		if required:
			report ["failed_slices"].append({
				"id": slice_id,
				"save_key": save_key,
				"engine_id": engine_id,
				"export_method": export_method,
				"reason": "export_method_unavailable"
			})
		else:
			report ["warnings"].append({
				"id": slice_id,
				"save_key": save_key,
				"engine_id": engine_id,
				"export_method": export_method,
				"reason": "export_method_unavailable"
			})

		if _has_fallback_data(fallback_data):
			return _build_slice_row(slice_contract, fallback_data, true, "export_method_unavailable")

		return {}

	var payload: Variant = target.callv(export_method, [])
	return _build_slice_row(slice_contract, payload, false, "")


func _build_slice_row(slice_contract: Dictionary, payload: Variant, fallback: bool, fallback_reason: String = "") -> Dictionary:
	var slice_id: String = str(slice_contract.get("id", slice_contract.get("save_key", ""))).strip_edges()
	var save_key: String = str(slice_contract.get("save_key", slice_id)).strip_edges()
	var metadata: Dictionary = _safe_dictionary(slice_contract.get("metadata", {}))

	var row: Dictionary = {
		"id": slice_id,
		"save_key": save_key,
		"engine_id": str(slice_contract.get("engine_id", "")).strip_edges(),
		"schema": str(slice_contract.get("schema", "eralife.save_slice")).strip_edges(),
		"version": int(slice_contract.get("version", 1)),
		"min_supported_version": int(slice_contract.get("min_supported_version", 1)),
		"hydration_phase": _phase_for_slice(slice_contract),
		"import_method": str(slice_contract.get("import_method", "import_state")).strip_edges(),
		"export_method": str(slice_contract.get("export_method", "export_state")).strip_edges(),
		"contract_policy": str(slice_contract.get("save_policy", slice_contract.get("policy", "migrate_by_schema"))).strip_edges(),
		"compatibility_mode": str(slice_contract.get("compatibility_mode", "bidirectional")).strip_edges(),
		"preserve_unknown_fields": bool(slice_contract.get("preserve_unknown_fields", true)),
		"stream_on_demand": bool(slice_contract.get("stream_on_demand", false)),
		"migration_hints": {
			"policy": str(slice_contract.get("save_policy", slice_contract.get("policy", "migrate_by_schema"))).strip_edges(),
			"from_version": int(slice_contract.get("version", 1)),
			"min_supported_version": int(slice_contract.get("min_supported_version", 1)),
			"allow_destructive_migrations": bool(slice_contract.get("allow_destructive_migrations", false))
		},
		"metadata": metadata.duplicate(true),
		"data": _make_binary_safe(payload),
		"fallback": fallback,
		"exported_at_ms": int(Time.get_ticks_msec())
	}

	if fallback_reason != "":
		row ["fallback_reason"] = fallback_reason

	return row


func _apply_slice_bundle_to_payload(payload: Dictionary, slice_bundle: Dictionary) -> void:
	if typeof(payload.get("slices", {})) != TYPE_DICTIONARY:
		payload ["slices"] = {}

	var structured_slices: Dictionary = payload ["slices"]
	var slice_rows_raw: Variant = slice_bundle.get("slices", {})
	var slice_rows: Dictionary = slice_rows_raw if typeof(slice_rows_raw) == TYPE_DICTIONARY else {}

	payload ["game_state_contract_slices"] = slice_bundle.duplicate(true)

	for save_key in slice_rows.keys():
		var row_raw: Variant = slice_rows.get(save_key, {})
		if typeof(row_raw) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = row_raw
		var clean_save_key: String = str(row.get("save_key", save_key)).strip_edges()
		if clean_save_key == "":
			continue

		structured_slices [clean_save_key] = row.duplicate(true)
		payload [clean_save_key] = _make_binary_safe(row.get("data", {}))

	payload ["slices"] = structured_slices


func _apply_preserved_unknown_slices_to_payload(payload: Dictionary) -> void:
	var preserved: Dictionary = _collect_preserved_unknown_slices()
	if preserved.is_empty():
		return

	if typeof(payload.get("slices", {})) != TYPE_DICTIONARY:
		payload ["slices"] = {}

	var structured_slices: Dictionary = payload ["slices"]

	for key in preserved.keys():
		var row: Dictionary = _normalize_preserved_unknown_row(str(key), preserved.get(key, {}))
		if row.is_empty():
			continue

		var save_key: String = str(row.get("save_key", key)).strip_edges()
		if save_key == "":
			continue

		if not structured_slices.has(save_key):
			structured_slices [save_key] = row.duplicate(true)

		if not payload.has(save_key):
			payload [save_key] = _make_binary_safe(row.get("data", {}))

	payload ["slices"] = structured_slices
	payload ["preserved_unknown_save_slices"] = preserved.duplicate(true)


func _collect_preserved_unknown_slices() -> Dictionary:
	var out: Dictionary = {}

	if gs == null:
		return out

	if typeof(gs.preserved_unknown_save_slices) == TYPE_DICTIONARY:
		for key in gs.preserved_unknown_save_slices.keys():
			out [str(key)] = gs.preserved_unknown_save_slices.get(key)

	if typeof(gs.scenario_state) == TYPE_DICTIONARY:
		var preserved_raw: Variant = gs.scenario_state.get("preserved_unknown_save_slices", {})
		if typeof(preserved_raw) == TYPE_DICTIONARY:
			for key in (preserved_raw as Dictionary).keys():
				out [str(key)] = (preserved_raw as Dictionary).get(key)

		var orphaned_raw: Variant = gs.scenario_state.get("orphaned_save_slices", {})
		if typeof(orphaned_raw) == TYPE_DICTIONARY:
			for key in (orphaned_raw as Dictionary).keys():
				out [str(key)] = (orphaned_raw as Dictionary).get(key)

	if gs.game_state_contract_engine != null:
		var engine_orphaned_raw: Variant = gs.game_state_contract_engine.get("orphaned_save_slices")
		if typeof(engine_orphaned_raw) == TYPE_DICTIONARY:
			for key in (engine_orphaned_raw as Dictionary).keys():
				out [str(key)] = (engine_orphaned_raw as Dictionary).get(key)

	return out


func _normalize_preserved_unknown_row(fallback_key: String, value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {
			"id": fallback_key,
			"save_key": fallback_key,
			"schema": "eralife.unknown_save_slice",
			"version": 1,
			"min_supported_version": 1,
			"contract_policy": "preserve_unknown_fields",
			"compatibility_mode": "orphaned",
			"preserve_unknown_fields": true,
			"unknown": true,
			"orphaned": true,
			"data": _make_binary_safe(value),
			"exported_at_ms": int(Time.get_ticks_msec())
		}

	var row: Dictionary = value.duplicate(true)
	var save_key: String = str(row.get("save_key", fallback_key)).strip_edges()
	if save_key == "":
		save_key = fallback_key

	if not row.has("data"):
		row ["data"] = row.duplicate(true)

	row ["id"] = str(row.get("id", save_key)).strip_edges()
	row ["save_key"] = save_key
	row ["schema"] = str(row.get("schema", "eralife.unknown_save_slice")).strip_edges()
	row ["version"] = int(row.get("version", 1))
	row ["min_supported_version"] = int(row.get("min_supported_version", 1))
	row ["contract_policy"] = str(row.get("contract_policy", row.get("policy", "preserve_unknown_fields"))).strip_edges()
	row ["compatibility_mode"] = str(row.get("compatibility_mode", "orphaned")).strip_edges()
	row ["preserve_unknown_fields"] = bool(row.get("preserve_unknown_fields", true))
	row ["unknown"] = bool(row.get("unknown", true))
	row ["orphaned"] = bool(row.get("orphaned", true))
	row ["exported_at_ms"] = int(Time.get_ticks_msec())

	return _make_binary_safe(row)


func _build_payload_meta(options: Dictionary, slice_bundle: Dictionary) -> Dictionary:
	var identity_context: Dictionary = options.get("identity_context", {}) if typeof(options.get("identity_context", {})) == TYPE_DICTIONARY else {}
	if identity_context.is_empty() and gs != null and gs.identity_contract_engine != null and gs.identity_contract_engine.has_method("emit_identity_context"):
		identity_context = gs.identity_contract_engine.emit_identity_context({ "source": "serialization_meta"})

	var session_pointer: Dictionary = {}
	if gs != null and gs.session_contract_engine != null and gs.session_contract_engine.has_method("emit_session_context"):
		var session_context: Dictionary = gs.session_contract_engine.emit_session_context({
			"source": "serialization_meta",
			"identity_context": identity_context.duplicate(true)
		})
		session_pointer = session_context.get("session_pointer", {}) if typeof(session_context.get("session_pointer", {})) == TYPE_DICTIONARY else {}

	var meta: Dictionary = {
		"source": str(options.get("source", "save_game")),
		"profile": str(options.get("profile", "full_simulation")),
		"path": str(options.get("path", "")),
		"year": int(gs.year) if gs != null else 0,
		"player_id": int(gs.player_id) if gs != null else -1,
		"save_version": int(gs.save_version) if gs != null else 0,
		"state_id": _active_state_id(),
		"identity_context": identity_context.duplicate(true),
		"session_pointer": session_pointer.duplicate(true),
		"slice_count": _safe_dictionary(slice_bundle.get("slices", {})).size(),
		"unknown_slices_preserved": _collect_preserved_unknown_slices().keys(),
		"created_at_ms": int(Time.get_ticks_msec())
	}
	return meta


func _build_migration_hints(slice_bundle: Dictionary, _options: Dictionary = {}) -> Dictionary:
	var hints: Dictionary = {
		"schema": "eralife.save_migration_hints",
		"version": 1,
		"slice_hints": {},
		"created_at_ms": int(Time.get_ticks_msec())
	}

	var slice_rows: Dictionary = _safe_dictionary(slice_bundle.get("slices", {}))
	for save_key in slice_rows.keys():
		var row_raw: Variant = slice_rows.get(save_key, {})
		if typeof(row_raw) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_raw
		hints ["slice_hints"] [str(save_key)] = {
			"id": str(row.get("id", save_key)),
			"save_key": str(row.get("save_key", save_key)),
			"engine_id": str(row.get("engine_id", "")),
			"version": int(row.get("version", 1)),
			"min_supported_version": int(row.get("min_supported_version", 1)),
			"contract_policy": str(row.get("contract_policy", "migrate_by_schema")),
			"compatibility_mode": str(row.get("compatibility_mode", "bidirectional")),
			"stream_on_demand": bool(row.get("stream_on_demand", false))
		}

	return hints


func _build_save_summary(path: String, payload: Dictionary) -> Dictionary:
	var summary_player_name: String = str(payload.get("player_name", "")).strip_edges()
	if summary_player_name == "":
		summary_player_name = "Unknown Life"

	var meta: Dictionary = payload.get("meta", {}) if typeof(payload.get("meta", {})) == TYPE_DICTIONARY else {}
	var identity_context: Dictionary = meta.get("identity_context", {}) if typeof(meta.get("identity_context", {})) == TYPE_DICTIONARY else {}
	var life_packet: Dictionary = payload.get("life_packet", {}) if typeof(payload.get("life_packet", {})) == TYPE_DICTIONARY else {}

	return {
		"path": path,
		"player_name": summary_player_name,
		"age": int(payload.get("last_saved_age", 0)),
		"year": int(payload.get("year", 0)),
		"era_name": str(payload.get("era_name", "Unknown Era")),
		"player_id": int(payload.get("player_id", -1)),
		"identity_id": str(identity_context.get("identity_id", "")),
		"life_id": str(life_packet.get("life_id", meta.get("life_id", ""))),
		"life_packet_signature": str(life_packet.get("signature", "")),
		"saved_at_unix": int(payload.get("saved_at_unix", Time.get_unix_time_from_system())),
		"schema": str(payload.get("schema", SAVE_SCHEMA)),
		"slice_count": _safe_dictionary(payload.get("slices", {})).size()
	}


func _write_summary_cache(path: String, summary: Dictionary) -> void:
	if gs == null:
		return
	if gs.has_method("_write_saved_life_summary_cache"):
		gs._write_saved_life_summary_cache(path, summary)


func _build_cross_device_checkpoint(
	path: String,
	options: Dictionary
) -> void:
	# DIAGNOSTIC: no SAVE_CHECKPOINT line appears, so this function either is not
	# called or returns before the commit. Report entry and each guard.
	EraLog.truth(
		"ERALIFE_XDEV|entry|gs_null=%s|path=%s|has_commit=%s"
		% [
			str(gs == null),
			str(path),
			str(gs != null and gs.has_method("commit_current_life_checkpoint_contract"))
		]
	)

	if gs == null:
		return

	var clean_path: String = str(
		path
	).strip_edges()

	if clean_path == "":
		return

	var identity_context: Dictionary = (
		options.get(
			"identity_context",
			{}
		)
		if typeof(
			options.get(
				"identity_context",
				{}
			)
		) == TYPE_DICTIONARY
		else {}
	)

	if (
		identity_context.is_empty()
		and gs.identity_contract_engine != null
		and gs.identity_contract_engine.has_method(
			"emit_identity_context"
		)
	):
		identity_context = (
			gs.identity_contract_engine.emit_identity_context({
				"source": "cross_device_checkpoint"
			})
		)

	var checkpoint_commit_report: Dictionary = {}

	if gs.has_method(
		"commit_current_life_checkpoint_contract"
	):
		checkpoint_commit_report = (
			gs.commit_current_life_checkpoint_contract(
				clean_path,
				{},
				{
					"source": (
						"serialization_cross_device_checkpoint"
					),
					"identity_context": (
						identity_context.duplicate(false)
					),
					"scene_route": str(
						options.get(
							"scene_route",
							""
						)
					),
					"current_panel": str(
						options.get(
							"current_panel",
							options.get(
								"scene_route",
								"life"
							)
						)
					),
					"ui_surface": str(
						options.get(
							"ui_surface",
							""
						)
					),
					"checkpoint_first_frame_snapshot": (
						options.get(
							"checkpoint_first_frame_snapshot",
							{}
						)
						if typeof(
							options.get(
								"checkpoint_first_frame_snapshot",
								{}
							)
						) == TYPE_DICTIONARY
						else {}
					),
					"checkpoint_path": clean_path
				}
			)
		)




	# DIAGNOSTIC: the saved .summary cache -- which is the ONLY place the resume
	# contract is stored -- is written only when this commit succeeded. A load with no
	# .summary file falls back to filename metadata (12 keys, no resume contract) and
	# can never reach "ready". Report what the commit returned.
	EraLog.truth(
		"ERALIFE_SAVE_CHECKPOINT|commit_empty=%s|success=%s|reason=%s"
		% [
			str(checkpoint_commit_report.is_empty()),
			str(checkpoint_commit_report.get("success", false)),
			str(checkpoint_commit_report.get("reason", "-"))
		]
	)

	if (
		not checkpoint_commit_report.is_empty()
		and bool(
			checkpoint_commit_report.get(
				"success",
				false
			)
		)
		and gs.has_method(
			"_read_saved_life_summary"
		)
		and gs.has_method(
			"_write_saved_life_summary_cache"
		)
	):
		var summary: Dictionary = (
			gs._read_saved_life_summary(
				clean_path
			)
		)
		var resume_raw: Variant = (
			checkpoint_commit_report.get(
				"checkpoint_resume_contract",
				{}
			)
		)
		var resume_contract: Dictionary = (
			(resume_raw as Dictionary).duplicate(false)
			if typeof(resume_raw) == TYPE_DICTIONARY
			else {}
		)
		var residency_signature: String = str(
			checkpoint_commit_report.get(
				"residency_signature",
				resume_contract.get(
					"residency_signature",
					""
				)
			)
		).strip_edges()
		var controlled_actor_id: int = int(
			checkpoint_commit_report.get(
				"controlled_actor_id",
				checkpoint_commit_report.get(
					"actor_id",
					resume_contract.get(
						"controlled_actor_id",
						resume_contract.get(
							"actor_id",
							-1
						)
					)
				)
			)
		)
		var current_panel: String = str(
			checkpoint_commit_report.get(
				"current_panel",
				resume_contract.get(
					"current_panel",
					"life"
				)
			)
		).strip_edges().to_lower()

		if current_panel == "":
			current_panel = "life"

		summary ["path"] = clean_path
		summary ["residency_signature"] = (
			residency_signature
		)
		summary ["checkpoint_resume_contract"] = (
			resume_contract
		)
		summary ["actor_id"] = controlled_actor_id
		summary ["controlled_actor_id"] = (
			controlled_actor_id
		)
		summary ["current_panel"] = current_panel
		summary ["life_id"] = str(
			checkpoint_commit_report.get(
				"life_id",
				resume_contract.get(
					"life_id",
					summary.get(
						"life_id",
						""
					)
				)
			)
		)
		summary ["branch_id"] = str(
			checkpoint_commit_report.get(
				"branch_id",
				resume_contract.get(
					"branch_id",
					"main"
				)
			)
		)
		summary ["resume_capsule_available"] = (
			not resume_contract.is_empty()
		)
		summary [
			"binary_decode_required_before_first_frame"
		] = false
		summary [
			"checkpoint_summary_schema"
		] = "eralife.saved_life.resume_summary"
		summary [
			"checkpoint_summary_version"
		] = 2

		gs._write_saved_life_summary_cache(
			clean_path,
			summary
		)

		EraLog.truth(
			"ERALIFE_SAVE_SUMMARY|path=%s|keys=%d|has_resume=%s|cache_written=%s"
			% [
				clean_path,
				summary.size(),
				str(summary.has("checkpoint_resume_contract")),
				str(FileAccess.file_exists("%s.summary" % clean_path))
			]
		)

	if gs.game_state_contract_engine == null:
		return

	if not gs.game_state_contract_engine.has_method(
		"build_cross_device_continuity_checkpoint"
	):
		return

	var continuity_checkpoint: Dictionary = (
		gs.game_state_contract_engine
		.build_cross_device_continuity_checkpoint(
			"",
			{
				"source": "save_game",
				"save_path": clean_path,
				"identity_context": (
					identity_context.duplicate(false)
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
				"skip_portable_capsule": bool(
					options.get(
						"skip_continuity_capsule",
						true
					)
				)
			}
		)
	)

	if typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state [
			"last_cross_device_continuity_checkpoint"
		] = continuity_checkpoint.duplicate(false)
		gs.scenario_state [
			"last_cross_device_checkpoint_commit_report"
		] = checkpoint_commit_report.duplicate(false)
		gs.scenario_state [
			"checkpoint_resume_summary_written"
		] = bool(
			checkpoint_commit_report.get(
				"success",
				false
			)
		)

func _build_life_packet_for_payload(payload: Dictionary, options: Dictionary = {}) -> Dictionary:
	var meta: Dictionary = payload.get("meta", {}) if typeof(payload.get("meta", {})) == TYPE_DICTIONARY else {}
	var identity_context: Dictionary = meta.get("identity_context", {}) if typeof(meta.get("identity_context", {})) == TYPE_DICTIONARY else {}
	var life_id: String = str(options.get("life_id", "")).strip_edges()
	if life_id == "" and gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		life_id = str(gs.scenario_state.get("life_id", "")).strip_edges()
	if life_id == "":
		life_id = "life_%s_%d" % [str(identity_context.get("identity_id", "local")), int(Time.get_unix_time_from_system())]
		if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
			gs.scenario_state ["life_id"] = life_id

	var packet: Dictionary = {
		"schema": "eralife.life_packet",
		"version": 1,
		"identity_id": str(identity_context.get("identity_id", "")),
		"owner_identity_id": str(identity_context.get("identity_id", "")),
		"life_id": life_id,
		"origin_id": str(options.get("origin_id", life_id)),
		"fork_id": str(options.get("fork_id", "")),
		"checkpoint_snapshot": {
			"year": int(payload.get("year", 0)),
			"age": int(payload.get("last_saved_age", 0)),
			"player_id": int(payload.get("player_id", -1)),
			"save_path": str(options.get("path", ""))
		},
		"event_stream": [],
		"relationship_graph": payload.get("relationship_graph_contract_engine_state", {}),
		"world_state_refs": {
			"world_seed": int(payload.get("world_seed", 0)),
			"era_name": str(payload.get("era_name", "")),
			"slice_count": _safe_dictionary(payload.get("slices", {})).size()
		},
		"sharing": {
			"forkable": true,
		},
		"created_at_ms": int(Time.get_ticks_msec())
	}
	packet ["signature"] = _life_packet_signature(packet)
	return packet

func _life_packet_signature(packet: Dictionary) -> String:
	var unsigned: Dictionary = packet.duplicate(true)
	unsigned.erase("signature")
	return "lp_%d" % abs(int(hash(JSON.stringify(unsigned))))


func _resolve_save_slice_contracts() -> Array:
	var out: Array = []

	if gs != null and gs.game_state_contract_engine != null:
		var registry_raw: Variant = gs.game_state_contract_engine.get("save_slice_registry")
		if typeof(registry_raw) == TYPE_DICTIONARY:
			for key in (registry_raw as Dictionary).keys():
				var raw_contract: Variant = (registry_raw as Dictionary).get(key, {})
				if typeof(raw_contract) == TYPE_DICTIONARY:
					out.append((raw_contract as Dictionary).duplicate(true))
		elif typeof(registry_raw) == TYPE_ARRAY:
			for raw in registry_raw:
				if typeof(raw) == TYPE_DICTIONARY:
					out.append((raw as Dictionary).duplicate(true))

		if out.is_empty() and gs.game_state_contract_engine.has_method("export_registry"):
			var exported: Variant = gs.game_state_contract_engine.export_registry()
			if typeof(exported) == TYPE_DICTIONARY:
				out = _extract_save_slices_from_registry(exported as Dictionary)

	if out.is_empty():
		out = _fallback_legacy_save_slice_contracts()

	var has_life_diary_slice: bool = false
	for raw_slice in out:
		if typeof(raw_slice) != TYPE_DICTIONARY:
			continue
		var slice_contract: Dictionary = raw_slice as Dictionary
		if str(slice_contract.get("id", "")) == "life_diary_contract_engine_state" \
or str(slice_contract.get("engine_id", "")) == "life_diary_contract_engine":
			has_life_diary_slice = true
			break

	if not has_life_diary_slice and gs != null and gs.life_diary_contract_engine != null:
		if gs.life_diary_contract_engine.has_method("save_slice_contract"):
			out.append(gs.life_diary_contract_engine.save_slice_contract())
		else:
			out.append({
				"id": "life_diary_contract_engine_state",
				"save_key": "life_diary_contract_engine_state",
				"engine_id": "life_diary_contract_engine",
				"import_method": "import_state",
				"export_method": "export_state",
				"hydration_phase": PHASE_SYSTEM_STATE,
				"required": false,
				"missing_engine_policy": "recover"
			})

	return out


func _extract_save_slices_from_registry(registry: Dictionary) -> Array:
	var out: Array = []

	for key in ["save_slice_registry", "save_slices"]:
		var raw: Variant = registry.get(key, null)
		if typeof(raw) == TYPE_DICTIONARY:
			for slice_key in (raw as Dictionary).keys():
				var slice_contract: Variant = (raw as Dictionary).get(slice_key, {})
				if typeof(slice_contract) == TYPE_DICTIONARY:
					out.append((slice_contract as Dictionary).duplicate(true))
		elif typeof(raw) == TYPE_ARRAY:
			for slice_contract in raw:
				if typeof(slice_contract) == TYPE_DICTIONARY:
					out.append((slice_contract as Dictionary).duplicate(true))

	var active_contract_raw: Variant = registry.get("active_save_contract", registry.get("kernel_contract", {}))
	if typeof(active_contract_raw) == TYPE_DICTIONARY:
		var active_contract: Dictionary = active_contract_raw
		var active_slices: Variant = active_contract.get("save_slices", [])
		if typeof(active_slices) == TYPE_ARRAY:
			for slice_contract in active_slices:
				if typeof(slice_contract) == TYPE_DICTIONARY:
					out.append((slice_contract as Dictionary).duplicate(true))

	return out


func _fallback_legacy_save_slice_contracts() -> Array:
	return [
		{ "id": "realm_contract_registry", "save_key": "realm_contract_registry", "engine_id": "realm_contract_engine", "import_method": "import_registry", "export_method": "export_registry", "hydration_phase": PHASE_STRUCTURAL_SYSTEMS},
		{ "id": "simulation_contract_registry", "save_key": "simulation_contract_registry", "engine_id": "simulation_contract_engine", "import_method": "import_registry", "export_method": "export_registry", "hydration_phase": PHASE_STRUCTURAL_SYSTEMS},
		{ "id": "ui_contract_registry", "save_key": "ui_contract_registry", "engine_id": "ui_contract_engine", "import_method": "import_registry", "hydration_phase": PHASE_STRUCTURAL_SYSTEMS},
		{ "id": "perceptual_integrity_engine_state", "save_key": "perceptual_integrity_engine_state", "engine_id": "perceptual_integrity_engine", "import_method": "import_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "world_engine_contract_registry", "save_key": "world_engine_contract_registry", "engine_id": "world_engine", "import_method": "import_registry", "export_method": "export_registry", "hydration_phase": PHASE_STRUCTURAL_SYSTEMS},
		{ "id": "life_engine_contract_registry", "save_key": "life_engine_contract_registry", "engine_id": "life_engine", "import_method": "import_registry", "export_method": "export_registry", "hydration_phase": PHASE_STRUCTURAL_SYSTEMS},
		{
			"id": "royalty_runtime_engine_state",
			"save_key": "royalty_runtime_engine_state",
			"engine_id": "royalty_runtime_engine",
			"export_method": "export_state",
			"import_method": "import_state",
			"schema": "eralife.royalty_runtime_engine_state",
			"version": 1,
			"min_supported_version": 1,
			"persistent": true,
			"metadata": {
				"hydration_lane": "core",
				"preserve_unknown_fields": true,
				"backwards_compatible": true,
				"legacy_repair_source": [
					"person_royal_fields",
					"realm_ruler_id",
					"dynasty_origin"
				]
			},
			"migration_rules": [
				{
					"action": "ensure_dictionary",
					"path": "state"
				},
				{
					"action": "ensure_dictionary",
					"path": "state.institutions"
				},
				{
					"action": "ensure_dictionary",
					"path": "state.houses"
				},
				{
					"action": "ensure_dictionary",
					"path": "state.person_index"
				},
				{
					"action": "ensure_array",
					"path": "state.event_history"
				}
			]
		},
		{
			"id": "royalty_contract_engine_state",
			"save_key": "royalty_contract_engine_state",
			"engine_id": "royalty_contract_engine",
			"export_method": "export_state",
			"import_method": "import_state",
			"schema": "eralife.royalty_contract_engine_state",
			"version": 1,
			"min_supported_version": 1,
			"persistent": true,
			"metadata": {
				"hydration_lane": "core",
				"preserve_unknown_fields": true,
				"backwards_compatible": true,
			},
			"migration_rules": [
				{
					"action": "ensure_dictionary",
					"path": "constitutional_contract_registry"
				},
				{
					"action": "ensure_dictionary",
					"path": "realm_contract_index"
				}
			]
		},
		{
			"id": "royalty_mod_contract_engine_state",
			"save_key": "royalty_mod_contract_engine_state",
			"engine_id": "royalty_mod_contract_engine",
			"export_method": "export_state",
			"import_method": "import_state",
			"schema": "eralife.royalty_mod_contract_engine_state",
			"version": 1,
			"min_supported_version": 1,
			"persistent": true,
			"metadata": {
				"hydration_lane": "extensions",
				"preserve_unknown_fields": true,
				"backwards_compatible": true,
			},
			"migration_rules": [
				{
					"action": "ensure_dictionary",
					"path": "provider_cache"
				},
				{
					"action": "ensure_dictionary",
					"path": "provider_validation_registry"
				}
			]
		},
		{
			"id": "crown_hub_contract_engine_state",
			"save_key": "crown_hub_contract_engine_state",
			"engine_id": "crown_hub_contract_engine",
			"export_method": "export_state",
			"import_method": "import_state",
			"schema": "eralife.crown_hub_contract_engine_state",
			"version": 1,
			"min_supported_version": 1,
			"persistent": true,
			"metadata": {
				"hydration_lane": "ui_lens",
				"preserve_unknown_fields": true,
				"backwards_compatible": true
			},
			"migration_rules": [
				{
					"action": "ensure_dictionary",
					"path": "lens_state"
				}
			]
		},
		{
			"id": "mod_bundle_contract_engine_state",
			"save_key": "mod_bundle_contract_engine_state",
			"engine_id": "mod_bundle_contract_engine",
			"export_method": "export_state",
			"import_method": "import_state",
			"schema": "eralife.mod_bundle_contract_engine.state",
			"version": 1,
			"min_supported_version": 1,
			"persistent": true,
			"metadata": {
				"hydration_lane": "extensions",
				"preserve_unknown_fields": true,
			},
			"migration_rules": [
				{
					"action": "ensure_dictionary",
					"path": "bundle_state_registry"
				}
			]
		},
		{
			"id": "caveman_reality_runtime_engine_state",
			"save_key": "caveman_reality_runtime_engine_state",
			"engine_id": "caveman_reality_runtime_engine",
			"export_method": "export_state",
			"import_method": "import_state",
			"schema": "eralife.caveman_reality_runtime_engine.state",
			"version": 1,
			"min_supported_version": 1,
			"persistent": true,
			"required": true,
			"metadata": {
				"hydration_lane": "extensions",
				"bundle_id": "eralife.caveman_reality_pack",
				"identity_safe": true,
				"preserve_unknown_fields": true
			},
			"migration_rules": [
				{
					"action": "ensure_dictionary",
					"path": "state.actor_profiles"
				},
				{
					"action": "ensure_dictionary",
					"path": "state.tribes"
				},
				{
					"action": "ensure_dictionary",
					"path": "state.actor_tribe_index"
				},
				{
					"action": "ensure_dictionary",
					"path": "state.settings"
				},
				{
					"action": "ensure_array",
					"path": "state.selected_component_ids"
				},
				{
					"action": "ensure_array",
					"path": "state.active_component_ids"
				},
				{
					"action": "ensure_array",
					"path": "state.activity_history"
				}
			]
		},
		{
			"id": "era_contract_engine_state",
			"save_key": "era_contract_engine_state",
			"engine_id": "era_contract_engine",
			"export_method": "export_state",
			"import_method": "import_state",
			"schema": "eralife.era_contract_engine.state",
			"version": 1,
			"min_supported_version": 1,
			"persistent": true,
			"metadata": {
				"hydration_lane": "world",
				"effective_era_contract": true,
				"preserve_unknown_fields": true
			}
		},
		{
			"id": "era_mod_contract_engine_state",
			"save_key": "era_mod_contract_engine_state",
			"engine_id": "era_mod_contract_engine",
			"export_method": "export_state",
			"import_method": "import_state",
			"schema": "eralife.era_mod_contract_engine.state",
			"version": 1,
			"min_supported_version": 1,
			"persistent": true,
			"metadata": {
				"hydration_lane": "extensions",
				"preserve_unknown_fields": true
			}
		},
		{ "id": "universal_faction_state", "save_key": "universal_faction_state", "engine_id": "universal_faction_engine", "import_method": "import_state", "export_method": "export_state", "hydration_phase": PHASE_STRUCTURAL_SYSTEMS},
		{ "id": "geo_engine_state", "save_key": "geo_engine_state", "engine_id": "geo_engine", "import_method": "import_state", "export_method": "export_state", "hydration_phase": PHASE_STRUCTURAL_SYSTEMS},
		{ "id": "food_engine_state", "save_key": "food_engine_state", "engine_id": "food_engine", "import_method": "import_state", "export_method": "export_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "food_restaurant_engine_state", "save_key": "food_restaurant_engine_state", "engine_id": "food_restaurant_engine", "import_method": "import_state", "export_method": "export_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "grocery_store_engine_state", "save_key": "grocery_store_engine_state", "engine_id": "grocery_store_engine", "import_method": "import_state", "export_method": "export_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "runtime_contract_engine_state", "save_key": "runtime_contract_engine_state", "engine_id": "runtime_contract_engine", "import_method": "import_state", "export_method": "export_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "shared_public_space_engine_state", "save_key": "shared_public_space_engine_state", "engine_id": "shared_public_space_engine", "import_method": "import_state", "export_method": "export_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "genetics_inheritance_engine_state", "save_key": "genetics_inheritance_engine_state", "engine_id": "genetics_inheritance_engine", "import_method": "import_state", "export_method": "export_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "body_type_contract_engine_state", "save_key": "body_type_contract_engine_state", "engine_id": "body_type_contract_engine", "import_method": "import_state", "export_method": "export_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "growth_curve_engine_state", "save_key": "growth_curve_engine_state", "engine_id": "growth_curve_engine", "import_method": "import_state", "export_method": "export_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "height_contract_engine_state", "save_key": "height_contract_engine_state", "engine_id": "height_contract_engine", "import_method": "import_state", "export_method": "export_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "weight_contract_engine_state", "save_key": "weight_contract_engine_state", "engine_id": "weight_contract_engine", "import_method": "import_state", "export_method": "export_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "movie_theater_engine_state", "save_key": "movie_theater_engine_state", "engine_id": "movie_theater_engine", "import_method": "import_state", "export_method": "export_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "luxury_shop_engine_state", "save_key": "luxury_shop_engine_state", "engine_id": "luxury_shop_engine", "import_method": "import_state", "export_method": "export_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "bank_engine_state", "save_key": "bank_engine_state", "engine_id": "bank_engine", "import_method": "import_state", "export_method": "export_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "scenario_popup_contract_engine_state", "save_key": "scenario_popup_contract_engine_state", "engine_id": "scenario_popup_contract_engine", "import_method": "import_state", "export_method": "export_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "scenario_runtime_contract_engine_state", "save_key": "scenario_runtime_contract_engine_state", "engine_id": "scenario_runtime_contract_engine", "import_method": "import_state", "export_method": "export_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "pending_situations_engine_state", "save_key": "pending_situations_engine_state", "engine_id": "pending_situations_engine", "import_method": "import_state", "export_method": "export_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "live_person_editor_engine_state", "save_key": "live_person_editor_engine_state", "engine_id": "live_person_editor_engine", "import_method": "import_state", "export_method": "export_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "contract_view_layer_contract_engine_state", "save_key": "contract_view_layer_contract_engine_state", "engine_id": "contract_view_layer_contract_engine", "import_method": "import_state", "export_method": "export_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "traits_contract_engine_state", "save_key": "traits_contract_engine_state", "engine_id": "traits_contract_engine", "import_method": "import_state", "export_method": "export_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "identity_contract_engine_state", "save_key": "identity_contract_engine_state", "engine_id": "identity_contract_engine", "import_method": "import_state", "export_method": "export_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "universal_switch_contract_engine_state", "save_key": "universal_switch_contract_engine_state", "engine_id": "universal_switch_contract_engine", "import_method": "import_state", "export_method": "export_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "consciousness_engine_state", "save_key": "consciousness_engine_state", "engine_id": "consciousness_engine", "import_method": "import_state", "export_method": "export_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "power_engine_state", "save_key": "power_engine_state", "engine_id": "power_engine", "import_method": "import_state", "export_method": "export_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "superhero_engine_state", "save_key": "superhero_engine_state", "engine_id": "superhero_engine", "import_method": "import_state", "export_method": "export_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "infamy_engine_state", "save_key": "infamy_engine_state", "engine_id": "infamy_engine", "import_method": "import_state", "export_method": "export_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "crime_contract_engine_state", "save_key": "crime_contract_engine_state", "engine_id": "crime_contract_engine", "import_method": "import_state", "export_method": "export_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "investigation_layer_state", "save_key": "investigation_layer_state", "engine_id": "investigation_layer", "import_method": "import_state", "export_method": "export_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "justice_system_engine_state", "save_key": "justice_system_engine_state", "engine_id": "justice_system_engine", "import_method": "import_state", "export_method": "export_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "jail_engine_state", "save_key": "jail_engine_state", "engine_id": "jail_engine", "import_method": "import_state", "export_method": "export_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "prison_engine_state", "save_key": "prison_engine_state", "engine_id": "prison_engine", "import_method": "import_state", "export_method": "export_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "case_orchestrator_state", "save_key": "case_orchestrator_state", "engine_id": "case_orchestrator", "import_method": "import_state", "export_method": "export_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "belongings_engine_state", "save_key": "belongings_engine_state", "engine_id": "belongings_engine", "import_method": "import_state", "export_method": "export_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "boxing_opponent_pool_engine_state", "save_key": "boxing_opponent_pool_engine_state", "engine_id": "boxing_opponent_pool_engine", "import_method": "import_state", "export_method": "export_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "boxing_combat_resolution_engine_state", "save_key": "boxing_combat_resolution_engine_state", "engine_id": "boxing_combat_resolution_engine", "import_method": "import_state", "export_method": "export_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "boxing_fight_economy_engine_state", "save_key": "boxing_fight_economy_engine_state", "engine_id": "boxing_fight_economy_engine", "import_method": "import_state", "export_method": "export_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "boxing_title_engine_state", "save_key": "boxing_title_engine_state", "engine_id": "boxing_title_engine", "import_method": "import_state", "export_method": "export_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "boxing_amateur_engine_state", "save_key": "boxing_amateur_engine_state", "engine_id": "boxing_amateur_engine", "import_method": "import_state", "export_method": "export_state", "hydration_phase": PHASE_SYSTEM_STATE},
		{ "id": "boxing_media_engine_state", "save_key": "boxing_media_engine_state", "engine_id": "boxing_media_engine", "import_method": "import_state", "export_method": "export_state", "hydration_phase": PHASE_SYSTEM_STATE}
	]


func _phase_for_slice(slice_contract: Dictionary) -> String:
	var explicit_phase: String = str(slice_contract.get("hydration_phase", "")).strip_edges()
	if explicit_phase in PHASE_ORDER:
		return explicit_phase

	var metadata: Dictionary = _safe_dictionary(slice_contract.get("metadata", {}))
	var metadata_phase: String = str(metadata.get("hydration_phase", metadata.get("phase", ""))).strip_edges()
	if metadata_phase in PHASE_ORDER:
		return metadata_phase

	var lane: String = str(metadata.get("hydration_lane", slice_contract.get("hydration_lane", ""))).strip_edges().to_lower()
	match lane:
		"identity", "core_identity":
			return PHASE_CORE_IDENTITY
		"structural", "structure", "realm", "world", "faction":
			return PHASE_STRUCTURAL_SYSTEMS
		"entity", "entities", "npc", "relationship":
			return PHASE_ENTITY_GRAPH
		"system", "runtime", "core":
			return PHASE_SYSTEM_STATE
		"derived", "cache":
			return PHASE_DERIVED_SYSTEMS
		"final", "finalization":
			return PHASE_FINALIZATION
		_:
			return PHASE_SYSTEM_STATE


func _resolve_engine(engine_id: String) -> Variant:
	if gs == null:
		return null

	var clean: String = str(engine_id).strip_edges()
	if clean == "":
		return null

	var value: Variant = gs.get(clean)
	if value != null:
		return value

	if typeof(gs.contract_runtime_engines) == TYPE_DICTIONARY and gs.contract_runtime_engines.has(clean):
		return gs.contract_runtime_engines.get(clean)

	return null


func _engine_export_state(engine: Variant) -> Variant:
	if engine == null:
		return {}
	if engine.has_method("export_state"):
		return _make_binary_safe(engine.call("export_state"))
	return {}


func _engine_field(engine: Variant, field_name: String, fallback: Variant) -> Variant:
	if engine == null:
		return _make_binary_safe(fallback)

	var value: Variant = engine.get(field_name)
	if value == null:
		return _make_binary_safe(fallback)

	return _make_binary_safe(value)


func _era_name() -> String:
	if gs == null:
		return "Unknown Era"

	if gs.era == null:
		return "Unknown Era"

	if typeof(gs.era) == TYPE_DICTIONARY:
		return str((gs.era as Dictionary).get("name", (gs.era as Dictionary).get("era_name", "Unknown Era")))

	if "name" in gs.era:
		return str(gs.era.name)

	return "Unknown Era"


func _active_state_id() -> String:
	if gs == null or gs.game_state_contract_engine == null:
		return ""

	var raw: Variant = gs.game_state_contract_engine.get("active_state_id")
	return str(raw).strip_edges()


func _has_fallback_data(value: Variant) -> bool:
	match typeof(value):
		TYPE_DICTIONARY:
			return not (value as Dictionary).is_empty()
		TYPE_ARRAY:
			return not (value as Array).is_empty()
		TYPE_NIL:
			return false
		_:
			return true


func _store_last_report(report: Dictionary) -> void:
	last_serialization_report = _make_binary_safe(report)
	last_serialization_report.erase("payload")

	if gs == null:
		return

	gs.game_state_serialization_report = last_serialization_report.duplicate(true)

	if typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["game_state_serialization_report"] = last_serialization_report.duplicate(true)
		gs.scenario_state ["last_game_state_serialization_report"] = last_serialization_report.duplicate(true)


func _fail_report(reason_id: String, reason: String, extra: Dictionary = {}) -> Dictionary:
	var report: Dictionary = {
		"schema": "eralife.game_state_serialization_report",
		"version": SERIALIZATION_RUNTIME_VERSION,
		"success": false,
		"reason_id": reason_id,
		"reason": reason,
		"created_at_ms": int(Time.get_ticks_msec())
	}

	for key in extra.keys():
		report [key] = extra [key]

	_store_last_report(report)
	return report.duplicate(true)


func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


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