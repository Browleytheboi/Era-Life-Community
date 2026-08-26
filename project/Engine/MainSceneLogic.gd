extends RefCounted
class_name MainSceneLogic

# Second extraction from MainScene.gd. These functions depend on nothing from the
# scene except the GameState, so `gs` is passed in explicitly instead of being read
# off the node. No $NodePath, no self, no signals, no meta, no consts, no other
# member variables. The set is closed under its own calls -- every function it calls
# is also in this file -- so nothing here can reach back into the scene.

static func _contract_tab_visual_theme(surface_id: String, _tab_id: String, active: bool, surface: Dictionary = {}) -> Dictionary:
	var surface_visual: Dictionary = MainSceneHelpers._contract_surface_visual_theme(surface, surface_id)
	var runtime_state: Dictionary = surface.get("runtime_state", {}) if typeof(surface.get("runtime_state", {})) == TYPE_DICTIONARY else {}
	var store_id: String = str(runtime_state.get("store_id", "")).strip_edges()
	var border: Color = Color(0.42, 0.56, 0.64, 0.3)
	var font: Color = Color(0.9, 1.0, 1.0, 1.0)
	var bg: Color = Color(0.03, 0.045, 0.065, 0.82)
	if surface_visual.has("border"):
		border = surface_visual.get("border")
	if surface_visual.has("title"):
		font = surface_visual.get("title")
	if surface_id == "restaurant_contract_hub":
		bg = Color(0.175, 0.085, 0.035, 0.94) if active else Color(0.07, 0.038, 0.024, 0.84)
		border = Color(1.0, 0.66, 0.24, 0.78) if active else Color(1.0, 0.46, 0.18, 0.34)
		font = Color(1.0, 0.94, 0.84, 1.0)
	elif surface_id == "food_contract_hub":
		if store_id == "basket_lane_market":
			bg = Color(0.158, 0.058, 0.076, 0.96) if active else Color(0.076, 0.032, 0.046, 0.86)
			border = Color(1.0, 0.56, 0.46, 0.82) if active else Color(0.86, 0.36, 0.38, 0.42)
			font = Color(1.0, 0.9, 0.88, 1.0)
		else:
			bg = Color(0.092, 0.075, 0.04, 0.94) if active else Color(0.035, 0.052, 0.04, 0.84)
			border = Color(1.0, 0.76, 0.24, 0.78) if active else Color(0.55, 0.72, 0.48, 0.38)
			font = Color(1.0, 0.92, 0.62, 1.0)
	return {
		"bg": bg,
		"border": border,
		"font": font
	}


static func _contract_row_visual_theme(surface_id: String, _section_id: String, row_dict: Dictionary = {}) -> Dictionary:
	var row_kind: String = str(row_dict.get("kind", "")).strip_edges().to_lower()
	var store_id: String = str(row_dict.get("store_id", "")).strip_edges()
	var restaurant_id: String = str(row_dict.get("restaurant_id", "")).strip_edges()
	var category: String = str(row_dict.get("category", "")).strip_edges().to_lower()
	var tier: String = str(row_dict.get("tier", "")).strip_edges().to_lower()
	var bg: Color = Color(0.04, 0.055, 0.075, 0.88)
	var border: Color = Color(0.46, 0.72, 0.78, 0.28)
	var font: Color = Color(0.94, 1.0, 1.0, 1.0)
	var description_font: Color = Color(0.7, 0.82, 0.86, 0.9)
	var border_width: int = 1
	var radius: int = 16
	var title_size: int = 16
	var pulse_glow: bool = false
	var pulse_tint: Color = Color(1.0, 1.0, 1.0, 1.0)
	var pulse_seconds: float = 0.82
	var orbit_color: Color = Color(0.0, 0.0, 0.0, 0.0)
	var orbit_seconds: float = 2.1

	if surface_id == "food_contract_hub":
		bg = Color(0.035, 0.05, 0.04, 0.92)
		border = Color(0.52, 0.74, 0.54, 0.42)
		font = Color(0.92, 1.0, 0.88, 1.0)
		description_font = Color(0.76, 0.88, 0.78, 0.92)
		match store_id:
			"basket_lane_market":
				bg = Color(0.11, 0.046, 0.06, 0.97)
				border = Color(1.0, 0.56, 0.46, 0.8)
				font = Color(1.0, 0.9, 0.88, 1.0)
				description_font = Color(1.0, 0.82, 0.8, 0.94)
				border_width = 2
			"goldleaf_grocers":
				bg = Color(0.07, 0.05, 0.024, 0.97)
				border = Color(1.0, 0.84, 0.34, 0.86)
				font = Color(1.0, 0.94, 0.72, 1.0)
				description_font = Color(0.98, 0.87, 0.62, 0.95)
				border_width = 2
			"nutripod_exchange":
				bg = Color(0.028, 0.058, 0.078, 0.96)
				border = Color(0.38, 0.95, 1.0, 0.76)
				font = Color(0.76, 1.0, 1.0, 1.0)
				description_font = Color(0.66, 0.9, 0.96, 0.94)
				border_width = 2

		if row_kind == "grocery_store_premium":
			radius = 22
			title_size = 19
		elif row_kind == "grocery_item":
			radius = 14
			title_size = 15
			var grocery_visual: Dictionary = MainSceneHelpers._grocery_item_contract_visual_profile(row_dict)
			if grocery_visual.has("bg"):
				bg = grocery_visual.get("bg")
			if grocery_visual.has("border"):
				border = grocery_visual.get("border")
			if grocery_visual.has("font"):
				font = grocery_visual.get("font")
			if grocery_visual.has("description_font"):
				description_font = grocery_visual.get("description_font")
			if grocery_visual.has("border_width"):
				border_width = int(grocery_visual.get("border_width", border_width))
			if grocery_visual.has("radius"):
				radius = int(grocery_visual.get("radius", radius))
			if grocery_visual.has("title_size"):
				title_size = int(grocery_visual.get("title_size", title_size))
			pulse_glow = bool(grocery_visual.get("pulse_glow", false))
			pulse_tint = grocery_visual.get("pulse_tint", pulse_tint)
			pulse_seconds = float(grocery_visual.get("pulse_seconds", pulse_seconds))
			orbit_color = grocery_visual.get("orbit_color", orbit_color)
			orbit_seconds = float(grocery_visual.get("orbit_seconds", orbit_seconds))
		elif row_kind == "grocery_aisle_carousel":
			radius = 20
			title_size = 24
			if store_id == "basket_lane_market":
				bg = Color(0.148, 0.056, 0.078, 0.97)
				border = Color(1.0, 0.62, 0.5, 0.86)
				font = Color(1.0, 0.92, 0.9, 1.0)
				description_font = Color(1.0, 0.84, 0.82, 0.94)
				border_width = 3
		elif row_kind == "grocery_inside_store_header":
			title_size = 18
			radius = 22
			if store_id == "basket_lane_market":
				bg = Color(0.126, 0.05, 0.066, 0.97)
				border = Color(1.0, 0.58, 0.48, 0.84)
				font = Color(1.0, 0.9, 0.88, 1.0)
				description_font = Color(1.0, 0.82, 0.8, 0.94)
				border_width = 3

	if surface_id == "restaurant_contract_hub":
		bg = Color(0.1, 0.05, 0.026, 0.94)
		border = Color(1.0, 0.56, 0.18, 0.48)
		font = Color(1.0, 0.94, 0.86, 1.0)
		description_font = Color(1.0, 0.8, 0.62, 0.92)
		if ["restaurant_intent", "restaurant_intent_partner", "restaurant_intent_find_date", "restaurant_intent_locked"].has(row_kind):
			bg = Color(0.15, 0.074, 0.032, 0.97)
			border = Color(1.0, 0.67, 0.28, 0.72)
			font = Color(1.0, 0.95, 0.88, 1.0)
			description_font = Color(1.0, 0.82, 0.66, 0.94)
			border_width = 2
			radius = 22
			title_size = 18
		elif row_kind == "restaurant_category":
			bg = Color(0.175, 0.084, 0.034, 0.96)
			border = Color(1.0, 0.72, 0.3, 0.68)
			border_width = 2
			radius = 20
			title_size = 18
		elif ["restaurant", "restaurant_selected"].has(row_kind):
			var key: String = restaurant_id
			if key == "":
				key = str(row_dict.get("label", "restaurant"))
			var palette_index: int = abs(int(hash(key))) % 4
			match palette_index:
				0:
					bg = Color(0.135, 0.048, 0.03, 0.96)
					border = Color(1.0, 0.45, 0.24, 0.7)
				1:
					bg = Color(0.115, 0.072, 0.03, 0.96)
					border = Color(1.0, 0.72, 0.28, 0.7)
				2:
					bg = Color(0.086, 0.045, 0.03, 0.96)
					border = Color(1.0, 0.88, 0.66, 0.64)
				_:
					bg = Color(0.15, 0.06, 0.02, 0.96)
					border = Color(1.0, 0.58, 0.14, 0.72)
			if category == "luxury" or tier.find("luxury") >= 0:
				border = Color(1.0, 0.84, 0.4, 0.86)
				font = Color(1.0, 0.95, 0.76, 1.0)
			elif category == "fast_food":
				border = Color(1.0, 0.38, 0.18, 0.8)
				font = Color(1.0, 0.9, 0.78, 1.0)
			if row_kind == "restaurant_selected":
				border_width = 3
				title_size = 18
			else:
				border_width = 2
				title_size = 17

	return {
		"bg": bg,
		"border": border,
		"font": font,
		"description_font": description_font,
		"border_width": border_width,
		"radius": radius,
		"title_size": title_size,
		"pulse_glow": pulse_glow,
		"pulse_tint": pulse_tint,
		"pulse_seconds": pulse_seconds,
		"orbit_color": orbit_color,
		"orbit_seconds": orbit_seconds
	}


static func _apply_contract_action_button_visual(button: Button, action: Dictionary, surface_id: String, section_id: String, row_context: Dictionary = {}, compact_contract_section: bool = false) -> void:
	if button == null or not is_instance_valid(button):
		return

	var action_id: String = str(action.get("id", action.get("action_id", ""))).strip_edges()
	var action_style: String = str(action.get("style", "")).strip_edges().to_lower()
	var row_store_id: String = str(row_context.get("store_id", "")).strip_edges()
	var row_visual: Dictionary = _contract_row_visual_theme(surface_id, section_id, row_context)
	var bg: Color = Color(0.06, 0.075, 0.085, 0.94)
	var border: Color = Color(0.66, 0.76, 0.78, 0.44)
	var font: Color = Color(0.94, 0.98, 0.98, 1.0)
	var glow: Color = Color(1.0, 1.0, 1.0, 0.32)
	var border_width: int = 1
	var radius: int = 15

	if row_visual.has("border"):
		border = row_visual.get("border")
	if row_visual.has("font"):
		font = row_visual.get("font")

	if surface_id == "food_contract_hub":
		bg = Color(0.045, 0.06, 0.05, 0.94)
		border = Color(0.78, 0.82, 0.74, 0.36)
		font = Color(0.91, 0.96, 0.9, 1.0)
		glow = Color(1.0, 1.0, 1.0, 0.42)

		var era_mart_context: bool = (
			action_id == "grocery_store:basket_lane_market"
			or row_store_id == "basket_lane_market"
			or action_id.begins_with("grocery_aisle:")
			or action_id == "grocery_done_browsing"
			or action_id == "grocery_back:aisles"
			or action_id == "grocery_back:stores"
		)

		if era_mart_context:
			bg = Color(0.138, 0.06, 0.076, 0.97)
			border = Color(1.0, 0.56, 0.46, 0.78)
			font = Color(1.0, 0.92, 0.88, 1.0)
			glow = Color(1.0, 0.72, 0.66, 0.48)
			border_width = 2
			radius = 18

		if action_id == "grocery_store:basket_lane_market":
			bg = Color(0.16, 0.064, 0.082, 0.98)
			border = Color(1.0, 0.6, 0.5, 0.84)
			font = Color(1.0, 0.92, 0.88, 1.0)
			border_width = 2
			radius = 18
		elif action_id == "grocery_store:goldleaf_grocers" or action_id.begins_with("grocery_goldleaf_membership"):
			bg = Color(0.085, 0.066, 0.038, 0.96)
			border = Color(0.94, 0.8, 0.46, 0.76)
			font = Color(0.98, 0.92, 0.72, 1.0)
			border_width = 2
			radius = 18
		elif action_id.begins_with("grocery_aisle:"):
			bg = Color(0.152, 0.064, 0.084, 0.98)
			border = Color(1.0, 0.64, 0.52, 0.86)
			font = Color(1.0, 0.94, 0.92, 1.0)
			glow = Color(1.0, 0.78, 0.72, 0.52)
			border_width = 2
			radius = 20
		elif action_id.begins_with("grocery_add"):
			if row_store_id == "basket_lane_market":
				bg = Color(0.13, 0.06, 0.072, 0.97)
				border = Color(1.0, 0.58, 0.48, 0.82)
				font = Color(1.0, 0.92, 0.9, 1.0)
				glow = Color(1.0, 0.74, 0.68, 0.52)
				border_width = 2
				radius = 16
			else:
				bg = Color(0.06, 0.07, 0.068, 0.95)
				border = Color(0.86, 0.88, 0.82, 0.58)
				font = Color(0.94, 0.96, 0.92, 1.0)
				border_width = 2
		elif action_style == "danger":
			bg = Color(0.095, 0.048, 0.046, 0.95)
			border = Color(0.9, 0.42, 0.36, 0.62)
			font = Color(0.98, 0.88, 0.84, 1.0)

	if surface_id == "restaurant_contract_hub":
		bg = Color(0.125, 0.072, 0.045, 0.95)
		border = Color(0.95, 0.66, 0.34, 0.58)
		font = Color(0.98, 0.92, 0.82, 1.0)
		glow = Color(1.0, 0.93, 0.76, 0.46)
		border_width = 2
		radius = 18
		if action_id.begins_with("restaurant_start") or action_id.begins_with("restaurant_category") or action_id.begins_with("restaurant_select"):
			bg = Color(0.145, 0.082, 0.045, 0.96)
			border = Color(0.98, 0.72, 0.4, 0.72)
			font = Color(0.99, 0.94, 0.86, 1.0)
		elif action_id.begins_with("restaurant_menu"):
			bg = Color(0.155, 0.09, 0.05, 0.96)
			border = Color(0.98, 0.76, 0.45, 0.74)
			font = Color(0.99, 0.95, 0.84, 1.0)
		elif action_style == "danger":
			bg = Color(0.12, 0.052, 0.038, 0.95)
			border = Color(0.92, 0.44, 0.34, 0.66)
			font = Color(0.99, 0.88, 0.82, 1.0)
		elif action_style == "secondary":
			bg = Color(0.09, 0.06, 0.045, 0.94)
			border = Color(0.92, 0.68, 0.45, 0.42)
			font = Color(0.98, 0.9, 0.78, 1.0)

	if compact_contract_section:
		radius = 12

	var normal_style: StyleBoxFlat = MainSceneHelpers._contract_make_stylebox(bg, border, border_width, radius)
	var hover_style: StyleBoxFlat = MainSceneHelpers._contract_make_stylebox(MainSceneHelpers._contract_brighten_color(bg, 0.035), glow, border_width + 1, radius)
	hover_style.shadow_color = glow
	hover_style.shadow_size = 8
	hover_style.shadow_offset = Vector2.ZERO

	var pressed_style: StyleBoxFlat = MainSceneHelpers._contract_make_stylebox(MainSceneHelpers._contract_darken_color(bg, 0.035), glow, border_width + 1, radius)
	pressed_style.shadow_color = glow
	pressed_style.shadow_size = 3
	pressed_style.shadow_offset = Vector2.ZERO

	var disabled_style: StyleBoxFlat = MainSceneHelpers._contract_make_stylebox(Color(bg.r, bg.g, bg.b, 0.45), Color(border.r, border.g, border.b, 0.2), border_width, radius)
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_stylebox_override("disabled", disabled_style)
	button.add_theme_color_override("font_color", font)
	button.add_theme_color_override("font_hover_color", Color(min(font.r + 0.04, 1.0), min(font.g + 0.04, 1.0), min(font.b + 0.04, 1.0), 1.0))
	button.add_theme_color_override("font_pressed_color", font)
	button.add_theme_color_override("font_disabled_color", Color(font.r, font.g, font.b, 0.45))
	if not compact_contract_section:
		button.add_theme_font_size_override("font_size", 14)
		button.custom_minimum_size = Vector2(0, 38)


static func _grocery_store_display_name_for_popup(gs: GameState,
	store_id: String) -> String:
	var clean_store_id: String = str(store_id).strip_edges()

	match clean_store_id:
		"basket_lane_market":
			return "EraMart"
		"goldleaf_grocers":
			return "Goldleaf"
		"nutripod_exchange":
			return "Nutripod Exchange"

	if gs != null and gs.grocery_store_engine != null and gs.grocery_store_engine.has_method("get_store"):
		var store: Dictionary = gs.grocery_store_engine.get_store(clean_store_id)
		var store_name: String = str(store.get("name", "")).strip_edges()
		if store_name != "":
			return store_name.replace("Era-Mart", "EraMart")

	if clean_store_id == "":
		return "Grocery Store"

	return clean_store_id.replace("_", " ").capitalize()


static func _append_stone_and_element_colored_text_to_rich_label(
	target_label: RichTextLabel,
	text: String,
	append_newline: bool = true
) -> void:
	if target_label == null:
		return

	var source_text: String = str(text)
	var phrase_variants: Array = [
		"4 Elements",
		"4 elements",
		"4 ELEMENTS"
	]

	var cursor: int = 0
	while cursor < source_text.length():
		var nearest_index: int = -1
		var nearest_phrase: String = ""

		for raw_phrase in phrase_variants:
			var phrase: String = str(raw_phrase)
			var found_index: int = source_text.find(phrase, cursor)
			if found_index == -1:
				continue
			if nearest_index == -1 or found_index < nearest_index:
				nearest_index = found_index
				nearest_phrase = phrase

		if nearest_index == -1:
			MainSceneHelpers._append_stone_colored_text_to_rich_label(
				target_label,
				source_text.substr(cursor),
				false
			)
			break

		if nearest_index > cursor:
			MainSceneHelpers._append_stone_colored_text_to_rich_label(
				target_label,
				source_text.substr(cursor, nearest_index - cursor),
				false
			)

		MainSceneHelpers._append_avatar_four_elements_phrase(target_label, nearest_phrase)
		cursor = nearest_index + nearest_phrase.length()

	if append_newline:
		target_label.append_text("\n")


static func _runtime_focus_navigation_enabled(gs: GameState) -> bool:
	if gs == null or typeof(gs.scenario_state) != TYPE_DICTIONARY:
		return false

	var guard_raw: Variant = gs.scenario_state.get("runtime_guard", {})
	var guard: Dictionary = guard_raw if typeof(guard_raw) == TYPE_DICTIONARY else {}

	if bool(guard.get("ui_focus_navigation_enabled", false)):
		return true

	var profile_raw: Variant = gs.scenario_state.get("runtime_capability_profile", {})
	var profile: Dictionary = profile_raw if typeof(profile_raw) == TYPE_DICTIONARY else {}

	var device_class: String = str(profile.get("device_class", "")).strip_edges().to_lower()
	var input_mode: String = str(profile.get("input_mode", "")).strip_edges().to_lower()

	return device_class == "smart_tv" or input_mode in ["focus_remote", "remote"]


static func _build_current_auto_preserve_path(gs: GameState) -> String:
	MainSceneHelpers._ensure_saved_lives_dir()

	if gs == null or gs.player == null:
		return "%s/autopreserve_current.bin" % MainSceneHelpers._saved_lives_dir()

	if typeof(gs.custom_settings) != TYPE_DICTIONARY:
		gs.custom_settings = {}

	var cached:= str(gs.custom_settings.get("_auto_preserve_slot_path", "")).strip_edges()
	if cached != "":
		return cached

	var player_name:= MainSceneHelpers._sanitize_save_slot_component("%s_%s" % [
		gs.player.first_name,
		gs.player.last_name
	])
	var birth_city:= MainSceneHelpers._sanitize_save_slot_component(str(gs.player.birth_city))
	var birth_country:= MainSceneHelpers._sanitize_save_slot_component(str(gs.player.birth_country))
	var birth_month:= int(gs.player.birthday.get("month", 1))
	var birth_day:= int(gs.player.birthday.get("day", 1))

	var slot_path:= "%s/%s_%s_%s_%02d_%02d_autopreserve.bin" % [
		MainSceneHelpers._saved_lives_dir(),
		player_name,
		birth_city,
		birth_country,
		birth_month,
		birth_day
	]

	gs.custom_settings ["_auto_preserve_slot_path"] = slot_path
	return slot_path


static func _spawn_ready_primary_birth_actor_id(gs: GameState) -> int:
	if gs == null or gs.player == null:
		return -1
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		return int(gs.player.id)

	var primary_id: int = int(gs.scenario_state.get("spawn_ready_primary_birth_actor_id", -1))
	if primary_id <= 0:
		primary_id = int(gs.scenario_state.get("birth_shell_player_id", -1))
	if primary_id <= 0:
		primary_id = int(gs.player.id)
		gs.scenario_state ["spawn_ready_primary_birth_actor_id"] = primary_id

	return primary_id


static func _spawn_ready_birth_intro_allowed_for_current_actor(gs: GameState) -> bool:
	if gs == null or gs.player == null:
		return false
	return int(gs.player.id) == _spawn_ready_primary_birth_actor_id(gs)


static func _rick_weapon_shop_hub_available_shell_safe(gs: GameState) -> bool:
	if gs == null or gs.player == null:
		return false
	if gs.awaiting_new_life:
		return false
	if gs.weapons_engine == null:
		return false

	if typeof(gs.scenario_state) == TYPE_DICTIONARY:
		var snapshot: Dictionary = MainSceneHelpers._safe_dictionary(gs.scenario_state.get("runtime_hud_visibility_snapshot", {}))
		if snapshot.has("rick_weapon_shop_available"):
			return bool(snapshot.get("rick_weapon_shop_available", false))

	return _rick_weapon_shop_hub_available(gs)


static func _save_load_reality_build_status_from_scheduler(gs: GameState) -> String:
	if gs == null or not gs.has_method("get_runtime_boot_scheduler_snapshot"):
		return "Reality is assembling..."

	var snapshot: Dictionary = gs.get_runtime_boot_scheduler_snapshot()
	var domain_states: Dictionary = snapshot.get("domain_states", {}) if typeof(snapshot.get("domain_states", {})) == TYPE_DICTIONARY else {}

	if domain_states.has("world"):
		var world_state: Dictionary = domain_states.get("world", {}) if typeof(domain_states.get("world", {})) == TYPE_DICTIONARY else {}
		var execution_state: String = str(world_state.get("execution_state", "")).strip_edges()
		if execution_state == "streaming":
			return str(world_state.get("player_status_text", "World hydration is streaming in the background."))

	return "Your playable shell is live."


static func _checkpoint_residency_signature_from_load_options(
	path: String,
	load_options: Dictionary
) -> String:
	var resume_contract: Dictionary = (
		MainSceneHelpers._checkpoint_resume_contract_from_load_options(
			load_options
		)
	)
	var continue_raw: Variant = load_options.get(
		"continue_contract",
		{}
	)
	var continue_contract: Dictionary = (
		continue_raw as Dictionary
		if typeof(continue_raw) == TYPE_DICTIONARY
		else {}
	)
	var life_summary_raw: Variant = continue_contract.get(
		"life_summary",
		{}
	)
	var life_summary: Dictionary = (
		life_summary_raw as Dictionary
		if typeof(life_summary_raw) == TYPE_DICTIONARY
		else {}
	)
	var candidates: Array = [
		load_options.get(
			"residency_signature",
			""
		),
		resume_contract.get(
			"residency_signature",
			""
		),
		continue_contract.get(
			"residency_signature",
			""
		),
		life_summary.get(
			"residency_signature",
			""
		)
	]

	for raw_candidate in candidates:
		var candidate: String = str(
			raw_candidate
		).strip_edges()

		if candidate != "":
			return candidate

	return MainSceneHelpers._saved_life_residency_signature(
		path
	)


static func _boxing_belt_visual_contract_for_title_label(title_label: String) -> Dictionary:
	var body: String = MainSceneHelpers._boxing_title_body_from_label(title_label)
	var visual: Dictionary = MainSceneHelpers._boxing_belt_visual_contract_for_body(body)
	visual ["title_label"] = str(title_label).strip_edges()
	return visual


static func _boxing_belt_visual_contracts_for_title_labels(title_labels: Array) -> Array:
	var visuals: Array = []
	var seen: Dictionary = {}

	for raw_label in title_labels:
		var label: String = str(raw_label).strip_edges()
		if label == "":
			continue

		var body: String = MainSceneHelpers._boxing_title_body_from_label(label)
		if body == "":
			body = label.to_upper()

		if seen.has(body):
			continue

		var visual: Dictionary = MainSceneHelpers._boxing_belt_visual_contract_for_body(body)
		visual ["title_label"] = label
		visuals.append(visual)
		seen [body] = true

	return visuals


static func _boxing_champion_belt_aura_contract(title_labels: Array, is_champion: bool, fame_value: int = 0) -> Dictionary:
	var visuals: Array = _boxing_belt_visual_contracts_for_title_labels(title_labels)
	var has_wbc: bool = false
	var has_wba: bool = false
	var has_ibf: bool = false
	var has_wbo: bool = false
	var primary_glows: Array = []
	var secondary_glows: Array = []
	var borders: Array = []
	var backgrounds: Array = []
	var tags: Array = []

	for raw_visual in visuals:
		if typeof(raw_visual) != TYPE_DICTIONARY:
			continue

		var visual: Dictionary = raw_visual
		var body: String = str(visual.get("body", "")).strip_edges().to_upper()

		match body:
			"WBC":
				has_wbc = true
			"WBA":
				has_wba = true
			"IBF":
				has_ibf = true
			"WBO":
				has_wbo = true

		if typeof(visual.get("glow_primary", null)) == TYPE_COLOR:
			primary_glows.append(visual.get("glow_primary"))
		if typeof(visual.get("glow_secondary", null)) == TYPE_COLOR:
			secondary_glows.append(visual.get("glow_secondary"))
		if typeof(visual.get("border", null)) == TYPE_COLOR:
			borders.append(visual.get("border"))
		if typeof(visual.get("bg", null)) == TYPE_COLOR:
			backgrounds.append(visual.get("bg"))

		var tag: String = str(visual.get("aura_tag", "")).strip_edges()
		if tag != "" and tag not in tags:
			tags.append(tag)

	var belt_count: int = visuals.size()
	var undisputed: bool = has_wbc and has_wba and has_ibf and has_wbo
	var hybrid_red_green: bool = has_wbc and has_wba
	var dark_gold_dominance: bool = has_wbo and has_ibf

	var fallback_bg: Color = Color(0.06, 0.046, 0.03, 0.96)
	var fallback_border: Color = Color(1.0, 0.86, 0.48, 0.94)
	var fallback_primary: Color = Color(1.0, 0.86, 0.58, 0.48)
	var fallback_secondary: Color = Color(1.0, 0.94, 0.74, 0.22)

	var bg: Color = MainSceneHelpers._boxing_blend_color_list(backgrounds, fallback_bg)
	var border: Color = MainSceneHelpers._boxing_blend_color_list(borders, fallback_border)
	var primary: Color = MainSceneHelpers._boxing_blend_color_list(primary_glows, fallback_primary)
	var secondary: Color = MainSceneHelpers._boxing_blend_color_list(secondary_glows, fallback_secondary)
	var title_text: Color = Color(1.0, 0.92, 0.62, 1.0)
	var aura_label: String = "Champion Aura"
	var pulse_speed: float = 0.74

	if undisputed:
		bg = Color(0.025, 0.018, 0.012, 0.98)
		border = Color(1.0, 0.92, 0.34, 1.0)
		primary = Color(0.32, 1.0, 0.43, 0.72)
		secondary = Color(1.0, 0.12, 0.1, 0.62)
		title_text = Color(1.0, 0.96, 0.7, 1.0)
		aura_label = "UNDISPUTED GOD ENERGY"
		pulse_speed = 1.12
	elif hybrid_red_green:
		bg = Color(0.07, 0.055, 0.038, 0.97)
		border = Color(0.82, 0.62, 0.26, 0.96)
		primary = Color(0.16, 1.0, 0.42, 0.62)
		secondary = Color(1.0, 0.08, 0.16, 0.5)
		title_text = Color(0.96, 1.0, 0.82, 1.0)
		aura_label = "Hybrid Champion Aura"
	elif dark_gold_dominance:
		bg = Color(0.014, 0.012, 0.012, 0.98)
		border = Color(1.0, 0.78, 0.22, 0.96)
		primary = Color(1.0, 0.76, 0.16, 0.58)
		secondary = Color(1.0, 0.08, 0.06, 0.44)
		title_text = Color(1.0, 0.9, 0.56, 1.0)
		aura_label = "Dark Gold Dominance"
	elif has_wbc:
		aura_label = "WBC Green Glow"
		title_text = Color(0.85, 1.0, 0.88, 1.0)
	elif has_wba:
		aura_label = "WBA Maroon Glow"
		title_text = Color(1.0, 0.86, 0.88, 1.0)
	elif has_wbo:
		aura_label = "WBO Black Gold Glow"
		title_text = Color(1.0, 0.89, 0.54, 1.0)
	elif has_ibf:
		aura_label = "IBF Gold Glow"
		title_text = Color(1.0, 0.94, 0.72, 1.0)

	var fame_boost: float = clamp(float(fame_value) / 260.0, 0.0, 0.38)
	var intensity: float = clamp(0.24 + float(belt_count) * 0.16 + fame_boost, 0.0, 1.0)

	return {
		"enabled": is_champion and belt_count > 0,
		"belt_count": belt_count,
		"is_undisputed": undisputed,
		"hybrid_red_green": hybrid_red_green,
		"dark_gold_dominance": dark_gold_dominance,
		"visuals": visuals,
		"tags": tags,
		"label": aura_label,
		"bg": bg,
		"border": border,
		"glow_primary": primary,
		"glow_secondary": secondary,
		"title_text": title_text,
		"intensity": intensity,
		"pulse_speed": pulse_speed,
		"shadow_size": 14 + int(float(belt_count) * 5.0) + (10 if undisputed else 0)
	}


static func _boxing_hub_fighter_card_style(_visual_contract: Dictionary, row: Dictionary) -> StyleBoxFlat:
	var is_champion: bool = bool(row.get("is_champion", false))
	var belt_count: int = max(0, int(row.get("belt_count", 0)))
	var fame_value: int = clamp(int(row.get("fame", 0)), 0, 100)
	var rank: int = int(row.get("rank", 99))
	var rank_heat: float = clamp(float(row.get("rank_heat", 0.0)), 0.0, 1.0)
	if rank > 0 and rank <= 5:
		rank_heat = max(rank_heat, clamp(float(6 - rank) / 5.0, 0.0, 1.0))

	var title_labels: Array = row.get("title_labels", []) if typeof(row.get("title_labels", [])) == TYPE_ARRAY else []
	var belt_aura: Dictionary = row.get("belt_aura", {}) if typeof(row.get("belt_aura", {})) == TYPE_DICTIONARY else {}
	if belt_aura.is_empty():
		belt_aura = _boxing_champion_belt_aura_contract(title_labels, is_champion, fame_value)

	var cream_glow: float = clamp(0.14 + float(belt_count) * 0.18 + float(fame_value) / 280.0 + rank_heat * 0.12, 0.0, 1.0)
	var style:= StyleBoxFlat.new()
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.content_margin_left = 10
	style.content_margin_top = 8
	style.content_margin_right = 10
	style.content_margin_bottom = 8
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1

	if is_champion:
		var intensity: float = clamp(float(belt_aura.get("intensity", cream_glow)), 0.0, 1.0)
		style.bg_color = belt_aura.get("bg", Color(0.24 + cream_glow * 0.18, 0.15 + cream_glow * 0.12, 0.055, 0.96))
		style.border_color = belt_aura.get("border", Color(1.0, 0.86, 0.48, 0.94))
		style.shadow_color = belt_aura.get("glow_primary", Color(1.0, 0.86, 0.58, 0.26 + cream_glow * 0.28))
		style.shadow_size = int(belt_aura.get("shadow_size", 14 + int(belt_count * 5)))

		if bool(belt_aura.get("is_undisputed", false)):
			style.border_width_left = 2
			style.border_width_top = 2
			style.border_width_right = 2
			style.border_width_bottom = 2
			style.shadow_size += int(8.0 * intensity)
	elif rank > 0 and rank <= 5:
		style.bg_color = Color(0.06 + rank_heat * 0.03, 0.07 + rank_heat * 0.035, 0.09 + rank_heat * 0.03, 0.92)
		style.border_color = Color(0.92, 0.82, 0.58, 0.42 + rank_heat * 0.22)
		style.shadow_color = Color(1.0, 0.88, 0.62, 0.16 + rank_heat * 0.14)
		style.shadow_size = 8 + int(rank_heat * 5.0)
	else:
		style.bg_color = Color(0.03, 0.04, 0.06, 0.9)
		style.border_color = Color(0.52, 0.62, 0.78, 0.34)
		style.shadow_color = Color(0.1, 0.14, 0.22, 0.16)
		style.shadow_size = 6

	return style


static func _boxing_hub_champion_title_caption_from_labels(title_labels: Array, division_text: String = "") -> String:
	var body_names: Array = []
	var weight_class: String = str(division_text).strip_edges()

	if weight_class.begins_with("Male "):
		weight_class = weight_class.substr(5).strip_edges()
	elif weight_class.begins_with("Female "):
		weight_class = weight_class.substr(7).strip_edges()

	for raw_label in title_labels:
		var title_label: String = str(raw_label).strip_edges()
		if title_label == "":
			continue

		var body: String = MainSceneHelpers._boxing_title_body_from_label(title_label)
		if body == "":
			continue

		var display_body: String = "Ring" if body == "RING" else body
		if display_body not in body_names:
			body_names.append(display_body)

		var clean_weight: String = title_label
		if body == "RING":
			clean_weight = clean_weight.replace("Ring Magazine Lineal", "")
			clean_weight = clean_weight.replace("Ring Magazine", "")
			clean_weight = clean_weight.replace("Lineal", "")
		else:
			clean_weight = clean_weight.replace(body, "")

		clean_weight = clean_weight.replace("Champion", "")
		clean_weight = clean_weight.replace("Champ", "")
		clean_weight = clean_weight.replace("Title", "")
		clean_weight = clean_weight.strip_edges()

		if clean_weight != "":
			weight_class = clean_weight

	if weight_class == "":
		return "Champion"

	if body_names.is_empty():
		return "%s Champion" % weight_class

	var suffix: String = "Champ" if body_names.size() == 1 else "Champion"
	return "%s %s %s" % [
		", ".join(body_names),
		weight_class,
		suffix
	]


static func _render_boxing_hub_fighter_card(parent: Control, row: Dictionary, visual_contract: Dictionary) -> void:
	if parent == null:
		return

	var is_champion: bool = bool(row.get("is_champion", false))
	var rank: int = int(row.get("rank", 99))
	var rank_heat: float = clamp(float(row.get("rank_heat", 0.0)), 0.0, 1.0)
	if rank > 0 and rank <= 5:
		rank_heat = max(rank_heat, clamp(float(6 - rank) / 5.0, 0.0, 1.0))

	var target_fame: float = clamp(float(row.get("fame", 0)), 0.0, 100.0)
	var title_labels: Array = row.get("title_labels", []) if typeof(row.get("title_labels", [])) == TYPE_ARRAY else []
	var belt_aura: Dictionary = row.get("belt_aura", {}) if typeof(row.get("belt_aura", {})) == TYPE_DICTIONARY else {}
	if belt_aura.is_empty():
		belt_aura = _boxing_champion_belt_aura_contract(title_labels, is_champion, int(target_fame))

	var belt_visuals: Array = row.get("belt_visuals", []) if typeof(row.get("belt_visuals", [])) == TYPE_ARRAY else []
	if belt_visuals.is_empty() and not title_labels.is_empty():
		belt_visuals = _boxing_belt_visual_contracts_for_title_labels(title_labels)

	var champion_title_caption: String = str(row.get("champion_title_caption", row.get("champion_aura_label", ""))).strip_edges()
	if champion_title_caption == "" and is_champion:
		champion_title_caption = _boxing_hub_champion_title_caption_from_labels(title_labels, str(row.get("division", "")))

	var card:= PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 176 if is_champion and not title_labels.is_empty() else 152)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _boxing_hub_fighter_card_style(visual_contract, row))
	parent.add_child(card)

	var margin:= MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)

	var box:= VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)

	var title:= Label.new()
	title.text = "%s%s" % [
		"🏆 " if is_champion else "",
		str(row.get("title", row.get("name", "Unknown Fighter")))
	]
	title.clip_text = true
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", belt_aura.get("title_text", Color(1.0, 0.92, 0.62, 1.0)) if is_champion else Color(0.93, 0.94, 0.98, 0.96))
	title.add_theme_color_override("font_shadow_color", belt_aura.get("glow_secondary", Color(0.0, 0.0, 0.0, 0.72)) if is_champion else Color(0.0, 0.0, 0.0, 0.54))
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 1)
	box.add_child(title)

	if is_champion and champion_title_caption != "":
		var aura_label:= Label.new()
		aura_label.text = champion_title_caption
		aura_label.clip_text = true
		aura_label.add_theme_font_size_override("font_size", 10)
		aura_label.add_theme_color_override("font_color", belt_aura.get("title_text", Color(1.0, 0.9, 0.58, 0.92)))
		aura_label.add_theme_color_override("font_shadow_color", belt_aura.get("glow_primary", Color(0.0, 0.0, 0.0, 0.66)))
		aura_label.add_theme_constant_override("shadow_offset_x", 1)
		aura_label.add_theme_constant_override("shadow_offset_y", 1)
		box.add_child(aura_label)

	var record:= Label.new()
	record.text = "%s • %s" % [
		str(row.get("division", "")),
		str(row.get("record_text", "0-0-0"))
	]
	record.clip_text = true
	record.add_theme_font_size_override("font_size", 11)
	record.add_theme_color_override("font_color", visual_contract.get("body_text", Color(0.92, 0.95, 1.0, 0.9)))
	box.add_child(record)

	if not title_labels.is_empty():
		var belt_icons: Array = []
		for raw_visual in belt_visuals:
			if typeof(raw_visual) != TYPE_DICTIONARY:
				continue

			var belt_visual: Dictionary = raw_visual
			var belt_icon: String = str(belt_visual.get("emoji", "")).strip_edges()
			if belt_icon != "":
				belt_icons.append(belt_icon)

		var belts_header:= Label.new()
		belts_header.text = "Titles: %s" % " ".join(belt_icons) if not belt_icons.is_empty() else "Titles:"
		belts_header.add_theme_font_size_override("font_size", 10)
		belts_header.add_theme_color_override("font_color", belt_aura.get("title_text", Color(1.0, 0.84, 0.46, 0.96)) if is_champion else Color(1.0, 0.84, 0.46, 0.96))
		box.add_child(belts_header)

		var belts_wrap:= HFlowContainer.new()
		belts_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		belts_wrap.add_theme_constant_override("h_separation", 5)
		belts_wrap.add_theme_constant_override("v_separation", 4)
		box.add_child(belts_wrap)

		for raw_title_label in title_labels:
			var title_label: String = str(raw_title_label).strip_edges()
			if title_label == "":
				continue

			var visual: Dictionary = _boxing_belt_visual_contract_for_title_label(title_label)

			var chip_outer:= PanelContainer.new()
			chip_outer.add_theme_stylebox_override("panel", MainSceneHelpers._boxing_belt_chip_style(visual, true))
			belts_wrap.add_child(chip_outer)

			var chip:= PanelContainer.new()
			chip.add_theme_stylebox_override("panel", MainSceneHelpers._boxing_belt_chip_style(visual, false))
			chip_outer.add_child(chip)

			var chip_margin:= MarginContainer.new()
			chip_margin.add_theme_constant_override("margin_left", 5)
			chip_margin.add_theme_constant_override("margin_top", 2)
			chip_margin.add_theme_constant_override("margin_right", 5)
			chip_margin.add_theme_constant_override("margin_bottom", 2)
			chip.add_child(chip_margin)

			var chip_label:= Label.new()
			chip_label.text = "%s %s" % [
				str(visual.get("emoji", "🏆")),
				title_label
			]
			chip_label.clip_text = true
			chip_label.add_theme_font_size_override("font_size", 10)
			chip_label.add_theme_color_override("font_color", visual.get("text", Color(1.0, 0.94, 0.76, 1.0)))
			chip_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.82))
			chip_label.add_theme_constant_override("shadow_offset_x", 1)
			chip_label.add_theme_constant_override("shadow_offset_y", 1)
			chip_margin.add_child(chip_label)

	var last_fight:= Label.new()
	last_fight.text = "Last: %s" % str(row.get("last_fight", "No recent fight."))
	last_fight.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	last_fight.add_theme_font_size_override("font_size", 11)
	last_fight.add_theme_color_override("font_color", visual_contract.get("muted_text", Color(0.8, 0.86, 1.0, 0.8)))
	box.add_child(last_fight)

	var fame_label:= Label.new()
	fame_label.text = "Fame"
	fame_label.add_theme_font_size_override("font_size", 10)
	fame_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.36, 0.94) if target_fame >= 30.0 else Color(1.0, 0.34, 0.3, 0.94))
	box.add_child(fame_label)

	var fame_wrap:= Control.new()
	fame_wrap.custom_minimum_size = Vector2(0, 15)
	fame_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(fame_wrap)

	var fame_bar:= ProgressBar.new()
	fame_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fame_bar.min_value = 0.0
	fame_bar.max_value = 100.0
	fame_bar.value = 0.0
	fame_bar.show_percentage = false
	fame_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fame_wrap.add_child(fame_bar)

	var back_style:= StyleBoxFlat.new()
	back_style.bg_color = Color(0.045, 0.04, 0.035, 0.96)
	back_style.corner_radius_top_left = 8
	back_style.corner_radius_top_right = 8
	back_style.corner_radius_bottom_left = 8
	back_style.corner_radius_bottom_right = 8

	var fill_style:= StyleBoxFlat.new()
	fill_style.bg_color = MainSceneHelpers._boxing_hub_fame_fill_color(target_fame, is_champion, rank_heat)
	fill_style.corner_radius_top_left = 8
	fill_style.corner_radius_top_right = 8
	fill_style.corner_radius_bottom_left = 8
	fill_style.corner_radius_bottom_right = 8

	fame_bar.add_theme_stylebox_override("background", back_style)
	fame_bar.add_theme_stylebox_override("fill", fill_style)

	var fame_number:= Label.new()
	fame_number.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fame_number.text = "%d/100" % int(round(target_fame))
	fame_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fame_number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fame_number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fame_number.add_theme_font_size_override("font_size", 9)
	fame_number.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.96))
	fame_number.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.78))
	fame_number.add_theme_constant_override("shadow_offset_x", 1)
	fame_number.add_theme_constant_override("shadow_offset_y", 1)
	fame_wrap.add_child(fame_number)

	var tween:= fame_bar.create_tween()
	tween.tween_property(fame_bar, "value", target_fame, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	if target_fame >= 75.0 or bool(belt_aura.get("is_undisputed", false)):
		var pulse:= fame_wrap.create_tween()
		pulse.set_loops()

		var pulse_color: Color = Color(1.0, 0.92, 0.58, 1.0) if target_fame >= 30.0 else Color(1.0, 0.34, 0.3, 1.0)
		var pulse_speed: float = float(belt_aura.get("pulse_speed", 0.48)) if is_champion else 0.48
		pulse_speed = clamp(pulse_speed, 0.34, 1.24)

		pulse.tween_property(fame_wrap, "modulate", pulse_color, pulse_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(fame_wrap, "modulate", Color(1.0, 1.0, 1.0, 1.0), pulse_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


static func _boxing_hub_panel_style(gs: GameState) -> StyleBoxFlat:
	var visual_contract: Dictionary = _boxing_hub_visual_contract(gs)
	var base: Color = visual_contract.get("panel", Color(0.045, 0.052, 0.075, 0.96))
	var accent: Color = visual_contract.get("accent", Color(1.0, 0.52, 0.2, 0.72))

	var sb:= StyleBoxFlat.new()
	sb.bg_color = base
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.54)
	sb.set_border_width_all(2)
	sb.corner_radius_top_left = 22
	sb.corner_radius_top_right = 22
	sb.corner_radius_bottom_left = 22
	sb.corner_radius_bottom_right = 22
	sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.18)
	sb.shadow_size = 22
	sb.shadow_offset = Vector2(0, 6)
	sb.content_margin_left = 14
	sb.content_margin_top = 14
	sb.content_margin_right = 14
	sb.content_margin_bottom = 14
	return sb


static func _boxing_hub_visual_contract(gs: GameState) -> Dictionary:
	var era_name: String = "Modern Era"
	if gs != null and gs.era != null:
		era_name = str(gs.era.name)

	var base: Color = Color(0.022, 0.024, 0.03, 0.99)
	var panel: Color = Color(0.04, 0.048, 0.062, 0.97)
	var accent: Color = Color(1.0, 0.56, 0.2, 1.0)
	var hot: Color = Color(1.0, 0.82, 0.38, 1.0)
	var title: Color = Color(1.0, 0.9, 0.66, 1.0)
	var body_text: Color = Color(0.96, 0.97, 1.0, 0.94)
	var muted_text: Color = Color(0.86, 0.9, 0.98, 0.8)

	match era_name:
		"Future Era":
			base = Color(0.004, 0.018, 0.03, 0.99)
			panel = Color(0.012, 0.04, 0.062, 0.97)
			accent = Color(0.36, 0.94, 1.0, 1.0)
			hot = Color(0.72, 1.0, 0.94, 1.0)
			title = Color(0.78, 1.0, 0.96, 1.0)
			body_text = Color(0.9, 0.98, 1.0, 0.94)
			muted_text = Color(0.74, 0.92, 1.0, 0.8)
		"Modern Era":
			base = Color(0.03, 0.026, 0.022, 0.99)
			panel = Color(0.055, 0.044, 0.036, 0.97)
			accent = Color(1.0, 0.56, 0.2, 1.0)
			hot = Color(1.0, 0.82, 0.38, 1.0)
			title = Color(1.0, 0.9, 0.66, 1.0)
			body_text = Color(0.98, 0.96, 0.92, 0.94)
			muted_text = Color(0.96, 0.88, 0.78, 0.8)
		_:
			base = Color(0.026, 0.024, 0.03, 0.99)
			panel = Color(0.044, 0.042, 0.054, 0.97)
			accent = Color(1.0, 0.58, 0.24, 1.0)
			hot = Color(1.0, 0.8, 0.38, 1.0)

	return {
		"era": era_name,
		"base": base,
		"panel": panel,
		"accent": accent,
		"hot": hot,
		"title": title,
		"body_text": body_text,
		"muted_text": muted_text,
		"shadow_accent": Color(accent.r, accent.g, accent.b, 0.48)
	}


static func _apply_action_result_choice_effects(gs: GameState,
	choice: Dictionary) -> void:
	if gs == null or gs.player == null:
		return

	var stat_deltas_raw: Variant = choice.get("stat_deltas", {})
	if typeof(stat_deltas_raw) != TYPE_DICTIONARY:
		return

	var stat_deltas: Dictionary = stat_deltas_raw
	for raw_key in stat_deltas.keys():
		var stat_key: String = str(raw_key).strip_edges()
		if stat_key == "":
			continue

		var before_value: float = float(gs.player.get(stat_key))
		var delta_value: float = float(stat_deltas.get(raw_key, 0.0))
		var after_value: float = before_value + delta_value

		match stat_key:
			"health":
				after_value = clamp(after_value, 0.0, 200.0)
			"mental_health", "satisfaction", "smarts", "looks", "fame":
				after_value = clamp(after_value, 0.0, 100.0)
			_:
				pass

		gs.player.set(stat_key, after_value)


static func _ensure_universal_switch_contract_engine(gs: GameState) -> void:
	if gs == null:
		return
	if gs.universal_switch_contract_engine == null:
		gs.universal_switch_contract_engine = UniversalSwitchContractEngine.new(gs)


static func _pending_situations_controlled_actor(gs: GameState) -> Person:
	if gs == null or gs.player == null:
		return null
	return gs.player


static func _pending_situations_controlled_actor_id(gs: GameState) -> int:
	var actor: Person = _pending_situations_controlled_actor(gs)
	if actor == null:
		return -1
	return int(actor.id)


static func _pending_situations_current_era_name(gs: GameState) -> String:
	if gs == null:
		return "Modern Era"

	if gs.era != null:
		var era_name: String = str(gs.era.name if "name" in gs.era else "").strip_edges()
		if era_name != "":
			return era_name

	var era_text: String = str(gs.get("era_name") if "era_name" in gs else "").strip_edges()
	if era_text != "":
		return era_text

	return "Modern Era"


static func _pending_situation_result_diary_text_from_result(result: Dictionary) -> String:
	if typeof(result) != TYPE_DICTIONARY:
		return ""

	var candidate_keys: Array = [
		"life_diary_text",
		"diary_text",
		"text",
		"popup_text"
	]

	for raw_key in candidate_keys:
		var key: String = str(raw_key)
		var candidate: String = str(result.get(key, "")).strip_edges()
		if candidate == "":
			continue

		candidate = candidate.replace("Tap anywhere to continue.", "").strip_edges()
		candidate = candidate.replace("Tap to continue.", "").strip_edges()
		candidate = _clean_pending_situation_diary_text(candidate)

		if candidate != "":
			return candidate

	return ""


static func _clean_pending_situation_diary_text(text: String) -> String:
	var clean_text: String = MainSceneHelpers._compact_diary_text(str(text).strip_edges())
	if clean_text == "":
		return ""

	if clean_text == "----------------------":
		return clean_text

	if clean_text.begins_with("Year: ") or clean_text.begins_with("Age: "):
		return clean_text

	if not clean_text.ends_with("!") and not clean_text.ends_with(".") and not clean_text.ends_with("?"):
		clean_text += "."

	return clean_text


static func _pending_situation_diary_fingerprint(text: String) -> String:
	var clean_text: String = _clean_pending_situation_diary_text(text).to_lower()
	if clean_text == "":
		return ""

	clean_text = clean_text.replace(" i hated how much it still mattered.", "")
	clean_text = clean_text.replace(" i barely knew what to feel.", "")
	clean_text = clean_text.replace(" somehow, i still felt like this would not be the end of my story.", "")
	clean_text = clean_text.replace(" i tried to understand it through faith.", "")
	clean_text = clean_text.strip_edges()

	if clean_text == "":
		return ""

	return "pending_situation_diary:%s" % clean_text


static func _pending_situation_diary_line_exists_in_entries(entries: Array, text: String) -> bool:
	var clean_text: String = _clean_pending_situation_diary_text(text)
	if clean_text == "":
		return true

	var fingerprint: String = _pending_situation_diary_fingerprint(clean_text)

	for raw_entry in entries:
		if typeof(raw_entry) != TYPE_ARRAY:
			continue

		var entry: Array = raw_entry as Array
		for raw_line in entry:
			var existing_text: String = _clean_pending_situation_diary_text(str(raw_line))
			if existing_text == "":
				continue

			if existing_text == clean_text:
				return true

			if fingerprint != "" and _pending_situation_diary_fingerprint(existing_text) == fingerprint:
				return true

	return false


static func _pending_situation_diary_fingerprints_from_entries(entries: Array, existing_fingerprints: Array = []) -> Array:
	var out: Array = []

	for raw_fingerprint in existing_fingerprints:
		var fingerprint: String = str(raw_fingerprint).strip_edges()
		if fingerprint != "" and fingerprint not in out:
			out.append(fingerprint)

	for raw_entry in entries:
		if typeof(raw_entry) != TYPE_ARRAY:
			continue

		var entry: Array = raw_entry as Array
		for raw_line in entry:
			var line_text: String = str(raw_line).strip_edges()
			if line_text == "":
				continue

			var fingerprint: String = _pending_situation_diary_fingerprint(line_text)
			if fingerprint != "" and fingerprint not in out:
				out.append(fingerprint)

	return out


static func _pending_situation_bank_report_from_result(result: Dictionary) -> Dictionary:
	if typeof(result) != TYPE_DICTIONARY:
		return {}

	var direct: Dictionary = MainSceneHelpers._safe_dictionary(result.get("bank_report", {}))
	if not direct.is_empty():
		return direct

	var money_direct: Dictionary = MainSceneHelpers._safe_dictionary(result.get("money_delta_report", {}))
	if not money_direct.is_empty():
		return money_direct

	var resolution_report: Dictionary = MainSceneHelpers._safe_dictionary(result.get("resolution_report", {}))
	var nested_bank: Dictionary = MainSceneHelpers._safe_dictionary(resolution_report.get("bank_report", {}))
	if not nested_bank.is_empty():
		return nested_bank

	var nested_money: Dictionary = MainSceneHelpers._safe_dictionary(resolution_report.get("money_delta_report", {}))
	if not nested_money.is_empty():
		return nested_money

	return {}


static func _pending_situation_actor_by_id(gs: GameState,
	actor_id: int) -> Person:
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


static func _build_reality_surge_panel_style(theme_id: String, phase: int = 0) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	var clean_theme: String = str(theme_id).strip_edges().to_lower()
	var border: Color = MainSceneHelpers._reality_surge_color(clean_theme, phase)
	var dark: Color = _reality_surge_dark_color(clean_theme, phase)

	style.bg_color = dark
	style.border_color = border
	style.border_width_left = 5
	style.border_width_top = 5
	style.border_width_right = 5
	style.border_width_bottom = 5
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.shadow_color = Color(border.r, border.g, border.b, 0.55)
	style.shadow_size = 22
	style.shadow_offset = Vector2.ZERO
	style.content_margin_left = 24
	style.content_margin_top = 22
	style.content_margin_right = 24
	style.content_margin_bottom = 22

	return style


static func _reality_surge_dark_color(theme_id: String, phase: int = 0) -> Color:
	var glow: Color = MainSceneHelpers._reality_surge_color(theme_id, phase)
	return Color(
		clamp(glow.r * 0.16, 0.03, 0.2),
		clamp(glow.g * 0.14, 0.03, 0.2),
		clamp(glow.b * 0.14, 0.04, 0.22),
		0.96
	)


static func _apply_afterlife_panel_visual_state(panel: PanelContainer, is_hovered: bool) -> void:
	if panel == null:
		return
	panel.add_theme_stylebox_override("panel", MainSceneHelpers._build_afterlife_panel_style(is_hovered))


static func _clear_dictionary_property_if_present(target: Object, property_name: String) -> void:
	if target == null:
		return
	if not MainSceneHelpers._object_has_script_property(target, property_name):
		return

	var value: Variant = target.get(property_name)
	if typeof(value) == TYPE_DICTIONARY:
		(value as Dictionary).clear()
		target.set(property_name, value)
	else:
		target.set(property_name, {})


static func _clear_array_property_if_present(target: Object, property_name: String) -> void:
	if target == null:
		return
	if not MainSceneHelpers._object_has_script_property(target, property_name):
		return

	var value: Variant = target.get(property_name)
	if typeof(value) == TYPE_ARRAY:
		(value as Array).clear()
		target.set(property_name, value)
	else:
		target.set(property_name, [])


static func _reset_transient_engine_for_menu_return(engine: Object) -> void:
	if engine == null:
		return

	if engine.has_method("stop_grocery_store_realtime_session"):
		engine.call("stop_grocery_store_realtime_session", "")

	for property_name in [
		"active_runtime_contracts",
		"runtime_contract_index",
		"runtime_contract_observations",
		"public_space_sessions",
		"actor_public_space_sessions",
		"runtime_contract_public_space_keys",
		"movie_theater_sessions_by_actor_id",
		"restaurant_carts_by_actor_id",
		"restaurant_date_state_by_actor_id",
		"restaurant_public_sessions_by_restaurant_id",
		"grocery_carts_by_actor_id",
		"grocery_shopper_sessions_by_store_id",
		"grocery_store_worker_sessions_by_store_id",
		"grocery_self_checkout_sessions_by_actor_id",
		"cached_runtime_rows_by_actor_id",
		"active_sessions",
		"sessions_by_actor_id",
		"last_report"
	]:
		_clear_dictionary_property_if_present(engine, property_name)

	for property_name in [
		"runtime_contract_mutation_log",
		"visit_ledger",
		"grocery_ledger"
	]:
		_clear_array_property_if_present(engine, property_name)

	if engine.has_method("reset_runtime"):
		engine.call("reset_runtime")


static func _activity_group_for_label(gs: GameState,
	action_label: String) -> String:
	if _activity_label_is_pet_shop_label(gs, action_label):
		return "Companions"

	if _activity_label_is_meat_market_label(gs, action_label):
		return "Markets & Assets"

	if action_label in [
		"Trade On The Silk Road",
		"Look For Property",
		"Look For Vehicles",
		"Browse Property Market",
		"Browse Vehicle Market",
		"Review Estates",
		"Manage Holdings",
		"Open To Tenants",
		"Manage Fleet",
		"Assign Driver",
		"Assign Captain",
		"Artifact Shop",
		"View Assets"
	]:
		return "Markets & Assets"

	if action_label in [
		"Start School",
		"Enroll In Era School",
		"Enroll In Bending School",
		"Dual Enrollment",
		"Interact With Classmates"
	]:
		return "School & Youth"

	if action_label in [
		"Feed",
		"Use Blood Bag",
		"Glamour Target",
		"Join Coven",
		"Found Coven",
		"Seek Cure",
		"Turn Someone",
		"Blood Bond",
		"Investigate Vampire Rumors",
		"Ask To Be Turned",
		"Forge Gauntlet",
		"Become A Super Hero"
	]:
		return "Supernatural"

	if action_label in [
		"Migrate Somewhere",
		"Go to the movies",
		"Go To The Movies"
	]:
		return "Public Life"

	match action_label:
		"Begin Boxing":
			return "Featured"

		_:
			return "Miscellaneous"


static func _activities_current_controlled_actor(gs: GameState,
	
	fallback_actor: Person = null
) -> Person:
	if gs != null and gs.player != null:
		return gs.player

	return fallback_actor


static func _market_surface_contract_is_renderable(
	surface_contract: Dictionary,
	market_kind: String
) -> bool:
	if surface_contract.is_empty():
		return false

	if not bool(
		surface_contract.get(
			"success",
			false
		)
	):
		return false

	var truth_state: String = str(
		surface_contract.get(
			"truth_state",
			""
		)
	).strip_edges().to_lower()

	if truth_state in [
		"",
		"observable_partial",
		"observable_shell",
		"resolving",
		"cold",
		"missing_surface_contract"
	]:
		return false

	if bool(
		surface_contract.get(
			"crr_fallback",
			false
		)
	):
		return false

	var listing_cards: Array = MainSceneHelpers._safe_array(
		surface_contract.get(
			"listing_card_contracts",
			[]
		)
	)
	var clean_market_kind: String = str(
		market_kind
	).strip_edges().to_lower()
	var surface_mode: String = str(
		surface_contract.get(
			"surface_mode",
			""
		)
	).strip_edges().to_lower()

	for raw_card in listing_cards:
		var card: Dictionary = MainSceneHelpers._safe_dictionary(
			raw_card
		)

		if card.is_empty():
			return false

		if bool(
			card.get(
				"crr_placeholder_card",
				false
			)
		):
			return false

		if str(
			card.get(
				"truth_state",
				""
			)
		).strip_edges().to_lower() in [
			"observable_partial",
			"resolving",
			"cold"
		]:
			return false

		if str(
			card.get(
				"availability",
				""
			)
		).strip_edges().to_lower() == "resolving":
			return false

	if clean_market_kind == "property":
		return not listing_cards.is_empty()

	if clean_market_kind == "vehicle":
		var dealerships: Array = MainSceneHelpers._safe_array(
			surface_contract.get(
				"dealership_contracts",
				[]
			)
		)

		if surface_mode == "dealership_selector":
			return not dealerships.is_empty()

		return not listing_cards.is_empty()

	return not listing_cards.is_empty()


static func _market_surface_contract_is_authoritatively_hot(
	surface_contract: Dictionary,
	market_kind: String
) -> bool:
	if not _market_surface_contract_is_renderable(
		surface_contract,
		market_kind
	):
		return false

	if not bool(
		surface_contract.get(
			"success",
			false
		)
	):
		return false

	var truth_state: String = str(
		surface_contract.get(
			"truth_state",
			""
		)
	).strip_edges().to_lower()

	return truth_state not in [
		"",
		"observable_partial",
		"missing_surface_contract",
		"resolving",
		"cold"
	]


static func _observable_asset_market_surface_contract(gs: GameState,
	
	target_actor: Person,
	market_kind: String,
	status_text: String = ""
) -> Dictionary:
	var clean_market_kind: String = str(
		market_kind
	).strip_edges().to_lower()
	var is_property_market: bool = (
		clean_market_kind == "property"
	)
	var actor_id: int = (
		int(target_actor.id)
		if target_actor != null
		else -1
	)
	var era_name: String = (
		str(gs.era.name)
		if gs != null and gs.era != null
		else "Unknown"
	)
	var year_value: int = (
		int(gs.year)
		if gs != null
		else 0
	)
	var market_label: String = (
		"PROPERTY MARKET"
		if is_property_market
		else "VEHICLE MARKET"
	)
	var clean_status: String = str(
		status_text
	).strip_edges()

	if clean_status == "":
		clean_status = (
			"%s contracts are publishing live for %s."
			% [
				(
					"Property"
					if is_property_market
					else "Vehicle and dealership"
				),
				era_name
			]
		)



	return {
		"success": false,
		"schema": (
			"eralife.market.property_market.surface_contract"
			if is_property_market
			else "eralife.market.vehicle_market.surface_contract"
		),
		"version": 1,
		"actor_id": actor_id,
		"surface_mode": (
			"inventory"
			if is_property_market
			else "dealership_selector"
		),
		"title": market_label,
		"subtitle": (
			"Authoritative %s market truth is publishing."
			% clean_market_kind
		),
		"era": era_name,
		"market_year": year_value,
		"status_text": clean_status,
		"listing_card_contracts": [],
		"listing_count": 0,
		"filter_contracts": [],
		"dealership_contracts": [],
		"truth_state": "observable_partial",
		"surface_signature": (
			"observable_market_shell|%s|%d|%d"
			% [
				clean_market_kind,
				actor_id,
				year_value
			]
		),
		"crr_fallback": true,
		"retired_fake_generic_market_surface": true,
		"catalog_authority": "",
		"authoritative_market_surface_required": true,
		"generic_resident_market_fallback_forbidden": true,
		"blank_surface_impossible": true,
		"visible_click_work_required": false,
		"visible_click_work_forbidden": true,
		"ready_gate_member": false,
		"ui_is_renderer_only": true,
		"created_at_ms": int(
			Time.get_ticks_msec()
		)
	}


static func _vehicle_market_contract_has_renderable_surface(
	contract: Dictionary
) -> bool:
	if contract.is_empty():
		return false

	var cards: Array = MainSceneHelpers._safe_array(
		contract.get(
			"listing_card_contracts",
			[]
		)
	)

	if not cards.is_empty():
		return true

	if str(
		contract.get(
			"surface_mode",
			""
		)
	) == "dealership_selector":
		return not MainSceneHelpers._safe_array(
			contract.get(
				"dealership_contracts",
				[]
			)
		).is_empty()

	return false


static func _global_intent_current_actor_id(gs: GameState) -> int:
	if gs == null:
		return -1
	if gs.player != null:
		return int(gs.player.id)
	if "player_id" in gs:
		return int(gs.player_id)
	return -1


static func _career_coworker_group_label(gs: GameState,
	coworker: Person) -> String:
	if coworker == null or gs == null or gs.player == null:
		return "Workplace Team"

	var workplace_id: String = str(coworker.current_workplace_id).strip_edges()
	if gs.workplace_engine != null and workplace_id != "":
		var meta_value = gs.workplace_engine.workplace_meta.get(workplace_id, {})
		if typeof(meta_value) == TYPE_DICTIONARY:
			var meta: Dictionary = meta_value
			var department: String = str(meta.get("department", "")).strip_edges()
			if department != "":
				return department

	if coworker.id in gs.player.friends:
		return "Work Friends"

	var relation_score: int = _relationship_score_for_target(gs, coworker)
	if relation_score <= 35:
		return "Workplace Rivals"
	if int(coworker.job_performance) >= 80:
		return "High Performers"
	if int(coworker.job_performance) <= 35:
		return "Needs Support"
	return "Workplace Team"


static func _career_coworker_marker_suffix(gs: GameState,
	coworker: Person) -> String:
	if coworker == null:
		return "Coworker"

	var tags: Array = []
	var role_text: String = str(coworker.job).strip_edges()
	if role_text != "":
		tags.append(role_text)

	if gs != null and gs.player != null:
		if coworker.id in gs.player.friends:
			tags.append("Friend")
		else:
			var relation_score: int = _relationship_score_for_target(gs, coworker)
			if relation_score <= 35:
				tags.append("Rival")
			elif relation_score >= 70:
				tags.append("Trusted")

	if int(coworker.job_performance) >= 80:
		tags.append("High Perf")
	elif int(coworker.job_performance) <= 35:
		tags.append("Low Perf")

	if tags.is_empty():
		return "Coworker"
	return " • ".join(tags)


static func _nearby_switch_is_immediate_household_member(gs: GameState,
	npc: Person) -> bool:
	if gs == null or gs.player == null or npc == null:
		return false

	var player: Person = gs.player
	var npc_id: int = int(npc.id)

	if MainSceneHelpers._safe_array(player.parents).has(npc_id):
		return true
	if MainSceneHelpers._safe_array(player.children).has(npc_id):
		return true
	if player.partner != null and int(player.partner.id) == npc_id:
		return true

	for raw_parent_id in MainSceneHelpers._safe_array(player.parents):
		var parent: Person = gs.get_or_reactivate_npc_by_id(int(raw_parent_id))
		if parent == null:
			continue
		if MainSceneHelpers._safe_array(parent.children).has(npc_id):
			return true

	return false


static func _nearby_switch_is_family_member(gs: GameState,
	npc: Person) -> bool:
	if gs == null or gs.player == null or npc == null:
		return false

	var player: Person = gs.player
	var npc_id: int = int(npc.id)

	if _nearby_switch_is_immediate_household_member(gs, npc):
		return true

	if MainSceneHelpers._safe_array(npc.children).has(int(player.id)):
		return true
	if MainSceneHelpers._safe_array(player.children).has(npc_id):
		return true
	if MainSceneHelpers._safe_array(player.parents).has(npc_id):
		return true
	if MainSceneHelpers._safe_array(npc.parents).has(int(player.id)):
		return true

	for raw_parent_id in MainSceneHelpers._safe_array(player.parents):
		var parent: Person = gs.get_or_reactivate_npc_by_id(int(raw_parent_id))
		if parent == null:
			continue
		if MainSceneHelpers._safe_array(parent.parents).has(npc_id):
			return true
		if MainSceneHelpers._safe_array(parent.children).has(npc_id):
			return true

	for raw_child_id in MainSceneHelpers._safe_array(player.children):
		var child: Person = gs.get_or_reactivate_npc_by_id(int(raw_child_id))
		if child == null:
			continue
		if MainSceneHelpers._safe_array(child.children).has(npc_id):
			return true

	return false


static func _nearby_switch_contract_distance_to_player(gs: GameState,
	npc: Person) -> int:
	if gs == null or gs.player == null or npc == null:
		return 999999

	if _nearby_switch_is_immediate_household_member(gs, npc):
		return 0

	var player_city: String = _person_contract_city(gs.player)
	var npc_city: String = _person_contract_city(npc)
	var player_country: String = _person_contract_country(gs.player)
	var npc_country: String = _person_contract_country(npc)

	if player_city != "" and npc_city != "" and player_city == npc_city:
		return 1 + int(abs(hash("neighbor|%s|%s" % [str(gs.player.id), str(npc.id)])) % 5)

	if player_country != "" and npc_country != "" and player_country == npc_country:
		if gs.has_method("_world_distance_to_player"):
			return max(6, int(gs._world_distance_to_player(npc)))
		return 6 + int(abs(hash("local|%s|%s" % [str(gs.player.id), str(npc.id)])) % 45)

	if gs.has_method("_world_distance_to_player"):
		return int(gs._world_distance_to_player(npc))

	return 999999


static func _person_contract_country(person: Person) -> String:
	return MainSceneHelpers._person_contract_value(person, [
		"current_country",
		"country",
		"home_country",
		"birth_country",
		"realm_country",
		"nation"
	], "")


static func _person_contract_city(person: Person) -> String:
	return MainSceneHelpers._person_contract_value(person, [
		"current_city",
		"city",
		"home_city",
		"birth_city",
		"settlement",
		"location"
	], "")


static func _other_country_elemental_definite_name(place_name: String, uppercase: bool = false) -> String:
	var clean_name: String = str(place_name).strip_edges()
	if clean_name == "":
		return ""
	var lower_name: String = clean_name.to_lower()
	var out: String = clean_name
	if MainSceneHelpers._other_country_elemental_needs_definite_article(clean_name):
		out = "the %s" % clean_name
	elif lower_name.begins_with("the "):
		out = clean_name
	if uppercase:
		return out.to_upper()
	return out


static func _other_country_elemental_surface_origin_name(realm: Dictionary, entry: Dictionary = {}) -> String:
	if typeof(realm) != TYPE_DICTIONARY:
		return ""
	var candidates: Array = [
		str(realm.get("name", "")).strip_edges(),
		str(realm.get("country", "")).strip_edges(),
		str(entry.get("name", "")).strip_edges()
	]
	for raw_candidate in candidates:
		var candidate: String = str(raw_candidate).strip_edges()
		if candidate == "":
			continue
		if MainSceneHelpers._other_country_elemental_needs_definite_article(candidate):
			return candidate
	return ""


static func _other_country_browser_reality_mode_key(gs: GameState) -> String:
	if gs == null:
		return "unknown"

	var mode_key: String = str(gs.reality_mode).strip_edges().to_lower()
	if typeof(gs.custom_settings) == TYPE_DICTIONARY:
		mode_key = str(gs.custom_settings.get("reality_mode", mode_key)).strip_edges().to_lower()

	if mode_key == "":
		mode_key = "chaos"

	return mode_key


static func _other_country_browser_feature_enabled(gs: GameState,
	feature_key: String) -> bool:
	if gs == null:
		return false

	if gs.has_method("is_feature_enabled"):
		return bool(gs.is_feature_enabled(feature_key))

	if typeof(gs.custom_settings) == TYPE_DICTIONARY:
		var overrides_raw: Variant = gs.custom_settings.get("feature_overrides", {})
		var overrides: Dictionary = overrides_raw if typeof(overrides_raw) == TYPE_DICTIONARY else {}
		if overrides.has(feature_key):
			return bool(overrides.get(feature_key, false))

	return true


static func _other_country_browser_allows_elemental_surfaces(gs: GameState) -> bool:
	if _other_country_browser_reality_mode_key(gs) == "realistic":
		return false
	return _other_country_browser_feature_enabled(gs, "bending")


static func _other_country_browser_allows_many_realms_surfaces(gs: GameState) -> bool:
	if _other_country_browser_reality_mode_key(gs) == "realistic":
		return false
	return _other_country_browser_feature_enabled(gs, "many_realms")


static func _other_country_player_presence(gs: GameState,
	entry: Dictionary, realm: Dictionary) -> Dictionary:
	var out:= {
		"lives_here": false,
		"rules_here": false,
		"is_current_place": false,
		"label": ""
	}

	if gs == null or gs.player == null:
		return out

	var p: Person = gs.player
	var entry_name: String = str(entry.get("name", realm.get("name", ""))).strip_edges()
	var entry_kind: String = str(entry.get("entry_kind", "")).strip_edges().to_lower()

	var home_country: String = str(p.home_country).strip_edges()
	if home_country == "":
		home_country = str(p.birth_country).strip_edges()

	var player_home_key: String = MainSceneHelpers._other_country_identity_key(home_country)
	var entry_name_key: String = MainSceneHelpers._other_country_identity_key(entry_name)
	var realm_name_key: String = MainSceneHelpers._other_country_identity_key(str(realm.get("name", entry_name)))
	var realm_country_key: String = MainSceneHelpers._other_country_identity_key(str(realm.get("country", entry_name)))

	var lives_here: bool = false
	if home_country != "":
		lives_here = player_home_key == entry_name_key \
or player_home_key == realm_name_key \
or player_home_key == realm_country_key

	var resolved_realm_id: int = _resolve_existing_realm_id_for_other_country_population_entry(gs, entry)
	var entry_is_real_realm: bool = entry_kind == "realm" or entry_kind == "hidden_realm"
	var entry_is_country_shell: bool = entry_kind == "country"

	if not lives_here and entry_is_real_realm and resolved_realm_id > 0 and int(p.realm_id) == resolved_realm_id:
		lives_here = true

	if not lives_here and not entry_is_country_shell:
		var entry_realm_id: int = int(entry.get("realm_id", realm.get("realm_id", realm.get("id", 0))))
		if entry_realm_id > 0 and int(p.realm_id) == entry_realm_id:
			lives_here = true

	var us_realm_id: int = -1
	if typeof(gs.scenario_state) == TYPE_DICTIONARY:
		us_realm_id = int(gs.scenario_state.get("presidential_parent_contract_us_realm_id", -1))

	if not lives_here and _other_country_surface_is_united_states(gs, entry, realm):
		if us_realm_id > 0 and int(p.realm_id) == us_realm_id:
			lives_here = true
		elif player_home_key in ["usa", "us", "unitedstates", "unitedstatesofamerica", "america"]:
			lives_here = true

	var rules_here: bool = false
	var raw_ruler = realm.get("ruler_id", realm.get("leader_id", realm.get("president_person_id", 0)))

	if int(raw_ruler) > 0 and int(raw_ruler) == int(p.id):
		rules_here = true

	if not rules_here and bool(p.is_ruler):
		if lives_here:
			rules_here = true
		elif entry_is_real_realm and resolved_realm_id > 0 and int(p.realm_id) == resolved_realm_id:
			rules_here = true

	out ["lives_here"] = lives_here
	out ["rules_here"] = rules_here
	out ["is_current_place"] = lives_here or rules_here
	out ["label"] = "YOU LIVE HERE" if bool(out ["is_current_place"]) else ""

	return out


static func _other_country_surface_is_united_states(gs: GameState,
	entry: Dictionary, realm: Dictionary) -> bool:
	var keys: Array = [
		str(entry.get("name", "")),
		str(entry.get("label", "")),
		str(entry.get("entry_id", "")),
		str(realm.get("name", "")),
		str(realm.get("country", "")),
		str(realm.get("realm_contract_resolved_from_country", ""))
	]

	for raw_value in keys:
		var key: String = MainSceneHelpers._other_country_identity_key(str(raw_value))
		if key in ["usa", "us", "unitedstates", "unitedstatesofamerica", "america"]:
			return true
		if key.find("unitedstates") >= 0:
			return true

	if typeof(gs.scenario_state) == TYPE_DICTIONARY:
		var us_realm_id: int = int(gs.scenario_state.get("presidential_parent_contract_us_realm_id", -1))
		var realm_id: int = int(realm.get("realm_id", realm.get("id", -1)))
		if us_realm_id > 0 and realm_id == us_realm_id:
			return true

	return false


static func _append_other_country_browser_entry_unique(out: Array, seen: Dictionary, entry: Dictionary) -> void:
	if typeof(entry) != TYPE_DICTIONARY or entry.is_empty():
		return

	var entry_kind: String = str(entry.get("entry_kind", "realm")).strip_edges().to_lower()
	var entry_id: String = str(entry.get("entry_id", "")).strip_edges()
	var entry_name: String = str(entry.get("name", "")).strip_edges()
	var realm_raw: Variant = entry.get("realm", {})
	var realm: Dictionary = realm_raw if typeof(realm_raw) == TYPE_DICTIONARY else {}
	var realm_name: String = str(realm.get("name", entry_name)).strip_edges()
	var realm_id: int = int(entry.get("realm_id", realm.get("realm_id", realm.get("id", 0))))

	if entry_id == "":
		entry_id = MainSceneHelpers._other_country_identity_key(entry_name)

	var aliases: Array = _other_country_browser_entry_identity_aliases(entry_kind, entry_id, entry_name, realm_name, realm_id)

	for alias_key in aliases:
		if seen.has(alias_key):
			return

	for alias_key in aliases:
		seen [alias_key] = true

	out.append(entry)


static func _other_country_browser_entry_identity_aliases(entry_kind: String, entry_id: String, entry_name: String, realm_name: String, realm_id: int = 0) -> Array:
	var aliases: Array = []

	var clean_kind: String = str(entry_kind).strip_edges().to_lower()
	if clean_kind == "":
		clean_kind = "realm"

	var clean_entry_id: String = MainSceneHelpers._other_country_identity_key(entry_id)
	var clean_entry_name: String = MainSceneHelpers._other_country_identity_key(entry_name)
	var clean_realm_name: String = MainSceneHelpers._other_country_identity_key(realm_name)

	if clean_entry_id != "":
		aliases.append("%s:id:%s" % [clean_kind, clean_entry_id])
		aliases.append("any:id:%s" % clean_entry_id)

	if clean_entry_name != "":
		aliases.append("%s:name:%s" % [clean_kind, clean_entry_name])
		aliases.append("any:name:%s" % clean_entry_name)

	if clean_realm_name != "":
		aliases.append("%s:realm_name:%s" % [clean_kind, clean_realm_name])
		aliases.append("any:realm_name:%s" % clean_realm_name)

	if realm_id > 0:
		aliases.append("realm_id:%d" % realm_id)

	var joined: String = "%s %s %s" % [entry_id, entry_name, realm_name]
	var lowered: String = joined.strip_edges().to_lower()

	if lowered.find("terabithia") >= 0:
		aliases.append("special:terabithia")

	if lowered.find("vormir") >= 0:
		aliases.append("special:vormir")

	if lowered.find("nidavellir") >= 0:
		aliases.append("special:nidavellir")

	if lowered.find("era kingdom") >= 0 or lowered.find("erakingdom") >= 0:
		aliases.append("special:era_kingdom")

	var elemental_exact_key: String = clean_entry_name if clean_entry_name != "" else clean_realm_name
	if elemental_exact_key != "":
		if lowered.find("earth kingdom") >= 0:
			aliases.append("elemental_surface:earth:%s" % elemental_exact_key)
		elif lowered.find("fire nation") >= 0:
			aliases.append("elemental_surface:fire:%s" % elemental_exact_key)
		elif lowered.find("water tribe") >= 0:
			aliases.append("elemental_surface:water:%s" % elemental_exact_key)
		elif lowered.find("air temple") >= 0 or lowered.find("air nomads") >= 0:
			aliases.append("elemental_surface:air:%s" % elemental_exact_key)

	if aliases.is_empty():
		aliases.append("%s:fallback:%s" % [clean_kind, MainSceneHelpers._other_country_identity_key("%s:%s:%d" % [entry_id, entry_name, realm_id])])

	return aliases


static func _ensure_romance_contract_engine_ready(gs: GameState) -> bool:
	if gs == null:
		return false

	if gs.has_method("_ensure_load_game_runtime_dependencies"):
		gs._ensure_load_game_runtime_dependencies()

	if gs.romance_contract_engine == null:
		gs.romance_contract_engine = RomanceContractEngine.new(gs)

	if gs.romance_contract_engine == null:
		return false

	if "gs" in gs.romance_contract_engine:
		gs.romance_contract_engine.gs = gs

	if not gs.romance_contract_engine.has_method("begin_foreign_date_search"):
		return false

	if not gs.romance_contract_engine.has_method("accept_pending_foreign_romance_contract"):
		return false

	return true


static func _other_country_apply_presidential_parent_leader_truth_to_surface(gs: GameState,
	surface_realm: Dictionary) -> Dictionary:
	if gs == null or typeof(surface_realm) != TYPE_DICTIONARY:
		return surface_realm
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		return surface_realm

	var out: Dictionary = surface_realm.duplicate(true)
	var us_realm_id: int = int(gs.scenario_state.get("presidential_parent_contract_us_realm_id", -1))
	var president_id: int = int(gs.scenario_state.get("presidential_parent_contract_president_id", -1))

	var country_key: String = MainSceneHelpers._other_country_identity_key(str(out.get("country", out.get("name", ""))))
	var name_key: String = MainSceneHelpers._other_country_identity_key(str(out.get("name", "")))
	var realm_id: int = int(out.get("realm_id", out.get("id", -1)))

	var is_us_surface: bool = realm_id == us_realm_id \
or country_key in ["usa", "us", "unitedstates", "unitedstatesofamerica", "america"] \
or name_key in ["usa", "us", "unitedstates", "unitedstatesofamerica", "america"]

	if not is_us_surface:
		return out

	if president_id <= 0:
		president_id = int(out.get("president_person_id", out.get("leader_id", out.get("ruler_id", -1))))

	if president_id <= 0 and gs.player != null:
		var player_country_key: String = MainSceneHelpers._other_country_identity_key(str(gs.player.home_country))
		var player_job_key: String = str(gs.player.job).strip_edges().to_lower()
		var player_civic_title_key: String = str(gs.player.civic_title).strip_edges().to_lower()

		if player_country_key in ["usa", "us", "unitedstates", "unitedstatesofamerica", "america"]:
			if player_job_key.find("president") >= 0 or player_civic_title_key.find("president") >= 0 or bool(gs.player.is_ruler):
				president_id = int(gs.player.id)

	if president_id <= 0:
		return out

	var president = null
	if gs.has_method("get_npc_by_id"):
		president = gs.get_npc_by_id(president_id)
	if president == null and gs.has_method("get_or_reactivate_npc_by_id"):
		president = gs.get_or_reactivate_npc_by_id(president_id)

	var president_name: String = "President"
	if president != null:
		president_name = "%s %s" % [str(president.first_name), str(president.last_name)]
		president_name = president_name.strip_edges()

	out ["id"] = us_realm_id
	out ["realm_id"] = us_realm_id
	out ["name"] = "United States"
	out ["country"] = "United States"
	out ["government_style"] = "Republic"
	out ["government_model"] = "federal_presidential_republic"
	out ["federal_republic_population_contract"] = true
	out ["ruler_id"] = president_id
	out ["ruler_npc_id"] = president_id
	out ["leader_id"] = president_id
	out ["president_person_id"] = president_id
	out ["ruler_name"] = president_name
	out ["leader_name"] = president_name
	out ["leader_title"] = "President of the United States"
	out ["surface_ruler_office"] = "President of the United States"
	out ["presidential_parent_contract_leader_truth"] = true
	out ["ui_is_renderer_only"] = true

	return out


static func _other_country_person_title_name(person: Person, fallback_title: String) -> String:
	if person == null:
		return "Unknown"

	var full_name: String = MainSceneHelpers._other_country_person_plain_name(person)
	var title_text: String = str(fallback_title).strip_edges()

	if title_text == "":
		title_text = MainSceneHelpers._other_country_clean_person_title_for_display(str(person.royal_title), full_name)

	if title_text.strip_edges().to_lower() == "ruler":
		return full_name

	if title_text == "":
		return full_name

	if MainSceneHelpers._other_country_text_already_has_title(full_name, title_text):
		return full_name

	return "%s %s" % [title_text, full_name]


static func _other_country_extract_person_name_from_ruler_text(raw_text: String, realm: Dictionary = {}) -> String:
	var text_value: String = str(raw_text).strip_edges()
	if text_value == "":
		return ""

	var lower_text: String = text_value.to_lower()

	if MainSceneHelpers._other_country_ruler_text_is_generic_office(lower_text, realm):
		return ""

	var generic_prefixes: Array = [
		"president of ",
		"chancellor of ",
		"supreme leader of ",
		"general secretary of ",
		"council voice of ",
		"ruler of ",
		"head of state of ",
		"king of ",
		"queen of ",
		"emperor of ",
		"empress of ",
		"fire lord of ",
		"earth king of ",
		"earth queen of ",
		"chief of ",
		"air monk of "
	]

	for raw_prefix in generic_prefixes:
		var prefix: String = str(raw_prefix)
		if lower_text.begins_with(prefix):
			var remainder: String = text_value.substr(prefix.length()).strip_edges()
			if remainder != "" and not MainSceneHelpers._other_country_ruler_text_is_generic_office(remainder.to_lower(), realm):
				return remainder
			return ""

	return text_value


static func _other_country_surface_culture_contract(realm_name: String, country_name: String, native_element: String, era_key: String) -> Dictionary:
	var lower_realm: String = str(realm_name).strip_edges().to_lower()
	var lower_country: String = str(country_name).strip_edges().to_lower()
	var lower_element: String = str(native_element).strip_edges().to_lower()
	var lower_era: String = str(era_key).strip_edges().to_lower()
	var key_text: String = "%s %s %s %s" % [lower_era, lower_realm, lower_country, lower_element]

	if lower_element == "fire" or key_text.find("fire nation") >= 0:
		return _other_country_make_culture_contract({
			"id": "fire_nation",
			"display_name": "Fire Nation Culture",
			"values": ["discipline", "honor", "expansion", "strength"],
			"naming_rules": "first_name + 'of' + military_city",
			"city_pool": ["Capital City", "Caldera City", "Ember Island", "Fire Fountain City", "Shu Jing"],
			"power_structure": "military monarchy",
			"ruler_title": "Fire Lord",
			"name_format": "of_city",
			"prefer_actions": ["expand_influence", "project_strength", "preserve_honor"],
			"avoid_actions": ["appear_weak", "ignore_insult"],
			"behavior_bias": { "loyalty": 8, "rebellion": -4, "militarism": 18, "diplomacy": -5, "stability": 4}
		})

	if lower_element == "earth" or key_text.find("earth kingdom") >= 0:
		return _other_country_make_culture_contract({
			"id": "earth_kingdom",
			"display_name": "Earth Kingdom Culture",
			"values": ["tradition", "endurance", "territory", "stability"],
			"naming_rules": "first_name + 'of' + ancient_city",
			"city_pool": ["Ba Sing Se", "Omashu", "Gaoling", "Chin Village", "Kyoshi Island"],
			"power_structure": "royal monarchy",
			"ruler_title": "Earth King",
			"name_format": "of_city",
			"prefer_actions": ["preserve_borders", "maintain_order", "defend_customs"],
			"avoid_actions": ["rapid_reform", "reckless_war"],
			"behavior_bias": { "loyalty": 10, "rebellion": -8, "stability": 14, "militarism": 3, "diplomacy": 4}
		})

	if lower_element == "water" or key_text.find("water tribe") >= 0 or key_text.find("water nation") >= 0:
		return _other_country_make_culture_contract({
			"id": "water_tribes",
			"display_name": "Water Tribe Culture",
			"values": ["community", "adaptation", "healing", "ancestry"],
			"naming_rules": "first_name + 'of' + tribal_home",
			"city_pool": ["Agna Qel'a", "Wolf Cove", "Harbor City", "Foggy Swamp", "Southern Water Village"],
			"power_structure": "tribal chieftaincy",
			"ruler_title": "Chief",
			"name_format": "of_city",
			"prefer_actions": ["protect_community", "heal_divisions", "honor_ancestors"],
			"avoid_actions": ["abandon_people", "break_tradition"],
			"behavior_bias": { "loyalty": 16, "rebellion": -6, "stability": 8, "diplomacy": 10, "militarism": -2}
		})

	if lower_element == "air" or key_text.find("air temple") >= 0 or key_text.find("air nomads") >= 0:
		return _other_country_make_culture_contract({
			"id": "air_nomads",
			"display_name": "Air Nomad Culture",
			"values": ["freedom", "spirituality", "balance", "nonviolence"],
			"naming_rules": "first_name + 'of' + temple",
			"city_pool": ["Eastern Air Temple", "Western Air Temple", "Northern Air Temple", "Southern Air Temple"],
			"power_structure": "spiritual council",
			"ruler_title": "Air Monk",
			"name_format": "of_city",
			"prefer_actions": ["preserve_balance", "mediate_conflict", "teach_spirituality"],
			"avoid_actions": ["conquest", "cruel_punishment"],
			"behavior_bias": { "loyalty": 12, "rebellion": -10, "stability": 7, "diplomacy": 18, "militarism": -18}
		})

	if key_text.find("ancient egypt") >= 0 or key_text.find("egypt") >= 0:
		return _other_country_make_culture_contract({
			"id": "ancient_egypt",
			"display_name": "Ancient Egyptian Culture",
			"values": ["order", "afterlife", "divinity", "monumentality"],
			"naming_rules": "first_name + 'of' + sacred_city",
			"city_pool": ["Thebes", "Memphis", "Heliopolis", "Alexandria", "Abydos"],
			"power_structure": "divine monarchy",
			"ruler_title": "Pharaoh",
			"name_format": "of_city",
			"prefer_actions": ["preserve_order", "honor_gods", "build_monuments"],
			"avoid_actions": ["rebellion", "desecration"],
			"behavior_bias": { "loyalty": 20, "rebellion": -15, "stability": 16, "diplomacy": 2, "monuments": 18}
		})

	if lower_era in ["medieval", "medieval era"]:
		return _other_country_make_culture_contract({
			"id": "medieval_feudal",
			"display_name": "Medieval Feudal Culture",
			"values": ["lineage", "faith", "land", "oaths"],
			"naming_rules": "first_name + 'of' + seat",
			"city_pool": ["York", "Winchester", "Canterbury", "London", "Norwich"],
			"power_structure": "feudal monarchy",
			"ruler_title": "King",
			"name_format": "of_city",
			"prefer_actions": ["form_alliances", "defend_lineage", "wage_claim_wars"],
			"avoid_actions": ["break_oaths", "ignore_vassals"],
			"behavior_bias": { "loyalty": 5, "rebellion": 6, "stability": -2, "diplomacy": 8, "militarism": 10}
		})

	if lower_era in ["ancient", "ancient era"]:
		return _other_country_make_culture_contract({
			"id": "ancient_dynastic",
			"display_name": "Ancient Dynastic Culture",
			"values": ["lineage", "omens", "conquest", "ritual"],
			"naming_rules": "first_name + 'of' + ancient_city",
			"city_pool": ["Babylon", "Ur", "Nineveh", "Tyre", "Persepolis"],
			"power_structure": "dynastic monarchy",
			"ruler_title": "King",
			"name_format": "of_city",
			"prefer_actions": ["expand_dynasty", "honor_omens", "secure_grain"],
			"avoid_actions": ["dynastic_shame", "weak_succession"],
			"behavior_bias": { "loyalty": 8, "rebellion": -3, "stability": 5, "militarism": 8, "diplomacy": 2}
		})

	if lower_era in ["future", "future era"]:
		return _other_country_make_culture_contract({
			"id": "future_civic_algorithmic",
			"display_name": "Future Civic Culture",
			"values": ["efficiency", "innovation", "surveillance", "mobility"],
			"naming_rules": "first_name + legal_family_name",
			"city_pool": ["Neo Tokyo", "New Shanghai", "Lagos Arcology", "Toronto Spire", "Chicago Grid"],
			"power_structure": "technocratic republic",
			"ruler_title": "President",
			"name_format": "family_name",
			"prefer_actions": ["optimize_systems", "expand_infrastructure", "manage_risk"],
			"avoid_actions": ["systemic_decay", "untracked_instability"],
			"behavior_bias": { "loyalty": 0, "rebellion": 4, "stability": 8, "innovation": 18, "privacy": -10}
		})

	return _other_country_make_culture_contract({
		"id": "modern_civic",
		"display_name": "Modern Civic Culture",
		"values": ["rights", "commerce", "identity", "public_opinion"],
		"naming_rules": "first_name + legal_family_name",
		"city_pool": [],
		"power_structure": "civic state",
		"ruler_title": "",
		"name_format": "family_name",
		"prefer_actions": ["manage_public_opinion", "grow_economy", "protect_rights"],
		"avoid_actions": ["public_scandal", "economic_collapse"],
		"behavior_bias": { "loyalty": 0, "rebellion": 2, "stability": 0, "diplomacy": 4, "commerce": 8}
	})


static func _other_country_make_culture_contract(data: Dictionary) -> Dictionary:
	var id_text: String = str(data.get("id", "generic_culture")).strip_edges().to_lower()
	var display_name: String = str(data.get("display_name", id_text.capitalize())).strip_edges()
	var city_pool: Array = MainSceneHelpers._safe_array(data.get("city_pool", []))
	var ruler_title: String = str(data.get("ruler_title", "")).strip_edges()
	var name_format: String = str(data.get("name_format", "family_name")).strip_edges().to_lower()
	var behavior_bias: Dictionary = MainSceneHelpers._safe_dictionary(data.get("behavior_bias", {}))

	return {
		"schema": "eralife.cultural_reality_contract",
		"version": 1,
		"id": id_text,
		"display_name": display_name,
		"values": MainSceneHelpers._safe_array(data.get("values", [])),
		"naming_rules": str(data.get("naming_rules", "")),
		"city_pool": city_pool,
		"power_structure": str(data.get("power_structure", "civic state")),
		"behavior_bias": behavior_bias,
		"ruler_identity_contract": {
			"must_have_title": ruler_title,
			"name_format": name_format,
			"valid_origin_cities": city_pool
		},
		"behavior_contract": {
			"prefer_actions": MainSceneHelpers._safe_array(data.get("prefer_actions", [])),
			"avoid_actions": MainSceneHelpers._safe_array(data.get("avoid_actions", [])),
			"bias": behavior_bias
		},
		"history_contract": {
			"records_identity_origin": name_format == "of_city",
		},
		"ui_contract": {
			"observer_only": true,
		}
	}


static func _other_country_surface_birth_locations_for_era(gs: GameState,
	era_key: String = "") -> Array:
	var out: Array = []
	var clean_era: String = str(era_key).strip_edges()

	if gs == null:
		return out

	var source_candidates: Array = []
	if "era_manager" in gs and gs.era_manager != null:
		source_candidates.append(gs.era_manager)
	if "era_engine" in gs and gs.era_engine != null:
		source_candidates.append(gs.era_engine)
	if "era" in gs and gs.era != null:
		source_candidates.append(gs.era)

	for source in source_candidates:
		var source_locations: Array = _other_country_surface_birth_locations_from_source(source, clean_era)
		for raw_location in source_locations:
			if typeof(raw_location) != TYPE_DICTIONARY:
				continue
			var location: Dictionary = raw_location as Dictionary
			if not out.has(location):
				out.append(location)

	return out


static func _other_country_surface_birth_locations_from_source(source: Variant, era_key: String = "") -> Array:
	if source == null:
		return []

	if typeof(source) == TYPE_DICTIONARY:
		var source_dict: Dictionary = source as Dictionary
		var direct_locations: Array = MainSceneHelpers._safe_array(source_dict.get("birth_locations", []))
		if not direct_locations.is_empty():
			return direct_locations

		var keyed_locations: Array = MainSceneHelpers._safe_array(source_dict.get("locations", []))
		if not keyed_locations.is_empty():
			return keyed_locations

		var eras: Dictionary = MainSceneHelpers._safe_dictionary(source_dict.get("eras", {}))
		var clean_era: String = str(era_key).strip_edges()
		if clean_era != "" and eras.has(clean_era):
			var era_payload: Variant = eras.get(clean_era)
			if typeof(era_payload) == TYPE_DICTIONARY:
				return MainSceneHelpers._safe_array((era_payload as Dictionary).get("birth_locations", []))
			if typeof(era_payload) == TYPE_ARRAY:
				return era_payload as Array

		return []

	if typeof(source) != TYPE_OBJECT:
		return []

	if era_key != "" and source.has_method("get_birth_locations_for_era"):
		var era_locations: Variant = source.get_birth_locations_for_era(era_key)
		if typeof(era_locations) == TYPE_ARRAY:
			return era_locations as Array

	if source.has_method("get_birth_locations"):
		var locations: Variant = source.get_birth_locations()
		if typeof(locations) == TYPE_ARRAY:
			return locations as Array

	return []


static func _reality_fusion_current_universe_matches_path(gs: GameState,
	path: String) -> bool:
	var clean_path: String = str(path).strip_edges()
	if clean_path == "" or gs == null or typeof(gs.scenario_state) != TYPE_DICTIONARY:
		return false

	var entered_raw: Variant = gs.scenario_state.get("reality_fusion_entered_universe", {})
	if typeof(entered_raw) != TYPE_DICTIONARY:
		return false

	var entered: Dictionary = entered_raw
	var entered_path: String = str(entered.get("path", "")).strip_edges()
	return entered_path != "" and entered_path == clean_path


static func _build_reality_fusion_contract(mode: String) -> Dictionary:
	var clean_mode: String = str(mode).strip_edges().to_lower()
	var contract: Dictionary = {
		"schema": "eralife.reality_fusion_contract",
		"version": 1,
		"id": "main_scene_%s" % clean_mode,
		"mode": clean_mode,
		"extract": {
			"relationships": "none"
		},
		"transform": {},
		"reconcile": {
			"source_world": "unchanged",
			"write_source_save": false,
			"compensation": "none"
		},
		"balance": {
			"fatigue_cost": 4.0,
			"mental_strain": 2.0,
			"identity_instability": 1.0,
			"mutation_risk": 0.0,
			"cooldown_ms": 2500
		},
		"source_resistance": {
			"enabled": false,
			"chance": 0.0
		},
		"ui": {
			"label": clean_mode,
		}
	}
	match clean_mode:
		"stats_steal":
			contract ["extract"] ["stats"] = MainSceneHelpers._reality_fusion_stat_keys()
			contract ["transform"] ["stats"] = {
				"mode": "max",
				"cap": 100
			}
			contract ["source_resistance"] = {
				"enabled": true,
				"chance": 0.18
			}
			contract ["balance"] = {
				"fatigue_cost": 12.0,
				"mental_strain": 9.0,
				"identity_instability": 6.0,
				"mutation_risk": 0.1,
				"cooldown_ms": 8500
			}
		"inventory_merge":
			contract ["extract"] ["inventory"] = {
				"enabled": true,
				"filter": "rarity:legendary",
			}
			contract ["transform"] ["inventory"] = {
				"mode": "inject",
				"conflict": "stack_or_replace"
			}
			contract ["balance"] = {
				"fatigue_cost": 3.0,
				"mental_strain": 1.0,
				"identity_instability": 1.0,
				"mutation_risk": 0.02,
				"cooldown_ms": 3000
			}
		"bending_transfer":
			contract ["extract"] ["bending"] = {
				"enabled": true,
				"skills": true,
			}
			contract ["transform"] ["bending"] = {
				"mode": "skill_transfer",
				"cap": 100,
				"multiple_avatar_influence": true
			}
			contract ["balance"] = {
				"fatigue_cost": 9.0,
				"mental_strain": 7.0,
				"identity_instability": 4.0,
				"mutation_risk": 0.08,
				"cooldown_ms": 7000
			}
		"traits_merge":
			contract ["extract"] ["traits"] = {
				"include": [],
				"exclude": ["addiction", "reckless"]
			}
			contract ["transform"] ["traits"] = {
				"mode": "union",
				"mutation_chance": 0.08
			}
			contract ["balance"] = {
				"fatigue_cost": 2.0,
				"mental_strain": 6.0,
				"identity_instability": 5.0,
				"mutation_risk": 0.08,
				"cooldown_ms": 5000
			}
		"money_transfer":
			contract ["extract"] ["money"] = true
			contract ["transform"] ["money"] = {
				"mode": "add",
				"multiplier": 0.25,
				"cap": 1000000
			}
			contract ["source_resistance"] = {
				"enabled": true,
				"chance": 0.08
			}
			contract ["balance"] = {
				"fatigue_cost": 1.0,
				"mental_strain": 2.0,
				"identity_instability": 2.0,
				"mutation_risk": 0.03,
				"cooldown_ms": 4000
			}
		"bring_person_family":
			contract ["mode"] = "parallel_identity_import"
			contract ["merge_policy"] = MainSceneHelpers._reality_fusion_merge_policy([
				"parents",
				"children",
				"spouse",
				"partner",
				"ex_partners",
				"siblings",
				"grandparents",
				"grandchildren",
				"family_web",
				"extended_family"
			], "bidirectional", -1)
			contract ["balance"] = {
				"fatigue_cost": 3.0,
				"mental_strain": 3.0,
				"identity_instability": 2.0,
				"mutation_risk": 0.02,
				"cooldown_ms": 4000
			}
		"friend_person":
			contract ["mode"] = "friend_person"
			contract ["merge_policy"] = MainSceneHelpers._reality_fusion_merge_policy([], "bidirectional", -1)
			contract ["balance"] = {
				"fatigue_cost": 1.0,
				"mental_strain": 1.0,
				"identity_instability": 0.5,
				"mutation_risk": 0.0,
				"cooldown_ms": 2500
			}
		"bring_family_member":
			contract ["mode"] = "bring_family_member"
			contract ["merge_policy"] = MainSceneHelpers._reality_fusion_merge_policy([], "bidirectional", -1)
			contract ["balance"] = {
				"fatigue_cost": 1.5,
				"mental_strain": 2.0,
				"identity_instability": 1.0,
				"mutation_risk": 0.0,
				"cooldown_ms": 3000
			}
		_:
			contract ["extract"] ["stats"] = MainSceneHelpers._reality_fusion_stat_keys()
			contract ["transform"] ["stats"] = {
				"mode": "weighted_blend",
				"weight_self": 0.7,
				"weight_source": 0.3,
				"cap": 100
			}
	return contract


static func _reality_fusion_mode_titles(modes: Array) -> Array:
	var out: Array = []
	for raw_mode in modes:
		out.append(MainSceneHelpers._reality_fusion_mode_title(str(raw_mode)))
	return out


static func _reality_fusion_mode_button_style(mode: String, selected: bool, disabled: bool) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	var color: Color = MainSceneHelpers._reality_fusion_mode_color(mode)
	if selected:
		color = color.lerp(Color(1.0, 1.0, 1.0, color.a), 0.18)
	if disabled:
		color = color.lerp(Color(0.02, 0.02, 0.02, color.a), 0.45)
		color.a = 0.58
	style.bg_color = color
	style.border_color = Color(1.0, 1.0, 1.0, 0.26 if selected else 0.14)
	style.border_width_left = 2 if selected else 1
	style.border_width_right = 2 if selected else 1
	style.border_width_top = 2 if selected else 1
	style.border_width_bottom = 2 if selected else 1
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.shadow_color = Color(color.r, color.g, color.b, 0.24 if selected else 0.1)
	style.shadow_size = 8 if selected else 3
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


static func _reality_fusion_foreign_timeline_pressure(gs: GameState) -> float:
	if gs == null or typeof(gs.scenario_state) != TYPE_DICTIONARY:
		return 0.0

	var entered_raw: Variant = gs.scenario_state.get("reality_fusion_entered_universe", {})
	if typeof(entered_raw) != TYPE_DICTIONARY:
		return 0.0

	var entered: Dictionary = entered_raw
	if entered.is_empty():
		return 0.0

	var pressure: float = 1.0
	if bool(entered.get("mode_mismatch", false)):
		pressure += 0.65

	pressure += clamp(float(gs.scenario_state.get("tva_engine_heat", 0.0)) / 4.0, 0.0, 2.5)
	pressure += clamp(float(gs.scenario_state.get("reality_fusion_identity_instability", 0.0)) / 18.0, 0.0, 2.0)

	return clamp(pressure, 0.0, 4.0)


static func _resolve_player_stat_surface(title: String, value: int, max_value: int, surface_context: Dictionary) -> Dictionary:
	var safe_max: int = max(1, max_value)
	var ratio: float = clamp(float(value) / float(safe_max), 0.0, 1.0)
	var descriptor: String = ""
	var flavor: String = ""
	var flavor_already_localized: bool = false
	var bar_text_override: String = ""
	match title:
		"Health":
			var health_value: int = max(0, int(round(float(value))))
			var subject_dead: bool = bool(surface_context.get("subject_dead", false)) or health_value <= 0

			if subject_dead:
				descriptor = "Dead"
				flavor = str(surface_context.get("death_health_flavor", "")).strip_edges()
				if flavor == "":
					flavor = MainSceneHelpers._relationship_profile_dead_health_flavor(surface_context)
			elif health_value >= 180:
				descriptor = "Mythic Body"
				flavor = "Your body is operating beyond anything ordinary people are built to survive."
			elif health_value >= 150:
				descriptor = "Superhuman"
				flavor = "Your body is past peak condition and starting to feel unreal."
			elif health_value >= 125:
				descriptor = "Enhanced"
				flavor = "Your body is stronger than normal limits, but still recognizably human."
			elif health_value >= 100:
				descriptor = "Peak Condition"
				flavor = "Your body is at the kind of health most people dream about."
			elif health_value >= 85:
				descriptor = "Excellent"
				flavor = "Your body feels strong, responsive, and dependable."
			elif health_value >= 70:
				descriptor = "Strong"
				flavor = "You feel durable, steady, and ready for impact."
			elif health_value >= 50:
				descriptor = "Stable"
				flavor = "You are holding together without obvious strain."
			elif health_value >= 30:
				descriptor = "Injured"
				flavor = "Your body is asking for recovery whether you listen or not."
			elif health_value >= 15:
				descriptor = "Critical"
				flavor = "Your body is refusing to give up, but it is close."
			else:
				descriptor = "Near Death"
				flavor = "Every movement feels like it could be your last."
		"Hunger":
			var hunger_value: int = clamp(int(round(float(value))), 0, 100)
			if hunger_value <= 5:
				descriptor = "Critical Starvation"
				flavor = "Your body is running on almost nothing. This is dangerous."
			elif hunger_value <= 18:
				descriptor = "Starving"
				flavor = "Your body urgently needs food. Every moment without sustenance matters."
			elif hunger_value <= 35:
				descriptor = "Malnourished"
				flavor = "You have gone too long without enough food."
			elif hunger_value <= 55:
				descriptor = "Hungry"
				flavor = "Your body is asking for food."
			elif hunger_value <= 72:
				descriptor = "Peckish"
				flavor = "You could eat, but you are still holding steady."
			elif hunger_value <= 92:
				descriptor = "Satisfied"
				flavor = "You feel fed and steady."
			else:
				descriptor = "Full"
				flavor = "You are fully fed. Food is not pressing on your body right now."
		"Mental":
			if bool(surface_context.get("is_royal_pressure", false)):
				if ratio >= 0.75:
					descriptor = "Commanding"
					flavor = "Pressure is real, but your mind is still above it."
				elif ratio >= 0.45:
					descriptor = "Siege-Minded"
					flavor = "Responsibility is crowding your thoughts."
				else:
					descriptor = "Overrun"
					flavor = "The crown is louder than your control."
			elif bool(surface_context.get("is_public_pressure", false)):
				if ratio >= 0.75:
					descriptor = "Focused"
					flavor = "The world is loud, but your inner signal is still clean."
				elif ratio >= 0.45:
					descriptor = "Crowded"
					flavor = "Too much attention is living in your head rent-free."
				else:
					descriptor = "Overwhelmed"
					flavor = "The noise outside is starting to win."
			else:
				if ratio >= 0.9:
					descriptor = "Locked In"
					flavor = "Your thoughts feel sharp, quiet, and fully under you."
				elif ratio >= 0.72:
					descriptor = "Focused"
					flavor = "Your mind is steady and responsive."
				elif ratio >= 0.5:
					descriptor = "Steady"
					flavor = "You are carrying your thoughts without slipping."
				elif ratio >= 0.3:
					descriptor = "Overloaded"
					flavor = "Your thoughts are louder than your control."
				elif ratio >= 0.15:
					descriptor = "Fractured"
					flavor = "Your mind is splitting under pressure."
				else:
					descriptor = "Overwhelmed"
					flavor = "You are barely holding the inside together."
		"Happiness":
			if ratio >= 0.9:
				descriptor = "Thriving"
				flavor = "Life feels open, bright, and worth leaning into."
			elif ratio >= 0.72:
				descriptor = "Content"
				flavor = "There is real warmth in your day-to-day state."
			elif ratio >= 0.5:
				descriptor = "Grounded"
				flavor = "You are not flying, but you are not empty either."
			elif ratio >= 0.3:
				descriptor = "Drained"
				flavor = "Joy is present mostly as memory."
			elif ratio >= 0.15:
				descriptor = "Numb"
				flavor = "Feeling good takes more work than it should."
			else:
				descriptor = "Joyless"
				flavor = "The light is there somewhere, but not in reach right now."
		"Smarts":
			if ratio >= 0.95:
				descriptor = "Gifted"
				flavor = "Your mind is operating above the room."
			elif ratio >= 0.8:
				descriptor = "Brilliant"
				flavor = "You process patterns faster than most people can explain them."
			elif ratio >= 0.6:
				descriptor = "Sharp"
				flavor = "You are thinking clearly and catching things quickly."
			elif ratio >= 0.4:
				descriptor = "Clever"
				flavor = "You can work your way through things with effort."
			elif ratio >= 0.2:
				descriptor = "Foggy"
				flavor = "Your thinking works, but it feels heavy."
			else:
				descriptor = "Lost"
				flavor = "Nothing is clicking the way it should."
		"Looks":
			if ratio >= 0.9:
				descriptor = "Striking"
				flavor = "Your presence lands before you even say anything."
			elif ratio >= 0.72:
				descriptor = "Attractive"
				flavor = "You are carrying yourself well and it shows."
			elif ratio >= 0.5:
				descriptor = "Presentable"
				flavor = "You look fine, even if it is not commanding the room."
			elif ratio >= 0.3:
				descriptor = "Plain"
				flavor = "Nothing is wrong, but nothing is turning heads either."
			elif ratio >= 0.15:
				descriptor = "Rough"
				flavor = "You look like life has been leaving fingerprints."
			else:
				descriptor = "Haggard"
				flavor = "You look visibly worn down."
		"Imagination":
			if bool(surface_context.get("terabithia_entered", false)):
				if ratio >= 0.9:
					descriptor = "Reality Bender"
					flavor = "Reality feels thin around you."
				elif ratio >= 0.72:
					descriptor = "Veil-Thinning"
					flavor = "You can feel the edge where ordinary rules weaken."
				elif ratio >= 0.5:
					descriptor = "Awakening"
					flavor = "Something beyond ordinary perception keeps answering back."
				else:
					descriptor = "Creative"
					flavor = "The door is real, but you are not fully through it yet."
			elif bool(surface_context.get("terabithia_unlocked", false)) or bool(surface_context.get("terabithia_known", false)):
				if ratio >= 0.9:
					descriptor = "Threshold Open"
					flavor = "Imagination is no longer just internal."
				elif ratio >= 0.72:
					descriptor = "Veil-Thinning"
					flavor = "Reality keeps feeling less sealed than before."
				elif ratio >= 0.5:
					descriptor = "Awakening"
					flavor = "Your creativity is beginning to bend perception."
				elif ratio >= 0.3:
					descriptor = "Creative"
					flavor = "Your inner world is getting louder."
				else:
					descriptor = "Grounded"
					flavor = "The signal is there, but it is still faint."
			else:
				if ratio >= 0.9:
					descriptor = "World-Shaping"
					flavor = "Your imagination feels capable of pulling new layers into existence."
				elif ratio >= 0.72:
					descriptor = "Creative"
					flavor = "Ideas come alive fast and vividly."
				elif ratio >= 0.5:
					descriptor = "Awakening"
					flavor = "Your inner world is active and getting stronger."
				elif ratio >= 0.3:
					descriptor = "Curious"
					flavor = "Your imagination is present, but not yet breaking through."
				else:
					descriptor = "Grounded"
					flavor = "Your perception stays close to the material world."
		"Willpower":
			var will_value: int = max(0, int(round(float(value))))
			if will_value >= 900:
				descriptor = "Avatar Limitless"
				flavor = "Your will is being carried by the Avatar State. Pain, fear, pressure, and defeat are struggling to find an edge."
			elif will_value >= 180:
				descriptor = "Mythic"
				flavor = "Your will is operating beyond ordinary collapse thresholds."
			elif will_value >= 150:
				descriptor = "Legendary"
				flavor = "Your mind refuses defeat with almost supernatural force."
			elif will_value >= 120:
				descriptor = "Unbreakable"
				flavor = "Pressure bends around you more than it breaks you."
			elif will_value >= 95:
				descriptor = "Iron"
				flavor = "You can take punishment, fear, and failure without losing your center."
			elif will_value >= 75:
				descriptor = "Strong"
				flavor = "You keep moving even when your body and emotions argue back."
			elif will_value >= 55:
				descriptor = "Steady"
				flavor = "Your resolve is holding under normal pressure."
			elif will_value >= 35:
				descriptor = "Shaken"
				flavor = "You can still push forward, but the cracks are getting louder."
			elif will_value >= 15:
				descriptor = "Breaking"
				flavor = "Your will is close to collapse and needs recovery."
			else:
				descriptor = "Collapsed"
				flavor = "Your internal resistance is almost gone."
		"Fame":
			var fame_tier_text: String = str(surface_context.get("fame_tier_text", "")).strip_edges()
			if fame_tier_text != "":
				descriptor = fame_tier_text
			elif ratio >= 0.9:
				descriptor = "Legend"
			elif ratio >= 0.72:
				descriptor = "Icon"
			elif ratio >= 0.5:
				descriptor = "Recognized"
			elif ratio >= 0.3:
				descriptor = "Known"
			else:
				descriptor = "Obscure"
			if ratio >= 0.85:
				flavor = "Your name walks into rooms before you do."
			elif ratio >= 0.6:
				flavor = "People know you, and that changes what life feels like."
			elif ratio >= 0.3:
				flavor = "Recognition is growing, even if it is not fully world-bending yet."
			else:
				flavor = "Your name is still mostly local to your own orbit."

		"Approval":
			if ratio >= 0.85:
				descriptor = "Beloved"
				flavor = "The public is leaning toward you, not away from you."
			elif ratio >= 0.7:
				descriptor = "Backed"
				flavor = "Your rule has support and breathing room."
			elif ratio >= 0.5:
				descriptor = "Stable"
				flavor = "You still hold legitimacy, but it is not untouchable."
			elif ratio >= 0.3:
				descriptor = "Fragile"
				flavor = "Your position is standing, but the ground is shifting."
			elif ratio >= 0.15:
				descriptor = "Rejected"
				flavor = "Trust is leaving faster than it is returning."
			else:
				descriptor = "Coup Risk"
				flavor = "Power around you feels one bad moment from turning."
		"Bond":
			var living_bond_descriptor: String = MainSceneHelpers._relationship_bond_descriptor_for_ratio(ratio)
			var subject_dead: bool = bool(surface_context.get("subject_dead", false))

			if subject_dead:
				descriptor = MainSceneHelpers._relationship_bond_posthumous_descriptor(living_bond_descriptor)
				flavor = MainSceneHelpers._relationship_bond_flavor_for_descriptor(living_bond_descriptor, surface_context, true)
				bar_text_override = "Dead"
			else:
				descriptor = living_bond_descriptor
				flavor = MainSceneHelpers._relationship_bond_flavor_for_descriptor(living_bond_descriptor, surface_context, false)

			flavor_already_localized = true
		_:
			descriptor = "%d" % clamp(value, 0, safe_max)
			flavor = ""
	if not flavor_already_localized:
		flavor = MainSceneHelpers._surface_stat_phrase(flavor, surface_context)

	var resolved_bar_text: String = str(bar_text_override).strip_edges()
	if resolved_bar_text == "":
		resolved_bar_text = "%d" % clamp(value, 0, safe_max)

	return {
		"descriptor": descriptor,
		"flavor": flavor,
		"bar_text": resolved_bar_text
	}


static func _player_has_meaningful_approval(p: Person) -> bool:
	if p == null:
		return false

	if MainSceneHelpers._player_is_government_figure(p):
		return true

	if bool(p.is_ruler):
		return true

	if bool(p.is_royal):
		return true

	var royal_title: String = str(p.royal_title).strip_edges()
	if royal_title != "":
		return true

	var social_class: String = str(p.social_class).strip_edges()
	if social_class == "Royal":
		return true

	var succession_rank: int = int(p.succession_rank)
	if succession_rank > 0 and succession_rank <= 12:
		if bool(p.is_royal) or royal_title != "" or social_class == "Royal":
			return true

	return false


static func _bending_feature_enabled_by_reality_contract(gs: GameState) -> bool:
	if gs == null:
		return false




	if typeof(
		gs.custom_settings
	) == TYPE_DICTIONARY:
		var custom_overrides_raw: Variant = (
			gs.custom_settings.get(
				"feature_overrides",
				{}
			)
		)

		if typeof(
			custom_overrides_raw
		) == TYPE_DICTIONARY:
			var custom_overrides: Dictionary = (
				custom_overrides_raw as Dictionary
			)

			if custom_overrides.has(
				"bending"
			):
				return bool(
					custom_overrides.get(
						"bending",
						false
					)
				)

	if typeof(
		gs.reality_feature_overrides
	) == TYPE_DICTIONARY:
		if gs.reality_feature_overrides.has(
			"bending"
		):
			return bool(
				gs.reality_feature_overrides.get(
					"bending",
					false
				)
			)

	return bool(
		gs.player_bending_enabled
	)


static func _food_lifestyle_active_actor(gs: GameState) -> Person:
	if gs == null:
		return null
	return gs.player


static func _food_lifestyle_era_supports_modern_future_hubs(era_name: String) -> bool:
	var clean_era: String = MainSceneHelpers._food_lifestyle_normalized_era_key_for_mainscene(era_name)
	return clean_era == "modern" or clean_era == "future"


static func _food_lifestyle_era_name_from_year_for_mainscene(year_value: int) -> String:
	match MainSceneHelpers._food_lifestyle_era_key_from_year_for_mainscene(year_value):
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


static func _food_lifestyle_publish_year_era_truth(gs: GameState,
	era_name: String) -> void:
	if gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	gs.scenario_state ["year_era_authority"] = "mainscene.year_threshold"
	gs.scenario_state ["year_era_name"] = era_name
	gs.scenario_state ["era_name"] = era_name
	gs.scenario_state ["era"] = MainSceneHelpers._food_lifestyle_normalized_era_key_for_mainscene(era_name).capitalize()
	gs.scenario_state ["year_era_source_year"] = int(gs.year)
	gs.scenario_state ["year_era_synced_at_ms"] = int(Time.get_ticks_msec())


static func _stage_food_lifestyle_hud_truth_for_zero_frame_entry(gs: GameState,
	
	snapshot: Dictionary,
	reason: String = "god_mode_food_lifestyle_stage"
) -> Dictionary:
	var out: Dictionary = snapshot.duplicate(false)

	if gs == null:
		return out

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var era_name: String = (
		str(gs.era.name).strip_edges()
		if gs.era != null
		else str(out.get("era_name", ""))
	)
	var grocery_allowed: bool = bool(
		gs.scenario_state.get(
			"grocery_hud_allowed",
			out.get(
				"grocery_hud_allowed",
				false
			)
		)
	)
	var restaurant_allowed: bool = bool(
		gs.scenario_state.get(
			"restaurant_hud_allowed",
			out.get(
				"restaurant_hud_allowed",
				false
			)
		)
	)

	out ["food_lifestyle_hud_allowed"] = (
		grocery_allowed
		or restaurant_allowed
	)
	out ["food_lifestyle_hud_era_name"] = era_name
	out ["food_lifestyle_available"] = grocery_allowed
	out ["restaurant_lifestyle_available"] = restaurant_allowed
	out ["grocery_hud_allowed"] = grocery_allowed
	out ["restaurant_hud_allowed"] = restaurant_allowed
	out ["industrial_food_lifestyle_expansion_slot_reserved"] = true
	out ["food_lifestyle_stage_reason"] = reason
	out ["food_lifestyle_stage_called_engine"] = false
	out ["food_lifestyle_ready_gate_member"] = false

	return out


static func _rick_weapon_shop_hub_available(gs: GameState) -> bool:
	if gs == null or gs.player == null:
		return false
	if gs.awaiting_new_life:
		return false
	if gs.weapons_engine == null:
		return false
	if gs.weapons_engine.has_method("get_store"):
		return not gs.weapons_engine.get_store().is_empty()
	return true


static func _rick_weapon_shop_should_show_recognition(gs: GameState,
	contract: Dictionary) -> bool:
	if gs == null or gs.player == null:
		return false

	var actor_id: int = int(gs.player.id)
	for raw_entry in MainSceneHelpers._safe_array(contract.get("transaction_log", [])):
		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = raw_entry as Dictionary
		if int(entry.get("actor_id", -1)) == actor_id and bool(entry.get("success", false)):
			return true

	return false


static func _rick_weapon_shop_population_badge_text(label_text: String, value: int, show_value: bool = true) -> String:
	var clean_label: String = str(label_text).strip_edges()
	if not show_value:
		return clean_label

	var lowered: String = clean_label.to_lower()
	var suffix: String = clean_label

	if lowered == "people" or lowered == "person":
		suffix = ""
	elif lowered.begins_with("people "):
		suffix = clean_label.substr(7).strip_edges()
	elif lowered.begins_with("person "):
		suffix = clean_label.substr(7).strip_edges()

	var count_text: String = MainSceneHelpers._rick_weapon_shop_population_count_text(value)
	if suffix == "":
		return count_text

	return "%s %s" % [count_text, suffix]


static func _rick_weapon_shop_inside_live_text(contract: Dictionary, state: Dictionary) -> String:
	var inside: Dictionary = MainSceneHelpers._safe_dictionary(state.get("inside", {}))
	var lines: Array = []

	var last_live_line: String = str(inside.get("last_live_line", "")).strip_edges()
	if last_live_line != "":
		lines.append(last_live_line)

	var rick_live_text: String = str(inside.get("rick_live_text", "")).strip_edges()
	if rick_live_text != "":
		lines.append(rick_live_text)
	else:
		lines.append(_rick_weapon_shop_rick_greeting(contract))

	return "\n\n".join(lines)


static func _rick_weapon_shop_rick_greeting(contract: Dictionary) -> String:
	var vendor: Dictionary = MainSceneHelpers._safe_dictionary(contract.get("vendor", {}))
	var vendor_name: String = str(vendor.get("display_name", "Rick"))
	return "%s looks up before the door finishes opening.\nRick: \"Take your time. The wall always tells me what people think they need.\"" % vendor_name


static func _rick_weapon_shop_find_weapon(weapon_name: String, contract: Dictionary) -> Dictionary:
	for raw_weapon in MainSceneHelpers._safe_array(contract.get("inventory", [])):
		if typeof(raw_weapon) != TYPE_DICTIONARY:
			continue
		var weapon: Dictionary = raw_weapon as Dictionary
		var current_name: String = str(weapon.get("name", weapon.get("display_name", ""))).strip_edges()
		if current_name == weapon_name:
			return weapon.duplicate(true)
	return {}


static func _rick_weapon_shop_line_for_selected_weapon(weapon: Dictionary, contract: Dictionary) -> String:
	if weapon.is_empty():
		return "Rick squints at the wall.\nRick: \"Point at the thing, not the idea of the thing.\""

	var weapon_name: String = str(weapon.get("name", weapon.get("display_name", "that"))).strip_edges()
	var handling_line: String = str(weapon.get("rick_line", "")).strip_edges()
	var danger_scope: String = MainSceneHelpers._rick_weapon_shop_weapon_danger_scope(weapon)
	var overview: String = _rick_weapon_shop_weapon_overview(weapon, contract)
	var disaster: String = MainSceneHelpers._rick_weapon_shop_weapon_disaster_line(weapon)

	var live_lines: Array = []
	live_lines.append("Rick follows your eyes to the %s." % weapon_name)
	if handling_line != "":
		live_lines.append(handling_line)
	live_lines.append("Danger scope: %s." % danger_scope)
	live_lines.append(overview)
	live_lines.append("Rick: \"%s\"" % disaster)

	return "\n".join(live_lines)


static func _rick_weapon_shop_weapon_overview(weapon: Dictionary, contract: Dictionary) -> String:
	var commerce: Dictionary = MainSceneHelpers._safe_dictionary(contract.get("commerce", {}))
	var currency: String = str(commerce.get("currency", "coins"))
	return "%s costs %d %s. Legal status: %s. License: %s." % [
		str(weapon.get("name", weapon.get("display_name", "This weapon"))),
		int(weapon.get("cost", 0)),
		currency,
		str(weapon.get("legality_label", "Legal")),
		str(weapon.get("license_label", "No License Required"))
	]


static func _rick_weapon_shop_best_era(gs: GameState) -> String:
	if gs != null and gs.era != null:
		var era_text: String = str(gs.era.name if "name" in gs.era else gs.era).strip_edges()
		if era_text != "":
			return era_text
	return "Modern Era"


static func _rick_weapon_shop_best_country(gs: GameState) -> String:
	if gs != null and gs.player != null:
		for key in ["country", "birth_country", "current_country", "home_country"]:
			var value: String = MainSceneHelpers._rick_weapon_shop_clean_location_value(gs.player.get(key) if gs.player.has_method("get") else "")
			if value != "":
				return value

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		for key in ["country", "birth_country", "current_country", "home_country"]:
			var state_country: String = MainSceneHelpers._rick_weapon_shop_clean_location_value(gs.scenario_state.get(key, ""))
			if state_country != "":
				return state_country

	return "United States"


static func _rick_weapon_shop_best_city(gs: GameState) -> String:
	if gs != null and gs.player != null:
		for key in ["city", "birth_city", "current_city", "home_city"]:
			var value: String = MainSceneHelpers._rick_weapon_shop_clean_location_value(gs.player.get(key) if gs.player.has_method("get") else "")
			if value != "":
				return value

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		for key in ["city", "birth_city", "current_city", "home_city"]:
			var state_city: String = MainSceneHelpers._rick_weapon_shop_clean_location_value(gs.scenario_state.get(key, ""))
			if state_city != "":
				return state_city

	return "Unknown City"


static func _rick_weapon_shop_local_rick_name(country: String) -> String:
	var tag: String = MainSceneHelpers._rick_weapon_shop_local_culture_tag(country)
	if tag == "":
		return "Rick"
	if tag == "a monk":
		return "Rick but a monk"
	if tag.begins_with("from "):
		return "Rick but %s" % tag
	return "Rick but %s" % tag


static func _style_rick_weapon_shop_button(button: Button, pulse: float) -> void:
	if button == null or not is_instance_valid(button):
		return

	var btn_style: StyleBoxFlat = MainSceneHelpers._runtime_stylebox_flat_from_meta(button, "rick_weapon_shop_button_style", 2, 16)
	if btn_style == null:
		return

	button.text = "🔫"
	button.tooltip_text = "Open Rick's Universal Weapon Shop"
	button.add_theme_font_size_override("font_size", 28)
	button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))

	btn_style.bg_color = Color(0.34, 0.18, 0.08, 0.22 + (pulse * 0.12))
	btn_style.border_color = Color(1.0, 0.62, 0.24, 0.55 + (pulse * 0.3))
	button.add_theme_stylebox_override("normal", btn_style)
	button.add_theme_stylebox_override("hover", btn_style)
	button.add_theme_stylebox_override("pressed", btn_style)


static func _create_spirit_world_avatar_echo(gs: GameState,
	actor: Person, avatar_record: Dictionary = {}) -> Person:
	if gs == null or actor == null:
		return null
	if gs.npc_factory == null:
		return null

	var echo: Person = gs.npc_factory.create_random_npc()
	if echo == null:
		return null

	var element: String = str(avatar_record.get("native_element", "")).strip_edges().to_lower()
	if element == "" and gs.bending_engine != null and gs.bending_engine.has_method("_bending_person_primary_element"):
		element = str(gs.bending_engine.call("_bending_person_primary_element", actor)).strip_edges().to_lower()

	if element not in ["air", "water", "earth", "fire"]:
		element = ["air", "water", "earth", "fire"].pick_random()

	var avatar_name: String = str(avatar_record.get("name", "Avatar Echo")).strip_edges()
	if avatar_name == "":
		avatar_name = "Avatar Echo"

	echo.first_name = avatar_name
	echo.last_name = ""
	echo.age = max(24, int(actor.age) + 20)
	echo.alive = true
	echo.health = max(90, int(actor.health) + 20)
	echo.mental_health = 100
	echo.smarts = max(80, int(actor.smarts))
	echo.ambition = max(75, int(actor.ambition))
	echo.motivation = max(85, int(actor.motivation))
	echo.bending_type = "avatar"
	echo.bending_nation = str(actor.bending_nation)

	var actor_level: int = _spirit_world_actor_bending_level(gs, actor, element)
	var avatar_score: int = int(avatar_record.get("spirit_score", actor_level + 18))
	var echo_level: int = clamp(max(actor_level + 18, avatar_score), 35, 120)

	if gs.bending_engine != null and gs.bending_engine.has_method("force_bending_type"):
		gs.bending_engine.force_bending_type(echo, element, echo_level)

	echo.bending_type = "avatar"
	echo.bending_nation = str(actor.bending_nation)

	if typeof(echo.bending_mastery) == TYPE_DICTIONARY:
		for base_element in ["air", "water", "earth", "fire"]:
			var base_value: int = int(echo.bending_mastery.get(base_element, 0))
			if base_element == element:
				echo.bending_mastery [base_element] = max(base_value, echo_level)
			else:
				echo.bending_mastery [base_element] = max(base_value, clamp(echo_level - 18, 25, 100))

	if "willpower_engine" in gs and gs.willpower_engine != null and gs.willpower_engine.has_method("ensure_willpower"):
		gs.willpower_engine.ensure_willpower(echo, {
			"source": "spirit_world_echo_spawn",
			"duel_scope": "bending",
			"previous_avatar_name": avatar_name,
			"previous_avatar_element": element
		})

	if "npcs" in gs and typeof(gs.npcs) == TYPE_ARRAY and echo not in gs.npcs:
		gs.npcs.append(echo)

	return echo


static func _spirit_world_previous_avatar_records(gs: GameState,
	actor: Person) -> Array:
	if gs == null or actor == null:
		return []

	if "avatar_influence_engine" in gs and gs.avatar_influence_engine != null:
		if gs.avatar_influence_engine.has_method("_previous_avatar_records_for"):
			var records_raw: Variant = gs.avatar_influence_engine.call("_previous_avatar_records_for", actor)
			if typeof(records_raw) == TYPE_ARRAY:
				return records_raw

	return []


static func _spirit_world_actor_bending_level(gs: GameState,
	actor: Person, element: String = "") -> int:
	if actor == null:
		return 1

	var clean_element: String = str(element).strip_edges().to_lower()
	if clean_element == "":
		clean_element = "fire"

	if gs != null and gs.bending_engine != null and gs.bending_engine.has_method("get_bending_level"):
		return int(gs.bending_engine.call("get_bending_level", actor, clean_element))

	if typeof(actor.bending_mastery) == TYPE_DICTIONARY:
		return int(actor.bending_mastery.get(clean_element, 1))

	return 1


static func _spirit_world_avatar_path_combat_ui(gs: GameState,
	actor: Person, context: Dictionary = {}) -> Dictionary:
	var active_element: String = str(context.get("active_element", "avatar")).strip_edges().to_lower()
	var phase: String = str(context.get("phase", "threshold")).strip_edges().to_lower()
	var status_text: String = str(context.get("status_text", "Spirit World • Avatar Cycle")).strip_edges()

	return {
		"visible": true,
		"theme": "bending_avatar",
		"status_text": status_text,
		"player_label": "%s • Living Avatar" % MainSceneHelpers._spirit_world_person_label(actor),
		"player_value": clamp(_spirit_world_actor_bending_level(gs, actor, active_element), 1, 120),
		"player_max": 120,
		"enemy_label": "The Avatar Cycle • Listening",
		"enemy_value": 100,
		"enemy_max": 100,
		"player_avatar_pulse": true,
		"enemy_avatar_pulse": true,
		"spirit_world": true,
		"phase": phase,
		"impact_shake": true,
		"impact_shake_amount": 4.0,
		"elemental_screen_damage": {
			"enabled": true,
			"screen_damage": "soft",
			"screen_damage_intensity": 0.28,
			"screen_fracture": false,
			"screen_bleed": false,
			"time_dilation": 0.82,
			"audio_muffle": 0.18,
			"element": active_element,
			"finish_move": "Spirit World crossing",
			"motion": "avatar_cycle_veil_breathe"
		},
		"surge_vector": {
			"enabled": true,
			"direction": "cycle_to_avatar",
			"origin_id": -1,
			"target_id": int(actor.id) if actor != null else -1,
			"element": active_element,
			"mode": "spiritual_threshold",
			"text": "The Avatar Cycle bends softly around you."
		}
	}


static func _begin_spirit_world_avatar_duel(gs: GameState,
	actor: Person, avatar_record: Dictionary) -> Dictionary:
	var echo: Person = _create_spirit_world_avatar_echo(gs, actor, avatar_record)
	if echo == null:
		return {
			"type": "scenario_commit_complete",
			"text": "The Spirit World duel could not begin because no echo formed.",
			"popup_title": "Spirit World",
			"popup_text": "The previous Avatar's echo flickered but never fully arrived.",
			"popup_footer": "Tap anywhere to continue.",
			"opps": []
		}

	var avatar_name: String = str(avatar_record.get("name", ("%s %s" % [echo.first_name, echo.last_name]).strip_edges()))
	var avatar_element: String = str(avatar_record.get("native_element", "avatar")).strip_edges().to_lower()

	var duel_scenario: Dictionary = {
		"id": "spirit_world_duel_%d_%d" % [int(actor.id), int(Time.get_ticks_msec())],
		"source": "scenario_engine",
		"category": "bending",
		"target_id": int(echo.id),
		"bending_duel_target_id": int(echo.id),
		"bending_duel_target_name": avatar_name,
		"previous_avatar_name": avatar_name,
		"previous_avatar_element": avatar_element,
		"combat_ui": _spirit_world_avatar_path_combat_ui(gs, actor, {
			"status_text": "Spirit World Duel • %s" % avatar_name,
			"phase": "avatar_duel_start",
			"active_element": avatar_element
		}),
		"bending_duel_contract": {
			"schema": "eralife.spirit_world_bending_duel_contract",
			"version": 2,
			"source": "spirit_world",
			"uses_scenario_panel": true,
			"damage_reflects_on_stats": false,
			"world_feed_enabled": false,
			"previous_avatar_name": avatar_name,
			"previous_avatar_element": avatar_element
		}
	}

	return _spirit_world_begin_bending_duel(gs, actor, echo, duel_scenario)


static func _spirit_world_queue_external_scenario(gs: GameState,
	scenario: Dictionary) -> Dictionary:
	if gs == null or gs.scenario_engine == null:
		return {
			"success": false,
			"popup_title": "Scenario Runtime Missing",
			"popup_text": "ScenarioEngine is unavailable.",
			"popup_footer": "Tap anywhere to continue."
		}

	if not gs.scenario_engine.has_method("queue_external_scenario"):
		return {
			"success": false,
			"popup_title": "Scenario Runtime Missing",
			"popup_text": "ScenarioEngine.queue_external_scenario() is unavailable.",
			"popup_footer": "Tap anywhere to continue."
		}

	var queued_result: Variant = gs.scenario_engine.call("queue_external_scenario", scenario)
	if typeof(queued_result) == TYPE_DICTIONARY:
		return queued_result

	return {
		"success": false,
		"popup_title": "Scenario Runtime Missing",
		"popup_text": "ScenarioEngine.queue_external_scenario() did not return a Dictionary.",
		"popup_footer": "Tap anywhere to continue."
	}


static func _spirit_world_begin_bending_duel(gs: GameState,
	actor: Person, target: Person, duel_scenario: Dictionary) -> Dictionary:
	if gs == null or gs.scenario_engine == null:
		return {
			"type": "scenario_commit_complete",
			"text": "The Spirit World duel could not begin because ScenarioEngine was unavailable.",
			"popup_title": "Spirit World Duel",
			"popup_text": "The previous Avatar stepped forward, but the duel runtime was missing.",
			"popup_footer": "Tap anywhere to continue.",
			"opps": []
		}

	if gs.scenario_engine.has_method("_begin_bending_duel_scenario"):
		var duel_result: Variant = gs.scenario_engine.call("_begin_bending_duel_scenario", actor, target, duel_scenario)
		if typeof(duel_result) == TYPE_DICTIONARY:
			return duel_result

	if gs.scenario_engine.has_method("queue_external_scenario"):
		var fallback_scenario: Dictionary = duel_scenario.duplicate(true)
		fallback_scenario ["resolver_owner"] = "scenario_engine"
		fallback_scenario ["resolver_method"] = "_resolve_bending_duel_choice"
		fallback_scenario ["panel_title"] = str(fallback_scenario.get("panel_title", "SPIRIT WORLD DUEL"))
		fallback_scenario ["footer_text"] = str(fallback_scenario.get("footer_text", "The previous Avatar waits."))
		fallback_scenario ["prompt"] = str(fallback_scenario.get("prompt", "%s steps forward through the veil.\n\nThe duel begins when you accept." % MainSceneHelpers._spirit_world_person_label(target)))
		fallback_scenario ["choices"] = [
			{
				"id": "bending_duel_accept",
				"label": "Begin the spiritual duel",
				"journal_text": "I began a spiritual duel with a previous Avatar.",
				"choice_family": "duel",
				"button_theme": "bending_ability",
				"power_source": "spirit_world",
				"bending_duel_target_id": int(target.id)
			},
			{
				"id": "bending_duel_decline",
				"label": "Step back",
				"journal_text": "I stepped back from the spiritual duel.",
				"choice_family": "leave",
				"button_theme": "defensive_escape",
				"power_source": "survival",
				"bending_duel_target_id": int(target.id)
			}
		]
		return _spirit_world_queue_external_scenario(gs, fallback_scenario)

	return {
		"type": "scenario_commit_complete",
		"text": "The Spirit World duel could not begin because no compatible duel route was available.",
		"popup_title": "Spirit World Duel",
		"popup_text": "The previous Avatar waited, but the duel runtime could not accept the scenario.",
		"popup_footer": "Tap anywhere to continue.",
		"opps": []
	}


static func _bending_hub_default_player_element(gs: GameState) -> String:
	if gs == null or gs.player == null:
		return ""

	var p:= gs.player
	var bending_type: String = str(p.bending_type).strip_edges().to_lower()

	if bending_type in ["air", "water", "earth", "fire"]:
		return bending_type

	if gs.bending_engine != null:
		var best_element: String = ""
		var best_score: float = -999999.0

		for element in ["air", "water", "earth", "fire"]:
			var level: int = int(gs.bending_engine.get_bending_level(p, element))
			var potential: int = 0
			if gs.bending_engine.has_method("get_bending_latent_potential"):
				potential = int(gs.bending_engine.get_bending_latent_potential(p, element))

			var score: float = float(potential) - (float(level) * 0.65)
			if level <= 0:
				score += 6.0

			if score > best_score:
				best_score = score
				best_element = element

		return best_element

	return ""


static func _player_has_visible_wizard_magic(gs: GameState) -> bool:
	if gs == null or gs.player == null:
		return false

	if gs.wizard_engine == null:
		return false
	if not gs.wizard_engine.has_method("has_wizard_magic"):
		return false
	return gs.wizard_engine.has_wizard_magic(gs.player)


static func _wizard_hub_signature(gs: GameState) -> String:
	if gs == null or gs.player == null:
		return "no-player"
	var profile: Dictionary = gs.player.wizard_profile if typeof(gs.player.wizard_profile) == TYPE_DICTIONARY else {}
	var skill: Dictionary = profile.get("skill", {}) if typeof(profile.get("skill", {})) == TYPE_DICTIONARY else {}
	var wand: Dictionary = profile.get("wand", {}) if typeof(profile.get("wand", {})) == TYPE_DICTIONARY else {}
	var competition: Dictionary = profile.get("competition", {}) if typeof(profile.get("competition", {})) == TYPE_DICTIONARY else {}
	return "%s|%s|%s|%s|%s|%s|%s|%s" % [
		str(profile.get("magic_status", "")),
		str(profile.get("wizard_blood_status", "")),
		str(profile.get("full_wizard", false)),
		str(wand.get("name", "")),
		str(wand.get("level", 0)),
		str(skill.get("spellcraft", 0)),
		str(skill.get("spell_theory", 0)),
		str(competition.get("available", false))
	]


static func _belongings_projection_has_asset(gs: GameState,
	actor: Person, category: String, asset_id: int) -> bool:
	if actor == null or gs == null or gs.belongings_engine == null:
		return false
	if asset_id <= 0:
		return false

	var clean_category: String = str(category).strip_edges()
	if clean_category == "":
		return false

	var existing_items: Array = gs.belongings_engine.get_category_items(actor, clean_category)
	for raw_item in existing_items:
		if typeof(raw_item) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = raw_item as Dictionary
		if int(item.get("id", -1)) == asset_id:
			return true

	return false


static func _baseline_property_context_for_actor(gs: GameState,
	actor: Person, reason: String = "") -> Dictionary:
	return {
		"source": "controlled_actor_baseline_property_projection",
		"reason": str(reason),
		"era_name": _baseline_property_era_name(gs),
		"social_tier": MainSceneHelpers._baseline_property_social_tier_for_actor(actor),
		"desired_tags": _baseline_property_desired_tags_for_actor(actor),
		"price_override": 0,
	}


static func _baseline_property_desired_tags_for_actor(actor: Person) -> Array:
	var tier: String = MainSceneHelpers._baseline_property_social_tier_for_actor(actor)
	match tier:
		"working":
			return ["small", "shelter", "modest", "residence"]
		"wealthy":
			return ["large", "luxury", "residence"]
		"royal":
			return ["royal", "palace", "estate", "residence"]
		"noble":
			return ["estate", "mansion", "residence"]
		_:
			return ["residence", "home"]


static func _baseline_property_legacy_size_for_actor(actor: Person) -> String:
	match MainSceneHelpers._baseline_property_social_tier_for_actor(actor):
		"working":
			return "Small"
		"wealthy":
			return "Large"
		"royal":
			return "Royal"
		"noble":
			return "Mansion"
		_:
			return "Medium"


static func _baseline_property_era_name(gs: GameState) -> String:
	if gs == null:
		return "Modern Era"
	if gs.era != null:
		var era_name: String = str(gs.era.name).strip_edges()
		if era_name != "":
			return era_name
	return "Modern Era"


static func _player_has_named_artifact(gs: GameState,
	item_name: String) -> bool:
	if gs == null or gs.player == null or gs.belongings_engine == null:
		return false
	return gs.belongings_engine.has_item_named(gs.player, "Artifacts", item_name)


static func _player_has_red_bonnet_artifact(gs: GameState) -> bool:
	return _player_has_named_artifact(gs, "Red Bonnet")


static func _player_has_infinity_gauntlet_artifact(gs: GameState) -> bool:
	return _player_has_named_artifact(gs, "Infinity Gauntlet")


static func _world_feed_display_dedupe_key(gs: GameState,
	entry: Dictionary) -> String:
	if typeof(entry) != TYPE_DICTIONARY or entry.is_empty():
		return ""

	return "%s|%s|%s|%d" % [
		str(entry.get("event_name", "")).strip_edges(),
		str(entry.get("tournament_id", "")).strip_edges(),
		str(entry.get("world_text", entry.get("text", ""))).strip_edges(),
		int(entry.get("year", gs.year if gs != null else 0))
	]


static func _is_personally_relevant_relic_feed_entry(gs: GameState,
	entry: Dictionary) -> bool:
	var normalized: Dictionary = entry
	if gs != null:
		normalized = gs.normalize_world_feed_entry(entry)

	if not bool(normalized.get("personally_relevant", false)):
		return false

	var event_name: String = str(normalized.get("event_name", "")).strip_edges()
	var category: String = str(normalized.get("category", "")).strip_edges().to_lower()
	var text: String = str(normalized.get("text", "")).to_lower()

	if category == "artifact":
		return true
	if text.findn("infinity stone") != -1:
		return true
	if text.findn("red bonnet") != -1:
		return true
	if text.findn("infinity gauntlet") != -1:
		return true
	if event_name == "red_bonnet_acquired" or event_name == "red_bonnet_rumor":
		return true
	if event_name == str(ActionEventTypes.GAUNTLET_FORGED):
		return true
	return false


static func _build_artifact_card_style(item: Dictionary, aura_strength: float) -> StyleBoxFlat:
	var accent: Color = MainSceneHelpers._artifact_item_color(item)
	var item_name: String = str(item.get("name", "")).strip_edges().to_lower()

	var style:= StyleBoxFlat.new()
	var base_bg: Color = Color(0.08, 0.1, 0.14, 0.94).lerp(Color(accent.r, accent.g, accent.b, 0.16), 0.18)

	if item_name.findn("gauntlet") != -1:
		base_bg = base_bg.lerp(Color(1.0, 0.96, 0.78, base_bg.a), 0.1 * aura_strength)
	elif item_name.findn("red bonnet") != -1:
		base_bg = base_bg.lerp(Color(0.3, 0.09, 0.1, base_bg.a), 0.18 * aura_strength)

	style.bg_color = base_bg
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(accent.r, accent.g, accent.b, 0.38 + aura_strength * 0.34)
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.14 + aura_strength * 0.24)
	style.shadow_size = 5 + int(round(aura_strength * 6.0))
	style.shadow_offset = Vector2(0, 0)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	return style


static func _build_artifact_button_style(item: Dictionary, aura_strength: float, is_hovered: bool = false) -> StyleBoxFlat:
	var accent: Color = MainSceneHelpers._artifact_item_color(item)
	var item_name: String = str(item.get("name", "")).strip_edges().to_lower()
	var style:= StyleBoxFlat.new()
	var bg_alpha: float = 0.1 + aura_strength * 0.1 + (0.06 if is_hovered else 0.0)
	var border_alpha: float = 0.5 + aura_strength * 0.3 + (0.1 if is_hovered else 0.0)
	var glow_alpha: float = 0.18 + aura_strength * 0.24 + (0.08 if is_hovered else 0.0)
	var bg_color: Color = Color(accent.r, accent.g, accent.b, bg_alpha)

	if item_name.findn("gauntlet") != -1:
		bg_color = bg_color.lerp(Color(1.0, 0.96, 0.78, bg_color.a), 0.16 * aura_strength)
	elif item_name.findn("red bonnet") != -1:
		bg_color = bg_color.lerp(Color(1.0, 0.3, 0.3, bg_color.a), 0.12 * aura_strength)

	style.bg_color = bg_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(accent.r, accent.g, accent.b, border_alpha)
	style.shadow_color = Color(accent.r, accent.g, accent.b, glow_alpha)
	style.shadow_size = 6 + int(round(aura_strength * 4.0)) + (1 if is_hovered else 0)
	style.shadow_offset = Vector2(0, 0)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	return style


static func _build_red_bonnet_wish_button_style(aura_strength: float, is_hovered: bool = false) -> StyleBoxFlat:
	var accent:= MainSceneHelpers._artifact_item_color({
		"name": "Red Bonnet",
		"color": "red"
	})
	var gold:= Color(1.0, 0.84, 0.36, 1.0)

	var style:= StyleBoxFlat.new()
	var bg_alpha: float = 0.22 + aura_strength * 0.16 + (0.08 if is_hovered else 0.0)
	var border_alpha: float = 0.62 + aura_strength * 0.22 + (0.1 if is_hovered else 0.0)
	var glow_alpha: float = 0.28 + aura_strength * 0.3 + (0.1 if is_hovered else 0.0)

	var bg_color:= Color(0.42, 0.08, 0.1, bg_alpha)
	bg_color = bg_color.lerp(Color(gold.r, gold.g, gold.b, bg_alpha), 0.1 + aura_strength * 0.06)

	style.bg_color = bg_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(gold.r, gold.g, gold.b, border_alpha).lerp(
		Color(accent.r, accent.g, accent.b, border_alpha),
		0.42
	)
	style.shadow_color = Color(accent.r, accent.g, accent.b, glow_alpha)
	style.shadow_size = 10 + int(round(aura_strength * 6.0)) + (2 if is_hovered else 0)
	style.shadow_offset = Vector2(0, 0)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	return style


static func _resolve_player_crown_pressure(gs: GameState) -> Dictionary:
	if gs == null or gs.player == null:
		return {}
	if typeof(gs.transient_scenario_biases) != TYPE_DICTIONARY:
		return {}
	var raw_bias: Variant = gs.transient_scenario_biases.get(int(gs.player.id), {})
	var bias: Dictionary = {}
	if typeof(raw_bias) == TYPE_ARRAY:
		var bucket: Array = raw_bias
		if not bucket.is_empty() and typeof(bucket [0]) == TYPE_DICTIONARY:
			bias = bucket [0]
	elif typeof(raw_bias) == TYPE_DICTIONARY:
		bias = raw_bias
	var faction_pressure_raw: Variant = bias.get("faction_pressure", {})
	return faction_pressure_raw if typeof(faction_pressure_raw) == TYPE_DICTIONARY else {}


static func _resolve_player_realm_dict(gs: GameState) -> Dictionary:
	if gs == null or gs.player == null or gs.realm_engine == null:
		return {}

	var preferred_city: String = str(gs.player.home_city if str(gs.player.home_city).strip_edges() != "" else gs.player.birth_city).strip_edges()

	var realm_id: int = int(gs.player.realm_id)
	if realm_id > 0 and gs.realm_engine.realms.has(realm_id):
		if gs.realm_engine.has_method("ensure_realm_population_surface_contract"):
			gs.realm_engine.ensure_realm_population_surface_contract(realm_id, preferred_city, {
				"source": "mainscene_player_realm_contract_resolution",
				"ui_is_renderer": true
			})

		var direct_raw: Variant = gs.realm_engine.realms.get(realm_id, {})
		var direct_realm: Dictionary = direct_raw if typeof(direct_raw) == TYPE_DICTIONARY else {}
		if not direct_realm.is_empty():
			return direct_realm

	var candidate_names: Array = []
	for raw_name in [
		str(gs.player.home_country).strip_edges(),
		str(gs.player.birth_country).strip_edges(),
		str(gs.player.bending_nation).strip_edges()
	]:
		var clean_name: String = str(raw_name).strip_edges()
		if clean_name != "" and not candidate_names.has(clean_name):
			candidate_names.append(clean_name)

	for preferred_name in candidate_names:
		var ensured_realm_id: int = -1
		if gs.realm_engine.has_method("ensure_realm_for_country"):
			ensured_realm_id = gs.realm_engine.ensure_realm_for_country(preferred_name, preferred_city)

		if ensured_realm_id <= 0:
			continue

		gs.player.realm_id = ensured_realm_id

		if gs.realm_engine.has_method("ensure_realm_population_surface_contract"):
			gs.realm_engine.ensure_realm_population_surface_contract(ensured_realm_id, preferred_city, {
				"source": "mainscene_player_realm_contract_resolution_from_country",
				"ui_is_renderer": true
			})

		var ensured_raw: Variant = gs.realm_engine.realms.get(ensured_realm_id, {})
		var ensured_realm: Dictionary = ensured_raw if typeof(ensured_raw) == TYPE_DICTIONARY else {}
		if not ensured_realm.is_empty():
			return ensured_realm

	return {}


static func _person_has_government_command_surface_access(gs: GameState,
	person: Person) -> bool:
	if person == null:
		return false

	var office_raw: Variant = person.get("civic_office_contract")
	if typeof(office_raw) == TYPE_DICTIONARY:
		var office: Dictionary = (office_raw as Dictionary).duplicate(true)
		var government_model: String = str(office.get("government_model", "")).strip_edges().to_lower()
		var office_name: String = str(office.get("office", "")).strip_edges().to_lower()
		var office_title: String = str(office.get("office_full_title", "")).strip_edges().to_lower()
		var branch_name: String = str(office.get("branch", "")).strip_edges().to_lower()

		if bool(office.get("ruling_power_by_office", false)):
			return true

		if bool(office.get("crown_hub_access", false)):
			return true

		if bool(office.get("government_command_surface_access", false)):
			return true

		if branch_name == "executive" and office_name != "":
			return true

		if government_model in [
			"federal_presidential_republic",
			"federal_republic",
			"presidential_republic",
			"constitutional_republic",
			"democracy",
			"republic"
		] and office_name in [
			"president",
			"prime minister",
			"chancellor",
			"governor",
			"executive"
		]:
			return true

		if office_title in [
			"the president of the united states",
			"president of the united states",
			"prime minister",
			"chancellor",
			"governor"
		]:
			return true

	var civic_title: String = str(person.get("civic_title")).strip_edges().to_lower()
	var job_text: String = str(person.job).strip_edges().to_lower()

	if civic_title in [
		"president",
		"prime minister",
		"chancellor",
		"governor"
	]:
		return true

	if job_text in [
		"president",
		"president of the united states",
		"prime minister",
		"chancellor",
		"governor"
	]:
		return true

	if bool(person.is_ruler) and not bool(person.is_royal):
		var social_class: String = str(person.social_class).strip_edges()
		if social_class not in ["Royal", "Noble"]:
			return true

	if gs != null and gs.has_method("get_npc_facts_by_id"):
		var facts: Dictionary = gs.get_npc_facts_by_id(int(person.id))
		if bool(facts.get("government_command_surface_access", false)):
			return true

		var facts_office_raw: Variant = facts.get("civic_office_contract", {})
		if typeof(facts_office_raw) == TYPE_DICTIONARY:
			var facts_office: Dictionary = (facts_office_raw as Dictionary).duplicate(true)
			if bool(facts_office.get("ruling_power_by_office", false)):
				return true
			if bool(facts_office.get("crown_hub_access", false)):
				return true
			if bool(facts_office.get("government_command_surface_access", false)):
				return true

			var facts_government_model: String = str(facts_office.get("government_model", "")).strip_edges().to_lower()
			var facts_office_name: String = str(facts_office.get("office", "")).strip_edges().to_lower()
			var facts_branch_name: String = str(facts_office.get("branch", "")).strip_edges().to_lower()

			if facts_branch_name == "executive" and facts_office_name != "":
				return true

			if facts_government_model in [
				"federal_presidential_republic",
				"federal_republic",
				"presidential_republic",
				"constitutional_republic",
				"democracy",
				"republic"
			] and facts_office_name in [
				"president",
				"prime minister",
				"chancellor",
				"governor",
				"executive"
			]:
				return true

	return false


static func _resolve_player_government_style(gs: GameState) -> String:
	var realm: Dictionary = _resolve_player_realm_dict(gs)
	var style: String = str(realm.get("government_style", "")).strip_edges()
	if style != "":
		return style

	if gs != null and gs.player != null:
		var office_raw: Variant = gs.player.get("civic_office_contract")
		if typeof(office_raw) == TYPE_DICTIONARY:
			var office: Dictionary = office_raw
			var government_model: String = str(office.get("government_model", "")).strip_edges().to_lower()
			match government_model:
				"federal_presidential_republic", "federal_republic":
					return "Federal Republic"
				"presidential_republic", "constitutional_republic", "republic":
					return "Republic"
				"democracy":
					return "Democracy"
				"dictatorship":
					return "Dictatorship"

		if _person_has_government_command_surface_access(gs, gs.player):
			return "Federal Republic" if _player_is_federal_republic_office_holder(gs) else "State"

		if bool(gs.player.is_ruler) or bool(gs.player.is_royal):
			return "Monarchy"

	return "State"


static func _player_has_bending_power_source(gs: GameState) -> bool:
	if gs == null or gs.player == null:
		return false

	var bending_type: String = str(gs.player.bending_type).strip_edges().to_lower()
	if bending_type != "" and bending_type != "none":
		return true

	if typeof(gs.player.bending_mastery) == TYPE_DICTIONARY:
		for raw_key in gs.player.bending_mastery.keys():
			if int(gs.player.bending_mastery.get(raw_key, 0)) > 0:
				return true

	return false


static func _invalidate_super_runtime_surface_cache(gs: GameState,
	reason: String = "changed") -> void:
	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state.erase("super_runtime_surface_cache")
		gs.scenario_state ["super_runtime_surface_cache_invalidated_reason"] = reason
		gs.scenario_state ["super_runtime_surface_cache_invalidated_at_ms"] = int(Time.get_ticks_msec())


static func _crown_hub_depth_style(target: Control, meta_key: String, layer: String, accent: Color, selected: bool = false, danger: bool = false) -> StyleBoxFlat:
	var radius: int = 16
	var border_width: int = 1
	var bg: Color = Color(0.06, 0.07, 0.11, 0.92)
	var border: Color = Color(accent.r, accent.g, accent.b, 0.32)

	match layer:
		"tabs":
			radius = 15
			border_width = 2
			bg = Color(accent.r, accent.g, accent.b, 0.3 if selected else 0.12)
			border = Color(accent.r, accent.g, accent.b, 0.94 if selected else 0.38)
		"raised":
			radius = 20
			border_width = 2
			bg = Color(0.09, 0.08, 0.13, 0.96)
			border = Color(accent.r, accent.g, accent.b, 0.62)
		"recessed":
			radius = 18
			border_width = 1
			bg = Color(0.035, 0.043, 0.066, 0.96)
			border = Color(accent.r, accent.g, accent.b, 0.24)
		"lowest":
			radius = 12
			border_width = 1
			bg = Color(0.025, 0.03, 0.045, 0.94)
			border = Color(accent.r, accent.g, accent.b, 0.16)
		"danger":
			radius = 18
			border_width = 2
			bg = Color(0.17, 0.035, 0.045, 0.96)
			border = Color(1.0, 0.2, 0.16, 0.82)
		_:
			pass

	if danger:
		bg = Color(0.16, 0.035, 0.045, 0.96)
		border = Color(1.0, 0.24, 0.18, 0.86)

	var style: StyleBoxFlat = MainSceneHelpers._runtime_stylebox_flat_from_meta(target, meta_key, border_width, radius)
	if style == null:
		style = StyleBoxFlat.new()

	style.bg_color = bg
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.border_color = border
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius

	return style


static func _crown_hub_identity_line(gs: GameState,
	summary: Dictionary) -> String:
	var title_text: String = str(summary.get("title", gs.player.royal_title if gs != null and gs.player != null else "Ruler")).strip_edges()
	var realm_name: String = str(summary.get("realm_name", gs.player.home_country if gs != null and gs.player != null else "Realm")).strip_edges()

	if bool(summary.get("federal_republic", false)):
		if title_text == "":
			title_text = "Federal Officer"
		if realm_name == "":
			realm_name = "the United States"
		return "You are %s in %s" % [title_text, realm_name]

	if title_text == "":
		title_text = "Ruler"
	if realm_name == "":
		realm_name = "the Realm"

	return "You are %s of %s" % [title_text, realm_name]


static func _player_is_federal_republic_office_holder(gs: GameState) -> bool:
	if gs == null or gs.player == null:
		return false

	var office: Dictionary = gs.player.get("civic_office_contract")
	if typeof(office) == TYPE_DICTIONARY:
		if str(office.get("government_model", "")).strip_edges() == "federal_presidential_republic":
			return true

	var job_text: String = str(gs.player.job).strip_edges().to_lower()
	return job_text == "president of the united states" or job_text == "president"


static func _crown_population_promotion_ceiling_seed(gs: GameState) -> String:
	if gs == null or gs.player == null:
		return ""

	var p: Person = gs.player
	if bool(p.is_ruler):
		return "Heir Line"

	var clean_title:= str(p.royal_title).strip_edges().to_lower()
	if int(p.succession_rank) == 1 or clean_title.find("heir") != -1 or clean_title.find("crown") != -1:
		return "Royal Child"

	if bool(p.is_royal) or str(p.royal_title).strip_edges() != "":
		return "Lesser Royal"

	return ""


static func _build_crown_population_promotion_options(gs: GameState,
	target: Person) -> Array:
	var out: Array = []
	if target == null:
		return out

	var ceiling_seed:= _crown_population_promotion_ceiling_seed(gs)
	if ceiling_seed == "":
		return out

	var option_rows: Array = []
	if gs != null and gs.royalty_engine != null and gs.royalty_engine.has_method("get_spawnable_royal_rank_options"):
		option_rows = gs.royalty_engine.get_spawnable_royal_rank_options(
			_crown_realm_name(gs, int(target.realm_id)),
			""
		)

	if option_rows.is_empty():
		option_rows = [
			{ "seed": "Royal Child", "label": "Prince / Princess"},
			{ "seed": "Heir Line", "label": "Crown Prince / Crown Princess"},
			{ "seed": "Lesser Royal", "label": "Duke / Duchess"}
		]

	for raw_row in option_rows:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = raw_row
		var seed_text:= str(row.get("seed", "")).strip_edges()
		if seed_text == "":
			continue

		if ceiling_seed == "Lesser Royal" and seed_text != "Lesser Royal":
			continue
		if ceiling_seed == "Royal Child" and seed_text == "Heir Line":
			continue

		out.append(row)

	return out


static func _apply_crown_population_promotion(gs: GameState,
	target: Person, rank_seed: String) -> String:
	if target == null or gs == null or gs.player == null:
		return ""

	var normalized_seed:= str(rank_seed).strip_edges()
	if gs.royalty_engine != null and gs.royalty_engine.has_method("_normalize_royal_rank_seed"):
		normalized_seed = str(gs.royalty_engine.call("_normalize_royal_rank_seed", normalized_seed)).strip_edges()
	if normalized_seed == "":
		normalized_seed = "Lesser Royal"

	target.is_ruler = false
	target.is_royal = true
	target.deposed = false
	target.exiled = false
	target.realm_id = int(gs.player.realm_id)
	target.palace_owned = false

	match normalized_seed:
		"Heir Line":
			target.social_class = "Royal"
			target.succession_rank = 1
			target.royal_title = str(gs.royalty_engine.call("_resolve_rank_title", target, "heir"))
		"Royal Child":
			target.social_class = "Royal"
			target.succession_rank = max(3, int(target.succession_rank))
			target.royal_title = str(gs.royalty_engine.call("_resolve_rank_title", target, "royal_child"))
		_:
			target.social_class = "Noble"
			target.succession_rank = max(8, int(target.succession_rank))
			target.royal_title = str(gs.royalty_engine.call("_resolve_rank_title", target, "lesser_royal"))
			normalized_seed = "Lesser Royal"

	if gs.royalty_engine != null and gs.royalty_engine.has_method("_set_royal_rank_seed_trait"):
		gs.royalty_engine.call("_set_royal_rank_seed_trait", target, normalized_seed)
	if gs.royalty_engine != null and gs.royalty_engine.has_method("_sync_royal_job_identity"):
		gs.royalty_engine.call("_sync_royal_job_identity", target)
	if gs.royalty_engine != null and gs.royalty_engine.has_method("_apply_royal_fame_floor"):
		gs.royalty_engine.call("_apply_royal_fame_floor", target)

	target.approval = min(100, int(target.approval) + 12)
	return normalized_seed


static func _belonging_popup_action_routes_to_crown_hub(
	action_spec: Dictionary
) -> bool:
	var payload: Dictionary = MainSceneHelpers._safe_dictionary(
		action_spec.get(
			"payload",
			{}
		)
	)
	var action_id: String = str(
		payload.get(
			"action",
			action_spec.get(
				"action_id",
				action_spec.get(
					"id",
					""
				)
			)
		)
	).strip_edges().to_lower()

	return action_id == "access_federal_republic_crown_hub"


static func _append_crown_war_side_column(
	parent: HBoxContainer,
	side_contract: Dictionary,
	title: String,
	accent: Color
) -> void:
	if parent == null:
		return

	var column:= VBoxContainer.new()
	column.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	column.add_theme_constant_override(
		"separation",
		8
	)
	parent.add_child(
		column
	)

	var header:= Label.new()
	header.text = title
	header.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	header.add_theme_font_size_override(
		"font_size",
		18
	)
	header.add_theme_color_override(
		"font_color",
		accent
	)
	column.add_child(
		header
	)

	for raw_card in MainSceneHelpers._safe_array(
		side_contract.get(
			"realm_cards",
			[]
		)
	):
		var card_contract: Dictionary = MainSceneHelpers._safe_dictionary(
			raw_card
		)

		if card_contract.is_empty():
			continue

		var panel:= PanelContainer.new()
		panel.size_flags_horizontal = (
			Control.SIZE_EXPAND_FILL
		)

		var panel_style:= StyleBoxFlat.new()
		panel_style.bg_color = Color(
			accent.r * 0.11,
			accent.g * 0.11,
			accent.b * 0.11,
			0.98
		)
		panel_style.border_color = Color(
			accent.r,
			accent.g,
			accent.b,
			0.86
		)
		panel_style.set_border_width_all(
			2
		)
		panel_style.set_corner_radius_all(
			14
		)
		panel.add_theme_stylebox_override(
			"panel",
			panel_style
		)
		column.add_child(
			panel
		)

		var margin:= MarginContainer.new()
		margin.add_theme_constant_override(
			"margin_left",
			12
		)
		margin.add_theme_constant_override(
			"margin_top",
			10
		)
		margin.add_theme_constant_override(
			"margin_right",
			12
		)
		margin.add_theme_constant_override(
			"margin_bottom",
			10
		)
		panel.add_child(
			margin
		)

		var body:= VBoxContainer.new()
		body.add_theme_constant_override(
			"separation",
			5
		)
		margin.add_child(
			body
		)

		var banner:= Label.new()
		banner.text = "AT WAR"
		banner.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_CENTER
		)
		banner.add_theme_font_size_override(
			"font_size",
			17
		)
		banner.add_theme_color_override(
			"font_color",
			Color(
				1.0,
				0.24,
				0.18,
				1.0
			)
		)
		body.add_child(
			banner
		)

		var name_label:= Label.new()
		name_label.text = str(
			card_contract.get(
				"name",
				"Unknown Realm"
			)
		)
		name_label.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_CENTER
		)
		name_label.add_theme_font_size_override(
			"font_size",
			20
		)
		name_label.add_theme_color_override(
			"font_color",
			accent
		)
		body.add_child(
			name_label
		)

		var stats:= Label.new()
		stats.text = (
			"Military: %s\nPopulation: %s\nTreasury: %s\nGoods: %s"
			% [
				MainSceneHelpers._crown_exact_number(
					int(
						card_contract.get(
							"military",
							0
						)
					)
				),
				MainSceneHelpers._crown_exact_number(
					int(
						card_contract.get(
							"population",
							0
						)
					)
				),
				MainSceneHelpers._crown_exact_number(
					int(
						card_contract.get(
							"treasury",
							0
						)
					)
				),
				MainSceneHelpers._crown_exact_number(
					int(
						card_contract.get(
							"goods",
							0
						)
					)
				)
			]
		)
		stats.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_CENTER
		)
		body.add_child(
			stats
		)


static func _crown_current_era_key(gs: GameState) -> String:
	if gs == null:
		return "Modern"

	if gs.era != null and typeof(gs.era) == TYPE_DICTIONARY:
		var era_name: String = str(gs.era.get("name", gs.era.get("key", ""))).strip_edges()
		if era_name != "":
			return era_name

	if gs.era_engine != null and gs.era_engine.has_method("_era_from_year"):
		var era_dict: Dictionary = gs.era_engine._era_from_year(int(gs.year))
		return str(era_dict.get("name", era_dict.get("key", "Modern")))

	return "Modern"


static func _build_crown_law_review_proposal(gs: GameState) -> Dictionary:
	var era_key: String = _crown_current_era_key(gs)
	var era_lower: String = era_key.strip_edges().to_lower()
	var pool: Array = []

	match era_lower:
		"ancient":
			pool = [
				{ "title": "Burial Ground Protection Edict", "description": "Make it illegal to hunt, loot, or hold games on burial grounds.", "risk_label": "Sacred law", "approval_on_sign": 7, "approval_on_reject": -8, "approval_on_revise": 2, "approval_on_delay": -2},
				{ "title": "Daily Parent Reverence Law", "description": "Require children to say 'I love you' to their parents every day before sunset.", "risk_label": "Goofy but popular", "approval_on_sign": 2, "approval_on_reject": 1, "approval_on_revise": 1, "approval_on_delay": 0},
				{ "title": "Anti-Government Speech Ban", "description": "Make it illegal to speak openly against the government.", "risk_label": "Authoritarian danger", "approval_on_sign": -15, "approval_on_reject": 8, "approval_on_revise": 3, "approval_on_delay": -3}
			]
		"medieval":
			pool = [
				{ "title": "Protected Orchard Law", "description": "Ban nobles from seizing common orchard harvests during winter.", "risk_label": "Pro-commoner reform", "approval_on_sign": 9, "approval_on_reject": -10, "approval_on_revise": 3, "approval_on_delay": -2},
				{ "title": "Mandatory Compliment to the Crown", "description": "Require citizens to compliment the ruler's outfit during public festivals.", "risk_label": "Deeply unserious", "approval_on_sign": -1, "approval_on_reject": 3, "approval_on_revise": 1, "approval_on_delay": 0},
				{ "title": "Forest Burial Peace Act", "description": "Make it illegal to hunt in burial woods and ancestral grave fields.", "risk_label": "Spiritual protection", "approval_on_sign": 6, "approval_on_reject": -7, "approval_on_revise": 2, "approval_on_delay": -1}
			]
		"industrial":
			pool = [
				{ "title": "Factory Child Safety Act", "description": "Limit dangerous factory work for children and require inspections.", "risk_label": "Moral reform", "approval_on_sign": 12, "approval_on_reject": -16, "approval_on_revise": 5, "approval_on_delay": -4},
				{ "title": "Anti-Whistle Law", "description": "Make factory whistles after midnight illegal unless the whistle sounds polite.", "risk_label": "Goofy nuisance law", "approval_on_sign": 1, "approval_on_reject": 2, "approval_on_revise": 1, "approval_on_delay": 0},
				{ "title": "Seditious Pamphlet Ban", "description": "Criminalize printed criticism of the government.", "risk_label": "Civil liberty crisis", "approval_on_sign": -14, "approval_on_reject": 9, "approval_on_revise": 2, "approval_on_delay": -3}
			]
		"future":
			pool = [
				{ "title": "Synthetic Memory Consent Act", "description": "Require consent before corporations can simulate a citizen's memories.", "risk_label": "Human rights protection", "approval_on_sign": 13, "approval_on_reject": -15, "approval_on_revise": 4, "approval_on_delay": -3},
				{ "title": "Mandatory Robot Thank-You Law", "description": "Require citizens to thank service robots at least once per transaction.", "risk_label": "Goofy civic etiquette", "approval_on_sign": 2, "approval_on_reject": 1, "approval_on_revise": 1, "approval_on_delay": 0},
				{ "title": "Predictive Dissent Lockdown", "description": "Allow the state to punish citizens for future anti-government speech predicted by AI.", "risk_label": "Extremely dangerous", "approval_on_sign": -22, "approval_on_reject": 14, "approval_on_revise": 2, "approval_on_delay": -5}
			]
		_:
			pool = [
				{ "title": "Burial Ground Protection Act", "description": "Make it illegal to hunt in burial grounds or profit from sacred sites.", "risk_label": "Respectful public law", "approval_on_sign": 7, "approval_on_reject": -8, "approval_on_revise": 2, "approval_on_delay": -1},
				{ "title": "Mandatory Daily Parent Affection Act", "description": "Require children to say 'I love you' to their parents every day.", "risk_label": "Goofy family law", "approval_on_sign": 1, "approval_on_reject": 2, "approval_on_revise": 1, "approval_on_delay": 0},
				{ "title": "Government Criticism Ban", "description": "Make it illegal to speak out against the government.", "risk_label": "Authoritarian danger", "approval_on_sign": -18, "approval_on_reject": 11, "approval_on_revise": 3, "approval_on_delay": -4}
			]

	var law_seed_bucket: int = int(floor(float(Time.get_ticks_msec()) / 9000.0))
	var seed_text: String = "%s.%s.%s.%s" % [
		era_key,
		str(gs.player.first_name) if gs != null and gs.player != null else "ruler",
		str(gs.player.last_name) if gs != null and gs.player != null else "realm",
		str(law_seed_bucket)
	]
	var seed_value: int = int(hash(seed_text))
	if seed_value < 0:
		seed_value = - seed_value
	if seed_value <= 0:
		seed_value = 1

	var rng:= RandomNumberGenerator.new()
	rng.seed = seed_value

	var proposal: Dictionary = pool [int(rng.randi_range(0, pool.size() - 1))].duplicate(true)
	proposal ["era"] = era_key
	proposal ["court_reading"] = "The royal court believes this law could shape public trust, fear, tradition, and legitimacy."
	proposal ["created_at_ms"] = int(Time.get_ticks_msec())
	return proposal


static func _find_crown_cached_realm_id_for_country(gs: GameState,
	country_name: String) -> int:
	if gs == null or gs.realm_engine == null:
		return -1

	var clean_country: String = str(country_name).strip_edges().to_lower()
	if clean_country == "":
		return -1

	var realms_raw: Variant = gs.realm_engine.realms
	var realms: Dictionary = realms_raw if typeof(realms_raw) == TYPE_DICTIONARY else {}

	for raw_realm_id in realms.keys():
		var realm_raw: Variant = realms.get(raw_realm_id, {})
		if typeof(realm_raw) != TYPE_DICTIONARY:
			continue

		var realm: Dictionary = realm_raw
		var candidates: Array = [
			str(realm.get("country", "")),
			str(realm.get("country_name", "")),
			str(realm.get("nation", "")),
			str(realm.get("home_country", "")),
			str(realm.get("name", ""))
		]

		for raw_candidate in candidates:
			var candidate: String = str(raw_candidate).strip_edges().to_lower()
			if candidate != "" and candidate == clean_country:
				return int(raw_realm_id)

	return -1


static func _crown_is_player_ruling_country(gs: GameState,
	country_name: String, realm_id: int = -1, realm: Dictionary = {}) -> bool:
	if gs == null or gs.player == null:
		return false

	var p:= gs.player
	if realm_id > 0 and int(p.realm_id) == realm_id:
		return true

	var realm_ruler_id: int = int(realm.get("ruler_id", realm.get("leader_id", -1)))
	if realm_ruler_id > 0 and realm_ruler_id == int(p.id):
		return true

	var clean_country: String = str(country_name).strip_edges().to_lower()
	var candidate_names: Array = [
		str(p.home_country).strip_edges().to_lower(),
		str(p.birth_country).strip_edges().to_lower(),
		str(p.bending_nation).strip_edges().to_lower(),
		str(realm.get("name", "")).strip_edges().to_lower()
	]

	for raw_name in candidate_names:
		var candidate: String = str(raw_name).strip_edges().to_lower()
		if candidate != "" and candidate == clean_country:
			return true

	return false


static func _crown_preferred_capital_for_country(gs: GameState,
	country_name: String, era_key: String) -> String:
	if gs == null:
		return ""

	var clean_country: String = str(country_name).strip_edges()
	if clean_country == "":
		return ""

	if gs.player != null and str(gs.player.home_country).strip_edges().to_lower() == clean_country.to_lower():
		var player_city: String = str(gs.player.home_city).strip_edges()
		if player_city != "":
			return player_city

	if gs.era_engine != null and gs.era_engine.has_method("get_cities_for_era_country"):
		var cities: Array = gs.era_engine.get_cities_for_era_country(era_key, clean_country)
		if not cities.is_empty():
			return str(cities [0]).strip_edges()

	return ""


static func _crown_country_ruler_label(gs: GameState,
	realm: Dictionary, country_name: String) -> String:
	if gs == null:
		return "Unknown Leader"

	var ruler_id: int = int(realm.get("ruler_id", realm.get("leader_id", -1)))
	var government_style: String = str(realm.get("government_style", "")).strip_edges()
	var fallback_name: String = str(realm.get("ruler_name", realm.get("leader_name", ""))).strip_edges()

	if ruler_id > 0:
		var ruler: Person = gs.get_or_reactivate_npc_by_id(ruler_id)
		if ruler != null:
			var full_name: String = ("%s %s" % [str(ruler.first_name), str(ruler.last_name)]).strip_edges()
			var royal_title: String = str(ruler.royal_title).strip_edges()
			if royal_title != "":
				return "%s %s" % [royal_title, full_name]

			var leader_title: String = _crown_leader_title_for_government(government_style, ruler)
			return "%s %s" % [leader_title, full_name]

	if fallback_name != "":
		return fallback_name

	return "%s Leader" % str(country_name).strip_edges()


static func _crown_leader_title_for_government(government_style: String, ruler: Person = null) -> String:
	var style: String = str(government_style).strip_edges().to_lower()

	if ruler != null:
		var job_title: String = str(ruler.job).strip_edges()
		if job_title != "" and not job_title.to_lower() in ["unemployed", "student"]:
			return MainSceneHelpers._crown_title_case(job_title)

	match style:
		"monarchy":
			return "Ruler"
		"democracy":
			return "President"
		"republic":
			return "President"
		"dictatorship":
			return "Supreme Leader"
		"communism":
			return "General Secretary"
		"anarchy":
			return "Council Speaker"
		_:
			return "Leader"


static func _format_crown_exact_treasury_label(gs: GameState,
	amount: int, currency_name: String) -> String:
	var clean_currency: String = str(currency_name).strip_edges()
	if clean_currency == "":
		clean_currency = _crown_default_currency_name_for_realm(gs, "")
	return "%s %s" % [MainSceneHelpers._crown_exact_number(amount), clean_currency]


static func _find_active_crown_person_by_id(gs: GameState,
	person_id: int) -> Person:
	if gs == null or person_id <= 0:
		return null

	if gs.player != null and int(gs.player.id) == person_id:
		return gs.player

	for raw_npc in gs.npcs:
		var npc: Person = raw_npc
		if npc != null and int(npc.id) == person_id:
			return npc

	return null


static func _crown_population_realm_element(gs: GameState,
	realm_id: int, realm_name: String = "") -> String:
	var clean_name: String = str(realm_name).strip_edges()
	if clean_name == "":
		clean_name = _crown_realm_name(gs, realm_id)

	if gs != null and gs.realm_engine != null and gs.realm_engine.has_method("_realm_element_for_name"):
		return str(gs.realm_engine._realm_element_for_name(clean_name)).strip_edges().to_lower()

	return ""


static func _is_crown_population_element_master(gs: GameState,
	target: Person, realm_id: int, element: String) -> bool:
	if target == null or not target.alive:
		return false

	var clean_element: String = str(element).strip_edges().to_lower()
	if clean_element == "":
		return false

	var bending_type: String = str(target.bending_type).strip_edges().to_lower()
	var bending_nation: String = str(target.bending_nation).strip_edges().to_lower()
	var realm_name: String = _crown_realm_name(gs, realm_id).strip_edges()
	var realm_key: String = realm_name.to_lower()

	var is_elemental_bender: bool = bending_type == clean_element or bending_type == "avatar"
	if not is_elemental_bender:
		return false

	var mastery_value: int = 0
	if typeof(target.bending_mastery) == TYPE_DICTIONARY:
		mastery_value = int(target.bending_mastery.get(clean_element, 0))

	var has_master_signal: bool = mastery_value >= 70
	has_master_signal = has_master_signal or str(target.job).strip_edges().to_lower().find("bending") >= 0
	has_master_signal = has_master_signal or "Bending Master" in target.traits

	if not has_master_signal:
		return false

	if int(target.realm_id) == realm_id:
		return true

	if bending_nation != "":
		if bending_nation == realm_key:
			return true
		if bending_nation.find(clean_element) >= 0:
			return true
		if realm_key.find(bending_nation) >= 0:
			return true

	if realm_key.find(clean_element) >= 0:
		return true

	if _crown_population_person_matches_realm(gs, target, realm_id, realm_name):
		return true

	return false


static func _crown_population_modern_citizen_role_label(gs: GameState,
	target: Person, realm_id: int, realm_name: String = "") -> String:
	if target == null:
		return "Citizen"

	if not _crown_population_uses_modern_class_lens(gs, realm_id, realm_name):
		return ""

	var social_key: String = str(target.social_class).strip_edges().to_lower()
	var job_text: String = str(target.job).strip_edges()

	if social_key in ["elite", "ultra elite", "ruling elite", "old money", "billionaire", "one percent", "1%", "rich"]:
		return "Upper-Class Citizen"

	if social_key in ["upper middle class", "upper-middle class", "upper class", "upperclass", "wealthy"]:
		return "Upper-Middle Citizen"

	if social_key in ["middle class", "middle-class", "professional"]:
		return "Middle-Class Citizen"

	if social_key in ["lower middle class", "lower-middle class", "working class", "working-class", "commoner", "merchant", "trader", "worker"]:
		if job_text != "":
			return MainSceneHelpers._crown_title_case(job_text)
		return "Working-Class Citizen"

	if social_key in ["poor", "lower class", "low class", "bottom class", "bottom-class", "struggling"]:
		return "Bottom-Class Citizen"

	if job_text != "":
		return MainSceneHelpers._crown_title_case(job_text)

	return "Citizen"


static func _crown_population_is_throne_holder(gs: GameState,
	target: Person, realm_id: int) -> bool:
	if target == null:
		return false

	if bool(target.is_ruler):
		return true

	if gs != null and gs.realm_engine != null and gs.realm_engine.realms.has(realm_id):
		var realm_raw: Variant = gs.realm_engine.realms.get(realm_id, {})
		var realm: Dictionary = realm_raw if typeof(realm_raw) == TYPE_DICTIONARY else {}
		var ruler_id: int = int(realm.get("ruler_id", -1))
		if ruler_id > 0 and int(target.id) == ruler_id:
			return true

	return false


static func _crown_population_loyalty_value(gs: GameState,
	target: Person, realm_id: int, section_kind: String) -> int:
	if target == null:
		return 0

	if _crown_population_is_throne_holder(gs, target, realm_id):
		return -1

	var realm_loyalty: int = 50
	if gs != null and gs.realm_engine != null and gs.realm_engine.realms.has(realm_id):
		var realm_raw: Variant = gs.realm_engine.realms.get(realm_id, {})
		var realm: Dictionary = realm_raw if typeof(realm_raw) == TYPE_DICTIONARY else {}
		realm_loyalty = clampi(int(realm.get("loyalty", 50)), 0, 100)

	var approval_value: int = clampi(int(target.approval), 0, 100)
	var respect_value: int = clampi(int(target.respect), 0, 100)
	var fame_value: int = clampi(int(target.fame), 0, 100)

	if section_kind == "official" or bool(target.is_royal) or int(target.succession_rank) > 0:
		return clampi(int(round((float(approval_value) * 0.62) + (float(respect_value) * 0.28) + (float(realm_loyalty) * 0.1))), 0, 100)

	return clampi(int(round((float(realm_loyalty) * 0.68) + (float(respect_value) * 0.22) + (float(fame_value) * 0.1))), 0, 100)


static func _apply_crown_population_name_button_style(button: Button, _target: Person, _section_kind: String, _accent: Color, role_accent: Color) -> void:
	if button == null:
		return

	var base_bg: Color = Color(role_accent.r * 0.11, role_accent.g * 0.1, role_accent.b * 0.12, 0.94)
	var normal_border: Color = Color(role_accent.r, role_accent.g, role_accent.b, 0.46)
	var hover_border: Color = Color(1.0, 0.91, 0.72, 1.0)

	button.add_theme_stylebox_override("normal", MainSceneHelpers._crown_population_button_style(base_bg, normal_border, false, false))
	button.add_theme_stylebox_override("hover", MainSceneHelpers._crown_population_button_style(base_bg.lerp(Color(1.0, 0.91, 0.72, 0.96), 0.16), hover_border, true, false))
	button.add_theme_stylebox_override("pressed", MainSceneHelpers._crown_population_button_style(base_bg.lerp(Color(1.0, 0.78, 0.34, 0.98), 0.2), Color(1.0, 0.78, 0.34, 1.0), true, false))
	button.add_theme_stylebox_override("disabled", MainSceneHelpers._crown_population_button_style(base_bg, normal_border, false, true))
	button.add_theme_color_override("font_color", Color(0.96, 0.92, 0.84, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.82, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.88, 0.52, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(1.0, 0.92, 0.5, 0.86))


static func _crown_population_bloodline_color(target: Person, fallback: Color) -> Color:
	var key: String = MainSceneHelpers._crown_population_bloodline_key(target)
	var bloodline_hash: int = abs(int(hash(key)))

	var r_bucket: int = bloodline_hash % 47
	var g_bucket: int = floori(float(bloodline_hash) / 47.0) % 47
	var b_bucket: int = floori(float(bloodline_hash) / 2209.0) % 47

	var r: float = 0.32 + float(r_bucket) / 100.0
	var g: float = 0.32 + float(g_bucket) / 100.0
	var b: float = 0.32 + float(b_bucket) / 100.0

	return Color(
		clamp(r, 0.24, 0.92),
		clamp(g, 0.24, 0.92),
		clamp(b, 0.24, 0.92),
		1.0
	).lerp(fallback, 0.3)


static func _crown_population_realm_ruler_for(gs: GameState,
	realm_id: int) -> Person:
	if gs == null or realm_id <= 0:
		return null

	if gs.realm_engine != null and gs.realm_engine.realms.has(realm_id):
		var realm_raw: Variant = gs.realm_engine.realms.get(realm_id, {})
		var realm: Dictionary = realm_raw if typeof(realm_raw) == TYPE_DICTIONARY else {}
		var ruler_id: int = int(realm.get("ruler_id", -1))
		if ruler_id > 0:
			return _find_active_crown_person_by_id(gs, ruler_id)

	return null


static func _crown_population_influence_value(gs: GameState,
	target: Person, realm_id: int, section_kind: String, element: String = "") -> int:
	if target == null:
		return 0

	var influence: float = 0.0

	match section_kind:
		"official":
			influence += 34.0
		"noble":
			influence += 26.0
		"master":
			influence += 22.0
		_:
			influence += 8.0

	if _crown_population_is_throne_holder(gs, target, realm_id):
		influence += 40.0
	if bool(target.is_royal):
		influence += 16.0
	if int(target.succession_rank) > 0:
		influence += maxf(0.0, 22.0 - float(target.succession_rank))

	influence += float(target.fame) * 0.18
	influence += float(target.respect) * 0.22
	influence += float(target.approval) * 0.12

	if int(target.bank_balance) >= 1000000:
		influence += 8.0
	if int(target.bank_balance) >= 10000000:
		influence += 10.0

	var clean_element: String = str(element).strip_edges().to_lower()
	if clean_element != "" and _is_crown_population_element_master(gs, target, realm_id, clean_element):
		influence += 14.0

	return clampi(int(round(influence)), 0, 100)


static func _crown_population_current_action_text(target: Person) -> String:
	if target == null:
		return "No readable action context."

	var bits: Array = []

	var context_text: String = str(target.current_context).strip_edges()
	if context_text != "" and context_text != "free":
		bits.append("Context: %s" % context_text.replace("_", " ").capitalize())

	var job_text: String = str(target.job).strip_edges()
	if job_text != "":
		bits.append("Work: %s" % MainSceneHelpers._crown_title_case(job_text))

	var school_status: String = str(target.school_status).strip_edges()
	if school_status != "":
		bits.append("School: %s" % school_status)

	var marital_status: String = str(target.marital_status).strip_edges()
	if marital_status != "":
		bits.append("House: %s" % marital_status)

	if bits.is_empty():
		return "Current action: living inside the active realm simulation."

	return " • ".join(bits)


static func _crown_population_collect_visible_graph_entity_ids(groups: Array) -> Dictionary:
	var out: Dictionary = {}

	for raw_group in groups:
		if typeof(raw_group) != TYPE_ARRAY:
			continue

		var group: Array = raw_group
		for raw_person in group:
			var person: Person = raw_person
			if person == null or not person.alive:
				continue

			var entity_id: String = MainSceneHelpers._crown_population_entity_id_for_person(person)
			if entity_id != "":
				out [entity_id] = true

	return out


static func _crown_population_graph_card_visible_in_layer(card: Control, layer: Control) -> bool:
	if card == null or layer == null:
		return false

	if not is_instance_valid(card) or not is_instance_valid(layer):
		return false

	var view_rect:= Rect2(Vector2.ZERO, layer.size).grow(8.0)
	var card_rect: Rect2 = MainSceneHelpers._crown_population_graph_card_rect_in_layer(card, layer)

	if card_rect.size == Vector2.ZERO:
		return false

	return view_rect.intersects(card_rect)


static func _crown_population_wall_cache_key(gs: GameState,
	realm_id: int) -> String:
	return "realm_population_wall:category_v12_sovereign_scope_async_shards:%d:%d" % [
		realm_id,
		int(gs.year) if gs != null else 0
	]


static func _crown_population_should_city_split_realm(gs: GameState,
	realm_id: int, realm_name: String, element: String = "") -> bool:
	var name_key: String = str(realm_name).strip_edges().to_lower()
	var element_key: String = str(element).strip_edges().to_lower()

	if element_key == "earth":
		return true

	if name_key.find("earth kingdom") >= 0:
		return true

	var resolved_name: String = _crown_realm_name(gs, realm_id).strip_edges().to_lower()
	if resolved_name.find("earth kingdom") >= 0:
		return true

	return false


static func _crown_population_representative_nation_sample(gs: GameState,
	people: Array, max_count: int, realm_id: int, realm_name: String, section_kind: String, element: String = "") -> Array:
	var clean_max: int = maxi(0, max_count)
	if clean_max <= 0:
		return []

	if people.size() <= clean_max:
		return people

	var buckets: Dictionary = {}
	var bucket_order: Array = []
	var split_by_city: bool = _crown_population_should_city_split_realm(gs, realm_id, realm_name, element)

	for raw_person in people:
		var person: Person = raw_person
		if person == null or not person.alive:
			continue

		var bucket_key: String = MainSceneHelpers._crown_population_city_bucket_key_for_person(
			person,
			realm_id,
			realm_name,
			section_kind,
			element,
			split_by_city
		)

		if not buckets.has(bucket_key):
			buckets [bucket_key] = []
			bucket_order.append(bucket_key)

		var bucket: Array = buckets.get(bucket_key, [])
		bucket.append(person)
		buckets [bucket_key] = bucket

	var out: Array = []
	var cursor_by_bucket: Dictionary = {}

	for raw_bucket_key in bucket_order:
		cursor_by_bucket [str(raw_bucket_key)] = 0

	var made_progress: bool = true
	while out.size() < clean_max and made_progress:
		made_progress = false

		for raw_bucket_key in bucket_order:
			if out.size() >= clean_max:
				break

			var bucket_key: String = str(raw_bucket_key)
			var bucket: Array = buckets.get(bucket_key, []) if typeof(buckets.get(bucket_key, [])) == TYPE_ARRAY else []
			var cursor: int = int(cursor_by_bucket.get(bucket_key, 0))

			if cursor >= bucket.size():
				continue

			var person: Person = bucket [cursor]
			cursor_by_bucket [bucket_key] = cursor + 1

			if person == null or not person.alive:
				continue

			out.append(person)
			made_progress = true

	return out


static func _ensure_truth_resolution_contract_engine(gs: GameState) -> TruthResolutionContractEngine:
	if gs == null:
		return null

	if "truth_resolution_contract_engine" in gs and gs.truth_resolution_contract_engine != null:
		return gs.truth_resolution_contract_engine as TruthResolutionContractEngine

	gs.truth_resolution_contract_engine = TruthResolutionContractEngine.new(gs)
	return gs.truth_resolution_contract_engine as TruthResolutionContractEngine


static func _crown_population_view_contract_signature(gs: GameState,
	view_contract: Dictionary) -> String:
	if view_contract.is_empty():
		return "empty"

	return "%d:%d:%d:%d:%d:%d" % [
		int(view_contract.get("realm_id", -1)),
		int(view_contract.get("built_for_year", gs.year if gs != null else 0)),
		(view_contract.get("officials", []) as Array).size() if typeof(view_contract.get("officials", [])) == TYPE_ARRAY else 0,
		(view_contract.get("nobles", []) as Array).size() if typeof(view_contract.get("nobles", [])) == TYPE_ARRAY else 0,
		(view_contract.get("masters", []) as Array).size() if typeof(view_contract.get("masters", [])) == TYPE_ARRAY else 0,
		(view_contract.get("citizens", []) as Array).size() if typeof(view_contract.get("citizens", [])) == TYPE_ARRAY else 0
	]


static func _request_population_government_truth_tail_for_realm(gs: GameState,
	realm_id: int, realm_name: String, reason: String = "population_government_truth_tail") -> Dictionary:
	if gs == null or realm_id <= 0:
		return {
			"success": false,
			"reason": "missing_game_state_or_invalid_realm",
			"ui_is_renderer_only": true
		}

	if not "truth_resolution_contract_engine" in gs or gs.truth_resolution_contract_engine == null:
		gs.truth_resolution_contract_engine = TruthResolutionContractEngine.new(gs)

	if gs.truth_resolution_contract_engine == null:
		return {
			"success": false,
			"reason": "missing_truth_resolution_contract_engine",
			"realm_id": realm_id,
			"realm_name": realm_name,
			"ui_is_renderer_only": true
		}

	if not gs.truth_resolution_contract_engine.has_method("resolve_population_and_government_truth_for_realms"):
		return {
			"success": false,
			"reason": "truth_resolution_engine_missing_resolve_method",
			"realm_id": realm_id,
			"realm_name": realm_name,
			"ui_is_renderer_only": true
		}

	return gs.truth_resolution_contract_engine.resolve_population_and_government_truth_for_realms(
		[realm_id],
		{
			"source": reason,
			"realm_id": realm_id,
			"realm_name": realm_name,
			"surface_already_exists": true,
			"truth_may_complete_after_observation": true,
			"skip_runtime_materialization": true,
			"ontology_only_ready_gate": true,
			"background_truth_resolution": true,
			"ready_door_may_not_wait": true,
			"ui_is_renderer_only": true
		}
	)


static func _global_prewarm_ready_gate_realm_ids(gs: GameState) -> Array:
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


static func _population_card_contract_tail_realm_name(gs: GameState,
	realm_id: int) -> String:
	if realm_id <= 0:
		return ""

	if gs != null and gs.realm_engine != null and "realms" in gs.realm_engine and typeof(gs.realm_engine.realms) == TYPE_DICTIONARY:
		var realm_raw: Variant = gs.realm_engine.realms.get(realm_id, {})
		if typeof(realm_raw) == TYPE_DICTIONARY:
			var realm: Dictionary = realm_raw
			var realm_name: String = str(realm.get("name", realm.get("country", ""))).strip_edges()
			if realm_name != "":
				return realm_name

	return _crown_realm_name(gs, realm_id)


static func _other_country_population_preferred_city(gs: GameState,
	_entry: Dictionary, realm: Dictionary = {}) -> String:
	var preferred_city: String = str(realm.get("capital_city", "")).strip_edges()
	if preferred_city != "":
		return preferred_city

	var subzones_raw: Variant = realm.get("subzones", [])
	if typeof(subzones_raw) == TYPE_ARRAY:
		var subzones: Array = subzones_raw
		if not subzones.is_empty():
			preferred_city = str(subzones [0]).strip_edges()
			if preferred_city != "":
				return preferred_city

	if gs != null and gs.player != null:
		preferred_city = str(gs.player.home_city if str(gs.player.home_city).strip_edges() != "" else gs.player.birth_city).strip_edges()

	return preferred_city


static func _resolve_existing_realm_id_for_other_country_population_entry(gs: GameState,
	entry: Dictionary) -> int:
	if gs == null or gs.realm_engine == null:
		return -1
	if typeof(gs.realm_engine.realms) != TYPE_DICTIONARY:
		return -1

	var realm_raw: Variant = entry.get("realm", {})
	var realm: Dictionary = realm_raw if typeof(realm_raw) == TYPE_DICTIONARY else {}

	var direct_realm_id: int = int(entry.get("realm_id", realm.get("realm_id", realm.get("id", -1))))
	if direct_realm_id > 0 and gs.realm_engine.realms.has(direct_realm_id):
		return direct_realm_id

	var wanted_name: String = MainSceneHelpers._other_country_population_realm_name_from_entry(entry, realm)
	var wanted_country: String = str(realm.get("country", wanted_name)).strip_edges()
	var wanted_keys: Dictionary = {}

	for raw_name in [wanted_name, wanted_country, str(entry.get("name", ""))]:
		var clean_name: String = str(raw_name).strip_edges()
		if clean_name == "":
			continue
		wanted_keys [MainSceneHelpers._other_country_identity_key(clean_name)] = true

	for raw_realm_id in gs.realm_engine.realms.keys():
		var realm_id: int = int(raw_realm_id)
		var existing_raw: Variant = gs.realm_engine.realms.get(raw_realm_id, gs.realm_engine.realms.get(realm_id, {}))
		if typeof(existing_raw) != TYPE_DICTIONARY:
			continue

		var existing: Dictionary = existing_raw
		var existing_names: Array = [
			str(existing.get("name", "")),
			str(existing.get("country", "")),
			str(existing.get("realm_contract_resolved_from_country", ""))
		]

		for raw_existing_name in existing_names:
			var existing_key: String = MainSceneHelpers._other_country_identity_key(str(raw_existing_name))
			if existing_key != "" and wanted_keys.has(existing_key):
				return realm_id

	return -1


static func _population_lens_prewarm_trace_event(gs: GameState,
	stage: String, payload: Dictionary = {}) -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var events_raw: Variant = gs.scenario_state.get("population_lens_prewarm_trace", [])
	var events: Array = events_raw if typeof(events_raw) == TYPE_ARRAY else []

	var row: Dictionary = payload.duplicate(true)
	row ["stage"] = str(stage)
	row ["at_ms"] = int(Time.get_ticks_msec())
	row ["year"] = int(gs.year)
	row ["ui_is_renderer_only"] = true
	row ["intent_is_not_action"] = true

	events.append(row)

	if events.size() > 320:
		events = events.slice(events.size() - 320, events.size())

	gs.scenario_state ["population_lens_prewarm_trace"] = events
	gs.scenario_state ["population_lens_prewarm_trace_last_stage"] = str(stage)
	gs.scenario_state ["population_lens_prewarm_trace_last_payload"] = row.duplicate(true)


static func _other_country_reconcile_observable_population_surface(gs: GameState,
	
	panel,
	realm_id: int,
	realm_name: String,
	aliases: Array,
	reason: String
) -> Dictionary:
	if gs == null or panel == null or realm_id <= 0:
		return {
			"success": false,
			"reason": "missing_panel_or_realm",
			"ui_is_renderer_only": true
		}

	var observable_hot: bool = false
	if "world_observability_contract_engine" in gs and gs.world_observability_contract_engine != null:
		if gs.world_observability_contract_engine.has_method("has_observable_population_surface"):
			observable_hot = gs.world_observability_contract_engine.has_observable_population_surface(realm_id)

	if not observable_hot:
		return {
			"success": false,
			"reason": "observable_surface_not_sealed",
			"realm_id": realm_id,
			"realm_name": realm_name,
			"click_path_build_forbidden": true,
			"ui_is_renderer_only": true
		}

	var hot: bool = panel.has_surface_for(realm_id, realm_name)

	if not hot:
		for raw_alias in aliases:
			var alias_name: String = str(raw_alias).strip_edges()
			if alias_name == "":
				continue

			if panel.has_surface_for(realm_id, alias_name):
				realm_name = alias_name
				hot = true
				break

	if hot:
		panel.add_aliases(realm_id, realm_name, aliases)

	return {
		"success": hot,
		"reason": "observable_surface_read_only_hot" if hot else "observable_surface_exists_but_panel_shell_missing",
		"realm_id": realm_id,
		"realm_name": realm_name,
		"panel_hot": hot,
		"observable_hot": observable_hot,
		"read_only": true,
		"click_path_build_forbidden": true,
		"ui_is_renderer_only": true,
		"reason_context": reason
	}


static func _presidential_parent_federal_population_stream_complete_for_realm(gs: GameState,
	realm_id: int) -> bool:
	if gs == null or realm_id <= 0:
		return true

	var scenario_complete: bool = true
	var scenario_pending: bool = false

	if typeof(gs.scenario_state) == TYPE_DICTIONARY:
		var us_realm_id: int = int(gs.scenario_state.get("presidential_parent_contract_us_realm_id", -1))
		if us_realm_id == realm_id:
			scenario_complete = bool(gs.scenario_state.get("presidential_parent_contract_federal_population_complete", false)) \
or bool(gs.scenario_state.get("presidential_parent_contract_federal_population_stream_complete", false))

			scenario_pending = bool(gs.scenario_state.get("presidential_parent_contract_federal_population_pending_after_player_control", false)) \
or bool(gs.scenario_state.get("presidential_parent_contract_federal_population_stream_running", false)) \
or bool(gs.scenario_state.get("presidential_parent_contract_federal_population_stream_jobs_pending_after_player_control", false))

			if scenario_complete:
				return true

			if scenario_pending:
				return false

	if gs.realm_engine != null and "realms" in gs.realm_engine and typeof(gs.realm_engine.realms) == TYPE_DICTIONARY:
		var realm_raw: Variant = gs.realm_engine.realms.get(realm_id, {})
		if typeof(realm_raw) == TYPE_DICTIONARY:
			var realm: Dictionary = realm_raw
			var managed_federal: bool = bool(realm.get("federal_republic_population_contract", false)) \
or str(realm.get("government_model", "")).strip_edges().to_lower() == "federal_presidential_republic"

			if not managed_federal:
				return true

			if bool(realm.get("federal_republic_population_complete", false)) \
or bool(realm.get("federal_republic_population_stream_complete", false)):
				return true

			if bool(realm.get("federal_republic_population_pending_after_player_control", false)) \
or bool(realm.get("federal_republic_population_streaming", false)) \
or bool(realm.get("federal_republic_population_stream_jobs_pending_after_player_control", false)):
				return false

	return true


static func _population_lens_incremental_section_specs(
	view_contract: Dictionary,
	realm_accent: Color,
	element: String,
	federal_republic: bool
) -> Array:
	var section_contracts_raw: Variant = (
		view_contract.get(
			"population_section_contracts",
			[]
		)
	)
	var section_contracts: Array = (
		section_contracts_raw as Array
		if typeof(
			section_contracts_raw
		) == TYPE_ARRAY
		else []
	)
	var specs: Array = []

	if not section_contracts.is_empty():
		for raw_section in section_contracts:
			var section: Dictionary = (
				MainSceneHelpers._safe_dictionary(
					raw_section
				)
			)

			if section.is_empty():
				continue

			var rows: Array = MainSceneHelpers._safe_array(
				section.get(
					"rows",
					[]
				)
			)

			if rows.is_empty():
				continue

			var accent: Color = (
				MainSceneHelpers._population_lens_incremental_section_accent(
					str(
						section.get(
							"accent_key",
							""
						)
					),
					realm_accent
				)
			)

			specs.append({
				"key": str(
					section.get(
						"key",
						"population"
					)
				),
				"title": str(
					section.get(
						"title",
						"POPULATION"
					)
				),
				"subtitle": str(
					section.get(
						"subtitle",
						""
					)
				),
				"rows": rows,
				"accent": accent,
				"glow": float(
					section.get(
						"glow",
						0.16
					)
				),
				"columns": int(
					section.get(
						"columns",
						5
					)
				),
				"section_kind": str(
					section.get(
						"section_kind",
						section.get(
							"key",
							"population"
						)
					)
				),
				"social_class": str(
					section.get(
						"social_class",
						""
					)
				)
			})

		return specs


	if federal_republic:
		return [
			{
				"key": "federal_executive",
				"title": "EXECUTIVE BRANCH",
				"subtitle": "President and First Family.",
				"rows": MainSceneHelpers._safe_array(
					view_contract.get(
						"federal_executive",
						[]
					)
				),
				"accent": Color(
					0.34,
					0.56,
					1.0,
					1.0
				),
				"glow": 0.36,
				"columns": 2
			},
			{
				"key": "federal_cabinet",
				"title": "EXECUTIVE CABINET",
				"subtitle": (
					"Federal executive department leadership."
				),
				"rows": MainSceneHelpers._safe_array(
					view_contract.get(
						"federal_cabinet",
						[]
					)
				),
				"accent": Color(
					0.42,
					0.66,
					1.0,
					1.0
				),
				"glow": 0.24,
				"columns": 5
			},
			{
				"key": "federal_senate",
				"title": (
					"LEGISLATIVE BRANCH • SENATE"
				),
				"subtitle": "Two senators per state.",
				"rows": MainSceneHelpers._safe_array(
					view_contract.get(
						"federal_senate",
						[]
					)
				),
				"accent": Color(
					0.38,
					0.54,
					0.98,
					1.0
				),
				"glow": 0.2,
				"columns": 7
			},
			{
				"key": "federal_supreme_court",
				"title": (
					"JUDICIAL BRANCH • SUPREME COURT"
				),
				"subtitle": "Federal judicial authority.",
				"rows": MainSceneHelpers._safe_array(
					view_contract.get(
						"federal_supreme_court",
						[]
					)
				),
				"accent": Color(
					0.7,
					0.56,
					1.0,
					1.0
				),
				"glow": 0.22,
				"columns": 4
			},
			{
				"key": "federal_governor",
				"title": (
					"STATE EXECUTIVES • GOVERNORS"
				),
				"subtitle": (
					"Governors of the geographical states."
				),
				"rows": MainSceneHelpers._safe_array(
					view_contract.get(
						"federal_governors",
						[]
					)
				),
				"accent": Color(
					0.48,
					0.82,
					0.62,
					1.0
				),
				"glow": 0.18,
				"columns": 7
			},
			{
				"key": "citizen",
				"title": "CITIZENS",
				"subtitle": (
					"Resident civilian population."
				),
				"rows": MainSceneHelpers._safe_array(
					view_contract.get(
						"citizens",
						[]
					)
				),
				"accent": realm_accent,
				"glow": 0.14,
				"columns": 7
			}
		]

	return [
		{
			"key": "official",
			"title": "ROYAL COURT",
			"subtitle": (
				"Ruler, partner, heirs, and sovereignty offices."
			),
			"rows": MainSceneHelpers._safe_array(
				view_contract.get(
					"royals",
					view_contract.get(
						"officials",
						[]
					)
				)
			),
			"accent": Color(
				1.0,
				0.78,
				0.24,
				1.0
			),
			"glow": 0.34,
			"columns": 4
		},
		{
			"key": "noble",
			"title": "NOBLE COURT",
			"subtitle": (
				"High noble houses and territorial authorities."
			),
			"rows": MainSceneHelpers._safe_array(
				view_contract.get(
					"nobles",
					[]
				)
			),
			"accent": Color(
				0.78,
				0.56,
				1.0,
				1.0
			),
			"glow": 0.28,
			"columns": 4
		},
		{
			"key": "master",
			"title": (
				"%s BENDING MASTERS"
				% element.to_upper()
				if element != ""
				else "MASTERS"
			),
			"subtitle": (
				"Realm-aligned masters and high-skill residents."
			),
			"rows": MainSceneHelpers._safe_array(
				view_contract.get(
					"masters",
					[]
				)
			),
			"accent": realm_accent,
			"glow": 0.42,
			"columns": 5
		},
		{
			"key": "citizen",
			"title": "CITIZENS",
			"subtitle": "Resident civilian population.",
			"rows": MainSceneHelpers._safe_array(
				view_contract.get(
					"citizens",
					[]
				)
			),
			"accent": realm_accent,
			"glow": 0.14,
			"columns": 7
		}
	]


static func _resolve_surface_realm_dict(gs: GameState,
	raw_realm_id: Variant) -> Dictionary:
	var out: Dictionary = {}
	if gs == null or gs.realm_engine == null:
		return out

	var realms_raw: Variant = gs.realm_engine.realms
	var realms: Dictionary = realms_raw if typeof(realms_raw) == TYPE_DICTIONARY else {}

	var raw_key: String = str(raw_realm_id).strip_edges()
	var int_key: int = int(raw_realm_id)
	var realm_raw: Variant = {}

	if realms.has(raw_realm_id):
		realm_raw = realms.get(raw_realm_id, {})
	elif raw_key != "" and realms.has(raw_key):
		realm_raw = realms.get(raw_key, {})
	elif realms.has(int_key):
		realm_raw = realms.get(int_key, {})
	else:
		realm_raw = {}

	out = realm_raw if typeof(realm_raw) == TYPE_DICTIONARY else {}
	if out.is_empty():
		return out

	if int_key > 0 and gs.realm_engine.has_method("ensure_realm_defaults"):
		var hydrated: Dictionary = gs.realm_engine.ensure_realm_defaults(int_key)
		if not hydrated.is_empty():
			out = hydrated

	return out


static func _get_crown_allocation_draft_key(gs: GameState) -> String:
	if gs == null or gs.player == null:
		return ""
	return "%d:%d" % [int(gs.player.realm_id), int(gs.year)]


static func _apply_crown_pending_tax_effects(gs: GameState,
	realm: Dictionary) -> Dictionary:
	if gs == null or gs.player == null:
		return realm
	if realm.is_empty():
		return realm
	var pending_year: int = int(realm.get("pending_tax_effect_year", -1))
	if pending_year <= 0 or int(gs.year) < pending_year:
		return realm
	if int(realm.get("tax_effect_applied_year", -1)) == int(gs.year):
		return realm
	var p:= gs.player
	var approval_delta: int = int(realm.get("pending_tax_approval_delta", 0))
	var happiness_delta: int = int(realm.get("pending_tax_happiness_delta", 0))
	var respect_delta: int = int(realm.get("pending_tax_respect_delta", 0))
	p.approval = clamp(int(p.approval) + approval_delta, 0, 100)
	realm ["happiness"] = clamp(int(realm.get("happiness", 50)) + happiness_delta, 0, 100)
	realm ["respect_bias"] = clamp(int(realm.get("respect_bias", 0)) + respect_delta, -40, 40)
	realm ["tax_effect_applied_year"] = int(gs.year)
	if gs.realm_engine != null and int(p.realm_id) > 0:
		gs.realm_engine.realms [int(p.realm_id)] = realm
	return realm


static func _rebalance_crown_allocation_draft(draft: Dictionary, changed_key: String, requested_value: int) -> Dictionary:
	var out: Dictionary = MainSceneHelpers._sanitize_crown_allocation_split(draft)
	var ordered_keys: Array = ["treasury_pct", "military_pct", "goods_pct"]
	if not ordered_keys.has(changed_key):
		return out

	var other_keys: Array = []
	for raw_key in ordered_keys:
		var key: String = str(raw_key)
		if key != changed_key:
			other_keys.append(key)

	var next_value: int = clamp(requested_value, 0, 100)
	out [changed_key] = next_value

	var remaining: int = 100 - next_value
	var first_key: String = str(other_keys [0])
	var second_key: String = str(other_keys [1])

	var current_first: int = int(out.get(first_key, 0))
	var current_second: int = int(out.get(second_key, 0))
	var current_total: int = current_first + current_second

	if current_total <= 0:
		var first_share: int = int(floor(float(remaining) * 0.5))
		out [first_key] = first_share
		out [second_key] = remaining - first_share
	else:
		var first_share: int = int(round(float(remaining) * (float(current_first) / float(current_total))))
		first_share = clamp(first_share, 0, remaining)
		out [first_key] = first_share
		out [second_key] = remaining - first_share

	return MainSceneHelpers._sanitize_crown_allocation_split(out)


static func _build_crown_allocation_projection(summary: Dictionary, realm: Dictionary, draft: Dictionary) -> Dictionary:
	var clean_draft: Dictionary = MainSceneHelpers._sanitize_crown_allocation_split(draft)
	var tax_rate: float = clamp(float(clean_draft.get("tax_rate", 10.0)), 0.0, 40.0)
	var treasury_pct: int = int(clean_draft.get("treasury_pct", 34))
	var military_pct: int = int(clean_draft.get("military_pct", 33))
	var goods_pct: int = int(clean_draft.get("goods_pct", 33))
	var population: int = int(summary.get("population", 0))
	var tax_revenue: int = MainSceneHelpers._calculate_crown_tax_revenue(population, tax_rate, realm)
	var saved_reserve: int = int(realm.get("allocation_reserve", summary.get("allocation_reserve", 0)))
	var available_pool: int = saved_reserve + tax_revenue

	var treasury_amount: int = int(round(float(available_pool) * (float(treasury_pct) / 100.0)))
	var military_budget: int = int(round(float(available_pool) * (float(military_pct) / 100.0)))
	var goods_budget: int = int(round(float(available_pool) * (float(goods_pct) / 100.0)))

	var military_unit_cost: int = int(summary.get("military_unit_cost", 4500))
	var goods_unit_cost: int = int(summary.get("goods_unit_cost", 200000))

	var military_units: int = int(floor(float(military_budget) / float(max(1, military_unit_cost))))
	var goods_units: int = int(floor(float(goods_budget) / float(max(1, goods_unit_cost))))

	var military_amount: int = military_units * max(1, military_unit_cost)
	var goods_amount: int = goods_units * max(1, goods_unit_cost)

	var spent_total: int = treasury_amount + military_amount + goods_amount
	var carryover_amount: int = max(0, available_pool - spent_total)

	return {
		"tax_rate": tax_rate,
		"treasury_pct": treasury_pct,
		"military_pct": military_pct,
		"goods_pct": goods_pct,
		"tax_revenue": tax_revenue,
		"saved_reserve": saved_reserve,
		"available_pool": available_pool,
		"treasury_amount": treasury_amount,
		"military_amount": military_amount,
		"goods_amount": goods_amount,
		"carryover_amount": carryover_amount,
		"military_units": military_units,
		"goods_units": goods_units,
		"happiness_delta": MainSceneHelpers._crown_tax_pressure_delta(tax_rate, "happiness"),
		"approval_delta": MainSceneHelpers._crown_tax_pressure_delta(tax_rate, "approval"),
		"respect_delta": MainSceneHelpers._crown_tax_pressure_delta(tax_rate, "respect")
	}


static func _crown_allocation_draft_has_changes(summary: Dictionary, realm: Dictionary, draft: Dictionary) -> bool:
	var baseline: Dictionary = {
		"tax_rate": clamp(float(realm.get("tax_rate", summary.get("tax_rate", 10.0))), 0.0, 40.0),
		"treasury_pct": clamp(int(realm.get("allocation_treasury_pct", 34)), 0, 100),
		"military_pct": clamp(int(realm.get("allocation_military_pct", 33)), 0, 100),
		"goods_pct": clamp(int(realm.get("allocation_goods_pct", 33)), 0, 100)
	}
	baseline = MainSceneHelpers._sanitize_crown_allocation_split(baseline)

	var probe: Dictionary = MainSceneHelpers._sanitize_crown_allocation_split(draft)

	if abs(float(probe.get("tax_rate", 0.0)) - float(baseline.get("tax_rate", 0.0))) >= 0.5:
		return true

	for key in ["treasury_pct", "military_pct", "goods_pct"]:
		if int(probe.get(key, 0)) != int(baseline.get(key, 0)):
			return true

	return false


static func _pick_best_crown_successor(gs: GameState,
	exclude_id: int = -1) -> Person:
	if gs == null or gs.player == null:
		return null
	var best: Person = null
	for raw_npc in gs.npcs:
		var npc: Person = raw_npc
		if npc == null or not npc.alive or int(npc.id) == exclude_id:
			continue
		if int(npc.realm_id) != int(gs.player.realm_id):
			continue
		if not bool(npc.is_royal):
			continue
		if bool(npc.exiled):
			continue
		if best == null:
			best = npc
			continue
		if int(npc.succession_rank) < int(best.succession_rank):
			best = npc
		elif int(npc.succession_rank) == int(best.succession_rank) and int(npc.age) > int(best.age):
			best = npc
	return best


static func _build_crown_execution_methods(gs: GameState) -> Array:
	var era_key: String = _crown_current_era_key(gs).strip_edges().to_lower()

	var methods: Array = [
		{ "label": "Public Decree", "severity": 35, "approval_delta": -6, "scandal_delta": 6, "outcry_delta": 5, "cause": "Execution"},
		{ "label": "Quiet Poison", "severity": 45, "approval_delta": -5, "scandal_delta": 9, "outcry_delta": 4, "cause": "Execution"},
		{ "label": "Iron Maiden", "severity": 90, "approval_delta": -18, "scandal_delta": 20, "outcry_delta": 18, "cause": "Execution"},
		{ "label": "Impalement", "severity": 92, "approval_delta": -19, "scandal_delta": 21, "outcry_delta": 19, "cause": "Execution"},
		{ "label": "Puppy Chow", "severity": 100, "approval_delta": -25, "scandal_delta": 28, "outcry_delta": 26, "cause": "Execution"},
		{ "label": "Cement Shoes", "severity": 66, "approval_delta": -13, "scandal_delta": 17, "outcry_delta": 12, "cause": "Execution"},
		{ "label": "Brazen Bull", "severity": 96, "approval_delta": -22, "scandal_delta": 25, "outcry_delta": 24, "cause": "Execution"},
		{ "label": "Drawn & Quartered", "severity": 100, "approval_delta": -26, "scandal_delta": 28, "outcry_delta": 28, "cause": "Execution"},
		{ "label": "Tar & Feathered", "severity": 52, "approval_delta": -8, "scandal_delta": 10, "outcry_delta": 8, "cause": "Execution"},
		{ "label": "Boiling Oil", "severity": 94, "approval_delta": -21, "scandal_delta": 24, "outcry_delta": 23, "cause": "Execution"},
		{ "label": "Black Mamba Bite", "severity": 82, "approval_delta": -17, "scandal_delta": 20, "outcry_delta": 16, "cause": "Execution"},
		{ "label": "Rat Torture", "severity": 93, "approval_delta": -22, "scandal_delta": 25, "outcry_delta": 23, "cause": "Execution"}
	]

	match era_key:
		"ancient":
			methods.append_array([
				{ "label": "Stoning", "severity": 78, "approval_delta": -15, "scandal_delta": 15, "outcry_delta": 15, "cause": "Execution"},
				{ "label": "Crucifixion", "severity": 96, "approval_delta": -23, "scandal_delta": 24, "outcry_delta": 25, "cause": "Execution"}
			])
		"medieval":
			methods.append_array([
				{ "label": "Burning at the Stake", "severity": 91, "approval_delta": -20, "scandal_delta": 23, "outcry_delta": 22, "cause": "Execution"},
				{ "label": "Public Beheading", "severity": 70, "approval_delta": -12, "scandal_delta": 14, "outcry_delta": 12, "cause": "Execution"}
			])
		"industrial":
			methods.append_array([
				{ "label": "Guillotine", "severity": 68, "approval_delta": -11, "scandal_delta": 12, "outcry_delta": 11, "cause": "Execution"},
				{ "label": "Firing Squad", "severity": 62, "approval_delta": -10, "scandal_delta": 12, "outcry_delta": 10, "cause": "Execution"}
			])
		"modern":
			methods.append_array([
				{ "label": "Lethal Injection", "severity": 48, "approval_delta": -7, "scandal_delta": 9, "outcry_delta": 7, "cause": "Execution"},
				{ "label": "Military Tribunal Execution", "severity": 65, "approval_delta": -12, "scandal_delta": 14, "outcry_delta": 12, "cause": "Execution"}
			])
		"future":
			methods.append_array([
				{ "label": "Neural Deletion Sentence", "severity": 88, "approval_delta": -20, "scandal_delta": 24, "outcry_delta": 22, "cause": "Execution"},
				{ "label": "Orbital Airlock Sentence", "severity": 84, "approval_delta": -18, "scandal_delta": 22, "outcry_delta": 20, "cause": "Execution"}
			])

	return methods


static func _apply_crown_public_outcry_delta(gs: GameState,
	delta_value: int) -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var current_outcry: int = int(gs.scenario_state.get("crown_public_outcry", 0))
	gs.scenario_state ["crown_public_outcry"] = clamp(current_outcry + int(delta_value), 0, 100)


static func _build_crown_honorific_options(gs: GameState) -> Array:
	if gs == null or gs.player == null:
		return ["Sovereign", "Majesty", "High Ruler"]
	var p:= gs.player
	var out: Array = []
	if bool(p.is_ruler):
		out.append("Your Majesty")
		out.append("Sovereign")
		out.append("High Ruler")
		out.append("First Crown")
	else:
		out.append("Royal Highness")
		out.append("Heir Apparent")
		out.append("Claimant Regent")
	return out


static func _build_crown_heir_candidates(gs: GameState) -> Array:
	var out: Array = []
	if gs == null or gs.player == null:
		return out
	for raw_npc in gs.npcs:
		var npc: Person = raw_npc
		if npc == null or not npc.alive or int(npc.id) == int(gs.player.id):
			continue
		if int(npc.realm_id) != int(gs.player.realm_id):
			continue
		if not bool(npc.is_royal):
			continue
		if bool(npc.exiled):
			continue
		out.append(npc)
	return out.slice(0, min(8, out.size()))


static func _build_crown_marriage_candidates(gs: GameState) -> Array:
	var out: Array = []
	if gs == null or gs.player == null:
		return out
	for raw_npc in gs.npcs:
		var npc: Person = raw_npc
		if npc == null or not npc.alive:
			continue
		if int(npc.realm_id) == int(gs.player.realm_id):
			continue
		if not bool(npc.is_royal):
			continue
		if npc.partner != null:
			continue
		if int(npc.age) < 18:
			continue
		out.append(npc)
	return out.slice(0, min(8, out.size()))


static func _build_crown_succession_text(gs: GameState) -> String:
	var lines: Array = []
	lines.append("Current throne order:")
	var candidates: Array = _build_crown_heir_candidates(gs)
	if candidates.is_empty():
		lines.append("No clear heir lines found.")
	else:
		for raw_candidate in candidates:
			var candidate: Person = raw_candidate
			lines.append("%s %s  •  rank %d  •  age %d" % [
				candidate.first_name,
				candidate.last_name,
				int(candidate.succession_rank),
				int(candidate.age)
			])
	return "\n".join(lines)


static func _build_crown_claimant_text(gs: GameState) -> String:
	var lines: Array = []
	lines.append("Claimant and branch pressure:")
	if gs == null or gs.player == null:
		return "\n".join(lines)
	for raw_npc in gs.npcs:
		var npc: Person = raw_npc
		if npc == null or not npc.alive:
			continue
		if int(npc.realm_id) != int(gs.player.realm_id):
			continue
		if not bool(npc.deposed) and not bool(npc.exiled) and int(npc.succession_rank) > 12:
			continue
		lines.append("%s %s  •  rank %d  •  exiled=%s  •  deposed=%s" % [
			npc.first_name,
			npc.last_name,
			int(npc.succession_rank),
			str(bool(npc.exiled)),
			str(bool(npc.deposed))
		])
	if lines.size() == 1:
		lines.append("No major claimant threats are visible.")
	return "\n".join(lines)


static func _crown_default_currency_name_for_realm(gs: GameState,
	realm_name: String) -> String:
	var clean_name: String = realm_name.strip_edges()
	match clean_name:
		"Fire Nation":
			return "Gold Pieces"
		"Earth Kingdom":
			return "Yuan"
		"Water Tribe":
			return "Silver Marks"
		"Air Nomads":
			return "Monastery Chits"
		"USA":
			return "Dollars"
		"UK":
			return "Pounds"
		"Japan":
			return "Yen"
		"Brazil":
			return "Reais"
		"Germany":
			return "Marks"
		"Federated Earth":
			return "Credits"
		"Sol Empire":
			return "Solar Credits"
		"Lunar Republic":
			return "Lunar Credits"
	match gs.era.name if gs != null and gs.era != null else "":
		"Ancient Era":
			return "Talents"
		"Medieval Era":
			return "Crowns"
		"Industrial Era":
			return "Pounds"
		"Modern Era":
			return "Dollars"
		"Future Era":
			return "Credits"
		_:
			return "Crowns"


static func _crown_population_uses_federal_republic_lens(gs: GameState,
	realm_id: int, realm_name: String = "") -> bool:
	var resolved_name: String = str(realm_name).strip_edges()
	if resolved_name == "":
		resolved_name = _crown_realm_name(gs, realm_id)

	var name_key: String = resolved_name.strip_edges().to_lower()
	var compact_name: String = name_key.replace(".", "").replace(" ", "").replace("-", "")

	if compact_name in [
		"usa",
		"us",
		"unitedstates",
		"unitedstatesofamerica",
		"america"
	]:
		return true

	if gs != null and gs.realm_engine != null and "realms" in gs.realm_engine and typeof(gs.realm_engine.realms) == TYPE_DICTIONARY:
		var realm_raw: Variant = gs.realm_engine.realms.get(realm_id, {})
		if typeof(realm_raw) == TYPE_DICTIONARY:
			var realm: Dictionary = realm_raw
			var government_model: String = str(realm.get("government_model", "")).strip_edges().to_lower()
			var government_style: String = str(realm.get("government_style", realm.get("government", ""))).strip_edges().to_lower()

			if bool(realm.get("federal_republic_population_contract", false)):
				return true

			if government_model in [
				"federal_presidential_republic",
				"federal_republic",
				"presidential_republic",
				"constitutional_republic"
			]:
				return true

			if government_style in [
				"federal republic",
				"presidential republic",
				"constitutional republic"
			]:
				return true

	return false


static func _crown_population_noble_title_from_person(target: Person, _realm_id: int = -1) -> String:
	if target == null:
		return ""

	var royal_title_text: String = str(target.royal_title).strip_edges()
	var royal_title_match: String = MainSceneHelpers._crown_population_noble_title_from_text(royal_title_text)
	if royal_title_match != "":
		return royal_title_match

	var social_class_text: String = str(target.social_class).strip_edges()
	var social_title_match: String = MainSceneHelpers._crown_population_noble_title_from_text(social_class_text)
	if social_title_match != "":
		return social_title_match

	var job_text: String = str(target.job).strip_edges()
	var job_title_match: String = MainSceneHelpers._crown_population_noble_title_from_text(job_text)
	if job_title_match != "":
		return job_title_match

	var social_key: String = social_class_text.to_lower()
	var gender_text: String = str(target.gender).strip_edges().to_lower()

	if social_key in [
		"noble",
		"nobility",
		"aristocrat",
		"aristocracy",
		"upper nobility",
		"high nobility"
	]:
		var succession_rank: int = int(target.succession_rank)

		if succession_rank > 0 and succession_rank <= 8:
			return "Duchess" if gender_text == "female" else "Duke"

		if succession_rank > 8 and succession_rank <= 12:
			return "Marchioness" if gender_text == "female" else "Marquess"

		return "Lady" if gender_text == "female" else "Lord"

	return ""


static func _crown_population_is_ruler_partner_card(gs: GameState,
	target: Person, realm_id: int) -> bool:
	if target == null or not target.alive:
		return false

	if _crown_population_is_throne_holder(gs, target, realm_id):
		return true

	var ruler: Person = _crown_population_realm_ruler_for(gs, realm_id)
	if ruler == null:
		return false

	if target.partner != null and int(target.partner.id) == int(ruler.id):
		return true

	if ruler.partner != null and int(ruler.partner.id) == int(target.id):
		return true

	return false


static func _crown_population_person_matches_realm(gs: GameState,
	target: Person, realm_id: int, realm_name: String = "") -> bool:
	if target == null or not target.alive:
		return false

	if realm_id > 0 and int(target.realm_id) == realm_id:
		return true

	var resolved_realm_name: String = str(realm_name).strip_edges()
	if resolved_realm_name == "":
		resolved_realm_name = _crown_realm_name(gs, realm_id)

	var normalized_realm_name: String = resolved_realm_name.strip_edges().to_lower()
	if normalized_realm_name == "":
		return false

	var aliases: Dictionary = {}
	if gs != null and gs.realm_engine != null and gs.realm_engine.has_method("_normalize_realm_match_aliases"):
		aliases = gs.realm_engine._normalize_realm_match_aliases(resolved_realm_name)

	for raw_value in [
		str(target.home_country),
		str(target.birth_country),
		str(target.bending_nation)
	]:
		var value: String = str(raw_value).strip_edges().to_lower()
		if value == "":
			continue
		if value == normalized_realm_name or aliases.has(value):
			return true

	return false


static func _crown_population_uses_modern_class_lens(gs: GameState,
	realm_id: int, realm_name: String = "") -> bool:
	var resolved_name: String = str(realm_name).strip_edges()
	if resolved_name == "":
		resolved_name = _crown_realm_name(gs, realm_id)

	var name_key: String = resolved_name.strip_edges().to_lower()
	var compact_name: String = name_key.replace(".", "").replace(" ", "").replace("-", "")

	if compact_name in [
		"usa",
		"us",
		"unitedstates",
		"unitedstatesofamerica",
		"america"
	]:
		return true

	if gs != null and gs.realm_engine != null and gs.realm_engine.realms.has(realm_id):
		var realm_raw: Variant = gs.realm_engine.realms.get(realm_id, {})
		var realm: Dictionary = realm_raw if typeof(realm_raw) == TYPE_DICTIONARY else {}
		var government_style: String = str(realm.get("government_style", "")).strip_edges().to_lower()

		if government_style in [
			"democracy",
			"republic",
			"federal republic",
			"constitutional republic",
			"presidential republic",
			"parliamentary democracy"
		]:
			return true

	return false


static func _crown_population_citizen_strata_order(gs: GameState,
	realm_id: int, realm_name: String = "") -> Array:
	if _crown_population_uses_modern_class_lens(gs, realm_id, realm_name):
		return [
			"bottom_class",
			"lower_middle_class",
			"middle_class",
			"upper_middle_class",
			"elite"
		]

	return ["peasant", "commoner", "merchant"]


static func _materialize_crown_population_target_for_realm(gs: GameState,
	realm_id: int, realm_name: String = "", capital_city: String = "") -> Person:
	if gs == null or realm_id <= 0:
		return null

	var resolved_realm_name: String = realm_name.strip_edges()
	var resolved_capital_city: String = capital_city.strip_edges()
	var native_element: String = ""
	var is_avatar_nation: bool = false
	if gs.realm_engine != null and gs.realm_engine.has_method("ensure_realm_defaults"):
		var realm: Dictionary = gs.realm_engine.ensure_realm_defaults(realm_id)
		if not realm.is_empty():
			if resolved_realm_name == "":
				resolved_realm_name = str(realm.get("name", "")).strip_edges()
			if resolved_capital_city == "":
				resolved_capital_city = str(realm.get("capital_city", "")).strip_edges()
			if gs.realm_engine.has_method("_realm_element_for_name"):
				native_element = str(gs.realm_engine._realm_element_for_name(resolved_realm_name)).strip_edges().to_lower()
			is_avatar_nation = native_element in ["air", "earth", "fire", "water"]

	var generated: Person = null
	var materialize_filters: Array = []
	if is_avatar_nation:
		materialize_filters.append({
			"realm_id": realm_id,
			"home_country": resolved_realm_name,
			"birth_country": resolved_realm_name,
			"bending_nation": resolved_realm_name,
			"bending_type": native_element
		})
		materialize_filters.append({
			"realm_id": realm_id,
			"home_country": resolved_realm_name,
			"birth_country": resolved_realm_name,
			"bending_nation": resolved_realm_name
		})
		materialize_filters.append({
			"realm_id": realm_id,
			"home_country": resolved_realm_name
		})
	materialize_filters.append({
		"realm_id": realm_id
	})

	for raw_filters in materialize_filters:
		var filters: Dictionary = raw_filters
		if gs.population_lifecycle_manager == null:
			break
		generated = gs.population_lifecycle_manager.materialize_person_from_shard(filters)
		if generated != null:
			break

	if generated == null and gs.realm_engine != null and gs.realm_engine.has_method("create_bootstrap_realm_resident"):
		var bootstrap_role: String = "worker"
		if is_avatar_nation and randi() % 100 < 35:
			bootstrap_role = "soldier"
		generated = gs.realm_engine.create_bootstrap_realm_resident(realm_id, resolved_capital_city, bootstrap_role)

	if generated == null:
		generated = _synthesize_crown_population_target_for_realm(gs, 
			realm_id,
			resolved_realm_name,
			resolved_capital_city,
			native_element,
			is_avatar_nation
		)

	if generated == null:
		return null

	generated.realm_id = realm_id
	var preferred_settlement_id: String = ""
	if gs.geo_engine != null:
		if gs.geo_engine.has_method("bootstrap_for_current_era"):
			gs.geo_engine.bootstrap_for_current_era()
		var options: Array = gs.geo_engine.realm_to_settlements.get(realm_id, [])
		if not options.is_empty():
			preferred_settlement_id = str(options [0])

	if preferred_settlement_id != "" and gs.geo_engine != null and gs.geo_engine.has_method("bootstrap_person_place"):
		gs.geo_engine.bootstrap_person_place(generated, {
			"settlement_id": preferred_settlement_id
		})

	if resolved_realm_name != "":
		generated.home_country = resolved_realm_name
		if str(generated.birth_country).strip_edges() == "":
			generated.birth_country = resolved_realm_name
	if resolved_capital_city != "":
		if str(generated.home_city).strip_edges() == "":
			generated.home_city = resolved_capital_city
		if str(generated.birth_city).strip_edges() == "":
			generated.birth_city = resolved_capital_city

	if is_avatar_nation:
		if str(generated.bending_nation).strip_edges() == "":
			generated.bending_nation = resolved_realm_name
		var current_bending_type: String = str(generated.bending_type).strip_edges().to_lower()
		if current_bending_type == "" or current_bending_type == "none":
			generated.bending_type = native_element
		if typeof(generated.bending_mastery) != TYPE_DICTIONARY:
			generated.bending_mastery = {}
		var mastery: Dictionary = generated.bending_mastery
		mastery [native_element] = max(1, int(mastery.get(native_element, 0)))
		generated.bending_mastery = mastery

	if gs.realm_engine != null and gs.realm_engine.has_method("_apply_elemental_realm_identity_to_npc"):
		gs.realm_engine._apply_elemental_realm_identity_to_npc(generated, resolved_realm_name)

	return generated


static func _synthesize_crown_population_target_for_realm(gs: GameState,
	realm_id: int, realm_name: String, capital_city: String, native_element: String, is_avatar_nation: bool) -> Person:
	if gs == null or gs.npc_factory == null or realm_id <= 0:
		return null

	var generated: Person = gs.npc_factory.create_random_npc(false)
	if generated == null:
		return null

	gs.apply_reality_rules_to_person(generated)

	generated.realm_id = realm_id
	generated.is_ruler = false
	generated.is_royal = false
	generated.deposed = false
	generated.exiled = false
	generated.palace_owned = false
	generated.royal_title = ""
	generated.succession_rank = 99

	if realm_name.strip_edges() != "":
		generated.home_country = realm_name
		generated.birth_country = realm_name

	if capital_city.strip_edges() != "":
		generated.home_city = capital_city
		generated.birth_city = capital_city

	var era_name: String = str(gs.era.name if gs != null and gs.era != null else "Modern Era")
	var synthetic_role: String = "worker"

	if is_avatar_nation and randi() % 100 < 35:
		synthetic_role = "soldier"

	if synthetic_role == "soldier":
		generated.social_class = "Commoner"
		if era_name == "Ancient Era":
			generated.job = ["Warrior", "Guard", "Spearman", "Archer"].pick_random()
		elif era_name == "Medieval Era":
			generated.job = ["Guard", "Watchman", "Soldier", "Militia"].pick_random()
		else:
			generated.job = ["Soldier", "Guard", "Militia", "Officer"].pick_random()
	else:
		if era_name == "Ancient Era":
			generated.social_class = ["Commoner", "Peasant", "Merchant"].pick_random()
			generated.job = ["Farmer", "Builder", "Artisan", "Trader", "Fisher"].pick_random()
		elif era_name == "Medieval Era":
			generated.social_class = ["Peasant", "Commoner", "Merchant"].pick_random()
			generated.job = ["Farmer", "Blacksmith", "Mason", "Merchant", "Artisan"].pick_random()
		else:
			generated.social_class = ["Commoner", "Commoner", "Merchant"].pick_random()
			generated.job = ["Worker", "Laborer", "Merchant", "Artisan", "Dockhand"].pick_random()

	if era_name == "Ancient Era" and is_avatar_nation:
		var lineage_place: String = capital_city.strip_edges()
		if lineage_place == "":
			lineage_place = realm_name.strip_edges()
		if lineage_place != "":
			generated.last_name = "of %s" % lineage_place

	if is_avatar_nation:
		generated.bending_nation = realm_name
		var current_bending_type: String = str(generated.bending_type).strip_edges().to_lower()
		if current_bending_type == "" or current_bending_type == "none":
			generated.bending_type = native_element
			if typeof(generated.bending_mastery) != TYPE_DICTIONARY:
				generated.bending_mastery = {}
			var mastery: Dictionary = generated.bending_mastery
			mastery [native_element] = max(1, int(mastery.get(native_element, 0)))
			generated.bending_mastery = mastery

	if gs.population_lifecycle_manager != null and gs.population_lifecycle_manager.has_method("inject_live_population_personality"):
		gs.population_lifecycle_manager.inject_live_population_personality(generated, {
			"realm_id": realm_id,
			"home_country": realm_name,
			"source": "crown_fallback_synth"
		})

	if not gs.npcs.has(generated):
		gs.npcs.append(generated)

	if gs.geo_engine != null and gs.geo_engine.has_method("bootstrap_person_place"):
		var preferred_settlement_id: String = ""
		if gs.geo_engine.has_method("bootstrap_for_current_era"):
			gs.geo_engine.bootstrap_for_current_era()
		var options: Array = gs.geo_engine.realm_to_settlements.get(realm_id, [])
		if not options.is_empty():
			preferred_settlement_id = str(options [0])
		if preferred_settlement_id != "":
			gs.geo_engine.bootstrap_person_place(generated, {
				"settlement_id": preferred_settlement_id
			})

	if gs.world_space_engine != null:
		gs.world_space_engine.place_npc(generated)

	if gs.chunk_simulation_engine != null:
		gs.chunk_simulation_engine.assign_npc(generated)

	return generated


static func _get_crown_realm_relation_score(gs: GameState,
	target_realm_id: int) -> int:
	if gs == null or gs.player == null:
		return 0
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	var raw_store: Variant = gs.scenario_state.get("crown_realm_relations", {})
	var store: Dictionary = raw_store if typeof(raw_store) == TYPE_DICTIONARY else {}
	var key: String = "%d:%d" % [int(gs.player.realm_id), int(target_realm_id)]
	return int(store.get(key, 0))


static func _crown_realm_name(gs: GameState,
	realm_id: int) -> String:
	if gs == null or gs.realm_engine == null or realm_id <= 0:
		return "Unknown Realm"
	if not gs.realm_engine.realms.has(realm_id):
		return "Unknown Realm"
	var realm_raw: Variant = gs.realm_engine.realms.get(realm_id, {})
	var realm: Dictionary = realm_raw if typeof(realm_raw) == TYPE_DICTIONARY else {}
	return str(realm.get("name", "Unknown Realm"))


static func _era_border_theme_key_from_world(gs: GameState) -> String:
	if gs == null or gs.era == null:
		return "ancient"

	var era_name: String = str(gs.era.name).to_lower()

	if era_name.find("future") != -1:
		return "future"
	if era_name.find("modern") != -1 or era_name.find("industrial") != -1 or era_name.find("contemporary") != -1:
		return "modern"
	if era_name.find("medieval") != -1 or era_name.find("middle") != -1 or era_name.find("feudal") != -1:
		return "medieval"

	return "ancient"


static func _relationship_score_for_target(gs: GameState,
	target: Person) -> int:
	if gs == null or gs.player == null or target == null:
		return 0

	if gs.relationship_engine != null and gs.relationship_engine.has_method("ensure_pair_relationship_baseline"):
		return int(gs.relationship_engine.ensure_pair_relationship_baseline(gs.player, target))

	if typeof(gs.player.affection) == TYPE_DICTIONARY:
		return clamp(int(gs.player.affection.get(target.id, 0)), 0, 100)

	return 0


static func _get_era_panel_transition_style(gs: GameState) -> Dictionary:
	var era_name: String = ""
	if gs != null and gs.era != null:
		era_name = str(gs.era.name)

	match era_name:
		"Ancient Era":
			return {
				"duration": 0.24,
				"x_distance": 22.0,
				"y_distance": 7.0,
				"start_scale": 0.974
			}
		"Medieval Era":
			return {
				"duration": 0.21,
				"x_distance": 18.0,
				"y_distance": 5.0,
				"start_scale": 0.979
			}
		"Industrial Era":
			return {
				"duration": 0.18,
				"x_distance": 15.0,
				"y_distance": 3.0,
				"start_scale": 0.984
			}
		"Modern Era":
			return {
				"duration": 0.16,
				"x_distance": 12.0,
				"y_distance": 2.0,
				"start_scale": 0.988
			}
		"Future Era":
			return {
				"duration": 0.14,
				"x_distance": 20.0,
				"y_distance": 1.0,
				"start_scale": 0.992
			}
		_:
			return {
				"duration": 0.18,
				"x_distance": 10.0,
				"y_distance": 2.0,
				"start_scale": 0.985
			}


static func _meat_market_activity_label(gs: GameState) -> String:
	if gs == null or gs.player == null or gs.meat_market_contract_engine == null:
		return ""
	if not gs.meat_market_contract_engine.available_in_current_era():
		return ""
	return str(gs.meat_market_contract_engine.market_label_for_actor(gs.player)).strip_edges()


static func _activity_label_is_meat_market_label(gs: GameState,
	action_label: String) -> bool:
	var clean_label: String = str(action_label).strip_edges()
	if clean_label == "":
		return false
	return clean_label == _meat_market_activity_label(gs)


static func _activity_label_is_pet_shop_label(gs: GameState,
	action_label: String) -> bool:
	var clean_label: String = str(action_label).strip_edges()
	if clean_label == "":
		return false
	if clean_label in ["Pet Shop", "Animal Market", "Stable & Menagerie", "Animal Dealer", "Bio-Companion Gallery", "Creature Market"]:
		return true
	if gs != null and gs.pet_shop_contract_engine != null and gs.pet_shop_contract_engine.has_method("shop_label_for_current_era"):
		return clean_label == str(gs.pet_shop_contract_engine.shop_label_for_current_era()).strip_edges()
	return false


static func _pet_shop_activity_label(gs: GameState) -> String:
	if gs != null and gs.pet_shop_contract_engine != null and gs.pet_shop_contract_engine.has_method("shop_label_for_current_era"):
		return str(gs.pet_shop_contract_engine.shop_label_for_current_era()).strip_edges()
	return "Pet Shop"


static func _relationship_hub_pet_card_contracts_for_player(gs: GameState) -> Array:
	if gs == null or gs.player == null:
		return []
	if gs.pets_contract_engine == null:
		return []
	return gs.pets_contract_engine.get_pet_cards_for_actor(gs.player, {
		"source": "mainscene.relationship_hub_pets_section"
	})


static func _entity_relationship_trait_color(trait_text: String, entity: Dictionary = {}) -> Color:
	var stats: Dictionary = MainSceneHelpers._safe_dictionary(entity.get("stats", {}))
	var trust_value: int = int(stats.get("trust", 50))
	var training_value: int = int(stats.get("training", 0))

	match str(trait_text).strip_edges().to_lower():
		"strong":
			return Color(1.0, 0.72, 0.42, 1.0)
		"sensitive":
			return Color(1.0, 0.56, 0.7, 1.0) if trust_value > 35 else Color(1.0, 0.38, 0.54, 1.0)
		"trainable":
			return Color(0.76, 1.0, 0.52, 1.0) if training_value >= 50 else Color(0.66, 0.94, 0.54, 1.0)
		"protective":
			return Color(0.8, 0.92, 1.0, 1.0)
		"playful":
			return Color(1.0, 0.92, 0.46, 1.0)
		"loyal":
			return Color(0.78, 1.0, 0.86, 1.0)
		"gentle":
			return Color(0.92, 0.86, 1.0, 1.0)
		"alert":
			return Color(1.0, 0.76, 0.38, 1.0)
		_:
			return Color(0.86, 0.92, 1.0, 1.0)


static func _entity_relationship_profile_commit_delta_for_stat(stat_key: String, state_delta: Dictionary, bond_delta: int = 0) -> int:
	var clean_key: String = str(stat_key).strip_edges().to_lower()
	if clean_key == "bond":
		return bond_delta

	var before_stats: Dictionary = MainSceneHelpers._safe_dictionary(state_delta.get("before", {}))
	var after_stats: Dictionary = MainSceneHelpers._safe_dictionary(state_delta.get("after", {}))
	if before_stats.is_empty() or after_stats.is_empty():
		return 0

	return int(after_stats.get(clean_key, before_stats.get(clean_key, 0))) - int(before_stats.get(clean_key, 0))


static func _pet_shop_actor_cache_key(gs: GameState,
	
	actor_id: int
) -> String:
	if gs == null:
		return str(
			actor_id
		)

	return "%d:%d:%s" % [
		int(
			actor_id
		),
		int(
			gs.year
		),
		(
			str(gs.era.name).strip_edges().to_lower()
			if gs.era != null
			else "unknown"
		)
	]


static func _activities_begin_boxing_should_render(gs: GameState) -> bool:
	if gs == null or gs.player == null:
		return false

	var actor: Person = gs.player
	if not bool(actor.alive):
		return false

	var profile: Dictionary = MainSceneHelpers._safe_dictionary(actor.boxing_profile)

	var already_started: bool = (
		bool(profile.get("is_boxer", false))
		or bool(profile.get("boxing_hub_unlocked", false))
		or bool(profile.get("boxing_career_started_by_player", false))
		or bool(profile.get("turned_pro", false))
		or bool(MainSceneHelpers._safe_dictionary(profile.get("amateur_circuit", {})).get("is_amateur", false))
	)

	if already_started:
		return false

	if bool(profile.get("retired", false)):
		return false

	return true


static func _grocery_store_music_resolve_path(file_name: String) -> String:
	for raw_path in MainSceneHelpers._grocery_store_music_candidate_paths(file_name):
		var path: String = str(raw_path).strip_edges()
		if path == "":
			continue
		if ResourceLoader.exists(path):
			return path

	return "res://audio/music/%s" % str(file_name).strip_edges()


static func _era_mart_store_music_candidate_paths() -> Array:
	return MainSceneHelpers._grocery_store_music_candidate_paths("EraMartMusic.ogg")


static func _era_mart_store_music_path() -> String:
	return _grocery_store_music_resolve_path("EraMartMusic.ogg")


static func _birth_intro_cry_entry_kind_allowed(entry_kind: String) -> bool:
	var normalized: String = str(entry_kind).strip_edges().to_lower()
	if normalized == "":
		normalized = "custom"

	var contract: Dictionary = MainSceneHelpers._birth_intro_cry_audio_contract()
	var allowed: Array = contract.get("allowed_entry_kinds", ["custom", "random"])
	return allowed.has(normalized)


static func _birth_intro_cry_current_player_is_newborn_start(gs: GameState) -> bool:
	if gs == null or gs.player == null:
		return false

	if int(gs.player.age) != 0:
		return false

	var settings: Dictionary = gs.custom_settings.duplicate(true) if typeof(gs.custom_settings) == TYPE_DICTIONARY else {}
	var entry_kind: String = str(settings.get("_god_mode_entry_kind", settings.get("god_mode_entry_kind", ""))).strip_edges().to_lower()

	if entry_kind == "household_curated_life":
		return bool(settings.get("birth_intro_cry_allowed", false))

	if bool(settings.get("birth_intro_cry_allowed", true)):
		return true

	if typeof(gs.scenario_state) == TYPE_DICTIONARY:
		if bool(gs.scenario_state.get("birth_intro_cry_allowed", false)):
			return true
		if bool(gs.scenario_state.get("birth_shell_player_is_newborn", false)):
			return true
		if bool(gs.scenario_state.get("birth_shell_intro_required", false)):
			return true
		if bool(gs.scenario_state.get("active_lineage_birth_contract", {}).get("birth_intro_cry_allowed", false)):
			return true

	return true


static func _process_realtime_notifications(gs: GameState):
	if gs.pending_death_messages.size() > 0:
		for msg in gs.pending_death_messages:
			EraLog.truth(msg)
		gs.pending_death_messages.clear()


static func _format_job_for_parent(job: String) -> String:
	var office_text: String = MainSceneHelpers._format_civic_office_article_title(job)
	if office_text != "":
		return office_text

	return "a %s" % job.to_lower()


static func _resolve_birth_relative_pair(gs: GameState,
	ids: Array) -> Array:
	var first: Person = null
	var second: Person = null
	var extras: Array = []

	for raw_id in ids:
		var rel: Person = gs.get_or_reactivate_npc_by_id(int(raw_id))
		if rel == null:
			continue

		if rel.gender == "Male" and first == null:
			first = rel
		elif rel.gender == "Female" and second == null:
			second = rel
		else:
			extras.append(rel)

	if first == null and extras.size() > 0:
		first = extras [0]

	if second == null:
		for extra in extras:
			if extra != first:
				second = extra
				break

	return [first, second]


static func _format_birth_relative_royal_role(npc: Person) -> String:
	if npc == null or not npc.is_royal:
		return ""
	var title:= str(npc.royal_title).strip_edges()
	var job_text:= str(npc.job).strip_edges()
	if title == "":
		if job_text == "" or job_text == "Retired":
			return ""
		return "The %s" % MainSceneHelpers._crown_title_case(job_text)
	if title.begins_with("Former "):
		var former_title:= title.substr(7, title.length() - 7).strip_edges()
		return "The Former %s" % MainSceneHelpers._crown_title_case(former_title)
	if job_text == "Retired":
		return "The Retired %s" % MainSceneHelpers._crown_title_case(title)
	return "The %s" % MainSceneHelpers._crown_title_case(title)


static func _resolve_age_up_loading_theme_key(gs: GameState,
	loading_context: Dictionary = {}, overlay_context: Dictionary = {}) -> String:
	var forced_theme_key: String = str(
		loading_context.get(
			"force_target_theme_key",
			overlay_context.get("force_target_theme_key", "")
		)
	).strip_edges().to_lower()
	if forced_theme_key != "":
		return forced_theme_key
	var explicit_theme_key: String = str(
		loading_context.get(
			"theme_key",
			overlay_context.get("theme_key", "")
		)
	).strip_edges().to_lower()
	if explicit_theme_key != "":
		return explicit_theme_key
	var era_name: String = str(
		overlay_context.get(
			"era_name",
			loading_context.get("era_name", "")
		)
	).strip_edges().to_lower()
	if era_name == "":
		era_name = str(
			loading_context.get(
				"target_era_name",
				overlay_context.get("target_era_name", "")
			)
		).strip_edges().to_lower()
	if era_name == "":
		var target_year: int = int(
			overlay_context.get(
				"target_year",
				loading_context.get("target_year", 0)
			)
		)
		if target_year != 0 and gs != null and gs.era_engine != null and gs.era_engine.has_method("_era_from_year"):
			var resolved_era: Variant = gs.era_engine._era_from_year(target_year)
			if typeof(resolved_era) == TYPE_DICTIONARY:
				era_name = str(resolved_era.get("name", "")).strip_edges().to_lower()
	if era_name != "":
		if "ancient" in era_name:
			return "ancient"
		if "medieval" in era_name:
			return "medieval"
		if "industrial" in era_name:
			return "industrial"
		if "future" in era_name:
			return "future"
	return _era_border_theme_key_from_world(gs)


static func _resume_nonvisible_age_up_result(gs: GameState,
	result: Dictionary) -> Dictionary:
	if gs == null or gs.life_engine == null:
		return result
	if str(result.get("type", "")) != "year_pipeline_pending":
		return result
	if gs.life_engine.has_method("continue_nonvisible_age_up_transaction"):
		return gs.life_engine.continue_nonvisible_age_up_transaction()
	return result


static func _build_speculative_year_precompute_signature(gs: GameState) -> String:
	if gs == null or gs.player == null:
		return ""
	var npc_count: int = int(gs.npcs.size())
	var dormant_count: int = int(gs.dormant_npcs.size())
	var world_feed_count: int = int(gs.world_feed.size())
	var player_age: int = int(gs.player.age)
	var player_id: int = int(gs.player.id)
	return "%d|%d|%d|%d|%d|%d|%s" % [
		int(gs.year + 1),
		player_id,
		player_age,
		npc_count,
		dormant_count,
		world_feed_count,
		str(gs.reality_mode)
	]


static func _speculative_population_precompute_lane(gs: GameState,
	next_year: int) -> Dictionary:
	var lane: Dictionary = {
		"ready": true,
		"year": next_year,
		"active_count": int(gs.npcs.size()) if gs != null else 0,
		"dormant_count": int(gs.dormant_npcs.size()) if gs != null else 0,
		"can_apply": false
	}
	if gs == null:
		return lane
	if gs.population_lifecycle_manager != null and gs.population_lifecycle_manager.has_method("speculative_precompute_next_year"):
		lane ["payload"] = gs.population_lifecycle_manager.speculative_precompute_next_year({
			"year": next_year,
			"budget_ms": 1
		})
		lane ["can_apply"] = true
	return lane


static func _speculative_faction_pressure_precompute_lane(gs: GameState,
	next_year: int) -> Dictionary:
	var lane: Dictionary = {
		"ready": true,
		"year": next_year,
		"faction_count": int(gs.universal_faction_state.size()) if gs != null and typeof(gs.universal_faction_state) == TYPE_DICTIONARY else 0,
		"can_apply": false
	}
	if gs == null:
		return lane
	if gs.universal_faction_engine != null and gs.universal_faction_engine.has_method("speculative_precompute_pressure"):
		lane ["payload"] = gs.universal_faction_engine.speculative_precompute_pressure({
			"year": next_year,
			"budget_ms": 1
		})
		lane ["can_apply"] = true
	return lane


static func _speculative_economy_precompute_lane(gs: GameState,
	next_year: int) -> Dictionary:
	var lane: Dictionary = {
		"ready": true,
		"year": next_year,
		"can_apply": false
	}
	if gs == null:
		return lane
	if gs.economy_engine != null and gs.economy_engine.has_method("speculative_precompute_year"):
		lane ["payload"] = gs.economy_engine.speculative_precompute_year({
			"year": next_year,
			"budget_ms": 1
		})
		lane ["can_apply"] = true
	elif gs.global_market_engine != null and gs.global_market_engine.has_method("speculative_precompute_year"):
		lane ["payload"] = gs.global_market_engine.speculative_precompute_year({
			"year": next_year,
			"budget_ms": 1
		})
		lane ["can_apply"] = true
	return lane


static func _get_age_up_loading_recent_did_you_know_keys(gs: GameState) -> Array:
	if gs == null:
		return []

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var raw_keys: Variant = gs.scenario_state.get("age_up_loading_recent_did_you_know_keys", [])
	var keys: Array = raw_keys if typeof(raw_keys) == TYPE_ARRAY else []
	var cleaned: Array = []

	for raw_key in keys:
		var key: String = str(raw_key).strip_edges()
		if key != "":
			cleaned.append(key)

	return cleaned


static func _store_age_up_loading_recent_did_you_know_keys(gs: GameState,
	keys: Array) -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	gs.scenario_state ["age_up_loading_recent_did_you_know_keys"] = keys.duplicate(true)


static func _build_age_up_loading_live_did_you_know_cache_key(gs: GameState,
	overlay_context: Dictionary) -> String:
	if gs == null or gs.player == null:
		return "no_player"

	var player: Person = gs.player
	var target_year: int = int(overlay_context.get("target_year", gs.year if gs != null else 0))
	var last_name: String = str(player.last_name).strip_edges().to_lower()
	var parent_signature: int = 0
	if typeof(player.parents) == TYPE_ARRAY and not player.parents.is_empty():
		parent_signature = abs(int(str(player.parents).hash()))

	var bias_raw: Variant = gs.transient_scenario_biases.get(int(player.id), {})
	var bias: Dictionary = {}
	if typeof(bias_raw) == TYPE_ARRAY:
		var bias_bucket: Array = bias_raw
		if not bias_bucket.is_empty() and typeof(bias_bucket [0]) == TYPE_DICTIONARY:
			bias = bias_bucket [0]
	elif typeof(bias_raw) == TYPE_DICTIONARY:
		bias = bias_raw

	var faction_pressure_raw: Variant = bias.get("faction_pressure", {})
	var faction_pressure: Dictionary = faction_pressure_raw if typeof(faction_pressure_raw) == TYPE_DICTIONARY else {}

	return "%d|%d|%s|%d|%d|%d|%d|%d|%d|%d|%d" % [
		int(player.id),
		target_year,
		last_name,
		1 if bool(player.is_royal) else 0,
		parent_signature,
		int(round(float(faction_pressure.get("justice_pressure", 0.0)))),
		int(round(float(faction_pressure.get("syndicate_turf_pressure", 0.0)))),
		int(round(float(faction_pressure.get("workplace_pressure", 0.0)))),
		int(round(float(faction_pressure.get("dynasty_pressure", 0.0)))),
		int(round(float(faction_pressure.get("neighborhood_pressure", 0.0)))),
		int(round(float(faction_pressure.get("hidden_realm_instability", 0.0))))
	]


static func _merged_feature_overrides_from_settings(gs: GameState) -> Dictionary:
	var saved_mode:= str(gs.custom_settings.get("reality_mode", "chaos")).to_lower()
	var merged:= MainSceneHelpers._feature_overrides_for_mode(saved_mode)

	var saved_overrides = gs.custom_settings.get("feature_overrides", {})
	if typeof(saved_overrides) == TYPE_DICTIONARY:
		for key in MainSceneHelpers._feature_override_keys():
			if saved_overrides.has(key):
				merged [key] = bool(saved_overrides [key])

	return merged


static func _god_mode_back_to_main_menu_circle_shell_size() -> int:
	return MainSceneHelpers._god_mode_back_to_main_menu_circle_button_size() + 22


static func _reality_mode_allows_elemental_birth_locations(mode_text: String) -> bool:
	var clean_mode: String = str(mode_text).strip_edges().to_lower()
	if clean_mode == "":
		clean_mode = "chaos"

	if clean_mode == "realistic":
		return false

	var overrides: Dictionary = MainSceneHelpers._feature_overrides_for_mode(clean_mode)
	return bool(overrides.get("bending", true))


static func _filter_birth_countries_for_reality_mode(countries: Array, mode_text: String) -> Array:
	if _reality_mode_allows_elemental_birth_locations(mode_text):
		return countries.duplicate(true)

	var filtered: Array = []
	for raw_country in countries:
		var country_text: String = str(raw_country).strip_edges()
		if country_text == "":
			continue
		if MainSceneHelpers._is_elemental_nation_name(country_text):
			continue
		filtered.append(country_text)

	return filtered


static func _friendly_reality_mode_label(mode_text: String) -> String:
	match MainSceneHelpers._canonical_reality_mode_key(mode_text):
		"realistic":
			return "Realistic"
		"enhanced":
			return "Enhanced"
		"chaos":
			return "Chaos"
		_:
			return "Chaos"


static func _superpower_catalog_ids(gs: GameState) -> Array:
	var out: Array = []
	if gs != null and gs.power_engine != null:
		var registry_raw: Variant = gs.power_engine.contract_registry
		if typeof(registry_raw) == TYPE_DICTIONARY:
			var registry: Dictionary = registry_raw
			for raw_key in registry.keys():
				var power_id: String = str(raw_key).strip_edges().to_lower()
				if power_id == "":
					continue
				out.append(power_id)

	out.sort()

	if out.is_empty():
		out = [
			"super_strength",
			"super_speed",
			"spider_abilities",
			"infant_chaos_polymorph",
			"energy_projection",
			"telepathy",
			"probability_manipulation",
			"super_serum",
			"adamantium_skeleton"
		]

	return out


static func _superpower_catalog_label(gs: GameState,
	power_id: String) -> String:
	var clean_power_id:= str(power_id).strip_edges().to_lower()
	if gs != null and gs.power_engine != null and gs.power_engine.has_method("get_power_contract"):
		var contract: Dictionary = gs.power_engine.get_power_contract(clean_power_id)
		if typeof(contract) == TYPE_DICTIONARY and not contract.is_empty():
			return str(contract.get("display_name", clean_power_id.replace("_", " ").capitalize()))

	return clean_power_id.replace("_", " ").capitalize()


static func _build_superpower_sandbox_summary(gs: GameState,
	config: Dictionary) -> String:
	if config.is_empty():
		return "No power is bound yet. The bloodline is quiet, but the sky is listening."

	var scope_label:= str(config.get("scope", "only_me")).replace("_", " ").capitalize()
	var origin_label:= str(config.get("origin", "born_hidden")).replace("_", " ").capitalize()
	var power_label:= _superpower_catalog_label(gs, str(config.get("primary_power", "super_strength")))
	var identity_label:= str(config.get("public_identity", "secret")).replace("_", " ").capitalize()

	var awakening: Dictionary = config.get("awakening", {})
	var awakening_label:= str(awakening.get("mode", "latent")).replace("_", " ").capitalize()

	var inheritance: Dictionary = config.get("inheritance", {})
	var flags: Array = []

	if bool(inheritance.get("awakens_under_trauma", false)):
		flags.append("trauma ignition")
	if bool(inheritance.get("awakens_at_age_13", false)):
		flags.append("age 13 spark")
	if bool(inheritance.get("only_firstborn", false)):
		flags.append("firstborn seal")
	if bool(inheritance.get("only_avatars_benders", false)):
		flags.append("bender-linked genome")
	if bool(inheritance.get("corrupts_bloodline_over_time", false)):
		flags.append("bloodline decay")

	var flag_text:= ""
	if not flags.is_empty():
		flag_text = " • %s" % ", ".join(flags)

	return "Bound Power: %s • Origin: %s • Awakening: %s • Scope: %s • Identity: %s%s" % [
		power_label,
		origin_label,
		awakening_label,
		scope_label,
		identity_label,
		flag_text
	]


static func _startup_intro_should_glitch_bridge_payload(remaining_ms: int, hyper_active: bool) -> bool:
	if not hyper_active:
		return false

	return remaining_ms <= MainSceneHelpers._startup_intro_bridge_payload_glitch_window_ms()


static func _startup_intro_sequence_bundle_signature(intro_sequence: Array, bridge_sequence: Array) -> String:
	return "%s||%s" % [
		MainSceneHelpers._startup_intro_sequence_signature(intro_sequence),
		MainSceneHelpers._startup_intro_sequence_signature(bridge_sequence)
	]


static func _startup_intro_format_procedural_year(raw_year: Variant) -> String:
	var year_value: int = int(raw_year)

	if year_value < 0:
		return "%d BCE" % abs(year_value)

	if year_value == 0:
		return "1 BCE"

	if year_value <= MainSceneHelpers._startup_intro_ad_suffix_cutoff_year():
		return "%d AD" % year_value

	return str(year_value)


static func _startup_intro_apply_massive_pool_expansion(base_contract: Dictionary) -> Dictionary:
	var contract: Dictionary = base_contract.duplicate(true)
	contract ["version"] = 3
	contract ["schema"] = "eralife.procedural_cinematic_sequence_contract"
	contract ["expansion"] = "massive_grounded_to_legendary_recipe_pool_pass"
	contract ["recent_memory_limit"] = 768
	contract ["runtime_content_strategy"] = "static_pools_plus_o1_recipe_generation"

	var pool_rotation: Array = contract.get("pool_rotation", []) if typeof(contract.get("pool_rotation", [])) == TYPE_ARRAY else []
	var pools: Dictionary = contract.get("pools", {}) if typeof(contract.get("pools", {})) == TYPE_DICTIONARY else {}

	var static_expansion: Dictionary = MainSceneHelpers._startup_intro_massive_static_pool_expansion()
	var generated_recipes: Dictionary = MainSceneHelpers._startup_intro_massive_generated_pool_recipes()

	_startup_intro_merge_pool_expansion(pool_rotation, pools, static_expansion)
	MainSceneHelpers._startup_intro_merge_generated_recipe_pool_ids(pool_rotation, generated_recipes)

	contract ["pool_rotation"] = pool_rotation
	contract ["pools"] = pools
	contract ["generated_recipe_pools"] = generated_recipes
	contract ["expanded_pool_count"] = pool_rotation.size()
	contract ["expanded_moment_count"] = MainSceneHelpers._startup_intro_count_pool_moments(pools) + MainSceneHelpers._startup_intro_count_recipe_pool_combinations(generated_recipes)

	return contract


static func _startup_intro_generate_recipe_pool_moment(pool_id: String, recipe: Dictionary, rng: RandomNumberGenerator, phase: String, slot_index: int) -> Dictionary:
	var years: Array = recipe.get("years", []) if typeof(recipe.get("years", [])) == TYPE_ARRAY else []
	var subjects: Array = recipe.get("subjects", []) if typeof(recipe.get("subjects", [])) == TYPE_ARRAY else []
	var outcomes: Array = recipe.get("outcomes", []) if typeof(recipe.get("outcomes", [])) == TYPE_ARRAY else []
	var era_tag: String = str(recipe.get("era", "modern")).strip_edges().to_lower()
	var clean_pool_id: String = str(pool_id).strip_edges()

	if years.is_empty() or subjects.is_empty() or outcomes.is_empty():
		return {}

	for attempt in range(32):
		var year_value: int = int(years [int(rng.randi_range(0, years.size() - 1))])
		var subject_text: String = str(subjects [int(rng.randi_range(0, subjects.size() - 1))]).strip_edges()
		var outcome_text: String = str(outcomes [int(rng.randi_range(0, outcomes.size() - 1))]).strip_edges()

		if subject_text == "" or outcome_text == "":
			continue

		if not MainSceneHelpers._startup_intro_generated_subject_allows_outcome(clean_pool_id, subject_text, outcome_text):
			continue

		var line_text: String = "%s %s." % [subject_text, outcome_text]
		var event_signature: String = MainSceneHelpers._startup_intro_event_signature_from_line(line_text)
		var line_key: String = _startup_intro_line_identity_key(line_text)
		var opening_key: String = _startup_intro_line_opening_key(line_text, 3)
		var subject_key: String = _startup_intro_subject_identity_key(line_text)

		return {
			"year": year_value,
			"era": era_tag,
			"line": line_text,
			"pool_label": clean_pool_id,
			"phase": phase,
			"slot_index": slot_index,
			"event_signature": event_signature,
			"line_identity_key": line_key,
			"intro_opening_key": opening_key,
			"subject_identity_key": subject_key,
			"year_identity_key": str(year_value),
		}

	return {}


static func _startup_intro_merge_pool_expansion(pool_rotation: Array, pools: Dictionary, expansion: Dictionary) -> void:
	for raw_pool_id in expansion.keys():
		var pool_id: String = str(raw_pool_id).strip_edges()
		if pool_id == "":
			continue

		if not pool_rotation.has(pool_id):
			pool_rotation.append(pool_id)

		var base_pool: Array = pools.get(pool_id, []) if typeof(pools.get(pool_id, [])) == TYPE_ARRAY else []
		var add_pool: Array = expansion.get(pool_id, []) if typeof(expansion.get(pool_id, [])) == TYPE_ARRAY else []

		var known_keys: Dictionary = {}
		for raw_existing in base_pool:
			if typeof(raw_existing) != TYPE_DICTIONARY:
				continue
			var existing: Dictionary = raw_existing
			known_keys [MainSceneHelpers._startup_intro_moment_key(existing)] = true

		for raw_moment in add_pool:
			if typeof(raw_moment) != TYPE_DICTIONARY:
				continue

			var moment: Dictionary = (raw_moment as Dictionary).duplicate(true)
			var moment_key: String = MainSceneHelpers._startup_intro_moment_key(moment)
			if known_keys.has(moment_key):
				continue

			known_keys [moment_key] = true
			base_pool.append(moment)

		pools [pool_id] = base_pool


static func _startup_intro_massive_generated_pool_expansion() -> Dictionary:
	var expansion: Dictionary = {}

	_startup_intro_add_generated_pool(
		expansion,
		"grounded_modern_headlines",
		"modern",
		[1984, 1999, 2007, 2016, 2020, 2026, 2031, 2037],
		[
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
		[
			"was arrested for murder",
			"abandoned his family",
			"vanished before sentencing",
			"confessed on live television",
			"hid a second life",
			"became a scandal overnight",
			"lost everything after one phone call",
			"bought silence and called it peace"
		]
	)

	_startup_intro_add_generated_pool(
		expansion,
		"ancient_empire_pressure",
		"ancient",
		[-333, -218, -120, -60, -33, -12, 33, 41, 79, 177, 210, 305, 399],
		[
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
		[
			"go to war",
			"broke an oath before sunrise",
			"followed a sign nobody else could see",
			"buried a weapon beneath the river",
			"turned a betrayal into law",
			"survived a prophecy meant to kill them",
			"opened a door beneath the palace",
			"vanished from every official record"
		]
	)

	_startup_intro_add_generated_pool(
		expansion,
		"medieval_oaths_and_realms",
		"medieval",
		[410, 476, 512, 580, 611, 620, 642, 666, 701, 718, 741, 750, 793, 1066, 1099, 1204, 1348, 1453, 1492],
		[
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
		[
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
	)

	_startup_intro_add_generated_pool(
		expansion,
		"industrial_pressure_cooker",
		"industrial",
		[1666, 1776, 1815, 1833, 1842, 1847, 1888, 1892, 1906, 1914, 1918],
		[
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
		[
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
	)

	_startup_intro_add_generated_pool(
		expansion,
		"future_mythic_systems",
		"future",
		[2043, 2059, 2075, 2091, 2148, 2210, 2410, 2655, 2826, 3022, 4001],
		[
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
		[
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
	)

	return expansion


static func _startup_intro_add_generated_pool(expansion: Dictionary, pool_id: String, era_tag: String, years: Array, subjects: Array, outcomes: Array) -> void:
	var clean_pool_id: String = str(pool_id).strip_edges()
	if clean_pool_id == "":
		return

	if not expansion.has(clean_pool_id):
		expansion [clean_pool_id] = []

	var out: Array = expansion.get(clean_pool_id, []) if typeof(expansion.get(clean_pool_id, [])) == TYPE_ARRAY else []

	for special_moment in MainSceneHelpers._startup_intro_generated_pool_special_moments(clean_pool_id, era_tag):
		if typeof(special_moment) != TYPE_DICTIONARY:
			continue
		out.append((special_moment as Dictionary).duplicate(true))

	for raw_year in years:
		for raw_subject in subjects:
			for raw_outcome in outcomes:
				var subject_text: String = str(raw_subject).strip_edges()
				var outcome_text: String = str(raw_outcome).strip_edges()
				if subject_text == "" or outcome_text == "":
					continue

				if not MainSceneHelpers._startup_intro_generated_subject_allows_outcome(clean_pool_id, subject_text, outcome_text):
					continue

				var line_text: String = "%s %s." % [subject_text, outcome_text]
				var event_signature: String = MainSceneHelpers._startup_intro_event_signature_from_line(line_text)

				out.append({
					"year": int(raw_year),
					"era": str(era_tag).strip_edges().to_lower(),
					"line": line_text,
					"event_signature": event_signature,
				})

	expansion [clean_pool_id] = out


static func _startup_intro_line_identity_key(line_text: String) -> String:
	return MainSceneHelpers._startup_intro_compact_identity_text(line_text)


static func _startup_intro_identity_words(line_text: String) -> Array:
	var clean: String = MainSceneHelpers._startup_intro_compact_identity_text(line_text)
	if clean == "":
		return []

	var raw_words: Array = clean.split(" ", false)
	var out: Array = []
	for raw_word in raw_words:
		var word: String = str(raw_word).strip_edges()
		if word == "":
			continue
		out.append(word)

	return out


static func _startup_intro_line_opening_key(line_text: String, word_count: int = 3) -> String:
	var words: Array = _startup_intro_identity_words(line_text)
	if words.is_empty():
		return ""

	var take_count: int = clamp(int(word_count), 1, words.size())
	var out: Array = []
	for i in range(take_count):
		out.append(str(words [i]))

	return " ".join(out)


static func _startup_intro_subject_identity_key(line_text: String) -> String:
	var words: Array = _startup_intro_identity_words(line_text)
	if words.is_empty():
		return ""

	var start_index: int = 0
	if str(words [0]) in ["a", "an", "the"]:
		start_index = 1

	if start_index >= words.size():
		return _startup_intro_line_opening_key(line_text, 3)

	var take_count: int = min(2, words.size() - start_index)
	var subject_words: Array = []
	for i in range(take_count):
		subject_words.append(str(words [start_index + i]))

	return " ".join(subject_words).strip_edges()


static func _startup_intro_perceptual_integrity_engine(gs: GameState):
	if gs == null:
		return null

	if not "perceptual_integrity_engine" in gs:
		return null

	if gs.perceptual_integrity_engine == null:
		gs.perceptual_integrity_engine = PerceptualIntegrityEngine.new(gs)

	return gs.perceptual_integrity_engine


static func _startup_intro_register_used_moment_identity(gs: GameState,
	moment: Dictionary, used_keys: Dictionary, fallback_phase: String = "") -> void:
	if typeof(moment) != TYPE_DICTIONARY:
		return

	var engine = _startup_intro_perceptual_integrity_engine(gs)
	if engine != null and engine.has_method("register_used_moment_identity"):
		engine.register_used_moment_identity(
			moment,
			used_keys,
			MainSceneHelpers._startup_intro_perceptual_integrity_context(
				str(moment.get("phase", fallback_phase)),
				int(moment.get("slot_index", -1)),
				0,
				str(moment.get("pool_label", ""))
			)
		)
		return

	var line_text: String = str(moment.get("line", "")).strip_edges()
	var line_key: String = str(moment.get("line_identity_key", _startup_intro_line_identity_key(line_text))).strip_edges()
	var opening_key: String = str(moment.get("intro_opening_key", _startup_intro_line_opening_key(line_text, 3))).strip_edges()
	var subject_key: String = str(moment.get("subject_identity_key", _startup_intro_subject_identity_key(line_text))).strip_edges()
	var event_signature: String = str(moment.get("event_signature", MainSceneHelpers._startup_intro_event_signature_from_line(line_text))).strip_edges()
	var year_key: String = MainSceneHelpers._startup_intro_moment_year_identity_key(moment)
	var pool_id: String = str(moment.get("pool_label", "")).strip_edges()
	var phase: String = str(moment.get("phase", fallback_phase)).strip_edges()

	if line_key != "":
		used_keys ["_line_identity:%s" % line_key] = true
		used_keys ["_last_line_identity_key"] = line_key
	if opening_key != "":
		used_keys ["_opening_identity:%s" % opening_key] = true
		used_keys ["_last_opening_key"] = opening_key
	if subject_key != "":
		used_keys ["_subject_identity:%s" % subject_key] = true
		used_keys ["_last_subject_key"] = subject_key
	if event_signature != "":
		used_keys ["_event_signature:%s" % event_signature] = true
	if year_key != "":
		used_keys ["_year_identity:%s" % year_key] = true
		used_keys ["_last_year_key"] = year_key
	if pool_id != "":
		var pool_use_key: String = "_pool_count:%s" % pool_id
		used_keys [pool_use_key] = int(used_keys.get(pool_use_key, 0)) + 1
		used_keys ["_last_pool_id"] = pool_id
	if line_text != "":
		used_keys ["%s|%s|%s" % [
			year_key,
			line_text,
			phase
		]] = true


static func _startup_intro_current_reality_mode_tag(gs: GameState) -> String:
	if gs != null:
		var raw_mode: String = str(gs.reality_mode).strip_edges().to_lower()
		if raw_mode != "":
			return raw_mode

	return "chaos"


static func _startup_intro_pool_allowed_for_current_reality(gs: GameState,
	pool_id: String) -> bool:
	var mode: String = _startup_intro_current_reality_mode_tag(gs)
	var clean_pool: String = str(pool_id).strip_edges().to_lower()

	if mode == "chaos":
		return true

	if mode == "enhanced":
		if clean_pool in ["realm_anomalies", "future_mythic_systems"]:
			return true
		return true

	if mode == "realistic":
		if clean_pool.find("bending") >= 0:
			return false
		if clean_pool.find("cosmic") >= 0:
			return false
		if clean_pool.find("realm") >= 0:
			return false
		if clean_pool.find("mythic") >= 0:
			return false
		if clean_pool in ["artifact_discoveries"]:
			return false

	return true


static func _startup_intro_moment_to_beat(moment: Dictionary, timing: Dictionary = {}) -> Dictionary:
	var era_tag: String = str(moment.get("era", "unknown")).strip_edges().to_lower()
	var line_text: String = str(moment.get("line", "The world moved before anyone knew your name."))
	var event_signature: String = str(moment.get("event_signature", MainSceneHelpers._startup_intro_event_signature_from_line(line_text))).strip_edges()
	var line_key: String = str(moment.get("line_identity_key", _startup_intro_line_identity_key(line_text))).strip_edges()
	var opening_key: String = str(moment.get("intro_opening_key", _startup_intro_line_opening_key(line_text, 3))).strip_edges()
	var subject_key: String = str(moment.get("subject_identity_key", _startup_intro_subject_identity_key(line_text))).strip_edges()
	var raw_year_value: int = int(moment.get("year", 1))
	var year_key: String = str(moment.get("year_identity_key", str(raw_year_value))).strip_edges()
	var colors: Dictionary = MainSceneHelpers._startup_intro_procedural_color_for_era_tag(era_tag)

	var beat: Dictionary = {
		"year": _startup_intro_format_procedural_year(raw_year_value),
		"raw_year": raw_year_value,
		"line": line_text,
		"year_color": colors.get("year_color", Color(1.0, 1.0, 1.0, 1.0)),
		"line_color": colors.get("line_color", Color(1.0, 1.0, 1.0, 1.0)),
		"pitch": float(timing.get("pitch", 1.0)),
		"era_tag": era_tag,
		"pool_label": str(moment.get("pool_label", "unknown")),
		"event_signature": event_signature,
		"line_identity_key": line_key,
		"intro_opening_key": opening_key,
		"subject_identity_key": subject_key,
		"year_identity_key": year_key,
	}

	if timing.has("fade_in"):
		beat ["fade_in"] = float(timing.get("fade_in", 0.2))
	if timing.has("hold"):
		beat ["hold"] = float(timing.get("hold", 0.2))
	if timing.has("fade_out"):
		beat ["fade_out"] = float(timing.get("fade_out", 0.15))

	return beat


static func _household_creator_load_unfinished_drafts_from_disk() -> Array:
	var path: String = MainSceneHelpers._household_creator_unfinished_drafts_storage_path()
	if not FileAccess.file_exists(path):
		return []

	var file:= FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Could not open unfinished household draft storage: %s" % path)
		return []

	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	var raw_drafts: Array = []

	if typeof(parsed) == TYPE_ARRAY:
		raw_drafts = parsed as Array
	elif typeof(parsed) == TYPE_DICTIONARY:
		var payload: Dictionary = parsed as Dictionary
		var drafts_raw: Variant = payload.get("drafts", payload.get("unfinished_household_creation_contracts", []))
		if typeof(drafts_raw) == TYPE_ARRAY:
			raw_drafts = drafts_raw as Array

	return MainSceneHelpers._household_creator_normalize_unfinished_drafts(raw_drafts)


static func _household_creator_save_unfinished_drafts_to_disk(drafts: Array) -> void:
	var normalized_drafts: Array = MainSceneHelpers._household_creator_normalize_unfinished_drafts(drafts)
	var payload: Dictionary = {
		"schema": "eralife.unfinished_household_creation_contract_storage",
		"version": 1,
		"storage_key": "unfinished_household_creation_contracts",
		"drafts": normalized_drafts.duplicate(true),
		"saved_at_ms": int(Time.get_ticks_msec()),
		"saved_at_unix": int(Time.get_unix_time_from_system())
	}

	var path: String = MainSceneHelpers._household_creator_unfinished_drafts_storage_path()
	var file:= FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write unfinished household draft storage: %s" % path)
		return

	file.store_string(JSON.stringify(payload, "\t"))
	file.close()


static func _household_creator_unfinished_drafts(gs: GameState) -> Array:
	var disk_drafts: Array = _household_creator_load_unfinished_drafts_from_disk()
	var session_drafts: Array = []

	if gs != null:
		if typeof(gs.scenario_state) != TYPE_DICTIONARY:
			gs.scenario_state = {}

		var raw: Variant = gs.scenario_state.get("unfinished_household_creation_contracts", [])
		if typeof(raw) == TYPE_ARRAY:
			session_drafts = raw as Array
		else:
			gs.scenario_state ["unfinished_household_creation_contracts"] = []

	var merged: Array = []
	merged.append_array(disk_drafts)
	merged.append_array(session_drafts)

	var normalized: Array = MainSceneHelpers._household_creator_normalize_unfinished_drafts(merged)

	if gs != null:
		gs.scenario_state ["unfinished_household_creation_contracts"] = normalized.duplicate(true)

	if disk_drafts.is_empty() and not session_drafts.is_empty() and not normalized.is_empty():
		_household_creator_save_unfinished_drafts_to_disk(normalized)

	return normalized.duplicate(true)


static func _household_creator_store_unfinished_draft(gs: GameState,
	draft: Dictionary) -> void:
	var draft_id: String = str(draft.get("draft_id", "")).strip_edges()
	if draft_id == "":
		return

	var drafts: Array = _household_creator_unfinished_drafts(gs)
	var replaced: bool = false

	for i in range(drafts.size()):
		if typeof(drafts [i]) != TYPE_DICTIONARY:
			continue

		if str((drafts [i] as Dictionary).get("draft_id", "")).strip_edges() == draft_id:
			drafts [i] = draft.duplicate(true)
			replaced = true
			break

	if not replaced:
		drafts.append(draft.duplicate(true))

	drafts = MainSceneHelpers._household_creator_normalize_unfinished_drafts(drafts)

	if gs != null:
		if typeof(gs.scenario_state) != TYPE_DICTIONARY:
			gs.scenario_state = {}
		gs.scenario_state ["unfinished_household_creation_contracts"] = drafts.duplicate(true)

	_household_creator_save_unfinished_drafts_to_disk(drafts)


static func _household_creator_remove_unfinished_draft(gs: GameState,
	draft_id: String) -> void:
	var clean_id: String = str(draft_id).strip_edges()
	if clean_id == "":
		return

	var drafts: Array = _household_creator_unfinished_drafts(gs)
	var kept: Array = []

	for raw_draft in drafts:
		if typeof(raw_draft) != TYPE_DICTIONARY:
			continue

		var draft: Dictionary = raw_draft as Dictionary
		if str(draft.get("draft_id", "")).strip_edges() == clean_id:
			continue

		kept.append(draft.duplicate(true))

	kept = MainSceneHelpers._household_creator_normalize_unfinished_drafts(kept)

	if gs != null:
		if typeof(gs.scenario_state) != TYPE_DICTIONARY:
			gs.scenario_state = {}
		gs.scenario_state ["unfinished_household_creation_contracts"] = kept.duplicate(true)

	_household_creator_save_unfinished_drafts_to_disk(kept)


static func _ensure_family_creation_contract_engine(gs: GameState) -> void:
	if gs == null:
		return
	if gs.family_creation_contract_engine == null:
		gs.family_creation_contract_engine = FamilyCreationContractEngine.new(gs)


static func _household_creator_house_type_options_for(gs: GameState,
	default_class: String, era_key: String) -> Array:
	_ensure_family_creation_contract_engine(gs)

	if gs != null and gs.family_creation_contract_engine != null:
		return gs.family_creation_contract_engine.house_type_options_for(era_key, default_class)

	return ["Family home", "Apartment", "Townhouse"]


static func _household_creator_validate_world_contract(gs: GameState,
	world_contract: Dictionary) -> Dictionary:
	_ensure_family_creation_contract_engine(gs)
	if gs != null and gs.family_creation_contract_engine != null:
		return gs.family_creation_contract_engine.validate_world_contract(world_contract)

	for key in ["era", "year", "reality_mode", "default_social_class", "house_type", "country", "city"]:
		if str(world_contract.get(key, "")).strip_edges() == "":
			return {
				"success": false,
				"reason": "Select %s first." % key
			}

	return {
		"success": true,
		"reason": "World contract valid."
	}


static func _household_creator_life_stage_for_age(gs: GameState,
	age_value: int) -> String:
	_ensure_family_creation_contract_engine(gs)
	if gs != null and gs.family_creation_contract_engine != null:
		return gs.family_creation_contract_engine.life_stage_for_age(age_value)

	if age_value <= 1:
		return "Baby"
	if age_value <= 12:
		return "Child"
	if age_value <= 17:
		return "Teen"
	if age_value <= 64:
		return "Adult"
	return "Elder"


static func _household_creator_member_requires_job(gs: GameState,
	age_value: int) -> bool:
	_ensure_family_creation_contract_engine(gs)
	if gs != null and gs.family_creation_contract_engine != null and gs.family_creation_contract_engine.has_method("member_requires_job"):
		return bool(gs.family_creation_contract_engine.member_requires_job(age_value))

	return int(age_value) >= 18


static func _household_creator_life_stage_age_range(gs: GameState,
	stage_text: String) -> Dictionary:
	_ensure_family_creation_contract_engine(gs)
	if gs != null and gs.family_creation_contract_engine != null and gs.family_creation_contract_engine.has_method("life_stage_age_range"):
		return gs.family_creation_contract_engine.life_stage_age_range(stage_text)

	var stage: String = str(stage_text).strip_edges().to_lower()
	match stage:
		"baby":
			return { "min": 0, "max": 1, "default": 0}
		"child":
			return { "min": 2, "max": 12, "default": 8}
		"teen":
			return { "min": 13, "max": 17, "default": 16}
		"elder":
			return { "min": 65, "max": 130, "default": 70}
		_:
			return { "min": 18, "max": 64, "default": 25}


static func _household_creator_relationship_gender_lock(gs: GameState,
	raw_relation: String) -> String:
	_ensure_family_creation_contract_engine(gs)
	if gs != null and gs.family_creation_contract_engine != null and gs.family_creation_contract_engine.has_method("relationship_gender_lock"):
		return str(gs.family_creation_contract_engine.relationship_gender_lock(raw_relation)).strip_edges().to_lower()

	var relation: String = _household_normalize_relationship(gs, raw_relation)
	match relation:
		"father", "son", "brother", "husband", "uncle":
			return "male"
		"mother", "daughter", "sister", "wife", "aunt":
			return "female"
		_:
			return ""


static func _household_creator_gender_adjusted_relationship(gs: GameState,
	raw_relation: String, gender_text: String) -> String:
	var relation: String = _household_normalize_relationship(gs, raw_relation)
	var gender: String = str(gender_text).strip_edges().to_lower()

	if gender == "male":
		match relation:
			"mother":
				return "Father"
			"daughter":
				return "Son"
			"sister":
				return "Brother"
			"wife":
				return "Husband"
			"aunt":
				return "Uncle"

	if gender == "female":
		match relation:
			"father":
				return "Mother"
			"son":
				return "Daughter"
			"brother":
				return "Sister"
			"husband":
				return "Wife"
			"uncle":
				return "Aunt"

	return raw_relation


static func _household_creator_relationship_age_range(gs: GameState,
	raw_relation: String, anchor_age: int = -1) -> Dictionary:
	_ensure_family_creation_contract_engine(gs)
	if gs != null and gs.family_creation_contract_engine != null and gs.family_creation_contract_engine.has_method("relationship_age_range"):
		return gs.family_creation_contract_engine.relationship_age_range(raw_relation, anchor_age)

	var relation: String = _household_normalize_relationship(gs, raw_relation)
	match relation:
		"mother", "father":
			if anchor_age >= 0:
				return { "min": int(clamp(anchor_age + 16, 18, 130)), "max": 130}
			return { "min": 18, "max": 130}
		"son", "daughter":
			if anchor_age >= 16:
				return { "min": 0, "max": int(clamp(anchor_age - 16, 0, 130))}
			return { "min": 0, "max": 0}
		"husband", "wife", "ex":
			return { "min": 18, "max": 130}
		"grandparent":
			return { "min": 65, "max": 130}
		_:
			return { "min": 0, "max": 130}


static func _household_creator_default_age_for_relationship(gs: GameState,
	raw_relation: String, anchor_age: int, min_age: int, max_age: int) -> int:
	var relation: String = _household_normalize_relationship(gs, raw_relation)
	match relation:
		"mother", "father":
			return int(clamp(anchor_age + 30, min_age, max_age))
		"son", "daughter":
			return int(clamp(anchor_age - 25, min_age, max_age))
		"husband", "wife", "ex", "brother", "sister", "cousin", "friend", "roommate":
			return int(clamp(anchor_age, min_age, max_age))
		"uncle", "aunt":
			return int(clamp(anchor_age + 20, min_age, max_age))
		"grandparent":
			return int(clamp(max(70, anchor_age + 55), min_age, max_age))
		_:
			return int(clamp(25, min_age, max_age))


static func _household_normalize_relationship(gs: GameState,
	raw_value: String) -> String:
	_ensure_family_creation_contract_engine(gs)
	if gs != null and gs.family_creation_contract_engine != null:
		return gs.family_creation_contract_engine.normalize_relationship(raw_value)

	var value: String = str(raw_value).strip_edges().to_lower()
	if value == "":
		return "none"
	return value


static func _apply_god_mode_royal_birth_truth_to_actor(gs: GameState,
	actor: Person, settings: Dictionary, reason: String = "god_mode_royal_birth_truth") -> void:
	if actor == null:
		return

	var social_class: String = MainSceneHelpers._god_mode_birth_normalized_social_class(settings)
	var rank_seed: String = MainSceneHelpers._god_mode_birth_royal_rank_seed(settings)
	var requested_royal: bool = social_class in ["Royal", "Noble"] or rank_seed != ""

	if social_class != "":
		actor.social_class = social_class

	if not requested_royal:
		return

	if rank_seed == "":
		rank_seed = "Royal Child" if social_class == "Royal" else "Ducal Line"

	if gs != null and gs.royalty_engine != null and gs.royalty_engine.has_method("_normalize_royal_rank_seed"):
		rank_seed = str(gs.royalty_engine.call("_normalize_royal_rank_seed", rank_seed)).strip_edges()
		if rank_seed == "Lesser Royal":
			rank_seed = "Ducal Line"

	actor.is_ruler = false
	actor.is_royal = true
	actor.deposed = false
	actor.exiled = false
	actor.palace_owned = social_class == "Royal"

	match rank_seed:
		"Heir Line":
			actor.social_class = "Royal"
			actor.succession_rank = 1
			actor.royal_title = _god_mode_birth_resolve_royal_title(gs, actor, "heir")
		"Royal Child":
			actor.social_class = "Royal"
			actor.succession_rank = max(3, int(actor.succession_rank))
			actor.royal_title = _god_mode_birth_resolve_royal_title(gs, actor, "royal_child")
		"Ducal Line":
			actor.social_class = "Noble"
			actor.succession_rank = max(8, int(actor.succession_rank))
			actor.royal_title = _god_mode_birth_resolve_royal_title(gs, actor, "ducal_royal")
		"Marcher Line":
			actor.social_class = "Noble"
			actor.succession_rank = max(9, int(actor.succession_rank))
			actor.royal_title = _god_mode_birth_resolve_royal_title(gs, actor, "marcher_royal")
		_:
			actor.social_class = "Noble"
			actor.succession_rank = max(10, int(actor.succession_rank))
			actor.royal_title = _god_mode_birth_resolve_royal_title(gs, actor, "lesser_royal")

	if gs != null and gs.royalty_engine != null:
		if gs.royalty_engine.has_method("_set_royal_rank_seed_trait"):
			gs.royalty_engine.call("_set_royal_rank_seed_trait", actor, rank_seed)
		if gs.royalty_engine.has_method("_sync_royal_job_identity"):
			gs.royalty_engine.call("_sync_royal_job_identity", actor)
		if gs.royalty_engine.has_method("_apply_royal_fame_floor"):
			gs.royalty_engine.call("_apply_royal_fame_floor", actor)

	actor.approval = clamp(max(int(actor.approval), 50), 0, 100)

	if typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["god_mode_royal_birth_truth_applied"] = true
		gs.scenario_state ["god_mode_royal_birth_truth_actor_id"] = int(actor.id)
		gs.scenario_state ["god_mode_royal_birth_truth_rank_seed"] = rank_seed
		gs.scenario_state ["god_mode_royal_birth_truth_reason"] = reason
		gs.scenario_state ["god_mode_royal_birth_truth_at_ms"] = int(Time.get_ticks_msec())


static func _god_mode_birth_resolve_royal_title(gs: GameState,
	actor: Person, rank_key: String) -> String:
	if actor == null:
		return ""

	if gs != null and gs.royalty_engine != null and gs.royalty_engine.has_method("_resolve_rank_title"):
		return str(gs.royalty_engine.call("_resolve_rank_title", actor, rank_key)).strip_edges()

	var gender_text: String = str(actor.gender).strip_edges().to_lower()

	match rank_key:
		"heir":
			return "Crown Princess" if gender_text == "female" else "Crown Prince"
		"royal_child":
			return "Princess" if gender_text == "female" else "Prince"
		"ducal_royal":
			return "Duchess" if gender_text == "female" else "Duke"
		"marcher_royal":
			return "Marchioness" if gender_text == "female" else "Marquess"
		_:
			return "Noble"


static func _god_mode_birth_actor_display_name(actor: Person, settings: Dictionary = {}) -> String:
	var first_name: String = str(settings.get("first_name", "")).strip_edges()
	var last_name: String = str(settings.get("last_name", "")).strip_edges()

	if first_name == "" and actor != null:
		first_name = str(actor.first_name).strip_edges()

	if last_name == "" and actor != null:
		last_name = str(actor.last_name).strip_edges()

	var full_name: String = ("%s %s" % [first_name, last_name]).strip_edges()
	if full_name == "" or full_name.to_lower() == "unknown":
		full_name = MainSceneHelpers._person_display_name_for_identity_switch(actor)

	if full_name == "" or full_name.to_lower() == "unknown":
		full_name = "Acrello IsBack"

	return full_name


static func _god_mode_birth_surface_lock_active(gs: GameState,
	_reason: String = "god_mode_birth_surface_lock") -> bool:
	if gs == null or gs.player == null:
		return false

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		return false

	if not bool(gs.scenario_state.get("god_mode_birth_surface_lock_active", false)):
		return false

	var locked_actor_id: int = int(gs.scenario_state.get("god_mode_birth_surface_lock_actor_id", -1))
	if locked_actor_id > 0 and locked_actor_id != int(gs.player.id):
		gs.scenario_state ["god_mode_birth_surface_lock_active"] = false
		return false

	var until_ms: int = int(gs.scenario_state.get("god_mode_birth_surface_lock_until_ms", 0))
	if until_ms > 0 and int(Time.get_ticks_msec()) > until_ms:
		gs.scenario_state ["god_mode_birth_surface_lock_active"] = false
		return false

	return true


static func _god_mode_birth_intro_cry_should_play(gs: GameState,
	snapshot: Dictionary) -> bool:
	if gs == null or gs.player == null:
		return false

	if bool(snapshot.get("suppress_birth_intro_for_existing_life", false)):
		return false

	if bool(snapshot.get("birth_intro_cry_allowed", false)):
		return true

	return int(snapshot.get("age", int(gs.player.age))) <= 0


static func _feature_overrides_match_mode(mode_text: String, overrides: Dictionary) -> bool:
	var preset:= MainSceneHelpers._feature_overrides_for_mode(mode_text)

	for key in MainSceneHelpers._feature_override_keys():
		if bool(overrides.get(key, false)) != bool(preset.get(key, false)):
			return false

	return true


static func _normalize_feature_overrides_for_reality_mode(mode_text: String, raw_overrides: Variant) -> Dictionary:
	var clean_mode: String = MainSceneHelpers._canonical_reality_mode_key(mode_text)
	var out: Dictionary = MainSceneHelpers._feature_overrides_for_mode(clean_mode)

	if typeof(raw_overrides) != TYPE_DICTIONARY:
		return out

	var raw: Dictionary = (raw_overrides as Dictionary).duplicate(true)

	for raw_key in raw.keys():
		var canonical_key: String = MainSceneHelpers._canonical_feature_override_key(raw_key)
		if canonical_key == "":
			continue

		out [canonical_key] = bool(raw.get(raw_key, out.get(canonical_key, false)))

	return out


static func _canonicalize_god_mode_reality_settings(settings: Dictionary, reason: String = "god_mode_reality_settings") -> Dictionary:
	var out: Dictionary = settings.duplicate(true)

	var clean_mode: String = MainSceneHelpers._canonical_reality_mode_key(out.get("reality_mode", "chaos"))
	var normalized_overrides: Dictionary = _normalize_feature_overrides_for_reality_mode(
		clean_mode,
		out.get("feature_overrides", {})
	)

	out ["reality_mode"] = clean_mode
	out ["feature_overrides"] = normalized_overrides.duplicate(true)
	out ["reality_mode_label"] = _friendly_reality_mode_label(clean_mode) if _feature_overrides_match_mode(clean_mode, normalized_overrides) else "Custom"
	out ["reality_mode_authority"] = "god_mode_canonical_reality_contract"
	out ["reality_mode_canonicalized_reason"] = reason
	out ["reality_mode_canonicalized_at_ms"] = int(Time.get_ticks_msec())
	out ["fantasy_alias_is_chaos"] = true

	return out


static func _display_reality_mode_label_from_settings(settings: Dictionary) -> String:
	var clean_mode: String = MainSceneHelpers._canonical_reality_mode_key(settings.get("reality_mode", "chaos"))
	var overrides: Dictionary = _normalize_feature_overrides_for_reality_mode(
		clean_mode,
		settings.get("feature_overrides", {})
	)

	if not _feature_overrides_match_mode(clean_mode, overrides):
		return "Custom"

	return _friendly_reality_mode_label(clean_mode)


static func _push_new_life_world_feed_entries(gs: GameState) -> void:
	if gs == null:
		return

	var seed_text:= "World Seed: Unknown"
	if gs.seed_engine != null:
		seed_text = "World Seed: %s" % str(gs.seed_engine.seed_value)

	var seed_entry:= gs.make_world_feed_entry(seed_text, {
		"category": "system",
		"event_name": "startup_seed",
		"source": "new_life_intro"
	})

	var existing_seed_index:= -1
	for i in range(gs.world_feed.size()):
		var entry:= gs.normalize_world_feed_entry(gs.world_feed [i])
		if str(entry.get("event_name", "")) == "startup_seed":
			existing_seed_index = i
			break

	if existing_seed_index != -1:
		gs.world_feed.remove_at(existing_seed_index)

	gs.world_feed.insert(0, seed_entry)

	if _player_is_avatar_birth(gs):
		var p: Person = gs.player
		var birth_city: String = str(p.birth_city).strip_edges()
		var birth_country: String = str(p.birth_country).strip_edges()

		if birth_city == "":
			birth_city = str(p.home_city).strip_edges()
		if birth_country == "":
			birth_country = str(p.home_country).strip_edges()
		if birth_city == "":
			birth_city = "an unknown city"
		if birth_country == "":
			birth_country = "an unknown nation"

		var avatar_text: String = "🌌The Avatar has been reincarnated in %s, %s." % [
			birth_city,
			birth_country
		]

		var existing_avatar_index:= -1
		for i in range(gs.world_feed.size()):
			var entry:= gs.normalize_world_feed_entry(gs.world_feed [i])
			if str(entry.get("event_name", "")) == "avatar_player_birth_reincarnation":
				existing_avatar_index = i
				break

		if existing_avatar_index != -1:
			gs.world_feed.remove_at(existing_avatar_index)

		var avatar_entry:= gs.make_world_feed_entry(avatar_text, {
			"npc_id": int(p.id),
			"personally_relevant": false,
			"category": "bending",
			"event_name": "avatar_player_birth_reincarnation",
			"source": "new_life_intro",
			"birth_city": birth_city,
			"birth_country": birth_country
		})

		gs.world_feed.insert(min(1, gs.world_feed.size()), avatar_entry)

	while gs.world_feed.size() > gs.WORLD_FEED_LIMIT:
		gs.world_feed.pop_back()


static func _player_is_avatar_birth(gs: GameState) -> bool:
	if gs == null or gs.player == null:
		return false

	return str(gs.player.bending_type).strip_edges().to_lower() == "avatar"


static func _is_secret_superpower_birth_identity_line(text: String) -> bool:
	var clean_text: String = MainSceneHelpers._compact_diary_text(text)
	if clean_text == "":
		return false

	var lower_text: String = clean_text.to_lower()
	return lower_text.find("what you see is not what you get") != -1 \
or lower_text.find("what i see is not what i get") != -1


static func _custom_household_member_display_job(member: Person) -> String:
	if member == null:
		return "unemployed"

	var job_name: String = str(member.job).strip_edges()
	if job_name == "":
		return "unemployed"
	return "%s %s" % [MainSceneHelpers._article_for_phrase(job_name), job_name]


static func _player_has_secret_superpower_birth_identity(gs: GameState) -> bool:
	if gs == null or gs.player == null:
		return false

	var has_power: bool = false
	if gs.power_engine != null and gs.power_engine.has_method("has_superpowers"):
		has_power = gs.power_engine.has_superpowers(gs.player)

	if not has_power:
		return false

	var config: Dictionary = {}
	if typeof(gs.custom_settings) == TYPE_DICTIONARY:
		var config_raw: Variant = gs.custom_settings.get("superpower_configurator", {})
		if typeof(config_raw) == TYPE_DICTIONARY:
			config = (config_raw as Dictionary).duplicate(true)

	var public_identity: String = str(config.get("public_identity", "")).strip_edges().to_lower()
	if public_identity == "secret":
		return true

	if gs.power_engine != null and gs.power_engine.has_method("get_person_power_state"):
		var power_state: Dictionary = gs.power_engine.get_person_power_state(gs.player)
		return not bool(power_state.get("public_power_known", false))

	return false


static func print_last_history(gs: GameState):
	var hist = gs.historical_timeline_engine.get_last_years(5)

	EraLog.truth("===== HISTORY =====")
	for y in hist.keys():
		EraLog.truth("Year:", y)
		for e in hist [y]:
			EraLog.truth(" -", e)
	EraLog.truth("===================")


static func _world_feed_section_key(gs: GameState,
	entry: Dictionary) -> String:
	var normalized: Dictionary = entry
	if gs != null:
		normalized = gs.normalize_world_feed_entry(entry)
	var category: String = str(normalized.get("category", "")).strip_edges().to_lower()
	var event_name: String = str(normalized.get("event_name", "")).strip_edges().to_lower()
	var text: String = str(normalized.get("text", "")).to_lower()

	if category in ["politics", "realm"]:
		return "politics"
	if category == "dynasty":
		return "dynasty"
	if category == "faction":
		return "factions"
	if category in ["war", "military"]:
		return "conflict"
	if category == "bending":
		return "bending"
	if category == "cosmic":
		return "cosmic"
	if category == "artifact":
		if event_name == "artifact_world_pressure" or text.findn("infinity stone") != -1 or text.findn("reality destabilizes") != -1:
			return "cosmic"
		return "artifacts"
	if category == "world":
		return "world"
	return "society"


static func _should_render_world_feed_entry_as_compact_block(gs: GameState,
	entry: Dictionary) -> bool:
	var normalized: Dictionary = entry
	if gs != null:
		normalized = gs.normalize_world_feed_entry(entry)
	var section_key: String = _world_feed_section_key(gs, normalized)
	var lines: Array = MainSceneHelpers._world_feed_trimmed_lines(str(gs.get_world_feed_text(normalized)) if gs != null else str(normalized.get("text", "")))
	if lines.size() <= 1:
		return false
	return section_key in ["politics", "society", "world"]


static func _collapse_realm_politics_compact_lines(lines: Array) -> Array:
	var rows: Array = []
	if lines.size() <= 1:
		return rows
	var seen: Dictionary = {}
	var split_payloads: Array = []
	var next_year_payloads: Array = []
	for i in range(1, lines.size()):
		var line: String = str(lines [i]).strip_edges()
		if line == "":
			continue
		var lower_line: String = line.to_lower()
		var treasury_fragment: String = MainSceneHelpers._extract_compact_politics_fragment(line, "Treasury")
		var military_fragment: String = MainSceneHelpers._extract_compact_politics_fragment(line, "Military")
		var goods_fragment: String = MainSceneHelpers._extract_compact_politics_fragment(line, "Goods")
		var happiness_fragment: String = MainSceneHelpers._extract_compact_politics_fragment(line, "Happiness")
		var approval_fragment: String = MainSceneHelpers._extract_compact_politics_fragment(line, "Approval")
		var respect_fragment: String = MainSceneHelpers._extract_compact_politics_fragment(line, "Respect")

		var split_context: bool = (
			lower_line.find("split") != -1
			or lower_line.find("allocation") != -1
			or lower_line.find("revenue") != -1
			or lower_line.find("%") != -1
		)

		if split_context:
			if treasury_fragment != "":
				var treasury_split: String = "Treasury " + MainSceneHelpers._compact_politics_payload_from_fragment(treasury_fragment, "Treasury")
				if not split_payloads.has(treasury_split):
					split_payloads.append(treasury_split)
			if military_fragment != "":
				var military_split: String = "Military " + MainSceneHelpers._compact_politics_payload_from_fragment(military_fragment, "Military")
				if not split_payloads.has(military_split):
					split_payloads.append(military_split)
			if goods_fragment != "":
				var goods_split: String = "Goods " + MainSceneHelpers._compact_politics_payload_from_fragment(goods_fragment, "Goods")
				if not split_payloads.has(goods_split):
					split_payloads.append(goods_split)
		else:
			if treasury_fragment != "":
				MainSceneHelpers._append_compact_politics_row(rows, seen, "Treasury", MainSceneHelpers._compact_politics_payload_from_fragment(treasury_fragment, "Treasury"))
			if military_fragment != "":
				MainSceneHelpers._append_compact_politics_row(rows, seen, "Military", MainSceneHelpers._compact_politics_payload_from_fragment(military_fragment, "Military"))
			if goods_fragment != "":
				MainSceneHelpers._append_compact_politics_row(rows, seen, "Goods", MainSceneHelpers._compact_politics_payload_from_fragment(goods_fragment, "Goods"))

		if happiness_fragment != "":
			var happiness_payload: String = "Happiness " + MainSceneHelpers._compact_politics_payload_from_fragment(happiness_fragment, "Happiness")
			if not next_year_payloads.has(happiness_payload):
				next_year_payloads.append(happiness_payload)
		if approval_fragment != "":
			var approval_payload: String = "Approval " + MainSceneHelpers._compact_politics_payload_from_fragment(approval_fragment, "Approval")
			if not next_year_payloads.has(approval_payload):
				next_year_payloads.append(approval_payload)
		if respect_fragment != "":
			var respect_payload: String = "Respect " + MainSceneHelpers._compact_politics_payload_from_fragment(respect_fragment, "Respect")
			if not next_year_payloads.has(respect_payload):
				next_year_payloads.append(respect_payload)

	if not split_payloads.is_empty():
		MainSceneHelpers._append_compact_politics_row(rows, seen, "State Split", " • ".join(split_payloads))
	if not next_year_payloads.is_empty():
		MainSceneHelpers._append_compact_politics_row(rows, seen, "Next Year", " • ".join(next_year_payloads))
	return rows


static func _current_life_diary_owner_id(gs: GameState) -> int:
	if gs == null or gs.player == null:
		return -1
	return int(gs.player.id)


static func _life_diary_bridge_context(gs: GameState,
	reason: String = "life_diary_bridge", extra: Dictionary = {}) -> Dictionary:
	var context: Dictionary = extra.duplicate(true)
	context ["source"] = str(context.get("source", reason))
	context ["bridge"] = "mainscene_legacy_life_diary_bridge"
	context ["ui_is_reader_only"] = true
	context ["legacy_call_intercepted"] = true
	context ["year"] = int(gs.year if gs != null else 0)
	context ["actor_id"] = _current_life_diary_owner_id(gs)
	if gs != null and gs.player != null:
		context ["age"] = int(gs.player.age)
	return context


static func _ensure_life_diary_state_store(gs: GameState) -> Dictionary:
	if gs == null:
		return {}
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	var store_raw: Variant = gs.scenario_state.get("life_diary_state_by_npc", {})
	if typeof(store_raw) != TYPE_DICTIONARY:
		gs.scenario_state ["life_diary_state_by_npc"] = {}
		store_raw = gs.scenario_state.get("life_diary_state_by_npc", {})
	return store_raw if typeof(store_raw) == TYPE_DICTIONARY else {}


static func _world_feed_entry_importance_score(gs: GameState,
	entry: Dictionary) -> float:
	var normalized: Dictionary = entry
	if gs != null:
		normalized = gs.normalize_world_feed_entry(entry)
	var section_key: String = _world_feed_section_key(gs, normalized)
	var event_name: String = str(normalized.get("event_name", "")).strip_edges().to_lower()
	var text: String = str(normalized.get("text", "")).strip_edges()
	var line_count: int = max(1, MainSceneHelpers._world_feed_trimmed_lines(text).size())
	var score: float = 10.0 + (float(line_count) * 0.35)
	if bool(normalized.get("personally_relevant", false)):
		score += 18.0
	match section_key:
		"cosmic":
			score += 32.0
		"artifacts":
			score += 24.0
		"conflict":
			score += 20.0
		"politics":
			score += 16.0
		"dynasty":
			score += 14.0
		"factions":
			score += 12.0
		"bending":
			score += 10.0
		"world":
			score += 8.0
		_:
			score += 6.0
	if event_name in [
		"artifact_birth_loadout",
		"artifact_world_pressure",
		str(ActionEventTypes.COSMIC_ENFORCER_SPAWNED).to_lower()
	]:
		score += 10.0
	return score


static func _can_stage_coup_against_target(gs: GameState,
	target: Person) -> bool:
	if gs == null or gs.player == null or target == null:
		return false
	if not gs.player.is_royal or not target.is_royal:
		return false
	if int(gs.player.id) == int(target.id):
		return false
	if int(gs.player.age) < 16:
		return false
	var my_house:= str(gs.player.dynasty_origin).strip_edges()
	var target_house:= str(target.dynasty_origin).strip_edges()
	if my_house != "" and target_house != "" and my_house != target_house:
		return false
	if target.is_ruler:
		return true
	if int(target.succession_rank) > 0 and int(gs.player.succession_rank) > 0 and int(target.succession_rank) < int(gs.player.succession_rank):
		return true
	return false


static func _collect_ancestor_generation_ids(gs: GameState,
	person: Person, generation: int) -> Array:
	var out: Array = []
	if person == null:
		return out
	if generation <= 1:
		return out

	var frontier: Array = []
	for pid in person.parents:
		frontier.append(int(pid))

	var depth: int = 1
	var seen: Dictionary = {}

	while depth < generation and frontier.size() > 0:
		var next_frontier: Array = []
		for pid in frontier:
			var facts: Dictionary = gs.get_npc_facts_by_id(int(pid))
			if facts.is_empty():
				continue
			var parent_ids_raw = facts.get("parents", [])
			if typeof(parent_ids_raw) != TYPE_ARRAY:
				continue
			for ancestor_pid in parent_ids_raw:
				next_frontier.append(int(ancestor_pid))
		frontier = next_frontier
		depth += 1

	for pid in frontier:
		var ancestor_id: int = int(pid)
		if ancestor_id <= 0:
			continue
		if seen.has(ancestor_id):
			continue
		seen [ancestor_id] = true
		out.append(ancestor_id)

	return out


static func _collect_descendant_generation_ids(gs: GameState,
	person: Person, generation: int) -> Array:
	var out: Array = []
	if person == null:
		return out
	if generation <= 0:
		return out

	var frontier: Array = []
	var root_facts: Dictionary = gs.get_npc_facts_by_id(int(person.id)) if gs != null and gs.has_method("get_npc_facts_by_id") else {}
	var root_children_raw: Variant = root_facts.get("children", person.children) if not root_facts.is_empty() else person.children
	var root_children: Array = root_children_raw if typeof(root_children_raw) == TYPE_ARRAY else []

	for cid in person.children:
		if int(cid) > 0 and int(cid) not in frontier:
			frontier.append(int(cid))

	for cid in root_children:
		if int(cid) > 0 and int(cid) not in frontier:
			frontier.append(int(cid))

	var depth: int = 1
	var seen: Dictionary = {}

	while depth < generation and frontier.size() > 0:
		var next_frontier: Array = []
		for cid in frontier:
			var facts: Dictionary = gs.get_npc_facts_by_id(int(cid))
			if facts.is_empty():
				continue
			var child_ids_raw = facts.get("children", [])
			if typeof(child_ids_raw) != TYPE_ARRAY:
				continue
			for gcid in child_ids_raw:
				if int(gcid) > 0 and int(gcid) not in next_frontier:
					next_frontier.append(int(gcid))
		frontier = next_frontier
		depth += 1

	for cid in frontier:
		var descendant_id: int = int(cid)
		if descendant_id <= 0:
			continue
		if seen.has(descendant_id):
			continue
		seen [descendant_id] = true
		out.append(descendant_id)

	return out


static func _append_relationship_browser_target_split_dead_by_id(gs: GameState,
	
	targets: Array,
	seen: Dictionary,
	npc_id: int,
	living_section: String
) -> void:
	if npc_id <= 0:
		return

	var npc: Person = gs.get_npc_by_id(npc_id)
	if npc == null:
		npc = gs.get_or_reactivate_npc_by_id(npc_id)

	if npc == null:
		var facts: Dictionary = gs.get_npc_facts_by_id(npc_id)
		if facts.is_empty():
			return
		var ghost:= Person.new()
		ghost.id = npc_id
		ghost.first_name = str(facts.get("first_name", ""))
		ghost.last_name = str(facts.get("last_name", ""))
		ghost.gender = str(facts.get("gender", ""))
		ghost.age = int(facts.get("age", 0))
		ghost.alive = bool(facts.get("alive", false))
		npc = ghost

	MainSceneHelpers._append_relationship_browser_target_split_dead(targets, seen, npc, living_section)


static func _count_npc_properties(gs: GameState,
	npc_id: int) -> int:
	if gs.property_engine == null:
		return 0
	if not gs.property_engine.properties.has(npc_id):
		return 0
	return gs.property_engine.properties [npc_id].size()


static func _count_npc_vehicles(gs: GameState,
	npc_id: int) -> int:
	if gs.vehicle_engine == null:
		return 0
	if not gs.vehicle_engine.vehicles.has(npc_id):
		return 0
	return gs.vehicle_engine.vehicles [npc_id].size()


static func _collect_death_panel_family_member_ids(gs: GameState,
	root: Person) -> Array:
	var ids: Array = []
	var seen: Dictionary = {}
	if root == null or gs == null:
		return ids
	MainSceneHelpers._add_unique_death_panel_family_id(ids, seen, int(root.id))
	var partner: Person = gs.get_valid_partner(root, true, true)
	if partner != null:
		MainSceneHelpers._add_unique_death_panel_family_id(ids, seen, int(partner.id))
	for parent_id_value in root.parents:
		MainSceneHelpers._add_unique_death_panel_family_id(ids, seen, int(parent_id_value))
	for child_id_value in root.children:
		MainSceneHelpers._add_unique_death_panel_family_id(ids, seen, int(child_id_value))
	if not root.parents.is_empty():
		for npc in gs.npcs:
			if npc == null:
				continue
			if int(npc.id) == int(root.id):
				continue
			if npc.parents == root.parents:
				MainSceneHelpers._add_unique_death_panel_family_id(ids, seen, int(npc.id))
	return ids


static func _net_worth_entry_key(prefix: String, category: String, entry: Dictionary) -> String:
	var entry_id: int = int(entry.get("id", -1))
	if entry_id > 0:
		return "%s:%d" % [prefix, entry_id]
	var asset_name: String = str(entry.get("name", entry.get("type", entry.get("size", "asset"))))
	var address: String = str(entry.get("address", ""))
	var value: int = int(round(MainSceneHelpers._net_worth_entry_value(entry)))
	return "%s:%s:%s:%s:%d" % [prefix, category, asset_name, address, value]


static func _sum_unique_flat_asset_bucket(bucket: Dictionary, owner_ids: Array, prefix: String, seen_asset_keys: Dictionary) -> float:
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
				var entry_key: String = _net_worth_entry_key(prefix, "", entry)
				if seen_asset_keys.has(entry_key):
					continue
				seen_asset_keys [entry_key] = true
				total += MainSceneHelpers._net_worth_entry_value(entry)
	return total


static func _sum_unique_inventory_value(gs: GameState,
	owner_ids: Array, seen_asset_keys: Dictionary) -> float:
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
					var item_key: String = _net_worth_entry_key("item", category, item)
					if seen_asset_keys.has(item_key):
						continue
					seen_asset_keys [item_key] = true
					total += MainSceneHelpers._net_worth_entry_value(item)
	return total


static func _calculate_personal_net_worth(gs: GameState,
	person: Person) -> float:
	if person == null or gs == null:
		return 0.0
	var owner_ids: Array = [int(person.id)]
	var seen_asset_keys: Dictionary = {}
	var total: float = max(0.0, float(person.bank_balance))
	if gs.property_engine != null:
		total += _sum_unique_flat_asset_bucket(gs.property_engine.properties, owner_ids, "property", seen_asset_keys)
	if gs.vehicle_engine != null:
		total += _sum_unique_flat_asset_bucket(gs.vehicle_engine.vehicles, owner_ids, "vehicle", seen_asset_keys)
	total += _sum_unique_inventory_value(gs, owner_ids, seen_asset_keys)
	return total


static func _calculate_family_net_worth(gs: GameState,
	root: Person) -> float:
	if root == null or gs == null:
		return 0.0
	var member_ids: Array = _collect_death_panel_family_member_ids(gs, root)
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
		total += _sum_unique_flat_asset_bucket(gs.property_engine.properties, effective_ids, "property", seen_asset_keys)
	if gs.vehicle_engine != null:
		total += _sum_unique_flat_asset_bucket(gs.vehicle_engine.vehicles, effective_ids, "vehicle", seen_asset_keys)
	total += _sum_unique_inventory_value(gs, effective_ids, seen_asset_keys)
	return total


static func _other_country_romance_initial_diary_line(gs: GameState,
	entry: Dictionary, preference: String) -> String:
	var target_text: String = _other_country_romance_target_sentence_name(entry)
	var preference_text: String = MainSceneHelpers._other_country_romance_preference_text(preference)
	var era_name: String = str(gs.era.name if gs != null and gs.era != null and "name" in gs.era else "").strip_edges()
	var lower_era: String = era_name.to_lower()

	if lower_era.find("ancient") >= 0 or lower_era.find("medieval") >= 0:
		return "I sent a letter to %s hoping to meet %s." % [target_text, preference_text]

	if lower_era.find("future") >= 0:
		return "I sent a future-era romance signal toward %s hoping to meet %s." % [target_text, preference_text]

	return "I made a public statement in %s hoping to meet %s." % [target_text, preference_text]


static func _other_country_romance_target_sentence_name(entry: Dictionary) -> String:
	var clean: String = str(entry.get("name", entry.get("entry_id", "that place"))).strip_edges()
	if clean == "":
		return "that place"

	var lower: String = clean.to_lower()
	if lower.begins_with("the "):
		return "the %s" % clean.substr(4).strip_edges()

	if MainSceneHelpers._other_country_romance_target_needs_definite_article(clean):
		return "the %s" % clean

	return clean


static func _relationship_descendant_section_from_target_facts(gs: GameState,
	target: Person) -> String:
	if gs == null or gs.player == null or target == null:
		return ""

	var observer_id: int = int(gs.player.id)
	var target_id: int = int(target.id)
	if observer_id <= 0 or target_id <= 0 or observer_id == target_id:
		return ""

	var frontier: Array = [target_id]
	var visited: Dictionary = {}

	for depth in range(1, 5):
		var next_frontier: Array = []

		for raw_id in frontier:
			var current_id: int = int(raw_id)
			if current_id <= 0:
				continue
			if visited.has(current_id):
				continue
			visited [current_id] = true

			var facts: Dictionary = gs.get_npc_facts_by_id(current_id) if gs.has_method("get_npc_facts_by_id") else {}
			if facts.is_empty():
				continue

			var parent_ids_raw: Variant = facts.get("parents", [])
			var parent_ids: Array = parent_ids_raw if typeof(parent_ids_raw) == TYPE_ARRAY else []

			for raw_parent_id in parent_ids:
				var parent_id: int = int(raw_parent_id)
				if parent_id == observer_id:
					match depth:
						1:
							return "Children"
						2:
							return "Grandchildren"
						3:
							return "Great-Grandchildren"
						_:
							return "Descendants"

				if parent_id > 0:
					next_frontier.append(parent_id)

		frontier = next_frontier

	return ""


static func _relationship_label_from_bidirectional_lineage_facts(gs: GameState,
	target: Person) -> String:
	if target == null:
		return ""

	var descendant_section: String = _relationship_descendant_section_from_target_facts(gs, target)
	if descendant_section == "":
		return ""

	match descendant_section:
		"Children":
			if str(target.gender) == "Male":
				return "Son"
			if str(target.gender) == "Female":
				return "Daughter"
			return "Child"
		"Grandchildren":
			if str(target.gender) == "Male":
				return "Grandson"
			if str(target.gender) == "Female":
				return "Granddaughter"
			return "Grandchild"
		"Great-Grandchildren":
			if str(target.gender) == "Male":
				return "Great-Grandson"
			if str(target.gender) == "Female":
				return "Great-Granddaughter"
			return "Great-Grandchild"
		_:
			return "Descendant"


static func _primary_royal_court_entry_for_npc(gs: GameState,
	npc: Person) -> Dictionary:
	if gs == null or npc == null:
		return {}
	var membership_index_raw: Variant = gs.scenario_state.get("royal_court_membership_index", {})
	var membership_index: Dictionary = membership_index_raw if typeof(membership_index_raw) == TYPE_DICTIONARY else {}
	var npc_entries_raw: Variant = membership_index.get(str(int(npc.id)), {})
	var npc_entries: Dictionary = npc_entries_raw if typeof(npc_entries_raw) == TYPE_DICTIONARY else {}

	var best_entry: Dictionary = {}
	var best_priority: int = 999

	for raw_faction_id in npc_entries.keys():
		var entry_raw: Variant = npc_entries.get(raw_faction_id, {})
		var entry: Dictionary = entry_raw if typeof(entry_raw) == TYPE_DICTIONARY else {}
		if not bool(entry.get("active", true)):
			continue
		var priority: int = MainSceneHelpers._royal_court_role_priority(str(entry.get("role", "courtier")))
		if best_entry.is_empty() or priority < best_priority:
			best_entry = entry.duplicate(true)
			best_entry ["faction_id"] = str(raw_faction_id)
			best_priority = priority

	return best_entry


static func _relationship_profile_target_is_grocery_locked_non_royal(target: Person) -> bool:
	var locked_job: String = MainSceneHelpers._relationship_profile_grocery_locked_job(target)
	if locked_job == "":
		return false

	var lower_job: String = locked_job.to_lower()
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
			return false

	return true


static func _relationship_profile_fallback_job_for(gs: GameState,
	target: Person) -> String:
	if target == null:
		return "Unemployed"

	if int(target.age) < 16:
		return "Student"

	if int(target.age) < 18:
		return "Part-Time Worker"

	if gs != null and gs.career_engine != null and gs.career_engine.has_method("pick_job_for"):
		var picked_job: String = str(gs.career_engine.pick_job_for(target)).strip_edges()
		if picked_job != "" and not MainSceneHelpers._relationship_profile_job_is_invalid(picked_job) and not MainSceneHelpers._relationship_profile_job_looks_royal(picked_job):
			return picked_job

	var fallback_jobs: Array = [
		"Teacher",
		"Nurse",
		"Mechanic",
		"Cashier",
		"Office Worker",
		"Delivery Driver",
		"Engineer",
		"Security Guard",
		"Retail Manager",
		"Construction Worker",
		"Accountant",
		"Chef"
	]

	var seed_value: int = abs(int(hash("%d|profile_fallback_job|%d" % [int(target.id), int(gs.year) if gs != null else 0])))
	return str(fallback_jobs [seed_value % fallback_jobs.size()])


static func _relationship_profile_effective_job_for(gs: GameState,
	target: Person, grocery_locked_non_royal: bool) -> String:
	if target == null:
		return "Unemployed"

	var federal_job: String = _relationship_profile_federal_republic_job_for(target)
	if federal_job != "":
		target.job = federal_job
		target.is_royal = false
		target.royal_title = ""
		target.succession_rank = 99
		return federal_job

	var locked_grocery_job: String = MainSceneHelpers._relationship_profile_grocery_locked_job(target)
	var effective_job: String = str(target.job).strip_edges()

	if locked_grocery_job != "":
		effective_job = locked_grocery_job
	elif gs != null and gs.royalty_engine != null and gs.royalty_engine.has_method("_formal_royal_job_for") and not grocery_locked_non_royal:
		var royal_job: String = str(gs.royalty_engine._formal_royal_job_for(target)).strip_edges()
		if royal_job != "" and not MainSceneHelpers._relationship_profile_target_has_federal_republic_office(target):
			effective_job = royal_job

	if MainSceneHelpers._relationship_profile_job_is_invalid(effective_job):
		effective_job = _relationship_profile_fallback_job_for(gs, target)
		target.job = effective_job

	if grocery_locked_non_royal and MainSceneHelpers._relationship_profile_job_looks_royal(effective_job):
		effective_job = _relationship_profile_fallback_job_for(gs, target)
		target.job = effective_job

	if MainSceneHelpers._relationship_profile_target_has_federal_republic_office(target) and MainSceneHelpers._relationship_profile_job_looks_royal(effective_job):
		effective_job = _relationship_profile_federal_republic_job_for(target)
		target.job = effective_job
		target.is_royal = false
		target.royal_title = ""
		target.succession_rank = 99

	if effective_job == "":
		effective_job = "Unemployed"

	return effective_job


static func _relationship_profile_federal_republic_job_for(target: Person) -> String:
	if target == null:
		return ""

	if not MainSceneHelpers._relationship_profile_target_has_federal_republic_office(target):
		return ""

	var office_contract: Dictionary = {}
	var raw_contract: Variant = target.get("civic_office_contract")
	if typeof(raw_contract) == TYPE_DICTIONARY:
		office_contract = (raw_contract as Dictionary).duplicate(true)

	var office_text: String = str(office_contract.get("office", "")).strip_edges()
	var full_title: String = str(office_contract.get("office_full_title", "")).strip_edges()
	var civic_title: String = str(target.get("civic_title")).strip_edges()
	var job_text: String = str(target.job).strip_edges()
	var job_key: String = job_text.to_lower()

	if office_text == "President" or civic_title == "President" or job_key == "president" or job_key == "president of the united states":
		return "President of the United States"

	if office_text in ["First Lady", "First Gentleman"]:
		return office_text

	if civic_title in ["First Lady", "First Gentleman", "Vice President"]:
		return civic_title

	if full_title != "":
		if full_title.begins_with("The "):
			full_title = full_title.substr(4).strip_edges()
		if full_title == "President of the United States":
			return "President of the United States"
		return full_title

	if job_text != "":
		return job_text

	return ""


static func _relationship_profile_effective_fame_tier_for(gs: GameState,
	target: Person) -> String:
	if target == null:
		return "None"

	var civic_fame_floor: int = _relationship_profile_civic_fame_floor(gs, target)
	var fame_value: int = max(int(target.fame), civic_fame_floor)

	if fame_value > int(target.fame):
		target.fame = fame_value

	var resolved_tier: String = MainSceneHelpers._relationship_profile_fame_tier_for_value(fame_value)

	if str(target.fame_tier).strip_edges() == "" or str(target.fame_tier).strip_edges() == "None" or MainSceneHelpers._relationship_profile_fame_tier_rank(resolved_tier) > MainSceneHelpers._relationship_profile_fame_tier_rank(str(target.fame_tier)):
		target.fame_tier = resolved_tier

	return str(target.fame_tier)


static func _relationship_profile_civic_fame_floor(gs: GameState,
	target: Person) -> int:
	if target == null:
		return 0

	var federal_job: String = _relationship_profile_federal_republic_job_for(target).strip_edges().to_lower()
	if federal_job == "president of the united states":
		return 85

	if federal_job in ["first lady", "first gentleman"]:
		return 55

	if _relationship_profile_target_is_presidential_child(gs, target):
		return 35

	return 0


static func _relationship_profile_target_is_presidential_child(gs: GameState,
	target: Person) -> bool:
	if target == null or gs == null or typeof(gs.scenario_state) != TYPE_DICTIONARY:
		return false

	var president_id: int = int(gs.scenario_state.get("presidential_parent_contract_president_id", -1))
	var first_partner_id: int = int(gs.scenario_state.get("presidential_parent_contract_first_partner_id", -1))
	var target_id: int = int(target.id)

	if president_id <= 0 and first_partner_id <= 0:
		return false

	if target.parents.has(president_id) or target.parents.has(first_partner_id):
		return true

	var president: Person = gs.get_or_reactivate_npc_by_id(president_id) if president_id > 0 else null
	if president != null and president.children.has(target_id):
		return true

	var first_partner: Person = gs.get_or_reactivate_npc_by_id(first_partner_id) if first_partner_id > 0 else null
	if first_partner != null and first_partner.children.has(target_id):
		return true

	return false


static func _relationship_profile_income_floor_for(target: Person, effective_job: String, effective_social_class: String) -> int:
	if target == null:
		return 0

	if int(target.age) < 16:
		return 0

	var lower_job: String = str(effective_job).strip_edges().to_lower()
	var base_income: float = 32000.0

	if lower_job == "student":
		base_income = 0.0
	elif lower_job.find("part-time") >= 0:
		base_income = 14500.0
	elif lower_job.find("teacher") >= 0:
		base_income = 52000.0
	elif lower_job.find("nurse") >= 0:
		base_income = 76000.0
	elif lower_job.find("soldier") >= 0:
		base_income = 42000.0
	elif lower_job.find("cashier") >= 0:
		base_income = 28500.0
	elif lower_job.find("mechanic") >= 0:
		base_income = 47000.0
	elif lower_job.find("chef") >= 0:
		base_income = 44000.0
	elif lower_job.find("security") >= 0:
		base_income = 34000.0
	elif lower_job.find("streamer") >= 0:
		base_income = 41000.0
	elif lower_job.find("office") >= 0:
		base_income = 43000.0
	elif lower_job.find("artist") >= 0:
		base_income = 39000.0
	elif lower_job.find("delivery") >= 0:
		base_income = 36000.0
	elif lower_job.find("engineer") >= 0 or lower_job.find("software") >= 0:
		base_income = 92000.0
	elif lower_job.find("trainer") >= 0:
		base_income = 48000.0
	elif lower_job.find("entrepreneur") >= 0:
		base_income = 68000.0
	elif lower_job.find("manager") >= 0:
		base_income = 56000.0
	elif lower_job.find("construction") >= 0:
		base_income = 49000.0
	elif lower_job.find("accountant") >= 0:
		base_income = 64000.0
	elif MainSceneHelpers._relationship_profile_job_looks_royal(lower_job):
		base_income = 125000.0

	var class_text: String = str(effective_social_class).strip_edges().to_lower()
	if class_text.find("royal") >= 0 or class_text.find("noble") >= 0 or class_text.find("elite") >= 0:
		base_income *= 1.85
	elif class_text.find("upper") >= 0:
		base_income *= 1.55
	elif class_text.find("middle") >= 0:
		base_income *= 1.12
	elif class_text.find("poor") >= 0 or class_text.find("lower") >= 0:
		base_income *= 0.72

	var seed_value: int = abs(int(hash("%d|%s|income_projection" % [int(target.id), effective_job])))
	var variance: float = 0.88 + (float(seed_value % 31) / 100.0)

	return int(round(base_income * variance))


static func _relationship_profile_effective_income(target: Person, effective_job: String, effective_social_class: String) -> int:
	if target == null:
		return 0

	var actual_income: int = int(round(float(target.income)))
	if actual_income > 0:
		return actual_income

	var seeded_income: int = _relationship_profile_income_floor_for(target, effective_job, effective_social_class)
	if seeded_income > 0:
		target.income = seeded_income
		if float(target.bank_balance) <= 0.0:
			target.bank_balance = int(round(float(seeded_income) * 0.22))

	return seeded_income


static func _relationship_profile_display_home(gs: GameState,
	target: Person) -> Dictionary:
	var out: Dictionary = {
		"city": "",
		"country": ""
	}

	if target == null:
		return out

	var city: String = str(target.home_city).strip_edges()
	var country: String = str(target.home_country).strip_edges()

	if _relationship_profile_target_should_share_player_home(gs, target):
		var player_home: Dictionary = _relationship_profile_world_anchor_home(gs)
		var player_city: String = str(player_home.get("city", "")).strip_edges()
		var player_country: String = str(player_home.get("country", "")).strip_edges()
		if not MainSceneHelpers._relationship_profile_home_is_placeholder(player_city, player_country):
			city = player_city
			country = player_country

	if not MainSceneHelpers._relationship_profile_home_is_placeholder(city, country):
		out ["city"] = city
		out ["country"] = country
		return out

	var anchor_home: Dictionary = _relationship_profile_world_anchor_home(gs)
	var anchor_city: String = str(anchor_home.get("city", "")).strip_edges()
	var anchor_country: String = str(anchor_home.get("country", "")).strip_edges()

	if not MainSceneHelpers._relationship_profile_home_is_placeholder(anchor_city, anchor_country):
		city = anchor_city
		country = anchor_country

	if MainSceneHelpers._relationship_profile_home_is_placeholder(city, country) and gs != null and gs.era_engine != null and gs.era_engine.has_method("get_birth_locations"):
		var locations: Array = gs.era_engine.get_birth_locations()
		for raw_place in locations:
			if typeof(raw_place) != TYPE_DICTIONARY:
				continue
			var place: Dictionary = raw_place as Dictionary
			var place_city: String = str(place.get("city", "")).strip_edges()
			var place_country: String = str(place.get("country", "")).strip_edges()
			if not MainSceneHelpers._relationship_profile_home_is_placeholder(place_city, place_country):
				city = place_city
				country = place_country
				break

	if MainSceneHelpers._relationship_profile_home_is_placeholder(city, country):
		city = "Chicago"
		country = "United States"

	target.home_city = city
	target.home_country = country

	if str(target.birth_city).strip_edges() == "" or MainSceneHelpers._relationship_profile_home_is_placeholder(str(target.birth_city), str(target.birth_country)):
		target.birth_city = city
	if str(target.birth_country).strip_edges() == "" or MainSceneHelpers._relationship_profile_home_is_placeholder(str(target.birth_city), str(target.birth_country)):
		target.birth_country = country

	out ["city"] = city
	out ["country"] = country
	return out


static func _relationship_profile_world_anchor_home(gs: GameState) -> Dictionary:
	var candidates: Array = []

	if gs != null and typeof(gs.custom_settings) == TYPE_DICTIONARY:
		candidates.append({
			"city": str(gs.custom_settings.get("city", gs.custom_settings.get("birth_city", gs.custom_settings.get("home_city", "")))),
			"country": str(gs.custom_settings.get("country", gs.custom_settings.get("birth_country", gs.custom_settings.get("home_country", ""))))
		})

	if gs != null and gs.player != null:
		candidates.append({
			"city": str(gs.player.home_city),
			"country": str(gs.player.home_country)
		})
		candidates.append({
			"city": str(gs.player.birth_city),
			"country": str(gs.player.birth_country)
		})

	if gs != null and gs.era_engine != null and gs.era_engine.has_method("get_birth_locations"):
		for raw_place in gs.era_engine.get_birth_locations():
			if typeof(raw_place) != TYPE_DICTIONARY:
				continue
			var place: Dictionary = raw_place as Dictionary
			candidates.append({
				"city": str(place.get("city", "")),
				"country": str(place.get("country", ""))
			})

	for raw_candidate in candidates:
		if typeof(raw_candidate) != TYPE_DICTIONARY:
			continue
		var candidate: Dictionary = raw_candidate as Dictionary
		var city: String = str(candidate.get("city", "")).strip_edges()
		var country: String = str(candidate.get("country", "")).strip_edges()
		if not MainSceneHelpers._relationship_profile_home_is_placeholder(city, country):
			return {
				"city": city,
				"country": country
			}

	return {
		"city": "Chicago",
		"country": "United States"
	}


static func _relationship_profile_target_should_share_player_home(gs: GameState,
	target: Person) -> bool:
	if gs == null or gs.player == null or target == null:
		return false
	if int(target.id) == int(gs.player.id):
		return true

	var target_id: int = int(target.id)
	var player: Person = gs.player

	if int(player.age) < 18 and target_id in player.parents:
		return true
	if int(target.age) < 18 and target_id in player.children:
		return true
	if player.partner != null and int(player.partner.id) == target_id:
		return true

	if typeof(gs.scenario_state) == TYPE_DICTIONARY:
		var member_index: Dictionary = gs.scenario_state.get("custom_household_member_index", {})
		if typeof(member_index) == TYPE_DICTIONARY:
			var player_found: bool = false
			var target_found: bool = false
			for raw_key in member_index.keys():
				var member_id: int = int(member_index.get(raw_key, -1))
				if member_id == int(player.id):
					player_found = true
				if member_id == target_id:
					target_found = true
			if player_found and target_found:
				return true

	return false


static func _relationship_profile_body_contract_from_sources(target: Person, body_truth: Dictionary, direct_key: String, body_key: String, summary_key: String) -> Dictionary:
	var out: Dictionary = {}
	var display_key: String = "display_name" if direct_key == "body_type_contract" else "display"

	var raw_direct: Variant = body_truth.get(direct_key, {})
	if typeof(raw_direct) == TYPE_DICTIONARY:
		out = (raw_direct as Dictionary).duplicate(true)

	if out.is_empty() and target != null:
		var raw_target_direct: Variant = target.get(direct_key)
		if typeof(raw_target_direct) == TYPE_DICTIONARY:
			out = (raw_target_direct as Dictionary).duplicate(true)

	if out.is_empty():
		var raw_body: Variant = body_truth.get("body_contract", {})
		if typeof(raw_body) == TYPE_DICTIONARY:
			var body_contract: Dictionary = raw_body as Dictionary
			var raw_nested: Variant = body_contract.get(body_key, {})
			if typeof(raw_nested) == TYPE_DICTIONARY:
				out = (raw_nested as Dictionary).duplicate(true)

			if out.is_empty():
				var summary: Dictionary = MainSceneHelpers._safe_dictionary(body_contract.get("summary", {}))
				var summary_display: String = str(summary.get(summary_key, "")).strip_edges()
				if summary_display != "":
					out [display_key] = summary_display

	if out.is_empty() and target != null and typeof(target.body_contract) == TYPE_DICTIONARY:
		var target_body_contract: Dictionary = target.body_contract
		var raw_target_nested: Variant = target_body_contract.get(body_key, {})
		if typeof(raw_target_nested) == TYPE_DICTIONARY:
			out = (raw_target_nested as Dictionary).duplicate(true)

		if out.is_empty():
			var target_summary: Dictionary = MainSceneHelpers._safe_dictionary(target_body_contract.get("summary", {}))
			var target_summary_display: String = str(target_summary.get(summary_key, "")).strip_edges()
			if target_summary_display != "":
				out [display_key] = target_summary_display

	return out


static func _relationship_profile_local_display_height_inches(target: Person) -> float:
	if target == null:
		return 67.0

	var age_value: int = max(0, int(target.age))
	var gender_text: String = str(target.gender).strip_edges().to_lower()
	var base_adult_height: float = 69.0

	if gender_text in ["female", "woman", "girl", "f"]:
		base_adult_height = 64.0

	var identity_offset: float = float((abs(int(target.id)) % 9) - 4) * 0.65
	var adult_height: float = clamp(base_adult_height + identity_offset, 48.0, 86.0)
	var growth_factor: float = MainSceneHelpers._relationship_profile_local_height_growth_factor_for_age(age_value)

	return clamp(adult_height * growth_factor, 16.0, 90.0)


static func _relationship_profile_local_display_weight_lbs(target: Person, height_in: float, body_type: String) -> float:
	if target == null:
		return 150.0

	var age_value: int = max(0, int(target.age))
	var height_m: float = max(0.3, height_in * 0.0254)
	var adult_weight: float = 22.0 * height_m * height_m * 2.20462
	var growth_factor: float = MainSceneHelpers._relationship_profile_local_height_growth_factor_for_age(age_value)
	var weight_growth_factor: float = clamp(growth_factor * growth_factor, 0.1, 1.06)
	var frame_multiplier: float = 1.0

	match str(body_type).strip_edges().to_lower():
		"ectomorph":
			frame_multiplier = 0.92
		"endomorph":
			frame_multiplier = 1.1
		_:
			frame_multiplier = 1.02

	var identity_offset: float = float((abs(int(target.id)) % 11) - 5) * 1.2
	return clamp((adult_weight * weight_growth_factor * frame_multiplier) + identity_offset, 5.0, 850.0)


static func _relationship_profile_page_cache_key(gs: GameState,
	
	target: Person
) -> String:
	if target == null:
		return ""

	var viewer_id: int = -1

	if gs != null and gs.player != null:
		viewer_id = int(gs.player.id)

	return "%d:%d" % [
		viewer_id,
		int(target.id)
	]


static func _relationship_profile_page_signature(gs: GameState,
	
	target: Person
) -> String:
	if target == null:
		return ""

	var viewer_id: int = -1
	var viewer_age: int = -1
	var viewer_bending_type: String = "none"
	var current_year: int = 0

	if gs != null:
		current_year = int(gs.year)

		if gs.player != null:
			viewer_id = int(gs.player.id)
			viewer_age = int(gs.player.age)
			viewer_bending_type = str(
				gs.player.bending_type
			)

	var signature_source: String = (
		"%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%s|%s|%s"
		% [
			viewer_id,
			int(target.id),
			current_year,
			viewer_age,
			int(target.age),
			int(round(float(target.health))),
			int(round(float(target.mental_health))),
			int(round(float(target.smarts))),
			int(round(float(target.looks))),
			int(target.bank_balance),
			_relationship_profile_popup_fast_bond_score(gs, 
				target
			),
			str(target.alive),
			viewer_bending_type,
			str(target.bending_type)
		]
	)

	return str(
		signature_source.hash()
	)


static func _playable_life_viewer_packet_tail_apply_forbidden(packet: Dictionary, reason: String = "") -> bool:
	if typeof(packet) != TYPE_DICTIONARY:
		return true

	var clean_reason: String = str(reason).strip_edges().to_lower()
	if clean_reason.find("relationship_profile_switch") != -1:
		return true
	if clean_reason.find("relationship_switch") != -1:
		return true

	if bool(packet.get("tail_apply_forbidden", false)):
		return true
	if bool(packet.get("relationship_profile_switch_tail_apply_forbidden", false)):
		return true
	if bool(packet.get("switch_packet_fully_consumed_before_modal_close", false)):
		return true

	var render_policy: Dictionary = MainSceneHelpers._safe_dictionary(packet.get("render_policy", {}))
	if bool(render_policy.get("tail_apply_forbidden", false)):
		return true
	if bool(render_policy.get("relationship_profile_switch_tail_apply_forbidden", false)):
		return true
	if bool(render_policy.get("switch_packet_fully_consumed_before_modal_close", false)):
		return true

	var surface: Dictionary = MainSceneHelpers._safe_dictionary(packet.get("surface_contract", {}))
	if bool(surface.get("tail_apply_forbidden", false)):
		return true
	if bool(surface.get("relationship_profile_switch_tail_apply_forbidden", false)):
		return true
	if bool(surface.get("switch_packet_fully_consumed_before_modal_close", false)):
		return true

	return false


static func _relationship_profile_zero_frame_shell_store(gs: GameState) -> Dictionary:
	if gs == null:
		return {}

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var store_raw: Variant = gs.scenario_state.get("relationship_profile_zero_frame_life_shell_by_actor", {})
	var store: Dictionary = store_raw if typeof(store_raw) == TYPE_DICTIONARY else {}

	gs.scenario_state ["relationship_profile_zero_frame_life_shell_by_actor"] = store
	return store


static func _relationship_profile_popup_fast_bond_score(gs: GameState,
	target: Person) -> int:
	if gs == null or gs.player == null or target == null:
		return 0

	if typeof(gs.player.affection) == TYPE_DICTIONARY:
		return clamp(int(gs.player.affection.get(target.id, 0)), 0, 100)

	return 0


static func _relationship_profile_narrative_memory_lines(gs: GameState,
	target: Person) -> Array:
	var lines: Array = []
	if gs == null or gs.player == null or target == null:
		return lines
	if gs.narrative_engine == null:
		return lines

	var personal_rows: Array = []
	if gs.narrative_engine.has_method("get_relationship_memory_summary"):
		personal_rows = gs.narrative_engine.get_relationship_memory_summary(gs.player, target, 4)

	var conflict_rows: Array = []
	if gs.narrative_engine.has_method("build_conflicting_narrative_rows"):
		conflict_rows = gs.narrative_engine.build_conflicting_narrative_rows(gs.player, target, 4)

	if personal_rows.is_empty() and conflict_rows.is_empty():
		return lines

	lines.append("")
	lines.append("Shared Memory")

	for raw_memory in personal_rows:
		if typeof(raw_memory) != TYPE_DICTIONARY:
			continue
		var memory: Dictionary = raw_memory
		var tone: String = str(memory.get("tone", "neutral")).capitalize()
		var text: String = str(memory.get("text", "")).strip_edges()
		if text == "":
			continue
		lines.append("• %s: %s" % [tone, text])

	if not conflict_rows.is_empty():
		lines.append("")
		lines.append("Conflicting Narratives")

	for raw_conflict in conflict_rows:
		if typeof(raw_conflict) != TYPE_DICTIONARY:
			continue
		var conflict: Dictionary = raw_conflict
		var player_text: String = ""
		var target_text: String = ""

		if int(conflict.get("person_a_id", -1)) == int(gs.player.id):
			player_text = str(conflict.get("person_a_text", "")).strip_edges()
			target_text = str(conflict.get("person_b_text", "")).strip_edges()
		else:
			player_text = str(conflict.get("person_b_text", "")).strip_edges()
			target_text = str(conflict.get("person_a_text", "")).strip_edges()

		if player_text != "":
			lines.append("• You remember: %s" % player_text)
		if target_text != "":
			lines.append("• They remember: %s" % target_text)

	return lines


static func _ensure_live_person_editor_engine(gs: GameState) -> void:
	if gs == null:
		return

	if gs.live_person_editor_engine == null:
		gs.live_person_editor_engine = LivePersonEditorEngine.new(gs)


static func _relationship_profile_fling_label(gs: GameState,
	target: Person) -> String:
	if target == null or gs == null:
		return ""

	if typeof(gs.scenario_state) == TYPE_DICTIONARY:
		var foreign_ids: Array = gs.scenario_state.get("foreign_romance_fling_ids", []) if typeof(gs.scenario_state.get("foreign_romance_fling_ids", [])) == TYPE_ARRAY else []
		if int(target.id) in foreign_ids:
			return "Writing Fling"

		var restaurant_ids: Array = gs.scenario_state.get("restaurant_fling_ids", []) if typeof(gs.scenario_state.get("restaurant_fling_ids", [])) == TYPE_ARRAY else []
		if int(target.id) in restaurant_ids:
			return "Fling"

	return ""


static func _relationship_profile_people_share_any_parent(a: Person, b: Person) -> bool:
	if a == null or b == null:
		return false

	var a_parent_ids: Array = MainSceneHelpers._relationship_safe_person_id_array(a, "parents")
	var b_parent_ids: Array = MainSceneHelpers._relationship_safe_person_id_array(b, "parents")
	return MainSceneHelpers._relationship_people_share_any_parent_id(a_parent_ids, b_parent_ids)


static func _can_avatar_alter_bending(gs: GameState) -> bool:
	var p: Person = gs.player
	if p == null:
		return false
	if str(p.bending_type) != "avatar":
		return false
	return p.age >= 12


static func _is_family_like_target(gs: GameState,
	target: Person) -> bool:
	if target == null or gs.player == null:
		return false

	var p:= gs.player

	if target.id in p.parents:
		return true
	if target.id in p.children:
		return true
	if p.partner != null and p.partner.id == target.id:
		return true
	if target.id in p.ex_partners:
		return true

	for gid in _collect_ancestor_generation_ids(gs, p, 2):
		if int(gid) == target.id:
			return true

	for ggid in _collect_ancestor_generation_ids(gs, p, 3):
		if int(ggid) == target.id:
			return true

	if p.parents.size() > 0 and target.parents == p.parents and target.id != p.id:
		return true

	return false


static func _is_classmate_target(gs: GameState,
	target: Person) -> bool:
	if target == null or gs == null or gs.player == null or gs.school_engine == null:
		return false

	var p:= gs.player
	gs.school_engine.sync_person_school_fields(p)

	for c in gs.school_engine.get_classmates(p):
		if c != null and c.id == target.id:
			return true

	return false


static func _unfriend_target(gs: GameState,
	target: Person) -> Dictionary:
	if target == null or gs.player == null:
		return { "success": false, "text": "Nobody is selected."}

	gs.player.friends.erase(target.id)
	target.friends.erase(gs.player.id)

	return {
		"success": true,
		"text": "I unfriended %s %s." % [target.first_name, target.last_name]
	}


static func _relationship_profile_target_is_foreign_writing_fling(gs: GameState,
	target: Person) -> bool:
	if target == null or gs == null or gs.player == null:
		return false

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		return false

	var foreign_ids: Array = gs.scenario_state.get("foreign_romance_fling_ids", []) if typeof(gs.scenario_state.get("foreign_romance_fling_ids", [])) == TYPE_ARRAY else []
	if not int(target.id) in foreign_ids:
		return false

	return _relationship_profile_target_is_in_different_country(gs, target)


static func _relationship_profile_target_is_in_different_country(gs: GameState,
	target: Person) -> bool:
	if target == null or gs == null or gs.player == null:
		return false

	var player_country: String = str(gs.player.home_country).strip_edges()
	if player_country == "":
		player_country = str(gs.player.birth_country).strip_edges()

	var target_country: String = str(target.home_country).strip_edges()
	if target_country == "":
		target_country = str(target.birth_country).strip_edges()

	if player_country == "" or target_country == "":
		return false

	return player_country.to_lower() != target_country.to_lower()


static func _is_coworker_target(gs: GameState,
	target: Person) -> bool:
	if target == null or gs == null or gs.player == null or gs.workplace_engine == null:
		return false
	for coworker in gs.workplace_engine.get_coworkers(gs.player):
		if coworker != null and int(coworker.id) == int(target.id):
			return true
	return false


static func _resolve_coworker_profile_action(gs: GameState,
	target: Person, action_id: String) -> Dictionary:
	if target == null or gs == null or gs.player == null:
		return { "success": false, "text": "No coworker is selected."}
	var player:= gs.player
	var relation_score: int = 50
	if gs.relationship_engine != null:
		relation_score = int(gs.relationship_engine.update_relationship(player, target))
	match action_id:
		"coworker_talk_shop":
			if gs.relationship_engine != null:
				gs.relationship_engine.adjust_relationship(player, target, 4)
			player.job_performance = clamp(int(player.job_performance) + 2, 0, 100)
			player.satisfaction = clamp(int(player.satisfaction) + 1, 0, 100)
			return {
				"success": true,
				"text": "You talked shop with %s %s. Work felt a little smoother." % [target.first_name, target.last_name]
			}
		"coworker_network":
			if gs.relationship_engine != null:
				gs.relationship_engine.adjust_relationship(player, target, 3)
			player.satisfaction = clamp(int(player.satisfaction) + 2, 0, 100)
			player.job_performance = clamp(int(player.job_performance) + 1, 0, 100)
			return {
				"success": true,
				"text": "You strengthened your workplace connection with %s %s." % [target.first_name, target.last_name]
			}
		"coworker_ask_referral":
			var success_chance: int = clamp(relation_score + int(player.job_performance / 2.0), 20, 95)
			var success: bool = (randi() % 100) < success_chance
			if success:
				if gs.relationship_engine != null:
					gs.relationship_engine.adjust_relationship(player, target, 5)
				player.job_performance = clamp(int(player.job_performance) + 4, 0, 100)
				player.satisfaction = clamp(int(player.satisfaction) + 3, 0, 100)
				return {
					"success": true,
					"text": "%s %s agreed to put in a good word for you." % [target.first_name, target.last_name]
				}
			if gs.relationship_engine != null:
				gs.relationship_engine.adjust_relationship(player, target, -2)
			player.work_stress = clamp(int(player.work_stress) + 2, 0, 100)
			return {
				"success": false,
				"text": "%s %s was not ready to refer you yet." % [target.first_name, target.last_name]
			}
		"coworker_set_boundary":
			player.work_stress = clamp(int(player.work_stress) - 8, 0, 100)
			player.mental_health = clamp(int(player.mental_health) + 3, 0, 100)
			if relation_score >= 55:
				if gs.relationship_engine != null:
					gs.relationship_engine.adjust_relationship(player, target, 1)
				return {
					"success": true,
					"text": "You set a clear boundary with %s %s, and they respected it." % [target.first_name, target.last_name]
				}
			if gs.relationship_engine != null:
				gs.relationship_engine.adjust_relationship(player, target, -1)
			return {
				"success": true,
				"text": "You set a clear boundary with %s %s. It was a little awkward, but clearer now." % [target.first_name, target.last_name]
			}
	return { "success": false, "text": "Unknown coworker action."}


static func _relationship_popup_default_element_for_player(gs: GameState) -> String:
	var p: Person = gs.player
	if p == null:
		return "fire"

	if str(p.bending_type) != "" and str(p.bending_type) != "none" and str(p.bending_type) != "avatar":
		return str(p.bending_type)

	var best_element:= "fire"
	var best_mastery:= -1

	for element in ["air", "water", "earth", "fire"]:
		var mastery:= int(p.bending_mastery.get(element, 0))
		if mastery > best_mastery:
			best_mastery = mastery
			best_element = element

	return best_element


static func _locked_zero_frame_switch_surface(gs: GameState) -> Dictionary:
	if gs == null or typeof(gs.scenario_state) != TYPE_DICTIONARY:
		return {}

	var surface: Dictionary = MainSceneHelpers._safe_dictionary(gs.scenario_state.get("zero_frame_consciousness_switch_surface", {}))
	if surface.is_empty():
		return {}

	if gs.player != null:
		var surface_actor_id: int = int(surface.get("actor_id", -1))
		if surface_actor_id > 0 and surface_actor_id != int(gs.player.id):
			return {}

	return surface.duplicate(true)


static func _institution_hub_sections_for(gs: GameState,
	kind: String) -> Array:
	match kind:
		"career":
			return [
				{ "key": "overview", "label": "Overview"},
				{ "key": "actions", "label": "Actions"},
				{ "key": "jobs", "label": "Jobs"},
				{ "key": "workplace", "label": "Workplace"}
			]
		"school":
			if not _school_hub_has_active_contract_for_player(gs):
				return []
			return [
				{ "key": "overview", "label": "Overview"},
				{ "key": "classes", "label": "Classes"},
				{ "key": "meal", "label": _school_hub_meal_tab_label(gs)},
				{ "key": "teachers", "label": "Teachers"},
				{ "key": "social", "label": "Social"},
				{ "key": "actions", "label": "Actions"}
			]
		"relationships":
			return [
				{ "key": "family", "label": "Family"},
				{ "key": "ancestors", "label": "Ancestors"},
				{ "key": "household", "label": "MY HOUSEHOLD"},
				{ "key": "partner", "label": "Partner"},
				{ "key": "pets", "label": "PETS"},
				{ "key": "descendants", "label": "Descendants"},
				{ "key": "dead", "label": "Dead"},
				{ "key": "social", "label": "Social"},
				{ "key": "exes", "label": "Exes"}
			]
		_:
			return [
				{ "key": "overview", "label": "Overview"}
			]


static func _relationship_hub_add_climate_relationship_id(gs: GameState,
	ids: Array, seen: Dictionary, npc_id: int) -> void:
	var clean_id: int = int(npc_id)
	if clean_id <= 0:
		return
	if gs != null and gs.player != null and clean_id == int(gs.player.id):
		return
	if seen.has(clean_id):
		return

	seen [clean_id] = true
	ids.append(clean_id)


static func _institution_hub_section_is_allowed(gs: GameState,
	kind: String, section: String) -> bool:
	var clean_section: String = str(section).strip_edges()
	if clean_section == "":
		return false

	var defs: Array = _institution_hub_sections_for(gs, str(kind).strip_edges().to_lower())
	for raw_def in defs:
		var def: Dictionary = raw_def
		if str(def.get("key", "")).strip_edges() == clean_section:
			return true

	return false


static func _school_hub_has_active_contract_for_player(gs: GameState) -> bool:
	if gs == null or gs.player == null or gs.school_engine == null:
		return false

	var p: Person = gs.player
	var school_name: String = str(p.school_name).strip_edges()
	var school_mode: String = str(p.school_mode).strip_edges()
	var school_status: String = str(p.school_status).strip_edges().to_lower()

	if school_name != "" and school_name != "None" and school_mode != "" and school_mode != "None" and school_status == "active":
		return true

	var snapshot: Dictionary = gs.school_engine.get_school_ecosystem_snapshot(p)
	var active_contract: Dictionary = MainSceneHelpers._safe_dictionary(snapshot.get("active_contract", {}))
	return not active_contract.is_empty()


static func _school_hub_get_enrollable_children_for_parent(gs: GameState,
	parent: Person) -> Array:
	if parent == null or gs == null or gs.school_engine == null:
		return []
	if not gs.school_engine.has_method("get_enrollable_children_for_parent"):
		return []
	return gs.school_engine.get_enrollable_children_for_parent(parent)


static func _school_hub_get_children_for_parent(gs: GameState,
	parent: Person) -> Array:
	if parent == null or gs == null or gs.school_engine == null:
		return []
	if gs.school_engine.has_method("get_children_for_parent"):
		return gs.school_engine.get_children_for_parent(parent)
	return _school_hub_get_enrollable_children_for_parent(gs, parent)


static func _school_hub_child_id_csv(ids: Array) -> String:
	var parts: Array = []
	for raw_id in ids:
		var child_id: int = int(raw_id)
		if child_id > 0 and not parts.has(str(child_id)):
			parts.append(str(child_id))
	return MainSceneHelpers._school_hub_join_strings(parts, ",")


static func _school_hub_group_child_school_options(gs: GameState,
	children: Array) -> Array:
	var grouped: Dictionary = {}
	var order: Array = []

	if gs == null or gs.school_engine == null:
		return []

	for raw_child in children:
		var child: Person = raw_child
		if child == null:
			continue

		var child_options: Array = gs.school_engine.get_school_options_for(child)
		for raw_option in child_options:
			var option: Dictionary = MainSceneHelpers._safe_dictionary(raw_option)
			var contract: Dictionary = MainSceneHelpers._safe_dictionary(option.get("contract", {}))
			var school_name: String = str(option.get("name", "")).strip_edges()
			var school_type: String = str(option.get("type", "")).strip_edges()
			if school_name == "" or school_type == "":
				continue

			var group_key: String = "%s::%s" % [school_type, school_name]
			if not grouped.has(group_key):
				grouped [group_key] = {
					"type": school_type,
					"name": school_name,
					"contract": contract.duplicate(true),
					"child_ids": [],
					"child_names": []
				}
				order.append(group_key)

			var row: Dictionary = MainSceneHelpers._safe_dictionary(grouped.get(group_key, {}))
			var child_ids: Array = MainSceneHelpers._safe_array(row.get("child_ids", []))
			var child_names: Array = MainSceneHelpers._safe_array(row.get("child_names", []))

			if not child_ids.has(int(child.id)):
				child_ids.append(int(child.id))
				child_names.append("%s age %d" % [child.first_name, int(child.age)])

			row ["child_ids"] = child_ids
			row ["child_names"] = child_names
			grouped [group_key] = row

	var out: Array = []
	for raw_key in order:
		var key: String = str(raw_key)
		if grouped.has(key):
			out.append(MainSceneHelpers._safe_dictionary(grouped.get(key, {})))

	return out


static func _collect_dead_institution_relationship_ids(gs: GameState,
	ids: Array) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	if gs == null:
		return out
	for raw_id in ids:
		var pid: int = int(raw_id)
		if pid <= 0:
			continue
		if seen.has(pid):
			continue
		var rel_person: Person = gs.get_or_reactivate_npc_by_id(pid)
		if rel_person != null:
			if not rel_person.alive:
				seen [pid] = true
				out.append(pid)
		elif gs.npc_graveyard.has(pid):
			seen [pid] = true
			out.append(pid)
	return out


static func _relationship_hub_resolve_section_id(gs: GameState,
	raw_section: String = "") -> String:
	var clean_section: String = str(raw_section).strip_edges().to_lower()

	if clean_section == "" or clean_section == "overview":
		clean_section = "family"

	if _institution_hub_section_is_allowed(gs, "relationships", clean_section):
		return clean_section

	return "family"


static func _relationship_hub_person_card_style(state: String, featured: bool, section_key: String = "", bond_value: int = 50, hovered: bool = false, pulse_strength: float = 0.0) -> StyleBoxFlat:
	var palette: Dictionary = MainSceneHelpers._relationship_hub_section_palette(section_key)
	var section_accent: Color = palette.get("accent", Color(1.0, 0.48, 0.72, 0.9))
	var safe_bond: int = clamp(int(bond_value), 0, 100)
	var bond_ratio: float = clamp(float(safe_bond) / 100.0, 0.0, 1.0)
	var high_bond_pulse: float = clamp((bond_ratio - 0.7) / 0.3, 0.0, 1.0) * clamp(pulse_strength, 0.0, 1.0)

	var bg_color: Color = Color(0.09, 0.035, 0.07, 0.97)
	var border_color: Color = section_accent
	var bond_glow_color: Color = Color(section_accent.r, section_accent.g, section_accent.b, lerp(0.1, 0.42, bond_ratio))

	match str(state).strip_edges().to_lower():
		"warm":
			bg_color = Color(0.125, 0.05, 0.095, 0.97).lerp(Color(0.155, 0.06, 0.115, 0.98), bond_ratio * 0.42)
			border_color = section_accent.lerp(Color(1.0, 0.82, 0.9, 1.0), 0.3 + (bond_ratio * 0.42))
			bond_glow_color = Color(border_color.r, border_color.g, border_color.b, lerp(0.14, 0.48, bond_ratio))
		"strained":
			bg_color = Color(0.06, 0.072, 0.108, 0.97).lerp(Color(0.075, 0.085, 0.125, 0.98), bond_ratio * 0.2)
			border_color = Color(0.64, 0.74, 0.92, 0.88).lerp(section_accent, bond_ratio * 0.22)
			bond_glow_color = Color(0.24, 0.34, 0.56, lerp(0.14, 0.3, bond_ratio))
		"conflict":
			bg_color = Color(0.13, 0.042, 0.07, 0.97)
			border_color = Color(1.0, 0.42, 0.56, 0.96)
			bond_glow_color = Color(0.52, 0.08, 0.16, lerp(0.18, 0.32, bond_ratio))

	if hovered:
		border_color = border_color.lerp(Color(1.0, 1.0, 1.0, 1.0), 0.38)
		bond_glow_color = bond_glow_color.lerp(Color(1.0, 1.0, 1.0, 0.72), 0.34)

	var style:= StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = 2 if featured else 1
	style.border_width_top = 2 if featured else 1
	style.border_width_right = 2 if featured else 1
	style.border_width_bottom = 2 if featured else 1
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.shadow_color = bond_glow_color
	style.shadow_size = int(round(lerp(8.0, 26.0, bond_ratio))) + (8 if hovered else 0) + int(round(high_bond_pulse * 5.0))
	style.shadow_offset = Vector2(0, 5 if featured else 4)
	return style


static func _collect_player_fling_ids(gs: GameState,
	_person: Person) -> Array:
	var out: Array = []
	var seen: Dictionary = {}

	if gs == null:
		return out

	if typeof(gs.scenario_state) == TYPE_DICTIONARY:
		var restaurant_ids: Array = gs.scenario_state.get("restaurant_fling_ids", []) if typeof(gs.scenario_state.get("restaurant_fling_ids", [])) == TYPE_ARRAY else []
		for raw_restaurant_id in restaurant_ids:
			MainSceneHelpers._add_unique_institution_relationship_id(out, seen, int(raw_restaurant_id))

		var foreign_ids: Array = gs.scenario_state.get("foreign_romance_fling_ids", []) if typeof(gs.scenario_state.get("foreign_romance_fling_ids", [])) == TYPE_ARRAY else []
		for raw_foreign_id in foreign_ids:
			MainSceneHelpers._add_unique_institution_relationship_id(out, seen, int(raw_foreign_id))

	return out


static func _build_institution_hub_stat_surface_context(gs: GameState,
	kind: String, person: Person) -> Dictionary:
	var clean_kind: String = str(kind).strip_edges().to_lower()
	var has_partner: bool = gs != null and gs.get_valid_partner(person, true, true) != null
	var school_active: bool = str(person.school_name).strip_edges() != ""
	var career_active: bool = str(person.job).strip_edges() != ""
	var workplace_active: bool = str(person.current_workplace_id).strip_edges() != ""
	return {
		"surface_family": "institution_hub",
		"institution_kind": clean_kind,
		"career_active": career_active,
		"school_active": school_active,
		"relationship_partnered": has_partner,
		"workplace_active": workplace_active
	}


static func _collect_alive_institution_relationship_ids(gs: GameState,
	ids: Array) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	if gs == null:
		return out
	for raw_id in ids:
		var pid: int = int(raw_id)
		if pid <= 0:
			continue
		if seen.has(pid):
			continue
		var rel_person: Person = gs.get_or_reactivate_npc_by_id(pid)
		if rel_person == null:
			continue
		if not rel_person.alive:
			continue
		seen [pid] = true
		out.append(pid)
	return out


static func _resolve_player_custodial_parent(gs: GameState,
	person: Person) -> Person:
	if person == null or gs == null:
		return null
	for raw_parent_id in person.parents:
		var parent: Person = gs.get_or_reactivate_npc_by_id(int(raw_parent_id))
		if parent != null and parent.alive:
			return parent
	return null


static func _resolve_player_household_anchor(gs: GameState,
	person: Person) -> Person:
	if person == null or gs == null:
		return null

	var household_state_raw: Variant = gs.scenario_state.get("household_state", {}) if typeof(gs.scenario_state) == TYPE_DICTIONARY else {}
	var household_state: Dictionary = household_state_raw if typeof(household_state_raw) == TYPE_DICTIONARY else {}
	var forced_self_anchor_id: int = int(household_state.get("forced_self_anchor_player_id", -1))
	if forced_self_anchor_id == int(person.id):
		return person

	if int(person.age) < 18:
		var custodial_parent: Person = _resolve_player_custodial_parent(gs, person)
		if custodial_parent != null:
			return custodial_parent

	return person


static func _resolve_player_household_property_record(gs: GameState,
	person: Person) -> Dictionary:
	if person == null or gs == null or gs.property_engine == null:
		return {}

	var owners_to_check: Array = []
	var seen_owner_ids: Dictionary = {}

	var anchor: Person = _resolve_player_household_anchor(gs, person)
	if anchor != null and not seen_owner_ids.has(int(anchor.id)):
		owners_to_check.append(anchor)
		seen_owner_ids [int(anchor.id)] = true

	var custodial_parent: Person = _resolve_player_custodial_parent(gs, person)
	if custodial_parent != null and not seen_owner_ids.has(int(custodial_parent.id)):
		owners_to_check.append(custodial_parent)
		seen_owner_ids [int(custodial_parent.id)] = true

	if not seen_owner_ids.has(int(person.id)):
		owners_to_check.append(person)
		seen_owner_ids [int(person.id)] = true

	var best_property: Dictionary = {}
	var best_score: float = -999999.0

	for property_owner in owners_to_check:
		if property_owner == null:
			continue
		if not gs.property_engine.properties.has(property_owner.id):
			continue

		for raw_prop in gs.property_engine.properties.get(property_owner.id, []):
			if typeof(raw_prop) != TYPE_DICTIONARY:
				continue

			var prop: Dictionary = raw_prop
			var score: float = 0.0
			var feature_tags: Array = prop.get("feature_tags", [])

			if "dynasty_seat" in feature_tags:
				score += 6.0
			if "family_seat" in feature_tags:
				score += 4.0
			if "luxury" in feature_tags:
				score += 2.0
			if "fortified" in feature_tags:
				score += 1.5

			match str(prop.get("size", "")):
				"Royal":
					score += 6.0
				"Mansion":
					score += 5.0
				"Large":
					score += 4.0
				"Medium":
					score += 3.0
				"Small":
					score += 2.0

			score += float(prop.get("value", prop.get("price", prop.get("base_value", 0)))) / 1000000.0

			if score > best_score:
				best_score = score
				best_property = prop.duplicate(true)

	return best_property


static func _household_property_display_name(gs: GameState,
	prop: Dictionary) -> String:
	if prop.is_empty():
		return "Unknown Residence"

	var display_name: String = str(prop.get("nickname", "")).strip_edges()
	if display_name != "":
		return display_name

	display_name = str(prop.get("display_name", prop.get("type", "Property"))).strip_edges()
	if display_name != "":
		return display_name

	var size_name: String = str(prop.get("size", "")).strip_edges()
	if size_name != "" and gs != null and gs.property_engine != null and gs.property_engine.has_method("_property_type_for_size"):
		return str(gs.property_engine._property_type_for_size(size_name)).strip_edges()

	return "Residence"


static func _build_household_property_card_lines(gs: GameState,
	person: Person) -> Array:
	var lines: Array = []
	lines.append("===== HOUSEHOLD PROPERTY =====")

	if person == null or gs == null or gs.property_engine == null:
		lines.append("Residence: Unresolved")
		lines.append("No household property system is available right now.")
		lines.append("==============================")
		return lines

	var prop: Dictionary = _resolve_player_household_property_record(gs, person)
	if prop.is_empty():
		lines.append("Residence: Unresolved")
		lines.append("No owned property is currently linked to this household.")
		if str(person.home_city).strip_edges() != "" or str(person.home_country).strip_edges() != "":
			if str(person.home_city).strip_edges() != "" and str(person.home_country).strip_edges() != "":
				lines.append("Location: %s, %s" % [person.home_city, person.home_country])
			elif str(person.home_city).strip_edges() != "":
				lines.append("Location: %s" % person.home_city)
			else:
				lines.append("Location: %s" % person.home_country)
		lines.append("==============================")
		return lines

	var display_name: String = _household_property_display_name(gs, prop)
	var size_name: String = str(prop.get("size", "")).strip_edges()
	var era_form: String = display_name
	if size_name != "" and gs.property_engine.has_method("_property_type_for_size"):
		era_form = str(gs.property_engine._property_type_for_size(size_name)).strip_edges()

	var address_text: String = str(prop.get("address", "Unknown Address")).strip_edges()
	if address_text == "":
		address_text = "Unknown Address"

	var condition_score: int = int(round(float(prop.get("condition", 100.0))))
	var condition_label: String = str(prop.get("condition_label", "Excellent")).strip_edges()
	var social_tier: String = str(prop.get("social_tier", "common")).strip_edges()
	var value_band: String = str(prop.get("value_band", "entry")).strip_edges()
	var archetype: String = str(prop.get("archetype", "residence")).strip_edges()
	var feature_tags: Array = prop.get("feature_tags", [])

	var household_role: String = "Primary Household Residence"
	if "dynasty_seat" in feature_tags:
		household_role = "Dynasty Seat"
	elif "family_seat" in feature_tags:
		household_role = "Family Seat"
	elif "fortified" in feature_tags:
		household_role = "Fortified Residence"
	elif "luxury" in feature_tags:
		household_role = "Luxury Residence"

	lines.append("Residence: %s" % display_name)
	lines.append("Era Form: %s" % era_form)
	lines.append("Household Role: %s" % household_role)
	lines.append("Archetype: %s" % archetype.capitalize())
	if size_name != "":
		lines.append("Size Tier: %s" % size_name)
	lines.append("Address: %s" % address_text)
	lines.append("Condition: %d%% • %s" % [condition_score, condition_label])
	if social_tier != "":
		lines.append("Social Tier: %s" % social_tier.capitalize())
	if value_band != "":
		lines.append("Value Band: %s" % value_band.capitalize())

	var ambiance_bits: Array = []
	if "fortified" in feature_tags:
		ambiance_bits.append("fortified")
	if "luxury" in feature_tags:
		ambiance_bits.append("luxury")
	if "dense" in feature_tags:
		ambiance_bits.append("dense")
	if "family_seat" in feature_tags:
		ambiance_bits.append("family-seat")
	if "dynasty_seat" in feature_tags:
		ambiance_bits.append("dynasty-seat")

	if ambiance_bits.is_empty():
		lines.append("Property Feel: This household is anchored by a practical %s-era residence." % str(gs.era.name))
	else:
		lines.append("Property Feel: %s-era %s" % [str(gs.era.name), ", ".join(ambiance_bits)])

	lines.append("==============================")
	return lines


static func _school_hub_friendliness_text_color(value: int) -> Color:
	var base: Color = MainSceneHelpers._school_hub_friendliness_color(value)
	return Color(base.r, base.g, base.b, 0.98)


static func _school_hub_apply_friendliness_bar_visual(bar: ProgressBar, value: int) -> void:
	if bar == null:
		return

	var clean_value: int = clamp(int(value), 0, 100)
	var fill_color: Color = MainSceneHelpers._school_hub_friendliness_color(clean_value)

	var fill_style:= StyleBoxFlat.new()
	fill_style.bg_color = fill_color
	fill_style.corner_radius_top_left = 8
	fill_style.corner_radius_top_right = 8
	fill_style.corner_radius_bottom_left = 8
	fill_style.corner_radius_bottom_right = 8

	var background_style:= StyleBoxFlat.new()
	background_style.bg_color = Color(fill_color.r, fill_color.g, fill_color.b, 0.13)
	background_style.border_color = Color(fill_color.r, fill_color.g, fill_color.b, 0.28)
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


static func _school_hub_student_friendliness_for_row(gs: GameState,
	row: Dictionary) -> int:
	var clean_row: Dictionary = MainSceneHelpers._safe_dictionary(row)
	if clean_row.is_empty():
		return 50

	if clean_row.has("friendliness"):
		return clamp(int(clean_row.get("friendliness", 50)), 0, 100)

	if clean_row.has("friendliness_value"):
		return clamp(int(clean_row.get("friendliness_value", 50)), 0, 100)

	if clean_row.has("social_warmth"):
		return clamp(int(clean_row.get("social_warmth", 50)), 0, 100)

	var person_id: int = int(clean_row.get("person_id", -1))
	if gs != null and person_id > 0:
		var npc: Person = gs.get_or_reactivate_npc_by_id(person_id)
		if npc != null:
			var score: float = 50.0
			score += (float(npc.satisfaction) - 50.0) * 0.24
			score += (float(npc.mental_health) - 50.0) * 0.2
			score += (float(npc.respect) - 50.0) * 0.22
			score += (float(npc.happiness) - 50.0) * 0.18 if "happiness" in npc else 0.0
			score += (float(npc.health) - 50.0) * 0.08
			score += (float(npc.smarts) - 50.0) * 0.04
			return clamp(int(round(score)), 0, 100)

	var popularity: int = clamp(int(clean_row.get("popularity", 50)), 0, 100)
	return clamp(int(round(45.0 + (float(popularity) * 0.18))), 0, 100)


static func _school_hub_add_student_friendliness_bar(gs: GameState,
	box: VBoxContainer, row: Dictionary) -> void:
	if box == null:
		return

	var friendliness: int = _school_hub_student_friendliness_for_row(gs, row)

	var friendliness_label:= Label.new()
	friendliness_label.text = "Friendliness %d%%" % friendliness
	friendliness_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	friendliness_label.add_theme_font_size_override("font_size", 11)
	friendliness_label.add_theme_color_override("font_color", _school_hub_friendliness_text_color(friendliness))
	box.add_child(friendliness_label)

	var friendliness_bar:= ProgressBar.new()
	friendliness_bar.min_value = 0
	friendliness_bar.max_value = 100
	friendliness_bar.value = friendliness
	friendliness_bar.custom_minimum_size = Vector2(0, 12)
	friendliness_bar.show_percentage = false
	friendliness_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_school_hub_apply_friendliness_bar_visual(friendliness_bar, friendliness)
	box.add_child(friendliness_bar)


static func _school_hub_meal_tab_label(gs: GameState) -> String:
	if gs == null or gs.player == null or gs.school_engine == null:
		return "Meal"

	var snapshot: Dictionary = gs.school_engine.get_school_ecosystem_snapshot(gs.player)
	var active_contract: Dictionary = MainSceneHelpers._safe_dictionary(snapshot.get("active_contract", {}))
	var meal_zone: Dictionary = MainSceneHelpers._safe_dictionary(snapshot.get("meal_zone", {}))
	var label_text: String = str(meal_zone.get("name", active_contract.get("meal_surface_label", "Meal"))).strip_edges()

	if label_text == "":
		return "Meal"

	return label_text


static func _school_hub_visible_classmate_count(classmates: Array, class_zones: Array, player: Person) -> int:
	var seen: Dictionary = {}

	for raw_classmate in classmates:
		var npc: Person = raw_classmate
		if npc == null:
			continue
		if player != null and int(npc.id) == int(player.id):
			continue
		seen [int(npc.id)] = true

	for raw_zone in class_zones:
		var class_zone: Dictionary = MainSceneHelpers._safe_dictionary(raw_zone)
		var students: Array = MainSceneHelpers._safe_array(class_zone.get("students", []))
		for raw_student in students:
			var row: Dictionary = MainSceneHelpers._safe_dictionary(raw_student)
			var student_id: int = int(row.get("person_id", -1))
			if student_id <= 0:
				continue
			if player != null and student_id == int(player.id):
				continue
			seen [student_id] = true

	return seen.size()


static func _school_hub_remaining_class_roster_rows(gs: GameState,
	class_zone: Dictionary) -> Array:
	var rows: Array = []
	var students: Array = MainSceneHelpers._safe_array(class_zone.get("students", []))
	if students.is_empty():
		return rows

	var preview_limit: int = int(class_zone.get("student_preview_limit", 10))
	preview_limit = int(clamp(preview_limit, 0, students.size()))

	for i in range(preview_limit, students.size()):
		var student_row: Dictionary = MainSceneHelpers._safe_dictionary(students [i])
		if student_row.is_empty():
			continue

		var person_id: int = int(student_row.get("person_id", -1))
		var popularity: int = int(student_row.get("popularity", 0))

		if popularity <= 0 and gs != null and person_id > 0:
			var npc: Person = gs.get_or_reactivate_npc_by_id(person_id)
			if npc != null:
				popularity = MainSceneHelpers._school_hub_popularity_for_person(npc)

		rows.append({
			"person_id": person_id,
			"full_name": str(student_row.get("full_name", "Student")),
			"age": int(student_row.get("age", 0)),
			"role": "Student • %s" % str(class_zone.get("name", "Class")),
			"popularity": popularity
		})

	return rows


static func _resolve_belonging_market_profile(gs: GameState,
	item: Dictionary) -> Dictionary:
	var item_type: String = str(item.get("type", item.get("subtype", ""))).strip_edges()
	var lore: String = str(item.get("lore", "")).strip_edges()

	var base_value: int = int(item.get("base_value", item.get("value", 0)))
	if base_value <= 0 and item.has("worth"):
		base_value = int(item.get("worth", 0))
	if base_value <= 0 and item.has("price"):
		base_value = int(item.get("price", 0))
	if base_value <= 0 and item.has("estimated_value"):
		base_value = int(item.get("estimated_value", 0))

	var annual_appreciation_rate: float = float(item.get("annual_appreciation_rate", 0.0))

	var acquired_year: int = int(item.get("acquired_year", 0))
	if acquired_year == 0 and typeof(item.get("provenance", {})) == TYPE_DICTIONARY:
		var provenance: Dictionary = item.get("provenance", {})
		acquired_year = int(provenance.get("acquired_year", 0))

	if item_type == "DragonBall":
		var star: int = int(item.get("star", 0))
		var dragon_ball_prices: Dictionary = {
			1: 1000000000,
			2: 2500000000,
			3: 5000000000,
			4: 10000000000,
			5: 15000000000,
			6: 25000000000,
			7: 40000000000
		}
		var dragon_ball_lore: Dictionary = {
			1: "Its glow feels ancient even when resting still.",
			2: "Collectors whisper that this one tends to surface near turning points in history.",
			3: "Its internal light bends like a living flame.",
			4: "The most sentimental traders refuse to name their price for this one.",
			5: "Merchants claim the room changes temperature when it is near.",
			6: "Its glow feels too intelligent to be ordinary treasure.",
			7: "The rarest dealers won't even look directly at it for too long."
		}
		if base_value <= 0 and dragon_ball_prices.has(star):
			base_value = int(dragon_ball_prices [star])
		if annual_appreciation_rate <= 0.0 and base_value > 0:
			annual_appreciation_rate = 0.09
		if lore == "" and dragon_ball_lore.has(star):
			lore = str(dragon_ball_lore [star]).strip_edges()

	elif item_type == "Artifact":
		var artifact_market_profile: Dictionary = (
			MainSceneHelpers._safe_dictionary(
				item.get(
					"artifact_market_profile",
					{}
				)
			)
		)

		if not artifact_market_profile.is_empty():
			if base_value <= 0:
				base_value = int(
					artifact_market_profile.get(
						"base_value",
						artifact_market_profile.get(
							"value",
							0
						)
					)
				)

			if annual_appreciation_rate <= 0.0:
				annual_appreciation_rate = float(
					artifact_market_profile.get(
						"annual_appreciation_rate",
						0.0
					)
				)

			if lore == "":
				lore = str(
					artifact_market_profile.get(
						"lore",
						""
					)
				).strip_edges()

			if not artifact_market_profile.has(
				"historical_value"
			):
				artifact_market_profile [
					"historical_value"
				] = int(
					item.get(
						"historical_value",
						0
					)
				)

			if not artifact_market_profile.has(
				"cultural_value"
			):
				artifact_market_profile [
					"cultural_value"
				] = int(
					item.get(
						"cultural_value",
						0
					)
				)

	var years_held: int = 0
	if gs != null and acquired_year > 0:
		years_held = max(0, int(gs.year) - acquired_year)

	var current_value: int = base_value
	if annual_appreciation_rate > 0.0 and years_held > 0:
		current_value = int(round(float(base_value) * pow(1.0 + annual_appreciation_rate, years_held)))

	return {
		"base_value": base_value,
		"current_value": current_value,
		"annual_appreciation_rate": annual_appreciation_rate,
		"years_held": years_held,
		"lore": lore
	}


static func _resolve_belonging_display_lore(gs: GameState,
	item: Dictionary) -> String:
	var lore: String = str(item.get("lore", "")).strip_edges()
	if lore != "":
		return lore

	var market_profile: Dictionary = _resolve_belonging_market_profile(gs, item)
	return str(market_profile.get("lore", "")).strip_edges()


static func _player_is_royal_bender(gs: GameState) -> bool:
	if gs == null or gs.player == null:
		return false
	var p:= gs.player
	if not p.is_royal:
		return false
	return str(p.bending_nation).strip_edges() != ""


static func _royal_bender_ui_tint_for_player(gs: GameState) -> Color:
	if not _player_is_royal_bender(gs):
		return Color(1.0, 1.0, 1.0, 1.0)
	var nation:= str(gs.player.bending_nation).strip_edges()
	match nation:
		"Fire Nation":
			return Color(1.0, 0.58, 0.3, 1.0)
		"Water Tribe":
			return Color(0.5, 0.8, 1.0, 1.0)
		"Earth Kingdom":
			return Color(0.73, 0.92, 0.46, 1.0)
		"Air Nomads":
			return Color(0.92, 0.92, 0.96, 1.0)
		_:
			return Color(1.0, 1.0, 1.0, 1.0)


static func _main_tab_packet_is_desktop_forbidden(
	packet: Dictionary
) -> bool:
	if typeof(packet) != TYPE_DICTIONARY:
		return true

	var surface_id: String = str(
		packet.get(
			"surface_id",
			packet.get(
				"id",
				""
			)
		)
	).strip_edges().to_lower()
	var source: String = str(
		packet.get(
			"source",
			packet.get(
				"runtime_source",
				""
			)
		)
	).strip_edges().to_lower()
	var shell_kind: String = str(
		packet.get(
			"shell_kind",
			packet.get(
				"platform",
				""
			)
		)
	).strip_edges().to_lower()
	var title: String = str(
		packet.get(
			"title",
			""
		)
	).strip_edges().to_lower()
	var subtitle: String = str(
		packet.get(
			"subtitle",
			""
		)
	).strip_edges().to_lower()
	var description: String = str(
		packet.get(
			"description",
			""
		)
	).strip_edges().to_lower()
	var tags: Array = MainSceneHelpers._safe_array(
		packet.get(
			"tags",
			[]
		)
	)

	if surface_id in [
		"discord_life_hub",
		"relationship_contract_hub",
		"career_contract_hub",
		"school_contract_hub",
		"activity_contract_hub",
		"realm_contract_hub"
	]:
		return true

	if surface_id.begins_with(
		"discord_"
	):
		return true

	if source.find("discord") >= 0:
		return true

	if shell_kind in [
		"discord",
		"discord_remote_shell",
		"remote_discord_shell"
	]:
		return true

	for raw_tag in tags:
		if str(
			raw_tag
		).strip_edges().to_lower().find(
			"discord"
		) >= 0:
			return true

	for text_value in [
		title,
		subtitle,
		description
	]:
		if text_value.find(
			"discord"
		) >= 0:
			return true

	return false


static func _desktop_ui_contract_surface_is_allowed(
	surface_contract: Dictionary
) -> bool:
	if surface_contract.is_empty():
		return false

	if _main_tab_packet_is_desktop_forbidden(
		surface_contract
	):
		return false

	var platform_scope: String = str(
		surface_contract.get(
			"platform_scope",
			surface_contract.get(
				"shell_scope",
				""
			)
		)
	).strip_edges().to_lower()

	if platform_scope in [
		"discord",
		"discord_only",
		"remote_shell",
		"remote_shell_only"
	]:
		return false

	return true


static func _main_tab_packet_is_renderable(packet: Dictionary) -> bool:
	if typeof(packet) != TYPE_DICTIONARY:
		return false
	if packet.is_empty():
		return false
	if _main_tab_packet_is_desktop_forbidden(packet):
		return false
	if not bool(packet.get("success", false)):
		return false
	if not bool(packet.get("ui_safe", false)):
		return false
	if str(packet.get("contract_status", "")) != "satisfied":
		return false
	return true


static func _runtime_hud_snapshot_flag(gs: GameState,
	key: String, fallback: bool = false) -> bool:
	if gs == null or typeof(gs.scenario_state) != TYPE_DICTIONARY:
		return fallback

	var snapshot: Dictionary = MainSceneHelpers._safe_dictionary(gs.scenario_state.get("runtime_hud_visibility_snapshot", {}))
	if snapshot.is_empty():
		return fallback

	return bool(snapshot.get(key, fallback))


