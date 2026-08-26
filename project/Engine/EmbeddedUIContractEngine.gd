extends Resource
class_name EmbeddedUIContractEngine

const EMBEDDED_UI_VERSION:= 1

const SUPPORTED_PLATFORMS:= [
	"discord",
	"web",
	"wii",
	"smart_tv",
	"mobile",
	"terminal",
	"godot"
]

const MAX_DISCORD_FIELDS:= 8
const MAX_DISCORD_BUTTONS_PER_ROW:= 5
const MAX_DISCORD_COMPONENT_ROWS:= 5

var gs
var ui_engine
var last_render_report: Dictionary = {}
var last_route_report: Dictionary = {}


func _init(_gs = null):
	gs = _gs
	_bind_ui_engine()


func render_surface(surface_id: String, context: Dictionary = {}) -> Dictionary:
	_bind_ui_engine()

	var clean_surface: String = str(surface_id).strip_edges()
	if clean_surface == "":
		return _embedded_error("missing_surface_id", "Embedded UI render needs a surface_id.", context)

	if ui_engine == null:
		return _embedded_error("ui_contract_engine_unavailable", "UIContractEngine is not available yet.", context)

	var platform: String = _normalize_platform(str(context.get("platform", context.get("adapter", "discord"))))
	var embedded_context: Dictionary = _normalize_context(context, platform)

	var view_model: Dictionary = {}
	if ui_engine.has_method("get_surface_view_model"):
		view_model = ui_engine.get_surface_view_model(clean_surface, embedded_context)
	elif ui_engine.has_method("resolve_surface"):
		view_model = ui_engine.resolve_surface(clean_surface, embedded_context)

	if view_model.is_empty():
		return _embedded_error("surface_not_visible_or_missing", "That UI surface is not visible or does not exist.", embedded_context, {
			"surface_id": clean_surface
		})

	var render_model: Dictionary = _render_view_model(view_model, platform, embedded_context)

	last_render_report = _make_binary_safe({
		"schema": "eralife.embedded_ui_render_report",
		"version": EMBEDDED_UI_VERSION,
		"success": true,
		"surface_id": clean_surface,
		"platform": platform,
		"context": embedded_context.duplicate(true),
		"view_model": view_model.duplicate(true),
		"render_model": render_model.duplicate(true),
		"rendered_at_ms": int(Time.get_ticks_msec())
	})

	return last_render_report.duplicate(true)


func route_interaction(surface_id: String, action_id: String, payload: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	_bind_ui_engine()

	var clean_surface: String = str(surface_id).strip_edges()
	var clean_action: String = str(action_id).strip_edges()

	if clean_surface == "":
		return _embedded_error("missing_surface_id", "Embedded UI action needs a surface_id.", context)

	if clean_action == "":
		return _embedded_error("missing_action_id", "Embedded UI action needs an action_id.", context)

	if ui_engine == null:
		return _embedded_error("ui_contract_engine_unavailable", "UIContractEngine is not available yet.", context)

	var platform: String = _normalize_platform(str(context.get("platform", context.get("adapter", "discord"))))
	var embedded_context: Dictionary = _normalize_context(context, platform)

	var action_report: Dictionary = {}

	if clean_action.begins_with("section:"):
		var section_id: String = clean_action.trim_prefix("section:").strip_edges()
		if ui_engine.has_method("set_active_section"):
			action_report = ui_engine.set_active_section(clean_surface, section_id)
		else:
			action_report = {
				"success": false,
				"reason": "UIContractEngine cannot set active sections."
			}
	else:
		if ui_engine.has_method("route_interaction"):
			action_report = ui_engine.route_interaction(clean_surface, clean_action, payload, embedded_context)
		else:
			action_report = {
				"success": false,
				"reason": "UIContractEngine cannot route interactions."
			}

	var next_surface_id: String = str(action_report.get("next_surface_id", clean_surface)).strip_edges()
	if next_surface_id == "":
		next_surface_id = clean_surface

	var render_report: Dictionary = render_surface(next_surface_id, embedded_context)

	last_route_report = _make_binary_safe({
		"schema": "eralife.embedded_ui_route_report",
		"version": EMBEDDED_UI_VERSION,
		"success": bool(action_report.get("success", false)),
		"surface_id": clean_surface,
		"next_surface_id": next_surface_id,
		"action_id": clean_action,
		"platform": platform,
		"payload": payload.duplicate(true),
		"context": embedded_context.duplicate(true),
		"action_report": action_report.duplicate(true),
		"render_report": render_report.duplicate(true),
		"routed_at_ms": int(Time.get_ticks_msec())
	})

	return last_route_report.duplicate(true)


func export_debug_snapshot() -> Dictionary:
	return _make_binary_safe({
		"schema": "eralife.embedded_ui_debug_snapshot",
		"version": EMBEDDED_UI_VERSION,
		"bound": ui_engine != null,
		"supported_platforms": SUPPORTED_PLATFORMS.duplicate(),
		"last_render_report": last_render_report.duplicate(true),
		"last_route_report": last_route_report.duplicate(true)
	})


func _render_view_model(view_model: Dictionary, platform: String, context: Dictionary) -> Dictionary:
	var model:= {
		"schema": "eralife.embedded_ui_model",
		"version": EMBEDDED_UI_VERSION,
		"platform": platform,
		"surface": _surface_summary(view_model),
		"rows": _active_rows(view_model),
		"actions": _active_actions(view_model),
		"section_tabs": _safe_array(view_model.get("section_tabs", [])),
		"active_section": _safe_dictionary(view_model.get("active_section", {})),
		"generated_at_ms": int(Time.get_ticks_msec())
	}

	match platform:
		"discord":
			model ["discord"] = _render_discord_model(view_model, context)
		"terminal":
			model ["terminal"] = _render_terminal_model(view_model)
		"web", "mobile", "wii", "smart_tv", "godot":
			model [platform] = _render_generic_platform_model(view_model, platform)
		_:
			model ["terminal"] = _render_terminal_model(view_model)

	return _make_binary_safe(model)


func _render_discord_model(view_model: Dictionary, context: Dictionary) -> Dictionary:
	var surface_id: String = str(view_model.get("surface_id", "")).strip_edges()
	var active_section: Dictionary = _safe_dictionary(view_model.get("active_section", {}))
	var title: String = _with_icon(str(view_model.get("icon", "")), str(view_model.get("title", view_model.get("label", surface_id))))
	var subtitle: String = str(view_model.get("subtitle", "")).strip_edges()
	var description: String = str(view_model.get("description", "")).strip_edges()
	var section_description: String = str(active_section.get("description", "")).strip_edges()

	var description_lines: Array = []
	if subtitle != "":
		description_lines.append(subtitle)
	if description != "":
		description_lines.append(description)
	if section_description != "" and section_description != description:
		description_lines.append(section_description)

	var rows: Array = _active_rows(view_model)
	var fields: Array = []

	for row in rows.slice(0, min(MAX_DISCORD_FIELDS, rows.size())):
		var row_dict: Dictionary = _safe_dictionary(row)
		fields.append({
			"name": _row_title(row_dict),
			"value": _row_value(row_dict),
			"inline": false
		})

	if rows.is_empty():
		fields.append({
			"name": "Status",
			"value": "No rows are available for this surface yet.",
			"inline": false
		})

	return {
		"embeds": [
			{
				"title": title,
				"description": "\n\n".join(description_lines).strip_edges(),
				"color": _theme_color(view_model, context),
				"fields": fields,
				"footer": "EmbeddedUIContractEngine • %s" % surface_id
			}
		],
		"components": _discord_components(view_model),
		"ephemeral": bool(context.get("ephemeral", false))
	}


func _render_terminal_model(view_model: Dictionary) -> Dictionary:
	var lines: Array = []
	var surface_id: String = str(view_model.get("surface_id", "")).strip_edges()

	lines.append(_with_icon(str(view_model.get("icon", "")), str(view_model.get("title", surface_id))))
	lines.append("Surface: %s" % surface_id)

	var active_section: Dictionary = _safe_dictionary(view_model.get("active_section", {}))
	var section_label: String = str(active_section.get("label", "")).strip_edges()
	if section_label != "":
		lines.append("Section: %s" % section_label)

	lines.append("")

	for row in _active_rows(view_model):
		var row_dict: Dictionary = _safe_dictionary(row)
		lines.append("• %s — %s" % [_row_title(row_dict), _row_value(row_dict)])

	return {
		"text": "\n".join(lines),
		"actions": _active_actions(view_model),
		"section_tabs": _safe_array(view_model.get("section_tabs", []))
	}


func _render_generic_platform_model(view_model: Dictionary, platform: String) -> Dictionary:
	return {
		"platform": platform,
		"title": str(view_model.get("title", view_model.get("label", ""))),
		"subtitle": str(view_model.get("subtitle", "")),
		"layout": str(view_model.get("layout", "hub_sections")),
		"surface_id": str(view_model.get("surface_id", "")),
		"active_section_id": str(view_model.get("active_section_id", "")),
		"sections": _safe_array(view_model.get("sections", [])),
		"section_tabs": _safe_array(view_model.get("section_tabs", [])),
		"rows": _active_rows(view_model),
		"actions": _active_actions(view_model),
		"theme": _safe_dictionary(view_model.get("theme", {}))
	}


func _discord_components(view_model: Dictionary) -> Array:
	var surface_id: String = str(view_model.get("surface_id", "")).strip_edges()
	var component_rows: Array = []

	var tabs: Array = _safe_array(view_model.get("section_tabs", []))
	var tab_buttons: Array = []
	for tab in tabs.slice(0, min(MAX_DISCORD_BUTTONS_PER_ROW, tabs.size())):
		var tab_dict: Dictionary = _safe_dictionary(tab)
		var section_id: String = str(tab_dict.get("id", "")).strip_edges()
		if section_id == "":
			continue
		tab_buttons.append({
			"type": "button",
			"surface_id": surface_id,
			"action_id": "section:%s" % section_id,
			"label": str(tab_dict.get("label", section_id)).substr(0, 80),
			"style": "secondary" if not bool(tab_dict.get("active", false)) else "primary",
			"disabled": not bool(tab_dict.get("enabled", true))
		})

	if not tab_buttons.is_empty():
		component_rows.append({
			"type": "action_row",
			"components": tab_buttons
		})

	var action_buttons: Array = []
	for action in _active_actions(view_model).slice(0, min(MAX_DISCORD_BUTTONS_PER_ROW, _active_actions(view_model).size())):
		var action_dict: Dictionary = _safe_dictionary(action)
		var button: Dictionary = _discord_button_from_action(action_dict, surface_id)
		if not button.is_empty():
			action_buttons.append(button)

	if not action_buttons.is_empty() and component_rows.size() < MAX_DISCORD_COMPONENT_ROWS:
		component_rows.append({
			"type": "action_row",
			"components": action_buttons
		})

	var row_buttons: Array = []
	for row in _active_rows(view_model):
		if component_rows.size() >= MAX_DISCORD_COMPONENT_ROWS:
			break

		var row_dict: Dictionary = _safe_dictionary(row)
		for action in _safe_array(row_dict.get("actions", [])):
			var action_dict: Dictionary = _safe_dictionary(action)
			var button: Dictionary = _discord_button_from_action(action_dict, surface_id)
			if button.is_empty():
				continue

			row_buttons.append(button)

			if row_buttons.size() >= MAX_DISCORD_BUTTONS_PER_ROW:
				component_rows.append({
					"type": "action_row",
					"components": row_buttons
				})
				row_buttons = []

			if component_rows.size() >= MAX_DISCORD_COMPONENT_ROWS:
				break

	if not row_buttons.is_empty() and component_rows.size() < MAX_DISCORD_COMPONENT_ROWS:
		component_rows.append({
			"type": "action_row",
			"components": row_buttons
		})

	return component_rows.slice(0, MAX_DISCORD_COMPONENT_ROWS)
func _discord_button_from_action(action_dict: Dictionary, surface_id: String) -> Dictionary:
	var action_id: String = str(action_dict.get("id", action_dict.get("action_id", ""))).strip_edges()
	var kind: String = str(action_dict.get("kind", "")).strip_edges().to_lower()
	var target: String = str(action_dict.get("target", "")).strip_edges()

	if action_id == "" and kind == "open_surface" and target != "":
		action_id = "open_surface:%s" % target

	if action_id == "":
		return {}

	return {
		"type": "button",
		"surface_id": str(action_dict.get("surface_id", surface_id)).strip_edges(),
		"action_id": action_id,
		"label": str(action_dict.get("label", action_id)).substr(0, 80),
		"style": _discord_style_for_action(action_dict),
		"disabled": not bool(action_dict.get("enabled", true)),
		"payload": action_dict.get("payload", {}).duplicate(true) if typeof(action_dict.get("payload", {})) == TYPE_DICTIONARY else {}
	}


func _active_rows(view_model: Dictionary) -> Array:
	var active_section: Dictionary = _safe_dictionary(view_model.get("active_section", {}))
	var section_rows: Array = _safe_array(active_section.get("rows", []))
	if not section_rows.is_empty():
		return section_rows

	return _safe_array(view_model.get("rows", []))


func _active_actions(view_model: Dictionary) -> Array:
	var out: Array = []

	var active_section: Dictionary = _safe_dictionary(view_model.get("active_section", {}))
	for action in _safe_array(active_section.get("actions", [])):
		if typeof(action) == TYPE_DICTIONARY:
			out.append((action as Dictionary).duplicate(true))

	for action in _safe_array(view_model.get("actions", [])):
		if typeof(action) == TYPE_DICTIONARY:
			out.append((action as Dictionary).duplicate(true))

	return out


func _surface_summary(view_model: Dictionary) -> Dictionary:
	return {
		"surface_id": str(view_model.get("surface_id", "")),
		"title": str(view_model.get("title", view_model.get("label", ""))),
		"label": str(view_model.get("label", "")),
		"subtitle": str(view_model.get("subtitle", "")),
		"icon": str(view_model.get("icon", "")),
		"layout": str(view_model.get("layout", "")),
		"active_section_id": str(view_model.get("active_section_id", ""))
	}


func _row_title(row: Dictionary) -> String:
	for key in ["title", "label", "name", "item_name", "restaurant_name", "store_name", "surface_id", "id"]:
		var value: String = str(row.get(key, "")).strip_edges()
		if value != "":
			return value.substr(0, 256)

	return "Entry"


func _row_value(row: Dictionary) -> String:
	for key in ["description", "summary", "text", "value", "status", "price_text"]:
		var value: String = str(row.get(key, "")).strip_edges()
		if value != "":
			return value.substr(0, 1024)

	var parts: Array = []
	for key in row.keys():
		if str(key).begins_with("_"):
			continue
		var value_text: String = str(row.get(key, "")).strip_edges()
		if value_text == "":
			continue
		parts.append("%s: %s" % [str(key), value_text])
		if parts.size() >= 5:
			break

	if parts.is_empty():
		return "—"

	return "\n".join(parts).substr(0, 1024)


func _discord_style_for_action(action: Dictionary) -> String:
	var style: String = str(action.get("style", action.get("button_style", ""))).strip_edges().to_lower()
	if style in ["primary", "secondary", "success", "danger"]:
		return style

	var kind: String = str(action.get("kind", "")).strip_edges().to_lower()
	match kind:
		"command", "engine_call", "method":
			return "success"
		"open_surface", "open_section":
			return "primary"
		_:
			return "secondary"


func _theme_color(view_model: Dictionary, context: Dictionary) -> int:
	var theme: Dictionary = _safe_dictionary(view_model.get("theme", {}))
	if theme.has("discord_color"):
		return int(theme.get("discord_color", 2829617))
	if theme.has("color"):
		return int(theme.get("color", 2829617))
	if context.has("era_color"):
		return int(context.get("era_color", 2829617))
	if context.has("reality_color"):
		return int(context.get("reality_color", 2829617))
	return 2829617


func _with_icon(icon: String, text: String) -> String:
	var clean_icon: String = str(icon).strip_edges()
	var clean_text: String = str(text).strip_edges()
	if clean_icon == "":
		return clean_text
	return "%s %s" % [clean_icon, clean_text]


func _normalize_context(context: Dictionary, platform: String) -> Dictionary:
	var out: Dictionary = context.duplicate(true)
	out ["platform"] = platform
	out ["embedded_ui"] = true
	out ["renderer"] = "EmbeddedUIContractEngine"

	if not out.has("device_profile"):
		match platform:
			"mobile", "discord":
				out ["device_profile"] = "phone"
			"smart_tv", "wii":
				out ["device_profile"] = "low_power"
			_:
				out ["device_profile"] = "desktop"

	return out


func _normalize_platform(value: String) -> String:
	var clean: String = str(value).strip_edges().to_lower()
	match clean:
		"discord.js", "discord_bot":
			return "discord"
		"tv", "smarttv":
			return "smart_tv"
		"phone":
			return "mobile"
		_:
			if clean in SUPPORTED_PLATFORMS:
				return clean
	return "discord"


func _bind_ui_engine() -> void:
	if ui_engine != null:
		return

	if gs == null:
		return

	if gs.has_method("get"):
		ui_engine = gs.get("ui_contract_engine")


func _embedded_error(reason: String, message: String, context: Dictionary = {}, extra: Dictionary = {}) -> Dictionary:
	var report:= {
		"schema": "eralife.embedded_ui_error",
		"version": EMBEDDED_UI_VERSION,
		"success": false,
		"reason": reason,
		"text": message,
		"context": context.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	for key in extra.keys():
		report [key] = extra [key]

	return _make_binary_safe(report)


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)


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