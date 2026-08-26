extends Control
class_name ModificationPanel

signal request_close
signal request_save(
	actor_id: int,
	values: Dictionary
)
const PANEL_SCHEMA:= (
	"eralife.modification_panel"
)
const PANEL_VERSION:= 1

var active_contract: Dictionary = {}
var active_actor_id: int = -1

var dim: ColorRect = null
var card: PanelContainer = null
var title_label: Label = null
var status_label: Label = null

var first_name_edit: LineEdit = null
var last_name_edit: LineEdit = null
var bank_balance_picker: SpinBox = null

var stat_controls: Dictionary = {}
var content_scroll: ScrollContainer = null


func _ready() -> void:
	name = "ModificationPanel"
	visible = false
	mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	process_mode = (
		Node.PROCESS_MODE_INHERIT
	)
	z_as_relative = false
	z_index = 1320

	set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	set_meta(
		"schema",
		PANEL_SCHEMA
	)
	set_meta(
		"version",
		PANEL_VERSION
	)
	set_meta(
		"ui_is_renderer_only",
		true
	)
	set_meta(
		"visible_press_build_forbidden",
		true
	)

	_build_shell_once()


func open_contract(
	modification_contract: Dictionary
) -> void:
	render_contract(
		modification_contract
	)

	visible = true
	mouse_filter = (
		Control.MOUSE_FILTER_STOP
	)
	process_mode = (
		Node.PROCESS_MODE_INHERIT
	)
	z_index = 1320

	var panel_parent: Node = get_parent()

	if panel_parent != null:
		panel_parent.move_child(
			self,
			panel_parent.get_child_count() - 1
		)

	set_meta(
		"opened_at_ms",
		int(
			Time.get_ticks_msec()
		)
	)


func close_panel() -> void:
	visible = false
	mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)


func render_contract(
	modification_contract: Dictionary
) -> void:
	active_contract = (
		modification_contract.duplicate(true)
	)
	active_actor_id = int(
		active_contract.get(
			"actor_id",
			-1
		)
	)

	var snapshot: Dictionary = _safe_dictionary(
		active_contract.get(
			"snapshot",
			{}
		)
	)

	title_label.text = (
		"MODIFY • %s"
		% str(
			active_contract.get(
				"actor_name",
				snapshot.get(
					"actor_name",
					"Person"
				)
			)
		).to_upper()
	)

	first_name_edit.text = str(
		snapshot.get(
			"first_name",
			""
		)
	)
	last_name_edit.text = str(
		snapshot.get(
			"last_name",
			""
		)
	)
	bank_balance_picker.value = float(
		snapshot.get(
			"bank_balance",
			0
		)
	)

	_apply_stat_value(
		"happiness",
		float(
			snapshot.get(
				"happiness",
				0
			)
		)
	)
	_apply_stat_value(
		"health",
		float(
			snapshot.get(
				"health",
				0
			)
		)
	)
	_apply_stat_value(
		"hunger",
		float(
			snapshot.get(
				"hunger",
				100
			)
		)
	)
	_apply_stat_value(
		"smarts",
		float(
			snapshot.get(
				"smarts",
				0
			)
		)
	)
	_apply_stat_value(
		"looks",
		float(
			snapshot.get(
				"looks",
				0
			)
		)
	)
	_apply_stat_value(
		"mental_health",
		float(
			snapshot.get(
				"mental_health",
				0
			)
		)
	)
	_apply_stat_value(
		"willpower",
		float(
			snapshot.get(
				"willpower",
				0
			)
		)
	)
	_apply_stat_value(
		"imagination",
		float(
			snapshot.get(
				"imagination",
				0
			)
		)
	)
	_apply_stat_value(
		"fame",
		float(
			snapshot.get(
				"fame",
				0
			)
		)
	)
	_apply_stat_value(
		"fertility",
		float(
			snapshot.get(
				"fertility",
				0
			)
		)
	)

	status_label.text = ""
	content_scroll.scroll_vertical = 0


func set_status(
	text_value: String
) -> void:
	status_label.text = text_value


func _build_shell_once() -> void:
	dim = ColorRect.new()
	dim.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	dim.color = Color(
		0.0,
		0.0,
		0.0,
		0.82
	)
	dim.mouse_filter = (
		Control.MOUSE_FILTER_STOP
	)
	add_child(dim)

	card = PanelContainer.new()
	card.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	card.offset_left = 44
	card.offset_top = 32
	card.offset_right = -44
	card.offset_bottom = -32
	card.mouse_filter = (
		Control.MOUSE_FILTER_STOP
	)
	card.add_theme_stylebox_override(
		"panel",
		_panel_style()
	)
	add_child(card)

	var margin:= MarginContainer.new()
	margin.add_theme_constant_override(
		"margin_left",
		22
	)
	margin.add_theme_constant_override(
		"margin_right",
		22
	)
	margin.add_theme_constant_override(
		"margin_top",
		18
	)
	margin.add_theme_constant_override(
		"margin_bottom",
		18
	)
	card.add_child(margin)

	var root:= VBoxContainer.new()
	root.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	root.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	root.add_theme_constant_override(
		"separation",
		12
	)
	margin.add_child(root)

	var header:= HBoxContainer.new()
	header.add_theme_constant_override(
		"separation",
		10
	)
	root.add_child(header)

	var back_button:= Button.new()
	back_button.text = "BACK"
	back_button.custom_minimum_size = (
		Vector2(
			112,
			42
		)
	)
	_style_button(
		back_button
	)
	back_button.pressed.connect(
		func () -> void:
			close_panel()
			request_close.emit()
	)
	header.add_child(back_button)

	title_label = Label.new()
	title_label.text = "MODIFY PERSON"
	title_label.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	title_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	title_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)
	title_label.add_theme_font_size_override(
		"font_size",
		24
	)
	title_label.add_theme_color_override(
		"font_color",
		Color(
			0.88,
			0.94,
			1.0,
			1.0
		)
	)
	header.add_child(title_label)

	var save_button:= Button.new()
	save_button.text = "SAVE CHANGES"
	save_button.custom_minimum_size = (
		Vector2(
			170,
			42
		)
	)
	_style_button(
		save_button
	)
	save_button.pressed.connect(
		_on_save_pressed
	)
	header.add_child(save_button)

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
	root.add_child(content_scroll)

	var content:= VBoxContainer.new()
	content.custom_minimum_size = (
		Vector2(
			0,
			900
		)
	)
	content.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	content.add_theme_constant_override(
		"separation",
		14
	)
	content_scroll.add_child(content)

	content.add_child(
		_section_title(
			"IDENTITY"
		)
	)

	var identity_grid:= GridContainer.new()
	identity_grid.columns = 2
	identity_grid.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	identity_grid.add_theme_constant_override(
		"h_separation",
		18
	)
	identity_grid.add_theme_constant_override(
		"v_separation",
		8
	)
	content.add_child(identity_grid)

	first_name_edit = (
		_identity_field(
			identity_grid,
			"FIRST NAME"
		)
	)
	last_name_edit = (
		_identity_field(
			identity_grid,
			"LAST NAME"
		)
	)

	content.add_child(
		_section_title(
			"ECONOMY"
		)
	)

	var economy_row:= HBoxContainer.new()
	economy_row.add_theme_constant_override(
		"separation",
		12
	)
	content.add_child(economy_row)

	var bank_label:= Label.new()
	bank_label.text = "BANK BALANCE"
	bank_label.custom_minimum_size = (
		Vector2(
			190,
			40
		)
	)
	bank_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)
	economy_row.add_child(bank_label)

	bank_balance_picker = SpinBox.new()
	bank_balance_picker.min_value = 0.0
	bank_balance_picker.max_value = 5000000.0
	bank_balance_picker.step = 100.0
	bank_balance_picker.allow_greater = false
	bank_balance_picker.allow_lesser = false
	bank_balance_picker.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	economy_row.add_child(
		bank_balance_picker
	)

	content.add_child(
		_section_title(
			"PLAYER STATS"
		)
	)

	var stat_grid:= GridContainer.new()
	stat_grid.columns = 2
	stat_grid.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	stat_grid.add_theme_constant_override(
		"h_separation",
		22
	)
	stat_grid.add_theme_constant_override(
		"v_separation",
		12
	)
	content.add_child(stat_grid)

	_add_stat_control(
		stat_grid,
		"happiness",
		"HAPPINESS",
		0.0,
		100.0
	)
	_add_stat_control(
		stat_grid,
		"health",
		"HEALTH",
		0.0,
		200.0
	)
	_add_stat_control(
		stat_grid,
		"hunger",
		"HUNGER",
		0.0,
		100.0
	)
	_add_stat_control(
		stat_grid,
		"mental_health",
		"MENTAL HEALTH",
		0.0,
		100.0
	)
	_add_stat_control(
		stat_grid,
		"smarts",
		"SMARTS",
		0.0,
		100.0
	)
	_add_stat_control(
		stat_grid,
		"looks",
		"LOOKS",
		0.0,
		100.0
	)
	_add_stat_control(
		stat_grid,
		"willpower",
		"WILLPOWER",
		0.0,
		150.0
	)
	_add_stat_control(
		stat_grid,
		"imagination",
		"IMAGINATION",
		0.0,
		100.0
	)
	_add_stat_control(
		stat_grid,
		"fame",
		"FAME",
		0.0,
		100.0
	)
	_add_stat_control(
		stat_grid,
		"fertility",
		"FERTILITY",
		0.0,
		100.0
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
			0.72,
			0.88,
			1.0,
			1.0
		)
	)
	root.add_child(status_label)


func _section_title(
	text_value: String
) -> Label:
	var label:= Label.new()
	label.text = text_value
	label.add_theme_font_size_override(
		"font_size",
		18
	)
	label.add_theme_color_override(
		"font_color",
		Color(
			0.54,
			0.78,
			1.0,
			1.0
		)
	)
	return label


func _identity_field(
	parent: GridContainer,
	label_text: String
) -> LineEdit:
	var box:= VBoxContainer.new()
	box.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	box.add_theme_constant_override(
		"separation",
		5
	)
	parent.add_child(box)

	var label:= Label.new()
	label.text = label_text
	label.add_theme_font_size_override(
		"font_size",
		12
	)
	box.add_child(label)

	var edit:= LineEdit.new()
	edit.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	edit.max_length = 40
	edit.custom_minimum_size = (
		Vector2(
			0,
			40
		)
	)
	box.add_child(edit)

	return edit


func _add_stat_control(
	parent: GridContainer,
	stat_id: String,
	label_text: String,
	minimum: float,
	maximum: float
) -> void:
	var box:= VBoxContainer.new()
	box.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	box.add_theme_constant_override(
		"separation",
		5
	)
	parent.add_child(box)

	var heading:= HBoxContainer.new()
	box.add_child(heading)

	var label:= Label.new()
	label.text = label_text
	label.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	heading.add_child(label)

	var value_label:= Label.new()
	value_label.text = "0"
	value_label.custom_minimum_size = (
		Vector2(
			56,
			0
		)
	)
	value_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_RIGHT
	)
	heading.add_child(value_label)

	var slider:= HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 1.0
	slider.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	slider.value_changed.connect(
		func (next_value: float) -> void:
			value_label.text = str(
				int(
					round(
						next_value
					)
				)
			)
	)
	box.add_child(slider)

	stat_controls [stat_id] = {
		"slider": slider,
		"value_label": value_label
	}


func _apply_stat_value(
	stat_id: String,
	value: float
) -> void:
	var row_raw: Variant = (
		stat_controls.get(
			stat_id,
			{}
		)
	)

	if typeof(row_raw) != TYPE_DICTIONARY:
		return

	var row: Dictionary = (
		row_raw as Dictionary
	)
	var slider: HSlider = row.get(
		"slider",
		null
	) as HSlider
	var value_label: Label = row.get(
		"value_label",
		null
	) as Label

	if slider == null:
		return

	slider.value = clampf(
		value,
		slider.min_value,
		slider.max_value
	)

	if value_label != null:
		value_label.text = str(
			int(
				round(
					slider.value
				)
			)
		)


func _on_save_pressed() -> void:
	if active_actor_id <= 0:
		set_status(
			"No person is selected."
		)
		return

	var values: Dictionary = {
		"first_name": (
			first_name_edit.text
			.strip_edges()
		),
		"last_name": (
			last_name_edit.text
			.strip_edges()
		),
		"bank_balance": int(
			round(
				bank_balance_picker.value
			)
		)
	}

	for raw_stat_id in stat_controls.keys():
		var row_raw: Variant = (
			stat_controls.get(
				raw_stat_id,
				{}
			)
		)

		if typeof(row_raw) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = (
			row_raw as Dictionary
		)
		var slider: HSlider = row.get(
			"slider",
			null
		) as HSlider

		if slider == null:
			continue

		values [str(raw_stat_id)] = (
			slider.value
		)

	set_status(
		"Committing modification contract..."
	)

	request_save.emit(
		active_actor_id,
		values
	)


func _panel_style() -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(
		0.028,
		0.038,
		0.072,
		0.985
	)
	style.border_color = Color(
		0.38,
		0.68,
		1.0,
		0.72
	)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	style.shadow_color = Color(
		0.0,
		0.0,
		0.0,
		0.58
	)
	style.shadow_size = 16
	style.shadow_offset = Vector2(
		0,
		5
	)
	return style


func _style_button(
	button: Button
) -> void:
	var normal:= StyleBoxFlat.new()
	normal.bg_color = Color(
		0.07,
		0.13,
		0.24,
		0.96
	)
	normal.border_color = Color(
		0.38,
		0.68,
		1.0,
		0.62
	)
	normal.set_border_width_all(1)
	normal.corner_radius_top_left = 12
	normal.corner_radius_top_right = 12
	normal.corner_radius_bottom_left = 12
	normal.corner_radius_bottom_right = 12

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(
		0.12,
		0.25,
		0.46,
		0.98
	)
	hover.border_color = Color(
		0.6,
		0.82,
		1.0,
		0.92
	)

	var pressed: StyleBoxFlat = hover.duplicate()
	pressed.bg_color = Color(
		0.18,
		0.34,
		0.58,
		1.0
	)

	button.add_theme_stylebox_override(
		"normal",
		normal
	)
	button.add_theme_stylebox_override(
		"hover",
		hover
	)
	button.add_theme_stylebox_override(
		"pressed",
		pressed
	)
	button.add_theme_color_override(
		"font_color",
		Color.WHITE
	)


func _safe_dictionary(
	value: Variant
) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return (
			value as Dictionary
		).duplicate(true)

	return {}