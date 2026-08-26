extends Control
class_name CrimePanel

signal close_requested
signal section_requested(
	section_id: String
)
signal action_requested(
	payload: Dictionary
)
signal person_requested(
	target_id: int,
	payload: Dictionary
)
const CRIME_TARGET_BLOOM_BATCH_SIZE:= 1
const CRIME_TARGET_VISUAL_DIM_BATCH_SIZE:= 8
const CRIME_TARGET_RETICLE_PULSE_BATCH_SIZE:= 8
const CRIME_TITLE_BASE_COLOR:= Color(
	1.0,
	0.18,
	0.22,
	1.0
)
const CRIME_TITLE_BREATHE_COLOR:= Color(
	1.0,
	0.34,
	0.38,
	1.0
)
const CRIME_TITLE_BREATHE_SECONDS:= 4.8
const CRIME_CLOSE_SPARKLE_COUNT:= 8
const CRIME_SECTION_REPAINTS_PER_QUANTUM:= 1
const CRIME_SECTION_REPAINT_BUDGET_USEC:= 600

var crime_section_repaint_queue: Dictionary = {}
var crime_section_repaint_queue_head: int = 0
var crime_section_repaint_queue_tail: int = 0
var crime_section_repaint_keys: Dictionary = {}
var crime_section_repaint_service_active: bool = false
var crime_section_repaint_generation: int = 0
var crime_target_bloom_queue: Array = []
var crime_target_bloom_service_active: bool = false
var crime_target_bloom_generation: int = 0
var crime_target_bloom_cursor: int = 0
var crime_visual_fx_elapsed: float = 0.0
var crime_close_sparkles: Array = []





var crime_target_card_by_id: Dictionary = {}
var crime_target_card_order: Array = []
var crime_target_visual_ack_target_id: int = -1
var crime_target_visual_generation: int = 0
var crime_target_visual_dim_cursor: int = 0
var crime_target_reticle_pulse_cursor: int = 0
var crime_target_reticle_pulse_time: float = 0.0


var crime_title_crime_label: Label = null
var crime_title_amp_left_label: Label = null
var crime_title_amp_right_label: Label = null
var crime_title_justice_label: Label = null
var crime_title_pulse_time: float = 0.0
var weapon_target_grid_by_section: Dictionary = {}
var weapon_body_surface_by_target_id: Dictionary = {}
var weapon_body_contract_by_target_id: Dictionary = {}
var weapon_target_section_by_target_id: Dictionary = {}
var active_weapon_target_id: int = -1
var active_contract: Dictionary = {}
var section_contract_cache: Dictionary = {}
var section_buttons: Dictionary = {}
var section_surface_nodes: Dictionary = {}
var dim: ColorRect
var card: PanelContainer
var title_label: Label
var subtitle_label: Label
var close_button: Button
var section_grid: GridContainer
var scroll: ScrollContainer
var list_root: VBoxContainer
var footer_label: Label

func _init() -> void:
	name = "CrimePanel"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 520
	set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)


func _ready() -> void:
	_ensure_surface()
	_install_crime_justice_title_presentation()
	_install_crime_visual_fx()
func _install_crime_visual_fx() -> void:
	if (
		title_label == null
		or close_button == null
		or section_grid == null
	):
		return

	title_label.add_theme_color_override(
		"font_color",
		CRIME_TITLE_BASE_COLOR
	)

	_bind_crime_navigation_button_motion(
		close_button,
		"close"
	)

	var tab_child_callback:= Callable(
		self,
		"_on_crime_section_grid_child_entered"
	)

	if not section_grid.is_connected(
		"child_entered_tree",
		tab_child_callback
	):
		section_grid.connect(
			"child_entered_tree",
			tab_child_callback
		)

	for child in section_grid.get_children():
		_on_crime_section_grid_child_entered(
			child
		)

	if crime_close_sparkles.is_empty():
		var sparkle_anchors: Array = [
			Vector2(0.02, 0.1),
			Vector2(0.34, -0.1),
			Vector2(0.72, -0.08),
			Vector2(0.98, 0.18),
			Vector2(1.02, 0.78),
			Vector2(0.68, 1.02),
			Vector2(0.28, 1.04),
			Vector2(-0.02, 0.66)
		]

		for index in range(
			min(
				CRIME_CLOSE_SPARKLE_COUNT,
				sparkle_anchors.size()
			)
		):
			var sparkle:= Label.new()
			sparkle.name = (
				"CrimeCloseSparkle_%d"
				% index
			)
			sparkle.text = "✦"
			sparkle.mouse_filter = Control.MOUSE_FILTER_IGNORE
			sparkle.custom_minimum_size = Vector2(
				12,
				12
			)
			sparkle.horizontal_alignment = (
				HORIZONTAL_ALIGNMENT_CENTER
			)
			sparkle.vertical_alignment = (
				VERTICAL_ALIGNMENT_CENTER
			)
			sparkle.add_theme_font_size_override(
				"font_size",
				12
			)
			sparkle.add_theme_color_override(
				"font_color",
				Color(
					1.0,
					0.52,
					0.58,
					1.0
				)
			)
			sparkle.set_meta(
				"crime_sparkle_anchor",
				sparkle_anchors [
					index
				]
			)
			sparkle.set_meta(
				"crime_sparkle_phase",
				float(index) / float(
					CRIME_CLOSE_SPARKLE_COUNT
				)
			)

			close_button.add_child(
				sparkle
			)
			crime_close_sparkles.append(
				sparkle
			)

	set_process(
		true
	)
func _configure_crime_title_label(
	label: Label,
	text: String
) -> void:
	label.text = text
	label.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)
	label.add_theme_font_size_override(
		"font_size",
		30
	)
	label.add_theme_constant_override(
		"shadow_offset_x",
		2
	)
	label.add_theme_constant_override(
		"shadow_offset_y",
		2
	)


func _install_crime_justice_title_presentation() -> void:
	if (
		title_label == null
		or subtitle_label == null
		or crime_title_crime_label != null
	):
		return

	var header_copy:= (
		title_label.get_parent()
		as VBoxContainer
	)

	if header_copy == null:
		return

	var header:= (
		header_copy.get_parent()
		as HBoxContainer
	)

	if header == null:
		return




	var balance_spacer:= Control.new()
	balance_spacer.name = "CrimeHeaderBalanceSpacer"
	balance_spacer.custom_minimum_size = Vector2(
		(
			close_button.custom_minimum_size.x
			if close_button != null
			else 110.0
		),
		48.0
	)
	balance_spacer.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	header.add_child(
		balance_spacer
	)
	header.move_child(
		balance_spacer,
		0
	)



	title_label.visible = false

	subtitle_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	var title_row:= HBoxContainer.new()
	title_row.name = "CrimeJusticeTitleRow"
	title_row.alignment = (
		BoxContainer.ALIGNMENT_CENTER
	)
	title_row.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	title_row.custom_minimum_size = Vector2(
		0.0,
		42.0
	)
	title_row.add_theme_constant_override(
		"separation",
		5
	)

	header_copy.add_child(
		title_row
	)
	header_copy.move_child(
		title_row,
		0
	)

	crime_title_crime_label = Label.new()
	_configure_crime_title_label(
		crime_title_crime_label,
		"CRIME"
	)
	title_row.add_child(
		crime_title_crime_label
	)





	var amp_root:= Control.new()
	amp_root.name = "CrimeJusticeSplitAmpersand"
	amp_root.custom_minimum_size = Vector2(
		34.0,
		42.0
	)
	amp_root.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	title_row.add_child(
		amp_root
	)

	var amp_left_clip:= Control.new()
	amp_left_clip.position = Vector2(
		0.0,
		0.0
	)
	amp_left_clip.size = Vector2(
		17.0,
		42.0
	)
	amp_left_clip.clip_contents = true
	amp_left_clip.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	amp_root.add_child(
		amp_left_clip
	)

	crime_title_amp_left_label = Label.new()
	_configure_crime_title_label(
		crime_title_amp_left_label,
		"&"
	)
	crime_title_amp_left_label.position = Vector2.ZERO
	crime_title_amp_left_label.size = Vector2(
		34.0,
		42.0
	)

	amp_left_clip.add_child(
		crime_title_amp_left_label
	)

	var amp_right_clip:= Control.new()
	amp_right_clip.position = Vector2(
		17.0,
		0.0
	)
	amp_right_clip.size = Vector2(
		17.0,
		42.0
	)
	amp_right_clip.clip_contents = true
	amp_right_clip.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	amp_root.add_child(
		amp_right_clip
	)

	crime_title_amp_right_label = Label.new()
	_configure_crime_title_label(
		crime_title_amp_right_label,
		"&"
	)
	crime_title_amp_right_label.position = Vector2(
		-17.0,
		0.0
	)
	crime_title_amp_right_label.size = Vector2(
		34.0,
		42.0
	)

	amp_right_clip.add_child(
		crime_title_amp_right_label
	)

	crime_title_justice_label = Label.new()
	_configure_crime_title_label(
		crime_title_justice_label,
		"JUSTICE"
	)

	title_row.add_child(
		crime_title_justice_label
	)

	_update_crime_justice_title_pulse()


func _update_crime_justice_title_pulse() -> void:
	if (
		crime_title_crime_label == null
		or crime_title_amp_left_label == null
		or crime_title_amp_right_label == null
		or crime_title_justice_label == null
	):
		return

	var breathe_seconds: float = maxf(
		CRIME_TITLE_BREATHE_SECONDS,
		0.001
	)

	var breathe_phase: float = (
		crime_title_pulse_time
		/ breathe_seconds
	) * TAU





	var breath: float = (
		0.5
		- 0.5 * cos(
			breathe_phase
		)
	)

	var bright_red:= Color(
		1.0,
		0.2,
		0.24,
		1.0
	)

	var dark_red:= Color(
		0.42,
		0.012,
		0.04,
		1.0
	)

	var bright_purple:= Color(
		0.86,
		0.68,
		1.0,
		1.0
	)

	var dark_purple:= Color(
		0.28,
		0.075,
		0.42,
		1.0
	)

	var crime_color: Color = (
		bright_red.lerp(
			dark_red,
			breath
		)
	)

	var justice_color: Color = (
		bright_purple.lerp(
			dark_purple,
			breath
		)
	)

	for red_label in [
		crime_title_crime_label,
		crime_title_amp_left_label
	]:
		red_label.add_theme_color_override(
			"font_color",
			crime_color
		)

		red_label.add_theme_color_override(
			"font_shadow_color",
			Color(
				crime_color.r,
				crime_color.g,
				crime_color.b,
				0.62
			)
		)

	for purple_label in [
		crime_title_amp_right_label,
		crime_title_justice_label
	]:
		purple_label.add_theme_color_override(
			"font_color",
			justice_color
		)

		purple_label.add_theme_color_override(
			"font_shadow_color",
			Color(
				justice_color.r,
				justice_color.g,
				justice_color.b,
				0.62
			)
		)
func _crime_target_interaction_stage() -> String:
	var target_surface: Dictionary = _shallow_dictionary(
		section_contract_cache.get(
			"targets",
			{}
		)
	)

	var interaction: Dictionary = _shallow_dictionary(
		target_surface.get(
			"interaction_contract",
			{}
		)
	)

	return str(
		interaction.get(
			"stage",
			""
		)
	).strip_edges().to_lower()


func _crime_target_selection_action_for_row(
	row: Dictionary,
	interaction_stage: String
) -> Dictionary:
	if interaction_stage == "choose_crime_target":
		var target_surface: Dictionary = _shallow_dictionary(
			section_contract_cache.get(
				"targets",
				{}
			)
		)
		var interaction: Dictionary = _shallow_dictionary(
			target_surface.get(
				"interaction_contract",
				{}
			)
		)
		var action_key: String = str(
			interaction.get(
				"target_action_key",
				"target_selection_action"
			)
		).strip_edges()

		if action_key == "":
			action_key = "target_selection_action"

		return _shallow_dictionary(
			row.get(
				action_key,
				{}
			)
		)

	if interaction_stage != "choose_target":
		return {}

	for raw_action in _safe_array(
		row.get(
			"actions",
			[]
		)
	):
		if typeof(raw_action) != TYPE_DICTIONARY:
			continue

		var action: Dictionary = (
			raw_action as Dictionary
		)

		if (
			str(
				action.get(
					"id",
					""
				)
			).strip_edges().to_lower()
			== "choose_weapon_target"
		):
			return action

	return {}


func _crime_target_targeting_state(
	row: Dictionary
) -> String:
	var interaction_stage: String = (
		_crime_target_interaction_stage()
	)

	if interaction_stage not in [
		"choose_crime_target",
		"choose_target"
	]:
		return "browse"

	var target_id: int = int(
		row.get(
			"target_id",
			-1
		)
	)

	if target_id <= 0:
		return "unavailable"

	var action: Dictionary = (
		_crime_target_selection_action_for_row(
			row,
			interaction_stage
		)
	)

	if (
		action.is_empty()
		or not bool(
			action.get(
				"enabled",
				true
			)
		)
	):
		return "unavailable"

	if target_id == crime_target_visual_ack_target_id:
		return "selected"

	var risk_tier: String = str(
		row.get(
			"risk_tier",
			row.get(
				"danger_label",
				""
			)
		)
	).strip_edges().to_lower()

	if (
		bool(
			row.get(
				"extreme_risk",
				false
			)
		)
		or risk_tier in [
			"extreme",
			"critical",
			"extreme risk"
		]
	):
		return "extreme_risk"

	return "eligible"


func _crime_target_reticle_color(
	state: String
) -> Color:
	match state:
		"unavailable":
			return Color(
				0.46,
				0.25,
				0.28,
				0.72
			)

		"extreme_risk":
			return Color(
				1.0,
				0.34,
				0.12,
				0.96
			)

		_:
			return Color(
				1.0,
				0.07,
				0.12,
				0.96
			)

func _queue_crime_section_surface_repaint(
	section_id: String
) -> void:
	var clean_section: String = str(
		section_id
	).strip_edges().to_lower()

	if clean_section == "":
		return

	if crime_section_repaint_keys.has(
		clean_section
	):



		if (
			crime_section_repaint_queue_head
			< crime_section_repaint_queue_tail
		):
			_arm_crime_section_repaint_service()
			return


		crime_section_repaint_keys.erase(
			clean_section
		)

	crime_section_repaint_keys [
		clean_section
	] = true

	var queue_slot: int = (
		crime_section_repaint_queue_tail
	)

	crime_section_repaint_queue_tail += 1

	crime_section_repaint_queue [
		queue_slot
	] = {
		"generation": crime_section_repaint_generation,
		"section_id": clean_section
	}

	_arm_crime_section_repaint_service()

func _arm_crime_section_repaint_service() -> void:
	if (
		crime_section_repaint_queue_head
		>= crime_section_repaint_queue_tail
	):
		return

	var tree:= Engine.get_main_loop() as SceneTree

	if tree == null:
		return

	var callback:= Callable(
		self,
		"_drive_crime_section_repaint_process_frame"
	)

	if tree.process_frame.is_connected(
		callback
	):
		crime_section_repaint_service_active = true
		return

	tree.process_frame.connect(
		callback
	)

	crime_section_repaint_service_active = true
func _drive_crime_section_repaint_process_frame() -> void:
	var tree:= Engine.get_main_loop() as SceneTree
	var callback:= Callable(
		self,
		"_drive_crime_section_repaint_process_frame"
	)

	if (
		crime_section_repaint_queue_head
		>= crime_section_repaint_queue_tail
	):
		if (
			tree != null
			and tree.process_frame.is_connected(
				callback
			)
		):
			tree.process_frame.disconnect(
				callback
			)

		crime_section_repaint_service_active = false
		return

	_service_crime_section_repaint_queue()

	if (
		crime_section_repaint_queue_head
		>= crime_section_repaint_queue_tail
	):
		if (
			tree != null
			and tree.process_frame.is_connected(
				callback
			)
		):
			tree.process_frame.disconnect(
				callback
			)

		crime_section_repaint_service_active = false
	else:
		crime_section_repaint_service_active = true

func _service_crime_section_repaint_queue() -> void:
	crime_section_repaint_service_active = false

	var started_usec: int = int(
		Time.get_ticks_usec()
	)

	var repainted: int = 0

	while (
		crime_section_repaint_queue_head
			< crime_section_repaint_queue_tail
		and repainted
			< CRIME_SECTION_REPAINTS_PER_QUANTUM
		and int(
			Time.get_ticks_usec()
		) - started_usec
			< CRIME_SECTION_REPAINT_BUDGET_USEC
	):
		var queue_slot: int = (
			crime_section_repaint_queue_head
		)

		crime_section_repaint_queue_head += 1

		var request_raw: Variant = (
			crime_section_repaint_queue.get(
				queue_slot,
				{}
			)
		)

		crime_section_repaint_queue.erase(
			queue_slot
		)

		if typeof(request_raw) != TYPE_DICTIONARY:
			continue

		var request: Dictionary = (
			request_raw as Dictionary
		)
		var section_id: String = str(
			request.get(
				"section_id",
				""
			)
		).strip_edges().to_lower()



		if section_id != "":
			crime_section_repaint_keys.erase(
				section_id
			)

		if int(
			request.get(
				"generation",
				-1
			)
		) != crime_section_repaint_generation:
			continue

		if section_id == "":
			continue

		var resident_surface: VBoxContainer = (
			section_surface_nodes.get(
				section_id,
				null
			) as VBoxContainer
		)

		if (
			resident_surface == null
			or not is_instance_valid(
				resident_surface
			)
		):




			if section_buttons.has(
				section_id
			):
				_queue_crime_section_surface_repaint(
					section_id
				)
				break

			continue

		var section_contract: Dictionary = _shallow_dictionary(
			section_contract_cache.get(
				section_id,
				{}
			)
		)

		_paint_crime_section_surface(
			section_id,
			resident_surface,
			section_contract
		)

		repainted += 1

	if (
		crime_section_repaint_queue_head
		>= crime_section_repaint_queue_tail
	):
		crime_section_repaint_queue.clear()
		crime_section_repaint_queue_head = 0
		crime_section_repaint_queue_tail = 0
		return

	_arm_crime_section_repaint_service()
func _build_crime_target_reticle(
	card_control: PanelContainer,
	row: Dictionary
) -> void:
	if (
		card_control == null
		or not is_instance_valid(
			card_control
		)
		or card_control.has_meta(
			"crime_target_reticle_overlay"
		)
	):
		return
	var overlay:= Control.new()
	overlay.name = "CrimeTargetReticleOverlay"
	overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	overlay.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	overlay.z_as_relative = true
	overlay.z_index = 20
	overlay.visible = false
	card_control.add_child(
		overlay
	)
	var frame:= Control.new()
	frame.name = "CrimeTargetReticleFrame"
	frame.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	frame.offset_left = 10.0
	frame.offset_top = 10.0
	frame.offset_right = -10.0
	frame.offset_bottom = -10.0
	frame.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	overlay.add_child(
		frame
	)
	var corner_specs: Array = [
		{
			"text": "⌜",
			"preset": Control.PRESET_TOP_LEFT,
			"left": 0.0,
			"top": 0.0,
			"right": 30.0,
			"bottom": 30.0
		},
		{
			"text": "⌝",
			"preset": Control.PRESET_TOP_RIGHT,
			"left": -30.0,
			"top": 0.0,
			"right": 0.0,
			"bottom": 30.0
		},
		{
			"text": "⌞",
			"preset": Control.PRESET_BOTTOM_LEFT,
			"left": 0.0,
			"top": -30.0,
			"right": 30.0,
			"bottom": 0.0
		},
		{
			"text": "⌟",
			"preset": Control.PRESET_BOTTOM_RIGHT,
			"left": -30.0,
			"top": -30.0,
			"right": 0.0,
			"bottom": 0.0
		}
	]
	var corner_labels: Array = []
	for raw_spec in corner_specs:
		var spec: Dictionary = _shallow_dictionary(
			raw_spec
		)
		var corner:= Label.new()
		corner.text = str(
			spec.get(
				"text",
				""
			)
		)
		corner.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)
		corner.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_CENTER
		)
		corner.vertical_alignment = (
			VERTICAL_ALIGNMENT_CENTER
		)
		corner.add_theme_font_size_override(
			"font_size",
			24
		)
		corner.set_anchors_preset(
			int(
				spec.get(
					"preset",
					Control.PRESET_TOP_LEFT
				)
			)
		)
		corner.offset_left = float(
			spec.get(
				"left",
				0.0
			)
		)
		corner.offset_top = float(
			spec.get(
				"top",
				0.0
			)
		)
		corner.offset_right = float(
			spec.get(
				"right",
				30.0
			)
		)
		corner.offset_bottom = float(
			spec.get(
				"bottom",
				30.0
			)
		)
		frame.add_child(
			corner
		)
		corner_labels.append(
			corner
		)





	var center_root:= Control.new()
	center_root.name = "CrimeTargetCenterReticle"
	center_root.set_anchors_preset(
		Control.PRESET_CENTER
	)
	center_root.offset_left = -28.0
	center_root.offset_top = -28.0
	center_root.offset_right = 28.0
	center_root.offset_bottom = 28.0
	center_root.pivot_offset = Vector2(
		28.0,
		28.0
	)
	center_root.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	overlay.add_child(
		center_root
	)

	var center_left_clip:= Control.new()
	center_left_clip.name = "CrimeTargetCenterLeftClip"
	center_left_clip.position = Vector2.ZERO
	center_left_clip.size = Vector2(
		28.0,
		56.0
	)
	center_left_clip.clip_contents = true
	center_left_clip.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	center_root.add_child(
		center_left_clip
	)

	var center_left:= Label.new()
	center_left.name = "CrimeTargetCenterLeft"
	center_left.text = "◎"
	center_left.position = Vector2.ZERO
	center_left.size = Vector2(
		56.0,
		56.0
	)
	center_left.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	center_left.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)
	center_left.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	center_left.add_theme_font_size_override(
		"font_size",
		34
	)
	center_left_clip.add_child(
		center_left
	)

	var center_right_clip:= Control.new()
	center_right_clip.name = "CrimeTargetCenterRightClip"
	center_right_clip.position = Vector2(
		28.0,
		0.0
	)
	center_right_clip.size = Vector2(
		28.0,
		56.0
	)
	center_right_clip.clip_contents = true
	center_right_clip.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	center_root.add_child(
		center_right_clip
	)

	var center_right:= Label.new()
	center_right.name = "CrimeTargetCenterRight"
	center_right.text = "◎"
	center_right.position = Vector2(
		-28.0,
		0.0
	)
	center_right.size = Vector2(
		56.0,
		56.0
	)
	center_right.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	center_right.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)
	center_right.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	center_right.add_theme_font_size_override(
		"font_size",
		34
	)
	center_right_clip.add_child(
		center_right
	)

	card_control.set_meta(
		"crime_target_reticle_overlay",
		overlay
	)
	card_control.set_meta(
		"crime_target_reticle_frame",
		frame
	)
	card_control.set_meta(
		"crime_target_reticle_center",
		center_root
	)
	card_control.set_meta(
		"crime_target_reticle_center_left",
		center_left
	)
	card_control.set_meta(
		"crime_target_reticle_center_right",
		center_right
	)
	card_control.set_meta(
		"crime_target_reticle_corners",
		corner_labels
	)
	card_control.set_meta(
		"crime_target_row_contract",
		row.duplicate(false)
	)
	card_control.set_meta(
		"crime_target_reticle_hovered",
		false
	)
	_refresh_crime_target_reticle(
		card_control,
		row,
		false
	)
func _kill_crime_target_reticle_tween(
	frame: Control
) -> void:
	if (
		frame == null
		or not is_instance_valid(
			frame
		)
	):
		return

	var tween_meta_key: StringName = (
		"crime_target_reticle_motion_tween"
	)

	if not frame.has_meta(
		tween_meta_key
	):
		return

	var tween_raw: Variant = frame.get_meta(
		tween_meta_key,
		null
	)

	frame.remove_meta(
		tween_meta_key
	)

	if tween_raw is Tween:
		var tween: Tween = tween_raw as Tween

		if tween.is_valid():
			tween.kill()


func _refresh_crime_target_reticle(
	card_control: PanelContainer,
	row: Dictionary,
	hovered: bool
) -> void:
	if (
		card_control == null
		or not is_instance_valid(
			card_control
		)
		or not card_control.has_meta(
			"crime_target_reticle_overlay"
		)
	):
		return

	var overlay:= card_control.get_meta(
		"crime_target_reticle_overlay",
		null
	) as Control
	var frame:= card_control.get_meta(
		"crime_target_reticle_frame",
		null
	) as Control
	var center_root:= card_control.get_meta(
		"crime_target_reticle_center",
		null
	) as Control
	var center_left:= card_control.get_meta(
		"crime_target_reticle_center_left",
		null
	) as Label
	var center_right:= card_control.get_meta(
		"crime_target_reticle_center_right",
		null
	) as Label

	if (
		overlay == null
		or frame == null
		or center_root == null
		or center_left == null
		or center_right == null
		or not is_instance_valid(
			overlay
		)
		or not is_instance_valid(
			frame
		)
		or not is_instance_valid(
			center_root
		)
		or not is_instance_valid(
			center_left
		)
		or not is_instance_valid(
			center_right
		)
	):
		return

	card_control.set_meta(
		"crime_target_reticle_hovered",
		hovered
	)

	var state: String = (
		_crime_target_targeting_state(
			row
		)
	)

	if state == "browse":
		overlay.visible = false
		center_root.scale = Vector2.ONE
		center_root.rotation = 0.0
		center_root.modulate = Color.WHITE
		card_control.self_modulate = Color(
			1.0,
			1.0,
			1.0,
			1.0
		)
		return

	overlay.visible = true

	var reticle_color: Color = (
		_crime_target_reticle_color(
			state
		)
	)


	var justice_reticle_color:= Color(
		0.86,
		0.68,
		1.0,
		reticle_color.a
	)

	var reticle_text: String = "◎"

	match state:
		"selected":
			reticle_text = "●"

		"unavailable":
			reticle_text = "✕"

		"extreme_risk":
			reticle_text = "⚠"

		_:
			reticle_text = (
				"⊕"
				if hovered
				else "◎"
			)

	center_left.text = reticle_text
	center_right.text = reticle_text

	center_left.add_theme_color_override(
		"font_color",
		reticle_color
	)
	center_right.add_theme_color_override(
		"font_color",
		(
			justice_reticle_color
			if (
				hovered
				and state != "unavailable"
			)
			else reticle_color
		)
	)

	if state != "unavailable":
		center_root.rotation = 0.0

	if not hovered:
		center_root.scale = Vector2.ONE
		center_root.modulate = Color.WHITE

	var corners_raw: Variant = card_control.get_meta(
		"crime_target_reticle_corners",
		[]
	)

	if typeof(corners_raw) == TYPE_ARRAY:
		var corners: Array = (
			corners_raw as Array
		)

		for corner_index in range(
			corners.size()
		):
			var corner: Label = (
				corners [
					corner_index
				] as Label
			)

			if (
				corner == null
				or not is_instance_valid(
					corner
				)
			):
				continue

			var corner_color: Color = (
				reticle_color
			)








			if (
				hovered
				and state != "unavailable"
				and corner_index in [
					1,
					3
				]
			):
				corner_color = (
					justice_reticle_color
				)

			corner.add_theme_color_override(
				"font_color",
				corner_color
			)

	var target_inset: float = 10.0

	if hovered:
		target_inset = 18.0
	elif state == "selected":
		target_inset = 15.0

	_kill_crime_target_reticle_tween(
		frame
	)

	var tween:= frame.create_tween()

	tween.set_parallel(
		true
	)
	tween.set_trans(
		Tween.TRANS_QUAD
	)
	tween.set_ease(
		Tween.EASE_OUT
	)
	tween.tween_property(
		frame,
		"offset_left",
		target_inset,
		0.1
	)
	tween.tween_property(
		frame,
		"offset_top",
		target_inset,
		0.1
	)
	tween.tween_property(
		frame,
		"offset_right",
		- target_inset,
		0.1
	)
	tween.tween_property(
		frame,
		"offset_bottom",
		- target_inset,
		0.1
	)

	frame.set_meta(
		"crime_target_reticle_motion_tween",
		tween
	)
func _register_crime_target_card_presentation(
	card_control: PanelContainer,
	row: Dictionary
) -> void:
	if (
		card_control == null
		or not is_instance_valid(
			card_control
		)
	):
		return

	var target_id: int = int(
		row.get(
			"target_id",
			-1
		)
	)

	if target_id <= 0:
		return

	var target_key: String = str(
		target_id
	)

	var previous_card: PanelContainer = (
		crime_target_card_by_id.get(
			target_key,
			null
		) as PanelContainer
	)

	if (
		previous_card != null
		and previous_card != card_control
		and is_instance_valid(
			previous_card
		)
	):
		previous_card.queue_free()

	crime_target_card_by_id [
		target_key
	] = card_control

	if target_id not in crime_target_card_order:
		crime_target_card_order.append(
			target_id
		)

	_build_crime_target_reticle(
		card_control,
		row
	)

	_apply_crime_target_visual_ack_to_card(
		card_control,
		row
	)


func _apply_crime_target_visual_ack_to_card(
	card_control: PanelContainer,
	row: Dictionary
) -> void:
	if (
		card_control == null
		or not is_instance_valid(
			card_control
		)
	):
		return

	var target_id: int = int(
		row.get(
			"target_id",
			-1
		)
	)

	var selected: bool = (
		crime_target_visual_ack_target_id > 0
		and target_id == crime_target_visual_ack_target_id
	)

	var another_selected: bool = (
		crime_target_visual_ack_target_id > 0
		and target_id != crime_target_visual_ack_target_id
	)

	card_control.self_modulate = Color(
		1.0,
		1.0,
		1.0,
		(
			0.66
			if another_selected
			else 1.0
		)
	)

	_refresh_crime_target_reticle(
		card_control,
		row,
		bool(
			card_control.get_meta(
				"crime_target_reticle_hovered",
				false
			)
		)
	)

	if selected:
		card_control.move_to_front()


func _acknowledge_crime_target_visual_selection(
	target_id: int
) -> void:
	if target_id <= 0:
		return

	crime_target_visual_ack_target_id = target_id
	crime_target_visual_generation += 1
	crime_target_visual_dim_cursor = 0

	var target_key: String = str(
		target_id
	)

	var selected_card: PanelContainer = (
		crime_target_card_by_id.get(
			target_key,
			null
		) as PanelContainer
	)

	if (
		selected_card != null
		and is_instance_valid(
			selected_card
		)
	):
		var row: Dictionary = _shallow_dictionary(
			selected_card.get_meta(
				"crime_target_row_contract",
				{}
			)
		)

		_apply_crime_target_visual_ack_to_card(
			selected_card,
			row
		)

	_arm_crime_target_visual_dim_service(
		crime_target_visual_generation
	)


func _arm_crime_target_visual_dim_service(
	generation: int
) -> void:
	var tree:= Engine.get_main_loop() as SceneTree

	if tree == null:
		return

	tree.process_frame.connect(
		Callable(
			self,
			"_service_crime_target_visual_dim"
		).bind(
			generation
		),
		CONNECT_ONE_SHOT | CONNECT_DEFERRED
	)

func _service_crime_target_visual_dim(
	generation: int
) -> void:
	if generation != crime_target_visual_generation:
		return

	var serviced: int = 0

	while (
		crime_target_visual_dim_cursor
		< crime_target_card_order.size()
		and serviced
		< CRIME_TARGET_VISUAL_DIM_BATCH_SIZE
	):
		var target_id: int = int(
			crime_target_card_order [
				crime_target_visual_dim_cursor
			]
		)

		crime_target_visual_dim_cursor += 1
		serviced += 1

		var card_control: PanelContainer = (
			crime_target_card_by_id.get(
				str(
					target_id
				),
				null
			) as PanelContainer
		)

		if (
			card_control == null
			or not is_instance_valid(
				card_control
			)
		):
			continue

		var row: Dictionary = _shallow_dictionary(
			card_control.get_meta(
				"crime_target_row_contract",
				{}
			)
		)

		_apply_crime_target_visual_ack_to_card(
			card_control,
			row
		)

	if (
		crime_target_visual_dim_cursor
		>= crime_target_card_order.size()
	):
		return

	_arm_crime_target_visual_dim_service(
		generation
	)


func _service_crime_target_reticle_pulse_quantum() -> void:
	if crime_target_card_order.is_empty():
		crime_target_reticle_pulse_cursor = 0
		return

	var serviced: int = 0

	while serviced < CRIME_TARGET_RETICLE_PULSE_BATCH_SIZE:
		if (
			crime_target_reticle_pulse_cursor
			>= crime_target_card_order.size()
		):
			crime_target_reticle_pulse_cursor = 0
			break

		var target_id: int = int(
			crime_target_card_order [
				crime_target_reticle_pulse_cursor
			]
		)

		crime_target_reticle_pulse_cursor += 1
		serviced += 1

		var card_control: PanelContainer = (
			crime_target_card_by_id.get(
				str(
					target_id
				),
				null
			) as PanelContainer
		)

		if (
			card_control == null
			or not is_instance_valid(
				card_control
			)
			or not card_control.has_meta(
				"crime_target_reticle_overlay"
			)
		):
			continue

		var overlay:= card_control.get_meta(
			"crime_target_reticle_overlay",
			null
		) as Control

		if (
			overlay == null
			or not is_instance_valid(
				overlay
			)
			or not overlay.visible
		):
			continue

		var center_root:= card_control.get_meta(
			"crime_target_reticle_center",
			null
		) as Control

		var hovered: bool = bool(
			card_control.get_meta(
				"crime_target_reticle_hovered",
				false
			)
		)

		var row: Dictionary = _shallow_dictionary(
			card_control.get_meta(
				"crime_target_row_contract",
				{}
			)
		)

		var state: String = (
			_crime_target_targeting_state(
				row
			)
		)

		var breath: float = (
			0.5
			+ 0.5 * sin(
				crime_target_reticle_pulse_time
				* 2.15
			)
		)




		if state == "unavailable":
			overlay.modulate.a = (
				1.0
				if hovered
				else lerpf(
					0.58,
					0.88,
					breath
				)
			)

			if (
				center_root != null
				and is_instance_valid(
					center_root
				)
			):
				var unavailable_scale: float = lerpf(
					0.92,
					1.07,
					breath
				)

				center_root.scale = Vector2(
					unavailable_scale,
					unavailable_scale
				)
				center_root.rotation = lerpf(
					-0.09,
					0.09,
					breath
				)
				center_root.modulate.a = lerpf(
					0.76,
					1.0,
					breath
				)

			continue

		if (
			center_root != null
			and is_instance_valid(
				center_root
			)
		):
			center_root.rotation = 0.0

		if hovered:
			overlay.modulate.a = 1.0

			if (
				center_root != null
				and is_instance_valid(
					center_root
				)
			):
				var center_scale: float = lerpf(
					0.975,
					1.035,
					breath
				)

				center_root.scale = Vector2(
					center_scale,
					center_scale
				)
				center_root.modulate.a = lerpf(
					0.9,
					1.0,
					breath
				)

			continue

		if state == "selected":
			overlay.modulate.a = 1.0

			if (
				center_root != null
				and is_instance_valid(
					center_root
				)
			):
				center_root.scale = Vector2.ONE
				center_root.rotation = 0.0
				center_root.modulate = Color.WHITE

			continue

		if (
			center_root != null
			and is_instance_valid(
				center_root
			)
		):
			center_root.scale = Vector2.ONE
			center_root.rotation = 0.0
			center_root.modulate = Color.WHITE

		overlay.modulate.a = lerpf(
			0.42,
			0.62,
			breath
		)
func _on_crime_section_grid_child_entered(
	node: Node
) -> void:
	if not (node is Button):
		return

	_bind_crime_navigation_button_motion(
		node as Button,
		"tab"
	)


func _bind_crime_navigation_button_motion(
	button: Button,
	motion_kind: String
) -> void:
	if (
		button == null
		or not is_instance_valid(button)
		or bool(
			button.get_meta(
				"crime_navigation_motion_bound",
				false
			)
		)
	):
		return

	button.set_meta(
		"crime_navigation_motion_bound",
		true
	)
	button.set_meta(
		"crime_navigation_motion_kind",
		motion_kind
	)

	button.mouse_entered.connect(
		Callable(
			self,
			"_on_crime_navigation_hover_changed"
		).bind(
			button,
			true
		)
	)
	button.mouse_exited.connect(
		Callable(
			self,
			"_on_crime_navigation_hover_changed"
		).bind(
			button,
			false
		)
	)
	button.button_down.connect(
		Callable(
			self,
			"_on_crime_navigation_button_down"
		).bind(
			button
		)
	)
	button.button_up.connect(
		Callable(
			self,
			"_on_crime_navigation_button_up"
		).bind(
			button
		)
	)


func _kill_crime_navigation_tween(
	button: Button
) -> void:
	if (
		button == null
		or not is_instance_valid(button)
	):
		return

	const tween_meta_key: StringName = "crime_navigation_motion_tween"

	if not button.has_meta(
		tween_meta_key
	):
		return

	var tween_raw: Variant = button.get_meta(
		tween_meta_key,
		null
	)

	button.remove_meta(
		tween_meta_key
	)

	if tween_raw is Tween:
		var tween: Tween = tween_raw as Tween

		if tween.is_valid():
			tween.kill()

func _on_crime_navigation_hover_changed(
	button: Button,
	hovered: bool
) -> void:
	if (
		button == null
		or not is_instance_valid(button)
	):
		return

	button.set_meta(
		"crime_navigation_hovered",
		hovered
	)

	_kill_crime_navigation_tween(
		button
	)

	button.pivot_offset = button.size * 0.5

	var target_scale: Vector2 = (
		Vector2(
			1.026,
			1.026
		)
		if hovered
		else Vector2.ONE
	)

	var tween: Tween = button.create_tween()
	tween.set_trans(
		Tween.TRANS_QUAD
	)
	tween.set_ease(
		Tween.EASE_OUT
	)
	tween.tween_property(
		button,
		"scale",
		target_scale,
		0.11
	)

	button.set_meta(
		"crime_navigation_motion_tween",
		tween
	)


func _on_crime_navigation_button_down(
	button: Button
) -> void:
	if (
		button == null
		or not is_instance_valid(button)
	):
		return

	_kill_crime_navigation_tween(
		button
	)

	button.pivot_offset = button.size * 0.5

	var tween: Tween = button.create_tween()
	tween.set_trans(
		Tween.TRANS_QUAD
	)
	tween.set_ease(
		Tween.EASE_OUT
	)
	tween.tween_property(
		button,
		"scale",
		Vector2(
			0.965,
			0.965
		),
		0.065
	)

	button.set_meta(
		"crime_navigation_motion_tween",
		tween
	)


func _on_crime_navigation_button_up(
	button: Button
) -> void:
	if (
		button == null
		or not is_instance_valid(button)
	):
		return

	_kill_crime_navigation_tween(
		button
	)

	button.pivot_offset = button.size * 0.5

	var resting_scale: Vector2 = (
		Vector2(
			1.026,
			1.026
		)
		if bool(
			button.get_meta(
				"crime_navigation_hovered",
				false
			)
		)
		else Vector2.ONE
	)

	var tween: Tween = button.create_tween()
	tween.set_trans(
		Tween.TRANS_BACK
	)
	tween.set_ease(
		Tween.EASE_OUT
	)
	tween.tween_property(
		button,
		"scale",
		Vector2(
			1.055,
			1.055
		),
		0.085
	)
	tween.tween_property(
		button,
		"scale",
		resting_scale,
		0.12
	)

	button.set_meta(
		"crime_navigation_motion_tween",
		tween
	)


func _process(
	delta: float
) -> void:
	if not is_visible_in_tree():
		return

	var frame_delta: float = maxf(
		delta,
		0.0
	)

	crime_visual_fx_elapsed = fmod(
		crime_visual_fx_elapsed + frame_delta,
		60.0
	)

	crime_title_pulse_time = fmod(
		crime_title_pulse_time + frame_delta,
		maxf(
			CRIME_TITLE_BREATHE_SECONDS,
			0.001
		)
	)

	crime_target_reticle_pulse_time = fmod(
		crime_target_reticle_pulse_time + frame_delta,
		TAU * 4.0
	)




	_update_crime_justice_title_pulse()
	_service_crime_target_reticle_pulse_quantum()

	if (
		close_button == null
		or not is_instance_valid(close_button)
	):
		return

	for raw_sparkle in crime_close_sparkles:
		var sparkle: Label = raw_sparkle as Label

		if (
			sparkle == null
			or not is_instance_valid(sparkle)
		):
			continue

		var anchor_raw: Variant = sparkle.get_meta(
			"crime_sparkle_anchor",
			Vector2.ZERO
		)
		var anchor: Vector2 = (
			anchor_raw
			if typeof(anchor_raw) == TYPE_VECTOR2
			else Vector2.ZERO
		)
		var phase_offset: float = float(
			sparkle.get_meta(
				"crime_sparkle_phase",
				0.0
			)
		) * TAU

		var glint: float = (
			0.5
			+ 0.5 * sin(
				crime_visual_fx_elapsed * 2.4
				+ phase_offset
			)
		)

		var drift:= Vector2(
			sin(
				crime_visual_fx_elapsed * 1.7
				+ phase_offset
			),
			cos(
				crime_visual_fx_elapsed * 1.5
				+ phase_offset
			)
		) * 2.5

		sparkle.position = Vector2(
			close_button.size.x * anchor.x,
			close_button.size.y * anchor.y
		) + drift - sparkle.size * 0.5

		sparkle.scale = Vector2.ONE * lerpf(
			0.72,
			1.18,
			glint
		)

		sparkle.modulate = Color(
			1.0,
			1.0,
			1.0,
			lerpf(
				0.16,
				0.96,
				glint
			)
		)
func _crime_section_surface_projection_rank(
	surface: Dictionary
) -> int:
	if surface.is_empty():
		return 0

	var truth_state: String = str(
		surface.get(
			"truth_state",
			""
		)
	).strip_edges().to_lower()

	var hydrated: bool = bool(
		surface.get(
			"hydrated",
			false
		)
	)

	var projection_pending: bool = bool(
		surface.get(
			"projection_pending",
			false
		)
	)

	if truth_state == "hot" and hydrated:
		return (
			2
			if projection_pending
			else 3
		)

	if (
		truth_state in [
			"resident_shell",
			"renderer_chassis"
		]
		or projection_pending
	):
		return 1

	return 1


func _crime_section_surface_revision_ms(
	surface: Dictionary
) -> int:
	if surface.is_empty():
		return 0

	var revision_ms: int = 0

	for raw_key in [
		"updated_at_ms",
		"published_at_ms",
		"built_at_ms",
		"generated_at_ms",
		"dirty_at_ms"
	]:
		revision_ms = maxi(
			revision_ms,
			int(
				surface.get(
					raw_key,
					0
				)
			)
		)

	return revision_ms


func _crime_section_interaction_stage(
	surface: Dictionary
) -> String:
	var interaction: Dictionary = _shallow_dictionary(
		surface.get(
			"interaction_contract",
			{}
		)
	)

	return str(
		surface.get(
			"interaction_stage",
			interaction.get(
				"stage",
				""
			)
		)
	).strip_edges().to_lower()


func _should_adopt_crime_section_surface(
	existing_surface: Dictionary,
	incoming_surface: Dictionary
) -> bool:
	if incoming_surface.is_empty():
		return false

	if existing_surface.is_empty():
		return true

	var existing_actor_id: int = int(
		existing_surface.get(
			"actor_id",
			-1
		)
	)
	var incoming_actor_id: int = int(
		incoming_surface.get(
			"actor_id",
			-1
		)
	)

	if (
		existing_actor_id > 0
		and incoming_actor_id > 0
		and existing_actor_id != incoming_actor_id
	):
		return true

	var existing_stage: String = (
		_crime_section_interaction_stage(
			existing_surface
		)
	)
	var incoming_stage: String = (
		_crime_section_interaction_stage(
			incoming_surface
		)
	)
	var existing_interaction_has_sovereignty: bool = (
		existing_stage in [
			"choose_target",
			"choose_body_part",
			"choose_crime_target"
		]
	)
	var incoming_interaction_has_sovereignty: bool = (
		incoming_stage in [
			"choose_target",
			"choose_body_part",
			"choose_crime_target"
		]
	)



	if (
		existing_interaction_has_sovereignty
		and not incoming_interaction_has_sovereignty
	):
		return false





	if (
		incoming_interaction_has_sovereignty
		and not existing_interaction_has_sovereignty
	):
		return true

	var existing_rank: int = (
		_crime_section_surface_projection_rank(
			existing_surface
		)
	)
	var incoming_rank: int = (
		_crime_section_surface_projection_rank(
			incoming_surface
		)
	)

	if incoming_rank != existing_rank:
		return incoming_rank > existing_rank

	var existing_revision_ms: int = (
		_crime_section_surface_revision_ms(
			existing_surface
		)
	)
	var incoming_revision_ms: int = (
		_crime_section_surface_revision_ms(
			incoming_surface
		)
	)

	if (
		existing_revision_ms > 0
		and incoming_revision_ms <= 0
	):
		return false

	return incoming_revision_ms >= existing_revision_ms


func _crime_section_scaffold_matches(
	tabs: Array
) -> bool:
	if (
		section_grid == null
		or list_root == null
		or tabs.is_empty()
		or section_buttons.size() != tabs.size()
		or section_surface_nodes.size() != tabs.size()
	):
		return false

	for raw_tab in tabs:
		if typeof(raw_tab) != TYPE_DICTIONARY:
			return false

		var tab: Dictionary = raw_tab as Dictionary
		var section_id: String = str(
			tab.get(
				"id",
				""
			)
		).strip_edges().to_lower()

		if (
			section_id == ""
			or not section_buttons.has(section_id)
			or not section_surface_nodes.has(section_id)
		):
			return false

		var button: Button = section_buttons.get(
			section_id,
			null
		) as Button

		var surface: VBoxContainer = section_surface_nodes.get(
			section_id,
			null
		) as VBoxContainer

		if (
			button == null
			or surface == null
			or not is_instance_valid(button)
			or not is_instance_valid(surface)
		):
			return false

	return true


func _invalidate_crime_target_bloom_projection() -> void:
	crime_target_bloom_generation += 1
	crime_target_bloom_queue.clear()
	weapon_target_grid_by_section.clear()
	weapon_body_surface_by_target_id.clear()
	weapon_body_contract_by_target_id.clear()
	weapon_target_section_by_target_id.clear()
	active_weapon_target_id = -1


func render_contract(
	contract: Dictionary
) -> void:
	if contract.is_empty():
		return

	var install_hidden: bool = bool(
		contract.get(
			"install_hidden",
			false
		)
	)

	var incoming_contract: Dictionary = (
		contract.duplicate(false)
	)

	var previous_actor_id: int = int(
		active_contract.get(
			"actor_id",
			-1
		)
	)
	var incoming_actor_id: int = int(
		incoming_contract.get(
			"actor_id",
			-1
		)
	)

	var same_actor: bool = (
		previous_actor_id > 0
		and incoming_actor_id > 0
		and previous_actor_id == incoming_actor_id
	)
	var actor_changed: bool = (
		previous_actor_id > 0
		and incoming_actor_id > 0
		and previous_actor_id != incoming_actor_id
	)

	var previous_active_section: String = str(
		active_contract.get(
			"active_section",
			""
		)
	).strip_edges().to_lower()

	if actor_changed:
		section_contract_cache.clear()

	var adopted_sections: Array = []

	var surfaces_raw: Variant = incoming_contract.get(
		"section_surfaces",
		{}
	)

	if typeof(surfaces_raw) == TYPE_DICTIONARY:
		var surfaces: Dictionary = (
			surfaces_raw as Dictionary
		)

		for raw_section_id in surfaces.keys():
			var section_id: String = str(
				raw_section_id
			).strip_edges().to_lower()

			var surface_raw: Variant = surfaces.get(
				raw_section_id,
				{}
			)

			if (
				section_id == ""
				or typeof(surface_raw) != TYPE_DICTIONARY
			):
				continue

			var incoming_surface: Dictionary = (
				(surface_raw as Dictionary).duplicate(false)
			)
			var existing_surface: Dictionary = _shallow_dictionary(
				section_contract_cache.get(
					section_id,
					{}
				)
			)

			if not _should_adopt_crime_section_surface(
				existing_surface,
				incoming_surface
			):
				continue

			section_contract_cache [
				section_id
			] = incoming_surface

			adopted_sections.append(
				section_id
			)

	var active_section: String = str(
		incoming_contract.get(
			"active_section",
			"overview"
		)
	).strip_edges().to_lower()

	if active_section == "":
		active_section = "overview"



	if (
		same_actor
		and install_hidden
		and previous_active_section != ""
		and section_contract_cache.has(
			previous_active_section
		)
	):
		active_section = previous_active_section

	if not section_contract_cache.has(
		active_section
	):
		var top_level_hot: bool = (
			str(
				incoming_contract.get(
					"truth_state",
					""
				)
			) == "hot"
			and bool(
				incoming_contract.get(
					"hydrated",
					false
				)
			)
		)

		var fallback_surface: Dictionary = {
			"actor_id": incoming_actor_id,
			"section_id": active_section,
			"section_rows": incoming_contract.get(
				"section_rows",
				[]
			),
			"interaction_contract": incoming_contract.get(
				"interaction_contract",
				{}
			),
			"truth_state": (
				"hot"
				if top_level_hot
				else "renderer_chassis"
			),
			"projection_composed": bool(
				incoming_contract.get(
					"projection_composed",
					false
				)
			),
			"hydrated": top_level_hot,
			"projection_pending": not top_level_hot,
			"ui_is_renderer_only": true
		}

		var existing_fallback: Dictionary = _shallow_dictionary(
			section_contract_cache.get(
				active_section,
				{}
			)
		)

		if _should_adopt_crime_section_surface(
			existing_fallback,
			fallback_surface
		):
			section_contract_cache [
				active_section
			] = fallback_surface

			adopted_sections.append(
				active_section
			)

	var merged_surfaces: Dictionary = {}

	for raw_section_id in section_contract_cache.keys():
		var section_id: String = str(
			raw_section_id
		).strip_edges().to_lower()

		if section_id == "":
			continue

		merged_surfaces [
			section_id
		] = _shallow_dictionary(
			section_contract_cache.get(
				raw_section_id,
				{}
			)
		).duplicate(false)

	incoming_contract [
		"active_section"
	] = active_section

	incoming_contract [
		"section_surfaces"
	] = merged_surfaces

	active_contract = incoming_contract

	_ensure_surface()

	var tabs: Array = _safe_array(
		active_contract.get(
			"section_tabs",
			[]
		)
	)

	if not _crime_section_scaffold_matches(
		tabs
	):
		_render_active_contract()
	else:
		title_label.text = str(
			active_contract.get(
				"title",
				"CRIME & JUSTICE"
			)
		)
		subtitle_label.text = str(
			active_contract.get(
				"subtitle",
				""
			)
		)

		section_grid.columns = clampi(
			tabs.size(),
			1,
			4
		)

		var sections_to_repaint: Array = (
			[]
			if not actor_changed
			else section_surface_nodes.keys()
		)

		if not actor_changed:
			for raw_section_id in adopted_sections:
				var section_id: String = str(
					raw_section_id
				).strip_edges().to_lower()

				if (
					section_id != ""
					and section_id not in sections_to_repaint
				):
					sections_to_repaint.append(
						section_id
					)

		if "targets" in sections_to_repaint:
			_invalidate_crime_target_bloom_projection()

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

			var button: Button = section_buttons.get(
				section_id,
				null
			) as Button

			if (
				button != null
				and is_instance_valid(button)
			):
				button.text = str(
					tab.get(
						"label",
						section_id.capitalize()
					)
				)

			if section_id not in sections_to_repaint:
				continue

			var resident_surface: VBoxContainer = (
				section_surface_nodes.get(
					section_id,
					null
				) as VBoxContainer
			)

			if (
				resident_surface == null
				or not is_instance_valid(resident_surface)
			):
				continue

			_paint_crime_section_surface(
				section_id,
				resident_surface,
				_shallow_dictionary(
					section_contract_cache.get(
						section_id,
						{}
					)
				)
			)

		_activate_section_surface(
			active_section,
			false
		)

	if install_hidden:
		visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		process_mode = Node.PROCESS_MODE_INHERIT
	else:
		visible = true
		mouse_filter = Control.MOUSE_FILTER_STOP
		process_mode = Node.PROCESS_MODE_INHERIT
		move_to_front()

	set_meta(
		"crime_panel_contract_copy_mode",
		"shallow_read_only"
	)
	set_meta(
		"crime_panel_recursive_contract_copy_forbidden",
		true
	)
	set_meta(
		"crime_panel_section_cache_count",
		section_contract_cache.size()
	)
	set_meta(
		"crime_panel_section_press_routes_engine",
		false
	)
	set_meta(
		"crime_panel_all_section_controls_precomposed",
		true
	)
	set_meta(
		"crime_panel_build_on_section_press",
		false
	)
	set_meta(
		"crime_panel_installed_hidden",
		install_hidden
	)
	set_meta(
		"crime_panel_monotonic_section_adoption",
		true
	)
	set_meta(
		"crime_panel_full_packet_erases_hot_delta",
		false
	)
func hide_surface() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE



	process_mode = Node.PROCESS_MODE_INHERIT

	set_meta(
		"crime_hidden_resident_streaming_allowed",
		true
	)


func has_renderable_contract(
	actor_id: int = -1
) -> bool:
	if active_contract.is_empty():
		return false

	if not bool(
		active_contract.get(
			"success",
			false
		)
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

	return (
		str(
			active_contract.get(
				"truth_state",
				""
			)
		) == "hot"
		and bool(
			active_contract.get(
				"projection_composed",
				false
			)
		)
		and bool(
			active_contract.get(
				"hydrated",
				false
			)
		)
	)


func _ensure_surface() -> void:
	if card != null:
		return

	dim = ColorRect.new()
	dim.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	dim.color = Color(
		0.012,
		0.002,
		0.004,
		0.965
	)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(
		dim
	)

	card = PanelContainer.new()
	card.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	card.offset_left = 26
	card.offset_top = 26
	card.offset_right = -26
	card.offset_bottom = -26
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var card_style:= StyleBoxFlat.new()
	card_style.bg_color = Color(
		0.045,
		0.006,
		0.01,
		0.985
	)
	card_style.border_color = Color(
		0.82,
		0.035,
		0.075,
		0.95
	)
	card_style.set_border_width_all(
		3
	)
	card_style.set_corner_radius_all(
		22
	)
	card_style.shadow_color = Color(
		0.72,
		0.015,
		0.045,
		0.42
	)
	card_style.shadow_size = 24

	card.add_theme_stylebox_override(
		"panel",
		card_style
	)

	add_child(
		card
	)

	var margin:= MarginContainer.new()
	margin.add_theme_constant_override(
		"margin_left",
		24
	)
	margin.add_theme_constant_override(
		"margin_top",
		20
	)
	margin.add_theme_constant_override(
		"margin_right",
		24
	)
	margin.add_theme_constant_override(
		"margin_bottom",
		20
	)
	card.add_child(
		margin
	)

	var root:= VBoxContainer.new()
	root.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	root.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	root.add_theme_constant_override(
		"separation",
		12
	)
	margin.add_child(
		root
	)

	var header:= HBoxContainer.new()
	header.add_theme_constant_override(
		"separation",
		12
	)
	root.add_child(
		header
	)

	var header_copy:= VBoxContainer.new()
	header_copy.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	header.add_child(
		header_copy
	)

	title_label = Label.new()
	title_label.text = "CRIME"
	title_label.add_theme_font_size_override(
		"font_size",
		30
	)
	title_label.add_theme_color_override(
		"font_color",
		Color(
			1.0,
			0.18,
			0.22,
			1.0
		)
	)
	title_label.add_theme_color_override(
		"font_shadow_color",
		Color(
			0.82,
			0.0,
			0.05,
			0.62
		)
	)
	title_label.add_theme_constant_override(
		"shadow_offset_x",
		2
	)
	title_label.add_theme_constant_override(
		"shadow_offset_y",
		2
	)
	header_copy.add_child(
		title_label
	)

	subtitle_label = Label.new()
	subtitle_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	subtitle_label.add_theme_font_size_override(
		"font_size",
		14
	)
	subtitle_label.add_theme_color_override(
		"font_color",
		Color(
			0.94,
			0.74,
			0.76,
			1.0
		)
	)
	header_copy.add_child(
		subtitle_label
	)

	close_button = Button.new()
	close_button.text = "CLOSE"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.custom_minimum_size = Vector2(
		110,
		48
	)

	_apply_crime_button_visuals(
		close_button,
		false
	)

	close_button.pressed.connect(
		_on_close_pressed
	)
	header.add_child(
		close_button
	)

	section_grid = GridContainer.new()
	section_grid.columns = 4
	section_grid.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	section_grid.add_theme_constant_override(
		"h_separation",
		8
	)
	section_grid.add_theme_constant_override(
		"v_separation",
		8
	)
	root.add_child(
		section_grid
	)

	scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	scroll.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	root.add_child(
		scroll
	)

	list_root = VBoxContainer.new()
	list_root.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	list_root.add_theme_constant_override(
		"separation",
		12
	)
	scroll.add_child(
		list_root
	)

	footer_label = Label.new()
	footer_label.text = (
		"UI IS THE LENS • CRIMINAL REALITY REMAINS AUTHORITATIVE"
	)
	footer_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	footer_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	footer_label.add_theme_font_size_override(
		"font_size",
		11
	)
	footer_label.add_theme_color_override(
		"font_color",
		Color(
			0.75,
			0.3,
			0.34,
			0.85
		)
	)
	root.add_child(
		footer_label
	)
func _crime_button_style(
	hovered: bool = false,
	pressed: bool = false
) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()

	style.bg_color = (
		Color(
			0.28,
			0.015,
			0.03,
			0.98
		)
		if pressed
		else (
			Color(
				0.19,
				0.01,
				0.02,
				0.98
			)
			if hovered
			else Color(
				0.095,
				0.008,
				0.014,
				0.98
			)
		)
	)

	style.border_color = (
		Color(
			1.0,
			0.12,
			0.17,
			1.0
		)
		if hovered or pressed
		else Color(
			0.58,
			0.035,
			0.07,
			0.88
		)
	)

	style.set_border_width_all(
		2
	)
	style.set_corner_radius_all(
		11
	)

	if hovered or pressed:
		style.shadow_color = Color(
			0.85,
			0.015,
			0.06,
			0.42
		)
		style.shadow_size = 10

	return style


func _apply_crime_button_visuals(
	button: Button,
	selected: bool = false
) -> void:
	if (
		button == null
		or not is_instance_valid(
			button
		)
	):
		return

	button.add_theme_stylebox_override(
		"normal",
		_crime_button_style(
			false,
			selected
		)
	)
	button.add_theme_stylebox_override(
		"hover",
		_crime_button_style(
			true,
			false
		)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_crime_button_style(
			true,
			true
		)
	)
	button.add_theme_stylebox_override(
		"focus",
		_crime_button_style(
			true,
			selected
		)
	)

	button.add_theme_color_override(
		"font_color",
		Color(
			0.96,
			0.8,
			0.81,
			1.0
		)
	)
	button.add_theme_color_override(
		"font_hover_color",
		Color(
			1.0,
			0.26,
			0.29,
			1.0
		)
	)
	button.add_theme_color_override(
		"font_pressed_color",
		Color(
			1.0,
			0.38,
			0.4,
			1.0
		)
	)

func _render_active_contract() -> void:
	if card == null:
		return

	title_label.text = str(
		active_contract.get(
			"title",
			"CRIME"
		)
	)
	subtitle_label.text = str(
		active_contract.get(
			"subtitle",
			""
		)
	)

	crime_target_bloom_generation += 1
	crime_target_bloom_queue.clear()
	weapon_target_grid_by_section.clear()
	weapon_body_surface_by_target_id.clear()
	weapon_body_contract_by_target_id.clear()
	weapon_target_section_by_target_id.clear()
	active_weapon_target_id = -1

	_clear_children(
		section_grid
	)
	_clear_children(
		list_root
	)

	section_buttons.clear()
	section_surface_nodes.clear()

	var active_section: String = str(
		active_contract.get(
			"active_section",
			"overview"
		)
	).strip_edges().to_lower()

	var tabs: Array = _safe_array(
		active_contract.get(
			"section_tabs",
			[]
		)
	)

	section_grid.columns = clampi(
		tabs.size(),
		1,
		4
	)

	for raw_tab in tabs:
		if typeof(
			raw_tab
		) != TYPE_DICTIONARY:
			continue

		var tab: Dictionary = (
			raw_tab as Dictionary
		)
		var section_id: String = str(
			tab.get(
				"id",
				"overview"
			)
		).strip_edges().to_lower()

		if section_id == "":
			continue

		var button:= Button.new()
		button.text = str(
			tab.get(
				"label",
				section_id.capitalize()
			)
		)
		button.focus_mode = Control.FOCUS_NONE
		button.toggle_mode = true
		button.size_flags_horizontal = (
			Control.SIZE_EXPAND_FILL
		)
		_apply_crime_button_visuals(
			button,
			section_id == active_section
		)
		button.pressed.connect(
			Callable(
				self,
				"_on_section_pressed"
			).bind(
				section_id
			)
		)
		section_grid.add_child(
			button
		)
		section_buttons [
			section_id
		] = button

		var section_surface:= VBoxContainer.new()
		section_surface.name = (
			"CrimeSectionSurface_%s"
			% section_id
		)
		section_surface.visible = false
		section_surface.size_flags_horizontal = (
			Control.SIZE_EXPAND_FILL
		)
		section_surface.add_theme_constant_override(
			"separation",
			10
		)
		list_root.add_child(
			section_surface
		)
		section_surface_nodes [
			section_id
		] = section_surface

		var surface: Dictionary = _shallow_dictionary(
			section_contract_cache.get(
				section_id,
				{}
			)
		)

		_paint_crime_section_surface(
			section_id,
			section_surface,
			surface
		)

	_activate_section_surface(
		active_section,
		false
	)

	set_meta(
		"crime_panel_section_surface_count",
		section_surface_nodes.size()
	)
	set_meta(
		"crime_panel_section_controls_built_during_contract_install",
		true
	)
	set_meta(
		"crime_panel_section_controls_built_during_section_press",
		false
	)

func _crime_empty_section_status(
	section_id: String,
	surface: Dictionary
) -> String:
	var explicit_status: String = str(
		surface.get(
			"status_text",
			""
		)
	).strip_edges()

	if explicit_status != "":
		return explicit_status

	var surface_actor_id: int = int(
		surface.get(
			"actor_id",
			-1
		)
	)
	var truth_state: String = str(
		surface.get(
			"truth_state",
			""
		)
	).strip_edges().to_lower()
	var hydrated: bool = bool(
		surface.get(
			"hydrated",
			false
		)
	)
	var projection_pending: bool = bool(
		surface.get(
			"projection_pending",
			true
		)
	)



	if (
		surface.is_empty()
		or surface_actor_id <= 0
		or truth_state != "hot"
		or not hydrated
		or projection_pending
	):
		return (
			"%s is publishing its resident projection live."
			% section_id.replace(
				"_",
				" "
			).capitalize()
		)

	match section_id:
		"weapons":
			return "No resident weapons are currently available."
		"cases":
			return "No active crime cases are attached to this actor."
		"pending":
			return (
				"No pending criminal or legal pressure "
				+ "is attached to this actor."
			)
		"custody", "prison":
			return "No custody contract is active for this actor."
		"targets":
			return "No eligible resident crime targets are currently projected."
		"crime_actions":
			return "Resident crime actions are publishing live."
		_:
			return "Controlled-actor Crime truth is publishing live."

func _add_crime_section_status_label(
	parent: Node,
	status_text: String
) -> void:
	if (
		parent == null
		or not is_instance_valid(parent)
	):
		return

	var status:= Label.new()
	status.name = "CrimeSectionStatus"
	status.text = status_text
	status.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	status.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	status.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	status.add_theme_color_override(
		"font_color",
		Color(
			0.82,
			0.5,
			0.53,
			0.96
		)
	)

	parent.add_child(
		status
	)
func _paint_crime_section_surface(
	section_id: String,
	section_surface: VBoxContainer,
	surface: Dictionary
) -> void:
	if (
		section_surface == null
		or not is_instance_valid(section_surface)
	):
		return
	_clear_children(
		section_surface
	)
	var interaction: Dictionary = _shallow_dictionary(
		surface.get(
			"interaction_contract",
			{}
		)
	)
	var interaction_stage: String = str(
		interaction.get(
			"stage",
			""
		)
	).strip_edges().to_lower()
	if not interaction.is_empty():
		var interaction_header:= HBoxContainer.new()
		interaction_header.size_flags_horizontal = (
			Control.SIZE_EXPAND_FILL
		)
		interaction_header.add_theme_constant_override(
			"separation",
			12
		)
		section_surface.add_child(
			interaction_header
		)
		var interaction_title:= Label.new()
		interaction_title.text = str(
			interaction.get(
				"title",
				"Crime Action"
			)
		)
		interaction_title.size_flags_horizontal = (
			Control.SIZE_EXPAND_FILL
		)
		interaction_title.add_theme_font_size_override(
			"font_size",
			24
		)
		interaction_title.add_theme_color_override(
			"font_color",
			Color(
				1.0,
				0.18,
				0.22,
				1.0
			)
		)
		interaction_header.add_child(
			interaction_title
		)
		var cancel_action: Dictionary = _shallow_dictionary(
			interaction.get(
				"cancel_action",
				{}
			)
		)
		if (
			interaction_stage == "choose_crime_target"
			and not cancel_action.is_empty()
		):
			var cancel_button:= Button.new()
			cancel_button.text = str(
				cancel_action.get(
					"label",
					"CANCEL"
				)
			)
			cancel_button.focus_mode = Control.FOCUS_NONE
			cancel_button.custom_minimum_size = Vector2(
				170.0,
				42.0
			)
			_apply_crime_button_visuals(
				cancel_button,
				false
			)
			cancel_button.pressed.connect(
				Callable(
					self,
					"_on_action_pressed"
				).bind(
					cancel_action.duplicate(false),
					{
						"kind": "crime_interaction_cancel",
						"label": str(
							cancel_action.get(
								"label",
								"CANCEL"
							)
						)
					}
				)
			)
			interaction_header.add_child(
				cancel_button
			)
		var interaction_subtitle:= Label.new()
		interaction_subtitle.text = str(
			interaction.get(
				"subtitle",
				""
			)
		)
		interaction_subtitle.autowrap_mode = (
			TextServer.AUTOWRAP_WORD_SMART
		)
		interaction_subtitle.add_theme_color_override(
			"font_color",
			Color(
				0.88,
				0.7,
				0.72,
				1.0
			)
		)
		section_surface.add_child(
			interaction_subtitle
		)
	var rows: Array = _safe_array(
		surface.get(
			"section_rows",
			[]
		)
	)
	var status_text: String = (
		_crime_empty_section_status(
			section_id,
			surface
		)
	)
	var projection_pending: bool = bool(
		surface.get(
			"projection_pending",
			false
		)
	)

	if (
		section_id == "targets"
		and interaction_stage != "choose_body_part"
	):
		_prepare_weapon_target_bloom(
			section_id,
			section_surface,
			rows,
			status_text,
			projection_pending
		)
		return





	if section_id == "crime_actions":
		var action_grid:= GridContainer.new()
		action_grid.columns = 2
		action_grid.size_flags_horizontal = (
			Control.SIZE_EXPAND_FILL
		)
		action_grid.add_theme_constant_override(
			"h_separation",
			14
		)
		action_grid.add_theme_constant_override(
			"v_separation",
			14
		)
		section_surface.add_child(
			action_grid
		)
		for raw_row in rows:
			if typeof(raw_row) != TYPE_DICTIONARY:
				continue
			_render_row_into(
				action_grid,
				raw_row as Dictionary
			)
		if rows.is_empty():
			_add_crime_section_status_label(
				action_grid,
				status_text
			)
		return
	for raw_row in rows:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue
		_render_row_into(
			section_surface,
			raw_row as Dictionary
		)
	if section_surface.get_child_count() <= 0:
		_add_crime_section_status_label(
			section_surface,
			status_text
		)
func _crime_row_card_style(
	row: Dictionary,
	hovered: bool = false
) -> StyleBoxFlat:
	var kind: String = str(
		row.get(
			"kind",
			""
		)
	).strip_edges().to_lower()

	var target_card: bool = (
		kind == "crime_target"
	)
	var action_card: bool = (
		kind == "crime_action"
	)

	var style:= StyleBoxFlat.new()

	style.bg_color = (
		Color(
			0.13,
			0.006,
			0.014,
			0.99
		)
		if target_card
		else (
			Color(
				0.1,
				0.004,
				0.01,
				0.99
			)
			if action_card
			else Color(
				0.065,
				0.008,
				0.012,
				0.98
			)
		)
	)

	style.border_color = (
		Color(
			1.0,
			0.1,
			0.16,
			1.0
		)
		if hovered
		else (
			Color(
				0.82,
				0.035,
				0.08,
				0.92
			)
			if target_card or action_card
			else Color(
				0.45,
				0.025,
				0.055,
				0.78
			)
		)
	)

	style.set_border_width_all(
		3
		if hovered
		else 2
	)

	style.set_corner_radius_all(
		18
	)

	style.shadow_color = (
		Color(
			0.92,
			0.015,
			0.075,
			0.48
		)
		if hovered
		else Color(
			0.62,
			0.008,
			0.04,
			0.24
		)
	)

	style.shadow_size = (
		18
		if hovered
		else 9
	)

	return style


func _set_crime_row_card_hover(
	card_control: PanelContainer,
	row: Dictionary,
	hovered: bool
) -> void:
	if (
		card_control == null
		or not is_instance_valid(
			card_control
		)
	):
		return

	card_control.add_theme_stylebox_override(
		"panel",
		_crime_row_card_style(
			row,
			hovered
		)
	)

	card_control.scale = (
		Vector2(
			1.018,
			1.018
		)
		if hovered
		else Vector2.ONE
	)

	_refresh_crime_target_reticle(
		card_control,
		row,
		hovered
	)


func _toggle_resident_crime_method_grid(
	method_grid: GridContainer
) -> void:
	if (
		method_grid == null
		or not is_instance_valid(
			method_grid
		)
	):
		return



	method_grid.visible = not method_grid.visible
	method_grid.mouse_filter = (
		Control.MOUSE_FILTER_PASS
		if method_grid.visible
		else Control.MOUSE_FILTER_IGNORE
	)


func _on_crime_target_card_gui_input(
	event: InputEvent,
	row: Dictionary
) -> void:
	if not (event is InputEventMouseButton):
		return

	var mouse_event: InputEventMouseButton = (
		event as InputEventMouseButton
	)

	if (
		mouse_event.button_index != MOUSE_BUTTON_LEFT
		or not mouse_event.pressed
	):
		return

	var target_id: int = int(
		row.get(
			"target_id",
			-1
		)
	)

	if target_id <= 0:
		return

	var interaction_stage: String = (
		_crime_target_interaction_stage()
	)

	if interaction_stage == "choose_target":
		var action: Dictionary = (
			_crime_target_selection_action_for_row(
				row,
				interaction_stage
			)
		)

		if (
			action.is_empty()
			or not bool(
				action.get(
					"enabled",
					true
				)
			)
		):
			return

		_acknowledge_crime_target_visual_selection(
			target_id
		)
		_on_resident_weapon_target_pressed(
			target_id
		)
		return

	if interaction_stage == "choose_crime_target":
		var action: Dictionary = (
			_crime_target_selection_action_for_row(
				row,
				interaction_stage
			)
		)

		if (
			action.is_empty()
			or not bool(
				action.get(
					"enabled",
					true
				)
			)
		):
			return

		_acknowledge_crime_target_visual_selection(
			target_id
		)
		_on_action_pressed(
			action,
			row
		)
		return







	var dormant_action: Dictionary = _shallow_dictionary(
		row.get(
			"target_selection_action",
			{}
		)
	)

	if (
		dormant_action.is_empty()
		or not bool(
			dormant_action.get(
				"enabled",
				true
			)
		)
	):
		return

	_on_action_pressed(
		dormant_action,
		row
	)
func _prepare_weapon_target_bloom(
	section_id: String,
	section_surface: VBoxContainer,
	rows: Array,
	status_text: String = "",
	projection_pending: bool = true
) -> void:


	crime_target_bloom_generation += 1
	crime_target_bloom_queue.clear()
	crime_target_bloom_cursor = 0

	crime_target_visual_generation += 1
	crime_target_visual_ack_target_id = -1
	crime_target_visual_dim_cursor = 0
	crime_target_reticle_pulse_cursor = 0
	crime_target_card_by_id.clear()
	crime_target_card_order.clear()

	var grid:= GridContainer.new()
	grid.name = (
		"CrimeWeaponTargetGrid_%s"
		% section_id
	)
	grid.columns = 3
	grid.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	grid.add_theme_constant_override(
		"h_separation",
		12
	)
	grid.add_theme_constant_override(
		"v_separation",
		12
	)

	section_surface.add_child(
		grid
	)

	weapon_target_grid_by_section [
		section_id
	] = grid



	if rows.is_empty():
		var resolved_status: String = (
			status_text.strip_edges()
		)

		if resolved_status == "":
			resolved_status = (
				"Resident target identities are publishing live…"
				if projection_pending
				else (
					"No eligible resident crime targets "
					+ "are currently projected."
				)
			)

		_add_crime_section_status_label(
			grid,
			resolved_status
		)

		return

	var generation: int = (
		crime_target_bloom_generation
	)

	for raw_row in rows:
		if typeof(
			raw_row
		) != TYPE_DICTIONARY:
			continue

		crime_target_bloom_queue.append({
			"generation": generation,
			"section_id": section_id,
			"section_surface": section_surface,
			"grid": grid,
			"row": raw_row
		})

	_arm_crime_target_bloom_service()
func _arm_crime_target_bloom_service() -> void:
	if (
		crime_target_bloom_queue.is_empty()
		or crime_target_bloom_cursor
		>= crime_target_bloom_queue.size()
	):
		return

	var tree:= Engine.get_main_loop() as SceneTree

	if tree == null:
		return

	var callback:= Callable(
		self,
		"_drive_crime_target_bloom_process_frame"
	)

	if tree.process_frame.is_connected(
		callback
	):
		crime_target_bloom_service_active = true
		return

	tree.process_frame.connect(
		callback
	)

	crime_target_bloom_service_active = true

	if OS.is_debug_build():
		EraLog.truth(
			"ERALIFE_CRIME_PIPELINE_TRUTH"
			+ "|authority=CrimePanel"
			+ "|stage=target_bloom_lease_acquired"
			+ "|queued_rows=%d" % (
				crime_target_bloom_queue.size()
				- crime_target_bloom_cursor
			)
			+ "|at_ms=%d" % int(
				Time.get_ticks_msec()
			)
		)


func _drive_crime_target_bloom_process_frame() -> void:
	var tree:= Engine.get_main_loop() as SceneTree
	var callback:= Callable(
		self,
		"_drive_crime_target_bloom_process_frame"
	)

	if (
		crime_target_bloom_queue.is_empty()
		or crime_target_bloom_cursor
		>= crime_target_bloom_queue.size()
	):
		if (
			tree != null
			and tree.process_frame.is_connected(
				callback
			)
		):
			tree.process_frame.disconnect(
				callback
			)

		crime_target_bloom_service_active = false
		return

	_service_weapon_target_bloom()

	if (
		crime_target_bloom_queue.is_empty()
		or crime_target_bloom_cursor
		>= crime_target_bloom_queue.size()
	):
		if (
			tree != null
			and tree.process_frame.is_connected(
				callback
			)
		):
			tree.process_frame.disconnect(
				callback
			)

		crime_target_bloom_service_active = false
	else:
		crime_target_bloom_service_active = true
func _service_weapon_target_bloom() -> void:
	if (
		crime_target_bloom_queue.is_empty()
		or crime_target_bloom_cursor
		>= crime_target_bloom_queue.size()
	):
		crime_target_bloom_queue.clear()
		crime_target_bloom_cursor = 0
		return

	var serviced_this_quantum: int = 0

	while (
		crime_target_bloom_cursor
		< crime_target_bloom_queue.size()
		and serviced_this_quantum
		< CRIME_TARGET_BLOOM_BATCH_SIZE
	):
		var request: Dictionary = _shallow_dictionary(
			crime_target_bloom_queue [
				crime_target_bloom_cursor
			]
		)

		crime_target_bloom_cursor += 1
		serviced_this_quantum += 1

		if int(
			request.get(
				"generation",
				-1
			)
		) != crime_target_bloom_generation:
			continue

		var grid: GridContainer = (
			request.get(
				"grid",
				null
			) as GridContainer
		)

		var section_surface: VBoxContainer = (
			request.get(
				"section_surface",
				null
			) as VBoxContainer
		)

		var row: Dictionary = _shallow_dictionary(
			request.get(
				"row",
				{}
			)
		)

		if (
			grid == null
			or section_surface == null
			or not is_instance_valid(
				grid
			)
			or not is_instance_valid(
				section_surface
			)
			or row.is_empty()
		):
			continue

		var child_count_before: int = (
			grid.get_child_count()
		)

		_render_row_into(
			grid,
			row
		)

		if (
			grid.get_child_count()
			> child_count_before
		):
			var rendered_card: PanelContainer = (
				grid.get_child(
					grid.get_child_count() - 1
				) as PanelContainer
			)

			if rendered_card != null:
				_register_crime_target_card_presentation(
					rendered_card,
					row
				)

				if OS.is_debug_build():
					EraLog.truth(
						"ERALIFE_CRIME_PIPELINE_TRUTH"
						+ "|authority=CrimePanel"
						+ "|stage=card_painted"
						+ "|section=%s" % str(
							request.get(
								"section_id",
								"targets"
							)
						)
						+ "|target_id=%d" % int(
							row.get(
								"target_id",
								-1
							)
						)
						+ "|card_count=%d" % (
							grid.get_child_count()
						)
						+ "|at_ms=%d" % int(
							Time.get_ticks_msec()
						)
					)

		_prepaint_weapon_body_surface(
			str(
				request.get(
					"section_id",
					"targets"
				)
			),
			section_surface,
			row
		)

	if (
		crime_target_bloom_cursor
		>= crime_target_bloom_queue.size()
	):
		crime_target_bloom_queue.clear()
		crime_target_bloom_cursor = 0
		return






func _prepaint_weapon_body_surface(
	section_id: String,
	section_surface: VBoxContainer,
	target_row: Dictionary
) -> void:
	var target_id: int = int(
		target_row.get(
			"target_id",
			-1
		)
	)

	if (
		target_id <= 0
		or weapon_body_surface_by_target_id.has(
			target_id
		)
	):
		return

	var body_contract: Dictionary = _shallow_dictionary(
		target_row.get(
			"body_surface_contract",
			{}
		)
	)

	if body_contract.is_empty():
		return

	var body_surface:= VBoxContainer.new()
	body_surface.name = (
		"CrimeWeaponBodySurface_%d"
		% target_id
	)
	body_surface.visible = false
	body_surface.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	body_surface.add_theme_constant_override(
		"separation",
		10
	)
	section_surface.add_child(
		body_surface
	)

	var back_button:= Button.new()
	back_button.text = "← BACK TO TARGETS"
	back_button.focus_mode = (
		Control.FOCUS_NONE
	)
	back_button.pressed.connect(
		_on_weapon_body_back_pressed.bind(
			section_id,
			target_id
		)
	)
	body_surface.add_child(
		back_button
	)

	var title:= Label.new()
	title.text = str(
		body_contract.get(
			"title",
			"Choose where to target"
		)
	)
	title.add_theme_font_size_override(
		"font_size",
		24
	)
	body_surface.add_child(
		title
	)

	var subtitle:= Label.new()
	subtitle.text = str(
		body_contract.get(
			"subtitle",
			""
		)
	)
	subtitle.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	body_surface.add_child(
		subtitle
	)

	for raw_body_row in _safe_array(
		body_contract.get(
			"rows",
			[]
		)
	):
		if typeof(
			raw_body_row
		) != TYPE_DICTIONARY:
			continue

		_render_row_into(
			body_surface,
			raw_body_row as Dictionary
		)

	weapon_body_surface_by_target_id [
		target_id
	] = body_surface
	weapon_body_contract_by_target_id [
		target_id
	] = body_contract
	weapon_target_section_by_target_id [
		target_id
	] = section_id


func _on_resident_weapon_target_pressed(
	target_id: int
) -> void:
	if target_id <= 0:
		return






	var target_card: PanelContainer = (
		crime_target_card_by_id.get(
			str(
				target_id
			),
			null
		) as PanelContainer
	)

	if (
		target_card == null
		or not is_instance_valid(
			target_card
		)
	):
		return

	var row: Dictionary = _shallow_dictionary(
		target_card.get_meta(
			"crime_target_row_contract",
			{}
		)
	)

	if row.is_empty():
		return

	var interaction_stage: String = (
		_crime_target_interaction_stage()
	)

	if interaction_stage != "choose_target":
		return

	var action: Dictionary = (
		_crime_target_selection_action_for_row(
			row,
			interaction_stage
		)
	)

	if (
		action.is_empty()
		or not bool(
			action.get(
				"enabled",
				true
			)
		)
	):
		return



	if crime_target_visual_ack_target_id != target_id:
		_acknowledge_crime_target_visual_selection(
			target_id
		)

	set_meta(
		"crime_target_press_engine_call_performed",
		false
	)
	set_meta(
		"crime_target_press_build_performed",
		false
	)
	set_meta(
		"crime_target_press_pointer_swap_only",
		false
	)
	set_meta(
		"crime_target_press_constitutional_intent_only",
		true
	)




	_on_action_pressed(
		action.duplicate(
			false
		),
		row.duplicate(
			false
		)
	)


func _on_weapon_body_back_pressed(
	section_id: String,
	target_id: int
) -> void:
	var body_surface: VBoxContainer = (
		weapon_body_surface_by_target_id.get(
			target_id,
			null
		) as VBoxContainer
	)

	if (
		body_surface != null
		and is_instance_valid(
			body_surface
		)
	):
		body_surface.visible = false
		body_surface.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)

	var grid: GridContainer = (
		weapon_target_grid_by_section.get(
			section_id,
			null
		) as GridContainer
	)

	if (
		grid != null
		and is_instance_valid(
			grid
		)
	):
		grid.visible = true
		grid.mouse_filter = (
			Control.MOUSE_FILTER_PASS
		)

	var section_contract: Dictionary = _shallow_dictionary(
		section_contract_cache.get(
			section_id,
			{}
		)
	)

	active_contract [
		"interaction_contract"
	] = _shallow_dictionary(
		section_contract.get(
			"interaction_contract",
			{}
		)
	)

	active_weapon_target_id = -1
func _render_row(
	row: Dictionary
) -> void:
	_render_row_into(
		list_root,
		row
	)


func _render_row_into(
	target_root: Container,
	row: Dictionary
) -> void:
	if (
		target_root == null
		or not is_instance_valid(
			target_root
		)
	):
		return

	var row_kind: String = str(
		row.get(
			"kind",
			""
		)
	).strip_edges().to_lower()

	var is_target_card: bool = (
		row_kind == "crime_target"
	)
	var is_action_card: bool = (
		row_kind == "crime_action"
	)

	var row_card:= PanelContainer.new()
	row_card.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	row_card.mouse_filter = (
		Control.MOUSE_FILTER_STOP
	)

	if is_target_card:
		row_card.custom_minimum_size = Vector2(
			270,
			205
		)
	elif is_action_card:
		row_card.custom_minimum_size = Vector2(
			360,
			235
		)

	row_card.add_theme_stylebox_override(
		"panel",
		_crime_row_card_style(
			row,
			false
		)
	)

	if (
		is_target_card
		or is_action_card
	):
		row_card.mouse_entered.connect(
			Callable(
				self,
				"_set_crime_row_card_hover"
			).bind(
				row_card,
				row.duplicate(false),
				true
			)
		)

		row_card.mouse_exited.connect(
			Callable(
				self,
				"_set_crime_row_card_hover"
			).bind(
				row_card,
				row.duplicate(false),
				false
			)
		)

	if is_target_card:
		row_card.gui_input.connect(
			Callable(
				self,
				"_on_crime_target_card_gui_input"
			).bind(
				row.duplicate(false)
			)
		)

	target_root.add_child(
		row_card
	)

	var margin:= MarginContainer.new()
	margin.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
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
	row_card.add_child(
		margin
	)

	var body:= VBoxContainer.new()
	body.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	body.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	body.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	body.add_theme_constant_override(
		"separation",
		8
	)
	margin.add_child(
		body
	)

	if is_target_card:
		var target_chip:= Label.new()
		target_chip.text = (
			"TARGET • %s"
			% str(
				row.get(
					"relationship_label",
					"Resident"
				)
			).to_upper()
		)
		target_chip.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_CENTER
		)
		target_chip.add_theme_font_size_override(
			"font_size",
			11
		)
		target_chip.add_theme_color_override(
			"font_color",
			Color(
				1.0,
				0.22,
				0.25,
				1.0
			)
		)
		target_chip.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)
		body.add_child(
			target_chip
		)

	if is_action_card:
		var action_chip:= Label.new()
		action_chip.text = str(
			row.get(
				"danger_label",
				"CRIME"
			)
		).to_upper()
		action_chip.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_CENTER
		)
		action_chip.add_theme_font_size_override(
			"font_size",
			11
		)
		action_chip.add_theme_color_override(
			"font_color",
			Color(
				1.0,
				0.12,
				0.18,
				1.0
			)
		)
		action_chip.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)
		body.add_child(
			action_chip
		)

	var label:= Label.new()
	label.text = str(
		row.get(
			"label",
			"Crime Record"
		)
	)
	label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
		if (
			is_target_card
			or is_action_card
		)
		else HORIZONTAL_ALIGNMENT_LEFT
	)
	label.add_theme_font_size_override(
		"font_size",
		22
		if (
			is_target_card
			or is_action_card
		)
		else 18
	)
	label.add_theme_color_override(
		"font_color",
		Color(
			1.0,
			0.87,
			0.88,
			1.0
		)
	)
	label.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	body.add_child(
		label
	)

	var subtitle_text: String = str(
		row.get(
			"subtitle",
			row.get(
				"overview",
				""
			)
		)
	).strip_edges()

	if subtitle_text != "":
		var subtitle:= Label.new()
		subtitle.text = subtitle_text
		subtitle.autowrap_mode = (
			TextServer.AUTOWRAP_WORD_SMART
		)
		subtitle.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_CENTER
			if (
				is_target_card
				or is_action_card
			)
			else HORIZONTAL_ALIGNMENT_LEFT
		)
		subtitle.add_theme_font_size_override(
			"font_size",
			13
		)
		subtitle.add_theme_color_override(
			"font_color",
			Color(
				0.88,
				0.7,
				0.72,
				1.0
			)
		)
		subtitle.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)
		body.add_child(
			subtitle
		)

	var actions: Array = _safe_array(
		row.get(
			"actions",
			[]
		)
	)

	var method_actions: Array = _safe_array(
		row.get(
			"method_actions",
			[]
		)
	)

	var method_grid: GridContainer = null

	if not method_actions.is_empty():
		method_grid = GridContainer.new()
		method_grid.columns = mini(
			3,
			maxi(
				1,
				method_actions.size()
			)
		)
		method_grid.visible = false
		method_grid.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)
		method_grid.size_flags_horizontal = (
			Control.SIZE_EXPAND_FILL
		)
		method_grid.add_theme_constant_override(
			"h_separation",
			7
		)
		method_grid.add_theme_constant_override(
			"v_separation",
			7
		)



		for raw_method_action in method_actions:
			if typeof(raw_method_action) != TYPE_DICTIONARY:
				continue

			var method_action: Dictionary = (
				raw_method_action as Dictionary
			)
			var method_button:= Button.new()

			method_button.text = str(
				method_action.get(
					"label",
					"METHOD"
				)
			)

			method_button.focus_mode = (
				Control.FOCUS_NONE
			)
			method_button.size_flags_horizontal = (
				Control.SIZE_EXPAND_FILL
			)

			_apply_crime_button_visuals(
				method_button,
				false
			)

			method_button.pressed.connect(
				Callable(
					self,
					"_on_action_pressed"
				).bind(
					method_action.duplicate(false),
					row.duplicate(false)
				)
			)

			method_grid.add_child(
				method_button
			)

	if not actions.is_empty():
		var action_grid:= GridContainer.new()
		action_grid.columns = mini(
			3,
			maxi(
				1,
				actions.size()
			)
		)
		action_grid.size_flags_horizontal = (
			Control.SIZE_EXPAND_FILL
		)
		action_grid.add_theme_constant_override(
			"h_separation",
			7
		)
		action_grid.add_theme_constant_override(
			"v_separation",
			7
		)
		body.add_child(
			action_grid
		)

		for raw_action in actions:
			if typeof(raw_action) != TYPE_DICTIONARY:
				continue

			var action: Dictionary = (
				raw_action as Dictionary
			)
			var button:= Button.new()

			button.text = str(
				action.get(
					"label",
					"Select"
				)
			)

			button.focus_mode = Control.FOCUS_NONE
			button.disabled = not bool(
				action.get(
					"enabled",
					true
				)
			)
			button.size_flags_horizontal = (
				Control.SIZE_EXPAND_FILL
			)

			_apply_crime_button_visuals(
				button,
				false
			)

			var action_id: String = str(
				action.get(
					"id",
					""
				)
			).strip_edges().to_lower()

			var body_surface_contract: Dictionary = (
				_shallow_dictionary(
					row.get(
						"body_surface_contract",
						{}
					)
				)
			)

			if (
				action_id == "show_resident_crime_methods"
				and method_grid != null
			):
				button.pressed.connect(
					Callable(
						self,
						"_toggle_resident_crime_method_grid"
					).bind(
						method_grid
					)
				)

			elif (
				action_id == "choose_weapon_target"
				and not body_surface_contract.is_empty()
			):
				button.pressed.connect(
					_on_resident_weapon_target_pressed.bind(
						int(
							row.get(
								"target_id",
								-1
							)
						)
					)
				)

			else:
				button.pressed.connect(
					Callable(
						self,
						"_on_action_pressed"
					).bind(
						action.duplicate(false),
						row.duplicate(false)
					)
				)

			action_grid.add_child(
				button
			)

	if method_grid != null:
		body.add_child(
			method_grid
		)

	if (
		actions.is_empty()
		and int(
			row.get(
				"target_id",
				-1
			)
		) > 0
		and not is_target_card
	):
		var profile_button:= Button.new()
		profile_button.text = "VIEW PERSON"
		profile_button.focus_mode = (
			Control.FOCUS_NONE
		)

		_apply_crime_button_visuals(
			profile_button,
			false
		)

		profile_button.pressed.connect(
			Callable(
				self,
				"_on_person_pressed"
			).bind(
				int(
					row.get(
						"target_id",
						-1
					)
				),
				row.duplicate(false)
			)
		)

		body.add_child(
			profile_button
		)
func apply_section_contract(
	section_id: String,
	section_contract: Dictionary,
	activate: bool = false
) -> void:
	var clean_section: String = str(
		section_id
	).strip_edges().to_lower()

	if (
		clean_section == ""
		or section_contract.is_empty()
	):
		return

	var incoming_surface: Dictionary = (
		section_contract.duplicate(
			false
		)
	)

	var incoming_actor_id: int = int(
		incoming_surface.get(
			"actor_id",
			-1
		)
	)

	var current_actor_id: int = int(
		active_contract.get(
			"actor_id",
			-1
		)
	)






	if (
		incoming_actor_id > 0
		and incoming_actor_id != current_actor_id
	):
		section_contract_cache.clear()

		crime_section_repaint_generation += 1
		crime_section_repaint_queue.clear()
		crime_section_repaint_keys.clear()
		crime_section_repaint_queue_head = 0
		crime_section_repaint_queue_tail = 0
		crime_section_repaint_service_active = false

		_invalidate_crime_target_bloom_projection()

		active_contract [
			"actor_id"
		] = incoming_actor_id

		active_contract [
			"success"
		] = true

		active_contract [
			"truth_state"
		] = "resident_shell"

		active_contract [
			"projection_composed"
		] = true

		active_contract [
			"hydrated"
		] = false

		active_contract [
			"projection_pending"
		] = true

		active_contract [
			"section_surfaces"
		] = {}

		active_contract [
			"section_rows"
		] = []

		active_contract [
			"interaction_contract"
		] = {}

		active_contract [
			"renderer_chassis_only"
		] = false

	var existing_surface: Dictionary = _shallow_dictionary(
		section_contract_cache.get(
			clean_section,
			{}
		)
	)

	if not _should_adopt_crime_section_surface(
		existing_surface,
		incoming_surface
	):
		if activate:
			_activate_section_surface(
				clean_section,
				false
			)

		return

	section_contract_cache [
		clean_section
	] = incoming_surface

	var surfaces: Dictionary = _shallow_dictionary(
		active_contract.get(
			"section_surfaces",
			{}
		)
	)

	var merged_surfaces: Dictionary = (
		surfaces.duplicate(
			false
		)
	)

	merged_surfaces [
		clean_section
	] = incoming_surface

	active_contract [
		"section_surfaces"
	] = merged_surfaces

	if incoming_actor_id > 0:
		active_contract [
			"actor_id"
		] = incoming_actor_id

	active_contract [
		"success"
	] = true

	active_contract [
		"projection_composed"
	] = true

	var tabs: Array = _safe_array(
		active_contract.get(
			"section_tabs",
			[]
		)
	)

	var resident_count: int = 0
	var observable_count: int = 0
	var complete_count: int = 0

	for raw_tab in tabs:
		if typeof(raw_tab) != TYPE_DICTIONARY:
			continue

		var tab: Dictionary = (
			raw_tab as Dictionary
		)

		var tab_section_id: String = str(
			tab.get(
				"id",
				""
			)
		).strip_edges().to_lower()

		if tab_section_id == "":
			continue

		var resident_contract: Dictionary = _shallow_dictionary(
			section_contract_cache.get(
				tab_section_id,
				{}
			)
		)

		if resident_contract.is_empty():
			continue

		resident_count += 1

		var observable: bool = (
			str(
				resident_contract.get(
					"truth_state",
					""
				)
			).strip_edges().to_lower() == "hot"
			and bool(
				resident_contract.get(
					"hydrated",
					false
				)
			)
		)

		if not observable:
			continue

		observable_count += 1

		if not bool(
			resident_contract.get(
				"projection_pending",
				false
			)
		):
			complete_count += 1

	var section_target_count: int = tabs.size()

	var all_sections_resident: bool = (
		section_target_count > 0
		and resident_count == section_target_count
	)

	var all_sections_observable: bool = (
		section_target_count > 0
		and observable_count == section_target_count
	)

	var all_sections_complete: bool = (
		section_target_count > 0
		and complete_count == section_target_count
	)

	active_contract [
		"resident_section_count"
	] = resident_count

	active_contract [
		"observable_section_count"
	] = observable_count

	active_contract [
		"complete_section_count"
	] = complete_count

	active_contract [
		"section_target_count"
	] = section_target_count

	active_contract [
		"all_sections_resident"
	] = all_sections_resident

	active_contract [
		"all_sections_observable"
	] = all_sections_observable

	active_contract [
		"all_sections_precomposed"
	] = all_sections_complete

	active_contract [
		"truth_state"
	] = (
		"hot"
		if all_sections_observable
		else "resident_shell"
	)

	active_contract [
		"hydrated"
	] = all_sections_observable

	active_contract [
		"projection_pending"
	] = not all_sections_complete

	if str(
		active_contract.get(
			"active_section",
			""
		)
	).strip_edges().to_lower() == clean_section:
		active_contract [
			"section_rows"
		] = incoming_surface.get(
			"section_rows",
			[]
		)

		active_contract [
			"interaction_contract"
		] = incoming_surface.get(
			"interaction_contract",
			{}
		)



	var completion_metadata_only: bool = bool(
		incoming_surface.get(
			"stream_completion_only",
			false
		)
	)

	if (
		clean_section == "targets"
		and not completion_metadata_only
	):
		_invalidate_crime_target_bloom_projection()

	if not completion_metadata_only:
		_queue_crime_section_surface_repaint(
			clean_section
		)

	if activate:
		_activate_section_surface(
			clean_section,
			false
		)

	set_meta(
		"crime_section_delta_complete_hub_rebuild_performed",
		false
	)

	set_meta(
		"crime_section_delta_monotonic_adoption",
		true
	)

	set_meta(
		"crime_section_delta_rendered_in_signal_callback",
		false
	)

	set_meta(
		"crime_section_delta_repaint_queued",
		not completion_metadata_only
	)

	set_meta(
		"crime_section_delta_actor_id",
		incoming_actor_id
	)


func stream_section_row(
	section_id: String,
	row_contract: Dictionary
) -> void:
	var clean_section: String = str(
		section_id
	).strip_edges().to_lower()

	if (
		clean_section == ""
		or row_contract.is_empty()
	):
		return

	var section_contract: Dictionary = _shallow_dictionary(
		section_contract_cache.get(
			clean_section,
			{}
		)
	)

	if section_contract.is_empty():
		section_contract = {
			"section_id": clean_section,
			"section_rows": [],
			"interaction_contract": {},
			"truth_state": "hot",
			"hydrated": true
		}

	var rows: Array = _safe_array(
		section_contract.get(
			"section_rows",
			[]
		)
	)
	var interaction: Dictionary = _shallow_dictionary(
		section_contract.get(
			"interaction_contract",
			{}
		)
	)
	var interaction_stage: String = str(
		interaction.get(
			"stage",
			""
		)
	).strip_edges().to_lower()
	var _row_kind: String = str(
		row_contract.get(
			"kind",
			""
		)
	).strip_edges().to_lower()
	var incoming_target_id: int = int(
		row_contract.get(
			"target_id",
			-1
		)
	)
	var incoming_is_target_card: bool = (
		clean_section == "targets"
		and interaction_stage != "choose_body_part"
		and incoming_target_id > 0
	)
	var had_real_target_row: bool = false

	for raw_existing in rows:
		var existing: Dictionary = _shallow_dictionary(
			raw_existing
		)

		if int(
			existing.get(
				"target_id",
				-1
			)
		) > 0:
			had_real_target_row = true
			break

	if incoming_is_target_card:
		var retained_rows: Array = []

		for raw_existing in rows:
			var existing: Dictionary = _shallow_dictionary(
				raw_existing
			)

			if str(
				existing.get(
					"kind",
					""
				)
			).strip_edges().to_lower() == (
				"crime_target_stream_status"
			):
				continue

			retained_rows.append(
				existing
			)

		rows = retained_rows

	var incoming_key: String = _crime_row_identity_key(
		row_contract
	)
	var replaced: bool = false

	for index in range(
		rows.size()
	):
		var existing: Dictionary = _shallow_dictionary(
			rows [
				index
			]
		)

		if (
			_crime_row_identity_key(
				existing
			) != incoming_key
		):
			continue

		rows [
			index
		] = row_contract
		replaced = true
		break

	if not replaced:
		rows.append(
			row_contract
		)

	section_contract [
		"section_rows"
	] = rows

	if (
		not interaction.is_empty()
		and interaction_stage == "choose_target"
	):
		interaction [
			"rows"
		] = rows

		if row_contract.has(
			"target_projection_complete"
		):
			interaction [
				"target_projection_complete"
			] = bool(
				row_contract.get(
					"target_projection_complete",
					false
				)
			)
			interaction [
				"target_projection_pending"
			] = not bool(
				row_contract.get(
					"target_projection_complete",
					false
				)
			)

		if row_contract.has(
			"target_projection_signature"
		):
			interaction [
				"target_projection_signature"
			] = str(
				row_contract.get(
					"target_projection_signature",
					""
				)
			)

		section_contract [
			"interaction_contract"
		] = interaction

	section_contract_cache [
		clean_section
	] = section_contract

	var resident_surface: VBoxContainer = (
		section_surface_nodes.get(
			clean_section,
			null
		) as VBoxContainer
	)

	if (
		resident_surface == null
		or not is_instance_valid(
			resident_surface
		)
	):



		if section_buttons.has(
			clean_section
		):
			_queue_crime_section_surface_repaint(
				clean_section
			)
		return

	if incoming_is_target_card:
		var grid: GridContainer = (
			weapon_target_grid_by_section.get(
				clean_section,
				null
			) as GridContainer
		)

		if (
			grid == null
			or not is_instance_valid(
				grid
			)
		):



			_queue_crime_section_surface_repaint(
				clean_section
			)
			return



		if not had_real_target_row:
			_clear_children(
				grid
			)

		crime_target_bloom_queue.append({
			"generation": (
				crime_target_bloom_generation
			),
			"section_id": clean_section,
			"section_surface": resident_surface,
			"grid": grid,
			"row": row_contract
		})

		_arm_crime_target_bloom_service()

		return

	if not interaction.is_empty():

		return

	_queue_streamed_crime_section_row_paint(
		clean_section,
		row_contract
	)

func _queue_streamed_crime_section_row_paint(
	section_id: String,
	row_contract: Dictionary
) -> void:
	var tree:= Engine.get_main_loop() as SceneTree

	if tree == null:
		return

	var callback:= Callable(
		self,
		"_paint_streamed_crime_section_row_on_process_frame"
	).bind(
		section_id,
		row_contract.duplicate(
			false
		)
	)

	if tree.process_frame.is_connected(
		callback
	):
		return

	tree.process_frame.connect(
		callback,
		CONNECT_ONE_SHOT
	)


func _paint_streamed_crime_section_row_on_process_frame(
	section_id: String,
	row_contract: Dictionary
) -> void:
	_paint_streamed_crime_section_row(
		section_id,
		row_contract
	)

	if OS.is_debug_build():
		EraLog.truth(
			"ERALIFE_CRIME_PIPELINE_TRUTH"
			+ "|authority=CrimePanel"
			+ "|stage=section_row_painted"
			+ "|section=%s" % section_id
			+ "|kind=%s" % str(
				row_contract.get(
					"kind",
					""
				)
			)
			+ "|target_id=%d" % int(
				row_contract.get(
					"target_id",
					-1
				)
			)
			+ "|at_ms=%d" % int(
				Time.get_ticks_msec()
			)
		)
func _paint_streamed_crime_section_row(
	section_id: String,
	row_contract: Dictionary
) -> void:
	var resident_surface: VBoxContainer = (
		section_surface_nodes.get(
			section_id,
			null
		) as VBoxContainer
	)

	if (
		resident_surface == null
		or not is_instance_valid(resident_surface)
	):
		return

	var row_kind: String = str(
		row_contract.get(
			"kind",
			""
		)
	).strip_edges().to_lower()



	if (
		section_id == "targets"
		and row_kind == "crime_target_stream_status"
	):
		var grid: GridContainer = (
			weapon_target_grid_by_section.get(
				section_id,
				null
			) as GridContainer
		)

		if (
			grid != null
			and is_instance_valid(grid)
		):
			_clear_children(
				grid
			)
			_render_row_into(
				grid,
				row_contract
			)

			set_meta(
				"crime_live_row_bloomed",
				true
			)
			set_meta(
				"crime_live_row_bloomed_at_ms",
				int(
					Time.get_ticks_msec()
				)
			)
			return

		var target_completion_status: Node = resident_surface.get_node_or_null(
			"CrimeSectionStatus"
		)

		if (
			target_completion_status != null
			and is_instance_valid(target_completion_status)
		):
			resident_surface.remove_child(
				target_completion_status
			)
			target_completion_status.queue_free()

		_render_row_into(
			resident_surface,
			row_contract
		)

		set_meta(
			"crime_live_row_bloomed",
			true
		)
		set_meta(
			"crime_live_row_bloomed_at_ms",
			int(
				Time.get_ticks_msec()
			)
		)
		return





	if crime_section_repaint_keys.has(
		section_id
	):
		return

	var pending_status: Node = resident_surface.get_node_or_null(
		"CrimeSectionStatus"
	)

	if (
		pending_status != null
		and is_instance_valid(pending_status)
	):
		resident_surface.remove_child(
			pending_status
		)
		pending_status.queue_free()

	_render_row_into(
		resident_surface,
		row_contract
	)

	set_meta(
		"crime_live_row_bloomed",
		true
	)
	set_meta(
		"crime_live_row_bloomed_at_ms",
		int(
			Time.get_ticks_msec()
		)
	)
func _crime_row_identity_key(
	row: Dictionary
) -> String:
	var item: Dictionary = _shallow_dictionary(
		row.get(
			"item",
			row
		)
	)

	var item_id: int = int(
		item.get(
			"id",
			row.get(
				"item_id",
				-1
			)
		)
	)

	if item_id > 0:
		return "item:%d" % item_id

	var target_id: int = int(
		row.get(
			"target_id",
			-1
		)
	)

	if target_id > 0:
		return "target:%d" % target_id

	return "%s:%s" % [
		str(
			row.get(
				"kind",
				"row"
			)
		),
		str(
			row.get(
				"label",
				""
			)
		)
	]
func _activate_section_surface(
	section_id: String,
	emit_observation: bool = true
) -> void:
	var clean_section: String = str(
		section_id
	).strip_edges().to_lower()

	if clean_section == "":
		clean_section = "overview"

	if not section_surface_nodes.has(
		clean_section
	):
		return

	for raw_section_id in section_surface_nodes.keys():
		var resident_section_id: String = str(
			raw_section_id
		)
		var section_surface: VBoxContainer = (
			section_surface_nodes.get(
				raw_section_id,
				null
			) as VBoxContainer
		)

		if (
			section_surface != null
			and is_instance_valid(
				section_surface
			)
		):
			section_surface.visible = (
				resident_section_id == clean_section
			)

	for raw_section_id in section_buttons.keys():
		var resident_section_id: String = str(
			raw_section_id
		)
		var section_button: Button = (
			section_buttons.get(
				raw_section_id,
				null
			) as Button
		)

		if (
			section_button != null
			and is_instance_valid(
				section_button
			)
		):
			section_button.set_pressed_no_signal(
				resident_section_id == clean_section
			)

	var surface: Dictionary = _shallow_dictionary(
		section_contract_cache.get(
			clean_section,
			{}
		)
	)
	active_contract ["active_section"] = clean_section
	active_contract ["section_rows"] = surface.get(
		"section_rows",
		[]
	)
	active_contract ["interaction_contract"] = surface.get(
		"interaction_contract",
		{}
	)

	set_meta(
		"crime_panel_last_local_section_reveal",
		clean_section
	)
	set_meta(
		"crime_panel_last_local_section_reveal_at_ms",
		int(Time.get_ticks_msec())
	)
	set_meta(
		"crime_panel_section_engine_call_performed",
		false
	)
	set_meta(
		"crime_panel_section_controls_created_on_press",
		false
	)
	set_meta(
		"crime_panel_section_visibility_swap_only",
		true
	)

	if emit_observation:
		section_requested.emit(
			clean_section
		)


func has_resident_section_deck(
	actor_id: int = -1
) -> bool:
	if active_contract.is_empty():
		return false

	if not bool(
		active_contract.get(
			"success",
			false
		)
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

	var tabs: Array = _safe_array(
		active_contract.get(
			"section_tabs",
			[]
		)
	)

	if tabs.is_empty():
		return false

	var resident_section_count: int = 0

	for raw_tab in tabs:
		if typeof(raw_tab) != TYPE_DICTIONARY:
			return false

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
			return false




		if not section_surface_nodes.has(
			section_id
		):
			return false

		var surface: Dictionary = _shallow_dictionary(
			section_contract_cache.get(
				section_id,
				{}
			)
		)




		if surface.is_empty():
			continue

		var surface_actor_id: int = int(
			surface.get(
				"actor_id",
				actor_id
			)
		)

		if (
			actor_id > 0
			and surface_actor_id > 0
			and surface_actor_id != actor_id
		):
			return false

		resident_section_count += 1



	return resident_section_count > 0
func has_observable_section_deck(
	actor_id: int = -1
) -> bool:
	if not has_renderable_contract(
		actor_id
	):
		return false

	var tabs: Array = _safe_array(
		active_contract.get(
			"section_tabs",
			[]
		)
	)

	if tabs.is_empty():
		return false

	for raw_tab in tabs:
		if typeof(raw_tab) != TYPE_DICTIONARY:
			return false

		var tab: Dictionary = raw_tab as Dictionary
		var section_id: String = str(
			tab.get(
				"id",
				""
			)
		).strip_edges().to_lower()

		if section_id == "":
			return false

		var surface: Dictionary = _shallow_dictionary(
			section_contract_cache.get(
				section_id,
				{}
			)
		)





		if (
			surface.is_empty()
			or not section_surface_nodes.has(
				section_id
			)
			or str(
				surface.get(
					"truth_state",
					""
				)
			) != "hot"
			or not bool(
				surface.get(
					"hydrated",
					false
				)
			)
		):
			return false

	return true
func _on_close_pressed() -> void:
	close_requested.emit()


func _on_section_pressed(
	section_id: String
) -> void:
	_activate_section_surface(
		section_id,
		true
	)

func _on_action_pressed(
	action: Dictionary,
	row: Dictionary
) -> void:
	var payload_raw: Variant = action.get(
		"payload",
		{}
	)
	var payload: Dictionary = (
		(
			payload_raw as Dictionary
		).duplicate(false)
		if typeof(
			payload_raw
		) == TYPE_DICTIONARY
		else {}
	)
	var interaction_raw: Variant = (
		active_contract.get(
			"interaction_contract",
			{}
		)
	)
	var interaction: Dictionary = (
		interaction_raw as Dictionary
		if typeof(
			interaction_raw
		) == TYPE_DICTIONARY
		else {}
	)
	var shared_raw: Variant = interaction.get(
		"shared_payload",
		{}
	)
	var shared_payload: Dictionary = (
		shared_raw as Dictionary
		if typeof(
			shared_raw
		) == TYPE_DICTIONARY
		else {}
	)

	for raw_key in shared_payload.keys():
		if payload.has(
			raw_key
		):
			continue

		payload [
			raw_key
		] = shared_payload.get(
			raw_key
		)

	payload ["action_id"] = str(
		payload.get(
			"action_id",
			action.get(
				"id",
				""
			)
		)
	)
	payload ["source"] = "crime_panel"
	payload ["row_context"] = {
		"kind": str(
			row.get(
				"kind",
				""
			)
		),
		"target_id": int(
			row.get(
				"target_id",
				-1
			)
		),
		"body_part": str(
			row.get(
				"body_part",
				""
			)
		),
		"label": str(
			row.get(
				"label",
				""
			)
		)
	}
	payload [
		"immutable_contract_references"
	] = true

	action_requested.emit(
		payload
	)


func _on_person_pressed(
	target_id: int,
	row: Dictionary
) -> void:
	person_requested.emit(
		target_id,
		row
	)


func _clear_children(
	parent: Node
) -> void:
	if parent == null:
		return

	for child in parent.get_children():
		child.queue_free()


func _shallow_dictionary(
		value: Variant
) -> Dictionary:
	if typeof(
		value
	) == TYPE_DICTIONARY:
		return (
			value as Dictionary
		).duplicate(false)

	return {}


func _safe_array(
		value: Variant
) -> Array:
	if typeof(
		value
	) == TYPE_ARRAY:
		return (
			value as Array
		).duplicate(false)

	return []