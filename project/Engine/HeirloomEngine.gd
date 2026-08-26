extends Resource
class_name HeirloomEngine




var gs
var heirlooms: Dictionary = {}


func _init(
	_gs
) -> void:
	gs = _gs


func bootstrap_default_contracts() -> Dictionary:
	if gs == null:
		return _fail(
			"missing_game_state"
		)

	var contract_report: Dictionary = {}
	var runtime_report: Dictionary = {}

	if gs.heirloom_contract_engine != null:
		contract_report = (
			gs.heirloom_contract_engine
			.bootstrap_default_contracts()
		)

	if gs.heirloom_runtime_engine != null:
		runtime_report = (
			gs.heirloom_runtime_engine
			.bootstrap_default_contracts()
		)

	_sync_legacy_projection()

	return {
		"success": true,
		"mode": (
			"heirloom_compatibility_facade_bootstrapped"
		),
		"contract_report": (
			contract_report.duplicate(true)
		),
		"runtime_report": (
			runtime_report.duplicate(true)
		),
		"legacy_owner_count": heirlooms.size(),
		"compatibility_facade": true,
		"ui_is_renderer_only": true
	}


func buy_heirloom(
	buyer: Person
) -> Dictionary:
	return resolve_intent(
		buyer,
		{
			"action_id": "purchase_random",
			"source": (
				"heirloom_engine.compatibility_buy"
			)
		}
	)


func resolve_intent(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _fail(
			"missing_actor"
		)

	if (
		gs == null
		or gs.heirloom_contract_engine == null
	):
		return _fail(
			"heirloom_contract_engine_unavailable"
		)

	var report: Dictionary = (
		gs.heirloom_contract_engine.resolve_intent(
			actor,
			payload
		)
	)

	_sync_legacy_projection()

	return report


func transfer_heirloom(
	from_actor: Person,
	to_actor: Person,
	object_id: String,
	transfer_mode: String = "gift",
	context: Dictionary = {}
) -> Dictionary:
	if to_actor == null:
		return _fail(
			"missing_transfer_target"
		)

	var payload: Dictionary = context.duplicate(true)

	payload ["action_id"] = "transfer_heirloom"
	payload ["target_id"] = int(
		to_actor.id
	)
	payload ["object_id"] = object_id
	payload ["transfer_mode"] = transfer_mode
	payload ["source"] = str(
		payload.get(
			"source",
			"heirloom_engine.compatibility_transfer"
		)
	)

	return resolve_intent(
		from_actor,
		payload
	)


func designate_heirloom(
	actor: Person,
	item_query: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	var payload: Dictionary = (
		item_query.duplicate(true)
	)

	for key in context.keys():
		payload [key] = context [key]

	payload ["action_id"] = "designate_heirloom"
	payload ["source"] = str(
		payload.get(
			"source",
			"heirloom_engine.compatibility_designation"
		)
	)

	return resolve_intent(
		actor,
		payload
	)


func contest_heirloom(
	actor: Person,
	object_id: String,
	context: Dictionary = {}
) -> Dictionary:
	var payload: Dictionary = context.duplicate(true)

	payload ["action_id"] = "contest_heirloom"
	payload ["object_id"] = object_id
	payload ["source"] = str(
		payload.get(
			"source",
			"heirloom_engine.compatibility_dispute"
		)
	)

	return resolve_intent(
		actor,
		payload
	)


func yearly_tick(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	var payload: Dictionary = context.duplicate(true)

	payload ["action_id"] = "yearly_tick"
	payload ["year"] = int(
		payload.get(
			"year",
			(
				gs.year
				if gs != null
				else 0
			)
		)
	)
	payload ["source"] = str(
		payload.get(
			"source",
			"heirloom_engine.compatibility_yearly_tick"
		)
	)

	return resolve_intent(
		actor,
		payload
	)


func _generate_heirloom() -> Dictionary:
	if (
		gs != null
		and gs.heirloom_contract_engine != null
		and gs.player != null
	):
		return (
			gs.heirloom_contract_engine
			.generate_purchase_definition(
				gs.player,
				{
					"source": (
						"heirloom_engine"
						+ ".compatibility_generator"
					)
				}
			)
		)

	return _basic(
		"Old Keepsake",
		500,
		"Common"
	)


func _basic(
	item_name: String,
	price: int,
	rarity: String
) -> Dictionary:
	return {
		"name": item_name,
		"display_name": item_name,
		"price": price,
		"value": price,
		"base_value": price,
		"rarity": rarity,
		"type": "Heirloom",
		"asset_kind": "heirloom",
		"object_domains": [
			"heirloom"
		],
		"inheritable": true,
		"lineage_bound": true
	}


func _gen_id() -> int:
	if gs == null:
		return int(
			Time.get_ticks_msec()
		)

	var next_item_id: int = maxi(
		1,
		int(
			gs.next_id
		)
	)

	gs.next_id = next_item_id + 1

	return next_item_id


func export_state() -> Dictionary:
	var runtime_state: Dictionary = {}

	if (
		gs != null
		and gs.heirloom_runtime_engine != null
		and gs.heirloom_runtime_engine.has_method(
			"export_state"
		)
	):
		runtime_state = (
			gs.heirloom_runtime_engine
			.export_state()
		)

	return {
		"schema": (
			"eralife.heirloom_engine_compatibility_state"
		),
		"version": 1,
		"heirlooms": heirlooms.duplicate(true),
		"runtime_state": runtime_state.duplicate(true),
		"compatibility_facade": true
	}


func import_state(
	data: Dictionary
) -> Dictionary:
	heirlooms = _safe_dictionary(
		data.get(
			"heirlooms",
			{}
		)
	)

	if (
		gs != null
		and gs.heirloom_runtime_engine != null
	):
		var runtime_state: Dictionary = _safe_dictionary(
			data.get(
				"runtime_state",
				{}
			)
		)

		if not runtime_state.is_empty():
			gs.heirloom_runtime_engine.import_state(
				runtime_state
			)
		else:
			gs.heirloom_runtime_engine.repair_from_legacy_state()

	_sync_legacy_projection()

	return {
		"success": true,
		"mode": (
			"heirloom_compatibility_state_imported"
		),
		"legacy_owner_count": heirlooms.size()
	}


func _sync_legacy_projection() -> void:
	if (
		gs == null
		or gs.heirloom_runtime_engine == null
	):
		return

	var runtime_state: Dictionary = (
		gs.heirloom_runtime_engine.export_state()
	)
	var records: Dictionary = _safe_dictionary(
		runtime_state.get(
			"records",
			{}
		)
	)
	var mirror: Dictionary = {}

	for record_key in records.keys():
		var record: Dictionary = _safe_dictionary(
			records.get(
				record_key,
				{}
			)
		)

		if bool(
			record.get(
				"archived",
				false
			)
		):
			continue

		var owner_id: int = int(
			record.get(
				"owner_id",
				-1
			)
		)

		if owner_id <= 0:
			continue

		if not mirror.has(
			owner_id
		):
			mirror [owner_id] = []

		var source_item: Dictionary = _safe_dictionary(
			record.get(
				"source_item",
				{}
			)
		)

		if source_item.is_empty():
			source_item = record.duplicate(true)

		mirror [owner_id].append(
			source_item
		)

	heirlooms = mirror


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _fail(
	reason: String
) -> Dictionary:
	EraLog.failure(
		get_script().resource_path.get_file(),
		str(reason)
	)
	return {
		"success": false,
		"reason": reason,
		"mode": (
			"heirloom_compatibility_facade_rejected"
		),
		"compatibility_facade": true
	}