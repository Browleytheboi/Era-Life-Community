

extends RefCounted
class_name ModBundleContractEngine

const ENGINE_SCHEMA:= "eralife.mod_bundle_contract_engine"
const ENGINE_VERSION:= 1
const BUNDLE_SCHEMA:= "eralife.mod_bundle_contract"
const BUNDLE_VERSION:= 1
const STATE_KEY:= "mod_bundle_contract_state"

var gs
var bundle_registry: Dictionary = {}
var bundle_state_registry: Dictionary = {}
var prepared_toggle_registry: Dictionary = {}
var bundle_service_registry: Dictionary = {}
var registry_revision: int = 0
var last_report: Dictionary = {}


func _init(
	_gs = null
) -> void:
	gs = _gs
	_ensure_state_shape()


func bootstrap_default_contracts() -> Dictionary:
	register_bundle_service(
		"caveman_reality",
		"caveman_reality_runtime_engine",
		[
			"perform_activity",
			"assign_role",
			"emit_bundle_menu_contract",
			"emit_reality_surface_contract"
		]
	)

	var registration: Dictionary = (
		register_bundle_contract(
			CavemanRealityBundlePack.bundle_contract(),
			{
				"source": (
					"mod_bundle_contract_engine."
					+ "bootstrap_default_contracts"
				),
				"register_root_mod": false
			}
		)
	)









	call_deferred(
		"queue_resident_bundle_admission",
		{
			"source": (
				"mod_bundle_contract_engine."
				+ "bootstrap_default_contracts."
				+ "background_catalog_admission"
			),
			"observation_required": false
		}
	)

	return {
		"success": bool(
			registration.get(
				"success",
				false
			)
		),
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"bundle_count": bundle_registry.size(),
		"registration": registration,
		"provider_topology_authoring_owned_by": (
			"mod_bundle_contract_engine."
			+ "resident_bundle_admission_service"
		),
		"ui_is_renderer_only": true
	}

func reality_surface_contract(
		bundle_id: String,
		actor: Person,
		context: Dictionary = {}
) -> Dictionary:
	var clean_bundle_id: String = _id(
		bundle_id
	)
	var bundle_state: Dictionary = _bundle_state(
		clean_bundle_id
	)
	var enabled: bool = bool(
		bundle_state.get(
			"enabled",
			false
		)
	)

	if (
		clean_bundle_id
		== CavemanRealityBundlePack.BUNDLE_ID
		and enabled
		and gs != null
		and gs.caveman_reality_runtime_engine != null
	):
		return (
			gs.caveman_reality_runtime_engine
			.emit_reality_surface_contract(
				actor,
				context
			)
		)




	return {
		"success": true,
		"schema": "eralife.reality_surface_lens_reset",
		"version": 1,
		"bundle_id": clean_bundle_id,
		"enabled": false,
		"actor_id": (
			int(actor.id)
			if actor != null
			else -1
		),
		"presentation": {},
		"world_taxonomy": {},
		"effective_era": {},
		"display_calendar": {},
		"location_projection": {},
		"birth_intro_projection": {},
		"activities_contract": {},
		"world_browser_entries": [],
		"property_projection": {},
		"replace_base_activity_catalog": false,
		"surface_revision": (
			"base_lens_reset:%d:%d"
			% [
				int(
					actor.id
					if actor != null
					else -1
				),
				registry_revision
			]
		),
		"ui_is_renderer_only": true,
		"source": str(
			context.get(
				"source",
				"mod_bundle_contract_engine.reality_surface_contract"
			)
		)
	}
func register_bundle_service(
	service_id: String,
	engine_property: String,
	allowed_methods: Array
) -> Dictionary:
	var clean_service_id: String = _id(
		service_id
	)
	var clean_property: String = str(
		engine_property
	).strip_edges()

	if (
		clean_service_id == ""
		or clean_property == ""
	):
		return _failure(
			"invalid_bundle_service",
			(
				"A bundle service requires a stable "
				+ "id and engine property."
			)
		)

	bundle_service_registry [clean_service_id] = {
		"service_id": clean_service_id,
		"engine_property": clean_property,
		"allowed_methods": (
			_string_array(allowed_methods)
		),
	}

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"service_id": clean_service_id
	}


func register_bundle_contract(
	bundle_contract: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	var normalized: Dictionary = (
		_normalize_bundle_contract(
			bundle_contract
		)
	)
	var validation: Dictionary = (
		validate_bundle_contract(
			normalized
		)
	)

	if not bool(
		validation.get(
			"valid",
			false
		)
	):
		return {
			"success": false,
			"schema": ENGINE_SCHEMA,
			"version": ENGINE_VERSION,
			"reason": "invalid_bundle_contract",
			"validation": validation
		}

	var bundle_id: String = str(
		normalized.get(
			"bundle_id",
			""
		)
	)
	bundle_registry [bundle_id] = (
		normalized.duplicate(true)
	)

	var existing_state: Dictionary = _dict(
		bundle_state_registry.get(
			bundle_id,
			{}
		)
	)

	if existing_state.is_empty():
		existing_state = _default_bundle_state(
			normalized
		)

	bundle_state_registry [bundle_id] = existing_state
	registry_revision += 1

	var root_registration: Dictionary = {}

	if bool(
		context.get(
			"register_root_mod",
			false
		)
	):
		root_registration = _register_bundle_root_mod(
			bundle_id,
			{
				"source": str(
					context.get(
						"source",
						"register_bundle_contract"
					)
				),
				"preserve_enabled_state": true
			}
		)

	_publish_state()

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"bundle_id": bundle_id,
		"root_registration": root_registration,
		"validation": validation,
		"registry_revision": registry_revision
	}


func validate_bundle_contract(
	bundle_contract: Dictionary
) -> Dictionary:
	var errors: Array = []
	var warnings: Array = []
	var bundle_id: String = str(
		bundle_contract.get(
			"bundle_id",
			""
		)
	).strip_edges()
	var root_mod_id: String = str(
		bundle_contract.get(
			"root_mod_id",
			""
		)
	).strip_edges()

	if bundle_id == "":
		errors.append(
			"An installable reality bundle requires bundle_id."
		)

	if root_mod_id == "":
		errors.append(
			"An installable reality bundle requires root_mod_id."
		)

	if typeof(
		bundle_contract.get(
			"components",
			{}
		)
	) != TYPE_DICTIONARY:
		errors.append(
			"Bundle components must be a Dictionary."
		)

	if typeof(
		bundle_contract.get(
			"experience_contract",
			{}
		)
	) != TYPE_DICTIONARY:
		errors.append(
			"Bundle requires an experience_contract."
		)

	if typeof(
		bundle_contract.get(
			"bundle_menu_contract",
			{}
		)
	) != TYPE_DICTIONARY:
		warnings.append(
			(
				"Bundle does not expose a "
				+ "bundle-specific menu contract."
			)
		)

	var component_order: Array = _array(
		bundle_contract.get(
			"component_order",
			[]
		)
	)
	var components: Dictionary = _dict(
		bundle_contract.get(
			"components",
			{}
		)
	)

	for raw_component_id in component_order:
		var component_id: String = str(
			raw_component_id
		)

		if not components.has(component_id):
			errors.append(
				(
					"Bundle component_order references "
					+ "missing component '%s'."
				) % component_id
			)

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
		"bundle_id": bundle_id,
		"root_mod_id": root_mod_id
	}


func install_bundle(
		bundle_id: String,
		context: Dictionary = {}
) -> Dictionary:
	var clean_bundle_id: String = _id(
		bundle_id
	)
	var bundle: Dictionary = _bundle(
		clean_bundle_id
	)

	if bundle.is_empty():
		return _failure(
			"unknown_bundle",
			"That reality bundle is not registered."
		)

	if _law() == null:
		return _failure(
			"missing_mod_law",
			"ModContractEngine is unavailable."
		)

	var root_mod_id: String = _id(
		str(
			bundle.get(
				"root_mod_id",
				""
			)
		)
	)

	if not _law().mod_registry.has(root_mod_id):
		return _failure(
			"bundle_residency_contract_missing",
			(
				"This reality bundle has not finished resident "
				+ "catalog admission. Installation may not perform "
				+ "provider registration."
			)
		)

	var component_ids: Array = _array(
		context.get(
			"component_ids",
			bundle.get(
				"all_in_one_component_ids",
				bundle.get(
					"component_order",
					[]
				)
			)
		)
	)
	var selected_components: Array = (
		_valid_component_ids(
			bundle,
			component_ids
		)
	)

	var resident_root_raw: Variant = (
		_law().mod_registry.get(
			root_mod_id,
			{}
		)
	)
	var resident_root: Dictionary = (
		resident_root_raw as Dictionary
		if typeof(resident_root_raw) == TYPE_DICTIONARY
		else {}
	)
	var resident_components: Array = _array(
		resident_root.get(
			"bundle_component_ids",
			[]
		)
	)

	if resident_components != selected_components:
		return _failure(
			"bundle_component_variant_not_resident",
			(
				"That component combination is not a resident "
				+ "prepared bundle variant. Installation may not "
				+ "compile a new provider topology."
			)
		)

	var topology_revision: int = int(
		_law().provider_topology_revision
	)
	var enabled_key: String = _prepared_toggle_key(
		clean_bundle_id,
		true,
		topology_revision
	)
	var disabled_key: String = _prepared_toggle_key(
		clean_bundle_id,
		false,
		topology_revision
	)

	if (
		not prepared_toggle_registry.has(enabled_key)
		or not prepared_toggle_registry.has(disabled_key)
	):
		return _failure(
			"bundle_toggle_residency_missing",
			(
				"The bundle's enabled and disabled snapshots "
				+ "must both be resident before installation."
			)
		)

	var state: Dictionary = _bundle_state(
		clean_bundle_id
	)
	state ["installed"] = true
	state ["selected_component_ids"] = (
		selected_components
	)
	state ["last_install_source"] = str(
		context.get(
			"source",
			"mod_bundle_contract_engine.install_bundle"
		)
	)
	state ["installed_at_ms"] = int(
		Time.get_ticks_msec()
	)
	bundle_state_registry [clean_bundle_id] = state

	var enable_after_install: bool = bool(
		context.get(
			"enable_after_install",
			true
		)
	)
	var transition: Dictionary = {}

	if enable_after_install:
		transition = set_bundle_enabled(
			clean_bundle_id,
			true,
			{
				"source": str(
					context.get(
						"source",
						"install_bundle"
					)
				)
			}
		)

	_publish_bundle_state_row(
		clean_bundle_id,
		{
			"source": "install_bundle",
			"installed": true
		}
	)

	return {
		"success": (
			not enable_after_install
			or bool(
				transition.get(
					"success",
					false
				)
			)
		),
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"type": "reality_bundle_installed",
		"bundle_id": clean_bundle_id,
		"component_ids": selected_components,
		"root_registration": {
			"success": true,
		},
		"enabled_prewarm": {
			"success": true,
			"prepared_toggle_key": enabled_key,
			"reused": true
		},
		"disabled_prewarm": {
			"success": true,
			"prepared_toggle_key": disabled_key,
			"reused": true
		},
		"transition": transition,
		"loading_screen_required": false,
		"text": "%s was installed." % str(
			bundle.get(
				"name",
				clean_bundle_id
			)
		)
	}

func install_bundle_component(
	bundle_id: String,
	component_id: String,
	context: Dictionary = {}
) -> Dictionary:
	var clean_bundle_id: String = _id(
		bundle_id
	)
	var clean_component_id: String = _id(
		component_id
	)
	var bundle: Dictionary = _bundle(
		clean_bundle_id
	)

	if bundle.is_empty():
		return _failure(
			"unknown_bundle",
			"That reality bundle is not registered."
		)

	var components: Dictionary = _dict(
		bundle.get(
			"components",
			{}
		)
	)

	if not components.has(clean_component_id):
		return _failure(
			"unknown_bundle_component",
			"That bundle component is not registered."
		)

	var state: Dictionary = _bundle_state(
		clean_bundle_id
	)
	var selected: Array = _array(
		state.get(
			"selected_component_ids",
			[]
		)
	)

	if clean_component_id not in selected:
		selected.append(clean_component_id)

	state ["installed"] = true
	state ["selected_component_ids"] = (
		_valid_component_ids(
			bundle,
			selected
		)
	)
	state ["last_component_install_at_ms"] = int(
		Time.get_ticks_msec()
	)
	bundle_state_registry [clean_bundle_id] = state

	var registration: Dictionary = (
		_register_bundle_root_mod(
			clean_bundle_id,
			{
				"source": str(
					context.get(
						"source",
						"install_bundle_component"
					)
				),
				"preserve_enabled_state": true
			}
		)
	)


	_clear_prepared_bundle_toggles(
		clean_bundle_id
	)
	prewarm_bundle_toggle(
		clean_bundle_id,
		true,
		context
	)
	prewarm_bundle_toggle(
		clean_bundle_id,
		false,
		context
	)

	if bool(
		state.get(
			"enabled",
			false
		)
	):
		set_bundle_enabled(
			clean_bundle_id,
			true,
			context
		)

	_publish_state()

	return {
		"success": bool(
			registration.get(
				"success",
				false
			)
		),
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"type": "bundle_component_installed",
		"bundle_id": clean_bundle_id,
		"component_id": clean_component_id,
		"selected_component_ids": _array(
			state.get(
				"selected_component_ids",
				[]
			)
		),
		"registration": registration,
		"text": "%s was added to the bundle." % str(
			_dict(
				components.get(
					clean_component_id,
					{}
				)
			).get(
				"name",
				clean_component_id
			)
		)
	}


func remove_bundle_component(
	bundle_id: String,
	component_id: String,
	context: Dictionary = {}
) -> Dictionary:
	var clean_bundle_id: String = _id(
		bundle_id
	)
	var clean_component_id: String = _id(
		component_id
	)
	var bundle: Dictionary = _bundle(
		clean_bundle_id
	)

	if bundle.is_empty():
		return _failure(
			"unknown_bundle",
			"That reality bundle is not registered."
		)

	var state: Dictionary = _bundle_state(
		clean_bundle_id
	)
	var selected: Array = _array(
		state.get(
			"selected_component_ids",
			[]
		)
	)
	selected.erase(clean_component_id)

	state ["selected_component_ids"] = (
		_valid_component_ids(
			bundle,
			selected
		)
	)
	state ["last_component_remove_at_ms"] = int(
		Time.get_ticks_msec()
	)
	bundle_state_registry [clean_bundle_id] = state

	var registration: Dictionary = (
		_register_bundle_root_mod(
			clean_bundle_id,
			{
				"source": str(
					context.get(
						"source",
						"remove_bundle_component"
					)
				),
				"preserve_enabled_state": true
			}
		)
	)

	_clear_prepared_bundle_toggles(
		clean_bundle_id
	)
	prewarm_bundle_toggle(
		clean_bundle_id,
		true,
		context
	)
	prewarm_bundle_toggle(
		clean_bundle_id,
		false,
		context
	)

	if bool(
		state.get(
			"enabled",
			false
		)
	):
		set_bundle_enabled(
			clean_bundle_id,
			true,
			context
		)

	_publish_state()

	return {
		"success": bool(
			registration.get(
				"success",
				false
			)
		),
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"type": "bundle_component_removed",
		"bundle_id": clean_bundle_id,
		"component_id": clean_component_id,
		"selected_component_ids": _array(
			state.get(
				"selected_component_ids",
				[]
			)
		),
		"registration": registration
	}
func prepare_resident_bundle_toggles(
		context: Dictionary = {}
) -> Dictionary:
	if _law() == null:
		return _failure(
			"missing_mod_law",
			"ModContractEngine is unavailable."
		)

	var rows: Array = []
	var failures: Array = []
	var bundle_ids: Array = bundle_registry.keys()
	bundle_ids.sort()

	for raw_bundle_id in bundle_ids:
		var bundle_id: String = str(
			raw_bundle_id
		)

		var root_registration: Dictionary = (
			_register_bundle_root_mod(
				bundle_id,
				{
					"source": str(
						context.get(
							"source",
							"prepare_resident_bundle_toggles"
						)
					),
					"preserve_enabled_state": true,
				}
			)
		)

		if not bool(
			root_registration.get(
				"success",
				false
			)
		):
			failures.append({
				"bundle_id": bundle_id,
				"phase": "root_registration",
				"report": root_registration
			})
			continue

		var topology_revision: int = int(
			_law().provider_topology_revision
		)
		var enabled_key: String = _prepared_toggle_key(
			bundle_id,
			true,
			topology_revision
		)
		var disabled_key: String = _prepared_toggle_key(
			bundle_id,
			false,
			topology_revision
		)

		var enabled_report: Dictionary = {}
		var disabled_report: Dictionary = {}

		if prepared_toggle_registry.has(enabled_key):
			enabled_report = {
				"success": true,
				"type": "bundle_toggle_already_resident",
				"prepared_toggle_key": enabled_key,
				"reused": true
			}
		else:
			enabled_report = prewarm_bundle_toggle(
				bundle_id,
				true,
				{
					"source": str(
						context.get(
							"source",
							"prepare_resident_bundle_toggles"
						)
					),
				}
			)

		if prepared_toggle_registry.has(disabled_key):
			disabled_report = {
				"success": true,
				"type": "bundle_toggle_already_resident",
				"prepared_toggle_key": disabled_key,
				"reused": true
			}
		else:
			disabled_report = prewarm_bundle_toggle(
				bundle_id,
				false,
				{
					"source": str(
						context.get(
							"source",
							"prepare_resident_bundle_toggles"
						)
					),
				}
			)

		var row_success: bool = (
			bool(
				enabled_report.get(
					"success",
					false
				)
			)
			and bool(
				disabled_report.get(
					"success",
					false
				)
			)
		)

		rows.append({
			"bundle_id": bundle_id,
			"success": row_success,
			"root_registration": root_registration,
			"enabled_preparation": enabled_report,
			"disabled_preparation": disabled_report,
			"provider_topology_revision": (
				_law().provider_topology_revision
			)
		})

		if not row_success:
			failures.append(
				rows [rows.size() - 1]
			)

	return {
		"success": failures.is_empty(),
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"type": "resident_bundle_toggle_preparation",
		"bundle_rows": rows,
		"failures": failures,
		"bundle_count": rows.size(),
		"ui_is_renderer_only": true
	}
func queue_resident_bundle_admission(
	context: Dictionary = {}
) -> Dictionary:
	var bundle_ids: Array = bundle_registry.keys()
	bundle_ids.sort()

	if bundle_ids.is_empty():
		return {
			"success": true,
			"schema": ENGINE_SCHEMA,
			"version": ENGINE_VERSION,
			"type": "resident_bundle_admission_not_required",
			"bundle_count": 0,
			"ui_is_renderer_only": true
		}

	var generation: int = int(
		get_meta(
			"resident_bundle_admission_generation",
			0
		)
	) + 1

	set_meta(
		"resident_bundle_admission_generation",
		generation
	)
	set_meta(
		"resident_bundle_admission_pending",
		true
	)
	set_meta(
		"resident_bundle_admission_job",
		{
			"generation": generation,
			"source": str(
				context.get(
					"source",
					"queue_resident_bundle_admission"
				)
			),
			"bundle_ids": bundle_ids.duplicate(false),
			"phase": "await_topology",
			"cursor": 0,
			"stable_topology_passes": 0,
			"observed_topology_revision": -1,
			"prepared_topology_revision": -1,
			"bundle_rows": {},
			"failure_count": 0,
			"queued_at_ms": int(
				Time.get_ticks_msec()
			),
			"observation_required": false
		}
	)

	_schedule_resident_bundle_admission_quantum(
		generation,
		0.1
	)

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"type": "resident_bundle_admission_queued",
		"generation": generation,
		"bundle_count": bundle_ids.size(),
		"ui_is_renderer_only": true
	}


func _schedule_resident_bundle_admission_quantum(
	generation: int,
	delay_seconds: float = 0.05
) -> void:
	if generation != int(
		get_meta(
			"resident_bundle_admission_generation",
			0
		)
	):
		return

	var scheduled_generation: int = int(
		get_meta(
			"resident_bundle_admission_scheduled_generation",
			-1
		)
	)

	if scheduled_generation == generation:
		return

	set_meta(
		"resident_bundle_admission_scheduled_generation",
		generation
	)

	var main_loop: MainLoop = Engine.get_main_loop()

	if (
		main_loop == null
		or not (main_loop is SceneTree)
	):
		call_deferred(
			"_service_resident_bundle_admission_quantum",
			generation
		)
		return

	var tree: SceneTree = main_loop as SceneTree
	var timer:= tree.create_timer(
		maxf(
			0.01,
			delay_seconds
		)
	)

	timer.timeout.connect(
		Callable(
			self,
			"_service_resident_bundle_admission_quantum"
		).bind(
			generation
		),
		CONNECT_ONE_SHOT
	)


func _service_resident_bundle_admission_quantum(
	generation: int
) -> void:
	if generation != int(
		get_meta(
			"resident_bundle_admission_generation",
			0
		)
	):
		return

	set_meta(
		"resident_bundle_admission_scheduled_generation",
		-1
	)

	var job_raw: Variant = get_meta(
		"resident_bundle_admission_job",
		{}
	)
	var job: Dictionary = (
		job_raw as Dictionary
		if typeof(job_raw) == TYPE_DICTIONARY
		else {}
	)

	if (
		job.is_empty()
		or int(
			job.get(
				"generation",
				-1
			)
		) != generation
	):
		return

	var law = _law()

	if law == null:
		job ["failure_count"] = int(
			job.get(
				"failure_count",
				0
			)
		) + 1

		set_meta(
			"resident_bundle_admission_job",
			job
		)

		_schedule_resident_bundle_admission_quantum(
			generation,
			0.15
		)
		return

	var phase: String = str(
		job.get(
			"phase",
			"await_topology"
		)
	)
	var bundle_ids: Array = _array(
		job.get(
			"bundle_ids",
			[]
		)
	)

	if phase == "await_topology":
		var topology_revision: int = int(
			law.provider_topology_revision
		)
		var observed_revision: int = int(
			job.get(
				"observed_topology_revision",
				-1
			)
		)
		var stable_passes: int = int(
			job.get(
				"stable_topology_passes",
				0
			)
		)

		if topology_revision == observed_revision:
			stable_passes += 1
		else:
			observed_revision = topology_revision
			stable_passes = 0

		job ["observed_topology_revision"] = (
			observed_revision
		)
		job ["stable_topology_passes"] = stable_passes

		if stable_passes < 2:
			set_meta(
				"resident_bundle_admission_job",
				job
			)

			_schedule_resident_bundle_admission_quantum(
				generation,
				0.05
			)
			return

		job ["phase"] = "roots"
		job ["cursor"] = 0
		job ["failure_count"] = 0

		set_meta(
			"resident_bundle_admission_job",
			job
		)

		_schedule_resident_bundle_admission_quantum(
			generation,
			0.01
		)
		return

	if phase in [
		"enabled_snapshots",
		"disabled_snapshots"
	]:
		var prepared_revision: int = int(
			job.get(
				"prepared_topology_revision",
				-1
			)
		)

		if int(
			law.provider_topology_revision
		) != prepared_revision:
			job ["phase"] = "await_topology"
			job ["cursor"] = 0
			job ["stable_topology_passes"] = 0
			job ["observed_topology_revision"] = -1
			job ["prepared_topology_revision"] = -1
			job ["bundle_rows"] = {}
			job ["failure_count"] = 0

			set_meta(
				"resident_bundle_admission_job",
				job
			)

			_schedule_resident_bundle_admission_quantum(
				generation,
				0.05
			)
			return

	var cursor: int = int(
		job.get(
			"cursor",
			0
		)
	)

	if phase == "roots":
		if cursor >= bundle_ids.size():
			job ["phase"] = "enabled_snapshots"
			job ["cursor"] = 0
			job ["failure_count"] = 0
			job ["prepared_topology_revision"] = int(
				law.provider_topology_revision
			)

			set_meta(
				"resident_bundle_admission_job",
				job
			)

			_schedule_resident_bundle_admission_quantum(
				generation,
				0.02
			)
			return

		var bundle_id: String = str(
			bundle_ids [cursor]
		)
		var root_report: Dictionary = (
			_register_bundle_root_mod(
				bundle_id,
				{
					"source": (
						"mod_bundle_contract_engine."
						+ "resident_bundle_admission."
						+ "root_quantum"
					),
					"preserve_enabled_state": true,
				}
			)
		)

		if not bool(
			root_report.get(
				"success",
				false
			)
		):
			job ["failure_count"] = int(
				job.get(
					"failure_count",
					0
				)
			) + 1
			job ["last_failure"] = (
				root_report.duplicate(false)
			)

			if int(
				job.get(
					"failure_count",
					0
				)
			) >= 24:
				set_meta(
					"resident_bundle_admission_pending",
					false
				)
				set_meta(
					"resident_bundle_admission_truth",
					{
						"success": false,
						"schema": ENGINE_SCHEMA,
						"version": ENGINE_VERSION,
						"type": (
							"resident_bundle_admission_failed"
						),
						"generation": generation,
						"phase": phase,
						"bundle_id": bundle_id,
						"report": root_report,
						"ui_is_renderer_only": true
					}
				)
				return

			set_meta(
				"resident_bundle_admission_job",
				job
			)

			_schedule_resident_bundle_admission_quantum(
				generation,
				0.15
			)
			return

		var bundle_rows: Dictionary = (
			job.get(
				"bundle_rows",
				{}
			) as Dictionary
		)

		if not bundle_rows.has(bundle_id):
			bundle_rows [bundle_id] = {}

		var row: Dictionary = (
			bundle_rows [bundle_id] as Dictionary
		)
		row ["root_registration"] = (
			root_report.duplicate(false)
		)
		bundle_rows [bundle_id] = row

		job ["bundle_rows"] = bundle_rows
		job ["cursor"] = cursor + 1
		job ["failure_count"] = 0

		set_meta(
			"resident_bundle_admission_job",
			job
		)

		_schedule_resident_bundle_admission_quantum(
			generation,
			0.02
		)
		return

	if phase == "enabled_snapshots":
		if cursor >= bundle_ids.size():
			job ["phase"] = "disabled_snapshots"
			job ["cursor"] = 0
			job ["failure_count"] = 0

			set_meta(
				"resident_bundle_admission_job",
				job
			)

			_schedule_resident_bundle_admission_quantum(
				generation,
				0.02
			)
			return

		var bundle_id: String = str(
			bundle_ids [cursor]
		)
		var enabled_key: String = (
			_prepared_toggle_key(
				bundle_id,
				true,
				int(
					law.provider_topology_revision
				)
			)
		)
		var enabled_report: Dictionary = {}

		if prepared_toggle_registry.has(
			enabled_key
		):
			enabled_report = {
				"success": true,
				"type": (
					"bundle_toggle_already_resident"
				),
				"prepared_toggle_key": enabled_key,
				"reused": true
			}
		else:
			enabled_report = prewarm_bundle_toggle(
				bundle_id,
				true,
				{
					"source": (
						"mod_bundle_contract_engine."
						+ "resident_bundle_admission."
						+ "enabled_quantum"
					),
				}
			)

		if not bool(
			enabled_report.get(
				"success",
				false
			)
		):
			job ["failure_count"] = int(
				job.get(
					"failure_count",
					0
				)
			) + 1
			job ["last_failure"] = (
				enabled_report.duplicate(false)
			)

			set_meta(
				"resident_bundle_admission_job",
				job
			)

			_schedule_resident_bundle_admission_quantum(
				generation,
				0.15
			)
			return

		var bundle_rows: Dictionary = (
			job.get(
				"bundle_rows",
				{}
			) as Dictionary
		)
		var row: Dictionary = (
			bundle_rows.get(
				bundle_id,
				{}
			) as Dictionary
		)
		row ["enabled_preparation"] = (
			enabled_report.duplicate(false)
		)
		bundle_rows [bundle_id] = row

		job ["bundle_rows"] = bundle_rows
		job ["cursor"] = cursor + 1
		job ["failure_count"] = 0

		set_meta(
			"resident_bundle_admission_job",
			job
		)

		_schedule_resident_bundle_admission_quantum(
			generation,
			0.02
		)
		return

	if phase == "disabled_snapshots":
		if cursor >= bundle_ids.size():
			var completed_rows: Dictionary = (
				job.get(
					"bundle_rows",
					{}
				) as Dictionary
			)

			set_meta(
				"resident_bundle_admission_pending",
				false
			)
			set_meta(
				"resident_bundle_admission_job",
				{}
			)
			set_meta(
				"resident_bundle_admission_truth",
				{
					"success": true,
					"schema": ENGINE_SCHEMA,
					"version": ENGINE_VERSION,
					"type": (
						"resident_bundle_admission_complete"
					),
					"generation": generation,
					"provider_topology_revision": int(
						law.provider_topology_revision
					),
					"bundle_rows": completed_rows,
					"bundle_count": bundle_ids.size(),
					"observation_required": false,
					"completed_at_ms": int(
						Time.get_ticks_msec()
					),
					"ui_is_renderer_only": true
				}
			)
			return

		var bundle_id: String = str(
			bundle_ids [cursor]
		)
		var disabled_key: String = (
			_prepared_toggle_key(
				bundle_id,
				false,
				int(
					law.provider_topology_revision
				)
			)
		)
		var disabled_report: Dictionary = {}

		if prepared_toggle_registry.has(
			disabled_key
		):
			disabled_report = {
				"success": true,
				"type": (
					"bundle_toggle_already_resident"
				),
				"prepared_toggle_key": disabled_key,
				"reused": true
			}
		else:
			disabled_report = prewarm_bundle_toggle(
				bundle_id,
				false,
				{
					"source": (
						"mod_bundle_contract_engine."
						+ "resident_bundle_admission."
						+ "disabled_quantum"
					),
				}
			)

		if not bool(
			disabled_report.get(
				"success",
				false
			)
		):
			job ["failure_count"] = int(
				job.get(
					"failure_count",
					0
				)
			) + 1
			job ["last_failure"] = (
				disabled_report.duplicate(false)
			)

			set_meta(
				"resident_bundle_admission_job",
				job
			)

			_schedule_resident_bundle_admission_quantum(
				generation,
				0.15
			)
			return

		var bundle_rows: Dictionary = (
			job.get(
				"bundle_rows",
				{}
			) as Dictionary
		)
		var row: Dictionary = (
			bundle_rows.get(
				bundle_id,
				{}
			) as Dictionary
		)
		row ["disabled_preparation"] = (
			disabled_report.duplicate(false)
		)
		row ["success"] = true
		bundle_rows [bundle_id] = row

		job ["bundle_rows"] = bundle_rows
		job ["cursor"] = cursor + 1
		job ["failure_count"] = 0

		set_meta(
			"resident_bundle_admission_job",
			job
		)

		_schedule_resident_bundle_admission_quantum(
			generation,
			0.02
		)
func prewarm_bundle_toggle(
		bundle_id: String,
		enabled: bool,
		context: Dictionary = {}
) -> Dictionary:
	var clean_bundle_id: String = _id(
		bundle_id
	)
	var bundle: Dictionary = _bundle(
		clean_bundle_id
	)

	if bundle.is_empty():
		return _failure(
			"unknown_bundle",
			"That reality bundle is not registered."
		)

	if _law() == null:
		return _failure(
			"missing_mod_law",
			"ModContractEngine is unavailable."
		)

	var root_mod_id: String = _id(
		str(
			bundle.get(
				"root_mod_id",
				""
			)
		)
	)

	if not _law().mod_registry.has(root_mod_id):
		return _failure(
			"bundle_root_not_resident",
			(
				"The bundle root must be registered before "
				+ "its toggle snapshots can be prepared."
			)
		)

	var desired_enabled_set: Dictionary = (
		_law().enabled_mod_ids.duplicate(false)
	)

	if enabled:
		desired_enabled_set [root_mod_id] = true
	else:
		desired_enabled_set.erase(root_mod_id)

	var snapshot: Dictionary = (
		_law().compile_enabled_set_snapshot(
			desired_enabled_set,
			{
				"source": str(
					context.get(
						"source",
						"prewarm_bundle_toggle"
					)
				),
				"bundle_id": clean_bundle_id,
			}
		)
	)

	if not bool(
		snapshot.get(
			"success",
			false
		)
	):
		return snapshot

	var resolution_raw: Variant = snapshot.get(
		"provider_resolution_registry",
		{}
	)

	if typeof(resolution_raw) != TYPE_DICTIONARY:
		return _failure(
			"invalid_prepared_provider_resolution",
			"The prepared provider resolution is malformed."
		)

	var actor: Person = (
		gs.player
		if (
			gs != null
			and gs.player != null
		)
		else null
	)

	var era_cache_snapshot: Dictionary = {
		"success": true,
		"provider_cache": {},
	}
	var royalty_cache_snapshot: Dictionary = {
		"success": true,
		"provider_cache": {},
		"provider_validation_registry": {},
	}

	if (
		gs != null
		and gs.era_mod_contract_engine != null
		and gs.era_mod_contract_engine.has_method(
			"compile_provider_cache_snapshot"
		)
	):
		era_cache_snapshot = (
			gs.era_mod_contract_engine
			.compile_provider_cache_snapshot(
				resolution_raw as Dictionary,
				actor,
				{
					"source": (
						"bundle_toggle_resident_preparation"
					),
					"bundle_id": clean_bundle_id,
					"enabled": enabled
				}
			)
		)

	if (
		gs != null
		and gs.royalty_mod_contract_engine != null
		and gs.royalty_mod_contract_engine.has_method(
			"compile_provider_cache_snapshot"
		)
	):
		royalty_cache_snapshot = (
			gs.royalty_mod_contract_engine
			.compile_provider_cache_snapshot(
				resolution_raw as Dictionary,
				actor,
				{
					"source": (
						"bundle_toggle_resident_preparation"
					),
					"bundle_id": clean_bundle_id,
					"enabled": enabled
				}
			)
		)

	if (
		not bool(
			era_cache_snapshot.get(
				"success",
				false
			)
		)
		or not bool(
			royalty_cache_snapshot.get(
				"success",
				false
			)
		)
	):
		return _failure(
			"dependent_provider_snapshot_compile_failed",
			(
				"The bundle's dependent provider caches could "
				+ "not be prepared."
			)
		)

	var prepared_toggle_key: String = (
		_prepared_toggle_key(
			clean_bundle_id,
			enabled,
			int(
				snapshot.get(
					"source_topology_revision",
					-1
				)
			)
		)
	)



	prepared_toggle_registry [prepared_toggle_key] = {
		"bundle_id": clean_bundle_id,
		"enabled": enabled,
		"root_mod_id": root_mod_id,
		"snapshot": snapshot,
		"era_mod_cache_snapshot": era_cache_snapshot,
		"royalty_mod_cache_snapshot": (
			royalty_cache_snapshot
		),
		"provider_topology_revision": int(
			snapshot.get(
				"source_topology_revision",
				-1
			)
		),
		"prepared_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"type": "bundle_toggle_prepared",
		"bundle_id": clean_bundle_id,
		"enabled": enabled,
		"prepared_toggle_key": prepared_toggle_key,
		"target_count": int(
			snapshot.get(
				"target_count",
				0
			)
		),
		"conflict_count": int(
			snapshot.get(
				"conflict_count",
				0
			)
		),
	}

func set_bundle_enabled(
		bundle_id: String,
		enabled: bool,
		context: Dictionary = {}
) -> Dictionary:
	var clean_bundle_id: String = _id(
		bundle_id
	)
	var bundle: Dictionary = _bundle(
		clean_bundle_id
	)

	if bundle.is_empty():
		return _failure(
			"unknown_bundle",
			"That reality bundle is not registered."
		)

	if _law() == null:
		return _failure(
			"missing_mod_law",
			"ModContractEngine is unavailable."
		)

	var state: Dictionary = _bundle_state(
		clean_bundle_id
	)

	if not bool(
		state.get(
			"installed",
			false
		)
	):
		return _failure(
			"bundle_not_installed",
			"Install the reality bundle before enabling it."
		)

	var root_mod_id: String = _id(
		str(
			bundle.get(
				"root_mod_id",
				""
			)
		)
	)
	var topology_revision: int = int(
		_law().provider_topology_revision
	)
	var prepared_toggle_key: String = (
		_prepared_toggle_key(
			clean_bundle_id,
			enabled,
			topology_revision
		)
	)
	var prepared_raw: Variant = (
		prepared_toggle_registry.get(
			prepared_toggle_key,
			{}
		)
	)

	if typeof(prepared_raw) != TYPE_DICTIONARY:
		return _failure(
			"bundle_toggle_snapshot_not_resident",
			(
				"The requested bundle state is not resident. "
				+ "Toggle-time compilation is forbidden."
			)
		)

	var prepared: Dictionary = (
		prepared_raw as Dictionary
	)
	var snapshot_raw: Variant = prepared.get(
		"snapshot",
		{}
	)

	if typeof(snapshot_raw) != TYPE_DICTIONARY:
		return _failure(
			"invalid_bundle_toggle_snapshot",
			"The resident bundle toggle snapshot is malformed."
		)

	var snapshot: Dictionary = (
		snapshot_raw as Dictionary
	)

	if int(
		snapshot.get(
			"source_topology_revision",
			-1
		)
	) != topology_revision:
		return _failure(
			"stale_bundle_toggle_snapshot",
			(
				"The resident bundle snapshot belongs to an older "
				+ "provider topology. Recompilation may not occur "
				+ "on the toggle path."
			)
		)

	var desired_raw: Variant = snapshot.get(
		"enabled_mod_ids",
		{}
	)

	if typeof(desired_raw) != TYPE_DICTIONARY:
		return _failure(
			"invalid_bundle_enabled_set",
			"The resident enabled-set contract is malformed."
		)

	var transaction: Dictionary = (
		_law().apply_enabled_set_transaction(
			desired_raw as Dictionary,
			{
				"source": str(
					context.get(
						"source",
						"set_bundle_enabled"
					)
				),
				"bundle_id": clean_bundle_id,
				"single_mod_id": root_mod_id,
				"prepared_snapshot": snapshot,
				"atomic_bundle_transition": true
			}
		)
	)

	if not bool(
		transaction.get(
			"success",
			false
		)
	):
		return transaction

	var era_cache_report: Dictionary = {
		"success": true,
	}
	var royalty_cache_report: Dictionary = {
		"success": true,
	}

	var era_snapshot_raw: Variant = (
		prepared.get(
			"era_mod_cache_snapshot",
			{}
		)
	)
	if (
		gs != null
		and gs.era_mod_contract_engine != null
		and gs.era_mod_contract_engine.has_method(
			"install_prepared_provider_cache_snapshot"
		)
		and typeof(era_snapshot_raw) == TYPE_DICTIONARY
	):
		era_cache_report = (
			gs.era_mod_contract_engine
			.install_prepared_provider_cache_snapshot(
				era_snapshot_raw as Dictionary,
				{
					"source": "bundle_toggle_commit",
					"bundle_id": clean_bundle_id,
					"enabled": enabled
				}
			)
		)

	var royalty_snapshot_raw: Variant = (
		prepared.get(
			"royalty_mod_cache_snapshot",
			{}
		)
	)
	if (
		gs != null
		and gs.royalty_mod_contract_engine != null
		and gs.royalty_mod_contract_engine.has_method(
			"install_prepared_provider_cache_snapshot"
		)
		and typeof(royalty_snapshot_raw) == TYPE_DICTIONARY
	):
		royalty_cache_report = (
			gs.royalty_mod_contract_engine
			.install_prepared_provider_cache_snapshot(
				royalty_snapshot_raw as Dictionary,
				{
					"source": "bundle_toggle_commit",
					"bundle_id": clean_bundle_id,
					"enabled": enabled
				}
			)
		)

	if (
		not bool(
			era_cache_report.get(
				"success",
				false
			)
		)
		or not bool(
			royalty_cache_report.get(
				"success",
				false
			)
		)
	):
		return _failure(
			"prepared_dependent_cache_install_failed",
			(
				"A prepared dependent cache could not be "
				+ "installed."
			)
		)

	var runtime_report: Dictionary = (
		_set_bundle_runtime_enabled(
			clean_bundle_id,
			enabled,
			{
				"source": str(
					context.get(
						"source",
						"set_bundle_enabled"
					)
				),
				"component_ids": _array(
					state.get(
						"selected_component_ids",
						[]
					)
				),
			}
		)
	)

	if not bool(
		runtime_report.get(
			"success",
			true
		)
	):
		return runtime_report

	state ["enabled"] = enabled
	state [
		"last_enabled_at_ms"
		if enabled
		else "last_disabled_at_ms"
	] = int(
		Time.get_ticks_msec()
	)
	state ["last_transition_source"] = str(
		context.get(
			"source",
			"set_bundle_enabled"
		)
	)
	state ["last_transaction_revision"] = int(
		transaction.get(
			"registry_revision",
			0
		)
	)
	bundle_state_registry [clean_bundle_id] = state
	registry_revision += 1

	_reconcile_dependent_authorities({
		"source": "bundle_toggle_commit",
		"bundle_id": clean_bundle_id,
		"enabled": enabled,
	})

	_publish_bundle_state_row(
		clean_bundle_id,
		{
			"source": "bundle_toggle_commit",
			"enabled": enabled
		}
	)

	var observed_actor: Person = (
		gs.player
		if (
			gs != null
			and gs.player != null
		)
		else null
	)
	var reality_surface: Dictionary = (
		reality_surface_contract(
			clean_bundle_id,
			observed_actor,
			{
				"source": "bundle_toggle_commit",
				"enabled": enabled,
				"transition_revision": registry_revision,
				"simulation_mutation_forbidden": true
			}
		)
	)

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"type": (
			"reality_bundle_enabled"
			if enabled
			else "reality_bundle_disabled"
		),
		"bundle_id": clean_bundle_id,
		"root_mod_id": root_mod_id,
		"enabled": enabled,
		"selected_component_ids": _array(
			state.get(
				"selected_component_ids",
				[]
			)
		),
		"transaction": transaction,
		"runtime_report": runtime_report,
		"era_cache_report": era_cache_report,
		"royalty_cache_report": royalty_cache_report,
		"reality_surface_contract": reality_surface,
		"loading_screen_required": false,
		"surface_invalidation_contract": {
			"surface_ids": [
				"world",
				"life",
				"activities",
				"career",
				"relationships",
				"assets",
				"mods"
			],
			"build_on_click_forbidden": true,
			"reason": "reality_bundle_transition"
		},
		"text": (
			"%s is now live." % str(
				bundle.get(
					"name",
					clean_bundle_id
				)
			)
			if enabled
			else (
				"Base EraLife reality restored "
				+ "from the resident provider registry."
			)
		)
	}


func uninstall_bundle(
	bundle_id: String,
	context: Dictionary = {}
) -> Dictionary:
	var clean_bundle_id: String = _id(
		bundle_id
	)
	var bundle: Dictionary = _bundle(
		clean_bundle_id
	)

	if bundle.is_empty():
		return _failure(
			"unknown_bundle",
			"That reality bundle is not registered."
		)

	var state: Dictionary = _bundle_state(
		clean_bundle_id
	)

	if bool(
		state.get(
			"enabled",
			false
		)
	):
		set_bundle_enabled(
			clean_bundle_id,
			false,
			{
				"source": "uninstall_bundle_disable"
			}
		)

	var root_mod_id: String = _id(
		str(
			bundle.get(
				"root_mod_id",
				""
			)
		)
	)
	var uninstall_report: Dictionary = (
		_law().uninstall_mod(
			root_mod_id,
			{
				"source": str(
					context.get(
						"source",
						"uninstall_bundle"
					)
				),
				"preserve_save_data": true
			}
		)
		if _law() != null
		else {}
	)

	state ["installed"] = false
	state ["enabled"] = false
	state ["last_uninstalled_at_ms"] = int(
		Time.get_ticks_msec()
	)
	bundle_state_registry [clean_bundle_id] = state
	_clear_prepared_bundle_toggles(
		clean_bundle_id
	)
	registry_revision += 1

	_reconcile_dependent_authorities({
		"source": "bundle_uninstall",
		"bundle_id": clean_bundle_id
	})
	_publish_state()

	return {
		"success": bool(
			uninstall_report.get(
				"success",
				true
			)
		),
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"type": "reality_bundle_uninstalled",
		"bundle_id": clean_bundle_id,
		"uninstall_report": uninstall_report,
		"text": "%s was uninstalled." % str(
			bundle.get(
				"name",
				clean_bundle_id
			)
		)
	}


func resolve_intent(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	var action_id: String = str(
		payload.get(
			"action_id",
			payload.get(
				"intent_type",
				"refresh_bundles"
			)
		)
	).strip_edges().to_lower()
	var bundle_id: String = str(
		payload.get(
			"bundle_id",
			""
		)
	)

	match action_id:
		"install_bundle":
			return install_bundle(
				bundle_id,
				payload
			)

		"install_bundle_component":
			return install_bundle_component(
				bundle_id,
				str(
					payload.get(
						"component_id",
						""
					)
				),
				payload
			)

		"remove_bundle_component":
			return remove_bundle_component(
				bundle_id,
				str(
					payload.get(
						"component_id",
						""
					)
				),
				payload
			)

		"enable_bundle":
			return set_bundle_enabled(
				bundle_id,
				true,
				payload
			)

		"disable_bundle":
			return set_bundle_enabled(
				bundle_id,
				false,
				payload
			)

		"prewarm_bundle_enable":
			return prewarm_bundle_toggle(
				bundle_id,
				true,
				payload
			)

		"prewarm_bundle_disable":
			return prewarm_bundle_toggle(
				bundle_id,
				false,
				payload
			)

		"uninstall_bundle":
			return uninstall_bundle(
				bundle_id,
				payload
			)

		"open_bundle_menu", "refresh_bundle_menu":
			return {
				"success": true,
				"schema": ENGINE_SCHEMA,
				"version": ENGINE_VERSION,
				"type": "bundle_menu_resolved",
				"bundle_id": _id(bundle_id),
				"bundle_menu_contract": (
					bundle_menu_contract(
						_id(bundle_id),
						actor,
						payload
					)
				)
			}

		_:
			return _failure(
				"unknown_bundle_intent",
				(
					"ModBundleContractEngine does not "
					+ "recognize that intent."
				)
			)


func resolve_bundle_service_intent(
	actor: Person,
	provider: Dictionary,
	route: Dictionary,
	payload: Dictionary = {}
) -> Dictionary:
	var provider_mod_id: String = _id(
		str(
			provider.get(
				"mod_id",
				""
			)
		)
	)
	var bundle_id: String = _id(
		str(
			route.get(
				"bundle_id",
				""
			)
		)
	)
	var service_id: String = _id(
		str(
			route.get(
				"service_id",
				""
			)
		)
	)
	var method_name: String = str(
		route.get(
			"method",
			""
		)
	).strip_edges()
	var bundle: Dictionary = _bundle(
		bundle_id
	)

	if bundle.is_empty():
		return _failure(
			"unknown_bundle",
			"The provider bundle is not registered."
		)

	if _id(
		str(
			bundle.get(
				"root_mod_id",
				""
			)
		)
	) != provider_mod_id:
		return _failure(
			"bundle_provider_ownership_mismatch",
			(
				"The provider is not owned by "
				+ "the declared reality bundle."
			)
		)

	var state: Dictionary = _bundle_state(
		bundle_id
	)

	if not bool(
		state.get(
			"enabled",
			false
		)
	):
		return _failure(
			"bundle_disabled",
			"That reality bundle is not active."
		)

	var service: Dictionary = _dict(
		bundle_service_registry.get(
			service_id,
			{}
		)
	)

	if service.is_empty():
		return _failure(
			"unknown_bundle_service",
			"That bundle service is not registered."
		)

	if (
		method_name == ""
		or method_name.begins_with("_")
	):
		return _failure(
			"private_bundle_method_forbidden",
			"Bundle service methods must be public."
		)

	if method_name not in _array(
		service.get(
			"allowed_methods",
			[]
		)
	):
		return _failure(
			"undeclared_bundle_method",
			(
				"That bundle service method "
				+ "is not allowed."
			)
		)

	if gs == null:
		return _failure(
			"missing_game_state",
			"GameState is unavailable."
		)

	var engine_property: String = str(
		service.get(
			"engine_property",
			""
		)
	)
	var instance = gs.get(engine_property)

	if (
		instance == null
		or not instance.has_method(method_name)
	):
		return _failure(
			"bundle_service_unavailable",
			(
				"The bundle runtime service "
				+ "is unavailable."
			)
		)

	var result: Variant = instance.callv(
		method_name,
		[
			actor,
			payload.duplicate(true)
		]
	)

	if typeof(result) != TYPE_DICTIONARY:
		return _failure(
			"invalid_bundle_service_result",
			(
				"A bundle service must return "
				+ "a Dictionary contract."
			)
		)

	var report: Dictionary = (
		result as Dictionary
	).duplicate(true)
	report ["bundle_id"] = bundle_id
	report ["service_id"] = service_id
	report ["mod_id"] = provider_mod_id
	report ["ui_is_renderer_only"] = true

	return report


func bundle_catalog_rows() -> Array:
	var rows: Array = []
	var bundle_ids: Array = bundle_registry.keys()
	bundle_ids.sort()

	for raw_bundle_id in bundle_ids:
		var bundle_id: String = str(
			raw_bundle_id
		)
		var bundle: Dictionary = _bundle(
			bundle_id
		)
		var state: Dictionary = _bundle_state(
			bundle_id
		)

		rows.append({
			"listing_kind": "reality_bundle",
			"bundle_id": bundle_id,
			"mod_id": str(
				bundle.get(
					"root_mod_id",
					""
				)
			),
			"name": str(
				bundle.get(
					"name",
					bundle_id
				)
			),
			"description": str(
				bundle.get(
					"description",
					""
				)
			),
			"author": str(
				bundle.get(
					"author",
					"EraLife"
				)
			),
			"release_version": str(
				bundle.get(
					"release_version",
					"1.0.0"
				)
			),
			"featured": bool(
				bundle.get(
					"featured",
					false
				)
			),
			"first_party": bool(
				bundle.get(
					"first_party",
					false
				)
			),
			"installed": bool(
				state.get(
					"installed",
					false
				)
			),
			"enabled": bool(
				state.get(
					"enabled",
					false
				)
			),
			"selected_component_ids": _array(
				state.get(
					"selected_component_ids",
					[]
				)
			),
			"component_count": _array(
				bundle.get(
					"component_order",
					[]
				)
			).size(),
			"installed_component_count": _array(
				state.get(
					"selected_component_ids",
					[]
				)
			).size(),
			"bundle_contract": (
				bundle.duplicate(true)
			),
			"compatibility": {
				"compatible": true,
				"status": "compatible",
				"reasons": [],
				"warnings": []
			},
			"rating": 5.0,
			"downloads": 0
		})

	return rows


func bundle_summaries() -> Array:
	var out: Array = []

	for raw_row in bundle_catalog_rows():
		var row: Dictionary = _dict(raw_row)

		out.append({
			"bundle_id": str(
				row.get(
					"bundle_id",
					""
				)
			),
			"root_mod_id": str(
				row.get(
					"mod_id",
					""
				)
			),
			"name": str(
				row.get(
					"name",
					"Reality Bundle"
				)
			),
			"description": str(
				row.get(
					"description",
					""
				)
			),
			"installed": bool(
				row.get(
					"installed",
					false
				)
			),
			"enabled": bool(
				row.get(
					"enabled",
					false
				)
			),
			"first_party": bool(
				row.get(
					"first_party",
					false
				)
			),
			"selected_component_ids": _array(
				row.get(
					"selected_component_ids",
					[]
				)
			),
			"component_count": int(
				row.get(
					"component_count",
					0
				)
			),
			"installed_component_count": int(
				row.get(
					"installed_component_count",
					0
				)
			),
		})

	return out


func bundle_component_rows(
	bundle_id: String
) -> Array:
	var bundle: Dictionary = _bundle(
		bundle_id
	)

	if bundle.is_empty():
		return []

	var state: Dictionary = _bundle_state(
		bundle_id
	)
	var selected: Array = _array(
		state.get(
			"selected_component_ids",
			[]
		)
	)
	var components: Dictionary = _dict(
		bundle.get(
			"components",
			{}
		)
	)
	var rows: Array = []

	for raw_component_id in _array(
		bundle.get(
			"component_order",
			[]
		)
	):
		var component_id: String = str(
			raw_component_id
		)
		var component: Dictionary = _dict(
			components.get(
				component_id,
				{}
			)
		)
		var installed: bool = (
			component_id in selected
		)

		rows.append({
			"row_kind": "bundle_component",
			"id": "%s::%s" % [
				bundle_id,
				component_id
			],
			"bundle_id": bundle_id,
			"component_id": component_id,
			"title": str(
				component.get(
					"name",
					component_id.capitalize()
				)
			),
			"subtitle": "Bundle Component",
			"description": str(
				component.get(
					"description",
					""
				)
			),
			"installed": installed,
			"enabled": true,
			"chips": [
				(
					"Installed"
					if installed
					else "Available"
				),
				"Contract Provider Set"
			],
			"actions": [
				{
					"action_id": (
						"remove_bundle_component"
						if installed
						else "install_bundle_component"
					),
					"label": (
						"Remove"
						if installed
						else "Install"
					),
					"bundle_id": bundle_id,
					"component_id": component_id,
					"enabled": true
				}
			]
		})

	return rows


func bundle_menu_contract(
	bundle_id: String,
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	var clean_bundle_id: String = _id(
		bundle_id
	)
	var bundle: Dictionary = _bundle(
		clean_bundle_id
	)
	var state: Dictionary = _bundle_state(
		clean_bundle_id
	)

	if bundle.is_empty():
		return _failure(
			"unknown_bundle",
			"That reality bundle is not registered."
		)

	var bundle_installed: bool = bool(
		state.get(
			"installed",
			false
		)
	)
	var bundle_enabled: bool = bool(
		state.get(
			"enabled",
			false
		)
	)

	if not bundle_enabled:
		var installer_surfaces: Dictionary = {
			"overview": [
				{
					"row_kind": "reality_bundle",
					"id": clean_bundle_id,
					"title": str(
						bundle.get(
							"name",
							clean_bundle_id
						)
					),
					"subtitle": (
						"Installed Reality • Dormant"
						if bundle_installed
						else "Installable Reality"
					),
					"description": str(
						bundle.get(
							"description",
							""
						)
					),
					"enabled": false,
					"chips": [
						(
							"Installed"
							if bundle_installed
							else "Not Installed"
						),
						"State Preserved",
						"Hot-Swappable"
					],
					"actions": [
						{
							"action_id": (
								"enable_bundle"
								if bundle_installed
								else "install_bundle"
							),
							"label": (
								"Enable Reality"
								if bundle_installed
								else "Install Reality"
							),
							"bundle_id": (
								clean_bundle_id
							),
							"enable_after_install": true,
							"enabled": true
						}
					]
				}
			],
			"components": bundle_component_rows(
				clean_bundle_id
			)
		}
		var active_section: String = str(
			context.get(
				"active_section",
				"overview"
			)
		).strip_edges().to_lower()

		if active_section not in [
			"overview",
			"components"
		]:
			active_section = "overview"

		return {
			"success": true,
			"schema": (
				"eralife.bundle_menu_runtime_contract"
			),
			"version": 2,
			"bundle_id": clean_bundle_id,
			"actor_id": (
				int(actor.id)
				if actor != null
				else -1
			),
			"title": str(
				bundle.get(
					"name",
					"Reality Bundle"
				)
			),
			"subtitle": (
				"Reality dormant. Its complete state remains "
				+ "preserved and may be reattached immediately."
			),
			"bundle_installed": bundle_installed,
			"bundle_enabled": false,
			"active_section": active_section,
			"section_tabs": [
				{
					"id": "overview",
					"label": "OVERVIEW",
					"icon": "◉"
				},
				{
					"id": "components",
					"label": "COMPONENTS",
					"icon": "▦"
				}
			],
			"section_surfaces": installer_surfaces,
			"section_rows": _array(
				installer_surfaces.get(
					active_section,
					[]
				)
			),
			"truth_state": "hot",
			"authoritative_projection": true,
			"runtime_state_preserved": true,
			"ui_is_renderer_only": true
		}

	if (
		clean_bundle_id
		== CavemanRealityBundlePack.BUNDLE_ID
		and gs != null
		and gs.caveman_reality_runtime_engine != null
	):
		var caveman_contract: Dictionary = (
			gs.caveman_reality_runtime_engine
			.emit_bundle_menu_contract(
				actor,
				context
			)
		)

		caveman_contract [
			"bundle_installed"
		] = bundle_installed
		caveman_contract [
			"bundle_enabled"
		] = bundle_enabled
		caveman_contract [
			"runtime_state_preserved"
		] = true

		return caveman_contract

	var menu_contract: Dictionary = _dict(
		bundle.get(
			"bundle_menu_contract",
			{}
		)
	)

	menu_contract ["success"] = true
	menu_contract ["bundle_id"] = clean_bundle_id
	menu_contract ["actor_id"] = (
		int(actor.id)
		if actor != null
		else -1
	)
	menu_contract [
		"bundle_installed"
	] = bundle_installed
	menu_contract [
		"bundle_enabled"
	] = bundle_enabled
	menu_contract ["truth_state"] = "hot"
	menu_contract [
		"authoritative_projection"
	] = true
	menu_contract [
		"runtime_state_preserved"
	] = true
	menu_contract [
		"ui_is_renderer_only"
	] = true

	return menu_contract

func active_experience_contract() -> Dictionary:
	for raw_bundle_id in bundle_registry.keys():
		var bundle_id: String = str(
			raw_bundle_id
		)
		var state: Dictionary = _bundle_state(
			bundle_id
		)

		if bool(
			state.get(
				"enabled",
				false
			)
		):
			var bundle: Dictionary = _bundle(
				bundle_id
			)
			var experience: Dictionary = _dict(
				bundle.get(
					"experience_contract",
					{}
				)
			)
			experience ["bundle_id"] = bundle_id
			experience ["selected_component_ids"] = (
				_array(
					state.get(
						"selected_component_ids",
						[]
					)
				)
			)
			return experience

	return {}


func self_heal(
	context: Dictionary = {}
) -> Dictionary:
	var repaired: Array = []
	var resident_admission_required: bool = false

	for raw_bundle_id in bundle_registry.keys():
		var bundle_id: String = str(
			raw_bundle_id
		)
		var bundle: Dictionary = _bundle(
			bundle_id
		)
		var state: Dictionary = _bundle_state(
			bundle_id
		)
		var root_mod_id: String = _id(
			str(
				bundle.get(
					"root_mod_id",
					""
				)
			)
		)

		state ["selected_component_ids"] = (
			_valid_component_ids(
				bundle,
				_array(
					state.get(
						"selected_component_ids",
						[]
					)
				)
			)
		)

		if bool(
			state.get(
				"installed",
				false
			)
		):
			var root_missing: bool = (
				_law() == null
				or not _law().mod_registry.has(
					root_mod_id
				)
			)

			if root_missing:
				resident_admission_required = true

				repaired.append({
					"bundle_id": bundle_id,
					"repair": (
						"root_mod_resident_admission_queued"
					),
				})

		bundle_state_registry [bundle_id] = state

	_publish_state()

	if resident_admission_required:
		call_deferred(
			"queue_resident_bundle_admission",
			{
				"source": str(
					context.get(
						"source",
						"mod_bundle_contract_engine.self_heal"
					)
				),
				"reason": (
					"imported_bundle_topology_not_resident"
				),
				"preserve_enabled_state": true,
			}
		)

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"repair_rows": repaired,
		"source": str(
			context.get(
				"source",
				"self_heal"
			)
		),
		"resident_admission_required": (
			resident_admission_required
		),
	}
func export_state() -> Dictionary:
	return {
		"schema": ENGINE_SCHEMA + ".state",
		"version": ENGINE_VERSION,
		"bundle_state_registry": (
			bundle_state_registry.duplicate(true)
		),
		"registry_revision": registry_revision,
		"last_report": last_report.duplicate(true)
	}


func import_state(
	data: Dictionary = {}
) -> Dictionary:
	bundle_state_registry = _dict(
		data.get(
			"bundle_state_registry",
			{}
		)
	)
	registry_revision = int(
		data.get(
			"registry_revision",
			0
		)
	)
	last_report = _dict(
		data.get(
			"last_report",
			{}
		)
	)
	_ensure_state_shape()

	return self_heal({
		"source": (
			"mod_bundle_contract_engine.import_state"
		)
	})


func _register_bundle_root_mod(
		bundle_id: String,
		context: Dictionary = {}
) -> Dictionary:
	var bundle: Dictionary = _bundle(
		bundle_id
	)
	var state: Dictionary = _bundle_state(
		bundle_id
	)

	if (
		bundle.is_empty()
		or _law() == null
	):
		return _failure(
			"bundle_root_registration_unavailable",
			(
				"The bundle or ModContractEngine "
				+ "is unavailable."
			)
		)

	var selected: Array = _array(
		state.get(
			"selected_component_ids",
			[]
		)
	)

	if selected.is_empty():
		selected = _array(
			bundle.get(
				"component_order",
				[]
			)
		)

	selected = _valid_component_ids(
		bundle,
		selected
	)

	var root_mod_id: String = _id(
		str(
			bundle.get(
				"root_mod_id",
				""
			)
		)
	)

	var existing_raw: Variant = (
		_law().mod_registry.get(
			root_mod_id,
			{}
		)
	)

	if typeof(existing_raw) == TYPE_DICTIONARY:
		var existing: Dictionary = (
			existing_raw as Dictionary
		)
		var existing_components: Array = _array(
			existing.get(
				"bundle_component_ids",
				[]
			)
		)

		if (
			_id(
				str(
					existing.get(
						"bundle_id",
						""
					)
				)
			) == _id(bundle_id)
			and existing_components == selected
		):
			state ["root_mod_registered"] = true
			state ["root_mod_id"] = root_mod_id
			bundle_state_registry [bundle_id] = state

			return {
				"success": true,
				"schema": ENGINE_SCHEMA,
				"version": ENGINE_VERSION,
				"bundle_id": bundle_id,
				"mod_id": root_mod_id,
				"provider_topology_revision": (
					_law().provider_topology_revision
				)
			}

	var root_contract: Dictionary

	if (
		bundle_id
		== CavemanRealityBundlePack.BUNDLE_ID
	):
		root_contract = (
			CavemanRealityBundlePack
			.assembled_mod_contract(
				selected
			)
		)
	else:
		root_contract = _dict(
			bundle.get(
				"root_mod_contract",
				{}
			)
		)

	if root_contract.is_empty():
		return _failure(
			"missing_bundle_root_contract",
			(
				"The reality bundle does not define "
				+ "a root mod contract."
			)
		)

	var preserve_enabled: bool = bool(
		context.get(
			"preserve_enabled_state",
			true
		)
	)
	var should_enable: bool = (
		bool(
			state.get(
				"enabled",
				false
			)
		)
		if preserve_enabled
		else false
	)

	root_contract ["enabled"] = should_enable




	var registration: Dictionary = (
		_law().register_mod_contract(
			root_mod_id,
			root_contract,
			{
				"source": str(
					context.get(
						"source",
						"bundle_root_registration"
					)
				),
				"defer_resolution": true,
				"apply_runtime": false
			}
		)
	)

	state ["root_mod_registered"] = bool(
		registration.get(
			"success",
			false
		)
	)
	state ["root_mod_id"] = root_mod_id
	bundle_state_registry [bundle_id] = state

	return registration


func _set_bundle_runtime_enabled(
	bundle_id: String,
	enabled: bool,
	context: Dictionary
) -> Dictionary:
	if gs == null:
		return {}

	if (
		bundle_id
		== CavemanRealityBundlePack.BUNDLE_ID
	):
		if gs.caveman_reality_runtime_engine == null:
			return _failure(
				"missing_caveman_runtime",
				(
					"CavemanRealityRuntimeEngine "
					+ "is unavailable."
				)
			)

		return (
			gs.caveman_reality_runtime_engine
			.set_bundle_enabled(
				enabled,
				context
			)
		)

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"enabled": enabled,
	}


func _reconcile_dependent_authorities(
		context: Dictionary
) -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}





	gs.scenario_state [
		"reality_surface_revision"
	] = int(
		gs.scenario_state.get(
			"reality_surface_revision",
			0
		)
	) + 1

	gs.scenario_state [
		"last_reality_bundle_transition"
	] = context.duplicate(true)

	gs.scenario_state [
		"reality_bundle_transition_reconciliation_contract"
	] = {
		"ui_is_renderer_only": true
	}

func _clear_prepared_bundle_toggles(
	bundle_id: String
) -> void:
	var clean_bundle_id: String = _id(
		bundle_id
	)

	for raw_key in prepared_toggle_registry.keys():
		var key: String = str(raw_key)
		var row: Dictionary = _dict(
			prepared_toggle_registry.get(
				key,
				{}
			)
		)

		if str(
			row.get(
				"bundle_id",
				""
			)
		) == clean_bundle_id:
			prepared_toggle_registry.erase(key)


func _normalize_bundle_contract(
	raw: Dictionary
) -> Dictionary:
	var out: Dictionary = raw.duplicate(true)
	out ["schema"] = BUNDLE_SCHEMA
	out ["version"] = max(
		1,
		int(
			out.get(
				"version",
				BUNDLE_VERSION
			)
		)
	)
	out ["bundle_id"] = _id(
		str(
			out.get(
				"bundle_id",
				out.get(
					"id",
					""
				)
			)
		)
	)
	out ["root_mod_id"] = _id(
		str(
			out.get(
				"root_mod_id",
				""
			)
		)
	)
	out ["component_order"] = _string_array(
		out.get(
			"component_order",
			[]
		)
	)
	out ["all_in_one_component_ids"] = (
		_string_array(
			out.get(
				"all_in_one_component_ids",
				out.get(
					"component_order",
					[]
				)
			)
		)
	)
	out ["components"] = _dict(
		out.get(
			"components",
			{}
		)
	)
	out ["experience_contract"] = _dict(
		out.get(
			"experience_contract",
			{}
		)
	)
	out ["bundle_menu_contract"] = _dict(
		out.get(
			"bundle_menu_contract",
			{}
		)
	)
	out ["compatibility"] = _dict(
		out.get(
			"compatibility",
			{}
		)
	)
	out ["lifecycle"] = _dict(
		out.get(
			"lifecycle",
			{}
		)
	)
	out ["metadata"] = _dict(
		out.get(
			"metadata",
			{}
		)
	)

	return out


func _default_bundle_state(
	bundle: Dictionary
) -> Dictionary:
	var installed: bool = bool(
		bundle.get(
			"installed_by_default",
			false
		)
	)
	var enabled: bool = (
		bool(
			bundle.get(
				"enabled_by_default",
				false
			)
		)
		and installed
	)
	var selected: Array = (
		_array(
			bundle.get(
				"all_in_one_component_ids",
				[]
			)
		)
		if installed
		else []
	)

	return {
		"bundle_id": str(
			bundle.get(
				"bundle_id",
				""
			)
		),
		"root_mod_id": str(
			bundle.get(
				"root_mod_id",
				""
			)
		),
		"installed": installed,
		"enabled": enabled,
		"selected_component_ids": selected,
		"root_mod_registered": false,
		"installed_at_ms": 0,
		"last_enabled_at_ms": 0,
		"last_disabled_at_ms": 0,
		"last_uninstalled_at_ms": 0,
		"last_transition_source": ""
	}


func _valid_component_ids(
	bundle: Dictionary,
	requested: Array
) -> Array:
	var components: Dictionary = _dict(
		bundle.get(
			"components",
			{}
		)
	)
	var out: Array = []

	for raw_component_id in _array(
		bundle.get(
			"component_order",
			[]
		)
	):
		var component_id: String = _id(
			str(raw_component_id)
		)

		if (
			component_id in requested
			and components.has(component_id)
		):
			out.append(component_id)

	return out


func _prepared_toggle_key(
	bundle_id: String,
	enabled: bool,
	topology_revision: int
) -> String:
	return "%s::%s::%d" % [
		bundle_id,
		"enabled" if enabled else "disabled",
		topology_revision
	]


func _ensure_state_shape() -> void:
	if gs == null:
		return

	if typeof(
		gs.scenario_state
	) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var saved: Dictionary = _dict(
		gs.scenario_state.get(
			STATE_KEY,
			{}
		)
	)

	if not saved.is_empty():
		bundle_state_registry = _dict(
			saved.get(
				"bundle_state_registry",
				bundle_state_registry
			)
		)
		registry_revision = maxi(
			registry_revision,
			int(
				saved.get(
					"registry_revision",
					0
				)
			)
		)

	_publish_state()

func _publish_bundle_state_row(
		bundle_id: String,
		context: Dictionary = {}
) -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var clean_bundle_id: String = _id(
		bundle_id
	)
	var state_raw: Variant = (
		bundle_state_registry.get(
			clean_bundle_id,
			{}
		)
	)

	if typeof(state_raw) != TYPE_DICTIONARY:
		return

	var mirror_raw: Variant = gs.scenario_state.get(
		STATE_KEY,
		{}
	)
	var mirror: Dictionary = (
		mirror_raw as Dictionary
		if typeof(mirror_raw) == TYPE_DICTIONARY
		else {}
	)
	var rows_raw: Variant = mirror.get(
		"bundle_state_registry",
		{}
	)
	var rows: Dictionary = (
		rows_raw as Dictionary
		if typeof(rows_raw) == TYPE_DICTIONARY
		else {}
	)

	rows [clean_bundle_id] = (
		(state_raw as Dictionary).duplicate(true)
	)

	mirror ["schema"] = ENGINE_SCHEMA + ".state"
	mirror ["version"] = ENGINE_VERSION
	mirror ["bundle_state_registry"] = rows
	mirror ["registry_revision"] = registry_revision
	mirror ["last_transition_source"] = str(
		context.get(
			"source",
			"bundle_state_row_publish"
		)
	)
	mirror ["published_at_ms"] = int(
		Time.get_ticks_msec()
	)

	gs.scenario_state [STATE_KEY] = mirror
func _publish_state() -> void:
	if gs == null:
		return

	if typeof(
		gs.scenario_state
	) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	gs.scenario_state [STATE_KEY] = {
		"schema": ENGINE_SCHEMA + ".state",
		"version": ENGINE_VERSION,
		"bundle_state_registry": (
			bundle_state_registry.duplicate(true)
		),
		"registry_revision": registry_revision,
		"published_at_ms": int(
			Time.get_ticks_msec()
		)
	}


func _bundle(
	bundle_id: String
) -> Dictionary:
	return _dict(
		bundle_registry.get(
			_id(bundle_id),
			{}
		)
	)


func _bundle_state(
	bundle_id: String
) -> Dictionary:
	var clean_bundle_id: String = _id(
		bundle_id
	)
	var state: Dictionary = _dict(
		bundle_state_registry.get(
			clean_bundle_id,
			{}
		)
	)

	if state.is_empty():
		var bundle: Dictionary = _bundle(
			clean_bundle_id
		)

		if not bundle.is_empty():
			state = _default_bundle_state(
				bundle
			)
			bundle_state_registry [
				clean_bundle_id
			] = state

	return state


func _law():
	return (
		gs.mod_contract_engine
		if (
			gs != null
			and gs.mod_contract_engine != null
		)
		else null
	)


func _id(
	value: String
) -> String:
	var out: String = str(
		value
	).strip_edges().to_lower()

	for token in [
		" ",
		"/",
		"\\",
		":"
	]:
		out = out.replace(
			token,
			"_"
		)

	return out


func _string_array(
	value: Variant
) -> Array:
	var out: Array = []

	if typeof(value) != TYPE_ARRAY:
		return out

	for raw_value in value as Array:
		var clean: String = _id(
			str(raw_value)
		)

		if clean != "" and clean not in out:
			out.append(clean)

	return out


func _dict(
	value: Variant
) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return (
			value as Dictionary
		).duplicate(true)

	return {}


func _array(
	value: Variant
) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return (
			value as Array
		).duplicate(true)

	return []


func _failure(
	reason: String,
	text: String
) -> Dictionary:
	EraLog.failure(
		get_script().resource_path.get_file(),
		str(reason)
	)
	return {
		"success": false,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"reason": reason,
		"text": text,
		"ui_is_renderer_only": true
	}