extends PanelContainer
class_name PropertyViewer

signal close_requested
signal property_action_requested(action_id: String, payload: Dictionary)
signal makeover_action_requested(path_id: String, action_id: String, payload: Dictionary)

var host: Node = null
var gs: GameState = null
var actor: Person = null
var active_contract: Dictionary = {}
var selected_path_id: String = ""
var active_floor_index: int = 0
var active_room_id: String = ""
var title_label: Label = null
var subtitle_label: Label = null
var status_label: Label = null
var content_box: VBoxContainer = null



var resident_interior_painted: bool = false
var resident_render_mode: String = ""
var resident_action_sections: Dictionary = {}
var resident_action_button_pools: Dictionary = {}
var resident_action_empty_labels: Dictionary = {}
var resident_card_bodies: Dictionary = {}

func bind_host(_host: Node, _gs: GameState = null) -> void:
	host = _host
	gs = _gs
	_ensure_surface()


func open_for_property(target_actor: Person, contract: Dictionary) -> void:
	actor = target_actor
	active_floor_index = int(contract.get("active_floor", 0))
	active_room_id = str(contract.get("active_room", ""))
	_ensure_surface()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	render_surface_contract(contract)


func render_surface_contract(
	contract: Dictionary
) -> void:
	_ensure_surface()

	var mode: String = str(
		contract.get(
			"mode",
			"interior"
		)
	)
	var mode_changed: bool = (
		resident_render_mode != mode
	)



	active_contract = contract.duplicate(false)
	active_floor_index = int(
		contract.get(
			"active_floor",
			active_floor_index
		)
	)
	active_room_id = str(
		contract.get(
			"active_room",
			active_room_id
		)
	)
	title_label.text = str(
		contract.get(
			"title",
			"Property"
		)
	).to_upper()
	subtitle_label.text = str(
		contract.get(
			"subtitle",
			""
		)
	)
	status_label.text = str(
		contract.get(
			"status_text",
			""
		)
	)

	if (
		mode_changed
		or (
			mode == "interior"
			and not resident_interior_painted
		)
	):
		_clear_children(
			content_box
		)
		_reset_resident_property_controls()
		resident_render_mode = mode

	if mode == "makeover":
		_render_makeover(
			contract
		)
		return

	_render_interior(
		active_contract
	)
	resident_interior_painted = true


func apply_surface_delta(
	delta: Dictionary
) -> void:
	if delta.is_empty():
		return

	var schema: String = str(
		delta.get(
			"schema",
			""
		)
	)
	if schema != (
		"eralife.property_space.surface_delta_contract"
	):
		return

	var delta_property_id: int = int(
		delta.get(
			"property_id",
			-1
		)
	)
	var active_property_id: int = int(
		active_contract.get(
			"property_id",
			-1
		)
	)
	if (
		delta_property_id > 0
		and active_property_id > 0
		and delta_property_id != active_property_id
	):
		return

	for key in [
		"active_floor",
		"active_room",
		"current_room",
		"navigation_actions",
		"room_navigation_actions",
		"movement_options",
		"spatial_movement_actions",
		"room_interaction_actions",
		"spatial_description",
		"surroundings",
		"occupants",
		"presence_summary",
		"status_text",
		"cursor_revision"
	]:
		if delta.has(key):
			active_contract [key] = delta.get(
				key
			)

	active_floor_index = int(
		active_contract.get(
			"active_floor",
			active_floor_index
		)
	)
	active_room_id = str(
		active_contract.get(
			"active_room",
			active_room_id
		)
	)

	status_label.text = str(
		active_contract.get(
			"status_text",
			""
		)
	)



	_render_interior(
		active_contract
	)

	set_meta(
		"property_surface_delta_applied",
		true
	)
	set_meta(
		"property_surface_delta_renderer_teardown",
		false
	)
	set_meta(
		"property_surface_delta_at_ms",
		int(
			Time.get_ticks_msec()
		)
	)
func _reset_resident_property_controls() -> void:
	resident_interior_painted = false
	resident_action_sections.clear()
	resident_action_button_pools.clear()
	resident_action_empty_labels.clear()
	resident_card_bodies.clear()
func _ensure_surface() -> void:
	if title_label != null and is_instance_valid(title_label):
		return

	name = "PropertyViewer"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var top:= HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	root.add_child(top)

	var back:= Button.new()
	back.text = "Leave"
	back.custom_minimum_size = Vector2(120, 42)
	back.pressed.connect(func (): close_requested.emit())
	top.add_child(back)

	title_label = Label.new()
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 31)
	title_label.add_theme_color_override("font_color", Color(0.96, 0.84, 0.62, 1.0))
	top.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(subtitle_label)

	var scroll:= ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	content_box = VBoxContainer.new()
	content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_box.add_theme_constant_override("separation", 10)
	scroll.add_child(content_box)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(status_label)


func _render_interior(
	contract: Dictionary
) -> void:
	var floors: Array = _safe_array(
		contract.get(
			"floors",
			[]
		)
	)
	active_floor_index = int(
		contract.get(
			"active_floor",
			active_floor_index
		)
	)
	active_room_id = str(
		contract.get(
			"active_room",
			active_room_id
		)
	).strip_edges()

	if active_room_id == "":
		active_room_id = "entryway"

	var current_floor: Dictionary = _floor_by_index(
		floors,
		active_floor_index
	)
	var current_room: Dictionary = _safe_dictionary(
		contract.get(
			"current_room",
			{}
		)
	)

	if (
		current_floor.is_empty()
		and not floors.is_empty()
	):
		current_floor = _safe_dictionary(
			floors [0]
		)
		active_floor_index = int(
			current_floor.get(
				"floor_index",
				0
			)
		)

	if current_room.is_empty():
		current_room = _first_room_on_floor(
			current_floor
		)
		active_room_id = str(
			current_room.get(
				"room_id",
				active_room_id
			)
		)

	if active_room_id == "":
		active_room_id = "entryway"

	var floor_label: String = str(
		current_floor.get(
			"label",
			"Floor %d" % active_floor_index
		)
	)
	var room_title: String = str(
		current_room.get(
			"title",
			current_room.get(
				"name",
				active_room_id.replace(
					"_",
					" "
				).capitalize()
			)
		)
	)
	var property_id: int = int(
		contract.get(
			"property_id",
			-1
		)
	)

	_add_action_grid(
		"Spatial Movement",
		_spatial_actions_from_contract(
			contract,
			floors,
			current_floor
		),
		property_id
	)
	_add_action_grid(
		"Room Interactions",
		_room_interaction_actions_from_contract(
			contract,
			current_room
		),
		property_id
	)
	_add_action_grid(
		"Property Actions",
		_property_actions_from_contract(
			contract
		),
		property_id
	)

	_add_spatial_context_surface(
		contract,
		current_floor,
		current_room,
		floor_label,
		room_title
	)
	_add_presence_surface(
		contract
	)
func _add_spatial_context_surface(contract: Dictionary, current_floor: Dictionary, current_room: Dictionary, floor_label: String, room_title: String) -> void:
	var lines: Array = []

	var spatial_description: String = str(contract.get("spatial_description", "")).strip_edges()
	if spatial_description != "":
		lines.append(spatial_description)
	else:
		lines.append("You are standing in the %s." % room_title)

	lines.append("")
	lines.append("Floor: %s" % floor_label)
	lines.append("Room: %s" % room_title)

	var description: String = str(current_room.get("description", "")).strip_edges()
	if description != "":
		lines.append("")
		lines.append(description)

	var surroundings: Array = _safe_array(contract.get("surroundings", []))
	if not surroundings.is_empty():
		lines.append("")
		lines.append("Around you:")
		for raw_surrounding in surroundings:
			lines.append("• %s" % str(raw_surrounding))
	else:
		var synthesized: Array = _synthesize_surroundings(current_floor, current_room)
		if not synthesized.is_empty():
			lines.append("")
			lines.append("Around you:")
			for raw_line in synthesized:
				lines.append("• %s" % str(raw_line))

	_add_card("WHERE YOU ARE", "\n".join(lines))


func _add_presence_surface(contract: Dictionary) -> void:
	var occupants: Array = _safe_array(contract.get("occupants", []))
	var visible_lines: Array = []

	for raw_occupant in occupants:
		var occupant: Dictionary = _safe_dictionary(raw_occupant)
		if str(occupant.get("room_id", "")) != active_room_id:
			continue
		if str(occupant.get("presence_label", "")) == "You are here.":
			continue
		visible_lines.append("● %s" % str(occupant.get("presence_label", "Someone is here.")))

	if visible_lines.is_empty():
		visible_lines.append(str(contract.get("presence_summary", "No one else is in this room right now.")))

	_add_card("PRESENCE", "\n".join(visible_lines))


func _add_action_grid(
	section_title: String,
	actions: Array,
	property_id: int
) -> void:
	var section_key: String = (
		section_title
		.strip_edges()
		.to_lower()
		.replace(
			" ",
			"_"
		)
	)
	var resolved_property_id: int = property_id
	if resolved_property_id <= 0:
		resolved_property_id = int(
			active_contract.get(
				"property_id",
				-1
			)
		)

	if not resident_action_sections.has(
		section_key
	):
		_create_resident_action_section(
			section_key,
			section_title
		)

	var pool_raw: Variant = (
		resident_action_button_pools.get(
			section_key,
			[]
		)
	)
	if typeof(pool_raw) != TYPE_ARRAY:
		return
	var pool: Array = pool_raw as Array

	var valid_actions: Array = []
	for raw_action in actions:
		if typeof(raw_action) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = (
			raw_action as Dictionary
		)
		if str(
			action.get(
				"action_id",
				""
			)
		).strip_edges() == "":
			continue
		valid_actions.append(
			action
		)

	var empty_label_raw: Variant = (
		resident_action_empty_labels.get(
			section_key,
			null
		)
	)
	if empty_label_raw is Label:
		var empty_label: Label = (
			empty_label_raw as Label
		)
		empty_label.visible = (
			valid_actions.is_empty()
		)

	for index in range(
		pool.size()
	):
		var button_raw: Variant = pool [index]
		if not button_raw is Button:
			continue
		var button: Button = button_raw as Button

		if index >= valid_actions.size():
			button.visible = false
			button.disabled = true
			button.set_meta(
				"property_action_id",
				""
			)
			button.set_meta(
				"property_action_payload",
				{}
			)
			continue

		var action: Dictionary = (
			valid_actions [index] as Dictionary
		)
		var action_id: String = str(
			action.get(
				"action_id",
				""
			)
		)
		var disabled: bool = bool(
			action.get(
				"disabled",
				false
			)
		)
		var compact_payload: Dictionary = (
			_compact_property_action_payload(
				action,
				resolved_property_id
			)
		)

		button.visible = true
		button.text = str(
			action.get(
				"label",
				"Action"
			)
		)
		button.disabled = disabled
		button.mouse_default_cursor_shape = (
			Control.CURSOR_ARROW
			if disabled
			else Control.CURSOR_POINTING_HAND
		)
		button.tooltip_text = str(
			action.get(
				"tooltip",
				action.get(
					"blocked_text",
					action.get(
						"blocked_reason",
						""
					)
				)
			)
		)
		button.modulate = (
			Color(
				0.68,
				0.68,
				0.68,
				0.78
			)
			if disabled
			else Color.WHITE
		)
		button.set_meta(
			"property_action_id",
			action_id
		)
		button.set_meta(
			"property_action_payload",
			compact_payload
		)
		button.set_meta(
			"ui_is_renderer_only",
			true
		)

	set_meta(
		"property_action_pool_overflow_%s"
		% section_key,
		maxi(
			0,
			valid_actions.size() - pool.size()
		)
	)
func _create_resident_action_section(
	section_key: String,
	section_title: String
) -> void:
	var section_root:= VBoxContainer.new()
	section_root.name = (
		"ResidentPropertyActionSection_%s"
		% section_key
	)
	section_root.add_theme_constant_override(
		"separation",
		6
	)
	content_box.add_child(
		section_root
	)
	resident_action_sections [
		section_key
	] = section_root

	var section_label:= Label.new()
	section_label.text = section_title.to_upper()
	section_label.add_theme_font_size_override(
		"font_size",
		13
	)
	section_label.add_theme_color_override(
		"font_color",
		Color(
			0.96,
			0.78,
			0.48,
			0.95
		)
	)
	section_root.add_child(
		section_label
	)

	var empty_notice:= Label.new()
	empty_notice.text = (
		(
			"No %s are currently observable. "
			+ "The property topology exposed no valid edges from this space."
		)
		% section_title.to_lower()
	)
	empty_notice.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	empty_notice.add_theme_color_override(
		"font_color",
		Color(
			1.0,
			0.72,
			0.42,
			0.88
		)
	)
	empty_notice.add_theme_font_size_override(
		"font_size",
		11
	)
	section_root.add_child(
		empty_notice
	)
	resident_action_empty_labels [
		section_key
	] = empty_notice

	var grid:= GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	grid.add_theme_constant_override(
		"h_separation",
		6
	)
	grid.add_theme_constant_override(
		"v_separation",
		6
	)
	section_root.add_child(
		grid
	)

	var capacity: int = 12
	if section_key == "spatial_movement":
		capacity = 32
	elif section_key == "room_interactions":
		capacity = 24

	var pool: Array = []
	for index in range(
		capacity
	):
		var button:= Button.new()
		button.name = (
			"ResidentPropertyAction%d"
			% index
		)
		button.visible = false
		button.disabled = true
		button.custom_minimum_size = Vector2(
			0,
			34
		)
		button.size_flags_horizontal = (
			Control.SIZE_EXPAND_FILL
		)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override(
			"font_size",
			12
		)
		button.pressed.connect(
			Callable(
				self,
				"_on_resident_property_action_pressed"
			).bind(
				button
			)
		)
		grid.add_child(
			button
		)
		pool.append(
			button
		)

	resident_action_button_pools [
		section_key
	] = pool


func _on_resident_property_action_pressed(
	button: Button
) -> void:
	if (
		button == null
		or not is_instance_valid(
			button
		)
		or button.disabled
	):
		return

	var action_id: String = str(
		button.get_meta(
			"property_action_id",
			""
		)
	).strip_edges()
	if action_id == "":
		return

	var payload_raw: Variant = button.get_meta(
		"property_action_payload",
		{}
	)
	var payload: Dictionary = (
		(payload_raw as Dictionary).duplicate(false)
		if typeof(payload_raw) == TYPE_DICTIONARY
		else {}
	)

	property_action_requested.emit(
		action_id,
		payload
	)


func _compact_property_action_payload(
	action: Dictionary,
	property_id: int
) -> Dictionary:
	var out: Dictionary = {
		"property_id": int(
			action.get(
				"property_id",
				property_id
			)
		),
		"property_owner_id": int(
			active_contract.get(
				"property_owner_id",
				-1
			)
		),
		"room_id": str(
			action.get(
				"room_id",
				active_room_id
			)
		),
		"active_floor": int(
			action.get(
				"active_floor",
				active_floor_index
			)
		),
		"cursor_revision": int(
			active_contract.get(
				"cursor_revision",
				0
			)
		),
		"source": (
			"property_viewer.resident_action"
		),
		"ui_is_renderer_only": true,
	}

	for key in [
		"from_room_id",
		"target_room_id",
		"fixture_id",
		"fixture_kind",
		"host_id",
		"host_kind",
		"provider_id",
		"multiplayer_mode",
		"direction",
		"edge_id",
		"security_mode"
	]:
		if action.has(
			key
		):
			out [key] = str(
				action.get(
					key,
					""
				)
			)

	for key in [
		"launch_direct",
		"open_provider_setup"
	]:
		if action.has(
			key
		):
			out [key] = bool(
				action.get(
					key,
					false
				)
			)

	for key in [
		"from_floor",
		"target_floor"
	]:
		if action.has(
			key
		):
			out [key] = int(
				action.get(
					key,
					active_floor_index
				)
			)

	return out
func _spatial_actions_from_contract(
	contract: Dictionary,
	_floors: Array,
	_current_floor: Dictionary
) -> Array:
	for action_key in [
		"spatial_movement_actions",
		"movement_options",
		"navigation_actions",
		"room_navigation_actions"
	]:
		var actions_raw: Variant = contract.get(
			action_key,
			[]
		)
		if typeof(actions_raw) != TYPE_ARRAY:
			continue

		var out: Array = []
		var seen: Dictionary = {}
		for raw_action in actions_raw as Array:
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
			).strip_edges()
			if action_id == "":
				continue

			var from_room: String = str(
				action.get(
					"from_room_id",
					action.get(
						"source_room_id",
						active_room_id
					)
				)
			).strip_edges()
			if (
				from_room != ""
				and from_room != active_room_id
			):
				continue


			if (
				action_id in [
					"move_room",
					"move_to_room",
					"navigate_floor"
				]
				and bool(
					action.get(
						"secured_edge",
						false
					)
				)
			):
				continue

			var identity: String = (
				"%s|%s|%s"
				% [
					action_id,
					str(
						action.get(
							"target_room_id",
							action.get(
								"room_id",
								""
							)
						)
					),
					str(
						action.get(
							"edge_id",
							""
						)
					)
				]
			)
			if seen.has(identity):
				continue

			seen [identity] = true
			out.append(
				action
			)

		if not out.is_empty():
			return out

	return []
func _floor_indices(floors: Array) -> Array:
	var out: Array = []
	for raw_floor in floors:
		var floor_contract: Dictionary = _safe_dictionary(raw_floor)
		if floor_contract.is_empty():
			continue
		var floor_index: int = int(floor_contract.get("floor_index", 0))
		if not out.has(floor_index):
			out.append(floor_index)
	out.sort()
	return out


func _room_interaction_actions_from_contract(contract: Dictionary, current_room: Dictionary) -> Array:
	var actions: Array = _safe_array(contract.get("room_interaction_actions", []))
	if not actions.is_empty():
		return actions

	var out: Array = []
	var room_id: String = str(current_room.get("room_id", active_room_id))
	var room_title: String = str(current_room.get("title", room_id.replace("_", " ").capitalize()))

	out.append({
		"action_id": "inspect_room",
		"label": "Inspect %s" % room_title,
		"room_id": room_id
	})

	for raw_fixture in _safe_array(current_room.get("fixtures", [])):
		var fixture: Dictionary = _safe_dictionary(raw_fixture)
		var fixture_id: String = str(fixture.get("fixture_id", ""))
		if fixture_id == "":
			continue
		out.append({
			"action_id": "use_fixture",
			"label": str(fixture.get("label", "Use %s" % str(fixture.get("title", "Fixture")))),
			"room_id": room_id,
			"fixture_id": fixture_id,
			"fixture_kind": str(fixture.get("kind", "fixture"))
		})

	return out


func _property_actions_from_contract(
	contract: Dictionary
) -> Array:
	var out: Array = []
	var household_context_available: bool = bool(
		contract.get(
			"household_context_available",
			false
		)
	)

	for raw_action in _safe_array(
		contract.get(
			"actions",
			[]
		)
	):
		var action: Dictionary = _safe_dictionary(
			raw_action
		)
		var action_id: String = str(
			action.get(
				"action_id",
				""
			)
		).strip_edges()

		if action_id in [
			"",
			"move_room",
			"move_to_room",
			"navigate_floor",
			"inspect_room",
			"use_fixture"
		]:
			continue



		if (
			action_id == "view_household"
			and not household_context_available
		):
			continue

		out.append(
			action
		)

	if out.is_empty():

		out.append({
			"action_id": "leave_property",
			"label": "Leave Property"
		})

	return out

func _synthesize_surroundings(
	_current_floor: Dictionary,
	current_room: Dictionary
) -> Array:
	var out: Array = []
	var adjacent_nodes: Array = _safe_array(
		current_room.get("adjacent_nodes", [])
	)

	for raw_adjacent in adjacent_nodes:
		var adjacent: Dictionary = _safe_dictionary(
			raw_adjacent
		)

		if adjacent.is_empty():
			continue

		var title: String = str(
			adjacent.get(
				"title",
				adjacent.get(
					"node_id",
					"Nearby Space"
				).replace("_", " ").capitalize()
			)
		)
		var icon: String = str(
			adjacent.get("icon", "🚪")
		)
		var state: String = str(
			adjacent.get("state", "intact")
		).strip_edges().to_lower()
		var blocked: bool = bool(
			adjacent.get("blocked", false)
		) or state in [
			"destroyed",
			"collapsed",
			"unsafe",
			"locked_off"
		]

		out.append(
			"%s %s%s" % [
				icon,
				title,
				(
					" — %s" % state
						.replace("_", " ")
						.capitalize()
					if blocked
					else ""
				)
			]
		)

	for raw_fixture in _safe_array(
		current_room.get("fixtures", [])
	):
		var fixture: Dictionary = _safe_dictionary(
			raw_fixture
		)
		out.append(
			str(
				fixture.get(
					"surface_text",
					fixture.get(
						"label",
						fixture.get(
							"title",
							"Something usable is here."
						)
					)
				)
			)
		)

	return out


func _first_room_on_floor(floor_contract: Dictionary) -> Dictionary:
	for raw_room in _safe_array(floor_contract.get("rooms", [])):
		var room: Dictionary = _safe_dictionary(raw_room)
		if not room.is_empty():
			return room
	return {}
func _add_property_action_button(action: Dictionary, property_id: int) -> void:
	var action_id: String = str(action.get("action_id", ""))
	if action_id == "":
		return

	var button:= Button.new()
	button.text = str(action.get("label", "Action"))
	button.custom_minimum_size = Vector2(0, 42)
	button.pressed.connect(func ():
		var payload: Dictionary = action.duplicate(true)
		payload ["property_id"] = property_id
		property_action_requested.emit(action_id, payload)
	)
	content_box.add_child(button)


func _floor_by_index(floors: Array, floor_index: int) -> Dictionary:
	for raw_floor in floors:
		var floor_contract: Dictionary = _safe_dictionary(raw_floor)
		if int(floor_contract.get("floor_index", -9999)) == floor_index:
			return floor_contract
	return {}


func _render_makeover(contract: Dictionary) -> void:
	var paths: Array = _safe_array(contract.get("makeover_paths", []))

	if paths.is_empty():
		_add_card(
			"MAKEOVER PATHS NOT OBSERVABLE",
			"CRR blocked a blank makeover surface. The property exists, but no upgrade paths were attached to this render contract."
		)

		var fallback_button:= Button.new()
		fallback_button.text = "Refresh Property Makeover"
		fallback_button.custom_minimum_size = Vector2(0, 42)
		fallback_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fallback_button.pressed.connect(func ():
			property_action_requested.emit("open_makeover", {
				"property_id": int(contract.get("property_id", -1)),
				"source": "property_viewer.makeover_empty_refresh"
			})
		)
		content_box.add_child(fallback_button)
		return

	for raw_path in paths:
		var path: Dictionary = _safe_dictionary(raw_path)
		var path_id: String = str(path.get("path_id", "")).strip_edges()
		if path_id == "":
			continue

		_add_card(
			"%s • %s" % [str(path.get("title", "Makeover")), str(path.get("cost_text", "$0"))],
			"%s\nDuration: %d days\nDisruption: %s" % [
				str(path.get("description", "")),
				int(path.get("duration_days", 0)),
				str(path.get("disruption_level", "low")).capitalize()
			]
		)

		var option_count: int = 0
		for raw_option in _safe_array(path.get("options", [])):
			var option: Dictionary = _safe_dictionary(raw_option)
			var option_id: String = str(option.get("action_id", "")).strip_edges()
			if option_id == "":
				continue

			var button:= Button.new()
			button.text = str(option.get("label", "Select"))
			button.custom_minimum_size = Vector2(0, 38)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.pressed.connect(func ():
				makeover_action_requested.emit(path_id, option_id, {
					"property_id": int(contract.get("property_id", -1)),
					"path_id": path_id,
					"makeover_action": option_id,
					"source": "property_viewer.makeover_path_option"
				})
			)
			content_box.add_child(button)
			option_count += 1

		if option_count <= 0:
			var unavailable:= Label.new()
			unavailable.text = "No selectable actions were attached to this makeover path."
			unavailable.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			content_box.add_child(unavailable)


func _add_card(
	title: String,
	body: String
) -> void:
	var card_key: String = (
		title
		.strip_edges()
		.to_lower()
		.replace(
			" ",
			"_"
		)
	)

	if resident_card_bodies.has(
		card_key
	):
		var existing_raw: Variant = (
			resident_card_bodies.get(
				card_key,
				null
			)
		)
		if existing_raw is Label:
			var existing_body: Label = (
				existing_raw as Label
			)
			existing_body.text = body
			return

	var card:= PanelContainer.new()
	card.name = (
		"ResidentPropertyCard_%s"
		% card_key
	)
	card.add_theme_stylebox_override(
		"panel",
		_card_style()
	)
	content_box.add_child(
		card
	)

	var margin:= MarginContainer.new()
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
	card.add_child(
		margin
	)

	var box:= VBoxContainer.new()
	box.add_theme_constant_override(
		"separation",
		6
	)
	margin.add_child(
		box
	)

	var card_title_label:= Label.new()
	card_title_label.text = title
	card_title_label.add_theme_font_size_override(
		"font_size",
		20
	)
	box.add_child(
		card_title_label
	)

	var body_label:= Label.new()
	body_label.text = body
	body_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	box.add_child(
		body_label
	)

	resident_card_bodies [
		card_key
	] = body_label
func _panel_style() -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.04, 0.034, 0.985)
	style.border_color = Color(0.96, 0.72, 0.42, 0.48)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style


func _card_style() -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.105, 0.088, 0.064, 0.96)
	style.border_color = Color(0.96, 0.72, 0.42, 0.42)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(value: Variant) -> Array:
	return (
		value as Array
		if typeof(value) == TYPE_ARRAY
		else []
	)