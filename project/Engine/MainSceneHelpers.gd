extends RefCounted
class_name MainSceneHelpers

# Extracted from MainScene.gd (250,507 lines, 3,977 functions -- 27% of the whole
# project in one file).
#
# Every function here was verified to depend on NOTHING from MainScene: no member
# vars, no consts, no $NodePath, no self, no signals, no await, and no bare calls
# except GDScript globals. They are pure transforms of their arguments, so moving
# them cannot change behaviour.


static func _contract_row_layout_group_id(row: Variant) -> String:
	if typeof(row) != TYPE_DICTIONARY:
		return ""

	var row_dict: Dictionary = row
	return str(row_dict.get("layout_group", "")).strip_edges()


static func _contract_make_stylebox(bg: Color, border: Color, border_width: int = 1, radius: int = 16) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style


static func _contract_surface_visual_theme(surface: Dictionary, surface_id: String) -> Dictionary:
	var runtime_state: Dictionary = surface.get("runtime_state", {}) if typeof(surface.get("runtime_state", {})) == TYPE_DICTIONARY else {}
	var store_id: String = str(runtime_state.get("store_id", "")).strip_edges()
	var visual: Dictionary = {
		"bg": Color(0.03, 0.036, 0.044, 0.975),
		"border": Color(0.62, 0.78, 0.82, 0.44),
		"title": Color(0.9, 0.96, 0.96, 1.0)
	}
	if surface_id == "restaurant_contract_hub":
		visual ["bg"] = Color(0.085, 0.052, 0.036, 0.985)
		visual ["border"] = Color(0.92, 0.62, 0.34, 0.56)
		visual ["title"] = Color(0.98, 0.92, 0.82, 1.0)
		return visual
	if surface_id == "food_contract_hub":
		match store_id:
			"basket_lane_market":
				visual ["bg"] = Color(0.088, 0.034, 0.048, 0.988)
				visual ["border"] = Color(1.0, 0.5, 0.43, 0.64)
				visual ["title"] = Color(1.0, 0.88, 0.84, 1.0)
			"goldleaf_grocers":
				visual ["bg"] = Color(0.05, 0.044, 0.032, 0.988)
				visual ["border"] = Color(0.92, 0.78, 0.48, 0.62)
				visual ["title"] = Color(0.98, 0.91, 0.7, 1.0)
			"nutripod_exchange":
				visual ["bg"] = Color(0.03, 0.048, 0.058, 0.985)
				visual ["border"] = Color(0.5, 0.86, 0.92, 0.56)
				visual ["title"] = Color(0.78, 0.96, 0.98, 1.0)
			_:
				visual ["bg"] = Color(0.034, 0.046, 0.038, 0.982)
				visual ["border"] = Color(0.58, 0.74, 0.58, 0.46)
				visual ["title"] = Color(0.86, 0.96, 0.84, 1.0)
	return visual


static func _grocery_item_contract_visual_profile(row_dict: Dictionary = {}) -> Dictionary:
	var row_kind: String = str(row_dict.get("kind", "")).strip_edges().to_lower()
	if row_kind != "grocery_item":
		return {}

	var store_id: String = str(row_dict.get("store_id", "")).strip_edges()
	var food_id: String = str(row_dict.get("food_id", "")).strip_edges().to_lower()
	var label_text: String = str(row_dict.get("label", "")).strip_edges().to_lower()
	var quality: String = str(row_dict.get("quality", row_dict.get("quality_tier", ""))).strip_edges().to_lower()

	var visual: Dictionary = {
		"bg": Color(0.115, 0.064, 0.07, 0.97),
		"border": Color(0.98, 0.58, 0.48, 0.76),
		"font": Color(1.0, 0.93, 0.9, 1.0),
		"description_font": Color(1.0, 0.84, 0.82, 0.94),
		"border_width": 2,
		"radius": 16,
		"title_size": 16
	}

	if quality.find("legendary") >= 0:
		visual ["bg"] = Color(0.138, 0.086, 0.05, 0.98)
		visual ["border"] = Color(1.0, 0.86, 0.34, 0.92)
		visual ["font"] = Color(1.0, 0.96, 0.8, 1.0)
		visual ["description_font"] = Color(0.98, 0.88, 0.66, 0.96)
		visual ["border_width"] = 3
		visual ["pulse_glow"] = true
		visual ["pulse_tint"] = Color(1.0, 0.9, 0.56, 1.0)
		visual ["pulse_seconds"] = 0.82
	elif quality.find("elite") >= 0 or quality.find("premium") >= 0 or quality.find("organic") >= 0 or quality.find("high_quality") >= 0:
		visual ["bg"] = Color(0.084, 0.094, 0.074, 0.97)
		visual ["border"] = Color(0.66, 0.96, 0.76, 0.88)
		visual ["font"] = Color(0.92, 1.0, 0.94, 1.0)
		visual ["description_font"] = Color(0.78, 0.96, 0.86, 0.95)
		visual ["border_width"] = 3
		visual ["pulse_glow"] = true
		visual ["pulse_tint"] = Color(0.74, 1.0, 0.84, 1.0)
		visual ["pulse_seconds"] = 0.86
	elif quality.find("cheap") >= 0 or quality.find("budget") >= 0 or quality.find("working_class") >= 0:
		visual ["bg"] = Color(0.084, 0.058, 0.056, 0.96)
		visual ["border"] = Color(0.72, 0.56, 0.54, 0.72)
		visual ["font"] = Color(0.94, 0.88, 0.86, 1.0)
		visual ["description_font"] = Color(0.86, 0.76, 0.74, 0.92)
	elif quality.find("sugary") >= 0 or quality.find("sweet") >= 0 or quality.find("chocolate") >= 0 or quality.find("fun_") >= 0:
		visual ["bg"] = Color(0.126, 0.058, 0.078, 0.97)
		visual ["border"] = Color(1.0, 0.52, 0.7, 0.82)
		visual ["font"] = Color(1.0, 0.9, 0.94, 1.0)
		visual ["description_font"] = Color(1.0, 0.82, 0.88, 0.94)
	else:
		visual ["bg"] = Color(0.11, 0.062, 0.068, 0.97)
		visual ["border"] = Color(1.0, 0.56, 0.48, 0.78)
		visual ["font"] = Color(1.0, 0.92, 0.9, 1.0)
		visual ["description_font"] = Color(1.0, 0.82, 0.8, 0.94)

	if store_id == "goldleaf_grocers" or food_id.begins_with("goldleaf_"):
		visual ["bg"] = Color(0.118, 0.082, 0.04, 0.98)
		visual ["border"] = Color(1.0, 0.84, 0.36, 0.94)
		visual ["font"] = Color(1.0, 0.96, 0.82, 1.0)
		visual ["description_font"] = Color(0.98, 0.88, 0.66, 0.96)
		visual ["border_width"] = 3
		visual ["pulse_glow"] = true
		visual ["pulse_tint"] = Color(1.0, 0.92, 0.54, 1.0)
		visual ["pulse_seconds"] = 0.74

	if food_id == "acrellos_cereal" or label_text.find("acrello") >= 0:
		visual ["orbit_color"] = Color(0.68, 0.34, 1.0, 1.0)
		visual ["orbit_seconds"] = 2.1
		visual ["border_width"] = max(int(visual.get("border_width", 2)), 3)

	if food_id.find("fatcakes") >= 0 or label_text.find("fatcakes") >= 0:
		visual ["orbit_color"] = Color(1.0, 0.42, 0.74, 1.0)
		visual ["orbit_seconds"] = 1.9
		visual ["border_width"] = max(int(visual.get("border_width", 2)), 3)

	return visual


static func _contract_brighten_color(color: Color, amount: float = 0.04) -> Color:
	return Color(
		clamp(color.r + amount, 0.0, 1.0),
		clamp(color.g + amount, 0.0, 1.0),
		clamp(color.b + amount, 0.0, 1.0),
		color.a
	)


static func _contract_darken_color(color: Color, amount: float = 0.04) -> Color:
	return Color(
		clamp(color.r - amount, 0.0, 1.0),
		clamp(color.g - amount, 0.0, 1.0),
		clamp(color.b - amount, 0.0, 1.0),
		color.a
	)


static func _career_contract_route_result(
	report: Dictionary
) -> Dictionary:
	if report.is_empty():
		return {}

	var cursor: Dictionary = report.duplicate(true)

	for _index in range(10):
		if cursor.has(
			"career_panel_contract"
		):
			return cursor

		var advanced: bool = false

		for key in [
			"route_report",
			"result",
			"engine_report",
			"target_report",
			"commit_report",
			"command_report",
			"payload"
		]:
			var nested_raw: Variant = cursor.get(
				key,
				{}
			)

			if typeof(nested_raw) != TYPE_DICTIONARY:
				continue

			var nested: Dictionary = (
				nested_raw as Dictionary
			).duplicate(true)

			if nested.is_empty():
				continue

			cursor = nested
			advanced = true
			break

		if not advanced:
			break

	return {}


static func _grocery_aisle_carousel_direction_from_route(action: Dictionary, report: Dictionary) -> int:
	var report_direction: int = int(report.get("aisle_slide_direction", 0))
	if report_direction < 0:
		return -1
	if report_direction > 0:
		return 1

	var action_style: String = str(action.get("style", "")).strip_edges().to_lower()
	if action_style == "secondary":
		return -1
	if action_style == "primary":
		return 1

	return 1


static func _should_use_grocery_aisle_carousel_transition(surface_id: String, action_id: String, report: Dictionary) -> bool:
	if str(surface_id).strip_edges() != "food_contract_hub":
		return false

	if not str(action_id).strip_edges().begins_with("grocery_aisle:"):
		return false

	if str(report.get("target_section", report.get("active_section_id", ""))).strip_edges() != "aisles":
		return false

	return true


static func _grocery_aisle_display_name_for_popup(aisle_id: String) -> String:
	var clean_aisle_id: String = str(aisle_id).strip_edges()
	if clean_aisle_id == "":
		return "Aisle"
	return clean_aisle_id.replace("_", " ").capitalize()


static func _grocery_clear_popup_grid(grid: Control) -> void:
	if grid == null or not is_instance_valid(grid):
		return

	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()


static func _life_diary_year_header_text(
	line: String
) -> String:
	var clean_line: String = str(
		line
	).strip_edges()

	if clean_line.begins_with("Year: "):
		return clean_line.substr(
			6
		).strip_edges()

	return clean_line


static func _append_avatar_four_elements_phrase(target_label: RichTextLabel, phrase: String) -> void:
	if target_label == null:
		return

	var colors: Array = [
		Color(1.0, 0.28, 0.12, 1.0),
		Color(0.25, 0.62, 1.0, 1.0),
		Color(0.45, 0.78, 0.34, 1.0),
		Color(0.82, 0.94, 1.0, 1.0)
	]

	var color_index: int = 0
	for i in range(str(phrase).length()):
		var ch: String = str(phrase).substr(i, 1)
		if ch == " ":
			target_label.append_text(" ")
			continue

		var color: Color = colors [color_index % colors.size()]
		target_label.append_text("[color=#%s]%s[/color]" % [
			color.to_html(false),
			ch
		])
		color_index += 1


static func _append_stone_colored_text_to_rich_label(
	target_label: RichTextLabel,
	text: String,
	append_newline: bool = true
) -> void:
	if target_label == null:
		return
	var stone_colors: Dictionary = {
		"Mind Stone": Color(1.0, 0.92, 0.22, 1.0),
		"Space Stone": Color(0.3, 0.58, 1.0, 1.0),
		"Reality Stone": Color(1.0, 0.26, 0.34, 1.0),
		"Power Stone": Color(0.7, 0.4, 1.0, 1.0),
		"Time Stone": Color(0.24, 0.92, 0.46, 1.0),
		"Soul Stone": Color(1.0, 0.58, 0.16, 1.0)
	}
	var ordered_names: Array = [
		"Reality Stone",
		"Space Stone",
		"Mind Stone",
		"Power Stone",
		"Time Stone",
		"Soul Stone"
	]
	var cursor: int = 0
	while cursor < text.length():
		var nearest_name: String = ""
		var nearest_index: int = -1
		for stone_name_value in ordered_names:
			var stone_name: String = str(stone_name_value)
			var idx: int = text.find(stone_name, cursor)
			if idx == -1:
				continue
			if nearest_index == -1 or idx < nearest_index:
				nearest_index = idx
				nearest_name = stone_name
		if nearest_index == -1:
			var tail_text: String = text.substr(cursor)
			if tail_text != "":
				target_label.append_text(tail_text)
			if append_newline:
				target_label.append_text("\n")
			return
		if nearest_index > cursor:
			target_label.append_text(text.substr(cursor, nearest_index - cursor))
		target_label.push_color(stone_colors.get(nearest_name, Color(1.0, 1.0, 1.0, 1.0)))
		target_label.push_bold()
		target_label.append_text(nearest_name)
		target_label.pop()
		target_label.pop()
		cursor = nearest_index + nearest_name.length()
	if append_newline:
		target_label.append_text("\n")


static func _collect_runtime_focusable_controls(root: Node, out: Array) -> void:
	if root == null:
		return

	if root is Control:
		var control:= root as Control
		if control.is_visible_in_tree() and control.focus_mode != Control.FOCUS_NONE:
			if not bool(control.get("disabled")):
				out.append(control)

	for child in root.get_children():
		_collect_runtime_focusable_controls(child, out)


static func _ui_nav_button_variant_for_key(key: String) -> String:
	return "priority" if key == "age_up" else "standard"


static func _era_surface_theme_data(theme_key: String, surface_kind: String = "main") -> Dictionary:
	if surface_kind == "player_stats":
		match theme_key:
			"ancient":
				return {
					"bg": Color(0.48, 0.38, 0.28, 0.97),
					"hover_bg": Color(0.54, 0.42, 0.31, 0.99),
					"border": Color(1.0, 0.9, 0.7, 0.28),
					"hover_border": Color(1.0, 0.95, 0.78, 0.42),
					"glow": Color(1.0, 0.88, 0.6, 0.12),
					"hover_glow": Color(1.0, 0.92, 0.7, 0.18),
					"glow_size": 12,
					"hover_glow_size": 18,
					"radius": 18,
					"margin": 8
				}
			"medieval":
				return {
					"bg": Color(0.2, 0.23, 0.28, 0.97),
					"hover_bg": Color(0.24, 0.28, 0.33, 0.99),
					"border": Color(0.92, 0.96, 1.0, 0.3),
					"hover_border": Color(0.98, 0.99, 1.0, 0.42),
					"glow": Color(0.92, 0.96, 1.0, 0.1),
					"hover_glow": Color(0.98, 0.99, 1.0, 0.16),
					"glow_size": 10,
					"hover_glow_size": 16,
					"radius": 18,
					"margin": 8
				}
			"future":
				return {
					"bg": Color(0.12, 0.2, 0.26, 0.98),
					"hover_bg": Color(0.16, 0.25, 0.31, 1.0),
					"border": Color(0.76, 0.94, 1.0, 0.3),
					"hover_border": Color(0.88, 0.98, 1.0, 0.44),
					"glow": Color(0.66, 0.98, 1.0, 0.12),
					"hover_glow": Color(0.86, 1.0, 1.0, 0.18),
					"glow_size": 12,
					"hover_glow_size": 18,
					"radius": 18,
					"margin": 8
				}
			_:
				return {
					"bg": Color(0.18, 0.3, 0.78, 0.96),
					"hover_bg": Color(0.24, 0.38, 0.9, 0.98),
					"border": Color(0.94, 0.98, 1.0, 0.3),
					"hover_border": Color(1.0, 1.0, 1.0, 0.46),
					"glow": Color(1.0, 1.0, 1.0, 0.14),
					"hover_glow": Color(1.0, 1.0, 1.0, 0.22),
					"glow_size": 20,
					"hover_glow_size": 28,
					"radius": 18,
					"margin": 8
				}

	match theme_key:
		"ancient":
			return {
				"bg": Color(0.34, 0.28, 0.22, 0.9),
				"hover_bg": Color(0.4, 0.32, 0.24, 0.94),
				"border": Color(0.96, 0.82, 0.58, 0.12),
				"hover_border": Color(1.0, 0.88, 0.64, 0.2),
				"glow": Color(1.0, 0.8, 0.48, 0.03),
				"hover_glow": Color(1.0, 0.82, 0.52, 0.06),
				"glow_size": 4,
				"hover_glow_size": 7,
				"radius": 14,
				"margin": 10
			}
		"medieval":
			return {
				"bg": Color(0.12, 0.14, 0.17, 0.9),
				"hover_bg": Color(0.16, 0.18, 0.22, 0.94),
				"border": Color(0.9, 0.94, 0.99, 0.16),
				"hover_border": Color(0.96, 0.98, 1.0, 0.24),
				"glow": Color(0.88, 0.94, 1.0, 0.02),
				"hover_glow": Color(0.94, 0.98, 1.0, 0.04),
				"glow_size": 4,
				"hover_glow_size": 6,
				"radius": 14,
				"margin": 10
			}
		"future":
			return {
				"bg": Color(0.08, 0.13, 0.18, 0.92),
				"hover_bg": Color(0.1, 0.16, 0.22, 0.96),
				"border": Color(0.62, 0.86, 0.96, 0.14),
				"hover_border": Color(0.74, 0.92, 1.0, 0.22),
				"glow": Color(0.36, 0.96, 1.0, 0.04),
				"hover_glow": Color(0.54, 0.98, 1.0, 0.08),
				"glow_size": 5,
				"hover_glow_size": 9,
				"radius": 14,
				"margin": 10
			}
		_:
			return {
				"bg": Color(0.05, 0.09, 0.18, 0.84),
				"hover_bg": Color(0.08, 0.15, 0.3, 0.9),
				"border": Color(1.0, 1.0, 1.0, 0.14),
				"hover_border": Color(1.0, 1.0, 1.0, 0.26),
				"glow": Color(1.0, 1.0, 1.0, 0.08),
				"hover_glow": Color(1.0, 1.0, 1.0, 0.18),
				"glow_size": 8,
				"hover_glow_size": 14,
				"radius": 14,
				"margin": 10
			}


static func _player_stat_row_phase_offset(title: String) -> float:
	match title:
		"Health":
			return 0.15
		"Mental":
			return 0.85
		"Happiness":
			return 1.55
		"Smarts":
			return 2.2
		"Looks":
			return 2.95
		"Fame":
			return 3.6
		_:
			return 0.0


static func _saved_lives_dir() -> String:
	return "user://saved_lives"


static func _safe_modal_z_index(raw_value: int, fallback_value: int = 950) -> int:
	var min_z: int = -2048
	var max_z: int = 2048
	var desired_z: int = max(int(raw_value), int(fallback_value))
	return int(clamp(desired_z, min_z, max_z))


static func _result_is_red_bonnet_dragonball_spectator_packet(result: Dictionary) -> bool:
	if typeof(result) != TYPE_DICTIONARY or result.is_empty():
		return false

	var source_text: String = str(result.get("source", result.get("action_source", ""))).strip_edges().to_lower()
	var theme_text: String = str(result.get("theme", "")).strip_edges().to_lower()
	var title_text: String = str(result.get("popup_title", result.get("title", ""))).strip_edges().to_lower()
	var text_blob: String = str(result.get("popup_text", result.get("text", ""))).strip_edges().to_lower()

	if theme_text == "dragonball" or theme_text == "dragonballs":
		return true

	if source_text.find("red_bonnet") != -1 and source_text.find("dragon") != -1:
		return true

	if title_text.find("dragon ball") != -1:
		return true

	if text_blob.find("dragon ball") != -1 and text_blob.find("red bonnet") != -1:
		return true

	if typeof(result.get("dragonball_arrival_animation", {})) == TYPE_DICTIONARY:
		var arrival_packet: Dictionary = result.get("dragonball_arrival_animation", {}) as Dictionary
		if bool(arrival_packet.get("active", false)):
			return true

	return false


static func _ensure_saved_lives_dir() -> void:
	var root:= DirAccess.open("user://")
	if root == null:
		return
	if not root.dir_exists("saved_lives"):
		root.make_dir("saved_lives")


static func _sanitize_save_slot_component(text: String) -> String:
	var cleaned:= text.strip_edges().to_lower()
	for ch in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|", " "]:
		cleaned = cleaned.replace(ch, "_")
	while cleaned.find("__") != -1:
		cleaned = cleaned.replace("__", "_")
	if cleaned == "":
		cleaned = "life"
	return cleaned


static func _install_zero_frame_scroll_passthrough(root: Node) -> void:
	if root == null:
		return
	if not is_instance_valid(root):
		return

	for raw_child in root.get_children():
		var child:= raw_child as Node
		if child == null:
			continue

		if child is ScrollContainer:
			var nested_scroll:= child as ScrollContainer
			nested_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
			nested_scroll.follow_focus = false
			nested_scroll.scroll_deadzone = 0
			continue

		if child is RichTextLabel:
			var rich:= child as RichTextLabel
			rich.mouse_filter = Control.MOUSE_FILTER_PASS
			rich.scroll_active = false
		elif child is Button:
			var button:= child as Button
			button.mouse_filter = Control.MOUSE_FILTER_STOP
			button.focus_mode = Control.FOCUS_ALL
		elif child is Label:
			var label:= child as Label
			label.mouse_filter = Control.MOUSE_FILTER_PASS
		elif child is Control:
			var control:= child as Control
			if control.mouse_filter == Control.MOUSE_FILTER_IGNORE:
				control.mouse_filter = Control.MOUSE_FILTER_PASS

		_install_zero_frame_scroll_passthrough(child)


static func _zero_frame_scroll_step(scroll: ScrollContainer) -> float:
	if scroll == null:
		return 68.0

	var vbar:= scroll.get_v_scroll_bar()
	if vbar == null:
		return 68.0

	return max(68.0, float(vbar.page) * 0.28)


static func _zero_frame_trackpad_scroll_multiplier(scroll: ScrollContainer) -> float:
	if scroll == null:
		return 96.0

	var vbar:= scroll.get_v_scroll_bar()
	if vbar == null:
		return 96.0

	return max(84.0, float(vbar.page) * 0.42)


static func _zero_frame_scroll_by(scroll: ScrollContainer, amount: float) -> void:
	if scroll == null:
		return
	if not is_instance_valid(scroll):
		return

	var vbar:= scroll.get_v_scroll_bar()
	if vbar == null:
		return

	var target_value: float = clamp(
		float(vbar.value) + amount,
		float(vbar.min_value),
		float(vbar.max_value)
	)

	vbar.value = target_value
	scroll.set_meta("zero_frame_scroll_last_input_ms", int(Time.get_ticks_msec()))
	scroll.set_meta("zero_frame_scroll_used_touchpad_or_wheel", true)
	scroll.queue_redraw()


static func _spawn_ready_runtime_hud_hydration_methods() -> Array:


	return []


static func _checkpoint_resume_contract_from_load_options(
	load_options: Dictionary
) -> Dictionary:
	var direct_raw: Variant = load_options.get(
		"checkpoint_resume_contract",
		{}
	)

	if typeof(direct_raw) == TYPE_DICTIONARY:
		var direct_contract: Dictionary = (
			direct_raw as Dictionary
		)

		if not direct_contract.is_empty():
			return direct_contract.duplicate(false)

	var continue_raw: Variant = load_options.get(
		"continue_contract",
		{}
	)
	var continue_contract: Dictionary = (
		continue_raw as Dictionary
		if typeof(continue_raw) == TYPE_DICTIONARY
		else {}
	)
	var continue_resume_raw: Variant = continue_contract.get(
		"checkpoint_resume_contract",
		{}
	)

	if typeof(continue_resume_raw) == TYPE_DICTIONARY:
		var continue_resume: Dictionary = (
			continue_resume_raw as Dictionary
		)

		if not continue_resume.is_empty():
			return continue_resume.duplicate(false)

	var life_summary_raw: Variant = continue_contract.get(
		"life_summary",
		{}
	)
	var life_summary: Dictionary = (
		life_summary_raw as Dictionary
		if typeof(life_summary_raw) == TYPE_DICTIONARY
		else {}
	)
	var summary_resume_raw: Variant = life_summary.get(
		"checkpoint_resume_contract",
		{}
	)

	if typeof(summary_resume_raw) == TYPE_DICTIONARY:
		var summary_resume: Dictionary = (
			summary_resume_raw as Dictionary
		)

		if not summary_resume.is_empty():
			return summary_resume.duplicate(false)

	return {}


static func _saved_life_residency_signature(
	path: String
) -> String:
	var clean_path: String = str(
		path
	).strip_edges()

	if clean_path == "":
		return ""

	var modified_at: int = int(
		FileAccess.get_modified_time(
			clean_path
		)
	)
	var signature_hash: int = abs(
		hash(
			"%s|%d|resident_checkpoint"
			% [
				clean_path,
				modified_at
			]
		)
	)

	return "checkpoint:%d" % signature_hash


static func _boxing_hub_rankings_division_carousel_style(visual_contract: Dictionary) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.06, 0.07, 0.72)
	style.border_color = Color(1.0, 0.68, 0.34, 0.74)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.shadow_color = visual_contract.get("shadow_accent", Color(1.0, 0.32, 0.08, 0.2))
	style.shadow_size = 8
	style.content_margin_left = 10
	style.content_margin_top = 8
	style.content_margin_right = 10
	style.content_margin_bottom = 8
	return style


static func _boxing_entry_weight_classes() -> Array:
	return [
		"Flyweight",
		"Bantamweight",
		"Featherweight",
		"Lightweight",
		"Welterweight",
		"Middleweight",
		"Light Heavyweight",
		"Heavyweight"
	]


static func _boxing_entry_gender_division_for_actor(actor: Person) -> String:
	if actor == null:
		return "Male"

	var gender_text: String = str(actor.gender if "gender" in actor else "").strip_edges().to_lower()
	if gender_text in ["female", "woman", "girl", "f"]:
		return "Female"

	return "Male"


static func _boxing_entry_popup_style() -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.038, 0.026, 0.97)
	style.border_color = Color(1.0, 0.67, 0.32, 0.92)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 24
	style.corner_radius_top_right = 24
	style.corner_radius_bottom_left = 24
	style.corner_radius_bottom_right = 24
	style.shadow_color = Color(1.0, 0.44, 0.12, 0.34)
	style.shadow_size = 18
	style.content_margin_left = 24
	style.content_margin_top = 22
	style.content_margin_right = 24
	style.content_margin_bottom = 22
	return style


static func _boxing_entry_button_style(accent: Color = Color(1.0, 0.58, 0.22, 1.0)) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(accent.r * 0.2, accent.g * 0.16, accent.b * 0.1, 0.92)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.86)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.shadow_color = Color(accent.r, accent.g * 0.7, accent.b * 0.45, 0.2)
	style.shadow_size = 8
	style.content_margin_left = 14
	style.content_margin_top = 12
	style.content_margin_right = 14
	style.content_margin_bottom = 12
	return style


static func _boxing_title_body_from_label(title_label: String) -> String:
	var clean_label: String = str(title_label).strip_edges().to_upper()

	if clean_label.find("WBC") >= 0:
		return "WBC"
	if clean_label.find("WBA") >= 0:
		return "WBA"
	if clean_label.find("IBF") >= 0:
		return "IBF"
	if clean_label.find("WBO") >= 0:
		return "WBO"
	if clean_label.find("RING") >= 0 or clean_label.find("LINEAL") >= 0:
		return "RING"

	return ""


static func _boxing_belt_visual_contract_for_body(body: String) -> Dictionary:
	var clean_body: String = str(body).strip_edges().to_upper()

	match clean_body:
		"WBC":
			return {
				"body": "WBC",
				"short": "WBC",
				"emoji": "🟢",
				"aura_tag": "green_glory",
				"bg": Color(0.015, 0.13, 0.06, 0.96),
				"core": Color(0.18, 1.0, 0.42, 1.0),
				"border": Color(0.25, 1.0, 0.52, 0.96),
				"glow_primary": Color(0.13, 1.0, 0.42, 0.62),
				"glow_secondary": Color(0.54, 1.0, 0.72, 0.28),
				"text": Color(0.86, 1.0, 0.9, 1.0)
			}
		"WBA":
			return {
				"body": "WBA",
				"short": "WBA",
				"emoji": "🔴",
				"aura_tag": "maroon_bloodline",
				"bg": Color(0.145, 0.018, 0.04, 0.96),
				"core": Color(0.76, 0.06, 0.16, 1.0),
				"border": Color(0.98, 0.22, 0.3, 0.92),
				"glow_primary": Color(0.98, 0.09, 0.18, 0.52),
				"glow_secondary": Color(0.52, 0.02, 0.08, 0.38),
				"text": Color(1.0, 0.88, 0.9, 1.0)
			}
		"IBF":
			return {
				"body": "IBF",
				"short": "IBF",
				"emoji": "🟡",
				"aura_tag": "gold_standard",
				"bg": Color(0.19, 0.125, 0.02, 0.96),
				"core": Color(1.0, 0.82, 0.24, 1.0),
				"border": Color(1.0, 0.9, 0.42, 0.94),
				"glow_primary": Color(1.0, 0.78, 0.22, 0.56),
				"glow_secondary": Color(1.0, 0.96, 0.56, 0.28),
				"text": Color(1.0, 0.96, 0.76, 1.0)
			}
		"WBO":
			return {
				"body": "WBO",
				"short": "WBO",
				"emoji": "⚫",
				"aura_tag": "black_gold_red_crown",
				"bg": Color(0.01, 0.01, 0.014, 0.98),
				"core": Color(0.02, 0.018, 0.018, 1.0),
				"border": Color(1.0, 0.76, 0.2, 0.92),
				"glow_primary": Color(1.0, 0.72, 0.16, 0.5),
				"glow_secondary": Color(1.0, 0.1, 0.08, 0.45),
				"text": Color(1.0, 0.89, 0.58, 1.0)
			}
		"RING":
			return {
				"body": "RING",
				"short": "Ring",
				"emoji": "💍",
				"aura_tag": "lineal_silver",
				"bg": Color(0.06, 0.07, 0.09, 0.96),
				"core": Color(0.79, 0.88, 1.0, 1.0),
				"border": Color(0.86, 0.93, 1.0, 0.88),
				"glow_primary": Color(0.58, 0.74, 1.0, 0.42),
				"glow_secondary": Color(1.0, 1.0, 1.0, 0.18),
				"text": Color(0.92, 0.96, 1.0, 1.0)
			}
		_:
			return {
				"body": clean_body,
				"short": clean_body,
				"emoji": "🏆",
				"aura_tag": "generic_title",
				"bg": Color(0.105, 0.075, 0.025, 0.94),
				"core": Color(1.0, 0.76, 0.24, 1.0),
				"border": Color(1.0, 0.86, 0.4, 0.84),
				"glow_primary": Color(1.0, 0.76, 0.24, 0.34),
				"glow_secondary": Color(1.0, 0.94, 0.62, 0.18),
				"text": Color(1.0, 0.94, 0.76, 1.0)
			}


static func _boxing_blend_color_list(colors: Array, fallback: Color) -> Color:
	if colors.is_empty():
		return fallback

	var r: float = 0.0
	var g: float = 0.0
	var b: float = 0.0
	var a: float = 0.0

	for raw_color in colors:
		if typeof(raw_color) != TYPE_COLOR:
			continue

		var color: Color = raw_color
		r += color.r
		g += color.g
		b += color.b
		a += color.a

	var count: float = float(max(1, colors.size()))
	return Color(r / count, g / count, b / count, clamp(a / count, 0.0, 1.0))


static func _boxing_belt_chip_style(visual: Dictionary, secondary_layer: bool = false) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_left = 9
	style.corner_radius_bottom_right = 9
	style.content_margin_left = 7
	style.content_margin_top = 3
	style.content_margin_right = 7
	style.content_margin_bottom = 3
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1

	style.bg_color = visual.get("bg", Color(0.105, 0.075, 0.025, 0.94))
	style.border_color = visual.get("border", Color(1.0, 0.86, 0.4, 0.84))
	style.shadow_color = visual.get("glow_secondary", visual.get("glow_primary", Color(1.0, 0.76, 0.24, 0.22))) if secondary_layer else visual.get("glow_primary", Color(1.0, 0.76, 0.24, 0.28))
	style.shadow_size = 8 if secondary_layer else 5

	return style


static func _boxing_hub_fame_fill_color(fame_value: float, is_champion: bool, rank_heat: float) -> Color:
	var clean_fame: float = clamp(fame_value, 0.0, 100.0)

	if clean_fame < 30.0:
		return Color(1.0, 0.16, 0.12, 0.92)

	if is_champion or clean_fame >= 70.0:
		return Color(1.0, 0.86, 0.22, 0.96)

	return Color(1.0, 0.68 + rank_heat * 0.12, 0.24, 0.88)


static func _boxing_hub_athleticism_panel_style(visual_contract: Dictionary) -> StyleBoxFlat:
	var base: Color = visual_contract.get("base", Color(0.03, 0.026, 0.022, 0.99))
	var accent: Color = visual_contract.get("accent", Color(1.0, 0.56, 0.2, 1.0))

	var sb:= StyleBoxFlat.new()
	sb.bg_color = Color(base.r, base.g, base.b, 0.46)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.58)
	sb.set_border_width_all(1)
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_left = 16
	sb.corner_radius_bottom_right = 16
	sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.18)
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(0, 4)
	return sb


static func _boxing_hub_athleticism_bar_background_style(visual_contract: Dictionary) -> StyleBoxFlat:
	var panel: Color = visual_contract.get("panel", Color(0.055, 0.044, 0.036, 0.97))

	var sb:= StyleBoxFlat.new()
	sb.bg_color = Color(panel.r, panel.g, panel.b, 0.7)
	sb.border_color = Color(1.0, 1.0, 1.0, 0.1)
	sb.set_border_width_all(1)
	sb.corner_radius_top_left = 999
	sb.corner_radius_top_right = 999
	sb.corner_radius_bottom_left = 999
	sb.corner_radius_bottom_right = 999
	return sb


static func _boxing_hub_athleticism_bar_fill_style(visual_contract: Dictionary, value: int) -> StyleBoxFlat:
	var accent: Color = visual_contract.get("accent", Color(1.0, 0.56, 0.2, 1.0))
	var hot: Color = visual_contract.get("hot", Color(1.0, 0.82, 0.38, 1.0))
	var clean_value: int = clamp(value, 0, 100)

	var fill_color: Color = Color(accent.r, accent.g, accent.b, 0.82)
	if clean_value >= 80:
		fill_color = Color(hot.r, hot.g, hot.b, 0.92)
	elif clean_value <= 35:
		fill_color = Color(1.0, 0.22, 0.12, 0.82)

	var sb:= StyleBoxFlat.new()
	sb.bg_color = fill_color
	sb.border_color = Color(1.0, 1.0, 1.0, 0.18)
	sb.set_border_width_all(1)
	sb.corner_radius_top_left = 999
	sb.corner_radius_top_right = 999
	sb.corner_radius_bottom_left = 999
	sb.corner_radius_bottom_right = 999
	sb.shadow_color = Color(fill_color.r, fill_color.g, fill_color.b, 0.28)
	sb.shadow_size = 7
	sb.shadow_offset = Vector2.ZERO
	return sb


static func _boxing_hub_athleticism_value_color(value: int, visual_contract: Dictionary) -> Color:
	var clean_value: int = clamp(value, 0, 100)

	if clean_value >= 80:
		return visual_contract.get("hot", Color(1.0, 0.82, 0.38, 1.0))

	if clean_value <= 35:
		return Color(1.0, 0.22, 0.12, 1.0)

	return visual_contract.get("body_text", Color(0.96, 0.97, 1.0, 0.94))


static func _boxing_hub_growth_box_gap() -> float:
	return 2.0


static func _boxing_hub_growth_skill_label_width() -> float:
	return 250.0


static func _boxing_hub_growth_cost_column_width() -> float:
	return 82.0


static func _boxing_hub_growth_header_label(text: String, min_width: float, visual_contract: Dictionary, expand: bool = false) -> Label:
	var label:= Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", visual_contract.get("title", Color(1.0, 0.9, 0.66, 1.0)))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)

	if expand:
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		label.custom_minimum_size = Vector2(min_width, 24)

	if text == "XP COST":
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	elif expand:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	return label


static func _boxing_hub_apply_growth_invisible_scroll(scroll: ScrollContainer) -> void:
	if scroll == null or not is_instance_valid(scroll):
		return

	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = false
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP

	var vbar:= scroll.get_v_scroll_bar()
	if vbar == null:
		return

	vbar.step = 1.0
	vbar.custom_minimum_size = Vector2(0, 0)
	vbar.modulate = Color(1.0, 1.0, 1.0, 0.0)
	vbar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var transparent:= StyleBoxFlat.new()
	transparent.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	transparent.border_color = Color(0.0, 0.0, 0.0, 0.0)
	transparent.set_border_width_all(0)
	transparent.shadow_size = 0

	vbar.add_theme_stylebox_override("scroll", transparent)
	vbar.add_theme_stylebox_override("scroll_focus", transparent)
	vbar.add_theme_stylebox_override("grabber", transparent)
	vbar.add_theme_stylebox_override("grabber_highlight", transparent)
	vbar.add_theme_stylebox_override("grabber_pressed", transparent)


static func _boxing_hub_growth_cost_text_for_row(skill_row: Dictionary) -> String:
	var current_level: int = int(skill_row.get("current_level", 0))
	var max_level: int = int(skill_row.get("max_level", 20))
	var next_cost: int = int(skill_row.get("next_cost", 0))
	var xp: int = int(skill_row.get("xp", 0))
	var remaining_total_slots: int = int(skill_row.get("remaining_total_slots", 0))

	if current_level >= max_level:
		return "MAX"

	if remaining_total_slots <= 0:
		return "CAP"

	if xp < next_cost:
		return "%d" % next_cost

	return "%d" % next_cost


static func _boxing_hub_growth_cost_color_for_row(skill_row: Dictionary, visual_contract: Dictionary) -> Color:
	var current_level: int = int(skill_row.get("current_level", 0))
	var max_level: int = int(skill_row.get("max_level", 20))
	var next_cost: int = int(skill_row.get("next_cost", 0))
	var xp: int = int(skill_row.get("xp", 0))
	var remaining_total_slots: int = int(skill_row.get("remaining_total_slots", 0))

	if current_level >= max_level:
		return Color(0.3, 1.0, 0.46, 1.0)

	if remaining_total_slots <= 0:
		return visual_contract.get("muted_text", Color(0.86, 0.9, 0.98, 0.8))

	if xp < next_cost:
		return visual_contract.get("muted_text", Color(0.86, 0.9, 0.98, 0.8))

	return visual_contract.get("title", Color(1.0, 0.9, 0.66, 1.0))


static func _boxing_hub_growth_board_style(visual_contract: Dictionary) -> StyleBoxFlat:
	var base: Color = visual_contract.get("base", Color(0.03, 0.026, 0.022, 0.99))
	var accent: Color = visual_contract.get("accent", Color(1.0, 0.56, 0.2, 1.0))

	var sb:= StyleBoxFlat.new()
	sb.bg_color = Color(base.r, base.g, base.b, 0.46)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.56)
	sb.set_border_width_all(1)
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 14
	sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.16)
	sb.shadow_size = 16
	sb.shadow_offset = Vector2(0, 4)
	return sb


static func _boxing_hub_growth_row_style(visual_contract: Dictionary, alternate: bool = false) -> StyleBoxFlat:
	var panel: Color = visual_contract.get("panel", Color(0.055, 0.044, 0.036, 0.97))
	var accent: Color = visual_contract.get("accent", Color(1.0, 0.56, 0.2, 1.0))

	var alpha: float = 0.38 if alternate else 0.28

	var sb:= StyleBoxFlat.new()
	sb.bg_color = Color(panel.r, panel.g, panel.b, alpha)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.1)
	sb.set_border_width_all(1)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	return sb


static func _boxing_hub_growth_level_box_style(visual_contract: Dictionary, state: String) -> StyleBoxFlat:
	var clean_state: String = str(state).strip_edges().to_lower()
	var hover: bool = clean_state.ends_with("_hover")
	var pressed: bool = clean_state.ends_with("_pressed")
	clean_state = clean_state.replace("_hover", "").replace("_pressed", "")

	var accent: Color = visual_contract.get("accent", Color(1.0, 0.56, 0.2, 1.0))
	var hot: Color = visual_contract.get("hot", Color(1.0, 0.82, 0.38, 1.0))

	var bg: Color = Color(0.2, 0.23, 0.23, 0.58)
	var border: Color = Color(0.58, 0.64, 0.62, 0.62)
	var shadow: Color = Color(0.0, 0.0, 0.0, 0.14)
	var border_width: int = 1

	match clean_state:
		"filled":
			bg = Color(0.0, 0.84, 0.2, 0.98)
			border = Color(0.42, 1.0, 0.52, 0.92)
			shadow = Color(0.0, 1.0, 0.24, 0.22)
		"available":
			bg = Color(0.12, 0.18, 0.13, 0.62)
			border = Color(accent.r, accent.g, accent.b, 0.7)
			shadow = Color(accent.r, accent.g, accent.b, 0.14)
		"locked":
			bg = Color(0.18, 0.2, 0.2, 0.48)
			border = Color(0.58, 0.64, 0.62, 0.54)
			shadow = Color(0.0, 0.0, 0.0, 0.16)
		"blocked_flash":
			bg = Color(0.42, 0.08, 0.055, 0.78)
			border = Color(1.0, 0.12, 0.08, 1.0)
			shadow = Color(1.0, 0.06, 0.02, 0.42)
			border_width = 2

	if hover:
		if clean_state == "filled":
			bg = Color(0.08, 1.0, 0.3, 1.0)
			border = Color(0.72, 1.0, 0.76, 1.0)
			shadow = Color(0.0, 1.0, 0.3, 0.3)
		elif clean_state == "available":
			bg = Color(accent.r, accent.g, accent.b, 0.3)
			border = Color(hot.r, hot.g, hot.b, 0.96)
			shadow = Color(hot.r, hot.g, hot.b, 0.26)
		elif clean_state == "locked":
			bg = Color(0.22, 0.24, 0.24, 0.58)
			border = Color(0.74, 0.78, 0.76, 0.78)
			shadow = Color(0.0, 0.0, 0.0, 0.2)
		border_width = 2

	if pressed:
		if clean_state == "available":
			bg = Color(hot.r, hot.g, hot.b, 0.4)
			border = Color(1.0, 1.0, 0.92, 1.0)
			shadow = Color(hot.r, hot.g, hot.b, 0.3)
		elif clean_state == "locked":
			bg = Color(0.24, 0.25, 0.25, 0.64)
			border = Color(0.82, 0.86, 0.84, 0.84)
		border_width = 2

	var sb:= StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.corner_radius_top_left = 3
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3
	sb.corner_radius_bottom_right = 3
	sb.shadow_color = shadow
	sb.shadow_size = 5
	sb.shadow_offset = Vector2.ZERO
	sb.content_margin_left = 0
	sb.content_margin_top = 0
	sb.content_margin_right = 0
	sb.content_margin_bottom = 0
	return sb


static func _boxing_hub_popup_style(visual_contract: Dictionary) -> StyleBoxFlat:
	var base: Color = visual_contract.get("base", Color(0.03, 0.026, 0.022, 0.99))

	var sb:= StyleBoxFlat.new()
	sb.bg_color = base
	sb.border_color = Color(0.0, 0.0, 0.0, 0.0)
	sb.set_border_width_all(0)
	sb.corner_radius_top_left = 0
	sb.corner_radius_top_right = 0
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.0)
	sb.shadow_size = 0
	sb.shadow_offset = Vector2.ZERO
	return sb


static func _boxing_hub_legacy_ladder_card_style(visual_contract: Dictionary) -> StyleBoxFlat:
	var base: Color = visual_contract.get("base", Color(0.03, 0.026, 0.022, 0.99))
	var accent: Color = visual_contract.get("accent", Color(1.0, 0.56, 0.2, 1.0))

	var sb:= StyleBoxFlat.new()
	sb.bg_color = Color(base.r, base.g, base.b, 0.42)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.44)
	sb.set_border_width_all(1)
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 14
	sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.18)
	sb.shadow_size = 18
	sb.shadow_offset = Vector2(0, 4)
	return sb


static func _boxing_hub_shell_style(visual_contract: Dictionary) -> StyleBoxFlat:
	var base: Color = visual_contract.get("base", Color(0.03, 0.026, 0.022, 0.99))
	var panel: Color = visual_contract.get("panel", Color(0.055, 0.044, 0.036, 0.97))
	var accent: Color = visual_contract.get("accent", Color(1.0, 0.56, 0.2, 1.0))

	var sb:= StyleBoxFlat.new()
	sb.bg_color = base.lerp(panel, 0.55)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.68)
	sb.set_border_width_all(2)
	sb.corner_radius_top_left = 28
	sb.corner_radius_top_right = 28
	sb.corner_radius_bottom_left = 28
	sb.corner_radius_bottom_right = 28
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.76)
	sb.shadow_size = 26
	sb.shadow_offset = Vector2(0, 8)
	sb.content_margin_left = 10
	sb.content_margin_top = 10
	sb.content_margin_right = 10
	sb.content_margin_bottom = 10
	return sb


static func _boxing_hub_tab_button_style(visual_contract: Dictionary, state: String = "normal") -> StyleBoxFlat:
	var panel: Color = visual_contract.get("panel", Color(0.055, 0.044, 0.036, 0.97))
	var accent: Color = visual_contract.get("accent", Color(1.0, 0.56, 0.2, 1.0))
	var hot: Color = visual_contract.get("hot", Color(1.0, 0.82, 0.38, 1.0))

	var bg: Color = Color(panel.r, panel.g, panel.b, 0.62)
	var border: Color = Color(accent.r, accent.g, accent.b, 0.22)
	var shadow: Color = Color(accent.r, accent.g, accent.b, 0.08)
	var border_width: int = 1

	match state:
		"hover":
			bg = Color(accent.r, accent.g, accent.b, 0.2)
			border = Color(accent.r, accent.g, accent.b, 0.66)
			shadow = Color(accent.r, accent.g, accent.b, 0.3)
			border_width = 2
		"selected":
			bg = Color(accent.r, accent.g, accent.b, 0.28)
			border = Color(hot.r, hot.g, hot.b, 0.88)
			shadow = Color(accent.r, accent.g, accent.b, 0.34)
			border_width = 2
		"selected_hover":
			bg = Color(accent.r, accent.g, accent.b, 0.38)
			border = Color(hot.r, hot.g, hot.b, 1.0)
			shadow = Color(hot.r, hot.g, hot.b, 0.42)
			border_width = 2
		"pressed":
			bg = Color(hot.r, hot.g, hot.b, 0.24)
			border = Color(hot.r, hot.g, hot.b, 1.0)
			shadow = Color(hot.r, hot.g, hot.b, 0.26)
			border_width = 2

	var sb:= StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.corner_radius_top_left = 999
	sb.corner_radius_top_right = 999
	sb.corner_radius_bottom_left = 999
	sb.corner_radius_bottom_right = 999
	sb.shadow_color = shadow
	sb.shadow_size = 12
	sb.shadow_offset = Vector2.ZERO
	sb.content_margin_left = 10
	sb.content_margin_top = 6
	sb.content_margin_right = 10
	sb.content_margin_bottom = 6
	return sb


static func _boxing_hub_action_button_style(visual_contract: Dictionary, state: String = "normal") -> StyleBoxFlat:
	var panel: Color = visual_contract.get("panel", Color(0.055, 0.044, 0.036, 0.97))
	var accent: Color = visual_contract.get("accent", Color(1.0, 0.56, 0.2, 1.0))
	var hot: Color = visual_contract.get("hot", Color(1.0, 0.82, 0.38, 1.0))

	var bg: Color = Color(panel.r, panel.g, panel.b, 0.72)
	var border: Color = Color(accent.r, accent.g, accent.b, 0.34)
	var shadow: Color = Color(0.0, 0.0, 0.0, 0.32)
	var border_width: int = 1

	match state:
		"hover":
			bg = Color(accent.r, accent.g, accent.b, 0.22)
			border = Color(hot.r, hot.g, hot.b, 0.9)
			shadow = Color(accent.r, accent.g, accent.b, 0.34)
			border_width = 2
		"pressed":
			bg = Color(hot.r, hot.g, hot.b, 0.26)
			border = Color(hot.r, hot.g, hot.b, 1.0)
			shadow = Color(hot.r, hot.g, hot.b, 0.28)
			border_width = 2

	var sb:= StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 14
	sb.shadow_color = shadow
	sb.shadow_size = 12
	sb.shadow_offset = Vector2(0, 4)
	sb.content_margin_left = 12
	sb.content_margin_top = 8
	sb.content_margin_right = 12
	sb.content_margin_bottom = 8
	return sb


static func _boxing_hub_close_button_style(visual_contract: Dictionary, state: String = "normal") -> StyleBoxFlat:
	var accent: Color = visual_contract.get("accent", Color(1.0, 0.56, 0.2, 1.0))
	var hot: Color = visual_contract.get("hot", Color(1.0, 0.82, 0.38, 1.0))

	var bg: Color = Color(0.05, 0.035, 0.025, 0.72)
	var border: Color = Color(accent.r, accent.g, accent.b, 0.78)
	var shadow: Color = Color(accent.r, accent.g, accent.b, 0.36)

	match state:
		"hover":
			bg = Color(accent.r, accent.g, accent.b, 0.26)
			border = Color(hot.r, hot.g, hot.b, 1.0)
			shadow = Color(hot.r, hot.g, hot.b, 0.56)
		"pressed":
			bg = Color(hot.r, hot.g, hot.b, 0.34)
			border = Color(1.0, 1.0, 1.0, 0.92)
			shadow = Color(hot.r, hot.g, hot.b, 0.36)

	var sb:= StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.corner_radius_top_left = 999
	sb.corner_radius_top_right = 999
	sb.corner_radius_bottom_left = 999
	sb.corner_radius_bottom_right = 999
	sb.shadow_color = shadow
	sb.shadow_size = 16
	sb.shadow_offset = Vector2.ZERO
	sb.content_margin_left = 8
	sb.content_margin_top = 8
	sb.content_margin_right = 8
	sb.content_margin_bottom = 8
	return sb


static func _boxing_hub_micro_card_style(visual_contract: Dictionary) -> StyleBoxFlat:
	var panel: Color = visual_contract.get("panel", Color(0.055, 0.044, 0.036, 0.97))
	var accent: Color = visual_contract.get("accent", Color(1.0, 0.56, 0.2, 1.0))

	var sb:= StyleBoxFlat.new()
	sb.bg_color = Color(panel.r, panel.g, panel.b, 0.72)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.28)
	sb.set_border_width_all(1)
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_left = 16
	sb.corner_radius_bottom_right = 16
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.26)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 3)
	return sb


static func _boxing_hub_style_scrollbar(scrollbar: VScrollBar, visual_contract: Dictionary) -> void:
	if scrollbar == null:
		return

	var base: Color = visual_contract.get("base", Color(0.03, 0.026, 0.022, 0.99))
	var accent: Color = visual_contract.get("accent", Color(1.0, 0.56, 0.2, 1.0))
	var hot: Color = visual_contract.get("hot", Color(1.0, 0.82, 0.38, 1.0))

	var track:= StyleBoxFlat.new()
	track.bg_color = Color(base.r, base.g, base.b, 0.08)
	track.border_color = Color(accent.r, accent.g, accent.b, 0.1)
	track.set_border_width_all(1)
	track.corner_radius_top_left = 999
	track.corner_radius_top_right = 999
	track.corner_radius_bottom_left = 999
	track.corner_radius_bottom_right = 999

	var grabber:= StyleBoxFlat.new()
	grabber.bg_color = Color(accent.r, accent.g, accent.b, 0.62)
	grabber.border_color = Color(hot.r, hot.g, hot.b, 0.72)
	grabber.set_border_width_all(1)
	grabber.corner_radius_top_left = 999
	grabber.corner_radius_top_right = 999
	grabber.corner_radius_bottom_left = 999
	grabber.corner_radius_bottom_right = 999
	grabber.shadow_color = Color(accent.r, accent.g, accent.b, 0.35)
	grabber.shadow_size = 10

	var grabber_hover:= grabber.duplicate() as StyleBoxFlat
	grabber_hover.bg_color = Color(hot.r, hot.g, hot.b, 0.86)
	grabber_hover.border_color = Color(1.0, 1.0, 1.0, 0.72)
	grabber_hover.shadow_color = Color(hot.r, hot.g, hot.b, 0.46)
	grabber_hover.shadow_size = 14

	var grabber_pressed:= grabber.duplicate() as StyleBoxFlat
	grabber_pressed.bg_color = Color(hot.r, hot.g, hot.b, 1.0)
	grabber_pressed.border_color = Color(1.0, 1.0, 1.0, 0.88)
	grabber_pressed.shadow_color = Color(hot.r, hot.g, hot.b, 0.38)
	grabber_pressed.shadow_size = 16

	scrollbar.add_theme_stylebox_override("scroll", track)
	scrollbar.add_theme_stylebox_override("scroll_focus", track)
	scrollbar.add_theme_stylebox_override("grabber", grabber)
	scrollbar.add_theme_stylebox_override("grabber_highlight", grabber_hover)
	scrollbar.add_theme_stylebox_override("grabber_pressed", grabber_pressed)


static func _artifact_shop_rarity_color(
	rarity: String
) -> Color:
	match rarity.strip_edges().to_lower():
		"common":
			return Color(
				0.64,
				0.66,
				0.72,
				1.0
			)

		"uncommon":
			return Color(
				0.36,
				0.9,
				0.48,
				1.0
			)

		"rare":
			return Color(
				0.28,
				0.62,
				1.0,
				1.0
			)

		"epic":
			return Color(
				0.68,
				0.36,
				1.0,
				1.0
			)

		"legendary":
			return Color(
				1.0,
				0.72,
				0.18,
				1.0
			)

		"mythic":
			return Color(
				1.0,
				0.34,
				0.7,
				1.0
			)

		"cosmic":
			return Color(
				0.3,
				0.92,
				1.0,
				1.0
			)

		"divine":
			return Color(
				1.0,
				0.92,
				0.58,
				1.0
			)

	return Color(
		0.82,
		0.84,
		0.92,
		1.0
	)


static func _pending_situations_actor_display_name(actor: Person) -> String:
	if actor == null:
		return "this person"

	if actor.has_method("get_display_name"):
		var display_name: String = str(actor.call("get_display_name")).strip_edges()
		if display_name != "":
			return display_name

	if actor.has_method("get_full_name"):
		var method_name: String = str(actor.call("get_full_name")).strip_edges()
		if method_name != "":
			return method_name

	var direct_name: String = ""
	var direct_name_raw = actor.get("name")
	if direct_name_raw != null:
		direct_name = str(direct_name_raw).strip_edges()
	if direct_name != "":
		return direct_name

	var first_name: String = ""
	var first_name_raw = actor.get("first_name")
	if first_name_raw != null:
		first_name = str(first_name_raw).strip_edges()

	var last_name: String = ""
	var last_name_raw = actor.get("last_name")
	if last_name_raw != null:
		last_name = str(last_name_raw).strip_edges()

	var combined_name: String = ("%s %s" % [first_name, last_name]).strip_edges()
	if combined_name != "":
		return combined_name

	var actor_id: int = -1
	var actor_id_raw = actor.get("id")
	if actor_id_raw != null:
		actor_id = int(actor_id_raw)

	if actor_id > 0:
		return "person #%d" % actor_id

	return "this person"


static func _dragonball_scatter_icon(star: int) -> String:
	match int(star):
		1:
			return "🟠"
		2:
			return "🟠"
		3:
			return "🟠"
		4:
			return "🟠"
		5:
			return "🟠"
		6:
			return "🟠"
		7:
			return "🟠"
		_:
			return "🟠"


static func _reality_surge_color(theme_id: String, phase: int = 0) -> Color:
	var clean_theme: String = str(theme_id).strip_edges().to_lower()

	if clean_theme == "avatar":
		var cycle: Array = [
			Color(1.0, 0.25, 0.06, 1.0),
			Color(0.2, 0.68, 1.0, 1.0),
			Color(0.54, 0.88, 0.36, 1.0),
			Color(0.86, 0.94, 1.0, 1.0)
		]
		return cycle [abs(phase) % cycle.size()]

	match clean_theme:
		"fire":
			return Color(1.0, 0.33, 0.08, 1.0)
		"water":
			return Color(0.22, 0.68, 1.0, 1.0)
		"earth":
			return Color(0.54, 0.78, 0.36, 1.0)
		"air":
			return Color(0.88, 0.94, 1.0, 1.0)
		_:
			return Color(1.0, 0.86, 0.42, 1.0)


static func _reality_surge_theme_id(surge: Dictionary) -> String:
	var surge_theme: Dictionary = {}
	var theme_raw: Variant = surge.get("theme", {})
	if typeof(theme_raw) == TYPE_DICTIONARY:
		surge_theme = theme_raw
	return str(surge_theme.get("theme_id", surge_theme.get("element", "generic"))).strip_edges().to_lower()


static func _checkpoint_resume_saved_diary_lines_from_contract(
	resume_contract: Dictionary
) -> Array:
	var lines: Array = []

	if resume_contract.is_empty():
		return lines

	var entries_raw: Variant = resume_contract.get(
		"life_diary_entries",
		[]
	)

	if typeof(entries_raw) != TYPE_ARRAY:
		return lines

	var entries: Array = (
		entries_raw as Array
	)

	for entry_raw in entries:
		var entry_lines: Array = []

		if typeof(entry_raw) == TYPE_ARRAY:
			entry_lines = (
				entry_raw as Array
			)
		elif typeof(entry_raw) == TYPE_DICTIONARY:
			var entry_dict: Dictionary = (
				entry_raw as Dictionary
			)
			var entry_lines_raw: Variant = entry_dict.get(
				"lines",
				[]
			)

			if typeof(entry_lines_raw) == TYPE_ARRAY:
				entry_lines = (
					entry_lines_raw as Array
				)
		else:
			entry_lines = [
				entry_raw
			]

		if entry_lines.is_empty():
			continue

		for raw_line in entry_lines:
			lines.append(
				str(raw_line)
			)

		lines.append("")
		lines.append("")

	return lines


static func _build_afterlife_panel_style(is_hovered: bool) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()

	style.bg_color = Color(0.03, 0.03, 0.03, 0.96) if is_hovered else Color(0.0, 0.0, 0.0, 0.93)

	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(1.0, 1.0, 1.0, 0.22) if is_hovered else Color(1.0, 1.0, 1.0, 0.12)

	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_right = 16
	style.corner_radius_bottom_left = 16

	style.content_margin_left = 12
	style.content_margin_top = 12
	style.content_margin_right = 12
	style.content_margin_bottom = 12

	style.shadow_color = Color(1.0, 1.0, 1.0, 0.18) if is_hovered else Color(1.0, 1.0, 1.0, 0.1)
	style.shadow_size = 20 if is_hovered else 13
	style.shadow_offset = Vector2(0, 0)

	return style


static func _is_transient_afterlife_overlay_result_type(_result_type: String) -> bool:
	return false


static func _object_has_script_property(target: Object, property_name: String) -> bool:
	if target == null:
		return false

	for property_info in target.get_property_list():
		if typeof(property_info) != TYPE_DICTIONARY:
			continue
		if str(property_info.get("name", "")).strip_edges() == property_name:
			return true

	return false


static func _property_asset_enter_button_label(payload: Dictionary) -> String:
	var property_type: String = str(payload.get("subtype", "")).strip_edges()
	if property_type == "":
		property_type = str(payload.get("display_name", payload.get("type", "Property"))).strip_edges()
	property_type = property_type.replace("_", " ").capitalize()

	var address: String = str(payload.get("address", "")).strip_edges()
	if address == "" or address == "Unknown Address":
		return property_type

	return "%s at %s" % [property_type, address]


static func _luxury_exchange_shiny_audio_candidate_paths() -> Array:
	return [
		"res://audio/music/Shiny.ogg",
		"res://Audio/Music/Shiny.ogg",
		"res://audio/Shiny.ogg",
		"res://Audio/Shiny.ogg",
		"res://audio/sfx/Shiny.ogg",
		"res://Audio/SFX/Shiny.ogg",
		"res://Shiny.ogg"
	]


static func _asset_surface_contract_revision_key(
	contract: Dictionary
) -> String:
	if contract.is_empty():
		return ""

	for key in [
		"surface_signature",
		"surface_revision",
		"projection_revision",
		"revision"
	]:
		var value: String = str(
			contract.get(
				key,
				""
			)
		).strip_edges()

		if value != "":
			return value

	return str(
		hash(contract)
	)


static func _activities_hub_icon_for_group(group_name: String) -> String:
	match str(group_name).strip_edges():
		"Featured":
			return "✨"
		"Markets & Assets":
			return "🏦"
		"Public Life":
			return "🌆"
		"School & Youth":
			return "📚"
		"Supernatural":
			return "🌀"
		_:
			return "🎲"


static func _activities_hub_description_for_group(group_name: String) -> String:
	match str(group_name).strip_edges():
		"Featured":
			return "One-time unlocks and important life-entry decisions."
		"Markets & Assets":
			return "Browse, manage, or inspect owned things without mixing in careers."
		"Public Life":
			return "Go places, move around, and interact with the world."
		"School & Youth":
			return "School-adjacent actions that are not full training systems."
		"Supernatural":
			return "Reality-bending routes, occult choices, and high-weirdness actions."
		_:
			return "Contextual life actions that do not belong to a deeper hub yet."


static func _property_makeover_surface_panel_key(
	actor_id: int,
	property_id: int
) -> String:
	return "%d:%d" % [
		actor_id,
		property_id
	]


static func _property_viewer_surface_panel_key(
	actor_id: int,
	property_id: int
) -> String:
	return "%d:%d" % [
		actor_id,
		property_id
	]


static func _compact_property_spatial_intent_payload(
	source: Dictionary,
	action_id: String,
	actor_id: int,
	property_id: int,
	property_owner_id: int
) -> Dictionary:
	var out: Dictionary = {
		"actor_id": actor_id,
		"property_id": property_id,
		"property_owner_id": property_owner_id,
		"action_id": action_id,
		"intent_type": "spatial_traversal",
		"source": "mainscene.property_viewer",
		"ui_is_renderer_only": true,
	}

	for key in [
		"room_id",
		"from_room_id",
		"target_room_id",
		"fixture_id",
		"fixture_kind",
		"host_id",
		"host_kind",
		"provider_id",
		"multiplayer_mode",
		"direction",
		"edge_id",
		"security_mode"
	]:
		if source.has(
			key
		):
			out [key] = str(
				source.get(
					key,
					""
				)
			)

	for key in [
		"launch_direct",
		"open_provider_setup"
	]:
		if source.has(
			key
		):
			out [key] = bool(
				source.get(
					key,
					false
				)
			)

	if source.has(
		"cursor_revision"
	):
		out [
			"cursor_revision"
		] = int(
			source.get(
				"cursor_revision",
				0
			)
		)

	for key in [
		"active_floor",
		"from_floor",
		"target_floor"
	]:
		if source.has(
			key
		):
			out [key] = int(
				source.get(
					key,
					0
				)
			)

	return out


static func _property_portfolio_body_lines(payload: Dictionary, status_text: String = "") -> Array:
	var lines: Array = []
	var rollup: Dictionary = payload.get("rollup", {})
	var portfolio_tags: Dictionary = rollup.get("portfolio_tags", {})
	lines.append("Holdings: %d total" % int(rollup.get("asset_count", 0)))
	if int(portfolio_tags.get("dynastic_properties", 0)) > 0:
		lines.append("Dynastic Seats: %d" % int(portfolio_tags.get("dynastic_properties", 0)))
	if int(portfolio_tags.get("rentals", 0)) > 0:
		lines.append("Rentals: %d" % int(portfolio_tags.get("rentals", 0)))
	if int(portfolio_tags.get("safehouses", 0)) > 0:
		lines.append("Safehouses: %d" % int(portfolio_tags.get("safehouses", 0)))
	if status_text.strip_edges() != "":
		lines.append("")
		lines.append(status_text.strip_edges())
	return lines


static func _vehicle_portfolio_body_lines(payload: Dictionary, status_text: String = "") -> Array:
	var lines: Array = []
	var rollup: Dictionary = payload.get("rollup", {})
	var portfolio_tags: Dictionary = rollup.get("portfolio_tags", {})
	lines.append("Mobility Assets: %d total" % int(rollup.get("asset_count", 0)))
	if int(portfolio_tags.get("fleets", 0)) > 0:
		lines.append("Fleet Tags: %d" % int(portfolio_tags.get("fleets", 0)))
	if int(portfolio_tags.get("stables", 0)) > 0:
		lines.append("Stable Tags: %d" % int(portfolio_tags.get("stables", 0)))
	if int(portfolio_tags.get("hangars", 0)) > 0:
		lines.append("Hangar Tags: %d" % int(portfolio_tags.get("hangars", 0)))
	if int(portfolio_tags.get("trade_routes", 0)) > 0:
		lines.append("Trade Routes: %d" % int(portfolio_tags.get("trade_routes", 0)))
	if status_text.strip_edges() != "":
		lines.append("")
		lines.append(status_text.strip_edges())
	return lines


static func _vehicle_portfolio_asset_body_lines(payload: Dictionary, status_text: String = "") -> Array:
	var lines: Array = []
	lines.append("Asset: %s" % str(payload.get("display_name", "Mobility Asset")))
	lines.append("Identity: %s • %s • %s • %s" % [
		str(payload.get("archetype", "transport")).replace("_", " ").capitalize(),
		str(payload.get("subtype", "")).replace("_", " ").capitalize(),
		str(payload.get("social_tier", "common")).replace("_", " ").capitalize(),
		str(payload.get("value_band", "entry")).replace("_", " ").capitalize()
	])
	lines.append("Condition: %d%% • %s" % [
		int(payload.get("condition", 100)),
		str(payload.get("condition_label", "Excellent"))
	])
	lines.append("Operator: %s" % str(payload.get("operator_label", "Owner / Self")))
	lines.append("Route: %s" % str(payload.get("route_label", "Local Use")))
	lines.append("Trade Role: %s" % str(payload.get("trade_role_label", "Personal Travel")))

	if str(payload.get("active_assignment", "")) != "":
		lines.append("Assignment: %s" % str(payload.get("active_assignment", "")))

	var feature_tag_labels: Array = payload.get("feature_tag_labels", [])
	if not feature_tag_labels.is_empty():
		lines.append("Identity Tags: %s" % ", ".join(feature_tag_labels))

	var requirement_tag_labels: Array = payload.get("requirement_tag_labels", [])
	if not requirement_tag_labels.is_empty():
		lines.append("Requirements: %s" % ", ".join(requirement_tag_labels))

	var missing_requirement_labels: Array = payload.get("missing_requirement_labels", [])
	if not missing_requirement_labels.is_empty():
		lines.append("Missing Support: %s" % ", ".join(missing_requirement_labels))

	var satisfied_requirement_labels: Array = payload.get("satisfied_requirement_labels", [])
	if not satisfied_requirement_labels.is_empty():
		lines.append("Satisfied Support: %s" % ", ".join(satisfied_requirement_labels))

	var portfolio_tag_labels: Array = payload.get("portfolio_tag_labels", [])
	if not portfolio_tag_labels.is_empty():
		lines.append("Portfolio Tags: %s" % ", ".join(portfolio_tag_labels))

	var status_lines: Array = payload.get("status_lines", [])
	if not status_lines.is_empty():
		lines.append("")
		lines.append("Status Signals:")
		for line_text in status_lines:
			lines.append("• %s" % str(line_text))

	var operational_lines: Array = payload.get("operational_lines", [])
	if not operational_lines.is_empty():
		lines.append("")
		lines.append("Operational Profile:")
		for line_text in operational_lines:
			lines.append("• %s" % str(line_text))

	var pressure_lines: Array = payload.get("pressure_lines", [])
	if not pressure_lines.is_empty():
		lines.append("")
		lines.append("Story Pressure:")
		for line_text in pressure_lines:
			lines.append("• %s" % str(line_text))

	var provenance_lines: Array = payload.get("provenance_lines", [])
	if not provenance_lines.is_empty():
		lines.append("")
		lines.append("Provenance:")
		for line_text in provenance_lines:
			lines.append("• %s" % str(line_text))

	var candidate_labels: Array = payload.get("candidate_labels", [])
	if not candidate_labels.is_empty():
		lines.append("")
		lines.append("Operator Pool: %s" % ", ".join(candidate_labels))

	lines.append("")
	lines.append("Legal Status: %s" % str(payload.get("legal_status", "owned")))
	if str(payload.get("market_region", "")) != "":
		lines.append("Region: %s" % str(payload.get("market_region", "")))
	if str(payload.get("market_climate", "")) != "":
		lines.append("Market Climate: %s" % str(payload.get("market_climate", "")))
	if str(payload.get("custom_paint", "")) != "":
		lines.append("Custom Paint: %s" % str(payload.get("custom_paint", "")))

	if status_text.strip_edges() != "":
		lines.append("")
		lines.append(status_text.strip_edges())
	return lines


static func _nearby_switch_row_person(row: Dictionary) -> Person:
	if typeof(row) != TYPE_DICTIONARY:
		return null
	var npc_raw: Variant = row.get("npc", null)
	if npc_raw != null and npc_raw is Person:
		return npc_raw as Person
	return null


static func _person_contract_value(person: Person, keys: Array, fallback: String = "") -> String:
	if person == null:
		return fallback

	for raw_key in keys:
		var key: String = str(raw_key)
		var value: String = ""

		if person.has_method("get"):
			value = str(person.get(key)).strip_edges()

		if value != "" and value != "<null>":
			return value

	return fallback


static func _other_country_elemental_needs_definite_article(place_name: String) -> bool:
	var clean_name: String = str(place_name).strip_edges()
	if clean_name == "":
		return false
	var lower_name: String = clean_name.to_lower()
	if lower_name.begins_with("the "):
		return false
	if lower_name == "fire nation":
		return true
	if lower_name == "earth kingdom":
		return true
	if lower_name == "air nomads":
		return true
	if lower_name.find("air temple") >= 0:
		return true
	if lower_name.find("water tribe") >= 0:
		return true
	return false


static func _build_other_country_elemental_palette(element: String) -> Dictionary:
	match element:
		"fire":
			return {
				"display_name": "Fire",
				"aura_bg": Color(0.28, 0.08, 0.05, 0.18),
				"aura_border": Color(1.0, 0.52, 0.22, 0.78),
				"aura_shadow": Color(0.98, 0.44, 0.18, 0.34),
				"card_bg": Color(0.19, 0.09, 0.06, 0.98),
				"card_border": Color(1.0, 0.58, 0.22, 0.84),
				"card_shadow": Color(0.96, 0.42, 0.14, 0.24),
				"header_bg": Color(0.28, 0.12, 0.08, 0.98),
				"header_border": Color(1.0, 0.64, 0.26, 0.88),
				"header_shadow": Color(0.96, 0.42, 0.14, 0.24),
				"button_bg": Color(0.22, 0.1, 0.07, 0.96),
				"button_border": Color(1.0, 0.58, 0.24, 0.84),
				"button_shadow": Color(0.94, 0.38, 0.14, 0.22),
				"hover_bg": Color(0.36, 0.15, 0.1, 1.0),
				"hover_border": Color(1.0, 0.76, 0.38, 1.0),
				"hover_shadow": Color(0.98, 0.5, 0.18, 0.3),
				"header_font": Color(1.0, 0.94, 0.88, 0.99),
				"summary_font": Color(1.0, 0.92, 0.86, 0.92),
				"pulse_a": Color(1.06, 1.02, 1.0, 1.0),
				"pulse_b": Color(1.14, 1.06, 1.02, 1.0)
			}
		"water":
			return {
				"display_name": "Water",
				"aura_bg": Color(0.06, 0.14, 0.22, 0.2),
				"aura_border": Color(0.54, 0.86, 1.0, 0.74),
				"aura_shadow": Color(0.28, 0.64, 1.0, 0.32),
				"card_bg": Color(0.08, 0.14, 0.21, 0.98),
				"card_border": Color(0.58, 0.88, 1.0, 0.82),
				"card_shadow": Color(0.24, 0.54, 0.92, 0.22),
				"header_bg": Color(0.1, 0.18, 0.28, 0.98),
				"header_border": Color(0.7, 0.92, 1.0, 0.88),
				"header_shadow": Color(0.26, 0.56, 0.96, 0.22),
				"button_bg": Color(0.1, 0.17, 0.26, 0.96),
				"button_border": Color(0.58, 0.86, 1.0, 0.82),
				"button_shadow": Color(0.22, 0.5, 0.9, 0.2),
				"hover_bg": Color(0.14, 0.24, 0.36, 1.0),
				"hover_border": Color(0.84, 0.96, 1.0, 1.0),
				"hover_shadow": Color(0.34, 0.66, 1.0, 0.32),
				"header_font": Color(0.94, 0.98, 1.0, 0.99),
				"summary_font": Color(0.9, 0.96, 1.0, 0.92),
				"pulse_a": Color(1.0, 1.04, 1.1, 1.0),
				"pulse_b": Color(1.04, 1.1, 1.18, 1.0)
			}
		"earth":
			return {
				"display_name": "Earth",
				"aura_bg": Color(0.1, 0.16, 0.08, 0.2),
				"aura_border": Color(0.78, 0.92, 0.46, 0.72),
				"aura_shadow": Color(0.5, 0.76, 0.22, 0.3),
				"card_bg": Color(0.1, 0.15, 0.08, 0.98),
				"card_border": Color(0.8, 0.92, 0.52, 0.82),
				"card_shadow": Color(0.44, 0.68, 0.2, 0.22),
				"header_bg": Color(0.15, 0.2, 0.1, 0.98),
				"header_border": Color(0.88, 0.96, 0.64, 0.88),
				"header_shadow": Color(0.48, 0.72, 0.22, 0.22),
				"button_bg": Color(0.13, 0.18, 0.1, 0.96),
				"button_border": Color(0.78, 0.92, 0.5, 0.82),
				"button_shadow": Color(0.4, 0.62, 0.18, 0.2),
				"hover_bg": Color(0.2, 0.26, 0.12, 1.0),
				"hover_border": Color(0.96, 1.0, 0.76, 1.0),
				"hover_shadow": Color(0.52, 0.76, 0.24, 0.3),
				"header_font": Color(0.98, 0.98, 0.9, 0.99),
				"summary_font": Color(0.92, 0.96, 0.86, 0.92),
				"pulse_a": Color(1.02, 1.06, 1.0, 1.0),
				"pulse_b": Color(1.08, 1.12, 1.04, 1.0)
			}
		"air":
			return {
				"display_name": "Air",
				"aura_bg": Color(0.2, 0.16, 0.08, 0.18),
				"aura_border": Color(0.96, 0.9, 0.58, 0.74),
				"aura_shadow": Color(0.92, 0.84, 0.44, 0.3),
				"card_bg": Color(0.18, 0.14, 0.08, 0.98),
				"card_border": Color(0.98, 0.92, 0.66, 0.82),
				"card_shadow": Color(0.88, 0.8, 0.4, 0.22),
				"header_bg": Color(0.24, 0.19, 0.1, 0.98),
				"header_border": Color(1.0, 0.96, 0.76, 0.88),
				"header_shadow": Color(0.92, 0.84, 0.42, 0.22),
				"button_bg": Color(0.22, 0.17, 0.1, 0.96),
				"button_border": Color(0.98, 0.92, 0.64, 0.82),
				"button_shadow": Color(0.84, 0.76, 0.38, 0.2),
				"hover_bg": Color(0.3, 0.24, 0.12, 1.0),
				"hover_border": Color(1.0, 0.98, 0.84, 1.0),
				"hover_shadow": Color(0.94, 0.86, 0.46, 0.3),
				"header_font": Color(1.0, 0.98, 0.9, 0.99),
				"summary_font": Color(0.98, 0.96, 0.86, 0.92),
				"pulse_a": Color(1.04, 1.04, 1.0, 1.0),
				"pulse_b": Color(1.1, 1.1, 1.04, 1.0)
			}

	return {}


static func _apply_other_country_browser_button_palette(button: Button, palette: Dictionary) -> void:
	if button == null:
		return

	var normal_style:= StyleBoxFlat.new()
	normal_style.bg_color = palette.get("button_bg", Color(0.14, 0.16, 0.24, 0.92))
	normal_style.border_color = palette.get("button_border", Color(0.6, 0.7, 0.9, 0.34))
	normal_style.shadow_color = palette.get("button_shadow", Color(0.45, 0.58, 0.9, 0.16))
	normal_style.shadow_size = int(palette.get("button_shadow_size", 8))
	normal_style.border_width_left = 1
	normal_style.border_width_top = 1
	normal_style.border_width_right = 1
	normal_style.border_width_bottom = 1
	normal_style.corner_radius_top_left = 10
	normal_style.corner_radius_top_right = 10
	normal_style.corner_radius_bottom_left = 10
	normal_style.corner_radius_bottom_right = 10
	normal_style.shadow_offset = Vector2.ZERO
	button.add_theme_stylebox_override("normal", normal_style)

	var hover_style:= normal_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = palette.get("hover_bg", normal_style.bg_color.lightened(0.08))
	hover_style.border_color = palette.get("hover_border", normal_style.border_color.lightened(0.12))
	hover_style.shadow_color = palette.get("hover_shadow", normal_style.shadow_color.lightened(0.1))
	hover_style.shadow_size = int(palette.get("hover_shadow_size", normal_style.shadow_size + 6))
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("focus", hover_style)
	button.add_theme_stylebox_override("pressed", hover_style)

	button.add_theme_color_override("font_color", palette.get("header_font", Color(0.94, 0.97, 1.0, 0.98)))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_focus_color", Color(1.0, 1.0, 1.0, 1.0))


static func _build_other_country_elemental_descriptor(element: String) -> Dictionary:
	match element:
		"fire":
			return {
				"display_name": "Fire",
				"intro": "This realm reads like a furnace with a flag—disciplined, dynastic, and always one decree away from ignition.",
				"nature": "Volcanic monarchy, imperial memory, and disciplined combustion.",
				"stat_a": "Heat",
				"stat_b": "Discipline",
				"stat_c": "Imperial Will",
				"stat_d": "Volcanic Pressure",
				"current_title": "EMBER CURRENT",
				"sites_title": "FLAME SEATS",
				"pressure_title": "DYNASTIC PRESSURE",
				"pressure_lines": [
					"The realm values strength, command, and the visible projection of sovereign force.",
					"Its beauty is inseparable from danger: ceremony, steel, ships, heat, and ambition all move together.",
					"Even at rest, the realm feels like it is storing ignition for later."
				]
			}
		"water":
			return {
				"display_name": "Water",
				"intro": "This realm moves like memory held under ice—adaptive, ancestral, and far more dangerous than its stillness first suggests.",
				"nature": "Tidal resilience, ancestral adaptation, and cold luminous sovereignty.",
				"stat_a": "Flow",
				"stat_b": "Adaptation",
				"stat_c": "Tribal Resolve",
				"stat_d": "Ice Pressure",
				"current_title": "TIDAL CURRENT",
				"sites_title": "ICE SEATS",
				"pressure_title": "ANCESTRAL PRESSURE",
				"pressure_lines": [
					"The realm survives by motion, memory, and collective discipline under brutal conditions.",
					"What looks soft from a distance is often the result of extreme resilience up close.",
					"Ice, tide, kinship, and endurance are all part of the same state language here."
				]
			}
		"earth":
			return {
				"display_name": "Earth",
				"intro": "This realm feels tectonic—massive, patient, and too old to rush itself for anyone.",
				"nature": "Continental sovereignty, dynastic stone, and enduring structural power.",
				"stat_a": "Fortitude",
				"stat_b": "Stability",
				"stat_c": "Dynastic Weight",
				"stat_d": "Seismic Pressure",
				"current_title": "TECTONIC CURRENT",
				"sites_title": "STONE SEATS",
				"pressure_title": "CONTINENTAL PRESSURE",
				"pressure_lines": [
					"The realm projects power through durability, scale, and the ability to outlast sudden disruption.",
					"Its authority is less theatrical than fire and less fluid than water, but it can feel immovable when fully aligned.",
					"Stone, law, land, and continuity all reinforce one another here."
				]
			}
		"air":
			return {
				"display_name": "Air",
				"intro": "This realm does not sit heavily in the world. It hovers over it—lucid, elevated, and spiritually charged.",
				"nature": "Sky-bound monastic sovereignty, mobility, clarity, and spiritual lift.",
				"stat_a": "Lift",
				"stat_b": "Harmony",
				"stat_c": "Clarity",
				"stat_d": "Spiritual Pressure",
				"current_title": "SKY CURRENT",
				"sites_title": "HIGH PLACES",
				"pressure_title": "SPIRITUAL PRESSURE",
				"pressure_lines": [
					"The realm expresses power through detachment, mobility, spiritual discipline, and high vantage.",
					"It feels less like a machine of domination and more like a sacred current moving above denser states.",
					"When strained, its pressure shows up as imbalance between serenity and worldly intrusion."
				]
			}

	return {
		"display_name": "Elemental",
		"intro": "This realm is visibly element-aligned and should never render like an ordinary country card.",
		"nature": "Elemental sovereignty.",
		"stat_a": "Alignment",
		"stat_b": "Current",
		"stat_c": "Will",
		"stat_d": "Pressure",
		"current_title": "ELEMENTAL CURRENT",
		"sites_title": "KEY SITES",
		"pressure_title": "STATE PRESSURE",
		"pressure_lines": [
			"The realm carries a visible elemental signature."
		]
	}


static func _append_other_country_contract_special_realms(_out: Array, _seen: Dictionary) -> void:












	return


static func _fallback_country_shell_names_for_era(era_key: String) -> Array:
	var clean_era: String = str(era_key).strip_edges().to_lower()

	if clean_era.find("ancient") >= 0:
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

	if clean_era.find("medieval") >= 0:
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

	if clean_era.find("industrial") >= 0:
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

	if clean_era.find("future") >= 0:
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


static func _other_country_identity_key(value: String) -> String:
	var cleaned: String = str(value).strip_edges().to_lower()
	for ch in [" ", "_", "-", "•", ".", ",", "'", "\"", ":", ";", "/", "\\", "(", ")"]:
		cleaned = cleaned.replace(ch, "")
	return cleaned


static func _other_country_browser_section_title(
	section: String
) -> String:
	match str(
		section
	).strip_edges().to_lower():
		"interrealm_authority":
			return "INTERREALM AUTHORITY"

		"space_realms":
			return "SPACE REALMS"

		"imaginative_realms":
			return "IMAGINATIVE REALMS"

		"elemental_realms":
			return "ELEMENTAL REALMS"

		"standard_realms", "ordinary_realms":
			return "ORDINARY REALMS"

		_:
			return str(
				section
			).replace(
				"_",
				" "
			).to_upper()


static func _other_country_browser_section_priority(
	section: String
) -> int:
	match str(
		section
	).strip_edges().to_lower():
		"interrealm_authority":
			return 0

		"space_realms":
			return 1

		"imaginative_realms":
			return 2

		"elemental_realms":
			return 3

		"standard_realms", "ordinary_realms":
			return 4

		_:
			return 5


static func _era_country_ruler_surface_label(country_name: String, era_key: String, hash_value: int) -> String:
	var era_lower: String = str(era_key).strip_edges().to_lower()
	var clean_country: String = str(country_name).strip_edges()
	if clean_country == "":
		clean_country = "Unknown Country"

	if era_lower == "ancient":
		return ["High King", "Queen Regent", "Divine Steward", "Imperial Governor"] [hash_value % 4] + " of %s" % clean_country
	if era_lower == "medieval":
		return ["Crown Regent", "High Lord", "Sovereign", "Royal Steward"] [hash_value % 4] + " of %s" % clean_country
	if era_lower == "industrial":
		return ["Prime Minister", "Industrial Chancellor", "President", "Crown Minister"] [hash_value % 4] + " of %s" % clean_country
	if era_lower == "future":
		return ["Quantum Chancellor", "World Governor", "Civic AI Regent", "Planetary Steward"] [hash_value % 4] + " of %s" % clean_country

	return ["President", "Prime Minister", "Chancellor", "National Regent"] [hash_value % 4] + " of %s" % clean_country


static func _elemental_realm_ruler_surface_label(native_element: String) -> String:
	match str(native_element).strip_edges().to_lower():
		"fire":
			return "Fire Lord"
		"water":
			return "Chief"
		"earth":
			return "Earth King"
		"air":
			return "Air Monk"
		_:
			return "Elemental Regent"


static func _romance_contract_stat_palette_key(stat_name: String) -> String:
	var clean: String = str(stat_name).strip_edges()

	match clean:
		"Mental Health":
			return "Mental"
		"Affection":
			return "Bond"
		"Distance Pull":
			return "Bond"
		_:
			return clean


static func _other_country_merge_realm_truth_into_surface_realm(surface_realm: Dictionary, truth_realm: Dictionary) -> Dictionary:
	var out: Dictionary = surface_realm.duplicate(true)

	for key in [
		"id",
		"realm_id",
		"name",
		"country",
		"government_style",
		"government_model",
		"government_type",
		"ruler_id",
		"ruler_npc_id",
		"leader_id",
		"ruler_name",
		"leader_name",
		"leader_title",
		"surface_ruler_office",
		"president_person_id",
		"first_partner_person_id",
		"federal_republic_population_contract",
		"federal_executive_person_ids",
		"federal_cabinet_person_ids",
		"federal_senate_person_ids",
		"federal_supreme_court_person_ids",
		"federal_governor_person_ids",
		"federal_citizen_person_ids"
	]:
		if truth_realm.has(key):
			out [key] = truth_realm.get(key)

	if not out.has("population") and truth_realm.has("population"):
		out ["population"] = truth_realm.get("population")
	if not out.has("treasury") and truth_realm.has("treasury"):
		out ["treasury"] = truth_realm.get("treasury")
	if not out.has("military_units") and truth_realm.has("military_units"):
		out ["military_units"] = truth_realm.get("military_units")
	if not out.has("military_stockpile") and truth_realm.has("military_stockpile"):
		out ["military_stockpile"] = truth_realm.get("military_stockpile")

	out ["surface_governance_merged_from_realm_truth"] = true
	out ["ui_is_renderer_only"] = true
	return out


static func _other_country_text_already_has_title(raw_text: String, title_text: String) -> bool:
	var clean_raw: String = str(raw_text).strip_edges().to_lower()
	var clean_title: String = str(title_text).strip_edges().to_lower()
	if clean_raw == "" or clean_title == "":
		return true

	if clean_raw.begins_with(clean_title):
		return true

	return false


static func _other_country_person_plain_name(person: Person) -> String:
	if person == null:
		return "Unknown"

	var first_name: String = str(person.first_name).strip_edges()
	var last_name: String = str(person.last_name).strip_edges()
	var full_name: String = ("%s %s" % [first_name, last_name]).strip_edges()

	if full_name == "":
		full_name = str(person.name).strip_edges()

	if full_name == "":
		full_name = "Unknown"

	return full_name


static func _other_country_ruler_text_is_generic_office(lower_text: String, realm: Dictionary = {}) -> bool:
	var text_value: String = str(lower_text).strip_edges().to_lower()
	if text_value == "":
		return false

	var realm_name: String = str(realm.get("name", "")).strip_edges().to_lower()
	var place_names: Array = []
	if realm_name != "":
		place_names.append(realm_name)
		if realm_name.begins_with("the "):
			place_names.append(realm_name.substr(4).strip_edges())
		else:
			place_names.append("the %s" % realm_name)

	var capital_text: String = str(realm.get("capital", realm.get("capital_city", ""))).strip_edges().to_lower()
	if capital_text != "":
		place_names.append(capital_text)

	var office_prefixes: Array = [
		"president",
		"chancellor",
		"supreme leader",
		"general secretary",
		"council voice",
		"head of state",
		"ruler",
		"king",
		"queen",
		"emperor",
		"empress",
		"fire lord",
		"earth king",
		"earth queen",
		"chief",
		"air monk",
		"monk",
		"pharaoh",
		"pharoah",
		"archon",
		"basileus",
		"shahanshah",
		"suffet",
		"maharaja",
		"chieftain",
		"consul",
		"tyrant",
		"sultan",
		"mansa",
		"khan",
		"doge",
		"shogun",
		"council head",
		"warlord"
	]

	for raw_prefix in office_prefixes:
		var prefix: String = str(raw_prefix).strip_edges().to_lower()
		if prefix == "":
			continue

		if text_value == prefix:
			return true

		for raw_place in place_names:
			var place: String = str(raw_place).strip_edges().to_lower()
			if place == "":
				continue
			if text_value == "%s of %s" % [prefix, place]:
				return true

		if text_value.begins_with("%s of " % prefix):
			return true

	return false


static func _other_country_clean_person_title_for_display(raw_title: String, plain_name: String = "") -> String:
	var title_text: String = str(raw_title).strip_edges()
	if title_text == "":
		return ""

	var lower_title: String = title_text.to_lower()
	var lower_name: String = str(plain_name).strip_edges().to_lower()

	if lower_name != "" and lower_title.find(lower_name) >= 0:
		return ""

	var rejected_office_tokens: Array = [
		"president of ",
		"chancellor of ",
		"supreme leader of ",
		"general secretary of ",
		"council voice of ",
		"head of state of ",
		"ruler of "
	]

	for raw_token in rejected_office_tokens:
		if lower_title.begins_with(str(raw_token)):
			return ""

	return title_text


static func _other_country_surface_ruler_explicit_city_pool(lower_realm: String, lower_country: String, lower_element: String) -> Array:
	var key_text: String = "%s %s %s" % [lower_realm, lower_country, lower_element]

	if lower_element == "fire" or key_text.find("fire nation") >= 0:
		return ["Capital City", "Caldera City", "Ember Island", "Fire Fountain City", "Shu Jing"]

	if lower_element == "earth" or key_text.find("earth kingdom") >= 0:
		return ["Ba Sing Se", "Omashu", "Gaoling", "Chin Village", "Kyoshi Island"]

	if lower_element == "water" or key_text.find("water tribe") >= 0 or key_text.find("water nation") >= 0:
		return ["Agna Qel'a", "Wolf Cove", "Harbor City", "Foggy Swamp", "Southern Water Village"]

	if lower_element == "air" or key_text.find("air temple") >= 0 or key_text.find("air nomads") >= 0:
		return ["Eastern Air Temple", "Western Air Temple", "Northern Air Temple", "Southern Air Temple"]

	if key_text.find("ancient egypt") >= 0 or key_text.find("egypt") >= 0:
		return ["Thebes", "Memphis", "Alexandria", "Avaris", "Heliopolis"]

	if key_text.find("mesopotamia") >= 0:
		return ["Babylon", "Ur", "Nineveh", "Akkad", "Lagash"]

	if key_text.find("assyria") >= 0:
		return ["Nineveh", "Ashur", "Nimrud", "Arbela"]

	if key_text.find("greece") >= 0:
		return ["Athens", "Sparta", "Corinth", "Thebes"]

	if key_text.find("rome") >= 0 or key_text.find("roman") >= 0:
		return ["Rome", "Pompeii", "Ravenna", "Mediolanum"]

	if key_text.find("china") >= 0:
		return ["Xi'an", "Luoyang", "Chang'an", "Nanjing"]

	if key_text.find("persia") >= 0:
		return ["Persepolis", "Susa", "Ecbatana", "Pasargadae"]

	if key_text.find("mali") >= 0:
		return ["Timbuktu", "Niani", "Gao", "Jenne"]

	if key_text.find("england") >= 0:
		return ["London", "York", "Winchester", "Canterbury"]

	if key_text.find("frankia") >= 0 or key_text.find("france") >= 0:
		return ["Paris", "Tours", "Orléans", "Reims"]

	if key_text.find("byzantine") >= 0:
		return ["Constantinople", "Nicaea", "Thessalonica", "Antioch"]

	if key_text.find("japan") >= 0:
		return ["Kyoto", "Nara", "Kamakura", "Edo"]

	if key_text.find("arabia") >= 0 or key_text.find("caliphate") >= 0:
		return ["Mecca", "Medina", "Damascus", "Baghdad"]

	return []


static func _other_country_ancient_ruler_title_for_name(lower_name: String, government_style: String = "") -> String:
	var clean_name: String = str(lower_name).strip_edges().to_lower()
	var clean_government: String = str(government_style).strip_edges()

	if clean_name.find("greece") >= 0:
		return "Archon"
	if clean_name.find("athens") >= 0:
		return "Archon"
	if clean_name.find("sparta") >= 0:
		return "Basileus"
	if clean_name.find("roman") >= 0:
		return "Emperor"
	if clean_name.find("egypt") >= 0:
		return "Pharaoh"
	if clean_name.find("persia") >= 0:
		return "Shahanshah"
	if clean_name.find("carthage") >= 0:
		return "Suffet"
	if clean_name.find("han china") >= 0 or clean_name == "china":
		return "Emperor"
	if clean_name.find("india") >= 0:
		return "Maharaja"
	if clean_name.find("judea") >= 0:
		return "King"
	if clean_name.find("numidia") >= 0:
		return "King"
	if clean_name.find("gaul") >= 0 or clean_name.find("germania") >= 0 or clean_name.find("britannia") >= 0:
		return "Chieftain"

	match clean_government:
		"Monarchy":
			return "King"
		"Empire":
			return "Emperor"
		"Kingdom":
			return "King"
		"Republic":
			return "Consul"
		"Democracy":
			return "Archon"
		"Dictatorship":
			return "Tyrant"
		_:
			return "Ruler"


static func _other_country_medieval_ruler_title_for_name(lower_name: String, government_style: String = "") -> String:
	var clean_name: String = str(lower_name).strip_edges().to_lower()
	var clean_government: String = str(government_style).strip_edges()

	if clean_name.find("byzantine") >= 0:
		return "Emperor"
	if clean_name.find("holy roman") >= 0:
		return "Emperor"
	if clean_name.find("mali") >= 0:
		return "Mansa"
	if clean_name.find("mongol") >= 0:
		return "Khan"
	if clean_name.find("venice") >= 0:
		return "Doge"
	if clean_name.find("japan") >= 0:
		return "Shogun"
	if clean_name.find("china") >= 0:
		return "Emperor"
	if clean_name.find("england") >= 0 or clean_name.find("france") >= 0 or clean_name.find("spain") >= 0 or clean_name.find("portugal") >= 0:
		return "King"
	if clean_name.find("egypt") >= 0:
		return "Sultan"

	match clean_government:
		"Monarchy":
			return "King"
		"Empire":
			return "Emperor"
		"Kingdom":
			return "King"
		"Republic":
			return "Doge"
		"Democracy":
			return "Council Head"
		"Dictatorship":
			return "Warlord"
		_:
			return "Ruler"


static func _reality_fusion_mode_warning(mode: String) -> String:
	match str(mode).strip_edges().to_lower():
		"stats_steal":
			return "STEAL this player's stats into yours? They might fight back."
		"inventory_merge":
			return "Merge their inventory into yours? Legendary objects may not arrive quietly."
		"bending_transfer":
			return "Merge their bending skills into yours? The elements may remember both souls."
		"traits_merge":
			return "Merge their traits into yours? Personality drift is possible."
		"money_transfer":
			return "Pull money from their universe? Interdimensional banking is messy."
		"bring_person_family":
			return "Queue this person and their close family for crossover."
		"friend_person":
			return "Bring only this person into your universe as an ally/friend."
		"bring_family_member":
			return "Bring only the selected family member into your universe."
		"fusion_loadout":
			return "Execute the queued Fusion Loadout. Multiple reality layers may shift at once."
		_:
			return "Merge this player's stats into yours? Could be too good to be true."


static func _reality_fusion_success_label(mode: String, source_name: String) -> String:
	match str(mode).strip_edges().to_lower():
		"stats_steal":
			return "Stole stat power from %s." % source_name
		"inventory_merge":
			return "Merged inventory echoes from %s." % source_name
		"bending_transfer":
			return "Merged bending influence from %s." % source_name
		"traits_merge":
			return "Merged trait fragments from %s." % source_name
		"money_transfer":
			return "Transferred money from %s's universe." % source_name
		"parallel_identity_import", "bring_person_family":
			return "%s and their family crossed into this universe." % source_name
		"friend_person":
			return "%s crossed into this universe as your ally." % source_name
		"bring_family_member":
			return "%s crossed into this universe alone." % source_name
		"fusion_loadout":
			return "Executed a Fusion Loadout through %s's universe." % source_name
		_:
			return "Merged stats from %s." % source_name


static func _reality_fusion_execute_button_style(selected: bool, pressed: bool, disabled: bool) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.set_corner_radius_all(16)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8

	if disabled:
		style.bg_color = Color(0.28, 0.22, 0.1, 0.72)
		style.border_color = Color(0.72, 0.56, 0.22, 0.38)
		style.set_border_width_all(1)
		return style

	if pressed:
		style.bg_color = Color(1.0, 0.78, 0.08, 1.0)
		style.border_color = Color(1.0, 1.0, 1.0, 0.96)
		style.shadow_color = Color(1.0, 1.0, 1.0, 0.55)
		style.shadow_size = 18
		style.shadow_offset = Vector2.ZERO
		style.set_border_width_all(3)
		return style

	if selected:
		style.bg_color = Color(0.96, 0.66, 0.05, 0.96)
		style.border_color = Color(1.0, 0.95, 0.64, 0.86)
		style.shadow_color = Color(1.0, 0.95, 0.74, 0.34)
		style.shadow_size = 10
		style.shadow_offset = Vector2.ZERO
		style.set_border_width_all(2)
		return style

	style.bg_color = Color(0.72, 0.46, 0.04, 0.92)
	style.border_color = Color(1.0, 0.88, 0.42, 0.72)
	style.shadow_color = Color(1.0, 0.92, 0.58, 0.22)
	style.shadow_size = 8
	style.shadow_offset = Vector2.ZERO
	style.set_border_width_all(2)
	return style


static func _collect_reality_fusion_buttons(root: Node) -> Array:
	var out: Array = []
	if root == null:
		return out
	for child in root.get_children():
		if child is Button:
			out.append(child)
		out.append_array(_collect_reality_fusion_buttons(child))
	return out


static func _reality_fusion_source_identity_from_preview(source_player: Dictionary) -> String:
	var bits: Array = []

	var age: int = int(source_player.get("age", 0))
	if age > 0:
		bits.append("age %d" % age)

	var identity: String = str(source_player.get("identity", "")).strip_edges()
	if identity != "":
		bits.append(identity)

	var bending_type: String = str(source_player.get("bending_type", "none")).strip_edges()
	if bending_type != "" and bending_type.to_lower() != "none":
		if bending_type.to_lower() == "avatar":
			bits.append("Avatar")
		else:
			bits.append("%s bender" % bending_type.capitalize())

	if bool(source_player.get("avatar_state_unlocked", false)):
		bits.append("Avatar State unlocked")

	var traits: Array = source_player.get("traits", []) if typeof(source_player.get("traits", [])) == TYPE_ARRAY else []
	if not traits.is_empty():
		bits.append("%d traits" % traits.size())

	if bits.is_empty():
		return "a parallel identity"

	return ", ".join(bits)


static func _reality_fusion_animation_bucket(period_ms: float) -> int:
	var safe_period_ms: float = max(1.0, period_ms)
	return int(float(Time.get_ticks_msec()) / safe_period_ms)


static func _reality_fusion_loadout_effect_line(mode: String) -> String:
	match str(mode).strip_edges().to_lower():
		"stats_blend":
			return "Merge their stats into yours without fully stealing their identity."
		"stats_steal":
			return "Try to overpower their stats and pull the strongest values into your body. Resistance risk rises."
		"traits_merge":
			return "Blend personality traits into your identity. Useful, but it can create selfhood drift."
		"money_transfer":
			return "Pull money through interdimensional banking. Low body risk, messy timeline trace."
		"inventory_merge":
			return "Preserve inventory/artifact packets for crossover. Legendary objects may destabilize the save."
		"bending_transfer":
			return "Transfer bending mastery echoes. Avatar or multi-element influence can leave residue."
		"bring_person_family":
			return "Bring the saved character and close family branches into this universe."
		"friend_person":
			return "Try to bring the saved character alone as an ally or friend."
		"bring_family_member":
			return "Bring only the selected family member through the breach."
		_:
			return "Apply this reality layer through the fusion contract."


static func _read_reality_fusion_save_payload(path: String) -> Dictionary:
	var clean_path: String = str(path).strip_edges()
	if clean_path == "" or not FileAccess.file_exists(clean_path):
		return {}
	var lower_path: String = clean_path.to_lower()
	if lower_path.ends_with(".bin"):
		var f_bin = FileAccess.open(clean_path, FileAccess.READ)
		if f_bin == null:
			return {}
		var bytes: PackedByteArray = f_bin.get_buffer(f_bin.get_length())
		f_bin.close()
		var decoded: Variant = BinarySaveEngine.decode(bytes)
		return decoded if typeof(decoded) == TYPE_DICTIONARY else {}
	var f_json = FileAccess.open(clean_path, FileAccess.READ)
	if f_json == null:
		return {}
	var parsed: Variant = JSON.parse_string(f_json.get_as_text())
	f_json.close()
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


static func _reality_fusion_append_family_id(out: Array, seen: Dictionary, person_id: int) -> void:
	if person_id <= 0:
		return
	if seen.has(person_id):
		return
	seen [person_id] = true
	out.append(person_id)


static func _reality_fusion_gendered_family_label(npc: Dictionary, male_label: String, female_label: String, neutral_label: String) -> String:
	var gender: String = str(npc.get("gender", "")).strip_edges().to_lower()
	if gender == "male" or gender == "man" or gender == "boy":
		return male_label
	if gender == "female" or gender == "woman" or gender == "girl":
		return female_label
	return neutral_label


static func _reality_fusion_save_person_alive(npc: Dictionary) -> bool:
	if npc.is_empty():
		return false
	return bool(npc.get("alive", true))


static func _reality_fusion_merge_policy(scope: Array, friend_link: String, root_person_id: int = -1) -> Dictionary:
	return {
		"relationship_scope": scope.duplicate(true),
		"friend_link": friend_link,
		"root_person_id": root_person_id,
		"lineage_strategy": "preserve" if not scope.is_empty() else "none",
		"id_strategy": "remap_safe",
		"conflict_resolution": "parallel_identity",
		"world_integration": {
			"register_npcs": true,
			"rebuild_index": true,
			"ensure_lineage": not scope.is_empty()
		}
	}


static func _reality_fusion_stat_keys() -> Array:
	return [
		"health",
		"mental_health",
		"smarts",
		"looks",
		"imagination",
		"fertility",
		"satisfaction",
		"job_performance",
		"motivation",
		"ambition",
		"fame"
	]


static func _reality_fusion_mode_title(mode: String) -> String:
	match str(mode).strip_edges().to_lower():
		"stats_blend":
			return "Merge Stats"
		"stats_steal":
			return "STEAL Stats"
		"traits_merge":
			return "Take Traits"
		"money_transfer":
			return "Drain Money"
		"inventory_merge":
			return "Inventory"
		"bending_transfer":
			return "Transfer Bending"
		"bring_person_family", "parallel_identity_import":
			return "Bring Family"
		"friend_person":
			return "Bring Ally"
		"bring_family_member":
			return "Bring Family Member"
		"fusion_loadout":
			return "Fusion Loadout"
		_:
			return mode.capitalize()


static func _reality_fusion_mode_button_text(text: String, mode: String) -> String:
	match str(mode).strip_edges().to_lower():
		"stats_blend":
			return "🧬 %s" % text
		"stats_steal":
			return "🩸 %s" % text
		"traits_merge":
			return "🎭 %s" % text
		"money_transfer":
			return "💰 %s" % text
		"inventory_merge":
			return "🎒 %s" % text
		"bending_transfer":
			return "🌊 %s" % text
		"bring_person_family":
			return "👨‍👩‍👧 %s" % text
		"friend_person":
			return "🤝 %s" % text
		"bring_family_member":
			return "🧍 %s" % text
		"pick_family_member":
			return "🔎 %s" % text
		"enter_universe":
			return "🚪 %s" % text
		_:
			return text


static func _reality_fusion_mode_color(mode: String) -> Color:
	match str(mode).strip_edges().to_lower():
		"stats_blend":
			return Color(0.2, 0.36, 0.56, 0.92)
		"stats_steal":
			return Color(0.56, 0.13, 0.18, 0.94)
		"traits_merge":
			return Color(0.38, 0.22, 0.58, 0.92)
		"money_transfer":
			return Color(0.17, 0.48, 0.26, 0.92)
		"inventory_merge":
			return Color(0.44, 0.34, 0.18, 0.92)
		"bending_transfer":
			return Color(0.14, 0.4, 0.55, 0.92)
		"bring_person_family":
			return Color(0.42, 0.28, 0.58, 0.92)
		"friend_person":
			return Color(0.17, 0.46, 0.42, 0.92)
		"bring_family_member":
			return Color(0.46, 0.28, 0.52, 0.92)
		"pick_family_member":
			return Color(0.28, 0.35, 0.52, 0.92)
		"enter_universe":
			return Color(0.18, 0.18, 0.22, 0.92)
		"execute_fusion":
			return Color(0.6, 0.32, 0.12, 0.96)
		"clear_loadout":
			return Color(0.18, 0.18, 0.2, 0.88)
		_:
			return Color(0.24, 0.26, 0.28, 0.9)


static func _health_base_display_max(value: int) -> int:
	return max(100, int(value))


static func _build_player_stat_row_visual_signature(
	theme_key: String,
	title: String,
	is_hovered: bool,
	danger_state: bool,
	pulse_strength: float,
	flavor_visible: bool
) -> String:
	var pulse_bucket: int = int(round(clamp(pulse_strength, 0.0, 1.0) * 6.0))
	return "%s|%s|%s|%s|%s|%d" % [
		theme_key,
		title,
		str(is_hovered),
		str(danger_state),
		str(flavor_visible),
		pulse_bucket
	]


static func _ensure_player_stat_bar_fill_lens(bar: ProgressBar) -> PanelContainer:
	if bar == null:
		return null
	if not is_instance_valid(bar):
		return null

	var existing:= bar.get_node_or_null("StatFillLens") as PanelContainer
	if existing != null and is_instance_valid(existing):
		return existing

	var fill_lens:= PanelContainer.new()
	fill_lens.name = "StatFillLens"
	fill_lens.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill_lens.focus_mode = Control.FOCUS_NONE
	fill_lens.z_as_relative = true
	fill_lens.z_index = 1
	fill_lens.anchor_left = 0.0
	fill_lens.anchor_top = 0.0
	fill_lens.anchor_right = 0.0
	fill_lens.anchor_bottom = 1.0
	fill_lens.offset_left = 0.0
	fill_lens.offset_top = 0.0
	fill_lens.offset_right = 0.0
	fill_lens.offset_bottom = 0.0
	fill_lens.set_meta("stat_fill_lens_authority", "player_stat_overlay")
	fill_lens.set_meta("stat_fill_lens_width_source", "bar_value_over_bar_max_value")
	fill_lens.set_meta("stat_fill_lens_is_visual_only", true)

	bar.add_child(fill_lens)
	bar.move_child(fill_lens, 0)

	return fill_lens


static func _player_stat_fill_lens_style(fill_lens: PanelContainer) -> StyleBoxFlat:
	if fill_lens == null:
		return null
	if not is_instance_valid(fill_lens):
		return null

	if fill_lens.has_meta("stat_fill_lens_stylebox"):
		var cached: Variant = fill_lens.get_meta("stat_fill_lens_stylebox")
		if cached != null and cached is StyleBoxFlat:
			return cached as StyleBoxFlat

	var style:= StyleBoxFlat.new()
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0

	fill_lens.set_meta("stat_fill_lens_stylebox", style)
	fill_lens.add_theme_stylebox_override("panel", style)

	return style


static func _get_or_create_player_stat_row_stylebox(bar: ProgressBar, meta_key: String) -> StyleBoxFlat:
	var cached: Variant = null
	if bar != null and bar.has_meta(meta_key):
		cached = bar.get_meta(meta_key)
	if cached != null and cached is StyleBoxFlat:
		return cached as StyleBoxFlat
	var style:= StyleBoxFlat.new()
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	if bar != null:
		bar.set_meta(meta_key, style)
	return style


static func _format_commas_for_player_stats_bank(amount: int) -> String:
	var negative: bool = amount < 0
	var digits: String = str(abs(amount))
	var grouped: String = ""

	while digits.length() > 3:
		grouped = "," + digits.substr(digits.length() - 3, 3) + grouped
		digits = digits.substr(0, digits.length() - 3)

	grouped = digits + grouped

	if negative:
		grouped = "-" + grouped

	return grouped


static func _relationship_profile_death_cause_for(target: Person) -> String:
	if target == null:
		return "unknown causes"

	var cause_text: String = str(target.cause_of_death).strip_edges()
	if cause_text == "":
		cause_text = "unknown causes"

	return cause_text


static func _relationship_profile_dead_health_flavor(surface_context: Dictionary) -> String:
	var cause_text: String = str(surface_context.get("death_cause", "unknown causes")).strip_edges()
	if cause_text == "":
		cause_text = "unknown causes"

	var year_label: String = str(surface_context.get("death_year_label", "an unknown year")).strip_edges()
	if year_label == "":
		year_label = "an unknown year"

	var perspective: String = str(surface_context.get("narrative_perspective", "first_person")).strip_edges().to_lower()

	if perspective == "first_person":
		return "I died from %s in the year %s." % [cause_text, year_label]

	return "They died from %s in the year %s." % [cause_text, year_label]


static func _surface_stat_phrase(text: String, surface_context: Dictionary) -> String:
	var out: String = str(text).strip_edges()
	if out == "":
		return out

	var perspective: String = str(surface_context.get("narrative_perspective", "first_person")).strip_edges().to_lower()
	var replacements: Array = []

	if perspective == "third_person":
		replacements = [
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
	else:
		replacements = [
			["Your ", "My "],
			["your ", "my "],
			["your.", "my."],
			["your,", "my,"],
			["your!", "my!"],
			["your?", "my?"],
			["You are ", "I am "],
			["You feel ", "I feel "],
			["You can ", "I can "],
			["You look ", "I look "],
			["You process ", "I process "],
			["You think ", "I think "],
			["You carry ", "I carry "],
			["You ", "I "],
			[" you are ", " I am "],
			[" you feel ", " I feel "],
			[" you can ", " I can "],
			[" you look ", " I look "],
			[" you process ", " I process "],
			[" you think ", " I think "],
			[" you carry ", " I carry "],
			[" you do.", " I do."],
			[" you do,", " I do,"],
			[" whether you ", " whether I "],
			[" when you ", " when I "],
			[" if you ", " if I "],
			[" before you ", " before I "],
			[" while you ", " while I "],
			[" know you,", " know me,"],
			[" know you.", " know me."],
			[" toward you", " toward me"],
			[" away from you", " away from me"],
			[" around you", " around me"],
			[" under you", " under me"],
			[" above you", " above me"],
			[" beside you", " beside me"],
			[" with you", " with me"],
			[" for you", " for me"],
			[" from you", " from me"],
			[" to you", " to me"]
		]

	for pair in replacements:
		if pair.size() < 2:
			continue
		out = out.replace(str(pair [0]), str(pair [1]))

	return out


static func _relationship_bond_descriptor_for_ratio(ratio: float) -> String:
	var safe_ratio: float = clamp(float(ratio), 0.0, 1.0)

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


static func _relationship_bond_posthumous_descriptor(living_descriptor: String) -> String:
	var clean_descriptor: String = str(living_descriptor).strip_edges()
	if clean_descriptor == "":
		clean_descriptor = "Unknown"

	return "%s, Now Dead" % clean_descriptor


static func _relationship_bond_flavor_for_descriptor(descriptor: String, surface_context: Dictionary, posthumous: bool = false) -> String:
	var clean_descriptor: String = str(descriptor).strip_edges()
	var perspective: String = str(surface_context.get("narrative_perspective", "first_person")).strip_edges().to_lower()
	var surface_family: String = str(surface_context.get("surface_family", "")).strip_edges().to_lower()
	var descriptor_title_mode: String = str(surface_context.get("descriptor_title_mode", "")).strip_edges().to_lower()
	var relationship_card_owned: bool = bool(surface_context.get("relationship_card_labels_are_contract_owned", false)) \
or bool(surface_context.get("relationship_card_contract_engine_owned", false)) \
or surface_family == "institution_hub" \
or descriptor_title_mode == "bond_pov"

	var bond_object_label: String = str(surface_context.get("bond_object_label", "")).strip_edges()

	if bond_object_label == "":
		bond_object_label = "you" if perspective == "third_person" and relationship_card_owned else "them"

	if perspective == "third_person":
		if posthumous:
			match clean_descriptor:
				"Devoted":
					return "They trusted %s deeply and felt safest when they were close to %s." % [bond_object_label, bond_object_label]
				"Warm":
					return "They felt genuinely close to %s and usually read %s as safe, welcome company." % [bond_object_label, bond_object_label]
				"Open":
					return "They were comfortable around %s, even if some emotional distance was still there." % [bond_object_label]
				"Guarded":
					return "They recognized %s, but they were still protecting part of themselves around %s." % [bond_object_label, bond_object_label]
				"Cold":
					return "They did not feel fully settled around %s and kept their trust pulled back." % [bond_object_label]
				"Hostile":
					return "They felt tense around %s and would rather keep distance than closeness." % [bond_object_label]

			return "Their relationship with %s ended with unresolved emotional distance." % bond_object_label

		match clean_descriptor:
			"Devoted":
				return "They trust %s deeply and feel safest when they are close to %s." % [bond_object_label, bond_object_label]
			"Warm":
				return "They feel genuinely close to %s and usually read %s as safe, welcome company." % [bond_object_label, bond_object_label]
			"Open":
				return "They are comfortable around %s, even if some emotional distance is still there." % [bond_object_label]
			"Guarded":
				return "They recognize %s, but they are still protecting part of themselves around %s." % [bond_object_label, bond_object_label]
			"Cold":
				return "They do not feel fully settled around %s and keep their trust pulled back." % [bond_object_label]
			"Hostile":
				return "They feel tense around %s and would rather keep distance than closeness." % [bond_object_label]

		return ""

	if posthumous:
		match clean_descriptor:
			"Devoted":
				return "I trusted them deeply and felt safest when I was close to them."
			"Warm":
				return "I felt genuinely close to them and usually read them as safe, welcome company."
			"Open":
				return "I was comfortable around them, even if some emotional distance was still there."
			"Guarded":
				return "I recognized them, but I was still protecting part of myself around them."
			"Cold":
				return "I did not feel fully settled around them and kept my trust pulled back."
			"Hostile":
				return "I felt tense around them and would rather keep distance than closeness."

		return "My relationship with them ended with unresolved emotional distance."

	match clean_descriptor:
		"Devoted":
			return "I trust them deeply and feel safest when I am close to them."
		"Warm":
			return "I feel genuinely close to them and usually read them as safe, welcome company."
		"Open":
			return "I am comfortable around them, even if some emotional distance is still there."
		"Guarded":
			return "I recognize them, but I am still protecting part of myself around them."
		"Cold":
			return "I do not feel fully settled around them and keep my trust pulled back."
		"Hostile":
			return "I feel tense around them and would rather keep distance than closeness."

	return ""


static func _player_is_government_figure(p: Person) -> bool:
	if p == null:
		return false

	if bool(p.is_ruler):
		return true

	if bool(p.is_royal) or str(p.royal_title).strip_edges() != "":
		return true

	if int(p.succession_rank) >= 0 and int(p.succession_rank) <= 12:
		return true

	var office_fields: Array = [
		"government_role",
		"government_title",
		"political_office",
		"office_title",
		"elected_office",
		"public_office"
	]

	for field_name in office_fields:
		var raw_value: Variant = p.get(str(field_name))
		if raw_value != null and str(raw_value).strip_edges() != "":
			return true

	if typeof(p.traits) == TYPE_ARRAY:
		for raw_trait in p.traits:
			var trait_text: String = str(raw_trait).strip_edges().to_lower()
			if trait_text in [
				"president",
				"prime_minister",
				"governor",
				"mayor",
				"senator",
				"representative",
				"council_member",
				"minister",
				"chancellor",
				"government_official",
				"elected_official"
			]:
				return true

	return false


static func _build_runtime_floating_hud_button_style(
	core_color: Color,
	state: String
) -> StyleBoxFlat:
	var clean_state: String = str(state).strip_edges().to_lower()

	var background: Color = core_color.darkened(0.74)
	var border_alpha: float = 0.64
	var border_width: int = 1
	var shadow_alpha: float = 0.24
	var shadow_size: int = 8

	match clean_state:
		"hover":
			background = core_color.darkened(0.62)
			border_alpha = 0.96
			border_width = 2
			shadow_alpha = 0.48
			shadow_size = 16
		"pressed":
			background = core_color.darkened(0.82)
			border_alpha = 1.0
			border_width = 2
			shadow_alpha = 0.36
			shadow_size = 10
		"focus":
			background = core_color.darkened(0.66)
			border_alpha = 0.92
			border_width = 2
			shadow_alpha = 0.42
			shadow_size = 14
		"disabled":
			background = core_color.darkened(0.84)
			border_alpha = 0.22
			border_width = 1
			shadow_alpha = 0.06
			shadow_size = 3

	background.a = 0.97

	var style:= StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = Color(
		core_color.r,
		core_color.g,
		core_color.b,
		border_alpha
	)
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(16)
	style.shadow_color = Color(
		core_color.r,
		core_color.g,
		core_color.b,
		shadow_alpha
	)
	style.shadow_size = shadow_size
	style.shadow_offset = Vector2.ZERO
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0

	return style


static func _runtime_floating_hud_force_key(hud_id: String) -> String:
	return "__runtime_floating_hud_force_keep_open_%s" % str(hud_id).strip_edges().to_lower()


static func _bending_hub_surface_cache_signature_for_state(
	source_gs: GameState
) -> String:
	if source_gs == null or source_gs.player == null:
		return ""

	var actor: Person = source_gs.player
	var parts: Array = [
		"schema:eralife.bending_hub_surface_cache",
		"actor:%d" % int(actor.id),
		"year:%d" % int(source_gs.year),
		"age:%d" % int(actor.age),
		"type:%s" % str(actor.bending_type),
		"nation:%s" % str(actor.bending_nation),
		"skill_points:%d" % int(actor.bending_skill_points),
		"avatar_unlocked:%s" % str(actor.avatar_state_unlocked),
		"avatar_used:%s" % str(actor.avatar_state_used)
	]

	for element in ["air", "water", "earth", "fire"]:
		parts.append(
			"%s_mastery:%s"
			% [
				element,
				str(
					actor.bending_mastery.get(
						element,
						0
					)
				)
			]
		)
		parts.append(
			"%s_potential:%s"
			% [
				element,
				str(
					actor.bending_latent_potential.get(
						element,
						0
					)
				)
			]
		)

	if typeof(
		actor.bending_tournament_profile
	) == TYPE_DICTIONARY:
		parts.append(
			"tournament_profile:%s"
			% str(
				actor.bending_tournament_profile
			)
		)

	if typeof(
		source_gs.scenario_state
	) == TYPE_DICTIONARY:
		var world_raw: Variant = (
			source_gs.scenario_state.get(
				"bending_world_championship",
				{}
			)
		)

		if typeof(world_raw) == TYPE_DICTIONARY:
			var world_state: Dictionary = world_raw

			parts.append(
				"bending_world_version:%s"
				% str(
					world_state.get(
						"version",
						0
					)
				)
			)
			parts.append(
				"bending_world_projection_revision:%s"
				% str(
					world_state.get(
						"projection_revision",
						0
					)
				)
			)
			parts.append(
				"bending_world_last_report:%s"
				% str(
					world_state.get(
						"last_report",
						{}
					)
				)
			)

	return "|".join(parts)


static func _food_lifestyle_actor_is_old_enough(actor: Person) -> bool:
	return actor != null and int(actor.age) >= 15


static func _food_lifestyle_normalized_era_key_for_mainscene(era_name: String) -> String:
	var clean: String = str(era_name).strip_edges().to_lower()
	clean = clean.replace(" era", "")
	clean = clean.replace(" ", "_")
	return clean


static func _food_lifestyle_era_key_from_year_for_mainscene(year_value: int) -> String:
	if year_value <= 499:
		return "Ancient"
	if year_value <= 1799:
		return "Medieval"
	if year_value <= 1949:
		return "Industrial"
	if year_value <= 2049:
		return "Modern"
	return "Future"


static func _restaurant_lifestyle_empty_surface_state() -> Dictionary:
	return {
		"restaurant_mode": "",
		"restaurant_plan_chosen": false,
		"restaurant_category": "",
		"restaurant_id": "",
		"restaurant_service_mode": "",
		"candidate_id": -1,
		"candidate_name": "",
		"date_partner_id": -1,
		"date_partner_name": "",
		"notice": ""
	}


static func _rick_weapon_shop_population_count_text(value: int) -> String:
	var clean_value: int = max(0, int(value))
	if clean_value == 1:
		return "1 person"
	return "%d people" % clean_value


static func _rick_weapon_shop_tracker_title(tracker_key: String) -> String:
	match tracker_key:
		"walking_by":
			return "People Walking By"
		"walking_in":
			return "People Walking In"
		"walking_out":
			return "People Walking Out"
		"browsing":
			return "People Browsing"
		"checking_out":
			return "Person Checking Out"
		"inside_all":
			return "People In The Store"
		_:
			return "Live People"


static func _rick_weapon_shop_weapon_danger_scope(weapon: Dictionary) -> String:
	var weapon_type: String = str(weapon.get("type", "weapon")).strip_edges().to_lower()
	var legal: bool = bool(weapon.get("legal", true))
	var license_required: bool = bool(weapon.get("license_required", false))

	if not legal:
		return "Restricted / reputation-warping / guard-attracting"

	match weapon_type:
		"gun":
			return "High lethality, loud consequences" if license_required else "High lethality, fast escalation"
		"energy":
			return "Reality-bending tech danger"
		"blade":
			return "Close-range danger, personal consequences"
		"ranged":
			return "Distance danger, confidence trap"
		_:
			return "Unknown object danger, which is Rick's least favorite kind"


static func _rick_weapon_shop_weapon_disaster_line(weapon: Dictionary) -> String:
	var weapon_type: String = str(weapon.get("type", "weapon")).strip_edges().to_lower()
	match weapon_type:
		"blade":
			return "I saw one of those turn a wedding into a family tree with missing branches."
		"ranged":
			return "I saw somebody miss the target and hit their grandma once."
		"gun":
			return "I saw one make a loud man quiet and a quiet room happy."
		"energy":
			return "I saw one turn a locked door into weather. Nobody enjoyed the breeze."
		_:
			return "I saw one go wrong once. The object apologized before the person did."


static func _rick_weapon_shop_live_flow_count(rng: RandomNumberGenerator, chance: float = 0.65, max_group: int = 5) -> int:
	var clean_chance: float = clamp(chance, 0.0, 1.0)
	var clean_max: int = int(clamp(max_group, 1, 5))
	if rng.randf() > clean_chance:
		return 0

	var roll: float = rng.randf()
	if clean_max >= 5 and roll >= 0.96:
		return 5
	if clean_max >= 4 and roll >= 0.9:
		return 4
	if clean_max >= 3 and roll >= 0.78:
		return 3
	if clean_max >= 2 and roll >= 0.54:
		return 2
	return 1


static func _rick_weapon_shop_random_jitter_ms(min_ms: int, max_ms: int) -> int:
	var rng:= RandomNumberGenerator.new()
	rng.randomize()
	return int(rng.randi_range(min_ms, max_ms))


static func _rick_weapon_shop_random_checkout_line() -> String:
	var rng:= RandomNumberGenerator.new()
	rng.randomize()
	var lines: Array = [
		"Customer: \"Thanks, Rick.\"\nRick: \"Try not to make the local guards learn your name.\"",
		"Customer: \"Do you do refunds?\"\nRick: \"Only in timelines nobody likes.\"",
		"Customer: \"Bye, Rick.\"\nRick: \"Walk slowly. Fast people explain themselves to doctors.\"",
		"Customer: \"Is this safe?\"\nRick: \"That question gets cheaper before the purchase.\""
	]
	return str(lines [int(rng.randi_range(0, lines.size() - 1))])


static func _rick_weapon_shop_section_panel(bg_color: Color, border_color: Color) -> PanelContainer:
	var panel:= PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style:= StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(20)
	style.shadow_color = Color(1.0, 0.38, 0.1, 0.14)
	style.shadow_size = 12
	panel.add_theme_stylebox_override("panel", style)

	var margin:= MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	panel.set_meta("margin", margin)

	return panel


static func _rick_weapon_shop_clean_location_value(raw_value: Variant) -> String:
	if raw_value == null:
		return ""
	var text: String = str(raw_value).strip_edges()
	var lowered: String = text.to_lower()
	if text == "" or lowered in ["<null>", "null", "none", "nil", "n/a", "unknown"]:
		return ""
	return text


static func _rick_weapon_shop_local_culture_tag(country: String) -> String:
	var normalized: String = str(country).strip_edges().to_lower()
	var exact_map: Dictionary = {
		"china": "Chinese",
		"ancient china": "Chinese",
		"greece": "Greek",
		"ancient greece": "Greek",
		"mali": "from Mali",
		"mali empire": "from Mali",
		"assyria": "Assyrian",
		"assyrian empire": "Assyrian",
		"mexico": "Mexican",
		"canada": "Canadian",
		"united states": "American",
		"america": "American",
		"usa": "American"
	}

	if exact_map.has(normalized):
		return str(exact_map.get(normalized))
	if normalized.find("air temple") >= 0:
		return "a monk"
	if normalized.find("fire nation") >= 0:
		return "Fire Nation"
	if normalized.find("earth kingdom") >= 0:
		return "Earth Kingdom"
	if normalized.find("southern water") >= 0:
		return "Southern Water Nation"
	if normalized.find("northern water") >= 0:
		return "Northern Water Nation"
	if normalized.find("water tribe") >= 0:
		return "Water Tribe"
	if normalized.find("china") >= 0:
		return "Chinese"
	if normalized.find("mali") >= 0:
		return "from Mali"
	if normalized.find("assyr") >= 0:
		return "Assyrian"
	if normalized.find("mexico") >= 0:
		return "Mexican"
	if normalized.find("canada") >= 0:
		return "Canadian"
	if normalized.find("america") >= 0 or normalized.find("united states") >= 0:
		return "American"

	var clean_country: String = str(country).strip_edges()
	if clean_country == "":
		return "local"
	return "from %s" % clean_country


static func _bending_hub_valid_sections() -> Array:
	return ["profile", "stats", "training", "skill_points", "abilities", "tournaments"]


static func _bending_hub_section_title(section: String) -> String:
	var clean_section: String = str(section).strip_edges().to_lower()
	match clean_section:
		"profile":
			return "PROFILE"
		"stats":
			return "STATS"
		"tournaments":
			return "TOURNAMENTS"
		"training":
			return "TRAINING"
		"skill_points":
			return "SKILL POINTS"
		"abilities":
			return "ABILITIES"
		_:
			return "PROFILE"


static func _bending_hub_willpower_descriptor(value: int) -> String:
	if value >= 900:
		return "Avatar Limitless"
	if value >= 180:
		return "Mythic"
	if value >= 150:
		return "Legendary"
	if value >= 120:
		return "Unbreakable"
	if value >= 95:
		return "Iron"
	if value >= 75:
		return "Strong"
	if value >= 55:
		return "Steady"
	if value >= 35:
		return "Shaken"
	if value >= 15:
		return "Breaking"
	return "Collapsed"


static func _make_bending_hub_section_label(text: String) -> Label:
	var label:= Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0, 0.96))
	return label


static func _bending_hub_ability_visual_profile_from_ability(ability: Dictionary) -> Dictionary:
	var profile:= {
		"visual_tier": str(ability.get("visual_tier", "low")),
		"visual_rank": int(ability.get("visual_rank", 1)),
		"visual_label": str(ability.get("visual_label", "Subtle Glow")),
		"aura_radius": int(ability.get("aura_radius", 12)),
		"aura_alpha": float(ability.get("aura_alpha", 0.22)),
		"pulse_speed": float(ability.get("pulse_speed", 0.85)),
		"distortion": bool(ability.get("distortion", false)),
		"legendary_vignette": bool(ability.get("legendary_vignette", false)),
		"legendary_mastery": bool(ability.get("legendary_mastery", false)),
		"corrupted_bending": bool(ability.get("corrupted_bending", false)),
		"avatar_pulse": bool(ability.get("avatar_pulse", false)),
		"element": str(ability.get("element", "")).strip_edges().to_lower()
	}

	return profile


static func _bending_hub_level_surface(element: String, level: int) -> Dictionary:
	var clean_element: String = str(element).strip_edges().to_lower()
	var safe_level: int = clamp(int(level), 0, 100)

	var descriptor: String = "Dormant"
	var flavor: String = "The element is present, but it has not truly answered you yet."

	if safe_level >= 95:
		descriptor = "Mythic"
		flavor = "Your bending feels almost legendary. The element moves like it already knows your intent."
	elif safe_level >= 85:
		descriptor = "Masterful"
		flavor = "Your control is disciplined, dangerous, and respected. Very few benders ever reach this level."
	elif safe_level >= 70:
		descriptor = "Elite"
		flavor = "Your technique is sharp enough to change the outcome of serious danger."
	elif safe_level >= 55:
		descriptor = "Formidable"
		flavor = "Your bending has become reliable under pressure, though mastery still demands more."
	elif safe_level >= 40:
		descriptor = "Focused"
		flavor = "Your element responds with purpose. You are no longer just practicing; you are shaping."
	elif safe_level >= 25:
		descriptor = "Awakening"
		flavor = "Your bending is becoming useful, but real control still slips when pressure rises."
	elif safe_level >= 10:
		descriptor = "Unsteady"
		flavor = "The element answers in flashes. You can do something now, but not safely every time."
	elif safe_level > 0:
		descriptor = "Flickering"
		flavor = "The gift is there, but fragile. Training matters more than raw talent right now."

	match clean_element:
		"air":
			if safe_level >= 85:
				flavor = "Your airbending is calm, precise, and nearly untouchable when you stay centered."
			elif safe_level >= 40:
				flavor = "Your airbending has started to feel light, reactive, and hard to pin down."
			elif safe_level > 0:
				flavor = "Your airbending arrives in uneven bursts, like wind learning your name."
		"water":
			if safe_level >= 85:
				flavor = "Your waterbending flows with frightening patience, shifting from healing to control with ease."
			elif safe_level >= 40:
				flavor = "Your waterbending is becoming adaptable, defensive, and emotionally responsive."
			elif safe_level > 0:
				flavor = "Your waterbending moves in small surges, still tied closely to your focus."
		"earth":
			if safe_level >= 85:
				flavor = "Your earthbending feels immovable. The ground itself seems to trust your command."
			elif safe_level >= 40:
				flavor = "Your earthbending is getting heavier, steadier, and harder to break."
			elif safe_level > 0:
				flavor = "Your earthbending is rough but real, like stone shifting under a new voice."
		"fire":
			if safe_level >= 85:
				flavor = "Your firebending is controlled power, no longer just heat but discipline."
			elif safe_level >= 40:
				flavor = "Your firebending burns cleaner now, stronger without becoming reckless."
			elif safe_level > 0:
				flavor = "Your firebending sparks with potential, but it still needs breath and restraint."

	return {
		"title_text": "%s: %s" % [clean_element.capitalize(), descriptor],
		"descriptor": descriptor,
		"flavor": flavor,
		"bar_text": "Level %d" % safe_level
	}


static func _bending_hub_ability_progress_text(ability: Dictionary, _player_age: int) -> String:
	var ability_name: String = str(ability.get("name", "Unknown Skill"))
	var current_level: int = int(ability.get("current_level", 0))
	var unlocked: bool = bool(ability.get("unlocked", false))
	var on_cooldown: bool = bool(ability.get("on_cooldown", false))
	var lock_text: String = str(ability.get("lock_text", "")).strip_edges()
	var upgrade_level: int = int(ability.get("upgrade_level", 0))
	var max_upgrade_level: int = int(ability.get("max_upgrade_level", 0))

	if on_cooldown:
		return "%s - Recovering" % ability_name

	if not unlocked:
		if lock_text == "":
			lock_text = "Unlock path incomplete"
		return "%s - Locked: %s" % [ability_name, lock_text]

	var tier_text: String = "Tier %d/%d" % [upgrade_level, max_upgrade_level] if max_upgrade_level > 0 else "Tier %d" % upgrade_level

	return "%s - Ready • %s • Level %d/100" % [
		ability_name,
		tier_text,
		current_level
	]


static func _bending_hub_ability_type_label(raw_type: String) -> String:
	var clean_type: String = str(raw_type).strip_edges().to_lower()
	match clean_type:
		"attack":
			return "Attack"
		"control":
			return "Control"
		"heal":
			return "Healing"
		"defense":
			return "Defense"
		"escape":
			return "Movement"
		_:
			return "Technique"


static func _bending_hub_category_bundle_text(bundle: Dictionary) -> String:
	if bundle.is_empty():
		return "No category bundle"

	var ordered_keys: Array = ["accuracy", "power", "guard", "counter", "evasion", "focus"]
	var parts: Array = []
	var used: Dictionary = {}

	for stat_name in ordered_keys:
		if not bundle.has(stat_name):
			continue

		parts.append("%s %d+" % [
			str(stat_name).capitalize(),
			int(bundle.get(stat_name, 0))
		])
		used [stat_name] = true

	for raw_key in bundle.keys():
		var clean_key: String = str(raw_key).strip_edges().to_lower()
		if clean_key == "" or bool(used.get(clean_key, false)):
			continue

		parts.append("%s %d+" % [
			clean_key.capitalize(),
			int(bundle.get(raw_key, 0))
		])

	if parts.is_empty():
		return "No category bundle"

	return ", ".join(parts)


static func _spirit_world_person_label(person: Person) -> String:
	if person == null:
		return "Unknown"

	var first_name: String = ""
	var last_name: String = ""

	if "first_name" in person:
		first_name = str(person.first_name).strip_edges()
	if "last_name" in person:
		last_name = str(person.last_name).strip_edges()

	var full_name: String = ("%s %s" % [first_name, last_name]).strip_edges()
	if full_name != "":
		return full_name

	if "name" in person:
		var direct_name: String = str(person.name).strip_edges()
		if direct_name != "":
			return direct_name

	return "Person #%d" % int(person.id)


static func _runtime_stylebox_flat_from_meta(meta_target: Object, meta_key: String, border_width: int = 2, corner_radius: int = 16) -> StyleBoxFlat:
	if meta_target == null:
		return null

	var raw_style: Variant = null
	if meta_target.has_meta(meta_key):
		raw_style = meta_target.get_meta(meta_key)

	if raw_style is StyleBoxFlat:
		return raw_style as StyleBoxFlat

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius

	meta_target.set_meta(meta_key, style)
	return style


static func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)


static func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


static func _make_wizard_hub_label(text: String) -> Label:
	var label:= Label.new()
	label.text = str(text)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	return label


static func _make_wizard_hub_body(text: String) -> RichTextLabel:
	var body:= RichTextLabel.new()
	body.bbcode_enabled = false
	body.fit_content = true
	body.scroll_active = false
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.text = str(text)
	return body


static func _make_wizard_hub_button(text: String) -> Button:
	var button:= Button.new()
	button.text = str(text)
	button.custom_minimum_size = Vector2(0, 42)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button


static func _baseline_property_social_tier_for_actor(actor: Person) -> String:
	if actor == null:
		return "common"

	var raw_class: String = str(actor.social_class).strip_edges().to_lower()
	if raw_class == "":
		raw_class = str(actor.get("class") if actor.has_method("get") else "").strip_edges().to_lower()

	match raw_class:
		"poor", "lower", "lower class", "working", "working class", "commoner":
			return "working"
		"middle", "middle class", "merchant":
			return "common"
		"upper", "upper class", "wealthy", "rich":
			return "wealthy"
		"royal", "king", "queen", "prince", "princess":
			return "royal"
		"noble", "elite", "aristocrat":
			return "noble"
		_:
			return "common"


static func _artifact_item_color(item: Dictionary) -> Color:
	var color_key: String = str(item.get("color", "")).strip_edges().to_lower()
	var item_name: String = str(item.get("name", "")).strip_edges().to_lower()
	var dragon_star: int = int(item.get("star", 0))

	if dragon_star <= 0 and item_name.findn("-star dragon ball") != -1:
		var star_chunks: PackedStringArray = item_name.split("-star dragon ball")
		if star_chunks.size() > 0:
			dragon_star = int(star_chunks [0])

	if color_key == "":
		if item_name.findn("red bonnet") != -1:
			color_key = "red"
		elif item_name.findn("dragon ball") != -1:
			color_key = "orange"
		elif item_name.findn("gauntlet") != -1:
			color_key = "gold"

	match color_key:
		"red":
			return Color(1.0, 0.26, 0.24, 1.0)
		"blue":
			return Color(0.28, 0.72, 1.0, 1.0)
		"green", "emerald":
			return Color(0.24, 1.0, 0.54, 1.0)
		"yellow":
			return Color(1.0, 0.91, 0.26, 1.0)
		"orange":
			if item_name.findn("dragon ball") != -1 or dragon_star > 0:
				var star_heat: float = clamp(float(max(dragon_star, 1) - 1) / 6.0, 0.0, 1.0)
				return Color(1.0, 0.62, 0.22, 1.0).lerp(Color(1.0, 0.82, 0.3, 1.0), 0.18 + star_heat * 0.34)
			return Color(1.0, 0.62, 0.22, 1.0)
		"violet", "purple":
			return Color(0.72, 0.48, 1.0, 1.0)
		"gold":
			return Color(1.0, 0.84, 0.36, 1.0)
		"silver":
			return Color(0.84, 0.9, 1.0, 1.0)
		"white":
			return Color(0.96, 0.98, 1.0, 1.0)
		"crimson":
			return Color(1.0, 0.3, 0.42, 1.0)
		_:
			return Color(1.0, 0.82, 0.36, 1.0)


static func _read_browser_origin() -> String:
	if not OS.has_feature("web"):
		return ""

	if not ClassDB.class_exists("JavaScriptBridge"):
		return ""

	var origin_raw: Variant = JavaScriptBridge.eval("window.location.origin || ''", true)
	return str(origin_raw).strip_edges().trim_suffix("/")


static func _read_browser_base_path() -> String:
	if not OS.has_feature("web"):
		return ""

	if not ClassDB.class_exists("JavaScriptBridge"):
		return ""

	var path_raw: Variant = JavaScriptBridge.eval("window.location.pathname || ''", true)
	var path: String = str(path_raw).strip_edges()
	if path == "":
		return ""

	var play_index: int = path.find("/play/")
	if play_index >= 0:
		return path.substr(0, play_index).trim_suffix("/")

	var mobile_index: int = path.find("/m/play/")
	if mobile_index >= 0:
		return path.substr(0, mobile_index).trim_suffix("/")

	var tv_index: int = path.find("/tv/play/")
	if tv_index >= 0:
		return path.substr(0, tv_index).trim_suffix("/")

	if path.ends_with("/index.html"):
		return path.trim_suffix("/index.html").trim_suffix("/")

	return ""


static func _read_browser_url() -> String:
	if not OS.has_feature("web"):
		return ""

	if not ClassDB.class_exists("JavaScriptBridge"):
		return ""

	var href_raw: Variant = JavaScriptBridge.eval("window.location.href", true)
	return str(href_raw).strip_edges()


static func _query_value_from_url(url: String, key: String) -> String:
	var clean_url: String = str(url).strip_edges()
	if clean_url == "":
		return ""

	var sections: Array = []

	var query_start: int = clean_url.find("?")
	if query_start >= 0:
		var query: String = clean_url.substr(query_start + 1)
		var hash_start: int = query.find("#")
		if hash_start >= 0:
			query = query.substr(0, hash_start)
		sections.append(query)

	var hash_index: int = clean_url.find("#")
	if hash_index >= 0:
		var hash_query: String = clean_url.substr(hash_index + 1)
		if hash_query.begins_with("?"):
			hash_query = hash_query.substr(1)
		sections.append(hash_query)

	for section_raw in sections:
		var section: String = str(section_raw)
		for raw_part in section.split("&", false):
			var part: String = str(raw_part)
			var eq_index: int = part.find("=")
			var raw_key: String = part if eq_index < 0 else part.substr(0, eq_index)
			var raw_value: String = "" if eq_index < 0 else part.substr(eq_index + 1)

			if raw_key.uri_decode() == key:
				return raw_value.uri_decode()

	return ""


static func _world_feed_stone_inline_color(stone_name: String) -> Color:
	match stone_name:
		"Mind Stone":
			return Color(1.0, 0.92, 0.22, 1.0)
		"Space Stone":
			return Color(0.3, 0.58, 1.0, 1.0)
		"Reality Stone":
			return Color(1.0, 0.26, 0.34, 1.0)
		"Power Stone":
			return Color(0.7, 0.4, 1.0, 1.0)
		"Time Stone":
			return Color(0.24, 0.92, 0.46, 1.0)
		"Soul Stone":
			return Color(1.0, 0.58, 0.16, 1.0)
		_:
			return Color(1.0, 1.0, 1.0, 1.0)


static func _super_runtime_superhero_profile_has_access(profile: Dictionary) -> bool:
	if profile.is_empty():
		return false

	if bool(profile.get("hub_unlocked", false)):
		return true

	var alignment: String = str(profile.get("alignment", "civilian")).strip_edges().to_lower()
	if alignment != "" and alignment != "civilian":
		return true

	var registration_status: String = str(profile.get("registration_status", "unregistered")).strip_edges().to_lower()
	if registration_status not in ["", "unregistered", "unknown"]:
		return true

	if bool(profile.get("birth_power_configured", false)):
		return true

	var alias_name: String = str(profile.get("public_alias", "")).strip_edges()
	if alias_name != "":
		return true

	return false


static func _build_superpower_hub_panel_style() -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.018, 0.09, 0.985)
	style.border_color = Color(0.9, 0.48, 1.0, 0.86)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 30
	style.corner_radius_top_right = 30
	style.corner_radius_bottom_left = 30
	style.corner_radius_bottom_right = 30
	style.content_margin_left = 22
	style.content_margin_top = 20
	style.content_margin_right = 22
	style.content_margin_bottom = 20
	style.shadow_color = Color(0.7, 0.2, 1.0, 0.36)
	style.shadow_size = 38
	style.shadow_offset = Vector2(0, 12)
	return style


static func _superpower_hub_actor_label(actor: Person) -> String:
	if actor == null:
		return "Unknown"

	var first_name: String = str(actor.get("first_name")).strip_edges()
	var last_name: String = str(actor.get("last_name")).strip_edges()
	var full_name: String = ("%s %s" % [first_name, last_name]).strip_edges()

	if full_name != "":
		return full_name
	if first_name != "":
		return first_name
	if last_name != "":
		return last_name

	return "Unknown"


static func _surface_guard_context_allows_render(context: Dictionary = {}) -> bool:
	if typeof(context) != TYPE_DICTIONARY:
		return false

	if bool(context.get("render_surface", false)):
		return true
	if bool(context.get("surface_already_asserted", false)):
		return true
	if bool(context.get("ui_must_not_wait_for_runtime", false)):
		return true
	if bool(context.get("surface_render_contract", false)):
		return true

	var intent: String = str(context.get("intent", context.get("mode", ""))).strip_edges().to_lower()
	if intent in ["render_surface", "surface_click", "open_surface", "assert_surface", "ui_render", "pre_life_surface"]:
		return true

	var source: String = str(context.get("source", "")).strip_edges().to_lower()
	if source.find("surface") >= 0 and source.find("render") >= 0:
		return true
	if source.find("pressed") >= 0 or source.find("clicked") >= 0:
		return true

	return false


static func _runtime_boot_cie_domain_for_action(domain_id: String, action_id: String) -> String:
	var clean_action: String = str(action_id).strip_edges().to_lower()

	if clean_action in ["track_villain", "respond_to_crime", "patrol_city"]:
		return "villains"
	if clean_action in ["recruit_ally", "recruit_sidekick", "start_team"]:
		return "sidekicks"
	if clean_action.find("duel") >= 0 and str(domain_id).strip_edges().to_lower() == "bending":
		return "bending_duels"

	return str(domain_id).strip_edges().to_lower()


static func _runtime_boot_domain_for_hub_action(action: Dictionary, fallback_domain: String, engine_property: String, payload: Dictionary) -> String:
	var clean_engine: String = str(engine_property).strip_edges().to_lower()
	if clean_engine == "power_engine":
		return "powers"
	if clean_engine == "superhero_engine":
		return "superhero"
	if clean_engine == "artifacts_engine":
		return "artifacts"
	if clean_engine == "bending_engine":
		return "bending"

	var action_id: String = str(action.get("id", payload.get("action", ""))).strip_edges().to_lower()

	if action_id.find("crime") >= 0 or action_id.find("villain") >= 0 or action_id.find("patrol") >= 0 or action_id.find("team") >= 0 or action_id.find("ally") >= 0 or action_id.find("register") >= 0:
		return "superhero"

	if action_id.find("power") >= 0 or action_id.find("mutation") >= 0 or action_id.find("training") >= 0 or action_id.find("subskill") >= 0:
		return "powers"

	if action_id.find("artifact") >= 0 or action_id.find("stone") >= 0:
		return "artifacts"

	if action_id.find("bending") >= 0 or action_id.find("dojo") >= 0:
		return "bending"

	return str(fallback_domain).strip_edges().to_lower()


static func _build_superpower_hub_entry_style() -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.035, 0.14, 0.78)
	style.border_color = Color(0.92, 0.54, 1.0, 0.38)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.content_margin_left = 14
	style.content_margin_top = 12
	style.content_margin_right = 14
	style.content_margin_bottom = 12
	return style


static func _build_power_hub_panel_style() -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.038, 0.075, 0.985)
	style.border_color = Color(0.38, 0.72, 1.0, 0.86)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 30
	style.corner_radius_top_right = 30
	style.corner_radius_bottom_left = 30
	style.corner_radius_bottom_right = 30
	style.content_margin_left = 22
	style.content_margin_top = 20
	style.content_margin_right = 22
	style.content_margin_bottom = 20
	style.shadow_color = Color(0.15, 0.45, 1.0, 0.34)
	style.shadow_size = 38
	style.shadow_offset = Vector2(0, 12)
	return style


static func _build_power_hub_entry_style() -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.06, 0.12, 0.78)
	style.border_color = Color(0.38, 0.72, 1.0, 0.38)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.content_margin_left = 14
	style.content_margin_top = 12
	style.content_margin_right = 14
	style.content_margin_bottom = 12
	return style


static func _crown_hub_mood_color(summary: Dictionary) -> Color:
	var happiness_value: int = clampi(int(summary.get("happiness", 50)), 0, 100)
	var approval_value: int = clampi(int(summary.get("approval", 50)), 0, 100)

	if happiness_value <= 24 or approval_value <= 24:
		return Color(0.34, 0.06, 0.07, 1.0)
	if happiness_value <= 44 or approval_value <= 44:
		return Color(0.32, 0.14, 0.06, 1.0)
	if happiness_value >= 78 and approval_value >= 70:
		return Color(0.1, 0.2, 0.14, 1.0)

	return Color(0.06, 0.08, 0.13, 1.0)


static func _crown_hub_ensure_named_label(parent: Control, node_name: String, font_size: int = 13) -> Label:
	if parent == null:
		return null

	var existing: Label = parent.get_node_or_null(node_name) as Label
	if existing != null:
		return existing

	var label:= Label.new()
	label.name = node_name
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


static func _crown_hub_projection_color(delta_value: int) -> Color:
	if delta_value > 0:
		return Color(0.45, 1.0, 0.58, 1.0)
	if delta_value < 0:
		return Color(1.0, 0.38, 0.3, 1.0)
	return Color(0.82, 0.82, 0.78, 0.92)


static func _crown_diplomacy_entry_key(
	entry: Dictionary
) -> String:
	var entry_key: String = str(
		entry.get(
			"realm_key",
			""
		)
	).strip_edges()

	if entry_key != "":
		return entry_key

	var realm_id: int = int(
		entry.get(
			"realm_id",
			-1
		)
	)

	if realm_id > 0:
		return "realm:%d" % realm_id

	return "country:%s" % str(
		entry.get(
			"country",
			"unknown"
		)
	).strip_edges().to_lower()


static func _crown_diplomacy_filter_specs() -> Array:
	return [
		{
			"key": "all",
			"label": "All"
		},
		{
			"key": "elemental",
			"label": "Elemental"
		},
		{
			"key": "empires",
			"label": "Empires"
		},
		{
			"key": "kingdoms",
			"label": "Kingdoms"
		},
		{
			"key": "republics",
			"label": "Republics"
		},
		{
			"key": "allies",
			"label": "Allies"
		},
		{
			"key": "neutral",
			"label": "Neutral"
		},
		{
			"key": "strained",
			"label": "Strained"
		},
		{
			"key": "war",
			"label": "At War"
		},
		{
			"key": "tradable",
			"label": "Tradable"
		},
		{
			"key": "era_kingdom",
			"label": "Era Kingdom"
		}
	]


static func _crown_diplomacy_entry_core_color(
	entry: Dictionary
) -> Color:
	if bool(
		entry.get(
			"is_era_kingdom",
			false
		)
	):
		return Color(
			0.72,
			0.34,
			1.0,
			1.0
		)

	if bool(
		entry.get(
			"is_player_country",
			false
		)
	):
		return Color(
			1.0,
			0.76,
			0.2,
			1.0
		)

	match str(
		entry.get(
			"element",
			""
		)
	).strip_edges().to_lower():
		"fire":
			return Color(
				1.0,
				0.28,
				0.12,
				1.0
			)

		"earth":
			return Color(
				0.4,
				0.72,
				0.26,
				1.0
			)

		"water":
			return Color(
				0.22,
				0.58,
				1.0,
				1.0
			)

		"air":
			return Color(
				0.82,
				0.9,
				1.0,
				1.0
			)

	var realm_kind: String = str(
		entry.get(
			"realm_kind",
			""
		)
	).strip_edges().to_lower()

	if realm_kind.find(
		"empire"
	) >= 0:
		return Color(
			0.82,
			0.34,
			0.3,
			1.0
		)

	if realm_kind.find(
		"kingdom"
	) >= 0:
		return Color(
			0.76,
			0.56,
			0.94,
			1.0
		)

	if realm_kind.find(
		"republic"
	) >= 0:
		return Color(
			0.34,
			0.66,
			1.0,
			1.0
		)

	return Color(
		0.42,
		0.72,
		0.96,
		1.0
	)


static func _crown_tiny_stat_bar(value: int) -> String:
	var filled: int = clamp(int(round(float(value) / 10.0)), 0, 10)
	var out: String = ""
	for i in range(10):
		out += "▰" if i < filled else "▱"
	return out


static func _grant_crown_wisdom_willpower(target: Person, amount: int) -> void:
	if target == null:
		return

	var gain: float = float(max(amount, 0))
	target.willpower = clamp(float(target.willpower) + gain, 0.0, 250.0)

	if typeof(target.willpower_profile) == TYPE_DICTIONARY:
		target.willpower_profile ["core_score"] = max(float(target.willpower_profile.get("core_score", 0.0)), float(target.willpower))
		target.willpower_profile ["last_crown_wisdom_gain"] = gain
		target.willpower_profile ["last_crown_wisdom_gain_at_ms"] = int(Time.get_ticks_msec())


static func _crown_is_era_kingdom_country(country_name: String) -> bool:
	var clean: String = str(country_name).strip_edges().to_lower()
	return clean == "era kingdom" or clean == "the era kingdom"


static func _crown_exact_number(value: int) -> String:
	var number: int = int(value)
	var sign_text: String = ""
	if number < 0:
		sign_text = "-"
		number = abs(number)

	var raw_text: String = str(number)
	var out: String = ""
	var counter: int = 0

	for i in range(raw_text.length() - 1, -1, -1):
		if counter > 0 and counter % 3 == 0:
			out = "," + out
		out = raw_text.substr(i, 1) + out
		counter += 1

	return sign_text + out


static func _crown_population_element_color(element: String, fallback: Color = Color(1.0, 0.84, 0.36, 1.0)) -> Color:
	match str(element).strip_edges().to_lower():
		"fire":
			return Color(1.0, 0.28, 0.12, 1.0)
		"water":
			return Color(0.2, 0.62, 1.0, 1.0)
		"earth":
			return Color(0.55, 0.82, 0.36, 1.0)
		"air":
			return Color(0.86, 0.92, 1.0, 1.0)
		_:
			return fallback


static func _crown_population_button_style(bg: Color, border: Color, hover: bool = false, disabled: bool = false) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = bg
	style.border_width_left = 2 if hover else 1
	style.border_width_top = 2 if hover else 1
	style.border_width_right = 2 if hover else 1
	style.border_width_bottom = 2 if hover else 1
	style.border_color = border
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 8
	style.content_margin_top = 5
	style.content_margin_right = 8
	style.content_margin_bottom = 5

	if disabled:
		style.bg_color = style.bg_color.darkened(0.25)
		style.border_color = Color(1.0, 0.92, 0.5, 0.66)

	return style


static func _style_crown_population_scrollbar(scroll: ScrollContainer, accent: Color) -> void:
	if scroll == null:
		return

	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true

	var vbar:= scroll.get_v_scroll_bar()
	if vbar == null:
		return

	vbar.custom_minimum_size = Vector2(12, 0)

	var track:= StyleBoxFlat.new()
	track.bg_color = Color(accent.r * 0.045, accent.g * 0.04, accent.b * 0.052, 0.7)
	track.border_width_left = 1
	track.border_width_right = 1
	track.border_color = Color(accent.r, accent.g, accent.b, 0.22)
	track.corner_radius_top_left = 8
	track.corner_radius_top_right = 8
	track.corner_radius_bottom_left = 8
	track.corner_radius_bottom_right = 8

	var grabber:= StyleBoxFlat.new()
	grabber.bg_color = Color(accent.r, accent.g, accent.b, 0.62)
	grabber.border_width_left = 1
	grabber.border_width_top = 1
	grabber.border_width_right = 1
	grabber.border_width_bottom = 1
	grabber.border_color = Color(1.0, 0.92, 0.72, 0.74)
	grabber.corner_radius_top_left = 8
	grabber.corner_radius_top_right = 8
	grabber.corner_radius_bottom_left = 8
	grabber.corner_radius_bottom_right = 8

	var grabber_hover:= grabber.duplicate() as StyleBoxFlat
	grabber_hover.bg_color = Color(1.0, 0.91, 0.7, 0.88)
	grabber_hover.border_color = Color(1.0, 0.96, 0.82, 1.0)

	vbar.add_theme_stylebox_override("scroll", track)
	vbar.add_theme_stylebox_override("grabber", grabber)
	vbar.add_theme_stylebox_override("grabber_highlight", grabber_hover)
	vbar.add_theme_stylebox_override("grabber_pressed", grabber_hover)


static func _crown_population_bloodline_key(target: Person) -> String:
	if target == null:
		return "unknown"

	var dynasty_text: String = str(target.dynasty_origin).strip_edges()
	if dynasty_text != "":
		return dynasty_text

	var last_name_text: String = str(target.last_name).strip_edges()
	if last_name_text != "":
		return last_name_text

	return "entity_%d" % int(target.id)


static func _crown_population_observable_node_display_name(node: Dictionary) -> String:
	var direct_name: String = str(node.get("name", node.get("display_name", ""))).strip_edges()
	if direct_name != "":
		return direct_name

	var first_name: String = str(node.get("first_name", "")).strip_edges()
	var last_name: String = str(node.get("last_name", "")).strip_edges()
	var full_name: String = "%s %s" % [first_name, last_name]
	full_name = full_name.strip_edges()

	if full_name != "":
		return full_name

	var person_id: int = int(node.get("id", node.get("person_id", -1)))
	if person_id > 0:
		return "Observable Person %d" % person_id

	return "Observable Person"


static func _crown_population_observable_node_role_label(
	node: Dictionary,
	section_kind: String
) -> String:
	var role_text: String = ""

	for raw_value in [
		node.get(
			"job",
			""
		),
		node.get(
			"civic_title",
			""
		),
		node.get(
			"role_label",
			""
		),
		node.get(
			"royal_title",
			""
		)
	]:
		var candidate: String = str(
			raw_value
		).strip_edges()

		if candidate != "":
			role_text = candidate
			break

	if role_text == "":
		var contract_raw: Variant = node.get(
			"civic_office_contract",
			{}
		)

		if typeof(contract_raw) == TYPE_DICTIONARY:
			var contract: Dictionary = (
				contract_raw as Dictionary
			)

			role_text = str(
				contract.get(
					"role_label",
					contract.get(
						"office",
						""
					)
				)
			).strip_edges()

	if role_text == "":
		match str(
			section_kind
		).strip_edges().to_lower():
			"sovereign":
				role_text = "Sovereign"

			"royal_court":
				role_text = "Royal Court"

			"noble_court":
				role_text = "Noble Court"

			"executive", \
"federal_executive", \
"federal_cabinet":
				role_text = "Executive Official"

			"legislative", \
"federal_legislative", \
"federal_senate":
				role_text = "Legislator"

			"judicial", \
"federal_judicial", \
"federal_supreme_court":
				role_text = "Judicial Official"

			"military_command":
				role_text = "Military Command"

			"masters":
				role_text = "Master"

			"citizen":
				role_text = "Citizen"

			_:
				role_text = "Population Node"

	var city: String = str(
		node.get(
			"home_city",
			node.get(
				"birth_city",
				""
			)
		)
	).strip_edges()

	if city != "":
		return "%s • %s" % [
			role_text,
			city
		]

	return role_text


static func _crown_population_entity_id_for_person(target: Person) -> String:
	if target == null:
		return ""
	return "human:%d" % int(target.id)


static func _collect_crown_population_graph_nodes_from_surface(root: Node, out: Dictionary) -> void:
	if root == null:
		return

	if root is PanelContainer and root.has_meta("crown_population_graph_node_contract"):
		var node_raw: Variant = root.get_meta("crown_population_graph_node_contract", {})
		if typeof(node_raw) == TYPE_DICTIONARY:
			var node_contract: Dictionary = node_raw
			var entity_id: String = str(node_contract.get("entity_id", "")).strip_edges()
			if entity_id != "":
				node_contract ["card"] = root
				out [entity_id] = node_contract

	for child in root.get_children():
		_collect_crown_population_graph_nodes_from_surface(child, out)


static func _register_crown_population_graph_node_tween(graph_node: Node, tween: Tween) -> void:
	if graph_node == null or not is_instance_valid(graph_node):
		return

	if tween == null or not tween.is_valid():
		return

	var tweens_raw: Variant = graph_node.get_meta("crown_population_graph_tweens", [])
	var tweens: Array = tweens_raw if typeof(tweens_raw) == TYPE_ARRAY else []

	tweens.append(tween)
	graph_node.set_meta("crown_population_graph_tweens", tweens)


static func _kill_crown_population_graph_node_tweens(graph_node: Node) -> void:
	if graph_node == null or not is_instance_valid(graph_node):
		return

	var tweens_raw: Variant = graph_node.get_meta("crown_population_graph_tweens", [])
	if typeof(tweens_raw) != TYPE_ARRAY:
		return

	var tweens: Array = tweens_raw
	for raw_tween in tweens:
		if raw_tween is Tween:
			var tween: Tween = raw_tween
			if tween.is_valid():
				tween.kill()

	graph_node.set_meta("crown_population_graph_tweens", [])


static func _crown_population_graph_edge_lod_score(raw_edge: Variant) -> float:
	if typeof(raw_edge) != TYPE_DICTIONARY:
		return 0.0

	var edge: Dictionary = raw_edge
	var line_kind: String = str(edge.get("line_kind", "relationship")).strip_edges().to_lower()
	var bond: float = float(clampi(int(edge.get("bond", 50)), 0, 100))
	var weight: float = float(edge.get("weight", 1.0))
	var importance_weight: float = float(edge.get("importance_weight", -1.0))

	if importance_weight < 0.0:
		var tags: Array = edge.get("tags", []) if typeof(edge.get("tags", [])) == TYPE_ARRAY else []
		var label: String = str(edge.get("relationship_label", edge.get("label", ""))).strip_edges().to_lower()

		match line_kind:
			"succession_heir":
				importance_weight = 1.0
			"family":
				if tags.has("parent") or tags.has("child") or label in ["parent", "child", "mother", "father", "son", "daughter"]:
					importance_weight = 0.97
				else:
					importance_weight = 0.88
			"romance":
				importance_weight = 0.92
			"conflict":
				importance_weight = 0.84
			"political":
				importance_weight = 0.76
			"house":
				importance_weight = 0.7
			"economic":
				importance_weight = 0.58
			"social":
				importance_weight = 0.46
			"civic":
				importance_weight = 0.34
			_:
				importance_weight = 0.22

	var kind_bonus: float = 0.0
	match line_kind:
		"succession_heir":
			kind_bonus = 68.0
		"family":
			kind_bonus = 48.0
		"romance":
			kind_bonus = 44.0
		"conflict":
			kind_bonus = 42.0
		"political":
			kind_bonus = 34.0
		"house":
			kind_bonus = 28.0
		"economic":
			kind_bonus = 22.0
		"social":
			kind_bonus = 16.0
		"civic":
			kind_bonus = 10.0
		_:
			kind_bonus = 0.0

	return bond + kind_bonus + (weight * 8.0) + (importance_weight * 45.0)


static func _crown_population_graph_card_rect_in_layer(card: Control, layer: Control) -> Rect2:
	if card == null or layer == null:
		return Rect2()

	if not is_instance_valid(card) or not is_instance_valid(layer):
		return Rect2()

	if not card.is_visible_in_tree():
		return Rect2()

	var layer_rect: Rect2 = layer.get_global_rect()
	var card_rect: Rect2 = card.get_global_rect()
	card_rect.position = card_rect.position - layer_rect.position

	return card_rect


static func _crown_population_graph_edge_width(edge: Dictionary) -> float:
	var bond: int = clampi(int(edge.get("bond", 50)), 0, 100)
	var contract_weight: float = float(edge.get("weight", 2.0))
	var importance_weight: float = float(edge.get("importance_weight", 0.22))
	var line_kind: String = str(edge.get("line_kind", "relationship")).strip_edges().to_lower()

	var width: float = 1.15 + (float(bond) / 28.0) + (contract_weight * 0.2) + (importance_weight * 0.85)

	match line_kind:
		"succession_heir":
			width += 1.2
		"family":
			width += 0.82
		"romance":
			width += 0.58
		"conflict":
			width += 0.75
		"political":
			width += 0.45
		"house":
			width += 0.35
		"economic":
			width += 0.25
		"civic":
			width -= 0.2
		_:
			pass

	return clampf(width, 1.35, 7.25)


static func _crown_population_graph_docked_target_rect_for_layer(
	layer: Control,
	target_rect: Rect2,
	edge_index: int,
	total_edges: int
) -> Rect2:
	if layer == null:
		return target_rect

	var layer_size: Vector2 = layer.size
	var margin: float = 18.0
	var dock_size: Vector2 = Vector2(10.0, 10.0)
	var target_center: Vector2 = target_rect.get_center()

	var center: Vector2 = Vector2(
		clampf(target_center.x, margin, maxf(margin, layer_size.x - margin)),
		clampf(target_center.y, margin, maxf(margin, layer_size.y - margin))
	)

	var left_overflow: float = maxf(0.0, - target_center.x)
	var right_overflow: float = maxf(0.0, target_center.x - layer_size.x)
	var top_overflow: float = maxf(0.0, - target_center.y)
	var bottom_overflow: float = maxf(0.0, target_center.y - layer_size.y)

	var strongest_axis: String = "right"
	var strongest_value: float = right_overflow

	if left_overflow > strongest_value:
		strongest_axis = "left"
		strongest_value = left_overflow
	if top_overflow > strongest_value:
		strongest_axis = "top"
		strongest_value = top_overflow
	if bottom_overflow > strongest_value:
		strongest_axis = "bottom"
		strongest_value = bottom_overflow

	var safe_total: int = max(1, total_edges)
	var lane_ratio: float = float(edge_index + 1) / float(safe_total + 1)
	var lane_sway: float = sin(float(edge_index) * 1.61803398875) * (32.0 if safe_total >= 10 else 18.0)

	match strongest_axis:
		"left":
			center.x = margin
			center.y = clampf((layer_size.y * lane_ratio) + lane_sway, margin, layer_size.y - margin)
		"right":
			center.x = layer_size.x - margin
			center.y = clampf((layer_size.y * lane_ratio) + lane_sway, margin, layer_size.y - margin)
		"top":
			center.y = margin
			center.x = clampf((layer_size.x * lane_ratio) + lane_sway, margin, layer_size.x - margin)
		"bottom":
			center.y = layer_size.y - margin
			center.x = clampf((layer_size.x * lane_ratio) + lane_sway, margin, layer_size.x - margin)

	return Rect2(center - (dock_size * 0.5), dock_size)


static func _crown_population_graph_virtual_target_rect_for_edge(
	layer: Control,
	source_rect: Rect2,
	edge: Dictionary,
	edge_index: int,
	total_edges: int
) -> Rect2:
	if layer == null:
		return Rect2()

	var layer_size: Vector2 = layer.size
	if layer_size.x <= 0.0 or layer_size.y <= 0.0:
		return Rect2()

	var margin: float = 18.0
	var dock_size: Vector2 = Vector2(10.0, 10.0)
	var source_center: Vector2 = source_rect.get_center()
	var safe_total: int = max(1, total_edges)
	var lane_ratio: float = float(edge_index + 1) / float(safe_total + 1)
	var target_entity_id: String = str(edge.get("target_entity_id", "")).strip_edges()
	var line_kind: String = str(edge.get("line_kind", "relationship")).strip_edges().to_lower()
	var stable_hash: int = abs(int(("%s:%s:%d" % [target_entity_id, line_kind, edge_index]).hash()))
	var hash_ratio: float = float(stable_hash % 1000) / 1000.0
	var sway: float = (hash_ratio - 0.5) * 46.0
	var side: int = stable_hash % 4
	var center: Vector2 = Vector2.ZERO

	match side:
		0:
			center.x = margin
			center.y = clampf((layer_size.y * lane_ratio) + sway, margin, layer_size.y - margin)
		1:
			center.x = layer_size.x - margin
			center.y = clampf((layer_size.y * lane_ratio) + sway, margin, layer_size.y - margin)
		2:
			center.y = margin
			center.x = clampf((layer_size.x * lane_ratio) + sway, margin, layer_size.x - margin)
		_:
			center.y = layer_size.y - margin
			center.x = clampf((layer_size.x * lane_ratio) + sway, margin, layer_size.x - margin)

	if absf(source_center.x - center.x) < 24.0 and absf(source_center.y - center.y) < 24.0:
		center.x = clampf(layer_size.x - center.x, margin, layer_size.x - margin)
		center.y = clampf(layer_size.y - center.y, margin, layer_size.y - margin)

	return Rect2(center - (dock_size * 0.5), dock_size)


static func _crown_population_graph_anchor_route(source_rect: Rect2, target_rect: Rect2) -> Dictionary:
	var source_center: Vector2 = source_rect.get_center()
	var target_center: Vector2 = target_rect.get_center()
	var delta: Vector2 = target_center - source_center

	if absf(delta.x) >= absf(delta.y):
		if delta.x >= 0.0:
			return {
				"source": source_rect.position + Vector2(source_rect.size.x, source_rect.size.y * 0.5),
				"target": target_rect.position + Vector2(0.0, target_rect.size.y * 0.5),
				"axis": "horizontal"
			}

		return {
			"source": source_rect.position + Vector2(0.0, source_rect.size.y * 0.5),
			"target": target_rect.position + Vector2(target_rect.size.x, target_rect.size.y * 0.5),
			"axis": "horizontal"
		}

	if delta.y >= 0.0:
		return {
			"source": source_rect.position + Vector2(source_rect.size.x * 0.5, source_rect.size.y),
			"target": target_rect.position + Vector2(target_rect.size.x * 0.5, 0.0),
			"axis": "vertical"
		}

	return {
		"source": source_rect.position + Vector2(source_rect.size.x * 0.5, 0.0),
		"target": target_rect.position + Vector2(target_rect.size.x * 0.5, target_rect.size.y),
		"axis": "vertical"
	}


static func _crown_population_graph_edge_color(line_kind: String, accent: Color, intensity: float = 0.78) -> Color:
	var alpha: float = clampf(intensity, 0.36, 1.0)

	match line_kind:
		"succession_heir":
			return Color(1.0, 0.72, 0.1, alpha)
		"romance":
			return Color(1.0, 0.12, 0.68, alpha)
		"family":
			return Color(0.22, 0.58, 1.0, alpha)
		"house":
			return Color(0.76, 0.38, 1.0, alpha)
		"political":
			return Color(1.0, 0.78, 0.18, alpha)
		"economic":
			return Color(0.24, 0.98, 0.52, alpha)
		"conflict":
			return Color(1.0, 0.16, 0.1, alpha)
		"civic":
			return Color(0.78, 0.66, 0.46, alpha)
		"social":
			return Color(0.4, 0.82, 1.0, alpha)
		_:
			return Color(accent.r, accent.g, accent.b, alpha)


static func _crown_population_city_bucket_key_for_person(target: Person, realm_id: int, realm_name: String, section_kind: String, element: String = "", split_by_city: bool = false) -> String:
	if target == null:
		return "unknown"

	var home_city: String = str(target.home_city).strip_edges()
	var birth_city: String = str(target.birth_city).strip_edges()
	var city_key: String = home_city if home_city != "" else birth_city

	if city_key == "":
		city_key = "Unplaced"

	var normalized_city: String = city_key.strip_edges().to_lower()
	var normalized_realm: String = str(realm_name).strip_edges().to_lower()
	var element_key: String = str(element).strip_edges().to_lower()

	if split_by_city:
		return "split:%s:%s:%s" % [
			normalized_realm if normalized_realm != "" else str(realm_id),
			normalized_city,
			section_kind
		]

	if element_key in ["air", "fire", "water"]:
		return "nation:%s:%s:%s" % [
			element_key,
			normalized_city,
			section_kind
		]

	return "nation:%s:%s:%s" % [
		normalized_realm if normalized_realm != "" else str(realm_id),
		normalized_city,
		section_kind
	]


static func _other_country_population_entry_should_hide(entry: Dictionary, realm: Dictionary = {}) -> bool:
	var entry_id: String = str(entry.get("entry_id", "")).strip_edges().to_lower()
	var entry_name: String = str(entry.get("name", "")).strip_edges().to_lower()
	var visual_theme: String = str(realm.get("browser_visual_theme", realm.get("overview_visual_theme", ""))).strip_edges().to_lower()

	if entry_id == "era_kingdom" or entry_name == "era kingdom" or visual_theme == "era_kingdom":
		return true

	if entry_id == "terabithia" or entry_name == "terabithia" or visual_theme == "terabithia":
		return true

	return false


static func _other_country_population_realm_name_from_entry(entry: Dictionary, realm: Dictionary = {}) -> String:
	var realm_name: String = str(realm.get("name", realm.get("country", ""))).strip_edges()
	if realm_name != "":
		return realm_name

	realm_name = str(entry.get("name", "")).strip_edges()
	if realm_name != "":
		return realm_name

	return "Country / Realm"


static func _crown_population_wall_should_hide_for_realm(_realm_id: int, realm_name: String, realm: Dictionary = {}) -> bool:
	var name_key: String = str(realm_name).strip_edges().to_lower()
	var visual_theme: String = str(realm.get("browser_visual_theme", realm.get("overview_visual_theme", ""))).strip_edges().to_lower()
	var entry_id: String = str(realm.get("entry_id", realm.get("id", ""))).strip_edges().to_lower()

	if name_key == "era kingdom" or entry_id == "era_kingdom" or visual_theme == "era_kingdom":
		return true

	if name_key == "terabithia" or entry_id == "terabithia" or visual_theme == "terabithia":
		return true

	return false


static func _population_lens_incremental_entity_key(
	raw_row: Variant
) -> String:
	if raw_row is Person:
		return "person:%d" % int(
			(raw_row as Person).id
		)

	if typeof(raw_row) == TYPE_DICTIONARY:
		var row: Dictionary = (
			raw_row as Dictionary
		)

		for raw_key in [
			"entity_id",
			"node_id",
			"person_id",
			"actor_id",
			"id",
			"contract_id"
		]:
			var key: String = str(
				raw_key
			)
			var candidate: String = str(
				row.get(
					key,
					""
				)
			).strip_edges()

			if candidate != "":
				return "%s:%s" % [
					key,
					candidate
				]

	return "row_hash:%s" % str(
		hash(
			raw_row
		)
	)


static func _population_lens_incremental_section_accent(
	accent_key: String,
	realm_accent: Color
) -> Color:
	match str(
		accent_key
	).strip_edges().to_lower():
		"royal":
			return Color(
				1.0,
				0.78,
				0.24,
				1.0
			)

		"noble":
			return Color(
				0.78,
				0.56,
				1.0,
				1.0
			)

		"executive", "federal_executive":
			return Color(
				0.34,
				0.56,
				1.0,
				1.0
			)

		"federal_cabinet":
			return Color(
				0.42,
				0.66,
				1.0,
				1.0
			)

		"legislative", "federal_legislative":
			return Color(
				0.38,
				0.54,
				0.98,
				1.0
			)

		"judicial", "federal_judicial":
			return Color(
				0.7,
				0.56,
				1.0,
				1.0
			)

		"federal_governor":
			return Color(
				0.48,
				0.82,
				0.62,
				1.0
			)

		"military":
			return Color(
				0.86,
				0.48,
				0.34,
				1.0
			)

		"elemental":
			return realm_accent

		"social_upper":
			return Color(
				1.0,
				0.76,
				0.28,
				1.0
			)

		"social_middle":
			return Color(
				0.34,
				0.72,
				1.0,
				1.0
			)

		"social_skilled":
			return Color(
				0.34,
				0.88,
				0.68,
				1.0
			)

		"social_working":
			return Color(
				0.82,
				0.6,
				0.34,
				1.0
			)

		"social_lower":
			return Color(
				0.62,
				0.64,
				0.72,
				1.0
			)

		_:
			return realm_accent


static func _crown_population_full_target_bucket_color(title_text: String, fallback: Color) -> Color:
	var key: String = str(title_text).strip_edges().to_lower()

	if key.find("profile") >= 0:
		return Color(0.56, 0.76, 1.0, 1.0)
	if key.find("court") >= 0:
		return Color(0.82, 0.58, 1.0, 1.0)
	if key.find("dynasty") >= 0 or key.find("family") >= 0:
		return Color(1.0, 0.72, 0.38, 1.0)
	if key.find("force") >= 0 or key.find("state") >= 0:
		return Color(1.0, 0.34, 0.24, 1.0)

	return fallback


static func _crown_population_full_target_bucket_style(accent: Color, hovered: bool = false) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(accent.r * 0.08, accent.g * 0.062, accent.b * 0.085, 0.95)
	style.border_width_left = 2 if hovered else 1
	style.border_width_top = 2 if hovered else 1
	style.border_width_right = 2 if hovered else 1
	style.border_width_bottom = 2 if hovered else 1
	style.border_color = Color(accent.r, accent.g, accent.b, 0.82 if hovered else 0.42)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.28 if hovered else 0.12)
	style.shadow_size = 10 if hovered else 4
	style.shadow_offset = Vector2.ZERO
	return style


static func _calculate_crown_tax_revenue(population: int, tax_rate: float, realm: Dictionary = {}) -> int:
	if population <= 0 or tax_rate <= 0.0:
		return 0
	var quality: float = float(realm.get("quality", realm.get("country_quality", 50.0)))
	var prosperity: float = float(realm.get("prosperity", realm.get("realm_quality", 0.0)))
	var land: float = float(realm.get("land", realm.get("land_size", 0.0)))
	var taxable_income_per_citizen: float = max(24.0, 120.0 + (quality * 6.0) + (prosperity * 2.5) + min(80.0, land * 0.04))
	return max(0, int(round(float(population) * taxable_income_per_citizen * (tax_rate / 100.0))))


static func _crown_allocation_bucket_help_line(bucket_key: String) -> String:
	match str(bucket_key):
		"treasury_pct":
			return "Treasury protects the reserve and stabilizes future choices."
		"military_pct":
			return "Military production raises force projection but can make goods feel thinner."
		"goods_pct":
			return "Goods production supports the people and the economy, but reduces immediate military pressure."
		_:
			return "Remaining buckets auto-balance live."


static func _crown_diplomacy_card_leader_text(
	entry: Dictionary
) -> String:
	var label_text: String = str(
		entry.get(
			"ruler_label",
			entry.get(
				"leader_label",
				""
			)
		)
	).strip_edges()

	while label_text != "":
		var lower_text: String = (
			label_text.to_lower()
		)

		if lower_text.begins_with(
			"leader:"
		):
			label_text = label_text.substr(
				"leader:".length()
			).strip_edges()
			continue

		if lower_text.begins_with(
			"leader -"
		):
			label_text = label_text.substr(
				"leader -".length()
			).strip_edges()
			continue

		if lower_text.begins_with(
			"leader —"
		):
			label_text = label_text.substr(
				"leader —".length()
			).strip_edges()
			continue

		break

	if label_text == "":
		label_text = "Unassigned Office Holder"

	return "Leader: %s" % label_text


static func _format_crown_compact_scaled_value(
	scaled: float
) -> String:
	var label: String = ""

	if scaled < 10.0:
		label = "%0.2f" % scaled
	elif scaled < 100.0:
		label = "%0.1f" % scaled
	else:
		label = "%0.0f" % scaled



	if label.find(".") >= 0:
		while label.ends_with("0"):
			label = label.substr(
				0,
				maxi(
					0,
					label.length() - 1
				)
			)

		if label.ends_with("."):
			label = label.substr(
				0,
				maxi(
					0,
					label.length() - 1
				)
			)

	return label


static func _sanitize_crown_allocation_split(draft: Dictionary) -> Dictionary:
	var out: Dictionary = draft.duplicate(true)
	var tax_rate: float = clamp(float(out.get("tax_rate", 10.0)), 0.0, 40.0)
	var treasury_pct: int = clamp(int(out.get("treasury_pct", 34)), 0, 100)
	var military_pct: int = clamp(int(out.get("military_pct", 33)), 0, 100)
	var goods_pct: int = clamp(int(out.get("goods_pct", 33)), 0, 100)

	var total_pct: int = treasury_pct + military_pct + goods_pct
	if total_pct != 100:
		if total_pct <= 0:
			treasury_pct = 34
			military_pct = 33
			goods_pct = 33
		else:
			var pct_scale: float = 100.0 / float(total_pct)
			treasury_pct = clamp(int(round(float(treasury_pct) * pct_scale)), 0, 100)
			military_pct = clamp(int(round(float(military_pct) * pct_scale)), 0, 100)
			goods_pct = clamp(int(round(float(goods_pct) * pct_scale)), 0, 100)

			var fixed_total: int = treasury_pct + military_pct + goods_pct
			if fixed_total != 100:
				goods_pct += 100 - fixed_total

	if goods_pct < 0:
		goods_pct = 0

	out ["tax_rate"] = tax_rate
	out ["treasury_pct"] = treasury_pct
	out ["military_pct"] = military_pct
	out ["goods_pct"] = goods_pct
	return out


static func _crown_tax_pressure_delta(
		tax_rate: float,
		channel: String
) -> int:
		var clean_tax: float = clamp(
			float(tax_rate),
			0.0,
			40.0
		)
		var clean_channel: String = str(
			channel
		).strip_edges().to_lower()

		if clean_tax <= 13.0:
			var relief_ratio: float = clamp(
				(13.0 - clean_tax) / 13.0,
				0.0,
				1.0
			)

			match clean_channel:
				"happiness":
					return int(
						round(
							pow(
								relief_ratio,
								0.88
							) * 24.0
						)
					)
				"approval":
					return int(
						round(
							pow(
								relief_ratio,
								0.92
							) * 18.0
						)
					)
				"respect":
					return int(
						round(
							pow(
								relief_ratio,
								0.96
							) * 12.0
						)
					)
				_:
					return 0

		var over_tax: float = clean_tax - 13.0

		match clean_channel:
			"happiness":
				return clamp(
					-2
					- int(
						round(
							pow(over_tax, 1.35) * 1.35
						)
					),
					-60,
					0
				)
			"approval":
				return clamp(
					-2
					- int(
						round(
							pow(over_tax, 1.3) * 1.1
						)
					),
					-50,
					0
				)
			"respect":
				return clamp(
					-1
					- int(
						round(
							pow(over_tax, 1.25) * 0.95
						)
					),
					-40,
					0
				)
			_:
				return 0


static func _crown_popup_title_for_event(event_name: String) -> String:
	match str(event_name).strip_edges():
		"crown_execution":
			return "Execution Ordered"
		"crown_exile":
			return "Exile Ordered"
		"crown_pardon":
			return "Mercy Granted"
		"crown_country_trade", "crown_trade":
			return "Trade Route Opened"
		"crown_country_gift", "crown_gift":
			return "Diplomatic Gift Sent"
		"crown_country_bribe", "crown_bribe":
			return "Bribe Sent"
		"crown_country_war":
			return "WAR DECLARED"
		"crown_law_signed":
			return "Law Signed"
		"crown_law_rejected":
			return "Law Rejected"
		"crown_law_revised":
			return "Law Revised"
		"crown_law_delayed":
			return "Law Delayed"
		"crown_citizen_mediation":
			return "Citizens Mediated"
		_:
			return "Crown Decision"


static func _crown_population_noble_title_from_text(text: String) -> String:
	var lowered: String = str(text).strip_edges().to_lower()
	if lowered == "":
		return ""

	if lowered.find("high noble") >= 0 \
or lowered.find("high nobility") >= 0 \
or lowered.find("upper nobility") >= 0 \
or lowered.find("aristocrat") >= 0 \
or lowered.find("aristocracy") >= 0 \
or lowered.find("nobility") >= 0:
		return "High Noble"

	if lowered.find("marchioness") >= 0:
		return "Marchioness"

	if lowered.find("marquess") >= 0 \
or lowered.find("marquis") >= 0 \
or lowered.find("marquise") >= 0 \
or lowered.find("marquee") >= 0 \
or lowered.find("marcher lord") >= 0:
		return "Marquess"

	if lowered.find("archduchess") >= 0:
		return "Archduchess"

	if lowered.find("archduke") >= 0:
		return "Archduke"

	if lowered.find("duchess") >= 0:
		return "Duchess"

	if lowered.find("duke") >= 0 \
or lowered.find("ducal") >= 0 \
or lowered.find("duchy") >= 0:
		return "Duke"

	if lowered.find("countess") >= 0:
		return "Countess"

	if lowered.find("count ") >= 0 or lowered == "count":
		return "Count"

	if lowered.find("baroness") >= 0:
		return "Baroness"

	if lowered.find("baron") >= 0:
		return "Baron"

	if lowered.find("viscountess") >= 0:
		return "Viscountess"

	if lowered.find("viscount") >= 0:
		return "Viscount"

	if lowered.find("lady") >= 0:
		return "Lady"

	if lowered.find("lord") >= 0:
		return "Lord"

	if lowered == "noble":
		return "High Noble"

	return ""


static func _crown_population_title_tier_from_text(title_text: String) -> String:
	var lowered: String = str(title_text).strip_edges().to_lower()
	if lowered == "":
		return ""

	if lowered.find("king") >= 0 \
or lowered.find("queen") >= 0 \
or lowered.find("emperor") >= 0 \
or lowered.find("empress") >= 0 \
or lowered.find("pharaoh") >= 0 \
or lowered.find("sovereign") >= 0 \
or lowered.find("chief") >= 0 \
or lowered.find("fire lord") >= 0 \
or lowered.find("fire queen") >= 0 \
or lowered.find("earth king") >= 0 \
or lowered.find("earth queen") >= 0 \
or lowered.find("air regent") >= 0:
		return "ruler"

	if lowered.find("crown prince") >= 0 or lowered.find("crown princess") >= 0:
		return "heir"

	if lowered.find("prince") >= 0 or lowered.find("princess") >= 0:
		return "royal_child"

	if lowered.find("archduke") >= 0 or lowered.find("archduchess") >= 0:
		return "ducal"

	if lowered.find("duke") >= 0 \
or lowered.find("duchess") >= 0 \
or lowered.find("ducal") >= 0 \
or lowered.find("duchy") >= 0:
		return "ducal"

	if lowered.find("marquess") >= 0 \
or lowered.find("marchioness") >= 0 \
or lowered.find("marquis") >= 0 \
or lowered.find("marquise") >= 0 \
or lowered.find("marquee") >= 0 \
or lowered.find("marcher lord") >= 0:
		return "marcher"

	if lowered.find("high noble") >= 0 \
or lowered.find("nobility") >= 0 \
or lowered.find("aristocrat") >= 0 \
or lowered.find("aristocracy") >= 0:
		return "lord"

	if lowered.find("countess") >= 0 \
or lowered.find("count ") >= 0 \
or lowered == "count" \
or lowered.find("baroness") >= 0 \
or lowered.find("baron") >= 0 \
or lowered.find("viscountess") >= 0 \
or lowered.find("viscount") >= 0:
		return "lord"

	if lowered.find("lord") >= 0 or lowered.find("lady") >= 0:
		return "lord"

	return ""


static func _crown_population_push_unique_person(out: Array, seen: Dictionary, target: Person) -> void:
	if target == null or not target.alive:
		return

	var target_id: int = int(target.id)
	if target_id <= 0 or seen.has(target_id):
		return

	out.append(target)
	seen [target_id] = true


static func _crown_title_case(text: String) -> String:
	var out: Array = []
	for raw_word in str(text).strip_edges().split(" "):
		var word: String = str(raw_word).strip_edges()
		if word == "":
			continue
		out.append(word.substr(0, 1).to_upper() + word.substr(1).to_lower())
	return " ".join(out)


static func _crown_population_citizen_strata_title(key: String) -> String:
	match str(key):
		"bottom_class":
			return "BOTTOM CLASS"
		"lower_middle_class":
			return "LOWER-MIDDLE CLASS"
		"middle_class":
			return "MIDDLE CLASS"
		"upper_middle_class":
			return "UPPER-MIDDLE CLASS"
		"elite":
			return "ELITES"
		"peasant":
			return "PEASANTS"
		"merchant":
			return "MERCHANTS"
		_:
			return "COMMONERS"


static func _crown_population_citizen_strata_subtitle(key: String) -> String:
	match str(key):
		"bottom_class":
			return "Bottom-class citizens with the least economic security. Their jobs and stats still render per card."
		"lower_middle_class":
			return "Working and lower-middle citizens. They are regular citizens, not federal officials."
		"middle_class":
			return "Stable middle-class citizens, professionals, workers, and household builders."
		"upper_middle_class":
			return "Upper-middle citizens, business owners, high earners, and high-status professionals."
		"elite":
			return "The one percent: rich, famous, or extremely wealthy civilians. They are powerful citizens, not federal officers."
		"peasant":
			return "Lowborn workers, farmers, servants, laborers, and rural citizens."
		"merchant":
			return "Trade, craft, shop, and wealth-building citizens."
		_:
			return "Regular citizens outside the noble court. Their individual jobs still render on each card."


static func _crown_population_citizen_strata_accent_color(key: String, fallback: Color) -> Color:
	match str(key):
		"bottom_class":
			return Color(fallback.r * 0.58, fallback.g * 0.58, fallback.b * 0.58, 1.0)
		"lower_middle_class":
			return Color(fallback.r * 0.74, fallback.g * 0.78, fallback.b * 0.82, 1.0)
		"middle_class":
			return Color(fallback.r * 0.92, fallback.g * 0.92, fallback.b * 0.92, 1.0)
		"upper_middle_class":
			return Color(0.78, 0.86, 1.0, 1.0)
		"elite":
			return Color(1.0, 0.88, 0.48, 1.0)
		"peasant":
			return Color(0.72, 0.62, 0.44, 1.0)
		"merchant":
			return Color(0.5, 0.86, 0.68, 1.0)
		_:
			return Color(fallback.r, fallback.g, fallback.b, 1.0)


static func _build_crown_population_removal_label(target: Person) -> String:
	if target == null:
		return "Execute"
	if bool(target.is_ruler):
		return "Assassinate"
	if bool(target.is_royal):
		return "Assassinate"
	if int(target.succession_rank) > 0:
		return "Assassinate"
	if str(target.royal_title).strip_edges() != "":
		return "Assassinate"

	var office_job: String = str(target.job).strip_edges().to_lower()
	if office_job in [
		"president",
		"prime minister",
		"governor",
		"mayor",
		"senator",
		"judge",
		"minister",
		"court official",
		"general"
	]:
		return "Assassinate"

	return "Execute"


static func _crown_relation_label(
	score: int
) -> String:
	if score >= 60:
		return "Allied"

	if score >= 25:
		return "Friendly"

	if score >= 0:
		return "Neutral"

	if score >= -24:
		return "Unfriendly"

	if score >= -49:
		return "Strained"

	if score >= -69:
		return "Hostile"

	if score >= -84:
		return "Enemies"

	if score >= -99:
		return "Sworn enemies"

	return "Pure enemies"


static func _belonging_item_is_food(item: Dictionary, category: String) -> bool:
	var clean_category: String = str(category).strip_edges().to_lower()
	var item_type: String = str(item.get("type", "")).strip_edges().to_lower()

	if clean_category == "food":
		return true
	if item_type == "food" or item_type == "grocery":
		return true
	if item.has("hunger_restore") or item.has("nutrition"):
		return true
	if str(item.get("source", "")).strip_edges().to_lower().find("grocery") >= 0:
		return true

	return false


static func _belonging_food_item_id(item: Dictionary) -> int:
	return int(item.get("id", item.get("item_id", -1)))


static func _belonging_food_action_button_style(_item: Dictionary, strength: float, hovered: bool = false) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	var core: Color = Color(1.0, 0.58, 0.28, 1.0)
	style.bg_color = Color(core.r * 0.22, core.g * 0.18, core.b * 0.12, 0.42 + strength * 0.2)
	style.border_color = Color(core.r, core.g, core.b, 0.58 + strength * 0.24)
	style.shadow_color = Color(core.r, core.g * 0.75, core.b * 0.45, 0.22 + strength * 0.18)
	style.shadow_size = 18 if hovered else 10
	style.shadow_offset = Vector2.ZERO
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	return style


static func _red_bonnet_wish_is_dragon_ball_summon(wish_name: String) -> bool:
	var clean: String = str(wish_name).strip_edges().to_lower()
	return clean in [
		"summon_dragon_balls",
		"summon dragon balls",
		"summon all dragon balls"
	]


static func _normalize_ui_nav_button_text(button_text: String) -> String:
	var raw: String = str(button_text).strip_edges().to_lower()
	if raw == "":
		return ""

	var compact: String = raw
	compact = compact.replace(" ", "")
	compact = compact.replace("\t", "")
	compact = compact.replace("\n", "")
	compact = compact.replace("
", "")
	compact = compact.replace("_", "")
	compact = compact.replace("-", "")
	compact = compact.replace(":", "")
	compact = compact.replace(".", "")
	compact = compact.replace(",", "")
	compact = compact.replace("!", "")
	compact = compact.replace("?", "")
	compact = compact.strip_edges()

	if compact == "":
		return ""

	if compact.begins_with("profile"):
		return ""

	if compact == "ageup" or compact.begins_with("ageup"):
		return "age_up"

	if compact == "world" or compact.begins_with("world"):
		return "world"

	if compact == "life" or compact.begins_with("life"):
		return "life"

	if compact == "school" or compact.begins_with("school"):
		return "school"

	if compact == "activities" or compact.begins_with("activities"):
		return "activities"

	if compact == "relationships" or compact.begins_with("relationships"):
		return "relationships"

	if compact == "career" or compact.begins_with("career"):
		return "career"
	if compact == "mods" or compact.begins_with("mods"):
		return "mods"
	return ""


static func _make_era_border_rect(initial_color: Color) -> ColorRect:
	var rect:= ColorRect.new()
	rect.color = initial_color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


static func _position_particle_along_frame(
	rect: ColorRect,
	distance: float,
	w: float,
	h: float,
	inset: float,
	particle_size: float
) -> void:
	var perimeter: float = max(1.0, (w * 2.0) + (h * 2.0))
	var d: float = fposmod(distance, perimeter)

	rect.size = Vector2(particle_size, particle_size)

	if d <= w:
		rect.position = Vector2(d - particle_size * 0.5, inset)
	elif d <= w + h:
		d -= w
		rect.position = Vector2(w - inset - particle_size, d - particle_size * 0.5)
	elif d <= w + h + w:
		d -= (w + h)
		rect.position = Vector2((w - d) - particle_size * 0.5, h - inset - particle_size)
	else:
		d -= (w + h + w)
		rect.position = Vector2(inset, (h - d) - particle_size * 0.5)


static func _era_border_theme_data(theme_key: String) -> Dictionary:
	match theme_key:
		"medieval":
			return {
				"core": Color(0.3, 0.35, 0.42, 0.98),
				"glow": Color(0.86, 0.92, 1.0, 0.03),
				"thickness": 5.0,
				"glow_thickness": 5.0,
				"pulse": 0.008,
				"shadow_alpha": 0.36,
				"corner_alpha": 0.05,
				"inner_inset": 5.0,
				"pulse_speed": 0.75,
				"corner_scale": 0.82,
				"highlight": Color(0.96, 0.99, 1.0, 0.26),
				"overlay": Color(0.84, 0.9, 0.98, 0.04),
				"hot_corner": Color(0.98, 1.0, 1.0, 0.08),
				"top_mult": 1.0,
				"right_mult": 1.0,
				"bottom_mult": 1.06,
				"left_mult": 1.0,
				"highlight_thickness": 1.8,
				"overlay_width_ratio": 0.1,
				"overlay_speed": 0.22
			}
		"modern":
			return {
				"core": Color(0.94, 0.95, 0.97, 0.94),
				"glow": Color(0.94, 0.97, 1.0, 0.02),
				"thickness": 3.0,
				"glow_thickness": 3.0,
				"pulse": 0.004,
				"shadow_alpha": 0.07,
				"corner_alpha": 0.012,
				"inner_inset": 3.0,
				"pulse_speed": 0.45,
				"corner_scale": 0.58,
				"highlight": Color(1.0, 1.0, 1.0, 0.14),
				"overlay": Color(1.0, 1.0, 1.0, 0.025),
				"hot_corner": Color(1.0, 1.0, 1.0, 0.03),
				"top_mult": 1.0,
				"right_mult": 1.0,
				"bottom_mult": 1.0,
				"left_mult": 1.0,
				"highlight_thickness": 1.0,
				"overlay_width_ratio": 0.08,
				"overlay_speed": 0.12
			}
		"future":
			return {
				"core": Color(0.24, 0.9, 1.0, 0.98),
				"glow": Color(0.5, 0.98, 1.0, 0.1),
				"thickness": 7.0,
				"glow_thickness": 12.0,
				"pulse": 0.1,
				"shadow_alpha": 0.08,
				"corner_alpha": 0.18,
				"inner_inset": 4.0,
				"pulse_speed": 1.55,
				"corner_scale": 1.18,
				"highlight": Color(0.9, 1.0, 1.0, 0.5),
				"overlay": Color(0.7, 0.96, 1.0, 0.08),
				"hot_corner": Color(0.76, 1.0, 1.0, 0.2),
				"top_mult": 1.0,
				"right_mult": 1.0,
				"bottom_mult": 1.0,
				"left_mult": 1.0,
				"highlight_thickness": 2.0,
				"overlay_width_ratio": 0.16,
				"overlay_speed": 1.1
			}
		_:
			return {
				"core": Color(0.62, 0.5, 0.33, 0.98),
				"glow": Color(0.96, 0.75, 0.4, 0.05),
				"thickness": 5.0,
				"glow_thickness": 7.0,
				"pulse": 0.04,
				"shadow_alpha": 0.3,
				"corner_alpha": 0.14,
				"inner_inset": 5.0,
				"pulse_speed": 1.0,
				"corner_scale": 1.04,
				"highlight": Color(0.98, 0.86, 0.6, 0.18),
				"overlay": Color(0.94, 0.78, 0.52, 0.07),
				"hot_corner": Color(1.0, 0.84, 0.56, 0.18),
				"top_mult": 0.84,
				"right_mult": 0.96,
				"bottom_mult": 1.12,
				"left_mult": 0.9,
				"highlight_thickness": 1.4,
				"overlay_width_ratio": 0.1,
				"overlay_speed": 0.24
			}


static func _standard_tab_make_vormir_panel_style(kind: String = "info") -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()

	match kind:
		"stat":
			style.bg_color = Color(0.018, 0.01, 0.03, 0.985)
			style.border_color = Color(0.78, 0.3, 1.0, 0.86)
			style.shadow_color = Color(0.42, 0.08, 0.88, 0.42)
			style.shadow_size = 24
		"section":
			style.bg_color = Color(0.03, 0.012, 0.05, 0.96)
			style.border_color = Color(1.0, 0.48, 0.16, 0.72)
			style.shadow_color = Color(0.76, 0.18, 1.0, 0.38)
			style.shadow_size = 26
		"button":
			style.bg_color = Color(0.035, 0.014, 0.062, 0.98)
			style.border_color = Color(1.0, 0.52, 0.18, 0.88)
			style.shadow_color = Color(0.72, 0.18, 1.0, 0.44)
			style.shadow_size = 24
		"button_hover":
			style.bg_color = Color(0.07, 0.028, 0.11, 1.0)
			style.border_color = Color(1.0, 0.68, 0.28, 1.0)
			style.shadow_color = Color(0.92, 0.3, 1.0, 0.62)
			style.shadow_size = 32
		_:
			style.bg_color = Color(0.012, 0.008, 0.024, 0.988)
			style.border_color = Color(0.72, 0.28, 1.0, 0.9)
			style.shadow_color = Color(0.42, 0.08, 0.88, 0.46)
			style.shadow_size = 28

	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.shadow_offset = Vector2.ZERO

	return style


static func _standard_tab_apply_vormir_label_style(label: Label, strong: bool = false) -> void:
	if label == null:
		return

	label.add_theme_color_override("font_color", Color(1.0, 0.91, 0.78, 0.99) if strong else Color(0.93, 0.86, 1.0, 0.96))
	label.add_theme_color_override("font_shadow_color", Color(1.0, 0.36, 0.08, 0.34) if strong else Color(0.7, 0.18, 1.0, 0.3))
	label.add_theme_constant_override("shadow_outline_size", 4 if strong else 2)


static func _standard_tab_apply_vormir_bar_style(bar: ProgressBar) -> void:
	if bar == null:
		return

	var bg:= StyleBoxFlat.new()
	bg.bg_color = Color(0.018, 0.01, 0.03, 0.96)
	bg.border_color = Color(0.44, 0.12, 0.72, 0.62)
	bg.border_width_left = 1
	bg.border_width_top = 1
	bg.border_width_right = 1
	bg.border_width_bottom = 1
	bg.corner_radius_top_left = 10
	bg.corner_radius_top_right = 10
	bg.corner_radius_bottom_left = 10
	bg.corner_radius_bottom_right = 10

	var fill:= StyleBoxFlat.new()
	fill.bg_color = Color(1.0, 0.48, 0.16, 0.92)
	fill.border_color = Color(1.0, 0.76, 0.3, 0.68)
	fill.border_width_left = 1
	fill.border_width_top = 1
	fill.border_width_right = 1
	fill.border_width_bottom = 1
	fill.corner_radius_top_left = 10
	fill.corner_radius_top_right = 10
	fill.corner_radius_bottom_left = 10
	fill.corner_radius_bottom_right = 10
	fill.shadow_color = Color(1.0, 0.42, 0.1, 0.34)
	fill.shadow_size = 10
	fill.shadow_offset = Vector2.ZERO

	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)


static func _crime_hub_renderer_chassis_contract() -> Dictionary:
	return {
		"schema": "eralife.crime_hub_contract",
		"version": 1,
		"success": true,
		"actor_id": -1,
		"title": "CRIME & JUSTICE",
		"subtitle": (
			(
				"Crime reality is resident. "
				+ "Targets, criminal intent, cases, weapons, custody, "
				+ "and legal pressure bind continuously."
			)
		),
		"active_section": "overview",
		"section_tabs": [
			{
				"id": "overview",
				"label": "OVERVIEW"
			},
			{
				"id": "crime_actions",
				"label": "CRIME ACTIONS"
			},
			{
				"id": "targets",
				"label": "TARGETS"
			},
			{
				"id": "weapons",
				"label": "WEAPONS"
			},
			{
				"id": "cases",
				"label": "CASES"
			},
			{
				"id": "pending",
				"label": "PENDING"
			},
			{
				"id": "custody",
				"label": "CUSTODY"
			}
		],
		"section_rows": [
			{
				"kind": "resident_projection",
				"label": "CRIME REALITY RESIDENT",
				"subtitle": (
					(
						"This room already exists. "
						+ "Its current actor projection is reconnecting."
					)
				),
				"actions": []
			}
		],
		"identity": {},
		"access_contract": {
			"minimum_age": 0,
			"under_12_access": true,
		},
		"incarcerated": false,
		"prison_reality_contract": {},
		"interaction_contract": {},
		"action_report": {},
		"truth_state": "renderer_chassis",
		"projection_composed": true,
		"hydrated": false,
		"ui_is_renderer_only": true,
		"renderer_chassis_only": true,
		"generated_at_ms": int(
			Time.get_ticks_msec()
		)
	}


static func _resolve_realm_stat_surface(_title: String, value: int, max_value: int, surface_context: Dictionary) -> Dictionary:
	var safe_max: int = max(1, max_value)
	var safe_value: int = clamp(value, 0, safe_max)
	var ratio: float = clamp(float(safe_value) / float(safe_max), 0.0, 1.0)

	var stat_family: String = str(surface_context.get("realm_stat_family", "generic")).strip_edges()
	var is_imaginative_realm: bool = bool(surface_context.get("is_imaginative_realm", false))
	var is_elemental_realm: bool = bool(surface_context.get("is_elemental_realm", false))
	var is_era_kingdom: bool = bool(surface_context.get("is_era_kingdom", false))
	var native_element: String = str(surface_context.get("native_element", "")).strip_edges().to_lower()
	var access_state: String = str(surface_context.get("access_state", "")).strip_edges().to_lower()

	var descriptor: String = ""
	var flavor: String = ""

	match stat_family:
		"wonder":
			if ratio >= 0.9:
				descriptor = "Mythic"
				flavor = "The realm feels overflowing with living wonder."
			elif ratio >= 0.72:
				descriptor = "Charged"
				flavor = "Imagination is moving strongly through the realm."
			elif ratio >= 0.5:
				descriptor = "Awake"
				flavor = "The realm still answers belief, even if not at full brilliance."
			elif ratio >= 0.3:
				descriptor = "Fading"
				flavor = "Wonder is still present, but the realm is not glowing at full strength."
			else:
				descriptor = "Thin"
				flavor = "The realm feels dimmer, weaker, and harder to fully believe."

		"resonance":
			if ratio >= 0.9:
				descriptor = "Harmonized"
				flavor = "The realm is listening and responding with almost no internal resistance."
			elif ratio >= 0.72:
				descriptor = "Tuned"
				flavor = "Its internal rhythm feels aligned and steady."
			elif ratio >= 0.5:
				descriptor = "Steady"
				flavor = "The realm is holding together without obvious distortion."
			elif ratio >= 0.3:
				descriptor = "Uneven"
				flavor = "Something in the realm feels slightly out of tune."
			else:
				descriptor = "Discordant"
				flavor = "The realm feels unstable, strained, and hard to settle."

		"protection":
			if ratio >= 0.9:
				descriptor = "Fortified"
				flavor = "Its protectors feel numerous, alert, and difficult to break through."
			elif ratio >= 0.72:
				descriptor = "Guarded"
				flavor = "The threshold is being watched with real strength."
			elif ratio >= 0.5:
				descriptor = "Covered"
				flavor = "The realm is protected, though not beyond challenge."
			elif ratio >= 0.3:
				descriptor = "Thinly Guarded"
				flavor = "Protection is present, but the defensive edge feels lighter than it should."
			else:
				descriptor = "Exposed"
				flavor = "The threshold feels easier to breach than the realm would want."

		"veil_strength":
			if access_state == "view_only":
				if ratio >= 0.85:
					descriptor = "Sealed"
					flavor = "The veil is holding hard, and true entry still feels distant."
				elif ratio >= 0.6:
					descriptor = "Veiled"
					flavor = "The realm can be seen, but the crossing still resists full access."
				else:
					descriptor = "Porous"
					flavor = "The veil is still there, but it does not feel perfectly secure."
			else:
				if ratio >= 0.85:
					descriptor = "Hidden"
					flavor = "The realm still keeps much of itself obscured."
				elif ratio >= 0.6:
					descriptor = "Thinned"
					flavor = "Ordinary rules are weakening around the edges."
				elif ratio >= 0.35:
					descriptor = "Opened"
					flavor = "The boundary is parting more easily than before."
				else:
					descriptor = "Exposed"
					flavor = "The veil feels weak enough that crossing pressure can be felt directly."

		"prosperity":
			if ratio >= 0.9:
				descriptor = "Flourishing"
				flavor = "The realm feels wealthy, supplied, and confidently expanding."
			elif ratio >= 0.72:
				descriptor = "Healthy"
				flavor = "Its resources and general condition feel comfortably strong."
			elif ratio >= 0.5:
				descriptor = "Stable"
				flavor = "The realm is functioning well enough, even if not lavishly."
			elif ratio >= 0.3:
				descriptor = "Strained"
				flavor = "The realm can still function, but it does not feel economically comfortable."
			else:
				descriptor = "Starving"
				flavor = "The realm feels deprived, underfed, and at risk of visible decline."

		"stability":
			if ratio >= 0.9:
				descriptor = "Anchored"
				flavor = "The realm feels deeply settled and difficult to shake."
			elif ratio >= 0.72:
				descriptor = "Secure"
				flavor = "Its internal order feels dependable and intact."
			elif ratio >= 0.5:
				descriptor = "Holding"
				flavor = "The realm is standing, though not without stress."
			elif ratio >= 0.3:
				descriptor = "Shaken"
				flavor = "The realm feels vulnerable to disruption."
			else:
				descriptor = "Fractured"
				flavor = "Its internal order feels close to giving way."

		"loyalty":
			if ratio >= 0.9:
				descriptor = "Devoted"
				flavor = "Its people feel deeply committed to the realm’s current order."
			elif ratio >= 0.72:
				descriptor = "Backed"
				flavor = "Support feels real and broadly intact."
			elif ratio >= 0.5:
				descriptor = "Compliant"
				flavor = "The realm still has obedience, even if not passionate loyalty."
			elif ratio >= 0.3:
				descriptor = "Restless"
				flavor = "Its people are following, but they do not feel fully settled."
			else:
				descriptor = "Disloyal"
				flavor = "The realm feels emotionally and politically ready to pull away."

		"pressure":
			if ratio >= 0.9:
				descriptor = "Boiling"
				flavor = "Pressure inside the realm feels near open rupture."
			elif ratio >= 0.72:
				descriptor = "Volatile"
				flavor = "The realm feels one bad moment away from visible escalation."
			elif ratio >= 0.5:
				descriptor = "Tense"
				flavor = "Pressure is present and noticeable, even if not yet explosive."
			elif ratio >= 0.3:
				descriptor = "Watchful"
				flavor = "The realm is carrying pressure, but it still feels containable."
			else:
				descriptor = "Clear"
				flavor = "There is pressure in the background, but not enough to define the realm."

		_:
			if is_imaginative_realm:
				descriptor = "Otherworldly" if ratio >= 0.65 else "Unsteady"
				flavor = "This realm does not behave like an ordinary state surface."
			elif is_elemental_realm:
				match native_element:
					"fire":
						descriptor = "Blazing" if ratio >= 0.75 else "Smoldering"
						flavor = "The realm feels defined by heat, force, and disciplined intensity."
					"water":
						descriptor = "Flowing" if ratio >= 0.75 else "Shifting"
						flavor = "The realm feels adaptive, fluid, and emotionally responsive."
					"earth":
						descriptor = "Rooted" if ratio >= 0.75 else "Heavy"
						flavor = "The realm feels grounded, enduring, and difficult to move."
					"air":
						descriptor = "Lifted" if ratio >= 0.75 else "Drifting"
						flavor = "The realm feels light, spiritual, and hard to pin down."
					_:
						descriptor = "Elemental"
						flavor = "The realm is carrying a clear elemental identity."
			elif is_era_kingdom:
				descriptor = "Sovereign" if ratio >= 0.7 else "Imperiled"
				flavor = "The hidden sovereign structure feels powerful, but not invulnerable."
			else:
				descriptor = "%d" % safe_value
				flavor = ""

	return {
		"descriptor": descriptor,
		"flavor": flavor,
		"bar_text": "%d" % safe_value,
		"title_text": ""
	}


static func _resolve_player_stat_surface_title(title: String, descriptor: String, surface_context: Dictionary) -> String:
	var safe_title: String = str(title).strip_edges()
	var safe_descriptor: String = str(descriptor).strip_edges()
	if safe_title == "":
		return safe_descriptor

	var title_mode: String = str(surface_context.get("descriptor_title_mode", "default")).strip_edges().to_lower()
	var perspective: String = str(surface_context.get("narrative_perspective", "first_person")).strip_edges().to_lower()

	if title_mode == "bond_pov" and safe_title == "Bond":
		if perspective == "third_person":
			match safe_descriptor:
				"Devoted":
					return "Bond: Devoted to You"
				"Warm":
					return "Bond: Warm Toward You"
				"Open":
					return "Bond: Open to You"
				"Guarded":
					return "Bond: Guarded Around You"
				"Cold":
					return "Bond: Cold Toward You"
				"Hostile":
					return "Bond: Hostile Toward You"

	if title_mode == "approval_pov" and safe_title == "Approval":
		match safe_descriptor:
			"Beloved":
				return "Approval: Beloved by Them"
			"Backed":
				return "Approval: Backed by Them"
			"Rejected":
				return "Approval: Rejected by Them"

	return "%s: %s" % [safe_title, safe_descriptor]


static func _activities_hub_panel_style(kind: String = "card") -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	var clean_kind: String = str(kind).strip_edges().to_lower()

	match clean_kind:
		"shell":
			style.bg_color = Color(0.018, 0.024, 0.048, 0.985)
			style.border_color = Color(0.96, 0.68, 0.28, 0.34)
			style.shadow_color = Color(0.96, 0.54, 0.16, 0.18)
			style.shadow_size = 18
		"hero":
			style.bg_color = Color(0.055, 0.072, 0.12, 0.94)
			style.border_color = Color(1.0, 0.82, 0.42, 0.42)
			style.shadow_color = Color(0.96, 0.64, 0.22, 0.16)
			style.shadow_size = 14
		_:
			style.bg_color = Color(0.038, 0.05, 0.086, 0.94)
			style.border_color = Color(0.62, 0.78, 1.0, 0.24)
			style.shadow_color = Color(0.1, 0.18, 0.38, 0.12)
			style.shadow_size = 10

	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	style.shadow_offset = Vector2.ZERO
	return style


static func _pet_shop_listing_category_label(
	category_id: String
) -> String:
	match category_id:
		"mythical":
			return "MYTHICAL & ARCANE"
		"working":
			return "WORKING, GUARDIAN & MOUNT"
		"exotic":
			return "EXOTIC & WILD"
		_:
			return "HOUSEHOLD COMPANIONS"


static func _pet_shop_listing_icon(
	listing: Dictionary
) -> String:
	var species_id: String = str(
		listing.get(
			"species_id",
			listing.get(
				"listing_id",
				""
			)
		)
	).strip_edges().to_lower()

	if str(
		listing.get(
			"entity_kind",
			"animal"
		)
	).to_lower() == "mythical":
		return "✦"

	match species_id:
		"dog":
			return "🐕"
		"cat":
			return "🐈"
		"horse":
			return "🐎"
		"cow":
			return "🐄"
		"chicken":
			return "🐓"
		"sheep":
			return "🐑"
		"goat":
			return "🐐"
		"rabbit":
			return "🐇"
		"duck":
			return "🦆"
		"crow":
			return "🐦"
		_:
			return "🐾"


static func _entity_relationship_popup_panel_style(accent: Color) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.1, 0.12, 0.94)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = accent
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	style.shadow_size = 4
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
	return style


static func _entity_relationship_progress_background_style() -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.16, 0.18, 0.94)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	return style


static func _entity_relationship_progress_fill_style(fill_color: Color) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = fill_color
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	return style


static func _entity_relationship_stat_palette(value: int, max_value: int, mode: String = "") -> Dictionary:
	var ratio: float = 0.0
	if max_value > 0:
		ratio = clamp(float(value) / float(max_value), 0.0, 1.0)

	var fill_color: Color = Color(0.7, 0.84, 1.0, 0.96)
	var text_color: Color = Color(1.0, 1.0, 1.0, 0.98)

	match mode:
		"bond":
			if ratio <= 0.35:
				fill_color = Color(1.0, 0.34, 0.34, 0.96)
			elif ratio <= 0.74:
				fill_color = Color(1.0, 0.84, 0.22, 0.96)
			else:
				fill_color = Color(1.0, 0.38, 0.68, 0.96)
		"danger":
			if ratio >= 0.7:
				fill_color = Color(1.0, 0.38, 0.28, 0.98)
			elif ratio >= 0.4:
				fill_color = Color(1.0, 0.72, 0.24, 0.96)
			else:
				fill_color = Color(0.92, 0.94, 0.52, 0.96)
		"health":
			fill_color = Color(0.48, 1.0, 0.76, 0.96)
		"training":
			fill_color = Color(0.76, 1.0, 0.48, 0.96)
		"hunger":
			fill_color = Color(1.0, 0.74, 0.32, 0.96)
		_:
			if ratio <= 0.35:
				fill_color = Color(1.0, 0.34, 0.34, 0.96)
			elif ratio <= 0.74:
				fill_color = Color(1.0, 0.84, 0.22, 0.96)
			else:
				fill_color = Color(1.0, 0.38, 0.68, 0.96)

	return {
		"fill": fill_color,
		"text": text_color
	}


static func _entity_relationship_card_danger_color(danger_value: int) -> Color:
	var safe_danger: int = clampi(danger_value, 0, 10)

	if safe_danger <= 1:
		return Color(0.36, 1.0, 0.42, 1.0)
	if safe_danger <= 3:
		return Color(0.62, 1.0, 0.48, 1.0)
	if safe_danger <= 5:
		return Color(1.0, 0.88, 0.36, 1.0)
	if safe_danger <= 7:
		return Color(1.0, 0.58, 0.28, 1.0)

	return Color(1.0, 0.3, 0.24, 1.0)


static func _entity_relationship_card_dot_row(value: int, max_value: int = 100, dot_count: int = 5) -> String:
	var ratio: float = 0.0
	if max_value > 0:
		ratio = clamp(float(value) / float(max_value), 0.0, 1.0)

	var filled: int = clampi(int(round(ratio * float(dot_count))), 0, dot_count)
	var out: Array = []
	for i in range(dot_count):
		out.append("●" if i < filled else "○")
	return "".join(out)


static func _entity_relationship_trait_icon(trait_text: String) -> String:
	match str(trait_text).strip_edges().to_lower():
		"strong":
			return "✦"
		"sensitive":
			return "❤"
		"trainable":
			return "⬆"
		"protective":
			return "🛡"
		"playful":
			return "★"
		"loyal":
			return "✚"
		"gentle":
			return "❀"
		"alert":
			return "⚑"
		_:
			return "◆"


static func _entity_relationship_delta_flash_color(stat_key: String, delta: int, positive_delta_is_good: bool = true) -> Color:
	var clean_key: String = str(stat_key).strip_edges().to_lower()
	var good_delta: bool = delta > 0 if positive_delta_is_good else delta < 0

	if clean_key == "hunger":
		good_delta = delta < 0

	if good_delta:
		return Color(0.78, 1.0, 0.66, 1.0)

	return Color(1.0, 0.42, 0.46, 1.0)


static func _activity_label_should_be_hidden_from_activities(action_label: String) -> bool:
	var clean_label: String = str(action_label).strip_edges()
	var lowered: String = clean_label.to_lower()

	if clean_label == "":
		return true

	if clean_label == "Begin Boxing":
		return false

	if clean_label in [
		"Apply for Part Time Job",
		"Browse Part Time Jobs",
		"Apply for Full Time Job",
		"Browse Full Time Jobs",
		"Browse Famous Careers",
		"View Job Details",
		"Work Normally",
		"Work Hard",
		"Slack Off",
		"Ask for Raise",
		"View Coworkers",
		"Quit Job"
	]:
		return true

	if clean_label in [
		"Train Bending",
		"Teach Bending",
		"Grant Bending",
		"Remove Bending",
		"Challenge To Bending Duel",
		"Train Boxing",
		"Boxing Sparring",
		"Boxing Hub",
		"Open Boxing Hub",
		"Book Boxing Match",
		"View Boxing Record",
		"View Boxing Rivalries",
		"Call Out Opponent",
		"Change Weight Class",
		"Review Last Fight Log",
		"Enter Amateur Tournament"
	]:
		return true

	if clean_label == "Start Boxing":
		return true

	if lowered.find("career") >= 0:
		return true
	if lowered.find("job") >= 0:
		return true
	if lowered.find("coworker") >= 0:
		return true
	if lowered.find("work ") >= 0 or lowered == "work":
		return true
	if lowered.find("train") >= 0:
		return true
	if lowered.find("sparring") >= 0:
		return true

	return false


static func _normalize_activity_action_to_player_action(action_label: String) -> String:
	match action_label:
		"Apply for Full Time Job":
			return "browse_jobs"
		"Browse Jobs":
			return "browse_jobs"
		"View Job Details":
			return "view_job_details"
		"Work Normally":
			return "work_normally"
		"Work Hard":
			return "work_hard"
		"Slack Off":
			return "slack_off"
		"Ask for Raise":
			return "ask_for_raise"
		"Quit Job":
			return "quit_job"
		"Start School":
			return "start_school"
		"Enroll In Era School":
			return "enroll_era_school"
		"Enroll In Bending School":
			return "enroll_bending_school"
		"Dual Enrollment":
			return "dual_enrollment"
		"Interact With Classmates":
			return "interact_with_classmates"
		_:
			return action_label.to_lower().replace(" ", "_")


static func _death_transition_audio_candidate_paths() -> Array:
	return [
		"res://audio/music/Death.ogg",
		"res://Audio/Music/Death.ogg",
		"res://audio/Death.ogg",
		"res://Audio/Death.ogg",
		"res://Death.ogg"
	]


static func _grocery_store_music_profiles() -> Dictionary:
	return {
		"basket_lane_market": {
			"display_name": "Era-Mart Store Speaker",
			"context_key": "grocery_store_era_mart",
			"surface_id": "food_contract_hub_era_mart",
			"volume_db": -17.25,
			"fade_in_ms": 950,
			"fade_out_ms": 1050,
			"rotation_crossfade_ms": 1800,
			"track_variants": [
				{ "id": "era_mart_store_speaker_1", "file": "EraMartMusic.ogg"},
				{ "id": "era_mart_store_speaker_2", "file": "EraMartMusic2.ogg"},
				{ "id": "era_mart_store_speaker_3", "file": "EraMartMusic3.ogg"}
			],
			"context_keys": ["grocery_store_era_mart", "era_mart", "basket_lane_market", "food_contract_hub_era_mart"]
		},
		"goldleaf_grocers": {
			"display_name": "Goldleaf Store Speaker",
			"context_key": "grocery_store_goldleaf",
			"surface_id": "food_contract_hub_goldleaf",
			"volume_db": -18.25,
			"fade_in_ms": 950,
			"fade_out_ms": 1050,
			"rotation_crossfade_ms": 1800,
			"track_variants": [
				{ "id": "goldleaf_store_speaker_1", "file": "GoldMusic.ogg"},
				{ "id": "goldleaf_store_speaker_2", "file": "GoldMusic2.ogg"}
			],
			"context_keys": ["grocery_store_goldleaf", "goldleaf", "goldleaf_grocers", "food_contract_hub_goldleaf"]
		}
	}


static func _grocery_store_music_candidate_paths(file_name: String) -> Array:
	var clean_file: String = str(file_name).strip_edges()
	if clean_file == "":
		return []

	return [
		"res://audio/music/%s" % clean_file,
		"res://audio/%s" % clean_file,
		"res://%s" % clean_file
	]


static func _birth_intro_cry_audio_contract() -> Dictionary:
	return {
		"schema": "eralife.one_shot_audio_event_contract",
		"version": 1,
		"event_id": "birth_intro_cry",
		"display_name": "Birth Intro Cry",
		"paths": [
			"res://audio/sfx/BirthIntroCry.ogg",
			"res://audio/music/BirthIntroCry.ogg",
			"res://BirthIntroCry.ogg"
		],
		"bus": "Master",
		"volume_db": -1.25,
		"pitch_scale": 1.0,
		"play_once": true,
		"allowed_entry_kinds": ["custom", "random", "household_curated_life"]
	}


static func _character_switch_audio_contract() -> Dictionary:
	return {
		"schema": "eralife.one_shot_audio_event_contract",
		"version": 1,
		"event_id": "character_switch",
		"display_name": "Character Switch",
		"paths": [
			"res://audio/sfx/CharacterSwitch.ogg",
			"res://audio/music/CharacterSwitch.ogg",
			"res://CharacterSwitch.ogg"
		],
		"bus": "Master",
		"volume_db": -0.75,
		"pitch_scale": 1.0,
		"play_once": true,
		"duck_fade_ms": 95,
		"restore_fade_ms": 180,
		"duck_volume_drop_db": 17.0,
		"minimum_duck_volume_db": -31.0,
		"source": "relationship_profile_switch"
	}


static func _append_character_switch_duck_player(out: Array, player: AudioStreamPlayer) -> void:
	if player == null or not is_instance_valid(player):
		return
	if not player.playing:
		return
	if out.has(player):
		return

	out.append(player)


static func _birth_intro_cry_should_arm_for_settings(settings: Dictionary) -> bool:
	var entry_kind: String = str(settings.get("_god_mode_entry_kind", settings.get("god_mode_entry_kind", "custom"))).strip_edges().to_lower()
	var starting_age: int = int(settings.get("starting_age", settings.get("age", 0)))

	if starting_age != 0:
		return false

	if entry_kind == "household_curated_life":
		return bool(settings.get("birth_intro_cry_allowed", false))

	return true


static func _god_mode_menu_music_transition_lead_seconds_for_stream(stream_length: float, profile: Dictionary) -> float:
	var raw_lead: float = float(profile.get("rotation_lead_seconds", 0.42))
	var min_lead: float = float(profile.get("rotation_min_lead_seconds", 0.24))
	var max_lead: float = float(profile.get("rotation_max_lead_seconds", 0.62))
	var max_tail_ratio: float = float(profile.get("rotation_max_tail_ratio", 0.018))
	var ratio_limited_lead: float = stream_length * max_tail_ratio

	if stream_length <= 1.0:
		return raw_lead

	var resolved_lead: float = raw_lead
	if ratio_limited_lead > 0.0:
		resolved_lead = min(raw_lead, ratio_limited_lead)

	return clamp(resolved_lead, min_lead, max_lead)


static func _god_mode_menu_music_resolve_path(file_name: String) -> String:
	var clean_file: String = str(file_name).strip_edges()
	if clean_file == "":
		return ""
	if clean_file.begins_with("res://"):
		return clean_file
	return "res://audio/music/%s" % clean_file


static func _get_month_name(m):
	var names = [
		"January", "February", "March", "April", "May", "June",
		"July", "August", "September", "October", "November", "December"
	]
	return names [m - 1]


static func _format_civic_office_article_title(job: String) -> String:
	var clean_job: String = str(job).strip_edges()
	var lower_job: String = clean_job.to_lower()

	if lower_job == "president" or lower_job == "president of the united states":
		return "The President of the United States"

	if lower_job == "first lady":
		return "The First Lady"

	if lower_job == "first gentleman":
		return "The First Gentleman"

	return ""


static func _format_job_for_grandparent(job: String) -> String:
	if job == "Retired":
		return "retired"
	return "a %s" % job.to_lower()


static func _format_birth_relative_civic_role(npc: Person) -> String:
	if npc == null:
		return ""

	var civic_title: String = str(npc.get("civic_title")).strip_edges()
	var job_text: String = str(npc.job).strip_edges()

	for raw_text in [civic_title, job_text]:
		var clean_text: String = str(raw_text).strip_edges()
		var lower_text: String = clean_text.to_lower()

		if lower_text == "president" or lower_text == "president of the united states":
			return "The President of the United States"

		if lower_text == "first lady":
			return "The First Lady"

		if lower_text == "first gentleman":
			return "The First Gentleman"

	return ""


static func _feature_overrides_for_mode(mode_text: String) -> Dictionary:
	match mode_text.to_lower():
		"realistic":
			return {
				"bending": false,
				"superpowers": false,
				"vampires": false,
				"artifacts": false,
				"supernatural_school": false,
				"supernatural_events": false
			}

		"enhanced":
			return {
				"bending": true,
				"superpowers": false,
				"vampires": false,
				"artifacts": false,
				"supernatural_school": true,
				"supernatural_events": true
			}

		_:
			return {
				"bending": true,
				"superpowers": true,
				"vampires": true,
				"artifacts": true,
				"supernatural_school": true,
				"supernatural_events": true
			}


static func _build_age_up_loading_prewarm_signature(loading_context: Dictionary) -> String:
	var headline: String = str(loading_context.get("headline", "")).strip_edges()
	var subline: String = str(loading_context.get("subline", "")).strip_edges()
	var dominant_domain: String = str(loading_context.get("dominant_domain", "general")).strip_edges().to_lower()
	if dominant_domain == "":
		dominant_domain = "general"
	var reality_mode: String = str(loading_context.get("reality_mode", "realistic")).strip_edges().to_lower()
	if reality_mode == "":
		reality_mode = "realistic"
	var era_name: String = str(loading_context.get("era_name", "")).strip_edges().to_lower()
	var target_year: int = int(loading_context.get("target_year", 0))
	return "%s|%s|%s|%s|%s|%d" % [
		headline,
		subline,
		dominant_domain,
		reality_mode,
		era_name,
		target_year
	]


static func _build_age_up_loading_text_refresh_signature(loading: Dictionary, overlay_context: Dictionary) -> String:
	var stall_score: float = float(loading.get("stall_score", 0.0))
	return "%s|%s|%s|%s|%s|%s" % [
		str(loading.get("current_phase", "preflight")),
		str(loading.get("completion_state", "running")),
		str(loading.get("session_stage", "boot")),
		str(loading.get("subline", "")),
		str(overlay_context.get("target_year", 0)),
		str(int(floor(stall_score / 10.0)))
	]


static func _resolve_age_up_loading_text_refresh_interval_ms(loading: Dictionary, overlay_context: Dictionary) -> int:
	var current_phase: String = str(loading.get("current_phase", "preflight"))
	var completion_state: String = str(loading.get("completion_state", "running"))
	var session_stage: String = str(loading.get("session_stage", "boot"))
	var stall_score: float = float(loading.get("stall_score", 0.0))
	var interval_ms: int = 96

	if completion_state == "complete" or session_stage == "complete":
		interval_ms = 42
	elif session_stage in ["settling_previous_year", "settling_current_year"]:
		interval_ms = 56
	elif current_phase in ["core_state_resolution", "internal_identity_drift", "year_budget_pipeline_commit", "commit_settling"]:
		interval_ms = 72
	elif stall_score >= 60.0:
		interval_ms = 72
	elif stall_score >= 45.0:
		interval_ms = 84

	if str(overlay_context.get("reality_mode", "")).strip_edges().to_lower() == "chaos":
		interval_ms = min(interval_ms, 84)

	return max(28, interval_ms)


static func _build_theme_color_override_cache_key(
	override_name: String,
	color: Color,
	quantization_steps: int = 64
) -> String:
	var quant_steps: int = max(1, quantization_steps)
	var r_bucket: int = int(round(clamp(color.r, 0.0, 1.0) * quant_steps))
	var g_bucket: int = int(round(clamp(color.g, 0.0, 1.0) * quant_steps))
	var b_bucket: int = int(round(clamp(color.b, 0.0, 1.0) * quant_steps))
	var a_bucket: int = int(round(clamp(color.a, 0.0, 1.0) * quant_steps))
	return "%s|%d|%d|%d|%d" % [
		override_name,
		r_bucket,
		g_bucket,
		b_bucket,
		a_bucket
	]


static func _build_control_scale_cache_key(
	scale_value: Vector2,
	quantization_steps: int = 384
) -> String:
	var quant_steps: int = max(1, quantization_steps)
	var x_bucket: int = int(round(scale_value.x * quant_steps))
	var y_bucket: int = int(round(scale_value.y * quant_steps))
	return "%d|%d" % [x_bucket, y_bucket]


static func _build_control_rotation_cache_key(
	rotation_value: float,
	quantization_steps: int = 8192
) -> String:
	var quant_steps: int = max(1, quantization_steps)
	return str(int(round(rotation_value * quant_steps)))


static func _build_control_position_cache_key(
	position_value: Vector2,
	quantization_steps: int = 4
) -> String:
	var quant_steps: int = max(1, quantization_steps)
	var x_bucket: int = int(round(position_value.x * quant_steps))
	var y_bucket: int = int(round(position_value.y * quant_steps))
	return "%d|%d" % [x_bucket, y_bucket]


static func _build_canvas_item_modulate_cache_key(
	color: Color,
	quantization_steps: int = 128
) -> String:
	var quant_steps: int = max(1, quantization_steps)
	var r_bucket: int = int(round(clamp(color.r, 0.0, 1.0) *
	quant_steps))
	var g_bucket: int = int(round(clamp(color.g, 0.0, 1.0) *
	quant_steps))
	var b_bucket: int = int(round(clamp(color.b, 0.0, 1.0) *
	quant_steps))
	var a_bucket: int = int(round(clamp(color.a, 0.0, 1.0) *
	quant_steps))
	return "%d|%d|%d|%d" % [
		r_bucket,
		g_bucket,
		b_bucket,
		a_bucket
	]


static func _build_age_up_loading_copy_bucket_key(overlay_context: Dictionary, loading: Dictionary) -> String:
	var reality_mode: String = str(overlay_context.get("reality_mode", "realistic")).strip_edges().to_lower()
	if reality_mode == "":
		reality_mode = "realistic"

	var dominant_domain: String = str(loading.get("dominant_domain", overlay_context.get("dominant_domain", "general"))).strip_edges().to_lower()
	if dominant_domain == "":
		dominant_domain = "general"

	return "%s|%s" % [reality_mode, dominant_domain]


static func _build_age_up_loading_did_you_know_static_bucket_key(overlay_context: Dictionary) -> String:
	var reality_mode: String = str(overlay_context.get("reality_mode", "realistic")).strip_edges().to_lower()
	if reality_mode == "":
		reality_mode = "realistic"

	var era_name: String = str(overlay_context.get("era_name", "")).strip_edges().to_lower()

	return "%s|%s" % [reality_mode, era_name]


static func _resolve_age_up_loading_dominant_domain(influences: Dictionary) -> String:
	var best_key: String = "general"
	var best_score: float = -1.0
	for raw_key in influences.keys():
		var key: String = str(raw_key)
		var score: float = float(influences.get(key, 0.0))
		if score > best_score:
			best_score = score
			best_key = key
	return best_key


static func _age_up_loading_phase_display_text(phase_key: String) -> String:
	match phase_key:
		"preflight":
			return "Preparing year runtime"
		"commit_settling":
			return "Settling deferred workloads"
		"core_state_resolution":
			return "Advancing the world"
		"internal_identity_drift":
			return "Simulating people and pressure"
		"year_budget_pipeline_commit":
			return "Resolving distant lives"
		"player_phase_contract":
			return "Locking the player's year"
		"choice_and_opportunity_surfacing":
			return "Surfacing scenarios and opportunities"
		"narrative_and_presentation":
			return "Composing events and world feed"
		"complete":
			return "Year resolved"
		_:
			return "Time is turning..."


static func _bending_sum_int_dictionary_values(row: Dictionary) -> int:
	var total: int = 0
	for raw_key in row.keys():
		total += max(0, int(row.get(raw_key, 0)))
	return total


static func _sanitize_age_up_loading_did_you_know_row(raw_row: Variant, fallback_index: int) -> Dictionary:
	if typeof(raw_row) != TYPE_DICTIONARY:
		return {}

	var row: Dictionary = raw_row
	if bool(row.get("_normalized", false)):
		var normalized_text: String = str(row.get("text", "")).strip_edges()
		var normalized_key: String = str(row.get("key", "")).strip_edges()
		if normalized_text == "" or normalized_key == "":
			return {}
		return {
			"key": normalized_key,
			"text": normalized_text,
			"_normalized": true
		}

	var text: String = str(row.get("text", "")).strip_edges()
	if text == "":
		return {}
	var key: String = str(row.get("key", "")).strip_edges()
	if key == "":
		key = "did_you_know_%d_%d" % [fallback_index, abs(int(text.hash()))]
	return {
		"key": key,
		"text": text,
		"_normalized": true
	}


static func _build_age_up_loading_eralife_markup_cache_key(visible_text: String, phase_bucket: int) -> String:
	return "%s|%d" % [visible_text.strip_edges(), phase_bucket]


static func _feature_override_keys() -> Array:
	return [
		"bending",
		"superpowers",
		"vampires",
		"artifacts",
		"dragonballs",
		"many_realms",
		"supernatural_school",
		"supernatural_events"
	]


static func _feature_override_label(feature_name: String) -> String:
	match feature_name:
		"bending":
			return "Bending"
		"superpowers":
			return "Super Powers"
		"vampires":
			return "Vampires"
		"artifacts":
			return "Artifacts"
		"dragonballs":
			return "Dragon Balls"
		"many_realms":
			return "Many Realms"
		"supernatural_school":
			return "Supernatural School"
		"supernatural_events":
			return "Supernatural Events"
		_:
			return feature_name.capitalize()


static func _build_god_mode_field_box_style(bg_color: Color, border_color: Color, shadow_color: Color) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border_color
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	style.content_margin_left = 12
	style.content_margin_top = 8
	style.content_margin_right = 12
	style.content_margin_bottom = 8
	style.shadow_color = shadow_color
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 2)
	return style


static func _god_mode_scrollbar_idle_fade_delay_ms() -> int:
	return 120


static func _god_mode_panel_shaded_color(source: Color, rgb_scale: float, alpha: float = -1.0) -> Color:
	var out_alpha:= source.a if alpha < 0.0 else alpha
	return Color(
		clamp(source.r * rgb_scale, 0.0, 1.0),
		clamp(source.g * rgb_scale, 0.0, 1.0),
		clamp(source.b * rgb_scale, 0.0, 1.0),
		clamp(out_alpha, 0.0, 1.0)
	)


static func _god_mode_month_name(month_value: int) -> String:
	var month_names:= [
		"January",
		"February",
		"March",
		"April",
		"May",
		"June",
		"July",
		"August",
		"September",
		"October",
		"November",
		"December"
	]
	var clamped_value:= int(clamp(month_value, 1, 12))
	return month_names [clamped_value - 1]


static func _is_god_mode_leap_year(year_value: int) -> bool:
	var normalized_year:= year_value
	if normalized_year < 0:
		normalized_year += 1
	if normalized_year % 400 == 0:
		return true
	if normalized_year % 100 == 0:
		return false
	return normalized_year % 4 == 0


static func _selected_god_mode_option_value(button: OptionButton, fallback: int = 0) -> int:
	if button == null or button.item_count == 0:
		return fallback
	var idx:= button.get_selected_id()
	if idx < 0:
		idx = 0
	var metadata = button.get_item_metadata(idx)
	if typeof(metadata) == TYPE_INT or typeof(metadata) == TYPE_FLOAT:
		return int(metadata)
	var text:= button.get_item_text(idx)
	if text.is_valid_int():
		return int(text)
	return fallback


static func _style_god_mode_check_box(check_box: CheckBox) -> void:
	if check_box == null:
		return

	check_box.custom_minimum_size = Vector2(28, 28)
	check_box.scale = Vector2(1.08, 1.08)
	check_box.self_modulate = Color(1.0, 0.96, 1.0, 1.0)


static func _god_mode_elemental_country_visual_profile(country_text: String) -> Dictionary:
	var clean_country: String = str(country_text).strip_edges()
	var canonical: String = clean_country

	if clean_country in ["Northern Water Tribe", "Southern Water Tribe", "Water Tribe"]:
		canonical = "Water Tribe"
	elif clean_country in ["Northern Air Temple", "Southern Air Temple", "Eastern Air Temple", "Western Air Temple", "Air Nomads"]:
		canonical = "Air Nomads"

	match canonical:
		"Fire Nation":
			return {
				"nation": "Fire Nation",
				"core": Color(1.0, 0.3, 0.12, 1.0),
				"glow": Color(1.0, 0.62, 0.24, 0.86),
				"soft": Color(0.42, 0.08, 0.03, 0.92)
			}
		"Earth Kingdom":
			return {
				"nation": "Earth Kingdom",
				"core": Color(0.46, 0.86, 0.32, 1.0),
				"glow": Color(0.86, 1.0, 0.46, 0.82),
				"soft": Color(0.12, 0.3, 0.1, 0.92)
			}
		"Water Tribe":
			return {
				"nation": "Water Tribe",
				"core": Color(0.34, 0.72, 1.0, 1.0),
				"glow": Color(0.68, 0.92, 1.0, 0.86),
				"soft": Color(0.06, 0.16, 0.38, 0.92)
			}
		"Air Nomads":
			return {
				"nation": "Air Nomads",
				"core": Color(0.96, 0.92, 0.78, 1.0),
				"glow": Color(1.0, 0.98, 0.88, 0.86),
				"soft": Color(0.24, 0.22, 0.18, 0.82)
			}
		_:
			return {}


static func _build_god_mode_section_divider_style(line_color: Color, thickness: int = 2) -> StyleBoxLine:
	var style:= StyleBoxLine.new()
	style.color = line_color
	style.thickness = thickness
	style.grow_begin = 4.0
	style.grow_end = 4.0
	return style


static func _style_god_mode_value_label(value_label: Label) -> void:
	if value_label == null:
		return
	value_label.text = "0"
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.custom_minimum_size = Vector2(54, 0)
	value_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.8, 1.0))
	value_label.add_theme_font_size_override("font_size", 16)


static func _god_mode_back_to_main_menu_circle_button_size() -> int:
	return 54


static func _build_god_mode_circle_button_style(bg_color: Color, border_color: Color, shadow_color: Color, border_width: int = 2, shadow_size: int = 12) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.border_color = border_color

	var circle_radius: int = 256
	style.corner_radius_top_left = circle_radius
	style.corner_radius_top_right = circle_radius
	style.corner_radius_bottom_right = circle_radius
	style.corner_radius_bottom_left = circle_radius

	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	style.shadow_color = shadow_color
	style.shadow_size = shadow_size
	style.shadow_offset = Vector2.ZERO
	return style


static func _god_mode_palette_for_mode(mode_text: String, is_custom: bool = false) -> Dictionary:
	var palette:= {}

	match mode_text:
		"realistic":
			palette = {
				"panel_base": Color(0.08, 0.12, 0.16, 0.96),
				"panel_hover": Color(0.11, 0.16, 0.21, 0.98),
				"border": Color(0.62, 0.9, 0.82, 0.34),
				"border_hover": Color(0.84, 1.0, 0.94, 0.56),
				"shadow": Color(0.08, 0.18, 0.16, 0.2),
				"shadow_hover": Color(0.1, 0.26, 0.22, 0.3),
				"panel_modulate_idle": Color(0.98, 1.0, 0.99, 1.0),
				"panel_modulate_hover": Color(1.0, 1.0, 1.0, 1.0),
				"dim": Color(0.03, 0.06, 0.08, 0.94),
				"title": Color(0.95, 1.0, 0.97, 1.0),
				"subtitle": Color(0.88, 0.98, 0.93, 0.98),
				"body": Color(0.92, 0.98, 0.95, 0.88),
				"status": Color(0.82, 1.0, 0.9, 1.0),
				"preview": Color(0.94, 1.0, 0.96, 1.0),
				"accent": Color(0.56, 0.92, 0.78, 1.0),
				"accent_soft": Color(0.2, 0.33, 0.28, 0.96)
			}
		"enhanced":
			palette = {
				"panel_base": Color(0.17, 0.1, 0.27, 0.95),
				"panel_hover": Color(0.2, 0.12, 0.3, 0.97),
				"border": Color(0.82, 0.75, 0.98, 0.34),
				"border_hover": Color(0.92, 0.86, 1.0, 0.55),
				"shadow": Color(0.26, 0.12, 0.48, 0.22),
				"shadow_hover": Color(0.42, 0.22, 0.7, 0.3),
				"panel_modulate_idle": Color(0.98, 0.98, 1.0, 1.0),
				"panel_modulate_hover": Color(1.0, 1.0, 1.0, 1.0),
				"dim": Color(0.08, 0.02, 0.13, 0.94),
				"title": Color(1.0, 0.97, 0.9, 1.0),
				"subtitle": Color(0.98, 0.93, 1.0, 0.98),
				"body": Color(0.98, 0.95, 1.0, 0.86),
				"status": Color(0.86, 0.95, 1.0, 1.0),
				"preview": Color(1.0, 0.98, 0.9, 1.0),
				"accent": Color(0.86, 0.54, 1.0, 1.0),
				"accent_soft": Color(0.32, 0.16, 0.5, 0.98)
			}
		_:
			palette = {
				"panel_base": Color(0.25, 0.07, 0.17, 0.96),
				"panel_hover": Color(0.31, 0.09, 0.2, 0.98),
				"border": Color(1.0, 0.48, 0.72, 0.38),
				"border_hover": Color(1.0, 0.74, 0.86, 0.62),
				"shadow": Color(0.44, 0.1, 0.28, 0.24),
				"shadow_hover": Color(0.62, 0.16, 0.38, 0.34),
				"panel_modulate_idle": Color(1.0, 0.98, 0.99, 1.0),
				"panel_modulate_hover": Color(1.0, 1.0, 1.0, 1.0),
				"dim": Color(0.1, 0.01, 0.06, 0.95),
				"title": Color(1.0, 0.96, 0.92, 1.0),
				"subtitle": Color(1.0, 0.88, 0.93, 0.98),
				"body": Color(1.0, 0.93, 0.96, 0.88),
				"status": Color(1.0, 0.82, 0.92, 1.0),
				"preview": Color(1.0, 0.96, 0.92, 1.0),
				"accent": Color(1.0, 0.46, 0.76, 1.0),
				"accent_soft": Color(0.44, 0.14, 0.28, 0.98)
			}

	if is_custom:
		palette ["border"] = Color(1.0, 0.88, 0.6, 0.42)
		palette ["border_hover"] = Color(1.0, 0.95, 0.78, 0.68)
		palette ["status"] = Color(1.0, 0.92, 0.66, 1.0)
		palette ["accent"] = Color(1.0, 0.84, 0.48, 1.0)
		palette ["accent_soft"] = Color(0.36, 0.24, 0.1, 0.96)

	return palette


static func _is_god_mode_presentation_control(control: Control) -> bool:
	return control is Button or control is OptionButton or control is LineEdit or control is SpinBox or control is CheckBox


static func _god_mode_presenter_state_for(control: Control) -> String:
	if control == null:
		return "idle"
	var hovered:= bool(control.get_meta("god_mode_presenter_hovered", false))
	if control.has_focus():
		return "focus"
	if hovered:
		return "hover"
	return "idle"


static func _god_mode_subtitle_glitch_color_cycle() -> Array:
	return [
		Color(0.24, 0.86, 1.0, 1.0),
		Color(1.0, 0.78, 0.34, 1.0),
		Color(0.92, 0.44, 1.0, 1.0),
		Color(0.48, 1.0, 0.72, 1.0),
		Color(1.0, 0.34, 0.48, 1.0),
		Color(0.82, 0.7, 0.46, 1.0)
	]


static func _build_reality_mode_state_button_style(bg_color: Color, border_color: Color, shadow_color: Color) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = border_color
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_right = 18
	style.corner_radius_bottom_left = 18
	style.content_margin_left = 12
	style.content_margin_top = 10
	style.content_margin_right = 12
	style.content_margin_bottom = 10
	style.shadow_color = shadow_color
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 5)
	return style


static func _make_stat_slider(max_value: float) -> HSlider:
	var slider:= HSlider.new()
	slider.min_value = 0
	slider.max_value = max_value
	slider.step = 1
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(0, 28)
	slider.focus_mode = Control.FOCUS_CLICK
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return slider


static func _sync_single_stat_value_label(slider: HSlider, value_label: Label) -> void:
	if slider == null or value_label == null:
		return
	value_label.text = str(int(round(slider.value)))


static func _build_god_mode_slider_track_style(fill_color: Color, border_color: Color, shadow_color: Color) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border_color
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_right = 9
	style.corner_radius_bottom_left = 9
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.shadow_color = shadow_color
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 1)
	return style


static func _build_god_mode_slider_streak_style(fill_color: Color, border_color: Color, shadow_color: Color) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border_color
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	style.shadow_color = shadow_color
	style.shadow_size = 14
	style.shadow_offset = Vector2.ZERO
	return style


static func _get_god_mode_slider_palette(slider: HSlider) -> Dictionary:
	var stat_key:= ""
	if slider != null and slider.has_meta("god_mode_stat_key"):
		stat_key = str(slider.get_meta("god_mode_stat_key")).to_lower()

	match stat_key:
		"happiness":
			return {
				"core": Color(1.0, 0.82, 0.3, 1.0),
				"soft": Color(0.7, 0.46, 0.12, 0.98),
				"glow": Color(1.0, 0.76, 0.22, 0.24),
				"label": Color(1.0, 0.96, 0.82, 1.0)
			}
		"health":
			return {
				"core": Color(0.98, 0.34, 0.3, 1.0),
				"soft": Color(0.54, 0.14, 0.16, 0.98),
				"glow": Color(0.98, 0.34, 0.3, 0.24),
				"label": Color(1.0, 0.9, 0.88, 1.0)
			}
		"smarts":
			return {
				"core": Color(0.28, 0.72, 1.0, 1.0),
				"soft": Color(0.1, 0.28, 0.56, 0.98),
				"glow": Color(0.28, 0.72, 1.0, 0.24),
				"label": Color(0.9, 0.97, 1.0, 1.0)
			}
		"looks":
			return {
				"core": Color(1.0, 0.46, 0.78, 1.0),
				"soft": Color(0.58, 0.18, 0.42, 0.98),
				"glow": Color(1.0, 0.46, 0.78, 0.24),
				"label": Color(1.0, 0.92, 0.97, 1.0)
			}
		"mental_health":
			return {
				"core": Color(0.4, 0.92, 0.62, 1.0),
				"soft": Color(0.14, 0.4, 0.24, 0.98),
				"glow": Color(0.4, 0.92, 0.62, 0.24),
				"label": Color(0.92, 1.0, 0.94, 1.0)
			}
		"fertility":
			return {
				"core": Color(0.78, 0.48, 1.0, 1.0),
				"soft": Color(0.38, 0.18, 0.58, 0.98),
				"glow": Color(0.78, 0.48, 1.0, 0.24),
				"label": Color(0.96, 0.92, 1.0, 1.0)
			}
		"approval":
			return {
				"core": Color(1.0, 0.86, 0.58, 1.0),
				"soft": Color(0.46, 0.34, 0.18, 0.98),
				"glow": Color(1.0, 0.92, 0.7, 0.3),
				"label": Color(1.0, 0.96, 0.84, 1.0)
			}
		_:
			return {
				"core": Color(0.86, 0.54, 1.0, 1.0),
				"soft": Color(0.32, 0.16, 0.5, 0.98),
				"glow": Color(0.62, 0.28, 0.9, 0.24),
				"label": Color(1.0, 0.96, 0.8, 1.0)
			}


static func _clear_god_mode_slider_emotion_profile(slider: HSlider) -> void:
	if slider == null:
		return
	slider.set_meta("god_mode_emotion_profile", {})
	slider.set_meta("god_mode_last_value", float(slider.value))


static func _select_option_by_text(button: OptionButton, text: String) -> void:
	if button == null:
		return

	for i in range(button.item_count):
		if button.get_item_text(i).to_lower() == text.to_lower():
			button.select(i)
			return

	if button.item_count > 0:
		button.select(0)


static func _set_option_button_blank(button: OptionButton) -> void:
	if button == null:
		return

	button.clear()
	button.add_item("")
	button.select(0)


static func _parse_birth_year_text(raw_text: String) -> Dictionary:
	var text:= raw_text.strip_edges()

	if text == "" or text == "-" or text == "+":
		return { "valid": false}

	if not text.is_valid_int():
		return { "valid": false}

	return {
		"valid": true,
		"year": int(text)
	}


static func _option_button_has_text(button: OptionButton, wanted: String) -> bool:
	if button == null:
		return false
	for i in range(button.item_count):
		if button.get_item_text(i) == wanted:
			return true
	return false


static func _government_style_supports_royalty(government_style: String) -> bool:
	var style_text:= str(government_style).strip_edges().to_lower()
	return style_text in ["monarchy", "empire"]


static func _populate_superpower_option_button(button: OptionButton, rows: Array, selected_value: String = "") -> void:
	if button == null:
		return

	button.clear()

	var selected_index:= 0
	var clean_selected:= str(selected_value).strip_edges().to_lower()

	for i in range(rows.size()):
		var row: Dictionary = rows [i]
		var label: String = str(row.get("label", row.get("id", "Option")))
		var value: String = str(row.get("id", label)).strip_edges().to_lower()
		button.add_item(label)
		button.set_item_metadata(i, value)
		if clean_selected != "" and value == clean_selected:
			selected_index = i

	if button.item_count > 0:
		button.select(selected_index)


static func _selected_superpower_option_value(button: OptionButton, fallback: String = "") -> String:
	if button == null or button.item_count <= 0:
		return fallback

	var idx:= button.get_selected_id()
	if idx < 0 or idx >= button.item_count:
		return fallback

	var metadata:= str(button.get_item_metadata(idx)).strip_edges().to_lower()
	if metadata != "":
		return metadata

	return str(button.get_item_text(idx)).strip_edges().to_lower()


static func _build_superpower_sandbox_celestial_panel_style() -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.025, 0.085, 0.985)
	style.border_color = Color(0.84, 0.56, 1.0, 0.88)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 30
	style.corner_radius_top_right = 30
	style.corner_radius_bottom_left = 30
	style.corner_radius_bottom_right = 30
	style.content_margin_left = 22
	style.content_margin_top = 20
	style.content_margin_right = 22
	style.content_margin_bottom = 20
	style.shadow_color = Color(0.58, 0.24, 1.0, 0.36)
	style.shadow_size = 36
	style.shadow_offset = Vector2(0, 10)
	return style


static func _normalize_social_class_picker_value(value: String) -> String:
	var text:= str(value).strip_edges()
	if text in ["Royal", "Royal Court", "Imperial Court", "Pharaonic Court"]:
		return "Royal"
	if text in ["Noble", "Noble House", "Imperial Nobility", "Pharaonic Nobility"]:
		return "Noble"
	return text


static func _startup_intro_title_impact_seconds() -> float:
	return 9.28


static func _startup_intro_title_bridge_end_padding_ms() -> int:
	return 70


static func _startup_intro_initial_loading_seconds() -> float:
	return 2.6


static func _startup_intro_loading_glitch_year_fragment(target_year: String, step: int) -> String:
	var clean_year: String = str(target_year).strip_edges()
	if clean_year == "":
		clean_year = "????"

	if step <= 0:
		return "///"
	if step == 1:
		return "%s / ??" % clean_year
	if step == 2:
		return clean_year.replace(" ", " / ")

	return clean_year


static func _startup_intro_loading_glitch_line_fragment(target_line: String, step: int) -> String:
	var clean_line: String = str(target_line).strip_edges()
	if clean_line == "":
		clean_line = "history signal found"

	if step <= 0:
		return "timeline signal searching..."
	if step == 1:
		return "history buffer unstable..."
	if step == 2:
		return "%s //" % clean_line

	return clean_line


static func _startup_intro_bridge_payload_glitch_window_ms() -> int:
	return 430


static func _startup_intro_glitched_bridge_payload(beat: Dictionary, bridge_index: int, remaining_ms: int) -> Dictionary:
	var out: Dictionary = beat.duplicate(true)
	var year_text: String = str(out.get("year", "")).strip_edges()
	var line_text: String = str(out.get("line", "")).strip_edges()

	var mode: int = bridge_index % 4
	if mode == 0:
		out ["year"] = "%s / SIGNAL" % year_text
		out ["line"] = "%s • reality tearing" % line_text
	elif mode == 1:
		out ["year"] = "/// %s ///" % year_text
		out ["line"] = "%s • time stutters" % line_text
	elif mode == 2:
		out ["year"] = "%s / %s" % [year_text, "????"]
		out ["line"] = "%s • history desync" % line_text
	else:
		out ["year"] = year_text.replace("/", " / // / ")
		out ["line"] = "%s • life signal incoming" % line_text

	out ["year_color"] = Color(1.0, 0.76, 0.96, 1.0)
	out ["line_color"] = Color(0.76, 1.0, 0.96, 1.0)
	out ["pitch"] = max(float(out.get("pitch", 2.18)), 2.44)

	if remaining_ms <= 180:
		out ["year"] = "%s / ERALIFE" % str(out.get("year", ""))
		out ["line"] = "%s • glass about to break" % str(out.get("line", ""))

	return out


static func _startup_intro_positive_hash(hash_material: String) -> int:
	var value: int = int(hash(str(hash_material)))
	if value < 0:
		value = - value
	if value <= 0:
		value = 1
	return value


static func _startup_intro_sequence_signature(sequence: Array) -> String:
	var parts: Array = []
	var limit_count: int = min(sequence.size(), 64)

	for i in range(limit_count):
		var raw_beat: Variant = sequence [i]
		if typeof(raw_beat) != TYPE_DICTIONARY:
			continue

		var beat: Dictionary = raw_beat as Dictionary
		var year_text: String = str(beat.get("year", "")).strip_edges()
		var line_text: String = str(beat.get("line", "")).strip_edges()
		if year_text == "" and line_text == "":
			continue

		parts.append("%s::%s" % [year_text, line_text])

	var signature: String = ""
	for raw_part in parts:
		var part: String = str(raw_part)
		if signature != "":
			signature += "|"
		signature += part

	return signature


static func _startup_intro_ad_suffix_cutoff_year() -> int:
	return 750


static func _startup_intro_procedural_content_contract() -> Dictionary:
	return {
		"schema": "eralife.procedural_cinematic_sequence_contract",
		"version": 1,
		"sequence_count": 14,
		"bridge_count": 34,
		"pool_rotation": [
			"royal_bloodlines",
			"artifact_discoveries",
			"wars_and_crowns",
			"ordinary_lives",
			"crime_and_celebrity",
			"realm_anomalies",
			"future_legends"
		],
		"pools": {
			"royal_bloodlines": [
				{ "year": -30, "era": "ancient", "line": "A prodigy was born as Crowned Prince."},
				{ "year": -12, "era": "ancient", "line": "A queen hid an heir beneath a palace chapel."},
				{ "year": 41, "era": "ancient", "line": "A royal infant survived a poisoned feast."},
				{ "year": 210, "era": "ancient", "line": "A prince inherited a throne nobody believed he could hold."},
				{ "year": 476, "era": "medieval", "line": "A fallen dynasty buried its last crown in silence."},
				{ "year": 611, "era": "medieval", "line": "A child of two kingdoms was promised to a war."},
				{ "year": 742, "era": "medieval", "line": "A royal bloodline awakened with a name no historian trusted."},
				{ "year": 1204, "era": "medieval", "line": "A royal house broke quietly behind golden doors."},
				{ "year": 1492, "era": "medieval", "line": "A voyage redrew inheritance, land, and destiny."},
				{ "year": 1847, "era": "industrial", "line": "A family built a name from hunger, debt, and stubborn breath."},
				{ "year": 1914, "era": "industrial", "line": "A noble son marched away and returned as a story."},
				{ "year": 2026, "era": "modern", "line": "A celebrity bloodline collapsed on live television."},
				{ "year": 2148, "era": "future", "line": "Two royal timelines folded into one heir."},
				{ "year": 3022, "era": "future", "line": "A crown was inherited by code."}
			],
			"artifact_discoveries": [
				{ "year": -300, "era": "ancient", "line": "A temple opened around a stone that hummed like time."},
				{ "year": -44, "era": "ancient", "line": "A blade carried a prophecy through a senate hall."},
				{ "year": 33, "era": "ancient", "line": "A relic vanished the moment history tried to name it."},
				{ "year": 210, "era": "ancient", "line": "A time-changing artifact was discovered."},
				{ "year": 620, "era": "medieval", "line": "A desert city heard a message that would outlive empires."},
				{ "year": 699, "era": "medieval", "line": "A monk copied a map to a realm that should not exist."},
				{ "year": 750, "era": "medieval", "line": "An artifact chose a farmer instead of a king."},
				{ "year": 1066, "era": "medieval", "line": "A crown changed hands while an old relic watched."},
				{ "year": 1666, "era": "industrial", "line": "A hidden realm woke under ash and watched the smoke rise."},
				{ "year": 1969, "era": "modern", "line": "A footprint touched the moon while Earth held its breath."},
				{ "year": 1999, "era": "modern", "line": "Time forgot which life came first."},
				{ "year": 2075, "era": "future", "line": "A man vanished from every record except a child's dream."},
				{ "year": 2410, "era": "future", "line": "A name became legend and refused to stay dead."},
				{ "year": 4001, "era": "future", "line": "A universe archived its last prayer."}
			],
			"wars_and_crowns": [
				{ "year": -333, "era": "ancient", "line": "A young conqueror stared at the world like it owed him land."},
				{ "year": -218, "era": "ancient", "line": "An army crossed the mountains and made fear practical."},
				{ "year": -60, "era": "ancient", "line": "Three powerful men agreed to share a future none of them trusted."},
				{ "year": 73, "era": "ancient", "line": "A revolt became a lesson written in blood."},
				{ "year": 410, "era": "medieval", "line": "A city thought eternal learned how endings sounded."},
				{ "year": 476, "era": "medieval", "line": "A capital fell, but the age refused to end cleanly."},
				{ "year": 622, "era": "medieval", "line": "A migration changed the calendar of millions."},
				{ "year": 732, "era": "medieval", "line": "A battlefield decided which prayers would echo west."},
				{ "year": 793, "era": "medieval", "line": "A coastline learned fear before the ships had names."},
				{ "year": 1099, "era": "medieval", "line": "A city prayed under siege while history took notes."},
				{ "year": 1453, "era": "medieval", "line": "Walls fell and an empire changed shape overnight."},
				{ "year": 1776, "era": "industrial", "line": "A rebellion became a country and taught flags to argue."},
				{ "year": 1914, "era": "industrial", "line": "The world went to war and boys became dates on stone."},
				{ "year": 1945, "era": "modern", "line": "Cities learned the shape of endings."}
			],
			"ordinary_lives": [
				{ "year": -120, "era": "ancient", "line": "A farmer named his child after rain that never came."},
				{ "year": -7, "era": "ancient", "line": "A child opened their eyes while kingdoms argued over tomorrow."},
				{ "year": 88, "era": "ancient", "line": "A mother sold bread while a future soldier learned to walk."},
				{ "year": 244, "era": "ancient", "line": "A healer saved one stranger and changed a family line."},
				{ "year": 512, "era": "medieval", "line": "A village survived winter because one child remembered a path."},
				{ "year": 640, "era": "medieval", "line": "A blacksmith taught his daughter how to hear metal breathe."},
				{ "year": 701, "era": "medieval", "line": "A fisherman disappeared and left behind a map no one could read."},
				{ "year": 750, "era": "medieval", "line": "A runaway apprentice found a city that did not ask his name."},
				{ "year": 1348, "era": "medieval", "line": "A plague emptied streets and made silence feel crowded."},
				{ "year": 1815, "era": "industrial", "line": "An emperor met his final weather."},
				{ "year": 1892, "era": "industrial", "line": "A legacy fractured and every heir blamed the mirror."},
				{ "year": 1998, "era": "modern", "line": "A child was born into nothing and still bent the odds."},
				{ "year": 2031, "era": "modern", "line": "A school rumor became a scandal before lunch ended."},
				{ "year": 2091, "era": "future", "line": "A machine asked for a childhood."}
			],
			"crime_and_celebrity": [
				{ "year": -55, "era": "ancient", "line": "A thief stole a crown jewel and accidentally started a dynasty."},
				{ "year": 69, "era": "ancient", "line": "Four rulers claimed one year and none of them slept well."},
				{ "year": 305, "era": "ancient", "line": "A palace guard sold a secret to the wrong prophet."},
				{ "year": 642, "era": "medieval", "line": "A masked outlaw became more trusted than the local lord."},
				{ "year": 718, "era": "medieval", "line": "A singer exposed a king with one forbidden verse."},
				{ "year": 1517, "era": "medieval", "line": "A page was nailed down and a world split open."},
				{ "year": 1888, "era": "industrial", "line": "A city learned that fear could become a headline."},
				{ "year": 1927, "era": "modern", "line": "A silent star smiled while a studio buried the truth."},
				{ "year": 1984, "era": "modern", "line": "A city watched itself blink through a thousand cameras."},
				{ "year": 2026, "era": "modern", "line": "A celebrity fought crime at night and signed autographs by noon."},
				{ "year": 2037, "era": "modern", "line": "A mayor sold the future for peace."},
				{ "year": 2043, "era": "future", "line": "A boxer unified the world and punched through fate."},
				{ "year": 2059, "era": "future", "line": "A singer disappeared during the encore."},
				{ "year": 2210, "era": "future", "line": "A colony elected a ghost."}
			],
			"realm_anomalies": [
				{ "year": -900, "era": "ancient", "line": "A cave painted tomorrow before anyone invented history."},
				{ "year": -222, "era": "ancient", "line": "A buried door opened into a sky with two moons."},
				{ "year": 1, "era": "ancient", "line": "A calendar blinked and pretended nothing happened."},
				{ "year": 177, "era": "ancient", "line": "A child spoke a language from a kingdom not yet born."},
				{ "year": 399, "era": "ancient", "line": "A philosopher dreamed of a trial he had already lost."},
				{ "year": 580, "era": "medieval", "line": "A monastery bell rang from underground."},
				{ "year": 666, "era": "medieval", "line": "A hidden realm looked back through a candle flame."},
				{ "year": 741, "era": "medieval", "line": "A doorway appeared for exactly one heartbeat."},
				{ "year": 1666, "era": "industrial", "line": "A hidden realm woke under ash and refused to go back to sleep."},
				{ "year": 1999, "era": "modern", "line": "A timeline split and both versions blamed the other."},
				{ "year": 2075, "era": "future", "line": "Records erased a man who still kept aging."},
				{ "year": 2148, "era": "future", "line": "Two destinies folded into one and both screamed quietly."},
				{ "year": 2655, "era": "future", "line": "A crown was inherited by code."},
				{ "year": 3022, "era": "future", "line": "A memory survived the death of worlds."}
			],
			"future_legends": [
				{ "year": 1969, "era": "modern", "line": "A footprint touched the moon while children watched from carpet floors."},
				{ "year": 1998, "era": "modern", "line": "A child was born into nothing and still inherited time."},
				{ "year": 2026, "era": "modern", "line": "A celebrity smiled through interviews while hiding a second life."},
				{ "year": 2031, "era": "modern", "line": "A school rumor became a scandal before lunch ended."},
				{ "year": 2043, "era": "future", "line": "A boxer became champion while three timelines bet against him."},
				{ "year": 2059, "era": "future", "line": "A singer vanished during the encore and became a myth."},
				{ "year": 2075, "era": "future", "line": "A man vanished from every record except one child's dream."},
				{ "year": 2091, "era": "future", "line": "A machine asked for a childhood."},
				{ "year": 2148, "era": "future", "line": "Two destinies folded into one and both remembered the pain."},
				{ "year": 2210, "era": "future", "line": "A colony elected a ghost."},
				{ "year": 2410, "era": "future", "line": "A name became legend and refused to stay dead."},
				{ "year": 2655, "era": "future", "line": "A crown was inherited by code."},
				{ "year": 3022, "era": "future", "line": "A memory survived the death of worlds."},
				{ "year": 4001, "era": "future", "line": "A universe archived its last prayer."}
			]
		}
	}


static func _startup_intro_merge_generated_recipe_pool_ids(pool_rotation: Array, generated_recipes: Dictionary) -> void:
	for raw_pool_id in generated_recipes.keys():
		var pool_id: String = str(raw_pool_id).strip_edges()
		if pool_id == "":
			continue
		if not pool_rotation.has(pool_id):
			pool_rotation.append(pool_id)


static func _startup_intro_count_recipe_pool_combinations(generated_recipes: Dictionary) -> int:
	var count: int = 0
	for raw_pool_id in generated_recipes.keys():
		var recipe_raw: Variant = generated_recipes.get(raw_pool_id, {})
		if typeof(recipe_raw) != TYPE_DICTIONARY:
			continue

		var recipe: Dictionary = recipe_raw
		var years: Array = recipe.get("years", []) if typeof(recipe.get("years", [])) == TYPE_ARRAY else []
		var subjects: Array = recipe.get("subjects", []) if typeof(recipe.get("subjects", [])) == TYPE_ARRAY else []
		var outcomes: Array = recipe.get("outcomes", []) if typeof(recipe.get("outcomes", [])) == TYPE_ARRAY else []

		count += max(0, years.size() * subjects.size() * outcomes.size())

	return count


static func _startup_intro_recipe_pool_moment_count(recipe: Dictionary) -> int:
	var years: Array = recipe.get("years", []) if typeof(recipe.get("years", [])) == TYPE_ARRAY else []
	var subjects: Array = recipe.get("subjects", []) if typeof(recipe.get("subjects", [])) == TYPE_ARRAY else []
	var outcomes: Array = recipe.get("outcomes", []) if typeof(recipe.get("outcomes", [])) == TYPE_ARRAY else []
	return max(0, years.size() * subjects.size() * outcomes.size())


static func _startup_intro_massive_generated_pool_recipes() -> Dictionary:
	return {
		"grounded_modern_headlines": {
			"era": "modern",
			"years": [1984, 1999, 2007, 2016, 2020, 2026, 2031, 2037],
			"subjects": [
				"A teacher",
				"A lawyer",
				"A mayor",
				"A surgeon",
				"A principal",
				"A detective",
				"A preacher",
				"A billionaire",
				"A streamer",
				"A judge"
			],
			"outcomes": [
				"was arrested for murder",
				"abandoned his family",
				"vanished before sentencing",
				"confessed on live television",
				"hid a second life",
				"became a scandal overnight",
				"lost everything after one phone call",
				"bought silence and called it peace"
			]
		},
		"ancient_empire_pressure": {
			"era": "ancient",
			"years": [-333, -218, -120, -60, -33, -12, 33, 41, 79, 177, 210, 305, 399],
			"subjects": [
				"Empires",
				"Two kings",
				"A general",
				"A prophet",
				"A prince",
				"A queen",
				"A temple",
				"A hidden army",
				"A royal child",
				"A forgotten city"
			],
			"outcomes": [
				"go to war",
				"broke an oath before sunrise",
				"followed a sign nobody else could see",
				"buried a weapon beneath the river",
				"turned a betrayal into law",
				"survived a prophecy meant to kill them",
				"opened a door beneath the palace",
				"vanished from every official record"
			]
		},
		"medieval_oaths_and_realms": {
			"era": "medieval",
			"years": [410, 476, 512, 580, 611, 620, 642, 666, 701, 718, 741, 750, 793, 1066, 1099, 1204, 1348, 1453, 1492],
			"subjects": [
				"A knight",
				"A monk",
				"A queen",
				"A blacksmith",
				"A hidden realm",
				"A village",
				"A thief",
				"A singer",
				"A prince",
				"A plague doctor"
			],
			"outcomes": [
				"broke a vow and saved a kingdom",
				"copied a map to a place that should not exist",
				"hid an heir beneath a chapel",
				"heard metal speak back",
				"looked through a candle flame",
				"survived winter by blaming the wrong stranger",
				"stole a crown and started a dynasty",
				"exposed a king with one forbidden verse",
				"inherited a war before learning mercy",
				"was accused of selling curses"
			]
		},
		"industrial_pressure_cooker": {
			"era": "industrial",
			"years": [1666, 1776, 1815, 1833, 1842, 1847, 1888, 1892, 1906, 1914, 1918],
			"subjects": [
				"A factory",
				"A union",
				"A boxer",
				"A nurse",
				"A railroad heir",
				"A coal town",
				"A machine",
				"A newspaper",
				"A soldier",
				"A furnace"
			],
			"outcomes": [
				"changed how families survived",
				"began in whispers under smoke",
				"won a fight nobody paid to see",
				"kept working while the city counted its dead",
				"lost everything to a signed contract",
				"buried its shame under ash",
				"made a man rich and a city sick",
				"turned fear into a headline",
				"returned home as a ghost of himself",
				"revealed a crown made of black glass"
			]
		},
		"future_mythic_systems": {
			"era": "future",
			"years": [2043, 2059, 2075, 2091, 2148, 2210, 2410, 2655, 2826, 3022, 4001],
			"subjects": [
				"A Bender",
				"A colony",
				"A ghost",
				"A machine",
				"A cloned heir",
				"A prison moon",
				"A synthetic judge",
				"A memory",
				"A cosmic relic",
				"The last Avatar"
			],
			"outcomes": [
				"rises from sheer will power",
				"elected a ghost and called it democracy",
				"kept aging after being erased",
				"asked for a childhood",
				"remembered two timelines at once",
				"opened one cell and lost a civilization",
				"delivered a verdict nobody programmed",
				"survived the death of worlds",
				"refused every owner except a child",
				"heard every past life speak at once"
			]
		}
	}


static func _startup_intro_count_pool_moments(pools: Dictionary) -> int:
	var count: int = 0
	for raw_pool_id in pools.keys():
		var pool_raw: Variant = pools.get(raw_pool_id, [])
		if typeof(pool_raw) == TYPE_ARRAY:
			count += (pool_raw as Array).size()
	return count


static func _startup_intro_moment_key(moment: Dictionary) -> String:
	return "%s|%s|%s" % [
		str(moment.get("year", "")),
		str(moment.get("era", "")),
		str(moment.get("line", ""))
	]


static func _startup_intro_massive_static_pool_expansion() -> Dictionary:
	return {
		"grounded_life_fractures": [
			{ "year": -44, "era": "ancient", "line": "A senator betrayed a friend and called it duty."},
			{ "year": -33, "era": "ancient", "line": "Empires go to war."},
			{ "year": 79, "era": "ancient", "line": "A city disappeared beneath fire and ash."},
			{ "year": 310, "era": "ancient", "line": "A healer saved a child who would bankrupt a kingdom."},
			{ "year": 612, "era": "medieval", "line": "A farmer buried coins under a floor nobody would find for centuries."},
			{ "year": 740, "era": "medieval", "line": "A village blamed a stranger for a winter that would not end."},
			{ "year": 1221, "era": "medieval", "line": "A merchant vanished after selling bread to the wrong army."},
			{ "year": 1665, "era": "industrial", "line": "A doctor refused to leave the sick behind."},
			{ "year": 1842, "era": "industrial", "line": "A factory girl lost three fingers and started a union in secret."},
			{ "year": 1918, "era": "industrial", "line": "A nurse kept working while the city counted its dead."},
			{ "year": 1999, "era": "modern", "line": "A lawyer abandons his family."},
			{ "year": 2007, "era": "modern", "line": "A father changed his name and started over in another city."},
			{ "year": 2026, "era": "modern", "line": "A teacher was arrested for murder."},
			{ "year": 2034, "era": "modern", "line": "A streamer confessed on camera and deleted the evidence too late."},
			{ "year": 2098, "era": "future", "line": "A child sued the algorithm that raised him."},
			{ "year": 2315, "era": "future", "line": "A family bought a memory they could not afford."}
		],
		"bending_and_willpower": [
			{ "year": -12, "era": "ancient", "line": "A firebender refused a throne and walked into exile."},
			{ "year": 79, "era": "ancient", "line": "The Avatar still walks amongst men."},
			{ "year": 210, "era": "ancient", "line": "A child bent water before learning their own name."},
			{ "year": 511, "era": "medieval", "line": "A monk taught breath control to a boy who feared his hands."},
			{ "year": 642, "era": "medieval", "line": "An earthbender held a bridge until sunrise."},
			{ "year": 750, "era": "medieval", "line": "The Avatar vanished into a storm and returned older."},
			{ "year": 1420, "era": "medieval", "line": "A master refused to teach the prince and chose the stable boy."},
			{ "year": 1833, "era": "industrial", "line": "A metalworker heard the earth inside the machine."},
			{ "year": 1906, "era": "industrial", "line": "A bending tournament ended when the arena floor split in half."},
			{ "year": 1998, "era": "modern", "line": "A quiet student bent fire after years of humiliation."},
			{ "year": 2029, "era": "modern", "line": "A street duel made a nobody famous by morning."},
			{ "year": 2043, "era": "future", "line": "An airbender learned to move without being seen."},
			{ "year": 2148, "era": "future", "line": "A bending bloodline reappeared inside a cloned dynasty."},
			{ "year": 2826, "era": "future", "line": "A Bender rises from sheer will power."},
			{ "year": 3022, "era": "future", "line": "A master bent gravity and denied it happened."},
			{ "year": 4001, "era": "future", "line": "The last Avatar heard every past life speak at once."}
		],
		"crime_justice_and_scandal": [
			{ "year": -60, "era": "ancient", "line": "A governor bought innocence with temple gold."},
			{ "year": 33, "era": "ancient", "line": "A prisoner became a symbol before the empire understood why."},
			{ "year": 305, "era": "ancient", "line": "A palace guard framed a beggar for a royal death."},
			{ "year": 699, "era": "medieval", "line": "A judge sentenced his own brother and lost the city."},
			{ "year": 1066, "era": "medieval", "line": "A thief crossed a battlefield carrying the wrong crown."},
			{ "year": 1348, "era": "medieval", "line": "A plague doctor was accused of selling curses."},
			{ "year": 1888, "era": "industrial", "line": "A city learned fear could become a headline."},
			{ "year": 1927, "era": "modern", "line": "A studio buried a death and sold the smile anyway."},
			{ "year": 1984, "era": "modern", "line": "A mayor won reelection while hiding three bodies."},
			{ "year": 1999, "era": "modern", "line": "A detective solved the case and disappeared before trial."},
			{ "year": 2026, "era": "modern", "line": "A teacher was arrested for murder."},
			{ "year": 2037, "era": "modern", "line": "A courtroom livestream turned a witness into a celebrity."},
			{ "year": 2075, "era": "future", "line": "A synthetic judge delivered a verdict nobody programmed."},
			{ "year": 2410, "era": "future", "line": "A prison moon opened one cell and lost a civilization."},
			{ "year": 2826, "era": "future", "line": "A criminal empire bought a timeline and still went bankrupt."},
			{ "year": 3022, "era": "future", "line": "A confession arrived from a person not yet born."}
		],
		"cosmic_artifacts_and_relics": [
			{ "year": -300, "era": "ancient", "line": "A temple stone hummed before the priests learned fear."},
			{ "year": -33, "era": "ancient", "line": "A relic chose war over silence."},
			{ "year": 79, "era": "ancient", "line": "A buried artifact survived the mountain's fire."},
			{ "year": 210, "era": "ancient", "line": "A time-changing artifact was discovered."},
			{ "year": 620, "era": "medieval", "line": "A desert relic whispered through a locked room."},
			{ "year": 750, "era": "medieval", "line": "A ring opened a realm beneath a sleeping city."},
			{ "year": 1204, "era": "medieval", "line": "A knight sold a holy blade to pay a debt."},
			{ "year": 1666, "era": "industrial", "line": "A hidden realm woke under ash and refused to sleep again."},
			{ "year": 1847, "era": "industrial", "line": "A factory furnace revealed a crown made of black glass."},
			{ "year": 1969, "era": "modern", "line": "The moon kept one footprint and one secret."},
			{ "year": 1999, "era": "modern", "line": "A child found a red bonnet inside a locked attic."},
			{ "year": 2026, "era": "modern", "line": "Seven signals lit up across the world."},
			{ "year": 2043, "era": "future", "line": "An artifact escaped containment by becoming a rumor."},
			{ "year": 2148, "era": "future", "line": "A stone rewound one minute and aged a king by fifty years."},
			{ "year": 2826, "era": "future", "line": "A cosmic relic refused every owner except a child."},
			{ "year": 4001, "era": "future", "line": "The final artifact remembered the first universe."}
		],
		"family_dynasty_and_betrayal": [
			{ "year": -120, "era": "ancient", "line": "A mother hid twins from a bloodline that wanted only one."},
			{ "year": -30, "era": "ancient", "line": "A prodigy was born as Crowned Prince."},
			{ "year": 41, "era": "ancient", "line": "A royal infant survived a poisoned feast."},
			{ "year": 476, "era": "medieval", "line": "A fallen dynasty buried its last crown in silence."},
			{ "year": 611, "era": "medieval", "line": "A child of two kingdoms was promised to a war."},
			{ "year": 742, "era": "medieval", "line": "A royal bloodline awakened with a name no historian trusted."},
			{ "year": 1492, "era": "medieval", "line": "A voyage redrew inheritance, land, and destiny."},
			{ "year": 1815, "era": "industrial", "line": "An emperor met his final weather."},
			{ "year": 1892, "era": "industrial", "line": "A legacy fractured and every heir blamed the mirror."},
			{ "year": 1914, "era": "industrial", "line": "A noble son marched away and returned as a story."},
			{ "year": 1999, "era": "modern", "line": "A lawyer abandons his family."},
			{ "year": 2026, "era": "modern", "line": "A celebrity bloodline collapsed on live television."},
			{ "year": 2031, "era": "modern", "line": "A daughter inherited debt and turned it into a dynasty."},
			{ "year": 2075, "era": "future", "line": "A family uploaded its inheritance and forgot the password."},
			{ "year": 2655, "era": "future", "line": "A crown was inherited by code."},
			{ "year": 3022, "era": "future", "line": "A bloodline ended physically and continued legally."}
		],
		"ordinary_to_legendary": [
			{ "year": -7, "era": "ancient", "line": "A child opened their eyes while kingdoms argued over tomorrow."},
			{ "year": 88, "era": "ancient", "line": "A mother sold bread while a future soldier learned to walk."},
			{ "year": 244, "era": "ancient", "line": "A healer saved one stranger and changed a family line."},
			{ "year": 512, "era": "medieval", "line": "A village survived winter because one child remembered a path."},
			{ "year": 640, "era": "medieval", "line": "A blacksmith taught his daughter how to hear metal breathe."},
			{ "year": 701, "era": "medieval", "line": "A fisherman disappeared and left behind a map no one could read."},
			{ "year": 750, "era": "medieval", "line": "A runaway apprentice found a city that did not ask his name."},
			{ "year": 1847, "era": "industrial", "line": "A family built a name from hunger, debt, and stubborn breath."},
			{ "year": 1914, "era": "industrial", "line": "A boy lied about his age and returned older than his father."},
			{ "year": 1969, "era": "modern", "line": "A child watched the moon landing and decided Earth was too small."},
			{ "year": 1998, "era": "modern", "line": "A child was born into nothing and still bent the odds."},
			{ "year": 2026, "era": "modern", "line": "A broke dreamer built a world nobody could explain."},
			{ "year": 2043, "era": "future", "line": "A boxer unified the world and punched through fate."},
			{ "year": 2091, "era": "future", "line": "A machine asked for a childhood."},
			{ "year": 2410, "era": "future", "line": "A name became legend and refused to stay dead."},
			{ "year": 4001, "era": "future", "line": "A universe archived its last prayer."}
		]
	}


static func _startup_intro_generated_pool_special_moments(pool_id: String, era_tag: String) -> Array:
	var clean_pool_id: String = str(pool_id).strip_edges().to_lower()
	var clean_era: String = str(era_tag).strip_edges().to_lower()

	match clean_pool_id:
		"grounded_modern_headlines":
			return [
				{ "year": 1999, "era": "modern", "line": "A lawyer abandoned his family.", "event_signature": "family_abandonment"},
				{ "year": 2026, "era": "modern", "line": "A teacher was arrested for murder.", "event_signature": "teacher_murder_arrest"},
				{ "year": 2031, "era": "modern", "line": "A prodigy was born into history.", "event_signature": "prodigy_born_history"},
				{ "year": 2037, "era": "modern", "line": "A courtroom became famous before the verdict.", "event_signature": "courtroom_fame_before_verdict"}
			]
		"ancient_empire_pressure":
			return [
				{ "year": -33, "era": "ancient", "line": "Empires go to war.", "event_signature": "empires_go_to_war"},
				{ "year": 79, "era": "ancient", "line": "The Avatar still walks amongst men.", "event_signature": "avatar_walks_amongst_men"},
				{ "year": 210, "era": "ancient", "line": "A prodigy was born into history.", "event_signature": "prodigy_born_history"},
				{ "year": 250, "era": "ancient", "line": "A firebender summoned the Dragon Balls.", "event_signature": "firebender_summoned_dragon_balls"}
			]
		"future_mythic_systems":
			return [
				{ "year": 2043, "era": "future", "line": "A firebender summoned the Dragon Balls.", "event_signature": "firebender_summoned_dragon_balls"},
				{ "year": 2148, "era": "future", "line": "A prodigy was born into history.", "event_signature": "prodigy_born_history"},
				{ "year": 2826, "era": "future", "line": "A Bender rose from sheer willpower.", "event_signature": "bender_sheer_willpower"},
				{ "year": 3022, "era": "future", "line": "A cosmic relic chose a child and bent the sky around them.", "event_signature": "cosmic_relic_chose_child"}
			]
		"industrial_pressure_cooker":
			return [
				{ "year": 1847, "era": "industrial", "line": "A factory swallowed a family and gave back a dynasty.", "event_signature": "factory_family_dynasty"},
				{ "year": 1888, "era": "industrial", "line": "A newspaper turned fear into a headline.", "event_signature": "newspaper_fear_headline"},
				{ "year": 1914, "era": "industrial", "line": "A soldier returned home as a rumor.", "event_signature": "soldier_returned_rumor"}
			]
		_:
			return [
				{ "year": 250, "era": clean_era, "line": "A prodigy was born into history.", "event_signature": "prodigy_born_history"}
			]


static func _startup_intro_generated_subject_allows_outcome(pool_id: String, subject_text: String, outcome_text: String) -> bool:
	var pool: String = str(pool_id).strip_edges().to_lower()
	var subject: String = str(subject_text).strip_edges().to_lower()
	var outcome: String = str(outcome_text).strip_edges().to_lower()

	if subject == "" or outcome == "":
		return false

	match pool:
		"future_mythic_systems":
			if subject in ["a bender", "the last avatar"]:
				return outcome in [
					"rises from sheer will power",
					"heard every past life speak at once",
					"remembered two timelines at once"
				]
			if subject in ["a colony"]:
				return outcome in [
					"elected a ghost and called it democracy",
					"opened one cell and lost a civilization"
				]
			if subject in ["a ghost"]:
				return outcome in [
					"kept aging after being erased",
					"survived the death of worlds"
				]
			if subject in ["a machine"]:
				return outcome in [
					"asked for a childhood",
					"delivered a verdict nobody programmed"
				]
			if subject in ["a synthetic judge"]:
				return outcome in [
					"delivered a verdict nobody programmed"
				]
			if subject in ["a memory"]:
				return outcome in [
					"survived the death of worlds",
					"remembered two timelines at once"
				]
			if subject in ["a cosmic relic"]:
				return outcome in [
					"refused every owner except a child",
					"remembered two timelines at once"
				]
			if subject in ["a prison moon"]:
				return outcome in [
					"opened one cell and lost a civilization"
				]
			if subject in ["a cloned heir"]:
				return outcome in [
					"remembered two timelines at once"
				]
			return false

		"industrial_pressure_cooker":
			if subject in ["a factory", "a coal town", "a machine", "a furnace"]:
				return outcome in [
					"changed how families survived",
					"buried its shame under ash",
					"made a man rich and a city sick",
					"revealed a crown made of black glass"
				]
			if subject in ["a union"]:
				return outcome in [
					"began in whispers under smoke",
					"changed how families survived"
				]
			if subject in ["a boxer"]:
				return outcome in [
					"won a fight nobody paid to see"
				]
			if subject in ["a nurse"]:
				return outcome in [
					"kept working while the city counted its dead"
				]
			if subject in ["a railroad heir"]:
				return outcome in [
					"lost everything to a signed contract"
				]
			if subject in ["a newspaper"]:
				return outcome in [
					"turned fear into a headline"
				]
			if subject in ["a soldier"]:
				return outcome in [
					"returned home as a ghost of himself"
				]
			return false

		"grounded_modern_headlines":
			if subject in ["a teacher", "a principal", "a preacher", "a mayor", "a judge", "a surgeon", "a detective"]:
				return outcome in [
					"was arrested for murder",
					"vanished before sentencing",
					"confessed on live television",
					"hid a second life",
					"became a scandal overnight",
					"lost everything after one phone call",
					"bought silence and called it peace"
				]
			if subject in ["a lawyer"]:
				return outcome in [
					"abandoned his family",
					"vanished before sentencing",
					"hid a second life",
					"lost everything after one phone call"
				]
			if subject in ["a billionaire", "a streamer"]:
				return outcome in [
					"confessed on live television",
					"hid a second life",
					"became a scandal overnight",
					"lost everything after one phone call",
					"bought silence and called it peace"
				]
			return false

		"ancient_empire_pressure":
			if subject in ["empires", "two kings", "a general", "a hidden army"]:
				return outcome in [
					"go to war",
					"broke an oath before sunrise",
					"buried a weapon beneath the river",
					"turned a betrayal into law",
					"vanished from every official record"
				]
			if subject in ["a prophet", "a temple", "a forgotten city"]:
				return outcome in [
					"followed a sign nobody else could see",
					"opened a door beneath the palace",
					"vanished from every official record"
				]
			if subject in ["a prince", "a queen", "a royal child"]:
				return outcome in [
					"broke an oath before sunrise",
					"turned a betrayal into law",
					"survived a prophecy meant to kill them"
				]
			return false

		"medieval_oaths_and_realms":
			if subject in ["a knight", "a prince"]:
				return outcome in [
					"broke a vow and saved a kingdom",
					"inherited a war before learning mercy"
				]
			if subject in ["a monk"]:
				return outcome in [
					"copied a map to a place that should not exist"
				]
			if subject in ["a queen"]:
				return outcome in [
					"hid an heir beneath a chapel"
				]
			if subject in ["a blacksmith"]:
				return outcome in [
					"heard metal speak back"
				]
			if subject in ["a hidden realm"]:
				return outcome in [
					"looked through a candle flame"
				]
			if subject in ["a village"]:
				return outcome in [
					"survived winter by blaming the wrong stranger"
				]
			if subject in ["a thief"]:
				return outcome in [
					"stole a crown and started a dynasty"
				]
			if subject in ["a singer"]:
				return outcome in [
					"exposed a king with one forbidden verse"
				]
			if subject in ["a plague doctor"]:
				return outcome in [
					"was accused of selling curses"
				]
			return false

	return true


static func _startup_intro_event_signature_from_line(line_text: String) -> String:
	var clean: String = str(line_text).strip_edges().to_lower()
	clean = clean.replace(".", "")
	clean = clean.replace(",", "")
	clean = clean.replace(";", "")
	clean = clean.replace(":", "")
	clean = clean.replace("  ", " ")

	if clean.begins_with("a "):
		var first_space: int = clean.find(" ")
		var second_space: int = clean.find(" ", first_space + 1)
		if second_space > 0:
			clean = clean.substr(second_space + 1).strip_edges()

	if clean.begins_with("the "):
		var first_space_the: int = clean.find(" ")
		var second_space_the: int = clean.find(" ", first_space_the + 1)
		if second_space_the > 0:
			clean = clean.substr(second_space_the + 1).strip_edges()

	return clean


static func _startup_intro_compact_identity_text(raw_text: String) -> String:
	var clean: String = str(raw_text).strip_edges().to_lower()
	clean = clean.replace(".", "")
	clean = clean.replace(",", "")
	clean = clean.replace(";", "")
	clean = clean.replace(":", "")
	clean = clean.replace("!", "")
	clean = clean.replace("?", "")
	clean = clean.replace("/", " ")
	clean = clean.replace("\\", " ")
	clean = clean.replace("'", "")
	clean = clean.replace("\"", "")
	clean = clean.replace("  ", " ")

	while clean.find("  ") >= 0:
		clean = clean.replace("  ", " ")

	return clean.strip_edges()


static func _startup_intro_moment_year_identity_key(moment: Dictionary) -> String:
	if typeof(moment) != TYPE_DICTIONARY:
		return ""

	if moment.has("raw_year"):
		return str(moment.get("raw_year", "")).strip_edges()

	return str(moment.get("year", "")).strip_edges()


static func _startup_intro_perceptual_integrity_context(phase: String, slot_index: int = -1, attempt: int = 0, pool_id: String = "") -> Dictionary:
	return {
		"stream_id": "startup_intro",
		"phase": str(phase).strip_edges(),
		"slot_index": int(slot_index),
		"attempt": int(attempt),
		"pool_label": str(pool_id).strip_edges(),
		"source": "mainscene_startup_intro",
		"profile": "cinematic_hot_path",
	}


static func _startup_intro_sequence_timing_slots() -> Array:
	return [
		{ "fade_in": 0.2, "hold": 0.22, "fade_out": 0.08, "pitch": 0.98},
		{ "fade_in": 0.16, "hold": 0.18, "fade_out": 0.07, "pitch": 1.04},
		{ "fade_in": 0.13, "hold": 0.15, "fade_out": 0.06, "pitch": 1.1},
		{ "fade_in": 0.11, "hold": 0.12, "fade_out": 0.05, "pitch": 1.16},
		{ "fade_in": 0.09, "hold": 0.1, "fade_out": 0.04, "pitch": 1.22},
		{ "fade_in": 0.08, "hold": 0.08, "fade_out": 0.035, "pitch": 1.28},
		{ "fade_in": 0.07, "hold": 0.07, "fade_out": 0.03, "pitch": 1.34},
		{ "fade_in": 0.06, "hold": 0.06, "fade_out": 0.03, "pitch": 1.4},
		{ "fade_in": 0.05, "hold": 0.05, "fade_out": 0.025, "pitch": 1.46},
		{ "fade_in": 0.045, "hold": 0.045, "fade_out": 0.022, "pitch": 1.52},
		{ "fade_in": 0.04, "hold": 0.04, "fade_out": 0.02, "pitch": 1.58},
		{ "fade_in": 0.036, "hold": 0.036, "fade_out": 0.018, "pitch": 1.64},
		{ "fade_in": 0.032, "hold": 0.032, "fade_out": 0.016, "pitch": 1.7},
		{ "fade_in": 0.028, "hold": 0.028, "fade_out": 0.014, "pitch": 1.76}
	]


static func _startup_intro_procedural_color_for_era_tag(era_tag: String) -> Dictionary:
	match str(era_tag).strip_edges().to_lower():
		"ancient":
			return {
				"year_color": Color(0.96, 0.82, 0.42, 1.0),
				"line_color": Color(1.0, 0.91, 0.63, 1.0)
			}
		"medieval":
			return {
				"year_color": Color(0.82, 0.66, 1.0, 1.0),
				"line_color": Color(0.94, 0.86, 1.0, 1.0)
			}
		"industrial":
			return {
				"year_color": Color(0.95, 0.56, 0.3, 1.0),
				"line_color": Color(1.0, 0.72, 0.46, 1.0)
			}
		"modern":
			return {
				"year_color": Color(0.48, 0.9, 1.0, 1.0),
				"line_color": Color(0.76, 0.97, 1.0, 1.0)
			}
		"future":
			return {
				"year_color": Color(1.0, 0.3, 0.78, 1.0),
				"line_color": Color(1.0, 0.58, 0.9, 1.0)
			}
		_:
			return {
				"year_color": Color(1.0, 0.94, 0.62, 1.0),
				"line_color": Color(0.82, 0.98, 1.0, 1.0)
			}


static func _startup_intro_bridge_pitch_for_index(index: int) -> float:
	return min(2.72, 1.46 + (0.036 * float(index)))


static func _startup_intro_jumble_fragment_from_line(line_text: String) -> String:
	var clean: String = str(line_text).strip_edges()
	clean = clean.replace(".", "")
	clean = clean.replace(",", "")
	clean = clean.replace(";", "")
	clean = clean.replace(":", "")
	clean = clean.replace("  ", " ")

	if clean.length() > 42:
		clean = clean.substr(0, 42).strip_edges() + "..."

	return clean.to_lower()


static func _startup_intro_default_jumble_years() -> Array:
	return [
		"300 BCE",
		"44 BCE",
		"1",
		"210",
		"476",
		"620",
		"750",
		"1204",
		"1666",
		"1914",
		"1969",
		"1998",
		"2043",
		"2148",
		"3022",
		"????"
	]


static func _startup_intro_default_jumble_fragments() -> Array:
	return [
		"prodigy born",
		"artifact discovered",
		"empire fractured",
		"realm woke",
		"crown changed",
		"time forgot",
		"city prayed",
		"child inherited time",
		"boxer became champion",
		"records erased",
		"destinies folded",
		"life pushed back"
	]


static func _startup_intro_bridge_duration_for_remaining(remaining_seconds: float) -> float:
	if remaining_seconds > 3.0:
		return 0.14
	if remaining_seconds > 2.15:
		return 0.115
	if remaining_seconds > 1.25:
		return 0.09
	if remaining_seconds > 0.68:
		return 0.066
	return 0.046


static func _startup_intro_drumming_ramp_begin_seconds() -> float:
	return 4.26


static func _startup_intro_tonal_pitch_hyper_begin_seconds() -> float:
	return 6.2


static func _startup_intro_bridge_ramp_duration_for_progress(ramp_progress: float) -> float:
	var p: float = clamp(float(ramp_progress), 0.0, 1.0)
	p = p * p * (3.0 - (2.0 * p))

	var slowest_duration: float = 0.138
	var fastest_duration: float = 0.052

	return lerp(slowest_duration, fastest_duration, p)


static func _startup_intro_bridge_hyper_duration_for_remaining(remaining_seconds: float) -> float:
	if remaining_seconds > 2.45:
		return 0.046
	if remaining_seconds > 1.7:
		return 0.034
	if remaining_seconds > 0.92:
		return 0.024
	if remaining_seconds > 0.48:
		return 0.017
	return 0.012


static func _startup_intro_jumble_slot_count_for_remaining(remaining_ms: int) -> int:
	if remaining_ms < 0:
		return 4

	if remaining_ms > 330:
		return 1

	if remaining_ms > 230:
		return 2

	if remaining_ms > 130:
		return 3

	return 4


static func _first_handled_command_report(report: Dictionary) -> Dictionary:
	var handled_raw: Variant = report.get("handled", [])
	if typeof(handled_raw) == TYPE_ARRAY:
		for raw_handled in handled_raw:
			if typeof(raw_handled) == TYPE_DICTIONARY:
				var handled_report: Dictionary = (raw_handled as Dictionary).duplicate(true)
				if handled_report.has("mode") or handled_report.has("message") or handled_report.has("reason"):
					return handled_report

	var failed_raw: Variant = report.get("failed", [])
	if typeof(failed_raw) == TYPE_ARRAY:
		for raw_failed in failed_raw:
			if typeof(raw_failed) == TYPE_DICTIONARY:
				var failed_report: Dictionary = (raw_failed as Dictionary).duplicate(true)
				if failed_report.has("mode") or failed_report.has("message") or failed_report.has("reason"):
					return failed_report

	return report.duplicate(true)


static func _eraccount_banner_style(connected: bool = true) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.025, 0.028, 0.96)
	style.border_color = Color(0.88, 0.88, 0.88, 0.84) if connected else Color(1.0, 0.72, 0.72, 0.84)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	style.shadow_size = 18
	return style


static func _find_choose_ereality_entry_button_in_tree(root: Node) -> Button:
	if root == null:
		return null

	if root is Button:
		var button:= root as Button
		var role: String = str(button.get_meta("entry_role", "")).strip_edges().to_lower()
		if role in ["god_mode_alive", "choose_ereality", "ereality", "god_mode"]:
			return button

	for child in root.get_children():
		var found: Button = _find_choose_ereality_entry_button_in_tree(child)
		if found != null and is_instance_valid(found):
			return found

	return null


static func _build_choose_adventure_entry_button_style(accent: Color, hovered: bool, role: String = "") -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	var narrative: bool = role == "narrative_alive" or role == "choose_adventure"
	var god_mode: bool = role == "god_mode_alive" or role == "choose_ereality"
	var base_mix: float = 0.22 if narrative else 0.14
	if god_mode:
		base_mix = 0.18
	style.bg_color = Color(
		0.055 + (accent.r * base_mix),
		0.045 + (accent.g * base_mix),
		0.08 + (accent.b * base_mix),
		0.98
	)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.86 if not hovered else 1.0)
	style.border_width_left = 2 if not hovered else 4
	style.border_width_right = 2 if not hovered else 4
	style.border_width_top = 2 if not hovered else 4
	style.border_width_bottom = 2 if not hovered else 4
	style.corner_radius_top_left = 22
	style.corner_radius_top_right = 22
	style.corner_radius_bottom_left = 22
	style.corner_radius_bottom_right = 22
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	var shadow_alpha: float = 0.22
	if narrative:
		shadow_alpha = 0.34
	elif god_mode:
		shadow_alpha = 0.28
	if hovered:
		shadow_alpha += 0.18
	style.shadow_color = Color(accent.r, accent.g, accent.b, shadow_alpha)
	style.shadow_size = 16 if not hovered else 28
	style.shadow_offset = Vector2(0, 6)
	return style


static func _build_choose_adventure_entry_card_style(accent: Color, hovered: bool, phase: float) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.045, 0.09, 0.94)
	style.border_color = accent.lightened(0.1 + (0.12 * phase))
	style.border_width_left = 2 if not hovered else 4
	style.border_width_right = 2 if not hovered else 4
	style.border_width_top = 2 if not hovered else 4
	style.border_width_bottom = 2 if not hovered else 4
	style.corner_radius_top_left = 28
	style.corner_radius_top_right = 28
	style.corner_radius_bottom_left = 28
	style.corner_radius_bottom_right = 28
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.24 if not hovered else 0.42)
	style.shadow_size = 18 if not hovered else 30
	style.shadow_offset = Vector2(0, 10)
	return style


static func _god_mode_reality_candidate_entry_kind(settings: Dictionary) -> String:
	var entry_kind: String = str(settings.get("_god_mode_entry_kind", settings.get("god_mode_entry_kind", "custom"))).strip_edges().to_lower()
	if entry_kind == "":
		entry_kind = "custom"
	return entry_kind


static func _god_mode_seed_contract_from_candidate(
	candidate: Dictionary
) -> Dictionary:
	var world_seed: int = int(
		candidate.get(
			"world_seed",
			-1
		)
	)

	return {
		"schema": "eralife.seed_contract",
		"version": 2,
		"seed": world_seed,
		"source": "god_mode_prebirth_reality_candidate",
		"candidate_id": str(
			candidate.get(
				"candidate_id",
				""
			)
		),
		"transaction_id": str(
			candidate.get(
				"transaction_id",
				""
			)
		),
		"transaction_sequence": int(
			candidate.get(
				"transaction_sequence",
				0
			)
		),
		"fresh_seed_commit": bool(
			candidate.get(
				"fresh_seed_commit",
				false
			)
		),
		"single_target_reality": true
	}


static func _god_mode_zero_frame_panel_style() -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.018, 0.06, 0.985)
	style.border_color = Color(0.3, 0.92, 1.0, 0.72)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 24
	style.corner_radius_top_right = 24
	style.corner_radius_bottom_left = 24
	style.corner_radius_bottom_right = 24
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 8)
	return style


static func _household_creator_resolve_world_seed_from_settings(settings: Dictionary) -> int:
	var world_seed: int = int(settings.get("world_seed", -1))
	if world_seed > 0:
		return world_seed

	var seed_contract_raw: Variant = settings.get("seed_contract", {})
	if typeof(seed_contract_raw) == TYPE_DICTIONARY:
		world_seed = int((seed_contract_raw as Dictionary).get("seed", -1))
		if world_seed > 0:
			return world_seed

	var candidate_raw: Variant = settings.get("_prebirth_reality_candidate", {})
	if typeof(candidate_raw) == TYPE_DICTIONARY:
		world_seed = int((candidate_raw as Dictionary).get("world_seed", -1))
		if world_seed > 0:
			return world_seed

	return -1


static func _household_creator_unfinished_draft_button_text(draft: Dictionary) -> String:
	var overview_raw: Variant = draft.get("overview", {})
	var overview: Dictionary = overview_raw if typeof(overview_raw) == TYPE_DICTIONARY else {}

	var household_name: String = str(overview.get("household_name", "Unfinished Household")).strip_edges()
	if household_name == "":
		household_name = "Unfinished Household"

	var era_text: String = str(overview.get("era", "Modern")).strip_edges()
	var year_text: String = str(overview.get("year", "2000")).strip_edges()
	var country_text: String = str(overview.get("country", "")).strip_edges()
	var city_text: String = str(overview.get("city", "")).strip_edges()
	var member_count: int = int(overview.get("member_count", 0))
	var world_seed: int = int(overview.get("world_seed", -1))

	var location_text: String = city_text
	if country_text != "":
		location_text = "%s, %s" % [city_text, country_text] if city_text != "" else country_text

	if location_text == "":
		location_text = "No location"

	return "%s\n%s %s • %s • %d member%s • seed %d" % [
		household_name,
		era_text,
		year_text,
		location_text,
		member_count,
		"" if member_count == 1 else "s",
		world_seed
	]


static func _household_creator_unfinished_drafts_storage_path() -> String:
	return "user://eralife_unfinished_household_creation_contracts.json"


static func _household_creator_normalize_unfinished_drafts(raw_drafts: Array) -> Array:
	var drafts_by_id: Dictionary = {}
	var order: Array = []

	for raw_draft in raw_drafts:
		if typeof(raw_draft) != TYPE_DICTIONARY:
			continue

		var draft: Dictionary = (raw_draft as Dictionary).duplicate(true)
		var draft_id: String = str(draft.get("draft_id", "")).strip_edges()
		if draft_id == "":
			continue

		draft ["draft_id"] = draft_id

		if not draft.has("schema"):
			draft ["schema"] = "eralife.unfinished_household_creation_contract"

		if not draft.has("version"):
			draft ["version"] = 1

		if not order.has(draft_id):
			order.append(draft_id)

		drafts_by_id [draft_id] = draft

	var out: Array = []
	for raw_id in order:
		var clean_id: String = str(raw_id).strip_edges()
		if clean_id == "" or not drafts_by_id.has(clean_id):
			continue
		out.append((drafts_by_id [clean_id] as Dictionary).duplicate(true))

	return out


static func _household_creator_section_card(title_text: String) -> PanelContainer:
	var card:= PanelContainer.new()
	card.name = "HouseholdCreatorSection_%s" % title_text.replace(" ", "_")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.035, 0.02, 0.84)
	style.border_color = Color(1.0, 0.18, 0.04, 0.38)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	card.add_theme_stylebox_override("panel", style)

	var margin:= MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	card.add_child(margin)

	var body:= VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	margin.add_child(body)

	var title:= Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.72, 1.0))
	body.add_child(title)

	card.set_meta("body", body)
	return card


static func _household_creator_style_choice_button(button: Button, selected: bool, accent: Color) -> void:
	if button == null or not is_instance_valid(button):
		return

	var normal:= StyleBoxFlat.new()
	normal.bg_color = Color(0.22, 0.045, 0.028, 0.86) if selected else Color(0.14, 0.026, 0.018, 0.82)
	normal.border_color = Color(accent.r, accent.g, accent.b, 0.84 if selected else 0.34)
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.corner_radius_top_left = 16
	normal.corner_radius_top_right = 16
	normal.corner_radius_bottom_left = 16
	normal.corner_radius_bottom_right = 16
	normal.shadow_color = Color(accent.r, accent.g, accent.b, 0.34 if selected else 0.1)
	normal.shadow_size = 24 if selected else 10

	var hover:= normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.28, 0.06, 0.035, 0.94)
	hover.border_color = Color(accent.r, accent.g, accent.b, 0.95)
	hover.shadow_color = Color(accent.r, accent.g, accent.b, 0.46)
	hover.shadow_size = 32

	var pressed:= normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.32, 0.07, 0.04, 0.98)
	pressed.shadow_size = 12
	pressed.content_margin_top = 3

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", Color(1.0, 0.92, 0.82, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.9, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.86, 0.72, 1.0))
	button.queue_redraw()


static func _household_creator_add_labeled_control(parent: Control, label_text: String, control: Control) -> void:
	var label:= Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.62, 0.84))
	parent.add_child(label)
	parent.add_child(control)

	if control != null and is_instance_valid(control):
		control.set_meta("household_creator_label", label)


static func _household_creator_array_has_text(values: Array, needle: String) -> bool:
	var clean_needle: String = str(needle).strip_edges().to_lower()
	if clean_needle == "":
		return false

	for raw_value in values:
		if str(raw_value).strip_edges().to_lower() == clean_needle:
			return true

	return false


static func _household_creator_dedupe_sorted_strings(values: Array) -> Array:
	var out: Array = []
	var seen:= {}

	for raw_value in values:
		var value: String = str(raw_value).strip_edges()
		if value == "":
			continue

		var key: String = value.to_lower()
		if seen.has(key):
			continue

		seen [key] = true
		out.append(value)

	out.sort()
	return out


static func _household_creator_selection_chip(title_text: String) -> PanelContainer:
	var chip:= PanelContainer.new()
	chip.name = "HouseholdCreatorSelectionChip_%s" % title_text.replace(" ", "_")
	chip.custom_minimum_size = Vector2(180, 64)
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.018, 0.012, 0.92)
	style.border_color = Color(1.0, 0.24, 0.08, 0.54)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.shadow_color = Color(1.0, 0.18, 0.05, 0.18)
	style.shadow_size = 10
	chip.add_theme_stylebox_override("panel", style)

	var margin:= MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	chip.add_child(margin)

	var box:= VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	margin.add_child(box)

	var title:= Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color(1.0, 0.6, 0.48, 0.88))
	box.add_child(title)

	var value:= Label.new()
	value.text = "—"
	value.clip_text = true
	value.add_theme_font_size_override("font_size", 17)
	value.add_theme_color_override("font_color", Color(1.0, 0.88, 0.74, 1.0))
	box.add_child(value)

	chip.set_meta("value_label", value)
	return chip


static func _household_creator_life_stage_options() -> Array:
	return ["Baby", "Child", "Teen", "Adult", "Elder"]


static func _household_creator_set_labeled_control_visible(control: Control, visible_value: bool) -> void:
	if control == null or not is_instance_valid(control):
		return

	control.visible = visible_value

	var raw_label: Variant = control.get_meta("household_creator_label", null)
	if raw_label != null and raw_label is Control and is_instance_valid(raw_label):
		(raw_label as Control).visible = visible_value


static func _household_creator_member_key_from_anchor_label(label_text: String) -> String:
	var text: String = str(label_text)
	var start: int = text.rfind("[")
	var end: int = text.rfind("]")
	if start >= 0 and end > start:
		return text.substr(start + 1, end - start - 1).strip_edges()
	return ""


static func _household_creator_pretty_stat(stat_key: String) -> String:
	match stat_key:
		"mental_health":
			return "Mental"
		_:
			return stat_key.capitalize()


static func _household_creator_starting_money_for_class(class_text: String) -> int:
	var normalized: String = str(class_text).strip_edges().to_lower()
	match normalized:
		"royal":
			return 250000
		"noble":
			return 120000
		"wealthy":
			return 75000
		"middle class":
			return 10000
		"working class":
			return 3000
		"poor":
			return 250
		_:
			return 5000


static func _household_prewarm_signature_material(contract: Dictionary) -> String:
	var safe_contract: Dictionary = contract.duplicate(true)



	safe_contract.erase("start_person_key")

	var members_raw: Variant = safe_contract.get("members", [])
	if typeof(members_raw) == TYPE_ARRAY:
		var members: Array = []
		for raw_member in members_raw:
			if typeof(raw_member) != TYPE_DICTIONARY:
				continue
			var member: Dictionary = (raw_member as Dictionary).duplicate(true)
			member.erase("is_start_actor")
			members.append(member)
		safe_contract ["members"] = members

	return JSON.stringify(safe_contract)


static func _retire_god_mode_visual_authority_node(node: CanvasItem, reason: String) -> void:
	if node == null or not is_instance_valid(node):
		return

	node.visible = false
	node.z_as_relative = false
	node.z_index = -4096
	node.modulate = Color(node.modulate.r, node.modulate.g, node.modulate.b, 0.0)
	node.set_meta("god_mode_visual_authority_retired", true)
	node.set_meta("god_mode_visual_authority_retired_reason", reason)
	node.set_meta("god_mode_visual_authority_retired_at_ms", int(Time.get_ticks_msec()))

	var control:= node as Control
	if control != null:
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		control.scale = Vector2.ONE


static func _retire_god_mode_visual_node_for_playable_life(node: CanvasItem, reason: String) -> void:
	if node == null or not is_instance_valid(node):
		return

	node.visible = false
	node.z_as_relative = false
	node.z_index = -4096
	node.modulate = Color(node.modulate.r, node.modulate.g, node.modulate.b, 0.0)
	node.set_meta("god_mode_visual_authority_retired", true)
	node.set_meta("god_mode_visual_authority_retired_reason", reason)
	node.set_meta("god_mode_visual_authority_retired_at_ms", int(Time.get_ticks_msec()))

	var control:= node as Control
	if control != null:
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		control.scale = Vector2.ONE


static func _god_mode_life_prewarm_thread_worker(
	_candidate_settings: Dictionary,
	_reason: String,
	signature: String,
	_contract: Dictionary,
	_candidate: Dictionary,
	_seed_contract: Dictionary,
	_world_seed: int,
	_surface_rows: Array
) -> Dictionary:


	return {
		"success": false,
		"mode": (
			"threaded_game_state_construction_retired"
		),
		"reason": (
			"GameState construction now belongs to "
			+ "persistent main-thread residency microstages."
		),
		"signature": signature,
		"worker_thread_used": false,
		"ui_is_renderer_only": true
	}


static func _household_member_contract_for_key(contract: Dictionary, local_key: String) -> Dictionary:
	var members_raw: Variant = contract.get("members", [])
	var members: Array = members_raw if typeof(members_raw) == TYPE_ARRAY else []
	for raw_member in members:
		if typeof(raw_member) != TYPE_DICTIONARY:
			continue
		var member: Dictionary = raw_member as Dictionary
		if str(member.get("local_key", "")).strip_edges() == local_key:
			return member.duplicate(true)
	return {}


static func _god_mode_prewarm_should_tail_defer_heavy_surface_caches(prewarm_gs: GameState, settings: Dictionary = {}) -> bool:
	if prewarm_gs == null:
		return true

	if typeof(prewarm_gs.scenario_state) == TYPE_DICTIONARY:
		if bool(prewarm_gs.scenario_state.get("royalty_heavy_bootstrap_forbidden_during_prewarm", false)):
			return true
		if bool(prewarm_gs.scenario_state.get("royal_first_frame_shell_truth_only", false)):
			return true
		if bool(prewarm_gs.scenario_state.get("birth_shell_fast_first_paint", false)):
			return true

	var role_key: String = str(settings.get("royal_role", settings.get("social_role", ""))).strip_edges().to_lower()
	if role_key.find("prince") >= 0:
		return true
	if role_key.find("princess") >= 0:
		return true
	if role_key.find("king") >= 0:
		return true
	if role_key.find("queen") >= 0:
		return true
	if role_key.find("emperor") >= 0:
		return true
	if role_key.find("empress") >= 0:
		return true

	return false


static func _birth_entry_surge_headline(birth_boot_context: Dictionary = {}) -> String:
	var era_name: String = str(birth_boot_context.get("era_name", "")).strip_edges()
	if era_name == "":
		era_name = "EraLife"
	return "%s Reality Surge" % era_name


static func _god_mode_birth_normalized_social_class(settings: Dictionary) -> String:
	var raw_class: String = str(settings.get("social_class", settings.get("social_class_label", ""))).strip_edges()

	if raw_class in ["Royal", "Royal Court", "Imperial Court", "Pharaonic Court"]:
		return "Royal"

	if raw_class in ["Noble", "Noble House", "Imperial Nobility", "Pharaonic Nobility"]:
		return "Noble"

	if raw_class == "Upperclass":
		return "Upper Class"

	return raw_class


static func _god_mode_birth_royal_rank_seed(settings: Dictionary) -> String:
	var rank_seed: String = str(settings.get("royal_rank", "")).strip_edges()
	if rank_seed == "Lesser Royal":
		return "Ducal Line"
	return rank_seed


static func _god_mode_birth_safe_actor_number(actor: Person, property_name: String, fallback: float = 0.0) -> float:
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


static func _silk_road_contract_route_result(
	report: Dictionary
) -> Dictionary:
	if report.is_empty():
		return {}

	var cursor: Dictionary = report

	for _index in range(12):
		if str(
			cursor.get(
				"mode",
				""
			)
		).strip_edges() == "silk_road_intent_resolved":
			return cursor.duplicate(false)

		var advanced: bool = false

		for key in [
			"route_report",
			"engine_report",
			"target_report",
			"commit_report",
			"command_report",
			"payload"
		]:
			var nested_raw: Variant = cursor.get(
				key,
				{}
			)

			if typeof(
				nested_raw
			) != TYPE_DICTIONARY:
				continue

			var nested: Dictionary = (
				nested_raw as Dictionary
			)

			if nested.is_empty():
				continue

			cursor = nested
			advanced = true
			break

		if not advanced:
			break

	return cursor.duplicate(false)


static func _silk_road_listing_color(
	rarity: String
) -> Color:
	match rarity.strip_edges().to_lower():
		"staple":
			return Color(
				0.82,
				0.68,
				0.42,
				1.0
			)

		"fine":
			return Color(
				0.44,
				0.76,
				1.0,
				1.0
			)

		"luxury":
			return Color(
				1.0,
				0.76,
				0.24,
				1.0
			)

		"rare":
			return Color(
				0.76,
				0.46,
				1.0,
				1.0
			)

	return Color(
		0.92,
		0.86,
		0.68,
		1.0
	)


static func _reality_residency_route_result(
		report: Dictionary
) -> Dictionary:
	var route_raw: Variant = report.get(
		"route_report",
		{}
	)

	if typeof(
		route_raw
	) == TYPE_DICTIONARY:
		var route_result: Dictionary = (
			route_raw as Dictionary
		)

		if not route_result.is_empty():
			return route_result

	var result_raw: Variant = report.get(
		"result",
		{}
	)

	if typeof(
		result_raw
	) == TYPE_DICTIONARY:
		var result: Dictionary = (
			result_raw as Dictionary
		)

		if not result.is_empty():
			return result



	return report


static func _global_reality_intake_hide_button_style(hovered: bool = false) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.84, 0.1, 1.0) if not hovered else Color(1.0, 0.94, 0.32, 1.0)
	style.border_color = Color(1.0, 1.0, 0.72, 0.92)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 13
	style.corner_radius_top_right = 13
	style.corner_radius_bottom_left = 13
	style.corner_radius_bottom_right = 13
	style.shadow_color = Color(1.0, 0.78, 0.08, 0.34)
	style.shadow_size = 8 if hovered else 5
	return style


static func _global_reality_intake_tab_style(hovered: bool = false) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.026, 0.028, 0.038, 0.94) if not hovered else Color(0.05, 0.054, 0.07, 0.98)
	style.border_color = Color(1.0, 0.84, 0.1, 0.62)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_right = 0
	style.shadow_color = Color(1.0, 0.84, 0.1, 0.18)
	style.shadow_size = 10 if hovered else 6
	return style


static func _global_reality_intake_button_style(hovered: bool = false, pressed: bool = false) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()

	if pressed:
		style.bg_color = Color(0.018, 0.02, 0.028, 0.98)
	elif hovered:
		style.bg_color = Color(0.05, 0.054, 0.07, 0.98)
	else:
		style.bg_color = Color(0.026, 0.028, 0.038, 0.94)

	style.border_color = Color(0.86, 0.92, 1.0, 0.62) if hovered else Color(0.72, 0.78, 0.9, 0.36)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.shadow_color = Color(0.5, 0.64, 1.0, 0.2 if hovered else 0.1)
	style.shadow_size = 14 if hovered else 8
	return style


static func _canonical_reality_mode_key(mode_text: String) -> String:
	var clean_mode: String = str(mode_text).strip_edges().to_lower()

	if clean_mode == "":
		return "chaos"

	if clean_mode == "fantasy":
		return "chaos"

	if clean_mode in ["realistic", "enhanced", "chaos"]:
		return clean_mode

	return "chaos"


static func _canonical_feature_override_key(raw_key: Variant) -> String:
	var clean_key: String = str(raw_key).strip_edges().to_lower()
	clean_key = clean_key.replace("-", "_")
	clean_key = clean_key.replace(" ", "_")

	match clean_key:
		"bending":
			return "bending"
		"super_power", "super_powers", "superpower", "superpowers":
			return "superpowers"
		"vampire", "vampires":
			return "vampires"
		"artifact", "artifacts":
			return "artifacts"
		"dragon_ball", "dragon_balls", "dragonball", "dragonballs":
			return "dragonballs"
		"many_realm", "many_realms":
			return "many_realms"
		"supernatural_school":
			return "supernatural_school"
		"supernatural_event", "supernatural_events":
			return "supernatural_events"
		_:
			return ""


static func _custom_household_job_diary_line(_person: Person) -> String:
	return ""


static func _article_for_phrase(text: String) -> String:
	var clean_text: String = str(text).strip_edges()
	if clean_text == "":
		return "a"

	var first_char: String = clean_text.substr(0, 1).to_lower()
	if first_char in ["a", "e", "i", "o", "u"]:
		return "an"

	return "a"


static func _custom_household_relation_label_from_actor(actor_key: String, other_key: String, members_by_key: Dictionary) -> String:
	if actor_key == "" or other_key == "":
		return "household member"

	var other_member: Dictionary = members_by_key.get(other_key, {}) if typeof(members_by_key.get(other_key, {})) == TYPE_DICTIONARY else {}
	var other_anchor_key: String = str(other_member.get("relationship_anchor_key", "")).strip_edges()
	var other_relation_to_anchor: String = str(other_member.get("relationship_to_anchor", other_member.get("relationship_to_start", "household member"))).strip_edges().to_lower()

	if other_anchor_key == actor_key:
		return other_relation_to_anchor if other_relation_to_anchor != "" and other_relation_to_anchor != "none" else "household member"

	var actor_member: Dictionary = members_by_key.get(actor_key, {}) if typeof(members_by_key.get(actor_key, {})) == TYPE_DICTIONARY else {}
	var actor_anchor_key: String = str(actor_member.get("relationship_anchor_key", "")).strip_edges()
	var actor_relation_to_anchor: String = str(actor_member.get("relationship_to_anchor", actor_member.get("relationship_to_start", "household member"))).strip_edges().to_lower()

	if actor_anchor_key == other_key:
		match actor_relation_to_anchor:
			"mother":
				return "child"
			"father":
				return "child"
			"parent":
				return "child"
			"child", "son", "daughter":
				return "parent"
			"husband":
				return "wife"
			"wife":
				return "husband"
			"spouse":
				return "spouse"
			"brother", "sister", "sibling":
				return "sibling"
			"roommate":
				return "roommate"
			"friend":
				return "friend"
			"ex":
				return "ex"
			_:
				return "household member"

	return "household member"


static func _custom_household_is_birth_leak_diary_line(text: String) -> bool:
	var lower_text: String = str(text).strip_edges().to_lower()
	if lower_text == "":
		return true

	return lower_text.begins_with("i was born ") \
or lower_text.begins_with("i was conceived ") \
or lower_text.begins_with("before i was born") \
or lower_text.begins_with("before you had a name") \
or lower_text.begins_with("my soul was chosen ") \
or lower_text.begins_with("i was blessed to be born with ") \
or lower_text.begins_with("i was reincarnated as ") \
or lower_text.find(" was born with ") != -1 \
or lower_text.find(" birth class") != -1 \
or lower_text.find(" birth contract") != -1 \
or lower_text.find(" being born into ") != -1 \
or lower_text.find("you are being born") != -1 \
or lower_text.find("i was born touched by") != -1 \
or lower_text.begins_with("my birthday is ") \
or lower_text.begins_with("my father is ") \
or lower_text.begins_with("my mother is ") \
or lower_text.find("grandfather is ") != -1 \
or lower_text.find("grandmother is ") != -1 \
or lower_text.find("great-grandfather is ") != -1 \
or lower_text.find("great-grandmother is ") != -1


static func _format_birth_place_text(city: String, state: String, country: String) -> String:
	var clean_city: String = str(city).strip_edges()
	var clean_state: String = str(state).strip_edges()
	var clean_country: String = str(country).strip_edges()

	if clean_country.to_lower() in ["usa", "united states", "united states of america"]:
		clean_country = "USA"

	if clean_state != "":
		return "%s, %s, %s" % [clean_city, clean_state, clean_country]

	return "%s, %s" % [clean_city, clean_country]


static func _compact_diary_text(text: String) -> String:
	var raw_text: String = str(text).strip_edges()
	if raw_text == "":
		return ""

	var out:= ""
	for raw_line in raw_text.split("\n", false):
		var line: String = str(raw_line).strip_edges()
		if line == "":
			continue
		if out != "":
			out += " "
		out += line

	return out


static func _world_feed_section_label(section_key: String) -> String:
	match section_key:
		"politics":
			return "POLITICS / STATECRAFT"
		"dynasty":
			return "DYNASTY / SUCCESSION"
		"factions":
			return "FACTIONS / POWER BLOCS"
		"conflict":
			return "CONFLICT / WAR"
		"bending":
			return "BENDING / ELEMENTAL SHIFTS"
		"cosmic":
			return "COSMIC / UNNATURAL EVENTS"
		"artifacts":
			return "ARTIFACTS / RELICS"
		"world":
			return "WORLD SHIFTS"
		_:
			return "SOCIETY / SIGNALS"


static func _world_feed_section_color(section_key: String) -> Color:
	match section_key:
		"politics":
			return Color(1.0, 0.84, 0.54, 1.0)
		"dynasty":
			return Color(1.0, 0.74, 0.88, 1.0)
		"factions":
			return Color(0.78, 0.92, 1.0, 1.0)
		"conflict":
			return Color(1.0, 0.66, 0.66, 1.0)
		"bending":
			return Color(0.64, 1.0, 0.82, 1.0)
		"cosmic":
			return Color(0.66, 0.9, 1.0, 1.0)
		"artifacts":
			return Color(1.0, 0.8, 0.28, 1.0)
		"world":
			return Color(0.86, 0.88, 1.0, 1.0)
		_:
			return Color(0.82, 0.92, 0.96, 1.0)


static func _world_feed_trimmed_lines(text: String) -> Array:
	var out: Array = []
	for raw_line in str(text).split("\n", false):
		var clean_line: String = str(raw_line).strip_edges()
		if clean_line == "":
			continue
		out.append(clean_line)
	return out


static func _extract_compact_politics_fragment(line: String, label: String) -> String:
	var source: String = str(line).strip_edges()
	var lower_source: String = source.to_lower()
	var lower_label: String = label.to_lower()
	var start: int = lower_source.find(lower_label)
	if start == -1:
		return ""
	var end: int = source.length()
	var delimiters: Array = [",", "•", "|", ";"]
	for raw_delimiter in delimiters:
		var delimiter: String = str(raw_delimiter)
		var candidate: int = source.find(delimiter, start)
		if candidate != -1 and candidate < end:
			end = candidate
	var fragment: String = source.substr(start, end - start).strip_edges()
	while fragment.begins_with(":") or fragment.begins_with("-") or fragment.begins_with("—"):
		if fragment.length() <= 1:
			break
		fragment = fragment.substr(1, fragment.length() - 1).strip_edges()
	return fragment


static func _compact_politics_payload_from_fragment(fragment: String, label: String) -> String:
	var out: String = str(fragment).strip_edges()
	var lower_out: String = out.to_lower()
	var lower_label: String = label.to_lower()
	if lower_out.begins_with(lower_label):
		out = out.substr(label.length(), out.length() - label.length()).strip_edges()
	while out.begins_with(":") or out.begins_with("-") or out.begins_with("—"):
		if out.length() <= 1:
			break
		out = out.substr(1, out.length() - 1).strip_edges()
	return out if out != "" else str(fragment).strip_edges()


static func _append_compact_politics_row(rows: Array, seen: Dictionary, label: String, payload: String) -> void:
	var clean_payload: String = str(payload).strip_edges()
	if clean_payload == "":
		return
	var row: String = "%s • %s" % [label, clean_payload]
	if seen.has(row):
		return
	seen [row] = true
	rows.append(row)


static func _world_feed_section_priority(section_key: String) -> int:
	match section_key:
		"cosmic":
			return 0
		"artifacts":
			return 1
		"conflict":
			return 2
		"politics":
			return 3
		"dynasty":
			return 4
		"factions":
			return 5
		"bending":
			return 6
		"world":
			return 7
		_:
			return 8


static func _append_relationship_browser_target(targets: Array, seen: Dictionary, npc: Person, section: String) -> void:
	if npc == null:
		return
	if npc.id <= 0:
		return
	if seen.has(npc.id):
		return

	var final_section:= section
	if not npc.alive:
		final_section = "Dead Relationships"

	seen [npc.id] = true
	targets.append({
		"id": npc.id,
		"section": final_section,
		"npc": npc
	})


static func _add_unique_death_panel_family_id(ids: Array, seen: Dictionary, npc_id: int) -> void:
	if npc_id <= 0:
		return
	if seen.has(npc_id):
		return
	seen [npc_id] = true
	ids.append(npc_id)


static func _net_worth_entry_value(entry: Dictionary) -> float:
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


static func _stat_meter(label: String, value: int, max_value: int) -> String:
	var clamped_value: int = clamp(value, 0, max_value)
	var width:= 18
	var filled:= int(round((float(clamped_value) / float(max_value)) * width))
	filled = clamp(filled, 0, width)

	var bar:= ""
	for i in range(width):
		bar += "█" if i < filled else "░"

	return "%s: [%s] %d/%d" % [label, bar, clamped_value, max_value]


static func _diary_entry_has_body_lines(lines: Array) -> bool:
	for raw_line in lines:
		var line: String = str(raw_line).strip_edges()
		if line == "":
			continue
		if line == "----------------------":
			continue
		if line.begins_with("Year: "):
			continue
		if line.begins_with("Age: "):
			continue
		return true
	return false


static func _other_country_romance_preference_text(preference: String) -> String:
	var clean: String = str(preference).strip_edges().to_lower()
	if clean in ["man", "men", "male", "boyfriend"]:
		return "a man"
	if clean in ["woman", "women", "female", "girlfriend"]:
		return "a woman"
	return "someone"


static func _other_country_romance_target_needs_definite_article(target_name: String) -> bool:
	var clean: String = str(target_name).strip_edges()
	if clean == "":
		return false

	var lower: String = clean.to_lower()
	if lower.begins_with("the "):
		return true

	var exact_targets: Array = [
		"earth kingdom",
		"fire nation",
		"water tribe",
		"water nation",
		"northern water tribe",
		"southern water tribe",
		"northern air temple",
		"southern air temple",
		"eastern air temple",
		"western air temple",
		"maurya empire",
		"kingdom of aksum",
		"kingdom of askum",
		"united states",
		"united kingdom",
		"netherlands",
		"philippines",
		"maldives"
	]

	if lower in exact_targets:
		return true

	var article_markers: Array = [
		" kingdom",
		" empire",
		" nation",
		" republic",
		" dynasty",
		" temple",
		" temples",
		" tribe",
		" tribes",
		" confederation",
		" federation",
		" state",
		" states",
		" realm",
		" caliphate",
		" sultanate",
		" duchy"
	]

	for marker in article_markers:
		if lower.find(str(marker)) >= 0:
			return true

	return false


static func _append_relationship_browser_target_split_dead(
	targets: Array,
	seen: Dictionary,
	npc: Person,
	living_section: String
) -> void:
	if npc == null:
		return
	if seen.has(npc.id):
		return

	var final_section:= living_section
	if not npc.alive:
		final_section = "Dead Relationships"

	seen [npc.id] = true
	targets.append({
		"id": npc.id,
		"npc": npc,
		"section": final_section
	})


static func _royal_court_role_priority(role: String) -> int:
	match str(role).strip_edges():
		"ruler":
			return 0
		"heir":
			return 1
		"consort":
			return 2
		"regent":
			return 3
		"advisor":
			return 4
		"guard_captain":
			return 5
		"spymaster":
			return 6
		"envoy":
			return 7
		_:
			return 99


static func _royal_court_role_display(role: String) -> String:
	match str(role).strip_edges():
		"ruler":
			return "Ruler"
		"heir":
			return "Heir"
		"consort":
			return "Consort"
		"regent":
			return "Regent"
		"advisor":
			return "Advisor"
		"guard_captain":
			return "Guard Captain"
		"spymaster":
			return "Spymaster"
		"envoy":
			return "Envoy"
		"courtier":
			return "Courtier"
		_:
			return str(role).replace("_", " ").capitalize()


static func _relationship_profile_grocery_locked_job(target: Person) -> String:
	if target == null:
		return ""

	if target.has_meta("grocery_identity_locked_job"):
		var locked_job: String = str(target.get_meta("grocery_identity_locked_job")).strip_edges()
		if locked_job != "":
			return locked_job

	return ""


static func _relationship_profile_job_looks_royal(job_text: String) -> bool:
	var lower_job: String = str(job_text).strip_edges().to_lower()
	if lower_job == "":
		return false

	var royal_terms: Array = [
		"king",
		"queen",
		"prince",
		"princess",
		"duke",
		"duchess",
		"emperor",
		"empress",
		"ruler",
		"royal"
	]

	for raw_term in royal_terms:
		if lower_job.find(str(raw_term)) >= 0:
			return true

	return false


static func _relationship_profile_job_is_invalid(job_text: String) -> bool:
	var lower_job: String = str(job_text).strip_edges().to_lower()
	return lower_job == "" or lower_job == "parent" or lower_job == "mother" or lower_job == "father" or lower_job == "guardian"


static func _relationship_profile_target_has_federal_republic_office(target: Person) -> bool:
	if target == null:
		return false

	var office_contract: Dictionary = {}
	var raw_contract: Variant = target.get("civic_office_contract")
	if typeof(raw_contract) == TYPE_DICTIONARY:
		office_contract = (raw_contract as Dictionary).duplicate(true)

	var government_model: String = str(office_contract.get("government_model", "")).strip_edges().to_lower()
	if government_model in [
		"federal_presidential_republic",
		"federal_republic",
		"presidential_republic",
		"constitutional_republic"
	]:
		return true

	var civic_title: String = str(target.get("civic_title")).strip_edges().to_lower()
	var job_key: String = str(target.job).strip_edges().to_lower()

	return civic_title in [
		"president",
		"first lady",
		"first gentleman",
		"vice president"
	] or job_key in [
		"president",
		"president of the united states",
		"first lady",
		"first gentleman",
		"vice president"
	]


static func _relationship_profile_fame_tier_for_value(value: int) -> String:
	if value >= 90:
		return "Legend"
	if value >= 70:
		return "Global"
	if value >= 50:
		return "National"
	if value >= 25:
		return "Local"
	return "None"


static func _relationship_profile_fame_tier_rank(tier: String) -> int:
	match str(tier).strip_edges().to_lower():
		"legend":
			return 4
		"global":
			return 3
		"national":
			return 2
		"local":
			return 1
		_:
			return 0


static func _relationship_profile_effective_property_count(target: Person, raw_property_count: int, effective_social_class: String) -> int:
	if target == null:
		return max(0, raw_property_count)

	if raw_property_count > 0:
		return raw_property_count

	if int(target.age) < 18:
		return 0

	var class_text: String = str(effective_social_class).strip_edges().to_lower()
	if class_text.find("royal") >= 0 or class_text.find("noble") >= 0 or class_text.find("elite") >= 0:
		return 3
	if class_text.find("upper") >= 0:
		return 2

	return 1


static func _relationship_profile_effective_vehicle_count(target: Person, raw_vehicle_count: int, effective_income: int, effective_social_class: String) -> int:
	if target == null:
		return max(0, raw_vehicle_count)

	if raw_vehicle_count > 0:
		return raw_vehicle_count

	if int(target.age) < 18:
		return 0

	var class_text: String = str(effective_social_class).strip_edges().to_lower()
	if class_text.find("royal") >= 0 or class_text.find("noble") >= 0 or class_text.find("elite") >= 0:
		return 2
	if class_text.find("upper") >= 0:
		return 1
	if effective_income >= 65000:
		return 1

	return 0


static func _relationship_profile_home_is_placeholder(city: String, country: String) -> bool:
	var home_text: String = ("%s, %s" % [city, country]).strip_edges().to_lower()
	if home_text == ",":
		return true
	if home_text.find("frontier realm") >= 0:
		return true
	if str(city).strip_edges() == "" or str(country).strip_edges() == "":
		return true
	return false


static func _relationship_profile_should_show_pregnancy_line(target: Person) -> bool:
	if target == null:
		return false

	var gender_text: String = str(target.gender).strip_edges().to_lower()
	var pregnancy_active: bool = int(target.pregnancy_progress) >= 0 or bool(target.pregnancy_known)

	if pregnancy_active:
		return true

	if gender_text == "male" or gender_text == "man" or gender_text == "boy":
		return false

	return true


static func _relationship_profile_hunger_descriptor(hunger_value: float) -> String:
	var value: int = clamp(int(round(hunger_value)), 0, 100)

	if value <= 5:
		return "Critical Starvation"
	if value <= 18:
		return "Starving"
	if value <= 35:
		return "Malnourished"
	if value <= 55:
		return "Hungry"
	if value <= 72:
		return "Peckish"
	if value <= 92:
		return "Satisfied"
	return "Full"


static func _relationship_profile_height_text_from_contract(height_contract: Dictionary) -> String:
	var display: String = str(height_contract.get("display", "")).strip_edges()
	if display != "":
		return display

	var height_in: float = float(height_contract.get("height_in", height_contract.get("height_inches", 0.0)))
	if height_in > 0.0:
		var rounded: int = int(round(height_in))
		var feet: int = int(floor(float(rounded) / 12.0))
		var inches: int = int(rounded % 12)
		return "%d'%d\"" % [feet, inches]

	var display_metric: String = str(height_contract.get("display_metric", "")).strip_edges()
	if display_metric != "":
		return display_metric

	return ""


static func _relationship_profile_weight_text_from_contract(weight_contract: Dictionary) -> String:
	var display: String = str(weight_contract.get("display", "")).strip_edges()
	if display != "":
		return display

	var weight_lbs: float = float(weight_contract.get("weight_lbs", weight_contract.get("walkaround_weight_lbs", 0.0)))
	if weight_lbs > 0.0:
		return "%d lb" % int(round(weight_lbs))

	var display_metric: String = str(weight_contract.get("display_metric", "")).strip_edges()
	if display_metric != "":
		return display_metric

	return ""


static func _relationship_profile_local_direct_number_from_person(target: Person, keys: Array) -> float:
	if target == null:
		return 0.0

	for raw_key in keys:
		var key: String = str(raw_key)
		if key == "":
			continue
		if key in target:
			var raw_value: Variant = target.get(key)
			var number_value: float = float(raw_value)
			if number_value > 0.0:
				return number_value

	return 0.0


static func _relationship_profile_local_body_type_for_actor(target: Person) -> String:
	if target == null:
		return "mesomorph"

	var seed_value: int = abs(hash("relationship_profile_body_type|%d|%s|%s" % [
		int(target.id),
		str(target.gender),
		str(target.first_name)
	])) % 3

	if seed_value == 0:
		return "ectomorph"
	if seed_value == 2:
		return "endomorph"
	return "mesomorph"


static func _relationship_profile_local_body_type_display_name(body_type: String) -> String:
	match str(body_type).strip_edges().to_lower():
		"ectomorph":
			return "Ectomorph"
		"endomorph":
			return "Endomorph"
		_:
			return "Mesomorph"


static func _relationship_profile_local_body_type_traits(body_type: String) -> Dictionary:
	match str(body_type).strip_edges().to_lower():
		"ectomorph":
			return {
				"fat_gain_multiplier": 0.78,
				"muscle_gain_multiplier": 0.88,
				"natural_frame_multiplier": 0.92,
				"metabolism_multiplier": 1.14,
				"weight_drift_to_setpoint": 0.18,
				"description": "Naturally leaner frame, faster metabolism, harder weight gain."
			}
		"endomorph":
			return {
				"fat_gain_multiplier": 1.22,
				"muscle_gain_multiplier": 1.03,
				"natural_frame_multiplier": 1.1,
				"metabolism_multiplier": 0.88,
				"weight_drift_to_setpoint": 0.12,
				"description": "Naturally heavier frame, easier weight gain, slower weight loss."
			}
		_:
			return {
				"fat_gain_multiplier": 1.0,
				"muscle_gain_multiplier": 1.1,
				"natural_frame_multiplier": 1.02,
				"metabolism_multiplier": 1.0,
				"weight_drift_to_setpoint": 0.15,
				"description": "Balanced athletic frame with average weight response."
			}


static func _relationship_profile_local_adult_height_for_actor(target: Person) -> float:
	if target == null:
		return 67.0

	var gender_text: String = str(target.gender).strip_edges().to_lower()
	var base_height: float = 69.0
	if gender_text in ["female", "woman", "girl", "f"]:
		base_height = 64.0

	var rng:= RandomNumberGenerator.new()
	rng.seed = abs(hash("relationship_profile_adult_height|%d|%s|%s" % [
		int(target.id),
		str(target.gender),
		str(target.last_name)
	])) % 2147483647

	return clamp(base_height + rng.randfn(0.0, 2.2), 48.0, 86.0)


static func _relationship_profile_local_height_growth_factor_for_age(age: int) -> float:
	var age_value: float = max(0.0, float(age))
	var maturity_age: float = 18.0

	if age_value <= 0.0:
		return 0.305
	if age_value < 2.0:
		return lerp(0.305, 0.485, age_value / 2.0)
	if age_value < 6.0:
		return lerp(0.485, 0.655, (age_value - 2.0) / 4.0)
	if age_value < 12.0:
		return lerp(0.655, 0.815, (age_value - 6.0) / 6.0)
	if age_value < maturity_age:
		return lerp(0.815, 1.0, (age_value - 12.0) / max(1.0, maturity_age - 12.0))
	if age_value >= 65.0:
		return clamp(1.0 - ((age_value - 65.0) * 0.0012), 0.955, 1.0)

	return 1.0


static func _relationship_profile_local_life_stage_for_age(age: int) -> String:
	if age <= 1:
		return "baby"
	if age <= 5:
		return "child"
	if age <= 12:
		return "preteen"
	if age <= 17:
		return "teen"
	if age <= 25:
		return "young_adult"
	if age <= 59:
		return "adult"
	if age <= 79:
		return "elder"
	return "elderly"


static func _relationship_profile_local_format_height_inches(height_in: float) -> String:
	var rounded: int = int(round(height_in))
	var feet: int = int(floor(float(rounded) / 12.0))
	var inches: int = int(rounded % 12)
	return "%d'%d\"" % [feet, inches]


static func _relationship_profile_local_healthy_weight_for_height(height_in: float, traits: Dictionary, weight_growth_factor: float) -> float:
	var height_m: float = max(0.3, height_in * 0.0254)
	var adult_healthy: float = 22.0 * height_m * height_m * 2.20462
	var frame_multiplier: float = clamp(float(traits.get("natural_frame_multiplier", 1.0)), 0.72, 1.35)
	var growth_factor: float = clamp(weight_growth_factor, 0.1, 1.08)
	return clamp(adult_healthy * frame_multiplier * growth_factor, 5.0, 650.0)


static func _relationship_profile_local_starting_weight_offset(target: Person, body_type: String) -> float:
	if target == null:
		return 0.0

	var rng:= RandomNumberGenerator.new()
	rng.seed = abs(hash("relationship_profile_starting_weight|%d|%s|%s" % [
		int(target.id),
		str(target.age),
		str(body_type)
	])) % 2147483647

	var center: float = 1.5
	match str(body_type).strip_edges().to_lower():
		"ectomorph":
			center = -5.0
		"endomorph":
			center = 7.0
		_:
			center = 1.5

	return rng.randfn(center, 4.0)


static func _relationship_profile_local_weight_category_from_bmi(bmi: float) -> String:
	if bmi < 18.5:
		return "lean"
	if bmi < 25.0:
		return "average"
	if bmi < 30.0:
		return "overweight"
	return "obese"


static func _relationship_profile_unified_child_panel_style() -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.024, 0.058, 0.18)
	style.border_color = Color(1.0, 0.48, 0.72, 0.14)
	style.border_width_left = 0
	style.border_width_top = 0
	style.border_width_right = 0
	style.border_width_bottom = 0
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.0)
	style.shadow_size = 0
	style.shadow_offset = Vector2.ZERO
	return style


static func _relationship_profile_stats_panel_style() -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.026, 0.07, 0.74)
	style.border_color = Color(1.0, 1.0, 1.0, 0.0)
	style.border_width_left = 0
	style.border_width_top = 0
	style.border_width_right = 0
	style.border_width_bottom = 0
	style.corner_radius_top_left = 22
	style.corner_radius_top_right = 22
	style.corner_radius_bottom_left = 22
	style.corner_radius_bottom_right = 22
	style.shadow_color = Color(1.0, 0.2, 0.64, 0.16)
	style.shadow_size = 14
	style.shadow_offset = Vector2.ZERO
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style


static func _relationship_profile_move_children(
	source: Node,
	destination: Node
) -> void:
	if source == null or destination == null:
		return

	while source.get_child_count() > 0:
		var child: Node = source.get_child(0)

		source.remove_child(child)
		destination.add_child(child)


static func _elemental_nation_for_bending_type(bending_type_text: String) -> String:
	match str(bending_type_text).strip_edges().to_lower():
		"air":
			return "Air Nomads"
		"water":
			return "Water Tribe"
		"earth":
			return "Earth Kingdom"
		"fire":
			return "Fire Nation"
		_:
			return ""


static func _relationship_civic_display_title(npc: Person) -> String:
	if npc == null:
		return ""

	var civic_title: String = str(npc.get("civic_title")).strip_edges()
	if civic_title != "":
		return civic_title

	var job_text: String = str(npc.job).strip_edges().to_lower()

	if job_text == "president" or job_text == "president of the united states":
		return "President"

	if job_text == "first lady":
		return "First Lady"

	if job_text == "first gentleman":
		return "First Gentleman"

	return ""


static func _relationship_profile_click_key(kind: String, action_id: String = "", target_id: int = -1) -> String:
	return "%s:%s:%d" % [
		str(kind).strip_edges().to_lower(),
		str(action_id).strip_edges(),
		int(target_id)
	]


static func _relationship_profile_is_primary_click_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mouse_event:= event as InputEventMouseButton
		return mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed

	if event is InputEventScreenTouch:
		var touch_event:= event as InputEventScreenTouch
		return touch_event.pressed

	return false


static func _resident_actor_lens_push_candidate_id(
	raw_id: Variant,
	out: Array,
	seen: Dictionary
) -> void:
	var clean_id: int = int(raw_id)

	if clean_id <= 0:
		return

	if seen.has(clean_id):
		return

	seen [clean_id] = true
	out.append(clean_id)


static func _relationship_profile_switch_room_prewarm_meta_key(target_id: int) -> String:
	return "relationship_profile_switch_room_prewarm_requested_%d" % int(target_id)


static func _add_bending_style_echo_rows_to_box(box: VBoxContainer, title: String, rows: Array, max_rows: int = 8) -> void:
	var title_label:= Label.new()
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.text = "\n%s" % title
	box.add_child(title_label)

	if rows.is_empty():
		var empty_label:= Label.new()
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.text = "No style echoes have formed yet."
		box.add_child(empty_label)
		return

	for i in range(min(max_rows, rows.size())):
		if typeof(rows [i]) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = rows [i]
		var label:= Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = "#%d %s • %s • Echo Heat %d\n%s\nBloodline: %s | Dojo: %s | Nation: %s" % [
			i + 1,
			str(row.get("style_title", "Unformed Style")),
			str(row.get("element", "none")).capitalize(),
			int(row.get("echo_heat", 0)),
			str(row.get("myth_title", "A recognizable fighting culture is beginning to form.")),
			str(row.get("bloodline", "Unknown")),
			str(row.get("dojo_name", "Solo")),
			str(row.get("nation", "Unknown"))
		]
		box.add_child(label)


static func _add_bending_history_board_to_box(box: VBoxContainer, title: String, rows: Array) -> void:
	var title_label:= Label.new()
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.text = "\n%s" % title
	box.add_child(title_label)

	if rows.is_empty():
		var empty_label:= Label.new()
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.text = "No records yet."
		box.add_child(empty_label)
		return

	for i in range(min(5, rows.size())):
		if typeof(rows [i]) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = rows [i]
		var wins: int = int(row.get("wins", 0))
		var losses: int = int(row.get("losses", 0))
		var fights: int = max(1, wins + losses)
		var win_pct: float = float(wins) / float(fights) * 100.0

		var record_label:= Label.new()
		record_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		record_label.text = "#%d %s • %d-%d • %.1f%% • KO %d • Titles %d • %s" % [
			i + 1,
			str(row.get("name", "Unknown")),
			wins,
			losses,
			win_pct,
			int(row.get("kos", 0)),
			int(row.get("championships", 0)),
			str(row.get("element", "none")).capitalize()
		]
		box.add_child(record_label)


static func _grant_picker_button_label(element: String) -> String:
	return "Grant %s Bending" % element.capitalize()


static func _grantable_avatar_elements_for_target(target: Person) -> Array:
	var out: Array = []
	if target == null:
		return out

	for element in ["air", "earth", "fire", "water"]:
		if int(target.bending_mastery.get(element, 0)) <= 0:
			out.append(element)

	return out


static func _removable_avatar_elements_for_target(target: Person) -> Array:
	var out: Array = []
	if target == null:
		return out

	for element in ["air", "earth", "fire", "water"]:
		if int(target.bending_mastery.get(element, 0)) > 0:
			out.append(element)

	return out


static func _switch_action_label_for_target(target: Person) -> String:
	if target == null:
		return "SWITCH TO THEM"
	if str(target.gender) == "Male":
		return "SWITCH TO HIM"
	if str(target.gender) == "Female":
		return "SWITCH TO HER"
	return "SWITCH TO THEM"


static func _life_diary_actor_flat_cache_key(actor_id: int) -> String:
	return "life_diary_actor_%d_flat_lines" % int(actor_id)


static func _life_diary_actor_cache_key(actor_id: int) -> String:
	return "life_diary_actor_%d_entries" % int(actor_id)


static func _person_display_name_for_identity_switch(person: Person) -> String:
	if person == null:
		return "Unknown Life"

	var first: String = str(person.first_name).strip_edges()
	var last: String = str(person.last_name).strip_edges()
	var full_name: String = ("%s %s" % [first, last]).strip_edges()

	if full_name == "":
		full_name = str(person.name).strip_edges()
	if full_name == "":
		full_name = "Unknown Life"

	return full_name


static func _relationship_profile_gendered_niece_nephew_label(target: Person) -> String:
	if target == null:
		return "Niece/Nephew"

	var gender: String = str(target.gender).strip_edges().to_lower()
	if gender == "male" or gender == "man" or gender == "boy":
		return "Nephew"
	if gender == "female" or gender == "woman" or gender == "girl":
		return "Niece"

	return "Niece/Nephew"


static func _relationship_profile_gendered_child_label(target: Person) -> String:
	if target == null:
		return "child"

	var gender: String = str(target.gender).strip_edges().to_lower()
	if gender == "male" or gender == "man" or gender == "boy":
		return "son"
	if gender == "female" or gender == "woman" or gender == "girl":
		return "daughter"

	return "child"


static func _relationship_profile_gendered_sibling_label(sibling: Person) -> String:
	if sibling == null:
		return "Sibling"

	var gender: String = str(sibling.gender).strip_edges().to_lower()
	if gender == "male" or gender == "man" or gender == "boy":
		return "Brother"
	if gender == "female" or gender == "woman" or gender == "girl":
		return "Sister"

	return "Sibling"


static func _collect_interactive_surface_authority_candidates(node: Node, out: Array) -> void:
	if node == null:
		return

	for child in node.get_children():
		if child is Control:
			var control_child: Control = child
			if bool(control_child.get_meta("interactive_surface_claimed", false)):
				out.append(control_child)

		_collect_interactive_surface_authority_candidates(child, out)


static func _relationship_hub_climate_chip_style(climate_value: int) -> StyleBoxFlat:
	var safe_value: int = clamp(int(climate_value), 0, 100)
	var ratio: float = clamp(float(safe_value) / 100.0, 0.0, 1.0)

	var cold_accent: Color = Color(0.34, 0.62, 1.0, 0.92)
	var neutral_accent: Color = Color(0.78, 0.64, 0.92, 0.94)
	var warm_accent: Color = Color(1.0, 0.5, 0.74, 0.98)

	var accent: Color = cold_accent.lerp(neutral_accent, clamp(ratio * 2.0, 0.0, 1.0))
	if ratio > 0.5:
		accent = neutral_accent.lerp(warm_accent, clamp((ratio - 0.5) * 2.0, 0.0, 1.0))

	var cold_base: Color = Color(0.018, 0.03, 0.064, 0.98)
	var warm_base: Color = Color(0.105, 0.034, 0.082, 0.98)

	var style:= StyleBoxFlat.new()
	style.bg_color = cold_base.lerp(warm_base, ratio)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.62 + ratio * 0.3)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.12 + ratio * 0.42)
	style.shadow_size = int(round(lerp(5.0, 26.0, ratio)))
	style.shadow_offset = Vector2(0, 4)
	return style


static func _school_hub_join_strings(values: Array, separator: String = ", ") -> String:
	var out: String = ""
	for i in range(values.size()):
		if i > 0:
			out += separator
		out += str(values [i])
	return out


static func _school_hub_parse_child_id_csv(raw_text: String) -> Array:
	var out: Array = []
	var parts: PackedStringArray = str(raw_text).split(",", false)
	for raw_part in parts:
		var child_id: int = int(str(raw_part).strip_edges())
		if child_id > 0 and not out.has(child_id):
			out.append(child_id)
	return out


static func _relationship_hub_control_tree_has_rendered_card(root: Node, depth: int = 0) -> bool:
	if root == null:
		return false
	if not is_instance_valid(root):
		return false
	if depth > 8:
		return false

	if root is Control:
		var control: Control = root as Control
		if control.has_meta("relationship_card_npc_id"):
			return true
		if control.has_meta("relationship_card_contract"):
			return true
		if control.has_meta("relationship_card_contract_engine_owned"):
			return true

	for child in root.get_children():
		if child is Node:
			if _relationship_hub_control_tree_has_rendered_card(child as Node, depth + 1):
				return true

	return false


static func _relationship_hub_section_key_from_button_text(label_text: String) -> String:
	var clean: String = str(label_text).strip_edges().to_lower()
	match clean:
		"family":
			return "family"
		"ancestors":
			return "ancestors"
		"my household":
			return "household"
		"partner":
			return "partner"
		"pets", "pet", "animals", "animal", "companions":
			return "pets"
		"descendants":
			return "descendants"
		"dead":
			return "dead"
		"social":
			return "social"
		"exes":
			return "exes"
		_:
			return clean


static func _relationship_hub_section_palette(section_key: String) -> Dictionary:
	var clean: String = str(section_key).strip_edges().to_lower()
	match clean:
		"family":
			return {
				"accent": Color(1.0, 0.5, 0.74, 0.96),
				"active_fill": Color(0.145, 0.05, 0.105, 0.98),
				"inactive_fill": Color(0.06, 0.03, 0.055, 0.94),
				"hover_fill": Color(0.195, 0.065, 0.125, 0.98),
				"font_color": Color(1.0, 0.96, 0.99, 1.0),
				"shadow_color": Color(0.48, 0.08, 0.24, 0.28)
			}
		"ancestors":
			return {
				"accent": Color(0.92, 0.8, 0.46, 0.94),
				"active_fill": Color(0.135, 0.105, 0.04, 0.98),
				"inactive_fill": Color(0.06, 0.05, 0.028, 0.94),
				"hover_fill": Color(0.18, 0.145, 0.055, 0.98),
				"font_color": Color(1.0, 0.97, 0.88, 1.0),
				"shadow_color": Color(0.38, 0.3, 0.1, 0.24)
			}
		"household":
			return {
				"accent": Color(1.0, 0.72, 0.42, 0.94),
				"active_fill": Color(0.17, 0.088, 0.032, 0.98),
				"inactive_fill": Color(0.08, 0.045, 0.02, 0.94),
				"hover_fill": Color(0.215, 0.108, 0.04, 0.98),
				"font_color": Color(1.0, 0.97, 0.92, 1.0),
				"shadow_color": Color(0.46, 0.2, 0.05, 0.24)
			}
		"social":
			return {
				"accent": Color(0.42, 0.88, 1.0, 0.94),
				"active_fill": Color(0.035, 0.112, 0.15, 0.98),
				"inactive_fill": Color(0.02, 0.058, 0.085, 0.94),
				"hover_fill": Color(0.05, 0.145, 0.188, 0.98),
				"font_color": Color(0.95, 0.99, 1.0, 1.0),
				"shadow_color": Color(0.06, 0.28, 0.36, 0.24)
			}
		"dead":
			return {
				"accent": Color(0.62, 0.7, 0.84, 0.9),
				"active_fill": Color(0.06, 0.074, 0.105, 0.98),
				"inactive_fill": Color(0.035, 0.045, 0.065, 0.94),
				"hover_fill": Color(0.085, 0.1, 0.135, 0.98),
				"font_color": Color(0.92, 0.96, 1.0, 1.0),
				"shadow_color": Color(0.1, 0.14, 0.22, 0.2)
			}
		"partner":
			return {
				"accent": Color(1.0, 0.4, 0.6, 0.96),
				"active_fill": Color(0.165, 0.04, 0.085, 0.98),
				"inactive_fill": Color(0.072, 0.02, 0.05, 0.94),
				"hover_fill": Color(0.21, 0.05, 0.098, 0.98),
				"font_color": Color(1.0, 0.96, 0.98, 1.0),
				"shadow_color": Color(0.44, 0.06, 0.18, 0.24)
			}
		"exes":
			return {
				"accent": Color(0.98, 0.42, 0.62, 0.92),
				"active_fill": Color(0.115, 0.045, 0.07, 0.98),
				"inactive_fill": Color(0.055, 0.025, 0.045, 0.94),
				"hover_fill": Color(0.155, 0.05, 0.08, 0.98),
				"font_color": Color(1.0, 0.96, 0.98, 1.0),
				"shadow_color": Color(0.4, 0.08, 0.16, 0.22)
			}
		"descendants":
			return {
				"accent": Color(0.88, 0.6, 1.0, 0.94),
				"active_fill": Color(0.102, 0.052, 0.13, 0.98),
				"inactive_fill": Color(0.052, 0.028, 0.072, 0.94),
				"hover_fill": Color(0.13, 0.062, 0.165, 0.98),
				"font_color": Color(0.98, 0.96, 1.0, 1.0),
				"shadow_color": Color(0.22, 0.08, 0.3, 0.22)
			}
		_:
			return {
				"accent": Color(1.0, 0.48, 0.72, 0.9),
				"active_fill": Color(0.1, 0.04, 0.085, 0.98),
				"inactive_fill": Color(0.05, 0.022, 0.045, 0.94),
				"hover_fill": Color(0.135, 0.05, 0.095, 0.98),
				"font_color": Color(1.0, 1.0, 1.0, 1.0),
				"shadow_color": Color(0.0, 0.0, 0.0, 0.24)
			}


static func _institution_hub_visual_control_for_row_data(row_data: Dictionary) -> Control:
	if row_data.has("card_surface"):
		return row_data.get("card_surface", null)
	if row_data.has("bar"):
		return row_data.get("bar", null)
	if row_data.has("label"):
		return row_data.get("label", null)
	return null


static func _relationship_hub_visual_pulse_bucket(pulse_strength: float, max_bucket: int = 6) -> int:
	var safe_max: int = max(1, int(max_bucket))
	return clamp(int(round(clamp(float(pulse_strength), 0.0, 1.0) * float(safe_max))), 0, safe_max)


static func _add_unique_institution_relationship_id(ids: Array, seen: Dictionary, npc_id: int) -> void:
	if npc_id <= 0:
		return
	if seen.has(npc_id):
		return
	seen [npc_id] = true
	ids.append(npc_id)


static func _relationship_safe_person_id_array(person: Person, property_id: String) -> Array:
	var out: Array = []

	if person == null:
		return out

	var raw_value: Variant = person.get(property_id)
	if typeof(raw_value) != TYPE_ARRAY:
		return out

	for raw_id in raw_value:
		var clean_id: int = int(raw_id)
		if clean_id <= 0:
			continue
		if clean_id in out:
			continue
		out.append(clean_id)

	return out


static func _relationship_people_share_any_parent_id(a_parent_ids: Array, b_parent_ids: Array) -> bool:
	if a_parent_ids.is_empty() or b_parent_ids.is_empty():
		return false

	for raw_parent_id in a_parent_ids:
		if int(raw_parent_id) in b_parent_ids:
			return true

	return false


static func _resolve_institution_hub_stat_surface(title: String, value: int, max_value: int, surface_context: Dictionary) -> Dictionary:
	var safe_max: int = max(1, max_value)
	var safe_value: int = clamp(value, 0, safe_max)
	var ratio: float = clamp(float(safe_value) / float(safe_max), 0.0, 1.0)
	var descriptor: String = ""
	var flavor: String = ""

	match title:
		"Career Standing":
			if not bool(surface_context.get("career_active", false)):
				descriptor = "Unemployed"
				flavor = "You do not currently have a job, so your career standing is at zero."
			elif ratio >= 0.85:
				descriptor = "Established"
				flavor = "Your work footing feels secure, respected, and difficult to shake."
			elif ratio >= 0.65:
				descriptor = "Advancing"
				flavor = "Your career is moving with real traction and visible upward pull."
			elif ratio >= 0.45:
				descriptor = "Holding"
				flavor = "Your work position is stable enough, even if it is not dominating the room."
			elif ratio >= 0.25:
				descriptor = "Fragile"
				flavor = "Your career footing exists, but it does not feel fully protected."
			else:
				descriptor = "Precarious"
				flavor = "Your work life feels one bad turn from slipping sideways."
		"Career Pressure":
			if not bool(surface_context.get("career_active", false)):
				descriptor = "Clear"
				flavor = "You are not carrying workplace pressure right now."
			elif ratio >= 0.85:
				descriptor = "Crushing"
				flavor = "Work pressure is sitting on your chest and asking too much from too many directions."
			elif ratio >= 0.65:
				descriptor = "Strained"
				flavor = "Your work stress is real, persistent, and hard to completely shake."
			elif ratio >= 0.45:
				descriptor = "Busy"
				flavor = "There is pressure on the lane, but it still feels manageable."
			elif ratio >= 0.25:
				descriptor = "Managed"
				flavor = "You are carrying the demands of work without feeling swallowed by them."
			else:
				descriptor = "Clear"
				flavor = "Your career lane feels breathable right now."
		"School Standing":
			if not bool(surface_context.get("school_active", false)):
				descriptor = "Inactive"
				flavor = "You are outside formal school right now, so academic standing is not actively being pressed."
			elif ratio >= 0.85:
				descriptor = "Excelling"
				flavor = "Your academic position feels strong, visible, and hard to argue with."
			elif ratio >= 0.65:
				descriptor = "Strong"
				flavor = "You are holding solid footing in school with room to keep climbing."
			elif ratio >= 0.45:
				descriptor = "Steady"
				flavor = "Your school position is intact, even if it is not at the very top."
			elif ratio >= 0.25:
				descriptor = "Slipping"
				flavor = "Your academic footing is still there, but it feels easier to lose than before."
			else:
				descriptor = "At Risk"
				flavor = "Your school standing feels fragile and exposed."
		"School Pressure":
			if not bool(surface_context.get("school_active", false)):
				descriptor = "Clear"
				flavor = "With no active school lane, academic pressure is not the force shaping your day."
			elif ratio >= 0.85:
				descriptor = "Swamped"
				flavor = "School pressure is loud enough that it can crowd everything else in your head."
			elif ratio >= 0.65:
				descriptor = "Pressed"
				flavor = "The weight of school is building and refusing to stay in the background."
			elif ratio >= 0.45:
				descriptor = "Busy"
				flavor = "School is demanding, but the load still feels carryable."
			elif ratio >= 0.25:
				descriptor = "Manageable"
				flavor = "You are feeling the academic load without being buried by it."
			else:
				descriptor = "Light"
				flavor = "School pressure feels low and breathable right now."
		"Relationship Climate":
			if ratio >= 0.85:
				descriptor = "Connected"
				flavor = "Your relationship world feels warm, supported, and emotionally alive."
			elif ratio >= 0.65:
				descriptor = "Warm"
				flavor = "There is meaningful connection around you, even if it is not perfect on every side."
			elif ratio >= 0.45:
				descriptor = "Open"
				flavor = "Your social and family climate feels livable, even with some distance in the air."
			elif ratio >= 0.25:
				descriptor = "Strained"
				flavor = "Connection exists, but the emotional weather around you does not feel fully relaxed."
			else:
				descriptor = "Isolated"
				flavor = "Your relationship climate feels thin, quiet, and short on real support."
		_:
			descriptor = "%d" % safe_value
			flavor = ""

	return {
		"descriptor": descriptor,
		"flavor": flavor,
		"bar_text": "%d" % safe_value,
		"title_text": ""
	}


static func _normalize_career_job_apply_result(job_name: String, result: Dictionary) -> Dictionary:
	var normalized: Dictionary = result.duplicate(true) if typeof(result) == TYPE_DICTIONARY else {}
	var result_text: String = str(normalized.get("text", "")).strip_edges()
	if result_text == "":
		result_text = "The result of your application could not be resolved."

	var success: bool = bool(normalized.get("success", false))
	var lead_text: String = "You applied for %s." % job_name
	if success:
		lead_text = "You applied for %s.\n\nYou got accepted." % job_name
	else:
		lead_text = "You applied for %s.\n\nYou were not accepted." % job_name

	normalized ["text"] = "%s\n\n%s" % [lead_text, result_text]
	normalized ["popup_title"] = "Career Application"
	normalized ["popup_text"] = str(normalized.get("text", ""))
	if not normalized.has("popup_footer"):
		normalized ["popup_footer"] = "Tap anywhere to continue."
	return normalized


static func _career_job_browser_title(job_kind: String) -> String:
	match str(job_kind).strip_edges():
		"part_time":
			return "PART-TIME CAREERS"
		"famous":
			return "FAMOUS CAREER TRACKS"
		_:
			return "FULL-TIME CAREERS"


static func _career_job_browser_body_lines(job_kind: String, person: Person) -> Array:
	var lines: Array = []
	lines.append("===== CAREER BROWSER =====")

	match str(job_kind).strip_edges():
		"part_time":
			lines.append("Lane: Part-Time")
			lines.append("Eligibility: Ages 16-17")
		"famous":
			lines.append("Lane: Famous Career")
			lines.append("Eligibility: Depends on the track")
			lines.append("Boxing starts from the bottom and routes into the Boxing Hub.")
		_:
			lines.append("Lane: Full-Time")
			lines.append("Eligibility: Ages 18+")

	lines.append("Current Age: %d" % int(person.age))
	lines.append("Tap any career below to inspect it.")
	lines.append("==========================")
	return lines


static func _career_hub_workplace_snapshot_lines(person: Person) -> Array:
	var lines: Array = []
	var has_job: bool = str(person.job).strip_edges() != ""
	lines.append("Current Job: %s" % (person.job if has_job else "Unemployed"))
	lines.append("Workplace ID: %s" % (str(person.current_workplace_id) if str(person.current_workplace_id).strip_edges() != "" else "None"))
	lines.append("Performance: %d" % int(person.job_performance))
	lines.append("Stress: %d" % int(person.work_stress))
	if has_job:
		lines.append("Presence: You are actively attached to a workplace lane.")
	else:
		lines.append("Presence: You are not currently attached to any workplace.")
	return lines


static func _school_hub_friendliness_color(value: int) -> Color:
	var clean_value: int = clamp(int(value), 0, 100)
	var red:= Color(0.96, 0.16, 0.18, 1.0)
	var yellow:= Color(0.96, 0.84, 0.22, 1.0)
	var orange:= Color(0.98, 0.48, 0.16, 1.0)
	var green:= Color(0.18, 0.92, 0.38, 1.0)

	if clean_value >= 85:
		return green
	if clean_value >= 75:
		return orange.lerp(green, inverse_lerp(75.0, 85.0, float(clean_value)))
	if clean_value >= 50:
		return yellow.lerp(orange, inverse_lerp(50.0, 74.0, float(clean_value)))

	return red.lerp(yellow, inverse_lerp(0.0, 49.0, float(clean_value)))


static func _school_hub_friendliness_meta_key(title_text: String) -> String:
	var clean_title: String = str(title_text).strip_edges().to_lower()
	if clean_title == "":
		clean_title = "meal_space"
	clean_title = clean_title.replace(" ", "_").replace("/", "_").replace(":", "_")
	return "school_hub_friendliness_display_%s" % clean_title


static func _school_hub_apply_popularity_bar_visual(bar: ProgressBar) -> void:
	if bar == null:
		return

	var cyan:= Color(0.12, 0.9, 1.0, 1.0)

	var fill_style:= StyleBoxFlat.new()
	fill_style.bg_color = cyan
	fill_style.corner_radius_top_left = 8
	fill_style.corner_radius_top_right = 8
	fill_style.corner_radius_bottom_left = 8
	fill_style.corner_radius_bottom_right = 8

	var background_style:= StyleBoxFlat.new()
	background_style.bg_color = Color(cyan.r, cyan.g, cyan.b, 0.13)
	background_style.border_color = Color(cyan.r, cyan.g, cyan.b, 0.28)
	background_style.border_width_left = 1
	background_style.border_width_top = 1
	background_style.border_width_right = 1
	background_style.border_width_bottom = 1
	background_style.corner_radius_top_left = 8
	background_style.corner_radius_top_right = 8
	background_style.corner_radius_bottom_left = 8
	background_style.corner_radius_bottom_right = 8

	bar.add_theme_stylebox_override("fill", fill_style)
	bar.add_theme_stylebox_override("background", background_style)


static func _institution_hub_inner_panel_style(kind: String) -> StyleBoxFlat:
	var clean_kind: String = str(kind).strip_edges().to_lower()
	var accent: Color = Color(0.42, 0.62, 1.0, 0.88)
	var top_color: Color = Color(0.03, 0.045, 0.085, 0.98)
	var base_color: Color = Color(0.015, 0.02, 0.04, 0.98)

	match clean_kind:
		"school":
			accent = Color(0.46, 0.72, 1.0, 0.92)
			top_color = Color(0.03, 0.07, 0.13, 0.98)
			base_color = Color(0.012, 0.024, 0.06, 0.98)
		"relationships":
			accent = Color(1.0, 0.48, 0.72, 0.9)
			top_color = Color(0.078, 0.03, 0.072, 0.98)
			base_color = Color(0.034, 0.014, 0.04, 0.98)
		"career":
			accent = Color(0.52, 0.92, 0.72, 0.88)
			top_color = Color(0.025, 0.08, 0.055, 0.98)
			base_color = Color(0.012, 0.036, 0.026, 0.98)

	var style:= StyleBoxFlat.new()
	style.bg_color = base_color.lerp(top_color, 0.36)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.62)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.48)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 4)
	return style


static func _style_institution_hub_action_button(btn: Button, kind: String) -> void:
	if btn == null:
		return

	var clean_kind: String = str(kind).strip_edges().to_lower()
	var accent: Color = Color(0.42, 0.62, 1.0, 0.88)
	var fill: Color = Color(0.045, 0.06, 0.105, 0.96)

	match clean_kind:
		"school":
			accent = Color(0.46, 0.72, 1.0, 0.92)
			fill = Color(0.04, 0.085, 0.155, 0.96)
		"relationships":
			accent = Color(1.0, 0.48, 0.72, 0.9)
			fill = Color(0.1, 0.04, 0.085, 0.96)
		"career":
			accent = Color(0.52, 0.92, 0.72, 0.88)
			fill = Color(0.04, 0.105, 0.07, 0.96)

	var normal:= StyleBoxFlat.new()
	normal.bg_color = fill
	normal.border_color = Color(accent.r, accent.g, accent.b, 0.62)
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.corner_radius_top_left = 12
	normal.corner_radius_top_right = 12
	normal.corner_radius_bottom_left = 12
	normal.corner_radius_bottom_right = 12
	normal.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
	normal.shadow_size = 5
	normal.shadow_offset = Vector2(0, 2)

	var hover:= normal.duplicate()
	hover.bg_color = fill.lerp(accent, 0.22)
	hover.border_color = accent

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	btn.add_theme_font_size_override("font_size", 14)


static func _school_hub_class_zone_key(class_zone: Dictionary) -> String:
	var zone_id: String = str(class_zone.get("zone_id", "")).strip_edges()
	if zone_id == "":
		zone_id = str(class_zone.get("name", "class")).strip_edges().to_lower().replace(" ", "_")
	if zone_id == "":
		zone_id = "class"
	return zone_id


static func _school_hub_add_mini_surface_bar(parent: Control, title_text: String, value: int, _danger: bool, _surface_context: Dictionary = {}) -> void:
	if parent == null:
		return

	var label:= Label.new()
	label.text = "%s: %d%%" % [title_text, clamp(value, 0, 100)]
	label.add_theme_color_override("font_color", Color(0.82, 0.9, 1.0, 0.96))
	label.add_theme_font_size_override("font_size", 11)
	parent.add_child(label)

	var bar:= ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.value = clamp(value, 0, 100)
	bar.custom_minimum_size = Vector2(0, 14)
	bar.show_percentage = false
	parent.add_child(bar)


static func _school_hub_people_label(count: int) -> String:
	if count == 1:
		return "1 person"
	return "%d people" % max(0, count)


static func _school_hub_add_population_contract_row(rows: Array, seen: Dictionary, row: Dictionary, role: String) -> void:
	var npc_id: int = int(row.get("person_id", -1))
	if npc_id <= 0 or seen.has(npc_id):
		return

	seen [npc_id] = true
	rows.append({
		"person_id": npc_id,
		"full_name": str(row.get("full_name", "Student")),
		"age": int(row.get("age", 0)),
		"role": role,
		"popularity": int(row.get("popularity", 0))
	})


static func _school_hub_popularity_for_person(npc: Person) -> int:
	if npc == null:
		return 0

	var score: float = 0.0
	score += float(npc.fame) * 0.3
	score += float(npc.respect) * 0.26
	score += float(npc.looks) * 0.16
	score += float(npc.smarts) * 0.12
	score += float(npc.satisfaction) * 0.08
	score += float(npc.mental_health) * 0.08
	return clamp(int(round(score)), 0, 100)


static func _relationship_hub_family_lane_has_members(ids: Array) -> bool:
	if typeof(ids) != TYPE_ARRAY:
		return false

	for raw_id in ids:
		if int(raw_id) > 0:
			return true

	return false


static func _world_feed_entry_is_desktop_world_tab_candidate(entry: Dictionary, current_year: int, min_recent_year: int) -> bool:
	if typeof(entry) != TYPE_DICTIONARY:
		return false

	var entry_year: int = int(entry.get("year", current_year))
	if entry_year >= min_recent_year:
		return true

	var category: String = str(entry.get("category", "")).strip_edges().to_lower()
	var event_name: String = str(entry.get("event_name", "")).strip_edges().to_lower()
	var text: String = str(entry.get("text", entry.get("display_text", ""))).strip_edges().to_lower()

	if bool(entry.get("personally_relevant", false)):
		return true

	if category == "bending":
		return true

	if event_name.find("bending") >= 0:
		return true

	if event_name.find("tournament") >= 0:
		return true

	if event_name.find("spawn") >= 0:
		return true

	if event_name.find("birth") >= 0:
		return true

	if text.find("bending") >= 0 and text.find("tournament") >= 0:
		return true

	return false


static func _prime_panel_transition_surface(surface: Control) -> void:
	if surface == null:
		return
	if not surface.has_meta("ui_panel_transition_base_position"):
		surface.set_meta("ui_panel_transition_base_position", surface.position)
	if not surface.has_meta("ui_panel_transition_base_scale"):
		surface.set_meta("ui_panel_transition_base_scale", surface.scale)
	surface.pivot_offset = surface.size * 0.5


static func _is_elemental_nation_name(nation_name: String) -> bool:
	match str(nation_name).strip_edges():
		"Fire Nation", "Earth Kingdom", "Water Tribe", "Northern Water Tribe", "Southern Water Tribe", "Air Nomads", "Northern Air Temple", "Southern Air Temple", "Eastern Air Temple", "Western Air Temple":
			return true
		_:
			return false


static func _main_tab_default_section_for_panel(panel_id: String) -> String:
	match str(panel_id).strip_edges().to_lower():
		"relationships":
			return "relationships"
		"career":
			return "full_time_jobs"
		"school":
			return "overview"
		"world":
			return "overview"
		"activities":
			return "activities"
		"mods":
			return "installed"
		_:
			return ""


static func _main_tab_panel_uses_native_zero_frame_door(panel_id: String) -> bool:
	var clean_panel: String = str(panel_id).strip_edges().to_lower()
	return clean_panel in ["world", "relationships", "career", "school", "activities", "mods"]


static func _get_person_display_name(person: Person) -> String:
	if person == null:
		return "Unknown Life"

	var first_name: String = str(person.first_name).strip_edges()
	var last_name: String = str(person.last_name).strip_edges()
	var full_name: String = ("%s %s" % [first_name, last_name]).strip_edges()

	if full_name == "" and person.has_method("_display_name"):
		full_name = str(person.call("_display_name")).strip_edges()

	if full_name == "":
		full_name = str(person.name).strip_edges()

	if full_name == "":
		var person_id: int = int(person.id)
		if person_id > 0:
			full_name = "Life #%d" % person_id

	if full_name == "":
		full_name = "Unknown Life"

	var royal_title: String = str(person.royal_title).strip_edges()
	if royal_title != "" and not full_name.begins_with(royal_title):
		full_name = ("%s %s" % [royal_title, full_name]).strip_edges()

	return full_name


static func _main_tab_label_for_panel(panel_id: String) -> String:
	match str(panel_id).strip_edges().to_lower():
		"life":
			return "LIFE / DIARY"
		"relationships":
			return "RELATIONSHIPS"
		"career":
			return "CAREER"
		"school":
			return "SCHOOL"
		"activities":
			return "ACTIVITIES"
		"world":
			return "WORLD"
		_:
			return "ERALIFE"


static func _main_tab_prewarm_surface_rows() -> Array:
	return [
		{
			"surface_id": "life_panel",
			"active_section_id": "",
			"context": {
				"main_tab": "life",
				"packet_contract_required": true,
				"click_path_must_not_build": true
			}
		},
		{
			"surface_id": "desktop_relationships_panel",
			"active_section_id": "relationships",
			"context": {
				"main_tab": "relationships",
				"packet_contract_required": true,
				"click_path_must_not_build": true
			}
		},
		{
			"surface_id": "desktop_career_panel",
			"active_section_id": "full_time_jobs",
			"context": {
				"main_tab": "career",
				"packet_contract_required": true,
				"click_path_must_not_build": true
			}
		},
		{
			"surface_id": "desktop_school_panel",
			"active_section_id": "overview",
			"context": {
				"main_tab": "school",
				"packet_contract_required": true,
				"click_path_must_not_build": true
			}
		},
		{
			"surface_id": "desktop_activities_panel",
			"active_section_id": "activities",
			"context": {
				"main_tab": "activities",
				"packet_contract_required": true,
				"click_path_must_not_build": true
			}
		},
		{
			"surface_id": "world_feed_panel",
			"active_section_id": "overview",
			"context": {
				"main_tab": "world",
				"packet_contract_required": true,
				"click_path_must_not_build": true
			}
		}
	]


static func _ui_packet_row_to_display_line(raw_row: Variant) -> String:
	if typeof(raw_row) != TYPE_DICTIONARY:
		return str(raw_row).strip_edges()

	var row: Dictionary = raw_row as Dictionary
	var title: String = str(row.get("title", row.get("label", row.get("name", row.get("id", ""))))).strip_edges()
	var description: String = str(row.get("description", row.get("text", row.get("summary", "")))).strip_edges()

	if title == "":
		return description
	if description == "":
		return title

	return "%s — %s" % [title, description]


static func _main_tab_uses_desktop_native_renderer(panel_id: String) -> bool:
	var clean_panel: String = str(panel_id).strip_edges().to_lower()

	match clean_panel:
		"life", "world", "relationships", "career", "school", "activities", "mods":
			return true
		_:
			return false


static func _main_tab_hot_surface_key(panel_id: String) -> String:
	return str(panel_id).strip_edges().to_lower()


static func _incarceration_context_for_actor(actor: Person) -> Dictionary:
	if actor == null:
		return {}

	if str(actor.current_context).strip_edges().to_lower() != "incarcerated":
		return {}

	if typeof(actor.incarceration_context) != TYPE_DICTIONARY:
		return {}

	return actor.incarceration_context.duplicate(true)


static func _incarceration_facility_title(context: Dictionary, tab_label: String) -> String:
	var facility: String = str(context.get("facility_type", context.get("facility_label", "Facility"))).strip_edges()
	var _era_name: String = str(context.get("era", "Unknown Era")).strip_edges()
	var security: String = str(context.get("security_level", "Low")).strip_edges()
	return "%s — %s • %s" % [tab_label, facility.to_upper(), security]


static func _incarceration_base_lines(context: Dictionary) -> Array:
	var sentence_years: int = int(context.get("sentence_years", 0))
	var years_remaining: int = int(context.get("years_remaining", sentence_years))
	var years_served: int = int(context.get("years_served", 0))
	var months_served: int = int(context.get("months_served", years_served * 12))

	return [
		"Facility: %s" % str(context.get("facility_type", context.get("facility_label", "Facility"))),
		"Era: %s" % str(context.get("era", "Unknown Era")),
		"Security Level: %s" % str(context.get("security_level", "Low")),
		"Sentence: %d year%s" % [sentence_years, "" if sentence_years == 1 else "s"],
		"Time Served: %d month%s" % [months_served, "" if months_served == 1 else "s"],
		"Years Remaining: %d" % years_remaining
	]


