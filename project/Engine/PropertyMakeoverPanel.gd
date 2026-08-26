extends PanelContainer
class_name PropertyMakeoverPanel

signal close_requested
signal makeover_action_requested(path_id: String, action_id: String, payload: Dictionary)

var host: Node = null
var gs: GameState = null
var actor: Person = null
var active_contract: Dictionary = {}

var title_label: Label = null
var subtitle_label: Label = null
var status_label: Label = null
var content_box: VBoxContainer = null

func bind_host(_host: Node, _gs: GameState = null) -> void:
	host = _host
	gs = _gs
	_ensure_surface()


func open_for_property(target_actor: Person, contract: Dictionary) -> void:
	actor = target_actor
	_ensure_surface()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	render_surface_contract(contract)


func render_surface_contract(contract: Dictionary) -> void:
	_ensure_surface()
	active_contract = contract.duplicate(true)

	title_label.text = str(contract.get("title", "PROPERTY MAKEOVER")).to_upper()
	subtitle_label.text = str(contract.get("subtitle", ""))
	status_label.text = str(contract.get("status_text", ""))
	_clear_children(content_box)

	_add_header_card("RENOVATION AUTHORITY", [
		"This is the property construction surface.",
		"Add rooms, floors, hidden spaces, containers, fixtures, and identity-shaping renovations without the UI mutating reality.",
		"Every button below emits a makeover intent. The engine decides what actually changes."
	])

	var paths: Array = _safe_array(contract.get("makeover_paths", []))
	if paths.is_empty():
		_add_header_card("NO ACTIVE PATHS", [
			"No renovation paths are currently observable for this property.",
			"The surface remains alive so future contractors, room catalogs, item catalogs, and blueprint systems can plug in without changing this UI."
		])
		return

	for raw_path in paths:
		var path: Dictionary = _safe_dictionary(raw_path)
		_render_makeover_path(path, int(contract.get("property_id", -1)))


func _ensure_surface() -> void:
	if title_label != null and is_instance_valid(title_label):
		return

	name = "PropertyMakeoverPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_theme_stylebox_override("panel", _panel_style())
	set_process(true)

	var margin:= MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var root:= VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var top:= HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	root.add_child(top)

	var back:= Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(120, 42)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.add_theme_stylebox_override("normal", _makeover_button_style(Color(0.078, 0.058, 0.046, 1.0), Color(0.96, 0.72, 0.42, 0.48)))
	back.add_theme_stylebox_override("hover", _makeover_button_style(Color(0.105, 0.075, 0.055, 1.0), Color(1.0, 0.82, 0.5, 0.82), true))
	back.add_theme_stylebox_override("pressed", _makeover_button_style(Color(0.055, 0.04, 0.032, 1.0), Color(1.0, 0.72, 0.36, 0.92), false, true))
	back.add_theme_color_override("font_color", Color(1.0, 0.88, 0.62, 1.0))
	back.pressed.connect(func () -> void:
		close_requested.emit()
	)
	top.add_child(back)

	title_label = Label.new()
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.add_theme_color_override("font_color", Color(0.96, 0.82, 0.54, 1.0))
	title_label.add_theme_color_override("font_shadow_color", Color(1.0, 0.58, 0.2, 0.3))
	title_label.add_theme_constant_override("shadow_outline_size", 3)
	top.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_color_override("font_color", Color(0.92, 0.82, 0.66, 0.92))
	root.add_child(subtitle_label)

	var scroll:= ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	content_box = VBoxContainer.new()
	content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_box.add_theme_constant_override("separation", 14)
	scroll.add_child(content_box)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color(0.92, 0.78, 0.58, 0.88))
	root.add_child(status_label)


func _render_makeover_path(path: Dictionary, property_id: int) -> void:
	var contractor_profile: Dictionary = _safe_dictionary(path.get("contractor_profile", {}))
	var reputation: int = clamp(int(contractor_profile.get("reputation", 70)), 0, 100)
	var botch_risk: int = clamp(int(contractor_profile.get("botch_risk", max(5, 100 - reputation))), 0, 100)
	var risk_color: Color = _makeover_risk_color(botch_risk)
	var card_accent: Color = risk_color.lerp(Color(1.0, 0.78, 0.42, 1.0), 0.45)

	var card:= PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.add_theme_stylebox_override("panel", _makeover_card_style_for(card_accent, false, 0.0, botch_risk))
	card.set_meta("makeover_animated_card", true)
	card.set_meta("makeover_card_accent_color", card_accent)
	card.set_meta("makeover_card_hovered", false)
	card.set_meta("makeover_botch_risk", botch_risk)
	card.set_meta("makeover_card_phase_offset", float(abs(str(path.get("path_id", "")).hash()) % 1000) / 1000.0)
	_register_makeover_animated_card(card)
	content_box.add_child(card)

	var margin:= MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	card.add_child(margin)

	var box:= VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var title:= Label.new()
	title.text = "%s • Build Cost %s" % [
		str(path.get("title", "Makeover")),
		str(path.get("cost_text", "$0"))
	]
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.58, 1.0))
	title.add_theme_color_override("font_shadow_color", Color(card_accent.r, card_accent.g, card_accent.b, 0.3))
	title.add_theme_constant_override("shadow_outline_size", 2)
	box.add_child(title)

	var body:= Label.new()
	body.text = "%s\nDuration: %d days\nDisruption: %s\nProjected value gain: %s\nContractor reputation: %d%% • %s" % [
		str(path.get("description", "")),
		int(path.get("duration_days", 0)),
		str(path.get("disruption_level", "low")).capitalize(),
		str(path.get("projected_value_delta_text", "$0")),
		reputation,
		str(contractor_profile.get("reputation_label", "Mixed"))
	]
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_color_override("font_color", Color(0.94, 0.86, 0.74, 0.95))
	box.add_child(body)

	var risk_label:= Label.new()
	risk_label.text = "Botch Risk: %d%% • %s" % [botch_risk, _makeover_risk_label(botch_risk)]
	risk_label.add_theme_font_size_override("font_size", 16)
	risk_label.add_theme_color_override("font_color", risk_color)
	risk_label.add_theme_color_override("font_shadow_color", Color(risk_color.r, risk_color.g, risk_color.b, 0.35))
	risk_label.add_theme_constant_override("shadow_outline_size", 2)
	box.add_child(risk_label)

	var risk_bar:= ProgressBar.new()
	risk_bar.min_value = 0
	risk_bar.max_value = 100
	risk_bar.value = botch_risk
	risk_bar.show_percentage = false
	risk_bar.custom_minimum_size = Vector2(0, 18)
	risk_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	risk_bar.set_meta("makeover_risk_bar", true)
	risk_bar.set_meta("makeover_botch_risk", botch_risk)
	_apply_makeover_risk_bar_visual(risk_bar, botch_risk, 0.0)
	box.add_child(risk_bar)

	var grid:= GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)

	for raw_option in _safe_array(path.get("options", [])):
		var option: Dictionary = _safe_dictionary(raw_option)
		var path_id: String = str(path.get("path_id", "")).strip_edges()
		var option_action_id: String = str(option.get("action_id", "")).strip_edges()
		if path_id == "" or option_action_id == "":
			continue

		var button:= Button.new()
		button.text = str(option.get("label", "Select"))
		button.custom_minimum_size = Vector2(0, 42)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_stylebox_override("normal", _makeover_button_style(Color(0.08, 0.055, 0.042, 1.0), Color(card_accent.r, card_accent.g, card_accent.b, 0.52)))
		button.add_theme_stylebox_override("hover", _makeover_button_style(Color(0.115, 0.078, 0.052, 1.0), Color(card_accent.r, card_accent.g, card_accent.b, 0.88), true))
		button.add_theme_stylebox_override("pressed", _makeover_button_style(Color(0.055, 0.038, 0.03, 1.0), Color(card_accent.r, card_accent.g, card_accent.b, 1.0), false, true))
		button.add_theme_color_override("font_color", Color(1.0, 0.89, 0.68, 1.0))

		var payload: Dictionary = {
			"property_id": property_id,
			"path_id": path_id,
			"makeover_action": option_action_id,
			"source": "property_makeover_panel.aaa_card_button"
		}

		button.pressed.connect(func () -> void:
			makeover_action_requested.emit(path_id, option_action_id, payload.duplicate(true))
		)

		grid.add_child(button)

func _add_header_card(title: String, lines: Array) -> void:
	var body_lines: Array = []
	for raw_line in lines:
		body_lines.append(str(raw_line))
	_add_card(title, "\n".join(body_lines))


func _add_card(title: String, body: String) -> void:
	var accent: Color = Color(0.96, 0.72, 0.42, 1.0)

	var card:= PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.add_theme_stylebox_override("panel", _makeover_card_style_for(accent, false, 0.0, 0))
	card.set_meta("makeover_animated_card", true)
	card.set_meta("makeover_card_accent_color", accent)
	card.set_meta("makeover_card_hovered", false)
	card.set_meta("makeover_botch_risk", 0)
	card.set_meta("makeover_card_phase_offset", float(abs(str(title).hash()) % 1000) / 1000.0)
	_register_makeover_animated_card(card)
	content_box.add_child(card)

	var margin:= MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	card.add_child(margin)

	var box:= VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	margin.add_child(box)

	var card_title_label:= Label.new()
	card_title_label.text = title
	card_title_label.add_theme_font_size_override("font_size", 20)
	card_title_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.58, 1.0))
	card_title_label.add_theme_color_override("font_shadow_color", Color(1.0, 0.58, 0.2, 0.24))
	card_title_label.add_theme_constant_override("shadow_outline_size", 2)
	box.add_child(card_title_label)

	var body_label:= Label.new()
	body_label.text = body
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_color_override("font_color", Color(0.94, 0.86, 0.74, 0.94))
	box.add_child(body_label)

func _panel_style() -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.034, 0.03, 0.985)
	style.border_color = Color(0.96, 0.72, 0.42, 0.55)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	return style


func _card_style() -> StyleBoxFlat:
	return _makeover_card_style_for(Color(0.96, 0.72, 0.42, 1.0), false, 0.0, 0)
func _process(_delta: float) -> void:
	if not visible:
		return
	if content_box == null or not is_instance_valid(content_box):
		return

	var phase: float = float(Time.get_ticks_msec()) / 1000.0
	_animate_makeover_cards(content_box, phase)
	_animate_makeover_risk_bars(content_box, phase)


func _register_makeover_animated_card(card: PanelContainer) -> void:
	if card == null:
		return

	card.mouse_entered.connect(func () -> void:
		if card != null and is_instance_valid(card):
			card.set_meta("makeover_card_hovered", true)
	)

	card.mouse_exited.connect(func () -> void:
		if card != null and is_instance_valid(card):
			card.set_meta("makeover_card_hovered", false)
	)


func _animate_makeover_cards(node: Node, phase: float) -> void:
	if node == null:
		return

	for child in node.get_children():
		if child is PanelContainer:
			var card:= child as PanelContainer
			if bool(card.get_meta("makeover_animated_card", false)):
				var accent: Color = card.get_meta("makeover_card_accent_color", Color(0.96, 0.72, 0.42, 1.0))
				var hovered: bool = bool(card.get_meta("makeover_card_hovered", false))
				var risk: int = int(card.get_meta("makeover_botch_risk", 0))
				var offset: float = float(card.get_meta("makeover_card_phase_offset", 0.0))
				var base_pulse: float = 0.04 + (sin((phase + offset) * 2.1) * 0.035)
				var hover_pulse: float = 0.2 + (sin((phase + offset) * 5.0) * 0.055) if hovered else base_pulse
				var high_risk_pulse: float = 0.12 + (sin((phase + offset) * 7.0) * 0.08) if risk >= 80 else 0.0
				card.add_theme_stylebox_override("panel", _makeover_card_style_for(accent, hovered, max(hover_pulse, high_risk_pulse), risk))

		_animate_makeover_cards(child, phase)


func _animate_makeover_risk_bars(node: Node, phase: float) -> void:
	if node == null:
		return

	for child in node.get_children():
		if child is ProgressBar:
			var risk_bar:= child as ProgressBar
			if bool(risk_bar.get_meta("makeover_risk_bar", false)):
				var risk: int = int(risk_bar.get_meta("makeover_botch_risk", 0))
				var pulse: float = 0.0
				if risk >= 80:
					pulse = 0.18 + (sin(phase * 7.0) * 0.1)
				_apply_makeover_risk_bar_visual(risk_bar, risk, pulse)

		_animate_makeover_risk_bars(child, phase)


func _makeover_card_style_for(accent: Color, hovered: bool = false, pulse: float = 0.0, risk: int = 0) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	var warm_base: Color = Color(0.11, 0.084, 0.06, 0.965)
	var hover_base: Color = Color(0.145, 0.103, 0.07, 0.985)
	var risk_tint: Color = _makeover_risk_color(risk)

	style.bg_color = warm_base.lerp(hover_base, 0.35 + pulse if hovered else 0.0)
	if risk >= 80:
		style.bg_color = style.bg_color.lerp(Color(risk_tint.r, risk_tint.g, risk_tint.b, 1.0), 0.08 + pulse * 0.08)

	style.border_color = Color(accent.r, accent.g, accent.b, 0.48 + pulse)
	style.set_border_width_all(1 if not hovered else 2)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.18 + pulse * 0.58)
	style.shadow_size = 12 if hovered else 6
	style.shadow_offset = Vector2(0, 0)
	return style


func _makeover_button_style(bg: Color, border: Color, hovered: bool = false, pressed: bool = false) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = bg
	if hovered:
		style.bg_color = style.bg_color.lerp(Color(1.0, 0.82, 0.5, 1.0), 0.08)
	if pressed:
		style.bg_color = style.bg_color.darkened(0.14)

	style.border_color = border
	style.set_border_width_all(1 if not hovered else 2)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.shadow_color = Color(border.r, border.g, border.b, 0.18 if not hovered else 0.38)
	style.shadow_size = 3 if not hovered else 8
	style.shadow_offset = Vector2(0, 0)
	return style


func _makeover_risk_color(risk: int) -> Color:
	var safe_risk: int = clamp(int(risk), 0, 100)

	if safe_risk <= 20:
		return Color(0.035, 0.33, 0.12, 1.0)
	if safe_risk <= 40:
		return Color(0.62, 0.89, 0.26, 1.0)
	if safe_risk <= 60:
		return Color(1.0, 0.86, 0.16, 1.0)
	if safe_risk <= 80:
		return Color(1.0, 0.48, 0.08, 1.0)

	return Color(0.9, 0.03, 0.04, 1.0)


func _makeover_risk_label(risk: int) -> String:
	var safe_risk: int = clamp(int(risk), 0, 100)

	if safe_risk <= 20:
		return "Low Risk"
	if safe_risk <= 40:
		return "Low-Medium Risk"
	if safe_risk <= 60:
		return "Medium Risk"
	if safe_risk <= 80:
		return "Medium-High Risk"

	return "High Risk"


func _apply_makeover_risk_bar_visual(risk_bar: ProgressBar, risk: int, pulse: float = 0.0) -> void:
	if risk_bar == null or not is_instance_valid(risk_bar):
		return

	var safe_risk: int = clamp(int(risk), 0, 100)
	var risk_color: Color = _makeover_risk_color(safe_risk)
	if safe_risk >= 80:
		risk_color = risk_color.lerp(Color(1.0, 0.12, 0.14, 1.0), clamp(pulse, 0.0, 0.35))

	var bg:= StyleBoxFlat.new()
	bg.bg_color = Color(0.03, 0.025, 0.022, 0.92)
	bg.border_color = Color(risk_color.r, risk_color.g, risk_color.b, 0.3)
	bg.set_border_width_all(1)
	bg.corner_radius_top_left = 8
	bg.corner_radius_top_right = 8
	bg.corner_radius_bottom_left = 8
	bg.corner_radius_bottom_right = 8

	var fill:= StyleBoxFlat.new()
	fill.bg_color = risk_color
	fill.border_color = Color(risk_color.r, risk_color.g, risk_color.b, 0.82)
	fill.set_border_width_all(1)
	fill.corner_radius_top_left = 8
	fill.corner_radius_top_right = 8
	fill.corner_radius_bottom_left = 8
	fill.corner_radius_bottom_right = 8
	fill.shadow_color = Color(risk_color.r, risk_color.g, risk_color.b, 0.35 + pulse)
	fill.shadow_size = 5 if safe_risk < 80 else 9
	fill.shadow_offset = Vector2(0, 0)

	risk_bar.add_theme_stylebox_override("background", bg)
	risk_bar.add_theme_stylebox_override("fill", fill)
	risk_bar.value = safe_risk


func _clear_children(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		child.queue_free()


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []