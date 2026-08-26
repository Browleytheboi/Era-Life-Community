extends Node
class_name EraAudioContractEngine

const CONTRACT_SCHEMA:= "eralife.audio_contract"
const CONTRACT_VERSION:= 1
const SILENT_DB:= -80.0

var host_node: Node = null
var primary_player: AudioStreamPlayer = null
var secondary_player: AudioStreamPlayer = null
var current_player: AudioStreamPlayer = null
var current_track_id: String = ""
var current_era_key: String = ""
var current_context_key: String = ""
var current_stream_path: String = ""
var current_contract_signature: String = ""
var fade_tween: Tween = null
var last_report: Dictionary = {}



var precached_streams: Dictionary = {}




var pending_audio_claim: Dictionary = {}
var pending_audio_claim_sequence: int = 0


func bootstrap(parent_node: Node) -> void:
	if parent_node == null:
		return

	host_node = parent_node



	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)

	primary_player = _ensure_audio_player(
		"EraAudioPrimary"
	)
	secondary_player = _ensure_audio_player(
		"EraAudioSecondary"
	)

	if current_player == null:
		current_player = primary_player

	for player in [
		primary_player,
		secondary_player
	]:
		if (
			player == null
			or not is_instance_valid(player)
		):
			continue

		player.process_mode = Node.PROCESS_MODE_ALWAYS
		player.stream_paused = false
		player.autoplay = false
func _append_audio_path_candidate(
	candidates: Array,
	seen: Dictionary,
	raw_path: String
) -> void:
	var clean_path: String = str(
		raw_path
	).strip_edges()

	if clean_path == "":
		return

	var key: String = clean_path.to_lower()

	if seen.has(key):
		return

	seen [key] = true
	candidates.append(clean_path)


func _audio_path_candidates(
	raw_path: String
) -> Array:
	var clean_path: String = str(
		raw_path
	).strip_edges()
	var candidates: Array = []
	var seen: Dictionary = {}

	if clean_path == "":
		return candidates

	_append_audio_path_candidate(
		candidates,
		seen,
		clean_path
	)

	var file_name: String = clean_path.get_file()

	if file_name != "":
		for directory in [
			"res://audio",
			"res://Audio",
			"res://audio/music",
			"res://Audio/Music",
			"res://audio/sfx",
			"res://Audio/SFX",
			"res://"
		]:
			var candidate_path: String = (
				"%s/%s"
				% [
					str(directory).trim_suffix("/"),
					file_name
				]
			)

			_append_audio_path_candidate(
				candidates,
				seen,
				candidate_path
			)

	var existing_candidates: Array = (
		candidates.duplicate()
	)

	for raw_candidate in existing_candidates:
		var candidate: String = str(
			raw_candidate
		)

		for variant in [
			candidate.replace(
				"res://audio/",
				"res://Audio/"
			),
			candidate.replace(
				"res://Audio/",
				"res://audio/"
			),
			candidate.replace(
				"/music/",
				"/Music/"
			),
			candidate.replace(
				"/Music/",
				"/music/"
			),
			candidate.replace(
				"/sfx/",
				"/SFX/"
			),
			candidate.replace(
				"/SFX/",
				"/sfx/"
			)
		]:
			_append_audio_path_candidate(
				candidates,
				seen,
				str(variant)
			)

	return candidates


func resolve_audio_stream_path(
	candidate_paths: Array
) -> String:
	set_meta(
		"audio_stream_last_path_rejection",
		{}
	)

	for raw_path in candidate_paths:
		for raw_candidate in _audio_path_candidates(
			str(raw_path)
		):
			var candidate: String = str(
				raw_candidate
			).strip_edges()

			if candidate == "":
				continue

			var cached_raw: Variant = precached_streams.get(
				candidate,
				null
			)

			if cached_raw is AudioStream:
				return candidate

			var validation: Dictionary = (
				_audio_import_payload_validation(
					candidate
				)
			)

			if not bool(
				validation.get(
					"valid",
					false
				)
			):
				set_meta(
					"audio_stream_last_path_rejection",
					validation.duplicate(true)
				)
				continue

			if ResourceLoader.exists(
				candidate
			):
				return candidate

	return ""

func request_audio_stream(
	candidate_paths: Array,
	context: Dictionary = {}
) -> Dictionary:
	var stream_path: String = (
		resolve_audio_stream_path(
			candidate_paths
		)
	)

	if stream_path == "":
		var rejection_raw: Variant = get_meta(
			"audio_stream_last_path_rejection",
			{}
		)
		var rejection: Dictionary = (
			(rejection_raw as Dictionary).duplicate(true)
			if typeof(rejection_raw) == TYPE_DICTIONARY
			else {}
		)
		var rejection_reason: String = str(
			rejection.get(
				"reason",
				"audio_stream_path_missing"
			)
		).strip_edges()

		if rejection_reason == "":
			rejection_reason = "audio_stream_path_missing"

		return {
			"success": false,
			"ready": false,
			"pending": false,
			"reason": rejection_reason,
			"candidate_paths": (
				candidate_paths.duplicate(true)
			),
			"path_validation": rejection,
			"synchronous_load_performed": false,
			"terminal_for_current_import_state": (
				rejection_reason
				== "audio_import_payload_missing"
			),
			"context": context.duplicate(true)
		}

	var cached_raw: Variant = (
		precached_streams.get(
			stream_path,
			null
		)
	)

	if cached_raw is AudioStream:
		return {
			"success": true,
			"ready": true,
			"pending": false,
			"reason": "audio_stream_cached",
			"stream_path": stream_path,
			"stream": cached_raw,
			"synchronous_load_performed": false,
			"context": context.duplicate(true)
		}

	var validation: Dictionary = (
		_audio_import_payload_validation(
			stream_path
		)
	)

	if not bool(
		validation.get(
			"valid",
			false
		)
	):
		return {
			"success": false,
			"ready": false,
			"pending": false,
			"reason": str(
				validation.get(
					"reason",
					"audio_import_payload_invalid"
				)
			),
			"stream_path": stream_path,
			"path_validation": (
				validation.duplicate(true)
			),
			"synchronous_load_performed": false,
			"context": context.duplicate(true)
		}

	var load_status: ResourceLoader.ThreadLoadStatus = (
		ResourceLoader.load_threaded_get_status(
			stream_path
		)
	)

	match load_status:
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			var request_error: Error = (
				ResourceLoader.load_threaded_request(
					stream_path,
					"AudioStream"
				)
			)

			if request_error != OK:
				return {
					"success": false,
					"ready": false,
					"pending": false,
					"reason": (
						"audio_stream_threaded_request_failed"
					),
					"stream_path": stream_path,
					"request_error": request_error,
					"path_validation": (
						validation.duplicate(true)
					),
					"context": context.duplicate(true)
				}

			return {
				"success": true,
				"ready": false,
				"pending": true,
				"reason": (
					"audio_stream_threaded_load_requested"
				),
				"stream_path": stream_path,
				"synchronous_load_performed": false,
				"context": context.duplicate(true)
			}

		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return {
				"success": true,
				"ready": false,
				"pending": true,
				"reason": (
					"audio_stream_threaded_load_pending"
				),
				"stream_path": stream_path,
				"synchronous_load_performed": false,
				"context": context.duplicate(true)
			}

		ResourceLoader.THREAD_LOAD_LOADED:
			var stream:= (
				ResourceLoader.load_threaded_get(
					stream_path
				) as AudioStream
			)

			if stream == null:
				return {
					"success": false,
					"ready": false,
					"pending": false,
					"reason": (
						"audio_stream_threaded_result_missing"
					),
					"stream_path": stream_path,
					"context": context.duplicate(true)
				}

			precached_streams [
				stream_path
			] = stream

			return {
				"success": true,
				"ready": true,
				"pending": false,
				"reason": (
					"audio_stream_threaded_load_complete"
				),
				"stream_path": stream_path,
				"stream": stream,
				"synchronous_load_performed": false,
				"context": context.duplicate(true)
			}

		ResourceLoader.THREAD_LOAD_FAILED:
			return {
				"success": false,
				"ready": false,
				"pending": false,
				"reason": (
					"audio_stream_threaded_load_failed"
				),
				"stream_path": stream_path,
				"context": context.duplicate(true)
			}

	return {
		"success": false,
		"ready": false,
		"pending": false,
		"reason": "unknown_threaded_audio_status",
		"stream_path": stream_path,
		"load_status": int(load_status),
		"context": context.duplicate(true)
	}

func _remember_pending_audio_claim(
	contract: Dictionary,
	context: Dictionary,
	track_id: String,
	stream_path: String
) -> void:
	pending_audio_claim_sequence += 1

	pending_audio_claim = {
		"sequence": pending_audio_claim_sequence,
		"contract": contract.duplicate(true),
		"context": context.duplicate(true),
		"track_id": track_id,
		"stream_path": stream_path,
		"requested_at_ms": int(
			Time.get_ticks_msec()
		),
		"ready_gate_member": false,
	}

	set_process(true)


func _clear_pending_audio_claim(
	reason: String
) -> void:
	if pending_audio_claim.is_empty():
		return

	set_meta(
		"audio_pending_claim_cleared_reason",
		reason
	)
	set_meta(
		"audio_pending_claim_cleared_at_ms",
		int(
			Time.get_ticks_msec()
		)
	)

	pending_audio_claim = {}


func _process(_delta: float) -> void:
	if pending_audio_claim.is_empty():
		return

	var sequence: int = int(
		pending_audio_claim.get(
			"sequence",
			-1
		)
	)
	var stream_path: String = str(
		pending_audio_claim.get(
			"stream_path",
			""
		)
	).strip_edges()

	if stream_path == "":
		_clear_pending_audio_claim(
			"pending_audio_claim_missing_path"
		)
		return

	var validation: Dictionary = (
		_audio_import_payload_validation(
			stream_path
		)
	)

	if not bool(
		validation.get(
			"valid",
			false
		)
	):
		var validation_reason: String = str(
			validation.get(
				"reason",
				"pending_audio_import_invalid"
			)
		)

		_clear_pending_audio_claim(
			validation_reason
		)

		_report(
			false,
			validation_reason,
			{
				"stream_path": stream_path,
				"sequence": sequence,
				"path_validation": (
					validation.duplicate(true)
				),
				"pending": false
			}
		)
		return

	var load_status: ResourceLoader.ThreadLoadStatus = (
		ResourceLoader.load_threaded_get_status(
			stream_path
		)
	)

	if (
		load_status
		== ResourceLoader.THREAD_LOAD_IN_PROGRESS
	):
		return

	if (
		load_status
		== ResourceLoader.THREAD_LOAD_INVALID_RESOURCE
	):
		var request_error: Error = (
			ResourceLoader.load_threaded_request(
				stream_path,
				"AudioStream"
			)
		)

		if request_error != OK:
			_clear_pending_audio_claim(
				"pending_audio_reissue_failed"
			)

			_report(
				false,
				"pending_audio_reissue_failed",
				{
					"stream_path": stream_path,
					"request_error": request_error,
					"path_validation": (
						validation.duplicate(true)
					)
				}
			)

		return

	if (
		load_status
		== ResourceLoader.THREAD_LOAD_FAILED
	):
		_clear_pending_audio_claim(
			"pending_audio_load_failed"
		)

		_report(
			false,
			"pending_audio_load_failed",
			{
				"stream_path": stream_path,
				"sequence": sequence
			}
		)
		return

	if (
		load_status
		!= ResourceLoader.THREAD_LOAD_LOADED
	):
		return

	var stream:= (
		ResourceLoader.load_threaded_get(
			stream_path
		) as AudioStream
	)

	if stream == null:
		_clear_pending_audio_claim(
			"pending_audio_result_missing"
		)

		_report(
			false,
			"pending_audio_result_missing",
			{
				"stream_path": stream_path,
				"sequence": sequence
			}
		)
		return

	precached_streams [
		stream_path
	] = stream

	var claim: Dictionary = (
		pending_audio_claim.duplicate(true)
	)

	_clear_pending_audio_claim(
		"pending_audio_ready"
	)

	var contract_raw: Variant = claim.get(
		"contract",
		{}
	)
	var context_raw: Variant = claim.get(
		"context",
		{}
	)
	var resumed_contract: Dictionary = (
		(contract_raw as Dictionary).duplicate(true)
		if typeof(contract_raw) == TYPE_DICTIONARY
		else {}
	)
	var resumed_context: Dictionary = (
		(context_raw as Dictionary).duplicate(true)
		if typeof(context_raw) == TYPE_DICTIONARY
		else {}
	)

	resumed_context [
		"audio_pending_resume"
	] = true
	resumed_context [
		"audio_pending_sequence"
	] = sequence
	resumed_context [
		"synchronous_load_performed"
	] = false

	apply_audio_contract(
		resumed_contract,
		resumed_context
	)

func apply_audio_contract(
	contract: Dictionary,
	context: Dictionary
) -> Dictionary:
	if host_node == null:
		return _report(
			false,
			"missing_host_node",
			{
				"context": context.duplicate(true)
			}
		)

	if (
		primary_player == null
		or not is_instance_valid(primary_player)
		or secondary_player == null
		or not is_instance_valid(secondary_player)
	):
		bootstrap(host_node)

	if not bool(
		contract.get(
			"enabled",
			true
		)
	):
		_clear_pending_audio_claim(
			"audio_contract_disabled"
		)

		_fade_stop_all(
			int(
				context.get(
					"audio_fade_ms",
					contract.get(
						"fade_ms",
						650
					)
				)
			)
		)

		return _report(
			true,
			"audio_contract_disabled",
			{
				"audio_started": false,
				"pending": false,
				"context": context.duplicate(true)
			}
		)

	var resolved: Dictionary = (
		_resolve_track_for_context(
			contract,
			context
		)
	)

	if resolved.is_empty():
		_clear_pending_audio_claim(
			"no_audio_route_for_context"
		)

		if bool(
			contract.get(
				"silence_when_unmatched",
				true
			)
		):
			_fade_stop_all(
				int(
					context.get(
						"audio_fade_ms",
						contract.get(
							"fade_ms",
							650
						)
					)
				)
			)

		return _report(
			true,
			"no_audio_route_for_context",
			{
				"audio_started": false,
				"pending": false,
				"context": context.duplicate(true)
			}
		)

	var track_id: String = str(
		resolved.get(
			"track_id",
			""
		)
	).strip_edges()
	var track: Dictionary = (
		resolved.get(
			"track",
			{}
		).duplicate(true)
	)
	var declared_stream_path: String = str(
		track.get(
			"path",
			""
		)
	).strip_edges()

	if (
		track_id == ""
		or declared_stream_path == ""
	):
		return _report(
			false,
			"invalid_audio_track_contract",
			{
				"audio_started": false,
				"pending": false,
				"context": context.duplicate(true),
				"resolved": resolved.duplicate(true)
			}
		)

	var stream_path: String = (
		resolve_audio_stream_path(
			[
				declared_stream_path
			]
		)
	)

	if stream_path == "":
		return _report(
			false,
			"audio_stream_path_missing",
			{
				"track_id": track_id,
				"declared_stream_path": (
					declared_stream_path
				),
				"audio_started": false,
				"pending": false,
				"context": context.duplicate(true)
			}
		)

	var target_volume_db: float = float(
		context.get(
			"audio_volume_db",
			track.get(
				"volume_db",
				contract.get(
					"volume_db",
					-12.0
				)
			)
		)
	)
	var fade_ms: int = int(
		context.get(
			"audio_fade_ms",
			track.get(
				"fade_ms",
				contract.get(
					"fade_ms",
					900
				)
			)
		)
	)
	var restart_policy: String = str(
		context.get(
			"audio_restart_policy",
			""
		)
	).strip_edges().to_lower()
	var force_restart_audio: bool = bool(
		context.get(
			"force_restart_audio",
			context.get(
				"audio_force_restart",
				false
			)
		)
	)

	if restart_policy in [
		"force",
		"force_from_beginning",
		"restart",
		"restart_from_beginning",
		"force_from_random_position",
		"restart_from_random_position"
	]:
		force_restart_audio = true

	if (
		track_id == current_track_id
		and stream_path == current_stream_path
		and current_player != null
		and is_instance_valid(current_player)
		and current_player.playing
		and not force_restart_audio
	):
		_clear_pending_audio_claim(
			"audio_track_already_active"
		)

		var fade_active: bool = (
			fade_tween != null
			and fade_tween.is_valid()
		)

		current_player.process_mode = (
			Node.PROCESS_MODE_ALWAYS
		)
		current_player.stream_paused = false

		if not fade_active:
			current_player.volume_db = (
				target_volume_db
			)

		return _report(
			true,
			"audio_track_already_active",
			{
				"track_id": track_id,
				"stream_path": stream_path,
				"era_key": current_era_key,
				"context_key": current_context_key,
				"fade_active": fade_active,
				"audio_started": true,
				"pending": false,
				"context": context.duplicate(true)
			}
		)

	var stream_report: Dictionary = (
		request_audio_stream(
			[
				stream_path
			],
			{
				"source": (
					"EraAudioContractEngine."
					+ "apply_audio_contract"
				),
				"track_id": track_id,
				"context_key": str(
					context.get(
						"context_key",
						context.get(
							"surface_id",
							""
						)
					)
				)
			}
		)
	)

	if bool(
		stream_report.get(
			"pending",
			false
		)
	):
		_remember_pending_audio_claim(
			contract,
			context,
			track_id,
			stream_path
		)

		return _report(
			true,
			str(
				stream_report.get(
					"reason",
					"audio_stream_pending"
				)
			),
			{
				"track_id": track_id,
				"stream_path": stream_path,
				"pending": true,
				"audio_started": false,
				"synchronous_load_performed": false,
				"context": context.duplicate(true)
			}
		)

	if not bool(
		stream_report.get(
			"success",
			false
		)
	):
		return _report(
			false,
			str(
				stream_report.get(
					"reason",
					"audio_stream_load_failed"
				)
			),
			{
				"track_id": track_id,
				"stream_path": stream_path,
				"pending": false,
				"audio_started": false,
				"stream_report": (
					stream_report.duplicate(true)
				),
				"context": context.duplicate(true)
			}
		)

	var stream_raw: Variant = stream_report.get(
		"stream",
		null
	)

	if not (stream_raw is AudioStream):
		return _report(
			false,
			"audio_stream_result_invalid",
			{
				"track_id": track_id,
				"stream_path": stream_path,
				"pending": false,
				"audio_started": false,
				"context": context.duplicate(true)
			}
		)

	var stream: AudioStream = (
		stream_raw as AudioStream
	)

	_set_stream_loop_if_supported(
		stream,
		bool(
			track.get(
				"loop",
				true
			)
		)
	)

	precached_streams [
		stream_path
	] = stream

	var next_player: AudioStreamPlayer = (
		_standby_player()
	)

	if next_player == null:
		return _report(
			false,
			"audio_player_unavailable",
			{
				"track_id": track_id,
				"stream_path": stream_path,
				"pending": false,
				"audio_started": false,
				"context": context.duplicate(true)
			}
		)

	var start_position: float = (
		_resolve_audio_start_position(
			stream,
			track,
			context
		)
	)

	_clear_pending_audio_claim(
		"audio_track_starting"
	)

	next_player.process_mode = Node.PROCESS_MODE_ALWAYS
	next_player.stream_paused = false
	next_player.stop()
	next_player.stream = stream
	next_player.bus = str(
		track.get(
			"bus",
			contract.get(
				"bus",
				"Master"
			)
		)
	)
	next_player.volume_db = SILENT_DB
	next_player.pitch_scale = float(
		track.get(
			"pitch_scale",
			1.0
		)
	)
	next_player.play(start_position)

	current_track_id = track_id
	current_era_key = str(
		context.get(
			"era_key",
			""
		)
	).strip_edges()
	current_context_key = str(
		context.get(
			"context_key",
			context.get(
				"surface_id",
				""
			)
		)
	).strip_edges()
	current_stream_path = stream_path
	current_contract_signature = (
		_contract_signature(
			contract,
			context
		)
	)

	_crossfade_to(
		next_player,
		target_volume_db,
		fade_ms
	)

	return _report(
		true,
		"audio_track_started",
		{
			"track_id": track_id,
			"stream_path": stream_path,
			"declared_stream_path": (
				declared_stream_path
			),
			"era_key": current_era_key,
			"context_key": current_context_key,
			"fade_ms": fade_ms,
			"volume_db": target_volume_db,
			"start_position": start_position,
			"force_restart_audio": (
				force_restart_audio
			),
			"audio_restart_policy": (
				restart_policy
			),
			"audio_started": true,
			"pending": false,
			"synchronous_load_performed": false,
			"context": context.duplicate(true)
		}
	)
func precache_audio_contract(
		contract: Dictionary,
		context: Dictionary
) -> Dictionary:
	if host_node == null:
		return _report(
			false,
			"missing_host_node",
			{
				"precache_only": true,
				"context": context.duplicate(true)
			}
		)

	var resolved: Dictionary = _resolve_track_for_context(
		contract,
		context
	)

	if resolved.is_empty():
		return _report(
			true,
			"no_audio_route_for_precache_context",
			{
				"precache_only": true,
				"context": context.duplicate(true)
			}
		)

	var track_id: String = str(
		resolved.get(
			"track_id",
			""
		)
	).strip_edges()
	var track_raw: Variant = resolved.get(
		"track",
		{}
	)

	if typeof(
		track_raw
	) != TYPE_DICTIONARY:
		return _report(
			false,
			"invalid_audio_track_precache_payload",
			{
				"track_id": track_id,
				"track_payload_type": typeof(
					track_raw
				),
				"precache_only": true,
				"resolved": resolved.duplicate(true),
				"context": context.duplicate(true)
			}
		)

	var track: Dictionary = (
		(track_raw as Dictionary).duplicate(true)
	)
	var stream_path: String = str(
		track.get(
			"path",
			""
		)
	).strip_edges()

	if (
		track_id == ""
		or stream_path == ""
	):
		return _report(
			false,
			"invalid_audio_track_precache_contract",
			{
				"track_id": track_id,
				"stream_path": stream_path,
				"precache_only": true,
				"track": track.duplicate(true),
				"context": context.duplicate(true)
			}
		)

	if precached_streams.has(
		stream_path
	):
		var cached_raw: Variant = precached_streams.get(
			stream_path,
			null
		)

		if (
			cached_raw is AudioStream
			and is_instance_valid(
				cached_raw
			)
		):
			return _report(
				true,
				"audio_stream_already_precached",
				{
					"track_id": track_id,
					"stream_path": stream_path,
					"precache_only": true,
					"retained_stream_count": (
						precached_streams.size()
					),
					"context": context.duplicate(true)
				}
			)


		precached_streams.erase(
			stream_path
		)

	if not ResourceLoader.exists(
		stream_path
	):
		return _report(
			false,
			"audio_stream_path_missing",
			{
				"track_id": track_id,
				"stream_path": stream_path,
				"precache_only": true,
				"context": context.duplicate(true)
			}
		)

	var stream:= load(
		stream_path
	) as AudioStream

	if stream == null:
		return _report(
			false,
			"audio_stream_precache_failed",
			{
				"track_id": track_id,
				"stream_path": stream_path,
				"precache_only": true,
				"context": context.duplicate(true)
			}
		)

	_set_stream_loop_if_supported(
		stream,
		bool(
			track.get(
				"loop",
				true
			)
		)
	)

	precached_streams [
		stream_path
	] = stream

	return _report(
		true,
		"audio_stream_precached",
		{
			"track_id": track_id,
			"stream_path": stream_path,
			"precache_only": true,
			"retained_stream_count": (
				precached_streams.size()
			),
			"context": context.duplicate(true)
		}
	)
func hard_stop_all(
	reason: String = "hard_stop_all",
	context: Dictionary = {}
) -> Dictionary:
	_clear_pending_audio_claim(
		"%s_pending_claim_cancelled"
		% reason
	)

	if fade_tween != null:
		fade_tween.kill()
		fade_tween = null

	_stop_all_players()

	current_player = primary_player
	current_track_id = ""
	current_era_key = ""
	current_context_key = ""
	current_stream_path = ""
	current_contract_signature = ""

	return _report(
		true,
		reason,
		{
			"hard_stop": true,
			"context": context.duplicate(true)
		}
	)

func release_audio_contract(reason: String = "release", fade_ms: int = 650, context: Dictionary = {}) -> Dictionary:
	_fade_stop_all(fade_ms)

	return _report(true, reason, {
		"fade_ms": fade_ms,
		"context": context.duplicate(true)
	})
func _ensure_audio_player(
	player_name: String
) -> AudioStreamPlayer:
	var existing:= (
		get_node_or_null(
			player_name
		) as AudioStreamPlayer
	)

	if existing != null:
		existing.process_mode = Node.PROCESS_MODE_ALWAYS
		existing.stream_paused = false
		existing.autoplay = false

		if str(existing.bus).strip_edges() == "":
			existing.bus = "Master"

		return existing

	var player:= AudioStreamPlayer.new()
	player.name = player_name
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.stream_paused = false
	player.autoplay = false
	player.bus = "Master"
	player.volume_db = SILENT_DB

	add_child(player)

	return player

func _standby_player() -> AudioStreamPlayer:
	if primary_player == null or not is_instance_valid(primary_player):
		primary_player = _ensure_audio_player("EraAudioPrimary")

	if secondary_player == null or not is_instance_valid(secondary_player):
		secondary_player = _ensure_audio_player("EraAudioSecondary")

	if current_player == primary_player:
		return secondary_player

	return primary_player


func _resolve_track_for_context(contract: Dictionary, context: Dictionary) -> Dictionary:
	var era_key: String = str(context.get("era_key", "")).to_lower().strip_edges()
	var era_name: String = str(context.get("era_name", "")).to_lower().strip_edges()
	var context_key: String = str(context.get("context_key", "")).to_lower().strip_edges()
	var context_name: String = str(context.get("context_name", "")).to_lower().strip_edges()
	var surface_id: String = str(context.get("surface_id", "")).to_lower().strip_edges()
	var panel_id: String = str(context.get("panel_id", "")).to_lower().strip_edges()

	var tracks_raw: Variant = contract.get("tracks", {})
	var tracks: Dictionary = tracks_raw if typeof(tracks_raw) == TYPE_DICTIONARY else {}

	var context_routes_raw: Variant = contract.get("context_routes", {})
	var context_routes: Dictionary = context_routes_raw if typeof(context_routes_raw) == TYPE_DICTIONARY else {}

	var presentation_routes_raw: Variant = contract.get("presentation_routes", {})
	var presentation_routes: Dictionary = presentation_routes_raw if typeof(presentation_routes_raw) == TYPE_DICTIONARY else {}

	var normalized_context_keys: Array = []
	for raw_context_key in [context_key, context_name, surface_id, panel_id]:
		var clean_context_key: String = str(raw_context_key).to_lower().strip_edges()
		if clean_context_key != "" and not normalized_context_keys.has(clean_context_key):
			normalized_context_keys.append(clean_context_key)

	for route_key in normalized_context_keys:
		if context_routes.has(route_key):
			return _track_result(str(context_routes.get(route_key, "")), tracks)

		if presentation_routes.has(route_key):
			return _track_result(str(presentation_routes.get(route_key, "")), tracks)

	var routes_raw: Variant = contract.get("era_routes", {})
	var routes: Dictionary = routes_raw if typeof(routes_raw) == TYPE_DICTIONARY else {}

	if routes.has(era_key):
		return _track_result(str(routes.get(era_key, "")), tracks)

	if era_name != "" and routes.has(era_name):
		return _track_result(str(routes.get(era_name, "")), tracks)

	for raw_track_id in tracks.keys():
		var track_id: String = str(raw_track_id)
		var track_raw: Variant = tracks.get(raw_track_id, {})
		if typeof(track_raw) != TYPE_DICTIONARY:
			continue

		var track: Dictionary = (track_raw as Dictionary).duplicate(true)
		var context_keys: Array = _normalize_string_array(track.get("context_keys", []))

		for raw_track_context_key in context_keys:
			var context_candidate: String = str(raw_track_context_key).to_lower().strip_edges()
			if normalized_context_keys.has(context_candidate):
				return {
					"track_id": track_id,
					"track": track
				}

		var era_keys: Array = _normalize_string_array(track.get("era_keys", []))

		for raw_era_key in era_keys:
			var candidate: String = str(raw_era_key).to_lower().strip_edges()
			if candidate == era_key or candidate == era_name:
				return {
					"track_id": track_id,
					"track": track
				}

	var default_track_id: String = str(contract.get("default_track_id", "")).strip_edges()
	if default_track_id != "":
		return _track_result(default_track_id, tracks)

	return {}
func _track_result(track_id: String, tracks: Dictionary) -> Dictionary:
	track_id = track_id.strip_edges()
	if track_id == "":
		return {}

	if not tracks.has(track_id):
		return {}

	var track_raw: Variant = tracks.get(track_id, {})
	if typeof(track_raw) != TYPE_DICTIONARY:
		return {}

	return {
		"track_id": track_id,
		"track": (track_raw as Dictionary).duplicate(true)
	}


func _normalize_string_array(value: Variant) -> Array:
	var out: Array = []

	if typeof(value) == TYPE_ARRAY:
		for item in value:
			var text: String = str(item).strip_edges()
			if text != "":
				out.append(text)
		return out

	var text_value: String = str(value).strip_edges()
	if text_value != "":
		out.append(text_value)

	return out


func _set_stream_loop_if_supported(stream: AudioStream, should_loop: bool) -> void:
	if stream == null:
		return

	for property_info in stream.get_property_list():
		if typeof(property_info) != TYPE_DICTIONARY:
			continue

		if str(property_info.get("name", "")) == "loop":
			stream.set("loop", should_loop)
			return
func _audio_import_payload_validation(
	stream_path: String
) -> Dictionary:
	var clean_path: String = str(
		stream_path
	).strip_edges()

	if clean_path == "":
		return {
			"valid": false,
			"reason": "audio_stream_path_empty",
			"stream_path": ""
		}

	var import_sidecar_path: String = (
		"%s.import" % clean_path
	)

	var resource_loader_resident: bool = (
		ResourceLoader.exists(
			clean_path
		)
	)





	if resource_loader_resident:
		return {
			"valid": true,
			"reason": "audio_resource_loader_authoritative",
			"stream_path": clean_path,
			"import_sidecar_path": import_sidecar_path,
		}



	if not FileAccess.file_exists(
		import_sidecar_path
	):
		return {
			"valid": false,
			"reason": "audio_stream_path_missing",
			"stream_path": clean_path,
			"import_sidecar_path": import_sidecar_path,
		}

	var import_config:= ConfigFile.new()
	var import_error: Error = import_config.load(
		import_sidecar_path
	)

	if import_error != OK:
		return {
			"valid": false,
			"reason": "audio_import_sidecar_unreadable",
			"stream_path": clean_path,
			"import_sidecar_path": import_sidecar_path,
			"import_error": int(import_error),
		}

	var declared_payload_paths: Array = []

	for raw_key in import_config.get_section_keys(
		"remap"
	):
		var key: String = str(
			raw_key
		).strip_edges()

		if (
			key != "path"
			and not key.begins_with(
				"path."
			)
		):
			continue

		var payload_path: String = str(
			import_config.get_value(
				"remap",
				key,
				""
			)
		).strip_edges()

		if (
			payload_path != ""
			and payload_path not in declared_payload_paths
		):
			declared_payload_paths.append(
				payload_path
			)

	var dest_files_raw: Variant = import_config.get_value(
		"deps",
		"dest_files",
		[]
	)

	if typeof(dest_files_raw) == TYPE_ARRAY:
		for raw_payload_path in dest_files_raw as Array:
			var payload_path: String = str(
				raw_payload_path
			).strip_edges()

			if (
				payload_path != ""
				and payload_path not in declared_payload_paths
			):
				declared_payload_paths.append(
					payload_path
				)
	elif typeof(dest_files_raw) == TYPE_PACKED_STRING_ARRAY:
		for raw_payload_path in dest_files_raw as PackedStringArray:
			var payload_path: String = str(
				raw_payload_path
			).strip_edges()

			if (
				payload_path != ""
				and payload_path not in declared_payload_paths
			):
				declared_payload_paths.append(
					payload_path
				)

	if declared_payload_paths.is_empty():
		return {
			"valid": false,
			"reason": "audio_import_payload_not_declared",
			"stream_path": clean_path,
			"import_sidecar_path": import_sidecar_path,
		}

	var existing_payload_paths: Array = []
	var missing_payload_paths: Array = []

	for raw_payload_path in declared_payload_paths:
		var payload_path: String = str(
			raw_payload_path
		).strip_edges()

		if FileAccess.file_exists(
			payload_path
		):
			existing_payload_paths.append(
				payload_path
			)
		else:
			missing_payload_paths.append(
				payload_path
			)

	if existing_payload_paths.is_empty():
		return {
			"valid": false,
			"reason": "audio_import_payload_missing",
			"stream_path": clean_path,
			"import_sidecar_path": import_sidecar_path,
			"declared_payload_paths": (
				declared_payload_paths.duplicate()
			),
			"missing_payload_paths": (
				missing_payload_paths.duplicate()
			),
		}

	return {
		"valid": false,
		"reason": "audio_resource_loader_path_unavailable",
		"stream_path": clean_path,
		"import_sidecar_path": import_sidecar_path,
		"declared_payload_paths": (
			declared_payload_paths.duplicate()
		),
		"existing_payload_paths": (
			existing_payload_paths.duplicate()
		),
		"missing_payload_paths": (
			missing_payload_paths.duplicate()
		),
	}
func _resolve_audio_start_position(stream: AudioStream, track: Dictionary, context: Dictionary) -> float:
	if stream == null:
		return 0.0

	var stream_length: float = float(stream.get_length())
	if stream_length <= 0.25:
		return 0.0

	var explicit_position: float = float(context.get("audio_start_position", context.get("audio_start_position_seconds", track.get("start_position", 0.0))))
	if explicit_position > 0.0:
		return clamp(explicit_position, 0.0, max(0.0, stream_length - 0.15))

	var random_start: bool = bool(context.get("audio_random_start_position", track.get("random_start_position", false)))
	if not random_start:
		return 0.0

	var seed_text: String = "%s|%s|%s|%s|audio_random_start" % [
		str(context.get("store_id", "")),
		str(context.get("track_id", "")),
		str(context.get("reason", "")),
		str(Time.get_ticks_msec())
	]
	var seed_value: int = int(hash(seed_text))
	if seed_value < 0:
		seed_value = - seed_value
	if seed_value <= 0:
		seed_value = 1

	var rng:= RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng.randf_range(0.0, max(0.0, stream_length - 0.35))
func _crossfade_to(
	next_player: AudioStreamPlayer,
	target_volume_db: float,
	fade_ms: int
) -> void:
	if (
		next_player == null
		or not is_instance_valid(next_player)
	):
		return

	next_player.process_mode = Node.PROCESS_MODE_ALWAYS
	next_player.stream_paused = false

	if fade_tween != null:
		fade_tween.kill()
		fade_tween = null

	var old_player: AudioStreamPlayer = current_player
	current_player = next_player

	var duration: float = max(
		0.01,
		float(
			max(
				0,
				fade_ms
			)
		) / 1000.0
	)

	fade_tween = create_tween()
	fade_tween.tween_property(
		next_player,
		"volume_db",
		target_volume_db,
		duration
	)

	if (
		old_player != null
		and is_instance_valid(old_player)
		and old_player != next_player
		and old_player.playing
	):
		old_player.process_mode = (
			Node.PROCESS_MODE_ALWAYS
		)
		old_player.stream_paused = false

		fade_tween.parallel().tween_property(
			old_player,
			"volume_db",
			SILENT_DB,
			duration
		)

	fade_tween.tween_callback(
		Callable(
			self,
			"_stop_silent_players"
		)
	)

func _fade_stop_all(fade_ms: int = 650) -> void:
	if fade_tween != null:
		fade_tween.kill()
		fade_tween = null

	var players_to_fade: Array = []

	for player in [primary_player, secondary_player]:
		if player == null or not is_instance_valid(player):
			continue

		if not player.playing:
			player.volume_db = SILENT_DB
			continue

		players_to_fade.append(player)

	if players_to_fade.is_empty():
		_stop_all_players()
		current_track_id = ""
		current_era_key = ""
		current_context_key = ""
		current_stream_path = ""
		current_contract_signature = ""
		return

	var duration: float = max(0.01, float(max(0, fade_ms)) / 1000.0)
	fade_tween = create_tween()

	for i in range(players_to_fade.size()):
		var player: AudioStreamPlayer = players_to_fade [i]
		if player == null or not is_instance_valid(player):
			continue

		if i == 0:
			fade_tween.tween_property(player, "volume_db", SILENT_DB, duration)
		else:
			fade_tween.parallel().tween_property(player, "volume_db", SILENT_DB, duration)

	fade_tween.tween_callback(Callable(self, "_stop_all_players"))

	current_track_id = ""
	current_era_key = ""
	current_context_key = ""
	current_stream_path = ""
	current_contract_signature = ""

func _stop_silent_players() -> void:
	for player in [primary_player, secondary_player]:
		if player == null or not is_instance_valid(player):
			continue

		if player != current_player and player.volume_db <= SILENT_DB + 1.0:
			player.stop()


func _stop_all_players() -> void:
	for player in [primary_player, secondary_player]:
		if player == null or not is_instance_valid(player):
			continue

		player.stop()
		player.volume_db = SILENT_DB


func _contract_signature(contract: Dictionary, context: Dictionary) -> String:
	return "%s|%s|%s|%s|%s|%s|%s|%s" % [
		str(contract.get("schema", CONTRACT_SCHEMA)),
		str(contract.get("version", CONTRACT_VERSION)),
		str(context.get("context_key", "")),
		str(context.get("surface_id", "")),
		str(context.get("panel_id", "")),
		str(context.get("era_key", "")),
		str(context.get("era_name", "")),
		str(context.get("year", ""))
	]

func _report(success: bool, reason: String, payload: Dictionary = {}) -> Dictionary:
	var report: Dictionary = payload.duplicate(true)
	report ["success"] = success
	report ["reason"] = reason
	report ["schema"] = CONTRACT_SCHEMA
	report ["version"] = CONTRACT_VERSION
	report ["created_at_ms"] = int(Time.get_ticks_msec())

	last_report = report.duplicate(true)
	return report