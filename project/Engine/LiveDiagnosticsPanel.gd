extends CanvasLayer
class_name LiveDiagnosticsPanel
signal view_fix_requested
signal apply_patch_requested
var root_card: PanelContainer = null
var header_bar: HBoxContainer = null
var title_label: Label = null
var minimize_button: Button = null
var body_box: VBoxContainer = null
var runtime_label: Label = null
var patch_label: Label = null
var patch_actions_row: HBoxContainer = null
var view_fix_button: Button = null
var apply_patch_button: Button = null
var fix_preview_label: Label = null
var minimized: bool = false
var dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	layer = 128
	_build_ui()

func _build_ui() -> void:
	if root_card != null:
		return

	root_card = PanelContainer.new()
	root_card.custom_minimum_size = Vector2(308, 0)
	root_card.position = Vector2(14, 14)
	add_child(root_card)

	var panel:= StyleBoxFlat.new()
	panel.bg_color = Color(0.04, 0.05, 0.08, 0.94)
	panel.border_width_left = 1
	panel.border_width_top = 1
	panel.border_width_right = 1
	panel.border_width_bottom = 1
	panel.border_color = Color(0.82, 0.88, 1.0, 0.3)
	panel.corner_radius_top_left = 12
	panel.corner_radius_top_right = 12
	panel.corner_radius_bottom_left = 12
	panel.corner_radius_bottom_right = 12
	panel.content_margin_left = 8
	panel.content_margin_top = 8
	panel.content_margin_right = 8
	panel.content_margin_bottom = 8
	panel.shadow_color = Color(0.0, 0.0, 0.0, 0.32)
	panel.shadow_size = 14
	panel.shadow_offset = Vector2(0, 4)
	root_card.add_theme_stylebox_override("panel", panel)

	var outer:= VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	root_card.add_child(outer)

	header_bar = HBoxContainer.new()
	header_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	header_bar.gui_input.connect(_on_header_gui_input)
	outer.add_child(header_bar)

	title_label = Label.new()
	title_label.text = "LIVE STABILITY • BOOT"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 12)
	header_bar.add_child(title_label)

	minimize_button = Button.new()
	minimize_button.text = "—"
	minimize_button.custom_minimum_size = Vector2(24, 20)
	minimize_button.add_theme_font_size_override("font_size", 13)
	minimize_button.pressed.connect(_on_minimize_pressed)
	header_bar.add_child(minimize_button)

	body_box = VBoxContainer.new()
	body_box.add_theme_constant_override("separation", 6)
	outer.add_child(body_box)

	runtime_label = Label.new()
	runtime_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	runtime_label.add_theme_font_size_override("font_size", 11)
	runtime_label.text = "Waiting for runtime state..."
	body_box.add_child(runtime_label)

	patch_label = Label.new()
	patch_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	patch_label.add_theme_font_size_override("font_size", 11)
	patch_label.text = "No patch cards."
	body_box.add_child(patch_label)

	patch_actions_row = HBoxContainer.new()
	patch_actions_row.add_theme_constant_override("separation", 6)
	patch_actions_row.visible = false
	body_box.add_child(patch_actions_row)

	view_fix_button = Button.new()
	view_fix_button.text = "View Fix"
	view_fix_button.custom_minimum_size = Vector2(0, 24)
	view_fix_button.add_theme_font_size_override("font_size", 11)
	view_fix_button.visible = false
	view_fix_button.pressed.connect(_on_view_fix_pressed)
	patch_actions_row.add_child(view_fix_button)

	apply_patch_button = Button.new()
	apply_patch_button.text = "Apply Patch"
	apply_patch_button.custom_minimum_size = Vector2(0, 24)
	apply_patch_button.add_theme_font_size_override("font_size", 11)
	apply_patch_button.visible = false
	apply_patch_button.pressed.connect(_on_apply_patch_pressed)
	patch_actions_row.add_child(apply_patch_button)

	fix_preview_label = Label.new()
	fix_preview_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	fix_preview_label.add_theme_font_size_override("font_size", 11)
	fix_preview_label.visible = false
	fix_preview_label.text = ""
	body_box.add_child(fix_preview_label)

func set_snapshot(snapshot: Dictionary, patch_cards: Array = []) -> void:
	if root_card == null:
		_build_ui()
	var state_label: String = str(snapshot.get("state_label", "IDLE"))
	var current_panel: String = str(snapshot.get("current_panel", ""))
	var current_phase: String = str(snapshot.get("current_phase", ""))
	var current_lane: String = str(snapshot.get("current_lane", ""))
	var session_stage: String = str(snapshot.get("session_stage", ""))
	var frame_ms: float = float(snapshot.get("frame_ms", 0.0))
	var stall_score: float = float(snapshot.get("stall_score", 0.0))
	var popup_stack_raw: Variant = snapshot.get("popup_stack", [])
	var popup_stack: Array = popup_stack_raw if typeof(popup_stack_raw) == TYPE_ARRAY else []
	var popup_list: String = "none" if popup_stack.is_empty() else ", ".join(popup_stack)
	var transition_active: bool = bool(snapshot.get("transition_active", false))
	var loading_active: bool = bool(snapshot.get("loading_active", false))
	var budget_raw: Variant = snapshot.get("budget_consumption", {})
	var budget: Dictionary = budget_raw if typeof(budget_raw) == TYPE_DICTIONARY else {}
	var phase_steps_consumed: int = int(budget.get("phase_steps_consumed", 0))
	var phase_steps_total: int = int(budget.get("phase_steps_total", 0))
	var year_pipeline_stage: int = int(snapshot.get("year_pipeline_stage", 0))
	var deferred_raw: Variant = snapshot.get("deferred_jobs", [])
	var deferred_jobs: Array = deferred_raw if typeof(deferred_raw) == TYPE_ARRAY else []
	var latest_auto_patch_raw: Variant = snapshot.get("latest_auto_patch", {})
	var latest_auto_patch: Dictionary = latest_auto_patch_raw if typeof(latest_auto_patch_raw) == TYPE_DICTIONARY else {}
	var preview_raw: Variant = snapshot.get("auto_patch_preview", {})
	var preview: Dictionary = preview_raw if typeof(preview_raw) == TYPE_DICTIONARY else {}
	var preview_available: bool = not preview.is_empty()
	title_label.text = "LIVE STABILITY • %s" % state_label
	runtime_label.text = (
		"Panel: %s\n"
		+ "Phase: %s • Lane: %s\n"
		+ "Stage: %s • Frame: %.1fms\n"
		+ "Loading: %s • Stall: %.1f\n"
		+ "Transition Active: %s\n"
		+ "Popups (%d): %s\n"
		+ "Budget: %d / %d\n"
		+ "Pipeline Stage: %d\n"
		+ "Deferred Jobs: %d"
	) % [
		current_panel if current_panel != "" else "(none)",
		current_phase if current_phase != "" else "preflight",
		current_lane if current_lane != "" else "boot",
		session_stage if session_stage != "" else "boot",
		frame_ms,
		str(loading_active),
		stall_score,
		str(transition_active),
		popup_stack.size(),
		popup_list,
		phase_steps_consumed,
		phase_steps_total,
		year_pipeline_stage,
		deferred_jobs.size()
	]
	var patch_text: String = "No patch cards."
	if not patch_cards.is_empty() and typeof(patch_cards [patch_cards.size() - 1]) == TYPE_DICTIONARY:
		var card: Dictionary = patch_cards [patch_cards.size() - 1]
		patch_text = (
			"Last Patch Card\n"
			+ "Source: %s\n"
			+ "Invariant: %s\n"
			+ "Mitigation: %s\n"
			+ "Confidence: %.2f"
		) % [
			str(card.get("likely_source_function", "unknown")),
			str(card.get("probable_invariant", "unknown")),
			str(card.get("temporary_mitigation_applied", "monitor_only")),
			float(card.get("confidence", 0.0))
		]
	if not latest_auto_patch.is_empty():
		patch_text += (
			"\n\nAuto Patch\n"
			+ "Target: %s • %s\n"
			+ "Patch Key: %s\n"
			+ "Confidence: %.2f"
		) % [
			str(latest_auto_patch.get("target_engine", "unknown")),
			str(latest_auto_patch.get("target_function", "unknown")),
			str(latest_auto_patch.get("patch_key", "unknown")),
			float(latest_auto_patch.get("confidence", 0.0))
		]
	if preview_available:
		patch_text += "\nPreview: Exact before/after ready"
	patch_label.text = patch_text
	if patch_actions_row != null:
		patch_actions_row.visible = preview_available
	if view_fix_button != null:
		view_fix_button.visible = preview_available
		view_fix_button.disabled = not preview_available
		view_fix_button.text = str(preview.get("view_button_text", "View Fix"))
	if apply_patch_button != null:
		apply_patch_button.visible = preview_available
		apply_patch_button.disabled = not preview_available or bool(preview.get("applied", false))
		apply_patch_button.text = str(preview.get("apply_button_text", "Apply Patch"))
	if fix_preview_label != null:
		var preview_text: String = ""
		if preview_available and bool(preview.get("expanded", false)):
			preview_text = (
				"%s\n"
				+ "Summary: %s\n"
				+ "Target: %s • %s\n"
				+ "Applied: %s\n\n"
				+ "BEFORE\n"
				+ "%s\n\n"
				+ "AFTER\n"
				+ "%s"
			) % [
				str(preview.get("title", "Proposed Fix")),
				str(preview.get("summary", "")),
				str(preview.get("target_engine", "unknown")),
				str(preview.get("target_function", "unknown")),
				str(bool(preview.get("applied", false))),
				str(preview.get("before_code", "")),
				str(preview.get("after_code", ""))
			]
		fix_preview_label.visible = preview_text != ""
		fix_preview_label.text = preview_text
func _on_view_fix_pressed() -> void:
	emit_signal("view_fix_requested")

func _on_apply_patch_pressed() -> void:
	emit_signal("apply_patch_requested")

func _on_minimize_pressed() -> void:
	minimized = not minimized
	if body_box != null:
		body_box.visible = not minimized
	if minimize_button != null:
		minimize_button.text = "+" if minimized else "—"

func _on_header_gui_input(event) -> void:
	if root_card == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		if dragging:
			drag_offset = root_card.position - event.global_position
	elif event is InputEventMouseMotion and dragging:
		root_card.position = event.global_position + drag_offset