extends PanelContainer
class_name CareerHubPanel

signal request_intent(payload: Dictionary)
signal request_close()
signal request_person_profile(
	target_id: int,
	prepared_profile: Dictionary
)

const PANEL_SCHEMA:= "eralife.career_hub_contract"

var active_contract: Dictionary = {}
var active_actor_id: int = -1
var active_section_id: String = "overview"
var active_lane: String = "full_time"

var shell_root: VBoxContainer
var title_label: Label
var subtitle_label: Label
var time_label: Label
var section_bar: HBoxContainer
var content_root: VBoxContainer
var content_deck_root: VBoxContainer
var status_label: Label
var section_buttons: Dictionary = {}


var section_surface_build_queue: Array = []
var section_surface_build_generation: int = 0
var section_surface_build_service_active: bool = false


var career_opportunity_stream_rows: Array = []
var career_opportunity_stream_cursor: int = 0
var career_opportunity_stream_generation: int = 0
var career_opportunity_stream_active: bool = false
var career_opportunity_stream_root: VBoxContainer = null
var career_opportunity_stream_grid_by_group: Dictionary = {}
var career_opportunity_stream_status_label: Label = null
var career_opportunity_lane_root_by_id: Dictionary = {}
var career_opportunity_lane_button_by_id: Dictionary = {}
var career_opportunity_search_query: String = ""



var career_explore_surface_by_path_id: Dictionary = {}
var career_explore_overlay_host: Control = null
var career_explore_active_path_id: String = ""


var section_surface_deck: Dictionary = {}
var rendered_surface_revision: String = ""
var rendered_actor_id: int = -1
var back_button: Button
var identity_card: PanelContainer
var identity_name_label: Label
var identity_role_label: Label
var identity_context_label: Label
var identity_metrics_grid: GridContainer
var tab_scroll: ScrollContainer
var content_scroll: ScrollContainer

func _ready() -> void:
	_ensure_surface()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_status(
	text: String
) -> void:
	_set_status(
		text
	)
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
func _precompose_section_surfaces(
	tab_rows: Array
) -> void:
	if (
		content_deck_root == null
		or not is_instance_valid(
			content_deck_root
		)
	):
		return

	section_surface_build_generation += 1
	var generation: int = (
		section_surface_build_generation
	)

	section_surface_build_queue.clear()
	section_surface_build_service_active = false

	career_opportunity_stream_generation += 1
	career_opportunity_stream_active = false
	career_opportunity_stream_rows.clear()
	career_opportunity_stream_grid_by_group.clear()
	_clear_career_explore_surfaces()
	_clear(
		content_deck_root
	)
	section_surface_deck.clear()

	var requested_section: String = (
		active_section_id
	)
	var deferred_sections: Array = []

	for raw_tab in tab_rows:
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

		var surface:= VBoxContainer.new()
		surface.name = (
			"CareerSection_%s"
			% section_id
		)
		surface.size_flags_horizontal = (
			Control.SIZE_EXPAND_FILL
		)
		surface.add_theme_constant_override(
			"separation",
			10
		)
		surface.visible = false
		surface.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)
		surface.set_meta(
			"career_section_surface_built",
			false
		)

		var placeholder:= Label.new()
		placeholder.name = (
			"CareerSectionStreamingPlaceholder"
		)
		placeholder.text = (
			"Professional surface is streaming…"
		)
		placeholder.autowrap_mode = (
			TextServer.AUTOWRAP_WORD_SMART
		)
		placeholder.add_theme_font_size_override(
			"font_size",
			14
		)
		surface.add_child(
			placeholder
		)

		content_deck_root.add_child(
			surface
		)
		section_surface_deck [
			section_id
		] = surface

		if section_id == requested_section:
			section_surface_build_queue.push_front(
				section_id
			)
		else:
			deferred_sections.append(
				section_id
			)

	for raw_section_id in deferred_sections:
		section_surface_build_queue.append(
			raw_section_id
		)

	content_root = content_deck_root
	active_section_id = requested_section

	_reveal_section_surface(
		requested_section
	)

	_schedule_career_section_surface_build_quantum(
		generation
	)
func _clear_career_explore_surfaces() -> void:
	career_explore_active_path_id = ""
	career_explore_surface_by_path_id.clear()

	if (
		career_explore_overlay_host != null
		and is_instance_valid(
			career_explore_overlay_host
		)
	):
		career_explore_overlay_host.queue_free()

	career_explore_overlay_host = null


func _ensure_career_explore_overlay_host() -> Control:
	if (
		career_explore_overlay_host != null
		and is_instance_valid(
			career_explore_overlay_host
		)
	):
		return career_explore_overlay_host

	var host:= Control.new()
	host.name = "CareerExploreResidentOverlayHost"
	host.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	host.visible = false
	host.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	host.z_as_relative = false
	host.z_index = 850

	add_child(
		host
	)

	career_explore_overlay_host = host

	return host


func _precompose_career_explore_surface(
	row: Dictionary
) -> void:
	var path_id: String = str(
		row.get(
			"path_id",
			""
		)
	).strip_edges()

	if (
		path_id == ""
		or career_explore_surface_by_path_id.has(
			path_id
		)
	):
		return

	var host: Control = (
		_ensure_career_explore_overlay_host()
	)

	if host == null:
		return

	var overlay:= Control.new()
	overlay.name = (
		"CareerExplore_%s"
		% path_id
	)
	overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	overlay.visible = false
	overlay.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	host.add_child(
		overlay
	)

	var dim:= ColorRect.new()
	dim.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	dim.color = Color(
		0.0,
		0.0,
		0.0,
		0.52
	)
	dim.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	overlay.add_child(
		dim
	)

	var center:= CenterContainer.new()
	center.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	center.mouse_filter = (
		Control.MOUSE_FILTER_PASS
	)
	overlay.add_child(
		center
	)

	var card:= PanelContainer.new()
	card.custom_minimum_size = Vector2(
		620,
		390
	)
	card.add_theme_stylebox_override(
		"panel",
		_career_job_card_style(
			bool(
				row.get(
					"qualification_eligible",
					false
				)
			)
		)
	)
	center.add_child(
		card
	)

	var margin:= MarginContainer.new()
	margin.add_theme_constant_override(
		"margin_left",
		24
	)
	margin.add_theme_constant_override(
		"margin_top",
		22
	)
	margin.add_theme_constant_override(
		"margin_right",
		24
	)
	margin.add_theme_constant_override(
		"margin_bottom",
		22
	)
	card.add_child(
		margin
	)

	var root:= VBoxContainer.new()
	root.add_theme_constant_override(
		"separation",
		10
	)
	margin.add_child(
		root
	)

	_title(
		root,
		str(
			row.get(
				"title",
				"Career"
			)
		)
	)

	_body(
		root,
		str(
			row.get(
				"description",
				""
			)
		)
	)

	_secondary(
		root,
		"Institution: %s"
		% str(
			row.get(
				"organization_name",
				"Institution"
			)
		)
	)

	_secondary(
		root,
		"Department: %s"
		% str(
			row.get(
				"department_name",
				"General"
			)
		)
	)

	_secondary(
		root,
		"Entry rank: %s"
		% str(
			row.get(
				"entry_rank_title",
				"Entry Position"
			)
		)
	)

	_secondary(
		root,
		"Pay: %s"
		% str(
			row.get(
				"pay_text",
				"Unresolved"
			)
		)
	)

	var qualification_label:= Label.new()
	qualification_label.text = str(
		row.get(
			"eligibility_label",
			"Qualification unresolved"
		)
	)
	qualification_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	qualification_label.add_theme_font_size_override(
		"font_size",
		14
	)
	qualification_label.add_theme_color_override(
		"font_color",
		_presentation_color(
			(
				"eligible"
				if bool(
					row.get(
						"qualification_eligible",
						false
					)
				)
				else "ineligible"
			),
			Color.WHITE
		)
	)
	root.add_child(
		qualification_label
	)

	for raw_line in _array(
		row.get(
			"requirement_lines",
			[]
		)
	):
		_secondary(
			root,
			"• %s" % str(
				raw_line
			)
		)

	var spacer:= Control.new()
	spacer.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	root.add_child(
		spacer
	)

	var close_button:= Button.new()
	close_button.text = "CLOSE OVERVIEW"
	close_button.custom_minimum_size = Vector2(
		0,
		44
	)
	close_button.pressed.connect(
		_hide_career_explore_surface.bind(
			path_id
		)
	)
	root.add_child(
		close_button
	)

	career_explore_surface_by_path_id [
		path_id
	] = overlay


func _reveal_career_explore_surface(
	path_id: String
) -> void:
	var clean_path_id: String = str(
		path_id
	).strip_edges()

	if (
		clean_path_id == ""
		or not career_explore_surface_by_path_id.has(
			clean_path_id
		)
	):
		return

	for raw_path_id in (
		career_explore_surface_by_path_id.keys()
	):
		var surface: Control = (
			career_explore_surface_by_path_id.get(
				raw_path_id,
				null
			) as Control
		)

		if (
			surface == null
			or not is_instance_valid(
				surface
			)
		):
			continue

		var selected: bool = (
			str(
				raw_path_id
			) == clean_path_id
		)

		surface.visible = selected
		surface.mouse_filter = (
			Control.MOUSE_FILTER_STOP
			if selected
			else Control.MOUSE_FILTER_IGNORE
		)

	career_explore_active_path_id = (
		clean_path_id
	)

	if (
		career_explore_overlay_host != null
		and is_instance_valid(
			career_explore_overlay_host
		)
	):
		career_explore_overlay_host.visible = true
		career_explore_overlay_host.mouse_filter = (
			Control.MOUSE_FILTER_PASS
		)


func _hide_career_explore_surface(
	path_id: String = ""
) -> void:
	var clean_path_id: String = str(
		path_id
	).strip_edges()

	if clean_path_id == "":
		clean_path_id = (
			career_explore_active_path_id
		)

	var surface: Control = (
		career_explore_surface_by_path_id.get(
			clean_path_id,
			null
		) as Control
	)

	if (
		surface != null
		and is_instance_valid(
			surface
		)
	):
		surface.visible = false
		surface.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)

	career_explore_active_path_id = ""

	if (
		career_explore_overlay_host != null
		and is_instance_valid(
			career_explore_overlay_host
		)
	):
		career_explore_overlay_host.visible = false
		career_explore_overlay_host.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)
func _schedule_career_section_surface_build_quantum(
	generation: int
) -> void:
	if (
		generation
		!= section_surface_build_generation
		or section_surface_build_queue.is_empty()
	):
		section_surface_build_service_active = false
		return

	if section_surface_build_service_active:
		return

	section_surface_build_service_active = true

	var tree:= get_tree()

	if tree == null:
		call_deferred(
			"_service_career_section_surface_build_quantum",
			generation
		)
		return

	var timer:= tree.create_timer(
		0.024
	)
	timer.timeout.connect(
		Callable(
			self,
			"_service_career_section_surface_build_quantum"
		).bind(
			generation
		),
		CONNECT_ONE_SHOT
	)


func _service_career_section_surface_build_quantum(
	generation: int
) -> void:
	section_surface_build_service_active = false

	if generation != section_surface_build_generation:
		return

	if section_surface_build_queue.is_empty():
		return

	var section_id: String = str(
		section_surface_build_queue.pop_front()
	).strip_edges().to_lower()

	var surface:= section_surface_deck.get(
		section_id,
		null
	) as VBoxContainer

	if (
		surface != null
		and is_instance_valid(
			surface
		)
		and not bool(
			surface.get_meta(
				"career_section_surface_built",
				false
			)
		)
	):
		var previous_section: String = (
			active_section_id
		)
		var previous_root: VBoxContainer = (
			content_root
		)

		content_root = surface
		active_section_id = section_id

		_render_section()

		surface.set_meta(
			"career_section_surface_built",
			true
		)
		surface.set_meta(
			"career_section_surface_built_at_ms",
			int(
				Time.get_ticks_msec()
			)
		)

		content_root = previous_root
		active_section_id = previous_section

	_schedule_career_section_surface_build_quantum(
		generation
	)


func _prioritize_career_section_surface_build(
	section_id: String
) -> void:
	var clean_section: String = str(
		section_id
	).strip_edges().to_lower()

	if clean_section == "":
		return

	var surface:= section_surface_deck.get(
		clean_section,
		null
	) as Control

	if (
		surface != null
		and is_instance_valid(
			surface
		)
		and bool(
			surface.get_meta(
				"career_section_surface_built",
				false
			)
		)
	):
		return

	section_surface_build_queue.erase(
		clean_section
	)
	section_surface_build_queue.push_front(
		clean_section
	)

	_schedule_career_section_surface_build_quantum(
		section_surface_build_generation
	)

func _reveal_section_surface(
	section_id: String
) -> void:
	var clean_section: String = str(
		section_id
	).strip_edges().to_lower()

	if clean_section == "":
		clean_section = "overview"

	if not section_surface_deck.has(
		clean_section
	):
		clean_section = (
			"overview"
			if section_surface_deck.has(
				"overview"
			)
			else (
				str(
					section_surface_deck
					.keys()
					.front()
				)
				if not section_surface_deck.is_empty()
				else ""
			)
		)

	active_section_id = clean_section


	if (
		identity_card != null
		and is_instance_valid(
			identity_card
		)
	):
		var show_identity: bool = (
			clean_section == "overview"
		)
		identity_card.visible = show_identity
		identity_card.mouse_filter = (
			Control.MOUSE_FILTER_PASS
			if show_identity
			else Control.MOUSE_FILTER_IGNORE
		)

	for raw_section_id in section_surface_deck.keys():
		var stored_section_id: String = str(
			raw_section_id
		).strip_edges().to_lower()

		var surface: Control = (
			section_surface_deck.get(
				raw_section_id,
				null
			) as Control
		)

		if (
			surface == null
			or not is_instance_valid(
				surface
			)
		):
			continue

		var should_reveal: bool = (
			stored_section_id
			== clean_section
		)

		surface.visible = should_reveal
		surface.mouse_filter = (
			Control.MOUSE_FILTER_PASS
			if should_reveal
			else Control.MOUSE_FILTER_IGNORE
		)



	_prioritize_career_section_surface_build(
		clean_section
	)


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

	var may_reuse_deck: bool = (
		incoming_revision != ""
		and incoming_revision
		== rendered_surface_revision
		and incoming_actor_id
		== rendered_actor_id
		and not section_surface_deck.is_empty()
	)



	active_contract = contract
	active_actor_id = incoming_actor_id
	active_section_id = str(
		active_contract.get(
			"active_section",
			"overview"
		)
	).strip_edges().to_lower()
	active_lane = str(
		active_contract.get(
			"career_lane",
			"full_time"
		)
	).strip_edges().to_lower()

	if active_section_id == "":
		active_section_id = "overview"

	if active_lane not in [
		"full_time",
		"part_time"
	]:
		active_lane = "full_time"

	_apply_presentation_theme()

	title_label.text = str(
		active_contract.get(
			"title",
			"     CAREER HUB"
		)
	)
	subtitle_label.text = str(
		active_contract.get(
			"subtitle",
			"Professional reality is observable."
		)
	)
	time_label.text = str(
		active_contract.get(
			"current_time",
			""
		)
	)

	_render_identity_overview(
		_dict(
			active_contract.get(
				"identity_overview",
				{}
			)
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

	var tab_rows: Array = _array(
		active_contract.get(
			"section_tabs",
			[]
		)
	)
	_render_tabs(
		tab_rows
	)

	if not may_reuse_deck:
		rendered_surface_revision = (
			incoming_revision
		)
		rendered_actor_id = incoming_actor_id

		_precompose_section_surfaces(
			tab_rows
		)
		return

	_reveal_section_surface(
		active_section_id
	)

func open_observable_partial(
	contract: Dictionary
) -> void:
	open_contract(
		contract
	)


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

	add_theme_stylebox_override(
		"panel",
		_career_hub_panel_style(
			"shell"
		)
	)

	var outer_margin:= MarginContainer.new()
	outer_margin.add_theme_constant_override(
		"margin_left",
		24
	)
	outer_margin.add_theme_constant_override(
		"margin_top",
		20
	)
	outer_margin.add_theme_constant_override(
		"margin_right",
		24
	)
	outer_margin.add_theme_constant_override(
		"margin_bottom",
		20
	)
	add_child(
		outer_margin
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
	outer_margin.add_child(
		shell_root
	)




	var header_card:= PanelContainer.new()
	header_card.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	header_card.add_theme_stylebox_override(
		"panel",
		_career_hub_panel_style(
			"header"
		)
	)
	shell_root.add_child(
		header_card
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
	header_card.add_child(
		header_margin
	)

	var header:= HBoxContainer.new()
	header.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	header.add_theme_constant_override(
		"separation",
		14
	)
	header_margin.add_child(
		header
	)

	var brand_badge:= PanelContainer.new()
	brand_badge.custom_minimum_size = Vector2(
		58,
		58
	)
	brand_badge.add_theme_stylebox_override(
		"panel",
		_career_hub_panel_style(
			"brand_badge"
		)
	)
	header.add_child(
		brand_badge
	)

	var brand_icon:= Label.new()
	brand_icon.text = "💼"
	brand_icon.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	brand_icon.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)
	brand_icon.add_theme_font_size_override(
		"font_size",
		28
	)
	brand_badge.add_child(
		brand_icon
	)

	var title_box:= VBoxContainer.new()
	title_box.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	title_box.add_theme_constant_override(
		"separation",
		3
	)
	header.add_child(
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
			0.96,
			0.98,
			1.0,
			1.0
		)
	)
	title_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	title_box.add_child(
		title_label
	)

	subtitle_label = Label.new()
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
	subtitle_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	title_box.add_child(
		subtitle_label
	)

	var time_chip:= PanelContainer.new()
	time_chip.custom_minimum_size = Vector2(
		92,
		42
	)
	time_chip.add_theme_stylebox_override(
		"panel",
		_career_hub_panel_style(
			"time_chip"
		)
	)
	header.add_child(
		time_chip
	)

	time_label = Label.new()
	time_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	time_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)
	time_label.add_theme_font_size_override(
		"font_size",
		15
	)
	time_label.add_theme_color_override(
		"font_color",
		Color(
			0.88,
			0.93,
			1.0,
			1.0
		)
	)
	time_chip.add_child(
		time_label
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
	back_button.add_theme_font_size_override(
		"font_size",
		14
	)
	back_button.add_theme_color_override(
		"font_color",
		Color(
			0.96,
			0.98,
			1.0,
			1.0
		)
	)
	back_button.add_theme_stylebox_override(
		"normal",
		_career_hub_button_style(
			"normal",
			false
		)
	)
	back_button.add_theme_stylebox_override(
		"hover",
		_career_hub_button_style(
			"hover",
			false
		)
	)
	back_button.add_theme_stylebox_override(
		"pressed",
		_career_hub_button_style(
			"pressed",
			false
		)
	)
	back_button.add_theme_stylebox_override(
		"focus",
		_career_hub_button_style(
			"hover",
			false
		)
	)
	back_button.pressed.connect(
		close_panel
	)
	header.add_child(
		back_button
	)




	identity_card = PanelContainer.new()
	identity_card.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	identity_card.add_theme_stylebox_override(
		"panel",
		_career_hub_panel_style(
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
		13
	)
	identity_margin.add_theme_constant_override(
		"margin_right",
		18
	)
	identity_margin.add_theme_constant_override(
		"margin_bottom",
		13
	)
	identity_card.add_child(
		identity_margin
	)

	var identity_root:= VBoxContainer.new()
	identity_root.add_theme_constant_override(
		"separation",
		7
	)
	identity_margin.add_child(
		identity_root
	)

	var identity_top:= HBoxContainer.new()
	identity_top.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	identity_top.add_theme_constant_override(
		"separation",
		12
	)
	identity_root.add_child(
		identity_top
	)

	identity_name_label = Label.new()
	identity_name_label.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	identity_name_label.add_theme_font_size_override(
		"font_size",
		20
	)
	identity_name_label.add_theme_color_override(
		"font_color",
		Color(
			1.0,
			0.9,
			0.58,
			1.0
		)
	)
	identity_top.add_child(
		identity_name_label
	)

	identity_role_label = Label.new()
	identity_role_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_RIGHT
	)
	identity_role_label.add_theme_font_size_override(
		"font_size",
		16
	)
	identity_role_label.add_theme_color_override(
		"font_color",
		Color(
			0.77,
			0.88,
			1.0,
			1.0
		)
	)
	identity_role_label.text_overrun_behavior = (
		TextServer.OVERRUN_TRIM_ELLIPSIS
	)
	identity_top.add_child(
		identity_role_label
	)

	identity_context_label = Label.new()
	identity_context_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	identity_context_label.add_theme_font_size_override(
		"font_size",
		13
	)
	identity_context_label.add_theme_color_override(
		"font_color",
		Color(
			0.72,
			0.79,
			0.91,
			1.0
		)
	)
	identity_root.add_child(
		identity_context_label
	)

	identity_metrics_grid = GridContainer.new()
	identity_metrics_grid.columns = 3
	identity_metrics_grid.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	identity_metrics_grid.add_theme_constant_override(
		"h_separation",
		8
	)
	identity_metrics_grid.add_theme_constant_override(
		"v_separation",
		8
	)
	identity_root.add_child(
		identity_metrics_grid
	)




	tab_scroll = ScrollContainer.new()
	tab_scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_AUTO
	)
	tab_scroll.vertical_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)
	tab_scroll.custom_minimum_size = Vector2(
		0,
		52
	)
	shell_root.add_child(
		tab_scroll
	)

	section_bar = HBoxContainer.new()
	section_bar.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
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

	content_deck_root = VBoxContainer.new()
	content_deck_root.name = "ContentDeckRoot"
	content_deck_root.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	content_deck_root.add_theme_constant_override(
		"separation",
		10
	)
	content_scroll.add_child(
		content_deck_root
	)



	content_root = content_deck_root

	status_label = Label.new()
	status_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	status_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	status_label.add_theme_font_size_override(
		"font_size",
		13
	)
	status_label.add_theme_color_override(
		"font_color",
		Color(
			0.76,
			0.85,
			1.0,
			1.0
		)
	)
	shell_root.add_child(
		status_label
	)
func _render_identity_overview(
	identity: Dictionary
) -> void:
	if (
		identity_name_label == null
		or identity_metrics_grid == null
	):
		return

	var resolved: Dictionary = (
		identity.duplicate(true)
	)

	if resolved.is_empty():
		resolved = {
			"name": str(
				active_contract.get(
					"actor_name",
					"Current Life"
				)
			),
			"position_title": "Career Explorer",
			"organization_name": (
				"No Current Organization"
			),
			"department_name": (
				"Professional Discovery"
			),
			"employment_status": (
				"Exploring Careers"
			),
			"age": 0,
			"era_name": str(
				active_contract.get(
					"era_name",
					"Unknown Era"
				)
			),
			"performance": 0,
			"reputation_score": 0,
			"reputation_stars": "☆☆☆☆☆",
			"satisfaction": 0,
			"work_stress": 0
		}

	identity_name_label.text = str(
		resolved.get(
			"name",
			"Current Life"
		)
	)
	identity_role_label.text = str(
		resolved.get(
			"position_title",
			"Career Explorer"
		)
	)
	identity_context_label.text = (
		"%s  •  %s  •  %s"
		% [
			str(
				resolved.get(
					"organization_name",
					"No Current Organization"
				)
			),
			str(
				resolved.get(
					"department_name",
					"Professional Discovery"
				)
			),
			str(
				resolved.get(
					"employment_status",
					"Exploring Careers"
				)
			)
		]
	)

	_clear(
		identity_metrics_grid
	)

	var metrics: Array = [
		{
			"label": "AGE",
			"value": str(
				resolved.get(
					"age",
					0
				)
			)
		},
		{
			"label": "ERA",
			"value": str(
				resolved.get(
					"era_name",
					"Unknown"
				)
			)
		},
		{
			"label": "PERFORMANCE",
			"value": str(
				resolved.get(
					"performance",
					0
				)
			)
		},
		{
			"label": "REPUTATION",
			"value": "%s %s" % [
				str(
					resolved.get(
						"reputation_stars",
						"☆☆☆☆☆"
					)
				),
				str(
					resolved.get(
						"reputation_score",
						0
					)
				)
			]
		},
		{
			"label": "SATISFACTION",
			"value": str(
				resolved.get(
					"satisfaction",
					0
				)
			)
		},
		{
			"label": "STRESS",
			"value": str(
				resolved.get(
					"work_stress",
					0
				)
			)
		}
	]

	for raw_metric in metrics:
		_identity_metric_chip(
			_dict(
				raw_metric
			)
		)


func _identity_metric_chip(
	metric: Dictionary
) -> void:
	var chip:= PanelContainer.new()
	chip.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	chip.custom_minimum_size = Vector2(
		122,
		54
	)
	chip.add_theme_stylebox_override(
		"panel",
		_career_hub_panel_style(
			"metric_chip"
		)
	)
	identity_metrics_grid.add_child(
		chip
	)

	var chip_box:= VBoxContainer.new()
	chip_box.alignment = (
		BoxContainer.ALIGNMENT_CENTER
	)
	chip.add_child(
		chip_box
	)

	var chip_label:= Label.new()
	chip_label.text = str(
		metric.get(
			"label",
			"METRIC"
		)
	)
	chip_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	chip_label.add_theme_font_size_override(
		"font_size",
		10
	)
	chip_label.add_theme_color_override(
		"font_color",
		Color(
			0.58,
			0.68,
			0.86,
			1.0
		)
	)
	chip_box.add_child(
		chip_label
	)

	var chip_value:= Label.new()
	chip_value.text = str(
		metric.get(
			"value",
			"—"
		)
	)
	chip_value.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	chip_value.add_theme_font_size_override(
		"font_size",
		14
	)
	chip_value.add_theme_color_override(
		"font_color",
		Color(
			0.94,
			0.97,
			1.0,
			1.0
		)
	)
	chip_value.text_overrun_behavior = (
		TextServer.OVERRUN_TRIM_ELLIPSIS
	)
	chip_box.add_child(
		chip_value
	)


func _render_tabs(
	rows: Array
) -> void:
	if (
		shell_root != null
		and is_instance_valid(
			shell_root
		)
		and tab_scroll != null
		and is_instance_valid(
			tab_scroll
		)
		and identity_card != null
		and is_instance_valid(
			identity_card
		)
		and tab_scroll.get_parent() == shell_root
		and identity_card.get_parent() == shell_root
		and tab_scroll.get_index() > identity_card.get_index()
	):
		shell_root.move_child(
			tab_scroll,
			identity_card.get_index()
		)

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

		button.text = "%s %s" % [
			str(
				row.get(
					"icon",
					""
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
			138,
			38
		)
		button.mouse_default_cursor_shape = (
			Control.CURSOR_POINTING_HAND
		)
		button.add_theme_font_size_override(
			"font_size",
			11
		)
		button.set_meta(
			"career_hub_section_id",
			section_id
		)

		_apply_tab_button_style(
			button,
			section_id == active_section_id
		)

		button.pressed.connect(
			_on_section.bind(
				section_id
			)
		)

		section_bar.add_child(
			button
		)

		section_buttons [
			section_id
		] = button

func _render_section() -> void:
	_clear(
		content_root
	)

	match active_section_id:
		"overview":
			_render_overview()
		"actions":
			_render_actions()
		"workplace":
			_render_workplace()
		"people":
			_render_people()
		"workflow":
			_render_workflow()
		"organization":
			_render_organization()
		"opportunities":
			_render_opportunities()
		"education":
			_render_education()
		"reputation":
			_render_reputation()
		"promotion":
			_render_promotion()
		"timeline":
			_render_timeline()
		_:
			_empty(
				"No Career Hub section is observable."
			)
func _render_primary_job_actions() -> void:
	var published_actions: Array = _array(
		active_contract.get(
			"primary_job_actions",
			[]
		)
	)

	if published_actions.is_empty():
		return

	_banner(
		"POSITION ACTIONS"
	)

	var action_grid: GridContainer = _career_card_grid(
		3,
		content_root
	)

	for raw_action in published_actions:
		if typeof(raw_action) != TYPE_DICTIONARY:
			continue

		var action: Dictionary = (
			raw_action as Dictionary
		)

		var action_id: String = str(
			action.get(
				"action_id",
				""
			)
		).strip_edges().to_lower()

		if action_id not in [
			"request_promotion",
			"request_raise",
			"retire",
			"quit_position",
			"view_coworkers"
		]:
			continue

		_action(
			action_grid,
			action
		)
func _render_overview() -> void:
	_header(
		"CURRENT POSITION"
	)

	var grid: GridContainer = _career_card_grid(
		3,
		content_root
	)

	for raw_card in _array(
		active_contract.get(
			"overview_cards",
			[]
		)
	):
		_render_card(
			_dict(
				raw_card
			),
			grid,
			true
		)
func _render_actions() -> void:
	_header(
		"ACTIONS"
	)

	_render_workload_controls()
	_render_primary_job_actions()
func _render_workload_controls() -> void:
	var workload: Dictionary = _dict(
		active_contract.get(
			"workload_contract",
			{}
		)
	)

	if not bool(
		workload.get(
			"employed",
			false
		)
	):
		return

	_banner(
		str(
			workload.get(
				"weekly_hours_label",
				"WEEKLY HOURS"
			)
		)
	)

	var current_hours: int = int(
		workload.get(
			"weekly_hours",
			40
		)
	)

	_render_card(
		{
			"title": (
				"%d HOURS PER WEEK"
				% current_hours
			),
			"description": str(
				workload.get(
					"performance_forecast",
					""
				)
			),
			"lines": [
				(
					"Player-selectable maximum: %d hours"
					% int(
						workload.get(
							"player_selectable_max",
							50
						)
					)
				),
				(
					"Overwork threshold: %d hours"
					% int(
						workload.get(
							"overwork_threshold",
							50
						)
					)
				)
			]
		},
		content_root,
		true
	)

	var hour_grid: GridContainer = _career_card_grid(
		5,
		content_root
	)

	for raw_action in _array(
		workload.get(
			"hour_actions",
			[]
		)
	):
		_action(
			hour_grid,
			_dict(
				raw_action
			)
		)

	var harder_action: Dictionary = _dict(
		workload.get(
			"work_harder_action",
			{}
		)
	)

	if not harder_action.is_empty():
		var effort_grid: GridContainer = _career_card_grid(
			3,
			content_root
		)

		_action(
			effort_grid,
			harder_action
		)
func _render_workplace() -> void:
	var contract: Dictionary = _dict(
		active_contract.get(
			"workplace_contract",
			{}
		)
	)

	_header(
		str(
			contract.get(
				"space_name",
				"WORKPLACE"
			)
		)
	)

	if bool(
		contract.get(
			"preview_only",
			false
		)
	):
		_banner(
			(
				"Workplace preview: its spaces and people "
				+ "are observable before employment."
			)
		)

	var zone_rows: Array = _array(
		contract.get(
			"zone_rows",
			[]
		)
	)

	if zone_rows.is_empty():
		_empty(
			"No workplace locations are observable."
		)
		return

	var zone_grid: GridContainer = _career_card_grid(
		3,
		content_root
	)

	for raw_zone in zone_rows:
		_render_workplace_zone_card(
			zone_grid,
			_dict(
				raw_zone
			)
		)
func _render_workplace_zone_card(
	parent: GridContainer,
	zone: Dictionary
) -> void:
	if (
		parent == null
		or zone.is_empty()
	):
		return

	var card: PanelContainer = _card()
	card.custom_minimum_size = Vector2(
		260,
		170
	)

	parent.add_child(
		card
	)

	var margin:= MarginContainer.new()
	margin.add_theme_constant_override(
		"margin_left",
		12
	)
	margin.add_theme_constant_override(
		"margin_top",
		11
	)
	margin.add_theme_constant_override(
		"margin_right",
		12
	)
	margin.add_theme_constant_override(
		"margin_bottom",
		11
	)
	card.add_child(
		margin
	)

	var root:= VBoxContainer.new()
	root.add_theme_constant_override(
		"separation",
		7
	)
	margin.add_child(
		root
	)

	_title(
		root,
		"%s %s" % [
			str(
				zone.get(
					"icon",
					""
				)
			),
			str(
				zone.get(
					"label",
					"Location"
				)
			)
		]
	)

	_body(
		root,
		str(
			zone.get(
				"description",
				""
			)
		)
	)

	_secondary(
		root,
		"People here: %d"
		% int(
			zone.get(
				"people_count",
				0
			)
		)
	)

	if int(
		zone.get(
			"goods_count",
			0
		)
	) > 0:
		_secondary(
			root,
			"Goods here: %d"
			% int(
				zone.get(
					"goods_count",
					0
				)
			)
		)

	var details:= VBoxContainer.new()
	details.add_theme_constant_override(
		"separation",
		8
	)
	details.visible = bool(
		zone.get(
			"current",
			false
		)
	)
	root.add_child(
		details
	)

	var access_button:= Button.new()
	access_button.text = (
		"CLOSE"
		if details.visible
		else "ACCESS"
	)
	access_button.custom_minimum_size = Vector2(
		0,
		38
	)
	access_button.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND
	)
	access_button.pressed.connect(
		func () -> void:
			details.visible = not details.visible
			access_button.text = (
				"CLOSE"
				if details.visible
				else "ACCESS"
			)
	)
	root.add_child(
		access_button
	)

	var people_rows: Array = _array(
		zone.get(
			"people_rows",
			[]
		)
	)

	if not people_rows.is_empty():
		var grouped_people: Dictionary = {}

		for raw_person in people_rows:
			var person: Dictionary = _dict(
				raw_person
			)

			var activity_key: String = str(
				person.get(
					"current_activity",
					"Working"
				)
			)

			var group: Array = _array(
				grouped_people.get(
					activity_key,
					[]
				)
			).duplicate(false)

			group.append(
				person
			)

			grouped_people [
				activity_key
			] = group

		for activity_key in grouped_people.keys():
			var activity_label:= Label.new()
			activity_label.text = str(
				activity_key
			)
			activity_label.add_theme_font_size_override(
				"font_size",
				12
			)
			details.add_child(
				activity_label
			)

			var people_grid:= GridContainer.new()
			people_grid.columns = 2
			people_grid.size_flags_horizontal = (
				Control.SIZE_EXPAND_FILL
			)
			people_grid.add_theme_constant_override(
				"h_separation",
				7
			)
			people_grid.add_theme_constant_override(
				"v_separation",
				7
			)
			details.add_child(
				people_grid
			)

			for raw_person in _array(
				grouped_people.get(
					activity_key,
					[]
				)
			):
				_render_person(
					_dict(
						raw_person
					),
					people_grid,
					true
				)

	var goods_rows: Array = _array(
		zone.get(
			"goods_rows",
			[]
		)
	)

	if not goods_rows.is_empty():
		var goods_label:= Label.new()
		goods_label.text = "GOODS"
		goods_label.add_theme_font_size_override(
			"font_size",
			12
		)
		details.add_child(
			goods_label
		)

		var goods_grid:= GridContainer.new()
		goods_grid.columns = 2
		goods_grid.size_flags_horizontal = (
			Control.SIZE_EXPAND_FILL
		)
		goods_grid.add_theme_constant_override(
			"h_separation",
			7
		)
		goods_grid.add_theme_constant_override(
			"v_separation",
			7
		)
		details.add_child(
			goods_grid
		)

		for raw_good in goods_rows:
			var good: Dictionary = _dict(
				raw_good
			)

			_render_card(
				{
					"title": str(
						good.get(
							"title",
							"Trade Good"
						)
					),
					"description": str(
						good.get(
							"description",
							""
						)
					),
					"lines": [
						"Market value: %s"
						% str(
							good.get(
								"value_text",
								"$0"
							)
						)
					]
				},
				goods_grid,
				true
			)


func _render_people() -> void:
	var people: Dictionary = _dict(
		active_contract.get(
			"people_contract",
			{}
		)
	)

	_header(
		"PROFESSIONAL NETWORK"
	)

	var manager_rows: Array = _array(
		people.get(
			"manager_rows",
			[]
		)
	)

	if manager_rows.is_empty():
		var manager: Dictionary = _dict(
			people.get(
				"manager",
				{}
			)
		)

		if not manager.is_empty():
			manager_rows.append(
				manager
			)

	if not manager_rows.is_empty():
		_banner(
			"BOSSES"
		)

		var boss_grid: GridContainer = _career_card_grid(
			3,
			content_root
		)

		for raw_manager in manager_rows:
			_render_person(
				_dict(
					raw_manager
				),
				boss_grid,
				true
			)

	var rows: Array = _array(
		people.get(
			"coworker_rows",
			[]
		)
	)

	_banner(
		"COWORKERS"
	)

	if rows.is_empty():
		_empty(
			"No coworkers in this profession are observable."
		)

	else:
		var coworker_grid: GridContainer = _career_card_grid(
			3,
			content_root
		)

		for raw_row in rows:
			_render_person(
				_dict(
					raw_row
				),
				coworker_grid,
				true
			)

	var total: int = int(
		people.get(
			"total_coworkers",
			rows.size() + manager_rows.size()
		)
	)

	if total > (
		rows.size() + manager_rows.size()
	):
		var pagination_grid: GridContainer = _career_card_grid(
			3,
			content_root
		)

		_action(
			pagination_grid,
			{
				"action_id": "set_coworker_shard",
				"label": "LOAD NEXT COWORKER SHARD",
				"offset": (
					rows.size()
					+ manager_rows.size()
				),
				"section_id": "people",
				"enabled": true
			}
		)


func _render_workflow() -> void:
	var workflow: Dictionary = _dict(
		active_contract.get(
			"workflow_contract",
			{}
		)
	)

	var profession: Dictionary = _dict(
		workflow.get(
			"profession_lens",
			{}
		)
	)

	_header(
		"DUTIES"
	)

	_render_card(
		{
			"title": "%s %s" % [
				str(
					profession.get(
						"icon",
						""
					)
				),
				str(
					profession.get(
						"title",
						"Current Profession"
					)
				)
			],
			"description": str(
				profession.get(
					"description",
					""
				)
			),
			"lines": [
				"Primary responsibility: %s"
				% str(
					profession.get(
						"primary_task",
						"Professional work"
					)
				)
			]
		},
		content_root,
		true
	)

	_banner(
		"ROLE-SPECIFIC ACTIONS"
	)

	var activity_grid: GridContainer = _career_card_grid(
		3,
		content_root
	)

	for raw_activity in _array(
		workflow.get(
			"activity_rows",
			[]
		)
	):
		var activity: Dictionary = _dict(
			raw_activity
		)

		_render_card(
			{
				"title": str(
					activity.get(
						"label",
						"Professional Activity"
					)
				),
				"description": str(
					activity.get(
						"description",
						""
					)
				),
				"lines": _array(
					activity.get(
						"impact_lines",
						[]
					)
				),
				"actions": [
					{
						"action_id": "perform_activity",
						"activity_id": str(
							activity.get(
								"activity_id",
								""
							)
						),
						"label": str(
							activity.get(
								"action_label",
								"PERFORM"
							)
						),
						"section_id": "workflow",
						"enabled": bool(
							activity.get(
								"enabled",
								true
							)
						)
					}
				]
			},
			activity_grid,
			true
		)

	var scenario_actions: Array = _array(
		workflow.get(
			"scenario_actions",
			[]
		)
	)

	if not scenario_actions.is_empty():
		_banner(
			"LIVE WORKPLACE MOMENTS"
		)

		var scenario_grid: GridContainer = _career_card_grid(
			3,
			content_root
		)

		for raw_action in scenario_actions:
			_action(
				scenario_grid,
				_dict(
					raw_action
				)
			)
func _render_organization() -> void:
	var contract: Dictionary = _dict(
		active_contract.get(
			"organization_contract",
			{}
		)
	)

	var organization: Dictionary = _dict(
		contract.get(
			"organization",
			{}
		)
	)

	_header(
		str(
			organization.get(
				"name",
				"ORGANIZATION"
			)
		)
	)

	var overview_grid: GridContainer = _career_card_grid(
		3,
		content_root
	)

	_render_card(
		{
			"title": "Institution State",
			"lines": [
				"Type: %s"
				% str(
					organization.get(
						"organization_type",
						"institution"
					)
				).capitalize(),
				"Stability: %d"
				% int(
					organization.get(
						"stability",
						0
					)
				),
				"Prestige: %d"
				% int(
					organization.get(
						"prestige",
						0
					)
				),
				"Vacancy rate: %d%%"
				% int(
					round(
						float(
							organization.get(
								"vacancy_rate",
								0.0
							)
						) * 100.0
					)
				)
			]
		},
		overview_grid,
		true
	)

	var hierarchy_rows: Array = _array(
		contract.get(
			"hierarchy_rows",
			[]
		)
	)

	if not hierarchy_rows.is_empty():
		_banner(
			"HIERARCHY"
		)

		var hierarchy_grid: GridContainer = _career_card_grid(
			3,
			content_root
		)

		for raw_row in hierarchy_rows:
			var row: Dictionary = _dict(
				raw_row
			)

			_render_card(
				{
					"title": str(
						row.get(
							"label",
							"Hierarchy"
						)
					),
					"lines": [
						"Level: %d"
						% int(
							row.get(
								"depth",
								0
							)
						),
						"Type: %s"
						% str(
							row.get(
								"kind",
								"position"
							)
						).replace(
							"_",
							" "
						).capitalize()
					]
				},
				hierarchy_grid,
				true
			)

	_banner(
		"DEPARTMENTS"
	)

	var department_grid: GridContainer = _career_card_grid(
		3,
		content_root
	)

	for raw_row in _array(
		contract.get(
			"department_rows",
			[]
		)
	):
		_render_card(
			_dict(
				raw_row
			),
			department_grid,
			true
		)

	_banner(
		"PAYROLL"
	)

	var payroll: Dictionary = _dict(
		contract.get(
			"payroll",
			{}
		)
	)

	var payroll_grid: GridContainer = _career_card_grid(
		3,
		content_root
	)

	_render_card(
		{
			"title": str(
				payroll.get(
					"pay_cycle",
					"Payroll"
				)
			),
			"lines": [
				"Annual: %s"
				% str(
					payroll.get(
						"annual_text",
						"Unresolved"
					)
				),
				"Monthly: %s"
				% str(
					payroll.get(
						"monthly_text",
						"Unresolved"
					)
				),
				"Estimated net: %s"
				% str(
					payroll.get(
						"estimated_net_text",
						"Unresolved"
					)
				),
				"Estimated tax: %d%%"
				% int(
					round(
						float(
							payroll.get(
								"tax_rate",
								0.0
							)
						) * 100.0
					)
				)
			]
		},
		payroll_grid,
		true
	)

	_banner(
		"BENEFITS"
	)

	var benefit_grid: GridContainer = _career_card_grid(
		3,
		content_root
	)

	for raw_row in _array(
		contract.get(
			"benefit_rows",
			[]
		)
	):
		_render_card(
			_dict(
				raw_row
			),
			benefit_grid,
			true
		)


func _render_opportunities() -> void:
	var active_catalog: Dictionary = _dict(
		active_contract.get(
			"opportunity_contract",
			{}
		)
	)

	var catalog_by_lane: Dictionary = _dict(
		active_contract.get(
			"opportunity_contract_by_lane",
			{}
		)
	)

	if catalog_by_lane.is_empty():
		catalog_by_lane = {
			active_lane: active_catalog
		}

	_header(
		"OCCUPATIONS"
	)

	var controls:= HBoxContainer.new()
	controls.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	controls.add_theme_constant_override(
		"separation",
		8
	)
	content_root.add_child(
		controls
	)

	career_opportunity_lane_button_by_id.clear()
	career_opportunity_lane_root_by_id.clear()

	for lane_id in [
		"full_time",
		"part_time"
	]:
		var lane_button:= Button.new()
		lane_button.text = (
			"FULL-TIME"
			if lane_id == "full_time"
			else "PART-TIME"
		)
		lane_button.toggle_mode = true
		lane_button.button_pressed = (
			lane_id == active_lane
		)
		lane_button.custom_minimum_size = Vector2(
			118,
			36
		)
		lane_button.pressed.connect(
			_on_career_opportunity_lane_selected.bind(
				lane_id
			)
		)
		controls.add_child(
			lane_button
		)

		career_opportunity_lane_button_by_id [
			lane_id
		] = lane_button

	var spacer:= Control.new()
	spacer.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	controls.add_child(
		spacer
	)

	var search:= LineEdit.new()
	search.placeholder_text = "Search occupations…"
	search.text = career_opportunity_search_query
	search.custom_minimum_size = Vector2(
		230,
		36
	)
	search.clear_button_enabled = true
	search.text_changed.connect(
		_on_career_opportunity_search_changed
	)
	controls.add_child(
		search
	)

	var lane_deck:= VBoxContainer.new()
	lane_deck.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	lane_deck.add_theme_constant_override(
		"separation",
		10
	)
	content_root.add_child(
		lane_deck
	)

	career_opportunity_stream_generation += 1

	var generation: int = (
		career_opportunity_stream_generation
	)

	career_opportunity_stream_root = content_root
	career_opportunity_stream_rows.clear()
	career_opportunity_stream_cursor = 0
	career_opportunity_stream_grid_by_group.clear()

	for lane_id in [
		"full_time",
		"part_time"
	]:
		var lane_root:= VBoxContainer.new()
		lane_root.name = (
			"CareerOpportunityLane_%s"
			% lane_id
		)
		lane_root.size_flags_horizontal = (
			Control.SIZE_EXPAND_FILL
		)
		lane_root.add_theme_constant_override(
			"separation",
			10
		)
		lane_root.visible = (
			lane_id == active_lane
		)
		lane_root.mouse_filter = (
			Control.MOUSE_FILTER_PASS
			if lane_root.visible
			else Control.MOUSE_FILTER_IGNORE
		)
		lane_deck.add_child(
			lane_root
		)

		career_opportunity_lane_root_by_id [
			lane_id
		] = lane_root

		var lane_catalog: Dictionary = _dict(
			catalog_by_lane.get(
				lane_id,
				{}
			)
		)

		var status_text: String = str(
			lane_catalog.get(
				"status_text",
				""
			)
		)

		if status_text != "":
			var lane_status:= Label.new()
			lane_status.text = status_text
			lane_status.autowrap_mode = (
				TextServer.AUTOWRAP_WORD_SMART
			)
			lane_status.add_theme_font_size_override(
				"font_size",
				12
			)
			lane_root.add_child(
				lane_status
			)

		for raw_row in _array(
			lane_catalog.get(
				"career_rows",
				[]
			)
		):
			var row: Dictionary = _dict(
				raw_row
			).duplicate(false)

			row [
				"_resident_career_lane"
			] = lane_id

			career_opportunity_stream_rows.append(
				row
			)

	career_opportunity_stream_active = (
		not career_opportunity_stream_rows.is_empty()
	)

	career_opportunity_stream_status_label = Label.new()
	career_opportunity_stream_status_label.text = (
		"Publishing resident occupation cards…"
	)
	career_opportunity_stream_status_label.add_theme_font_size_override(
		"font_size",
		13
	)
	career_opportunity_stream_status_label.add_theme_color_override(
		"font_color",
		_presentation_color(
			"secondary",
			Color(
				0.74,
				0.82,
				0.96,
				1.0
			)
		)
	)
	content_root.add_child(
		career_opportunity_stream_status_label
	)

	if career_opportunity_stream_active:
		_schedule_career_opportunity_stream_quantum(
			generation
		)

	else:
		career_opportunity_stream_status_label.text = (
			"No occupations are published for this era."
		)

func _schedule_career_opportunity_stream_quantum(
	generation: int
) -> void:
	if (
		not career_opportunity_stream_active
		or generation
		!= career_opportunity_stream_generation
	):
		return

	var tree:= get_tree()

	if tree == null:
		call_deferred(
			"_service_career_opportunity_stream_quantum",
			generation
		)
		return

	var timer:= tree.create_timer(
		0.032
	)
	timer.timeout.connect(
		Callable(
			self,
			"_service_career_opportunity_stream_quantum"
		).bind(
			generation
		),
		CONNECT_ONE_SHOT
	)


func _service_career_opportunity_stream_quantum(
	generation: int
) -> void:
	if (
		not career_opportunity_stream_active
		or generation
		!= career_opportunity_stream_generation
	):
		return

	if (
		career_opportunity_stream_root == null
		or not is_instance_valid(
			career_opportunity_stream_root
		)
	):
		career_opportunity_stream_active = false
		return

	if (
		career_opportunity_stream_cursor
		>= career_opportunity_stream_rows.size()
	):
		career_opportunity_stream_active = false

		if (
			career_opportunity_stream_status_label != null
			and is_instance_valid(
				career_opportunity_stream_status_label
			)
		):
			career_opportunity_stream_status_label.text = (
				"%d career paths published."
				% career_opportunity_stream_rows.size()
			)

		return

	var row_raw: Variant = (
		career_opportunity_stream_rows [
			career_opportunity_stream_cursor
		]
	)
	career_opportunity_stream_cursor += 1

	if typeof(row_raw) == TYPE_DICTIONARY:
		var row: Dictionary = (
			row_raw as Dictionary
		)
		var grid: GridContainer = (
			_career_opportunity_group_grid(
				row
			)
		)

		if grid != null:
			_render_career_opportunity_card(
				grid,
				row
			)



			_precompose_career_explore_surface(
				row
			)

	if (
		career_opportunity_stream_status_label != null
		and is_instance_valid(
			career_opportunity_stream_status_label
		)
	):
		career_opportunity_stream_status_label.text = (
			"Published %d / %d career paths"
			% [
				career_opportunity_stream_cursor,
				career_opportunity_stream_rows.size()
			]
		)

	_schedule_career_opportunity_stream_quantum(
		generation
	)


func _career_opportunity_group_grid(
	row: Dictionary
) -> GridContainer:
	var lane_id: String = str(
		row.get(
			"_resident_career_lane",
			active_lane
		)
	).strip_edges().to_lower()

	var group_key: String = str(
		row.get(
			"social_class_group",
			""
		)
	).strip_edges()

	if group_key == "":
		group_key = "ALL CAREERS"

	var resident_grid_key: String = (
		"%s::%s"
		% [
			lane_id,
			group_key
		]
	)

	if career_opportunity_stream_grid_by_group.has(
		resident_grid_key
	):
		return (
			career_opportunity_stream_grid_by_group.get(
				resident_grid_key,
				null
			) as GridContainer
		)

	var lane_root:= (
		career_opportunity_lane_root_by_id.get(
			lane_id,
			null
		) as VBoxContainer
	)

	if (
		lane_root == null
		or not is_instance_valid(
			lane_root
		)
	):
		return null

	if group_key != "ALL CAREERS":
		var group_label:= Label.new()
		group_label.text = group_key
		group_label.add_theme_font_size_override(
			"font_size",
			17
		)
		group_label.add_theme_color_override(
			"font_color",
			_presentation_color(
				"accent",
				Color(
					1.0,
					0.78,
					0.34,
					1.0
				)
			)
		)
		lane_root.add_child(
			group_label
		)

	var grid:= GridContainer.new()
	grid.columns = 3
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

	lane_root.add_child(
		grid
	)

	career_opportunity_stream_grid_by_group [
		resident_grid_key
	] = grid

	return grid
func _on_career_opportunity_lane_selected(
	lane_id: String
) -> void:
	var clean_lane: String = str(
		lane_id
	).strip_edges().to_lower()

	if clean_lane not in [
		"full_time",
		"part_time"
	]:
		return

	active_lane = clean_lane

	for raw_lane_id in career_opportunity_lane_root_by_id.keys():
		var resident_lane_id: String = str(
			raw_lane_id
		)

		var lane_root:= (
			career_opportunity_lane_root_by_id.get(
				resident_lane_id,
				null
			) as VBoxContainer
		)

		if (
			lane_root != null
			and is_instance_valid(
				lane_root
			)
		):
			var selected: bool = (
				resident_lane_id == clean_lane
			)

			lane_root.visible = selected
			lane_root.mouse_filter = (
				Control.MOUSE_FILTER_PASS
				if selected
				else Control.MOUSE_FILTER_IGNORE
			)

		var lane_button:= (
			career_opportunity_lane_button_by_id.get(
				resident_lane_id,
				null
			) as Button
		)

		if (
			lane_button != null
			and is_instance_valid(
				lane_button
			)
		):
			lane_button.button_pressed = (
				resident_lane_id == clean_lane
			)

	_apply_career_opportunity_search_filter()


	_emit_intent({
		"action_id": "set_section",
		"section_id": "opportunities",
		"lane": clean_lane,
		"lens_persistence_only": true,
	})
func _on_career_opportunity_search_changed(
	query: String
) -> void:
	career_opportunity_search_query = str(
		query
	).strip_edges().to_lower()

	_apply_career_opportunity_search_filter()
func _apply_career_opportunity_search_filter() -> void:
	var query: String = (
		career_opportunity_search_query
	)

	for raw_grid in career_opportunity_stream_grid_by_group.values():
		var grid:= raw_grid as GridContainer

		if (
			grid == null
			or not is_instance_valid(
				grid
			)
		):
			continue

		for raw_child in grid.get_children():
			var card:= raw_child as Control

			if card == null:
				continue

			var search_text: String = str(
				card.get_meta(
					"career_opportunity_search_text",
					""
				)
			).to_lower()

			card.visible = (
				query == ""
				or search_text.contains(
					query
				)
			)
func _render_career_opportunity_card(
	grid: GridContainer,
	row: Dictionary
) -> void:
	if grid == null:
		return

	var eligible: bool = bool(
		row.get(
			"qualification_eligible",
			false
		)
	)

	var card:= PanelContainer.new()
	card.custom_minimum_size = Vector2(
		270,
		260
	)

	card.set_meta(
		"career_opportunity_search_text",
		(
			"%s %s %s %s %s"
			% [
				str(
					row.get(
						"title",
						""
					)
				),
				str(
					row.get(
						"organization_name",
						""
					)
				),
				str(
					row.get(
						"department_name",
						""
					)
				),
				str(
					row.get(
						"entry_rank_title",
						""
					)
				),
				" ".join(
					_array(
						row.get(
							"rank_titles",
							[]
						)
					)
				)
			]
		).to_lower()
	)

	card.set_meta(
		"career_opportunity_lane",
		str(
			row.get(
				"_resident_career_lane",
				active_lane
			)
		)
	)
	card.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	card.add_theme_stylebox_override(
		"panel",
		_career_job_card_style(
			eligible
		)
	)
	grid.add_child(
		card
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
	card.add_child(
		margin
	)

	var root:= VBoxContainer.new()
	root.add_theme_constant_override(
		"separation",
		7
	)
	margin.add_child(
		root
	)

	var eligibility_label:= Label.new()
	eligibility_label.text = str(
		row.get(
			"eligibility_label",
			(
				"YOU'RE ELIGIBLE FOR THIS JOB!"
				if eligible
				else "YOU'RE NOT ELIGIBLE FOR THIS JOB"
			)
		)
	)
	eligibility_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	eligibility_label.add_theme_font_size_override(
		"font_size",
		13
	)
	eligibility_label.add_theme_color_override(
		"font_color",
		_presentation_color(
			(
				"eligible"
				if eligible
				else "ineligible"
			),
			(
				Color(
					0.2,
					0.86,
					0.42,
					1.0
				)
				if eligible
				else Color(
					0.96,
					0.28,
					0.28,
					1.0
				)
			)
		)
	)
	root.add_child(
		eligibility_label
	)

	var title:= Label.new()
	title.text = str(
		row.get(
			"title",
			"Career"
		)
	)
	title.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	title.add_theme_font_size_override(
		"font_size",
		19
	)
	title.add_theme_color_override(
		"font_color",
		Color(
			0.96,
			0.97,
			1.0,
			1.0
		)
	)
	root.add_child(
		title
	)

	var pay_label:= Label.new()
	pay_label.text = str(
		row.get(
			"pay_text",
			"0"
		)
	)
	pay_label.add_theme_font_size_override(
		"font_size",
		25
	)
	pay_label.add_theme_color_override(
		"font_color",
		_presentation_color(
			"accent",
			Color(
				1.0,
				0.78,
				0.34,
				1.0
			)
		)
	)
	root.add_child(
		pay_label
	)

	_animate_career_pay_label(
		pay_label,
		maxi(
			0,
			int(
				row.get(
					"pay_amount",
					row.get(
						"salary",
						0
					)
				)
			)
		),
		_dict(
			row.get(
				"currency_contract",
				{}
			)
		),
		str(
			row.get(
				"pay_text",
				""
			)
		)
	)

	var institution:= Label.new()
	institution.text = "%s • %s" % [
		str(
			row.get(
				"organization_name",
				"Institution"
			)
		),
		str(
			row.get(
				"department_name",
				"General"
			)
		)
	]
	institution.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	institution.add_theme_font_size_override(
		"font_size",
		12
	)
	institution.add_theme_color_override(
		"font_color",
		_presentation_color(
			"secondary",
			Color(
				0.74,
				0.82,
				0.96,
				1.0
			)
		)
	)
	root.add_child(
		institution
	)

	var description:= Label.new()
	description.text = str(
		row.get(
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
	root.add_child(
		description
	)

	var entry_label:= Label.new()
	entry_label.text = "Entry rank: %s • Vacancy: %s" % [
		str(
			row.get(
				"entry_rank_title",
				"Entry Position"
			)
		),
		(
			"Open"
			if bool(
				row.get(
					"has_vacancy",
					false
				)
			)
			else "None"
		)
	]
	entry_label.add_theme_font_size_override(
		"font_size",
		12
	)
	root.add_child(
		entry_label
	)

	for raw_line in _array(
		row.get(
			"requirement_lines",
			[]
		)
	):
		var requirement:= Label.new()
		requirement.text = "• %s" % str(
			raw_line
		)
		requirement.autowrap_mode = (
			TextServer.AUTOWRAP_WORD_SMART
		)
		requirement.add_theme_font_size_override(
			"font_size",
			11
		)
		requirement.add_theme_color_override(
			"font_color",
			(
				Color(
					0.73,
					0.78,
					0.86,
					1.0
				)
				if eligible
				else _presentation_color(
					"ineligible",
					Color(
						0.96,
						0.28,
						0.28,
						1.0
					)
				)
			)
		)
		root.add_child(
			requirement
		)

	var status:= Label.new()
	status.text = str(
		row.get(
			"application_status",
			""
		)
	)
	status.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	status.add_theme_font_size_override(
		"font_size",
		11
	)
	root.add_child(
		status
	)

	var action_row:= HBoxContainer.new()
	action_row.add_theme_constant_override(
		"separation",
		8
	)
	root.add_child(
		action_row
	)

	_action(
		action_row,
		{
			"action_id": "preview_career_path",
			"path_id": str(
				row.get(
					"path_id",
					""
				)
			),
			"lane": str(
				row.get(
					"lane",
					active_lane
				)
			),
			"section_id": "opportunities",
			"label": "EXPLORE",
			"enabled": true
		}
	)

	_action(
		action_row,
		{
			"action_id": "apply_position",
			"position_id": str(
				row.get(
					"position_id",
					""
				)
			),
			"path_id": str(
				row.get(
					"path_id",
					""
				)
			),
			"lane": str(
				row.get(
					"lane",
					active_lane
				)
			),
			"section_id": "opportunities",
			"label": "APPLY",
			"enabled": bool(
				row.get(
					"can_apply",
					false
				)
			),
			"disabled_reason": str(
				row.get(
					"application_status",
					""
				)
			)
		}
	)
	var search_text: String = str(
		card.get_meta(
			"career_opportunity_search_text",
			""
		)
	)

	card.visible = (
		career_opportunity_search_query == ""
		or search_text.contains(
			career_opportunity_search_query
		)
	)

func _animate_career_pay_label(
	label: Label,
	target_amount: int,
	currency_contract: Dictionary = {},
	authoritative_pay_text: String = ""
) -> void:
	if (
		label == null
		or not is_instance_valid(
			label
		)
	):
		return

	var symbol: String = str(
		currency_contract.get(
			"symbol",
			""
		)
	)
	var currency_name: String = str(
		currency_contract.get(
			"name",
			""
		)
	).strip_edges()

	if target_amount <= 0:
		label.text = (
			authoritative_pay_text
			if authoritative_pay_text != ""
			else (
				"%s0 %s"
				% [
					symbol,
					currency_name
				]
			).strip_edges()
		)
		return




	var label_instance_id: int = int(
		label.get_instance_id()
	)
	var tween:= create_tween()


	tween.bind_node(
		label
	)

	tween.tween_method(
		Callable(
			self,
			"_career_pay_tween_value_step"
		).bind(
			label_instance_id,
			symbol,
			currency_name
		),
		0.0,
		float(
			target_amount
		),
		0.24
	)

	tween.set_trans(
		Tween.TRANS_CUBIC
	)
	tween.set_ease(
		Tween.EASE_OUT
	)

	if authoritative_pay_text != "":
		tween.finished.connect(
			Callable(
				self,
				"_career_pay_tween_finished"
			).bind(
				label_instance_id,
				authoritative_pay_text
			),
			CONNECT_ONE_SHOT
		)
func _career_pay_tween_value_step(
	value: float,
	label_instance_id: int,
	symbol: String,
	currency_name: String
) -> void:
	var resolved_object: Object = instance_from_id(
		label_instance_id
	)
	var label:= resolved_object as Label

	if (
		label == null
		or not is_instance_valid(
			label
		)
	):
		return

	label.text = (
		"%s%s %s"
		% [
			symbol,
			_career_pay_integer_text(
				int(
					round(value)
				)
			),
			currency_name
		]
	).strip_edges()
func _career_pay_tween_finished(
	label_instance_id: int,
	authoritative_pay_text: String
) -> void:
	if authoritative_pay_text == "":
		return

	var resolved_object: Object = instance_from_id(
		label_instance_id
	)
	var label:= resolved_object as Label

	if (
		label == null
		or not is_instance_valid(
			label
		)
	):
		return

	label.text = authoritative_pay_text
func _career_pay_integer_text(
	value: int
) -> String:
	var negative: bool = value < 0
	var digits: String = str(
		absi(
			value
		)
	)
	var out: String = ""

	while digits.length() > 3:
		out = (
			","
			+ digits.right(
				3
			)
			+ out
		)
		digits = digits.left(
			digits.length() - 3
		)

	out = digits + out

	if negative:
		out = "-" + out

	return out


func _career_job_card_style(
	eligible: bool
) -> StyleBoxFlat:
	var style:= _career_hub_panel_style(
		"card"
	)

	style.border_color = (
		_presentation_color(
			"eligible",
			Color(
				0.2,
				0.86,
				0.42,
				1.0
			)
		)
		if eligible
		else _presentation_color(
			"ineligible",
			Color(
				0.96,
				0.28,
				0.28,
				1.0
			)
		)
	)

	style.set_border_width_all(
		2
	)
	style.shadow_color = Color(
		style.border_color.r,
		style.border_color.g,
		style.border_color.b,
		0.18
	)
	style.shadow_size = 10

	return style
func _presentation_color(
	key: String,
	fallback: Color
) -> Color:
	var presentation: Dictionary = _dict(
		active_contract.get(
			"presentation_contract",
			{}
		)
	)
	var colors: Dictionary = _dict(
		presentation.get(
			"colors",
			{}
		)
	)

	var raw_value: Variant = colors.get(
		key,
		fallback
	)

	if typeof(raw_value) == TYPE_COLOR:
		return raw_value

	return fallback


func _apply_presentation_theme() -> void:
	add_theme_stylebox_override(
		"panel",
		_career_hub_panel_style(
			"shell"
		)
	)

	if (
		identity_card != null
		and is_instance_valid(
			identity_card
		)
	):
		identity_card.add_theme_stylebox_override(
			"panel",
			_career_hub_panel_style(
				"identity"
			)
		)

	for raw_button in section_buttons.values():
		var button:= raw_button as Button

		if (
			button == null
			or not is_instance_valid(
				button
			)
		):
			continue

		_apply_tab_button_style(
			button,
			button.button_pressed
		)
func _render_education() -> void:
	var contract: Dictionary = _dict(
		active_contract.get(
			"education_contract",
			{}
		)
	)

	_header(
		"EDUCATION & PROFESSIONAL CREDENTIALS"
	)

	for raw_row in _array(
		contract.get(
			"education_rows",
			[]
		)
	):
		_render_card(
			_dict(
				raw_row
			)
		)

	_banner(
		"CERTIFICATIONS & PATH REQUIREMENTS"
	)

	for raw_row in _array(
		contract.get(
			"certification_rows",
			[]
		)
	):
		_render_card(
			_dict(
				raw_row
			)
		)


func _render_reputation() -> void:
	var contract: Dictionary = _dict(
		active_contract.get(
			"reputation_contract",
			{}
		)
	)

	_header(
		"PROFESSIONAL STANDING"
	)

	var summary_grid: GridContainer = _career_card_grid(
		3,
		content_root
	)

	_render_card(
		{
			"title": "%s • %d" % [
				str(
					contract.get(
						"stars",
						"☆☆☆☆☆"
					)
				),
				int(
					contract.get(
						"score",
						0
					)
				)
			],
			"description": str(
				contract.get(
					"summary",
					""
				)
			)
		},
		summary_grid,
		true
	)

	var axis_grid: GridContainer = _career_card_grid(
		3,
		content_root
	)

	for raw_row in _array(
		contract.get(
			"axis_rows",
			[]
		)
	):
		var row: Dictionary = _dict(
			raw_row
		)

		_progress(
			str(
				row.get(
					"label",
					"Metric"
				)
			),
			str(
				row.get(
					"description",
					"Professional standing."
				)
			),
			float(
				row.get(
					"value",
					0.0
				)
			),
			float(
				row.get(
					"max_value",
					100.0
				)
			),
			axis_grid
		)

	_banner(
		"REPUTATION REACH"
	)

	var reach_grid: GridContainer = _career_card_grid(
		3,
		content_root
	)

	for raw_row in _array(
		contract.get(
			"reach_rows",
			[]
		)
	):
		var row: Dictionary = _dict(
			raw_row
		)

		_render_card(
			{
				"title": str(
					row.get(
						"label",
						"Reach"
					)
				),
				"lines": [
					str(
						row.get(
							"stars",
							"☆☆☆☆☆"
						)
					),
					"Recognition: %d"
					% int(
						row.get(
							"value",
							0
						)
					)
				]
			},
			reach_grid,
			true
		)


func _render_promotion() -> void:
	var contract: Dictionary = _dict(
		active_contract.get(
			"promotion_contract",
			{}
		)
	)

	_header(
		"PROMOTION LADDER"
	)

	_render_card({
		"title": str(
			contract.get(
				"current_rank_title",
				"No Current Rank"
			)
		),
		"description": str(
			contract.get(
				"summary",
				""
			)
		),
		"progress": float(
			contract.get(
				"progress",
				0.0
			)
		),
		"lines": [
			"Next rank: %s"
			% str(
				contract.get(
					"next_rank_title",
					"Top Rank"
				)
			),
			"Vacancy: %s"
			% (
				"Open"
				if bool(
					contract.get(
						"vacancy_open",
						false
					)
				)
				else "Closed"
			),
			"Performance: %d / %d"
			% [
				int(
					contract.get(
						"performance",
						0
					)
				),
				int(
					contract.get(
						"performance_required",
						0
					)
				)
			],
			"Experience: %d / %d"
			% [
				int(
					contract.get(
						"experience",
						0
					)
				),
				int(
					contract.get(
						"experience_required",
						0
					)
				)
			],
			"Reputation: %d / %d"
			% [
				int(
					contract.get(
						"reputation",
						0
					)
				),
				int(
					contract.get(
						"reputation_required",
						0
					)
				)
			]
		],
		"actions": _array(
			contract.get(
				"actions",
				[]
			)
		)
	})

	for raw_row in _array(
		contract.get(
			"ladder_rows",
			[]
		)
	):
		var row: Dictionary = _dict(
			raw_row
		)
		var marker: String = "⬇"

		if bool(
			row.get(
				"completed",
				false
			)
		):
			marker = "✅"
		elif bool(
			row.get(
				"current",
				false
			)
		):
			marker = "▶"

		_label(
			"%s %s" % [
				marker,
				str(
					row.get(
						"title",
						"Rank"
					)
				)
			],
			15,
			Color(
				0.88,
				0.92,
				1.0,
				1.0
			)
		)


func _render_timeline() -> void:
	var contract: Dictionary = _dict(
		active_contract.get(
			"timeline_contract",
			{}
		)
	)

	_header(
		"CAREER TIMELINE & LEGACY"
	)

	var timeline_rows: Array = _array(
		contract.get(
			"timeline_rows",
			[]
		)
	)

	if not timeline_rows.is_empty():
		var timeline_grid: GridContainer = _career_card_grid(
			3,
			content_root
		)

		for raw_row in timeline_rows:
			var row: Dictionary = _dict(
				raw_row
			)

			_render_card(
				{
					"title": str(
						row.get(
							"rank_title",
							row.get(
								"event",
								"Career Event"
							)
						)
					).replace(
						"_",
						" "
					).capitalize(),
					"lines": [
						"Year: %s"
						% str(
							row.get(
								"year",
								"Unknown"
							)
						),
						"Organization: %s"
						% str(
							row.get(
								"organization_name",
								row.get(
									"organization_id",
									"Institution"
								)
							)
						)
					]
				},
				timeline_grid,
				true
			)

	var award_rows: Array = _array(
		contract.get(
			"award_rows",
			[]
		)
	)

	if not award_rows.is_empty():
		_banner(
			"PROFESSIONAL AWARDS"
		)

		var award_grid: GridContainer = _career_card_grid(
			3,
			content_root
		)

		for raw_row in award_rows:
			_render_card(
				_dict(
					raw_row
				),
				award_grid,
				true
			)

	var legacy_rows: Array = _array(
		contract.get(
			"legacy_rows",
			[]
		)
	)

	if not legacy_rows.is_empty():
		_banner(
			"LEGACY"
		)

		var legacy_grid: GridContainer = _career_card_grid(
			3,
			content_root
		)

		for raw_row in legacy_rows:
			_render_card(
				_dict(
					raw_row
				),
				legacy_grid,
				true
			)

	var retirement: Dictionary = _dict(
		contract.get(
			"retirement",
			{}
		)
	)

	var retirement_grid: GridContainer = _career_card_grid(
		3,
		content_root
	)

	_render_card(
		{
			"title": "Retirement",
			"description": str(
				retirement.get(
					"summary",
					""
				)
			),
			"lines": [
				"Retirement age: %d"
				% int(
					retirement.get(
						"retirement_age",
						0
					)
				),
				"Years remaining: %d"
				% int(
					retirement.get(
						"years_remaining",
						0
					)
				)
			],
			"actions": [
				{
					"action_id": "retire",
					"label": "RETIRE",
					"section_id": "timeline",
					"enabled": bool(
						retirement.get(
							"eligible",
							false
						)
					)
				}
			]
		},
		retirement_grid,
		true
	)

func _render_person(
	row: Dictionary,
	parent: Control = null,
	compact: bool = false
) -> void:
	if row.is_empty():
		return

	var target_parent: Control = (
		parent
		if parent != null
		else content_root
	)

	var mood: Dictionary = _dict(
		row.get(
			"mood",
			{}
		)
	)

	var actions: Array = _array(
		row.get(
			"actions",
			[]
		)
	)

	var card: PanelContainer = _card()
	card.custom_minimum_size = Vector2(
		220 if compact else 0,
		150 if compact else 180
	)

	target_parent.add_child(
		card
	)

	var margin:= MarginContainer.new()
	margin.add_theme_constant_override(
		"margin_left",
		10
	)
	margin.add_theme_constant_override(
		"margin_top",
		9
	)
	margin.add_theme_constant_override(
		"margin_right",
		10
	)
	margin.add_theme_constant_override(
		"margin_bottom",
		9
	)
	card.add_child(
		margin
	)

	var box:= VBoxContainer.new()
	box.add_theme_constant_override(
		"separation",
		5
	)
	margin.add_child(
		box
	)

	_title(
		box,
		"%s — %s" % [
			str(
				row.get(
					"name",
					"Coworker"
				)
			),
			str(
				row.get(
					"role",
					"Professional"
				)
			)
		]
	)

	_body(
		box,
		"%s %s • %s" % [
			str(
				mood.get(
					"emoji",
					""
				)
			),
			str(
				mood.get(
					"label",
					"Neutral"
				)
			),
			str(
				row.get(
					"rating",
					"☆☆☆☆☆"
				)
			)
		]
	)

	if str(
		row.get(
			"tier_label",
			""
		)
	) != "":
		_secondary(
			box,
			"Tier: %s"
			% str(
				row.get(
					"tier_label",
					"Coworker"
				)
			)
		)

	_secondary(
		box,
		"Years here: %d"
		% int(
			row.get(
				"years_here",
				0
			)
		)
	)

	_secondary(
		box,
		"Current activity: %s"
		% str(
			row.get(
				"current_activity",
				"Working"
			)
		)
	)

	_secondary(
		box,
		"Bond: %d%%"
		% int(
			row.get(
				"bond",
				0
			)
		)
	)

	for raw_action in actions:
		var action: Dictionary = _dict(
			raw_action
		)

		if str(
			action.get(
				"action_id",
				""
			)
		) == "open_coworker_profile":
			var button:= Button.new()
			button.text = str(
				action.get(
					"label",
					"OPEN FULL PROFILE"
				)
			)
			button.disabled = not bool(
				action.get(
					"enabled",
					true
				)
			)
			button.pressed.connect(
				_emit_profile.bind(
					int(
						action.get(
							"target_id",
							-1
						)
					),
					row
				)
			)
			box.add_child(
				button
			)

		else:
			_action(
				box,
				action
			)
func _career_card_grid(
	columns: int = 3,
	parent: Control = null
) -> GridContainer:
	var target_parent: Control = (
		parent
		if parent != null
		else content_root
	)

	var grid:= GridContainer.new()
	grid.columns = clampi(
		columns,
		1,
		5
	)
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

	target_parent.add_child(
		grid
	)

	return grid

func _render_card(
	row: Dictionary,
	parent: Control = null,
	compact: bool = false
) -> void:
	if row.is_empty():
		return

	var target_parent: Control = (
		parent
		if parent != null
		else content_root
	)

	var card: PanelContainer = _card()
	card.custom_minimum_size = Vector2(
		220 if compact else 0,
		132 if compact else 170
	)

	target_parent.add_child(
		card
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
		6 if compact else 7
	)
	margin.add_child(
		box
	)

	_title(
		box,
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

	_body(
		box,
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

	for raw_metric in _array(
		row.get(
			"metrics",
			[]
		)
	):
		var metric: Dictionary = _dict(
			raw_metric
		)

		_secondary(
			box,
			"%s: %s" % [
				str(
					metric.get(
						"label",
						"Metric"
					)
				),
				str(
					metric.get(
						"value",
						""
					)
				)
			]
		)

	for raw_line in _array(
		row.get(
			"lines",
			[]
		)
	):
		_secondary(
			box,
			str(
				raw_line
			)
		)

	if row.has(
		"progress"
	):
		_bar(
			box,
			float(
				row.get(
					"progress",
					0.0
				)
			) * 100.0,
			100.0
		)

	for raw_action in _array(
		row.get(
			"actions",
			[]
		)
	):
		_action(
			box,
			_dict(
				raw_action
			)
		)

func _progress(
	label: String,
	description: String,
	value: float,
	maximum: float,
	parent: Control = null
) -> void:
	var target_parent: Control = (
		parent
		if parent != null
		else content_root
	)

	var card: PanelContainer = _card()
	card.custom_minimum_size = Vector2(
		240,
		120
	)

	target_parent.add_child(
		card
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
		8
	)
	margin.add_child(
		box
	)

	_title(
		box,
		"%s: %s" % [
			label,
			description
		]
	)

	_bar(
		box,
		value,
		maximum
	)

func _bar(
	parent: VBoxContainer,
	value: float,
	maximum: float
) -> void:
	var bar:= ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = maxf(
		1.0,
		maximum
	)
	bar.value = clampf(
		value,
		0.0,
		bar.max_value
	)
	bar.show_percentage = true
	bar.custom_minimum_size = Vector2(
		0,
		24
	)

	var background_style:= StyleBoxFlat.new()
	background_style.bg_color = Color(
		0.035,
		0.045,
		0.07,
		0.98
	)
	background_style.border_color = _presentation_color(
		"secondary",
		Color(
			0.3,
			0.42,
			0.62,
			0.9
		)
	)
	background_style.border_width_left = 1
	background_style.border_width_top = 1
	background_style.border_width_right = 1
	background_style.border_width_bottom = 1
	background_style.corner_radius_top_left = 8
	background_style.corner_radius_top_right = 8
	background_style.corner_radius_bottom_left = 8
	background_style.corner_radius_bottom_right = 8

	var fill_style:= StyleBoxFlat.new()
	fill_style.bg_color = _presentation_color(
		"accent",
		Color(
			0.8,
			0.58,
			0.24,
			1.0
		)
	)
	fill_style.corner_radius_top_left = 8
	fill_style.corner_radius_top_right = 8
	fill_style.corner_radius_bottom_left = 8
	fill_style.corner_radius_bottom_right = 8

	bar.add_theme_stylebox_override(
		"background",
		background_style
	)
	bar.add_theme_stylebox_override(
		"fill",
		fill_style
	)
	bar.add_theme_color_override(
		"font_color",
		Color(
			1.0,
			1.0,
			1.0,
			1.0
		)
	)
	bar.add_theme_color_override(
		"font_outline_color",
		Color(
			0.0,
			0.0,
			0.0,
			0.85
		)
	)
	bar.add_theme_constant_override(
		"outline_size",
		4
	)

	parent.add_child(
		bar
	)
func _action(
	parent: Control,
	spec: Dictionary
) -> void:
	var action_id: String = str(
		spec.get(
			"action_id",
			spec.get(
				"id",
				""
			)
		)
	).strip_edges()

	if action_id == "":
		return

	var button:= Button.new()
	button.text = str(
		spec.get(
			"label",
			action_id.replace(
				"_",
				" "
			).to_upper()
		)
	)
	button.disabled = not bool(
		spec.get(
			"enabled",
			true
		)
	)
	button.tooltip_text = str(
		spec.get(
			"disabled_reason",
			spec.get(
				"description",
				""
			)
		)
	)
	button.custom_minimum_size = Vector2(
		0,
		44
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
			0.82,
			0.89,
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
		"font_pressed_color",
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
			0.56,
			0.67,
			0.72
		)
	)
	button.add_theme_stylebox_override(
		"normal",
		_career_hub_button_style(
			"normal",
			false
		)
	)
	button.add_theme_stylebox_override(
		"hover",
		_career_hub_button_style(
			"hover",
			false
		)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_career_hub_button_style(
			"pressed",
			true
		)
	)
	button.add_theme_stylebox_override(
		"focus",
		_career_hub_button_style(
			"hover",
			false
		)
	)

	var disabled_style: StyleBoxFlat = (
		_career_hub_button_style(
			"normal",
			false
		)
	)
	disabled_style.bg_color = Color(
		0.04,
		0.048,
		0.07,
		0.78
	)
	disabled_style.border_color = Color(
		0.18,
		0.23,
		0.32,
		0.58
	)
	button.add_theme_stylebox_override(
		"disabled",
		disabled_style
	)

	var payload: Dictionary = (
		spec.duplicate(true)
	)
	payload ["action_id"] = action_id
	payload ["section_id"] = str(
		payload.get(
			"section_id",
			active_section_id
		)
	)

	if action_id == "reveal_section":
		var target_section_id: String = str(
			payload.get(
				"target_section_id",
				"overview"
			)
		).strip_edges().to_lower()

		button.pressed.connect(
			_on_section.bind(
				target_section_id
			)
		)

	elif action_id == "preview_career_path":

		button.pressed.connect(
			_reveal_career_explore_surface.bind(
				str(
					payload.get(
						"path_id",
						""
					)
				)
			)
		)

	else:
		button.pressed.connect(
			_emit_intent.bind(
				payload
			)
		)

	parent.add_child(
		button
	)
func _on_section(
	section_id: String
) -> void:
	var clean_section: String = str(
		section_id
	).strip_edges().to_lower()

	if clean_section == "":
		return

	active_section_id = clean_section

	for raw_id in section_buttons.keys():
		var button: Button = (
			section_buttons.get(
				raw_id,
				null
			) as Button
		)

		if (
			button == null
			or not is_instance_valid(
				button
			)
		):
			continue

		var selected: bool = (
			str(raw_id)
			== clean_section
		)

		button.button_pressed = selected
		_apply_tab_button_style(
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


	_reveal_section_surface(
		clean_section
	)

	_emit_intent({
		"action_id": "set_section",
		"section_id": clean_section,
		"lens_persistence_only": true
	})
func _emit_intent(
	payload: Dictionary
) -> void:
	var envelope: Dictionary = payload.duplicate(true)
	envelope ["actor_id"] = active_actor_id
	envelope ["surface_id"] = "career_hub_panel"
	envelope ["ui_is_expression_only"] = true

	request_intent.emit(
		envelope
	)


func _emit_profile(
	target_id: int,
	row: Dictionary = {}
) -> void:
	if target_id <= 0:
		return

	var profile_contract: Dictionary = _dict(
		row.get(
			"relationship_profile_contract",
			{}
		)
	)

	var target_pointer: Variant = row.get(
		"target_pointer",
		null
	)

	if (
		profile_contract.is_empty()
		or int(
			profile_contract.get(
				"target_id",
				-1
			)
		) != target_id
		or str(
			profile_contract.get(
				"truth_state",
				""
			)
		) != "hot"
		or not (
			target_pointer is Person
		)
	):
		_set_status(
			(
				"That coworker's resident profile "
				+ "is still publishing."
			)
		)
		return

	request_person_profile.emit(
		target_id,
		{
			"target_id": target_id,
			"target_pointer": target_pointer,
			"relationship_profile_contract": (
				profile_contract
			),
			"return_context": "career_hub",
			"ui_is_expression_only": true
		}
	)
func _apply_tab_button_style(
	button: Button,
	selected: bool
) -> void:
	button.add_theme_stylebox_override(
		"normal",
		_career_hub_button_style(
			"normal",
			selected
		)
	)
	button.add_theme_stylebox_override(
		"hover",
		_career_hub_button_style(
			"hover",
			selected
		)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_career_hub_button_style(
			"pressed",
			true
		)
	)
	button.add_theme_stylebox_override(
		"focus",
		_career_hub_button_style(
			"hover",
			selected
		)
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
				0.76,
				0.84,
				0.96,
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
	button.add_theme_color_override(
		"font_pressed_color",
		Color(
			1.0,
			0.94,
			0.72,
			1.0
		)
	)


func _career_hub_panel_style(
	kind: String
) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	var clean_kind: String = str(
		kind
	).strip_edges().to_lower()

	var shell_bg: Color = _presentation_color(
		"shell_bg",
		Color(
			0.014,
			0.019,
			0.036,
			0.995
		)
	)
	var shell_border: Color = _presentation_color(
		"shell_border",
		Color(
			0.27,
			0.47,
			0.82,
			0.92
		)
	)
	var card_bg: Color = _presentation_color(
		"card_bg",
		Color(
			0.045,
			0.058,
			0.094,
			0.98
		)
	)
	var card_border: Color = _presentation_color(
		"card_border",
		Color(
			0.25,
			0.39,
			0.66,
			0.7
		)
	)
	var accent: Color = _presentation_color(
		"accent",
		Color(
			1.0,
			0.78,
			0.34,
			1.0
		)
	)
	var secondary: Color = _presentation_color(
		"secondary",
		Color(
			0.52,
			0.74,
			1.0,
			1.0
		)
	)

	match clean_kind:
		"shell":
			style.bg_color = shell_bg
			style.border_color = shell_border
			style.shadow_color = Color(
				shell_border.r,
				shell_border.g,
				shell_border.b,
				0.34
			)
			style.shadow_size = 24
			style.set_border_width_all(
				2
			)
			style.set_corner_radius_all(
				22
			)

		"header":
			style.bg_color = (
				shell_bg.lightened(
					0.055
				)
			)
			style.border_color = (
				secondary
			)
			style.shadow_color = Color(
				secondary.r,
				secondary.g,
				secondary.b,
				0.18
			)
			style.shadow_size = 14
			style.set_border_width_all(
				1
			)
			style.set_corner_radius_all(
				16
			)

		"identity":
			style.bg_color = (
				card_bg.lightened(
					0.025
				)
			)
			style.border_color = accent
			style.shadow_color = Color(
				accent.r,
				accent.g,
				accent.b,
				0.18
			)
			style.shadow_size = 12
			style.set_border_width_all(
				1
			)
			style.set_corner_radius_all(
				15
			)

		"brand_badge":
			style.bg_color = (
				shell_bg.lightened(
					0.09
				)
			)
			style.border_color = secondary
			style.set_border_width_all(
				1
			)
			style.set_corner_radius_all(
				16
			)

		"time_chip":
			style.bg_color = (
				shell_bg.lightened(
					0.055
				)
			)
			style.border_color = shell_border
			style.set_border_width_all(
				1
			)
			style.set_corner_radius_all(
				12
			)

		"metric_chip":
			style.bg_color = card_bg
			style.border_color = card_border
			style.set_border_width_all(
				1
			)
			style.set_corner_radius_all(
				10
			)
			style.content_margin_left = 8.0
			style.content_margin_right = 8.0
			style.content_margin_top = 6.0
			style.content_margin_bottom = 6.0

		_:
			style.bg_color = card_bg
			style.border_color = card_border
			style.shadow_color = Color(
				card_border.r,
				card_border.g,
				card_border.b,
				0.18
			)
			style.shadow_size = 8
			style.set_border_width_all(
				1
			)
			style.set_corner_radius_all(
				12
			)

	return style

func _career_hub_button_style(
	state: String,
	selected: bool
) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	var clean_state: String = str(
		state
	).strip_edges().to_lower()

	var shell_bg: Color = _presentation_color(
		"shell_bg",
		Color(
			0.014,
			0.019,
			0.036,
			0.995
		)
	)
	var shell_border: Color = _presentation_color(
		"shell_border",
		Color(
			0.27,
			0.47,
			0.82,
			0.92
		)
	)
	var accent: Color = _presentation_color(
		"accent",
		Color(
			1.0,
			0.78,
			0.34,
			1.0
		)
	)
	var secondary: Color = _presentation_color(
		"secondary",
		Color(
			0.52,
			0.74,
			1.0,
			1.0
		)
	)

	if selected:
		style.bg_color = (
			shell_bg.lightened(
				0.16
			)
		)
		style.border_color = accent
		style.shadow_color = Color(
			secondary.r,
			secondary.g,
			secondary.b,
			0.25
		)
		style.shadow_size = 10

	elif clean_state == "hover":
		style.bg_color = (
			shell_bg.lightened(
				0.11
			)
		)
		style.border_color = secondary
		style.shadow_color = Color(
			secondary.r,
			secondary.g,
			secondary.b,
			0.2
		)
		style.shadow_size = 8

	elif clean_state == "pressed":
		style.bg_color = (
			shell_bg.lightened(
				0.18
			)
		)
		style.border_color = accent
		style.shadow_size = 4

	else:
		style.bg_color = (
			shell_bg.lightened(
				0.065
			)
		)
		style.border_color = shell_border
		style.shadow_size = 0

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
func _card() -> PanelContainer:
	var card:= PanelContainer.new()
	card.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	card.add_theme_stylebox_override(
		"panel",
		_career_hub_panel_style(
			"card"
		)
	)

	return card


func _header(
	text: String
) -> void:
	_label(
		text,
		19,
		Color(
			0.94,
			0.96,
			1.0,
			1.0
		)
	)


func _banner(
	text: String
) -> void:
	_label(
		text,
		14,
		Color(
			0.74,
			0.82,
			0.96,
			1.0
		)
	)


func _label(
	text: String,
	font_size: int,
	color: Color
) -> void:
	var label:= Label.new()
	label.text = text
	label.add_theme_font_size_override(
		"font_size",
		font_size
	)
	label.modulate = color
	label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)

	content_root.add_child(
		label
	)

func _title(
	parent: VBoxContainer,
	text: String
) -> void:
	var label:= Label.new()
	label.text = text
	label.add_theme_font_size_override(
		"font_size",
		17
	)
	label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)

	parent.add_child(
		label
	)


func _body(
	parent: VBoxContainer,
	text: String
) -> void:
	if text.strip_edges() == "":
		return

	var label:= Label.new()
	label.text = text
	label.add_theme_font_size_override(
		"font_size",
		14
	)
	label.modulate = Color(
		0.82,
		0.87,
		0.95,
		1.0
	)
	label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)

	parent.add_child(
		label
	)


func _secondary(
	parent: VBoxContainer,
	text: String
) -> void:
	if text.strip_edges() == "":
		return

	var label:= Label.new()
	label.text = text
	label.add_theme_font_size_override(
		"font_size",
		13
	)
	label.modulate = Color(
		0.69,
		0.76,
		0.88,
		1.0
	)
	label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)

	parent.add_child(
		label
	)


func _empty(
	text: String
) -> void:
	_render_card({
		"title": "Observable State",
		"description": text
	})


func _set_status(
	text: String
) -> void:
	status_label.text = text.strip_edges()
	status_label.visible = (
		status_label.text != ""
	)


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


func _default_tabs() -> Array:
	return [
		{
			"id": "overview",
			"label": "OVERVIEW",
			"icon": "💼"
		},
		{
			"id": "workplace",
			"label": "WORKPLACE",
			"icon": "📍"
		},
		{
			"id": "people",
			"label": "PEOPLE",
			"icon": "👥"
		},
		{
			"id": "workflow",
			"label": "TODAY",
			"icon": "🗓️"
		},
		{
			"id": "organization",
			"label": "ORGANIZATION",
			"icon": "🏢"
		},
		{
			"id": "opportunities",
			"label": "OPPORTUNITIES",
			"icon": "🔎"
		},
		{
			"id": "education",
			"label": "EDUCATION",
			"icon": "🎓"
		},
		{
			"id": "reputation",
			"label": "REPUTATION",
			"icon": "⭐"
		},
		{
			"id": "promotion",
			"label": "PROMOTION",
			"icon": "📈"
		},
		{
			"id": "timeline",
			"label": "TIMELINE",
			"icon": "🏆"
		}
	]

func _dict(
	value
) -> Dictionary:
	return (
		value as Dictionary
		if typeof(value) == TYPE_DICTIONARY
		else {}
	)


func _array(
	value
) -> Array:
	return (
		value as Array
		if typeof(value) == TYPE_ARRAY
		else []
	)