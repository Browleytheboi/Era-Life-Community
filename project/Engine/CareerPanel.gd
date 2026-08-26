extends PanelContainer
class_name CareerPanel

signal request_intent(payload: Dictionary)
signal request_close()
signal request_coworker_profile(target_id: int)

const PANEL_SCHEMA:= "eralife.career_panel_contract"

var active_contract: Dictionary = {}
var active_actor_id: int = -1
var active_section_id: String = "overview"

var shell_root: VBoxContainer
var header_row: HBoxContainer
var title_label: Label
var subtitle_label: Label
var close_button: Button
var section_scroll: ScrollContainer
var section_bar: HBoxContainer
var section_buttons: Dictionary = {}
var content_scroll: ScrollContainer
var content_root: VBoxContainer
var status_label: Label


func _ready() -> void:
	_ensure_surface()

	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func open_contract(
	contract: Dictionary
) -> void:
	_ensure_surface()
	render_contract(
		contract
	)

	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_INHERIT


func close_panel() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	request_close.emit()


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
			"overview"
		)
	).strip_edges().to_lower()

	if active_section_id == "":
		active_section_id = "overview"

	title_label.text = str(
		active_contract.get(
			"title",
			"CAREER ECOSYSTEM"
		)
	)
	subtitle_label.text = str(
		active_contract.get(
			"subtitle",
			"Professional reality is observable."
		)
	)

	_set_status(
		str(
			active_contract.get(
				"status_text",
				""
			)
		)
	)
	_render_section_tabs(
		_safe_array(
			active_contract.get(
				"section_tabs",
				[]
			)
		)
	)
	_render_active_section()


func open_observable_partial(
	actor_id: int,
	actor_name: String,
	status_text: String = (
		"Career truth is resolving…"
	)
) -> void:
	open_contract({
		"success": true,
		"schema": PANEL_SCHEMA,
		"version": 1,
		"actor_id": actor_id,
		"actor_name": actor_name,
		"title": "CAREER ECOSYSTEM",
		"subtitle": (
			"The professional world exists and is becoming observable."
		),
		"active_section": "overview",
		"section_tabs": [
			{
				"id": "overview",
				"label": "OVERVIEW"
			},
			{
				"id": "activities",
				"label": "WORK"
			},
			{
				"id": "opportunities",
				"label": "OPPORTUNITIES"
			},
			{
				"id": "organization",
				"label": "ORGANIZATION"
			},
			{
				"id": "education",
				"label": "EDUCATION"
			},
			{
				"id": "reputation",
				"label": "REPUTATION"
			},
			{
				"id": "legacy",
				"label": "LEGACY"
			}
		],
		"overview_cards": [
			{
				"title": "Career Reality",
				"lines": [
					"Institutional truth is resolving.",
					(
						"This surface will hydrate without another click."
					)
				]
			}
		],
		"activity_rows": [],
		"opportunity_rows": [],
		"organization_rows": [],
		"education_rows": [],
		"reputation_rows": [],
		"legacy_rows": [],
		"actions": [],
		"status_text": status_text,
		"truth_state": "observable_partial",
		"ui_is_renderer_only": true
	})


func set_status(
	text: String
) -> void:
	_set_status(text)


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
	z_index = 230

	var panel_style:= StyleBoxFlat.new()
	panel_style.bg_color = Color(
		0.035,
		0.04,
		0.055,
		0.985
	)
	panel_style.border_color = Color(
		0.36,
		0.48,
		0.72,
		0.95
	)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(18)
	panel_style.content_margin_left = 22.0
	panel_style.content_margin_right = 22.0
	panel_style.content_margin_top = 18.0
	panel_style.content_margin_bottom = 18.0

	add_theme_stylebox_override(
		"panel",
		panel_style
	)

	shell_root = VBoxContainer.new()
	shell_root.name = "CareerPanelRoot"
	shell_root.add_theme_constant_override(
		"separation",
		12
	)
	add_child(shell_root)

	header_row = HBoxContainer.new()
	header_row.add_theme_constant_override(
		"separation",
		12
	)
	shell_root.add_child(
		header_row
	)

	var title_box:= VBoxContainer.new()
	title_box.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	title_box.add_theme_constant_override(
		"separation",
		2
	)
	header_row.add_child(
		title_box
	)

	title_label = Label.new()
	title_label.text = "CAREER ECOSYSTEM"
	title_label.add_theme_font_size_override(
		"font_size",
		25
	)
	title_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	title_box.add_child(
		title_label
	)

	subtitle_label = Label.new()
	subtitle_label.text = (
		"Professional reality is observable."
	)
	subtitle_label.add_theme_font_size_override(
		"font_size",
		14
	)
	subtitle_label.modulate = Color(
		0.78,
		0.82,
		0.9,
		1.0
	)
	subtitle_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	title_box.add_child(
		subtitle_label
	)

	close_button = Button.new()
	close_button.text = "BACK"
	close_button.custom_minimum_size = Vector2(
		110,
		42
	)
	close_button.pressed.connect(
		close_panel
	)
	header_row.add_child(
		close_button
	)

	section_scroll = ScrollContainer.new()
	section_scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_AUTO
	)
	section_scroll.vertical_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)
	section_scroll.custom_minimum_size = Vector2(
		0,
		48
	)
	shell_root.add_child(
		section_scroll
	)

	section_bar = HBoxContainer.new()
	section_bar.add_theme_constant_override(
		"separation",
		8
	)
	section_scroll.add_child(
		section_bar
	)

	content_scroll = ScrollContainer.new()
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

	content_root = VBoxContainer.new()
	content_root.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	content_root.add_theme_constant_override(
		"separation",
		12
	)
	content_scroll.add_child(
		content_root
	)

	status_label = Label.new()
	status_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	status_label.add_theme_font_size_override(
		"font_size",
		13
	)
	status_label.modulate = Color(
		0.82,
		0.86,
		0.96,
		1.0
	)
	shell_root.add_child(
		status_label
	)


func _render_section_tabs(
	rows: Array
) -> void:
	_clear_children(
		section_bar
	)
	section_buttons.clear()

	for raw_row in rows:
		var row: Dictionary = _safe_dictionary(
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
		button.text = str(
			row.get(
				"label",
				section_id.to_upper()
			)
		)
		button.toggle_mode = true
		button.button_pressed = (
			section_id == active_section_id
		)
		button.custom_minimum_size = Vector2(
			132,
			40
		)
		button.pressed.connect(
			_on_section_pressed.bind(
				section_id
			)
		)

		section_bar.add_child(
			button
		)
		section_buttons [
			section_id
		] = button


func _render_active_section() -> void:
	_clear_children(
		content_root
	)

	match active_section_id:
		"overview":
			_render_cards(
				_safe_array(
					active_contract.get(
						"overview_cards",
						[]
					)
				)
			)
			_render_global_actions()

		"activities":
			_add_section_header(
				"RESPONSIBILITIES & DAILY ACTIVITIES"
			)
			_render_activity_rows(
				_safe_array(
					active_contract.get(
						"activity_rows",
						[]
					)
				)
			)

		"opportunities":
			_add_section_header(
				"OPEN POSITIONS"
			)
			_render_opportunity_rows(
				_safe_array(
					active_contract.get(
						"opportunity_rows",
						[]
					)
				)
			)

		"organization":
			_add_section_header(
				"INSTITUTIONAL STRUCTURE"
			)
			_render_generic_rows(
				_safe_array(
					active_contract.get(
						"organization_rows",
						[]
					)
				)
			)
			_render_global_actions()

		"education":
			_add_section_header(
				"EDUCATION & CREDENTIALS"
			)
			_render_generic_rows(
				_safe_array(
					active_contract.get(
						"education_rows",
						[]
					)
				)
			)

		"reputation":
			_add_section_header(
				"PROFESSIONAL REPUTATION"
			)
			_render_metric_rows(
				_safe_array(
					active_contract.get(
						"reputation_rows",
						[]
					)
				)
			)

		"legacy":
			_add_section_header(
				"PROFESSIONAL LEGACY"
			)
			_render_generic_rows(
				_safe_array(
					active_contract.get(
						"legacy_rows",
						[]
					)
				)
			)

		_:
			_add_empty_state(
				"No career section is observable."
			)
func _render_activity_rows(
	rows: Array
) -> void:
	if rows.is_empty():
		_add_empty_state(
			"No professional activities are available for the current assignment."
		)
		return

	for raw_row in rows:
		var row: Dictionary = _safe_dictionary(
			raw_row
		)
		var card:= _new_card()
		content_root.add_child(card)

		var root:= VBoxContainer.new()
		root.add_theme_constant_override(
			"separation",
			7
		)
		card.add_child(root)

		_add_card_title(
			root,
			str(
				row.get(
					"label",
					"Professional Activity"
				)
			)
		)
		_add_body_label(
			root,
			str(
				row.get(
					"description",
					""
				)
			)
		)

		for raw_line in _safe_array(
			row.get(
				"impact_lines",
				[]
			)
		):
			_add_secondary_label(
				root,
				str(raw_line)
			)

		var action:= Button.new()
		action.text = str(
			row.get(
				"action_label",
				"PERFORM"
			)
		)
		action.disabled = not bool(
			row.get(
				"enabled",
				true
			)
		)
		action.custom_minimum_size = Vector2(
			0,
			44
		)
		action.pressed.connect(
			_emit_intent.bind({
				"action_id": "perform_activity",
				"activity_id": str(
					row.get(
						"activity_id",
						""
					)
				),
				"section_id": "activities"
			})
		)
		root.add_child(action)


func _render_opportunity_rows(
	rows: Array
) -> void:
	if rows.is_empty():
		_add_empty_state(
			(
				"There are no open positions matching this life right now. "
				+ "Vacancies can appear when workers retire, die, quit, "
				+ "transfer, or organizations expand."
			)
		)
		return

	for raw_row in rows:
		var row: Dictionary = _safe_dictionary(
			raw_row
		)
		var card:= _new_card()
		content_root.add_child(card)

		var root:= VBoxContainer.new()
		root.add_theme_constant_override(
			"separation",
			7
		)
		card.add_child(root)

		_add_card_title(
			root,
			str(
				row.get(
					"title",
					"Open Position"
				)
			)
		)
		_add_body_label(
			root,
			"%s • %s"
			% [
				str(
					row.get(
						"organization_name",
						"Institution"
					)
				),
				str(
					row.get(
						"department_name",
						"Department"
					)
				)
			]
		)
		_add_secondary_label(
			root,
			str(
				row.get(
					"career_name",
					"Career Path"
				)
			)
		)

		for raw_line in _safe_array(
			row.get(
				"requirement_lines",
				[]
			)
		):
			_add_secondary_label(
				root,
				str(raw_line)
			)

		var button:= Button.new()
		var eligible: bool = bool(
			row.get(
				"eligible",
				false
			)
		)
		button.text = (
			"APPLY"
			if eligible
			else "REQUIREMENTS NOT MET"
		)
		button.disabled = not eligible
		button.custom_minimum_size = Vector2(
			0,
			44
		)
		button.pressed.connect(
			_emit_intent.bind({
				"action_id": "apply_position",
				"position_id": str(
					row.get(
						"position_id",
						""
					)
				),
				"section_id": "opportunities"
			})
		)
		root.add_child(button)


func _on_section_pressed(
	section_id: String
) -> void:
	active_section_id = section_id

	for raw_id in section_buttons.keys():
		var button: Button = section_buttons.get(
			raw_id,
			null
		)

		if button != null:
			button.button_pressed = (
				str(raw_id) == section_id
			)

	_emit_intent({
		"action_id": "set_section",
		"section_id": section_id
	})


func _emit_intent(
	payload: Dictionary
) -> void:
	var envelope: Dictionary = payload.duplicate(
		true
	)
	envelope ["actor_id"] = active_actor_id
	envelope ["surface_id"] = "career_panel"
	envelope [
		"ui_is_expression_only"
	] = true

	request_intent.emit(
		envelope
	)
func _set_status(
	text: String
) -> void:
	if (
		status_label == null
		or not is_instance_valid(
			status_label
		)
	):
		return

	var clean_text: String = str(
		text
	).strip_edges()

	status_label.text = clean_text
	status_label.visible = clean_text != ""


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)


func _clear_children(
	parent: Node
) -> void:
	if (
		parent == null
		or not is_instance_valid(
			parent
		)
	):
		return

	for child in parent.get_children():
		parent.remove_child(
			child
		)
		child.queue_free()


func _new_card() -> PanelContainer:
	var card:= PanelContainer.new()
	card.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	var style:= StyleBoxFlat.new()
	style.bg_color = Color(
		0.065,
		0.075,
		0.1,
		0.97
	)
	style.border_color = Color(
		0.25,
		0.34,
		0.52,
		0.88
	)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0

	card.add_theme_stylebox_override(
		"panel",
		style
	)

	return card


func _add_section_header(
	text: String
) -> void:
	var label:= Label.new()
	label.text = str(
		text
	).strip_edges()
	label.add_theme_font_size_override(
		"font_size",
		18
	)
	label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	label.modulate = Color(
		0.91,
		0.94,
		1.0,
		1.0
	)

	content_root.add_child(
		label
	)


func _add_card_title(
	parent: VBoxContainer,
	text: String
) -> void:
	if parent == null:
		return

	var label:= Label.new()
	label.text = str(
		text
	).strip_edges()
	label.add_theme_font_size_override(
		"font_size",
		17
	)
	label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	label.modulate = Color(
		0.94,
		0.96,
		1.0,
		1.0
	)

	parent.add_child(
		label
	)


func _add_body_label(
	parent: VBoxContainer,
	text: String
) -> void:
	if parent == null:
		return

	var clean_text: String = str(
		text
	).strip_edges()

	if clean_text == "":
		return

	var label:= Label.new()
	label.text = clean_text
	label.add_theme_font_size_override(
		"font_size",
		14
	)
	label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	label.modulate = Color(
		0.82,
		0.86,
		0.94,
		1.0
	)

	parent.add_child(
		label
	)


func _add_secondary_label(
	parent: VBoxContainer,
	text: String
) -> void:
	if parent == null:
		return

	var clean_text: String = str(
		text
	).strip_edges()

	if clean_text == "":
		return

	var label:= Label.new()
	label.text = clean_text
	label.add_theme_font_size_override(
		"font_size",
		13
	)
	label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	label.modulate = Color(
		0.7,
		0.76,
		0.87,
		1.0
	)

	parent.add_child(
		label
	)


func _add_empty_state(
	text: String
) -> void:
	var card: PanelContainer = _new_card()

	content_root.add_child(
		card
	)

	var root:= VBoxContainer.new()
	root.add_theme_constant_override(
		"separation",
		6
	)
	card.add_child(
		root
	)

	_add_body_label(
		root,
		text
	)


func _render_cards(
	rows: Array
) -> void:
	if rows.is_empty():
		_add_empty_state(
			"No career overview is observable yet."
		)
		return

	for raw_row in rows:
		var row: Dictionary = _safe_dictionary(
			raw_row
		)

		if row.is_empty():
			continue

		var card: PanelContainer = _new_card()

		content_root.add_child(
			card
		)

		var root:= VBoxContainer.new()
		root.add_theme_constant_override(
			"separation",
			7
		)
		card.add_child(
			root
		)

		_add_card_title(
			root,
			str(
				row.get(
					"title",
					row.get(
						"label",
						"Career"
					)
				)
			)
		)
		_add_body_label(
			root,
			str(
				row.get(
					"description",
					row.get(
						"text",
						""
					)
				)
			)
		)

		for raw_line in _safe_array(
			row.get(
				"lines",
				[]
			)
		):
			_add_secondary_label(
				root,
				str(raw_line)
			)


func _render_generic_rows(
	rows: Array
) -> void:
	if rows.is_empty():
		_add_empty_state(
			"No information is observable in this section."
		)
		return

	for raw_row in rows:
		var row: Dictionary = _safe_dictionary(
			raw_row
		)

		if row.is_empty():
			continue

		var card: PanelContainer = _new_card()

		content_root.add_child(
			card
		)

		var root:= VBoxContainer.new()
		root.add_theme_constant_override(
			"separation",
			7
		)
		card.add_child(
			root
		)

		_add_card_title(
			root,
			str(
				row.get(
					"title",
					row.get(
						"label",
						row.get(
							"name",
							"Career Detail"
						)
					)
				)
			)
		)
		_add_body_label(
			root,
			str(
				row.get(
					"description",
					row.get(
						"text",
						row.get(
							"subtitle",
							""
						)
					)
				)
			)
		)

		for raw_line in _safe_array(
			row.get(
				"lines",
				[]
			)
		):
			_add_secondary_label(
				root,
				str(raw_line)
			)

		var target_id: int = int(
			row.get(
				"target_id",
				-1
			)
		)

		if target_id > 0:
			var profile_button:= Button.new()
			profile_button.text = str(
				row.get(
					"profile_label",
					"VIEW PROFILE"
				)
			)
			profile_button.custom_minimum_size = Vector2(
				0,
				40
			)
			profile_button.pressed.connect(
				_emit_coworker_profile.bind(
					target_id
				)
			)

			root.add_child(
				profile_button
			)


func _render_metric_rows(
	rows: Array
) -> void:
	if rows.is_empty():
		_add_empty_state(
			"No professional reputation has been established."
		)
		return

	for raw_row in rows:
		var row: Dictionary = _safe_dictionary(
			raw_row
		)

		if row.is_empty():
			continue

		var card: PanelContainer = _new_card()

		content_root.add_child(
			card
		)

		var root:= VBoxContainer.new()
		root.add_theme_constant_override(
			"separation",
			6
		)
		card.add_child(
			root
		)

		var max_value: float = maxf(
			1.0,
			float(
				row.get(
					"max_value",
					100.0
				)
			)
		)
		var value: float = clampf(
			float(
				row.get(
					"value",
					0.0
				)
			),
			0.0,
			max_value
		)

		_add_card_title(
			root,
			"%s — %d"
			% [
				str(
					row.get(
						"label",
						row.get(
							"title",
							"Metric"
						)
					)
				),
				int(
					round(
						value
					)
				)
			]
		)
		_add_body_label(
			root,
			str(
				row.get(
					"description",
					""
				)
			)
		)

		var bar:= ProgressBar.new()
		bar.min_value = 0.0
		bar.max_value = max_value
		bar.value = value
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(
			0,
			16
		)

		root.add_child(
			bar
		)


func _render_global_actions() -> void:
	var rows: Array = _safe_array(
		active_contract.get(
			"actions",
			[]
		)
	)

	if rows.is_empty():
		return

	_add_section_header(
		"CAREER ACTIONS"
	)

	for raw_row in rows:
		var row: Dictionary = _safe_dictionary(
			raw_row
		)
		var action_id: String = str(
			row.get(
				"action_id",
				row.get(
					"id",
					""
				)
			)
		).strip_edges()

		if action_id == "":
			continue

		var button:= Button.new()
		button.text = str(
			row.get(
				"label",
				action_id.replace(
					"_",
					" "
				).to_upper()
			)
		)
		button.disabled = not bool(
			row.get(
				"enabled",
				true
			)
		)
		button.tooltip_text = str(
			row.get(
				"disabled_reason",
				row.get(
					"description",
					""
				)
			)
		)
		button.custom_minimum_size = Vector2(
			0,
			44
		)

		var payload: Dictionary = _safe_dictionary(
			row.get(
				"payload",
				{}
			)
		)
		payload ["action_id"] = action_id
		payload ["section_id"] = str(
			row.get(
				"section_id",
				active_section_id
			)
		)

		button.pressed.connect(
			_emit_intent.bind(
				payload
			)
		)

		content_root.add_child(
			button
		)


func _emit_coworker_profile(
	target_id: int
) -> void:
	if target_id <= 0:
		return

	request_coworker_profile.emit(
		target_id
	)