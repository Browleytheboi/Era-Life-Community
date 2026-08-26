extends VBoxContainer
class_name ActivitiesPanel

signal action_requested(payload: Dictionary)

var active_contract: Dictionary = {}
var active_section: String = "all"
var shell_root: VBoxContainer
var grid: GridContainer
var empty_label: Label



var category_card_deck: Dictionary = {}
var rendered_surface_revision: String = ""
var rendered_actor_id: int = -1


func _ready() -> void:
	_ensure_surface()


func render_contract(
	contract: Dictionary,
	section_id: String = "all"
) -> void:
	_ensure_surface()

	var incoming_actor_id: int = int(
		contract.get(
			"actor_id",
			-1
		)
	)
	var incoming_revision: String = str(
		contract.get(
			"surface_revision",
			""
		)
	).strip_edges()
	var may_reuse_deck: bool = (
		incoming_revision != ""
		and incoming_revision == rendered_surface_revision
		and incoming_actor_id == rendered_actor_id
		and not category_card_deck.is_empty()
	)

	active_contract = contract.duplicate(true)
	active_section = _section(
		section_id
	)

	if not may_reuse_deck:
		rendered_surface_revision = incoming_revision
		rendered_actor_id = incoming_actor_id
		_render_categories()
		return

	reveal_section(
		active_section
	)


func _ensure_surface() -> void:
	if (
		grid != null
		and is_instance_valid(
			grid
		)
	):
		return

	size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	add_theme_constant_override(
		"separation",
		12
	)

	grid = GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	grid.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	grid.add_theme_constant_override(
		"h_separation",
		12
	)
	grid.add_theme_constant_override(
		"v_separation",
		12
	)
	add_child(
		grid
	)

	empty_label = Label.new()
	empty_label.visible = false
	empty_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	empty_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)
	empty_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	empty_label.custom_minimum_size = Vector2(
		0,
		180
	)
	empty_label.add_theme_font_size_override(
		"font_size",
		16
	)
	empty_label.add_theme_color_override(
		"font_color",
		Color(
			0.72,
			0.8,
			0.94,
			1.0
		)
	)
	add_child(
		empty_label
	)


func _render_categories() -> void:
	_clear(
		grid
	)
	category_card_deck.clear()
	empty_label.visible = false

	for raw_category in _array(
		active_contract.get(
			"category_rows",
			[]
		)
	):
		var category: Dictionary = _dict(
			raw_category
		)
		var category_id: String = str(
			category.get(
				"id",
				""
			)
		).strip_edges().to_lower()

		if category_id == "":
			continue

		_render_category_card(
			category
		)

	reveal_section(
		active_section
	)
func reveal_section(
	section_id: String
) -> void:
	active_section = _section(
		section_id
	)

	var visible_count: int = 0

	for raw_category_id in category_card_deck.keys():
		var category_id: String = str(
			raw_category_id
		).strip_edges().to_lower()
		var card: Control = category_card_deck.get(
			raw_category_id,
			null
		) as Control

		if (
			card == null
			or not is_instance_valid(
				card
			)
		):
			continue

		var should_reveal: bool = (
			active_section == "all"
			or category_id == active_section
		)
		card.visible = should_reveal
		card.mouse_filter = (
			Control.MOUSE_FILTER_PASS
			if should_reveal
			else Control.MOUSE_FILTER_IGNORE
		)

		if should_reveal:
			visible_count += 1

	empty_label.text = (
		"No activities are observable in "
		+ "this category right now."
	)
	empty_label.visible = (
		visible_count == 0
	)


func _render_category_card(
	category: Dictionary
) -> void:
	var category_id: String = str(
		category.get(
			"id",
			""
		)
	).strip_edges().to_lower()

	if category_id == "":
		return

	var card:= PanelContainer.new()
	card.name = "ActivityCategory_%s" % (
		category_id
	)
	card.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	card.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	card.add_theme_stylebox_override(
		"panel",
		_panel_style(
			"card"
		)
	)
	grid.add_child(
		card
	)
	category_card_deck [category_id] = card

	var margin:= MarginContainer.new()
	margin.add_theme_constant_override(
		"margin_left",
		15
	)
	margin.add_theme_constant_override(
		"margin_top",
		14
	)
	margin.add_theme_constant_override(
		"margin_right",
		15
	)
	margin.add_theme_constant_override(
		"margin_bottom",
		14
	)
	card.add_child(
		margin
	)

	var root:= VBoxContainer.new()
	root.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	root.add_theme_constant_override(
		"separation",
		8
	)
	margin.add_child(
		root
	)

	var title:= Label.new()
	title.text = "%s  %s" % [
		str(
			category.get(
				"icon",
				"•"
			)
		),
		str(
			category.get(
				"label",
				"Activities"
			)
		).to_upper()
	]
	title.add_theme_font_size_override(
		"font_size",
		17
	)
	title.add_theme_color_override(
		"font_color",
		Color(
			1.0,
			0.88,
			0.58,
			1.0
		)
	)
	root.add_child(
		title
	)

	var description:= Label.new()
	description.text = str(
		category.get(
			"description",
			""
		)
	)
	description.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	description.add_theme_font_size_override(
		"font_size",
		12
	)
	description.add_theme_color_override(
		"font_color",
		Color(
			0.69,
			0.77,
			0.91,
			1.0
		)
	)
	root.add_child(
		description
	)

	var separator:= HSeparator.new()
	separator.modulate = Color(
		0.42,
		0.58,
		0.88,
		0.3
	)
	root.add_child(
		separator
	)

	var actions: Array = _array(
		category.get(
			"actions",
			[]
		)
	)

	if actions.is_empty():
		var resolving:= Label.new()
		resolving.text = (
			"No current actions in this category."
		)
		resolving.autowrap_mode = (
			TextServer.AUTOWRAP_WORD_SMART
		)
		resolving.add_theme_color_override(
			"font_color",
			Color(
				0.62,
				0.7,
				0.84,
				1.0
			)
		)
		root.add_child(
			resolving
		)
		return

	for raw_action in actions:
		_render_action_button(
			root,
			_dict(
				raw_action
			)
		)


func _render_action_button(
	parent: VBoxContainer,
	action: Dictionary
) -> void:
	var button:= Button.new()
	button.text = "%s  %s" % [
		str(
			action.get(
				"icon",
				"▶"
			)
		),
		str(
			action.get(
				"label",
				"Activity"
			)
		)
	]
	button.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	button.custom_minimum_size = Vector2(
		0,
		46
	)
	button.disabled = not bool(
		action.get(
			"enabled",
			true
		)
	)
	button.tooltip_text = str(
		action.get(
			"disabled_reason",
			action.get(
				"description",
				""
			)
		)
	)
	button.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND
	)
	button.add_theme_font_size_override(
		"font_size",
		13
	)
	button.add_theme_color_override(
		"font_color",
		Color(
			0.92,
			0.96,
			1.0,
			1.0
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
	button.add_theme_color_override(
		"font_disabled_color",
		Color(
			0.5,
			0.57,
			0.69,
			0.78
		)
	)
	button.add_theme_stylebox_override(
		"normal",
		_button_style(
			"normal"
		)
	)
	button.add_theme_stylebox_override(
		"hover",
		_button_style(
			"hover"
		)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_button_style(
			"pressed"
		)
	)
	button.add_theme_stylebox_override(
		"focus",
		_button_style(
			"hover"
		)
	)
	button.add_theme_stylebox_override(
		"disabled",
		_button_style(
			"disabled"
		)
	)

	var payload: Dictionary = action.duplicate(true)
	payload ["action_id"] = str(
		payload.get(
			"action_id",
			"perform_activity"
		)
	)
	button.pressed.connect(
		_emit_action.bind(
			payload
		)
	)
	parent.add_child(
		button
	)


func _emit_action(
	payload: Dictionary
) -> void:
	action_requested.emit(
		payload.duplicate(true)
	)


func _panel_style(
	_kind: String
) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(
		0.036,
		0.048,
		0.082,
		0.98
	)
	style.border_color = Color(
		0.35,
		0.52,
		0.83,
		0.56
	)
	style.shadow_color = Color(
		0.03,
		0.08,
		0.2,
		0.28
	)
	style.shadow_size = 10
	style.set_border_width_all(
		1
	)
	style.set_corner_radius_all(
		15
	)

	return style


func _button_style(
	state: String
) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()

	match state:
		"hover":
			style.bg_color = Color(
				0.11,
				0.2,
				0.37,
				0.98
			)
			style.border_color = Color(
				0.52,
				0.74,
				1.0,
				0.86
			)
			style.shadow_color = Color(
				0.18,
				0.4,
				0.92,
				0.24
			)
			style.shadow_size = 8

		"pressed":
			style.bg_color = Color(
				0.16,
				0.29,
				0.52,
				1.0
			)
			style.border_color = Color(
				1.0,
				0.8,
				0.38,
				0.9
			)

		"disabled":
			style.bg_color = Color(
				0.035,
				0.043,
				0.062,
				0.8
			)
			style.border_color = Color(
				0.18,
				0.23,
				0.32,
				0.56
			)

		_:
			style.bg_color = Color(
				0.055,
				0.078,
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
		10
	)
	style.content_margin_left = 11.0
	style.content_margin_right = 11.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0

	return style


func _section(
	value: String
) -> String:
	var clean: String = str(
		value
	).strip_edges().to_lower()

	if clean == "" or clean == "all":
		return "all"



	if category_card_deck.has(
		clean
	):
		return clean





	for raw_category in _array(
		active_contract.get(
			"category_rows",
			[]
		)
	):
		var category: Dictionary = _dict(
			raw_category
		)
		var category_id: String = str(
			category.get(
				"id",
				""
			)
		).strip_edges().to_lower()

		if category_id == clean:
			return clean

	return "all"


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