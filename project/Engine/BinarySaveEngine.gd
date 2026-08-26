extends Resource
class_name BinarySaveEngine




const _STREAM_PACKET_MAGIC_V2: int = 1162625586
const _DEFAULT_STREAM_CHUNK_SIZE: int = 131072
const _MAX_SANITIZE_DEPTH: int = 48
const _CONTRACT_BINARY_SAVE_SCHEMA: String = "eralife.contract_driven_binary_save"
const _CONTRACT_BINARY_SAVE_VERSION: int = 1

static func encode(data: Dictionary) -> PackedByteArray:
	var source_data: Dictionary = _maybe_wrap_contract_save(data)
	var session: Dictionary = begin_encode_session(source_data)
	while not bool(session.get("is_complete", false)):
		session = step_encode_session(session, 8)
	var bytes_raw: Variant = session.get("bytes", PackedByteArray())
	return bytes_raw if typeof(bytes_raw) == TYPE_PACKED_BYTE_ARRAY else PackedByteArray()

static func begin_encode_session(data: Dictionary, assume_safe: bool = false, chunk_size: int = _DEFAULT_STREAM_CHUNK_SIZE) -> Dictionary:
	var normalized_chunk_size: int = max(32768, chunk_size)
	return {
		"stage": "stringify" if assume_safe else "sanitize",
		"source_data": data,
		"safe_data": {},
		"json_text": "",
		"raw_bytes": PackedByteArray(),
		"packet": PackedByteArray(),
		"bytes": PackedByteArray(),
		"chunk_size": normalized_chunk_size,
		"chunk_index": 0,
		"chunk_count": 0,
		"raw_size": 0,
		"is_complete": false
	}

static func step_encode_session(session: Dictionary, max_steps: int = 1) -> Dictionary:
	var out: Dictionary = session if typeof(session) == TYPE_DICTIONARY else {}
	if out.is_empty():
		return {
			"stage": "complete",
			"bytes": PackedByteArray(),
			"is_complete": true
		}

	var remaining_steps: int = max(1, max_steps)
	while remaining_steps > 0 and not bool(out.get("is_complete", false)):
		remaining_steps -= 1
		var stage: String = str(out.get("stage", "")).strip_edges()

		match stage:
			"sanitize":
				var source_raw: Variant = out.get("source_data", {})
				var source_data: Dictionary = source_raw if typeof(source_raw) == TYPE_DICTIONARY else {}
				out ["safe_data"] = _deep_sanitize(source_data)
				out ["stage"] = "stringify"

			"stringify":
				var safe_raw: Variant = out.get("safe_data", {})
				var safe_data: Dictionary = safe_raw if typeof(safe_raw) == TYPE_DICTIONARY else {}
				if safe_data.is_empty():
					var source_raw: Variant = out.get("source_data", {})
					safe_data = source_raw if typeof(source_raw) == TYPE_DICTIONARY else {}
				out ["json_text"] = JSON.stringify(safe_data)
				out.erase("safe_data")
				out.erase("source_data")
				out ["stage"] = "utf8"

			"utf8":
				var json_text: String = str(out.get("json_text", ""))
				var raw_bytes: PackedByteArray = json_text.to_utf8_buffer()
				out ["raw_bytes"] = raw_bytes
				out ["raw_size"] = raw_bytes.size()
				out.erase("json_text")
				out ["stage"] = "init_packet"

			"init_packet":
				var raw_size: int = int(out.get("raw_size", 0))
				var chunk_size: int = max(32768, int(out.get("chunk_size", _DEFAULT_STREAM_CHUNK_SIZE)))
				var chunk_count: int = 0
				if raw_size > 0:
					chunk_count = int(ceil(float(raw_size) / float(chunk_size)))

				var packet:= PackedByteArray()
				packet.resize(16)
				packet.encode_u32(0, _STREAM_PACKET_MAGIC_V2)
				packet.encode_u32(4, raw_size)
				packet.encode_u32(8, chunk_size)
				packet.encode_u32(12, chunk_count)

				out ["packet"] = packet
				out ["chunk_index"] = 0
				out ["chunk_count"] = chunk_count
				out ["stage"] = "compress_chunks" if chunk_count > 0 else "finalize_packet"

			"compress_chunks":
				var raw_bytes_raw: Variant = out.get("raw_bytes", PackedByteArray())
				var raw_bytes: PackedByteArray = raw_bytes_raw if typeof(raw_bytes_raw) == TYPE_PACKED_BYTE_ARRAY else PackedByteArray()
				var packet_raw: Variant = out.get("packet", PackedByteArray())
				var packet: PackedByteArray = packet_raw if typeof(packet_raw) == TYPE_PACKED_BYTE_ARRAY else PackedByteArray()
				var chunk_index: int = int(out.get("chunk_index", 0))
				var chunk_count: int = int(out.get("chunk_count", 0))
				var chunk_size: int = max(32768, int(out.get("chunk_size", _DEFAULT_STREAM_CHUNK_SIZE)))

				if chunk_index >= chunk_count:
					out ["packet"] = packet
					out ["stage"] = "finalize_packet"
					continue

				var start: int = chunk_index * chunk_size
				var end: int = min(start + chunk_size, raw_bytes.size())
				var raw_chunk: PackedByteArray = raw_bytes.slice(start, end)
				var compressed_chunk: PackedByteArray = raw_chunk.compress(FileAccess.COMPRESSION_ZSTD)

				var header:= PackedByteArray()
				header.resize(8)
				header.encode_u32(0, raw_chunk.size())
				header.encode_u32(4, compressed_chunk.size())

				packet.append_array(header)
				packet.append_array(compressed_chunk)

				out ["packet"] = packet
				out ["chunk_index"] = chunk_index + 1
				if int(out.get("chunk_index", 0)) >= chunk_count:
					out ["stage"] = "finalize_packet"

			"finalize_packet":
				var packet_raw: Variant = out.get("packet", PackedByteArray())
				out ["bytes"] = packet_raw if typeof(packet_raw) == TYPE_PACKED_BYTE_ARRAY else PackedByteArray()
				out.erase("packet")
				out.erase("raw_bytes")
				out.erase("chunk_index")
				out.erase("chunk_count")
				out.erase("raw_size")
				out.erase("source_data")
				out.erase("safe_data")
				out.erase("json_text")
				out ["is_complete"] = true
				out ["stage"] = "complete"

			"complete":
				out ["is_complete"] = true

			_:
				out ["bytes"] = PackedByteArray()
				out ["is_complete"] = true
				out ["stage"] = "complete"

	return out

static func _deep_sanitize(value: Variant, _visited: Dictionary = {}, _depth: int = 0) -> Variant:
	if _depth >= _MAX_SANITIZE_DEPTH:
		if value == null:
			return null
		return str(value)
	match typeof(value):
		TYPE_DICTIONARY:
			var out:= {}
			for key in value.keys():
				var safe_key: String = str(key)
				var child: Variant = value [key]
				var ct: int = typeof(child)
				if ct == TYPE_INT or ct == TYPE_FLOAT or ct == TYPE_STRING or ct == TYPE_BOOL:
					out [safe_key] = child
				elif ct == TYPE_NIL:
					out [safe_key] = null
				else:
					out [safe_key] = _deep_sanitize(child, _visited, _depth + 1)
			return out
		TYPE_ARRAY:
			var out:= []
			out.resize(value.size())
			for i in range(value.size()):
				var child: Variant = value [i]
				var ct: int = typeof(child)
				if ct == TYPE_INT or ct == TYPE_FLOAT or ct == TYPE_STRING or ct == TYPE_BOOL:
					out [i] = child
				elif ct == TYPE_NIL:
					out [i] = null
				else:
					out [i] = _deep_sanitize(child, _visited, _depth + 1)
			return out
		TYPE_OBJECT:
			if value != null:
				var obj_id: int = value.get_instance_id()
				if _visited.has(obj_id):
					return "<object:circular>"
				_visited [obj_id] = true
				return "<object:%s>" % str(value)
			return null
		TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_BOOL:
			return value
		TYPE_NIL:
			return null
		_:
			return str(value)

static func decode(bytes: PackedByteArray) -> Dictionary:
	if bytes.is_empty():
		return {}

	if bytes.size() >= 16:
		var packet_magic: int = int(bytes.decode_u32(0))
		if packet_magic == _STREAM_PACKET_MAGIC_V2:
			return _unwrap_contract_binary_save(_decode_chunked_packet(bytes), true)

	if bytes.size() >= 4:
		var expected_size: int = int(bytes.decode_u32(0))
		if expected_size > 0:
			var payload: PackedByteArray = bytes.slice(4, bytes.size())
			var raw: PackedByteArray = payload.decompress(expected_size, FileAccess.COMPRESSION_ZSTD)
			if not raw.is_empty():
				var parsed_new: Dictionary = _parse_json_bytes(raw)
				if not parsed_new.is_empty():
					return _unwrap_contract_binary_save(parsed_new, true)

	var legacy_raw: PackedByteArray = bytes.decompress(536870912, FileAccess.COMPRESSION_ZSTD)
	if not legacy_raw.is_empty():
		var parsed_legacy: Dictionary = _parse_json_bytes(legacy_raw)
		if not parsed_legacy.is_empty():
			return _unwrap_contract_binary_save(parsed_legacy, true)

	return _unwrap_contract_binary_save(_parse_json_bytes(bytes), true)

static func _decode_chunked_packet(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() < 16:
		return {}

	var expected_size: int = int(bytes.decode_u32(4))
	var chunk_count: int = int(bytes.decode_u32(12))
	var cursor: int = 16
	var raw:= PackedByteArray()

	for _i in range(chunk_count):
		if cursor + 8 > bytes.size():
			return {}

		var raw_chunk_size: int = int(bytes.decode_u32(cursor))
		cursor += 4
		var compressed_chunk_size: int = int(bytes.decode_u32(cursor))
		cursor += 4

		if raw_chunk_size < 0 or compressed_chunk_size < 0:
			return {}
		if cursor + compressed_chunk_size > bytes.size():
			return {}

		var compressed_chunk: PackedByteArray = bytes.slice(cursor, cursor + compressed_chunk_size)
		cursor += compressed_chunk_size

		var raw_chunk: PackedByteArray = compressed_chunk.decompress(raw_chunk_size, FileAccess.COMPRESSION_ZSTD)
		if raw_chunk_size > 0 and raw_chunk.is_empty():
			return {}

		raw.append_array(raw_chunk)

	if expected_size > 0 and raw.size() != expected_size:
		return {}

	return _parse_json_bytes(raw)
static func encode_contract_save(data: Dictionary, contract_context: Dictionary = {}) -> PackedByteArray:
	var envelope: Dictionary = _build_contract_binary_save_envelope(data, contract_context)
	var session: Dictionary = begin_encode_session(envelope)
	while not bool(session.get("is_complete", false)):
		session = step_encode_session(session, 8)
	var bytes_raw: Variant = session.get("bytes", PackedByteArray())
	return bytes_raw if typeof(bytes_raw) == TYPE_PACKED_BYTE_ARRAY else PackedByteArray()

static func decode_contract_save(bytes: PackedByteArray) -> Dictionary:
	if bytes.is_empty():
		return {}

	var decoded: Dictionary = decode(bytes)
	if str(decoded.get("schema", "")).strip_edges() == _CONTRACT_BINARY_SAVE_SCHEMA:
		return decoded

	var envelope:= {
		"schema": _CONTRACT_BINARY_SAVE_SCHEMA,
		"version": _CONTRACT_BINARY_SAVE_VERSION,
		"payload": decoded,
		"decoded_at_ms": int(Time.get_ticks_msec())
	}

	return envelope

static func _maybe_wrap_contract_save(data: Dictionary) -> Dictionary:
	var schema: String = str(data.get("schema", "")).strip_edges()
	if schema == _CONTRACT_BINARY_SAVE_SCHEMA:
		return data

	if data.has("save_contract") or data.has("contract_governor_report") or schema == "eralife.game_state_contract_save_slices":
		return _build_contract_binary_save_envelope(data, {})

	return data

static func _build_contract_binary_save_envelope(data: Dictionary, contract_context: Dictionary = {}) -> Dictionary:
	var payload: Dictionary = data.duplicate(true)

	var save_contract_raw: Variant = contract_context.get("save_contract", payload.get("save_contract", {}))
	var save_contract: Dictionary = save_contract_raw.duplicate(true) if typeof(save_contract_raw) == TYPE_DICTIONARY else {}

	var slice_registry_raw: Variant = contract_context.get("save_slice_registry", {})
	var slice_registry: Dictionary = slice_registry_raw.duplicate(true) if typeof(slice_registry_raw) == TYPE_DICTIONARY else {}

	if str(payload.get("schema", "")).strip_edges() == "eralife.game_state_contract_save_slices":
		var governor:= SaveContractGovernor.new()
		var governed: Dictionary = governor.govern_export_save_slices(payload, save_contract, slice_registry)
		var governed_payload_raw: Variant = governed.get("payload", payload)
		if typeof(governed_payload_raw) == TYPE_DICTIONARY:
			payload = governed_payload_raw
		var governed_contract_raw: Variant = governed.get("contract", save_contract)
		if typeof(governed_contract_raw) == TYPE_DICTIONARY:
			save_contract = governed_contract_raw

	var envelope:= {
		"schema": _CONTRACT_BINARY_SAVE_SCHEMA,
		"version": _CONTRACT_BINARY_SAVE_VERSION,
		"binary_packet_version": 2,
		"payload_schema": str(payload.get("schema", "")),
		"state_id": str(payload.get("state_id", contract_context.get("state_id", ""))).strip_edges(),
		"world_id": str(contract_context.get("world_id", payload.get("world_id", payload.get("state_id", "")))).strip_edges(),
		"life_id": str(contract_context.get("life_id", payload.get("life_id", ""))).strip_edges(),
		"timeline_id": str(contract_context.get("timeline_id", payload.get("timeline_id", ""))).strip_edges(),
		"save_contract": save_contract.duplicate(true),
		"payload": payload,
		"compatibility": {
			"backwards_compatible": true,
		},
		"created_at_ms": int(Time.get_ticks_msec())
	}

	return envelope

static func _unwrap_contract_binary_save(decoded: Dictionary, unwrap_payload: bool = true) -> Dictionary:
	if decoded.is_empty():
		return {}

	if str(decoded.get("schema", "")).strip_edges() != _CONTRACT_BINARY_SAVE_SCHEMA:
		return decoded

	if not unwrap_payload:
		return decoded

	var payload_raw: Variant = decoded.get("payload", {})
	if typeof(payload_raw) != TYPE_DICTIONARY:
		return {}

	var payload: Dictionary = payload_raw.duplicate(true)

	if not payload.has("save_contract"):
		var save_contract_raw: Variant = decoded.get("save_contract", {})
		if typeof(save_contract_raw) == TYPE_DICTIONARY:
			payload ["save_contract"] = (save_contract_raw as Dictionary).duplicate(true)

	payload ["binary_save_envelope"] = {
		"schema": str(decoded.get("schema", "")),
		"version": int(decoded.get("version", 1)),
		"state_id": str(decoded.get("state_id", "")),
		"world_id": str(decoded.get("world_id", "")),
		"life_id": str(decoded.get("life_id", "")),
		"timeline_id": str(decoded.get("timeline_id", "")),
		"compatibility": decoded.get("compatibility", {}).duplicate(true) if typeof(decoded.get("compatibility", {})) == TYPE_DICTIONARY else {},
		"created_at_ms": int(decoded.get("created_at_ms", 0))
	}

	return payload
static func _parse_json_bytes(raw: PackedByteArray) -> Dictionary:
	if raw.is_empty():
		return {}

	var text: String = raw.get_string_from_utf8()
	if text == "":
		return {}

	var json:= JSON.new()
	var err: int = json.parse(text)
	if err == OK and typeof(json.data) == TYPE_DICTIONARY:
		return json.data
	return {}