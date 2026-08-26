extends PanelContainer
class_name PropertyMarketPanel

signal close_requested
signal listing_action_requested(listing_id: String, action_id: String, action_context: Dictionary)

const PANEL_SCHEMA:= "eralife.market.property_market_panel"
const CONTRACT_VERSION:= 1

var host: Node = null
var gs: GameState = null
var actor: Person = null
var active_contract: Dictionary = {}
var active_render_signature: String = ""
var selected_listing_id: String = ""
var selected_variation_index_by_listing: Dictionary = {}
var listing_contract_by_id: Dictionary = {}

var title_label: Label = null
var subtitle_label: Label = null
var status_label: Label = null
var card_grid: GridContainer = null
var filter_grid: GridContainer = null
var filter_dock: PanelContainer = null
var property_card_scroll: ScrollContainer = null
var selected_property_filter: String = "all"
var property_filter_buttons: Dictionary = {}
var market_card_stream_generation: int = 0
var market_card_stream_armed_generation: int = -1
var market_card_stream_service_armed: bool = false
var market_card_stream_queue: Array = []
var market_card_stream_signature: String = ""
var market_card_stream_rendered_count: int = 0
var market_card_stream_target_count: int = 0
var market_card_stream_empty_status: String = ""
func _ready() -> void:
	_ensure_surface()


func bind_host(_host: Node, _gs: GameState = null) -> void:
	host = _host
	gs = _gs
	_ensure_surface()


func open_for_actor(
	target_actor: Person,
	surface_contract: Dictionary = {}
) -> void:
	actor = target_actor
	_ensure_surface()

	if target_actor != null:
		set_meta(
			"market_actor_id",
			int(target_actor.id)
		)

	if not surface_contract.is_empty():
		render_surface_contract(
			surface_contract
		)

	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_INHERIT
	set_meta(
		"market_surface_revealed_at_ms",
		int(Time.get_ticks_msec())
	)
	set_meta(
		"visible_click_build_required",
		false
	)

func render_surface_contract(
	surface_contract: Dictionary = {}
) -> void:
	_ensure_surface()

	var normalized: Dictionary = (
		_normalized_surface_contract(
			surface_contract
		)
	)
	var signature: String = (
		_surface_contract_render_signature(
			normalized
		)
	)
	var same_contract: bool = (
		signature != ""
		and signature == active_render_signature
		and not active_contract.is_empty()
	)
	var projection_is_present: bool = (
		_surface_projection_is_present(
			normalized
		)
	)
	var matching_stream_pending: bool = (
		signature != ""
		and signature == market_card_stream_signature
		and (
			not market_card_stream_queue.is_empty()
			or (
				market_card_stream_service_armed
				and market_card_stream_armed_generation
				== market_card_stream_generation
			)
		)
	)

	active_contract = normalized
	active_render_signature = signature

	_apply_shell_contract(
		active_contract
	)

	if (
		card_grid != null
		and is_instance_valid(
			card_grid
		)
	):
		card_grid.visible = true

	if (
		property_card_scroll != null
		and is_instance_valid(
			property_card_scroll
		)
	):
		property_card_scroll.visible = true

	if (
		filter_dock != null
		and is_instance_valid(
			filter_dock
		)
	):
		filter_dock.visible = true



	if (
		same_contract
		and (
			projection_is_present
			or matching_stream_pending
		)
	):
		if (
			matching_stream_pending
			and not market_card_stream_service_armed
		):
			_schedule_market_card_stream_quantum(
				market_card_stream_generation,
				0.016
			)

		set_meta(
			"surface_render_reused",
			true
		)
		set_meta(
			"surface_stream_reused",
			matching_stream_pending
		)
		set_meta(
			"visible_click_build_required",
			false
		)
		set_meta(
			"observable_partial_renderer_retired",
			projection_is_present
		)
		return

	_render_cards(
		active_contract
	)

	set_meta(
		"surface_render_reused",
		false
	)
	set_meta(
		"surface_projection_present",
		_surface_projection_is_present(
			active_contract
		)
	)
	set_meta(
		"surface_prepainted_at_ms",
		int(
			Time.get_ticks_msec()
		)
	)
	set_meta(
		"visible_click_build_required",
		false
	)
	set_meta(
		"observable_partial_renderer_retired",
		true
	)
	set_meta(
		"authoritative_contract_restored_card_visibility",
		true
	)
	set_meta(
		"market_cards_stream_in_live",
		true
	)
func _start_market_card_stream(
	jobs: Array,
	empty_status: String
) -> void:
	market_card_stream_generation += 1
	market_card_stream_armed_generation = -1
	market_card_stream_service_armed = false
	market_card_stream_queue = jobs.duplicate(
		false
	)
	market_card_stream_signature = (
		active_render_signature
	)
	market_card_stream_rendered_count = 0
	market_card_stream_target_count = jobs.size()
	market_card_stream_empty_status = str(
		empty_status
	).strip_edges()

	set_meta(
		"market_card_stream_generation",
		market_card_stream_generation
	)
	set_meta(
		"market_card_stream_signature",
		market_card_stream_signature
	)
	set_meta(
		"market_card_stream_target_count",
		market_card_stream_target_count
	)
	set_meta(
		"market_card_stream_rendered_count",
		0
	)
	set_meta(
		"market_card_stream_pending",
		not jobs.is_empty()
	)
	set_meta(
		"market_card_stream_complete",
		jobs.is_empty()
	)
	set_meta(
		"market_card_stream_one_card_per_timer_quantum",
		true
	)
	set_meta(
		"market_card_stream_process_frame_forbidden",
		true
	)
	set_meta(
		"market_card_stream_build_on_click",
		false
	)

	if jobs.is_empty():
		if status_label != null:
			status_label.text = (
				market_card_stream_empty_status
			)

		return

	if status_label != null:
		status_label.text = (
			"Publishing 0/%d market cards live."
			% market_card_stream_target_count
		)

	_schedule_market_card_stream_quantum(
		market_card_stream_generation,
		0.016
	)


func _schedule_market_card_stream_quantum(
	generation: int,
	delay_seconds: float = 0.016
) -> void:
	if generation != market_card_stream_generation:
		return

	if (
		market_card_stream_service_armed
		and market_card_stream_armed_generation
		== generation
	):
		return

	market_card_stream_service_armed = true
	market_card_stream_armed_generation = generation

	var tree:= Engine.get_main_loop() as SceneTree

	if tree == null:
		call_deferred(
			"_service_market_card_stream_quantum",
			generation
		)
		return

	var timer:= tree.create_timer(
		clampf(
			delay_seconds,
			0.016,
			0.25
		),
		true,
		false,
		true
	)

	timer.timeout.connect(
		Callable(
			self,
			"_service_market_card_stream_quantum"
		).bind(
			generation
		),
		CONNECT_ONE_SHOT
	)


func _service_market_card_stream_quantum(
	generation: int
) -> void:
	if market_card_stream_armed_generation == generation:
		market_card_stream_service_armed = false
		market_card_stream_armed_generation = -1

	if generation != market_card_stream_generation:
		return

	if market_card_stream_queue.is_empty():
		set_meta(
			"market_card_stream_pending",
			false
		)
		set_meta(
			"market_card_stream_complete",
			true
		)
		set_meta(
			"market_card_stream_completed_at_ms",
			int(
				Time.get_ticks_msec()
			)
		)

		if status_label != null:
			status_label.text = (
				"%d market cards are resident."
				% market_card_stream_rendered_count
			)

		return

	var job_raw: Variant = (
		market_card_stream_queue.pop_front()
	)
	var mounted: bool = false

	if typeof(job_raw) == TYPE_DICTIONARY:
		mounted = _append_market_card_stream_job(
			job_raw as Dictionary,
			active_contract
		)

	if mounted:
		market_card_stream_rendered_count += 1

	set_meta(
		"market_card_stream_rendered_count",
		market_card_stream_rendered_count
	)
	set_meta(
		"market_card_stream_remaining",
		market_card_stream_queue.size()
	)
	set_meta(
		"market_card_stream_pending",
		not market_card_stream_queue.is_empty()
	)
	set_meta(
		"market_card_stream_last_card_at_ms",
		int(
			Time.get_ticks_msec()
		)
	)

	if status_label != null:
		status_label.text = (
			"%d/%d market cards published live."
			% [
				market_card_stream_rendered_count,
				market_card_stream_target_count
			]
		)

	_schedule_market_card_stream_quantum(
		generation,
		0.016
	)


func _append_market_card_stream_job(
	job: Dictionary,
	_contract: Dictionary
) -> bool:
	if (
		card_grid == null
		or not is_instance_valid(
			card_grid
		)
	):
		return false

	if str(
		job.get(
			"kind",
			""
		)
	) != "property_listing":
		return false

	var card_raw: Variant = job.get(
		"card_contract",
		{}
	)

	if typeof(card_raw) != TYPE_DICTIONARY:
		return false

	var card_contract: Dictionary = (
		_register_listing_contract(
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
	_apply_market_card_primary_contract_label(
		card,
		card_contract
	)
	card_grid.add_child(
		card
	)

	return true
func apply_progressive_listing_patch(
	patch: Dictionary
) -> void:
	if patch.is_empty():
		return

	_ensure_surface()

	if card_grid != null:
		card_grid.visible = true

	if property_card_scroll != null:
		property_card_scroll.visible = true

	if filter_dock != null:
		filter_dock.visible = true

	var patch_kind: String = str(
		patch.get(
			"patch_kind",
			""
		)
	).strip_edges().to_lower()

	match patch_kind:
		"filters":
			var filters_raw: Variant = patch.get(
				"filter_contracts",
				[]
			)

			if typeof(filters_raw) != TYPE_ARRAY:
				return

			if active_contract.is_empty():
				active_contract = {
					"actor_id": int(
						patch.get(
							"actor_id",
							-1
						)
					),
					"filter_contracts": [],
					"listing_card_contracts": [],
					"ui_is_renderer_only": true
				}

			active_contract [
				"filter_contracts"
			] = filters_raw

			_render_property_filters(
				active_contract
			)

			set_meta(
				"progressive_property_market_filters_hot",
				true
			)
			set_meta(
				"progressive_property_market_filters_before_cards",
				true
			)

			if status_label != null:
				status_label.text = (
					"Filters are resident. Property contracts are publishing live."
				)

		"listing":
			var card_raw: Variant = patch.get(
				"listing_card_contract",
				{}
			)

			if typeof(card_raw) != TYPE_DICTIONARY:
				return

			var card_contract: Dictionary = (
				card_raw as Dictionary
			)

			var listing_id: String = str(
				card_contract.get(
					"listing_id",
					""
				)
			)

			if listing_id == "":
				return

			if listing_contract_by_id.has(
				listing_id
			):
				return

			var registered: Dictionary = (
				_register_listing_contract(
					card_contract
				)
			)

			if registered.is_empty():
				return

			if active_contract.is_empty():
				active_contract = {
					"listing_card_contracts": [],
					"filter_contracts": [],
					"ui_is_renderer_only": true
				}

			var active_rows_raw: Variant = (
				active_contract.get(
					"listing_card_contracts",
					[]
				)
			)

			var active_rows: Array = (
				(active_rows_raw as Array).duplicate(false)
				if typeof(active_rows_raw) == TYPE_ARRAY
				else []
			)

			active_rows.append(
				registered
			)

			active_contract [
				"listing_card_contracts"
			] = active_rows

			if _property_card_matches_filter(
				registered,
				selected_property_filter,
				active_contract
			):
				var card: Control = (
					_build_property_card(
						registered
					)
				)

				if card != null:
					_apply_market_card_primary_contract_label(
						card,
						registered
					)

					card_grid.add_child(
						card
					)

			if status_label != null:
				status_label.text = (
					"%d property contracts published live."
					% listing_contract_by_id.size()
				)

		"complete":
			var surface_raw: Variant = patch.get(
				"surface_contract",
				{}
			)

			if typeof(surface_raw) == TYPE_DICTIONARY:
				active_contract = (
					surface_raw as Dictionary
				).duplicate(false)

				_apply_shell_contract(
					active_contract
				)


				if not bool(
					get_meta(
						"progressive_property_market_filters_hot",
						false
					)
				):
					_render_property_filters(
						active_contract
					)

			if status_label != null:
				status_label.text = (
					"%d property contracts are resident."
					% int(
						patch.get(
							"listing_count",
							listing_contract_by_id.size()
						)
					)
				)

			set_meta(
				"progressive_property_market_complete",
				true
			)

		_:
			return

	set_meta(
		"progressive_property_market_last_patch",
		patch_kind
	)
	set_meta(
		"progressive_property_market_last_patch_at_ms",
		int(
			Time.get_ticks_msec()
		)
	)
func _surface_contract_render_signature(
	contract: Dictionary
) -> String:
	var explicit_signature: String = str(
		contract.get(
			"surface_signature",
			contract.get(
				"signature",
				""
			)
		)
	)

	return (
		"%s|schema:%s|actor:%s|era:%s|mode:%s|dealer:%s|template:%s|cards:%d|dealers:%d|filters:%d|truth:%s|status:%s"
		% [
			explicit_signature,
			str(
				contract.get(
					"schema",
					PANEL_SCHEMA
				)
			),
			str(
				contract.get(
					"actor_id",
					-1
				)
			),
			str(
				contract.get(
					"era_key",
					contract.get(
						"era",
						""
					)
				)
			),
			str(
				contract.get(
					"surface_mode",
					"inventory"
				)
			),
			str(
				contract.get(
					"selected_dealership_id",
					""
				)
			),
			str(
				contract.get(
					"selected_template_id",
					""
				)
			),
			_safe_array(
				contract.get(
					"listing_card_contracts",
					[]
				)
			).hash(),
			_safe_array(
				contract.get(
					"dealership_contracts",
					[]
				)
			).hash(),
			_safe_array(
				contract.get(
					"filter_contracts",
					[]
				)
			).hash(),
			str(
				contract.get(
					"truth_state",
					""
				)
			),
			str(
				contract.get(
					"status_text",
					""
				)
			)
		]
	)
func _surface_projection_is_present(
	surface_contract: Dictionary
) -> bool:
	if (
		title_label == null
		or not is_instance_valid(title_label)
		or status_label == null
		or not is_instance_valid(status_label)
	):
		return false

	var surface_mode: String = str(
		surface_contract.get(
			"surface_mode",
			"inventory"
		)
	)

	if surface_mode == "dealership_selector":
		var raw_dealership_grid: Variant = get(
			"vehicle_dealership_grid"
		)

		if (
			raw_dealership_grid is GridContainer
			and is_instance_valid(
				raw_dealership_grid
			)
		):
			var dealership_grid: GridContainer = (
				raw_dealership_grid
				as GridContainer
			)

			return (
				dealership_grid.get_child_count()
				> 0
			)

		return false

	var cards: Array = _safe_array(
		surface_contract.get(
			"listing_card_contracts",
			[]
		)
	)

	if cards.is_empty():
		return (
			str(status_label.text).strip_edges()
			!= ""
		)

	return (
		card_grid != null
		and is_instance_valid(card_grid)
		and card_grid.get_child_count() > 0
	)

func _ensure_surface() -> void:
	if title_label != null and is_instance_valid(title_label):
		return

	name = "PropertyMarketPanel"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 172
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_meta("schema", PANEL_SCHEMA)
	set_meta("ui_is_renderer_only", true)
	set_meta("filter_dock_never_obscures_cards", true)
	add_theme_stylebox_override("panel", _panel_style())

	var margin:= MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var root:= VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var top_bar:= HBoxContainer.new()
	top_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_theme_constant_override("separation", 12)
	root.add_child(top_bar)

	var back_button:= Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(116, 42)
	back_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	back_button.pressed.connect(func () -> void:
		close_requested.emit()
	)
	top_bar.add_child(back_button)

	title_label = Label.new()
	title_label.text = "PROPERTY MARKET"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 32)
	title_label.add_theme_color_override(
		"font_color",
		Color(0.92, 0.78, 0.52, 1.0)
	)
	top_bar.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_color_override(
		"font_color",
		Color(0.9, 0.86, 0.76, 0.86)
	)
	root.add_child(subtitle_label)



	property_card_scroll = ScrollContainer.new()
	property_card_scroll.name = "PropertyCardScroll"
	property_card_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	property_card_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	property_card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	property_card_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	property_card_scroll.set_meta(
		"renders_property_contract_cards_only",
		true
	)
	root.add_child(property_card_scroll)

	card_grid = GridContainer.new()
	card_grid.name = "PropertyCardGrid"
	card_grid.columns = 2
	card_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_grid.add_theme_constant_override("h_separation", 14)
	card_grid.add_theme_constant_override("v_separation", 14)
	property_card_scroll.add_child(card_grid)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.88, 0.72, 0.82)
	)
	root.add_child(status_label)


	filter_dock = PanelContainer.new()
	filter_dock.name = "PropertyFilterDock"
	filter_dock.custom_minimum_size = Vector2(0, 92)
	filter_dock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter_dock.clip_contents = false
	filter_dock.mouse_filter = Control.MOUSE_FILTER_STOP
	filter_dock.set_meta("dock_position", "bottom")
	filter_dock.set_meta("ui_is_renderer_only", true)
	filter_dock.add_theme_stylebox_override(
		"panel",
		_property_filter_dock_style()
	)
	root.add_child(filter_dock)

	var filter_margin:= MarginContainer.new()
	filter_margin.add_theme_constant_override("margin_left", 10)
	filter_margin.add_theme_constant_override("margin_top", 8)
	filter_margin.add_theme_constant_override("margin_right", 10)
	filter_margin.add_theme_constant_override("margin_bottom", 8)
	filter_dock.add_child(filter_margin)

	filter_grid = GridContainer.new()
	filter_grid.name = "PropertyFilterGrid"
	filter_grid.columns = 6
	filter_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter_grid.clip_contents = false
	filter_grid.add_theme_constant_override("h_separation", 6)
	filter_grid.add_theme_constant_override("v_separation", 6)
	filter_margin.add_child(filter_grid)

func _apply_shell_contract(contract: Dictionary) -> void:
	title_label.text = str(contract.get("title", "Property Market")).to_upper()
	subtitle_label.text = str(contract.get("subtitle", ""))
	status_label.text = str(contract.get("status_text", ""))
	set_meta("property_market_surface_contract", contract.duplicate(true))
	set_meta("ui_builds_truth_forbidden", true)

func _on_property_filter_selected(
	filter_id: String
) -> void:
	selected_property_filter = str(
		filter_id
	).strip_edges().to_lower()
	_render_cards(active_contract)


func _render_property_filters(
	contract: Dictionary
) -> void:
	property_filter_buttons.clear()

	for raw_filter in _safe_array(
		contract.get("filter_contracts", [])
	):
		var filter_contract: Dictionary = _safe_dictionary(
			raw_filter
		)
		var filter_id: String = str(
			filter_contract.get(
				"filter_id",
				""
			)
		).strip_edges().to_lower()

		if filter_id == "":
			continue

		var selected: bool = (
			selected_property_filter == filter_id
		)
		var accent: Color = _property_filter_accent(
			filter_contract,
			filter_id
		)
		var button:= Button.new()
		button.name = "PropertyFilter_%s" % filter_id
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
		button.button_pressed = selected
		button.custom_minimum_size = Vector2(0, 34)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.focus_mode = Control.FOCUS_ALL
		button.clip_contents = false
		button.set_meta("filter_id", filter_id)
		button.set_meta(
			"filter_contract",
			filter_contract.duplicate(true)
		)
		button.set_meta("filter_accent", accent)
		button.set_meta("ui_is_renderer_only", true)

		_style_property_filter_button(
			button,
			accent,
			selected
		)

		button.pressed.connect(
			_on_property_filter_selected.bind(
				filter_id
			)
		)
		button.mouse_entered.connect(
			_on_property_filter_hover_changed.bind(
				button,
				true
			)
		)
		button.mouse_exited.connect(
			_on_property_filter_hover_changed.bind(
				button,
				false
			)
		)
		button.focus_entered.connect(
			_on_property_filter_hover_changed.bind(
				button,
				true
			)
		)
		button.focus_exited.connect(
			_on_property_filter_hover_changed.bind(
				button,
				false
			)
		)

		filter_grid.add_child(button)
		property_filter_buttons [filter_id] = button

func _property_card_matches_filter(
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
		card_contract.get("ownership_status", ""),
		card_contract.get("availability", ""),
		card_contract.get("value_band", "")
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
		contract.get("filter_contracts", [])
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
				str(raw_match_tag).to_lower()
			):
				return true

		return false

	return true
func _register_listing_contract(
	card_contract: Dictionary
) -> Dictionary:
	var listing_id: String = str(
		card_contract.get(
			"listing_id",
			""
		)
	)

	if listing_id == "":
		return card_contract

	listing_contract_by_id [listing_id] = card_contract.duplicate(true)

	if not selected_variation_index_by_listing.has(listing_id):
		selected_variation_index_by_listing [listing_id] = int(
			card_contract.get(
				"active_variation_index",
				0
			)
		)

	return _project_active_listing_variation(
		card_contract
	)


func _project_active_listing_variation(
	card_contract: Dictionary
) -> Dictionary:
	var projected: Dictionary = card_contract.duplicate(true)
	var listing_id: String = str(
		projected.get(
			"listing_id",
			""
		)
	)
	var variations: Array = _safe_array(
		projected.get(
			"variation_contracts",
			[]
		)
	)

	if variations.is_empty():
		return projected

	var active_index: int = clampi(
		int(
			selected_variation_index_by_listing.get(
				listing_id,
				projected.get(
					"active_variation_index",
					0
				)
			)
		),
		0,
		variations.size() - 1
	)
	var variation: Dictionary = _safe_dictionary(
		variations [active_index]
	)

	for key in [
		"variation_id",
		"variation_label",
		"price",
		"price_text",
		"condition",
		"condition_text",
		"condition_applicable",
		"monthly_rent",
		"monthly_rent_text",
		"mortgage_down_payment",
		"mortgage_down_payment_text",
		"mortgage_monthly_payment",
		"mortgage_monthly_payment_text",
		"finance_down_payment",
		"finance_down_payment_text",
		"finance_monthly_payment",
		"finance_monthly_payment_text",
		"lease_due_today",
		"lease_due_today_text",
		"lease_monthly_payment",
		"lease_monthly_payment_text"
	]:
		if variation.has(key):
			projected [key] = variation [key]

	projected ["active_variation_index"] = active_index
	projected ["active_variation_contract"] = variation.duplicate(true)
	projected ["variation_count"] = variations.size()
	return projected


func _activate_or_cycle_listing_card(
	listing_id: String
) -> void:
	var clean_listing_id: String = str(
		listing_id
	).strip_edges()

	if clean_listing_id == "":
		return

	var previous_listing_id: String = str(
		selected_listing_id
	)

	if selected_listing_id != clean_listing_id:
		selected_listing_id = clean_listing_id

		call_deferred(
			"_refresh_market_listing_selection_projection",
			previous_listing_id,
			clean_listing_id
		)
		return

	var card_contract: Dictionary = _safe_dictionary(
		listing_contract_by_id.get(
			clean_listing_id,
			{}
		)
	)
	var variations: Array = _safe_array(
		card_contract.get(
			"variation_contracts",
			[]
		)
	)

	if variations.size() <= 1:
		selected_listing_id = ""

		call_deferred(
			"_refresh_market_listing_selection_projection",
			clean_listing_id,
			""
		)
		return

	var current_index: int = int(
		selected_variation_index_by_listing.get(
			clean_listing_id,
			0
		)
	)

	selected_variation_index_by_listing [
		clean_listing_id
	] = (
		(current_index + 1)
		% variations.size()
	)

	call_deferred(
		"_refresh_market_listing_card_projection",
		clean_listing_id
	)
func _market_listing_contract_from_card_node(
	card: Control
) -> Dictionary:
	if (
		card == null
		or not is_instance_valid(
			card
		)
	):
		return {}

	for meta_key in [
		"property_market_card_contract",
		"vehicle_market_card_contract"
	]:
		if not card.has_meta(
			meta_key
		):
			continue

		var raw_contract: Variant = card.get_meta(
			meta_key,
			{}
		)

		if typeof(raw_contract) == TYPE_DICTIONARY:
			return raw_contract as Dictionary

	return {}
func _refresh_market_listing_card_projection(
	listing_id: String
) -> void:
	var clean_listing_id: String = str(
		listing_id
	).strip_edges()

	if (
		clean_listing_id == ""
		or card_grid == null
		or not is_instance_valid(
			card_grid
		)
	):
		return

	var base_contract: Dictionary = _safe_dictionary(
		listing_contract_by_id.get(
			clean_listing_id,
			{}
		)
	)

	if base_contract.is_empty():


		return

	var existing_card: Control = null
	var existing_index: int = -1
	var children: Array = card_grid.get_children()

	for index in range(
		children.size()
	):
		var candidate:= children [index] as Control

		if candidate == null:
			continue

		var candidate_contract: Dictionary = (
			_market_listing_contract_from_card_node(
				candidate
			)
		)

		if str(
			candidate_contract.get(
				"listing_id",
				""
			)
		) != clean_listing_id:
			continue

		existing_card = candidate
		existing_index = index
		break

	if existing_card == null:
		return

	var projected_contract: Dictionary = (
		_project_active_listing_variation(
			base_contract
		)
	)
	var replacement: Control = _build_property_card(
		projected_contract
	)

	if replacement == null:
		return

	_apply_market_card_primary_contract_label(
		replacement,
		projected_contract
	)

	card_grid.add_child(
		replacement
	)
	card_grid.move_child(
		replacement,
		existing_index
	)

	existing_card.queue_free()

	set_meta(
		"market_card_selection_full_republish_performed",
		false
	)
	set_meta(
		"market_card_selection_single_card_refresh",
		true
	)
	set_meta(
		"market_card_selection_refreshed_listing_id",
		clean_listing_id
	)
func _refresh_market_listing_selection_projection(
	previous_listing_id: String,
	current_listing_id: String
) -> void:
	var previous_clean: String = str(
		previous_listing_id
	).strip_edges()
	var current_clean: String = str(
		current_listing_id
	).strip_edges()

	if previous_clean != "":
		_refresh_market_listing_card_projection(
			previous_clean
		)

	if (
		current_clean != ""
		and current_clean != previous_clean
	):
		_refresh_market_listing_card_projection(
			current_clean
		)

	set_meta(
		"market_listing_selection_restarted_stream",
		false
	)
func _apply_market_card_primary_contract_label(
	card: Control,
	card_contract: Dictionary
) -> void:
	if (
		card == null
		or not is_instance_valid(
			card
		)
	):
		return

	var display_label: String = str(
		card_contract.get(
			"name",
			card_contract.get(
				"title",
				card_contract.get(
					"display_name",
					"Asset"
				)
			)
		)
	).strip_edges()

	if display_label == "":
		return

	var queue: Array = [
		card
	]

	while not queue.is_empty():
		var node_raw: Variant = queue.pop_front()

		if not (node_raw is Node):
			continue

		var node:= node_raw as Node

		if node is Button:
			var button:= node as Button
			button.text = display_label
			button.set_meta(
				"generic_asset_name_icon_removed",
				true
			)
			return

		for child in node.get_children():
			queue.append(
				child
			)
func _on_market_card_body_gui_input(
	event: InputEvent,
	listing_id: String
) -> void:
	if not (
		event is InputEventMouseButton
	):
		return

	var mouse_event:= event as InputEventMouseButton

	if (
		mouse_event.button_index == MOUSE_BUTTON_LEFT
		and mouse_event.pressed
	):
		_activate_or_cycle_listing_card(
			listing_id
		)
		accept_event()


func _listing_action_context(
	listing_id: String
) -> Dictionary:
	var raw_card: Dictionary = _safe_dictionary(
		listing_contract_by_id.get(
			listing_id,
			{}
		)
	)
	var projected: Dictionary = _project_active_listing_variation(
		raw_card
	)
	var active_variation: Dictionary = _safe_dictionary(
		projected.get(
			"active_variation_contract",
			{}
		)
	)

	return {
		"variation_id": str(
			active_variation.get(
				"variation_id",
				projected.get(
					"variation_id",
					""
				)
			)
		),
		"active_variation_index": int(
			projected.get(
				"active_variation_index",
				0
			)
		),
		"resident_listing_contract": (
			projected.duplicate(false)
		),
		"listing_regeneration_forbidden": true,
		"amenity_resynthesis_forbidden": true,
		"source": "market_card_renderer",
		"ui_is_renderer_only": true
	}

func _add_market_condition_bar(
	parent: VBoxContainer,
	card_contract: Dictionary,
	accent: Color
) -> void:
	var applicable: bool = bool(
		card_contract.get(
			"condition_applicable",
			true
		)
	)
	var condition_value: float = clampf(
		float(
			card_contract.get(
				"condition",
				100.0
			)
		),
		0.0,
		100.0
	)
	var condition_text: String = str(
		card_contract.get(
			"condition_text",
			"Maintained"
		)
	)

	var header:= HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(header)

	var label:= Label.new()
	label.text = (
		"Living Asset"
		if not applicable
		else "Condition %d%% • %s" % [
			int(round(condition_value)),
			condition_text
		]
	)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
			0.96
		)
	)
	header.add_child(label)

	var variations: Array = _safe_array(
		card_contract.get(
			"variation_contracts",
			[]
		)
	)

	if variations.size() > 1:
		var variation_label:= Label.new()
		variation_label.text = "%s • %d/%d" % [
			str(
				card_contract.get(
					"variation_label",
					"Variation"
				)
			),
			int(
				card_contract.get(
					"active_variation_index",
					0
				)
			) + 1,
			variations.size()
		]
		variation_label.add_theme_color_override(
			"font_color",
			Color(0.9, 0.94, 1.0, 0.76)
		)
		header.add_child(variation_label)

	if not applicable:
		return

	var condition_bar:= ProgressBar.new()
	condition_bar.min_value = 0.0
	condition_bar.max_value = 100.0
	condition_bar.value = condition_value
	condition_bar.show_percentage = false
	condition_bar.custom_minimum_size = Vector2(
		0,
		12
	)

	var background:= StyleBoxFlat.new()
	background.bg_color = Color(0.05, 0.06, 0.09, 0.96)
	background.border_color = Color(
		accent.r,
		accent.g,
		accent.b,
		0.3
	)
	background.set_border_width_all(1)
	background.set_corner_radius_all(6)

	var fill:= StyleBoxFlat.new()
	fill.bg_color = Color(
		accent.r,
		accent.g,
		accent.b,
		0.94
	)
	fill.set_corner_radius_all(6)

	condition_bar.add_theme_stylebox_override(
		"background",
		background
	)
	condition_bar.add_theme_stylebox_override(
		"fill",
		fill
	)
	parent.add_child(condition_bar)
func _render_cards(
	contract: Dictionary
) -> void:
	_clear_children(
		card_grid
	)
	_clear_children(
		filter_grid
	)

	_render_property_filters(
		contract
	)

	listing_contract_by_id.clear()

	var cards: Array = _safe_array(
		contract.get(
			"listing_card_contracts",
			[]
		)
	)
	var jobs: Array = []
	var visible_listing_ids: Dictionary = {}

	for raw_card in cards:
		if typeof(raw_card) != TYPE_DICTIONARY:
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

		if not _property_card_matches_filter(
			base_card,
			selected_property_filter,
			contract
		):
			continue

		jobs.append({
			"kind": "property_listing",
			"listing_id": listing_id,
			"card_contract": base_card,
		})

	for raw_listing_id in (
		selected_variation_index_by_listing
		.keys()
		.duplicate()
	):
		if not visible_listing_ids.has(
			str(
				raw_listing_id
			)
		):
			selected_variation_index_by_listing.erase(
				raw_listing_id
			)

	_start_market_card_stream(
		jobs,
		"No property contracts match this filter."
	)
func _property_filter_dock_style() -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.041, 0.028, 0.985)
	style.border_color = Color(0.96, 0.7, 0.3, 0.52)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 4.0
	style.content_margin_top = 4.0
	style.content_margin_right = 4.0
	style.content_margin_bottom = 4.0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
	style.shadow_size = 12
	return style


func _property_filter_accent(
	filter_contract: Dictionary,
	filter_id: String
) -> Color:
	var raw_accent: Variant = filter_contract.get(
		"accent_color",
		null
	)

	if typeof(raw_accent) == TYPE_COLOR:
		return raw_accent

	match filter_id:
		"residential":
			return Color(0.33, 0.78, 1.0, 1.0)
		"commercial":
			return Color(0.32, 0.92, 0.68, 1.0)
		"government":
			return Color(0.45, 0.66, 1.0, 1.0)
		"military":
			return Color(0.78, 0.86, 0.4, 1.0)
		"royal":
			return Color(0.91, 0.58, 1.0, 1.0)
		"religious":
			return Color(0.96, 0.88, 0.62, 1.0)
		"fantasy":
			return Color(0.72, 0.42, 1.0, 1.0)
		"rental":
			return Color(0.96, 0.66, 0.32, 1.0)
		"owned":
			return Color(0.96, 0.82, 0.3, 1.0)
		"available":
			return Color(0.38, 0.92, 0.48, 1.0)
		"luxury":
			return Color(1.0, 0.56, 0.78, 1.0)
		_:
			return Color(0.96, 0.74, 0.36, 1.0)


func _style_property_filter_button(
	button: Button,
	accent: Color,
	selected: bool
) -> void:
	button.add_theme_stylebox_override(
		"normal",
		_property_filter_button_style(
			accent,
			"normal",
			selected
		)
	)
	button.add_theme_stylebox_override(
		"hover",
		_property_filter_button_style(
			accent,
			"hover",
			selected
		)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_property_filter_button_style(
			accent,
			"pressed",
			true
		)
	)
	button.add_theme_stylebox_override(
		"focus",
		_property_filter_button_style(
			accent,
			"focus",
			selected
		)
	)
	button.add_theme_color_override(
		"font_color",
		Color(0.98, 0.96, 0.9, 0.94)
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
	button.add_theme_font_size_override(
		"font_size",
		13
	)
	button.modulate = (
		Color.WHITE
		if selected
		else Color(0.91, 0.92, 0.94, 0.92)
	)
	button.scale = Vector2.ONE


func _property_filter_button_style(
	accent: Color,
	state: String,
	selected: bool
) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	var intensity: float = 0.12
	var border_alpha: float = 0.38
	var shadow_alpha: float = 0.1
	var shadow_size: int = 5

	match state:
		"hover", "focus":
			intensity = 0.24
			border_alpha = 0.86
			shadow_alpha = 0.26
			shadow_size = 11
		"pressed":
			intensity = 0.32
			border_alpha = 1.0
			shadow_alpha = 0.34
			shadow_size = 14

	if selected:
		intensity = maxf(intensity, 0.3)
		border_alpha = maxf(border_alpha, 0.96)
		shadow_alpha = maxf(shadow_alpha, 0.3)
		shadow_size = maxi(shadow_size, 13)

	style.bg_color = Color(
		accent.r * intensity,
		accent.g * intensity,
		accent.b * intensity,
		0.96
	)
	style.border_color = Color(
		accent.r,
		accent.g,
		accent.b,
		border_alpha
	)
	style.set_border_width_all(2 if selected else 1)
	style.set_corner_radius_all(9)
	style.content_margin_left = 8.0
	style.content_margin_top = 5.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 5.0
	style.shadow_color = Color(
		accent.r,
		accent.g,
		accent.b,
		shadow_alpha
	)
	style.shadow_size = shadow_size
	return style


func _on_property_filter_hover_changed(
	button: Button,
	hovered: bool
) -> void:
	if button == null or not is_instance_valid(button):
		return

	var selected: bool = button.button_pressed
	var target_scale: Vector2 = (
		Vector2(1.035, 1.035)
		if hovered
		else Vector2.ONE
	)
	var target_modulate: Color = (
		Color(1.08, 1.08, 1.08, 1.0)
		if hovered
		else Color.WHITE
		if selected
		else Color(0.91, 0.92, 0.94, 0.92)
	)

	var tween: Tween = button.create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(
		button,
		"scale",
		target_scale,
		0.16
	)
	tween.tween_property(
		button,
		"modulate",
		target_modulate,
		0.14
	)
func _add_property_fact(
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
		Color(1.0, 0.96, 0.88, 0.94)
	)
	row.add_child(value)



func _market_card_visual_contract(card_contract: Dictionary) -> Dictionary:
	return _safe_dictionary(card_contract.get("card_visual_contract", {}))


func _market_card_contract_color(
	visual_contract: Dictionary,
	key: String,
	fallback: Color
) -> Color:
	var raw_color: Variant = visual_contract.get(key, fallback)
	if typeof(raw_color) == TYPE_COLOR:
		return raw_color
	return fallback


func _market_card_panel_style(
	card_contract: Dictionary,
	selected: bool
) -> StyleBoxFlat:
	var visual: Dictionary = _market_card_visual_contract(card_contract)
	var accent: Color = _market_card_contract_color(
		visual,
		"accent_color",
		Color(1.0, 0.76, 0.34, 1.0)
	)
	var bloom: Color = _market_card_contract_color(
		visual,
		"bloom_color",
		accent
	)
	var dark_surface: Color = _market_card_contract_color(
		visual,
		"dark_surface_color",
		Color(0.08, 0.058, 0.038, 0.98)
	)

	var style:= StyleBoxFlat.new()
	style.bg_color = dark_surface.lerp(
		accent,
		0.1 if selected else 0.025
	)
	style.border_color = Color(
		accent.r,
		accent.g,
		accent.b,
		0.96 if selected else 0.42
	)
	style.set_border_width_all(2 if selected else 1)
	style.set_corner_radius_all(
		int(visual.get("rounded_corner_radius", 18))
	)
	style.shadow_color = Color(
		bloom.r,
		bloom.g,
		bloom.b,
		0.52 if selected else 0.16
	)
	style.shadow_size = 26 if selected else 10
	style.shadow_offset = Vector2.ZERO

	return style


func _market_card_button_style(
	accent: Color,
	state: String
) -> StyleBoxFlat:
	var clean_state: String = str(state).strip_edges().to_lower()
	var background: Color = accent.darkened(0.74)
	var border_alpha: float = 0.58
	var shadow_alpha: float = 0.18
	var shadow_size: int = 7

	if clean_state == "hover":
		background = accent.darkened(0.6)
		border_alpha = 0.94
		shadow_alpha = 0.46
		shadow_size = 16
	elif clean_state == "pressed":
		background = accent.darkened(0.82)
		border_alpha = 1.0
		shadow_alpha = 0.32
		shadow_size = 10
	elif clean_state == "disabled":
		background = accent.darkened(0.88)
		border_alpha = 0.2
		shadow_alpha = 0.04
		shadow_size = 2

	background.a = 0.98

	var style:= StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = Color(
		accent.r,
		accent.g,
		accent.b,
		border_alpha
	)
	style.set_border_width_all(1 if clean_state == "normal" else 2)
	style.set_corner_radius_all(13)
	style.shadow_color = Color(
		accent.r,
		accent.g,
		accent.b,
		shadow_alpha
	)
	style.shadow_size = shadow_size
	style.shadow_offset = Vector2.ZERO

	return style


func _style_market_card_button(
	button: Button,
	accent: Color
) -> void:
	if button == null:
		return

	button.add_theme_stylebox_override(
		"normal",
		_market_card_button_style(accent, "normal")
	)
	button.add_theme_stylebox_override(
		"hover",
		_market_card_button_style(accent, "hover")
	)
	button.add_theme_stylebox_override(
		"pressed",
		_market_card_button_style(accent, "pressed")
	)
	button.add_theme_stylebox_override(
		"focus",
		_market_card_button_style(accent, "hover")
	)
	button.add_theme_stylebox_override(
		"disabled",
		_market_card_button_style(accent, "disabled")
	)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.76, 0.78, 0.82, 0.62))


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
		_listing_action_context(
			clean_listing_id
		)
	)


func _append_selected_market_top_options(
	parent: VBoxContainer,
	card_contract: Dictionary,
	listing_id: String
) -> void:
	var visual: Dictionary = _market_card_visual_contract(card_contract)
	var accent: Color = _market_card_contract_color(
		visual,
		"accent_color",
		Color(1.0, 0.76, 0.34, 1.0)
	)
	var top_options: Array = _safe_array(
		card_contract.get(
			"top_option_contracts",
			card_contract.get("actions", [])
		)
	)

	if top_options.is_empty():
		return

	var option_title:= Label.new()
	option_title.text = "SELECT AN OPTION"
	option_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	option_title.add_theme_font_size_override("font_size", 13)
	option_title.add_theme_color_override(
		"font_color",
		Color(accent.r, accent.g, accent.b, 1.0)
	)
	parent.add_child(option_title)

	var option_grid:= GridContainer.new()
	option_grid.columns = 2
	option_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option_grid.add_theme_constant_override("h_separation", 8)
	option_grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(option_grid)

	for raw_option in top_options:
		var option: Dictionary = _safe_dictionary(raw_option)
		if option.is_empty():
			continue

		var action_id: String = str(option.get("action_id", "")).strip_edges()
		if action_id == "":
			continue

		var option_button:= Button.new()
		option_button.text = "%s %s" % [
			str(option.get("icon", "✦")),
			str(option.get("label", "Action"))
		]
		option_button.custom_minimum_size = Vector2(0, 44)
		option_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option_button.disabled = bool(option.get("disabled", false))
		option_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_style_market_card_button(option_button, accent)
		option_button.pressed.connect(
			_emit_market_listing_action.bind(
				listing_id,
				action_id
			)
		)
		option_grid.add_child(option_button)
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
		Color(1.0, 0.76, 0.34, 1.0)
	)

	var card:= PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(
		340,
		390 if not selected else 530
	)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.modulate = (
		Color.WHITE
		if (
			selected_listing_id == ""
			or selected
		)
		else Color(0.72, 0.74, 0.78, 0.5)
	)
	card.set_meta(
		"property_market_card_contract",
		card_contract.duplicate(true)
	)
	card.set_meta(
		"ui_is_renderer_only",
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
		_on_market_card_body_gui_input.bind(
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
	select_button.text = "🏠 %s" % str(
		card_contract.get(
			"title",
			"Property"
		)
	)
	select_button.custom_minimum_size = Vector2(
		0,
		46
	)
	select_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select_button.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND
	)
	_style_market_card_button(
		select_button,
		accent
	)
	select_button.pressed.connect(
		_activate_or_cycle_listing_card.bind(
			listing_id
		)
	)
	vbox.add_child(select_button)

	_add_market_condition_bar(
		vbox,
		card_contract,
		accent
	)

	if _safe_array(
		card_contract.get(
			"variation_contracts",
			[]
		)
	).size() > 1:
		var variation_hint:= Label.new()
		variation_hint.text = "Click the card again to view the next available condition and price."
		variation_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		variation_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		variation_hint.add_theme_font_size_override(
			"font_size",
			11
		)
		variation_hint.add_theme_color_override(
			"font_color",
			Color(0.88, 0.92, 1.0, 0.7)
		)
		vbox.add_child(variation_hint)

	if selected:
		_append_selected_market_top_options(
			vbox,
			card_contract,
			listing_id
		)

	_add_property_fact(
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
	_add_property_fact(
		vbox,
		"Category",
		str(
			card_contract.get(
				"category",
				"Residential"
			)
		).capitalize(),
		accent
	)
	_add_property_fact(
		vbox,
		"Ownership",
		str(
			card_contract.get(
				"ownership_status",
				"available"
			)
		).replace("_", " ").capitalize(),
		accent
	)
	_add_property_fact(
		vbox,
		"Availability",
		str(
			card_contract.get(
				"availability",
				"available"
			)
		).replace("_", " ").capitalize(),
		accent
	)
	_add_property_fact(
		vbox,
		"Vehicle Storage",
		"%d slot%s" % [
			int(
				card_contract.get(
					"vehicle_storage_capacity",
					0
				)
			),
			(
				""
				if int(
					card_contract.get(
						"vehicle_storage_capacity",
						0
					)
				) == 1
				else "s"
			)
		],
		accent
	)

	var amenity_label:= Label.new()
	amenity_label.text = "AMENITIES"
	amenity_label.add_theme_font_size_override(
		"font_size",
		12
	)
	amenity_label.add_theme_color_override(
		"font_color",
		Color(
			accent.r,
			accent.g,
			accent.b,
			0.88
		)
	)
	vbox.add_child(amenity_label)

	var amenity_text:= Label.new()
	amenity_text.text = str(
		card_contract.get(
			"amenity_summary",
			"No resolved amenities"
		)
	)
	amenity_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	amenity_text.add_theme_font_size_override(
		"font_size",
		13
	)
	amenity_text.add_theme_color_override(
		"font_color",
		Color(1.0, 0.93, 0.78, 0.9)
	)
	vbox.add_child(amenity_text)

	if selected:
		_add_property_fact(
			vbox,
			"Monthly Rent",
			str(
				card_contract.get(
					"monthly_rent_text",
					"$0"
				)
			),
			accent
		)
		_add_property_fact(
			vbox,
			"Mortgage Down",
			str(
				card_contract.get(
					"mortgage_down_payment_text",
					"$0"
				)
			),
			accent
		)
		_add_property_fact(
			vbox,
			"Mortgage Monthly",
			str(
				card_contract.get(
					"mortgage_monthly_payment_text",
					"$0"
				)
			),
			accent
		)

	return card

func _add_label(parent: Node, text: String, font_size: int, color: Color) -> void:
	var label:= Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)


func _normalized_surface_contract(surface_contract: Dictionary) -> Dictionary:
	var out: Dictionary = surface_contract.duplicate(true) if not surface_contract.is_empty() else {}
	out ["schema"] = str(out.get("schema", "eralife.market.property_market.surface_contract"))
	out ["panel_schema"] = PANEL_SCHEMA
	out ["panel_version"] = CONTRACT_VERSION
	out ["ui_is_renderer_only"] = true
	if typeof(out.get("listing_card_contracts", [])) != TYPE_ARRAY:
		out ["listing_card_contracts"] = []
	return out


func _panel_style() -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.04, 0.032, 0.985)
	style.border_color = Color(0.92, 0.7, 0.38, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0, 0, 0, 0.38)
	style.shadow_size = 14
	return style


func _card_style(selected: bool) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.105, 0.09, 0.065, 0.96)
	style.border_color = Color(1.0, 0.8, 0.42, 0.92 if selected else 0.45)
	style.set_border_width_all(2 if selected else 1)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(1.0, 0.72, 0.34, 0.22 if selected else 0.1)
	style.shadow_size = 14 if selected else 8
	return style

func _clear_children(node: Node) -> void:
	if node == null:
		return

	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []