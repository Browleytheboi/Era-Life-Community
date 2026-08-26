

extends PanelContainer
class_name ModMenuPanel

signal closed
signal intent_requested(payload: Dictionary)

const PANEL_SCHEMA:= "eralife.mod_menu_panel"
const MENU_SCHEMA:= "eralife.mod_menu_contract"

var active_contract: Dictionary = {}
var active_actor_id: int = -1
var active_section_id: String = "bundles"

var shell_root: VBoxContainer
var header_row: HBoxContainer
var title_label: Label
var subtitle_label: Label
var identity_label: Label
var close_button: Button
var toolbar_row: HBoxContainer
var section_scroll: ScrollContainer
var section_bar: HBoxContainer
var section_buttons: Dictionary = {}
var content_scroll: ScrollContainer
var content_root: VBoxContainer
var status_label: Label
var content_deck_root: VBoxContainer
var section_surface_deck: Dictionary = {}
var rendered_surface_revision: String = ""
var rendered_actor_id: int = -1
var active_surface_mode: String = "global_hub"
var active_presentation_contract: Dictionary = {}

var window_contract: Dictionary = {}
var minimize_button: Button = null
var minimized: bool = false
var floating_window_mode: bool = false
var section_grid_deck: Dictionary = {}
var scroll_up_button: Button = null
var scroll_down_button: Button = null
var content_vertical_scrollbar: VScrollBar = null
var scroll_indicator_hold_seconds: float = 0.0
var scroll_indicator_alpha: float = 0.0
var animated_action_buttons: Array = []
var animated_row_cards: Array = []
var last_grid_column_count: int = -1
var expand_button: Button = null
var bundle_toggle: CheckButton = null
var window_state_label: Label = null
var window_drag_surface: Control = null
var window_footer_row: HBoxContainer = null
var window_hint_label: Label = null
var resize_handle: Button = null

var window_dragging: bool = false
var window_resizing: bool = false
var window_expanded: bool = false
var window_geometry_initialized: bool = false
var bundle_toggle_contract_sync: bool = false

var window_pointer_origin: Vector2 = Vector2.ZERO
var window_position_origin: Vector2 = Vector2.ZERO
var window_size_origin: Vector2 = Vector2.ZERO

var restored_window_rect: Rect2 = Rect2()
var compact_window_size: Vector2 = Vector2(
	486.0,
	640.0
)
var expanded_window_size: Vector2 = Vector2(
	760.0,
	720.0
)
var minimum_window_size: Vector2 = Vector2(
	420.0,
	360.0
)
var maximum_window_size: Vector2 = Vector2(
	920.0,
	840.0
)
var minimized_edge_tab: Button = null
var minimized_edge_side: String = "right"
var minimized_edge_dragging: bool = false
var minimized_edge_pointer_origin: Vector2 = Vector2.ZERO
var minimized_edge_position_origin: Vector2 = Vector2.ZERO
var minimized_edge_drag_distance: float = 0.0

const MINIMIZED_EDGE_TAB_SIZE:= Vector2(
	184.0,
	52.0
)
const MINIMIZED_EDGE_TAB_MARGIN:= 8.0
func _ready() -> void:
	_ensure_surface()
	_ensure_aaa_window_chrome()
	set_process(true)

func _process(
	delta: float
) -> void:
	if not visible:
		return

	if minimized:
		_ensure_minimized_edge_tab()
		_refresh_minimized_edge_tab_copy()

		if not minimized_edge_dragging:
			position = _snap_minimized_edge_tab_position(
				position,
				minimized_edge_side
			)

		return

	_sync_section_grid_columns()
	_update_animated_mod_controls(
		delta
	)

	if (
		content_vertical_scrollbar == null
			and content_scroll != null
	):
		content_vertical_scrollbar = (
			content_scroll.get_v_scroll_bar()
		)

	if content_vertical_scrollbar == null:
		return

	if scroll_indicator_hold_seconds > 0.0:
		scroll_indicator_hold_seconds = maxf(
			0.0,
			scroll_indicator_hold_seconds - delta
		)
		scroll_indicator_alpha = move_toward(
			scroll_indicator_alpha,
			1.0,
			delta * 8.0
		)
	else:
		scroll_indicator_alpha = move_toward(
			scroll_indicator_alpha,
			0.0,
			delta * 3.5
		)

	var scrollbar_modulate: Color = (
		content_vertical_scrollbar.modulate
	)
	scrollbar_modulate.a = scroll_indicator_alpha
	content_vertical_scrollbar.modulate = scrollbar_modulate
	content_vertical_scrollbar.mouse_filter = (
		Control.MOUSE_FILTER_STOP
			if scroll_indicator_alpha > 0.08
			else Control.MOUSE_FILTER_IGNORE
	)

func prepare_surface() -> void:
	_ensure_surface()
	_ensure_aaa_window_chrome()


func open_contract(
	contract: Dictionary
) -> void:
	render_contract(contract)
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_INHERIT


func render_contract(
	contract: Dictionary
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
	var incoming_mode: String = str(
		contract.get(
			"surface_mode",
			"global_hub"
		)
	).strip_edges().to_lower()
	var may_reuse_deck: bool = (
		incoming_revision != ""
		and incoming_revision == rendered_surface_revision
		and incoming_actor_id == rendered_actor_id
		and incoming_mode == active_surface_mode
		and not section_surface_deck.is_empty()
	)



	active_contract = contract.duplicate(false)
	active_actor_id = incoming_actor_id
	active_surface_mode = incoming_mode
	active_section_id = str(
		active_contract.get(
			"active_section",
			active_contract.get(
				"default_section",
				"bundles"
			)
		)
	).strip_edges().to_lower()
	active_presentation_contract = _dict(
		active_contract.get(
			"presentation",
			{}
		)
	)

	if active_section_id == "":
		active_section_id = "bundles"

	title_label.text = str(
		active_contract.get(
			"title",
			"🧩 MOD HUB"
		)
	)
	subtitle_label.text = str(
		active_contract.get(
			"subtitle",
			(
				"Install and control contract-driven "
				+ "reality systems."
			)
		)
	)

	_apply_presentation_contract(
		active_presentation_contract
	)

	_render_identity(
		_dict(
			active_contract.get(
				"identity_overview",
				{}
			)
		)
	)
	_render_toolbar(
		_array(
			active_contract.get(
				"toolbar_actions",
				[]
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

	if not may_reuse_deck:
		rendered_surface_revision = incoming_revision
		rendered_actor_id = incoming_actor_id

		_precompose_section_surfaces(
			_dict(
				active_contract.get(
					"section_surfaces",
					{}
				)
			)
		)
	else:
		reveal_section(
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

	set_meta(
		"section_surface_deck_precomposed",
		not section_surface_deck.is_empty()
	)
	set_meta(
		"section_press_reveal_only",
		true
	)
	set_meta(
		"recursive_contract_copy_forbidden",
		true
	)
	set_meta(
		"active_section_id",
		active_section_id
	)

	_sync_bundle_window_chrome_from_contract()

func open_observable_contract(
	contract: Dictionary
) -> void:
	open_contract(contract)


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
	) != MENU_SCHEMA:
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

	return (
		typeof(
			active_contract.get(
				"section_surfaces",
				{}
			)
		) == TYPE_DICTIONARY
		or active_contract.has("section_rows")
	)
func has_precomposed_surface(
	actor_id: int = -1
) -> bool:
	if not has_renderable_contract(
		actor_id
	):
		return false

	if section_surface_deck.is_empty():
		return false

	for raw_tab in _array(
		active_contract.get(
			"section_tabs",
			[]
		)
	):
		var tab: Dictionary = _dict(
			raw_tab
		)
		var section_id: String = str(
			tab.get(
				"id",
				""
			)
		).strip_edges().to_lower()

		if section_id == "":
			continue

		if not section_surface_deck.has(
			section_id
		):
			return false

		var section_surface: Control = (
			section_surface_deck.get(
				section_id,
				null
			) as Control
		)

		if (
			section_surface == null
			or not is_instance_valid(
				section_surface
			)
		):
			return false

	return true


func reveal_precomposed_surface(
	actor_id: int = -1
) -> bool:
	if not has_precomposed_surface(
		actor_id
	):
		return false


	reveal_section(
		active_section_id
	)

	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_INHERIT

	return true
func _precompose_section_surfaces(
	section_surfaces: Dictionary
) -> void:
	if (
		content_deck_root == null
		or not is_instance_valid(content_deck_root)
	):
		return

	_clear_children(content_deck_root)
	section_surface_deck.clear()
	section_grid_deck.clear()
	animated_action_buttons.clear()
	animated_row_cards.clear()

	for raw_tab in _array(active_contract.get("section_tabs", [])):
		var tab: Dictionary = _dict(raw_tab)
		var section_id: String = str(tab.get("id", "")).strip_edges().to_lower()

		if section_id == "":
			continue

		var section_room:= VBoxContainer.new()
		section_room.name = "ModSection_%s" % _safe_name(section_id)
		section_room.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		section_room.size_flags_vertical = Control.SIZE_EXPAND_FILL
		section_room.add_theme_constant_override("separation", 10)
		section_room.visible = false
		section_room.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content_deck_root.add_child(section_room)
		section_surface_deck [section_id] = section_room

		var grid:= GridContainer.new()
		grid.name = "ModGrid_%s" % _safe_name(section_id)
		grid.columns = 1
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		section_room.add_child(grid)
		section_grid_deck [section_id] = grid

		_render_rows_into(
			grid,
			_array(section_surfaces.get(section_id, [])),
			section_id
		)

	content_root = content_deck_root
	reveal_section(active_section_id)
	_sync_section_grid_columns()

func _render_rows_into(
	target_root: GridContainer,
	rows: Array,
	section_id: String
) -> void:
	_clear_children(target_root)

	if rows.is_empty():
		var empty_label:= Label.new()
		empty_label.text = _empty_section_text_for(section_id)
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.custom_minimum_size = Vector2(0.0, 150.0)
		empty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		target_root.add_child(empty_label)
		return

	for raw_row in rows:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue

		target_root.add_child(
			_build_row_card(raw_row as Dictionary)
		)

func reveal_section(
	section_id: String
) -> void:
	var clean_section: String = str(
		section_id
	).strip_edges().to_lower()

	if clean_section == "":
		clean_section = "bundles"

	if not section_surface_deck.has(
		clean_section
	):
		if section_surface_deck.has("bundles"):
			clean_section = "bundles"
		elif not section_surface_deck.is_empty():
			clean_section = str(
				section_surface_deck.keys().front()
			)
		else:
			return

	active_section_id = clean_section
	active_contract ["active_section"] = clean_section

	for raw_section_id in section_surface_deck.keys():
		var stored_section_id: String = str(
			raw_section_id
		)
		var surface: Control = (
			section_surface_deck.get(
				raw_section_id,
				null
			) as Control
		)

		if (
			surface == null
			or not is_instance_valid(surface)
		):
			continue

		var should_reveal: bool = (
			stored_section_id == clean_section
		)
		surface.visible = should_reveal
		surface.mouse_filter = (
			Control.MOUSE_FILTER_PASS
			if should_reveal
			else Control.MOUSE_FILTER_IGNORE
		)

	for raw_button_id in section_buttons.keys():
		var button: Button = (
			section_buttons.get(
				raw_button_id,
				null
			) as Button
		)

		if (
			button == null
			or not is_instance_valid(button)
		):
			continue

		button.button_pressed = (
			str(raw_button_id) == clean_section
		)

	if (
		content_scroll != null
		and is_instance_valid(content_scroll)
	):
		content_scroll.scroll_vertical = 0

func has_hot_contract(
	actor_id: int = -1
) -> bool:
	if not has_renderable_contract(actor_id):
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
		status_label.text = str(text)


func close_panel() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	closed.emit()


func _ensure_surface() -> void:
	if (
		shell_root != null
		and is_instance_valid(shell_root)
	):
		return

	name = "ModMenuPanel"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_INHERIT

	set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	offset_left = 64.0
	offset_top = 46.0
	offset_right = -64.0
	offset_bottom = -46.0
	custom_minimum_size = Vector2(
		760.0,
		560.0
	)
	add_theme_stylebox_override(
		"panel",
		_panel_style()
	)

	shell_root = VBoxContainer.new()
	shell_root.name = "ModMenuShell"
	shell_root.add_theme_constant_override(
		"separation",
		12
	)
	add_child(shell_root)

	header_row = HBoxContainer.new()
	header_row.name = "HeaderRow"
	header_row.add_theme_constant_override(
		"separation",
		12
	)
	shell_root.add_child(header_row)

	var heading_box:= VBoxContainer.new()
	heading_box.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	heading_box.add_theme_constant_override(
		"separation",
		3
	)
	header_row.add_child(heading_box)

	title_label = Label.new()
	title_label.name = "Title"
	title_label.text = "🧩 MOD MENU"
	title_label.add_theme_font_size_override(
		"font_size",
		25
	)
	title_label.add_theme_color_override(
		"font_color",
		Color(
			0.96,
			0.93,
			1.0,
			1.0
		)
	)
	heading_box.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.name = "Subtitle"
	subtitle_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	subtitle_label.add_theme_font_size_override(
		"font_size",
		13
	)
	subtitle_label.add_theme_color_override(
		"font_color",
		Color(
			0.74,
			0.7,
			0.82,
			1.0
		)
	)
	heading_box.add_child(subtitle_label)

	minimize_button = Button.new()
	minimize_button.name = "MinimizeButton"
	minimize_button.text = "—"
	minimize_button.tooltip_text = (
		"Minimize Acrello's Mods"
	)
	minimize_button.focus_mode = (
		Control.FOCUS_NONE
	)
	minimize_button.custom_minimum_size = Vector2(
		42.0,
		38.0
	)
	minimize_button.visible = false
	minimize_button.pressed.connect(
		_on_minimize_pressed
	)
	header_row.add_child(
		minimize_button
	)

	close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "BACK"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.custom_minimum_size = Vector2(
		88.0,
		38.0
	)
	close_button.pressed.connect(
		close_panel
	)
	header_row.add_child(
		close_button
	)

	identity_label = Label.new()
	identity_label.name = "IdentityOverview"
	identity_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	identity_label.add_theme_font_size_override(
		"font_size",
		13
	)
	identity_label.add_theme_color_override(
		"font_color",
		Color(
			0.84,
			0.79,
			0.95,
			1.0
		)
	)
	shell_root.add_child(identity_label)

	toolbar_row = HBoxContainer.new()
	toolbar_row.name = "Toolbar"
	toolbar_row.add_theme_constant_override(
		"separation",
		8
	)
	shell_root.add_child(toolbar_row)

	section_scroll = ScrollContainer.new()
	section_scroll.name = "SectionScroll"
	section_scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_AUTO
	)
	section_scroll.vertical_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)
	section_scroll.custom_minimum_size = Vector2(
		0.0,
		46.0
	)
	shell_root.add_child(section_scroll)

	section_bar = HBoxContainer.new()
	section_bar.name = "SectionBar"
	section_bar.add_theme_constant_override(
		"separation",
		8
	)
	section_scroll.add_child(section_bar)

	content_scroll = ScrollContainer.new()
	content_scroll.name = "ContentScroll"
	content_scroll.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	content_scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)
	content_scroll.vertical_scroll_mode = (
		ScrollContainer.SCROLL_MODE_AUTO
	)
	shell_root.add_child(content_scroll)

	content_deck_root = VBoxContainer.new()
	content_deck_root.name = "ContentDeckRoot"
	content_deck_root.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	content_deck_root.add_theme_constant_override(
		"separation",
		10
	)
	content_scroll.add_child(content_deck_root)



	content_root = content_deck_root
	status_label = Label.new()
	status_label.name = "Status"
	status_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	status_label.add_theme_font_size_override(
		"font_size",
		12
	)
	status_label.add_theme_color_override(
		"font_color",
		Color(
			0.74,
			0.77,
			0.9,
			1.0
		)
	)
	shell_root.add_child(status_label)
func _ensure_aaa_window_chrome() -> void:
	if bool(
		get_meta(
			"aaa_mod_window_chrome_ready",
			false
		)
	):
		return

	if (
		shell_root == null
		or header_row == null
		or title_label == null
		or subtitle_label == null
	):
		return

	window_drag_surface = header_row
	window_drag_surface.mouse_filter = (
		Control.MOUSE_FILTER_STOP
	)
	window_drag_surface.mouse_default_cursor_shape = (
		Control.CURSOR_MOVE
	)

	title_label.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	subtitle_label.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	identity_label.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	var drag_callable:= Callable(
		self,
		"_on_window_header_gui_input"
	)

	if not window_drag_surface.gui_input.is_connected(
		drag_callable
	):
		window_drag_surface.gui_input.connect(
			drag_callable
		)

	bundle_toggle = CheckButton.new()
	bundle_toggle.name = "BundleRealityToggle"
	bundle_toggle.text = "REALITY"
	bundle_toggle.tooltip_text = (
		"Toggle this complete reality bundle"
	)
	bundle_toggle.focus_mode = (
		Control.FOCUS_NONE
	)
	bundle_toggle.custom_minimum_size = Vector2(
		138.0,
		38.0
	)
	bundle_toggle.visible = false
	bundle_toggle.toggled.connect(
		_on_bundle_reality_toggle_toggled
	)
	header_row.add_child(
		bundle_toggle
	)
	header_row.move_child(
		bundle_toggle,
		1
	)

	expand_button = Button.new()
	expand_button.name = "ExpandButton"
	expand_button.text = "↗"
	expand_button.tooltip_text = (
		"Expand Acrello's Mods"
	)
	expand_button.focus_mode = (
		Control.FOCUS_NONE
	)
	expand_button.custom_minimum_size = Vector2(
		42.0,
		38.0
	)
	expand_button.visible = false
	expand_button.pressed.connect(
		_on_expand_pressed
	)
	header_row.add_child(
		expand_button
	)
	header_row.move_child(
		expand_button,
		2
	)

	window_state_label = Label.new()
	window_state_label.name = "WindowState"
	window_state_label.text = "CONTRACT LENS"
	window_state_label.add_theme_font_size_override(
		"font_size",
		10
	)
	window_state_label.add_theme_color_override(
		"font_color",
		Color(
			0.76,
			0.72,
			0.88,
			1.0
		)
	)
	window_state_label.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	shell_root.add_child(
		window_state_label
	)
	shell_root.move_child(
		window_state_label,
		1
	)

	window_footer_row = HBoxContainer.new()
	window_footer_row.name = "WindowFooter"
	window_footer_row.add_theme_constant_override(
		"separation",
		8
	)
	shell_root.add_child(
		window_footer_row
	)

	window_hint_label = Label.new()
	window_hint_label.text = (
		"Drag the header • resize from the corner"
	)
	window_hint_label.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	window_hint_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)
	window_hint_label.add_theme_font_size_override(
		"font_size",
		10
	)
	window_hint_label.add_theme_color_override(
		"font_color",
		Color(
			0.58,
			0.56,
			0.68,
			1.0
		)
	)
	window_hint_label.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	window_footer_row.add_child(
		window_hint_label
	)

	resize_handle = Button.new()
	resize_handle.name = "ResizeHandle"
	resize_handle.text = "◢"
	resize_handle.tooltip_text = (
		"Drag to resize Acrello's Mods"
	)
	resize_handle.focus_mode = (
		Control.FOCUS_NONE
	)
	resize_handle.custom_minimum_size = Vector2(
		34.0,
		30.0
	)
	resize_handle.mouse_default_cursor_shape = (
		Control.CURSOR_FDIAGSIZE
	)
	resize_handle.visible = false
	resize_handle.gui_input.connect(
		_on_resize_handle_gui_input
	)
	window_footer_row.add_child(
		resize_handle
	)

	title_label.add_theme_font_size_override(
		"font_size",
		22
	)
	subtitle_label.add_theme_font_size_override(
		"font_size",
		12
	)
	identity_label.add_theme_stylebox_override(
		"normal",
		_identity_capsule_style()
	)
	identity_label.add_theme_constant_override(
		"outline_size",
		0
	)

	content_scroll.custom_minimum_size = Vector2(
		0.0,
		320.0
	)
	section_scroll.custom_minimum_size = Vector2(
		0.0,
		42.0
	)
	shell_root.add_theme_constant_override(
		"separation",
		10
	)

	for raw_button in [
		minimize_button,
		expand_button,
		close_button
	]:
		var button:= raw_button as Button

		if button == null:
			continue

		_apply_window_chrome_button_style(
			button
		)
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	content_vertical_scrollbar = content_scroll.get_v_scroll_bar()

	if content_vertical_scrollbar != null:
		var hidden_scrollbar_modulate: Color = (
			content_vertical_scrollbar.modulate
		)
		hidden_scrollbar_modulate.a = 0.0
		content_vertical_scrollbar.modulate = (
			hidden_scrollbar_modulate
		)
		content_vertical_scrollbar.value_changed.connect(
			_on_content_scroll_activity
		)

	scroll_up_button = Button.new()
	scroll_up_button.text = "▲"
	scroll_up_button.tooltip_text = "Scroll up"
	scroll_up_button.focus_mode = Control.FOCUS_NONE
	scroll_up_button.custom_minimum_size = Vector2(36.0, 30.0)
	scroll_up_button.pressed.connect(
		_scroll_content_by.bind(-240)
	)
	_apply_window_chrome_button_style(scroll_up_button)
	window_footer_row.add_child(scroll_up_button)

	scroll_down_button = Button.new()
	scroll_down_button.text = "▼"
	scroll_down_button.tooltip_text = "Scroll down"
	scroll_down_button.focus_mode = Control.FOCUS_NONE
	scroll_down_button.custom_minimum_size = Vector2(36.0, 30.0)
	scroll_down_button.pressed.connect(
		_scroll_content_by.bind(240)
	)
	_apply_window_chrome_button_style(scroll_down_button)
	window_footer_row.add_child(scroll_down_button)
	set_meta(
		"aaa_mod_window_chrome_ready",
		true
	)
	set_meta(
		"aaa_mod_window_vertical_slice",
		true
	)
	set_meta(
		"aaa_mod_window_ui_is_renderer_only",
		true
	)
func _identity_capsule_style() -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()

	style.bg_color = Color(
		0.13,
		0.105,
		0.19,
		0.88
	)
	style.border_color = Color(
		0.5,
		0.4,
		0.72,
		0.38
	)
	style.set_border_width_all(
		1
	)
	style.set_corner_radius_all(
		10
	)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0

	return style


func _apply_window_chrome_button_style(
	button: Button
) -> void:
	var normal:= StyleBoxFlat.new()
	normal.bg_color = Color(
		0.13,
		0.1,
		0.19,
		0.96
	)
	normal.border_color = Color(
		0.51,
		0.4,
		0.76,
		0.48
	)
	normal.set_border_width_all(
		1
	)
	normal.set_corner_radius_all(
		9
	)

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(
		0.22,
		0.16,
		0.31,
		1.0
	)
	hover.border_color = Color(
		0.72,
		0.6,
		0.96,
		0.82
	)

	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color(
		0.1,
		0.075,
		0.15,
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
func apply_window_contract(
	contract: Dictionary = {}
) -> void:
	_ensure_surface()
	_ensure_aaa_window_chrome()
	_ensure_minimized_edge_tab()

	window_contract = contract.duplicate(true)

	var display_mode: String = str(
		window_contract.get(
			"display_mode",
			"embedded_full_surface"
		)
	).strip_edges().to_lower()
	floating_window_mode = (
		display_mode == "floating_non_embedded"
	)

	minimum_window_size = _window_contract_vector2(
		window_contract.get(
			"minimum_size",
			{}
		),
		Vector2(
			360.0,
			340.0
		)
	)
	maximum_window_size = _window_contract_vector2(
		window_contract.get(
			"maximum_size",
			{}
		),
		Vector2(
			920.0,
			840.0
		)
	)

	var requested_compact_size: Vector2 = _window_contract_vector2(
		window_contract.get(
			"initial_size",
			{}
		),
		Vector2(
			410.0,
			560.0
		)
	)
	var requested_expanded_size: Vector2 = _window_contract_vector2(
		window_contract.get(
			"expanded_size",
			{}
		),
		Vector2(
			720.0,
			720.0
		)
	)
	var viewport_size: Vector2 = get_viewport_rect().size
	var sleek_vertical_slice: bool = bool(
		window_contract.get(
			"sleek_vertical_slice",
			true
		)
	)

	if sleek_vertical_slice:
		requested_compact_size = Vector2(
			minf(
				requested_compact_size.x,
				minf(
					430.0,
					maxf(
						320.0,
						viewport_size.x * 0.42
					)
				)
			),
			minf(
				requested_compact_size.y,
				minf(
					560.0,
					maxf(
						420.0,
						viewport_size.y * 0.72
					)
				)
			)
		)

	compact_window_size = _clamp_floating_window_size(
		requested_compact_size
	)
	expanded_window_size = _clamp_floating_window_size(
		requested_expanded_size
	)

	if floating_window_mode:
		set_anchors_preset(
			Control.PRESET_TOP_LEFT
		)
		z_as_relative = false
		z_index = 350

		if not window_geometry_initialized:
			var initial_size: Vector2 = compact_window_size
			size = initial_size
			position = _clamp_floating_window_position(
				(
					viewport_size - initial_size
				) * 0.5,
				initial_size
			)
			restored_window_rect = Rect2(
				position,
				initial_size
			)
			window_geometry_initialized = true
			window_expanded = false
		elif not minimized:
			size = _clamp_floating_window_size(
				size
			)
			position = _clamp_floating_window_position(
				position,
				size
			)
			restored_window_rect = Rect2(
				position,
				size
			)

		custom_minimum_size = Vector2(
			minf(
				minimum_window_size.x,
				size.x
			),
			minf(
				minimum_window_size.y,
				size.y
			)
		)
	else:
		window_dragging = false
		window_resizing = false
		window_expanded = false
		window_geometry_initialized = false
		minimized = false
		minimized_edge_dragging = false

		if minimized_edge_tab != null:
			minimized_edge_tab.visible = false
			minimized_edge_tab.mouse_filter = (
				Control.MOUSE_FILTER_IGNORE
			)

		if shell_root != null:
			shell_root.visible = true
			shell_root.mouse_filter = (
				Control.MOUSE_FILTER_PASS
			)

		set_anchors_and_offsets_preset(
			Control.PRESET_FULL_RECT
		)
		offset_left = 64.0
		offset_top = 46.0
		offset_right = -64.0
		offset_bottom = -46.0
		custom_minimum_size = Vector2(
			760.0,
			560.0
		)
		z_as_relative = false
		z_index = 250

	var minimizable: bool = bool(
		window_contract.get(
			"minimizable",
			false
		)
	)
	var resizable: bool = bool(
		window_contract.get(
			"resizable",
			false
		)
	)
	var expandable: bool = bool(
		window_contract.get(
			"expandable",
			false
		)
	)

	if minimize_button != null:
		minimize_button.visible = (
			floating_window_mode
				and minimizable
				and not minimized
		)

	if expand_button != null:
		expand_button.visible = (
			floating_window_mode
				and expandable
				and not minimized
		)

	if resize_handle != null:
		resize_handle.visible = (
			floating_window_mode
				and resizable
				and not minimized
		)

	if close_button != null:
		close_button.text = (
			"CLOSE"
				if floating_window_mode
				else "BACK"
		)

	var host_title: String = str(
		window_contract.get(
			"host_title",
			""
		)
	).strip_edges()
	var contract_title: String = str(
		active_contract.get(
			"title",
			""
		)
	).strip_edges()

	if (
		floating_window_mode
			and host_title != ""
			and title_label != null
	):
		title_label.text = (
			"%s — %s" % [
				host_title,
				contract_title
			]
				if contract_title != ""
				else host_title
		)

	_sync_bundle_window_chrome_from_contract()
	set_minimized(
		minimized
	)
func set_minimized(
	value: bool
) -> void:
	_ensure_minimized_edge_tab()

	var may_minimize: bool = (
		floating_window_mode
			and bool(
				window_contract.get(
					"minimizable",
					false
				)
			)
	)
	var requested_minimized: bool = (
		value
			and may_minimize
	)
	var was_minimized: bool = minimized

	if (
		requested_minimized
			and not was_minimized
	):
		restored_window_rect = Rect2(
			position,
			size
		)

	minimized = requested_minimized
	minimized_edge_dragging = false

	var body_nodes: Array = [
		subtitle_label,
		identity_label,
		toolbar_row,
		section_scroll,
		content_scroll,
		status_label,
		window_state_label,
		window_footer_row
	]

	for raw_node in body_nodes:
		var control:= raw_node as Control

		if (
			control == null
				or not is_instance_valid(
					control
				)
		):
			continue

		control.visible = not minimized
		control.mouse_filter = (
			Control.MOUSE_FILTER_PASS
				if not minimized
				else Control.MOUSE_FILTER_IGNORE
		)

	if shell_root != null:
		shell_root.visible = not minimized
		shell_root.mouse_filter = (
			Control.MOUSE_FILTER_PASS
				if not minimized
				else Control.MOUSE_FILTER_IGNORE
		)

	if minimized_edge_tab != null:
		minimized_edge_tab.visible = minimized
		minimized_edge_tab.mouse_filter = (
			Control.MOUSE_FILTER_STOP
				if minimized
				else Control.MOUSE_FILTER_IGNORE
		)

	if minimize_button != null:
		minimize_button.text = "—"
		minimize_button.tooltip_text = (
			"Minimize Acrello's Mods"
		)
		minimize_button.visible = (
			floating_window_mode
				and may_minimize
				and not minimized
		)

	if expand_button != null:
		expand_button.visible = (
			floating_window_mode
				and bool(
					window_contract.get(
						"expandable",
						false
					)
				)
				and not minimized
		)

	if resize_handle != null:
		resize_handle.visible = (
			floating_window_mode
				and bool(
					window_contract.get(
						"resizable",
						false
					)
				)
				and not minimized
		)

	if floating_window_mode:
		if minimized:
			custom_minimum_size = MINIMIZED_EDGE_TAB_SIZE
			size = MINIMIZED_EDGE_TAB_SIZE
			position = _snap_minimized_edge_tab_position(
				position,
				""
			)
			_refresh_minimized_edge_tab_copy()
		else:
			custom_minimum_size = minimum_window_size

			if (
				was_minimized
					and restored_window_rect.size.x > 0.0
					and restored_window_rect.size.y > 0.0
			):
				size = _clamp_floating_window_size(
					restored_window_rect.size
				)
				position = _clamp_floating_window_position(
					restored_window_rect.position,
					size
				)
			else:
				size = compact_window_size
				position = _clamp_floating_window_position(
					(
						get_viewport_rect().size - size
					) * 0.5,
					size
				)

			restored_window_rect = Rect2(
				position,
				size
			)

	_sync_bundle_window_chrome_from_contract()
func _ensure_minimized_edge_tab() -> void:
	if (
		minimized_edge_tab != null
			and is_instance_valid(
				minimized_edge_tab
			)
	):
		return

	minimized_edge_tab = Button.new()
	minimized_edge_tab.name = "MinimizedEdgeTab"
	minimized_edge_tab.focus_mode = Control.FOCUS_NONE
	minimized_edge_tab.visible = false
	minimized_edge_tab.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	minimized_edge_tab.custom_minimum_size = (
		MINIMIZED_EDGE_TAB_SIZE
	)
	minimized_edge_tab.mouse_default_cursor_shape = (
		Control.CURSOR_MOVE
	)
	minimized_edge_tab.tooltip_text = (
		"Drag along the screen edge • click to restore"
	)
	minimized_edge_tab.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	_apply_window_chrome_button_style(
		minimized_edge_tab
	)
	minimized_edge_tab.gui_input.connect(
		_on_minimized_edge_tab_gui_input
	)
	add_child(
		minimized_edge_tab
	)
	move_child(
		minimized_edge_tab,
		get_child_count() - 1
	)
	_refresh_minimized_edge_tab_copy()


func _refresh_minimized_edge_tab_copy() -> void:
	if minimized_edge_tab == null:
		return

	var bundle_control: Dictionary = _dict(
		active_contract.get(
			"bundle_control",
			{}
		)
	)
	var configured_label: String = str(
		window_contract.get(
			"minimized_tab_label",
			""
		)
	).strip_edges()
	var contract_label: String = str(
		bundle_control.get(
			"label",
			active_contract.get(
				"title",
				"Acrello's Mods"
			)
		)
	).strip_edges()

	if configured_label != "":
		minimized_edge_tab.text = configured_label
	elif contract_label != "":
		minimized_edge_tab.text = (
			"◈ %s" % contract_label.to_upper()
		)
	else:
		minimized_edge_tab.text = "◈ ACRELLO'S MODS"


func _snap_minimized_edge_tab_position(
	requested_position: Vector2,
	preferred_edge: String = ""
) -> Vector2:
	var viewport_size: Vector2 = get_viewport_rect().size
	var clean_edge: String = str(
		preferred_edge
	).strip_edges().to_lower()

	if clean_edge not in [
		"left",
		"right"
	]:
		clean_edge = (
			"left"
				if (
					requested_position.x
						+ MINIMIZED_EDGE_TAB_SIZE.x * 0.5
				) < viewport_size.x * 0.5
				else "right"
		)

	minimized_edge_side = clean_edge

	var maximum_y: float = maxf(
		MINIMIZED_EDGE_TAB_MARGIN,
		viewport_size.y
			- MINIMIZED_EDGE_TAB_SIZE.y
			- MINIMIZED_EDGE_TAB_MARGIN
	)
	var snapped_x: float = (
		MINIMIZED_EDGE_TAB_MARGIN
			if clean_edge == "left"
			else maxf(
				MINIMIZED_EDGE_TAB_MARGIN,
				viewport_size.x
					- MINIMIZED_EDGE_TAB_SIZE.x
					- MINIMIZED_EDGE_TAB_MARGIN
			)
	)

	return Vector2(
		snapped_x,
		clampf(
			requested_position.y,
			MINIMIZED_EDGE_TAB_MARGIN,
			maximum_y
		)
	)


func _on_minimized_edge_tab_gui_input(
	event: InputEvent
) -> void:
	if not minimized:
		return

	if event is InputEventMouseButton:
		var mouse_event:= (
			event as InputEventMouseButton
		)

		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return

		if mouse_event.pressed:
			minimized_edge_dragging = true
			minimized_edge_pointer_origin = (
				mouse_event.global_position
			)
			minimized_edge_position_origin = position
			minimized_edge_drag_distance = 0.0
			accept_event()
			return

		var should_restore: bool = (
			minimized_edge_dragging
				and minimized_edge_drag_distance <= 6.0
				and bool(
					window_contract.get(
						"restore_on_minimized_click",
						true
					)
				)
		)
		minimized_edge_dragging = false
		position = _snap_minimized_edge_tab_position(
			position,
			minimized_edge_side
		)

		if should_restore:
			set_minimized(
				false
			)

		accept_event()
		return

	if (
		event is InputEventMouseMotion
			and minimized_edge_dragging
	):
		var motion_event:= (
			event as InputEventMouseMotion
		)
		var drag_delta: Vector2 = (
			motion_event.global_position
				- minimized_edge_pointer_origin
		)
		minimized_edge_drag_distance = maxf(
			minimized_edge_drag_distance,
			drag_delta.length()
		)
		position = _snap_minimized_edge_tab_position(
			minimized_edge_position_origin + drag_delta,
			""
		)
		accept_event()
func _on_minimize_pressed() -> void:
	set_minimized(
		not minimized
	)
func _on_window_header_gui_input(
	event: InputEvent
) -> void:
	if (
		not floating_window_mode
		or not bool(
			window_contract.get(
				"draggable",
				false
			)
		)
	):
		return

	if event is InputEventMouseButton:
		var mouse_event:= (
			event as InputEventMouseButton
		)

		if (
			mouse_event.button_index
			!= MOUSE_BUTTON_LEFT
		):
			return

		if mouse_event.pressed:
			if (
				minimized
				and bool(
					window_contract.get(
						"restore_on_minimized_click",
						true
					)
				)
			):
				set_minimized(
					false
				)
				accept_event()
				return

			window_dragging = true
			window_resizing = false
			window_pointer_origin = (
				mouse_event.global_position
			)
			window_position_origin = position
			accept_event()
			return

		window_dragging = false
		restored_window_rect = Rect2(
			position,
			size
		)
		accept_event()
		return

	if (
		event is InputEventMouseMotion
		and window_dragging
	):
		var motion_event:= (
			event as InputEventMouseMotion
		)
		var delta: Vector2 = (
			motion_event.global_position
			- window_pointer_origin
		)
		position = (
			_clamp_floating_window_position(
				window_position_origin + delta,
				size
			)
		)
		restored_window_rect = Rect2(
			position,
			size
		)
		accept_event()


func _on_resize_handle_gui_input(
	event: InputEvent
) -> void:
	if (
		not floating_window_mode
		or minimized
		or not bool(
			window_contract.get(
				"resizable",
				false
			)
		)
	):
		return

	if event is InputEventMouseButton:
		var mouse_event:= (
			event as InputEventMouseButton
		)

		if (
			mouse_event.button_index
			!= MOUSE_BUTTON_LEFT
		):
			return

		if mouse_event.pressed:
			window_resizing = true
			window_dragging = false
			window_pointer_origin = (
				mouse_event.global_position
			)
			window_size_origin = size
			accept_event()
			return

		window_resizing = false
		restored_window_rect = Rect2(
			position,
			size
		)
		accept_event()
		return

	if (
		event is InputEventMouseMotion
		and window_resizing
	):
		var motion_event:= (
			event as InputEventMouseMotion
		)
		var delta: Vector2 = (
			motion_event.global_position
			- window_pointer_origin
		)
		var next_size: Vector2 = (
			_clamp_floating_window_size(
				window_size_origin + delta
			)
		)

		size = next_size
		position = (
			_clamp_floating_window_position(
				position,
				next_size
			)
		)
		restored_window_rect = Rect2(
			position,
			next_size
		)
		window_expanded = (
			next_size.x
			>= (
				compact_window_size.x
				+ expanded_window_size.x
			) * 0.5
		)
		_sync_bundle_window_chrome_from_contract()
		accept_event()


func _on_expand_pressed() -> void:
	if not floating_window_mode:
		return

	if minimized:
		set_minimized(
			false
		)

	window_expanded = not window_expanded

	var target_size: Vector2 = (
		expanded_window_size
		if window_expanded
		else compact_window_size
	)
	var previous_center: Vector2 = (
		position + size * 0.5
	)

	size = _clamp_floating_window_size(
		target_size
	)
	position = (
		_clamp_floating_window_position(
			previous_center - size * 0.5,
			size
		)
	)
	restored_window_rect = Rect2(
		position,
		size
	)

	_sync_bundle_window_chrome_from_contract()


func _clamp_floating_window_size(
	requested_size: Vector2
) -> Vector2:
	var viewport_size: Vector2 = get_viewport_rect().size
	var viewport_limit: Vector2 = Vector2(
		maxf(280.0, viewport_size.x - 24.0),
		maxf(260.0, viewport_size.y - 24.0)
	)
	var effective_minimum: Vector2 = Vector2(
		minf(minimum_window_size.x, viewport_limit.x),
		minf(minimum_window_size.y, viewport_limit.y)
	)
	var effective_maximum: Vector2 = Vector2(
		minf(maximum_window_size.x, viewport_limit.x),
		minf(maximum_window_size.y, viewport_limit.y)
	)

	return Vector2(
		clampf(requested_size.x, effective_minimum.x, effective_maximum.x),
		clampf(requested_size.y, effective_minimum.y, effective_maximum.y)
	)
func _on_content_scroll_activity(
	_value: float
) -> void:
	scroll_indicator_hold_seconds = 0.85


func _scroll_content_by(
	delta_pixels: int
) -> void:
	if content_scroll == null:
		return

	content_scroll.scroll_vertical = maxi(
		0,
		content_scroll.scroll_vertical + delta_pixels
	)
	scroll_indicator_hold_seconds = 0.85


func _sync_section_grid_columns() -> void:
	var available_width: float = size.x - 48.0
	var columns: int = 1

	if available_width >= 780.0:
		columns = 3
	elif available_width >= 520.0:
		columns = 2

	if columns == last_grid_column_count:
		return

	last_grid_column_count = columns

	for raw_grid in section_grid_deck.values():
		var grid:= raw_grid as GridContainer

		if grid != null and is_instance_valid(grid):
			grid.columns = columns


func _update_animated_mod_controls(
	delta: float
) -> void:
	var mouse_position: Vector2 = get_global_mouse_position()

	for raw_entry in animated_action_buttons:
		if typeof(
			raw_entry
		) != TYPE_DICTIONARY:
			continue

		var entry: Dictionary = raw_entry
		var button:= entry.get(
			"button",
			null
		) as Button

		if (
			button == null
				or not is_instance_valid(
					button
				)
		):
			continue

		if not button.is_visible_in_tree():
			button.scale = button.scale.lerp(
				Vector2.ONE,
				clampf(
					delta * 12.0,
					0.0,
					1.0
				)
			)
			continue

		var hovered: bool = button.get_global_rect().has_point(
			mouse_position
		)
		var target_scale: Vector2 = (
			Vector2(
				1.025,
				1.025
			)
				if hovered and not button.disabled
				else Vector2.ONE
		)
		button.pivot_offset = button.size * 0.5
		button.scale = button.scale.lerp(
			target_scale,
			clampf(
				delta * 12.0,
				0.0,
				1.0
			)
		)
		button.modulate = button.modulate.lerp(
			(
				Color(
					1.0,
					1.0,
					1.0,
					1.0
				)
					if hovered
					else Color(
						0.94,
						0.94,
						1.0,
						1.0
					)
			),
			clampf(
				delta * 10.0,
				0.0,
				1.0
			)
		)

	for raw_entry in animated_row_cards:
		if typeof(
			raw_entry
		) != TYPE_DICTIONARY:
			continue

		var entry: Dictionary = raw_entry
		var card:= entry.get(
			"card",
			null
		) as PanelContainer
		var title:= entry.get(
			"title",
			null
		) as Label

		if (
			card == null
				or title == null
				or not is_instance_valid(
					card
				)
				or not is_instance_valid(
					title
				)
		):
			continue

		var hovered: bool = (
			card.is_visible_in_tree()
				and card.get_global_rect().has_point(
					mouse_position
				)
		)
		var animate_title: bool = bool(
			entry.get(
				"animate_title_on_hover",
				false
			)
		)
		var title_default_color: Color = entry.get(
			"title_default_color",
			Color.WHITE
		)
		var title_hover_color: Color = entry.get(
			"title_hover_color",
			Color.WHITE
		)

		if animate_title:
			title.text = str(
				entry.get(
					"default_title",
					""
				)
			)
			title.pivot_offset = title.size * 0.5
			title.scale = title.scale.lerp(
				(
					Vector2(
						1.035,
						1.035
					)
						if hovered
						else Vector2.ONE
				),
				clampf(
					delta * 10.0,
					0.0,
					1.0
				)
			)
			title.add_theme_color_override(
				"font_color",
				(
					title_hover_color
						if hovered
						else title_default_color
				)
			)
		else:
			title.text = str(
				entry.get(
					(
						"hover_title"
							if hovered
							else "default_title"
					),
					""
				)
			)

		for raw_control in _array(
			entry.get(
				"hover_controls",
				[]
			)
		):
			var hover_control:= raw_control as Control

			if (
				hover_control == null
					or not is_instance_valid(
						hover_control
					)
			):
				continue

			hover_control.visible = hovered
			hover_control.mouse_filter = (
				Control.MOUSE_FILTER_STOP
					if hovered
					else Control.MOUSE_FILTER_IGNORE
			)

		card.modulate = card.modulate.lerp(
			(
				Color(
					1.0,
					1.0,
					1.0,
					1.0
				)
					if hovered
					else Color(
						0.97,
						0.97,
						1.0,
						1.0
					)
			),
			clampf(
				delta * 8.0,
				0.0,
				1.0
			)
		)
func _clamp_floating_window_position(
	requested_position: Vector2,
	window_size: Vector2
) -> Vector2:
	var viewport_size: Vector2 = (
		get_viewport_rect().size
	)
	var safe_margin: float = 12.0
	var maximum_x: float = maxf(
		safe_margin,
		viewport_size.x
		- window_size.x
		- safe_margin
	)
	var maximum_y: float = maxf(
		safe_margin,
		viewport_size.y
		- window_size.y
		- safe_margin
	)

	return Vector2(
		clampf(
			requested_position.x,
			safe_margin,
			maximum_x
		),
		clampf(
			requested_position.y,
			safe_margin,
			maximum_y
		)
	)


func _window_contract_vector2(
	value: Variant,
	fallback: Vector2
) -> Vector2:
	if value is Vector2:
		return value

	if typeof(value) == TYPE_DICTIONARY:
		var row: Dictionary = value as Dictionary

		return Vector2(
			float(
				row.get(
					"x",
					fallback.x
				)
			),
			float(
				row.get(
					"y",
					fallback.y
				)
			)
		)

	return fallback
func _sync_bundle_window_chrome_from_contract() -> void:
	if not floating_window_mode:
		if bundle_toggle != null:
			bundle_toggle.visible = false

		if window_state_label != null:
			window_state_label.visible = false

		return

	var bundle_control: Dictionary = _dict(
		active_contract.get(
			"bundle_control",
			{}
		)
	)
	var control_visible: bool = bool(
		bundle_control.get(
			"visible",
			false
		)
	)
	var bundle_enabled: bool = bool(
		bundle_control.get(
			"enabled",
			active_contract.get(
				"bundle_enabled",
				false
			)
		)
	)
	var may_toggle: bool = bool(
		bundle_control.get(
			"toggle_enabled",
			true
		)
	)
	var display_name: String = str(
		bundle_control.get(
			"label",
			"Caveman Reality"
		)
	)

	if bundle_toggle != null:
		bundle_toggle_contract_sync = true
		bundle_toggle.visible = control_visible
		bundle_toggle.disabled = not may_toggle
		bundle_toggle.button_pressed = (
			bundle_enabled
		)
		bundle_toggle.text = (
			"%s: %s"
			% [
				display_name.to_upper(),
				(
					"ON"
					if bundle_enabled
					else "OFF"
				)
			]
		)
		bundle_toggle.tooltip_text = str(
			bundle_control.get(
				"tooltip",
				(
					"Disable this reality while preserving "
					+ "its complete runtime history."
					if bundle_enabled
					else (
						"Enable this reality and reconnect "
						+ "its preserved runtime."
					)
				)
			)
		)
		bundle_toggle_contract_sync = false

	if window_state_label != null:
		window_state_label.visible = true
		window_state_label.text = (
			"REALITY LIVE • CONTRACTED • HOT-SWAPPABLE"
			if bundle_enabled
			else (
				"REALITY DORMANT • STATE PRESERVED "
				+ "• READY TO REATTACH"
			)
		)

	if expand_button != null:
		expand_button.text = (
			"↙"
			if window_expanded
			else "↗"
		)
		expand_button.tooltip_text = (
			"Return to compact vertical slice"
			if window_expanded
			else "Expand Acrello's Mods"
		)
func _on_bundle_reality_toggle_toggled(
	desired_enabled: bool
) -> void:
	if bundle_toggle_contract_sync:
		return

	var bundle_control: Dictionary = _dict(
		active_contract.get(
			"bundle_control",
			{}
		)
	)
	var bundle_id: String = str(
		bundle_control.get(
			"bundle_id",
			active_contract.get(
				"active_bundle_id",
				""
			)
		)
	).strip_edges().to_lower()
	var authoritative_enabled: bool = bool(
		bundle_control.get(
			"enabled",
			active_contract.get(
				"bundle_enabled",
				false
			)
		)
	)




	if bundle_toggle != null:
		bundle_toggle_contract_sync = true
		bundle_toggle.button_pressed = (
			authoritative_enabled
		)
		bundle_toggle_contract_sync = false

	if bundle_id == "":
		set_status(
			"Reality bundle identity is unavailable."
		)
		return

	if desired_enabled == authoritative_enabled:
		return

	set_status(
		(
			"Requesting Caveman Reality activation..."
			if desired_enabled
			else (
				"Requesting return to base reality..."
			)
		)
	)

	intent_requested.emit({
		"action_id": (
			"enable_bundle"
			if desired_enabled
			else "disable_bundle"
		),
		"bundle_id": bundle_id,
		"actor_id": active_actor_id,
		"section_id": active_section_id,
		"bundle_section": active_section_id,
		"enable_after_install": desired_enabled,
		"preserve_bundle_window": true,
		"expected_surface_mode": "bundle_menu",
		"source": "mod_menu_panel.bundle_reality_toggle",
		"ui_is_expression_only": true
	})
func _render_identity(
	identity: Dictionary
) -> void:
	var actor_name: String = str(
		identity.get(
			"name",
			active_contract.get(
				"actor_name",
				"Current Life"
			)
		)
	)

	identity_label.text = (
		"%s  •  %d installed  •  %d enabled  •  "
		+ "%d providers  •  %d conflicts"
	) % [
		actor_name,
		int(
			identity.get(
				"installed_mod_count",
				0
			)
		),
		int(
			identity.get(
				"enabled_mod_count",
				0
			)
		),
		int(
			identity.get(
				"provider_count",
				0
			)
		),
		int(
			identity.get(
				"conflict_count",
				0
			)
		)
	]


func _render_toolbar(
	actions: Array
) -> void:
	_clear_children(toolbar_row)

	for raw_action in actions:
		if typeof(raw_action) != TYPE_DICTIONARY:
			continue

		var action: Dictionary = raw_action as Dictionary
		var button:= Button.new()
		button.text = "%s %s" % [
			str(
				action.get(
					"icon",
					""
				)
			),
			str(
				action.get(
					"label",
					"Action"
				)
			)
		]
		button.disabled = not bool(
			action.get(
				"enabled",
				true
			)
		)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(
			_on_action_pressed.bind(
				action.duplicate(true)
			)
		)
		toolbar_row.add_child(button)


func _render_tabs(
	tabs: Array
) -> void:
	_clear_children(section_bar)
	section_buttons.clear()

	for raw_tab in tabs:
		if typeof(raw_tab) != TYPE_DICTIONARY:
			continue

		var tab: Dictionary = raw_tab as Dictionary
		var section_id: String = str(
			tab.get(
				"id",
				""
			)
		).strip_edges().to_lower()
		if section_id == "":
			continue

		var button:= Button.new()
		button.name = "Section_%s" % section_id
		button.text = "%s %s" % [
			str(
				tab.get(
					"icon",
					""
				)
			),
			str(
				tab.get(
					"label",
					section_id.to_upper()
				)
			)
		]
		button.toggle_mode = true
		button.button_pressed = (
			section_id == active_section_id
		)
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(
			128.0,
			38.0
		)
		button.pressed.connect(
			_on_section_pressed.bind(section_id)
		)
		section_bar.add_child(button)
		section_buttons [section_id] = button


func _render_rows(
	rows: Array
) -> void:
	_clear_children(content_root)

	if rows.is_empty():
		var empty_label:= Label.new()
		empty_label.text = _empty_section_text()
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
			0.0,
			150.0
		)
		empty_label.add_theme_color_override(
			"font_color",
			Color(
				0.67,
				0.64,
				0.74,
				1.0
			)
		)
		content_root.add_child(empty_label)
		return

	for raw_row in rows:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue

		content_root.add_child(
			_build_row_card(
				raw_row as Dictionary
			)
		)


func _build_row_card(
	row: Dictionary
) -> Control:
	var card:= PanelContainer.new()
	card.name = "Row_%s" % _safe_name(
		str(
			row.get(
				"id",
				"row"
			)
		)
	)
	card.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	card.add_theme_stylebox_override(
		"panel",
		_row_style(
			bool(
				row.get(
					"enabled",
					true
				)
			),
			str(
				row.get(
					"row_kind",
					""
				)
			) == "mod_conflict"
		)
	)
	card.custom_minimum_size = Vector2(
		0.0,
		168.0
	)
	card.mouse_filter = Control.MOUSE_FILTER_PASS

	var root:= VBoxContainer.new()
	root.add_theme_constant_override(
		"separation",
		7
	)
	card.add_child(
		root
	)

	var title_row:= HBoxContainer.new()
	title_row.add_theme_constant_override(
		"separation",
		8
	)
	root.add_child(
		title_row
	)

	var title:= Label.new()
	title.text = str(
		row.get(
			"title",
			"Mod Contract"
		)
	)
	title.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	title.add_theme_font_size_override(
		"font_size",
		17
	)

	var title_default_color:= Color(
		0.94,
		0.92,
		1.0,
		1.0
	)
	var title_hover_color:= Color(
		1.0,
		0.88,
		0.58,
		1.0
	)
	title.add_theme_color_override(
		"font_color",
		title_default_color
	)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(
		title
	)

	var default_title: String = title.text
	var hover_title: String = str(
		row.get(
			"hover_title",
			default_title
		)
	)
	var animate_title_on_hover: bool = bool(
		row.get(
			"animate_title_on_hover",
			false
		)
	)
	var hover_controls: Array = []

	if row.has(
		"enabled"
	):
		var state_label:= Label.new()
		state_label.text = (
			"ENABLED"
				if bool(
					row.get(
						"enabled",
						false
					)
				)
				else "DISABLED"
		)
		state_label.add_theme_font_size_override(
			"font_size",
			11
		)
		state_label.add_theme_color_override(
			"font_color",
			(
				Color(
					0.55,
					0.95,
					0.69,
					1.0
				)
					if bool(
						row.get(
							"enabled",
							false
						)
					)
					else Color(
						0.95,
						0.58,
						0.58,
						1.0
					)
			)
		)
		title_row.add_child(
			state_label
		)

	var subtitle_text: String = str(
		row.get(
			"subtitle",
			""
		)
	).strip_edges()

	if subtitle_text != "":
		var subtitle:= Label.new()
		subtitle.text = subtitle_text
		subtitle.add_theme_font_size_override(
			"font_size",
			12
		)
		subtitle.add_theme_color_override(
			"font_color",
			Color(
				0.74,
				0.7,
				0.82,
				1.0
			)
		)
		root.add_child(
			subtitle
		)

	var description_text: String = str(
		row.get(
			"description",
			""
		)
	).strip_edges()

	if description_text != "":
		var description:= Label.new()
		description.text = description_text
		description.autowrap_mode = (
			TextServer.AUTOWRAP_WORD_SMART
		)
		description.add_theme_font_size_override(
			"font_size",
			13
		)
		description.add_theme_color_override(
			"font_color",
			Color(
				0.84,
				0.82,
				0.9,
				1.0
			)
		)
		root.add_child(
			description
		)

	var chips: Array = _array(
		row.get(
			"chips",
			[]
		)
	)

	if not chips.is_empty():
		var chips_row:= HBoxContainer.new()
		chips_row.add_theme_constant_override(
			"separation",
			6
		)
		root.add_child(
			chips_row
		)

		for raw_chip in chips:
			var chip:= Label.new()
			chip.text = " %s " % str(
				raw_chip
			)
			chip.add_theme_font_size_override(
				"font_size",
				10
			)
			chip.add_theme_color_override(
				"font_color",
				Color(
					0.78,
					0.73,
					0.92,
					1.0
				)
			)
			chip.add_theme_stylebox_override(
				"normal",
				_chip_style()
			)
			chips_row.add_child(
				chip
			)

	if str(
		row.get(
			"row_kind",
			""
		)
	) == "mod_setting":
		root.add_child(
			_build_setting_control(
				row
			)
		)

	var actions: Array = _array(
		row.get(
			"actions",
			[]
		)
	)

	if not actions.is_empty():
		var actions_row:= HBoxContainer.new()
		actions_row.alignment = (
			BoxContainer.ALIGNMENT_END
		)
		actions_row.add_theme_constant_override(
			"separation",
			8
		)
		root.add_child(
			actions_row
		)

		var persistent_action_count: int = 0
		var hover_action_count: int = 0

		for raw_action in actions:
			if typeof(
				raw_action
			) != TYPE_DICTIONARY:
				continue

			var action: Dictionary = raw_action as Dictionary
			var hover_only: bool = bool(
				action.get(
					"hover_only",
					false
				)
			)
			var button:= Button.new()
			button.text = str(
				action.get(
					"label",
					"Action"
				)
			)
			button.disabled = not bool(
				action.get(
					"enabled",
					true
				)
			)
			button.focus_mode = Control.FOCUS_NONE
			button.custom_minimum_size = Vector2(
				0.0,
				38.0
			)
			button.size_flags_horizontal = (
				Control.SIZE_EXPAND_FILL
			)
			button.visible = not hover_only
			button.mouse_filter = (
				Control.MOUSE_FILTER_STOP
					if not hover_only
					else Control.MOUSE_FILTER_IGNORE
			)
			_apply_window_chrome_button_style(
				button
			)
			animated_action_buttons.append({
				"button": button
			})
			button.pressed.connect(
				_on_action_pressed.bind(
					action.duplicate(true)
				)
			)
			actions_row.add_child(
				button
			)

			if hover_only:
				hover_action_count += 1
				hover_controls.append(
					button
				)
			else:
				persistent_action_count += 1

		if (
			hover_action_count > 0
				and persistent_action_count == 0
		):
			actions_row.visible = false
			actions_row.mouse_filter = (
				Control.MOUSE_FILTER_IGNORE
			)
			hover_controls.append(
				actions_row
			)

	var disabled_reason: String = str(
		row.get(
			"disabled_reason",
			""
		)
	).strip_edges()

	if disabled_reason != "":
		var reason_label:= Label.new()
		reason_label.text = disabled_reason
		reason_label.autowrap_mode = (
			TextServer.AUTOWRAP_WORD_SMART
		)
		reason_label.add_theme_font_size_override(
			"font_size",
			11
		)
		reason_label.add_theme_color_override(
			"font_color",
			Color(
				0.95,
				0.61,
				0.61,
				1.0
			)
		)
		root.add_child(
			reason_label
		)

	animated_row_cards.append({
		"card": card,
		"title": title,
		"default_title": default_title,
		"hover_title": hover_title,
		"animate_title_on_hover": animate_title_on_hover,
		"title_default_color": title_default_color,
		"title_hover_color": title_hover_color,
		"hover_controls": hover_controls
	})

	return card

func _build_setting_control(
	row: Dictionary
) -> Control:
	var setting_type: String = str(
		row.get(
			"setting_type",
			"string"
		)
	).strip_edges().to_lower()
	var mod_id: String = str(
		row.get(
			"mod_id",
			""
		)
	)
	var setting_id: String = str(
		row.get(
			"setting_id",
			""
		)
	)
	var current_value: Variant = row.get(
		"value"
	)
	var control_enabled: bool = bool(
		row.get(
			"enabled",
			true
		)
	)

	match setting_type:
		"bool", "boolean":
			var toggle:= CheckButton.new()
			toggle.text = "Enabled"
			toggle.button_pressed = bool(
				current_value
			)
			toggle.disabled = not control_enabled
			toggle.focus_mode = (
				Control.FOCUS_ALL
				if control_enabled
				else Control.FOCUS_NONE
			)
			toggle.toggled.connect(
				_on_setting_value_changed.bind(
					mod_id,
					setting_id
				)
			)
			return toggle

		"option":
			var picker:= OptionButton.new()
			var options: Array = _array(
				row.get(
					"options",
					[]
				)
			)

			for raw_option in options:
				picker.add_item(
					str(raw_option)
				)

				if raw_option == current_value:
					picker.select(
						picker.item_count - 1
					)

			picker.disabled = not control_enabled
			picker.focus_mode = (
				Control.FOCUS_ALL
				if control_enabled
				else Control.FOCUS_NONE
			)
			picker.item_selected.connect(
				_on_setting_option_selected.bind(
					picker,
					mod_id,
					setting_id
				)
			)
			return picker

		"int", "integer", "float", "number":
			var number:= SpinBox.new()
			number.value = float(
				current_value
			)
			number.allow_greater = true
			number.allow_lesser = true
			number.editable = control_enabled
			number.focus_mode = (
				Control.FOCUS_ALL
				if control_enabled
				else Control.FOCUS_NONE
			)
			number.step = (
				1.0
				if setting_type in [
					"int",
					"integer"
				]
				else 0.1
			)

			var line_edit: LineEdit = (
				number.get_line_edit()
			)

			if line_edit != null:
				line_edit.editable = control_enabled
				line_edit.focus_mode = (
					Control.FOCUS_ALL
					if control_enabled
					else Control.FOCUS_NONE
				)

			number.value_changed.connect(
				_on_setting_number_changed.bind(
					mod_id,
					setting_id,
					setting_type
				)
			)
			return number

		_:
			var text_input:= LineEdit.new()
			text_input.text = str(
				current_value
			)
			text_input.editable = control_enabled
			text_input.focus_mode = (
				Control.FOCUS_ALL
				if control_enabled
				else Control.FOCUS_NONE
			)
			text_input.text_submitted.connect(
				_on_setting_text_submitted.bind(
					mod_id,
					setting_id
				)
			)
			return text_input
func _emit_provider_setting_intent(
	row: Dictionary,
	value: Variant
) -> void:
	var outgoing: Dictionary = row.duplicate(true)
	outgoing ["action_id"] = str(
		row.get(
			"provider_action_id",
			row.get("action_id", "")
		)
	)
	outgoing ["value"] = value
	outgoing ["bundle_id"] = str(
		row.get(
			"bundle_id",
			active_contract.get("active_bundle_id", "")
		)
	)
	outgoing ["actor_id"] = active_actor_id
	outgoing ["source"] = "mod_menu_panel.provider_setting"
	outgoing ["ui_is_expression_only"] = true
	intent_requested.emit(outgoing)

func _on_section_pressed(
	section_id: String
) -> void:
	var clean_section: String = str(
		section_id
	).strip_edges().to_lower()

	if clean_section == "":
		return



	reveal_section(
		clean_section
	)

	set_meta(
		"last_section_press_id",
		clean_section
	)
	set_meta(
		"last_section_press_reveal_only",
		true
	)
	set_meta(
		"last_section_press_intent_emitted",
		false
	)
	set_meta(
		"last_section_press_engine_calls",
		false
	)
	set_meta(
		"last_section_press_build_performed",
		false
	)
	set_meta(
		"last_section_press_at_ms",
		int(
			Time.get_ticks_msec()
		)
	)
func _apply_presentation_contract(
	presentation: Dictionary
) -> void:
	if presentation.is_empty():
		return

	var palette: Dictionary = _dict(
		presentation.get(
			"palette",
			{}
		)
	)

	add_theme_stylebox_override(
		"panel",
		_panel_style_from_presentation(
			palette
		)
	)

	title_label.add_theme_color_override(
		"font_color",
		_contract_color(
			palette.get(
				"text",
				""
			),
			Color(
				0.96,
				0.93,
				1.0,
				1.0
			)
		)
	)

	subtitle_label.add_theme_color_override(
		"font_color",
		_contract_color(
			palette.get(
				"text_muted",
				""
			),
			Color(
				0.74,
				0.7,
				0.82,
				1.0
			)
		)
	)


func _panel_style_from_presentation(
	palette: Dictionary
) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = _contract_color(
		palette.get(
			"panel",
			""
		),
		Color(
			0.075,
			0.055,
			0.12,
			0.98
		)
	)
	style.border_color = _contract_color(
		palette.get(
			"border",
			""
		),
		Color(
			0.48,
			0.35,
			0.72,
			0.82
		)
	)
	style.set_border_width_all(1)
	style.set_corner_radius_all(18)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 16.0
	style.content_margin_bottom = 16.0

	return style


func _contract_color(
	value: Variant,
	fallback: Color
) -> Color:
	if value is Color:
		return value

	var text: String = str(
		value
	).strip_edges()

	if (
		text != ""
		and Color.html_is_valid(text)
	):
		return Color.html(text)

	return fallback
func _on_action_pressed(
	action: Dictionary
) -> void:
	var payload: Dictionary = action.duplicate(true)
	payload ["actor_id"] = active_actor_id
	payload ["section_id"] = active_section_id
	payload ["source"] = "mod_menu_panel.action"
	payload ["ui_is_expression_only"] = true
	intent_requested.emit(payload)


func _on_setting_value_changed(
	value: bool,
	mod_id: String,
	setting_id: String
) -> void:
	_emit_setting_intent(
		mod_id,
		setting_id,
		value
	)


func _on_setting_option_selected(
	index: int,
	picker: OptionButton,
	mod_id: String,
	setting_id: String
) -> void:
	_emit_setting_intent(
		mod_id,
		setting_id,
		picker.get_item_text(index)
	)


func _on_setting_number_changed(
	value: float,
	mod_id: String,
	setting_id: String,
	setting_type: String
) -> void:
	var resolved_value: Variant = value

	if setting_type in [
		"int",
		"integer"
	]:
		resolved_value = int(value)

	_emit_setting_intent(
		mod_id,
		setting_id,
		resolved_value
	)
func _on_setting_text_submitted(
	value: String,
	mod_id: String,
	setting_id: String
) -> void:
	_emit_setting_intent(
		mod_id,
		setting_id,
		value
	)


func _emit_setting_intent(
	mod_id: String,
	setting_id: String,
	value: Variant
) -> void:
	intent_requested.emit({
		"action_id": "set_mod_setting",
		"mod_id": mod_id,
		"setting_id": setting_id,
		"value": value,
		"actor_id": active_actor_id,
		"section_id": active_section_id,
		"source": "mod_menu_panel.setting",
		"ui_is_expression_only": true
	})


func _empty_section_text() -> String:
	return _empty_section_text_for(
		active_section_id
	)


func _empty_section_text_for(
	section_id: String
) -> String:
	var clean_section: String = str(
		section_id
	).strip_edges().to_lower()

	match clean_section:
		"bundles":
			return (
				"No installable reality bundles are "
				+ "currently observable."
			)

		"installed":
			return (
				"No mods are installed in this reality yet."
			)

		"marketplace":
			return (
				"No marketplace listings are currently observable."
			)

		"systems":
			return (
				"No mod providers are currently contributing systems."
			)

		"conflicts":
			return (
				"No provider conflicts are currently blocking reality."
			)

		"settings":
			return (
				"Installed mods have not exposed "
				+ "configurable settings."
			)

		"overview":
			return (
				"This reality bundle has not exposed "
				+ "an overview contract yet."
			)

		"components":
			return (
				"This reality bundle has no separately "
				+ "installable components."
			)

		"roles":
			return (
				"No roles are currently observable "
				+ "for this reality."
			)

		"survival":
			return (
				"No survival-status contracts are "
				+ "currently observable."
			)

		"resources":
			return (
				"No resource contracts are currently observable."
			)

		"tribe":
			return (
				"No tribe contracts are currently observable."
			)

		_:
			return (
				"No contracts are currently observable "
				+ "for this section."
			)


func _panel_style() -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(
		0.075,
		0.055,
		0.105,
		0.985
	)
	style.border_color = Color(
		0.56,
		0.4,
		0.82,
		0.92
	)
	style.set_border_width_all(2)
	style.set_corner_radius_all(20)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 16.0
	style.content_margin_bottom = 16.0
	style.shadow_color = Color(
		0.0,
		0.0,
		0.0,
		0.45
	)
	style.shadow_size = 18
	return style


func _row_style(
	enabled: bool,
	conflict: bool
) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(
		0.115,
		0.085,
		0.155,
		0.96
	)
	style.border_color = (
		Color(
			0.95,
			0.4,
			0.42,
			0.88
		)
		if conflict
		else (
			Color(
				0.48,
				0.34,
				0.72,
				0.82
			)
			if enabled
			else Color(
				0.32,
				0.3,
				0.36,
				0.76
			)
		)
	)
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	return style


func _chip_style() -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(
		0.22,
		0.16,
		0.31,
		0.92
	)
	style.border_color = Color(
		0.5,
		0.38,
		0.7,
		0.7
	)
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	return style


func _safe_name(
	value: String
) -> String:
	var clean: String = str(
		value
	).strip_edges()
	clean = clean.replace(" ", "_")
	clean = clean.replace("::", "_")
	clean = clean.replace(".", "_")
	clean = clean.replace("/", "_")
	return clean


func _clear_children(
	node: Node
) -> void:
	if node == null:
		return

	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


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