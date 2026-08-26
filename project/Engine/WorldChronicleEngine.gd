extends Resource
class_name WorldChronicleEngine

var gs


var timeline: Array = []


const MAX_CHRONICLE = 10000


func _init(_gs):
	gs = _gs





func record(text: String):
	if text == "":
		return

	var year_value: int = gs.year if gs != null else 0
	var normalized_text: String = str(text).strip_edges()
	if normalized_text == "":
		return

	if timeline.size() > 0:
		var last_raw = timeline.back()
		if typeof(last_raw) == TYPE_DICTIONARY:
			var last_entry: Dictionary = last_raw
			if int(last_entry.get("year", -1)) == year_value and str(last_entry.get("text", "")).strip_edges() == normalized_text:
				return

	var entry = {
		"year": year_value,
		"text": normalized_text
	}
	timeline.append(entry)
	if timeline.size() > MAX_CHRONICLE:
		timeline.pop_front()
func _fast_chronicle_packet_key(packet: Dictionary) -> String:

	if typeof(packet) != TYPE_DICTIONARY or packet.is_empty():
		return ""
	var packet_type: String = str(packet.get("type", "")).strip_edges()
	if packet_type == "chronicle_entry":
		var direct_text: String = str(packet.get("text", "")).strip_edges()
		if direct_text == "":
			return ""
		return "chronicle|%s|%s" % [
			str(int(packet.get("year", gs.year if gs != null else 0))),
			direct_text
		]
	var chronicle_text: String = str(packet.get("chronicle_text", "")).strip_edges()
	if chronicle_text == "" and bool(packet.get("queue_chronicle", false)):
		chronicle_text = str(packet.get("text", "")).strip_edges()
	if chronicle_text == "":
		return ""
	return "chronicle|%s|%s|%s" % [
		packet_type,
		str(int(packet.get("year", gs.year if gs != null else 0))),
		chronicle_text
	]





func record_from_bus(payload: Dictionary):
	var mailbox_entry: Dictionary = _chronicle_mailbox_entry_from_typed_packet(payload)
	if not mailbox_entry.is_empty():
		var chronicle_text: String = str(mailbox_entry.get("text", "")).strip_edges()
		if chronicle_text != "":
			record(chronicle_text)
		return

	var text = payload.get("text", "")
	if text != "":
		record(text)
func build_runtime_mailbox_entries_from_typed_packets(delta_packets: Array) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	var raw_seen: Dictionary = {}

	for raw_packet in delta_packets:
		if typeof(raw_packet) != TYPE_DICTIONARY:
			continue

		var packet: Dictionary = raw_packet
		var raw_key: String = _fast_chronicle_packet_key(packet)
		if raw_key != "" and raw_seen.has(raw_key):
			continue
		if raw_key != "":
			raw_seen [raw_key] = true

		var mailbox_entry: Dictionary = _chronicle_mailbox_entry_from_typed_packet(packet)
		if mailbox_entry.is_empty():
			continue

		var mailbox_key: String = str(mailbox_entry.get("mailbox_key", "")).strip_edges()
		if mailbox_key != "" and seen.has(mailbox_key):
			continue
		if mailbox_key != "":
			seen [mailbox_key] = true

		out.append(mailbox_entry)

	return out

func _chronicle_mailbox_entry_from_typed_packet(packet: Dictionary) -> Dictionary:
	if typeof(packet) != TYPE_DICTIONARY or packet.is_empty():
		return {}

	var packet_type: String = str(packet.get("type", "")).strip_edges()
	if packet_type == "":
		return {}

	if packet_type == "chronicle_entry":
		var direct_text: String = str(packet.get("text", "")).strip_edges()
		if direct_text == "":
			return {}
		return {
			"type": "chronicle_entry",
			"text": direct_text,
			"year": int(packet.get("year", gs.year if gs != null else 0)),
			"source": str(packet.get("source", "typed_phase_packet")),
			"mailbox_key": "chronicle|chronicle_entry|%s|%s" % [
				str(packet.get("year", gs.year if gs != null else 0)),
				direct_text
			]
		}

	var chronicle_text: String = str(packet.get("chronicle_text", "")).strip_edges()
	if chronicle_text == "" and bool(packet.get("queue_chronicle", false)):
		chronicle_text = str(packet.get("text", "")).strip_edges()

	if chronicle_text == "":
		match packet_type:
			"death":
				var dead_name: String = str(packet.get("name", "Someone")).strip_edges()
				if dead_name == "":
					dead_name = "Someone"
				chronicle_text = "%s died." % dead_name
			"moved":
				var mover_name: String = str(packet.get("name", "Someone")).strip_edges()
				if mover_name == "":
					mover_name = "Someone"
				var destination: String = str(packet.get("to_label", packet.get("to", ""))).strip_edges()
				if destination != "":
					chronicle_text = "%s moved to %s." % [mover_name, destination]
			"place_shift":
				var place_name: String = str(packet.get("name", "Someone")).strip_edges()
				if place_name == "":
					place_name = "Someone"

				var from_city: String = str(packet.get("from_city", "")).strip_edges()
				var from_country: String = str(packet.get("from_country", "")).strip_edges()
				var to_city: String = str(packet.get("to_city", "")).strip_edges()
				var to_country: String = str(packet.get("to_country", "")).strip_edges()

				var from_label: String = ""
				if from_city != "" and from_country != "":
					from_label = "%s, %s" % [from_city, from_country]
				elif from_city != "":
					from_label = from_city
				else:
					from_label = from_country

				var to_label: String = ""
				if to_city != "" and to_country != "":
					to_label = "%s, %s" % [to_city, to_country]
				elif to_city != "":
					to_label = to_city
				else:
					to_label = to_country

				if to_label != "":
					if from_label != "":
						chronicle_text = "%s shifted from %s to %s." % [place_name, from_label, to_label]
					else:
						chronicle_text = "%s is now tied to %s." % [place_name, to_label]
			"era_shift":
				var era_name: String = str(packet.get("era", "")).strip_edges()
				if era_name != "":
					chronicle_text = "The world entered the %s." % era_name

	if chronicle_text == "":
		return {}

	return {
		"type": "chronicle_entry",
		"text": chronicle_text,
		"year": int(packet.get("year", gs.year if gs != null else 0)),
		"source": str(packet.get("source", "typed_phase_packet")),
		"mailbox_key": "chronicle|%s|%s|%s" % [
			packet_type,
			str(packet.get("year", gs.year if gs != null else 0)),
			chronicle_text
		]
	}






func log(text: String):
	record(text)






func get_chronicle() -> Array:
	return timeline