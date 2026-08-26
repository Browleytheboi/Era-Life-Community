extends Resource
class_name CardContractEngine

const ENGINE_SCHEMA:= "eralife.card_contract_engine"
const CONTRACT_VERSION:= 1

var gs: GameState = null


func _init(_gs: GameState = null) -> void:
	bind_game_state(_gs)


func bind_game_state(_gs: GameState) -> void:
	gs = _gs


func project_market_surface(
	market_kind: String,
	actor: Person,
	surface_contract: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	var clean_kind: String = str(market_kind).strip_edges().to_lower()
	var out: Dictionary = surface_contract.duplicate(true)
	var cards: Array = _safe_array(out.get("listing_card_contracts", []))
	var projected_cards: Array = []

	for raw_card in cards:
		var card: Dictionary = _safe_dictionary(raw_card)
		if card.is_empty():
			continue

		projected_cards.append(
			_project_market_card(
				clean_kind,
				actor,
				card,
				context
			)
		)

	if projected_cards.is_empty():
		projected_cards = _observable_pending_cards(clean_kind, actor)

	out ["listing_card_contracts"] = projected_cards
	out ["listing_count"] = projected_cards.size()
	out ["card_projection_schema"] = ENGINE_SCHEMA
	out ["card_projection_version"] = CONTRACT_VERSION
	out ["card_contract_engine_applied"] = true
	out ["card_visual_contracts_ready"] = true
	out ["cards_are_observable_even_if_truth_is_partial"] = true
	out ["ui_is_renderer_only"] = true
	out ["ui_builds_cards_forbidden"] = true

	return out


func _project_market_card(
	market_kind: String,
	actor: Person,
	card: Dictionary,
	_context: Dictionary
) -> Dictionary:
	var out: Dictionary = card.duplicate(true)
	var tier: String = str(
		out.get(
			"dealership_tier",
			out.get("value_band", out.get("social_tier", "standard"))
		)
	).strip_edges().to_lower()

	var visual: Dictionary = _visual_contract_for_market_card(
		market_kind,
		tier
	)
	var actions: Array = _safe_array(out.get("actions", []))
	var top_options: Array = []

	for raw_action in actions:
		var action: Dictionary = _safe_dictionary(raw_action)
		if action.is_empty():
			continue

		var action_id: String = str(action.get("action_id", "")).strip_edges()
		var option: Dictionary = action.duplicate(true)
		option ["icon"] = _icon_for_market_action(action_id)
		option ["surface_position"] = "selected_card_top_bloom"
		option ["visual_contract"] = {
			"accent_color": visual.get("accent_color"),
			"bloom_color": visual.get("bloom_color"),
			"dark_surface_color": visual.get("dark_surface_color"),
			"rounded": true,
		}
		top_options.append(option)

	out ["market_kind"] = market_kind
	out ["card_visual_contract"] = visual
	out ["top_option_contracts"] = top_options
	out ["selection_contract"] = {
	}
	out ["actor_id"] = int(actor.id) if actor != null else -1
	out ["card_contract_schema"] = "eralife.market.card_contract"
	out ["card_contract_version"] = CONTRACT_VERSION
	out ["card_projection_authority"] = ENGINE_SCHEMA
	out ["ui_is_renderer_only"] = true

	return out


func _visual_contract_for_market_card(
	market_kind: String,
	tier: String
) -> Dictionary:
	var clean_kind: String = str(market_kind).strip_edges().to_lower()
	var clean_tier: String = str(tier).strip_edges().to_lower()

	var accent: Color = Color(0.96, 0.72, 0.32, 1.0)
	var bloom: Color = Color(1.0, 0.56, 0.18, 1.0)
	var dark_surface: Color = Color(0.075, 0.05, 0.032, 0.98)

	if clean_kind == "vehicle":
		accent = Color(0.34, 0.76, 1.0, 1.0)
		bloom = Color(0.16, 0.9, 1.0, 1.0)
		dark_surface = Color(0.025, 0.06, 0.09, 0.98)

	match clean_tier:
		"premium":
			accent = accent.lerp(Color(0.62, 0.42, 1.0, 1.0), 0.38)
		"luxury":
			accent = Color(1.0, 0.74, 0.22, 1.0)
			bloom = Color(1.0, 0.42, 0.12, 1.0)
		"premium_luxury", "ultra_luxury":
			accent = Color(1.0, 0.38, 0.78, 1.0)
			bloom = Color(0.72, 0.34, 1.0, 1.0)
			dark_surface = Color(0.09, 0.028, 0.078, 0.98)
		"wealthy", "estate", "mansion":
			accent = Color(1.0, 0.8, 0.32, 1.0)
			bloom = Color(1.0, 0.52, 0.18, 1.0)

	return {
		"accent_color": accent,
		"bloom_color": bloom,
		"dark_surface_color": dark_surface,
		"hover_glow": true,
		"selected_bloom_strength": 1.0,
		"normal_bloom_strength": 0.34,
		"rounded_corner_radius": 18,
		"animation_contract": {
			"hover_scale": 1.018,
			"selected_breathe_speed": 1.8
		}
	}


func _observable_pending_cards(
	market_kind: String,
	actor: Person
) -> Array:
	var clean_kind: String = str(market_kind).strip_edges().to_lower()
	var title: String = "Property listings resolving"
	var subtitle: String = "Property market truth exists but is still hydrating."

	if clean_kind == "vehicle":
		title = "Vehicle listings resolving"
		subtitle = "Vehicle market truth exists but is still hydrating."

	var card: Dictionary = {
		"listing_id": "observable_pending:%s:%d" % [
			clean_kind,
			int(actor.id) if actor != null else -1
		],
		"title": title,
		"price_text": "Market truth pending",
		"meta_line": subtitle,
		"truth_state": "observable_partial",
		"actions": [],
		"ui_is_renderer_only": true
	}

	return [
		_project_market_card(
			clean_kind,
			actor,
			card,
			{}
		)
	]


func _icon_for_market_action(action_id: String) -> String:
	match str(action_id).strip_edges().to_lower():
		"inspect":
			return "🔎"
		"buy_outright", "buy_vehicle":
			return "💳"
		"rent_monthly":
			return "🔑"
		"apply_mortgage":
			return "🏦"
		"finance_vehicle":
			return "📄"
		"lease_vehicle":
			return "🗓️"
		_:
			return "✦"


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []