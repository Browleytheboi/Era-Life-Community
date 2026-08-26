extends Resource
class_name PublicFeedContractEngine

const ENGINE_SCHEMA:= "eralife.public_feed"
const CONTRACT_VERSION:= 1
const FEED_REGISTRY_PATH:= (
	"user://identity/public_feed_registry.json"
)
const POST_CHARACTER_LIMIT:= 500

var gs
var feed_registry: Dictionary = {}
var last_report: Dictionary = {}


func _init(_gs = null) -> void:
	gs = _gs
	_ensure_state()


func create_post(
	text: String,
	visibility: String = "public",
	context: Dictionary = {}
) -> Dictionary:
	var identity_context: Dictionary = _identity_context()

	if bool(identity_context.get("is_guest", true)):
		return _fail(
			"account_required",
			"Sign into an ErAccount to post publicly.",
			context
		)

	var clean_text: String = str(
		text
	).strip_edges()

	if clean_text == "":
		return _fail(
			"post_missing",
			"Enter something to post.",
			context
		)

	if clean_text.length() > POST_CHARACTER_LIMIT:
		return _fail(
			"post_too_long",
			"Public Feed posts are limited to %d characters."
			% POST_CHARACTER_LIMIT,
			context
		)

	var clean_visibility: String = str(
		visibility
	).strip_edges().to_lower()

	if (
		clean_visibility
		not in ["public", "connections", "private"]
	):
		clean_visibility = "public"

	var now_ms: int = _now_ms()
	var identity_id: String = _identity_id(
		identity_context
	)
	var username: String = str(
		identity_context.get(
			"account_username",
			""
		)
	)
	var post_id: String = "post_%d" % abs(
		hash(
			"%s|%d|%s" % [
				identity_id,
				now_ms,
				clean_text
			]
		)
	)
	var post: Dictionary = {
		"schema": "eralife.public_feed.post",
		"version": CONTRACT_VERSION,
		"post_id": post_id,
		"author_identity_id": identity_id,
		"author_username": username,
		"text": clean_text,
		"visibility": clean_visibility,
		"liked_by_identity_ids": [],
		"reposted_by_identity_ids": [],
		"created_at_ms": now_ms,
		"updated_at_ms": now_ms
	}

	var posts: Dictionary = _safe_dictionary(
		feed_registry.get(
			"posts",
			{}
		)
	)
	posts [post_id] = post
	feed_registry ["posts"] = posts
	_write_registry()

	return {
		"schema": "eralife.public_feed.action_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": "post_created",
		"message": "Posted to the Public Feed.",
		"post": post.duplicate(true),
		"created_at_ms": now_ms
	}


func toggle_like(
	post_id: String,
	context: Dictionary = {}
) -> Dictionary:
	var identity_context: Dictionary = _identity_context()

	if bool(identity_context.get("is_guest", true)):
		return _fail(
			"account_required",
			"Sign into an ErAccount to like posts.",
			context
		)

	var posts: Dictionary = _safe_dictionary(
		feed_registry.get(
			"posts",
			{}
		)
	)

	if not posts.has(post_id):
		return _fail(
			"post_missing",
			"That Public Feed post could not be found.",
			context
		)

	var post: Dictionary = _safe_dictionary(
		posts.get(
			post_id,
			{}
		)
	)
	var identity_id: String = _identity_id(
		identity_context
	)
	var liked_by: Array = _safe_array(
		post.get(
			"liked_by_identity_ids",
			[]
		)
	)
	var liked: bool = not liked_by.has(
		identity_id
	)

	if liked:
		liked_by.append(identity_id)
	else:
		liked_by.erase(identity_id)

	post ["liked_by_identity_ids"] = liked_by
	post ["updated_at_ms"] = _now_ms()
	posts [post_id] = post
	feed_registry ["posts"] = posts
	_write_registry()

	return {
		"schema": "eralife.public_feed.action_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": "post_like_toggled",
		"message": (
			"Post liked."
			if liked
			else "Like removed."
		),
		"liked": liked,
		"post": post.duplicate(true),
		"created_at_ms": _now_ms()
	}


func toggle_repost(
	post_id: String,
	context: Dictionary = {}
) -> Dictionary:
	var identity_context: Dictionary = _identity_context()

	if bool(identity_context.get("is_guest", true)):
		return _fail(
			"account_required",
			"Sign into an ErAccount to repost.",
			context
		)

	var posts: Dictionary = _safe_dictionary(
		feed_registry.get(
			"posts",
			{}
		)
	)

	if not posts.has(post_id):
		return _fail(
			"post_missing",
			"That Public Feed post could not be found.",
			context
		)

	var post: Dictionary = _safe_dictionary(
		posts.get(
			post_id,
			{}
		)
	)
	var identity_id: String = _identity_id(
		identity_context
	)
	var reposted_by: Array = _safe_array(
		post.get(
			"reposted_by_identity_ids",
			[]
		)
	)
	var reposted: bool = not reposted_by.has(
		identity_id
	)

	if reposted:
		reposted_by.append(identity_id)
	else:
		reposted_by.erase(identity_id)

	post ["reposted_by_identity_ids"] = reposted_by
	post ["updated_at_ms"] = _now_ms()
	posts [post_id] = post
	feed_registry ["posts"] = posts
	_write_registry()

	return {
		"schema": "eralife.public_feed.action_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": "post_repost_toggled",
		"message": (
			"Post reposted."
			if reposted
			else "Repost removed."
		),
		"reposted": reposted,
		"post": post.duplicate(true),
		"created_at_ms": _now_ms()
	}


func emit_feed(
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	var identity_context: Dictionary = _identity_context()
	var viewer_identity_id: String = _identity_id(
		identity_context
	)
	var connected_ids: Array = []

	if (
		viewer_identity_id != ""
		and gs != null
		and "connection_graph_network" in gs
		and gs.connection_graph_network != null
	):
		connected_ids = (
			gs.connection_graph_network
				.connected_identity_ids(
					viewer_identity_id
				)
		)

	var posts: Dictionary = _safe_dictionary(
		feed_registry.get(
			"posts",
			{}
		)
	)
	var visible_posts: Array = []

	for raw_post_id in posts.keys():
		var post: Dictionary = _safe_dictionary(
			posts.get(
				raw_post_id,
				{}
			)
		)
		var author_id: String = str(
			post.get(
				"author_identity_id",
				""
			)
		)
		var visibility: String = str(
			post.get(
				"visibility",
				"public"
			)
		)

		if visibility == "private":
			if author_id != viewer_identity_id:
				continue
		elif visibility == "connections":
			if (
				author_id != viewer_identity_id
				and not connected_ids.has(
					author_id
				)
			):
				continue

		var profile: Dictionary = _profile_by_identity(
			author_id
		)
		var liked_by: Array = _safe_array(
			post.get(
				"liked_by_identity_ids",
				[]
			)
		)
		var reposted_by: Array = _safe_array(
			post.get(
				"reposted_by_identity_ids",
				[]
			)
		)

		post ["author_display_name"] = str(
			profile.get(
				"display_name",
				post.get(
					"author_username",
					"Unknown"
				)
			)
		)
		post ["profile_photo"] = _safe_dictionary(
			profile.get(
				"profile_photo",
				{}
			)
		)
		post ["like_count"] = liked_by.size()
		post ["repost_count"] = reposted_by.size()
		post ["viewer_has_liked"] = liked_by.has(
			viewer_identity_id
		)
		post ["viewer_has_reposted"] = reposted_by.has(
			viewer_identity_id
		)
		visible_posts.append(post)

	visible_posts.sort_custom(
		Callable(
			self,
			"_sort_posts"
		)
	)

	return {
		"schema": "eralife.public_feed.contract",
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": "public_feed_ready",
		"posts": visible_posts,
		"post_count": visible_posts.size(),
		"character_limit": POST_CHARACTER_LIMIT,
		"context": context.duplicate(true),
		"created_at_ms": _now_ms()
	}


func migrate_username(
	identity_id: String,
	_old_username: String,
	new_username: String,
	context: Dictionary = {}
) -> Dictionary:
	var posts: Dictionary = _safe_dictionary(
		feed_registry.get(
			"posts",
			{}
		)
	)

	for raw_post_id in posts.keys():
		var post: Dictionary = _safe_dictionary(
			posts.get(
				raw_post_id,
				{}
			)
		)

		if (
			str(
				post.get(
					"author_identity_id",
					""
				)
			)
			== identity_id
		):
			post ["author_username"] = new_username
			posts [raw_post_id] = post

	feed_registry ["posts"] = posts
	_write_registry()

	return {
		"success": true,
		"mode": "public_feed_username_migrated",
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

	if command_id == "public_feed.create_post":
		return create_post(
			str(envelope.get("text", "")),
			str(envelope.get("visibility", "public")),
			envelope
		)

	if command_id == "public_feed.toggle_like":
		return toggle_like(
			str(envelope.get("post_id", "")),
			envelope
		)

	if command_id == "public_feed.toggle_repost":
		return toggle_repost(
			str(envelope.get("post_id", "")),
			envelope
		)

	if command_id == "public_feed.emit":
		return emit_feed(envelope)

	return _fail(
		"unknown_public_feed_command",
		"PublicFeedContractEngine did not recognize command.",
		envelope
	)


func _profile_by_identity(
	identity_id: String
) -> Dictionary:
	if (
		gs != null
		and "eraccount_profile_contract_engine" in gs
		and gs.eraccount_profile_contract_engine != null
	):
		return (
			gs.eraccount_profile_contract_engine
				.emit_profile_by_identity(
					identity_id,
					{
						"source": "public_feed"
					}
				)
		)

	return {}


func _identity_context() -> Dictionary:
	if (
		gs != null
		and "identity_contract_engine" in gs
		and gs.identity_contract_engine != null
	):
		return gs.identity_contract_engine.emit_identity_context({
			"source": "public_feed"
		})

	return {
		"is_guest": true
	}


func _identity_id(
	identity_context: Dictionary
) -> String:
	return str(
		identity_context.get(
			"cloud_identity_id",
			identity_context.get(
				"identity_id",
				""
			)
		)
	)


func _sort_posts(
	a: Dictionary,
	b: Dictionary
) -> bool:
	return (
		int(a.get("created_at_ms", 0))
		> int(b.get("created_at_ms", 0))
	)


func _ensure_state() -> void:
	feed_registry = _read_registry()

	if (
		typeof(
			feed_registry.get(
				"posts",
				{}
			)
		)
		!= TYPE_DICTIONARY
	):
		feed_registry ["posts"] = {}


func _read_registry() -> Dictionary:
	if not FileAccess.file_exists(
		FEED_REGISTRY_PATH
	):
		return {
			"schema": ENGINE_SCHEMA,
			"version": CONTRACT_VERSION,
			"posts": {}
		}

	var file:= FileAccess.open(
		FEED_REGISTRY_PATH,
		FileAccess.READ
	)

	if file == null:
		return {
			"schema": ENGINE_SCHEMA,
			"version": CONTRACT_VERSION,
			"posts": {}
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
		"posts": {}
	}


func _write_registry() -> void:
	_ensure_identity_dir()

	var file:= FileAccess.open(
		FEED_REGISTRY_PATH,
		FileAccess.WRITE
	)

	if file == null:
		return

	file.store_string(
		JSON.stringify(
			feed_registry,
			"\t"
		)
	)
	file.close()


func _ensure_identity_dir() -> void:
	var root:= DirAccess.open("user://")

	if (
		root != null
		and not root.dir_exists("identity")
	):
		root.make_dir("identity")


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
		"schema": "eralife.public_feed.error",
		"version": CONTRACT_VERSION,
		"success": false,
		"reason_id": reason_id,
		"reason": message,
		"message": message,
		"context": context.duplicate(true),
		"created_at_ms": _now_ms()
	}
	return last_report.duplicate(true)