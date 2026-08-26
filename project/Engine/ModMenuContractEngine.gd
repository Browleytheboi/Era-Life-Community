

extends RefCounted
class_name ModMenuContractEngine

const ENGINE_SCHEMA:= "eralife.mod_menu_contract_engine"
const ENGINE_VERSION:= 1
const MENU_SCHEMA:= "eralife.mod_menu_contract"
const MENU_VERSION:= 1
const LENS_STATE_KEY:= "mod_menu_lens_state"

var gs
var last_report: Dictionary = {}


func _init(
	_gs = null
) -> void:
	gs = _gs


func bootstrap_default_contracts() -> Dictionary:
	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"hub_authority": "mod_hub_contract_engine",
		"ui_is_renderer_only": true
	}


func resolve_intent(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _failure(
			"missing_actor",
			"No Mod Menu observer could be resolved."
		)

	var action_id: String = str(
		payload.get(
			"action_id",
			payload.get(
				"intent_type",
				"refresh"
			)
		)
	).strip_edges().to_lower()
	var lens: Dictionary = _lens_for(actor)
	var lens_persistence_only: bool = bool(
		payload.get(
			"lens_persistence_only",
			false
		)
	)
	var result: Dictionary

	match action_id:
		"observe_partial":
			result = {
				"success": true,
				"type": "mod_menu_observable_projection"
			}
			result ["mod_menu_contract"] = (
				emit_observable_contract(
					actor,
					{
						"active_section": str(
							payload.get(
								"section_id",
								lens.get(
									"active_section",
									"bundles"
								)
							)
						),
						"status_text": str(
							payload.get(
								"status_text",
								"Mod reality is becoming observable."
							)
						)
					}
				)
			)

		"refresh", "open_menu":
			lens ["active_surface_mode"] = "global_hub"
			lens ["active_bundle_id"] = ""
			_commit_lens(
				actor,
				lens
			)

			result = {
				"success": true,
				"type": "mod_menu_refreshed"
			}

		"set_section":
			lens ["active_section"] = _section(
				str(
					payload.get(
						"section_id",
						"bundles"
					)
				)
			)
			lens ["active_surface_mode"] = "global_hub"
			lens ["active_bundle_id"] = ""
			_commit_lens(
				actor,
				lens
			)

			result = {
				"success": true,
				"type": "mod_menu_section_changed",
				"active_section": str(
					lens.get(
						"active_section",
						"bundles"
					)
				),
				"simulation_mutation_performed": false
			}

		"set_bundle_section":
			var persisted_bundle_id: String = str(
				payload.get(
					"bundle_id",
					lens.get(
						"active_bundle_id",
						""
					)
				)
			).strip_edges().to_lower()
			var persisted_bundle_section: String = str(
				payload.get(
					"section_id",
					lens.get(
						"bundle_section",
						"overview"
					)
				)
			).strip_edges().to_lower()

			if persisted_bundle_section == "":
				persisted_bundle_section = "overview"

			lens ["active_surface_mode"] = "bundle_menu"
			lens ["active_bundle_id"] = persisted_bundle_id
			lens ["bundle_section"] = persisted_bundle_section
			_commit_lens(
				actor,
				lens
			)

			result = {
				"success": true,
				"type": "mod_bundle_menu_section_changed",
				"bundle_id": persisted_bundle_id,
				"active_section": persisted_bundle_section,
				"simulation_mutation_performed": false
			}

		"open_bundle_menu", "refresh_bundle_menu":
			if _bundle_authority() == null:
				result = _failure(
					"missing_bundle_authority",
					(
						"The installable reality bundle "
						+ "authority is unavailable."
					)
				)
			else:
				var active_bundle_id: String = str(
					payload.get(
						"bundle_id",
						lens.get(
							"active_bundle_id",
							""
						)
					)
				).strip_edges().to_lower()
				var bundle_section: String = str(
					payload.get(
						"bundle_section",
						payload.get(
							"section_id",
							lens.get(
								"bundle_section",
								"overview"
							)
						)
					)
				).strip_edges().to_lower()

				if bundle_section == "":
					bundle_section = "overview"

				var bundle_contract: Dictionary = (
					_bundle_authority().bundle_menu_contract(
						active_bundle_id,
						actor,
						{
							"active_section": bundle_section,
							"source": (
								"mod_menu_contract_engine.bundle_menu"
							)
						}
					)
				)

				if not bool(
					bundle_contract.get(
						"success",
						false
					)
				):
					result = _failure(
						str(
							bundle_contract.get(
								"reason",
								"bundle_menu_unavailable"
							)
						),
						str(
							bundle_contract.get(
								"text",
								(
									"The requested bundle menu "
									+ "could not be resolved."
								)
							)
						)
					)
				else:
					lens ["active_surface_mode"] = "bundle_menu"
					lens ["active_bundle_id"] = active_bundle_id
					lens ["bundle_section"] = str(
						bundle_contract.get(
							"active_section",
							bundle_section
						)
					)
					_commit_lens(
						actor,
						lens
					)

					result = {
						"success": true,
						"type": "mod_bundle_menu_resolved",
						"bundle_id": active_bundle_id,
						"mod_menu_contract": (
							_menu_from_bundle_contract(
								actor,
								bundle_contract,
								{
									"active_section": str(
										bundle_contract.get(
											"active_section",
											bundle_section
										)
									),
									"source": (
										"mod_menu_contract_engine."
										+ "resolve_intent"
									)
								}
							)
						)
					}

		_:
			if _hub() == null:
				result = _failure(
					"missing_mod_hub",
					"The Mod Hub authority is unavailable."
				)
			else:
				result = _hub().resolve_intent(
					actor,
					payload
				)




	if bool(
		result.get(
			"success",
			false
		)
	):
		if action_id in [
			"enable_bundle",
			"install_bundle"
		]:
			var activated_bundle_id: String = str(
				result.get(
					"bundle_id",
					payload.get(
						"bundle_id",
						""
					)
				)
			).strip_edges().to_lower()
			var bundle_is_live: bool = bool(
				result.get(
					"enabled",
					payload.get(
						"enable_after_install",
						action_id == "enable_bundle"
					)
				)
			)

			if (
				activated_bundle_id != ""
				and bundle_is_live
			):
				lens ["active_surface_mode"] = (
					"bundle_menu"
				)
				lens ["active_bundle_id"] = (
					activated_bundle_id
				)
				lens ["bundle_section"] = str(
					payload.get(
						"bundle_section",
						"roles"
					)
				).strip_edges().to_lower()

				if str(
					lens.get(
						"bundle_section",
						""
					)
				) == "":
					lens ["bundle_section"] = "roles"

				_commit_lens(
					actor,
					lens
				)

		elif action_id in [
			"disable_bundle",
			"uninstall_bundle"
		]:
			lens ["active_surface_mode"] = "global_hub"
			lens ["active_bundle_id"] = ""
			lens ["bundle_section"] = "overview"

			_commit_lens(
				actor,
				lens
			)
	if bool(result.get("success", false)):
		var reality_surface: Dictionary = _dict(
			result.get("reality_surface_contract", {})
		)

		if reality_surface.is_empty():
			reality_surface = _dict(
				_dict(result.get("transition", {})).get(
					"reality_surface_contract",
					{}
				)
			)

		if (
			reality_surface.is_empty()
			and _bundle_authority() != null
		):
			reality_surface = _bundle_authority().reality_surface_contract(
				str(payload.get("bundle_id", result.get("bundle_id", ""))),
				actor,
				{
					"source": "mod_menu_contract_engine.resolve_intent"
				}
			)

		if not reality_surface.is_empty():
			result ["reality_surface_contract"] = reality_surface.duplicate(true)
	if (
		not result.has("mod_menu_contract")
		and not lens_persistence_only
	):
		var active_surface_mode: String = str(
			lens.get(
				"active_surface_mode",
				"global_hub"
			)
		).strip_edges().to_lower()
		var active_bundle_id: String = str(
			lens.get(
				"active_bundle_id",
				""
			)
		).strip_edges().to_lower()

		if (
			active_surface_mode == "bundle_menu"
			and active_bundle_id != ""
			and _bundle_authority() != null
		):
			var bundle_section: String = str(
				lens.get(
					"bundle_section",
					"overview"
				)
			).strip_edges().to_lower()
			var bundle_contract: Dictionary = (
				_bundle_authority().bundle_menu_contract(
					active_bundle_id,
					actor,
					{
						"active_section": bundle_section,
						"status_text": str(
							result.get(
								"text",
								""
							)
						),
						"source": (
							"mod_menu_contract_engine."
							+ "resolve_active_bundle_after_intent"
						)
					}
				)
			)

			if bool(
				bundle_contract.get(
					"success",
					false
				)
			):
				result ["mod_menu_contract"] = (
					_menu_from_bundle_contract(
						actor,
						bundle_contract,
						{
							"active_section": bundle_section,
							"source": (
								"mod_menu_contract_engine."
								+ "resolve_active_bundle_after_intent"
							)
						}
					)
				)

		if not result.has("mod_menu_contract"):
			result ["mod_menu_contract"] = emit_menu_contract(
				actor,
				{
					"active_section": str(
						payload.get(
							"section_id",
							lens.get(
								"active_section",
								"bundles"
							)
						)
					),
					"status_text": str(
						result.get(
							"text",
							""
						)
					),
					"source": str(
						payload.get(
							"source",
							"mod_menu_contract_engine.resolve_intent"
						)
					)
				}
			)

	result ["mod_menu_contract_engine_owned"] = true
	result ["ui_is_renderer_only"] = true
	last_report = result.duplicate(true)

	return result


func emit_observable_contract(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	var hub_contract: Dictionary = {}

	if _hub() != null:
		hub_contract = _hub().emit_observable_contract(
			actor,
			context
		)

	return _menu_from_hub_contract(
		actor,
		hub_contract,
		context
	)


func emit_menu_contract(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	var hub_contract: Dictionary = {}

	if _hub() != null:
		hub_contract = _hub().emit_mod_hub_contract(
			actor,
			context
		)
	else:
		hub_contract = {
			"truth_state": "observable_partial",
			"installed_mods": [],
			"available_mods": [],
			"modded_systems": [],
			"conflicts": [],
			"section_tabs": []
		}

	return _menu_from_hub_contract(
		actor,
		hub_contract,
		context
	)


func export_state() -> Dictionary:
	return {
		"schema": ENGINE_SCHEMA + ".state",
		"version": ENGINE_VERSION,
		"lens_state": _lens_root(),
		"last_report": last_report.duplicate(true)
	}


func import_state(
	data: Dictionary = {}
) -> Dictionary:
	if gs != null:
		if typeof(gs.scenario_state) != TYPE_DICTIONARY:
			gs.scenario_state = {}

		gs.scenario_state [LENS_STATE_KEY] = _dict(
			data.get(
				"lens_state",
				{}
			)
		)

	last_report = _dict(
		data.get(
			"last_report",
			{}
		)
	)

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION
	}


func _menu_from_hub_contract(
	actor: Person,
	hub_contract: Dictionary,
	context: Dictionary
) -> Dictionary:
	var lens: Dictionary = _lens_for(actor)
	var active_section: String = _section(
		str(
			context.get(
				"active_section",
				lens.get(
					"active_section",
					"bundles"
				)
			)
		)
	)

	var installed_mods: Array = _array(
		hub_contract.get(
			"installed_mods",
			[]
		)
	)
	var available_mods: Array = _array(
		hub_contract.get(
			"available_mods",
			[]
		)
	)
	var systems: Array = _array(
		hub_contract.get(
			"modded_systems",
			[]
		)
	)
	var conflicts: Array = _array(
		hub_contract.get(
			"conflicts",
			[]
		)
	)
	var section_surfaces: Dictionary = {
		"bundles": _bundle_rows(
			_array(
				hub_contract.get(
					"reality_bundles",
					[]
				)
			)
		),
		"installed": _installed_rows(
			installed_mods
		),
		"marketplace": _marketplace_rows(
			available_mods
		),
		"systems": _system_rows(
			systems
		),
		"conflicts": _conflict_rows(
			conflicts
		),
		"settings": _settings_rows(
			installed_mods
		)
	}

	if not section_surfaces.has(active_section):
		active_section = (
			"bundles"
			if section_surfaces.has("bundles")
			else "installed"
		)

	lens ["active_section"] = active_section
	lens ["active_surface_mode"] = "global_hub"
	lens ["active_bundle_id"] = ""
	_commit_lens(
		actor,
		lens
	)

	var status_text: String = str(
		context.get(
			"status_text",
			""
		)
	).strip_edges()

	if status_text == "":
		status_text = str(
			hub_contract.get(
				"status_text",
				""
			)
		)

	var reality_presentation: Dictionary = (
		gs.era_contract_engine.presentation_contract()
		if (
			gs != null
			and gs.era_contract_engine != null
		)
		else {}
	)

	return {
		"success": true,
		"schema": MENU_SCHEMA,
		"version": MENU_VERSION,
		"actor_id": (
			int(actor.id)
			if actor != null
			else -1
		),
		"actor_name": str(
			hub_contract.get(
				"actor_name",
				"Current Life"
			)
		),
		"title": "🧩 MOD MENU",
		"subtitle": (
			"Install realities, control providers, and inspect "
			+ "conflicts without exposing simulation state to UI."
		),
		"surface_mode": "global_hub",
		"active_bundle_id": "",
		"active_section": active_section,
		"identity_overview": _dict(
			hub_contract.get(
				"identity_overview",
				{}
			)
		),
		"section_tabs": _array(
			hub_contract.get(
				"section_tabs",
				_default_tabs()
			)
		),
		"section_surfaces": section_surfaces,
		"section_rows": _array(
			section_surfaces.get(
				active_section,
				[]
			)
		),
		"installed_mods": installed_mods,
		"available_mods": available_mods,
		"modded_systems": systems,
		"conflicts": conflicts,
		"performance_budget": _dict(
			hub_contract.get(
				"performance_budget",
				{}
			)
		),
		"presentation": reality_presentation,
		"reality_presentation": reality_presentation,
		"toolbar_actions": [
			{
				"action_id": "reload_mods",
				"label": "Reload Sources",
				"icon": "↻",
				"enabled": true
			}
		],
		"status_text": status_text,
		"truth_state": str(
			hub_contract.get(
				"truth_state",
				"observable_partial"
			)
		),
		"authoritative_projection": bool(
			hub_contract.get(
				"authoritative_projection",
				false
			)
		),
		"surface_revision": str(
			hub_contract.get(
				"surface_revision",
				"mod_menu:observable"
			)
		),
		"ui_is_renderer_only": true
	}

func _menu_from_bundle_contract(
	actor: Person,
	bundle_contract: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	if bundle_contract.is_empty():
		return _failure(
			"missing_bundle_menu_contract",
			"No bundle menu contract could be resolved."
		)

	var bundle_id: String = str(
		bundle_contract.get(
			"bundle_id",
			""
		)
	).strip_edges().to_lower()
	var bundle_installed: bool = bool(
		bundle_contract.get(
			"bundle_installed",
			true
		)
	)
	var bundle_enabled: bool = bool(
		bundle_contract.get(
			"bundle_enabled",
			true
		)
	)
	var section_tabs: Array = _array(
		bundle_contract.get(
			"section_tabs",
			[]
		)
	)
	var section_surfaces: Dictionary = _dict(
		bundle_contract.get(
			"section_surfaces",
			{}
		)
	)
	var active_section: String = str(
		context.get(
			"active_section",
			bundle_contract.get(
				"active_section",
				"overview"
			)
		)
	).strip_edges().to_lower()

	if (
		active_section == ""
		or not section_surfaces.has(
			active_section
		)
	):
		active_section = ""

		for raw_tab in section_tabs:
			if typeof(
				raw_tab
			) != TYPE_DICTIONARY:
				continue

			var tab: Dictionary = (
				raw_tab as Dictionary
			)
			var tab_id: String = str(
				tab.get(
					"id",
					""
				)
			).strip_edges().to_lower()

			if (
				tab_id != ""
				and section_surfaces.has(
					tab_id
				)
			):
				active_section = tab_id
				break

	if active_section == "":
		if section_surfaces.has(
			"overview"
		):
			active_section = "overview"
		elif not section_surfaces.is_empty():
			active_section = str(
				section_surfaces.keys().front()
			)

	var base_reality_presentation: Dictionary = (
		gs.era_contract_engine.presentation_contract()
		if (
			gs != null
			and gs.era_contract_engine != null
		)
		else {}
	)
	var reality_surface_contract: Dictionary = _dict(
		bundle_contract.get(
			"reality_surface_contract",
			{}
		)
	)
	var effective_bundle_presentation: Dictionary = _dict(
		bundle_contract.get(
			"presentation",
			{}
		)
	)

	if effective_bundle_presentation.is_empty():
		effective_bundle_presentation = _dict(
			reality_surface_contract.get(
				"presentation",
				{}
			)
		)

	if effective_bundle_presentation.is_empty():
		effective_bundle_presentation = (
			base_reality_presentation.duplicate(true)
		)

	var bundle_toolbar_actions: Array = [
		{
			"action_id": "open_menu",
			"label": "All Mods",
			"icon": "←",
			"enabled": true
		}
	]

	bundle_toolbar_actions.append_array(
		_array(
			bundle_contract.get(
				"toolbar_actions",
				[]
			)
		)
	)

	var surface_revision: String = str(
		bundle_contract.get(
			"surface_revision",
			""
		)
	).strip_edges()

	if surface_revision == "":
		surface_revision = (
			"bundle_menu:%s:%s:%d:%d"
			% [
				bundle_id,
				str(bundle_enabled),
				section_tabs.size(),
				section_surfaces.size()
			]
		)

	var bundle_control: Dictionary = {
		"schema": (
			"eralife.mod_bundle_toggle_contract"
		),
		"version": 1,
		"visible": true,
		"bundle_id": bundle_id,
		"label": (
			"Caveman Reality"
			if bundle_id
			== CavemanRealityBundlePack.BUNDLE_ID
			else "Reality"
		),
		"installed": bundle_installed,
		"enabled": bundle_enabled,
		"toggle_enabled": bundle_installed,
		"runtime_state_preserved": true,
		"tooltip": (
			"Disable this reality while preserving "
			+ "its complete runtime history."
			if bundle_enabled
			else (
				"Enable this reality and reconnect "
				+ "its preserved runtime."
			)
		),
		"ui_is_expression_only": true
	}

	return {
		"success": true,
		"schema": MENU_SCHEMA,
		"version": MENU_VERSION,
		"actor_id": (
			int(actor.id)
			if actor != null
			else -1
		),
		"actor_name": str(
			bundle_contract.get(
				"actor_name",
				"Current Life"
			)
		),
		"title": str(
			bundle_contract.get(
				"title",
				"REALITY BUNDLE"
			)
		),
		"subtitle": str(
			bundle_contract.get(
				"subtitle",
				(
					"Control the active systems exposed "
					+ "by this installable reality."
				)
			)
		),
		"surface_mode": "bundle_menu",
		"active_bundle_id": bundle_id,
		"bundle_installed": bundle_installed,
		"bundle_enabled": bundle_enabled,
		"bundle_control": bundle_control,
		"active_section": active_section,
		"identity_overview": _dict(
			bundle_contract.get(
				"identity_overview",
				{}
			)
		),
		"section_tabs": section_tabs,
		"section_surfaces": section_surfaces,
		"section_rows": _array(
			section_surfaces.get(
				active_section,
				[]
			)
		),
		"reality_surface_contract": (
			reality_surface_contract.duplicate(true)
		),
		"presentation": (
			effective_bundle_presentation.duplicate(true)
		),
		"reality_presentation": (
			effective_bundle_presentation.duplicate(true)
		),
		"toolbar_actions": bundle_toolbar_actions,
		"window_contract": {
			"schema": (
				"eralife.mod_bundle_window_contract"
			),
			"version": 2,
			"window_id": (
				"acrellos_mods:%s"
				% bundle_id
			),
			"host_title": "Acrello's Mods",
			"display_mode": (
				"floating_non_embedded"
			),
			"initial_size": {
				"x": 410.0,
				"y": 600.0
			},
			"expanded_size": {
				"x": 720.0,
				"y": 720.0
			},
			"minimum_size": {
				"x": 360.0,
				"y": 340.0
			},
			"maximum_size": {
				"x": 920.0,
				"y": 840.0
			},
			"draggable": true,
			"resizable": true,
			"expandable": true,
			"minimizable": true,
			"restore_on_minimized_click": true,
			"build_on_click_forbidden": true,
			"bundle_control": (
				bundle_control.duplicate(true)
			),
			"ui_is_renderer_only": true
		},
		"status_text": str(
			bundle_contract.get(
				"status_text",
				(
					"Reality bundle controls are observable."
				)
			)
		),
		"truth_state": str(
			bundle_contract.get(
				"truth_state",
				"hot"
			)
		),
		"authoritative_projection": bool(
			bundle_contract.get(
				"authoritative_projection",
				true
			)
		),
		"surface_revision": surface_revision,
		"bundle_menu_contract": (
			bundle_contract.duplicate(true)
		),
		"ui_is_renderer_only": true
	}
func _installed_rows(
	installed_mods: Array
) -> Array:
	var rows: Array = []

	for raw_mod in installed_mods:
		if typeof(raw_mod) != TYPE_DICTIONARY:
			continue

		var mod: Dictionary = raw_mod as Dictionary
		var enabled: bool = bool(
			mod.get(
				"enabled",
				false
			)
		)

		rows.append({
			"row_kind": "installed_mod",
			"id": str(
				mod.get(
					"mod_id",
					""
				)
			),
			"mod_id": str(
				mod.get(
					"mod_id",
					""
				)
			),
			"title": str(
				mod.get(
					"name",
					mod.get(
						"mod_id",
						"Mod"
					)
				)
			),
			"subtitle": "%s • v%s" % [
				str(
					mod.get(
						"author",
						"Unknown creator"
					)
				),
				str(
					mod.get(
						"release_version",
						"1.0.0"
					)
				)
			],
			"description": str(
				mod.get(
					"description",
					""
				)
			),
			"chips": [
				"%d providers" % int(
					mod.get(
						"provider_count",
						0
					)
				),
				"%d active" % int(
					mod.get(
						"active_provider_count",
						0
					)
				),
				str(
					mod.get(
						"lifecycle_state",
						"installed"
					)
				).capitalize()
			],
			"actions": [
				{
					"action_id": (
						"disable_mod"
						if enabled
						else "enable_mod"
					),
					"label": (
						"Disable"
						if enabled
						else "Enable"
					),
					"mod_id": str(
						mod.get(
							"mod_id",
							""
						)
					),
					"enabled": true
				},
				{
					"action_id": "uninstall_mod",
					"label": "Uninstall",
					"mod_id": str(
						mod.get(
							"mod_id",
							""
						)
					),
					"enabled": true,
				}
			],
			"enabled": enabled,
			"ui_is_renderer_only": true
		})

	return rows


func _marketplace_rows(
	available_mods: Array
) -> Array:
	var rows: Array = []

	for raw_mod in available_mods:
		if typeof(raw_mod) != TYPE_DICTIONARY:
			continue

		var mod: Dictionary = raw_mod as Dictionary
		var compatibility: Dictionary = _dict(
			mod.get(
				"compatibility",
				{}
			)
		)
		var compatible: bool = bool(
			compatibility.get(
				"compatible",
				true
			)
		)
		var installed: bool = bool(
			mod.get(
				"installed",
				false
			)
		)

		rows.append({
			"row_kind": "marketplace_mod",
			"id": str(
				mod.get(
					"mod_id",
					""
				)
			),
			"mod_id": str(
				mod.get(
					"mod_id",
					""
				)
			),
			"title": str(
				mod.get(
					"name",
					mod.get(
						"mod_id",
						"Mod"
					)
				)
			),
			"subtitle": "%s • v%s" % [
				str(
					mod.get(
						"author",
						"Unknown creator"
					)
				),
				str(
					mod.get(
						"release_version",
						"1.0.0"
					)
				)
			],
			"description": str(
				mod.get(
					"description",
					""
				)
			),
			"chips": [
				"★ %.1f" % float(
					mod.get(
						"rating",
						0.0
					)
				),
				"%d installs" % int(
					mod.get(
						"downloads",
						0
					)
				),
				str(
					compatibility.get(
						"status",
						"compatible"
					)
				).capitalize()
			],
			"actions": [
				{
					"action_id": "install_mod",
					"label": (
						"Installed"
						if installed
						else "Install"
					),
					"mod_id": str(
						mod.get(
							"mod_id",
							""
						)
					),
					"marketplace_row": mod.duplicate(true),
					"enabled": (
						compatible
						and not installed
					)
				}
			],
			"enabled": compatible,
			"disabled_reason": "\n".join(
				_array(
					compatibility.get(
						"reasons",
						[]
					)
				)
			),
			"ui_is_renderer_only": true
		})

	return rows
func _bundle_authority():
	return (
		gs.mod_bundle_contract_engine
		if (
			gs != null
			and gs.mod_bundle_contract_engine != null
		)
		else null
	)
func _bundle_rows(
	reality_bundles: Array
) -> Array:
	var rows: Array = []

	for raw_bundle in reality_bundles:
		if typeof(raw_bundle) != TYPE_DICTIONARY:
			continue

		var bundle: Dictionary = (
			raw_bundle as Dictionary
		).duplicate(true)
		var bundle_id: String = str(
			bundle.get(
				"bundle_id",
				""
			)
		)
		var installed: bool = bool(
			bundle.get(
				"installed",
				false
			)
		)
		var enabled: bool = bool(
			bundle.get(
				"enabled",
				false
			)
		)
		var actions: Array = []

		if not installed:
			actions.append({
				"action_id": "install_bundle",
				"label": "Install All-in-One",
				"bundle_id": bundle_id,
				"enable_after_install": true,
				"enabled": true
			})
			actions.append({
				"action_id": "open_bundle_menu",
				"label": "Choose Components",
				"bundle_id": bundle_id,
				"bundle_section": "components",
				"enabled": true
			})
		else:
			actions.append({
				"action_id": (
					"disable_bundle"
					if enabled
					else "enable_bundle"
				),
				"label": (
					"Disable Reality"
					if enabled
					else "Enable Reality"
				),
				"bundle_id": bundle_id,
				"enabled": true
			})
			actions.append({
				"action_id": "open_bundle_menu",
				"label": (
					"Open Reality Menu"
					if enabled
					else "Manage Components"
				),
				"bundle_id": bundle_id,
				"bundle_section": (
					"roles"
					if enabled
					else "components"
				),
				"enabled": true
			})
			actions.append({
				"action_id": "uninstall_bundle",
				"label": "Uninstall",
				"bundle_id": bundle_id,
				"enabled": true,
			})

		rows.append({
			"row_kind": "reality_bundle",
			"id": bundle_id,
			"bundle_id": bundle_id,
			"title": str(
				bundle.get(
					"name",
					"Reality Bundle"
				)
			),
			"subtitle": (
				"LIVE REALITY • %s"
				% (
					"ENABLED"
					if enabled
					else "INSTALLED"
					if installed
					else "AVAILABLE"
				)
			),
			"description": str(
				bundle.get(
					"description",
					""
				)
			),
			"chips": [
				"%d/%d components" % [
					int(
						bundle.get(
							"installed_component_count",
							0
						)
					),
					int(
						bundle.get(
							"component_count",
							0
						)
					)
				],
				"Hot-Swappable",
				"Identity-Safe"
			],
			"actions": actions,
			"enabled": enabled,
			"installed": installed,
			"ui_is_renderer_only": true
		})

	return rows

func _system_rows(
	systems: Array
) -> Array:
	var rows: Array = []

	for raw_system in systems:
		if typeof(raw_system) != TYPE_DICTIONARY:
			continue

		var system: Dictionary = raw_system as Dictionary
		rows.append({
			"row_kind": "modded_system",
			"id": str(
				system.get(
					"target_key",
					""
				)
			),
			"title": "%s → %s" % [
				str(
					system.get(
						"provider_type",
						"system"
					)
				).capitalize(),
				str(
					system.get(
						"target_id",
						"default"
					)
				)
			],
			"subtitle": str(
				system.get(
					"resolution_policy",
					"namespace"
				)
			).capitalize(),
			"description": (
				"%d active provider contract(s)." % int(
					system.get(
						"active_count",
						0
					)
				)
			),
			"chips": _array(
				system.get(
					"active_provider_keys",
					[]
				)
			),
			"actions": [],
			"enabled": not bool(
				system.get(
					"blocked",
					false
				)
			),
			"ui_is_renderer_only": true
		})

	return rows


func _conflict_rows(
	conflicts: Array
) -> Array:
	var rows: Array = []

	for raw_conflict in conflicts:
		if typeof(raw_conflict) != TYPE_DICTIONARY:
			continue

		var conflict: Dictionary = raw_conflict as Dictionary
		rows.append({
			"row_kind": "mod_conflict",
			"id": str(
				conflict.get(
					"target_key",
					"conflict"
				)
			),
			"title": str(
				conflict.get(
					"target_key",
					"Provider conflict"
				)
			),
			"subtitle": str(
				conflict.get(
					"resolution_policy",
					"blocked"
				)
			).capitalize(),
			"description": str(
				conflict.get(
					"reason",
					(
						"Multiple providers target the "
						+ "same contract surface."
					)
				)
			),
			"chips": _array(
				conflict.get(
					"candidate_provider_keys",
					[]
				)
			),
			"actions": [],
			"enabled": false,
			"ui_is_renderer_only": true
		})

	return rows


func _settings_rows(
	installed_mods: Array
) -> Array:
	var rows: Array = []

	for raw_mod in installed_mods:
		if typeof(raw_mod) != TYPE_DICTIONARY:
			continue

		var mod: Dictionary = raw_mod as Dictionary
		var mod_id: String = str(
			mod.get(
				"mod_id",
				""
			)
		)
		var schema: Dictionary = _dict(
			mod.get(
				"settings_schema",
				{}
			)
		)
		var values: Dictionary = _dict(
			mod.get(
				"settings",
				{}
			)
		)

		for raw_setting_id in schema.keys():
			var setting_id: String = str(
				raw_setting_id
			)
			var setting: Dictionary = _dict(
				schema.get(
					setting_id,
					{}
				)
			)

			rows.append({
				"row_kind": "mod_setting",
				"id": "%s::%s" % [
					mod_id,
					setting_id
				],
				"mod_id": mod_id,
				"setting_id": setting_id,
				"title": str(
					setting.get(
						"label",
						setting_id.capitalize()
					)
				),
				"subtitle": str(
					mod.get(
						"name",
						mod_id
					)
				),
				"description": str(
					setting.get(
						"description",
						""
					)
				),
				"setting_type": str(
					setting.get(
						"type",
						"string"
					)
				),
				"value": values.get(
					setting_id,
					setting.get("default")
				),
				"options": _array(
					setting.get(
						"options",
						[]
					)
				),
				"actions": [],
				"enabled": bool(
					mod.get(
						"enabled",
						false
					)
				),
				"ui_is_renderer_only": true
			})

	return rows


func _default_tabs() -> Array:
	return [
		{
			"id": "bundles",
			"label": "REALITY BUNDLES",
			"icon": "🌍"
		},
		{
			"id": "installed",
			"label": "INSTALLED",
			"icon": "✅"
		},
		{
			"id": "marketplace",
			"label": "MARKETPLACE",
			"icon": "🛍️"
		},
		{
			"id": "systems",
			"label": "SYSTEMS",
			"icon": "⚙️"
		},
		{
			"id": "conflicts",
			"label": "CONFLICTS",
			"icon": "⚠️"
		},
		{
			"id": "settings",
			"label": "SETTINGS",
			"icon": "🎛️"
		}
	]

func _section(
	value: String
) -> String:
	var clean: String = str(
		value
	).strip_edges().to_lower()

	if clean not in [
		"bundles",
		"installed",
		"marketplace",
		"systems",
		"conflicts",
		"settings"
	]:
		return "bundles"

	return clean


func _lens_for(
	actor: Person
) -> Dictionary:
	var root: Dictionary = _lens_root()
	var actor_key: String = str(
		int(actor.id)
	)
	var lens: Dictionary = _dict(
		root.get(
			actor_key,
			{}
		)
	)

	if lens.is_empty():
		lens = {
			"active_section": "bundles",
			"active_surface_mode": "global_hub",
			"active_bundle_id": "",
			"bundle_section": "overview"
		}

	if not lens.has("active_surface_mode"):
		lens ["active_surface_mode"] = "global_hub"

	if not lens.has("active_bundle_id"):
		lens ["active_bundle_id"] = ""

	if not lens.has("bundle_section"):
		lens ["bundle_section"] = "overview"

	return lens


func _commit_lens(
	actor: Person,
	lens: Dictionary
) -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var root: Dictionary = _lens_root()
	root [str(int(actor.id))] = lens.duplicate(true)
	gs.scenario_state [LENS_STATE_KEY] = root


func _lens_root() -> Dictionary:
	if (
		gs == null
		or typeof(
			gs.scenario_state
		) != TYPE_DICTIONARY
	):
		return {}

	return _dict(
		gs.scenario_state.get(
			LENS_STATE_KEY,
			{}
		)
	)


func _hub():
	return (
		gs.mod_hub_contract_engine
		if (
			gs != null
			and gs.mod_hub_contract_engine != null
		)
		else null
	)


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