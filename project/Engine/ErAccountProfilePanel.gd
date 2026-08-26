extends PanelContainer
class_name ErAccountProfilePanel

signal request_close
signal request_command(
	envelope: Dictionary
)

const PANEL_SCHEMA:= (
	"eralife.eraccount.profile_panel"
)
const PANEL_VERSION:= 1

var profile_contract: Dictionary = {}
var content_root: VBoxContainer = null
var message_edit: LineEdit = null


func _init() -> void:
	visible = false
	top_level = true
	z_as_relative = false
	z_index = 1700
	mouse_filter = Control.MOUSE_FILTER_STOP

	add_theme_stylebox_override(
		"panel",
		_outer_style()
	)


func _ready() -> void:
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -280
	offset_right = 280
	offset_top = -360
	offset_bottom = 360


func render_profile(
	next_profile: Dictionary
) -> void:
	profile_contract = (
		next_profile.duplicate(true)
	)
	_build()
	visible = true
	show()


func apply_command_report(
	report: Dictionary
) -> void:
	if str(
		report.get(
			"mode",
			""
		)
	) == "profile_emitted":
		render_profile(report)
		return

	if (
		content_root != null
		and is_instance_valid(
			content_root
		)
	):
		var status:= Label.new()
		status.text = str(
			report.get(
				"message",
				report.get(
					"reason",
					"Profile request handled."
				)
			)
		)
		status.autowrap_mode = (
			TextServer.AUTOWRAP_WORD_SMART
		)
		status.add_theme_color_override(
			"font_color",
			Color(
				0.72,
				1.0,
				0.82,
				0.9
			)
		)
		content_root.add_child(status)


func close_profile() -> void:
	visible = false
	request_close.emit()


func _build() -> void:
	_clear_children(self)
	add_theme_stylebox_override(
		"panel",
		_outer_style()
	)

	var margin:= MarginContainer.new()
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
		14
	)
	margin.add_theme_constant_override(
		"margin_bottom",
		14
	)
	add_child(margin)

	var scroll:= ScrollContainer.new()
	scroll.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	scroll.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)
	margin.add_child(scroll)

	content_root = VBoxContainer.new()
	content_root.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	content_root.add_theme_constant_override(
		"separation",
		10
	)
	scroll.add_child(content_root)

	var banner:= PanelContainer.new()
	banner.custom_minimum_size = (
		Vector2(
			0,
			120
		)
	)
	banner.add_theme_stylebox_override(
		"panel",
		_banner_style()
	)
	content_root.add_child(banner)

	var banner_margin:= MarginContainer.new()
	banner_margin.add_theme_constant_override(
		"margin_left",
		14
	)
	banner_margin.add_theme_constant_override(
		"margin_right",
		14
	)
	banner_margin.add_theme_constant_override(
		"margin_top",
		14
	)
	banner_margin.add_theme_constant_override(
		"margin_bottom",
		14
	)
	banner.add_child(banner_margin)

	var top:= HBoxContainer.new()
	top.add_theme_constant_override(
		"separation",
		14
	)
	banner_margin.add_child(top)

	top.add_child(
		_profile_photo_view(
			_safe_dictionary(
				profile_contract.get(
					"profile_photo",
					{}
				)
			),
			92
		)
	)

	var identity_box:= VBoxContainer.new()
	identity_box.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	identity_box.add_theme_constant_override(
		"separation",
		2
	)
	top.add_child(identity_box)

	var display_name:= Label.new()
	display_name.text = str(
		profile_contract.get(
			"display_name",
			"Unknown ErAccount"
		)
	)
	display_name.add_theme_font_size_override(
		"font_size",
		24
	)
	display_name.add_theme_color_override(
		"font_color",
		Color(
			0.98,
			0.99,
			1.0,
			1.0
		)
	)
	identity_box.add_child(display_name)

	var username: String = str(
		profile_contract.get(
			"username",
			""
		)
	)
	var username_label:= Label.new()
	username_label.text = (
		"@%s"
		% username
	)
	username_label.add_theme_color_override(
		"font_color",
		Color(
			0.76,
			0.82,
			0.96,
			0.84
		)
	)
	identity_box.add_child(username_label)

	var identity_label:= Label.new()
	identity_label.text = (
		"ErAccount ID: %s\nJoined: %s"
		% [
			str(
				profile_contract.get(
					"eraccount_id",
					""
				)
			),
			str(
				profile_contract.get(
					"joined_year",
					"None yet"
				)
			)
		]
	)
	identity_label.add_theme_font_size_override(
		"font_size",
		11
	)
	identity_label.add_theme_color_override(
		"font_color",
		Color(
			0.74,
			0.78,
			0.88,
			0.72
		)
	)
	identity_box.add_child(identity_label)

	var close_button:= Button.new()
	close_button.text = "✕"
	close_button.custom_minimum_size = (
		Vector2(
			42,
			42
		)
	)
	close_button.pressed.connect(
		close_profile
	)
	top.add_child(close_button)

	var bio_text: String = str(
		profile_contract.get(
			"bio",
			""
		)
	).strip_edges()
	var bio:= Label.new()
	bio.text = (
		bio_text
		if bio_text != ""
		else "No profile bio yet."
	)
	bio.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	bio.add_theme_color_override(
		"font_color",
		Color(
			0.84,
			0.87,
			0.94,
			0.88
		)
	)
	content_root.add_child(bio)

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
	content_root.add_child(stats)

	_add_stat(
		stats,
		"Realities Created",
		str(
			profile_contract.get(
				"realities_created_label",
				"None yet"
			)
		)
	)
	_add_stat(
		stats,
		"Total Lives",
		str(
			profile_contract.get(
				"total_lives_label",
				"None yet"
			)
		)
	)
	_add_stat(
		stats,
		"Favorite Era",
		str(
			profile_contract.get(
				"favorite_era",
				"None yet"
			)
		)
	)
	_add_stat(
		stats,
		"Favorite Reality Mode",
		str(
			profile_contract.get(
				"favorite_reality_mode",
				"None yet"
			)
		)
	)
	_add_stat(
		stats,
		"Current Public Reality",
		str(
			profile_contract.get(
				"current_public_reality_label",
				"None yet"
			)
		)
	)

	if not bool(
		profile_contract.get(
			"is_self",
			false
		)
	):
		_build_social_actions(
			username
		)

	var privacy:= Label.new()
	privacy.text = (
		"Connected profile"
		if bool(
			profile_contract.get(
				"is_connection",
				false
			)
		)
		else "Public profile projection"
	)
	privacy.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	privacy.add_theme_font_size_override(
		"font_size",
		11
	)
	privacy.add_theme_color_override(
		"font_color",
		Color(
			0.7,
			0.76,
			0.9,
			0.66
		)
	)
	content_root.add_child(privacy)


func _build_social_actions(
	username: String
) -> void:
	var row:= HBoxContainer.new()
	row.add_theme_constant_override(
		"separation",
		8
	)
	content_root.add_child(row)

	if not bool(
		profile_contract.get(
			"is_connection",
			false
		)
	):
		var connect_button:= Button.new()
		connect_button.text = (
			"Send Connection Request"
		)
		connect_button.pressed.connect(
			_send_connection_request.bind(
				username
			)
		)
		row.add_child(connect_button)

	message_edit = LineEdit.new()
	message_edit.placeholder_text = (
		"Message @%s"
		% username
	)
	message_edit.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	row.add_child(message_edit)

	var send_button:= Button.new()
	send_button.text = "Send Message"
	send_button.pressed.connect(
		_send_message.bind(
			username
		)
	)
	row.add_child(send_button)

func _send_connection_request(
	username: String
) -> void:
	request_command.emit({
		"command": (
			"mailbox.send_friend_request"
		),
		"recipient_username": username,
		"note": "",
		"source": (
			"ErAccountProfilePanel"
		)
	})


func _send_message(
	username: String
) -> void:
	request_command.emit({
		"command": (
			"messenger.send_direct_message"
		),
		"recipient_username": username,
		"message": (
			message_edit.text
			if message_edit != null
			else ""
		),
		"source": (
			"ErAccountProfilePanel"
		)
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
			0.72,
			0.78,
			0.9,
			0.72
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
		1,
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
		_photo_style(
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
func _outer_style() -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(
		0.02,
		0.022,
		0.032,
		0.99
	)
	style.border_color = Color(
		0.54,
		0.66,
		1.0,
		0.58
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
		0.62
	)
	style.shadow_size = 22
	return style


func _banner_style() -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(
		0.12,
		0.16,
		0.28,
		0.98
	)
	style.border_color = Color(
		0.66,
		0.78,
		1.0,
		0.44
	)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	return style


func _photo_style(
	radius: int
) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(
		0.08,
		0.1,
		0.16,
		1.0
	)
	style.border_color = Color(
		0.82,
		0.9,
		1.0,
		0.72
	)
	style.set_border_width_all(2)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _clear_children(
	node: Node
) -> void:
	for child in node.get_children():
		child.queue_free()