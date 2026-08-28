extends Control
class_name ScenarioPanel
signal option_pressed(action_label: String)
var dim: ColorRect
var card: PanelContainer
var title_label: Label
var body_scroll: ScrollContainer
var body_label: RichTextLabel
var combat_box: VBoxContainer
var combat_status_label: Label
var combat_player_label: Label
var combat_player_bar: ProgressBar
var combat_enemy_label: Label
var combat_enemy_bar: ProgressBar
var buttons_scroll: ScrollContainer
var buttons_box: VBoxContainer
var footer_label: Label
var spectator_frame_timer: Timer
var spectator_frames: Array = []
var spectator_frame_index: int = 0
var spectator_frame_seconds: float = 1.15
var spectator_final_interactive: bool = false
var idle_escalation_timer: Timer
var idle_escalation_frames: Array = []
var idle_escalation_index: int = 0
var idle_escalation_seconds: float = 4.6
var spectator_auto_emit_timer: Timer
var spectator_auto_emit_label: String = ""
var spectator_auto_emit_armed: bool = false
func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	# FIX: the panel lays out correctly the first time it is shown, then fails on every
	# later visit. On the first present the UI is built fresh and measured as it is
	# constructed; on re-entry _ensure_ui() returns early and the panel is merely made
	# visible again, so every container reuses the cached measurements from the
	# previous scenario. Re-arming the layout pass on each show covers every path that
	# reveals this panel, not just present().
	if not visibility_changed.is_connected(_on_scenario_panel_visibility_changed):
		visibility_changed.connect(_on_scenario_panel_visibility_changed)
	# FIX: this panel was top_level, which makes a Control ignore its parent's
	# transform -- so PRESET_FULL_RECT anchors had nothing to resolve against, the
	# size had to be assigned by hand, and the container tree never received the
	# resize notifications that make Godot lay it out. That is why the card kept its
	# stale minimum and position until a real viewport resize (the editor's aspect
	# ratio button, then fullscreen) forced one. As a normal anchored child the panel
	# tracks its parent and gets those notifications for free.
	top_level = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	focus_mode = Control.FOCUS_ALL
	z_index = 144
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# ROOT CAUSE: _ensure_ui() used to run here. At _ready the panel measures 0x0, so
	# the whole tree -- CenterContainer, card, margin, VBox, scrolls, label -- was
	# constructed against a zero-sized parent. A CenterContainer positions its child
	# from its own size, so everything landed at the origin with minimum sizes, and
	# those measurements were cached. Godot only re-sorts containers on a resize
	# notification, which is exactly why nothing short of a real window resize ever
	# fixed it. The UI is now built in present(), once the panel has a real size.

func _adopt_parent_size() -> void:
	# The panel is anchored full-rect, but anchors only resolve on a layout pass. When
	# present() runs on the same frame the panel was created, that pass has not
	# happened yet and size is still 0x0. Take the size directly so the UI is built
	# against real dimensions.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var target_size: Vector2 = Vector2.ZERO
	var parent_node: Node = get_parent()

	if parent_node is Control:
		target_size = (parent_node as Control).size

	if target_size.x <= 1.0 or target_size.y <= 1.0:
		if is_inside_tree():
			target_size = get_viewport_rect().size

	if target_size.x > 1.0 and target_size.y > 1.0:
		if not size.is_equal_approx(target_size):
			size = target_size


func _ensure_ui() -> void:
	if dim != null:
		return

	dim = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.58)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center:= CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(center)

	card = PanelContainer.new()
	card.custom_minimum_size = Vector2(820, 0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.add_theme_stylebox_override("panel", _build_panel_style())
	center.add_child(card)

	var margin:= MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_STOP
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	card.add_child(margin)

	var vbox:= VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_STOP
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	title_label = Label.new()
	title_label.text = "SCENARIO"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.mouse_filter = Control.MOUSE_FILTER_STOP
	vbox.add_child(title_label)

	body_scroll = ScrollContainer.new()
	body_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# FIX: without a vertical expand flag this scroll never takes the space it is
	# given, and because the RichTextLabel inside uses fit_content it grows to the
	# full height of the text instead. The card then grows with it -- measured at
	# 1742px inside a 900px window -- and the CenterContainer centres it mostly
	# off-screen, which is why the panel looked blank until a manual toggle forced a
	# re-clamp.
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# FIX: a ScrollContainer sizes its child to the child's MINIMUM width, not its own,
	# while horizontal scrolling is enabled -- so size_flags_horizontal on the label
	# did nothing and the RichTextLabel came out 1px wide. Its 422 characters then
	# wrapped into a single-character column 9683px tall, which inflated the card to
	# 2457px, and the CenterContainer centred that at y=-779: almost entirely above
	# the top of the screen. Disabling horizontal scroll forces the child to take the
	# container's width, so the text wraps at 782px as intended.
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_scroll.custom_minimum_size = Vector2(0, 136)
	body_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	vbox.add_child(body_scroll)

	body_label = RichTextLabel.new()
	body_label.fit_content = true
	body_label.scroll_active = false
	body_label.bbcode_enabled = false
	body_label.custom_minimum_size = Vector2(0, 120)
	body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_label.mouse_filter = Control.MOUSE_FILTER_STOP
	body_scroll.add_child(body_label)

	combat_box = VBoxContainer.new()
	combat_box.visible = false
	combat_box.mouse_filter = Control.MOUSE_FILTER_STOP
	combat_box.add_theme_constant_override("separation", 8)
	vbox.add_child(combat_box)

	combat_status_label = Label.new()
	combat_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combat_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	combat_status_label.mouse_filter = Control.MOUSE_FILTER_STOP
	combat_box.add_child(combat_status_label)

	combat_player_label = Label.new()
	combat_player_label.mouse_filter = Control.MOUSE_FILTER_STOP
	combat_box.add_child(combat_player_label)

	combat_player_bar = ProgressBar.new()
	combat_player_bar.min_value = 0
	combat_player_bar.max_value = 100
	combat_player_bar.show_percentage = true
	combat_player_bar.custom_minimum_size = Vector2(0, 28)
	combat_player_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	combat_box.add_child(combat_player_bar)

	combat_enemy_label = Label.new()
	combat_enemy_label.mouse_filter = Control.MOUSE_FILTER_STOP
	combat_box.add_child(combat_enemy_label)

	combat_enemy_bar = ProgressBar.new()
	combat_enemy_bar.min_value = 0
	combat_enemy_bar.max_value = 100
	combat_enemy_bar.show_percentage = true
	combat_enemy_bar.custom_minimum_size = Vector2(0, 28)
	combat_enemy_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	combat_box.add_child(combat_enemy_bar)

	buttons_scroll = ScrollContainer.new()
	buttons_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Same defect as body_scroll: without disabling horizontal scroll the option
	# buttons are sized to their own minimum width rather than the panel's, so they
	# render as a narrow column instead of full-width rows.
	buttons_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	buttons_scroll.custom_minimum_size = Vector2(0, 212)
	buttons_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	vbox.add_child(buttons_scroll)

	buttons_box = VBoxContainer.new()
	buttons_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons_box.mouse_filter = Control.MOUSE_FILTER_STOP
	buttons_box.add_theme_constant_override("separation", 8)
	buttons_scroll.add_child(buttons_box)

	footer_label = Label.new()
	footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer_label.modulate = Color(1.0, 1.0, 1.0, 0.76)
	footer_label.mouse_filter = Control.MOUSE_FILTER_STOP
	vbox.add_child(footer_label)
	spectator_frame_timer = Timer.new()
	spectator_frame_timer.one_shot = true
	spectator_frame_timer.wait_time = spectator_frame_seconds
	spectator_frame_timer.timeout.connect(_advance_spectator_frame)
	add_child(spectator_frame_timer)

	idle_escalation_timer = Timer.new()
	idle_escalation_timer.one_shot = true
	idle_escalation_timer.wait_time = idle_escalation_seconds
	idle_escalation_timer.timeout.connect(_advance_idle_escalation_frame)
	add_child(idle_escalation_timer)

	spectator_auto_emit_timer = Timer.new()
	spectator_auto_emit_timer.one_shot = true
	spectator_auto_emit_timer.wait_time = 6.5
	spectator_auto_emit_timer.timeout.connect(_on_spectator_auto_emit_timeout)
	add_child(spectator_auto_emit_timer)
func present(result: Dictionary) -> void:
	# Give the panel a real size BEFORE the container tree is built. Building at 0x0
	# is what caused every container to cache a zero-based layout that only a window
	# resize could clear.
	_adopt_parent_size()
	_ensure_ui()
	_adopt_parent_size()
	visible = true
	show()
	mouse_filter = Control.MOUSE_FILTER_STOP
	# FIX: this panel was top_level, which makes a Control ignore its parent's
	# transform -- so PRESET_FULL_RECT anchors had nothing to resolve against, the
	# size had to be assigned by hand, and the container tree never received the
	# resize notifications that make Godot lay it out. That is why the card kept its
	# stale minimum and position until a real viewport resize (the editor's aspect
	# ratio button, then fullscreen) forced one. As a normal anchored child the panel
	# tracks its parent and gets those notifications for free.
	top_level = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	focus_mode = Control.FOCUS_ALL
	z_as_relative = false
	z_index = max(int(z_index), 144)
	call_deferred("grab_focus")

	if dim != null:
		dim.visible = true
		dim.mouse_filter = Control.MOUSE_FILTER_STOP

	if card != null:
		card.visible = true
		card.mouse_filter = Control.MOUSE_FILTER_STOP

	var frames_raw: Variant = result.get("spectator_frames", [])
	if typeof(frames_raw) == TYPE_ARRAY and not (frames_raw as Array).is_empty():
		spectator_frames = (frames_raw as Array).duplicate(true)
		spectator_frame_index = 0
		spectator_final_interactive = bool(result.get("spectator_final_interactive", false))
		spectator_frame_seconds = clamp(float(result.get("spectator_frame_seconds", 1.15)), 0.12, 3.0)
		_present_spectator_frame()
		return

	_stop_spectator_frames()

	var combat_ui_raw: Variant = result.get("combat_ui", {})
	var combat_ui: Dictionary = combat_ui_raw if typeof(combat_ui_raw) == TYPE_DICTIONARY else {}
	var theme_name: String = _resolve_theme_name(result, combat_ui)
	_apply_theme(theme_name)

	title_label.text = str(result.get("panel_title", result.get("popup_title", "SCENARIO")))

	body_label.clear()
	var body_text: String = str(result.get("text", result.get("popup_text", ""))).strip_edges()
	if body_text == "":
		body_text = "The scene resolved, but no narration was provided."
	# FIX: this used append_text(), which is the BBCode path, while bbcode_enabled is
	# false on this label. Assigning .text directly is the correct call for plain text
	# and, unlike append_text(), it updates the label's minimum size -- which is what
	# fit_content relies on. That missing size update is why the body stayed blank
	# until a container was hidden and re-shown by hand.
	body_label.text = body_text

	footer_label.text = str(result.get("footer_text", result.get("popup_footer", "Tap anywhere to continue.")))

	var show_combat: bool = bool(combat_ui.get("visible", false))
	combat_box.visible = show_combat

	if show_combat:
		combat_status_label.text = str(combat_ui.get("status_text", ""))
		combat_player_label.text = str(combat_ui.get("player_label", "Fighter A"))
		combat_player_bar.max_value = max(1.0, float(combat_ui.get("player_max", 100)))
		combat_player_bar.value = clampf(float(combat_ui.get("player_value", 0)), 0.0, combat_player_bar.max_value)

		combat_enemy_label.text = str(combat_ui.get("enemy_label", "Fighter B"))
		combat_enemy_bar.max_value = max(1.0, float(combat_ui.get("enemy_max", 100)))
		combat_enemy_bar.value = clampf(float(combat_ui.get("enemy_value", 0)), 0.0, combat_enemy_bar.max_value)
	else:
		combat_status_label.text = ""
		combat_player_label.text = ""
		combat_enemy_label.text = ""
		combat_player_bar.value = 0
		combat_enemy_bar.value = 0

	_apply_progress_theme(theme_name, combat_ui)
	_clear_buttons()

	var opps_raw: Variant = result.get("opps", [])
	var opps: Array = opps_raw if typeof(opps_raw) == TYPE_ARRAY else []

	for raw_opp in opps:
		var label_text:= ""
		var disabled:= false
		var tooltip_hint:= ""
		var option_style_data: Dictionary = {}

		if typeof(raw_opp) == TYPE_DICTIONARY:
			var opp: Dictionary = raw_opp
			option_style_data = opp.duplicate(true)
			label_text = str(opp.get("label", "Choose"))
			disabled = bool(opp.get("disabled", false))
			tooltip_hint = str(opp.get("tooltip", ""))
		else:
			label_text = str(raw_opp)

		var btn:= Button.new()
		btn.text = label_text
		btn.disabled = disabled
		btn.tooltip_text = tooltip_hint
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 48)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.focus_mode = Control.FOCUS_ALL

		_apply_button_theme(btn, theme_name, disabled, option_style_data)

		if not disabled:
			btn.pressed.connect(_emit_option_pressed_from_button.bind(label_text))

		buttons_box.add_child(btn)

	if opps.is_empty():
		var done_btn:= Button.new()
		done_btn.text = "Done"
		done_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		done_btn.custom_minimum_size = Vector2(0, 48)
		done_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		done_btn.focus_mode = Control.FOCUS_ALL
		_apply_button_theme(done_btn, theme_name, false, {})
		done_btn.pressed.connect(_hide_panel_from_button)
		buttons_box.add_child(done_btn)

	if show_combat and bool(combat_ui.get("impact_shake", false)):
		var shake_amount: float = max(0.0, float(combat_ui.get("impact_shake_amount", 0.0)))
		if shake_amount > 0.0:
			call_deferred("_play_combat_impact_shake", shake_amount)
	if show_combat:
		var screen_damage_packet: Dictionary = _combat_screen_damage_packet(combat_ui)
		if bool(screen_damage_packet.get("active", false)):
			call_deferred("_play_combat_screen_damage", screen_damage_packet)
			_configure_idle_escalation_from_result(result)
			_start_idle_escalation_timer()

	# FIX: the card does not lay out on the first present. The panel is visible and the
	# card has a size, but nothing appears until the CenterContainer is hidden and
	# shown again, which forces Godot to re-sort it. queue_sort() alone was not enough
	# because the panel is still being laid out in this same frame, so the request is
	# swallowed. Repeat the toggle that is known to work, deferred to the next frame.
	if card != null and is_instance_valid(card):
		var card_parent: Node = card.get_parent()
		if card_parent is Container:
			(card_parent as Container).queue_sort()
		if card is Container:
			(card as Container).queue_sort()

	queue_redraw()

	# Arm several frames of re-layout rather than a single deferred pass -- one frame
	# was still too early and the card kept needing a manual toggle.
	_layout_settle_frames = 6
	_layout_passes_run = 0
	set_process(true)
	set_process_unhandled_key_input(true)
	call_deferred("_force_scenario_card_layout")
	call_deferred("snapshot_layout", "after_present")


func _unhandled_key_input(event: InputEvent) -> void:
	# Press F9 after fixing the panel by hand to capture the second snapshot. The
	# difference between "after_present" and "after_manual_fix" is the bug.
	if not visible:
		return

	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return

	if key_event.keycode == KEY_F9:
		snapshot_layout("after_manual_fix")

var _layout_settle_frames: int = 0
var _layout_passes_run: int = 0


func _process(_delta: float) -> void:
	# A single deferred pass was not enough: the manual fix works because it happens
	# seconds later, once every container has settled. Repeat the re-layout for a few
	# consecutive frames after present(), then switch processing back off so this
	# costs nothing during normal play.
	if _layout_settle_frames <= 0:
		set_process(false)
		return

	_layout_settle_frames -= 1
	_force_scenario_card_layout()

	if _layout_settle_frames <= 0:
		set_process(false)


func _force_scenario_card_layout() -> void:
	# NOTE: this re-layout pass is a workaround, not a cure. Measurement shows the
	# card is 1742px tall while body_scroll is only 136px, so the height comes from
	# the BUTTONS area, not the body text. The panel also reports its own height as
	# 1440 inside a 900px viewport, so its anchoring is wrong as well. Until those two
	# are fixed properly the card overflows the screen and only a forced re-layout
	# brings it back.
	if card == null or not is_instance_valid(card):
		return

	var card_parent: Node = card.get_parent()
	if card_parent == null or not (card_parent is Control):
		return

	var container: Control = card_parent as Control
	if not container.visible:
		return

	container.visible = false
	container.visible = true

	# ROOT CAUSE (measured in-game): the RichTextLabel came out 1px wide inside a 782px
	# ScrollContainer, so 422 characters wrapped into a single-character column 9683px
	# tall. That inflated the card to 2457px and the CenterContainer centred it at
	# y=-779 -- almost entirely above the screen. Disabling horizontal scroll is the
	# proper container-level fix, but the label's width is forced here too so it cannot
	# collapse again regardless of when the scroll gets its own size.
	if (
		body_label != null
		and is_instance_valid(body_label)
		and body_scroll != null
		and is_instance_valid(body_scroll)
	):
		var target_label_width: float = maxf(
			0.0,
			body_scroll.size.x - 8.0
		)

		if (
			target_label_width > 1.0
			and absf(body_label.custom_minimum_size.x - target_label_width) > 1.0
		):
			body_label.custom_minimum_size = Vector2(
				target_label_width,
				body_label.custom_minimum_size.y
			)
			body_label.reset_size()

	# The two snapshots differ in exactly one value: the card stays 820x2457 at
	# y=-779 after present, and becomes 820x637 at y=131 after a manual toggle. The
	# label is already correct (774x276) in both. So the card is holding a CACHED
	# minimum size computed while the label was still 9683px tall. Godot only
	# recomputes that on an explicit invalidation, so walk the chain from the label
	# up to the card and invalidate each one.
	var invalidation_chain: Array = [
		body_label,
		body_scroll,
		buttons_box,
		buttons_scroll,
		card
	]

	for raw_node in invalidation_chain:
		if raw_node == null or not is_instance_valid(raw_node):
			continue

		var control_node: Control = raw_node as Control
		if control_node == null:
			continue

		control_node.update_minimum_size()

		if control_node is Container:
			(control_node as Container).queue_sort()

	# update_minimum_size() alone did not shrink the card in game -- it stayed at the
	# stale 2457 while the manual toggle produced 637. reset_size() forces the control
	# back to its minimum immediately rather than waiting for a recompute.
	card.reset_size()

	if container is Container:
		(container as Container).queue_sort()

	# The card's SIZE now corrects on the first pass (2457 -> 637), but its POSITION
	# stays at -779, which was the correct centring for the old 2457px card:
	# (900 - 2457) / 2 = -778.5. The CenterContainer is not re-centring after the
	# resize, so centre the card directly. If the container does sort later it will
	# arrive at the same value: (900 - 637) / 2 = 131.5.
	var centred_position: Vector2 = (
		(container.size - card.size) * 0.5
	).round()

	if card.position.distance_to(centred_position) > 1.0:
		card.position = centred_position

	# With the panel anchored to its parent instead of top_level, Godot sizes it and
	# emits the resize notifications itself -- the manual size alternation that used
	# to live here is no longer needed and would fight the anchors.
	#
	# What a real window resize does, and nothing else did, is send
	# NOTIFICATION_RESIZED to EVERY Control in the tree. That is the cascade that makes
	# each container remeasure. propagate_notification() sends exactly that to this
	# panel and all of its descendants, without touching the window.
	propagate_notification(Control.NOTIFICATION_RESIZED)

	_layout_passes_run += 1

	if body_scroll != null and is_instance_valid(body_scroll):
		if body_scroll.visible:
			body_scroll.visible = false
			body_scroll.visible = true
		body_scroll.queue_sort()

	_resort_container_subtree(container)

	card.queue_redraw()
	queue_redraw()


func _resort_container_subtree(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return

	for child in node.get_children():
		_resort_container_subtree(child)

	if node is Control:
		# THE missing call. queue_sort() re-positions a container's children but does
		# NOT recompute cached minimum sizes, so the card stayed sized for the old
		# 9683px label (820x2457 at y=-779) even after the label shrank to 774x276.
		# update_minimum_size() is what invalidates that cache -- which is what the
		# manual hide/show was really doing.
		(node as Control).update_minimum_size()

	if node is Container:
		var container_node: Container = node as Container
		if container_node.visible:
			container_node.visible = false
			container_node.visible = true
		container_node.queue_sort()

	if node is Control:
		(node as Control).queue_redraw()


func _on_scenario_panel_visibility_changed() -> void:
	if not visible:
		return

	# Every time this panel is revealed -- first present or the tenth -- give it a
	# fresh run of layout passes. Without this, a re-shown panel keeps the cached
	# sizes from the previous scenario and renders off-screen again.
	_layout_settle_frames = 6
	_layout_passes_run = 0
	set_process(true)
	call_deferred("_force_scenario_card_layout")


func snapshot_layout(tag: String) -> void:
	# Captures every property that could plausibly differ between "present() just ran"
	# and "the user toggled a container by hand". Whatever changes between the two
	# snapshots IS the bug -- no more reasoning from the code.
	var rows: Array = []

	var probes: Array = [
		["panel", self],
		["center", card.get_parent() if card != null and is_instance_valid(card) else null],
		["card", card],
		["body_scroll", body_scroll],
		["body_label", body_label],
		["buttons_box", buttons_box]
	]

	for probe in probes:
		var probe_name: String = str(probe[0])
		var node = probe[1]

		if node == null or not is_instance_valid(node):
			rows.append("%s=<missing>" % probe_name)
			continue

		var control: Control = node as Control
		if control == null:
			rows.append("%s=<not_control>" % probe_name)
			continue

		rows.append(
			"%s[vis=%s size=%.0fx%.0f pos=%.0f,%.0f min=%.0fx%.0f mod_a=%.2f clip=%s]"
			% [
				probe_name,
				str(control.visible),
				control.size.x,
				control.size.y,
				control.position.x,
				control.position.y,
				control.custom_minimum_size.x,
				control.custom_minimum_size.y,
				control.modulate.a,
				str(control.clip_contents)
			]
		)

	if body_label != null and is_instance_valid(body_label):
		rows.append(
			"label_extra[text_len=%d fit=%s scroll_active=%s bbcode=%s content_h=%.0f]"
			% [
				body_label.text.length(),
				str(body_label.fit_content),
				str(body_label.scroll_active),
				str(body_label.bbcode_enabled),
				body_label.get_content_height()
			]
		)

	EraLog.truth(
		"ERALIFE_LAYOUT_SNAPSHOT|%s|passes=%d frames_left=%d processing=%s|%s"
		% [tag, _layout_passes_run, _layout_settle_frames, str(is_processing()), " ".join(rows)]
	)


func _stop_spectator_frames() -> void:
	spectator_frames = []
	spectator_frame_index = 0
	spectator_final_interactive = false
	spectator_frame_seconds = 1.15
	spectator_auto_emit_label = ""
	spectator_auto_emit_armed = false
	if spectator_frame_timer != null:
		spectator_frame_timer.stop()
	if spectator_auto_emit_timer != null:
		spectator_auto_emit_timer.stop()


func _present_spectator_frame() -> void:
	# Same requirement as present(): never build the container tree while the panel is
	# still 0x0, or every container caches a zero-based layout.
	_adopt_parent_size()
	_ensure_ui()

	if spectator_frames.is_empty():
		return

	visible = true
	show()
	mouse_filter = Control.MOUSE_FILTER_STOP
	# FIX: this panel was top_level, which makes a Control ignore its parent's
	# transform -- so PRESET_FULL_RECT anchors had nothing to resolve against, the
	# size had to be assigned by hand, and the container tree never received the
	# resize notifications that make Godot lay it out. That is why the card kept its
	# stale minimum and position until a real viewport resize (the editor's aspect
	# ratio button, then fullscreen) forced one. As a normal anchored child the panel
	# tracks its parent and gets those notifications for free.
	top_level = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	focus_mode = Control.FOCUS_ALL
	z_as_relative = false
	z_index = max(int(z_index), 144)

	if dim != null:
		dim.visible = true
		dim.mouse_filter = Control.MOUSE_FILTER_STOP

	if card != null:
		card.visible = true
		card.mouse_filter = Control.MOUSE_FILTER_STOP

	var frame_index: int = clamp(spectator_frame_index, 0, spectator_frames.size() - 1)
	var frame_raw: Variant = spectator_frames [frame_index]
	var frame: Dictionary = {}
	if typeof(frame_raw) == TYPE_DICTIONARY:
		frame = (frame_raw as Dictionary).duplicate(true)
	else:
		frame = {
			"panel_title": "BENDING WORLD CHAMPIONSHIP — SPECTATING",
			"text": str(frame_raw),
			"footer_text": "Spectating live.",
			"opps": []
		}

	title_label.text = str(frame.get("panel_title", "BENDING WORLD CHAMPIONSHIP — SPECTATING"))

	body_label.clear()
	var frame_text: String = str(frame.get("text", "")).strip_edges()
	if frame_text == "":
		frame_text = "The fighters are circling, reading each other, and waiting for the next exchange."
	body_label.append_text(frame_text)

	footer_label.text = str(frame.get("footer_text", "Spectating live."))

	var combat_ui_raw: Variant = frame.get("combat_ui", {})
	var combat_ui: Dictionary = combat_ui_raw if typeof(combat_ui_raw) == TYPE_DICTIONARY else {}
	var theme_name: String = _resolve_theme_name(frame, combat_ui)

	_apply_theme(theme_name)

	var show_combat: bool = bool(combat_ui.get("visible", false))
	combat_box.visible = show_combat

	if show_combat:
		combat_status_label.text = str(combat_ui.get("status_text", ""))
		combat_player_label.text = str(combat_ui.get("player_label", "Fighter A"))
		combat_player_bar.max_value = max(1.0, float(combat_ui.get("player_max", 100)))
		combat_player_bar.value = clampf(float(combat_ui.get("player_value", 0)), 0.0, combat_player_bar.max_value)

		combat_enemy_label.text = str(combat_ui.get("enemy_label", "Fighter B"))
		combat_enemy_bar.max_value = max(1.0, float(combat_ui.get("enemy_max", 100)))
		combat_enemy_bar.value = clampf(float(combat_ui.get("enemy_value", 0)), 0.0, combat_enemy_bar.max_value)
	else:
		combat_status_label.text = ""
		combat_player_label.text = ""
		combat_enemy_label.text = ""
		combat_player_bar.value = 0
		combat_enemy_bar.value = 0

	_apply_progress_theme(theme_name, combat_ui)
	_clear_buttons()

	var hide_actions: bool = bool(frame.get("hide_actions", false))
	if buttons_scroll != null:
		buttons_scroll.visible = not hide_actions

	var opps_raw: Variant = frame.get("opps", [])
	var opps: Array = opps_raw if typeof(opps_raw) == TYPE_ARRAY else []
	var final_interactive_frame: bool = spectator_final_interactive and frame_index >= spectator_frames.size() - 1

	if not hide_actions:
		for raw_opp in opps:
			var opp: Dictionary = raw_opp if typeof(raw_opp) == TYPE_DICTIONARY else {
				"label": str(raw_opp),
				"disabled": not final_interactive_frame
			}

			var label_text: String = str(opp.get("label", "Watching..."))
			var disabled: bool = bool(opp.get("disabled", false)) or not final_interactive_frame

			var btn:= Button.new()
			btn.text = label_text
			btn.disabled = disabled
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.custom_minimum_size = Vector2(0, 48)
			btn.mouse_filter = Control.MOUSE_FILTER_STOP
			btn.focus_mode = Control.FOCUS_ALL if final_interactive_frame and not disabled else Control.FOCUS_NONE

			_apply_button_theme(btn, theme_name, disabled, opp)

			if final_interactive_frame and not disabled:
				btn.pressed.connect(_emit_spectator_option_pressed_from_button.bind(label_text))

			buttons_box.add_child(btn)

		if opps.is_empty() and spectator_frame_index < spectator_frames.size() - 1:
			var watching_btn:= Button.new()
			watching_btn.text = "Watching the exchange..."
			watching_btn.disabled = true
			watching_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			watching_btn.custom_minimum_size = Vector2(0, 48)
			watching_btn.mouse_filter = Control.MOUSE_FILTER_STOP
			watching_btn.focus_mode = Control.FOCUS_NONE
			_apply_button_theme(watching_btn, theme_name, true, {})
			buttons_box.add_child(watching_btn)

	if show_combat and bool(combat_ui.get("impact_shake", false)):
		var shake_amount: float = max(0.0, float(combat_ui.get("impact_shake_amount", 0.0)))
		if shake_amount > 0.0:
			call_deferred("_play_combat_impact_shake", shake_amount)

	if show_combat:
		var screen_damage_packet: Dictionary = _combat_screen_damage_packet(combat_ui)
		if bool(screen_damage_packet.get("active", false)):
			call_deferred("_play_combat_screen_damage", screen_damage_packet)

	if final_interactive_frame:
		_configure_idle_escalation_from_result(frame)
		_start_idle_escalation_timer()
		_start_spectator_auto_emit(frame)
	else:
		_stop_idle_escalation()
		_stop_spectator_auto_emit()

	if spectator_frame_index < spectator_frames.size() - 1:
		spectator_frame_index += 1
		if spectator_frame_timer != null:
			var next_delay_seconds: float = clamp(float(frame.get("delay_seconds", spectator_frame_seconds)), 0.12, 30.0)
			spectator_frame_timer.wait_time = next_delay_seconds
			spectator_frame_timer.start()
	else:
		if not final_interactive_frame:
			var done_btn:= Button.new()
			done_btn.text = "Done Watching"
			done_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			done_btn.custom_minimum_size = Vector2(0, 48)
			done_btn.mouse_filter = Control.MOUSE_FILTER_STOP
			done_btn.focus_mode = Control.FOCUS_ALL
			_apply_button_theme(done_btn, theme_name, false, {})
			done_btn.pressed.connect(_hide_panel_from_button)
			buttons_box.add_child(done_btn)
func _start_spectator_auto_emit(frame: Dictionary = {}) -> void:
	if spectator_auto_emit_timer == null:
		return

	_stop_spectator_auto_emit()

	var auto_label: String = str(frame.get("auto_emit_label", "")).strip_edges()
	if auto_label == "":
		return

	var delay_seconds: float = float(frame.get("auto_emit_after_seconds", 0.0))
	if delay_seconds <= 0.0:
		return

	spectator_auto_emit_label = auto_label
	spectator_auto_emit_armed = true
	spectator_auto_emit_timer.wait_time = clamp(delay_seconds, 0.8, 60.0)
	spectator_auto_emit_timer.start()


func _stop_spectator_auto_emit() -> void:
	spectator_auto_emit_label = ""
	spectator_auto_emit_armed = false
	if spectator_auto_emit_timer != null:
		spectator_auto_emit_timer.stop()


func _on_spectator_auto_emit_timeout() -> void:
	if not spectator_auto_emit_armed:
		return

	var label: String = spectator_auto_emit_label.strip_edges()
	_stop_spectator_auto_emit()
	_stop_idle_escalation()

	if label == "":
		return

	option_pressed.emit(label)
func _emit_option_pressed_from_button(action_label: String) -> void:
	var clean_label: String = str(action_label).strip_edges()
	if clean_label == "":
		return

	_stop_idle_escalation()
	option_pressed.emit(clean_label)


func _emit_spectator_option_pressed_from_button(action_label: String) -> void:
	var clean_label: String = str(action_label).strip_edges()
	if clean_label == "":
		return

	_stop_idle_escalation()
	_stop_spectator_auto_emit()
	option_pressed.emit(clean_label)


func _hide_panel_from_button() -> void:
	_stop_idle_escalation()
	_stop_spectator_auto_emit()
	option_pressed.emit("Done Watching")
	hide_panel()
func _configure_idle_escalation_from_result(result: Dictionary) -> void:
	idle_escalation_frames = []
	idle_escalation_index = 0
	idle_escalation_seconds = clamp(float(result.get("idle_escalation_seconds", 4.6)), 0.8, 30.0)

	var frames_raw: Variant = result.get("idle_escalation_frames", [])
	if typeof(frames_raw) == TYPE_ARRAY:
		idle_escalation_frames = (frames_raw as Array).duplicate(true)
func _start_idle_escalation_timer() -> void:
	if idle_escalation_timer == null:
		return
	if idle_escalation_frames.is_empty():
		return

	var next_frame: Dictionary = {}
	if typeof(idle_escalation_frames [idle_escalation_index]) == TYPE_DICTIONARY:
		next_frame = idle_escalation_frames [idle_escalation_index] as Dictionary

	var delay_seconds: float = idle_escalation_seconds
	if not next_frame.is_empty():
		delay_seconds = clamp(float(next_frame.get("delay_seconds", idle_escalation_seconds)), 0.8, 30.0)

	idle_escalation_timer.stop()
	idle_escalation_timer.wait_time = delay_seconds
	idle_escalation_timer.start()
func _stop_idle_escalation() -> void:
	idle_escalation_frames = []
	idle_escalation_index = 0
	idle_escalation_seconds = 4.6
	if idle_escalation_timer != null:
		idle_escalation_timer.stop()
func _advance_idle_escalation_frame() -> void:
	if not visible:
		return
	if idle_escalation_frames.is_empty():
		return

	if idle_escalation_index < 0:
		idle_escalation_index = 0

	if idle_escalation_index >= idle_escalation_frames.size():
		idle_escalation_index = 0

	var frame_raw: Variant = idle_escalation_frames [idle_escalation_index]
	var frame: Dictionary = {}
	if typeof(frame_raw) == TYPE_DICTIONARY:
		frame = (frame_raw as Dictionary).duplicate(true)
	else:
		frame = {
			"panel_title": "SHENRON • PRESSURE",
			"text": str(frame_raw),
			"footer_text": "The dragon waits."
		}

	var combat_ui_raw: Variant = frame.get("combat_ui", {})
	var combat_ui: Dictionary = combat_ui_raw if typeof(combat_ui_raw) == TYPE_DICTIONARY else {}
	var theme_name: String = _resolve_theme_name(frame, combat_ui)
	_apply_theme(theme_name)

	title_label.text = str(frame.get("panel_title", title_label.text))
	body_label.clear()

	var frame_text: String = str(frame.get("text", "")).strip_edges()
	if frame_text == "":
		frame_text = "The pressure grows."

	body_label.append_text(frame_text)
	footer_label.text = str(frame.get("footer_text", footer_label.text))

	idle_escalation_index += 1
	if idle_escalation_index >= idle_escalation_frames.size():
		idle_escalation_index = clamp(int(frame.get("loop_to_index", 0)), 0, max(0, idle_escalation_frames.size() - 1))

	_start_idle_escalation_timer()

func _advance_spectator_frame() -> void:
	if not visible:
		return
	_present_spectator_frame()
func _play_combat_impact_shake(amount: float = 8.0) -> void:
	if card == null:
		return
	var base_position:= Vector2(
		float(card.get_meta("_combat_shake_base_x", card.position.x)),
		float(card.get_meta("_combat_shake_base_y", card.position.y))
	)
	card.set_meta("_combat_shake_base_x", base_position.x)
	card.set_meta("_combat_shake_base_y", base_position.y)
	card.position = base_position
	var tween:= create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "position", base_position + Vector2(amount, 0), 0.035)
	tween.tween_property(card, "position", base_position + Vector2(- amount * 0.72, 0), 0.045)
	tween.tween_property(card, "position", base_position + Vector2(amount * 0.36, 0), 0.04)
	tween.tween_property(card, "position", base_position, 0.05)

func _combat_screen_damage_packet(combat_ui: Dictionary) -> Dictionary:
	var raw_packet: Variant = combat_ui.get("elemental_screen_damage", {})
	if typeof(raw_packet) == TYPE_DICTIONARY:
		return (raw_packet as Dictionary).duplicate(true)
	return {}


func _play_combat_screen_damage(packet: Dictionary = {}) -> void:
	if dim == null:
		return
	if typeof(packet) != TYPE_DICTIONARY or not bool(packet.get("active", false)):
		return

	var element: String = str(packet.get("element", "generic")).strip_edges().to_lower()
	var intensity: float = clamp(float(packet.get("intensity", 0.35)), 0.05, 1.0)
	var duration: float = clamp(float(packet.get("duration_ms", 260)) / 1000.0, 0.08, 0.75)

	var original_color: Color = dim.color
	var flash_color: Color = Color(1.0, 1.0, 1.0, clamp(0.12 + intensity * 0.28, 0.12, 0.42))

	match element:
		"fire":
			flash_color = Color(1.0, 0.22, 0.04, clamp(0.16 + intensity * 0.38, 0.16, 0.58))
		"water":
			flash_color = Color(0.08, 0.42, 1.0, clamp(0.14 + intensity * 0.34, 0.14, 0.52))
		"earth":
			flash_color = Color(0.42, 0.3, 0.12, clamp(0.16 + intensity * 0.36, 0.16, 0.54))
		"air":
			flash_color = Color(0.82, 0.96, 1.0, clamp(0.13 + intensity * 0.28, 0.13, 0.46))
		"avatar":
			flash_color = Color(0.86, 0.78, 1.0, clamp(0.18 + intensity * 0.4, 0.18, 0.62))

	dim.color = flash_color

	var tween:= create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(dim, "color", original_color, duration)
func _resolve_theme_name(result: Dictionary, combat_ui: Dictionary) -> String:
	var theme_name: String = str(result.get("theme", combat_ui.get("theme", ""))).strip_edges().to_lower()
	if theme_name != "":
		return theme_name

	var panel_title: String = str(result.get("panel_title", "")).strip_edges().to_lower()
	if panel_title == "nidavellir":
		return "nidavellir"
	if panel_title.find("reality fusion") >= 0:
		return "reality_fusion"
	if panel_title.find("shenron") >= 0 or panel_title.find("dragon") >= 0:
		return "dragonball"

	return ""
func _bending_theme_palette(theme_name: String) -> Dictionary:
	match str(theme_name).strip_edges().to_lower():
		"bending_element_air":
			return {
				"bg": Color(0.12, 0.3, 0.38, 0.98),
				"border": Color(0.78, 0.96, 1.0, 0.98),
				"shadow": Color(0.56, 0.9, 1.0, 0.46),
				"font": Color(0.9, 0.98, 1.0, 0.98),
				"fill": Color(0.62, 0.9, 1.0, 0.96)
			}
		"bending_element_earth":
			return {
				"bg": Color(0.08, 0.24, 0.12, 0.98),
				"border": Color(0.56, 0.92, 0.36, 0.98),
				"shadow": Color(0.32, 0.76, 0.24, 0.46),
				"font": Color(0.92, 1.0, 0.86, 0.98),
				"fill": Color(0.36, 0.76, 0.26, 0.96)
			}
		"bending_element_fire":
			return {
				"bg": Color(0.34, 0.06, 0.02, 0.98),
				"border": Color(1.0, 0.48, 0.16, 0.98),
				"shadow": Color(1.0, 0.2, 0.06, 0.52),
				"font": Color(1.0, 0.92, 0.84, 0.98),
				"fill": Color(1.0, 0.3, 0.08, 0.96)
			}
		"bending_element_water":
			return {
				"bg": Color(0.02, 0.14, 0.34, 0.98),
				"border": Color(0.32, 0.74, 1.0, 0.98),
				"shadow": Color(0.12, 0.58, 1.0, 0.5),
				"font": Color(0.88, 0.96, 1.0, 0.98),
				"fill": Color(0.14, 0.58, 1.0, 0.96)
			}
		"bending_avatar":
			return {
				"bg": Color(0.04, 0.04, 0.08, 0.98),
				"border": Color(0.96, 0.92, 1.0, 0.98),
				"shadow": Color(0.62, 0.86, 1.0, 0.62),
				"font": Color(0.98, 0.96, 1.0, 0.99),
				"fill": Color(0.92, 0.84, 1.0, 0.96)
			}
		"bending_duel_mercy":
			return {
				"bg": Color(0.2, 0.02, 0.02, 0.98),
				"border": Color(1.0, 0.2, 0.1, 0.98),
				"shadow": Color(1.0, 0.04, 0.02, 0.62),
				"font": Color(1.0, 0.9, 0.86, 0.99),
				"fill": Color(1.0, 0.18, 0.06, 0.96)
			}
		_:
			return {}
func _apply_theme(theme_name: String) -> void:
	card.add_theme_stylebox_override("panel", _build_panel_style(theme_name))
	var bending_palette: Dictionary = _bending_theme_palette(theme_name)
	if not bending_palette.is_empty():
		dim.color = Color(0.0, 0.0, 0.0, 0.7)
		title_label.add_theme_color_override("font_color", bending_palette ["font"])
		body_label.add_theme_color_override("default_color", bending_palette ["font"])
		footer_label.add_theme_color_override("font_color", Color(bending_palette ["font"].r, bending_palette ["font"].g, bending_palette ["font"].b, 0.84))
		combat_status_label.add_theme_color_override("font_color", bending_palette ["font"])
		combat_player_label.add_theme_color_override("font_color", bending_palette ["font"])
		combat_enemy_label.add_theme_color_override("font_color", bending_palette ["font"])
		return
	if theme_name == "nidavellir":
		dim.color = Color(0.08, 0.02, 0.1, 0.72)
		title_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.34, 0.99))
		body_label.add_theme_color_override("default_color", Color(1.0, 0.96, 0.9, 0.98))
		footer_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.26, 0.92))
		combat_status_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.22, 0.98))
		combat_player_label.add_theme_color_override("font_color", Color(0.96, 0.76, 1.0, 0.98))
		combat_enemy_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.26, 0.98))
	elif theme_name == "reality_fusion":
		dim.color = Color(0.02, 0.0, 0.08, 0.76)
		title_label.add_theme_color_override("font_color", Color(0.74, 0.92, 1.0, 0.99))
		body_label.add_theme_color_override("default_color", Color(0.9, 0.96, 1.0, 0.98))
		footer_label.add_theme_color_override("font_color", Color(0.72, 0.84, 1.0, 0.92))
		combat_status_label.add_theme_color_override("font_color", Color(0.74, 0.92, 1.0, 0.98))
		combat_player_label.add_theme_color_override("font_color", Color(0.78, 1.0, 0.92, 0.98))
		combat_enemy_label.add_theme_color_override("font_color", Color(1.0, 0.62, 0.92, 0.98))
	elif theme_name == "dragonball":
		dim.color = Color(0.02, 0.01, 0.0, 0.76)
		title_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.32, 0.99))
		body_label.add_theme_color_override("default_color", Color(1.0, 0.94, 0.78, 0.98))
		footer_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.22, 0.92))
		combat_status_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.32, 0.98))
		combat_player_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.56, 0.98))
		combat_enemy_label.add_theme_color_override("font_color", Color(1.0, 0.62, 0.22, 0.98))
	else:
		dim.color = Color(0.0, 0.0, 0.0, 0.58)
		title_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.98))
		body_label.add_theme_color_override("default_color", Color(1.0, 1.0, 1.0, 0.96))
		footer_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.76))
		combat_status_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
		combat_player_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
		combat_enemy_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))

func _apply_progress_theme(theme_name: String, combat_ui: Dictionary = {}) -> void:
	var player_background:= StyleBoxFlat.new()
	var player_fill:= StyleBoxFlat.new()
	var enemy_background:= StyleBoxFlat.new()
	var enemy_fill:= StyleBoxFlat.new()

	var player_theme_name: String = str(combat_ui.get("player_theme", theme_name)).strip_edges().to_lower()
	var enemy_theme_name: String = str(combat_ui.get("enemy_theme", theme_name)).strip_edges().to_lower()

	if player_theme_name == "":
		player_theme_name = theme_name
	if enemy_theme_name == "":
		enemy_theme_name = theme_name

	var player_palette: Dictionary = _bending_theme_palette(player_theme_name)
	var enemy_palette: Dictionary = _bending_theme_palette(enemy_theme_name)

	if not player_palette.is_empty():
		player_background.bg_color = Color(player_palette ["bg"].r * 0.55, player_palette ["bg"].g * 0.55, player_palette ["bg"].b * 0.55, 0.96)
		player_background.border_color = player_palette ["border"]
		player_fill.bg_color = player_palette ["fill"]
		player_fill.border_color = player_palette ["border"]
	elif theme_name == "nidavellir":
		player_background.bg_color = Color(0.18, 0.08, 0.22, 0.96)
		player_background.border_color = Color(0.94, 0.68, 1.0, 0.8)
		player_fill.bg_color = Color(0.78, 0.24, 1.0, 0.96)
		player_fill.border_color = Color(1.0, 0.86, 0.3, 0.92)
	elif theme_name == "reality_fusion":
		player_background.bg_color = Color(0.04, 0.12, 0.16, 0.96)
		player_background.border_color = Color(0.42, 1.0, 0.86, 0.8)
		player_fill.bg_color = Color(0.24, 0.92, 0.72, 0.96)
		player_fill.border_color = Color(0.78, 1.0, 0.92, 0.92)
	else:
		player_background.bg_color = Color(0.1, 0.1, 0.1, 0.92)
		player_background.border_color = Color(1.0, 1.0, 1.0, 0.16)
		player_fill.bg_color = Color(0.7, 0.82, 1.0, 0.92)
		player_fill.border_color = Color(1.0, 1.0, 1.0, 0.2)

	if not enemy_palette.is_empty():
		enemy_background.bg_color = Color(enemy_palette ["bg"].r * 0.55, enemy_palette ["bg"].g * 0.55, enemy_palette ["bg"].b * 0.55, 0.96)
		enemy_background.border_color = enemy_palette ["border"]
		enemy_fill.bg_color = enemy_palette ["fill"]
		enemy_fill.border_color = enemy_palette ["border"]
	elif theme_name == "nidavellir":
		enemy_background.bg_color = Color(0.2, 0.1, 0.08, 0.96)
		enemy_background.border_color = Color(1.0, 0.74, 0.3, 0.84)
		enemy_fill.bg_color = Color(1.0, 0.56, 0.16, 0.98)
		enemy_fill.border_color = Color(1.0, 0.92, 0.34, 0.94)
	elif theme_name == "reality_fusion":
		enemy_background.bg_color = Color(0.16, 0.04, 0.14, 0.96)
		enemy_background.border_color = Color(1.0, 0.4, 0.82, 0.84)
		enemy_fill.bg_color = Color(0.92, 0.18, 0.72, 0.98)
		enemy_fill.border_color = Color(1.0, 0.72, 0.92, 0.94)
	elif theme_name == "bending_duel_mercy":
		enemy_background.bg_color = Color(0.18, 0.0, 0.0, 0.98)
		enemy_background.border_color = Color(1.0, 0.06, 0.02, 0.98)
		enemy_background.shadow_color = Color(1.0, 0.0, 0.0, 0.34)
		enemy_background.shadow_size = 8
		enemy_fill.bg_color = Color(1.0, 0.02, 0.0, 0.98)
		enemy_fill.border_color = Color(1.0, 0.42, 0.3, 1.0)
		enemy_fill.shadow_color = Color(1.0, 0.0, 0.0, 0.68)
		enemy_fill.shadow_size = 10
	else:
		enemy_background.bg_color = Color(0.1, 0.1, 0.1, 0.92)
		enemy_background.border_color = Color(1.0, 1.0, 1.0, 0.16)
		enemy_fill.bg_color = Color(1.0, 0.62, 0.74, 0.92)
		enemy_fill.border_color = Color(1.0, 1.0, 1.0, 0.2)

	for style in [player_background, player_fill, enemy_background, enemy_fill]:
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.corner_radius_top_left = 10
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_left = 10
		style.corner_radius_bottom_right = 10

	combat_player_bar.add_theme_stylebox_override("background", player_background)
	combat_player_bar.add_theme_stylebox_override("fill", player_fill)
	combat_enemy_bar.add_theme_stylebox_override("background", enemy_background)
	combat_enemy_bar.add_theme_stylebox_override("fill", enemy_fill)

	_apply_avatar_bar_pulse(combat_player_bar, bool(combat_ui.get("player_avatar_pulse", player_theme_name == "bending_avatar")), 0.0)
	_apply_avatar_bar_pulse(combat_enemy_bar, bool(combat_ui.get("enemy_avatar_pulse", enemy_theme_name == "bending_avatar")), 0.35)
func _apply_avatar_bar_pulse(bar: ProgressBar, enabled: bool, phase_offset: float = 0.0) -> void:
	if bar == null:
		return

	if not enabled:
		if bool(bar.get_meta("_avatar_bar_pulse_enabled", false)):
			var existing_raw: Variant = bar.get_meta("_avatar_bar_pulse_tween", null)
			if existing_raw is Tween:
				var existing_tween:= existing_raw as Tween
				if is_instance_valid(existing_tween):
					existing_tween.kill()
			bar.set_meta("_avatar_bar_pulse_enabled", false)
			bar.set_meta("_avatar_bar_pulse_tween", null)
			bar.modulate = Color(1, 1, 1, 1)
		return

	if bool(bar.get_meta("_avatar_bar_pulse_enabled", false)):
		return

	bar.set_meta("_avatar_bar_pulse_enabled", true)

	var tween:= create_tween()
	tween.set_loops()
	tween.tween_property(bar, "modulate", Color(1.0, 0.42, 0.18, 1.0), 0.3 + phase_offset)
	tween.tween_property(bar, "modulate", Color(0.24, 0.62, 1.0, 1.0), 0.3)
	tween.tween_property(bar, "modulate", Color(0.42, 0.9, 0.34, 1.0), 0.3)
	tween.tween_property(bar, "modulate", Color(0.82, 0.96, 1.0, 1.0), 0.3)
	tween.tween_property(bar, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.22)

	bar.set_meta("_avatar_bar_pulse_tween", tween)
func _resolve_stone_action_name(option_data: Dictionary) -> String:
	if typeof(option_data) != TYPE_DICTIONARY:
		return ""
	var explicit_theme: String = str(option_data.get("button_theme", "")).strip_edges().to_lower()
	var power_source: String = str(option_data.get("power_source", "")).strip_edges().to_lower()
	var stone_name: String = str(option_data.get("stone_key", option_data.get("stone_name", ""))).strip_edges()
	if stone_name == "":
		return ""
	if explicit_theme == "infinity_stone":
		return stone_name
	if power_source == "stone":
		return stone_name
	return ""
func _inventory_action_button_palette(option_data: Dictionary) -> Dictionary:
	if typeof(option_data) != TYPE_DICTIONARY:
		return {}

	var theme_name: String = str(option_data.get("button_theme", "")).strip_edges().to_lower()
	var power_source: String = str(option_data.get("power_source", "")).strip_edges().to_lower()

	if theme_name in ["artifact_action"] or power_source == "artifact":
		return {
			"bg": Color(0.42, 0.2, 0.62, 0.98),
			"border": Color(0.86, 0.54, 1.0, 0.98),
			"shadow": Color(0.7, 0.28, 1.0, 0.52),
			"hover_bg": Color(0.58, 0.26, 0.82, 1.0),
			"hover_border": Color(0.96, 0.74, 1.0, 1.0),
			"hover_shadow": Color(0.86, 0.46, 1.0, 0.74),
			"font": Color(0.98, 0.92, 1.0, 1.0)
		}

	if theme_name in ["weapon_action"] or power_source == "weapon":
		return {
			"bg": Color(0.54, 0.12, 0.12, 0.98),
			"border": Color(1.0, 0.42, 0.32, 0.98),
			"shadow": Color(1.0, 0.2, 0.16, 0.5),
			"hover_bg": Color(0.74, 0.18, 0.16, 1.0),
			"hover_border": Color(1.0, 0.62, 0.48, 1.0),
			"hover_shadow": Color(1.0, 0.32, 0.22, 0.72),
			"font": Color(1.0, 0.94, 0.9, 1.0)
		}

	if theme_name in ["inventory_action"] or power_source == "inventory":
		return {
			"bg": Color(0.24, 0.34, 0.48, 0.98),
			"border": Color(0.56, 0.78, 1.0, 0.96),
			"shadow": Color(0.28, 0.58, 1.0, 0.42),
			"hover_bg": Color(0.32, 0.46, 0.64, 1.0),
			"hover_border": Color(0.72, 0.9, 1.0, 1.0),
			"hover_shadow": Color(0.42, 0.72, 1.0, 0.62),
			"font": Color(0.92, 0.97, 1.0, 1.0)
		}

	if theme_name in ["reality_break"] or power_source == "reality":
		return {
			"bg": Color(0.46, 0.08, 0.56, 0.98),
			"border": Color(0.72, 0.92, 1.0, 0.98),
			"shadow": Color(0.72, 0.26, 1.0, 0.58),
			"hover_bg": Color(0.64, 0.12, 0.8, 1.0),
			"hover_border": Color(0.92, 1.0, 1.0, 1.0),
			"hover_shadow": Color(0.88, 0.42, 1.0, 0.78),
			"font": Color(0.94, 0.98, 1.0, 1.0)
		}

	if theme_name in ["defensive_escape"] or power_source == "survival":
		return {
			"bg": Color(0.12, 0.34, 0.26, 0.98),
			"border": Color(0.5, 1.0, 0.72, 0.96),
			"shadow": Color(0.22, 1.0, 0.62, 0.4),
			"hover_bg": Color(0.18, 0.48, 0.36, 1.0),
			"hover_border": Color(0.7, 1.0, 0.84, 1.0),
			"hover_shadow": Color(0.34, 1.0, 0.72, 0.62),
			"font": Color(0.92, 1.0, 0.94, 1.0)
		}

	return {}

func _infinity_stone_button_palette(stone_name: String) -> Dictionary:
	match str(stone_name).strip_edges().to_lower():
		"time":
			return {
				"bg": Color(0.05, 0.42, 0.16, 0.98),
				"border": Color(0.42, 1.0, 0.52, 0.98),
				"shadow": Color(0.16, 1.0, 0.34, 0.58),
				"hover_bg": Color(0.08, 0.58, 0.24, 1.0),
				"hover_border": Color(0.64, 1.0, 0.7, 1.0),
				"hover_shadow": Color(0.24, 1.0, 0.44, 0.78),
				"font": Color(0.92, 1.0, 0.92, 1.0)
			}
		"space":
			return {
				"bg": Color(0.06, 0.18, 0.62, 0.98),
				"border": Color(0.36, 0.66, 1.0, 0.98),
				"shadow": Color(0.16, 0.44, 1.0, 0.58),
				"hover_bg": Color(0.08, 0.28, 0.82, 1.0),
				"hover_border": Color(0.58, 0.82, 1.0, 1.0),
				"hover_shadow": Color(0.28, 0.62, 1.0, 0.78),
				"font": Color(0.92, 0.97, 1.0, 1.0)
			}
		"reality":
			return {
				"bg": Color(0.56, 0.06, 0.14, 0.98),
				"border": Color(1.0, 0.2, 0.34, 0.98),
				"shadow": Color(1.0, 0.12, 0.28, 0.58),
				"hover_bg": Color(0.78, 0.08, 0.2, 1.0),
				"hover_border": Color(1.0, 0.42, 0.52, 1.0),
				"hover_shadow": Color(1.0, 0.2, 0.38, 0.78),
				"font": Color(1.0, 0.94, 0.95, 1.0)
			}
		"mind":
			return {
				"bg": Color(0.72, 0.58, 0.08, 0.98),
				"border": Color(1.0, 0.92, 0.24, 0.98),
				"shadow": Color(1.0, 0.86, 0.18, 0.56),
				"hover_bg": Color(0.92, 0.74, 0.1, 1.0),
				"hover_border": Color(1.0, 0.98, 0.44, 1.0),
				"hover_shadow": Color(1.0, 0.94, 0.28, 0.76),
				"font": Color(1.0, 0.99, 0.88, 1.0)
			}
		"soul":
			return {
				"bg": Color(0.68, 0.3, 0.04, 0.98),
				"border": Color(1.0, 0.62, 0.18, 0.98),
				"shadow": Color(1.0, 0.46, 0.1, 0.58),
				"hover_bg": Color(0.88, 0.4, 0.06, 1.0),
				"hover_border": Color(1.0, 0.78, 0.36, 1.0),
				"hover_shadow": Color(1.0, 0.58, 0.18, 0.78),
				"font": Color(1.0, 0.96, 0.88, 1.0)
			}
		"power":
			return {
				"bg": Color(0.44, 0.08, 0.72, 0.98),
				"border": Color(0.82, 0.34, 1.0, 0.98),
				"shadow": Color(0.72, 0.22, 1.0, 0.6),
				"hover_bg": Color(0.58, 0.12, 0.92, 1.0),
				"hover_border": Color(0.94, 0.58, 1.0, 1.0),
				"hover_shadow": Color(0.86, 0.34, 1.0, 0.8),
				"font": Color(0.98, 0.92, 1.0, 1.0)
			}
		_:
			return {}
func _resolve_bending_action_element(option_data: Dictionary) -> String:
	if typeof(option_data) != TYPE_DICTIONARY:
		return ""
	var explicit_theme: String = str(option_data.get("button_theme", "")).strip_edges().to_lower()
	var power_source: String = str(option_data.get("power_source", "")).strip_edges().to_lower()
	var element: String = str(option_data.get("ability_element", "")).strip_edges().to_lower()
	if element == "":
		return ""
	if explicit_theme == "bending_ability":
		return element
	if power_source == "bending":
		return element
	return ""


func _bending_button_palette(element: String) -> Dictionary:
	match str(element).strip_edges().to_lower():
		"air":
			return {
				"bg": Color(0.6, 0.86, 1.0, 0.94),
				"border": Color(0.86, 0.98, 1.0, 0.98),
				"shadow": Color(0.7, 0.96, 1.0, 0.52),
				"hover_bg": Color(0.72, 0.94, 1.0, 1.0),
				"hover_border": Color(0.96, 1.0, 1.0, 1.0),
				"hover_shadow": Color(0.82, 1.0, 1.0, 0.72),
				"font": Color(0.04, 0.12, 0.18, 1.0)
			}
		"earth":
			return {
				"bg": Color(0.22, 0.46, 0.16, 0.96),
				"border": Color(0.52, 0.88, 0.38, 0.98),
				"shadow": Color(0.34, 0.78, 0.28, 0.54),
				"hover_bg": Color(0.3, 0.62, 0.22, 1.0),
				"hover_border": Color(0.7, 1.0, 0.54, 1.0),
				"hover_shadow": Color(0.44, 0.94, 0.36, 0.76),
				"font": Color(0.94, 1.0, 0.9, 1.0)
			}
		"fire":
			return {
				"bg": Color(0.78, 0.18, 0.06, 0.96),
				"border": Color(1.0, 0.54, 0.2, 0.98),
				"shadow": Color(1.0, 0.3, 0.08, 0.58),
				"hover_bg": Color(0.96, 0.26, 0.08, 1.0),
				"hover_border": Color(1.0, 0.72, 0.34, 1.0),
				"hover_shadow": Color(1.0, 0.42, 0.12, 0.78),
				"font": Color(1.0, 0.94, 0.88, 1.0)
			}
		"water":
			return {
				"bg": Color(0.06, 0.36, 0.7, 0.96),
				"border": Color(0.34, 0.78, 1.0, 0.98),
				"shadow": Color(0.16, 0.62, 1.0, 0.56),
				"hover_bg": Color(0.08, 0.48, 0.9, 1.0),
				"hover_border": Color(0.58, 0.9, 1.0, 1.0),
				"hover_shadow": Color(0.26, 0.78, 1.0, 0.78),
				"font": Color(0.92, 0.98, 1.0, 1.0)
			}
		"metal":
			return {
				"bg": Color(0.42, 0.46, 0.5, 0.96),
				"border": Color(0.82, 0.88, 0.92, 0.98),
				"shadow": Color(0.76, 0.84, 0.9, 0.52),
				"hover_bg": Color(0.56, 0.62, 0.68, 1.0),
				"hover_border": Color(0.96, 0.98, 1.0, 1.0),
				"hover_shadow": Color(0.86, 0.92, 1.0, 0.72),
				"font": Color(0.98, 1.0, 1.0, 1.0)
			}
		_:
			return {}
func _apply_button_theme(btn: Button, theme_name: String, disabled: bool, option_data: Dictionary = {}) -> void:
	var normal:= StyleBoxFlat.new()
	var hover:= StyleBoxFlat.new()
	var stone_name: String = _resolve_stone_action_name(option_data)
	var stone_palette: Dictionary = _infinity_stone_button_palette(stone_name)
	var power_button_theme: bool = theme_name in ["nidavellir", "reality_fusion"]

	var is_stone_action: bool = power_button_theme and not stone_palette.is_empty()
	var bending_element: String = _resolve_bending_action_element(option_data)
	var bending_palette: Dictionary = _bending_button_palette(bending_element)
	var is_bending_action: bool = power_button_theme and not bending_palette.is_empty()
	var inventory_palette: Dictionary = _inventory_action_button_palette(option_data)
	var is_inventory_action: bool = power_button_theme and not inventory_palette.is_empty()
	if is_stone_action:
		normal.bg_color = stone_palette ["bg"]
		normal.border_color = stone_palette ["border"]
		normal.shadow_color = stone_palette ["shadow"]
		normal.shadow_size = 34
		hover.bg_color = stone_palette ["hover_bg"]
		hover.border_color = stone_palette ["hover_border"]
		hover.shadow_color = stone_palette ["hover_shadow"]
		hover.shadow_size = 44
		btn.add_theme_color_override("font_color", stone_palette ["font"])
		btn.add_theme_color_override("font_hover_color", stone_palette ["font"])
		btn.add_theme_color_override("font_pressed_color", stone_palette ["font"])
		btn.add_theme_color_override("font_focus_color", stone_palette ["font"])
		btn.add_theme_color_override("font_disabled_color", Color(stone_palette ["font"].r, stone_palette ["font"].g, stone_palette ["font"].b, 0.48))
	elif is_bending_action:
		normal.bg_color = bending_palette ["bg"]
		normal.border_color = bending_palette ["border"]
		normal.shadow_color = bending_palette ["shadow"]
		normal.shadow_size = 34
		hover.bg_color = bending_palette ["hover_bg"]
		hover.border_color = bending_palette ["hover_border"]
		hover.shadow_color = bending_palette ["hover_shadow"]
		hover.shadow_size = 44
		btn.add_theme_color_override("font_color", bending_palette ["font"])
		btn.add_theme_color_override("font_hover_color", bending_palette ["font"])
		btn.add_theme_color_override("font_pressed_color", bending_palette ["font"])
		btn.add_theme_color_override("font_focus_color", bending_palette ["font"])
		btn.add_theme_color_override("font_disabled_color", Color(bending_palette ["font"].r, bending_palette ["font"].g, bending_palette ["font"].b, 0.48))
	elif is_inventory_action:
		normal.bg_color = inventory_palette ["bg"]
		normal.border_color = inventory_palette ["border"]
		normal.shadow_color = inventory_palette ["shadow"]
		normal.shadow_size = 30
		hover.bg_color = inventory_palette ["hover_bg"]
		hover.border_color = inventory_palette ["hover_border"]
		hover.shadow_color = inventory_palette ["hover_shadow"]
		hover.shadow_size = 40
		btn.add_theme_color_override("font_color", inventory_palette ["font"])
		btn.add_theme_color_override("font_hover_color", inventory_palette ["font"])
		btn.add_theme_color_override("font_pressed_color", inventory_palette ["font"])
		btn.add_theme_color_override("font_focus_color", inventory_palette ["font"])
		btn.add_theme_color_override("font_disabled_color", Color(inventory_palette ["font"].r, inventory_palette ["font"].g, inventory_palette ["font"].b, 0.48))
	elif theme_name == "nidavellir":
		normal.bg_color = Color(0.58, 0.18, 0.72, 0.98)
		normal.border_color = Color(1.0, 0.8, 0.24, 0.98)
		normal.shadow_color = Color(1.0, 0.9, 0.24, 0.54)
		normal.shadow_size = 24
		hover.bg_color = Color(0.88, 0.26, 0.42, 1.0)
		hover.border_color = Color(1.0, 0.92, 0.3, 1.0)
		hover.shadow_color = Color(1.0, 0.96, 0.34, 0.72)
		hover.shadow_size = 30
		btn.add_theme_color_override("font_color", Color(1.0, 0.98, 0.94, 0.99))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.94, 0.99))
		btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.98, 0.94, 0.99))
		btn.add_theme_color_override("font_focus_color", Color(1.0, 0.98, 0.94, 0.99))
	else:
		normal.bg_color = Color(0.16, 0.16, 0.2, 0.96)
		normal.border_color = Color(1.0, 1.0, 1.0, 0.16)
		normal.shadow_color = Color(0.0, 0.0, 0.0, 0.12)
		normal.shadow_size = 12
		hover.bg_color = Color(0.24, 0.24, 0.3, 0.98)
		hover.border_color = Color(1.0, 1.0, 1.0, 0.22)
		hover.shadow_color = Color(0.0, 0.0, 0.0, 0.18)
		hover.shadow_size = 16
		btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.96))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 0.96))
		btn.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 0.96))
		btn.add_theme_color_override("font_focus_color", Color(1.0, 1.0, 1.0, 0.96))

	for style in [normal, hover]:
		style.border_width_left = 5 if is_stone_action or is_bending_action or is_inventory_action else 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.corner_radius_top_left = 12
		style.corner_radius_top_right = 12
		style.corner_radius_bottom_left = 12
		style.corner_radius_bottom_right = 12
		style.shadow_offset = Vector2.ZERO

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_stylebox_override("pressed", hover)

	var disabled_style:= normal.duplicate() as StyleBoxFlat
	disabled_style.bg_color = Color(
		normal.bg_color.r * 0.55,
		normal.bg_color.g * 0.55,
		normal.bg_color.b * 0.55,
		0.86
	)
	disabled_style.border_color = Color(
		normal.border_color.r,
		normal.border_color.g,
		normal.border_color.b,
		0.4
	)
	disabled_style.shadow_color = Color(0.0, 0.0, 0.0, 0.0)
	disabled_style.shadow_size = 0
	btn.add_theme_stylebox_override("disabled", disabled_style)
	btn.modulate = Color(1.0, 1.0, 1.0, 0.56 if disabled else 1.0)

func _gui_input(event) -> void:
	if not visible:
		return
	if event is InputEventMouseButton \
or event is InputEventMouseMotion \
or event is InputEventScreenTouch \
or event is InputEventScreenDrag \
or event is InputEventKey \
or event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()
func hide_panel() -> void:
	_stop_spectator_frames()
	_stop_idle_escalation()
	visible = false
	_clear_buttons()

func _clear_buttons() -> void:
	if buttons_box == null:
		return
	for child in buttons_box.get_children():
		child.queue_free()

func _build_panel_style(theme_name: String = "") -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	var bending_palette: Dictionary = _bending_theme_palette(theme_name)

	if not bending_palette.is_empty():
		style.bg_color = bending_palette ["bg"]
		style.border_color = bending_palette ["border"]
		style.shadow_color = bending_palette ["shadow"]
		style.shadow_size = 34 if theme_name == "bending_avatar" else 26
	elif theme_name == "nidavellir":
		style.bg_color = Color(0.16, 0.04, 0.2, 0.98)
		style.border_color = Color(1.0, 0.76, 0.22, 0.96)
		style.shadow_color = Color(0.84, 0.26, 1.0, 0.34)
		style.shadow_size = 28
	elif theme_name == "dragonball":
		style.bg_color = Color(0.08, 0.04, 0.0, 0.98)
		style.border_color = Color(1.0, 0.7, 0.18, 0.98)
		style.shadow_color = Color(1.0, 0.42, 0.04, 0.42)
		style.shadow_size = 34
	else:
		style.bg_color = Color(0.0, 0.0, 0.0, 0.94)
		style.border_color = Color(1.0, 1.0, 1.0, 0.14)
		style.shadow_color = Color(1.0, 1.0, 1.0, 0.1)
		style.shadow_size = 18

	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_right = 16
	style.corner_radius_bottom_left = 16
	style.shadow_offset = Vector2.ZERO
	return style