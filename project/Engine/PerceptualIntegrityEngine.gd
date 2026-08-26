extends Resource
class_name PerceptualIntegrityEngine

const PERCEPTUAL_INTEGRITY_VERSION:= 1
const PERCEPTUAL_INTEGRITY_SCHEMA:= "eralife.perceptual_integrity_engine_state"
const DEFAULT_STREAM_ID:= "global"

var gs
var integrity_contract: Dictionary = {}
var persistent_stream_memory: Dictionary = {}
var evaluation_ledger: Array = []
var last_evaluation_report: Dictionary = {}
var last_accept_report: Dictionary = {}
var unknown_state_fields: Dictionary = {}


func _init(_gs = null):
	gs = _gs
	integrity_contract = _default_integrity_contract()


func evaluate_candidate(candidate: Dictionary, used_keys: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	var normalized: Dictionary = normalize_candidate(candidate, context)
	var stream_id: String = _stream_id_from_context(context)
	var attempt: int = int(context.get("attempt", 0))
	var phase: String = str(context.get("phase", normalized.get("phase", ""))).strip_edges()
	var contract: Dictionary = _resolve_contract(context)
	var thresholds: Dictionary = contract.get("attempt_thresholds", {}) if typeof(contract.get("attempt_thresholds", {})) == TYPE_DICTIONARY else {}
	var identity: Dictionary = normalized.get("perceptual_identity", {}) if typeof(normalized.get("perceptual_identity", {})) == TYPE_DICTIONARY else {}

	var persistent_memory_enabled: bool = _context_bool(context, "persistent_memory_enabled", true)
	var collect_ledger: bool = _context_bool(context, "collect_ledger", true)
	var record_reports: bool = _context_bool(context, "record_reports", true)
	var stream_memory: Dictionary = _stream_memory(stream_id) if persistent_memory_enabled else {}

	var rejection_reasons: Array = []
	var warnings: Array = []

	var line_key: String = str(identity.get("line_identity_key", "")).strip_edges()
	var opening_key: String = str(identity.get("intro_opening_key", "")).strip_edges()
	var subject_key: String = str(identity.get("subject_identity_key", "")).strip_edges()
	var event_signature: String = str(identity.get("event_signature", "")).strip_edges()
	var year_key: String = str(identity.get("year_identity_key", "")).strip_edges()
	var pool_id: String = str(identity.get("pool_label", "")).strip_edges()
	var exact_phase_key: String = "%s|%s|%s" % [year_key, str(normalized.get("line", "")), phase]

	var last_pool_id: String = str(used_keys.get("_last_pool_id", stream_memory.get("last_pool_id", ""))).strip_edges()
	var last_opening_key: String = str(used_keys.get("_last_opening_key", stream_memory.get("last_opening_key", ""))).strip_edges()
	var last_subject_key: String = str(used_keys.get("_last_subject_key", stream_memory.get("last_subject_key", ""))).strip_edges()
	var last_year_key: String = str(used_keys.get("_last_year_key", stream_memory.get("last_year_key", ""))).strip_edges()

	if pool_id != "" and pool_id == last_pool_id and attempt < int(thresholds.get("same_pool_block_until_attempt", 48)):
		rejection_reasons.append("same_pool_as_previous")

	var pool_use_key: String = "_pool_count:%s" % pool_id
	var pool_use_count: int = int(used_keys.get(pool_use_key, 0))
	if pool_id != "" and pool_use_count >= int(thresholds.get("max_pool_uses_per_run", 2)) and attempt < int(thresholds.get("pool_overuse_block_until_attempt", 60)):
		rejection_reasons.append("pool_overused_in_run")

	if line_key != "":
		if used_keys.has("_line_identity:%s" % line_key):
			rejection_reasons.append("line_identity_already_used")
		if persistent_memory_enabled and _persistent_identity_seen(stream_memory, "line_identity", line_key) and attempt < int(thresholds.get("persistent_line_block_until_attempt", 140)):
			rejection_reasons.append("line_identity_seen_recently")

	if exact_phase_key != "" and used_keys.has(exact_phase_key) and attempt < int(thresholds.get("exact_phase_key_block_until_attempt", 84)):
		rejection_reasons.append("exact_phase_key_already_used")

	if opening_key != "":
		if opening_key == last_opening_key and attempt < int(thresholds.get("same_opening_as_previous_block_until_attempt", 104)):
			rejection_reasons.append("same_opening_as_previous")
		if used_keys.has("_opening_identity:%s" % opening_key) and attempt < int(thresholds.get("opening_repeat_block_until_attempt", 124)):
			rejection_reasons.append("opening_identity_already_used")

	if subject_key != "":
		if subject_key == last_subject_key and attempt < int(thresholds.get("same_subject_as_previous_block_until_attempt", 116)):
			rejection_reasons.append("same_subject_as_previous")
		if used_keys.has("_subject_identity:%s" % subject_key) and attempt < int(thresholds.get("subject_repeat_block_until_attempt", 132)):
			rejection_reasons.append("subject_identity_already_used")

	if year_key != "":
		if year_key == last_year_key and attempt < int(thresholds.get("same_year_as_previous_block_until_attempt", 96)):
			rejection_reasons.append("same_year_as_previous")
		if used_keys.has("_year_identity:%s" % year_key) and attempt < int(thresholds.get("year_repeat_block_until_attempt", 108)):
			rejection_reasons.append("year_identity_already_used")

	if event_signature != "":
		if used_keys.has("_event_signature:%s" % event_signature) and attempt < int(thresholds.get("event_signature_block_until_attempt", 112)):
			rejection_reasons.append("event_signature_already_used")
		if persistent_memory_enabled and _persistent_identity_seen(stream_memory, "event_signature", event_signature) and attempt < int(thresholds.get("persistent_event_signature_block_until_attempt", 128)):
			rejection_reasons.append("event_signature_seen_recently")

	var accepted: bool = rejection_reasons.is_empty()
	var report: Dictionary = {
		"schema": "eralife.perceptual_integrity_evaluation_report",
		"version": PERCEPTUAL_INTEGRITY_VERSION,
		"success": true,
		"accepted": accepted,
		"candidate": normalized,
		"stream_id": stream_id,
		"phase": phase,
		"attempt": attempt,
		"rejection_reasons": rejection_reasons,
		"warnings": warnings,
		"identity": identity,
		"created_at_ms": int(Time.get_ticks_msec())
	}

	if record_reports:
		last_evaluation_report = report.duplicate(true)

	if collect_ledger:
		_append_evaluation_ledger(report)

	return report


func accept_candidate(candidate: Dictionary, used_keys: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	var normalized: Dictionary = normalize_candidate(candidate, context)
	var stream_id: String = _stream_id_from_context(context)
	var phase: String = str(context.get("phase", normalized.get("phase", ""))).strip_edges()
	var identity: Dictionary = normalized.get("perceptual_identity", {}) if typeof(normalized.get("perceptual_identity", {})) == TYPE_DICTIONARY else {}
	var persistent_memory_enabled: bool = _context_bool(context, "persistent_memory_enabled", true)
	var record_reports: bool = _context_bool(context, "record_reports", true)
	var stream_memory: Dictionary = _stream_memory(stream_id) if persistent_memory_enabled else {}

	var line_text: String = str(normalized.get("line", "")).strip_edges()
	var line_key: String = str(identity.get("line_identity_key", "")).strip_edges()
	var opening_key: String = str(identity.get("intro_opening_key", "")).strip_edges()
	var subject_key: String = str(identity.get("subject_identity_key", "")).strip_edges()
	var event_signature: String = str(identity.get("event_signature", "")).strip_edges()
	var year_key: String = str(identity.get("year_identity_key", "")).strip_edges()
	var pool_id: String = str(identity.get("pool_label", "")).strip_edges()

	if line_key != "":
		used_keys ["_line_identity:%s" % line_key] = true
		used_keys ["_last_line_identity_key"] = line_key
		if persistent_memory_enabled:
			_remember_persistent_identity(stream_id, "line_identity", line_key)

	if opening_key != "":
		used_keys ["_opening_identity:%s" % opening_key] = true
		used_keys ["_last_opening_key"] = opening_key
		if persistent_memory_enabled:
			_remember_persistent_identity(stream_id, "opening_identity", opening_key)

	if subject_key != "":
		used_keys ["_subject_identity:%s" % subject_key] = true
		used_keys ["_last_subject_key"] = subject_key
		if persistent_memory_enabled:
			_remember_persistent_identity(stream_id, "subject_identity", subject_key)

	if event_signature != "":
		used_keys ["_event_signature:%s" % event_signature] = true
		if persistent_memory_enabled:
			_remember_persistent_identity(stream_id, "event_signature", event_signature)

	if year_key != "":
		used_keys ["_year_identity:%s" % year_key] = true
		used_keys ["_last_year_key"] = year_key
		if persistent_memory_enabled:
			_remember_persistent_identity(stream_id, "year_identity", year_key)

	if pool_id != "":
		var pool_use_key: String = "_pool_count:%s" % pool_id
		used_keys [pool_use_key] = int(used_keys.get(pool_use_key, 0)) + 1
		used_keys ["_last_pool_id"] = pool_id
		if persistent_memory_enabled:
			stream_memory ["last_pool_id"] = pool_id

	if persistent_memory_enabled:
		stream_memory ["last_line_identity_key"] = line_key
		stream_memory ["last_opening_key"] = opening_key
		stream_memory ["last_subject_key"] = subject_key
		stream_memory ["last_year_key"] = year_key
		stream_memory ["last_event_signature"] = event_signature
		stream_memory ["accepted_count"] = int(stream_memory.get("accepted_count", 0)) + 1
		stream_memory ["updated_at_ms"] = int(Time.get_ticks_msec())
		persistent_stream_memory [stream_id] = stream_memory

	if line_text != "":
		used_keys ["%s|%s|%s" % [year_key, line_text, phase]] = true

	var report: Dictionary = {
		"schema": "eralife.perceptual_integrity_accept_report",
		"version": PERCEPTUAL_INTEGRITY_VERSION,
		"success": true,
		"candidate": normalized,
		"stream_id": stream_id,
		"phase": phase,
		"identity": identity,
		"created_at_ms": int(Time.get_ticks_msec())
	}

	if record_reports:
		last_accept_report = report.duplicate(true)

	return report

func register_used_moment_identity(moment: Dictionary, used_keys: Dictionary, context: Dictionary = {}) -> Dictionary:
	return accept_candidate(moment, used_keys, context)


func normalize_candidate(candidate: Dictionary, context: Dictionary = {}) -> Dictionary:
	var out: Dictionary = candidate.duplicate(true)
	var line_text: String = str(out.get("line", "")).strip_edges()
	var raw_year_value: int = int(out.get("raw_year", out.get("year", 0)))
	var pool_id: String = str(out.get("pool_label", context.get("pool_label", ""))).strip_edges()
	var phase: String = str(out.get("phase", context.get("phase", ""))).strip_edges()

	var identity: Dictionary = out.get("perceptual_identity", {}) if typeof(out.get("perceptual_identity", {})) == TYPE_DICTIONARY else {}

	var line_key: String = str(out.get("line_identity_key", identity.get("line_identity_key", line_identity_key(line_text)))).strip_edges()
	var opening_key: String = str(out.get("intro_opening_key", identity.get("intro_opening_key", line_opening_key(line_text, 3)))).strip_edges()
	var subject_key: String = str(out.get("subject_identity_key", identity.get("subject_identity_key", subject_identity_key(line_text)))).strip_edges()
	var event_signature: String = str(out.get("event_signature", identity.get("event_signature", event_signature_from_line(line_text)))).strip_edges()
	var year_key: String = str(out.get("year_identity_key", identity.get("year_identity_key", str(raw_year_value)))).strip_edges()

	identity ["line_identity_key"] = line_key
	identity ["intro_opening_key"] = opening_key
	identity ["subject_identity_key"] = subject_key
	identity ["event_signature"] = event_signature
	identity ["year_identity_key"] = year_key
	identity ["pool_label"] = pool_id
	identity ["phase"] = phase

	out ["line_identity_key"] = line_key
	out ["intro_opening_key"] = opening_key
	out ["subject_identity_key"] = subject_key
	out ["event_signature"] = event_signature
	out ["year_identity_key"] = year_key
	out ["pool_label"] = pool_id
	out ["phase"] = phase
	out ["perceptual_identity"] = identity

	return out


func event_signature_from_line(line_text: String) -> String:
	var clean: String = compact_identity_text(line_text)
	if clean.begins_with("a "):
		var first_space: int = clean.find(" ")
		var second_space: int = clean.find(" ", first_space + 1)
		if second_space > 0:
			clean = clean.substr(second_space + 1).strip_edges()
	if clean.begins_with("an "):
		var first_space_an: int = clean.find(" ")
		var second_space_an: int = clean.find(" ", first_space_an + 1)
		if second_space_an > 0:
			clean = clean.substr(second_space_an + 1).strip_edges()
	if clean.begins_with("the "):
		var first_space_the: int = clean.find(" ")
		var second_space_the: int = clean.find(" ", first_space_the + 1)
		if second_space_the > 0:
			clean = clean.substr(second_space_the + 1).strip_edges()
	return clean


func line_identity_key(line_text: String) -> String:
	return compact_identity_text(line_text)


func compact_identity_text(raw_text: String) -> String:
	var clean: String = str(raw_text).strip_edges().to_lower()
	clean = clean.replace(".", "")
	clean = clean.replace(",", "")
	clean = clean.replace(";", "")
	clean = clean.replace(":", "")
	clean = clean.replace("!", "")
	clean = clean.replace("?", "")
	clean = clean.replace("/", " ")
	clean = clean.replace("\\", " ")
	clean = clean.replace("'", "")
	clean = clean.replace("\"", "")
	while clean.find("  ") >= 0:
		clean = clean.replace("  ", " ")
	return clean.strip_edges()


func identity_words(line_text: String) -> Array:
	var clean: String = compact_identity_text(line_text)
	if clean == "":
		return []

	var raw_words: Array = clean.split(" ", false)
	var out: Array = []
	for raw_word in raw_words:
		var word: String = str(raw_word).strip_edges()
		if word == "":
			continue
		out.append(word)

	return out


func line_opening_key(line_text: String, word_count: int = 3) -> String:
	var words: Array = identity_words(line_text)
	if words.is_empty():
		return ""

	var take_count: int = clamp(int(word_count), 1, words.size())
	var out: Array = []
	for i in range(take_count):
		out.append(str(words [i]))

	return " ".join(out)


func subject_identity_key(line_text: String) -> String:
	var words: Array = identity_words(line_text)
	if words.is_empty():
		return ""

	var start_index: int = 0
	if str(words [0]) in ["a", "an", "the"]:
		start_index = 1

	if start_index >= words.size():
		return line_opening_key(line_text, 3)

	var take_count: int = min(2, words.size() - start_index)
	var subject_words: Array = []
	for i in range(take_count):
		subject_words.append(str(words [start_index + i]))

	return " ".join(subject_words).strip_edges()


func moment_year_identity_key(moment: Dictionary) -> String:
	if typeof(moment) != TYPE_DICTIONARY:
		return ""
	if moment.has("raw_year"):
		return str(moment.get("raw_year", "")).strip_edges()
	return str(moment.get("year", "")).strip_edges()


func recent_moment_key_lookup(stream_id: String = DEFAULT_STREAM_ID) -> Dictionary:
	var memory: Dictionary = _stream_memory(stream_id)
	var lookup: Dictionary = {}
	var recent_keys: Array = memory.get("recent_persistent_keys", []) if typeof(memory.get("recent_persistent_keys", [])) == TYPE_ARRAY else []
	for raw_key in recent_keys:
		lookup [str(raw_key)] = true
	return lookup


func remember_recent_moment_key(moment_key: String, stream_id: String = DEFAULT_STREAM_ID) -> void:
	var clean_key: String = str(moment_key).strip_edges()
	if clean_key == "":
		return

	_remember_persistent_identity(stream_id, "persistent_moment", clean_key)


func export_state() -> Dictionary:
	return _make_binary_safe({
		"schema": PERCEPTUAL_INTEGRITY_SCHEMA,
		"version": PERCEPTUAL_INTEGRITY_VERSION,
		"integrity_contract": integrity_contract.duplicate(true),
		"persistent_stream_memory": persistent_stream_memory.duplicate(true),
		"evaluation_ledger": evaluation_ledger.duplicate(true),
		"last_evaluation_report": last_evaluation_report.duplicate(true),
		"last_accept_report": last_accept_report.duplicate(true),
		"unknown_state_fields": unknown_state_fields.duplicate(true)
	})


func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return { "success": false, "reason": "PerceptualIntegrityEngine import_state expected a Dictionary."}

	unknown_state_fields.clear()
	for key in data.keys():
		if not str(key) in [
			"schema",
			"version",
			"integrity_contract",
			"persistent_stream_memory",
			"evaluation_ledger",
			"last_evaluation_report",
			"last_accept_report",
			"unknown_state_fields"
		]:
			unknown_state_fields [str(key)] = data.get(key)

	integrity_contract = data.get("integrity_contract", _default_integrity_contract()).duplicate(true) if typeof(data.get("integrity_contract", {})) == TYPE_DICTIONARY else _default_integrity_contract()
	persistent_stream_memory = data.get("persistent_stream_memory", {}).duplicate(true) if typeof(data.get("persistent_stream_memory", {})) == TYPE_DICTIONARY else {}
	evaluation_ledger = data.get("evaluation_ledger", []).duplicate(true) if typeof(data.get("evaluation_ledger", [])) == TYPE_ARRAY else []
	last_evaluation_report = data.get("last_evaluation_report", {}).duplicate(true) if typeof(data.get("last_evaluation_report", {})) == TYPE_DICTIONARY else {}
	last_accept_report = data.get("last_accept_report", {}).duplicate(true) if typeof(data.get("last_accept_report", {})) == TYPE_DICTIONARY else {}

	return {
		"success": true,
		"stream_count": persistent_stream_memory.size(),
		"evaluation_count": evaluation_ledger.size(),
		"unknown_field_count": unknown_state_fields.size()
	}


func _resolve_contract(context: Dictionary = {}) -> Dictionary:
	var raw_contract: Variant = context.get("integrity_contract", {})
	if typeof(raw_contract) == TYPE_DICTIONARY and not (raw_contract as Dictionary).is_empty():
		return raw_contract as Dictionary
	if typeof(integrity_contract) == TYPE_DICTIONARY and not integrity_contract.is_empty():
		return integrity_contract
	integrity_contract = _default_integrity_contract()
	return integrity_contract
func _context_bool(context: Dictionary, key: String, fallback: bool = false) -> bool:
	if typeof(context) != TYPE_DICTIONARY:
		return fallback
	if context.has(key):
		return bool(context.get(key))
	return fallback

func _default_integrity_contract() -> Dictionary:
	return {
		"schema": "eralife.perceptual_integrity_contract",
		"version": PERCEPTUAL_INTEGRITY_VERSION,
		"engine_id": "perceptual_integrity_engine",
		"mode": "pure_evaluator",
		"identity_layers": [
			"line_identity",
			"opening_identity",
			"subject_identity",
			"year_identity",
			"event_signature",
			"pool_pressure",
			"persistent_recent_memory"
		],
		"attempt_thresholds": {
			"same_pool_block_until_attempt": 48,
			"pool_overuse_block_until_attempt": 60,
			"max_pool_uses_per_run": 2,
			"exact_phase_key_block_until_attempt": 84,
			"same_year_as_previous_block_until_attempt": 96,
			"year_repeat_block_until_attempt": 108,
			"same_opening_as_previous_block_until_attempt": 104,
			"same_subject_as_previous_block_until_attempt": 116,
			"opening_repeat_block_until_attempt": 124,
			"subject_repeat_block_until_attempt": 132,
			"event_signature_block_until_attempt": 112,
			"persistent_line_block_until_attempt": 140,
			"persistent_event_signature_block_until_attempt": 128
		},
		"persistent_memory": {
			"enabled": true,
			"recent_limit": 768,
			"ledger_limit": 96
		},
		"backwards_compatible": true
	}


func _stream_id_from_context(context: Dictionary = {}) -> String:
	var stream_id: String = str(context.get("stream_id", DEFAULT_STREAM_ID)).strip_edges()
	if stream_id == "":
		stream_id = DEFAULT_STREAM_ID
	return stream_id


func _stream_memory(stream_id: String) -> Dictionary:
	var clean_id: String = str(stream_id).strip_edges()
	if clean_id == "":
		clean_id = DEFAULT_STREAM_ID

	if not persistent_stream_memory.has(clean_id) or typeof(persistent_stream_memory.get(clean_id, {})) != TYPE_DICTIONARY:
		persistent_stream_memory [clean_id] = {
			"recent_identity_keys": {},
			"recent_persistent_keys": [],
			"accepted_count": 0,
			"created_at_ms": int(Time.get_ticks_msec())
		}

	return persistent_stream_memory [clean_id]


func _persistent_identity_seen(stream_memory: Dictionary, layer: String, key: String) -> bool:
	var clean_key: String = str(key).strip_edges()
	if clean_key == "":
		return false

	var identities: Dictionary = stream_memory.get("recent_identity_keys", {}) if typeof(stream_memory.get("recent_identity_keys", {})) == TYPE_DICTIONARY else {}
	return bool(identities.get("%s:%s" % [str(layer), clean_key], false))


func _remember_persistent_identity(stream_id: String, layer: String, key: String) -> void:
	var clean_key: String = str(key).strip_edges()
	if clean_key == "":
		return

	var memory: Dictionary = _stream_memory(stream_id)
	var identities: Dictionary = memory.get("recent_identity_keys", {}) if typeof(memory.get("recent_identity_keys", {})) == TYPE_DICTIONARY else {}
	var recent_keys: Array = memory.get("recent_persistent_keys", []) if typeof(memory.get("recent_persistent_keys", [])) == TYPE_ARRAY else []
	var packed_key: String = "%s:%s" % [str(layer), clean_key]

	identities [packed_key] = true
	recent_keys.erase(packed_key)
	recent_keys.append(packed_key)

	var limit: int = int(_default_integrity_contract().get("persistent_memory", {}).get("recent_limit", 768))
	if typeof(integrity_contract) == TYPE_DICTIONARY:
		var memory_contract: Dictionary = integrity_contract.get("persistent_memory", {}) if typeof(integrity_contract.get("persistent_memory", {})) == TYPE_DICTIONARY else {}
		limit = max(128, int(memory_contract.get("recent_limit", limit)))

	while recent_keys.size() > limit:
		var removed_key: String = str(recent_keys [0])
		recent_keys.remove_at(0)
		identities.erase(removed_key)

	memory ["recent_identity_keys"] = identities
	memory ["recent_persistent_keys"] = recent_keys
	memory ["updated_at_ms"] = int(Time.get_ticks_msec())
	persistent_stream_memory [stream_id] = memory


func _append_evaluation_ledger(report: Dictionary) -> void:
	evaluation_ledger.append(report.duplicate(true))

	var limit: int = 96
	if typeof(integrity_contract) == TYPE_DICTIONARY:
		var memory_contract: Dictionary = integrity_contract.get("persistent_memory", {}) if typeof(integrity_contract.get("persistent_memory", {})) == TYPE_DICTIONARY else {}
		limit = max(16, int(memory_contract.get("ledger_limit", 96)))

	while evaluation_ledger.size() > limit:
		evaluation_ledger.remove_at(0)


func _make_binary_safe(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var out: Dictionary = {}
			for raw_key in (value as Dictionary).keys():
				out [raw_key] = _make_binary_safe((value as Dictionary).get(raw_key))
			return out
		TYPE_ARRAY:
			var arr: Array = []
			for raw_item in (value as Array):
				arr.append(_make_binary_safe(raw_item))
			return arr
		TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_BOOL, TYPE_NIL:
			return value
		_:
			return str(value)