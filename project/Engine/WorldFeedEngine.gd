extends Resource
class_name WorldFeedEngine

var gs

func _init(_gs):
	gs = _gs
	if gs != null and gs.event_bus != null:
		gs.event_bus.subscribe(ActionEventTypes.YEAR_PASSED, self, "yearly_asset_world_feed_tick")
func yearly_asset_world_feed_tick(_payload:= {}) -> void:
	if gs == null or gs.player == null:
		return

	var pushed_player_consequences: int = 0
	for raw_row in _get_player_faction_consequence_feed_rows():
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = raw_row
		var text: String = str(row.get("text", "")).strip_edges()
		if text == "":
			continue
		gs.push_world_feed(text, {
			"npc_id": int(gs.player.id),
			"relation_label": "Me",
			"personally_relevant": true,
			"category": str(row.get("category", "faction")),
			"event_name": str(row.get("event_name", "player_faction_consequence")),
			"source": "world_feed_engine",
			"consequence_key": str(row.get("consequence_key", "")),
			"faction_name": str(row.get("faction_name", ""))
		})
		pushed_player_consequences += 1
		if pushed_player_consequences >= 2:
			break

	var player_fragments: Array = _asset_world_feed_fragments_for_owner(gs.player)
	var pushed_player: int = 0
	for raw_fragment in player_fragments:
		if typeof(raw_fragment) != TYPE_DICTIONARY:
			continue
		var fragment: Dictionary = raw_fragment
		var text: String = str(fragment.get("text", "")).strip_edges()
		if text == "":
			continue
		gs.push_world_feed(text, {
			"npc_id": int(gs.player.id),
			"relation_label": "Me",
			"personally_relevant": true,
			"category": "assets",
			"event_name": "asset_yearly_world_feed",
			"source": "world_feed_engine"
		})
		pushed_player += 1
		if pushed_player >= 2:
			break

	var seen_owner_ids: Dictionary = {}
	if gs.property_engine != null:
		for raw_id in gs.property_engine.properties.keys():
			seen_owner_ids [int(raw_id)] = true
	if gs.vehicle_engine != null:
		for raw_id in gs.vehicle_engine.vehicles.keys():
			seen_owner_ids [int(raw_id)] = true
	if gs.artifacts_engine != null and typeof(gs.artifacts_engine.ownership) == TYPE_DICTIONARY:
		for raw_id in gs.artifacts_engine.ownership.keys():
			seen_owner_ids [int(raw_id)] = true
	if gs.dragonballs_engine != null and typeof(gs.dragonballs_engine.ownership) == TYPE_DICTIONARY:
		for raw_id in gs.dragonballs_engine.ownership.keys():
			seen_owner_ids [int(raw_id)] = true
	if gs.red_bonnet_engine != null:
		var bonnet_owner_id: int = int(gs.red_bonnet_engine.owner_id)
		if bonnet_owner_id > 0:
			seen_owner_ids [bonnet_owner_id] = true

	var pushed_related: int = 0
	for raw_owner_id in seen_owner_ids.keys():
		var owner_id: int = int(raw_owner_id)
		if owner_id == int(gs.player.id):
			continue
		var owner: Person = gs.get_or_reactivate_npc_by_id(owner_id)
		if owner == null or not owner.alive:
			continue
		if not _is_personally_relevant_npc(gs.player, owner):
			continue
		var fragments: Array = _asset_world_feed_fragments_for_owner(owner)
		for raw_fragment in fragments:
			if typeof(raw_fragment) != TYPE_DICTIONARY:
				continue
			var fragment: Dictionary = raw_fragment
			var text: String = str(fragment.get("text", "")).strip_edges()
			if text == "":
				continue
			gs.push_world_feed(text, {
				"npc_id": int(owner.id),
				"relation_label": _resolve_relationship_label(gs.player, owner),
				"personally_relevant": true,
				"category": "assets",
				"event_name": "asset_yearly_world_feed",
				"source": "world_feed_engine"
			})
			pushed_related += 1
			break
		if pushed_related >= 3:
			break
func _get_player_faction_consequence_feed_rows() -> Array:
	var out: Array = []
	if gs == null or gs.player == null:
		return out

	var bias_raw: Variant = gs.transient_scenario_biases.get(int(gs.player.id), {})
	var bias_bucket: Dictionary = {}
	if typeof(bias_raw) == TYPE_ARRAY:
		var bias_arr: Array = bias_raw
		if not bias_arr.is_empty() and typeof(bias_arr [0]) == TYPE_DICTIONARY:
			bias_bucket = bias_arr [0]
	elif typeof(bias_raw) == TYPE_DICTIONARY:
		bias_bucket = bias_raw

	var faction_pressure_raw: Variant = bias_bucket.get("faction_pressure", {})
	var faction_pressure: Dictionary = faction_pressure_raw if typeof(faction_pressure_raw) == TYPE_DICTIONARY else {}
	var consequences_raw: Variant = faction_pressure.get("player_consequences", [])
	var consequences: Array = consequences_raw if typeof(consequences_raw) == TYPE_ARRAY else []

	var sorted_rows: Array = []
	for raw_consequence in consequences:
		if typeof(raw_consequence) != TYPE_DICTIONARY:
			continue
		var consequence: Dictionary = raw_consequence.duplicate(true)
		consequence ["_sort"] = float(consequence.get("weight", 0.0))
		sorted_rows.append(consequence)

	sorted_rows.sort_custom(func (a, b): return float(a.get("_sort", 0.0)) > float(b.get("_sort", 0.0)))

	for raw_row in sorted_rows:
		var row: Dictionary = raw_row
		var text: String = _world_text_from_player_consequence(row)
		if text == "":
			continue
		out.append({
			"text": text,
			"category": "faction",
			"event_name": "player_faction_consequence",
			"consequence_key": str(row.get("key", "")),
			"faction_name": str(row.get("faction_name", ""))
		})

	return out


func _world_text_from_player_consequence(consequence: Dictionary) -> String:
	var key: String = str(consequence.get("key", "")).strip_edges()
	var faction_name: String = str(consequence.get("faction_name", "")).strip_edges()

	match key:
		"career_instability":
			if faction_name.find("'s company") != -1:
				return "\n💼\n Your boss's company is collapsing."
			if faction_name != "":
				return "\n💼\n %s is collapsing around your work life." % faction_name
			return "\n💼\n Your workplace is collapsing."
		"dynasty_instability":
			return "\n👑\n Your family dynasty is losing power."
		"housing_instability":
			return "\n🏘\n Your neighborhood is tightening around you."
		"local_surveillance":
			return "\n👁\n Your block is getting watched."
		_:
			if faction_name != "":
				return "\n🧭\n %s is pressing directly on your life this year." % faction_name
			return "\n🧭\n Faction pressure is closing in on your life this year."

func _resolve_relationship_label(player: Person, npc: Person) -> String:
	if player == null or npc == null:
		return "Related"
	if int(player.id) == int(npc.id):
		return "Me"
	if gs != null and gs.relationship_engine != null and gs.relationship_engine.has_method("get_relationship_label"):
		var resolved = gs.relationship_engine.call("get_relationship_label", player, npc)
		var resolved_text: String = str(resolved).strip_edges()
		if resolved_text != "":
			return resolved_text
	return _fallback_relationship_label(player, npc)

func _fallback_relationship_label(player: Person, npc: Person) -> String:
	if player == null or npc == null:
		return "Related"
	var npc_id: int = int(npc.id)
	if npc_id in player.parents:
		return "Father" if str(npc.gender) == "Male" else "Mother"
	if npc_id in player.children:
		return "Son" if str(npc.gender) == "Male" else "Daughter"
	if _is_current_partner(player, npc):
		return "Husband" if str(npc.gender) == "Male" else "Wife"
	if _shares_parent(player, npc):
		return "Brother" if str(npc.gender) == "Male" else "Sister"
	if _is_grandparent(player, npc):
		return "Grandfather" if str(npc.gender) == "Male" else "Grandmother"
	if _is_grandchild(player, npc):
		return "Grandson" if str(npc.gender) == "Male" else "Granddaughter"
	if _is_great_grandparent(player, npc):
		return "Great-Grandfather" if str(npc.gender) == "Male" else "Great-Grandmother"
	if _is_great_grandchild(player, npc):
		return "Great-Grandson" if str(npc.gender) == "Male" else "Great-Granddaughter"
	return "Relative"

func _is_current_partner(a: Person, b: Person) -> bool:
	if a == null or b == null:
		return false

	var a_partner_id: int = -1
	var b_partner_id: int = -1

	for raw_prop in a.get_property_list():
		if typeof(raw_prop) != TYPE_DICTIONARY:
			continue
		if str(raw_prop.get("name", "")) == "partner_id":
			a_partner_id = int(a.get("partner_id"))
			break

	for raw_prop in b.get_property_list():
		if typeof(raw_prop) != TYPE_DICTIONARY:
			continue
		if str(raw_prop.get("name", "")) == "partner_id":
			b_partner_id = int(b.get("partner_id"))
			break

	if a_partner_id == int(b.id):
		return true
	if b_partner_id == int(a.id):
		return true

	if gs != null and gs.has_method("get_valid_partner"):
		var a_partner: Person = gs.get_valid_partner(a, true, true)
		if a_partner != null and int(a_partner.id) == int(b.id):
			return true

		var b_partner: Person = gs.get_valid_partner(b, true, true)
		if b_partner != null and int(b_partner.id) == int(a.id):
			return true

	return false

func _shares_parent(a: Person, b: Person) -> bool:
	if a == null or b == null:
		return false
	for pid in a.parents:
		if int(pid) <= 0:
			continue
		if int(pid) in b.parents:
			return true
	return false

func _is_grandparent(player: Person, npc: Person) -> bool:
	if player == null or npc == null or gs == null:
		return false
	for pid in player.parents:
		var parent: Person = gs.get_or_reactivate_npc_by_id(int(pid))
		if parent == null:
			continue
		if int(npc.id) in parent.parents:
			return true
	return false

func _is_grandchild(player: Person, npc: Person) -> bool:
	if player == null or npc == null or gs == null:
		return false
	for cid in player.children:
		var child: Person = gs.get_or_reactivate_npc_by_id(int(cid))
		if child == null:
			continue
		if int(npc.id) in child.children:
			return true
	return false

func _is_great_grandparent(player: Person, npc: Person) -> bool:
	if player == null or npc == null or gs == null:
		return false
	for pid in player.parents:
		var parent: Person = gs.get_or_reactivate_npc_by_id(int(pid))
		if parent == null:
			continue
		for gpid in parent.parents:
			var grandparent: Person = gs.get_or_reactivate_npc_by_id(int(gpid))
			if grandparent == null:
				continue
			if int(npc.id) in grandparent.parents:
				return true
	return false

func _is_great_grandchild(player: Person, npc: Person) -> bool:
	if player == null or npc == null or gs == null:
		return false
	for cid in player.children:
		var child: Person = gs.get_or_reactivate_npc_by_id(int(cid))
		if child == null:
			continue
		for gcid in child.children:
			var grandchild: Person = gs.get_or_reactivate_npc_by_id(int(gcid))
			if grandchild == null:
				continue
			if int(npc.id) in grandchild.children:
				return true
	return false
func _asset_world_feed_fragments_for_owner(owner: Person) -> Array:
	var out: Array = []
	if owner == null or gs == null:
		return out

	if gs.property_engine != null:
		for raw_fragment in gs.property_engine.get_yearly_event_fragments_for_owner(owner):
			if typeof(raw_fragment) != TYPE_DICTIONARY:
				continue
			out.append(raw_fragment)

	if gs.vehicle_engine != null:
		for raw_fragment in gs.vehicle_engine.get_yearly_event_fragments_for_owner(owner):
			if typeof(raw_fragment) != TYPE_DICTIONARY:
				continue
			out.append(raw_fragment)

	if gs.artifacts_engine != null and gs.artifacts_engine.has_method("get_yearly_event_fragments_for_owner"):
		for raw_fragment in gs.artifacts_engine.get_yearly_event_fragments_for_owner(owner):
			if typeof(raw_fragment) != TYPE_DICTIONARY:
				continue
			out.append(raw_fragment)

	if gs.dragonballs_engine != null and gs.dragonballs_engine.has_method("get_yearly_event_fragments_for_owner"):
		for raw_fragment in gs.dragonballs_engine.get_yearly_event_fragments_for_owner(owner):
			if typeof(raw_fragment) != TYPE_DICTIONARY:
				continue
			out.append(raw_fragment)

	if gs.red_bonnet_engine != null and gs.red_bonnet_engine.has_method("get_yearly_event_fragments_for_owner"):
		for raw_fragment in gs.red_bonnet_engine.get_yearly_event_fragments_for_owner(owner):
			if typeof(raw_fragment) != TYPE_DICTIONARY:
				continue
			out.append(raw_fragment)

	return out


func _world_text_from_asset_fragment(owner: Person, fragment: Dictionary) -> String:
	if owner == null:
		return ""

	if owner == gs.player:
		return str(fragment.get("text", "")).strip_edges()

	var full_name: String = ("%s %s" % [owner.first_name, owner.last_name]).strip_edges()
	var world_text: String = str(fragment.get("world_text", "")).strip_edges()
	if world_text != "":
		if world_text.find("%s") != -1:
			return world_text % full_name
		return world_text

	return str(fragment.get("text", "")).strip_edges()



func handle_event(npc: Person, event_text: String):
	if event_text == "":
		return

	if npc == gs.player:
		return

	var player = gs.player
	var is_personally_relevant = _is_personally_relevant_npc(player, npc)
	if _is_routine_child_minor_illness(npc, event_text) and not is_personally_relevant:
		return

	if _is_school_related_text(event_text):
		if not _is_school_relevant_to_player(player, npc):
			return

	if not is_personally_relevant:
		var unrelated_count:= 0
		for f in gs.world_feed:
			var entry = gs.normalize_world_feed_entry(f)
			if not bool(entry.get("personally_relevant", false)):
				unrelated_count += 1

		if unrelated_count >= 5:
			return

	var relation = _get_relation_label(player, npc)
	var final_text: String = _world_feed_force_third_person_text(npc, event_text)
	if final_text == "":
		return

	var category = _category_from_text(final_text)

	gs.push_world_feed(final_text, {
		"npc_id": npc.id,
		"relation_label": relation,
		"personally_relevant": is_personally_relevant,
		"category": category,
		"event_name": "narrative_world_feed",
		"source": "world_feed_engine",
		"public_perspective": "third_person",
	})
func _world_feed_force_third_person_text(npc: Person, event_text: String) -> String:
	var out: String = _strip_world_feed_first_person_tone_tail(str(event_text).strip_edges())
	if out == "":
		return ""

	var subject_name: String = _world_feed_public_name_for_npc(npc)
	if subject_name == "":
		subject_name = "Someone"

	var lower: String = out.to_lower()

	if lower.begins_with("i "):
		out = subject_name + " " + out.substr(2)
	elif lower.begins_with("i'm "):
		out = subject_name + " is " + out.substr(4)
	elif lower.begins_with("i am "):
		out = subject_name + " is " + out.substr(5)
	elif lower.begins_with("my "):
		out = subject_name + "'s " + out.substr(3)
	elif lower.begins_with("me "):
		out = subject_name + " " + out.substr(3)
	elif lower.begins_with("you "):
		out = subject_name + " " + out.substr(4)
	elif lower.begins_with("your "):
		out = subject_name + "'s " + out.substr(5)

	out = out.replace(" I hated how much it still mattered.", "")
	out = out.replace(". I hated how much it still mattered.", ".")
	out = out.replace(" I barely knew what to feel.", "")
	out = out.replace(". I barely knew what to feel.", ".")
	out = out.replace(" Somehow, I still felt like this would not be the end of my story.", "")
	out = out.replace(". Somehow, I still felt like this would not be the end of my story.", ".")
	out = out.replace(" I tried to understand it through faith.", "")
	out = out.replace(". I tried to understand it through faith.", ".")

	if out != "" and not out.ends_with(".") and not out.ends_with("!") and not out.ends_with("?"):
		out += "."

	return out.strip_edges()


func _strip_world_feed_first_person_tone_tail(text: String) -> String:
	var out: String = str(text).strip_edges()
	if out == "":
		return ""

	var forbidden_tails: Array = [
		" I hated how much it still mattered.",
		". I hated how much it still mattered.",
		" I barely knew what to feel.",
		". I barely knew what to feel.",
		" Somehow, I still felt like this would not be the end of my story.",
		". Somehow, I still felt like this would not be the end of my story.",
		" I tried to understand it through faith.",
		". I tried to understand it through faith."
	]

	for raw_tail in forbidden_tails:
		var tail: String = str(raw_tail)
		if out.ends_with(tail):
			out = out.substr(0, out.length() - tail.length()).strip_edges()

	return out


func _world_feed_public_name_for_npc(npc: Person) -> String:
	if npc == null:
		return "Someone"

	var full_name: String = ("%s %s" % [str(npc.first_name), str(npc.last_name)]).strip_edges()
	if full_name != "":
		return full_name

	var first_name: String = str(npc.first_name).strip_edges()
	if first_name != "":
		return first_name

	return "Someone"



func _is_personally_relevant_npc(player: Person, npc: Person) -> bool:
	if player == null or npc == null:
		return false

	return (
		npc.id in player.parents or
		player.id in npc.parents or
		(npc.parents == player.parents and npc.id != player.id) or
		npc.id in player.friends or
		player.partner == npc or
		npc.id in player.ex_partners
	)





func _is_school_related_text(event_text: String) -> bool:
	var lower = event_text.to_lower()

	return (
		lower.find("school") != -1 or
		lower.find("classmate") != -1 or
		lower.find("teacher") != -1 or
		lower.find("student") != -1 or
		lower.find("bully") != -1 or
		lower.find("bullied") != -1 or
		lower.find("lessons") != -1 or
		lower.find("class ") != -1 or
		lower.find("class.") != -1 or
		lower.find("rumor spread through the school") != -1 or
		lower.find("another school year passed") != -1
	)





func _is_school_relevant_to_player(player: Person, npc: Person) -> bool:
	if player == null or npc == null:
		return false


	if _is_personally_relevant_npc(player, npc):
		return true


	if gs.school_engine != null and gs.school_engine.are_classmates(player, npc):
		return true

	return false

func _get_relation_label(player: Person, npc: Person) -> String:
	if player == null or npc == null:
		return ""

	var player_parent_ids: Array = []
	var npc_parent_ids: Array = []
	var player_friend_ids: Array = []
	var player_ex_partner_ids: Array = []

	if typeof(player.parents) == TYPE_ARRAY:
		player_parent_ids = player.parents
	if typeof(npc.parents) == TYPE_ARRAY:
		npc_parent_ids = npc.parents
	if typeof(player.friends) == TYPE_ARRAY:
		player_friend_ids = player.friends
	if typeof(player.ex_partners) == TYPE_ARRAY:
		player_ex_partner_ids = player.ex_partners


	if npc.id in player_parent_ids:
		return "My father" if npc.gender == "Male" else "My mother"
	if player.id in npc_parent_ids:
		return "My son" if npc.gender == "Male" else "My daughter"
	if npc_parent_ids == player_parent_ids and npc.id != player.id:
		return "My brother" if npc.gender == "Male" else "My sister"


	if npc.id in player_friend_ids:
		return "My friend"


	if player.partner == npc:
		return "My partner"
	if npc.id in player_ex_partner_ids:
		return "My ex"


	return ""

func handle_event_from_bus(payload: Dictionary):
	if gs == null:
		return
	var mailbox_entry: Dictionary = _world_feed_mailbox_entry_from_typed_packet(payload)
	if not mailbox_entry.is_empty():
		var raw_entry: Variant = mailbox_entry.get("entry", {})
		var entry: Dictionary = raw_entry if typeof(raw_entry) == TYPE_DICTIONARY else {}
		var suppress_entry_world_feed: bool = bool(entry.get("suppress_world_feed", false)) or bool(payload.get("suppress_world_feed", false))
		if suppress_entry_world_feed:
			return
		var entry_text: String = str(entry.get("text", "")).strip_edges()
		if entry_text != "":
			gs.push_world_feed(entry_text, entry)
		return

	var suppress_world_feed: bool = bool(payload.get("suppress_world_feed", false))
	if not suppress_world_feed:
		var source_name: String = str(payload.get("source", "")).strip_edges()
		var show_move_in_world_feed: bool = bool(payload.get("show_move_in_world_feed", false))
		if source_name in ["migration_engine", "family_control_engine"] and not show_move_in_world_feed:
			suppress_world_feed = true
	if suppress_world_feed:
		return

	var npc_id = payload.get("npc_id", -1)
	var text = payload.get("text", "")
	var npc = gs.get_npc_by_id(npc_id)
	if npc == null:
		return
	handle_event(npc, text)
func build_runtime_mailbox_entries_from_typed_packets(delta_packets: Array) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	var raw_seen: Dictionary = {}

	for raw_packet in delta_packets:
		if typeof(raw_packet) != TYPE_DICTIONARY:
			continue

		var packet: Dictionary = raw_packet
		var raw_key: String = _fast_world_feed_packet_key(packet)
		if raw_key != "" and raw_seen.has(raw_key):
			continue
		if raw_key != "":
			raw_seen [raw_key] = true

		var mailbox_entry: Dictionary = _world_feed_mailbox_entry_from_typed_packet(packet)
		if mailbox_entry.is_empty():
			continue

		var mailbox_key: String = str(mailbox_entry.get("mailbox_key", "")).strip_edges()
		if mailbox_key != "" and seen.has(mailbox_key):
			continue
		if mailbox_key != "":
			seen [mailbox_key] = true

		out.append(mailbox_entry)

	return out
func _world_feed_entry_dedupe_key(entry: Dictionary) -> String:
	if typeof(entry) != TYPE_DICTIONARY or entry.is_empty():
		return ""

	var fallback_year: int = int(gs.year) if gs != null else 0

	return "%s|%s|%s|%s" % [
		str(entry.get("world_text", entry.get("text", ""))).strip_edges(),
		str(entry.get("player_text", "")).strip_edges(),
		str(int(entry.get("npc_id", -1))),
		str(int(entry.get("year", fallback_year)))
	]

func _fast_world_feed_packet_key(packet: Dictionary) -> String:

	if typeof(packet) != TYPE_DICTIONARY or packet.is_empty():
		return ""
	var packet_type: String = str(packet.get("type", "")).strip_edges()
	if packet_type == "world_feed_entry":
		var raw_entry = packet.get("entry", {})
		if typeof(raw_entry) != TYPE_DICTIONARY:
			return ""
		return _world_feed_entry_dedupe_key(raw_entry)
	var world_feed_text: String = str(packet.get("world_feed_text", "")).strip_edges()
	if world_feed_text == "" and bool(packet.get("queue_world_feed", false)):
		world_feed_text = str(packet.get("text", "")).strip_edges()
	if world_feed_text == "":
		return ""
	return "%s|%s|%s|%s" % [
		packet_type,
		str(int(packet.get("npc_id", -1))),
		str(int(packet.get("year", gs.year if gs != null else 0))),
		world_feed_text
	]
func _world_feed_mailbox_entry_from_typed_packet(packet: Dictionary) -> Dictionary:
	if gs == null or typeof(packet) != TYPE_DICTIONARY or packet.is_empty():
		return {}

	var packet_type: String = str(packet.get("type", "")).strip_edges()
	if packet_type == "":
		return {}

	if packet_type == "world_feed_entry":
		var raw_entry = packet.get("entry", {})
		if typeof(raw_entry) != TYPE_DICTIONARY or raw_entry.is_empty():
			return {}
		var normalized_entry: Dictionary = gs.normalize_world_feed_entry(raw_entry)
		return {
			"type": "world_feed_entry",
			"entry": normalized_entry,
			"mailbox_key": "world_feed|%s|%s|%s" % [
				str(normalized_entry.get("event_name", "")),
				str(normalized_entry.get("npc_id", -1)),
				str(normalized_entry.get("text", ""))
			]
		}

	var npc_id: int = int(packet.get("npc_id", -1))
	var npc: Person = gs.get_npc_by_id(npc_id) if npc_id > 0 else null

	var feed_text: String = str(packet.get("world_feed_text", "")).strip_edges()
	if feed_text == "" and bool(packet.get("queue_world_feed", false)):
		feed_text = str(packet.get("text", "")).strip_edges()

	if feed_text == "":
		match packet_type:
			"death":
				var dead_name: String = str(packet.get("name", npc.name if npc != null else "Someone")).strip_edges()
				if dead_name == "":
					dead_name = "Someone"
				feed_text = "💀 %s died." % dead_name
			"moved":
				var mover_name: String = str(packet.get("name", npc.name if npc != null else "Someone")).strip_edges()
				if mover_name == "":
					mover_name = "Someone"
				var destination: String = str(packet.get("to_label", packet.get("to", ""))).strip_edges()
				if destination != "":
					feed_text = "📦 %s moved to %s." % [mover_name, destination]
			"place_shift":
				var place_name: String = str(packet.get("name", npc.name if npc != null else "Someone")).strip_edges()
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
						feed_text = "📍 %s's world shifted from %s to %s." % [place_name, from_label, to_label]
					else:
						feed_text = "📍 %s is now tied to %s." % [place_name, to_label]

	if feed_text == "":
		return {}

	var relation_label: String = str(packet.get("relation_label", "")).strip_edges()
	if relation_label == "" and gs.player != null and npc != null:
		relation_label = _get_relation_label(gs.player, npc)

	var personally_relevant: bool = bool(packet.get("personally_relevant", false))
	if not personally_relevant and gs.player != null:
		if npc != null and (int(npc.id) == int(gs.player.id) or relation_label != ""):
			personally_relevant = true
		elif npc != null and _is_school_relevant_to_player(gs.player, npc):
			personally_relevant = true

	var entry: Dictionary = gs.make_world_feed_entry(feed_text, {
		"year": int(packet.get("year", gs.year)),
		"era": str(packet.get("era", gs.era.name if gs.era != null else "")),
		"npc_id": npc_id,
		"relation_label": relation_label,
		"personally_relevant": personally_relevant,
		"category": str(packet.get("category", "runtime")),
		"event_name": str(packet.get("event_name", packet_type)),
		"source": str(packet.get("source", "typed_phase_packet"))
	})

	return {
		"type": "world_feed_entry",
		"entry": entry,
		"mailbox_key": "world_feed|%s|%s|%s" % [
			str(entry.get("event_name", "")),
			str(entry.get("npc_id", -1)),
			str(entry.get("text", ""))
		]
	}
func _category_from_text(event_text: String) -> String:
	var lower = event_text.to_lower()

	if _is_school_related_text(event_text):
		return "school"
	if lower.find("married") != -1 or lower.find("divorc") != -1 or lower.find("partner") != -1:
		return "relationship"
	if lower.find("moved") != -1:
		return "movement"
	if lower.find("died") != -1:
		return "death"
	if lower.find("artifact") != -1 or lower.find("stone") != -1 or lower.find("bonnet") != -1:
		return "artifact"
	if lower.find("famous") != -1 or lower.find("recognition") != -1:
		return "fame"

	return "general"
func _apply_relation_pov(event_text: String, relation: String, npc: Person) -> String:
	if relation == "" or npc == null:
		return event_text

	var full_name = ("%s %s" % [npc.first_name, npc.last_name]).strip_edges()
	var first_name = npc.first_name



	if event_text.begins_with("At "):
		var full_marker = ", %s " % full_name
		if event_text.find(full_marker) != -1:
			return event_text.replace(full_marker, ", %s " % relation)

		var first_marker = ", %s " % first_name
		if event_text.find(first_marker) != -1:
			return event_text.replace(first_marker, ", %s " % relation)

	if event_text.begins_with(full_name + " "):
		return relation + event_text.substr(full_name.length())

	if event_text.begins_with(first_name + " "):
		return relation + event_text.substr(first_name.length())



	return event_text
func _is_routine_child_minor_illness(npc: Person, event_text: String) -> bool:
	if npc == null:
		return false
	if npc.age >= 18:
		return false

	var lower:= event_text.to_lower()
	return lower.find("caught a minor illness") != -1