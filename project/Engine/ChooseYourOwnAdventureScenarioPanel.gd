extends Control
class_name ChooseYourOwnAdventureScenarioPanel

signal choice_pressed(choice_id: String)
var dim: ColorRect
var card: PanelContainer
var top_actions_bar: HBoxContainer
var top_left_actions: HBoxContainer
var top_right_actions: HBoxContainer
var title_label: Label
var subtitle_label: Label
var body_label: RichTextLabel
var pressure_label: Label
var saturation_label: Label
var choices_scroll: ScrollContainer
var choices_box: VBoxContainer
var footer_label: Label
var animation_phase: float = 0.0
var current_accent: Color = Color(0.7, 0.42, 1.0, 1.0)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_as_relative = false
	z_index = 900
	_build_ui()
	hide()


func _process(delta: float) -> void:
	if not visible:
		return

	animation_phase += delta
	if card != null and is_instance_valid(card):
		var pulse: float = (sin(animation_phase * 1.35) + 1.0) * 0.5
		card.add_theme_stylebox_override("panel", _build_card_style(pulse))


func present(result: Dictionary) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_as_relative = false
	z_index = 900

	if dim == null or card == null:
		_build_ui()

	show()

	current_accent = _parse_color(str(result.get("accent", "#B56BFF")), Color(0.7, 0.42, 1.0, 1.0))
	_build_top_actions(result)

	var display_kind: String = str(result.get("display_kind", result.get("type", ""))).strip_edges()
	var safe_emoji: String = str(result.get("emoji", " ")).strip_edges()
	if safe_emoji == "":
		safe_emoji = " "

	title_label.text = "%s %s" % [
		safe_emoji,
		str(result.get("panel_title", "Choose Your Own Adventure"))
	]
	subtitle_label.text = str(result.get("subtitle", "Narrative as Pressure Injection"))

	body_label.clear()

	var intro_text: String = str(result.get("text", "")).strip_edges()
	var overview: String = str(result.get("overview", "")).strip_edges()
	var body_text: String = intro_text

	if display_kind == "adventure_catalog":
		body_text = _build_catalog_intro_text(intro_text)
	elif overview != "" and overview != intro_text:
		body_text = "%s\n\n— Story Pulse —\n%s" % [intro_text, overview]

	if body_text == "":
		body_text = "You feel the story waiting for a choice."

	body_label.append_text(body_text)

	var pressure_raw: Variant = result.get("pressure", {})
	var pressure: Dictionary = pressure_raw.duplicate(true) if typeof(pressure_raw) == TYPE_DICTIONARY else {}
	pressure_label.text = _format_pressure(pressure)

	var saturation: float = float(result.get("saturation", 0.0))
	saturation_label.text = "Narrative Saturation: %d%%" % int(round(saturation))

	_clear_choices()

	var opps_raw: Variant = result.get("opps", [])
	var opps: Array = opps_raw if typeof(opps_raw) == TYPE_ARRAY else []
	for raw_choice in opps:
		if typeof(raw_choice) != TYPE_DICTIONARY:
			continue
		_add_choice_card(raw_choice as Dictionary)

	if opps.is_empty():
		_add_choice_card({
			"choice_id": "open_adventure_catalog",
			"label": "No action contracts surfaced yet",
			"text": "The current story node did not expose choices.",
			"overview": "This fallback keeps the panel recoverable instead of trapping the player.",
			"display_kind": "action_card",
			"accent": "#B56BFF",
			"emoji": "↩"
		})

	footer_label.text = str(result.get("footer_text", "Your choice changes the pressure. The pressure changes the life."))

	if choices_scroll != null and is_instance_valid(choices_scroll):
		choices_scroll.scroll_vertical = 0

	if body_label != null and is_instance_valid(body_label):
		body_label.scroll_to_line(0)

	call_deferred("_hide_scrollbars")


func hide_panel() -> void:
	hide()


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_as_relative = false
	z_index = 900

	dim = ColorRect.new()
	dim.name = "ChooseAdventureScenarioDim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.008, 0.006, 0.018, 0.985)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var safe_margin:= MarginContainer.new()
	safe_margin.name = "ChooseAdventureSafeMargin"
	safe_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_margin.add_theme_constant_override("margin_left", 18)
	safe_margin.add_theme_constant_override("margin_right", 18)
	safe_margin.add_theme_constant_override("margin_top", 14)
	safe_margin.add_theme_constant_override("margin_bottom", 14)
	safe_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	safe_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(safe_margin)

	card = PanelContainer.new()
	card.name = "ChooseAdventureScenarioCard"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _build_card_style(0.0))
	safe_margin.add_child(card)

	var margin:= MarginContainer.new()
	margin.name = "ChooseAdventureScenarioInnerMargin"
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 22)
	card.add_child(margin)

	var root:= VBoxContainer.new()
	root.name = "ChooseAdventureScenarioRoot"
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)
	top_actions_bar = HBoxContainer.new()
	top_actions_bar.name = "ChooseAdventureTopActions"
	top_actions_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_actions_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	top_actions_bar.add_theme_constant_override("separation", 12)
	root.add_child(top_actions_bar)

	top_left_actions = HBoxContainer.new()
	top_left_actions.name = "ChooseAdventureTopLeftActions"
	top_left_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_left_actions.alignment = BoxContainer.ALIGNMENT_BEGIN
	top_left_actions.add_theme_constant_override("separation", 10)
	top_actions_bar.add_child(top_left_actions)

	top_right_actions = HBoxContainer.new()
	top_right_actions.name = "ChooseAdventureTopRightActions"
	top_right_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_right_actions.alignment = BoxContainer.ALIGNMENT_END
	top_right_actions.add_theme_constant_override("separation", 10)
	top_actions_bar.add_child(top_right_actions)
	title_label = Label.new()
	title_label.name = "ChooseAdventureTitle"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", 34)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.96, 1.0, 1.0))
	root.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.name = "ChooseAdventureSubtitle"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.add_theme_font_size_override("font_size", 16)
	subtitle_label.add_theme_color_override("font_color", Color(0.82, 0.78, 0.96, 1.0))
	root.add_child(subtitle_label)

	var stats:= HBoxContainer.new()
	stats.name = "ChooseAdventurePressureStats"
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 18)
	root.add_child(stats)

	pressure_label = Label.new()
	pressure_label.name = "PressureLabel"
	pressure_label.add_theme_font_size_override("font_size", 12)
	pressure_label.add_theme_color_override("font_color", Color(0.82, 0.72, 1.0, 1.0))
	stats.add_child(pressure_label)

	saturation_label = Label.new()
	saturation_label.name = "SaturationLabel"
	saturation_label.add_theme_font_size_override("font_size", 12)
	saturation_label.add_theme_color_override("font_color", Color(0.46, 0.9, 1.0, 1.0))
	stats.add_child(saturation_label)

	var intro_panel:= PanelContainer.new()
	intro_panel.name = "ChooseAdventureIntroPanel"
	intro_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intro_panel.custom_minimum_size = Vector2(0, 124)
	intro_panel.add_theme_stylebox_override("panel", _build_intro_style())
	root.add_child(intro_panel)

	var intro_margin:= MarginContainer.new()
	intro_margin.name = "ChooseAdventureIntroMargin"
	intro_margin.add_theme_constant_override("margin_left", 18)
	intro_margin.add_theme_constant_override("margin_right", 18)
	intro_margin.add_theme_constant_override("margin_top", 14)
	intro_margin.add_theme_constant_override("margin_bottom", 14)
	intro_panel.add_child(intro_margin)

	body_label = RichTextLabel.new()
	body_label.name = "ChooseAdventureBody"
	body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_label.fit_content = true
	body_label.scroll_active = false
	body_label.bbcode_enabled = false
	body_label.add_theme_font_size_override("normal_font_size", 16)
	body_label.add_theme_color_override("default_color", Color(0.93, 0.9, 0.98, 1.0))
	intro_margin.add_child(body_label)

	var library_label:= Label.new()
	library_label.name = "ChooseAdventureLibraryLabel"
	library_label.text = "ADVENTURE LIBRARY"
	library_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	library_label.add_theme_font_size_override("font_size", 13)
	library_label.add_theme_color_override("font_color", Color(0.74, 0.66, 0.94, 1.0))
	root.add_child(library_label)

	choices_scroll = ScrollContainer.new()
	choices_scroll.name = "ChooseAdventureChoicesScroll"
	choices_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	choices_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	choices_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	choices_scroll.follow_focus = true
	choices_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(choices_scroll)

	choices_box = VBoxContainer.new()
	choices_box.name = "ChooseAdventureChoices"
	choices_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	choices_box.add_theme_constant_override("separation", 14)
	choices_scroll.add_child(choices_box)

	footer_label = Label.new()
	footer_label.name = "ChooseAdventureFooter"
	footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer_label.add_theme_font_size_override("font_size", 12)
	footer_label.add_theme_color_override("font_color", Color(0.6, 0.57, 0.72, 1.0))
	root.add_child(footer_label)

	call_deferred("_hide_scrollbars")


func _hide_scrollbars() -> void:
	if choices_scroll != null and is_instance_valid(choices_scroll):
		var choice_bar: VScrollBar = choices_scroll.get_v_scroll_bar()
		if choice_bar != null:
			choice_bar.modulate = Color(1.0, 1.0, 1.0, 0.0)
			choice_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var story_scroll: ScrollContainer = get_node_or_null("ChooseAdventureSafeMargin/ChooseAdventureScenarioCard/ChooseAdventureScenarioInnerMargin/ChooseAdventureScenarioRoot/ChooseAdventureContentSplit/ChooseAdventureStoryScroll")
	if story_scroll != null:
		var story_bar: VScrollBar = story_scroll.get_v_scroll_bar()
		if story_bar != null:
			story_bar.modulate = Color(1.0, 1.0, 1.0, 0.0)
			story_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _add_choice_card(choice: Dictionary) -> void:
	if choices_box == null:
		return

	var choice_id: String = str(choice.get("choice_id", choice.get("id", ""))).strip_edges()
	if choice_id == "":
		choice_id = "choice_%d" % choices_box.get_child_count()

	var label: String = str(choice.get("label", "Choose")).strip_edges()
	var text: String = str(choice.get("text", "")).strip_edges()
	var overview: String = str(choice.get("overview", "")).strip_edges()
	var display_kind: String = str(choice.get("display_kind", "action_card")).strip_edges()
	var emoji: String = str(choice.get("emoji", "✦")).strip_edges()
	if emoji == "":
		emoji = "✦"

	var accent: Color = _parse_color(str(choice.get("accent", "#B56BFF")), current_accent)

	var card_height: int = 104
	match display_kind:
		"adventure_card":
			card_height = 176
		"story_start_card":
			card_height = 292
		"birth_path_card":
			card_height = 178
		_:
			card_height = 112

	if overview.length() > 360:
		card_height = max(card_height, 248)
	if overview.length() > 700:
		card_height = max(card_height, 332)

	var button:= Button.new()
	button.name = "ChooseAdventureChoice_%s" % choice_id
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, card_height)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.text = _build_choice_card_text(emoji, label, text, overview, display_kind)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color(1.0, 0.98, 1.0, 1.0))
	button.add_theme_stylebox_override("normal", _build_choice_style(accent, false))
	button.add_theme_stylebox_override("hover", _build_choice_style(accent, true))
	button.add_theme_stylebox_override("pressed", _build_choice_style(accent.darkened(0.18), true))
	button.add_theme_stylebox_override("focus", _build_choice_style(accent.lightened(0.1), true))

	button.mouse_entered.connect(func () -> void:
		current_accent = accent
		if card != null and is_instance_valid(card):
			card.add_theme_stylebox_override("panel", _build_card_style(0.65))
	)

	button.pressed.connect(func () -> void:
		choice_pressed.emit(choice_id)
	)

	choices_box.add_child(button)

func _build_catalog_intro_text(intro_text: String) -> String:
	var clean_intro: String = str(intro_text).strip_edges()
	if clean_intro == "":
		clean_intro = "Pick an adventure contract. Each story begins as a choice, becomes pressure, and eventually teaches the simulation what kind of life it should create."

	return "%s\n\nScroll the library below. Each card is a doorway into a different kind of Life: Family, Faith, Money, Danger, Reputation, Love, Survival, Power, and Identity." % clean_intro
func _build_intro_style() -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.045, 0.09, 0.72)
	style.border_color = Color(current_accent.r, current_accent.g, current_accent.b, 0.44)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.shadow_color = Color(current_accent.r, current_accent.g, current_accent.b, 0.1)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 4)
	return style
func _build_choice_card_text(emoji: String, label: String, text: String, overview: String, display_kind: String) -> String:
	var lines: Array = []

	lines.append("%s %s" % [emoji, label])

	if text != "":
		lines.append(text)

	match display_kind:
		"story_start_card":
			if overview != "":
				lines.append("")
				lines.append("— Overview —")
				lines.append(_shorten(overview.replace("\n", " "), 900))
		"birth_path_card":
			if overview != "" and overview != text:
				lines.append(_shorten(overview.replace("\n", " "), 360))
		"adventure_card":
			if overview != "":
				lines.append(_shorten(overview.replace("\n", " "), 260))
		_:
			if overview != "" and overview != text:
				lines.append(_shorten(overview.replace("\n", " "), 150))

	return "\n".join(lines)


func _shorten(value: String, max_chars: int) -> String:
	var clean: String = str(value).strip_edges()
	if clean.length() <= max_chars:
		return clean
	return "%s…" % clean.substr(0, max(0, max_chars - 1)).strip_edges()


func _clear_choices() -> void:
	if choices_box == null:
		return

	for child in choices_box.get_children():
		child.queue_free()
func _build_top_actions(result: Dictionary) -> void:
	if top_left_actions == null or top_right_actions == null:
		return
	for child in top_left_actions.get_children():
		child.queue_free()
	for child in top_right_actions.get_children():
		child.queue_free()
	var actions_raw: Variant = result.get("top_actions", [])
	var actions: Array = actions_raw.duplicate(true) if typeof(actions_raw) == TYPE_ARRAY else []
	for raw_action in actions:
		if typeof(raw_action) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = raw_action
		var slot: String = str(action.get("slot", "right")).strip_edges().to_lower()
		var button: Button = _build_top_action_button(action)
		if slot == "left":
			top_left_actions.add_child(button)
		else:
			top_right_actions.add_child(button)

func _build_top_action_button(action: Dictionary) -> Button:
	var button:= Button.new()
	var choice_id: String = str(action.get("choice_id", "")).strip_edges()
	button.name = "ChooseAdventureTopAction_%s" % choice_id.replace(":", "_").replace(" ", "_")
	button.text = str(action.get("label", "Back"))
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(152, 42)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color(1.0, 0.98, 1.0, 1.0))
	var role: String = str(action.get("role", "secondary")).strip_edges().to_lower()
	var accent: Color = current_accent
	if role == "god_mode":
		accent = Color(0.24, 0.86, 1.0, 1.0)
	elif role == "primary":
		accent = current_accent.lightened(0.1)
	button.add_theme_stylebox_override("normal", _build_top_action_style(accent, false, role))
	button.add_theme_stylebox_override("hover", _build_top_action_style(accent, true, role))
	button.add_theme_stylebox_override("pressed", _build_top_action_style(accent.darkened(0.16), true, role))
	button.pressed.connect(func () -> void:
		choice_pressed.emit(choice_id)
	)
	return button

func _build_top_action_style(accent: Color, hovered: bool, role: String = "secondary") -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	var intensity: float = 0.12
	if role == "primary":
		intensity = 0.22
	elif role == "god_mode":
		intensity = 0.28
	style.bg_color = Color(
		0.045 + (accent.r * intensity),
		0.04 + (accent.g * intensity),
		0.07 + (accent.b * intensity),
		0.94
	)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.68 if not hovered else 1.0)
	style.border_width_left = 1 if not hovered else 2
	style.border_width_right = 1 if not hovered else 2
	style.border_width_top = 1 if not hovered else 2
	style.border_width_bottom = 1 if not hovered else 2
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.14 if not hovered else 0.3)
	style.shadow_size = 8 if not hovered else 14
	style.shadow_offset = Vector2(0, 3)
	return style

func _format_pressure(pressure: Dictionary) -> String:
	if pressure.is_empty():
		return "Pressure: dormant"

	var parts: Array = []
	for raw_key in pressure.keys():
		var key: String = str(raw_key)
		var value: float = float(pressure.get(raw_key, 0.0))
		if abs(value) <= 0.01:
			continue
		parts.append("%s %+d" % [key.capitalize().replace("_", " "), int(round(value))])

	if parts.is_empty():
		return "Pressure: dormant"

	return "Pressure: %s" % " • ".join(parts)


func _parse_color(value: String, fallback: Color) -> Color:
	var clean: String = str(value).strip_edges()
	if clean == "":
		return fallback

	if not clean.begins_with("#"):
		clean = "#%s" % clean

	if Color.html_is_valid(clean):
		return Color.html(clean)

	return fallback


func _build_card_style(pulse: float) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.028, 0.058, 0.975)
	style.border_color = Color(
		current_accent.r + (0.05 * pulse),
		current_accent.g + (0.05 * pulse),
		current_accent.b + (0.05 * pulse),
		0.94
	)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 24
	style.corner_radius_top_right = 24
	style.corner_radius_bottom_left = 24
	style.corner_radius_bottom_right = 24
	style.shadow_color = Color(current_accent.r, current_accent.g, current_accent.b, 0.18 + (0.12 * pulse))
	style.shadow_size = 24 + int(8.0 * pulse)
	style.shadow_offset = Vector2(0, 8)
	return style


func _build_choice_style(accent: Color, hovered: bool) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(
		0.07 + (accent.r * 0.1),
		0.055 + (accent.g * 0.08),
		0.1 + (accent.b * 0.08),
		0.96
	)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.82 if not hovered else 1.0)
	style.border_width_left = 2 if not hovered else 3
	style.border_width_right = 2 if not hovered else 3
	style.border_width_top = 2 if not hovered else 3
	style.border_width_bottom = 2 if not hovered else 3
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.16 if not hovered else 0.3)
	style.shadow_size = 10 if not hovered else 18
	style.shadow_offset = Vector2(0, 5)
	return style