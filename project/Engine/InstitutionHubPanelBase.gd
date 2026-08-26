extends Control
class_name InstitutionHubPanelBase

signal close_requested
signal section_requested(section_id: String)
signal person_requested(target_id: int, payload: Dictionary)
signal action_requested(payload: Dictionary)

const PANEL_SCHEMA:= "eralife.institution_hub_panel"
const PANEL_VERSION:= 1

var panel_kind: String = "institution"
var active_contract: Dictionary = {}
var active_actor_id: int = -1
var active_section_id: String = "overview"
var section_contracts: Dictionary = {}
var surface_prepared: bool = false
var resident_option_stream_jobs: Array = []
var resident_option_stream_service_armed: bool = false
var resident_option_stream_generation: int = 0
var dim: ColorRect = null
var shell: PanelContainer = null
var shell_margin: MarginContainer = null
var shell_root: VBoxContainer = null
var top_bar: HBoxContainer = null
var close_button: Button = null
var title_label: Label = null
var header_chip: PanelContainer = null
var header_chip_label: Label = null
var tab_scroll: ScrollContainer = null
var tab_grid: GridContainer = null
var section_surface_host: Control = null
var status_label: Label = null

var tab_button_by_section: Dictionary = {}
var tab_contract_by_section: Dictionary = {}
var section_surface_deck: Dictionary = {}
var section_scroll_deck: Dictionary = {}
var pending_section_surface_order: Array = []
var pending_section_surface_contracts: Dictionary = {}
var pending_section_surface_service_active: bool = false
var section_surface_revision_by_id: Dictionary = {}



var pending_card_surface_install_queue: Array = []
var card_surface_install_service_active: bool = false
var card_surface_input_priority_until_ms: int = 0

var animated_cards: Array = []
var animation_time: float = 0.0


func prepare_surface(kind: String = "institution") -> void:
	var clean_kind: String = str(kind).strip_edges().to_lower()

	if clean_kind != "":
		panel_kind = clean_kind

	if surface_prepared:
		_apply_shell_theme()
		return

	name = "%sHubPanel" % panel_kind.capitalize()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_INHERIT
	z_as_relative = false
	z_index = 250

	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	dim = ColorRect.new()
	dim.name = "Dim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	shell = PanelContainer.new()
	shell.name = "Shell"
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell.offset_left = 42.0
	shell.offset_top = 24.0
	shell.offset_right = -42.0
	shell.offset_bottom = -24.0
	shell.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shell)

	shell_margin = MarginContainer.new()
	shell_margin.add_theme_constant_override("margin_left", 14)
	shell_margin.add_theme_constant_override("margin_top", 14)
	shell_margin.add_theme_constant_override("margin_right", 14)
	shell_margin.add_theme_constant_override("margin_bottom", 14)
	shell.add_child(shell_margin)

	shell_root = VBoxContainer.new()
	shell_root.name = "ShellRoot"
	shell_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell_root.add_theme_constant_override("separation", 8)
	shell_margin.add_child(shell_root)

	top_bar = HBoxContainer.new()
	top_bar.name = "TopBar"
	top_bar.add_theme_constant_override("separation", 8)
	shell_root.add_child(top_bar)

	close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(44.0, 44.0)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.pressed.connect(_on_close_pressed)
	top_bar.add_child(close_button)

	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "%s HUB" % panel_kind.to_upper()
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0, 1.0))
	title_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.72))
	title_label.add_theme_constant_override("shadow_offset_y", 2)
	top_bar.add_child(title_label)

	header_chip = PanelContainer.new()
	header_chip.name = "HeaderChip"
	header_chip.custom_minimum_size = Vector2(260.0, 38.0)
	header_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(header_chip)

	var chip_margin:= MarginContainer.new()
	chip_margin.add_theme_constant_override("margin_left", 10)
	chip_margin.add_theme_constant_override("margin_top", 5)
	chip_margin.add_theme_constant_override("margin_right", 10)
	chip_margin.add_theme_constant_override("margin_bottom", 5)
	header_chip.add_child(chip_margin)

	header_chip_label = Label.new()
	header_chip_label.name = "HeaderChipLabel"
	header_chip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_chip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_chip_label.add_theme_font_size_override("font_size", 12)
	header_chip_label.add_theme_color_override("font_color", Color(0.92, 0.92, 1.0, 1.0))
	chip_margin.add_child(header_chip_label)

	tab_scroll = ScrollContainer.new()
	tab_scroll.name = "TabScroll"
	tab_scroll.custom_minimum_size = Vector2(0.0, 48.0)
	tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	tab_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tab_scroll.follow_focus = false
	tab_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	shell_root.add_child(tab_scroll)

	tab_grid = GridContainer.new()
	tab_grid.name = "TabGrid"
	tab_grid.columns = 4
	tab_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_grid.add_theme_constant_override("h_separation", 6)
	tab_grid.add_theme_constant_override("v_separation", 6)
	tab_scroll.add_child(tab_grid)

	section_surface_host = Control.new()
	section_surface_host.name = "SectionSurfaceHost"
	section_surface_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section_surface_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	section_surface_host.custom_minimum_size = Vector2(0.0, 280.0)
	section_surface_host.clip_contents = true
	shell_root.add_child(section_surface_host)

	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", Color(0.72, 0.76, 0.88, 1.0))
	shell_root.add_child(status_label)

	surface_prepared = true
	_apply_shell_theme()
	_render_observable_partial(
		"%s reality is resident. Its current projection is reconnecting." % panel_kind.capitalize()
	)


func render_contract(
	contract: Dictionary
) -> void:
	prepare_surface(
		panel_kind
	)

	var incoming_contract: Dictionary = _dict(
		contract
	)

	if incoming_contract.is_empty():
		set_meta(
			"blank_contract_rejected",
			true
		)
		set_meta(
			"blank_contract_rejected_reason",
			"incoming_contract_is_empty"
		)
		return

	var incoming_actor_id: int = int(
		incoming_contract.get(
			"actor_id",
			-1
		)
	)
	var incoming_section_id: String = (
		str(
			incoming_contract.get(
				"active_section_id",
				incoming_contract.get(
					"active_section",
					_default_section()
				)
			)
		)
		.strip_edges()
		.to_lower()
	)

	if incoming_section_id == "":
		incoming_section_id = _default_section()

	var incoming_section_contracts: Dictionary = _dict(
		incoming_contract.get(
			"section_contracts",
			{}
		)
	)

	if incoming_section_contracts.is_empty():
		var active_copy: Dictionary = (
			incoming_contract.duplicate(false)
		)

		active_copy [
			"active_section_id"
		] = incoming_section_id
		incoming_section_contracts [
			incoming_section_id
		] = active_copy

	var incoming_has_renderable_rows: bool = false

	for raw_section_contract in incoming_section_contracts.values():
		var section_contract: Dictionary = _dict(
			raw_section_contract
		)
		var groups: Array = _array(
			section_contract.get(
				"groups",
				[]
			)
		)
		var rows: Array = _array(
			section_contract.get(
				"section_rows",
				section_contract.get(
					"rows",
					[]
				)
			)
		)

		if (
			not groups.is_empty()
			or not rows.is_empty()
		):
			incoming_has_renderable_rows = true
			break




	if (
		not incoming_has_renderable_rows
		and has_renderable_contract(
			active_actor_id
		)
	):
		set_meta(
			"blank_contract_rejected",
			true
		)
		set_meta(
			"blank_contract_rejected_reason",
			"existing_renderable_contract_has_sovereignty"
		)
		set_meta(
			"blank_contract_rejected_actor_id",
			incoming_actor_id
		)
		return

	set_meta(
		"blank_contract_rejected",
		false
	)

	active_contract = incoming_contract
	active_actor_id = incoming_actor_id
	active_section_id = incoming_section_id
	section_contracts = incoming_section_contracts

	title_label.text = str(
		active_contract.get(
			"title",
			"%s HUB" % panel_kind.to_upper()
		)
	)

	_render_header_chip(
		active_contract
	)
	_render_tabs(
		_array(
			active_contract.get(
				"tabs",
				[]
			)
		)
	)

	for raw_section_id in section_contracts.keys():
		var section_id: String = str(
			raw_section_id
		).strip_edges().to_lower()

		if section_id == "":
			continue

		var section_contract: Dictionary = _dict(
			section_contracts.get(
				raw_section_id,
				{}
			)
		)

		if section_contract.is_empty():
			continue

		section_contract [
			"active_section_id"
		] = section_id

		_queue_section_surface_contract(
			section_id,
			section_contract,
			section_id == active_section_id
		)




	if section_surface_deck.has(
		active_section_id
	):
		_activate_section_surface(
			active_section_id,
			false
		)
	else:
		set_meta(
			"active_section_surface_publication_pending",
			true
		)
		set_meta(
			"active_section_surface_publication_pending_id",
			active_section_id
		)
		set_meta(
			"active_section_surface_sync_build_forbidden",
			true
		)

	status_label.text = str(
		active_contract.get(
			"status_text",
			""
		)
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
		"active_actor_id",
		active_actor_id
	)
	set_meta(
		"active_section_id",
		active_section_id
	)
	set_meta(
		"truth_state",
		str(
			active_contract.get(
				"truth_state",
				"hot"
			)
		)
	)
	set_meta(
		"surface_revision",
		str(
			active_contract.get(
				"surface_revision",
				""
			)
		)
	)
	set_meta(
		"section_surface_build_is_cooperative",
		true
	)
	set_meta(
		"section_surface_build_one_section_per_frame",
		true
	)
	set_meta(
		"existing_renderable_sections_are_never_cleared_first",
		true
	)
	set_meta(
		"panel_blank_forbidden",
		true
	)
	set_meta(
		"ui_is_renderer_only",
		true
	)

	_arm_section_surface_contract_service()
func _render_relationship_observation_group_into(
	root: VBoxContainer,
	group: Dictionary,
	section_id: String
) -> void:
	var title_text: String = str(
		group.get(
			"title",
			"People"
		)
	)
	var subtitle_text: String = str(
		group.get(
			"subtitle",
			""
		)
	).strip_edges()
	var cards: Array = _array(
		group.get(
			"cards",
			group.get(
				"people",
				[]
			)
		)
	)

	_add_section_heading_to(
		root,
		title_text,
		subtitle_text
	)

	if cards.is_empty():
		_add_info_card_to(
			root,
			title_text,
			[
				str(
					group.get(
						"empty_text",
						"None"
					)
				)
			]
		)
		return




	var card_text:= RichTextLabel.new()

	card_text.name = "RelationshipObservationCards"
	card_text.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	card_text.fit_content = true
	card_text.scroll_active = false
	card_text.selection_enabled = false
	card_text.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	card_text.mouse_filter = (
		Control.MOUSE_FILTER_STOP
	)
	card_text.custom_minimum_size = Vector2(
		0.0,
		maxf(
			92.0,
			float(
				cards.size()
			) * 74.0
		)
	)
	card_text.meta_clicked.connect(
		_on_relationship_observation_meta_clicked
	)

	root.add_child(
		card_text
	)

	for raw_card in cards:
		var card_contract: Dictionary = _dict(
			raw_card
		)

		if card_contract.is_empty():
			continue

		var surface_contract: Dictionary = _dict(
			card_contract.get(
				"surface_contract",
				{}
			)
		)
		var state: String = str(
			card_contract.get(
				"state",
				"warm"
			)
		).strip_edges().to_lower()
		var palette: Dictionary = _card_palette(
			card_contract,
			section_id,
			state
		)
		var fill: Color = _color_from_variant(
			palette.get(
				"fill",
				Color(
					0.05,
					0.054,
					0.092,
					0.98
				)
			),
			Color(
				0.05,
				0.054,
				0.092,
				0.98
			)
		)
		var accent: Color = _color_from_variant(
			palette.get(
				"accent",
				_accent_color()
			),
			_accent_color()
		)
		var font_color: Color = _color_from_variant(
			palette.get(
				"font_color",
				Color.WHITE
			),
			Color.WHITE
		)
		var title_line: String = str(
			card_contract.get(
				"display_line",
				surface_contract.get(
					"card_title",
					card_contract.get(
						"target_name_with_age",
						card_contract.get(
							"full_name",
							card_contract.get(
								"target_name",
								"Person"
							)
						)
					)
				)
			)
		).strip_edges()
		var role_line: String = str(
			card_contract.get(
				"role",
				card_contract.get(
					"relationship_type",
					surface_contract.get(
						"subtitle",
						""
					)
				)
			)
		).strip_edges()
		var detail_parts: Array = []

		if role_line != "":
			detail_parts.append(
				role_line
			)

		if card_contract.has(
			"bond"
		):
			detail_parts.append(
				"BOND %d"
				% int(
					card_contract.get(
						"bond",
						0
					)
				)
			)

		if card_contract.has(
			"health"
		):
			detail_parts.append(
				"HEALTH %d/%d"
				% [
					int(
						card_contract.get(
							"health",
							0
						)
					),
					maxi(
						1,
						int(
							card_contract.get(
								"health_max",
								100
							)
						)
					)
				]
			)

		var target_id: int = int(
			card_contract.get(
				"target_id",
				card_contract.get(
					"person_id",
					-1
				)
			)
		)
		var interaction_contract: Dictionary = _dict(
			card_contract.get(
				"interaction_contract",
				{}
			)
		)
		var can_open: bool = (
			target_id > 0
			and not bool(
				card_contract.get(
					"is_self",
					false
				)
			)
			and bool(
				interaction_contract.get(
					"can_open_profile",
					true
				)
			)
		)
		var card_fill: Color = Color(
			fill.r,
			fill.g,
			fill.b,
			clampf(
				fill.a,
				0.82,
				0.98
			)
		)

		card_text.push_bgcolor(
			card_fill
		)

		if can_open:


			card_text.push_meta(
				card_contract.duplicate(
					false
				)
			)

		card_text.push_color(
			font_color
		)
		card_text.push_bold()
		card_text.add_text(
			"  %s  "
			% title_line
		)
		card_text.pop()
		card_text.pop()
		card_text.newline()

		card_text.push_color(
			accent
		)
		card_text.add_text(
			"  %s%s  "
			% [
				_join_strings(
					detail_parts,
					" | "
				),
				(
					" | OPEN PROFILE"
					if can_open
					else ""
				)
			]
		)
		card_text.pop()

		if can_open:
			card_text.pop()

		card_text.pop()
		card_text.newline()
		card_text.newline()


func _on_relationship_observation_meta_clicked(
	meta: Variant
) -> void:
	if typeof(
		meta
	) != TYPE_DICTIONARY:
		return

	var payload: Dictionary = (
		meta as Dictionary
	)
	var target_id: int = int(
		payload.get(
			"target_id",
			payload.get(
				"person_id",
				-1
			)
		)
	)

	if target_id <= 0:
		return

	_on_person_pressed(
		target_id,
		payload
	)


func _ensure_relationship_observation_section_surface(
	section_id: String,
	section_contract: Dictionary
) -> void:
	if (
		section_surface_host == null
		or not is_instance_valid(
			section_surface_host
		)
	):
		return

	var clean_section: String = str(
		section_id
	).strip_edges().to_lower()

	if clean_section == "":
		return

	var groups: Array = _array(
		section_contract.get(
			"groups",
			[]
		)
	)
	var rows: Array = _array(
		section_contract.get(
			"section_rows",
			section_contract.get(
				"rows",
				[]
			)
		)
	)
	var revision: String = str(
		section_contract.get(
			"surface_revision",
			""
		)
	).strip_edges()

	if revision == "":
		revision = (
			"relationship_observation:%d:%s:%d:%d"
			% [
				int(
					section_contract.get(
						"actor_id",
						active_actor_id
					)
				),
				clean_section,
				groups.size(),
				rows.size()
			]
		)

	var existing_raw: Variant = (
		section_surface_deck.get(
			clean_section,
			null
		)
	)

	if (
		typeof(
			existing_raw
		) == TYPE_OBJECT
		and is_instance_valid(
			existing_raw
		)
		and existing_raw is Control
		and str(
			section_surface_revision_by_id.get(
				clean_section,
				""
			)
		) == revision
		and bool(
			(existing_raw as Control).get_meta(
				"relationship_observation_surface",
				false
			)
		)
	):
		return

	var section_scroll:= ScrollContainer.new()

	section_scroll.name = (
		"RelationshipObservation_%s"
		% _safe_name(
			clean_section
		)
	)
	section_scroll.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	section_scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)
	section_scroll.vertical_scroll_mode = (
		ScrollContainer.SCROLL_MODE_AUTO
	)
	section_scroll.follow_focus = false
	section_scroll.clip_contents = true
	section_scroll.mouse_filter = (
		Control.MOUSE_FILTER_PASS
	)
	section_scroll.visible = false
	section_scroll.set_meta(
		"relationship_observation_surface",
		true
	)
	section_scroll.set_meta(
		"full_card_tree_construction_performed",
		false
	)
	section_scroll.set_meta(
		"engine_calls",
		false
	)

	var content_margin:= MarginContainer.new()

	content_margin.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	content_margin.add_theme_constant_override(
		"margin_left",
		4
	)
	content_margin.add_theme_constant_override(
		"margin_top",
		4
	)
	content_margin.add_theme_constant_override(
		"margin_right",
		10
	)
	content_margin.add_theme_constant_override(
		"margin_bottom",
		12
	)
	section_scroll.add_child(
		content_margin
	)

	var content_root:= VBoxContainer.new()

	content_root.name = "ContentRoot"
	content_root.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	content_root.add_theme_constant_override(
		"separation",
		10
	)
	content_margin.add_child(
		content_root
	)

	if not groups.is_empty():
		for raw_group in groups:
			var group: Dictionary = _dict(
				raw_group
			)

			if group.is_empty():
				continue

			_render_relationship_observation_group_into(
				content_root,
				group,
				clean_section
			)
	else:
		for raw_row in rows:
			var row: Dictionary = _dict(
				raw_row
			)

			if row.is_empty():
				continue

			if (
				row.has(
					"cards"
				)
				or row.has(
					"people"
				)
			):
				_render_relationship_observation_group_into(
					content_root,
					row,
					clean_section
				)
				continue

			var info_lines: Array = _array(
				row.get(
					"lines",
					[]
				)
			)

			if info_lines.is_empty():
				info_lines = [
					str(
						row.get(
							"subtitle",
							row.get(
								"description",
								""
							)
						)
					)
				]

			_add_info_card_to(
				content_root,
				str(
					row.get(
						"title",
						row.get(
							"label",
							"Observable Relationship Truth"
						)
					)
				),
				info_lines
			)

	if content_root.get_child_count() == 0:
		_add_info_card_to(
			content_root,
			"Observable Relationship Truth",
			[
				str(
					section_contract.get(
						"status_text",
						(
							"No relationships are currently "
							+ "projected in this section."
						)
					)
				)
			]
		)

	section_surface_host.add_child(
		section_scroll
	)

	var previous_surface: Control = null

	if (
		typeof(
			existing_raw
		) == TYPE_OBJECT
		and is_instance_valid(
			existing_raw
		)
		and existing_raw is Control
	):
		previous_surface = (
			existing_raw as Control
		)

	section_surface_deck [
		clean_section
	] = section_scroll
	section_scroll_deck [
		clean_section
	] = section_scroll
	section_surface_revision_by_id [
		clean_section
	] = revision

	if previous_surface != null:
		_retire_animated_entries_for_surface(
			previous_surface
		)

		previous_surface.visible = false
		previous_surface.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)
		previous_surface.process_mode = (
			Node.PROCESS_MODE_DISABLED
		)
		previous_surface.queue_free()

	var selected: bool = (
		clean_section == active_section_id
	)

	section_scroll.visible = selected
	section_scroll.mouse_filter = (
		Control.MOUSE_FILTER_PASS
		if selected
		else Control.MOUSE_FILTER_IGNORE
	)

	set_meta(
		"relationship_observation_surface_installed",
		true
	)
	set_meta(
		"relationship_observation_surface_last_id",
		clean_section
	)
	set_meta(
		"relationship_observation_surface_full_card_tree_forbidden",
		true
	)
	set_meta(
		"relationship_observation_surface_build_on_click",
		false
	)
	set_meta(
		"relationship_observation_surface_engine_calls",
		false
	)
func _queue_section_surface_contract(
	section_id: String,
	section_contract: Dictionary,
	prioritize: bool = false
) -> void:
	var clean_section: String = str(
		section_id
	).strip_edges().to_lower()

	if (
		clean_section == ""
		or section_contract.is_empty()
	):
		return




	pending_section_surface_contracts [
		clean_section
	] = section_contract.duplicate(false)

	if clean_section in pending_section_surface_order:
		pending_section_surface_order.erase(
			clean_section
		)

	if prioritize:
		pending_section_surface_order.push_front(
			clean_section
		)
	else:
		pending_section_surface_order.append(
			clean_section
		)

	if panel_kind == "relationships":
		set_meta(
			"relationship_section_uses_cooperative_card_surface_deck",
			true
		)
		set_meta(
			"relationship_section_stream_build_on_click",
			false
		)
		set_meta(
			"relationship_section_stream_engine_calls",
			false
		)
		set_meta(
			"relationship_section_stream_ready_gate_member",
			false
		)
		set_meta(
			"relationship_section_stream_last_id",
			clean_section
		)
		set_meta(
			"relationship_section_stream_last_at_ms",
			int(
				Time.get_ticks_msec()
			)
		)

func _arm_section_surface_contract_service() -> void:
	if pending_section_surface_service_active:
		return

	if pending_section_surface_order.is_empty():
		return

	var tree:= get_tree()

	if tree == null:
		pending_section_surface_service_active = false
		return

	var callback:= Callable(
		self,
		"_service_section_surface_contract_queue"
	)

	if tree.process_frame.is_connected(
		callback
	):
		pending_section_surface_service_active = true
		return

	pending_section_surface_service_active = true

	tree.process_frame.connect(
		callback,
		CONNECT_ONE_SHOT
	)

	set_meta(
		"section_surface_stream_uses_call_deferred",
		false
	)
	set_meta(
		"section_surface_stream_waits_for_render_boundary",
		false
	)
	set_meta(
		"section_surface_stream_requires_input_idle",
		false
	)
	set_meta(
		"section_surface_stream_process_frame_quantized",
		true
	)

func _ancestor_renderer_present_fence_active() -> bool:
	var cursor: Node = self

	while cursor != null:
		if bool(
			cursor.get_meta(
				"renderer_present_fence_active",
				false
			)
		):
			return true

		cursor = cursor.get_parent()

	return false
func _service_section_surface_contract_queue() -> void:
	var tree:= get_tree()
	var callback:= Callable(
		self,
		"_service_section_surface_contract_queue"
	)

	if (
		tree != null
		and tree.process_frame.is_connected(
			callback
		)
	):
		tree.process_frame.disconnect(
			callback
		)

	pending_section_surface_service_active = false

	if pending_section_surface_order.is_empty():
		if panel_kind == "relationships":
			_retire_relationship_orphaned_section_surfaces()

		if (
			not visible
			and not card_surface_install_service_active
			and pending_card_surface_install_queue.is_empty()
		):
			process_mode = Node.PROCESS_MODE_DISABLED

		return

	var queued_section_id: String = str(
		pending_section_surface_order [
			0
		]
	).strip_edges().to_lower()

	if (
		panel_kind == "relationships"
		and queued_section_id != ""
		and not section_contracts.has(
			queued_section_id
		)
	):
		pending_section_surface_order.pop_front()
		pending_section_surface_contracts.erase(
			queued_section_id
		)

		_arm_section_surface_contract_service()
		return




	if panel_kind == "relationships":
		var required_world_year: int = int(
			get_meta(
				"resident_required_world_year",
				-999999
			)
		)
		var queued_contract: Dictionary = _dict(
			pending_section_surface_contracts.get(
				queued_section_id,
				{}
			)
		)

		if (
			required_world_year != -999999
			and not queued_contract.is_empty()
		):
			var queued_wrapper: Dictionary = {
				"actor_id": int(
					queued_contract.get(
						"actor_id",
						active_actor_id
					)
				),
				"active_section_id": queued_section_id,
				"section_contracts": {
					queued_section_id: queued_contract
				}
			}
			var queued_world_year: int = (
				_relationship_observation_contract_world_year(
					queued_wrapper
				)
			)

			if queued_world_year != required_world_year:
				pending_section_surface_order.pop_front()
				pending_section_surface_contracts.erase(
					queued_section_id
				)

				set_meta(
					"relationship_stale_section_install_rejected",
					true
				)
				set_meta(
					"relationship_stale_section_install_id",
					queued_section_id
				)
				set_meta(
					"relationship_stale_section_install_world_year",
					queued_world_year
				)
				set_meta(
					"relationship_stale_section_required_world_year",
					required_world_year
				)
				set_meta(
					"relationship_stale_section_contract_mutated",
					false
				)

				_arm_section_surface_contract_service()
				return




	if _ancestor_renderer_present_fence_active():
		set_meta(
			"section_surface_stream_paused_for_present_fence",
			true
		)
		set_meta(
			"section_surface_stream_present_fence_blocks_input",
			false
		)

		_arm_section_surface_contract_service()
		return

	set_meta(
		"section_surface_stream_paused_for_present_fence",
		false
	)



	_service_next_section_surface_contract()

	set_meta(
		"section_surface_stream_requires_input_idle",
		false
	)
	set_meta(
		"section_surface_stream_continues_during_interaction",
		true
	)
	set_meta(
		"section_surface_stream_sections_per_quantum",
		1
	)
	set_meta(
		"section_surface_stream_render_boundary_used",
		false
	)
	set_meta(
		"section_surface_stream_deferred_callback_used",
		false
	)

	if panel_kind == "relationships":
		_retire_relationship_orphaned_section_surfaces()

	if not pending_section_surface_order.is_empty():
		_arm_section_surface_contract_service()
		return

	if (
		not visible
		and not card_surface_install_service_active
		and pending_card_surface_install_queue.is_empty()
	):
		process_mode = Node.PROCESS_MODE_DISABLED
func _retire_relationship_orphaned_section_surfaces() -> void:
	if panel_kind != "relationships":
		return

	var authoritative_section_ids: Dictionary = {}

	for raw_section_id in section_contracts.keys():
		var section_id: String = str(
			raw_section_id
		).strip_edges().to_lower()

		if section_id == "":
			continue

		authoritative_section_ids [
			section_id
		] = true

	if authoritative_section_ids.is_empty():
		return

	var retired_surfaces: Array = []

	for raw_section_id in section_surface_deck.keys():
		var section_id: String = str(
			raw_section_id
		).strip_edges().to_lower()

		if authoritative_section_ids.has(
			section_id
		):
			continue

		var surface_raw: Variant = section_surface_deck.get(
			raw_section_id,
			null
		)

		if (
			typeof(
				surface_raw
			) == TYPE_OBJECT
			and is_instance_valid(
				surface_raw
			)
			and surface_raw is Control
		):
			var surface: Control = (
				surface_raw as Control
			)

			_retire_animated_entries_for_surface(
				surface
			)

			surface.visible = false
			surface.mouse_filter = (
				Control.MOUSE_FILTER_IGNORE
			)
			surface.process_mode = (
				Node.PROCESS_MODE_DISABLED
			)

			retired_surfaces.append(
				surface
			)

			surface.queue_free()

		section_surface_deck.erase(
			raw_section_id
		)
		section_scroll_deck.erase(
			raw_section_id
		)
		section_surface_revision_by_id.erase(
			raw_section_id
		)

	if (
		not retired_surfaces.is_empty()
		and not pending_card_surface_install_queue.is_empty()
	):
		var retained_card_installs: Array = []

		for raw_entry in pending_card_surface_install_queue:
			if typeof(
				raw_entry
			) != TYPE_DICTIONARY:
				continue

			var entry: Dictionary = (
				raw_entry as Dictionary
			)
			var grid_raw: Variant = entry.get(
				"grid",
				null
			)

			if (
				typeof(
					grid_raw
				) != TYPE_OBJECT
				or not is_instance_valid(
					grid_raw
				)
				or not (
					grid_raw is Node
				)
			):
				continue

			var grid_node: Node = (
				grid_raw as Node
			)
			var belongs_to_retired_surface: bool = false

			for raw_surface in retired_surfaces:
				if (
					typeof(
						raw_surface
					) != TYPE_OBJECT
					or not is_instance_valid(
						raw_surface
					)
					or not (
						raw_surface is Control
					)
				):
					continue

				var retired_surface: Control = (
					raw_surface as Control
				)

				if (
					grid_node == retired_surface
					or retired_surface.is_ancestor_of(
						grid_node
					)
				):
					belongs_to_retired_surface = true
					break

			if belongs_to_retired_surface:
				continue

			retained_card_installs.append(
				entry
			)

		pending_card_surface_install_queue = (
			retained_card_installs
		)

	set_meta(
		"relationship_orphaned_section_cleanup_complete",
		true
	)
	set_meta(
		"relationship_orphaned_section_cleanup_retired_count",
		retired_surfaces.size()
	)
	set_meta(
		"card_surface_install_queue_size",
		pending_card_surface_install_queue.size()
	)
	set_meta(
		"relationship_orphaned_section_cleanup_at_ms",
		int(
			Time.get_ticks_msec()
		)
	)
func _retire_animated_entries_for_surface(
	surface: Control
) -> void:
	if (
		surface == null
		or not is_instance_valid(
			surface
		)
	):
		return

	var retained_entries: Array = []

	for raw_entry in animated_cards:
		if typeof(
			raw_entry
		) != TYPE_DICTIONARY:
			continue

		var entry: Dictionary = raw_entry
		var candidate_raw: Variant = entry.get(
			"control",
			entry.get(
				"card",
				null
			)
		)



		if typeof(
			candidate_raw
		) != TYPE_OBJECT:
			continue

		if not is_instance_valid(
			candidate_raw
		):
			continue

		if not (
			candidate_raw is Node
		):
			continue

		var candidate_node: Node = (
			candidate_raw as Node
		)

		if (
			candidate_node == surface
			or surface.is_ancestor_of(
				candidate_node
			)
		):
			continue

		retained_entries.append(
			entry
		)

	animated_cards = retained_entries
func _service_next_section_surface_contract() -> void:
	if pending_section_surface_order.is_empty():
		return

	var section_id: String = str(
		pending_section_surface_order.pop_front()
	).strip_edges().to_lower()
	var section_contract: Dictionary = _dict(
		pending_section_surface_contracts.get(
			section_id,
			{}
		)
	)

	pending_section_surface_contracts.erase(
		section_id
	)

	if section_contract.is_empty():
		return

	var revision: String = str(
		section_contract.get(
			"surface_revision",
			(
				"%s:%d:%d"
				% [
					section_id,
					int(
						section_contract.get(
							"actor_id",
							-1
						)
					),
					_array(
						section_contract.get(
							"groups",
							[]
						)
					).size()
				]
			)
		)
	)

	if (
		section_surface_deck.has(
			section_id
		)
		and str(
			section_surface_revision_by_id.get(
				section_id,
				""
			)
		) == revision
	):
		return

	var previous_surface_raw: Variant = (
		section_surface_deck.get(
			section_id,
			null
		)
	)
	var previous_surface: Control = null

	if (
		typeof(
			previous_surface_raw
		) == TYPE_OBJECT
		and is_instance_valid(
			previous_surface_raw
		)
		and previous_surface_raw is Control
	):
		previous_surface = (
			previous_surface_raw as Control
		)





	if (
		panel_kind == "relationships"
		and previous_surface != null
		and bool(
			previous_surface.get_meta(
				"resident_surface_has_relationship_groups",
				false
			)
		)
	):
		var incoming_groups: Array = _array(
			section_contract.get(
				"groups",
				[]
			)
		)
		var rendered_group_count: int = int(
			previous_surface.get_meta(
				"resident_streamed_group_count",
				0
			)
		)

		if incoming_groups.size() > rendered_group_count:
			var content_root:= (
				previous_surface.get_node_or_null(
					"ContentMargin/ContentRoot"
				) as VBoxContainer
			)

			if (
				content_root != null
				and is_instance_valid(
					content_root
				)
			):
				for group_index in range(
					rendered_group_count,
					incoming_groups.size()
				):
					var new_group: Dictionary = _dict(
						incoming_groups [
							group_index
						]
					)

					if new_group.is_empty():
						continue

					if str(
						new_group.get(
							"row_kind",
							""
						)
					).strip_edges() == "":
						new_group [
							"row_kind"
						] = (
							"relationship_group"
							if new_group.has(
								"cards"
							)
							else "information"
						)

					_render_row_into(
						content_root,
						new_group
					)

				previous_surface.set_meta(
					"resident_streamed_group_count",
					incoming_groups.size()
				)
				previous_surface.set_meta(
					"resident_surface_has_relationship_groups",
					not incoming_groups.is_empty()
				)

				section_surface_revision_by_id [
					section_id
				] = revision

				set_meta(
					"relationship_section_incremental_group_append",
					true
				)
				set_meta(
					"relationship_section_incremental_group_append_id",
					section_id
				)
				set_meta(
					"relationship_section_incremental_group_count",
					incoming_groups.size()
				)
				set_meta(
					"relationship_section_incremental_group_build_on_click",
					false
				)

				if section_id == active_section_id:
					_activate_section_surface(
						section_id,
						false
					)

				return



	var replacement_surface: ScrollContainer = (
		_build_section_surface(
			section_id,
			section_contract
		)
	)

	section_surface_host.add_child(
		replacement_surface
	)

	section_surface_deck [
		section_id
	] = replacement_surface
	section_scroll_deck [
		section_id
	] = replacement_surface
	section_surface_revision_by_id [
		section_id
	] = revision

	if previous_surface != null:
		_retire_animated_entries_for_surface(
			previous_surface
		)

		previous_surface.visible = false
		previous_surface.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)
		previous_surface.process_mode = (
			Node.PROCESS_MODE_DISABLED
		)
		previous_surface.queue_free()

	if section_id == active_section_id:
		_activate_section_surface(
			section_id,
			false
		)
	else:
		replacement_surface.visible = false
		replacement_surface.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)
func show_surface() -> void:
	prepare_surface(panel_kind)

	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_INHERIT


func hide_surface() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = (
		Node.PROCESS_MODE_INHERIT
		if (
			pending_section_surface_service_active
			or not pending_section_surface_order.is_empty()
			or card_surface_install_service_active
			or not pending_card_surface_install_queue.is_empty()
		)
		else Node.PROCESS_MODE_DISABLED
	)

func has_surface_shell() -> bool:
	return (
		surface_prepared
		and shell != null
		and is_instance_valid(shell)
		and tab_grid != null
		and is_instance_valid(tab_grid)
		and section_surface_host != null
		and is_instance_valid(section_surface_host)
	)
func _relationship_observation_contract_world_year(
	contract: Dictionary
) -> int:
	if (
		panel_kind != "relationships"
		or contract.is_empty()
	):
		return -999999

	var contract_actor_id: int = int(
		contract.get(
			"actor_id",
			-1
		)
	)
	var contract_section_id: String = str(
		contract.get(
			"active_section_id",
			contract.get(
				"active_section",
				active_section_id
			)
		)
	).strip_edges().to_lower()

	if contract_section_id == "":
		contract_section_id = active_section_id

	var contract_sections: Dictionary = _dict(
		contract.get(
			"section_contracts",
			{}
		)
	)
	var section_contract: Dictionary = _dict(
		contract_sections.get(
			contract_section_id,
			{}
		)
	)
	var revision: String = str(
		section_contract.get(
			"surface_revision",
			contract.get(
				"surface_revision",
				""
			)
		)
	).strip_edges()

	if revision == "":
		return -999999

	var revision_parts: PackedStringArray = (
		revision.split(":")
	)

	if revision_parts.size() < 2:
		return -999999

	if (
		not str(
			revision_parts [0]
		).is_valid_int()
		or not str(
			revision_parts [1]
		).is_valid_int()
	):
		return -999999

	var revision_actor_id: int = int(
		revision_parts [0]
	)

	if (
		contract_actor_id > 0
		and revision_actor_id != contract_actor_id
	):
		return -999999

	return int(
		revision_parts [1]
	)

func has_renderable_contract(
	actor_id: int = -1
) -> bool:
	if (
		not has_surface_shell()
		or active_contract.is_empty()
	):
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

	if panel_kind == "relationships":
		var required_actor_id: int = int(
			get_meta(
				"resident_required_actor_id",
				actor_id
			)
		)
		var required_world_year: int = int(
			get_meta(
				"resident_required_world_year",
				-999999
			)
		)
		var observed_world_year: int = (
			_relationship_observation_contract_world_year(
				active_contract
			)
		)

		if (
			required_actor_id > 0
			and int(
				active_contract.get(
					"actor_id",
					-1
				)
			) != required_actor_id
		):
			return false

		if (
			required_world_year != -999999
			and observed_world_year != required_world_year
		):
			set_meta(
				"relationship_historical_packet_rejected_as_current",
				true
			)
			set_meta(
				"relationship_historical_packet_actor_id",
				int(
					active_contract.get(
						"actor_id",
						-1
					)
				)
			)
			set_meta(
				"relationship_historical_packet_world_year",
				observed_world_year
			)
			set_meta(
				"relationship_required_world_year",
				required_world_year
			)
			set_meta(
				"relationship_historical_packet_remains_residency_proof",
				true
			)
			set_meta(
				"relationship_historical_packet_mutated",
				false
			)

			return false

	var projection_complete: bool = bool(
		active_contract.get(
			"projection_complete",
			active_contract.get(
				"authoritative_projection",
				false
			)
		)
	)
	var projection_pending: bool = bool(
		active_contract.get(
			"projection_pending",
			false
		)
	)
	var truth_state: String = str(
		active_contract.get(
			"truth_state",
			""
		)
	).strip_edges().to_lower()
	var active_section_contract: Dictionary = _dict(
		section_contracts.get(
			active_section_id,
			active_contract
		)
	)
	var groups: Array = _array(
		active_section_contract.get(
			"groups",
			active_contract.get(
				"groups",
				[]
			)
		)
	)
	var rows: Array = _array(
		active_section_contract.get(
			"section_rows",
			active_section_contract.get(
				"rows",
				[]
			)
		)
	)
	var progressive_packet_hot: bool = (
		projection_pending
		and (
			truth_state in [
				"warming",
				"streaming"
			]
			or not groups.is_empty()
			or not rows.is_empty()
		)
	)

	return (
		(
			projection_complete
			or progressive_packet_hot
		)
		and truth_state in [
			"warming",
			"streaming",
			"hot",
			"authoritative"
		]
		and section_surface_deck.has(
			active_section_id
		)
	)
func set_status(text: String) -> void:
	prepare_surface(panel_kind)
	status_label.text = text


func _rebuild_section_surface_deck() -> void:
	_clear_section_surface_deck()
	animated_cards.clear()

	if section_contracts.is_empty():
		var active_copy: Dictionary = active_contract.duplicate(true)
		active_copy ["active_section_id"] = active_section_id
		section_contracts [active_section_id] = active_copy

	for raw_section_id in section_contracts.keys():
		var section_id: String = str(raw_section_id).strip_edges().to_lower()

		if section_id == "":
			continue

		var section_contract: Dictionary = _dict(section_contracts.get(raw_section_id, {}))

		if section_contract.is_empty():
			continue

		section_contract ["active_section_id"] = section_id
		var section_surface: ScrollContainer = _build_section_surface(section_id, section_contract)
		section_surface_host.add_child(section_surface)
		section_surface_deck [section_id] = section_surface
		section_scroll_deck [section_id] = section_surface

	if not section_surface_deck.has(active_section_id):
		var fallback_contract: Dictionary = active_contract.duplicate(true)
		fallback_contract ["active_section_id"] = active_section_id
		var fallback_surface: ScrollContainer = _build_section_surface(
			active_section_id, fallback_contract
		)
		section_surface_host.add_child(fallback_surface)
		section_surface_deck [active_section_id] = fallback_surface
		section_scroll_deck [active_section_id] = fallback_surface


func _build_section_surface(
	section_id: String,
	section_contract: Dictionary
) -> ScrollContainer:
	var section_scroll:= ScrollContainer.new()
	section_scroll.name = "Section_%s" % _safe_name(section_id)

	section_scroll.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	section_scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)
	section_scroll.vertical_scroll_mode = (
		ScrollContainer.SCROLL_MODE_AUTO
	)
	section_scroll.follow_focus = false
	section_scroll.clip_contents = true
	section_scroll.mouse_filter = (
		Control.MOUSE_FILTER_PASS
	)
	section_scroll.visible = false

	var content_margin:= MarginContainer.new()
	content_margin.name = "ContentMargin"
	content_margin.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	content_margin.add_theme_constant_override(
		"margin_left",
		4
	)
	content_margin.add_theme_constant_override(
		"margin_top",
		4
	)
	content_margin.add_theme_constant_override(
		"margin_right",
		10
	)
	content_margin.add_theme_constant_override(
		"margin_bottom",
		12
	)
	section_scroll.add_child(
		content_margin
	)

	var content_root:= VBoxContainer.new()
	content_root.name = "ContentRoot"
	content_root.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	content_root.add_theme_constant_override(
		"separation",
		10
	)
	content_margin.add_child(
		content_root
	)

	var groups: Array = _array(
		section_contract.get(
			"groups",
			[]
		)
	)

	_render_contract_rows_into(
		content_root,
		section_contract
	)

	if content_root.get_child_count() == 0:
		_add_info_card_to(
			content_root,
			"Observable Reality",
			[
				str(
					section_contract.get(
						"status_text",
						(
							"This projection is resident but currently "
							+ "contains no visible cards."
						)
					)
				)
			]
		)

	section_scroll.set_meta(
		"resident_streamed_group_count",
		groups.size()
	)
	section_scroll.set_meta(
		"resident_surface_has_relationship_groups",
		not groups.is_empty()
	)
	section_scroll.set_meta(
		"resident_section_id",
		section_id
	)

	var vertical_bar:= (
		section_scroll.get_v_scroll_bar()
	)

	if vertical_bar != null:
		vertical_bar.step = 1.0
		vertical_bar.custom_minimum_size = Vector2(
			12.0,
			0.0
		)

	return section_scroll

func _render_contract_rows_into(root: VBoxContainer, contract: Dictionary) -> void:
	var groups: Array = _array(contract.get("groups", []))

	if not groups.is_empty():
		for raw_group in groups:
			var group: Dictionary = _dict(raw_group)

			if group.is_empty():
				continue

			if str(group.get("row_kind", "")).strip_edges() == "":
				group ["row_kind"] = ("relationship_group" if group.has("cards") else "information")

			_render_row_into(root, group)

		return

	var rows: Array = _array(contract.get("section_rows", contract.get("rows", [])))

	for raw_row in rows:
		var row: Dictionary = _dict(raw_row)

		if row.is_empty():
			continue

		_render_row_into(root, row)


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
		"relationship_group", "people_group":
			_render_people_group_into(
				root,
				row
			)

		"relationship_marriage_planner":
			_render_relationship_marriage_planner_into(
				root,
				row
			)

		"entity_group":
			_render_entity_group_into(
				root,
				row
			)

		"communal_zone":
			_render_communal_zone_into(
				root,
				row
			)

		"class_zone":
			_render_class_zone_into(
				root,
				row
			)

		"school_options":
			_render_school_options_into(
				root,
				row
			)

		"social_memory":
			_render_social_memory_into(
				root,
				row
			)

		"actions":
			_render_actions_into(
				root,
				row
			)

		"summary", "information":
			_add_info_card_to(
				root,
				str(
					row.get(
						"title",
						"Institution Reality"
					)
				),
				_array(
					row.get(
						"lines",
						[
							str(
								row.get(
									"description",
									""
								)
							)
						]
					)
				)
			)

		_:
			if row.has(
				"cards"
			):
				_render_people_group_into(
					root,
					row
				)
			else:
				_add_info_card_to(
					root,
					str(
						row.get(
							"title",
							"Institution Reality"
						)
					),
					_array(
						row.get(
							"lines",
							[]
						)
					)
				)
func reveal_resident_section(
	section_id: String
) -> bool:
	return _activate_section_surface(
		section_id,
		false
	)


func _render_relationship_marriage_planner_into(
	root: VBoxContainer,
	row: Dictionary
) -> void:
	if (
		root == null
		or not is_instance_valid(
			root
		)
	):
		return

	var planner_shell:= PanelContainer.new()
	planner_shell.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	root.add_child(
		planner_shell
	)

	var margin:= MarginContainer.new()
	margin.add_theme_constant_override(
		"margin_left",
		14
	)
	margin.add_theme_constant_override(
		"margin_top",
		12
	)
	margin.add_theme_constant_override(
		"margin_right",
		14
	)
	margin.add_theme_constant_override(
		"margin_bottom",
		12
	)
	planner_shell.add_child(
		margin
	)

	var stack:= VBoxContainer.new()
	stack.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	stack.add_theme_constant_override(
		"separation",
		9
	)
	margin.add_child(
		stack
	)

	var title:= Label.new()
	title.text = str(
		row.get(
			"title",
			"PLAN MARRIAGE"
		)
	)
	title.add_theme_font_size_override(
		"font_size",
		22
	)
	title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	stack.add_child(
		title
	)

	var partner_label:= Label.new()
	partner_label.text = (
		"Partner: %s"
		% str(
			row.get(
				"partner_name",
				"Partner"
			)
		)
	)
	partner_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	stack.add_child(
		partner_label
	)

	var wedding_label:= Label.new()
	wedding_label.text = "Wedding Type"
	stack.add_child(
		wedding_label
	)

	var wedding_picker:= OptionButton.new()
	wedding_picker.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	stack.add_child(
		wedding_picker
	)

	var honeymoon_label:= Label.new()
	honeymoon_label.text = "Honeymoon Realm"
	stack.add_child(
		honeymoon_label
	)

	var honeymoon_picker:= OptionButton.new()
	honeymoon_picker.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	stack.add_child(
		honeymoon_picker
	)

	var prenup_check:= CheckBox.new()
	prenup_check.text = "Request a Prenup"
	prenup_check.button_pressed = false
	prenup_check.visible = bool(
		row.get(
			"request_prenup_available",
			true
		)
	)
	stack.add_child(
		prenup_check
	)

	var total_label:= Label.new()
	total_label.text = (
		"Wedding + honeymoon cost will update as destinations publish."
	)
	total_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	total_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	stack.add_child(
		total_label
	)

	var planner_status_label:= Label.new()
	planner_status_label.text = (
		"Publishing resident wedding and realm choices…"
		if bool(
			row.get(
				"projection_pending",
				false
			)
		)
		else "Marriage planner is resident."
	)
	planner_status_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	planner_status_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	stack.add_child(
		planner_status_label
	)

	var submit:= Button.new()
	submit.text = "GET MARRIED"
	submit.focus_mode = Control.FOCUS_NONE
	submit.custom_minimum_size = Vector2(
		0,
		48
	)
	stack.add_child(
		submit
	)

	wedding_picker.item_selected.connect(
		Callable(
			self,
			"_refresh_marriage_planner_total_label"
		).bind(
			wedding_picker,
			honeymoon_picker,
			total_label
		)
	)

	honeymoon_picker.item_selected.connect(
		Callable(
			self,
			"_refresh_marriage_planner_total_label"
		).bind(
			wedding_picker,
			honeymoon_picker,
			total_label
		)
	)

	submit.pressed.connect(
		Callable(
			self,
			"_on_relationship_marriage_plan_submit_pressed"
		).bind(
			row.duplicate(false),
			wedding_picker,
			honeymoon_picker,
			prenup_check,
			planner_status_label
		)
	)




	_queue_resident_option_button_stream(
		wedding_picker,
		_array(
			row.get(
				"wedding_types",
				[]
			)
		),
		"id",
		"label",
		"cost"
	)

	_queue_resident_option_button_stream(
		honeymoon_picker,
		_array(
			row.get(
				"honeymoon_realms",
				[]
			)
		),
		"id",
		"label",
		"cost"
	)

func _queue_resident_option_button_stream(
	picker: OptionButton,
	rows: Array,
	id_key: String,
	label_key: String,
	cost_key: String
) -> void:
	if (
		picker == null
		or not is_instance_valid(
			picker
		)
	):
		return

	resident_option_stream_generation += 1

	resident_option_stream_jobs.append({
		"generation": (
			resident_option_stream_generation
		),
		"picker_instance_id": int(
			picker.get_instance_id()
		),
		"rows": rows,
		"cursor": 0,
		"id_key": id_key,
		"label_key": label_key,
		"cost_key": cost_key
	})

	_arm_resident_option_button_stream()


func _arm_resident_option_button_stream() -> void:
	if resident_option_stream_service_armed:
		return

	if resident_option_stream_jobs.is_empty():
		return

	var tree:= get_tree()

	if tree == null:
		return

	resident_option_stream_service_armed = true

	var timer:= tree.create_timer(
		0.018
	)

	timer.timeout.connect(
		Callable(
			self,
			"_service_resident_option_button_stream_quantum"
		),
		CONNECT_ONE_SHOT
	)


func _service_resident_option_button_stream_quantum() -> void:
	resident_option_stream_service_armed = false

	if resident_option_stream_jobs.is_empty():
		return

	var job_raw: Variant = (
		resident_option_stream_jobs [
			0
		]
	)
	var job: Dictionary = (
		job_raw as Dictionary
		if typeof(job_raw) == TYPE_DICTIONARY
		else {}
	)

	if job.is_empty():
		resident_option_stream_jobs.pop_front()
		_arm_resident_option_button_stream()
		return

	var picker_id: int = int(
		job.get(
			"picker_instance_id",
			0
		)
	)
	var picker_object: Object = (
		instance_from_id(
			picker_id
		)
		if picker_id > 0
		else null
	)

	if (
		picker_object == null
		or not (
			picker_object is OptionButton
		)
		or not is_instance_valid(
			picker_object
		)
	):
		resident_option_stream_jobs.pop_front()
		_arm_resident_option_button_stream()
		return

	var picker: OptionButton = (
		picker_object as OptionButton
	)
	var rows: Array = _array(
		job.get(
			"rows",
			[]
		)
	)
	var cursor: int = int(
		job.get(
			"cursor",
			0
		)
	)

	if cursor >= rows.size():
		resident_option_stream_jobs.pop_front()
		_arm_resident_option_button_stream()
		return

	var raw_row: Variant = rows [
		cursor
	]

	job ["cursor"] = cursor + 1

	if typeof(raw_row) == TYPE_DICTIONARY:
		var option: Dictionary = (
			raw_row as Dictionary
		)

		var label: String = str(
			option.get(
				str(
					job.get(
						"label_key",
						"label"
					)
				),
				"Option"
			)
		)

		var option_index: int = (
			picker.item_count
		)

		picker.add_item(
			label
		)

		picker.set_item_metadata(
			option_index,
			{
				"id": str(
					option.get(
						str(
							job.get(
								"id_key",
								"id"
							)
						),
						""
					)
				),
				"cost": float(
					option.get(
						str(
							job.get(
								"cost_key",
								"cost"
							)
						),
						0.0
					)
				)
			}
		)

	resident_option_stream_jobs [
		0
	] = job

	_arm_resident_option_button_stream()


func _refresh_marriage_planner_total_label(
	_selected_index: int,
	wedding_picker: OptionButton,
	honeymoon_picker: OptionButton,
	total_label: Label
) -> void:
	if (
		wedding_picker == null
		or honeymoon_picker == null
		or total_label == null
	):
		return

	if (
		wedding_picker.item_count <= 0
		or honeymoon_picker.item_count <= 0
	):
		total_label.text = (
			"Waiting for resident wedding and honeymoon choices…"
		)
		return

	var wedding_meta: Variant = (
		wedding_picker.get_item_metadata(
			wedding_picker.selected
		)
	)
	var honeymoon_meta: Variant = (
		honeymoon_picker.get_item_metadata(
			honeymoon_picker.selected
		)
	)

	var wedding_cost: float = (
		float(
			(wedding_meta as Dictionary).get(
				"cost",
				0.0
			)
		)
		if typeof(wedding_meta) == TYPE_DICTIONARY
		else 0.0
	)

	var honeymoon_cost: float = (
		float(
			(honeymoon_meta as Dictionary).get(
				"cost",
				0.0
			)
		)
		if typeof(honeymoon_meta) == TYPE_DICTIONARY
		else 0.0
	)

	total_label.text = (
		"Estimated total: $%0.2f"
		% (
			wedding_cost
			+ honeymoon_cost
		)
	)


func _on_relationship_marriage_plan_submit_pressed(
	row: Dictionary,
	wedding_picker: OptionButton,
	honeymoon_picker: OptionButton,
	prenup_check: CheckBox,
	planner_status_label: Label
) -> void:
	if (
		wedding_picker == null
		or honeymoon_picker == null
		or wedding_picker.item_count <= 0
		or honeymoon_picker.item_count <= 0
	):
		if planner_status_label != null:
			planner_status_label.text = (
				"Wedding or honeymoon choices are still publishing."
			)
		return

	var wedding_meta: Variant = (
		wedding_picker.get_item_metadata(
			wedding_picker.selected
		)
	)
	var honeymoon_meta: Variant = (
		honeymoon_picker.get_item_metadata(
			honeymoon_picker.selected
		)
	)

	if (
		typeof(wedding_meta) != TYPE_DICTIONARY
		or typeof(honeymoon_meta) != TYPE_DICTIONARY
	):
		return

	var wedding: Dictionary = (
		wedding_meta as Dictionary
	)
	var honeymoon: Dictionary = (
		honeymoon_meta as Dictionary
	)


	_on_action_pressed({
		"action_id": (
			"relationship_contract:commit_marriage_plan"
		),
		"target_id": int(
			row.get(
				"target_id",
				-1
			)
		),
		"wedding_type_id": str(
			wedding.get(
				"id",
				""
			)
		),
		"honeymoon_realm_id": int(
			str(
				honeymoon.get(
					"id",
					"-1"
				)
			)
		),
		"request_prenup": (
			prenup_check != null
			and prenup_check.button_pressed
		),
		"immutable_contract_references": true,
		"ui_is_expression_only": true
	})
func _queue_card_surface_install(
	grid: GridContainer,
	card_contract: Dictionary,
	card_kind: String
) -> void:
	if (
		grid == null
		or not is_instance_valid(
			grid
		)
		or card_contract.is_empty()
	):
		return

	pending_card_surface_install_queue.append({
		"grid": grid,
		"card_contract": card_contract.duplicate(false),
		"card_kind": str(
			card_kind
		).strip_edges().to_lower(),
		"queued_at_ms": int(
			Time.get_ticks_msec()
		)
	})
	set_meta(
		"card_surface_install_queue_size",
		pending_card_surface_install_queue.size()
	)
	set_meta(
		"card_surface_install_is_cooperative",
		true
	)
	set_meta(
		"card_surface_install_one_card_per_frame",
		false
	)
	set_meta(
		"card_surface_install_adaptive_frame_cadence",
		true
	)
	set_meta(
		"card_surface_install_requires_input_idle",
		false
	)
	set_meta(
		"card_surface_install_build_on_click",
		false
	)
	set_meta(
		"card_surface_install_ready_gate_member",
		false
	)

	if panel_kind == "relationships":
		set_meta(
			"relationship_full_card_queue_enabled",
			true
		)
		set_meta(
			"relationship_full_card_queue_engine_calls",
			false
		)
		set_meta(
			"relationship_full_card_queue_hidden_prewarm",
			not visible
		)
		set_meta(
			"relationship_full_card_queue_ready_gate_member",
			false
		)
		set_meta(
			"relationship_full_card_queue_input_idle_required",
			false
		)
		set_meta(
			"relationship_full_card_queue_adaptive_frame_budget",
			true
		)

	_arm_card_surface_install_service()
func _arm_card_surface_install_service() -> void:
	if card_surface_install_service_active:
		return

	if pending_card_surface_install_queue.is_empty():
		return

	card_surface_install_service_active = true
	process_mode = Node.PROCESS_MODE_INHERIT

	call_deferred(
		"_service_card_surface_install_queue"
	)


func _service_card_surface_install_queue() -> void:
	var tree:= get_tree()

	while not pending_card_surface_install_queue.is_empty():
		if tree == null:
			card_surface_install_service_active = false
			return




		if (
			panel_kind == "relationships"
			and _ancestor_renderer_present_fence_active()
		):
			set_meta(
				"card_surface_install_paused_for_present_fence",
				true
			)
			set_meta(
				"card_surface_install_present_fence_blocks_input",
				false
			)

			await tree.process_frame
			continue




		await RenderingServer.frame_post_draw



		if (
			panel_kind == "relationships"
			and _ancestor_renderer_present_fence_active()
		):
			await tree.process_frame
			continue

		set_meta(
			"card_surface_install_paused_for_present_fence",
			false
		)

		var entry_raw: Variant = (
			pending_card_surface_install_queue.pop_front()
		)

		if typeof(
			entry_raw
		) != TYPE_DICTIONARY:
			continue

		var entry: Dictionary = (
			entry_raw as Dictionary
		)

		var grid_raw: Variant = entry.get(
			"grid",
			null
		)

		if (
			typeof(
				grid_raw
			) != TYPE_OBJECT
			or not is_instance_valid(
				grid_raw
			)
			or not (
				grid_raw is GridContainer
			)
		):
			continue

		var grid: GridContainer = (
			grid_raw as GridContainer
		)

		if grid.is_queued_for_deletion():
			continue

		var card_contract_raw: Variant = entry.get(
			"card_contract",
			{}
		)

		if typeof(
			card_contract_raw
		) != TYPE_DICTIONARY:
			continue

		var card_contract: Dictionary = (
			card_contract_raw as Dictionary
		)

		if card_contract.is_empty():
			continue

		var build_started_usec: int = int(
			Time.get_ticks_usec()
		)
		var card_node: Control = null
		var card_kind: String = str(
			entry.get(
				"card_kind",
				"person"
			)
		).strip_edges().to_lower()

		if card_kind == "entity":
			card_node = _build_entity_card(
				card_contract
			)
		else:
			card_node = _build_person_card(
				card_contract
			)

		if (
			card_node != null
			and is_instance_valid(
				card_node
			)
		):
			grid.add_child(
				card_node
			)

		var build_cost_usec: int = maxi(
			0,
			int(
				Time.get_ticks_usec()
			) - build_started_usec
		)
		var cooldown_frames: int = 1







		if panel_kind == "relationships":
			var amortized_budget_usec: int = 900

			cooldown_frames = clampi(
				int(
					ceil(
						float(
							maxi(
								build_cost_usec,
								1
							)
						)
						/ float(
							amortized_budget_usec
						)
					)
				),
				1,
				8
			)

		set_meta(
			"card_surface_install_last_at_ms",
			int(
				Time.get_ticks_msec()
			)
		)
		set_meta(
			"card_surface_install_last_build_cost_usec",
			build_cost_usec
		)
		set_meta(
			"card_surface_install_last_cooldown_frames",
			cooldown_frames
		)
		set_meta(
			"card_surface_install_queue_size",
			pending_card_surface_install_queue.size()
		)
		set_meta(
			"card_surface_install_requires_input_idle",
			false
		)
		set_meta(
			"card_surface_install_continues_during_interaction",
			true
		)
		set_meta(
			"card_surface_install_adaptive_frame_cadence",
			panel_kind == "relationships"
		)

		for _cooldown_index in range(
			cooldown_frames
		):
			if tree == null:
				card_surface_install_service_active = false
				return

			await tree.process_frame

	card_surface_install_service_active = false

	set_meta(
		"card_surface_install_complete",
		true
	)
	set_meta(
		"card_surface_install_completed_at_ms",
		int(
			Time.get_ticks_msec()
		)
	)

	if (
		not visible
		and not pending_section_surface_service_active
		and pending_section_surface_order.is_empty()
	):
		process_mode = Node.PROCESS_MODE_DISABLED
func stream_section_contract_background(
	section_id: String,
	section_contract: Dictionary
) -> bool:
	var clean_section_id: String = str(
		section_id
	).strip_edges().to_lower()

	if (
		clean_section_id == ""
		or section_contract.is_empty()
	):
		return false

	if panel_kind == "relationships":
		var incoming_actor_id: int = int(
			section_contract.get(
				"actor_id",
				active_actor_id
			)
		)
		var required_actor_id: int = int(
			get_meta(
				"resident_required_actor_id",
				active_actor_id
			)
		)
		var required_world_year: int = int(
			get_meta(
				"resident_required_world_year",
				-999999
			)
		)
		var incoming_wrapper: Dictionary = {
			"actor_id": incoming_actor_id,
			"active_section_id": clean_section_id,
			"section_contracts": {
				clean_section_id: section_contract
			}
		}
		var incoming_world_year: int = (
			_relationship_observation_contract_world_year(
				incoming_wrapper
			)
		)


		if (
			required_actor_id > 0
			and incoming_actor_id > 0
			and incoming_actor_id != required_actor_id
		):
			set_meta(
				"relationship_section_successor_actor_rejected",
				true
			)
			set_meta(
				"relationship_section_successor_actor_id",
				incoming_actor_id
			)
			set_meta(
				"relationship_section_required_actor_id",
				required_actor_id
			)
			set_meta(
				"relationship_section_successor_contract_mutated",
				false
			)
			return false



		if (
			incoming_world_year != -999999
			and required_world_year != -999999
			and incoming_world_year < required_world_year
		):
			set_meta(
				"relationship_stale_section_install_rejected",
				true
			)
			set_meta(
				"relationship_stale_section_install_id",
				clean_section_id
			)
			set_meta(
				"relationship_stale_section_install_world_year",
				incoming_world_year
			)
			set_meta(
				"relationship_stale_section_required_world_year",
				required_world_year
			)
			set_meta(
				"relationship_stale_section_contract_mutated",
				false
			)
			return false









		if (
			incoming_world_year != -999999
			and (
				required_world_year == -999999
				or incoming_world_year > required_world_year
			)
		):
			set_meta(
				"resident_required_world_year",
				incoming_world_year
			)
			set_meta(
				"relationship_observation_frontier_advanced_by_successor",
				true
			)
			set_meta(
				"relationship_observation_frontier_previous_year",
				required_world_year
			)
			set_meta(
				"relationship_observation_frontier_current_year",
				incoming_world_year
			)
			set_meta(
				"relationship_observation_frontier_old_packet_mutated",
				false
			)
			set_meta(
				"relationship_observation_frontier_engine_calls",
				false
			)

	section_contracts [
		clean_section_id
	] = section_contract.duplicate(false)

	if not active_contract.is_empty():


		var next_active_contract: Dictionary = (
			active_contract.duplicate(false)
		)

		var next_section_contracts: Dictionary = _dict(
			next_active_contract.get(
				"section_contracts",
				{}
			)
		).duplicate(false)

		next_section_contracts [
			clean_section_id
		] = section_contract.duplicate(false)

		next_active_contract [
			"section_contracts"
		] = next_section_contracts

		if (
			str(
				next_active_contract.get(
					"active_section_id",
					next_active_contract.get(
						"active_section",
						active_section_id
					)
				)
			).strip_edges().to_lower()
			== clean_section_id
		):
			next_active_contract [
				"groups"
			] = _array(
				section_contract.get(
					"groups",
					[]
				)
			).duplicate(false)

			next_active_contract [
				"truth_state"
			] = str(
				section_contract.get(
					"truth_state",
					"hot"
				)
			)
			next_active_contract [
				"projection_pending"
			] = bool(
				section_contract.get(
					"projection_pending",
					false
				)
			)
			next_active_contract [
				"projection_complete"
			] = bool(
				section_contract.get(
					"projection_complete",
					section_contract.get(
						"section_projection_complete",
						false
					)
				)
			)

		var successor_revision: String = str(
			section_contract.get(
				"surface_revision",
				""
			)
		).strip_edges()

		if successor_revision != "":
			next_active_contract [
				"surface_revision"
			] = successor_revision

		next_active_contract [
			"relationship_observation_successor"
		] = (
			panel_kind == "relationships"
		)
		next_active_contract [
			"relationship_observation_successor_mutates_old_packet"
		] = false

		active_contract = next_active_contract

	if surface_prepared:
		process_mode = (
			Node.PROCESS_MODE_INHERIT
		)

	_queue_section_surface_contract(
		clean_section_id,
		section_contract,
		clean_section_id == active_section_id
	)

	_arm_section_surface_contract_service()

	set_meta(
		"background_section_contract_last_id",
		clean_section_id
	)
	set_meta(
		"background_section_contract_last_at_ms",
		int(
			Time.get_ticks_msec()
		)
	)
	set_meta(
		"background_section_contract_engine_calls",
		false
	)
	set_meta(
		"background_section_contract_requires_input_idle",
		false
	)
	set_meta(
		"background_section_contract_old_packet_mutated",
		false
	)
	set_meta(
		"background_section_contract_successor_pointer_only",
		true
	)

	return true
func prepare_observable_actor_shell(
	actor_id: int,
	message: String = (
		"Live truth is publishing into this surface."
	)
) -> void:
	prepare_surface(
		panel_kind
	)

	if has_renderable_contract(
		actor_id
	):
		return

	active_contract = {}
	active_actor_id = actor_id
	active_section_id = _default_section()
	section_contracts.clear()
	tab_contract_by_section.clear()

	_render_tabs([])
	_render_observable_partial(
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
	set_meta(
		"observable_actor_shell_engine_calls",
		false
	)
func _render_people_group_into(
	root: VBoxContainer,
	group: Dictionary
) -> void:
	var title_text: String = str(
		group.get(
			"title",
			"People"
		)
	)

	var subtitle_text: String = str(
		group.get(
			"subtitle",
			""
		)
	).strip_edges()

	var cards: Array = _array(
		group.get(
			"cards",
			group.get(
				"people",
				[]
			)
		)
	)

	_add_section_heading_to(
		root,
		title_text,
		subtitle_text
	)

	if cards.is_empty():
		_add_info_card_to(
			root,
			title_text,
			[
				str(
					group.get(
						"empty_text",
						"None"
					)
				)
			]
		)
		return

	var columns: int = clampi(
		int(
			group.get(
				"columns",
				3
			)
		),
		1,
		4
	)

	var grid:= GridContainer.new()
	grid.columns = columns
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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

	for raw_card in cards:
		var card_contract: Dictionary = _dict(
			raw_card
		)

		if card_contract.is_empty():
			continue

		var card_kind: String = "person"

		if panel_kind == "relationships":
			card_kind = str(
				card_contract.get(
					"card_kind",
					""
				)
			).strip_edges().to_lower()

			if card_kind == "":
				card_kind = (
					"entity"
					if card_contract.has(
						"target_entity_id"
					)
					else "person"
				)

		if panel_kind != "relationships":
			grid.add_child(
				_build_person_card(
					card_contract
				)
			)
			continue





		_queue_card_surface_install(
			grid,
			card_contract,
			card_kind
		)

func _render_entity_group_into(
	root: VBoxContainer,
	group: Dictionary
) -> void:
	var cards: Array = _array(
		group.get(
			"cards",
			group.get(
				"entities",
				[]
			)
		)
	)

	_add_section_heading_to(
		root,
		str(
			group.get(
				"title",
				"Entities"
			)
		),
		str(
			group.get(
				"subtitle",
				""
			)
		)
	)

	if cards.is_empty():
		_add_info_card_to(
			root,
			str(
				group.get(
					"title",
					"Entities"
				)
			),
			[
				str(
					group.get(
						"empty_text",
						"None"
					)
				)
			]
		)
		return

	var grid:= GridContainer.new()
	grid.columns = clampi(
		int(
			group.get(
				"columns",
				3
			)
		),
		1,
		4
	)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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

	var first_relationship_card_installed: bool = false

	for raw_card in cards:
		var card_contract: Dictionary = _dict(
			raw_card
		)

		if card_contract.is_empty():
			continue

		if panel_kind != "relationships":
			grid.add_child(
				_build_entity_card(
					card_contract
				)
			)
			continue

		if not first_relationship_card_installed:
			grid.add_child(
				_build_entity_card(
					card_contract
				)
			)
			first_relationship_card_installed = true
			continue

		_queue_card_surface_install(
			grid,
			card_contract,
			"entity"
		)


func _render_communal_zone_into(root: VBoxContainer, row: Dictionary) -> void:
	_add_section_heading_to(
		root,
		str(row.get("title", "Communal / Lunch Area")),
		str(row.get("subtitle", "Students interact alone and in groups."))
	)

	var atmosphere_lines: Array = []
	var friendliness_label: String = str(row.get("friendliness_label", "")).strip_edges()
	var friendliness_description: String = (
		str(row.get("friendliness_description", "")).strip_edges()
	)

	if friendliness_label != "":
		atmosphere_lines.append("Social temperature: %s" % friendliness_label)

	if friendliness_description != "":
		atmosphere_lines.append(friendliness_description)

	if not atmosphere_lines.is_empty():
		_add_info_card_to(root, "Live Communal Climate", atmosphere_lines)

	var social_groups: Array = _array(row.get("social_groups", row.get("groups", [])))

	if not social_groups.is_empty():
		_add_section_heading_to(
			root,
			"Visible Social Groups",
			"These groups are an already-resolved SchoolEngine projection."
		)

		var group_grid:= GridContainer.new()
		group_grid.columns = clampi(int(row.get("group_columns", 2)), 1, 3)
		group_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		group_grid.add_theme_constant_override("h_separation", 10)
		group_grid.add_theme_constant_override("v_separation", 10)
		root.add_child(group_grid)

		for raw_group in social_groups:
			var social_group: Dictionary = _dict(raw_group)

			if social_group.is_empty():
				continue

			group_grid.add_child(_build_social_group_card(social_group))

	var people: Array = _array(row.get("people", []))

	_add_section_heading_to(
		root,
		"Students In The Area",
		"Every card remains independently observable, even when the student belongs to a group."
	)

	if people.is_empty():
		_add_info_card_to(
			root, "Communal Area", ["No students are currently visible in this area."]
		)
		return

	var people_grid:= GridContainer.new()
	people_grid.columns = clampi(int(row.get("columns", 3)), 1, 4)
	people_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	people_grid.add_theme_constant_override("h_separation", 10)
	people_grid.add_theme_constant_override("v_separation", 10)
	root.add_child(people_grid)

	for raw_person in people:
		var person_contract: Dictionary = _dict(raw_person)

		if person_contract.is_empty():
			continue

		people_grid.add_child(_build_person_card(person_contract))


func _render_class_zone_into(root: VBoxContainer, row: Dictionary) -> void:
	_add_section_heading_to(
		root,
		str(row.get("title", row.get("name", "Class"))),
		str(row.get("subtitle", "A live school class projection."))
	)

	var teachers: Array = _array(row.get("teachers", []))
	var students: Array = _array(row.get("students", []))

	if not teachers.is_empty():
		_render_people_group_into(
			root,
			{
				"row_kind": "people_group",
				"title": "Teachers",
				"cards": teachers,
				"columns": 2,
				"empty_text": "No teacher is currently visible."
			}
		)

	_render_people_group_into(
		root,
		{
			"row_kind": "people_group",
			"title": "Students",
			"cards": students,
			"columns": int(row.get("columns", 3)),
			"empty_text": "No students are currently visible in this class."
		}
	)


func _render_school_options_into(root: VBoxContainer, row: Dictionary) -> void:
	_add_section_heading_to(
		root,
		str(row.get("title", "Available Schools")),
		str(row.get("subtitle", "Enrollment options are emitted by SchoolEngine."))
	)

	var options: Array = _array(row.get("options", []))

	if options.is_empty():
		_add_info_card_to(
			root,
			"Enrollment",
			[str(row.get("empty_text", "No school options are currently observable."))]
		)
		return

	var grid:= GridContainer.new()
	grid.columns = clampi(int(row.get("columns", 2)), 1, 3)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	root.add_child(grid)

	for raw_option in options:
		var option: Dictionary = _dict(raw_option)

		if option.is_empty():
			continue

		grid.add_child(_build_school_option_card(option))


func _render_social_memory_into(root: VBoxContainer, row: Dictionary) -> void:
	var memories: Array = _array(row.get("memories", row.get("rows", [])))
	var lines: Array = []

	for raw_memory in memories:
		if typeof(raw_memory) == TYPE_DICTIONARY:
			var memory: Dictionary = raw_memory as Dictionary
			lines.append(str(memory.get("text", memory.get("description", ""))))
		else:
			lines.append(str(raw_memory))

	_add_info_card_to(root, str(row.get("title", "School Social Memory")), lines)


func _render_actions_into(root: VBoxContainer, row: Dictionary) -> void:
	_add_section_heading_to(
		root,
		str(row.get("title", "Actions")),
		str(row.get("subtitle", "The panel emits expressions. Contract engines commit reality."))
	)

	var actions: Array = _array(row.get("actions", []))
	var action_grid:= GridContainer.new()
	action_grid.columns = clampi(int(row.get("columns", 2)), 1, 3)
	action_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_grid.add_theme_constant_override("h_separation", 8)
	action_grid.add_theme_constant_override("v_separation", 8)
	root.add_child(action_grid)

	for raw_action in actions:
		var action: Dictionary = _dict(raw_action)

		if action.is_empty():
			continue

		var button:= Button.new()
		button.text = str(action.get("label", action.get("title", "Action")))
		button.disabled = not bool(action.get("enabled", true))
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(0.0, 42.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_style_action_button(button)
		button.pressed.connect(_on_action_pressed.bind(action.duplicate(true)))
		action_grid.add_child(button)


func _build_person_card(
	contract: Dictionary
) -> PanelContainer:
	var card:= PanelContainer.new()

	card.name = (
		"PersonCard_%s"
		% _safe_name(
			str(
				contract.get(
					"target_id",
					contract.get(
						"person_id",
						"unknown"
					)
				)
			)
		)
	)
	card.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	card.custom_minimum_size = Vector2(
		0.0,
		float(
			contract.get(
				"card_minimum_height",
				232.0
			)
		)
	)
	card.mouse_filter = (
		Control.MOUSE_FILTER_PASS
	)

	var state: String = str(
		contract.get(
			"state",
			"warm"
		)
	).strip_edges().to_lower()
	var section_key: String = str(
		contract.get(
			"section_key",
			active_section_id
		)
	).strip_edges().to_lower()
	var palette: Dictionary = _card_palette(
		contract,
		section_key,
		state
	)
	var surface_contract: Dictionary = _dict(
		contract.get(
			"surface_contract",
			{}
		)
	)
	var is_relationship_card: bool = (
		panel_kind == "relationships"
		and contract.has("bond")
	)
	var bond_ratio: float = clampf(
		float(
			surface_contract.get(
				"glow_intensity",
				float(
					contract.get(
						"bond",
						0
					)
				) / 100.0
			)
		),
		0.0,
		1.0
	)
	var card_style: StyleBoxFlat = _card_style(
		palette,
		bool(
			contract.get(
				"featured",
				false
			)
		),
		is_relationship_card,
		bond_ratio
	)

	card.add_theme_stylebox_override(
		"panel",
		card_style
	)

	var margin:= MarginContainer.new()

	margin.add_theme_constant_override(
		"margin_left",
		16
	)
	margin.add_theme_constant_override(
		"margin_top",
		14
	)
	margin.add_theme_constant_override(
		"margin_right",
		16
	)
	margin.add_theme_constant_override(
		"margin_bottom",
		14
	)
	card.add_child(margin)

	var box:= VBoxContainer.new()

	box.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	box.add_theme_constant_override(
		"separation",
		8
	)
	margin.add_child(box)

	var title_text: String = str(
		contract.get(
			"display_line",
			surface_contract.get(
				"card_title",
				contract.get(
					"target_name_with_age",
					contract.get(
						"full_name",
						contract.get(
							"target_name",
							"Person"
						)
					)
				)
			)
		)
	)
	var title:= Label.new()

	title.text = title_text
	title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	title.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	title.add_theme_font_size_override(
		"font_size",
		18
	)
	title.add_theme_color_override(
		"font_color",
		_color_from_variant(
			palette.get(
				"font_color",
				Color.WHITE
			),
			Color.WHITE
		)
	)
	title.add_theme_color_override(
		"font_shadow_color",
		Color(
			0.0,
			0.0,
			0.0,
			0.72
		)
	)
	title.add_theme_constant_override(
		"shadow_offset_y",
		2
	)
	box.add_child(title)

	var subtitle_text: String = str(
		contract.get(
			"role",
			contract.get(
				"relationship_type",
				contract.get(
					"activity",
					surface_contract.get(
						"subtitle",
						""
					)
				)
			)
		)
	).strip_edges()

	if subtitle_text != "":
		var subtitle:= Label.new()

		subtitle.text = subtitle_text
		subtitle.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_CENTER
		)
		subtitle.autowrap_mode = (
			TextServer.AUTOWRAP_WORD_SMART
		)
		subtitle.add_theme_font_size_override(
			"font_size",
			12
		)
		subtitle.add_theme_color_override(
			"font_color",
			Color(
				1.0,
				0.72,
				0.88,
				1.0
			)
		)
		box.add_child(subtitle)

	if contract.has("bond"):
		_add_metric_bar(
			box,
			"BOND",
			float(
				contract.get(
					"bond",
					0
				)
			),
			100.0,
			Color(
				1.0,
				0.34,
				0.7,
				1.0
			),
			"How strong and secure this relationship feels."
		)

	if contract.has("health"):
		_add_metric_bar(
			box,
			"HEALTH",
			float(
				contract.get(
					"health",
					0
				)
			),
			maxf(
				1.0,
				float(
					contract.get(
						"health_max",
						100
					)
				)
			),
			Color(
				0.98,
				0.22,
				0.29,
				1.0
			),
			"Their current physical condition and vitality."
		)

	if contract.has("popularity"):
		_add_metric_bar(
			box,
			"POPULARITY",
			float(
				contract.get(
					"popularity",
					0
				)
			),
			100.0,
			Color(
				0.82,
				0.6,
				1.0,
				1.0
			),
			"How widely known and socially favored they are."
		)

	if contract.has("friendliness"):
		_add_metric_bar(
			box,
			"FRIENDLINESS",
			float(
				contract.get(
					"friendliness",
					50
				)
			),
			100.0,
			Color(
				0.52,
				0.78,
				1.0,
				1.0
			),
			"How open, warm, and approachable they currently feel."
		)

	var social_group: Array = _array(
		contract.get(
			"social_group",
			[]
		)
	)

	if not social_group.is_empty():
		var group_label:= Label.new()

		group_label.text = (
			"WITH: %s"
			% _join_strings(
				social_group,
				", "
			)
		)
		group_label.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_CENTER
		)
		group_label.autowrap_mode = (
			TextServer.AUTOWRAP_WORD_SMART
		)
		group_label.add_theme_font_size_override(
			"font_size",
			10
		)
		group_label.add_theme_color_override(
			"font_color",
			Color(
				0.72,
				0.74,
				0.84,
				1.0
			)
		)
		box.add_child(group_label)

	var target_id: int = int(
		contract.get(
			"target_id",
			contract.get(
				"person_id",
				-1
			)
		)
	)
	var is_self: bool = bool(
		contract.get(
			"is_self",
			false
		)
	)
	var interaction_contract: Dictionary = _dict(
		contract.get(
			"interaction_contract",
			{}
		)
	)
	var can_open: bool = bool(
		interaction_contract.get(
			"can_open_profile",
			target_id > 0 and not is_self
		)
	)

	if target_id > 0 and can_open:
		var open_button:= Button.new()

		open_button.text = str(
			contract.get(
				"button_text",
				surface_contract.get(
					"button_text",
					"Open full relationship profile"
				)
			)
		)
		open_button.focus_mode = (
			Control.FOCUS_NONE
		)
		open_button.custom_minimum_size = Vector2(
			0.0,
			40.0
		)
		open_button.mouse_default_cursor_shape = (
			Control.CURSOR_POINTING_HAND
		)

		_style_action_button(
			open_button
		)



		open_button.pressed.connect(
			_on_person_pressed.bind(
				target_id,
				contract.duplicate(false)
			)
		)
		box.add_child(open_button)

	animated_cards.append(
		{
			"kind": "card",
			"card": card,
			"style": card_style,
			"relationship_card": is_relationship_card,
			"bond_ratio": bond_ratio,
			"base_border_color": card_style.border_color,
			"base_modulate": Color(
				0.98,
				0.98,
				1.0,
				1.0
			),
			"hover_modulate": Color.WHITE
		}
	)

	return card


func _build_entity_card(contract: Dictionary) -> PanelContainer:
	var normalized: Dictionary = contract.duplicate(true)

	if not normalized.has("target_name"):
		normalized ["target_name"] = str(normalized.get("name", "Entity"))

	if not normalized.has("target_id"):
		normalized ["target_id"] = int(normalized.get("person_id", -1))

	return _build_person_card(normalized)


func _build_social_group_card(contract: Dictionary) -> PanelContainer:
	var card:= PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0.0, 112.0)
	card.add_theme_stylebox_override(
		"panel",
		_card_style(
			{
				"accent": Color(0.55, 0.74, 1.0, 1.0),
				"fill": Color(0.045, 0.065, 0.115, 0.98),
				"font_color": Color.WHITE
			},
			false
		)
	)

	var margin:= MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var box:= VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	margin.add_child(box)

	var title:= Label.new()
	title.text = str(contract.get("title", "Conversation Group"))
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color.WHITE)
	box.add_child(title)

	var members: Array = _array(contract.get("member_names", contract.get("members", [])))
	var description:= Label.new()
	description.text = str(contract.get("description", _join_strings(members, ", ")))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 12)
	description.add_theme_color_override("font_color", Color(0.75, 0.8, 0.92, 1.0))
	box.add_child(description)

	animated_cards.append(
		{ "card": card, "base_modulate": Color(0.98, 0.98, 1.0, 1.0), "hover_modulate": Color.WHITE}
	)

	return card


func _build_school_option_card(option: Dictionary) -> PanelContainer:
	var card:= PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0.0, 154.0)
	card.add_theme_stylebox_override(
		"panel",
		_card_style(
			{
				"accent": Color(0.46, 0.72, 1.0, 1.0),
				"fill": Color(0.04, 0.058, 0.105, 0.98),
				"font_color": Color.WHITE
			},
			false
		)
	)

	var margin:= MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var box:= VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	var title:= Label.new()
	title.text = str(option.get("school_name", option.get("title", "School")))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color.WHITE)
	box.add_child(title)

	var mode_label:= Label.new()
	mode_label.text = str(
		option.get(
			"display_line",
			option.get("description", str(option.get("mode", "School")).capitalize())
		)
	)
	mode_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mode_label.add_theme_font_size_override("font_size", 12)
	mode_label.add_theme_color_override("font_color", Color(0.76, 0.8, 0.92, 1.0))
	box.add_child(mode_label)

	var action: Dictionary = _dict(
		option.get(
			"action",
			{
				"action_id": "enroll",
				"school_name": str(option.get("school_name", "")),
				"school_mode": str(option.get("mode", "era_school")),
				"ui_is_expression_only": true
			}
		)
	)
	var button:= Button.new()
	button.text = str(action.get("label", "Enroll"))
	button.disabled = not bool(action.get("enabled", true))
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0.0, 38.0)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_action_button(button)
	button.pressed.connect(_on_action_pressed.bind(action.duplicate(true)))
	box.add_child(button)

	animated_cards.append(
		{ "card": card, "base_modulate": Color(0.98, 0.98, 1.0, 1.0), "hover_modulate": Color.WHITE}
	)

	return card


func _add_section_heading_to(
	root: VBoxContainer, title_text: String, subtitle_text: String = ""
) -> void:
	var heading:= VBoxContainer.new()
	heading.add_theme_constant_override("separation", 2)
	root.add_child(heading)

	var title:= Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.93, 0.95, 1.0, 1.0))
	heading.add_child(title)

	if subtitle_text.strip_edges() != "":
		var subtitle:= Label.new()
		subtitle.text = subtitle_text
		subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		subtitle.add_theme_font_size_override("font_size", 11)
		subtitle.add_theme_color_override("font_color", Color(0.68, 0.72, 0.84, 1.0))
		heading.add_child(subtitle)


func _add_info_card_to(root: VBoxContainer, title_text: String, lines: Array) -> void:
	var card:= PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _info_card_style())
	root.add_child(card)

	var margin:= MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var box:= VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	margin.add_child(box)

	var title:= Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0, 1.0))
	box.add_child(title)

	var rendered_line_count: int = 0

	for raw_line in lines:
		var line_text: String = str(raw_line).strip_edges()

		if line_text == "":
			continue

		var line:= Label.new()
		line.text = line_text
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_theme_font_size_override("font_size", 12)
		line.add_theme_color_override("font_color", Color(0.75, 0.78, 0.88, 1.0))
		box.add_child(line)
		rendered_line_count += 1

	if rendered_line_count == 0:
		var empty:= Label.new()
		empty.text = "No observable entries."
		empty.add_theme_font_size_override("font_size", 12)
		empty.add_theme_color_override("font_color", Color(0.62, 0.66, 0.76, 1.0))
		box.add_child(empty)


func _add_metric_bar(
	root: VBoxContainer,
	label_text: String,
	value: float,
	maximum: float,
	accent: Color,
	description_text: String = ""
) -> void:
	var metric_root:= VBoxContainer.new()

	metric_root.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	metric_root.add_theme_constant_override(
		"separation",
		3
	)
	root.add_child(metric_root)

	var label:= Label.new()

	label.text = label_text
	label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	label.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	label.add_theme_font_size_override(
		"font_size",
		11
	)
	label.add_theme_color_override(
		"font_color",
		Color(
			0.94,
			0.88,
			0.96,
			1.0
		)
	)
	metric_root.add_child(label)

	if description_text.strip_edges() != "":
		var description:= Label.new()

		description.text = description_text
		description.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_CENTER
		)
		description.autowrap_mode = (
			TextServer.AUTOWRAP_WORD_SMART
		)
		description.add_theme_font_size_override(
			"font_size",
			9
		)
		description.add_theme_color_override(
			"font_color",
			Color(
				0.68,
				0.69,
				0.8,
				0.92
			)
		)
		metric_root.add_child(description)

	var clean_maximum: float = maxf(
		1.0,
		maximum
	)
	var clean_value: float = clampf(
		value,
		0.0,
		clean_maximum
	)
	var ratio: float = clampf(
		clean_value / clean_maximum,
		0.0,
		1.0
	)
	var bar_stack:= Control.new()

	bar_stack.custom_minimum_size = Vector2(
		0.0,
		24.0
	)
	bar_stack.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	bar_stack.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	metric_root.add_child(bar_stack)

	var fill_style: StyleBoxFlat = (
		_metric_fill_style(accent)
	)
	var bar:= ProgressBar.new()

	bar.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	bar.min_value = 0.0
	bar.max_value = clean_maximum
	bar.value = clean_value
	bar.show_percentage = false
	bar.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	bar.add_theme_stylebox_override(
		"background",
		_metric_background_style()
	)
	bar.add_theme_stylebox_override(
		"fill",
		fill_style
	)
	bar_stack.add_child(bar)

	var inside_label:= Label.new()

	inside_label.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	inside_label.text = (
		"%d"
		% int(round(clean_value))
	)
	inside_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	inside_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)
	inside_label.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	inside_label.add_theme_font_size_override(
		"font_size",
		11
	)
	inside_label.add_theme_color_override(
		"font_color",
		Color.WHITE
	)
	inside_label.add_theme_color_override(
		"font_shadow_color",
		Color(
			0.0,
			0.0,
			0.0,
			0.92
		)
	)
	inside_label.add_theme_constant_override(
		"shadow_offset_x",
		1
	)
	inside_label.add_theme_constant_override(
		"shadow_offset_y",
		1
	)
	bar_stack.add_child(inside_label)






	if panel_kind != "relationships":
		animated_cards.append(
			{
				"kind": "metric",
				"control": bar_stack,
				"fill_style": fill_style,
				"base_fill_color": accent,
				"ratio": ratio,
				"metric_id": label_text.strip_edges().to_lower()
			}
		)

func _render_header_chip(contract: Dictionary) -> void:
	var chip_text: String = (
		str(contract.get("header_chip_text", contract.get("subtitle", ""))).strip_edges()
	)

	header_chip.visible = chip_text != ""
	header_chip_label.text = chip_text

func _ensure_section_surface_placeholder(
	section_id: String,
	label_text: String
) -> void:
	if (
		section_surface_host == null
		or not is_instance_valid(
			section_surface_host
		)
	):
		return

	var clean_section: String = str(
		section_id
	).strip_edges().to_lower()

	if clean_section == "":
		return

	var existing_raw: Variant = section_surface_deck.get(
		clean_section,
		null
	)

	if (
		typeof(
			existing_raw
		) == TYPE_OBJECT
		and is_instance_valid(
			existing_raw
		)
		and existing_raw is Control
	):
		return

	section_surface_deck.erase(
		clean_section
	)
	section_scroll_deck.erase(
		clean_section
	)
	section_surface_revision_by_id.erase(
		clean_section
	)

	var section_scroll:= ScrollContainer.new()
	section_scroll.name = (
		"SectionPlaceholder_%s"
		% _safe_name(
			clean_section
		)
	)
	section_scroll.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	section_scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)
	section_scroll.vertical_scroll_mode = (
		ScrollContainer.SCROLL_MODE_AUTO
	)
	section_scroll.follow_focus = false
	section_scroll.clip_contents = true
	section_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	section_scroll.visible = false

	var content_margin:= MarginContainer.new()
	content_margin.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	content_margin.add_theme_constant_override(
		"margin_left",
		8
	)
	content_margin.add_theme_constant_override(
		"margin_top",
		12
	)
	content_margin.add_theme_constant_override(
		"margin_right",
		12
	)
	content_margin.add_theme_constant_override(
		"margin_bottom",
		12
	)
	section_scroll.add_child(
		content_margin
	)

	var placeholder_label:= Label.new()
	placeholder_label.name = "ResidentSurfaceStatus"
	placeholder_label.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	placeholder_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	placeholder_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	placeholder_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)
	placeholder_label.text = (
		"%s is resident. Its prepared cards are attaching "
		+ "without blocking observation."
	) % (
		label_text
		if label_text.strip_edges() != ""
		else clean_section.capitalize()
	)
	content_margin.add_child(
		placeholder_label
	)

	section_surface_host.add_child(
		section_scroll
	)
	section_surface_deck [
		clean_section
	] = section_scroll
	section_scroll_deck [
		clean_section
	] = section_scroll
	section_surface_revision_by_id [
		clean_section
	] = "__resident_placeholder__"

	set_meta(
		"section_placeholder_surface_created",
		true
	)
	set_meta(
		"section_placeholder_surface_last_id",
		clean_section
	)
	set_meta(
		"section_placeholder_surface_build_on_click",
		false
	)
	set_meta(
		"section_placeholder_surface_ready_gate_member",
		false
	)
func _render_tabs(
	tabs: Array
) -> void:
	_clear_children(
		tab_grid
	)
	tab_button_by_section.clear()
	tab_contract_by_section.clear()

	if tabs.is_empty():
		tab_scroll.visible = false
		return

	tab_scroll.visible = true
	tab_grid.columns = clampi(
		mini(
			tabs.size(),
			4
		),
		1,
		4
	)

	for raw_tab in tabs:
		var tab: Dictionary = _dict(
			raw_tab
		)
		var section_id: String = str(
			tab.get(
				"key",
				tab.get(
					"id",
					""
				)
			)
		).strip_edges().to_lower()

		if section_id == "":
			continue

		var tab_label: String = str(
			tab.get(
				"label",
				section_id.capitalize()
			)
		)

		var button:= Button.new()
		button.name = (
			"Tab_%s"
			% _safe_name(
				section_id
			)
		)
		button.text = tab_label
		button.custom_minimum_size = Vector2(
			146.0,
			40.0
		)
		button.size_flags_horizontal = (
			Control.SIZE_EXPAND_FILL
		)
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.mouse_default_cursor_shape = (
			Control.CURSOR_POINTING_HAND
		)
		button.pressed.connect(
			_on_section_pressed.bind(
				section_id
			)
		)
		tab_grid.add_child(
			button
		)
		tab_button_by_section [
			section_id
		] = button
		tab_contract_by_section [
			section_id
		] = tab.duplicate(true)



		_ensure_section_surface_placeholder(
			section_id,
			tab_label
		)

	_refresh_tab_selection_styles()

	set_meta(
		"all_tab_surfaces_exist_before_input",
		true
	)
	set_meta(
		"tab_click_surface_construction_forbidden",
		true
	)


func _activate_section_surface(
	section_id: String,
	emit_request: bool = true
) -> bool:
	var clean_section: String = str(
		section_id
	).strip_edges().to_lower()

	if clean_section == "":
		clean_section = _default_section()

	if not section_surface_deck.has(
		clean_section
	):
		return false

	var selected_surface_found: bool = false
	var stale_keys: Array = []

	for raw_key in section_surface_deck.keys():
		var key: String = str(
			raw_key
		)
		var surface_raw: Variant = section_surface_deck.get(
			raw_key,
			null
		)

		if (
			typeof(
				surface_raw
			) != TYPE_OBJECT
			or not is_instance_valid(
				surface_raw
			)
			or not (
				surface_raw is Control
			)
		):
			stale_keys.append(
				raw_key
			)
			continue

		var surface: Control = (
			surface_raw as Control
		)
		var selected: bool = (
			key == clean_section
		)

		surface.visible = selected
		surface.mouse_filter = (
			Control.MOUSE_FILTER_PASS
			if selected
			else Control.MOUSE_FILTER_IGNORE
		)

		if selected:
			selected_surface_found = true

	for stale_key in stale_keys:
		section_surface_deck.erase(
			stale_key
		)
		section_scroll_deck.erase(
			stale_key
		)
		section_surface_revision_by_id.erase(
			stale_key
		)

	if not selected_surface_found:
		return false

	active_section_id = clean_section
	active_contract [
		"active_section_id"
	] = clean_section
	_refresh_tab_selection_styles()
	set_meta(
		"active_section_id",
		clean_section
	)

	if emit_request:
		section_requested.emit(
			clean_section
		)

	return true

func _refresh_tab_selection_styles() -> void:
	for raw_section_id in tab_button_by_section.keys():
		var section_id: String = str(raw_section_id)
		var button:= tab_button_by_section.get(raw_section_id, null) as Button

		if button == null or not is_instance_valid(button):
			continue

		var tab: Dictionary = _dict(tab_contract_by_section.get(raw_section_id, {}))
		_style_tab_button(button, tab, section_id == active_section_id)


func _style_tab_button(button: Button, tab: Dictionary, selected: bool) -> void:
	var palette: Dictionary = _dict(tab.get("palette", {}))

	if palette.is_empty():
		palette = (
			_relationship_palette(str(tab.get("key", active_section_id)))
			if panel_kind == "relationships"
			else _school_palette()
		)

	var accent: Color = _color_from_variant(palette.get("accent", _accent_color()), _accent_color())
	var normal_fill: Color = _color_from_variant(
		palette.get(
			"active_fill" if selected else "inactive_fill", Color(0.055, 0.06, 0.1, 0.96)
		),
		Color(0.055, 0.06, 0.1, 0.96)
	)
	var hover_fill: Color = _color_from_variant(
		palette.get("hover_fill", normal_fill.lerp(accent, 0.12)), normal_fill.lerp(accent, 0.12)
	)

	button.add_theme_stylebox_override("normal", _tab_style(normal_fill, accent, selected))
	button.add_theme_stylebox_override("hover", _tab_style(hover_fill, accent, true))
	button.add_theme_stylebox_override("pressed", _tab_style(hover_fill, accent, true))
	button.add_theme_color_override(
		"font_color", _color_from_variant(palette.get("font_color", Color.WHITE), Color.WHITE)
	)
	button.add_theme_color_override("font_hover_color", Color.WHITE)


func _apply_shell_theme() -> void:
	if not surface_prepared:
		return

	dim.color = Color(0.01, 0.012, 0.025, 0.76)
	shell.add_theme_stylebox_override("panel", _shell_style())
	header_chip.add_theme_stylebox_override("panel", _chip_style())
	_style_action_button(close_button)


func _shell_style() -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.024, 0.028, 0.052, 0.985)
	style.border_color = _accent_color()
	_set_uniform_border(style, 2)
	_set_uniform_radius(style, 18)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.58)
	style.shadow_size = 24
	style.shadow_offset = Vector2(0.0, 8.0)
	return style


func _chip_style() -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.06, 0.105, 0.96)
	style.border_color = Color(0.4, 0.48, 0.7, 0.9)
	_set_uniform_border(style, 1)
	_set_uniform_radius(style, 12)
	return style


func _tab_style(fill: Color, accent: Color, glowing: bool) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = accent
	_set_uniform_border(style, 2 if glowing else 1)
	_set_uniform_radius(style, 12)
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.3 if glowing else 0.08)
	style.shadow_size = 12 if glowing else 4
	style.shadow_offset = Vector2(0.0, 2.0)
	return style


func _card_style(
	palette: Dictionary,
	featured: bool,
	relationship_card: bool = false,
	glow_intensity: float = 0.0
) -> StyleBoxFlat:
	var accent: Color = _color_from_variant(
		palette.get(
			"accent",
			_accent_color()
		),
		_accent_color()
	)
	var fill: Color = _color_from_variant(
		palette.get(
			"fill",
			palette.get(
				"active_fill",
				Color(
					0.05,
					0.054,
					0.092,
					0.98
				)
			)
		),
		Color(
			0.05,
			0.054,
			0.092,
			0.98
		)
	)
	var clean_glow: float = clampf(
		glow_intensity,
		0.0,
		1.0
	)
	var style:= StyleBoxFlat.new()

	style.bg_color = fill
	style.border_color = accent

	_set_uniform_border(
		style,
		2 if relationship_card or featured else 1
	)
	_set_uniform_radius(
		style,
		18 if relationship_card else 14
	)

	if relationship_card:
		var relationship_pink:= Color(
			1.0,
			0.3,
			0.68,
			1.0
		)

		style.shadow_color = Color(
			relationship_pink.r,
			relationship_pink.g,
			relationship_pink.b,
			0.06 + (0.48 * clean_glow)
		)
		style.shadow_size = int(
			round(
				7.0 + (17.0 * clean_glow)
			)
		)
		style.shadow_offset = Vector2(
			0.0,
			4.0
		)
	else:
		style.shadow_color = Color(
			accent.r,
			accent.g,
			accent.b,
			0.24 if featured else 0.12
		)
		style.shadow_size = (
			12 if featured else 6
		)
		style.shadow_offset = Vector2(
			0.0,
			3.0
		)

	return style


func _info_card_style() -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.044, 0.076, 0.96)
	style.border_color = Color(0.22, 0.26, 0.4, 0.88)
	_set_uniform_border(style, 1)
	_set_uniform_radius(style, 12)
	return style


func _metric_background_style() -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.02, 0.034, 0.98)
	_set_uniform_radius(style, 6)
	return style


func _metric_fill_style(accent: Color) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = accent
	_set_uniform_radius(style, 6)
	return style


func _style_action_button(button: Button) -> void:
	if button == null:
		return

	var normal:= StyleBoxFlat.new()
	normal.bg_color = Color(0.07, 0.078, 0.13, 0.98)
	normal.border_color = Color(0.34, 0.42, 0.68, 0.92)
	_set_uniform_border(normal, 1)
	_set_uniform_radius(normal, 10)

	var hover:= normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.105, 0.12, 0.2, 1.0)
	hover.border_color = _accent_color()
	hover.shadow_color = Color(0.26, 0.4, 0.92, 0.26)
	hover.shadow_size = 8

	var pressed:= hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.135, 0.15, 0.235, 1.0)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color(0.94, 0.95, 1.0, 1.0))
	button.add_theme_color_override("font_hover_color", Color.WHITE)


func _card_palette(contract: Dictionary, section_key: String, state: String) -> Dictionary:
	var surface_contract: Dictionary = _dict(contract.get("surface_contract", {}))
	var color_signature: Dictionary = _dict(surface_contract.get("color_signature", {}))

	if not color_signature.is_empty():
		return {
			"accent":
			_color_from_variant(
				color_signature.get("accent", color_signature.get("border_color", _accent_color())),
				_accent_color()
			),
			"fill":
			_color_from_variant(
				color_signature.get(
					"fill",
					color_signature.get("background_color", Color(0.05, 0.054, 0.092, 0.98))
				),
				Color(0.05, 0.054, 0.092, 0.98)
			),
			"font_color":
			_color_from_variant(color_signature.get("font_color", Color.WHITE), Color.WHITE)
		}

	if panel_kind == "relationships":
		var palette: Dictionary = _relationship_palette(section_key)

		if state == "conflict":
			palette ["accent"] = Color(1.0, 0.32, 0.34, 1.0)
		elif state == "strained":
			palette ["accent"] = Color(1.0, 0.62, 0.28, 1.0)

		palette ["fill"] = _color_from_variant(
			palette.get("active_fill", Color(0.05, 0.054, 0.092, 0.98)),
			Color(0.05, 0.054, 0.092, 0.98)
		)
		return palette

	var school_palette: Dictionary = _school_palette()
	school_palette ["fill"] = school_palette ["active_fill"]
	return school_palette


func _relationship_palette(section_id: String) -> Dictionary:
	match str(section_id).strip_edges().to_lower():
		"family":
			return {
				"accent": Color(1.0, 0.44, 0.7, 1.0),
				"active_fill": Color(0.105, 0.038, 0.08, 0.98),
				"inactive_fill": Color(0.05, 0.024, 0.048, 0.95),
				"hover_fill": Color(0.145, 0.052, 0.11, 0.98),
				"font_color": Color.WHITE
			}

		"ancestors":
			return {
				"accent": Color(0.9, 0.72, 0.36, 1.0),
				"active_fill": Color(0.105, 0.075, 0.03, 0.98),
				"inactive_fill": Color(0.052, 0.04, 0.02, 0.95),
				"hover_fill": Color(0.14, 0.1, 0.04, 0.98),
				"font_color": Color.WHITE
			}

		"household":
			return {
				"accent": Color(0.52, 0.88, 1.0, 1.0),
				"active_fill": Color(0.035, 0.08, 0.112, 0.98),
				"inactive_fill": Color(0.022, 0.046, 0.062, 0.95),
				"hover_fill": Color(0.05, 0.11, 0.15, 0.98),
				"font_color": Color.WHITE
			}

		"partner":
			return {
				"accent": Color(1.0, 0.34, 0.46, 1.0),
				"active_fill": Color(0.115, 0.03, 0.05, 0.98),
				"inactive_fill": Color(0.058, 0.018, 0.032, 0.95),
				"hover_fill": Color(0.155, 0.046, 0.074, 0.98),
				"font_color": Color.WHITE
			}

		"pets":
			return {
				"accent": Color(0.52, 0.95, 0.62, 1.0),
				"active_fill": Color(0.03, 0.095, 0.05, 0.98),
				"inactive_fill": Color(0.02, 0.05, 0.03, 0.95),
				"hover_fill": Color(0.045, 0.13, 0.07, 0.98),
				"font_color": Color.WHITE
			}

		"descendants":
			return {
				"accent": Color(0.88, 0.6, 1.0, 1.0),
				"active_fill": Color(0.102, 0.052, 0.13, 0.98),
				"inactive_fill": Color(0.052, 0.028, 0.072, 0.95),
				"hover_fill": Color(0.13, 0.062, 0.165, 0.98),
				"font_color": Color.WHITE
			}

		"dead":
			return {
				"accent": Color(0.62, 0.66, 0.74, 1.0),
				"active_fill": Color(0.06, 0.064, 0.074, 0.98),
				"inactive_fill": Color(0.032, 0.034, 0.04, 0.95),
				"hover_fill": Color(0.082, 0.086, 0.1, 0.98),
				"font_color": Color.WHITE
			}

		"social":
			return {
				"accent": Color(0.48, 0.82, 1.0, 1.0),
				"active_fill": Color(0.036, 0.07, 0.115, 0.98),
				"inactive_fill": Color(0.022, 0.04, 0.062, 0.95),
				"hover_fill": Color(0.05, 0.095, 0.15, 0.98),
				"font_color": Color.WHITE
			}

		"exes":
			return {
				"accent": Color(0.98, 0.46, 0.36, 1.0),
				"active_fill": Color(0.11, 0.05, 0.038, 0.98),
				"inactive_fill": Color(0.056, 0.028, 0.022, 0.95),
				"hover_fill": Color(0.145, 0.068, 0.052, 0.98),
				"font_color": Color.WHITE
			}

		_:
			return {
				"accent": Color(1.0, 0.48, 0.72, 1.0),
				"active_fill": Color(0.1, 0.04, 0.085, 0.98),
				"inactive_fill": Color(0.05, 0.022, 0.045, 0.95),
				"hover_fill": Color(0.135, 0.05, 0.095, 0.98),
				"font_color": Color.WHITE
			}


func _school_palette() -> Dictionary:
	return {
		"accent": Color(0.46, 0.72, 1.0, 1.0),
		"active_fill": Color(0.038, 0.07, 0.125, 0.98),
		"inactive_fill": Color(0.024, 0.04, 0.068, 0.95),
		"hover_fill": Color(0.052, 0.098, 0.168, 0.98),
		"font_color": Color.WHITE
	}


func _accent_color() -> Color:
	return (
		Color(1.0, 0.46, 0.72, 1.0)
		if panel_kind == "relationships"
		else Color(0.46, 0.72, 1.0, 1.0)
	)


func _render_observable_partial(message: String) -> void:
	if section_surface_host == null:
		return

	_clear_section_surface_deck()
	var partial_contract: Dictionary = {
		"status_text": message,
		"section_rows":
		[
			{
				"row_kind": "information",
				"title": "%s Reality" % panel_kind.capitalize(),
				"lines": [message]
			}
		]
	}
	var surface: ScrollContainer = _build_section_surface(_default_section(), partial_contract)
	section_surface_host.add_child(surface)
	section_surface_deck [_default_section()] = surface
	section_scroll_deck [_default_section()] = surface
	active_section_id = _default_section()
	_activate_section_surface(active_section_id, false)
	status_label.text = message


func _default_section() -> String:
	return "family" if panel_kind == "relationships" else "overview"


func _on_close_pressed() -> void:
	close_requested.emit()


func _on_section_pressed(
	section_id: String
) -> void:
	var clean_section: String = str(
		section_id
	).strip_edges().to_lower()

	if clean_section == "":
		return

	var pressed_at_ms: int = int(
		Time.get_ticks_msec()
	)
	var revealed: bool = _activate_section_surface(
		clean_section,
		false
	)

	set_meta(
		"last_revealed_section_id",
		clean_section
	)
	set_meta(
		"last_section_press_reveal_succeeded",
		revealed
	)
	set_meta(
		"last_section_press_reveal_only",
		true
	)
	set_meta(
		"last_section_press_emitted_request",
		false
	)
	set_meta(
		"last_section_press_built_surface",
		false
	)
	set_meta(
		"last_section_press_engine_calls",
		false
	)
	set_meta(
		"last_section_press_card_install_quantum",
		false
	)
	set_meta(
		"last_section_press_section_install_quantum",
		false
	)
	set_meta(
		"last_section_press_waited_for_stream",
		false
	)
	set_meta(
		"last_section_press_surface_preexisting",
		revealed
	)
	set_meta(
		"last_section_press_at_ms",
		pressed_at_ms
	)



func _on_person_pressed(
	target_id: int,
	payload: Dictionary
) -> void:
	if target_id <= 0:
		return



	person_requested.emit(
		target_id,
		payload.duplicate(false)
	)


func _on_action_pressed(payload: Dictionary) -> void:
	var expression: Dictionary = payload.duplicate(true)
	expression ["actor_id"] = int(expression.get("actor_id", active_actor_id))
	expression ["section_id"] = str(expression.get("section_id", active_section_id))
	expression ["surface_id"] = str(expression.get("surface_id", "%s_hub_panel" % panel_kind))
	expression ["ui_is_expression_only"] = true
	action_requested.emit(expression)


func _process(
	delta: float
) -> void:
	if not is_visible_in_tree():
		return

	if animated_cards.is_empty():
		return

	animation_time += delta

	var active_scroll_raw: Variant = section_scroll_deck.get(
		active_section_id,
		null
	)
	var active_scroll: ScrollContainer = null

	if (
		typeof(
			active_scroll_raw
		) == TYPE_OBJECT
		and is_instance_valid(
			active_scroll_raw
		)
		and active_scroll_raw is ScrollContainer
	):
		active_scroll = (
			active_scroll_raw as ScrollContainer
		)

	if active_scroll == null:
		return

	var active_viewport_rect: Rect2 = (
		active_scroll.get_global_rect().grow(
			48.0
		)
	)
	var mouse_position: Vector2 = (
		get_global_mouse_position()
	)
	var relationship_wave: float = (
		0.72
		+ (
			0.28
			* (
				(
					sin(
						animation_time * 2.8
					)
					+ 1.0
				)
				* 0.5
			)
		)
	)
	var metric_wave: float = (
		0.55
		+ (
			0.45
			* (
				(
					sin(
						animation_time * 4.2
					)
					+ 1.0
				)
				* 0.5
			)
		)
	)
	var retained_entries: Array = []

	for raw_entry in animated_cards:
		if typeof(
			raw_entry
		) != TYPE_DICTIONARY:
			continue

		var entry: Dictionary = raw_entry
		var entry_kind: String = str(
			entry.get(
				"kind",
				"card"
			)
		)

		if entry_kind == "metric":
			var metric_control_raw: Variant = entry.get(
				"control",
				null
			)

			if (
				typeof(
					metric_control_raw
				) != TYPE_OBJECT
				or not is_instance_valid(
					metric_control_raw
				)
				or not (
					metric_control_raw is Control
				)
			):
				continue

			var metric_control: Control = (
				metric_control_raw as Control
			)




			if panel_kind == "relationships":
				metric_control.modulate = Color.WHITE
				continue

			retained_entries.append(
				entry
			)



			if not active_scroll.is_ancestor_of(
				metric_control
			):
				continue

			if not metric_control.is_visible_in_tree():
				continue

			if not active_viewport_rect.intersects(
				metric_control.get_global_rect(),
				true
			):
				continue

			var fill_style_raw: Variant = entry.get(
				"fill_style",
				null
			)

			if (
				typeof(
					fill_style_raw
				) != TYPE_OBJECT
				or not is_instance_valid(
					fill_style_raw
				)
				or not (
					fill_style_raw is StyleBoxFlat
				)
			):
				continue

			var fill_style: StyleBoxFlat = (
				fill_style_raw as StyleBoxFlat
			)
			var ratio: float = clampf(
				float(
					entry.get(
						"ratio",
						0.0
					)
				),
				0.0,
				1.0
			)
			var base_fill: Color = entry.get(
				"base_fill_color",
				Color.WHITE
			)
			var pulse_strength: float = (
				ratio
				* metric_wave
			)
			var light_mix: float = (
				0.04
				+ (0.18 * pulse_strength)
			)

			fill_style.bg_color = base_fill.lerp(
				Color(
					1.0,
					1.0,
					1.0,
					base_fill.a
				),
				light_mix
			)
			fill_style.shadow_color = Color(
				base_fill.r,
				base_fill.g,
				base_fill.b,
				0.08 + (0.46 * pulse_strength)
			)
			fill_style.shadow_size = int(
				round(
					2.0
					+ (10.0 * pulse_strength)
				)
			)
			continue

		var card_raw: Variant = entry.get(
			"card",
			null
		)

		if (
			typeof(
				card_raw
			) != TYPE_OBJECT
			or not is_instance_valid(
				card_raw
			)
			or not (
				card_raw is PanelContainer
			)
		):
			continue

		var card: PanelContainer = (
			card_raw as PanelContainer
		)

		retained_entries.append(
			entry
		)

		if not active_scroll.is_ancestor_of(
			card
		):
			continue

		if not card.is_visible_in_tree():
			continue

		var card_rect: Rect2 = (
			card.get_global_rect()
		)

		if not active_viewport_rect.intersects(
			card_rect,
			true
		):
			continue

		var hovered: bool = (
			card_rect.has_point(
				mouse_position
			)
		)
		var relationship_card: bool = bool(
			entry.get(
				"relationship_card",
				false
			)
		)
		var target_scale: Vector2 = (
			Vector2(
				1.012,
				1.012
			)
			if hovered
			else Vector2.ONE
		)
		var base_modulate: Color = entry.get(
			"base_modulate",
			Color.WHITE
		)
		var target_modulate: Color = (
			entry.get(
				"hover_modulate",
				Color.WHITE
			)
			if hovered
			else base_modulate
		)





		if (
			relationship_card
			and not hovered
		):
			var bond_ratio: float = clampf(
				float(
					entry.get(
						"bond_ratio",
						0.0
					)
				),
				0.0,
				1.0
			)
			var glow_strength: float = (
				bond_ratio
				* relationship_wave
			)
			var glow_tint:= Color(
				1.0,
				0.94,
				0.98,
				1.0
			)

			target_modulate = base_modulate.lerp(
				glow_tint,
				0.04 + (0.1 * glow_strength)
			)

		card.pivot_offset = card.size * 0.5
		card.scale = card.scale.lerp(
			target_scale,
			clampf(
				delta * 10.0,
				0.0,
				1.0
			)
		)
		card.modulate = card.modulate.lerp(
			target_modulate,
			clampf(
				delta * 8.0,
				0.0,
				1.0
			)
		)



	animated_cards = retained_entries
func _clear_section_surface_deck() -> void:
	if section_surface_host != null:
		_clear_children(section_surface_host)

	section_surface_deck.clear()
	section_scroll_deck.clear()


func _clear_children(parent: Node) -> void:
	if parent == null:
		return

	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _set_uniform_border(style: StyleBoxFlat, width: int) -> void:
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width


func _set_uniform_radius(style: StyleBoxFlat, radius: int) -> void:
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius


func _color_from_variant(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value

	if typeof(value) == TYPE_STRING:
		var text: String = str(value).strip_edges()

		if text.begins_with("#"):
			return Color.from_string(text, fallback)

	return fallback


func _safe_name(value: String) -> String:
	var clean: String = str(value).strip_edges().to_lower()
	clean = clean.replace(" ", "_")
	clean = clean.replace("/", "_")
	clean = clean.replace(":", "_")
	clean = clean.replace("-", "_")
	return clean


func _join_strings(values: Array, separator: String = ", ") -> String:
	var clean: PackedStringArray = PackedStringArray()

	for raw_value in values:
		var text: String = str(raw_value).strip_edges()

		if text != "":
			clean.append(text)

	return separator.join(clean)


func _dict(
	value: Variant
) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return (
			value as Dictionary
		).duplicate(false)

	return {}


func _array(
	value: Variant
) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return (
			value as Array
		).duplicate(false)

	return []