extends Control
class_name GodModeViewer

signal close_requested
signal prewarm_requested(panel_state: Dictionary, reason: String)
signal handoff_requested(panel_state: Dictionary, reason: String)
signal residency_candidate_changed(
	panel_state: Dictionary,
	reason: String
)
var engine: GodModeContractEngine = null

const GOD_MODE_VIEWER_MODAL_Z_INDEX:= 2400
const GOD_MODE_VIEWER_PANEL_MARGIN:= 0.0
const GOD_MODE_VIEWER_SCROLLBAR_FADE_IN_SECONDS:= 0.08
const GOD_MODE_VIEWER_SCROLLBAR_FADE_OUT_SECONDS:= 0.34
const GOD_MODE_VIEWER_TITLE_GLITCH_INTERVAL_MS:= 5000
const GOD_MODE_VIEWER_TITLE_GLITCH_DURATION_MS:= 260
const GOD_MODE_VIEWER_RESIDENCY_OBSERVE_INTERVAL_MS:= 90
const GOD_MODE_VIEWER_RESIDENCY_STABILITY_MS:= 180

const GOD_MODE_VIEWER_RED_BONNET_START_TEST_VISIBLE:= false

var residency_candidate_pending_signature: String = ""
var residency_candidate_last_emitted_signature: String = ""
var residency_candidate_stable_since_ms: int = 0
var residency_candidate_next_observe_ms: int = 0
var background_dim: ColorRect = null
var panel: PanelContainer = null
var margin: MarginContainer = null
var scroll: ScrollContainer = null
var scroll_bar: VScrollBar = null
var root: VBoxContainer = null

var title_label: Label = null
var subtitle_label: RichTextLabel = null

var scrollbar_fade_tween: Tween = null
var scrollbar_target_alpha: float = 0.0
var scrollbar_last_value: float = 0.0
var scrollbar_last_activity_ms: int = 0

var visual_phase: float = 0.0
var title_base_text: String = "CHOOSE YOUR EREALITY"
var title_glitch_next_ms: int = 0
var title_glitch_until_ms: int = 0

var panel_visual_ready: bool = false
var prebuilt_panel_state_signature: String = ""
var status_label: Label = null
var preview_label: Label = null
var progress_bar: ProgressBar = null

var realistic_button: Button = null
var enhanced_button: Button = null
var fantasy_button: Button = null

var first_name_edit: LineEdit = null
var last_name_edit: LineEdit = null
var gender_picker: OptionButton = null
var birth_year_spin: SpinBox = null
var birth_year_picker: OptionButton = null
var birth_year_custom_row: HBoxContainer = null
var birth_year_custom_edit: LineEdit = null
var birth_month_picker: OptionButton = null
var birth_day_spin: SpinBox = null
var bending_type_picker: OptionButton = null
var era_picker: OptionButton = null
var country_picker: OptionButton = null
var state_picker: OptionButton = null
var city_picker: OptionButton = null
var social_class_picker: OptionButton = null
var royal_rank_row: HBoxContainer = null
var royal_rank_picker: OptionButton = null
var presidential_parents_check: CheckBox = null

var happiness_slider: HSlider = null
var health_slider: HSlider = null
var smarts_slider: HSlider = null
var looks_slider: HSlider = null
var mental_health_slider: HSlider = null
var fertility_slider: HSlider = null
var bank_balance_picker: OptionButton = null

var feature_checks: Dictionary = {}
var celestial_power_sandbox_configured: bool = false
var celestial_power_sandbox_button: Button = null
var celestial_power_sandbox_panel: PanelContainer = null
var celestial_power_receiver_picker: OptionButton = null
var celestial_power_origin_picker: OptionButton = null
var celestial_primary_power_picker: OptionButton = null
var celestial_power_rarity_picker: OptionButton = null
var celestial_power_public_identity_picker: OptionButton = null
var celestial_power_awakening_picker: OptionButton = null
var celestial_power_inheritance_picker: OptionButton = null
var celestial_power_summary_label: Label = null
var prewarm_button: Button = null
var ready_button: Button = null
var back_button: Button = null

var selected_reality_mode: String = "chaos"
var sync_guard: bool = false
var location_contract_refresh_guard: bool = false
var last_rendered_lifecycle: String = ""
const GOD_MODE_VIEWER_ENGINE_SYNC_REFRESH_MS:= 60
const GOD_MODE_VIEWER_SUBTITLE_REFRESH_MS:= 120
const GOD_MODE_VIEWER_STAT_VISUAL_REFRESH_MS:= 80
const GOD_MODE_VIEWER_PREVIEW_VISUAL_REFRESH_MS:= 34
const GOD_MODE_VIEWER_MODE_NORMAL_HEIGHT:= 70.0
const GOD_MODE_VIEWER_MODE_SELECTED_HEIGHT:= 84.0

var next_engine_sync_ms: int = 0
var next_subtitle_visual_ms: int = 0
var next_stat_visual_ms: int = 0
var next_preview_visual_ms: int = 0

var stat_slider_visuals_dirty: bool = true
var preview_visual_dirty: bool = true

var prewarm_button_fill: ColorRect = null
var prewarm_button_label: Label = null
var prewarm_visual_progress: float = 0.0
const GOD_MODE_VIEWER_SCROLL_WHEEL_PIXELS:= 92
const GOD_MODE_VIEWER_TRACKPAD_MULTIPLIER:= 5.0
const GOD_MODE_VIEWER_SCROLL_ACTIVITY_HOLD_MS:= 150
const GOD_MODE_VIEWER_STAT_MOTION_REFRESH_MS:= 34
const GOD_MODE_VIEWER_HOT_SCROLL_ANIMATION_PAUSE_MS:= 260
const GOD_MODE_VIEWER_ENGINE_SYNC_IDLE_MS:= 180
const GOD_MODE_VIEWER_ENGINE_SYNC_PREWARM_MS:= 90

var last_input_scroll_ms: int = 0
var last_engine_lifecycle_seen: String = ""
var next_stat_motion_ms: int = 0
var starting_infinity_stones: int = 0
var infinity_stone_buttons: Array = []
var red_bonnet_check: CheckBox = null
func bind_contract_engine(_engine: GodModeContractEngine) -> void:
	engine = _engine
	_sync_from_engine()

func prebuild_hidden(
	settings: Dictionary = {},
	reason: String = "god_mode_viewer_prebuild_hidden"
) -> void:
	if panel == null or not is_instance_valid(panel):
		_build()


	_force_hidden_prebuilt_surface(
		reason
	)

	panel_visual_ready = true
	prebuilt_panel_state_signature = (
		_settings_visual_signature(
			settings
		)
	)

	set_meta(
		"god_mode_viewer_prebuilt_hidden",
		true
	)
	set_meta(
		"god_mode_viewer_prebuilt_hidden_reason",
		reason
	)
	set_meta(
		"god_mode_viewer_prebuilt_hidden_at_ms",
		int(
			Time.get_ticks_msec()
		)
	)
	set_meta(
		"god_mode_viewer_prebuild_sync_deferred",
		true
	)

	call_deferred(
		"_deferred_finish_hidden_prebuild",
		settings.duplicate(true),
		reason
	)


func _deferred_finish_hidden_prebuild(
	settings: Dictionary,
	reason: String
) -> void:
	_apply_settings(
		settings
	)
	_refresh_location_pickers()
	_refresh_preview()
	_sync_from_engine()
	_apply_palette(
		visible
	)
	_update_subtitle_rich_text()
	_ensure_prewarm_button_layers()

	prebuilt_panel_state_signature = (
		_settings_visual_signature(
			settings
		)
	)

	if not visible:
		_force_hidden_prebuilt_surface(
			reason
		)

	set_meta(
		"god_mode_viewer_prebuild_sync_deferred",
		false
	)
	set_meta(
		"god_mode_viewer_prebuild_sync_complete_at_ms",
		int(
			Time.get_ticks_msec()
		)
	)

func _observe_residency_candidate(
	now_ms: int
) -> void:
	if now_ms < residency_candidate_next_observe_ms:
		return

	residency_candidate_next_observe_ms = (
		now_ms
		+ GOD_MODE_VIEWER_RESIDENCY_OBSERVE_INTERVAL_MS
	)

	var panel_state: Dictionary = _collect_panel_state()
	var signature: String = _settings_visual_signature(
		panel_state
	)

	if signature == "":
		return

	if signature != residency_candidate_pending_signature:
		residency_candidate_pending_signature = signature
		residency_candidate_stable_since_ms = now_ms
		return

	if (
		now_ms - residency_candidate_stable_since_ms
		< GOD_MODE_VIEWER_RESIDENCY_STABILITY_MS
	):
		return

	if signature == residency_candidate_last_emitted_signature:
		return

	residency_candidate_last_emitted_signature = signature

	residency_candidate_changed.emit(
		panel_state.duplicate(true),
		"god_mode_viewer_stable_candidate"
	)

func present_as_modal(
	settings: Dictionary = {},
	reason: String = "god_mode_viewer_present"
) -> void:
	var hot_prebuilt: bool = (
		panel != null
		and is_instance_valid(panel)
		and bool(
			get_meta(
				"god_mode_viewer_prebuilt_hidden",
				false
			)
		)
	)

	if panel == null or not is_instance_valid(panel):
		_build()
		panel_visual_ready = true


	_force_modal_surface(
		reason
	)
	set_process(
		true
	)

	var incoming_signature: String = (
		_settings_visual_signature(
			settings
		)
	)
	var settings_changed: bool = (
		incoming_signature != ""
		and incoming_signature
		!= prebuilt_panel_state_signature
	)

	if settings_changed:
		call_deferred(
			"_deferred_apply_settings_after_visible",
			settings.duplicate(true),
			reason
		)
	else:
		call_deferred(
			"_deferred_sync_visible_god_mode_viewer_after_door_open",
			settings.duplicate(true),
			reason
		)

	set_meta(
		"god_mode_viewer_presented_from_hot_surface",
		hot_prebuilt
	)
	set_meta(
		"god_mode_viewer_present_press_frame_build_forbidden",
		true
	)
	set_meta(
		"god_mode_viewer_present_press_frame_sync_forbidden",
		true
	)
	set_meta(
		"god_mode_viewer_present_reason",
		reason
	)
	set_meta(
		"god_mode_viewer_present_at_ms",
		int(
			Time.get_ticks_msec()
		)
	)
func _deferred_sync_visible_god_mode_viewer_after_door_open(_settings: Dictionary = {}, reason: String = "god_mode_viewer_visible_sync") -> void:
	if not visible:
		return

	_sync_from_engine()
	_update_subtitle_rich_text()
	_apply_palette(false)
	_ensure_prewarm_button_layers()

	set_meta("god_mode_viewer_visible_sync_deferred", true)
	set_meta("god_mode_viewer_visible_sync_reason", reason)
	set_meta("god_mode_viewer_visible_sync_at_ms", int(Time.get_ticks_msec()))

func open_with_settings(settings: Dictionary = {}) -> void:
	present_as_modal(settings, "open_with_settings")


func close() -> void:
	_force_hidden_prebuilt_surface("close")
	set_meta("god_mode_viewer_modal_visible", false)
	set_meta("god_mode_viewer_closed_at_ms", int(Time.get_ticks_msec()))


func _force_hidden_prebuilt_surface(reason: String = "hidden_prebuilt") -> void:
	set_process(false)

	hide()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE

	if background_dim != null and is_instance_valid(background_dim):
		background_dim.visible = false
		background_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if panel != null and is_instance_valid(panel):
		panel.visible = false
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if back_button != null and is_instance_valid(back_button):
		back_button.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if scroll_bar != null and is_instance_valid(scroll_bar):
		scroll_bar.modulate.a = 0.0

	set_meta("god_mode_viewer_hidden_prebuilt_surface", true)
	set_meta("god_mode_viewer_hidden_prebuilt_surface_reason", reason)
	set_meta("god_mode_viewer_hidden_prebuilt_surface_at_ms", int(Time.get_ticks_msec()))


func _deferred_apply_settings_after_visible(settings: Dictionary, reason: String = "visible_settings_refresh") -> void:
	_apply_settings(settings)
	_refresh_location_pickers()
	_refresh_preview()
	_sync_from_engine()
	_apply_palette(true)
	_update_subtitle_rich_text()

	prebuilt_panel_state_signature = _settings_visual_signature(settings)
	set_meta("god_mode_viewer_visible_settings_refresh_reason", reason)


func _settings_visual_signature(settings: Dictionary) -> String:
	if typeof(settings) != TYPE_DICTIONARY:
		return ""
	return str(settings)

func _force_modal_surface(reason: String = "god_mode_viewer_modal") -> void:
	set_process(true)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	visible = true
	show()
	modulate = Color(1.0, 1.0, 1.0, 1.0)

	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL

	top_level = true
	z_as_relative = false
	z_index = max(int(z_index), GOD_MODE_VIEWER_MODAL_Z_INDEX)

	var parent_node:= get_parent()
	if parent_node != null:
		parent_node.move_child(self, parent_node.get_child_count() - 1)

	if background_dim != null and is_instance_valid(background_dim):
		background_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		background_dim.visible = true
		background_dim.mouse_filter = Control.MOUSE_FILTER_STOP
		background_dim.modulate = Color(1.0, 1.0, 1.0, 1.0)

	if panel != null and is_instance_valid(panel):
		panel.visible = true
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.modulate = Color(1.0, 1.0, 1.0, 1.0)
		panel.z_as_relative = false
		panel.z_index = GOD_MODE_VIEWER_MODAL_Z_INDEX + 2

	if scroll != null and is_instance_valid(scroll):
		scroll.visible = true
		scroll.mouse_filter = Control.MOUSE_FILTER_STOP

	if root != null and is_instance_valid(root):
		root.visible = true
		root.mouse_filter = Control.MOUSE_FILTER_PASS

	if back_button != null and is_instance_valid(back_button):
		back_button.mouse_filter = Control.MOUSE_FILTER_STOP

	stat_slider_visuals_dirty = true
	preview_visual_dirty = true

	set_meta("god_mode_viewer_modal_visible", true)
	set_meta("god_mode_viewer_modal_reason", reason)
	set_meta("god_mode_viewer_modal_at_ms", int(Time.get_ticks_msec()))

	call_deferred("grab_focus")
func reset_runtime_seed_state(reason: String = "main_menu_return") -> void:
	last_rendered_lifecycle = ""
	last_engine_lifecycle_seen = "idle"
	prewarm_visual_progress = 0.0

	if status_label != null and is_instance_valid(status_label):
		status_label.text = "No world seed has been committed yet."

	if progress_bar != null and is_instance_valid(progress_bar):
		progress_bar.value = 0.0

	if prewarm_button_fill != null and is_instance_valid(prewarm_button_fill):
		prewarm_button_fill.visible = false
		prewarm_button_fill.anchor_left = 0.0
		prewarm_button_fill.anchor_right = 0.0

	if prewarm_button_label != null and is_instance_valid(prewarm_button_label):
		prewarm_button_label.text = "Pre warm world seed"

	if prewarm_button != null and is_instance_valid(prewarm_button):
		prewarm_button.text = "Pre warm world seed"
		prewarm_button.disabled = false
		prewarm_button.mouse_filter = Control.MOUSE_FILTER_STOP
		prewarm_button.set_meta("viewer_ready_button_enabled", false)
		prewarm_button.set_meta("viewer_prewarm_ready_but_door_latch_pending", false)

	if ready_button != null and is_instance_valid(ready_button):
		ready_button.visible = false
		ready_button.disabled = true
		ready_button.mouse_filter = Control.MOUSE_FILTER_IGNORE

	set_meta("god_mode_viewer_seed_reset_after_main_menu_return", true)
	set_meta("god_mode_viewer_seed_reset_reason", reason)
	set_meta("god_mode_viewer_seed_reset_at_ms", int(Time.get_ticks_msec()))
	set_meta("god_mode_viewer_must_prewarm_new_seed", true)
func request_prewarm_from_current_state(
		reason: String = "viewer_prewarm_button"
) -> Dictionary:
	var now_ms: int = int(
		Time.get_ticks_msec()
	)
	var request_id: int = int(
		get_meta(
			"viewer_prewarm_press_request_sequence",
			0
		)
	) + 1
	var status_text: String = (
		"Prewarm request received. Selecting your resident reality."
	)

	set_meta(
		"viewer_prewarm_press_request_sequence",
		request_id
	)
	set_meta(
		"viewer_prewarm_press_visual_acknowledged",
		true
	)
	set_meta(
		"viewer_prewarm_press_visual_acknowledged_reason",
		reason
	)
	set_meta(
		"viewer_prewarm_press_visual_acknowledged_at_ms",
		now_ms
	)
	set_meta(
		"viewer_prewarm_press_dispatch_pending",
		true
	)
	set_meta(
		"viewer_prewarm_press_dispatch_request_id",
		request_id
	)



	last_engine_lifecycle_seen = "prewarm_requested"
	last_rendered_lifecycle = "prewarm_requested"
	next_engine_sync_ms = now_ms + 250

	if (
		status_label != null
		and is_instance_valid(
			status_label
		)
	):
		status_label.text = status_text

	_update_prewarm_button_visual(
		0.02,
		"prewarm_requested",
		status_text,
		false
	)

	if (
		ready_button != null
		and is_instance_valid(
			ready_button
		)
	):
		ready_button.visible = false
		ready_button.disabled = true
		ready_button.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)

	queue_redraw()

	if (
		prewarm_button != null
		and is_instance_valid(
			prewarm_button
		)
	):
		prewarm_button.queue_redraw()



	var dispatch_callable: Callable = Callable(
		self,
		"_dispatch_prewarm_request_after_press_paint"
	).bind(
		reason,
		request_id
	)
	var connection_error: int = (
		RenderingServer.frame_post_draw.connect(
			dispatch_callable,
			CONNECT_ONE_SHOT
		)
	)

	if connection_error != OK:
		call_deferred(
			"_dispatch_prewarm_request_after_press_paint",
			reason,
			request_id
		)

	return {
		"success": true,
		"mode": (
			"god_mode_viewer_prewarm_press_acknowledged"
		),
		"reason": reason,
		"request_id": request_id,
	}
func _dispatch_prewarm_request_after_press_paint(
		reason: String,
		request_id: int
) -> void:
	if request_id != int(
		get_meta(
			"viewer_prewarm_press_dispatch_request_id",
			-1
		)
	):
		return

	if not bool(
		get_meta(
			"viewer_prewarm_press_dispatch_pending",
			false
		)
	):
		return

	set_meta(
		"viewer_prewarm_press_dispatch_pending",
		false
	)
	set_meta(
		"viewer_prewarm_press_dispatch_started_at_ms",
		int(
			Time.get_ticks_msec()
		)
	)

	var state: Dictionary = _collect_panel_state()
	var published_state: Dictionary = (
		state.duplicate(true)
	)

	prewarm_requested.emit(
		published_state,
		reason
	)

	set_meta(
		"viewer_prewarm_press_dispatch_complete",
		true
	)
	set_meta(
		"viewer_prewarm_press_dispatch_complete_at_ms",
		int(
			Time.get_ticks_msec()
		)
	)
	set_meta(
		"viewer_prewarm_press_painted_before_dispatch",
		true
	)



	next_engine_sync_ms = 0

func request_handoff_from_current_state(
		reason: String = "viewer_ready_button"
) -> Dictionary:
	var now_ms: int = int(
		Time.get_ticks_msec()
	)
	var door_request: Dictionary = {
		"success": true,
		"schema": "eralife.god_mode.ready_door_request",
		"version": 1,
		"mode": "god_mode_viewer_handoff_requested",
		"reason": reason,
		"requested_at_ms": now_ms,
		"viewer_instance_id": int(
			get_instance_id()
		),
		"ready_button_is_door": true,
	}

	set_meta(
		"viewer_ready_door_request_emitted",
		true
	)
	set_meta(
		"viewer_ready_door_request_reason",
		reason
	)
	set_meta(
		"viewer_ready_door_request_emitted_at_ms",
		now_ms
	)
	set_meta(
		"viewer_ready_door_request_panel_state_capture_performed",
		false
	)
	set_meta(
		"viewer_ready_door_request_deep_copy_performed",
		false
	)



	handoff_requested.emit(
		door_request,
		reason
	)

	return door_request
func apply_presentation_surface_contract(
	surface_contract: Dictionary
) -> void:
	if (
		panel == null
		or not is_instance_valid(
			panel
		)
	):
		return

	var fills_stage: bool = bool(
		surface_contract.get(
			"fills_stage",
			true
		)
	)

	if fills_stage:
		panel.set_anchors_and_offsets_preset(
			Control.PRESET_FULL_RECT
		)

		panel.offset_left = 0.0
		panel.offset_top = 0.0
		panel.offset_right = 0.0
		panel.offset_bottom = 0.0

		panel.set_meta(
			"presentation_composition_contract_applied",
			true
		)
		panel.set_meta(
			"presentation_composition_fills_stage",
			true
		)
		panel.set_meta(
			"presentation_composition_source",
			str(
				surface_contract.get(
					"source",
					"presentation_composition"
				)
			)
		)

		return

	var panel_left: float = float(
		surface_contract.get(
			"panel_left",
			0.0
		)
	)

	var panel_top: float = float(
		surface_contract.get(
			"panel_top",
			0.0
		)
	)

	var panel_right: float = float(
		surface_contract.get(
			"panel_right",
			0.0
		)
	)

	var panel_bottom: float = float(
		surface_contract.get(
			"panel_bottom",
			0.0
		)
	)

	if (
		panel_right <= panel_left
		or panel_bottom <= panel_top
	):
		return

	panel.anchor_left = 0.0
	panel.anchor_right = 0.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0

	panel.offset_left = panel_left
	panel.offset_right = panel_right
	panel.offset_top = panel_top
	panel.offset_bottom = panel_bottom

	panel.set_meta(
		"presentation_composition_contract_applied",
		true
	)
	panel.set_meta(
		"presentation_composition_fills_stage",
		false
	)
	panel.set_meta(
		"presentation_composition_source",
		str(
			surface_contract.get(
				"source",
				"presentation_composition"
			)
		)
	)
func _input(event: InputEvent) -> void:
	if not visible:
		return

	if scroll == null or not is_instance_valid(scroll):
		return

	if not _god_mode_pointer_inside_panel():
		return

	if _scroll_god_mode_viewer_from_event(event, "viewer_input"):
		get_viewport().set_input_as_handled()

func _process(
	delta: float
) -> void:
	if not visible:
		return

	visual_phase += delta

	var now_ms: int = int(
		Time.get_ticks_msec()
	)



	_observe_residency_candidate(
		now_ms
	)


	_tick_avatar_bending_picker_border()

	var scroll_is_hot: bool = (
		_god_mode_scroll_is_hot(
			now_ms
		)
	)

	if now_ms >= next_engine_sync_ms:
		var lifecycle_hint: String = (
			last_engine_lifecycle_seen
		)
		var sync_delay_ms: int = (
			GOD_MODE_VIEWER_ENGINE_SYNC_PREWARM_MS
			if lifecycle_hint == "prewarm_requested"
			else GOD_MODE_VIEWER_ENGINE_SYNC_IDLE_MS
		)
		next_engine_sync_ms = (
			now_ms + sync_delay_ms
		)

		_sync_from_engine()

	_tick_scrollbar_visibility()

	if scroll_is_hot:
		return

	_tick_title_glitch()
	_tick_prewarm_button_energy()

	if (
		preview_visual_dirty
		or now_ms >= next_preview_visual_ms
	):
		next_preview_visual_ms = (
			now_ms
			+ GOD_MODE_VIEWER_PREVIEW_VISUAL_REFRESH_MS
		)
		preview_visual_dirty = false

		_tick_preview_label_visuals()

	if now_ms >= next_subtitle_visual_ms:
		next_subtitle_visual_ms = (
			now_ms
			+ GOD_MODE_VIEWER_SUBTITLE_REFRESH_MS
		)

		_update_subtitle_rich_text()

	if stat_slider_visuals_dirty:
		stat_slider_visuals_dirty = false

		_tick_stat_slider_visuals()

	if now_ms >= next_stat_motion_ms:
		next_stat_motion_ms = (
			now_ms
			+ GOD_MODE_VIEWER_STAT_MOTION_REFRESH_MS
		)

		_tick_stat_energy_bar_motion()
func _ensure_avatar_bending_picker_border() -> Dictionary:
	if (
		bending_type_picker == null
		or not is_instance_valid(
			bending_type_picker
		)
	):
		return {}

	var existing_raw: Variant = (
		bending_type_picker.get_meta(
			"avatar_bending_picker_border",
			{}
		)
	)

	if typeof(existing_raw) == TYPE_DICTIONARY:
		var existing: Dictionary = (
			existing_raw as Dictionary
		)

		var existing_hot: bool = true

		for key in [
			"top",
			"right",
			"bottom",
			"left"
		]:
			var edge_raw: Variant = existing.get(
				key,
				null
			)

			if (
				not (edge_raw is ColorRect)
				or not is_instance_valid(
					edge_raw as ColorRect
				)
			):
				existing_hot = false
				break

		if existing_hot:
			return existing

	var top:= ColorRect.new()
	var right:= ColorRect.new()
	var bottom:= ColorRect.new()
	var left:= ColorRect.new()

	for edge in [
		top,
		right,
		bottom,
		left
	]:
		edge.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)
		edge.z_index = 12
		edge.visible = false
		bending_type_picker.add_child(
			edge
		)

	top.anchor_left = 0.0
	top.anchor_top = 0.0
	top.anchor_right = 1.0
	top.anchor_bottom = 0.0
	top.offset_left = 0.0
	top.offset_top = 0.0
	top.offset_right = 0.0
	top.offset_bottom = 3.0

	right.anchor_left = 1.0
	right.anchor_top = 0.0
	right.anchor_right = 1.0
	right.anchor_bottom = 1.0
	right.offset_left = -3.0
	right.offset_top = 0.0
	right.offset_right = 0.0
	right.offset_bottom = 0.0

	bottom.anchor_left = 0.0
	bottom.anchor_top = 1.0
	bottom.anchor_right = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_left = 0.0
	bottom.offset_top = -3.0
	bottom.offset_right = 0.0
	bottom.offset_bottom = 0.0

	left.anchor_left = 0.0
	left.anchor_top = 0.0
	left.anchor_right = 0.0
	left.anchor_bottom = 1.0
	left.offset_left = 0.0
	left.offset_top = 0.0
	left.offset_right = 3.0
	left.offset_bottom = 0.0

	var border: Dictionary = {
		"top": top,
		"right": right,
		"bottom": bottom,
		"left": left
	}

	bending_type_picker.set_meta(
		"avatar_bending_picker_border",
		border
	)

	return border


func _tick_avatar_bending_picker_border() -> void:
	if (
		bending_type_picker == null
		or not is_instance_valid(
			bending_type_picker
		)
	):
		return

	var border: Dictionary = (
		_ensure_avatar_bending_picker_border()
	)

	if border.is_empty():
		return

	var avatar_selected: bool = (
		_selected_text(
			bending_type_picker
		).strip_edges().to_lower()
		== "avatar"
	)

	var top: ColorRect = (
		border.get(
			"top",
			null
		) as ColorRect
	)
	var right: ColorRect = (
		border.get(
			"right",
			null
		) as ColorRect
	)
	var bottom: ColorRect = (
		border.get(
			"bottom",
			null
		) as ColorRect
	)
	var left: ColorRect = (
		border.get(
			"left",
			null
		) as ColorRect
	)

	for edge in [
		top,
		right,
		bottom,
		left
	]:
		if (
			edge != null
			and is_instance_valid(
				edge
			)
		):
			edge.visible = avatar_selected

	if not avatar_selected:
		return


	var pulse: float = (
		0.5
		+ (
			sin(
				visual_phase * 1.35
			)
			* 0.5
		)
	)
	var alpha: float = lerpf(
		0.38,
		0.92,
		pulse
	)


	top.color = Color(
		0.88,
		0.94,
		1.0,
		alpha
	)
	right.color = Color(
		1.0,
		0.18,
		0.08,
		alpha
	)
	bottom.color = Color(
		0.35,
		0.82,
		0.28,
		alpha
	)
	left.color = Color(
		0.16,
		0.56,
		1.0,
		alpha
	)
func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	visible = true
	show()
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	top_level = true
	z_as_relative = false
	z_index = GOD_MODE_VIEWER_MODAL_Z_INDEX

	background_dim = ColorRect.new()
	background_dim.name = "GodModeViewerDim"
	background_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background_dim.color = Color(0.002, 0.012, 0.018, 0.985)
	background_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	background_dim.z_as_relative = false
	background_dim.z_index = GOD_MODE_VIEWER_MODAL_Z_INDEX + 1
	add_child(background_dim)

	panel = PanelContainer.new()
	panel.name = "GodModeViewerPanel"
	panel.anchor_left = GOD_MODE_VIEWER_PANEL_MARGIN
	panel.anchor_top = GOD_MODE_VIEWER_PANEL_MARGIN
	panel.anchor_right = 1.0 - GOD_MODE_VIEWER_PANEL_MARGIN
	panel.anchor_bottom = 1.0 - GOD_MODE_VIEWER_PANEL_MARGIN
	panel.offset_left = 0.0
	panel.offset_top = 0.0
	panel.offset_right = 0.0
	panel.offset_bottom = 0.0
	panel.visible = true
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.focus_mode = Control.FOCUS_ALL
	panel.z_as_relative = false
	panel.z_index = GOD_MODE_VIEWER_MODAL_Z_INDEX + 2
	add_child(panel)

	margin = MarginContainer.new()
	margin.name = "GodModeViewerMargin"
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	scroll = ScrollContainer.new()
	scroll.name = "GodModeViewerScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.clip_contents = true
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll.gui_input.connect(_on_god_mode_scroll_gui_input)
	margin.add_child(scroll)

	scroll_bar = scroll.get_v_scroll_bar()
	if scroll_bar != null and is_instance_valid(scroll_bar):
		scroll_bar.modulate.a = 0.0
		scroll_bar.mouse_entered.connect(func () -> void:
			_show_scrollbar_for_activity("mouse_entered")
		)
		scroll_bar.value_changed.connect(_on_scrollbar_value_changed)

	root = VBoxContainer.new()
	root.name = "GodModeViewerRoot"
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 13)
	scroll.add_child(root)

	var header_row:= HBoxContainer.new()
	header_row.name = "GodModeViewerHeaderRow"
	header_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_theme_constant_override("separation", 10)
	root.add_child(header_row)

	back_button = Button.new()
	back_button.name = "GodModeViewerBackButton"
	back_button.text = "←"
	back_button.custom_minimum_size = Vector2(58, 58)
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.mouse_filter = Control.MOUSE_FILTER_STOP
	back_button.pressed.connect(func () -> void:
		close_requested.emit()
	)
	header_row.add_child(back_button)

	var header_spacer:= Control.new()
	header_spacer.name = "GodModeViewerHeaderSpacer"
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(header_spacer)

	title_label = Label.new()
	title_label.name = "GodModeViewerTitle"
	title_label.text = title_base_text
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 34)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(title_label)

	_build_subtitle_rich_label()

	_update_subtitle_rich_text()
	_build_mode_picker()
	_add_section("Identity")

	first_name_edit = _add_line_edit("First Name", "Acrello")
	last_name_edit = _add_line_edit("Last Name", "IsBack")
	gender_picker = _add_picker("Gender", ["Male", "Female", "Nonbinary"])
	gender_picker.item_selected.connect(func (_i: int) -> void:
		_refresh_royal_rank_picker_preserving_selection()
		_refresh_preview()
	)

	_add_section("Birth / Era")

	bending_type_picker = _add_picker("Bending Type", ["None", "Air", "Water", "Earth", "Fire"])
	bending_type_picker.item_selected.connect(func (_i: int) -> void:
		_style_bending_type_picker()
		_refresh_preview()
	)

	birth_year_picker = _add_picker("Birth Year", _birth_year_preset_options())
	birth_year_picker.item_selected.connect(func (_i: int) -> void:
		_on_birth_year_picker_changed()
	)

	birth_year_custom_row = _row("Custom Year")
	birth_year_custom_edit = LineEdit.new()
	birth_year_custom_edit.text = "79 AD"
	birth_year_custom_edit.placeholder_text = "Type 33 BCE, 40 AD, 2086, or -33."
	birth_year_custom_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	birth_year_custom_edit.set_meta("god_mode_form_control", true)
	birth_year_custom_edit.text_changed.connect(func (_text: String) -> void:
		_on_birth_year_custom_text_changed()
	)
	birth_year_custom_row.add_child(birth_year_custom_edit)
	birth_year_custom_row.visible = false

	birth_month_picker = _add_picker("Birth Month", [
		"January", "February", "March", "April", "May", "June",
		"July", "August", "September", "October", "November", "December"
	])
	birth_day_spin = _add_spinbox("Birth Day", 1, 31, 1)

	# FIX: the day spinbox was a fixed 1-31 range with no relationship to the chosen
	# month, so February 31st, April 31st and similar impossible dates could be set.
	# Retune the maximum whenever the month (or the year, for February) changes, and
	# pull the current value down if it no longer fits.
	birth_month_picker.item_selected.connect(
		func (_i: int) -> void:
			_retune_birth_day_range()
	)
	era_picker = _add_picker("Era", _era_options_from_engine())
	social_class_picker = _add_picker("Social Class", [])
	social_class_picker.item_selected.connect(func (_i: int) -> void:
		_refresh_royal_rank_picker_preserving_selection()
		_refresh_presidential_parents_visibility()
		_refresh_preview()
	)

	royal_rank_row = _row("Royal Rank")
	royal_rank_picker = OptionButton.new()
	royal_rank_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	royal_rank_picker.custom_minimum_size = Vector2(0, 38)
	royal_rank_picker.set_meta("god_mode_form_control", true)
	royal_rank_picker.item_selected.connect(func (_i: int) -> void:
		_refresh_preview()
		preview_visual_dirty = true
	)
	royal_rank_row.add_child(royal_rank_picker)
	royal_rank_row.visible = false
	presidential_parents_check = _add_check_box("Presidential parents", false)
	presidential_parents_check.visible = false
	presidential_parents_check.disabled = true
	presidential_parents_check.tooltip_text = "Available for Elite starts in the United States during Industrial, Modern, or Future eras. One parent becomes President; the spouse becomes First Lady or First Gentleman. Family remains elite, not royal."
	presidential_parents_check.toggled.connect(func (_pressed: bool) -> void:
		_on_presidential_parents_toggled(_pressed)
	)
	country_picker = _add_picker("Country", [])
	state_picker = _add_picker("Birth State", [])
	city_picker = _add_picker("City", [])

	_configure_location_picker_popup_scroll(country_picker, 540)
	_configure_location_picker_popup_scroll(state_picker, 460)
	_configure_location_picker_popup_scroll(city_picker, 480)

	_set_picker_row_visible(state_picker, false)
	_set_picker_row_visible(city_picker, true)
	era_picker.item_selected.connect(func (_i: int) -> void:
		if not sync_guard:
			_set_birth_year_controls_from_value(_representative_year_for_era_key(_selected_text(era_picker)))
		_refresh_location_pickers()
		_refresh_social_class_picker_for_location()
		_refresh_presidential_parents_visibility()
		_refresh_preview()
		_apply_palette(true)
	)

	country_picker.item_selected.connect(func (_i: int) -> void:
		_refresh_state_picker_for_country()
		_refresh_city_picker_for_country()
		_style_elemental_location_controls()
		_refresh_social_class_picker_for_location()
		_refresh_presidential_parents_visibility()
		_refresh_preview()
	)
	state_picker.item_selected.connect(func (_i: int) -> void:
		_refresh_city_picker_for_country("", true)
		_refresh_presidential_parents_visibility()
		_refresh_preview()
	)
	city_picker.item_selected.connect(func (_i: int) -> void:
		_resolve_country_from_city()
		_style_elemental_location_controls()
		_refresh_social_class_picker_for_location()
		_refresh_presidential_parents_visibility()
		_refresh_preview()
	)
	_add_section(
		"Stats / Start"
	)

	happiness_slider = _add_slider(
		"Happiness",
		0,
		100,
		50
	)
	health_slider = _add_slider(
		"Health",
		0,
		200,
		100
	)
	smarts_slider = _add_slider(
		"Smarts",
		0,
		100,
		100
	)
	looks_slider = _add_slider(
		"Looks",
		0,
		100,
		100
	)
	mental_health_slider = _add_slider(
		"Mental Health",
		0,
		100,
		100
	)
	fertility_slider = _add_slider(
		"Fertility",
		0,
		100,
		50
	)
	bank_balance_picker = _add_picker(
		"Bank Balance",
		[
			"$0",
			"$500",
			"$10K",
			"$100K",
			"$500K",
			"$1M",
			"$10M"
		]
	)

	_build_infinity_stone_selector()
	red_bonnet_check = _add_check_box(
		"Start With Red Bonnet",
		false,
		GOD_MODE_VIEWER_RED_BONNET_START_TEST_VISIBLE
	)

	_build_celestial_power_sandbox_launcher()

	_add_section(
		"Customize Your Features"
	)

	for feature in ["Bending", "Artifacts", "Dragon Balls", "Many Realms", "Supernatural School", "Supernatural Events"]:
		var check:= CheckBox.new()
		check.text = feature
		check.button_pressed = feature in ["Bending", "Artifacts", "Dragon Balls", "Many Realms", "Supernatural School", "Supernatural Events"]
		check.toggled.connect(func (_pressed: bool) -> void:
			_on_feature_changed()
		)
		feature_checks [feature] = check
		root.add_child(check)

	prewarm_button = Button.new()
	prewarm_button.name = "GodModeViewerPrewarmButton"
	prewarm_button.text = ""
	prewarm_button.custom_minimum_size = Vector2(0, 58)
	prewarm_button.clip_contents = true
	prewarm_button.pressed.connect(func () -> void:
		var prewarm_is_ready: bool = false
		var door_latch_hot: bool = false

		if engine != null:
			var state: Dictionary = engine.current_state()
			prewarm_is_ready = bool(state.get("prewarm_ready", false))
			door_latch_hot = bool(state.get("viewer_ready_button_enabled", false))

		if door_latch_hot:
			request_handoff_from_current_state("god_mode_viewer_ready_button_pressed")
			return

		if prewarm_is_ready:
			set_meta("viewer_ready_press_blocked_until_door_latch_hot", true)
			set_meta("viewer_ready_press_blocked_at_ms", int(Time.get_ticks_msec()))
			return

		request_prewarm_from_current_state("god_mode_viewer_prewarm_button_pressed")
	)
	root.add_child(prewarm_button)
	_ensure_prewarm_button_layers()

	progress_bar = ProgressBar.new()
	progress_bar.name = "GodModeViewerHiddenPrewarmProgress"
	progress_bar.min_value = 0.0
	progress_bar.max_value = 1.0
	progress_bar.value = 0.0
	progress_bar.show_percentage = false
	progress_bar.visible = false
	progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_bar.custom_minimum_size = Vector2.ZERO
	root.add_child(progress_bar)

	status_label = Label.new()
	status_label.text = "No world seed has been committed yet."
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(0, 44)
	root.add_child(status_label)

	preview_label = Label.new()
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_label.custom_minimum_size = Vector2(0, 96)
	preview_label.add_theme_font_size_override("font_size", 18)
	root.add_child(preview_label)

	ready_button = Button.new()
	ready_button.text = "I'm ready to play EraLife"
	ready_button.custom_minimum_size = Vector2(0, 58)
	ready_button.pressed.connect(func () -> void:
		request_handoff_from_current_state("god_mode_viewer_ready_button_pressed")
	)
	root.add_child(ready_button)

	_apply_palette(false)
	_refresh_location_pickers()
	_refresh_preview()
func _build_subtitle_rich_label() -> void:
	if subtitle_label != null and is_instance_valid(subtitle_label):
		return

	subtitle_label = RichTextLabel.new()
	subtitle_label.name = "GodModeViewerSubtitle"
	subtitle_label.bbcode_enabled = true
	subtitle_label.fit_content = true
	subtitle_label.scroll_active = false
	subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subtitle_label.custom_minimum_size = Vector2(0, 42)
	subtitle_label.add_theme_font_size_override("normal_font_size", 15)
	subtitle_label.add_theme_color_override("default_color", Color(0.86, 1.0, 1.0, 0.96))

	root.add_child(subtitle_label)
	_update_subtitle_rich_text()

func _build_mode_picker() -> void:
	var row:= HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)
	root.add_child(row)

	realistic_button = _mode_button("REALISTIC\nGrounded only", "realistic")
	enhanced_button = _mode_button("ENHANCED\nBending abilities", "enhanced")
	fantasy_button = _mode_button("CHAOS\nAnything is possible", "chaos")

	row.add_child(realistic_button)
	row.add_child(enhanced_button)
	row.add_child(fantasy_button)

func _mode_button(text: String, mode: String) -> Button:
	var button:= Button.new()
	var clean_mode: String = _viewer_canonical_reality_mode(mode)

	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, GOD_MODE_VIEWER_MODE_NORMAL_HEIGHT)
	button.focus_mode = Control.FOCUS_NONE
	button.set_meta("god_mode_reality_mode", clean_mode)
	button.set_meta("fantasy_alias_is_chaos", true)

	button.pressed.connect(func () -> void:
		selected_reality_mode = clean_mode
		_apply_mode_constraints(clean_mode)
		_refresh_location_pickers()
		_refresh_preview()
		stat_slider_visuals_dirty = true
		preview_visual_dirty = true
		_apply_palette(true)
	)

	return button


func _add_section(text: String) -> void:
	var label:= Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	root.add_child(label)


func _add_line_edit(label_text: String, default_text: String) -> LineEdit:
	var row:= _row(label_text)
	var edit:= LineEdit.new()
	edit.text = default_text
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text_changed.connect(func (_text: String) -> void:
		_refresh_preview()
	)
	row.add_child(edit)
	return edit


func _add_picker(label_text: String, items: Array) -> OptionButton:
	var row:= _row(label_text)
	var picker:= OptionButton.new()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.custom_minimum_size = Vector2(0, 38)
	picker.set_meta("god_mode_form_control", true)

	for item in items:
		picker.add_item(str(item))

	picker.item_selected.connect(func (_index: int) -> void:
		_refresh_preview()
		preview_visual_dirty = true
	)

	row.add_child(picker)
	return picker


func _add_spinbox(label_text: String, min_value: float, max_value: float, default_value: float) -> SpinBox:
	var row:= _row(label_text)
	var spin:= SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.value = default_value
	spin.step = 1
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.custom_minimum_size = Vector2(0, 38)
	spin.set_meta("god_mode_form_control", true)
	spin.value_changed.connect(func (_value: float) -> void:
		_refresh_preview()
		preview_visual_dirty = true
	)
	row.add_child(spin)
	return spin

func _add_slider(label_text: String, min_value: float, max_value: float, default_value: float) -> HSlider:
	var row:= _row(label_text)

	var shell:= Control.new()
	shell.name = "GodModeEnergyBar_%s" % label_text.strip_edges().replace(" ", "_")
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.custom_minimum_size = Vector2(0, 46)
	shell.clip_contents = true
	shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(shell)

	var track:= PanelContainer.new()
	track.name = "EnergyTrack"
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.anchor_left = 0.0
	track.anchor_top = 0.0
	track.anchor_right = 1.0
	track.anchor_bottom = 1.0
	track.offset_top = 6.0
	track.offset_bottom = -6.0
	shell.add_child(track)

	var fill_clip:= Control.new()
	fill_clip.name = "EnergyFillClip"
	fill_clip.clip_contents = true
	fill_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill_clip.anchor_left = 0.0
	fill_clip.anchor_top = 0.0
	fill_clip.anchor_right = 0.0
	fill_clip.anchor_bottom = 1.0
	fill_clip.offset_top = 6.0
	fill_clip.offset_bottom = -6.0
	shell.add_child(fill_clip)

	var fill_base:= ColorRect.new()
	fill_base.name = "EnergyFillBase"
	fill_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill_base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fill_clip.add_child(fill_base)

	var flow_a:= ColorRect.new()
	flow_a.name = "EnergyFlowA"
	flow_a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill_clip.add_child(flow_a)

	var flow_b:= ColorRect.new()
	flow_b.name = "EnergyFlowB"
	flow_b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill_clip.add_child(flow_b)

	var thumb:= PanelContainer.new()
	thumb.name = "EnergyThumb"
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb.custom_minimum_size = Vector2(9, 26)
	shell.add_child(thumb)

	var value_label:= Label.new()
	value_label.name = "EnergyValueLabel"
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	value_label.offset_right = -14.0
	value_label.add_theme_font_size_override("font_size", 13)
	shell.add_child(value_label)

	var slider:= HSlider.new()
	slider.name = "EnergySliderInput"
	slider.min_value = min_value
	slider.max_value = max_value
	slider.value = default_value
	slider.step = 1
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.mouse_filter = Control.MOUSE_FILTER_PASS
	slider.gui_input.connect(_on_god_mode_scroll_gui_input)
	slider.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slider.modulate = Color(1.0, 1.0, 1.0, 0.01)
	slider.set_meta("god_mode_stat_role", label_text.strip_edges().to_lower().replace(" ", "_"))
	slider.set_meta("god_mode_energy_shell", shell)
	slider.set_meta("god_mode_energy_track", track)
	slider.set_meta("god_mode_energy_fill_clip", fill_clip)
	slider.set_meta("god_mode_energy_fill_base", fill_base)
	slider.set_meta("god_mode_energy_flow_a", flow_a)
	slider.set_meta("god_mode_energy_flow_b", flow_b)
	slider.set_meta("god_mode_energy_thumb", thumb)
	slider.set_meta("god_mode_energy_value_label", value_label)
	slider.value_changed.connect(func (_value: float) -> void:
		_update_stat_energy_bar(slider, true)
		_refresh_preview()
		preview_visual_dirty = true
	)
	shell.add_child(slider)

	_update_stat_energy_bar(slider, true)
	return slider
func _row(label_text: String) -> HBoxContainer:
	var row:= HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)

	var label:= Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(150, 0)
	row.add_child(label)

	root.add_child(row)
	return row

func _viewer_canonical_reality_mode(mode_text: String) -> String:
	var clean_mode: String = str(mode_text).strip_edges().to_lower()

	if clean_mode == "":
		return "chaos"

	if clean_mode == "fantasy":
		return "chaos"

	if clean_mode in ["realistic", "enhanced", "chaos"]:
		return clean_mode

	return "chaos"


func _viewer_reality_mode_label(mode_text: String) -> String:
	match _viewer_canonical_reality_mode(mode_text):
		"realistic":
			return "Realistic"
		"enhanced":
			return "Enhanced"
		"chaos":
			return "Chaos"
		_:
			return "Chaos"


func _viewer_feature_key_to_settings_key(raw_key: Variant) -> String:
	var clean_key: String = str(raw_key).strip_edges().to_lower()
	clean_key = clean_key.replace("-", "_")
	clean_key = clean_key.replace(" ", "_")

	match clean_key:
		"bending":
			return "bending"
		"super_power", "super_powers", "superpower", "superpowers":
			return "superpowers"
		"vampire", "vampires":
			return "vampires"
		"artifact", "artifacts":
			return "artifacts"
		"dragon_ball", "dragon_balls", "dragonball", "dragonballs":
			return "dragonballs"
		"many_realm", "many_realms":
			return "many_realms"
		"supernatural_school":
			return "supernatural_school"
		"supernatural_event", "supernatural_events":
			return "supernatural_events"
		_:
			return ""


func _viewer_default_feature_state_for_mode(mode_text: String) -> Dictionary:
	match _viewer_canonical_reality_mode(mode_text):
		"realistic":
			return {
				"bending": false,
				"superpowers": false,
				"vampires": false,
				"artifacts": false,
				"supernatural_school": false,
				"supernatural_events": false
			}
		"enhanced":
			return {
				"bending": true,
				"superpowers": false,
				"vampires": false,
				"artifacts": false,
				"supernatural_school": true,
				"supernatural_events": true
			}
		_:
			return {
				"bending": true,
				"superpowers": true,
				"vampires": true,
				"artifacts": true,
				"supernatural_school": true,
				"supernatural_events": true
			}
func _selected_bank_balance_value() -> int:
	var selected_label: String = _selected_text(
		bank_balance_picker
	).strip_edges().to_upper()

	if selected_label == "":
		return 0

	var numeric_text: String = selected_label
	numeric_text = numeric_text.replace("$", "")
	numeric_text = numeric_text.replace(",", "")
	numeric_text = numeric_text.replace("USD", "")
	numeric_text = numeric_text.replace(" ", "")

	var multiplier: float = 1.0

	if numeric_text.ends_with("K"):
		multiplier = 1000.0
		numeric_text = numeric_text.left(
			maxi(
				0,
				numeric_text.length() - 1
			)
		)
	elif numeric_text.ends_with("M"):
		multiplier = 1000000.0
		numeric_text = numeric_text.left(
			maxi(
				0,
				numeric_text.length() - 1
			)
		)
	elif numeric_text.ends_with("B"):
		multiplier = 1000000000.0
		numeric_text = numeric_text.left(
			maxi(
				0,
				numeric_text.length() - 1
			)
		)

	if not numeric_text.is_valid_float():
		return 0

	return maxi(
		0,
		int(
			round(
				float(numeric_text)
				* multiplier
			)
		)
	)
func _collect_panel_state() -> Dictionary:
	var birth_year_value: int = (
		_selected_birth_year_value()
	)
	var era_key: String = (
		_era_key_for_birth_year_value(
			birth_year_value
		)
	)
	var clean_reality_mode: String = (
		_viewer_canonical_reality_mode(
			selected_reality_mode
		)
	)
	var social_class_label: String = (
		_selected_text(
			social_class_picker
		)
	)
	var social_class_value: String = (
		_normalize_social_class_picker_value(
			social_class_label
		)
	)
	var royal_rank_value: String = (
		_selected_royal_rank_seed_from_picker()
	)

	if social_class_value not in [
		"Royal",
		"Noble"
	]:
		royal_rank_value = ""

	var presidential_selected: bool = (
		_presidential_parents_selected()
	)
	var selected_country: String = (
		_selected_text(
			country_picker
		)
	)
	var selected_state: String = (
		_selected_state_text()
		if _is_usa_country_name(
			selected_country
		)
		else ""
	)
	var selected_city: String = (
		_selected_text(
			city_picker
		)
	)
	var selected_territory: String = ""

	if presidential_selected:
		selected_country = "United States"
		selected_state = ""
		selected_city = "Washington, DC"
		selected_territory = (
			"District of Columbia"
		)

	return {
		"_god_mode_entry_kind": "custom",
		"reality_mode": clean_reality_mode,
		"reality_mode_label": (
			_viewer_reality_mode_label(
				clean_reality_mode
			)
		),
		"fantasy_alias_is_chaos": true,
		"first_name": (
			first_name_edit.text.strip_edges()
			if first_name_edit != null
			else ""
		),
		"last_name": (
			last_name_edit.text.strip_edges()
			if last_name_edit != null
			else ""
		),
		"gender": _selected_text(
			gender_picker
		),
		"birth_year": birth_year_value,
		"year": birth_year_value,
		"birth_year_mode": _selected_text(
			birth_year_picker
		),
		"birth_year_display": (
			_birth_year_display_text_for_value(
				birth_year_value
			)
		),
		"custom_year_text": (
			birth_year_custom_edit.text.strip_edges()
			if birth_year_custom_edit != null
			else _birth_year_display_text_for_value(
				birth_year_value
			)
		),
		"birth_month": _selected_text(
			birth_month_picker
		),
		"birth_day": (
			int(
				birth_day_spin.value
			)
			if birth_day_spin != null
			else 1
		),
		"era": era_key,
		"era_name": (
			_era_display_name_for_key(
				era_key
			)
		),
		"year_era_authority": (
			"god_mode_viewer.birth_year_threshold"
		),

		"country": selected_country,
		"birth_country": selected_country,
		"home_country": selected_country,

		"territory": selected_territory,
		"birth_territory": selected_territory,
		"home_territory": selected_territory,

		"selected_place_kind": (
			"territory"
			if presidential_selected
			else (
				"state"
				if selected_state != ""
				else "city"
			)
		),
		"selected_place": (
			selected_territory
			if presidential_selected
			else (
				selected_state
				if selected_state != ""
				else selected_city
			)
		),

		"state": selected_state,
		"birth_state": selected_state,
		"home_state": selected_state,

		"city": selected_city,
		"birth_city": selected_city,
		"home_city": selected_city,

		"social_class": social_class_value,
		"social_class_label": (
			social_class_label
		),
		"royal_rank": royal_rank_value,
		"royal_rank_label": _selected_text(
			royal_rank_picker
		),
		"bending_type": _selected_text(
			bending_type_picker
		).strip_edges().to_lower(),

		"happiness": (
			int(
				happiness_slider.value
			)
			if happiness_slider != null
			else 50
		),
		"health": (
			int(
				health_slider.value
			)
			if health_slider != null
			else 100
		),
		"smarts": (
			int(
				smarts_slider.value
			)
			if smarts_slider != null
			else 100
		),
		"looks": (
			int(
				looks_slider.value
			)
			if looks_slider != null
			else 100
		),
		"mental_health": (
			int(
				mental_health_slider.value
			)
			if mental_health_slider != null
			else 100
		),
		"fertility": (
			int(
				fertility_slider.value
			)
			if fertility_slider != null
			else 50
		),
		"bank_balance": (
			_selected_bank_balance_value()
		),
		"bank_balance_label": _selected_text(
			bank_balance_picker
		),
		"starting_infinity_stones": clampi(
			starting_infinity_stones,
			0,
			2
		),
		"start_with_red_bonnet": (
			GOD_MODE_VIEWER_RED_BONNET_START_TEST_VISIBLE
			and red_bonnet_check != null
			and is_instance_valid(
				red_bonnet_check
			)
			and red_bonnet_check.button_pressed
		),

		"presidential_parents": (
			presidential_selected
		),
		"presidential_parent_target": (
			"weighted_parent"
		),
		"presidential_parent_location_contract": {
			"schema": (
				"eralife.presidential_parent_location_contract"
			),
			"version": 1,
			"enabled": presidential_selected,
			"country": (
				"United States"
				if presidential_selected
				else selected_country
			),
			"continent": (
				"North America"
				if presidential_selected
				else ""
			),
			"place_kind": (
				"territory"
				if presidential_selected
				else ""
			),
			"territory": selected_territory,
			"selected_place": selected_territory,
			"city": (
				"Washington, DC"
				if presidential_selected
				else selected_city
			),
			"state_city_picker_hidden": (
				presidential_selected
			),
			"state_city_seed_forbidden": (
				presidential_selected
			),
			"ui_is_renderer_only": true
		},
		"presidential_parent_contract": {
			"enabled": presidential_selected,
			"country": (
				"United States"
				if presidential_selected
				else _selected_country_text()
			),
			"continent": (
				"North America"
				if presidential_selected
				else ""
			),
			"territory": selected_territory,
			"selected_place_kind": (
				"territory"
				if presidential_selected
				else ""
			),
			"selected_place": selected_territory,
			"birth_city": (
				"Washington, DC"
				if presidential_selected
				else selected_city
			),
			"era": era_key,
			"requires_social_class": "Elite",
			"president_gets_crown_hub_access": true,
			"family_gets_elite_jobs": true,
			"family_gets_ruling_power_by_proximity": false,
			"white_house_official_residence": (
				presidential_selected
			),
			"white_house_inheritable": false,
			"crown_hub_layout_variant": (
				"federal_republic"
			),
			"approval_label": (
				"Presidential Approval"
			),
			"ui_is_renderer_only": true
		},
		"superpower_configurator": (
			_celestial_power_sandbox_state()
		),
		"superpower_sandbox_config": (
			_celestial_power_sandbox_state()
		),
		"feature_overrides": (
			_feature_override_state()
		),
	}
func _birth_year_preset_options() -> Array:
	return [
		"378 BCE",
		"221 BCE",
		"33 BCE",
		"1 BCE",
		"40 AD",
		"79 AD",
		"298 AD",
		"476 AD",
		"500 AD",
		"1066 AD",
		"1492 AD",
		"1800 AD",
		"1914 AD",
		"1950 AD",
		"2000",
		"2026",
		"2050",
		"2086",
		"2250",
		"8172",
		"Custom"
	]
func _on_birth_year_picker_changed() -> void:
	var is_custom: bool = _birth_year_picker_is_custom()
	_set_birth_year_custom_visible(is_custom)

	if not is_custom and birth_year_custom_edit != null:
		birth_year_custom_edit.text = _birth_year_display_text_for_value(_selected_birth_year_value())

	_sync_era_from_birth_year("birth_year_picker_changed")
	_refresh_social_class_picker_for_location()
	# February's length depends on the year, so re-check the day range too.
	_retune_birth_day_range()

func _on_birth_year_custom_text_changed() -> void:
	if not _birth_year_picker_is_custom():
		return

	_sync_era_from_birth_year("birth_year_custom_text_changed")
	# February's length depends on the year, so re-check the day range too.
	_retune_birth_day_range()

func _birth_year_picker_is_custom() -> bool:
	return _selected_text(birth_year_picker).strip_edges().to_lower() == "custom"


func _set_birth_year_custom_visible(custom_year_visible: bool) -> void:
	if birth_year_custom_row != null and is_instance_valid(birth_year_custom_row):
		birth_year_custom_row.visible = custom_year_visible
		birth_year_custom_row.mouse_filter = Control.MOUSE_FILTER_PASS if custom_year_visible else Control.MOUSE_FILTER_IGNORE

	if birth_year_custom_edit != null and is_instance_valid(birth_year_custom_edit):
		birth_year_custom_edit.visible = custom_year_visible
		birth_year_custom_edit.editable = custom_year_visible
		birth_year_custom_edit.mouse_filter = Control.MOUSE_FILTER_STOP if custom_year_visible else Control.MOUSE_FILTER_IGNORE


func _selected_birth_year_value() -> int:
	if birth_year_picker != null and is_instance_valid(birth_year_picker):
		var selected_year_text: String = _selected_text(birth_year_picker).strip_edges()
		if selected_year_text.to_lower() == "custom":
			return _parse_birth_year_text(birth_year_custom_edit.text if birth_year_custom_edit != null else "", 79)
		if selected_year_text != "":
			return _parse_birth_year_text(selected_year_text, 79)

	if birth_year_custom_edit != null and is_instance_valid(birth_year_custom_edit):
		return _parse_birth_year_text(birth_year_custom_edit.text, 79)

	if birth_year_spin != null and is_instance_valid(birth_year_spin):
		return int(birth_year_spin.value)

	return 79


func _parse_birth_year_text(raw_text: String, fallback: int = 79) -> int:
	var clean: String = str(raw_text).strip_edges().replace(",", "").replace("_", "").replace(" ", "").to_lower()
	if clean == "":
		return fallback

	var year_direction: int = 1

	if clean.ends_with("bce"):
		year_direction = -1
		clean = clean.substr(0, clean.length() - 3)
	elif clean.ends_with("bc"):
		year_direction = -1
		clean = clean.substr(0, clean.length() - 2)
	elif clean.ends_with("ad"):
		clean = clean.substr(0, clean.length() - 2)
	elif clean.ends_with("ce"):
		clean = clean.substr(0, clean.length() - 2)
	elif clean.begins_with("ad"):
		clean = clean.substr(2)
	elif clean.begins_with("ce"):
		clean = clean.substr(2)

	if clean.begins_with("-"):
		year_direction = -1
		clean = clean.substr(1)
	elif clean.begins_with("+"):
		clean = clean.substr(1)

	if clean == "":
		return fallback

	for i in range(clean.length()):
		var character: String = clean.substr(i, 1)
		if character not in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]:
			return fallback

	if clean.length() > 18:
		return year_direction * 1000000000

	var magnitude: int = int(clean)
	if magnitude <= 0:
		return fallback

	return year_direction * magnitude
func _era_key_for_birth_year_value(year_value: int) -> String:
	if year_value <= 499:
		return "Ancient"
	if year_value <= 1799:
		return "Medieval"
	if year_value <= 1949:
		return "Industrial"
	if year_value <= 2049:
		return "Modern"
	return "Future"


func _era_display_name_for_key(era_key: String) -> String:
	match str(era_key).strip_edges():
		"Ancient":
			return "Ancient Era"
		"Medieval":
			return "Medieval Era"
		"Industrial":
			return "Industrial Era"
		"Modern":
			return "Modern Era"
		"Future":
			return "Future Era"
		_:
			return str(era_key).strip_edges()


func _representative_year_for_era_key(era_key: String) -> int:
	match str(era_key).strip_edges().to_lower().replace(" era", ""):
		"ancient":
			return 79
		"medieval":
			return 1066
		"industrial":
			return 1900
		"modern":
			return 2000
		"future":
			return 2050
		_:
			return _selected_birth_year_value()


func _set_birth_year_controls_from_value(year_value: int) -> void:
	var year_text: String = _birth_year_display_text_for_value(year_value)
	var matched_preset: bool = false

	if birth_year_picker != null and is_instance_valid(birth_year_picker):
		for i in range(birth_year_picker.item_count):
			var item_text: String = birth_year_picker.get_item_text(i).strip_edges()
			if item_text == year_text or _parse_birth_year_text(item_text, 79) == year_value:
				birth_year_picker.select(i)
				matched_preset = true
				break

		if not matched_preset:
			_select_picker_text(birth_year_picker, "Custom")

	if birth_year_custom_edit != null and is_instance_valid(birth_year_custom_edit):
		birth_year_custom_edit.text = year_text

	_set_birth_year_custom_visible(not matched_preset)

func _birth_year_display_text_for_value(year_value: int) -> String:
	var safe_year: int = int(year_value)

	if safe_year < 0:
		return "%d BCE" % abs(safe_year)

	if safe_year <= 1999:
		return "%d AD" % safe_year

	return str(safe_year)


func _selected_country_text() -> String:
	return _selected_text(country_picker)


func _selected_era_key() -> String:
	var birth_year_value: int = _selected_birth_year_value()
	return _era_key_for_birth_year_value(birth_year_value)


func _selected_gender_key() -> String:
	return _selected_text(gender_picker).strip_edges().to_lower()


func _government_style_for_selected_country() -> String:
	var country_text: String = _selected_country_text()
	var lowered: String = country_text.strip_edges().to_lower()

	if country_text == "":
		return ""

	if _is_elemental_country_name(country_text):
		return "Monarchy"





	if (
		lowered.find("egypt") >= 0
		and _selected_era_key() == "Ancient"
	):
		return "Monarchy"

	if lowered.find("empire") >= 0:
		return "Empire"
	if lowered.find("kingdom") >= 0:
		return "Monarchy"
	if lowered.find("sultanate") >= 0:
		return "Monarchy"
	if lowered.find("dynasty") >= 0:
		return "Monarchy"
	if lowered.find("byzantium") >= 0:
		return "Empire"
	if lowered.find("rome") >= 0 or lowered.find("roman") >= 0:
		return "Empire"
	if lowered.find("persia") >= 0:
		return "Empire"
	if lowered.find("england") >= 0 or lowered.find("united kingdom") >= 0:
		return "Monarchy"
	if (
		lowered.find("japan") >= 0
		and _selected_era_key() in [
			"Ancient",
			"Medieval",
			"Industrial"
		]
	):
		return "Empire"

	return ""


func _country_supports_royal_social_classes() -> bool:
	var government_style: String = _government_style_for_selected_country().strip_edges().to_lower()
	if government_style in ["monarchy", "empire"]:
		return true

	var country_text: String = _selected_country_text()
	var lowered: String = country_text.strip_edges().to_lower()

	return lowered.find("kingdom") >= 0 \
or lowered.find("empire") >= 0 \
or lowered.find("sultanate") >= 0 \
or lowered.find("dynasty") >= 0


func _royal_social_class_picker_label() -> String:
	var country_text: String = _selected_country_text()
	var lowered_country: String = country_text.strip_edges().to_lower()
	var government_style: String = _government_style_for_selected_country().strip_edges().to_lower()

	if lowered_country.find("egypt") >= 0:
		return "Pharaonic Court"
	if government_style == "empire":
		return "Imperial Court"
	if government_style == "monarchy":
		return "Royal Court"
	if _is_elemental_country_name(country_text):
		return "Royal Court"

	return "Royal"


func _noble_social_class_picker_label() -> String:
	var country_text: String = _selected_country_text()
	var lowered_country: String = country_text.strip_edges().to_lower()
	var government_style: String = _government_style_for_selected_country().strip_edges().to_lower()

	if lowered_country.find("egypt") >= 0:
		return "Pharaonic Nobility"
	if government_style == "empire":
		return "Imperial Nobility"
	if government_style == "monarchy":
		return "Noble House"
	if _is_elemental_country_name(country_text):
		return "Noble House"

	return "Noble"


func _normalize_social_class_picker_value(value: String) -> String:
	var text: String = str(value).strip_edges()

	if text in ["Royal", "Royal Court", "Imperial Court", "Pharaonic Court"]:
		return "Royal"

	if text in ["Noble", "Noble House", "Imperial Nobility", "Pharaonic Nobility"]:
		return "Noble"

	if text == "Upperclass":
		return "Upper Class"

	return text


func _social_class_options_for_current_location() -> Array:
	if not _country_supports_royal_social_classes():
		return [
			"Working Class",
			"Middle Class",
			"Upper Class",
			"Elite"
		]

	return [
		"Peasant",
		"Commoner",
		"Merchant",
		_noble_social_class_picker_label(),
		_royal_social_class_picker_label()
	]


func _default_social_class_for_current_location() -> String:
	var options: Array = _social_class_options_for_current_location()
	if options.has("Commoner"):
		return "Commoner"
	if options.has("Middle Class"):
		return "Middle Class"
	if not options.is_empty():
		return str(options [0])
	return "Middle Class"


func _refresh_social_class_picker_for_location(preferred_text: String = "") -> void:
	if social_class_picker == null or not is_instance_valid(social_class_picker):
		return

	var previous_rank: String = _selected_royal_rank_seed_from_picker()
	var current_text: String = str(preferred_text).strip_edges()

	if current_text == "":
		current_text = _selected_text(social_class_picker)

	current_text = _normalize_social_class_picker_value(current_text)

	var options: Array = _social_class_options_for_current_location()
	var default_text: String = _default_social_class_for_current_location()

	if current_text == "":
		current_text = default_text

	if current_text in ["Royal", "Noble"] and not _country_supports_royal_social_classes():
		current_text = default_text

	var picker_text: String = current_text
	if current_text == "Royal" and _country_supports_royal_social_classes():
		picker_text = _royal_social_class_picker_label()
	elif current_text == "Noble" and _country_supports_royal_social_classes():
		picker_text = _noble_social_class_picker_label()

	if not options.has(picker_text):
		picker_text = default_text

	var previous_guard: bool = sync_guard
	sync_guard = true
	social_class_picker.clear()

	for option in options:
		social_class_picker.add_item(str(option))

	_select_picker_text(social_class_picker, picker_text)
	sync_guard = previous_guard

	_refresh_royal_rank_picker_preserving_selection(previous_rank)

	if not location_contract_refresh_guard:
		_refresh_presidential_parents_visibility()
func _presidential_parents_available_for_current_selection() -> bool:
	var era_key: String = str(_selected_era_key()).strip_edges()
	if era_key not in ["Industrial", "Modern", "Future"]:
		return false

	var country_key: String = str(_selected_country_text()).strip_edges().to_lower()
	if country_key not in [
		"usa",
		"u.s.a.",
		"united states",
		"united states of america"
	]:
		return false

	var social_class_text: String = _normalize_social_class_picker_value(_selected_text(social_class_picker))
	return social_class_text == "Elite"


func _refresh_presidential_parents_visibility() -> void:
	if presidential_parents_check == null or not is_instance_valid(presidential_parents_check):
		return

	if location_contract_refresh_guard:
		return

	var previous_state: String = _selected_text(state_picker)
	var previous_city: String = _selected_text(city_picker)

	location_contract_refresh_guard = true

	var available: bool = _presidential_parents_available_for_current_selection()
	presidential_parents_check.visible = available
	presidential_parents_check.disabled = not available

	if not available:
		presidential_parents_check.set_block_signals(true)
		presidential_parents_check.button_pressed = false
		presidential_parents_check.set_block_signals(false)

	_refresh_state_picker_for_country(previous_state)
	_refresh_city_picker_for_country(previous_city, false)

	location_contract_refresh_guard = false
func _on_presidential_parents_toggled(_pressed: bool) -> void:
	if location_contract_refresh_guard:
		return

	location_contract_refresh_guard = true

	_refresh_state_picker_for_country()
	_refresh_city_picker_for_country("", false)
	_style_elemental_location_controls()

	location_contract_refresh_guard = false

	_refresh_preview()
	preview_visual_dirty = true
func _presidential_parents_selected() -> bool:
	return presidential_parents_check != null \
and is_instance_valid(presidential_parents_check) \
and presidential_parents_check.visible \
and presidential_parents_check.button_pressed


func _set_picker_row_label_text(picker: OptionButton, label_text: String) -> void:
	if picker == null or not is_instance_valid(picker):
		return

	var parent_control:= picker.get_parent() as Control
	if parent_control == null:
		return

	for child in parent_control.get_children():
		var label:= child as Label
		if label != null:
			label.text = label_text
			return
func _royal_rank_is_available_for_current_picker_state() -> bool:
	if social_class_picker == null or not is_instance_valid(social_class_picker):
		return false

	var social_class_text: String = _normalize_social_class_picker_value(_selected_text(social_class_picker))
	if social_class_text not in ["Royal", "Noble"]:
		return false

	return _country_supports_royal_social_classes()


func _selected_royal_rank_seed_from_picker() -> String:
	if royal_rank_picker == null or not is_instance_valid(royal_rank_picker):
		return ""
	if royal_rank_picker.item_count <= 0:
		return ""

	var selected_idx: int = royal_rank_picker.selected
	if selected_idx < 0 or selected_idx >= royal_rank_picker.item_count:
		return ""

	var metadata: Variant = royal_rank_picker.get_item_metadata(selected_idx)
	var seed_text: String = str(metadata).strip_edges()
	if seed_text != "":
		return seed_text

	return str(royal_rank_picker.get_item_text(selected_idx)).strip_edges()


func _select_royal_rank_picker_by_seed_or_text(preferred_value: String) -> bool:
	if royal_rank_picker == null or not is_instance_valid(royal_rank_picker):
		return false

	var wanted: String = str(preferred_value).strip_edges()
	if wanted == "":
		return false

	for i in range(royal_rank_picker.item_count):
		var metadata: String = str(royal_rank_picker.get_item_metadata(i)).strip_edges()
		var item_text: String = str(royal_rank_picker.get_item_text(i)).strip_edges()
		if metadata == wanted or item_text == wanted:
			royal_rank_picker.select(i)
			return true

	return false


func _refresh_royal_rank_picker_preserving_selection(preferred_value: String = "") -> void:
	if royal_rank_picker == null or not is_instance_valid(royal_rank_picker):
		return

	var rank_available: bool = _royal_rank_is_available_for_current_picker_state()
	royal_rank_picker.clear()
	royal_rank_picker.disabled = not rank_available

	if royal_rank_row != null and is_instance_valid(royal_rank_row):
		royal_rank_row.visible = rank_available
		royal_rank_row.mouse_filter = Control.MOUSE_FILTER_PASS if rank_available else Control.MOUSE_FILTER_IGNORE

	if not rank_available:
		return

	var social_class_text: String = _normalize_social_class_picker_value(_selected_text(social_class_picker))
	var option_rows: Array = []
	var state: GameState = _get_game_state()

	if state != null and state.royalty_engine != null and state.royalty_engine.has_method("get_spawnable_royal_rank_options"):
		option_rows = state.royalty_engine.get_spawnable_royal_rank_options(
			_selected_country_text(),
			_selected_era_key()
		)

	if option_rows.is_empty():
		option_rows = [
			{ "seed": "Royal Child", "label": "Prince / Princess"},
			{ "seed": "Heir Line", "label": "Crown Prince / Crown Princess"},
			{ "seed": "Ducal Line", "label": "Duke / Duchess"},
			{ "seed": "Marcher Line", "label": "Marquess / Marchioness"}
		]

	if social_class_text == "Noble":
		var filtered_rows: Array = []
		for raw_row in option_rows:
			if typeof(raw_row) != TYPE_DICTIONARY:
				continue
			var row: Dictionary = raw_row
			var seed_text: String = str(row.get("seed", "")).strip_edges()
			if seed_text in ["Ducal Line", "Marcher Line", "Lesser Royal"]:
				filtered_rows.append(row)
		option_rows = filtered_rows

	for raw_row in option_rows:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = raw_row
		var seed_text: String = str(row.get("seed", "")).strip_edges()
		var label_text: String = _gendered_royal_rank_label(row)

		if seed_text == "" or label_text == "":
			continue

		royal_rank_picker.add_item(label_text)
		var item_idx: int = royal_rank_picker.item_count - 1
		royal_rank_picker.set_item_metadata(item_idx, seed_text)

	royal_rank_picker.disabled = royal_rank_picker.item_count <= 0
	if royal_rank_picker.disabled:
		return

	var preferred_seed: String = str(preferred_value).strip_edges()
	if preferred_seed == "Lesser Royal":
		preferred_seed = "Ducal Line"

	var fallback_seed: String = "Ducal Line" if social_class_text == "Noble" else "Royal Child"
	if not _select_royal_rank_picker_by_seed_or_text(preferred_seed):
		_select_royal_rank_picker_by_seed_or_text(fallback_seed)

	if royal_rank_picker.selected < 0 and royal_rank_picker.item_count > 0:
		royal_rank_picker.select(0)


func _gendered_royal_rank_label(row: Dictionary) -> String:
	var seed_text: String = str(row.get("seed", "")).strip_edges()
	var label_text: String = str(row.get("label", "")).strip_edges()
	var gender_key: String = _selected_gender_key()

	if label_text.find("/") >= 0:
		var parts: PackedStringArray = label_text.split("/")
		if parts.size() >= 2:
			var male_label: String = str(parts [0]).strip_edges()
			var female_label: String = str(parts [1]).strip_edges()
			if gender_key == "female":
				return female_label
			if gender_key == "male":
				return male_label
			return "%s / %s" % [male_label, female_label]

	match seed_text:
		"Heir Line":
			if gender_key == "female":
				return "Crown Princess"
			if gender_key == "male":
				return "Crown Prince"
			return "Crown Prince / Crown Princess"
		"Royal Child":
			if gender_key == "female":
				return "Princess"
			if gender_key == "male":
				return "Prince"
			return "Prince / Princess"
		"Ducal Line":
			if gender_key == "female":
				return "Duchess"
			if gender_key == "male":
				return "Duke"
			return "Duke / Duchess"
		"Marcher Line":
			if gender_key == "female":
				return "Marchioness"
			if gender_key == "male":
				return "Marquess"
			return "Marquess / Marchioness"
		_:
			return label_text
func _sync_era_picker_to_birth_year_without_refresh() -> String:
	var birth_year_value: int = _selected_birth_year_value()
	var era_key: String = _era_key_for_birth_year_value(birth_year_value)

	if era_picker != null and is_instance_valid(era_picker):
		var previous_guard: bool = sync_guard
		sync_guard = true
		_select_picker_text(era_picker, era_key)
		sync_guard = previous_guard

	return era_key


func _sync_era_from_birth_year(reason: String = "birth_year_changed") -> void:
	var previous_country: String = _selected_text(country_picker)
	var previous_city: String = _selected_text(city_picker)

	_sync_era_picker_to_birth_year_without_refresh()
	_refresh_location_pickers(previous_country, previous_city, false)
	_refresh_preview()
	_apply_palette(true)

	set_meta("god_mode_year_era_sync_reason", reason)
	set_meta("god_mode_year_era_sync_year", _selected_birth_year_value())
	set_meta("god_mode_year_era_sync_era", _era_key_for_birth_year_value(_selected_birth_year_value()))
	set_meta("god_mode_year_era_sync_at_ms", int(Time.get_ticks_msec()))
func _apply_settings(
	settings: Dictionary
) -> void:
	if settings.is_empty():
		return

	if first_name_edit != null:
		first_name_edit.text = str(
			settings.get(
				"first_name",
				first_name_edit.text
			)
		)

	if last_name_edit != null:
		last_name_edit.text = str(
			settings.get(
				"last_name",
				last_name_edit.text
			)
		)

	selected_reality_mode = (
		_viewer_canonical_reality_mode(
			settings.get(
				"reality_mode",
				selected_reality_mode
			)
		)
	)

	if selected_reality_mode == "":
		selected_reality_mode = "chaos"

	var loaded_social_class: String = (
		_normalize_social_class_picker_value(
			str(
				settings.get(
					"social_class",
					""
				)
			)
		)
	)
	var loaded_royal_rank: String = str(
		settings.get(
			"royal_rank",
			""
		)
	).strip_edges()

	if loaded_royal_rank == "Lesser Royal":
		loaded_royal_rank = "Ducal Line"

	_ensure_avatar_bending_type_picker_option()

	_select_picker_text(
		gender_picker,
		str(
			settings.get(
				"gender",
				""
			)
		)
	)
	_select_picker_text(
		bending_type_picker,
		str(
			settings.get(
				"bending_type",
				""
			)
		)
	)

	var restored_year: int = (
		_parse_birth_year_text(
			str(
				settings.get(
					"custom_year_text",
					settings.get(
						"birth_year",
						settings.get(
							"year",
							79
						)
					)
				)
			),
			int(
				settings.get(
					"birth_year",
					settings.get(
						"year",
						79
					)
				)
			)
		)
	)

	_set_birth_year_controls_from_value(
		restored_year
	)
	_sync_era_from_birth_year(
		"apply_settings"
	)

	if birth_day_spin != null:
		birth_day_spin.value = int(
			settings.get(
				"birth_day",
				birth_day_spin.value
			)
		)

	_refresh_location_pickers()

	_select_picker_text(
		country_picker,
		str(
			settings.get(
				"country",
				""
			)
		)
	)

	_refresh_city_picker_for_country()

	_select_picker_text(
		city_picker,
		str(
			settings.get(
				"city",
				""
			)
		)
	)

	_refresh_social_class_picker_for_location(
		loaded_social_class
	)
	_refresh_royal_rank_picker_preserving_selection(
		loaded_royal_rank
	)
	_refresh_presidential_parents_visibility()

	if (
		presidential_parents_check != null
		and is_instance_valid(
			presidential_parents_check
		)
	):
		presidential_parents_check.set_block_signals(
			true
		)
		presidential_parents_check.button_pressed = (
			bool(
				settings.get(
					"presidential_parents",
					false
				)
			)
			and _presidential_parents_available_for_current_selection()
		)
		presidential_parents_check.set_block_signals(
			false
		)

	_style_bending_type_picker()
	_style_elemental_location_controls()

	if settings.has(
		"superpower_configurator"
	):
		_apply_celestial_power_sandbox_settings(
			settings.get(
				"superpower_configurator",
				{}
			)
		)
	elif settings.has(
		"superpower_sandbox_config"
	):
		_apply_celestial_power_sandbox_settings(
			settings.get(
				"superpower_sandbox_config",
				{}
			)
		)
func _sync_from_engine() -> void:
	if engine == null or status_label == null:
		return

	var state: Dictionary = engine.current_state()
	var lifecycle: String = str(state.get("lifecycle", "idle")).strip_edges()
	var progress: float = _prewarm_progress_from_engine_state(state, lifecycle)
	var status_text: String = ""

	match lifecycle:
		"idle":
			status_text = "No world seed has been committed yet."

		"panel_captured":
			status_text = "God Mode loadout captured."

		"prewarm_requested":
			status_text = "Prewarming your world seed. UI remains only a viewer."

		"prewarm_ready":
			status_text = "Reality prewarmed. The room exists. Ready opens the door."

		"handoff_emitted":
			status_text = "Handoff emitted. Life owns the screen."

		"surface_claimed":
			status_text = "Playable surface claimed."

		"entry_complete":
			status_text = "Entry complete."

		_:
			status_text = lifecycle.capitalize()

	if lifecycle != last_rendered_lifecycle:
		last_rendered_lifecycle = lifecycle
		status_label.text = status_text
	elif status_label.text != status_text:
		status_label.text = status_text

	if progress_bar != null and is_instance_valid(progress_bar):
		progress_bar.value = progress

	var viewer_ready_button_enabled: bool = bool(state.get("viewer_ready_button_enabled", false))
	_update_prewarm_button_visual(progress, lifecycle, status_text, viewer_ready_button_enabled)
	_apply_ready_button_state(state)

func _apply_ready_button_state(state: Dictionary) -> void:
	var prewarm_is_ready: bool = bool(state.get("prewarm_ready", false))
	var door_latch_hot: bool = bool(state.get("viewer_ready_button_enabled", false))
	var lifecycle: String = str(state.get("lifecycle", "")).strip_edges()
	var prewarm_is_pending: bool = lifecycle == "prewarm_requested"
	var latch_pending: bool = bool(state.get("prewarm_ready_but_door_latch_pending", false))

	if ready_button != null and is_instance_valid(ready_button):
		ready_button.visible = false
		ready_button.disabled = true
		ready_button.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if prewarm_button != null and is_instance_valid(prewarm_button):
		prewarm_button.disabled = (prewarm_is_pending and not prewarm_is_ready) or latch_pending
		prewarm_button.mouse_filter = Control.MOUSE_FILTER_STOP if not prewarm_button.disabled else Control.MOUSE_FILTER_IGNORE
		prewarm_button.set_meta("viewer_ready_button_enabled", door_latch_hot)
		prewarm_button.set_meta("viewer_prewarm_ready_but_door_latch_pending", latch_pending)
		prewarm_button.set_meta("viewer_ready_uses_door_latch_truth", true)
func _apply_mode_constraints(mode: String) -> void:
	var clean_mode: String = _viewer_canonical_reality_mode(mode)
	var previous_guard: bool = sync_guard
	sync_guard = true

	for key in feature_checks.keys():
		var check: CheckBox = feature_checks [key]
		if check == null or not is_instance_valid(check):
			continue

		var canonical_key: String = _viewer_feature_key_to_settings_key(key)
		var enabled: bool = true

		match clean_mode:
			"realistic":
				enabled = false
			"enhanced":
				enabled = canonical_key in ["bending", "supernatural_school", "supernatural_events"]
			"chaos":
				enabled = true
			_:
				enabled = check.button_pressed

		check.set_pressed_no_signal(enabled)

	sync_guard = previous_guard
	selected_reality_mode = clean_mode


func _on_feature_changed() -> void:
	if sync_guard:
		return

	selected_reality_mode = _viewer_canonical_reality_mode(selected_reality_mode)

	if selected_reality_mode in ["realistic", "enhanced", "chaos"]:
		if not _feature_state_matches_mode(selected_reality_mode):
			selected_reality_mode = "custom"

	_refresh_preview()
	stat_slider_visuals_dirty = true
	preview_visual_dirty = true
	_apply_palette(true)


func _feature_state_matches_mode(mode: String) -> bool:
	var state: Dictionary = _feature_override_state()
	var clean_mode: String = _viewer_canonical_reality_mode(mode)
	var expected_state: Dictionary = _viewer_default_feature_state_for_mode(clean_mode)

	for key in expected_state.keys():
		if bool(state.get(key, false)) != bool(expected_state.get(key, false)):
			return false

	return true


func _feature_override_state() -> Dictionary:
	var out: Dictionary = _viewer_default_feature_state_for_mode(selected_reality_mode)

	for key in feature_checks.keys():
		var canonical_key: String = _viewer_feature_key_to_settings_key(key)
		if canonical_key == "":
			continue

		var check: CheckBox = feature_checks [key]
		out [canonical_key] = check != null and is_instance_valid(check) and check.button_pressed

	if not _celestial_power_sandbox_state().is_empty():
		out ["superpowers"] = true
		out ["supernatural_events"] = true

	return out

func _refresh_location_pickers(preferred_country: String = "", preferred_city: String = "", force_city_selection: bool = false) -> void:
	if country_picker == null or city_picker == null:
		return

	var previous_country: String = _viewer_canonical_country_name(preferred_country)
	var previous_city: String = preferred_city.strip_edges()
	var previous_state: String = _selected_text(state_picker)

	if previous_country == "":
		previous_country = _viewer_canonical_country_name(_selected_text(country_picker))
	if previous_city == "":
		previous_city = _selected_text(city_picker)

	var era_key: String = _sync_era_picker_to_birth_year_without_refresh()
	var reality_mode: String = selected_reality_mode
	var countries: Array = _era_country_options(era_key, reality_mode)

	if countries.is_empty():
		countries = ["United States"]

	sync_guard = true
	country_picker.clear()

	for country in countries:
		country_picker.add_item(str(country))

	if previous_country != "":
		_select_picker_text(country_picker, previous_country)
	elif country_picker.item_count > 0:
		country_picker.select(0)

	sync_guard = false

	_refresh_state_picker_for_country(previous_state)
	_refresh_city_picker_for_country(previous_city, force_city_selection)
	_style_elemental_location_controls()
	_refresh_social_class_picker_for_location()
	_refresh_location_picker_popup_scrollbars()
func _refresh_state_picker_for_country(preferred_state: String = "") -> void:
	if state_picker == null or not is_instance_valid(state_picker):
		return

	var clean_preferred: String = preferred_state.strip_edges()
	if clean_preferred == "":
		clean_preferred = _selected_text(state_picker)

	if _presidential_parents_selected():
		_set_picker_row_visible(state_picker, true)
		_set_picker_row_label_text(state_picker, "Territory")
		state_picker.clear()
		state_picker.add_item("District of Columbia")
		state_picker.select(0)
		state_picker.disabled = true
		return

	_set_picker_row_label_text(state_picker, "Birth State")

	var country: String = _viewer_canonical_country_name(_selected_text(country_picker))
	var usa_selected: bool = _is_usa_country_name(country)
	var states: Array = _usa_state_options()

	_set_picker_row_visible(state_picker, usa_selected)
	state_picker.clear()
	state_picker.disabled = not usa_selected

	if not usa_selected:
		return

	for state_name in states:
		state_picker.add_item(str(state_name))

	var selected_match: bool = false
	if clean_preferred != "":
		for i in range(state_picker.item_count):
			if state_picker.get_item_text(i).strip_edges().to_lower() == clean_preferred.to_lower():
				state_picker.select(i)
				selected_match = true
				break

	if not selected_match and state_picker.item_count > 0:
		state_picker.select(0)
func _refresh_city_picker_for_country(preferred_city: String = "", force_city_selection: bool = false) -> void:
	if city_picker == null:
		return

	if _presidential_parents_selected():
		_set_picker_row_visible(city_picker, false)
		city_picker.clear()
		city_picker.add_item("Washington, DC")
		city_picker.select(0)
		_style_elemental_location_controls()
		_configure_location_picker_popup_scroll(city_picker, 480)

		if not location_contract_refresh_guard:
			_refresh_social_class_picker_for_location()

		return

	_set_picker_row_visible(city_picker, true)

	var era_key: String = _sync_era_picker_to_birth_year_without_refresh()
	var country: String = _selected_text(country_picker)
	var state_name: String = _selected_text(state_picker)
	var reality_mode: String = selected_reality_mode
	var cities: Array = []

	if _is_usa_country_name(country):
		cities = _usa_city_options_for_state(state_name)
	else:
		cities = _era_city_options(era_key, country, reality_mode)

	if cities.is_empty():
		cities = ["Random City"]

	city_picker.clear()
	for city in cities:
		city_picker.add_item(str(city))

	var clean_preferred_city: String = preferred_city.strip_edges()
	if clean_preferred_city != "":
		_select_picker_text(city_picker, clean_preferred_city)
	elif force_city_selection and city_picker.item_count > 0:
		city_picker.select(0)
	elif city_picker.item_count > 0 and city_picker.selected < 0:
		city_picker.select(0)

	_style_elemental_location_controls()

	if not location_contract_refresh_guard:
		_refresh_social_class_picker_for_location()
func _set_picker_row_visible(picker: OptionButton, visible_state: bool) -> void:
	if picker == null or not is_instance_valid(picker):
		return

	picker.visible = visible_state
	picker.disabled = not visible_state

	var parent_control:= picker.get_parent() as Control
	if parent_control != null:
		parent_control.visible = visible_state


func _selected_state_text() -> String:
	return _selected_text(state_picker)


func _is_usa_country_name(country: String) -> bool:
	return _viewer_canonical_country_name(country) == "United States"
func _viewer_canonical_country_name(country: String) -> String:
	var clean: String = str(country).strip_edges()

	while clean.ends_with("."):
		clean = clean.substr(0, clean.length() - 1).strip_edges()

	var key: String = clean.to_lower()
	if key.begins_with("the "):
		key = key.substr(4).strip_edges()

	var compact: String = key.replace(".", "").replace(" ", "").replace("-", "").replace("_", "")

	if compact in ["usa", "us", "unitedstates", "unitedstatesofamerica", "america"]:
		return "United States"

	if compact in ["uk", "unitedkingdom", "greatbritain", "britain"]:
		return "United Kingdom"

	if compact in ["uae", "unitedarabemirates"]:
		return "United Arab Emirates"

	if clean == "":
		return ""

	return clean


func _viewer_country_names_match(a: String, b: String) -> bool:
	var clean_a: String = _viewer_canonical_country_name(a).to_lower()
	var clean_b: String = _viewer_canonical_country_name(b).to_lower()

	if clean_a == "" or clean_b == "":
		return false

	return clean_a == clean_b


func _viewer_country_lookup_aliases(country: String) -> Array:
	var canonical: String = _viewer_canonical_country_name(country)

	if canonical == "United States":
		return ["USA", "United States", "United States of America", "U.S.A."]

	if canonical == "United Kingdom":
		return ["UK", "United Kingdom", "Great Britain", "Britain"]

	if canonical == "United Arab Emirates":
		return ["UAE", "United Arab Emirates"]

	if canonical == "":
		return []

	return [canonical]


func _usa_state_options() -> Array:
	return [
		"Alabama", "Alaska", "Arizona", "Arkansas", "California",
		"Colorado", "Connecticut", "Delaware", "Florida", "Georgia",
		"Hawaii", "Idaho", "Illinois", "Indiana", "Iowa",
		"Kansas", "Kentucky", "Louisiana", "Maine", "Maryland",
		"Massachusetts", "Michigan", "Minnesota", "Mississippi", "Missouri",
		"Montana", "Nebraska", "Nevada", "New Hampshire", "New Jersey",
		"New Mexico", "New York", "North Carolina", "North Dakota", "Ohio",
		"Oklahoma", "Oregon", "Pennsylvania", "Rhode Island", "South Carolina",
		"South Dakota", "Tennessee", "Texas", "Utah", "Vermont",
		"Virginia", "Washington", "West Virginia", "Wisconsin", "Wyoming"
	]


func _usa_city_options_for_state(state_name: String) -> Array:
	var key: String = str(state_name).strip_edges()

	var map: Dictionary = {
		"Texas": ["Houston", "Dallas", "Austin", "San Antonio", "Fort Worth", "El Paso", "Angleton"],
		"Michigan": ["Detroit", "Ann Arbor", "Lansing", "Grand Rapids", "Flint"],
		"New York": ["New York City", "Buffalo", "Rochester", "Albany", "Syracuse"],
		"California": ["Los Angeles", "San Francisco", "San Diego", "Sacramento", "Oakland"],
		"Illinois": ["Chicago", "Springfield", "Peoria", "Rockford"],
		"Florida": ["Miami", "Orlando", "Tampa", "Jacksonville", "Tallahassee"],
		"Georgia": ["Atlanta", "Savannah", "Augusta", "Macon"],
		"Washington": ["Seattle", "Olympia", "Tacoma", "Spokane"],
		"Pennsylvania": ["Philadelphia", "Pittsburgh", "Harrisburg", "Allentown"],
		"Ohio": ["Columbus", "Cleveland", "Cincinnati", "Toledo"],
		"Massachusetts": ["Boston", "Cambridge", "Worcester", "Springfield"]
	}

	if map.has(key):
		return _dedupe_sorted_strings(map [key])

	return ["Capital City", "Riverside", "Springfield", "Greenville", "Fairview"]
func _resolve_country_from_city() -> void:
	if sync_guard:
		return

	var city: String = _selected_text(city_picker)
	if city == "" or city == "Random City":
		return

	var era_key: String = _selected_text(era_picker)
	var resolved_country: String = _country_for_city(era_key, city)

	if resolved_country == "":
		return

	var current_country: String = _selected_text(country_picker)
	if current_country == resolved_country:
		return

	sync_guard = true
	_select_picker_text(country_picker, resolved_country)
	sync_guard = false

	_refresh_city_picker_for_country(city, true)


func _get_game_state() -> GameState:
	if engine == null:
		return null
	return engine.gs


func _era_options_from_engine() -> Array:
	var state: GameState = _get_game_state()

	if state != null and state.era_engine != null and typeof(state.era_engine.eras) == TYPE_DICTIONARY:
		var keys: Array = state.era_engine.eras.keys()
		keys.sort()
		if not keys.is_empty():
			return keys

	if state != null and state.family_creation_contract_engine != null and state.family_creation_contract_engine.has_method("build_world_catalog"):
		var catalog: Dictionary = state.family_creation_contract_engine.build_world_catalog({
			"year": 2000,
			"era": "Modern",
			"reality_mode": _catalog_reality_mode(selected_reality_mode)
		})
		var era_options_raw: Variant = catalog.get("era_options", [])
		if typeof(era_options_raw) == TYPE_ARRAY and not (era_options_raw as Array).is_empty():
			return (era_options_raw as Array).duplicate(true)

	return ["Ancient", "Medieval", "Industrial", "Modern", "Future"]


func _era_country_options(
	era_key: String,
	reality_mode: String
) -> Array:
	var state: GameState = _get_game_state()
	var clean_era: String = str(
		era_key
	).strip_edges()
	var clean_mode: String = str(
		reality_mode
	).strip_edges()
	var prelife_catalog: Dictionary = {}

	if (
		engine != null
		and engine.has_method(
			"emit_prelife_world_catalog"
		)
	):
		prelife_catalog = (
			engine.emit_prelife_world_catalog(
				{
					"year": _selected_birth_year_value(),
					"era": clean_era,
					"reality_mode": (
						_catalog_reality_mode(
							clean_mode
						)
					),
					"source": (
						"god_mode_viewer.country_options"
					),
				}
			)
		)

	var catalog_revision: String = str(
		prelife_catalog.get(
			"catalog_revision",
			"unversioned"
		)
	)
	var cache_key: String = (
		"god_mode_country_catalog:"
		+ "v4_prelife_contract:%s|%s|%s"
		% [
			clean_era,
			clean_mode,
			catalog_revision
		]
	)
	var meta_cache_bucket: String = (
		"god_mode_country_catalog_cache"
	)
	var meta_cache_raw: Variant = get_meta(
		meta_cache_bucket,
		{}
	)
	var meta_cache: Dictionary = (
		meta_cache_raw
		if typeof(meta_cache_raw) == TYPE_DICTIONARY
		else {}
	)

	if meta_cache.has(cache_key):
		var cached_raw: Variant = meta_cache.get(
			cache_key,
			[]
		)

		if (
			typeof(cached_raw) == TYPE_ARRAY
			and not (cached_raw as Array).is_empty()
		):
			return (
				cached_raw as Array
			).duplicate(true)

	var countries: Array = []
	var seen: Dictionary = {}
	var append_country:= func (raw_country) -> void:
		var country: String = (
			_viewer_canonical_country_name(
				str(raw_country)
			)
		)

		if country == "":
			return

		var key: String = country.to_lower()

		if seen.has(key):
			return

		seen [key] = true
		countries.append(country)

	var prelife_countries_raw: Variant = (
		prelife_catalog.get(
			"country_options",
			[]
		)
	)

	if typeof(prelife_countries_raw) == TYPE_ARRAY:
		for raw_country in prelife_countries_raw:
			append_country.call(raw_country)

	var prelife_rows_raw: Variant = (
		prelife_catalog.get(
			"birth_location_rows",
			[]
		)
	)

	if typeof(prelife_rows_raw) == TYPE_ARRAY:
		for raw_row in prelife_rows_raw:
			if typeof(raw_row) != TYPE_DICTIONARY:
				continue

			append_country.call(
				(raw_row as Dictionary).get(
					"country",
					""
				)
			)




	if (
		state != null
		and state.era_engine != null
		and state.era_engine.has_method(
			"get_countries_for_era"
		)
	):
		for raw_country in (
			state.era_engine.get_countries_for_era(
				clean_era
			)
		):
			append_country.call(raw_country)

	for row in _era_birth_location_rows(
		clean_era
	):
		if typeof(row) != TYPE_DICTIONARY:
			continue

		append_country.call(
			(row as Dictionary).get(
				"country",
				""
			)
		)



	for raw_country in (
		_god_mode_static_full_country_catalog_for_era(
			clean_era
		)
	):
		append_country.call(raw_country)

	for raw_country in (
		_fallback_country_options_for_era(
			clean_era
		)
	):
		append_country.call(raw_country)

	for row in (
		_fallback_birth_location_rows_for_era(
			clean_era
		)
	):
		if typeof(row) != TYPE_DICTIONARY:
			continue

		append_country.call(
			(row as Dictionary).get(
				"country",
				""
			)
		)

	countries = _filter_countries_for_reality_mode(
		countries,
		clean_mode
	)
	countries = _dedupe_sorted_strings(
		countries
	)

	meta_cache [cache_key] = countries.duplicate(true)
	set_meta(
		meta_cache_bucket,
		meta_cache
	)

	if (
		state != null
		and typeof(state.scenario_state) == TYPE_DICTIONARY
	):
		state.scenario_state [
			"god_mode_country_catalog_first_entry_complete"
		] = bool(
			prelife_catalog.get(
				"success",
				false
			)
		)
		state.scenario_state [
			"god_mode_country_catalog_revision"
		] = catalog_revision
		state.scenario_state [
			"god_mode_country_catalog_count"
		] = countries.size()
		state.scenario_state [
			"god_mode_country_catalog_required_playable_runtime"
		] = false

	return countries
func _god_mode_static_full_country_catalog_for_era(era_key: String) -> Array:
	var era: String = str(era_key).strip_edges().to_lower()

	match era:
		"ancient":
			return [
				"China",
				"Egypt",
				"Greece",
				"Kush",
				"Persia",
				"Rome",
				"Maurya Empire",
				"Kingdom of Aksum",
				"Earth Kingdom",
				"Fire Nation",
				"Northern Water Tribe",
				"Southern Water Tribe",
				"Northern Air Temple",
				"Southern Air Temple",
				"Eastern Air Temple",
				"Western Air Temple"
			]
		"medieval":
			return [
				"Byzantium",
				"England",
				"France",
				"Japan",
				"Mali",
				"Norway",
				"Earth Kingdom",
				"Fire Nation",
				"Northern Water Tribe",
				"Southern Water Tribe",
				"Northern Air Temple",
				"Southern Air Temple",
				"Eastern Air Temple",
				"Western Air Temple"
			]
		"industrial":
			return [
				"Brazil",
				"England",
				"France",
				"Germany",
				"Japan",
				"United States",
				"Earth Kingdom",
				"Fire Nation",
				"Northern Water Tribe",
				"Southern Water Tribe",
				"Republic City"
			]
		"future":
			return [
				"Atlantic Federation",
				"Lunar Commonwealth",
				"Mars Colony",
				"Neo Japan",
				"Pan-African Union",
				"United States",
				"Sol Colony",
				"Jovian Compact",
				"Saturn Ring Authority",
				"Inner Worlds Treaty",
				"Low Earth Assembly",
				"Deep Space Network",
				"Solar Accord",
				"Western Coalition"
			]
		_:
			return [
				"Brazil",
				"Canada",
				"France",
				"Japan",
				"Mexico",
				"South Korea",
				"United Kingdom",
				"United States",
				"Earth Kingdom",
				"Fire Nation",
				"Northern Water Tribe",
				"Southern Water Tribe",
				"Republic City"
			]
func _era_city_options(
	era_key: String,
	country: String,
	reality_mode: String
) -> Array:
	var state: GameState = _get_game_state()
	var cities: Array = []
	var clean_country: String = (
		_viewer_canonical_country_name(
			country
		)
	)
	var append_city:= func (raw_city) -> void:
		var city: String = str(
			raw_city
		).strip_edges()

		if city != "":
			cities.append(city)

	if (
		engine != null
		and engine.has_method(
			"emit_prelife_world_catalog"
		)
	):
		var prelife_catalog: Dictionary = (
			engine.emit_prelife_world_catalog(
				{
					"year": _selected_birth_year_value(),
					"era": era_key,
					"country": clean_country,
					"reality_mode": (
						_catalog_reality_mode(
							reality_mode
						)
					),
					"source": (
						"god_mode_viewer.city_options"
					),
				}
			)
		)
		var contract_cities_raw: Variant = (
			prelife_catalog.get(
				"city_options",
				[]
			)
		)

		if typeof(contract_cities_raw) == TYPE_ARRAY:
			for raw_city in contract_cities_raw:
				append_city.call(raw_city)

	for row in _era_birth_location_rows(
		era_key
	):
		if typeof(row) != TYPE_DICTIONARY:
			continue

		var location: Dictionary = row as Dictionary
		var row_country: String = (
			_viewer_canonical_country_name(
				str(
					location.get(
						"country",
						""
					)
				)
			)
		)

		if (
			clean_country != ""
			and not _viewer_country_names_match(
				row_country,
				clean_country
			)
		):
			continue

		append_city.call(
			location.get(
				"city",
				""
			)
		)

	if (
		state != null
		and state.era_engine != null
		and state.era_engine.has_method(
			"get_cities_for_era_country"
		)
	):
		for alias_country in (
			_viewer_country_lookup_aliases(
				clean_country
			)
		):
			for raw_city in (
				state.era_engine
				.get_cities_for_era_country(
					era_key,
					str(alias_country)
				)
			):
				append_city.call(raw_city)

	cities = _filter_cities_for_reality_mode(
		era_key,
		cities,
		reality_mode
	)

	return _dedupe_sorted_strings(
		cities
	)

func _country_for_city(
	era_key: String,
	city: String
) -> String:
	var clean_city: String = str(
		city
	).strip_edges()

	if clean_city == "":
		return ""

	for row in _era_birth_location_rows(
		era_key
	):
		if typeof(row) != TYPE_DICTIONARY:
			continue

		var location: Dictionary = row as Dictionary
		var row_city: String = str(
			location.get(
				"city",
				""
			)
		).strip_edges()

		if row_city.to_lower() == clean_city.to_lower():
			return _viewer_canonical_country_name(
				str(
					location.get(
						"country",
						""
					)
				)
			)

	return ""

func _era_birth_location_rows(
	era_key: String
) -> Array:
	if (
		engine != null
		and engine.has_method(
			"emit_prelife_world_catalog"
		)
	):
		var prelife_catalog: Dictionary = (
			engine.emit_prelife_world_catalog(
				{
					"year": _selected_birth_year_value(),
					"era": era_key,
					"reality_mode": (
						_catalog_reality_mode(
							selected_reality_mode
						)
					),
					"source": (
						"god_mode_viewer.birth_location_rows"
					),
				}
			)
		)
		var rows_raw: Variant = prelife_catalog.get(
			"birth_location_rows",
			[]
		)

		if (
			typeof(rows_raw) == TYPE_ARRAY
			and not (rows_raw as Array).is_empty()
		):
			return _sort_location_rows(
				(rows_raw as Array).duplicate(true)
			)

	var state: GameState = _get_game_state()

	if (
		state != null
		and state.era_engine != null
		and state.era_engine.has_method(
			"get_birth_locations_for_era"
		)
	):
		var runtime_rows: Array = (
			state.era_engine
			.get_birth_locations_for_era(
				era_key
			)
		)

		if not runtime_rows.is_empty():
			return _sort_location_rows(
				runtime_rows
			)

	return _sort_location_rows(
		_fallback_birth_location_rows_for_era(
			era_key
		)
	)


func _catalog_reality_mode(reality_mode: String) -> String:
	var clean_mode: String = str(reality_mode).strip_edges().to_lower()

	if clean_mode == "realistic":
		return "realistic"
	if clean_mode == "enhanced":
		return "enhanced"

	return "chaos"


func _filter_countries_for_reality_mode(countries: Array, reality_mode: String) -> Array:
	var clean_mode: String = str(reality_mode).strip_edges().to_lower()
	var out: Array = []

	for raw_country in countries:
		var country: String = str(raw_country).strip_edges()
		if country == "":
			continue

		if clean_mode == "realistic" and _is_elemental_country_name(country):
			continue

		out.append(country)

	return out


func _filter_cities_for_reality_mode(_era_key: String, cities: Array, _reality_mode: String) -> Array:
	var out: Array = []

	for raw_city in cities:
		var city: String = str(raw_city).strip_edges()
		if city == "":
			continue
		out.append(city)

	return out


func _is_elemental_country_name(country: String) -> bool:
	var normalized: String = str(country).strip_edges().to_lower()

	return normalized.find("fire nation") >= 0 \
or normalized.find("earth kingdom") >= 0 \
or normalized.find("water tribe") >= 0 \
or normalized.find("air temple") >= 0 \
or normalized.find("air nomad") >= 0 \
or normalized.find("republic city") >= 0


func _fallback_country_options_for_era(era_key: String) -> Array:
	var era: String = str(era_key).strip_edges().to_lower()

	match era:
		"ancient":
			return ["China", "Egypt", "Greece", "Kush", "Persia", "Rome", "Maurya Empire", "Kingdom of Aksum", "Earth Kingdom", "Fire Nation", "Northern Water Tribe", "Southern Water Tribe", "Northern Air Temple", "Southern Air Temple", "Eastern Air Temple", "Western Air Temple"]

		"medieval":
			return ["Byzantium", "England", "France", "Japan", "Mali", "Norway", "Earth Kingdom", "Fire Nation", "Northern Water Tribe", "Southern Water Tribe", "Northern Air Temple", "Southern Air Temple", "Eastern Air Temple", "Western Air Temple"]

		"industrial":
			return ["Brazil", "England", "France", "Germany", "Japan", "United States", "Earth Kingdom", "Fire Nation", "Northern Water Tribe", "Southern Water Tribe", "Republic City"]

		"future":
			return ["Atlantic Federation", "Lunar Commonwealth", "Mars Colony", "Neo Japan", "Pan-African Union", "United States", "Sol Colony", "Jovian Compact", "Saturn Ring Authority", "Inner Worlds Treaty", "Low Earth Assembly", "Deep Space Network", "Solar Accord", "Western Coalition"]

		_:
			return ["Brazil", "Canada", "France", "Japan", "Mexico", "South Korea", "United Kingdom", "United States", "Earth Kingdom", "Fire Nation", "Northern Water Tribe", "Southern Water Tribe", "Republic City"]


func _fallback_birth_location_rows_for_era(era_key: String) -> Array:
	var era: String = str(era_key).strip_edges().to_lower()

	var elemental_rows: Array = [
		{ "city": "Ba Sing Se", "country": "Earth Kingdom"},
		{ "city": "Omashu", "country": "Earth Kingdom"},
		{ "city": "Zaofu", "country": "Earth Kingdom"},
		{ "city": "Gaoling", "country": "Earth Kingdom"},
		{ "city": "Makapu", "country": "Earth Kingdom"},
		{ "city": "Taku", "country": "Earth Kingdom"},
		{ "city": "Capital City", "country": "Fire Nation"},
		{ "city": "Caldera City", "country": "Fire Nation"},
		{ "city": "Ember Island", "country": "Fire Nation"},
		{ "city": "Yu Dao", "country": "Fire Nation"},
		{ "city": "Shu Jing", "country": "Fire Nation"},
		{ "city": "Hari Bulkan", "country": "Fire Nation"},
		{ "city": "Agna Qel'a", "country": "Northern Water Tribe"},
		{ "city": "Taku", "country": "Northern Water Tribe"},
		{ "city": "Ice Dock", "country": "Northern Water Tribe"},
		{ "city": "Wolf Cove", "country": "Southern Water Tribe"},
		{ "city": "Whaletail Harbor", "country": "Southern Water Tribe"},
		{ "city": "Glacier Camp", "country": "Southern Water Tribe"},
		{ "city": "Northern Monastery", "country": "Northern Air Temple"},
		{ "city": "Northern Sanctuary", "country": "Northern Air Temple"},
		{ "city": "Southern Monastery", "country": "Southern Air Temple"},
		{ "city": "Southern Sanctuary", "country": "Southern Air Temple"},
		{ "city": "Eastern Spires", "country": "Eastern Air Temple"},
		{ "city": "Eastern Sanctuary", "country": "Eastern Air Temple"},
		{ "city": "Western Cloisters", "country": "Western Air Temple"},
		{ "city": "Western Sanctuary", "country": "Western Air Temple"}
	]

	var rows: Array = []

	match era:
		"ancient":
			rows = [
				{ "city": "Rome", "country": "Rome"},
				{ "city": "Pompeii", "country": "Rome"},
				{ "city": "Alexandria", "country": "Egypt"},
				{ "city": "Memphis", "country": "Egypt"},
				{ "city": "Athens", "country": "Greece"},
				{ "city": "Sparta", "country": "Greece"},
				{ "city": "Chang'an", "country": "China"},
				{ "city": "Persepolis", "country": "Persia"},
				{ "city": "Meroë", "country": "Kush"},
				{ "city": "Pataliputra", "country": "Maurya Empire"},
				{ "city": "Aksum", "country": "Kingdom of Aksum"}
			]

		"medieval":
			rows = [
				{ "city": "London", "country": "England"},
				{ "city": "York", "country": "England"},
				{ "city": "Paris", "country": "France"},
				{ "city": "Orléans", "country": "France"},
				{ "city": "Constantinople", "country": "Byzantium"},
				{ "city": "Kyoto", "country": "Japan"},
				{ "city": "Kamakura", "country": "Japan"},
				{ "city": "Timbuktu", "country": "Mali"},
				{ "city": "Niani", "country": "Mali"},
				{ "city": "Bergen", "country": "Norway"}
			]

		"industrial":
			rows = [
				{ "city": "New York", "country": "United States"},
				{ "city": "Chicago", "country": "United States"},
				{ "city": "Detroit", "country": "United States"},
				{ "city": "Manchester", "country": "England"},
				{ "city": "London", "country": "England"},
				{ "city": "Paris", "country": "France"},
				{ "city": "Lyon", "country": "France"},
				{ "city": "Berlin", "country": "Germany"},
				{ "city": "Hamburg", "country": "Germany"},
				{ "city": "Tokyo", "country": "Japan"},
				{ "city": "São Paulo", "country": "Brazil"}
			]

		"future":
			rows = [
				{ "city": "Neo Detroit", "country": "United States"},
				{ "city": "Tokyo Arcology", "country": "Neo Japan"},
				{ "city": "Olympus City", "country": "Mars Colony"},
				{ "city": "Astra Vale", "country": "Western Coalition"},
				{ "city": "Lunar One", "country": "Lunar Commonwealth"},
				{ "city": "Europa Station", "country": "Jovian Compact"},
				{ "city": "Titan Harbor", "country": "Saturn Ring Authority"},
				{ "city": "Mercury Shade Base", "country": "Inner Worlds Treaty"},
				{ "city": "Orbital Geneva", "country": "Low Earth Assembly"},
				{ "city": "Kepler Relay", "country": "Deep Space Network"},
				{ "city": "Helios Ring", "country": "Solar Accord"}
			]

		_:
			rows = [
				{ "city": "Angleton", "country": "United States"},
				{ "city": "Ann Arbor", "country": "United States"},
				{ "city": "New York", "country": "United States"},
				{ "city": "Toronto", "country": "Canada"},
				{ "city": "Tokyo", "country": "Japan"},
				{ "city": "Paris", "country": "France"},
				{ "city": "Seoul", "country": "South Korea"},
				{ "city": "London", "country": "United Kingdom"},
				{ "city": "Mexico City", "country": "Mexico"},
				{ "city": "São Paulo", "country": "Brazil"}
			]

	if selected_reality_mode != "realistic":
		rows.append_array(elemental_rows)

	return _sort_location_rows(rows)


func _sort_location_rows(rows: Array) -> Array:
	var out: Array = []

	for raw_row in rows:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = raw_row as Dictionary
		var city: String = str(row.get("city", "")).strip_edges()
		var country: String = str(row.get("country", "")).strip_edges()

		if city == "" or country == "":
			continue

		out.append({
			"city": city,
			"country": country
		})

	out.sort_custom(func (a, b):
		var a_country: String = str(a.get("country", "")).to_lower()
		var b_country: String = str(b.get("country", "")).to_lower()

		if a_country == b_country:
			return str(a.get("city", "")).to_lower() < str(b.get("city", "")).to_lower()

		return a_country < b_country
	)

	return out


func _dedupe_sorted_strings(values: Array) -> Array:
	var out: Array = []
	var seen:= {}

	for raw_value in values:
		var value: String = str(raw_value).strip_edges()
		if value == "":
			continue

		var key: String = value.to_lower()
		if seen.has(key):
			continue

		seen [key] = true
		out.append(value)

	out.sort()
	return out
func refresh_location_pickers(preferred_country: String = "", preferred_city: String = "", force_city_selection: bool = false) -> void:
	_refresh_location_pickers(preferred_country, preferred_city, force_city_selection)
	_refresh_preview()
	_apply_palette(true)


func _refresh_preview() -> void:
	if preview_label == null or not is_instance_valid(preview_label):
		return

	var birth_year: int = _selected_birth_year_value()
	var era_key: String = _era_key_for_birth_year_value(birth_year)
	var first_name: String = first_name_edit.text.strip_edges() if first_name_edit != null else "Someone"
	var last_name: String = last_name_edit.text.strip_edges() if last_name_edit != null else ""
	var city: String = _selected_text(city_picker)
	var country: String = _selected_text(country_picker)
	var birth_month: String = _selected_text(birth_month_picker)
	var bending_type: String = _selected_text(bending_type_picker)
	var mode_text: String = _viewer_reality_mode_label(selected_reality_mode)
	var social_class_label: String = _selected_text(social_class_picker)
	var social_class_value: String = _normalize_social_class_picker_value(social_class_label)
	var royal_rank_label: String = _selected_text(royal_rank_picker)
	var rank_text: String = ""

	if bending_type.strip_edges() == "":
		bending_type = "None"

	if social_class_value in ["Royal", "Noble"] and royal_rank_label.strip_edges() != "":
		rank_text = " • Rank: %s" % royal_rank_label

	preview_label.text = "%s %s will step into %s in %s, %s • Year %s • %s • %s • Class: %s%s • Bending: %s" % [
		first_name,
		last_name,
		mode_text,
		city,
		country,
		_birth_year_display_text_for_value(birth_year),
		_era_display_name_for_key(era_key),
		birth_month,
		social_class_label,
		rank_text,
		bending_type
	]

	preview_label.add_theme_font_size_override("font_size", 18)
	preview_label.add_theme_constant_override("shadow_offset_x", 0)
	preview_label.add_theme_constant_override("shadow_offset_y", 0)
	preview_visual_dirty = true
func _apply_palette(_animated: bool = false) -> void:
	var palette: Dictionary = _palette()
	var accent: Color = Color(palette.get("accent", Color(0.0, 0.95, 1.0, 1.0)))
	var bg: Color = Color(palette.get("bg", Color(0.01, 0.14, 0.16, 0.965)))
	var glow: Color = Color(palette.get("glow", Color(0.0, 0.95, 1.0, 0.36)))

	if background_dim != null and is_instance_valid(background_dim):
		background_dim.color = Color(bg.r * 0.08, bg.g * 0.08, bg.b * 0.1, 0.975)

	var panel_style:= StyleBoxFlat.new()
	panel_style.bg_color = bg
	panel_style.border_color = accent
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(20)
	panel_style.shadow_color = glow
	panel_style.shadow_size = 42
	panel_style.shadow_offset = Vector2.ZERO

	if panel != null and is_instance_valid(panel):
		panel.add_theme_stylebox_override("panel", panel_style)

	if title_label != null and is_instance_valid(title_label):
		title_label.add_theme_color_override("font_color", Color(palette.get("title", Color(0.84, 1.0, 1.0, 1.0))))
		title_label.add_theme_color_override("font_shadow_color", Color(accent.r, accent.g, accent.b, 0.62))
		title_label.add_theme_constant_override("shadow_offset_x", 0)
		title_label.add_theme_constant_override("shadow_offset_y", 0)
		title_label.add_theme_font_size_override("font_size", 34)

	_style_mode_buttons(accent, bg)
	_style_button(prewarm_button, Color(bg.r * 0.78, bg.g * 0.92, bg.b * 0.98, 0.94), accent)
	_style_button(ready_button, Color(bg.r * 0.72, bg.g * 0.84, bg.b * 0.92, 0.94), accent)
	_style_circle_button(back_button, accent)

	_style_form_controls(accent, bg)
	_style_scrollbar(accent, scrollbar_target_alpha)
	_ensure_prewarm_button_layers()

	stat_slider_visuals_dirty = true
	preview_visual_dirty = true

	if visible:
		_tick_stat_slider_visuals()
		_tick_preview_label_visuals()

	_update_subtitle_rich_text()
func _style_circle_button(button: Button, accent: Color) -> void:
	if button == null or not is_instance_valid(button):
		return

	var normal:= StyleBoxFlat.new()
	normal.bg_color = Color(accent.r * 0.08, accent.g * 0.14, accent.b * 0.16, 0.88)
	normal.border_color = accent
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(999)
	normal.shadow_color = Color(accent.r, accent.g, accent.b, 0.55)
	normal.shadow_size = 22

	var hover:= normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(accent.r * 0.14, accent.g * 0.22, accent.b * 0.26, 0.96)
	hover.shadow_color = Color(accent.r, accent.g, accent.b, 0.82)
	hover.shadow_size = 32

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_color_override("font_color", Color(0.82, 1.0, 1.0, 1.0))
	button.add_theme_font_size_override("font_size", 24)


func _style_form_controls(accent: Color, bg: Color) -> void:
	var controls: Array = [
		first_name_edit,
		last_name_edit,
		gender_picker,
		bending_type_picker,
		birth_year_picker,
		birth_year_custom_edit,
		birth_month_picker,
		birth_day_spin,
		era_picker,
		country_picker,
		city_picker,
		social_class_picker,
		royal_rank_picker,
		bank_balance_picker
	]

	for control in controls:
		if control == null or not is_instance_valid(control):
			continue

		var normal:= StyleBoxFlat.new()
		normal.bg_color = Color(bg.r * 0.74, bg.g * 0.92, bg.b * 0.96, 0.56)
		normal.border_color = Color(accent.r, accent.g, accent.b, 0.52)
		normal.set_border_width_all(1)
		normal.set_corner_radius_all(9)
		normal.shadow_color = Color(accent.r, accent.g, accent.b, 0.14)
		normal.shadow_size = 8

		var hover:= normal.duplicate() as StyleBoxFlat
		hover.bg_color = Color(bg.r * 0.86, bg.g * 1.05, bg.b * 1.1, 0.68)
		hover.border_color = Color(accent.r, accent.g, accent.b, 0.82)
		hover.shadow_color = Color(accent.r, accent.g, accent.b, 0.28)
		hover.shadow_size = 14

		var focus:= hover.duplicate() as StyleBoxFlat
		focus.border_color = Color(1.0, 0.76, 0.24, 0.96)
		focus.set_border_width_all(2)

		control.add_theme_stylebox_override("normal", normal)
		control.add_theme_stylebox_override("hover", hover)
		control.add_theme_stylebox_override("pressed", hover)
		control.add_theme_stylebox_override("focus", focus)
		control.add_theme_color_override("font_color", Color(0.88, 1.0, 1.0, 1.0))
		control.add_theme_color_override("font_focus_color", Color(1.0, 0.94, 0.72, 1.0))
		control.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))

		if control is OptionButton:
			_style_option_popup_menu((control as OptionButton).get_popup(), accent, bg)

		if control is SpinBox:
			var line_edit:= (control as SpinBox).get_line_edit()
			if line_edit != null and is_instance_valid(line_edit):
				line_edit.add_theme_stylebox_override("normal", normal)
				line_edit.add_theme_stylebox_override("focus", focus)
				line_edit.add_theme_color_override("font_color", Color(0.88, 1.0, 1.0, 1.0))

func _style_bending_type_picker() -> void:
	if (
		bending_type_picker == null
		or not is_instance_valid(
			bending_type_picker
		)
	):
		return

	_ensure_avatar_bending_type_picker_option()

	var bending_type: String = (
		_selected_text(
			bending_type_picker
		)
	)
	var is_avatar: bool = (
		bending_type.strip_edges().to_lower()
		== "avatar"
	)
	var color: Color = (
		Color(
			0.86,
			0.88,
			1.0,
			1.0
		)
		if is_avatar
		else _elemental_nation_color_for_text(
			bending_type
		)
	)

	_style_single_picker_as_elemental(
		bending_type_picker,
		color
	)

	_tick_avatar_bending_picker_border()
func _ensure_avatar_bending_type_picker_option() -> void:
	if (
		bending_type_picker == null
		or not is_instance_valid(
			bending_type_picker
		)
	):
		return

	for index in range(
		bending_type_picker.item_count
	):
		if str(
			bending_type_picker.get_item_text(
				index
			)
		).strip_edges().to_lower() == "avatar":
			return

	bending_type_picker.add_item(
		"Avatar"
	)


func _style_elemental_location_controls() -> void:
	var country_color: Color = _elemental_nation_color_for_text(_selected_text(country_picker))
	var city_color: Color = _elemental_nation_color_for_text(_selected_text(city_picker))

	if country_picker != null and is_instance_valid(country_picker):
		_style_single_picker_as_elemental(country_picker, country_color)

	if city_picker != null and is_instance_valid(city_picker):
		_style_single_picker_as_elemental(city_picker, city_color)


func _style_single_picker_as_elemental(picker: OptionButton, color: Color) -> void:
	if picker == null or not is_instance_valid(picker):
		return

	var normal:= StyleBoxFlat.new()
	normal.bg_color = Color(color.r * 0.12, color.g * 0.12, color.b * 0.12, 0.62)
	normal.border_color = Color(color.r, color.g, color.b, 0.78)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(9)
	normal.shadow_color = Color(color.r, color.g, color.b, 0.24)
	normal.shadow_size = 12

	var hover:= normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(color.r * 0.18, color.g * 0.18, color.b * 0.18, 0.74)
	hover.border_color = Color(color.r, color.g, color.b, 0.96)
	hover.shadow_color = Color(color.r, color.g, color.b, 0.42)
	hover.shadow_size = 18

	picker.add_theme_stylebox_override("normal", normal)
	picker.add_theme_stylebox_override("hover", hover)
	picker.add_theme_stylebox_override("pressed", hover)
	picker.add_theme_stylebox_override("focus", hover)
	picker.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.96))
	picker.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.72, 1.0))

	var popup:= picker.get_popup()
	if popup != null and is_instance_valid(popup):
		_style_option_popup_menu(popup, color, Color(color.r * 0.08, color.g * 0.08, color.b * 0.1, 0.98))


func _elemental_nation_color_for_text(text: String) -> Color:
	var clean_text: String = str(text).strip_edges().to_lower()

	if clean_text.find("fire") >= 0:
		return Color(1.0, 0.18, 0.08, 1.0)

	if clean_text.find("water") >= 0:
		return Color(0.16, 0.56, 1.0, 1.0)

	if clean_text.find("earth") >= 0:
		return Color(0.35, 0.82, 0.28, 1.0)

	if clean_text.find("air") >= 0:
		return Color(0.88, 0.92, 1.0, 1.0)

	return Color(_palette().get("accent", Color(0.0, 0.95, 1.0, 1.0)))
func _style_scrollbar(accent: Color, alpha: float = 0.0) -> void:
	if scroll_bar == null or not is_instance_valid(scroll_bar):
		return

	var clean_alpha: float = clamp(alpha, 0.0, 1.0)

	var track:= StyleBoxFlat.new()
	track.bg_color = Color(accent.r * 0.04, accent.g * 0.05, accent.b * 0.07, 0.02 * clean_alpha)
	track.set_corner_radius_all(999)

	var grabber:= StyleBoxFlat.new()
	grabber.bg_color = Color(accent.r, accent.g, accent.b, 0.7 * clean_alpha)
	grabber.border_color = Color(accent.r, accent.g, accent.b, 0.95 * clean_alpha)
	grabber.set_border_width_all(1)
	grabber.set_corner_radius_all(999)
	grabber.shadow_color = Color(accent.r, accent.g, accent.b, 0.72 * clean_alpha)
	grabber.shadow_size = 14

	scroll_bar.custom_minimum_size = Vector2(8, 0)
	scroll_bar.add_theme_stylebox_override("scroll", track)
	scroll_bar.add_theme_stylebox_override("grabber", grabber)
	scroll_bar.add_theme_stylebox_override("grabber_highlight", grabber)
	scroll_bar.add_theme_stylebox_override("grabber_pressed", grabber)
	scroll_bar.modulate.a = clean_alpha


func _style_stat_sliders(accent: Color) -> void:
	for row in _stat_slider_rows():
		var slider: HSlider = row.get("slider", null)
		if slider == null or not is_instance_valid(slider):
			continue

		var stat_color: Color = Color(row.get("color", accent))
		var track:= slider.get_meta("god_mode_energy_track", null) as PanelContainer
		var fill_base:= slider.get_meta("god_mode_energy_fill_base", null) as ColorRect
		var flow_a:= slider.get_meta("god_mode_energy_flow_a", null) as ColorRect
		var flow_b:= slider.get_meta("god_mode_energy_flow_b", null) as ColorRect
		var thumb:= slider.get_meta("god_mode_energy_thumb", null) as PanelContainer
		var value_label:= slider.get_meta("god_mode_energy_value_label", null) as Label

		if track != null and is_instance_valid(track):
			var track_style:= StyleBoxFlat.new()
			track_style.bg_color = Color(stat_color.r * 0.1, stat_color.g * 0.1, stat_color.b * 0.1, 0.42)
			track_style.border_color = Color(stat_color.r, stat_color.g, stat_color.b, 0.4)
			track_style.set_border_width_all(1)
			track_style.set_corner_radius_all(999)
			track_style.shadow_color = Color(stat_color.r, stat_color.g, stat_color.b, 0.18)
			track_style.shadow_size = 10
			track.add_theme_stylebox_override("panel", track_style)

		if fill_base != null and is_instance_valid(fill_base):
			fill_base.color = Color(stat_color.r, stat_color.g, stat_color.b, 0.72)

		if flow_a != null and is_instance_valid(flow_a):
			flow_a.color = Color(1.0, 1.0, 1.0, 0.2)

		if flow_b != null and is_instance_valid(flow_b):
			flow_b.color = Color(stat_color.r, stat_color.g, stat_color.b, 0.34)

		if thumb != null and is_instance_valid(thumb):
			var thumb_style:= StyleBoxFlat.new()
			thumb_style.bg_color = Color(1.0, 1.0, 1.0, 0.96)
			thumb_style.border_color = Color(stat_color.r, stat_color.g, stat_color.b, 1.0)
			thumb_style.set_border_width_all(2)
			thumb_style.set_corner_radius_all(999)
			thumb_style.shadow_color = Color(stat_color.r, stat_color.g, stat_color.b, 0.72)
			thumb_style.shadow_size = 14
			thumb.add_theme_stylebox_override("panel", thumb_style)

		if value_label != null and is_instance_valid(value_label):
			value_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.96))
			value_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.82))
			value_label.add_theme_constant_override("shadow_offset_x", 1)
			value_label.add_theme_constant_override("shadow_offset_y", 1)

		_update_stat_energy_bar(slider, true)

func _stat_slider_rows() -> Array:
	return [
		{ "slider": happiness_slider, "color": Color(1.0, 0.82, 0.25, 1.0)},
		{ "slider": health_slider, "color": Color(1.0, 0.16, 0.42, 1.0)},
		{ "slider": smarts_slider, "color": Color(0.12, 0.82, 1.0, 1.0)},
		{ "slider": looks_slider, "color": Color(1.0, 0.26, 0.92, 1.0)},
		{ "slider": mental_health_slider, "color": Color(0.2, 1.0, 0.82, 1.0)},
		{ "slider": fertility_slider, "color": Color(0.72, 0.36, 1.0, 1.0)}
	]


func _tick_stat_slider_visuals() -> void:
	if not visible:
		return

	_style_stat_sliders(Color(_palette().get("accent", Color(0.0, 0.95, 1.0, 1.0))))
	_tick_stat_energy_bar_motion()
func _tick_title_glitch() -> void:
	if title_label == null or not is_instance_valid(title_label):
		return

	var now_ms: int = int(Time.get_ticks_msec())
	var palette: Dictionary = _palette()
	var accent: Color = Color(palette.get("accent", Color(0.0, 0.95, 1.0, 1.0)))

	if title_glitch_next_ms <= 0:
		title_glitch_next_ms = now_ms + GOD_MODE_VIEWER_TITLE_GLITCH_INTERVAL_MS

	if now_ms >= title_glitch_next_ms:
		title_glitch_until_ms = now_ms + GOD_MODE_VIEWER_TITLE_GLITCH_DURATION_MS
		title_glitch_next_ms = now_ms + GOD_MODE_VIEWER_TITLE_GLITCH_INTERVAL_MS

	if now_ms < title_glitch_until_ms:
		var flicker: float = 0.5 + 0.5 * sin(float(now_ms) * 0.085)
		title_label.text = "CHOOSE YOUR ERE∆LITY" if flicker > 0.5 else "CHOOSE YOUR EREALITY"
		title_label.add_theme_color_override("font_color", accent.lerp(Color(1.0, 0.12, 0.42, 1.0), flicker))
		title_label.add_theme_color_override("font_shadow_color", Color(1.0, 0.12, 0.42, 0.88))
	else:
		title_label.text = title_base_text
		title_label.add_theme_color_override("font_color", Color(0.82, 1.0, 1.0, 1.0))
		title_label.add_theme_color_override("font_shadow_color", Color(accent.r, accent.g, accent.b, 0.58))


func _update_subtitle_rich_text() -> void:
	if subtitle_label == null or not is_instance_valid(subtitle_label):
		return

	var era_color: Color = _era_word_color()
	var blood_pulse: float = 0.55 + 0.45 * sin(visual_phase * 3.4)
	var blood_color:= Color(1.0, 0.02 + blood_pulse * 0.1, 0.04 + blood_pulse * 0.08, 1.0)

	subtitle_label.text = "[center]Shape your life, the [color=#%s]Era[/color], your [color=#%s]bloodline[/color], and the supernatural rules before your first breath.[/center]" % [
		era_color.to_html(false),
		blood_color.to_html(false)
	]


func _era_word_color() -> Color:
	var era: String = _selected_text(era_picker).strip_edges().to_lower()
	var pulse: float = 0.45 + 0.55 * sin(visual_phase * 1.45)

	match era:
		"ancient":
			return Color(0.0, 0.95 + pulse * 0.05, 0.72 + pulse * 0.18, 1.0)
		"medieval":
			return Color(0.62 + pulse * 0.24, 0.3 + pulse * 0.16, 1.0, 1.0)
		"industrial":
			return Color(1.0, 0.45 + pulse * 0.24, 0.14, 1.0)
		"modern":
			return Color(0.0, 0.78 + pulse * 0.18, 1.0, 1.0)
		"future":
			return Color(0.36 + pulse * 0.24, 1.0, 0.88 + pulse * 0.12, 1.0)
		_:
			return Color(0.0, 0.95, 1.0, 1.0)
func _on_scrollbar_value_changed(value: float) -> void:
	if abs(value - scrollbar_last_value) <= 0.001:
		return

	scrollbar_last_value = value
	_show_scrollbar_for_activity("scroll_value_changed")


func _show_scrollbar_for_activity(reason: String = "scrollbar_activity") -> void:
	scrollbar_last_activity_ms = int(Time.get_ticks_msec())
	_set_scrollbar_alpha_target(1.0, GOD_MODE_VIEWER_SCROLLBAR_FADE_IN_SECONDS, reason)


func _tick_scrollbar_visibility() -> void:
	if scroll_bar == null or not is_instance_valid(scroll_bar):
		return

	var now_ms: int = int(Time.get_ticks_msec())
	if scrollbar_last_activity_ms <= 0:
		_set_scrollbar_alpha_target(0.0, 0.0, "scrollbar_idle_initial")
		return

	if now_ms - scrollbar_last_activity_ms > 40:
		_set_scrollbar_alpha_target(0.0, GOD_MODE_VIEWER_SCROLLBAR_FADE_OUT_SECONDS, "scrollbar_idle_fade")


func _set_scrollbar_alpha_target(alpha: float, duration: float, reason: String = "scrollbar_alpha") -> void:
	var clean_alpha: float = clamp(alpha, 0.0, 1.0)
	if abs(scrollbar_target_alpha - clean_alpha) <= 0.01:
		return

	scrollbar_target_alpha = clean_alpha

	if scrollbar_fade_tween != null and scrollbar_fade_tween.is_valid():
		scrollbar_fade_tween.kill()

	if scroll_bar == null or not is_instance_valid(scroll_bar):
		return

	var accent: Color = Color(_palette().get("accent", Color(0.0, 0.95, 1.0, 1.0)))

	if duration <= 0.0:
		_style_scrollbar(accent, clean_alpha)
		return

	scrollbar_fade_tween = create_tween()
	scrollbar_fade_tween.set_trans(Tween.TRANS_SINE)
	scrollbar_fade_tween.set_ease(Tween.EASE_OUT)
	scrollbar_fade_tween.tween_method(
		func (v: float) -> void:
			_style_scrollbar(accent, v),
		scroll_bar.modulate.a,
		clean_alpha,
		duration
	)
	set_meta("god_mode_scrollbar_alpha_reason", reason)


func _palette() -> Dictionary:
	var era: String = _selected_text(era_picker).strip_edges().to_lower()
	var mode: String = selected_reality_mode.strip_edges().to_lower()

	var accent:= Color(0.0, 0.9, 1.0, 1.0)

	match era:
		"ancient":
			accent = Color(0.0, 0.95, 0.82, 1.0)
		"medieval":
			accent = Color(0.75, 0.45, 1.0, 1.0)
		"industrial":
			accent = Color(1.0, 0.58, 0.22, 1.0)
		"modern":
			accent = Color(0.0, 0.85, 1.0, 1.0)
		"future":
			accent = Color(0.5, 1.0, 0.95, 1.0)

	if mode == "chaos":
		accent = accent.lerp(Color(1.0, 0.18, 0.44, 1.0), 0.35)
	elif mode == "enhanced":
		accent = accent.lerp(Color(0.3, 0.42, 1.0, 1.0), 0.25)
	elif mode == "realistic":
		accent = accent.lerp(Color(0.86, 0.86, 0.78, 1.0), 0.3)

	return {
		"accent": accent,
		"bg": Color(accent.r * 0.08, accent.g * 0.14, accent.b * 0.16, 0.94),
		"glow": Color(accent.r, accent.g, accent.b, 0.3),
		"title": Color(0.78 + accent.r * 0.2, 0.88 + accent.g * 0.1, 0.88 + accent.b * 0.1, 1.0),
		"button": Color(accent.r * 0.12, accent.g * 0.14, accent.b * 0.18, 0.92)
	}


func _style_button(button: Button, bg: Color, border: Color) -> void:
	if button == null or not is_instance_valid(button):
		return

	var normal:= StyleBoxFlat.new()
	normal.bg_color = bg
	normal.border_color = border
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(12)
	normal.shadow_color = Color(border.r, border.g, border.b, 0.18)
	normal.shadow_size = 10

	var hover:= normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(bg.r * 1.12, bg.g * 1.12, bg.b * 1.12, min(bg.a + 0.04, 1.0))
	hover.border_color = Color(border.r, border.g, border.b, 0.88)
	hover.shadow_color = Color(border.r, border.g, border.b, 0.36)
	hover.shadow_size = 18

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", Color(0.88, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
func _style_mode_buttons(accent: Color, bg: Color) -> void:
	_style_mode_button(realistic_button, "realistic", accent, bg)
	_style_mode_button(enhanced_button, "enhanced", accent, bg)
	_style_mode_button(fantasy_button, "chaos", accent, bg)


func _style_mode_button(button: Button, mode: String, accent: Color, bg: Color) -> void:
	if button == null or not is_instance_valid(button):
		return

	var clean_mode: String = str(mode).strip_edges().to_lower()
	var selected: bool = selected_reality_mode.strip_edges().to_lower() == clean_mode
	var gold:= Color(1.0, 0.76, 0.24, 1.0)
	var mode_color: Color = _reality_mode_color(clean_mode, accent)
	var base: Color = Color(bg.r * 0.86, bg.g * 0.94, bg.b * 1.04, 0.88).lerp(mode_color, 0.18)

	if clean_mode == "chaos":
		base = Color(bg.r * 0.92, bg.g * 0.62, bg.b * 1.08, 0.9).lerp(mode_color, 0.24)
	elif clean_mode == "enhanced":
		base = Color(bg.r * 0.72, bg.g * 0.82, bg.b * 1.16, 0.9).lerp(mode_color, 0.22)
	elif clean_mode == "realistic":
		base = Color(bg.r * 0.86, bg.g * 0.86, bg.b * 0.76, 0.9).lerp(mode_color, 0.14)

	var normal:= StyleBoxFlat.new()
	normal.bg_color = base
	normal.border_color = gold if selected else Color(mode_color.r, mode_color.g, mode_color.b, 0.48)
	normal.set_border_width_all(3 if selected else 1)
	normal.set_corner_radius_all(15)
	normal.shadow_color = Color(gold.r, gold.g, gold.b, 0.52) if selected else Color(mode_color.r, mode_color.g, mode_color.b, 0.2)
	normal.shadow_size = 28 if selected else 12

	var hover:= normal.duplicate() as StyleBoxFlat
	hover.bg_color = base.lerp(Color(1.0, 1.0, 1.0, 1.0), 0.1)
	hover.shadow_size = 34 if selected else 18

	button.custom_minimum_size = Vector2(0, GOD_MODE_VIEWER_MODE_SELECTED_HEIGHT if selected else GOD_MODE_VIEWER_MODE_NORMAL_HEIGHT)
	button.scale = Vector2(1.025, 1.025) if selected else Vector2.ONE
	button.pivot_offset = button.size * 0.5
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", Color(1.0, 0.94, 0.72, 1.0) if selected else Color(0.84, 1.0, 1.0, 0.92))
	button.add_theme_font_size_override("font_size", 16 if selected else 15)


func _reality_mode_color(mode: String, fallback: Color) -> Color:
	match _viewer_canonical_reality_mode(mode):
		"realistic":
			return Color(0.92, 0.86, 0.68, 1.0)
		"enhanced":
			return Color(0.34, 0.52, 1.0, 1.0)
		"chaos":
			return Color(1.0, 0.18, 0.58, 1.0)
		_:
			return fallback


func _style_option_popup_menu(popup: PopupMenu, accent: Color, bg: Color) -> void:
	if popup == null or not is_instance_valid(popup):
		return

	var panel_style:= StyleBoxFlat.new()
	panel_style.bg_color = Color(bg.r * 0.88, bg.g * 1.02, bg.b * 1.08, 0.98)
	panel_style.border_color = Color(accent.r, accent.g, accent.b, 0.78)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(10)
	panel_style.shadow_color = Color(accent.r, accent.g, accent.b, 0.24)
	panel_style.shadow_size = 18

	var hover_style:= StyleBoxFlat.new()
	hover_style.bg_color = Color(accent.r, accent.g, accent.b, 0.22)
	hover_style.set_corner_radius_all(7)

	popup.add_theme_stylebox_override("panel", panel_style)
	popup.add_theme_stylebox_override("hover", hover_style)
	popup.add_theme_color_override("font_color", Color(0.88, 1.0, 1.0, 1.0))
	popup.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.72, 1.0))
	popup.add_theme_color_override("font_selected_color", Color(1.0, 0.78, 0.28, 1.0))
func _find_location_picker_scrollbar(node: Node) -> VScrollBar:
	if node == null:
		return null

	for child in node.get_children():
		if child is VScrollBar:
			return child as VScrollBar

		var nested: VScrollBar = _find_location_picker_scrollbar(child)
		if nested != null:
			return nested

	return null


func _style_location_picker_scrollbar(
	picker: OptionButton,
	accent: Color
) -> void:
	if picker == null or not is_instance_valid(picker):
		return

	var popup: PopupMenu = picker.get_popup()
	if popup == null or not is_instance_valid(popup):
		return

	var scrollbar: VScrollBar = _find_location_picker_scrollbar(popup)
	if scrollbar == null:
		return

	var track:= StyleBoxFlat.new()
	track.bg_color = Color(0.025, 0.035, 0.055, 0.96)
	track.border_color = Color(accent.r, accent.g, accent.b, 0.28)
	track.set_border_width_all(1)
	track.set_corner_radius_all(8)

	var grabber:= StyleBoxFlat.new()
	grabber.bg_color = Color(
		accent.r * 0.72,
		accent.g * 0.72,
		accent.b * 0.72,
		0.94
	)
	grabber.border_color = Color(accent.r, accent.g, accent.b, 0.92)
	grabber.set_border_width_all(1)
	grabber.set_corner_radius_all(8)
	grabber.shadow_color = Color(accent.r, accent.g, accent.b, 0.28)
	grabber.shadow_size = 6

	var grabber_hover:= grabber.duplicate() as StyleBoxFlat
	grabber_hover.bg_color = Color(
		accent.r,
		accent.g,
		accent.b,
		1.0
	)
	grabber_hover.shadow_color = Color(accent.r, accent.g, accent.b, 0.48)
	grabber_hover.shadow_size = 10

	scrollbar.custom_minimum_size = Vector2(15, 0)
	scrollbar.add_theme_stylebox_override("scroll", track)
	scrollbar.add_theme_stylebox_override("grabber", grabber)
	scrollbar.add_theme_stylebox_override("grabber_highlight", grabber_hover)
	scrollbar.add_theme_stylebox_override("grabber_pressed", grabber_hover)
	scrollbar.visible = true

	scrollbar.set_meta("god_mode_location_scrollbar_styled", true)
	scrollbar.set_meta("god_mode_location_scrollbar_styled_at_ms", int(Time.get_ticks_msec()))


func _configure_location_picker_popup_scroll(
	picker: OptionButton,
	max_height: int = 520
) -> void:
	if picker == null or not is_instance_valid(picker):
		return

	var popup: PopupMenu = picker.get_popup()
	if popup == null or not is_instance_valid(popup):
		return

	var resolved_max_height: int = maxi(260, max_height)

	popup.max_size = Vector2i(620, resolved_max_height)
	popup.set_meta("god_mode_location_popup_scroll_enabled", true)
	popup.set_meta("god_mode_location_popup_max_height", resolved_max_height)

	if not bool(popup.get_meta("god_mode_location_popup_scroll_signal_bound", false)):
		popup.about_to_popup.connect(func () -> void:
			if picker == null or not is_instance_valid(picker):
				return

			var popup_accent: Color = _reality_mode_color(
				selected_reality_mode,
				Color(0.34, 0.78, 1.0, 1.0)
			)

			call_deferred(
				"_style_location_picker_scrollbar",
				picker,
				popup_accent
			)
		)

		popup.set_meta("god_mode_location_popup_scroll_signal_bound", true)

	var initial_scrollbar_accent: Color = _reality_mode_color(
		selected_reality_mode,
		Color(0.34, 0.78, 1.0, 1.0)
	)

	call_deferred(
		"_style_location_picker_scrollbar",
		picker,
		initial_scrollbar_accent
	)

func _refresh_location_picker_popup_scrollbars() -> void:
	_configure_location_picker_popup_scroll(country_picker, 540)
	_configure_location_picker_popup_scroll(city_picker, 480)

	if state_picker != null and state_picker.visible:
		_configure_location_picker_popup_scroll(state_picker, 460)

func _safe_viewer_dictionary(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(true)
	return {}


func _prewarm_progress_from_engine_state(state: Dictionary, lifecycle: String) -> float:
	var last_report: Dictionary = _safe_viewer_dictionary(state.get("last_report", {}))
	var report_progress: Variant = last_report.get("prewarm_progress", last_report.get("progress", null))
	if typeof(report_progress) == TYPE_FLOAT or typeof(report_progress) == TYPE_INT:
		return clamp(float(report_progress), 0.0, 1.0)

	var prewarm_contract: Dictionary = _safe_viewer_dictionary(state.get("prewarm_contract", {}))
	var contract_progress: Variant = prewarm_contract.get("prewarm_progress", prewarm_contract.get("progress", null))
	if typeof(contract_progress) == TYPE_FLOAT or typeof(contract_progress) == TYPE_INT:
		return clamp(float(contract_progress), 0.0, 1.0)

	match lifecycle:
		"idle", "panel_captured":
			return 0.0
		"prewarm_requested":
			var created_at_ms: int = int(prewarm_contract.get("created_at_ms", Time.get_ticks_msec()))
			var elapsed_ratio: float = clamp(float(Time.get_ticks_msec() - created_at_ms) / 1600.0, 0.0, 1.0)
			return clamp(0.18 + elapsed_ratio * 0.64, 0.18, 0.82)
		"prewarm_ready", "handoff_emitted", "surface_claimed", "entry_complete":
			return 1.0
		_:
			return 0.0


func _ensure_prewarm_button_layers() -> void:
	if prewarm_button == null or not is_instance_valid(prewarm_button):
		return

	prewarm_button.text = ""
	prewarm_button.clip_contents = true

	if prewarm_button_fill == null or not is_instance_valid(prewarm_button_fill):
		prewarm_button_fill = ColorRect.new()
		prewarm_button_fill.name = "GodModePrewarmButtonFill"
		prewarm_button_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		prewarm_button_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		prewarm_button_fill.anchor_right = 0.0
		prewarm_button_fill.z_as_relative = true
		prewarm_button_fill.z_index = 1
		prewarm_button.add_child(prewarm_button_fill)

	if prewarm_button_label == null or not is_instance_valid(prewarm_button_label):
		prewarm_button_label = Label.new()
		prewarm_button_label.name = "GodModePrewarmButtonLabel"
		prewarm_button_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		prewarm_button_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prewarm_button_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		prewarm_button_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		prewarm_button_label.z_as_relative = true
		prewarm_button_label.z_index = 2
		prewarm_button_label.add_theme_font_size_override("font_size", 16)
		prewarm_button.add_child(prewarm_button_label)


func _update_prewarm_button_visual(progress: float, lifecycle: String, _status_text: String, prewarm_is_ready: bool) -> void:
	if prewarm_button == null or not is_instance_valid(prewarm_button):
		return

	_ensure_prewarm_button_layers()

	var clean_progress: float = 1.0 if prewarm_is_ready else clamp(progress, 0.0, 0.96)
	prewarm_visual_progress = clean_progress

	if progress_bar != null and is_instance_valid(progress_bar):
		progress_bar.value = clean_progress

	var pending: bool = lifecycle == "prewarm_requested"
	var staging_door_latch: bool = lifecycle == "prewarm_ready" and not prewarm_is_ready

	prewarm_button.disabled = (pending and not prewarm_is_ready) or staging_door_latch
	prewarm_button.mouse_filter = Control.MOUSE_FILTER_STOP if not prewarm_button.disabled else Control.MOUSE_FILTER_IGNORE

	if prewarm_button_fill != null and is_instance_valid(prewarm_button_fill):
		prewarm_button_fill.visible = clean_progress > 0.001
		prewarm_button_fill.anchor_left = 0.0
		prewarm_button_fill.anchor_right = clean_progress
		prewarm_button_fill.offset_left = 0.0
		prewarm_button_fill.offset_top = 0.0
		prewarm_button_fill.offset_right = 0.0
		prewarm_button_fill.offset_bottom = 0.0

	if prewarm_button_label != null and is_instance_valid(prewarm_button_label):
		if prewarm_is_ready:
			prewarm_button_label.text = "I’m ready to play EraLife"
		elif staging_door_latch:
			prewarm_button_label.text = "Staging playable shell..."
		elif clean_progress > 0.001:
			prewarm_button_label.text = "%d%%" % int(round(clean_progress * 100.0))
		else:
			prewarm_button_label.text = "Pre warm world seed"

func _tick_prewarm_button_energy() -> void:
	if prewarm_button_fill == null or not is_instance_valid(prewarm_button_fill):
		return

	var palette: Dictionary = _palette()
	var accent: Color = Color(palette.get("accent", Color(0.0, 0.95, 1.0, 1.0)))
	var pulse: float = 0.5 + 0.5 * sin(visual_phase * 7.0)

	prewarm_button_fill.color = Color(
		accent.r,
		accent.g,
		accent.b,
		0.26 + pulse * 0.18
	)

	if prewarm_button_label != null and is_instance_valid(prewarm_button_label):
		prewarm_button_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.72, 1.0) if prewarm_visual_progress > 0.001 else Color(0.86, 1.0, 1.0, 1.0))
		prewarm_button_label.add_theme_color_override("font_shadow_color", Color(accent.r, accent.g, accent.b, 0.42 + pulse * 0.28))
		prewarm_button_label.add_theme_constant_override("shadow_offset_x", 0)
		prewarm_button_label.add_theme_constant_override("shadow_offset_y", 0)


func _tick_preview_label_visuals() -> void:
	if preview_label == null or not is_instance_valid(preview_label):
		return

	var palette: Dictionary = _palette()
	var accent: Color = Color(palette.get("accent", Color(0.0, 0.95, 1.0, 1.0)))
	var pulse: float = 0.5 + 0.5 * sin(visual_phase * 2.4)

	preview_label.add_theme_color_override("font_color", Color(0.84 + pulse * 0.1, 1.0, 1.0, 0.88 + pulse * 0.12))
	preview_label.add_theme_color_override("font_shadow_color", Color(accent.r, accent.g, accent.b, 0.32 + pulse * 0.46))
	preview_label.add_theme_constant_override("shadow_offset_x", 0)
	preview_label.add_theme_constant_override("shadow_offset_y", 0)

func _on_god_mode_scroll_gui_input(event: InputEvent) -> void:
	if _scroll_god_mode_viewer_from_event(event, "scroll_container_gui_input"):
		accept_event()
func _scroll_god_mode_viewer_from_event(event: InputEvent, reason: String = "god_mode_scroll") -> bool:
	if scroll == null or not is_instance_valid(scroll):
		return false

	var delta_pixels: float = 0.0

	if event is InputEventPanGesture:
		var pan:= event as InputEventPanGesture
		delta_pixels = pan.delta.y * GOD_MODE_VIEWER_TRACKPAD_MULTIPLIER * 58.0
	elif event is InputEventMouseButton:
		var mouse:= event as InputEventMouseButton
		if not mouse.pressed:
			return false

		match mouse.button_index:
			MOUSE_BUTTON_WHEEL_DOWN:
				delta_pixels = GOD_MODE_VIEWER_SCROLL_WHEEL_PIXELS
			MOUSE_BUTTON_WHEEL_UP:
				delta_pixels = - GOD_MODE_VIEWER_SCROLL_WHEEL_PIXELS
			_:
				return false
	else:
		return false

	if abs(delta_pixels) <= 0.001:
		return false

	var bar:= scroll.get_v_scroll_bar()
	var max_value: float = bar.max_value if bar != null and is_instance_valid(bar) else 999999.0
	var next_value: float = clamp(float(scroll.scroll_vertical) + delta_pixels, 0.0, max_value)

	if abs(next_value - float(scroll.scroll_vertical)) <= 0.001:
		return false

	scroll.scroll_vertical = int(next_value)
	last_input_scroll_ms = int(Time.get_ticks_msec())
	scrollbar_last_activity_ms = last_input_scroll_ms
	_show_scrollbar_for_activity(reason)
	return true


func _god_mode_pointer_inside_panel() -> bool:
	if panel != null and is_instance_valid(panel):
		return panel.get_global_rect().has_point(get_global_mouse_position())

	return get_global_rect().has_point(get_global_mouse_position())


func _god_mode_scroll_is_hot(now_ms: int = -1) -> bool:
	var check_ms: int = now_ms
	if check_ms < 0:
		check_ms = int(Time.get_ticks_msec())

	var scrollbar_hot: bool = check_ms - scrollbar_last_activity_ms < GOD_MODE_VIEWER_SCROLL_ACTIVITY_HOLD_MS
	var input_hot: bool = check_ms - last_input_scroll_ms < GOD_MODE_VIEWER_HOT_SCROLL_ANIMATION_PAUSE_MS

	return scrollbar_hot or input_hot


func _update_stat_energy_bar(slider: HSlider, _immediate: bool = false) -> void:
	if slider == null or not is_instance_valid(slider):
		return

	var shell:= slider.get_meta("god_mode_energy_shell", null) as Control
	var fill_clip:= slider.get_meta("god_mode_energy_fill_clip", null) as Control
	var thumb:= slider.get_meta("god_mode_energy_thumb", null) as PanelContainer
	var value_label:= slider.get_meta("god_mode_energy_value_label", null) as Label

	var ratio: float = 0.0
	if slider.max_value > slider.min_value:
		ratio = clamp(float(slider.value - slider.min_value) / float(slider.max_value - slider.min_value), 0.0, 1.0)

	if fill_clip != null and is_instance_valid(fill_clip):
		fill_clip.anchor_left = 0.0
		fill_clip.anchor_right = ratio
		fill_clip.offset_left = 0.0
		fill_clip.offset_right = 0.0

	if shell != null and is_instance_valid(shell) and thumb != null and is_instance_valid(thumb):
		var usable_width: float = max(1.0, shell.size.x)
		thumb.size = Vector2(10.0, max(18.0, shell.size.y - 18.0))
		thumb.position = Vector2(clamp(usable_width * ratio - 5.0, 0.0, max(0.0, usable_width - 10.0)), 9.0)

	if value_label != null and is_instance_valid(value_label):
		value_label.text = "%d" % int(round(slider.value))


func _tick_stat_energy_bar_motion() -> void:
	for row in _stat_slider_rows():
		var slider: HSlider = row.get("slider", null)
		if slider == null or not is_instance_valid(slider):
			continue

		_update_stat_energy_bar(slider, false)

		var shell:= slider.get_meta("god_mode_energy_shell", null) as Control
		var fill_clip:= slider.get_meta("god_mode_energy_fill_clip", null) as Control
		var flow_a:= slider.get_meta("god_mode_energy_flow_a", null) as ColorRect
		var flow_b:= slider.get_meta("god_mode_energy_flow_b", null) as ColorRect

		if shell == null or not is_instance_valid(shell):
			continue
		if fill_clip == null or not is_instance_valid(fill_clip):
			continue

		var fill_width: float = max(1.0, fill_clip.size.x)
		var fill_height: float = max(4.0, fill_clip.size.y)
		var streak_width: float = max(68.0, shell.size.x * 0.16)

		if flow_a != null and is_instance_valid(flow_a):
			var x_a: float = fposmod(visual_phase * 210.0, fill_width + streak_width) - streak_width
			flow_a.position = Vector2(x_a, 0.0)
			flow_a.size = Vector2(streak_width, fill_height)

		if flow_b != null and is_instance_valid(flow_b):
			var x_b: float = fposmod(visual_phase * 150.0 + streak_width * 1.8, fill_width + streak_width) - streak_width
			flow_b.position = Vector2(x_b, 0.0)
			flow_b.size = Vector2(streak_width * 0.74, fill_height)


func _build_infinity_stone_selector() -> void:
	var row:= _row("Infinity Stones")
	infinity_stone_buttons.clear()

	for count in [0, 1, 2]:
		var button:= Button.new()
		button.text = "None" if count == 0 else "%d stone" % count if count == 1 else "%d stones" % count
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 48)
		button.set_meta("god_mode_infinity_stone_count", count)
		button.pressed.connect(func () -> void:
			starting_infinity_stones = count
			_style_infinity_stone_buttons()
			_refresh_preview()
		)
		infinity_stone_buttons.append(button)
		row.add_child(button)

	_style_infinity_stone_buttons()


func _add_check_box(
	label_text: String,
	default_pressed: bool = false,
	player_visible: bool = true
) -> CheckBox:
	var check:= CheckBox.new()
	check.text = label_text
	check.button_pressed = (
		default_pressed
		if player_visible
		else false
	)
	check.visible = player_visible
	check.disabled = not player_visible
	check.set_meta(
		"god_mode_form_control",
		true
	)
	check.set_meta(
		"god_mode_player_visible",
		player_visible
	)

	if not player_visible:
		check.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)
		check.focus_mode = (
			Control.FOCUS_NONE
		)

	check.toggled.connect(
		func (_pressed: bool) -> void:
			_refresh_preview()
			preview_visual_dirty = true
	)

	root.add_child(
		check
	)

	return check
func _build_celestial_power_sandbox_launcher() -> void:
	celestial_power_sandbox_button = Button.new()
	celestial_power_sandbox_button.name = (
		"GodModeCelestialPowerSandboxButton"
	)
	celestial_power_sandbox_button.text = "   Configure Superpowers"
	celestial_power_sandbox_button.custom_minimum_size = Vector2(
		0.0,
		48.0
	)
	celestial_power_sandbox_button.focus_mode = Control.FOCUS_NONE
	celestial_power_sandbox_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	celestial_power_sandbox_button.visible = false
	celestial_power_sandbox_button.disabled = true
	celestial_power_sandbox_button.set_meta(
		"god_mode_form_control",
		true
	)
	celestial_power_sandbox_button.set_meta(
		"temporarily_hidden",
		true
	)
	celestial_power_sandbox_button.pressed.connect(
		func () -> void:
			_open_celestial_power_sandbox()
	)
	root.add_child(
		celestial_power_sandbox_button
	)

	var palette: Dictionary = _palette()
	var accent: Color = Color(
		palette.get(
			"accent",
			Color(
				0.72,
				1.0,
				1.0,
				1.0
			)
		)
	)
	_style_button(
		celestial_power_sandbox_button,
		Color(
			accent.r * 0.12,
			accent.g * 0.14,
			accent.b * 0.2,
			0.94
		),
		Color(
			1.0,
			0.86,
			0.36,
			0.86
		)
	)

	celestial_power_summary_label = Label.new()
	celestial_power_summary_label.name = (
		"GodModeCelestialPowerSandboxSummary"
	)
	celestial_power_summary_label.text = (
		"Optional: configure who receives power, where it comes from, "
		+ "and how it awakens."
	)
	celestial_power_summary_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	celestial_power_summary_label.add_theme_font_size_override(
		"font_size",
		12
	)
	celestial_power_summary_label.add_theme_color_override(
		"font_color",
		Color(
			0.86,
			0.91,
			1.0,
			0.72
		)
	)
	celestial_power_summary_label.visible = false
	celestial_power_summary_label.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	celestial_power_summary_label.set_meta(
		"temporarily_hidden",
		true
	)
	root.add_child(
		celestial_power_summary_label
	)



	_ensure_celestial_power_sandbox_panel()
func _ensure_celestial_power_sandbox_panel() -> void:
	if celestial_power_sandbox_panel != null and is_instance_valid(celestial_power_sandbox_panel):
		return

	celestial_power_sandbox_panel = PanelContainer.new()
	celestial_power_sandbox_panel.name = "GodModeCelestialPowerSandboxPanel"
	celestial_power_sandbox_panel.visible = false
	celestial_power_sandbox_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	celestial_power_sandbox_panel.add_theme_stylebox_override("panel", _celestial_power_sandbox_panel_style())
	root.add_child(celestial_power_sandbox_panel)

	var sandbox_margin:= MarginContainer.new()
	sandbox_margin.add_theme_constant_override("margin_left", 16)
	sandbox_margin.add_theme_constant_override("margin_right", 16)
	sandbox_margin.add_theme_constant_override("margin_top", 14)
	sandbox_margin.add_theme_constant_override("margin_bottom", 14)
	celestial_power_sandbox_panel.add_child(sandbox_margin)

	var box:= VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	sandbox_margin.add_child(box)

	var title:= Label.new()
	title.text = "Celestial Power Sandbox"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.42, 0.96))
	box.add_child(title)

	var subtitle:= Label.new()
	subtitle.text = "Viewer-only configuration. The simulation receives this as a power contract when the world seed is committed."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color(0.86, 0.91, 1.0, 0.72))
	box.add_child(subtitle)

	celestial_power_receiver_picker = _celestial_power_sandbox_picker(box, "Who Receives Power", [
		"Only Me",
		"My Household",
		"My Bloodline",
		"Whole Family",
		"Selected Group"
	])

	celestial_power_origin_picker = _celestial_power_sandbox_picker(box, "Power Origin", [
		"Born Hidden",
		"Cosmic Event",
		"Experiment Surgery",
		"Artifact Exposure",
		"Bloodline Awakening",
		"Government Experiment"
	])

	celestial_primary_power_picker = _celestial_power_sandbox_picker(box, "Primary Power", [
		"Super Strength",
		"Super Speed",
		"Spider Abilities",
		"Infant Chaos Polymorph",
		"Energy Projection",
		"Telepathy",
		"Probability Manipulation",
		"Mind Control",
		"Fire Starter"
	])

	celestial_power_rarity_picker = _celestial_power_sandbox_picker(box, "Rarity", [
		"Common",
		"Rare",
		"Epic",
		"Legendary",
		"Mythic"
	])

	celestial_power_public_identity_picker = _celestial_power_sandbox_picker(box, "Public Identity", [
		"Secret",
		"Rumored",
		"Registered Hero",
		"Wanted Villain",
		"Government Experiment"
	])

	celestial_power_awakening_picker = _celestial_power_sandbox_picker(box, "Awakening", [
		"Immediate",
		"Awoken At Birth",
		"Latent",
		"Trauma Triggered",
		"Age Gate"
	])

	celestial_power_inheritance_picker = _celestial_power_sandbox_picker(box, "Inheritance Mode", [
		"Dominant",
		"Recessive",
		"Bloodline",
		"Firstborn Only",
		"Non-Inheritable"
	])

	var close_row:= HBoxContainer.new()
	close_row.add_theme_constant_override("separation", 8)
	box.add_child(close_row)

	var close_spacer:= Control.new()
	close_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_row.add_child(close_spacer)

	var close_button:= Button.new()
	close_button.text = "Close Sandbox"
	close_button.custom_minimum_size = Vector2(150.0, 34.0)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(func () -> void:
		if celestial_power_sandbox_panel != null and is_instance_valid(celestial_power_sandbox_panel):
			celestial_power_sandbox_panel.visible = false
	)
	close_row.add_child(close_button)

	_style_button(close_button, Color(0.08, 0.08, 0.12, 0.92), Color(1.0, 0.86, 0.36, 0.56))

func _celestial_power_sandbox_picker(parent: VBoxContainer, label_text: String, items: Array) -> OptionButton:
	var row:= HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	var label:= Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(170.0, 0.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0, 0.82))
	row.add_child(label)

	var picker:= OptionButton.new()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.custom_minimum_size = Vector2(0.0, 34.0)
	picker.set_meta("god_mode_form_control", true)

	for item in items:
		picker.add_item(str(item))

	picker.item_selected.connect(func (_index: int) -> void:
		_on_celestial_power_sandbox_changed()
	)

	row.add_child(picker)
	return picker


func _open_celestial_power_sandbox() -> void:
	celestial_power_sandbox_configured = true
	_ensure_celestial_power_sandbox_panel()

	if celestial_power_sandbox_panel != null and is_instance_valid(celestial_power_sandbox_panel):
		celestial_power_sandbox_panel.visible = true

	_refresh_celestial_power_sandbox_summary()
	_refresh_preview()
	preview_visual_dirty = true


func _on_celestial_power_sandbox_changed() -> void:
	celestial_power_sandbox_configured = true
	_refresh_celestial_power_sandbox_summary()
	_refresh_preview()
	preview_visual_dirty = true


func _refresh_celestial_power_sandbox_summary() -> void:
	if celestial_power_summary_label == null or not is_instance_valid(celestial_power_summary_label):
		return

	var config: Dictionary = _celestial_power_sandbox_state()
	if config.is_empty():
		celestial_power_summary_label.text = "Optional: configure who receives power, where it comes from, and how it awakens."
		return

	celestial_power_summary_label.text = "%s • %s • %s • %s" % [
		str(config.get("primary_power_label", "Superpower")),
		str(config.get("rarity_label", "Rare")),
		str(config.get("origin_label", "Born Hidden")),
		str(config.get("scope_label", "Only Me"))
	]


func _celestial_power_sandbox_state() -> Dictionary:
	if not celestial_power_sandbox_configured:
		return {}

	var scope_label: String = _selected_text(celestial_power_receiver_picker)
	var origin_label: String = _selected_text(celestial_power_origin_picker)
	var power_label: String = _selected_text(celestial_primary_power_picker)
	var rarity_label: String = _selected_text(celestial_power_rarity_picker)
	var public_identity_label: String = _selected_text(celestial_power_public_identity_picker)
	var awakening_label: String = _selected_text(celestial_power_awakening_picker)
	var inheritance_label: String = _selected_text(celestial_power_inheritance_picker)

	var awakening_id: String = _celestial_power_id_from_label(awakening_label)
	var inheritance_id: String = _celestial_power_id_from_label(inheritance_label)

	return {
		"schema": "eralife.superpower_sandbox_config",
		"version": 1,
		"enabled": true,
		"scope": _celestial_power_id_from_label(scope_label),
		"scope_label": scope_label,
		"target_group": "",
		"origin": _celestial_power_id_from_label(origin_label),
		"origin_label": origin_label,
		"primary_power": _celestial_power_id_from_label(power_label),
		"primary_power_label": power_label,
		"rarity": _celestial_power_id_from_label(rarity_label),
		"rarity_label": rarity_label,
		"public_identity": _celestial_power_id_from_label(public_identity_label),
		"public_identity_label": public_identity_label,
		"awakening": {
			"mode": awakening_id,
			"mode_label": awakening_label,
			"minimum_age": 13 if awakening_id == "age_gate" else 0,
			"public_visibility": _celestial_power_id_from_label(public_identity_label)
		},
		"inheritance": {
			"mode": inheritance_id,
			"mode_label": inheritance_label,
			"skips_generations": inheritance_id == "recessive",
			"awakens_under_trauma": awakening_id == "trauma_triggered",
			"awakens_at_age_13": awakening_id == "age_gate",
			"only_firstborn": inheritance_id == "firstborn_only",
			"only_avatars_benders": false,
			"corrupts_bloodline_over_time": false,
			"generation_strength_loss": 0.18,
			"mutation_chance": 0.07
		},
		"presentation": {
			"panel_theme": "celestial_power_sandbox",
			"viewer_surface": "GodModeViewer",
			"apply_label": "Apply Power",
			"ui_is_renderer_only": true
		}
	}


func _celestial_power_id_from_label(label_text: String) -> String:
	var clean: String = str(label_text).strip_edges().to_lower()
	clean = clean.replace("⚡", "")
	clean = clean.replace("️", "")
	clean = clean.strip_edges()
	clean = clean.replace(" ", "_")
	clean = clean.replace("-", "_")

	match clean:
		"only_me":
			return "only_me"
		"my_household":
			return "my_household"
		"my_bloodline":
			return "my_bloodline"
		"whole_family":
			return "whole_family"
		"selected_group":
			return "selected_group"
		"born_hidden":
			return "born_hidden"
		"cosmic_event":
			return "cosmic_event"
		"experiment_surgery":
			return "experiment_surgery"
		"artifact_exposure":
			return "artifact_exposure"
		"bloodline_awakening":
			return "bloodline_awakening"
		"government_experiment":
			return "government_experiment"
		"super_strength":
			return "super_strength"
		"super_speed":
			return "super_speed"
		"spider_abilities":
			return "spider_abilities"
		"infant_chaos_polymorph":
			return "infant_chaos_polymorph"
		"energy_projection":
			return "energy_projection"
		"telepathy":
			return "telepathy"
		"probability_manipulation":
			return "probability_manipulation"
		"mind_control":
			return "mind_control"
		"fire_starter":
			return "fire_starter"
		"registered_hero":
			return "registered_hero"
		"wanted_villain":
			return "wanted_villain"
		"awoken_at_birth":
			return "awoken_at_birth"
		"trauma_triggered":
			return "trauma_triggered"
		"age_gate":
			return "age_gate"
		"firstborn_only":
			return "firstborn_only"
		"non_inheritable":
			return "non_inheritable"
		_:
			return clean


func _celestial_power_label_from_id(raw_id: Variant) -> String:
	var clean: String = str(raw_id).strip_edges().to_lower()

	match clean:
		"only_me":
			return "Only Me"
		"my_household":
			return "My Household"
		"my_bloodline":
			return "My Bloodline"
		"whole_family":
			return "Whole Family"
		"selected_group":
			return "Selected Group"
		"born_hidden":
			return "Born Hidden"
		"cosmic_event":
			return "Cosmic Event"
		"experiment_surgery":
			return "Experiment Surgery"
		"artifact_exposure":
			return "Artifact Exposure"
		"bloodline_awakening":
			return "Bloodline Awakening"
		"government_experiment":
			return "Government Experiment"
		"super_strength":
			return "Super Strength"
		"super_speed":
			return "Super Speed"
		"spider_abilities":
			return "Spider Abilities"
		"infant_chaos_polymorph":
			return "Infant Chaos Polymorph"
		"energy_projection":
			return "Energy Projection"
		"telepathy":
			return "Telepathy"
		"probability_manipulation":
			return "Probability Manipulation"
		"mind_control":
			return "Mind Control"
		"fire_starter":
			return "Fire Starter"
		"common":
			return "Common"
		"rare":
			return "Rare"
		"epic":
			return "Epic"
		"legendary":
			return "Legendary"
		"mythic":
			return "Mythic"
		"secret":
			return "Secret"
		"rumored":
			return "Rumored"
		"registered_hero":
			return "Registered Hero"
		"wanted_villain":
			return "Wanted Villain"
		"immediate":
			return "Immediate"
		"awoken_at_birth":
			return "Awoken At Birth"
		"latent":
			return "Latent"
		"trauma_triggered":
			return "Trauma Triggered"
		"age_gate":
			return "Age Gate"
		"dominant":
			return "Dominant"
		"recessive":
			return "Recessive"
		"bloodline":
			return "Bloodline"
		"firstborn_only":
			return "Firstborn Only"
		"non_inheritable":
			return "Non-Inheritable"
		_:
			return str(raw_id).capitalize()


func _apply_celestial_power_sandbox_settings(raw_settings: Variant) -> void:
	if typeof(raw_settings) != TYPE_DICTIONARY:
		return

	var settings: Dictionary = (raw_settings as Dictionary).duplicate(true)
	if settings.is_empty():
		return

	celestial_power_sandbox_configured = bool(settings.get("enabled", true))
	_ensure_celestial_power_sandbox_panel()

	_select_picker_text(celestial_power_receiver_picker, _celestial_power_label_from_id(settings.get("scope", "only_me")))
	_select_picker_text(celestial_power_origin_picker, _celestial_power_label_from_id(settings.get("origin", "born_hidden")))
	_select_picker_text(celestial_primary_power_picker, _celestial_power_label_from_id(settings.get("primary_power", "super_strength")))
	_select_picker_text(celestial_power_rarity_picker, _celestial_power_label_from_id(settings.get("rarity", "rare")))
	_select_picker_text(celestial_power_public_identity_picker, _celestial_power_label_from_id(settings.get("public_identity", "secret")))

	var awakening: Dictionary = settings.get("awakening", {}) if typeof(settings.get("awakening", {})) == TYPE_DICTIONARY else {}
	var inheritance: Dictionary = settings.get("inheritance", {}) if typeof(settings.get("inheritance", {})) == TYPE_DICTIONARY else {}

	_select_picker_text(celestial_power_awakening_picker, _celestial_power_label_from_id(awakening.get("mode", "latent")))
	_select_picker_text(celestial_power_inheritance_picker, _celestial_power_label_from_id(inheritance.get("mode", "dominant")))

	_refresh_celestial_power_sandbox_summary()


func _celestial_power_sandbox_panel_style() -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.022, 0.018, 0.034, 0.94)
	style.border_color = Color(1.0, 0.86, 0.36, 0.54)
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(1.0, 0.76, 0.22, 0.18)
	style.shadow_size = 18
	return style
func _style_infinity_stone_buttons() -> void:
	var palette: Dictionary = _palette()
	var accent: Color = Color(palette.get("accent", Color(0.0, 0.95, 1.0, 1.0)))
	var gold:= Color(1.0, 0.76, 0.24, 1.0)

	for raw_button in infinity_stone_buttons:
		var button:= raw_button as Button
		if button == null or not is_instance_valid(button):
			continue

		var count: int = int(button.get_meta("god_mode_infinity_stone_count", 0))
		var selected: bool = count == starting_infinity_stones

		var style:= StyleBoxFlat.new()
		style.bg_color = Color(0.02, 0.15, 0.17, 0.74)
		style.border_color = gold if selected else Color(accent.r, accent.g, accent.b, 0.46)
		style.set_border_width_all(2 if selected else 1)
		style.set_corner_radius_all(10)
		style.shadow_color = Color(gold.r, gold.g, gold.b, 0.46) if selected else Color(accent.r, accent.g, accent.b, 0.18)
		style.shadow_size = 18 if selected else 8

		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		button.add_theme_stylebox_override("pressed", style)
		button.add_theme_color_override("font_color", Color(1.0, 0.92, 0.66, 1.0) if selected else Color(0.84, 1.0, 1.0, 0.9))
func _retune_birth_day_range() -> void:
	# Keep the Birth Day spinbox honest about the selected month. February also
	# depends on the year, so leap years get 29.
	if birth_day_spin == null or not is_instance_valid(birth_day_spin):
		return

	var month_index: int = 0

	if birth_month_picker != null and is_instance_valid(birth_month_picker):
		month_index = int(birth_month_picker.selected)

	var month_number: int = clampi(month_index + 1, 1, 12)
	# _selected_birth_year_value() handles the year picker and the custom text entry;
	# birth_year_spin is declared but never assigned, so reading it directly would
	# always yield 0 and February would never allow the 29th in a leap year.
	var year_number: int = _selected_birth_year_value()

	var max_days: int = EraUtils.days_in_month(
		month_number,
		year_number
	)

	birth_day_spin.max_value = max_days

	if int(birth_day_spin.value) > max_days:
		birth_day_spin.value = max_days


func _selected_text(picker: OptionButton) -> String:
	if picker == null or not is_instance_valid(picker) or picker.item_count <= 0:
		return ""
	var index: int = picker.selected
	if index < 0:
		index = 0
	return picker.get_item_text(index)


func _select_picker_text(picker: OptionButton, text: String) -> void:
	if picker == null or not is_instance_valid(picker):
		return

	var clean: String = text.strip_edges().to_lower()
	if clean == "":
		return

	for i in range(picker.item_count):
		if picker.get_item_text(i).strip_edges().to_lower() == clean:
			picker.select(i)
			return