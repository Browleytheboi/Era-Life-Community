extends InstitutionHubPanelBase
class_name SchoolHubPanel

signal communal_presence_observed(payload: Dictionary)

var communal_visible_seconds: float = 0.0
var communal_observation_accumulator: float = 0.0
var communal_observation_interval: float = 1.0
var communal_surface_revision: String = ""


func _init() -> void:
	panel_kind = "school"


func render_contract(contract: Dictionary) -> void:
	super.render_contract(contract)

	communal_surface_revision = str(active_contract.get("surface_revision", ""))

	if active_section_id != "meal":
		_reset_communal_observation_clock()


func hide_surface() -> void:
	super.hide_surface()
	_reset_communal_observation_clock()

func _render_row_into(
	root: VBoxContainer,
	row: Dictionary
) -> void:
	var row_kind: String = str(
		row.get(
			"row_kind",
			"information"
		)
	).strip_edges().to_lower()

	match row_kind:
		"higher_learning_programs":
			_render_higher_learning_programs_into(
				root,
				row
			)
			return

		"school_cliques":
			_render_school_cliques_into(
				root,
				row
			)
			return

	super._render_row_into(
		root,
		row
	)
func _render_higher_learning_programs_into(
	root: VBoxContainer,
	row: Dictionary
) -> void:
	_add_section_heading_to(
		root,
		str(
			row.get(
				"title",
				"HIGHER LEARNING"
			)
		),
		str(
			row.get(
				"subtitle",
				"Pick a program to study."
			)
		)
	)

	var institutions_raw: Variant = row.get(
		"institutions",
		[]
	)
	var institutions: Array = (
		institutions_raw as Array
		if typeof(institutions_raw) == TYPE_ARRAY
		else []
	)

	if institutions.is_empty():
		_add_info_card_to(
			root,
			"Higher Learning",
			[
				str(
					row.get(
						"empty_text",
						"Higher-learning contracts are still publishing."
					)
				)
			]
		)
		return

	var grid:= GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	grid.add_theme_constant_override(
		"h_separation",
		10
	)
	grid.add_theme_constant_override(
		"v_separation",
		10
	)
	root.add_child(
		grid
	)

	for raw_institution in institutions:
		if typeof(
			raw_institution
		) != TYPE_DICTIONARY:
			continue

		grid.add_child(
			_build_higher_learning_institution_card(
				raw_institution as Dictionary,
				row
			)
		)


func _build_higher_learning_institution_card(
	institution: Dictionary,
	row: Dictionary
) -> PanelContainer:
	var card:= PanelContainer.new()
	card.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	card.custom_minimum_size = Vector2(
		0.0,
		270.0
	)
	card.add_theme_stylebox_override(
		"panel",
		_card_style(
			{
				"accent": Color(
					0.46,
					0.72,
					1.0,
					1.0
				),
				"fill": Color(
					0.04,
					0.058,
					0.105,
					0.98
				),
				"font_color": Color.WHITE
			},
			false
		)
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
	card.add_child(
		margin
	)

	var box:= VBoxContainer.new()
	box.add_theme_constant_override(
		"separation",
		7
	)
	margin.add_child(
		box
	)

	var title:= Label.new()
	title.text = str(
		institution.get(
			"name",
			"Higher Learning"
		)
	)
	title.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	title.add_theme_font_size_override(
		"font_size",
		17
	)
	title.add_theme_color_override(
		"font_color",
		Color.WHITE
	)
	box.add_child(
		title
	)

	var prompt:= Label.new()
	prompt.text = str(
		institution.get(
			"program_prompt",
			"Pick a program to study."
		)
	)
	prompt.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	prompt.add_theme_font_size_override(
		"font_size",
		12
	)
	prompt.add_theme_color_override(
		"font_color",
		Color(
			0.76,
			0.8,
			0.92,
			1.0
		)
	)
	box.add_child(
		prompt
	)

	var programs_raw: Variant = institution.get(
		"programs",
		[]
	)
	var programs: Array = (
		programs_raw as Array
		if typeof(programs_raw) == TYPE_ARRAY
		else []
	)

	if programs.is_empty():
		var empty_label:= Label.new()
		empty_label.text = (
			"No resident programs are available here yet."
		)
		empty_label.autowrap_mode = (
			TextServer.AUTOWRAP_WORD_SMART
		)
		box.add_child(
			empty_label
		)
		return card

	var picker:= OptionButton.new()
	picker.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	picker.focus_mode = Control.FOCUS_NONE
	box.add_child(
		picker
	)

	var current_program_id: String = str(
		row.get(
			"current_program_id",
			""
		)
	)
	var selected_index: int = 0

	for index in range(
		programs.size()
	):
		var program_raw: Variant = programs [
			index
		]

		if typeof(
			program_raw
		) != TYPE_DICTIONARY:
			continue

		var program: Dictionary = (
			program_raw as Dictionary
		)
		var program_name: String = str(
			program.get(
				"program_name",
				"Program"
			)
		)

		picker.add_item(
			program_name
		)

		if str(
			program.get(
				"program_id",
				""
			)
		) == current_program_id:
			selected_index = index

	var cost_label:= Label.new()
	cost_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	cost_label.add_theme_font_size_override(
		"font_size",
		13
	)
	box.add_child(
		cost_label
	)

	var career_label:= Label.new()
	career_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	career_label.add_theme_font_size_override(
		"font_size",
		12
	)
	career_label.add_theme_color_override(
		"font_color",
		Color(
			0.82,
			0.86,
			0.96,
			1.0
		)
	)
	box.add_child(
		career_label
	)

	var funding_box:= VBoxContainer.new()
	funding_box.add_theme_constant_override(
		"separation",
		5
	)
	box.add_child(
		funding_box
	)

	picker.item_selected.connect(
		_on_higher_learning_program_selected.bind(
			programs,
			cost_label,
			career_label,
			funding_box,
			bool(
				row.get(
					"can_choose_program",
					false
				)
			)
		)
	)

	picker.select(
		selected_index
	)

	_on_higher_learning_program_selected(
		selected_index,
		programs,
		cost_label,
		career_label,
		funding_box,
		bool(
			row.get(
				"can_choose_program",
				false
			)
		)
	)

	animated_cards.append({
		"card": card,
		"base_modulate": Color(
			0.98,
			0.98,
			1.0,
			1.0
		),
		"hover_modulate": Color.WHITE
	})

	return card


func _on_higher_learning_program_selected(
	index: int,
	programs: Array,
	cost_label: Label,
	career_label: Label,
	funding_box: VBoxContainer,
	can_choose_program: bool
) -> void:
	if (
		index < 0
		or index >= programs.size()
	):
		return

	var program_raw: Variant = programs [
		index
	]

	if typeof(
		program_raw
	) != TYPE_DICTIONARY:
		return

	var program: Dictionary = (
		program_raw as Dictionary
	)
	var program_id: String = str(
		program.get(
			"program_id",
			""
		)
	)
	var cost_label_text: String = str(
		program.get(
			"cost_label",
			"Program cost"
		)
	)
	var tuition: float = float(
		program.get(
			"tuition",
			0.0
		)
	)

	cost_label.text = (
		"%s: %s"
		% [
			cost_label_text,
			(
				"Free"
				if tuition <= 0.0
				else str(
					int(
						round(
							tuition
						)
					)
				)
			)
		]
	)

	var career_projection_raw: Variant = program.get(
		"career_projection",
		{}
	)
	var career_projection: Dictionary = (
		career_projection_raw as Dictionary
		if typeof(career_projection_raw) == TYPE_DICTIONARY
		else {}
	)
	var career_lines_raw: Variant = career_projection.get(
		"display_lines",
		[]
	)
	var career_lines: Array = (
		career_lines_raw as Array
		if typeof(career_lines_raw) == TYPE_ARRAY
		else []
	)
	var career_text:= PackedStringArray()

	for raw_line in career_lines:
		var line: String = str(
			raw_line
		).strip_edges()

		if line != "":
			career_text.append(
				line
			)

	career_label.text = (
		"CAREER PATHS\n%s"
		% (
			"\n".join(
				career_text
			)
			if not career_text.is_empty()
			else "No direct career gate is attached yet."
		)
	)

	_clear_children(
		funding_box
	)

	if not can_choose_program:
		var enrolled_label:= Label.new()
		enrolled_label.text = (
			"You are already actively enrolled."
		)
		enrolled_label.autowrap_mode = (
			TextServer.AUTOWRAP_WORD_SMART
		)
		funding_box.add_child(
			enrolled_label
		)
		return

	var funding_raw: Variant = program.get(
		"funding_methods",
		[]
	)
	var funding_methods: Array = (
		funding_raw as Array
		if typeof(funding_raw) == TYPE_ARRAY
		else []
	)

	for raw_method in funding_methods:
		if typeof(
			raw_method
		) != TYPE_DICTIONARY:
			continue

		var method: Dictionary = (
			raw_method as Dictionary
		)
		var method_id: String = str(
			method.get(
				"id",
				""
			)
		).strip_edges()

		if method_id == "":
			continue

		var button:= Button.new()
		button.text = str(
			method.get(
				"label",
				"Choose Funding"
			)
		)
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(
			0.0,
			36.0
		)
		button.mouse_default_cursor_shape = (
			Control.CURSOR_POINTING_HAND
		)

		_style_action_button(
			button
		)



		button.pressed.connect(
			_on_action_pressed.bind({
				"action_id": "fund_higher_learning",
				"program_id": program_id,
				"funding_method": method_id,
				"return_section_id": "overview",
				"ui_is_expression_only": true
			})
		)

		funding_box.add_child(
			button
		)
func _render_school_cliques_into(
	root: VBoxContainer,
	row: Dictionary
) -> void:
	_add_section_heading_to(
		root,
		str(
			row.get(
				"title",
				"SCHOOL CLIQUES"
			)
		),
		str(
			row.get(
				"subtitle",
				"School social groups."
			)
		)
	)

	var cliques_raw: Variant = row.get(
		"cliques",
		[]
	)
	var cliques: Array = (
		cliques_raw as Array
		if typeof(cliques_raw) == TYPE_ARRAY
		else []
	)

	if cliques.is_empty():
		_add_info_card_to(
			root,
			"Cliques",
			[
				"No clique contracts are currently observable."
			]
		)
		return

	var grid:= GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	grid.add_theme_constant_override(
		"h_separation",
		10
	)
	grid.add_theme_constant_override(
		"v_separation",
		10
	)
	root.add_child(
		grid
	)

	for raw_clique in cliques:
		if typeof(
			raw_clique
		) != TYPE_DICTIONARY:
			continue

		grid.add_child(
			_build_school_clique_card(
				raw_clique as Dictionary
			)
		)


func _build_school_clique_card(
	clique: Dictionary
) -> PanelContainer:
	var card:= PanelContainer.new()
	card.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	card.custom_minimum_size = Vector2(
		0.0,
		210.0
	)
	card.add_theme_stylebox_override(
		"panel",
		_card_style(
			{
				"accent": Color(
					0.46,
					0.72,
					1.0,
					1.0
				),
				"fill": Color(
					0.04,
					0.058,
					0.105,
					0.98
				),
				"font_color": Color.WHITE
			},
			false
		)
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
	card.add_child(
		margin
	)

	var box:= VBoxContainer.new()
	box.add_theme_constant_override(
		"separation",
		6
	)
	margin.add_child(
		box
	)

	var title:= Label.new()
	title.text = str(
		clique.get(
			"label",
			"Clique"
		)
	)
	title.add_theme_font_size_override(
		"font_size",
		16
	)
	title.add_theme_color_override(
		"font_color",
		Color.WHITE
	)
	box.add_child(
		title
	)

	var description:= Label.new()
	description.text = str(
		clique.get(
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
	box.add_child(
		description
	)

	var requirements:= Label.new()
	requirements.text = (
		"Requirements: %s"
		% str(
			clique.get(
				"requirements_text",
				"None"
			)
		)
	)
	requirements.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	box.add_child(
		requirements
	)

	var member_cards_raw: Variant = clique.get(
		"member_cards",
		[]
	)
	var member_cards: Array = (
		member_cards_raw as Array
		if typeof(member_cards_raw) == TYPE_ARRAY
		else []
	)
	var member_names:= PackedStringArray()

	for raw_member in member_cards:
		if typeof(
			raw_member
		) != TYPE_DICTIONARY:
			continue

		var member: Dictionary = (
			raw_member as Dictionary
		)
		var member_name: String = str(
			member.get(
				"full_name",
				""
			)
		).strip_edges()

		if member_name != "":
			member_names.append(
				member_name
			)

	var members_label:= Label.new()
	members_label.text = (
		"Students: %s"
		% (
			", ".join(
				member_names
			)
			if not member_names.is_empty()
			else "No resident members visible yet"
		)
	)
	members_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	box.add_child(
		members_label
	)

	var joined: bool = bool(
		clique.get(
			"joined",
			false
		)
	)
	var eligible: bool = bool(
		clique.get(
			"eligible",
			false
		)
	)
	var button:= Button.new()

	if joined:
		button.text = "IN YOUR CLIQUE"
		button.disabled = true
	elif eligible:
		button.text = "JOIN CLIQUE"
		button.disabled = false
	else:
		button.text = "REQUIREMENTS NOT MET"
		button.disabled = true

	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(
		0.0,
		38.0
	)
	_style_action_button(
		button
	)

	if (
		not joined
		and eligible
	):
		button.pressed.connect(
			_on_action_pressed.bind({
				"action_id": "join_clique",
				"clique_id": str(
					clique.get(
						"clique_id",
						""
					)
				),
				"return_section_id": "social",
				"ui_is_expression_only": true
			})
		)

	box.add_child(
		button
	)

	animated_cards.append({
		"card": card,
		"base_modulate": Color(
			0.98,
			0.98,
			1.0,
			1.0
		),
		"hover_modulate": Color.WHITE
	})

	return card
func _activate_section_surface(section_id: String, emit_request: bool = true) -> bool:
	var activated: bool = super._activate_section_surface(section_id, emit_request)

	if active_section_id != "meal":
		_reset_communal_observation_clock()

	return activated


func _process(delta: float) -> void:
	super._process(delta)

	if not visible or active_section_id != "meal" or active_actor_id <= 0:
		return

	communal_visible_seconds += delta
	communal_observation_accumulator += delta

	if communal_observation_accumulator < communal_observation_interval:
		return

	communal_observation_accumulator = 0.0

	communal_presence_observed.emit(
		{
			"actor_id": active_actor_id,
			"visible_dwell_seconds": communal_visible_seconds,
			"surface_revision": communal_surface_revision,
			"active_section_id": active_section_id,
			"observation_kind": "school_communal_presence",
			"ui_is_expression_only": true
		}
	)


func _reset_communal_observation_clock() -> void:
	communal_visible_seconds = 0.0
	communal_observation_accumulator = 0.0