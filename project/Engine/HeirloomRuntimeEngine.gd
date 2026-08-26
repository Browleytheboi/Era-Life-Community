

extends RefCounted
class_name HeirloomRuntimeEngine

const ENGINE_SCHEMA:= "eralife.heirloom_runtime_engine"
const ENGINE_VERSION:= 1
const STATE_SCHEMA:= "eralife.heirloom_runtime_state"
const STATE_VERSION:= 1
const STATE_KEY:= "heirloom_runtime_state"
const EVENT_LIMIT:= 512

var gs
var state: Dictionary = {}
var last_report: Dictionary = {}


func _init(
	_game_state = null
) -> void:
	gs = _game_state
	_ensure_state_shape()


func bind_game_state(
	_game_state
) -> void:
	gs = _game_state
	_ensure_state_shape()


func bootstrap_default_contracts() -> Dictionary:
	_ensure_state_shape()
	var repair_report: Dictionary = repair_from_legacy_state()
	_sync_legacy_facade()

	last_report = {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"mode": "heirloom_runtime_bootstrapped",
		"record_count": _records().size(),
		"dispute_count": _disputes().size(),
		"repair_report": repair_report,
		"ui_is_renderer_only": true
	}
	return last_report.duplicate(true)


func commit_purchase(
	actor: Person,
	definition: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _fail("missing_actor")
	if gs == null or gs.belongings_engine == null:
		return _fail("belongings_engine_unavailable")

	var clean_definition: Dictionary = definition.duplicate(true)
	var display_name: String = str(
		clean_definition.get(
			"display_name",
			clean_definition.get("name", "Heirloom")
		)
	).strip_edges()
	var price: int = maxi(
		0,
		int(
			clean_definition.get(
				"price",
				clean_definition.get("cost", 0)
			)
		)
	)

	if float(actor.bank_balance) < float(price):
		return {
			"success": false,
			"reason": "insufficient_funds",
			"text": "Not enough money.",
			"popup_title": "Heirloom Purchase",
			"popup_text": "Not enough money.",
			"popup_footer": "Tap anywhere to continue."
		}

	var item_id: int = _next_item_id()
	var instance_object_id: String = "object_instance:%d" % item_id
	var catalog_object_id: String = str(
		clean_definition.get(
			"catalog_object_id",
			"heirloom:%s" % _slug(display_name)
		)
	).strip_edges().to_lower()
	var year: int = _current_year()
	var actor_id: int = int(actor.id)
	var lineage_id: String = str(
		clean_definition.get(
			"lineage_id",
			"lineage:%d" % actor_id
		)
	).strip_edges().to_lower()
	var object_domains: Array = _string_array(
		clean_definition.get(
			"object_domains",
			["heirloom"]
		)
	)

	if "heirloom" not in object_domains:
		object_domains.append("heirloom")

	var item: Dictionary = clean_definition.duplicate(true)
	item ["id"] = item_id
	item ["object_id"] = instance_object_id
	item ["instance_object_id"] = instance_object_id
	item ["catalog_object_id"] = catalog_object_id
	item ["name"] = display_name
	item ["display_name"] = display_name
	item ["type"] = str(item.get("type", "Heirloom"))
	item ["asset_kind"] = str(item.get("asset_kind", "heirloom"))
	item ["object_domains"] = object_domains
	item ["price"] = price
	item ["value"] = int(item.get("value", price))
	item ["base_value"] = int(item.get("base_value", price))
	item ["owner_id"] = actor_id
	item ["lineage_id"] = lineage_id
	item ["lineage_bound"] = true
	item ["inheritable"] = true
	item ["transferable"] = bool(item.get("transferable", true))
	item ["acquired_year"] = year
	item ["origin_era"] = str(
		context.get("era", _current_era_name())
	)
	item ["origin_contract"] = _merge_dictionary(
		_safe_dictionary(item.get("origin_contract", {})),
		{
			"era": str(context.get("era", _current_era_name())),
			"year": year,
			"country": str(context.get("country", "")),
			"city": str(context.get("city", "")),
			"source": str(context.get("source", "heirloom_purchase"))
		}
	)
	item ["ownership_chain"] = [
		{
			"owner_id": actor_id,
			"acquired_year": year,
			"mode": "purchase",
			"source": str(context.get("source", "heirloom_purchase"))
		}
	]
	item ["object_history"] = [
		{
			"event_type": "heirloom_purchased",
			"year": year,
			"owner_id": actor_id,
			"source": str(context.get("source", "heirloom_purchase"))
		}
	]
	item ["heirloom_runtime_contract"] = {
		"runtime_authority": "heirloom_runtime_engine",
		"constitutional_authority": "heirloom_contract_engine",
		"catalog_authority": "heirloom_catalog_contract_engine",
		"ownership_authority": "belongings_engine"
	}
	item ["affordances"] = _merge_unique_strings(
		_safe_array(item.get("affordances", [])),
		[
			"inspect_provenance",
			"transfer_heirloom",
			"designate_heirloom",
			"contest_heirloom",
			"object_history_anchor"
		]
	)
	item ["cross_reality_persistent"] = true

	actor.bank_balance -= float(price)
	gs.belongings_engine.add_item(
		actor,
		item,
		"Heirlooms",
		false,
		{
			"source": "heirloom_runtime_engine.commit_purchase",
			"catalog_object_id": catalog_object_id,
			"instance_object_id": instance_object_id
		}
	)

	var record: Dictionary = _record_from_item(
		actor,
		item,
		{
			"designation_mode": "purchase"
		}.merged(context, true)
	)
	_store_record(record)
	_record_event(
		"heirloom_purchased",
		record,
		context
	)
	_sync_legacy_facade()

	var text: String = "Purchased heirloom: %s." % display_name
	last_report = {
		"success": true,
		"mode": "heirloom_purchase_committed",
		"text": text,
		"popup_title": "Heirloom Acquired",
		"popup_text": text,
		"popup_footer": "Tap anywhere to continue.",
		"record": record.duplicate(true),
		"item": item.duplicate(true),
		"catalog_object_id": catalog_object_id,
		"instance_object_id": instance_object_id,
		"cost": price
	}
	return last_report.duplicate(true)


func commit_designation(
	actor: Person,
	item_query: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _fail("missing_actor")

	var entry: Dictionary = _find_belonging_entry(
		actor,
		item_query
	)
	if entry.is_empty():
		return _fail("heirloom_candidate_not_found")

	var item: Dictionary = _safe_dictionary(entry.get("item", {}))
	var category: String = str(entry.get("category", "Heirlooms"))
	item ["lineage_bound"] = true
	item ["inheritable"] = true
	item ["lineage_id"] = str(
		context.get(
			"lineage_id",
			item.get("lineage_id", "lineage:%d" % int(actor.id))
		)
	).strip_edges().to_lower()
	item ["object_domains"] = _merge_unique_strings(
		_safe_array(item.get("object_domains", [])),
		["heirloom"]
	)
	item ["affordances"] = _merge_unique_strings(
		_safe_array(item.get("affordances", [])),
		[
			"inspect_provenance",
			"transfer_heirloom",
			"contest_heirloom",
			"object_history_anchor"
		]
	)

	var item_id: int = int(item.get("id", -1))
	if item_id <= 0:
		return _fail("heirloom_candidate_missing_item_id")

	var removed: Dictionary = gs.belongings_engine.remove_item_by_id(
		actor,
		category,
		item_id
	)
	if removed.is_empty():
		return _fail("heirloom_candidate_remove_failed")

	for key in item.keys():
		removed [key] = item [key]

	gs.belongings_engine.add_item(
		actor,
		removed,
		category,
		false,
		{
			"source": "heirloom_runtime_engine.commit_designation"
		}
	)

	var record: Dictionary = _record_from_item(
		actor,
		removed,
		{
			"designation_mode": "designated"
		}.merged(context, true)
	)
	_store_record(record)
	_record_event(
		"object_designated_as_heirloom",
		record,
		context
	)
	_sync_legacy_facade()

	return {
		"success": true,
		"mode": "heirloom_designation_committed",
		"text": "%s is now bound to this lineage." % str(
			removed.get("display_name", removed.get("name", "This object"))
		),
		"record": record.duplicate(true),
		"item": removed.duplicate(true)
	}


func commit_transfer(
	from_actor: Person,
	to_actor: Person,
	object_id: String,
	transfer_mode: String = "gift",
	context: Dictionary = {}
) -> Dictionary:
	if (
		from_actor == null
		or to_actor == null
	):
		return _fail(
			"invalid_transfer_participants"
		)

	if (
		gs == null
		or gs.belongings_engine == null
	):
		return _fail(
			"belongings_engine_unavailable"
		)

	var entry: Dictionary = _find_belonging_entry(
		from_actor,
		{
			"object_id": object_id
		}
	)

	if entry.is_empty():
		return _fail(
			"heirloom_not_found"
		)

	var category: String = str(
		entry.get(
			"category",
			"Heirlooms"
		)
	)
	var item: Dictionary = _safe_dictionary(
		entry.get(
			"item",
			{}
		)
	)
	var item_id: int = int(
		item.get(
			"id",
			-1
		)
	)

	if item_id <= 0:
		return _fail(
			"heirloom_missing_item_id"
		)

	var removed: Dictionary = (
		gs.belongings_engine.remove_item_by_id(
			from_actor,
			category,
			item_id
		)
	)

	if removed.is_empty():
		return _fail(
			"heirloom_transfer_remove_failed"
		)

	var normalized_transfer_mode: String = str(
		transfer_mode
	).strip_edges().to_lower()
	var year: int = _current_year()
	var ownership_chain: Array = _safe_array(
		removed.get(
			"ownership_chain",
			[]
		)
	)

	ownership_chain.append({
		"owner_id": int(
			to_actor.id
		),
		"previous_owner_id": int(
			from_actor.id
		),
		"acquired_year": year,
		"mode": normalized_transfer_mode,
		"source": str(
			context.get(
				"source",
				"heirloom_transfer"
			)
		)
	})

	removed [
		"owner_id"
	] = int(
		to_actor.id
	)
	removed [
		"ownership_chain"
	] = ownership_chain
	removed [
		"inheritance_count"
	] = maxi(
		0,
		ownership_chain.size() - 1
	)
	removed [
		"object_history"
	] = _safe_array(
		removed.get(
			"object_history",
			[]
		)
	)
	removed [
		"object_history"
	].append({
		"event_type": "heirloom_transferred",
		"year": year,
		"from_id": int(
			from_actor.id
		),
		"to_id": int(
			to_actor.id
		),
		"mode": normalized_transfer_mode,
		"source": str(
			context.get(
				"source",
				"heirloom_transfer"
			)
		)
	})

	var belongings_transfer_context: Dictionary = {
		"source": "heirloom_runtime_engine.commit_transfer",
		"transfer_mode": transfer_mode,
		"from_id": int(
			from_actor.id
		),
		"to_id": int(
			to_actor.id
		)
	}







	if normalized_transfer_mode == "inheritance":
		belongings_transfer_context [
			"inheritance_transfer"
		] = true
		belongings_transfer_context [
			"ownership_transfer_not_discovery"
		] = true
		belongings_transfer_context [
			"suppress_object_perception"
		] = true
		belongings_transfer_context [
			"suppress_upce_perception"
		] = true
		belongings_transfer_context [
			"suppress_player_ui_interpretation"
		] = true
		belongings_transfer_context [
			"suppress_life_diary"
		] = true
		belongings_transfer_context [
			"suppress_myth_world_feed"
		] = true
		belongings_transfer_context [
			"suppress_duplicate_discovery_text"
		] = true

	gs.belongings_engine.add_item(
		to_actor,
		removed,
		category,
		false,
		belongings_transfer_context
	)

	var record: Dictionary = _record_from_item(
		to_actor,
		removed,
		context
	)
	_store_record(
		record
	)
	_record_event(
		"heirloom_transferred",
		record,
		{
			"from_id": int(
				from_actor.id
			),
			"to_id": int(
				to_actor.id
			),
			"transfer_mode": transfer_mode
		}.merged(
			context,
			true
		)
	)
	_sync_legacy_facade()

	return {
		"success": true,
		"mode": "heirloom_transfer_committed",
		"text": (
			"%s passed from %s to %s."
			% [
				str(
					removed.get(
						"display_name",
						removed.get(
							"name",
							"The heirloom"
						)
					)
				),
				_person_name(
					from_actor
				),
				_person_name(
					to_actor
				)
			]
		),
		"record": record.duplicate(true),
		"item": removed.duplicate(true),
		"from_id": int(
			from_actor.id
		),
		"to_id": int(
			to_actor.id
		)
	}
func commit_estate_transfer(
	owner: Person,
	heir: Person,
	context: Dictionary = {}
) -> Dictionary:
	if owner == null or heir == null:
		return _fail("invalid_estate_transfer_participants")

	var records: Array = records_for_actor(
		int(owner.id),
		{
			"include_archived": false
		}
	)
	var transfers: Array = []

	for raw_record in records:
		if typeof(raw_record) != TYPE_DICTIONARY:
			continue
		var record: Dictionary = raw_record as Dictionary
		var object_id: String = str(
			record.get(
				"instance_object_id",
				record.get("object_id", "")
			)
		)
		if object_id == "":
			continue

		var report: Dictionary = commit_transfer(
			owner,
			heir,
			object_id,
			"inheritance",
			{
				"source": "heirloom_runtime_engine.commit_estate_transfer"
			}.merged(context, true)
		)
		if bool(report.get("success", false)):
			transfers.append(report)

	return {
		"success": true,
		"mode": "heirloom_estate_transfer_committed",
		"owner_id": int(owner.id),
		"heir_id": int(heir.id),
		"transfer_count": transfers.size(),
		"transfers": transfers
	}


func commit_dispute(
	actor: Person,
	object_id: String,
	payload: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _fail("missing_actor")

	var record: Dictionary = record_for_object(object_id)
	if record.is_empty():
		return _fail("heirloom_not_found")

	var dispute_id: String = "heirloom_dispute:%s:%d" % [
		_slug(str(record.get("instance_object_id", object_id))),
		int(Time.get_ticks_msec())
	]
	var dispute: Dictionary = {
		"schema": "eralife.heirloom_dispute_contract",
		"version": 1,
		"dispute_id": dispute_id,
		"object_id": str(record.get("object_id", object_id)),
		"instance_object_id": str(record.get("instance_object_id", object_id)),
		"catalog_object_id": str(record.get("catalog_object_id", "")),
		"claimant_id": int(actor.id),
		"current_owner_id": int(record.get("owner_id", -1)),
		"claim_basis": str(payload.get("claim_basis", "lineage_claim")),
		"evidence": _safe_array(payload.get("evidence", [])),
		"state": "open",
		"opened_year": _current_year(),
		"opened_at_ms": int(Time.get_ticks_msec()),
		"resolution": {}
	}
	_disputes() [dispute_id] = dispute
	_bump_revision()
	_record_event("heirloom_dispute_opened", record, dispute)

	return {
		"success": true,
		"mode": "heirloom_dispute_opened",
		"dispute": dispute.duplicate(true),
		"text": "A lineage claim was opened for %s." % str(
			record.get("display_name", "the heirloom")
		)
	}


func resolve_dispute(
	dispute_id: String,
	resolution: Dictionary = {}
) -> Dictionary:
	var clean_id: String = str(dispute_id).strip_edges()
	if clean_id == "" or not _disputes().has(clean_id):
		return _fail("heirloom_dispute_not_found")

	var dispute: Dictionary = _safe_dictionary(
		_disputes().get(clean_id, {})
	)
	if str(dispute.get("state", "open")) != "open":
		return _fail("heirloom_dispute_already_resolved")

	dispute ["state"] = str(
		resolution.get("state", "resolved")
	).strip_edges().to_lower()
	dispute ["resolution"] = resolution.duplicate(true)
	dispute ["resolved_year"] = _current_year()
	dispute ["resolved_at_ms"] = int(Time.get_ticks_msec())
	_disputes() [clean_id] = dispute
	_bump_revision()

	return {
		"success": true,
		"mode": "heirloom_dispute_resolved",
		"dispute": dispute.duplicate(true)
	}


func yearly_tick(
	actor: Person = null,
	payload: Dictionary = {}
) -> Dictionary:
	_ensure_state_shape()
	var year: int = int(payload.get("year", _current_year()))
	var actor_id: int = int(actor.id) if actor != null else -1
	var updated: int = 0

	for record_key in _records().keys():
		var record: Dictionary = _safe_dictionary(
			_records().get(record_key, {})
		)
		if record.is_empty():
			continue
		if actor_id > 0 and int(record.get("owner_id", -1)) != actor_id:
			continue

		var last_year: int = int(
			record.get("last_yearly_tick", year - 1)
		)
		if last_year >= year:
			continue

		var ownership_chain: Array = _safe_array(
			record.get("ownership_chain", [])
		)
		var event_count: int = _safe_array(
			record.get("history", [])
		).size()
		var age_years: int = maxi(
			0,
			year - int(record.get("origin_year", year))
		)
		var prestige: float = float(record.get("prestige", 0.0))
		prestige += 0.15
		prestige += minf(1.5, float(ownership_chain.size()) * 0.06)
		prestige += minf(1.0, float(event_count) * 0.025)
		prestige += minf(1.2, float(age_years) * 0.004)
		record ["prestige"] = clampf(prestige, 0.0, 100.0)
		record ["historical_value"] = float(
			record.get("historical_value", 0.0)
		) + minf(2.0, 0.08 + float(event_count) * 0.01)
		record ["last_yearly_tick"] = year
		_records() [record_key] = record
		updated += 1

	if updated > 0:
		_bump_revision()
		_sync_legacy_facade()

	return {
		"success": true,
		"mode": "heirloom_yearly_tick",
		"year": year,
		"actor_id": actor_id,
		"updated_count": updated,
	}


func records_for_actor(
	actor_id: int,
	context: Dictionary = {}
) -> Array:
	_ensure_state_shape()
	var include_archived: bool = bool(
		context.get("include_archived", false)
	)
	var out: Array = []

	for record_key in _records().keys():
		var record: Dictionary = _safe_dictionary(
			_records().get(record_key, {})
		)
		if int(record.get("owner_id", -1)) != actor_id:
			continue
		if not include_archived and bool(record.get("archived", false)):
			continue
		out.append(record)

	out.sort_custom(func (a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("prestige", 0.0)) > float(b.get("prestige", 0.0))
	)
	return out


func record_for_object(
	object_id: String
) -> Dictionary:
	_ensure_state_shape()
	var clean_id: String = str(object_id).strip_edges().to_lower()
	if clean_id == "":
		return {}

	if _records().has(clean_id):
		return _safe_dictionary(_records().get(clean_id, {}))

	for record_key in _records().keys():
		var record: Dictionary = _safe_dictionary(
			_records().get(record_key, {})
		)
		var candidate_ids: Array = [
			str(record.get("object_id", "")).strip_edges().to_lower(),
			str(record.get("instance_object_id", "")).strip_edges().to_lower(),
			str(record.get("catalog_object_id", "")).strip_edges().to_lower()
		]
		if clean_id in candidate_ids:
			return record

	return {}


func disputes_for_actor(
	actor_id: int
) -> Array:
	var out: Array = []
	for dispute_key in _disputes().keys():
		var dispute: Dictionary = _safe_dictionary(
			_disputes().get(dispute_key, {})
		)
		if actor_id in [
			int(dispute.get("claimant_id", -1)),
			int(dispute.get("current_owner_id", -1))
		]:
			out.append(dispute)
	return out


func repair_from_legacy_state() -> Dictionary:
	_ensure_state_shape()
	var repaired: int = 0
	if gs == null or gs.heirloom_engine == null:
		return {
			"success": true,
			"repaired_count": 0,
			"reason": "legacy_facade_unavailable"
		}

	var legacy_registry: Variant = gs.heirloom_engine.get("heirlooms")
	if typeof(legacy_registry) != TYPE_DICTIONARY:
		return {
			"success": true,
			"repaired_count": 0,
			"reason": "legacy_registry_empty"
		}

	for raw_owner_id in (legacy_registry as Dictionary).keys():
		var owner: Person = _person_by_id(int(raw_owner_id))
		if owner == null:
			continue
		for raw_item in _safe_array(
			(legacy_registry as Dictionary).get(raw_owner_id, [])
		):
			if typeof(raw_item) != TYPE_DICTIONARY:
				continue
			var record: Dictionary = _record_from_item(
				owner,
				raw_item as Dictionary,
				{
					"source": "legacy_heirloom_engine_repair"
				}
			)
			var key: String = str(record.get("instance_object_id", ""))
			if key == "":
				key = str(record.get("catalog_object_id", ""))
			if key == "" or _records().has(key):
				continue
			_records() [key] = record
			repaired += 1

	if repaired > 0:
		_bump_revision()

	return {
		"success": true,
		"repaired_count": repaired,
		"record_count": _records().size()
	}


func export_state() -> Dictionary:
	_ensure_state_shape()
	return state.duplicate(true)


func import_state(
	data: Dictionary
) -> Dictionary:
	state = data.duplicate(true)
	_ensure_state_shape()
	_sync_state_back()
	_sync_legacy_facade()
	return {
		"success": true,
		"mode": "heirloom_runtime_state_imported",
		"record_count": _records().size(),
		"dispute_count": _disputes().size()
	}


func _record_from_item(
	owner: Person,
	item: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	var clean_item: Dictionary = item.duplicate(true)
	var item_id: int = int(clean_item.get("id", -1))
	var instance_object_id: String = str(
		clean_item.get(
			"instance_object_id",
			"object_instance:%d" % item_id if item_id > 0 else ""
		)
	).strip_edges().to_lower()
	var display_name: String = str(
		clean_item.get(
			"display_name",
			clean_item.get("name", "Heirloom")
		)
	).strip_edges()
	var catalog_object_id: String = str(
		clean_item.get(
			"catalog_object_id",
			"heirloom:%s" % _slug(display_name)
		)
	).strip_edges().to_lower()
	var origin: Dictionary = _safe_dictionary(
		clean_item.get("origin_contract", {})
	)
	var ownership_chain: Array = _safe_array(
		clean_item.get("ownership_chain", [])
	)

	if ownership_chain.is_empty() and owner != null:
		ownership_chain.append({
			"owner_id": int(owner.id),
			"acquired_year": int(clean_item.get("acquired_year", _current_year())),
			"mode": str(context.get("designation_mode", "legacy"))
		})

	return {
		"schema": "eralife.heirloom_runtime_record",
		"version": 1,
		"record_id": instance_object_id if instance_object_id != "" else catalog_object_id,
		"object_id": instance_object_id if instance_object_id != "" else catalog_object_id,
		"instance_object_id": instance_object_id,
		"catalog_object_id": catalog_object_id,
		"item_id": item_id,
		"display_name": display_name,
		"owner_id": int(owner.id) if owner != null else int(clean_item.get("owner_id", -1)),
		"lineage_id": str(
			clean_item.get(
				"lineage_id",
				"lineage:%d" % int(owner.id) if owner != null else ""
			)
		),
		"object_domains": _merge_unique_strings(
			_safe_array(clean_item.get("object_domains", [])),
			["heirloom"]
		),
		"origin_contract": origin,
		"origin_year": int(
			origin.get(
				"year",
				clean_item.get("acquired_year", _current_year())
			)
		),
		"ownership_chain": ownership_chain,
		"inheritance_count": maxi(0, ownership_chain.size() - 1),
		"prestige": float(clean_item.get("prestige", 0.0)),
		"historical_value": float(clean_item.get("historical_value", 0.0)),
		"cultural_value": float(clean_item.get("cultural_value", 0.0)),
		"relationship_influence": _safe_dictionary(
			clean_item.get("relationship_influence", {})
		),
		"reputation_influence": _safe_dictionary(
			clean_item.get("reputation_influence", {})
		),
		"history": _merge_history(
			_safe_array(clean_item.get("object_history", [])),
			_safe_array(clean_item.get("inheritance_history", []))
		),
		"transferable": bool(clean_item.get("transferable", true)),
		"inheritable": bool(clean_item.get("inheritable", true)),
		"dispute_eligible": bool(clean_item.get("inheritance_dispute_eligible", true)),
		"archived": false,
		"source_item": clean_item,
		"updated_year": _current_year(),
		"updated_at_ms": int(Time.get_ticks_msec())
	}


func _store_record(
	record: Dictionary
) -> void:
	var key: String = str(
		record.get(
			"instance_object_id",
			record.get("catalog_object_id", "")
		)
	).strip_edges().to_lower()
	if key == "":
		return
	_records() [key] = record.duplicate(true)
	_rebuild_owner_index()
	_bump_revision()


func _find_belonging_entry(
	actor: Person,
	query: Dictionary
) -> Dictionary:
	if actor == null or gs == null or gs.belongings_engine == null:
		return {}
	if not gs.belongings_engine.has_method("get_inventory"):
		return {}

	var inventory: Dictionary = _safe_dictionary(
		gs.belongings_engine.get_inventory(actor)
	)
	var requested: String = str(
		query.get(
			"object_id",
			query.get(
				"instance_object_id",
				query.get("catalog_object_id", query.get("item_id", ""))
			)
		)
	).strip_edges().to_lower()

	for raw_category in inventory.keys():
		var category: String = str(raw_category)
		for raw_item in _safe_array(inventory.get(raw_category, [])):
			if typeof(raw_item) != TYPE_DICTIONARY:
				continue
			var item: Dictionary = (raw_item as Dictionary).duplicate(true)
			var ids: Array = [
				str(item.get("id", "")).strip_edges().to_lower(),
				str(item.get("object_id", "")).strip_edges().to_lower(),
				str(item.get("instance_object_id", "")).strip_edges().to_lower(),
				str(item.get("catalog_object_id", "")).strip_edges().to_lower()
			]
			if requested != "" and requested not in ids:
				continue
			return {
				"category": category,
				"item": item
			}
	return {}


func _record_event(
	event_type: String,
	record: Dictionary,
	context: Dictionary = {}
) -> void:
	var row: Dictionary = {
		"event_type": str(event_type).strip_edges().to_lower(),
		"record_id": str(record.get("record_id", "")),
		"object_id": str(record.get("object_id", "")),
		"instance_object_id": str(record.get("instance_object_id", "")),
		"catalog_object_id": str(record.get("catalog_object_id", "")),
		"owner_id": int(record.get("owner_id", -1)),
		"year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec()),
		"context": context.duplicate(true)
	}
	_event_log().append(row)
	if _event_log().size() > EVENT_LIMIT:
		state ["event_log"] = _event_log().slice(
			_event_log().size() - EVENT_LIMIT,
			_event_log().size()
		)


func _rebuild_owner_index() -> void:
	var index: Dictionary = {}
	for record_key in _records().keys():
		var record: Dictionary = _safe_dictionary(
			_records().get(record_key, {})
		)
		var owner_key: String = str(int(record.get("owner_id", -1)))
		if not index.has(owner_key):
			index [owner_key] = []
		index [owner_key].append(str(record_key))
	state ["owner_index"] = index


func _sync_legacy_facade() -> void:
	if gs == null or gs.heirloom_engine == null:
		return
	if gs.heirloom_engine == self:
		return

	var mirror: Dictionary = {}
	for record_key in _records().keys():
		var record: Dictionary = _safe_dictionary(
			_records().get(record_key, {})
		)
		if bool(record.get("archived", false)):
			continue
		var owner_id: int = int(record.get("owner_id", -1))
		if owner_id <= 0:
			continue
		if not mirror.has(owner_id):
			mirror [owner_id] = []
		var source_item: Dictionary = _safe_dictionary(
			record.get("source_item", {})
		)
		if source_item.is_empty():
			source_item = record.duplicate(true)
		mirror [owner_id].append(source_item)

	gs.heirloom_engine.set("heirlooms", mirror)


func _ensure_state_shape() -> Dictionary:
	if state.is_empty() and gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		state = _safe_dictionary(gs.scenario_state.get(STATE_KEY, {}))

	if state.is_empty():
		state = {
			"schema": STATE_SCHEMA,
			"version": STATE_VERSION,
			"records": {},
			"owner_index": {},
			"disputes": {},
			"event_log": [],
			"revision": 0,
			"last_yearly_tick": -1
		}

	if typeof(state.get("records", {})) != TYPE_DICTIONARY:
		state ["records"] = {}
	if typeof(state.get("owner_index", {})) != TYPE_DICTIONARY:
		state ["owner_index"] = {}
	if typeof(state.get("disputes", {})) != TYPE_DICTIONARY:
		state ["disputes"] = {}
	if typeof(state.get("event_log", [])) != TYPE_ARRAY:
		state ["event_log"] = []
	if not state.has("revision"):
		state ["revision"] = 0

	_sync_state_back()
	return state


func _sync_state_back() -> void:
	if gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	gs.scenario_state [STATE_KEY] = state.duplicate(true)


func _records() -> Dictionary:
	_ensure_state_shape()
	return state ["records"] as Dictionary


func _disputes() -> Dictionary:
	_ensure_state_shape()
	return state ["disputes"] as Dictionary


func _event_log() -> Array:
	_ensure_state_shape()
	return state ["event_log"] as Array


func _bump_revision() -> void:
	state ["revision"] = int(state.get("revision", 0)) + 1
	_sync_state_back()


func _next_item_id() -> int:
	if gs == null:
		return int(Time.get_ticks_msec())
	var item_id: int = maxi(1, int(gs.next_id))
	gs.next_id = item_id + 1
	return item_id


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


func _person_name(
	person: Person
) -> String:
	if person == null:
		return "Unknown Person"
	return ("%s %s" % [person.first_name, person.last_name]).strip_edges()


func _current_year() -> int:
	return int(gs.year) if gs != null else 0


func _current_era_name() -> String:
	if gs != null and gs.era != null:
		return str(gs.era.name if "name" in gs.era else gs.era).strip_edges()
	return "Modern Era"


func _merge_history(
	base: Array,
	overlay: Array
) -> Array:
	var out: Array = base.duplicate(true)
	for row in overlay:
		out.append(row)
	return out


func _merge_dictionary(
	base: Dictionary,
	overlay: Dictionary
) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	for key in overlay.keys():
		out [key] = overlay [key]
	return out


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
		"mode": "heirloom_runtime_rejected"
	}
	for key in extra.keys():
		report [key] = extra [key]
	return report