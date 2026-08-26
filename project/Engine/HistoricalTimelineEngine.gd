extends Resource
class_name HistoricalTimelineEngine

var gs

func _init(_gs):
	gs = _gs






var timeline:= {}





func record_event(payload: Dictionary):
	var year = gs.year
	if not timeline.has(year):
		timeline [year] = []

	var text = str(payload.get("text", "")).strip_edges()
	if text == "":
		return

	var event_key: String = _historical_timeline_event_key(payload, year, text)
	var dedupe_state_raw: Variant = timeline.get("_dedupe", {})
	var dedupe_state: Dictionary = dedupe_state_raw if typeof(dedupe_state_raw) == TYPE_DICTIONARY else {}
	var year_bucket_raw: Variant = dedupe_state.get(str(year), {})
	var year_bucket: Dictionary = year_bucket_raw if typeof(year_bucket_raw) == TYPE_DICTIONARY else {}

	if event_key != "" and year_bucket.has(event_key):
		return

	if event_key != "":
		year_bucket [event_key] = true
		dedupe_state [str(year)] = year_bucket
		timeline ["_dedupe"] = dedupe_state

	timeline [year].append(text)
func _historical_timeline_event_key(payload: Dictionary, year: int, text: String) -> String:

	if typeof(payload) != TYPE_DICTIONARY:
		return ""
	return "%s|%s|%s|%s" % [
		str(year),
		str(payload.get("event_name", payload.get("type", ""))).strip_edges(),
		str(payload.get("source", "")).strip_edges(),
		text
	]





func record_era_shift(payload):

	var year = gs.year

	if not timeline.has(year):
		timeline [year] = []

	var era_name = payload.get("era", gs.era.name)

	timeline [year].append(
		"🌍 The world entered the %s." % era_name
	)





func record_birth(payload):

	var facts = gs.get_npc_facts_by_id(payload.get("npc_id", -1))
	if facts == {}:
		return

	var year = gs.year

	if not timeline.has(year):
		timeline [year] = []

	timeline [year].append(
		"👶 %s %s was born." % [facts.get("first_name", ""), facts.get("last_name", "")]
	)





func record_death(payload):

	var facts = gs.get_npc_facts_by_id(payload.get("npc_id", -1))
	if facts == {}:
		return

	var year = gs.year

	if not timeline.has(year):
		timeline [year] = []

	timeline [year].append(
		"🕊️ %s %s died." % [facts.get("first_name", ""), facts.get("last_name", "")]
	)





func record_dynasty(payload):

	var year = gs.year

	if not timeline.has(year):
		timeline [year] = []

	timeline [year].append(
		payload.get("text", "A dynasty shifted power.")
	)





func get_year(year: int) -> Array:
	return timeline.get(year, [])


func get_last_years(n: int) -> Dictionary:

	var out:= {}
	var keys = timeline.keys()
	keys.sort()

	var start = max(0, keys.size() - n)

	for i in range(start, keys.size()):
		var y = keys [i]
		out [y] = timeline [y]

	return out