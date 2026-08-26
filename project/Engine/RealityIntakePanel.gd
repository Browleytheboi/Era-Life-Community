extends PanelContainer
class_name RealityIntakePanel

signal request_command(
	envelope: Dictionary
)
signal request_close()
signal request_profile(
	username: String
)

const PANEL_SCHEMA:= (
	"eralife.reality_intake.panel"
)
const PANEL_VERSION:= 3

var contract: Dictionary = {}
var network_surface: EraLifeNetworkPanel = null
var search_edit: LineEdit = null
var recipient_edit: LineEdit = null
var message_edit: LineEdit = null
var status_label: Label = null
var entries_box: VBoxContainer = null
var results_box: VBoxContainer = null
var identity_search_timer: Timer = null
var identity_search_popover: PanelContainer = null
var identity_search_results_box: VBoxContainer = null
var identity_search_query_seq: int = 0
var last_identity_search_text: String = ""
var stream_status_label: Label = null
var network_status_label: Label = null
var connection_count_label: Label = null
var portal_surface: PanelContainer = null
var network_actions_scroll_bar: HScrollBar = null
var network_actions_scroll_fade_timer: Timer = null

var portal_line: ColorRect = null
var swirl_material: ShaderMaterial = null
var last_pointer_position: Vector2 = Vector2(0.5, 0.5)
var has_played_unfold: bool = false
func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	self_modulate = Color(1.0, 1.0, 1.0, 0.0)
	modulate = Color(1.0, 1.0, 1.0, 0.0)
	add_theme_stylebox_override("panel", _transparent_panel_style())
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	top_level = true
	z_as_relative = false
	z_index = 950
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_theme_stylebox_override("panel", _transparent_panel_style())
	_ensure_identity_search_timer()
	_ensure_network_actions_scroll_fade_timer()
	set_process(true)
func prewarm_for_first_open(prewarm_contract: Dictionary = {}) -> void:
	if bool(get_meta("reality_intake_panel_cold_prewarm_started", false)):
		return

	set_meta("reality_intake_panel_cold_prewarm_started", true)
	set_meta("reality_intake_panel_cold_prewarmed_finished", false)

	contract = prewarm_contract.duplicate(true)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	self_modulate = Color(1.0, 1.0, 1.0, 0.0)
	modulate = Color(1.0, 1.0, 1.0, 0.0)
	position = Vector2.ZERO
	add_theme_stylebox_override("panel", _transparent_panel_style())

	swirl_material = _swirl_material()

	await get_tree().process_frame

	if not is_inside_tree():
		return

	has_played_unfold = false
	set_meta("reality_intake_panel_cold_prewarmed_finished", true)
func reset_for_next_open() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	self_modulate = Color(1.0, 1.0, 1.0, 0.0)
	modulate = Color(1.0, 1.0, 1.0, 0.0)
	position = Vector2.ZERO
	scale = Vector2.ONE
	_hide_identity_search_popover()
	_hide_network_actions_scrollbar()

func render_contract(
	next_contract: Dictionary
) -> void:
	contract = next_contract.duplicate(true)
	prepare_for_hidden_open()
	_build_surface()
	call_deferred(
		"_reveal_after_prepaint"
	)

func _reveal_after_prepaint() -> void:
	if not is_inside_tree():
		return

	await get_tree().process_frame

	if not is_inside_tree():
		return

	_play_unfold_animation()
func _build_surface() -> void:
	_clear_children(self)
	identity_search_popover = null
	identity_search_results_box = null
	network_actions_scroll_bar = null
	network_surface = null

	add_theme_stylebox_override(
		"panel",
		_transparent_panel_style()
	)
	_build_dimensional_backdrop()

	portal_surface = PanelContainer.new()
	portal_surface.name = (
		"RealityIntakeSurface"
	)
	portal_surface.mouse_filter = (
		Control.MOUSE_FILTER_STOP
	)
	portal_surface.clip_contents = true
	portal_surface.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	portal_surface.offset_left = 36
	portal_surface.offset_right = -36
	portal_surface.offset_top = 28
	portal_surface.offset_bottom = -28
	portal_surface.pivot_offset = (
		get_viewport_rect().size * 0.5
	)
	portal_surface.add_theme_stylebox_override(
		"panel",
		_portal_surface_style()
	)
	add_child(portal_surface)

	_build_portal_swirl_layer(
		portal_surface
	)

	var margin:= MarginContainer.new()
	margin.name = (
		"RealityIntakeContentMargin"
	)
	margin.mouse_filter = (
		Control.MOUSE_FILTER_PASS
	)
	margin.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	margin.add_theme_constant_override(
		"margin_left",
		14
	)
	margin.add_theme_constant_override(
		"margin_right",
		14
	)
	margin.add_theme_constant_override(
		"margin_top",
		12
	)
	margin.add_theme_constant_override(
		"margin_bottom",
		12
	)
	portal_surface.add_child(margin)

	network_surface = EraLifeNetworkPanel.new()
	network_surface.name = (
		"EraLifeNetworkPanel"
	)
	network_surface.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	network_surface.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	network_surface.request_command.connect(
		_on_network_surface_request_command
	)
	network_surface.request_profile.connect(
		_on_network_surface_request_profile
	)
	network_surface.request_close.connect(
		_on_network_surface_request_close
	)
	margin.add_child(network_surface)

	network_surface.render_contract(
		contract
	)


func _on_network_surface_request_command(
	envelope: Dictionary
) -> void:
	request_command.emit(
		envelope.duplicate(true)
	)


func _on_network_surface_request_profile(
	username: String
) -> void:
	request_profile.emit(username)


func _on_network_surface_request_close() -> void:
	request_close.emit()
func _build_dimensional_backdrop() -> void:
	var dim:= ColorRect.new()
	dim.name = "RealityIntakeDim"
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.58)
	add_child(dim)

	portal_line = ColorRect.new()
	portal_line.name = "RealityIntakeOpeningLine"
	portal_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portal_line.anchor_left = 0.5
	portal_line.anchor_right = 0.5
	portal_line.anchor_top = 0.5
	portal_line.anchor_bottom = 0.5
	portal_line.offset_left = -4
	portal_line.offset_right = 4
	portal_line.offset_top = -1
	portal_line.offset_bottom = 1
	portal_line.color = Color(1.0, 1.0, 1.0, 0.72)
	add_child(portal_line)
func _build_portal_swirl_layer(parent: Control) -> void:
	if parent == null:
		return

	var portal_backing:= ColorRect.new()
	portal_backing.name = "RealityIntakePortalBacking"
	portal_backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portal_backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portal_backing.color = Color(0.0, 0.0, 0.0, 0.72)
	parent.add_child(portal_backing)

	var swirl:= ColorRect.new()
	swirl.name = "RealityIntakePortalSwirlField"
	swirl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swirl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	swirl.color = Color(0.0, 0.0, 0.0, 0.0)
	swirl.modulate = Color(1.0, 1.0, 1.0, 1.0)
	swirl_material = _swirl_material()
	swirl.material = swirl_material
	parent.add_child(swirl)

	var glass:= ColorRect.new()
	glass.name = "RealityIntakePortalGlass"
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glass.color = Color(0.01, 0.012, 0.018, 0.34)
	parent.add_child(glass)

	var depth_vignette:= PanelContainer.new()
	depth_vignette.name = "RealityIntakePortalDepth"
	depth_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	depth_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	depth_vignette.add_theme_stylebox_override("panel", _portal_depth_style())
	parent.add_child(depth_vignette)
func _build_header(root: VBoxContainer) -> void:
	var header:= PanelContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	header.custom_minimum_size = Vector2(0.0, 52.0)
	header.add_theme_stylebox_override("panel", _header_style())
	root.add_child(header)

	var header_margin:= MarginContainer.new()
	header_margin.add_theme_constant_override("margin_left", 14)
	header_margin.add_theme_constant_override("margin_right", 14)
	header_margin.add_theme_constant_override("margin_top", 7)
	header_margin.add_theme_constant_override("margin_bottom", 7)
	header.add_child(header_margin)

	var row:= HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	header_margin.add_child(row)

	var identity_box:= VBoxContainer.new()
	identity_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity_box.add_theme_constant_override("separation", 0)
	row.add_child(identity_box)

	var network_title:= Label.new()
	network_title.text = "ERALIFE NETWORK"
	network_title.add_theme_font_size_override("font_size", 18)
	network_title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.98))
	identity_box.add_child(network_title)

	var username: String = _username()
	var surface_title:= Label.new()
	surface_title.text = "Reality Intake - %s" % username
	surface_title.add_theme_font_size_override("font_size", 12)
	surface_title.add_theme_color_override("font_color", Color(0.86, 0.89, 0.96, 0.76))
	identity_box.add_child(surface_title)

	network_status_label = Label.new()
	network_status_label.text = _status_text()
	network_status_label.custom_minimum_size = Vector2(300.0, 0.0)
	network_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	network_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	network_status_label.add_theme_font_size_override("font_size", 11)
	network_status_label.add_theme_color_override("font_color", Color(0.8, 1.0, 0.88, 0.82))
	row.add_child(network_status_label)

	connection_count_label = Label.new()
	connection_count_label.text = "Connections: %d" % _connection_count()
	connection_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	connection_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	connection_count_label.add_theme_font_size_override("font_size", 11)
	connection_count_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.62))
	row.add_child(connection_count_label)

	var close_button:= Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(82, 30)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.add_theme_stylebox_override("normal", _button_style(Color(0.18, 0.18, 0.2, 0.88), Color(0.78, 0.78, 0.84, 0.5)))
	close_button.add_theme_stylebox_override("hover", _button_style(Color(0.24, 0.24, 0.28, 0.96), Color(1.0, 1.0, 1.0, 0.82)))
	close_button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.92))
	close_button.pressed.connect(func (): request_close.emit())
	row.add_child(close_button)
func _build_network_tools(root: VBoxContainer) -> void:
	var tools:= PanelContainer.new()
	tools.name = "RealityNetworkTools"
	tools.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tools.custom_minimum_size = Vector2(0.0, 54.0)
	tools.add_theme_stylebox_override("panel", _tool_band_style())
	root.add_child(tools)

	var margin:= MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	tools.add_child(margin)

	var row_scroll:= ScrollContainer.new()
	row_scroll.name = "RealityNetworkActionsScroll"
	row_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_scroll.custom_minimum_size = Vector2(0.0, 36.0)
	row_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	row_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(row_scroll)

	var row:= HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 6)
	row_scroll.add_child(row)

	search_edit = LineEdit.new()
	search_edit.placeholder_text = "Find an ErAccount"
	search_edit.custom_minimum_size = Vector2(180, 30)
	search_edit.add_theme_stylebox_override("normal", _line_edit_style())
	search_edit.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.94))
	search_edit.add_theme_color_override("font_placeholder_color", Color(1.0, 1.0, 1.0, 0.42))
	search_edit.text = last_identity_search_text
	search_edit.text_changed.connect(_on_identity_search_text_changed)
	search_edit.focus_entered.connect(func ():
		if str(search_edit.text).strip_edges() != "":
			_show_identity_search_popover_pending(str(search_edit.text))
	)
	row.add_child(search_edit)

	var search_button:= _network_button("Scan", Color(0.72, 0.78, 1.0, 1.0))
	search_button.custom_minimum_size = Vector2(70, 30)
	search_button.pressed.connect(func ():
		_request_identity_discovery_now(search_edit.text)
	)
	row.add_child(search_button)

	recipient_edit = LineEdit.new()
	recipient_edit.placeholder_text = "Target ErAccount"
	recipient_edit.custom_minimum_size = Vector2(156, 30)
	recipient_edit.add_theme_stylebox_override("normal", _line_edit_style())
	recipient_edit.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.94))
	recipient_edit.add_theme_color_override("font_placeholder_color", Color(1.0, 1.0, 1.0, 0.42))
	row.add_child(recipient_edit)

	message_edit = LineEdit.new()
	message_edit.placeholder_text = "Attach a message"
	message_edit.custom_minimum_size = Vector2(214, 30)
	message_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_edit.add_theme_stylebox_override("normal", _line_edit_style())
	message_edit.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.94))
	message_edit.add_theme_color_override("font_placeholder_color", Color(1.0, 1.0, 1.0, 0.42))
	row.add_child(message_edit)

	var connect_button:= _network_button("Connect", Color(0.8, 1.0, 0.86, 1.0))
	connect_button.custom_minimum_size = Vector2(84, 30)
	connect_button.pressed.connect(func ():
		request_command.emit({
			"command": "mailbox.send_friend_request",
			"recipient_username": recipient_edit.text,
			"note": message_edit.text,
			"source": "RealityIntakePanel"
		})
	)
	row.add_child(connect_button)

	var life_button:= _network_button("Transmit", Color(1.0, 0.88, 0.62, 1.0))
	life_button.custom_minimum_size = Vector2(92, 30)
	life_button.pressed.connect(func ():
		request_command.emit({
			"command": "mailbox.send_current_life",
			"recipient_username": recipient_edit.text,
			"message": message_edit.text,
			"source": "RealityIntakePanel"
		})
	)
	row.add_child(life_button)

	var live_button:= _network_button("Invite Live", Color(0.72, 1.0, 1.0, 1.0))
	live_button.custom_minimum_size = Vector2(102, 30)
	live_button.pressed.connect(func ():
		request_command.emit({
			"command": "mailbox.send_live_reality_invite",
			"recipient_username": recipient_edit.text,
			"message": message_edit.text,
			"source": "RealityIntakePanel"
		})
	)
	row.add_child(live_button)

	var publish_button:= _network_button("Go Live", Color(0.72, 1.0, 1.0, 1.0))
	publish_button.custom_minimum_size = Vector2(82, 30)
	publish_button.pressed.connect(func ():
		request_command.emit({
			"command": "self_host_network.publish_presence",
			"source": "RealityIntakePanel"
		})
	)
	row.add_child(publish_button)

	var disconnect_button:= _network_button("Disconnect", Color(1.0, 0.74, 0.46, 1.0))
	disconnect_button.custom_minimum_size = Vector2(102, 30)
	disconnect_button.pressed.connect(func ():
		request_command.emit({
			"command": "self_host_network.disconnect_presence",
			"source": "RealityIntakePanel"
		})
	)
	row.add_child(disconnect_button)

	_configure_network_actions_scrollbar(row_scroll)
func _ensure_network_actions_scroll_fade_timer() -> void:
	if network_actions_scroll_fade_timer != null and is_instance_valid(network_actions_scroll_fade_timer):
		return

	network_actions_scroll_fade_timer = Timer.new()
	network_actions_scroll_fade_timer.name = "NetworkActionsScrollFadeTimer"
	network_actions_scroll_fade_timer.one_shot = true
	network_actions_scroll_fade_timer.wait_time = 0.72
	network_actions_scroll_fade_timer.timeout.connect(_hide_network_actions_scrollbar)
	add_child(network_actions_scroll_fade_timer)


func _configure_network_actions_scrollbar(row_scroll: ScrollContainer) -> void:
	if row_scroll == null or not is_instance_valid(row_scroll):
		return

	network_actions_scroll_bar = row_scroll.get_h_scroll_bar()
	if network_actions_scroll_bar == null or not is_instance_valid(network_actions_scroll_bar):
		return

	network_actions_scroll_bar.custom_minimum_size = Vector2(0.0, 7.0)
	network_actions_scroll_bar.modulate = Color(1.0, 1.0, 1.0, 0.0)
	network_actions_scroll_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	network_actions_scroll_bar.add_theme_stylebox_override("scroll", _network_actions_scroll_track_style(false))
	network_actions_scroll_bar.add_theme_stylebox_override("grabber", _network_actions_scroll_grabber_style(false))
	network_actions_scroll_bar.add_theme_stylebox_override("grabber_highlight", _network_actions_scroll_grabber_style(true))
	network_actions_scroll_bar.add_theme_stylebox_override("grabber_pressed", _network_actions_scroll_grabber_style(true, true))

	if not network_actions_scroll_bar.value_changed.is_connected(_on_network_actions_scrollbar_value_changed):
		network_actions_scroll_bar.value_changed.connect(_on_network_actions_scrollbar_value_changed)


func _on_network_actions_scrollbar_value_changed(_value: float) -> void:
	_show_network_actions_scrollbar()


func _show_network_actions_scrollbar() -> void:
	if network_actions_scroll_bar == null or not is_instance_valid(network_actions_scroll_bar):
		return

	_ensure_network_actions_scroll_fade_timer()
	network_actions_scroll_bar.add_theme_stylebox_override("scroll", _network_actions_scroll_track_style(true))
	network_actions_scroll_bar.add_theme_stylebox_override("grabber", _network_actions_scroll_grabber_style(true))

	var tween:= create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(network_actions_scroll_bar, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.1)

	if network_actions_scroll_fade_timer != null:
		network_actions_scroll_fade_timer.stop()
		network_actions_scroll_fade_timer.start()


func _hide_network_actions_scrollbar() -> void:
	if network_actions_scroll_bar == null or not is_instance_valid(network_actions_scroll_bar):
		return

	network_actions_scroll_bar.add_theme_stylebox_override("scroll", _network_actions_scroll_track_style(false))
	network_actions_scroll_bar.add_theme_stylebox_override("grabber", _network_actions_scroll_grabber_style(false))

	var tween:= create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(network_actions_scroll_bar, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.22)


func _network_actions_scroll_track_style(active: bool = false) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.72, 1.0, 1.0, 0.16 if active else 0.0)
	style.border_color = Color(0.72, 1.0, 1.0, 0.22 if active else 0.0)
	style.set_border_width_all(0)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style


func _network_actions_scroll_grabber_style(active: bool = false, pressed: bool = false) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()

	if pressed:
		style.bg_color = Color(1.0, 0.86, 0.44, 0.96)
	elif active:
		style.bg_color = Color(0.72, 1.0, 1.0, 0.92)
	else:
		style.bg_color = Color(0.72, 1.0, 1.0, 0.0)

	style.border_color = Color(1.0, 1.0, 1.0, 0.42 if active or pressed else 0.0)
	style.set_border_width_all(1 if active or pressed else 0)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.shadow_color = Color(0.72, 1.0, 1.0, 0.24 if active or pressed else 0.0)
	style.shadow_size = 6 if active or pressed else 0
	return style
func _build_reality_stream(root: VBoxContainer) -> void:
	var split:= HSplitContainer.new()
	split.name = "RealityStreamSplit"
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.size_flags_stretch_ratio = 1.0
	split.custom_minimum_size = Vector2(0.0, 96.0)
	root.add_child(split)

	var stream_panel:= PanelContainer.new()
	stream_panel.name = "RealityStreamPanel"
	stream_panel.custom_minimum_size = Vector2(0.0, 0.0)
	stream_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stream_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stream_panel.add_theme_stylebox_override("panel", _stream_style())
	split.add_child(stream_panel)

	var stream_margin:= MarginContainer.new()
	stream_margin.add_theme_constant_override("margin_left", 9)
	stream_margin.add_theme_constant_override("margin_right", 9)
	stream_margin.add_theme_constant_override("margin_top", 7)
	stream_margin.add_theme_constant_override("margin_bottom", 7)
	stream_panel.add_child(stream_margin)

	var stream_root:= VBoxContainer.new()
	stream_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stream_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stream_root.add_theme_constant_override("separation", 4)
	stream_margin.add_child(stream_root)

	var stream_header:= HBoxContainer.new()
	stream_header.add_theme_constant_override("separation", 6)
	stream_root.add_child(stream_header)

	var stream_title_box:= VBoxContainer.new()
	stream_title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stream_title_box.add_theme_constant_override("separation", 0)
	stream_header.add_child(stream_title_box)

	var stream_title:= Label.new()
	stream_title.text = "Reality Stream"
	stream_title.add_theme_font_size_override("font_size", 16)
	stream_title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.94))
	stream_title_box.add_child(stream_title)

	var stream_subtitle:= Label.new()
	stream_subtitle.text = "Lives, forks, transfers, and objects entering your world."
	stream_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stream_subtitle.add_theme_font_size_override("font_size", 10)
	stream_subtitle.add_theme_color_override("font_color", Color(0.78, 0.84, 0.94, 0.58))
	stream_title_box.add_child(stream_subtitle)

	stream_status_label = Label.new()
	stream_status_label.text = "%d unread" % int(contract.get("unread_count", 0))
	stream_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stream_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stream_status_label.add_theme_font_size_override("font_size", 10)
	stream_status_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.58, 0.82))
	stream_header.add_child(stream_status_label)

	var entries_scroll:= ScrollContainer.new()
	entries_scroll.name = "RealityEntriesScroll"
	entries_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entries_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	entries_scroll.custom_minimum_size = Vector2(0.0, 0.0)
	entries_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	entries_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	stream_root.add_child(entries_scroll)

	entries_box = VBoxContainer.new()
	entries_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entries_box.add_theme_constant_override("separation", 6)
	entries_scroll.add_child(entries_box)

	var people_panel:= PanelContainer.new()
	people_panel.name = "LifeIndexPanel"
	people_panel.custom_minimum_size = Vector2(190.0, 0.0)
	people_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	people_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	people_panel.add_theme_stylebox_override("panel", _stream_style(true))
	split.add_child(people_panel)

	var people_margin:= MarginContainer.new()
	people_margin.add_theme_constant_override("margin_left", 8)
	people_margin.add_theme_constant_override("margin_right", 8)
	people_margin.add_theme_constant_override("margin_top", 7)
	people_margin.add_theme_constant_override("margin_bottom", 7)
	people_panel.add_child(people_margin)

	var people_root:= VBoxContainer.new()
	people_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	people_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	people_root.add_theme_constant_override("separation", 4)
	people_margin.add_child(people_root)

	var people_title:= Label.new()
	people_title.text = "Life Index"
	people_title.add_theme_font_size_override("font_size", 14)
	people_title.add_theme_color_override("font_color", Color(0.9, 0.94, 1.0, 0.8))
	people_root.add_child(people_title)

	results_box = VBoxContainer.new()
	results_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	results_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	results_box.add_theme_constant_override("separation", 4)
	people_root.add_child(results_box)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 10)
	status_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.5))
	people_root.add_child(status_label)

	_render_entries()
	_render_search_results()
func _status_text() -> String:
	if not bool(contract.get("success", false)):
		return str(contract.get("reason", "Sign into an ErAccount to open Reality Intake."))

	var live_count: int = int(contract.get("live_node_count", 0))
	if live_count > 0:
		return "Connected • Portable Lives Enabled • %d live reality node(s)" % live_count

	return "Connected • Portable Lives Enabled • SelfHost Ready"


func _render_entries() -> void:
	if entries_box == null:
		return

	_clear_children(entries_box)

	var entries: Array = contract.get("entries", []) if typeof(contract.get("entries", [])) == TYPE_ARRAY else []
	if entries.is_empty():
		entries_box.add_child(_build_empty_stream_state())
		return

	var tile_index: int = 0
	for raw_entry in entries:
		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue

		var tile:= _build_reality_tile(raw_entry as Dictionary)
		entries_box.add_child(tile)
		_play_reality_tile_arrival(tile, tile_index)
		tile_index += 1

func _build_empty_stream_state() -> Control:
	var empty:= PanelContainer.new()
	empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	empty.custom_minimum_size = Vector2(0, 64)
	empty.add_theme_stylebox_override("panel", _empty_state_style())

	var margin:= MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	empty.add_child(margin)

	var box:= VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 3)
	margin.add_child(box)

	var title:= Label.new()
	title.text = "No incoming realities..."
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.86))
	box.add_child(title)

	var body:= Label.new()
	body.text = "The network is quiet right now."
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 10)
	body.add_theme_color_override("font_color", Color(0.78, 0.84, 0.92, 0.62))
	box.add_child(body)

	return empty
func _build_reality_tile(entry: Dictionary) -> Control:
	var tile:= PanelContainer.new()
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.custom_minimum_size = Vector2(0, 142)
	tile.mouse_filter = Control.MOUSE_FILTER_STOP
	tile.pivot_offset = Vector2(360, 71)
	tile.add_theme_stylebox_override("panel", _tile_style(entry))
	tile.set_meta("reality_intake_entry", entry.duplicate(true))
	tile.set_meta("ui_is_renderer_only", true)
	_bind_reality_tile_hover_motion(tile, entry)

	var margin:= MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	tile.add_child(margin)

	var box:= VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	margin.add_child(box)

	var top:= HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	box.add_child(top)

	var arrival_mark:= ColorRect.new()
	arrival_mark.custom_minimum_size = Vector2(4, 38)
	arrival_mark.color = _entry_accent(entry)
	top.add_child(arrival_mark)

	var title_box:= VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 2)
	top.add_child(title_box)

	var type_label:= Label.new()
	type_label.text = _entry_type_label(entry)
	type_label.add_theme_font_size_override("font_size", 12)
	type_label.add_theme_color_override("font_color", _entry_accent(entry))
	title_box.add_child(type_label)

	var title:= Label.new()
	title.text = _entry_title(entry)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.96))
	title_box.add_child(title)

	var source:= Label.new()
	source.text = "From: %s" % str(entry.get("sender_username", "Unknown"))
	source.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	source.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	source.add_theme_font_size_override("font_size", 12)
	source.add_theme_color_override("font_color", Color(0.86, 0.9, 1.0, 0.68))
	top.add_child(source)

	var body:= Label.new()
	body.text = _entry_body(entry)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 12)
	body.add_theme_color_override("font_color", Color(0.9, 0.92, 0.98, 0.78))
	box.add_child(body)

	var actions:= HBoxContainer.new()
	actions.add_theme_constant_override("separation", 7)
	box.add_child(actions)

	var action_list: Array = entry.get("actions", []) if typeof(entry.get("actions", [])) == TYPE_ARRAY else []
	for raw_action in action_list:
		var action_text: String = str(raw_action).strip_edges().to_lower()
		if action_text == "":
			continue

		var button:= _tile_action_button(_action_label(action_text), _entry_accent(entry))
		button.custom_minimum_size = Vector2(124, 30)
		button.pressed.connect(func ():
			request_command.emit({
				"command": "mailbox.consume_entry_action",
				"entry_id": str(entry.get("entry_id", "")),
				"entry_action": action_text,
				"source": "RealityIntakePanel"
			})
		)
		actions.add_child(button)

	return tile

func _render_search_results() -> void:
	if results_box == null:
		return

	_clear_children(results_box)

	var results: Array = contract.get("search_results", []) if typeof(contract.get("search_results", [])) == TYPE_ARRAY else []
	if results.is_empty():
		var empty:= Label.new()
		empty.text = "Search for an ErAccount.\nFind the people whose lives can reach yours."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_font_size_override("font_size", 14)
		empty.add_theme_color_override("font_color", Color(0.82, 0.86, 0.94, 0.72))
		results_box.add_child(empty)
		return

	for raw_result in results:
		if typeof(raw_result) != TYPE_DICTIONARY:
			continue
		results_box.add_child(_build_life_index_result(raw_result as Dictionary))


func _build_life_index_result(result: Dictionary) -> Control:
	var card:= PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _result_style())
	_bind_hover_motion(card)

	var margin:= MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var box:= VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var username:= Label.new()
	username.text = str(result.get("username", "Unknown"))
	username.add_theme_font_size_override("font_size", 18)
	username.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.96))
	box.add_child(username)

	var meta:= Label.new()
	meta.text = "Registered ErAccount\nPortable reality endpoint"
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta.add_theme_font_size_override("font_size", 12)
	meta.add_theme_color_override("font_color", Color(0.78, 0.84, 0.94, 0.74))
	box.add_child(meta)

	var buttons:= HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	box.add_child(buttons)

	var select_button:= _mini_button("Select")
	select_button.pressed.connect(func ():
		if recipient_edit != null:
			recipient_edit.text = str(result.get("username", ""))
	)
	buttons.add_child(select_button)

	var connect_button:= _mini_button("Connect")
	connect_button.pressed.connect(func ():
		if recipient_edit != null:
			recipient_edit.text = str(result.get("username", ""))
		request_command.emit({
			"command": "mailbox.send_friend_request",
			"recipient_username": str(result.get("username", "")),
			"note": message_edit.text if message_edit != null else "",
			"source": "RealityIntakePanel"
		})
	)
	buttons.add_child(connect_button)

	var send_button:= _mini_button("Transmit")
	send_button.pressed.connect(func ():
		if recipient_edit != null:
			recipient_edit.text = str(result.get("username", ""))
		request_command.emit({
			"command": "mailbox.send_current_life",
			"recipient_username": str(result.get("username", "")),
			"message": message_edit.text if message_edit != null else "",
			"source": "RealityIntakePanel"
		})
	)
	buttons.add_child(send_button)

	return card


func apply_command_report(
	report: Dictionary
) -> void:
	if (
		network_surface != null
		and is_instance_valid(
			network_surface
		)
	):
		network_surface.apply_command_report(
			report
		)

	if typeof(
		report.get(
			"surface_contract",
			{}
		)
	) == TYPE_DICTIONARY:
		var next_contract: Dictionary = (
			report.get(
				"surface_contract",
				{}
			) as Dictionary
		).duplicate(true)

		if not next_contract.is_empty():
			contract = next_contract
func set_active_network_section(
	section_id: String
) -> void:
	if (
		network_surface != null
		and is_instance_valid(
			network_surface
		)
	):
		network_surface.set_active_section(
			section_id
		)
func _ensure_identity_search_timer() -> void:
	if identity_search_timer != null and is_instance_valid(identity_search_timer):
		return

	identity_search_timer = Timer.new()
	identity_search_timer.name = "IdentitySearchDebounceTimer"
	identity_search_timer.one_shot = true
	identity_search_timer.wait_time = 0.24
	identity_search_timer.timeout.connect(_perform_debounced_identity_search)
	add_child(identity_search_timer)


func _on_identity_search_text_changed(new_text: String) -> void:
	last_identity_search_text = str(new_text)
	identity_search_query_seq += 1

	var clean_query: String = last_identity_search_text.strip_edges()
	if clean_query == "":
		_hide_identity_search_popover()
		return

	_show_identity_search_popover_pending(clean_query)

	_ensure_identity_search_timer()
	identity_search_timer.stop()
	identity_search_timer.start()


func _perform_debounced_identity_search() -> void:
	_request_identity_discovery_now(last_identity_search_text)


func _request_identity_discovery_now(query: String) -> void:
	var clean_query: String = str(query).strip_edges()
	if clean_query == "":
		_hide_identity_search_popover()
		return

	identity_search_query_seq += 1
	_show_identity_search_popover_pending(clean_query)

	request_command.emit({
		"command": "search.identity_discovery",
		"query": clean_query,
		"query_seq": identity_search_query_seq,
		"limit": 6,
		"source": "RealityIntakePanel"
	})


func _apply_identity_discovery_report(report: Dictionary) -> void:
	var report_seq: int = int(report.get("query_seq", identity_search_query_seq))
	if report_seq < identity_search_query_seq:
		return

	var query: String = str(report.get("query", last_identity_search_text)).strip_edges()
	var results: Array = report.get("results", []) if typeof(report.get("results", [])) == TYPE_ARRAY else []
	_render_identity_search_results(query, results)


func _ensure_identity_search_popover() -> void:
	if identity_search_popover != null and is_instance_valid(identity_search_popover):
		return

	identity_search_popover = PanelContainer.new()
	identity_search_popover.name = "IdentityDiscoveryPopover"
	identity_search_popover.visible = false
	identity_search_popover.mouse_filter = Control.MOUSE_FILTER_STOP
	identity_search_popover.z_as_relative = false
	identity_search_popover.z_index = 990
	identity_search_popover.custom_minimum_size = Vector2(360, 0)
	identity_search_popover.add_theme_stylebox_override("panel", _identity_search_popover_style())
	add_child(identity_search_popover)

	var margin:= MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	identity_search_popover.add_child(margin)

	identity_search_results_box = VBoxContainer.new()
	identity_search_results_box.add_theme_constant_override("separation", 8)
	margin.add_child(identity_search_results_box)


func _show_identity_search_popover_pending(_query: String) -> void:
	_ensure_identity_search_popover()
	if identity_search_results_box == null:
		return

	_clear_children(identity_search_results_box)

	var label:= Label.new()
	label.text = "Searching the living reality network..."
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.88, 0.92, 1.0, 0.78))
	identity_search_results_box.add_child(label)

	_position_identity_search_popover()
	identity_search_popover.visible = true


func _render_identity_search_results(_query: String, results: Array) -> void:
	_ensure_identity_search_popover()
	if identity_search_results_box == null:
		return

	_clear_children(identity_search_results_box)

	if results.is_empty():
		var empty:= Label.new()
		empty.text = "No identities found.\nThe network is quiet here."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_font_size_override("font_size", 13)
		empty.add_theme_color_override("font_color", Color(0.86, 0.9, 1.0, 0.72))
		identity_search_results_box.add_child(empty)
	else:
		for raw_result in results:
			if typeof(raw_result) != TYPE_DICTIONARY:
				continue
			identity_search_results_box.add_child(_build_identity_discovery_result(raw_result as Dictionary))

	_position_identity_search_popover()
	identity_search_popover.visible = true


func _build_identity_discovery_result(result: Dictionary) -> Control:
	var card:= PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.add_theme_stylebox_override("panel", _identity_discovery_result_style(bool(result.get("alive_now", false))))
	_bind_hover_motion(card)

	var margin:= MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)

	var row:= HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	var text_box:= VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 2)
	row.add_child(text_box)

	var username:= Label.new()
	username.text = str(result.get("username", "Unknown"))
	username.add_theme_font_size_override("font_size", 16)
	username.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.96))
	text_box.add_child(username)

	var presence:= Label.new()
	presence.text = str(result.get("presence_label", "registered ErAccount"))
	presence.add_theme_font_size_override("font_size", 12)
	presence.add_theme_color_override("font_color", Color(0.72, 1.0, 1.0, 0.82) if bool(result.get("alive_now", false)) else Color(0.78, 0.84, 0.94, 0.7))
	text_box.add_child(presence)

	var select_button:= _mini_button("Select")
	select_button.pressed.connect(func ():
		if recipient_edit != null:
			recipient_edit.text = str(result.get("username", ""))
		_hide_identity_search_popover()
	)
	row.add_child(select_button)

	return card


func _position_identity_search_popover() -> void:
	if identity_search_popover == null or not is_instance_valid(identity_search_popover):
		return
	if search_edit == null or not is_instance_valid(search_edit):
		return

	var search_rect: Rect2 = search_edit.get_global_rect()
	var panel_rect: Rect2 = get_global_rect()
	var popover_width: float = max(360.0, search_rect.size.x + 120.0)
	var estimated_popover_height: float = 220.0

	var desired_global_position: Vector2 = search_rect.position + Vector2(0.0, search_rect.size.y + 8.0)
	var local_position: Vector2 = desired_global_position - panel_rect.position

	var max_x: float = max(8.0, panel_rect.size.x - popover_width - 16.0)
	local_position.x = clamp(local_position.x, 8.0, max_x)

	if local_position.y + estimated_popover_height > panel_rect.size.y - 16.0:
		local_position.y = max(8.0, search_rect.position.y - panel_rect.position.y - estimated_popover_height - 8.0)

	identity_search_popover.position = local_position
	identity_search_popover.custom_minimum_size = Vector2(popover_width, 0.0)

func _hide_identity_search_popover() -> void:
	if identity_search_popover != null and is_instance_valid(identity_search_popover):
		identity_search_popover.visible = false
func _identity_search_popover_style() -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.02, 0.03, 0.94)
	style.border_color = Color(0.72, 1.0, 1.0, 0.34)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	style.shadow_size = 18
	return style


func _identity_discovery_result_style(alive_now: bool = false) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.034, 0.04, 0.052, 0.88)
	style.border_color = Color(0.72, 1.0, 1.0, 0.52) if alive_now else Color(1.0, 1.0, 1.0, 0.16)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.shadow_color = Color(0.72, 1.0, 1.0, 0.18) if alive_now else Color(0.0, 0.0, 0.0, 0.2)
	style.shadow_size = 12 if alive_now else 4
	return style

func _play_unfold_animation() -> void:
	has_played_unfold = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	position = Vector2.ZERO
	scale = Vector2.ONE
	self_modulate = Color(1.0, 1.0, 1.0, 1.0)
	modulate = Color(1.0, 1.0, 1.0, 1.0)

	if portal_surface != null and is_instance_valid(portal_surface):
		portal_surface.scale = Vector2.ONE
		portal_surface.modulate = Color(1.0, 1.0, 1.0, 1.0)

	if portal_line != null and is_instance_valid(portal_line):
		portal_line.modulate = Color(1.0, 1.0, 1.0, 0.0)

func _process(_delta: float) -> void:
	if swirl_material != null:
		swirl_material.set_shader_parameter("pointer", last_pointer_position)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var viewport_size: Vector2 = get_viewport_rect().size
		if viewport_size.x > 0.0 and viewport_size.y > 0.0:
			last_pointer_position = Vector2(
				clamp(event.position.x / viewport_size.x, 0.0, 1.0),
				clamp(event.position.y / viewport_size.y, 0.0, 1.0)
			)


func _username() -> String:
	var username: String = str(contract.get("username", "")).strip_edges()
	if username != "":
		return username

	var identity_context: Dictionary = contract.get("identity_context", {}) if typeof(contract.get("identity_context", {})) == TYPE_DICTIONARY else {}
	username = str(identity_context.get("account_username", "")).strip_edges()
	if username != "":
		return username

	return "Guest"


func _connection_count() -> int:
	var messenger_context: Dictionary = contract.get("messenger_context", {}) if typeof(contract.get("messenger_context", {})) == TYPE_DICTIONARY else {}
	var friends: Array = messenger_context.get("friends", []) if typeof(messenger_context.get("friends", [])) == TYPE_ARRAY else []
	var connections: Array = messenger_context.get("connections", []) if typeof(messenger_context.get("connections", [])) == TYPE_ARRAY else []
	return max(friends.size(), connections.size())


func _entry_title(entry: Dictionary) -> String:
	var entry_type: String = str(entry.get("type", "")).strip_edges().to_lower()
	var sender: String = str(entry.get("sender_username", "Unknown")).strip_edges()

	if entry_type == "live_reality_invite":
		return "%s is currently alive in their world." % sender
	if entry_type == "life_packet":
		return "A life is requesting entry into your world."
	if entry_type == "friend_request":
		return "%s wants to connect realities." % sender
	if entry_type == "item_packet":
		return "A verified object crossed the network."
	if entry_type == "fork_notice":
		return "Your life was forked."
	if entry_type == "reality_transfer":
		return "Reality transfer waiting."

	return str(entry.get("title", "Reality Transfer"))


func _entry_type_label(entry: Dictionary) -> String:
	var entry_type: String = str(entry.get("type", "")).strip_edges().to_lower()

	if entry_type == "live_reality_invite":
		return "Live Reality"
	if entry_type == "life_packet":
		return "Incoming Life"
	if entry_type == "friend_request":
		return "Connection Request"
	if entry_type == "item_packet":
		return "ItemPacket"
	if entry_type == "fork_notice":
		return "Timeline Divergence"
	if entry_type == "direct_message":
		return "Cross-Reality Message"

	return "Reality Intake"


func _entry_body(entry: Dictionary) -> String:
	var entry_type: String = str(entry.get("type", "")).strip_edges().to_lower()
	var message: String = str(entry.get("message", "")).strip_edges()
	var payload: Dictionary = entry.get("payload", {}) if typeof(entry.get("payload", {})) == TYPE_DICTIONARY else {}
	var life_packet: Dictionary = payload.get("life_packet", {}) if typeof(payload.get("life_packet", {})) == TYPE_DICTIONARY else {}
	if entry_type == "live_reality_invite":
		var live_reality: Dictionary = payload.get("live_reality", {}) if typeof(payload.get("live_reality", {})) == TYPE_DICTIONARY else {}
		var runtime_presence: Dictionary = live_reality.get("runtime_presence", {}) if typeof(live_reality.get("runtime_presence", {})) == TYPE_DICTIONARY else {}
		var active_text: String = "Active node" if bool(runtime_presence.get("active", false)) else "Local-first node prepared"
		var line: String = "%s • Runtime: %s\nEnter live, observe the active reality, or fork a snapshot into your own timeline." % [
			active_text,
			str(live_reality.get("runtime_id", "local runtime"))
		]
		if message != "":
			line += "\nTransmission note: %s" % message
		return line
	if entry_type == "life_packet":
		var player_name: String = str(life_packet.get("player_name", "Unknown Life"))
		var checkpoint: Dictionary = life_packet.get("checkpoint_snapshot", {}) if typeof(life_packet.get("checkpoint_snapshot", {})) == TYPE_DICTIONARY else {}
		var world_refs: Dictionary = life_packet.get("world_state_refs", {}) if typeof(life_packet.get("world_state_refs", {})) == TYPE_DICTIONARY else {}
		var age: int = int(checkpoint.get("age", 0))
		var era_name: String = str(world_refs.get("era_name", "Unknown Era")).strip_edges()
		var line: String = "%s • Age %d • %s\nThis life can be played, observed, or forked into a new timeline." % [player_name, age, era_name]
		if message != "":
			line += "\nTransmission note: %s" % message
		return line

	if entry_type == "friend_request":
		if message != "":
			return "Connection note: %s" % message
		return "A person on the EraLife Network wants their reality to be reachable from yours."

	if entry_type == "item_packet":
		return "This object carries ownership history, origin context, and a validation signature."

	if message != "":
		return message

	return "A reality packet is waiting for your decision."


func _entry_accent(entry: Dictionary) -> Color:
	var entry_type: String = str(entry.get("type", "")).strip_edges().to_lower()

	if entry_type == "live_reality_invite":
		return Color(0.72, 1.0, 1.0, 1.0)
	if entry_type == "life_packet":
		return Color(1.0, 0.82, 0.48, 1.0)
	if entry_type == "friend_request":
		return Color(0.7, 1.0, 0.82, 1.0)
	if entry_type == "item_packet":
		return Color(0.72, 0.86, 1.0, 1.0)
	if entry_type == "fork_notice":
		return Color(1.0, 0.68, 1.0, 1.0)

	return Color(0.9, 0.92, 1.0, 1.0)


func _action_label(action: String) -> String:
	var clean_action: String = str(action).strip_edges().to_lower()

	if clean_action == "enter_live":
		return "Enter Reality"
	if clean_action == "observe_live":
		return "Observe Live"
	if clean_action == "fork_snapshot":
		return "Fork Snapshot"
	if clean_action == "play":
		return "Become Them"
	if clean_action == "observe":
		return "Observe Reality"
	if clean_action == "fork":
		return "Fork Timeline"
	if clean_action == "accept":
		return "Accept Connection"
	if clean_action == "ignore":
		return "Ignore"
	if clean_action == "open":
		return "Open Packet"
	if clean_action == "verify":
		return "Verify"
	if clean_action == "import":
		return "Import"

	return clean_action.capitalize()

func _network_button(text: String, accent: Color) -> Button:
	var button:= Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(132, 38)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", _button_style(Color(0.1, 0.11, 0.13, 0.92), Color(accent.r, accent.g, accent.b, 0.48)))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.16, 0.17, 0.21, 0.98), Color(accent.r, accent.g, accent.b, 0.9)))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.06, 0.06, 0.08, 0.98), Color(accent.r, accent.g, accent.b, 1.0)))
	button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.94))
	return button


func _tile_action_button(text: String, accent: Color) -> Button:
	var button:= _network_button(text, accent)
	button.custom_minimum_size = Vector2(142, 34)
	return button


func _mini_button(text: String) -> Button:
	var button:= Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(88, 30)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", _button_style(Color(0.12, 0.12, 0.15, 0.88), Color(1.0, 1.0, 1.0, 0.24)))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.18, 0.18, 0.22, 0.96), Color(1.0, 1.0, 1.0, 0.6)))
	button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
	return button

func _bind_reality_tile_hover_motion(control: Control, entry: Dictionary) -> void:
	control.mouse_entered.connect(func ():
		if control == null or not is_instance_valid(control):
			return
		control.add_theme_stylebox_override("panel", _tile_style_hover(entry))
		var tween:= create_tween()
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(control, "scale", Vector2(1.014, 1.014), 0.12)
	)
	control.mouse_exited.connect(func ():
		if control == null or not is_instance_valid(control):
			return
		control.add_theme_stylebox_override("panel", _tile_style(entry))
		var tween:= create_tween()
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(control, "scale", Vector2(1.0, 1.0), 0.12)
	)


func _play_reality_tile_arrival(tile: Control, tile_index: int = 0) -> void:
	if tile == null or not is_instance_valid(tile):
		return

	tile.modulate = Color(1.0, 1.0, 1.0, 0.0)
	tile.scale = Vector2(0.972, 0.972)

	var tween:= create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_interval(min(0.24, float(tile_index) * 0.045))
	tween.tween_property(tile, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.16)
	tween.parallel().tween_property(tile, "scale", Vector2(1.0, 1.0), 0.2)
func _bind_hover_motion(control: Control) -> void:
	control.mouse_entered.connect(func ():
		if control == null or not is_instance_valid(control):
			return
		var tween:= create_tween()
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(control, "scale", Vector2(1.012, 1.012), 0.12)
	)
	control.mouse_exited.connect(func ():
		if control == null or not is_instance_valid(control):
			return
		var tween:= create_tween()
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(control, "scale", Vector2(1.0, 1.0), 0.12)
	)


func _transparent_panel_style() -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(0)
	style.shadow_size = 0
	return style


func _portal_surface_style() -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.014, 0.02, 0.28)
	style.border_color = Color(1.0, 1.0, 1.0, 0.3)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.7)
	style.shadow_size = 34
	return style


func _header_style() -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.028, 0.032, 0.044, 0.72)
	style.border_color = Color(0.84, 0.9, 1.0, 0.26)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.shadow_color = Color(0.55, 0.72, 1.0, 0.1)
	style.shadow_size = 12
	return style


func _tool_band_style() -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.02, 0.03, 0.54)
	style.border_color = Color(1.0, 1.0, 1.0, 0.12)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	return style

func _stream_style(side_panel: bool = false) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.02, 0.03, 0.46) if not side_panel else Color(0.02, 0.022, 0.032, 0.38)
	style.border_color = Color(1.0, 1.0, 1.0, 0.1)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	return style

func _tile_style(entry: Dictionary) -> StyleBoxFlat:
	var accent: Color = _entry_accent(entry)
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.044, 0.058, 0.78)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.42)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.13)
	style.shadow_size = 12
	return style
func _tile_style_hover(entry: Dictionary) -> StyleBoxFlat:
	var accent: Color = _entry_accent(entry)
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.058, 0.064, 0.084, 0.88)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.82)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.28)
	style.shadow_size = 20
	return style


func _empty_state_style() -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.038, 0.05, 0.68)
	style.border_color = Color(1.0, 1.0, 1.0, 0.14)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style


func _result_style() -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.038, 0.042, 0.056, 0.62)
	style.border_color = Color(0.78, 0.84, 1.0, 0.22)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	return style
func _portal_depth_style() -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(1.0, 1.0, 1.0, 0.08)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	style.shadow_size = 26
	return style


func _line_edit_style() -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.38)
	style.border_color = Color(1.0, 1.0, 1.0, 0.28)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style


func _button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style


func _swirl_material() -> ShaderMaterial:
	var shader:= Shader.new()

	shader.code = "\nshader_type canvas_item;\n\nuniform vec2 pointer = vec2(0.5, 0.5);\n\nvoid fragment() {\n\tvec2 uv = (UV - vec2(0.5)) * 1.42;\n\tvec2 pull = (pointer - vec2(0.5)) * 0.14;\n\tuv += pull;\n\n\tfloat r = length(uv);\n\tfloat t = TIME * 0.12;\n\n\tfloat wave_a = sin((uv.x * 16.0) + (uv.y * 9.0) + (r * 34.0) - (t * 4.0));\n\tfloat wave_b = cos((uv.x * -11.0) + (uv.y * 15.0) - (r * 26.0) + (t * 2.4));\n\tfloat wave_c = sin(((uv.x + uv.y) * 18.0) + (r * 18.0) + (t * 3.2));\n\n\tfloat smoke = (wave_a * 0.46) + (wave_b * 0.34) + (wave_c * 0.20);\n\tfloat white = smoothstep(-0.10, 0.24, smoke);\n\n\tfloat center_fade = smoothstep(1.08, 0.18, r);\n\tfloat edge_fade = smoothstep(1.18, 0.36, r);\n\tfloat alpha = 0.24 * center_fade * edge_fade;\n\n\tCOLOR = vec4(vec3(white), alpha);\n}\n"


























	var shader_material:= ShaderMaterial.new()
	shader_material.resource_local_to_scene = true
	shader_material.shader = shader
	shader_material.set_shader_parameter("pointer", last_pointer_position)
	return shader_material
func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()
func prepare_for_hidden_open() -> void:
	visible = false
	modulate = Color(1.0, 1.0, 1.0, 0.0)
	self_modulate = Color(1.0, 1.0, 1.0, 0.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", _transparent_panel_style())

	if portal_surface != null and is_instance_valid(portal_surface):
		portal_surface.modulate = Color(1.0, 1.0, 1.0, 0.0)