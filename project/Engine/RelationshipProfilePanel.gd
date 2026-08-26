extends Control
class_name RelationshipProfilePanel

signal request_back
signal request_switch(
	target_id: int,
	switch_packet: Dictionary
)
signal resident_switch_packet_installed(
	target_id: int,
	switch_packet: Dictionary
)
signal request_edit(
	target_id: int
)
signal request_action(
	action_id: String,
	target_id: int
)

const PANEL_SCHEMA:= (
	"eralife.relationship_profile.panel"
)
const PANEL_VERSION:= 1
const ACTION_BUTTON_POOL_SIZE:= 32
const HIGH_STAT_PULSE_RATIO:= 0.85
const STAT_PULSE_SPEED:= 4.2
const STAT_PULSE_AMOUNT:= 0.2
const SCROLL_STEP_PIXELS:= 74
const PAN_SCROLL_SCALE:= 42.0

var active_contract: Dictionary = {}
var active_target_id: int = -1
var stat_pulse_time: float = 0.0
var dim: ColorRect = null
var card: PanelContainer = null

var back_button: Button = null
var bank_label: Label = null
var title_label: Label = null
var switch_button: Button = null
var edit_button: Button = null

var stats_grid: GridContainer = null
var stat_rows_by_id: Dictionary = {}

var profile_scroll: ScrollContainer = null
var profile_text: RichTextLabel = null

var actions_scroll: ScrollContainer = null
var actions_box: VBoxContainer = null
var action_button_pool: Array = []
var status_label: Label = null


func _ready() -> void:
	name = "RelationshipProfilePanel"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_INHERIT
	z_as_relative = false
	z_index = 1300

	set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	set_meta(
		"schema",
		PANEL_SCHEMA
	)
	set_meta(
		"version",
		PANEL_VERSION
	)
	set_meta(
		"ui_is_renderer_only",
		true
	)
	set_meta(
		"visible_press_build_forbidden",
		true
	)
	set_meta(
		"touchpad_scroll_enabled",
		true
	)
	set_meta(
		"mouse_wheel_scroll_enabled",
		true
	)

	_build_shell_once()
	set_process(true)
func _process(
	delta: float
) -> void:
	if not visible:
		return

	stat_pulse_time += delta

	var pulse_phase: float = (
		0.55
		+ (
			0.45
			* (
				(
					sin(
						stat_pulse_time
						* STAT_PULSE_SPEED
					)
					+ 1.0
				)
				* 0.5
			)
		)
	)

	for raw_stat_id in stat_rows_by_id.keys():
		var row_raw: Variant = stat_rows_by_id.get(
			raw_stat_id,
			{}
		)

		if typeof(row_raw) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = row_raw as Dictionary
		var stat_id: String = str(
			row.get(
				"stat_id",
				raw_stat_id
			)
		)
		var ratio: float = clampf(
			float(
				row.get(
					"ratio",
					0.0
				)
			),
			0.0,
			1.0
		)
		var base_color: Color = row.get(
			"base_fill_color",
			Color.WHITE
		)
		var fill_style:= row.get(
			"fill_style",
			null
		) as StyleBoxFlat

		if fill_style == null:
			continue

		var pulse_strength: float = (
			ratio
			* pulse_phase
			* STAT_PULSE_AMOUNT
		)

		if stat_id == "health":
			pulse_strength *= 1.45

		fill_style.bg_color = base_color.lerp(
			Color(
				1.0,
				1.0,
				1.0,
				base_color.a
			),
			clampf(
				pulse_strength,
				0.0,
				0.34
			)
		)
		fill_style.shadow_color = Color(
			base_color.r,
			base_color.g,
			base_color.b,
			0.06
			+ (
				ratio
				* pulse_phase
				* 0.52
			)
		)
		fill_style.shadow_size = int(
			round(
				2.0
				+ (
					ratio
					* pulse_phase
					* 12.0
				)
			)
		)


func open_contract(
	profile_contract: Dictionary
) -> void:
	render_contract(
		profile_contract
	)

	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_INHERIT
	z_index = 1300

	var panel_parent: Node = get_parent()

	if panel_parent != null:
		panel_parent.move_child(
			self,
			panel_parent.get_child_count() - 1
		)

	set_meta(
		"profile_revealed_at_ms",
		int(
			Time.get_ticks_msec()
		)
	)
	set_meta(
		"profile_press_built_controls",
		false
	)

func close_panel() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	set_meta(
		"profile_closed_at_ms",
		int(
			Time.get_ticks_msec()
		)
	)
	set_meta(
		"profile_is_visible",
		false
	)


func render_contract(
	profile_contract: Dictionary
) -> void:
	active_contract = (
		profile_contract.duplicate(false)
	)
	active_target_id = int(
		active_contract.get(
			"target_id",
			-1
		)
	)

	title_label.text = str(
		active_contract.get(
			"title",
			active_contract.get(
				"target_name",
				"Relationship Profile"
			)
		)
	)
	bank_label.text = str(
		active_contract.get(
			"bank_text",
			"$0"
		)
	)
	switch_button.text = str(
		active_contract.get(
			"switch_label",
			"SWITCH TO THEM"
		)
	)
	edit_button.text = str(
		active_contract.get(
			"edit_label",
			"EDIT THEM"
		)
	)




	var target_alive: bool = bool(
		active_contract.get(
			"target_alive",
			true
		)
	)
	var semantic_can_switch: bool = (
		target_alive
		and bool(
			active_contract.get(
				"switch_semantically_available",
				active_contract.get(
					"can_switch",
					false
				)
			)
		)
	)
	var semantic_can_edit: bool = (
		target_alive
		and bool(
			active_contract.get(
				"edit_semantically_available",
				active_contract.get(
					"can_edit",
					true
				)
			)
		)
	)

	var switch_packet: Dictionary = _safe_dictionary(
		active_contract.get(
			"switch_packet",
			{}
		)
	)

	if not semantic_can_switch:
		switch_packet = {}
		active_contract [
			"switch_packet"
		] = {}
		active_contract [
			"switch_packet_hot"
		] = false
		active_contract [
			"switch_packet_core_hot"
		] = false
		active_contract [
			"can_switch"
		] = false

	var switch_surface: Dictionary = _safe_dictionary(
		switch_packet.get(
			"surface_contract",
			{}
		)
	)
	var switch_support_packet: Dictionary = _safe_dictionary(
		switch_packet.get(
			"control_switch_support_surface_packet",
			switch_surface.get(
				"control_switch_support_surface_packet",
				{}
			)
		)
	)
	var switch_main_tab_deck: Dictionary = _safe_dictionary(
		switch_packet.get(
			"main_tab_surface_contracts",
			switch_surface.get(
				"main_tab_surface_contracts",
				{}
			)
		)
	)
	var packet_revision: String = str(
		switch_packet.get(
			"pointer_revision",
			switch_surface.get(
				"pointer_revision",
				""
			)
		)
	).strip_edges()
	var surface_revision: String = str(
		switch_surface.get(
			"pointer_revision",
			""
		)
	).strip_edges()
	var press_frame_lens_cache: Dictionary = _safe_dictionary(
		switch_packet.get(
			"press_frame_lens_cache",
			switch_surface.get(
				"press_frame_lens_cache",
				{}
			)
		)
	)
	var pointer_only_packet: bool = bool(
		switch_packet.get(
			"pointer_only_profile_packet",
			switch_surface.get(
				"pointer_only_profile_packet",
				switch_surface.get(
					"pointer_only",
					false
				)
			)
		)
	)
	var diary_lines: Array = _safe_array(
		switch_packet.get(
			"life_diary_lines",
			switch_surface.get(
				"life_diary_lines",
				[]
			)
		)
	)
	var diary_signature: String = str(
		switch_packet.get(
			"life_diary_signature",
			switch_surface.get(
				"life_diary_signature",
				""
			)
		)
	).strip_edges()

	var switch_packet_core_hot: bool = (
		semantic_can_switch
		and not switch_packet.is_empty()
		and not switch_surface.is_empty()
		and int(
			switch_packet.get(
				"actor_id",
				-1
			)
		) == active_target_id
		and int(
			switch_surface.get(
				"actor_id",
				-1
			)
		) == active_target_id
		and packet_revision != ""
		and packet_revision == surface_revision
		and bool(
			switch_surface.get(
				"surface_hot",
				true
			)
		)
		and bool(
			switch_surface.get(
				"press_frame_ready",
				true
			)
		)
		and bool(
			switch_packet.get(
				"press_frame_build_forbidden",
				switch_packet.get(
					"switch_press_build_forbidden",
					true
				)
			)
		)
		and (
			press_frame_lens_cache.is_empty()
			or int(
				press_frame_lens_cache.get(
					"actor_id",
					active_target_id
				)
			) == active_target_id
		)
		and (
			pointer_only_packet
			or not diary_lines.is_empty()
			or diary_signature != ""
		)
	)

	var complete_main_tab_count: int = 0

	for raw_tab_id in [
		"relationships",
		"school",
		"activities",
		"career",
		"mods"
	]:
		var tab_id: String = str(
			raw_tab_id
		)
		var tab_contract: Dictionary = _safe_dictionary(
			switch_main_tab_deck.get(
				tab_id,
				{}
			)
		)

		if (
			tab_contract.is_empty()
			or int(
				tab_contract.get(
					"actor_id",
					-1
				)
			) != active_target_id
			or bool(
				tab_contract.get(
					"pointer_only",
					false
				)
			)
			or str(
				tab_contract.get(
					"truth_state",
					""
				)
			).strip_edges().to_lower() == (
				"pointer_only_resident_shell"
			)
		):
			continue

		complete_main_tab_count += 1

	var support_enrichment_hot: bool = (
		switch_packet_core_hot
		and complete_main_tab_count == 5
		and not switch_support_packet.is_empty()
		and int(
			switch_support_packet.get(
				"actor_id",
				active_target_id
			)
		) == active_target_id
	)
	var effective_can_switch: bool = (
		semantic_can_switch
		and switch_packet_core_hot
	)

	active_contract [
		"switch_packet_hot"
	] = switch_packet_core_hot
	active_contract [
		"switch_packet_core_hot"
	] = switch_packet_core_hot
	active_contract [
		"can_switch"
	] = effective_can_switch
	active_contract [
		"switch_semantically_available"
	] = semantic_can_switch
	active_contract [
		"can_edit"
	] = semantic_can_edit
	active_contract [
		"support_deck_blocks_switch"
	] = false

	switch_button.visible = semantic_can_switch
	switch_button.disabled = not effective_can_switch
	switch_button.mouse_filter = (
		Control.MOUSE_FILTER_STOP
		if effective_can_switch
		else Control.MOUSE_FILTER_IGNORE
	)

	set_meta(
		"profile_target_alive",
		target_alive
	)
	set_meta(
		"profile_switch_semantically_available",
		semantic_can_switch
	)
	set_meta(
		"profile_switch_packet_core_hot",
		switch_packet_core_hot
	)
	set_meta(
		"profile_switch_packet_hot",
		switch_packet_core_hot
	)
	set_meta(
		"profile_switch_button_waiting_for_packet",
		(
			semantic_can_switch
			and not switch_packet_core_hot
		)
	)
	set_meta(
		"profile_switch_button_disabled_by_packet",
		(
			semantic_can_switch
			and not switch_packet_core_hot
		)
	)
	set_meta(
		"profile_switch_complete_main_tab_count",
		complete_main_tab_count
	)
	set_meta(
		"profile_switch_support_enrichment_hot",
		support_enrichment_hot
	)
	set_meta(
		"profile_switch_support_deck_blocks_switch",
		false
	)

	edit_button.visible = semantic_can_edit
	edit_button.disabled = not semantic_can_edit
	edit_button.mouse_filter = (
		Control.MOUSE_FILTER_STOP
		if semantic_can_edit
		else Control.MOUSE_FILTER_IGNORE
	)

	var rendered_stat_ids: Dictionary = {}

	for raw_stat in _safe_array(
		active_contract.get(
			"stats",
			[]
		)
	):
		if typeof(raw_stat) != TYPE_DICTIONARY:
			continue

		var stat_contract: Dictionary = (
			(raw_stat as Dictionary).duplicate(false)
		)
		var stat_id: String = str(
			stat_contract.get(
				"stat_id",
				stat_contract.get(
					"id",
					""
				)
			)
		).strip_edges().to_lower()

		if stat_id == "mental_health":
			stat_id = "mental"

		if (
			stat_id == ""
			or not stat_rows_by_id.has(
				stat_id
			)
		):
			continue

		stat_contract [
			"stat_id"
		] = stat_id
		rendered_stat_ids [
			stat_id
		] = true

		_apply_stat_contract(
			stat_id,
			stat_contract
		)

	for raw_stat_id in stat_rows_by_id.keys():
		var clean_stat_id: String = str(
			raw_stat_id
		).strip_edges().to_lower()
		var row: Dictionary = _safe_dictionary(
			stat_rows_by_id.get(
				raw_stat_id,
				{}
			)
		)
		var root: Control = row.get(
			"root",
			null
		) as Control

		if root != null:
			root.visible = bool(
				rendered_stat_ids.get(
					clean_stat_id,
					false
				)
			)

	profile_text.text = str(
		active_contract.get(
			"profile_text",
			(
				"===== PROFILE =====\n"
				+ "No profile truth is currently observable."
			)
		)
	)

	var action_contracts: Array = _safe_array(
		active_contract.get(
			"actions",
			[]
		)
	)

	_apply_action_contracts(
		action_contracts
	)

	var resolved_status_text: String = str(
		active_contract.get(
			"status_text",
			""
		)
	)

	if not target_alive:
		if (
			resolved_status_text == ""
			or resolved_status_text.find(
				"Preparing this viewpoint"
			) >= 0
			or resolved_status_text.find(
				"Viewpoint destination ready"
			) >= 0
		):
			resolved_status_text = (
				"Deceased. Viewpoint switching is unavailable."
			)

	elif semantic_can_switch:
		if not switch_packet_core_hot:
			if (
				resolved_status_text == ""
				or resolved_status_text.find(
					"Preparing this viewpoint"
				) >= 0
			):
				resolved_status_text = (
					"Preparing this viewpoint's resident destination…"
				)

		elif (
			resolved_status_text == ""
			or resolved_status_text.find(
				"Preparing this viewpoint"
			) >= 0
		):
			resolved_status_text = (
				"Viewpoint destination ready."
			)

	status_label.text = resolved_status_text

	set_meta(
		"profile_stats_hot",
		not rendered_stat_ids.is_empty()
	)
	set_meta(
		"profile_stat_count",
		rendered_stat_ids.size()
	)
	set_meta(
		"profile_actions_hot",
		not action_contracts.is_empty()
	)
	set_meta(
		"profile_action_count",
		action_contracts.size()
	)
	set_meta(
		"profile_semantic_switch_allowed",
		semantic_can_switch
	)
	set_meta(
		"profile_switch_button_visible",
		switch_button.visible
	)
	set_meta(
		"profile_switch_button_disabled",
		switch_button.disabled
	)
	set_meta(
		"profile_switch_packet_hot",
		switch_packet_core_hot
	)
	set_meta(
		"profile_edit_button_visible",
		edit_button.visible
	)
	set_meta(
		"profile_edit_button_disabled",
		edit_button.disabled
	)
	set_meta(
		"profile_switch_press_build_forbidden",
		true
	)
	set_meta(
		"profile_recursive_copy_forbidden",
		true
	)

	profile_scroll.scroll_vertical = 0
	actions_scroll.scroll_vertical = 0
func install_resident_switch_packet(
	switch_packet: Dictionary
) -> bool:
	if (
		active_target_id <= 0
		or switch_packet.is_empty()
	):
		return false

	var target_alive: bool = bool(
		active_contract.get(
			"target_alive",
			true
		)
	)
	var semantic_can_switch: bool = (
		target_alive
		and bool(
			active_contract.get(
				"switch_semantically_available",
				active_contract.get(
					"can_switch",
					false
				)
			)
		)
	)




	if not semantic_can_switch:
		var rejected_contract: Dictionary = (
			active_contract.duplicate(false)
		)

		rejected_contract [
			"switch_packet"
		] = {}
		rejected_contract [
			"switch_packet_hot"
		] = false
		rejected_contract [
			"switch_packet_core_hot"
		] = false
		rejected_contract [
			"can_switch"
		] = false
		rejected_contract [
			"switch_semantically_available"
		] = false
		active_contract = rejected_contract

		switch_button.visible = false
		switch_button.disabled = true
		switch_button.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)

		if (
			status_label != null
			and not target_alive
		):
			status_label.text = (
				"Deceased. Viewpoint switching is unavailable."
			)

		set_meta(
			"profile_target_alive",
			target_alive
		)
		set_meta(
			"profile_semantic_switch_allowed",
			false
		)
		set_meta(
			"profile_switch_packet_hot",
			false
		)
		set_meta(
			"profile_switch_packet_core_hot",
			false
		)
		set_meta(
			"profile_switch_button_waiting_for_packet",
			false
		)
		set_meta(
			"profile_switch_button_disabled_by_packet",
			false
		)
		set_meta(
			"profile_switch_packet_rejected_by_lifecycle",
			true
		)

		return false

	var previous_packet: Dictionary = _safe_dictionary(
		active_contract.get(
			"switch_packet",
			{}
		)
	)
	var previous_surface: Dictionary = _safe_dictionary(
		previous_packet.get(
			"surface_contract",
			{}
		)
	)
	var previous_revision: String = str(
		previous_packet.get(
			"pointer_revision",
			previous_surface.get(
				"pointer_revision",
				""
			)
		)
	).strip_edges()
	var previous_support_packet: Dictionary = _safe_dictionary(
		previous_packet.get(
			"control_switch_support_surface_packet",
			previous_surface.get(
				"control_switch_support_surface_packet",
				{}
			)
		)
	)
	var previous_support_deck_hot: bool = bool(
		previous_packet.get(
			"main_tab_surface_deck_hot",
			previous_surface.get(
				"main_tab_surface_deck_hot",
				false
			)
		)
	)
	var previous_complete_destination_visible: bool = (
		previous_support_deck_hot
		and not previous_support_packet.is_empty()
	)
	var surface_contract: Dictionary = _safe_dictionary(
		switch_packet.get(
			"surface_contract",
			{}
		)
	)
	var packet_revision: String = str(
		switch_packet.get(
			"pointer_revision",
			surface_contract.get(
				"pointer_revision",
				""
			)
		)
	).strip_edges()
	var surface_revision: String = str(
		surface_contract.get(
			"pointer_revision",
			""
		)
	).strip_edges()
	var press_frame_lens_cache: Dictionary = _safe_dictionary(
		switch_packet.get(
			"press_frame_lens_cache",
			surface_contract.get(
				"press_frame_lens_cache",
				{}
			)
		)
	)
	var pointer_only_packet: bool = bool(
		switch_packet.get(
			"pointer_only_profile_packet",
			surface_contract.get(
				"pointer_only",
				false
			)
		)
	)
	var diary_lines: Array = _safe_array(
		switch_packet.get(
			"life_diary_lines",
			surface_contract.get(
				"life_diary_lines",
				[]
			)
		)
	)
	var diary_signature: String = str(
		switch_packet.get(
			"life_diary_signature",
			surface_contract.get(
				"life_diary_signature",
				""
			)
		)
	).strip_edges()
	var support_packet: Dictionary = _safe_dictionary(
		switch_packet.get(
			"control_switch_support_surface_packet",
			surface_contract.get(
				"control_switch_support_surface_packet",
				{}
			)
		)
	)
	var support_deck_hot: bool = bool(
		switch_packet.get(
			"main_tab_surface_deck_hot",
			surface_contract.get(
				"main_tab_surface_deck_hot",
				false
			)
		)
	)
	var packet_hot: bool = (
		semantic_can_switch
		and int(
			switch_packet.get(
				"actor_id",
				-1
			)
		) == active_target_id
		and int(
			surface_contract.get(
				"actor_id",
				-1
			)
		) == active_target_id
		and packet_revision != ""
		and packet_revision == surface_revision
		and bool(
			surface_contract.get(
				"surface_hot",
				true
			)
		)
		and bool(
			surface_contract.get(
				"press_frame_ready",
				true
			)
		)
		and bool(
			switch_packet.get(
				"press_frame_build_forbidden",
				true
			)
		)
		and (
			press_frame_lens_cache.is_empty()
			or int(
				press_frame_lens_cache.get(
					"actor_id",
					active_target_id
				)
			) == active_target_id
		)
		and (
			pointer_only_packet
			or not diary_lines.is_empty()
			or diary_signature != ""
		)
	)

	EraLog.truth(
		"PROFILE_PACKET_VISIBLE"
		+ "|actor_id=" + str(active_target_id)
		+ "|packet_hot=" + str(packet_hot).to_lower()
		+ "|pointer_revision=" + packet_revision
		+ "|support_deck_hot="
		+ str(support_deck_hot).to_lower()
		+ "|support_blocks_switch=false"
		+ "|build_on_press=false"
		+ "|at_ms=" + str(Time.get_ticks_msec())
	)

	if not packet_hot:
		return false

	var complete_destination_visible: bool = (
		support_deck_hot
		and not support_packet.is_empty()
	)
	var publication_transition: bool = (
		complete_destination_visible
		and (
			packet_revision != previous_revision
			or not previous_complete_destination_visible
		)
	)
	var updated_contract: Dictionary = (
		active_contract.duplicate(false)
	)

	updated_contract [
		"switch_packet"
	] = switch_packet.duplicate(false)
	updated_contract [
		"switch_packet_hot"
	] = true
	updated_contract [
		"switch_packet_core_hot"
	] = true



	updated_contract [
		"switch_semantically_available"
	] = semantic_can_switch
	updated_contract [
		"can_switch"
	] = semantic_can_switch
	updated_contract [
		"resident_actor_renderer_deck_hot"
	] = bool(
		switch_packet.get(
			"main_tab_surface_deck_hot",
			surface_contract.get(
				"main_tab_surface_deck_hot",
				false
			)
		)
	)
	updated_contract [
		"support_deck_blocks_switch"
	] = false
	active_contract = updated_contract

	switch_button.visible = semantic_can_switch
	switch_button.disabled = not semantic_can_switch
	switch_button.mouse_filter = (
		Control.MOUSE_FILTER_STOP
		if semantic_can_switch
		else Control.MOUSE_FILTER_IGNORE
	)

	if status_label != null:
		if status_label.text.find(
			"continues enriching"
		) >= 0:
			status_label.text = ""

	set_meta(
		"profile_target_alive",
		target_alive
	)
	set_meta(
		"profile_semantic_switch_allowed",
		semantic_can_switch
	)
	set_meta(
		"profile_switch_packet_hot",
		true
	)
	set_meta(
		"profile_switch_packet_core_hot",
		true
	)
	set_meta(
		"profile_switch_button_waiting_for_packet",
		false
	)
	set_meta(
		"profile_switch_button_disabled_by_packet",
		false
	)
	set_meta(
		"profile_switch_support_deck_blocks_switch",
		false
	)
	set_meta(
		"profile_complete_destination_packet_visible",
		complete_destination_visible
	)
	set_meta(
		"profile_complete_destination_packet_revision",
		packet_revision
	)

	if publication_transition:
		set_meta(
			"profile_complete_destination_packet_transition_at_ms",
			int(
				Time.get_ticks_msec()
			)
		)
		resident_switch_packet_installed.emit(
			active_target_id,
			switch_packet.duplicate(false)
		)

		EraLog.truth(
			"PROFILE_PACKET_REPLACED"
			+ "|actor_id=" + str(active_target_id)
			+ "|pointer_revision=" + packet_revision
			+ "|support_deck_hot=true"
			+ "|renderer_prewarm_notification=true"
			+ "|build_on_press=false"
			+ "|at_ms=" + str(Time.get_ticks_msec())
		)

	return true
func set_status(
	status_text: String
) -> void:
	if status_label != null:
		status_label.text = status_text


func _build_shell_once() -> void:
	dim = ColorRect.new()
	dim.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	dim.color = Color(
		0.0,
		0.0,
		0.0,
		0.78
	)
	dim.mouse_filter = (
		Control.MOUSE_FILTER_STOP
	)
	add_child(dim)

	card = PanelContainer.new()
	card.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	card.offset_left = 18
	card.offset_top = 18
	card.offset_right = -18
	card.offset_bottom = -18
	card.mouse_filter = (
		Control.MOUSE_FILTER_STOP
	)
	card.add_theme_stylebox_override(
		"panel",
		_outer_panel_style()
	)
	add_child(card)
	card.gui_input.connect(
		_on_scroll_surface_gui_input
	)
	var margin:= MarginContainer.new()
	margin.add_theme_constant_override(
		"margin_left",
		18
	)
	margin.add_theme_constant_override(
		"margin_right",
		18
	)
	margin.add_theme_constant_override(
		"margin_top",
		16
	)
	margin.add_theme_constant_override(
		"margin_bottom",
		16
	)
	card.add_child(margin)

	var root:= VBoxContainer.new()
	root.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	root.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	root.add_theme_constant_override(
		"separation",
		10
	)
	margin.add_child(root)

	var top_bar:= HBoxContainer.new()
	top_bar.add_theme_constant_override(
		"separation",
		8
	)
	root.add_child(top_bar)

	back_button = Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = (
		Vector2(
			112,
			42
		)
	)
	_style_action_button(
		back_button
	)
	back_button.pressed.connect(
		func () -> void:

			close_panel()
			request_back.emit()
	)
	top_bar.add_child(back_button)

	bank_label = Label.new()
	bank_label.text = "$0"
	bank_label.custom_minimum_size = (
		Vector2(
			168,
			42
		)
	)
	bank_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	bank_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)
	bank_label.add_theme_font_size_override(
		"font_size",
		15
	)
	bank_label.add_theme_color_override(
		"font_color",
		Color(
			0.82,
			1.0,
			0.88,
			1.0
		)
	)
	top_bar.add_child(bank_label)

	title_label = Label.new()
	title_label.text = (
		"Relationship Profile"
	)
	title_label.custom_minimum_size = (
		Vector2(
			0,
			42
		)
	)
	title_label.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	title_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	title_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)
	title_label.clip_text = true
	title_label.add_theme_font_size_override(
		"font_size",
		24
	)
	title_label.add_theme_color_override(
		"font_color",
		Color(
			1.0,
			0.88,
			0.96,
			1.0
		)
	)
	top_bar.add_child(title_label)

	switch_button = Button.new()
	switch_button.text = (
		"SWITCH TO THEM"
	)
	switch_button.custom_minimum_size = (
		Vector2(
			168,
			42
		)
	)
	_style_action_button(
		switch_button
	)
	switch_button.pressed.connect(
		func () -> void:
			if active_target_id <= 0:
				return




			if bool(
				switch_button.get_meta(
					"switch_release_request_suppressed",
					false
				)
			):
				switch_button.set_meta(
					"switch_release_request_suppressed",
					false
				)

				EraLog.truth(
					"RELATIONSHIP_SWITCH_RELEASE_DUPLICATE_SUPPRESSED"
					+ "|actor_id=" + str(active_target_id)
					+ "|button_down_owned_intent=true"
					+ "|second_route_emitted=false"
					+ "|build_on_press=false"
					+ "|at_ms=" + str(Time.get_ticks_msec())
				)
				return

			var switch_packet: Dictionary = (
				_safe_dictionary(
					active_contract.get(
						"switch_packet",
						{}
					)
				)
			)

			request_switch.emit(
				active_target_id,
				switch_packet
			)
	)
	top_bar.add_child(switch_button)

	edit_button = Button.new()
	edit_button.text = "EDIT THEM"
	edit_button.custom_minimum_size = (
		Vector2(
			130,
			42
		)
	)
	_style_action_button(
		edit_button
	)
	edit_button.pressed.connect(
		func () -> void:
			if active_target_id > 0:
				request_edit.emit(
					active_target_id
				)
	)
	top_bar.add_child(edit_button)

	var stats_panel:= PanelContainer.new()
	stats_panel.custom_minimum_size = (
		Vector2(
			0,
			154
		)
	)
	stats_panel.add_theme_stylebox_override(
		"panel",
		_stats_panel_style()
	)
	root.add_child(stats_panel)

	var stats_margin:= MarginContainer.new()
	stats_margin.add_theme_constant_override(
		"margin_left",
		14
	)
	stats_margin.add_theme_constant_override(
		"margin_right",
		14
	)
	stats_margin.add_theme_constant_override(
		"margin_top",
		12
	)
	stats_margin.add_theme_constant_override(
		"margin_bottom",
		12
	)
	stats_panel.add_child(stats_margin)

	stats_grid = GridContainer.new()
	stats_grid.columns = 3
	stats_grid.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	stats_grid.add_theme_constant_override(
		"h_separation",
		18
	)
	stats_grid.add_theme_constant_override(
		"v_separation",
		12
	)
	stats_margin.add_child(stats_grid)

	for stat_definition in [
		{
			"id": "bond",
			"title": "BOND"
		},
		{
			"id": "hunger",
			"title": "HUNGER"
		},
		{
			"id": "health",
			"title": "HEALTH"
		},
		{
			"id": "mental",
			"title": "MENTAL"
		},
		{
			"id": "smarts",
			"title": "SMARTS"
		},
		{
			"id": "looks",
			"title": "LOOKS"
		}
	]:
		_create_stat_row(
			str(stat_definition ["id"]),
			str(stat_definition ["title"])
		)

	var body_grid:= GridContainer.new()
	body_grid.columns = 2
	body_grid.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	body_grid.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	body_grid.add_theme_constant_override(
		"h_separation",
		12
	)
	root.add_child(body_grid)

	var profile_panel:= PanelContainer.new()
	profile_panel.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	profile_panel.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	profile_panel.add_theme_stylebox_override(
		"panel",
		_child_panel_style()
	)
	body_grid.add_child(profile_panel)

	var profile_margin:= MarginContainer.new()
	profile_margin.add_theme_constant_override(
		"margin_left",
		12
	)
	profile_margin.add_theme_constant_override(
		"margin_right",
		12
	)
	profile_margin.add_theme_constant_override(
		"margin_top",
		10
	)
	profile_margin.add_theme_constant_override(
		"margin_bottom",
		10
	)
	profile_panel.add_child(profile_margin)

	profile_scroll = ScrollContainer.new()
	profile_scroll.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	profile_scroll.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	profile_scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)
	profile_scroll.vertical_scroll_mode = (
		ScrollContainer.SCROLL_MODE_AUTO
	)
	profile_margin.add_child(
		profile_scroll
	)

	profile_text = RichTextLabel.new()
	profile_text.bbcode_enabled = false
	profile_text.fit_content = false
	profile_text.scroll_active = false
	profile_text.custom_minimum_size = (
		Vector2(
			0,
			900
		)
	)
	profile_text.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	profile_text.add_theme_font_size_override(
		"normal_font_size",
		15
	)
	profile_text.add_theme_color_override(
		"default_color",
		Color(
			0.92,
			0.93,
			1.0,
			0.94
		)
	)
	profile_scroll.add_child(
		profile_text
	)
	profile_text.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	var action_panel:= PanelContainer.new()
	action_panel.custom_minimum_size = (
		Vector2(
			390,
			0
		)
	)
	action_panel.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	action_panel.add_theme_stylebox_override(
		"panel",
		_child_panel_style()
	)
	body_grid.add_child(action_panel)

	var action_margin:= MarginContainer.new()
	action_margin.add_theme_constant_override(
		"margin_left",
		12
	)
	action_margin.add_theme_constant_override(
		"margin_right",
		12
	)
	action_margin.add_theme_constant_override(
		"margin_top",
		10
	)
	action_margin.add_theme_constant_override(
		"margin_bottom",
		10
	)
	action_panel.add_child(action_margin)

	var action_root:= VBoxContainer.new()
	action_root.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	action_root.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	action_root.add_theme_constant_override(
		"separation",
		8
	)
	action_margin.add_child(action_root)

	var activity_title:= Label.new()
	activity_title.text = (
		"Relationship Activities"
	)
	activity_title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	activity_title.add_theme_font_size_override(
		"font_size",
		18
	)
	activity_title.add_theme_color_override(
		"font_color",
		Color(
			1.0,
			0.78,
			0.92,
			1.0
		)
	)
	action_root.add_child(activity_title)

	actions_scroll = ScrollContainer.new()
	actions_scroll.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	actions_scroll.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	actions_scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)
	actions_scroll.vertical_scroll_mode = (
		ScrollContainer.SCROLL_MODE_AUTO
	)
	action_root.add_child(
		actions_scroll
	)

	actions_box = VBoxContainer.new()
	actions_box.custom_minimum_size = (
		Vector2(
			0,
			900
		)
	)
	actions_box.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	actions_box.add_theme_constant_override(
		"separation",
		6
	)
	actions_scroll.add_child(
		actions_box
	)
	actions_scroll.gui_input.connect(
		_on_scroll_surface_gui_input
	)
	for button_index in range(
		ACTION_BUTTON_POOL_SIZE
	):
		var action_button:= Button.new()
		action_button.visible = false
		action_button.disabled = true
		action_button.size_flags_horizontal = (
			Control.SIZE_EXPAND_FILL
		)
		action_button.custom_minimum_size = (
			Vector2(
				0,
				38
			)
		)
		action_button.set_meta(
			"action_id",
			""
		)
		_style_action_button(
			action_button
		)
		action_button.pressed.connect(
			_on_action_button_pressed.bind(
				button_index
			)
		)
		actions_box.add_child(
			action_button
		)
		action_button_pool.append(
			action_button
		)
		action_button.gui_input.connect(
			_on_action_button_gui_input.bind(
				button_index
			)
		)
	status_label = Label.new()
	status_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	status_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	status_label.add_theme_color_override(
		"font_color",
		Color(
			0.82,
			0.9,
			1.0,
			0.84
		)
	)
	action_root.add_child(
		status_label
	)
func _on_scroll_surface_gui_input(
	event: InputEvent
) -> void:
	if _route_scroll_input(event):
		accept_event()


func _on_action_button_gui_input(
	event: InputEvent,
	_button_index: int
) -> void:
	if _route_scroll_input(event):
		accept_event()


func _route_scroll_input(
	event: InputEvent
) -> bool:
	var pixel_delta: float = 0.0

	if event is InputEventMouseButton:
		var mouse_event:= (
			event as InputEventMouseButton
		)

		if not mouse_event.pressed:
			return false

		match mouse_event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				pixel_delta = (
					- float(
						SCROLL_STEP_PIXELS
					)
				)

			MOUSE_BUTTON_WHEEL_DOWN:
				pixel_delta = float(
					SCROLL_STEP_PIXELS
				)

			_:
				return false

	elif event is InputEventPanGesture:
		var pan_event:= (
			event as InputEventPanGesture
		)

		pixel_delta = (
			pan_event.delta.y
			* PAN_SCROLL_SCALE
		)
	else:
		return false

	var target_scroll: ScrollContainer = (
		_scroll_target_for_pointer()
	)

	if target_scroll == null:
		return false

	var next_scroll: int = int(
		round(
			float(
				target_scroll.scroll_vertical
			)
			+ pixel_delta
		)
	)

	target_scroll.scroll_vertical = maxi(
		0,
		next_scroll
	)

	return true


func _scroll_target_for_pointer() -> ScrollContainer:
	var pointer_position: Vector2 = (
		get_global_mouse_position()
	)

	if (
		actions_scroll != null
		and is_instance_valid(
			actions_scroll
		)
		and actions_scroll.get_global_rect().has_point(
			pointer_position
		)
	):
		return actions_scroll

	if (
		profile_scroll != null
		and is_instance_valid(
			profile_scroll
		)
	):
		return profile_scroll

	return null

func _create_stat_row(
	stat_id: String,
	title_text: String
) -> void:
	var root:= VBoxContainer.new()

	root.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	root.add_theme_constant_override(
		"separation",
		4
	)
	stats_grid.add_child(root)

	var title:= Label.new()

	title.text = title_text
	title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	title.add_theme_font_size_override(
		"font_size",
		12
	)
	title.add_theme_color_override(
		"font_color",
		Color(
			1.0,
			0.82,
			0.94,
			0.94
		)
	)
	root.add_child(title)

	var description_text: String = ""

	match stat_id:
		"bond":
			description_text = (
				"How strong and secure this relationship feels."
			)
		"hunger":
			description_text = (
				"How urgently their body currently needs food."
			)
		"health":
			description_text = (
				"Their present physical condition and vitality."
			)
		"mental":
			description_text = (
				"Their emotional and psychological wellbeing."
			)
		"smarts":
			description_text = (
				"Their reasoning, learning, and problem-solving ability."
			)
		"looks":
			description_text = (
				"Their current physical presentation and attractiveness."
			)

	var description:= Label.new()

	description.text = description_text
	description.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	description.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	description.add_theme_font_size_override(
		"font_size",
		9
	)
	description.add_theme_color_override(
		"font_color",
		Color(
			0.7,
			0.7,
			0.82,
			0.92
		)
	)
	root.add_child(description)

	var bar_stack:= Control.new()

	bar_stack.custom_minimum_size = Vector2(
		0,
		26
	)
	bar_stack.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	bar_stack.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	root.add_child(bar_stack)

	var base_fill_color: Color = (
		_stat_bar_fill_color(
			stat_id
		)
	)
	var fill_style:= StyleBoxFlat.new()

	fill_style.bg_color = base_fill_color
	fill_style.corner_radius_top_left = 8
	fill_style.corner_radius_top_right = 8
	fill_style.corner_radius_bottom_left = 8
	fill_style.corner_radius_bottom_right = 8

	var bar:= ProgressBar.new()

	bar.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 0.0
	bar.show_percentage = false
	bar.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	bar.add_theme_stylebox_override(
		"background",
		_stat_bar_background_style()
	)
	bar.add_theme_stylebox_override(
		"fill",
		fill_style
	)
	bar_stack.add_child(bar)

	var inside_label:= Label.new()

	inside_label.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	inside_label.text = "0"
	inside_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	inside_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)
	inside_label.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	inside_label.add_theme_font_size_override(
		"font_size",
		12
	)
	inside_label.add_theme_color_override(
		"font_color",
		Color.WHITE
	)
	inside_label.add_theme_color_override(
		"font_shadow_color",
		Color(
			0.0,
			0.0,
			0.0,
			0.88
		)
	)
	inside_label.add_theme_constant_override(
		"shadow_offset_x",
		1
	)
	inside_label.add_theme_constant_override(
		"shadow_offset_y",
		1
	)
	bar_stack.add_child(inside_label)

	stat_rows_by_id [stat_id] = {
		"stat_id": stat_id,
		"root": root,
		"title": title,
		"description": description,
		"bar": bar,
		"inside_label": inside_label,
		"fill_style": fill_style,
		"base_fill_color": base_fill_color,
		"ratio": 0.0
	}

func _apply_stat_contract(
	stat_id: String,
	stat_contract: Dictionary
) -> void:
	var row_raw: Variant = stat_rows_by_id.get(
		stat_id,
		{}
	)

	if typeof(row_raw) != TYPE_DICTIONARY:
		return

	var row: Dictionary = row_raw as Dictionary
	var bar:= row.get(
		"bar",
		null
	) as ProgressBar
	var title:= row.get(
		"title",
		null
	) as Label
	var description:= row.get(
		"description",
		null
	) as Label
	var inside_label:= row.get(
		"inside_label",
		null
	) as Label



	var value: float = float(
		stat_contract.get(
			"display_value",
			stat_contract.get(
				"value",
				0
			)
		)
	)
	var maximum: float = maxf(
		1.0,
		float(
			stat_contract.get(
				"maximum",
				stat_contract.get(
					"max_value",
					100
				)
			)
		)
	)
	var clamped_value: float = clampf(
		value,
		0.0,
		maximum
	)
	var ratio: float = clampf(
		clamped_value / maximum,
		0.0,
		1.0
	)
	var lifecycle_terminal: bool = bool(
		stat_contract.get(
			"lifecycle_terminal",
			false
		)
	)
	var title_text: String = str(
		stat_contract.get(
			"title_text",
			stat_contract.get(
				"label",
				stat_contract.get(
					"title",
					stat_id.to_upper()
				)
			)
		)
	).strip_edges()
	var sub_description: String = str(
		stat_contract.get(
			"sub_description",
			stat_contract.get(
				"description",
				""
			)
		)
	).strip_edges()
	var bar_text: String = str(
		stat_contract.get(
			"bar_text",
			stat_contract.get(
				"display_text",
				""
			)
		)
	).strip_edges()

	if title != null:
		title.text = title_text.to_upper()

	if (
		description != null
		and sub_description != ""
	):
		description.text = sub_description

	if bar != null:
		bar.max_value = maximum
		bar.value = clamped_value

	if inside_label != null:
		inside_label.text = (
			bar_text
			if bar_text != ""
			else str(
				int(
					round(
						clamped_value
					)
				)
			)
		)



	row [
		"ratio"
	] = (
		0.0
		if lifecycle_terminal
		else ratio
	)
	stat_rows_by_id [
		stat_id
	] = row
func _stat_bar_fill_color(
	stat_id: String
) -> Color:
	match stat_id:
		"bond":
			return Color(
				1.0,
				0.5,
				0.76,
				0.96
			)

		"hunger":
			return Color(
				1.0,
				0.68,
				0.34,
				0.96
			)

		"health":
			return Color(
				0.98,
				0.2,
				0.27,
				0.98
			)

		"mental":
			return Color(
				0.62,
				0.58,
				1.0,
				0.96
			)

		"smarts":
			return Color(
				0.34,
				0.72,
				1.0,
				0.96
			)

		"looks":
			return Color(
				1.0,
				0.46,
				0.76,
				0.96
			)

		_:
			return Color(
				1.0,
				0.5,
				0.76,
				0.96
			)
func _apply_action_contracts(
	actions: Array
) -> void:
	for button_index in range(
		action_button_pool.size()
	):
		var button: Button = (
			action_button_pool [button_index]
			as Button
		)

		if button_index >= actions.size():
			button.visible = false
			button.disabled = true
			button.text = ""
			button.set_meta(
				"action_id",
				""
			)
			continue

		if (
			typeof(actions [button_index])
			!= TYPE_DICTIONARY
		):
			button.visible = false
			button.disabled = true
			continue

		var action: Dictionary = (
			actions [button_index]
			as Dictionary
		)
		var action_id: String = str(
			action.get(
				"action_id",
				action.get(
					"id",
					""
				)
			)
		)

		button.visible = true
		button.disabled = bool(
			action.get(
				"disabled",
				false
			)
		)
		button.text = str(
			action.get(
				"label",
				action_id
			)
		)
		button.tooltip_text = str(
			action.get(
				"disabled_reason",
				""
			)
		)
		button.set_meta(
			"action_id",
			action_id
		)


func _on_action_button_pressed(
	button_index: int
) -> void:
	if (
		button_index < 0
		or button_index
		>= action_button_pool.size()
	):
		return

	var button: Button = (
		action_button_pool [button_index]
		as Button
	)
	var action_id: String = str(
		button.get_meta(
			"action_id",
			""
		)
	)

	if (
		action_id == ""
		or active_target_id <= 0
	):
		return

	request_action.emit(
		action_id,
		active_target_id
	)


func _outer_panel_style() -> StyleBoxFlat:
	var accent:= Color(
		1.0,
		0.48,
		0.72,
		0.9
	)
	var top_color:= Color(
		0.078,
		0.03,
		0.072,
		0.98
	)
	var base_color:= Color(
		0.034,
		0.014,
		0.04,
		0.98
	)

	var style:= StyleBoxFlat.new()
	style.bg_color = base_color.lerp(
		top_color,
		0.36
	)
	style.border_color = Color(
		accent.r,
		accent.g,
		accent.b,
		0.62
	)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.shadow_color = Color(
		0.0,
		0.0,
		0.0,
		0.48
	)
	style.shadow_size = 12
	style.shadow_offset = Vector2(
		0,
		4
	)
	return style


func _stats_panel_style() -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(
		0.07,
		0.026,
		0.07,
		0.74
	)
	style.set_border_width_all(0)
	style.corner_radius_top_left = 22
	style.corner_radius_top_right = 22
	style.corner_radius_bottom_left = 22
	style.corner_radius_bottom_right = 22
	style.shadow_color = Color(
		1.0,
		0.4,
		0.72,
		0.16
	)
	style.shadow_size = 14
	return style


func _child_panel_style() -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(
		0.06,
		0.024,
		0.058,
		0.18
	)
	style.set_border_width_all(0)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	return style


func _style_action_button(
	button: Button
) -> void:
	var accent:= Color(
		1.0,
		0.48,
		0.72,
		0.9
	)
	var fill:= Color(
		0.1,
		0.04,
		0.085,
		0.96
	)

	button.add_theme_stylebox_override(
		"normal",
		_button_style(
			fill,
			Color(
				accent.r,
				accent.g,
				accent.b,
				0.62
			)
		)
	)
	button.add_theme_stylebox_override(
		"hover",
		_button_style(
			fill.lerp(
				accent,
				0.22
			),
			accent
		)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_button_style(
			fill.lerp(
				accent,
				0.34
			),
			accent
		)
	)
	button.add_theme_color_override(
		"font_color",
		Color(
			1.0,
			0.92,
			0.98,
			1.0
		)
	)


func _button_style(
	fill: Color,
	border: Color
) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.shadow_color = Color(
		0.0,
		0.0,
		0.0,
		0.42
	)
	style.shadow_size = 5
	return style


func _stat_bar_background_style() -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(
		0.018,
		0.012,
		0.024,
		0.92
	)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style


func _stat_bar_fill_style(
	stat_id: String
) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = (
		_stat_bar_fill_color(
			stat_id
		)
	)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(
	value: Variant
) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return (
			value as Array
		).duplicate(true)

	return []