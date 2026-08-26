extends Resource
class_name Compression

const ENGINE_SCHEMA:= "eralife.profile_photo_compression"
const CONTRACT_VERSION:= 1

const MAX_PROFILE_DIMENSION:= 512
const DEFAULT_JPEG_QUALITY:= 0.82

var gs
var last_report: Dictionary = {}


func _init(_gs = null) -> void:
	gs = _gs
	_ensure_directories()


func compress_profile_photo(
	source_path: String,
	identity_id: String,
	context: Dictionary = {}
) -> Dictionary:
	var clean_source_path: String = str(
		source_path
	).strip_edges()
	var clean_identity_id: String = str(
		identity_id
	).strip_edges()

	if clean_source_path == "":
		return _fail(
			"source_path_missing",
			"No profile image was selected.",
			context
		)

	if clean_identity_id == "":
		return _fail(
			"identity_id_missing",
			"A profile image requires an ErAccount ID.",
			context
		)

	if not FileAccess.file_exists(clean_source_path):
		return _fail(
			"source_file_missing",
			"The selected profile image could not be found.",
			context
		)

	var image: Image = Image.load_from_file(
		clean_source_path
	)

	if (
		image == null
		or image.is_empty()
	):
		return _fail(
			"image_decode_failed",
			"The selected file is not a readable image.",
			context
		)

	var original_width: int = image.get_width()
	var original_height: int = image.get_height()

	if (
		original_width <= 0
		or original_height <= 0
	):
		return _fail(
			"image_dimensions_invalid",
			"The selected image has invalid dimensions.",
			context
		)

	var largest_dimension: int = maxi(
		original_width,
		original_height
	)

	if largest_dimension > MAX_PROFILE_DIMENSION:
		var ratio: float = (
			float(MAX_PROFILE_DIMENSION)
			/ float(largest_dimension)
		)
		var resized_width: int = maxi(
			1,
			int(
				round(
					float(original_width)
					* ratio
				)
			)
		)
		var resized_height: int = maxi(
			1,
			int(
				round(
					float(original_height)
					* ratio
				)
			)
		)

		image.resize(
			resized_width,
			resized_height,
			Image.INTERPOLATE_LANCZOS
		)

	_ensure_directories()

	var target_path: String = (
		"user://identity/profile_photos/%s.jpg"
		% _safe_file_component(
			clean_identity_id
		)
	)
	var save_error: Error = image.save_jpg(
		target_path,
		DEFAULT_JPEG_QUALITY
	)

	if save_error != OK:
		return _fail(
			"image_write_failed",
			"The compressed profile photo could not be written.",
			{
				"save_error": int(save_error),
				"target_path": target_path,
				"context": context.duplicate(true)
			}
		)

	var compressed_bytes: PackedByteArray = (
		FileAccess.get_file_as_bytes(
			target_path
		)
	)
	var photo_contract: Dictionary = {
		"schema": (
			"eralife.profile_photo.asset_contract"
		),
		"version": CONTRACT_VERSION,
		"identity_id": clean_identity_id,
		"local_path": target_path,
		"mime_type": "image/jpeg",
		"width": image.get_width(),
		"height": image.get_height(),
		"original_width": original_width,
		"original_height": original_height,
		"compressed_size_bytes": compressed_bytes.size(),
		"content_hash": "profile_photo_%d" % abs(
			hash(compressed_bytes)
		),
		"maximum_dimension": MAX_PROFILE_DIMENSION,
		"quality": DEFAULT_JPEG_QUALITY,
		"ui_is_renderer_only": true,
		"created_at_ms": _now_ms()
	}

	last_report = {
		"schema": (
			"eralife.profile_photo.compression_report"
		),
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": "profile_photo_compressed",
		"message": "Profile photo updated.",
		"photo_contract": photo_contract.duplicate(true),
		"context": context.duplicate(true),
		"created_at_ms": _now_ms()
	}

	return last_report.duplicate(true)


func route_command_envelope(
	envelope: Dictionary
) -> Dictionary:
	var command_id: String = str(
		envelope.get(
			"command",
			envelope.get(
				"action_id",
				""
			)
		)
	).strip_edges().to_lower()

	if command_id == "compression.profile_photo":
		return compress_profile_photo(
			str(envelope.get("source_path", "")),
			str(envelope.get("identity_id", "")),
			envelope
		)

	return _fail(
		"unknown_compression_command",
		"Compression did not recognize command.",
		envelope
	)


func _ensure_directories() -> void:
	var root:= DirAccess.open("user://")

	if root == null:
		return

	if not root.dir_exists("identity"):
		root.make_dir("identity")

	var identity_dir:= DirAccess.open(
		"user://identity"
	)

	if (
		identity_dir != null
		and not identity_dir.dir_exists(
			"profile_photos"
		)
	):
		identity_dir.make_dir(
			"profile_photos"
		)


func _safe_file_component(
	value: String
) -> String:
	var out: String = ""

	for i in range(value.length()):
		var character: String = value.substr(
			i,
			1
		)

		if (
			character.is_valid_identifier()
			or character.is_valid_int()
			or character in ["_", "-"]
		):
			out += character
		else:
			out += "_"

	if out == "":
		return "unknown_identity"

	return out


func _now_ms() -> int:
	return int(
		Time.get_unix_time_from_system()
		* 1000.0
	)


func _fail(
	reason_id: String,
	message: String,
	context: Dictionary = {}
) -> Dictionary:
	EraLog.failure(
		get_script().resource_path.get_file(),
		str(reason_id)
	)
	last_report = {
		"schema": "eralife.profile_photo.error",
		"version": CONTRACT_VERSION,
		"success": false,
		"reason_id": reason_id,
		"reason": message,
		"message": message,
		"context": context.duplicate(true),
		"created_at_ms": _now_ms()
	}
	return last_report.duplicate(true)