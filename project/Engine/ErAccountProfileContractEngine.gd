extends Resource
class_name ErAccountProfileContractEngine

const ENGINE_SCHEMA:= "eralife.eraccount_profile"
const CONTRACT_VERSION:= 1

const PROFILE_REGISTRY_PATH:= (
	"user://identity/eraccount_profile_registry.json"
)
const ACCOUNT_REGISTRY_PATH:= (
	"user://identity/account_registry.json"
)

const DISPLAY_NAME_WINDOW_MS:= 604800000
const DISPLAY_NAME_WINDOW_LIMIT:= 2
const DISPLAY_NAME_MAX_LENGTH:= 32
const BIO_MAX_LENGTH:= 190

var gs
var profile_registry: Dictionary = {}
var last_report: Dictionary = {}


func _init(_gs = null) -> void:
	gs = _gs
	_ensure_state()


func emit_profile(
	target_username: String = "",
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	var identity_context: Dictionary = _identity_context()
	var viewer_username: String = str(
		identity_context.get(
			"account_username",
			""
		)
	).strip_edges()
	var resolved_target_username: String = str(
		target_username
	).strip_edges()

	if resolved_target_username == "":
		resolved_target_username = viewer_username

	var target_account: Dictionary = _account_for_username(
		resolved_target_username
	)

	if target_account.is_empty():
		return _fail(
			"profile_account_missing",
			"That ErAccount profile could not be found.",
			context
		)

	var viewer_account: Dictionary = _account_for_username(
		viewer_username
	)
	var target_identity_id: String = _account_identity_id(
		target_account
	)
	var viewer_identity_id: String = _account_identity_id(
		viewer_account
	)
	var is_self: bool = (
		target_identity_id != ""
		and target_identity_id == viewer_identity_id
	)
	var connected: bool = (
		is_self
		or _are_connected(
			target_identity_id,
			viewer_identity_id
		)
	)

	var profile: Dictionary = _profile_for_account(
		target_account
	)
	var permissions: Dictionary = _safe_dictionary(
		profile.get(
			"permissions",
			{}
		)
	)
	var profile_visibility: String = str(
		permissions.get(
			"public_profile",
			"everyone"
		)
	).to_lower()

	var full_profile_visible: bool = is_self

	if profile_visibility == "everyone":
		full_profile_visible = true
	elif (
		profile_visibility == "connections"
		and connected
	):
		full_profile_visible = true

	var simulation_identity: Dictionary = _safe_dictionary(
		profile.get(
			"simulation_identity",
			{}
		)
	)
	var realities_created: int = int(
		simulation_identity.get(
			"realities_created",
			0
		)
	)
	var total_lives: int = int(
		simulation_identity.get(
			"total_lives",
			0
		)
	)
	var favorite_era: String = _favorite_key(
		_safe_dictionary(
			simulation_identity.get(
				"era_counts",
				{}
			)
		)
	)
	var favorite_mode: String = _favorite_key(
		_safe_dictionary(
			simulation_identity.get(
				"reality_mode_counts",
				{}
			)
		)
	)
	var current_public_reality: Dictionary = (
		_safe_dictionary(
			simulation_identity.get(
				"current_public_reality",
				{}
			)
		)
	)

	var now_ms: int = _now_ms()
	var display_history: Array = _trim_history(
		_safe_array(
			profile.get(
				"display_name_change_history_ms",
				[]
			)
		),
		DISPLAY_NAME_WINDOW_MS,
		now_ms
	)

	profile ["display_name_change_history_ms"] = (
		display_history
	)
	_store_profile(profile)

	var profile_contract: Dictionary = {
		"schema": "eralife.eraccount.profile_contract",
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": "profile_emitted",
		"eraccount_id": target_identity_id,
		"identity_id": target_identity_id,
		"username": str(
			target_account.get(
				"username",
				resolved_target_username
			)
		),
		"display_name": str(
			profile.get(
				"display_name",
				target_account.get(
					"username",
					resolved_target_username
				)
			)
		),
		"bio": (
			str(profile.get("bio", ""))
			if full_profile_visible
			else ""
		),
		"joined_year": int(
			profile.get(
				"joined_year",
				_current_real_year()
			)
		),
		"profile_photo": _safe_dictionary(
			profile.get(
				"profile_photo",
				{}
			)
		),
		"permissions": (
			permissions.duplicate(true)
			if is_self
			else _public_permissions_projection(
				permissions
			)
		),
		"simulation_identity": (
			simulation_identity.duplicate(true)
			if full_profile_visible
			else {}
		),
		"realities_created": realities_created,
		"realities_created_label": (
			str(realities_created)
			if realities_created > 0
			else "None yet"
		),
		"total_lives": total_lives,
		"total_lives_label": (
			str(total_lives)
			if total_lives > 0
			else "None yet"
		),
		"favorite_era": (
			favorite_era
			if favorite_era != ""
			else "None yet"
		),
		"favorite_reality_mode": (
			favorite_mode
			if favorite_mode != ""
			else "None yet"
		),
		"current_public_reality": (
			current_public_reality
		),
		"current_public_reality_label": (
			str(
				current_public_reality.get(
					"title",
					current_public_reality.get(
						"era_name",
						""
					)
				)
			)
			if not current_public_reality.is_empty()
			else "None yet"
		),
		"is_self": is_self,
		"is_connection": connected,
		"full_profile_visible": (
			full_profile_visible
		),
		"can_edit": is_self,
		"change_limits": {
			"display_name": {
				"maximum": DISPLAY_NAME_WINDOW_LIMIT,
				"remaining": maxi(
					0,
					DISPLAY_NAME_WINDOW_LIMIT
					- display_history.size()
				),
				"window_days": 7
			},
			"username": {
				"maximum": 2,
				"window_days": 14,
				"authority": "IdentityContractEngine"
			}
		},
		"context": context.duplicate(true),
		"created_at_ms": now_ms,
		"contract_mesh": {
			"source_of_truth": (
				"ErAccountProfileContractEngine"
			),
			"account_identity_authority": (
				"IdentityContractEngine"
			),
			"photo_authority": "Compression",
			"ui_mutation_allowed": false
		}
	}

	last_report = profile_contract.duplicate(true)
	_commit_state()
	return profile_contract


func emit_profile_by_identity(
	identity_id: String,
	context: Dictionary = {}
) -> Dictionary:
	var account: Dictionary = _account_for_identity(
		identity_id
	)

	if account.is_empty():
		return _fail(
			"profile_identity_missing",
			"That ErAccount ID could not be found.",
			context
		)

	return emit_profile(
		str(account.get("username", "")),
		context
	)


func update_own_profile(
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	var identity_context: Dictionary = _identity_context()

	if bool(identity_context.get("is_guest", true)):
		return _fail(
			"account_required",
			"Sign into an ErAccount to edit your profile.",
			context
		)

	var username: String = str(
		identity_context.get(
			"account_username",
			""
		)
	).strip_edges()
	var account: Dictionary = _account_for_username(
		username
	)
	var profile: Dictionary = _profile_for_account(
		account
	)
	var now_ms: int = _now_ms()

	if context.has("display_name"):
		var new_display_name: String = str(
			context.get(
				"display_name",
				""
			)
		).strip_edges()

		if new_display_name == "":
			return _fail(
				"display_name_missing",
				"Display name cannot be empty.",
				context
			)

		if (
			new_display_name.length()
			> DISPLAY_NAME_MAX_LENGTH
		):
			return _fail(
				"display_name_too_long",
				"Display names are limited to %d characters."
				% DISPLAY_NAME_MAX_LENGTH,
				context
			)

		var old_display_name: String = str(
			profile.get(
				"display_name",
				username
			)
		)

		if new_display_name != old_display_name:
			var display_history: Array = _trim_history(
				_safe_array(
					profile.get(
						"display_name_change_history_ms",
						[]
					)
				),
				DISPLAY_NAME_WINDOW_MS,
				now_ms
			)

			if (
				display_history.size()
				>= DISPLAY_NAME_WINDOW_LIMIT
			):
				return _fail(
					"display_name_rate_limited",
					"You have used both display-name changes for this week.",
					{
						"remaining": 0,
						"window_days": 7,
						"context": context.duplicate(true)
					}
				)

			display_history.append(now_ms)
			profile [
				"display_name_change_history_ms"
			] = display_history
			profile ["display_name"] = (
				new_display_name
			)

	if context.has("bio"):
		var bio: String = str(
			context.get(
				"bio",
				""
			)
		).strip_edges()

		if bio.length() > BIO_MAX_LENGTH:
			bio = bio.substr(
				0,
				BIO_MAX_LENGTH
			)

		profile ["bio"] = bio

	if (
		context.has("permissions")
		and typeof(
			context.get(
				"permissions",
				{}
			)
		) == TYPE_DICTIONARY
	):
		var permissions: Dictionary = _safe_dictionary(
			profile.get(
				"permissions",
				_default_permissions()
			)
		)
		var incoming_permissions: Dictionary = (
			_safe_dictionary(
				context.get(
					"permissions",
					{}
				)
			)
		)

		for permission_key in [
			"messages",
			"connection_requests",
			"public_profile",
			"life_visibility",
			"milestone_visibility",
			"public_feed_visibility",
			"notes_visibility"
		]:
			if incoming_permissions.has(
				permission_key
			):
				permissions [permission_key] = str(
					incoming_permissions.get(
						permission_key,
						permissions.get(
							permission_key,
							"connections"
						)
					)
				).to_lower()

		if incoming_permissions.has(
			"notifications_enabled"
		):
			permissions [
				"notifications_enabled"
			] = bool(
				incoming_permissions.get(
					"notifications_enabled",
					true
				)
			)

		profile ["permissions"] = permissions

	profile ["updated_at_ms"] = now_ms
	_store_profile(profile)

	var report: Dictionary = emit_profile(
		username,
		{
			"source": "profile_update"
		}
	)
	report ["mode"] = "profile_updated"
	report ["message"] = "ErAccount profile updated."
	last_report = report.duplicate(true)
	return report


func upload_own_profile_photo(
	source_path: String,
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	var identity_context: Dictionary = _identity_context()

	if bool(identity_context.get("is_guest", true)):
		return _fail(
			"account_required",
			"Sign into an ErAccount to upload a profile photo.",
			context
		)

	var identity_id: String = str(
		identity_context.get(
			"cloud_identity_id",
			identity_context.get(
				"identity_id",
				""
			)
		)
	).strip_edges()

	if gs == null:
		return _fail(
			"compression_unavailable",
			"Profile-photo compression is unavailable.",
			context
		)

	if (
		"compression" in gs
		and gs.compression == null
	):
		gs.compression = Compression.new(gs)

	if (
		not ("compression" in gs)
		or gs.compression == null
		or not gs.compression.has_method(
			"compress_profile_photo"
		)
	):
		return _fail(
			"compression_unavailable",
			"Profile-photo compression is unavailable.",
			context
		)

	var compression_report: Dictionary = (
		gs.compression.compress_profile_photo(
			source_path,
			identity_id,
			context
		)
	)

	if not bool(
		compression_report.get(
			"success",
			false
		)
	):
		return compression_report

	var username: String = str(
		identity_context.get(
			"account_username",
			""
		)
	)
	var account: Dictionary = _account_for_username(
		username
	)
	var profile: Dictionary = _profile_for_account(
		account
	)
	profile ["profile_photo"] = _safe_dictionary(
		compression_report.get(
			"photo_contract",
			{}
		)
	)
	profile ["updated_at_ms"] = _now_ms()
	_store_profile(profile)

	var report: Dictionary = emit_profile(
		username,
		{
			"source": "profile_photo_upload"
		}
	)
	report ["mode"] = "profile_photo_updated"
	report ["message"] = "Profile photo updated."
	report ["compression_report"] = (
		compression_report.duplicate(true)
	)
	return report


func record_life_started(
	life_id: String,
	era_name: String,
	reality_mode: String,
	public_reality: Dictionary = {},
	context: Dictionary = {}
) -> Dictionary:
	var profile: Dictionary = _current_profile()

	if profile.is_empty():
		return {
			"success": false,
			"mode": "guest_life_not_profiled"
		}

	var simulation_identity: Dictionary = _safe_dictionary(
		profile.get(
			"simulation_identity",
			{}
		)
	)
	var known_life_ids: Array = _safe_array(
		simulation_identity.get(
			"known_life_ids",
			[]
		)
	)
	var clean_life_id: String = str(
		life_id
	).strip_edges()

	if (
		clean_life_id != ""
		and not known_life_ids.has(
			clean_life_id
		)
	):
		known_life_ids.append(clean_life_id)
		simulation_identity [
			"realities_created"
		] = int(
			simulation_identity.get(
				"realities_created",
				0
			)
		) + 1

	simulation_identity ["known_life_ids"] = (
		known_life_ids
	)
	simulation_identity ["lives_started"] = int(
		simulation_identity.get(
			"lives_started",
			0
		)
	) + 1

	_increment_counter(
		simulation_identity,
		"era_counts",
		str(era_name).strip_edges()
	)
	_increment_counter(
		simulation_identity,
		"reality_mode_counts",
		str(reality_mode).strip_edges()
	)

	if not public_reality.is_empty():
		simulation_identity [
			"current_public_reality"
		] = public_reality.duplicate(true)

	profile ["simulation_identity"] = (
		simulation_identity
	)
	profile ["updated_at_ms"] = _now_ms()
	_store_profile(profile)

	return {
		"success": true,
		"mode": "profile_life_started_recorded",
		"life_id": clean_life_id,
		"era_name": era_name,
		"reality_mode": reality_mode,
		"context": context.duplicate(true)
	}


func record_controlled_life_death(
	context: Dictionary = {}
) -> Dictionary:
	var profile: Dictionary = _current_profile()

	if profile.is_empty():
		return {
			"success": false,
			"mode": "guest_death_not_profiled"
		}

	var simulation_identity: Dictionary = _safe_dictionary(
		profile.get(
			"simulation_identity",
			{}
		)
	)
	simulation_identity ["total_lives"] = int(
		simulation_identity.get(
			"total_lives",
			0
		)
	) + 1
	simulation_identity [
		"current_public_reality"
	] = {}

	profile ["simulation_identity"] = (
		simulation_identity
	)
	profile ["updated_at_ms"] = _now_ms()
	_store_profile(profile)

	return {
		"success": true,
		"mode": "controlled_life_death_recorded",
		"total_lives": int(
			simulation_identity.get(
				"total_lives",
				0
			)
		),
		"context": context.duplicate(true)
	}


func record_reality_published(
	reality_contract: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	var profile: Dictionary = _current_profile()

	if profile.is_empty():
		return {
			"success": false,
			"mode": "guest_reality_not_profiled"
		}

	var simulation_identity: Dictionary = _safe_dictionary(
		profile.get(
			"simulation_identity",
			{}
		)
	)
	simulation_identity [
		"current_public_reality"
	] = reality_contract.duplicate(true)
	profile ["simulation_identity"] = (
		simulation_identity
	)
	profile ["updated_at_ms"] = _now_ms()
	_store_profile(profile)

	return {
		"success": true,
		"mode": "public_reality_recorded",
		"public_reality": reality_contract.duplicate(true),
		"context": context.duplicate(true)
	}


func permission_for_identity(
	identity_id: String,
	permission_key: String,
	fallback = null
):
	var account: Dictionary = _account_for_identity(
		identity_id
	)

	if account.is_empty():
		return fallback

	var profile: Dictionary = _profile_for_account(
		account
	)
	var permissions: Dictionary = _safe_dictionary(
		profile.get(
			"permissions",
			{}
		)
	)

	return permissions.get(
		permission_key,
		fallback
	)


func notifications_enabled_for_identity(
	identity_id: String
) -> bool:
	return bool(
		permission_for_identity(
			identity_id,
			"notifications_enabled",
			true
		)
	)


func migrate_username(
	identity_id: String,
	old_username: String,
	new_username: String,
	context: Dictionary = {}
) -> Dictionary:
	var profiles: Dictionary = _safe_dictionary(
		profile_registry.get(
			"profiles",
			{}
		)
	)

	if profiles.has(identity_id):
		var profile: Dictionary = _safe_dictionary(
			profiles.get(
				identity_id,
				{}
			)
		)
		profile ["username"] = new_username

		if (
			str(
				profile.get(
					"display_name",
					""
				)
			).to_lower()
			== old_username.to_lower()
		):
			profile ["display_name"] = new_username

		profile ["updated_at_ms"] = _now_ms()
		profiles [identity_id] = profile
		profile_registry ["profiles"] = profiles
		_write_registry()

	return {
		"success": true,
		"mode": "profile_username_migrated",
		"identity_id": identity_id,
		"old_username": old_username,
		"new_username": new_username,
		"context": context.duplicate(true)
	}


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

	if command_id == "profile.emit":
		return emit_profile(
			str(envelope.get("username", "")),
			envelope
		)

	if command_id == "profile.emit_public_profile":
		return emit_profile(
			str(envelope.get("username", "")),
			envelope
		)

	if command_id == "profile.update":
		return update_own_profile(envelope)

	if command_id == "profile.upload_photo":
		return upload_own_profile_photo(
			str(envelope.get("source_path", "")),
			envelope
		)

	if command_id == "profile.request_username_change":
		if (
			gs != null
			and "identity_contract_engine" in gs
			and gs.identity_contract_engine != null
			and gs.identity_contract_engine.has_method(
				"change_account_username"
			)
		):
			return (
				gs.identity_contract_engine
				.change_account_username(
					envelope
				)
			)

		return _fail(
			"identity_authority_unavailable",
			"IdentityContractEngine cannot change the username.",
			envelope
		)

	return _fail(
		"unknown_profile_command",
		"ErAccountProfileContractEngine did not recognize command.",
		envelope
	)


func _current_profile() -> Dictionary:
	var identity_context: Dictionary = _identity_context()

	if bool(identity_context.get("is_guest", true)):
		return {}

	var account: Dictionary = _account_for_username(
		str(
			identity_context.get(
				"account_username",
				""
			)
		)
	)

	if account.is_empty():
		return {}

	return _profile_for_account(account)


func _profile_for_account(
	account: Dictionary
) -> Dictionary:
	var identity_id: String = _account_identity_id(
		account
	)
	var profiles: Dictionary = _safe_dictionary(
		profile_registry.get(
			"profiles",
			{}
		)
	)

	if (
		identity_id != ""
		and profiles.has(identity_id)
	):
		return _safe_dictionary(
			profiles.get(
				identity_id,
				{}
			)
		)

	var profile: Dictionary = _default_profile(
		account
	)

	if identity_id != "":
		profiles [identity_id] = profile
		profile_registry ["profiles"] = profiles
		_write_registry()

	return profile


func _default_profile(
	account: Dictionary
) -> Dictionary:
	var identity_id: String = _account_identity_id(
		account
	)
	var username: String = str(
		account.get(
			"username",
			"ErAccount"
		)
	)
	var created_unix: int = int(
		account.get(
			"created_unix",
			Time.get_unix_time_from_system()
		)
	)
	var joined_datetime: Dictionary = (
		Time.get_datetime_dict_from_unix_time(
			created_unix
		)
	)

	return {
		"schema": ENGINE_SCHEMA,
		"version": CONTRACT_VERSION,
		"identity_id": identity_id,
		"eraccount_id": identity_id,
		"username": username,
		"display_name": username,
		"bio": "",
		"joined_year": int(
			joined_datetime.get(
				"year",
				_current_real_year()
			)
		),
		"profile_photo": {},
		"permissions": _default_permissions(),
		"display_name_change_history_ms": [],
		"simulation_identity": {
			"realities_created": 0,
			"lives_started": 0,
			"total_lives": 0,
			"known_life_ids": [],
			"era_counts": {},
			"reality_mode_counts": {},
			"current_public_reality": {}
		},
		"created_at_ms": _now_ms(),
		"updated_at_ms": _now_ms()
	}


func _default_permissions() -> Dictionary:
	return {
		"messages": "connections",
		"connection_requests": "everyone",
		"public_profile": "everyone",
		"life_visibility": "connections",
		"milestone_visibility": "connections",
		"public_feed_visibility": "public",
		"notes_visibility": "connections",
		"notifications_enabled": true
	}


func _public_permissions_projection(
	permissions: Dictionary
) -> Dictionary:
	return {
		"messages": str(
			permissions.get(
				"messages",
				"connections"
			)
		),
		"connection_requests": str(
			permissions.get(
				"connection_requests",
				"everyone"
			)
		),
		"life_visibility": str(
			permissions.get(
				"life_visibility",
				"connections"
			)
		),
		"milestone_visibility": str(
			permissions.get(
				"milestone_visibility",
				"connections"
			)
		),
		"public_feed_visibility": str(
			permissions.get(
				"public_feed_visibility",
				"public"
			)
		),
		"notes_visibility": str(
			permissions.get(
				"notes_visibility",
				"connections"
			)
		)
	}


func _increment_counter(
	root: Dictionary,
	key: String,
	value: String
) -> void:
	var clean_value: String = str(
		value
	).strip_edges()

	if clean_value == "":
		return

	var counters: Dictionary = _safe_dictionary(
		root.get(
			key,
			{}
		)
	)
	counters [clean_value] = int(
		counters.get(
			clean_value,
			0
		)
	) + 1
	root [key] = counters


func _favorite_key(
	counters: Dictionary
) -> String:
	var favorite: String = ""
	var favorite_count: int = -1

	for raw_key in counters.keys():
		var candidate: String = str(raw_key)
		var count: int = int(
			counters.get(
				raw_key,
				0
			)
		)

		if count > favorite_count:
			favorite = candidate
			favorite_count = count

	return favorite


func _trim_history(
	history: Array,
	window_ms: int,
	now_ms: int
) -> Array:
	var out: Array = []
	var minimum_ms: int = now_ms - window_ms

	for raw_timestamp in history:
		var timestamp: int = int(raw_timestamp)

		if timestamp >= minimum_ms:
			out.append(timestamp)

	return out


func _store_profile(
	profile: Dictionary
) -> void:
	var identity_id: String = str(
		profile.get(
			"identity_id",
			""
		)
	)

	if identity_id == "":
		return

	var profiles: Dictionary = _safe_dictionary(
		profile_registry.get(
			"profiles",
			{}
		)
	)
	profiles [identity_id] = profile.duplicate(true)
	profile_registry ["profiles"] = profiles
	_write_registry()


func _are_connected(
	first_identity_id: String,
	second_identity_id: String
) -> bool:
	if (
		first_identity_id == ""
		or second_identity_id == ""
	):
		return false

	if (
		gs != null
		and "connection_graph_network" in gs
		and gs.connection_graph_network != null
		and gs.connection_graph_network.has_method(
			"are_connected"
		)
	):
		return gs.connection_graph_network.are_connected(
			first_identity_id,
			second_identity_id
		)

	return false


func _identity_context() -> Dictionary:
	if (
		gs != null
		and "identity_contract_engine" in gs
		and gs.identity_contract_engine != null
		and gs.identity_contract_engine.has_method(
			"emit_identity_context"
		)
	):
		return gs.identity_contract_engine.emit_identity_context({
			"source": "eraccount_profile"
		})

	return {
		"is_guest": true
	}


func _account_identity_id(
	account: Dictionary
) -> String:
	return str(
		account.get(
			"identity_id",
			account.get(
				"cloud_identity_id",
				""
			)
		)
	)


func _account_for_username(
	username: String
) -> Dictionary:
	var accounts: Dictionary = _safe_dictionary(
		_read_account_registry().get(
			"accounts",
			{}
		)
	)

	return _safe_dictionary(
		accounts.get(
			str(username).strip_edges().to_lower(),
			{}
		)
	)


func _account_for_identity(
	identity_id: String
) -> Dictionary:
	var accounts: Dictionary = _safe_dictionary(
		_read_account_registry().get(
			"accounts",
			{}
		)
	)

	for raw_key in accounts.keys():
		var account: Dictionary = _safe_dictionary(
			accounts.get(
				raw_key,
				{}
			)
		)

		if _account_identity_id(account) == identity_id:
			return account

	return {}


func _ensure_state() -> void:
	profile_registry = _read_registry()

	if (
		typeof(
			profile_registry.get(
				"profiles",
				{}
			)
		)
		!= TYPE_DICTIONARY
	):
		profile_registry ["profiles"] = {}

	_commit_state()


func _read_registry() -> Dictionary:
	if not FileAccess.file_exists(
		PROFILE_REGISTRY_PATH
	):
		return {
			"schema": ENGINE_SCHEMA,
			"version": CONTRACT_VERSION,
			"profiles": {}
		}

	var file:= FileAccess.open(
		PROFILE_REGISTRY_PATH,
		FileAccess.READ
	)

	if file == null:
		return {
			"schema": ENGINE_SCHEMA,
			"version": CONTRACT_VERSION,
			"profiles": {}
		}

	var parsed: Variant = JSON.parse_string(
		file.get_as_text()
	)
	file.close()

	if typeof(parsed) == TYPE_DICTIONARY:
		return (parsed as Dictionary).duplicate(true)

	return {
		"schema": ENGINE_SCHEMA,
		"version": CONTRACT_VERSION,
		"profiles": {}
	}


func _write_registry() -> void:
	_ensure_identity_dir()

	var file:= FileAccess.open(
		PROFILE_REGISTRY_PATH,
		FileAccess.WRITE
	)

	if file == null:
		return

	file.store_string(
		JSON.stringify(
			profile_registry,
			"\t"
		)
	)
	file.close()
	_commit_state()


func _read_account_registry() -> Dictionary:
	if not FileAccess.file_exists(
		ACCOUNT_REGISTRY_PATH
	):
		return {
			"accounts": {}
		}

	var file:= FileAccess.open(
		ACCOUNT_REGISTRY_PATH,
		FileAccess.READ
	)

	if file == null:
		return {
			"accounts": {}
		}

	var parsed: Variant = JSON.parse_string(
		file.get_as_text()
	)
	file.close()

	if typeof(parsed) == TYPE_DICTIONARY:
		return (parsed as Dictionary).duplicate(true)

	return {
		"accounts": {}
	}


func _ensure_identity_dir() -> void:
	var root:= DirAccess.open("user://")

	if (
		root != null
		and not root.dir_exists("identity")
	):
		root.make_dir("identity")


func _commit_state() -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	gs.scenario_state [
		"eraccount_profile_registry"
	] = profile_registry.duplicate(true)
	gs.scenario_state [
		"last_eraccount_profile_report"
	] = last_report.duplicate(true)


func _current_real_year() -> int:
	var now: Dictionary = Time.get_datetime_dict_from_system()

	return int(
		now.get(
			"year",
			2026
		)
	)


func _now_ms() -> int:
	return int(
		Time.get_unix_time_from_system()
		* 1000.0
	)


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)


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
		"schema": "eralife.eraccount_profile.error",
		"version": CONTRACT_VERSION,
		"success": false,
		"reason_id": reason_id,
		"reason": message,
		"message": message,
		"context": context.duplicate(true),
		"created_at_ms": _now_ms()
	}
	_commit_state()
	return last_report.duplicate(true)