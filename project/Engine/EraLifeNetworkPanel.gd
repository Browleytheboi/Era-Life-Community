extends VBoxContainer
class_name EraLifeNetworkPanel

signal request_command(
	envelope: Dictionary
)
signal request_profile(
	username: String
)
signal request_close

const PANEL_SCHEMA:= "eralife.network.panel"
const PANEL_VERSION:= 1

var contract: Dictionary = {}
var active_section_id: String = "friends_live"
var section_host: VBoxContainer = null
var status_label: Label = null
var search_results: Array = []
var photo_dialog: FileDialog = null
var search_edit: LineEdit = null
var profile_display_name_edit: LineEdit = null
var profile_bio_edit: TextEdit = null
var profile_username_edit: LineEdit = null
var profile_note_edit: LineEdit = null
var feed_post_edit: TextEdit = null
var permission_controls: Dictionary = {}
var notifications_toggle: CheckButton = null


func _ready() -> void:
	size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	add_theme_constant_override(
		"separation",
		8
	)


func render_contract(
	next_contract: Dictionary
) -> void:
	contract = next_contract.duplicate(true)

	if not _section_exists(
		active_section_id
	):
		active_section_id = "friends_live"

	_build()


func set_active_section(
	section_id: String
) -> void:
	var clean_section_id: String = str(
		section_id
	).strip_edges().to_lower()

	if clean_section_id == "":
		return

	active_section_id = clean_section_id
	_build()


func apply_command_report(
	report: Dictionary
) -> void:
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
			render_contract(
				next_contract
			)
			return

	if str(
		report.get(
			"mode",
			""
		)
	) == "identity_discovery_results":
		search_results = _safe_array(
			report.get(
				"results",
				[]
			)
		)
		active_section_id = "search"
		_build()
		return

	if (
		status_label != null
		and is_instance_valid(
			status_label
		)
	):
		status_label.text = str(
			report.get(
				"message",
				report.get(
					"reason",
					"EraLife Network request handled."
				)
			)
		)


func _build() -> void:
	_clear_children(self)
	permission_controls.clear()
	photo_dialog = null
	section_host = null
	status_label = null
	search_edit = null
	profile_display_name_edit = null
	profile_bio_edit = null
	profile_username_edit = null
	profile_note_edit = null
	feed_post_edit = null
	notifications_toggle = null

	add_child(
		_build_identity_header()
	)

	var split:= HSplitContainer.new()
	split.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	split.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	split.split_offset = 260
	add_child(split)

	split.add_child(
		_build_navigation()
	)

	var content_panel:= PanelContainer.new()
	content_panel.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	content_panel.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	content_panel.add_theme_stylebox_override(
		"panel",
		_panel_style(
			Color(
				0.025,
				0.028,
				0.042,
				0.96
			),
			Color(
				0.36,
				0.48,
				0.78,
				0.34
			),
			18
		)
	)
	split.add_child(content_panel)

	var content_margin:= MarginContainer.new()
	content_margin.add_theme_constant_override(
		"margin_left",
		16
	)
	content_margin.add_theme_constant_override(
		"margin_right",
		16
	)
	content_margin.add_theme_constant_override(
		"margin_top",
		14
	)
	content_margin.add_theme_constant_override(
		"margin_bottom",
		14
	)
	content_panel.add_child(content_margin)

	var content_scroll:= ScrollContainer.new()
	content_scroll.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	content_scroll.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	content_scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)
	content_margin.add_child(content_scroll)

	section_host = VBoxContainer.new()
	section_host.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	section_host.add_theme_constant_override(
		"separation",
		10
	)
	content_scroll.add_child(section_host)

	_build_active_section()
	_build_bottom_actions()


func _build_identity_header() -> Control:
	var panel:= PanelContainer.new()
	panel.custom_minimum_size = Vector2(
		0,
		72
	)
	panel.add_theme_stylebox_override(
		"panel",
		_panel_style(
			Color(
				0.018,
				0.02,
				0.032,
				0.98
			),
			Color(
				0.72,
				0.82,
				1.0,
				0.34
			),
			16
		)
	)

	var margin:= MarginContainer.new()
	for margin_name in [
		"margin_left",
		"margin_right",
		"margin_top",
		"margin_bottom"
	]:
		margin.add_theme_constant_override(
			str(margin_name),
			14 if "left" in str(margin_name)
			or "right" in str(margin_name)
			else 10
		)
	panel.add_child(margin)

	var row:= HBoxContainer.new()
	row.add_theme_constant_override(
		"separation",
		12
	)
	margin.add_child(row)

	var profile: Dictionary = (
		_safe_dictionary(
			contract.get(
				"profile",
				{}
			)
		)
	)
	var identity_context: Dictionary = (
		_safe_dictionary(
			contract.get(
				"identity_context",
				{}
			)
		)
	)
	var is_guest: bool = bool(
		identity_context.get(
			"is_guest",
			true
		)
	)

	row.add_child(
		_profile_photo_view(
			_safe_dictionary(
				profile.get(
					"profile_photo",
					{}
				)
			),
			56
		)
	)

	var identity_box:= VBoxContainer.new()
	identity_box.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	identity_box.add_theme_constant_override(
		"separation",
		1
	)
	row.add_child(identity_box)

	var title:= Label.new()
	title.text = "ERA LIFE NETWORK"
	title.add_theme_font_size_override(
		"font_size",
		22
	)
	title.add_theme_color_override(
		"font_color",
		Color(
			0.94,
			0.97,
			1.0,
			1.0
		)
	)
	identity_box.add_child(title)

	var display_name: String = str(
		profile.get(
			"display_name",
			identity_context.get(
				"account_username",
				"Offline Player"
			)
		)
	)
	var username: String = str(
		identity_context.get(
			"account_username",
			""
		)
	)
	var subtitle:= Label.new()
	subtitle.text = (
		"Offline mode — full simulation remains available"
		if is_guest
		else (
			"%s  •  @%s  •  ID %s"
			% [
				display_name,
				username,
				str(
					contract.get(
						"eraccount_id",
						""
					)
				)
			]
		)
	)
	subtitle.add_theme_font_size_override(
		"font_size",
		12
	)
	subtitle.add_theme_color_override(
		"font_color",
		Color(
			0.76,
			0.82,
			0.94,
			0.78
		)
	)
	identity_box.add_child(subtitle)

	status_label = Label.new()
	status_label.text = str(
		contract.get(
			"message",
			"Connected to the EraLife community layer."
		)
	)
	status_label.custom_minimum_size = (
		Vector2(
			300,
			0
		)
	)
	status_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	status_label.add_theme_font_size_override(
		"font_size",
		11
	)
	status_label.add_theme_color_override(
		"font_color",
		Color(
			0.7,
			1.0,
			0.82,
			0.86
		)
	)
	row.add_child(status_label)

	var close_button:= Button.new()
	close_button.text = "✕"
	close_button.custom_minimum_size = (
		Vector2(
			42,
			42
		)
	)
	close_button.pressed.connect(
		func ():
			request_close.emit()
	)
	row.add_child(close_button)

	return panel


func _build_navigation() -> Control:
	var panel:= PanelContainer.new()
	panel.custom_minimum_size = (
		Vector2(
			250,
			0
		)
	)
	panel.add_theme_stylebox_override(
		"panel",
		_panel_style(
			Color(
				0.016,
				0.018,
				0.028,
				0.98
			),
			Color(
				0.3,
				0.36,
				0.56,
				0.3
			),
			16
		)
	)

	var margin:= MarginContainer.new()
	margin.add_theme_constant_override(
		"margin_left",
		10
	)
	margin.add_theme_constant_override(
		"margin_right",
		10
	)
	margin.add_theme_constant_override(
		"margin_top",
		12
	)
	margin.add_theme_constant_override(
		"margin_bottom",
		12
	)
	panel.add_child(margin)

	var box:= VBoxContainer.new()
	box.add_theme_constant_override(
		"separation",
		5
	)
	margin.add_child(box)

	for raw_row in _safe_array(
		contract.get(
			"menu_rows",
			[]
		)
	):
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue

		var row_contract: Dictionary = (
			raw_row as Dictionary
		)
		var section_id: String = str(
			row_contract.get(
				"section_id",
				""
			)
		)
		var label_text: String = str(
			row_contract.get(
				"label",
				section_id
			)
		)
		var count: int = int(
			row_contract.get(
				"count",
				0
			)
		)
		var button:= Button.new()
		button.text = (
			"%s (%d)"
			% [
				label_text,
				count
			]
			if count > 0
			else label_text
		)
		button.alignment = (
			HORIZONTAL_ALIGNMENT_LEFT
		)
		button.custom_minimum_size = (
			Vector2(
				0,
				38
			)
		)
		button.toggle_mode = true
		button.button_pressed = (
			section_id == active_section_id
		)
		button.add_theme_stylebox_override(
			"normal",
			_nav_style(
				false,
				false
			)
		)
		button.add_theme_stylebox_override(
			"hover",
			_nav_style(
				true,
				false
			)
		)
		button.add_theme_stylebox_override(
			"pressed",
			_nav_style(
				true,
				true
			)
		)
		button.pressed.connect(
			set_active_section.bind(
				section_id
			)
		)
		box.add_child(button)

	box.add_child(
		HSeparator.new()
	)

	var current_life: Dictionary = (
		_safe_dictionary(
			contract.get(
				"current_life",
				{}
			)
		)
	)
	var context_label:= Label.new()
	context_label.text = (
		"CURRENT LIFE\n%s\n%s • Age %d"
		% [
			str(
				current_life.get(
					"player_name",
					"None yet"
				)
			),
			str(
				current_life.get(
					"era_name",
					"None yet"
				)
			),
			int(
				current_life.get(
					"age",
					0
				)
			)
		]
	)
	context_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	context_label.add_theme_font_size_override(
		"font_size",
		11
	)
	context_label.add_theme_color_override(
		"font_color",
		Color(
			0.78,
			0.84,
			0.96,
			0.74
		)
	)
	box.add_child(context_label)

	return panel


func _build_active_section() -> void:
	if section_host == null:
		return

	var section_title:= Label.new()
	section_title.text = (
		_section_title(
			active_section_id
		)
	)
	section_title.add_theme_font_size_override(
		"font_size",
		20
	)
	section_title.add_theme_color_override(
		"font_color",
		Color(
			0.94,
			0.97,
			1.0,
			1.0
		)
	)
	section_host.add_child(section_title)

	match active_section_id:
		"friends_live":
			_build_friends_live_section()
		"requests":
			_build_requests_section()
		"public_feed":
			_build_public_feed_section()
		"reality_stream":
			_build_reality_stream_section()
		"search":
			_build_search_section()
		"transfers":
			_build_transfers_section()
		"announcements":
			_build_announcements_section()
		"profile":
			_build_profile_section()
		"community_realities":
			_build_community_realities_section()
		_:
			_build_empty_state(
				"This network surface has no observable entries yet."
			)


func _build_friends_live_section() -> void:
	_build_notes_strip()

	var live_rows: Array = _safe_array(
		contract.get(
			"friends_live",
			[]
		)
	)
	var connection_context: Dictionary = (
		_safe_dictionary(
			contract.get(
				"connection_context",
				{}
			)
		)
	)
	var connections: Array = _safe_array(
		connection_context.get(
			"connections",
			[]
		)
	)

	section_host.add_child(
		_subheading(
			"Friends Live (%d)"
			% live_rows.size()
		)
	)

	if live_rows.is_empty():
		_build_empty_state(
			"No connected friends are live right now."
		)
	else:
		for raw_live in live_rows:
			if typeof(raw_live) == TYPE_DICTIONARY:
				section_host.add_child(
					_build_live_friend_card(
						raw_live as Dictionary
					)
				)

	section_host.add_child(
		_subheading(
			"Connections (%d)"
			% connections.size()
		)
	)

	if connections.is_empty():
		_build_empty_state(
			"No connections yet. Search for an ErAccount and send a reality request."
		)
	else:
		for raw_connection in connections:
			if typeof(raw_connection) == TYPE_DICTIONARY:
				section_host.add_child(
					_build_connection_card(
						raw_connection as Dictionary
					)
				)


func _build_notes_strip() -> void:
	var notes_contract: Dictionary = (
		_safe_dictionary(
			contract.get(
				"visible_notes",
				{}
			)
		)
	)
	var notes: Array = _safe_array(
		notes_contract.get(
			"notes",
			[]
		)
	)

	if notes.is_empty():
		return

	section_host.add_child(
		_subheading(
			"Connection Notes"
		)
	)

	var scroll:= ScrollContainer.new()
	scroll.custom_minimum_size = (
		Vector2(
			0,
			150
		)
	)
	scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_AUTO
	)
	scroll.vertical_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)
	section_host.add_child(scroll)

	var row:= HBoxContainer.new()
	row.add_theme_constant_override(
		"separation",
		8
	)
	scroll.add_child(row)

	for raw_note in notes:
		if typeof(raw_note) != TYPE_DICTIONARY:
			continue

		var note: Dictionary = (
			raw_note as Dictionary
		)
		var username: String = str(
			note.get(
				"author_username",
				"Unknown"
			)
		)
		var note_id: String = str(
			note.get(
				"note_id",
				""
			)
		)
		var card:= _base_card()
		card.custom_minimum_size = (
			Vector2(
				230,
				136
			)
		)
		var body:= _card_body(card)

		var profile_button:= Button.new()
		profile_button.text = str(
			note.get(
				"author_display_name",
				username
			)
		)
		profile_button.flat = true
		profile_button.alignment = (
			HORIZONTAL_ALIGNMENT_LEFT
		)
		profile_button.pressed.connect(
			_on_profile_button_pressed.bind(
				username
			)
		)
		body.add_child(profile_button)

		body.add_child(
			_card_text(
				str(
					note.get(
						"text",
						""
					)
				)
			)
		)

		var reply_row:= HBoxContainer.new()
		reply_row.add_theme_constant_override(
			"separation",
			6
		)
		body.add_child(reply_row)

		var reply_edit:= LineEdit.new()
		reply_edit.placeholder_text = (
			"Reply to note"
		)
		reply_edit.size_flags_horizontal = (
			Control.SIZE_EXPAND_FILL
		)
		reply_row.add_child(reply_edit)

		var reply_button:= _action_button(
			"Reply"
		)
		reply_button.pressed.connect(
			_on_note_reply_pressed.bind(
				note_id,
				reply_edit
			)
		)
		reply_row.add_child(reply_button)
		row.add_child(card)


func _on_note_reply_pressed(
	note_id: String,
	reply_edit: LineEdit
) -> void:
	if reply_edit == null:
		return

	request_command.emit({
		"command": "network_notes.reply",
		"note_id": note_id,
		"message": reply_edit.text,
		"source": "EraLifeNetworkPanel"
	})


func _on_profile_button_pressed(
	username: String
) -> void:
	request_profile.emit(username)


func _build_requests_section() -> void:
	var requests: Array = _safe_array(
		contract.get(
			"reality_requests",
			[]
		)
	)

	if requests.is_empty():
		_build_empty_state(
			"No pending reality connection requests."
		)
		return

	for raw_request in requests:
		if typeof(raw_request) != TYPE_DICTIONARY:
			continue

		var request: Dictionary = (
			raw_request as Dictionary
		)
		var card:= _base_card()
		var body:= _card_body(card)
		var sender_username: String = str(
			request.get(
				"sender_username",
				"Unknown"
			)
		)

		body.add_child(
			_card_title(
				"@%s wants to connect"
				% sender_username
			)
		)
		body.add_child(
			_card_text(
				str(
					request.get(
						"note",
						"No note attached."
					)
				)
			)
		)

		var actions:= HBoxContainer.new()
		actions.add_theme_constant_override(
			"separation",
			8
		)
		body.add_child(actions)

		var request_id: String = str(
			request.get(
				"request_id",
				""
			)
		)
		var mailbox_entry_id: String = str(
			request.get(
				"mailbox_entry_id",
				""
			)
		)

		var accept:= _action_button(
			"Accept Connection"
		)
		accept.pressed.connect(
			_resolve_connection_request.bind(
				request_id,
				mailbox_entry_id,
				"accept"
			)
		)
		actions.add_child(accept)

		var ignore:= _action_button(
			"Ignore"
		)
		ignore.pressed.connect(
			_resolve_connection_request.bind(
				request_id,
				mailbox_entry_id,
				"ignore"
			)
		)
		actions.add_child(ignore)

		var profile_button:= _action_button(
			"View Profile"
		)
		profile_button.pressed.connect(
			_on_profile_button_pressed.bind(
				sender_username
			)
		)
		actions.add_child(profile_button)
		section_host.add_child(card)


func _resolve_connection_request(
	request_id: String,
	mailbox_entry_id: String,
	decision: String
) -> void:
	if mailbox_entry_id.strip_edges() != "":
		request_command.emit({
			"command": (
				"mailbox.consume_entry_action"
			),
			"entry_id": mailbox_entry_id,
			"entry_action": decision,
			"request_id": request_id,
			"source": "EraLifeNetworkPanel"
		})
		return

	request_command.emit({
		"command": (
			"connection_graph.resolve_request"
		),
		"request_id": request_id,
		"decision": decision,
		"source": "EraLifeNetworkPanel"
	})


func _build_public_feed_section() -> void:
	var identity_context: Dictionary = (
		_safe_dictionary(
			contract.get(
				"identity_context",
				{}
			)
		)
	)

	if bool(
		identity_context.get(
			"is_guest",
			true
		)
	):
		_build_empty_state(
			"Sign into an ErAccount to post, like, and repost. Offline simulation remains fully available."
		)
		return

	feed_post_edit = TextEdit.new()
	feed_post_edit.placeholder_text = (
		"Share something with the EraLife community..."
	)
	feed_post_edit.custom_minimum_size = (
		Vector2(
			0,
			88
		)
	)
	section_host.add_child(feed_post_edit)

	var post_button:= _action_button(
		"Post"
	)
	post_button.pressed.connect(
		_submit_public_feed_post
	)
	section_host.add_child(post_button)

	var feed_contract: Dictionary = (
		_safe_dictionary(
			contract.get(
				"public_feed",
				{}
			)
		)
	)
	var posts: Array = _safe_array(
		feed_contract.get(
			"posts",
			[]
		)
	)

	if posts.is_empty():
		_build_empty_state(
			"The Public Feed is quiet. Be the first to post."
		)
		return

	for raw_post in posts:
		if typeof(raw_post) != TYPE_DICTIONARY:
			continue

		section_host.add_child(
			_build_feed_post_card(
				raw_post as Dictionary
			)
		)


func _submit_public_feed_post() -> void:
	request_command.emit({
		"command": (
			"public_feed.create_post"
		),
		"text": (
			feed_post_edit.text
			if feed_post_edit != null
			else ""
		),
		"visibility": "public",
		"source": "EraLifeNetworkPanel"
	})


func _build_reality_stream_section() -> void:
	var stream_contract: Dictionary = (
		_safe_dictionary(
			contract.get(
				"reality_stream",
				{}
			)
		)
	)
	var entries: Array = _safe_array(
		stream_contract.get(
			"entries",
			[]
		)
	)

	if entries.is_empty():
		_build_empty_state(
			"Simulation milestones will appear here as connected realities evolve."
		)
		return

	for raw_entry in entries:
		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue

		var entry: Dictionary = (
			raw_entry as Dictionary
		)
		var card:= _base_card()
		var body:= _card_body(card)
		var username: String = str(
			entry.get(
				"author_username",
				"Unknown"
			)
		)
		var title_button:= Button.new()
		title_button.text = str(
			entry.get(
				"author_display_name",
				username
			)
		)
		title_button.flat = true
		title_button.alignment = (
			HORIZONTAL_ALIGNMENT_LEFT
		)
		title_button.pressed.connect(
			_on_profile_button_pressed.bind(
				username
			)
		)
		body.add_child(title_button)
		body.add_child(
			_card_text(
				str(
					entry.get(
						"text",
						"Reality changed."
					)
				)
			)
		)
		section_host.add_child(card)


func _build_search_section() -> void:
	var row:= HBoxContainer.new()
	row.add_theme_constant_override(
		"separation",
		8
	)
	section_host.add_child(row)

	search_edit = LineEdit.new()
	search_edit.placeholder_text = (
		"Search ErAccounts"
	)
	search_edit.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	search_edit.text_submitted.connect(
		_request_search
	)
	row.add_child(search_edit)

	var search_button:= _action_button(
		"Search"
	)
	search_button.pressed.connect(
		_request_search_from_button
	)
	row.add_child(search_button)

	if search_results.is_empty():
		_build_empty_state(
			"Search by username. Results only include ErAccounts that exist in the registry."
		)
		return

	for raw_result in search_results:
		if typeof(raw_result) != TYPE_DICTIONARY:
			continue

		var result: Dictionary = (
			raw_result as Dictionary
		)
		var card:= _base_card()
		var body:= _card_body(card)
		var username: String = str(
			result.get(
				"username",
				"Unknown"
			)
		)

		body.add_child(
			_card_title(
				"@%s"
				% username
			)
		)
		body.add_child(
			_card_text(
				str(
					result.get(
						"presence_label",
						"Registered ErAccount"
					)
				)
			)
		)

		var actions:= HBoxContainer.new()
		actions.add_theme_constant_override(
			"separation",
			8
		)
		body.add_child(actions)

		var profile_button:= _action_button(
			"View Profile"
		)
		profile_button.pressed.connect(
			_on_profile_button_pressed.bind(
				username
			)
		)
		actions.add_child(profile_button)

		var connect_button:= _action_button(
			"Connect"
		)
		connect_button.pressed.connect(
			_send_connection_request.bind(
				username
			)
		)
		actions.add_child(connect_button)
		section_host.add_child(card)


func _request_search_from_button() -> void:
	_request_search(
		search_edit.text
		if search_edit != null
		else ""
	)


func _send_connection_request(
	username: String
) -> void:
	request_command.emit({
		"command": (
			"mailbox.send_friend_request"
		),
		"recipient_username": username,
		"note": "",
		"source": "EraLifeNetworkPanel"
	})


func _build_transfers_section() -> void:
	var transfers: Array = _safe_array(
		contract.get(
			"incoming_transfers",
			[]
		)
	)
	var transfer_context: Dictionary = (
		_safe_dictionary(
			contract.get(
				"life_account_transfer",
				{}
			)
		)
	)

	if bool(
		transfer_context.get(
			"transfer_available",
			false
		)
	):
		var local_card:= _base_card()
		var local_body:= _card_body(
			local_card
		)

		local_body.add_child(
			_card_title(
				"Attach local lives to this ErAccount?"
			)
		)
		local_body.add_child(
			_card_text(
				"Attaching adds account ownership metadata. The local save files remain playable offline."
			)
		)

		var local_actions:= HBoxContainer.new()
		local_actions.add_theme_constant_override(
			"separation",
			8
		)
		local_body.add_child(local_actions)

		var attach:= _action_button(
			"Attach Local Lives"
		)
		attach.pressed.connect(
			_attach_local_lives
		)
		local_actions.add_child(attach)

		var leave_local:= _action_button(
			"Keep Local Only"
		)
		leave_local.pressed.connect(
			_keep_lives_local
		)
		local_actions.add_child(leave_local)
		section_host.add_child(local_card)

	if transfers.is_empty():
		_build_empty_state(
			"No incoming life packets, packages, or realm invitations."
		)
		return

	for raw_entry in transfers:
		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue

		section_host.add_child(
			_build_mailbox_entry_card(
				raw_entry as Dictionary
			)
		)


func _attach_local_lives() -> void:
	request_command.emit({
		"command": (
			"life_account_transfer.attach"
		),
		"life_paths": [],
		"source": "EraLifeNetworkPanel"
	})


func _keep_lives_local() -> void:
	request_command.emit({
		"command": (
			"life_account_transfer.leave_local"
		),
		"life_paths": [],
		"source": "EraLifeNetworkPanel"
	})


func _build_announcements_section() -> void:
	var announcements: Array = _safe_array(
		contract.get(
			"announcements",
			[]
		)
	)

	if announcements.is_empty():
		_build_empty_state(
			"No EraLife Network announcements."
		)
		return

	for raw_entry in announcements:
		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue

		section_host.add_child(
			_build_mailbox_entry_card(
				raw_entry as Dictionary
			)
		)


func _build_profile_section() -> void:
	var profile: Dictionary = _safe_dictionary(
		contract.get(
			"profile",
			{}
		)
	)
	var identity_context: Dictionary = (
		_safe_dictionary(
			contract.get(
				"identity_context",
				{}
			)
		)
	)

	if bool(
		identity_context.get(
			"is_guest",
			true
		)
	):
		_build_empty_state(
			"Create or log into an ErAccount to publish a profile. Your local lives remain available without one."
		)
		return

	var profile_card:= _base_card()
	var profile_body:= _card_body(
		profile_card
	)
	var top:= HBoxContainer.new()
	top.add_theme_constant_override(
		"separation",
		14
	)
	profile_body.add_child(top)

	top.add_child(
		_profile_photo_view(
			_safe_dictionary(
				profile.get(
					"profile_photo",
					{}
				)
			),
			96
		)
	)

	var identity_box:= VBoxContainer.new()
	identity_box.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	top.add_child(identity_box)

	identity_box.add_child(
		_card_title(
			str(
				profile.get(
					"display_name",
					"ErAccount"
				)
			)
		)
	)
	identity_box.add_child(
		_card_text(
			"@%s\nJoined: %s\nErAccount ID: %s"
			% [
				str(
					profile.get(
						"username",
						""
					)
				),
				str(
					profile.get(
						"joined_year",
						"None yet"
					)
				),
				str(
					profile.get(
						"eraccount_id",
						""
					)
				)
			]
		)
	)

	var upload:= _action_button(
		"Upload Profile Picture"
	)
	upload.pressed.connect(
		_open_profile_photo_dialog
	)
	identity_box.add_child(upload)
	section_host.add_child(profile_card)

	var stats:= GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override(
		"h_separation",
		12
	)
	stats.add_theme_constant_override(
		"v_separation",
		8
	)
	section_host.add_child(stats)

	_add_stat(
		stats,
		"Realities Created",
		str(
			profile.get(
				"realities_created_label",
				"None yet"
			)
		)
	)
	_add_stat(
		stats,
		"Total Lives",
		str(
			profile.get(
				"total_lives_label",
				"None yet"
			)
		)
	)
	_add_stat(
		stats,
		"Favorite Era",
		str(
			profile.get(
				"favorite_era",
				"None yet"
			)
		)
	)
	_add_stat(
		stats,
		"Favorite Reality Mode",
		str(
			profile.get(
				"favorite_reality_mode",
				"None yet"
			)
		)
	)
	_add_stat(
		stats,
		"Current Public Reality",
		str(
			profile.get(
				"current_public_reality_label",
				"None yet"
			)
		)
	)

	profile_display_name_edit = LineEdit.new()
	profile_display_name_edit.placeholder_text = (
		"Display name"
	)
	profile_display_name_edit.text = str(
		profile.get(
			"display_name",
			""
		)
	)
	section_host.add_child(
		profile_display_name_edit
	)

	profile_bio_edit = TextEdit.new()
	profile_bio_edit.placeholder_text = (
		"About me"
	)
	profile_bio_edit.text = str(
		profile.get(
			"bio",
			""
		)
	)
	profile_bio_edit.custom_minimum_size = (
		Vector2(
			0,
			88
		)
	)
	section_host.add_child(
		profile_bio_edit
	)

	section_host.add_child(
		_subheading(
			"Privacy & Permissions"
		)
	)

	var permissions: Dictionary = (
		_safe_dictionary(
			profile.get(
				"permissions",
				{}
			)
		)
	)

	_add_permission_control(
		"messages",
		"Messages",
		permissions,
		[
			"everyone",
			"connections",
			"nobody"
		]
	)
	_add_permission_control(
		"connection_requests",
		"Connection Requests",
		permissions,
		[
			"everyone",
			"nobody"
		]
	)
	_add_permission_control(
		"public_profile",
		"Profile Visibility",
		permissions,
		[
			"public",
			"connections",
			"private"
		]
	)
	_add_permission_control(
		"life_visibility",
		"Life Visibility",
		permissions,
		[
			"public",
			"connections",
			"private"
		]
	)
	_add_permission_control(
		"milestone_visibility",
		"Milestone Visibility",
		permissions,
		[
			"public",
			"connections",
			"private"
		]
	)
	_add_permission_control(
		"public_feed_visibility",
		"Feed Visibility",
		permissions,
		[
			"public",
			"connections",
			"private"
		]
	)
	_add_permission_control(
		"notes_visibility",
		"Notes Visibility",
		permissions,
		[
			"connections",
			"private"
		]
	)

	notifications_toggle = CheckButton.new()
	notifications_toggle.text = (
		"Notify me about connection activity and reality events"
	)
	notifications_toggle.button_pressed = bool(
		permissions.get(
			"notifications_enabled",
			true
		)
	)
	section_host.add_child(
		notifications_toggle
	)

	var save_profile:= _action_button(
		"Save Profile"
	)
	save_profile.pressed.connect(
		_submit_profile_update
	)
	section_host.add_child(save_profile)

	section_host.add_child(
		_subheading(
			"Change Username"
		)
	)
	profile_username_edit = LineEdit.new()
	profile_username_edit.placeholder_text = (
		"New username"
	)
	section_host.add_child(
		profile_username_edit
	)

	var username_change:= _action_button(
		"Change Username"
	)
	username_change.pressed.connect(
		_submit_username_change
	)
	section_host.add_child(
		username_change
	)

	section_host.add_child(
		_subheading(
			"Your Note"
		)
	)
	profile_note_edit = LineEdit.new()
	profile_note_edit.placeholder_text = (
		"Set a 120-character note. Use @username to tag a connection."
	)
	profile_note_edit.max_length = 120
	section_host.add_child(
		profile_note_edit
	)

	var note_button:= _action_button(
		"Set Note"
	)
	note_button.pressed.connect(
		_submit_network_note
	)
	section_host.add_child(note_button)


func _submit_username_change() -> void:
	request_command.emit({
		"command": (
			"profile.request_username_change"
		),
		"new_username": (
			profile_username_edit.text
			if profile_username_edit != null
			else ""
		),
		"source": "EraLifeNetworkPanel"
	})


func _submit_network_note() -> void:
	request_command.emit({
		"command": "network_notes.set",
		"text": (
			profile_note_edit.text
			if profile_note_edit != null
			else ""
		),
		"source": "EraLifeNetworkPanel"
	})


func _build_community_realities_section() -> void:
	var realities: Array = _safe_array(
		contract.get(
			"community_realities",
			[]
		)
	)

	if realities.is_empty():
		_build_empty_state(
			"No public or live community realities are visible yet."
		)
		return

	for raw_reality in realities:
		if typeof(raw_reality) != TYPE_DICTIONARY:
			continue

		var reality: Dictionary = (
			raw_reality as Dictionary
		)
		var card:= _base_card()
		var body:= _card_body(card)
		var username: String = str(
			reality.get(
				"username",
				"Unknown"
			)
		)

		body.add_child(
			_card_title(
				str(
					reality.get(
						"title",
						"Community Reality"
					)
				)
			)
		)
		body.add_child(
			_card_text(
				"@%s • %s%s"
				% [
					username,
					str(
						reality.get(
							"era_name",
							"Unknown Era"
						)
					),
					(
						" • LIVE"
						if bool(
							reality.get(
								"active",
								false
							)
						)
						else ""
					)
				]
			)
		)

		var profile_button:= _action_button(
			"View Creator"
		)
		profile_button.pressed.connect(
			_on_profile_button_pressed.bind(
				username
			)
		)
		body.add_child(profile_button)
		section_host.add_child(card)


func _build_bottom_actions() -> void:
	var row:= HBoxContainer.new()
	row.alignment = (
		BoxContainer.ALIGNMENT_CENTER
	)
	row.add_theme_constant_override(
		"separation",
		12
	)
	add_child(row)

	for raw_action in _safe_array(
		contract.get(
			"primary_actions",
			[]
		)
	):
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
		)
		var button:= _action_button(
			str(
				action.get(
					"label",
					action_id
				)
			)
		)
		button.custom_minimum_size = (
			Vector2(
				240,
				40
			)
		)
		button.pressed.connect(
			_trigger_primary_action.bind(
				action_id
			)
		)
		row.add_child(button)


func _trigger_primary_action(
	action_id: String
) -> void:
	if action_id == "browse_community_realities":
		set_active_section(
			"community_realities"
		)

	request_command.emit({
		"command": (
			"eralife_network.%s"
			% action_id
		),
		"source": "EraLifeNetworkPanel"
	})


func _build_connection_card(
	connection: Dictionary
) -> Control:
	var card:= _base_card()
	var body:= _card_body(card)
	var username: String = str(
		connection.get(
			"username",
			"Unknown"
		)
	)

	body.add_child(
		_card_title(
			"@%s"
			% username
		)
	)
	body.add_child(
		_card_text(
			"Connected ErAccount • Click to view profile"
		)
	)

	var view:= _action_button(
		"View Profile"
	)
	view.pressed.connect(
		_on_profile_button_pressed.bind(
			username
		)
	)
	body.add_child(view)
	return card


func _build_live_friend_card(
	node: Dictionary
) -> Control:
	var card:= _base_card()
	var body:= _card_body(card)
	var username: String = str(
		node.get(
			"username",
			"Unknown"
		)
	)
	var life_state: Dictionary = (
		_safe_dictionary(
			node.get(
				"life_state",
				{}
			)
		)
	)

	body.add_child(
		_card_title(
			"🟢 %s is live"
			% username
		)
	)
	body.add_child(
		_card_text(
			"%s • %s"
			% [
				str(
					life_state.get(
						"player_name",
						"Current Life"
					)
				),
				str(
					life_state.get(
						"era_name",
						"Unknown Era"
					)
				)
			]
		)
	)

	var profile_button:= _action_button(
		"Profile"
	)
	profile_button.pressed.connect(
		_on_profile_button_pressed.bind(
			username
		)
	)
	body.add_child(profile_button)

	var invite_button:= _action_button(
		"Invite To My Realm"
	)
	invite_button.pressed.connect(
		_invite_live_friend.bind(
			username
		)
	)
	body.add_child(invite_button)
	return card


func _invite_live_friend(
	username: String
) -> void:
	request_command.emit({
		"command": (
			"mailbox.send_live_reality_invite"
		),
		"recipient_username": username,
		"message": (
			"Join my current reality."
		),
		"source": "EraLifeNetworkPanel"
	})


func _build_feed_post_card(
	post: Dictionary
) -> Control:
	var card:= _base_card()
	var body:= _card_body(card)
	var username: String = str(
		post.get(
			"author_username",
			"Unknown"
		)
	)
	var post_id: String = str(
		post.get(
			"post_id",
			""
		)
	)

	var author:= Button.new()
	author.text = (
		"%s  @%s"
		% [
			str(
				post.get(
					"author_display_name",
					username
				)
			),
			username
		]
	)
	author.flat = true
	author.alignment = (
		HORIZONTAL_ALIGNMENT_LEFT
	)
	author.pressed.connect(
		_on_profile_button_pressed.bind(
			username
		)
	)
	body.add_child(author)

	body.add_child(
		_card_text(
			str(
				post.get(
					"text",
					""
				)
			)
		)
	)

	var actions:= HBoxContainer.new()
	actions.add_theme_constant_override(
		"separation",
		8
	)
	body.add_child(actions)

	var like:= _action_button(
		"♥ %d"
		% int(
			post.get(
				"like_count",
				0
			)
		)
	)
	like.pressed.connect(
		_toggle_feed_like.bind(
			post_id
		)
	)
	actions.add_child(like)

	var repost:= _action_button(
		"↻ %d"
		% int(
			post.get(
				"repost_count",
				0
			)
		)
	)
	repost.pressed.connect(
		_toggle_feed_repost.bind(
			post_id
		)
	)
	actions.add_child(repost)
	return card


func _toggle_feed_like(
	post_id: String
) -> void:
	request_command.emit({
		"command": (
			"public_feed.toggle_like"
		),
		"post_id": post_id,
		"source": "EraLifeNetworkPanel"
	})


func _toggle_feed_repost(
	post_id: String
) -> void:
	request_command.emit({
		"command": (
			"public_feed.toggle_repost"
		),
		"post_id": post_id,
		"source": "EraLifeNetworkPanel"
	})


func _build_mailbox_entry_card(
	entry: Dictionary
) -> Control:
	var card:= _base_card()
	var body:= _card_body(card)
	var entry_id: String = str(
		entry.get(
			"entry_id",
			""
		)
	)

	body.add_child(
		_card_title(
			str(
				entry.get(
					"title",
					"Reality Intake"
				)
			)
		)
	)
	body.add_child(
		_card_text(
			str(
				entry.get(
					"message",
					""
				)
			)
		)
	)

	var actions:= HBoxContainer.new()
	actions.add_theme_constant_override(
		"separation",
		8
	)
	body.add_child(actions)

	for raw_action in _safe_array(
		entry.get(
			"actions",
			[]
		)
	):
		var action_id: String = str(
			raw_action
		)
		var button:= _action_button(
			action_id.capitalize()
		)
		button.pressed.connect(
			_consume_mailbox_entry.bind(
				entry_id,
				action_id
			)
		)
		actions.add_child(button)

	return card


func _consume_mailbox_entry(
	entry_id: String,
	action_id: String
) -> void:
	request_command.emit({
		"command": (
			"mailbox.consume_entry_action"
		),
		"entry_id": entry_id,
		"entry_action": action_id,
		"source": "EraLifeNetworkPanel"
	})


func _submit_profile_update() -> void:
	var permissions: Dictionary = {}

	for raw_key in permission_controls.keys():
		var key: String = str(raw_key)
		var control: OptionButton = (
			permission_controls.get(
				key
			) as OptionButton
		)

		if control == null:
			continue

		permissions [key] = str(
			control.get_item_metadata(
				control.selected
			)
		)

	permissions ["notifications_enabled"] = (
		notifications_toggle.button_pressed
		if notifications_toggle != null
		else true
	)

	request_command.emit({
		"command": "profile.update",
		"display_name": (
			profile_display_name_edit.text
			if profile_display_name_edit != null
			else ""
		),
		"bio": (
			profile_bio_edit.text
			if profile_bio_edit != null
			else ""
		),
		"permissions": permissions,
		"source": "EraLifeNetworkPanel"
	})


func _add_permission_control(
	permission_key: String,
	label_text: String,
	permissions: Dictionary,
	choices: Array
) -> void:
	var row:= HBoxContainer.new()
	row.add_theme_constant_override(
		"separation",
		8
	)
	section_host.add_child(row)

	var label:= Label.new()
	label.text = label_text
	label.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	row.add_child(label)

	var options:= OptionButton.new()
	var current_value: String = str(
		permissions.get(
			permission_key,
			(
				choices [0]
				if not choices.is_empty()
				else "connections"
			)
		)
	)

	for raw_choice in choices:
		var choice: String = str(
			raw_choice
		)
		options.add_item(
			choice.capitalize()
		)
		var item_index: int = (
			options.item_count - 1
		)
		options.set_item_metadata(
			item_index,
			choice
		)

		if choice == current_value:
			options.select(item_index)

	row.add_child(options)
	permission_controls [
		permission_key
	] = options


func _open_profile_photo_dialog() -> void:
	if (
		photo_dialog == null
		or not is_instance_valid(
			photo_dialog
		)
	):
		photo_dialog = FileDialog.new()
		photo_dialog.file_mode = (
			FileDialog.FILE_MODE_OPEN_FILE
		)
		photo_dialog.access = (
			FileDialog.ACCESS_FILESYSTEM
		)
		photo_dialog.filters = (
			PackedStringArray([
				"*.png ; PNG Images",
				"*.jpg,*.jpeg ; JPEG Images",
				"*.webp ; WebP Images"
			])
		)
		photo_dialog.file_selected.connect(
			_upload_profile_photo
		)
		add_child(photo_dialog)

	photo_dialog.popup_centered_ratio(
		0.72
	)


func _upload_profile_photo(
	path: String
) -> void:
	request_command.emit({
		"command": "profile.upload_photo",
		"source_path": path,
		"source": "EraLifeNetworkPanel"
	})


func _request_search(
	query: String
) -> void:
	var clean_query: String = str(
		query
	).strip_edges()

	if clean_query == "":
		search_results = []
		_build()
		return

	request_command.emit({
		"command": (
			"search.identity_discovery"
		),
		"query": clean_query,
		"limit": 12,
		"source": "EraLifeNetworkPanel"
	})


func _add_stat(
	grid: GridContainer,
	label_text: String,
	value_text: String
) -> void:
	var label:= Label.new()
	label.text = label_text
	label.add_theme_color_override(
		"font_color",
		Color(
			0.74,
			0.8,
			0.92,
			0.76
		)
	)
	grid.add_child(label)

	var value:= Label.new()
	value.text = value_text
	value.add_theme_color_override(
		"font_color",
		Color(
			0.96,
			0.98,
			1.0,
			1.0
		)
	)
	grid.add_child(value)


func _build_empty_state(
	text: String
) -> void:
	var panel:= PanelContainer.new()
	panel.add_theme_stylebox_override(
		"panel",
		_panel_style(
			Color(
				0.035,
				0.04,
				0.06,
				0.72
			),
			Color(
				0.44,
				0.54,
				0.76,
				0.26
			),
			14
		)
	)

	var margin:= MarginContainer.new()
	margin.add_theme_constant_override(
		"margin_left",
		16
	)
	margin.add_theme_constant_override(
		"margin_right",
		16
	)
	margin.add_theme_constant_override(
		"margin_top",
		16
	)
	margin.add_theme_constant_override(
		"margin_bottom",
		16
	)
	panel.add_child(margin)

	var label:= Label.new()
	label.text = text
	label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	label.add_theme_color_override(
		"font_color",
		Color(
			0.8,
			0.85,
			0.96,
			0.76
		)
	)
	margin.add_child(label)
	section_host.add_child(panel)


func _base_card() -> PanelContainer:
	var card:= PanelContainer.new()
	card.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	card.add_theme_stylebox_override(
		"panel",
		_panel_style(
			Color(
				0.034,
				0.038,
				0.056,
				0.92
			),
			Color(
				0.46,
				0.58,
				0.88,
				0.3
			),
			14
		)
	)
	return card


func _card_body(
	card: PanelContainer
) -> VBoxContainer:
	var margin:= MarginContainer.new()
	margin.add_theme_constant_override(
		"margin_left",
		12
	)
	margin.add_theme_constant_override(
		"margin_right",
		12
	)
	margin.add_theme_constant_override(
		"margin_top",
		10
	)
	margin.add_theme_constant_override(
		"margin_bottom",
		10
	)
	card.add_child(margin)

	var body:= VBoxContainer.new()
	body.add_theme_constant_override(
		"separation",
		6
	)
	margin.add_child(body)
	return body


func _card_title(
	text: String
) -> Label:
	var label:= Label.new()
	label.text = text
	label.add_theme_font_size_override(
		"font_size",
		15
	)
	label.add_theme_color_override(
		"font_color",
		Color(
			0.96,
			0.98,
			1.0,
			1.0
		)
	)
	return label


func _card_text(
	text: String
) -> Label:
	var label:= Label.new()
	label.text = text
	label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	label.add_theme_color_override(
		"font_color",
		Color(
			0.8,
			0.84,
			0.94,
			0.82
		)
	)
	return label


func _subheading(
	text: String
) -> Label:
	var label:= Label.new()
	label.text = text
	label.add_theme_font_size_override(
		"font_size",
		14
	)
	label.add_theme_color_override(
		"font_color",
		Color(
			0.82,
			0.9,
			1.0,
			0.96
		)
	)
	return label


func _action_button(
	text: String
) -> Button:
	var button:= Button.new()
	button.text = text
	button.custom_minimum_size = (
		Vector2(
			110,
			32
		)
	)
	return button


func _profile_photo_view(
	photo_contract: Dictionary,
	photo_size: int
) -> Control:
	var resolved_photo_size: int = maxi(
		1,
		photo_size
	)
	var photo_radius: int = int(
		round(
			float(resolved_photo_size)
			* 0.5
		)
	)
	var fallback_font_size: int = maxi(
		14,
		int(
			round(
				float(resolved_photo_size)
				/ 3.0
			)
		)
	)

	var frame:= PanelContainer.new()
	frame.custom_minimum_size = (
		Vector2(
			resolved_photo_size,
			resolved_photo_size
		)
	)
	frame.add_theme_stylebox_override(
		"panel",
		_panel_style(
			Color(
				0.1,
				0.12,
				0.18,
				1.0
			),
			Color(
				0.72,
				0.82,
				1.0,
				0.48
			),
			photo_radius
		)
	)

	var path: String = str(
		photo_contract.get(
			"local_path",
			""
		)
	).strip_edges()

	if (
		path != ""
		and FileAccess.file_exists(path)
	):
		var image: Image = (
			Image.load_from_file(path)
		)

		if (
			image != null
			and not image.is_empty()
		):
			var texture_rect:= TextureRect.new()
			texture_rect.texture = (
				ImageTexture.create_from_image(
					image
				)
			)
			texture_rect.expand_mode = (
				TextureRect.EXPAND_IGNORE_SIZE
			)
			texture_rect.stretch_mode = (
				TextureRect.STRETCH_KEEP_ASPECT_COVERED
			)
			texture_rect.clip_contents = true
			frame.add_child(texture_rect)
			return frame

	var fallback:= Label.new()
	fallback.text = "ER"
	fallback.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	fallback.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)
	fallback.add_theme_font_size_override(
		"font_size",
		fallback_font_size
	)
	frame.add_child(fallback)
	return frame


func _section_title(
	section_id: String
) -> String:
	var section_titles: Dictionary = {
		"friends_live": "🟢 Friends Live",
		"requests": "📨 Reality Requests",
		"public_feed": "💬 Public Feed",
		"reality_stream": "🌍 Reality Stream",
		"search": "🔎 Search ErAccounts",
		"transfers": "📦 Incoming Transfers",
		"announcements": "📢 Announcements",
		"profile": "👤 Profile",
		"community_realities": (
			"Community Realities"
		)
	}

	return str(
		section_titles.get(
			section_id,
			"EraLife Network"
		)
	)


func _section_exists(
	section_id: String
) -> bool:
	if section_id == "community_realities":
		return true

	for raw_row in _safe_array(
		contract.get(
			"menu_rows",
			[]
		)
	):
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue

		if str(
			(
				raw_row as Dictionary
			).get(
				"section_id",
				""
			)
		) == section_id:
			return true

	return false


func _nav_style(
	hovered: bool,
	pressed: bool
) -> StyleBoxFlat:
	var background:= Color(
		0.05,
		0.06,
		0.09,
		0.9
	)
	var border:= Color(
		0.32,
		0.38,
		0.58,
		0.22
	)

	if pressed:
		background = Color(
			0.16,
			0.22,
			0.38,
			0.96
		)
		border = Color(
			0.64,
			0.78,
			1.0,
			0.72
		)
	elif hovered:
		background = Color(
			0.09,
			0.12,
			0.19,
			0.96
		)
		border = Color(
			0.52,
			0.66,
			0.96,
			0.48
		)

	return _panel_style(
		background,
		border,
		10
	)


func _panel_style(
	background: Color,
	border: Color,
	radius: int
) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)


func _clear_children(
	node: Node
) -> void:
	for child in node.get_children():
		child.queue_free()