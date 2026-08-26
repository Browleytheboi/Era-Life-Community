extends Control
class_name PopupViewer

signal contract_selected(contract_id: String)
signal option_selected(contract_id: String, option_id: String)
signal viewer_closed

var dim: ColorRect
var card: PanelContainer
var title_label: Label
var body_label: RichTextLabel
var list_box: VBoxContainer
var options_box: VBoxContainer
var footer_label: Label

var active_contracts: Dictionary = {}
var active_category_groups: Dictionary = {}
var last_list_payload: Dictionary = {}
var current_contract_id: String = ""
var current_category_key: String = ""


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	top_level = true
	z_as_relative = false
	z_index = 660
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()


func _build_ui() -> void:
	if dim != null:
		return

	dim = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.56)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center:= CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(center)

	card = PanelContainer.new()
	card.custom_minimum_size = Vector2(720, 420)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(card)

	var margin:= MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	card.add_child(margin)

	var root:= VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(root)

	var top:= HBoxContainer.new()
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(top)

	title_label = Label.new()
	title_label.text = "Pending Situations"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 22)
	top.add_child(title_label)

	var close_btn:= Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(52, 42)
	close_btn.pressed.connect(_on_close_pressed)
	top.add_child(close_btn)

	body_label = RichTextLabel.new()
	body_label.bbcode_enabled = false
	body_label.fit_content = true
	body_label.scroll_active = false
	body_label.custom_minimum_size = Vector2(0, 80)
	body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(body_label)

	var scroll:= ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 240)
	root.add_child(scroll)

	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 8)
	scroll.add_child(list_box)

	options_box = VBoxContainer.new()
	options_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options_box.add_theme_constant_override("separation", 8)
	root.add_child(options_box)

	footer_label = Label.new()
	footer_label.text = "These are unresolved realities. Closing this viewer does not resolve them."
	footer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(footer_label)

func _pending_viewer_contract_identity(
	contract: Dictionary
) -> String:
	for raw_key in [
		"view_contract_id",
		"id",
		"contract_id",
		"source_contract_id"
	]:
		var key: String = str(
			raw_key
		)
		var candidate: String = str(
			contract.get(
				key,
				""
			)
		).strip_edges()

		if candidate != "":
			return candidate

	return ""


func _pending_viewer_group_identity_set(
	group: Dictionary
) -> Dictionary:
	var seen: Dictionary = {}
	var contract_ids_raw: Variant = group.get(
		"contract_ids",
		[]
	)

	if typeof(contract_ids_raw) == TYPE_ARRAY:
		for raw_id in contract_ids_raw:
			var contract_id: String = str(
				raw_id
			).strip_edges()

			if contract_id != "":
				seen [
					contract_id
				] = true

	for raw_key in [
		"contracts",
		"summaries"
	]:
		var key: String = str(
			raw_key
		)
		var rows_raw: Variant = group.get(
			key,
			[]
		)

		if typeof(rows_raw) != TYPE_ARRAY:
			continue

		for raw_row in rows_raw:
			if typeof(raw_row) != TYPE_DICTIONARY:
				continue

			var row_id: String = (
				_pending_viewer_contract_identity(
					raw_row as Dictionary
				)
			)

			if row_id != "":
				seen [
					row_id
				] = true

	return seen


func _active_contract_key_for_any_id(contract_id: String) -> String:
	# FIX: active_contracts is keyed by _pending_viewer_contract_identity(), which
	# prefers view_contract_id, while current_contract_id comes from present_contract()
	# and is the SOURCE contract id. A repaint therefore lost the open contract and
	# dumped the player back to the category overview mid-choice. Match on any of the
	# id aliases so either form resolves to the same entry.
	var clean: String = str(contract_id).strip_edges()
	if clean == "":
		return ""

	if active_contracts.has(clean):
		return clean

	for raw_key in active_contracts.keys():
		var contract_raw: Variant = active_contracts.get(raw_key, {})
		if typeof(contract_raw) != TYPE_DICTIONARY:
			continue

		var contract: Dictionary = contract_raw as Dictionary
		for alias_key in ["id", "contract_id", "view_contract_id", "source_contract_id"]:
			if str(contract.get(alias_key, "")).strip_edges() == clean:
				return str(raw_key)

	return ""


func restore_pending_navigation(
	category_key: String,
	contract_id: String
) -> bool:
	var clean_contract_id: String = str(
		contract_id
	).strip_edges()
	var clean_category_key: String = str(
		category_key
	).strip_edges().to_lower()

	var resolved_key: String = _active_contract_key_for_any_id(
		clean_contract_id
	)

	if resolved_key != "":
		current_category_key = clean_category_key

		var contract_raw: Variant = (
			active_contracts.get(
				resolved_key,
				{}
			)
		)

		if typeof(contract_raw) == TYPE_DICTIONARY:
			present_contract(
				(
					contract_raw as Dictionary
				).duplicate(true)
			)
			return true

	if (
		clean_category_key != ""
		and active_category_groups.has(
			clean_category_key
		)
	):
		_render_pending_category_overview(
			clean_category_key
		)
		return true

	current_contract_id = ""
	current_category_key = ""

	return false
func present_list(
	payload: Dictionary,
	reveal_surface: bool = true
) -> void:
	_build_ui()

	_set_pending_viewer_overview_scroller_mode(
		true
	)

	active_contracts.clear()
	active_category_groups.clear()
	current_contract_id = ""
	current_category_key = ""
	last_list_payload = payload.duplicate(true)

	var count: int = int(
		payload.get(
			"count",
			0
		)
	)
	var era_name: String = str(
		payload.get(
			"era_name",
			"Modern Era"
		)
	)
	var category: String = str(
		payload.get(
			"dominant_category",
			_dominant_category_from_payload(
				payload
			)
		)
	)
	var urgency: float = (
		_dominant_urgency_from_payload(
			payload
		)
	)

	_apply_visual_context(
		category,
		era_name,
		urgency,
		"list"
	)

	title_label.text = (
		"Pending Situations (%d)"
		% count
	)
	body_label.custom_minimum_size = Vector2(
		0,
		64
	)
	body_label.clear()
	body_label.append_text(
		"Choose a category to inspect. Each category opens "
		+ "into its unresolved situation overviews."
	)

	_clear_container(
		list_box
	)
	_clear_container(
		options_box
	)

	var contracts: Array = (
		payload.get(
			"contracts",
			[]
		)
		if typeof(
			payload.get(
				"contracts",
				[]
			)
		) == TYPE_ARRAY
		else []
	)

	for raw_contract in contracts:
		if typeof(raw_contract) != TYPE_DICTIONARY:
			continue

		var contract: Dictionary = (
			raw_contract as Dictionary
		).duplicate(true)
		var contract_id: String = (
			_pending_viewer_contract_identity(
				contract
			)
		)

		if contract_id == "":
			continue

		contract [
			"id"
		] = contract_id
		contract [
			"contract_id"
		] = str(
			contract.get(
				"contract_id",
				contract_id
			)
		)
		contract [
			"era_name"
		] = str(
			contract.get(
				"era_name",
				era_name
			)
		)
		contract [
			"category"
		] = (
			_pending_viewer_category_key_for_contract(
				contract
			)
		)
		contract [
			"view_contract"
		] = bool(
			contract.get(
				"view_contract",
				true
			)
		)
		contract [
			"surface_role"
		] = str(
			contract.get(
				"surface_role",
				"full_pending_situation"
			)
		)

		active_contracts [
			contract_id
		] = contract.duplicate(true)

	active_category_groups = (
		_pending_viewer_category_groups_from_payload(
			payload,
			era_name
		)
	)

	var payload_category_groups_raw: Variant = payload.get(
		"category_groups",
		[]
	)

	if typeof(payload_category_groups_raw) == TYPE_ARRAY:
		for raw_group in payload_category_groups_raw:
			if typeof(raw_group) != TYPE_DICTIONARY:
				continue

			var group: Dictionary = (
				raw_group as Dictionary
			).duplicate(true)
			var group_key: String = str(
				group.get(
					"key",
					group.get(
						"category",
						""
					)
				)
			).strip_edges().to_lower()

			if group_key == "":
				continue

			if not active_category_groups.has(
				group_key
			):
				active_category_groups [
					group_key
				] = {
					"key": group_key,
					"label": str(
						group.get(
							"label",
							_pending_viewer_category_label(
								group_key
							)
						)
					),
					"count": int(
						group.get(
							"count",
							0
						)
					),
					"max_urgency": float(
						group.get(
							"max_urgency",
							urgency
						)
					),
					"era_name": era_name,
					"contract_ids": [],
					"contracts": [],
					"summaries": [],
					"tooltip": str(
						group.get(
							"tooltip",
							"Open %s pending situations."
							% _pending_viewer_category_label(
								group_key
							)
						)
					)
				}

			var merged_group: Dictionary = (
				active_category_groups [
					group_key
				]
			)
			var existing_contract_ids: Dictionary = (
				_pending_viewer_group_identity_set(
					merged_group
				)
			)
			var merged_summaries: Array = (
				(
					merged_group.get(
						"summaries",
						[]
					) as Array
				).duplicate(true)
				if typeof(
					merged_group.get(
						"summaries",
						[]
					)
				) == TYPE_ARRAY
				else []
			)
			var merged_contracts: Array = (
				(
					merged_group.get(
						"contracts",
						[]
					) as Array
				).duplicate(true)
				if typeof(
					merged_group.get(
						"contracts",
						[]
					)
				) == TYPE_ARRAY
				else []
			)
			var merged_contract_ids: Array = (
				(
					merged_group.get(
						"contract_ids",
						[]
					) as Array
				).duplicate(true)
				if typeof(
					merged_group.get(
						"contract_ids",
						[]
					)
				) == TYPE_ARRAY
				else []
			)
			var merged_summary_ids: Dictionary = {}

			for raw_existing_summary in merged_summaries:
				if typeof(
					raw_existing_summary
				) != TYPE_DICTIONARY:
					continue

				var existing_summary_id: String = (
					_pending_viewer_contract_identity(
						raw_existing_summary as Dictionary
					)
				)

				if existing_summary_id != "":
					merged_summary_ids [
						existing_summary_id
					] = true

			var summaries_raw: Variant = group.get(
				"summaries",
				[]
			)

			if typeof(summaries_raw) == TYPE_ARRAY:
				for raw_summary in summaries_raw:
					if typeof(
						raw_summary
					) != TYPE_DICTIONARY:
						continue

					var summary: Dictionary = (
						raw_summary as Dictionary
					).duplicate(true)
					var summary_id: String = (
						_pending_viewer_contract_identity(
							summary
						)
					)

					if summary_id == "":
						continue

					summary [
						"id"
					] = summary_id
					summary [
						"contract_id"
					] = str(
						summary.get(
							"contract_id",
							summary_id
						)
					)
					summary [
						"view_contract_id"
					] = str(
						summary.get(
							"view_contract_id",
							summary_id
						)
					)
					summary [
						"category"
					] = group_key
					summary [
						"era_name"
					] = era_name
					summary [
						"view_contract"
					] = true
					summary [
						"surface_role"
					] = "full_pending_situation"
					summary [
						"ui_is_renderer_only"
					] = true



					if not active_contracts.has(
						summary_id
					):
						active_contracts [
							summary_id
						] = summary.duplicate(true)

					if not merged_summary_ids.has(
						summary_id
					):
						merged_summaries.append(
							summary.duplicate(true)
						)
						merged_summary_ids [
							summary_id
						] = true



					if not existing_contract_ids.has(
						summary_id
					):
						merged_contracts.append(
							summary.duplicate(true)
						)
						merged_contract_ids.append(
							summary_id
						)
						existing_contract_ids [
							summary_id
						] = true

			merged_group [
				"summaries"
			] = merged_summaries
			merged_group [
				"contracts"
			] = merged_contracts
			merged_group [
				"contract_ids"
			] = merged_contract_ids
			merged_group [
				"count"
			] = maxi(
				int(
					group.get(
						"count",
						0
					)
				),
				existing_contract_ids.size()
			)
			merged_group [
				"max_urgency"
			] = maxf(
				float(
					merged_group.get(
						"max_urgency",
						0.0
					)
				),
				float(
					group.get(
						"max_urgency",
						0.0
					)
				)
			)

			active_category_groups [
				group_key
			] = merged_group

	var group_keys: Array = (
		active_category_groups.keys()
	)
	group_keys.sort_custom(
		Callable(
			self,
			"_sort_pending_viewer_category_keys"
		)
	)

	for raw_key in group_keys:
		var group_key: String = str(
			raw_key
		)
		var group: Dictionary = (
			active_category_groups.get(
				group_key,
				{}
			)
		)
		var group_count: int = int(
			group.get(
				"count",
				0
			)
		)

		if group_count <= 0:
			group_count = (
				(
					group.get(
						"contracts",
						[]
					) as Array
				).size()
				if typeof(
					group.get(
						"contracts",
						[]
					)
				) == TYPE_ARRAY
				else 0
			)

		if group_count <= 0:
			continue

		var btn:= Button.new()
		btn.text = "%s (%d)" % [
			str(
				group.get(
					"label",
					_pending_viewer_category_label(
						group_key
					)
				)
			),
			group_count
		]
		btn.tooltip_text = str(
			group.get(
				"tooltip",
				"Open this category."
			)
		)
		btn.custom_minimum_size = Vector2(
			0,
			60
		)
		btn.size_flags_horizontal = (
			Control.SIZE_EXPAND_FILL
		)
		btn.focus_mode = (
			Control.FOCUS_ALL
		)

		_apply_button_visual_context(
			btn,
			group_key,
			era_name,
			float(
				group.get(
					"max_urgency",
					urgency
				)
			),
			false
		)

		btn.pressed.connect(
			_on_pending_category_button_pressed.bind(
				group_key
			)
		)

		list_box.add_child(
			btn
		)

	if list_box.get_child_count() == 0:
		var empty:= Label.new()
		empty.text = (
			"No unresolved situations right now."
		)
		empty.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_CENTER
		)
		empty.add_theme_font_size_override(
			"font_size",
			18
		)
		empty.add_theme_color_override(
			"font_color",
			Color(
				0.96,
				0.92,
				0.82,
				1.0
			)
		)
		list_box.add_child(
			empty
		)

	set_meta(
		"prepainted_actor_id",
		int(
			payload.get(
				"actor_id",
				-1
			)
		)
	)
	set_meta(
		"prepainted_payload_revision",
		str(
			payload.get(
				"renderer_payload_revision",
				payload.get(
					"built_at_ms",
					hash(payload)
				)
			)
		)
	)
	set_meta(
		"prepainted_pending_count",
		count
	)
	set_meta(
		"pending_list_composed_before_click",
		not reveal_surface
	)
	set_meta(
		"pending_category_groups_hot",
		not active_category_groups.is_empty()
	)
	set_meta(
		"pending_active_contracts_hot",
		not active_contracts.is_empty()
	)

	visible = reveal_surface
	mouse_filter = (
		Control.MOUSE_FILTER_STOP
		if reveal_surface
		else Control.MOUSE_FILTER_IGNORE
	)

	if reveal_surface:
		show()
	else:
		hide()
func present_contract(contract: Dictionary) -> void:
	_build_ui()
	_set_pending_viewer_overview_scroller_mode(false)

	var contract_id: String = str(contract.get("id", "")).strip_edges()
	if contract_id == "":
		return

	current_contract_id = contract_id
	active_contracts [contract_id] = contract.duplicate(true)

	visible = true
	show()

	var era_name: String = str(contract.get("era_name", "Modern Era"))
	var category: String = str(contract.get("category", "general"))
	var urgency: float = float(contract.get("urgency", 0.0))

	_apply_visual_context(category, era_name, urgency, "contract")

	var description_text: String = _pending_contract_primary_description(contract)

	title_label.text = str(contract.get("title", "Pending Situation"))
	body_label.custom_minimum_size = Vector2(0, 118)
	body_label.clear()
	body_label.append_text(description_text)

	_clear_container(list_box)
	_clear_container(options_box)

	var options: Array = contract.get("response_options", []) if typeof(contract.get("response_options", [])) == TYPE_ARRAY else []
	for raw_option in options:
		if typeof(raw_option) != TYPE_DICTIONARY:
			continue

		var option: Dictionary = raw_option as Dictionary
		var option_id: String = str(option.get("id", "")).strip_edges()
		if option_id == "":
			continue

		var btn:= Button.new()
		btn.text = str(option.get("label", option_id.capitalize()))
		btn.custom_minimum_size = Vector2(0, 58)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.focus_mode = Control.FOCUS_ALL
		_apply_button_visual_context(btn, category, era_name, urgency, true)
		btn.pressed.connect(_on_option_button_pressed.bind(contract_id, option_id))
		options_box.add_child(btn)
func _set_pending_viewer_overview_scroller_mode(enabled: bool) -> void:
	if list_box == null or not is_instance_valid(list_box):
		return

	var scroll_parent: Node = list_box.get_parent()
	if scroll_parent == null or not is_instance_valid(scroll_parent):
		return

	if scroll_parent is Control:
		var scroll_control: Control = scroll_parent as Control
		scroll_control.visible = enabled
		scroll_control.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
		scroll_control.size_flags_vertical = Control.SIZE_EXPAND_FILL if enabled else Control.SIZE_SHRINK_BEGIN
		scroll_control.custom_minimum_size = Vector2(0, 240) if enabled else Vector2(0, 0)


func _pending_contract_primary_description(
	contract: Dictionary
) -> String:
	var overview_text: String = str(
		contract.get(
			"overview",
			""
		)
	).strip_edges()
	var details_text: String = str(
		contract.get(
			"details",
			""
		)
	).strip_edges()

	if (
		overview_text != ""
		and details_text != ""
		and overview_text != details_text
	):
		return "%s\n\n%s" % [
			overview_text,
			details_text
		]

	if overview_text != "":
		return overview_text

	if details_text != "":
		return details_text

	return str(
		contract.get(
			"title",
			"Pending Situation"
		)
	).strip_edges()
func _on_pending_category_button_pressed(category_key: String) -> void:
	_render_pending_category_overview(str(category_key).strip_edges())


func _on_pending_category_back_pressed() -> void:
	present_list(last_list_payload)


func _render_pending_category_overview(
	category_key: String
) -> void:
	_build_ui()

	_set_pending_viewer_overview_scroller_mode(
		true
	)

	var clean_key: String = str(
		category_key
	).strip_edges().to_lower()

	if clean_key == "":
		return

	if active_category_groups.is_empty():
		active_category_groups = (
			_pending_viewer_category_groups_from_payload(
				last_list_payload,
				str(
					last_list_payload.get(
						"era_name",
						"Modern Era"
					)
				)
			)
		)

	if not active_category_groups.has(
		clean_key
	):
		var payload_category_groups_raw: Variant = (
			last_list_payload.get(
				"category_groups",
				[]
			)
		)

		if typeof(payload_category_groups_raw) == TYPE_ARRAY:
			for raw_group in payload_category_groups_raw:
				if typeof(raw_group) != TYPE_DICTIONARY:
					continue

				var payload_group: Dictionary = (
					raw_group as Dictionary
				).duplicate(true)
				var group_key: String = str(
					payload_group.get(
						"key",
						payload_group.get(
							"category",
							""
						)
					)
				).strip_edges().to_lower()

				if group_key == "":
					continue

				if not active_category_groups.has(
					group_key
				):
					active_category_groups [
						group_key
					] = {
						"key": group_key,
						"label": str(
							payload_group.get(
								"label",
								_pending_viewer_category_label(
									group_key
								)
							)
						),
						"count": int(
							payload_group.get(
								"count",
								0
							)
						),
						"max_urgency": float(
							payload_group.get(
								"max_urgency",
								0.0
							)
						),
						"era_name": str(
							last_list_payload.get(
								"era_name",
								"Modern Era"
							)
						),
						"contract_ids": (
							payload_group.get(
								"contract_ids",
								[]
							)
							if typeof(
								payload_group.get(
									"contract_ids",
									[]
								)
							) == TYPE_ARRAY
							else []
						),
						"contracts": (
							payload_group.get(
								"contracts",
								[]
							)
							if typeof(
								payload_group.get(
									"contracts",
									[]
								)
							) == TYPE_ARRAY
							else []
						),
						"summaries": (
							payload_group.get(
								"summaries",
								[]
							)
							if typeof(
								payload_group.get(
									"summaries",
									[]
								)
							) == TYPE_ARRAY
							else []
						),
						"tooltip": str(
							payload_group.get(
								"tooltip",
								"Open %s pending situations."
								% _pending_viewer_category_label(
									group_key
								)
							)
						)
					}

	if not active_category_groups.has(
		clean_key
	):
		current_category_key = ""
		title_label.text = "Pending Situations"
		body_label.custom_minimum_size = Vector2(
			0,
			64
		)
		body_label.clear()
		body_label.append_text(
			"This category is not resident in the current pending-situations payload."
		)
		_clear_container(
			list_box
		)
		_clear_container(
			options_box
		)

		var missing_group_back_btn:= Button.new()
		missing_group_back_btn.text = "← Back to Categories"
		missing_group_back_btn.custom_minimum_size = Vector2(
			0,
			48
		)
		missing_group_back_btn.size_flags_horizontal = (
			Control.SIZE_EXPAND_FILL
		)
		missing_group_back_btn.focus_mode = Control.FOCUS_ALL
		missing_group_back_btn.pressed.connect(
			_on_pending_category_back_pressed
		)
		list_box.add_child(
			missing_group_back_btn
		)

		set_meta(
			"pending_category_click_rejected_missing_group",
			true
		)
		set_meta(
			"pending_category_click_rejected_key",
			clean_key
		)
		set_meta(
			"pending_category_click_engine_calls",
			false
		)
		set_meta(
			"pending_category_click_build_on_click",
			false
		)

		visible = true
		mouse_filter = Control.MOUSE_FILTER_STOP
		show()
		return

	current_category_key = clean_key

	var selected_group: Dictionary = (
		active_category_groups.get(
			clean_key,
			{}
		)
	)
	var era_name: String = str(
		selected_group.get(
			"era_name",
			last_list_payload.get(
				"era_name",
				"Modern Era"
			)
		)
	)
	var group_label: String = str(
		selected_group.get(
			"label",
			_pending_viewer_category_label(
				clean_key
			)
		)
	)
	var urgency: float = float(
		selected_group.get(
			"max_urgency",
			0.0
		)
	)

	_apply_visual_context(
		clean_key,
		era_name,
		urgency,
		"list"
	)

	title_label.text = "%s (%d)" % [
		group_label,
		int(
			selected_group.get(
				"count",
				0
			)
		)
	]
	body_label.custom_minimum_size = Vector2(
		0,
		56
	)
	body_label.clear()
	body_label.append_text(
		"Choose a situation overview to inspect fully."
	)

	_clear_container(
		list_box
	)
	_clear_container(
		options_box
	)

	var category_back_btn:= Button.new()
	category_back_btn.text = "← Back to Categories"
	category_back_btn.custom_minimum_size = Vector2(
		0,
		48
	)
	category_back_btn.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	category_back_btn.focus_mode = Control.FOCUS_ALL

	_apply_button_visual_context(
		category_back_btn,
		clean_key,
		era_name,
		urgency,
		false
	)

	category_back_btn.pressed.connect(
		_on_pending_category_back_pressed
	)

	list_box.add_child(
		category_back_btn
	)

	var contracts: Array = (
		selected_group.get(
			"contracts",
			[]
		)
		if typeof(
			selected_group.get(
				"contracts",
				[]
			)
		) == TYPE_ARRAY
		else []
	)

	if contracts.is_empty():
		var summary_rows: Array = (
			selected_group.get(
				"summaries",
				[]
			)
			if typeof(
				selected_group.get(
					"summaries",
					[]
				)
			) == TYPE_ARRAY
			else []
		)

		for raw_summary in summary_rows:
			if typeof(raw_summary) != TYPE_DICTIONARY:
				continue

			var summary: Dictionary = (
				raw_summary as Dictionary
			).duplicate(true)
			var summary_id: String = str(
				summary.get(
					"view_contract_id",
					summary.get(
						"id",
						summary.get(
							"source_contract_id",
							""
						)
					)
				)
			).strip_edges()

			if summary_id == "":
				continue

			summary ["id"] = summary_id
			summary ["contract_id"] = str(
				summary.get(
					"contract_id",
					summary_id
				)
			)
			summary ["category"] = clean_key
			summary ["era_name"] = era_name
			summary ["view_contract"] = true
			summary ["surface_role"] = "full_pending_situation"
			summary ["ui_is_renderer_only"] = true

			contracts.append(
				summary
			)

	for raw_contract in contracts:
		if typeof(raw_contract) != TYPE_DICTIONARY:
			continue

		var contract: Dictionary = (
			raw_contract as Dictionary
		).duplicate(true)
		var contract_id: String = str(
			contract.get(
				"id",
				contract.get(
					"view_contract_id",
					contract.get(
						"contract_id",
						""
					)
				)
			)
		).strip_edges()

		if contract_id == "":
			continue

		contract ["id"] = contract_id
		contract ["contract_id"] = str(
			contract.get(
				"contract_id",
				contract_id
			)
		)
		contract ["category"] = clean_key
		contract ["era_name"] = era_name
		contract ["surface_role"] = "full_pending_situation"
		contract ["view_contract"] = true
		contract ["ui_is_renderer_only"] = true

		active_contracts [
			contract_id
		] = contract.duplicate(true)

		var btn:= Button.new()
		btn.text = "• %s" % str(
			contract.get(
				"title",
				"Pending Situation"
			)
		)
		btn.tooltip_text = str(
			contract.get(
				"overview",
				""
			)
		)
		btn.custom_minimum_size = Vector2(
			0,
			58
		)
		btn.size_flags_horizontal = (
			Control.SIZE_EXPAND_FILL
		)
		btn.focus_mode = Control.FOCUS_ALL

		_apply_button_visual_context(
			btn,
			clean_key,
			era_name,
			float(
				contract.get(
					"urgency",
					urgency
				)
			),
			false
		)

		btn.pressed.connect(
			_on_contract_button_pressed.bind(
				contract_id
			)
		)

		list_box.add_child(
			btn
		)

	if contracts.is_empty():
		var empty:= Label.new()
		empty.text = "No unresolved situations in this category."
		empty.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_CENTER
		)
		empty.add_theme_font_size_override(
			"font_size",
			18
		)
		empty.add_theme_color_override(
			"font_color",
			Color(
				0.96,
				0.92,
				0.82,
				1.0
			)
		)
		list_box.add_child(
			empty
		)

	set_meta(
		"pending_category_click_opened",
		true
	)
	set_meta(
		"pending_category_click_opened_key",
		clean_key
	)
	set_meta(
		"pending_category_click_engine_calls",
		false
	)
	set_meta(
		"pending_category_click_build_on_click",
		false
	)

	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	show()

func _pending_viewer_category_groups_from_payload(
	payload: Dictionary,
	era_name: String
) -> Dictionary:
	var groups: Dictionary = {}
	var contracts_raw: Variant = payload.get(
		"contracts",
		[]
	)

	if typeof(contracts_raw) != TYPE_ARRAY:
		return groups

	for raw_contract in contracts_raw:
		if typeof(raw_contract) != TYPE_DICTIONARY:
			continue

		var contract: Dictionary = (
			raw_contract as Dictionary
		).duplicate(true)
		var contract_id: String = (
			_pending_viewer_contract_identity(
				contract
			)
		)

		if contract_id == "":
			continue

		var category_key: String = (
			_pending_viewer_category_key_for_contract(
				contract
			)
		)

		contract [
			"id"
		] = contract_id
		contract [
			"contract_id"
		] = str(
			contract.get(
				"contract_id",
				contract_id
			)
		)
		contract [
			"view_contract_id"
		] = str(
			contract.get(
				"view_contract_id",
				contract_id
			)
		)
		contract [
			"category"
		] = category_key
		contract [
			"era_name"
		] = str(
			contract.get(
				"era_name",
				era_name
			)
		)

		if not groups.has(
			category_key
		):
			groups [
				category_key
			] = {
				"key": category_key,
				"label": (
					_pending_viewer_category_label(
						category_key
					)
				),
				"count": 0,
				"max_urgency": 0.0,
				"era_name": era_name,
				"contract_ids": [],
				"contracts": [],
				"summaries": [],
				"tooltip": (
					"Open %s pending situations."
					% _pending_viewer_category_label(
						category_key
					)
				)
			}

		var group: Dictionary = (
			groups [
				category_key
			]
		)
		var contract_ids: Array = (
			group.get(
				"contract_ids",
				[]
			)
			if typeof(
				group.get(
					"contract_ids",
					[]
				)
			) == TYPE_ARRAY
			else []
		)

		if contract_id in contract_ids:
			continue

		contract_ids.append(
			contract_id
		)

		var group_contracts: Array = (
			group.get(
				"contracts",
				[]
			)
			if typeof(
				group.get(
					"contracts",
					[]
				)
			) == TYPE_ARRAY
			else []
		)

		group_contracts.append(
			contract.duplicate(true)
		)

		group [
			"contract_ids"
		] = contract_ids
		group [
			"contracts"
		] = group_contracts
		group [
			"count"
		] = contract_ids.size()
		group [
			"max_urgency"
		] = maxf(
			float(
				group.get(
					"max_urgency",
					0.0
				)
			),
			float(
				contract.get(
					"urgency",
					0.0
				)
			)
		)

		groups [
			category_key
		] = group

	return groups

func _sort_pending_viewer_category_keys(a, b) -> bool:
	var key_a: String = str(a)
	var key_b: String = str(b)
	var priority_a: int = _pending_viewer_category_priority(key_a)
	var priority_b: int = _pending_viewer_category_priority(key_b)

	if priority_a == priority_b:
		var urgency_a: float = float((active_category_groups.get(key_a, {}) as Dictionary).get("max_urgency", 0.0))
		var urgency_b: float = float((active_category_groups.get(key_b, {}) as Dictionary).get("max_urgency", 0.0))
		if urgency_a == urgency_b:
			return _pending_viewer_category_label(key_a) < _pending_viewer_category_label(key_b)
		return urgency_a > urgency_b

	return priority_a < priority_b


func _pending_viewer_category_priority(category_key: String) -> int:
	match str(category_key).strip_edges().to_lower():
		"deaths":
			return 0
		"danger":
			return 1
		"health":
			return 2
		"money":
			return 3
		"family":
			return 4
		"relationships":
			return 5
		"children":
			return 6
		"school":
			return 7
		"career":
			return 8
		"housing":
			return 9
		"belongings":
			return 10
		"legal":
			return 11
		"crime":
			return 12
		"romance":
			return 13
		"sports":
			return 14
		"royalty":
			return 15
		"supernatural":
			return 16
		"travel":
			return 17
		"world":
			return 18
		"social":
			return 19
		_:
			return 99


func _pending_viewer_category_key_for_contract(contract: Dictionary) -> String:
	var explicit_key: String = _pending_viewer_explicit_category_key(contract)
	if explicit_key != "":
		return explicit_key

	var category: String = str(contract.get("category", "")).strip_edges().to_lower()
	var request: String = str(contract.get("request", "")).strip_edges().to_lower()
	var title: String = str(contract.get("title", "")).strip_edges().to_lower()
	var overview: String = str(contract.get("overview", "")).strip_edges().to_lower()
	var details: String = str(contract.get("details", "")).strip_edges().to_lower()

	var joined: String = "%s %s %s %s %s" % [category, request, title, overview, details]

	if joined.find("somebody has died") >= 0 or _pending_viewer_text_has_any(joined, ["death", "funeral", "burial", "died", "dead", "grave"]):
		return "deaths"

	if joined.find("inheritance received") >= 0 \
or joined.find("left you") >= 0 \
or joined.find("in their will") >= 0 \
or joined.find("in the will") >= 0 \
or _pending_viewer_text_has_any(joined, ["inheritance", "finance", "finances", "bank", "loan", "debt", "cash", "payroll"]):
		return "money"

	if _pending_viewer_text_has_any(joined, ["medical", "health", "illness", "injury", "disease", "sick", "doctor", "hospital"]):
		return "health"

	if _pending_viewer_text_has_any(joined, ["danger", "threat", "safety", "war", "attack", "raid", "violence"]):
		return "danger"

	if _pending_viewer_text_has_any(joined, ["family", "parent", "parents", "sibling", "newborn", "guardian", "crib", "mother", "father"]):
		return "family"

	if _pending_viewer_text_has_any(joined, ["relationship", "friend", "neighbor", "bond"]):
		return "relationships"

	if _pending_viewer_text_has_any(joined, ["child", "baby", "pregnancy", "toddler"]):
		return "children"

	if _pending_viewer_text_has_any(joined, ["school", "teacher", "student", "classroom", "academy"]):
		return "school"

	if _pending_viewer_text_has_any(joined, ["career", "job", "work", "promotion", "boss"]):
		return "career"

	if _pending_viewer_text_has_any(joined, ["house", "home", "rent", "property, housing", "shelter"]):
		return "housing"

	if _pending_viewer_text_has_any(joined, ["belonging", "belongings", "item", "inventory"]):
		return "belongings"

	if _pending_viewer_text_has_any(joined, ["legal", "court", "law", "trial"]):
		return "legal"

	if _pending_viewer_text_has_any(joined, ["crime", "police", "jail", "prison"]):
		return "crime"

	if _pending_viewer_text_has_any(joined, ["romance", "partner", "date", "marriage", "spouse"]):
		return "romance"

	if _pending_viewer_text_has_any(joined, ["boxing", "sport", "fight", "gym"]):
		return "sports"

	if _pending_viewer_text_has_any(joined, ["crown", "royal", "realm", "king", "queen", "throne"]):
		return "royalty"

	if _pending_viewer_text_has_any(joined, ["avatar", "bending", "power", "super", "magic", "stone"]):
		return "supernatural"

	if _pending_viewer_text_has_any(joined, ["travel", "trip", "journey"]):
		return "travel"

	if _pending_viewer_text_has_any(joined, ["world", "country", "nation", "village", "city"]):
		return "world"

	if _pending_viewer_text_has_any(joined, ["social", "party", "public", "crowd"]):
		return "social"

	return "general"
func _pending_viewer_explicit_category_key(contract: Dictionary) -> String:
	var field_order: Array = [
		"pending_category",
		"category_group",
		"category_key",
		"category"
	]

	for raw_field in field_order:
		var field: String = str(raw_field)
		var raw_value: String = str(contract.get(field, "")).strip_edges().to_lower()
		var normalized: String = _pending_viewer_normalized_category_key(raw_value)
		if normalized != "":
			return normalized

	return ""


func _pending_viewer_normalized_category_key(raw_category: String) -> String:
	var key: String = str(raw_category).strip_edges().to_lower()
	if key == "":
		return ""

	match key:
		"death", "deaths", "family_death", "family_death_notice", "family_death_pending", "funeral", "burial":
			return "deaths"
		"money", "finance", "finances", "family_finance", "family_finance_argument", "inheritance", "bank", "loan", "debt":
			return "money"
		"family", "family_newborn", "newborn", "newborn_attention", "newborn_sibling_attention", "family_pressure", "household":
			return "family"
		"relationship", "relationships", "friendship", "friends", "neighbors":
			return "relationships"
		"health", "medical", "illness", "injury":
			return "health"
		"danger", "safety", "threat":
			return "danger"
		"children", "child", "baby", "pregnancy":
			return "children"
		"school", "education":
			return "school"
		"career", "job", "work":
			return "career"
		"housing", "property", "home":
			return "housing"
		"belongings", "inventory", "items":
			return "belongings"
		"legal", "law", "court":
			return "legal"
		"crime", "criminal":
			return "crime"
		"romance", "dating", "marriage":
			return "romance"
		"sports", "boxing", "gym":
			return "sports"
		"royalty", "crown", "realm":
			return "royalty"
		"supernatural", "powers", "power", "bending", "avatar":
			return "supernatural"
		"travel":
			return "travel"
		"world":
			return "world"
		"social":
			return "social"
		"general":
			return "general"
		_:
			return ""


func _pending_viewer_text_has_any(text: String, needles: Array) -> bool:
	var normalized: String = (" %s " % str(text).strip_edges().to_lower())
	normalized = normalized.replace("_", " ")
	normalized = normalized.replace("-", " ")
	normalized = normalized.replace(".", " ")
	normalized = normalized.replace(",", " ")
	normalized = normalized.replace("!", " ")
	normalized = normalized.replace("?", " ")
	normalized = normalized.replace(":", " ")
	normalized = normalized.replace(";", " ")
	normalized = normalized.replace("\"", " ")
	normalized = normalized.replace("'", " ")

	while normalized.find("  ") >= 0:
		normalized = normalized.replace("  ", " ")

	for raw_needle in needles:
		var needle: String = str(raw_needle).strip_edges().to_lower()
		if needle == "":
			continue

		var padded_needle: String = " %s " % needle
		if normalized.find(padded_needle) >= 0:
			return true

	return false

func _pending_viewer_category_label(category_key: String) -> String:
	match str(category_key).strip_edges().to_lower():
		"deaths":
			return "Deaths"
		"money":
			return "Money"
		"health":
			return "Health"
		"danger":
			return "Danger"
		"family":
			return "Family"
		"relationships":
			return "Relationships"
		"children":
			return "Children"
		"school":
			return "School"
		"career":
			return "Career"
		"housing":
			return "Housing"
		"belongings":
			return "Belongings"
		"legal":
			return "Legal"
		"crime":
			return "Crime"
		"romance":
			return "Romance"
		"sports":
			return "Sports"
		"royalty":
			return "Royalty"
		"supernatural":
			return "Powers & Supernatural"
		"travel":
			return "Travel"
		"world":
			return "World"
		"social":
			return "Social"
		_:
			return "General"
func _on_contract_button_pressed(contract_id: String) -> void:
	var clean_id: String = str(contract_id).strip_edges()
	if clean_id == "":
		return

	emit_signal("contract_selected", clean_id)

func _on_option_button_pressed(contract_id: String, option_id: String) -> void:
	emit_signal("option_selected", contract_id, option_id)


func _on_close_pressed() -> void:
	hide()
	visible = false
	current_contract_id = ""
	current_category_key = ""
	active_category_groups.clear()
	emit_signal("viewer_closed")

func _apply_visual_context(category: String, era_name: String, urgency: float, surface_mode: String = "list") -> void:
	var category_color: Color = _category_color(category)
	var era_color: Color = _era_color(era_name)
	var cream: Color = Color(1.0, 0.91, 0.72, 1.0)
	var accent: Color = category_color.lerp(era_color, 0.38)
	var pressure: float = clamp(urgency / 100.0, 0.0, 1.0)

	if dim != null:
		dim.color = Color(0.0, 0.0, 0.0, 0.62 + pressure * 0.16)

	if card != null:
		var style:= StyleBoxFlat.new()
		style.bg_color = _era_panel_base_color(era_name).lerp(category_color, 0.1 + pressure * 0.06)
		style.border_color = accent.lerp(cream, 0.22)
		style.set_border_width_all(3 if surface_mode == "list" else 4)
		style.set_corner_radius_all(24 if surface_mode == "list" else 28)
		style.shadow_color = accent.darkened(0.45)
		style.shadow_size = 24 + int(pressure * 14.0)
		style.shadow_offset = Vector2(0, 10)
		style.content_margin_left = 0
		style.content_margin_right = 0
		style.content_margin_top = 0
		style.content_margin_bottom = 0
		card.add_theme_stylebox_override("panel", style)
		card.custom_minimum_size = Vector2(760, 460) if surface_mode == "list" else Vector2(800, 500)

	if title_label != null:
		title_label.add_theme_color_override("font_color", cream.lerp(Color.WHITE, 0.35))
		title_label.add_theme_font_size_override("font_size", 27 if surface_mode == "list" else 29)

	if body_label != null:
		body_label.add_theme_color_override("default_color", Color(0.96, 0.94, 0.88, 1.0))

	if footer_label != null:
		footer_label.add_theme_color_override("font_color", cream.lerp(accent, 0.32))
		footer_label.add_theme_font_size_override("font_size", 14)


func _apply_button_visual_context(btn: Button, category: String, era_name: String, urgency: float, is_action_choice: bool = false) -> void:
	if btn == null:
		return

	var cream: Color = Color(1.0, 0.91, 0.72, 1.0)
	var accent: Color = _category_color(category).lerp(_era_color(era_name), 0.34)
	var pressure: float = clamp(urgency / 100.0, 0.0, 1.0)

	var base_bg: Color = _era_panel_base_color(era_name).lerp(accent, 0.14)
	var hover_bg: Color = _era_panel_base_color(era_name).lerp(accent, 0.24)
	var pressed_bg: Color = _era_panel_base_color(era_name).lerp(accent, 0.32)

	var normal_border: Color = accent.lerp(cream, 0.18)
	var hover_border: Color = cream
	var pressed_border: Color = cream.lerp(accent, 0.2)

	btn.add_theme_color_override("font_color", Color(1.0, 0.96, 0.86, 1.0))
	btn.add_theme_font_size_override("font_size", 18 if is_action_choice else 17)

	btn.add_theme_stylebox_override("normal", _pending_button_style(base_bg, normal_border, 2, 6, Color(0.0, 0.0, 0.0, 0.22)))
	btn.add_theme_stylebox_override("hover", _pending_button_style(hover_bg, hover_border, 5 if is_action_choice else 4, 18 if is_action_choice else 12, cream))
	btn.add_theme_stylebox_override("pressed", _pending_button_style(pressed_bg, pressed_border, 5, 12 + int(pressure * 6.0), cream.lerp(accent, 0.35)))
	btn.add_theme_stylebox_override("focus", _pending_button_style(hover_bg, hover_border, 5, 16, cream))


func _pending_button_style(bg: Color, border: Color, border_width: int, shadow_size: int, shadow_color: Color) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(16)
	style.shadow_color = shadow_color
	style.shadow_size = shadow_size
	style.shadow_offset = Vector2(0, 3)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _dominant_category_from_payload(payload: Dictionary) -> String:
	var contracts: Array = payload.get("contracts", []) if typeof(payload.get("contracts", [])) == TYPE_ARRAY else []
	var best_category: String = "general"
	var best_urgency: float = -1.0

	for raw_contract in contracts:
		if typeof(raw_contract) != TYPE_DICTIONARY:
			continue

		var contract: Dictionary = raw_contract as Dictionary
		var urgency: float = float(contract.get("urgency", 0.0))
		if urgency > best_urgency:
			best_urgency = urgency
			best_category = str(contract.get("category", "general"))

	return best_category


func _dominant_urgency_from_payload(payload: Dictionary) -> float:
	var contracts: Array = payload.get("contracts", []) if typeof(payload.get("contracts", [])) == TYPE_ARRAY else []
	var best_urgency: float = 0.0

	for raw_contract in contracts:
		if typeof(raw_contract) != TYPE_DICTIONARY:
			continue

		best_urgency = max(best_urgency, float((raw_contract as Dictionary).get("urgency", 0.0)))

	return best_urgency


func _category_color(category: String) -> Color:
	var key: String = str(category).strip_edges().to_lower()

	if key.find("finance") >= 0 or key.find("debt") >= 0 or key.find("money") >= 0:
		return Color(0.96, 0.7, 0.2, 1.0)
	if key.find("family") >= 0 or key.find("newborn") >= 0 or key.find("relationship") >= 0:
		return Color(1.0, 0.34, 0.44, 1.0)
	if key.find("medical") >= 0 or key.find("health") >= 0:
		return Color(0.28, 0.95, 0.7, 1.0)
	if key.find("danger") >= 0 or key.find("threat") >= 0 or key.find("safety") >= 0:
		return Color(1.0, 0.24, 0.16, 1.0)
	if key.find("school") >= 0:
		return Color(0.38, 0.62, 1.0, 1.0)

	return Color(0.74, 0.58, 1.0, 1.0)


func _era_color(era_name: String) -> Color:
	var key: String = str(era_name).strip_edges().to_lower()

	if key.find("ancient") >= 0:
		return Color(0.95, 0.56, 0.2, 1.0)
	if key.find("medieval") >= 0:
		return Color(0.58, 0.38, 0.95, 1.0)
	if key.find("industrial") >= 0:
		return Color(0.78, 0.58, 0.36, 1.0)
	if key.find("future") >= 0:
		return Color(0.18, 0.92, 1.0, 1.0)

	return Color(0.3, 0.52, 1.0, 1.0)


func _era_panel_base_color(era_name: String) -> Color:
	var key: String = str(era_name).strip_edges().to_lower()

	if key.find("ancient") >= 0:
		return Color(0.12, 0.075, 0.035, 0.96)
	if key.find("medieval") >= 0:
		return Color(0.055, 0.035, 0.105, 0.96)
	if key.find("industrial") >= 0:
		return Color(0.095, 0.075, 0.055, 0.96)
	if key.find("future") >= 0:
		return Color(0.025, 0.055, 0.075, 0.96)

	return Color(0.035, 0.045, 0.075, 0.96)
func _clear_container(container: Container) -> void:
	if container == null:
		return
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()