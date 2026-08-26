extends PanelContainer
class_name MiniGamePanel

signal close_requested
signal intent_requested(payload: Dictionary)

const PANEL_SCHEMA:= "eralife.minigame_panel"
const PANEL_VERSION:= 1

var active_contract: Dictionary = {}
var active_section: String = "games"

var root: VBoxContainer = null
var title_label: Label = null
var subtitle_label: Label = null
var identity_label: Label = null
var tab_scroll: ScrollContainer = null
var tab_row: HBoxContainer = null
var content_scroll: ScrollContainer = null
var content_root: VBoxContainer = null
var status_label: Label = null
var close_button: Button = null
var online_username_input: LineEdit = null
var scroll_bar: VScrollBar = null
var scroll_fade_hold: float = 0.0
var scroll_last_value: float = -1.0
var animation_time: float = 0.0
var animated_cards: Array = []
var animated_buttons: Array = []
var stick_fighter_damage_feedback_revision: int = 0

var stick_fighter_input_sequence: int = 0
var stick_fighter_live_session_id: String = ""
var stick_fighter_live_revision: int = -1
var stick_fighter_live_fullscreen: bool = false
var stick_fighter_live_arena: Control = null
var stick_fighter_live_stage_label: Label = null
var stick_fighter_live_countdown_label: Label = null
var stick_fighter_live_stage_width: float = 100.0
var stick_fighter_live_stage_height: float = 56.0
var stick_fighter_live_fighter_nodes: Dictionary = {}
var stick_fighter_live_hud_nodes: Dictionary = {}
var stick_fighter_live_weapon_drop_nodes: Dictionary = {}
var stick_fighter_live_projectile_nodes: Dictionary = {}
var stick_fighter_live_effect_nodes: Dictionary = {}
var stick_fighter_live_event_label: Label = null

func _ready() -> void:
	prepare_surface()


func prepare_surface() -> void:
	if root != null and is_instance_valid(root):
		return

	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 54.0
	offset_top = 42.0
	offset_right = -54.0
	offset_bottom = -42.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	process_mode = Node.PROCESS_MODE_INHERIT
	add_theme_stylebox_override("panel", _panel_style())

	root = VBoxContainer.new()
	root.name = "MiniGameRoot"
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var header:= HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 10)
	root.add_child(header)

	var title_box:= VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 2)
	header.add_child(title_box)

	title_label = Label.new()
	title_label.text = "MINIGAME ECOSYSTEM"
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color(0.98, 0.93, 0.82, 1.0))
	title_box.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = ("Persistent games hosted as contract realities.")
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.add_theme_font_size_override("font_size", 12)
	subtitle_label.add_theme_color_override("font_color", Color(0.69, 0.74, 0.84, 1.0))
	title_box.add_child(subtitle_label)

	identity_label = Label.new()
	identity_label.text = "No identity attached"
	identity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	identity_label.add_theme_font_size_override("font_size", 12)
	identity_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0, 1.0))
	header.add_child(identity_label)

	close_button = Button.new()
	close_button.text = "CLOSE"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.custom_minimum_size = Vector2(88.0, 38.0)
	_apply_button_style(close_button)
	close_button.pressed.connect(_on_close_pressed)
	header.add_child(close_button)

	tab_scroll = ScrollContainer.new()
	tab_scroll.name = "SectionScroll"
	tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	tab_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tab_scroll.custom_minimum_size = Vector2(0.0, 48.0)
	root.add_child(tab_scroll)

	tab_row = HBoxContainer.new()
	tab_row.name = "SectionTabs"
	tab_row.add_theme_constant_override("separation", 6)
	tab_scroll.add_child(tab_row)

	content_scroll = ScrollContainer.new()
	content_scroll.name = "ContentScroll"
	content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	root.add_child(content_scroll)

	content_root = VBoxContainer.new()
	content_root.name = "Content"
	content_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_root.add_theme_constant_override("separation", 12)
	content_scroll.add_child(content_root)

	status_label = Label.new()
	status_label.text = "Ready."
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 11)
	status_label.add_theme_color_override("font_color", Color(0.77, 0.8, 0.88, 1.0))
	root.add_child(status_label)

	scroll_bar = content_scroll.get_v_scroll_bar()

	if scroll_bar != null:
		scroll_bar.modulate.a = 0.0

	set_process(true)
	set_meta("ui_is_renderer_only", true)
	set_meta("panel_schema", PANEL_SCHEMA)
	set_meta("panel_version", PANEL_VERSION)


func render_contract(
	contract: Dictionary
) -> void:
	if (
		root == null
		or not is_instance_valid(
			root
		)
	):
		set_meta(
			"minigame_render_requires_resident_surface",
			true
		)
		return

	active_contract = contract.duplicate(false)

	active_section = _section(
		str(
			active_contract.get(
				"active_section",
				"games"
			)
		)
	)

	var session: Dictionary = _dict(
		active_contract.get(
			"session_contract",
			{}
		)
	)
	var projection: Dictionary = _dict(
		session.get(
			"ui_projection",
			{}
		)
	)
	var provider_setup: Dictionary = _dict(
		active_contract.get(
			"provider_setup_contract",
			{}
		)
	)

	var stick_fighter_provider_id: String = str(
		provider_setup.get(
			"provider_id",
			session.get(
				"provider_id",
				active_contract.get(
					"provider_id",
					""
				)
			)
		)
	).strip_edges().to_lower()

	var stick_fighter_surface: bool = (
		stick_fighter_provider_id == "stick_fighter"
	)

	var continuous_stick_fighter: bool = (
		active_section == "session"
		and str(
			projection.get(
				"projection_kind",
				""
			)
		).strip_edges().to_lower() == "stick_fighter_stage"
		and bool(
			projection.get(
				"continuous_simulation",
				false
			)
		)
	)

	_set_stick_fighter_live_surface_mode(
		stick_fighter_surface,
		continuous_stick_fighter
	)

	content_scroll.visible = true

	title_label.text = (
		str(
			session.get(
				"game_title",
				"STICK FIGHTER"
			)
		).to_upper()
		if continuous_stick_fighter
		else (
			str(
				provider_setup.get(
					"title",
					"STICK FIGHTER"
				)
			).to_upper()
			if stick_fighter_surface
			else str(
				active_contract.get(
					"title",
					"MINIGAME ECOSYSTEM"
				)
			)
		)
	)

	subtitle_label.text = (
		str(
			provider_setup.get(
				"subtitle",
				active_contract.get(
					"subtitle",
					"Persistent games hosted as contract realities."
				)
			)
		)
		if stick_fighter_surface
		else str(
			active_contract.get(
				"subtitle",
				"Persistent games hosted as contract realities."
			)
		)
	)

	identity_label.text = str(
		active_contract.get(
			"actor_name",
			"Current Life"
		)
	)

	status_label.text = str(
		active_contract.get(
			"status_text",
			"Ready."
		)
	)

	stick_fighter_live_session_id = ""
	stick_fighter_live_revision = -1
	stick_fighter_live_arena = null
	stick_fighter_live_stage_label = null
	stick_fighter_live_countdown_label = null
	stick_fighter_live_fighter_nodes = {}
	stick_fighter_live_hud_nodes = {}
	stick_fighter_live_weapon_drop_nodes = {}
	stick_fighter_live_projectile_nodes = {}
	stick_fighter_live_effect_nodes = {}
	stick_fighter_live_event_label = null

	if stick_fighter_surface:
		_clear_children(
			tab_row
		)
	else:
		_rebuild_tabs()

	_rebuild_active_section()

	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	move_to_front()

	set_meta(
		"minigame_contract_deep_copy_on_render",
		false
	)
	set_meta(
		"stick_fighter_live_fullscreen",
		continuous_stick_fighter
	)
	set_meta(
		"stick_fighter_owned_fullscreen_surface",
		stick_fighter_surface
	)
	set_meta(
		"minigame_render_surface_construction_performed",
		false
	)

func _set_stick_fighter_live_surface_mode(
	enabled: bool,
	live_match: bool = false
) -> void:
	stick_fighter_live_fullscreen = live_match

	if enabled:
		offset_left = 0.0
		offset_top = 0.0
		offset_right = 0.0
		offset_bottom = 0.0



		tab_scroll.visible = false
		subtitle_label.visible = not live_match
		identity_label.visible = false
		status_label.visible = not live_match

		content_scroll.vertical_scroll_mode = (
			ScrollContainer.SCROLL_MODE_AUTO
		)

		content_root.size_flags_vertical = (
			Control.SIZE_EXPAND_FILL
		)

		root.add_theme_constant_override(
			"separation",
			4
		)

		close_button.text = (
			"EXIT MATCH"
			if live_match
			else "EXIT STICK FIGHTER"
		)
	else:
		offset_left = 54.0
		offset_top = 42.0
		offset_right = -54.0
		offset_bottom = -42.0

		tab_scroll.visible = true
		subtitle_label.visible = true
		identity_label.visible = true
		status_label.visible = true

		content_scroll.vertical_scroll_mode = (
			ScrollContainer.SCROLL_MODE_AUTO
		)

		content_root.size_flags_vertical = (
			Control.SIZE_SHRINK_BEGIN
		)

		root.add_theme_constant_override(
			"separation",
			10
		)

		close_button.text = "CLOSE"

	set_meta(
		"stick_fighter_live_surface_renderer_only",
		true
	)
func _render_provider_map_size_selector(
	setup: Dictionary
) -> void:
	var rows: Array = _array(
		setup.get(
			"map_size_rows",
			[]
		)
	)

	if rows.is_empty():
		return

	_add_section_heading(
		"MAP SIZE",
		(
			"Map size is provider-authored combat geometry, "
			+ "not a renderer scale toggle."
		)
	)

	var row:= HBoxContainer.new()

	row.alignment = (
		BoxContainer.ALIGNMENT_CENTER
	)

	row.add_theme_constant_override(
		"separation",
		10
	)

	content_root.add_child(
		row
	)

	for raw_size in rows:
		var size_contract: Dictionary = _dict(
			raw_size
		)

		var selected: bool = bool(
			size_contract.get(
				"selected",
				false
			)
		)

		var button:= Button.new()

		button.text = str(
			size_contract.get(
				"title",
				"MAP"
			)
		).to_upper()

		button.tooltip_text = str(
			size_contract.get(
				"description",
				"Stick Fighter map size."
			)
		)

		button.disabled = selected

		button.focus_mode = (
			Control.FOCUS_NONE
		)

		button.custom_minimum_size = Vector2(
			150.0,
			44.0
		)

		_apply_button_style(
			button
		)

		if not selected:
			button.pressed.connect(
				_emit_intent.bind(
					_dict(
						size_contract.get(
							"select_action",
							{}
						)
					)
				)
			)

		row.add_child(
			button
		)

		_register_animated_button(
			button
		)
func has_renderable_contract(actor_id: int = -1) -> bool:
	if active_contract.is_empty():
		return false

	if actor_id < 0:
		return true

	return int(active_contract.get("actor_id", -1)) == actor_id


func hide_surface() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	animation_time += delta
	_update_scroll_visibility(delta)
	_update_animated_surfaces()


func _rebuild_tabs() -> void:
	_clear_children(tab_row)

	for raw_tab in _array(active_contract.get("section_tabs", [])):
		var tab: Dictionary = _dict(raw_tab)
		var section_id: String = _section(str(tab.get("id", "games")))
		var button:= Button.new()
		button.text = (
			"%s %s" % [str(tab.get("icon", "•")), str(tab.get("label", section_id.to_upper()))]
		)
		button.toggle_mode = true
		button.button_pressed = section_id == active_section
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(126.0, 38.0)
		_apply_button_style(button)
		button.pressed.connect(_on_section_pressed.bind(section_id))
		tab_row.add_child(button)


func _rebuild_active_section() -> void:
	_clear_children(content_root)
	animated_cards.clear()
	animated_buttons.clear()

	match active_section:
		"games":
			_render_games()
		"session":
			_render_session()
		"multiplayer":
			_render_multiplayer()
		"tournaments":
			_render_tournaments()
		"leaderboards":
			_render_leaderboards()
		"achievements":
			_render_achievements()
		"replays":
			_render_replays()
		"mods":
			_render_mod_games()
		_:
			_render_games()

	content_scroll.scroll_vertical = 0


func _render_games() -> void:
	var provider_setup: Dictionary = _dict(
		active_contract.get(
			"provider_setup_contract",
			{}
		)
	)

	if not provider_setup.is_empty():
		_render_provider_setup(
			provider_setup
		)
		return

	var rows: Array = _array(
		active_contract.get(
			"provider_rows",
			[]
		)
	)

	var first_party: Array = []

	for raw_row in rows:
		var row: Dictionary = _dict(
			raw_row
		)

		if bool(
			row.get(
				"mod_created_minigame",
				false
			)
		):
			continue

		first_party.append(
			row
		)

	_add_section_heading(
		"AVAILABLE GAMES",
		(
			"The host exposes providers. Launching is always "
			+ "a committed intent."
		)
	)

	_render_provider_grid(
		first_party
	)
func _render_provider_setup(
	setup: Dictionary
) -> void:
	_add_section_heading(
		str(
			setup.get(
				"title",
				"STICK FIGHTER"
			)
		),
		str(
			setup.get(
				"subtitle",
				"Configure the committed match."
			)
		)
	)

	var fighter_count_label:= Label.new()
	fighter_count_label.text = (
		"%d TOTAL FIGHTERS • %d CPU OPPONENTS"
		% [
			int(
				setup.get(
					"total_fighters",
					2
				)
			),
			int(
				setup.get(
					"selected_opponent_count",
					1
				)
			)
		]
	)
	fighter_count_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	fighter_count_label.add_theme_font_size_override(
		"font_size",
		15
	)
	fighter_count_label.add_theme_color_override(
		"font_color",
		Color(
			0.82,
			0.88,
			0.98,
			1.0
		)
	)
	content_root.add_child(
		fighter_count_label
	)

	_add_section_heading(
		"CHOOSE ARENA",
		"The selected arena is owned by the provider setup contract."
	)

	var arena_grid:= GridContainer.new()
	arena_grid.columns = 2
	arena_grid.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	arena_grid.add_theme_constant_override(
		"h_separation",
		12
	)
	arena_grid.add_theme_constant_override(
		"v_separation",
		12
	)
	content_root.add_child(
		arena_grid
	)

	for raw_arena in _array(
		setup.get(
			"arena_rows",
			[]
		)
	):
		var arena: Dictionary = _dict(
			raw_arena
		)

		var card:= _card()
		arena_grid.add_child(
			card
		)

		var box:= VBoxContainer.new()
		box.add_theme_constant_override(
			"separation",
			7
		)
		card.add_child(
			box
		)

		var selected: bool = bool(
			arena.get(
				"selected",
				false
			)
		)

		_add_card_title(
			box,
			str(
				arena.get(
					"title",
					"Arena"
				)
			),
			(
				"SELECTED"
				if selected
				else "ARENA"
			)
		)

		_add_body(
			box,
			str(
				arena.get(
					"description",
					"Stick Fighter arena."
				)
			)
		)

		var select_button:= Button.new()
		select_button.text = (
			"SELECTED"
			if selected
			else "CHOOSE ARENA"
		)
		select_button.disabled = selected
		select_button.focus_mode = (
			Control.FOCUS_NONE
		)
		select_button.custom_minimum_size = Vector2(
			0.0,
			40.0
		)

		_apply_button_style(
			select_button
		)

		if not selected:
			select_button.pressed.connect(
				_emit_intent.bind(
					_dict(
						arena.get(
							"select_action",
							{}
						)
					)
				)
			)

		box.add_child(
			select_button
		)
		_register_animated_button(
			select_button
		)


	_render_provider_map_size_selector(
		setup
	)

	_add_section_heading(
		"SOLO OPPONENTS",
		"Choose one, two, or three CPUs. Four total fighters is the maximum."
	)

	var opponent_row:= HBoxContainer.new()
	opponent_row.alignment = (
		BoxContainer.ALIGNMENT_CENTER
	)
	opponent_row.add_theme_constant_override(
		"separation",
		10
	)
	content_root.add_child(
		opponent_row
	)

	for raw_opponent in _array(
		setup.get(
			"opponent_rows",
			[]
		)
	):
		var opponent: Dictionary = _dict(
			raw_opponent
		)

		var selected: bool = bool(
			opponent.get(
				"selected",
				false
			)
		)

		var button:= Button.new()
		button.text = (
			"%d CPU%s • %d TOTAL"
			% [
				int(
					opponent.get(
						"opponent_count",
						1
					)
				),
				(
					""
					if int(
						opponent.get(
							"opponent_count",
							1
						)
					) == 1
					else "S"
				),
				int(
					opponent.get(
						"total_fighters",
						2
					)
				)
			]
		)

		button.disabled = selected
		button.focus_mode = (
			Control.FOCUS_NONE
		)
		button.custom_minimum_size = Vector2(
			150.0,
			44.0
		)

		_apply_button_style(
			button
		)

		if not selected:
			button.pressed.connect(
				_emit_intent.bind(
					_dict(
						opponent.get(
							"select_action",
							{}
						)
					)
				)
			)

		opponent_row.add_child(
			button
		)
		_register_animated_button(
			button
		)

	_render_provider_ai_difficulty_selector(
		setup
	)

	var start_button:= Button.new()
	start_button.text = (
		"START SOLO MATCH • %s • %s"
		% [
			str(
				setup.get(
					"selected_arena_id",
					"arena"
				)
			).replace(
				"_",
				" "
			).to_upper(),
			str(
				setup.get(
					"selected_ai_difficulty_id",
					"normal"
				)
			).replace(
				"_",
				" "
			).to_upper()
		]
	)
	start_button.focus_mode = (
		Control.FOCUS_NONE
	)
	start_button.custom_minimum_size = Vector2(
		0.0,
		56.0
	)

	_apply_button_style(
		start_button
	)

	start_button.pressed.connect(
		_emit_intent.bind(
			_dict(
				setup.get(
					"start_action",
					{}
				)
			)
		)
	)

	content_root.add_child(
		start_button
	)
	_register_animated_button(
		start_button
	)

	var back_button:= Button.new()
	back_button.text = "BACK TO GAMES"
	back_button.focus_mode = (
		Control.FOCUS_NONE
	)

	_apply_button_style(
		back_button
	)

	back_button.pressed.connect(
		_emit_intent.bind(
			_dict(
				setup.get(
					"back_action",
					{}
				)
			)
		)
	)

	content_root.add_child(
		back_button
	)
	_register_animated_button(
		back_button
	)

	set_meta(
		"minigame_provider_setup_renderer_only",
		true
	)
func _render_provider_ai_difficulty_selector(
	setup: Dictionary
) -> void:
	var rows: Array = _array(
		setup.get(
			"ai_difficulty_rows",
			[]
		)
	)

	if rows.is_empty():
		return

	_add_section_heading(
		"AI DIFFICULTY",
		(
			"Difficulty changes reaction quality and aggression. "
			+ "Every level still obeys provider-authored attack recovery."
		)
	)

	var grid:= GridContainer.new()
	grid.columns = 2
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

	content_root.add_child(
		grid
	)

	for raw_difficulty in rows:
		var difficulty: Dictionary = _dict(
			raw_difficulty
		)

		var selected: bool = bool(
			difficulty.get(
				"selected",
				false
			)
		)

		var card:= _card()
		grid.add_child(
			card
		)

		var box:= VBoxContainer.new()
		box.add_theme_constant_override(
			"separation",
			5
		)
		card.add_child(
			box
		)

		_add_card_title(
			box,
			str(
				difficulty.get(
					"title",
					"NORMAL"
				)
			),
			(
				"SELECTED"
				if selected
				else "AI"
			)
		)

		_add_body(
			box,
			str(
				difficulty.get(
					"description",
					"CPU combat difficulty."
				)
			)
		)

		var button:= Button.new()
		button.text = (
			"SELECTED"
			if selected
			else "SELECT"
		)
		button.disabled = selected
		button.focus_mode = (
			Control.FOCUS_NONE
		)
		button.custom_minimum_size = Vector2(
			0.0,
			40.0
		)

		_apply_button_style(
			button
		)

		if not selected:
			button.pressed.connect(
				_emit_intent.bind(
					_dict(
						difficulty.get(
							"select_action",
							{}
						)
					)
				)
			)

		box.add_child(
			button
		)
		_register_animated_button(
			button
		)


func _render_mod_games() -> void:
	var mod_rows: Array = []

	for raw_row in _array(active_contract.get("provider_rows", [])):
		var row: Dictionary = _dict(raw_row)

		if bool(row.get("mod_created_minigame", false)):
			mod_rows.append(row)

	_add_section_heading(
		"MOD-CREATED MINIGAMES", "Installed providers enter the same persistent session contract."
	)
	_render_provider_grid(mod_rows)


func _render_provider_grid(rows: Array) -> void:
	if rows.is_empty():
		_add_empty_state("No compatible minigame providers are observable on this host.")
		return

	var grid:= GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	content_root.add_child(grid)

	for raw_row in rows:
		var row: Dictionary = _dict(raw_row)
		var card:= _card()
		grid.add_child(card)
		var box:= VBoxContainer.new()
		box.add_theme_constant_override("separation", 7)
		card.add_child(box)
		_add_card_title(
			box,
			str(row.get("title", "Untitled Game")),
			str(row.get("subtitle", row.get("category", "MINIGAME"))).to_upper()
		)
		_add_body(box, str(row.get("description", "Persistent minigame provider.")))
		var modes:= Label.new()
		modes.text = "Modes: %s" % ", ".join(_string_array(row.get("supported_modes", [])))
		modes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		modes.add_theme_font_size_override("font_size", 10)
		modes.add_theme_color_override("font_color", Color(0.62, 0.68, 0.8, 1.0))
		box.add_child(modes)
		var launch:= Button.new()
		launch.text = "PLAY"
		launch.focus_mode = Control.FOCUS_NONE
		launch.custom_minimum_size = Vector2(0.0, 40.0)
		_apply_button_style(launch)
		launch.pressed.connect(_emit_intent.bind(_dict(row.get("launch_action", {}))))
		box.add_child(launch)
		_register_animated_button(launch)


func _render_session() -> void:
	var session: Dictionary = _dict(
		active_contract.get(
			"session_contract",
			{}
		)
	)

	if session.is_empty():
		_add_empty_state(
			"No active session exists. Choose a game first."
		)
		return

	_add_section_heading(
		str(
			session.get(
				"game_title",
				"LIVE SESSION"
			)
		),
		(
			"Reality committed • Session %s"
			% str(
				session.get(
					"session_id",
					""
				)
			)
		)
	)

	var projection: Dictionary = _dict(
		session.get(
			"ui_projection",
			{}
		)
	)

	var projection_kind: String = str(
		projection.get(
			"projection_kind",
			""
		)
	).strip_edges().to_lower()

	if (
		projection_kind == "stick_fighter_stage"
		and bool(
			projection.get(
				"continuous_simulation",
				false
			)
		)
	):
		stick_fighter_live_session_id = str(
			session.get(
				"session_id",
				""
			)
		)

		_render_stick_fighter_stage(
			projection
		)
		_capture_stick_fighter_live_stage_nodes(
			projection
		)
		_render_stick_fighter_live_hud(
			projection
		)

		var live_event_card:= _card()
		content_root.add_child(
			live_event_card
		)

		stick_fighter_live_event_label = Label.new()
		stick_fighter_live_event_label.text = str(
			projection.get(
				"headline",
				"The session is live."
			)
		)
		stick_fighter_live_event_label.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_CENTER
		)
		stick_fighter_live_event_label.autowrap_mode = (
			TextServer.AUTOWRAP_WORD_SMART
		)
		stick_fighter_live_event_label.add_theme_font_size_override(
			"font_size",
			18
		)
		stick_fighter_live_event_label.add_theme_color_override(
			"font_color",
			Color(
				1.0,
				0.79,
				0.36,
				1.0
			)
		)
		live_event_card.add_child(
			stick_fighter_live_event_label
		)

		var live_leave:= Button.new()
		live_leave.text = "RETURN TO GAMES"
		live_leave.focus_mode = Control.FOCUS_NONE
		_apply_button_style(
			live_leave
		)
		live_leave.pressed.connect(
			_emit_intent.bind(
				{
					"action_id": "leave_session",
					"active_section": "games",
					"host_contract": _dict(
						session.get(
							"host_contract",
							{}
						)
					).duplicate(true),
					"ui_is_renderer_only": true
				}
			)
		)
		content_root.add_child(
			live_leave
		)
		_register_animated_button(
			live_leave
		)

		set_meta(
			"stick_fighter_generic_action_grid_rendered",
			false
		)
		return




	if projection_kind == "stick_fighter_stage":
		_render_stick_fighter_stage(
			projection
		)

	var provider_state: Dictionary = _dict(
		session.get(
			"provider_state",
			{}
		)
	)
	var fighters: Dictionary = _dict(
		provider_state.get(
			"fighters",
			{}
		)
	)

	var fighter_grid:= GridContainer.new()
	fighter_grid.columns = maxi(
		1,
		mini(
			2,
			fighters.size()
		)
	)
	fighter_grid.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	fighter_grid.add_theme_constant_override(
		"h_separation",
		12
	)
	fighter_grid.add_theme_constant_override(
		"v_separation",
		12
	)
	content_root.add_child(
		fighter_grid
	)

	for raw_fighter in fighters.values():
		var fighter: Dictionary = _dict(
			raw_fighter
		)
		var fighter_card:= _card()
		fighter_grid.add_child(
			fighter_card
		)
		var fighter_box:= VBoxContainer.new()
		fighter_box.add_theme_constant_override(
			"separation",
			6
		)
		fighter_card.add_child(
			fighter_box
		)

		_add_card_title(
			fighter_box,
			str(
				fighter.get(
					"display_name",
					"Fighter"
				)
			),
			str(
				fighter.get(
					"state",
					"idle"
				)
			).to_upper()
		)

		_add_progress(
			fighter_box,
			"HEALTH",
			float(
				fighter.get(
					"health",
					0
				)
			),
			100.0
		)
		_add_progress(
			fighter_box,
			"STAMINA",
			float(
				fighter.get(
					"stamina",
					0
				)
			),
			100.0
		)
		_add_progress(
			fighter_box,
			"SPECIAL",
			float(
				fighter.get(
					"special_meter",
					0
				)
			),
			100.0
		)

	var event_card:= _card()
	content_root.add_child(
		event_card
	)

	var event_label:= Label.new()
	event_label.text = str(
		projection.get(
			"headline",
			provider_state.get(
				"last_event_text",
				"The session is live."
			)
		)
	)
	event_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	event_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	event_label.add_theme_font_size_override(
		"font_size",
		18
	)
	event_label.add_theme_color_override(
		"font_color",
		Color(
			1.0,
			0.79,
			0.36,
			1.0
		)
	)
	event_card.add_child(
		event_label
	)

	var action_grid:= GridContainer.new()
	action_grid.columns = 4
	action_grid.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	action_grid.add_theme_constant_override(
		"h_separation",
		8
	)
	action_grid.add_theme_constant_override(
		"v_separation",
		8
	)
	content_root.add_child(
		action_grid
	)

	for raw_action in _array(
		session.get(
			"actions",
			[]
		)
	):
		var action: Dictionary = _dict(
			raw_action
		)
		var button:= Button.new()
		button.text = str(
			action.get(
				"label",
				action.get(
					"action_id",
					"ACTION"
				)
			)
		).to_upper()
		button.disabled = not bool(
			action.get(
				"enabled",
				true
			)
		)
		button.tooltip_text = str(
			action.get(
				"description",
				""
			)
		)
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(
			120.0,
			48.0
		)

		_apply_button_style(
			button
		)

		var action_payload: Dictionary = {
			"action_id": "game_action",
			"game_action_id": str(
				action.get(
					"action_id",
					""
				)
			),
			"session_id": str(
				session.get(
					"session_id",
					""
				)
			),
			"provider_id": str(
				session.get(
					"provider_id",
					""
				)
			),
			"host_contract": _dict(
				session.get(
					"host_contract",
					{}
				)
			).duplicate(true),
			"active_section": "session",
			"ui_is_renderer_only": true
		}

		button.pressed.connect(
			_emit_intent.bind(
				action_payload
			)
		)
		action_grid.add_child(
			button
		)
		_register_animated_button(
			button
		)

	var leave:= Button.new()
	leave.text = "RETURN TO GAMES"
	leave.focus_mode = Control.FOCUS_NONE
	_apply_button_style(
		leave
	)
	leave.pressed.connect(
		_emit_intent.bind(
			{
				"action_id": "leave_session",
				"active_section": "games",
				"host_contract": _dict(
					session.get(
						"host_contract",
						{}
					)
				).duplicate(true),
				"ui_is_renderer_only": true
			}
		)
	)
	content_root.add_child(
		leave
	)
	_register_animated_button(
		leave
	)
func _capture_stick_fighter_live_stage_nodes(
	projection: Dictionary
) -> void:
	stick_fighter_live_fighter_nodes = {}
	stick_fighter_live_arena = null
	stick_fighter_live_stage_label = null

	var stage_contract: Dictionary = _dict(
		projection.get(
			"stage_contract",
			{}
		)
	)

	stick_fighter_live_stage_width = maxf(
		1.0,
		float(
			stage_contract.get(
				"width",
				100.0
			)
		)
	)
	stick_fighter_live_stage_height = maxf(
		1.0,
		float(
			stage_contract.get(
				"height",
				56.0
			)
		)
	)

	var arena_node: Node = content_root.find_child(
		"StickFighterArena",
		true,
		false
	)

	if not (
		arena_node is Control
	):
		return

	stick_fighter_live_arena = (
		arena_node as Control
	)

	for child in stick_fighter_live_arena.get_children():
		if (
			stick_fighter_live_stage_label == null
			and child is Label
		):
			stick_fighter_live_stage_label = (
				child as Label
			)

	for raw_fighter in _array(
		projection.get(
			"fighters",
			[]
		)
	):
		var fighter: Dictionary = _dict(
			raw_fighter
		)
		var identity_key: String = str(
			fighter.get(
				"identity_key",
				""
			)
		)
		var fighter_index: int = int(
			fighter.get(
				"fighter_index",
				0
			)
		)

		if identity_key == "":
			continue

		var expected_body_name: String = (
			"StickFighterBody%d"
			% fighter_index
		)

		for child in stick_fighter_live_arena.get_children():
			if not (
				child is Control
			):
				continue

			var anchor: Control = child as Control

			if anchor.get_node_or_null(
				expected_body_name
			) == null:
				continue

			stick_fighter_live_fighter_nodes [
				identity_key
			] = {
				"anchor": anchor,
				"visual_signature": (
					"%s:%d"
					% [
						str(
							fighter.get(
								"state",
								"idle"
							)
						),
						int(
							fighter.get(
								"facing",
								1
							)
						)
					]
				)
			}
			break


func _render_stick_fighter_live_hud(
	projection: Dictionary
) -> void:
	stick_fighter_live_hud_nodes = {}

	if (
		stick_fighter_live_arena == null
		or not is_instance_valid(
			stick_fighter_live_arena
		)
	):
		return

	var fighters: Array = _array(
		projection.get(
			"fighters",
			[]
		)
	)

	if fighters.is_empty():
		return

	var hud_layer:= Control.new()
	hud_layer.name = "StickFighterHudLayer"
	hud_layer.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	hud_layer.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	stick_fighter_live_arena.add_child(
		hud_layer
	)

	var columns: int = (
		2
		if fighters.size() > 2
		else maxi(
			1,
			fighters.size()
		)
	)

	for fighter_index in range(
		fighters.size()
	):
		var fighter: Dictionary = _dict(
			fighters [
				fighter_index
			]
		)

		var identity_key: String = str(
			fighter.get(
				"identity_key",
				""
			)
		)

		if identity_key == "":
			continue

		var column: int = (
			fighter_index
			% columns
		)

		var row_index: int = floori(
			float(
				fighter_index
			)
			/ float(
				columns
			)
		)

		var cell_width: float = (
			0.31
			if columns == 2
			else 0.62
		)

		var left_anchor: float = (
			0.018
			+ float(
				column
			) * 0.325
		)

		var top_anchor: float = (
			0.075
			+ float(
				row_index
			) * 0.185
		)

		var card:= _card()
		card.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)
		card.anchor_left = left_anchor
		card.anchor_right = minf(
			0.67,
			left_anchor + cell_width
		)
		card.anchor_top = top_anchor
		card.anchor_bottom = minf(
			0.47,
			top_anchor + 0.165
		)

		hud_layer.add_child(
			card
		)

		var box:= VBoxContainer.new()
		box.add_theme_constant_override(
			"separation",
			2
		)
		card.add_child(
			box
		)

		var name_label:= Label.new()
		name_label.text = str(
			fighter.get(
				"display_name",
				"Fighter"
			)
		)
		name_label.add_theme_font_size_override(
			"font_size",
			13
		)
		box.add_child(
			name_label
		)

		var state_label:= Label.new()
		state_label.text = str(
			fighter.get(
				"state",
				"idle"
			)
		).to_upper()
		state_label.add_theme_font_size_override(
			"font_size",
			9
		)
		box.add_child(
			state_label
		)

		var health_label:= Label.new()
		health_label.text = (
			"HEALTH %d"
			% int(
				fighter.get(
					"health",
					0
				)
			)
		)
		health_label.add_theme_font_size_override(
			"font_size",
			9
		)
		box.add_child(
			health_label
		)

		var health_bar:= ProgressBar.new()
		health_bar.max_value = 100.0
		health_bar.value = float(
			fighter.get(
				"health",
				0
			)
		)
		health_bar.show_percentage = false
		health_bar.custom_minimum_size = Vector2(
			0.0,
			8.0
		)
		box.add_child(
			health_bar
		)

		var stamina_label:= Label.new()
		stamina_label.text = (
			"STAMINA %d"
			% int(
				fighter.get(
					"stamina",
					0
				)
			)
		)
		stamina_label.add_theme_font_size_override(
			"font_size",
			9
		)
		box.add_child(
			stamina_label
		)

		var stamina_bar:= ProgressBar.new()
		stamina_bar.max_value = 100.0
		stamina_bar.value = float(
			fighter.get(
				"stamina",
				0
			)
		)
		stamina_bar.show_percentage = false
		stamina_bar.custom_minimum_size = Vector2(
			0.0,
			8.0
		)
		box.add_child(
			stamina_bar
		)

		var special_label:= Label.new()
		special_label.text = (
			"SPECIAL %d"
			% int(
				fighter.get(
					"special_meter",
					0
				)
			)
		)
		special_label.add_theme_font_size_override(
			"font_size",
			9
		)
		box.add_child(
			special_label
		)

		var special_bar:= ProgressBar.new()
		special_bar.max_value = 100.0
		special_bar.value = float(
			fighter.get(
				"special_meter",
				0
			)
		)
		special_bar.show_percentage = false
		special_bar.custom_minimum_size = Vector2(
			0.0,
			8.0
		)
		box.add_child(
			special_bar
		)

		stick_fighter_live_hud_nodes [
			identity_key
		] = {
			"state_label": state_label,
			"health_label": health_label,
			"health_bar": health_bar,
			"stamina_label": stamina_label,
			"stamina_bar": stamina_bar,
			"special_label": special_label,
			"special_bar": special_bar
		}

	hud_layer.move_to_front()

	set_meta(
		"stick_fighter_hud_overlay_renderer_only",
		true
	)

func render_session_observation_packet(
	packet: Dictionary
) -> void:
	if str(
		packet.get(
			"schema",
			""
		)
	).strip_edges().to_lower() != (
		"eralife.minigame_session_observation_packet"
	):
		return

	if str(
		packet.get(
			"session_id",
			""
		)
	) != stick_fighter_live_session_id:
		return

	var revision: int = int(
		packet.get(
			"revision",
			-1
		)
	)

	if revision <= stick_fighter_live_revision:
		return

	var projection: Dictionary = _dict(
		packet.get(
			"ui_projection",
			{}
		)
	)

	if str(
		projection.get(
			"projection_kind",
			""
		)
	).strip_edges().to_lower() != "stick_fighter_stage":
		return

	stick_fighter_live_revision = revision

	_paint_stick_fighter_live_projection(
		projection
	)

	if status_label != null:
		status_label.text = str(
			packet.get(
				"status_text",
				projection.get(
					"headline",
					"Stick Fighter is live."
				)
			)
		)

	set_meta(
		"stick_fighter_live_observation_revision",
		revision
	)
	set_meta(
		"stick_fighter_live_hub_rebuild",
		false
	)
	set_meta(
		"stick_fighter_live_content_root_rebuild",
		false
	)


func _paint_stick_fighter_live_projection(
	projection: Dictionary
) -> void:
	if (
		stick_fighter_live_arena == null
		or not is_instance_valid(
			stick_fighter_live_arena
		)
	):
		return

	var stage_contract: Dictionary = _dict(
		projection.get(
			"stage_contract",
			{}
		)
	)

	var blast_margin_x: float = maxf(
		0.0,
		float(
			stage_contract.get(
				"blast_zone_margin_x",
				12.0
			)
		)
	)

	var blast_margin_y: float = maxf(
		0.0,
		float(
			stage_contract.get(
				"blast_zone_margin_y",
				10.0
			)
		)
	)

	if (
		stick_fighter_live_stage_label != null
		and is_instance_valid(
			stick_fighter_live_stage_label
		)
	):
		stick_fighter_live_stage_label.text = (
			"%s • %s • ROUND %d • %d FIGHTERS"
			% [
				str(
					projection.get(
						"stage",
						"Neon Alley"
					)
				).to_upper(),
				str(
					projection.get(
						"map_size_title",
						"STANDARD"
					)
				).to_upper(),
				int(
					projection.get(
						"round",
						1
					)
				),
				int(
					projection.get(
						"fighter_count",
						2
					)
				)
			]
		)

	if (
		stick_fighter_live_countdown_label != null
		and is_instance_valid(
			stick_fighter_live_countdown_label
		)
	):
		var phase: String = str(
			projection.get(
				"phase",
				"fighting"
			)
		)

		if phase == "countdown":
			stick_fighter_live_countdown_label.text = str(
				projection.get(
					"countdown_value",
					5
				)
			)
			stick_fighter_live_countdown_label.visible = true
		elif bool(
			projection.get(
				"fight_banner_visible",
				false
			)
		):
			stick_fighter_live_countdown_label.text = "FIGHT!"
			stick_fighter_live_countdown_label.visible = true
		else:
			stick_fighter_live_countdown_label.text = ""
			stick_fighter_live_countdown_label.visible = false

	for raw_fighter in _array(
		projection.get(
			"fighters",
			[]
		)
	):
		var fighter: Dictionary = _dict(
			raw_fighter
		)

		var identity_key: String = str(
			fighter.get(
				"identity_key",
				""
			)
		)

		var live_row: Dictionary = _dict(
			stick_fighter_live_fighter_nodes.get(
				identity_key,
				{}
			)
		)

		var anchor_raw: Variant = live_row.get(
			"anchor",
			null
		)

		if not (
			anchor_raw is Control
		):
			continue

		var anchor: Control = (
			anchor_raw as Control
		)

		var stage_x: float = clampf(
			float(
				fighter.get(
					"stage_x",
					50.0
				)
			),
			- blast_margin_x,
			stick_fighter_live_stage_width
			+ blast_margin_x
		)

		var stage_y: float = clampf(
			float(
				fighter.get(
					"stage_y",
					50.0
				)
			),
			-18.0,
			stick_fighter_live_stage_height
			+ blast_margin_y
			+ 2.0
		)

		anchor.anchor_left = (
			stage_x
			/ stick_fighter_live_stage_width
		)
		anchor.anchor_right = anchor.anchor_left
		anchor.anchor_top = (
			stage_y
			/ stick_fighter_live_stage_height
		)
		anchor.anchor_bottom = anchor.anchor_top

		var equipped: Dictionary = _dict(
			fighter.get(
				"equipped_weapon",
				{}
			)
		)

		var weapon_signature: String = (
			"%s:%s"
			% [
				str(
					equipped.get(
						"weapon_id",
						""
					)
				),
				str(
					equipped.get(
						"visual_kind",
						""
					)
				)
			]
		)

		var current_facing: int = (
			-1
			if int(
				fighter.get(
					"facing",
					1
				)
			) < 0
			else 1
		)



		if weapon_signature != str(
			live_row.get(
				"weapon_signature",
				"__uninitialized__"
			)
		):
			_clear_children(
				anchor
			)

			_add_stick_fighter_body(
				anchor,
				fighter
			)

			live_row [
				"weapon_signature"
			] = weapon_signature

			live_row [
				"draw_facing"
			] = current_facing

		_paint_stick_fighter_live_body_transform(
			anchor,
			fighter,
			live_row
		)

		stick_fighter_live_fighter_nodes [
			identity_key
		] = live_row

		var hud: Dictionary = _dict(
			stick_fighter_live_hud_nodes.get(
				identity_key,
				{}
			)
		)

		var state_label:= (
			hud.get(
				"state_label",
				null
			) as Label
		)

		if state_label != null:
			state_label.text = str(
				fighter.get(
					"state",
					"idle"
				)
			).to_upper()

		var health_label:= (
			hud.get(
				"health_label",
				null
			) as Label
		)

		var health_bar:= (
			hud.get(
				"health_bar",
				null
			) as ProgressBar
		)

		if health_label != null:
			health_label.text = (
				"HEALTH %d"
				% int(
					fighter.get(
						"health",
						0
					)
				)
			)

		if health_bar != null:
			health_bar.value = float(
				fighter.get(
					"health",
					0
				)
			)

		var stamina_label:= (
			hud.get(
				"stamina_label",
				null
			) as Label
		)

		var stamina_bar:= (
			hud.get(
				"stamina_bar",
				null
			) as ProgressBar
		)

		if stamina_label != null:
			stamina_label.text = (
				"STAMINA %d"
				% int(
					fighter.get(
						"stamina",
						0
					)
				)
			)

		if stamina_bar != null:
			stamina_bar.value = float(
				fighter.get(
					"stamina",
					0
				)
			)

		var special_label:= (
			hud.get(
				"special_label",
				null
			) as Label
		)

		var special_bar:= (
			hud.get(
				"special_bar",
				null
			) as ProgressBar
		)

		if special_label != null:
			special_label.text = (
				"SPECIAL %d"
				% int(
					fighter.get(
						"special_meter",
						0
					)
				)
			)

		if special_bar != null:
			special_bar.value = float(
				fighter.get(
					"special_meter",
					0
				)
			)

	_sync_stick_fighter_live_observation_nodes(
		projection
	)

	if (
		stick_fighter_live_event_label != null
		and is_instance_valid(
			stick_fighter_live_event_label
		)
	):
		stick_fighter_live_event_label.text = str(
			projection.get(
				"headline",
				""
			)
		)

	_render_stick_fighter_damage_feedback(
		stick_fighter_live_arena,
		projection
	)

func _set_stick_fighter_rig_line(
	body: Node2D,
	node_name: String,
	points: PackedVector2Array
) -> void:
	var line:= (
		body.get_node_or_null(
			node_name
		) as Line2D
	)

	if line == null:
		return

	line.points = points


func _set_stick_fighter_rig_joint(
	body: Node2D,
	node_name: String,
	position_value: Vector2,
	radius: float
) -> void:
	var joint:= (
		body.get_node_or_null(
			node_name
		) as Polygon2D
	)

	if joint == null:
		return

	joint.polygon = _stick_fighter_circle_polygon(
		position_value,
		radius,
		10
	)


func _paint_stick_fighter_live_limb_pose(
	body: Node2D,
	fighter: Dictionary,
	draw_facing: int
) -> void:
	var pose_facing: float = (
		-1.0
		if draw_facing < 0
		else 1.0
	)
	var state: String = str(
		fighter.get(
			"state",
			"idle"
		)
	).strip_edges().to_lower()
	var simulation_step: int = int(
		fighter.get(
			"simulation_step",
			0
		)
	)

	var shoulder:= Vector2(
		0.0,
		-34.0
	)
	var hip:= Vector2(
		0.0,
		-14.0
	)
	var left_elbow:= Vector2(
		-9.0,
		-25.0
	)
	var right_elbow:= Vector2(
		9.0,
		-25.0
	)
	var left_hand:= Vector2(
		-17.0,
		-19.0
	)
	var right_hand:= Vector2(
		17.0,
		-19.0
	)
	var left_knee:= Vector2(
		-6.0,
		-7.0
	)
	var right_knee:= Vector2(
		6.0,
		-7.0
	)
	var left_foot:= Vector2(
		-11.0,
		0.0
	)
	var right_foot:= Vector2(
		11.0,
		0.0
	)

	if (
		state == "walk"
		and not bool(
			fighter.get(
				"airborne",
				false
			)
		)
	):
		var walk_phase: float = sin(
			float(
				simulation_step
			) * 0.42
		)
		var opposite_phase: float = - walk_phase

		left_knee = Vector2(
			-6.0 + walk_phase * 3.0,
			-7.0 - absf(
				walk_phase
			) * 1.5
		)
		left_foot = Vector2(
			-11.0 + walk_phase * 9.0,
			- absf(
				walk_phase
			) * 1.8
		)
		right_knee = Vector2(
			6.0 + opposite_phase * 3.0,
			-7.0 - absf(
				opposite_phase
			) * 1.5
		)
		right_foot = Vector2(
			11.0 + opposite_phase * 9.0,
			- absf(
				opposite_phase
			) * 1.8
		)
		left_elbow = Vector2(
			-9.0 - walk_phase * 2.5,
			-25.0
		)
		left_hand = Vector2(
			-17.0 - walk_phase * 5.0,
			-19.0
		)
		right_elbow = Vector2(
			9.0 + walk_phase * 2.5,
			-25.0
		)
		right_hand = Vector2(
			17.0 + walk_phase * 5.0,
			-19.0
		)

	match state:
		"punch":
			if pose_facing > 0.0:
				right_elbow = Vector2(
					15.0,
					-27.0
				)
				right_hand = Vector2(
					31.0,
					-26.0
				)
			else:
				left_elbow = Vector2(
					-15.0,
					-27.0
				)
				left_hand = Vector2(
					-31.0,
					-26.0
				)

		"weapon_attack", "fire":
			if pose_facing > 0.0:
				right_elbow = Vector2(
					14.0,
					-28.0
				)
				right_hand = Vector2(
					22.0,
					-23.0
				)
			else:
				left_elbow = Vector2(
					-14.0,
					-28.0
				)
				left_hand = Vector2(
					-22.0,
					-23.0
				)

		"grenade_aim":
			if pose_facing > 0.0:
				right_elbow = Vector2(
					8.0,
					-34.0
				)
				right_hand = Vector2(
					17.0,
					-42.0
				)
			else:
				left_elbow = Vector2(
					-8.0,
					-34.0
				)
				left_hand = Vector2(
					-17.0,
					-42.0
				)

		"kick":
			if pose_facing > 0.0:
				right_knee = Vector2(
					10.0,
					-9.0
				)
				right_foot = Vector2(
					30.0,
					-6.0
				)
			else:
				left_knee = Vector2(
					-10.0,
					-9.0
				)
				left_foot = Vector2(
					-30.0,
					-6.0
				)

		"block":
			left_elbow = Vector2(
				-7.0,
				-27.0
			)
			right_elbow = Vector2(
				7.0,
				-27.0
			)
			left_hand = Vector2(
				-6.0,
				-35.0
			)
			right_hand = Vector2(
				6.0,
				-35.0
			)

		"jump", "drop_in", "drop", "fall":
			left_knee = Vector2(
				-8.0,
				-8.0
			)
			right_knee = Vector2(
				8.0,
				-8.0
			)
			left_foot = Vector2(
				-14.0,
				-2.0
			)
			right_foot = Vector2(
				14.0,
				-2.0
			)
			left_hand = Vector2(
				-18.0,
				-32.0
			)
			right_hand = Vector2(
				18.0,
				-32.0
			)

		"special":
			left_elbow = Vector2(
				-17.0,
				-31.0
			)
			right_elbow = Vector2(
				17.0,
				-31.0
			)
			left_hand = Vector2(
				-30.0,
				-34.0
			)
			right_hand = Vector2(
				30.0,
				-34.0
			)
			left_foot = Vector2(
				-18.0,
				0.0
			)
			right_foot = Vector2(
				18.0,
				0.0
			)

	_set_stick_fighter_rig_line(
		body,
		"RigLeftArmOutline",
		PackedVector2Array([
			shoulder,
			left_elbow,
			left_hand
		])
	)
	_set_stick_fighter_rig_line(
		body,
		"RigLeftArmFill",
		PackedVector2Array([
			shoulder,
			left_elbow,
			left_hand
		])
	)
	_set_stick_fighter_rig_line(
		body,
		"RigRightArmOutline",
		PackedVector2Array([
			shoulder,
			right_elbow,
			right_hand
		])
	)
	_set_stick_fighter_rig_line(
		body,
		"RigRightArmFill",
		PackedVector2Array([
			shoulder,
			right_elbow,
			right_hand
		])
	)
	_set_stick_fighter_rig_line(
		body,
		"RigLeftLegOutline",
		PackedVector2Array([
			hip,
			left_knee,
			left_foot
		])
	)
	_set_stick_fighter_rig_line(
		body,
		"RigLeftLegFill",
		PackedVector2Array([
			hip,
			left_knee,
			left_foot
		])
	)
	_set_stick_fighter_rig_line(
		body,
		"RigRightLegOutline",
		PackedVector2Array([
			hip,
			right_knee,
			right_foot
		])
	)
	_set_stick_fighter_rig_line(
		body,
		"RigRightLegFill",
		PackedVector2Array([
			hip,
			right_knee,
			right_foot
		])
	)

	var joint_rows: Array = [
		{
			"name": "Shoulder",
			"position": shoulder
		},
		{
			"name": "Hip",
			"position": hip
		},
		{
			"name": "LeftElbow",
			"position": left_elbow
		},
		{
			"name": "RightElbow",
			"position": right_elbow
		},
		{
			"name": "LeftKnee",
			"position": left_knee
		},
		{
			"name": "RightKnee",
			"position": right_knee
		},
		{
			"name": "LeftHand",
			"position": left_hand
		},
		{
			"name": "RightHand",
			"position": right_hand
		},
		{
			"name": "LeftFoot",
			"position": left_foot
		},
		{
			"name": "RightFoot",
			"position": right_foot
		}
	]

	for raw_joint in joint_rows:
		var joint: Dictionary = raw_joint as Dictionary
		var joint_name: String = str(
			joint.get(
				"name",
				""
			)
		)
		var joint_position: Vector2 = joint.get(
			"position",
			Vector2.ZERO
		)

		_set_stick_fighter_rig_joint(
			body,
			"Rig%sOutline" % joint_name,
			joint_position,
			3.0
		)
		_set_stick_fighter_rig_joint(
			body,
			"Rig%sFill" % joint_name,
			joint_position,
			1.8
		)

	var trajectory:= (
		body.get_node_or_null(
			"GrenadeAimTrajectory"
		) as Line2D
	)
	var equipped: Dictionary = _dict(
		fighter.get(
			"equipped_weapon",
			{}
		)
	)
	var grenade_aim_active: bool = (
		str(
			equipped.get(
				"weapon_id",
				""
			)
		).strip_edges().to_lower() == "grenade"
		and bool(
			equipped.get(
				"grenade_aim_active",
				false
			)
		)
	)

	if trajectory != null:
		trajectory.visible = grenade_aim_active

		if grenade_aim_active:
			var charge_ratio: float = clampf(
				float(
					equipped.get(
						"grenade_charge_ratio",
						0.0
					)
				),
				0.0,
				1.0
			)
			var start:= Vector2(
				17.0 * pose_facing,
				-42.0
			)
			var horizontal_reach: float = lerpf(
				36.0,
				88.0,
				charge_ratio
			)
			var vertical_lift: float = lerpf(
				22.0,
				56.0,
				charge_ratio
			)
			var points:= PackedVector2Array()

			for point_index in range(
				13
			):
				var t: float = (
					float(
						point_index
					) / 12.0
				)
				points.append(
					Vector2(
						start.x
						+ pose_facing
						* horizontal_reach
						* t,
						start.y
						- vertical_lift * t
						+ 62.0 * t * t
					)
				)

			trajectory.points = points
func _paint_stick_fighter_live_body_transform(
	anchor: Control,
	fighter: Dictionary,
	live_row: Dictionary
) -> void:
	var body:= (
		anchor.get_node_or_null(
			"StickFighterBody%d"
			% int(
				fighter.get(
					"fighter_index",
					0
				)
			)
		) as Node2D
	)

	if body == null:
		return

	var current_facing: int = (
		-1
		if int(
			fighter.get(
				"facing",
				1
			)
		) < 0
		else 1
	)
	var draw_facing: int = int(
		live_row.get(
			"draw_facing",
			current_facing
		)
	)
	var horizontal_flip: float = (
		1.0
		if current_facing == draw_facing
		else -1.0
	)
	var animation_contract: Dictionary = _dict(
		fighter.get(
			"animation_contract",
			{}
		)
	)
	var animation_id: String = str(
		animation_contract.get(
			"animation_id",
			fighter.get(
				"state",
				"idle"
			)
		)
	).strip_edges().to_lower()
	var animation_progress: float = clampf(
		float(
			animation_contract.get(
				"progress",
				0.0
			)
		),
		0.0,
		1.0
	)
	var state: String = str(
		fighter.get(
			"state",
			"idle"
		)
	).strip_edges().to_lower()

	body.scale = Vector2(
		horizontal_flip,
		1.0
	)
	body.position = Vector2.ZERO
	body.rotation = 0.0

	match animation_id:
		"punch":
			body.position.x = (
				sin(
					animation_progress * PI
				)
				* 4.8
				* float(
					current_facing
				)
			)
			body.rotation = deg_to_rad(
				-6.0
				* sin(
					animation_progress * PI
				)
				* float(
					current_facing
				)
			)

		"air_punch":
			body.position.x = (
				sin(
					animation_progress * PI
				)
				* 5.5
				* float(
					current_facing
				)
			)
			body.position.y = -4.0
			body.rotation = deg_to_rad(
				-10.0
				* sin(
					animation_progress * PI
				)
				* float(
					current_facing
				)
			)

		"kick":
			body.position.x = (
				sin(
					animation_progress * PI
				)
				* 2.0
				* float(
					current_facing
				)
			)
			body.rotation = deg_to_rad(
				-8.0
				* sin(
					animation_progress * PI
				)
				* float(
					current_facing
				)
			)

		"sweep":
			body.position.y = 3.0
			body.rotation = deg_to_rad(
				12.0
				* sin(
					animation_progress * PI
				)
				* float(
					current_facing
				)
			)

		"swept_fall":
			body.position.y = (
				2.0
				+ 3.0
				* sin(
					animation_progress * PI
				)
			)
			body.rotation = deg_to_rad(
				78.0
				* sin(
					animation_progress * PI
				)
				* float(
					current_facing
				)
			)

		"weapon_attack":
			body.position.x = (
				sin(
					animation_progress * PI
				)
				* 3.4
				* float(
					current_facing
				)
			)
			body.rotation = deg_to_rad(
				-7.0
				* sin(
					animation_progress * PI
				)
				* float(
					current_facing
				)
			)

		"fire":
			body.position.x = (
				- sin(
					animation_progress * PI
				)
				* 2.2
				* float(
					current_facing
				)
			)
			body.rotation = deg_to_rad(
				3.5
				* sin(
					animation_progress * PI
				)
				* float(
					current_facing
				)
			)

		_:
			match state:
				"knockout":
					body.rotation = deg_to_rad(
						82.0
						* float(
							current_facing
						)
					)
					body.position.y = -3.0

				"hurt":
					body.rotation = deg_to_rad(
						-8.0
						* float(
							current_facing
						)
					)

				"jump", "double_jump", "drop_in", "drop", "fall", "respawn":
					body.position.y = -3.0


	_paint_stick_fighter_live_limb_pose(
		body,
		fighter,
		draw_facing
	)


	_apply_stick_fighter_aaa_limb_animation(
		body,
		fighter,
		draw_facing
	)

	var weapon_layer:= (
		body.get_node_or_null(
			"StickFighterWeaponLayer"
		) as Node2D
	)

	if weapon_layer != null:
		weapon_layer.position = Vector2.ZERO
		weapon_layer.rotation = 0.0

		match animation_id:
			"weapon_attack":
				var swing_angle: float = (
					lerpf(
						-72.0,
						58.0,
						clampf(
							animation_progress / 0.58,
							0.0,
							1.0
						)
					)
					if animation_progress < 0.58
					else lerpf(
						58.0,
						0.0,
						clampf(
							(
								animation_progress
								- 0.58
							) / 0.42,
							0.0,
							1.0
						)
					)
				)

				weapon_layer.rotation = deg_to_rad(
					swing_angle
					* float(
						draw_facing
					)
				)
				weapon_layer.position = Vector2(
					2.0
					* sin(
						animation_progress * PI
					)
					* float(
						draw_facing
					),
					-2.0
					* sin(
						animation_progress * PI
					)
				)

			"fire":
				weapon_layer.position.x = (
					-4.0
					* sin(
						animation_progress * PI
					)
					* float(
						draw_facing
					)
				)
				weapon_layer.rotation = deg_to_rad(
					-5.0
					* sin(
						animation_progress * PI
					)
					* float(
						draw_facing
					)
				)

	var simulation_step: int = int(
		fighter.get(
			"simulation_step",
			0
		)
	)
	var hit_flash_until_step: int = int(
		fighter.get(
			"hit_flash_until_step",
			-1
		)
	)

	body.modulate = (
		Color(
			1.0,
			0.3,
			0.3,
			1.0
		)
		if simulation_step <= hit_flash_until_step
		else Color.WHITE
	)

	var equipped: Dictionary = _dict(
		fighter.get(
			"equipped_weapon",
			{}
		)
	)
	var display_text: String = str(
		fighter.get(
			"display_name",
			"Fighter"
		)
	)

	if not equipped.is_empty():
		var ammo: int = int(
			equipped.get(
				"ammo",
				-1
			)
		)

		display_text += (
			" • %s%s"
			% [
				str(
					equipped.get(
						"title",
						"WEAPON"
					)
				).to_upper(),
				(
					" [%d]"
					% ammo
					if ammo >= 0
					else ""
				)
			]
		)

	for child in anchor.get_children():
		if child is Label:
			(child as Label).text = display_text
			break
func _sync_stick_fighter_live_stock_hud(
	projection: Dictionary
) -> void:
	if (
		stick_fighter_live_arena == null
		or not is_instance_valid(
			stick_fighter_live_arena
		)
	):
		return

	var existing:= (
		stick_fighter_live_arena.get_node_or_null(
			"StickFighterStockHud"
		) as Label
	)

	var stock_mode: bool = bool(
		projection.get(
			"stock_mode",
			false
		)
	)

	if not stock_mode:
		if existing != null:
			existing.queue_free()

		return

	var label: Label = existing

	if label == null:
		label = Label.new()
		label.name = "StickFighterStockHud"
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE

		label.anchor_left = 0.7
		label.anchor_right = 0.985
		label.anchor_top = 0.075
		label.anchor_bottom = 0.31

		label.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_RIGHT
		)
		label.vertical_alignment = (
			VERTICAL_ALIGNMENT_TOP
		)
		label.autowrap_mode = (
			TextServer.AUTOWRAP_WORD_SMART
		)

		label.add_theme_font_size_override(
			"font_size",
			12
		)
		label.add_theme_color_override(
			"font_color",
			Color(
				0.98,
				0.98,
				1.0,
				0.96
			)
		)

		stick_fighter_live_arena.add_child(
			label
		)

	var lines:= PackedStringArray()

	for raw_fighter in _array(
		projection.get(
			"fighters",
			[]
		)
	):
		var fighter: Dictionary = _dict(
			raw_fighter
		)
		var status_suffix: String = ""

		if bool(
			fighter.get(
				"eliminated",
				false
			)
		):
			status_suffix = " • OUT"
		elif bool(
			fighter.get(
				"respawn_pending",
				false
			)
		):
			status_suffix = " • RESPAWNING"

		lines.append(
			"%s  ♥ %d%s"
			% [
				str(
					fighter.get(
						"display_name",
						"Fighter"
					)
				),
				int(
					fighter.get(
						"stock_lives_remaining",
						0
					)
				),
				status_suffix
			]
		)

	label.text = (
		"STOCKS\n%s"
		% "\n".join(
			lines
		)
	)

	label.move_to_front()


func _sync_stick_fighter_live_observation_nodes(
	projection: Dictionary
) -> void:
	_sync_stick_fighter_live_weapon_drops(
		projection
	)
	_sync_stick_fighter_live_projectiles(
		projection
	)
	_sync_stick_fighter_live_effects(
		projection
	)
	_sync_stick_fighter_live_stock_hud(
		projection
	)

func _position_stick_fighter_live_node(
	node: Control,
	x: float,
	y: float
) -> void:
	if node == null:
		return

	node.anchor_left = (
		x
		/ stick_fighter_live_stage_width
	)
	node.anchor_right = node.anchor_left
	node.anchor_top = (
		y
		/ stick_fighter_live_stage_height
	)
	node.anchor_bottom = node.anchor_top


func _sync_stick_fighter_live_weapon_drops(
	projection: Dictionary
) -> void:
	var observed_keys: Dictionary = {}
	var simulation_step: int = int(
		projection.get(
			"simulation_step",
			0
		)
	)

	for raw_drop in _array(
		projection.get(
			"weapon_drops",
			[]
		)
	):
		var drop: Dictionary = _dict(
			raw_drop
		)
		var drop_id: String = str(
			drop.get(
				"drop_id",
				""
			)
		)

		if drop_id == "":
			continue

		observed_keys [
			drop_id
		] = true

		var node:= (
			stick_fighter_live_weapon_drop_nodes.get(
				drop_id,
				null
			) as PanelContainer
		)

		if (
			node == null
			or not is_instance_valid(
				node
			)
		):
			node = PanelContainer.new()
			node.name = (
				"StickFighterWeaponDrop_%s"
				% drop_id
			)
			node.mouse_filter = (
				Control.MOUSE_FILTER_IGNORE
			)
			node.offset_left = -34.0
			node.offset_right = 34.0
			node.offset_top = -24.0
			node.offset_bottom = 24.0

			var aura_color: Color = (
				_stick_fighter_projection_color(
					drop.get(
						"aura_rgba",
						[]
					),
					Color(
						0.8,
						0.84,
						0.94,
						0.62
					)
				)
			)

			var style:= StyleBoxFlat.new()
			style.bg_color = Color(
				aura_color.r,
				aura_color.g,
				aura_color.b,
				minf(
					0.28,
					aura_color.a
				)
			)
			style.border_color = aura_color
			style.border_width_left = 2
			style.border_width_top = 2
			style.border_width_right = 2
			style.border_width_bottom = 2
			style.corner_radius_top_left = 22
			style.corner_radius_top_right = 22
			style.corner_radius_bottom_left = 22
			style.corner_radius_bottom_right = 22

			node.add_theme_stylebox_override(
				"panel",
				style
			)

			var created_weapon_visual:= Node2D.new()
			created_weapon_visual.name = "WeaponVisual"
			created_weapon_visual.position = Vector2(
				22.0,
				30.0
			)
			created_weapon_visual.scale = Vector2(
				0.55,
				0.55
			)

			node.add_child(
				created_weapon_visual
			)

			var synthetic_fighter: Dictionary = {
				"equipped_weapon": {
					"weapon_id": str(
						drop.get(
							"weapon_id",
							""
						)
					),
					"title": str(
						drop.get(
							"title",
							"WEAPON"
						)
					),
					"visual_kind": str(
						drop.get(
							"visual_kind",
							"weapon"
						)
					)
				}
			}

			_add_stick_fighter_weapon_visual(
				created_weapon_visual,
				synthetic_fighter,
				1.0,
				aura_color
			)

			var created_weapon_label:= Label.new()
			created_weapon_label.name = "WeaponLabel"
			created_weapon_label.horizontal_alignment = (
				HORIZONTAL_ALIGNMENT_CENTER
			)
			created_weapon_label.vertical_alignment = (
				VERTICAL_ALIGNMENT_BOTTOM
			)
			created_weapon_label.set_anchors_and_offsets_preset(
				Control.PRESET_FULL_RECT
			)
			created_weapon_label.offset_top = 26.0
			created_weapon_label.add_theme_font_size_override(
				"font_size",
				9
			)
			created_weapon_label.add_theme_color_override(
				"font_color",
				Color(
					0.98,
					0.98,
					1.0,
					1.0
				)
			)

			node.add_child(
				created_weapon_label
			)

			stick_fighter_live_arena.add_child(
				node
			)

			stick_fighter_live_weapon_drop_nodes [
				drop_id
			] = node

		var weapon_label:= (
			node.get_node_or_null(
				"WeaponLabel"
			) as Label
		)

		if weapon_label != null:
			weapon_label.text = str(
				drop.get(
					"title",
					"WEAPON"
				)
			).to_upper()

		var weapon_visual:= (
			node.get_node_or_null(
				"WeaponVisual"
			) as Node2D
		)

		if weapon_visual != null:
			var drift_phase: float = (
				float(
					simulation_step
				) * 0.055
				+ float(
					absi(
						drop_id.hash()
					) % 360
				) * 0.0174533
			)

			weapon_visual.position = Vector2(
				22.0
				+ sin(
					drift_phase
				) * 2.4,
				30.0
				+ cos(
					drift_phase * 0.83
				) * 2.1
			)

			weapon_visual.rotation = deg_to_rad(
				sin(
					drift_phase * 0.71
				) * 7.0
			)

		_position_stick_fighter_live_node(
			node,
			float(
				drop.get(
					"x",
					50.0
				)
			),
			float(
				drop.get(
					"y",
					50.0
				)
			) - 2.0
		)

	for raw_key in (
		stick_fighter_live_weapon_drop_nodes
		.keys()
		.duplicate()
	):
		var drop_id: String = str(
			raw_key
		)

		if observed_keys.has(
			drop_id
		):
			continue

		var stale_node:= (
			stick_fighter_live_weapon_drop_nodes.get(
				drop_id,
				null
			) as Control
		)

		if (
			stale_node != null
			and is_instance_valid(
				stale_node
			)
		):
			stale_node.queue_free()

		stick_fighter_live_weapon_drop_nodes.erase(
			drop_id
		)

func reveal_pending_observation(
	section_id: String = "games",
	status_text: String = "MiniGame observation is publishing.",
	preserve_tabs: bool = false
) -> bool:
	if (
		root == null
		or not is_instance_valid(
			root
		)
	):
		return false

	var clean_section: String = _section(
		section_id
	)



	active_section = clean_section

	_set_stick_fighter_live_surface_mode(
		false
	)

	title_label.text = "MINIGAME ECOSYSTEM"
	subtitle_label.text = (
		"Persistent games hosted as contract realities."
	)
	status_label.text = status_text



	identity_label.visible = false
	tab_scroll.visible = (
		preserve_tabs
		and tab_row.get_child_count() > 0
	)
	content_scroll.visible = false

	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	move_to_front()

	set_meta(
		"minigame_pending_observation_visible",
		true
	)
	set_meta(
		"minigame_pending_observation_section",
		clean_section
	)
	set_meta(
		"minigame_pending_observation_build_performed",
		false
	)
	set_meta(
		"minigame_pending_observation_engine_calls",
		false
	)
	set_meta(
		"minigame_pending_observation_truth_mutated",
		false
	)

	return true
func _sync_stick_fighter_live_projectiles(
	projection: Dictionary
) -> void:
	var observed_keys: Dictionary = {}

	for raw_projectile in _array(
		projection.get(
			"projectiles",
			[]
		)
	):
		var projectile: Dictionary = _dict(
			raw_projectile
		)
		var projectile_id: String = str(
			projectile.get(
				"projectile_id",
				""
			)
		)

		if projectile_id == "":
			continue

		observed_keys [
			projectile_id
		] = true

		var node:= (
			stick_fighter_live_projectile_nodes.get(
				projectile_id,
				null
			) as Label
		)

		if (
			node == null
			or not is_instance_valid(
				node
			)
		):
			node = Label.new()
			node.name = (
				"StickFighterProjectile_%s"
				% projectile_id
			)
			node.mouse_filter = (
				Control.MOUSE_FILTER_IGNORE
			)
			node.horizontal_alignment = (
				HORIZONTAL_ALIGNMENT_CENTER
			)
			node.vertical_alignment = (
				VERTICAL_ALIGNMENT_CENTER
			)
			node.offset_left = -18.0
			node.offset_right = 18.0
			node.offset_top = -18.0
			node.offset_bottom = 18.0
			node.pivot_offset = Vector2(
				18.0,
				18.0
			)
			stick_fighter_live_arena.add_child(
				node
			)
			stick_fighter_live_projectile_nodes [
				projectile_id
			] = node

		var visual_kind: String = str(
			projectile.get(
				"visual_kind",
				projectile.get(
					"projectile_kind",
					"bullet"
				)
			)
		).strip_edges().to_lower()

		match visual_kind:
			"arrow":
				node.text = "➤"
				node.add_theme_font_size_override(
					"font_size",
					20
				)
			"knife":
				node.text = "▰"
				node.add_theme_font_size_override(
					"font_size",
					18
				)
			"grenade":
				node.text = "●"
				node.add_theme_font_size_override(
					"font_size",
					20
				)
			"rocket":
				node.text = "➤"
				node.add_theme_font_size_override(
					"font_size",
					22
				)
			_:
				node.text = "▬"
				node.add_theme_font_size_override(
					"font_size",
					17
				)

		node.add_theme_color_override(
			"font_color",
			(
				Color(
					0.96,
					0.42,
					0.22,
					1.0
				)
				if visual_kind == "rocket"
				else Color(
					1.0,
					0.92,
					0.58,
					1.0
				)
			)
		)

		var velocity:= Vector2(
			float(
				projectile.get(
					"vx",
					0.0
				)
			),
			float(
				projectile.get(
					"vy",
					0.0
				)
			)
		)

		node.rotation = (
			0.0
			if visual_kind == "grenade"
			else velocity.angle()
		)

		_position_stick_fighter_live_node(
			node,
			float(
				projectile.get(
					"x",
					50.0
				)
			),
			float(
				projectile.get(
					"y",
					50.0
				)
			)
		)

	for raw_key in (
		stick_fighter_live_projectile_nodes
		.keys()
		.duplicate()
	):
		var projectile_id: String = str(
			raw_key
		)

		if observed_keys.has(
			projectile_id
		):
			continue

		var stale_node:= (
			stick_fighter_live_projectile_nodes.get(
				projectile_id,
				null
			) as Control
		)

		if (
			stale_node != null
			and is_instance_valid(
				stale_node
			)
		):
			stale_node.queue_free()

		stick_fighter_live_projectile_nodes.erase(
			projectile_id
		)

func _sync_stick_fighter_live_effects(
	projection: Dictionary
) -> void:
	var observed_keys: Dictionary = {}

	for raw_effect in _array(
		projection.get(
			"combat_effects",
			[]
		)
	):
		var effect: Dictionary = _dict(
			raw_effect
		)

		var effect_id: String = str(
			effect.get(
				"effect_id",
				""
			)
		)

		if effect_id == "":
			continue

		observed_keys [
			effect_id
		] = true

		var node:= (
			stick_fighter_live_effect_nodes.get(
				effect_id,
				null
			) as Label
		)

		if (
			node == null
			or not is_instance_valid(
				node
			)
		):
			node = Label.new()
			node.name = (
				"StickFighterEffect_%s"
				% effect_id
			)
			node.mouse_filter = (
				Control.MOUSE_FILTER_IGNORE
			)
			node.offset_left = -18.0
			node.offset_right = 18.0
			node.offset_top = -18.0
			node.offset_bottom = 18.0
			node.horizontal_alignment = (
				HORIZONTAL_ALIGNMENT_CENTER
			)
			node.vertical_alignment = (
				VERTICAL_ALIGNMENT_CENTER
			)

			var effect_kind: String = str(
				effect.get(
					"effect_kind",
					"impact_spark"
				)
			)

			match effect_kind:
				"blood_spray":
					node.text = "✦"
					node.add_theme_font_size_override(
						"font_size",
						20
					)
					node.add_theme_color_override(
						"font_color",
						Color(
							0.82,
							0.05,
							0.08,
							0.92
						)
					)

				"explosion":
					node.text = "✹"
					node.add_theme_font_size_override(
						"font_size",
						30
					)
					node.add_theme_color_override(
						"font_color",
						Color(
							1.0,
							0.52,
							0.08,
							1.0
						)
					)

				"muzzle_flash":
					node.text = "✦"
					node.add_theme_font_size_override(
						"font_size",
						18
					)
					node.add_theme_color_override(
						"font_color",
						Color(
							1.0,
							0.92,
							0.38,
							1.0
						)
					)

				_:
					node.text = "✧"
					node.add_theme_font_size_override(
						"font_size",
						16
					)
					node.add_theme_color_override(
						"font_color",
						Color(
							0.92,
							0.95,
							1.0,
							0.92
						)
					)

			stick_fighter_live_arena.add_child(
				node
			)

			stick_fighter_live_effect_nodes [
				effect_id
			] = node

		_position_stick_fighter_live_node(
			node,
			float(
				effect.get(
					"x",
					50.0
				)
			),
			float(
				effect.get(
					"y",
					28.0
				)
			)
		)

	for raw_key in (
		stick_fighter_live_effect_nodes
		.keys()
		.duplicate()
	):
		var effect_id: String = str(
			raw_key
		)

		if observed_keys.has(
			effect_id
		):
			continue

		var stale_node:= (
			stick_fighter_live_effect_nodes.get(
				effect_id,
				null
			) as Control
		)

		if (
			stale_node != null
			and is_instance_valid(
				stale_node
			)
		):
			stale_node.queue_free()

		stick_fighter_live_effect_nodes.erase(
			effect_id
		)
func _render_stick_fighter_stage(
	projection: Dictionary
) -> void:
	var stage_contract: Dictionary = _dict(
		projection.get(
			"stage_contract",
			{}
		)
	)

	if stage_contract.is_empty():
		return

	var stage_width: float = maxf(
		1.0,
		float(
			stage_contract.get(
				"width",
				100.0
			)
		)
	)

	var stage_height: float = maxf(
		1.0,
		float(
			stage_contract.get(
				"height",
				56.0
			)
		)
	)

	var blast_margin_x: float = maxf(
		0.0,
		float(
			stage_contract.get(
				"blast_zone_margin_x",
				12.0
			)
		)
	)

	var blast_margin_y: float = maxf(
		0.0,
		float(
			stage_contract.get(
				"blast_zone_margin_y",
				10.0
			)
		)
	)

	var continuous_live: bool = bool(
		projection.get(
			"continuous_simulation",
			false
		)
	)

	var background_color: Color = (
		_stick_fighter_projection_color(
			stage_contract.get(
				"background_rgba",
				[]
			),
			Color(
				0.035,
				0.045,
				0.07,
				1.0
			)
		)
	)

	var platform_color: Color = (
		_stick_fighter_projection_color(
			stage_contract.get(
				"platform_rgba",
				[]
			),
			Color(
				0.3,
				0.39,
				0.52,
				0.92
			)
		)
	)

	var accent_color: Color = (
		_stick_fighter_projection_color(
			stage_contract.get(
				"accent_rgba",
				[]
			),
			Color(
				1.0,
				0.78,
				0.32,
				1.0
			)
		)
	)

	var stage_card:= _card()
	stage_card.custom_minimum_size = Vector2(
		0.0,
		(
			560.0
			if continuous_live
			else 340.0
		)
	)
	stage_card.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
		if continuous_live
		else Control.SIZE_FILL
	)

	content_root.add_child(
		stage_card
	)

	var arena:= Control.new()
	arena.name = "StickFighterArena"
	arena.custom_minimum_size = Vector2(
		0.0,
		(
			540.0
			if continuous_live
			else 320.0
		)
	)
	arena.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	arena.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	arena.clip_contents = true
	stage_card.add_child(
		arena
	)

	var background:= ColorRect.new()
	background.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	background.color = background_color
	background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	arena.add_child(
		background
	)

	var stage_label:= Label.new()
	stage_label.name = "StickFighterStageLabel"
	stage_label.text = (
		"%s • %s • ROUND %d • %d FIGHTERS"
		% [
			str(
				projection.get(
					"stage",
					"Neon Alley"
				)
			).to_upper(),
			str(
				projection.get(
					"map_size_title",
					"STANDARD"
				)
			).to_upper(),
			int(
				projection.get(
					"round",
					1
				)
			),
			int(
				projection.get(
					"fighter_count",
					2
				)
			)
		]
	)
	stage_label.position = Vector2(
		14.0,
		10.0
	)
	stage_label.add_theme_font_size_override(
		"font_size",
		16
	)
	stage_label.add_theme_color_override(
		"font_color",
		accent_color
	)
	arena.add_child(
		stage_label
	)

	var countdown_label:= Label.new()
	countdown_label.name = "StickFighterCountdownLabel"
	countdown_label.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	countdown_label.anchor_left = 0.25
	countdown_label.anchor_right = 0.75
	countdown_label.anchor_top = 0.16
	countdown_label.anchor_bottom = 0.58
	countdown_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	countdown_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)
	countdown_label.add_theme_font_size_override(
		"font_size",
		82
	)
	countdown_label.add_theme_constant_override(
		"outline_size",
		10
	)
	countdown_label.add_theme_color_override(
		"font_color",
		Color(
			1.0,
			0.92,
			0.7,
			1.0
		)
	)
	countdown_label.add_theme_color_override(
		"font_outline_color",
		Color(
			0.02,
			0.025,
			0.04,
			0.92
		)
	)

	var phase: String = str(
		projection.get(
			"phase",
			"fighting"
		)
	)

	if phase == "countdown":
		countdown_label.text = str(
			projection.get(
				"countdown_value",
				5
			)
		)
		countdown_label.visible = true
	elif bool(
		projection.get(
			"fight_banner_visible",
			false
		)
	):
		countdown_label.text = "FIGHT!"
		countdown_label.visible = true
	else:
		countdown_label.text = ""
		countdown_label.visible = false

	arena.add_child(
		countdown_label
	)

	stick_fighter_live_countdown_label = countdown_label

	for raw_platform in _array(
		stage_contract.get(
			"platforms",
			[]
		)
	):
		var platform_contract: Dictionary = _dict(
			raw_platform
		)

		_add_stick_fighter_platform_visual(
			arena,
			platform_contract,
			platform_color,
			accent_color,
			stage_width,
			stage_height
		)

	for raw_fighter in _array(
		projection.get(
			"fighters",
			[]
		)
	):
		var fighter: Dictionary = _dict(
			raw_fighter
		)

		var identity_key: String = str(
			fighter.get(
				"identity_key",
				""
			)
		)

		var stage_x: float = clampf(
			float(
				fighter.get(
					"stage_x",
					fighter.get(
						"x",
						50.0
					)
				)
			),
			- blast_margin_x,
			stage_width + blast_margin_x
		)

		var stage_y: float = clampf(
			float(
				fighter.get(
					"stage_y",
					50.0
				)
			),
			-18.0,
			stage_height + blast_margin_y + 2.0
		)

		var fighter_anchor:= Control.new()
		fighter_anchor.name = (
			"StickFighterAnchor%d"
			% int(
				fighter.get(
					"fighter_index",
					0
				)
			)
		)
		fighter_anchor.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)
		fighter_anchor.anchor_left = (
			stage_x / stage_width
		)
		fighter_anchor.anchor_right = (
			stage_x / stage_width
		)
		fighter_anchor.anchor_top = (
			stage_y / stage_height
		)
		fighter_anchor.anchor_bottom = (
			stage_y / stage_height
		)
		fighter_anchor.offset_left = 0.0
		fighter_anchor.offset_right = 0.0
		fighter_anchor.offset_top = 0.0
		fighter_anchor.offset_bottom = 0.0
		fighter_anchor.set_meta(
			"stick_fighter_identity_key",
			identity_key
		)

		arena.add_child(
			fighter_anchor
		)

		_add_stick_fighter_body(
			fighter_anchor,
			fighter
		)

	var controls_card:= PanelContainer.new()
	controls_card.anchor_left = 0.7
	controls_card.anchor_right = 0.985
	controls_card.anchor_top = 0.055
	controls_card.anchor_bottom = 0.5
	controls_card.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	arena.add_child(
		controls_card
	)

	var controls_margin:= MarginContainer.new()
	controls_margin.add_theme_constant_override(
		"margin_left",
		10
	)
	controls_margin.add_theme_constant_override(
		"margin_right",
		10
	)
	controls_margin.add_theme_constant_override(
		"margin_top",
		8
	)
	controls_margin.add_theme_constant_override(
		"margin_bottom",
		8
	)
	controls_card.add_child(
		controls_margin
	)

	var controls_box:= VBoxContainer.new()
	controls_box.add_theme_constant_override(
		"separation",
		3
	)
	controls_margin.add_child(
		controls_box
	)

	var controls_title:= Label.new()
	controls_title.text = "CONTROLS"
	controls_title.add_theme_font_size_override(
		"font_size",
		13
	)
	controls_title.add_theme_color_override(
		"font_color",
		accent_color
	)
	controls_box.add_child(
		controls_title
	)

	for raw_control in _array(
		projection.get(
			"controls_key",
			[]
		)
	):
		var control_contract: Dictionary = _dict(
			raw_control
		)

		var control_label:= Label.new()

		control_label.text = (
			"%s • %s"
			% [
				str(
					control_contract.get(
						"label",
						"ACTION"
					)
				),
				str(
					control_contract.get(
						"actions",
						""
					)
				)
			]
		)

		control_label.tooltip_text = str(
			control_contract.get(
				"description",
				""
			)
		)
		control_label.add_theme_font_size_override(
			"font_size",
			11
		)
		control_label.add_theme_color_override(
			"font_color",
			Color(
				0.84,
				0.88,
				0.96,
				1.0
			)
		)

		controls_box.add_child(
			control_label
		)

	_render_stick_fighter_damage_feedback(
		arena,
		projection
	)

	set_meta(
		"stick_fighter_stage_projection_rendered",
		true
	)
	set_meta(
		"stick_fighter_stage_renderer_owns_physics",
		false
	)
	set_meta(
		"stick_fighter_stage_uses_real_2d_canvas_items",
		true
	)
	set_meta(
		"stick_fighter_stage_fullscreen_live_surface",
		continuous_live
	)
func _add_stick_fighter_weapon_visual(
	body: Node2D,
	fighter: Dictionary,
	facing: float,
	fighter_color: Color
) -> void:
	var equipped: Dictionary = _dict(
		fighter.get(
			"equipped_weapon",
			{}
		)
	)

	if equipped.is_empty():
		return

	var visual_kind: String = str(
		equipped.get(
			"visual_kind",
			""
		)
	).strip_edges().to_lower()

	if visual_kind == "":
		return

	var direction: float = (
		-1.0
		if facing < 0.0
		else 1.0
	)

	var grip:= Vector2(
		18.0 * direction,
		-21.0
	)

	var metal_color:= Color(
		0.82,
		0.87,
		0.94,
		1.0
	)

	var dark_metal:= Color(
		0.13,
		0.16,
		0.22,
		1.0
	)

	var wood_color:= Color(
		0.48,
		0.29,
		0.14,
		1.0
	)

	match visual_kind:
		"bat":
			_stick_fighter_add_line(
				body,
				PackedVector2Array([
					grip,
					Vector2(
						39.0 * direction,
						-31.0
					)
				]),
				dark_metal,
				7.0
			)

			_stick_fighter_add_line(
				body,
				PackedVector2Array([
					grip,
					Vector2(
						39.0 * direction,
						-31.0
					)
				]),
				wood_color,
				4.5
			)

		"sword":
			_stick_fighter_add_line(
				body,
				PackedVector2Array([
					grip,
					Vector2(
						43.0 * direction,
						-34.0
					)
				]),
				metal_color,
				4.0
			)

			_stick_fighter_add_line(
				body,
				PackedVector2Array([
					Vector2(
						14.0 * direction,
						-24.0
					),
					Vector2(
						23.0 * direction,
						-18.0
					)
				]),
				Color(
					0.95,
					0.76,
					0.25,
					1.0
				),
				3.0
			)

		"hammer":
			_stick_fighter_add_line(
				body,
				PackedVector2Array([
					grip,
					Vector2(
						37.0 * direction,
						-34.0
					)
				]),
				wood_color,
				4.0
			)

			var hammer_head:= Polygon2D.new()
			hammer_head.polygon = PackedVector2Array([
				Vector2(
					31.0 * direction,
					-40.0
				),
				Vector2(
					45.0 * direction,
					-40.0
				),
				Vector2(
					45.0 * direction,
					-31.0
				),
				Vector2(
					31.0 * direction,
					-31.0
				)
			])
			hammer_head.color = dark_metal
			body.add_child(
				hammer_head
			)

		"spear":
			_stick_fighter_add_line(
				body,
				PackedVector2Array([
					Vector2(
						8.0 * direction,
						-18.0
					),
					Vector2(
						53.0 * direction,
						-31.0
					)
				]),
				wood_color,
				3.0
			)

			var spear_tip:= Polygon2D.new()
			spear_tip.polygon = PackedVector2Array([
				Vector2(
					53.0 * direction,
					-31.0
				),
				Vector2(
					44.0 * direction,
					-35.0
				),
				Vector2(
					45.0 * direction,
					-27.0
				)
			])
			spear_tip.color = metal_color
			body.add_child(
				spear_tip
			)

		"shield":
			var shield:= Polygon2D.new()
			shield.polygon = _stick_fighter_circle_polygon(
				Vector2(
					18.0 * direction,
					-25.0
				),
				8.5,
				14
			)
			shield.color = fighter_color.darkened(
				0.22
			)
			body.add_child(
				shield
			)

			_stick_fighter_add_line(
				body,
				PackedVector2Array([
					Vector2(
						18.0 * direction,
						-32.0
					),
					Vector2(
						18.0 * direction,
						-18.0
					)
				]),
				metal_color,
				2.0
			)

		"bow":
			var bow_line:= Line2D.new()
			bow_line.width = 2.5
			bow_line.default_color = wood_color
			bow_line.antialiased = true
			bow_line.points = PackedVector2Array([
				Vector2(
					24.0 * direction,
					-37.0
				),
				Vector2(
					31.0 * direction,
					-27.0
				),
				Vector2(
					24.0 * direction,
					-17.0
				)
			])
			body.add_child(
				bow_line
			)

			_stick_fighter_add_line(
				body,
				PackedVector2Array([
					Vector2(
						24.0 * direction,
						-37.0
					),
					Vector2(
						24.0 * direction,
						-17.0
					)
				]),
				metal_color,
				1.0
			)

		"knife":
			_stick_fighter_add_line(
				body,
				PackedVector2Array([
					grip,
					Vector2(
						31.0 * direction,
						-25.0
					)
				]),
				metal_color,
				3.0
			)

		"pistol":
			var pistol:= Polygon2D.new()
			pistol.polygon = PackedVector2Array([
				Vector2(
					16.0 * direction,
					-27.0
				),
				Vector2(
					32.0 * direction,
					-27.0
				),
				Vector2(
					32.0 * direction,
					-22.0
				),
				Vector2(
					21.0 * direction,
					-22.0
				),
				Vector2(
					21.0 * direction,
					-15.0
				),
				Vector2(
					17.0 * direction,
					-15.0
				)
			])
			pistol.color = dark_metal
			body.add_child(
				pistol
			)

		"uzi":
			var uzi:= Polygon2D.new()
			uzi.polygon = PackedVector2Array([
				Vector2(
					13.0 * direction,
					-28.0
				),
				Vector2(
					36.0 * direction,
					-28.0
				),
				Vector2(
					36.0 * direction,
					-22.0
				),
				Vector2(
					24.0 * direction,
					-22.0
				),
				Vector2(
					24.0 * direction,
					-13.0
				),
				Vector2(
					19.0 * direction,
					-13.0
				),
				Vector2(
					18.0 * direction,
					-22.0
				),
				Vector2(
					13.0 * direction,
					-22.0
				)
			])
			uzi.color = dark_metal
			body.add_child(
				uzi
			)

		"rocket_launcher":
			_stick_fighter_add_line(
				body,
				PackedVector2Array([
					Vector2(
						9.0 * direction,
						-31.0
					),
					Vector2(
						43.0 * direction,
						-31.0
					)
				]),
				dark_metal,
				9.0
			)

			_stick_fighter_add_line(
				body,
				PackedVector2Array([
					Vector2(
						35.0 * direction,
						-31.0
					),
					Vector2(
						47.0 * direction,
						-31.0
					)
				]),
				Color(
					0.33,
					0.4,
					0.48,
					1.0
				),
				5.0
			)

		"grenade":
			_stick_fighter_add_joint(
				body,
				Vector2(
					21.0 * direction,
					-22.0
				),
				Color(
					0.22,
					0.34,
					0.19,
					1.0
				),
				5.0
			)
func _add_stick_fighter_platform_visual(
	arena: Control,
	platform_contract: Dictionary,
	platform_color: Color,
	accent_color: Color,
	stage_width: float,
	stage_height: float
) -> void:
	var platform:= PanelContainer.new()

	platform.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	platform.anchor_left = clampf(
		float(
			platform_contract.get(
				"x",
				0.0
			)
		) / stage_width,
		0.0,
		1.0
	)

	platform.anchor_right = clampf(
		(
			float(
				platform_contract.get(
					"x",
					0.0
				)
			)
			+ float(
				platform_contract.get(
					"width",
					0.0
				)
			)
		) / stage_width,
		0.0,
		1.0
	)

	platform.anchor_top = clampf(
		float(
			platform_contract.get(
				"y",
				0.0
			)
		) / stage_height,
		0.0,
		1.0
	)

	platform.anchor_bottom = clampf(
		(
			float(
				platform_contract.get(
					"y",
					0.0
				)
			)
			+ float(
				platform_contract.get(
					"height",
					1.0
				)
			)
		) / stage_height,
		0.0,
		1.0
	)

	var surface_style: String = str(
		platform_contract.get(
			"surface_style",
			"metal"
		)
	).strip_edges().to_lower()

	var body_color: Color = platform_color
	var top_color: Color = accent_color.darkened(
		0.18
	)
	var motif_text: String = ""

	match surface_style:
		"grass":
			body_color = Color(
				0.24,
				0.17,
				0.1,
				0.98
			)

			top_color = Color(
				0.35,
				0.78,
				0.28,
				1.0
			)

			motif_text = "˄ ˄ ˄ ˄ ˄"

		"rock":
			body_color = Color(
				0.26,
				0.28,
				0.31,
				0.98
			)

			top_color = Color(
				0.48,
				0.49,
				0.52,
				1.0
			)

			motif_text = "╱╲  ╲╱"

		"crystal":
			body_color = Color(
				0.12,
				0.22,
				0.38,
				0.98
			)

			top_color = Color(
				0.35,
				0.88,
				1.0,
				1.0
			)

			motif_text = "◆ ◇ ◆"

		"concrete":
			body_color = Color(
				0.39,
				0.4,
				0.43,
				0.98
			)

			top_color = Color(
				0.64,
				0.66,
				0.7,
				1.0
			)

			motif_text = "·  ·  ·"

		_:
			motif_text = "▰  ▰  ▰"

	var style:= StyleBoxFlat.new()

	style.bg_color = body_color
	style.border_width_top = 2
	style.border_color = top_color
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2

	platform.add_theme_stylebox_override(
		"panel",
		style
	)

	arena.add_child(
		platform
	)

	if motif_text != "":
		var motif:= Label.new()

		motif.text = motif_text
		motif.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_CENTER
		)
		motif.vertical_alignment = (
			VERTICAL_ALIGNMENT_CENTER
		)
		motif.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)

		motif.add_theme_font_size_override(
			"font_size",
			10
		)

		motif.add_theme_color_override(
			"font_color",
			top_color
		)

		motif.set_anchors_and_offsets_preset(
			Control.PRESET_FULL_RECT
		)

		platform.add_child(
			motif
		)

	if bool(
		platform_contract.get(
			"drop_through",
			false
		)
	):
		var pass_through:= Label.new()

		pass_through.text = "↓"
		pass_through.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_RIGHT
		)
		pass_through.vertical_alignment = (
			VERTICAL_ALIGNMENT_CENTER
		)
		pass_through.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)

		pass_through.add_theme_font_size_override(
			"font_size",
			9
		)

		pass_through.add_theme_color_override(
			"font_color",
			Color(
				0.9,
				0.94,
				1.0,
				0.72
			)
		)

		pass_through.set_anchors_and_offsets_preset(
			Control.PRESET_FULL_RECT
		)

		platform.add_child(
			pass_through
		)
func _stick_fighter_projection_color(
	raw_value: Variant,
	fallback: Color
) -> Color:
	if typeof(raw_value) != TYPE_ARRAY:
		return fallback

	var values: Array = raw_value as Array

	if values.size() < 3:
		return fallback

	return Color(
		float(
			values [
				0
			]
		),
		float(
			values [
				1
			]
		),
		float(
			values [
				2
			]
		),
		float(
			values [
				3
			]
		)
		if values.size() > 3
		else 1.0
	)
func _stick_fighter_color(
	fighter_index: int
) -> Color:
	var palette: Array = [
		Color(
			0.47,
			0.84,
			1.0,
			1.0
		),
		Color(
			1.0,
			0.44,
			0.54,
			1.0
		),
		Color(
			0.62,
			1.0,
			0.55,
			1.0
		),
		Color(
			0.86,
			0.62,
			1.0,
			1.0
		)
	]

	return palette [
		posmod(
			fighter_index,
			palette.size()
		)
	]
func _stick_fighter_add_line(
	parent: Node,
	points: PackedVector2Array,
	color: Color,
	width: float = 4.0
) -> Line2D:
	var line:= Line2D.new()
	line.width = width
	line.default_color = color
	line.antialiased = true
	line.points = points

	parent.add_child(
		line
	)

	return line
func _add_stick_fighter_body(
	anchor: Control,
	fighter: Dictionary
) -> void:
	var fighter_index: int = int(
		fighter.get(
			"fighter_index",
			0
		)
	)
	var color: Color = _stick_fighter_color(
		fighter_index
	)
	var outline_color:= Color(
		0.045,
		0.055,
		0.075,
		1.0
	)
	var state: String = str(
		fighter.get(
			"state",
			"idle"
		)
	).strip_edges().to_lower()
	var facing: float = (
		-1.0
		if int(
			fighter.get(
				"facing",
				1
			)
		) < 0
		else 1.0
	)
	var body:= Node2D.new()

	body.name = (
		"StickFighterBody%d"
		% fighter_index
	)
	anchor.add_child(
		body
	)

	if state == "knockout":
		body.rotation = deg_to_rad(
			82.0 * facing
		)
		body.position.y = -3.0
	elif state == "hurt":
		body.rotation = deg_to_rad(
			-8.0 * facing
		)

	var shadow:= Polygon2D.new()
	shadow.polygon = PackedVector2Array([
		Vector2(-12.0, -1.0),
		Vector2(12.0, -1.0),
		Vector2(9.0, 2.0),
		Vector2(-9.0, 2.0)
	])
	shadow.color = Color(
		0.0,
		0.0,
		0.0,
		0.26
	)
	body.add_child(
		shadow
	)

	var head_center:= Vector2(
		0.0,
		-47.0
	)
	var head_outline:= Polygon2D.new()
	head_outline.polygon = _stick_fighter_circle_polygon(
		head_center,
		8.6,
		18
	)
	head_outline.color = outline_color
	body.add_child(
		head_outline
	)

	var head:= Polygon2D.new()
	head.polygon = _stick_fighter_circle_polygon(
		head_center,
		6.8,
		18
	)
	head.color = color
	body.add_child(
		head
	)

	_stick_fighter_add_joint(
		body,
		Vector2(
			2.4 * facing,
			-48.0
		),
		outline_color,
		1.0
	)

	var shoulder:= Vector2(
		0.0,
		-34.0
	)
	var hip:= Vector2(
		0.0,
		-14.0
	)
	var left_elbow:= Vector2(
		-9.0,
		-25.0
	)
	var right_elbow:= Vector2(
		9.0,
		-25.0
	)
	var left_hand:= Vector2(
		-17.0,
		-19.0
	)
	var right_hand:= Vector2(
		17.0,
		-19.0
	)
	var left_knee:= Vector2(
		-6.0,
		-7.0
	)
	var right_knee:= Vector2(
		6.0,
		-7.0
	)
	var left_foot:= Vector2(
		-11.0,
		0.0
	)
	var right_foot:= Vector2(
		11.0,
		0.0
	)

	match state:
		"punch":
			if facing > 0.0:
				right_elbow = Vector2(
					15.0,
					-27.0
				)
				right_hand = Vector2(
					31.0,
					-26.0
				)
			else:
				left_elbow = Vector2(
					-15.0,
					-27.0
				)
				left_hand = Vector2(
					-31.0,
					-26.0
				)
		"weapon_attack", "fire":
			if facing > 0.0:
				right_elbow = Vector2(
					14.0,
					-28.0
				)
				right_hand = Vector2(
					22.0,
					-23.0
				)
			else:
				left_elbow = Vector2(
					-14.0,
					-28.0
				)
				left_hand = Vector2(
					-22.0,
					-23.0
				)
		"grenade_aim":
			if facing > 0.0:
				right_elbow = Vector2(
					8.0,
					-34.0
				)
				right_hand = Vector2(
					17.0,
					-42.0
				)
			else:
				left_elbow = Vector2(
					-8.0,
					-34.0
				)
				left_hand = Vector2(
					-17.0,
					-42.0
				)
		"kick":
			if facing > 0.0:
				right_knee = Vector2(
					10.0,
					-9.0
				)
				right_foot = Vector2(
					30.0,
					-6.0
				)
			else:
				left_knee = Vector2(
					-10.0,
					-9.0
				)
				left_foot = Vector2(
					-30.0,
					-6.0
				)
		"block":
			left_elbow = Vector2(
				-7.0,
				-27.0
			)
			right_elbow = Vector2(
				7.0,
				-27.0
			)
			left_hand = Vector2(
				-6.0,
				-35.0
			)
			right_hand = Vector2(
				6.0,
				-35.0
			)
		"jump", "drop_in", "drop", "fall":
			left_knee = Vector2(
				-8.0,
				-8.0
			)
			right_knee = Vector2(
				8.0,
				-8.0
			)
			left_foot = Vector2(
				-14.0,
				-2.0
			)
			right_foot = Vector2(
				14.0,
				-2.0
			)
			left_hand = Vector2(
				-18.0,
				-32.0
			)
			right_hand = Vector2(
				18.0,
				-32.0
			)
		"special":
			left_elbow = Vector2(
				-17.0,
				-31.0
			)
			right_elbow = Vector2(
				17.0,
				-31.0
			)
			left_hand = Vector2(
				-30.0,
				-34.0
			)
			right_hand = Vector2(
				30.0,
				-34.0
			)
			left_foot = Vector2(
				-18.0,
				0.0
			)
			right_foot = Vector2(
				18.0,
				0.0
			)

	_stick_fighter_add_line(
		body,
		PackedVector2Array([
			Vector2(
				0.0,
				-39.0
			),
			shoulder,
			hip
		]),
		outline_color,
		7.0
	)
	_stick_fighter_add_line(
		body,
		PackedVector2Array([
			Vector2(
				0.0,
				-39.0
			),
			shoulder,
			hip
		]),
		color,
		4.4
	)

	var limb_rows: Array = [
		{
			"name": "LeftArm",
			"points": PackedVector2Array([
				shoulder,
				left_elbow,
				left_hand
			])
		},
		{
			"name": "RightArm",
			"points": PackedVector2Array([
				shoulder,
				right_elbow,
				right_hand
			])
		},
		{
			"name": "LeftLeg",
			"points": PackedVector2Array([
				hip,
				left_knee,
				left_foot
			])
		},
		{
			"name": "RightLeg",
			"points": PackedVector2Array([
				hip,
				right_knee,
				right_foot
			])
		}
	]

	for raw_limb in limb_rows:
		var limb: Dictionary = raw_limb as Dictionary
		var limb_name: String = str(
			limb.get(
				"name",
				"Limb"
			)
		)
		var limb_points: PackedVector2Array = limb.get(
			"points",
			PackedVector2Array()
		)

		var outline_line:= _stick_fighter_add_line(
			body,
			limb_points,
			outline_color,
			6.0
		)
		outline_line.name = (
			"Rig%sOutline"
			% limb_name
		)

		var fill_line:= _stick_fighter_add_line(
			body,
			limb_points,
			color,
			3.4
		)
		fill_line.name = (
			"Rig%sFill"
			% limb_name
		)

	var joint_rows: Array = [
		{ "name": "Shoulder", "position": shoulder},
		{ "name": "Hip", "position": hip},
		{ "name": "LeftElbow", "position": left_elbow},
		{ "name": "RightElbow", "position": right_elbow},
		{ "name": "LeftKnee", "position": left_knee},
		{ "name": "RightKnee", "position": right_knee},
		{ "name": "LeftHand", "position": left_hand},
		{ "name": "RightHand", "position": right_hand},
		{ "name": "LeftFoot", "position": left_foot},
		{ "name": "RightFoot", "position": right_foot}
	]

	for raw_joint in joint_rows:
		var joint: Dictionary = raw_joint as Dictionary
		var joint_name: String = str(
			joint.get(
				"name",
				"Joint"
			)
		)
		var joint_position: Vector2 = joint.get(
			"position",
			Vector2.ZERO
		)

		var outline_joint:= _stick_fighter_add_joint(
			body,
			joint_position,
			outline_color,
			3.0
		)
		outline_joint.name = (
			"Rig%sOutline"
			% joint_name
		)

		var fill_joint:= _stick_fighter_add_joint(
			body,
			joint_position,
			color,
			1.8
		)
		fill_joint.name = (
			"Rig%sFill"
			% joint_name
		)

	var grenade_trajectory:= Line2D.new()
	grenade_trajectory.name = "GrenadeAimTrajectory"
	grenade_trajectory.width = 1.8
	grenade_trajectory.default_color = Color(
		1.0,
		0.86,
		0.38,
		0.88
	)
	grenade_trajectory.antialiased = true
	grenade_trajectory.visible = false
	body.add_child(
		grenade_trajectory
	)

	var weapon_layer:= Node2D.new()
	weapon_layer.name = "StickFighterWeaponLayer"
	weapon_layer.scale = Vector2(
		1.22,
		1.22
	)
	body.add_child(
		weapon_layer
	)

	var held_weapon: Dictionary = _dict(
		fighter.get(
			"equipped_weapon",
			{}
		)
	)

	if not held_weapon.is_empty():
		var weapon_halo:= Polygon2D.new()
		weapon_halo.polygon = _stick_fighter_circle_polygon(
			Vector2(
				18.0 * facing,
				-22.0
			),
			12.0,
			16
		)
		weapon_halo.color = Color(
			color.r,
			color.g,
			color.b,
			0.15
		)
		weapon_layer.add_child(
			weapon_halo
		)

	_add_stick_fighter_weapon_visual(
		weapon_layer,
		fighter,
		facing,
		color
	)

	var name_label:= Label.new()
	name_label.text = str(
		fighter.get(
			"display_name",
			"Fighter"
		)
	)
	var equipped: Dictionary = _dict(
		fighter.get(
			"equipped_weapon",
			{}
		)
	)

	if not equipped.is_empty():
		var ammo: int = int(
			equipped.get(
				"ammo",
				-1
			)
		)
		name_label.text += (
			" • %s%s"
			% [
				str(
					equipped.get(
						"title",
						"WEAPON"
					)
				).to_upper(),
				(
					" [%d]" % ammo
					if ammo >= 0
					else ""
				)
			]
		)

	name_label.position = Vector2(
		-82.0,
		-78.0
	)
	name_label.size = Vector2(
		164.0,
		20.0
	)
	name_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	name_label.add_theme_font_size_override(
		"font_size",
		11
	)
	name_label.add_theme_color_override(
		"font_color",
		Color(
			0.98,
			0.98,
			1.0,
			0.96
		)
	)
	body.add_child(
		name_label
	)
func _stick_fighter_circle_polygon(
	center: Vector2,
	radius: float,
	point_count: int = 14
) -> PackedVector2Array:
	var points:= PackedVector2Array()

	for point_index in range(
		maxi(
			6,
			point_count
		)
	):
		var angle: float = (
			TAU
			* float(
				point_index
			)
			/ float(
				maxi(
					6,
					point_count
				)
			)
		)

		points.append(
			center
			+ Vector2(
				cos(
					angle
				),
				sin(
					angle
				)
			) * radius
		)

	return points


func _stick_fighter_add_joint(
	parent: Node,
	position_value: Vector2,
	color: Color,
	radius: float = 2.4
) -> Polygon2D:
	var joint:= Polygon2D.new()

	joint.polygon = _stick_fighter_circle_polygon(
		position_value,
		radius,
		10
	)
	joint.color = color

	parent.add_child(
		joint
	)

	return joint
func _render_stick_fighter_damage_feedback(
	arena: Control,
	projection: Dictionary
) -> void:
	if (
		arena == null
		or not is_instance_valid(
			arena
		)
	):
		return

	_render_stick_fighter_blast_feedback(
		arena,
		projection
	)

	var damage_feedback: Dictionary = _dict(
		projection.get(
			"damage_feedback",
			{}
		)
	)

	if not bool(
		damage_feedback.get(
			"local_player_damaged",
			false
		)
	):
		return

	var revision: int = int(
		damage_feedback.get(
			"revision",
			projection.get(
				"local_damage_flash_revision",
				0
			)
		)
	)

	if (
		revision <= 0
		or revision <= (
			stick_fighter_damage_feedback_revision
		)
	):
		return

	stick_fighter_damage_feedback_revision = revision

	var border:= Panel.new()
	border.name = (
		"StickFighterDamageBorder%d"
		% revision
	)
	border.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	border.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	border.offset_left = 7.0
	border.offset_top = 7.0
	border.offset_right = -7.0
	border.offset_bottom = -7.0

	var border_style:= StyleBoxFlat.new()
	border_style.bg_color = Color(
		0.0,
		0.0,
		0.0,
		0.0
	)
	border_style.border_color = Color(
		1.0,
		0.08,
		0.08,
		0.58
	)
	border_style.border_width_left = 6
	border_style.border_width_top = 6
	border_style.border_width_right = 6
	border_style.border_width_bottom = 6
	border_style.corner_radius_top_left = 12
	border_style.corner_radius_top_right = 12
	border_style.corner_radius_bottom_left = 12
	border_style.corner_radius_bottom_right = 12

	border.add_theme_stylebox_override(
		"panel",
		border_style
	)

	arena.add_child(
		border
	)
	border.move_to_front()

	var tween:= create_tween()
	tween.bind_node(
		border
	)
	tween.tween_property(
		border,
		"modulate:a",
		0.0,
		0.3
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_OUT
	)
	tween.tween_callback(
		Callable(
			border,
			"queue_free"
		)
	)

	set_meta(
		"stick_fighter_damage_feedback_revision",
		revision
	)
	set_meta(
		"stick_fighter_damage_feedback_amount",
		int(
			damage_feedback.get(
				"amount",
				0
			)
		)
	)
	set_meta(
		"stick_fighter_damage_feedback_renderer_only",
		true
	)
func _render_stick_fighter_blast_feedback(
	arena: Control,
	projection: Dictionary
) -> void:
	if (
		arena == null
		or not is_instance_valid(
			arena
		)
	):
		return

	var feedback_events: Array = _array(
		projection.get(
			"blast_feedback_events",
			[]
		)
	)

	if feedback_events.is_empty():
		return

	var consumed_revision: int = int(
		get_meta(
			"stick_fighter_blast_feedback_revision",
			0
		)
	)

	var highest_revision: int = (
		consumed_revision
	)

	var stage_contract: Dictionary = _dict(
		projection.get(
			"stage_contract",
			{}
		)
	)

	var stage_width: float = maxf(
		1.0,
		float(
			stage_contract.get(
				"width",
				100.0
			)
		)
	)

	var stage_height: float = maxf(
		1.0,
		float(
			stage_contract.get(
				"height",
				56.0
			)
		)
	)

	for raw_feedback in feedback_events:
		var feedback: Dictionary = _dict(
			raw_feedback
		)

		var revision: int = int(
			feedback.get(
				"revision",
				0
			)
		)

		if revision <= consumed_revision:
			continue

		highest_revision = maxi(
			highest_revision,
			revision
		)

		var stage_x: float = clampf(
			float(
				feedback.get(
					"stage_x",
					stage_width * 0.5
				)
			),
			0.0,
			stage_width
		)

		var stage_y: float = clampf(
			float(
				feedback.get(
					"stage_y",
					stage_height * 0.5
				)
			),
			0.0,
			stage_height
		)

		var edge: String = str(
			feedback.get(
				"edge",
				"right"
			)
		).strip_edges().to_lower()

		var inward: Vector2 = Vector2.LEFT

		match edge:
			"left":
				inward = Vector2.RIGHT

			"right":
				inward = Vector2.LEFT

			"top":
				inward = Vector2.DOWN

			"bottom":
				inward = Vector2.UP

		var perpendicular:= Vector2(
			- inward.y,
			inward.x
		)

		var blast_root:= Control.new()
		blast_root.name = (
			"StickFighterBlast%d"
			% revision
		)
		blast_root.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)
		blast_root.anchor_left = (
			stage_x / stage_width
		)
		blast_root.anchor_right = (
			stage_x / stage_width
		)
		blast_root.anchor_top = (
			stage_y / stage_height
		)
		blast_root.anchor_bottom = (
			stage_y / stage_height
		)
		blast_root.offset_left = 0.0
		blast_root.offset_right = 0.0
		blast_root.offset_top = 0.0
		blast_root.offset_bottom = 0.0
		blast_root.scale = Vector2(
			0.35,
			0.35
		)

		arena.add_child(
			blast_root
		)
		blast_root.move_to_front()

		var fighter_color: Color = (
			_stick_fighter_color(
				int(
					feedback.get(
						"fighter_index",
						0
					)
				)
			)
		)

		var core_color:= Color(
			1.0,
			1.0,
			1.0,
			0.98
		)

		_stick_fighter_add_line(
			blast_root,
			PackedVector2Array([
				inward * 132.0,
				Vector2.ZERO,
				- inward * 34.0
			]),
			fighter_color,
			12.0
		)

		_stick_fighter_add_line(
			blast_root,
			PackedVector2Array([
				inward * 112.0,
				Vector2.ZERO,
				- inward * 22.0
			]),
			core_color,
			5.0
		)

		for spread in [
			-1.0,
			1.0
		]:
			_stick_fighter_add_line(
				blast_root,
				PackedVector2Array([
					inward * 44.0,
					perpendicular * 34.0 * spread
				]),
				fighter_color,
				5.0
			)

			_stick_fighter_add_line(
				blast_root,
				PackedVector2Array([
					inward * 24.0,
					perpendicular * 19.0 * spread
				]),
				core_color,
				3.0
			)

		var tween:= create_tween()
		tween.bind_node(
			blast_root
		)
		tween.tween_property(
			blast_root,
			"scale",
			Vector2(
				1.18,
				1.18
			),
			0.12
		).set_trans(
			Tween.TRANS_EXPO
		).set_ease(
			Tween.EASE_OUT
		)
		tween.tween_property(
			blast_root,
			"modulate:a",
			0.0,
			0.34
		).set_trans(
			Tween.TRANS_QUAD
		).set_ease(
			Tween.EASE_OUT
		)
		tween.tween_callback(
			Callable(
				blast_root,
				"queue_free"
			)
		)

	if highest_revision > consumed_revision:
		set_meta(
			"stick_fighter_blast_feedback_revision",
			highest_revision
		)
		set_meta(
			"stick_fighter_blast_feedback_renderer_only",
			true
		)

func _render_multiplayer() -> void:
	_add_section_heading(
		"MULTIPLAYER",
		"Relationships become AI-controlled opponents. ErAccounts remain persistent online identities."
	)

	var provider_id: String = _default_provider_id()
	var host_contract: Dictionary = _dict(
		active_contract.get(
			"host_contract",
			{}
		)
	)
	var relationship_rows: Array = _array(
		active_contract.get(
			"relationship_invite_rows",
			[]
		)
	)

	if relationship_rows.is_empty():
		_add_empty_state(
			"No inviteable family or relationship identities are currently observable."
		)
	else:
		var grid:= GridContainer.new()
		grid.columns = 2
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
		content_root.add_child(
			grid
		)

		for raw_row in relationship_rows:
			var row: Dictionary = _dict(
				raw_row
			)
			var card:= _card()
			grid.add_child(
				card
			)

			var box:= VBoxContainer.new()
			box.add_theme_constant_override(
				"separation",
				6
			)
			card.add_child(
				box
			)

			_add_card_title(
				box,
				str(
					row.get(
						"display_name",
						"Relationship"
					)
				),
				"AGE %d • NPC CAN WIN"
				% int(
					row.get(
						"age",
						0
					)
				)
			)

			var invite:= Button.new()
			invite.text = "INVITE TO PLAY"
			invite.focus_mode = (
				Control.FOCUS_NONE
			)
			_apply_button_style(
				invite
			)
			invite.pressed.connect(
				_emit_intent.bind(
					_dict(
						row.get(
							"invite_action",
							{}
						)
					)
				)
			)
			box.add_child(
				invite
			)
			_register_animated_button(
				invite
			)

	var online_card:= _card()
	content_root.add_child(
		online_card
	)

	var online_box:= VBoxContainer.new()
	online_box.add_theme_constant_override(
		"separation",
		8
	)
	online_card.add_child(
		online_box
	)

	_add_card_title(
		online_box,
		"INVITE AN ERACCOUNT",
		"THEY MUST ACCEPT"
	)

	online_username_input = LineEdit.new()
	online_username_input.placeholder_text = (
		"ErAccount username"
	)
	online_username_input.custom_minimum_size = Vector2(
		0.0,
		40.0
	)
	online_box.add_child(
		online_username_input
	)

	var online_invite:= Button.new()
	online_invite.text = (
		"SEND ONLINE INVITATION"
	)
	online_invite.focus_mode = (
		Control.FOCUS_NONE
	)
	_apply_button_style(
		online_invite
	)
	online_invite.pressed.connect(
		_on_online_invite_pressed.bind(
			provider_id,
			host_contract
		)
	)
	online_box.add_child(
		online_invite
	)
	_register_animated_button(
		online_invite
	)

	var multiplayer_contract: Dictionary = _dict(
		active_contract.get(
			"multiplayer_contract",
			{}
		)
	)
	var invitations: Array = _array(
		multiplayer_contract.get(
			"invitations",
			[]
		)
	)

	if not invitations.is_empty():
		_add_section_heading(
			"INVITATIONS",
			"Pending and completed multiplayer contracts."
		)

	for raw_invitation in invitations:
		var invitation: Dictionary = _dict(
			raw_invitation
		)
		var sender: Dictionary = _dict(
			invitation.get(
				"sender",
				{}
			)
		)
		var recipient: Dictionary = _dict(
			invitation.get(
				"recipient",
				{}
			)
		)
		var card:= _card()
		content_root.add_child(
			card
		)

		var box:= VBoxContainer.new()
		box.add_theme_constant_override(
			"separation",
			6
		)
		card.add_child(
			box
		)

		_add_card_title(
			box,
			(
				"%s → %s"
				% [
					str(
						sender.get(
							"display_name",
							"Player"
						)
					),
					str(
						recipient.get(
							"display_name",
							"Player"
						)
					)
				]
			),
			str(
				invitation.get(
					"status",
					"pending"
				)
			).to_upper()
		)

		if str(
			invitation.get(
				"status",
				""
			)
		) == "pending":
			var action_row:= HBoxContainer.new()
			action_row.add_theme_constant_override(
				"separation",
				8
			)
			box.add_child(
				action_row
			)

			for action_id in [
				"accept_invitation",
				"decline_invitation"
			]:
				var action_button:= Button.new()
				action_button.text = (
					action_id
					.replace(
						"_invitation",
						""
					)
					.to_upper()
				)
				action_button.focus_mode = (
					Control.FOCUS_NONE
				)
				_apply_button_style(
					action_button
				)
				action_button.pressed.connect(
					_emit_intent.bind(
						{
							"action_id": action_id,
							"invitation_id": str(
								invitation.get(
									"invitation_id",
									""
								)
							),
							"provider_id": str(
								invitation.get(
									"provider_id",
									provider_id
								)
							),
							"host_contract": _dict(
								invitation.get(
									"host_contract",
									host_contract
								)
							).duplicate(true),
							"ui_is_renderer_only": true
						}
					)
				)
				action_row.add_child(
					action_button
				)
				_register_animated_button(
					action_button
				)

func _render_tournaments() -> void:
	_add_section_heading(
		"TOURNAMENTS",
		"Create brackets, join persistent events, and feed seasonal ladders."
	)

	var multiplayer_contract: Dictionary = _dict(
		active_contract.get(
			"multiplayer_contract",
			{}
		)
	)
	var tournaments: Array = _array(
		multiplayer_contract.get(
			"tournaments",
			[]
		)
	)

	var create:= Button.new()
	create.text = (
		"CREATE STICK FIGHTER TOURNAMENT"
	)
	create.focus_mode = (
		Control.FOCUS_NONE
	)
	create.custom_minimum_size = Vector2(
		0.0,
		44.0
	)
	_apply_button_style(
		create
	)
	create.pressed.connect(
		_emit_intent.bind(
			{
				"action_id": "create_tournament",
				"provider_id": (
					_default_provider_id()
				),
				"host_contract": _dict(
					active_contract.get(
						"host_contract",
						{}
					)
				).duplicate(true),
				"ui_is_renderer_only": true
			}
		)
	)
	content_root.add_child(
		create
	)
	_register_animated_button(
		create
	)

	if tournaments.is_empty():
		_add_empty_state(
			"No tournament contracts exist yet."
		)
		return

	for raw_row in tournaments:
		var row: Dictionary = _dict(
			raw_row
		)
		var card:= _card()
		content_root.add_child(
			card
		)

		var box:= VBoxContainer.new()
		box.add_theme_constant_override(
			"separation",
			6
		)
		card.add_child(
			box
		)

		_add_card_title(
			box,
			str(
				row.get(
					"title",
					"Tournament"
				)
			),
			(
				"%d PLAYERS • %s"
				% [
					_array(
						row.get(
							"participants",
							[]
						)
					).size(),
					str(
						row.get(
							"status",
							"open"
						)
					).to_upper()
				]
			)
		)

		var join:= Button.new()
		join.text = "JOIN TOURNAMENT"
		join.focus_mode = (
			Control.FOCUS_NONE
		)
		_apply_button_style(
			join
		)
		join.pressed.connect(
			_emit_intent.bind(
				{
					"action_id": "join_tournament",
					"tournament_id": str(
						row.get(
							"tournament_id",
							""
						)
					),
					"ui_is_renderer_only": true
				}
			)
		)
		box.add_child(
			join
		)
		_register_animated_button(
			join
		)


func _render_leaderboards() -> void:
	_add_section_heading("LEADERBOARDS", "Persistent all-time records and seasonal ladders.")
	var scoreboard: Dictionary = _dict(active_contract.get("scoreboard_contract", {}))
	var rows: Array = _array(scoreboard.get("seasonal_rows", []))

	if rows.is_empty():
		rows = _array(scoreboard.get("all_time_rows", []))

	if rows.is_empty():
		_add_empty_state("No completed matches have entered the scoreboard yet.")
		return

	var rank: int = 1

	for raw_row in rows:
		var row: Dictionary = _dict(raw_row)
		var card:= _card()
		content_root.add_child(card)
		var box:= HBoxContainer.new()
		box.add_theme_constant_override("separation", 12)
		card.add_child(box)
		var rank_label:= Label.new()
		rank_label.text = "#%d" % rank
		rank_label.custom_minimum_size = Vector2(54.0, 0.0)
		rank_label.add_theme_font_size_override("font_size", 20)
		rank_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.32, 1.0))
		box.add_child(rank_label)
		var name_label:= Label.new()
		name_label.text = str(row.get("display_name", "Player"))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		box.add_child(name_label)
		var stats:= Label.new()
		stats.text = (
			"%d W • %d L • %d RATING"
			% [int(row.get("wins", 0)), int(row.get("losses", 0)), int(row.get("rating", 1000))]
		)
		stats.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		stats.add_theme_color_override("font_color", Color(0.72, 0.79, 0.9, 1.0))
		box.add_child(stats)
		rank += 1


func _render_achievements() -> void:
	_add_section_heading(
		"ACHIEVEMENTS", "Unlocks are attached to persistent participant identities."
	)
	var achievements: Dictionary = _dict(active_contract.get("achievement_contract", {}))
	var rows: Array = _array(achievements.get("rows", []))

	if rows.is_empty():
		_add_empty_state("No achievements have been unlocked yet.")
		return

	for raw_row in rows:
		var row: Dictionary = _dict(raw_row)
		var card:= _card()
		content_root.add_child(card)
		var box:= VBoxContainer.new()
		box.add_theme_constant_override("separation", 5)
		card.add_child(box)
		_add_card_title(
			box,
			"★ %s" % str(row.get("title", "Achievement")),
			str(row.get("provider_id", "MINIGAME")).to_upper()
		)
		_add_body(box, str(row.get("description", "")))


func _render_replays() -> void:
	_add_section_heading(
		"REPLAYS",
		(
			"Every committed action can be reconstructed from its "
			+ "event contract."
		)
	)

	var replays: Dictionary = _dict(
		active_contract.get(
			"replay_contract",
			{}
		)
	)
	var rows: Array = _array(
		replays.get(
			"rows",
			[]
		)
	)

	if rows.is_empty():
		_add_empty_state(
			"No completed replay contracts exist yet."
		)
		return

	for raw_row in rows:
		var row: Dictionary = _dict(
			raw_row
		)
		var card:= _card()
		content_root.add_child(
			card
		)

		var box:= VBoxContainer.new()
		box.add_theme_constant_override(
			"separation",
			5
		)
		card.add_child(
			box
		)

		var event_count: int = int(
			row.get(
				"event_count",
				_array(
					row.get(
						"events",
						[]
					)
				).size()
			)
		)

		_add_card_title(
			box,
			str(
				row.get(
					"game_title",
					row.get(
						"provider_id",
						"Replay"
					).capitalize()
				)
			),
			(
				"%d EVENTS • %s"
				% [
					event_count,
					str(
						row.get(
							"status",
							"recording"
						)
					).to_upper()
				]
			)
		)

		_add_body(
			box,
			"Replay %s"
			% str(
				row.get(
					"replay_id",
					""
				)
			)
		)

func _on_section_pressed(
	section_id: String
) -> void:
	var clean_section: String = _section(
		section_id
	)



	reveal_pending_observation(
		clean_section,
		(
			"%s is resident. Current truth is publishing."
			% clean_section.replace(
				"_",
				" "
			).to_upper()
		),
		true
	)

	_emit_intent(
		{
			"action_id": "emit_hub",
			"active_section": clean_section,
			"host_contract": _dict(
				active_contract.get(
					"host_contract",
					{}
				)
			),
			"ui_is_renderer_only": true
		}
	)


func _on_online_invite_pressed(provider_id: String, host_contract: Dictionary) -> void:
	if online_username_input == null:
		return

	var username: String = online_username_input.text.strip_edges()

	if username == "":
		status_label.text = "Enter an ErAccount username first."
		return

	_emit_intent(
		{
			"action_id": "invite_eraccount",
			"recipient_username": username,
			"provider_id": provider_id,
			"game_title": _provider_title(provider_id),
			"host_contract": host_contract.duplicate(true),
			"ui_is_renderer_only": true
		}
	)
func _input(
	event: InputEvent
) -> void:
	if not (
		event is InputEventKey
	):
		return

	var key_event: InputEventKey = (
		event as InputEventKey
	)

	if (
		not visible
		or active_section != "session"
	):
		return

	var viewport:= get_viewport()

	if viewport != null:
		var focus_owner: Control = (
			viewport.gui_get_focus_owner()
		)

		if (
			focus_owner is LineEdit
			or focus_owner is TextEdit
		):
			return

	var session: Dictionary = _dict(
		active_contract.get(
			"session_contract",
			{}
		)
	)

	if session.is_empty():
		return

	if str(
		session.get(
			"provider_id",
			""
		)
	).strip_edges().to_lower() != "stick_fighter":
		return

	var game_action_id: String = (
		_stick_fighter_keyboard_action_id(
			key_event
		)
	)

	if game_action_id == "":
		return

	if not _stick_fighter_session_action_enabled(
		session,
		game_action_id
	):
		return

	if game_action_id == "drop_down":
		if key_event.echo:
			return

		if viewport != null:
			viewport.set_input_as_handled()

		_emit_stick_fighter_keyboard_action_intent(
			session,
			game_action_id,
			key_event.pressed,
			"held"
		)

		if key_event.pressed:
			_emit_stick_fighter_keyboard_action_intent(
				session,
				game_action_id,
				true,
				"edge"
			)

		return

	var held_input: bool = game_action_id in [
		"move_left",
		"move_right",
		"block"
	]
	var release_edge_required: bool = (
		game_action_id == "punch"
	)

	if (
		not held_input
		and not release_edge_required
		and (
			not key_event.pressed
			or key_event.echo
		)
	):
		return

	if (
		(held_input or release_edge_required)
		and key_event.echo
	):
		return

	if viewport != null:
		viewport.set_input_as_handled()

	_emit_stick_fighter_keyboard_action_intent(
		session,
		game_action_id,
		key_event.pressed
	)


func _stick_fighter_keyboard_action_id(
	event: InputEventKey
) -> String:
	var key_codes: Array = [
		int(
			event.keycode
		),
		int(
			event.physical_keycode
		)
	]

	if (
		int(KEY_LEFT) in key_codes
		or int(KEY_A) in key_codes
	):
		return "move_left"

	if (
		int(KEY_RIGHT) in key_codes
		or int(KEY_D) in key_codes
	):
		return "move_right"

	if (
		int(KEY_UP) in key_codes
		or int(KEY_W) in key_codes
	):
		return "jump"

	if (
		int(KEY_DOWN) in key_codes
		or int(KEY_S) in key_codes
	):
		return "drop_down"

	if (
		int(KEY_Z) in key_codes
		or int(KEY_J) in key_codes
	):
		return "punch"

	if (
		int(KEY_X) in key_codes
		or int(KEY_K) in key_codes
	):
		return "kick"

	if (
		int(KEY_C) in key_codes
		or int(KEY_L) in key_codes
	):
		return "block"

	if (
		int(KEY_V) in key_codes
		or int(KEY_SPACE) in key_codes
	):
		return "special"

	if int(
		KEY_TAB
	) in key_codes:
		return "pickup"

	return ""


func _stick_fighter_session_action_enabled(
	session: Dictionary,
	game_action_id: String
) -> bool:
	if session.is_empty():
		return false

	if str(
		session.get(
			"status",
			"active"
		)
	).strip_edges().to_lower() == "completed":
		return false

	var clean_action_id: String = str(
		game_action_id
	).strip_edges().to_lower()

	return clean_action_id in [
		"move_left",
		"move_right",
		"jump",
		"drop_down",
		"punch",
		"kick",
		"block",
		"special",
		"pickup"
	]

func _emit_stick_fighter_keyboard_action_intent(
	session: Dictionary,
	game_action_id: String,
	pressed: bool,
	input_kind_override: String = ""
) -> void:
	if session.is_empty():
		return

	var clean_action_id: String = str(
		game_action_id
	).strip_edges().to_lower()

	if clean_action_id == "":
		return

	if not _stick_fighter_session_action_enabled(
		session,
		clean_action_id
	):
		return

	var clean_override: String = str(
		input_kind_override
	).strip_edges().to_lower()
	var input_kind: String = clean_override

	if input_kind == "":
		input_kind = (
			"held"
			if clean_action_id in [
				"move_left",
				"move_right",
				"block"
			]
			else "edge"
		)

	if input_kind not in [
		"held",
		"edge"
	]:
		return

	if (
		input_kind == "edge"
		and not pressed
		and clean_action_id != "punch"
	):
		return

	stick_fighter_input_sequence += 1

	_emit_intent(
		{
			"action_id": "continuous_input",
			"input_action_id": clean_action_id,
			"pressed": pressed,
			"input_kind": input_kind,
			"input_sequence": stick_fighter_input_sequence,
			"session_id": str(
				session.get(
					"session_id",
					""
				)
			),
			"provider_id": str(
				session.get(
					"provider_id",
					""
				)
			),
			"active_section": "session",
			"input_surface": "keyboard",
			"ui_is_renderer_only": true
		}
	)
func _apply_stick_fighter_aaa_rig_pose(
	body: Node2D,
	shoulder: Vector2,
	hip: Vector2,
	left_elbow: Vector2,
	right_elbow: Vector2,
	left_hand: Vector2,
	right_hand: Vector2,
	left_knee: Vector2,
	right_knee: Vector2,
	left_foot: Vector2,
	right_foot: Vector2
) -> void:
	_set_stick_fighter_rig_line(
		body,
		"RigLeftArmOutline",
		PackedVector2Array([
			shoulder,
			left_elbow,
			left_hand
		])
	)
	_set_stick_fighter_rig_line(
		body,
		"RigLeftArmFill",
		PackedVector2Array([
			shoulder,
			left_elbow,
			left_hand
		])
	)
	_set_stick_fighter_rig_line(
		body,
		"RigRightArmOutline",
		PackedVector2Array([
			shoulder,
			right_elbow,
			right_hand
		])
	)
	_set_stick_fighter_rig_line(
		body,
		"RigRightArmFill",
		PackedVector2Array([
			shoulder,
			right_elbow,
			right_hand
		])
	)
	_set_stick_fighter_rig_line(
		body,
		"RigLeftLegOutline",
		PackedVector2Array([
			hip,
			left_knee,
			left_foot
		])
	)
	_set_stick_fighter_rig_line(
		body,
		"RigLeftLegFill",
		PackedVector2Array([
			hip,
			left_knee,
			left_foot
		])
	)
	_set_stick_fighter_rig_line(
		body,
		"RigRightLegOutline",
		PackedVector2Array([
			hip,
			right_knee,
			right_foot
		])
	)
	_set_stick_fighter_rig_line(
		body,
		"RigRightLegFill",
		PackedVector2Array([
			hip,
			right_knee,
			right_foot
		])
	)

	var joint_rows: Array = [
		{
			"name": "Shoulder",
			"position": shoulder
		},
		{
			"name": "Hip",
			"position": hip
		},
		{
			"name": "LeftElbow",
			"position": left_elbow
		},
		{
			"name": "RightElbow",
			"position": right_elbow
		},
		{
			"name": "LeftKnee",
			"position": left_knee
		},
		{
			"name": "RightKnee",
			"position": right_knee
		},
		{
			"name": "LeftHand",
			"position": left_hand
		},
		{
			"name": "RightHand",
			"position": right_hand
		},
		{
			"name": "LeftFoot",
			"position": left_foot
		},
		{
			"name": "RightFoot",
			"position": right_foot
		}
	]

	for raw_joint in joint_rows:
		var joint: Dictionary = (
			raw_joint as Dictionary
		)
		var joint_name: String = str(
			joint.get(
				"name",
				""
			)
		)
		var joint_position: Vector2 = joint.get(
			"position",
			Vector2.ZERO
		)

		_set_stick_fighter_rig_joint(
			body,
			"Rig%sOutline" % joint_name,
			joint_position,
			3.0
		)
		_set_stick_fighter_rig_joint(
			body,
			"Rig%sFill" % joint_name,
			joint_position,
			1.8
		)

func _apply_stick_fighter_aaa_limb_animation(
	body: Node2D,
	fighter: Dictionary,
	draw_facing: int
) -> void:
	var pose_facing: float = (
		-1.0
		if draw_facing < 0
		else 1.0
	)
	var animation_contract: Dictionary = _dict(
		fighter.get(
			"animation_contract",
			{}
		)
	)
	var animation_id: String = str(
		animation_contract.get(
			"animation_id",
			fighter.get(
				"state",
				"idle"
			)
		)
	).strip_edges().to_lower()
	var progress: float = clampf(
		float(
			animation_contract.get(
				"progress",
				0.0
			)
		),
		0.0,
		1.0
	)
	var movement_axis: float = float(
		animation_contract.get(
			"movement_axis",
			fighter.get(
				"movement_axis",
				0.0
			)
		)
	)
	var simulation_step: int = int(
		fighter.get(
			"simulation_step",
			0
		)
	)

	var shoulder:= Vector2(
		0.0,
		-34.0
	)
	var hip:= Vector2(
		0.0,
		-14.0
	)

	var left_elbow:= Vector2(
		-9.0,
		-25.0
	)
	var right_elbow:= Vector2(
		9.0,
		-25.0
	)
	var left_hand:= Vector2(
		-17.0,
		-19.0
	)
	var right_hand:= Vector2(
		17.0,
		-19.0
	)

	var left_knee:= Vector2(
		-6.0,
		-7.0
	)
	var right_knee:= Vector2(
		6.0,
		-7.0
	)
	var left_foot:= Vector2(
		-11.0,
		0.0
	)
	var right_foot:= Vector2(
		11.0,
		0.0
	)

	var override_pose: bool = false



	if (
		absf(
			movement_axis
		) > 0.001
		and not bool(
			fighter.get(
				"airborne",
				false
			)
		)
	):
		override_pose = true

		var gait: float = sin(
			float(
				simulation_step
			) * 0.46
		)
		var stride_direction: float = (
			-1.0
			if movement_axis < 0.0
			else 1.0
		)
		var stride: float = (
			gait
			* 7.0
			* stride_direction
		)
		var lift_left: float = (
			maxf(
				0.0,
				gait
			) * 2.3
		)
		var lift_right: float = (
			maxf(
				0.0,
				- gait
			) * 2.3
		)

		left_knee = Vector2(
			-6.0 + stride * 0.35,
			-7.0 - lift_left
		)
		right_knee = Vector2(
			6.0 - stride * 0.35,
			-7.0 - lift_right
		)
		left_foot = Vector2(
			-10.5 + stride,
			- lift_left
		)
		right_foot = Vector2(
			10.5 - stride,
			- lift_right
		)

		left_elbow = Vector2(
			-9.0 - stride * 0.22,
			-25.0
		)
		right_elbow = Vector2(
			9.0 + stride * 0.22,
			-25.0
		)
		left_hand = Vector2(
			-17.0 - stride * 0.48,
			-19.0
		)
		right_hand = Vector2(
			17.0 + stride * 0.48,
			-19.0
		)

	match animation_id:
		"punch":
			override_pose = true

			var windup: float = clampf(
				progress / 0.28,
				0.0,
				1.0
			)
			var strike: float = clampf(
				(progress - 0.28) / 0.32,
				0.0,
				1.0
			)
			var recover: float = clampf(
				(progress - 0.6) / 0.4,
				0.0,
				1.0
			)
			var extension: float = (
				lerpf(
					-6.0,
					15.0,
					strike
				)
				if progress < 0.6
				else lerpf(
					15.0,
					0.0,
					recover
				)
			)
			var rear_guard: float = lerpf(
				0.0,
				6.0,
				windup
			)

			if pose_facing > 0.0:
				right_elbow = Vector2(
					10.0 + extension * 0.45,
					-29.0
				)
				right_hand = Vector2(
					16.0 + extension,
					-28.0
				)
				left_elbow = Vector2(
					-7.0,
					-28.0
				)
				left_hand = Vector2(
					-5.0,
					-31.0 - rear_guard * 0.3
				)
			else:
				left_elbow = Vector2(
					-10.0 - extension * 0.45,
					-29.0
				)
				left_hand = Vector2(
					-16.0 - extension,
					-28.0
				)
				right_elbow = Vector2(
					7.0,
					-28.0
				)
				right_hand = Vector2(
					5.0,
					-31.0 - rear_guard * 0.3
				)

		"air_punch":
			override_pose = true

			var strike_wave: float = sin(
				progress * PI
			)

			left_knee = Vector2(
				-8.0,
				-10.0
			)
			right_knee = Vector2(
				8.0,
				-10.0
			)
			left_foot = Vector2(
				-14.0,
				-4.0
			)
			right_foot = Vector2(
				14.0,
				-4.0
			)

			if pose_facing > 0.0:
				right_elbow = Vector2(
					13.0 + strike_wave * 5.0,
					-29.0
				)
				right_hand = Vector2(
					20.0 + strike_wave * 17.0,
					-28.0
				)
				left_hand = Vector2(
					-5.0,
					-33.0
				)
			else:
				left_elbow = Vector2(
					-13.0 - strike_wave * 5.0,
					-29.0
				)
				left_hand = Vector2(
					-20.0 - strike_wave * 17.0,
					-28.0
				)
				right_hand = Vector2(
					5.0,
					-33.0
				)

		"kick":
			override_pose = true

			var chamber: float = clampf(
				progress / 0.32,
				0.0,
				1.0
			)
			var extension: float = clampf(
				(progress - 0.32) / 0.3,
				0.0,
				1.0
			)
			var recovery: float = clampf(
				(progress - 0.62) / 0.38,
				0.0,
				1.0
			)
			var kick_reach: float = (
				lerpf(
					0.0,
					22.0,
					extension
				)
				if progress < 0.62
				else lerpf(
					22.0,
					0.0,
					recovery
				)
			)

			if pose_facing > 0.0:
				right_knee = Vector2(
					7.0 + 7.0 * chamber,
					-10.0
				)
				right_foot = Vector2(
					12.0 + kick_reach,
					-7.0
				)
				left_foot = Vector2(
					-10.0,
					0.0
				)
			else:
				left_knee = Vector2(
					-7.0 - 7.0 * chamber,
					-10.0
				)
				left_foot = Vector2(
					-12.0 - kick_reach,
					-7.0
				)
				right_foot = Vector2(
					10.0,
					0.0
				)

		"sweep":
			override_pose = true

			var sweep_wave: float = sin(
				progress * PI
			)

			hip = Vector2(
				0.0,
				-10.0 - 2.0 * sweep_wave
			)
			shoulder = Vector2(
				-4.0 * pose_facing,
				-30.0
			)

			left_elbow = Vector2(
				-11.0,
				-21.0
			)
			right_elbow = Vector2(
				11.0,
				-21.0
			)
			left_hand = Vector2(
				-17.0,
				-14.0
			)
			right_hand = Vector2(
				17.0,
				-14.0
			)

			if pose_facing > 0.0:
				right_knee = Vector2(
					11.0,
					-5.0
				)
				right_foot = Vector2(
					15.0 + 23.0 * sweep_wave,
					-1.0
				)
				left_knee = Vector2(
					-6.0,
					-5.0
				)
				left_foot = Vector2(
					-11.0,
					0.0
				)
			else:
				left_knee = Vector2(
					-11.0,
					-5.0
				)
				left_foot = Vector2(
					-15.0 - 23.0 * sweep_wave,
					-1.0
				)
				right_knee = Vector2(
					6.0,
					-5.0
				)
				right_foot = Vector2(
					11.0,
					0.0
				)

		"swept_fall":
			override_pose = true

			var fall_wave: float = sin(
				progress * PI
			)

			left_elbow = Vector2(
				-16.0,
				-28.0 + 8.0 * fall_wave
			)
			right_elbow = Vector2(
				16.0,
				-28.0 + 8.0 * fall_wave
			)
			left_hand = Vector2(
				-26.0,
				-22.0 + 10.0 * fall_wave
			)
			right_hand = Vector2(
				26.0,
				-22.0 + 10.0 * fall_wave
			)

			left_knee = Vector2(
				-11.0,
				-8.0
			)
			right_knee = Vector2(
				11.0,
				-8.0
			)
			left_foot = Vector2(
				-21.0,
				-3.0 + 3.0 * fall_wave
			)
			right_foot = Vector2(
				21.0,
				-3.0 + 3.0 * fall_wave
			)

		"weapon_attack":
			override_pose = true

			var swing_wave: float = sin(
				progress * PI
			)

			if pose_facing > 0.0:
				right_elbow = Vector2(
					8.0 + swing_wave * 9.0,
					-31.0
				)
				right_hand = Vector2(
					15.0 + swing_wave * 12.0,
					-24.0
				)
				left_hand = Vector2(
					-4.0,
					-31.0
				)
			else:
				left_elbow = Vector2(
					-8.0 - swing_wave * 9.0,
					-31.0
				)
				left_hand = Vector2(
					-15.0 - swing_wave * 12.0,
					-24.0
				)
				right_hand = Vector2(
					4.0,
					-31.0
				)

		"fire":
			override_pose = true

			var recoil: float = (
				sin(
					progress * PI
				) * 4.0
			)

			if pose_facing > 0.0:
				right_elbow = Vector2(
					12.0 - recoil,
					-28.0
				)
				right_hand = Vector2(
					23.0 - recoil,
					-24.0
				)
				left_hand = Vector2(
					7.0,
					-27.0
				)
			else:
				left_elbow = Vector2(
					-12.0 + recoil,
					-28.0
				)
				left_hand = Vector2(
					-23.0 + recoil,
					-24.0
				)
				right_hand = Vector2(
					-7.0,
					-27.0
				)

	if not override_pose:
		return

	_apply_stick_fighter_aaa_rig_pose(
		body,
		shoulder,
		hip,
		left_elbow,
		right_elbow,
		left_hand,
		right_hand,
		left_knee,
		right_knee,
		left_foot,
		right_foot
	)

func _emit_intent(
	payload: Dictionary
) -> void:
	if payload.is_empty():
		return



	var clean: Dictionary = (
		payload.duplicate(false)
	)

	clean [
		"active_section"
	] = str(
		clean.get(
			"active_section",
			active_section
		)
	)
	clean [
		"source"
	] = str(
		clean.get(
			"source",
			"mini_game_panel"
		)
	)

	var action_id: String = str(
		clean.get(
			"action_id",
			""
		)
	).strip_edges().to_lower()




	if (
		action_id != "continuous_input"
		and not clean.has(
			"host_contract"
		)
	):
		var host_contract: Dictionary = _dict(
			active_contract.get(
				"host_contract",
				{}
			)
		)

		if not host_contract.is_empty():
			clean [
				"host_contract"
			] = host_contract

	clean [
		"immutable_contract_references"
	] = true
	clean [
		"ui_is_renderer_only"
	] = true

	intent_requested.emit(
		clean
	)

	set_meta(
		"minigame_intent_deep_copy_on_press",
		false
	)
	set_meta(
		"minigame_intent_engine_calls_on_press",
		false
	)



func _on_close_pressed() -> void:
	close_requested.emit()


func _default_provider_id() -> String:
	var session: Dictionary = _dict(active_contract.get("session_contract", {}))
	var provider_id: String = str(session.get("provider_id", "")).strip_edges().to_lower()

	if provider_id != "":
		return provider_id

	var rows: Array = _array(active_contract.get("provider_rows", []))

	if not rows.is_empty():
		return str(_dict(rows [0]).get("provider_id", "stick_fighter"))

	return "stick_fighter"


func _provider_title(provider_id: String) -> String:
	for raw_row in _array(active_contract.get("provider_rows", [])):
		var row: Dictionary = _dict(raw_row)

		if str(row.get("provider_id", "")) == provider_id:
			return str(row.get("title", provider_id.capitalize()))

	return provider_id.capitalize()


func _add_section_heading(title: String, subtitle: String) -> void:
	var box:= VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	content_root.add_child(box)
	var title_row:= Label.new()
	title_row.text = title
	title_row.add_theme_font_size_override("font_size", 18)
	title_row.add_theme_color_override("font_color", Color(0.95, 0.9, 0.79, 1.0))
	box.add_child(title_row)
	var subtitle_row:= Label.new()
	subtitle_row.text = subtitle
	subtitle_row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_row.add_theme_font_size_override("font_size", 11)
	subtitle_row.add_theme_color_override("font_color", Color(0.64, 0.7, 0.82, 1.0))
	box.add_child(subtitle_row)


func _add_card_title(parent: VBoxContainer, title: String, subtitle: String) -> void:
	var title_label_row:= Label.new()
	title_label_row.text = title
	title_label_row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label_row.add_theme_font_size_override("font_size", 16)
	title_label_row.add_theme_color_override("font_color", Color(0.97, 0.93, 0.84, 1.0))
	parent.add_child(title_label_row)
	var subtitle_label_row:= Label.new()
	subtitle_label_row.text = subtitle
	subtitle_label_row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label_row.add_theme_font_size_override("font_size", 10)
	subtitle_label_row.add_theme_color_override("font_color", Color(0.55, 0.75, 0.94, 1.0))
	parent.add_child(subtitle_label_row)


func _add_body(parent: VBoxContainer, text: String) -> void:
	var body:= Label.new()
	body.text = text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 11)
	body.add_theme_color_override("font_color", Color(0.76, 0.79, 0.86, 1.0))
	parent.add_child(body)


func _add_progress(parent: VBoxContainer, label_text: String, value: float, maximum: float) -> void:
	var label:= Label.new()
	label.text = "%s  %d" % [label_text, int(value)]
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.73, 0.79, 0.9, 1.0))
	parent.add_child(label)
	var bar:= ProgressBar.new()
	bar.max_value = maximum
	bar.value = clampf(value, 0.0, maximum)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0.0, 12.0)
	parent.add_child(bar)


func _add_empty_state(text: String) -> void:
	var card:= _card()
	content_root.add_child(card)
	var label:= Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.66, 0.72, 0.82, 1.0))
	card.add_child(label)


func _card() -> PanelContainer:
	var card:= PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0.0, 112.0)
	card.add_theme_stylebox_override("panel", _card_style())
	card.mouse_entered.connect(_on_card_hover.bind(card, true))
	card.mouse_exited.connect(_on_card_hover.bind(card, false))
	animated_cards.append(card)
	return card


func _on_card_hover(card: PanelContainer, hovered: bool) -> void:
	if card == null or not is_instance_valid(card):
		return

	card.set_meta("hovered", hovered)


func _register_animated_button(button: Button) -> void:
	animated_buttons.append(button)


func _update_animated_surfaces() -> void:
	var pulse: float = (sin(animation_time * 2.2) + 1.0) * 0.5

	for raw_card in animated_cards:
		var card:= raw_card as PanelContainer

		if card == null or not is_instance_valid(card):
			continue

		var hovered: bool = bool(card.get_meta("hovered", false))
		var target_scale: Vector2 = Vector2(1.012, 1.012) if hovered else Vector2.ONE
		card.scale = card.scale.lerp(target_scale, 0.18)
		card.modulate.a = (1.0 if hovered else 0.97 + pulse * 0.03)

	for raw_button in animated_buttons:
		var button:= raw_button as Button

		if button == null or not is_instance_valid(button):
			continue

		if button.disabled:
			button.modulate.a = 0.46
		else:
			button.modulate.a = 0.91 + pulse * 0.09


func _update_scroll_visibility(delta: float) -> void:
	if scroll_bar == null or not is_instance_valid(scroll_bar):
		return

	var current_value: float = float(content_scroll.scroll_vertical)

	if absf(current_value - scroll_last_value) > 0.5:
		scroll_last_value = current_value
		scroll_fade_hold = 0.75
		scroll_bar.modulate.a = 1.0
		return

	if scroll_fade_hold > 0.0:
		scroll_fade_hold = maxf(0.0, scroll_fade_hold - delta)
		return

	scroll_bar.modulate.a = lerpf(scroll_bar.modulate.a, 0.0, 0.14)


func _panel_style() -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.055, 0.082, 0.985)
	style.border_color = Color(0.35, 0.54, 0.78, 0.72)
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.58)
	style.shadow_size = 22
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 16.0
	style.content_margin_bottom = 16.0
	return style


func _card_style() -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.092, 0.135, 0.96)
	style.border_color = Color(0.26, 0.39, 0.58, 0.54)
	style.set_border_width_all(1)
	style.set_corner_radius_all(13)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	style.shadow_size = 8
	style.content_margin_left = 13.0
	style.content_margin_right = 13.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	return style


func _apply_button_style(button: Button) -> void:
	var normal:= StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.17, 0.27, 0.98)
	normal.border_color = Color(0.35, 0.58, 0.84, 0.58)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(9)

	var hover:= StyleBoxFlat.new()
	hover.bg_color = Color(0.18, 0.29, 0.43, 1.0)
	hover.border_color = Color(0.54, 0.81, 1.0, 0.94)
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(9)

	var pressed:= StyleBoxFlat.new()
	pressed.bg_color = Color(0.08, 0.12, 0.2, 1.0)
	pressed.border_color = Color(1.0, 0.69, 0.28, 0.92)
	pressed.set_border_width_all(1)
	pressed.set_corner_radius_all(9)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0, 1.0))
	button.add_theme_color_override("font_hover_color", Color.WHITE)


func _section(value: String) -> String:
	var clean: String = str(value).strip_edges().to_lower()

	if (
		clean
		in [
			"games",
			"session",
			"multiplayer",
			"tournaments",
			"leaderboards",
			"achievements",
			"replays",
			"mods"
		]
	):
		return clean

	return "games"


func _clear_children(parent: Node) -> void:
	if parent == null:
		return

	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _dict(value: Variant) -> Dictionary:
	return value if typeof(value) == TYPE_DICTIONARY else {}


func _array(value: Variant) -> Array:
	return value if typeof(value) == TYPE_ARRAY else []


func _string_array(value: Variant) -> PackedStringArray:
	var out:= PackedStringArray()

	for raw_value in _array(value):
		out.append(str(raw_value))

	return out