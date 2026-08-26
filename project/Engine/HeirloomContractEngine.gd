

extends RefCounted
class_name HeirloomContractEngine

const ENGINE_SCHEMA:= "eralife.heirloom_contract_engine"
const ENGINE_VERSION:= 1
const CONTRACT_SCHEMA:= "eralife.heirloom_constitutional_contract"
const CONTRACT_VERSION:= 1
const RARE_INFINITY_STONE_DENOMINATOR:= 50000

var gs
var definition_registry: Dictionary = {}
var registered_contracts: Dictionary = {}
var last_report: Dictionary = {}


func _init(
	_game_state = null
) -> void:
	gs = _game_state


func bind_game_state(
	_game_state
) -> void:
	gs = _game_state


func bootstrap_default_contracts() -> Dictionary:
	definition_registry.clear()
	registered_contracts.clear()
	_register_default_definitions()
	registered_contracts ["eralife.default.heirloom_law"] = _default_contract()

	last_report = {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"definition_count": definition_registry.size(),
		"contract_count": registered_contracts.size(),
		"runtime_authority": "heirloom_runtime_engine",
		"catalog_authority": "heirloom_catalog_contract_engine",
		"ui_is_renderer_only": true
	}
	return last_report.duplicate(true)


func register_heirloom_definition(
	definition: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	var normalized: Dictionary = _normalize_definition(definition, context)
	var definition_id: String = str(normalized.get("id", ""))
	if definition_id == "":
		return _fail("missing_definition_id")

	definition_registry [definition_id] = normalized
	return {
		"success": true,
		"mode": "heirloom_definition_registered",
		"definition_id": definition_id,
		"definition": normalized.duplicate(true)
	}


func get_catalog_definitions(
	context: Dictionary = {}
) -> Array:
	var requested_era: String = str(
		context.get("era", _current_era_name())
	).strip_edges().to_lower()
	var include_all_eras: bool = bool(context.get("include_all_eras", false))
	var out: Array = []

	for definition_id in definition_registry.keys():
		var definition: Dictionary = _safe_dictionary(
			definition_registry.get(definition_id, {})
		)
		var eras: Array = _string_array(definition.get("eras", []))
		if not include_all_eras and not eras.is_empty() and requested_era not in eras:
			continue
		out.append(definition)

	return out


func resolve_intent(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _fail("missing_actor")
	if _runtime() == null:
		return _fail("heirloom_runtime_engine_unavailable")

	var action_id: String = str(
		payload.get("action_id", payload.get("intent_id", "refresh"))
	).strip_edges().to_lower()

	match action_id:
		"purchase_random", "buy_heirloom", "purchase":
			var definition: Dictionary = generate_purchase_definition(
				actor,
				payload
			)
			var purchase_report: Dictionary = evaluate_purchase(
				actor,
				definition,
				payload
			)
			if not bool(purchase_report.get("success", false)):
				return purchase_report
			return _runtime().commit_purchase(actor, definition, payload)

		"purchase_definition":
			var definition_id: String = str(payload.get("definition_id", ""))
			var definition: Dictionary = _safe_dictionary(
				definition_registry.get(definition_id, {})
			)
			var purchase_report: Dictionary = evaluate_purchase(
				actor,
				definition,
				payload
			)
			if not bool(purchase_report.get("success", false)):
				return purchase_report
			return _runtime().commit_purchase(actor, definition, payload)

		"designate_heirloom":
			var designation_report: Dictionary = evaluate_designation(
				actor,
				payload
			)
			if not bool(designation_report.get("success", false)):
				return designation_report
			return _runtime().commit_designation(actor, payload, payload)

		"transfer_heirloom", "gift_heirloom", "inherit_heirloom":
			var target: Person = _person_by_id(int(payload.get("target_id", -1)))
			var transfer_report: Dictionary = evaluate_transfer(
				actor,
				target,
				payload
			)
			if not bool(transfer_report.get("success", false)):
				return transfer_report
			return _runtime().commit_transfer(
				actor,
				target,
				str(payload.get("object_id", payload.get("instance_object_id", ""))),
				str(payload.get("transfer_mode", "gift")),
				payload
			)

		"transfer_estate":
			var heir: Person = _person_by_id(int(payload.get("target_id", -1)))
			if heir == null:
				return _fail("estate_heir_unavailable")
			return _runtime().commit_estate_transfer(actor, heir, payload)

		"contest_heirloom":
			var dispute_report: Dictionary = evaluate_dispute(actor, payload)
			if not bool(dispute_report.get("success", false)):
				return dispute_report
			return _runtime().commit_dispute(
				actor,
				str(payload.get("object_id", "")),
				payload
			)

		"resolve_dispute":
			return _runtime().resolve_dispute(
				str(payload.get("dispute_id", "")),
				_safe_dictionary(payload.get("resolution", payload))
			)

		"yearly_tick":
			return yearly_tick(actor, payload)

		"inspect", "refresh", "open":
			return {
				"success": true,
				"mode": "heirloom_intent_observed",
				"record": _runtime().record_for_object(
					str(payload.get("object_id", ""))
				),
				"permissions": permissions_for_actor(actor, payload),
				"ui_is_renderer_only": true
			}

		_:
			return _fail(
				"unsupported_heirloom_intent",
				{
					"action_id": action_id
				}
			)


func generate_purchase_definition(
	_actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	var allow_mythic_roll: bool = bool(context.get("allow_mythic_roll", true))
	if allow_mythic_roll and randi() % RARE_INFINITY_STONE_DENOMINATOR == 0:
		var stone_names: Array = ["Power", "Mind", "Reality", "Space", "Time", "Soul"]
		var pick: String = str(stone_names [randi() % stone_names.size()])
		return _normalize_definition({
			"id": "%s_infinity_stone_heirloom" % pick.to_lower(),
			"name": "%s Infinity Stone" % pick,
			"price": 1000000000,
			"rarity": "Legendary",
			"eras": [],
			"object_domains": ["heirloom", "artifact"],
			"artifact": true,
			"artifact_kind": "stone",
			"stone_key": pick,
			"mythic": true
		}, context)

	var era_key: String = str(context.get("era", _current_era_name())).strip_edges().to_lower()
	var candidates: Array = get_catalog_definitions({
		"era": era_key,
		"include_all_eras": false
	})
	if candidates.is_empty():
		return _normalize_definition({
			"id": "old_keepsake",
			"name": "Old Keepsake",
			"price": 500,
			"rarity": "Common",
			"eras": []
		}, context)

	return _safe_dictionary(candidates [randi() % candidates.size()])


func evaluate_purchase(
	actor: Person,
	definition: Dictionary,
	_context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _fail("missing_actor")
	if definition.is_empty():
		return _fail("heirloom_definition_unavailable")

	var price: int = maxi(0, int(definition.get("price", definition.get("cost", 0))))
	if float(actor.bank_balance) < float(price):
		return {
			"success": false,
			"reason": "insufficient_funds",
			"text": "Not enough money.",
			"popup_title": "Heirloom Purchase",
			"popup_text": "Not enough money.",
			"popup_footer": "Tap anywhere to continue."
		}

	return {
		"success": true,
		"mode": "heirloom_purchase_validated",
		"definition": definition.duplicate(true),
		"price": price
	}


func evaluate_designation(
	actor: Person,
	payload: Dictionary
) -> Dictionary:
	if actor == null:
		return _fail("missing_actor")
	var object_id: String = str(
		payload.get("object_id", payload.get("instance_object_id", payload.get("item_id", "")))
	).strip_edges()
	if object_id == "":
		return _fail("missing_object_id")
	return {
		"success": true,
		"mode": "heirloom_designation_validated",
		"object_id": object_id
	}


func evaluate_transfer(
	actor: Person,
	target: Person,
	payload: Dictionary
) -> Dictionary:
	if actor == null or target == null:
		return _fail("invalid_transfer_participants")
	if int(actor.id) == int(target.id):
		return _fail("cannot_transfer_heirloom_to_self")
	var object_id: String = str(
		payload.get("object_id", payload.get("instance_object_id", ""))
	).strip_edges()
	if object_id == "":
		return _fail("missing_object_id")
	var record: Dictionary = _runtime().record_for_object(object_id)
	if record.is_empty():
		return _fail("heirloom_not_found")
	if int(record.get("owner_id", -1)) != int(actor.id):
		return _fail("actor_does_not_own_heirloom")
	if not bool(record.get("transferable", true)):
		return _fail("heirloom_is_not_transferable")
	return {
		"success": true,
		"mode": "heirloom_transfer_validated",
		"record": record
	}


func evaluate_dispute(
	actor: Person,
	payload: Dictionary
) -> Dictionary:
	if actor == null:
		return _fail("missing_actor")
	var object_id: String = str(payload.get("object_id", "")).strip_edges()
	if object_id == "":
		return _fail("missing_object_id")
	var record: Dictionary = _runtime().record_for_object(object_id)
	if record.is_empty():
		return _fail("heirloom_not_found")
	if not bool(record.get("dispute_eligible", true)):
		return _fail("heirloom_dispute_not_allowed")
	return {
		"success": true,
		"mode": "heirloom_dispute_validated",
		"record": record
	}


func yearly_tick(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	return _runtime().yearly_tick(actor, payload)


func permissions_for_actor(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	var record: Dictionary = _runtime().record_for_object(
		str(payload.get("object_id", ""))
	)
	var owner_id: int = int(record.get("owner_id", -1))
	var actor_id: int = int(actor.id) if actor != null else -1
	return {
		"can_purchase": actor != null,
		"can_designate": actor != null,
		"can_transfer": actor_id > 0 and owner_id == actor_id and bool(record.get("transferable", true)),
		"can_inherit": actor != null,
		"can_contest": actor != null and not record.is_empty() and bool(record.get("dispute_eligible", true)),
		"can_resolve_dispute": actor_id > 0 and owner_id == actor_id,
	}


func export_state() -> Dictionary:
	return {
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"definitions": definition_registry.duplicate(true),
		"contracts": registered_contracts.duplicate(true)
	}


func import_state(
	data: Dictionary
) -> Dictionary:
	definition_registry = _safe_dictionary(data.get("definitions", {}))
	registered_contracts = _safe_dictionary(data.get("contracts", {}))
	if definition_registry.is_empty():
		_register_default_definitions()
	if registered_contracts.is_empty():
		registered_contracts ["eralife.default.heirloom_law"] = _default_contract()
	return {
		"success": true,
		"mode": "heirloom_contract_state_imported",
		"definition_count": definition_registry.size(),
		"contract_count": registered_contracts.size()
	}


func _register_default_definitions() -> void:
	var rows: Array = [
		{
			"id": "bronze_ritual_idol",
			"name": "Bronze Ritual Idol",
			"price": 4000,
			"rarity": "Rare",
			"eras": ["Ancient Era"]
		},
		{
			"id": "knights_inscribed_signet",
			"name": "Knight's Inscribed Signet",
			"price": 6000,
			"rarity": "Rare",
			"eras": ["Medieval Era"]
		},
		{
			"id": "steam_powered_pocket_clock",
			"name": "Steam-Powered Pocket Clock",
			"price": 12000,
			"rarity": "Uncommon",
			"eras": ["Industrial Era"]
		},
		{
			"id": "diamond_necklace",
			"name": "Diamond Necklace",
			"price": 50000,
			"rarity": "Rare",
			"eras": ["Modern Era"]
		},
		{
			"id": "quantum_crystal_token",
			"name": "Quantum Crystal Token",
			"price": 250000,
			"rarity": "Epic",
			"eras": ["Future Era"]
		}
	]
	for row in rows:
		register_heirloom_definition(row)


func _normalize_definition(
	definition: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	var out: Dictionary = definition.duplicate(true)
	var name: String = str(out.get("display_name", out.get("name", "Heirloom"))).strip_edges()
	var definition_id: String = str(out.get("id", _slug(name))).strip_edges().to_lower()
	out ["id"] = definition_id
	out ["catalog_object_id"] = str(
		out.get("catalog_object_id", "heirloom:%s" % definition_id)
	).strip_edges().to_lower()
	out ["name"] = name
	out ["display_name"] = name
	out ["price"] = maxi(0, int(out.get("price", out.get("cost", 0))))
	out ["value"] = int(out.get("value", out ["price"]))
	out ["base_value"] = int(out.get("base_value", out ["price"]))
	out ["rarity"] = str(out.get("rarity", "Common"))
	out ["eras"] = _string_array(out.get("eras", []))
	out ["object_domains"] = _merge_unique_strings(
		_safe_array(out.get("object_domains", [])),
		["heirloom"]
	)
	out ["asset_kind"] = str(out.get("asset_kind", "heirloom"))
	out ["transferable"] = bool(out.get("transferable", true))
	out ["inheritable"] = true
	out ["provider_id"] = str(context.get("provider_id", out.get("provider_id", "eralife.heirlooms.core")))
	out ["source_kind"] = str(context.get("source_kind", out.get("source_kind", "first_party")))
	return out


func _default_contract() -> Dictionary:
	return {
		"schema": CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": "eralife.default.heirloom_law",
		"physical_ownership_authority": "belongings_engine",
		"lineage_state_authority": "heirloom_runtime_engine",
		"catalog_authority": "heirloom_catalog_contract_engine",
		"hub_authority": "heirloom_hub_contract_engine",
		"ui_is_renderer_only": true
	}


func _runtime():
	if gs == null:
		return null
	return gs.heirloom_runtime_engine


func _person_by_id(
	person_id: int
) -> Person:
	if gs == null or person_id <= 0:
		return null
	if gs.player != null and int(gs.player.id) == person_id:
		return gs.player
	if gs.has_method("get_npc_by_id"):
		var found: Variant = gs.get_npc_by_id(person_id)
		if found is Person:
			return found as Person
	return null


func _current_era_name() -> String:
	if gs != null and gs.era != null:
		return str(gs.era.name if "name" in gs.era else gs.era).strip_edges()
	return "Modern Era"


func _merge_unique_strings(
	base: Array,
	overlay: Array
) -> Array:
	var out: Array = []
	for raw_value in base + overlay:
		var clean: String = str(raw_value).strip_edges().to_lower()
		if clean != "" and clean not in out:
			out.append(clean)
	return out


func _string_array(
	value: Variant
) -> Array:
	return _merge_unique_strings([], _safe_array(value))


func _slug(
	value: String
) -> String:
	var clean: String = str(value).strip_edges().to_lower()
	for token in [" ", "-", "/", "\\", ":", ".", ",", "'", "\""]:
		clean = clean.replace(token, "_")
	while "__" in clean:
		clean = clean.replace("__", "_")
	return clean.trim_prefix("_").trim_suffix("_")


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)


func _fail(
	reason: String,
	extra: Dictionary = {}
) -> Dictionary:
	EraLog.failure(
		get_script().resource_path.get_file(),
		str(reason)
	)
	var report: Dictionary = {
		"success": false,
		"reason": reason,
		"mode": "heirloom_contract_rejected"
	}
	for key in extra.keys():
		report [key] = extra [key]
	return report