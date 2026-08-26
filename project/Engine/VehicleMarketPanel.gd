extends PropertyMarketPanel
class_name VehicleMarketPanel
var selected_storage_destination_by_listing: Dictionary = {}
var vehicle_dealership_grid: GridContainer = null
var vehicle_filter_grid: GridContainer = null
var vehicle_card_scroll: ScrollContainer = null
var vehicle_change_dealership_button: Button = null
var selected_vehicle_filter: String = "all"
func _vehicle_listing_contract_index() -> Dictionary:
	var raw_index: Variant = get(
		"listing_contract_by_id"
	)

	if typeof(raw_index) == TYPE_DICTIONARY:
		return raw_index as Dictionary

	return {}


func _vehicle_selected_variation_index() -> Dictionary:
	var raw_index: Variant = get(
		"selected_variation_index_by_listing"
	)

	if typeof(raw_index) == TYPE_DICTIONARY:
		return raw_index as Dictionary

	return {}


func _vehicle_register_listing_contract(
	card_contract: Dictionary
) -> Dictionary:
	if has_method("_register_listing_contract"):
		return _safe_dictionary(
			call(
				"_register_listing_contract",
				card_contract
			)
		)

	return card_contract.duplicate(true)

func _vehicle_color_from_contract(
	card_contract: Dictionary
) -> Color:
	var color_hex: String = str(
		card_contract.get(
			"color_hex",
			"7A8494"
		)
	).strip_edges()

	if not color_hex.begins_with("#"):
		color_hex = "#%s" % color_hex

	return Color.from_string(
		color_hex,
		Color(0.48, 0.52, 0.58, 1.0)
	)


func _add_vehicle_color_visual(
	parent: VBoxContainer,
	card_contract: Dictionary
) -> void:
	if parent == null or not is_instance_valid(parent):
		return

	var color_name: String = str(
		card_contract.get(
			"color_name",
			"Factory Finish"
		)
	)
	var vehicle_color: Color = (
		_vehicle_color_from_contract(
			card_contract
		)
	)
	var row:= HBoxContainer.new()
	row.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	row.add_theme_constant_override(
		"separation",
		8
	)

	var swatch:= ColorRect.new()
	swatch.color = vehicle_color
	swatch.custom_minimum_size = Vector2(
		36,
		20
	)
	swatch.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	row.add_child(swatch)

	var label:= Label.new()
	label.text = "Color • %s" % color_name
	label.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	label.add_theme_color_override(
		"font_color",
		Color(
			0.9,
			0.94,
			1.0,
			0.92
		)
	)
	row.add_child(label)

	parent.add_child(row)
func _vehicle_listing_action_context(
	listing_id: String
) -> Dictionary:
	var context: Dictionary = {}

	if has_method("_listing_action_context"):
		context = _safe_dictionary(
			call(
				"_listing_action_context",
				listing_id
			)
		)

	context ["storage_destination_id"] = str(
		selected_storage_destination_by_listing.get(
			listing_id,
			""
		)
	)
	context ["source"] = "vehicle_market_panel"
	context ["ui_is_renderer_only"] = true

	return context
func _append_vehicle_storage_destination_selector(
	parent: VBoxContainer,
	card_contract: Dictionary,
	listing_id: String
) -> void:
	var destinations: Array = _safe_array(
		card_contract.get(
			"storage_destination_contracts",
			[]
		)
	)

	if destinations.is_empty():
		return

	var selected_destination_id: String = str(
		selected_storage_destination_by_listing.get(
			listing_id,
			card_contract.get(
				"default_storage_destination_id",
				""
			)
		)
	)

	if selected_destination_id != "":
		selected_storage_destination_by_listing [
			listing_id
		] = selected_destination_id

	var title:= Label.new()
	title.text = "STORE THIS VEHICLE"
	title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	title.add_theme_font_size_override(
		"font_size",
		13
	)
	title.add_theme_color_override(
		"font_color",
		Color(0.7, 0.88, 1.0, 1.0)
	)
	parent.add_child(title)

	var group:= ButtonGroup.new()
	group.allow_unpress = false

	var grid:= GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	grid.add_theme_constant_override(
		"h_separation",
		8
	)
	grid.add_theme_constant_override(
		"v_separation",
		8
	)
	parent.add_child(grid)

	for raw_destination in destinations:
		var destination: Dictionary = (
			_safe_dictionary(
				raw_destination
			)
		)
		var destination_id: String = str(
			destination.get(
				"destination_id",
				""
			)
		)

		if destination_id == "":
			continue

		var button:= Button.new()
		button.text = str(
			destination.get(
				"label",
				"Storage Destination"
			)
		)
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = (
			destination_id
			== selected_destination_id
		)
		button.disabled = bool(
			destination.get(
				"disabled",
				false
			)
		)
		button.tooltip_text = str(
			destination.get(
				"disabled_reason",
				destination.get(
					"description",
					""
				)
			)
		)
		button.custom_minimum_size = Vector2(
			0,
			42
		)
		button.size_flags_horizontal = (
			Control.SIZE_EXPAND_FILL
		)
		button.mouse_default_cursor_shape = (
			Control.CURSOR_POINTING_HAND
		)
		button.set_meta(
			"storage_destination_id",
			destination_id
		)
		button.set_meta(
			"ui_is_renderer_only",
			true
		)
		button.pressed.connect(func () -> void:
			selected_storage_destination_by_listing [
				listing_id
			] = destination_id
		)
		grid.add_child(button)

func _vehicle_activate_or_cycle_listing_card(
	listing_id: String
) -> void:
	if has_method("_activate_or_cycle_listing_card"):
		call(
			"_activate_or_cycle_listing_card",
			listing_id
		)


func _vehicle_market_card_body_gui_input(
	event: InputEvent,
	listing_id: String
) -> void:
	if has_method("_on_market_card_body_gui_input"):
		call(
			"_on_market_card_body_gui_input",
			event,
			listing_id
		)


func _vehicle_add_market_condition_bar(
	parent: VBoxContainer,
	card_contract: Dictionary,
	accent: Color
) -> void:
	if has_method("_add_market_condition_bar"):
		call(
			"_add_market_condition_bar",
			parent,
			card_contract,
			accent
		)
func _vehicle_start_market_card_stream(
	jobs: Array,
	empty_status: String
) -> void:




	if not has_method(
		"_start_market_card_stream"
	):
		set_meta(
			"vehicle_market_parent_stream_service_missing",
			true
		)
		set_meta(
			"vehicle_market_parallel_stream_created",
			false
		)

		push_error(
			"VehicleMarketPanel requires PropertyMarketPanel."
			+ "_start_market_card_stream(). "
			+ "No parallel Vehicle stream was created."
		)

		return

	set_meta(
		"vehicle_market_parent_stream_service_missing",
		false
	)
	set_meta(
		"vehicle_market_stream_authority",
		"PropertyMarketPanel"
	)
	set_meta(
		"vehicle_market_parallel_stream_created",
		false
	)
	set_meta(
		"vehicle_market_stream_build_on_click",
		false
	)
	set_meta(
		"vehicle_market_stream_ready_gate_member",
		false
	)

	call(
		"_start_market_card_stream",
		jobs,
		empty_status
	)
func _ensure_surface() -> void:
	if (
		title_label != null
		and is_instance_valid(title_label)
	):
		return

	name = "VehicleMarketPanel"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 173
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	set_meta(
		"schema",
		"eralife.market.vehicle_market_panel"
	)
	set_meta("ui_is_renderer_only", true)
	set_meta(
		"vehicle_names_and_brands_in_panel_forbidden",
		true
	)
	add_theme_stylebox_override(
		"panel",
		_panel_style()
	)

	var margin:= MarginContainer.new()
	margin.add_theme_constant_override(
		"margin_left",
		22
	)
	margin.add_theme_constant_override(
		"margin_top",
		18
	)
	margin.add_theme_constant_override(
		"margin_right",
		22
	)
	margin.add_theme_constant_override(
		"margin_bottom",
		18
	)
	add_child(margin)

	var root:= VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override(
		"separation",
		10
	)
	margin.add_child(root)

	var top_bar:= HBoxContainer.new()
	top_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_theme_constant_override(
		"separation",
		12
	)
	root.add_child(top_bar)

	var back_button:= Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(
		116,
		42
	)
	back_button.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND
	)
	back_button.pressed.connect(func () -> void:
		close_requested.emit()
	)
	top_bar.add_child(back_button)

	title_label = Label.new()
	title_label.text = "VEHICLE MARKET"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override(
		"font_size",
		32
	)
	title_label.add_theme_color_override(
		"font_color",
		Color(0.66, 0.86, 1.0, 1.0)
	)
	top_bar.add_child(title_label)

	vehicle_change_dealership_button = Button.new()
	vehicle_change_dealership_button.name = "ChangeDealershipButton"
	vehicle_change_dealership_button.text = "🏬 Dealerships"
	vehicle_change_dealership_button.custom_minimum_size = Vector2(
		154,
		42
	)
	vehicle_change_dealership_button.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND
	)
	vehicle_change_dealership_button.pressed.connect(func () -> void:
		listing_action_requested.emit(
			"",
			"clear_dealership",
			{}
		)
	)
	top_bar.add_child(
		vehicle_change_dealership_button
	)

	subtitle_label = Label.new()
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_color_override(
		"font_color",
		Color(0.78, 0.9, 1.0, 0.86)
	)
	root.add_child(subtitle_label)

	vehicle_dealership_grid = GridContainer.new()
	vehicle_dealership_grid.name = "DealershipGrid"
	vehicle_dealership_grid.columns = 3
	vehicle_dealership_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vehicle_dealership_grid.add_theme_constant_override(
		"h_separation",
		10
	)
	vehicle_dealership_grid.add_theme_constant_override(
		"v_separation",
		10
	)
	root.add_child(vehicle_dealership_grid)

	vehicle_filter_grid = GridContainer.new()
	vehicle_filter_grid.name = "VehicleFilterGrid"
	vehicle_filter_grid.columns = 8
	vehicle_filter_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vehicle_filter_grid.add_theme_constant_override(
		"h_separation",
		6
	)
	vehicle_filter_grid.add_theme_constant_override(
		"v_separation",
		6
	)
	root.add_child(vehicle_filter_grid)

	vehicle_card_scroll = ScrollContainer.new()
	vehicle_card_scroll.name = "VehicleCardScroll"
	vehicle_card_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vehicle_card_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vehicle_card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vehicle_card_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	root.add_child(vehicle_card_scroll)

	card_grid = GridContainer.new()
	card_grid.columns = 2
	card_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_grid.add_theme_constant_override(
		"h_separation",
		14
	)
	card_grid.add_theme_constant_override(
		"v_separation",
		14
	)
	vehicle_card_scroll.add_child(card_grid)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override(
		"font_color",
		Color(0.82, 0.92, 1.0, 0.82)
	)
	root.add_child(status_label)


func _render_cards(
	contract: Dictionary
) -> void:
	_clear_children(
		card_grid
	)
	_clear_children(
		vehicle_dealership_grid
	)
	_clear_children(
		vehicle_filter_grid
	)

	var listing_index: Dictionary = (
		_vehicle_listing_contract_index()
	)

	listing_index.clear()

	var surface_mode: String = str(
		contract.get(
			"surface_mode",
			"inventory"
		)
	).strip_edges().to_lower()
	var dealership_selector_available: bool = bool(
		contract.get(
			"dealership_selector_available",
			surface_mode == "dealership_selector"
		)
	)

	if (
		vehicle_change_dealership_button != null
		and is_instance_valid(
			vehicle_change_dealership_button
		)
	):
		vehicle_change_dealership_button.visible = (
			dealership_selector_available
		)
		vehicle_change_dealership_button.disabled = (
			not dealership_selector_available
		)
		vehicle_change_dealership_button.set_meta(
			"dealership_selector_available",
			dealership_selector_available
		)
		vehicle_change_dealership_button.set_meta(
			"era_visibility_contract_owned",
			true
		)

	if (
		vehicle_dealership_grid != null
		and is_instance_valid(
			vehicle_dealership_grid
		)
	):
		vehicle_dealership_grid.visible = (
			surface_mode == "dealership_selector"
		)

	if (
		vehicle_filter_grid != null
		and is_instance_valid(
			vehicle_filter_grid
		)
	):
		vehicle_filter_grid.visible = (
			surface_mode != "dealership_selector"
		)

	if (
		vehicle_card_scroll != null
		and is_instance_valid(
			vehicle_card_scroll
		)
	):
		vehicle_card_scroll.visible = (
			surface_mode != "dealership_selector"
		)

	var jobs: Array = []

	if surface_mode == "dealership_selector":
		var dealerships: Array = _safe_array(
			contract.get(
				"dealership_contracts",
				[]
			)
		)

		for raw_dealership in dealerships:
			if typeof(
				raw_dealership
			) != TYPE_DICTIONARY:
				continue

			var dealership: Dictionary = (
				raw_dealership as Dictionary
			)
			var dealership_id: String = str(
				dealership.get(
					"dealership_id",
					""
				)
			).strip_edges()

			if dealership_id == "":
				continue

			jobs.append({
				"kind": "dealership",
				"dealership_id": dealership_id,
				"dealership_contract": dealership,
			})

		_vehicle_start_market_card_stream(
			jobs,
			"No era-valid dealership contracts are observable."
		)

		return

	_render_vehicle_filters(
		contract
	)

	var cards: Array = _safe_array(
		contract.get(
			"listing_card_contracts",
			[]
		)
	)
	var visible_listing_ids: Dictionary = {}

	for raw_card in cards:
		if typeof(
			raw_card
		) != TYPE_DICTIONARY:
			continue

		var base_card: Dictionary = (
			raw_card as Dictionary
		)

		if base_card.is_empty():
			continue

		var listing_id: String = str(
			base_card.get(
				"listing_id",
				""
			)
		).strip_edges()

		if listing_id == "":
			continue

		visible_listing_ids [
			listing_id
		] = true

		if not _vehicle_card_matches_filter(
			base_card,
			selected_vehicle_filter,
			contract
		):
			continue

		jobs.append({
			"kind": "vehicle_listing",
			"listing_id": listing_id,
			"card_contract": base_card,
		})

	var variation_index: Dictionary = (
		_vehicle_selected_variation_index()
	)

	for raw_listing_id in (
		variation_index.keys().duplicate()
	):
		if not visible_listing_ids.has(
			str(
				raw_listing_id
			)
		):
			variation_index.erase(
				raw_listing_id
			)

	_vehicle_start_market_card_stream(
		jobs,
		"No mobility contracts match this filter."
	)
func _on_vehicle_dealership_selected(
	dealership_id: String
) -> void:
	listing_action_requested.emit(
		"dealership:%s" % dealership_id,
		"select_dealership",
		{}
	)

func _on_vehicle_filter_selected(
	filter_id: String
) -> void:
	selected_vehicle_filter = str(
		filter_id
	).strip_edges().to_lower()

	_render_cards(active_contract)


func _render_dealership_selector(
	contract: Dictionary
) -> void:
	_clear_children(
		vehicle_dealership_grid
	)

	var dealerships: Array = _safe_array(
		contract.get(
			"dealership_contracts",
			[]
		)
	)
	var jobs: Array = []

	for raw_dealership in dealerships:
		if typeof(
			raw_dealership
		) != TYPE_DICTIONARY:
			continue

		var dealership: Dictionary = (
			raw_dealership as Dictionary
		)
		var dealership_id: String = str(
			dealership.get(
				"dealership_id",
				""
			)
		).strip_edges()

		if dealership_id == "":
			continue

		jobs.append({
			"kind": "dealership",
			"dealership_id": dealership_id,
			"dealership_contract": dealership,
		})

	_vehicle_start_market_card_stream(
		jobs,
		"No era-valid dealership contracts are observable."
	)
func _render_vehicle_filters(
	contract: Dictionary
) -> void:
	var filters: Array = _safe_array(
		contract.get(
			"filter_contracts",
			[]
		)
	)

	for raw_filter in filters:
		var filter_contract: Dictionary = _safe_dictionary(
			raw_filter
		)
		var filter_id: String = str(
			filter_contract.get(
				"filter_id",
				""
			)
		)

		if filter_id == "":
			continue

		var button:= Button.new()
		button.text = "%s %s" % [
			str(
				filter_contract.get(
					"icon",
					"✦"
				)
			),
			str(
				filter_contract.get(
					"label",
					filter_id.capitalize()
				)
			)
		]
		button.toggle_mode = true
		button.button_pressed = (
			selected_vehicle_filter
			== filter_id
		)
		button.custom_minimum_size = Vector2(
			0,
			34
		)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		button.pressed.connect(
			_on_vehicle_filter_selected.bind(
				filter_id
			)
		)

		vehicle_filter_grid.add_child(
			button
		)


func _vehicle_card_matches_filter(
	card_contract: Dictionary,
	filter_id: String,
	contract: Dictionary
) -> bool:
	if filter_id == "" or filter_id == "all":
		return true

	var tags: Array = _safe_array(
		card_contract.get(
			"filter_tags",
			card_contract.get(
				"feature_tags",
				[]
			)
		)
	)

	for raw_value in [
		card_contract.get("category", ""),
		card_contract.get("movement_type", ""),
		card_contract.get("ownership_status", ""),
		card_contract.get("availability", "")
	]:
		var value: String = str(
			raw_value
		).strip_edges().to_lower()

		if (
			value != ""
			and not tags.has(value)
		):
			tags.append(value)

	for raw_filter in _safe_array(
		contract.get(
			"filter_contracts",
			[]
		)
	):
		var filter_contract: Dictionary = _safe_dictionary(
			raw_filter
		)

		if str(
			filter_contract.get(
				"filter_id",
				""
			)
		) != filter_id:
			continue

		for raw_match_tag in _safe_array(
			filter_contract.get(
				"match_tags",
				[]
			)
		):
			if tags.has(
				str(
					raw_match_tag
				).strip_edges().to_lower()
			):
				return true

		return false

	return true


func _market_card_visual_contract(card_contract: Dictionary) -> Dictionary:
	var visual_raw: Variant = card_contract.get("card_visual_contract", {})

	if typeof(visual_raw) == TYPE_DICTIONARY:
		return (visual_raw as Dictionary).duplicate(true)

	return {}


func _market_card_contract_color(
	visual_contract: Dictionary,
	key: String,
	fallback: Color
) -> Color:
	var raw_color: Variant = visual_contract.get(key, fallback)

	if typeof(raw_color) == TYPE_COLOR:
		return raw_color as Color

	if typeof(raw_color) == TYPE_STRING:
		var color_text: String = str(raw_color).strip_edges()

		if color_text != "":
			return Color.from_string(color_text, fallback)

	return fallback


func _market_card_panel_style(
	card_contract: Dictionary,
	selected: bool
) -> StyleBoxFlat:
	var visual: Dictionary = _market_card_visual_contract(card_contract)

	var accent_color: Color = _market_card_contract_color(
		visual,
		"accent_color",
		Color(0.34, 0.76, 1.0, 1.0)
	)
	var bloom_color: Color = _market_card_contract_color(
		visual,
		"bloom_color",
		Color(0.16, 0.9, 1.0, 1.0)
	)
	var dark_surface_color: Color = _market_card_contract_color(
		visual,
		"dark_surface_color",
		Color(0.025, 0.06, 0.09, 0.98)
	)

	var style:= StyleBoxFlat.new()
	style.bg_color = dark_surface_color.lerp(
		accent_color,
		0.1 if selected else 0.025
	)
	style.border_color = Color(
		accent_color.r,
		accent_color.g,
		accent_color.b,
		0.96 if selected else 0.42
	)
	style.set_border_width_all(2 if selected else 1)
	style.set_corner_radius_all(
		maxi(8, int(visual.get("rounded_corner_radius", 18)))
	)
	style.shadow_color = Color(
		bloom_color.r,
		bloom_color.g,
		bloom_color.b,
		0.52 if selected else 0.16
	)
	style.shadow_size = 26 if selected else 10
	style.shadow_offset = Vector2.ZERO

	return style


func _market_card_button_style(
	accent_color: Color,
	state: String
) -> StyleBoxFlat:
	var clean_state: String = str(state).strip_edges().to_lower()
	var background_color: Color = accent_color.darkened(0.74)
	var border_alpha: float = 0.58
	var border_width: int = 1
	var shadow_alpha: float = 0.18
	var shadow_size: int = 7

	match clean_state:
		"hover", "focus":
			background_color = accent_color.darkened(0.6)
			border_alpha = 0.94
			border_width = 2
			shadow_alpha = 0.46
			shadow_size = 16
		"pressed":
			background_color = accent_color.darkened(0.82)
			border_alpha = 1.0
			border_width = 2
			shadow_alpha = 0.32
			shadow_size = 10
		"disabled":
			background_color = accent_color.darkened(0.88)
			border_alpha = 0.2
			border_width = 1
			shadow_alpha = 0.04
			shadow_size = 2

	background_color.a = 0.98

	var style:= StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = Color(
		accent_color.r,
		accent_color.g,
		accent_color.b,
		border_alpha
	)
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(13)
	style.shadow_color = Color(
		accent_color.r,
		accent_color.g,
		accent_color.b,
		shadow_alpha
	)
	style.shadow_size = shadow_size
	style.shadow_offset = Vector2.ZERO
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0

	return style


func _style_market_card_button(
	button: Button,
	accent_color: Color
) -> void:
	if button == null or not is_instance_valid(button):
		return

	button.add_theme_stylebox_override(
		"normal",
		_market_card_button_style(accent_color, "normal")
	)
	button.add_theme_stylebox_override(
		"hover",
		_market_card_button_style(accent_color, "hover")
	)
	button.add_theme_stylebox_override(
		"pressed",
		_market_card_button_style(accent_color, "pressed")
	)
	button.add_theme_stylebox_override(
		"focus",
		_market_card_button_style(accent_color, "focus")
	)
	button.add_theme_stylebox_override(
		"disabled",
		_market_card_button_style(accent_color, "disabled")
	)

	button.add_theme_color_override(
		"font_color",
		Color(0.94, 0.98, 1.0, 1.0)
	)
	button.add_theme_color_override(
		"font_hover_color",
		Color.WHITE
	)
	button.add_theme_color_override(
		"font_pressed_color",
		Color.WHITE
	)
	button.add_theme_color_override(
		"font_focus_color",
		Color.WHITE
	)
	button.add_theme_color_override(
		"font_disabled_color",
		Color(0.76, 0.78, 0.82, 0.62)
	)

	button.set_meta("vehicle_market_visual_lens_applied", true)
	button.set_meta("vehicle_market_generic_gray_forbidden", true)
	button.set_meta("vehicle_market_visual_lens_applied_at_ms", int(Time.get_ticks_msec()))


func _emit_market_listing_action(
	listing_id: String,
	action_id: String
) -> void:
	var clean_listing_id: String = str(
		listing_id
	).strip_edges()
	var clean_action_id: String = str(
		action_id
	).strip_edges()

	if clean_listing_id == "" or clean_action_id == "":
		return

	listing_action_requested.emit(
		clean_listing_id,
		clean_action_id,
		_vehicle_listing_action_context(
			clean_listing_id
		)
	)
func _append_selected_market_top_options(
	parent: VBoxContainer,
	card_contract: Dictionary,
	listing_id: String
) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	_append_vehicle_storage_destination_selector(parent, card_contract, listing_id)
	var visual: Dictionary = _market_card_visual_contract(card_contract)
	var accent_color: Color = _market_card_contract_color(
		visual,
		"accent_color",
		Color(0.34, 0.76, 1.0, 1.0)
	)

	var top_options_raw: Variant = card_contract.get(
		"top_option_contracts",
		card_contract.get("actions", [])
	)
	var top_options: Array = (
		(top_options_raw as Array).duplicate(true)
		if typeof(top_options_raw) == TYPE_ARRAY
		else []
	)

	if top_options.is_empty():
		return

	var option_title:= Label.new()
	option_title.text = "SELECT AN OPTION"
	option_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	option_title.add_theme_font_size_override("font_size", 13)
	option_title.add_theme_color_override(
		"font_color",
		Color(
			accent_color.r,
			accent_color.g,
			accent_color.b,
			1.0
		)
	)
	option_title.set_meta("vehicle_market_top_options_title", true)
	parent.add_child(option_title)

	var option_grid:= GridContainer.new()
	option_grid.columns = 2
	option_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option_grid.add_theme_constant_override("h_separation", 8)
	option_grid.add_theme_constant_override("v_separation", 8)
	option_grid.set_meta("vehicle_market_selected_top_option_grid", true)
	option_grid.set_meta("ui_is_renderer_only", true)
	parent.add_child(option_grid)

	for raw_option in top_options:
		if typeof(raw_option) != TYPE_DICTIONARY:
			continue

		var option: Dictionary = (raw_option as Dictionary).duplicate(true)
		var action_id: String = str(option.get("action_id", "")).strip_edges()

		if action_id == "":
			continue

		var action_label: String = str(
			option.get("label", "Action")
		).strip_edges()
		var action_icon: String = str(
			option.get("icon", "✦")
		).strip_edges()

		var option_button:= Button.new()
		option_button.text = "%s %s" % [
			action_icon,
			action_label
		]
		option_button.custom_minimum_size = Vector2(0, 44)
		option_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option_button.disabled = bool(option.get("disabled", false))
		option_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		option_button.set_meta("vehicle_market_listing_id", listing_id)
		option_button.set_meta("vehicle_market_action_id", action_id)
		option_button.set_meta("vehicle_market_action_contract", option.duplicate(true))
		option_button.set_meta("ui_is_renderer_only", true)

		_style_market_card_button(
			option_button,
			accent_color
		)

		option_button.pressed.connect(
			_emit_market_listing_action.bind(
				listing_id,
				action_id
			)
		)

		option_grid.add_child(option_button)


func _add_mobility_field(
	parent: VBoxContainer,
	label_text: String,
	value_text: String,
	accent: Color
) -> void:
	var row:= HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override(
		"separation",
		8
	)
	parent.add_child(row)

	var label:= Label.new()
	label.text = label_text.to_upper()
	label.custom_minimum_size = Vector2(
		138,
		0
	)
	label.add_theme_font_size_override(
		"font_size",
		12
	)
	label.add_theme_color_override(
		"font_color",
		Color(
			accent.r,
			accent.g,
			accent.b,
			0.82
		)
	)
	row.add_child(label)

	var value:= Label.new()
	value.text = value_text
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.add_theme_font_size_override(
		"font_size",
		13
	)
	value.add_theme_color_override(
		"font_color",
		Color(0.92, 0.97, 1.0, 0.94)
	)
	row.add_child(value)

func _build_vehicle_dealership_stream_button(
	dealership: Dictionary
) -> Button:
	var dealership_id: String = str(
		dealership.get(
			"dealership_id",
			""
		)
	).strip_edges()

	if dealership_id == "":
		return null

	var accent_raw: Variant = dealership.get(
		"accent_color",
		Color(
			0.32,
			0.68,
			1.0
		)
	)
	var accent: Color = (
		accent_raw as Color
		if typeof(accent_raw) == TYPE_COLOR
		else Color(
			0.32,
			0.68,
			1.0
		)
	)
	var button:= Button.new()

	button.text = "%s %s\n%s" % [
		str(
			dealership.get(
				"icon",
				""
			)
		),
		str(
			dealership.get(
				"name",
				"Dealership"
			)
		),
		str(
			dealership.get(
				"category_label",
				"Mobility"
			)
		)
	]
	button.custom_minimum_size = Vector2(
		0,
		82
	)
	button.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	button.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND
	)
	button.tooltip_text = str(
		dealership.get(
			"description",
			""
		)
	)
	button.set_meta(
		"dealership_contract",
		dealership.duplicate(false)
	)
	button.set_meta(
		"ui_is_renderer_only",
		true
	)
	button.set_meta(
		"built_by_market_card_stream",
		true
	)

	_style_market_card_button(
		button,
		accent
	)

	button.pressed.connect(
		_on_vehicle_dealership_selected.bind(
			dealership_id
		)
	)

	return button
func _append_market_card_stream_job(
	job: Dictionary,
	_contract: Dictionary
) -> bool:
	var kind: String = str(
		job.get(
			"kind",
			""
		)
	).strip_edges().to_lower()

	match kind:
		"dealership":
			if (
				vehicle_dealership_grid == null
				or not is_instance_valid(
					vehicle_dealership_grid
				)
			):
				return false

			var dealership_raw: Variant = job.get(
				"dealership_contract",
				{}
			)

			if typeof(
				dealership_raw
			) != TYPE_DICTIONARY:
				return false

			var button: Button = (
				_build_vehicle_dealership_stream_button(
					dealership_raw as Dictionary
				)
			)

			if button == null:
				return false

			vehicle_dealership_grid.add_child(
				button
			)

			return true

		"vehicle_listing":
			if (
				card_grid == null
				or not is_instance_valid(
					card_grid
				)
			):
				return false

			var card_raw: Variant = job.get(
				"card_contract",
				{}
			)

			if typeof(card_raw) != TYPE_DICTIONARY:
				return false

			var card_contract: Dictionary = (
				_vehicle_register_listing_contract(
					card_raw as Dictionary
				)
			)

			if card_contract.is_empty():
				return false

			var card: Control = _build_property_card(
				card_contract
			)

			if card == null:
				return false

			card_grid.add_child(
				card
			)

			return true

	return false
func _build_property_card(
	card_contract: Dictionary
) -> Control:
	var listing_id: String = str(
		card_contract.get(
			"listing_id",
			""
		)
	)
	var selected: bool = (
		selected_listing_id == listing_id
	)
	var visual: Dictionary = _market_card_visual_contract(
		card_contract
	)
	var accent: Color = _market_card_contract_color(
		visual,
		"accent_color",
		Color(0.34, 0.76, 1.0, 1.0)
	)

	var card:= PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(
		340,
		450 if not selected else 610
	)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND
	)
	card.modulate = (
		Color.WHITE
		if (
			selected_listing_id == ""
			or selected
		)
		else Color(0.7, 0.76, 0.82, 0.5)
	)
	card.set_meta(
		"vehicle_market_card_contract",
		card_contract.duplicate(true)
	)
	card.set_meta(
		"ui_is_renderer_only",
		true
	)
	card.set_meta(
		"mobility_contract_only",
		true
	)
	card.set_meta(
		"whole_card_is_clickable",
		true
	)
	card.add_theme_stylebox_override(
		"panel",
		_market_card_panel_style(
			card_contract,
			selected
		)
	)
	card.gui_input.connect(
		_vehicle_market_card_body_gui_input.bind(
			listing_id
		)
	)

	var margin:= MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
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

	var vbox:= VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_theme_constant_override(
		"separation",
		7
	)
	margin.add_child(vbox)

	var select_button:= Button.new()
	select_button.text = "🚗 %s" % str(
		card_contract.get(
			"name",
			card_contract.get(
				"title",
				"Mobility Asset"
			)
		)
	)
	select_button.custom_minimum_size = Vector2(
		0,
		46
	)
	select_button.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	select_button.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND
	)
	_style_market_card_button(
		select_button,
		accent
	)
	select_button.pressed.connect(
		_vehicle_activate_or_cycle_listing_card.bind(
			listing_id
		)
	)
	vbox.add_child(select_button)

	_vehicle_add_market_condition_bar(
		vbox,
		card_contract,
		accent
	)
	_add_vehicle_color_visual(vbox, card_contract)
	if _safe_array(
		card_contract.get(
			"variation_contracts",
			[]
		)
	).size() > 1:
		var variation_hint:= Label.new()
		variation_hint.text = "Click the card again to inspect the next condition and price variation."
		variation_hint.autowrap_mode = (
			TextServer.AUTOWRAP_WORD_SMART
		)
		variation_hint.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_CENTER
		)
		variation_hint.add_theme_font_size_override(
			"font_size",
			11
		)
		variation_hint.add_theme_color_override(
			"font_color",
			Color(0.88, 0.94, 1.0, 0.7)
		)
		vbox.add_child(variation_hint)

	if selected:
		_append_selected_market_top_options(
			vbox,
			card_contract,
			listing_id
		)

	_add_mobility_field(
		vbox,
		"Price",
		str(
			card_contract.get(
				"price_text",
				"$0"
			)
		),
		accent
	)
	_add_mobility_field(
		vbox,
		"Movement Type",
		str(
			card_contract.get(
				"movement_type",
				"Unknown"
			)
		).replace("_", " ").capitalize(),
		accent
	)
	_add_mobility_field(
		vbox,
		"Seats",
		str(
			int(
				card_contract.get(
					"seats",
					1
				)
			)
		),
		accent
	)
	_add_mobility_field(
		vbox,
		"Era",
		str(
			card_contract.get(
				"era",
				"Unknown"
			)
		),
		accent
	)
	_add_mobility_field(
		vbox,
		"Terrain",
		", ".join(
			_safe_array(
				card_contract.get(
					"terrain",
					[]
				)
			)
		).replace("_", " ").capitalize(),
		accent
	)
	_add_mobility_field(
		vbox,
		"Fuel",
		str(
			card_contract.get(
				"fuel",
				"None"
			)
		).replace("_", " ").capitalize(),
		accent
	)
	_add_mobility_field(
		vbox,
		"Monthly Cost",
		str(
			card_contract.get(
				"monthly_cost_text",
				"$0"
			)
		),
		accent
	)
	_add_mobility_field(
		vbox,
		"Ownership Status",
		str(
			card_contract.get(
				"ownership_status",
				"Available"
			)
		).replace("_", " ").capitalize(),
		accent
	)
	_add_mobility_field(
		vbox,
		"Availability",
		str(
			card_contract.get(
				"availability",
				"Available"
			)
		).replace("_", " ").capitalize(),
		accent
	)
	_add_mobility_field(
		vbox,
		"Dealer",
		str(
			card_contract.get(
				"dealer",
				card_contract.get(
					"dealership_label",
					"Market"
				)
			)
		),
		accent
	)

	if selected:
		_add_mobility_field(
			vbox,
			"Finance Down",
			str(
				card_contract.get(
					"finance_down_payment_text",
					"$0"
				)
			),
			accent
		)
		_add_mobility_field(
			vbox,
			"Finance Monthly",
			str(
				card_contract.get(
					"finance_monthly_payment_text",
					"$0"
				)
			),
			accent
		)
		_add_mobility_field(
			vbox,
			"Lease Due",
			str(
				card_contract.get(
					"lease_due_today_text",
					"$0"
				)
			),
			accent
		)

	return card

func _panel_style() -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.042, 0.055, 0.985)
	style.border_color = Color(0.42, 0.72, 1.0, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0, 0, 0, 0.38)
	style.shadow_size = 14
	return style


func _card_style(selected: bool) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.078, 0.105, 0.96)
	style.border_color = Color(0.5, 0.82, 1.0, 0.92 if selected else 0.45)
	style.set_border_width_all(2 if selected else 1)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0.34, 0.68, 1.0, 0.24 if selected else 0.1)
	style.shadow_size = 14 if selected else 8
	return style