extends Resource
class_name LuxuryShopEngine

const LUXURY_VERSION:= 1

const EXCHANGE_SCHEMA:= (
	"eralife.luxury.exchange_surface_contract"
)
const EXCHANGE_CARD_SCHEMA:= (
	"eralife.luxury.exchange_card_contract"
)
const EXCHANGE_MAX_NATIVE_CARDS:= 64
const EXCHANGE_MAX_ARTIFACT_CARDS:= 4
const EXCHANGE_MAX_VEHICLE_CARDS:= 3
const EXCHANGE_MAX_PROPERTY_CARDS:= 3

var gs
var luxury_contract: Dictionary = {}
var luxury_ledger: Array = []
var last_report: Dictionary = {}
var luxury_observation_memory: Dictionary = {
	"centerpiece_hover_audio_delivery_version": 2,
	"centerpiece_hover_audio_ever_played": false,
	"centerpiece_hover_audio_first_play_year": -999999,
	"centerpiece_hover_audio_last_play_year": -999999,
	"centerpiece_hover_audio_play_count": 0,
	"centerpiece_hover_audio_authorized_years": {},
	"centerpiece_hover_audio_authorized_playback_keys": {},
	"centerpiece_hover_audio_played_years": {}
}
func _normalize_luxury_observation_memory(
	value: Variant
) -> Dictionary:
	var out: Dictionary = (
		(value as Dictionary).duplicate(true)
		if typeof(value) == TYPE_DICTIONARY
		else {}
	)

	var delivery_version: int = int(
		out.get(
			"centerpiece_hover_audio_delivery_version",
			1
		)
	)

	if not out.has(
		"centerpiece_hover_audio_ever_played"
	):
		out [
			"centerpiece_hover_audio_ever_played"
		] = false

	if not out.has(
		"centerpiece_hover_audio_first_play_year"
	):
		out [
			"centerpiece_hover_audio_first_play_year"
		] = -999999

	if not out.has(
		"centerpiece_hover_audio_last_play_year"
	):
		out [
			"centerpiece_hover_audio_last_play_year"
		] = -999999

	if not out.has(
		"centerpiece_hover_audio_play_count"
	):
		out [
			"centerpiece_hover_audio_play_count"
		] = 0

	var played_years: Dictionary = _safe_dictionary(
		out.get(
			"centerpiece_hover_audio_played_years",
			{}
		)
	).duplicate(true)
	var authorized_years: Dictionary = _safe_dictionary(
		out.get(
			"centerpiece_hover_audio_authorized_years",
			{}
		)
	).duplicate(true)
	var authorized_playback_keys: Dictionary = _safe_dictionary(
		out.get(
			"centerpiece_hover_audio_authorized_playback_keys",
			{}
		)
	).duplicate(true)







	if delivery_version < 2:
		for raw_year_key in played_years.keys():
			var year_key: String = str(
				raw_year_key
			)

			authorized_years [
				year_key
			] = true

		played_years = {}
		out [
			"centerpiece_hover_audio_ever_played"
		] = false
		out [
			"centerpiece_hover_audio_first_play_year"
		] = -999999
		out [
			"centerpiece_hover_audio_last_play_year"
		] = -999999
		out [
			"centerpiece_hover_audio_play_count"
		] = 0

	out [
		"centerpiece_hover_audio_delivery_version"
	] = 2
	out [
		"centerpiece_hover_audio_authorized_years"
	] = authorized_years
	out [
		"centerpiece_hover_audio_authorized_playback_keys"
	] = authorized_playback_keys
	out [
		"centerpiece_hover_audio_played_years"
	] = played_years

	return out
func _init(_gs = null):
	gs = _gs
	luxury_contract = _default_luxury_contract()

func get_luxury_shop_rows(context: Dictionary = {}) -> Array:
	var era_name: String = _era_name_from_context(context)
	var out: Array = []

	for shop in get_shops_for_era(era_name):
		var shop_id: String = str(shop.get("id", "")).strip_edges()
		out.append({
			"label": "%s • fame gate %d" % [
				str(shop.get("name", "Luxury Shop")),
				int(shop.get("fame_required", 0))
			],
			"description": str(shop.get("description", "A contract-backed shop with separated luxury and artifact inventory.")),
			"shop_id": shop_id,
			"kind": "luxury_shop",
			"fame_required": int(shop.get("fame_required", 0)),
			"actions": [
				{
					"id": "luxury_items:%s" % shop_id,
					"label": "Browse",
					"kind": "packet",
					"style": "primary"
				}
			]
		})

	return out

func get_luxury_item_rows(context: Dictionary = {}) -> Array:
	var shop_id: String = str(context.get("shop_id", "")).strip_edges()
	var shop: Dictionary = get_shop(shop_id)
	var out: Array = []

	var notice: String = str(context.get("notice", "")).strip_edges()
	if notice != "":
		out.append({
			"label": "Status",
			"description": notice,
			"kind": "luxury_notice"
		})

	if shop.is_empty():
		if shop_id == "":
			out.append({
				"label": "Choose a shop first",
				"description": "Go back to Shops and pick a luxury shop or artifact vault.",
				"kind": "luxury_empty_items"
			})
		else:
			out.append({
				"label": "Shop not found",
				"description": "The selected luxury shop contract could not be resolved.",
				"kind": "luxury_missing_shop"
			})
		return out

	var inventory: Array = shop.get("inventory", []) if typeof(shop.get("inventory", [])) == TYPE_ARRAY else []
	for raw_item in inventory:
		if typeof(raw_item) != TYPE_DICTIONARY:
			continue

		var item: Dictionary = raw_item
		var item_id: String = str(item.get("id", "")).strip_edges()
		var category: String = str(item.get("category", item.get("type", "Luxury"))).strip_edges()
		var icon: String = _luxury_icon_for_item(item)
		var color: int = _luxury_color_for_item(item)

		out.append({
			"label": "%s %s • $%d • %s" % [
				icon,
				str(item.get("name", "Luxury Item")),
				int(item.get("price", 0)),
				category
			],
			"description": str(item.get("lore", item.get("description", "A luxury item with provenance."))).substr(0, 280),
			"shop_id": shop_id,
			"item_id": item_id,
			"kind": "luxury_item",
			"category": category,
			"material": str(item.get("material", "jewel")),
			"item_type": str(item.get("type", "Item")),
			"price": int(item.get("price", 0)),
			"value": int(item.get("value", item.get("price", 0))),
			"theme": {
				"discord_color": color
			},
			"discord_color": color,
			"actions": [
				{
					"id": "luxury_overview:%s:%s" % [shop_id, item_id],
					"label": "Overview",
					"kind": "packet",
					"style": "primary"
				},
				{
					"id": "luxury_buy:%s:%s" % [shop_id, item_id],
					"label": "Buy",
					"kind": "packet",
					"style": "success"
				}
			]
		})

	out.sort_custom(func (a, b):
		var ca: String = str((a as Dictionary).get("category", ""))
		var cb: String = str((b as Dictionary).get("category", ""))
		if ca == cb:
			return str((a as Dictionary).get("label", "")) < str((b as Dictionary).get("label", ""))
		return ca < cb
	)

	return out
func get_luxury_item_overview_rows(context: Dictionary = {}) -> Array:
	var shop_id: String = str(context.get("shop_id", "")).strip_edges()
	var item_id: String = str(context.get("item_id", "")).strip_edges()
	var shop: Dictionary = get_shop(shop_id)
	var out: Array = []

	var notice: String = str(context.get("notice", "")).strip_edges()
	if notice != "":
		out.append({
			"label": "Status",
			"description": notice,
			"kind": "luxury_notice"
		})

	if shop.is_empty() or item_id == "":
		out.append({
			"label": "No item selected",
			"description": "Return to Items and choose Overview on a specific item.",
			"kind": "luxury_item_overview_empty"
		})
		return out

	var item: Dictionary = _find_shop_item(shop, item_id)
	if item.is_empty():
		out.append({
			"label": "Item not found",
			"description": "That item does not exist in this shop contract.",
			"kind": "luxury_item_missing"
		})
		return out

	var color: int = _luxury_color_for_item(item)
	var icon: String = _luxury_icon_for_item(item)
	var lore: String = str(item.get("lore", item.get("description", "No lore has been written for this item yet."))).strip_edges()

	out.append({
		"label": "%s %s" % [icon, str(item.get("name", "Luxury Item"))],
		"description": "%s\n\nType: %s\nMaterial: %s\nCategory: %s\nPrice: $%d\nValue: $%d" % [
			lore,
			str(item.get("type", "Item")),
			str(item.get("material", "unknown")),
			str(item.get("category", "Luxury")),
			int(item.get("price", 0)),
			int(item.get("value", item.get("price", 0)))
		],
		"shop_id": shop_id,
		"item_id": item_id,
		"kind": "luxury_item_overview",
		"theme": {
			"discord_color": color
		},
		"discord_color": color,
		"actions": [
			{
				"id": "luxury_buy:%s:%s" % [shop_id, item_id],
				"label": "Buy",
				"kind": "packet",
				"style": "success"
			},
			{
				"id": "luxury_back:items",
				"label": "Items",
				"kind": "packet",
				"style": "secondary"
			}
		]
	})

	return out


func _luxury_icon_for_item(item: Dictionary) -> String:
	var category: String = str(item.get("category", item.get("type", ""))).strip_edges().to_lower()
	var material: String = str(item.get("material", "")).strip_edges().to_lower()
	var type_text: String = str(item.get("type", "")).strip_edges().to_lower()

	if category.find("artifact") >= 0:
		return "🗿"
	if type_text.find("ring") >= 0:
		return "💍"
	if material.find("diamond") >= 0:
		return "💎"
	if material.find("pearl") >= 0:
		return "🦪"
	if category.find("heirloom") >= 0:
		return "🏺"
	if category.find("relic") >= 0:
		return "🔮"

	return "✨"


func _luxury_color_for_item(item: Dictionary) -> int:
	var category: String = str(item.get("category", item.get("type", ""))).strip_edges().to_lower()
	var material: String = str(item.get("material", "")).strip_edges().to_lower()

	if category.find("artifact") >= 0:
		return 9323693
	if category.find("relic") >= 0:
		return 7101671
	if category.find("heirloom") >= 0:
		return 13938487
	if material.find("diamond") >= 0:
		return 6139362
	if material.find("pearl") >= 0:
		return 16314879

	return 15105570

func buy_luxury_item(
	actor: Person,
	shop_id: String,
	item_id: String,
	context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "No actor supplied."
		}

	var shop: Dictionary = get_shop(
		shop_id
	)

	if shop.is_empty():
		return {
			"success": false,
			"reason": "Luxury shop not found."
		}

	var fame_required: int = int(
		shop.get(
			"fame_required",
			0
		)
	)

	if int(actor.fame) < fame_required:
		return {
			"success": false,
			"reason": (
				"%s requires fame level %d."
				% [
					str(
						shop.get(
							"name",
							"This luxury shop"
						)
					),
					fame_required
				]
			)
		}

	var item: Dictionary = (
		_find_shop_item(
			shop,
			item_id
		)
	)

	if item.is_empty():
		return {
			"success": false,
			"reason": "Luxury item not found."
		}

	var category: String = str(
		item.get(
			"category",
			item.get(
				"type",
				"Luxury"
			)
		)
	).strip_edges().to_lower()



	if category == "artifact":
		return {
			"success": false,
			"reason": (
				"Artifact acquisition belongs to "
				+ "ArtifactShopContractEngine."
			),
			"required_authority": (
				"artifact_shop_contract_engine"
			)
		}

	var source_era: String = str(
		shop.get(
			"catalog_era",
			_era_for_shop_id(
				shop_id
			)
		)
	)
	var current_era: String = (
		_era_name_from_context(
			context
		)
	)
	var current_year: int = (
		int(gs.year)
		if gs != null
		else 0
	)

	var historical: bool = (
		_era_index(source_era)
		< _era_index(current_era)
	)

	if (
		historical
		and not bool(
			item.get(
				"historical_persistence",
				false
			)
		)
	):
		return {
			"success": false,
			"reason": (
				"That object does not persist into "
				+ "this era's circulating luxury market."
			)
		}

	if (
		not _luxury_item_circulates_this_year(
			item,
			source_era,
			current_era,
			current_year
		)
	):
		return {
			"success": false,
			"reason": (
				"That object is no longer circulating "
				+ "in this year's private market."
			)
		}

	var resident_examples: int = int(
		item.get(
			"resident_examples",
			0
		)
	)

	if (
		resident_examples == 1
		and _luxury_unique_item_was_acquired(
			item_id
		)
	):
		return {
			"success": false,
			"reason": (
				"That one-of-one object has already "
				+ "left the circulating market."
			)
		}

	var market_quote: Dictionary = (
		_luxury_market_quote(
			item,
			source_era,
			current_era,
			current_year
		)
	)
	var dealer_ask: float = float(
		market_quote.get(
			"dealer_ask",
			item.get(
				"price",
				0.0
			)
		)
	)

	var pay_report: Dictionary = _pay(
		actor,
		dealer_ask,
		{
			"source": "luxury_shop_engine",
			"shop_id": shop_id,
			"item_id": item_id,
			"market_quote": (
				market_quote.duplicate(false)
			)
		}
	)

	if not bool(
		pay_report.get(
			"success",
			false
		)
	):
		return pay_report

	var classification: String = (
		_luxury_classification_for_item(
			item,
			historical
		)
	)
	var owned_item: Dictionary = (
		item.duplicate(true)
	)

	owned_item [
		"personal_item_id"
	] = _make_luxury_item_instance_id(
		actor,
		owned_item
	)
	owned_item [
		"usable_for_proposal"
	] = _is_proposal_worthy_item(
		owned_item
	)
	owned_item [
		"shop_id"
	] = shop_id
	owned_item [
		"shop_name"
	] = str(
		shop.get(
			"name",
			"Luxury Shop"
		)
	)
	owned_item [
		"source_era"
	] = source_era
	owned_item [
		"luxury_classification"
	] = classification
	owned_item [
		"market_value_at_purchase"
	] = int(
		market_quote.get(
			"market_value",
			dealer_ask
		)
	)
	owned_item [
		"dealer_ask_at_purchase"
	] = int(
		round(
			dealer_ask
		)
	)
	owned_item [
		"acquired_year"
	] = current_year
	owned_item [
		"provenance"
	] = {
		"source": "luxury_shop_engine",
		"shop_id": shop_id,
		"source_era": source_era,
		"purchase_year": current_year,
		"price_paid": dealer_ask,
		"market_value_at_purchase": int(
			market_quote.get(
				"market_value",
				dealer_ask
			)
		),
		"market_pressure": str(
			market_quote.get(
				"market_pressure_label",
				"STEADY"
			)
		),
		"prior_provenance": str(
			item.get(
				"provenance_status",
				"Documented"
			)
		)
	}

	if (
		gs != null
		and gs.belongings_engine != null
	):
		gs.belongings_engine.add_item(
			actor,
			owned_item,
			"Luxury",
			false
		)

	var report: Dictionary = {
		"success": true,
		"committed": true,
		"mode": "luxury_exchange_acquisition",
		"actor_id": int(actor.id),
		"shop_id": shop_id,
		"item_id": item_id,
		"item": owned_item.duplicate(true),
		"market_quote": (
			market_quote.duplicate(false)
		),
		"payment_report": (
			pay_report.duplicate(true)
		),
		"text": (
			"I acquired %s from %s for %s."
			% [
				str(
					owned_item.get(
						"name",
						"a luxury item"
					)
				),
				str(
					shop.get(
						"name",
						"the luxury exchange"
					)
				),
				_format_luxury_money(
					int(
						round(
							dealer_ask
						)
					)
				)
			]
		)
	}

	luxury_ledger.append(
		report.duplicate(true)
	)

	report [
		"market_revision"
	] = luxury_ledger.size()

	last_report = (
		report.duplicate(true)
	)

	return report
func resolve_intent(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "missing_actor"
		}

	var action_id: String = str(
		payload.get(
			"action_id",
			"view_exchange"
		)
	).strip_edges().to_lower()

	match action_id:
		"view_exchange", "refresh_exchange":
			return {
				"success": true,
				"mode": "luxury_exchange_observation",
				"surface_contract": (
					emit_exchange_surface_contract(
						actor,
						payload
					)
				),
				"ui_is_renderer_only": true
			}

		"observe_centerpiece_hover":
			return (
				_commit_luxury_centerpiece_hover_observation(
					actor,
					payload
				)
			)

		"confirm_centerpiece_hover_audio_delivery":
			return (
				_commit_luxury_centerpiece_hover_audio_delivery(
					actor,
					payload
				)
			)

		"acquire_luxury_item", "request_acquisition":
			return buy_luxury_item(
				actor,
				str(
					payload.get(
						"shop_id",
						""
					)
				),
				str(
					payload.get(
						"item_id",
						""
					)
				),
				payload
			)

		_:
			return {
				"success": false,
				"reason": (
					"unsupported_luxury_exchange_intent"
				)
			}
func _commit_luxury_centerpiece_hover_observation(
	actor: Person,
	payload: Dictionary
) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "missing_actor"
		}

	if gs == null:
		return {
			"success": false,
			"reason": "missing_game_state"
		}

	var current_year: int = int(
		gs.year
	)
	var observed_year: int = int(
		payload.get(
			"market_year",
			current_year
		)
	)
	var card_id: String = str(
		payload.get(
			"card_id",
			""
		)
	).strip_edges()
	var centerpiece_card_id: String = str(
		payload.get(
			"centerpiece_card_id",
			""
		)
	).strip_edges()

	if observed_year != current_year:
		return {
			"success": false,
			"committed": false,
			"reason": "stale_luxury_market_year",
			"observed_year": observed_year,
			"canonical_year": current_year,
			"audio_authorized": false,
			"affects_market_projection": false
		}

	if (
		not bool(
			payload.get(
				"centerpiece",
				false
			)
		)
		or card_id == ""
		or centerpiece_card_id == ""
		or card_id != centerpiece_card_id
	):
		return {
			"success": false,
			"committed": false,
			"reason": "invalid_centerpiece_observation_contract",
			"audio_authorized": false,
			"affects_market_projection": false
		}

	var era_name: String = str(
		payload.get(
			"era_name",
			""
		)
	).strip_edges()

	if era_name == "":
		era_name = _era_name_from_context(
			payload
		)

	var expected_rotation_signature: int = (
		_stable_luxury_hash(
			"%s|luxury_orrery|%d"
			% [
				era_name,
				current_year
			]
		)
	)
	var observed_rotation_signature: int = int(
		payload.get(
			"market_rotation_signature",
			expected_rotation_signature
		)
	)

	if (
		observed_rotation_signature
		!= expected_rotation_signature
	):
		return {
			"success": false,
			"committed": false,
			"reason": "stale_luxury_rotation_signature",
			"canonical_rotation_signature": (
				expected_rotation_signature
			),
			"observed_rotation_signature": (
				observed_rotation_signature
			),
			"audio_authorized": false,
			"affects_market_projection": false
		}

	luxury_observation_memory = (
		_normalize_luxury_observation_memory(
			luxury_observation_memory
		)
	)

	var played_years: Dictionary = _safe_dictionary(
		luxury_observation_memory.get(
			"centerpiece_hover_audio_played_years",
			{}
		)
	).duplicate(true)
	var authorized_years: Dictionary = _safe_dictionary(
		luxury_observation_memory.get(
			"centerpiece_hover_audio_authorized_years",
			{}
		)
	).duplicate(true)
	var authorized_playback_keys: Dictionary = _safe_dictionary(
		luxury_observation_memory.get(
			"centerpiece_hover_audio_authorized_playback_keys",
			{}
		)
	).duplicate(true)
	var year_key: String = str(
		current_year
	)

	if bool(
		played_years.get(
			year_key,
			false
		)
	):
		var already_consumed:= {
			"success": true,
			"committed": false,
			"mode": (
				"luxury_centerpiece_hover_already_observed"
			),
			"reason": (
				"centerpiece_hover_audio_"
				+ "already_consumed_for_market_year"
			),
			"actor_id": int(actor.id),
			"market_year": current_year,
			"card_id": card_id,
			"audio_authorized": false,
			"affects_market_projection": false,
			"ui_is_renderer_only": true
		}

		last_report = (
			already_consumed.duplicate(true)
		)
		return already_consumed

	var first_ever: bool = not bool(
		luxury_observation_memory.get(
			"centerpiece_hover_audio_ever_played",
			false
		)
	)
	var playback_key: String = (
		"luxury_centerpiece_shiny|%d|%d"
		% [
			current_year,
			expected_rotation_signature
		]
	)
	var already_authorized: bool = (
		bool(
			authorized_years.get(
				year_key,
				false
			)
		)
		and str(
			authorized_playback_keys.get(
				year_key,
				""
			)
		) == playback_key
	)

	authorized_years [
		year_key
	] = true
	authorized_playback_keys [
		year_key
	] = playback_key

	luxury_observation_memory [
		"centerpiece_hover_audio_authorized_years"
	] = authorized_years
	luxury_observation_memory [
		"centerpiece_hover_audio_authorized_playback_keys"
	] = authorized_playback_keys

	var report:= {
		"success": true,
		"committed": not already_authorized,
		"mode": (
			"luxury_centerpiece_hover_audio_reauthorized"
			if already_authorized
			else "luxury_centerpiece_hover_observation_committed"
		),
		"actor_id": int(actor.id),
		"market_year": current_year,
		"card_id": card_id,
		"audio_authorized": true,
		"first_ever_centerpiece_hover": first_ever,
		"mutation_performed": not already_authorized,
		"mutation_scope": "luxury_observation_memory",
		"affects_market_projection": false,
		"audio_presentation_contract": {
			"schema": (
				"eralife.luxury."
				+ "centerpiece_hover_audio_contract"
			),
			"version": 2,
			"cue_id": "luxury_centerpiece_shiny",
			"file_name": "Shiny.ogg",
			"playback_key": playback_key,
			"market_year": current_year,
			"card_id": card_id,
			"first_ever": first_ever,
			"stop_on_unhover": true,
			"loop": false,
		}
	}

	last_report = report.duplicate(true)

	return report
func _commit_luxury_centerpiece_hover_audio_delivery(
	actor: Person,
	payload: Dictionary
) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"committed": false,
			"reason": "missing_actor",
			"affects_market_projection": false
		}

	luxury_observation_memory = (
		_normalize_luxury_observation_memory(
			luxury_observation_memory
		)
	)

	var market_year: int = int(
		payload.get(
			"market_year",
			-999999
		)
	)
	var playback_key: String = str(
		payload.get(
			"playback_key",
			""
		)
	).strip_edges()

	if (
		market_year == -999999
		or playback_key == ""
	):
		return {
			"success": false,
			"committed": false,
			"reason": "invalid_centerpiece_audio_delivery_receipt",
			"affects_market_projection": false
		}

	var year_key: String = str(
		market_year
	)
	var authorized_years: Dictionary = _safe_dictionary(
		luxury_observation_memory.get(
			"centerpiece_hover_audio_authorized_years",
			{}
		)
	).duplicate(true)
	var authorized_playback_keys: Dictionary = _safe_dictionary(
		luxury_observation_memory.get(
			"centerpiece_hover_audio_authorized_playback_keys",
			{}
		)
	).duplicate(true)
	var played_years: Dictionary = _safe_dictionary(
		luxury_observation_memory.get(
			"centerpiece_hover_audio_played_years",
			{}
		)
	).duplicate(true)

	if bool(
		played_years.get(
			year_key,
			false
		)
	):
		return {
			"success": true,
			"committed": false,
			"mode": "luxury_centerpiece_audio_delivery_already_committed",
			"reason": "centerpiece_hover_audio_already_delivered",
			"market_year": market_year,
			"actor_id": int(actor.id),
			"affects_market_projection": false
		}

	if (
		not bool(
			authorized_years.get(
				year_key,
				false
			)
		)
		or str(
			authorized_playback_keys.get(
				year_key,
				""
			)
		) != playback_key
	):
		return {
			"success": false,
			"committed": false,
			"reason": "centerpiece_audio_delivery_not_authorized",
			"market_year": market_year,
			"actor_id": int(actor.id),
			"affects_market_projection": false
		}

	var first_ever: bool = not bool(
		luxury_observation_memory.get(
			"centerpiece_hover_audio_ever_played",
			false
		)
	)

	played_years [
		year_key
	] = true
	authorized_years.erase(
		year_key
	)
	authorized_playback_keys.erase(
		year_key
	)

	luxury_observation_memory [
		"centerpiece_hover_audio_played_years"
	] = played_years
	luxury_observation_memory [
		"centerpiece_hover_audio_authorized_years"
	] = authorized_years
	luxury_observation_memory [
		"centerpiece_hover_audio_authorized_playback_keys"
	] = authorized_playback_keys
	luxury_observation_memory [
		"centerpiece_hover_audio_ever_played"
	] = true
	luxury_observation_memory [
		"centerpiece_hover_audio_last_play_year"
	] = market_year
	luxury_observation_memory [
		"centerpiece_hover_audio_play_count"
	] = int(
		luxury_observation_memory.get(
			"centerpiece_hover_audio_play_count",
			0
		)
	) + 1

	if first_ever:
		luxury_observation_memory [
			"centerpiece_hover_audio_first_play_year"
		] = market_year

	var report: Dictionary = {
		"success": true,
		"committed": true,
		"mode": "luxury_centerpiece_audio_delivery_committed",
		"actor_id": int(actor.id),
		"market_year": market_year,
		"playback_key": playback_key,
		"first_ever": first_ever,
		"mutation_scope": "luxury_observation_memory",
		"affects_market_projection": false
	}

	last_report = report.duplicate(true)

	return report

func _luxury_orrery_editorial_profile(
	card: Dictionary
) -> Dictionary:
	var section_id: String = str(
		card.get(
			"section_id",
			"collectibles"
		)
	).strip_edges().to_lower()
	var item_type: String = str(
		card.get(
			"item_type",
			"Luxury Object"
		)
	).strip_edges().to_lower()
	var title: String = str(
		card.get(
			"title",
			""
		)
	).strip_edges().to_lower()
	var semantic_text: String = (
		item_type
		+ " "
		+ title
	)

	var span: String = "standard_1x1"
	var inner_scale: float = 0.5
	var outer_scale: float = 0.66
	var outer_preferred: bool = false

	match section_id:
		"watches":
			span = "portrait_1x2"
			inner_scale = 0.52
			outer_scale = 0.78

		"jewelry":
			if (
				semantic_text.find("necklace") >= 0
				or semantic_text.find("bracelet") >= 0
				or semantic_text.find("cuff") >= 0
				or semantic_text.find("collar") >= 0
				or semantic_text.find("rivière") >= 0
				or semantic_text.find("riviere") >= 0
			):
				span = "landscape_2x1"
				inner_scale = 0.44
				outer_scale = 0.75
				outer_preferred = true
			elif (
				semantic_text.find("crown") >= 0
				or semantic_text.find("tiara") >= 0
				or semantic_text.find("diadem") >= 0
			):
				span = "portrait_1x2"
				inner_scale = 0.48
				outer_scale = 0.84
				outer_preferred = true
			else:


				span = "standard_1x1"
				inner_scale = 0.5
				outer_scale = 0.66

		"art":
			outer_preferred = true

			if (
				semantic_text.find("painting") >= 0
				or semantic_text.find("portrait") >= 0
				or semantic_text.find("canvas") >= 0
			):
				span = "portrait_1x2"
				inner_scale = 0.46
				outer_scale = 0.9
			elif (
				semantic_text.find("sculpture") >= 0
				or semantic_text.find("bust") >= 0
				or semantic_text.find("statue") >= 0
			):
				span = "portrait_1x2"
				inner_scale = 0.44
				outer_scale = 0.84
			else:
				span = "landscape_2x1"
				inner_scale = 0.44
				outer_scale = 0.8

		"fashion":
			outer_preferred = true

			if (
				semantic_text.find("couture") >= 0
				or semantic_text.find("robe") >= 0
				or semantic_text.find("gown") >= 0
				or semantic_text.find("mantle") >= 0
				or semantic_text.find("cloak") >= 0
			):
				span = "portrait_1x2"
				inner_scale = 0.46
				outer_scale = 0.84
			elif semantic_text.find("bag") >= 0:
				span = "standard_1x1"
				inner_scale = 0.48
				outer_scale = 0.68
			else:
				span = "landscape_2x1"
				inner_scale = 0.44
				outer_scale = 0.8

		"collectibles":
			if (
				semantic_text.find("manuscript") >= 0
				or semantic_text.find("book") >= 0
				or semantic_text.find("treaty") >= 0
				or semantic_text.find("tablet") >= 0
				or semantic_text.find("psalter") >= 0
			):
				span = "portrait_1x2"
				inner_scale = 0.46
				outer_scale = 0.88
				outer_preferred = true
			elif (
				semantic_text.find("sword") >= 0
				or semantic_text.find("blade") >= 0
				or semantic_text.find("saber") >= 0
				or semantic_text.find("sabre") >= 0
				or semantic_text.find("dagger") >= 0
				or semantic_text.find("khopesh") >= 0
				or semantic_text.find("weapon") >= 0
				or semantic_text.find("helm") >= 0
				or semantic_text.find("armor") >= 0
			):
				span = "portrait_1x2"
				inner_scale = 0.42
				outer_scale = 0.76
				outer_preferred = true
			elif (
				semantic_text.find("sculpture") >= 0
				or semantic_text.find("bust") >= 0
				or semantic_text.find("statue") >= 0
			):
				span = "portrait_1x2"
				inner_scale = 0.44
				outer_scale = 0.84
				outer_preferred = true
			elif (
				semantic_text.find("coin") >= 0
				or semantic_text.find("medallion") >= 0
				or semantic_text.find("wafer") >= 0
				or semantic_text.find("gem") >= 0
				or semantic_text.find("seal") >= 0
			):
				span = "standard_1x1"
				inner_scale = 0.5
				outer_scale = 0.66
			elif (
				semantic_text.find("bar") >= 0
				or semantic_text.find("ingot") >= 0
			):
				span = "landscape_2x1"
				inner_scale = 0.42
				outer_scale = 0.72
				outer_preferred = true
			elif (
				semantic_text.find("chalice") >= 0
				or semantic_text.find("reliquary") >= 0
				or semantic_text.find("amphora") >= 0
				or semantic_text.find("vessel") >= 0
				or semantic_text.find("antiquity") >= 0
			):
				span = "standard_1x1"
				inner_scale = 0.48
				outer_scale = 0.68
			else:
				span = "landscape_2x1"
				inner_scale = 0.44
				outer_scale = 0.8
				outer_preferred = true

		"vehicles":
			span = "landscape_2x1"
			inner_scale = 0.44
			outer_scale = 0.76
			outer_preferred = true

		"property":
			span = "landscape_2x1"
			inner_scale = 0.44
			outer_scale = 0.76
			outer_preferred = true

		"artifacts":
			span = "standard_1x1"
			inner_scale = 0.5
			outer_scale = 0.68

		_:
			span = "standard_1x1"
			inner_scale = 0.5
			outer_scale = 0.66

	return {
		"span": span,
		"inner_scale": inner_scale,
		"outer_scale": outer_scale,
		"outer_preferred": outer_preferred
	}
func _luxury_exchange_editorial_tier(
	card: Dictionary
) -> int:
	var classification: String = str(
		card.get(
			"classification_family",
			card.get(
				"classification",
				"AVAILABLE"
			)
		)
	).strip_edges().to_upper()



	if classification == "ARTIFACT":
		return (
			990
			if bool(
				card.get(
					"limited_time_crosslist",
					false
				)
			)
			else 930
		)

	match classification:
		"ONE OF ONE":
			return 1000

		"EXCEPTIONAL":
			return 900

		"HISTORIC":
			return 800

		"COLLECTOR":
			return 700

		"LIMITED":
			return 600

		_:
			return 500
func _luxury_exchange_reality_seed() -> int:
	if gs == null:
		return 0

	if typeof(
		gs.scenario_state
	) == TYPE_DICTIONARY:
		var scenario_seed: int = int(
			gs.scenario_state.get(
				"world_seed",
				-1
			)
		)

		if scenario_seed > 0:
			return scenario_seed

	if typeof(
		gs.custom_settings
	) == TYPE_DICTIONARY:
		var custom_seed: int = int(
			gs.custom_settings.get(
				"world_seed",
				-1
			)
		)

		if custom_seed > 0:
			return custom_seed

	if (
		gs.seed_engine != null
		and "seed_value" in gs.seed_engine
	):
		var engine_seed: int = int(
			gs.seed_engine.seed_value
		)

		if engine_seed > 0:
			return engine_seed

	return 0
func _luxury_exchange_reality_identity_key() -> String:
	if gs == null:
		return "unbound"

	var life_id: String = ""
	var timeline_id: String = ""

	if typeof(
		gs.scenario_state
	) == TYPE_DICTIONARY:
		life_id = str(
			gs.scenario_state.get(
				"life_id",
				""
			)
		).strip_edges()
		timeline_id = str(
			gs.scenario_state.get(
				"timeline_id",
				""
			)
		).strip_edges()

		var identity: Dictionary = _safe_dictionary(
			gs.scenario_state.get(
				"life_identity",
				{}
			)
		)

		if life_id == "":
			life_id = str(
				identity.get(
					"life_id",
					""
				)
			).strip_edges()

		if timeline_id == "":
			timeline_id = str(
				identity.get(
					"timeline_id",
					""
				)
			).strip_edges()

	var reality_seed: int = (
		_luxury_exchange_reality_seed()
	)

	if (
		life_id != ""
		or timeline_id != ""
	):
		return (
			"life:%s|timeline:%s|world:%d"
			% [
				life_id,
				timeline_id,
				reality_seed
			]
		)

	if reality_seed > 0:
		return (
			"world:%d"
			% reality_seed
		)

	return "unbound"


func _luxury_exchange_editorial_salt(
	era_name: String,
	market_year: int,
	channel: String
) -> String:
	return (
		"%s|era:%s|year:%d|channel:%s"
		% [
			_luxury_exchange_reality_identity_key(),
			era_name,
			market_year,
			channel
		]
	)


func _luxury_exchange_annual_rotation_index(
	era_name: String,
	market_year: int,
	channel: String,
	cardinality: int
) -> int:
	if cardinality <= 1:
		return 0

	var origin_index: int = (
		_stable_luxury_hash(
			"%s|era:%s|channel:%s|rotation_origin"
			% [
				_luxury_exchange_reality_identity_key(),
				era_name,
				channel
			]
		)
		% cardinality
	)
	var year_offset: int = (
		market_year % cardinality
	)

	if year_offset < 0:
		year_offset += cardinality

	return (
		origin_index
		+ year_offset
	) % cardinality


func _luxury_exchange_centerpiece_identity(
	card: Dictionary
) -> String:
	var ownership_domain: String = str(
		card.get(
			"ownership_domain",
			"luxury"
		)
	).strip_edges().to_lower()

	if ownership_domain == "artifact":
		var artifact_definition_id: String = str(
			card.get(
				"item_id",
				""
			)
		).strip_edges().to_lower()

		if artifact_definition_id != "":



			return (
				"artifact:%s"
				% artifact_definition_id
			)

	var card_id: String = str(
		card.get(
			"card_id",
			""
		)
	).strip_edges()

	return (
		"%s:%s"
		% [
			ownership_domain,
			card_id
		]
	)
func _luxury_exchange_yearly_showcase_key(
	card: Dictionary,
	era_name: String,
	market_year: int
) -> int:
	var card_id: String = str(
		card.get(
			"card_id",
			"unknown_luxury_card"
		)
	)
	var ownership_domain: String = str(
		card.get(
			"ownership_domain",
			"luxury"
		)
	)
	var editorial_salt: String = (
		_luxury_exchange_editorial_salt(
			era_name,
			market_year,
			"showcase_card:%s:%s"
			% [
				ownership_domain,
				card_id
			]
		)
	)

	return _stable_luxury_hash(
		editorial_salt
	)
func _luxury_exchange_card_is_ring(
	card: Dictionary
) -> bool:
	var semantic_text: String = (
		str(
			card.get(
				"item_type",
				""
			)
		)
		+ " "
		+ str(
			card.get(
				"title",
				""
			)
		)
	).strip_edges().to_lower()

	return semantic_text.find(
		"ring"
	) >= 0


func _luxury_exchange_centerpiece_card(
	ranked_cards: Array,
	era_name: String,
	market_year: int
) -> Dictionary:
	var centerpiece_candidates: Array = []
	var seen_editorial_identities: Dictionary = {}

	for raw_card in ranked_cards:
		if typeof(
			raw_card
		) != TYPE_DICTIONARY:
			continue

		var card: Dictionary = (
			raw_card as Dictionary
		)
		var editorial_tier: int = int(
			card.get(
				"exchange_editorial_tier",
				0
			)
		)
		var editorial_rank: int = int(
			card.get(
				"editorial_rank",
				0
			)
		)
		var dealer_ask: int = int(
			card.get(
				"dealer_ask",
				card.get(
					"market_value",
					0
				)
			)
		)

		if (
			editorial_tier < 900
			and editorial_rank < 820
			and dealer_ask < 250000000
		):
			continue

		var editorial_identity: String = (
			_luxury_exchange_centerpiece_identity(
				card
			)
		)

		if (
			editorial_identity == ""
			or seen_editorial_identities.has(
				editorial_identity
			)
		):
			continue

		seen_editorial_identities [
			editorial_identity
		] = true

		centerpiece_candidates.append(
			card
		)




	if centerpiece_candidates.is_empty():
		seen_editorial_identities.clear()

		for raw_card in ranked_cards:
			if typeof(
				raw_card
			) != TYPE_DICTIONARY:
				continue

			var fallback_card: Dictionary = (
				raw_card as Dictionary
			)
			var fallback_identity: String = (
				_luxury_exchange_centerpiece_identity(
					fallback_card
				)
			)

			if (
				fallback_identity == ""
				or seen_editorial_identities.has(
					fallback_identity
				)
			):
				continue

			seen_editorial_identities [
				fallback_identity
			] = true

			centerpiece_candidates.append(
				fallback_card
			)

	if centerpiece_candidates.is_empty():
		return {}

	centerpiece_candidates.sort_custom(
		func (a, b):
			var card_a: Dictionary = (
				a as Dictionary
			)
			var card_b: Dictionary = (
				b as Dictionary
			)
			var tier_a: int = int(
				card_a.get(
					"exchange_editorial_tier",
					0
				)
			)
			var tier_b: int = int(
				card_b.get(
					"exchange_editorial_tier",
					0
				)
			)

			if tier_a != tier_b:
				return tier_a > tier_b

			var rank_a: int = int(
				card_a.get(
					"editorial_rank",
					0
				)
			)
			var rank_b: int = int(
				card_b.get(
					"editorial_rank",
					0
				)
			)

			if rank_a != rank_b:
				return rank_a > rank_b

			return int(
				card_a.get(
					"dealer_ask",
					card_a.get(
						"market_value",
						0
					)
				)
			) > int(
				card_b.get(
					"dealer_ask",
					card_b.get(
						"market_value",
						0
					)
				)
			)
	)

	var centerpiece_pool_size: int = mini(
		8,
		centerpiece_candidates.size()
	)
	var centerpiece_index: int = (
		_luxury_exchange_annual_rotation_index(
			era_name,
			market_year,
			"centerpiece",
			centerpiece_pool_size
		)
	)

	return (
		centerpiece_candidates [
			centerpiece_index
		] as Dictionary
	)

func _luxury_exchange_mark_showcase_card(
	selected_ids: Dictionary,
	card: Dictionary,
	capacity: int
) -> bool:
	if selected_ids.size() >= capacity:
		return false

	var card_id: String = str(
		card.get(
			"card_id",
			""
		)
	).strip_edges()

	if (
		card_id == ""
		or selected_ids.has(
			card_id
		)
	):
		return false

	selected_ids [
		card_id
	] = true

	return true


func _luxury_exchange_showcase_selection(
	ranked_cards: Array,
	centerpiece: Dictionary,
	capacity: int,
	era_name: String,
	market_year: int
) -> Array:
	var out: Array = []

	if (
		ranked_cards.is_empty()
		or centerpiece.is_empty()
		or capacity <= 0
	):
		return out

	var selected_ids: Dictionary = {}
	var centerpiece_id: String = str(
		centerpiece.get(
			"card_id",
			""
		)
	).strip_edges()

	if centerpiece_id == "":
		return out

	selected_ids [
		centerpiece_id
	] = true



	var selected_ring_count: int = (
		1
		if _luxury_exchange_card_is_ring(
			centerpiece
		)
		else 0
	)

	for raw_card in ranked_cards:
		if (
			selected_ring_count >= 2
			or selected_ids.size() >= capacity
		):
			break

		if typeof(raw_card) != TYPE_DICTIONARY:
			continue

		var card: Dictionary = raw_card as Dictionary

		if not _luxury_exchange_card_is_ring(
			card
		):
			continue

		if _luxury_exchange_mark_showcase_card(
			selected_ids,
			card,
			capacity
		):
			selected_ring_count += 1




	var section_order: Array = [
		"jewelry",
		"watches",
		"art",
		"fashion",
		"collectibles",
		"vehicles",
		"property",
		"artifacts"
	]
	var section_offset: int = (
		_luxury_exchange_annual_rotation_index(
			era_name,
			market_year,
			"section_priority",
			section_order.size()
		)
	)
	for section_step in range(
		section_order.size()
	):
		if selected_ids.size() >= capacity:
			break

		var section_index: int = (
			section_offset
			+ section_step
		) % section_order.size()
		var section_id: String = str(
			section_order [
				section_index
			]
		)

		for raw_card in ranked_cards:
			if typeof(raw_card) != TYPE_DICTIONARY:
				continue

			var card: Dictionary = raw_card as Dictionary

			if str(
				card.get(
					"section_id",
					""
				)
			) != section_id:
				continue

			if _luxury_exchange_mark_showcase_card(
				selected_ids,
				card,
				capacity
			):
				break



	var selected_jewelry_count: int = 0

	for raw_card in ranked_cards:
		if typeof(raw_card) != TYPE_DICTIONARY:
			continue

		var card: Dictionary = raw_card as Dictionary
		var card_id: String = str(
			card.get(
				"card_id",
				""
			)
		)

		if (
			selected_ids.has(
				card_id
			)
			and str(
				card.get(
					"section_id",
					""
				)
			) == "jewelry"
		):
			selected_jewelry_count += 1

	for raw_card in ranked_cards:
		if (
			selected_jewelry_count >= 6
			or selected_ids.size() >= capacity
		):
			break

		if typeof(raw_card) != TYPE_DICTIONARY:
			continue

		var card: Dictionary = raw_card as Dictionary

		if str(
			card.get(
				"section_id",
				""
			)
		) != "jewelry":
			continue

		if _luxury_exchange_mark_showcase_card(
			selected_ids,
			card,
			capacity
		):
			selected_jewelry_count += 1



	for raw_card in ranked_cards:
		if selected_ids.size() >= capacity:
			break

		if typeof(raw_card) != TYPE_DICTIONARY:
			continue

		_luxury_exchange_mark_showcase_card(
			selected_ids,
			raw_card as Dictionary,
			capacity
		)




	out.append(
		centerpiece
	)

	for raw_card in ranked_cards:
		if typeof(raw_card) != TYPE_DICTIONARY:
			continue

		var card: Dictionary = raw_card as Dictionary
		var card_id: String = str(
			card.get(
				"card_id",
				""
			)
		).strip_edges()

		if (
			card_id == ""
			or card_id == centerpiece_id
			or not selected_ids.has(
				card_id
			)
		):
			continue

		out.append(
			card
		)

	return out
func emit_exchange_surface_contract(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "missing_actor"
		}

	var era_name: String = _era_name_from_context(context)
	var current_year: int = int(gs.year) if gs != null else 0
	var candidate_rows: Array = _luxury_exchange_candidate_rows(
		actor,
		era_name,
		current_year
	)
	var cards: Array = []
	var native_count: int = 0

	for raw_candidate in candidate_rows:
		if native_count >= EXCHANGE_MAX_NATIVE_CARDS:
			break

		if typeof(raw_candidate) != TYPE_DICTIONARY:
			continue

		var candidate: Dictionary = raw_candidate as Dictionary
		var card: Dictionary = _luxury_exchange_card_contract(
			actor,
			candidate,
			era_name,
			current_year
		)

		if card.is_empty():
			continue

		cards.append(
			card
		)
		native_count += 1

	for raw_card in _artifact_exchange_card_contracts(
		actor
	):
		if typeof(raw_card) != TYPE_DICTIONARY:
			continue

		cards.append(
			(raw_card as Dictionary).duplicate(false)
		)

	for raw_card in _vehicle_exchange_card_contracts(
		actor
	):
		if typeof(raw_card) != TYPE_DICTIONARY:
			continue

		cards.append(
			(raw_card as Dictionary).duplicate(false)
		)

	for raw_card in _property_exchange_card_contracts(
		actor
	):
		if typeof(raw_card) != TYPE_DICTIONARY:
			continue

		cards.append(
			(raw_card as Dictionary).duplicate(false)
		)

	for raw_card in cards:
		if typeof(raw_card) != TYPE_DICTIONARY:
			continue

		var card: Dictionary = raw_card as Dictionary
		card ["exchange_editorial_tier"] = (
			_luxury_exchange_editorial_tier(
				card
			)
		)
		card ["exchange_yearly_showcase_key"] = (
			_luxury_exchange_yearly_showcase_key(
				card,
				era_name,
				current_year
			)
		)


	cards.sort_custom(
		func (a, b):
			var card_a: Dictionary = a as Dictionary
			var card_b: Dictionary = b as Dictionary
			var tier_a: int = int(
				card_a.get(
					"exchange_editorial_tier",
					0
				)
			)
			var tier_b: int = int(
				card_b.get(
					"exchange_editorial_tier",
					0
				)
			)

			if tier_a != tier_b:
				return tier_a > tier_b

			var yearly_key_a: int = int(
				card_a.get(
					"exchange_yearly_showcase_key",
					0
				)
			)
			var yearly_key_b: int = int(
				card_b.get(
					"exchange_yearly_showcase_key",
					0
				)
			)

			if yearly_key_a != yearly_key_b:
				return yearly_key_a > yearly_key_b

			var rank_a: int = int(
				card_a.get(
					"editorial_rank",
					0
				)
			)
			var rank_b: int = int(
				card_b.get(
					"editorial_rank",
					0
				)
			)

			if rank_a != rank_b:
				return rank_a > rank_b

			return int(
				card_a.get(
					"dealer_ask",
					card_a.get(
						"market_value",
						0
					)
				)
			) > int(
				card_b.get(
					"dealer_ask",
					card_b.get(
						"market_value",
						0
					)
				)
			)
	)




	var annual_capacity_target: int = (
		22
		+ _luxury_exchange_annual_rotation_index(
			era_name,
			current_year,
			"showcase_capacity",
			5
		)
	)
	var editorial_card_capacity: int = mini(
		annual_capacity_target,
		cards.size()
	)
	var centerpiece: Dictionary = (
		_luxury_exchange_centerpiece_card(
			cards,
			era_name,
			current_year
		)
	)

	if (
		not centerpiece.is_empty()
		and editorial_card_capacity > 0
	):
		cards = _luxury_exchange_showcase_selection(
			cards,
			centerpiece,
			editorial_card_capacity,
			era_name,
			current_year
		)
	else:
		cards.clear()

	var yearly_inner_origin_degrees: float = (
		-90.0
		+ float(
			_stable_luxury_hash(
				_luxury_exchange_editorial_salt(
					era_name,
					current_year,
					"inner_orrery_origin"
				)
			) % 3600
		) / 10.0
	)
	var yearly_outer_origin_degrees: float = (
		-90.0
		+ float(
			_stable_luxury_hash(
				_luxury_exchange_editorial_salt(
					era_name,
					current_year,
					"outer_orrery_origin"
				)
			) % 3600
		) / 10.0
	)
	var yearly_rotation_signature: int = (
		_stable_luxury_hash(
			_luxury_exchange_editorial_salt(
				era_name,
				current_year,
				"luxury_orrery"
			)
		)
	)

	var centerpiece_card_id: String = ""
	var featured_remaining: int = 5

	if not cards.is_empty():
		var hero: Dictionary = cards [0] as Dictionary
		centerpiece_card_id = str(
			hero.get(
				"card_id",
				""
			)
		)
		hero ["source_mosaic_span"] = str(
			hero.get(
				"mosaic_span",
				"standard_1x1"
			)
		)
		hero ["mosaic_span"] = "hero_2x2"
		hero ["featured"] = true
		hero ["centerpiece"] = true
		hero ["publication_role"] = "centerpiece"
		hero ["formation_role"] = "centerpiece"
		hero ["formation_band"] = "center"
		hero ["formation_slot"] = 0
		hero ["formation_slot_count"] = 1
		hero ["orbit_enabled"] = false
		hero ["orbit_clock_scope"] = "none"
		hero ["orbit_clock_id"] = ""
		hero ["hover_projection_enabled"] = true
		hero ["orrery_presentation_scale"] = 0.92
		hero ["orrery_outer_preferred"] = false

	for index in range(
		1,
		cards.size()
	):
		var raw_card: Variant = cards [index]

		if typeof(raw_card) != TYPE_DICTIONARY:
			continue

		var card: Dictionary = raw_card as Dictionary
		var profile: Dictionary = (
			_luxury_orrery_editorial_profile(
				card
			)
		)

		card ["source_mosaic_span"] = str(
			card.get(
				"mosaic_span",
				"standard_1x1"
			)
		)
		card ["mosaic_span"] = str(
			profile.get(
				"span",
				"standard_1x1"
			)
		)
		card ["orrery_inner_scale"] = float(
			profile.get(
				"inner_scale",
				0.5
			)
		)
		card ["orrery_outer_scale"] = float(
			profile.get(
				"outer_scale",
				0.66
			)
		)
		card ["orrery_outer_preferred"] = bool(
			profile.get(
				"outer_preferred",
				false
			)
		)

	var orbit_count: int = maxi(
		0,
		cards.size() - 1
	)
	var inner_target_count: int = orbit_count









	if orbit_count >= 19:
		var minimum_inner_count: int = maxi(
			8,
			orbit_count - 15
		)
		var maximum_inner_count: int = mini(
			10,
			orbit_count - 11
		)

		if maximum_inner_count >= minimum_inner_count:
			inner_target_count = (
				minimum_inner_count
				+ (
					_stable_luxury_hash(
						_luxury_exchange_editorial_salt(
							era_name,
							current_year,
							"inner_ring_population"
						)
					)
					% (
						maximum_inner_count
						- minimum_inner_count
						+ 1
					)
				)
			)
		else:
			inner_target_count = clampi(
				int(
					round(
						float(orbit_count) * 0.4
					)
				),
				8,
				10
			)
	elif orbit_count >= 12:
		inner_target_count = clampi(
			int(
				round(
					float(orbit_count) * 0.45
				)
			),
			6,
			8
		)
	elif orbit_count >= 6:
		inner_target_count = clampi(
			int(
				round(
					float(orbit_count) * 0.45
				)
			),
			3,
			5
		)
	elif orbit_count >= 4:
		inner_target_count = mini(
			orbit_count - 2,
			maxi(
				2,
				int(
					round(
						float(orbit_count) * 0.5
					)
				)
			)
		)

	var inner_cards: Array = []
	var remaining_cards: Array = []




	for index in range(
		1,
		cards.size()
	):
		var raw_card: Variant = cards [index]

		if typeof(raw_card) != TYPE_DICTIONARY:
			continue

		var card: Dictionary = raw_card as Dictionary
		var outer_preferred: bool = bool(
			card.get(
				"orrery_outer_preferred",
				false
			)
		)

		if (
			inner_cards.size() < inner_target_count
			and not outer_preferred
		):
			inner_cards.append(
				card
			)
		else:
			remaining_cards.append(
				card
			)

	while (
		inner_cards.size() < inner_target_count
		and not remaining_cards.is_empty()
	):
		inner_cards.append(
			remaining_cards.pop_front()
		)

	var outer_cards: Array = remaining_cards
	var composed_cards: Array = []

	if not cards.is_empty():
		composed_cards.append(
			cards [0]
		)

	for raw_card in inner_cards:
		composed_cards.append(
			raw_card
		)

	for raw_card in outer_cards:
		composed_cards.append(
			raw_card
		)

	cards = composed_cards

	var inner_orbit_count: int = inner_cards.size()
	var outer_orbit_count: int = outer_cards.size()

	for index in range(
		cards.size()
	):
		var raw_card: Variant = cards [index]

		if typeof(raw_card) != TYPE_DICTIONARY:
			continue

		var card: Dictionary = raw_card as Dictionary
		card ["publication_index"] = index
		card ["centerpiece"] = index == 0
		card ["publication_role"] = (
			"centerpiece"
			if index == 0
			else "satellite"
		)

		if bool(
			card.get(
				"featured",
				false
			)
		):
			featured_remaining = maxi(
				0,
				featured_remaining - 1
			)
		elif featured_remaining > 0:
			card ["featured"] = true
			featured_remaining -= 1

		if index == 0:
			continue

		var is_inner: bool = (
			index <= inner_orbit_count
		)
		var formation_band: String = (
			"inner_orbit"
			if is_inner
			else "outer_orbit"
		)
		var formation_slot: int = (
			index - 1
			if is_inner
			else (
				index
				- 1
				- inner_orbit_count
			)
		)
		var formation_slot_count: int = maxi(
			1,
			(
				inner_orbit_count
				if is_inner
				else outer_orbit_count
			)
		)
		var orbit_direction: int = (
			1
			if is_inner
			else -1
		)
		var orbit_duration_seconds: float = (
			72.0
			if is_inner
			else 96.0
		)
		var phase_origin_degrees: float = (
			yearly_inner_origin_degrees
			if is_inner
			else yearly_outer_origin_degrees
		)
		var phase_offset_degrees: float = 0.0

		if not is_inner:
			phase_offset_degrees = (
				180.0
				/ float(formation_slot_count)
			)

		card ["formation_role"] = "orbit_piece"
		card ["formation_band"] = formation_band
		card ["formation_slot"] = formation_slot
		card ["formation_slot_count"] = formation_slot_count
		card ["formation_phase_degrees"] = (
			phase_origin_degrees
			+ phase_offset_degrees
			+ 360.0
			* float(formation_slot)
			/ float(formation_slot_count)
		)
		card ["orbit_enabled"] = true
		card ["orbit_direction"] = orbit_direction
		card ["orbit_duration_seconds"] = (
			orbit_duration_seconds
		)
		card ["orbit_clock_scope"] = "shared_ring"
		card ["orbit_clock_id"] = formation_band
		card ["hover_projection_enabled"] = true
		card ["orrery_presentation_scale"] = float(
			card.get(
				(
					"orrery_inner_scale"
					if is_inner
					else "orrery_outer_scale"
				),
				(
					0.5
					if is_inner
					else 0.66
				)
			)
		)
		card ["orrery_market_year"] = current_year
		card ["orrery_rotation_signature"] = (
			yearly_rotation_signature
		)

	var published_native_count: int = 0

	for raw_card in cards:
		if typeof(raw_card) != TYPE_DICTIONARY:
			continue

		if str(
			(raw_card as Dictionary).get(
				"ownership_domain",
				""
			)
		) == "luxury":
			published_native_count += 1

	return {
		"success": true,
		"schema": EXCHANGE_SCHEMA,
		"version": LUXURY_VERSION,
		"actor_id": int(actor.id),
		"title": "THE LUXURY EXCHANGE",
		"subtitle": (
			"Private acquisitions • %s • %s"
			% [
				_format_luxury_year(
					current_year
				),
				_format_luxury_money(
					int(actor.bank_balance)
				)
			]
		),
		"era": era_name,
		"market_year": current_year,
		"market_rotation_signature": (
			yearly_rotation_signature
		),
		"funds": int(actor.bank_balance),
		"funds_text": _format_luxury_money(
			int(actor.bank_balance)
		),
		"tabs": _luxury_exchange_tabs(
			cards
		),
		"card_contracts": cards.duplicate(false),
		"card_count": cards.size(),
		"centerpiece_card_id": centerpiece_card_id,
		"layout_contract": {
			"renderer": "LuxuryExchangePanel",
			"layout": "kinetic_luxury_orrery",
			"formation": "centerpiece_with_collision_free_dual_ring",
			"frozen_hierarchy": "centerpiece_inner_outer",
			"hero_span": "hero_2x2",
			"landscape_span": "landscape_2x1",
			"portrait_span": "portrait_1x2",
			"standard_span": "standard_1x1",
			"auto_wrap": false,
			"annual_card_capacity_min": 22,
			"annual_card_capacity_max": 26,
			"editorial_card_capacity": editorial_card_capacity,
			"centerpiece_card_id": centerpiece_card_id,
			"ring_spacing": "equal_angular",
			"wide_piece_policy": "outer_preferred_then_density_scale_clamp",
			"inner_ring_count": inner_orbit_count,
			"inner_ring_capacity": 10,
			"outer_ring_count": outer_orbit_count,
			"outer_ring_capacity": 15,
			"dual_ring_active": outer_orbit_count > 0,
			"inner_phase_origin_degrees": (
				yearly_inner_origin_degrees
			),
			"outer_phase_origin_degrees": (
				yearly_outer_origin_degrees
			),
			"rotation_market_year": current_year,
			"rotation_signature": yearly_rotation_signature,
			"orbit_motion": "shared_ring_phase",
			"orbit_guides": "persistent_animated_presentation_rails",
			"orbit_rail_layers": [
					"atmospheric_bloom",
					"primary_core",
					"directional_travel",
					"orbital_nodes",
					"micro_ticks",
					"faint_echo",
					"localized_focus_arc"
			],
			"satellite_presentation_classes": [
					"jewel",
					"horology",
					"couture",
					"fine_art",
					"collector_object",
					"artifact_relic",
					"grand_asset"
			],
			"presentation_class_source": "resident_section_and_type_projection",
			"ring_motion": {
					"inner_orbit": {
						"direction": 1,
						"duration_seconds": 72.0
					},
					"outer_orbit": {
						"direction": -1,
						"duration_seconds": 96.0
					}
			},
			"hover_projection": "interactive_non_embedded_side_projection",
			"hover_projection_truth_source": "resident_card_contract",
			"hover_projection_acquisition": "existing_intent_signal",
			"hover_projection_motion": "process_eased_slide_fade",
			"hover_focus_nonfocused_alpha": 0.4,
			"hover_focus_rail_alpha": 0.4,
			"hover_focus_scale_multiplier": 1.05,
			"centerpiece_focus_scale_multiplier": 1.018,
			"hover_focus_motion_policy": "shared_ring_eased_slowdown",
			"hover_focus_speed_multiplier": 0.34,
			"centerpiece_focus_speed_multiplier": 0.58,
			"publication_order": "centerpiece_then_inner_then_outer_annual_editorial_order",
			"publication_animation": "staggered_resident_orbital_reveal",
		},
		"rarity_language": [
			"AVAILABLE",
			"LIMITED",
			"COLLECTOR",
			"EXCEPTIONAL",
			"ONE OF ONE",
			"HISTORIC",
			"ARTIFACT"
		],
		"circulation_policy": "deterministic_yearly_private_market",
		"editorial_rotation_policy": "deterministic_22_to_26_card_annual_showcase",
		"native_luxury_count": published_native_count,
		"native_luxury_candidate_count": native_count,
		"resident_candidate_count": (
			candidate_rows.size()
		),
		"annual_capacity_target": (
			annual_capacity_target
		),
		"total_card_count": cards.size(),
		"market_revision": luxury_ledger.size(),
		"ui_is_renderer_only": true
	}
func _luxury_exchange_candidate_rows(
	actor: Person,
	current_era: String,
	current_year: int
) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	var current_era_index: int = (
		_era_index(
			current_era
		)
	)

	for raw_shop in get_shops_for_era(
		current_era
	):
		if typeof(raw_shop) != TYPE_DICTIONARY:
			continue

		var shop: Dictionary = (
			raw_shop as Dictionary
		)
		var shop_id: String = str(
			shop.get(
				"id",
				""
			)
		)
		var fame_required: int = int(
			shop.get(
				"fame_required",
				0
			)
		)

		for raw_item in _safe_array(
			shop.get(
				"inventory",
				[]
			)
		):
			if typeof(raw_item) != TYPE_DICTIONARY:
				continue

			var item: Dictionary = (
				raw_item as Dictionary
			)
			var item_id: String = str(
				item.get(
					"id",
					""
				)
			)

			if (
				item_id == ""
				or seen.has(
					item_id
				)
			):
				continue



			if int(
				item.get(
					"source_year",
					current_year
				)
			) > current_year:
				continue



			if str(
				item.get(
					"category",
					""
				)
			).strip_edges().to_lower() == "artifact":
				continue

			if not _luxury_item_circulates_this_year(
				item,
				current_era,
				current_era,
				current_year
			):
				continue

			seen [
				item_id
			] = true

			out.append({
				"item": (
					item.duplicate(true)
				),
				"shop_id": shop_id,
				"shop_name": str(
					shop.get(
						"name",
						"Private Exchange"
					)
				),
				"fame_required": fame_required,
				"source_era": current_era,
				"historic": false,
				"actor_id": int(actor.id)
			})

	for historical_era in _all_luxury_era_names():
		if (
			_era_index(
				str(historical_era)
			) >= current_era_index
		):
			continue

		for raw_shop in get_shops_for_era(
			str(historical_era)
		):
			if typeof(raw_shop) != TYPE_DICTIONARY:
				continue

			var shop: Dictionary = (
				raw_shop as Dictionary
			)

			for raw_item in _safe_array(
				shop.get(
					"inventory",
					[]
				)
			):
				if typeof(raw_item) != TYPE_DICTIONARY:
					continue

				var item: Dictionary = (
					raw_item as Dictionary
				)
				var item_id: String = str(
					item.get(
						"id",
						""
					)
				)

				if (
					item_id == ""
					or seen.has(
						item_id
					)
					or not bool(
						item.get(
							"historical_persistence",
							false
						)
					)
				):
					continue

				if int(
					item.get(
						"source_year",
						current_year
					)
				) > current_year:
					continue

				if not _luxury_item_circulates_this_year(
					item,
					str(historical_era),
					current_era,
					current_year
				):
					continue

				if (
					int(
						item.get(
							"resident_examples",
							0
						)
					) == 1
					and _luxury_unique_item_was_acquired(
						item_id
					)
				):
					continue

				seen [
					item_id
				] = true

				out.append({
					"item": (
						item.duplicate(true)
					),
					"shop_id": str(
						shop.get(
							"id",
							""
						)
					),
					"shop_name": str(
						shop.get(
							"name",
							"Historic Private Collection"
						)
					),
					"fame_required": int(
						shop.get(
							"fame_required",
							0
						)
					),
					"source_era": str(
						historical_era
					),
					"historic": true,
					"actor_id": int(
						actor.id
					)
				})

	out.sort_custom(
		func (a, b):
			var candidate_a: Dictionary = (
				a as Dictionary
			)
			var candidate_b: Dictionary = (
				b as Dictionary
			)
			var item_a: Dictionary = (
				_safe_dictionary(
					candidate_a.get(
						"item",
						{}
					)
				)
			)
			var item_b: Dictionary = (
				_safe_dictionary(
					candidate_b.get(
						"item",
						{}
					)
				)
			)

			return int(
				item_a.get(
					"value",
					item_a.get(
						"price",
						0
					)
				)
			) > int(
				item_b.get(
					"value",
					item_b.get(
						"price",
						0
					)
				)
			)
	)

	return out

func _luxury_exchange_card_contract(
	actor: Person,
	candidate: Dictionary,
	current_era: String,
	current_year: int
) -> Dictionary:
	var item: Dictionary = _safe_dictionary(
		candidate.get(
			"item",
			{}
		)
	)

	if item.is_empty():
		return {}

	var source_era: String = str(
		candidate.get(
			"source_era",
			current_era
		)
	)
	var historical: bool = bool(
		candidate.get(
			"historic",
			false
		)
	)
	var quote: Dictionary = (
		_luxury_market_quote(
			item,
			source_era,
			current_era,
			current_year
		)
	)
	var classification: String = (
		_luxury_classification_for_item(
			item,
			historical
		)
	)
	var market_value: int = int(
		quote.get(
			"market_value",
			item.get(
				"value",
				item.get(
					"price",
					0
				)
			)
		)
	)
	var dealer_ask: int = int(
		quote.get(
			"dealer_ask",
			market_value
		)
	)
	var section_id: String = (
		_luxury_section_id_for_item(
			item
		)
	)
	var fame_required: int = int(
		candidate.get(
			"fame_required",
			0
		)
	)
	var acquisition_disabled: bool = (
		int(actor.fame) < fame_required
	)
	var acquisition_disabled_reason: String = ""

	if acquisition_disabled:
		acquisition_disabled_reason = (
			"Private access requires fame level %d."
			% fame_required
		)

	var resident_examples: int = int(
		item.get(
			"resident_examples",
			0
		)
	)

	return {
		"schema": EXCHANGE_CARD_SCHEMA,
		"version": LUXURY_VERSION,
		"card_id": (
			"luxury:%s:%s"
			% [
				str(
					candidate.get(
						"shop_id",
						"exchange"
					)
				),
				str(
					item.get(
						"id",
						"item"
					)
				)
			]
		),
		"ownership_domain": "luxury",
		"truth_authority": "luxury_shop_engine",
		"shop_id": str(
			candidate.get(
				"shop_id",
				""
			)
		),
		"item_id": str(
			item.get(
				"id",
				""
			)
		),
		"title": str(
			item.get(
				"name",
				"Exceptional Object"
			)
		),
		"house": str(
			item.get(
				"house",
				candidate.get(
					"shop_name",
					"Private Exchange"
				)
			)
		),
		"item_type": str(
			item.get(
				"type",
				"Luxury Object"
			)
		),
		"category": str(
			item.get(
				"category",
				"Collectibles"
			)
		),
		"section_id": section_id,
		"classification": classification,
		"classification_display": (
			_luxury_classification_display(
				classification
			)
		),
		"source_era": source_era,
		"historic": historical,
		"source_year": int(
			item.get(
				"source_year",
				current_year
			)
		),
		"market_value": market_value,
		"market_value_text": (
			_format_luxury_money(
				market_value
			)
		),
		"dealer_ask": dealer_ask,
		"dealer_ask_text": (
			_format_luxury_money(
				dealer_ask
			)
		),
		"condition": int(
			item.get(
				"condition",
				94
			)
		),
		"condition_text": (
			"%d%%"
			% int(
				item.get(
					"condition",
					94
				)
			)
		),
		"provenance_status": str(
			item.get(
				"provenance_status",
				"Documented"
			)
		),
		"origin": str(
			item.get(
				"origin",
				"Private Market"
			)
		),
		"known_owners": int(
			item.get(
				"known_owners",
				1
			)
		),
		"last_transfer": str(
			item.get(
				"last_transfer",
				"Private"
			)
		),
		"resident_examples": resident_examples,
		"rarity_text": (
			"1 / %d resident examples"
			% resident_examples
			if resident_examples > 1
			else (
				"Unique canonical object"
				if resident_examples == 1
				else "Circulating luxury"
			)
		),
		"market_pressure": str(
			quote.get(
				"market_pressure",
				"steady"
			)
		),
		"market_pressure_label": str(
			quote.get(
				"market_pressure_label",
				"→ STEADY"
			)
		),
		"lore": str(
			item.get(
				"lore",
				""
			)
		),
		"history_note": str(
			item.get(
				"history_note",
				""
			)
		),
		"material": str(
			item.get(
				"material",
				""
			)
		),
		"visual_mark": str(
			item.get(
				"visual_mark",
				"◆"
			)
		),
		"mosaic_span": (
			_luxury_mosaic_span(
				classification,
				section_id,
				market_value,
				item
			)
		),
		"editorial_rank": (
			_luxury_editorial_rank(
				classification,
				market_value
			)
		),
		"featured": bool(
			item.get(
				"featured",
				false
			)
		),
		"acquisition_label": (
			"PLACE PRIVATE OFFER"
			if (
				classification in [
					"EXCEPTIONAL",
					"ONE OF ONE",
					"HISTORIC"
				]
				or dealer_ask >= 1000000
			)
			else "REQUEST ACQUISITION"
		),
		"acquisition_disabled": (
			acquisition_disabled
		),
		"acquisition_disabled_reason": (
			acquisition_disabled_reason
		),
		"acquisition_intent": {
			"action_id": "acquire_luxury_item",
			"payload": {
				"action_id": "acquire_luxury_item",
				"shop_id": str(
					candidate.get(
						"shop_id",
						""
					)
				),
				"item_id": str(
					item.get(
						"id",
						""
					)
				),
				"source": (
					"luxury_exchange.native_luxury"
				)
			},
			"target": {
				"route_kind": "engine_method",
				"engine_property": (
					"luxury_shop_engine"
				),
				"method": "resolve_intent",
				"pass_actor_payload": true
			}
		},
		"ui_is_renderer_only": true
	}


func _magical_artifact_exchange_card_contracts(
	actor: Person
) -> Array:
	var out: Array = []

	if (
		actor == null
		or gs == null
	):
		return out





	var reality_mode: String = "realistic"

	if gs.has_method(
		"get_reality_mode"
	):
		reality_mode = str(
			gs.get_reality_mode()
		).strip_edges().to_lower()
	elif "reality_mode" in gs:
		reality_mode = str(
			gs.reality_mode
		).strip_edges().to_lower()

	if reality_mode != "chaos":
		return out

	if (
		gs.artifact_shop_contract_engine == null
		or not gs.artifact_shop_contract_engine.has_method(
			"resident_shop_contract_for_actor"
		)
	):
		return out

	var resident_contract: Dictionary = (
		gs.artifact_shop_contract_engine
		.resident_shop_contract_for_actor(
			int(actor.id)
		)
	)
	var resident_rows: Array = _safe_array(
		resident_contract.get(
			"rows",
			[]
		)
	)

	if resident_rows.is_empty():
		return out

	var market_year: int = int(
		gs.year
	)
	var family_pools: Dictionary = {
		"infinity_stone": [],
		"dragon_ball": [],
		"red_bonnet": [],
		"other": []
	}
	var all_rows: Array = []

	for raw_row in resident_rows:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = raw_row as Dictionary
		var item_id: String = str(
			row.get(
				"id",
				""
			)
		).strip_edges()

		if item_id == "":
			continue

		var grant_type: String = str(
			row.get(
				"grant_type",
				""
			)
		).strip_edges().to_lower()
		var family_id: String = "other"

		if grant_type == "infinity_stone":
			family_id = "infinity_stone"
		elif grant_type == "dragon_ball":
			family_id = "dragon_ball"
		elif grant_type == "red_bonnet":
			family_id = "red_bonnet"

		var family_pool: Array = _safe_array(
			family_pools.get(
				family_id,
				[]
			)
		)

		family_pool.append(
			row
		)
		family_pools [
			family_id
		] = family_pool
		all_rows.append(
			row
		)

	var artifact_sorter: Callable = func (a, b):
		var row_a: Dictionary = a as Dictionary
		var row_b: Dictionary = b as Dictionary
		var key_a: int = _stable_luxury_hash(
			"%s|%d|%d|luxury_artifact_crosslist"
			% [
				str(
					row_a.get(
						"id",
						"artifact"
					)
				),
				int(actor.id),
				market_year
			]
		)
		var key_b: int = _stable_luxury_hash(
			"%s|%d|%d|luxury_artifact_crosslist"
			% [
				str(
					row_b.get(
						"id",
						"artifact"
					)
				),
				int(actor.id),
				market_year
			]
		)

		return key_a > key_b

	for family_id in [
		"infinity_stone",
		"dragon_ball",
		"red_bonnet",
		"other"
	]:
		var family_pool: Array = _safe_array(
			family_pools.get(
				family_id,
				[]
			)
		)

		family_pool.sort_custom(
			artifact_sorter
		)
		family_pools [
			family_id
		] = family_pool

	all_rows.sort_custom(
		artifact_sorter
	)




	var artifact_target_count: int = mini(
		EXCHANGE_MAX_ARTIFACT_CARDS,
		2
		+ (
			_stable_luxury_hash(
				"artifact_crosslist_count|%d|%d"
				% [
					int(actor.id),
					market_year
				]
			) % 3
		)
	)
	artifact_target_count = mini(
		artifact_target_count,
		all_rows.size()
	)

	var family_order: Array = [
		"infinity_stone",
		"dragon_ball",
		"red_bonnet",
		"other"
	]
	var family_offset: int = (
		_stable_luxury_hash(
			"artifact_family_rotation|%d|%d"
			% [
				int(actor.id),
				market_year
			]
		) % family_order.size()
	)
	var selected_rows: Array = []
	var selected_ids: Dictionary = {}

	for step in range(
		family_order.size()
	):
		if selected_rows.size() >= artifact_target_count:
			break

		var family_index: int = (
			family_offset
			+ step
		) % family_order.size()
		var family_id: String = str(
			family_order [
				family_index
			]
		)
		var family_pool: Array = _safe_array(
			family_pools.get(
				family_id,
				[]
			)
		)

		if family_pool.is_empty():
			continue

		var family_row: Dictionary = (
			family_pool [0] as Dictionary
		)
		var family_item_id: String = str(
			family_row.get(
				"id",
				""
			)
		).strip_edges()

		if (
			family_item_id == ""
			or selected_ids.has(
				family_item_id
			)
		):
			continue

		selected_rows.append(
			family_row
		)
		selected_ids [
			family_item_id
		] = true

	for raw_row in all_rows:
		if selected_rows.size() >= artifact_target_count:
			break

		if typeof(raw_row) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = raw_row as Dictionary
		var item_id: String = str(
			row.get(
				"id",
				""
			)
		).strip_edges()

		if (
			item_id == ""
			or selected_ids.has(
				item_id
			)
		):
			continue

		selected_rows.append(
			row
		)
		selected_ids [
			item_id
		] = true

	for raw_row in selected_rows:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = raw_row as Dictionary
		var item_id: String = str(
			row.get(
				"id",
				""
			)
		).strip_edges()

		if item_id == "":
			continue

		var grant_type: String = str(
			row.get(
				"grant_type",
				""
			)
		).strip_edges().to_lower()
		var is_infinity_stone: bool = (
			grant_type == "infinity_stone"
		)
		var is_dragon_ball: bool = (
			grant_type == "dragon_ball"
		)
		var is_red_bonnet: bool = (
			grant_type == "red_bonnet"
		)
		var price: int = int(
			row.get(
				"price",
				row.get(
					"cost",
					row.get(
						"value",
						0
					)
				)
			)
		)
		var authority_status: String = str(
			row.get(
				"status_text",
				"Available"
			)
		).strip_edges()
		var purchase_hint: String = str(
			row.get(
				"purchase_hint",
				""
			)
		).strip_edges()
		var acquisition_disabled: bool = (
			is_red_bonnet
			or authority_status.to_lower() != "available"
		)
		var acquisition_disabled_reason: String = ""

		if acquisition_disabled:
			acquisition_disabled_reason = (
				purchase_hint
				if purchase_hint != ""
				else (
					"This artifact is not currently available "
					+ "for acquisition."
				)
			)

		var display_color_key: String = str(
			row.get(
				"display_color_key",
				row.get(
					"color",
					""
				)
			)
		).strip_edges().to_lower()
		var classification_token: String = "ARTIFACT"

		if display_color_key != "":
			classification_token = (
				"ARTIFACT_%s"
				% display_color_key.to_upper()
					.replace(
						" ",
						"_"
					)
					.replace(
						"-",
						"_"
					)
			)

		var rarity_name: String = str(
			row.get(
				"rarity",
				(
					"Cosmic"
					if is_infinity_stone
					else "Artifact"
				)
			)
		).strip_edges()
		var item_type: String = str(
			row.get(
				"type",
				"Artifact"
			)
		)
		var editorial_rank: int = 980

		if is_infinity_stone:
			item_type = "Infinity Stone"
			editorial_rank = 1100
		elif is_red_bonnet:
			item_type = "Red Bonnet"
			editorial_rank = 1080
		elif is_dragon_ball:
			item_type = "Dragon Ball"
			editorial_rank = 1040

		out.append({
			"schema": EXCHANGE_CARD_SCHEMA,
			"version": LUXURY_VERSION,
			"card_id": (
				"artifact:%s"
				% item_id
			),
			"ownership_domain": "artifact",
			"truth_authority": (
				"artifact_shop_contract_engine"
			),
			"item_id": item_id,
			"title": str(
				row.get(
					"name",
					row.get(
						"display_name",
						"Artifact"
					)
				)
			),
			"house": "ARTIFACT AUTHORITY",
			"item_type": item_type,
			"category": "Artifact",
			"section_id": "artifacts",
			"classification": classification_token,
			"classification_family": "ARTIFACT",
			"artifact_display_color_key": display_color_key,
			"classification_display": (
				"✦ LIMITED-TIME ARTIFACT ✦"
				if is_infinity_stone
				else "✦ ARTIFACT ✦"
			),
			"market_value": int(
				row.get(
					"value",
					price
				)
			),
			"market_value_text": (
				_format_luxury_money(
					int(
						row.get(
							"value",
							price
						)
					)
				)
			),
			"dealer_ask": price,
			"dealer_ask_text": (
				_format_luxury_money(
					price
				)
			),
			"condition_text": authority_status,
			"provenance_status": (
				"Artifact contract"
			),
			"origin": str(
				row.get(
					"origin",
					"Canonical artifact reality"
				)
			),
			"rarity_text": (
				"%s • Artifact authority controls scarcity"
				% rarity_name
			),
			"market_pressure_label": (
				(
					"◈ PRIVATE WINDOW • %s"
					% _format_luxury_year(
						market_year
					)
				)
				if is_infinity_stone
				else (
					"NOT FOR SALE"
					if is_red_bonnet
					else "⚠ SPECIAL ACQUISITION"
				)
			),
			"lore": str(
				row.get(
					"lore",
					row.get(
						"description",
						""
					)
				)
			),
			"history_note": (
				(
					"Limited-time Luxury Exchange cross-list "
					+ "for this market year. Artifact authority "
					+ "retains all scarcity and acquisition truth."
				)
				if is_infinity_stone
				else (
					"Displayed by Luxury. "
					+ "Owned by Artifact authority."
				)
			),
			"visual_mark": (
				"◆"
				if is_infinity_stone
				else "✦"
			),
			"mosaic_span": (
				"standard_1x1"
				if (
					is_infinity_stone
					or is_dragon_ball
				)
				else "portrait_1x2"
			),
			"editorial_rank": editorial_rank,
			"featured": true,
			"limited_time_crosslist": is_infinity_stone,
			"limited_time_market_year": (
				market_year
				if is_infinity_stone
				else 0
			),
			"acquisition_label": (
				"NOT FOR SALE"
				if is_red_bonnet
				else (
					"REQUEST COSMIC ACQUISITION"
					if is_infinity_stone
					else "REQUEST ARTIFACT ACQUISITION"
				)
			),
			"acquisition_disabled": (
				acquisition_disabled
			),
			"acquisition_disabled_reason": (
				acquisition_disabled_reason
			),
			"acquisition_intent": {
				"action_id": "purchase_artifact",
				"payload": {
					"action_id": (
						"purchase_artifact"
					),
					"item_id": item_id,
					"source": (
						"luxury_exchange."
						+ "artifact_crosslist"
					)
				},
				"target": {
					"route_kind": (
						"engine_method"
					),
					"engine_property": (
						"artifact_shop_contract_engine"
					),
					"method": "resolve_intent",
					"pass_actor_payload": true
				}
			},
			"ui_is_renderer_only": true
		})

	return out
func _artifact_exchange_card_contracts(
	actor: Person
) -> Array:
	var out: Array = (
		_persistent_artifact_exchange_card_contracts(
			actor
		)
	)

	for raw_card in _magical_artifact_exchange_card_contracts(
		actor
	):
		if typeof(
			raw_card
		) != TYPE_DICTIONARY:
			continue

		out.append(
			(
				raw_card as Dictionary
			).duplicate(false)
		)

	return out
func _persistent_artifact_exchange_card_contracts(
	actor: Person
) -> Array:
	var out: Array = []

	if (
		actor == null
		or gs == null
		or gs.artifacts_engine == null
		or not gs.artifacts_engine.has_method(
			"get_luxury_exchange_artifact_rows"
		)
	):
		return out

	var rows_raw: Variant = (
		gs.artifacts_engine.get_luxury_exchange_artifact_rows(
			actor
		)
	)

	if typeof(
		rows_raw
	) != TYPE_ARRAY:
		return out

	for raw_row in rows_raw as Array:
		if typeof(
			raw_row
		) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = (
			raw_row as Dictionary
		).duplicate(true)
		var item_id: String = str(
			row.get(
				"id",
				""
			)
		).strip_edges().to_lower()
		var canonical_instance_id: String = str(
			row.get(
				"canonical_instance_id",
				""
			)
		).strip_edges()

		if (
			item_id == ""
			or canonical_instance_id == ""
		):
			continue

		var price: int = int(
			row.get(
				"price",
				row.get(
					"value",
					0
				)
			)
		)
		var family_lives: int = int(
			row.get(
				"extraordinary_family_lives",
				0
			)
		)
		var extraordinary: bool = (
			family_lives > 0
		)
		var classification_family: String = str(
			row.get(
				"classification_family",
				"ARTIFACT"
			)
		).strip_edges().to_upper()
		var lore_text: String = str(
			row.get(
				"description",
				row.get(
					"lore",
					""
				)
			)
		).strip_edges()
		var authority_note: String = str(
			row.get(
				"authority_note",
				""
			)
		).strip_edges()

		if authority_note != "":
			if lore_text != "":
				lore_text += "\n\n"

			lore_text += authority_note

		var acquisition_action_id: String = (
			"request_extraordinary_acquisition"
			if extraordinary
			else "purchase_exchange_artifact"
		)
		var ask_text_override: String = ""

		if extraordinary:
			ask_text_override = (
				"%s\n\nACQUISITION COST\n%s\n\n"
				+ "+ THREE RANDOM MEMBERS OF YOUR FAMILY’S LIVES"
			) % [
				_format_luxury_money(
					price
				),
				_format_luxury_money(
					price
				)
			]

		out.append({
			"schema": EXCHANGE_CARD_SCHEMA,
			"version": LUXURY_VERSION,
			"card_id": (
				"artifact_persistent:%s"
				% canonical_instance_id
			),
			"ownership_domain": "artifact",
			"truth_authority": "artifact_shop_contract_engine",
			"item_id": item_id,
			"canonical_instance_id": canonical_instance_id,
			"title": str(
				row.get(
					"name",
					"Artifact"
				)
			),
			"house": "ARTIFACT AUTHORITY",
			"item_type": str(
				row.get(
					"house_text",
					"HISTORIC ARTIFACT"
				)
			),
			"category": "Artifact",
			"section_id": "artifacts",
			"classification": classification_family,
			"classification_family": classification_family,
			"artifact_display_color_key": str(
				row.get(
					"display_color_key",
					"gold"
				)
			),
			"classification_display": str(
				row.get(
					"classification_display",
					"◆ BEYOND MYTHIC ◆"
				)
			),
			"market_value": price,
			"market_value_text": _format_luxury_money(
				price
			),
			"dealer_ask": price,
			"dealer_ask_text": _format_luxury_money(
				price
			),
			"condition_text": str(
				row.get(
					"condition_text",
					"Documented"
				)
			),
			"provenance_status": "Artifact Authority provenance",
			"origin": str(
				row.get(
					"origin",
					"Canonical artifact record"
				)
			),
			"known_owners": str(
				row.get(
					"known_owners",
					"—"
				)
			),
			"last_transfer": str(
				row.get(
					"last_transfer",
					"—"
				)
			),
			"rarity_text": (
				"%s · %s"
				% [
					str(
						row.get(
							"rarity",
							"Beyond Mythic"
						)
					),
					str(
						row.get(
							"mythic_rank",
							"Historical Anomaly"
						)
					)
				]
			),
			"market_pressure_label": (
				"CANONICAL HISTORICAL OBJECT"
				if extraordinary
				else "ARTIFACT AUTHORITY LISTING"
			),
			"lore": lore_text,
			"history_note": str(
				row.get(
					"history_note",
					""
				)
			),
			"provenance_text_override": str(
				row.get(
					"provenance_text",
					""
				)
			),
			"house_text_override": str(
				row.get(
					"house_text",
					""
				)
			),
			"ask_text_override": ask_text_override,
			"visual_mark": (
				"◆"
				if classification_family == "ONE OF ONE"
				else "✦"
			),
			"mosaic_span": (
				"hero_2x2"
				if classification_family == "ONE OF ONE"
				else "standard_1x1"
			),
			"editorial_rank": int(
				row.get(
					"editorial_rank",
					1500
				)
			),
			"featured": true,
			"limited_time_crosslist": (
				str(
					row.get(
						"circulation_policy",
						""
					)
				).strip_edges().to_lower()
				!= "always_when_unclaimed"
			),
			"limited_time_market_year": int(
				row.get(
					"market_year",
					0
				)
			),
			"acquisition_label": "REQUEST ACQUISITION",
			"acquisition_disabled": false,
			"acquisition_disabled_reason": "",
			"acquisition_intent": {
				"action_id": acquisition_action_id,
				"payload": {
					"action_id": acquisition_action_id,
					"item_id": item_id,
					"canonical_instance_id": canonical_instance_id,
					"source": "luxury_exchange.persistent_artifact"
				},
				"target": {
					"route_kind": "engine_method",
					"engine_property": "artifact_shop_contract_engine",
					"method": "resolve_intent",
					"pass_actor_payload": true
				}
			},
			"ui_is_renderer_only": true
		})

	return out
func _vehicle_exchange_card_contracts(
	actor: Person
) -> Array:
	var out: Array = []

	if (
		actor == null
		or gs == null
		or gs.dealership_contract_engine == null
		or not gs.dealership_contract_engine.has_method(
			"resident_luxury_listing_card_contracts"
		)
	):
		return out

	var cards: Array = (
		gs.dealership_contract_engine
		.resident_luxury_listing_card_contracts(
			actor,
			EXCHANGE_MAX_VEHICLE_CARDS
		)
	)

	for raw_card in cards:
		if typeof(raw_card) != TYPE_DICTIONARY:
			continue

		var native_card: Dictionary = (
			raw_card as Dictionary
		)
		var listing_id: String = str(
			native_card.get(
				"listing_id",
				""
			)
		)

		if listing_id == "":
			continue

		var price: int = int(
			native_card.get(
				"price",
				0
			)
		)
		var luxury_level: int = int(
			native_card.get(
				"luxury_level",
				0
			)
		)
		var classification: String = (
			"EXCEPTIONAL"
			if (
				luxury_level >= 4
				or price >= 1000000
			)
			else "COLLECTOR"
		)
		var buy_disabled: bool = false
		var disabled_reason: String = ""

		for raw_action in _safe_array(
			native_card.get(
				"actions",
				[]
			)
		):
			if typeof(raw_action) != TYPE_DICTIONARY:
				continue

			var native_action: Dictionary = (
				raw_action as Dictionary
			)

			if str(
				native_action.get(
					"action_id",
					""
				)
			) != "buy_vehicle":
				continue

			buy_disabled = bool(
				native_action.get(
					"disabled",
					false
				)
			)
			disabled_reason = str(
				native_action.get(
					"disabled_reason",
					""
				)
			)
			break

		out.append({
			"schema": EXCHANGE_CARD_SCHEMA,
			"version": LUXURY_VERSION,
			"card_id": (
				"vehicle:%s"
				% listing_id
			),
			"ownership_domain": "vehicle",
			"truth_authority": (
				"dealership_contract_engine"
			),
			"title": str(
				native_card.get(
					"title",
					"Private Vehicle"
				)
			),
			"house": str(
				native_card.get(
					"dealer",
					native_card.get(
						"dealership_label",
						"Private Motor House"
					)
				)
			),
			"item_type": str(
				native_card.get(
					"category",
					"Vehicle"
				)
			),
			"category": "Vehicles",
			"section_id": "vehicles",
			"classification": classification,
			"classification_display": (
				_luxury_classification_display(
					classification
				)
			),
			"market_value": price,
			"market_value_text": str(
				native_card.get(
					"price_text",
					_format_luxury_money(
						price
					)
				)
			),
			"dealer_ask": price,
			"dealer_ask_text": str(
				native_card.get(
					"price_text",
					_format_luxury_money(
						price
					)
				)
			),
			"condition_text": str(
				native_card.get(
					"condition_text",
					"Dealer Maintained"
				)
			),
			"provenance_status": (
				"Resident dealership contract"
			),
			"origin": str(
				native_card.get(
					"dealer",
					"Resident dealership"
				)
			),
			"rarity_text": (
				"Exceptional resident mobility listing"
			),
			"market_pressure_label": (
				"PRIVATE MOTOR MARKET"
			),
			"lore": str(
				native_card.get(
					"meta_line",
					""
				)
			),
			"history_note": (
				"Luxury is curating this vehicle. "
				+ "Vehicle authority owns acquisition."
			),
			"visual_mark": "◇",
			"mosaic_span": (
				"hero_2x2"
				if price >= 1000000
				else "landscape_2x1"
			),
			"editorial_rank": (
				900
				if price >= 1000000
				else 760
			),
			"featured": (
				price >= 500000
			),
			"acquisition_label": "ACQUIRE",
			"acquisition_disabled": (
				buy_disabled
			),
			"acquisition_disabled_reason": (
				disabled_reason
			),
			"acquisition_intent": {
				"action_id": "buy_vehicle",
				"payload": {
					"action_id": "buy_vehicle",
					"market_action": "buy_vehicle",
					"listing_id": listing_id,
					"variation_id": str(
						native_card.get(
							"variation_id",
							""
						)
					),
					"source": (
						"luxury_exchange."
						+ "vehicle_crosslist"
					)
				},
				"target": {
					"route_kind": (
						"engine_method"
					),
					"engine_property": (
						"dealership_contract_engine"
					),
					"method": (
						"commit_listing_action"
					),
					"pass_actor_payload": true
				}
			},
			"ui_is_renderer_only": true
		})

	return out


func _property_exchange_card_contracts(
	actor: Person
) -> Array:
	var out: Array = []

	if (
		actor == null
		or gs == null
		or gs.property_market_contract_engine == null
		or not gs.property_market_contract_engine.has_method(
			"resident_luxury_listing_card_contracts"
		)
	):
		return out

	var cards: Array = (
		gs.property_market_contract_engine
		.resident_luxury_listing_card_contracts(
			actor,
			EXCHANGE_MAX_PROPERTY_CARDS
		)
	)

	for raw_card in cards:
		if typeof(raw_card) != TYPE_DICTIONARY:
			continue

		var native_card: Dictionary = (
			raw_card as Dictionary
		)
		var listing_id: String = str(
			native_card.get(
				"listing_id",
				""
			)
		)

		if listing_id == "":
			continue

		var price: int = int(
			native_card.get(
				"price",
				0
			)
		)
		var classification: String = (
			"EXCEPTIONAL"
			if price >= 10000000
			else "COLLECTOR"
		)

		out.append({
			"schema": EXCHANGE_CARD_SCHEMA,
			"version": LUXURY_VERSION,
			"card_id": (
				"property:%s"
				% listing_id
			),
			"ownership_domain": "property",
			"truth_authority": (
				"property_market_contract_engine"
			),
			"title": str(
				native_card.get(
					"title",
					"Private Estate"
				)
			),
			"house": "PRIVATE PROPERTY DESK",
			"item_type": str(
				native_card.get(
					"category",
					"Estate"
				)
			),
			"category": "Property",
			"section_id": "property",
			"classification": classification,
			"classification_display": (
				_luxury_classification_display(
					classification
				)
			),
			"market_value": price,
			"market_value_text": str(
				native_card.get(
					"price_text",
					_format_luxury_money(
						price
					)
				)
			),
			"dealer_ask": price,
			"dealer_ask_text": str(
				native_card.get(
					"price_text",
					_format_luxury_money(
						price
					)
				)
			),
			"condition_text": str(
				native_card.get(
					"condition_text",
					"Maintained"
				)
			),
			"provenance_status": (
				"Resident property contract"
			),
			"origin": str(
				native_card.get(
					"amenity_summary",
					"Resident property market"
				)
			),
			"rarity_text": (
				"Exceptional resident estate listing"
			),
			"market_pressure_label": (
				"PRIVATE PROPERTY MARKET"
			),
			"lore": str(
				native_card.get(
					"meta_line",
					""
				)
			),
			"history_note": (
				"Luxury is curating this estate. "
				+ "Property authority owns acquisition."
			),
			"visual_mark": "▱",
			"mosaic_span": (
				"hero_2x2"
				if price >= 5000000
				else "landscape_2x1"
			),
			"editorial_rank": (
				950
				if price >= 10000000
				else 780
			),
			"featured": (
				price >= 2500000
			),
			"acquisition_label": (
				"REQUEST ACQUISITION"
			),
			"acquisition_disabled": bool(
				native_card.get(
					"buy_disabled",
					false
				)
			),
			"acquisition_disabled_reason": str(
				native_card.get(
					"buy_disabled_reason",
					""
				)
			),
			"acquisition_intent": {
				"action_id": "buy_outright",
				"payload": {
					"action_id": "buy_outright",
					"market_action": "buy_outright",
					"listing_id": listing_id,
					"variation_id": str(
						native_card.get(
							"variation_id",
							""
						)
					),
					"source": (
						"luxury_exchange."
						+ "property_crosslist"
					)
				},
				"target": {
					"route_kind": (
						"engine_method"
					),
					"engine_property": (
						"property_market_contract_engine"
					),
					"method": (
						"commit_listing_action"
					),
					"pass_actor_payload": true
				}
			},
			"ui_is_renderer_only": true
		})

	return out
func _luxury_item_circulates_this_year(
	item: Dictionary,
	source_era: String,
	current_era: String,
	current_year: int
) -> bool:
	var historical: bool = (
		_era_index(source_era)
		< _era_index(current_era)
	)

	if (
		historical
		and not bool(
			item.get(
				"historical_persistence",
				false
			)
		)
	):
		return false

	var percent: int = int(
		item.get(
			(
				"historic_circulation_percent"
				if historical
				else "circulation_percent"
			),
			(
				38
				if historical
				else 82
			)
		)
	)

	percent = clampi(
		percent,
		1,
		100
	)

	var seed_text: String = (
		"%s|%s|%s|%d"
		% [
			str(
				item.get(
					"id",
					"luxury_item"
				)
			),
			source_era,
			current_era,
			current_year
		]
	)

	return (
		_stable_luxury_hash(
			seed_text
		) % 100
		< percent
	)


func _luxury_market_quote(
	item: Dictionary,
	source_era: String,
	current_era: String,
	current_year: int
) -> Dictionary:
	var base_value: int = maxi(
		1,
		int(
			item.get(
				"value",
				item.get(
					"price",
					1
				)
			)
		)
	)
	var source_year: int = int(
		item.get(
			"source_year",
			current_year
		)
	)
	var historical: bool = (
		_era_index(source_era)
		< _era_index(current_era)
	)
	var historical_age: int = (
		absi(
			current_year
			- source_year
		)
		if historical
		else 0
	)
	var historic_multiplier: float = 1.0

	if historical:
		historic_multiplier = minf(
			8.0,
			1.0
			+ (
				float(
					historical_age
				) / 450.0
			)
		)

	var pressure_contract: Dictionary = (
		_luxury_market_pressure_contract(
			str(
				item.get(
					"id",
					"luxury_item"
				)
			),
			current_era,
			current_year
		)
	)
	var pressure_multiplier: float = float(
		pressure_contract.get(
			"multiplier",
			1.0
		)
	)
	var market_value: int = maxi(
		1,
		int(
			round(
				float(base_value)
				* historic_multiplier
				* pressure_multiplier
			)
		)
	)
	var ask_markup: float = 1.06 + float(
		_stable_luxury_hash(
			"%s|ask|%d"
			% [
				str(
					item.get(
						"id",
						"luxury_item"
					)
				),
				current_year
			]
		) % 9
	) / 100.0
	var dealer_ask: int = maxi(
		market_value,
		int(
			round(
				float(
					market_value
				) * ask_markup
			)
		)
	)

	return {
		"market_value": market_value,
		"dealer_ask": dealer_ask,
		"base_value": base_value,
		"historic_multiplier": (
			historic_multiplier
		),
		"historical_age_years": (
			historical_age
		),
		"market_pressure": str(
			pressure_contract.get(
				"id",
				"steady"
			)
		),
		"market_pressure_label": str(
			pressure_contract.get(
				"label",
				"→ STEADY"
			)
		),
		"market_pressure_multiplier": (
			pressure_multiplier
		),
		"quote_year": current_year,
	}


func _luxury_market_pressure_contract(
	item_id: String,
	era_name: String,
	current_year: int
) -> Dictionary:
	var value: int = (
		_stable_luxury_hash(
			"%s|%s|pressure|%d"
			% [
				item_id,
				era_name,
				current_year
			]
		) % 5
	)

	match value:
		0:
			return {
				"id": "soft",
				"label": "↓ SOFT",
				"multiplier": 0.96
			}

		1:
			return {
				"id": "quiet",
				"label": "→ QUIET",
				"multiplier": 0.99
			}

		2:
			return {
				"id": "steady",
				"label": "→ STEADY",
				"multiplier": 1.02
			}

		3:
			return {
				"id": "active",
				"label": "↑ ACTIVE",
				"multiplier": 1.07
			}

		_:
			return {
				"id": "high",
				"label": "↑ HIGH",
				"multiplier": 1.13
			}


func _luxury_classification_for_item(
	item: Dictionary,
	historical: bool
) -> String:
	if historical:
		return "HISTORIC"

	var explicit: String = str(
		item.get(
			"classification",
			""
		)
	).strip_edges().to_upper()

	if explicit in [
		"AVAILABLE",
		"LIMITED",
		"COLLECTOR",
		"EXCEPTIONAL",
		"ONE OF ONE"
	]:
		return explicit

	var resident_examples: int = int(
		item.get(
			"resident_examples",
			0
		)
	)

	if resident_examples == 1:
		return "ONE OF ONE"

	if (
		resident_examples > 1
		and resident_examples <= 14
	):
		return "EXCEPTIONAL"

	if (
		resident_examples > 14
		and resident_examples <= 60
	):
		return "COLLECTOR"

	if (
		resident_examples > 60
		and resident_examples <= 300
	):
		return "LIMITED"

	return "AVAILABLE"


func _luxury_classification_display(
	classification: String
) -> String:
	var clean: String = str(
		classification
	).strip_edges().to_upper()

	match clean:
		"ARTIFACT":
			return "✦ ARTIFACT ✦"

		"ONE OF ONE":
			return "◆ ONE OF ONE"

		"EXCEPTIONAL":
			return "✦ EXCEPTIONAL"

		"HISTORIC":
			return "✦ HISTORIC"

		"COLLECTOR":
			return "◆ COLLECTOR"

		"LIMITED":
			return "LIMITED"

		_:
			return "AVAILABLE"


func _luxury_mosaic_span(
	classification: String,
	section_id: String,
	market_value: int,
	item: Dictionary
) -> String:
	var explicit: String = str(
		item.get(
			"mosaic_span",
			""
		)
	).strip_edges().to_lower()

	if explicit in [
		"hero_2x2",
		"landscape_2x1",
		"portrait_1x2",
		"standard_1x1"
	]:
		return explicit

	if classification in [
		"ONE OF ONE",
		"EXCEPTIONAL"
	]:
		return "hero_2x2"

	if (
		classification == "HISTORIC"
		or market_value >= 1000000
		or section_id in [
			"art",
			"vehicles",
			"property"
		]
	):
		return "landscape_2x1"

	if section_id in [
		"jewelry",
		"fashion",
		"watches"
	]:
		return "portrait_1x2"

	return "standard_1x1"


func _luxury_editorial_rank(
	classification: String,
	market_value: int
) -> int:
	var rank: int = 100

	match classification:
		"ONE OF ONE":
			rank = 900
		"EXCEPTIONAL":
			rank = 820
		"HISTORIC":
			rank = 780
		"COLLECTOR":
			rank = 620
		"LIMITED":
			rank = 420
		_:
			rank = 200

	return rank + mini(
		99,
		int(
			log(
				float(
					maxi(
						1,
						market_value
					)
				)
			) * 7.0
		)
	)


func _luxury_section_id_for_item(
	item: Dictionary
) -> String:
	var category: String = str(
		item.get(
			"category",
			""
		)
	).strip_edges().to_lower()
	var item_type: String = str(
		item.get(
			"type",
			""
		)
	).strip_edges().to_lower()

	if (
		category.find("watch") >= 0
		or item_type.find("watch") >= 0
		or item_type.find("chronometer") >= 0
	):
		return "watches"

	if (
		category.find("jewel") >= 0
		or category.find("gem") >= 0
		or item_type.find("ring") >= 0
		or item_type.find("necklace") >= 0
		or item_type.find("brooch") >= 0
		or item_type.find("crown") >= 0
	):
		return "jewelry"

	if (
		category.find("fashion") >= 0
		or category.find("textile") >= 0
		or item_type.find("robe") >= 0
		or item_type.find("couture") >= 0
		or item_type.find("bag") >= 0
	):
		return "fashion"

	if (
		category.find("art") >= 0
		or item_type.find("painting") >= 0
		or item_type.find("tapestry") >= 0
		or item_type.find("pottery") >= 0
	):
		return "art"

	return "collectibles"


func _luxury_exchange_tabs(
	cards: Array
) -> Array:
	var ordered: Array = [
		{
			"id": "featured",
			"label": "FEATURED"
		}
	]
	var available_sections: Dictionary = {}

	for raw_card in cards:
		if typeof(raw_card) != TYPE_DICTIONARY:
			continue

		var section_id: String = str(
			(raw_card as Dictionary).get(
				"section_id",
				"collectibles"
			)
		)

		available_sections [
			section_id
		] = true

	for contract in [
		{ "id": "jewelry", "label": "JEWELRY"},
		{ "id": "watches", "label": "WATCHES"},
		{ "id": "fashion", "label": "FASHION"},
		{ "id": "art", "label": "ART"},
		{ "id": "collectibles", "label": "COLLECTIBLES"},
		{ "id": "vehicles", "label": "VEHICLES"},
		{ "id": "property", "label": "PROPERTY"},
		{ "id": "artifacts", "label": "ARTIFACTS"}
	]:
		if available_sections.has(
			str(
				contract.get(
					"id",
					""
				)
			)
		):
			ordered.append(
				contract.duplicate(true)
			)

	return ordered


func _luxury_unique_item_was_acquired(
	item_id: String
) -> bool:
	var inspected: int = 0

	for raw_report in luxury_ledger:
		if inspected >= 512:
			break

		inspected += 1

		if typeof(raw_report) != TYPE_DICTIONARY:
			continue

		if (
			str(
				(raw_report as Dictionary).get(
					"item_id",
					""
				)
			) == item_id
			and bool(
				(raw_report as Dictionary).get(
					"success",
					false
				)
			)
		):
			return true

	return false


func _era_for_shop_id(
	shop_id: String
) -> String:
	for era_name in _all_luxury_era_names():
		for raw_shop in get_shops_for_era(
			str(era_name)
		):
			if typeof(raw_shop) != TYPE_DICTIONARY:
				continue

			if str(
				(raw_shop as Dictionary).get(
					"id",
					""
				)
			) == shop_id:
				return str(
					era_name
				)

	return _era_name_from_context()


func _all_luxury_era_names() -> Array:
	return [
		"Ancient Era",
		"Medieval Era",
		"Industrial Era",
		"Modern Era",
		"Future Era"
	]


func _era_index(
	era_name: String
) -> int:
	var clean: String = str(
		era_name
	).strip_edges().to_lower()

	if clean.find("ancient") >= 0:
		return 0
	if clean.find("medieval") >= 0:
		return 1
	if clean.find("industrial") >= 0:
		return 2
	if clean.find("modern") >= 0:
		return 3
	if clean.find("future") >= 0:
		return 4

	return 3


func _stable_luxury_hash(
	text: String
) -> int:
	var value: int = 7919

	for index in range(
		text.length()
	):
		value = (
			(
				value * 131
			)
			+ text.unicode_at(
				index
			)
		) % 2147483647

	return absi(
		value
	)


func _format_luxury_money(
	amount: int
) -> String:
	if (
		gs != null
		and gs.economy_engine != null
		and gs.economy_engine.has_method(
			"format_money"
		)
	):
		return str(
			gs.economy_engine.format_money(
				amount
			)
		)

	return "$%d" % amount


func _format_luxury_year(
	year_value: int
) -> String:
	if year_value < 0:
		return "%d BCE" % absi(
			year_value
		)

	return "%d CE" % year_value


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)
func _luxury_item(
	item_id: String,
	item_name: String,
	item_type: String,
	category: String,
	material: String,
	price: int,
	value: int,
	lore: String,
	classification: String,
	resident_examples: int,
	source_year: int,
	origin: String,
	provenance_status: String,
	history_note: String,
	mosaic_span: String = "",
	historical_persistence: bool = true,
	circulation_percent: int = 82
) -> Dictionary:
	return {
		"id": item_id,
		"name": item_name,
		"type": item_type,
		"category": category,
		"material": material,
		"price": price,
		"value": value,
		"lore": lore,
		"classification": classification,
		"resident_examples": resident_examples,
		"source_year": source_year,
		"origin": origin,
		"provenance_status": provenance_status,
		"history_note": history_note,
		"mosaic_span": mosaic_span,
		"historical_persistence": (
			historical_persistence
		),
		"circulation_percent": (
			circulation_percent
		),
		"historic_circulation_percent": (
			maxi(
				12,
				int(
					round(
						float(
							circulation_percent
						) * 0.46
					)
				)
			)
		)
	}


func _luxury_exchange_extension_contract() -> Dictionary:
	return {
		"schema": (
			"eralife.luxury.exchange_catalog_extension"
		),
		"version": 1,
		"eras": {
			"Ancient Era": [
				{
					"id": "ancient_private_exchange",
					"name": "The Imperial Exchange",
					"description": (
						"Rare dyes, silk, gems, ceremonial "
						+ "objects, pottery, and manuscripts."
					),
					"fame_required": 0,
					"inventory": [
						_luxury_item(
							"tyrian_imperial_dye_casket",
							"Tyrian Imperial Dye Casket",
							"Pigment Casket",
							"Collectibles",
							"murex purple concentrate",
							3800,
							5200,
							"Enough true purple concentrate to clothe a ruler's household in status.",
							"EXCEPTIONAL",
							9,
							-220,
							"Phoenician Coast",
							"Documented",
							"Commissioned for an aristocratic textile house.",
							"landscape_2x1",
							true,
							64
						),
						_luxury_item(
							"eastern_court_silk_bolt",
							"Eastern Court Silk Bolt",
							"Silk Textile",
							"Fashion",
							"handwoven silk",
							2400,
							3100,
							"Imported silk whose journey across the world is part of its price.",
							"LIMITED",
							84,
							-180,
							"Eastern Trade Routes",
							"Documented",
							"Silk is luxury here because distance itself is expensive.",
							"portrait_1x2",
							true,
							80
						),
						_luxury_item(
							"emerald_scarab_signet",
							"Royal Emerald Scarab Signet",
							"Signet",
							"Jewelry",
							"emerald and electrum",
							7600,
							11800,
							"A court signet whose gemstone is worth less than the authority it once implied.",
							"EXCEPTIONAL",
							12,
							-310,
							"Lower Nile",
							"Documented",
							"Known to have passed through two temple treasuries.",
							"hero_2x2",
							true,
							58
						),
						_luxury_item(
							"attic_black_figure_amphora",
							"Attic Black-Figure Amphora",
							"Fine Pottery",
							"Art",
							"painted ceramic",
							4200,
							6900,
							"A museum-grade vessel painted with a procession no surviving text explains.",
							"COLLECTOR",
							27,
							-520,
							"Attica",
							"Documented",
							"Recovered from a noble burial inventory.",
							"landscape_2x1",
							true,
							53
						),
						_luxury_item(
							"lapis_lion_ceremonial_blade",
							"Lapis Lion Ceremonial Blade",
							"Ceremonial Blade",
							"Collectibles",
							"bronze, gold, lapis",
							6800,
							9400,
							"Too decorated for ordinary war; dangerous enough that nobody calls it harmless.",
							"COLLECTOR",
							31,
							-260,
							"Royal Foundry",
							"Partial",
							"Believed to have been displayed behind a provincial throne.",
							"portrait_1x2",
							true,
							57
						),
						_luxury_item(
							"alexandrian_star_manuscript",
							"Alexandrian Star Manuscript",
							"Manuscript",
							"Collectibles",
							"papyrus and mineral ink",
							9100,
							15400,
							"An illustrated celestial manuscript copied for a household wealthy enough to own ideas.",
							"ONE OF ONE",
							1,
							-140,
							"Alexandria",
							"Contested",
							"Several marginal notes appear to be later than the main text.",
							"hero_2x2",
							true,
							42
						)
					]
				}
			],

			"Medieval Era": [
				{
					"id": "medieval_court_exchange",
					"name": "The Court & Reliquary Exchange",
					"description": (
						"Crowns, armor, tapestries, illuminated "
						+ "books, imported cloth, and relics."
					),
					"fame_required": 5,
					"inventory": [
						_luxury_item(
							"crown_of_aurelia",
							"Crown of Aurelia",
							"Jeweled Crown",
							"Jewelry",
							"gold, ruby, sapphire",
							64000,
							93000,
							"A ceremonial crown whose politics outlived the court that commissioned it.",
							"EXCEPTIONAL",
							7,
							1214,
							"Western Court",
							"Documented",
							"Three dynastic inventories name the same crown.",
							"hero_2x2",
							true,
							44
						),
						_luxury_item(
							"milanese_gilded_plate",
							"Milanese Gilded Plate Commission",
							"Armor Commission",
							"Collectibles",
							"tempered steel and gold leaf",
							42000,
							61000,
							"Armor made as much for procession as violence.",
							"COLLECTOR",
							22,
							1478,
							"Northern Italy",
							"Documented",
							"The breastplate bears the erased arms of its first patron.",
							"landscape_2x1",
							true,
							62
						),
						_luxury_item(
							"flanders_hunt_tapestry",
							"Flanders Hunt Tapestry",
							"Tapestry",
							"Art",
							"wool, silk, metallic thread",
							27000,
							41000,
							"A wall-sized hunting scene that once insulated a castle while displaying its owner's wealth.",
							"COLLECTOR",
							34,
							1392,
							"Flanders",
							"Documented",
							"Commission records survive in a merchant ledger.",
							"landscape_2x1",
							true,
							58
						),
						_luxury_item(
							"royal_book_of_hours",
							"Royal Book of Hours",
							"Illuminated Manuscript",
							"Collectibles",
							"vellum, gold leaf, pigment",
							52000,
							88000,
							"Private devotion rendered with the budget of a small village.",
							"EXCEPTIONAL",
							11,
							1435,
							"Paris",
							"Documented",
							"A later owner added one family birth and one execution.",
							"hero_2x2",
							true,
							47
						),
						_luxury_item(
							"seven_keys_reliquary",
							"Reliquary of the Seven Keys",
							"Reliquary",
							"Collectibles",
							"silver gilt, crystal",
							110000,
							170000,
							"Seven locks, six surviving keys, and a provenance argument nobody has finished.",
							"ONE OF ONE",
							1,
							1328,
							"Central Europe",
							"Contested",
							"Ownership records disappear during a monastery fire.",
							"hero_2x2",
							true,
							31
						),
						_luxury_item(
							"levant_silk_court_robe",
							"Levant Silk Court Robe",
							"Court Robe",
							"Fashion",
							"imported silk and gold thread",
							18000,
							23000,
							"Imported silk cut for a court where fabric announced rank before a person spoke.",
							"LIMITED",
							63,
							1502,
							"Levant Trade",
							"Documented",
							"Preserved examples become historic textiles in later eras.",
							"portrait_1x2",
							true,
							72
						)
					]
				}
			],

			"Industrial Era": [
				{
					"id": "industrial_grand_salon",
					"name": "The Grand Salon Exchange",
					"description": (
						"Chronometers, jewel houses, paintings, "
						+ "travel objects, and imported curiosities."
					),
					"fame_required": 10,
					"inventory": [
						_luxury_item(
							"meridian_grand_chronometer",
							"Meridian Grand Chronometer",
							"Chronometer",
							"Watches",
							"gold, enamel, jeweled movement",
							18500,
							26000,
							"A hand-finished precision instrument from an era when accurate time was power.",
							"EXCEPTIONAL",
							14,
							1886,
							"Geneva",
							"Documented",
							"Previously held by an ocean-liner financier.",
							"hero_2x2",
							true,
							48
						),
						_luxury_item(
							"belle_epoque_tiara",
							"Belle Époque Diamond Tiara",
							"Tiara",
							"Jewelry",
							"platinum and diamond",
							74000,
							116000,
							"An architectural tiara built for electric light and very public entrances.",
							"EXCEPTIONAL",
							8,
							1904,
							"Paris",
							"Documented",
							"Photographed at three diplomatic receptions.",
							"hero_2x2",
							true,
							39
						),
						_luxury_item(
							"maharaja_sapphire_brooch",
							"Maharaja Sapphire Brooch",
							"Brooch",
							"Jewelry",
							"sapphire and diamond",
							96000,
							148000,
							"A deep blue sapphire surrounded by old-cut diamonds.",
							"COLLECTOR",
							19,
							1899,
							"South Asia",
							"Partial",
							"European auction notes begin decades after its likely creation.",
							"portrait_1x2",
							true,
							45
						),
						_luxury_item(
							"salon_no_9",
							"Salon No. 9",
							"Oil Painting",
							"Art",
							"oil on canvas",
							53000,
							81000,
							"A large salon painting once dismissed as fashionable and now pursued as period-defining.",
							"COLLECTOR",
							28,
							1872,
							"Vienna",
							"Documented",
							"Three estate transfers are recorded on the reverse frame.",
							"landscape_2x1",
							true,
							56
						),
						_luxury_item(
							"grand_tour_trunk",
							"Grand Tour Lacquer Trunk",
							"Travel Trunk",
							"Fashion",
							"leather, brass, lacquer",
							12500,
							18000,
							"A monogrammed travel trunk built for somebody whose luggage had its own itinerary.",
							"LIMITED",
							73,
							1910,
							"London",
							"Documented",
							"Shipping labels trace six ports across two continents.",
							"portrait_1x2",
							true,
							69
						)
					]
				}
			],

			"Modern Era": [
				{
					"id": "modern_private_exchange",
					"name": "The Private Exchange",
					"description": (
						"Exceptional watches, jewels, couture, "
						+ "art, and private collection objects."
					),
					"fame_required": 0,
					"inventory": [
						_luxury_item(
							"the_seraphim",
							"THE SERAPHIM",
							"Platinum Chronograph",
							"Watches",
							"platinum and sapphire",
							267000,
							284500,
							"Hand-finished platinum chronograph with a sapphire exhibition case.",
							"EXCEPTIONAL",
							25,
							2024,
							"Geneva → Monaco",
							"Documented",
							"Edition 7 of 25. Current example entered the private market this year.",
							"hero_2x2",
							true,
							46
						),
						_luxury_item(
							"azure_empress",
							"THE AZURE EMPRESS",
							"Natural Sapphire",
							"Jewelry",
							"71.3 ct natural sapphire",
							4380000,
							4800000,
							"A museum-grade sapphire with color so saturated collectors argue about it in private.",
							"ONE OF ONE",
							1,
							1912,
							"Sri Lanka",
							"Contested",
							"Known owners: 4. Last documented private transfer: 1987.",
							"hero_2x2",
							true,
							33
						),
						_luxury_item(
							"imperial_tennis_necklace",
							"Imperial Tennis Necklace",
							"Diamond Necklace",
							"Jewelry",
							"platinum and diamond",
							198000,
							218000,
							"A deliberately severe line of matched diamonds with almost no visible setting.",
							"COLLECTOR",
							41,
							2019,
							"New York",
							"Documented",
							"Private collection consignment.",
							"portrait_1x2",
							true,
							62
						),
						_luxury_item(
							"atelier_serein_archive_bag",
							"Atelier Serein Archive Bag",
							"Designer Bag",
							"Fashion",
							"hand-finished leather",
							16900,
							18900,
							"An archive-run handbag produced in quantities low enough that owners recognize each other.",
							"LIMITED",
							144,
							2025,
							"Paris",
							"Documented",
							"Archive colorway retired after one season.",
							"standard_1x1",
							true,
							78
						),
						_luxury_item(
							"nocturne_seven",
							"Nocturne VII",
							"Contemporary Painting",
							"Art",
							"oil, carbon, gold leaf",
							445000,
							480000,
							"A monumental nocturne from an artist whose private-market supply is aggressively controlled.",
							"COLLECTOR",
							17,
							2021,
							"London",
							"Documented",
							"Acquired directly from the artist's studio before entering private resale.",
							"landscape_2x1",
							true,
							49
						),
						_luxury_item(
							"vesper_runway_trunk",
							"Vesper Runway Archive Trunk",
							"Couture Archive",
							"Fashion",
							"silk, crystal, hand embroidery",
							66000,
							72000,
							"A complete runway archive preserved as one collection rather than separated garment by garment.",
							"COLLECTOR",
							12,
							2017,
							"Milan",
							"Documented",
							"Never offered at public retail.",
							"landscape_2x1",
							true,
							42
						)
					]
				}
			],

			"Future Era": [
				{
					"id": "future_continuity_exchange",
					"name": "The Continuity Exchange",
					"description": (
						"Orbital jewelry, mnemonic objects, "
						+ "post-biological couture, and impossible collectibles."
					),
					"fame_required": 25,
					"inventory": [
						_luxury_item(
							"mnemonic_continuity_wafer",
							"Mnemonic Continuity Wafer",
							"Neural Archive",
							"Collectibles",
							"diamond memory lattice",
							18000000,
							24000000,
							"A licensed continuity snapshot capable of preserving a legally recognized cognitive state.",
							"EXCEPTIONAL",
							9,
							2188,
							"Geneva Continuity Bank",
							"Documented",
							"Ownership transfers are governed like inheritance rather than software.",
							"hero_2x2",
							true,
							41
						),
						_luxury_item(
							"vacuum_bloom_necklace",
							"Vacuum Bloom Necklace",
							"Orbital Necklace",
							"Jewelry",
							"vacuum-grown diamond",
							3200000,
							4100000,
							"Diamonds grown in orbital vacuum around a flexible zero-gravity platinum lattice.",
							"EXCEPTIONAL",
							18,
							2210,
							"Luna-Geneva Trade",
							"Documented",
							"Every stone carries its chamber telemetry in the provenance chain.",
							"hero_2x2",
							true,
							57
						),
						_luxury_item(
							"eventide_gravity_watch",
							"Eventide Gravity Chronometer",
							"Relativistic Chronometer",
							"Watches",
							"star-metal and sapphire",
							880000,
							1100000,
							"A chronometer designed to reconcile personal time across routine orbital travel.",
							"COLLECTOR",
							37,
							2196,
							"Orbital Geneva",
							"Documented",
							"Calibration record includes three lunar and two orbital owners.",
							"portrait_1x2",
							true,
							63
						),
						_luxury_item(
							"gene_locked_couture",
							"Gene-Locked Couture Skin",
							"Adaptive Couture",
							"Fashion",
							"programmable biofabric",
							420000,
							560000,
							"A garment that will only fully express its design on its registered biological owner.",
							"LIMITED",
							120,
							2204,
							"Paris Arcology",
							"Documented",
							"Re-registration requires the original design house.",
							"portrait_1x2",
							false,
							74
						),
						_luxury_item(
							"weather_room_sculpture",
							"Private Weather Room No. 3",
							"Immersive Sculpture",
							"Art",
							"atmospheric field architecture",
							6800000,
							7900000,
							"A room-sized artwork that owns its own weather system.",
							"ONE OF ONE",
							1,
							2222,
							"New Kyoto",
							"Documented",
							"One of three related works; each weather model is permanently unique.",
							"hero_2x2",
							false,
							29
						)
					]
				}
			]
		}
	}
func _modern_gemstone_capsule_shop_contract() -> Dictionary:
	var inventory: Array = [
		_luxury_item(
			"royal_asscher_emerald_ring",
			"Royal Asscher Emerald Ring",
			"Ring",
			"Jewelry",
			"Colombian emerald, platinum, diamond",
			385000,
			430000,
			"A deep-green Asscher-cut emerald framed as architecture rather than ornament.",
			"EXCEPTIONAL",
			11,
			2018,
			"Muzo, Colombia → Geneva",
			"Documented",
			"The cut was commissioned to preserve unusually broad emerald corners and a visible hall-of-mirrors depth.",
			"standard_1x1",
			true,
			97
		),
		_luxury_item(
			"pigeon_blood_oval_ruby_ring",
			"Pigeon Blood Oval Ruby Ring",
			"Ring",
			"Jewelry",
			"Burmese ruby, diamond, platinum",
			210000,
			238000,
			"An oval ruby whose saturated red remains vivid under both gallery and candle light.",
			"COLLECTOR",
			28,
			2016,
			"Mogok, Myanmar → Geneva",
			"Documented",
			"Private collectors prize the stone for color consistency rather than sheer carat weight.",
			"standard_1x1",
			true,
			96
		),
		_luxury_item(
			"pear_cut_diamond_halo_ring",
			"Pear-Cut Diamond Halo Ring",
			"Ring",
			"Jewelry",
			"Colorless diamond, platinum",
			128000,
			146000,
			"A clean pear-cut center stone held inside an almost invisible halo of calibrated diamonds.",
			"LIMITED",
			74,
			2023,
			"Antwerp → New York",
			"Documented",
			"A modern private-house setting known for an unusually low profile and uninterrupted face-up brilliance.",
			"standard_1x1",
			true,
			98
		),
		_luxury_item(
			"step_cut_emerald_tennis_bracelet",
			"Step-Cut Emerald Tennis Bracelet",
			"Bracelet",
			"Jewelry",
			"Emerald, diamond, platinum",
			295000,
			330000,
			"Matched step-cut emeralds create a continuous green line broken only by fine diamond separators.",
			"COLLECTOR",
			19,
			2020,
			"Bogotá → Paris",
			"Documented",
			"The stones were assembled over several years to keep hue and table proportions nearly identical.",
			"landscape_2x1",
			true,
			97
		),
		_luxury_item(
			"cabochon_ruby_cuff",
			"Cabochon Ruby Cuff",
			"Bracelet",
			"Jewelry",
			"Cabochon ruby, eighteen-karat gold",
			188000,
			215000,
			"A sculptural gold cuff punctuated by smooth cabochon rubies instead of faceted stones.",
			"COLLECTOR",
			32,
			2015,
			"Jaipur → Monaco",
			"Documented",
			"The house deliberately preserved natural surface character in each ruby rather than cutting for uniformity.",
			"landscape_2x1",
			true,
			95
		),
		_luxury_item(
			"baguette_diamond_line_bracelet",
			"Baguette Diamond Line Bracelet",
			"Bracelet",
			"Jewelry",
			"Baguette diamond, platinum",
			460000,
			520000,
			"A severe platinum line of calibrated baguette diamonds with almost no visible metal from above.",
			"EXCEPTIONAL",
			12,
			2022,
			"Antwerp → Geneva",
			"Documented",
			"Its stones were cut as a single visual sequence, making replacement without breaking the rhythm exceptionally difficult.",
			"landscape_2x1",
			true,
			94
		),
		_luxury_item(
			"pigeon_blood_ruby_riviere_necklace",
			"Pigeon Blood Ruby Rivière Necklace",
			"Necklace",
			"Jewelry",
			"Burmese ruby, diamond, platinum",
			720000,
			810000,
			"A continuous rivière of saturated rubies graduated so subtly that the necklace reads as one red arc.",
			"EXCEPTIONAL",
			8,
			2019,
			"Mogok, Myanmar → London",
			"Documented",
			"The matched color run is scarcer than any single stone in the necklace and drives most of its collector premium.",
			"landscape_2x1",
			true,
			94
		),
		_luxury_item(
			"marquise_diamond_collar",
			"Marquise Diamond Collar",
			"Necklace",
			"Jewelry",
			"Marquise diamond, platinum",
			540000,
			605000,
			"Graduated marquise diamonds form a sharp collar whose silhouette feels closer to couture than conventional fine jewelry.",
			"COLLECTOR",
			21,
			2021,
			"New York → Monaco",
			"Documented",
			"The necklace was designed around negative space, with every marquise point aligned to preserve the collar's graphic edge.",
			"landscape_2x1",
			true,
			96
		)
	]

	var visual_marks: Array = [
		"◇",
		"◆",
		"◈",
		"◇",
		"◆",
		"◈",
		"◇",
		"◆"
	]

	for index in range(inventory.size()):
		if typeof(inventory [index]) != TYPE_DICTIONARY:
			continue

		var item: Dictionary = inventory [index] as Dictionary
		item ["house"] = "MAISON CHROMATIQUE"
		item ["visual_mark"] = str(
			visual_marks [index % visual_marks.size()]
		)
		item ["gemstone_capsule"] = true
		item ["luxury_authored_truth"] = true

	return {
		"id": "maison_chromatique",
		"name": "Maison Chromatique",
		"description": (
			"Private cut-stone jewelry spanning rings, bracelets, "
			+ "necklaces, emeralds, rubies, and diamonds."
		),
		"fame_required": 25,
		"inventory": inventory
	}
func _luxury_orrery_reserve_shop_contract(
	era_name: String
) -> Dictionary:
	var clean_era: String = str(
		era_name
	).strip_edges()
	var shop_id: String = ""
	var shop_name: String = ""
	var shop_description: String = ""
	var rows: Array = []

	match clean_era:
		"Ancient Era":
			shop_id = "ancient_orrery_reserve"
			shop_name = "THE IMPERIAL RESERVE"
			shop_description = (
				"Royal jewels, sacred relics, antiquities, "
				+ "weapons, manuscripts, sculpture, and coinage "
				+ "held inside the ancient private market."
			)
			rows = [
				[
					"reserve_holy_grail",
					"The Holy Grail",
					"Reliquary Chalice",
					"Collectibles",
					"ancient gold, precious stone, sacred relic",
					1080000000,
					1200000000,
					"ONE OF ONE",
					1,
					33,
					"Judea → private sacred collections",
					"Contested but extensively documented",
					"portrait_1x2",
					true,
					"✦"
				],
				[
					"reserve_ark_of_the_covenant",
					"Ark of the Covenant",
					"Sacred Antiquity",
					"Collectibles",
					"gilded acacia wood, ancient metalwork",
					500000000,
					620000000,
					"ONE OF ONE",
					1,
					-1200,
					"Ancient Levant",
					"Contested sacred provenance",
					"landscape_2x1",
					true,
					"◇"
				],
				[
					"reserve_nile_emerald_collar",
					"Nile Emerald Collar",
					"Necklace",
					"Jewelry",
					"emerald, electrum, gold",
					185000000,
					220000000,
					"EXCEPTIONAL",
					7,
					-80,
					"Alexandria",
					"Royal collection record",
					"landscape_2x1",
					false,
					"◆"
				],
				[
					"reserve_ruby_serpent_ring",
					"Ruby Serpent Ring",
					"Ring",
					"Jewelry",
					"cabochon ruby, high-karat gold",
					92000000,
					108000000,
					"EXCEPTIONAL",
					9,
					-65,
					"Alexandria",
					"Documented",
					"standard_1x1",
					false,
					"◇"
				],
				[
					"reserve_ptolemaic_diamond_signet",
					"Ptolemaic Diamond Signet",
					"Ring",
					"Jewelry",
					"old-cut diamond, gold",
					118000000,
					142000000,
					"EXCEPTIONAL",
					5,
					-42,
					"Ptolemaic Egypt",
					"Documented",
					"standard_1x1",
					false,
					"◈"
				],
				[
					"reserve_persian_sapphire_torque",
					"Persian Sapphire Torque",
					"Necklace",
					"Jewelry",
					"sapphire, gold, lapis",
					146000000,
					174000000,
					"EXCEPTIONAL",
					8,
					-120,
					"Persia",
					"Documented",
					"landscape_2x1",
					false,
					"◆"
				],
				[
					"reserve_cleopatra_court_emerald",
					"Cleopatra Court Emerald",
					"Gemstone",
					"Jewelry",
					"uncut emerald crystal",
					205000000,
					248000000,
					"ONE OF ONE",
					1,
					-35,
					"Egyptian Eastern Desert",
					"Royal collection attribution",
					"standard_1x1",
					true,
					"◇"
				],
				[
					"reserve_macedonian_gold_diadem",
					"Macedonian Gold Diadem",
					"Crown",
					"Jewelry",
					"hammered gold, garnet",
					132000000,
					158000000,
					"EXCEPTIONAL",
					4,
					-280,
					"Macedonia",
					"Documented",
					"portrait_1x2",
					true,
					"♛"
				],
				[
					"reserve_lydian_lion_stater_set",
					"Lydian Lion Stater Set",
					"Rare Coin Set",
					"Collectibles",
					"electrum",
					54000000,
					67000000,
					"COLLECTOR",
					14,
					-560,
					"Lydia",
					"Documented",
					"standard_1x1",
					true,
					"◉"
				],
				[
					"reserve_imperial_aureus_proof_set",
					"Imperial Aureus Proof Set",
					"Rare Coin Set",
					"Collectibles",
					"Roman gold",
					73000000,
					91000000,
					"COLLECTOR",
					18,
					54,
					"Rome",
					"Documented",
					"standard_1x1",
					true,
					"◉"
				],
				[
					"reserve_imperial_marble_bust",
					"Imperial Marble Bust",
					"Sculpture",
					"Carrara marble",
					88000000,
					107000000,
					"EXCEPTIONAL",
					6,
					62,
					"Rome",
					"Documented",
					"portrait_1x2",
					true,
					"◆"
				],
				[
					"reserve_hellenistic_bronze_athlete",
					"Hellenistic Bronze Athlete",
					"Sculpture",
					"patinated bronze",
					76000000,
					93000000,
					"EXCEPTIONAL",
					8,
					-130,
					"Rhodes",
					"Documented",
					"portrait_1x2",
					true,
					"◇"
				],
				[
					"reserve_phoenician_electrum_bracelet",
					"Phoenician Electrum Bracelet",
					"Bracelet",
					"Jewelry",
					"electrum, garnet",
					48000000,
					59000000,
					"COLLECTOR",
					22,
					-310,
					"Tyre",
					"Documented",
					"landscape_2x1",
					false,
					"◆"
				],
				[
					"reserve_royal_lapis_pectoral",
					"Royal Lapis Pectoral",
					"Necklace",
					"Jewelry",
					"lapis lazuli, turquoise, gold",
					96000000,
					116000000,
					"EXCEPTIONAL",
					9,
					-220,
					"Memphis",
					"Documented",
					"landscape_2x1",
					false,
					"◇"
				],
				[
					"reserve_sumerian_royal_seal",
					"Sumerian Royal Cylinder Seal",
					"Antiquity",
					"Collectibles",
					"lapis lazuli, carved stone",
					41000000,
					51000000,
					"COLLECTOR",
					17,
					-2200,
					"Ur",
					"Documented",
					"standard_1x1",
					true,
					"◈"
				],
				[
					"reserve_jeweled_ceremonial_khopesh",
					"Jeweled Ceremonial Khopesh",
					"Historical Weapon",
					"Collectibles",
					"bronze, gold, lapis, carnelian",
					127000000,
					151000000,
					"EXCEPTIONAL",
					5,
					-840,
					"Thebes",
					"Documented",
					"portrait_1x2",
					true,
					"⚔"
				],
				[
					"reserve_royal_ivory_game_set",
					"Royal Ivory Game Set",
					"Collectible",
					"Collectibles",
					"ivory, ebony, gold",
					34000000,
					42000000,
					"COLLECTOR",
					26,
					-180,
					"Alexandria",
					"Documented",
					"landscape_2x1",
					false,
					"◇"
				],
				[
					"reserve_ptolemaic_star_tablet",
					"Ptolemaic Star Tablet",
					"Manuscript Tablet",
					"Collectibles",
					"stone, pigment, gold leaf",
					61000000,
					76000000,
					"EXCEPTIONAL",
					8,
					-95,
					"Alexandria",
					"Documented",
					"portrait_1x2",
					true,
					"✦"
				],
				[
					"reserve_royal_obsidian_mirror",
					"Royal Obsidian Mirror",
					"Antiquity",
					"Collectibles",
					"polished obsidian, gold",
					39000000,
					47000000,
					"COLLECTOR",
					20,
					-150,
					"Anatolia",
					"Documented",
					"standard_1x1",
					false,
					"◆"
				],
				[
					"reserve_tyrian_court_amphora",
					"Tyrian Court Amphora",
					"Antiquity",
					"Art",
					"painted ceramic, purple pigment",
					45000000,
					55000000,
					"COLLECTOR",
					16,
					-110,
					"Tyre",
					"Documented",
					"portrait_1x2",
					false,
					"◇"
				]
			]

		"Medieval Era":
			shop_id = "medieval_orrery_reserve"
			shop_name = "THE CROWN VAULT"
			shop_description = (
				"Crown jewels, court manuscripts, armor, "
				+ "reliquaries, tapestries, coinage, and "
				+ "dynastic private treasures."
			)
			rows = [
				[
					"reserve_black_prince_ruby_ring",
					"Black Prince Ruby Ring",
					"Ring",
					"Jewelry",
					"ruby, diamond, gold",
					185000000,
					225000000,
					"ONE OF ONE",
					1,
					1367,
					"England",
					"Royal provenance",
					"standard_1x1",
					true,
					"◆"
				],
				[
					"reserve_canterbury_emerald_signet",
					"Canterbury Emerald Signet",
					"Ring",
					"Jewelry",
					"emerald, gold",
					72000000,
					88000000,
					"EXCEPTIONAL",
					7,
					1215,
					"England",
					"Documented",
					"standard_1x1",
					false,
					"◇"
				],
				[
					"reserve_burgundian_diamond_ring",
					"Burgundian Diamond Ring",
					"Ring",
					"Jewelry",
					"table-cut diamond, gold",
					96000000,
					119000000,
					"EXCEPTIONAL",
					6,
					1462,
					"Burgundy",
					"Documented",
					"standard_1x1",
					false,
					"◈"
				],
				[
					"reserve_royal_sapphire_riviere",
					"Royal Sapphire Rivière",
					"Necklace",
					"Jewelry",
					"sapphire, pearl, gold",
					154000000,
					188000000,
					"EXCEPTIONAL",
					8,
					1428,
					"France",
					"Royal provenance",
					"landscape_2x1",
					true,
					"◆"
				],
				[
					"reserve_plantagenet_pearl_collar",
					"Plantagenet Pearl Collar",
					"Necklace",
					"Jewelry",
					"natural pearl, gold",
					118000000,
					144000000,
					"EXCEPTIONAL",
					9,
					1290,
					"England",
					"Documented",
					"landscape_2x1",
					true,
					"◇"
				],
				[
					"reserve_venetian_ducat_proof_set",
					"Venetian Ducat Proof Set",
					"Rare Coin Set",
					"Collectibles",
					"Venetian gold",
					48000000,
					59000000,
					"COLLECTOR",
					19,
					1350,
					"Venice",
					"Documented",
					"standard_1x1",
					true,
					"◉"
				],
				[
					"reserve_jeweled_crusader_sword",
					"Jeweled Crusader Sword",
					"Historical Weapon",
					"Collectibles",
					"steel, ruby, gold",
					132000000,
					160000000,
					"EXCEPTIONAL",
					5,
					1191,
					"Levant → Europe",
					"Documented",
					"portrait_1x2",
					true,
					"⚔"
				],
				[
					"reserve_gothic_ivory_triptych",
					"Gothic Ivory Triptych",
					"Antiquity",
					"Art",
					"carved ivory, gold leaf",
					86000000,
					103000000,
					"EXCEPTIONAL",
					7,
					1320,
					"Paris",
					"Documented",
					"portrait_1x2",
					true,
					"◇"
				],
				[
					"reserve_royal_jeweled_chess_set",
					"Royal Jeweled Chess Set",
					"Collectible",
					"Collectibles",
					"rock crystal, ruby, sapphire, gold",
					67000000,
					81000000,
					"COLLECTOR",
					15,
					1405,
					"Castile",
					"Documented",
					"landscape_2x1",
					false,
					"◆"
				],
				[
					"reserve_illuminated_royal_psalter",
					"Illuminated Royal Psalter",
					"Manuscript",
					"Collectibles",
					"vellum, gold leaf, mineral pigment",
					98000000,
					122000000,
					"EXCEPTIONAL",
					6,
					1250,
					"London",
					"Documented",
					"portrait_1x2",
					true,
					"✦"
				],
				[
					"reserve_coronation_mantle_valois",
					"Coronation Mantle of Valois",
					"Couture",
					"Fashion",
					"silk velvet, gold thread, ermine",
					84000000,
					101000000,
					"EXCEPTIONAL",
					4,
					1380,
					"France",
					"Royal provenance",
					"portrait_1x2",
					true,
					"◆"
				],
				[
					"reserve_florentine_bronze_saint",
					"Florentine Bronze Saint",
					"Sculpture",
					"Art",
					"gilt bronze",
					59000000,
					71000000,
					"COLLECTOR",
					12,
					1472,
					"Florence",
					"Documented",
					"portrait_1x2",
					true,
					"◇"
				],
				[
					"reserve_alabaster_queen_bust",
					"Alabaster Queen Bust",
					"Sculpture",
					"Art",
					"alabaster, gilt detail",
					74000000,
					89000000,
					"EXCEPTIONAL",
					8,
					1441,
					"Burgundy",
					"Documented",
					"portrait_1x2",
					true,
					"◆"
				],
				[
					"reserve_jeweled_reliquary_chalice",
					"Jeweled Reliquary Chalice",
					"Antiquity",
					"Collectibles",
					"gold, ruby, emerald, rock crystal",
					145000000,
					176000000,
					"EXCEPTIONAL",
					5,
					1180,
					"Constantinople",
					"Documented",
					"standard_1x1",
					true,
					"✦"
				],
				[
					"reserve_champion_tournament_helm",
					"Champion's Tournament Helm",
					"Historical Armor",
					"Collectibles",
					"steel, gilt brass, enamel",
					51000000,
					62000000,
					"COLLECTOR",
					13,
					1490,
					"German States",
					"Documented",
					"portrait_1x2",
					false,
					"◇"
				],
				[
					"reserve_royal_merchants_astrolabe",
					"Royal Merchant's Astrolabe",
					"Scientific Antiquity",
					"Collectibles",
					"engraved brass, silver",
					63000000,
					77000000,
					"COLLECTOR",
					14,
					1310,
					"Al-Andalus",
					"Documented",
					"standard_1x1",
					true,
					"◈"
				],
				[
					"reserve_emerald_reliquary_pendant",
					"Emerald Reliquary Pendant",
					"Necklace",
					"Jewelry",
					"emerald, pearl, gold",
					88000000,
					106000000,
					"EXCEPTIONAL",
					9,
					1345,
					"Venice",
					"Documented",
					"standard_1x1",
					false,
					"◆"
				],
				[
					"reserve_diamond_court_brooch",
					"Diamond Court Brooch",
					"Brooch",
					"Jewelry",
					"table-cut diamond, silver-gilt",
					69000000,
					83000000,
					"COLLECTOR",
					17,
					1488,
					"Milan",
					"Documented",
					"standard_1x1",
					false,
					"◇"
				],
				[
					"reserve_royal_tapestry_leon",
					"Royal Tapestry of León",
					"Tapestry",
					"Art",
					"silk, wool, gold thread",
					92000000,
					113000000,
					"EXCEPTIONAL",
					6,
					1264,
					"León",
					"Documented",
					"landscape_2x1",
					true,
					"◆"
				],
				[
					"reserve_crusader_gold_reliquary",
					"Crusader Gold Reliquary",
					"Antiquity",
					"Collectibles",
					"gold, enamel, rock crystal",
					101000000,
					124000000,
					"EXCEPTIONAL",
					7,
					1210,
					"Acre → Venice",
					"Documented",
					"standard_1x1",
					true,
					"✦"
				]
			]

		"Industrial Era":
			shop_id = "industrial_orrery_reserve"
			shop_name = "THE GRAND SALON"
			shop_description = (
				"Grand-complication watches, old-mine jewels, "
				+ "salon art, first editions, imperial collectibles, "
				+ "couture, and presentation arms."
			)
			rows = [
				[
					"reserve_geneva_split_seconds",
					"Geneva Split-Seconds Chronometer",
					"Chronometer",
					"Watches",
					"platinum, enamel, hand-finished movement",
					24000000,
					29000000,
					"EXCEPTIONAL",
					8,
					1898,
					"Geneva",
					"Manufacture archive",
					"portrait_1x2",
					true,
					"◉"
				],
				[
					"reserve_platinum_grand_complication",
					"Platinum Grand Complication",
					"Watch",
					"Watches",
					"platinum, sapphire crystal",
					38000000,
					46000000,
					"EXCEPTIONAL",
					5,
					1907,
					"Geneva",
					"Manufacture archive",
					"portrait_1x2",
					true,
					"◈"
				],
				[
					"reserve_old_mine_diamond_ring",
					"Old-Mine Diamond Ring",
					"Ring",
					"Jewelry",
					"old-mine diamond, platinum",
					31000000,
					38000000,
					"EXCEPTIONAL",
					9,
					1886,
					"Paris",
					"Documented",
					"standard_1x1",
					false,
					"◇"
				],
				[
					"reserve_mogok_ruby_halo_ring",
					"Mogok Ruby Halo Ring",
					"Ring",
					"Jewelry",
					"Burmese ruby, diamond, platinum",
					47000000,
					57000000,
					"EXCEPTIONAL",
					7,
					1902,
					"Mogok → London",
					"Documented",
					"standard_1x1",
					false,
					"◆"
				],
				[
					"reserve_colombian_emerald_cluster_ring",
					"Colombian Emerald Cluster Ring",
					"Ring",
					"Jewelry",
					"Colombian emerald, diamond, gold",
					42000000,
					51000000,
					"EXCEPTIONAL",
					8,
					1892,
					"Bogotá → Paris",
					"Documented",
					"standard_1x1",
					false,
					"◈"
				],
				[
					"reserve_sapphire_riviere_industrial",
					"Sapphire Rivière Necklace",
					"Necklace",
					"Jewelry",
					"Ceylon sapphire, diamond, platinum",
					58000000,
					70000000,
					"EXCEPTIONAL",
					6,
					1905,
					"Colombo → Paris",
					"Documented",
					"landscape_2x1",
					false,
					"◆"
				],
				[
					"reserve_diamond_line_bracelet_industrial",
					"Diamond Line Bracelet",
					"Bracelet",
					"Jewelry",
					"old-European diamond, platinum",
					36000000,
					44000000,
					"EXCEPTIONAL",
					11,
					1912,
					"New York",
					"Documented",
					"landscape_2x1",
					false,
					"◇"
				],
				[
					"reserve_imperial_opal_brooch",
					"Imperial Opal Brooch",
					"Brooch",
					"Jewelry",
					"black opal, diamond, platinum",
					27000000,
					33000000,
					"COLLECTOR",
					16,
					1909,
					"Australia → London",
					"Documented",
					"standard_1x1",
					false,
					"◆"
				],
				[
					"reserve_romanov_jeweled_egg",
					"House of Romanov Jeweled Egg",
					"Collectible",
					"Collectibles",
					"gold, enamel, diamond, ruby",
					125000000,
					155000000,
					"ONE OF ONE",
					1,
					1901,
					"St. Petersburg",
					"Imperial provenance",
					"standard_1x1",
					true,
					"✦"
				],
				[
					"reserve_parisian_society_portrait",
					"Parisian Society Portrait",
					"Painting",
					"Art",
					"oil on canvas",
					72000000,
					91000000,
					"EXCEPTIONAL",
					4,
					1889,
					"Paris",
					"Documented",
					"portrait_1x2",
					true,
					"◇"
				],
				[
					"reserve_impressionist_night_canvas",
					"Impressionist Night Canvas",
					"Painting",
					"Art",
					"oil on canvas",
					165000000,
					205000000,
					"ONE OF ONE",
					1,
					1891,
					"Paris",
					"Documented",
					"portrait_1x2",
					true,
					"◆"
				],
				[
					"reserve_bronze_dancer_maquette",
					"Bronze Dancer Maquette",
					"Sculpture",
					"Art",
					"patinated bronze",
					62000000,
					76000000,
					"EXCEPTIONAL",
					5,
					1884,
					"Paris",
					"Documented",
					"portrait_1x2",
					true,
					"◇"
				],
				[
					"reserve_natural_history_first_edition",
					"First-Edition Natural History Treatise",
					"Manuscript",
					"Collectibles",
					"leather, rag paper, hand engraving",
					19000000,
					24000000,
					"COLLECTOR",
					13,
					1859,
					"London",
					"Documented",
					"portrait_1x2",
					true,
					"✦"
				],
				[
					"reserve_victorian_sovereign_proofs",
					"Victorian Sovereign Proof Set",
					"Rare Coin Set",
					"Collectibles",
					"gold",
					16000000,
					20000000,
					"COLLECTOR",
					24,
					1887,
					"London",
					"Mint provenance",
					"standard_1x1",
					true,
					"◉"
				],
				[
					"reserve_presentation_dueling_pistols",
					"Presentation Dueling Pistols",
					"Historical Weapon",
					"Collectibles",
					"steel, walnut, gold inlay",
					22000000,
					27000000,
					"COLLECTOR",
					12,
					1846,
					"London",
					"Documented",
					"landscape_2x1",
					true,
					"⚔"
				],
				[
					"reserve_jeweled_cavalry_saber",
					"Jeweled Cavalry Saber",
					"Historical Weapon",
					"Collectibles",
					"steel, gold, sapphire",
					28000000,
					35000000,
					"COLLECTOR",
					9,
					1871,
					"Vienna",
					"Documented",
					"portrait_1x2",
					true,
					"⚔"
				],
				[
					"reserve_opera_couture_gown",
					"Opera Couture Gown",
					"Couture",
					"Fashion",
					"silk, beadwork, silver thread",
					18000000,
					23000000,
					"COLLECTOR",
					11,
					1908,
					"Paris",
					"Maison archive",
					"portrait_1x2",
					false,
					"◆"
				],
				[
					"reserve_grand_tour_jewel_case",
					"Grand Tour Lacquer Jewel Case",
					"Collectible",
					"Collectibles",
					"lacquer, gold, mother-of-pearl",
					14000000,
					18000000,
					"COLLECTOR",
					18,
					1878,
					"Florence",
					"Documented",
					"landscape_2x1",
					false,
					"◇"
				],
				[
					"reserve_imperial_silver_tea_service",
					"Imperial Silver Tea Service",
					"Collectible",
					"Collectibles",
					"sterling silver, gilt detail",
					26000000,
					32000000,
					"COLLECTOR",
					14,
					1895,
					"St. Petersburg",
					"Imperial provenance",
					"landscape_2x1",
					true,
					"◆"
				],
				[
					"reserve_salon_marble_bust",
					"Salon Marble Bust",
					"Sculpture",
					"Art",
					"Carrara marble",
					34000000,
					42000000,
					"COLLECTOR",
					10,
					1876,
					"Rome → Paris",
					"Documented",
					"portrait_1x2",
					true,
					"◇"
				]
			]

		"Modern Era":
			shop_id = "modern_orrery_reserve"
			shop_name = "THE PRIVATE CONSORTIUM"
			shop_description = (
				"High jewelry, independent watchmaking, blue-chip art, "
				+ "couture, aerospace memorabilia, and contemporary "
				+ "private-collection objects."
			)
			rows = [
				[
					"reserve_blue_moon_diamond_ring",
					"Blue Moon Diamond Ring",
					"Ring",
					"Jewelry",
					"fancy vivid blue diamond, platinum",
					72000000,
					86000000,
					"ONE OF ONE",
					1,
					2015,
					"Geneva",
					"Documented",
					"standard_1x1",
					true,
					"◇"
				],
				[
					"reserve_mogok_pigeon_blood_ring",
					"Mogok Pigeon-Blood Ruby Ring",
					"Ring",
					"Jewelry",
					"Burmese ruby, diamond, platinum",
					48000000,
					56000000,
					"EXCEPTIONAL",
					6,
					2018,
					"Mogok → Geneva",
					"Documented",
					"standard_1x1",
					false,
					"◆"
				],
				[
					"reserve_emerald_architecture_ring",
					"Emerald Architecture Ring",
					"Ring",
					"Jewelry",
					"Colombian emerald, diamond, platinum",
					39000000,
					47000000,
					"EXCEPTIONAL",
					8,
					2021,
					"Bogotá → Paris",
					"Documented",
					"standard_1x1",
					false,
					"◈"
				],
				[
					"reserve_pink_diamond_riviere",
					"Pink Diamond Rivière",
					"Necklace",
					"Jewelry",
					"fancy pink diamond, platinum",
					145000000,
					172000000,
					"EXCEPTIONAL",
					4,
					2022,
					"Geneva",
					"Documented",
					"landscape_2x1",
					false,
					"◇"
				],
				[
					"reserve_imperial_emerald_necklace",
					"Imperial Emerald Necklace",
					"Necklace",
					"Jewelry",
					"Colombian emerald, diamond, platinum",
					118000000,
					138000000,
					"EXCEPTIONAL",
					5,
					2019,
					"Geneva",
					"Documented",
					"landscape_2x1",
					false,
					"◆"
				],
				[
					"reserve_high_jewelry_diamond_cuff",
					"High-Jewelry Diamond Cuff",
					"Bracelet",
					"Jewelry",
					"diamond, platinum",
					56000000,
					67000000,
					"EXCEPTIONAL",
					9,
					2024,
					"Paris",
					"Maison archive",
					"landscape_2x1",
					false,
					"◈"
				],
				[
					"reserve_platinum_minute_repeater",
					"Platinum Minute Repeater",
					"Watch",
					"Watches",
					"platinum, sapphire, hand-finished movement",
					18000000,
					22000000,
					"EXCEPTIONAL",
					7,
					2020,
					"Geneva",
					"Manufacture archive",
					"portrait_1x2",
					false,
					"◉"
				],
				[
					"reserve_independent_grand_chime",
					"Independent Grand Chime",
					"Watch",
					"Watches",
					"white gold, titanium, sapphire",
					9600000,
					11800000,
					"EXCEPTIONAL",
					11,
					2025,
					"Geneva",
					"Manufacture archive",
					"portrait_1x2",
					false,
					"◈"
				],
				[
					"reserve_midnight_archive_couture",
					"Midnight Archive Couture",
					"Couture",
					"Fashion",
					"silk, crystal embroidery",
					4200000,
					5100000,
					"COLLECTOR",
					14,
					2023,
					"Paris",
					"Maison archive",
					"portrait_1x2",
					false,
					"◆"
				],
				[
					"reserve_sculptural_couture_bag",
					"Sculptural Couture Bag",
					"Bag",
					"Fashion",
					"exotic leather, diamond hardware",
					1800000,
					2300000,
					"COLLECTOR",
					22,
					2024,
					"Paris",
					"Maison archive",
					"standard_1x1",
					false,
					"◇"
				],
				[
					"reserve_apollo_flown_gold_medallion",
					"Apollo-Flown Gold Medallion",
					"Collectible",
					"Collectibles",
					"gold, aerospace provenance",
					26000000,
					34000000,
					"ONE OF ONE",
					1,
					1971,
					"Earth orbit → private collection",
					"Mission provenance",
					"standard_1x1",
					true,
					"✦"
				],
				[
					"reserve_midnight_dominion_canvas",
					"Midnight Dominion Canvas",
					"Painting",
					"Art",
					"oil and mixed media on canvas",
					78000000,
					94000000,
					"EXCEPTIONAL",
					3,
					1987,
					"New York",
					"Documented",
					"portrait_1x2",
					true,
					"◆"
				],
				[
					"reserve_meteorite_platinum_sculpture",
					"Meteorite Platinum Sculpture",
					"Sculpture",
					"Art",
					"meteorite iron, platinum",
					34000000,
					41000000,
					"EXCEPTIONAL",
					6,
					2017,
					"London",
					"Documented",
					"portrait_1x2",
					false,
					"◇"
				],
				[
					"reserve_rare_american_double_eagle",
					"Rare Double Eagle",
					"Rare Coin",
					"Collectibles",
					"gold",
					16000000,
					19500000,
					"EXCEPTIONAL",
					9,
					1933,
					"United States",
					"Mint provenance",
					"standard_1x1",
					true,
					"◉"
				],
				[
					"reserve_renaissance_master_drawing",
					"Renaissance Master Drawing",
					"Manuscript",
					"Collectibles",
					"ink, chalk, handmade paper",
					69000000,
					85000000,
					"ONE OF ONE",
					1,
					1510,
					"Florence → private collection",
					"Documented",
					"portrait_1x2",
					true,
					"✦"
				],
				[
					"reserve_royal_provenance_saber",
					"Royal-Provenance Saber",
					"Historical Weapon",
					"Collectibles",
					"Damascus steel, gold, diamond",
					31000000,
					38000000,
					"EXCEPTIONAL",
					4,
					1812,
					"Europe → private collection",
					"Documented",
					"portrait_1x2",
					true,
					"⚔"
				],
				[
					"reserve_ancient_gold_bar_modern",
					"Ancient Royal Gold Bar",
					"Precious Metal",
					"Collectibles",
					"high-purity archaeological gold",
					12000000,
					15000000,
					"COLLECTOR",
					18,
					-120,
					"Mediterranean → private vault",
					"Documented",
					"landscape_2x1",
					true,
					"◆"
				],
				[
					"reserve_archival_supercar_prototype",
					"Coachbuilt Supercar Prototype",
					"Collectible",
					"Collectibles",
					"carbon fiber, titanium",
					14000000,
					17000000,
					"EXCEPTIONAL",
					2,
					2025,
					"Modena",
					"Factory provenance",
					"landscape_2x1",
					false,
					"◇"
				],
				[
					"reserve_artist_proof_sculpture",
					"Artist-Proof Monumental Sculpture",
					"Sculpture",
					"Art",
					"bronze, polished steel",
					52000000,
					64000000,
					"EXCEPTIONAL",
					2,
					2009,
					"London",
					"Artist archive",
					"portrait_1x2",
					false,
					"◆"
				],
				[
					"reserve_private_archive_manuscript",
					"Private Archive Manuscript",
					"Manuscript",
					"Collectibles",
					"vellum, ink, gold illumination",
					29000000,
					36000000,
					"EXCEPTIONAL",
					5,
					1458,
					"Europe → private archive",
					"Documented",
					"portrait_1x2",
					true,
					"✦"
				]
			]

		"Future Era":
			shop_id = "future_orrery_reserve"
			shop_name = "THE CELESTIAL RESERVE"
			shop_description = (
				"Quantum jewelry, orbital horology, off-world "
				+ "materials, dynastic archives, zero-gravity couture, "
				+ "and interplanetary private collectibles."
			)
			rows = [
				[
					"reserve_quantum_emerald_ring",
					"Quantum Emerald Ring",
					"Ring",
					"Jewelry",
					"stabilized emerald, quantum platinum",
					85000000,
					103000000,
					"EXCEPTIONAL",
					7,
					2112,
					"New Geneva",
					"Documented",
					"standard_1x1",
					false,
					"◇"
				],
				[
					"reserve_star_sapphire_gravity_ring",
					"Star Sapphire Gravity Ring",
					"Ring",
					"Jewelry",
					"star sapphire, gravitic gold",
					112000000,
					136000000,
					"EXCEPTIONAL",
					5,
					2144,
					"Lunar Geneva",
					"Documented",
					"standard_1x1",
					false,
					"◆"
				],
				[
					"reserve_diamond_lattice_ring",
					"Diamond Lattice Ring",
					"Ring",
					"Jewelry",
					"grown diamond lattice, platinum",
					74000000,
					91000000,
					"EXCEPTIONAL",
					9,
					2098,
					"Neo-Antwerp",
					"Documented",
					"standard_1x1",
					false,
					"◈"
				],
				[
					"reserve_vacuum_pearl_collar",
					"Vacuum Pearl Collar",
					"Necklace",
					"Jewelry",
					"zero-gravity pearl, diamond filament",
					126000000,
					151000000,
					"EXCEPTIONAL",
					6,
					2160,
					"Orbital Atelier Seven",
					"Documented",
					"landscape_2x1",
					false,
					"◇"
				],
				[
					"reserve_martian_ruby_brooch",
					"Martian Ruby Brooch",
					"Brooch",
					"Jewelry",
					"Martian corundum, platinum",
					98000000,
					119000000,
					"EXCEPTIONAL",
					8,
					2181,
					"Mars",
					"Documented",
					"standard_1x1",
					false,
					"◆"
				],
				[
					"reserve_gravitic_tourbillon",
					"Gravitic Tourbillon",
					"Watch",
					"Watches",
					"quantum alloy, sapphire",
					44000000,
					53000000,
					"EXCEPTIONAL",
					7,
					2130,
					"New Geneva",
					"Manufacture archive",
					"portrait_1x2",
					false,
					"◉"
				],
				[
					"reserve_atomic_clock_bracelet",
					"Atomic Clock Bracelet",
					"Watch",
					"Watches",
					"platinum lattice, atomic oscillator",
					32000000,
					39000000,
					"COLLECTOR",
					15,
					2118,
					"Orbital Switzerland",
					"Manufacture archive",
					"portrait_1x2",
					false,
					"◈"
				],
				[
					"reserve_zero_g_coronation_crown",
					"Zero-G Coronation Crown",
					"Crown",
					"Jewelry",
					"diamond aerogel, gold lattice",
					410000000,
					495000000,
					"ONE OF ONE",
					1,
					2198,
					"Lunar Commonwealth",
					"Dynastic provenance",
					"portrait_1x2",
					true,
					"♛"
				],
				[
					"reserve_first_lunar_regolith_coin",
					"First Lunar Regolith Coin",
					"Rare Coin",
					"Collectibles",
					"lunar regolith composite, platinum",
					68000000,
					84000000,
					"ONE OF ONE",
					1,
					2089,
					"Luna",
					"Mint provenance",
					"standard_1x1",
					true,
					"◉"
				],
				[
					"reserve_asteroid_platinum_bar",
					"Asteroid Platinum Bar",
					"Precious Metal",
					"Collectibles",
					"asteroid platinum",
					53000000,
					65000000,
					"COLLECTOR",
					20,
					2152,
					"Vesta extraction zone",
					"Documented",
					"landscape_2x1",
					false,
					"◆"
				],
				[
					"reserve_exoplanet_meteorite_gem",
					"Exoplanet Meteorite Gem",
					"Gemstone",
					"Jewelry",
					"faceted extrasolar mineral",
					182000000,
					224000000,
					"ONE OF ONE",
					1,
					2220,
					"Kepler expedition return",
					"Mission provenance",
					"standard_1x1",
					true,
					"◇"
				],
				[
					"reserve_memory_crystal_sculpture",
					"Memory Crystal Sculpture",
					"Sculpture",
					"Art",
					"encoded crystal, photonic metal",
					94000000,
					116000000,
					"EXCEPTIONAL",
					4,
					2175,
					"New Kyoto",
					"Artist archive",
					"portrait_1x2",
					false,
					"◆"
				],
				[
					"reserve_holographic_dynasty_portrait",
					"Holographic Dynasty Portrait",
					"Painting",
					"Art",
					"volumetric light field",
					87000000,
					104000000,
					"EXCEPTIONAL",
					5,
					2204,
					"Orbital Paris",
					"Dynastic provenance",
					"portrait_1x2",
					false,
					"◇"
				],
				[
					"reserve_orbital_couture_cloak",
					"Orbital Couture Cloak",
					"Couture",
					"Fashion",
					"programmable silk, photon thread",
					46000000,
					57000000,
					"EXCEPTIONAL",
					8,
					2166,
					"Orbital Paris",
					"Maison archive",
					"portrait_1x2",
					false,
					"◆"
				],
				[
					"reserve_gene_silk_archive_bag",
					"Gene-Silk Archive Bag",
					"Bag",
					"Fashion",
					"gene-silk, diamond hardware",
					21000000,
					26000000,
					"COLLECTOR",
					17,
					2148,
					"New Milan",
					"Maison archive",
					"standard_1x1",
					false,
					"◇"
				],
				[
					"reserve_first_mars_treaty",
					"Original First Mars Treaty",
					"Manuscript",
					"Collectibles",
					"archival smart-paper, sovereign seals",
					260000000,
					315000000,
					"ONE OF ONE",
					1,
					2107,
					"Mars",
					"Sovereign archive",
					"portrait_1x2",
					true,
					"✦"
				],
				[
					"reserve_solar_sail_maquette",
					"Solar Sail Maquette",
					"Collectible",
					"Collectibles",
					"gold film, carbon lattice",
					39000000,
					48000000,
					"COLLECTOR",
					12,
					2122,
					"Luna",
					"Mission provenance",
					"landscape_2x1",
					false,
					"◇"
				],
				[
					"reserve_fusion_ceremonial_blade",
					"Fusion Ceremonial Blade",
					"Historical Weapon",
					"Collectibles",
					"fusion-forged alloy, diamond edge",
					78000000,
					95000000,
					"EXCEPTIONAL",
					6,
					2188,
					"Mars",
					"Documented",
					"portrait_1x2",
					false,
					"⚔"
				],
				[
					"reserve_orbital_republic_medallion",
					"Orbital Republic Medallion",
					"Rare Coin",
					"Collectibles",
					"iridium, platinum",
					33000000,
					41000000,
					"COLLECTOR",
					21,
					2137,
					"Lunar Republic",
					"Mint provenance",
					"standard_1x1",
					false,
					"◉"
				],
				[
					"reserve_quantum_archive_reliquary",
					"Quantum Archive Reliquary",
					"Antiquity",
					"Collectibles",
					"diamond memory lattice, gold",
					138000000,
					169000000,
					"EXCEPTIONAL",
					3,
					2211,
					"New Kyoto",
					"Documented",
					"standard_1x1",
					true,
					"✦"
				]
			]

		_:
			return {}

	var inventory: Array = []

	for raw_row in rows:
		if typeof(raw_row) != TYPE_ARRAY:
			continue

		var row: Array = raw_row as Array

		if row.size() < 15:
			continue

		var item_name: String = str(row [1])
		var item_type: String = str(row [2])
		var material: String = str(row [4])
		var origin: String = str(row [10])
		var item: Dictionary = _luxury_item(
			str(row [0]),
			item_name,
			item_type,
			str(row [3]),
			material,
			int(row [5]),
			int(row [6]),
			(
				"%s is a resident private-market %s composed around %s."
				% [
					item_name,
					item_type.to_lower(),
					material
				]
			),
			str(row [7]),
			int(row [8]),
			int(row [9]),
			origin,
			str(row [11]),
			(
				"%s remains catalogued through %s and can enter "
				+ "the Luxury Exchange only through Luxury authority."
			)
			% [
				item_name,
				origin
			],
			str(row [12]),
			bool(row [13]),
			100
		)

		item ["house"] = shop_name
		item ["visual_mark"] = str(row [14])
		item ["orrery_reserve_truth"] = true
		item ["catalog_era"] = clean_era

		inventory.append(
			item
		)

	return {
		"id": shop_id,
		"name": shop_name,
		"description": shop_description,
		"fame_required": 0,
		"inventory": inventory
	}
func _make_luxury_item_instance_id(actor: Person, item: Dictionary) -> String:
	var actor_id: int = int(actor.id) if actor != null and "id" in actor else 0
	var base_id: String = str(item.get("id", item.get("item_id", "luxury_item"))).strip_edges()
	if base_id == "":
		base_id = "luxury_item"
	return "luxury.%d.%s.%d" % [
		actor_id,
		base_id.replace(" ", "_").to_lower(),
		int(Time.get_ticks_msec())
	]


func _is_proposal_worthy_item(item: Dictionary) -> bool:
	var type_text: String = str(item.get("type", "")).strip_edges().to_lower()
	var material_text: String = str(item.get("material", "")).strip_edges().to_lower()
	var name_text: String = str(item.get("name", "")).strip_edges().to_lower()

	if type_text.find("ring") >= 0:
		return true
	if name_text.find("ring") >= 0:
		return true
	if material_text.find("diamond") >= 0:
		return true
	if material_text.find("pearl") >= 0:
		return true
	if type_text.find("jewelry") >= 0:
		return true

	return false
func _luxury_temporal_foundation_inventory(
	era_name: String
) -> Array:
	var clean_era: String = str(
		era_name
	).strip_edges()
	var foundation_year: int = 0
	var house_name: String = ""
	var rows: Array = []

	match clean_era:
		"Medieval Era":
			foundation_year = 500
			house_name = "THE CROWN VAULT"
			rows = [
				[
					"medieval_foundation_byzantine_emerald_pectoral",
					"Byzantine Emerald Pectoral",
					"Necklace",
					"Jewelry",
					"emerald, pearl, high-karat gold",
					18000000,
					24000000,
					"EXCEPTIONAL",
					8,
					"Constantinople",
					"Palace treasury provenance",
					"landscape_2x1",
					true,
					"◆"
				],
				[
					"medieval_foundation_ostrogothic_garnet_fibula",
					"Ostrogothic Garnet Eagle Fibula",
					"Brooch",
					"Jewelry",
					"garnet, gold, cloisonné glass",
					9800000,
					12400000,
					"COLLECTOR",
					14,
					"Ravenna",
					"Documented court provenance",
					"standard_1x1",
					true,
					"◇"
				],
				[
					"medieval_foundation_merovingian_sapphire_signet",
					"Merovingian Sapphire Signet",
					"Ring",
					"Jewelry",
					"sapphire, gold",
					11500000,
					14200000,
					"EXCEPTIONAL",
					9,
					"Frankish Courts",
					"Documented",
					"standard_1x1",
					true,
					"◈"
				],
				[
					"medieval_foundation_sasanian_pearl_collar",
					"Sasanian Pearl Court Collar",
					"Necklace",
					"Jewelry",
					"natural pearl, gold, garnet",
					14000000,
					17000000,
					"EXCEPTIONAL",
					7,
					"Ctesiphon",
					"Court collection provenance",
					"landscape_2x1",
					true,
					"◆"
				],
				[
					"medieval_foundation_aksumite_gold_torque",
					"Aksumite Gold Torque",
					"Necklace",
					"Jewelry",
					"hammered gold, carnelian",
					7200000,
					9400000,
					"COLLECTOR",
					18,
					"Aksum",
					"Documented",
					"standard_1x1",
					true,
					"◇"
				],
				[
					"medieval_foundation_ravenna_cameo_ring",
					"Ravenna Imperial Cameo Ring",
					"Ring",
					"Jewelry",
					"sardonyx, gold",
					8800000,
					11100000,
					"COLLECTOR",
					13,
					"Ravenna",
					"Documented",
					"standard_1x1",
					true,
					"◈"
				],
				[
					"medieval_foundation_cloisonne_processional_cross",
					"Imperial Cloisonné Processional Cross",
					"Reliquary",
					"Collectibles",
					"gold, garnet, enamel",
					21000000,
					27000000,
					"EXCEPTIONAL",
					5,
					"Constantinople",
					"Ecclesiastical treasury record",
					"portrait_1x2",
					true,
					"✦"
				],
				[
					"medieval_foundation_silver_reliquary_chalice",
					"Silver-Gilt Reliquary Chalice",
					"Reliquary Chalice",
					"Collectibles",
					"silver-gilt, rock crystal",
					16500000,
					20800000,
					"EXCEPTIONAL",
					6,
					"Ravenna",
					"Documented",
					"standard_1x1",
					true,
					"✦"
				],
				[
					"medieval_foundation_purple_gospel_codex",
					"Purple Gospel Codex",
					"Manuscript",
					"Collectibles",
					"purple vellum, gold and silver ink",
					28000000,
					36000000,
					"EXCEPTIONAL",
					4,
					"Constantinople",
					"Scriptorium provenance",
					"portrait_1x2",
					true,
					"✦"
				],
				[
					"medieval_foundation_consular_ivory_diptych",
					"Consular Ivory Diptych",
					"Carved Diptych",
					"Art",
					"carved ivory",
					17000000,
					22000000,
					"EXCEPTIONAL",
					7,
					"Constantinople",
					"Documented",
					"portrait_1x2",
					true,
					"◇"
				],
				[
					"medieval_foundation_ravenna_mosaic_icon",
					"Ravenna Mosaic Icon Panel",
					"Mosaic Panel",
					"Art",
					"glass tesserae, gold leaf",
					24000000,
					31000000,
					"EXCEPTIONAL",
					5,
					"Ravenna",
					"Documented basilica workshop provenance",
					"portrait_1x2",
					true,
					"◆"
				],
				[
					"medieval_foundation_byzantine_silk_mantle",
					"Byzantine Silk Court Mantle",
					"Couture",
					"Fashion",
					"silk, gold thread, pearl",
					13000000,
					17500000,
					"EXCEPTIONAL",
					9,
					"Constantinople",
					"Court wardrobe provenance",
					"portrait_1x2",
					true,
					"◆"
				],
				[
					"medieval_foundation_gold_thread_hanging",
					"Gold-Thread Hunting Hanging",
					"Tapestry",
					"Art",
					"wool, silk, gold thread",
					11800000,
					15000000,
					"COLLECTOR",
					11,
					"Eastern Mediterranean",
					"Documented",
					"landscape_2x1",
					true,
					"◇"
				],
				[
					"medieval_foundation_gilt_ceremonial_spatha",
					"Gilt Ceremonial Spatha",
					"Historical Weapon",
					"Collectibles",
					"pattern-welded steel, gold, garnet",
					15500000,
					19500000,
					"EXCEPTIONAL",
					8,
					"Northern Italy",
					"Documented",
					"portrait_1x2",
					true,
					"⚔"
				],
				[
					"medieval_foundation_jeweled_guard_helm",
					"Jeweled Guard Helm",
					"Historical Armor",
					"Collectibles",
					"iron, gilt bronze, garnet",
					12800000,
					16400000,
					"COLLECTOR",
					10,
					"Ravenna",
					"Guard armory provenance",
					"portrait_1x2",
					true,
					"◇"
				],
				[
					"medieval_foundation_royal_parade_saddle",
					"Royal Parade Saddle",
					"Court Object",
					"Collectibles",
					"leather, silver-gilt, garnet",
					8700000,
					11200000,
					"COLLECTOR",
					16,
					"Iberian Courts",
					"Documented",
					"landscape_2x1",
					false,
					"◆"
				],
				[
					"medieval_foundation_rock_crystal_casket",
					"Rock-Crystal Court Casket",
					"Reliquary Casket",
					"Collectibles",
					"rock crystal, silver-gilt",
					10600000,
					13900000,
					"COLLECTOR",
					12,
					"Constantinople",
					"Documented",
					"standard_1x1",
					true,
					"◇"
				],
				[
					"medieval_foundation_solidus_treasury_set",
					"Imperial Solidus Treasury Set",
					"Rare Coin Set",
					"Collectibles",
					"Byzantine gold",
					6800000,
					8900000,
					"COLLECTOR",
					24,
					"Constantinople",
					"Mint and treasury provenance",
					"standard_1x1",
					true,
					"◉"
				],
				[
					"medieval_foundation_celestial_instrument",
					"Brass Celestial Instrument",
					"Scientific Antiquity",
					"Collectibles",
					"engraved brass, silver inlay",
					9400000,
					12200000,
					"COLLECTOR",
					13,
					"Alexandria → Constantinople",
					"Scholarly collection provenance",
					"standard_1x1",
					true,
					"◈"
				],
				[
					"medieval_foundation_silver_incense_ship",
					"Silver Incense Ship",
					"Ceremonial Vessel",
					"Collectibles",
					"silver, niello, rock crystal",
					7600000,
					9800000,
					"COLLECTOR",
					18,
					"Mediterranean Court",
					"Documented",
					"standard_1x1",
					true,
					"✦"
				],
				[
					"medieval_foundation_strategy_game_set",
					"Carved Royal Strategy Game Set",
					"Collectible",
					"Collectibles",
					"ivory, ebony, garnet",
					5900000,
					7700000,
					"COLLECTOR",
					21,
					"Eastern Mediterranean",
					"Documented",
					"landscape_2x1",
					false,
					"◇"
				],
				[
					"medieval_foundation_amber_drinking_horn",
					"Amber Ceremonial Drinking Horn",
					"Court Object",
					"Collectibles",
					"amber, silver-gilt",
					5400000,
					7100000,
					"LIMITED",
					27,
					"Baltic Trade → Royal Court",
					"Documented",
					"portrait_1x2",
					false,
					"◆"
				],
				[
					"medieval_foundation_enamel_brooch_pair",
					"Enamel Court Brooch Pair",
					"Brooch",
					"Jewelry",
					"gold, enamel, garnet",
					6900000,
					8800000,
					"COLLECTOR",
					19,
					"Ravenna",
					"Documented",
					"standard_1x1",
					false,
					"◇"
				],
				[
					"medieval_foundation_porphyry_diptych",
					"Porphyry Imperial Diptych",
					"Carved Panel",
					"Art",
					"porphyry, gilt detail",
					14700000,
					18800000,
					"EXCEPTIONAL",
					6,
					"Constantinople",
					"Palace collection provenance",
					"portrait_1x2",
					true,
					"◆"
				],
				[
					"medieval_foundation_scriptorium_masterwork_set",
					"Royal Scriptorium Masterwork Set",
					"Manuscript Set",
					"Collectibles",
					"vellum, mineral pigment, gold leaf",
					8200000,
					10600000,
					"COLLECTOR",
					15,
					"Constantinople",
					"Scriptorium provenance",
					"landscape_2x1",
					true,
					"✦"
				],
				[
					"medieval_foundation_lapis_reliquary_casket",
					"Lapis Reliquary Casket",
					"Reliquary Casket",
					"Collectibles",
					"lapis lazuli, gold, rock crystal",
					12400000,
					15900000,
					"EXCEPTIONAL",
					8,
					"Eastern Mediterranean",
					"Documented",
					"standard_1x1",
					true,
					"✦"
				]
			]

		"Industrial Era":
			foundation_year = 1800
			house_name = "THE GRAND SALON"
			rows = [
				[
					"industrial_foundation_georgian_diamond_riviere",
					"Georgian Old-Mine Diamond Rivière",
					"Necklace",
					"Jewelry",
					"old-mine diamond, silver, gold",
					24000000,
					30000000,
					"EXCEPTIONAL",
					8,
					"London",
					"Documented aristocratic provenance",
					"landscape_2x1",
					true,
					"◆"
				],
				[
					"industrial_foundation_regency_emerald_parure",
					"Regency Emerald Parure",
					"Jewelry Suite",
					"Jewelry",
					"emerald, diamond, gold",
					28000000,
					35000000,
					"EXCEPTIONAL",
					7,
					"London",
					"Court collection provenance",
					"landscape_2x1",
					true,
					"◈"
				],
				[
					"industrial_foundation_empire_sapphire_tiara",
					"Empire Sapphire Tiara",
					"Tiara",
					"Jewelry",
					"sapphire, diamond, gold",
					31000000,
					39000000,
					"EXCEPTIONAL",
					6,
					"Paris",
					"Documented",
					"portrait_1x2",
					true,
					"♛"
				],
				[
					"industrial_foundation_rose_cut_cluster_ring",
					"Rose-Cut Diamond Cluster Ring",
					"Ring",
					"Jewelry",
					"rose-cut diamond, silver, gold",
					8500000,
					10800000,
					"COLLECTOR",
					18,
					"Amsterdam → London",
					"Documented",
					"standard_1x1",
					false,
					"◇"
				],
				[
					"industrial_foundation_natural_pearl_collar",
					"Natural Pearl Court Collar",
					"Necklace",
					"Jewelry",
					"natural pearl, gold",
					12000000,
					15500000,
					"EXCEPTIONAL",
					12,
					"London",
					"Documented",
					"landscape_2x1",
					true,
					"◆"
				],
				[
					"industrial_foundation_hardstone_cameo_suite",
					"Hardstone Cameo Suite",
					"Jewelry Suite",
					"Jewelry",
					"agate cameo, gold",
					6900000,
					8700000,
					"COLLECTOR",
					20,
					"Rome → Paris",
					"Grand Tour provenance",
					"standard_1x1",
					false,
					"◇"
				],
				[
					"industrial_foundation_quarter_repeater_watch",
					"Gold Quarter-Repeater Pocket Watch",
					"Pocket Watch",
					"Watches",
					"gold, enamel, jeweled movement",
					7800000,
					10100000,
					"EXCEPTIONAL",
					11,
					"Geneva",
					"Manufacture archive",
					"portrait_1x2",
					true,
					"◉"
				],
				[
					"industrial_foundation_marine_box_chronometer",
					"Marine Box Chronometer",
					"Chronometer",
					"Watches",
					"brass, mahogany, jeweled movement",
					6400000,
					8200000,
					"COLLECTOR",
					16,
					"London",
					"Observatory calibration record",
					"standard_1x1",
					true,
					"◈"
				],
				[
					"industrial_foundation_musical_pocket_watch",
					"Enamel Musical Pocket Watch",
					"Pocket Watch",
					"Watches",
					"gold, enamel, mechanical automaton",
					9200000,
					11800000,
					"EXCEPTIONAL",
					9,
					"Geneva",
					"Manufacture archive",
					"standard_1x1",
					true,
					"◉"
				],
				[
					"industrial_foundation_silk_court_train",
					"Silk Court Train",
					"Couture",
					"Fashion",
					"silk satin, metallic embroidery",
					5600000,
					7400000,
					"COLLECTOR",
					14,
					"Paris",
					"Court wardrobe provenance",
					"portrait_1x2",
					false,
					"◆"
				],
				[
					"industrial_foundation_empire_gown",
					"Embroidered Empire Gown",
					"Couture",
					"Fashion",
					"silk, silver thread, seed pearl",
					4800000,
					6300000,
					"COLLECTOR",
					17,
					"Paris",
					"Documented",
					"portrait_1x2",
					false,
					"◇"
				],
				[
					"industrial_foundation_grand_tour_dispatch_trunk",
					"Grand Tour Dispatch Trunk",
					"Travel Trunk",
					"Fashion",
					"leather, brass, mahogany",
					4200000,
					5600000,
					"COLLECTOR",
					21,
					"London",
					"Family archive provenance",
					"landscape_2x1",
					false,
					"◆"
				],
				[
					"industrial_foundation_neoclassical_society_portrait",
					"Neoclassical Society Portrait",
					"Painting",
					"Art",
					"oil on canvas",
					14000000,
					18000000,
					"EXCEPTIONAL",
					6,
					"Paris",
					"Documented",
					"portrait_1x2",
					true,
					"◇"
				],
				[
					"industrial_foundation_carrara_muse_bust",
					"Carrara Muse Bust",
					"Sculpture",
					"Art",
					"Carrara marble",
					11500000,
					14700000,
					"COLLECTOR",
					9,
					"Florence",
					"Studio provenance",
					"portrait_1x2",
					true,
					"◆"
				],
				[
					"industrial_foundation_romantic_landscape",
					"Romantic Landscape Masterwork",
					"Painting",
					"Art",
					"oil on canvas",
					18000000,
					23000000,
					"EXCEPTIONAL",
					5,
					"London",
					"Documented",
					"landscape_2x1",
					true,
					"◆"
				],
				[
					"industrial_foundation_imperial_porcelain_service",
					"Imperial Porcelain Service",
					"Decorative Arts",
					"Collectibles",
					"porcelain, gilt decoration",
					7400000,
					9500000,
					"COLLECTOR",
					13,
					"Sèvres",
					"Factory and court provenance",
					"landscape_2x1",
					true,
					"◇"
				],
				[
					"industrial_foundation_regency_silver_tea_service",
					"Regency Silver Tea Service",
					"Silver Service",
					"Collectibles",
					"sterling silver, ivory",
					5800000,
					7200000,
					"COLLECTOR",
					18,
					"London",
					"Silversmith archive",
					"landscape_2x1",
					false,
					"◇"
				],
				[
					"industrial_foundation_dueling_pistol_case",
					"Presentation Dueling Pistol Case",
					"Historical Weapon",
					"Collectibles",
					"steel, walnut, gold inlay",
					6200000,
					8000000,
					"COLLECTOR",
					12,
					"London",
					"Maker and owner provenance",
					"landscape_2x1",
					true,
					"⚔"
				],
				[
					"industrial_foundation_campaign_writing_desk",
					"Mahogany Campaign Writing Desk",
					"Furniture",
					"Collectibles",
					"mahogany, brass, leather",
					4900000,
					6400000,
					"COLLECTOR",
					17,
					"London",
					"Documented",
					"landscape_2x1",
					false,
					"◇"
				],
				[
					"industrial_foundation_imperial_atlas",
					"First-Edition Imperial Atlas",
					"Rare Book",
					"Collectibles",
					"rag paper, leather, hand engraving",
					8800000,
					11300000,
					"EXCEPTIONAL",
					10,
					"London",
					"Publisher and library provenance",
					"portrait_1x2",
					true,
					"✦"
				],
				[
					"industrial_foundation_sovereign_coin_cabinet",
					"Sovereign Coin Cabinet",
					"Rare Coin Set",
					"Collectibles",
					"gold, silver, mahogany cabinet",
					10500000,
					13400000,
					"COLLECTOR",
					15,
					"London",
					"Mint and collector provenance",
					"standard_1x1",
					true,
					"◉"
				],
				[
					"industrial_foundation_scientific_instrument_cabinet",
					"Brass Scientific Instrument Cabinet",
					"Scientific Collection",
					"Collectibles",
					"brass, glass, mahogany",
					6700000,
					8500000,
					"COLLECTOR",
					14,
					"Paris",
					"Academy provenance",
					"landscape_2x1",
					true,
					"◈"
				],
				[
					"industrial_foundation_grand_salon_orrery",
					"Grand Salon Orrery",
					"Astronomical Instrument",
					"Collectibles",
					"brass, enamel, mahogany",
					9400000,
					12000000,
					"EXCEPTIONAL",
					8,
					"London",
					"Royal instrument-maker provenance",
					"landscape_2x1",
					true,
					"◈"
				],
				[
					"industrial_foundation_crystal_ormolu_candelabra",
					"Crystal & Ormolu Candelabra Pair",
					"Decorative Arts",
					"Art",
					"cut crystal, gilt bronze",
					5100000,
					6800000,
					"COLLECTOR",
					16,
					"Paris",
					"Documented",
					"portrait_1x2",
					false,
					"◇"
				],
				[
					"industrial_foundation_royal_gold_snuff_box",
					"Royal Gold Snuff Box",
					"Court Object",
					"Collectibles",
					"gold, enamel, diamond",
					4700000,
					6200000,
					"COLLECTOR",
					20,
					"Paris",
					"Court gift provenance",
					"standard_1x1",
					true,
					"◆"
				],
				[
					"industrial_foundation_naval_presentation_sabre",
					"Naval Presentation Sabre",
					"Historical Weapon",
					"Collectibles",
					"steel, gilt brass, ivory",
					7300000,
					9200000,
					"COLLECTOR",
					11,
					"London",
					"Naval presentation provenance",
					"portrait_1x2",
					true,
					"⚔"
				]
			]

		_:
			return []

	var out: Array = []

	for raw_row in rows:
		if typeof(raw_row) != TYPE_ARRAY:
			continue

		var row: Array = raw_row as Array

		if row.size() < 14:
			continue

		var item_name: String = str(
			row [1]
		)
		var item_type: String = str(
			row [2]
		)
		var origin: String = str(
			row [9]
		)
		var item: Dictionary = _luxury_item(
			str(row [0]),
			item_name,
			item_type,
			str(row [3]),
			str(row [4]),
			int(row [5]),
			int(row [6]),
			(
				"%s is canonical resident luxury from the opening "
				+ "temporal frontier of %s."
			)
			% [
				item_name,
				clean_era
			],
			str(row [7]),
			int(row [8]),
			foundation_year,
			origin,
			str(row [10]),
			(
				"%s is already resident at the %s foundation year "
				+ "and remains independently owned by LuxuryShopEngine."
			)
			% [
				item_name,
				clean_era
			],
			str(row [11]),
			bool(row [12]),
			100
		)

		item ["house"] = house_name
		item ["visual_mark"] = str(
			row [13]
		)
		item ["orrery_reserve_truth"] = true
		item ["luxury_authored_truth"] = true
		item ["temporal_foundation_reserve_truth"] = true
		item ["temporal_foundation_year"] = foundation_year
		item ["catalog_era"] = clean_era
		item ["renderer_generated"] = false

		out.append(
			item
		)

	return out
func get_shops_for_era(
	era_name: String = ""
) -> Array:
	var resolved_era: String = str(
		era_name
	).strip_edges()

	if resolved_era == "":
		resolved_era = (
			_era_name_from_context()
		)

	var all_eras: Array = (
		_all_luxury_era_names()
	)

	if resolved_era not in all_eras:
		resolved_era = "Modern Era"

	var eras: Dictionary = (
		luxury_contract.get(
			"eras",
			{}
		)
		if typeof(
			luxury_contract.get(
				"eras",
				{}
			)
		) == TYPE_DICTIONARY
		else {}
	)
	var out: Array = []
	var base_raw: Variant = eras.get(
		resolved_era,
		[]
	)

	if typeof(base_raw) == TYPE_ARRAY:
		for raw_shop in base_raw as Array:
			if typeof(raw_shop) != TYPE_DICTIONARY:
				continue

			out.append(
				(
					raw_shop as Dictionary
				).duplicate(true)
			)

	var extension_contract: Dictionary = (
		_luxury_exchange_extension_contract()
	)
	var extension_eras: Dictionary = (
		_safe_dictionary(
			extension_contract.get(
				"eras",
				{}
			)
		)
	)
	var extension_raw: Variant = (
		extension_eras.get(
			resolved_era,
			[]
		)
	)

	if typeof(extension_raw) == TYPE_ARRAY:
		for raw_shop in extension_raw as Array:
			if typeof(raw_shop) != TYPE_DICTIONARY:
				continue

			var shop: Dictionary = (
				(raw_shop as Dictionary)
				.duplicate(true)
			)
			var shop_id: String = str(
				shop.get(
					"id",
					""
				)
			).strip_edges()
			var duplicate_shop: bool = false

			for raw_existing in out:
				if typeof(raw_existing) != TYPE_DICTIONARY:
					continue

				if str(
					(raw_existing as Dictionary).get(
						"id",
						""
					)
				) == shop_id:
					duplicate_shop = true
					break

			if not duplicate_shop:
				out.append(
					shop
				)




	if resolved_era == "Modern Era":
		var gemstone_shop: Dictionary = (
			_modern_gemstone_capsule_shop_contract()
		)
		var gemstone_shop_id: String = str(
			gemstone_shop.get(
				"id",
				""
			)
		).strip_edges()
		var gemstone_duplicate: bool = false

		for raw_existing in out:
			if typeof(raw_existing) != TYPE_DICTIONARY:
				continue

			if str(
				(raw_existing as Dictionary).get(
					"id",
					""
				)
			) == gemstone_shop_id:
				gemstone_duplicate = true
				break

		if (
			not gemstone_duplicate
			and not gemstone_shop.is_empty()
		):
			out.append(
				gemstone_shop.duplicate(true)
			)




	var reserve_shop: Dictionary = (
		_luxury_orrery_reserve_shop_contract(
			resolved_era
		)
	)









	if not reserve_shop.is_empty():
		var foundation_inventory: Array = (
			_luxury_temporal_foundation_inventory(
				resolved_era
			)
		)

		if not foundation_inventory.is_empty():
			var reserve_inventory: Array = (
				_safe_array(
					reserve_shop.get(
						"inventory",
						[]
					)
				).duplicate(true)
			)
			var reserve_item_ids: Dictionary = {}
			var foundation_added_count: int = 0

			for raw_item in reserve_inventory:
				if typeof(raw_item) != TYPE_DICTIONARY:
					continue

				var existing_item_id: String = str(
					(raw_item as Dictionary).get(
						"id",
						""
					)
				).strip_edges()

				if existing_item_id != "":
					reserve_item_ids [
						existing_item_id
					] = true

			for raw_item in foundation_inventory:
				if typeof(raw_item) != TYPE_DICTIONARY:
					continue

				var foundation_item: Dictionary = (
					raw_item as Dictionary
				)
				var foundation_item_id: String = str(
					foundation_item.get(
						"id",
						""
					)
				).strip_edges()

				if (
					foundation_item_id == ""
					or reserve_item_ids.has(
						foundation_item_id
					)
				):
					continue

				reserve_item_ids [
					foundation_item_id
				] = true
				reserve_inventory.append(
					foundation_item.duplicate(true)
				)
				foundation_added_count += 1

			reserve_shop [
				"inventory"
			] = reserve_inventory
			reserve_shop [
				"temporal_foundation_inventory_count"
			] = foundation_added_count
			reserve_shop [
				"temporal_foundation_inventory_authored_upstream"
			] = true
			reserve_shop [
				"temporal_foundation_inventory_renderer_padding"
			] = false

	if not reserve_shop.is_empty():
		var reserve_shop_id: String = str(
			reserve_shop.get(
				"id",
				""
			)
		).strip_edges()
		var reserve_duplicate: bool = false

		for raw_existing in out:
			if typeof(raw_existing) != TYPE_DICTIONARY:
				continue

			if str(
				(raw_existing as Dictionary).get(
					"id",
					""
				)
			) == reserve_shop_id:
				reserve_duplicate = true
				break

		if not reserve_duplicate:
			out.append(
				reserve_shop.duplicate(true)
			)

	return out
func get_shop(
	shop_id: String
) -> Dictionary:
	var clean_shop_id: String = str(
		shop_id
	).strip_edges()

	if clean_shop_id == "":
		return {}

	for era_name in _all_luxury_era_names():
		for raw_row in get_shops_for_era(
			str(era_name)
		):
			if typeof(raw_row) != TYPE_DICTIONARY:
				continue

			var row: Dictionary = (
				raw_row as Dictionary
			)

			if str(
				row.get(
					"id",
					""
				)
			) == clean_shop_id:
				var resolved: Dictionary = (
					row.duplicate(true)
				)
				resolved [
					"catalog_era"
				] = str(era_name)
				return resolved

	return {}


func export_state() -> Dictionary:
	return {
		"schema": "eralife.luxury_shop_engine_state",
		"version": LUXURY_VERSION,
		"luxury_contract": luxury_contract.duplicate(true),
		"luxury_ledger": luxury_ledger.duplicate(true),
		"last_report": last_report.duplicate(true),
		"luxury_observation_memory": (
			_normalize_luxury_observation_memory(
				luxury_observation_memory
			)
		)
	}
func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": (
				"LuxuryShopEngine import data must be a Dictionary."
			)
		}

	luxury_contract = (
		data.get(
			"luxury_contract",
			_default_luxury_contract()
		).duplicate(true)
		if typeof(
			data.get(
				"luxury_contract",
				{}
			)
		) == TYPE_DICTIONARY
		else _default_luxury_contract()
	)
	luxury_ledger = (
		data.get(
			"luxury_ledger",
			[]
		).duplicate(true)
		if typeof(
			data.get(
				"luxury_ledger",
				[]
			)
		) == TYPE_ARRAY
		else []
	)
	last_report = (
		data.get(
			"last_report",
			{}
		).duplicate(true)
		if typeof(
			data.get(
				"last_report",
				{}
			)
		) == TYPE_DICTIONARY
		else {}
	)
	luxury_observation_memory = (
		_normalize_luxury_observation_memory(
			data.get(
				"luxury_observation_memory",
				{}
			)
		)
	)

	return {
		"success": true,
	}

func _find_shop_item(shop: Dictionary, item_id: String) -> Dictionary:
	var inventory: Array = shop.get("inventory", []) if typeof(shop.get("inventory", [])) == TYPE_ARRAY else []
	for raw_item in inventory:
		if typeof(raw_item) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = raw_item
		if str(item.get("id", "")) == str(item_id):
			return item.duplicate(true)
	return {}

func _pay(
	actor: Person,
	amount: float,
	context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "No actor supplied."
		}

	var clean_amount: float = maxf(
		0.0,
		amount
	)

	if clean_amount <= 0.0:
		return {
			"success": false,
			"reason": "Luxury consideration must be positive."
		}

	if (
		gs != null
		and gs.bank_engine != null
		and gs.bank_engine.has_method(
			"request_actor_bank_action"
		)
		and gs.bank_engine.has_method(
			"get_owner_summary_for_actor"
		)
		and gs.bank_engine.has_method(
			"owner_key_from_actor"
		)
	):
		var summary: Dictionary = (
			gs.bank_engine.get_owner_summary_for_actor(
				actor,
				context
			)
		)
		var secured_balance: float = maxf(
			0.0,
			float(
				summary.get(
					"bank_balance",
					actor.bank_balance
				)
			)
		)
		var cash_on_hand: float = maxf(
			0.0,
			float(
				summary.get(
					"cash_on_hand",
					0.0
				)
			)
		)
		var total_accessible: float = (
			secured_balance
			+ cash_on_hand
		)

		if total_accessible < clean_amount:
			return {
				"success": false,
				"reason": "Not enough money.",
				"required": clean_amount,
				"available": total_accessible
			}

		var deposit_report: Dictionary = {}

		if secured_balance < clean_amount:
			var required_deposit: float = minf(
				cash_on_hand,
				clean_amount - secured_balance
			)

			if required_deposit > 0.0:
				deposit_report = (
					gs.bank_engine.request_actor_bank_action(
						actor,
						{
							"action": "deposit",
							"amount": required_deposit,
							"currency": "USD",
							"reason": (
								"luxury_purchase_settlement_preparation"
							)
						},
						context
					)
				)

				if not bool(
					deposit_report.get(
						"success",
						false
					)
				):
					return {
						"success": false,
						"reason": (
							"Luxury consideration could not "
							+ "be secured for settlement."
						),
						"deposit_report": (
							deposit_report.duplicate(true)
						)
					}

		var transfer_report: Dictionary = (
			gs.bank_engine.request_actor_bank_action(
				actor,
				{
					"action": "transfer",
					"amount": clean_amount,
					"currency": "USD",
					"target_owner_id": (
						"institution:luxury_sanctorum"
					),
					"reason": "luxury_purchase",
					"transfer_scope": "local"
				},
				context
			)
		)

		if not bool(
			transfer_report.get(
				"success",
				false
			)
		):
			return transfer_report

		return {
			"success": true,
			"mode": "luxury_sanctorum_bank_transfer",
			"amount": clean_amount,
			"payer_owner_id": (
				gs.bank_engine.owner_key_from_actor(
					actor
				)
			),
			"payee_owner_id": (
				"institution:luxury_sanctorum"
			),
			"deposit_report": (
				deposit_report.duplicate(true)
			),
			"transfer_report": (
				transfer_report.duplicate(true)
			),
		}

	if actor.bank_balance < clean_amount:
		return {
			"success": false,
			"reason": "Not enough money."
		}

	actor.bank_balance -= clean_amount

	return {
		"success": true,
		"mode": "legacy_bank_balance",
		"amount": clean_amount
	}
func _era_name_from_context(context: Dictionary = {}) -> String:
	var clean: String = str(context.get("era_name", "")).strip_edges()
	if clean != "":
		return clean
	if gs != null and gs.era != null:
		return str(gs.era.name)
	return "Modern Era"

func _default_luxury_contract() -> Dictionary:
	return {
		"schema": "eralife.luxury_shop_contract",
		"version": LUXURY_VERSION,
		"eras": {
			"Modern Era": [
				{
					"id": "crown_and_carbon",
					"name": "Crown & Carbon",
					"description": "A bright street-level luxury shop for jewelry, rings, and public-flex prestige items.",
					"fame_required": 0,
					"inventory": [
						{
							"id": "silver_pearl_chain",
							"name": "Silver Pearl Chain",
							"type": "Jewelry",
							"category": "Jewelry",
							"material": "pearl",
							"price": 450,
							"value": 450,
							"lore": "A clean pearl chain with old-money softness. People notice it because it does not beg to be noticed."
						},
						{
							"id": "rose_diamond_ring",
							"name": "Rose Diamond Ring",
							"type": "Ring",
							"category": "Jewelry",
							"material": "diamond",
							"price": 2500,
							"value": 2500,
							"lore": "A proposal-worthy rose diamond ring. It catches warm light and makes ordinary rooms feel expensive."
						},
						{
							"id": "sunset_gold_bracelet",
							"name": "Sunset Gold Bracelet",
							"type": "Bracelet",
							"category": "Jewelry",
							"material": "gold",
							"price": 1200,
							"value": 1200,
							"lore": "A gold bracelet hammered until it looks like the last orange line before night."
						}
					]
				},
				{
					"id": "astral_vault",
					"name": "Astral Vault",
					"description": "A fame-gated vault where jewels start acting like history instead of accessories.",
					"fame_required": 45,
					"inventory": [
						{
							"id": "black_sun_diamond",
							"name": "Black Sun Diamond",
							"type": "Gemstone",
							"category": "Gemstone",
							"material": "black diamond",
							"price": 180000,
							"value": 180000,
							"lore": "A black diamond that drinks light at the edges. Rumor says its first owner never lost an argument again."
						},
						{
							"id": "imperial_teardrop_pearl",
							"name": "Imperial Teardrop Pearl",
							"type": "Pearl",
							"category": "Gemstone",
							"material": "pearl",
							"price": 90000,
							"value": 90000,
							"lore": "A pearl shaped like grief that survived royalty, exile, and three locked jewelry boxes."
						},
						{
							"id": "mirror_court_brooch",
							"name": "Mirror Court Brooch",
							"type": "Brooch",
							"category": "Heirloom",
							"material": "silver and glass",
							"price": 60000,
							"value": 85000,
							"lore": "A brooch from a court that vanished from every map. Its glass still reflects rooms that are not there."
						}
					]
				},
				{
					"id": "relic_house_nocturne",
					"name": "Relic House Nocturne",
					"description": "A quiet artifact shop that separates relics from jewelry because some items have opinions.",
					"fame_required": 20,
					"inventory": [
						{
							"id": "saint_clock_locket",
							"name": "Saint Clock Locket",
							"type": "Locket",
							"category": "Artifact",
							"material": "clockwork gold",
							"price": 35000,
							"value": 70000,
							"lore": "A tiny clock ticks inside the locket even when time is paused. Nobody can agree who wound it."
						},
						{
							"id": "blue_candle_relic",
							"name": "Blue Candle Relic",
							"type": "Relic",
							"category": "Artifact",
							"material": "enchanted wax",
							"price": 18000,
							"value": 42000,
							"lore": "A blue candle that burns cold. Families pass it down when they want protection but fear the price."
						},
						{
							"id": "little_king_coin",
							"name": "Little King Coin",
							"type": "Coin",
							"category": "Artifact",
							"material": "ancient gold",
							"price": 25000,
							"value": 50000,
							"lore": "A small coin stamped with a king nobody remembers. It feels heavier when someone lies nearby."
						}
					]
				}
			],
			"Future Era": [
				{
					"id": "nova_jewel_archive",
					"name": "Nova Jewel Archive",
					"description": "A future archive for quantum gemstones, star-metal heirlooms, and reality-reactive artifacts.",
					"fame_required": 60,
					"inventory": [
						{
							"id": "quantum_blue_diamond",
							"name": "Quantum Blue Diamond",
							"type": "Gemstone",
							"category": "Gemstone",
							"material": "quantum diamond",
							"price": 800000,
							"value": 800000,
							"lore": "A blue diamond that seems to exist in several decisions at once. Jewelers refuse to cut it twice."
						},
						{
							"id": "gravity_thread_crown",
							"name": "Gravity Thread Crown",
							"type": "Crown",
							"category": "Artifact",
							"material": "star-thread alloy",
							"price": 2200000,
							"value": 3000000,
							"lore": "A crown woven from star-thread alloy. When held, it pulls loose objects toward the person with the strongest ambition."
						}
					]
				}
			]
		}
	}