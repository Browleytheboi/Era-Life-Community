extends Resource
class_name UIContractEngine

const UI_CONTRACT_VERSION:= 1
const UI_RUNTIME_VERSION:= 2

const PRESENTATION_DENSITY_CONTRACT_SCHEMA:= (
	"eralife.presentation_density_contract"
)
const PRESENTATION_DENSITY_CONTRACT_VERSION:= 1

const PRESENTATION_COMPOSITION_CONTRACT_SCHEMA:= (
	"eralife.presentation_composition_contract"
)
const PRESENTATION_COMPOSITION_CONTRACT_VERSION:= 1

const PRESENTATION_REFERENCE_WIDTH:= 1440.0
const PRESENTATION_REFERENCE_HEIGHT:= 900.0

const PRESENTATION_SCALE_MIN:= 0.8
const PRESENTATION_SCALE_MAX:= 8.0
const PRESENTATION_SCALE_QUANTIZATION:= 100.0

const SUPPORTED_SURFACE_TYPES:= [
	"button",
	"hub",
	"panel",
	"card",
	"list",
	"popup",
	"combat_ui",
	"debug_panel",
	"section",
	"action_lane"
]

const SUPPORTED_LAYOUTS:= [
	"button",
	"button_lane",
	"hub_sections",
	"scroll_list",
	"card_grid",
	"detail_panel",
	"popup",
	"combat_frame",
	"debug_text"
]

const SUPPORTED_DEVICE_PROFILES:= [
	"auto",
	"desktop",
	"tablet",
	"phone",
	"low_power"
]

var gs

var surface_registry: Dictionary = {}
var action_route_registry: Dictionary = {}
var data_source_registry: Dictionary = {}
var system_registry: Dictionary = {}
var validation_reports: Dictionary = {}
var last_resolution_report: Dictionary = {}

var active_section_by_surface: Dictionary = {}
var surface_runtime_state: Dictionary = {}
var last_action_report: Dictionary = {}
var device_profile_override: String = ""

var prewarmed_packet_cache: Dictionary = {}
var last_prewarm_report: Dictionary = {}

func _init(_gs = null):
	gs = _gs
	_ensure_core_surface_contracts()

func ingest_pack(pack: Dictionary) -> Dictionary:
	var report:= {
		"pack_id": str(pack.get("id", "runtime_pack")),
		"surfaces": [],
		"data_sources": [],
		"actions": [],
		"systems": [],
		"failed": []
	}

	for raw_system in _safe_dictionary_array(pack.get("systems", [])):
		var system_report: Dictionary = register_system_contract(raw_system)
		if bool(system_report.get("success", false)):
			report ["systems"].append(system_report.get("system_id", ""))
		else:
			report ["failed"].append(system_report)

	for raw_surface in _safe_dictionary_array(pack.get("ui_surfaces", pack.get("surfaces", []))):
		var normalized: Dictionary = normalize_surface_contract(raw_surface, str(pack.get("id", "runtime_pack")))
		var validation: Dictionary = normalized.get("validation", {})
		var surface_id: String = str(normalized.get("surface_id", "")).strip_edges()

		if surface_id == "" or not bool(validation.get("valid", false)):
			report ["failed"].append({
				"surface_id": surface_id,
				"validation": validation
			})
			continue

		surface_registry [surface_id] = normalized
		validation_reports [surface_id] = validation.duplicate(true)

		if bool(normalized.get("persistent_state", true)) and not active_section_by_surface.has(surface_id):
			var default_section_id: String = _first_section_id(normalized)
			if default_section_id != "":
				active_section_by_surface [surface_id] = default_section_id

		report ["surfaces"].append(surface_id)

	for raw_source in _safe_dictionary_array(pack.get("data_sources", [])):
		var source_id: String = str(raw_source.get("id", raw_source.get("data_source", ""))).strip_edges()
		if source_id == "":
			report ["failed"].append({ "reason": "Data source missing id."})
			continue
		data_source_registry [source_id] = raw_source.duplicate(true)
		report ["data_sources"].append(source_id)

	for raw_action in _safe_dictionary_array(pack.get("action_routes", pack.get("ui_actions", []))):
		var action_id: String = str(raw_action.get("id", raw_action.get("action_id", ""))).strip_edges()
		if action_id == "":
			report ["failed"].append({ "reason": "Action route missing id."})
			continue
		action_route_registry [action_id] = _normalize_action_contract(raw_action, str(raw_action.get("surface_id", "")))
		report ["actions"].append(action_id)

	return report

func register_system_contract(system_contract: Dictionary) -> Dictionary:
	var system_id: String = str(system_contract.get("system_id", system_contract.get("id", ""))).strip_edges()
	if system_id == "":
		return { "success": false, "reason": "System contract missing system_id."}

	var normalized:= {
		"system_id": system_id,
		"engine_property": str(system_contract.get("engine_property", "")).strip_edges(),
		"owner_pack": str(system_contract.get("owner_pack", "")).strip_edges(),
		"surfaces": _safe_string_array(system_contract.get("surfaces", [])),
		"data_sources": _safe_string_array(system_contract.get("data_sources", [])),
		"action_routes": _safe_string_array(system_contract.get("action_routes", [])),
		"scenario_contracts": _safe_string_array(system_contract.get("scenario_contracts", [])),
		"enabled": bool(system_contract.get("enabled", true)),
		"tags": _safe_string_array(system_contract.get("tags", [])),
		"validation": {
			"valid": true,
			"errors": [],
			"warnings": []
		}
	}

	system_registry [system_id] = normalized
	validation_reports ["system:%s" % system_id] = normalized ["validation"].duplicate(true)

	return {
		"success": true,
		"system_id": system_id
	}
func resolve_presentation_density_contract(
	context: Dictionary = {}
) -> Dictionary:
	return _resolve_presentation_density_contract_pure(
		context
	)


static func resolve_presentation_density_bootstrap_contract(
	context: Dictionary = {}
) -> Dictionary:
	return _resolve_presentation_density_contract_pure(
		context
	)


static func _resolve_presentation_density_contract_pure(
	context: Dictionary = {}
) -> Dictionary:
	var physical_width: float = maxf(
		1.0,
		float(
			context.get(
				"physical_viewport_width",
				PRESENTATION_REFERENCE_WIDTH
			)
		)
	)

	var physical_height: float = maxf(
		1.0,
		float(
			context.get(
				"physical_viewport_height",
				PRESENTATION_REFERENCE_HEIGHT
			)
		)
	)

	var safe_left: float = maxf(
		0.0,
		float(
			context.get(
				"safe_inset_left",
				0.0
			)
		)
	)

	var safe_top: float = maxf(
		0.0,
		float(
			context.get(
				"safe_inset_top",
				0.0
			)
		)
	)

	var safe_right: float = maxf(
		0.0,
		float(
			context.get(
				"safe_inset_right",
				0.0
			)
		)
	)

	var safe_bottom: float = maxf(
		0.0,
		float(
			context.get(
				"safe_inset_bottom",
				0.0
			)
		)
	)

	var usable_width: float = maxf(
		1.0,
		physical_width
		- safe_left
		- safe_right
	)

	var usable_height: float = maxf(
		1.0,
		physical_height
		- safe_top
		- safe_bottom
	)

	var width_density: float = (
		usable_width
		/ PRESENTATION_REFERENCE_WIDTH
	)

	var height_density: float = (
		usable_height
		/ PRESENTATION_REFERENCE_HEIGHT
	)

	var desktop_presentation: bool = bool(
		context.get(
			"desktop_presentation",
			false
		)
	)

	var raw_scale: float = (
		maxf(
			width_density,
			height_density
		)
		if desktop_presentation
		else minf(
			width_density,
			height_density
		)
	)

	var clamped_scale: float = clampf(
		raw_scale,
		PRESENTATION_SCALE_MIN,
		PRESENTATION_SCALE_MAX
	)

	var ui_scale: float = clamped_scale

	if not desktop_presentation:
		ui_scale = (
			round(
				clamped_scale
				* PRESENTATION_SCALE_QUANTIZATION
			)
			/ PRESENTATION_SCALE_QUANTIZATION
		)

		ui_scale = clampf(
			ui_scale,
			PRESENTATION_SCALE_MIN,
			PRESENTATION_SCALE_MAX
		)

	var logical_width: float = (
		usable_width
		/ ui_scale
	)

	var logical_height: float = (
		usable_height
		/ ui_scale
	)

	var aspect_ratio: float = (
		usable_width
		/ usable_height
	)

	var aspect_profile: String = "standard"

	if aspect_ratio < 1.5:
		aspect_profile = "compact"
	elif aspect_ratio >= 2.2:
		aspect_profile = "ultrawide"
	elif aspect_ratio >= 1.9:
		aspect_profile = "wide"

	var density_profile: String = "reference"

	if ui_scale < 0.95:
		density_profile = "compact"
	elif ui_scale >= 1.5:
		density_profile = "high"
	elif ui_scale > 1.05:
		density_profile = "expanded"

	return {
		"schema": PRESENTATION_DENSITY_CONTRACT_SCHEMA,
		"version": PRESENTATION_DENSITY_CONTRACT_VERSION,

		"reference_viewport": {
			"width": PRESENTATION_REFERENCE_WIDTH,
			"height": PRESENTATION_REFERENCE_HEIGHT
		},

		"physical_viewport": {
			"width": physical_width,
			"height": physical_height
		},

		"safe_insets": {
			"left": safe_left,
			"top": safe_top,
			"right": safe_right,
			"bottom": safe_bottom
		},

		"usable_viewport": {
			"width": usable_width,
			"height": usable_height
		},

		"logical_viewport": {
			"width": logical_width,
			"height": logical_height
		},

		"raw_scale": raw_scale,
		"ui_scale": ui_scale,
		"scale_min": PRESENTATION_SCALE_MIN,
		"scale_max": PRESENTATION_SCALE_MAX,

		"density_profile": density_profile,
		"aspect_ratio": aspect_ratio,
		"aspect_profile": aspect_profile,


		"desktop_width_is_canonical": (
			desktop_presentation
			and width_density >= height_density
		),

		"desktop_reference_width": (
			PRESENTATION_REFERENCE_WIDTH
		),


		"desktop_reference_box_is_cover_scaled": (
			desktop_presentation
		),

		"desktop_letterbox_forbidden": (
			desktop_presentation
		),

		"desktop_extra_logical_canvas_forbidden": (
			desktop_presentation
		),

		"composition_measure_owned_by": (
			PRESENTATION_COMPOSITION_CONTRACT_SCHEMA
		),


		"platform": str(
			context.get(
				"platform",
				""
			)
		),

		"display_server": str(
			context.get(
				"display_server",
				""
			)
		),

		"source": str(
			context.get(
				"source",
				"presentation_density"
			)
		),

		"ui_is_expression_only": true,
	}
func resolve_presentation_composition_contract(
	context: Dictionary = {}
) -> Dictionary:
	return _resolve_presentation_composition_contract_pure(
		context
	)


static func resolve_presentation_composition_bootstrap_contract(
	context: Dictionary = {}
) -> Dictionary:
	return _resolve_presentation_composition_contract_pure(
		context
	)


static func _resolve_presentation_composition_contract_pure(
	context: Dictionary = {}
) -> Dictionary:
	var logical_width: float = maxf(
		1.0,
		float(
			context.get(
				"logical_viewport_width",
				PRESENTATION_REFERENCE_WIDTH
			)
		)
	)

	var logical_height: float = maxf(
		1.0,
		float(
			context.get(
				"logical_viewport_height",
				PRESENTATION_REFERENCE_HEIGHT
			)
		)
	)

	var aspect_ratio: float = float(
		context.get(
			"aspect_ratio",
			logical_width / logical_height
		)
	)

	var aspect_profile: String = str(
		context.get(
			"aspect_profile",
			""
		)
	).strip_edges().to_lower()

	if aspect_profile not in [
		"compact",
		"standard",
		"wide",
		"ultrawide"
	]:
		aspect_profile = "standard"

		if aspect_ratio < 1.5:
			aspect_profile = "compact"
		elif aspect_ratio >= 2.2:
			aspect_profile = "ultrawide"
		elif aspect_ratio >= 1.9:
			aspect_profile = "wide"

	var stage_left: float = 0.0
	var stage_top: float = 0.0
	var stage_width: float = logical_width
	var stage_height: float = logical_height
	var stage_right: float = stage_width
	var stage_bottom: float = stage_height

	var choose_adventure_occupancy_ratio: float = 0.85
	var choose_adventure_card_count: int = 3
	var choose_adventure_card_separation: float = 22.0
	var choose_adventure_card_minimum_width: float = 350.0
	var choose_adventure_card_minimum_height: float = 570.0

	var choose_adventure_minimum_shell_width: float = minf(
		logical_width,
		(
			choose_adventure_card_minimum_width
			* float(choose_adventure_card_count)
		)
		+ (
			choose_adventure_card_separation
			* float(
				maxi(
					0,
					choose_adventure_card_count - 1
				)
			)
		)
	)

	var choose_adventure_minimum_shell_height: float = minf(
		logical_height,
		choose_adventure_card_minimum_height
	)

	var choose_adventure_shell_width: float = minf(
		logical_width,
		maxf(
			choose_adventure_minimum_shell_width,
			logical_width
			* choose_adventure_occupancy_ratio
		)
	)

	var choose_adventure_shell_height: float = minf(
		logical_height,
		maxf(
			choose_adventure_minimum_shell_height,
			logical_height
			* choose_adventure_occupancy_ratio
		)
	)

	var menu_horizontal_gutter: float = maxf(
		0.0,
		(
			logical_width
			- choose_adventure_shell_width
		)
		* 0.5
	)

	var menu_vertical_gutter: float = maxf(
		0.0,
		(
			logical_height
			- choose_adventure_shell_height
		)
		* 0.5
	)

	var god_mode_outer_gutter: float = 0.0
	var god_mode_panel_width: float = logical_width
	var god_mode_panel_height: float = logical_height
	var god_mode_panel_left: float = 0.0
	var god_mode_panel_top: float = 0.0

	return {
		"schema": PRESENTATION_COMPOSITION_CONTRACT_SCHEMA,
		"version": PRESENTATION_COMPOSITION_CONTRACT_VERSION,

		"logical_viewport": {
			"width": logical_width,
			"height": logical_height
		},

		"aspect_ratio": aspect_ratio,
		"aspect_profile": aspect_profile,

		"canonical_stage": {
			"left": stage_left,
			"top": stage_top,
			"right": stage_right,
			"bottom": stage_bottom,
			"width": stage_width,
			"height": stage_height
		},

		"startup_intro": {
			"left": stage_left,
			"top": stage_top,
			"right": stage_right,
			"bottom": stage_bottom,
			"width": stage_width,
			"height": stage_height,
			"fills_stage": true
		},

		"choose_adventure_entry": {
			"shell_width": choose_adventure_shell_width,
			"shell_height": choose_adventure_shell_height,
			"occupancy_ratio": choose_adventure_occupancy_ratio,
			"card_count": choose_adventure_card_count,
			"card_separation": choose_adventure_card_separation,
			"horizontal_gutter": menu_horizontal_gutter,
			"vertical_gutter": menu_vertical_gutter
		},

		"god_mode_viewer": {
			"panel_left": god_mode_panel_left,
			"panel_top": god_mode_panel_top,
			"panel_right": (
				god_mode_panel_left
				+ god_mode_panel_width
			),
			"panel_bottom": (
				god_mode_panel_top
				+ god_mode_panel_height
			),
			"panel_width": god_mode_panel_width,
			"panel_height": god_mode_panel_height,
			"outer_gutter": god_mode_outer_gutter,
			"fills_stage": true
		},

		"root_shell": {
			"stats_safe_width": 126.0,
			"gutter": 18.0,
			"left_rail_reserve": 303.0,
			"playable_border_pad": 18.0,

			"minimum_usable_width": 360.0,
			"minimum_content_width": 860.0,

			"default_content_ratio": 0.68,
			"wide_content_ratio": 0.74,
			"ultrawide_content_ratio": 0.78,

			"wide_breakpoint": 1500.0,
			"ultrawide_breakpoint": 1900.0,

			"diary_horizontal_padding": 24.0,
			"diary_minimum_height": 360.0,

			"nav_button_height": 30.0,
			"age_up_button_height": 34.0,

			"hud_button_width": 82.0,
			"hud_button_height": 62.0
		},


		"source": str(
			context.get(
				"source",
				"presentation_composition"
			)
		),

		"ui_is_expression_only": true,
	}
func normalize_surface_contract(surface: Dictionary, owner_pack: String = "") -> Dictionary:
	var errors: Array = []
	var warnings: Array = []

	var surface_id: String = str(surface.get("surface_id", surface.get("id", ""))).strip_edges()
	if surface_id == "":
		errors.append("UI surface missing surface_id.")

	var surface_type: String = str(surface.get("surface_type", surface.get("type", "button"))).strip_edges().to_lower()
	if surface_type not in SUPPORTED_SURFACE_TYPES:
		warnings.append("Unsupported surface_type '%s'. Fallback: button." % surface_type)
		surface_type = "button"

	var layout: String = str(surface.get("layout", _default_layout_for_surface(surface_type))).strip_edges().to_lower()
	if layout not in SUPPORTED_LAYOUTS:
		warnings.append("Unsupported layout '%s'. Fallback applied." % layout)
		layout = _default_layout_for_surface(surface_type)

	var normalized_sections: Array = []
	for raw_section in _safe_dictionary_array(surface.get("sections", [])):
		normalized_sections.append(_normalize_section_contract(raw_section, surface_id))

	var normalized_actions: Array = []
	for raw_action in _safe_dictionary_array(surface.get("actions", [])):
		normalized_actions.append(_normalize_action_contract(raw_action, surface_id))

	var normalized:= {
		"schema": "eralife.ui_surface_contract",
		"version": UI_CONTRACT_VERSION,
		"runtime_version": UI_RUNTIME_VERSION,
		"surface_id": surface_id,
		"owner_pack": owner_pack,
		"system_id": str(surface.get("system_id", "")).strip_edges(),
		"surface_type": surface_type,
		"layout": layout,
		"label": str(surface.get("label", surface.get("title", surface_id))).strip_edges(),
		"title": str(surface.get("title", surface.get("label", surface_id))).strip_edges(),
		"subtitle": str(surface.get("subtitle", "")).strip_edges(),
		"description": str(surface.get("description", "")).strip_edges(),
		"icon": str(surface.get("icon", "")).strip_edges(),
		"sort_priority": int(surface.get("sort_priority", 50)),
		"visibility_rule": surface.get("visibility_rule", "always"),
		"enabled_rule": surface.get("enabled_rule", "always"),
		"data_source": str(surface.get("data_source", "")).strip_edges(),
		"data_binding": surface.get("data_binding", {}).duplicate(true) if typeof(surface.get("data_binding", {})) == TYPE_DICTIONARY else {},
		"device_profiles": _safe_string_array(surface.get("device_profiles", ["auto"])),
		"device_overrides": surface.get("device_overrides", {}).duplicate(true) if typeof(surface.get("device_overrides", {})) == TYPE_DICTIONARY else {},
		"layout_by_device": surface.get("layout_by_device", {}).duplicate(true) if typeof(surface.get("layout_by_device", {})) == TYPE_DICTIONARY else {},
		"theme": surface.get("theme", {}).duplicate(true) if typeof(surface.get("theme", {})) == TYPE_DICTIONARY else {},
		"sync_policy": surface.get("sync_policy", {}).duplicate(true) if typeof(surface.get("sync_policy", {})) == TYPE_DICTIONARY else {},
		"persistent_state": bool(surface.get("persistent_state", true)),
		"sections": normalized_sections,
		"actions": normalized_actions,
		"fallback": surface.get("fallback", {}).duplicate(true) if typeof(surface.get("fallback", {})) == TYPE_DICTIONARY else {},
		"metadata": surface.get("metadata", {}).duplicate(true) if typeof(surface.get("metadata", {})) == TYPE_DICTIONARY else {},
		"validation": {
			"valid": errors.is_empty(),
			"errors": errors,
			"warnings": warnings
		}
	}

	return normalized

func get_valid_surfaces(context: Dictionary = {}) -> Array:
	var out: Array = []
	var report:= {
		"checked": 0,
		"visible": 0,
		"hidden": [],
		"device_profile": _resolve_device_profile(context),
		"at_ms": int(Time.get_ticks_msec())
	}

	for surface_id in surface_registry.keys():
		var resolved: Dictionary = resolve_surface(str(surface_id), context)
		report ["checked"] += 1

		if resolved.is_empty():
			report ["hidden"].append(str(surface_id))
			continue

		out.append(resolved)
		report ["visible"] += 1

	out.sort_custom(func (a, b):
		var pa: int = int((a as Dictionary).get("sort_priority", 50))
		var pb: int = int((b as Dictionary).get("sort_priority", 50))
		if pa == pb:
			return str((a as Dictionary).get("label", "")) < str((b as Dictionary).get("label", ""))
		return pa < pb
	)

	last_resolution_report = report
	return out

func resolve_surface(
	surface_id: String,
	context: Dictionary = {}
) -> Dictionary:
	var clean_id: String = str(
		surface_id
	).strip_edges()

	if clean_id == "":
		return {}

	var surface_raw: Variant = surface_registry.get(
		clean_id,
		{}
	)

	if typeof(surface_raw) != TYPE_DICTIONARY:
		return {}

	var runtime_state_raw: Variant = (
		surface_runtime_state.get(
			clean_id,
			{}
		)
	)
	var runtime_state: Dictionary = (
		(runtime_state_raw as Dictionary).duplicate(true)
		if typeof(runtime_state_raw) == TYPE_DICTIONARY
		else {}
	)
	var resolved_context: Dictionary = _merge_dict(
		context,
		runtime_state
	)
	var device_profile: String = _resolve_device_profile(
		resolved_context
	)
	var surface: Dictionary = _apply_device_override(
		(surface_raw as Dictionary).duplicate(true),
		device_profile
	)

	surface = _apply_food_lifestyle_surface_contract_upgrades(
		clean_id,
		surface,
		resolved_context
	)

	if surface.is_empty():
		return {}

	surface = _apply_movie_theater_surface_contract_upgrades(
		clean_id,
		surface,
		resolved_context
	)

	if surface.is_empty():
		return {}

	if not _surface_supports_device(
		surface,
		device_profile
	):
		return {}

	if not _passes_rule(
		surface.get(
			"visibility_rule",
			"always"
		),
		resolved_context,
		surface
	):
		return {}

	var requested_section_id: String = str(
		context.get(
			"active_section_id",
			""
		)
	).strip_edges()

	if requested_section_id == "":
		requested_section_id = str(
			active_section_by_surface.get(
				clean_id,
				""
			)
		).strip_edges()

	if requested_section_id == "":
		requested_section_id = str(
			runtime_state.get(
				"active_section_id",
				""
			)
		).strip_edges()

	var visible_sections: Array = []
	var first_section_id: String = ""
	var default_section_id: String = ""

	for raw_section in surface.get(
		"sections",
		[]
	):
		if typeof(raw_section) != TYPE_DICTIONARY:
			continue

		var section: Dictionary = (
			raw_section as Dictionary
		).duplicate(true)

		if not _passes_rule(
			section.get(
				"visibility_rule",
				"always"
			),
			resolved_context,
			section
		):
			continue

		var section_id: String = str(
			section.get(
				"id",
				""
			)
		).strip_edges()

		if section_id == "":
			continue

		if first_section_id == "":
			first_section_id = section_id

		if (
			default_section_id == ""
			and bool(
				section.get(
					"is_default",
					false
				)
			)
		):
			default_section_id = section_id

		section ["enabled"] = _passes_rule(
			section.get(
				"enabled_rule",
				"always"
			),
			resolved_context,
			section
		)

		section ["rows"] = []
		section ["actions"] = []
		section ["rows_deferred"] = true
		section ["actions_deferred"] = true
		visible_sections.append(
			section
		)

	var active_section_id: String = requested_section_id
	var requested_section_exists: bool = false

	for raw_section in visible_sections:
		if typeof(raw_section) != TYPE_DICTIONARY:
			continue

		if str(
			(raw_section as Dictionary).get(
				"id",
				""
			)
		).strip_edges() == active_section_id:
			requested_section_exists = true
			break

	if not requested_section_exists:
		active_section_id = (
			default_section_id
			if default_section_id != ""
			else first_section_id
		)

	var resolved_sections: Array = []

	for raw_section in visible_sections:
		if typeof(raw_section) != TYPE_DICTIONARY:
			continue

		var section: Dictionary = (
			raw_section as Dictionary
		)
		var section_id: String = str(
			section.get(
				"id",
				""
			)
		).strip_edges()

		if section_id == active_section_id:
			section ["rows"] = resolve_data_source(
				str(
					section.get(
						"data_source",
						""
					)
				),
				resolved_context,
				section
			)

			for authored_raw in surface.get(
				"sections",
				[]
			):
				if typeof(authored_raw) != TYPE_DICTIONARY:
					continue

				var authored: Dictionary = (
					authored_raw as Dictionary
				)

				if str(
					authored.get(
						"id",
						""
					)
				).strip_edges() != section_id:
					continue

				section ["actions"] = _resolve_action_list(
					authored.get(
						"actions",
						[]
					),
					resolved_context,
					section
				)
				break

			section ["rows_deferred"] = false
			section ["actions_deferred"] = false

		resolved_sections.append(
			section
		)

	var resolved: Dictionary = surface.duplicate(true)

	resolved ["device_profile"] = device_profile
	resolved ["runtime_state"] = (
		runtime_state.duplicate(true)
	)
	resolved ["enabled"] = _passes_rule(
		surface.get(
			"enabled_rule",
			"always"
		),
		resolved_context,
		surface
	)
	resolved ["rows"] = resolve_data_source(
		str(
			surface.get(
				"data_source",
				""
			)
		),
		resolved_context,
		surface
	)
	resolved ["sections"] = resolved_sections
	resolved ["actions"] = _resolve_action_list(
		surface.get(
			"actions",
			[]
		),
		resolved_context,
		surface
	)
	resolved ["active_section_id"] = active_section_id
	resolved ["active_section_only_resolved"] = true
	resolved ["inactive_section_build_forbidden"] = true

	if clean_id == "food_contract_hub":
		EraLog.truth(
			(
				"ERALIFE_GROCERY_SURFACE_RESOLUTION_TRUTH"
				+ "|active_section=%s"
				+ "|visible_sections=%d"
				+ "|resolved_sections=1"
				+ "|inactive_rows_resolved=false"
				+ "|at_ms=%d"
			)
			% [
				active_section_id,
				resolved_sections.size(),
				int(
					Time.get_ticks_msec()
				)
			]
		)

	return resolved
func _food_lifestyle_grocery_cart_has_items() -> bool:
	if gs == null or gs.player == null or gs.grocery_store_engine == null:
		return false

	if gs.grocery_store_engine.has_method("actor_cart_has_items"):
		return bool(gs.grocery_store_engine.actor_cart_has_items(gs.player))

	return false


func _food_lifestyle_restaurant_order_has_items() -> bool:
	if gs == null or gs.player == null or gs.food_restaurant_engine == null:
		return false

	if gs.food_restaurant_engine.has_method("actor_order_has_items"):
		return bool(gs.food_restaurant_engine.actor_order_has_items(gs.player))

	return false


func _food_lifestyle_restaurant_plan_chosen(context: Dictionary = {}) -> bool:
	if bool(context.get("restaurant_plan_chosen", false)):
		return true

	if _food_lifestyle_restaurant_order_has_items():
		return true

	if _food_lifestyle_restaurant_date_turn_active():
		return true

	var mode: String = str(context.get("restaurant_mode", "")).strip_edges().to_lower()
	var partner_id: int = int(context.get("date_partner_id", -1))

	match mode:
		"alone", "partner":
			return true
		"date":
			if partner_id > 0:
				return true

	if gs != null and gs.player != null and gs.food_restaurant_engine != null:
		if gs.food_restaurant_engine.has_method("actor_has_restaurant_plan") and bool(gs.food_restaurant_engine.actor_has_restaurant_plan(gs.player)):
			return true

		if gs.food_restaurant_engine.has_method("restaurant_surface_state_for_actor"):
			var restaurant_state: Dictionary = gs.food_restaurant_engine.restaurant_surface_state_for_actor(gs.player)
			var state_mode: String = str(restaurant_state.get("restaurant_mode", "")).strip_edges().to_lower()
			var state_partner_id: int = int(restaurant_state.get("date_partner_id", -1))

			match state_mode:
				"alone", "partner":
					return true
				"date":
					return state_partner_id > 0

	return false

func _food_lifestyle_restaurant_date_turn_active() -> bool:
	if gs == null or gs.player == null or gs.food_restaurant_engine == null:
		return false

	if gs.food_restaurant_engine.has_method("actor_has_active_date_turn"):
		return bool(gs.food_restaurant_engine.actor_has_active_date_turn(gs.player))

	return false


func _food_lifestyle_restaurant_checkout_label() -> String:
	if gs == null or gs.player == null or gs.food_restaurant_engine == null:
		return "Place Order"

	if gs.food_restaurant_engine.has_method("actor_order_checkout_label"):
		return str(gs.food_restaurant_engine.actor_order_checkout_label(gs.player))

	return "Place Order"
func _food_lifestyle_store_name(store_id: String) -> String:
	var clean_id: String = str(store_id).strip_edges()
	if clean_id == "" or gs == null or gs.grocery_store_engine == null:
		return "the Store"

	if gs.grocery_store_engine.has_method("get_store"):
		var store: Dictionary = gs.grocery_store_engine.get_store(clean_id)
		if not store.is_empty():
			return str(store.get("name", "the Store"))

	return "the Store"
func _food_lifestyle_grocery_cart_metrics() -> Dictionary:
	var metrics: Dictionary = {
		"has_items": false,
		"item_count": 0,
		"line_count": 0,
		"subtotal": 0.0,
		"tax": 0.0,
		"total": 0.0
	}

	if gs == null or gs.player == null or gs.grocery_store_engine == null:
		return metrics

	var cart: Dictionary = {}
	if gs.grocery_store_engine.has_method("_grocery_cart_for_actor"):
		cart = gs.grocery_store_engine._grocery_cart_for_actor(gs.player)

	var items: Array = cart.get("items", []) if typeof(cart.get("items", [])) == TYPE_ARRAY else []
	metrics ["line_count"] = items.size()

	var item_count: int = 0
	for raw_item in items:
		if typeof(raw_item) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = raw_item
		item_count += max(1, int(item.get("quantity", 1)))

	metrics ["item_count"] = item_count
	metrics ["has_items"] = item_count > 0

	if gs.grocery_store_engine.has_method("_grocery_cart_price_breakdown"):
		var breakdown: Dictionary = gs.grocery_store_engine._grocery_cart_price_breakdown(cart)
		metrics ["subtotal"] = float(breakdown.get("subtotal", 0.0))
		metrics ["tax"] = float(breakdown.get("tax", 0.0))
		metrics ["total"] = float(breakdown.get("total", 0.0))
	elif gs.grocery_store_engine.has_method("_grocery_cart_total"):
		metrics ["total"] = float(gs.grocery_store_engine._grocery_cart_total(cart))

	return metrics


func _food_lifestyle_restaurant_name(restaurant_id: String) -> String:
	var clean_id: String = str(restaurant_id).strip_edges()
	if clean_id == "" or gs == null or gs.food_restaurant_engine == null:
		return ""

	if gs.food_restaurant_engine.has_method("get_restaurant"):
		var restaurant: Dictionary = gs.food_restaurant_engine.get_restaurant(clean_id)
		if not restaurant.is_empty():
			return str(restaurant.get("name", "")).strip_edges()

	return ""
func _apply_food_lifestyle_surface_contract_upgrades(surface_id: String, surface: Dictionary, _context: Dictionary = {}) -> Dictionary:
	var clean_id: String = str(surface_id).strip_edges()
	if surface.is_empty():
		return {}

	match clean_id:
		"food_contract_hub":
			if not _food_hub_player_can_open():
				return {}

			var upgraded: Dictionary = surface.duplicate(true)
			var selected_store_id: String = str(_context.get("store_id", "")).strip_edges()
			var grocery_metrics: Dictionary = _food_lifestyle_grocery_cart_metrics()
			var grocery_has_cart: bool = bool(grocery_metrics.get("has_items", false))
			var grocery_cart_count: int = int(grocery_metrics.get("item_count", 0))
			var grocery_cart_total: float = float(grocery_metrics.get("total", 0.0))
			var grocery_cart_unlocked: bool = grocery_has_cart and bool(_context.get("grocery_cart_unlocked", grocery_has_cart))
			var cashier_ready: bool = grocery_has_cart and bool(_context.get("grocery_ready_for_cashier", false))
			var grocery_action_report_raw: Variant = _context.get("last_action_report", {})
			var grocery_action_report: Dictionary = grocery_action_report_raw.duplicate(true) if typeof(grocery_action_report_raw) == TYPE_DICTIONARY else {}
			var last_added_delta: float = float(grocery_action_report.get("added_total_delta", 0.0))
			var last_added_food_id: String = str(grocery_action_report.get("food_id", "")).strip_edges()
			var membership_cost_delta: float = float(grocery_action_report.get("membership_cost_delta", 0.0))
			var last_added_pulse: String = ""
			var last_added_pulse_key: String = ""
			var last_added_pulse_tone: String = ""

			if membership_cost_delta < 0.0:
				last_added_pulse = str(grocery_action_report.get("membership_cost_pulse_text", "-$250/Mo")).strip_edges()
				last_added_pulse_key = "goldleaf_membership|%s|%s" % [
					str(grocery_action_report.get("updated_at_ms", "")),
					str(membership_cost_delta)
				]
				last_added_pulse_tone = "negative"
			elif last_added_delta > 0.0 and last_added_food_id != "":
				last_added_pulse = "+$%.2f" % last_added_delta
				last_added_pulse_key = "%s|%s|%s|%s|%s" % [
					str(grocery_action_report.get("updated_at_ms", "")),
					last_added_food_id,
					str(grocery_action_report.get("cart_total", "")),
					str(grocery_action_report.get("cart_item_count", "")),
					str(last_added_delta)
				]
				last_added_pulse_tone = "positive"

			var sections: Array = [
				{
					"id": "stores",
					"label": "Grocery Stores",
					"is_default": true,
					"data_source": "grocery.stores",
					"description": "Choose the grocery store you are entering. Once you enter, the hub moves into aisle browsing."
				}
			]

			upgraded ["label"] = "Groceries"
			upgraded ["title"] = " Food Hub" if selected_store_id == "" else " Inside %s" % _food_lifestyle_store_name(selected_store_id)
			upgraded ["subtitle"] = ""
			upgraded ["icon"] = " "
			upgraded ["sort_priority"] = 36
			upgraded ["persistent_state"] = true

			if selected_store_id != "" and gs != null and gs.grocery_store_engine != null and gs.grocery_store_engine.has_method("get_grocery_store_presence_summary"):
				var presence_summary: Dictionary = gs.grocery_store_engine.get_grocery_store_presence_summary(selected_store_id, _context)
				upgraded ["header_badges"] = [
					{
						"label": "People in Store",
						"value": int(presence_summary.get("people_in_store", 1)),
						"style": "cherry",
						"tooltip": "Includes you, live shoppers, and the active cashier."
					}
				]
			else:
				upgraded.erase("header_badges")

			if selected_store_id != "":
				sections.append({
					"id": "aisles",
					"label": "Aisles",
					"data_source": "grocery.aisles",
					"description": "You are inside this store now. Flip aisles, add items, then press Done Browsing when you are ready for the cart.",
					"trailing_text": "Your total so far: $%.2f" % grocery_cart_total,
					"pulse_text": last_added_pulse,
					"pulse_key": last_added_pulse_key,
					"pulse_tone": last_added_pulse_tone,
					"actions": [
						{ "id": "grocery_done_browsing", "label": "Done Browsing", "kind": "packet", "style": "success"},
						{ "id": "grocery_back:stores", "label": "Back", "kind": "packet", "style": "secondary"}
					]
				})

			var self_checkout_state: String = str(_context.get("self_checkout_state", "")).strip_edges()
			var self_checkout_active: bool = bool(_context.get("grocery_self_checkout_active", false)) or self_checkout_state != ""

			if grocery_has_cart and grocery_cart_unlocked:
				sections.append({
					"id": "cart",
					"label": "Cart",
					"badge_count": grocery_cart_count,
					"badge_color": "red",
					"data_source": "grocery.cart",
					"description": "Review the real cart total. Checkout sends you to the cashier first; self-checkout opens a real lane with machine availability and waiting.",
					"actions": [
						{ "id": "grocery_cashier", "label": "Check Out With Cashier", "kind": "packet", "style": "success"},
						{ "id": "grocery_self_checkout", "label": "Self Checkout", "kind": "packet", "style": "primary"},
						{ "id": "grocery_shoplift", "label": "Steal Groceries", "kind": "packet", "style": "danger"},
						{ "id": "grocery_back:aisles", "label": "Back", "kind": "packet", "style": "secondary"}
					]
				})

			if self_checkout_active:
				sections.append({
					"id": "self_checkout",
					"label": "Self Checkout",
					"data_source": "grocery.self_checkout",
					"description": "A real self-checkout lane with multiple machines, occupied stations, waiting, payment prompts, and exit flow.",
					"actions": [
						{ "id": "grocery_back:cart", "label": "Back To Cart", "kind": "packet", "style": "secondary"}
					]
				})

			if cashier_ready:
				sections.append({
					"id": "cashier",
					"label": "Cashier",
					"data_source": "grocery.cashier",
					"description": "Complete the order through the clickable cashier.",
					"actions": [
						{ "id": "grocery_back:cart", "label": "Back", "kind": "packet", "style": "secondary"}
					]
				})

			upgraded ["sections"] = sections
			return upgraded

		"restaurant_contract_hub":
			if not _restaurant_hub_player_can_open():
				return {}

			var restaurant_surface: Dictionary = surface.duplicate(true)
			var plan_chosen: bool = _food_lifestyle_restaurant_plan_chosen(_context)
			var selected_restaurant_id: String = str(_context.get("restaurant_id", "")).strip_edges()
			var selected_restaurant_name: String = _food_lifestyle_restaurant_name(selected_restaurant_id)
			var menu_preview_only: bool = bool(_context.get("menu_preview_only", false))
			var order_has_items: bool = _food_lifestyle_restaurant_order_has_items()
			var date_turn_active: bool = _food_lifestyle_restaurant_date_turn_active()
			var order_unlocked: bool = (order_has_items or date_turn_active) and bool(_context.get("restaurant_order_unlocked", order_has_items or date_turn_active))
			var bill_requested: bool = bool(_context.get("restaurant_bill_requested", false))
			var bill_stage: String = str(_context.get("restaurant_bill_stage", "")).strip_edges().to_lower()
			var waiter_actions: Array = []

			var restaurant_sections: Array = [
				{
					"id": "plan",
					"label": "Who Are You Going With?",
					"is_default": true,
					"data_source": "restaurant.intent",
					"description": "Choose whether this is solo, with your partner, or a date search. The rest of the restaurant unlocks after this."
				}
			]

			restaurant_surface ["label"] = "Restaurants"
			restaurant_surface ["title"] = "     %s" % _restaurant_hub_title_for_era()
			restaurant_surface ["subtitle"] = "Era-based dining: choose who you are going with, pick a restaurant and service style, build the menu order, then place it, call the waiter, pay the bill, and end the date."
			if selected_restaurant_name != "":
				restaurant_surface ["subtitle"] = "You chose %s. Pick dine-in, takeout, drive-thru if available, or preview the menu without committing." % selected_restaurant_name
			restaurant_surface ["icon"] = " "
			restaurant_surface ["sort_priority"] = 37
			restaurant_surface ["persistent_state"] = true

			if plan_chosen:
				var restaurant_description: String = "Pick a restaurant type, then a specific restaurant, then choose dine-in, takeout, or drive-thru."
				if selected_restaurant_name != "":
					restaurant_description = "%s is selected. Choose dine-in, takeout, drive-thru if available, or view the menu without going." % selected_restaurant_name

				restaurant_sections.append({
					"id": "restaurant",
					"label": "Restaurant" if selected_restaurant_name == "" else "Restaurant • %s" % selected_restaurant_name,
					"data_source": "restaurant.list_by_category",
					"description": restaurant_description,
					"actions": [
						{ "id": "restaurant_back:plan", "label": "Back", "kind": "packet", "style": "secondary"}
					]
				})

			if selected_restaurant_id != "":
				var menu_actions: Array = []
				if menu_preview_only:
					menu_actions.append({ "id": "restaurant_select:%s" % selected_restaurant_id, "label": "Back to Selected Restaurant", "kind": "packet", "style": "secondary"})
				else:
					menu_actions.append({ "id": "restaurant_cart", "label": "View Order", "kind": "packet", "style": "primary"})
					menu_actions.append({ "id": "restaurant_back:restaurant", "label": "Back", "kind": "packet", "style": "secondary"})

				restaurant_sections.append({
					"id": "menu",
					"label": "Menu Preview" if menu_preview_only else "Menu",
					"data_source": "restaurant.menu",
					"description": "Previewing %s’s menu without starting service." % selected_restaurant_name if menu_preview_only and selected_restaurant_name != "" else "Add food to the order. If you brought someone, ask what they want and their item joins the cart.",
					"actions": menu_actions
				})

			if order_unlocked:
				if date_turn_active:
					if bill_requested or bill_stage != "":
						waiter_actions.append({ "id": "restaurant_waiter:pay_bill", "label": "PAY BILL AND END DATE", "kind": "packet", "style": "success"})
					else:
						waiter_actions.append({ "id": "restaurant_waiter:call", "label": "CALL WAITER", "kind": "packet", "style": "primary"})
				waiter_actions.append({ "id": "restaurant_back:menu", "label": "Back", "kind": "packet", "style": "secondary"})

				restaurant_sections.append({
					"id": "cart",
					"label": "Order",
					"data_source": "restaurant.cart",
					"description": "Review the order, continue the date, call the waiter, or ask for the bill.",
					"actions": waiter_actions
				})

			restaurant_surface ["sections"] = restaurant_sections
			return restaurant_surface

		"relationship_contract_hub":
			var relationship_surface: Dictionary = surface.duplicate(true)
			var sections: Array = relationship_surface.get("sections", []) if typeof(relationship_surface.get("sections", [])) == TYPE_ARRAY else []
			var has_flings: bool = false
			for raw_section in sections:
				if typeof(raw_section) != TYPE_DICTIONARY:
					continue
				if str((raw_section as Dictionary).get("id", "")) == "flings":
					has_flings = true
					break

			if not has_flings:
				sections.append({
					"id": "flings",
					"label": "Flings",
					"data_source": "relationship.flings",
					"description": "Restaurant flings and long-distance writing flings, without becoming official partners."
				})

			relationship_surface ["sections"] = sections
			return relationship_surface

	return surface

func _food_hub_player_can_open() -> bool:
	if gs == null or gs.player == null:
		return false
	if int(gs.player.age) < 15:
		return false

	return _food_lifestyle_era_supports_modern_future_hubs(_food_lifestyle_current_era_name())


func _restaurant_hub_player_can_open() -> bool:
	if gs == null or gs.player == null:
		return false
	if int(gs.player.age) < 15:
		return false

	return _food_lifestyle_era_supports_modern_future_hubs(_food_lifestyle_current_era_name())


func _food_lifestyle_current_era_name() -> String:
	if gs != null:
		var year_era_name: String = _food_lifestyle_era_name_from_year(int(gs.year))
		if year_era_name != "":
			return year_era_name

	if gs != null and gs.era != null:
		if typeof(gs.era) == TYPE_DICTIONARY:
			return str((gs.era as Dictionary).get("name", "")).strip_edges()
		return str(gs.era.name).strip_edges()

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		var scenario_era: String = str(gs.scenario_state.get("era_name", gs.scenario_state.get("era", ""))).strip_edges()
		if scenario_era != "":
			return scenario_era

	return ""
func _food_lifestyle_era_supports_modern_future_hubs(era_name: String) -> bool:
	var clean_era: String = _food_lifestyle_normalized_era_key(era_name)
	return clean_era == "modern" or clean_era == "future"


func _food_lifestyle_normalized_era_key(era_name: String) -> String:
	var clean: String = str(era_name).strip_edges().to_lower()
	clean = clean.replace(" era", "")
	clean = clean.replace(" ", "_")
	return clean


func _food_lifestyle_era_name_from_year(year_value: int) -> String:
	match _food_lifestyle_era_key_from_year(year_value):
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


func _food_lifestyle_era_key_from_year(year_value: int) -> String:
	if year_value <= 499:
		return "Ancient"
	if year_value <= 1799:
		return "Medieval"
	if year_value <= 1949:
		return "Industrial"
	if year_value <= 2049:
		return "Modern"
	return "Future"


func _restaurant_hub_title_for_era() -> String:
	var era_name: String = _food_lifestyle_current_era_name()
	match era_name:
		"Future Era":
			return "Restaurant Hub • Future Dining"
		"Modern Era":
			return "Restaurant Hub • Modern Dining"
		_:
			return "Restaurant Hub • Locked Until Modern Era"
func _movie_theater_player_can_open() -> bool:
	if gs == null or gs.player == null:
		return false

	var era_name: String = _food_lifestyle_current_era_name()
	return era_name in ["Modern Era", "Future Era"]


func _movie_theater_name(theater_id: String) -> String:
	var clean_id: String = str(theater_id).strip_edges()
	if clean_id == "":
		return ""

	if gs != null and gs.movie_theater_engine != null and gs.movie_theater_engine.has_method("get_theater"):
		var theater: Dictionary = gs.movie_theater_engine.get_theater(clean_id)
		if not theater.is_empty():
			return str(theater.get("name", clean_id)).strip_edges()

	return clean_id.replace("_", " ").capitalize()


func _apply_movie_theater_surface_contract_upgrades(surface_id: String, surface: Dictionary, _context: Dictionary = {}) -> Dictionary:
	var clean_id: String = str(surface_id).strip_edges()
	if clean_id != "movie_theater_contract_hub":
		return surface

	if surface.is_empty():
		return {}

	if not _movie_theater_player_can_open():
		return {}

	var upgraded: Dictionary = surface.duplicate(true)
	var state: Dictionary = {}
	if gs != null and gs.player != null and gs.movie_theater_engine != null and gs.movie_theater_engine.has_method("movie_theater_surface_state_for_actor"):
		state = gs.movie_theater_engine.movie_theater_surface_state_for_actor(gs.player)

	var theater_id: String = str(state.get("theater_id", "")).strip_edges()
	var theater_name: String = str(state.get("theater_name", "")).strip_edges()
	if theater_name == "" and theater_id != "":
		theater_name = _movie_theater_name(theater_id)

	var movie_id: String = str(state.get("movie_id", "")).strip_edges()
	var movie_title: String = str(state.get("movie_title", "")).strip_edges()
	var ticket_bought: bool = bool(state.get("ticket_bought", false))
	var active_event: Dictionary = state.get("active_friction_event", {}) if typeof(state.get("active_friction_event", {})) == TYPE_DICTIONARY else {}

	var sections: Array = [
		{
			"id": "theaters",
			"label": "Movie Theaters",
			"is_default": true,
			"data_source": "movie.theaters",
			"description": "Choose which movie theater to enter. This creates a shared public-space session with lobby, line, concessions, auditorium, and exit zones."
		}
	]

	if theater_id != "":
		sections.append({
			"id": "movies",
			"label": "Movie Selection",
			"data_source": "movie.selection",
			"description": "Pick what you are watching. Genre changes the crowd type, behavior pressure, and social friction pool.",
			"actions": [
				{ "id": "movie_back:theaters", "label": "Back", "kind": "packet", "style": "secondary", "payload": { "target_section": "theaters"}}
			]
		})

	if movie_id != "":
		sections.append({
			"id": "lobby",
			"label": "Lobby Line",
			"data_source": "movie.lobby",
			"description": "Stand in line, wait your turn, and buy the ticket before entering the theater.",
			"actions": [
				{ "id": "movie_back:movies", "label": "Back To Movies", "kind": "packet", "style": "secondary", "payload": { "target_section": "movies"}}
			]
		})

	if ticket_bought:
		sections.append({
			"id": "concessions",
			"label": "Concessions",
			"data_source": "movie.concessions",
			"description": "Buy popcorn, soda, candy, or nachos before the movie."
		})
		sections.append({
			"id": "auditorium",
			"label": "Theater",
			"data_source": "movie.auditorium",
			"description": "Sit down inside the shared audience space. Let the movie play to generate contract-driven social friction."
		})

	if not active_event.is_empty():
		sections.append({
			"id": "friction",
			"label": "Social Friction",
			"data_source": "movie.friction",
			"description": "Respond to the current audience friction event. Each response checks intensity, personality influence, and possible escalation."
		})

	upgraded ["label"] = "Movies"
	upgraded ["title"] = "Movie Theater" if theater_name == "" else "Inside %s" % theater_name
	upgraded ["subtitle"] = "Choose a theater, pick a movie, survive the lobby line, buy snacks, then deal with live audience friction."
	if movie_title != "":
		upgraded ["subtitle"] = "Watching %s. Genre pressure changes the crowd and friction events." % movie_title
	upgraded ["icon"] = "🎬"
	upgraded ["sort_priority"] = 33
	upgraded ["persistent_state"] = true
	upgraded ["sections"] = sections

	if theater_id != "" and gs != null and gs.movie_theater_engine != null and gs.movie_theater_engine.has_method("get_movie_theater_presence_summary"):
		var presence_summary: Dictionary = gs.movie_theater_engine.get_movie_theater_presence_summary(theater_id, _context)
		var zone_counts: Dictionary = presence_summary.get("zone_counts", {}) if typeof(presence_summary.get("zone_counts", {})) == TYPE_DICTIONARY else {}
		upgraded ["header_badges"] = [
			{
				"label": "People in Building",
				"value": int(presence_summary.get("people_in_building", 0)),
				"style": "cherry",
				"tooltip": "SharedPublicSpaceEngine population count for this movie theater."
			},
			{
				"label": "Lobby",
				"value": int(zone_counts.get("lobby", 0)),
				"style": "cherry",
				"tooltip": "NPCs currently in the lobby zone."
			},
			{
				"label": "Theater",
				"value": int(zone_counts.get("auditorium", 0)),
				"style": "cherry",
				"tooltip": "NPCs currently in the auditorium zone."
			}
		]
	else:
		upgraded.erase("header_badges")

	return upgraded
func build_ui_packet(surface_id: String, context: Dictionary = {}, options: Dictionary = {}) -> Dictionary:
	var clean_surface: String = str(surface_id).strip_edges()

	if clean_surface == "":
		return {
			"success": false,
			"schema": "eralife.ui_packet",
			"version": UI_CONTRACT_VERSION,
			"reason": "Missing surface_id.",
			"ui_safe": false,
			"contract_status": "failed",
			"stability_tier": "blocked_invalid_contract"
		}

	var shell_first_contract_only: bool = bool(context.get("first_frame_is_live_runtime", false)) \
or bool(context.get("first_visible_runtime_boot", false)) \
or bool(context.get("playable_birth_shell_only", false)) \
or bool(context.get("live_reality_stream", false)) \
or bool(context.get("shell_first_handoff", false)) \
or bool(options.get("shell_first_handoff", false))

	if bool(options.get("use_prewarm", false)):
		var consumed: Dictionary = consume_prewarmed_surface_packet(clean_surface, context)
		if not consumed.is_empty():
			consumed ["stability_tier"] = str(consumed.get("stability_tier", "prewarmed_stable"))
			consumed ["background_reconciliation_required"] = false
			return consumed

		if shell_first_contract_only:
			var placeholder_options: Dictionary = options.duplicate(true)
			placeholder_options ["prewarm_cache_miss"] = true
			placeholder_options ["shell_first_handoff"] = true
			placeholder_options ["deferred_truth_policy"] = true
			placeholder_options ["source"] = str(placeholder_options.get("source", "ui_contract_engine.build_ui_packet.first_frame_placeholder"))

			var placeholder_packet: Dictionary = _build_synthesized_ui_packet_for_surface(clean_surface, context, placeholder_options)
			placeholder_packet ["consumed_from_shell_first_placeholder"] = true
			placeholder_packet ["prewarm_cache_miss"] = true
			placeholder_packet ["stability_tier"] = "shell_safe_synthesized"
			placeholder_packet ["background_reconciliation_required"] = true
			placeholder_packet ["deferred_truth_policy"] = {
				"enabled": true,
				"reason": "prewarm_cache_miss_during_shell_first_handoff",
				"ui_may_render": bool(placeholder_packet.get("ui_safe", false))
			}
			return placeholder_packet

	if clean_surface == "life_panel":
		var life_packet: Dictionary = _build_life_panel_ui_packet(context, options)
		return _contract_satisfy_ui_packet(life_packet, {}, context, options)

	var surface: Dictionary = get_surface_view_model(clean_surface, context)
	if surface.is_empty():
		return _build_synthesized_ui_packet_for_surface(clean_surface, context, options)

	return _packet_from_surface_view_model(surface, context, options)

func prewarm_surface_packet(surface_id: String, context: Dictionary = {}, options: Dictionary = {}) -> Dictionary:
	var clean_surface: String = str(surface_id).strip_edges()
	if clean_surface == "":
		return {
			"success": false,
			"schema": "eralife.ui_prewarm_report",
			"version": UI_CONTRACT_VERSION,
			"reason": "Missing surface_id.",
			"ui_safe": false,
			"contract_status": "failed"
		}

	var build_options: Dictionary = options.duplicate(true)
	build_options ["prewarm"] = true
	build_options ["use_prewarm"] = false
	build_options ["packet_contract_required"] = true

	var packet: Dictionary = build_ui_packet(clean_surface, context, build_options)
	var cache_key: String = _ui_packet_cache_key(clean_surface, context)
	var packet_ui_safe: bool = bool(packet.get("ui_safe", false))
	var packet_satisfied: bool = str(packet.get("contract_status", "")) == "satisfied"

	if bool(packet.get("success", false)) and packet_ui_safe and packet_satisfied:
		packet ["prewarmed"] = true
		packet ["prewarm_cache_key"] = cache_key
		packet ["prewarmed_at_ms"] = int(Time.get_ticks_msec())

		prewarmed_packet_cache [cache_key] = {
			"surface_id": clean_surface,
			"packet": packet.duplicate(true),
			"context": context.duplicate(true),
			"created_at_ms": int(Time.get_ticks_msec())
		}

	var report: Dictionary = {
		"success": bool(packet.get("success", false)) and packet_ui_safe and packet_satisfied,
		"schema": "eralife.ui_prewarm_report",
		"version": UI_CONTRACT_VERSION,
		"runtime_version": UI_RUNTIME_VERSION,
		"surface_id": clean_surface,
		"cache_key": cache_key,
		"packet": packet.duplicate(true),
		"context": context.duplicate(true),
		"ui_safe": packet_ui_safe,
		"contract_status": str(packet.get("contract_status", "unknown")),
		"packet_contract_id": str(packet.get("packet_contract_id", "")),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	last_prewarm_report = report.duplicate(true)
	return report
func consume_prewarmed_surface_packet(surface_id: String, context: Dictionary = {}) -> Dictionary:
	var clean_surface: String = str(surface_id).strip_edges()
	if clean_surface == "":
		return {}

	var cache_key: String = _ui_packet_cache_key(clean_surface, context)
	if not prewarmed_packet_cache.has(cache_key):
		return {}

	var cached_raw: Variant = prewarmed_packet_cache.get(cache_key, {})
	prewarmed_packet_cache.erase(cache_key)

	if typeof(cached_raw) != TYPE_DICTIONARY:
		return {}

	var cached: Dictionary = cached_raw as Dictionary
	var packet_raw: Variant = cached.get("packet", {})
	if typeof(packet_raw) != TYPE_DICTIONARY:
		return {}

	var packet: Dictionary = (packet_raw as Dictionary).duplicate(true)
	packet = _contract_satisfy_ui_packet(packet, {}, context, {
		"consume": true,
		"source": "ui_contract_engine.consume_prewarmed_surface_packet"
	})

	if not bool(packet.get("success", false)):
		return {}
	if not bool(packet.get("ui_safe", false)):
		return {}
	if str(packet.get("contract_status", "")) != "satisfied":
		return {}

	packet ["consumed_from_prewarm"] = true
	packet ["consumed_at_ms"] = int(Time.get_ticks_msec())
	return packet

func _packet_from_surface_view_model(surface: Dictionary, context: Dictionary = {}, options: Dictionary = {}) -> Dictionary:
	var clean_surface: String = str(surface.get("surface_id", surface.get("id", ""))).strip_edges()
	var rows: Array = []
	var raw_rows: Variant = surface.get("rows", [])
	if typeof(raw_rows) == TYPE_ARRAY:
		for raw_row in raw_rows:
			rows.append(raw_row)

	var packet: Dictionary = {
		"success": true,
		"schema": "eralife.ui_packet",
		"version": UI_CONTRACT_VERSION,
		"runtime_version": UI_RUNTIME_VERSION,
		"surface_id": clean_surface,
		"surface_type": str(surface.get("surface_type", "panel")),
		"layout": str(surface.get("layout", "scroll_list")),
		"title": str(surface.get("title", surface.get("label", clean_surface))),
		"subtitle": str(surface.get("subtitle", "")),
		"theme_id": str(surface.get("theme_id", surface.get("theme", {}).get("theme_id", "default")) if typeof(surface.get("theme", {})) == TYPE_DICTIONARY else "default"),
		"visibility": {
			"condition": surface.get("visibility_rule", "always"),
			"resolved": true,
			"visible": true
		},
		"enabled": bool(surface.get("enabled", true)),
		"data": {
			"rows": rows,
			"sections": surface.get("sections", []) if typeof(surface.get("sections", [])) == TYPE_ARRAY else [],
			"actions": surface.get("actions", []) if typeof(surface.get("actions", [])) == TYPE_ARRAY else []
		},
		"context": context.duplicate(true),
		"options": options.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	packet ["signature"] = _ui_packet_cache_key(clean_surface, context)
	return _contract_satisfy_ui_packet(packet, surface, context, options)

func _build_life_panel_ui_packet(context: Dictionary = {}, options: Dictionary = {}) -> Dictionary:
	var lines: Array = []
	var raw_lines: Variant = context.get("diary_lines", context.get("lines", []))
	if typeof(raw_lines) == TYPE_ARRAY:
		for raw_line in raw_lines:
			lines.append(str(raw_line))

	if lines.is_empty():
		lines.append("No diary entries yet. DO SOMETHING BRO.")

	var actions: Array = []
	var raw_actions: Variant = context.get("actions", [])
	if typeof(raw_actions) == TYPE_ARRAY:
		for raw_action in raw_actions:
			if typeof(raw_action) == TYPE_DICTIONARY:
				actions.append((raw_action as Dictionary).duplicate(true))

	if actions.is_empty():
		actions.append({
			"id": "life.view_assets",
			"intent": "life.view_assets",
			"legacy_action_id": "Life View Assets",
			"label": "View Assets       ",
			"kind": "ui_intent",
			"enabled": true
		})

	var packet: Dictionary = {
		"success": true,
		"schema": "eralife.ui_packet",
		"version": UI_CONTRACT_VERSION,
		"runtime_version": UI_RUNTIME_VERSION,
		"surface_id": "life_panel",
		"surface_type": "panel",
		"layout": "scroll_list",
		"title": "LIFE / DIARY",
		"subtitle": "",
		"theme_id": "life",
		"visibility": {
			"condition": "player.exists",
			"resolved": true,
			"visible": true
		},
		"enabled": true,
		"data": {
			"lines": lines,
			"sections": [
				{
					"id": "assets_wealth",
					"label": "Assets / Wealth",
					"visible": true,
					"actions": actions
				}
			]
		},
		"context": context.duplicate(true),
		"options": options.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	packet ["signature"] = _ui_packet_cache_key("life_panel", context)
	return _contract_satisfy_ui_packet(packet, {}, context, options)
func _build_synthesized_ui_packet_for_surface(surface_id: String, context: Dictionary = {}, options: Dictionary = {}) -> Dictionary:
	var clean_surface: String = str(surface_id).strip_edges()
	var contract: Dictionary = _ui_packet_contract_for_surface(clean_surface)

	var packet: Dictionary = {
		"success": true,
		"schema": "eralife.ui_packet",
		"version": UI_CONTRACT_VERSION,
		"runtime_version": UI_RUNTIME_VERSION,
		"surface_id": clean_surface,
		"surface_type": str(contract.get("surface_type", "panel")),
		"layout": str(contract.get("layout", "scroll_list")),
		"title": str(contract.get("title", clean_surface.capitalize())),
		"subtitle": str(contract.get("subtitle", "Perceived truth stabilized by the Packet Contract Engine.")),
		"theme_id": str(contract.get("theme_id", "default")),
		"visibility": {
			"condition": "packet_contract.satisfied",
			"resolved": true,
			"visible": true
		},
		"enabled": true,
		"data": {},
		"context": context.duplicate(true),
		"options": options.duplicate(true),
		"synthesized_surface": true,
		"created_at_ms": int(Time.get_ticks_msec())
	}

	packet ["signature"] = _ui_packet_cache_key(clean_surface, context)
	return _contract_satisfy_ui_packet(packet, {}, context, options)


func _contract_satisfy_ui_packet(packet: Dictionary, surface: Dictionary = {}, context: Dictionary = {}, options: Dictionary = {}) -> Dictionary:
	var clean_surface: String = str(packet.get("surface_id", surface.get("surface_id", surface.get("id", "")))).strip_edges()
	if clean_surface == "":
		clean_surface = str(context.get("surface_id", "")).strip_edges()

	var contract: Dictionary = _ui_packet_contract_for_surface(clean_surface)
	var required: Array = contract.get("required", []) if typeof(contract.get("required", [])) == TYPE_ARRAY else []
	var data_raw: Variant = packet.get("data", {})
	var data: Dictionary = data_raw.duplicate(true) if typeof(data_raw) == TYPE_DICTIONARY else {}

	var missing: Array = []
	var synthesized: Array = []
	var delayed: Array = []
	var degraded: Array = []

	for raw_path in required:
		var path: String = str(raw_path).strip_edges()
		if path == "":
			continue
		if _ui_packet_data_has_path(data, path):
			continue

		var fallback: Variant = _ui_packet_fallback_for_path(path, clean_surface, context)
		if typeof(fallback) == TYPE_NIL:
			delayed.append(path)
			continue

		_ui_packet_data_set_path(data, path, fallback)
		missing.append(path)
		synthesized.append(path)

	if not data.has("lines") or typeof(data.get("lines", [])) != TYPE_ARRAY or (data.get("lines", []) as Array).is_empty():
		data ["lines"] = _ui_packet_lines_from_data(clean_surface, data, context)

	if clean_surface == "life_panel":
		var life_raw: Variant = data.get("life", {})
		var life: Dictionary = life_raw.duplicate(true) if typeof(life_raw) == TYPE_DICTIONARY else {}
		var diary_raw: Variant = life.get("diary", {})
		var diary: Dictionary = diary_raw.duplicate(true) if typeof(diary_raw) == TYPE_DICTIONARY else {}
		var diary_lines_raw: Variant = diary.get("lines", [])
		if typeof(diary_lines_raw) == TYPE_ARRAY and not (diary_lines_raw as Array).is_empty():
			data ["lines"] = (diary_lines_raw as Array).duplicate(true)

	var shell_first_context: bool = bool(context.get("first_frame_is_live_runtime", false)) \
or bool(context.get("first_visible_runtime_boot", false)) \
or bool(context.get("playable_birth_shell_only", false)) \
or bool(context.get("live_reality_stream", false)) \
or bool(context.get("shell_first_handoff", false)) \
or bool(options.get("shell_first_handoff", false))

	var row_cap: int = int(options.get("ui_packet_row_cap", context.get("ui_packet_row_cap", 64)))
	if shell_first_context:
		row_cap = min(row_cap, 24)

	if row_cap > 0 and data.has("rows") and typeof(data.get("rows", [])) == TYPE_ARRAY:
		var rows: Array = data.get("rows", [])
		if rows.size() > row_cap:
			data ["rows"] = rows.slice(0, row_cap)
			data ["overflow_rows_deferred"] = rows.size() - row_cap
			degraded.append("rows")

	if row_cap > 0 and data.has("lines") and typeof(data.get("lines", [])) == TYPE_ARRAY:
		var lines: Array = data.get("lines", [])
		if lines.size() > row_cap:
			data ["lines"] = lines.slice(0, row_cap)
			data ["overflow_lines_deferred"] = lines.size() - row_cap
			degraded.append("lines")

	var row_weight: int = 0
	if data.has("rows") and typeof(data.get("rows", [])) == TYPE_ARRAY:
		row_weight += (data.get("rows", []) as Array).size()
	if data.has("sections") and typeof(data.get("sections", [])) == TYPE_ARRAY:
		row_weight += (data.get("sections", []) as Array).size() * 2
	if data.has("lines") and typeof(data.get("lines", [])) == TYPE_ARRAY:
		row_weight += (data.get("lines", []) as Array).size()

	var ui_may_render: bool = delayed.is_empty()
	var stability_tier: String = "stable_contract"
	if not delayed.is_empty():
		stability_tier = "blocked_deferred"
	elif shell_first_context and (not synthesized.is_empty() or bool(packet.get("synthesized_surface", false))):
		stability_tier = "shell_safe_synthesized"
	elif not degraded.is_empty():
		stability_tier = "heavy_degraded_stable"
	elif not synthesized.is_empty() or bool(packet.get("synthesized_surface", false)):
		stability_tier = "safe_synthesized"
	elif row_weight >= 96:
		stability_tier = "heavy_stable_background_reconcile"

	packet ["success"] = true
	packet ["data"] = data
	packet ["packet_contract"] = contract.duplicate(true)
	packet ["packet_contract_id"] = str(contract.get("id", ""))
	packet ["packet_contract_signature"] = _ui_packet_contract_signature(clean_surface, context, required)
	packet ["required_paths"] = required.duplicate(true)
	packet ["missing_requirements"] = missing
	packet ["synthesized_requirements"] = synthesized
	packet ["delayed_requirements"] = delayed
	packet ["degraded_requirements"] = degraded
	packet ["fallback_policy"] = str(contract.get("fallback_policy", "synthesize_if_missing"))
	packet ["validation"] = str(contract.get("validation", "strict"))
	packet ["stability_tier"] = stability_tier
	packet ["ui_packet_stability"] = {
		"tier": stability_tier,
		"row_weight": row_weight,
		"row_cap": row_cap,
		"shell_first_context": shell_first_context,
		"degraded": not degraded.is_empty(),
		"background_reconciliation_required": shell_first_context or not degraded.is_empty() or row_weight >= 96,
		"created_at_ms": int(Time.get_ticks_msec())
	}
	packet ["truth_layer"] = {
		"simulation_truth": "runtime",
		"perceived_truth": "ui_safe_packet",
		"ui_may_render": ui_may_render,
		"deferred_truth_policy": shell_first_context or not synthesized.is_empty(),
		"stability_tier": stability_tier
	}
	packet ["deferred_truth_policy"] = {
		"enabled": shell_first_context or not synthesized.is_empty(),
		"ui_may_render": ui_may_render,
		"requires_background_reconciliation": shell_first_context or not degraded.is_empty() or row_weight >= 96,
	}
	packet ["contract_status"] = "satisfied" if delayed.is_empty() else "deferred"
	packet ["ui_safe"] = ui_may_render
	packet ["pure_renderer_ready"] = ui_may_render
	packet ["background_reconciliation_required"] = bool(packet ["ui_packet_stability"].get("background_reconciliation_required", false))
	packet ["contract_satisfied_at_ms"] = int(Time.get_ticks_msec())
	packet ["options"] = options.duplicate(true)

	return _make_binary_safe(packet)

func _ui_packet_contract_for_surface(surface_id: String) -> Dictionary:
	var clean_surface: String = str(surface_id).strip_edges()
	var required: Array = _ui_packet_required_paths_for_surface(clean_surface)

	return {
		"schema": "eralife.ui_packet_contract",
		"version": UI_CONTRACT_VERSION,
		"id": "eralife.ui_packet.%s" % clean_surface,
		"surface_id": clean_surface,
		"surface_type": _ui_packet_surface_type(clean_surface),
		"layout": _ui_packet_layout(clean_surface),
		"title": _ui_packet_title(clean_surface),
		"subtitle": _ui_packet_subtitle(clean_surface),
		"theme_id": _ui_packet_theme(clean_surface),
		"required": required,
		"fallback_policy": "synthesize_if_missing",
		"validation": "strict",
		"truth_policy": {
			"ui_is_pure_renderer": true,
		}
	}


func _ui_packet_required_paths_for_surface(surface_id: String) -> Array:
	var clean_surface: String = str(surface_id).strip_edges().to_lower()

	match clean_surface:
		"life_panel":
			return [
				"player.identity",
				"player.stats",
				"life.diary",
				"relationships.core",
				"world.population_presence",
				"belongings.summary",
				"ui.navigation"
			]
		"player_stats_overlay":
			return [
				"player.identity",
				"player.stats",
				"world.identity",
				"ui.navigation"
			]
		"relationship_contract_hub":
			return [
				"player.identity",
				"relationships.core",
				"relationships.family",
				"relationships.social_actions",
				"world.population_presence",
				"ui.navigation"
			]
		"career_contract_hub":
			return [
				"player.identity",
				"player.stats",
				"career.core",
				"career.available_actions",
				"world.identity",
				"ui.navigation"
			]
		"school_contract_hub":
			return [
				"player.identity",
				"player.stats",
				"school.core",
				"school.available_actions",
				"relationships.core",
				"world.identity",
				"ui.navigation"
			]
		"world_feed_panel", "realm_contract_hub":
			return [
				"player.identity",
				"world.identity",
				"world.population_presence",
				"world.feed",
				"ui.navigation"
			]
		"belongings_hud", "inventory_contract_hub":
			return [
				"player.identity",
				"belongings.summary",
				"belongings.visible_items",
				"world.identity",
				"ui.navigation"
			]
		_:
			return [
				"player.identity",
				"player.stats",
				"world.identity",
				"ui.navigation"
			]


func _ui_packet_surface_type(surface_id: String) -> String:
	match str(surface_id).strip_edges().to_lower():
		"relationship_contract_hub", "career_contract_hub", "school_contract_hub", "realm_contract_hub":
			return "hub"
		"player_stats_overlay":
			return "card"
		_:
			return "panel"


func _ui_packet_layout(surface_id: String) -> String:
	match str(surface_id).strip_edges().to_lower():
		"relationship_contract_hub", "career_contract_hub", "school_contract_hub", "realm_contract_hub":
			return "hub_sections"
		"player_stats_overlay":
			return "detail_panel"
		_:
			return "scroll_list"


func _ui_packet_title(surface_id: String) -> String:
	match str(surface_id).strip_edges().to_lower():
		"life_panel":
			return "LIFE / DIARY"
		"relationship_contract_hub":
			return "RELATIONSHIPS"
		"career_contract_hub":
			return "CAREER"
		"school_contract_hub":
			return "SCHOOL"
		"world_feed_panel":
			return "WORLD"
		"realm_contract_hub":
			return "WORLD / REALMS"
		"belongings_hud", "inventory_contract_hub":
			return "BELONGINGS"
		"player_stats_overlay":
			return "PLAYER STATS"
		_:
			return str(surface_id).strip_edges().capitalize()


func _ui_packet_subtitle(surface_id: String) -> String:
	match str(surface_id).strip_edges().to_lower():
		"life_panel":
			return "Your life diary rendered from a contract-satisfied packet."
		"relationship_contract_hub":
			return "Family, friends, romance, rivals, and social memory stabilized for UI."
		"career_contract_hub":
			return "Jobs, income, fame routes, and work pressure stabilized for UI."
		"school_contract_hub":
			return "Education, classes, grades, classmates, and school actions stabilized for UI."
		"world_feed_panel":
			return "World seed, year, reality mode, and public events stabilized for UI."
		_:
			return "Perceived truth stabilized for the UI shell."


func _ui_packet_theme(surface_id: String) -> String:
	match str(surface_id).strip_edges().to_lower():
		"life_panel":
			return "life"
		"relationship_contract_hub":
			return "relationships"
		"career_contract_hub":
			return "career"
		"school_contract_hub":
			return "school"
		"world_feed_panel", "realm_contract_hub":
			return "world"
		"belongings_hud", "inventory_contract_hub":
			return "inventory"
		_:
			return "default"


func _ui_packet_fallback_for_path(path: String, surface_id: String, context: Dictionary = {}) -> Variant:
	match str(path).strip_edges():
		"player.identity":
			return _ui_packet_player_identity(context)
		"player.stats":
			return _ui_packet_player_stats(context)
		"life.diary":
			return _ui_packet_life_diary(context)
		"relationships.core":
			return _ui_packet_relationship_core(context)
		"relationships.family":
			return _ui_packet_relationship_family(context)
		"relationships.social_actions":
			return _ui_packet_relationship_actions(context)
		"career.core":
			return _ui_packet_career_core(context)
		"career.available_actions":
			return _ui_packet_career_actions(context)
		"school.core":
			return _ui_packet_school_core(context)
		"school.available_actions":
			return _ui_packet_school_actions(context)
		"world.identity":
			return _ui_packet_world_identity(context)
		"world.population_presence":
			return _ui_packet_population_presence(context)
		"world.feed":
			return _ui_packet_world_feed(context)
		"belongings.summary":
			return _ui_packet_belongings_summary(context)
		"belongings.visible_items":
			return _ui_packet_visible_belongings(context)
		"ui.navigation":
			return _ui_packet_navigation(surface_id, context)
		_:
			return {
				"placeholder": true,
				"path": path,
				"text": "This packet field is stabilizing."
			}


func _ui_packet_player_identity(_context: Dictionary = {}) -> Dictionary:
	var p = gs.player if gs != null and "player" in gs else null
	if p == null:
		return {
			"exists": false,
			"id": -1,
			"name": "Unknown",
			"first_name": "Unknown",
			"last_name": "",
			"age": 0,
			"placeholder": true
		}

	var first_name: String = str(_ui_packet_object_value(p, "first_name", "")).strip_edges()
	var last_name: String = str(_ui_packet_object_value(p, "last_name", "")).strip_edges()
	var full_name: String = ("%s %s" % [first_name, last_name]).strip_edges()
	if full_name == "":
		full_name = str(_ui_packet_object_value(p, "name", "Unknown")).strip_edges()
	if full_name == "":
		full_name = "Unknown"

	return {
		"exists": true,
		"id": int(_ui_packet_object_value(p, "id", -1)),
		"name": full_name,
		"first_name": first_name,
		"last_name": last_name,
		"gender": str(_ui_packet_object_value(p, "gender", "")),
		"age": int(_ui_packet_object_value(p, "age", 0)),
		"birth_city": str(_ui_packet_object_value(p, "birth_city", _ui_packet_object_value(p, "home_city", ""))),
		"birth_country": str(_ui_packet_object_value(p, "birth_country", _ui_packet_object_value(p, "home_country", ""))),
		"alive": bool(_ui_packet_object_value(p, "alive", true)),
		"placeholder": false
	}


func _ui_packet_player_stats(_context: Dictionary = {}) -> Dictionary:
	var p = gs.player if gs != null and "player" in gs else null
	if p == null:
		return {
			"health": 100,
			"mental_health": 100,
			"satisfaction": 100,
			"smarts": 100,
			"looks": 100,
			"bank_balance": 0,
			"placeholder": true
		}

	return {
		"health": int(round(float(_ui_packet_object_value(p, "health", 100)))),
		"mental_health": int(round(float(_ui_packet_object_value(p, "mental_health", 100)))),
		"satisfaction": int(round(float(_ui_packet_object_value(p, "satisfaction", 100)))),
		"smarts": int(round(float(_ui_packet_object_value(p, "smarts", 100)))),
		"looks": int(round(float(_ui_packet_object_value(p, "looks", 100)))),
		"imagination": int(round(float(_ui_packet_object_value(p, "imagination", 0)))),
		"fame": int(round(float(_ui_packet_object_value(p, "fame", 0)))),
		"approval": int(round(float(_ui_packet_object_value(p, "approval", 0)))),
		"bank_balance": int(_ui_packet_object_value(p, "bank_balance", 0)),
		"job": str(_ui_packet_object_value(p, "job", "")),
		"placeholder": false
	}


func _ui_packet_life_diary(context: Dictionary = {}) -> Dictionary:
	var lines: Array = []
	var raw_lines: Variant = context.get("diary_lines", context.get("lines", []))
	if typeof(raw_lines) == TYPE_ARRAY:
		for raw_line in raw_lines:
			lines.append(str(raw_line))

	if lines.is_empty() and gs != null and typeof(gs.world_feed) == TYPE_ARRAY:
		var start_index: int = max(0, gs.world_feed.size() - 5)
		for i in range(start_index, gs.world_feed.size()):
			var entry_text: String = str(gs.world_feed [i])
			if entry_text.strip_edges() != "":
				lines.append(entry_text)

	if lines.is_empty():
		lines.append("My life has begun. The rest of the world is still stabilizing around my first breath.")

	return {
		"lines": lines,
		"entry_count": lines.size(),
		"placeholder": bool(context.get("god_mode_life_prewarm", false)) and lines.size() <= 1
	}


func _ui_packet_relationship_core(_context: Dictionary = {}) -> Dictionary:
	var p = gs.player if gs != null and "player" in gs else null
	return {
		"parent_count": _ui_packet_object_array_count(p, "parents"),
		"sibling_count": _ui_packet_object_array_count(p, "siblings"),
		"child_count": _ui_packet_object_array_count(p, "children"),
		"friend_count": _ui_packet_object_array_count(p, "friends"),
		"ex_count": _ui_packet_object_array_count(p, "ex_partners"),
		"partner_id": int(_ui_packet_object_value(p, "partner_id", -1)),
		"placeholder": p == null
	}


func _ui_packet_relationship_family(context: Dictionary = {}) -> Dictionary:
	var core: Dictionary = _ui_packet_relationship_core(context)
	return {
		"summary": "Family graph ready.",
		"parent_count": int(core.get("parent_count", 0)),
		"sibling_count": int(core.get("sibling_count", 0)),
		"child_count": int(core.get("child_count", 0)),
		"placeholder": bool(core.get("placeholder", false))
	}


func _ui_packet_relationship_actions(_context: Dictionary = {}) -> Array:
	return [
		{
			"id": "relationships.view_family",
			"label": "View Family",
			"legacy_action_id": "Relationships Family",
			"kind": "ui_intent",
			"enabled": true
		},
		{
			"id": "relationships.view_friends",
			"label": "View Friends",
			"legacy_action_id": "Relationships Friends",
			"kind": "ui_intent",
			"enabled": true
		}
	]


func _ui_packet_career_core(_context: Dictionary = {}) -> Dictionary:
	var p = gs.player if gs != null and "player" in gs else null
	return {
		"job": str(_ui_packet_object_value(p, "job", "")),
		"income": int(_ui_packet_object_value(p, "income", 0)),
		"bank_balance": int(_ui_packet_object_value(p, "bank_balance", 0)),
		"age": int(_ui_packet_object_value(p, "age", 0)),
		"eligible_for_work": int(_ui_packet_object_value(p, "age", 0)) >= 14,
		"placeholder": p == null
	}


func _ui_packet_career_actions(_context: Dictionary = {}) -> Array:
	return [
		{
			"id": "career.full_time_jobs",
			"label": "Full-Time Jobs",
			"legacy_action_id": "Career Full-Time Jobs",
			"kind": "ui_intent",
			"enabled": true
		},
		{
			"id": "career.part_time_jobs",
			"label": "Part-Time Jobs",
			"legacy_action_id": "Career Part-Time Jobs",
			"kind": "ui_intent",
			"enabled": true
		}
	]


func _ui_packet_school_core(_context: Dictionary = {}) -> Dictionary:
	var p = gs.player if gs != null and "player" in gs else null
	return {
		"school": str(_ui_packet_object_value(p, "school", "")),
		"grade": str(_ui_packet_object_value(p, "grade", "")),
		"education_status": str(_ui_packet_object_value(p, "education_status", "Not enrolled yet")),
		"age": int(_ui_packet_object_value(p, "age", 0)),
		"placeholder": p == null
	}


func _ui_packet_school_actions(_context: Dictionary = {}) -> Array:
	return [
		{
			"id": "school.view_classes",
			"label": "View Classes",
			"legacy_action_id": "School Classes",
			"kind": "ui_intent",
			"enabled": true
		},
		{
			"id": "school.study",
			"label": "Study",
			"legacy_action_id": "School Study",
			"kind": "ui_intent",
			"enabled": true
		}
	]


func _ui_packet_world_identity(_context: Dictionary = {}) -> Dictionary:
	var era_name: String = "Unknown Era"
	if gs != null:
		if typeof(gs.era) == TYPE_DICTIONARY:
			era_name = str(gs.era.get("name", gs.era.get("key", era_name)))
		elif gs.era != null:
			era_name = str(gs.era.name)

	var seed_text: String = "Unknown"
	if gs != null and "seed_engine" in gs and gs.seed_engine != null:
		seed_text = str(gs.seed_engine.seed_value)

	var reality_mode: String = "realistic"
	if gs != null and typeof(gs.custom_settings) == TYPE_DICTIONARY:
		reality_mode = str(gs.custom_settings.get("reality_mode", reality_mode))

	return {
		"year": int(gs.year) if gs != null else 0,
		"era_name": era_name,
		"world_seed": seed_text,
		"reality_mode": reality_mode,
		"placeholder": gs == null
	}


func _ui_packet_population_presence(_context: Dictionary = {}) -> Dictionary:
	var npc_count: int = 0
	if gs != null and typeof(gs.npcs) == TYPE_ARRAY:
		npc_count = gs.npcs.size()

	return {
		"npc_count": npc_count,
		"population_ready": npc_count > 0,
		"placeholder": npc_count <= 0
	}


func _ui_packet_world_feed(_context: Dictionary = {}) -> Dictionary:
	var rows: Array = []
	if gs != null and typeof(gs.world_feed) == TYPE_ARRAY:
		var start_index: int = max(0, gs.world_feed.size() - 12)
		for i in range(start_index, gs.world_feed.size()):
			var raw_entry: Variant = gs.world_feed [i]
			var text: String = ""
			if typeof(raw_entry) == TYPE_DICTIONARY:
				var entry: Dictionary = raw_entry as Dictionary
				text = str(entry.get("text", entry.get("message", entry.get("label", "")))).strip_edges()
				if text == "":
					text = str(entry)
			else:
				text = str(raw_entry).strip_edges()

			if text != "":
				rows.append({
					"text": text,
					"sort_priority": i
				})

	if rows.is_empty():
		rows.append({
			"text": "The world is quiet while the first playable frame stabilizes.",
			"placeholder": true
		})

	return {
		"rows": rows,
		"count": rows.size(),
		"placeholder": rows.size() == 1 and bool((rows [0] as Dictionary).get("placeholder", false))
	}


func _ui_packet_belongings_summary(_context: Dictionary = {}) -> Dictionary:
	var rows: Array = []
	var openable: bool = gs != null and gs.player != null and "belongings_engine" in gs and gs.belongings_engine != null

	if openable:
		if gs.belongings_engine.has_method("get_player_inventory_rows"):
			var resolved: Variant = gs.belongings_engine.get_player_inventory_rows({
				"source": "ui_packet_contract_engine"
			})
			if typeof(resolved) == TYPE_ARRAY:
				rows = (resolved as Array).duplicate(true)

	return {
		"visible_count": rows.size(),
		"has_visible_items": openable,
		"placeholder": not openable,
		"openable": openable,
		"text": "Belongings ready." if not rows.is_empty() else "Belongings ready. Nothing is being carried yet."
	}

func _ui_packet_visible_belongings(context: Dictionary = {}) -> Array:
	var summary: Dictionary = _ui_packet_belongings_summary(context)
	if bool(summary.get("placeholder", false)):
		return []
	return [
		{
			"id": "belongings.summary",
			"title": "Belongings",
			"description": str(summary.get("text", "Belongings ready."))
		}
	]


func _ui_packet_navigation(surface_id: String, _context: Dictionary = {}) -> Dictionary:
	return {
		"surface_id": surface_id,
		"renderer": "pure_shell",
		"may_open": true,
		"may_close": true,
		"placeholder": false
	}


func _ui_packet_lines_from_data(surface_id: String, data: Dictionary, _context: Dictionary = {}) -> Array:
	var clean_surface: String = str(surface_id).strip_edges().to_lower()
	var lines: Array = []

	match clean_surface:
		"relationship_contract_hub":
			var relationships: Dictionary = _ui_packet_nested_dictionary(data, "relationships.core")
			lines.append("Family: %d parents • %d siblings • %d children" % [
				int(relationships.get("parent_count", 0)),
				int(relationships.get("sibling_count", 0)),
				int(relationships.get("child_count", 0))
			])
			lines.append("Social: %d friends • %d exes" % [
				int(relationships.get("friend_count", 0)),
				int(relationships.get("ex_count", 0))
			])
		"career_contract_hub":
			var career: Dictionary = _ui_packet_nested_dictionary(data, "career.core")
			var job: String = str(career.get("job", "")).strip_edges()
			lines.append("Current job: %s" % (job if job != "" else "None yet"))
			lines.append("Work eligibility: %s" % ("Ready" if bool(career.get("eligible_for_work", false)) else "Not yet"))
		"school_contract_hub":
			var school: Dictionary = _ui_packet_nested_dictionary(data, "school.core")
			lines.append("School: %s" % str(school.get("school", "Not enrolled yet")))
			lines.append("Education status: %s" % str(school.get("education_status", "Stabilizing")))
		"world_feed_panel", "realm_contract_hub":
			var world: Dictionary = _ui_packet_nested_dictionary(data, "world.identity")
			lines.append("Year: %s" % str(world.get("year", 0)))
			lines.append("Era: %s" % str(world.get("era_name", "Unknown Era")))
			lines.append("World Seed: %s" % str(world.get("world_seed", "Unknown")))
			var feed: Dictionary = _ui_packet_nested_dictionary(data, "world.feed")
			var feed_rows: Array = feed.get("rows", []) if typeof(feed.get("rows", [])) == TYPE_ARRAY else []
			for raw_row in feed_rows:
				if typeof(raw_row) == TYPE_DICTIONARY:
					lines.append(str((raw_row as Dictionary).get("text", "")))
				else:
					lines.append(str(raw_row))
		"life_panel":
			var diary: Dictionary = _ui_packet_nested_dictionary(data, "life.diary")
			var diary_lines: Array = diary.get("lines", []) if typeof(diary.get("lines", [])) == TYPE_ARRAY else []
			for raw_line in diary_lines:
				lines.append(str(raw_line))
		_:
			lines.append("This UI surface is ready.")
			lines.append("Simulation truth may continue catching up behind the perceived UI packet.")

	if lines.is_empty():
		lines.append("This UI packet is stable and ready.")

	return lines


func _ui_packet_data_has_path(data: Dictionary, path: String) -> bool:
	var parts: PackedStringArray = str(path).split(".")
	if parts.is_empty():
		return false

	var cursor: Variant = data
	for raw_part in parts:
		var part: String = str(raw_part).strip_edges()
		if part == "":
			return false
		if typeof(cursor) != TYPE_DICTIONARY:
			return false
		var cursor_dict: Dictionary = cursor as Dictionary
		if not cursor_dict.has(part):
			return false
		cursor = cursor_dict.get(part)

	return true


func _ui_packet_data_set_path(data: Dictionary, path: String, value: Variant) -> void:
	var parts: PackedStringArray = str(path).split(".")
	if parts.is_empty():
		return

	var cursor: Dictionary = data
	for i in range(parts.size()):
		var part: String = str(parts [i]).strip_edges()
		if part == "":
			continue

		if i == parts.size() - 1:
			cursor [part] = value
			return

		var next_raw: Variant = cursor.get(part, {})
		if typeof(next_raw) != TYPE_DICTIONARY:
			next_raw = {}
			cursor [part] = next_raw

		var next_dict: Dictionary = next_raw as Dictionary
		cursor = next_dict


func _ui_packet_nested_dictionary(data: Dictionary, path: String) -> Dictionary:
	var parts: PackedStringArray = str(path).split(".")
	var cursor: Variant = data

	for raw_part in parts:
		var part: String = str(raw_part).strip_edges()
		if part == "":
			return {}
		if typeof(cursor) != TYPE_DICTIONARY:
			return {}
		var cursor_dict: Dictionary = cursor as Dictionary
		if not cursor_dict.has(part):
			return {}
		cursor = cursor_dict.get(part)

	if typeof(cursor) == TYPE_DICTIONARY:
		return (cursor as Dictionary).duplicate(true)

	return {}


func _ui_packet_contract_signature(surface_id: String, context: Dictionary, required: Array) -> String:
	return "%s::actor:%s::year:%s::rev:%s::required:%d" % [
		str(surface_id).strip_edges().to_lower(),
		str(context.get("actor_id", "")),
		str(context.get("year", "")),
		str(context.get("revision", context.get("diary_revision", ""))),
		required.size()
	]


func _ui_packet_object_value(obj: Variant, property_id: String, fallback: Variant = null) -> Variant:
	if obj == null:
		return fallback
	if obj is Object:
		var value: Variant = obj.get(property_id)
		if value != null:
			return value
	return fallback


func _ui_packet_object_array_count(obj: Variant, property_id: String) -> int:
	var value: Variant = _ui_packet_object_value(obj, property_id, [])
	if typeof(value) == TYPE_ARRAY:
		return (value as Array).size()
	return 0

func _ui_packet_cache_key(surface_id: String, context: Dictionary = {}) -> String:
	var clean_surface: String = str(surface_id).strip_edges().to_lower()
	var device_profile: String = str(context.get("device_profile", device_profile_override)).strip_edges().to_lower()
	if device_profile == "":
		device_profile = "auto"

	var actor_id: int = int(context.get("actor_id", _get_player_value("id", -1)))
	var active_section_id: String = str(context.get("active_section_id", "")).strip_edges().to_lower()
	var revision: String = str(context.get("revision", context.get("diary_revision", context.get("year", "")))).strip_edges()

	return "%s::actor:%d::device:%s::section:%s::rev:%s" % [
		clean_surface,
		actor_id,
		device_profile,
		active_section_id,
		revision
	]
func get_surface_view_model(surface_id: String, context: Dictionary = {}) -> Dictionary:
	var surface: Dictionary = resolve_surface(surface_id, context)
	if surface.is_empty():
		return {}

	var sections: Array = surface.get("sections", []) if typeof(surface.get("sections", [])) == TYPE_ARRAY else []
	var runtime_state: Dictionary = surface_runtime_state.get(surface_id, {}).duplicate(true) if typeof(surface_runtime_state.get(surface_id, {})) == TYPE_DICTIONARY else {}

	var requested_section_id: String = str(context.get("active_section_id", "")).strip_edges()
	if requested_section_id == "":
		requested_section_id = str(active_section_by_surface.get(surface_id, "")).strip_edges()
	if requested_section_id == "":
		requested_section_id = str(runtime_state.get("active_section_id", "")).strip_edges()

	var first_section_id: String = ""
	var default_section_id: String = ""
	var available_section_ids: Array = []

	for raw_section in sections:
		if typeof(raw_section) != TYPE_DICTIONARY:
			continue

		var section: Dictionary = raw_section
		var section_id: String = str(section.get("id", "")).strip_edges()
		if section_id == "":
			continue

		if first_section_id == "":
			first_section_id = section_id

		if default_section_id == "" and bool(section.get("is_default", false)):
			default_section_id = section_id

		if not available_section_ids.has(section_id):
			available_section_ids.append(section_id)

	var active_section_id: String = ""
	if requested_section_id != "" and available_section_ids.has(requested_section_id):
		active_section_id = requested_section_id
	elif default_section_id != "":
		active_section_id = default_section_id
	else:
		active_section_id = first_section_id

	var active_section: Dictionary = {}
	var section_tabs: Array = []

	for raw_section in sections:
		if typeof(raw_section) != TYPE_DICTIONARY:
			continue

		var section: Dictionary = raw_section
		var section_id: String = str(section.get("id", "")).strip_edges()
		if section_id == "":
			continue

		var is_active: bool = section_id == active_section_id
		if is_active:
			active_section = section.duplicate(true)

		section_tabs.append({
			"id": section_id,
			"label": str(section.get("label", section_id)),
			"title": str(section.get("title", section.get("label", section_id))),
			"icon": str(section.get("icon", "")),
			"enabled": bool(section.get("enabled", true)),
			"active": is_active,
			"badge_count": int(section.get("badge_count", 0)),
			"badge_color": str(section.get("badge_color", "")),
			"trailing_text": str(section.get("trailing_text", "")),
			"pulse_text": str(section.get("pulse_text", "")),
			"pulse_key": str(section.get("pulse_key", "")),
			"pulse_tone": str(section.get("pulse_tone", "")),
			"tooltip": str(section.get("tooltip", section.get("description", "")))
		})
	if active_section.is_empty() and not sections.is_empty() and typeof(sections [0]) == TYPE_DICTIONARY:
		active_section = (sections [0] as Dictionary).duplicate(true)
		active_section_id = str(active_section.get("id", active_section_id)).strip_edges()

	if active_section_id != "":
		active_section_by_surface [surface_id] = active_section_id
		runtime_state ["active_section_id"] = active_section_id
		runtime_state ["updated_at_ms"] = int(Time.get_ticks_msec())
		surface_runtime_state [surface_id] = runtime_state.duplicate(true)

	surface ["active_section_id"] = active_section_id
	surface ["active_section"] = active_section
	surface ["section_tabs"] = section_tabs
	surface ["runtime_state"] = runtime_state.duplicate(true)

	return surface

func set_active_section(surface_id: String, section_id: String) -> Dictionary:
	var clean_surface: String = str(surface_id).strip_edges()
	var clean_section: String = str(section_id).strip_edges()

	if clean_surface == "" or clean_section == "":
		return {
			"success": false,
			"reason": "Missing surface_id or section_id."
		}

	active_section_by_surface [clean_surface] = clean_section

	var state: Dictionary = surface_runtime_state.get(clean_surface, {}).duplicate(true) if typeof(surface_runtime_state.get(clean_surface, {})) == TYPE_DICTIONARY else {}
	state ["active_section_id"] = clean_section
	state ["updated_at_ms"] = int(Time.get_ticks_msec())
	surface_runtime_state [clean_surface] = state

	return {
		"success": true,
		"surface_id": clean_surface,
		"active_section_id": clean_section
	}

func resolve_data_source(data_source: String, context: Dictionary = {}, surface: Dictionary = {}) -> Array:
	var clean: String = str(data_source).strip_edges()
	if clean == "":
		return []

	match clean:
		"bending.available_abilities":
			if gs != null and gs.bending_engine != null and gs.player != null and gs.bending_engine.has_method("get_available_bending_abilities"):
				return gs.bending_engine.get_available_bending_abilities(gs.player)

		"wizard.available_spells":
			if gs != null and gs.wizard_engine != null and gs.player != null and gs.wizard_engine.has_method("get_available_spells"):
				return gs.wizard_engine.get_available_spells(gs.player)

		"career.full_time_jobs":
			if gs != null and gs.career_engine != null and gs.player != null:
				return gs.career_engine.get_available_jobs_for(gs.player)

		"career.part_time_jobs":
			if gs != null and gs.career_engine != null and gs.player != null:
				return gs.career_engine.get_available_part_time_jobs_for(gs.player)

		"career.famous_tracks":
			if gs != null and gs.career_engine != null and gs.player != null:
				return gs.career_engine.get_famous_career_tracks_for(gs.player)

		"realm.external_entries":
			if gs != null and gs.realm_contract_engine != null and gs.realm_contract_engine.has_method("get_external_surface_entries"):
				return gs.realm_contract_engine.get_external_surface_entries()

		"scenario.available_contracts":
			if gs != null and gs.simulation_contract_engine != null and gs.simulation_contract_engine.has_method("get_available_scenario_contracts"):
				return gs.simulation_contract_engine.get_available_scenario_contracts(context)

		"ui.embedded_surface_launcher":
			return _embedded_surface_launcher_rows(context)

		"ui.valid_surfaces":
			return get_valid_surfaces(context)

		"life.relationship_surface":
			return _embedded_relationship_surface_rows(context)

		"life.activity_surface":
			return _embedded_activity_surface_rows(context)

		"grocery.stores":
			if gs != null and gs.grocery_store_engine != null and gs.grocery_store_engine.has_method("get_grocery_store_rows"):
				return gs.grocery_store_engine.get_grocery_store_rows(context)
		"grocery.aisles":
			if gs != null and gs.grocery_store_engine != null and gs.grocery_store_engine.has_method("get_grocery_aisle_rows"):
				return gs.grocery_store_engine.get_grocery_aisle_rows(context)
		"grocery.items":
			if gs != null and gs.grocery_store_engine != null and gs.grocery_store_engine.has_method("get_grocery_item_rows"):
				return gs.grocery_store_engine.get_grocery_item_rows(context)
		"grocery.cart":
			if gs != null and gs.grocery_store_engine != null and gs.grocery_store_engine.has_method("get_grocery_cart_rows"):
				return gs.grocery_store_engine.get_grocery_cart_rows(context)
		"grocery.cashier":
			if gs != null and gs.grocery_store_engine != null and gs.grocery_store_engine.has_method("get_grocery_cashier_rows"):
				return gs.grocery_store_engine.get_grocery_cashier_rows(context)
		"grocery.self_checkout":
			if gs != null and gs.grocery_store_engine != null and gs.grocery_store_engine.has_method("get_grocery_self_checkout_rows"):
				return gs.grocery_store_engine.get_grocery_self_checkout_rows(context)
		"restaurant.intent":
			if gs != null and gs.food_restaurant_engine != null and gs.food_restaurant_engine.has_method("get_restaurant_intent_rows"):
				return gs.food_restaurant_engine.get_restaurant_intent_rows(context)
		"restaurant.date_candidates":
			if gs != null and gs.food_restaurant_engine != null and gs.food_restaurant_engine.has_method("get_date_candidate_rows"):
				return gs.food_restaurant_engine.get_date_candidate_rows(context)
		"restaurant.categories":
			if gs != null and gs.food_restaurant_engine != null and gs.food_restaurant_engine.has_method("get_restaurant_category_rows"):
				return gs.food_restaurant_engine.get_restaurant_category_rows(context)
		"restaurant.list", "restaurant.list_by_category":
			if gs != null and gs.food_restaurant_engine != null and gs.food_restaurant_engine.has_method("get_restaurant_rows"):
				return gs.food_restaurant_engine.get_restaurant_rows(context)
		"restaurant.service":
			if gs != null and gs.food_restaurant_engine != null and gs.food_restaurant_engine.has_method("get_restaurant_service_rows"):
				return gs.food_restaurant_engine.get_restaurant_service_rows(context)
		"restaurant.menu":
			if gs != null and gs.food_restaurant_engine != null and gs.food_restaurant_engine.has_method("get_menu_rows"):
				return gs.food_restaurant_engine.get_menu_rows(context)
		"restaurant.cart":
			if gs != null and gs.food_restaurant_engine != null and gs.food_restaurant_engine.has_method("get_restaurant_cart_rows"):
				return gs.food_restaurant_engine.get_restaurant_cart_rows(context)
		"restaurant.date_turn":
			if gs != null and gs.food_restaurant_engine != null and gs.food_restaurant_engine.has_method("get_restaurant_date_turn_rows"):
				return gs.food_restaurant_engine.get_restaurant_date_turn_rows(context)
		"restaurant.flings", "relationship.flings":
				return _relationship_fling_surface_rows(context)
		"luxury.shops":
			if gs != null and gs.luxury_shop_engine != null and gs.luxury_shop_engine.has_method("get_luxury_shop_rows"):
				return gs.luxury_shop_engine.get_luxury_shop_rows(context)

		"luxury.items":
			if gs != null and gs.luxury_shop_engine != null and gs.luxury_shop_engine.has_method("get_luxury_item_rows"):
				return gs.luxury_shop_engine.get_luxury_item_rows(context)

		"luxury.item_overview":
			if gs != null and gs.luxury_shop_engine != null and gs.luxury_shop_engine.has_method("get_luxury_item_overview_rows"):
				return gs.luxury_shop_engine.get_luxury_item_overview_rows(context)

		_:
			if data_source_registry.has(clean):
				return _resolve_registered_data_source(data_source_registry.get(clean, {}), context, surface)

	return []
func _relationship_fling_surface_rows(context: Dictionary = {}) -> Array:
	var out: Array = []
	var seen_people: Dictionary = {}

	if gs != null and gs.food_restaurant_engine != null and gs.food_restaurant_engine.has_method("get_restaurant_fling_rows"):
		for raw_row in gs.food_restaurant_engine.get_restaurant_fling_rows(context):
			if typeof(raw_row) != TYPE_DICTIONARY:
				continue

			var row: Dictionary = raw_row as Dictionary
			if str(row.get("kind", "")) == "relationship_empty_flings":
				continue

			var person_id: int = int(row.get("person_id", -1))
			if person_id > 0:
				if seen_people.has(person_id):
					continue
				seen_people [person_id] = true

			out.append(row.duplicate(true))

	if gs != null and gs.romance_contract_engine != null and gs.romance_contract_engine.has_method("get_foreign_romance_fling_rows"):
		for raw_romance_row in gs.romance_contract_engine.get_foreign_romance_fling_rows(context):
			if typeof(raw_romance_row) != TYPE_DICTIONARY:
				continue

			var romance_row: Dictionary = raw_romance_row as Dictionary
			var romance_person_id: int = int(romance_row.get("person_id", -1))
			if romance_person_id > 0:
				if seen_people.has(romance_person_id):
					continue
				seen_people [romance_person_id] = true

			out.append(romance_row.duplicate(true))

	if out.is_empty():
		out.append({
			"label": "No flings yet",
			"description": "Restaurant flings and long-distance writing flings can appear here without occupying the serious partner slot.",
			"kind": "relationship_empty_flings"
		})

	return out
func _embedded_surface_launcher_rows(context: Dictionary = {}) -> Array:
	var out: Array = []
	var device_profile: String = _resolve_device_profile(context)
	for surface_id in surface_registry.keys():
		var clean_surface: String = str(surface_id).strip_edges()
		if clean_surface == "" or clean_surface == "discord_life_hub":
			continue
		var raw_surface: Variant = surface_registry.get(clean_surface, {})
		if typeof(raw_surface) != TYPE_DICTIONARY:
			continue
		var surface: Dictionary = _apply_device_override((raw_surface as Dictionary).duplicate(true), device_profile)
		if not _surface_supports_device(surface, device_profile):
			continue
		if not _passes_rule(surface.get("visibility_rule", "always"), context, surface):
			continue

		var label: String = str(surface.get("title", surface.get("label", clean_surface))).strip_edges()
		var subtitle: String = str(surface.get("subtitle", surface.get("description", "Open this EraLife surface."))).strip_edges()
		var icon: String = str(surface.get("icon", "")).strip_edges()
		var category: String = _embedded_surface_category(clean_surface)
		var action_label: String = _embedded_surface_action_label(clean_surface)

		out.append({
			"id": clean_surface,
			"surface_id": clean_surface,
			"title": "%s %s" % [icon, label] if icon != "" else label,
			"description": "%s\n\n%s" % [category, subtitle],
			"sort_priority": int(surface.get("sort_priority", 50)),
			"actions": [
				{
					"id": "open_surface:%s" % clean_surface,
					"label": action_label,
					"kind": "open_surface",
					"target": clean_surface,
					"style": "primary",
					"enabled": true
				}
			]
		})

	out.sort_custom(func (a, b):
		var pa: int = int((a as Dictionary).get("sort_priority", 50))
		var pb: int = int((b as Dictionary).get("sort_priority", 50))
		if pa == pb:
			return str((a as Dictionary).get("title", "")) < str((b as Dictionary).get("title", ""))
		return pa < pb
	)
	return out
func _embedded_surface_category(surface_id: String) -> String:
	var clean: String = str(surface_id).strip_edges().to_lower()
	match clean:
		"bank_contract_hub":
			return "🏦 Money, accounts, cash risk, deposits, and withdrawals."
		"career_contract_hub":
			return "💼 Work, jobs, fame paths, and income routes."
		"restaurant_contract_hub":
			return "🍔 Food spots, menus, dates, drive-through, and dining choices."
		"grocery_contract_hub":
			return "🛒 Stores, food supplies, pantry pressure, and survival shopping."
		"luxury_contract_hub":
			return "💎 High-end shops, rare items, flex purchases, and lifestyle upgrades."
		"inventory_contract_hub":
			return "🎒 Belongings, owned items, carried objects, and personal property."
		"realm_contract_hub":
			return "🌐 Other countries, realms, travel surfaces, and world-facing entries."
		"bending_contract_hub":
			return "🌀 Bending training, abilities, mastery, and elemental identity."
		"scenario_contract_hub":
			return "🎭 Interactive scenarios, choices, risk events, and story branches."
		_:
			return "✨ EraLife surface available through the Discord UI shell."


func _embedded_surface_action_label(surface_id: String) -> String:
	var clean: String = str(surface_id).strip_edges().to_lower()
	match clean:
		"bank_contract_hub":
			return "Open Bank"
		"career_contract_hub":
			return "Open Career"
		"restaurant_contract_hub":
			return "Open Food"
		"grocery_contract_hub":
			return "Open Store"
		"luxury_contract_hub":
			return "Open Luxury"
		"inventory_contract_hub":
			return "Open Items"
		"realm_contract_hub":
			return "Open World"
		"bending_contract_hub":
			return "Open Bending"
		"scenario_contract_hub":
			return "Open Story"
		_:
			return "Open"
func _embedded_relationship_surface_rows(context: Dictionary = {}) -> Array:
	if gs != null and gs.has_method("get") and gs.get("relationship_engine") != null:
		var relationship_engine = gs.get("relationship_engine")
		if relationship_engine.has_method("get_embedded_relationship_rows"):
			var rows: Variant = relationship_engine.get_embedded_relationship_rows(context)
			if typeof(rows) == TYPE_ARRAY:
				return rows

	return [
		{
			"id": "immediate_family",
			"title": "👨‍👩‍👧 Immediate Family",
			"description": "Parents, siblings, children, and household bonds will route here as relationship contracts expand.",
			"sort_priority": 10,
			"actions": [
				{
					"id": "open_surface:discord_life_hub",
					"label": "Back to Hub",
					"kind": "open_surface",
					"target": "discord_life_hub",
					"style": "secondary",
					"enabled": true
				}
			]
		},
		{
			"id": "friends",
			"title": "🤝 Friends",
			"description": "Friendships, rivals, classmates, coworkers, and social history can be projected here.",
			"sort_priority": 20
		},
		{
			"id": "romance",
			"title": "❤️ Romance",
			"description": "Dating, marriage, breakups, commitment, and compatibility can become their own contract rows.",
			"sort_priority": 30
		}
	]


func _embedded_activity_surface_rows(_context: Dictionary = {}) -> Array:
	var movie_enabled: bool = _movie_theater_player_can_open()
	var movie_description: String = "Go to the movies through a contract-driven shared public space: choose a theater, pick a movie, stand in line, buy tickets and snacks, then react to audience friction."
	if not movie_enabled:
		movie_description = "Movie theaters unlock in the Modern and Future eras."

	return [
		{
			"id": "entertainment_movies",
			"title": "🎬 Movies",
			"description": movie_description,
			"sort_priority": 5,
			"actions": [
				{
					"id": "open_surface:movie_theater_contract_hub",
					"label": "Go To The Movies",
					"kind": "open_surface",
					"target": "movie_theater_contract_hub",
					"style": "primary",
					"enabled": movie_enabled
				}
			]
		},
		{
			"id": "mind_body",
			"title": "   Mind & Body",
			"description": "Train, meditate, work out, recover, study, and build your character through future activity contracts.",
			"sort_priority": 10
		},
		{
			"id": "social",
			"title": "   Social",
			"description": "Hang out, post, perform, argue, date, prank, network, and start chaos through routed scenarios.",
			"sort_priority": 20,
			"actions": [
				{
					"id": "open_surface:scenario_contract_hub",
					"label": "Open Stories",
					"kind": "open_surface",
					"target": "scenario_contract_hub",
					"style": "primary",
					"enabled": true
				}
			]
		},
		{
			"id": "risk",
			"title": "    Risk",
			"description": "Crime, dares, survival pressure, fame stunts, and consequences should all route through scenario contracts.",
			"sort_priority": 30
		},
		{
			"id": "travel_world",
			"title": "    World",
			"description": "Travel, migrate, visit realms, join public events, and affect the wider shared timeline.",
			"sort_priority": 40,
			"actions": [
				{
					"id": "open_surface:realm_contract_hub",
					"label": "Open World",
					"kind": "open_surface",
					"target": "realm_contract_hub",
					"style": "secondary",
					"enabled": true
				}
			]
		}
	]
func build_action_packet(surface_id: String, action_id: String, payload: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	var clean_surface: String = str(surface_id).strip_edges()
	var clean_action: String = str(action_id).strip_edges()

	var surface: Dictionary = resolve_surface(clean_surface, context)
	var route: Dictionary = action_route_registry.get(clean_action, {}).duplicate(true) if typeof(action_route_registry.get(clean_action, {})) == TYPE_DICTIONARY else {}
	if route.is_empty() and not surface.is_empty():
		route = _find_action_in_surface(surface, clean_action)
	if route.is_empty() and typeof(payload.get("_inline_action_route", {})) == TYPE_DICTIONARY:
		route = (payload.get("_inline_action_route", {}) as Dictionary).duplicate(true)
	var merged_payload: Dictionary = {}
	if typeof(route.get("payload", {})) == TYPE_DICTIONARY:
		merged_payload = route.get("payload", {}).duplicate(true)
	for key in payload.keys():
		merged_payload [key] = payload [key]

	var success: bool = not route.is_empty()
	var command_envelope: Dictionary = {}
	if success:
		command_envelope = _build_command_envelope(clean_surface, clean_action, route, merged_payload, context)

	return {
		"success": success,
		"schema": "eralife.ui_action_packet",
		"version": UI_CONTRACT_VERSION,
		"surface_id": clean_surface,
		"action_id": clean_action,
		"route": route.duplicate(true),
		"payload": merged_payload.duplicate(true),
		"context": context.duplicate(true),
		"command_envelope": command_envelope,
		"built_at_ms": int(Time.get_ticks_msec())
	}

func route_interaction(surface_id: String, action_id: String, payload: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	var dynamic_report: Dictionary = _route_dynamic_embedded_action(surface_id, action_id, payload, context)
	if not dynamic_report.is_empty():
		last_action_report = _make_binary_safe(dynamic_report)
		return last_action_report.duplicate(true)

	var packet: Dictionary = build_action_packet(surface_id, action_id, payload, context)
	if not bool(packet.get("success", false)):
		last_action_report = packet.duplicate(true)
		return packet

	var route: Dictionary = packet.get("route", {})
	var kind: String = str(route.get("kind", "packet")).strip_edges().to_lower()
	var report: Dictionary = packet.duplicate(true)
	report ["handled"] = false
	report ["action_result"] = {}

	match kind:
		"open_section":
			var target_section: String = str(route.get("target", route.get("section_id", ""))).strip_edges()
			report ["action_result"] = set_active_section(surface_id, target_section)
			report ["handled"] = bool(report ["action_result"].get("success", false))
		"open_surface":
			report ["next_surface_id"] = str(route.get("target", "")).strip_edges()
			report ["handled"] = true
		"scenario":
			report ["action_result"] = _route_scenario_action(route, packet.get("payload", {}), context)
			report ["handled"] = bool(report ["action_result"].get("success", false))
		"engine_call", "method":
			report ["action_result"] = _route_engine_call(route, packet.get("payload", {}), context)
			report ["handled"] = bool(report ["action_result"].get("success", false))
		"command":
			report ["action_result"] = _route_command_envelope(packet.get("command_envelope", {}))
			report ["handled"] = bool(report ["action_result"].get("success", false))
		_:
			report ["handled"] = true
			report ["action_result"] = {
				"success": true,
				"mode": "packet_only",
				"packet": packet.duplicate(true)
			}

	last_action_report = _make_binary_safe(report)
	return last_action_report.duplicate(true)
func _route_dynamic_embedded_action(surface_id: String, action_id: String, _payload: Dictionary = {}, _context: Dictionary = {}) -> Dictionary:
	var clean_surface: String = str(surface_id).strip_edges()
	var clean_action: String = str(action_id).strip_edges()
	if clean_surface == "" or clean_action == "":
		return {}

	var movie_theater_report: Dictionary = _route_movie_theater_dynamic_action(clean_surface, clean_action, _payload, _context)
	if not movie_theater_report.is_empty():
		return movie_theater_report

	var food_lifestyle_report: Dictionary = _route_food_lifestyle_dynamic_action(clean_surface, clean_action, _payload, _context)
	if not food_lifestyle_report.is_empty():
		return food_lifestyle_report

	var parts = clean_action.split(":")
	if parts.size() <= 0:
		return {}

	var verb: String = str(parts [0]).strip_edges().to_lower()
	match verb:
		"open_surface":
			if parts.size() < 2:
				return {}
			var target_surface_id: String = str(parts [1]).strip_edges()
			if target_surface_id == "":
				return {}
			return {
				"success": true,
				"handled": true,
				"surface_id": clean_surface,
				"next_surface_id": target_surface_id,
				"action_id": clean_action,
				"mode": "dynamic_open_surface"
			}
		"restaurant_menu":
			if parts.size() < 2:
				return {}
			var restaurant_id: String = str(parts [1]).strip_edges()
			sync_surface_state(clean_surface, {
				"restaurant_id": restaurant_id,
				"notice": ""
			})
			set_active_section(clean_surface, "menu")
			return {
				"success": true,
				"handled": true,
				"surface_id": clean_surface,
				"next_surface_id": clean_surface,
				"action_id": clean_action,
				"mode": "dynamic_restaurant_menu",
				"restaurant_id": restaurant_id
			}

		"restaurant_back":
			sync_surface_state(clean_surface, {
				"restaurant_id": "",
				"food_id": "",
				"notice": ""
			})
			set_active_section(clean_surface, "restaurants")
			return {
				"success": true,
				"handled": true,
				"surface_id": clean_surface,
				"next_surface_id": clean_surface,
				"action_id": clean_action,
				"mode": "dynamic_restaurant_back"
			}

		"restaurant_order":
			if parts.size() < 4:
				return {}
			if gs == null or gs.player == null or gs.food_restaurant_engine == null:
				return {
					"success": false,
					"handled": true,
					"surface_id": clean_surface,
					"next_surface_id": clean_surface,
					"action_id": clean_action,
					"reason": "Restaurant runtime is unavailable."
				}

			var order_restaurant_id: String = str(parts [1]).strip_edges()
			var food_id: String = str(parts [2]).strip_edges()
			var service_mode: String = str(parts [3]).strip_edges()

			var order_report: Dictionary = gs.food_restaurant_engine.place_order(gs.player, order_restaurant_id, food_id, {
				"source": "embedded_ui_contract_engine",
				"order_mode": "takeout" if service_mode in ["takeout", "drive_through"] else "eat_now",
				"service_mode": service_mode
			})

			sync_surface_state(clean_surface, {
				"restaurant_id": order_restaurant_id,
				"food_id": food_id,
				"notice": str(order_report.get("text", order_report.get("reason", "Restaurant order resolved."))),
				"last_action_report": order_report.duplicate(true)
			})
			set_active_section(clean_surface, "menu")

			return {
				"success": bool(order_report.get("success", false)),
				"handled": true,
				"surface_id": clean_surface,
				"next_surface_id": clean_surface,
				"action_id": clean_action,
				"mode": "dynamic_restaurant_order",
				"action_result": order_report.duplicate(true)
			}

		"luxury_items":
			if parts.size() < 2:
				return {}
			var shop_id: String = str(parts [1]).strip_edges()
			sync_surface_state(clean_surface, {
				"shop_id": shop_id,
				"item_id": "",
				"notice": ""
			})
			set_active_section(clean_surface, "items")
			return {
				"success": true,
				"handled": true,
				"surface_id": clean_surface,
				"next_surface_id": clean_surface,
				"action_id": clean_action,
				"mode": "dynamic_luxury_items",
				"shop_id": shop_id
			}

		"luxury_overview":
			if parts.size() < 3:
				return {}
			var overview_shop_id: String = str(parts [1]).strip_edges()
			var overview_item_id: String = str(parts [2]).strip_edges()
			sync_surface_state(clean_surface, {
				"shop_id": overview_shop_id,
				"item_id": overview_item_id,
				"notice": ""
			})
			set_active_section(clean_surface, "lore")
			return {
				"success": true,
				"handled": true,
				"surface_id": clean_surface,
				"next_surface_id": clean_surface,
				"action_id": clean_action,
				"mode": "dynamic_luxury_overview",
				"shop_id": overview_shop_id,
				"item_id": overview_item_id
			}

		"luxury_buy":
			if parts.size() < 3:
				return {}
			if gs == null or gs.player == null or gs.luxury_shop_engine == null:
				return {
					"success": false,
					"handled": true,
					"surface_id": clean_surface,
					"next_surface_id": clean_surface,
					"action_id": clean_action,
					"reason": "Luxury shop runtime is unavailable."
				}

			var buy_shop_id: String = str(parts [1]).strip_edges()
			var buy_item_id: String = str(parts [2]).strip_edges()
			var buy_report: Dictionary = gs.luxury_shop_engine.buy_luxury_item(gs.player, buy_shop_id, buy_item_id, {
				"source": "embedded_ui_contract_engine"
			})

			sync_surface_state(clean_surface, {
				"shop_id": buy_shop_id,
				"item_id": buy_item_id,
				"notice": str(buy_report.get("text", buy_report.get("reason", "Luxury purchase resolved."))),
				"last_action_report": buy_report.duplicate(true)
			})
			set_active_section(clean_surface, "items")

			return {
				"success": bool(buy_report.get("success", false)),
				"handled": true,
				"surface_id": clean_surface,
				"next_surface_id": clean_surface,
				"action_id": clean_action,
				"mode": "dynamic_luxury_buy",
				"action_result": buy_report.duplicate(true)
			}

		"luxury_back":
			var target_section: String = "shops"
			if parts.size() >= 2:
				target_section = str(parts [1]).strip_edges()
			if target_section == "shops":
				sync_surface_state(clean_surface, {
					"shop_id": "",
					"item_id": "",
					"notice": ""
				})
			set_active_section(clean_surface, target_section)
			return {
				"success": true,
				"handled": true,
				"surface_id": clean_surface,
				"next_surface_id": clean_surface,
				"action_id": clean_action,
				"mode": "dynamic_luxury_back",
				"target_section": target_section
			}

		_:
			return {}
func _route_movie_theater_dynamic_action(surface_id: String, action_id: String, payload: Dictionary = {}, _context: Dictionary = {}) -> Dictionary:
	var clean_surface: String = str(surface_id).strip_edges()
	var clean_action: String = str(action_id).strip_edges()
	if clean_surface != "movie_theater_contract_hub":
		return {}
	if clean_action == "":
		return {}

	var parts:= clean_action.split(":")
	if parts.size() <= 0:
		return {}

	var verb: String = str(parts [0]).strip_edges().to_lower()
	if not verb.begins_with("movie"):
		return {}

	if gs == null or gs.player == null or gs.movie_theater_engine == null:
		return {
			"success": false,
			"handled": true,
			"surface_id": clean_surface,
			"next_surface_id": clean_surface,
			"action_id": clean_action,
			"reason": "Movie theater runtime is unavailable."
		}

	var movie_report: Dictionary = gs.movie_theater_engine.resolve_movie_action(gs.player, clean_action, payload)
	var target_section: String = str(movie_report.get("target_section", movie_report.get("active_section_id", ""))).strip_edges()
	if target_section == "":
		target_section = "theaters"

	var state_patch: Dictionary = {}
	if typeof(movie_report.get("state_patch", {})) == TYPE_DICTIONARY:
		state_patch = (movie_report.get("state_patch", {}) as Dictionary).duplicate(true)

	state_patch ["notice"] = str(movie_report.get("text", movie_report.get("reason", "Movie theater action resolved.")))
	state_patch ["last_action_report"] = movie_report.duplicate(true)
	state_patch ["active_section_id"] = target_section

	sync_surface_state(clean_surface, state_patch)
	set_active_section(clean_surface, target_section)

	var out: Dictionary = movie_report.duplicate(true)
	out ["handled"] = true
	out ["surface_id"] = clean_surface
	out ["next_surface_id"] = clean_surface
	out ["action_id"] = clean_action
	out ["mode"] = str(movie_report.get("mode", "dynamic_movie_theater_action"))
	out ["target_section"] = target_section
	out ["active_section_id"] = target_section

	return out
func _route_food_lifestyle_dynamic_action(surface_id: String, action_id: String, payload: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	var clean_surface: String = str(surface_id).strip_edges()
	var clean_action: String = str(action_id).strip_edges()
	if clean_surface == "" or clean_action == "":
		return {}

	var parts:= clean_action.split(":")
	if parts.size() <= 0:
		return {}

	var verb: String = str(parts [0]).strip_edges().to_lower()

	match verb:
		"grocery_goldleaf_membership":
			if gs == null or gs.player == null or gs.grocery_store_engine == null:
				return { "success": false, "handled": true, "surface_id": clean_surface, "next_surface_id": clean_surface, "reason": "Grocery runtime is unavailable."}

			var membership_action: String = "buy"
			if parts.size() >= 2:
				membership_action = str(parts [1]).strip_edges().to_lower()

			var membership_report: Dictionary = {}
			match membership_action:
				"buy":
					membership_report = gs.grocery_store_engine.buy_goldleaf_premium_membership(gs.player, {
						"source": "ui_contract_engine",
						"context": context.duplicate(true)
					})
				"cancel":
					membership_report = gs.grocery_store_engine.cancel_goldleaf_premium_membership(gs.player, {
						"source": "ui_contract_engine",
						"context": context.duplicate(true)
					})
				"status":
					membership_report = {
						"success": true,
						"actor_id": int(gs.player.id),
						"show_popup": true,
						"popup_title": "Goldleaf Premium",
						"popup_text": "I am a Goldleaf Premium Member.\n\n50% off every product.\nNo tax while active.",
						"popup_footer": "Tap anywhere to continue.",
						"text": "I am a Goldleaf Premium Member."
					}
				_:
					membership_report = { "success": false, "reason": "Unknown Goldleaf membership action."}

			sync_surface_state(clean_surface, {
				"notice": str(membership_report.get("text", membership_report.get("reason", "Goldleaf membership resolved."))),
				"last_action_report": membership_report.duplicate(true),
				"active_section_id": "stores"
			})
			set_active_section(clean_surface, "stores")
			return {
				"success": bool(membership_report.get("success", false)),
				"handled": true,
				"surface_id": clean_surface,
				"next_surface_id": clean_surface,
				"action_id": clean_action,
				"mode": "dynamic_grocery_goldleaf_membership",
				"target_section": "stores",
				"active_section_id": "stores",
				"show_popup": bool(membership_report.get("show_popup", false)),
				"action_result": membership_report.duplicate(true)
			}
		"grocery_store":
			if parts.size() < 2:
				return {}

			var store_id: String = str(parts [1]).strip_edges()
			var first_aisle_id: String = ""

			if gs != null and gs.grocery_store_engine != null and gs.grocery_store_engine.has_method("first_aisle_id_for_store"):
				first_aisle_id = str(gs.grocery_store_engine.first_aisle_id_for_store(store_id)).strip_edges()

			if gs != null and gs.grocery_store_engine != null and gs.grocery_store_engine.has_method("start_grocery_store_realtime_session"):
				gs.grocery_store_engine.start_grocery_store_realtime_session(store_id, first_aisle_id, {
					"source": "ui_contract_engine_grocery_store_enter",
					"context": context.duplicate(true),
				})

			sync_surface_state(clean_surface, {
				"store_id": store_id,
				"aisle_id": first_aisle_id,
				"grocery_inside_store": true,
				"grocery_cart_unlocked": false,
				"grocery_ready_for_cashier": false,
				"grocery_self_checkout_active": false,
				"self_checkout_state": "",
				"self_checkout_machine_id": "",
				"self_checkout_exit_ready": false,
				"grocery_manual_leave_committed": false,
				"grocery_manual_leave_reason": "",
				"grocery_manual_leave_store_id": "",
				"grocery_manual_leave_at_ms": 0,
				"active_cashier": {},
				"last_action_report": {},
				"notice": "You entered the store. Browse aisles in real time, add items, then press Done Browsing."
			})

			set_active_section(clean_surface, "aisles")

			return {
				"success": true,
				"handled": true,
				"surface_id": clean_surface,
				"next_surface_id": clean_surface,
				"action_id": clean_action,
				"mode": "dynamic_grocery_store",
				"target_section": "aisles",
				"active_section_id": "aisles",
				"store_id": store_id,
				"aisle_id": first_aisle_id
			}
		"grocery_aisle":
			if parts.size() < 3:
				return {}

			var aisle_store_id: String = str(parts [1]).strip_edges()
			var aisle_id: String = str(parts [2]).strip_edges()
			var previous_surface_state: Dictionary = surface_runtime_state.get(clean_surface, {}) if typeof(surface_runtime_state.get(clean_surface, {})) == TYPE_DICTIONARY else {}
			var previous_aisle_id: String = str(previous_surface_state.get("aisle_id", "")).strip_edges()
			var aisle_slide_direction: int = 0

			if gs != null and gs.grocery_store_engine != null and gs.grocery_store_engine.has_method("aisle_slide_direction_for_store"):
				aisle_slide_direction = int(gs.grocery_store_engine.aisle_slide_direction_for_store(aisle_store_id, previous_aisle_id, aisle_id))

			if aisle_slide_direction == 0 and previous_aisle_id != "" and previous_aisle_id != aisle_id:
				aisle_slide_direction = 1

			sync_surface_state(clean_surface, {
				"store_id": aisle_store_id,
				"aisle_id": aisle_id,
				"previous_aisle_id": previous_aisle_id,
				"last_aisle_slide_direction": aisle_slide_direction,
				"grocery_inside_store": true,
				"notice": "You moved into the %s aisle." % aisle_id.replace("_", " ").capitalize()
			})
			set_active_section(clean_surface, "aisles")

			return {
				"success": true,
				"handled": true,
				"surface_id": clean_surface,
				"next_surface_id": clean_surface,
				"action_id": clean_action,
				"mode": "dynamic_grocery_aisle",
				"target_section": "aisles",
				"store_id": aisle_store_id,
				"previous_aisle_id": previous_aisle_id,
				"aisle_id": aisle_id,
				"aisle_slide_direction": aisle_slide_direction
			}
		"grocery_add":
			if parts.size() < 3:
				return {}
			if gs == null or gs.player == null or gs.grocery_store_engine == null:
				return { "success": false, "handled": true, "surface_id": clean_surface, "next_surface_id": clean_surface, "reason": "Grocery runtime is unavailable."}

			var add_store_id: String = str(parts [1]).strip_edges()
			var add_food_id: String = str(parts [2]).strip_edges()
			var add_report: Dictionary = gs.grocery_store_engine.add_to_cart(gs.player, add_store_id, add_food_id, 1, {
				"source": "ui_contract_engine",
				"payload": payload.duplicate(true),
				"context": context.duplicate(true)
			})
			var add_aisle_id: String = ""
			if add_report.has("aisle_id"):
				add_aisle_id = str(add_report.get("aisle_id", "")).strip_edges()

			sync_surface_state(clean_surface, {
				"store_id": add_store_id,
				"aisle_id": add_aisle_id,
				"grocery_cart_unlocked": true,
				"grocery_ready_for_cashier": false,
				"notice": str(add_report.get("text", add_report.get("reason", "Cart updated."))),
				"last_action_report": add_report.duplicate(true)
			})
			set_active_section(clean_surface, "aisles")
			return {
				"success": bool(add_report.get("success", false)),
				"handled": true,
				"surface_id": clean_surface,
				"next_surface_id": clean_surface,
				"action_id": clean_action,
				"mode": "dynamic_grocery_add",
				"target_section": "aisles",
				"active_section_id": "aisles",
				"action_result": add_report.duplicate(true)
			}
		"grocery_done_browsing":
			if gs == null or gs.player == null or gs.grocery_store_engine == null:
				return { "success": false, "handled": true, "surface_id": clean_surface, "next_surface_id": clean_surface, "reason": "Grocery runtime is unavailable."}

			var has_items: bool = false
			if gs.grocery_store_engine.has_method("actor_cart_has_items"):
				has_items = bool(gs.grocery_store_engine.actor_cart_has_items(gs.player))

			var done_target: String = "cart" if has_items else "aisles"
			sync_surface_state(clean_surface, {
				"grocery_cart_unlocked": has_items,
				"grocery_ready_for_cashier": false,
				"active_section_id": done_target,
				"notice": "You finished browsing. Review the cart before checking out." if has_items else "Your cart is empty. Add something from the aisles first."
			})
			set_active_section(clean_surface, done_target)
			return {
				"success": has_items,
				"handled": true,
				"surface_id": clean_surface,
				"next_surface_id": clean_surface,
				"action_id": clean_action,
				"mode": "dynamic_grocery_done_browsing",
				"target_section": done_target,
				"active_section_id": done_target
			}
		"grocery_cart":
			set_active_section(clean_surface, "cart")
			return { "success": true, "handled": true, "surface_id": clean_surface, "next_surface_id": clean_surface, "action_id": clean_action, "mode": "dynamic_grocery_cart"}

		"grocery_cashier":
			var cashier_surface_state: Dictionary = surface_runtime_state.get(clean_surface, {}) if typeof(surface_runtime_state.get(clean_surface, {})) == TYPE_DICTIONARY else {}
			var cashier_store_id: String = str(cashier_surface_state.get("store_id", "")).strip_edges()
			var assigned_cashier: Dictionary = {}

			if gs != null and gs.grocery_store_engine != null and gs.grocery_store_engine.has_method("assign_next_checkout_cashier"):
				assigned_cashier = gs.grocery_store_engine.assign_next_checkout_cashier(cashier_store_id, {
					"source": "ui_contract_engine",
					"surface_state": cashier_surface_state.duplicate(true),
					"context": context.duplicate(true)
				})

			sync_surface_state(clean_surface, {
				"grocery_cart_unlocked": true,
				"grocery_ready_for_cashier": true,
				"active_section_id": "cashier",
				"active_cashier": assigned_cashier.duplicate(true),
				"notice": "You step into %s's checkout lane with your cart." % str(assigned_cashier.get("name", "the cashier"))
			})
			set_active_section(clean_surface, "cashier")
			return {
				"success": true,
				"handled": true,
				"surface_id": clean_surface,
				"next_surface_id": clean_surface,
				"action_id": clean_action,
				"mode": "dynamic_grocery_cashier",
				"target_section": "cashier",
				"active_section_id": "cashier",
				"active_cashier": assigned_cashier.duplicate(true)
			}
		"grocery_self_checkout":
			if gs == null or gs.player == null or gs.grocery_store_engine == null:
				return { "success": false, "handled": true, "surface_id": clean_surface, "next_surface_id": clean_surface, "reason": "Grocery runtime is unavailable."}

			var self_checkout_surface_state: Dictionary = surface_runtime_state.get(clean_surface, {}) if typeof(surface_runtime_state.get(clean_surface, {})) == TYPE_DICTIONARY else {}
			var self_checkout_store_id: String = str(self_checkout_surface_state.get("store_id", "")).strip_edges()
			var self_checkout_report: Dictionary = gs.grocery_store_engine.begin_self_checkout_lane(gs.player, self_checkout_store_id, {
				"source": "ui_contract_engine",
				"surface_state": self_checkout_surface_state.duplicate(true),
				"context": context.duplicate(true)
			})

			sync_surface_state(clean_surface, {
				"store_id": str(self_checkout_report.get("store_id", self_checkout_store_id)),
				"grocery_cart_unlocked": true,
				"grocery_ready_for_cashier": false,
				"grocery_self_checkout_active": true,
				"self_checkout_state": str(self_checkout_report.get("self_checkout_state", "")),
				"self_checkout_queue_position": int(self_checkout_report.get("queue_position", 0)),
				"active_section_id": "self_checkout",
				"notice": str(self_checkout_report.get("text", self_checkout_report.get("reason", "Self-checkout lane opened."))),
				"last_action_report": self_checkout_report.duplicate(true)
			})
			set_active_section(clean_surface, "self_checkout")

			return {
				"success": bool(self_checkout_report.get("success", false)),
				"handled": true,
				"surface_id": clean_surface,
				"next_surface_id": clean_surface,
				"action_id": clean_action,
				"mode": "dynamic_grocery_self_checkout",
				"target_section": "self_checkout",
				"active_section_id": "self_checkout",
				"action_result": self_checkout_report.duplicate(true)
			}

		"grocery_self_checkout_wait":
			if gs == null or gs.player == null or gs.grocery_store_engine == null:
				return { "success": false, "handled": true, "surface_id": clean_surface, "next_surface_id": clean_surface, "reason": "Grocery runtime is unavailable."}

			var self_wait_state: Dictionary = surface_runtime_state.get(clean_surface, {}) if typeof(surface_runtime_state.get(clean_surface, {})) == TYPE_DICTIONARY else {}
			var wait_report: Dictionary = gs.grocery_store_engine.advance_self_checkout_lane(gs.player, {
				"source": "ui_contract_engine",
				"store_id": str(self_wait_state.get("store_id", "")),
				"surface_state": self_wait_state.duplicate(true),
				"context": context.duplicate(true)
			})

			sync_surface_state(clean_surface, {
				"store_id": str(wait_report.get("store_id", self_wait_state.get("store_id", ""))),
				"grocery_self_checkout_active": true,
				"self_checkout_state": str(wait_report.get("self_checkout_state", "")),
				"self_checkout_queue_position": int(wait_report.get("queue_position", 0)),
				"active_section_id": "self_checkout",
				"notice": str(wait_report.get("text", wait_report.get("reason", "Self-checkout line advanced."))),
				"last_action_report": wait_report.duplicate(true)
			})
			set_active_section(clean_surface, "self_checkout")

			return {
				"success": bool(wait_report.get("success", false)),
				"handled": true,
				"surface_id": clean_surface,
				"next_surface_id": clean_surface,
				"action_id": clean_action,
				"mode": "dynamic_grocery_self_checkout_wait",
				"target_section": "self_checkout",
				"active_section_id": "self_checkout",
				"action_result": wait_report.duplicate(true)
			}

		"grocery_self_checkout_machine":
			if gs == null or gs.player == null or gs.grocery_store_engine == null:
				return { "success": false, "handled": true, "surface_id": clean_surface, "next_surface_id": clean_surface, "reason": "Grocery runtime is unavailable."}
			if parts.size() < 2:
				return { "success": false, "handled": true, "surface_id": clean_surface, "next_surface_id": clean_surface, "reason": "No self-checkout machine selected."}

			var selected_machine_id: String = str(parts [1]).strip_edges()
			var machine_report: Dictionary = gs.grocery_store_engine.select_self_checkout_machine(gs.player, selected_machine_id, {
				"source": "ui_contract_engine",
				"context": context.duplicate(true)
			})

			sync_surface_state(clean_surface, {
				"store_id": str(machine_report.get("store_id", "")),
				"grocery_self_checkout_active": true,
				"self_checkout_state": str(machine_report.get("self_checkout_state", "")),
				"self_checkout_machine_id": str(machine_report.get("assigned_machine_id", selected_machine_id)),
				"active_section_id": "self_checkout",
				"notice": str(machine_report.get("text", machine_report.get("reason", "Self-checkout machine selected."))),
				"last_action_report": machine_report.duplicate(true)
			})
			set_active_section(clean_surface, "self_checkout")

			return {
				"success": bool(machine_report.get("success", false)),
				"handled": true,
				"surface_id": clean_surface,
				"next_surface_id": clean_surface,
				"action_id": clean_action,
				"mode": "dynamic_grocery_self_checkout_machine",
				"target_section": "self_checkout",
				"active_section_id": "self_checkout",
				"action_result": machine_report.duplicate(true)
			}

		"grocery_self_checkout_pay":
			if gs == null or gs.player == null or gs.grocery_store_engine == null:
				return { "success": false, "handled": true, "surface_id": clean_surface, "next_surface_id": clean_surface, "reason": "Grocery runtime is unavailable."}

			var self_payment_type: String = "card"
			if parts.size() >= 2:
				self_payment_type = str(parts [1]).strip_edges().to_lower()
			if self_payment_type == "":
				self_payment_type = "card"

			var pay_report: Dictionary = gs.grocery_store_engine.pay_self_checkout_machine(gs.player, self_payment_type, {
				"source": "ui_contract_engine",
				"context": context.duplicate(true)
			})

			sync_surface_state(clean_surface, {
				"store_id": str(pay_report.get("store_id", "")),
				"grocery_cart_unlocked": false,
				"grocery_ready_for_cashier": false,
				"grocery_self_checkout_active": true,
				"self_checkout_state": str(pay_report.get("self_checkout_state", "")),
				"self_checkout_machine_id": str(pay_report.get("assigned_machine_id", "")),
				"self_checkout_exit_ready": true,
				"active_section_id": "self_checkout",
				"notice": str(pay_report.get("text", pay_report.get("reason", "Self-checkout payment resolved."))),
				"last_action_report": pay_report.duplicate(true)
			})
			set_active_section(clean_surface, "self_checkout")

			return {
				"success": bool(pay_report.get("success", false)),
				"handled": true,
				"surface_id": clean_surface,
				"next_surface_id": clean_surface,
				"action_id": clean_action,
				"mode": "dynamic_grocery_self_checkout_pay",
				"target_section": "self_checkout",
				"active_section_id": "self_checkout",
				"show_popup": bool(pay_report.get("show_popup", false)),
				"action_result": pay_report.duplicate(true)
			}

		"grocery_self_checkout_exit":
			if gs == null or gs.player == null or gs.grocery_store_engine == null:
				return { "success": false, "handled": true, "surface_id": clean_surface, "next_surface_id": clean_surface, "reason": "Grocery runtime is unavailable."}

			var exit_report: Dictionary = gs.grocery_store_engine.finish_self_checkout_exit(gs.player, {
				"source": "ui_contract_engine",
				"context": context.duplicate(true)
			})

			sync_surface_state(clean_surface, {
				"store_id": "",
				"aisle_id": "",
				"grocery_inside_store": false,
				"grocery_cart_unlocked": false,
				"grocery_ready_for_cashier": false,
				"grocery_self_checkout_active": false,
				"self_checkout_state": "",
				"self_checkout_machine_id": "",
				"self_checkout_exit_ready": false,
				"active_section_id": "stores",
				"notice": str(exit_report.get("text", "I exited the store.")),
				"last_action_report": exit_report.duplicate(true)
			})
			set_active_section(clean_surface, "stores")

			return {
				"success": bool(exit_report.get("success", false)),
				"handled": true,
				"surface_id": clean_surface,
				"next_surface_id": clean_surface,
				"action_id": clean_action,
				"mode": "dynamic_grocery_self_checkout_exit",
				"target_section": "stores",
				"active_section_id": "stores",
				"action_result": exit_report.duplicate(true)
			}
		"grocery_checkout":
			if gs == null or gs.player == null or gs.grocery_store_engine == null:
				return { "success": false, "handled": true, "surface_id": clean_surface, "next_surface_id": clean_surface, "reason": "Grocery runtime is unavailable."}

			var checkout_report: Dictionary = {}
			if gs.grocery_store_engine.has_method("checkout_cart_for_ui"):
				checkout_report = gs.grocery_store_engine.checkout_cart_for_ui(gs.player, {
					"source": "ui_contract_engine",
					"checkout_lane": "cashier",
					"context": context.duplicate(true)
				})
			else:
				checkout_report = gs.grocery_store_engine.checkout_cart(gs.player, {
					"source": "ui_contract_engine",
					"context": context.duplicate(true)
				})

			sync_surface_state(clean_surface, {
				"grocery_cart_unlocked": false,
				"grocery_ready_for_cashier": false,
				"grocery_inside_store": false,
				"store_id": "",
				"aisle_id": "",
				"active_section_id": "stores",
				"notice": str(checkout_report.get("text", checkout_report.get("reason", "Checkout resolved."))),
				"last_action_report": checkout_report.duplicate(true)
			})
			set_active_section(clean_surface, "stores")
			return {
				"success": bool(checkout_report.get("success", false)),
				"handled": true,
				"surface_id": clean_surface,
				"next_surface_id": clean_surface,
				"action_id": clean_action,
				"mode": "dynamic_grocery_checkout",
				"target_section": "stores",
				"active_section_id": "stores",
				"action_result": checkout_report.duplicate(true)
			}
		"grocery_shoplift":
			if gs == null or gs.player == null or gs.grocery_store_engine == null:
				return { "success": false, "handled": true, "surface_id": clean_surface, "next_surface_id": clean_surface, "reason": "Grocery runtime is unavailable."}

			var shoplift_report: Dictionary = gs.grocery_store_engine.shoplift_cart(gs.player, {
				"source": "ui_contract_engine",
				"context": context.duplicate(true)
			})
			sync_surface_state(clean_surface, {
				"notice": str(shoplift_report.get("text", shoplift_report.get("reason", "Shoplifting resolved."))),
				"last_action_report": shoplift_report.duplicate(true)
			})
			set_active_section(clean_surface, "cart")
			return {
				"success": bool(shoplift_report.get("success", false)),
				"handled": true,
				"surface_id": clean_surface,
				"next_surface_id": clean_surface,
				"action_id": clean_action,
				"mode": "dynamic_grocery_shoplift",
				"action_result": shoplift_report.duplicate(true)
			}
		"grocery_shoppers_popup":
			if gs == null or gs.grocery_store_engine == null:
				return { "success": false, "handled": true, "surface_id": clean_surface, "next_surface_id": clean_surface, "reason": "Grocery runtime is unavailable."}

			var shopper_store_id: String = ""
			var shopper_aisle_id: String = ""

			if parts.size() >= 2:
				shopper_store_id = str(parts [1]).strip_edges()
			if parts.size() >= 3:
				shopper_aisle_id = str(parts [2]).strip_edges()

			var shopper_rows: Array = []
			if gs.grocery_store_engine.has_method("get_grocery_aisle_shopper_popup_rows"):
				shopper_rows = gs.grocery_store_engine.get_grocery_aisle_shopper_popup_rows(shopper_store_id, shopper_aisle_id, {
					"source": "ui_contract_engine",
					"surface_state": surface_runtime_state.get(clean_surface, {}).duplicate(true) if typeof(surface_runtime_state.get(clean_surface, {})) == TYPE_DICTIONARY else {},
					"context": context.duplicate(true)
				})

			return {
				"success": true,
				"handled": true,
				"surface_id": clean_surface,
				"next_surface_id": clean_surface,
				"action_id": clean_action,
				"mode": "dynamic_grocery_shoppers_popup",
				"target_section": "aisles",
				"active_section_id": "aisles",
				"store_id": shopper_store_id,
				"aisle_id": shopper_aisle_id,
				"shopper_rows": shopper_rows
			}
		"grocery_back":
			var grocery_target: String = "stores"
			if parts.size() >= 2:
				grocery_target = str(parts [1]).strip_edges()
			if grocery_target == "":
				grocery_target = "stores"

			var grocery_patch: Dictionary = {
				"active_section_id": grocery_target
			}

			match grocery_target:
				"stores":
					var leaving_store_id: String = ""
					var leaving_surface_state: Dictionary = surface_runtime_state.get(clean_surface, {}) if typeof(surface_runtime_state.get(clean_surface, {})) == TYPE_DICTIONARY else {}
					leaving_store_id = str(leaving_surface_state.get("store_id", "")).strip_edges()

					if gs != null and gs.player != null and gs.grocery_store_engine != null and gs.grocery_store_engine.has_method("reset_grocery_cart_for_actor"):
						gs.grocery_store_engine.reset_grocery_cart_for_actor(gs.player, leaving_store_id, {
							"reason": "left_store",
							"source": "ui_contract_engine_grocery_back_to_stores"
						})

					grocery_patch ["store_id"] = ""
					grocery_patch ["aisle_id"] = ""
					grocery_patch ["grocery_inside_store"] = false
					grocery_patch ["grocery_cart_unlocked"] = false
					grocery_patch ["grocery_ready_for_cashier"] = false
					grocery_patch ["grocery_self_checkout_active"] = false
					grocery_patch ["self_checkout_state"] = ""
					grocery_patch ["self_checkout_machine_id"] = ""
					grocery_patch ["self_checkout_exit_ready"] = false
					grocery_patch ["active_cashier"] = {}
					grocery_patch ["last_action_report"] = {}
					grocery_patch ["notice"] = "You left the store."
					grocery_patch ["grocery_manual_leave_committed"] = bool(context.get("manual_surface_close", false))
					grocery_patch ["grocery_manual_leave_reason"] = str(context.get("close_surface_reason", "grocery_back_to_stores"))
					grocery_patch ["grocery_manual_leave_store_id"] = leaving_store_id
					grocery_patch ["grocery_manual_leave_at_ms"] = int(Time.get_ticks_msec())
				"aisles":
					grocery_patch ["grocery_cart_unlocked"] = false
					grocery_patch ["grocery_ready_for_cashier"] = false
					grocery_patch ["notice"] = "You went back to browsing. Cart is locked until you add another item or press Done Browsing again."
				"cart":
					grocery_patch ["grocery_cart_unlocked"] = true
					grocery_patch ["grocery_ready_for_cashier"] = false
					grocery_patch ["notice"] = "You stepped back from the cashier to the cart."
				_:
					grocery_patch ["notice"] = ""

			sync_surface_state(clean_surface, grocery_patch)
			set_active_section(clean_surface, grocery_target)
			return {
				"success": true,
				"handled": true,
				"surface_id": clean_surface,
				"next_surface_id": clean_surface,
				"action_id": clean_action,
				"mode": "dynamic_grocery_back",
				"target_section": grocery_target,
				"active_section_id": grocery_target
			}

		"restaurant_start":
			if gs == null or gs.player == null or gs.food_restaurant_engine == null:
				return { "success": false, "handled": true, "surface_id": clean_surface, "next_surface_id": clean_surface, "reason": "Restaurant runtime is unavailable."}

			var mode: String = "alone"
			if parts.size() >= 2:
				mode = str(parts [1]).strip_edges().to_lower()

			var start_report: Dictionary = gs.food_restaurant_engine.choose_restaurant_mode(gs.player, mode, {
				"source": "ui_contract_engine"
			})

			var start_state: Dictionary = start_report.get("surface_state", {}) if typeof(start_report.get("surface_state", {})) == TYPE_DICTIONARY else {}
			var next_restaurant_section: String = "plan"

			if bool(start_report.get("success", false)):
				if mode == "date" and int(start_state.get("date_partner_id", -1)) <= 0:
					next_restaurant_section = "plan"
					start_state ["restaurant_plan_chosen"] = false
				else:
					next_restaurant_section = "restaurant"
					start_state ["restaurant_plan_chosen"] = true
			else:
				next_restaurant_section = "plan"
				start_state ["restaurant_plan_chosen"] = false

			sync_surface_state(clean_surface, start_state)
			set_active_section(clean_surface, next_restaurant_section)

			return {
				"success": bool(start_report.get("success", false)),
				"handled": true,
				"surface_id": clean_surface,
				"next_surface_id": clean_surface,
				"action_id": clean_action,
				"mode": "dynamic_restaurant_start",
				"target_section": next_restaurant_section,
				"action_result": start_report.duplicate(true)
			}
		"restaurant_candidate":
			if gs == null or gs.player == null or gs.food_restaurant_engine == null:
				return { "success": false, "handled": true, "surface_id": clean_surface, "next_surface_id": clean_surface, "reason": "Restaurant runtime is unavailable."}

			var candidate_action: String = "next"
			if parts.size() >= 2:
				candidate_action = str(parts [1]).strip_edges().to_lower()

			var candidate_report: Dictionary = {}
			if candidate_action == "ask":
				candidate_report = gs.food_restaurant_engine.ask_current_date_candidate_out(gs.player, {
					"source": "ui_contract_engine"
				})
			else:
				candidate_report = gs.food_restaurant_engine.find_next_date_candidate(gs.player, {
					"source": "ui_contract_engine"
				})

			var candidate_state: Dictionary = candidate_report.get("surface_state", {}) if typeof(candidate_report.get("surface_state", {})) == TYPE_DICTIONARY else {}
			var candidate_next_section: String = "restaurant" if bool(candidate_report.get("accepted", false)) else "plan"
			candidate_state ["restaurant_plan_chosen"] = bool(candidate_report.get("accepted", false))

			sync_surface_state(clean_surface, candidate_state)
			set_active_section(clean_surface, candidate_next_section)

			return {
				"success": bool(candidate_report.get("success", false)),
				"handled": true,
				"surface_id": clean_surface,
				"next_surface_id": clean_surface,
				"action_id": clean_action,
				"mode": "dynamic_restaurant_candidate",
				"target_section": candidate_next_section,
				"action_result": candidate_report.duplicate(true)
			}

		"restaurant_category":
			if parts.size() < 2:
				return {}

			var category_id: String = str(parts [1]).strip_edges().to_lower()
			sync_surface_state(clean_surface, {
				"restaurant_category": category_id,
				"restaurant_id": "",
				"restaurant_service_mode": "",
				"active_section_id": "restaurant",
				"notice": "Choose a %s restaurant." % category_id.replace("_", " ")
			})
			set_active_section(clean_surface, "restaurant")
			return {
				"success": true,
				"handled": true,
				"surface_id": clean_surface,
				"next_surface_id": clean_surface,
				"action_id": clean_action,
				"mode": "dynamic_restaurant_category",
				"target_section": "restaurant",
				"active_section_id": "restaurant",
				"restaurant_category": category_id
			}
		"restaurant_select":

			if parts.size() < 2:
				return {}
			var selected_restaurant_id: String = str(parts [1]).strip_edges()
			var selected_restaurant_name: String = _food_lifestyle_restaurant_name(selected_restaurant_id)
			sync_surface_state(clean_surface, {
				"restaurant_id": selected_restaurant_id,
				"restaurant_service_mode": "",
				"menu_preview_only": false,
				"active_section_id": "restaurant",
				"notice": "%s selected. Choose dine-in, takeout, drive-thru if available, or preview the menu without going." % selected_restaurant_name if selected_restaurant_name != "" else "Restaurant selected. Choose dine-in, takeout, or drive-thru if available."
			})
			set_active_section(clean_surface, "restaurant")
			return {
				"success": true,
				"handled": true,
				"surface_id": clean_surface,
				"next_surface_id": clean_surface,
				"action_id": clean_action,
				"mode": "dynamic_restaurant_select",
				"target_section": "restaurant",
				"active_section_id": "restaurant",
				"restaurant_id": selected_restaurant_id
			}
		"restaurant_preview_menu":
			if parts.size() < 2:
				return {}
			var preview_restaurant_id: String = str(parts [1]).strip_edges()
			var preview_restaurant_name: String = _food_lifestyle_restaurant_name(preview_restaurant_id)
			sync_surface_state(clean_surface, {
				"restaurant_id": preview_restaurant_id,
				"restaurant_service_mode": "",
				"menu_preview_only": true,
				"restaurant_order_unlocked": false,
				"active_section_id": "menu",
				"notice": "Viewing %s’s menu without starting service." % preview_restaurant_name if preview_restaurant_name != "" else "Viewing this menu without starting service."
			})
			set_active_section(clean_surface, "menu")
			return {
				"success": true,
				"handled": true,
				"surface_id": clean_surface,
				"next_surface_id": clean_surface,
				"action_id": clean_action,
				"mode": "dynamic_restaurant_preview_menu",
				"target_section": "menu",
				"active_section_id": "menu",
				"restaurant_id": preview_restaurant_id
			}
		"restaurant_menu":
			if parts.size() < 2:
				return {}
			var menu_restaurant_id: String = str(parts [1]).strip_edges()
			var menu_service_mode: String = "takeout"
			if parts.size() >= 3:
				menu_service_mode = str(parts [2]).strip_edges().to_lower()
			if menu_service_mode == "":
				menu_service_mode = "takeout"
			var begin_order_report: Dictionary = {}
			if gs != null and gs.player != null and gs.food_restaurant_engine != null and gs.food_restaurant_engine.has_method("begin_restaurant_order_context"):
				begin_order_report = gs.food_restaurant_engine.begin_restaurant_order_context(gs.player, menu_restaurant_id, menu_service_mode, {
					"source": "ui_contract_engine",
					"surface_id": clean_surface
				})
			sync_surface_state(clean_surface, {
				"restaurant_id": menu_restaurant_id,
				"restaurant_service_mode": menu_service_mode,
				"menu_preview_only": false,
				"active_section_id": "menu",
				"notice": "Service set to %s. Build the order from the menu." % menu_service_mode.replace("_", " "),
				"last_action_report": begin_order_report.duplicate(true)
			})
			set_active_section(clean_surface, "menu")
			return {
				"success": true,
				"handled": true,
				"surface_id": clean_surface,
				"next_surface_id": clean_surface,
				"action_id": clean_action,
				"mode": "dynamic_restaurant_menu",
				"target_section": "menu",
				"active_section_id": "menu",
				"restaurant_id": menu_restaurant_id,
				"restaurant_service_mode": menu_service_mode,
				"action_result": begin_order_report.duplicate(true)
			}

		"restaurant_service":
			if parts.size() < 2:
				return {}
			var selected_service_mode: String = str(parts [1]).strip_edges().to_lower()
			if selected_service_mode == "":
				selected_service_mode = "takeout"
			sync_surface_state(clean_surface, {
				"restaurant_service_mode": selected_service_mode,
				"notice": "Service set to %s. Now build the order." % selected_service_mode.replace("_", " ")
			})
			set_active_section(clean_surface, "menu")
			return {
				"success": true,
				"handled": true,
				"surface_id": clean_surface,
				"next_surface_id": clean_surface,
				"action_id": clean_action,
				"mode": "dynamic_restaurant_service",
				"restaurant_service_mode": selected_service_mode
			}
		"restaurant_add":
			if parts.size() < 3:
				return {}
			if gs == null or gs.player == null or gs.food_restaurant_engine == null:
				return { "success": false, "handled": true, "surface_id": clean_surface, "next_surface_id": clean_surface, "reason": "Restaurant runtime is unavailable."}

			var add_restaurant_id: String = str(parts [1]).strip_edges()
			var add_food_id: String = str(parts [2]).strip_edges()
			var restaurant_add_report: Dictionary = gs.food_restaurant_engine.add_to_cart(gs.player, add_restaurant_id, add_food_id, 1, {
				"source": "ui_contract_engine",
				"payload": payload.duplicate(true),
				"context": context.duplicate(true)
			})
			sync_surface_state(clean_surface, {
				"restaurant_id": add_restaurant_id,
				"restaurant_order_unlocked": true,
				"notice": str(restaurant_add_report.get("text", restaurant_add_report.get("reason", "Order updated."))),
				"last_action_report": restaurant_add_report.duplicate(true)
			})
			set_active_section(clean_surface, "menu")
			return {
				"success": bool(restaurant_add_report.get("success", false)),
				"handled": true,
				"surface_id": clean_surface,
				"next_surface_id": clean_surface,
				"action_id": clean_action,
				"mode": "dynamic_restaurant_add",
				"target_section": "menu",
				"active_section_id": "menu",
				"action_result": restaurant_add_report.duplicate(true)
			}

		"restaurant_partner_pick":
			if gs == null or gs.player == null or gs.food_restaurant_engine == null:
				return { "success": false, "handled": true, "surface_id": clean_surface, "next_surface_id": clean_surface, "reason": "Restaurant runtime is unavailable."}

			var partner_live_state: Dictionary = surface_runtime_state.get(clean_surface, {}) if typeof(surface_runtime_state.get(clean_surface, {})) == TYPE_DICTIONARY else {}
			var partner_pick_report: Dictionary = gs.food_restaurant_engine.partner_pick_menu_item(gs.player, {
				"source": "ui_contract_engine",
				"restaurant_id": str(partner_live_state.get("restaurant_id", "")),
				"restaurant_service_mode": str(partner_live_state.get("restaurant_service_mode", ""))
			})
			sync_surface_state(clean_surface, {
				"restaurant_id": str(partner_live_state.get("restaurant_id", "")),
				"restaurant_service_mode": str(partner_live_state.get("restaurant_service_mode", "")),
				"restaurant_order_unlocked": bool(partner_pick_report.get("success", false)),
				"notice": str(partner_pick_report.get("text", partner_pick_report.get("reason", "They picked something."))),
				"last_action_report": partner_pick_report.duplicate(true)
			})
			set_active_section(clean_surface, "menu")
			return {
				"success": bool(partner_pick_report.get("success", false)),
				"handled": true,
				"surface_id": clean_surface,
				"next_surface_id": clean_surface,
				"action_id": clean_action,
				"mode": "dynamic_restaurant_partner_pick",
				"target_section": "menu",
				"active_section_id": "menu",
				"action_result": partner_pick_report.duplicate(true)
			}

		"restaurant_cart":
			sync_surface_state(clean_surface, {
				"restaurant_order_unlocked": true,
				"active_section_id": "cart"
			})
			set_active_section(clean_surface, "cart")
			return {
				"success": true,
				"handled": true,
				"surface_id": clean_surface,
				"next_surface_id": clean_surface,
				"action_id": clean_action,
				"mode": "dynamic_restaurant_cart",
				"target_section": "cart",
				"active_section_id": "cart"
			}

		"restaurant_checkout":
			if gs == null or gs.player == null or gs.food_restaurant_engine == null:
				return { "success": false, "handled": true, "surface_id": clean_surface, "next_surface_id": clean_surface, "reason": "Restaurant runtime is unavailable."}

			var service_mode: String = "selected"
			if parts.size() >= 2:
				service_mode = str(parts [1]).strip_edges().to_lower()

			var live_surface_state: Dictionary = surface_runtime_state.get(clean_surface, {}) if typeof(surface_runtime_state.get(clean_surface, {})) == TYPE_DICTIONARY else {}
			if service_mode == "" or service_mode == "selected":
				service_mode = str(live_surface_state.get("restaurant_service_mode", "takeout")).strip_edges().to_lower()
				if service_mode == "":
					service_mode = "takeout"

			var checkout_restaurant_report: Dictionary = gs.food_restaurant_engine.checkout_cart(gs.player, service_mode, {
				"source": "ui_contract_engine",
				"surface_state": live_surface_state.duplicate(true),
				"context": context.duplicate(true)
			})

			var started_date_turn: bool = bool(checkout_restaurant_report.get("started_date_turn", false))
			var checkout_target: String = "cart" if started_date_turn else "restaurant"

			sync_surface_state(clean_surface, {
				"restaurant_service_mode": service_mode,
				"restaurant_order_unlocked": started_date_turn,
				"active_section_id": checkout_target,
				"notice": str(checkout_restaurant_report.get("text", checkout_restaurant_report.get("reason", "Restaurant checkout resolved."))),
				"last_action_report": checkout_restaurant_report.duplicate(true)
			})
			set_active_section(clean_surface, checkout_target)

			return {
				"success": bool(checkout_restaurant_report.get("success", false)),
				"handled": true,
				"surface_id": clean_surface,
				"next_surface_id": clean_surface,
				"action_id": clean_action,
				"mode": "dynamic_restaurant_checkout",
				"restaurant_service_mode": service_mode,
				"target_section": checkout_target,
				"active_section_id": checkout_target,
				"show_popup": bool(checkout_restaurant_report.get("show_popup", false)),
				"action_result": checkout_restaurant_report.duplicate(true)
			}
		"restaurant_waiter":
			if gs == null or gs.player == null or gs.food_restaurant_engine == null:
				return { "success": false, "handled": true, "surface_id": clean_surface, "next_surface_id": clean_surface, "reason": "Restaurant runtime is unavailable."}

			var waiter_action: String = "call"
			if parts.size() >= 2:
				waiter_action = str(parts [1]).strip_edges().to_lower()

			var waiter_report: Dictionary = {}
			if gs.food_restaurant_engine.has_method("resolve_waiter_action"):
				waiter_report = gs.food_restaurant_engine.resolve_waiter_action(gs.player, waiter_action, {
					"source": "ui_contract_engine",
					"surface_state": surface_runtime_state.get(clean_surface, {}).duplicate(true) if typeof(surface_runtime_state.get(clean_surface, {})) == TYPE_DICTIONARY else {},
					"context": context.duplicate(true)
				})
			else:
				waiter_report = {
					"success": false,
					"waiter_called": false,
					"bill_requested": false,
					"bill_stage": "",
					"custom_tip": 0.0,
					"target_section": "cart",
					"reason": "Restaurant waiter runtime is unavailable."
				}

			var waiter_target: String = str(waiter_report.get("target_section", "cart")).strip_edges()
			if waiter_target == "":
				waiter_target = "cart"

			sync_surface_state(clean_surface, {
				"restaurant_waiter_called": bool(waiter_report.get("waiter_called", false)),
				"restaurant_bill_requested": bool(waiter_report.get("bill_requested", false)),
				"restaurant_bill_stage": str(waiter_report.get("bill_stage", "")),
				"restaurant_custom_tip": float(waiter_report.get("custom_tip", 0.0)),
				"active_section_id": waiter_target,
				"notice": str(waiter_report.get("text", waiter_report.get("reason", "Waiter action resolved."))),
				"last_action_report": waiter_report.duplicate(true)
			})
			set_active_section(clean_surface, waiter_target)

			return {
				"success": bool(waiter_report.get("success", false)),
				"handled": true,
				"surface_id": clean_surface,
				"next_surface_id": clean_surface,
				"action_id": clean_action,
				"mode": "dynamic_restaurant_waiter",
				"target_section": waiter_target,
				"active_section_id": waiter_target,
				"show_popup": bool(waiter_report.get("show_popup", false)),
				"close_contract_surface": bool(waiter_report.get("close_contract_surface", false)),
				"close_after": bool(waiter_report.get("close_after", false)),
				"action_result": waiter_report.duplicate(true)
			}

		"restaurant_tip":
			if gs == null or gs.player == null or gs.food_restaurant_engine == null:
				return { "success": false, "handled": true, "surface_id": clean_surface, "next_surface_id": clean_surface, "reason": "Restaurant runtime is unavailable."}

			var tip_action: String = "preset"
			if parts.size() >= 2:
				tip_action = str(parts [1]).strip_edges().to_lower()

			var tip_value: String = ""
			if parts.size() >= 3:
				tip_value = str(parts [2]).strip_edges()

			var tip_report: Dictionary = {}
			if gs.food_restaurant_engine.has_method("resolve_tip_action"):
				tip_report = gs.food_restaurant_engine.resolve_tip_action(gs.player, tip_action, tip_value, {
					"source": "ui_contract_engine",
					"surface_state": surface_runtime_state.get(clean_surface, {}).duplicate(true) if typeof(surface_runtime_state.get(clean_surface, {})) == TYPE_DICTIONARY else {},
					"context": context.duplicate(true)
				})
			else:
				tip_report = {
					"success": false,
					"bill_requested": true,
					"bill_stage": "ready_to_pay",
					"custom_tip": 0.0,
					"reason": "Restaurant tip runtime is unavailable."
				}

			var tip_target: String = "cart"
			sync_surface_state(clean_surface, {
				"restaurant_bill_requested": bool(tip_report.get("bill_requested", true)),
				"restaurant_bill_stage": str(tip_report.get("bill_stage", "tip_select")),
				"restaurant_custom_tip": float(tip_report.get("custom_tip", 0.0)),
				"restaurant_order_unlocked": not bool(tip_report.get("date_finished", false)),
				"active_section_id": tip_target,
				"notice": str(tip_report.get("text", tip_report.get("reason", "Tip action resolved."))),
				"last_action_report": tip_report.duplicate(true)
			})

			if not bool(tip_report.get("close_contract_surface", false)):
				set_active_section(clean_surface, tip_target)

			return {
				"success": bool(tip_report.get("success", false)),
				"handled": true,
				"surface_id": clean_surface,
				"next_surface_id": clean_surface,
				"action_id": clean_action,
				"mode": "dynamic_restaurant_tip",
				"target_section": tip_target,
				"active_section_id": tip_target,
				"show_popup": bool(tip_report.get("show_popup", false)),
				"close_contract_surface": bool(tip_report.get("close_contract_surface", false)),
				"close_after": bool(tip_report.get("close_after", false)),
				"action_result": tip_report.duplicate(true)
			}
		"restaurant_date_action":
			if gs == null or gs.player == null or gs.food_restaurant_engine == null:
				return { "success": false, "handled": true, "surface_id": clean_surface, "next_surface_id": clean_surface, "reason": "Restaurant runtime is unavailable."}

			var date_action: String = "chat"
			if parts.size() >= 2:
				date_action = str(parts [1]).strip_edges().to_lower()

			var date_report: Dictionary = gs.food_restaurant_engine.resolve_date_action(gs.player, date_action, {
				"source": "ui_contract_engine"
			})

			var date_finished: bool = bool(date_report.get("date_finished", false))
			var should_close_surface: bool = bool(date_report.get("close_contract_surface", false)) or bool(date_report.get("close_after", false))
			var next_date_section: String = "restaurant" if date_finished else "cart"

			sync_surface_state(clean_surface, {
				"notice": str(date_report.get("text", date_report.get("reason", "Date action resolved."))),
				"last_action_report": date_report.duplicate(true),
				"active_section_id": next_date_section
			})

			if not should_close_surface:
				set_active_section(clean_surface, next_date_section)

			return {
				"success": bool(date_report.get("success", false)),
				"handled": true,
				"surface_id": clean_surface,
				"next_surface_id": clean_surface,
				"action_id": clean_action,
				"mode": "dynamic_restaurant_date_action",
				"target_section": next_date_section,
				"active_section_id": next_date_section,
				"show_popup": bool(date_report.get("show_popup", false)),
				"close_contract_surface": should_close_surface,
				"close_after": should_close_surface,
				"action_result": date_report.duplicate(true)
			}

		"restaurant_pay_entry":
			if gs == null or gs.player == null or gs.food_restaurant_engine == null:
				return { "success": false, "handled": true, "surface_id": clean_surface, "next_surface_id": clean_surface, "reason": "Restaurant runtime is unavailable."}

			var pay_entry_restaurant_id: String = ""
			if parts.size() >= 2:
				pay_entry_restaurant_id = str(parts [1]).strip_edges()

			var entry_report: Dictionary = gs.food_restaurant_engine.pay_restaurant_entry_fee(gs.player, pay_entry_restaurant_id, {
				"source": "ui_contract_engine"
			})
			sync_surface_state(clean_surface, {
				"restaurant_id": pay_entry_restaurant_id,
				"notice": str(entry_report.get("text", entry_report.get("reason", "Entry fee resolved."))),
				"last_action_report": entry_report.duplicate(true)
			})
			set_active_section(clean_surface, "menu")
			return {
				"success": bool(entry_report.get("success", false)),
				"handled": true,
				"surface_id": clean_surface,
				"next_surface_id": clean_surface,
				"action_id": clean_action,
				"mode": "dynamic_restaurant_entry_fee",
				"action_result": entry_report.duplicate(true)
			}
		"restaurant_continue":
			var continue_target: String = "restaurant"
			if parts.size() >= 2:
				continue_target = str(parts [1]).strip_edges()
			if continue_target == "":
				continue_target = "restaurant"

			var live_surface_state: Dictionary = surface_runtime_state.get(clean_surface, {}).duplicate(true) if typeof(surface_runtime_state.get(clean_surface, {})) == TYPE_DICTIONARY else {}
			var live_mode: String = str(live_surface_state.get("restaurant_mode", "")).strip_edges().to_lower()
			var live_partner_id: int = int(live_surface_state.get("date_partner_id", -1))
			var has_plan: bool = bool(live_surface_state.get("restaurant_plan_chosen", false))

			if not has_plan:
				match live_mode:
					"alone", "partner":
						has_plan = true
					"date":
						has_plan = live_partner_id > 0

			if not has_plan and gs != null and gs.player != null and gs.food_restaurant_engine != null and gs.food_restaurant_engine.has_method("actor_has_restaurant_plan"):
				has_plan = bool(gs.food_restaurant_engine.actor_has_restaurant_plan(gs.player))

			var resolved_target: String = continue_target if has_plan else "plan"

			sync_surface_state(clean_surface, {
				"restaurant_plan_chosen": has_plan,
				"active_section_id": resolved_target,
				"notice": "Restaurant plan ready. Choose a place and service style." if has_plan else "Choose who you are going with first."
			})

			set_active_section(clean_surface, resolved_target)

			return {
				"success": has_plan,
				"handled": true,
				"surface_id": clean_surface,
				"next_surface_id": clean_surface,
				"action_id": clean_action,
				"mode": "dynamic_restaurant_continue",
				"target_section": resolved_target,
				"active_section_id": resolved_target,
				"route": {
					"kind": "open_section",
					"target": resolved_target,
					"refresh_after": true
				}
			}
		"restaurant_back":
			var restaurant_target: String = "plan"
			if parts.size() >= 2:
				restaurant_target = str(parts [1]).strip_edges()
			if restaurant_target == "":
				restaurant_target = "plan"

			var restaurant_patch: Dictionary = {
				"active_section_id": restaurant_target
			}

			match restaurant_target:
				"plan":
					if gs != null and gs.food_restaurant_engine != null and gs.player != null:
						gs.food_restaurant_engine.clear_restaurant_session(gs.player)

					restaurant_patch ["restaurant_mode"] = ""
					restaurant_patch ["restaurant_plan_chosen"] = false
					restaurant_patch ["restaurant_category"] = ""
					restaurant_patch ["restaurant_id"] = ""
					restaurant_patch ["restaurant_service_mode"] = ""
					restaurant_patch ["restaurant_order_unlocked"] = false
					restaurant_patch ["candidate_id"] = -1
					restaurant_patch ["candidate_name"] = ""
					restaurant_patch ["date_partner_id"] = -1
					restaurant_patch ["date_partner_name"] = ""
					restaurant_patch ["notice"] = "Restaurant plan cleared."

				"restaurant_type":
					restaurant_target = "restaurant"
					if gs != null and gs.food_restaurant_engine != null and gs.player != null and gs.food_restaurant_engine.has_method("clear_restaurant_order_items"):
						gs.food_restaurant_engine.clear_restaurant_order_items(gs.player)

					restaurant_patch ["active_section_id"] = restaurant_target
					restaurant_patch ["restaurant_category"] = ""
					restaurant_patch ["restaurant_id"] = ""
					restaurant_patch ["restaurant_service_mode"] = ""
					restaurant_patch ["restaurant_order_unlocked"] = false
					restaurant_patch ["notice"] = "Pick a restaurant type."

				"restaurant":
					if gs != null and gs.food_restaurant_engine != null and gs.player != null and gs.food_restaurant_engine.has_method("clear_restaurant_order_items"):
						gs.food_restaurant_engine.clear_restaurant_order_items(gs.player)

					restaurant_patch ["restaurant_id"] = ""
					restaurant_patch ["restaurant_service_mode"] = ""
					restaurant_patch ["restaurant_order_unlocked"] = false
					restaurant_patch ["notice"] = "Choose a restaurant again."

				"menu":
					if gs != null and gs.food_restaurant_engine != null and gs.player != null and gs.food_restaurant_engine.has_method("clear_restaurant_order_items"):
						gs.food_restaurant_engine.clear_restaurant_order_items(gs.player)

					restaurant_patch ["restaurant_order_unlocked"] = false
					restaurant_patch ["notice"] = "Order cleared. Add something from the menu again."

				_:
					restaurant_patch ["notice"] = ""

			sync_surface_state(clean_surface, restaurant_patch)
			set_active_section(clean_surface, restaurant_target)
			return {
				"success": true,
				"handled": true,
				"surface_id": clean_surface,
				"next_surface_id": clean_surface,
				"action_id": clean_action,
				"mode": "dynamic_restaurant_back",
				"target_section": restaurant_target,
				"active_section_id": restaurant_target
			}

	return {}


func sync_surface_state(surface_id: String, patch: Dictionary = {}) -> Dictionary:
	var clean_surface: String = str(surface_id).strip_edges()
	if clean_surface == "":
		return { "success": false, "reason": "Missing surface_id."}

	var state: Dictionary = surface_runtime_state.get(clean_surface, {}).duplicate(true) if typeof(surface_runtime_state.get(clean_surface, {})) == TYPE_DICTIONARY else {}
	for key in patch.keys():
		state [key] = patch [key]
	state ["updated_at_ms"] = int(Time.get_ticks_msec())

	surface_runtime_state [clean_surface] = state

	return {
		"success": true,
		"surface_id": clean_surface,
		"state": state.duplicate(true)
	}

func export_registry() -> Dictionary:
	return _make_binary_safe({
		"schema": "eralife.ui_contract_registry",
		"version": UI_CONTRACT_VERSION,
		"runtime_version": UI_RUNTIME_VERSION,
		"surface_registry": surface_registry.duplicate(true),
		"action_route_registry": action_route_registry.duplicate(true),
		"data_source_registry": data_source_registry.duplicate(true),
		"system_registry": system_registry.duplicate(true),
		"validation_reports": validation_reports.duplicate(true),
		"last_resolution_report": last_resolution_report.duplicate(true),
		"active_section_by_surface": active_section_by_surface.duplicate(true),
		"surface_runtime_state": surface_runtime_state.duplicate(true),
		"last_action_report": last_action_report.duplicate(true),
		"device_profile_override": device_profile_override,
		"prewarmed_packet_cache": prewarmed_packet_cache.duplicate(true),
		"last_prewarm_report": last_prewarm_report.duplicate(true)
	})

func import_registry(data: Dictionary) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		_ensure_core_surface_contracts()
		return

	var surfaces_raw: Variant = data.get("surface_registry", {})
	if typeof(surfaces_raw) == TYPE_DICTIONARY:
		surface_registry = (surfaces_raw as Dictionary).duplicate(true)

	var actions_raw: Variant = data.get("action_route_registry", {})
	if typeof(actions_raw) == TYPE_DICTIONARY:
		action_route_registry = (actions_raw as Dictionary).duplicate(true)

	var sources_raw: Variant = data.get("data_source_registry", {})
	if typeof(sources_raw) == TYPE_DICTIONARY:
		data_source_registry = (sources_raw as Dictionary).duplicate(true)

	var systems_raw: Variant = data.get("system_registry", {})
	if typeof(systems_raw) == TYPE_DICTIONARY:
		system_registry = (systems_raw as Dictionary).duplicate(true)

	var reports_raw: Variant = data.get("validation_reports", {})
	if typeof(reports_raw) == TYPE_DICTIONARY:
		validation_reports = (reports_raw as Dictionary).duplicate(true)

	var active_sections_raw: Variant = data.get("active_section_by_surface", {})
	if typeof(active_sections_raw) == TYPE_DICTIONARY:
		active_section_by_surface = (active_sections_raw as Dictionary).duplicate(true)

	var runtime_state_raw: Variant = data.get("surface_runtime_state", {})
	if typeof(runtime_state_raw) == TYPE_DICTIONARY:
		surface_runtime_state = (runtime_state_raw as Dictionary).duplicate(true)

	var action_report_raw: Variant = data.get("last_action_report", {})
	if typeof(action_report_raw) == TYPE_DICTIONARY:
		last_action_report = (action_report_raw as Dictionary).duplicate(true)
	var prewarm_cache_raw: Variant = data.get("prewarmed_packet_cache", {})
	if typeof(prewarm_cache_raw) == TYPE_DICTIONARY:
		prewarmed_packet_cache = (prewarm_cache_raw as Dictionary).duplicate(true)

	var prewarm_report_raw: Variant = data.get("last_prewarm_report", {})
	if typeof(prewarm_report_raw) == TYPE_DICTIONARY:
		last_prewarm_report = (prewarm_report_raw as Dictionary).duplicate(true)
	device_profile_override = str(data.get("device_profile_override", "")).strip_edges()

	_ensure_core_surface_contracts()
	_repair_runtime_state_after_import()

func get_debug_report() -> Dictionary:
	return _make_binary_safe({
		"schema": "eralife.ui_contract_debug_report",
		"version": UI_CONTRACT_VERSION,
		"runtime_version": UI_RUNTIME_VERSION,
		"surface_count": surface_registry.size(),
		"system_count": system_registry.size(),
		"data_source_count": data_source_registry.size(),
		"action_route_count": action_route_registry.size(),
		"active_section_by_surface": active_section_by_surface.duplicate(true),
		"surface_runtime_state": surface_runtime_state.duplicate(true),
		"validation_reports": validation_reports.duplicate(true),
		"last_resolution_report": last_resolution_report.duplicate(true),
		"last_action_report": last_action_report.duplicate(true),
		"prewarmed_packet_count": prewarmed_packet_cache.size(),
		"last_prewarm_report": last_prewarm_report.duplicate(true)
	})

func _normalize_section_contract(section: Dictionary, surface_id: String) -> Dictionary:
	return {
		"id": str(section.get("id", "section")).strip_edges(),
		"surface_id": surface_id,
		"label": str(section.get("label", section.get("title", "Section"))).strip_edges(),
		"title": str(section.get("title", section.get("label", "Section"))).strip_edges(),
		"subtitle": str(section.get("subtitle", "")).strip_edges(),
		"description": str(section.get("description", "")).strip_edges(),
		"icon": str(section.get("icon", "")).strip_edges(),
		"layout": str(section.get("layout", "scroll_list")).strip_edges().to_lower(),
		"visibility_rule": section.get("visibility_rule", "always"),
		"enabled_rule": section.get("enabled_rule", "always"),
		"data_source": str(section.get("data_source", "")).strip_edges(),
		"data_binding": section.get("data_binding", {}).duplicate(true) if typeof(section.get("data_binding", {})) == TYPE_DICTIONARY else {},
		"actions": _safe_dictionary_array(section.get("actions", [])),
		"theme": section.get("theme", {}).duplicate(true) if typeof(section.get("theme", {})) == TYPE_DICTIONARY else {},
		"content_surface": str(section.get("content_surface", "")).strip_edges(),
		"is_default": bool(section.get("is_default", false)),
		"persistent_state": bool(section.get("persistent_state", true)),
		"metadata": section.get("metadata", {}).duplicate(true) if typeof(section.get("metadata", {})) == TYPE_DICTIONARY else {}
	}

func _normalize_action_contract(action: Dictionary, surface_id: String) -> Dictionary:
	return {
		"id": str(action.get("id", action.get("action_id", ""))).strip_edges(),
		"surface_id": str(action.get("surface_id", surface_id)).strip_edges(),
		"label": str(action.get("label", "Action")).strip_edges(),
		"kind": str(action.get("kind", "packet")).strip_edges().to_lower(),
		"target": str(action.get("target", "")).strip_edges(),
		"method": str(action.get("method", "")).strip_edges(),
		"engine_property": str(action.get("engine_property", "")).strip_edges(),
		"command": str(action.get("command", "")).strip_edges(),
		"scenario_id": str(action.get("scenario_id", "")).strip_edges(),
		"payload": action.get("payload", {}).duplicate(true) if typeof(action.get("payload", {})) == TYPE_DICTIONARY else {},
		"call_mode": str(action.get("call_mode", "payload_context")).strip_edges().to_lower(),
		"visibility_rule": action.get("visibility_rule", "always"),
		"enabled_rule": action.get("enabled_rule", "always"),
		"close_after": bool(action.get("close_after", false)),
		"refresh_after": bool(action.get("refresh_after", true)),
		"metadata": action.get("metadata", {}).duplicate(true) if typeof(action.get("metadata", {})) == TYPE_DICTIONARY else {}
	}

func _passes_rule(rule: Variant, context: Dictionary, owner: Dictionary = {}) -> bool:
	if typeof(rule) == TYPE_BOOL:
		return bool(rule)

	if typeof(rule) == TYPE_DICTIONARY:
		var kind: String = str(rule.get("kind", rule.get("rule", "always"))).strip_edges().to_lower()

		match kind:
			"all":
				for child_rule in rule.get("rules", []):
					if not _passes_rule(child_rule, context, owner):
						return false
				return true

			"any":
				for child_rule in rule.get("rules", []):
					if _passes_rule(child_rule, context, owner):
						return true
				return false

			"not":
				return not _passes_rule(rule.get("rule_value", rule.get("value", "always")), context, owner)

			"age_at_least":
				return gs != null and gs.player != null and int(gs.player.age) >= int(rule.get("value", 0))

			"feature_enabled":
				return gs != null and gs.has_method("is_feature_enabled") and gs.is_feature_enabled(str(rule.get("feature", "")))

			"has_trait":
				return gs != null and gs.player != null and str(rule.get("trait", "")) in gs.player.traits

			"data_source_has_rows":
				return resolve_data_source(str(rule.get("data_source", "")), context, owner).size() > 0

			"current_panel":
				return str(context.get("panel", "")).strip_edges() == str(rule.get("value", "")).strip_edges()

			"device_profile":
				return _resolve_device_profile(context) == str(rule.get("value", "")).strip_edges().to_lower()

			"player_property_equals":
				var key: String = str(rule.get("property", "")).strip_edges()
				return str(_get_player_value(key, null)) == str(rule.get("value", ""))

			_:
				return true

	var clean: String = str(rule).strip_edges().to_lower()
	match clean:
		"", "always", "true":
			return true

		"never", "false":
			return false

		"player_has_bending":
			return gs != null and gs.player != null and gs.bending_engine != null and gs.bending_engine.has_method("has_bending") and gs.bending_engine.has_bending(gs.player)

		"player_has_wizard_magic":
			return gs != null and gs.player != null and gs.wizard_engine != null and gs.wizard_engine.has_method("has_wizard_magic") and gs.wizard_engine.has_wizard_magic(gs.player)
		"player_has_superpowers":
			return gs != null and gs.player != null and gs.power_engine != null and gs.power_engine.has_method("has_superpowers") and gs.power_engine.has_superpowers(gs.player)
		"player_is_royal":
			return bool(_get_player_value("is_royal", false))

		"player_has_artifacts":
			return gs != null and gs.has_method("is_feature_enabled") and gs.is_feature_enabled("artifacts")

		_:
			return true

func _resolve_registered_data_source(source: Dictionary, context: Dictionary, _surface: Dictionary) -> Array:
	var engine_property: String = str(source.get("engine_property", "")).strip_edges()
	var method_name: String = str(source.get("method", "")).strip_edges()
	var call_mode: String = str(source.get("call_mode", "context")).strip_edges().to_lower()

	if gs == null or engine_property == "" or method_name == "":
		return []

	var engine: Variant = gs.get(engine_property) if gs.has_method("get") else null
	if engine == null or not engine.has_method(method_name):
		return []

	var args: Array = []
	match call_mode:
		"none":
			args = []
		"player":
			args = [gs.player]
		"context_surface":
			args = [context, _surface]
		"context":
			args = [context]
		_:
			args = [context]

	var result: Variant = engine.callv(method_name, args)
	if typeof(result) == TYPE_ARRAY:
		return result

	return []

func _resolve_action_list(actions: Variant, context: Dictionary, owner: Dictionary) -> Array:
	var out: Array = []
	for raw_action in _safe_dictionary_array(actions):
		var action: Dictionary = _normalize_action_contract(raw_action, str(owner.get("surface_id", "")))
		if not _passes_rule(action.get("visibility_rule", "always"), context, action):
			continue
		action ["enabled"] = _passes_rule(action.get("enabled_rule", "always"), context, action)
		out.append(action)
	return out

func _find_action_in_surface(surface: Dictionary, action_id: String) -> Dictionary:
	for raw_action in surface.get("actions", []):
		if typeof(raw_action) != TYPE_DICTIONARY:
			continue
		if str((raw_action as Dictionary).get("id", "")) == action_id:
			return (raw_action as Dictionary).duplicate(true)

	for raw_section in surface.get("sections", []):
		if typeof(raw_section) != TYPE_DICTIONARY:
			continue
		var section: Dictionary = raw_section
		for raw_action in section.get("actions", []):
			if typeof(raw_action) != TYPE_DICTIONARY:
				continue
			if str((raw_action as Dictionary).get("id", "")) == action_id:
				return (raw_action as Dictionary).duplicate(true)

	return {}

func _build_command_envelope(surface_id: String, action_id: String, route: Dictionary, payload: Dictionary, context: Dictionary) -> Dictionary:
	return {
		"schema": "eralife.ui_command_envelope",
		"version": UI_CONTRACT_VERSION,
		"source": "ui_contract_engine",
		"surface_id": surface_id,
		"action_id": action_id,
		"kind": str(route.get("kind", "packet")),
		"target": str(route.get("target", "")),
		"command": str(route.get("command", "")),
		"engine_property": str(route.get("engine_property", "")),
		"method": str(route.get("method", "")),
		"scenario_id": str(route.get("scenario_id", "")),
		"payload": payload.duplicate(true),
		"context": context.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec())
	}

func _route_scenario_action(route: Dictionary, payload: Dictionary, context: Dictionary) -> Dictionary:
	if gs == null:
		return { "success": false, "reason": "GameState unavailable."}

	var scenario_id: String = str(route.get("scenario_id", route.get("target", ""))).strip_edges()
	if scenario_id == "":
		return { "success": false, "reason": "Scenario action missing scenario_id."}

	if gs.scenario_engine != null and gs.scenario_engine.has_method("queue_data_driven_scenario"):
		gs.scenario_engine.queue_data_driven_scenario(scenario_id, gs.player)
		return {
			"success": true,
			"scenario_id": scenario_id,
			"mode": "queue_data_driven_scenario"
		}

	return {
		"success": true,
		"scenario_id": scenario_id,
		"mode": "scenario_packet_only",
		"payload": payload.duplicate(true),
		"context": context.duplicate(true)
	}

func _route_engine_call(route: Dictionary, payload: Dictionary, context: Dictionary) -> Dictionary:
	if gs == null:
		return { "success": false, "reason": "GameState unavailable."}

	var engine_property: String = str(route.get("engine_property", "")).strip_edges()
	var method_name: String = str(route.get("method", "")).strip_edges()
	var call_mode: String = str(route.get("call_mode", "payload_context")).strip_edges().to_lower()

	if engine_property == "" or method_name == "":
		return { "success": false, "reason": "Engine action missing engine_property or method."}

	var engine: Variant = gs.get(engine_property) if gs.has_method("get") else null
	if engine == null or not engine.has_method(method_name):
		return { "success": false, "reason": "Engine or method unavailable."}

	var args: Array = []
	match call_mode:
		"none":
			args = []
		"payload":
			args = [payload]
		"context":
			args = [context]
		"player_payload":
			args = [gs.player, payload]
		_:
			args = [payload, context]

	var result: Variant = engine.callv(method_name, args)
	return {
		"success": true,
		"engine_property": engine_property,
		"method": method_name,
		"result": result
	}

func _route_command_envelope(envelope: Dictionary) -> Dictionary:
	if envelope.is_empty():
		return { "success": false, "reason": "Command envelope is empty."}

	if gs != null and gs.has_method("queue_command_envelope"):
		gs.queue_command_envelope(envelope)
		return {
			"success": true,
			"mode": "queued",
			"envelope": envelope.duplicate(true)
		}

	if gs != null and gs.has_method("route_command_envelope"):
		var result: Variant = gs.route_command_envelope(envelope)
		return {
			"success": true,
			"mode": "routed",
			"result": result
		}

	return {
		"success": true,
		"mode": "packet_only",
		"envelope": envelope.duplicate(true)
	}

func _surface_supports_device(surface: Dictionary, profile: String) -> bool:
	var profiles: Array = _safe_string_array(surface.get("device_profiles", ["auto"]))
	if profiles.is_empty():
		return true
	if "auto" in profiles or "all" in profiles:
		return true
	return profile in profiles

func _resolve_device_profile(context: Dictionary = {}) -> String:
	var override: String = device_profile_override.strip_edges().to_lower()
	if override != "":
		return override

	var context_profile: String = str(context.get("device_profile", "")).strip_edges().to_lower()
	if context_profile in SUPPORTED_DEVICE_PROFILES:
		return context_profile

	var width: int = int(context.get("viewport_width", 1280))
	if width <= 640:
		return "phone"
	if width <= 1024:
		return "tablet"

	return "desktop"

func _apply_device_override(surface: Dictionary, profile: String) -> Dictionary:
	var layout_by_device_raw: Variant = surface.get("layout_by_device", {})
	if typeof(layout_by_device_raw) == TYPE_DICTIONARY:
		var layout_by_device: Dictionary = layout_by_device_raw
		if layout_by_device.has(profile):
			surface ["layout"] = str(layout_by_device.get(profile, surface.get("layout", "button")))

	var overrides_raw: Variant = surface.get("device_overrides", {})
	if typeof(overrides_raw) != TYPE_DICTIONARY:
		return surface

	var overrides: Dictionary = overrides_raw
	if not overrides.has(profile):
		return surface

	var patch_raw: Variant = overrides.get(profile, {})
	if typeof(patch_raw) != TYPE_DICTIONARY:
		return surface

	return _merge_dict(surface, patch_raw as Dictionary)

func _repair_runtime_state_after_import() -> void:
	for surface_id in surface_registry.keys():
		var clean_surface: String = str(surface_id).strip_edges()
		if clean_surface == "":
			continue
		if not active_section_by_surface.has(clean_surface):
			var default_section_id: String = _first_section_id(surface_registry.get(clean_surface, {}))
			if default_section_id != "":
				active_section_by_surface [clean_surface] = default_section_id

func _first_section_id(surface: Dictionary) -> String:
	var sections: Array = surface.get("sections", []) if typeof(surface.get("sections", [])) == TYPE_ARRAY else []
	for raw_section in sections:
		if typeof(raw_section) != TYPE_DICTIONARY:
			continue
		var section: Dictionary = raw_section
		if bool(section.get("is_default", false)):
			return str(section.get("id", "")).strip_edges()

	for raw_section in sections:
		if typeof(raw_section) != TYPE_DICTIONARY:
			continue
		var section: Dictionary = raw_section
		var section_id: String = str(section.get("id", "")).strip_edges()
		if section_id != "":
			return section_id

	return ""

func _get_player_value(key: String, fallback: Variant = null) -> Variant:
	if gs == null or gs.player == null:
		return fallback

	var clean_key: String = str(key).strip_edges()
	if clean_key == "":
		return fallback

	if gs.player.has_method("get"):
		var value: Variant = gs.player.get(clean_key)
		if value != null:
			return value

	return fallback

func _default_layout_for_surface(surface_type: String) -> String:
	match surface_type:
		"hub":
			return "hub_sections"
		"panel":
			return "detail_panel"
		"list":
			return "scroll_list"
		"combat_ui":
			return "combat_frame"
		"debug_panel":
			return "debug_text"
		_:
			return "button"

func _safe_dictionary_array(value: Variant) -> Array:
	var out: Array = []
	if typeof(value) != TYPE_ARRAY:
		return out
	for raw in value:
		if typeof(raw) == TYPE_DICTIONARY:
			out.append((raw as Dictionary).duplicate(true))
	return out

func _safe_string_array(value: Variant) -> Array:
	var out: Array = []
	if typeof(value) != TYPE_ARRAY:
		return out
	for raw in value:
		var clean: String = str(raw).strip_edges()
		if clean != "":
			out.append(clean)
	return out

func _merge_dict(base: Dictionary, patch: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	for key in patch.keys():
		var patch_value: Variant = patch [key]
		if typeof(patch_value) == TYPE_DICTIONARY and typeof(out.get(key, {})) == TYPE_DICTIONARY:
			out [key] = _merge_dict(out.get(key, {}), patch_value)
		else:
			out [key] = patch_value
	return out

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

func _ensure_core_surface_contracts() -> void:
	if surface_registry.has("career_contract_hub") and surface_registry.has("realm_contract_hub") and surface_registry.has("bending_contract_hub") and surface_registry.has("bank_contract_hub"):
		return

	var core_pack:= {
		"data_sources": [
			{
				"id": "bank.player_summary",
				"engine_property": "bank_engine",
				"method": "get_player_bank_rows",
				"call_mode": "context"
			},
			{
				"id": "bank.cash_wallet",
				"engine_property": "bank_engine",
				"method": "get_player_cash_rows",
				"call_mode": "context"
			},
			{
				"id": "bank.accounts",
				"engine_property": "bank_engine",
				"method": "get_player_account_rows",
				"call_mode": "context"
			},
			{
				"id": "bank.risk_rules",
				"engine_property": "bank_engine",
				"method": "get_risk_rows",
				"call_mode": "context"
				},
				{
				"id": "food.status",
				"engine_property": "food_engine",
				"method": "get_food_status_rows",
				"call_mode": "context"
				},
				{
				"id": "food.pantry",
				"engine_property": "food_engine",
				"method": "get_pantry_rows",
				"call_mode": "context"
				},
				{
				"id": "restaurant.list",
				"engine_property": "food_restaurant_engine",
				"method": "get_restaurant_rows",
				"call_mode": "context"
				},
				{
				"id": "grocery.stores",
				"engine_property": "grocery_store_engine",
				"method": "get_grocery_store_rows",
				"call_mode": "context"
				},
				{
				"id": "luxury.shops",
				"engine_property": "luxury_shop_engine",
				"method": "get_luxury_shop_rows",
				"call_mode": "context"
			},
			{
				"id": "inventory.player",
				"engine_property": "belongings_engine",
				"method": "get_player_inventory_rows",
				"call_mode": "context"
			},
			{
				"id": "superhero.dashboard",
				"engine_property": "superhero_engine",
				"method": "get_dashboard_rows",
				"call_mode": "context"
			},
			{
				"id": "superhero.patrol",
				"engine_property": "superhero_engine",
				"method": "get_patrol_rows",
				"call_mode": "context"
			},
			{
				"id": "superhero.crime_response",
				"engine_property": "superhero_engine",
				"method": "get_crime_response_rows",
				"call_mode": "context"
			},
			{
				"id": "superhero.villains",
				"engine_property": "superhero_engine",
				"method": "get_villain_rows",
				"call_mode": "context"
			},
			{
				"id": "superhero.teams",
				"engine_property": "superhero_engine",
				"method": "get_team_rows",
				"call_mode": "context"
			},
			{
				"id": "superhero.reputation",
				"engine_property": "superhero_engine",
				"method": "get_reputation_rows",
				"call_mode": "context"
			},
			{
				"id": "superhero.live_events",
				"engine_property": "superhero_engine",
				"method": "get_live_event_rows",
				"call_mode": "context"
			},
			{
				"id": "powers.overview",
				"engine_property": "power_engine",
				"method": "get_power_overview_rows",
				"call_mode": "context"
			},
			{
				"id": "powers.training",
				"engine_property": "power_engine",
				"method": "get_power_training_rows",
				"call_mode": "context"
			},
			{
				"id": "powers.origins",
				"engine_property": "power_engine",
				"method": "get_power_origin_rows",
				"call_mode": "context"
			},
			{
				"id": "infamy.profile",
				"engine_property": "infamy_engine",
				"method": "get_infamy_rows",
				"call_mode": "context"
			}
		],
		"id": "eralife_core_ui_surfaces",
		"systems": [
			{
				"system_id": "ui_contract_engine",
				"engine_property": "ui_contract_engine",
				"surfaces": [
					"discord_life_hub",
					"career_contract_hub",
					"relationship_contract_hub",
					"activity_contract_hub",
					"realm_contract_hub",
					"superhero_contract_hub",
					"bending_contract_hub",
					"bank_contract_hub",
					"food_contract_hub",
					"restaurant_contract_hub",
					"grocery_contract_hub",
					"luxury_contract_hub",
					"inventory_contract_hub",
					"scenario_contract_hub"
				],
				"enabled": true,
				"tags": ["core", "ui", "runtime"]
			}
		],
		"ui_surfaces": [
			{
				"surface_id": "discord_life_hub",
				"surface_type": "hub",
				"layout": "hub_sections",
				"label": "EraLife",
				"title": "EraLife Discord Hub",
				"subtitle": "Your life is now controlled through Data Driven UI surfaces instead of slash command spam.",
				"description": "Open a surface below. Discord is only the shell; EraLife contracts own the reality.",
				"icon": "🌌",
				"sort_priority": 1,
				"persistent_state": true,
				"sections": [
				{
				"id": "surfaces",
				"label": "Surfaces",
				"is_default": true,
				"data_source": "ui.embedded_surface_launcher",
				"description": "Choose the next EraLife surface to open."
				}
				]
			},
			{
				"surface_id": "career_contract_hub",
				"surface_type": "hub",
				"layout": "hub_sections",
				"label": "Career Hub",
				"title": "Career Hub",
				"subtitle": "Jobs, part-time work, and fame tracks routed through UI contracts.",
				"icon": "💼",
				"sort_priority": 30,
				"persistent_state": true,
				"sections": [
					{
						"id": "full_time_jobs",
						"label": "Full-Time Jobs",
						"is_default": true,
						"data_source": "career.full_time_jobs"
					},
					{
						"id": "part_time_jobs",
						"label": "Part-Time Jobs",
						"data_source": "career.part_time_jobs"
					},
					{
						"id": "famous_tracks",
						"label": "Fame Tracks",
						"data_source": "career.famous_tracks"
					}
				]
			},
			{
				"surface_id": "relationship_contract_hub",
				"surface_type": "hub",
				"layout": "hub_sections",
				"label": "Relationships",
				"title": "Relationship Hub",
				"subtitle": "Family, friends, romance, rivals, and social memory routed through relationship contracts.",
				"icon": "❤️",
				"sort_priority": 31,
				"persistent_state": true,
				"sections": [
				{
				"id": "relationships",
				"label": "Relationships",
				"is_default": true,
				"data_source": "life.relationship_surface"
				}
				]
			},
			{
				"surface_id": "activity_contract_hub",
				"surface_type": "hub",
				"layout": "hub_sections",
				"label": "Activities",
				"title": "Activity Hub",
				"subtitle": "Life actions, social choices, risky events, and scenario routes gathered into one Discord surface.",
				"icon": "🎲",
				"sort_priority": 32,
				"persistent_state": true,
				"sections": [
				{
				"id": "activities",
				"label": "Activities",
				"is_default": true,
				"data_source": "life.activity_surface"
				}
				]
			},
			{
				"surface_id": "realm_contract_hub",
				"surface_type": "hub",
				"layout": "hub_sections",
				"label": "Realms",
				"title": "Realm Browser",
				"subtitle": "Realm entries resolved from contract-backed realm surfaces.",
				"icon": "🌐",
				"sort_priority": 35,
				"persistent_state": true,
				"sections": [
					{
						"id": "external_realms",
						"label": "Available Realms",
						"is_default": true,
						"data_source": "realm.external_entries"
					}
				]
			},
			{
				"surface_id": "bending_contract_hub",
				"surface_type": "hub",
				"layout": "hub_sections",
				"label": "Bending",
				"title": "Bending Hub",
				"subtitle": "Training, abilities, and bending actions resolved through contracts.",
				"icon": "🌀",
				"sort_priority": 40,
				"visibility_rule": "player_has_bending",
				"persistent_state": true,
				"sections": [
					{
						"id": "abilities",
						"label": "Abilities",
						"is_default": true,
						"data_source": "bending.available_abilities"
					}
				]
			},
			{
				"surface_id": "superhero_contract_hub",
				"surface_type": "hub",
				"layout": "hub_sections",
				"label": "Super Hero",
				"title": "Super Hero Hub",
				"subtitle": "Powers, patrols, villains, teams, reputation, and infamy routed through contract-driven superhero systems.",
				"icon": "🦸",
				"sort_priority": 39,
				"visibility_rule": {
					"kind": "any",
					"rules": [
						"player_has_superpowers",
						{
							"kind": "feature_enabled",
							"feature": "superpowers"
						}
					]
				},
				"persistent_state": true,
				"sections": [
					{
						"id": "dashboard",
						"label": "Dashboard",
						"is_default": true,
						"data_source": "superhero.dashboard",
						"actions": [
							{
								"id": "superhero_become_hero",
								"label": "Become A Hero",
								"kind": "engine_call",
								"engine_property": "superhero_engine",
								"method": "resolve_hub_action",
								"call_mode": "player_payload",
								"payload": {
									"action": "become_hero"
								},
								"refresh_after": true
							},
							{
								"id": "superhero_become_villain",
								"label": "Become A Villain",
								"kind": "engine_call",
								"engine_property": "superhero_engine",
								"method": "resolve_hub_action",
								"call_mode": "player_payload",
								"payload": {
									"action": "become_villain"
								},
								"refresh_after": true
							}
						]
					},
					{
						"id": "patrol",
						"label": "Patrol City",
						"data_source": "superhero.patrol",
						"actions": [
							{
								"id": "superhero_patrol_city",
								"label": "Patrol City",
								"kind": "engine_call",
								"engine_property": "superhero_engine",
								"method": "resolve_hub_action",
								"call_mode": "player_payload",
								"payload": {
									"action": "patrol_city"
								},
								"refresh_after": true
							}
						]
					},
					{
						"id": "respond",
						"label": "Respond to Crime",
						"data_source": "superhero.crime_response",
						"actions": [
							{
								"id": "superhero_respond_to_crime",
								"label": "Respond To Crime",
								"kind": "engine_call",
								"engine_property": "superhero_engine",
								"method": "resolve_hub_action",
								"call_mode": "player_payload",
								"payload": {
									"action": "respond_to_crime"
								},
								"refresh_after": true
							}
						]
					},
					{
						"id": "villains",
						"label": "Track Villains",
						"data_source": "superhero.villains",
						"actions": [
							{
								"id": "superhero_track_villain",
								"label": "Track Villain",
								"kind": "engine_call",
								"engine_property": "superhero_engine",
								"method": "resolve_hub_action",
								"call_mode": "player_payload",
								"payload": {
									"action": "track_villain"
								},
								"refresh_after": true
							}
						]
					},
					{
						"id": "powers",
						"label": "Train Powers",
						"data_source": "powers.training",
						"actions": [
							{
								"id": "superhero_train_powers",
								"label": "Train Current Power",
								"kind": "engine_call",
								"engine_property": "superhero_engine",
								"method": "resolve_hub_action",
								"call_mode": "player_payload",
								"payload": {
									"action": "train_powers"
								},
								"refresh_after": true
							}
						]
					},
					{
						"id": "origins",
						"label": "Power Origins",
						"data_source": "powers.origins"
					},
					{
						"id": "recruit",
						"label": "Recruit Allies",
						"data_source": "superhero.teams",
						"actions": [
							{
								"id": "superhero_recruit_ally",
								"label": "Recruit Powered Ally",
								"kind": "engine_call",
								"engine_property": "superhero_engine",
								"method": "resolve_hub_action",
								"call_mode": "player_payload",
								"payload": {
									"action": "recruit_ally"
								},
								"refresh_after": true
							}
						]
					},
					{
						"id": "team",
						"label": "Manage Team",
						"data_source": "superhero.teams",
						"actions": [
							{
								"id": "superhero_start_team",
								"label": "Create Crime Fighting Team",
								"kind": "engine_call",
								"engine_property": "superhero_engine",
								"method": "resolve_hub_action",
								"call_mode": "player_payload",
								"payload": {
									"action": "start_team"
								},
								"refresh_after": true
							}
						]
					},
					{
						"id": "reputation",
						"label": "Public Reputation",
						"data_source": "superhero.reputation"
					},
					{
						"id": "live",
						"label": "Watch Live Events",
						"data_source": "superhero.live_events",
						"actions": [
							{
								"id": "superhero_watch_live_events",
								"label": "Refresh Live Events",
								"kind": "engine_call",
								"engine_property": "superhero_engine",
								"method": "resolve_hub_action",
								"call_mode": "player_payload",
								"payload": {
									"action": "watch_live_events"
								},
								"refresh_after": true
							}
						]
					},
					{
						"id": "villain_path",
						"label": "Infamy",
						"data_source": "infamy.profile"
					}
				]
			},
			{
				"surface_id": "bank_contract_hub",
				"surface_type": "hub",
				"layout": "hub_sections",
				"label": "Bank",
				"title": "Bank Hub",
				"subtitle": "Cash, secured bank accounts, and InterWorld credit routed through BankEngine contracts.",
				"icon": "🏦",
				"sort_priority": 34,
				"persistent_state": true,
				"sections": [
					{
						"id": "summary",
						"label": "Overview",
						"is_default": true,
						"data_source": "bank.player_summary",
						"actions": [
							{
								"id": "bank_deposit_100",
								"label": "Deposit 100 Cash",
								"kind": "command",
								"command": "bank.deposit",
								"engine_property": "bank_engine",
								"target": "bank_engine",
								"payload": {
									"action": "deposit",
									"amount": 100,
									"currency": "USD"
								},
								"refresh_after": true
							},
							{
								"id": "bank_withdraw_100",
								"label": "Withdraw 100 Cash",
								"kind": "command",
								"command": "bank.withdraw",
								"engine_property": "bank_engine",
								"target": "bank_engine",
								"payload": {
									"action": "withdraw",
									"amount": 100,
									"currency": "USD"
								},
								"refresh_after": true
							},
							{
								"id": "bank_deposit_all_cash",
								"label": "Deposit All Cash",
								"kind": "command",
								"command": "bank.deposit",
								"engine_property": "bank_engine",
								"target": "bank_engine",
								"payload": {
									"action": "deposit_all",
									"currency": "USD"
								},
								"refresh_after": true
							}
						]
					},
					{
						"id": "cash",
						"label": "Cash",
						"data_source": "bank.cash_wallet"
					},
					{
						"id": "accounts",
						"label": "Accounts",
						"data_source": "bank.accounts"
					},
					{
						"id": "risk_rules",
						"label": "Risks",
						"data_source": "bank.risk_rules"
					}
				]
			},
			{
				"surface_id": "food_contract_hub",
				"surface_type": "hub",
				"layout": "hub_sections",
				"label": "Food",
				"title": "Food Hub",
				"subtitle": "Hunger, nutrition, pantry food, cooking, and diet pressure routed through FoodEngine.",
				"icon": "🍽️",
				"sort_priority": 36,
				"persistent_state": true,
				"sections": [
				{
				"id": "status",
				"label": "Status",
				"is_default": true,
				"data_source": "food.status"
				},
				{
				"id": "pantry",
				"label": "Pantry",
				"data_source": "food.pantry"
				}
				]
				},
			{
				"surface_id": "restaurant_contract_hub",
				"surface_type": "hub",
				"layout": "hub_sections",
				"label": "Restaurants",
				"title": "Restaurant Hub",
				"subtitle": "Fast food, dates, drive-through, luxury restaurants, and fame-gated dining.",
				"icon": "🍔",
				"sort_priority": 37,
				"persistent_state": true,
				"sections": [
					{
						"id": "restaurants",
						"label": "Restaurants",
						"is_default": true,
						"data_source": "restaurant.list",
						"description": "Pick a restaurant to open its contract-generated menu."
					},
					{
						"id": "menu",
						"label": "Menu",
						"data_source": "restaurant.menu",
						"description": "Menu actions are generated from the selected restaurant contract.",
						"actions": [
							{
								"id": "restaurant_back:list",
								"label": "Restaurants",
								"kind": "packet",
								"style": "secondary"
							}
						]
					}
				]
			},
			{
				"surface_id": "grocery_contract_hub",
				"surface_type": "hub",
				"layout": "hub_sections",
				"label": "Groceries",
				"title": "Grocery Store Hub",
				"subtitle": "Buy food into pantry inventory, track spoilage, and route payment through BankEngine.",
				"icon": "🛒",
				"sort_priority": 38,
				"persistent_state": true,
				"sections": [
				{
				"id": "stores",
				"label": "Stores",
				"is_default": true,
				"data_source": "grocery.stores"
				}
				]
				},
			{
				"surface_id": "luxury_contract_hub",
				"surface_type": "hub",
				"layout": "hub_sections",
				"label": "Luxury",
				"title": "Luxury & Artifacts Shop",
				"subtitle": "Jewelry, gemstones, heirlooms, relics, and lore-backed prestige items.",
				"icon": "💎",
				"sort_priority": 39,
				"persistent_state": true,
				"sections": [
					{
						"id": "shops",
						"label": "Shops",
						"is_default": true,
						"data_source": "luxury.shops",
						"description": "Choose a shop to browse contract-separated item categories."
					},
					{
						"id": "items",
						"label": "Items",
						"data_source": "luxury.items",
						"description": "Items are grouped and color-tagged by category, material, and artifact class.",
						"actions": [
							{
								"id": "luxury_back:shops",
								"label": "Shops",
								"kind": "packet",
								"style": "secondary"
							}
						]
					},
					{
						"id": "lore",
						"label": "Lore",
						"data_source": "luxury.item_overview",
						"description": "Read the item overview before buying.",
						"actions": [
							{
								"id": "luxury_back:items",
								"label": "Items",
								"kind": "packet",
								"style": "secondary"
							}
						]
					}
				]
			},
			{
				"surface_id": "inventory_contract_hub",
				"surface_type": "hub",
				"layout": "hub_sections",
				"label": "Inventory",
				"title": "Inventory",
				"subtitle": "Items are separated by category and owned by BelongingsEngine.",
				"icon": "🎒",
				"sort_priority": 41,
				"persistent_state": true,
				"sections": [
				{
				"id": "items",
				"label": "Items",
				"is_default": true,
				"data_source": "inventory.player"
				}
				]
				},
			{
				"surface_id": "scenario_contract_hub",
				"surface_type": "hub",
				"layout": "hub_sections",
				"label": "Scenarios",
				"title": "Scenario Contracts",
				"subtitle": "Available runtime scenarios exposed without hard-wiring UI to systems.",
				"icon": "🎭",
				"sort_priority": 90,
				"persistent_state": true,
				"sections": [
					{
						"id": "available_scenarios",
						"label": "Available",
						"is_default": true,
						"data_source": "scenario.available_contracts"
					}
				]
			}
		]
	}

	ingest_pack(core_pack)