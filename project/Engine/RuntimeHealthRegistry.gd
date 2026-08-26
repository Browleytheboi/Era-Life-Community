extends Resource
class_name RuntimeHealthRegistry

var gs
var contracts: Dictionary = {}
var recurring_signatures: Dictionary = {}
var recent_faults: Array = []
var recent_recoveries: Array = []
var recent_patch_cards: Array = []
var recent_snapshots: Array = []
var active_mitigations: Array = []
var recent_auto_patches: Array = []
const MAX_AUTO_PATCHES:= 20
const MAX_FAULTS:= 60
const MAX_PATCH_CARDS:= 30
const MAX_RECOVERIES:= 30
const MAX_SNAPSHOTS:= 90
const MAX_MITIGATIONS:= 40

func _init(_gs):
	gs = _gs

func register_contract(contract_id: String, contract: Dictionary) -> void:
	if contract_id == "":
		return
	var row: Dictionary = contract.duplicate(true)
	row ["engine_id"] = str(row.get("engine_id", contract_id))
	contracts [contract_id] = row

func get_contract(contract_id: String) -> Dictionary:
	var raw: Variant = contracts.get(contract_id, {})
	return raw if typeof(raw) == TYPE_DICTIONARY else {}

func record_snapshot(snapshot: Dictionary) -> void:
	if typeof(snapshot) != TYPE_DICTIONARY or snapshot.is_empty():
		return
	recent_snapshots.append(snapshot.duplicate(true))
	while recent_snapshots.size() > MAX_SNAPSHOTS:
		recent_snapshots.remove_at(0)

func record_fault(fault: Dictionary) -> void:
	if typeof(fault) != TYPE_DICTIONARY or fault.is_empty():
		return
	recent_faults.append(fault.duplicate(true))
	while recent_faults.size() > MAX_FAULTS:
		recent_faults.remove_at(0)

func remember_signature(signature: String, fault: Dictionary = {}) -> Dictionary:
	if signature == "":
		return {}
	var bucket_raw: Variant = recurring_signatures.get(signature, {})
	var bucket: Dictionary = bucket_raw if typeof(bucket_raw) == TYPE_DICTIONARY else {}
	bucket ["signature"] = signature
	bucket ["count"] = int(bucket.get("count", 0)) + 1
	bucket ["last_seen_ms"] = int(Time.get_ticks_msec())
	if typeof(fault) == TYPE_DICTIONARY and not fault.is_empty():
		bucket ["last_fault"] = fault.duplicate(true)
	recurring_signatures [signature] = bucket
	return bucket.duplicate(true)

func record_recovery(recovery: Dictionary) -> void:
	if typeof(recovery) != TYPE_DICTIONARY or recovery.is_empty():
		return
	recent_recoveries.append(recovery.duplicate(true))
	while recent_recoveries.size() > MAX_RECOVERIES:
		recent_recoveries.remove_at(0)

func record_patch_card(card: Dictionary) -> void:
	if typeof(card) != TYPE_DICTIONARY or card.is_empty():
		return
	recent_patch_cards.append(card.duplicate(true))
	while recent_patch_cards.size() > MAX_PATCH_CARDS:
		recent_patch_cards.remove_at(0)

func record_mitigation(action: Dictionary) -> void:
	if typeof(action) != TYPE_DICTIONARY or action.is_empty():
		return
	active_mitigations.append(action.duplicate(true))
	while active_mitigations.size() > MAX_MITIGATIONS:
		active_mitigations.remove_at(0)

func get_recent_faults(limit: int = 5) -> Array:
	if limit <= 0 or recent_faults.is_empty():
		return []
	return recent_faults.slice(max(0, recent_faults.size() - limit), recent_faults.size()).duplicate(true)

func get_recent_patch_cards(limit: int = 5) -> Array:
	if limit <= 0 or recent_patch_cards.is_empty():
		return []
	return recent_patch_cards.slice(max(0, recent_patch_cards.size() - limit), recent_patch_cards.size()).duplicate(true)

func get_recent_recoveries(limit: int = 5) -> Array:
	if limit <= 0 or recent_recoveries.is_empty():
		return []
	return recent_recoveries.slice(max(0, recent_recoveries.size() - limit), recent_recoveries.size()).duplicate(true)

func get_live_digest() -> Dictionary:
	var latest_fault: Dictionary = {}
	var latest_patch: Dictionary = {}
	var latest_recovery: Dictionary = {}
	var latest_auto_patch: Dictionary = {}
	if not recent_faults.is_empty() and typeof(recent_faults [recent_faults.size() - 1]) == TYPE_DICTIONARY:
		latest_fault = recent_faults [recent_faults.size() - 1].duplicate(true)
	if not recent_patch_cards.is_empty() and typeof(recent_patch_cards [recent_patch_cards.size() - 1]) == TYPE_DICTIONARY:
		latest_patch = recent_patch_cards [recent_patch_cards.size() - 1].duplicate(true)
	if not recent_recoveries.is_empty() and typeof(recent_recoveries [recent_recoveries.size() - 1]) == TYPE_DICTIONARY:
		latest_recovery = recent_recoveries [recent_recoveries.size() - 1].duplicate(true)
	if not recent_auto_patches.is_empty() and typeof(recent_auto_patches [recent_auto_patches.size() - 1]) == TYPE_DICTIONARY:
		latest_auto_patch = recent_auto_patches [recent_auto_patches.size() - 1].duplicate(true)
	return {
		"contract_count": int(contracts.size()),
		"signature_count": int(recurring_signatures.size()),
		"latest_fault": latest_fault,
		"latest_patch_card": latest_patch,
		"latest_recovery": latest_recovery,
		"latest_auto_patch": latest_auto_patch,
		"active_mitigations": active_mitigations.duplicate(true)
	}
func record_auto_patch(patch: Dictionary) -> void:
	if typeof(patch) != TYPE_DICTIONARY or patch.is_empty():
		return
	recent_auto_patches.append(patch.duplicate(true))
	while recent_auto_patches.size() > MAX_AUTO_PATCHES:
		recent_auto_patches.remove_at(0)

func get_recent_auto_patches(limit: int = 3) -> Array:
	if limit <= 0 or recent_auto_patches.is_empty():
		return []
	return recent_auto_patches.slice(max(0, recent_auto_patches.size() - limit), recent_auto_patches.size()).duplicate(true)