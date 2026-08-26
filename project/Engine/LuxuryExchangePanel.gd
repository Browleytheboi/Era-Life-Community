extends PanelContainer
class_name LuxuryExchangePanel

signal close_requested
signal acquisition_requested(card_contract: Dictionary)
signal centerpiece_hover_observation_requested(
	observation_contract: Dictionary
)
signal centerpiece_hover_release_requested(
	observation_contract: Dictionary
)

const PANEL_SCHEMA:= (
	"eralife.luxury.exchange_panel"
)
const CONTRACT_VERSION:= 1
const FX_BATCH_SIZE:= 6




const SANCTORUM_SHELL_SCHEMA:= (
	"eralife.luxury.sanctorum_shell"
)
const SANCTORUM_SHELL_VERSION:= 1


class LuxurySanctorumWordLabel:
	extends Label

	var sanctorum_fx_time: float = 0.0

	func _process(
		delta: float
	) -> void:
		if not is_visible_in_tree():
			return

		sanctorum_fx_time = fposmod(
			sanctorum_fx_time + delta,
			TAU * 1024.0
		)

		var slow_breath: float = (
			0.5
			+ 0.5
			* sin(
				sanctorum_fx_time * 1.65
			)
		)
		var metallic_sheen: float = (
			0.5
			+ 0.5
			* sin(
				sanctorum_fx_time * 3.7
				+ 0.85
			)
		)
		var resolved_sheen: float = clampf(
			0.2
			+ metallic_sheen * 0.3
			+ slow_breath * 0.12,
			0.0,
			1.0
		)

		self_modulate = Color(
			lerpf(
				0.9,
				1.0,
				resolved_sheen
			),
			lerpf(
				0.82,
				1.0,
				resolved_sheen
			),
			lerpf(
				0.62,
				0.94,
				resolved_sheen
			),
			1.0
		)


var actor: Person = null
var active_contract: Dictionary = {}

var title_label: Label = null
var sanctorum_title_label: Label = null
var subtitle_label: Label = null
var status_label: Label = null
var tab_bar: HBoxContainer = null
var card_flow: Control = null

var card_controls: Array = []
var fx_entries: Array = []
var fx_cursor: int = 0
var fx_time: float = 0.0
var active_section_id: String = "featured"

var formation_pan_active: bool = false
var formation_pan_moved: bool = false
var formation_pan_hover_rearm_required: bool = false
var formation_pan_scroll_position: Vector2 = Vector2.ZERO

func _luxury_scrollbar_track_style(
	accent: Color
) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()

	style.bg_color = Color(
		accent.r * 0.08,
		accent.g * 0.08,
		accent.b * 0.1,
		0.42
	)
	style.border_color = Color(
		accent.r,
		accent.g,
		accent.b,
		0.18
	)
	style.set_border_width_all(
		1
	)
	style.set_corner_radius_all(
		999
	)

	return style


func _luxury_scrollbar_grabber_style(
	accent: Color,
	highlighted: bool = false
) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()

	style.bg_color = Color(
		accent.r,
		accent.g,
		accent.b,
		0.96 if highlighted else 0.78
	)
	style.border_color = Color(
		1.0,
		0.94,
		0.78,
		0.78 if highlighted else 0.46
	)
	style.set_border_width_all(
		1
	)
	style.set_corner_radius_all(
		999
	)
	style.shadow_color = Color(
		accent.r,
		accent.g,
		accent.b,
		0.52 if highlighted else 0.3
	)
	style.shadow_size = (
		10 if highlighted else 6
	)

	return style


func _install_luxury_formation_navigation(
	formation_scroll: ScrollContainer
) -> void:
	if (
		formation_scroll == null
		or not is_instance_valid(formation_scroll)
	):
		return

	formation_scroll.follow_focus = false
	formation_scroll.draw_focus_border = false
	formation_scroll.scroll_deadzone = 0
	formation_scroll.mouse_filter = (
		Control.MOUSE_FILTER_STOP
	)
	formation_scroll.mouse_default_cursor_shape = (
		Control.CURSOR_MOVE
	)

	var horizontal_bar: HScrollBar = (
		formation_scroll.get_h_scroll_bar()
	)
	var vertical_bar: VScrollBar = (
		formation_scroll.get_v_scroll_bar()
	)
	var inner_accent: Color = _classification_color(
		"EXCEPTIONAL"
	)
	var outer_accent: Color = _classification_color(
		"ARTIFACT"
	)

	if horizontal_bar != null:
		horizontal_bar.step = 1.0
		horizontal_bar.custom_minimum_size = Vector2(
			0,
			11
		)
		horizontal_bar.mouse_default_cursor_shape = (
			Control.CURSOR_POINTING_HAND
		)
		horizontal_bar.add_theme_stylebox_override(
			"scroll",
			_luxury_scrollbar_track_style(
				inner_accent
			)
		)
		horizontal_bar.add_theme_stylebox_override(
			"scroll_focus",
			_luxury_scrollbar_track_style(
				inner_accent
			)
		)
		horizontal_bar.add_theme_stylebox_override(
			"grabber",
			_luxury_scrollbar_grabber_style(
				inner_accent,
				false
			)
		)
		horizontal_bar.add_theme_stylebox_override(
			"grabber_highlight",
			_luxury_scrollbar_grabber_style(
				inner_accent,
				true
			)
		)
		horizontal_bar.add_theme_stylebox_override(
			"grabber_pressed",
			_luxury_scrollbar_grabber_style(
				inner_accent,
				true
			)
		)

	if vertical_bar != null:
		vertical_bar.step = 1.0
		vertical_bar.custom_minimum_size = Vector2(
			11,
			0
		)
		vertical_bar.mouse_default_cursor_shape = (
			Control.CURSOR_POINTING_HAND
		)
		vertical_bar.add_theme_stylebox_override(
			"scroll",
			_luxury_scrollbar_track_style(
				outer_accent
			)
		)
		vertical_bar.add_theme_stylebox_override(
			"scroll_focus",
			_luxury_scrollbar_track_style(
				outer_accent
			)
		)
		vertical_bar.add_theme_stylebox_override(
			"grabber",
			_luxury_scrollbar_grabber_style(
				outer_accent,
				false
			)
		)
		vertical_bar.add_theme_stylebox_override(
			"grabber_highlight",
			_luxury_scrollbar_grabber_style(
				outer_accent,
				true
			)
		)
		vertical_bar.add_theme_stylebox_override(
			"grabber_pressed",
			_luxury_scrollbar_grabber_style(
				outer_accent,
				true
			)
		)

	formation_scroll.gui_input.connect(
		_on_luxury_formation_scroll_gui_input.bind(
			formation_scroll
		)
	)

	set_meta(
		"luxury_formation_navigation_is_presentation_only",
		true
	)
	set_meta(
		"luxury_formation_navigation_engine_calls",
		false
	)
	set_meta(
		"luxury_formation_navigation_truth_reads",
		false
	)
	set_meta(
		"luxury_formation_drag_pan_enabled",
		true
	)
	set_meta(
		"luxury_formation_navigation_deferred_waits",
		false
	)


func _luxury_formation_pan_can_begin(
	formation_scroll: ScrollContainer
) -> bool:
	if (
		formation_scroll == null
		or not is_instance_valid(formation_scroll)
	):
		return false

	var hovered: Control = (
		get_viewport().gui_get_hovered_control()
	)

	if hovered == null:
		return true

	var cursor: Node = hovered

	while cursor != null:
		if cursor is BaseButton:
			return false

		if cursor is ScrollBar:
			return false

		if cursor.has_meta(
			"luxury_card_contract"
		):
			return false

		if (
			cursor == card_flow
			or cursor == formation_scroll
		):
			break

		cursor = cursor.get_parent()

	return true


func _apply_luxury_formation_scroll_position(
	formation_scroll: ScrollContainer,
	target_position: Vector2
) -> void:
	if (
		formation_scroll == null
		or not is_instance_valid(formation_scroll)
	):
		return

	var horizontal_bar: HScrollBar = (
		formation_scroll.get_h_scroll_bar()
	)
	var vertical_bar: VScrollBar = (
		formation_scroll.get_v_scroll_bar()
	)
	var max_horizontal: float = 0.0
	var max_vertical: float = 0.0

	if horizontal_bar != null:
		max_horizontal = maxf(
			0.0,
			horizontal_bar.max_value
			- horizontal_bar.page
		)

	if vertical_bar != null:
		max_vertical = maxf(
			0.0,
			vertical_bar.max_value
			- vertical_bar.page
		)

	formation_pan_scroll_position = Vector2(
		clampf(
			target_position.x,
			0.0,
			max_horizontal
		),
		clampf(
			target_position.y,
			0.0,
			max_vertical
		)
	)

	formation_scroll.scroll_horizontal = int(
		round(
			formation_pan_scroll_position.x
		)
	)
	formation_scroll.scroll_vertical = int(
		round(
			formation_pan_scroll_position.y
		)
	)

func _luxury_formation_card_under_pointer() -> Control:
	var hovered: Control = (
		get_viewport().gui_get_hovered_control()
	)

	if hovered == null:
		return null

	var cursor: Node = hovered

	while cursor != null:
		if (
			cursor is Control
			and cursor.has_meta(
				"luxury_card_contract"
			)
		):
			return cursor as Control

		if (
			cursor == card_flow
			or cursor.name == "LuxuryFormationScroll"
		):
			break

		cursor = cursor.get_parent()

	return null
func _on_luxury_formation_scroll_gui_input(
	event: InputEvent,
	formation_scroll: ScrollContainer
) -> void:
	if (
		formation_scroll == null
		or not is_instance_valid(formation_scroll)
	):
		return

	if event is InputEventPanGesture:
		var pan_event:= event as InputEventPanGesture



		formation_pan_hover_rearm_required = true

		formation_pan_scroll_position = Vector2(
			formation_scroll.scroll_horizontal,
			formation_scroll.scroll_vertical
		)

		_apply_luxury_formation_scroll_position(
			formation_scroll,
			formation_pan_scroll_position
			+ pan_event.delta * 62.0
		)

		formation_scroll.accept_event()
		return

	if event is InputEventMouseButton:
		var button_event:= (
			event as InputEventMouseButton
		)

		if (
			button_event.pressed
			and button_event.button_index in [
				MOUSE_BUTTON_WHEEL_UP,
				MOUSE_BUTTON_WHEEL_DOWN,
				MOUSE_BUTTON_WHEEL_LEFT,
				MOUSE_BUTTON_WHEEL_RIGHT
			]
		):
			var raw_wheel_factor: float = absf(
				button_event.factor
			)
			var wheel_factor: float = (
				1.0
				if raw_wheel_factor <= 0.001
				else clampf(
					raw_wheel_factor,
					0.35,
					3.0
				)
			)
			var horizontal_wheel_step: float = (
				clampf(
					formation_scroll.size.x * 0.11,
					104.0,
					172.0
				)
				* wheel_factor
			)
			var vertical_wheel_step: float = (
				clampf(
					formation_scroll.size.y * 0.16,
					96.0,
					156.0
				)
				* wheel_factor
			)
			var target_position:= Vector2(
				formation_scroll.scroll_horizontal,
				formation_scroll.scroll_vertical
			)



			formation_pan_hover_rearm_required = true

			match button_event.button_index:
				MOUSE_BUTTON_WHEEL_UP:
					if button_event.shift_pressed:
						target_position.x -= (
							horizontal_wheel_step
						)
					else:
						target_position.y -= (
							vertical_wheel_step
						)

				MOUSE_BUTTON_WHEEL_DOWN:
					if button_event.shift_pressed:
						target_position.x += (
							horizontal_wheel_step
						)
					else:
						target_position.y += (
							vertical_wheel_step
						)

				MOUSE_BUTTON_WHEEL_LEFT:
					target_position.x -= (
						horizontal_wheel_step
					)

				MOUSE_BUTTON_WHEEL_RIGHT:
					target_position.x += (
						horizontal_wheel_step
					)

			_apply_luxury_formation_scroll_position(
				formation_scroll,
				target_position
			)

			formation_scroll.accept_event()
			return

		if (
			button_event.button_index
			== MOUSE_BUTTON_LEFT
		):
			if button_event.pressed:
				if not _luxury_formation_pan_can_begin(
					formation_scroll
				):
					return

				formation_pan_active = true
				formation_pan_moved = false
				formation_pan_hover_rearm_required = true
				formation_pan_scroll_position = Vector2(
					formation_scroll.scroll_horizontal,
					formation_scroll.scroll_vertical
				)

				formation_scroll.mouse_default_cursor_shape = (
					Control.CURSOR_DRAG
				)

				if (
					card_flow != null
					and is_instance_valid(card_flow)
				):
					card_flow.mouse_default_cursor_shape = (
						Control.CURSOR_DRAG
					)

				formation_scroll.accept_event()
				return

			if formation_pan_active:
				var completed_drag: bool = (
					formation_pan_moved
				)

				formation_pan_active = false
				formation_pan_moved = false




				if completed_drag:
					formation_pan_hover_rearm_required = (
						_luxury_formation_card_under_pointer()
						!= null
					)
				else:
					formation_pan_hover_rearm_required = false

				formation_scroll.mouse_default_cursor_shape = (
					Control.CURSOR_MOVE
				)

				if (
					card_flow != null
					and is_instance_valid(card_flow)
				):
					card_flow.mouse_default_cursor_shape = (
						Control.CURSOR_MOVE
					)

				formation_scroll.accept_event()
				return

	if event is InputEventMouseMotion:
		var motion_event:= (
			event as InputEventMouseMotion
		)

		if formation_pan_active:
			if motion_event.relative.length_squared() > 0.0:
				formation_pan_moved = true

			_apply_luxury_formation_scroll_position(
				formation_scroll,
				formation_pan_scroll_position
				- motion_event.relative
			)

			formation_scroll.accept_event()
			return




		if (
			formation_pan_hover_rearm_required
			and _luxury_formation_card_under_pointer() == null
		):
			formation_pan_hover_rearm_required = false
			set_meta(
				"luxury_hover_rearmed_after_navigation",
				true
			)
func prepare_surface() -> void:
	if (
		title_label != null
		and is_instance_valid(title_label)
	):
		return

	name = "LuxuryExchangePanel"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 245
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	set_meta("schema", PANEL_SCHEMA)
	set_meta("version", CONTRACT_VERSION)
	set_meta("ui_is_renderer_only", true)
	set_meta("contract_build_on_click", false)
	set_meta("image_disk_load_on_render", false)




	set_meta(
		"luxury_sanctorum_shell_schema",
		SANCTORUM_SHELL_SCHEMA
	)
	set_meta(
		"luxury_sanctorum_shell_version",
		SANCTORUM_SHELL_VERSION
	)
	set_meta(
		"luxury_sanctorum_shell_title",
		"THE LUXURY SANCTORUM"
	)
	set_meta(
		"luxury_sanctorum_shell_subtitle",
		"Private acquisitions & exceptional exchange"
	)
	set_meta(
		"luxury_sanctorum_active_chamber_id",
		"exchange"
	)
	set_meta(
		"luxury_sanctorum_exchange_filters_are_chamber_local",
		true
	)
	set_meta(
		"luxury_sanctorum_future_chamber_rail_reserved",
		true
	)
	set_meta(
		"luxury_sanctorum_future_chamber_rail_axis",
		"left_vertical"
	)
	set_meta(
		"luxury_sanctorum_shell_owns_simulation_truth",
		false
	)

	set_meta(
		"luxury_formation_renderer",
		"scrollable_kinetic_luxury_orrery"
	)
	set_meta(
		"luxury_formation_scrollable",
		true
	)
	set_meta(
		"luxury_hover_projection_is_presentation_only",
		true
	)
	set_meta(
		"luxury_hover_projection_engine_calls",
		false
	)
	set_meta(
		"luxury_hover_projection_contract_rebuild",
		false
	)
	set_meta(
		"luxury_hover_projection_acquisition_is_intent_only",
		true
	)
	set_meta(
		"luxury_hover_bridge_is_presentation_only",
		true
	)
	set_meta(
		"luxury_centerpiece_hover_is_observation_expression_only",
		true
	)

	add_theme_stylebox_override(
		"panel",
		_exchange_panel_style()
	)

	var margin:= MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var root:= VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var top_bar:= HBoxContainer.new()
	top_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_theme_constant_override("separation", 14)
	root.add_child(top_bar)

	var back_button:= Button.new()
	back_button.name = "LuxuryReturnToActivities"
	back_button.text = "RETURN TO ACTIVITIES"
	back_button.custom_minimum_size = Vector2(188, 42)
	back_button.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND
	)
	back_button.add_theme_font_size_override(
		"font_size",
		11
	)
	back_button.add_theme_color_override(
		"font_color",
		Color(0.9, 0.8, 0.58, 0.94)
	)
	back_button.add_theme_color_override(
		"font_hover_color",
		Color(1.0, 0.95, 0.8, 1.0)
	)
	back_button.add_theme_color_override(
		"font_pressed_color",
		Color(0.96, 0.83, 0.55, 1.0)
	)
	back_button.add_theme_color_override(
		"font_focus_color",
		Color(1.0, 0.95, 0.8, 1.0)
	)
	back_button.add_theme_stylebox_override(
		"normal",
		_luxury_return_button_style(
			"normal"
		)
	)
	back_button.add_theme_stylebox_override(
		"hover",
		_luxury_return_button_style(
			"hover"
		)
	)
	back_button.add_theme_stylebox_override(
		"pressed",
		_luxury_return_button_style(
			"pressed"
		)
	)
	back_button.add_theme_stylebox_override(
		"focus",
		_luxury_return_button_style(
			"focus"
		)
	)
	back_button.pressed.connect(
		func ():
			close_requested.emit()
	)
	top_bar.add_child(back_button)

	var title_stack:= VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.add_theme_constant_override("separation", 1)
	top_bar.add_child(title_stack)




	var title_row:= HBoxContainer.new()
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override(
		"separation",
		8
	)
	title_stack.add_child(title_row)

	title_label = Label.new()
	title_label.name = "LuxurySanctorumTitlePrefix"
	title_label.text = "THE LUXURY"
	title_label.add_theme_font_size_override(
		"font_size",
		34
	)
	title_label.add_theme_color_override(
		"font_color",
		Color(0.98, 0.95, 0.86, 1.0)
	)
	title_row.add_child(title_label)

	sanctorum_title_label = (
		LuxurySanctorumWordLabel.new()
	)
	sanctorum_title_label.name = (
		"LuxurySanctorumAnimatedWord"
	)
	sanctorum_title_label.text = "SANCTORUM"
	sanctorum_title_label.add_theme_font_size_override(
		"font_size",
		34
	)
	sanctorum_title_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.9, 0.65, 1.0)
	)
	sanctorum_title_label.add_theme_color_override(
		"font_outline_color",
		Color(0.44, 0.27, 0.07, 0.72)
	)
	sanctorum_title_label.add_theme_constant_override(
		"outline_size",
		2
	)
	sanctorum_title_label.set_meta(
		"sanctorum_title_animation_is_presentation_only",
		true
	)
	sanctorum_title_label.set_meta(
		"sanctorum_title_animation_engine_calls",
		false
	)
	sanctorum_title_label.set_meta(
		"sanctorum_title_animation_truth_reads",
		false
	)
	title_row.add_child(
		sanctorum_title_label
	)

	subtitle_label = Label.new()
	subtitle_label.text = (
		"Private acquisitions & exceptional exchange"
	)
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.add_theme_font_size_override("font_size", 13)
	subtitle_label.add_theme_color_override(
		"font_color",
		Color(0.82, 0.8, 0.74, 0.84)
	)
	title_stack.add_child(subtitle_label)

	var spacer:= Control.new()
	spacer.custom_minimum_size = Vector2(188, 1)
	top_bar.add_child(spacer)

	var rule:= HSeparator.new()
	root.add_child(rule)

	tab_bar = HBoxContainer.new()
	tab_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_bar.add_theme_constant_override("separation", 8)
	root.add_child(tab_bar)

	var formation_scroll:= ScrollContainer.new()
	formation_scroll.name = "LuxuryFormationScroll"
	formation_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	formation_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	formation_scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_AUTO
	)
	formation_scroll.vertical_scroll_mode = (
		ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	)
	formation_scroll.scroll_deadzone = 0
	root.add_child(formation_scroll)

	card_flow = Control.new()
	card_flow.name = "LuxuryOrbitalFormation"
	card_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_flow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_flow.custom_minimum_size = Vector2(1800, 1660)
	card_flow.clip_contents = false
	card_flow.mouse_filter = Control.MOUSE_FILTER_PASS
	card_flow.mouse_default_cursor_shape = (
		Control.CURSOR_MOVE
	)
	card_flow.set_meta(
		"formation",
		"centerpiece_with_collision_free_dual_ring"
	)
	card_flow.set_meta(
		"truth_owner",
		"resident_card_contracts"
	)
	card_flow.set_meta(
		"formation_canvas_minimum",
		Vector2(1800, 1660)
	)
	card_flow.set_meta(
		"formation_canvas_policy",
		"expanded_annular_navigation_envelope"
	)
	card_flow.set_meta(
		"orbit_clock_scope",
		"shared_ring_phase"
	)
	card_flow.resized.connect(
		_layout_luxury_orbital_formation
	)
	formation_scroll.add_child(card_flow)

	_install_luxury_formation_navigation(
		formation_scroll
	)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override(
		"font_color",
		Color(0.82, 0.8, 0.72, 0.78)
	)
	root.add_child(status_label)




	var hover_overlay:= Control.new()
	hover_overlay.name = "LuxuryHoverOverlay"
	hover_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_overlay.z_index = 800
	hover_overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	add_child(hover_overlay)

	var projection:= PanelContainer.new()
	projection.name = "LuxuryHoverProjection"
	projection.visible = false
	projection.mouse_filter = Control.MOUSE_FILTER_STOP
	projection.custom_minimum_size = Vector2(372, 410)
	projection.size = projection.custom_minimum_size
	hover_overlay.add_child(projection)

	var projection_margin:= MarginContainer.new()
	projection_margin.name = "ProjectionMargin"
	projection_margin.mouse_filter = Control.MOUSE_FILTER_PASS
	projection_margin.add_theme_constant_override(
		"margin_left",
		18
	)
	projection_margin.add_theme_constant_override(
		"margin_top",
		16
	)
	projection_margin.add_theme_constant_override(
		"margin_right",
		18
	)
	projection_margin.add_theme_constant_override(
		"margin_bottom",
		16
	)
	projection.add_child(projection_margin)

	var projection_root:= VBoxContainer.new()
	projection_root.name = "ProjectionRoot"
	projection_root.mouse_filter = Control.MOUSE_FILTER_PASS
	projection_root.add_theme_constant_override(
		"separation",
		6
	)
	projection_margin.add_child(projection_root)

	for field_name in [
		"Classification",
		"Title",
		"House",
		"Ask",
		"Market",
		"Rarity",
		"History",
		"Provenance",
		"Lore"
	]:
		var field:= Label.new()
		field.name = field_name
		field.mouse_filter = Control.MOUSE_FILTER_IGNORE
		field.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		projection_root.add_child(field)

	var projection_acquire:= Button.new()
	projection_acquire.name = "Acquire"
	projection_acquire.text = "REQUEST ACQUISITION"
	projection_acquire.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	projection_acquire.custom_minimum_size = Vector2(0, 38)
	projection_acquire.mouse_filter = Control.MOUSE_FILTER_STOP
	projection_acquire.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND
	)
	projection_acquire.add_theme_font_size_override(
		"font_size",
		11
	)
	projection_acquire.pressed.connect(
		func ():
			var projected_contract: Dictionary = _safe_dictionary(
				projection.get_meta(
					"luxury_card_contract",
					{}
				)
			)

			if projected_contract.is_empty():
				return

			if bool(
				projected_contract.get(
					"acquisition_disabled",
					false
				)
			):
				return

			if _safe_dictionary(
				projected_contract.get(
					"acquisition_intent",
					{}
				)
			).is_empty():
				return

			acquisition_requested.emit(
				projected_contract.duplicate(false)
			)
	)
	projection_root.add_child(
		projection_acquire
	)

	var projection_leave:= Button.new()
	projection_leave.name = "Leave"
	projection_leave.text = "LEAVE"
	projection_leave.visible = false
	projection_leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	projection_leave.custom_minimum_size = Vector2(
		0,
		34
	)
	projection_leave.mouse_filter = Control.MOUSE_FILTER_STOP
	projection_leave.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND
	)
	projection_leave.add_theme_font_size_override(
		"font_size",
		10
	)

	projection_leave.pressed.connect(
		func ():
			var projected_contract: Dictionary = _safe_dictionary(
				projection.get_meta(
					"luxury_card_contract",
					{}
				)
			)

			if projected_contract.is_empty():
				return

			var leave_intent: Dictionary = _safe_dictionary(
				projected_contract.get(
					"leave_intent",
					{}
				)
			)

			set_meta(
				"luxury_extraordinary_projection_locked",
				false
			)

			if not leave_intent.is_empty():
				acquisition_requested.emit({
					"card_id": (
						"%s:leave"
						% str(
							projected_contract.get(
								"card_id",
								"luxury_projection"
							)
						)
					),
					"acquisition_disabled": false,
					"acquisition_intent": leave_intent.duplicate(true),
					"ui_is_renderer_only": true
				})

			_clear_luxury_hover_focus(
				true
			)
	)

	projection_root.add_child(
		projection_leave
	)

	set_process(true)
func begin_resident_surface_stream(
	target_actor: Person,
	surface_contract: Dictionary
) -> void:
	actor = target_actor
	prepare_surface()

	active_contract = surface_contract.duplicate(false)
	active_section_id = "featured"




	set_meta(
		"luxury_sanctorum_active_chamber_id",
		"exchange"
	)
	set_meta(
		"luxury_sanctorum_active_chamber_title",
		str(
			active_contract.get(
				"title",
				"THE LUXURY EXCHANGE"
			)
		)
	)
	set_meta(
		"luxury_sanctorum_active_chamber_subtitle",
		str(
			active_contract.get(
				"subtitle",
				"Private acquisitions"
			)
		)
	)
	set_meta(
		"luxury_sanctorum_active_chamber_contract_schema",
		str(
			active_contract.get(
				"schema",
				""
			)
		)
	)
	set_meta(
		"luxury_sanctorum_old_exchange_packet_mutated",
		false
	)



	title_label.text = "THE LUXURY"

	if (
		sanctorum_title_label != null
		and is_instance_valid(
			sanctorum_title_label
		)
	):
		sanctorum_title_label.text = "SANCTORUM"

	subtitle_label.text = (
		"Private acquisitions & exceptional exchange"
	)

	_clear_luxury_hover_focus(
		true
	)
	_clear_children(tab_bar)
	_clear_children(card_flow)

	card_controls.clear()
	fx_entries.clear()
	fx_cursor = 0
	fx_time = 0.0

	var layout_contract: Dictionary = _safe_dictionary(
		active_contract.get(
			"layout_contract",
			{}
		)
	)
	var ring_motion: Dictionary = _safe_dictionary(
		layout_contract.get(
			"ring_motion",
			{}
		)
	)
	var inner_motion: Dictionary = _safe_dictionary(
		ring_motion.get(
			"inner_orbit",
			{}
		)
	)
	var outer_motion: Dictionary = _safe_dictionary(
		ring_motion.get(
			"outer_orbit",
			{}
		)
	)

	if (
		card_flow != null
		and is_instance_valid(card_flow)
	):
		card_flow.set_meta(
			"luxury_inner_ring_phase",
			0.0
		)
		card_flow.set_meta(
			"luxury_outer_ring_phase",
			0.0
		)
		card_flow.set_meta(
			"luxury_inner_ring_direction",
			int(
				inner_motion.get(
					"direction",
					1
				)
			)
		)
		card_flow.set_meta(
			"luxury_outer_ring_direction",
			int(
				outer_motion.get(
					"direction",
					-1
				)
			)
		)
		card_flow.set_meta(
			"luxury_inner_ring_duration_seconds",
			maxf(
				1.0,
				float(
					inner_motion.get(
						"duration_seconds",
						72.0
					)
				)
			)
		)
		card_flow.set_meta(
			"luxury_outer_ring_duration_seconds",
			maxf(
				1.0,
				float(
					outer_motion.get(
						"duration_seconds",
						96.0
					)
				)
			)
		)
		card_flow.set_meta(
			"luxury_orbit_paused",
			false
		)
		card_flow.set_meta(
			"luxury_ring_motion_source",
			"resident_layout_contract"
		)

	set_meta(
		"luxury_hover_release_pending",
		false
	)
	set_meta(
		"luxury_exchange_scroll_center_pending",
		true
	)



	_build_tab_buttons(
		_safe_array(
			active_contract.get(
				"tabs",
				[]
			)
		)
	)

	var expected_cards: int = int(
		active_contract.get(
			"card_count",
			0
		)
	)
	var centerpiece_card_id: String = str(
		active_contract.get(
			"centerpiece_card_id",
			""
		)
	).strip_edges()

	status_label.text = (
		(
			"Establishing the private-market centerpiece"
			+ " • %d resident object%s queued"
		)
		% [
			expected_cards,
			"" if expected_cards == 1 else "s"
		]
	)

	set_meta("luxury_exchange_stream_active", true)
	set_meta("luxury_exchange_stream_rendered_cards", 0)
	set_meta(
		"luxury_exchange_centerpiece_card_id",
		centerpiece_card_id
	)
	set_meta(
		"luxury_exchange_centerpiece_published",
		false
	)
	set_meta(
		"luxury_exchange_visual_reveal_is_renderer_only",
		true
	)
	set_meta(
		"luxury_exchange_visual_reveal_engine_calls",
		false
	)
	set_meta(
		"luxury_exchange_visual_reveal_contract_rebuild",
		false
	)
	set_meta(
		"luxury_sanctorum_exchange_chamber_resident",
		true
	)
	set_meta(
		"luxury_sanctorum_exchange_category_tabs_nested",
		true
	)
func _luxury_fixed_card_size_for_contract(
	card_contract: Dictionary
) -> Vector2:
	var is_centerpiece: bool = bool(
		card_contract.get(
			"centerpiece",
			false
		)
	)
	var span: String = str(
		card_contract.get(
			"mosaic_span",
			"standard_1x1"
		)
	).strip_edges().to_lower()

	if is_centerpiece:
		span = "hero_2x2"
	elif span == "hero_2x2":



		span = "standard_1x1"

	if span not in [
		"hero_2x2",
		"landscape_2x1",
		"portrait_1x2",
		"standard_1x1"
	]:
		span = "standard_1x1"

	return _card_size_for_span(
		span
	)


func _lock_luxury_card_fixed_dimensions(
	card: Control,
	card_contract: Dictionary
) -> void:
	if (
		card == null
		or not is_instance_valid(card)
	):
		return

	var fixed_size: Vector2 = (
		_luxury_fixed_card_size_for_contract(
			card_contract
		)
	)









	var content_host:= card.get_node_or_null(
		"LuxuryFixedContentHost"
	) as Control

	if content_host == null:
		var content_margin: MarginContainer = null

		for raw_child in card.get_children():
			if raw_child is MarginContainer:
				content_margin = raw_child as MarginContainer
				break

		if content_margin != null:
			content_host = Control.new()
			content_host.name = "LuxuryFixedContentHost"
			content_host.mouse_filter = (
				Control.MOUSE_FILTER_PASS
			)
			content_host.clip_contents = true
			content_host.custom_minimum_size = Vector2.ZERO
			content_host.set_anchors_and_offsets_preset(
				Control.PRESET_FULL_RECT
			)

			card.add_child(
				content_host
			)

			content_margin.reparent(
				content_host
			)
			content_margin.set_anchors_and_offsets_preset(
				Control.PRESET_FULL_RECT
			)

	card.custom_minimum_size = fixed_size
	card.size = fixed_size
	card.scale = Vector2.ONE
	card.pivot_offset = fixed_size * 0.5

	card.set_meta(
		"luxury_fixed_card_size",
		fixed_size
	)
	card.set_meta(
		"luxury_rest_scale",
		1.0
	)
	card.set_meta(
		"luxury_card_scale_locked",
		true
	)
	card.set_meta(
		"luxury_card_size_authority",
		"mosaic_span_fixed_vector"
	)
	card.set_meta(
		"luxury_card_children_can_expand_shell",
		false
	)
	card.set_meta(
		"luxury_card_orbit_scale_affects_dimensions",
		false
	)
func append_resident_card_contract(
	card_contract: Dictionary
) -> void:
	prepare_surface()

	if card_contract.is_empty():
		return

	var render_contract: Dictionary = card_contract.duplicate(false)
	var publication_index: int = int(
		render_contract.get(
			"publication_index",
			card_controls.size()
		)
	)
	var centerpiece_card_id: String = str(
		active_contract.get(
			"centerpiece_card_id",
			""
		)
	).strip_edges()
	var card_id: String = str(
		render_contract.get(
			"card_id",
			""
		)
	).strip_edges()
	var is_centerpiece: bool = bool(
		render_contract.get(
			"centerpiece",
			false
		)
	)




	if (
		not is_centerpiece
		and centerpiece_card_id != ""
		and card_id == centerpiece_card_id
	):
		is_centerpiece = true

	if (
		not is_centerpiece
		and centerpiece_card_id == ""
		and publication_index == 0
	):
		is_centerpiece = true

	render_contract ["centerpiece"] = is_centerpiece
	render_contract ["publication_index"] = publication_index

	var card: Control = _build_luxury_card(
		render_contract
	)





	_lock_luxury_card_fixed_dimensions(
		card,
		render_contract
	)

	card_flow.add_child(
		card
	)
	card.size = card.custom_minimum_size
	card.scale = Vector2.ONE
	card.pivot_offset = card.size * 0.5
	card_controls.append(
		card
	)



	_place_luxury_orbital_card(
		card,
		render_contract
	)

	if is_centerpiece:
		set_meta(
			"luxury_exchange_centerpiece_published",
			true
		)

	_apply_section_filter()

	var rendered_count: int = int(
		get_meta(
			"luxury_exchange_stream_rendered_cards",
			0
		)
	) + 1

	set_meta(
		"luxury_exchange_stream_rendered_cards",
		rendered_count
	)

	var expected_count: int = int(
		active_contract.get(
			"card_count",
			rendered_count
		)
	)

	status_label.text = (
		"Private market publishing • %d / %d resident pieces"
		% [
			rendered_count,
			maxi(
				rendered_count,
				expected_count
			)
		]
	)

	set_meta(
		"luxury_exchange_card_dimensions_fixed",
		true
	)
	set_meta(
		"luxury_exchange_card_dimension_truth_source",
		"resident_mosaic_span"
	)
	set_meta(
		"luxury_exchange_card_dimension_engine_calls",
		false
	)
func finish_resident_surface_stream() -> void:
	prepare_surface()

	var market_year: int = int(
		active_contract.get(
			"market_year",
			0
		)
	)

	status_label.text = (
		(
			"Resident private market • %d exceptional object%s"
			+ " currently circulating • Year %d"
		)
		% [
			card_controls.size(),
			(
				""
				if card_controls.size() == 1
				else "s"
			),
			market_year
		]
		if not card_controls.is_empty()
		else (
			"No exceptional objects are circulating "
			+ "in this resident market."
		)
	)

	set_meta(
		"luxury_exchange_stream_active",
		false
	)
	set_meta(
		"luxury_exchange_stream_complete",
		true
	)
	set_meta(
		"luxury_exchange_stream_completed_at_ms",
		int(
			Time.get_ticks_msec()
		)
	)
	set_meta(
		"luxury_exchange_stream_card_count",
		card_controls.size()
	)
	set_meta(
		"luxury_exchange_stream_remained_nonblocking",
		true
	)


func apply_action_result(
	result: Dictionary
) -> void:
	var presentation_raw: Variant = result.get(
		"extraordinary_presentation_card",
		{}
	)

	if typeof(
		presentation_raw
	) == TYPE_DICTIONARY:
		var presentation_card: Dictionary = (
			presentation_raw as Dictionary
		).duplicate(false)

		if not presentation_card.is_empty():
			_populate_luxury_hover_projection(
				presentation_card
			)

			set_meta(
				"luxury_hover_projection_active",
				true
			)
			set_meta(
				"luxury_hover_projection_engine_calls",
				false
			)
			set_meta(
				"luxury_hover_projection_simulation_mutation",
				false
			)

			if status_label != null:
				status_label.text = ""

			return

	if status_label == null:
		return

	var text: String = str(
		result.get(
			"text",
			result.get(
				"reason",
				""
			)
		)
	).strip_edges()

	if text != "":
		status_label.text = text

func _build_tab_buttons(
	tabs: Array
) -> void:
	for raw_tab in tabs:
		if typeof(raw_tab) != TYPE_DICTIONARY:
			continue

		var tab: Dictionary = (
			raw_tab as Dictionary
		)
		var section_id: String = str(
			tab.get(
				"id",
				""
			)
		).strip_edges().to_lower()

		if section_id == "":
			continue

		var button:= Button.new()
		button.text = str(
			tab.get(
				"label",
				section_id.to_upper()
			)
		)
		button.toggle_mode = true
		button.button_pressed = (
			section_id == active_section_id
		)
		button.mouse_default_cursor_shape = (
			Control.CURSOR_POINTING_HAND
		)
		button.add_theme_font_size_override(
			"font_size",
			11
		)
		button.pressed.connect(
			func ():
				active_section_id = section_id

				for sibling in tab_bar.get_children():
					if sibling is Button:
						(
							sibling as Button
						).button_pressed = (
							sibling == button
						)

				_apply_section_filter()
		)
		tab_bar.add_child(
			button
		)


func _apply_section_filter() -> void:
	for raw_card in card_controls:
		var card: Control = raw_card as Control

		if (
			card == null
			or not is_instance_valid(card)
		):
			continue



		if active_section_id == "featured":
			card.visible = true
			continue

		card.visible = (
			str(
				card.get_meta(
					"luxury_section_id",
					"collectibles"
				)
			) == active_section_id
		)
func _luxury_layout_contract() -> Dictionary:
	return _safe_dictionary(
		active_contract.get(
			"layout_contract",
			{}
		)
	)


func _luxury_presentation_class(
	card_contract: Dictionary
) -> String:
	var section_id: String = str(
		card_contract.get(
			"section_id",
			"collectibles"
		)
	).strip_edges().to_lower()

	match section_id:
		"jewelry":
			return "jewel"

		"watches":
			return "horology"

		"fashion":
			return "couture"

		"art":
			return "fine_art"

		"artifacts":
			return "artifact_relic"

		"vehicles", "property":
			return "grand_asset"

		_:
			return "collector_object"


func _luxury_is_exceptional_presentation(
	card_contract: Dictionary
) -> bool:
	var classification: String = str(
		card_contract.get(
			"classification",
			"AVAILABLE"
		)
	).strip_edges().to_upper()

	return (
		classification in [
			"COLLECTOR",
			"EXCEPTIONAL",
			"ONE OF ONE",
			"HISTORIC",
			"ARTIFACT"
		]
		or classification.begins_with(
			"ARTIFACT_"
		)
	)


func _luxury_aperture_size(
	presentation_class: String,
	is_centerpiece: bool
) -> Vector2:
	var clean: String = str(
		presentation_class
	).strip_edges().to_lower()

	if is_centerpiece:
		match clean:
			"jewel":
				return Vector2(132, 78)

			"horology":
				return Vector2(82, 82)

			"couture":
				return Vector2(76, 88)

			"fine_art":
				return Vector2(168, 78)

			"artifact_relic":
				return Vector2(88, 88)

			"grand_asset":
				return Vector2(174, 72)

			_:
				return Vector2(118, 78)

	match clean:
		"jewel":
			return Vector2(42, 42)

		"horology":
			return Vector2(42, 42)

		"couture":
			return Vector2(34, 46)

		"fine_art":
			return Vector2(54, 36)

		"artifact_relic":
			return Vector2(44, 44)

		"grand_asset":
			return Vector2(58, 34)

		_:
			return Vector2(42, 42)


func _luxury_aperture_style(
	card_contract: Dictionary,
	presentation_class: String,
	is_centerpiece: bool
) -> StyleBoxFlat:
	var classification: String = str(
		card_contract.get(
			"classification",
			"AVAILABLE"
		)
	).strip_edges().to_upper()
	var accent: Color = _classification_color(
		classification
	)
	var clean_class: String = str(
		presentation_class
	).strip_edges().to_lower()

	var style:= StyleBoxFlat.new()
	var base_surface:= Color(
		0.018,
		0.019,
		0.022,
		0.98
	)

	style.bg_color = base_surface.lerp(
		accent,
		0.07 if is_centerpiece else 0.035
	)
	style.border_color = Color(
		accent.r,
		accent.g,
		accent.b,
		0.52 if is_centerpiece else 0.28
	)
	style.set_border_width_all(
		2 if is_centerpiece else 1
	)

	match clean_class:
		"horology":
			style.set_corner_radius_all(
				42 if is_centerpiece else 24
			)

		"couture":
			style.set_corner_radius_all(
				12 if is_centerpiece else 9
			)

		"fine_art":
			style.set_corner_radius_all(3)

		"artifact_relic":
			style.set_corner_radius_all(
				18 if is_centerpiece else 12
			)

		"grand_asset":
			style.set_corner_radius_all(4)

		"jewel":
			style.set_corner_radius_all(7)

		_:
			style.set_corner_radius_all(6)

	return style


func _install_luxury_card_chrome(
	card: Control,
	card_contract: Dictionary
) -> void:
	if (
		card == null
		or not is_instance_valid(card)
	):
		return

	var classification: String = str(
		card_contract.get(
			"classification",
			"AVAILABLE"
		)
	).strip_edges().to_upper()
	var accent: Color = _classification_color(
		classification
	)
	var is_centerpiece: bool = bool(
		card_contract.get(
			"centerpiece",
			false
		)
	)
	var exceptional: bool = (
		_luxury_is_exceptional_presentation(
			card_contract
		)
	)
	var presentation_class: String = (
		_luxury_presentation_class(
			card_contract
		)
	)

	card.clip_contents = false
	card.set_meta(
		"luxury_presentation_class",
		presentation_class
	)
	card.set_meta(
		"luxury_nominal_depth_tier",
		4
		if is_centerpiece
		else (
			2
			if exceptional
			else 1
		)
	)




	var mount_glow: Line2D = Line2D.new()
	mount_glow.name = "LuxuryMountGlow"
	mount_glow.antialiased = true
	mount_glow.width = (
		7.0
		if is_centerpiece
		else 4.5
	)
	mount_glow.default_color = Color(
		accent.r,
		accent.g,
		accent.b,
		0.22
		if (
			is_centerpiece
			or exceptional
		)
		else 0.11
	)
	mount_glow.z_index = -2
	mount_glow.show_behind_parent = true
	mount_glow.set_meta(
		"luxury_presentation_only",
		true
	)
	mount_glow.set_meta(
		"luxury_gui_input_owner",
		false
	)
	card.add_child(mount_glow)

	var mount_core: Line2D = Line2D.new()
	mount_core.name = "LuxuryMountCore"
	mount_core.antialiased = true
	mount_core.width = (
		1.7
		if is_centerpiece
		else 1.15
	)
	mount_core.default_color = Color(
		accent.r,
		accent.g,
		accent.b,
		0.6
		if is_centerpiece
		else (
			0.48
			if exceptional
			else 0.32
		)
	)
	mount_core.z_index = -1
	mount_core.show_behind_parent = true
	mount_core.set_meta(
		"luxury_presentation_only",
		true
	)
	mount_core.set_meta(
		"luxury_gui_input_owner",
		false
	)
	card.add_child(mount_core)

	var mount_node:= Label.new()
	mount_node.name = "LuxuryMountNode"
	mount_node.text = "◆"
	mount_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mount_node.custom_minimum_size = Vector2(10, 10)
	mount_node.size = mount_node.custom_minimum_size
	mount_node.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	mount_node.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)
	mount_node.add_theme_font_size_override(
		"font_size",
		8
	)
	mount_node.add_theme_color_override(
		"font_color",
		Color(
			accent.r,
			accent.g,
			accent.b,
			0.62
		)
	)
	mount_node.z_index = -1
	mount_node.show_behind_parent = true
	card.add_child(mount_node)

	if not is_centerpiece:
		return

	var left_wing: Line2D = Line2D.new()
	left_wing.name = "LuxuryCenterpieceLeftWing"
	left_wing.antialiased = true
	left_wing.width = 1.0
	left_wing.default_color = Color(
		accent.r,
		accent.g,
		accent.b,
		0.34
	)
	left_wing.z_index = -1
	left_wing.show_behind_parent = true
	left_wing.set_meta(
		"luxury_presentation_only",
		true
	)
	left_wing.set_meta(
		"luxury_gui_input_owner",
		false
	)
	card.add_child(left_wing)

	var right_wing: Line2D = Line2D.new()
	right_wing.name = "LuxuryCenterpieceRightWing"
	right_wing.antialiased = true
	right_wing.width = 1.0
	right_wing.default_color = Color(
		accent.r,
		accent.g,
		accent.b,
		0.34
	)
	right_wing.z_index = -1
	right_wing.show_behind_parent = true
	right_wing.set_meta(
		"luxury_presentation_only",
		true
	)
	right_wing.set_meta(
		"luxury_gui_input_owner",
		false
	)
	card.add_child(right_wing)

	var ornament_layer:= Control.new()
	ornament_layer.name = "LuxuryCenterpieceOrnaments"
	ornament_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ornament_layer.size = card.custom_minimum_size
	ornament_layer.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	ornament_layer.z_index = 20
	card.add_child(ornament_layer)

	var card_width: float = card.custom_minimum_size.x
	var card_height: float = card.custom_minimum_size.y
	var ornament_color:= Color(
		accent.r,
		accent.g,
		accent.b,
		0.3
	)
	var ornament_specs: Array = [
		{
			"position": Vector2(10, 10),
			"size": Vector2(28, 1)
		},
		{
			"position": Vector2(10, 10),
			"size": Vector2(1, 20)
		},
		{
			"position": Vector2(card_width - 38, 10),
			"size": Vector2(28, 1)
		},
		{
			"position": Vector2(card_width - 11, 10),
			"size": Vector2(1, 20)
		},
		{
			"position": Vector2(10, card_height - 11),
			"size": Vector2(28, 1)
		},
		{
			"position": Vector2(10, card_height - 30),
			"size": Vector2(1, 20)
		},
		{
			"position": Vector2(
				card_width - 38,
				card_height - 11
			),
			"size": Vector2(28, 1)
		},
		{
			"position": Vector2(
				card_width - 11,
				card_height - 30
			),
			"size": Vector2(1, 20)
		}
	]

	for raw_spec in ornament_specs:
		if typeof(raw_spec) != TYPE_DICTIONARY:
			continue

		var spec: Dictionary = raw_spec as Dictionary
		var ornament:= ColorRect.new()
		ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ornament.position = spec.get(
			"position",
			Vector2.ZERO
		)
		ornament.size = spec.get(
			"size",
			Vector2.ONE
		)
		ornament.color = ornament_color
		ornament_layer.add_child(ornament)


func _update_luxury_card_mount_geometry(
	card: Control,
	composition_center: Vector2,
	orbit_center: Vector2,
	is_centerpiece: bool
) -> void:
	if (
		card == null
		or not is_instance_valid(card)
	):
		return

	var mount_glow:= card.get_node_or_null(
		"LuxuryMountGlow"
	) as Line2D
	var mount_core:= card.get_node_or_null(
		"LuxuryMountCore"
	) as Line2D
	var mount_node:= card.get_node_or_null(
		"LuxuryMountNode"
	) as Label

	if (
		mount_glow == null
		or mount_core == null
		or mount_node == null
	):
		return

	var local_center: Vector2 = card.size * 0.5

	if is_centerpiece:
		var pedestal_y: float = card.size.y + 10.0

		mount_glow.points = PackedVector2Array([
			Vector2(
				local_center.x - 62.0,
				pedestal_y
			),
			Vector2(
				local_center.x + 62.0,
				pedestal_y
			)
		])
		mount_core.points = PackedVector2Array([
			Vector2(
				local_center.x - 44.0,
				pedestal_y
			),
			Vector2(
				local_center.x + 44.0,
				pedestal_y
			)
		])
		mount_node.position = Vector2(
			local_center.x
			- mount_node.size.x * 0.5,
			pedestal_y
			- mount_node.size.y * 0.5
		)

		var left_wing:= card.get_node_or_null(
			"LuxuryCenterpieceLeftWing"
		) as Line2D
		var right_wing:= card.get_node_or_null(
			"LuxuryCenterpieceRightWing"
		) as Line2D

		if left_wing != null:
			left_wing.points = PackedVector2Array([
				Vector2(
					-28.0,
					local_center.y
				),
				Vector2(
					-7.0,
					local_center.y
				)
			])

		if right_wing != null:
			right_wing.points = PackedVector2Array([
				Vector2(
					card.size.x + 7.0,
					local_center.y
				),
				Vector2(
					card.size.x + 28.0,
					local_center.y
				)
			])

		return

	var inward_direction: Vector2 = (
		composition_center - orbit_center
	)

	if inward_direction.length_squared() < 0.0001:
		inward_direction = Vector2.DOWN
	else:
		inward_direction = inward_direction.normalized()

	var half_size: Vector2 = card.size * 0.5
	var x_distance: float = 1000000.0
	var y_distance: float = 1000000.0

	if absf(inward_direction.x) > 0.0001:
		x_distance = (
			half_size.x
			/ absf(inward_direction.x)
		)

	if absf(inward_direction.y) > 0.0001:
		y_distance = (
			half_size.y
			/ absf(inward_direction.y)
		)

	var edge_distance: float = minf(
		x_distance,
		y_distance
	)
	var edge_point: Vector2 = (
		local_center
		+ inward_direction * edge_distance
	)
	var mount_point: Vector2 = (
		edge_point
		+ inward_direction * 17.0
	)

	mount_glow.points = PackedVector2Array([
		edge_point,
		mount_point
	])
	mount_core.points = PackedVector2Array([
		edge_point,
		mount_point
	])
	mount_node.position = (
		mount_point
		- mount_node.size * 0.5
	)


func _set_luxury_card_focus_presentation(
	card: Control,
	focused: bool,
	dimmed: bool
) -> void:
	if (
		card == null
		or not is_instance_valid(card)
	):
		return

	var card_contract: Dictionary = _safe_dictionary(
		card.get_meta(
			"luxury_card_contract",
			{}
		)
	)

	if card_contract.is_empty():
		return

	var layout_contract: Dictionary = (
		_luxury_layout_contract()
	)
	var dim_alpha: float = clampf(
		float(
			layout_contract.get(
				"hover_focus_nonfocused_alpha",
				0.4
			)
		),
		0.25,
		0.7
	)
	var classification: String = str(
		card_contract.get(
			"classification",
			"AVAILABLE"
		)
	).strip_edges().to_upper()
	var accent: Color = _classification_color(
		classification
	)
	var exceptional: bool = (
		_luxury_is_exceptional_presentation(
			card_contract
		)
	)
	var is_centerpiece: bool = bool(
		card_contract.get(
			"centerpiece",
			false
		)
	)
	var mount_dim_multiplier: float = (
		dim_alpha
		if dimmed
		else 1.0
	)

	card.set_meta(
		"luxury_hovered",
		focused
	)
	card.set_meta(
		"luxury_focus_dimmed",
		dimmed
	)
	card.modulate.a = (
		1.0
		if focused
		else (
			dim_alpha
			if dimmed
			else 1.0
		)
	)



	card.scale = Vector2.ONE

	card.add_theme_stylebox_override(
		"panel",
		_card_style(
			card_contract,
			{
				"hovered": focused,
				"dimmed": dimmed,
				"ceremonial": is_centerpiece
			}
		)
	)

	card.z_index = (
		950
		if focused
		else int(
			card.get_meta(
				"luxury_base_z_index",
				card.z_index
			)
		)
	)

	var mount_glow:= card.get_node_or_null(
		"LuxuryMountGlow"
	) as Line2D
	var mount_core:= card.get_node_or_null(
		"LuxuryMountCore"
	) as Line2D
	var mount_node:= card.get_node_or_null(
		"LuxuryMountNode"
	) as Label

	if mount_glow != null:
		mount_glow.default_color = Color(
			accent.r,
			accent.g,
			accent.b,
			0.72
			if focused
			else (
				(
					0.22
					if exceptional
					else 0.11
				)
				* mount_dim_multiplier
			)
		)

	if mount_core != null:
		mount_core.default_color = Color(
			accent.r,
			accent.g,
			accent.b,
			0.96
			if focused
			else (
				(
					0.48
					if exceptional
					else 0.32
				)
				* mount_dim_multiplier
			)
		)

	if mount_node != null:
		mount_node.add_theme_color_override(
			"font_color",
			Color(
				accent.r,
				accent.g,
				accent.b,
				0.98
				if focused
				else (
					0.62
					* mount_dim_multiplier
				)
			)
		)

	card.set_meta(
		"luxury_focus_changes_card_dimensions",
		false
	)
func _build_luxury_card(
	card_contract: Dictionary
) -> Control:
	var classification_id: String = str(
		card_contract.get(
			"classification",
			"AVAILABLE"
		)
	).strip_edges().to_upper()
	var span: String = str(
		card_contract.get(
			"mosaic_span",
			"standard_1x1"
		)
	).strip_edges().to_lower()
	var is_centerpiece: bool = bool(
		card_contract.get(
			"centerpiece",
			false
		)
	)
	var publication_index: int = int(
		card_contract.get(
			"publication_index",
			card_controls.size()
		)
	)
	var accent: Color = _classification_color(
		classification_id
	)
	var presentation_class: String = (
		_luxury_presentation_class(
			card_contract
		)
	)

	if is_centerpiece:
		span = "hero_2x2"

	var card:= PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	card.custom_minimum_size = _card_size_for_span(span)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.clip_contents = false
	card.modulate = Color(1.0, 1.0, 1.0, 0.0)
	card.scale = (
		Vector2(0.972, 0.972)
		if is_centerpiece
		else Vector2(0.986, 0.986)
	)
	card.pivot_offset = card.custom_minimum_size * 0.5

	card.set_meta(
		"luxury_section_id",
		str(
			card_contract.get(
				"section_id",
				"collectibles"
			)
		)
	)
	card.set_meta(
		"luxury_featured",
		bool(
			card_contract.get(
				"featured",
				false
			)
		)
	)
	card.set_meta(
		"luxury_centerpiece",
		is_centerpiece
	)
	card.set_meta(
		"luxury_publication_index",
		publication_index
	)
	card.set_meta(
		"luxury_presentation_class",
		presentation_class
	)
	card.set_meta("luxury_hovered", false)
	card.set_meta("luxury_focus_dimmed", false)
	card.set_meta(
		"luxury_card_contract",
		card_contract.duplicate(false)
	)
	card.set_meta("ui_is_renderer_only", true)

	card.mouse_entered.connect(
		func ():
			_apply_luxury_hover_focus(card)
	)
	card.mouse_exited.connect(
		func ():
			_release_luxury_hover_focus(card)
	)

	card.add_theme_stylebox_override(
		"panel",
		_card_style(
			card_contract,
			false
		)
	)

	_install_luxury_card_chrome(
		card,
		card_contract
	)

	var margin:= MarginContainer.new()
	margin.add_theme_constant_override(
		"margin_left",
		20 if is_centerpiece else 10
	)
	margin.add_theme_constant_override(
		"margin_top",
		18 if is_centerpiece else 9
	)
	margin.add_theme_constant_override(
		"margin_right",
		20 if is_centerpiece else 10
	)
	margin.add_theme_constant_override(
		"margin_bottom",
		18 if is_centerpiece else 9
	)
	card.add_child(margin)

	var root:= VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override(
		"separation",
		6 if is_centerpiece else 4
	)
	margin.add_child(root)

	var accent_line:= ColorRect.new()
	accent_line.custom_minimum_size = Vector2(0, 2)
	accent_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	accent_line.color = accent
	accent_line.modulate.a = 0.26
	root.add_child(accent_line)

	if is_centerpiece:
		var centerpiece_crest:= HBoxContainer.new()
		centerpiece_crest.size_flags_horizontal = (
			Control.SIZE_EXPAND_FILL
		)
		centerpiece_crest.add_theme_constant_override(
			"separation",
			7
		)
		root.add_child(centerpiece_crest)

		var crest_left:= ColorRect.new()
		crest_left.custom_minimum_size = Vector2(0, 1)
		crest_left.size_flags_horizontal = (
			Control.SIZE_EXPAND_FILL
		)
		crest_left.color = Color(
			accent.r,
			accent.g,
			accent.b,
			0.28
		)
		crest_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
		centerpiece_crest.add_child(crest_left)

		var centerpiece_label:= Label.new()
		centerpiece_label.text = (
			"◇  PRIVATE MARKET CENTERPIECE  ◇"
		)
		centerpiece_label.add_theme_font_size_override(
			"font_size",
			10
		)
		centerpiece_label.add_theme_color_override(
			"font_color",
			Color(
				accent.r,
				accent.g,
				accent.b,
				0.82
			)
		)
		centerpiece_crest.add_child(
			centerpiece_label
		)

		var crest_right:= ColorRect.new()
		crest_right.custom_minimum_size = Vector2(0, 1)
		crest_right.size_flags_horizontal = (
			Control.SIZE_EXPAND_FILL
		)
		crest_right.color = Color(
			accent.r,
			accent.g,
			accent.b,
			0.28
		)
		crest_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
		centerpiece_crest.add_child(crest_right)

	var classification:= Label.new()
	classification.text = str(
		card_contract.get(
			"classification_display",
			"AVAILABLE"
		)
	)
	classification.add_theme_font_size_override(
		"font_size",
		12 if is_centerpiece else 10
	)
	classification.add_theme_color_override(
		"font_color",
		accent
	)
	root.add_child(classification)

	var sweep: ColorRect = null
	var ask_label:= Label.new()

	if is_centerpiece:
		var title:= Label.new()
		title.text = str(
			card_contract.get(
				"title",
				"Exceptional Object"
			)
		)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.add_theme_font_size_override(
			"font_size",
			_card_title_font_size(span)
		)
		title.add_theme_color_override(
			"font_color",
			Color(
				0.985,
				0.978,
				0.95,
				1.0
			)
		)
		root.add_child(title)

		var house:= Label.new()
		house.text = (
			"%s • %s"
			% [
				str(
					card_contract.get(
						"house",
						"Private Exchange"
					)
				),
				str(
					card_contract.get(
						"item_type",
						"Luxury Object"
					)
				)
			]
		)
		house.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		house.add_theme_font_size_override(
			"font_size",
			11
		)
		house.add_theme_color_override(
			"font_color",
			Color(
				0.74,
				0.74,
				0.71,
				0.9
			)
		)
		root.add_child(house)

		var visual_stage:= PanelContainer.new()
		visual_stage.custom_minimum_size = Vector2(
			0,
			_visual_height_for_span(span)
		)
		visual_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
		visual_stage.clip_contents = true
		visual_stage.add_theme_stylebox_override(
			"panel",
			_visual_stage_style(card_contract)
		)
		root.add_child(visual_stage)

		var visual_center:= CenterContainer.new()
		visual_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		visual_stage.add_child(visual_center)

		var aperture:= PanelContainer.new()
		aperture.name = "LuxuryCenterpieceAperture"
		aperture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		aperture.custom_minimum_size = (
			_luxury_aperture_size(
				presentation_class,
				true
			)
		)
		aperture.add_theme_stylebox_override(
			"panel",
			_luxury_aperture_style(
				card_contract,
				presentation_class,
				true
			)
		)
		visual_center.add_child(aperture)

		var aperture_center:= CenterContainer.new()
		aperture_center.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)
		aperture.add_child(aperture_center)

		var visual_mark:= Label.new()
		visual_mark.text = str(
			card_contract.get(
				"visual_mark",
				"◆"
			)
		)
		visual_mark.add_theme_font_size_override(
			"font_size",
			46
		)
		visual_mark.add_theme_color_override(
			"font_color",
			Color(
				accent.r,
				accent.g,
				accent.b,
				0.88
			)
		)
		aperture_center.add_child(visual_mark)

		var visual_overlay:= Control.new()
		visual_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		visual_overlay.set_anchors_and_offsets_preset(
			Control.PRESET_FULL_RECT
		)
		visual_stage.add_child(visual_overlay)

		sweep = ColorRect.new()
		sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sweep.color = Color(
			accent.r,
			accent.g,
			accent.b,
			0.11
		)
		sweep.set_anchors_preset(
			Control.PRESET_LEFT_WIDE
		)
		sweep.offset_left = -46.0
		sweep.offset_right = -18.0
		sweep.offset_top = 0.0
		sweep.offset_bottom = 0.0
		visual_overlay.add_child(sweep)

		var value_label:= Label.new()
		value_label.text = (
			"MARKET VALUE • %s"
			% str(
				card_contract.get(
					"market_value_text",
					"$0"
				)
			)
		)
		value_label.add_theme_font_size_override(
			"font_size",
			11
		)
		value_label.add_theme_color_override(
			"font_color",
			Color(
				0.76,
				0.75,
				0.7,
				0.84
			)
		)
		root.add_child(value_label)

		ask_label.text = str(
			card_contract.get(
				"dealer_ask_text",
				"$0"
			)
		)
		ask_label.add_theme_font_size_override(
			"font_size",
			29
		)
		ask_label.add_theme_color_override(
			"font_color",
			Color(
				0.985,
				0.95,
				0.825,
				1.0
			)
		)
		ask_label.modulate.a = 0.0
		root.add_child(ask_label)

		var pressure_label: String = str(
			card_contract.get(
				"market_pressure_label",
				"→ STEADY"
			)
		)

		var market_line:= Label.new()
		market_line.text = (
			"%s • %s • %s"
			% [
				str(
					card_contract.get(
						"condition_text",
						""
					)
				),
				str(
					card_contract.get(
						"provenance_status",
						"Documented"
					)
				),
				pressure_label
			]
		)
		market_line.autowrap_mode = (
			TextServer.AUTOWRAP_WORD_SMART
		)
		market_line.add_theme_font_size_override(
			"font_size",
			10
		)
		market_line.add_theme_color_override(
			"font_color",
			_market_pressure_color(
				pressure_label,
				accent
			)
		)
		root.add_child(market_line)

		var rarity:= Label.new()
		rarity.text = str(
			card_contract.get(
				"rarity_text",
				"Circulating luxury"
			)
		)
		rarity.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rarity.add_theme_font_size_override(
			"font_size",
			10
		)
		rarity.add_theme_color_override(
			"font_color",
			Color(
				accent.r,
				accent.g,
				accent.b,
				0.68
			)
		)
		root.add_child(rarity)
	else:
		var piece_header:= HBoxContainer.new()
		piece_header.size_flags_horizontal = (
			Control.SIZE_EXPAND_FILL
		)
		piece_header.add_theme_constant_override(
			"separation",
			7
		)
		root.add_child(piece_header)

		var aperture:= PanelContainer.new()
		aperture.name = "LuxurySatelliteAperture"
		aperture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		aperture.custom_minimum_size = (
			_luxury_aperture_size(
				presentation_class,
				false
			)
		)
		aperture.add_theme_stylebox_override(
			"panel",
			_luxury_aperture_style(
				card_contract,
				presentation_class,
				false
			)
		)
		piece_header.add_child(aperture)

		var aperture_center:= CenterContainer.new()
		aperture_center.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)
		aperture.add_child(aperture_center)

		var visual_mark:= Label.new()
		visual_mark.text = str(
			card_contract.get(
				"visual_mark",
				"◆"
			)
		)
		visual_mark.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_CENTER
		)
		visual_mark.vertical_alignment = (
			VERTICAL_ALIGNMENT_CENTER
		)
		visual_mark.add_theme_font_size_override(
			"font_size",
			24
		)
		visual_mark.add_theme_color_override(
			"font_color",
			Color(
				accent.r,
				accent.g,
				accent.b,
				0.84
			)
		)
		aperture_center.add_child(visual_mark)

		var piece_stack:= VBoxContainer.new()
		piece_stack.size_flags_horizontal = (
			Control.SIZE_EXPAND_FILL
		)
		piece_stack.add_theme_constant_override(
			"separation",
			1
		)
		piece_header.add_child(piece_stack)

		var title:= Label.new()
		title.text = str(
			card_contract.get(
				"title",
				"Exceptional Object"
			)
		)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.add_theme_font_size_override(
			"font_size",
			_card_title_font_size(span)
		)
		title.add_theme_color_override(
			"font_color",
			Color(
				0.985,
				0.978,
				0.95,
				1.0
			)
		)
		piece_stack.add_child(title)

		var house:= Label.new()
		house.text = str(
			card_contract.get(
				"house",
				"Private Exchange"
			)
		)
		house.text_overrun_behavior = (
			TextServer.OVERRUN_TRIM_ELLIPSIS
		)
		house.add_theme_font_size_override(
			"font_size",
			9
		)
		house.add_theme_color_override(
			"font_color",
			Color(
				0.7,
				0.7,
				0.68,
				0.82
			)
		)
		piece_stack.add_child(house)

		ask_label.text = str(
			card_contract.get(
				"dealer_ask_text",
				"$0"
			)
		)
		ask_label.add_theme_font_size_override(
			"font_size",
			17
		)
		ask_label.add_theme_color_override(
			"font_color",
			Color(
				0.985,
				0.95,
				0.825,
				1.0
			)
		)
		ask_label.modulate.a = 0.0
		root.add_child(ask_label)

		var orbit_meta:= Label.new()
		orbit_meta.text = (
			"%s • %s"
			% [
				str(
					card_contract.get(
						"item_type",
						"Luxury Object"
					)
				),
				str(
					card_contract.get(
						"condition_text",
						""
					)
				)
			]
		)
		orbit_meta.text_overrun_behavior = (
			TextServer.OVERRUN_TRIM_ELLIPSIS
		)
		orbit_meta.add_theme_font_size_override(
			"font_size",
			9
		)
		orbit_meta.add_theme_color_override(
			"font_color",
			Color(
				accent.r,
				accent.g,
				accent.b,
				0.64
			)
		)
		root.add_child(orbit_meta)

	var spacer:= Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(spacer)

	var acquire_button:= Button.new()
	acquire_button.text = (
		str(
			card_contract.get(
				"acquisition_label",
				"REQUEST ACQUISITION"
			)
		)
		if is_centerpiece
		else "REQUEST"
	)
	acquire_button.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	acquire_button.custom_minimum_size = Vector2(
		0,
		34 if is_centerpiece else 26
	)
	acquire_button.disabled = bool(
		card_contract.get(
			"acquisition_disabled",
			false
		)
	)
	acquire_button.tooltip_text = str(
		card_contract.get(
			"acquisition_disabled_reason",
			""
		)
	)
	acquire_button.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND
	)
	acquire_button.add_theme_font_size_override(
		"font_size",
		11 if is_centerpiece else 9
	)
	acquire_button.add_theme_color_override(
		"font_color",
		accent
	)
	acquire_button.add_theme_color_override(
		"font_hover_color",
		Color(
			1.0,
			0.985,
			0.94,
			1.0
		)
	)
	acquire_button.pressed.connect(
		func ():
			acquisition_requested.emit(
				card_contract.duplicate(false)
			)
	)
	root.add_child(acquire_button)

	fx_entries.append({
		"card": weakref(card),
		"sweep": (
			weakref(sweep)
			if sweep != null
			else null
		),
		"accent_line": weakref(accent_line),
		"ask_label": weakref(ask_label),
		"classification": classification_id,
		"centerpiece": is_centerpiece,
		"publication_index": publication_index,
		"reveal_started_ms": -1,
		"reveal_complete": false,
		"phase_offset": (
			float(publication_index % 9)
			* 0.091
		)
	})

	return card
func _process(
	delta: float
) -> void:
	if not visible:
		if int(
			get_meta(
				"luxury_hover_focus_card_id",
				-1
			)
		) >= 0:
			_clear_luxury_hover_focus()

		return




	if bool(
		get_meta(
			"luxury_exchange_scroll_center_pending",
			false
		)
	):
		var formation_scroll:= find_child(
			"LuxuryFormationScroll",
			true,
			false
		) as ScrollContainer

		if (
			formation_scroll != null
			and card_flow != null
			and is_instance_valid(card_flow)
			and formation_scroll.size.x > 64.0
			and formation_scroll.size.y > 64.0
			and card_flow.size.x > 64.0
			and card_flow.size.y > 64.0
		):
			formation_scroll.scroll_horizontal = maxi(
				0,
				int(
					round(
						(
							card_flow.size.x
							- formation_scroll.size.x
						) * 0.5
					)
				)
			)
			formation_scroll.scroll_vertical = maxi(
				0,
				int(
					round(
						(
							card_flow.size.y
							- formation_scroll.size.y
						) * 0.5
					)
				)
			)
			set_meta(
				"luxury_exchange_scroll_center_pending",
				false
			)



	if bool(
		get_meta(
			"luxury_hover_release_pending",
			false
		)
	):
		var focus_instance_id: int = int(
			get_meta(
				"luxury_hover_focus_card_id",
				-1
			)
		)
		var focused_card: Control = null

		for raw_card in card_controls:
			var candidate_card: Control = raw_card as Control

			if (
				candidate_card == null
				or not is_instance_valid(candidate_card)
			):
				continue

			if int(
				candidate_card.get_instance_id()
			) == focus_instance_id:
				focused_card = candidate_card
				break

		if (
			focused_card == null
			or not _luxury_hover_pointer_remains_engaged(
				focused_card
			)
		):
			_clear_luxury_hover_focus()

	fx_time += delta



	_drive_luxury_orrery_rail_fx()
	_drive_luxury_scrollbar_fx(
		delta
	)




	var orbit_phase_advanced: bool = false

	if (
		card_flow != null
		and is_instance_valid(card_flow)
		and not bool(
			card_flow.get_meta(
				"luxury_orbit_paused",
				false
			)
		)
	):
		var inner_duration: float = maxf(
			1.0,
			float(
				card_flow.get_meta(
					"luxury_inner_ring_duration_seconds",
					72.0
				)
			)
		)
		var outer_duration: float = maxf(
			1.0,
			float(
				card_flow.get_meta(
					"luxury_outer_ring_duration_seconds",
					96.0
				)
			)
		)
		var inner_direction: float = float(
			int(
				card_flow.get_meta(
					"luxury_inner_ring_direction",
					1
				)
			)
		)
		var outer_direction: float = float(
			int(
				card_flow.get_meta(
					"luxury_outer_ring_direction",
					-1
				)
			)
		)
		var inner_phase: float = float(
			card_flow.get_meta(
				"luxury_inner_ring_phase",
				0.0
			)
		)
		var outer_phase: float = float(
			card_flow.get_meta(
				"luxury_outer_ring_phase",
				0.0
			)
		)

		inner_phase = fposmod(
			inner_phase
			+ TAU
			* delta
			/ inner_duration
			* inner_direction,
			TAU
		)
		outer_phase = fposmod(
			outer_phase
			+ TAU
			* delta
			/ outer_duration
			* outer_direction,
			TAU
		)

		card_flow.set_meta(
			"luxury_inner_ring_phase",
			inner_phase
		)
		card_flow.set_meta(
			"luxury_outer_ring_phase",
			outer_phase
		)
		orbit_phase_advanced = true

	if orbit_phase_advanced:
		for raw_card in card_controls:
			var orbit_card: Control = raw_card as Control

			if (
				orbit_card == null
				or not is_instance_valid(orbit_card)
				or not orbit_card.visible
			):
				continue

			var orbit_contract: Dictionary = _safe_dictionary(
				orbit_card.get_meta(
					"luxury_card_contract",
					{}
				)
			)

			if bool(
				orbit_contract.get(
					"centerpiece",
					false
				)
			):
				continue

			_place_luxury_orbital_card(
				orbit_card,
				orbit_contract
			)

	var now_ms: int = int(
		Time.get_ticks_msec()
	)
	var serviced: int = 0

	while serviced < FX_BATCH_SIZE:
		if fx_cursor >= fx_entries.size():
			fx_cursor = 0
			break

		var raw_entry: Variant = fx_entries [fx_cursor]
		fx_cursor += 1
		serviced += 1

		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue

		var entry: Dictionary = raw_entry as Dictionary
		var card_ref: Variant = entry.get(
			"card",
			null
		)

		if not (card_ref is WeakRef):
			continue

		var card_raw: Variant = (
			(card_ref as WeakRef).get_ref()
		)

		if not (card_raw is PanelContainer):
			continue

		var card: PanelContainer = (
			card_raw as PanelContainer
		)

		if not card.visible:
			continue

		var classification: String = str(
			entry.get(
				"classification",
				"AVAILABLE"
			)
		).strip_edges().to_upper()
		var is_centerpiece: bool = bool(
			entry.get(
				"centerpiece",
				false
			)
		)
		var rare_motion: bool = (
			classification in [
				"COLLECTOR",
				"EXCEPTIONAL",
				"ONE OF ONE",
				"HISTORIC",
				"ARTIFACT"
			]
			or classification.begins_with(
				"ARTIFACT_"
			)
		)

		var reveal_started_ms: int = int(
			entry.get(
				"reveal_started_ms",
				-1
			)
		)

		if reveal_started_ms < 0:
			reveal_started_ms = now_ms
			entry ["reveal_started_ms"] = reveal_started_ms
			card.modulate.a = 0.0
			card.scale = Vector2.ONE

		var reveal_age_ms: int = maxi(
			0,
			now_ms - reveal_started_ms
		)
		var reveal_t: float = clampf(
			float(reveal_age_ms)
			/ (
				430.0
				if is_centerpiece
				else 320.0
			),
			0.0,
			1.0
		)
		var reveal_eased: float = (
			reveal_t
			* reveal_t
			* (
				3.0
				- 2.0 * reveal_t
			)
		)
		var focus_dimmed: bool = bool(
			card.get_meta(
				"luxury_focus_dimmed",
				false
			)
		)

		card.modulate.a = (
			reveal_eased
			* (
				0.16
				if focus_dimmed
				else 1.0
			)
		)

		var phase_offset: float = float(
			entry.get(
				"phase_offset",
				0.0
			)
		)
		var breath: float = (
			0.5
			+ 0.5
			* sin(
				(
					fx_time
					+ phase_offset
				) * 1.35
			)
		)

		if reveal_t >= 1.0:
			entry ["reveal_complete"] = true




		card.scale = Vector2.ONE

		var ask_ref: Variant = entry.get(
			"ask_label",
			null
		)

		if ask_ref is WeakRef:
			var ask_raw: Variant = (
				(ask_ref as WeakRef).get_ref()
			)

			if ask_raw is Label:
				var ask_label: Label = ask_raw as Label
				var price_t: float = clampf(
					float(
						maxi(
							0,
							reveal_age_ms - 90
						)
					) / 330.0,
					0.0,
					1.0
				)
				var price_eased: float = (
					price_t
					* price_t
					* (
						3.0
						- 2.0 * price_t
					)
				)

				ask_label.modulate.a = price_eased

		var accent_ref: Variant = entry.get(
			"accent_line",
			null
		)

		if accent_ref is WeakRef:
			var accent_raw: Variant = (
				(accent_ref as WeakRef).get_ref()
			)

			if accent_raw is ColorRect:
				var accent_line: ColorRect = (
					accent_raw as ColorRect
				)
				accent_line.modulate.a = (
					lerpf(
						0.24,
						(
							0.72
							if rare_motion
							else 0.46
						),
						breath
					)
					* reveal_eased
				)

		var sweep_ref: Variant = entry.get(
			"sweep",
			null
		)

		if sweep_ref is WeakRef:
			var sweep_raw: Variant = (
				(sweep_ref as WeakRef).get_ref()
			)

			if sweep_raw is ColorRect:
				var sweep: ColorRect = (
					sweep_raw as ColorRect
				)
				var sweep_parent: Control = (
					sweep.get_parent()
					as Control
				)

				if (
					sweep_parent != null
					and is_instance_valid(
						sweep_parent
					)
				):
					var sweep_phase: float = fmod(
						fx_time
						* (
							0.06
							if is_centerpiece
							else 0.048
						)
						+ phase_offset,
						1.0
					)

					sweep.position.x = lerpf(
						-52.0,
						maxf(
							64.0,
							sweep_parent.size.x
							+ 52.0
						),
						sweep_phase
					)
					sweep.modulate.a = lerpf(
						0.18,
						0.62,
						reveal_eased
					)

	set_meta(
		"luxury_fx_last_batch_size",
		serviced
	)
	set_meta(
		"luxury_fx_batch_limit",
		FX_BATCH_SIZE
	)
	set_meta(
		"luxury_fx_simulation_truth_read",
		false
	)
	set_meta(
		"luxury_fx_engine_calls",
		false
	)
	set_meta(
		"luxury_fx_contract_rebuilds",
		false
	)
	set_meta(
		"luxury_fx_deferred_waits",
		false
	)
	set_meta(
		"luxury_orbit_individual_tweens",
		false
	)
	set_meta(
		"luxury_orbit_shared_ring_clocks",
		true
	)
	set_meta(
		"luxury_fx_mutates_card_dimensions",
		false
	)
func _card_size_for_span(
	span: String
) -> Vector2:
	match str(span).strip_edges().to_lower():
		"hero_2x2":
			return Vector2(410, 348)

		"landscape_2x1":
			return Vector2(216, 152)

		"portrait_1x2":
			return Vector2(144, 178)

		_:
			return Vector2(164, 162)
func _visual_height_for_span(
	span: String
) -> float:
	match str(span).strip_edges().to_lower():
		"hero_2x2":
			return 104.0

		"landscape_2x1":
			return 72.0

		"portrait_1x2":
			return 82.0

		_:
			return 68.0


func _card_title_font_size(
	span: String
) -> int:
	match str(span).strip_edges().to_lower():
		"hero_2x2":
			return 28

		"landscape_2x1":
			return 14

		"portrait_1x2":
			return 13

		_:
			return 13
func _luxury_rest_scale_for_contract(
	_card_contract: Dictionary,
	_composition_scale: float
) -> float:








	return 1.0
func _luxury_card_visual_scale_for_publication(
	formation_scale: float
) -> float:
	var resolved_formation_scale: float = clampf(
		formation_scale,
		0.8,
		1.1
	)

	if (
		card_flow == null
		or not is_instance_valid(card_flow)
	):
		return resolved_formation_scale

	var market_year: int = int(
		active_contract.get(
			"market_year",
			0
		)
	)
	var stream_active: bool = bool(
		get_meta(
			"luxury_exchange_stream_active",
			false
		)
	)
	var has_visual_scale: bool = (
		card_flow.has_meta(
			"luxury_card_visual_scale"
		)
	)
	var has_visual_year: bool = (
		card_flow.has_meta(
			"luxury_card_visual_scale_market_year"
		)
	)
	var previous_market_year: int = int(
		card_flow.get_meta(
			"luxury_card_visual_scale_market_year",
			market_year
		)
	)




	if (
		has_visual_scale
		and has_visual_year
		and previous_market_year != market_year
	):
		var carried_visual_scale: float = clampf(
			float(
				card_flow.get_meta(
					"luxury_card_visual_scale",
					resolved_formation_scale
				)
			),
			0.8,
			1.1
		)

		card_flow.set_meta(
			"luxury_card_visual_scale_market_year",
			market_year
		)
		card_flow.set_meta(
			"luxury_card_visual_scale_source",
			"successor_year_carry_forward"
		)
		card_flow.set_meta(
			"luxury_card_visual_scale_decoupled_from_orbit_geometry",
			true
		)
		card_flow.set_meta(
			"luxury_card_visual_scale_successor_mutated_old_contract",
			false
		)

		return carried_visual_scale




	if (
		stream_active
		and has_visual_scale
	):
		var resident_visual_scale: float = clampf(
			float(
				card_flow.get_meta(
					"luxury_card_visual_scale",
					resolved_formation_scale
				)
			),
			0.8,
			1.1
		)

		card_flow.set_meta(
			"luxury_card_visual_scale_market_year",
			market_year
		)
		card_flow.set_meta(
			"luxury_card_visual_scale_source",
			"resident_publication_carry_forward"
		)
		card_flow.set_meta(
			"luxury_card_visual_scale_decoupled_from_orbit_geometry",
			true
		)

		return resident_visual_scale




	card_flow.set_meta(
		"luxury_card_visual_scale",
		resolved_formation_scale
	)
	card_flow.set_meta(
		"luxury_card_visual_scale_market_year",
		market_year
	)
	card_flow.set_meta(
		"luxury_card_visual_scale_source",
		"live_viewport_geometry"
	)
	card_flow.set_meta(
		"luxury_card_visual_scale_decoupled_from_orbit_geometry",
		true
	)

	return resolved_formation_scale
func _luxury_ellipse_polyline(
	center: Vector2,
	radii: Vector2,
	segment_count: int = 160
) -> PackedVector2Array:
	var points:= PackedVector2Array()
	var safe_segment_count: int = maxi(
		48,
		segment_count
	)

	for index in range(
		safe_segment_count + 1
	):
		var angle: float = (
			TAU
			* float(index)
			/ float(safe_segment_count)
		)

		points.append(
			Vector2(
				center.x
				+ cos(angle) * radii.x,
				center.y
				+ sin(angle) * radii.y
			)
		)

	return points
func _luxury_ellipse_segment_polyline(
	center: Vector2,
	radii: Vector2,
	head_angle: float,
	arc_span: float,
	segment_count: int = 18
) -> PackedVector2Array:
	var points:= PackedVector2Array()
	var safe_segment_count: int = maxi(
		4,
		segment_count
	)

	for index in range(
		safe_segment_count + 1
	):
		var t: float = (
			float(index)
			/ float(safe_segment_count)
		)
		var angle: float = (
			head_angle
			- arc_span
			+ arc_span * t
		)

		points.append(
			Vector2(
				center.x
				+ cos(angle) * radii.x,
				center.y
				+ sin(angle) * radii.y
			)
		)

	return points


func _luxury_orrery_marker_layer() -> Control:
	if (
		card_flow == null
		or not is_instance_valid(card_flow)
	):
		return null

	var existing:= card_flow.get_node_or_null(
		"LuxuryRailMarkerLayer"
	) as Control

	if existing != null:
		return existing

	var layer:= Control.new()
	layer.name = "LuxuryRailMarkerLayer"
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	layer.z_index = 6
	layer.set_meta(
		"luxury_persistent_presentation_node",
		true
	)
	layer.set_meta(
		"luxury_presentation_only",
		true
	)
	layer.set_meta(
		"luxury_simulation_truth_read",
		false
	)

	card_flow.add_child(layer)
	card_flow.move_child(
		layer,
		0
	)

	return layer


func _refresh_luxury_orrery_markers(
	center: Vector2,
	inner_radii: Vector2,
	outer_radii: Vector2,
	composition_scale: float
) -> void:
	var layer: Control = (
		_luxury_orrery_marker_layer()
	)

	if layer == null:
		return

	var inner_color: Color = (
		_classification_color(
			"EXCEPTIONAL"
		)
	)
	var outer_color: Color = (
		_classification_color(
			"ARTIFACT"
		)
	)

	for ring_spec in [
		{
			"id": "Inner",
			"count": 12,
			"radii": inner_radii,
			"color": inner_color
		},
		{
			"id": "Outer",
			"count": 16,
			"radii": outer_radii,
			"color": outer_color
		}
	]:
		var ring_id: String = str(
			ring_spec.get(
				"id",
				"Ring"
			)
		)
		var marker_count: int = maxi(
			1,
			int(
				ring_spec.get(
					"count",
					8
				)
			)
		)
		var radii: Vector2 = ring_spec.get(
			"radii",
			Vector2.ONE
		)
		var color: Color = ring_spec.get(
			"color",
			Color.WHITE
		)

		for index in range(marker_count):
			var marker_name: String = (
				"Luxury%sRailMarker%02d"
				% [
					ring_id,
					index
				]
			)
			var marker:= layer.get_node_or_null(
				marker_name
			) as ColorRect

			if marker == null:
				marker = ColorRect.new()
				marker.name = marker_name
				marker.mouse_filter = (
					Control.MOUSE_FILTER_IGNORE
				)
				layer.add_child(marker)

			var angle: float = (
				- PI * 0.5
				+ TAU
				* float(index)
				/ float(marker_count)
			)
			var significant_node: bool = (
				index % 4 == 0
			)
			var marker_size: Vector2 = (
				Vector2(4.0, 4.0)
				* composition_scale
				if significant_node
				else Vector2(7.0, 1.0)
				* composition_scale
			)
			var marker_position:= Vector2(
				center.x
				+ cos(angle) * radii.x,
				center.y
				+ sin(angle) * radii.y
			)

			marker.size = marker_size
			marker.pivot_offset = (
				marker_size * 0.5
			)
			marker.position = (
				marker_position
				- marker_size * 0.5
			)
			marker.rotation = (
				PI * 0.25
				if significant_node
				else angle + PI * 0.5
			)
			marker.color = Color(
				color.r,
				color.g,
				color.b,
				0.34
				if significant_node
				else 0.2
			)

	layer.set_meta(
		"luxury_marker_geometry_is_presentation_only",
		true
	)


func _update_luxury_focus_arc() -> void:
	if (
		card_flow == null
		or not is_instance_valid(card_flow)
	):
		return

	var composition_scale: float = clampf(
		float(
			card_flow.get_meta(
				"luxury_composition_scale",
				1.0
			)
		),
		0.8,
		1.1
	)
	var focus_core:= card_flow.get_node_or_null(
		"LuxuryFocusArcGuide"
	) as Line2D
	var focus_bloom:= card_flow.get_node_or_null(
		"LuxuryFocusArcBloomGuide"
	) as Line2D

	if focus_core == null:
		focus_core = _luxury_orrery_guide(
			"LuxuryFocusArcGuide",
			Color(
				1.0,
				1.0,
				1.0,
				0.0
			),
			1.85 * composition_scale,
			8
		)

		if focus_core != null:
			focus_core.visible = false

	if focus_bloom == null:
		focus_bloom = _luxury_orrery_guide(
			"LuxuryFocusArcBloomGuide",
			Color(
				1.0,
				1.0,
				1.0,
				0.0
			),
			6.4 * composition_scale,
			7
		)

		if focus_bloom != null:
			focus_bloom.visible = false

	if (
		focus_core == null
		or focus_bloom == null
	):
		return

	var focus_instance_id: int = int(
		get_meta(
			"luxury_hover_focus_card_id",
			-1
		)
	)

	if focus_instance_id < 0:
		focus_core.visible = false
		focus_bloom.visible = false
		return

	var focused_card: Control = null

	for raw_card in card_controls:
		var candidate: Control = raw_card as Control

		if (
			candidate == null
			or not is_instance_valid(candidate)
			or not candidate.visible
		):
			continue

		if int(
			candidate.get_instance_id()
		) == focus_instance_id:
			focused_card = candidate
			break

	if focused_card == null:
		focus_core.visible = false
		focus_bloom.visible = false
		return

	var card_contract: Dictionary = _safe_dictionary(
		focused_card.get_meta(
			"luxury_card_contract",
			{}
		)
	)



	if bool(
		card_contract.get(
			"centerpiece",
			false
		)
	):
		focus_core.visible = false
		focus_bloom.visible = false
		return

	var angle: float = float(
		focused_card.get_meta(
			"luxury_orbit_angle",
			0.0
		)
	)
	var radii: Vector2 = focused_card.get_meta(
		"luxury_orbit_radii",
		Vector2.ZERO
	)

	if radii == Vector2.ZERO:
		focus_core.visible = false
		focus_bloom.visible = false
		return

	var classification: String = str(
		card_contract.get(
			"classification",
			"AVAILABLE"
		)
	).strip_edges().to_upper()
	var accent: Color = _classification_color(
		classification
	)
	var center: Vector2 = card_flow.size * 0.5




	var points: PackedVector2Array = (
		_luxury_ellipse_segment_polyline(
			center,
			radii,
			angle - deg_to_rad(9.0),
			deg_to_rad(18.0),
			18
		)
	)
	var pulse: float = (
		0.72
		+ 0.28
		* (
			0.5
			+ 0.5
			* sin(
				fx_time * 4.8
			)
		)
	)

	focus_bloom.points = points
	focus_bloom.default_color = Color(
		accent.r,
		accent.g,
		accent.b,
		0.18
	)
	focus_bloom.modulate = Color(
		1.0,
		1.0,
		1.0,
		pulse
	)
	focus_bloom.visible = true

	focus_core.points = points
	focus_core.default_color = Color(
		accent.r,
		accent.g,
		accent.b,
		0.82
	)
	focus_core.modulate = Color(
		1.0,
		1.0,
		1.0,
		pulse
	)
	focus_core.visible = true

	set_meta(
		"luxury_focus_arc_is_presentation_only",
		true
	)
	set_meta(
		"luxury_focus_arc_engine_calls",
		false
	)
func _luxury_orrery_guide(
	guide_name: String,
	guide_color: Color,
	guide_width: float,
	guide_z_index: int
) -> Line2D:
	if (
		card_flow == null
		or not is_instance_valid(card_flow)
	):
		return null

	var safe_width: float = maxf(
		0.5,
		guide_width
	)
	var existing_guide:= card_flow.get_node_or_null(
		guide_name
	) as Line2D

	if existing_guide != null:
		existing_guide.default_color = guide_color
		existing_guide.width = safe_width
		existing_guide.z_index = guide_z_index
		existing_guide.modulate = Color.WHITE
		existing_guide.set_meta(
			"luxury_guide_base_width",
			safe_width
		)
		existing_guide.set_meta(
			"luxury_guide_base_alpha",
			guide_color.a
		)

		return existing_guide

	var guide:= Line2D.new()
	guide.name = guide_name
	guide.default_color = guide_color
	guide.width = safe_width
	guide.antialiased = true
	guide.z_index = guide_z_index
	guide.set_meta(
		"luxury_persistent_presentation_node",
		true
	)
	guide.set_meta(
		"luxury_presentation_only",
		true
	)
	guide.set_meta(
		"luxury_simulation_truth_read",
		false
	)
	guide.set_meta(
		"luxury_guide_base_width",
		safe_width
	)
	guide.set_meta(
		"luxury_guide_base_alpha",
		guide_color.a
	)

	card_flow.add_child(
		guide
	)
	card_flow.move_child(
		guide,
		0
	)

	return guide
func _drive_luxury_orrery_guide_pulse(
	guide_name: String,
	speed: float,
	phase_offset: float,
	minimum_alpha_multiplier: float
) -> void:
	if (
		card_flow == null
		or not is_instance_valid(card_flow)
	):
		return

	var guide:= card_flow.get_node_or_null(
		guide_name
	) as Line2D

	if guide == null:
		return

	var base_width: float = maxf(
		0.5,
		float(
			guide.get_meta(
				"luxury_guide_base_width",
				guide.width
			)
		)
	)
	var pulse: float = (
		0.5
		+ 0.5
		* sin(
			fx_time * speed
			+ phase_offset
		)
	)
	var micro_pulse: float = (
		0.5
		+ 0.5
		* sin(
			fx_time
			* (
				speed * 2.17
				+ 0.11
			)
			+ phase_offset * 1.71
			+ 0.63
		)
	)

	var guide_band: String = "centerpiece"

	if guide_name.find("InnerOrbit") >= 0:
		guide_band = "inner_orbit"
	elif guide_name.find("OuterOrbit") >= 0:
		guide_band = "outer_orbit"

	var focus_active: bool = bool(
		card_flow.get_meta(
			"luxury_rail_focus_active",
			false
		)
	)
	var focus_band: String = str(
		card_flow.get_meta(
			"luxury_rail_focus_band",
			""
		)
	).strip_edges().to_lower()
	var rail_dim_alpha: float = clampf(
		float(
			card_flow.get_meta(
				"luxury_rail_dim_alpha_multiplier",
				1.0
			)
		),
		0.0,
		1.0
	)

	var width_multiplier: float = 1.0
	var alpha_focus_multiplier: float = 1.0

	if focus_active:
		if focus_band == guide_band:
			width_multiplier = 1.18
			alpha_focus_multiplier = 1.0
		else:
			width_multiplier = 0.94
			alpha_focus_multiplier = rail_dim_alpha

	guide.width = (
		base_width
		* lerpf(
			0.965,
			1.055,
			pulse
		)
		* lerpf(
			0.992,
			1.008,
			micro_pulse
		)
		* width_multiplier
	)

	var alpha_multiplier: float = (
		lerpf(
			clampf(
				minimum_alpha_multiplier,
				0.0,
				1.0
			),
			1.0,
			pulse
		)
		* lerpf(
			0.965,
			1.0,
			micro_pulse
		)
	)

	guide.modulate = Color(
		1.0,
		1.0,
		1.0,
		alpha_multiplier * alpha_focus_multiplier
	)

	guide.set_meta(
		"luxury_rail_motion_layers",
		2
	)
	guide.set_meta(
		"luxury_rail_micro_motion_is_presentation_only",
		true
	)
func _drive_luxury_orrery_rail_fx() -> void:
	if (
		card_flow == null
		or not is_instance_valid(card_flow)
	):
		return

	var layout_contract: Dictionary = (
		_luxury_layout_contract()
	)
	var focus_active: bool = bool(
		card_flow.get_meta(
			"luxury_rail_focus_active",
			false
		)
	)
	var focus_band: String = str(
		card_flow.get_meta(
			"luxury_rail_focus_band",
			""
		)
	).strip_edges().to_lower()
	var dim_alpha: float = clampf(
		float(
			card_flow.get_meta(
				"luxury_rail_dim_alpha_multiplier",
				1.0
			)
		),
		0.0,
		1.0
	)



	var target_speed_multiplier: float = 1.0

	if focus_active:
		var focus_speed_key: String = (
			"centerpiece_focus_speed_multiplier"
			if focus_band == "centerpiece"
			else "hover_focus_speed_multiplier"
		)
		target_speed_multiplier = clampf(
			float(
				layout_contract.get(
					focus_speed_key,
					0.58
					if focus_band == "centerpiece"
					else 0.34
				)
			),
			0.1,
			1.0
		)

	var current_speed_multiplier: float = clampf(
		float(
			card_flow.get_meta(
				"luxury_orbit_speed_multiplier",
				1.0
			)
		),
		0.1,
		1.0
	)
	var motion_delta: float = maxf(
		0.0,
		get_process_delta_time()
	)
	var speed_ease_weight: float = clampf(
		1.0 - exp(
			- motion_delta * 6.5
		),
		0.0,
		1.0
	)

	current_speed_multiplier = lerpf(
		current_speed_multiplier,
		target_speed_multiplier,
		speed_ease_weight
	)

	card_flow.set_meta(
		"luxury_orbit_speed_multiplier",
		current_speed_multiplier
	)
	card_flow.set_meta(
		"luxury_orbit_speed_target_multiplier",
		target_speed_multiplier
	)





	if (
		focus_active
		and bool(
			card_flow.get_meta(
				"luxury_orbit_paused",
				false
			)
		)
		and str(
			card_flow.get_meta(
				"luxury_orbit_pause_reason",
				""
			)
		) == "satellite_hover"
	):
		card_flow.set_meta(
			"luxury_orbit_paused",
			false
		)
		card_flow.set_meta(
			"luxury_orbit_pause_reason",
			"focus_speed_eased"
		)

	var ring_motion: Dictionary = _safe_dictionary(
		layout_contract.get(
			"ring_motion",
			{}
		)
	)
	var inner_motion: Dictionary = _safe_dictionary(
		ring_motion.get(
			"inner_orbit",
			{}
		)
	)
	var outer_motion: Dictionary = _safe_dictionary(
		ring_motion.get(
			"outer_orbit",
			{}
		)
	)
	var base_inner_duration: float = maxf(
		1.0,
		float(
			inner_motion.get(
				"duration_seconds",
				72.0
			)
		)
	)
	var base_outer_duration: float = maxf(
		1.0,
		float(
			outer_motion.get(
				"duration_seconds",
				96.0
			)
		)
	)
	var safe_speed_multiplier: float = maxf(
		0.1,
		current_speed_multiplier
	)

	card_flow.set_meta(
		"luxury_inner_ring_duration_seconds",
		base_inner_duration
		/ safe_speed_multiplier
	)
	card_flow.set_meta(
		"luxury_outer_ring_duration_seconds",
		base_outer_duration
		/ safe_speed_multiplier
	)


	_drive_luxury_orrery_guide_pulse(
		"LuxuryCenterpieceHaloGuide",
		0.62,
		0.0,
		0.72
	)
	_drive_luxury_orrery_guide_pulse(
		"LuxuryInnerOrbitGlowGuide",
		0.41,
		0.32,
		0.24
	)
	_drive_luxury_orrery_guide_pulse(
		"LuxuryInnerOrbitGuide",
		0.47,
		0.85,
		0.68
	)
	_drive_luxury_orrery_guide_pulse(
		"LuxuryInnerOrbitEchoGuide",
		0.37,
		2.1,
		0.48
	)
	_drive_luxury_orrery_guide_pulse(
		"LuxuryOuterOrbitGlowGuide",
		0.28,
		0.55,
		0.22
	)
	_drive_luxury_orrery_guide_pulse(
		"LuxuryOuterOrbitGuide",
		0.31,
		1.45,
		0.64
	)
	_drive_luxury_orrery_guide_pulse(
		"LuxuryOuterOrbitEchoGuide",
		0.27,
		3.0,
		0.44
	)

	for idx in range(12):
		var node:= card_flow.get_node_or_null(
			"LuxuryInnerOrbitNode%d" % idx
		) as ColorRect

		if node == null:
			continue

		var alpha: float = lerpf(
			0.24,
			0.48,
			0.5 + 0.5 * sin(
				fx_time * 0.82
				+ float(idx) * 0.44
			)
		)

		if focus_active and focus_band != "inner_orbit":
			alpha *= dim_alpha

		node.modulate = Color(
			1.0,
			1.0,
			1.0,
			alpha
		)

	for idx in range(16):
		var node:= card_flow.get_node_or_null(
			"LuxuryOuterOrbitNode%d" % idx
		) as ColorRect

		if node == null:
			continue

		var alpha: float = lerpf(
			0.2,
			0.42,
			0.5 + 0.5 * sin(
				fx_time * 0.61
				+ float(idx) * 0.38
			)
		)

		if focus_active and focus_band != "outer_orbit":
			alpha *= dim_alpha

		node.modulate = Color(
			1.0,
			1.0,
			1.0,
			alpha
		)

	_update_luxury_traveling_highlights()
	_update_luxury_focus_arc()
	_drive_luxury_hover_projection_motion()

	set_meta(
		"luxury_orrery_rail_fx_engine_calls",
		false
	)
	set_meta(
		"luxury_orrery_rail_fx_truth_reads",
		false
	)
	set_meta(
		"luxury_orrery_rail_fx_resident_contract_only",
		true
	)
func _update_luxury_traveling_highlights() -> void:
	if (
		card_flow == null
		or not is_instance_valid(card_flow)
	):
		return

	var inner_radii: Vector2 = card_flow.get_meta(
		"luxury_inner_ring_radii",
		Vector2.ZERO
	)
	var outer_radii: Vector2 = card_flow.get_meta(
		"luxury_outer_ring_radii",
		Vector2.ZERO
	)

	if (
		inner_radii == Vector2.ZERO
		or outer_radii == Vector2.ZERO
	):
		return

	var composition_scale: float = clampf(
		float(
			card_flow.get_meta(
				"luxury_composition_scale",
				1.0
			)
		),
		0.8,
		1.1
	)
	var center: Vector2 = card_flow.size * 0.5
	var inner_color: Color = _classification_color(
		"EXCEPTIONAL"
	)
	var outer_color: Color = _classification_color(
		"ARTIFACT"
	)

	var inner_travel:= card_flow.get_node_or_null(
		"LuxuryInnerOrbitTravelGuide"
	) as Line2D
	var outer_travel:= card_flow.get_node_or_null(
		"LuxuryOuterOrbitTravelGuide"
	) as Line2D

	if inner_travel == null:
		inner_travel = _luxury_orrery_guide(
			"LuxuryInnerOrbitTravelGuide",
			Color(
				inner_color.r,
				inner_color.g,
				inner_color.b,
				0.34
			),
			2.1 * composition_scale,
			7
		)

	if outer_travel == null:
		outer_travel = _luxury_orrery_guide(
			"LuxuryOuterOrbitTravelGuide",
			Color(
				outer_color.r,
				outer_color.g,
				outer_color.b,
				0.3
			),
			1.95 * composition_scale,
			7
		)

	if (
		inner_travel == null
		or outer_travel == null
	):
		return

	var inner_direction: float = float(
		int(
			card_flow.get_meta(
				"luxury_inner_ring_direction",
				1
			)
		)
	)
	var outer_direction: float = float(
		int(
			card_flow.get_meta(
				"luxury_outer_ring_direction",
				-1
			)
		)
	)
	var inner_angle: float = fposmod(
		- PI * 0.5
		+ fx_time * 0.22 * inner_direction,
		TAU
	)
	var outer_angle: float = fposmod(
		PI * 0.5
		+ fx_time * 0.17 * outer_direction,
		TAU
	)

	inner_travel.points = (
		_luxury_ellipse_segment_polyline(
			center,
			inner_radii,
			inner_angle - deg_to_rad(3.5),
			deg_to_rad(7.0),
			12
		)
	)
	outer_travel.points = (
		_luxury_ellipse_segment_polyline(
			center,
			outer_radii,
			outer_angle - deg_to_rad(3.0),
			deg_to_rad(6.0),
			12
		)
	)

	var focus_active: bool = bool(
		card_flow.get_meta(
			"luxury_rail_focus_active",
			false
		)
	)
	var focus_band: String = str(
		card_flow.get_meta(
			"luxury_rail_focus_band",
			""
		)
	).strip_edges().to_lower()
	var rail_dim_alpha: float = clampf(
		float(
			card_flow.get_meta(
				"luxury_rail_dim_alpha_multiplier",
				0.4
			)
		),
		0.0,
		1.0
	)
	var travel_pulse: float = (
		0.76
		+ 0.24
		* (
			0.5
			+ 0.5
			* sin(
				fx_time * 1.35
			)
		)
	)
	var inner_alpha_multiplier: float = 1.0
	var outer_alpha_multiplier: float = 1.0

	if focus_active:
		if focus_band != "inner_orbit":
			inner_alpha_multiplier *= rail_dim_alpha

		if focus_band != "outer_orbit":
			outer_alpha_multiplier *= rail_dim_alpha

	inner_travel.default_color = Color(
		inner_color.r,
		inner_color.g,
		inner_color.b,
		0.34
	)
	inner_travel.modulate = Color(
		1.0,
		1.0,
		1.0,
		travel_pulse
		* inner_alpha_multiplier
	)

	outer_travel.default_color = Color(
		outer_color.r,
		outer_color.g,
		outer_color.b,
		0.3
	)
	outer_travel.modulate = Color(
		1.0,
		1.0,
		1.0,
		travel_pulse
		* outer_alpha_multiplier
	)

	set_meta(
		"luxury_directional_travel_is_presentation_only",
		true
	)
	set_meta(
		"luxury_directional_travel_engine_calls",
		false
	)


func _set_luxury_scrollbar_alpha(
	scroll_bar: ScrollBar,
	alpha: float
) -> void:
	if scroll_bar == null:
		return

	var clean_alpha: float = clampf(
		alpha,
		0.0,
		1.0
	)

	scroll_bar.modulate = Color(
		1.0,
		1.0,
		1.0,
		clean_alpha
	)


func _drive_luxury_scrollbar_fx(
	delta: float
) -> void:
	if (
		card_flow == null
		or not is_instance_valid(card_flow)
	):
		return

	var formation_scroll:= card_flow.get_parent() as ScrollContainer

	if formation_scroll == null:
		return

	var horizontal_bar: ScrollBar = (
		formation_scroll.get_h_scroll_bar()
	)
	var vertical_bar: ScrollBar = (
		formation_scroll.get_v_scroll_bar()
	)
	var current_horizontal: int = (
		formation_scroll.scroll_horizontal
	)
	var current_vertical: int = (
		formation_scroll.scroll_vertical
	)

	if not has_meta(
		"luxury_scrollbar_fx_initialized"
	):
		set_meta(
			"luxury_scrollbar_fx_initialized",
			true
		)
		set_meta(
			"luxury_scrollbar_last_horizontal",
			current_horizontal
		)
		set_meta(
			"luxury_scrollbar_last_vertical",
			current_vertical
		)
		set_meta(
			"luxury_scrollbar_hold_seconds",
			0.0
		)
		set_meta(
			"luxury_scrollbar_alpha",
			0.0
		)

		_set_luxury_scrollbar_alpha(
			horizontal_bar,
			0.0
		)
		_set_luxury_scrollbar_alpha(
			vertical_bar,
			0.0
		)
		return

	var previous_horizontal: int = int(
		get_meta(
			"luxury_scrollbar_last_horizontal",
			current_horizontal
		)
	)
	var previous_vertical: int = int(
		get_meta(
			"luxury_scrollbar_last_vertical",
			current_vertical
		)
	)
	var moved: bool = (
		current_horizontal != previous_horizontal
		or current_vertical != previous_vertical
	)
	var hold_seconds: float = maxf(
		0.0,
		float(
			get_meta(
				"luxury_scrollbar_hold_seconds",
				0.0
			)
		)
	)

	if moved:
		hold_seconds = 0.16
	else:
		hold_seconds = maxf(
			0.0,
			hold_seconds - delta
		)

	var target_alpha: float = (
		1.0
		if (
			moved
			or hold_seconds > 0.0
		)
		else 0.0
	)
	var current_alpha: float = clampf(
		float(
			get_meta(
				"luxury_scrollbar_alpha",
				0.0
			)
		),
		0.0,
		1.0
	)
	var alpha_speed: float = (
		12.0
		if target_alpha > current_alpha
		else 2.8
	)
	var next_alpha: float = move_toward(
		current_alpha,
		target_alpha,
		delta * alpha_speed
	)

	_set_luxury_scrollbar_alpha(
		horizontal_bar,
		next_alpha
	)
	_set_luxury_scrollbar_alpha(
		vertical_bar,
		next_alpha
	)

	set_meta(
		"luxury_scrollbar_last_horizontal",
		current_horizontal
	)
	set_meta(
		"luxury_scrollbar_last_vertical",
		current_vertical
	)
	set_meta(
		"luxury_scrollbar_hold_seconds",
		hold_seconds
	)
	set_meta(
		"luxury_scrollbar_alpha",
		next_alpha
	)
	set_meta(
		"luxury_scrollbar_visibility_is_presentation_only",
		true
	)
func _refresh_luxury_orrery_guides(
	stage_size: Vector2,
	inner_radii: Vector2,
	outer_radii: Vector2,
	composition_scale: float
) -> void:
	if (
		card_flow == null
		or not is_instance_valid(card_flow)
	):
		return

	var center: Vector2 = stage_size * 0.5



	var hero_visual_size: Vector2 = (
		_card_size_for_span(
			"hero_2x2"
		)
	)
	var centerpiece_halo_radii: Vector2 = (
		hero_visual_size * 0.5
		+ Vector2(
			30.0,
			26.0
		)
	)

	var centerpiece_color:= Color(
		0.97,
		0.81,
		0.43,
		0.34
	)
	var inner_color: Color = _classification_color(
		"EXCEPTIONAL"
	)
	var inner_glow_color: Color = inner_color
	var inner_echo_color: Color = inner_color
	var outer_color: Color = _classification_color(
		"ARTIFACT"
	)
	var outer_glow_color: Color = outer_color
	var outer_echo_color: Color = outer_color

	inner_color.a = 0.38
	inner_glow_color.a = 0.12
	inner_echo_color.a = 0.15
	outer_color.a = 0.34
	outer_glow_color.a = 0.11
	outer_echo_color.a = 0.14

	var centerpiece_guide: Line2D = _luxury_orrery_guide(
		"LuxuryCenterpieceHaloGuide",
		centerpiece_color,
		2.05 * composition_scale,
		4
	)
	var inner_glow_guide: Line2D = _luxury_orrery_guide(
		"LuxuryInnerOrbitGlowGuide",
		inner_glow_color,
		5.2 * composition_scale,
		2
	)
	var inner_guide: Line2D = _luxury_orrery_guide(
		"LuxuryInnerOrbitGuide",
		inner_color,
		2.05 * composition_scale,
		5
	)
	var inner_echo_guide: Line2D = _luxury_orrery_guide(
		"LuxuryInnerOrbitEchoGuide",
		inner_echo_color,
		1.05 * composition_scale,
		3
	)
	var outer_glow_guide: Line2D = _luxury_orrery_guide(
		"LuxuryOuterOrbitGlowGuide",
		outer_glow_color,
		5.0 * composition_scale,
		2
	)
	var outer_guide: Line2D = _luxury_orrery_guide(
		"LuxuryOuterOrbitGuide",
		outer_color,
		1.95 * composition_scale,
		5
	)
	var outer_echo_guide: Line2D = _luxury_orrery_guide(
		"LuxuryOuterOrbitEchoGuide",
		outer_echo_color,
		1.0 * composition_scale,
		3
	)

	if centerpiece_guide != null:
		centerpiece_guide.points = _luxury_ellipse_polyline(
			center,
			centerpiece_halo_radii,
			128
		)

	if inner_glow_guide != null:
		inner_glow_guide.points = _luxury_ellipse_polyline(
			center,
			inner_radii,
			176
		)

	if inner_guide != null:
		inner_guide.points = _luxury_ellipse_polyline(
			center,
			inner_radii,
			176
		)

	if inner_echo_guide != null:
		inner_echo_guide.points = _luxury_ellipse_polyline(
			center,
			inner_radii
			+ Vector2(
				13.0,
				11.0
			) * composition_scale,
			176
		)

	if outer_glow_guide != null:
		outer_glow_guide.points = _luxury_ellipse_polyline(
			center,
			outer_radii,
			208
		)

	if outer_guide != null:
		outer_guide.points = _luxury_ellipse_polyline(
			center,
			outer_radii,
			208
		)

	if outer_echo_guide != null:
		outer_echo_guide.points = _luxury_ellipse_polyline(
			center,
			outer_radii
			- Vector2(
				15.0,
				13.0
			) * composition_scale,
			208
		)

	for idx in range(12):
		var node_name: String = "LuxuryInnerOrbitNode%d" % idx
		var node:= card_flow.get_node_or_null(
			node_name
		) as ColorRect

		if node == null:
			node = ColorRect.new()
			node.name = node_name
			node.mouse_filter = Control.MOUSE_FILTER_IGNORE
			node.z_index = 6
			node.rotation = PI * 0.25
			node.set_meta(
				"luxury_persistent_presentation_node",
				true
			)
			card_flow.add_child(node)
			card_flow.move_child(
				node,
				0
			)

		var node_angle: float = (
			- PI * 0.5
			+ TAU * float(idx) / 12.0
		)
		var node_point:= Vector2(
			center.x + cos(node_angle) * inner_radii.x,
			center.y + sin(node_angle) * inner_radii.y
		)
		var node_size: Vector2 = Vector2.ONE * (
			(
				7.0
				if idx % 3 == 0
				else 5.0
			)
			* composition_scale
		)

		node.custom_minimum_size = node_size
		node.size = node_size
		node.position = node_point - node_size * 0.5
		node.color = Color(
			inner_color.r,
			inner_color.g,
			inner_color.b,
			(
				0.52
				if idx % 3 == 0
				else 0.34
			)
		)

	for idx in range(16):
		var node_name: String = "LuxuryOuterOrbitNode%d" % idx
		var node:= card_flow.get_node_or_null(
			node_name
		) as ColorRect

		if node == null:
			node = ColorRect.new()
			node.name = node_name
			node.mouse_filter = Control.MOUSE_FILTER_IGNORE
			node.z_index = 6
			node.rotation = PI * 0.25
			node.set_meta(
				"luxury_persistent_presentation_node",
				true
			)
			card_flow.add_child(node)
			card_flow.move_child(
				node,
				0
			)

		var node_angle: float = (
			- PI * 0.5
			+ TAU * float(idx) / 16.0
		)
		var node_point:= Vector2(
			center.x + cos(node_angle) * outer_radii.x,
			center.y + sin(node_angle) * outer_radii.y
		)
		var node_size: Vector2 = Vector2.ONE * (
			(
				6.0
				if idx % 4 == 0
				else 4.0
			)
			* composition_scale
		)

		node.custom_minimum_size = node_size
		node.size = node_size
		node.position = node_point - node_size * 0.5
		node.color = Color(
			outer_color.r,
			outer_color.g,
			outer_color.b,
			(
				0.48
				if idx % 4 == 0
				else 0.3
			)
		)

	card_flow.set_meta(
		"luxury_orrery_guides_visible",
		true
	)
	card_flow.set_meta(
		"luxury_orrery_guides_are_presentation_only",
		true
	)
	card_flow.set_meta(
		"luxury_orrery_guide_truth_queries",
		false
	)
	card_flow.set_meta(
		"luxury_orrery_guides_richened_without_layout_ownership",
		true
	)
func _layout_luxury_orbital_formation() -> void:
	if (
		card_flow == null
		or not is_instance_valid(card_flow)
	):
		return

	var stage_size: Vector2 = card_flow.size

	if stage_size.x < 64.0:
		stage_size.x = maxf(
			1800.0,
			card_flow.custom_minimum_size.x
		)

	if stage_size.y < 64.0:
		stage_size.y = maxf(
			1660.0,
			card_flow.custom_minimum_size.y
		)





	var viewport_size: Vector2 = Vector2(
		1280.0,
		900.0
	)
	var formation_scroll:= (
		card_flow.get_parent() as ScrollContainer
	)

	if (
		formation_scroll != null
		and formation_scroll.size.x > 64.0
		and formation_scroll.size.y > 64.0
	):
		viewport_size = formation_scroll.size




	var composition_scale: float = clampf(
		minf(
			viewport_size.x / 1490.0,
			viewport_size.y / 1050.0
		),
		0.92,
		1.0
	)
	var inner_radii:= Vector2(
		470.0,
		430.0
	) * composition_scale
	var outer_radii:= Vector2(
		760.0,
		710.0
	) * composition_scale

	card_flow.set_meta(
		"luxury_composition_scale",
		composition_scale
	)
	card_flow.set_meta(
		"luxury_card_visual_scale_resolved",
		1.0
	)
	card_flow.set_meta(
		"luxury_inner_ring_radii",
		inner_radii
	)
	card_flow.set_meta(
		"luxury_outer_ring_radii",
		outer_radii
	)
	card_flow.set_meta(
		"luxury_centerpiece_exclusion_gap",
		52.0 * composition_scale
	)
	card_flow.set_meta(
		"luxury_inter_ring_clearance",
		30.0 * composition_scale
	)
	card_flow.set_meta(
		"luxury_ring_geometry_shared",
		true
	)
	card_flow.set_meta(
		"luxury_individual_card_radii",
		false
	)
	card_flow.set_meta(
		"luxury_geometry_capacity",
		"hero_1_inner_10_outer_16"
	)
	card_flow.set_meta(
		"luxury_collision_envelope_reserved_for_hover",
		true
	)
	card_flow.set_meta(
		"luxury_frozen_hierarchy",
		"centerpiece_inner_outer"
	)
	card_flow.set_meta(
		"luxury_card_dimensions_follow_live_orbit_geometry",
		false
	)
	card_flow.set_meta(
		"luxury_card_dimension_scale",
		1.0
	)
	card_flow.set_meta(
		"luxury_orbit_geometry_can_resize_cards",
		false
	)
	card_flow.set_meta(
		"luxury_orbit_zones_have_explicit_breathing_room",
		true
	)
	card_flow.set_meta(
		"luxury_centerpiece_zone_is_exclusive",
		true
	)
	card_flow.set_meta(
		"luxury_composition_scale_source",
		"visible_scroll_viewport_not_content_canvas"
	)




	_refresh_luxury_orrery_guides(
		stage_size,
		inner_radii,
		outer_radii,
		composition_scale
	)

	for raw_card in card_controls:
		var card: Control = raw_card as Control

		if (
			card == null
			or not is_instance_valid(card)
		):
			continue

		var card_contract: Dictionary = _safe_dictionary(
			card.get_meta(
				"luxury_card_contract",
				{}
			)
		)
		var fixed_size: Vector2 = (
			_luxury_fixed_card_size_for_contract(
				card_contract
			)
		)

		card.custom_minimum_size = fixed_size
		card.size = fixed_size
		card.pivot_offset = fixed_size * 0.5
		card.scale = Vector2.ONE

		card.set_meta(
			"luxury_fixed_card_size",
			fixed_size
		)
		card.set_meta(
			"luxury_rest_scale",
			1.0
		)

		_place_luxury_orbital_card(
			card,
			card_contract
		)
func _place_luxury_orbital_card(
	card: Control,
	card_contract: Dictionary
) -> void:
	if (
		card == null
		or not is_instance_valid(card)
		or card_flow == null
		or not is_instance_valid(card_flow)
	):
		return

	var stage_size: Vector2 = card_flow.size

	if stage_size.x < 64.0:
		stage_size.x = maxf(
			1800.0,
			card_flow.custom_minimum_size.x
		)

	if stage_size.y < 64.0:
		stage_size.y = maxf(
			1660.0,
			card_flow.custom_minimum_size.y
		)

	if not card_flow.has_meta(
		"luxury_inner_ring_radii"
	):
		_layout_luxury_orbital_formation()
		return

	var formation_scale: float = clampf(
		float(
			card_flow.get_meta(
				"luxury_composition_scale",
				0.92
			)
		),
		0.92,
		1.0
	)




	if card_flow.get_node_or_null(
		"LuxuryInnerOrbitGuide"
	) == null:
		_layout_luxury_orbital_formation()
		return

	var center: Vector2 = stage_size * 0.5
	var is_centerpiece: bool = bool(
		card_contract.get(
			"centerpiece",
			false
		)
	)

	if is_centerpiece:
		card.position = center - card.size * 0.5
		card.set_meta(
			"luxury_base_z_index",
			240
		)
		card.set_meta(
			"luxury_nominal_depth_tier",
			4
		)
		card.z_index = (
			950
			if bool(
				card.get_meta(
					"luxury_hovered",
					false
				)
			)
			else 240
		)
		card.set_meta(
			"luxury_orbit_radii",
			Vector2.ZERO
		)
		card.set_meta(
			"luxury_orbit_angle",
			0.0
		)
		card.set_meta(
			"luxury_ring_clock_owner",
			"stationary_centerpiece"
		)

		_update_luxury_card_mount_geometry(
			card,
			center,
			center,
			true
		)
		return





	if bool(
		card.get_meta(
			"luxury_orbit_binding_resident",
			false
		)
	):
		var resident_band: String = str(
			card.get_meta(
				"luxury_orbit_band",
				"inner_orbit"
			)
		).strip_edges().to_lower()
		var resident_base_angle: float = float(
			card.get_meta(
				"luxury_orbit_base_angle",
				0.0
			)
		)
		var resident_orbit_enabled: bool = bool(
			card.get_meta(
				"luxury_orbit_enabled",
				true
			)
		)
		var resident_phase: float = 0.0
		var resident_radii: Vector2 = card_flow.get_meta(
			"luxury_inner_ring_radii",
			Vector2(
				470.0,
				430.0
			) * formation_scale
		)

		if resident_band == "outer_orbit":
			resident_radii = card_flow.get_meta(
				"luxury_outer_ring_radii",
				Vector2(
					760.0,
					710.0
				) * formation_scale
			)

			if resident_orbit_enabled:
				resident_phase = float(
					card_flow.get_meta(
						"luxury_outer_ring_phase",
						0.0
					)
				)
		elif resident_orbit_enabled:
			resident_phase = float(
				card_flow.get_meta(
					"luxury_inner_ring_phase",
					0.0
				)
			)

		var resident_angle: float = (
			resident_base_angle
			+ resident_phase
		)
		var resident_orbit_center:= Vector2(
			center.x
			+ cos(
				resident_angle
			) * resident_radii.x,
			center.y
			+ sin(
				resident_angle
			) * resident_radii.y
		)

		card.position = (
			resident_orbit_center
			- card.size * 0.5
		)
		card.set_meta(
			"luxury_orbit_radii",
			resident_radii
		)
		card.set_meta(
			"luxury_orbit_angle",
			resident_angle
		)

		_update_luxury_card_mount_geometry(
			card,
			center,
			resident_orbit_center,
			false
		)
		return

	var exceptional: bool = (
		_luxury_is_exceptional_presentation(
			card_contract
		)
	)

	if not card.has_meta(
		"luxury_rest_scale"
	):
		var card_visual_scale: float = (
			_luxury_card_visual_scale_for_publication(
				formation_scale
			)
		)
		var rest_scale: float = (
			_luxury_rest_scale_for_contract(
				card_contract,
				card_visual_scale
			)
		)

		card.scale *= rest_scale
		card.set_meta(
			"luxury_rest_scale",
			rest_scale
		)
		card.set_meta(
			"luxury_card_visual_scale_at_publication",
			card_visual_scale
		)

	var formation_band: String = str(
		card_contract.get(
			"formation_band",
			"inner_orbit"
		)
	).strip_edges().to_lower()
	var slot: int = int(
		card_contract.get(
			"formation_slot",
			maxi(
				0,
				int(
					card.get_meta(
						"luxury_publication_index",
						1
					)
				) - 1
			)
		)
	)
	var slot_count: int = maxi(
		1,
		int(
			card_contract.get(
				"formation_slot_count",
				maxi(
					1,
					int(
						active_contract.get(
							"card_count",
							2
						)
					) - 1
				)
			)
		)
	)
	var phase_degrees: float = float(
		card_contract.get(
			"formation_phase_degrees",
			(
				-90.0
				+ 360.0
				* float(slot)
				/ float(slot_count)
			)
		)
	)
	var orbit_enabled: bool = bool(
		card_contract.get(
			"orbit_enabled",
			true
		)
	)
	var phase: float = 0.0
	var radii: Vector2 = card_flow.get_meta(
		"luxury_inner_ring_radii",
		Vector2(
			470.0,
			430.0
		) * formation_scale
	)
	var base_z: int = (
		148
		if exceptional
		else 132
	)

	if formation_band == "outer_orbit":
		if orbit_enabled:
			phase = float(
				card_flow.get_meta(
					"luxury_outer_ring_phase",
					0.0
				)
			)

		radii = card_flow.get_meta(
			"luxury_outer_ring_radii",
			Vector2(
				760.0,
				710.0
			) * formation_scale
		)
		base_z = (
			138
			if exceptional
			else 122
		)
	elif orbit_enabled:
		phase = float(
			card_flow.get_meta(
				"luxury_inner_ring_phase",
				0.0
			)
		)

	var base_angle: float = deg_to_rad(
		phase_degrees
	)
	var angle: float = (
		base_angle
		+ phase
	)
	var orbit_center:= Vector2(
		center.x
		+ cos(angle) * radii.x,
		center.y
		+ sin(angle) * radii.y
	)

	card.position = (
		orbit_center
		- card.size * 0.5
	)
	card.set_meta(
		"luxury_base_z_index",
		base_z
	)
	card.set_meta(
		"luxury_nominal_depth_tier",
		2 if exceptional else 1
	)
	card.z_index = (
		950
		if bool(
			card.get_meta(
				"luxury_hovered",
				false
			)
		)
		else base_z
	)
	card.set_meta(
		"luxury_orbit_radii",
		radii
	)
	card.set_meta(
		"luxury_orbit_angle",
		angle
	)
	card.set_meta(
		"luxury_ring_clock_owner",
		"shared_formation_phase"
	)




	card.set_meta(
		"luxury_orbit_band",
		formation_band
	)
	card.set_meta(
		"luxury_orbit_base_angle",
		base_angle
	)
	card.set_meta(
		"luxury_orbit_enabled",
		orbit_enabled
	)
	card.set_meta(
		"luxury_orbit_binding_resident",
		true
	)
	card.set_meta(
		"luxury_orbit_frame_contract_reparse",
		false
	)

	_update_luxury_card_mount_geometry(
		card,
		center,
		orbit_center,
		false
	)
func _luxury_hover_pointer_remains_engaged(
	focused_card: Control
) -> bool:
	if (
		focused_card == null
		or not is_instance_valid(focused_card)
	):
		return false

	var projection:= get_node_or_null(
		"LuxuryHoverOverlay/LuxuryHoverProjection"
	) as PanelContainer

	if (
		projection == null
		or not projection.visible
	):
		return false

	var mouse_position: Vector2 = get_global_mouse_position()
	var card_rect: Rect2 = focused_card.get_global_rect().grow(10.0)
	var projection_rect: Rect2 = projection.get_global_rect().grow(10.0)

	if card_rect.has_point(mouse_position):
		return true

	if projection_rect.has_point(mouse_position):
		return true




	var card_center: Vector2 = card_rect.get_center()
	var projection_center: Vector2 = projection_rect.get_center()
	var projection_is_right: bool = (
		projection_center.x >= card_center.x
	)
	var bridge_start:= Vector2(
		card_rect.end.x
		if projection_is_right
		else card_rect.position.x,
		card_center.y
	)
	var bridge_end:= Vector2(
		projection_rect.position.x
		if projection_is_right
		else projection_rect.end.x,
		projection_center.y
	)
	var segment: Vector2 = bridge_end - bridge_start
	var segment_length_squared: float = maxf(
		1.0,
		segment.length_squared()
	)
	var projection_t: float = clampf(
		(
			mouse_position - bridge_start
		).dot(segment) / segment_length_squared,
		0.0,
		1.0
	)
	var closest_point: Vector2 = (
		bridge_start
		+ segment * projection_t
	)

	return (
		mouse_position.distance_to(closest_point)
		<= 54.0
	)
func _apply_luxury_hover_focus(
	card: Control
) -> void:
	if (
		card == null
		or not is_instance_valid(
			card
		)
	):
		return

	if bool(
		get_meta(
			"luxury_extraordinary_projection_locked",
			false
		)
	):
		return





	if (
		formation_pan_active
		or formation_pan_hover_rearm_required
	):
		set_meta(
			"luxury_hover_suppressed_by_navigation",
			true
		)
		set_meta(
			"luxury_hover_suppressed_card_id",
			card.get_instance_id()
		)
		set_meta(
			"luxury_hover_suppression_engine_calls",
			false
		)
		return

	set_meta(
		"luxury_hover_suppressed_by_navigation",
		false
	)

	var card_contract: Dictionary = _safe_dictionary(
		card.get_meta(
			"luxury_card_contract",
			{}
		)
	)

	if (
		card_contract.is_empty()
		or not bool(
			card_contract.get(
				"hover_projection_enabled",
				true
			)
		)
	):
		return

	set_meta(
		"luxury_hover_focus_card_id",
		card.get_instance_id()
	)
	set_meta(
		"luxury_hover_release_pending",
		false
	)

	var is_centerpiece: bool = bool(
		card_contract.get(
			"centerpiece",
			false
		)
	)
	var focus_band: String = (
		"centerpiece"
		if is_centerpiece
		else str(
			card_contract.get(
				"formation_band",
				"inner_orbit"
			)
		).strip_edges().to_lower()
	)

	if is_centerpiece:
		var observation_contract: Dictionary = (
			_luxury_centerpiece_hover_observation_contract(
				card_contract
			)
		)

		if not observation_contract.is_empty():
			centerpiece_hover_observation_requested.emit(
				observation_contract
			)

	if (
		card_flow != null
		and is_instance_valid(card_flow)
	):
		card_flow.set_meta(
			"luxury_orbit_paused",
			not is_centerpiece
		)
		card_flow.set_meta(
			"luxury_orbit_pause_reason",
			(
				"satellite_hover"
				if not is_centerpiece
				else ""
			)
		)
		card_flow.set_meta(
			"luxury_rail_focus_active",
			true
		)
		card_flow.set_meta(
			"luxury_rail_focus_band",
			focus_band
		)
		card_flow.set_meta(
			"luxury_rail_dim_alpha_multiplier",
			0.4
		)

	for raw_card in card_controls:
		var other: Control = raw_card as Control

		if (
			other == null
			or not is_instance_valid(other)
		):
			continue

		var other_contract: Dictionary = _safe_dictionary(
			other.get_meta(
				"luxury_card_contract",
				{}
			)
		)
		var is_focus: bool = other == card

		other.set_meta(
			"luxury_hovered",
			is_focus
		)
		other.set_meta(
			"luxury_focus_dimmed",
			not is_focus
		)
		other.modulate.a = (
			1.0
			if is_focus
			else 0.4
		)



		other.scale = Vector2.ONE

		other.z_index = (
			950
			if is_focus
			else int(
				other.get_meta(
					"luxury_base_z_index",
					other.z_index
				)
			)
		)
		other.add_theme_stylebox_override(
			"panel",
			_card_style(
				other_contract,
				{
					"hovered": is_focus,
					"dimmed": not is_focus,
					"depth_tier": (
						3
						if is_focus
						else (
							4
							if bool(
								other_contract.get(
									"centerpiece",
									false
								)
							)
							else 1
						)
					),
					"ceremonial": bool(
						other_contract.get(
							"centerpiece",
							false
						)
					)
				}
			)
		)

	_populate_luxury_hover_projection(
		card_contract
	)
	_position_luxury_hover_projection(
		card
	)

	set_meta(
		"luxury_hover_projection_active",
		true
	)
	set_meta(
		"luxury_hover_projection_engine_calls",
		false
	)
	set_meta(
		"luxury_hover_projection_contract_rebuild",
		false
	)
	set_meta(
		"luxury_hover_projection_simulation_mutation",
		false
	)
	set_meta(
		"luxury_centerpiece_hover_engine_calls",
		false
	)
	set_meta(
		"luxury_hover_changes_resident_card_dimensions",
		false
	)
func _release_luxury_hover_focus(
	card: Control
) -> void:
	if (
		card == null
		or not is_instance_valid(card)
	):
		return

	if int(
		get_meta(
			"luxury_hover_focus_card_id",
			-1
		)
	) != int(
		card.get_instance_id()
	):
		return

	var card_contract: Dictionary = _safe_dictionary(
		card.get_meta(
			"luxury_card_contract",
			{}
		)
	)

	if bool(
		card_contract.get(
			"centerpiece",
			false
		)
	):
		var observation_contract: Dictionary = (
			_luxury_centerpiece_hover_observation_contract(
				card_contract
			)
		)

		if not observation_contract.is_empty():
			centerpiece_hover_release_requested.emit(
				observation_contract
			)




	set_meta(
		"luxury_hover_release_pending",
		true
	)
func _clear_luxury_hover_focus(
	force: bool = false
) -> void:
	if (
		not force
		and bool(
			get_meta(
				"luxury_extraordinary_projection_locked",
				false
			)
		)
	):
		return

	set_meta(
		"luxury_extraordinary_projection_locked",
		false
	)

	set_meta(
		"luxury_hover_focus_card_id",
		-1
	)
	set_meta(
		"luxury_hover_projection_active",
		false
	)
	set_meta(
		"luxury_hover_release_pending",
		false
	)

	if (
		card_flow != null
		and is_instance_valid(
			card_flow
		)
	):
		card_flow.set_meta(
			"luxury_orbit_paused",
			false
		)
		card_flow.set_meta(
			"luxury_orbit_pause_reason",
			""
		)
		card_flow.set_meta(
			"luxury_rail_focus_active",
			false
		)
		card_flow.set_meta(
			"luxury_rail_focus_band",
			""
		)
		card_flow.set_meta(
			"luxury_rail_dim_alpha_multiplier",
			1.0
		)

	for raw_card in card_controls:
		var card: Control = raw_card as Control

		if (
			card == null
			or not is_instance_valid(
				card
			)
		):
			continue

		var card_contract: Dictionary = _safe_dictionary(
			card.get_meta(
				"luxury_card_contract",
				{}
			)
		)

		card.set_meta(
			"luxury_hovered",
			false
		)
		card.set_meta(
			"luxury_focus_dimmed",
			false
		)
		card.modulate.a = 1.0
		card.scale = Vector2.ONE
		card.z_index = int(
			card.get_meta(
				"luxury_base_z_index",
				card.z_index
			)
		)
		card.add_theme_stylebox_override(
			"panel",
			_card_style(
				card_contract
			)
		)

	var projection:= get_node_or_null(
		"LuxuryHoverOverlay/LuxuryHoverProjection"
	) as PanelContainer

	if projection != null:
		projection.visible = false

		if projection.has_meta(
			"luxury_card_contract"
		):
			projection.remove_meta(
				"luxury_card_contract"
			)

	set_meta(
		"luxury_hover_release_changes_resident_card_dimensions",
		false
	)
func _populate_luxury_hover_projection(
	card_contract: Dictionary
) -> void:
	var projection:= get_node_or_null(
		"LuxuryHoverOverlay/LuxuryHoverProjection"
	) as PanelContainer

	if projection == null:
		return

	var accent: Color = _classification_color(
		str(
			card_contract.get(
				"classification",
				"AVAILABLE"
			)
		).strip_edges().to_upper()
	)

	projection.add_theme_stylebox_override(
		"panel",
		_card_style(
			card_contract,
			{
				"projection": true,
				"hovered": true,
				"depth_tier": 3,
				"ceremonial": bool(
					card_contract.get(
						"centerpiece",
						false
					)
				)
			}
		)
	)
	projection.set_meta(
		"luxury_card_contract",
		card_contract.duplicate(false)
	)

	var classification:= projection.get_node_or_null(
		"ProjectionMargin/ProjectionRoot/Classification"
	) as Label
	var title:= projection.get_node_or_null(
		"ProjectionMargin/ProjectionRoot/Title"
	) as Label
	var house:= projection.get_node_or_null(
		"ProjectionMargin/ProjectionRoot/House"
	) as Label
	var ask:= projection.get_node_or_null(
		"ProjectionMargin/ProjectionRoot/Ask"
	) as Label
	var market:= projection.get_node_or_null(
		"ProjectionMargin/ProjectionRoot/Market"
	) as Label
	var rarity:= projection.get_node_or_null(
		"ProjectionMargin/ProjectionRoot/Rarity"
	) as Label
	var history:= projection.get_node_or_null(
		"ProjectionMargin/ProjectionRoot/History"
	) as Label
	var provenance:= projection.get_node_or_null(
		"ProjectionMargin/ProjectionRoot/Provenance"
	) as Label
	var lore:= projection.get_node_or_null(
		"ProjectionMargin/ProjectionRoot/Lore"
	) as Label
	var acquire_button:= projection.get_node_or_null(
		"ProjectionMargin/ProjectionRoot/Acquire"
	) as Button

	if classification != null:
		classification.text = str(
			card_contract.get(
				"classification_display",
				"AVAILABLE"
			)
		)
		classification.add_theme_font_size_override(
			"font_size",
			11
		)
		classification.add_theme_color_override(
			"font_color",
			accent
		)

	if title != null:
		title.text = str(
			card_contract.get(
				"title",
				"Exceptional Object"
			)
		)
		title.add_theme_font_size_override(
			"font_size",
			21
		)
		title.add_theme_color_override(
			"font_color",
			Color(
				0.99,
				0.98,
				0.95,
				1.0
			)
		)

	if house != null:
		if card_contract.has(
			"house_text_override"
		):
			house.text = str(
				card_contract.get(
					"house_text_override",
					""
				)
			)
		else:
			house.text = (
				"%s • %s"
				% [
					str(
						card_contract.get(
							"house",
							"Private Exchange"
						)
					),
					str(
						card_contract.get(
							"item_type",
							"Luxury Object"
						)
					)
				]
			)
		house.add_theme_font_size_override(
			"font_size",
			11
		)
		house.add_theme_color_override(
			"font_color",
			Color(
				0.76,
				0.75,
				0.72,
				0.88
			)
		)

	if ask != null:
		if card_contract.has(
			"ask_text_override"
		):
			ask.text = str(
				card_contract.get(
					"ask_text_override",
					""
				)
			)
		else:
			ask.text = (
				"%s • MARKET %s"
				% [
					str(
						card_contract.get(
							"dealer_ask_text",
							"$0"
						)
					),
					str(
						card_contract.get(
							"market_value_text",
							"$0"
						)
					)
				]
			)
		ask.add_theme_font_size_override(
			"font_size",
			18
		)
		ask.add_theme_color_override(
			"font_color",
			Color(
				0.99,
				0.95,
				0.82,
				1.0
			)
		)

	if market != null:
		if card_contract.has(
			"market_text_override"
		):
			market.text = str(
				card_contract.get(
					"market_text_override",
					""
				)
			)
		else:
			market.text = (
				"%s • %s • %s"
				% [
					str(
						card_contract.get(
							"condition_text",
							""
						)
					),
					str(
						card_contract.get(
							"provenance_status",
							"Documented"
						)
					),
					str(
						card_contract.get(
							"market_pressure_label",
							"→ STEADY"
						)
					)
				]
			)
		market.add_theme_font_size_override(
			"font_size",
			10
		)
		market.add_theme_color_override(
			"font_color",
			Color(
				accent.r,
				accent.g,
				accent.b,
				0.78
			)
		)

	if rarity != null:
		rarity.text = str(
			card_contract.get(
				"rarity_text",
				"Circulating luxury"
			)
		)
		rarity.add_theme_font_size_override(
			"font_size",
			10
		)
		rarity.add_theme_color_override(
			"font_color",
			Color(
				accent.r,
				accent.g,
				accent.b,
				0.68
			)
		)

	if history != null:
		history.text = str(
			card_contract.get(
				"history_note",
				""
			)
		)
		history.add_theme_font_size_override(
			"font_size",
			11
		)
		history.add_theme_color_override(
			"font_color",
			Color(
				0.88,
				0.86,
				0.81,
				0.88
			)
		)

	if provenance != null:
		if card_contract.has(
			"provenance_text_override"
		):
			provenance.text = str(
				card_contract.get(
					"provenance_text_override",
					""
				)
			)
		else:
			provenance.text = (
				"Origin • %s\n"
				+ "Known owners • %s\n"
				+ "Last transfer • %s"
			) % [
				str(
					card_contract.get(
						"origin",
						"Private Market"
					)
				),
				str(
					card_contract.get(
						"known_owners",
						"—"
					)
				),
				str(
					card_contract.get(
						"last_transfer",
						"Private"
					)
				)
			]
		provenance.add_theme_font_size_override(
			"font_size",
			10
		)
		provenance.add_theme_color_override(
			"font_color",
			Color(
				0.75,
				0.74,
				0.71,
				0.82
			)
		)

	if lore != null:
		lore.text = str(
			card_contract.get(
				"lore",
				""
			)
		)
		lore.visible = (
			lore.text.strip_edges() != ""
		)
		lore.add_theme_font_size_override(
			"font_size",
			10
		)
		lore.add_theme_color_override(
			"font_color",
			Color(
				0.84,
				0.82,
				0.78,
				0.78
			)
		)

	if acquire_button != null:
		var acquisition_intent: Dictionary = _safe_dictionary(
			card_contract.get(
				"acquisition_intent",
				{}
			)
		)

		acquire_button.visible = not acquisition_intent.is_empty()
		acquire_button.text = str(
			card_contract.get(
				"acquisition_label",
				"REQUEST ACQUISITION"
			)
		)
		acquire_button.disabled = bool(
			card_contract.get(
				"acquisition_disabled",
				false
			)
		)
		acquire_button.tooltip_text = str(
			card_contract.get(
				"acquisition_disabled_reason",
				""
			)
		)
		acquire_button.add_theme_color_override(
			"font_color",
			accent
		)
		acquire_button.add_theme_color_override(
			"font_hover_color",
			Color(
				1.0,
				0.985,
				0.94,
				1.0
			)
		)
	var leave_button:= projection.get_node_or_null(
		"ProjectionMargin/ProjectionRoot/Leave"
	) as Button

	if leave_button != null:
		var leave_label: String = str(
			card_contract.get(
				"leave_label",
				""
			)
		).strip_edges()

		leave_button.visible = (
			leave_label != ""
		)
		leave_button.text = leave_label

	set_meta(
		"luxury_extraordinary_projection_locked",
		bool(
			card_contract.get(
				"lock_hover_projection",
				false
			)
		)
	)
	projection.modulate = Color(
		1.0,
		1.0,
		1.0,
		0.985
	)
	projection.visible = true
func _position_luxury_hover_projection(
	hovered_card: Control
) -> void:
	var overlay:= get_node_or_null(
		"LuxuryHoverOverlay"
	) as Control
	var projection:= get_node_or_null(
		"LuxuryHoverOverlay/LuxuryHoverProjection"
	) as PanelContainer

	if (
		overlay == null
		or projection == null
		or hovered_card == null
		or not is_instance_valid(hovered_card)
	):
		return

	var overlay_size: Vector2 = overlay.size

	if overlay_size.x < 64.0:
		overlay_size = size

	projection.size = (
		projection.custom_minimum_size
	)
	projection.pivot_offset = (
		projection.size * 0.5
	)

	var panel_rect: Rect2 = get_global_rect()
	var hovered_rect: Rect2 = (
		hovered_card.get_global_rect()
	)
	var hovered_left: float = (
		hovered_rect.position.x
		- panel_rect.position.x
	)
	var hovered_right: float = (
		hovered_rect.end.x
		- panel_rect.position.x
	)
	var hovered_center_x: float = (
		hovered_rect.get_center().x
		- panel_rect.position.x
	)
	var hovered_center_y: float = (
		hovered_rect.get_center().y
		- panel_rect.position.y
	)
	var edge_margin: float = 18.0
	var bridge_gap: float = 24.0
	var left_candidate: float = (
		hovered_left
		- projection.size.x
		- bridge_gap
	)
	var right_candidate: float = (
		hovered_right
		+ bridge_gap
	)
	var left_fits: bool = left_candidate >= edge_margin
	var right_fits: bool = (
		right_candidate
		+ projection.size.x
		<= overlay_size.x - edge_margin
	)
	var target_x: float = edge_margin

	if left_fits and right_fits:
		var left_distance: float = absf(
			left_candidate
			+ projection.size.x * 0.5
			- hovered_center_x
		)
		var right_distance: float = absf(
			right_candidate
			+ projection.size.x * 0.5
			- hovered_center_x
		)

		target_x = (
			left_candidate
			if left_distance <= right_distance
			else right_candidate
		)
	elif left_fits:
		target_x = left_candidate
	elif right_fits:
		target_x = right_candidate
	else:
		target_x = (
			edge_margin
			if hovered_center_x >= overlay_size.x * 0.5
			else maxf(
				edge_margin,
				overlay_size.x
				- projection.size.x
				- edge_margin
			)
		)

	var target_y: float = clampf(
		hovered_center_y
		- projection.size.y * 0.5,
		edge_margin,
		maxf(
			edge_margin,
			overlay_size.y
			- projection.size.y
			- edge_margin
		)
	)
	var target_position:= Vector2(
		target_x,
		target_y
	)
	var was_active: bool = bool(
		get_meta(
			"luxury_hover_projection_active",
			false
		)
	)

	projection.set_meta(
		"luxury_projection_target_position",
		target_position
	)




	if not was_active:
		var entry_direction: float = (
			-1.0
			if target_x < hovered_center_x
			else 1.0
		)

		projection.position = (
			target_position
			+ Vector2(
				22.0 * entry_direction,
				4.0
			)
		)
		projection.scale = Vector2(
			0.985,
			0.985
		)
		projection.modulate.a = 0.0

	set_meta(
		"luxury_projection_position_is_presentation_only",
		true
	)
func _drive_luxury_hover_projection_motion() -> void:
	if not bool(
		get_meta(
			"luxury_hover_projection_active",
			false
		)
	):
		return

	var projection:= get_node_or_null(
		"LuxuryHoverOverlay/LuxuryHoverProjection"
	) as PanelContainer

	if (
		projection == null
		or not projection.visible
		or not projection.has_meta(
			"luxury_projection_target_position"
		)
	):
		return

	var target_raw: Variant = projection.get_meta(
		"luxury_projection_target_position",
		projection.position
	)

	if typeof(target_raw) != TYPE_VECTOR2:
		return

	var target_position: Vector2 = target_raw
	var motion_delta: float = maxf(
		0.0,
		get_process_delta_time()
	)
	var position_weight: float = clampf(
		1.0 - exp(
			- motion_delta * 12.0
		),
		0.0,
		1.0
	)
	var alpha_weight: float = clampf(
		1.0 - exp(
			- motion_delta * 15.0
		),
		0.0,
		1.0
	)

	projection.position = projection.position.lerp(
		target_position,
		position_weight
	)
	projection.scale = projection.scale.lerp(
		Vector2.ONE,
		position_weight
	)
	projection.modulate.a = lerpf(
		projection.modulate.a,
		0.985,
		alpha_weight
	)

	if projection.position.distance_to(
		target_position
	) <= 0.25:
		projection.position = target_position

	if projection.scale.distance_to(
		Vector2.ONE
	) <= 0.001:
		projection.scale = Vector2.ONE

	set_meta(
		"luxury_projection_motion_engine_calls",
		false
	)
	set_meta(
		"luxury_projection_motion_contract_rebuild",
		false
	)
	set_meta(
		"luxury_projection_motion_simulation_mutation",
		false
	)
func _classification_color(
	classification: String
) -> Color:
	var clean: String = str(
		classification
	).strip_edges().to_upper()

	if clean.begins_with(
		"ARTIFACT_"
	):
		var artifact_color_key: String = clean.trim_prefix(
			"ARTIFACT_"
		)

		match artifact_color_key:
			"GREEN", "EMERALD":
				return Color(
					0.32,
					0.94,
					0.54,
					0.98
				)

			"BLUE", "SAPPHIRE":
				return Color(
					0.38,
					0.68,
					1.0,
					0.98
				)

			"RED", "CRIMSON":
				return Color(
					1.0,
					0.36,
					0.42,
					0.98
				)

			"YELLOW", "GOLD":
				return Color(
					1.0,
					0.86,
					0.34,
					0.98
				)

			"ORANGE":
				return Color(
					1.0,
					0.58,
					0.24,
					0.98
				)

			"VIOLET", "PURPLE":
				return Color(
					0.78,
					0.66,
					1.0,
					0.98
				)

			"SILVER":
				return Color(
					0.82,
					0.88,
					0.94,
					0.96
				)

			"WHITE":
				return Color(
					0.94,
					0.96,
					1.0,
					0.98
				)

			_:
				return Color(
					0.78,
					0.66,
					1.0,
					0.96
				)

	match clean:
		"ARTIFACT":
			return Color(
				0.78,
				0.66,
				1.0,
				0.96
			)

		"ONE OF ONE":
			return Color(
				0.9,
				0.82,
				1.0,
				0.98
			)

		"EXCEPTIONAL":
			return Color(
				0.98,
				0.84,
				0.54,
				0.96
			)

		"HISTORIC":
			return Color(
				0.84,
				0.64,
				0.38,
				0.94
			)

		"COLLECTOR":
			return Color(
				0.58,
				0.78,
				0.86,
				0.92
			)

		"LIMITED":
			return Color(
				0.88,
				0.8,
				0.62,
				0.9
			)

		_:
			return Color(
				0.74,
				0.78,
				0.8,
				0.84
			)
func _market_pressure_color(
	pressure_label: String,
	classification_accent: Color
) -> Color:
	var clean: String = str(
		pressure_label
	).strip_edges().to_upper()

	if clean.find(
		"HIGH"
	) >= 0:
		return Color(
			1.0,
			0.72,
			0.46,
			0.92
		)

	if clean.find(
		"ACTIVE"
	) >= 0:
		return Color(
			classification_accent.r,
			classification_accent.g,
			classification_accent.b,
			0.88
		)

	if clean.find(
		"SOFT"
	) >= 0:
		return Color(
			0.62,
			0.72,
			0.8,
			0.78
		)

	if clean.find(
		"QUIET"
	) >= 0:
		return Color(
			0.68,
			0.7,
			0.7,
			0.72
		)

	return Color(
		0.76,
		0.76,
		0.72,
		0.8
	)
func _luxury_return_button_style(
	state: String = "normal"
) -> StyleBoxFlat:
	var clean_state: String = str(
		state
	).strip_edges().to_lower()
	var accent:= Color(
		0.9,
		0.72,
		0.36,
		1.0
	)
	var style:= StyleBoxFlat.new()

	style.bg_color = Color(
		0.03,
		0.029,
		0.027,
		0.965
	)
	style.border_color = Color(
		accent.r,
		accent.g,
		accent.b,
		0.42
	)
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.shadow_color = Color(
		0.0,
		0.0,
		0.0,
		0.32
	)
	style.shadow_size = 5

	match clean_state:
		"hover":
			style.bg_color = style.bg_color.lerp(
				accent,
				0.06
			)
			style.border_color.a = 0.78
			style.shadow_color = Color(
				accent.r,
				accent.g,
				accent.b,
				0.13
			)
			style.shadow_size = 9

		"pressed":
			style.bg_color = style.bg_color.lerp(
				accent,
				0.035
			)
			style.border_color.a = 0.9
			style.shadow_color = Color(
				accent.r,
				accent.g,
				accent.b,
				0.08
			)
			style.shadow_size = 4

		"focus":
			style.border_color.a = 0.72
			style.shadow_color = Color(
				accent.r,
				accent.g,
				accent.b,
				0.1
			)
			style.shadow_size = 7

		_:
			pass

	style.set_content_margin(
		SIDE_LEFT,
		14.0
	)
	style.set_content_margin(
		SIDE_RIGHT,
		14.0
	)
	style.set_content_margin(
		SIDE_TOP,
		8.0
	)
	style.set_content_margin(
		SIDE_BOTTOM,
		8.0
	)

	return style
func _luxury_centerpiece_hover_observation_contract(
	card_contract: Dictionary
) -> Dictionary:
	if (
		card_contract.is_empty()
		or not bool(
			card_contract.get(
				"centerpiece",
				false
			)
		)
	):
		return {}

	return {
		"schema": (
			"eralife.luxury."
			+ "centerpiece_hover_observation"
		),
		"version": CONTRACT_VERSION,
		"actor_id": int(
			active_contract.get(
				"actor_id",
				-1
			)
		),
		"era_name": str(
			active_contract.get(
				"era",
				""
			)
		),
		"market_year": int(
			active_contract.get(
				"market_year",
				-999999
			)
		),
		"market_rotation_signature": int(
			active_contract.get(
				"market_rotation_signature",
				0
			)
		),
		"centerpiece_card_id": str(
			active_contract.get(
				"centerpiece_card_id",
				""
			)
		),
		"card_id": str(
			card_contract.get(
				"card_id",
				""
			)
		),
		"centerpiece": true,
		"ui_is_expression_only": true,
	}
func _exchange_panel_style() -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(
		0.018,
		0.019,
		0.021,
		0.992
	)
	style.border_color = Color(
		0.66,
		0.59,
		0.43,
		0.44
	)
	style.set_border_width_all(
		1
	)
	style.set_corner_radius_all(
		8
	)
	style.shadow_color = Color(
		0.0,
		0.0,
		0.0,
		0.48
	)
	style.shadow_size = 18
	return style


func _card_style(
	card_contract: Dictionary,
	presentation: Variant = {}
) -> StyleBoxFlat:
	var presentation_state: Dictionary = _safe_dictionary(
		presentation
	)




	if typeof(presentation) == TYPE_BOOL:
		presentation_state = {
			"hovered": bool(presentation)
		}

	var classification: String = str(
		card_contract.get(
			"classification",
			"AVAILABLE"
		)
	).strip_edges().to_upper()
	var is_centerpiece: bool = bool(
		card_contract.get(
			"centerpiece",
			false
		)
	)
	var accent: Color = _classification_color(
		classification
	)
	var presentation_class: String = (
		_luxury_presentation_class(
			card_contract
		)
	)
	var rare_card: bool = (
		classification in [
			"COLLECTOR",
			"EXCEPTIONAL",
			"ONE OF ONE",
			"HISTORIC",
			"ARTIFACT"
		]
		or classification.begins_with(
			"ARTIFACT_"
		)
	)
	var hovered: bool = bool(
		presentation_state.get(
			"hovered",
			false
		)
	)
	var dimmed: bool = bool(
		presentation_state.get(
			"dimmed",
			false
		)
	)
	var projection: bool = bool(
		presentation_state.get(
			"projection",
			false
		)
	)
	var ceremonial: bool = bool(
		presentation_state.get(
			"ceremonial",
			is_centerpiece
		)
	)

	var default_depth_tier: int = 1

	if is_centerpiece:
		default_depth_tier = 4
	elif hovered:
		default_depth_tier = 3
	elif rare_card:
		default_depth_tier = 2

	var depth_tier: int = clampi(
		int(
			presentation_state.get(
				"depth_tier",
				default_depth_tier
			)
		),
		1,
		4
	)

	var bg_mix: float = 0.01
	var border_alpha: float = 0.24
	var border_width: int = 1
	var corner_radius: int = 7
	var shadow_alpha: float = 0.24
	var shadow_size: int = 8

	match depth_tier:
		4:
			if ceremonial:
				bg_mix = 0.082
				border_alpha = 0.98
				border_width = 4
				corner_radius = 13
				shadow_alpha = 0.68
				shadow_size = 30
			else:
				bg_mix = 0.05
				border_alpha = 0.84
				border_width = 2
				corner_radius = 12
				shadow_alpha = 0.56
				shadow_size = 26

		3:
			bg_mix = (
				0.048
				if projection
				else 0.04
			)
			border_alpha = 0.72
			border_width = 2
			corner_radius = 9
			shadow_alpha = 0.46
			shadow_size = 18

		2:
			bg_mix = 0.026
			border_alpha = 0.54
			border_width = 1
			corner_radius = 8
			shadow_alpha = 0.34
			shadow_size = 14

		1:
			pass

	match presentation_class:
		"jewel":
			border_alpha += 0.04
			corner_radius += 2

		"horology":
			corner_radius = maxi(
				5,
				corner_radius - 1
			)

		"couture":
			corner_radius += 1

		"fine_art":
			border_alpha += 0.02

		"artifact_relic":
			bg_mix += 0.01
			shadow_alpha += 0.06

		"grand_asset":
			corner_radius = maxi(
				4,
				corner_radius - 2
			)

		"collector_object":
			pass

	if hovered:
		border_alpha += 0.1
		shadow_alpha += 0.08

	if projection:
		bg_mix += 0.01
		border_alpha += 0.06

	var dim_alpha: float = (
		0.42
		if dimmed
		else 1.0
	)
	var base_surface:= Color(
		0.047,
		0.048,
		0.052,
		0.992
	)
	var resolved_border_color: Color = accent
	var resolved_shadow_color:= Color(
		0.0,
		0.0,
		0.0,
		clampf(
			shadow_alpha * dim_alpha,
			0.0,
			1.0
		)
	)

	if (
		is_centerpiece
		and ceremonial
		and not projection
	):
		var private_market_gold:= Color(
			1.0,
			0.82,
			0.42,
			1.0
		)

		resolved_border_color = accent.lerp(
			private_market_gold,
			0.72
		)
		resolved_shadow_color = Color(
			resolved_border_color.r * 0.3,
			resolved_border_color.g * 0.22,
			resolved_border_color.b * 0.08,
			clampf(
				0.62 * dim_alpha,
				0.0,
				1.0
			)
		)

	var style:= StyleBoxFlat.new()

	style.bg_color = base_surface.lerp(
		accent,
		bg_mix
	)
	style.bg_color.a *= dim_alpha
	style.border_color = resolved_border_color
	style.border_color.a = clampf(
		border_alpha * dim_alpha,
		0.0,
		1.0
	)
	style.set_border_width_all(
		border_width
	)
	style.set_corner_radius_all(
		corner_radius
	)
	style.shadow_color = resolved_shadow_color
	style.shadow_size = shadow_size

	return style
func _visual_stage_style(
	card_contract: Dictionary,
	presentation: Dictionary = {}
) -> StyleBoxFlat:
	var classification: String = str(
		card_contract.get(
			"classification",
			"AVAILABLE"
		)
	).strip_edges().to_upper()
	var is_centerpiece: bool = bool(
		card_contract.get(
			"centerpiece",
			false
		)
	)
	var accent: Color = _classification_color(
		classification
	)
	var section_id: String = str(
		card_contract.get(
			"section_id",
			""
		)
	).strip_edges().to_lower()
	var item_type: String = str(
		card_contract.get(
			"item_type",
			""
		)
	).strip_edges().to_lower()
	var presentation_class: String = str(
		card_contract.get(
			"presentation_class",
			""
		)
	).strip_edges().to_lower()

	if presentation_class == "":
		if (
			section_id == "jewelry"
			or item_type in [
				"ring",
				"necklace",
				"tiara",
				"bracelet",
				"brooch",
				"crown"
			]
		):
			presentation_class = "regalia"
		elif (
			section_id == "watches"
			or item_type in [
				"watch",
				"clock",
				"timepiece"
			]
		):
			presentation_class = "timepiece"
		elif (
			section_id == "fashion"
			or item_type in [
				"dress",
				"couture",
				"garment",
				"trunk"
			]
		):
			presentation_class = "couture"
		elif (
			section_id == "art"
			or item_type in [
				"painting",
				"drawing",
				"portrait",
				"sculpture"
			]
		):
			presentation_class = "gallery"
		elif (
			section_id == "artifacts"
			or classification == "ARTIFACT"
			or classification.begins_with(
				"ARTIFACT_"
			)
		):
			presentation_class = "relic"
		elif (
			section_id == "vehicles"
			or item_type in [
				"car",
				"hypercar",
				"plane",
				"jet",
				"yacht"
			]
		):
			presentation_class = "mobility"
		else:
			presentation_class = "cabinet"

	var hovered: bool = bool(
		presentation.get(
			"hovered",
			false
		)
	)
	var dimmed: bool = bool(
		presentation.get(
			"dimmed",
			false
		)
	)
	var projection: bool = bool(
		presentation.get(
			"projection",
			false
		)
	)
	var ceremonial: bool = bool(
		presentation.get(
			"ceremonial",
			is_centerpiece
		)
	)

	var base_mix: float = (
		0.06
		if ceremonial
		else (
			0.034
			if hovered
			else (
				0.03
				if projection
				else (
					0.052
					if is_centerpiece
					else 0.02
				)
			)
		)
	)
	var border_alpha: float = (
		0.34
		if ceremonial
		else (
			0.24
			if hovered
			else (
				0.2
				if projection
				else (
					0.26
					if is_centerpiece
					else 0.14
				)
			)
		)
	)
	var border_width: int = (
		2
		if ceremonial or hovered
		else 1
	)
	var corner_radius: int = (
		9
		if ceremonial
		else 6
	)

	match presentation_class:
		"regalia":
			corner_radius += 2
		"timepiece":
			corner_radius = maxi(
				4,
				corner_radius - 1
			)
		"gallery":
			border_alpha += 0.04
		"relic":
			base_mix += 0.012
		"mobility":
			corner_radius = maxi(
				4,
				corner_radius - 2
			)
		_:
			pass

	var dim_alpha: float = (
		0.42
		if dimmed
		else 1.0
	)
	var base_surface:= Color(
		0.022,
		0.023,
		0.026,
		1.0
	)
	var style:= StyleBoxFlat.new()

	style.bg_color = base_surface.lerp(
		accent,
		base_mix
	)
	style.bg_color.a *= dim_alpha
	style.border_color = accent
	style.border_color.a = clampf(
		border_alpha * dim_alpha,
		0.0,
		1.0
	)
	style.set_border_width_all(
		border_width
	)
	style.set_corner_radius_all(
		corner_radius
	)

	return style
func _clear_children(
	node: Node
) -> void:
	if node == null:
		return

	for child in node.get_children():
		if bool(
			child.get_meta(
				"luxury_persistent_presentation_node",
				false
			)
		):
			continue

		node.remove_child(
			child
		)
		child.queue_free()
func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(
	value: Variant
) -> Array:
	return (
		value as Array
		if typeof(value) == TYPE_ARRAY
		else []
	)