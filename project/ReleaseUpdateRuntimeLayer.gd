extends Node

const CONTRACT_SCHEMA:= "eralife.release_update_runtime"
const CONTRACT_VERSION:= 1
const RELEASE_CHANNEL:= "stable"



const LOCAL_CORE_BUILD_NUMBER:= 3

const RELEASE_GATEWAY_ORIGIN:= (
	"https://eralife-release.acrello71.workers.dev/"
)

const MANIFEST_URL:= (
	RELEASE_GATEWAY_ORIGIN
	+ "stable/release-envelope.json"
)

const RELEASE_PUBLIC_KEY_PATH:= (
	"res://release/eralife_release_public.pub"
)

const UPDATE_ORIGINS:= [
	RELEASE_GATEWAY_ORIGIN,
	"https://updates.eralife.app/"
]

const STARTUP_GRACE_MS:= 2500
const MANIFEST_INTERVAL_MS:= 30000
const RETRY_INTERVAL_MS:= 10000
const AUTHORITY_ADMISSION_RETRY_MS:= 1000

const MANIFEST_MAX_BODY_BYTES:= 65536
const LIVE_BUNDLE_MAX_BODY_BYTES:= 32768

var manifest_request: HTTPRequest = null
var live_bundle_request: HTTPRequest = null

var runtime_started_at_ms: int = 0
var next_manifest_check_ms: int = 0
var manifest_in_flight: bool = false
var live_bundle_in_flight: bool = false

var active_manifest: Dictionary = {}
var pending_live_descriptor: Dictionary = {}

var verified_live_bundle: Dictionary = {}
var verified_live_revision: String = ""

var authority_rows: Array = []
var authority_applied_revision_by_instance_id: Dictionary = {}
var authority_blocked_revision_by_instance_id: Dictionary = {}
var authority_next_admission_retry_ms_by_instance_id: Dictionary = {}

var live_transaction_context: Dictionary = {}

var core_update_available_contract: Dictionary = {}
var last_release_update_report: Dictionary = {}


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	var now_ms: int = int(
		Time.get_ticks_msec()
	)

	if runtime_started_at_ms <= 0:
		runtime_started_at_ms = now_ms
		next_manifest_check_ms = (
			now_ms + STARTUP_GRACE_MS
		)

		set_meta(
			"release_runtime_next_residency_probe_ms",
			now_ms
		)
		set_meta(
			"release_runtime_interactive_residency_cached",
			false
		)
		set_meta(
			"release_runtime_next_authority_service_ms",
			now_ms
		)

		return

	var next_residency_probe_ms: int = int(
		get_meta(
			"release_runtime_next_residency_probe_ms",
			0
		)
	)

	if now_ms >= next_residency_probe_ms:
		var interactive_residency: bool = (
			_release_runtime_interactive_residency_active()
		)

		set_meta(
			"release_runtime_interactive_residency_cached",
			interactive_residency
		)
		set_meta(
			"release_runtime_next_residency_probe_ms",
			now_ms + 250
		)
		set_meta(
			"release_runtime_last_residency_probe_at_ms",
			now_ms
		)

	var interactive_residency_cached: bool = bool(
		get_meta(
			"release_runtime_interactive_residency_cached",
			false
		)
	)





	if interactive_residency_cached:
		set_meta(
			"release_runtime_yielding_to_interactive_residency",
			true
		)
		set_meta(
			"release_runtime_yielded_at_ms",
			now_ms
		)

		if now_ms >= next_manifest_check_ms:
			next_manifest_check_ms = (
				now_ms + 1000
			)

		return

	set_meta(
		"release_runtime_yielding_to_interactive_residency",
		false
	)




	if (
		not verified_live_bundle.is_empty()
		and verified_live_revision != ""
	):
		var next_authority_service_ms: int = int(
			get_meta(
				"release_runtime_next_authority_service_ms",
				0
			)
		)

		if now_ms >= next_authority_service_ms:
			set_meta(
				"release_runtime_next_authority_service_ms",
				now_ms + 250
			)




			if authority_rows.size() <= 32:
				_service_live_release_authorities()
			else:
				set_meta(
					"release_runtime_authority_service_deferred",
					true
				)
				set_meta(
					"release_runtime_authority_service_deferred_reason",
					"authority_registry_exceeds_bounded_service_ceiling"
				)
				set_meta(
					"release_runtime_authority_service_deferred_count",
					authority_rows.size()
				)

	if now_ms < next_manifest_check_ms:
		return

	if (
		manifest_in_flight
		or live_bundle_in_flight
	):
		return

	_ensure_runtime_nodes()
	_request_release_manifest()


func register_contract_authority(
	authority: GameStateContractEngine
) -> void:
	if authority == null:
		return

	_cleanup_contract_authorities()

	var instance_id: int = int(
		authority.get_instance_id()
	)

	for raw_row in authority_rows:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = raw_row
		if int(
			row.get("instance_id", -1)
		) == instance_id:
			return

	authority_rows.append({
		"instance_id": instance_id,
		"ref": weakref(authority)
	})


func _cleanup_contract_authorities() -> void:
	for i in range(
		authority_rows.size() - 1,
		-1,
		-1
	):
		var raw_row: Variant = authority_rows [i]
		if typeof(raw_row) != TYPE_DICTIONARY:
			authority_rows.remove_at(i)
			continue

		var row: Dictionary = raw_row
		var authority_ref: WeakRef = row.get(
			"ref",
			null
		)

		if (
			authority_ref != null
			and authority_ref.get_ref() != null
		):
			continue

		var dead_instance_id: int = int(
			row.get("instance_id", -1)
		)

		authority_rows.remove_at(i)
		authority_applied_revision_by_instance_id.erase(
			dead_instance_id
		)
		authority_blocked_revision_by_instance_id.erase(
			dead_instance_id
		)
		authority_next_admission_retry_ms_by_instance_id.erase(
			dead_instance_id
		)

		var dead_transaction_ids: Array = []

		for raw_transaction_id in live_transaction_context.keys():
			var transaction_id: String = str(
				raw_transaction_id
			)
			var context_raw: Variant = (
				live_transaction_context.get(
					transaction_id,
					{}
				)
			)
			if typeof(context_raw) != TYPE_DICTIONARY:
				continue

			var context: Dictionary = context_raw
			if int(
				context.get(
					"authority_instance_id",
					-1
				)
			) == dead_instance_id:
				dead_transaction_ids.append(
					transaction_id
				)

		for dead_transaction_id in dead_transaction_ids:
			live_transaction_context.erase(
				str(dead_transaction_id)
			)


func _ensure_runtime_nodes() -> void:
	if manifest_request == null:
		manifest_request = HTTPRequest.new()
		manifest_request.name = "ReleaseManifestRequest"
		manifest_request.use_threads = true
		manifest_request.body_size_limit = (
			MANIFEST_MAX_BODY_BYTES
		)
		manifest_request.max_redirects = 0
		manifest_request.timeout = 8.0

		add_child(manifest_request)

		manifest_request.request_completed.connect(
			_on_release_manifest_request_completed
		)

	if live_bundle_request == null:
		live_bundle_request = HTTPRequest.new()
		live_bundle_request.name = "ReleaseLiveBundleRequest"
		live_bundle_request.use_threads = true
		live_bundle_request.body_size_limit = (
			LIVE_BUNDLE_MAX_BODY_BYTES
		)
		live_bundle_request.max_redirects = 0
		live_bundle_request.timeout = 10.0

		add_child(live_bundle_request)

		live_bundle_request.request_completed.connect(
			_on_live_bundle_request_completed
		)


func _request_release_manifest() -> void:
	var error: int = manifest_request.request(
		MANIFEST_URL,
		PackedStringArray([
			"Accept: application/json",
			"Cache-Control: no-cache"
		])
	)

	if error != OK:
		manifest_in_flight = false
		_schedule_next_manifest_check(false)

		last_release_update_report = {
			"schema": CONTRACT_SCHEMA,
			"version": CONTRACT_VERSION,
			"success": false,
			"stage": "request_manifest",
			"error": error,
			"checked_at_ms": int(
				Time.get_ticks_msec()
			)
		}
		return

	manifest_in_flight = true


func _on_release_manifest_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	manifest_in_flight = false




	if _release_runtime_interactive_residency_active():
		last_release_update_report = {
			"schema": CONTRACT_SCHEMA,
			"version": CONTRACT_VERSION,
			"success": true,
			"stage": "manifest_response_deferred",
			"reason": "interactive_residency_has_absolute_frame_priority",
			"deferred_at_ms": int(
				Time.get_ticks_msec()
			)
		}

		_schedule_next_manifest_check(
			false
		)
		return

	if (
		result != HTTPRequest.RESULT_SUCCESS
		or response_code != 200
	):
		_schedule_next_manifest_check(
			false
		)
		return

	var envelope_report: Dictionary = (
		_verify_signed_release_envelope(
			body,
			MANIFEST_MAX_BODY_BYTES
		)
	)

	if not bool(
		envelope_report.get(
			"success",
			false
		)
	):
		_schedule_next_manifest_check(
			false
		)
		last_release_update_report = (
			envelope_report.duplicate(true)
		)
		return

	var manifest_raw: Variant = (
		envelope_report.get(
			"payload",
			{}
		)
	)

	if typeof(manifest_raw) != TYPE_DICTIONARY:
		_schedule_next_manifest_check(
			false
		)
		return

	var manifest: Dictionary = manifest_raw

	if str(
		manifest.get(
			"schema",
			""
		)
	) != "eralife.release_manifest":
		_schedule_next_manifest_check(
			false
		)
		return

	if int(
		manifest.get(
			"version",
			0
		)
	) != 1:
		_schedule_next_manifest_check(
			false
		)
		return

	if str(
		manifest.get(
			"channel",
			""
		)
	).strip_edges().to_lower() != RELEASE_CHANNEL:
		_schedule_next_manifest_check(
			false
		)
		return

	active_manifest = manifest.duplicate(true)
	core_update_available_contract = (
		_core_update_contract(
			active_manifest
		)
	)

	var live_raw: Variant = (
		active_manifest.get(
			"live_contract",
			{}
		)
	)

	if typeof(live_raw) == TYPE_DICTIONARY:
		var live_descriptor: Dictionary = live_raw
		var revision: String = str(
			live_descriptor.get(
				"revision",
				""
			)
		).strip_edges()
		var min_core_build: int = int(
			live_descriptor.get(
				"min_core_build",
				LOCAL_CORE_BUILD_NUMBER
			)
		)
		var max_core_build: int = int(
			live_descriptor.get(
				"max_core_build",
				2147483647
			)
		)

		if (
			revision != ""
			and revision != verified_live_revision
			and LOCAL_CORE_BUILD_NUMBER >= min_core_build
			and LOCAL_CORE_BUILD_NUMBER <= max_core_build
		):
			_request_live_bundle(
				live_descriptor
			)
		elif (
			revision != ""
			and (
				LOCAL_CORE_BUILD_NUMBER < min_core_build
				or LOCAL_CORE_BUILD_NUMBER > max_core_build
			)
		):
			last_release_update_report = {
				"schema": CONTRACT_SCHEMA,
				"version": CONTRACT_VERSION,
				"success": false,
				"stage": "live_contract_compatibility",
				"restart_required": true,
				"revision": revision,
				"min_core_build": min_core_build,
				"max_core_build": max_core_build,
				"local_core_build": LOCAL_CORE_BUILD_NUMBER,
				"checked_at_ms": int(
					Time.get_ticks_msec()
				)
			}

	_schedule_next_manifest_check(
		true
	)


func _verify_signed_release_envelope(
	body: PackedByteArray,
	max_body_bytes: int
) -> Dictionary:
	var report:= {
		"schema": "eralife.signed_release_envelope_verification_report",
		"version": CONTRACT_VERSION,
		"success": false,
		"payload": {},
		"reason": "",
		"verified_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	if (
		body.is_empty()
		or body.size() > max_body_bytes
	):
		report ["reason"] = (
			"signed_envelope_size_invalid"
		)
		return report

	var envelope_raw: Variant = JSON.parse_string(
		body.get_string_from_utf8()
	)

	if typeof(envelope_raw) != TYPE_DICTIONARY:
		report ["reason"] = (
			"signed_envelope_json_invalid"
		)
		return report

	var envelope: Dictionary = envelope_raw

	if str(
		envelope.get("schema", "")
	) != "eralife.signed_release_envelope":
		report ["reason"] = (
			"signed_envelope_schema_invalid"
		)
		return report

	if int(envelope.get("version", 0)) != 1:
		report ["reason"] = (
			"signed_envelope_version_invalid"
		)
		return report

	var payload_b64: String = str(
		envelope.get("payload_b64", "")
	).strip_edges()
	var signature_b64: String = str(
		envelope.get("signature_b64", "")
	).strip_edges()

	if payload_b64 == "" or signature_b64 == "":
		report ["reason"] = (
			"signed_envelope_material_missing"
		)
		return report

	var payload_bytes: PackedByteArray = (
		Marshalls.base64_to_raw(payload_b64)
	)
	var signature: PackedByteArray = (
		Marshalls.base64_to_raw(signature_b64)
	)

	if (
		payload_bytes.is_empty()
		or signature.is_empty()
	):
		report ["reason"] = (
			"signed_envelope_base64_invalid"
		)
		return report

	if payload_bytes.size() > max_body_bytes:
		report ["reason"] = (
			"signed_payload_size_invalid"
		)
		return report

	var public_key:= CryptoKey.new()
	var key_error: int = public_key.load(
		RELEASE_PUBLIC_KEY_PATH,
		true
	)

	if key_error != OK:
		report ["reason"] = (
			"release_public_key_unavailable"
		)
		report ["error"] = key_error
		return report

	var payload_hash: PackedByteArray = (
		_sha256_buffer(payload_bytes)
	)

	if payload_hash.is_empty():
		report ["reason"] = (
			"signed_payload_hash_failed"
		)
		return report

	var crypto:= Crypto.new()

	if not crypto.verify(
		HashingContext.HASH_SHA256,
		payload_hash,
		signature,
		public_key
	):
		report ["reason"] = (
			"signed_payload_signature_invalid"
		)
		return report

	var payload_raw: Variant = JSON.parse_string(
		payload_bytes.get_string_from_utf8()
	)

	if typeof(payload_raw) != TYPE_DICTIONARY:
		report ["reason"] = (
			"signed_payload_json_invalid"
		)
		return report

	report ["success"] = true
	report ["payload"] = (
		(payload_raw as Dictionary).duplicate(true)
	)

	return report


func _sha256_buffer(
	bytes: PackedByteArray
) -> PackedByteArray:
	var hashing_context:= HashingContext.new()

	if (
		hashing_context.start(
			HashingContext.HASH_SHA256
		) != OK
	):
		return PackedByteArray()

	if hashing_context.update(bytes) != OK:
		return PackedByteArray()

	return hashing_context.finish()


func _sha256_hex(
	bytes: PackedByteArray
) -> String:
	var digest: PackedByteArray = (
		_sha256_buffer(bytes)
	)
	if digest.is_empty():
		return ""

	var out: String = ""
	for raw_byte in digest:
		out += "%02x" % int(raw_byte)

	return out


func _request_live_bundle(
	descriptor: Dictionary
) -> void:
	if live_bundle_in_flight:
		return

	var revision: String = str(
		descriptor.get("revision", "")
	).strip_edges()
	var bundle_url: String = str(
		descriptor.get("url", "")
	).strip_edges()
	var expected_sha256: String = str(
		descriptor.get("sha256", "")
	).strip_edges().to_lower()

	if revision == "":
		return

	if not _release_url_is_allowed(bundle_url):
		return

	if expected_sha256.length() != 64:
		return

	pending_live_descriptor = (
		descriptor.duplicate(true)
	)

	var error: int = live_bundle_request.request(
		bundle_url,
		PackedStringArray([
			"Accept: application/json",
			"Cache-Control: no-cache"
		])
	)

	if error != OK:
		pending_live_descriptor = {}
		live_bundle_in_flight = false
		return

	live_bundle_in_flight = true


func _on_live_bundle_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	live_bundle_in_flight = false

	var descriptor: Dictionary = (
		pending_live_descriptor.duplicate(true)
	)
	pending_live_descriptor = {}




	if _release_runtime_interactive_residency_active():
		last_release_update_report = {
			"schema": CONTRACT_SCHEMA,
			"version": CONTRACT_VERSION,
			"success": true,
			"stage": "live_bundle_response_deferred",
			"reason": "interactive_residency_has_absolute_frame_priority",
			"revision": str(
				descriptor.get(
					"revision",
					""
				)
			).strip_edges(),
			"deferred_at_ms": int(
				Time.get_ticks_msec()
			)
		}

		_schedule_next_manifest_check(
			false
		)
		return

	if (
		result != HTTPRequest.RESULT_SUCCESS
		or response_code != 200
	):
		return

	if (
		body.is_empty()
		or body.size() > LIVE_BUNDLE_MAX_BODY_BYTES
	):
		return

	var expected_sha256: String = str(
		descriptor.get(
			"sha256",
			""
		)
	).strip_edges().to_lower()

	var actual_sha256: String = (
		_sha256_hex(
			body
		)
	)

	if (
		actual_sha256 == ""
		or actual_sha256 != expected_sha256
	):
		return

	var bundle_raw: Variant = JSON.parse_string(
		body.get_string_from_utf8()
	)

	if typeof(bundle_raw) != TYPE_DICTIONARY:
		return

	verified_live_bundle = (
		(bundle_raw as Dictionary).duplicate(true)
	)
	verified_live_revision = str(
		descriptor.get(
			"revision",
			""
		)
	).strip_edges()

	last_release_update_report = {
		"schema": CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"success": true,
		"stage": "live_bundle_verified",
		"revision": verified_live_revision,
		"sha256": actual_sha256,
		"verified_at_ms": int(
			Time.get_ticks_msec()
		)
	}

func _service_live_release_authorities() -> void:
	_cleanup_contract_authorities()

	var now_ms: int = int(
		Time.get_ticks_msec()
	)

	if (
		verified_live_bundle.is_empty()
		or verified_live_revision == ""
	):
		return

	for raw_row in authority_rows:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = raw_row
		var authority_ref: WeakRef = row.get(
			"ref",
			null
		)
		if authority_ref == null:
			continue

		var authority = authority_ref.get_ref()
		if authority == null:
			continue

		var authority_instance_id: int = int(
			row.get("instance_id", -1)
		)

		if str(
			authority_applied_revision_by_instance_id.get(
				authority_instance_id,
				""
			)
		) == verified_live_revision:
			continue

		if str(
			authority_blocked_revision_by_instance_id.get(
				authority_instance_id,
				""
			)
		) == verified_live_revision:
			continue

		var admission_retry_ms: int = int(
			authority_next_admission_retry_ms_by_instance_id.get(
				authority_instance_id,
				0
			)
		)

		if admission_retry_ms > now_ms:
			continue

		if _authority_has_pending_live_transaction(
			authority_instance_id
		):
			continue

		var enqueue_report: Dictionary = (
			authority.live_hot_swap_contract_bundle(
				verified_live_bundle,
				{
					"source": "release_update_runtime",
					"source_label": (
						"release://%s"
						% verified_live_revision
					),
					"release_nonblocking_lane": true,
					"release_revision": (
						verified_live_revision
					),
					"allow_rollback": true
				}
			)
		)

		if bool(
			enqueue_report.get("accepted", false)
		):
			authority_next_admission_retry_ms_by_instance_id.erase(
				authority_instance_id
			)

			var transaction_id: String = str(
				enqueue_report.get(
					"transaction_id",
					""
				)
			).strip_edges()

			if transaction_id != "":
				live_transaction_context [
					transaction_id
				] = {
					"authority_instance_id": (
						authority_instance_id
					),
					"revision": (
						verified_live_revision
					)
				}


			return

		if bool(
			enqueue_report.get("deferred", false)
		):
			authority_next_admission_retry_ms_by_instance_id [
				authority_instance_id
			] = (
				now_ms
				+ AUTHORITY_ADMISSION_RETRY_MS
			)
			continue

		if bool(
			enqueue_report.get(
				"restart_required",
				false
			)
		):
			authority_blocked_revision_by_instance_id [
				authority_instance_id
			] = verified_live_revision

			last_release_update_report = {
				"schema": CONTRACT_SCHEMA,
				"version": CONTRACT_VERSION,
				"success": false,
				"stage": "live_bundle_admission",
				"restart_required": true,
				"revision": verified_live_revision,
				"authority_instance_id": (
					authority_instance_id
				),
				"admission": (
					enqueue_report.get(
						"admission",
						{}
					).duplicate(true)
					if typeof(
						enqueue_report.get(
							"admission",
							{}
						)
					) == TYPE_DICTIONARY
					else {}
				),
				"checked_at_ms": int(
					Time.get_ticks_msec()
				)
			}
			return

	for raw_row in authority_rows:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = raw_row
		var authority_ref: WeakRef = row.get(
			"ref",
			null
		)
		if authority_ref == null:
			continue

		var authority = authority_ref.get_ref()
		if authority == null:
			continue

		var service_report: Dictionary = (
			authority.service_live_release_hot_swap(
				1
			)
		)

		if int(
			service_report.get("serviced", 0)
		) <= 0:
			if int(
				service_report.get(
					"progressed",
					0
				)
			) > 0:


				return

			continue

		for raw_completion in service_report.get(
			"reports",
			[]
		):
			if typeof(
				raw_completion
			) != TYPE_DICTIONARY:
				continue

			var completion: Dictionary = (
				raw_completion
			)
			var transaction_id: String = str(
				completion.get(
					"transaction_id",
					""
				)
			).strip_edges()

			var context_raw: Variant = (
				live_transaction_context.get(
					transaction_id,
					{}
				)
			)
			var context: Dictionary = (
				context_raw as Dictionary
				if typeof(context_raw) == TYPE_DICTIONARY
				else {}
			)

			var authority_instance_id: int = int(
				context.get(
					"authority_instance_id",
					-1
				)
			)
			var revision: String = str(
				context.get(
					"revision",
					""
				)
			).strip_edges()

			if bool(
				completion.get("success", false)
			):
				authority_next_admission_retry_ms_by_instance_id.erase(
					authority_instance_id
				)
				authority_applied_revision_by_instance_id [
					authority_instance_id
				] = revision
				authority_blocked_revision_by_instance_id.erase(
					authority_instance_id
				)
			else:
				authority_blocked_revision_by_instance_id [
					authority_instance_id
				] = revision

			live_transaction_context.erase(
				transaction_id
			)
			last_release_update_report = (
				completion.duplicate(true)
			)

		return


func _authority_has_pending_live_transaction(
	authority_instance_id: int
) -> bool:
	for raw_context in live_transaction_context.values():
		if typeof(raw_context) != TYPE_DICTIONARY:
			continue

		var context: Dictionary = raw_context
		if int(
			context.get(
				"authority_instance_id",
				-1
			)
		) == authority_instance_id:
			return true

	return false


func _core_update_contract(
	manifest: Dictionary
) -> Dictionary:
	var remote_core_build: int = int(
		manifest.get(
			"core_build_number",
			0
		)
	)

	if remote_core_build <= LOCAL_CORE_BUILD_NUMBER:
		return {}

	var platform_key: String = _platform_key()
	var platforms_raw: Variant = (
		manifest.get("platforms", {})
	)

	if (
		platform_key == ""
		or typeof(platforms_raw) != TYPE_DICTIONARY
	):
		return {}

	var platforms: Dictionary = platforms_raw
	var artifact_raw: Variant = platforms.get(
		platform_key,
		{}
	)

	if typeof(artifact_raw) != TYPE_DICTIONARY:
		return {}

	var artifact: Dictionary = artifact_raw
	var artifact_url: String = str(
		artifact.get("url", "")
	).strip_edges()
	var artifact_sha256: String = str(
		artifact.get("sha256", "")
	).strip_edges().to_lower()

	if not _release_url_is_allowed(
		artifact_url
	):
		return {}

	if artifact_sha256.length() != 64:
		return {}

	return {
		"schema": "eralife.core_update_available_contract",
		"version": CONTRACT_VERSION,
		"release_id": str(
			manifest.get("release_id", "")
		),
		"core_build_number": remote_core_build,
		"local_core_build_number": (
			LOCAL_CORE_BUILD_NUMBER
		),
		"platform": platform_key,
		"artifact": artifact.duplicate(true),
		"restart_required": true,
		"observed_at_ms": int(
			Time.get_ticks_msec()
		)
	}


func _platform_key() -> String:
	if OS.has_feature("windows"):
		return "windows"

	if OS.has_feature("macos"):
		return "macos"

	if OS.has_feature("linux"):
		return "linux"

	return ""


func _release_url_is_allowed(
	url: String
) -> bool:
	var clean_url: String = str(
		url
	).strip_edges()

	if clean_url == "":
		return false

	for raw_origin in UPDATE_ORIGINS:
		var origin: String = str(
			raw_origin
		).strip_edges()

		if origin == "":
			continue

		if clean_url.begins_with(origin):
			return true

	return false

func _release_runtime_interactive_residency_active() -> bool:



	if authority_rows.is_empty():
		return true

	var total_rows: int = authority_rows.size()
	var max_rows_per_probe: int = 32
	var start_index: int = maxi(
		0,
		total_rows - max_rows_per_probe
	)

	for i in range(
		start_index,
		total_rows
	):
		var raw_row: Variant = authority_rows [i]

		if typeof(raw_row) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = raw_row
		var authority_ref: WeakRef = row.get(
			"ref",
			null
		)

		if authority_ref == null:
			continue

		var authority = authority_ref.get_ref()

		if authority == null:
			continue

		var authority_gs = authority.get(
			"gs"
		)

		if authority_gs == null:
			continue

		var state_raw: Variant = authority_gs.get(
			"scenario_state"
		)
		var state: Dictionary = (
			state_raw as Dictionary
			if typeof(state_raw) == TYPE_DICTIONARY
			else {}
		)

		if state.is_empty():
			continue

		if bool(
			state.get(
				"birth_shell_interactive_controls_visible",
				false
			)
		):
			return true

		var guard_raw: Variant = state.get(
			"runtime_guard",
			{}
		)
		var guard: Dictionary = (
			guard_raw as Dictionary
			if typeof(guard_raw) == TYPE_DICTIONARY
			else {}
		)

		var player_control_released: bool = bool(
			state.get(
				"birth_shell_player_control_released",
				false
			)
		)
		var residency_sovereignty: bool = (
			bool(
				state.get(
					"playable_life_shell_input_sovereignty",
					false
				)
			)
			or bool(
				state.get(
					"playable_life_shell_has_visible_sovereignty",
					false
				)
			)
			or bool(
				guard.get(
					"playable_life_shell_input_sovereignty",
					false
				)
			)
		)

		if (
			player_control_released
			and residency_sovereignty
		):
			return true



	if total_rows > max_rows_per_probe:
		return true

	return false
func _schedule_next_manifest_check(
	success: bool
) -> void:
	var interval_ms: int = (
		MANIFEST_INTERVAL_MS
		if success
		else RETRY_INTERVAL_MS
	)

	next_manifest_check_ms = (
		int(Time.get_ticks_msec())
		+ interval_ms
	)