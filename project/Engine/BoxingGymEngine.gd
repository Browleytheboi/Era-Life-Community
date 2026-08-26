extends Resource
class_name BoxingGymEngine

const CONTRACT_SCHEMA:= "eralife.boxing_gym_engine"
const CONTRACT_VERSION:= 1

var gs
var gym_state: Dictionary = {}

func _init(_gs):
	gs = _gs


func export_state() -> Dictionary:
	return {
		"schema": CONTRACT_SCHEMA + "_state",
		"version": CONTRACT_VERSION,
		"gym_state": gym_state.duplicate(true)
	}


func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return { "success": false, "reason": "BoxingGymEngine expected Dictionary state."}

	var raw_state: Variant = data.get("gym_state", {})
	if typeof(raw_state) == TYPE_DICTIONARY:
		gym_state = (raw_state as Dictionary).duplicate(true)
	else:
		gym_state = {}

	return {
		"success": true,
		"gym_count": gym_state.size()
	}


func _current_era_name() -> String:
	if gs != null and gs.era != null:
		return str(gs.era.name).strip_edges()
	return "Modern Era"


func _current_city() -> String:
	if gs != null and "city" in gs:
		return str(gs.city).strip_edges()
	return "Local City"


func _current_country() -> String:
	if gs != null and "country" in gs:
		return str(gs.country).strip_edges()
	return "Local Country"


func _stable_seed(text: String) -> int:
	var hash_value: int = 2166136261
	for i in range(str(text).length()):
		hash_value = int((hash_value ^ str(text).unicode_at(i)) * 16777619) & 2147483647
	return max(1, hash_value)


func _person_name(person: Person) -> String:
	if person == null:
		return "Unknown Fighter"

	var direct_name: String = str(person.name).strip_edges() if "name" in person else ""
	if direct_name != "":
		return direct_name

	var full_name: String = ("%s %s" % [
		str(person.first_name).strip_edges(),
		str(person.last_name).strip_edges()
	]).strip_edges()

	if full_name != "":
		return full_name

	return "Unknown Fighter"


func _actor_gym_id(actor: Person) -> String:
	if actor == null or typeof(actor.boxing_profile) != TYPE_DICTIONARY:
		return ""
	return str(actor.boxing_profile.get("gym_id", "")).strip_edges()


func get_gym_catalog(actor: Person = null) -> Array:
	var era_name: String = _current_era_name()
	var city_name: String = _current_city()
	var country_name: String = _current_country()

	var future_bias: bool = era_name == "Future Era"

	var catalog: Array = [
		{
			"id": "iron_temple_boxing",
			"name": "Iron Temple Boxing",
			"tier": "local",
			"monthly_fee": 35,
			"training_bonus": 4,
			"sparring_quality": 38,
			"reputation": 22,
			"color_heat": 0.28,
			"city": city_name,
			"country": country_name,
			"perks": ["Cheap membership", "Hard sparring", "Old-school coaches"],
			"requirements": { "minimum_fame": 0, "minimum_wins": 0}
		},
		{
			"id": "southside_gloves_club",
			"name": "Southside Gloves Club",
			"tier": "regional",
			"monthly_fee": 80,
			"training_bonus": 8,
			"sparring_quality": 54,
			"reputation": 40,
			"color_heat": 0.44,
			"city": city_name,
			"country": country_name,
			"perks": ["Better sparring pool", "Regional amateurs", "Conditioning coach"],
			"requirements": { "minimum_fame": 0, "minimum_wins": 1}
		},
		{
			"id": "crown_gloves_gym",
			"name": "Crown Gloves Gym",
			"tier": "contender",
			"monthly_fee": 180,
			"training_bonus": 13,
			"sparring_quality": 68,
			"reputation": 62,
			"color_heat": 0.62,
			"city": city_name,
			"country": country_name,
			"perks": ["Ranked sparring", "Title-camp coaches", "Media visibility"],
			"requirements": { "minimum_fame": 12, "minimum_wins": 4}
		},
		{
			"id": "champion_maker_labs" if future_bias else "champion_maker_gym",
			"name": "Champion Maker Labs" if future_bias else "Champion Maker Gym",
			"tier": "elite",
			"monthly_fee": 420,
			"training_bonus": 20,
			"sparring_quality": 86,
			"reputation": 84,
			"color_heat": 0.86,
			"city": city_name,
			"country": country_name,
			"perks": ["Elite coaches", "Champion sparring", "Camp science", "Title-fight preparation"],
			"requirements": { "minimum_fame": 35, "minimum_wins": 8}
		}
	]

	for i in range(catalog.size()):
		var gym: Dictionary = catalog [i]
		gym ["eligible"] = can_join_gym(actor, str(gym.get("id", "")))
		gym ["locked_reason"] = gym_locked_reason(actor, gym)
		catalog [i] = gym

	return catalog


func _record_for_actor(actor: Person) -> Dictionary:
	if actor == null:
		return {}
	var record: Variant = actor.boxing_profile.get("record", {})
	if typeof(record) == TYPE_DICTIONARY:
		return record
	return {}


func _total_wins(actor: Person) -> int:
	var record: Dictionary = _record_for_actor(actor)
	var amateur_record: Dictionary = actor.boxing_profile.get("amateur_record", {}) if actor != null and typeof(actor.boxing_profile.get("amateur_record", {})) == TYPE_DICTIONARY else {}
	return int(record.get("wins", 0)) + int(amateur_record.get("wins", 0))


func gym_locked_reason(actor: Person, gym: Dictionary) -> String:
	if actor == null:
		return "No boxer selected."

	var requirements: Dictionary = gym.get("requirements", {}) if typeof(gym.get("requirements", {})) == TYPE_DICTIONARY else {}
	var minimum_fame: int = int(requirements.get("minimum_fame", 0))
	var minimum_wins: int = int(requirements.get("minimum_wins", 0))

	if int(actor.fame) < minimum_fame:
		return "Requires at least %d fame." % minimum_fame

	if _total_wins(actor) < minimum_wins:
		return "Requires at least %d boxing wins." % minimum_wins

	return ""


func can_join_gym(actor: Person, gym_id: String) -> bool:
	if actor == null:
		return false
	if typeof(actor.boxing_profile) != TYPE_DICTIONARY:
		return false
	if not bool(actor.boxing_profile.get("is_boxer", false)):
		return false

	for raw_gym in get_gym_catalog(null):
		if typeof(raw_gym) != TYPE_DICTIONARY:
			continue

		var gym: Dictionary = raw_gym
		if str(gym.get("id", "")) != str(gym_id):
			continue

		return gym_locked_reason(actor, gym) == ""

	return false


func get_gym_by_id(gym_id: String) -> Dictionary:
	var clean_id: String = str(gym_id).strip_edges()
	for raw_gym in get_gym_catalog(null):
		if typeof(raw_gym) != TYPE_DICTIONARY:
			continue

		var gym: Dictionary = raw_gym
		if str(gym.get("id", "")) == clean_id:
			return gym.duplicate(true)

	return {}


func join_gym(actor: Person, gym_id: String) -> Dictionary:
	if actor == null:
		return { "success": false, "text": "No boxer selected."}

	var gym: Dictionary = get_gym_by_id(gym_id)
	if gym.is_empty():
		return { "success": false, "text": "That boxing gym does not exist in this city."}

	var locked_reason: String = gym_locked_reason(actor, gym)
	if locked_reason != "":
		return {
			"success": false,
			"text": "\n\nI could not join %s. %s" % [str(gym.get("name", "the gym")), locked_reason],
			"refresh_tab": "gym:find"
		}

	actor.boxing_profile ["gym_id"] = str(gym.get("id", ""))
	actor.boxing_profile ["gym_name"] = str(gym.get("name", "Unknown Gym"))
	actor.boxing_profile ["gym_joined_year"] = int(gs.year) if gs != null else 0
	actor.boxing_profile ["gym_training_bonus"] = int(gym.get("training_bonus", 0))
	actor.boxing_profile ["gym_sparring_quality"] = int(gym.get("sparring_quality", 0))

	_seed_gym_runtime_members(gym)

	var txt: String = "\n\nI joined %s and became part of their boxing room." % str(gym.get("name", "a boxing gym"))

	if gs != null and gs.narrative_engine != null:
		gs.narrative_engine.log_event(actor, { "type": "text", "text": txt})

	return {
		"success": true,
		"text": txt,
		"type": "open_boxing_gym_hub",
		"gym_id": str(gym.get("id", "")),
		"gym_tab": "common",
		"popup_title": "Gym Joined",
		"popup_text": "You entered %s. The Gym Hub is now available." % str(gym.get("name", "the gym")),
		"popup_footer": "Tap anywhere to continue.",
		"refresh_tab": "gym"
	}


func _seed_gym_runtime_members(gym: Dictionary) -> void:
	if gs == null:
		return

	var gym_id: String = str(gym.get("id", "")).strip_edges()
	if gym_id == "":
		return

	if not gym_state.has(gym_id):
		gym_state [gym_id] = {
			"members": [],
			"created_at_ms": int(Time.get_ticks_msec()),
			"updated_at_ms": int(Time.get_ticks_msec())
		}

	var state: Dictionary = gym_state [gym_id]
	var members: Array = state.get("members", []) if typeof(state.get("members", [])) == TYPE_ARRAY else []

	for raw_npc in gs.npcs:
		var npc:= raw_npc as Person
		if npc == null or not npc.alive:
			continue
		if typeof(npc.boxing_profile) != TYPE_DICTIONARY:
			continue
		if not bool(npc.boxing_profile.get("is_boxer", false)):
			continue
		if bool(npc.boxing_profile.get("retired", false)):
			continue

		var should_join: bool = false
		if str(npc.boxing_profile.get("gym_id", "")).strip_edges() == gym_id:
			should_join = true
		elif bool(npc.boxing_profile.get("generated_boxing_faction_member", false)) and members.size() < 18 and randi() % 100 < 22:
			should_join = true

		if not should_join:
			continue

		npc.boxing_profile ["gym_id"] = gym_id
		npc.boxing_profile ["gym_name"] = str(gym.get("name", "Unknown Gym"))

		if int(npc.id) not in members:
			members.append(int(npc.id))

		if members.size() >= 18:
			break

	state ["members"] = members
	state ["updated_at_ms"] = int(Time.get_ticks_msec())
	gym_state [gym_id] = state


func _gym_activity_for_member(member: Person, rng: RandomNumberGenerator, visible_names: Array) -> String:
	var activities: Array = [
		"jumping rope",
		"hitting the heavy bag",
		"working mitts with a trainer",
		"doing pushups on their knuckles",
		"shadowboxing near the mirror",
		"cooling down after sparring",
		"wrapping their hands",
		"watching film on a tablet",
		"working defense drills"
	]

	if visible_names.size() > 1 and rng.randi_range(0, 100) < 38:
		var partner_name: String = str(visible_names [int(rng.randi_range(0, visible_names.size() - 1))])
		if partner_name != _person_name(member):
			return "sparring with %s" % partner_name

	return str(activities [int(rng.randi_range(0, activities.size() - 1))])


func build_common_area_rows(actor: Person, gym_id: String) -> Array:
	var rows: Array = []
	var gym: Dictionary = get_gym_by_id(gym_id)
	if gym.is_empty():
		return rows

	_seed_gym_runtime_members(gym)

	var state: Dictionary = gym_state.get(gym_id, {}) if typeof(gym_state.get(gym_id, {})) == TYPE_DICTIONARY else {}
	var members: Array = state.get("members", []) if typeof(state.get("members", [])) == TYPE_ARRAY else []

	var visible_people: Array = []
	var visible_names: Array = []

	if actor != null:
		visible_people.append(actor)
		visible_names.append(_person_name(actor))

	for raw_id in members:
		var member: Person = gs.get_npc_by_id(int(raw_id)) if gs != null else null
		if member == null or member == actor:
			continue
		visible_people.append(member)
		visible_names.append(_person_name(member))
		if visible_people.size() >= 12:
			break

	var rng:= RandomNumberGenerator.new()
	rng.seed = _stable_seed("%s|%s|%s" % [gym_id, str(gs.year if gs != null else 0), str(Time.get_ticks_msec() / 5000.0)])

	for person_value in visible_people:
		var member:= person_value as Person
		if member == null:
			continue

		var record: Dictionary = member.boxing_profile.get("record", {}) if typeof(member.boxing_profile.get("record", {})) == TYPE_DICTIONARY else {}
		var amateur_record: Dictionary = member.boxing_profile.get("amateur_record", {}) if typeof(member.boxing_profile.get("amateur_record", {})) == TYPE_DICTIONARY else {}
		var turned_pro: bool = bool(member.boxing_profile.get("turned_pro", false))
		var activity_text: String = _gym_activity_for_member(member, rng, visible_names)

		rows.append({
			"row_type": "gym_fighter_card",
			"title": _person_name(member),
			"body": "%s • %s\n%s" % [
				"Pro" if turned_pro else "Amateur",
				("%d-%d-%d (%d KOs)" % [
					int(record.get("wins", amateur_record.get("wins", 0))),
					int(record.get("losses", amateur_record.get("losses", 0))),
					int(record.get("draws", amateur_record.get("draws", 0))),
					int(record.get("kos", amateur_record.get("kos", 0)))
				]),
				activity_text.capitalize()
			],
			"activity": activity_text,
			"fame": int(member.fame),
			"person_id": int(member.id)
		})

	return rows


func build_gym_hub_payload(actor: Person, tab_id: String = "common") -> Dictionary:
	var gym_id: String = _actor_gym_id(actor)
	var gym: Dictionary = get_gym_by_id(gym_id)
	var clean_tab: String = str(tab_id).strip_edges().to_lower()
	if clean_tab == "":
		clean_tab = "common"

	if actor == null:
		return { "success": false, "text": "No boxer selected.", "sections": []}

	if gym_id == "" or gym.is_empty():
		return {
			"success": false,
			"text": "I do not belong to a boxing gym yet.",
			"sections": []
		}

	var sections: Array = [
		{
			"id": "personal",
			"title": "Personal Training",
			"emoji": "🏋️",
			"summary": "Private work with this gym’s coaches. This is ready for deeper BoxingTrainingEngine expansion.",
			"lines": [
				"Gym: %s" % str(gym.get("name", "")),
				"Training Bonus: +%d" % int(gym.get("training_bonus", 0)),
				"Sparring Quality: %d/100" % int(gym.get("sparring_quality", 0))
			],
			"actions": [
				{ "label": "Personal Training", "command": "boxing.training.personal", "refresh_tab": "personal"}
			]
		},
		{
			"id": "common",
			"title": "Common Area",
			"emoji": "🥊",
			"summary": "Live gym floor. Fighters move, work, spar, rest, and build the gym’s room identity.",
			"lines": [],
			"rows": build_common_area_rows(actor, gym_id),
			"row_columns": 3,
			"actions": []
		},
		{
			"id": "accomplishments",
			"title": "Gym Accomplishments",
			"emoji": "🏆",
			"summary": "Titles, Golden Gloves wins, and major accomplishments carried by this room.",
			"lines": _gym_accomplishment_lines(gym_id),
			"actions": []
		}
	]

	return {
		"success": true,
		"schema": "eralife.boxing_gym_hub_payload",
		"version": CONTRACT_VERSION,
		"gym_id": gym_id,
		"gym_name": str(gym.get("name", "")),
		"selected_tab": clean_tab,
		"sections": sections,
		"built_at_ms": int(Time.get_ticks_msec())
	}


func _gym_accomplishment_lines(gym_id: String) -> Array:
	var out: Array = []
	var title_count: int = 0
	var golden_gloves_count: int = 0
	var named_champs: Array = []

	if gs == null:
		return ["Gym data unavailable."]

	for raw_npc in gs.npcs:
		var npc:= raw_npc as Person
		if npc == null:
			continue
		if typeof(npc.boxing_profile) != TYPE_DICTIONARY:
			continue
		if str(npc.boxing_profile.get("gym_id", "")).strip_edges() != gym_id:
			continue

		var belts: Array = npc.boxing_profile.get("belts", []) if typeof(npc.boxing_profile.get("belts", [])) == TYPE_ARRAY else []
		if not belts.is_empty():
			title_count += belts.size()
			named_champs.append("%s — %s" % [_person_name(npc), ", ".join(belts)])

		golden_gloves_count += int(npc.boxing_profile.get("golden_gloves_wins", 0))

	out.append("World Titles Represented: %d" % title_count)
	out.append("Golden Gloves Wins Represented: %d" % golden_gloves_count)

	if named_champs.is_empty():
		out.append("No world champions from this gym yet.")
	else:
		out.append("Championship Wall:")
		for champ_line in named_champs.slice(0, min(named_champs.size(), 8)):
			out.append("- %s" % str(champ_line))

	return out