extends Resource
class_name FoodRestaurantEngine

const RESTAURANT_VERSION:= 1

var gs
var restaurant_contract: Dictionary = {}
var visit_ledger: Array = []
var restaurant_carts_by_actor_id: Dictionary = {}
var restaurant_date_state_by_actor_id: Dictionary = {}
var restaurant_public_sessions_by_restaurant_id: Dictionary = {}
var last_report: Dictionary = {}

func _init(_gs = null):
	gs = _gs
	restaurant_contract = _default_restaurant_contract()

func get_restaurant_rows(context: Dictionary = {}) -> Array:
	var era_name: String = _era_name_from_context(context)
	var selected_category: String = str(context.get("restaurant_category", "")).strip_edges().to_lower()
	var selected_restaurant_id: String = str(context.get("restaurant_id", "")).strip_edges()
	var out: Array = []

	if selected_category == "":
		out.append({
			"label": "Restaurant Type",
			"description": "Choose the kind of food experience first. The room stays clean until a category opens.",
			"kind": "restaurant_category_header",
			"visual_theme": "restaurant_orange_white"
		})

		var category_rows: Array = get_restaurant_category_rows(context)
		for raw_category_row in category_rows:
			if typeof(raw_category_row) != TYPE_DICTIONARY:
				continue
			out.append(raw_category_row)

		return out

	var selected_restaurant_name: String = ""
	if selected_restaurant_id != "":
		var selected_restaurant: Dictionary = get_restaurant(selected_restaurant_id)
		if not selected_restaurant.is_empty():
			selected_restaurant_name = str(selected_restaurant.get("name", "")).strip_edges()

	var category_header_description: String = "Pick a specific place. Each restaurant carries its own dining-card theme before service options open."
	if selected_restaurant_name != "":
		category_header_description = "%s is selected. Choose a service style, preview the menu without going, or pick a different %s restaurant." % [
			selected_restaurant_name,
			_restaurant_category_label(selected_category)
		]

	out.append({
		"label": "%s Restaurants" % _restaurant_category_label(selected_category),
		"description": category_header_description,
		"kind": "restaurant_selected_category_header",
		"category": selected_category,
		"visual_theme": "restaurant_%s" % selected_category,
		"actions": [
			{
				"id": "restaurant_back:restaurant_type",
				"label": "Back to Restaurant Types",
				"kind": "packet",
				"style": "secondary"
			}
		]
	})

	var matched_count: int = 0
	for restaurant in get_restaurants_for_era(era_name):
		var restaurant_id: String = str(restaurant.get("id", "")).strip_edges()
		var category: String = _restaurant_category(restaurant)
		if category != selected_category:
			continue

		matched_count += 1

		var supports_drive_through: bool = bool(restaurant.get("supports_drive_through", false))
		var drive_text: String = "Drive-thru available" if supports_drive_through else "No drive-thru"
		var entry_fee: int = int(restaurant.get("entry_fee", 0))
		var is_selected: bool = selected_restaurant_id == restaurant_id
		var restaurant_theme: String = "restaurant_card_%d" % (abs(int(hash(restaurant_id))) % 4)

		if is_selected:
			var service_actions: Array = [
				{
					"id": "restaurant_menu:%s:dine_in" % restaurant_id,
					"label": "Dine In",
					"kind": "packet",
					"style": "success",
					"visual_theme": restaurant_theme
				},
				{
					"id": "restaurant_menu:%s:takeout" % restaurant_id,
					"label": "Takeout",
					"kind": "packet",
					"style": "secondary",
					"visual_theme": restaurant_theme
				}
			]

			if supports_drive_through:
				service_actions.append({
					"id": "restaurant_menu:%s:drive_through" % restaurant_id,
					"label": "Drive-Thru",
					"kind": "packet",
					"style": "primary",
					"visual_theme": restaurant_theme
				})

			service_actions.append({
				"id": "restaurant_preview_menu:%s" % restaurant_id,
				"label": "View menu without going",
				"kind": "packet",
				"style": "primary",
				"visual_theme": restaurant_theme
			})

			service_actions.append({
				"id": "restaurant_back:restaurant_type",
				"label": "Back to Restaurant Types",
				"kind": "packet",
				"style": "secondary"
			})

			out.append({
				"label": "✓ %s • %s • $%d+" % [
					str(restaurant.get("name", "Restaurant")),
					_restaurant_category_label(category),
					int(restaurant.get("minimum_price", 0))
				],
				"description": "%s • %s • fame gate %d%s\n\nSelected restaurant: %s. You have not started service yet — choose dine-in, takeout, drive-thru if available, or preview the menu without going." % [
					str(restaurant.get("quality", "restaurant")),
					drive_text,
					int(restaurant.get("fame_required", 0)),
					" • entry fee $%d" % entry_fee if entry_fee > 0 else "",
					str(restaurant.get("name", "Restaurant"))
				],
				"restaurant_id": restaurant_id,
				"kind": "restaurant_selected",
				"tier": str(restaurant.get("tier", "casual")),
				"category": category,
				"quality": str(restaurant.get("quality", "restaurant")),
				"minimum_price": int(restaurant.get("minimum_price", 0)),
				"supports_drive_through": supports_drive_through,
				"fame_required": int(restaurant.get("fame_required", 0)),
				"visual_theme": restaurant_theme,
				"actions": service_actions
			})
			continue

		out.append({
			"label": "%s • %s • $%d+" % [
				str(restaurant.get("name", "Restaurant")),
				_restaurant_category_label(category),
				int(restaurant.get("minimum_price", 0))
			],
			"description": "%s • %s • fame gate %d%s" % [
				str(restaurant.get("quality", "restaurant")),
				drive_text,
				int(restaurant.get("fame_required", 0)),
				" • entry fee $%d" % entry_fee if entry_fee > 0 else ""
			],
			"restaurant_id": restaurant_id,
			"kind": "restaurant",
			"tier": str(restaurant.get("tier", "casual")),
			"category": category,
			"quality": str(restaurant.get("quality", "restaurant")),
			"minimum_price": int(restaurant.get("minimum_price", 0)),
			"supports_drive_through": supports_drive_through,
			"fame_required": int(restaurant.get("fame_required", 0)),
			"visual_theme": restaurant_theme,
			"actions": [
				{
					"id": "restaurant_select:%s" % restaurant_id,
					"label": "Choose Restaurant",
					"kind": "packet",
					"style": "primary",
					"visual_theme": restaurant_theme
				}
			]
		})

	if matched_count <= 0:
		out.append({
			"label": "No restaurants found",
			"description": "No restaurants matched this category in the current era.",
			"kind": "restaurant_empty_category"
		})

	return out
func actor_order_has_items(actor: Person) -> bool:
	if actor == null:
		return false

	var cart: Dictionary = _restaurant_cart_for_actor(actor)
	var items: Array = cart.get("items", []) if typeof(cart.get("items", [])) == TYPE_ARRAY else []
	return not items.is_empty()

func restaurant_surface_state_for_actor(actor: Person) -> Dictionary:
	if actor == null:
		return {
			"restaurant_mode": "",
			"restaurant_plan_chosen": false,
			"candidate_id": -1,
			"candidate_name": "",
			"date_partner_id": -1,
			"date_partner_name": ""
		}

	var state: Dictionary = _restaurant_date_state(actor)
	var mode: String = str(state.get("mode", "")).strip_edges().to_lower()
	var partner_id: int = int(state.get("date_partner_id", -1))
	var plan_chosen: bool = false

	match mode:
		"alone", "partner":
			plan_chosen = true
		"date":
			plan_chosen = partner_id > 0

	return {
		"restaurant_mode": mode,
		"restaurant_plan_chosen": plan_chosen,
		"candidate_id": int(state.get("candidate_id", -1)),
		"candidate_name": str(state.get("candidate_name", "")),
		"date_partner_id": partner_id,
		"date_partner_name": str(state.get("date_partner_name", "")),
		"restaurant_id": str(state.get("restaurant_id", "")),
		"restaurant_service_mode": str(state.get("service_mode", ""))
	}
func actor_has_restaurant_plan(actor: Person) -> bool:
	if actor == null:
		return false

	var state: Dictionary = _restaurant_date_state(actor)
	return str(state.get("mode", "")).strip_edges() != ""


func actor_has_active_date_turn(actor: Person) -> bool:
	if actor == null:
		return false

	var state: Dictionary = _restaurant_date_state(actor)
	return (
		int(state.get("date_partner_id", -1)) > 0
		and str(state.get("service_mode", "")).strip_edges().to_lower() == "dine_in"
		and str(state.get("restaurant_id", "")).strip_edges() != ""
	)


func actor_order_checkout_label(actor: Person) -> String:
	if actor == null:
		return "Place Order"

	var state: Dictionary = _restaurant_date_state(actor)
	var service_mode: String = str(state.get("service_mode", "")).strip_edges().to_lower()
	var partner_id: int = int(state.get("date_partner_id", -1))

	if service_mode == "dine_in" and partner_id > 0:
		return "Place the Order and Start the Date"

	if service_mode == "drive_through":
		return "Place Drive-Thru Order"

	if service_mode == "takeout":
		return "Place Takeout Order"

	return "Place Order"
func get_restaurant_service_rows(context: Dictionary = {}) -> Array:
	var restaurant_id: String = str(context.get("restaurant_id", "")).strip_edges()
	var restaurant: Dictionary = get_restaurant(restaurant_id)
	var out: Array = []

	if restaurant.is_empty():
		out.append({
			"label": "Choose a restaurant first",
			"description": "Pick a restaurant before deciding dine-in, takeout, or drive-thru.",
			"kind": "restaurant_missing_service"
		})
		return out

	var restaurant_name: String = str(restaurant.get("name", "the restaurant"))
	var supports_drive_through: bool = bool(restaurant.get("supports_drive_through", false))

	out.append({
		"label": "Dine In",
		"description": "Sit down inside %s. If you brought a date, this starts the full turn-based date after checkout." % restaurant_name,
		"kind": "restaurant_service_mode",
		"service_mode": "dine_in",
		"actions": [
			{ "id": "restaurant_service:dine_in", "label": "Dine In", "kind": "packet", "style": "success"}
		]
	})

	out.append({
		"label": "Takeout",
		"description": "Order from %s and take the food with you. Good for quick health recovery and lighter social moments." % restaurant_name,
		"kind": "restaurant_service_mode",
		"service_mode": "takeout",
		"actions": [
			{ "id": "restaurant_service:takeout", "label": "Takeout", "kind": "packet", "style": "secondary"}
		]
	})

	if supports_drive_through:
		out.append({
			"label": "Drive-Thru",
			"description": "Pull through %s and get the food fast. Requires a vehicle." % restaurant_name,
			"kind": "restaurant_service_mode",
			"service_mode": "drive_through",
			"actions": [
				{ "id": "restaurant_service:drive_through", "label": "Drive-Thru", "kind": "packet", "style": "primary"}
			]
		})

	return out
func get_menu_rows(context: Dictionary = {}) -> Array:
	var restaurant_id: String = str(context.get("restaurant_id", "")).strip_edges()
	var restaurant: Dictionary = get_restaurant(restaurant_id)
	var out: Array = []
	var notice: String = str(context.get("notice", "")).strip_edges()
	var preview_only: bool = bool(context.get("menu_preview_only", false))

	if notice != "":
		out.append({
			"label": "Status",
			"description": notice,
			"kind": "restaurant_notice"
		})

	if restaurant.is_empty():
		if restaurant_id == "":
			out.append({
				"label": "Choose a restaurant first",
				"description": "Go back to Restaurants and pick a place to open its menu.",
				"kind": "restaurant_empty_menu"
			})
		else:
			out.append({
				"label": "Restaurant not found",
				"description": "The selected restaurant contract could not be resolved.",
				"kind": "restaurant_missing"
			})
		return out

	if preview_only:
		out.append({
			"label": "Menu Preview • %s" % str(restaurant.get("name", "Restaurant")),
			"description": "You are viewing the menu only. No service mode has started, no entry fee is charged, and nothing is added to an order from this preview.",
			"kind": "restaurant_menu_preview_header",
			"restaurant_id": restaurant_id
		})

	var actor: Person = _actor_from_context(context)

	if not preview_only:
		var room_summary: Dictionary = drive_restaurant_public_session(restaurant_id, context)
		var people_inside: int = int(room_summary.get("people_inside", 0))
		var visitor_count: int = int(room_summary.get("visitor_count", 0))
		var people_word: String = "person" if people_inside == 1 else "people"

		out.append({
			"label": "Dining Room • %d %s here" % [
				people_inside,
				people_word
			],
			"description": "%s has live public traffic. %d other visitors are eating, waiting, ordering, drifting between tables, or leaving while new groups arrive." % [
				str(restaurant.get("name", "This restaurant")),
				visitor_count
			],
			"kind": "restaurant_public_presence",
			"restaurant_id": restaurant_id,
			"people_inside": people_inside,
			"visitor_count": visitor_count,
			"arrival_wave_index": int(room_summary.get("arrival_wave_index", 0))
		})

	var entry_fee: int = int(restaurant.get("entry_fee", 0))
	if not preview_only and actor != null and entry_fee > 0 and not _restaurant_entry_paid(actor, restaurant_id):
		out.append({
			"label": "Entry Fee • $%d" % entry_fee,
			"description": "%s requires an entry fee before you can order." % str(restaurant.get("name", "This restaurant")),
			"kind": "restaurant_entry_fee",
			"actions": [
				{
					"id": "restaurant_pay_entry:%s" % restaurant_id,
					"label": "Pay Entry Fee",
					"kind": "packet",
					"style": "success"
				}
			]
		})
		return out

	var menu: Array = restaurant.get("menu", []) if typeof(restaurant.get("menu", [])) == TYPE_ARRAY else []
	for raw_item in menu:
		if typeof(raw_item) != TYPE_DICTIONARY:
			continue

		var item: Dictionary = raw_item
		var food_id: String = str(item.get("id", "")).strip_edges()
		var actions: Array = []

		if not preview_only:
			actions.append({
				"id": "restaurant_add:%s:%s" % [restaurant_id, food_id],
				"label": "Add to Order",
				"kind": "packet",
				"style": "success"
			})

		out.append({
			"label": "%s • $%d • restores %d hunger" % [
				str(item.get("name", "Menu Item")),
				int(item.get("price", 0)),
				int(item.get("hunger_restore", 0))
			],
			"description": "%s at %s. Nutrition %d. Quality: %s.%s" % [
				str(item.get("name", "Menu Item")),
				str(restaurant.get("name", "Restaurant")),
				int(item.get("nutrition", 0)),
				str(item.get("quality", restaurant.get("quality", "restaurant"))),
				" Preview only." if preview_only else ""
			],
			"restaurant_id": restaurant_id,
			"food_id": food_id,
			"kind": "restaurant_menu_item_preview" if preview_only else "restaurant_menu_item",
			"actions": actions
		})

	if not preview_only and _restaurant_session_has_date_partner(actor):
		out.append({
			"label": "Ask what they want",
			"description": "Let your date choose something from the menu. Their item adds itself to your order total.",
			"kind": "restaurant_partner_pick",
			"actions": [
				{
					"id": "restaurant_partner_pick",
					"label": "Ask Them",
					"kind": "packet",
					"style": "primary"
				}
			]
		})

	return out
func get_restaurant_intent_rows(context: Dictionary = {}) -> Array:
	var actor: Person = _actor_from_context(context)
	if actor == null:
		return []

	var state: Dictionary = _restaurant_date_state(actor)
	var context_mode: String = str(context.get("restaurant_mode", "")).strip_edges().to_lower()
	var mode: String = str(state.get("mode", "")).strip_edges().to_lower()
	var candidate_id: int = int(context.get("candidate_id", state.get("candidate_id", -1)))
	var date_partner_id: int = int(context.get("date_partner_id", state.get("date_partner_id", -1)))

	if context_mode == "" and not actor_order_has_items(actor) and not actor_has_active_date_turn(actor):
		mode = ""
		candidate_id = -1
		date_partner_id = -1
	elif context_mode != "":
		mode = context_mode

	if mode == "date" and candidate_id > 0 and date_partner_id <= 0:
		var date_search_rows: Array = [
			{
				"label": "Trying to Find a Date",
				"description": "Swipe through nearby opposite-gender NPCs for this pass. Ask them out, look for somebody else, or back out entirely.",
				"kind": "restaurant_date_search_header"
			}
		]
		date_search_rows.append_array(get_date_candidate_rows(context))
		return date_search_rows

	if mode != "":
		var current_text: String = "Going alone"
		if date_partner_id > 0:
			var partner: Person = gs.get_npc_by_id(date_partner_id) if gs != null else null
			if partner != null:
				current_text = "Going with %s" % str(partner.first_name)
		elif mode == "partner":
			var romantic_partner: Person = _current_romantic_partner(actor)
			if romantic_partner != null:
				current_text = "Going with %s" % str(romantic_partner.first_name)

		return [
			{
				"label": current_text,
				"description": "Your restaurant plan is set. Continue to Restaurant, or change the plan and start over.",
				"kind": "restaurant_intent_locked",
				"actions": [
					{ "id": "restaurant_continue:restaurant", "label": "Continue to Restaurant", "kind": "packet", "style": "primary"},
					{ "id": "restaurant_back:plan", "label": "Change Plan", "kind": "packet", "style": "secondary"}
				]
			}
		]

	var intent_rows: Array = [
		{
			"label": "Go Alone",
			"description": "Eat by yourself. Quick, clean, no social pressure.",
			"kind": "restaurant_intent",
			"actions": [
				{ "id": "restaurant_start:alone", "label": "Go Alone", "kind": "packet", "style": "secondary"}
			]
		}
	]

	var available_partner: Person = _current_romantic_partner(actor)
	if available_partner != null:
		intent_rows.append({
			"label": "Take %s" % str(available_partner.first_name),
			"description": "Invite your romantic partner out and turn the meal into a relationship moment.",
			"kind": "restaurant_intent_partner",
			"actions": [
				{ "id": "restaurant_start:partner", "label": "Take %s" % str(available_partner.first_name), "kind": "packet", "style": "success"}
			]
		})

	intent_rows.append({
		"label": "Try to Find a Date First",
		"description": "Look around for someone new. Browse one person at a time like a swipeable restaurant-date finder.",
		"kind": "restaurant_intent_find_date",
		"actions": [
			{ "id": "restaurant_start:date", "label": "Try to Find a Date First", "kind": "packet", "style": "primary"}
		]
	})

	return intent_rows

func get_date_candidate_rows(context: Dictionary = {}) -> Array:
	var actor: Person = _actor_from_context(context)
	if actor == null:
		return []

	var state: Dictionary = _restaurant_date_state(actor)
	var candidate_id: int = int(state.get("candidate_id", -1))
	var candidate: Person = gs.get_npc_by_id(candidate_id) if gs != null and candidate_id > 0 else null
	if candidate == null:
		var report: Dictionary = find_next_date_candidate(actor, { "source": "get_date_candidate_rows"})
		state = report.get("surface_state", {}) if typeof(report.get("surface_state", {})) == TYPE_DICTIONARY else _restaurant_date_state(actor)
		candidate_id = int(state.get("candidate_id", -1))
		candidate = gs.get_npc_by_id(candidate_id) if gs != null and candidate_id > 0 else null

	if candidate == null:
		return [
			{
				"label": "No date candidates found",
				"description": "Nobody nearby fits the current matching rules.",
				"kind": "restaurant_no_candidate"
			}
		]

	var perception: String = _date_candidate_perception(actor, candidate)
	return [
		{
			"label": "%s %s • Age %d" % [str(candidate.first_name), str(candidate.last_name), int(candidate.age)],
			"description": "%s\n\nThey perceive you as: %s" % [
				_date_candidate_description(candidate),
				perception
			],
			"kind": "restaurant_date_candidate",
			"candidate_id": int(candidate.id),
			"stat_bars": [
				{ "label": "Looks", "value": int(candidate.looks)},
				{ "label": "Smarts", "value": int(candidate.smarts)},
				{ "label": "Health", "value": int(candidate.health)},
				{ "label": "Chemistry", "value": _date_candidate_chemistry(actor, candidate)}
			],
			"actions": [
				{ "id": "restaurant_candidate:ask", "label": "Ask %s Out" % _him_her(candidate, true), "kind": "packet", "style": "success"},
				{ "id": "restaurant_candidate:next", "label": "Look for Somebody Else", "kind": "packet", "style": "primary"},
				{ "id": "restaurant_back:plan", "label": "Back Out", "kind": "packet", "style": "secondary"}
			]
		}
	]


func get_restaurant_category_rows(context: Dictionary = {}) -> Array:
	var era_name: String = _era_name_from_context(context)

	if era_name == "Industrial Era":
		return [
			{
				"label": "Quick Counters",
				"description": "Cheap plates, rail-station meals, worker lunches, and fast industrial-era food.",
				"kind": "restaurant_category",
				"category": "fast_food",
				"visual_theme": "restaurant_fast",
				"actions": [
					{ "id": "restaurant_category:fast_food", "label": "Quick Counters", "kind": "packet", "style": "primary"}
				]
			},
			{
				"label": "Dining Rooms",
				"description": "Sit-down meals, taverns, hotel restaurants, and proper date energy.",
				"kind": "restaurant_category",
				"category": "regular",
				"visual_theme": "restaurant_regular",
				"actions": [
					{ "id": "restaurant_category:regular", "label": "Dining Rooms", "kind": "packet", "style": "primary"}
				]
			},
			{
				"label": "Grand Tables",
				"description": "Elite dining rooms, reputation gates, entry fees, and society-night pressure.",
				"kind": "restaurant_category",
				"category": "luxury",
				"visual_theme": "restaurant_luxury",
				"actions": [
					{ "id": "restaurant_category:luxury", "label": "Grand Tables", "kind": "packet", "style": "primary"}
				]
			}
		]

	return [
		{
			"label": "🍟 Fast Food",
			"description": "Combos, fries, drive-thru energy, cheap dates, quick health recovery.",
			"kind": "restaurant_category",
			"category": "fast_food",
			"visual_theme": "restaurant_fast",
			"actions": [
				{ "id": "restaurant_category:fast_food", "label": "Fast Food", "kind": "packet", "style": "primary"}
			]
		},
		{
			"label": "🍽️ Regular Restaurants",
			"description": "Casual sit-down spots, balanced menus, real date energy.",
			"kind": "restaurant_category",
			"category": "regular",
			"visual_theme": "restaurant_regular",
			"actions": [
				{ "id": "restaurant_category:regular", "label": "Regular Restaurants", "kind": "packet", "style": "primary"}
			]
		},
		{
			"label": "🥂 Luxury Restaurants",
			"description": "Fame gates, entry fees, expensive menus, huge relationship moments.",
			"kind": "restaurant_category",
			"category": "luxury",
			"visual_theme": "restaurant_luxury",
			"actions": [
				{ "id": "restaurant_category:luxury", "label": "Luxury Restaurants", "kind": "packet", "style": "primary"}
			]
		}
	]

func get_restaurant_cart_rows(context: Dictionary = {}) -> Array:
	var actor: Person = _actor_from_context(context)
	if actor == null:
		return []

	if actor_has_active_date_turn(actor):
		return get_restaurant_date_turn_rows(context)

	var cart: Dictionary = _restaurant_cart_for_actor(actor)
	var items: Array = cart.get("items", []) if typeof(cart.get("items", [])) == TYPE_ARRAY else []
	var out: Array = []
	var notice: String = str(context.get("notice", "")).strip_edges()

	if notice != "":
		out.append({
			"label": "Order Notice",
			"description": notice,
			"kind": "restaurant_notice"
		})

	if items.is_empty():
		out.append({
			"label": "Your order is empty",
			"description": "Add food from the menu before checking out.",
			"kind": "restaurant_empty_cart"
		})
		return out

	var total: float = _restaurant_cart_total(cart)
	out.append({
		"label": "Order Total • $%.2f" % total,
		"description": "%d item stacks are in this order. Review everything before placing it." % items.size(),
		"kind": "restaurant_cart_total"
	})

	for raw_item in items:
		if typeof(raw_item) != TYPE_DICTIONARY:
			continue

		var item: Dictionary = raw_item
		out.append({
			"label": "%s ×%d • $%.2f" % [
				str(item.get("name", "Menu Item")),
				int(item.get("quantity", 1)),
				float(item.get("price", 0.0)) * float(item.get("quantity", 1))
			],
			"description": "For: %s • Quality: %s" % [
				str(item.get("ordered_for_name", "me")),
				str(item.get("quality", "restaurant"))
			],
			"kind": "restaurant_cart_item"
		})

	out.append({
		"label": "Ready?",
		"description": "Place the full order now. If this is dine-in with somebody, the date starts after the food is ordered.",
		"kind": "restaurant_place_order",
		"actions": [
			{
				"id": "restaurant_checkout:selected",
				"label": actor_order_checkout_label(actor),
				"kind": "packet",
				"style": "success"
			},
			{
				"id": "restaurant_back:menu",
				"label": "Keep Ordering",
				"kind": "packet",
				"style": "secondary"
			}
		]
	})

	return out

func get_restaurant_date_turn_rows(context: Dictionary = {}) -> Array:
	var actor: Person = _actor_from_context(context)
	if actor == null:
		return []

	var state: Dictionary = _restaurant_date_state(actor)
	var partner_id: int = int(state.get("date_partner_id", -1))
	var partner: Person = gs.get_npc_by_id(partner_id) if gs != null and partner_id > 0 else null
	if partner == null:
		return [
			{
				"label": "No active date",
				"description": "There is no dine-in date active right now.",
				"kind": "restaurant_no_active_date"
			}
		]

	var chemistry: int = int(state.get("date_score", _date_candidate_chemistry(actor, partner)))
	var turn: int = int(state.get("turn", 1))
	var is_partner: bool = _restaurant_date_partner_is_current_partner(actor, partner)
	var prompt: Dictionary = _restaurant_date_prompt_contract(actor, partner, state, chemistry)
	var prompt_text: String = str(prompt.get("text", "")).strip_edges()
	var prompt_key: String = str(prompt.get("key", "default")).strip_edges()
	var last_response: String = str(state.get("last_date_response", "")).strip_edges()
	var can_hook_up: bool = _date_can_hook_up(actor, partner, chemistry)
	var actions: Array = _restaurant_date_actions_for_prompt(prompt_key, is_partner, can_hook_up)
	var out: Array = []

	if bool(state.get("food_arrived", false)):
		out.append({
			"label": "🍽️ The Food Is Here",
			"description": "The plates are on the table. You can eat without interrupting the conversation choices below.",
			"kind": "restaurant_date_food_moment",
			"actions": [
				{
					"id": "restaurant_date_action:eat_bite",
					"label": "Take a Bite",
					"kind": "packet",
					"style": "success"
				}
			]
		})
	elif turn >= 2:
		out.append({
			"label": "🍽️ The Waiter Arrives",
			"description": "The waiter brings the food over and waits for the smallest reaction. Your date notices how you treat them.",
			"kind": "restaurant_date_waiter_moment",
			"actions": [
				{
					"id": "restaurant_date_action:waiter_polite",
					"label": "Thank the Waiter",
					"kind": "packet",
					"style": "success"
				},
				{
					"id": "restaurant_date_action:waiter_ignore",
					"label": "Ignore Them",
					"kind": "packet",
					"style": "secondary"
				},
				{
					"id": "restaurant_date_action:waiter_rude",
					"label": "Complain Rudely",
					"kind": "packet",
					"style": "danger"
				}
			]
		})

	var description_lines: Array = []
	if last_response != "":
		description_lines.append("Last: %s" % last_response)
	description_lines.append("%s looks at you across the table." % str(partner.first_name))
	description_lines.append(prompt_text)
	description_lines.append("Chemistry: %d/100." % chemistry)

	out.append({
		"label": "Date with %s • Turn %d" % [str(partner.first_name), turn],
		"description": "\n".join(description_lines),
		"kind": "restaurant_date_turn",
		"prompt_key": prompt_key,
		"stat_bars": [
			{ "label": "Chemistry", "value": chemistry},
			{ "label": "Their Affection", "value": int(partner.affection.get(int(actor.id), 50))},
			{ "label": "Your Health", "value": int(actor.health)}
		],
		"actions": actions
	})

	return out
func get_restaurant_fling_rows(_context: Dictionary = {}) -> Array:
	if gs == null or gs.player == null:
		return []

	var ids: Array = []
	if typeof(gs.scenario_state) == TYPE_DICTIONARY:
		ids = gs.scenario_state.get("restaurant_fling_ids", []) if typeof(gs.scenario_state.get("restaurant_fling_ids", [])) == TYPE_ARRAY else []

	var out: Array = []
	for raw_id in ids:
		var person_id: int = int(raw_id)
		var person: Person = gs.get_npc_by_id(person_id)
		if person == null:
			continue

		out.append({
			"label": "%s %s" % [str(person.first_name), str(person.last_name)],
			"description": "A fling from a restaurant date. Affection: %d/100." % int(person.affection.get(int(gs.player.id), 50)),
			"kind": "relationship_fling",
			"person_id": int(person.id)
		})

	if out.is_empty():
		out.append({
			"label": "No flings yet",
			"description": "Successful restaurant dates with non-partners can appear here.",
			"kind": "relationship_empty_flings"
		})

	return out
func choose_restaurant_mode(actor: Person, mode: String, _context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return { "success": false, "reason": "No actor supplied."}

	clear_restaurant_session(actor)

	var clean_mode: String = str(mode).strip_edges().to_lower()
	if clean_mode == "":
		clean_mode = "alone"

	var state: Dictionary = _restaurant_date_state(actor)
	state ["mode"] = clean_mode
	state ["turn"] = 1
	state ["date_score"] = 50
	state ["restaurant_id"] = ""
	state ["service_mode"] = ""
	state ["started_at_year"] = int(gs.year) if gs != null else 0

	if clean_mode == "partner":
		var partner: Person = _current_romantic_partner(actor)
		if partner == null:
			return { "success": false, "reason": "I do not have a romantic partner to take."}
		state ["date_partner_id"] = int(partner.id)
		state ["date_partner_name"] = "%s %s" % [str(partner.first_name), str(partner.last_name)]
		state ["date_score"] = clamp(int(partner.affection.get(int(actor.id), 55)) + 8, 0, 100)
	elif clean_mode == "date":
		restaurant_date_state_by_actor_id [str(int(actor.id))] = state
		return find_next_date_candidate(actor, _context)
	else:
		state ["date_partner_id"] = -1
		state ["date_partner_name"] = ""

	restaurant_date_state_by_actor_id [str(int(actor.id))] = state
	return {
		"success": true,
		"mode": clean_mode,
		"surface_state": {
			"restaurant_mode": clean_mode,
			"date_partner_id": int(state.get("date_partner_id", -1)),
			"date_partner_name": str(state.get("date_partner_name", "")),
			"notice": "Restaurant plan set."
		}
	}


func find_next_date_candidate(actor: Person, _context: Dictionary = {}) -> Dictionary:
	if actor == null or gs == null:
		return { "success": false, "reason": "No actor supplied."}

	var candidates: Array = _date_candidates_for_actor(actor)
	if candidates.is_empty():
		return {
			"success": false,
			"reason": "No date candidates found.",
			"surface_state": {
				"candidate_id": -1,
				"notice": "No date candidates found."
			}
		}

	var state: Dictionary = _restaurant_date_state(actor)
	var current_index: int = int(state.get("candidate_index", -1))
	var next_index: int = (current_index + 1) % candidates.size()
	var candidate: Person = candidates [next_index]

	state ["mode"] = "date"
	state ["candidate_index"] = next_index
	state ["candidate_id"] = int(candidate.id)
	state ["candidate_name"] = "%s %s" % [str(candidate.first_name), str(candidate.last_name)]
	state ["date_partner_id"] = -1
	state ["date_score"] = _date_candidate_chemistry(actor, candidate)
	restaurant_date_state_by_actor_id [str(int(actor.id))] = state

	return {
		"success": true,
		"candidate_id": int(candidate.id),
		"surface_state": {
			"restaurant_mode": "date",
			"candidate_id": int(candidate.id),
			"candidate_name": str(state.get("candidate_name", "")),
			"notice": "You noticed %s." % str(candidate.first_name)
		}
	}


func ask_current_date_candidate_out(actor: Person, _context: Dictionary = {}) -> Dictionary:
	if actor == null or gs == null:
		return { "success": false, "reason": "No actor supplied."}

	var state: Dictionary = _restaurant_date_state(actor)
	var candidate_id: int = int(state.get("candidate_id", -1))
	var candidate: Person = gs.get_npc_by_id(candidate_id)
	if candidate == null:
		return { "success": false, "reason": "No current date candidate."}

	var chemistry: int = _date_candidate_chemistry(actor, candidate)
	var accepted: bool = chemistry >= 42
	if not accepted:
		state ["date_score"] = chemistry
		restaurant_date_state_by_actor_id [str(int(actor.id))] = state
		return {
			"success": true,
			"accepted": false,
			"text": "%s smiled politely, but did not seem interested." % str(candidate.first_name),
			"surface_state": {
				"candidate_id": int(candidate.id),
				"notice": "%s declined the invite." % str(candidate.first_name)
			}
		}

	state ["date_partner_id"] = int(candidate.id)
	state ["date_partner_name"] = "%s %s" % [str(candidate.first_name), str(candidate.last_name)]
	state ["date_score"] = chemistry
	state ["turn"] = 1
	restaurant_date_state_by_actor_id [str(int(actor.id))] = state

	return {
		"success": true,
		"accepted": true,
		"text": "%s agreed to go out with me." % str(candidate.first_name),
		"surface_state": {
			"restaurant_mode": "date",
			"date_partner_id": int(candidate.id),
			"date_partner_name": str(state.get("date_partner_name", "")),
			"notice": "%s agreed. Pick somewhere to eat." % str(candidate.first_name)
		}
	}


func pay_restaurant_entry_fee(actor: Person, restaurant_id: String, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return { "success": false, "reason": "No actor supplied."}
	if gs == null or gs.food_engine == null:
		return { "success": false, "reason": "FoodEngine unavailable."}

	var restaurant: Dictionary = get_restaurant(restaurant_id)
	if restaurant.is_empty():
		return { "success": false, "reason": "Restaurant not found."}

	var fee: float = float(restaurant.get("entry_fee", 0.0))
	if fee <= 0.0:
		_mark_restaurant_entry_paid(actor, restaurant_id)
		return { "success": true, "text": "No entry fee was required."}

	var pay_report: Dictionary = gs.food_engine._pay_for_food(actor, fee, {
		"source": "restaurant_entry_fee",
		"restaurant_id": restaurant_id,
		"context": context.duplicate(true)
	})
	if not bool(pay_report.get("success", false)):
		return pay_report

	_mark_restaurant_entry_paid(actor, restaurant_id)
	return {
		"success": true,
		"restaurant_id": restaurant_id,
		"entry_fee": fee,
		"payment_report": pay_report.duplicate(true),
		"text": "I paid the $%.2f entry fee at %s." % [fee, str(restaurant.get("name", "the restaurant"))]
	}


func add_to_cart(actor: Person, restaurant_id: String, food_id: String, quantity: int = 1, _context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return { "success": false, "reason": "No actor supplied."}

	var restaurant: Dictionary = get_restaurant(restaurant_id)
	if restaurant.is_empty():
		return { "success": false, "reason": "Restaurant not found."}

	var item: Dictionary = _find_menu_item(restaurant, food_id)
	if item.is_empty():
		return { "success": false, "reason": "Menu item not found."}

	var cart: Dictionary = _restaurant_cart_for_actor(actor)
	cart ["restaurant_id"] = restaurant_id
	cart ["restaurant_name"] = str(restaurant.get("name", "Restaurant"))

	var items: Array = cart.get("items", []) if typeof(cart.get("items", [])) == TYPE_ARRAY else []
	var cart_item: Dictionary = item.duplicate(true)
	cart_item ["quantity"] = max(1, int(quantity))
	cart_item ["restaurant_id"] = restaurant_id
	cart_item ["restaurant_name"] = str(restaurant.get("name", "Restaurant"))
	cart_item ["ordered_for_id"] = int(actor.id)
	cart_item ["ordered_for_name"] = "me"
	items.append(cart_item)

	cart ["items"] = items
	cart ["updated_at_ms"] = int(Time.get_ticks_msec())
	restaurant_carts_by_actor_id [str(int(actor.id))] = cart

	return {
		"success": true,
		"actor_id": int(actor.id),
		"restaurant_id": restaurant_id,
		"food_id": food_id,
		"cart_total": _restaurant_cart_total(cart),
		"text": "I added %s to the order." % str(item.get("name", "food"))
	}

func begin_restaurant_order_context(actor: Person, restaurant_id: String, service_mode: String = "takeout", context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return { "success": false, "reason": "No actor supplied."}

	var clean_restaurant_id: String = str(restaurant_id).strip_edges()
	if clean_restaurant_id == "":
		return { "success": false, "reason": "No restaurant supplied."}

	var restaurant: Dictionary = get_restaurant(clean_restaurant_id)
	if restaurant.is_empty():
		return { "success": false, "reason": "Restaurant not found."}

	var clean_service: String = str(service_mode).strip_edges().to_lower()
	if clean_service == "":
		clean_service = "takeout"

	var cart: Dictionary = _restaurant_cart_for_actor(actor)
	cart ["restaurant_id"] = clean_restaurant_id
	cart ["restaurant_name"] = str(restaurant.get("name", "Restaurant"))
	cart ["service_mode"] = clean_service
	cart ["updated_at_ms"] = int(Time.get_ticks_msec())
	if not cart.has("items") or typeof(cart.get("items", [])) != TYPE_ARRAY:
		cart ["items"] = []
	restaurant_carts_by_actor_id [str(int(actor.id))] = cart

	var state: Dictionary = _restaurant_date_state(actor)
	state ["restaurant_id"] = clean_restaurant_id
	state ["restaurant_name"] = str(restaurant.get("name", "Restaurant"))
	state ["service_mode"] = clean_service
	state ["updated_at_ms"] = int(Time.get_ticks_msec())
	restaurant_date_state_by_actor_id [str(int(actor.id))] = state

	var public_session: Dictionary = {}
	if clean_service != "drive_through":
		public_session = drive_restaurant_public_session(clean_restaurant_id, {
			"source": "begin_restaurant_order_context",
			"actor_id": int(actor.id),
			"service_mode": clean_service,
			"context": context.duplicate(true)
		})

	return {
		"success": true,
		"actor_id": int(actor.id),
		"restaurant_id": clean_restaurant_id,
		"restaurant_name": str(restaurant.get("name", "Restaurant")),
		"service_mode": clean_service,
		"public_session": public_session.duplicate(true),
		"context": context.duplicate(true),
		"text": "You chose %s for %s." % [
			str(restaurant.get("name", "the restaurant")),
			clean_service.replace("_", " ")
		]
	}
func partner_pick_menu_item(actor: Person, _context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return { "success": false, "reason": "No actor supplied."}

	var cart: Dictionary = _restaurant_cart_for_actor(actor)
	var state: Dictionary = _restaurant_date_state(actor)
	var restaurant_id: String = str(cart.get("restaurant_id", state.get("restaurant_id", ""))).strip_edges()

	if restaurant_id == "":
		restaurant_id = str(_context.get("restaurant_id", "")).strip_edges()

	if restaurant_id == "":
		return { "success": false, "reason": "Pick a restaurant first."}

	var restaurant: Dictionary = get_restaurant(restaurant_id)
	if restaurant.is_empty():
		return { "success": false, "reason": "Restaurant not found."}

	var partner_id: int = int(state.get("date_partner_id", -1))
	var partner: Person = gs.get_npc_by_id(partner_id) if gs != null and partner_id > 0 else null
	if partner == null:
		return { "success": false, "reason": "There is nobody here to ask."}

	var menu: Array = restaurant.get("menu", []) if typeof(restaurant.get("menu", [])) == TYPE_ARRAY else []
	if menu.is_empty():
		return { "success": false, "reason": "The menu is empty."}

	var pick_index: int = abs(int(hash("%s|%s|%s" % [
		str(partner.id),
		str(restaurant_id),
		str(Time.get_ticks_msec())
	]))) % menu.size()
	var picked: Dictionary = (menu [pick_index] as Dictionary).duplicate(true)
	var cart_item: Dictionary = picked.duplicate(true)
	cart_item ["quantity"] = 1
	cart_item ["restaurant_id"] = restaurant_id
	cart_item ["restaurant_name"] = str(restaurant.get("name", "Restaurant"))
	cart_item ["ordered_for_id"] = int(partner.id)
	cart_item ["ordered_for_name"] = str(partner.first_name)

	var items: Array = cart.get("items", []) if typeof(cart.get("items", [])) == TYPE_ARRAY else []
	items.append(cart_item)

	cart ["restaurant_id"] = restaurant_id
	cart ["restaurant_name"] = str(restaurant.get("name", "Restaurant"))
	cart ["service_mode"] = str(state.get("service_mode", cart.get("service_mode", "dine_in"))).strip_edges().to_lower()
	cart ["items"] = items
	cart ["updated_at_ms"] = int(Time.get_ticks_msec())
	restaurant_carts_by_actor_id [str(int(actor.id))] = cart

	state ["restaurant_id"] = restaurant_id
	state ["restaurant_name"] = str(restaurant.get("name", "Restaurant"))
	state ["updated_at_ms"] = int(Time.get_ticks_msec())
	restaurant_date_state_by_actor_id [str(int(actor.id))] = state

	return {
		"success": true,
		"partner_id": int(partner.id),
		"food_id": str(picked.get("id", "")),
		"text": "%s picked %s. It was added to the order." % [
			str(partner.first_name),
			str(picked.get("name", "something"))
		]
	}

func checkout_cart(actor: Person, service_mode: String, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return { "success": false, "reason": "No actor supplied."}
	if gs == null or gs.food_engine == null:
		return { "success": false, "reason": "FoodEngine unavailable."}

	var cart: Dictionary = _restaurant_cart_for_actor(actor)
	var items: Array = cart.get("items", []) if typeof(cart.get("items", [])) == TYPE_ARRAY else []
	if items.is_empty():
		return { "success": false, "reason": "My order is empty."}

	var restaurant_id: String = str(cart.get("restaurant_id", "")).strip_edges()
	var restaurant: Dictionary = get_restaurant(restaurant_id)
	if restaurant.is_empty():
		return { "success": false, "reason": "Restaurant not found."}

	var state: Dictionary = _restaurant_date_state(actor)
	var clean_service: String = str(service_mode).strip_edges().to_lower()
	if clean_service == "" or clean_service == "selected":
		clean_service = str(state.get("service_mode", context.get("restaurant_service_mode", "takeout"))).strip_edges().to_lower()
	if clean_service == "":
		clean_service = "takeout"

	if clean_service == "drive_through":
		if not bool(restaurant.get("supports_drive_through", false)):
			return { "success": false, "reason": "%s does not support drive-through service." % str(restaurant.get("name", "This restaurant"))}
		if not _actor_has_vehicle(actor):
			return { "success": false, "reason": "I need a vehicle to use the drive-through."}

	var partner_id: int = int(state.get("date_partner_id", -1))
	var partner: Person = gs.get_npc_by_id(partner_id) if gs != null and partner_id > 0 else null
	var started_date_turn: bool = clean_service == "dine_in" and partner_id > 0
	var total: float = _restaurant_cart_total(cart)

	if started_date_turn:
		if partner_id > 0:
			_apply_date_boost(actor, partner_id, restaurant)

		state ["restaurant_id"] = restaurant_id
		state ["restaurant_name"] = str(restaurant.get("name", "Restaurant"))
		state ["service_mode"] = clean_service
		state ["turn"] = 1
		state ["date_score"] = clamp(int(state.get("date_score", 50)) + int(restaurant.get("date_affection_boost", 4)), 0, 100)
		state ["last_date_response"] = ""
		state ["food_arrived"] = false
		state ["meal_bite_count"] = 0
		state ["waiter_interaction"] = ""
		state ["restaurant_bill_requested"] = false
		state ["restaurant_bill_stage"] = ""
		state ["restaurant_custom_tip"] = 0.0
		state ["bill_snapshot"] = cart.duplicate(true)
		state ["bill_total"] = total
		state ["bill_paid"] = false
		restaurant_date_state_by_actor_id [str(int(actor.id))] = state

		restaurant_carts_by_actor_id.erase(str(int(actor.id)))

		var dine_report: Dictionary = {
			"success": true,
			"actor_id": int(actor.id),
			"restaurant_id": restaurant_id,
			"service_mode": clean_service,
			"total": total,
			"started_date_turn": true,
			"text": "The dine-in order was placed. The bill will come later."
		}
		visit_ledger.append(dine_report.duplicate(true))
		last_report = dine_report.duplicate(true)
		return dine_report

	var pay_report: Dictionary = gs.food_engine._pay_for_food(actor, total, {
		"source": "restaurant_checkout_cart",
		"restaurant_id": restaurant_id,
		"service_mode": clean_service,
		"context": context.duplicate(true)
	})
	if not bool(pay_report.get("success", false)):
		return pay_report

	var consume_reports: Array = []
	for raw_item in items:
		if typeof(raw_item) != TYPE_DICTIONARY:
			continue

		var item: Dictionary = raw_item
		if int(item.get("ordered_for_id", int(actor.id))) == int(actor.id):
			consume_reports.append(gs.food_engine.consume_food(actor, item, {
				"source": "restaurant_checkout_cart",
				"restaurant_id": restaurant_id,
				"service_mode": clean_service
			}))

	if partner_id > 0:
		_apply_date_boost(actor, partner_id, restaurant)

	restaurant_carts_by_actor_id.erase(str(int(actor.id)))

	var diary_text: String = ""
	var popup_text: String = ""
	var popup_title: String = "Restaurant Order"
	var popup_footer: String = "Tap anywhere to continue."

	if clean_service == "drive_through":
		var drive_summary: Dictionary = _restaurant_order_summary(actor, partner, items)
		diary_text = _restaurant_drive_through_diary_text(actor, partner, restaurant, drive_summary, total)
		popup_title = "Drive-Thru Order"
		popup_text = _restaurant_drive_through_popup_text(actor, partner, restaurant, drive_summary, total)
		_record_restaurant_life_diary(actor, diary_text)
	elif clean_service == "takeout":
		var takeout_summary: Dictionary = _restaurant_order_summary(actor, partner, items)
		diary_text = _restaurant_takeout_diary_text(actor, partner, restaurant, takeout_summary, total)
		popup_title = "Takeout Order"
		popup_text = _restaurant_takeout_popup_text(actor, partner, restaurant, takeout_summary, total)
		_record_restaurant_life_diary(actor, diary_text)

	var report: Dictionary = {
		"success": true,
		"actor_id": int(actor.id),
		"restaurant_id": restaurant_id,
		"service_mode": clean_service,
		"total": total,
		"payment_report": pay_report.duplicate(true),
		"consume_reports": consume_reports,
		"started_date_turn": false,
		"text": _restaurant_checkout_text(restaurant, clean_service, false)
	}

	if popup_text != "":
		report ["show_popup"] = true
		report ["popup_title"] = popup_title
		report ["popup_text"] = popup_text
		report ["popup_footer"] = popup_footer
		report ["life_diary_text"] = diary_text

	visit_ledger.append(report.duplicate(true))
	last_report = report.duplicate(true)
	return report

func resolve_date_action(actor: Person, action_id: String, _context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return { "success": false, "reason": "No actor supplied."}

	var state: Dictionary = _restaurant_date_state(actor)
	var partner_id: int = int(state.get("date_partner_id", -1))
	var partner: Person = gs.get_npc_by_id(partner_id) if gs != null and partner_id > 0 else null
	if partner == null:
		return { "success": false, "reason": "No active date partner."}

	var clean_action: String = str(action_id).strip_edges().to_lower()
	var score: int = int(state.get("date_score", _date_candidate_chemistry(actor, partner)))
	var delta: int = 0
	var text: String = ""
	var advances_turn: bool = true
	var is_partner: bool = _restaurant_date_partner_is_current_partner(actor, partner)

	match clean_action:
		"waiter_polite":
			delta = 6
			advances_turn = false
			state ["food_arrived"] = true
			state ["waiter_interaction"] = "polite"
			text = "I thanked the waiter. %s noticed the respect and softened a little." % str(partner.first_name)
		"waiter_ignore":
			delta = -3
			advances_turn = false
			state ["food_arrived"] = true
			state ["waiter_interaction"] = "ignored"
			text = "I ignored the waiter. %s clocked it, even if they did not say anything." % str(partner.first_name)
		"waiter_rude":
			delta = -12
			advances_turn = false
			state ["food_arrived"] = true
			state ["waiter_interaction"] = "rude"
			text = "I got rude with the waiter. %s looked embarrassed, and the table got colder." % str(partner.first_name)
		"eat_bite":
			advances_turn = false
			var bite_text: String = _restaurant_bite_text(actor, partner, state)
			state ["meal_bite_count"] = int(state.get("meal_bite_count", 0)) + 1
			text = bite_text
		"ask_about_life":
			if is_partner:
				delta = 1
				text = "%s laughed like I should already know that answer. The relationship made the question feel a little lazy." % str(partner.first_name)
			else:
				delta = 7 + int(float(partner.smarts) / 25.0)
				text = "%s opened up about where life has been taking %s." % [str(partner.first_name), _him_her(partner, false)]
		"answer_honest":
			delta = 8
			text = "I answered honestly. %s seemed to respect the fact that I did not perform for the table." % str(partner.first_name)
		"stretch_truth":
			delta = -2
			text = "I stretched the truth just enough to sound smoother. %s listened, but their eyes narrowed for half a second."
		"lie":
			delta = -10
			text = "I lied. %s did not fully catch it, but the energy got weird like the table knew." % str(partner.first_name)
		"change_subject":
			delta = -3
			text = "I changed the subject. %s went with it, but the dodge was obvious." % str(partner.first_name)
		"ignore_question":
			delta = -14
			text = "I ignored the question completely. %s stared at me like the date just lost a sponsor." % str(partner.first_name)
		"food_soul":
			delta = 9
			text = "I said I love food that tastes like somebody cared while making it. %s smiled at that." % str(partner.first_name)
		"food_fancy":
			delta = 4
			text = "I gave a polished answer about loving elevated food. %s seemed interested, but not fully convinced." % str(partner.first_name)
		"food_mayo":
			delta = -18
			text = "I said mayo sandwiches with confidence. %s paused so long the bread probably filed a complaint." % str(partner.first_name)
		"food_whatever":
			delta = -5
			text = "I shrugged and said I eat whatever. %s looked like they wanted more personality than that." % str(partner.first_name)
		"life_family":
			delta = 10
			text = "I said I want to build a stable life with people I love. %s looked genuinely moved." % str(partner.first_name)
		"life_empire":
			delta = 5
			text = "I said I want to build something big enough to change my family name. %s seemed intrigued by the ambition." % str(partner.first_name)
		"life_fame":
			delta = -4
			text = "I said I want to be famous enough that people cannot ignore me. %s smiled, but it was the kind of smile that had questions." % str(partner.first_name)
		"life_chaos":
			delta = -15
			text = "I said I mostly want money, options, and no accountability. %s blinked like the waiter should bring the check." % str(partner.first_name)
		"life_free":
			delta = 3
			text = "I said I want enough freedom to choose my own shape. %s seemed curious, even if they wanted more detail." % str(partner.first_name)
		"outfit_kind":
			delta = 9
			text = "I answered carefully and kindly. %s relaxed, like they were really asking if I saw them." % str(partner.first_name)
		"outfit_smooth":
			delta = 12
			text = "I gave a smooth answer without overdoing it. %s smiled like that landed exactly right." % str(partner.first_name)
		"outfit_too_honest":
			delta = -20
			text = "I told the truth with the grace of a dropped brick. %s looked at me like the date needed hazard insurance." % str(partner.first_name)
		"outfit_joke":
			delta = -6
			text = "I tried to joke through it. %s laughed for half a second, then clearly decided I was not escaping that easily." % str(partner.first_name)
		"joke":
			delta = 6 + int(float(actor.smarts) / 30.0)
			text = "%s laughed, and the table felt warmer." % str(partner.first_name)
		"compliment":
			delta = 8 + int(float(actor.looks) / 35.0)
			text = "%s looked away smiling after the compliment." % str(partner.first_name)
		"hook_up":
			var ask_text: String = "I leaned in and asked %s if they wanted to leave together after this, making it clear I meant more than another conversation." % str(partner.first_name)
			if not _date_can_hook_up(actor, partner, score):
				state ["last_date_response"] = "%s %s said the moment was not there yet." % [ask_text, str(partner.first_name)]
				restaurant_date_state_by_actor_id [str(int(actor.id))] = state
				return {
					"success": false,
					"date_finished": false,
					"partner_id": int(partner.id),
					"show_popup": true,
					"popup_title": "A Bold Ask",
					"popup_text": "%s\n\n%s said they were not ready for that." % [ask_text, str(partner.first_name)],
					"popup_footer": "Tap anywhere to continue.",
					"text": state ["last_date_response"]
				}

			_create_restaurant_fling(actor, partner)
			_apply_date_boost(actor, int(partner.id), get_restaurant(str(state.get("restaurant_id", ""))))
			text = "%s said yes. The night left the restaurant behind and became something much more private." % str(partner.first_name)
			state ["date_finished"] = true
			state ["last_date_response"] = text
			restaurant_date_state_by_actor_id [str(int(actor.id))] = state
			_record_restaurant_life_diary(actor, "I asked %s to hook up after our restaurant date, and they said yes. We left together, and the night became more than dinner." % str(partner.first_name))
			return {
				"success": true,
				"date_finished": true,
				"hook_up": true,
				"partner_id": int(partner.id),
				"show_popup": true,
				"popup_title": "A Bold Ask",
				"popup_text": ask_text,
				"popup_footer": "Tap anywhere to continue.",
				"followup_result": {
					"popup_title": "The Night Continued",
					"popup_text": text,
					"popup_footer": "Tap anywhere to continue."
				},
				"close_contract_surface": true,
				"close_after": true,
				"text": text
			}
		"end":
			if score >= 58:
				_create_restaurant_fling(actor, partner)
				text = "%s told me they had a great time. The night ended with a spark." % str(partner.first_name)
			else:
				text = "%s said the food was nice, but the connection felt uncertain." % str(partner.first_name)
			state ["date_finished"] = true
			state ["last_date_response"] = text
			restaurant_date_state_by_actor_id [str(int(actor.id))] = state
			_record_restaurant_life_diary(actor, "I ended my restaurant date with %s. %s" % [str(partner.first_name), text])
			return {
				"success": true,
				"date_finished": true,
				"partner_id": int(partner.id),
				"show_popup": true,
				"popup_title": "Date Ended",
				"popup_text": text,
				"popup_footer": "Tap anywhere to continue.",
				"text": text
			}
		_:
			delta = 2
			text = "The conversation kept moving."

	score = clamp(score + delta, 0, 100)
	state ["date_score"] = score
	state ["last_date_response"] = "%s Chemistry is now %d/100." % [text, score]
	if advances_turn:
		state ["turn"] = int(state.get("turn", 1)) + 1
	restaurant_date_state_by_actor_id [str(int(actor.id))] = state

	if gs != null and gs.relationship_engine != null and delta != 0:
		gs.relationship_engine.adjust_relationship(actor, partner, max(1, int(abs(float(delta)) / 2.0)) if delta > 0 else - max(1, int(abs(float(delta)) / 2.0)))

	return {
		"success": true,
		"date_finished": false,
		"partner_id": int(partner.id),
		"date_score": score,
		"text": state ["last_date_response"]
	}

func _restaurant_date_partner_is_current_partner(actor: Person, partner: Person) -> bool:
	if actor == null or partner == null:
		return false
	if actor.partner == null:
		return false
	return int(actor.partner.id) == int(partner.id)


func _restaurant_date_prompt_contract(actor: Person, partner: Person, state: Dictionary, chemistry: int) -> Dictionary:
	var name_text: String = str(partner.first_name) if partner != null else "They"
	var turn: int = int(state.get("turn", 1))
	var is_partner: bool = _restaurant_date_partner_is_current_partner(actor, partner)
	var gender_text: String = str(partner.gender).strip_edges().to_lower()
	var turn_index: int = abs(turn) % 5

	if is_partner:
		match turn_index:
			0:
				return {
					"key": "future_together",
					"text": "%s asks, \"What kind of life do you think we are actually building together?\"" % name_text
				}
			1:
				return {
					"key": "food_love",
					"text": "%s asks what food you secretly love even if everybody else judges it." % name_text
				}
			2:
				if gender_text == "female" or gender_text == "woman" or gender_text == "girl":
					return {
						"key": "outfit_trap",
						"text": "%s glances down and asks, \"Do these jeans make me look fat?\"" % name_text
					}
				return {
					"key": "outfit_trap",
					"text": "%s adjusts their outfit and asks, \"Do I look like I am trying too hard tonight?\"" % name_text
				}
			3:
				return {
					"key": "relationship_check",
					"text": "%s asks what you still want more of from the relationship." % name_text
				}
			_:
				return {
					"key": "default",
					"text": "%s already knows your background, so the question turns into whether you are still choosing them on purpose." % name_text
				}

	if chemistry >= 76:
		match turn_index:
			0:
				return {
					"key": "life_build",
					"text": "%s asks, \"What kind of life are you trying to build?\"" % name_text
				}
			1:
				return {
					"key": "closeness",
					"text": "%s leans in and asks what scares you about getting close to somebody." % name_text
				}
			2:
				return {
					"key": "food_love",
					"text": "%s smiles and asks what food you actually love when nobody is judging." % name_text
				}
			3:
				if gender_text == "female" or gender_text == "woman" or gender_text == "girl":
					return {
						"key": "outfit_trap",
						"text": "%s tilts her head and asks, \"Do these jeans make me look fat?\"" % name_text
					}
				return {
					"key": "outfit_trap",
					"text": "%s asks, \"Be honest, does this outfit look good on me?\"" % name_text
				}
			_:
				return {
					"key": "meaning",
					"text": "%s asks if you believe people meet for a reason." % name_text
				}

	if chemistry >= 50:
		match turn_index:
			0:
				return {
					"key": "default",
					"text": "%s asks what you usually do for fun." % name_text
				}
			1:
				return {
					"key": "origin",
					"text": "%s asks about your family and where you come from." % name_text
				}
			2:
				return {
					"key": "food_love",
					"text": "%s asks what kind of food you actually love." % name_text
				}
			3:
				return {
					"key": "life_build",
					"text": "%s asks what you want your future to feel like." % name_text
				}
			_:
				return {
					"key": "default",
					"text": "%s waits for you to carry the conversation forward." % name_text
				}

	match turn_index:
		0:
			return {
				"key": "default",
				"text": "%s asks a safe question and keeps their guard up." % name_text
			}
		1:
			return {
				"key": "origin",
				"text": "%s looks around the restaurant before asking where you are from." % name_text
			}
		2:
			return {
				"key": "awkward",
				"text": "%s gives a polite smile, waiting to see if you can make this less awkward." % name_text
			}
		3:
			return {
				"key": "food_love",
				"text": "%s asks where you usually eat, but their tone is hard to read." % name_text
			}
		_:
			return {
				"key": "default",
				"text": "%s seems unsure, but they have not checked out yet." % name_text
			}


func _restaurant_date_actions_for_prompt(prompt_key: String, is_partner: bool, can_hook_up: bool) -> Array:
	var key: String = str(prompt_key).strip_edges().to_lower()
	var actions: Array = []

	match key:
		"food_love":
			actions.append({ "id": "restaurant_date_action:food_soul", "label": "Say you love food with soul", "kind": "packet", "style": "success"})
			actions.append({ "id": "restaurant_date_action:food_fancy", "label": "Say you love fancy food", "kind": "packet", "style": "primary"})
			actions.append({ "id": "restaurant_date_action:food_mayo", "label": "Say mayo sandwiches", "kind": "packet", "style": "danger"})
			actions.append({ "id": "restaurant_date_action:food_whatever", "label": "Say you eat whatever", "kind": "packet", "style": "secondary"})
		"life_build", "future_together", "relationship_check":
			actions.append({ "id": "restaurant_date_action:life_family", "label": "Build a stable family life", "kind": "packet", "style": "success"})
			actions.append({ "id": "restaurant_date_action:life_empire", "label": "Build an empire", "kind": "packet", "style": "primary"})
			actions.append({ "id": "restaurant_date_action:life_free", "label": "Build a free life", "kind": "packet", "style": "primary"})
			actions.append({ "id": "restaurant_date_action:life_fame", "label": "Become famous", "kind": "packet", "style": "secondary"})
			actions.append({ "id": "restaurant_date_action:life_chaos", "label": "Money, options, no accountability", "kind": "packet", "style": "danger"})
		"outfit_trap":
			actions.append({ "id": "restaurant_date_action:outfit_kind", "label": "Answer kindly", "kind": "packet", "style": "success"})
			actions.append({ "id": "restaurant_date_action:outfit_smooth", "label": "Give a smooth answer", "kind": "packet", "style": "primary"})
			actions.append({ "id": "restaurant_date_action:outfit_too_honest", "label": "Be WAY too honest", "kind": "packet", "style": "danger"})
			actions.append({ "id": "restaurant_date_action:outfit_joke", "label": "Try to joke out of it", "kind": "packet", "style": "secondary"})
		_:
			actions.append({ "id": "restaurant_date_action:answer_honest", "label": "Answer Honestly", "kind": "packet", "style": "success"})
			actions.append({ "id": "restaurant_date_action:stretch_truth", "label": "Stretch the Truth", "kind": "packet", "style": "secondary"})
			actions.append({ "id": "restaurant_date_action:lie", "label": "Lie About It", "kind": "packet", "style": "danger"})
			actions.append({ "id": "restaurant_date_action:change_subject", "label": "Change the Subject", "kind": "packet", "style": "secondary"})

	if not is_partner:
		actions.append({ "id": "restaurant_date_action:ask_about_life", "label": "Ask About Their Life", "kind": "packet", "style": "primary"})

	actions.append({ "id": "restaurant_date_action:joke", "label": "Make a Joke", "kind": "packet", "style": "primary"})
	actions.append({ "id": "restaurant_date_action:compliment", "label": "Compliment Them", "kind": "packet", "style": "success"})
	actions.append({ "id": "restaurant_date_action:ignore_question", "label": "Ignore the Question", "kind": "packet", "style": "danger"})
	actions.append({ "id": "restaurant_date_action:end", "label": "End Date", "kind": "packet", "style": "secondary"})

	if can_hook_up:
		actions.append({ "id": "restaurant_date_action:hook_up", "label": "Ask to Hook Up", "kind": "packet", "style": "danger"})

	return actions


func _restaurant_bite_text(actor: Person, partner: Person, state: Dictionary) -> String:
	var seed_text: String = "%s|%s|%s|%s" % [
		str(actor.id) if actor != null else "0",
		str(partner.id) if partner != null else "0",
		str(state.get("turn", 1)),
		str(state.get("meal_bite_count", 0))
	]
	var index: int = abs(int(hash(seed_text))) % 5
	match index:
		0:
			return "I took a small bite and tried not to look too dramatic about it."
		1:
			return "I took a huge bite like the plate owed me money. %s definitely noticed." % str(partner.first_name)
		2:
			return "I stared at the food for a second before putting it in my mouth, like I was negotiating with destiny."
		3:
			return "I took a careful bite and nodded like a food critic with student loans."
		_:
			return "I took a bite and let the conversation breathe for a second."


func _restaurant_order_summary(actor: Person, partner: Person, items_or_restaurant: Variant, maybe_items: Variant = null) -> Dictionary:
	var items: Array = []

	if typeof(maybe_items) == TYPE_ARRAY:
		items = maybe_items as Array
	elif typeof(items_or_restaurant) == TYPE_ARRAY:
		items = items_or_restaurant as Array
	else:
		items = []

	var my_items: Array = []
	var their_items: Array = []

	for raw_item in items:
		if typeof(raw_item) != TYPE_DICTIONARY:
			continue

		var item: Dictionary = raw_item
		var item_name: String = str(item.get("name", "food")).strip_edges()
		var owner_id: int = int(item.get("ordered_for_id", int(actor.id) if actor != null else -1))

		if partner != null and owner_id == int(partner.id):
			their_items.append(item_name)
		else:
			my_items.append(item_name)

	return {
		"my_items": my_items,
		"their_items": their_items,
		"my_text": _restaurant_join_item_names(my_items),
		"their_text": _restaurant_join_item_names(their_items)
	}


func _restaurant_join_item_names(items: Array) -> String:
	var clean: Array = []
	for raw_item in items:
		var item_text: String = str(raw_item).strip_edges()
		if item_text != "":
			clean.append(item_text)

	if clean.is_empty():
		return "nothing"

	if clean.size() == 1:
		return str(clean [0])

	return ", ".join(clean.slice(0, clean.size() - 1)) + ", and " + str(clean [clean.size() - 1])


func _restaurant_drive_through_popup_text(_actor: Person, partner: Person, restaurant: Dictionary, summary: Dictionary, total: float) -> String:
	var restaurant_name: String = str(restaurant.get("name", "the restaurant"))
	if partner != null:
		return "I went through the drive-thru at %s with %s.\n\nI ordered %s.\n%s ordered %s.\n\nTotal: $%.2f." % [
			restaurant_name,
			str(partner.first_name),
			str(summary.get("my_text", "nothing")),
			str(partner.first_name),
			str(summary.get("their_text", "nothing")),
			total
		]

	return "I went alone through the drive-thru at %s and ordered %s.\n\nTotal: $%.2f." % [
		restaurant_name,
		str(summary.get("my_text", "nothing")),
		total
	]


func _restaurant_drive_through_diary_text(actor: Person, partner: Person, restaurant: Dictionary, summary: Dictionary, total: float) -> String:
	return _restaurant_drive_through_popup_text(actor, partner, restaurant, summary, total).replace("\n\n", " ")


func _restaurant_takeout_popup_text(_actor: Person, partner: Person, restaurant: Dictionary, summary: Dictionary, total: float) -> String:
	var restaurant_name: String = str(restaurant.get("name", "the restaurant"))
	if partner != null:
		return "I picked up takeout from %s with %s.\n\nI ordered %s.\n%s ordered %s.\n\nTotal: $%.2f." % [
			restaurant_name,
			str(partner.first_name),
			str(summary.get("my_text", "nothing")),
			str(partner.first_name),
			str(summary.get("their_text", "nothing")),
			total
		]

	return "I picked up takeout from %s and ordered %s.\n\nTotal: $%.2f." % [
		restaurant_name,
		str(summary.get("my_text", "nothing")),
		total
	]


func _restaurant_takeout_diary_text(actor: Person, partner: Person, restaurant: Dictionary, summary: Dictionary, total: float) -> String:
	return _restaurant_takeout_popup_text(actor, partner, restaurant, summary, total).replace("\n\n", " ")


func _record_restaurant_life_diary(actor: Person, text: String) -> void:
	if actor == null:
		return

	var clean_text: String = str(text).strip_edges()
	if clean_text == "":
		return

	if typeof(actor.memories) == TYPE_ARRAY:
		actor.memories.append(clean_text)

	if gs != null and gs.narrative_engine != null:
		gs.narrative_engine.log_event(actor, {
			"type": "restaurant_lifestyle",
			"text": clean_text,
			"life_diary_text": clean_text
		})
func resolve_waiter_action(actor: Person, action_id: String, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return { "success": false, "reason": "No actor supplied."}

	if gs == null or gs.food_engine == null:
		return { "success": false, "reason": "FoodEngine unavailable."}

	var state: Dictionary = _restaurant_date_state(actor)
	var partner_id: int = int(state.get("date_partner_id", -1))
	var partner: Person = gs.get_npc_by_id(partner_id) if gs != null and partner_id > 0 else null

	if partner == null:
		return { "success": false, "reason": "No active date partner."}

	var clean_action: String = str(action_id).strip_edges().to_lower()
	if clean_action == "":
		clean_action = "call"

	var actor_key: String = str(int(actor.id))
	var restaurant_id: String = str(state.get("restaurant_id", "")).strip_edges()
	var restaurant: Dictionary = get_restaurant(restaurant_id)
	var bill_total: float = float(state.get("bill_total", 0.0))
	var custom_tip: float = float(state.get("restaurant_custom_tip", state.get("custom_tip", 0.0)))

	if bill_total <= 0.0:
		var bill_snapshot: Dictionary = state.get("bill_snapshot", {}) if typeof(state.get("bill_snapshot", {})) == TYPE_DICTIONARY else {}
		if not bill_snapshot.is_empty():
			bill_total = _restaurant_cart_total(bill_snapshot)

	match clean_action:
		"call", "ask_bill", "request_bill":
			state ["waiter_called"] = true
			state ["food_arrived"] = true
			state ["restaurant_bill_requested"] = true
			state ["restaurant_bill_stage"] = "ready_to_pay"
			state ["bill_requested"] = true
			state ["bill_stage"] = "ready_to_pay"
			state ["updated_at_ms"] = int(Time.get_ticks_msec())
			restaurant_date_state_by_actor_id [actor_key] = state

			var call_text: String = "I called the waiter over. The food was cleared, the bill landed on the table, and %s watched how I handled the end of the date." % str(partner.first_name)

			return {
				"success": true,
				"waiter_called": true,
				"bill_requested": true,
				"bill_stage": "ready_to_pay",
				"custom_tip": custom_tip,
				"target_section": "cart",
				"active_section_id": "cart",
				"show_popup": true,
				"popup_title": "The Waiter Comes Over",
				"popup_text": call_text,
				"popup_footer": "Tap anywhere to continue.",
				"text": call_text
			}

		"pay_bill", "pay", "close_bill":
			var total_due: float = max(0.0, bill_total + custom_tip)
			var pay_report: Dictionary = {
				"success": true,
				"paid": 0.0,
				"reason": "No bill was due."
			}

			if total_due > 0.0:
				pay_report = gs.food_engine._pay_for_food(actor, total_due, {
					"source": "restaurant_waiter_bill",
					"restaurant_id": restaurant_id,
					"bill_total": bill_total,
					"tip": custom_tip,
					"context": context.duplicate(true)
				})

			if not bool(pay_report.get("success", false)):
				return {
					"success": false,
					"waiter_called": true,
					"bill_requested": true,
					"bill_stage": "ready_to_pay",
					"custom_tip": custom_tip,
					"target_section": "cart",
					"active_section_id": "cart",
					"payment_report": pay_report.duplicate(true),
					"text": str(pay_report.get("reason", "I could not pay the restaurant bill."))
				}

			var end_report: Dictionary = resolve_date_action(actor, "end", {
				"source": "restaurant_waiter_bill",
				"context": context.duplicate(true)
			})

			var end_text: String = str(end_report.get("text", "The date ended.")).strip_edges()
			var restaurant_name: String = str(restaurant.get("name", "the restaurant")) if not restaurant.is_empty() else "the restaurant"
			var paid_text: String = "I paid $%.2f at %s." % [total_due, restaurant_name]
			var final_text: String = "%s\n\n%s" % [paid_text, end_text]

			state ["bill_paid"] = true
			state ["date_finished"] = true
			state ["last_date_response"] = final_text
			state ["updated_at_ms"] = int(Time.get_ticks_msec())
			restaurant_date_state_by_actor_id [actor_key] = state

			visit_ledger.append({
				"restaurant_id": restaurant_id,
				"actor_id": int(actor.id),
				"partner_id": int(partner.id),
				"service_mode": "dine_in",
				"bill_total": bill_total,
				"tip": custom_tip,
				"total_paid": total_due,
				"payment_report": pay_report.duplicate(true),
				"date_end_report": end_report.duplicate(true),
				"year": int(gs.year) if gs != null else 0,
				"at_ms": int(Time.get_ticks_msec())
			})

			last_report = {
				"success": true,
				"restaurant_id": restaurant_id,
				"total_paid": total_due,
				"text": final_text
			}

			restaurant_carts_by_actor_id.erase(actor_key)
			restaurant_date_state_by_actor_id.erase(actor_key)

			return {
				"success": true,
				"waiter_called": true,
				"bill_requested": true,
				"bill_stage": "paid",
				"bill_paid": true,
				"date_finished": true,
				"custom_tip": custom_tip,
				"total_paid": total_due,
				"payment_report": pay_report.duplicate(true),
				"target_section": "cart",
				"active_section_id": "cart",
				"show_popup": true,
				"popup_title": "Bill Paid",
				"popup_text": final_text,
				"popup_footer": "Tap anywhere to continue.",
				"close_contract_surface": true,
				"close_after": true,
				"text": final_text
			}

		_:
			return {
				"success": false,
				"waiter_called": bool(state.get("waiter_called", false)),
				"bill_requested": bool(state.get("restaurant_bill_requested", state.get("bill_requested", false))),
				"bill_stage": str(state.get("restaurant_bill_stage", state.get("bill_stage", ""))),
				"custom_tip": custom_tip,
				"target_section": "cart",
				"active_section_id": "cart",
				"reason": "Unknown waiter action."
			}


func resolve_tip_action(actor: Person, action_id: String, tip_value: String = "", context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return { "success": false, "reason": "No actor supplied."}

	var state: Dictionary = _restaurant_date_state(actor)
	var clean_action: String = str(action_id).strip_edges().to_lower()
	var clean_tip_value: String = str(tip_value).strip_edges()
	var bill_total: float = float(state.get("bill_total", 0.0))
	var tip_amount: float = float(state.get("restaurant_custom_tip", state.get("custom_tip", 0.0)))

	if bill_total <= 0.0:
		var bill_snapshot: Dictionary = state.get("bill_snapshot", {}) if typeof(state.get("bill_snapshot", {})) == TYPE_DICTIONARY else {}
		if not bill_snapshot.is_empty():
			bill_total = _restaurant_cart_total(bill_snapshot)

	match clean_action:
		"preset", "percent":
			var percent: float = 18.0
			if clean_tip_value != "":
				percent = clamp(float(clean_tip_value), 0.0, 100.0)
			tip_amount = round((bill_total * (percent / 100.0)) * 100.0) / 100.0
		"custom", "amount":
			tip_amount = max(0.0, round(float(clean_tip_value) * 100.0) / 100.0)
		"none", "skip":
			tip_amount = 0.0
		_:
			tip_amount = max(0.0, tip_amount)

	state ["restaurant_bill_requested"] = true
	state ["restaurant_bill_stage"] = "ready_to_pay"
	state ["restaurant_custom_tip"] = tip_amount
	state ["bill_requested"] = true
	state ["bill_stage"] = "ready_to_pay"
	state ["custom_tip"] = tip_amount
	state ["updated_at_ms"] = int(Time.get_ticks_msec())
	restaurant_date_state_by_actor_id [str(int(actor.id))] = state

	return {
		"success": true,
		"bill_requested": true,
		"bill_stage": "ready_to_pay",
		"custom_tip": tip_amount,
		"bill_total": bill_total,
		"target_section": "cart",
		"active_section_id": "cart",
		"text": "Tip set to $%.2f. The bill is ready." % tip_amount,
		"context": context.duplicate(true)
	}
func clear_restaurant_session(actor: Person) -> void:
	if actor == null:
		return
	restaurant_carts_by_actor_id.erase(str(int(actor.id)))
	restaurant_date_state_by_actor_id.erase(str(int(actor.id)))
func clear_restaurant_order_items(actor: Person) -> void:
	if actor == null:
		return

	restaurant_carts_by_actor_id.erase(str(int(actor.id)))

	var state: Dictionary = _restaurant_date_state(actor)
	state ["updated_at_ms"] = int(Time.get_ticks_msec())
	restaurant_date_state_by_actor_id [str(int(actor.id))] = state
func place_order(actor: Person, restaurant_id: String, food_id: String, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return { "success": false, "reason": "No actor supplied."}

	var restaurant: Dictionary = get_restaurant(restaurant_id)
	if restaurant.is_empty():
		return { "success": false, "reason": "Restaurant not found."}

	var fame_required: int = int(restaurant.get("fame_required", 0))
	if int(actor.fame) < fame_required:
		return {
			"success": false,
			"reason": "%s requires fame level %d." % [str(restaurant.get("name", "This restaurant")), fame_required]
		}

	var service_mode: String = str(context.get("service_mode", "dine_in")).strip_edges()
	if service_mode == "drive_through":
		if not bool(restaurant.get("supports_drive_through", false)):
			return {
				"success": false,
				"reason": "%s does not support drive-through service." % str(restaurant.get("name", "This restaurant"))
			}
		if not _actor_has_vehicle(actor):
			return { "success": false, "reason": "I need a vehicle to use the drive-through."}

	var menu_item: Dictionary = _find_menu_item(restaurant, food_id)
	if menu_item.is_empty():
		return { "success": false, "reason": "Menu item not found."}

	var item: Dictionary = menu_item.duplicate(true)
	item ["restaurant_id"] = str(restaurant.get("id", ""))
	item ["restaurant_name"] = str(restaurant.get("name", "Restaurant"))
	item ["quality"] = str(item.get("quality", restaurant.get("quality", "restaurant")))

	var report: Dictionary = gs.food_engine.buy_and_consume(actor, item, {
		"source": "food_restaurant_engine",
		"restaurant_id": str(restaurant.get("id", "")),
		"service_mode": service_mode,
		"date_partner_id": int(context.get("date_partner_id", -1))
	})

	if bool(report.get("success", false)) and int(context.get("date_partner_id", -1)) > 0:
		_apply_date_boost(actor, int(context.get("date_partner_id", -1)), restaurant)

	visit_ledger.append({
		"restaurant_id": str(restaurant.get("id", "")),
		"food_id": food_id,
		"actor_id": int(actor.id),
		"service_mode": service_mode,
		"report": report.duplicate(true),
		"year": int(gs.year) if gs != null else 0,
		"at_ms": int(Time.get_ticks_msec())
	})
	last_report = report.duplicate(true)
	return report

func get_restaurants_for_era(era_name: String = "") -> Array:
	var clean: String = str(era_name).strip_edges()
	if clean == "":
		clean = _era_name_from_context({})

	var eras: Dictionary = restaurant_contract.get("eras", {}) if typeof(restaurant_contract.get("eras", {})) == TYPE_DICTIONARY else {}
	var raw_rows: Variant = eras.get(clean, [])

	if typeof(raw_rows) == TYPE_ARRAY and not (raw_rows as Array).is_empty():
		return (raw_rows as Array).duplicate(true)

	if clean == "Industrial Era":
		return _industrial_restaurant_rows()

	var modern_rows: Variant = eras.get("Modern Era", [])
	if typeof(modern_rows) == TYPE_ARRAY:
		return (modern_rows as Array).duplicate(true)

	return []
func _industrial_restaurant_rows() -> Array:
	return [
		{
			"id": "brass_kettle_chophouse",
			"name": "Brass Kettle Chophouse",
			"tier": "regular",
			"category": "regular",
			"quality": "hearty",
			"minimum_price": 9,
			"entry_fee": 0,
			"fame_required": 0,
			"supports_drive_through": false,
			"date_affection_boost": 5,
			"menu": [
				{ "id": "coal_roast_plate", "name": "Coal Roast Plate", "price": 12, "hunger_restore": 42, "nutrition": 52, "protein": 8, "quality": "hearty"},
				{ "id": "factory_stew_bowl", "name": "Factory Stew Bowl", "price": 7, "hunger_restore": 34, "nutrition": 44, "quality": "working_class"}
			]
		},
		{
			"id": "steam_lane_counter",
			"name": "Steam Lane Counter",
			"tier": "fast_food",
			"category": "fast_food",
			"quality": "quick",
			"minimum_price": 4,
			"entry_fee": 0,
			"fame_required": 0,
			"supports_drive_through": false,
			"date_affection_boost": 2,
			"menu": [
				{ "id": "paper_wrapped_pie", "name": "Paper-Wrapped Pie", "price": 4, "hunger_restore": 24, "nutrition": 22, "quality": "quick"},
				{ "id": "street_potato", "name": "Street Potato", "price": 2, "hunger_restore": 18, "nutrition": 20, "quality": "cheap"}
			]
		},
		{
			"id": "velvet_rail_dining_room",
			"name": "Velvet Rail Dining Room",
			"tier": "luxury",
			"category": "luxury",
			"quality": "elite_industrial",
			"minimum_price": 120,
			"entry_fee": 35,
			"fame_required": 12,
			"supports_drive_through": false,
			"date_affection_boost": 12,
			"menu": [
				{ "id": "silver_carriage_course", "name": "Silver Carriage Course", "price": 160, "hunger_restore": 48, "nutrition": 82, "protein": 10, "vitamins": 8, "quality": "elite_industrial"}
			]
		}
	]

func get_restaurant(restaurant_id: String) -> Dictionary:
	var clean: String = str(restaurant_id).strip_edges()
	for era_key in restaurant_contract.get("eras", {}).keys():
		var rows: Array = restaurant_contract ["eras"].get(era_key, [])
		for raw_row in rows:
			if typeof(raw_row) != TYPE_DICTIONARY:
				continue
			var row: Dictionary = raw_row
			if str(row.get("id", "")) == clean:
				return row.duplicate(true)
	return {}

func export_state() -> Dictionary:
	return {
		"schema": "eralife.food_restaurant_engine_state",
		"version": RESTAURANT_VERSION,
		"restaurant_contract": restaurant_contract.duplicate(true),
		"visit_ledger": visit_ledger.duplicate(true),
		"restaurant_carts_by_actor_id": restaurant_carts_by_actor_id.duplicate(true),
		"restaurant_date_state_by_actor_id": restaurant_date_state_by_actor_id.duplicate(true),
		"restaurant_public_sessions_by_restaurant_id": restaurant_public_sessions_by_restaurant_id.duplicate(true),
		"last_report": last_report.duplicate(true)
	}
func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return { "success": false, "reason": "FoodRestaurantEngine import data must be a Dictionary."}

	restaurant_contract = data.get("restaurant_contract", _default_restaurant_contract()).duplicate(true) if typeof(data.get("restaurant_contract", {})) == TYPE_DICTIONARY else _default_restaurant_contract()
	visit_ledger = data.get("visit_ledger", []).duplicate(true) if typeof(data.get("visit_ledger", [])) == TYPE_ARRAY else []
	restaurant_carts_by_actor_id = data.get("restaurant_carts_by_actor_id", {}).duplicate(true) if typeof(data.get("restaurant_carts_by_actor_id", {})) == TYPE_DICTIONARY else {}
	restaurant_date_state_by_actor_id = data.get("restaurant_date_state_by_actor_id", {}).duplicate(true) if typeof(data.get("restaurant_date_state_by_actor_id", {})) == TYPE_DICTIONARY else {}
	restaurant_public_sessions_by_restaurant_id = data.get("restaurant_public_sessions_by_restaurant_id", {}).duplicate(true) if typeof(data.get("restaurant_public_sessions_by_restaurant_id", {})) == TYPE_DICTIONARY else {}
	last_report = data.get("last_report", {}).duplicate(true) if typeof(data.get("last_report", {})) == TYPE_DICTIONARY else {}

	return { "success": true}

func _find_menu_item(restaurant: Dictionary, food_id: String) -> Dictionary:
	var menu: Array = restaurant.get("menu", []) if typeof(restaurant.get("menu", [])) == TYPE_ARRAY else []
	for raw_item in menu:
		if typeof(raw_item) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = raw_item
		if str(item.get("id", "")) == food_id:
			return item.duplicate(true)
	return {}
func start_restaurant_public_session(restaurant_id: String, context: Dictionary = {}) -> Dictionary:
	var clean_restaurant_id: String = str(restaurant_id).strip_edges()
	if clean_restaurant_id == "":
		return {}

	var restaurant: Dictionary = get_restaurant(clean_restaurant_id)
	if restaurant.is_empty():
		return {}

	var now_ms: int = int(Time.get_ticks_msec())
	var session: Dictionary = restaurant_public_sessions_by_restaurant_id.get(clean_restaurant_id, {}) if typeof(restaurant_public_sessions_by_restaurant_id.get(clean_restaurant_id, {})) == TYPE_DICTIONARY else {}

	if session.is_empty():
		session = {
			"restaurant_id": clean_restaurant_id,
			"active": true,
			"visitors": {},
			"departed_visitor_ids": [],
			"arrival_wave_index": 0,
			"next_arrival_wave_ms": now_ms,
			"generated_ambient_serial": 0,
			"created_at_ms": now_ms,
			"last_tick_ms": 0,
			"updated_at_ms": now_ms
		}

	session ["active"] = true
	session ["updated_at_ms"] = now_ms
	session = _restaurant_backfill_public_arrival_wave(clean_restaurant_id, restaurant, session, context, "session_start")
	restaurant_public_sessions_by_restaurant_id [clean_restaurant_id] = session

	return session.duplicate(true)


func drive_restaurant_public_session(restaurant_id: String, context: Dictionary = {}) -> Dictionary:
	var clean_restaurant_id: String = str(restaurant_id).strip_edges()
	if clean_restaurant_id == "":
		return {}

	var restaurant: Dictionary = get_restaurant(clean_restaurant_id)
	if restaurant.is_empty():
		return {}

	var session: Dictionary = start_restaurant_public_session(clean_restaurant_id, context)
	if session.is_empty():
		return {}

	var now_ms: int = int(Time.get_ticks_msec())
	var last_tick_ms: int = int(session.get("last_tick_ms", 0))

	if now_ms - last_tick_ms < _restaurant_public_tick_ms():
		session = _restaurant_backfill_public_arrival_wave(clean_restaurant_id, restaurant, session, context, "between_ticks")
		restaurant_public_sessions_by_restaurant_id [clean_restaurant_id] = session
		return _restaurant_public_summary(clean_restaurant_id, restaurant, session)

	var visitors: Dictionary = session.get("visitors", {}) if typeof(session.get("visitors", {})) == TYPE_DICTIONARY else {}
	var departed_visitor_ids: Array = session.get("departed_visitor_ids", []) if typeof(session.get("departed_visitor_ids", [])) == TYPE_ARRAY else []
	var remove_ids: Array = []
	var floor_count: int = _restaurant_public_min_visitor_count(restaurant)

	for raw_id in visitors.keys():
		var visitor_id: String = str(raw_id)
		var visitor: Dictionary = visitors.get(visitor_id, {}) if typeof(visitors.get(visitor_id, {})) == TYPE_DICTIONARY else {}
		if visitor.is_empty():
			remove_ids.append(visitor_id)
			continue

		var is_lingering: bool = now_ms < int(visitor.get("linger_until_ms", 0))
		var rng: RandomNumberGenerator = _restaurant_public_rng("%s|%s|%s" % [
			clean_restaurant_id,
			visitor_id,
			str(int(floor(float(now_ms) / float(max(1, _restaurant_public_tick_ms())))))
		])
		var roll: float = rng.randf()

		if visitors.size() - remove_ids.size() > floor_count and not is_lingering:
			if roll < 0.03:
				visitor ["left_restaurant"] = true
				visitor ["left_at_ms"] = now_ms
				if not departed_visitor_ids.has(int(visitor_id)):
					departed_visitor_ids.append(int(visitor_id))
				remove_ids.append(visitor_id)
				continue

			if roll < 0.22:
				visitor ["room_zone"] = _restaurant_public_zone_for_restaurant(restaurant, rng)
				visitor ["linger_until_ms"] = now_ms + int(rng.randi_range(3200, 12000))

		if rng.randf() < 0.36:
			visitor ["meal_estimate"] = round((float(visitor.get("meal_estimate", 0.0)) + rng.randf_range(6.0, 42.0)) * 100.0) / 100.0

		visitor ["updated_at_ms"] = now_ms
		visitors [visitor_id] = visitor

	for raw_remove_id in remove_ids:
		visitors.erase(str(raw_remove_id))

	session ["visitors"] = visitors
	session ["departed_visitor_ids"] = departed_visitor_ids
	session ["last_tick_ms"] = now_ms
	session ["updated_at_ms"] = now_ms
	session = _restaurant_backfill_public_arrival_wave(clean_restaurant_id, restaurant, session, context, "after_departures")

	restaurant_public_sessions_by_restaurant_id [clean_restaurant_id] = session
	return _restaurant_public_summary(clean_restaurant_id, restaurant, session)


func get_restaurant_presence_summary(restaurant_id: String, context: Dictionary = {}) -> Dictionary:
	return drive_restaurant_public_session(restaurant_id, context)


func stop_restaurant_public_session(restaurant_id: String = "") -> void:
	var clean_restaurant_id: String = str(restaurant_id).strip_edges()
	if clean_restaurant_id == "":
		for raw_key in restaurant_public_sessions_by_restaurant_id.keys():
			var key: String = str(raw_key)
			var loop_session: Dictionary = restaurant_public_sessions_by_restaurant_id.get(key, {}) if typeof(restaurant_public_sessions_by_restaurant_id.get(key, {})) == TYPE_DICTIONARY else {}
			loop_session ["active"] = false
			loop_session ["updated_at_ms"] = int(Time.get_ticks_msec())
			restaurant_public_sessions_by_restaurant_id [key] = loop_session
		return

	var target_session: Dictionary = restaurant_public_sessions_by_restaurant_id.get(clean_restaurant_id, {}) if typeof(restaurant_public_sessions_by_restaurant_id.get(clean_restaurant_id, {})) == TYPE_DICTIONARY else {}
	if target_session.is_empty():
		return

	target_session ["active"] = false
	target_session ["updated_at_ms"] = int(Time.get_ticks_msec())
	restaurant_public_sessions_by_restaurant_id [clean_restaurant_id] = target_session


func _restaurant_public_tick_ms() -> int:
	return 1250


func _restaurant_public_summary(restaurant_id: String, restaurant: Dictionary, session: Dictionary) -> Dictionary:
	var visitors: Dictionary = session.get("visitors", {}) if typeof(session.get("visitors", {})) == TYPE_DICTIONARY else {}
	var player_count: int = 1
	var staff_count: int = _restaurant_staff_count(restaurant)

	return {
		"restaurant_id": restaurant_id,
		"people_inside": visitors.size() + player_count + staff_count,
		"visitor_count": visitors.size(),
		"player_count": player_count,
		"staff_count": staff_count,
		"arrival_wave_index": int(session.get("arrival_wave_index", 0)),
		"next_arrival_wave_ms": int(session.get("next_arrival_wave_ms", 0)),
		"updated_at_ms": int(session.get("updated_at_ms", Time.get_ticks_msec()))
	}


func _restaurant_backfill_public_arrival_wave(restaurant_id: String, restaurant: Dictionary, session: Dictionary, context: Dictionary = {}, reason: String = "") -> Dictionary:
	var now_ms: int = int(Time.get_ticks_msec())
	var visitors: Dictionary = session.get("visitors", {}) if typeof(session.get("visitors", {})) == TYPE_DICTIONARY else {}
	var departed_visitor_ids: Array = session.get("departed_visitor_ids", []) if typeof(session.get("departed_visitor_ids", [])) == TYPE_ARRAY else []
	var min_count: int = _restaurant_public_min_visitor_count(restaurant)
	var max_count: int = _restaurant_public_max_visitor_count(restaurant)
	var target_count: int = _restaurant_public_target_visitor_count(restaurant_id, restaurant)
	var next_arrival_wave_ms: int = int(session.get("next_arrival_wave_ms", 0))
	var arrival_due: bool = now_ms >= next_arrival_wave_ms
	var below_floor: bool = visitors.size() < min_count
	var rng: RandomNumberGenerator = _restaurant_public_rng("%s|arrival_wave|%s|%s|%s" % [
		restaurant_id,
		str(int(session.get("arrival_wave_index", 0))),
		str(int(floor(float(now_ms) / 1000.0))),
		reason
	])

	var desired_count: int = target_count
	if below_floor:
		desired_count = max(desired_count, min(max_count, min_count + int(rng.randi_range(1, 3))))
	elif arrival_due and visitors.size() < max_count:
		desired_count = max(desired_count, min(max_count, visitors.size() + _restaurant_arrival_wave_size(restaurant, rng)))

	if not below_floor and not arrival_due and visitors.size() >= desired_count:
		session ["visitors"] = visitors
		session ["departed_visitor_ids"] = departed_visitor_ids
		return session

	var spawn_attempts: int = 0
	while visitors.size() < desired_count and spawn_attempts < 80:
		spawn_attempts += 1
		if not _restaurant_spawn_public_visitor(restaurant_id, restaurant, visitors, departed_visitor_ids, session, context):
			break

	if arrival_due or below_floor or next_arrival_wave_ms <= 0:
		session ["arrival_wave_index"] = int(session.get("arrival_wave_index", 0)) + 1
		session ["next_arrival_wave_ms"] = now_ms + _restaurant_next_arrival_wave_delay_ms(restaurant, rng)

	session ["visitors"] = visitors
	session ["departed_visitor_ids"] = departed_visitor_ids
	session ["last_arrival_reason"] = reason
	session ["updated_at_ms"] = now_ms
	return session


func _restaurant_spawn_public_visitor(restaurant_id: String, restaurant: Dictionary, visitors: Dictionary, departed_visitor_ids: Array, session: Dictionary, context: Dictionary = {}) -> bool:
	var now_ms: int = int(Time.get_ticks_msec())
	var candidate: Person = _restaurant_pick_public_visitor(restaurant_id, visitors, departed_visitor_ids, context)

	if candidate == null:
		var generated_rng: RandomNumberGenerator = _restaurant_public_rng("%s|generated_visitor|%s|%s" % [
			restaurant_id,
			str(now_ms),
			str(int(session.get("generated_ambient_serial", 0)))
		])
		var generated_visitor: Dictionary = _restaurant_generated_public_visitor_snapshot(restaurant_id, restaurant, visitors, departed_visitor_ids, session, generated_rng, now_ms)
		if generated_visitor.is_empty():
			return false
		visitors [str(int(generated_visitor.get("person_id", -1)))] = generated_visitor
		return true

	var rng: RandomNumberGenerator = _restaurant_public_rng("%s|%s|visitor_spawn|%s" % [
		restaurant_id,
		str(candidate.id),
		str(now_ms)
	])

	visitors [str(int(candidate.id))] = {
		"person_id": int(candidate.id),
		"name": _restaurant_person_name(candidate),
		"profession": _restaurant_person_profession(candidate),
		"restaurant_id": restaurant_id,
		"room_zone": _restaurant_public_zone_for_restaurant(restaurant, rng),
		"meal_estimate": round(rng.randf_range(5.0, 85.0) * 100.0) / 100.0,
		"entered_at_ms": now_ms,
		"updated_at_ms": now_ms,
		"linger_until_ms": now_ms + int(rng.randi_range(5200, 18000)),
		"left_restaurant": false,
		"ambient_generated": false
	}

	return true


func _restaurant_pick_public_visitor(_restaurant_id: String, visitors: Dictionary, departed_visitor_ids: Array, _context: Dictionary = {}) -> Person:
	if gs == null:
		return null

	var candidates: Array = []
	for raw_person in gs.npcs:
		if raw_person == null or not (raw_person is Person):
			continue

		var person: Person = raw_person as Person
		if gs.player != null and int(person.id) == int(gs.player.id):
			continue
		if not bool(person.alive):
			continue
		if visitors.has(str(int(person.id))):
			continue
		if departed_visitor_ids.has(int(person.id)):
			continue

		candidates.append(person)

	if candidates.is_empty():
		return null

	var rng: RandomNumberGenerator = _restaurant_public_rng("restaurant_pick|%s|%s" % [
		str(candidates.size()),
		str(Time.get_ticks_msec())
	])
	return candidates [int(rng.randi_range(0, candidates.size() - 1))]


func _restaurant_generated_public_visitor_snapshot(restaurant_id: String, restaurant: Dictionary, visitors: Dictionary, departed_visitor_ids: Array, session: Dictionary, rng: RandomNumberGenerator, now_ms: int) -> Dictionary:
	var serial: int = int(session.get("generated_ambient_serial", 0)) + 1
	var restaurant_offset: int = abs(int(hash(str(restaurant_id)))) % 500000
	var generated_id: int = - int(2000000 + restaurant_offset + serial)

	while visitors.has(str(generated_id)) or departed_visitor_ids.has(generated_id):
		serial += 1
		generated_id = - int(2000000 + restaurant_offset + serial)

	session ["generated_ambient_serial"] = serial

	var first_names: Array = _restaurant_generated_first_names()
	var last_names: Array = _restaurant_generated_last_names()
	var professions: Array = _restaurant_generated_professions()

	var first_name: String = str(first_names [int(rng.randi_range(0, first_names.size() - 1))])
	var last_name: String = str(last_names [int(rng.randi_range(0, last_names.size() - 1))])
	var profession: String = str(professions [int(rng.randi_range(0, professions.size() - 1))])

	return {
		"person_id": generated_id,
		"name": "%s %s" % [first_name, last_name],
		"profession": profession,
		"restaurant_id": restaurant_id,
		"room_zone": _restaurant_public_zone_for_restaurant(restaurant, rng),
		"meal_estimate": round(rng.randf_range(8.0, 120.0) * 100.0) / 100.0,
		"entered_at_ms": now_ms,
		"updated_at_ms": now_ms,
		"linger_until_ms": now_ms + int(rng.randi_range(6200, 22000)),
		"left_restaurant": false,
		"ambient_generated": true
	}


func _restaurant_public_target_visitor_count(restaurant_id: String, restaurant: Dictionary) -> int:
	var min_count: int = _restaurant_public_min_visitor_count(restaurant)
	var max_count: int = _restaurant_public_max_visitor_count(restaurant)
	var bucket: int = int(floor(float(Time.get_ticks_msec()) / 17000.0))
	var span: int = max(1, max_count - min_count + 1)
	var swing: int = abs(int(hash("%s|restaurant_crowd|%s" % [restaurant_id, str(bucket)]))) % span
	return clamp(min_count + swing, min_count, max_count)


func _restaurant_public_min_visitor_count(restaurant: Dictionary) -> int:
	match _restaurant_category(restaurant):
		"fast_food":
			return 5
		"regular":
			return 6
		"luxury":
			return 3
		_:
			return 4


func _restaurant_public_max_visitor_count(restaurant: Dictionary) -> int:
	match _restaurant_category(restaurant):
		"fast_food":
			return 20
		"regular":
			return 18
		"luxury":
			return 11
		_:
			return 14


func _restaurant_arrival_wave_size(restaurant: Dictionary, rng: RandomNumberGenerator) -> int:
	match _restaurant_category(restaurant):
		"fast_food":
			return int(rng.randi_range(1, 5))
		"regular":
			return int(rng.randi_range(1, 4))
		"luxury":
			return int(rng.randi_range(1, 3))
		_:
			return int(rng.randi_range(1, 4))


func _restaurant_next_arrival_wave_delay_ms(restaurant: Dictionary, rng: RandomNumberGenerator) -> int:
	match _restaurant_category(restaurant):
		"fast_food":
			return int(rng.randi_range(2600, 7000))
		"regular":
			return int(rng.randi_range(3600, 9200))
		"luxury":
			return int(rng.randi_range(5200, 13000))
		_:
			return int(rng.randi_range(3400, 9000))


func _restaurant_staff_count(restaurant: Dictionary) -> int:
	match _restaurant_category(restaurant):
		"fast_food":
			return 2
		"regular":
			return 3
		"luxury":
			return 5
		_:
			return 2


func _restaurant_public_zone_for_restaurant(restaurant: Dictionary, rng: RandomNumberGenerator) -> String:
	var zones: Array = []
	match _restaurant_category(restaurant):
		"fast_food":
			zones = ["counter line", "pickup shelf", "corner table", "drink station", "booth"]
		"regular":
			zones = ["host stand", "booth", "table", "waiting area", "server lane"]
		"luxury":
			zones = ["reservation desk", "private table", "bar lounge", "tasting room", "coat check"]
		_:
			zones = ["table", "counter", "waiting area", "booth"]

	return str(zones [int(rng.randi_range(0, zones.size() - 1))])


func _restaurant_public_rng(seed_text: String) -> RandomNumberGenerator:
	var rng:= RandomNumberGenerator.new()
	var seed_value: int = int(hash(str(seed_text)))
	if seed_value < 0:
		seed_value = - seed_value
	if seed_value <= 0:
		seed_value = 1
	rng.seed = seed_value
	return rng


func _restaurant_person_name(person: Person) -> String:
	if person == null:
		return "Unknown visitor"

	var full_name: String = ("%s %s" % [str(person.first_name), str(person.last_name)]).strip_edges()
	if full_name == "":
		full_name = str(person.name).strip_edges()
	if full_name == "":
		full_name = "Unknown visitor"

	return full_name


func _restaurant_person_profession(person: Person) -> String:
	if person == null:
		return "Customer"

	var job_text: String = str(person.job).strip_edges()
	if job_text != "":
		return job_text

	var fame_job_text: String = str(person.fame_job).strip_edges()
	if fame_job_text != "":
		return fame_job_text

	if int(person.age) < 18:
		return "Student"

	return "Customer"


func _restaurant_generated_first_names() -> Array:
	return [
		"Ari", "Maya", "Jordan", "Selene", "Noah", "Priya", "Dante", "Nia",
		"Ellis", "Amara", "Grant", "Brielle", "Isaiah", "Talia", "Kade", "Renee"
	]


func _restaurant_generated_last_names() -> Array:
	return [
		"Hart", "Cole", "Brooks", "Reed", "Wells", "Porter", "Cross", "Stone",
		"Bell", "Banks", "Vale", "Hayes", "Lane", "Price", "Monroe", "Sterling"
	]


func _restaurant_generated_professions() -> Array:
	return [
		"Teacher", "Nurse", "Office Worker", "Chef", "Student", "Engineer",
		"Artist", "Security Guard", "Entrepreneur", "Mechanic", "Streamer",
		"Delivery Driver", "Soldier", "Personal Trainer", "Barista", "Parent"
	]
func _actor_has_vehicle(actor: Person) -> bool:
	if gs == null or gs.vehicle_engine == null:
		return false
	var vehicles: Dictionary = gs.vehicle_engine.vehicles if typeof(gs.vehicle_engine.vehicles) == TYPE_DICTIONARY else {}
	return vehicles.has(int(actor.id)) or vehicles.has(str(actor.id))

func _apply_date_boost(actor: Person, partner_id: int, restaurant: Dictionary) -> void:
	if gs == null:
		return
	var partner: Person = gs.get_npc_by_id(partner_id)
	if partner == null:
		return
	var boost: int = int(restaurant.get("date_affection_boost", 4))
	partner.affection [int(actor.id)] = clamp(int(partner.affection.get(int(actor.id), 50)) + boost, 0, 100)
	actor.affection [int(partner.id)] = clamp(int(actor.affection.get(int(partner.id), 50)) + boost, 0, 100)

func _era_name_from_context(context: Dictionary = {}) -> String:
	var clean: String = str(context.get("era_name", "")).strip_edges()
	if clean != "":
		return clean
	if gs != null and gs.era != null:
		return str(gs.era.name)
	return "Modern Era"
func _actor_from_context(context: Dictionary = {}) -> Person:
	if gs == null:
		return null

	var actor_id: int = int(context.get("actor_id", context.get("npc_id", -1)))
	if actor_id > 0 and gs.has_method("get_npc_by_id"):
		var actor: Person = gs.get_npc_by_id(actor_id)
		if actor != null:
			return actor

	return gs.player


func _restaurant_cart_for_actor(actor: Person) -> Dictionary:
	if actor == null:
		return {}

	var key: String = str(int(actor.id))
	if not restaurant_carts_by_actor_id.has(key):
		restaurant_carts_by_actor_id [key] = {
			"restaurant_id": "",
			"restaurant_name": "",
			"items": [],
			"created_at_ms": int(Time.get_ticks_msec())
		}

	return restaurant_carts_by_actor_id [key].duplicate(true)


func _restaurant_cart_total(cart: Dictionary) -> float:
	var total: float = 0.0
	var items: Array = cart.get("items", []) if typeof(cart.get("items", [])) == TYPE_ARRAY else []
	for raw_item in items:
		if typeof(raw_item) != TYPE_DICTIONARY:
			continue

		var item: Dictionary = raw_item
		total += float(item.get("price", 0.0)) * float(max(1, int(item.get("quantity", 1))))

	return total


func _restaurant_date_state(actor: Person) -> Dictionary:
	if actor == null:
		return {}

	var key: String = str(int(actor.id))
	if not restaurant_date_state_by_actor_id.has(key):
		restaurant_date_state_by_actor_id [key] = {
			"mode": "alone",
			"date_partner_id": -1,
			"date_partner_name": "",
			"candidate_id": -1,
			"candidate_index": -1,
			"date_score": 50,
			"turn": 1,
			"created_at_ms": int(Time.get_ticks_msec())
		}

	return restaurant_date_state_by_actor_id [key].duplicate(true)


func _restaurant_session_has_date_partner(actor: Person) -> bool:
	if actor == null:
		return false

	var state: Dictionary = _restaurant_date_state(actor)
	return int(state.get("date_partner_id", -1)) > 0


func _current_romantic_partner(actor: Person) -> Person:
	if actor == null:
		return null

	if actor.partner != null and actor.partner.alive:
		return actor.partner

	if gs == null:
		return null

	for npc in gs.npcs:
		if npc == null or not npc.alive:
			continue

		if int(npc.id) == int(actor.id):
			continue

		if npc.partner != null and int(npc.partner.id) == int(actor.id):
			return npc

	return null


func _date_candidates_for_actor(actor: Person) -> Array:
	var out: Array = []
	if actor == null or gs == null:
		return out

	var actor_gender: String = str(actor.gender).strip_edges().to_lower()
	for npc in gs.npcs:
		if npc == null or not npc.alive:
			continue

		if int(npc.id) == int(actor.id):
			continue

		if int(npc.age) < max(15, int(actor.age) - 6):
			continue

		if int(npc.age) > int(actor.age) + 8:
			continue

		var npc_gender: String = str(npc.gender).strip_edges().to_lower()
		if actor_gender == "male" and npc_gender != "female":
			continue
		if actor_gender == "female" and npc_gender != "male":
			continue

		out.append(npc)

	return out


func _date_candidate_chemistry(actor: Person, candidate: Person) -> int:
	if actor == null or candidate == null:
		return 0

	var base: int = 38
	base += int(float(candidate.affection.get(int(actor.id), 50)) / 5.0)
	base += int(float(actor.looks) / 8.0)
	base += int(float(candidate.looks) / 10.0)
	base += int(float(actor.smarts) / 16.0)
	base += int(float(candidate.smarts) / 18.0)
	return clamp(base, 0, 100)


func _date_candidate_perception(actor: Person, candidate: Person) -> String:
	var chemistry: int = _date_candidate_chemistry(actor, candidate)
	if chemistry >= 78:
		return "very interested, almost like they were hoping you would notice them"
	if chemistry >= 60:
		return "curious and open to seeing where this goes"
	if chemistry >= 42:
		return "unsure, but not closed off"
	return "polite, distant, and hard to impress"


func _date_candidate_description(candidate: Person) -> String:
	var traits_text: String = ", ".join(candidate.traits) if typeof(candidate.traits) == TYPE_ARRAY and not candidate.traits.is_empty() else "hard to read"
	return "%s has %d looks, %d smarts, %d health, and gives off a %s energy." % [
		str(candidate.first_name),
		int(candidate.looks),
		int(candidate.smarts),
		int(candidate.health),
		traits_text
	]
func _restaurant_date_question_for_turn(partner: Person, turn: int, chemistry: int) -> String:
	var name_text: String = str(partner.first_name) if partner != null else "They"
	var turn_index: int = abs(int(turn)) % 5

	if chemistry >= 76:
		match turn_index:
			0:
				return "%s asks, \"What kind of life are you trying to build?\"" % name_text
			1:
				return "%s leans in and asks what scares you about getting close to somebody." % name_text
			2:
				return "%s smiles and asks what your perfect night would look like." % name_text
			3:
				return "%s asks if you believe people meet for a reason." % name_text
			_:
				return "%s studies your face like they already know this night matters." % name_text

	if chemistry >= 50:
		match turn_index:
			0:
				return "%s asks what you usually do for fun." % name_text
			1:
				return "%s asks about your family and where you come from." % name_text
			2:
				return "%s asks what kind of food you actually love." % name_text
			3:
				return "%s asks what you want your future to feel like." % name_text
			_:
				return "%s waits for you to carry the conversation forward." % name_text

	match turn_index:
		0:
			return "%s asks a safe question and keeps their guard up." % name_text
		1:
			return "%s looks around the restaurant before asking about your job." % name_text
		2:
			return "%s gives a polite smile, waiting to see if you can make this less awkward." % name_text
		3:
			return "%s asks where you usually eat, but their tone is hard to read." % name_text
		_:
			return "%s seems unsure, but they have not checked out yet." % name_text

func _date_can_hook_up(actor: Person, partner: Person, score: int) -> bool:
	if actor == null or partner == null:
		return false
	if int(actor.age) < 18 or int(partner.age) < 18:
		return false
	return int(score) >= 72


func _create_restaurant_fling(actor: Person, partner: Person) -> void:
	if actor == null or partner == null or gs == null:
		return

	if actor.partner != null and int(actor.partner.id) == int(partner.id):
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var ids: Array = gs.scenario_state.get("restaurant_fling_ids", []) if typeof(gs.scenario_state.get("restaurant_fling_ids", [])) == TYPE_ARRAY else []
	if not ids.has(int(partner.id)):
		ids.append(int(partner.id))

	gs.scenario_state ["restaurant_fling_ids"] = ids
	gs.scenario_state ["last_restaurant_fling"] = {
		"actor_id": int(actor.id),
		"partner_id": int(partner.id),
		"partner_name": "%s %s" % [str(partner.first_name), str(partner.last_name)],
		"year": int(gs.year),
		"at_ms": int(Time.get_ticks_msec())
	}

	if gs.relationship_engine != null:
		gs.relationship_engine.adjust_relationship(actor, partner, 9)


func _restaurant_category(restaurant: Dictionary) -> String:
	var explicit: String = str(restaurant.get("category", "")).strip_edges().to_lower()
	if explicit != "":
		return explicit

	var tier: String = str(restaurant.get("tier", "")).strip_edges().to_lower()
	var minimum_price: int = int(restaurant.get("minimum_price", 0))
	var fame_required: int = int(restaurant.get("fame_required", 0))

	if tier.find("fast") >= 0:
		return "fast_food"
	if tier.find("luxury") >= 0 or minimum_price >= 250 or fame_required >= 25:
		return "luxury"
	return "regular"


func _restaurant_category_label(category: String) -> String:
	match str(category).strip_edges().to_lower():
		"fast_food":
			return "Fast Food"
		"luxury":
			return "Luxury"
		_:
			return "Regular"


func _restaurant_checkout_text(restaurant: Dictionary, service_mode: String, started_date_turn: bool) -> String:
	var restaurant_name: String = str(restaurant.get("name", "the restaurant"))
	match str(service_mode).strip_edges().to_lower():
		"drive_through":
			return "I got food from the drive-thru at %s." % restaurant_name
		"dine_in":
			if started_date_turn:
				return "We sat down at %s. The date started." % restaurant_name
			return "I dined in at %s." % restaurant_name
		_:
			return "I got takeout from %s." % restaurant_name


func _restaurant_entry_paid(actor: Person, restaurant_id: String) -> bool:
	if actor == null:
		return false

	var state: Dictionary = _restaurant_date_state(actor)
	var paid: Dictionary = state.get("entry_paid", {}) if typeof(state.get("entry_paid", {})) == TYPE_DICTIONARY else {}
	return bool(paid.get(restaurant_id, false))


func _mark_restaurant_entry_paid(actor: Person, restaurant_id: String) -> void:
	if actor == null:
		return

	var state: Dictionary = _restaurant_date_state(actor)
	var paid: Dictionary = state.get("entry_paid", {}) if typeof(state.get("entry_paid", {})) == TYPE_DICTIONARY else {}
	paid [restaurant_id] = true
	state ["entry_paid"] = paid
	restaurant_date_state_by_actor_id [str(int(actor.id))] = state


func _him_her(person: Person, capitalize_first: bool = false) -> String:
	var gender: String = str(person.gender if person != null else "").strip_edges().to_lower()
	var word: String = "them"
	if gender == "male":
		word = "him"
	elif gender == "female":
		word = "her"

	if capitalize_first:
		return word.capitalize()

	return word
func _default_restaurant_contract() -> Dictionary:
	return {
		"schema": "eralife.food_restaurant_contract",
		"version": RESTAURANT_VERSION,
		"eras": {
			"Modern Era": [
				{
					"id": "burger_bishop",
					"name": "Burger Bishop",
					"tier": "fast_food",
					"quality": "cheap",
					"minimum_price": 6,
					"fame_required": 0,
					"supports_drive_through": true,
					"date_affection_boost": 1,
					"menu": [
						{ "id": "bishop_stack", "name": "Bishop Stack", "price": 8, "hunger_restore": 34, "nutrition": 24, "sodium": 10, "sugar": 3, "quality": "cheap"},
						{ "id": "holy_fries", "name": "Holy Fries", "price": 4, "hunger_restore": 18, "nutrition": 12, "sodium": 12, "quality": "cheap"}
					]
				},
				{
					"id": "taco_choir",
					"name": "Taco Choir",
					"tier": "fast_food",
					"quality": "street_fresh",
					"minimum_price": 5,
					"fame_required": 0,
					"supports_drive_through": true,
					"date_affection_boost": 2,
					"menu": [
						{ "id": "three_verse_tacos", "name": "Three-Verse Tacos", "price": 9, "hunger_restore": 36, "nutrition": 38, "protein": 8, "sodium": 7, "quality": "street_fresh"},
						{ "id": "choir_churros", "name": "Choir Churros", "price": 5, "hunger_restore": 20, "nutrition": 14, "sugar": 12, "quality": "sweet"}
					]
				},
				{
					"id": "winged_spoon",
					"name": "The Winged Spoon",
					"tier": "casual",
					"quality": "balanced",
					"minimum_price": 18,
					"fame_required": 0,
					"supports_drive_through": false,
					"date_affection_boost": 5,
					"menu": [
						{ "id": "sunset_salmon_plate", "name": "Sunset Salmon Plate", "price": 28, "hunger_restore": 42, "nutrition": 78, "protein": 12, "vitamins": 10, "quality": "balanced"},
						{ "id": "garden_rice_bowl", "name": "Garden Rice Bowl", "price": 16, "hunger_restore": 35, "nutrition": 70, "vitamins": 12, "quality": "balanced"}
					]
				},
				{
					"id": "midnight_waffle_house",
					"name": "Midnight Waffle House",
					"tier": "casual",
					"quality": "comfort",
					"minimum_price": 12,
					"fame_required": 0,
					"supports_drive_through": false,
					"date_affection_boost": 3,
					"menu": [
						{ "id": "storm_hour_waffles", "name": "Storm Hour Waffles", "price": 14, "hunger_restore": 40, "nutrition": 30, "sugar": 8, "quality": "comfort"},
						{ "id": "all_night_hash_plate", "name": "All-Night Hash Plate", "price": 13, "hunger_restore": 38, "nutrition": 36, "protein": 6, "quality": "comfort"}
					]
				},
				{
					"id": "greenroom_grill",
					"name": "Greenroom Grill",
					"tier": "premium",
					"quality": "healthy_premium",
					"minimum_price": 45,
					"fame_required": 10,
					"supports_drive_through": false,
					"date_affection_boost": 8,
					"menu": [
						{ "id": "tour_bus_power_bowl", "name": "Tour Bus Power Bowl", "price": 52, "hunger_restore": 46, "nutrition": 88, "protein": 14, "vitamins": 14, "quality": "healthy_premium"},
						{ "id": "golden_juice_pairing", "name": "Golden Juice Pairing", "price": 21, "hunger_restore": 18, "nutrition": 74, "vitamins": 18, "quality": "premium"}
					]
				},
				{
					"id": "velvet_orbit",
					"name": "Velvet Orbit",
					"tier": "luxury",
					"quality": "elite",
					"minimum_price": 750,
					"fame_required": 35,
					"supports_drive_through": false,
					"date_affection_boost": 14,
					"menu": [
						{ "id": "moonlit_truffle_table", "name": "Moonlit Truffle Table", "price": 1250, "hunger_restore": 52, "nutrition": 90, "protein": 10, "vitamins": 14, "quality": "elite"},
						{ "id": "velvet_saffron_course", "name": "Velvet Saffron Course", "price": 950, "hunger_restore": 48, "nutrition": 86, "protein": 9, "vitamins": 12, "quality": "elite"}
					]
				},
				{
					"id": "saint_aurora_table",
					"name": "Saint Aurora Table",
					"tier": "ultra_luxury",
					"quality": "legendary",
					"minimum_price": 5000,
					"fame_required": 70,
					"supports_drive_through": false,
					"date_affection_boost": 22,
					"menu": [
						{ "id": "aurora_ancestor_tasting", "name": "Aurora Ancestor Tasting", "price": 7200, "hunger_restore": 60, "nutrition": 98, "protein": 16, "vitamins": 20, "quality": "legendary"}
					]
				}
			],
			"Future Era": [
				{
					"id": "nebula_noodle_lounge",
					"name": "Nebula Noodle Lounge",
					"tier": "fast_future",
					"quality": "synthetic_balanced",
					"minimum_price": 30,
					"fame_required": 0,
					"supports_drive_through": true,
					"date_affection_boost": 4,
					"menu": [
						{ "id": "gravity_broth_bowl", "name": "Gravity Broth Bowl", "price": 35, "hunger_restore": 40, "nutrition": 74, "protein": 8, "vitamins": 8, "quality": "synthetic_balanced"},
						{ "id": "ion_crisp_wrap", "name": "Ion Crisp Wrap", "price": 28, "hunger_restore": 34, "nutrition": 68, "protein": 7, "vitamins": 9, "quality": "synthetic_balanced"}
					]
				},
				{
					"id": "orbit_drive_byte",
					"name": "Orbit Drive Byte",
					"tier": "future_fast_food",
					"quality": "convenient",
					"minimum_price": 18,
					"fame_required": 0,
					"supports_drive_through": true,
					"date_affection_boost": 2,
					"menu": [
						{ "id": "holo_burger_cube", "name": "Holo Burger Cube", "price": 22, "hunger_restore": 36, "nutrition": 44, "protein": 9, "sodium": 5, "quality": "convenient"}
					]
				},
				{
					"id": "aurelian_table",
					"name": "The Aurelian Table",
					"tier": "ultra_luxury",
					"quality": "elite",
					"minimum_price": 4000,
					"fame_required": 65,
					"supports_drive_through": false,
					"date_affection_boost": 20,
					"menu": [
						{ "id": "starlight_tasting_sequence", "name": "Starlight Tasting Sequence", "price": 6500, "hunger_restore": 58, "nutrition": 96, "protein": 12, "vitamins": 18, "quality": "elite"}
					]
				}
			]
		}
	}