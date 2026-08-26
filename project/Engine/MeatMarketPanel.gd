extends PanelContainer
class_name MeatMarketPanel

signal close_requested
signal add_listing_requested(listing_id: String, quantity: int)
signal checkout_requested

const PANEL_SCHEMA:= "eralife.market.meat_market_panel"
const CONTRACT_VERSION:= 1

var host: Node = null
var gs: GameState = null
var actor: Person = null
var active_contract: Dictionary = {}

var title_label: Label = null
var subtitle_label: Label = null
var basket_label: Label = null
var status_label: Label = null
var card_grid: HFlowContainer = null
var checkout_button: Button = null
var checkout_badge_label: Label = null
func _ready() -> void:
	_ensure_surface()


func bind_host(_host: Node, _gs: GameState = null) -> void:
	host = _host
	gs = _gs
	_ensure_surface()


func bind_game_state(_gs: GameState) -> void:
	gs = _gs


func open_for_actor(target_actor: Person, surface_contract: Dictionary = {}) -> void:
	actor = target_actor
	_ensure_surface()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	render_surface_contract(surface_contract)
func begin_resident_surface_stream(
		target_actor: Person,
		surface_contract: Dictionary
) -> void:
	actor = target_actor
	_ensure_surface()

	active_contract = (
		_normalized_surface_contract(
			surface_contract
		)
	)

	_apply_shell_contract(
		active_contract
	)
	_render_basket(
		active_contract
	)
	_clear_children(
		card_grid
	)

	status_label.text = (
		"Market cards are publishing live…"
	)

	set_meta(
		"meat_market_resident_stream_active",
		true
	)
	set_meta(
		"meat_market_resident_stream_rendered_cards",
		0
	)
	set_meta(
		"meat_market_resident_stream_target_cards",
		_safe_array(
			active_contract.get(
				"food_card_contracts",
				[]
			)
		).size()
	)


func append_resident_food_card_contract(
	card_contract: Dictionary
) -> void:
	_ensure_surface()

	if card_contract.is_empty():
		return

	card_grid.add_child(
		_build_food_card(
			card_contract
		)
	)

	set_meta(
		"meat_market_resident_stream_rendered_cards",
		int(
			get_meta(
				"meat_market_resident_stream_rendered_cards",
				0
			)
		) + 1
	)

func finish_resident_surface_stream() -> void:
	_ensure_surface()

	if card_grid.get_child_count() <= 0:
		status_label.text = (
			"No market food cards are hot for this era."
		)
	else:
		status_label.text = ""

	set_meta(
		"meat_market_resident_stream_active",
		false
	)
	set_meta(
		"meat_market_resident_stream_complete",
		true
	)
	set_meta(
		"meat_market_resident_stream_completed_at_ms",
		int(
			Time.get_ticks_msec()
		)
	)


func apply_basket_projection(
		basket_contract: Dictionary
) -> void:
	_ensure_surface()

	if basket_contract.is_empty():
		return

	if basket_contract.has(
		"basket"
	):
		active_contract ["basket"] = (
			_safe_array(
				basket_contract.get(
					"basket",
					[]
				)
			)
		)

	if basket_contract.has(
		"basket_total"
	):
		active_contract ["basket_total"] = int(
			basket_contract.get(
				"basket_total",
				0
			)
		)

	if basket_contract.has(
		"basket_total_text"
	):
		active_contract ["basket_total_text"] = str(
			basket_contract.get(
				"basket_total_text",
				""
			)
		)

	if basket_contract.has(
		"basket_item_count"
	):
		active_contract ["basket_item_count"] = int(
			basket_contract.get(
				"basket_item_count",
				0
			)
		)

	_render_basket(
		active_contract
	)

func render_surface_contract(surface_contract: Dictionary = {}) -> void:
	_ensure_surface()
	active_contract = _normalized_surface_contract(surface_contract)
	_apply_shell_contract(active_contract)
	_render_food_cards(active_contract)
	_render_basket(active_contract)


func _ensure_surface() -> void:
	if (
		title_label != null
		and is_instance_valid(title_label)
	):
		return

	name = "MeatMarketPanel"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 171
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	set_meta("schema", PANEL_SCHEMA)
	set_meta("version", CONTRACT_VERSION)
	set_meta("ui_is_renderer_only", true)
	set_meta(
		"food_card_truth_source",
		"MeatMarketContractEngine.food_card_contracts"
	)
	set_meta(
		"responsive_mosaic_renderer",
		true
	)
	set_meta(
		"card_layout_truth_owned_by_contract",
		true
	)
	set_meta(
		"meat_market_formation_renderer",
		"scrollable_compact_market_mosaic"
	)

	add_theme_stylebox_override(
		"panel",
		_panel_style()
	)

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

	var top_bar:= HBoxContainer.new()
	top_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_theme_constant_override("separation", 12)
	root.add_child(top_bar)

	var back_button:= Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(116, 42)
	back_button.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND
	)
	back_button.pressed.connect(
		func ():
			close_requested.emit()
	)
	top_bar.add_child(back_button)

	title_label = Label.new()
	title_label.text = "MEAT MARKET"
	title_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override(
		"font_size",
		32
	)
	title_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.82, 0.58, 1.0)
	)
	top_bar.add_child(title_label)

	checkout_button = Button.new()
	checkout_button.text = "Checkout"
	checkout_button.custom_minimum_size = Vector2(136, 42)
	checkout_button.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND
	)
	checkout_button.pressed.connect(
		func ():
			checkout_requested.emit()
	)
	top_bar.add_child(checkout_button)

	checkout_badge_label = Label.new()
	checkout_badge_label.text = "0"
	checkout_badge_label.visible = false
	checkout_badge_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	checkout_badge_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)
	checkout_badge_label.custom_minimum_size = Vector2(34, 28)
	checkout_badge_label.add_theme_font_size_override(
		"font_size",
		15
	)
	checkout_badge_label.add_theme_color_override(
		"font_color",
		Color(1.0, 1.0, 1.0, 1.0)
	)
	checkout_badge_label.add_theme_stylebox_override(
		"normal",
		_checkout_badge_style()
	)
	top_bar.add_child(checkout_badge_label)

	subtitle_label = Label.new()
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	subtitle_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.91, 0.78, 0.86)
	)
	root.add_child(subtitle_label)

	basket_label = Label.new()
	basket_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	basket_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	basket_label.add_theme_color_override(
		"font_color",
		Color(0.96, 1.0, 0.86, 0.86)
	)
	root.add_child(basket_label)

	var scroll:= ScrollContainer.new()
	scroll.name = "MeatMarketScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_AUTO
	)
	scroll.vertical_scroll_mode = (
		ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	)
	root.add_child(scroll)

	card_grid = HFlowContainer.new()
	card_grid.name = "MeatMarketMosaic"
	card_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card_grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card_grid.custom_minimum_size = Vector2(1240, 0)
	card_grid.alignment = FlowContainer.ALIGNMENT_CENTER
	card_grid.last_wrap_alignment = (
		FlowContainer.LAST_WRAP_ALIGNMENT_CENTER
	)
	card_grid.add_theme_constant_override(
		"h_separation",
		14
	)
	card_grid.add_theme_constant_override(
		"v_separation",
		14
	)
	card_grid.set_meta(
		"formation",
		"scrollable_compact_market_mosaic"
	)
	card_grid.set_meta(
		"truth_owner",
		"resident_food_card_contracts"
	)
	scroll.add_child(card_grid)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	status_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.88, 0.78, 0.82)
	)
	root.add_child(status_label)
func _meat_market_card_minimum_size(
	card_contract: Dictionary
) -> Vector2:
	var span: String = str(
		card_contract.get(
			"mosaic_span",
			"standard_1x1"
		)
	).strip_edges().to_lower()

	match span:
		"wide_2x1":
			return Vector2(
				342,
				222
			)

		"tall_1x2":
			return Vector2(
				236,
				278
			)

		_:
			return Vector2(
				262,
				230
			)

func _apply_shell_contract(contract: Dictionary) -> void:
	title_label.text = str(contract.get("title", "Meat Market")).to_upper()
	subtitle_label.text = str(contract.get("subtitle", ""))
	status_label.text = ""
	set_meta("meat_market_surface_contract", contract.duplicate(true))
	set_meta("meat_market_panel_truth_state", str(contract.get("truth_state", "hot")))
	set_meta("ui_builds_truth_forbidden", true)


func _render_food_cards(
	contract: Dictionary
) -> void:
	_clear_children(card_grid)

	var cards: Array = _safe_array(
		contract.get(
			"food_card_contracts",
			[]
		)
	)

	if cards.is_empty():
		cards = _food_cards_from_listings(
			_safe_array(
				contract.get(
					"listings",
					[]
				)
			),
			_safe_array(
				contract.get(
					"basket",
					[]
				)
			)
		)

	if cards.is_empty():
		cards = _fallback_food_card_contracts()

	if cards.is_empty():
		status_label.text = (
			"No market food cards are hot for this era."
		)
		return

	status_label.text = ""

	for raw_card in cards:
		var card_contract: Dictionary = (
			_safe_dictionary(raw_card)
		)

		if card_contract.is_empty():
			continue

		card_grid.add_child(
			_build_food_card(
				card_contract
			)
		)



func _build_food_card(
	card_contract: Dictionary
) -> Control:
	var card:= PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	card.custom_minimum_size = (
		_meat_market_card_minimum_size(
			card_contract
		)
	)
	card.set_meta(
		"meat_market_food_card_contract",
		card_contract.duplicate(true)
	)
	card.set_meta(
		"ui_is_renderer_only",
		true
	)
	card.add_theme_stylebox_override(
		"panel",
		_food_card_style(card_contract)
	)

	var margin:= MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var vbox:= VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 5)
	margin.add_child(vbox)

	var stall_label:= Label.new()
	stall_label.text = (
		"%s • %s"
		% [
			str(
				card_contract.get(
					"stall",
					"MARKET STALL"
				)
			).to_upper(),
			str(
				card_contract.get(
					"quality",
					"MARKET GRADE"
				)
			).to_upper()
		]
	)
	stall_label.add_theme_font_size_override(
		"font_size",
		9
	)
	stall_label.add_theme_color_override(
		"font_color",
		Color(
			1.0,
			0.72,
			0.48,
			0.78
		)
	)
	vbox.add_child(stall_label)

	var top:= HBoxContainer.new()
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_theme_constant_override("separation", 8)
	vbox.add_child(top)

	var title:= Label.new()
	title.text = str(
		card_contract.get(
			"title",
			"Market Food"
		)
	)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override(
		"font_size",
		17
	)
	title.add_theme_color_override(
		"font_color",
		Color(
			1.0,
			0.9,
			0.72,
			1.0
		)
	)
	top.add_child(title)

	var price:= Label.new()
	price.text = _format_market_money_from_contract(
		int(
			card_contract.get(
				"price",
				0
			)
		),
		card_contract
	)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price.add_theme_font_size_override(
		"font_size",
		16
	)
	price.add_theme_color_override(
		"font_color",
		Color(
			0.88,
			1.0,
			0.7,
			1.0
		)
	)
	top.add_child(price)

	var provenance:= Label.new()
	provenance.text = (
		"%s • %s"
		% [
			str(
				card_contract.get(
					"origin",
					"Local Market"
				)
			),
			str(
				card_contract.get(
					"meta_line",
					""
				)
			)
		]
	)
	provenance.text_overrun_behavior = (
		TextServer.OVERRUN_TRIM_ELLIPSIS
	)
	provenance.add_theme_font_size_override(
		"font_size",
		10
	)
	provenance.add_theme_color_override(
		"font_color",
		Color(
			1.0,
			0.76,
			0.62,
			0.74
		)
	)
	vbox.add_child(provenance)

	var desc:= Label.new()
	desc.text = str(
		card_contract.get(
			"description",
			""
		)
	)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override(
		"font_size",
		11
	)
	desc.add_theme_color_override(
		"font_color",
		Color(
			0.96,
			0.92,
			0.86,
			0.88
		)
	)
	vbox.add_child(desc)

	var max_affordable: int = int(
		card_contract.get(
			"max_affordable_quantity",
			0
		)
	)
	var default_quantity: int = max(
		1,
		int(
			card_contract.get(
				"quantity",
				1
			)
		)
	)

	if max_affordable > 0:
		default_quantity = min(
			default_quantity,
			max_affordable
		)

	var action:= Button.new()
	action.text = str(
		card_contract.get(
			"action_label",
			"Add To Basket"
		)
	)
	action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action.custom_minimum_size = Vector2(0, 34)
	action.disabled = (
		bool(
			card_contract.get(
				"disabled",
				false
			)
		)
		or max_affordable <= 0
	)
	action.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND
	)
	action.set_meta(
		"selected_quantity",
		default_quantity
	)

	var max_toggle:= CheckButton.new()
	max_toggle.text = (
		"%s X%d"
		% [
			str(
				card_contract.get(
					"display_name",
					card_contract.get(
						"title",
						"Market Food"
					)
				)
			),
			max_affordable
		]
	)
	max_toggle.disabled = (
		max_affordable <= default_quantity
	)
	max_toggle.button_pressed = false
	max_toggle.add_theme_font_size_override(
		"font_size",
		10
	)
	max_toggle.add_theme_color_override(
		"font_color",
		Color(
			1.0,
			0.86,
			0.7,
			0.88
		)
	)
	max_toggle.toggled.connect(
		func (enabled: bool):
			var selected_quantity: int = (
				max_affordable
				if enabled
				else default_quantity
			)

			action.set_meta(
				"selected_quantity",
				selected_quantity
			)

			action.text = (
				"Add X%d To Basket"
				% selected_quantity
				if selected_quantity > 1
				else str(
					card_contract.get(
						"action_label",
						"Add To Basket"
					)
				)
			)
	)
	vbox.add_child(max_toggle)

	var spacer:= Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var listing_id: String = str(
		card_contract.get(
			"listing_id",
			""
		)
	)

	action.pressed.connect(
		func ():
			add_listing_requested.emit(
				listing_id,
				max(
					1,
					int(
						action.get_meta(
							"selected_quantity",
							default_quantity
						)
					)
				)
			)
	)

	vbox.add_child(action)

	return card
func _render_basket(contract: Dictionary) -> void:
	var basket: Array = _safe_array(contract.get("basket", []))
	var total: int = int(contract.get("basket_total", 0))
	var item_count: int = int(contract.get("basket_item_count", _basket_item_count(basket)))
	var total_text: String = str(contract.get("basket_total_text", _format_market_money_from_contract(total, contract)))

	basket_label.text = "%s: %d item(s) - %s" % [
		str(contract.get("basket_name", "Basket")),
		item_count,
		total_text
	]

	if checkout_button != null:
		checkout_button.disabled = item_count <= 0
		checkout_button.text = "Checkout"

	if checkout_badge_label != null:
		checkout_badge_label.text = str(item_count)
		checkout_badge_label.visible = item_count > 0


func _normalized_surface_contract(surface_contract: Dictionary) -> Dictionary:
	var out: Dictionary = {}

	if surface_contract.is_empty():
		out = {
			"success": true,
			"schema": "eralife.market.meat_market.surface_contract",
			"version": CONTRACT_VERSION,
			"title": "Meat Market",
			"subtitle": "Live butchers, hunters, fishmongers, cooked stalls, and animal-feed scraps.",
			"basket": [],
			"basket_total": 0,
			"listings": [],
			"food_card_contracts": _fallback_food_card_contracts(),
			"truth_state": "panel_fallback_contract",
			"ui_is_renderer_only": true
		}
	else:
		out = surface_contract.duplicate(true)

	out ["schema"] = str(out.get("schema", "eralife.market.meat_market.surface_contract"))
	out ["panel_schema"] = PANEL_SCHEMA
	out ["panel_version"] = CONTRACT_VERSION
	out ["ui_is_renderer_only"] = true

	if not out.has("basket") or typeof(out.get("basket")) != TYPE_ARRAY:
		out ["basket"] = []

	if not out.has("basket_total"):
		out ["basket_total"] = 0

	if not out.has("listings") or typeof(out.get("listings")) != TYPE_ARRAY:
		out ["listings"] = []

	if not out.has("food_card_contracts") or typeof(out.get("food_card_contracts")) != TYPE_ARRAY:
		out ["food_card_contracts"] = []

	if _safe_array(out.get("food_card_contracts", [])).is_empty():
		out ["food_card_contracts"] = _food_cards_from_listings(_safe_array(out.get("listings", [])), _safe_array(out.get("basket", [])))

	if _safe_array(out.get("food_card_contracts", [])).is_empty():
		out ["food_card_contracts"] = _fallback_food_card_contracts()
		out ["truth_state"] = "panel_fallback_contract"

	return out
func _food_cards_from_listings(listings: Array, basket: Array = []) -> Array:
	var out: Array = []

	for raw_listing in listings:
		var listing: Dictionary = _safe_dictionary(raw_listing)
		if listing.is_empty():
			continue

		var listing_id: String = str(listing.get("listing_id", "")).strip_edges()
		var basket_quantity: int = _basket_quantity_for_listing(basket, listing_id)
		var price: int = int(listing.get("price", 0))

		out.append({
			"schema": "eralife.market.meat_market.food_card_contract",
			"version": CONTRACT_VERSION,
			"listing_id": listing_id,
			"title": str(listing.get("display_name", listing.get("name", "Market Food"))),
			"display_name": str(listing.get("display_name", listing.get("name", "Market Food"))),
			"description": str(listing.get("description", "")),
			"price": price,
			"price_text": _format_market_money_from_contract(price, active_contract),
			"quantity": int(listing.get("quantity", 1)),
			"category": str(listing.get("category", "Food")),
			"tags": _safe_array(listing.get("tags", [])),
			"bloodthirst_delta": int(listing.get("bloodthirst_delta", 0)),
			"basket_quantity": basket_quantity,
			"max_affordable_quantity": int(listing.get("max_affordable_quantity", 1)),
			"meta_line": _market_card_meta_line(listing, basket_quantity),
			"action_label": "Add To Basket" if basket_quantity <= 0 else "Add Another",
			"disabled": listing_id == "",
			"render_kind": "aaa_food_card",
			"truth_source": "MeatMarketPanel.contract_shape_repair",
			"ui_is_renderer_only": true
		})

	return out


func _fallback_food_card_contracts() -> Array:
	return [
		{
			"schema": "eralife.market.meat_market.food_card_contract",
			"version": CONTRACT_VERSION,
			"listing_id": "meat_scraps",
			"title": "Meat Scraps",
			"display_name": "Meat Scraps",
			"description": "Cheap scraps for dogs, cats, wolves, falcons, ravens, and other meat-eaters.",
			"price": 6,
			"quantity": 3,
			"category": "Food",
			"tags": ["meat", "pet_food", "scraps"],
			"bloodthirst_delta": 1,
			"basket_quantity": 0,
			"meta_line": "Bundle x3 - Pet food - Bloodthirst +1",
			"action_label": "Add To Basket",
			"disabled": false,
			"render_kind": "aaa_food_card",
			"truth_source": "MeatMarketPanel.fallback_surface_contract",
			"ui_is_renderer_only": true
		},
		{
			"schema": "eralife.market.meat_market.food_card_contract",
			"version": CONTRACT_VERSION,
			"listing_id": "raw_goat_meat",
			"title": "Raw Goat Meat",
			"display_name": "Raw Goat Meat",
			"description": "Raw meat fit for cooking or feeding carnivorous animals.",
			"price": 18,
			"quantity": 1,
			"category": "Food",
			"tags": ["meat", "raw_meat", "human_food", "pet_food"],
			"bloodthirst_delta": 3,
			"basket_quantity": 0,
			"meta_line": "Single portion - People + pets - Bloodthirst +3",
			"action_label": "Add To Basket",
			"disabled": false,
			"render_kind": "aaa_food_card",
			"truth_source": "MeatMarketPanel.fallback_surface_contract",
			"ui_is_renderer_only": true
		},
		{
			"schema": "eralife.market.meat_market.food_card_contract",
			"version": CONTRACT_VERSION,
			"listing_id": "raw_fish",
			"title": "Raw Fish",
			"display_name": "Raw Fish",
			"description": "Fish for people, cats, birds of prey, and scavengers.",
			"price": 12,
			"quantity": 2,
			"category": "Food",
			"tags": ["fish", "meat", "raw_meat", "human_food", "pet_food"],
			"bloodthirst_delta": 2,
			"basket_quantity": 0,
			"meta_line": "Bundle x2 - People + pets - Bloodthirst +2",
			"action_label": "Add To Basket",
			"disabled": false,
			"render_kind": "aaa_food_card",
			"truth_source": "MeatMarketPanel.fallback_surface_contract",
			"ui_is_renderer_only": true
		}
	]


func _basket_quantity_for_listing(basket: Array, listing_id: String) -> int:
	var total: int = 0
	for raw_item in basket:
		var item: Dictionary = _safe_dictionary(raw_item)
		if str(item.get("listing_id", "")).strip_edges() == listing_id:
			total += int(item.get("quantity", 1))
	return total
func _basket_item_count(basket: Array) -> int:
	var total: int = 0
	for raw_item in basket:
		var item: Dictionary = _safe_dictionary(raw_item)
		total += max(1, int(item.get("quantity", 1)))
	return total

func _format_market_money_from_contract(amount: int, source_contract: Dictionary = {}) -> String:
	var price_text: String = str(source_contract.get("price_text", "")).strip_edges()
	if price_text != "":
		return price_text

	var currency: Dictionary = source_contract.get("currency", {}) if typeof(source_contract.get("currency", {})) == TYPE_DICTIONARY else {}
	if currency.is_empty():
		currency = active_contract.get("currency", {}) if typeof(active_contract.get("currency", {})) == TYPE_DICTIONARY else {}

	var symbol: String = str(currency.get("symbol", "$")).strip_edges()
	var currency_name: String = str(currency.get("name", "")).strip_edges()

	if currency_name != "":
		return "%s%d %s" % [symbol, int(amount), currency_name]

	return "%s%d" % [symbol, int(amount)]

func _checkout_badge_style() -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.82, 0.08, 0.08, 0.96)
	style.border_color = Color(1.0, 0.82, 0.72, 0.78)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.shadow_color = Color(0.82, 0.08, 0.08, 0.42)
	style.shadow_size = 8
	return style

func _market_card_meta_line(listing: Dictionary, basket_quantity: int = 0) -> String:
	var parts: Array = []
	var quantity: int = int(listing.get("quantity", 1))
	var tags: Array = _safe_array(listing.get("tags", []))

	if quantity > 1:
		parts.append("Bundle x%d" % quantity)
	else:
		parts.append("Single portion")

	if tags.has("pet_food") and tags.has("human_food"):
		parts.append("People + pets")
	elif tags.has("pet_food"):
		parts.append("Pet food")
	elif tags.has("human_food"):
		parts.append("Human food")

	if int(listing.get("bloodthirst_delta", 0)) > 0:
		parts.append("Bloodthirst +%d" % int(listing.get("bloodthirst_delta", 0)))

	if basket_quantity > 0:
		parts.append("In basket x%d" % basket_quantity)

	return " - ".join(parts)
func _panel_style() -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.036, 0.03, 0.985)
	style.border_color = Color(0.95, 0.45, 0.24, 0.55)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.38)
	style.shadow_size = 14
	return style


func _food_card_style(card_contract: Dictionary) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	var accent: Color = Color(0.95, 0.38, 0.2, 1.0)
	var tags: Array = _safe_array(card_contract.get("tags", []))
	if tags.has("fish"):
		accent = Color(0.42, 0.78, 1.0, 1.0)
	style.bg_color = Color(0.115, 0.07, 0.055, 0.96)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.62)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.15)
	style.shadow_size = 8
	return style


func _clear_children(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		child.queue_free()


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []