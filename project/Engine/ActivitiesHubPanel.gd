extends PanelContainer
class_name ActivitiesHubPanel

signal closed
signal intent_requested(payload: Dictionary)

const PANEL_SCHEMA:= "eralife.activities_hub_panel"

var active_contract: Dictionary = {}
var active_actor_id: int = -1
var active_section_id: String = "all"

var shell_root: VBoxContainer
var title_label: Label
var subtitle_label: Label
var identity_name_label: Label
var identity_context_label: Label
var identity_metrics: HBoxContainer
var section_bar: HBoxContainer
var section_buttons: Dictionary = {}
var content_scroll: ScrollContainer
var activities_panel: ActivitiesPanel
var status_label: Label
var back_button: Button


func _ready() -> void:
	_ensure_surface()


func prepare_surface() -> void:
	_ensure_surface()


func open_contract(
	contract: Dictionary
) -> void:
	render_contract(
		contract
	)
	visible = true
	mouse_filter = (
		Control.MOUSE_FILTER_STOP
	)
	process_mode = (
		Node.PROCESS_MODE_INHERIT
	)


func render_contract(
	contract: Dictionary
) -> void:
	_ensure_surface()

	active_contract = contract.duplicate(true)
	active_actor_id = int(
		active_contract.get(
			"actor_id",
			-1
		)
	)
	active_section_id = str(
		active_contract.get(
			"active_section",
			"all"
		)
	).strip_edges().to_lower()

	if active_section_id == "":
		active_section_id = "all"

	title_label.text = str(
		active_contract.get(
			"title",
			"🎭 ACTIVITIES HUB"
		)
	)
	subtitle_label.text = str(
		active_contract.get(
			"subtitle",
			(
				"Immediate life actions "
				+ "organized by domain."
			)
		)
	)

	_render_identity(
		_dict(
			active_contract.get(
				"identity_overview",
				{}
			)
		)
	)
	_render_tabs(
		_array(
			active_contract.get(
				"section_tabs",
				[]
			)
		)
	)
	activities_panel.render_contract(
		active_contract,
		active_section_id
	)
	set_status(
		str(
			active_contract.get(
				"status_text",
				""
			)
		)
	)


func open_observable_contract(
	contract: Dictionary
) -> void:
	open_contract(
		contract
	)

func has_renderable_contract(
	actor_id: int = -1
) -> bool:
	if active_contract.is_empty():
		return false

	if str(
		active_contract.get(
			"schema",
			""
		)
	) != "eralife.activities_hub_contract":
		return false

	if (
		actor_id > 0
		and int(
			active_contract.get(
				"actor_id",
				-1
			)
		) != actor_id
	):
		return false

	if _array(
		active_contract.get(
			"section_tabs",
			[]
		)
	).is_empty():
		return false

	return not _dict(
		active_contract.get(
			"identity_overview",
			{}
		)
	).is_empty()


func has_hot_contract(
	actor_id: int = -1
) -> bool:
	if not has_renderable_contract(
		actor_id
	):
		return false

	return str(
		active_contract.get(
			"truth_state",
			""
		)
	).strip_edges().to_lower() in [
		"hot",
		"authoritative_hot"
	]


func set_status(
	text: String
) -> void:
	if status_label != null:
		status_label.text = str(
			text
		)


func close_panel() -> void:
	visible = false
	mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	closed.emit()


func _default_tabs() -> Array:
	var rows: Array = [{
		"id": "all",
		"label": "ALL ACTIVITIES",
		"icon": "✦"
	}]

	for category in _default_observable_categories():
		var row: Dictionary = _dict(
			category
		)
		rows.append({
			"id": str(
				row.get(
					"id",
					""
				)
			),
			"label": str(
				row.get(
					"label",
					"ACTIVITIES"
				)
			).to_upper(),
			"icon": str(
				row.get(
					"icon",
					"•"
				)
			)
		})

	return rows


func _default_observable_categories() -> Array:
	return [
		{
			"id": "featured",
			"label": "Featured",
			"icon": "✦",
			"description": (
				"High-signal actions for this life."
			),
			"actions": []
		},
		{
			"id": "markets_assets",
			"label": "Markets & Assets",
			"icon": "🏛",
			"description": (
				"Markets, property, vehicles, "
				+ "holdings, and trade."
			),
			"actions": []
		},
		{
			"id": "companions",
			"label": "Companions",
			"icon": "🐾",
			"description": (
				"Animals, pets, mounts, "
				+ "and companion markets."
			),
			"actions": []
		},
		{
			"id": "public_life",
			"label": "Public Life",
			"icon": "🌍",
			"description": (
				"Places, travel, entertainment, "
				+ "and public movement."
			),
			"actions": []
		},
		{
			"id": "school_youth",
			"label": "School & Youth",
			"icon": "🎓",
			"description": (
				"Education and age-contextual youth actions."
			),
			"actions": []
		},
		{
			"id": "supernatural",
			"label": "Supernatural",
			"icon": "✨",
			"description": (
				"Powers, artifacts, vampires, "
				+ "and mythic routes."
			),
			"actions": []
		},
		{
			"id": "miscellaneous",
			"label": "Miscellaneous",
			"icon": "◈",
			"description": (
				"Contextual actions that belong nowhere else."
			),
			"actions": []
		}
	]


func _ensure_surface() -> void:
	if (
		shell_root != null
		and is_instance_valid(
			shell_root
		)
	):
		return

	set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	z_as_relative = false
	z_index = 250
	clip_contents = true
	visible = false
	mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	add_theme_stylebox_override(
		"panel",
		_panel_style(
			"shell"
		)
	)

	var outer:= MarginContainer.new()
	outer.add_theme_constant_override(
		"margin_left",
		24
	)
	outer.add_theme_constant_override(
		"margin_top",
		20
	)
	outer.add_theme_constant_override(
		"margin_right",
		24
	)
	outer.add_theme_constant_override(
		"margin_bottom",
		20
	)
	add_child(
		outer
	)

	shell_root = VBoxContainer.new()
	shell_root.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	shell_root.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	shell_root.add_theme_constant_override(
		"separation",
		12
	)
	outer.add_child(
		shell_root
	)

	var header:= PanelContainer.new()
	header.add_theme_stylebox_override(
		"panel",
		_panel_style(
			"header"
		)
	)
	shell_root.add_child(
		header
	)

	var header_margin:= MarginContainer.new()
	header_margin.add_theme_constant_override(
		"margin_left",
		18
	)
	header_margin.add_theme_constant_override(
		"margin_top",
		14
	)
	header_margin.add_theme_constant_override(
		"margin_right",
		18
	)
	header_margin.add_theme_constant_override(
		"margin_bottom",
		14
	)
	header.add_child(
		header_margin
	)

	var header_row:= HBoxContainer.new()
	header_row.add_theme_constant_override(
		"separation",
		14
	)
	header_margin.add_child(
		header_row
	)

	var brand:= Label.new()
	brand.text = "🎭"
	brand.custom_minimum_size = Vector2(
		54,
		54
	)
	brand.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	brand.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)
	brand.add_theme_font_size_override(
		"font_size",
		29
	)
	header_row.add_child(
		brand
	)

	var title_box:= VBoxContainer.new()
	title_box.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	title_box.add_theme_constant_override(
		"separation",
		3
	)
	header_row.add_child(
		title_box
	)

	title_label = Label.new()
	title_label.add_theme_font_size_override(
		"font_size",
		28
	)
	title_label.add_theme_color_override(
		"font_color",
		Color(
			0.97,
			0.98,
			1.0,
			1.0
		)
	)
	title_box.add_child(
		title_label
	)

	subtitle_label = Label.new()
	subtitle_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	subtitle_label.add_theme_font_size_override(
		"font_size",
		14
	)
	subtitle_label.add_theme_color_override(
		"font_color",
		Color(
			0.7,
			0.79,
			0.94,
			1.0
		)
	)
	title_box.add_child(
		subtitle_label
	)

	back_button = Button.new()
	back_button.text = "← RETURN TO LIFE"
	back_button.custom_minimum_size = Vector2(
		168,
		44
	)
	back_button.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND
	)
	_apply_button_styles(
		back_button,
		false
	)
	back_button.pressed.connect(
		close_panel
	)
	header_row.add_child(
		back_button
	)

	var identity_card:= PanelContainer.new()
	identity_card.add_theme_stylebox_override(
		"panel",
		_panel_style(
			"identity"
		)
	)
	shell_root.add_child(
		identity_card
	)

	var identity_margin:= MarginContainer.new()
	identity_margin.add_theme_constant_override(
		"margin_left",
		18
	)
	identity_margin.add_theme_constant_override(
		"margin_top",
		12
	)
	identity_margin.add_theme_constant_override(
		"margin_right",
		18
	)
	identity_margin.add_theme_constant_override(
		"margin_bottom",
		12
	)
	identity_card.add_child(
		identity_margin
	)

	var identity_root:= VBoxContainer.new()
	identity_root.add_theme_constant_override(
		"separation",
		6
	)
	identity_margin.add_child(
		identity_root
	)

	identity_name_label = Label.new()
	identity_name_label.add_theme_font_size_override(
		"font_size",
		20
	)
	identity_name_label.add_theme_color_override(
		"font_color",
		Color(
			1.0,
			0.89,
			0.58,
			1.0
		)
	)
	identity_root.add_child(
		identity_name_label
	)

	identity_context_label = Label.new()
	identity_context_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	identity_context_label.add_theme_color_override(
		"font_color",
		Color(
			0.72,
			0.8,
			0.92,
			1.0
		)
	)
	identity_root.add_child(
		identity_context_label
	)

	identity_metrics = HBoxContainer.new()
	identity_metrics.add_theme_constant_override(
		"separation",
		8
	)
	identity_root.add_child(
		identity_metrics
	)

	var tab_scroll:= ScrollContainer.new()
	tab_scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_AUTO
	)
	tab_scroll.vertical_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)
	tab_scroll.custom_minimum_size = Vector2(
		0,
		50
	)
	shell_root.add_child(
		tab_scroll
	)

	section_bar = HBoxContainer.new()
	section_bar.add_theme_constant_override(
		"separation",
		8
	)
	tab_scroll.add_child(
		section_bar
	)

	content_scroll = ScrollContainer.new()
	content_scroll.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	content_scroll.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	content_scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)
	content_scroll.vertical_scroll_mode = (
		ScrollContainer.SCROLL_MODE_AUTO
	)
	shell_root.add_child(
		content_scroll
	)

	activities_panel = ActivitiesPanel.new()
	activities_panel.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	activities_panel.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	activities_panel.action_requested.connect(
		_on_action_requested
	)
	content_scroll.add_child(
		activities_panel
	)

	status_label = Label.new()
	status_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	status_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	status_label.add_theme_color_override(
		"font_color",
		Color(
			0.75,
			0.84,
			1.0,
			1.0
		)
	)
	shell_root.add_child(
		status_label
	)


func _render_identity(
	identity: Dictionary
) -> void:
	identity_name_label.text = str(
		identity.get(
			"name",
			active_contract.get(
				"actor_name",
				"Current Life"
			)
		)
	)
	identity_context_label.text = "%s  •  %s" % [
		str(
			identity.get(
				"location",
				"Current Reality"
			)
		),
		str(
			identity.get(
				"era_name",
				"Current Era"
			)
		)
	]

	_clear(
		identity_metrics
	)

	var metrics: Array = [
		{
			"label": "AGE",
			"value": str(
				identity.get(
					"age",
					0
				)
			)
		},
		{
			"label": "YEAR",
			"value": str(
				identity.get(
					"year",
					0
				)
			)
		},
		{
			"label": "SURFACE",
			"value": str(
				active_contract.get(
					"truth_state",
					"observable"
				)
			)
		}
	]

	for raw_metric in metrics:
		var metric: Dictionary = _dict(
			raw_metric
		)
		var chip:= PanelContainer.new()
		chip.size_flags_horizontal = (
			Control.SIZE_EXPAND_FILL
		)
		chip.add_theme_stylebox_override(
			"panel",
			_panel_style(
				"metric"
			)
		)
		identity_metrics.add_child(
			chip
		)

		var label:= Label.new()
		label.text = "%s  %s" % [
			str(
				metric.get(
					"label",
					"METRIC"
				)
			),
			str(
				metric.get(
					"value",
					"—"
				)
			)
		]
		label.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_CENTER
		)
		label.add_theme_font_size_override(
			"font_size",
			12
		)
		label.add_theme_color_override(
			"font_color",
			Color(
				0.88,
				0.93,
				1.0,
				1.0
			)
		)
		chip.add_child(
			label
		)


func _render_tabs(
	rows: Array
) -> void:
	_clear(
		section_bar
	)
	section_buttons.clear()

	for raw_row in rows:
		var row: Dictionary = _dict(
			raw_row
		)
		var section_id: String = str(
			row.get(
				"id",
				""
			)
		).strip_edges().to_lower()

		if section_id == "":
			continue

		var button:= Button.new()
		button.text = "%s  %s" % [
			str(
				row.get(
					"icon",
					"•"
				)
			),
			str(
				row.get(
					"label",
					section_id.to_upper()
				)
			)
		]
		button.toggle_mode = true
		button.button_pressed = (
			section_id == active_section_id
		)
		button.custom_minimum_size = Vector2(
			154,
			42
		)
		button.mouse_default_cursor_shape = (
			Control.CURSOR_POINTING_HAND
		)
		_apply_button_styles(
			button,
			section_id == active_section_id
		)
		button.pressed.connect(
			_on_section_pressed.bind(
				section_id
			)
		)

		section_bar.add_child(
			button
		)
		section_buttons [section_id] = button


func _on_section_pressed(
	section_id: String
) -> void:
	active_section_id = str(
		section_id
	).strip_edges().to_lower()

	if active_section_id == "":
		active_section_id = "all"


	active_contract ["active_section"] = (
		active_section_id
	)

	for raw_id in section_buttons.keys():
		var button: Button = section_buttons.get(
			raw_id,
			null
		) as Button

		if (
			button == null
			or not is_instance_valid(
				button
			)
		):
			continue

		var selected: bool = (
			str(
				raw_id
			) == active_section_id
		)
		button.button_pressed = selected
		_apply_button_styles(
			button,
			selected
		)

	if (
		content_scroll != null
		and is_instance_valid(
			content_scroll
		)
	):
		content_scroll.scroll_vertical = 0

	if (
		activities_panel != null
		and is_instance_valid(
			activities_panel
		)
	):
		activities_panel.reveal_section(
			active_section_id
		)



	intent_requested.emit({
		"action_id": "set_section",
		"section_id": active_section_id,
		"lens_persistence_only": true
	})
func prepare_observable_actor_shell(
	actor_id: int,
	message: String = (
		"Activities truth is publishing live."
	)
) -> void:
	_ensure_surface()

	if has_renderable_contract(
		actor_id
	):
		return

	active_contract = {}
	active_actor_id = actor_id
	active_section_id = "all"

	_render_identity(
		{}
	)
	_render_tabs(
		[]
	)
	activities_panel.render_contract(
		{
			"actor_id": actor_id,
			"categories": [],
			"section_tabs": [],
		},
		"all"
	)
	set_status(
		message
	)

	set_meta(
		"observable_actor_shell",
		true
	)
	set_meta(
		"observable_actor_shell_actor_id",
		actor_id
	)
	set_meta(
		"observable_actor_shell_truth_pending",
		true
	)
func _on_action_requested(
	payload: Dictionary
) -> void:
	var outgoing: Dictionary = payload.duplicate(true)
	outgoing ["section_id"] = active_section_id
	intent_requested.emit(
		outgoing
	)


func _apply_button_styles(
	button: Button,
	selected: bool
) -> void:
	button.add_theme_font_size_override(
		"font_size",
		12
	)
	button.add_theme_color_override(
		"font_color",
		(
			Color(
				1.0,
				0.91,
				0.62,
				1.0
			)
			if selected
			else Color(
				0.78,
				0.85,
				0.97,
				1.0
			)
		)
	)
	button.add_theme_color_override(
		"font_hover_color",
		Color(
			1.0,
			0.94,
			0.72,
			1.0
		)
	)
	button.add_theme_stylebox_override(
		"normal",
		_button_style(
			"normal",
			selected
		)
	)
	button.add_theme_stylebox_override(
		"hover",
		_button_style(
			"hover",
			selected
		)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_button_style(
			"pressed",
			true
		)
	)
	button.add_theme_stylebox_override(
		"focus",
		_button_style(
			"hover",
			selected
		)
	)


func _panel_style(
	kind: String
) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()

	match kind:
		"shell":
			style.bg_color = Color(
				0.014,
				0.019,
				0.036,
				0.995
			)
			style.border_color = Color(
				0.78,
				0.5,
				0.18,
				0.8
			)
			style.shadow_color = Color(
				0.32,
				0.18,
				0.04,
				0.42
			)
			style.shadow_size = 22
			style.set_corner_radius_all(
				22
			)
			style.set_border_width_all(
				2
			)

		"header":
			style.bg_color = Color(
				0.036,
				0.05,
				0.088,
				0.98
			)
			style.border_color = Color(
				0.38,
				0.57,
				0.92,
				0.58
			)
			style.shadow_size = 12
			style.set_corner_radius_all(
				16
			)
			style.set_border_width_all(
				1
			)

		"identity":
			style.bg_color = Color(
				0.052,
				0.061,
				0.096,
				0.98
			)
			style.border_color = Color(
				0.96,
				0.68,
				0.28,
				0.56
			)
			style.set_corner_radius_all(
				15
			)
			style.set_border_width_all(
				1
			)

		_:
			style.bg_color = Color(
				0.045,
				0.058,
				0.094,
				0.98
			)
			style.border_color = Color(
				0.25,
				0.39,
				0.66,
				0.58
			)
			style.set_corner_radius_all(
				10
			)
			style.set_border_width_all(
				1
			)
			style.content_margin_left = 8.0
			style.content_margin_right = 8.0
			style.content_margin_top = 6.0
			style.content_margin_bottom = 6.0

	return style


func _button_style(
	state: String,
	selected: bool
) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()

	if selected:
		style.bg_color = Color(
			0.15,
			0.27,
			0.5,
			0.98
		)
		style.border_color = Color(
			1.0,
			0.78,
			0.34,
			0.92
		)
		style.shadow_color = Color(
			0.35,
			0.56,
			1.0,
			0.28
		)
		style.shadow_size = 9

	elif state == "hover":
		style.bg_color = Color(
			0.1,
			0.18,
			0.34,
			0.98
		)
		style.border_color = Color(
			0.52,
			0.72,
			1.0,
			0.84
		)

	else:
		style.bg_color = Color(
			0.055,
			0.079,
			0.132,
			0.98
		)
		style.border_color = Color(
			0.28,
			0.43,
			0.7,
			0.66
		)

	style.set_border_width_all(
		1
	)
	style.set_corner_radius_all(
		11
	)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0

	return style


func _clear(
	parent: Node
) -> void:
	if parent == null:
		return

	for child in parent.get_children():
		parent.remove_child(
			child
		)
		child.queue_free()


func _dict(
	value: Variant
) -> Dictionary:
	if typeof(
		value
	) == TYPE_DICTIONARY:
		return (
			value as Dictionary
		).duplicate(true)

	return {}


func _array(
	value: Variant
) -> Array:
	if typeof(
		value
	) == TYPE_ARRAY:
		return (
			value as Array
		).duplicate(true)

	return []