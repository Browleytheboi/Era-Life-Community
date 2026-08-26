extends Resource
class_name AgentMemoryPropagationEngine

var gs















var observer_memories:= {}

const MAX_MEMORIES_PER_AGENT:= 60
const PROPAGATION_BASE_RADIUS:= 3
const MIN_PROPAGATION_CHANCE:= 8
const MAX_PROPAGATION_CHANCE:= 95
const YEARLY_DECAY:= 3


func _init(_gs):
	gs = _gs





func capture_event(payload: Dictionary):
	if typeof(payload) != TYPE_DICTIONARY:
		return

	var fanout_hints_raw: Variant = payload.get("fanout_hints", {})
	var fanout_hints: Dictionary = fanout_hints_raw if typeof(fanout_hints_raw) == TYPE_DICTIONARY else {}
	if bool(fanout_hints.get("skip_agent_memory_propagation", false)):
		return

	var qos_tier: String = _resolve_event_bus_qos_tier(payload)
	if qos_tier == "ambient":
		return

	var event_name = payload.get("event_name", payload.get("type", "event"))
	var subject_id = int(payload.get("npc_id", -1))
	if subject_id == -1:
		return
	var subject = gs.get_npc_by_id(subject_id)
	var subject_facts = gs.get_npc_facts_by_id(subject_id)
	if subject == null and subject_facts == {}:
		return
	var event_id = payload.get("event_id", randi())
	var subject_text: String = str(payload.get("subject_text", "")).strip_edges()
	var observer_text: String = str(payload.get("observer_text", "")).strip_edges()
	var text = ""
	if subject_text != "":
		text = subject_text
	elif subject != null:
		text = _event_text(subject, payload)
	else:
		text = str(payload.get("text", ""))
	if text == "":
		return

	var intensity = 10
	if subject != null:
		intensity = _event_intensity(subject, payload)
	else:
		intensity = _event_intensity_from_facts(subject_facts, payload)
	intensity = _adjust_event_intensity_for_qos(intensity, qos_tier)

	var direct_memory = {
		"id": event_id,
		"year": gs.year,
		"type": event_name,
		"subject_id": subject_id,
		"source_event_id": event_id,
		"text": text,
		"intensity": intensity,
		"credibility": 1.0,
		"firsthand": true,
		"inherited": false
	}

	_store_memory(subject_id, direct_memory)
	if subject != null:
		_apply_memory_effect(subject, subject, direct_memory)

	var observers = []
	if subject != null:
		observers = _get_observers(subject, payload)
	else:
		observers = _get_observers_from_facts(subject_facts)
	observers = _limit_observers_for_qos(observers, qos_tier)

	for observer in observers:
		if observer == null:
			continue
		if observer.id == subject_id:
			continue
		if not observer.alive:
			continue

		var spread_roll = randi() % 100
		var chance = 0
		if subject != null:
			chance = _spread_chance(subject, observer, intensity, payload)
		else:
			chance = _spread_chance_from_facts(subject_facts, observer, intensity)
		chance = _adjust_spread_chance_for_qos(chance, qos_tier)

		if spread_roll < chance:
			var rumor = {}
			if subject != null:
				rumor = _distort_memory_for_observer(subject, observer, direct_memory)
			else:
				rumor = _distort_memory_for_observer_from_facts(subject_facts, observer, direct_memory)
			if observer_text != "":
				rumor ["text"] = observer_text
			_store_memory(observer.id, rumor)
			if subject != null:
				_apply_memory_effect(observer, subject, rumor)
			else:
				_apply_memory_effect_from_subject_id(observer, subject_id, rumor)
func _resolve_event_bus_qos_tier(payload: Dictionary) -> String:
	var qos_tier: String = str(payload.get("qos_tier", "")).strip_edges().to_lower()
	if qos_tier in ["critical", "important", "ambient"]:
		return qos_tier

	var fanout_priority: String = str(payload.get("fanout_priority", "")).strip_edges().to_lower()
	if fanout_priority in ["critical", "high"]:
		return "critical"
	if fanout_priority in ["ambient", "low"]:
		return "ambient"
	return "important"


func _adjust_event_intensity_for_qos(intensity: int, qos_tier: String) -> int:
	if qos_tier == "important":
		return int(clamp(round(float(intensity) * 0.75), 4.0, 100.0))
	return intensity


func _adjust_spread_chance_for_qos(chance: int, qos_tier: String) -> int:
	if qos_tier == "important":
		return int(clamp(round(float(chance) * 0.65), 0.0, 100.0))
	return chance


func _limit_observers_for_qos(observers: Array, qos_tier: String) -> Array:
	if qos_tier != "important":
		return observers

	var limited: Array = []
	var seen: Dictionary = {}

	if gs != null and gs.player != null:
		for raw_observer in observers:
			var observer: Person = raw_observer
			if observer == null:
				continue
			if int(observer.id) == int(gs.player.id):
				limited.append(observer)
				seen [str(int(observer.id))] = true
				break

	for raw_observer in observers:
		var observer: Person = raw_observer
		if observer == null:
			continue
		var observer_key: String = str(int(observer.id))
		if seen.has(observer_key):
			continue
		limited.append(observer)
		seen [observer_key] = true
		if limited.size() >= 16:
			break

	return limited





func yearly_tick(_payload:= {}):
	for observer_id in observer_memories.keys():
		var arr = observer_memories [observer_id]
		var kept:= []
		for mem in arr:
			mem ["intensity"] = max(int(mem.get("intensity", 0)) - YEARLY_DECAY, 0)
			mem ["credibility"] = max(float(mem.get("credibility", 1.0)) - 0.03, 0.1)

			if int(mem ["intensity"]) > 0:
				kept.append(mem)
		observer_memories [observer_id] = kept
		var observer = gs.get_npc_by_id(int(observer_id))
		if observer != null and observer.alive:
			_apply_passive_memory_pressure(observer)

	_propagate_player_faction_consequence_memories()
func _propagate_player_faction_consequence_memories() -> void:
	if gs == null or gs.player == null or not gs.player.alive:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		return

	var stamp_key: String = "__player_faction_consequence_memory_year"
	if int(gs.scenario_state.get(stamp_key, -999999)) == int(gs.year):
		return

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

	var emitted: int = 0
	for raw_row in sorted_rows:
		var row: Dictionary = raw_row
		var subject_text: String = _subject_memory_text_from_player_consequence(row)
		var observer_text: String = _observer_memory_text_from_player_consequence(gs.player, row)
		var fallback_text: String = observer_text if observer_text != "" else subject_text
		if fallback_text == "":
			continue

		capture_event({
			"npc_id": int(gs.player.id),
			"event_name": "player_faction_consequence",
			"event_id": randi(),
			"text": fallback_text,
			"subject_text": subject_text,
			"observer_text": observer_text
		})

		emitted += 1
		if emitted >= 2:
			break

	gs.scenario_state [stamp_key] = int(gs.year)


func _subject_memory_text_from_player_consequence(consequence: Dictionary) -> String:
	var key: String = str(consequence.get("key", "")).strip_edges()

	match key:
		"career_instability":
			return "My boss's company is collapsing."
		"dynasty_instability":
			return "My family dynasty is losing power."
		"housing_instability":
			return "My neighborhood is tightening around me."
		"local_surveillance":
			return "My block is getting watched."
		_:
			return "Faction pressure is closing in on my life."


func _observer_memory_text_from_player_consequence(player: Person, consequence: Dictionary) -> String:
	if player == null:
		return ""

	var full_name: String = ("%s %s" % [player.first_name, player.last_name]).strip_edges()
	if full_name == "":
		full_name = player.first_name

	var key: String = str(consequence.get("key", "")).strip_edges()
	var faction_name: String = str(consequence.get("faction_name", "")).strip_edges()

	match key:
		"career_instability":
			if faction_name != "":
				return "%s's workplace, %s, is collapsing." % [full_name, faction_name]
			return "%s's workplace is collapsing." % full_name
		"dynasty_instability":
			return "%s's family dynasty is losing power." % full_name
		"housing_instability":
			return "%s's neighborhood is tightening." % full_name
		"local_surveillance":
			return "%s's block is getting watched." % full_name
		_:
			if faction_name != "":
				return "%s is under pressure from %s." % [full_name, faction_name]
			return "%s is under visible faction pressure." % full_name





func on_birth(payload: Dictionary):

	var child_id = payload.get("npc_id", -1)
	var child = gs.get_npc_by_id(child_id)
	if child == null:
		return

	for pid in child.parents:
		var parent = gs.get_npc_by_id(pid)
		if parent == null:
			continue

		var inherited = _select_inheritable_memories(parent)
		for mem in inherited:
			var echo = {
				"id": randi(),
				"year": gs.year,
				"type": "family_echo",
				"subject_id": int(mem.get("subject_id", parent.id)),
				"source_event_id": int(mem.get("source_event_id", -1)),
				"text": "My family remembers that " + str(mem.get("text", "")),
				"intensity": max(4, int(float(mem.get("intensity", 10)) / 2.0)),
				"credibility": max(0.35, float(mem.get("credibility", 1.0)) * 0.75),
				"firsthand": false,
				"inherited": true
			}
			_store_memory(child.id, echo)

			var subject = gs.get_npc_by_id(int(echo ["subject_id"]))
			if subject != null:
				_apply_memory_effect(child, subject, echo)





func get_memories_for(observer_id: int) -> Array:
	return observer_memories.get(observer_id, [])


func get_memory_modifier(observer: Person, subject: Person) -> int:
	if observer == null or subject == null:
		return 0

	var arr = observer_memories.get(observer.id, [])
	var delta:= 0

	for mem in arr:
		if int(mem.get("subject_id", -1)) != subject.id:
			continue

		var txt = str(mem.get("text", "")).to_lower()
		var power = int(mem.get("intensity", 0))

		if txt.find("crime") != -1 or txt.find("killed") != -1 or txt.find("shocking") != -1:
			delta -= int(float(power) / 6.0)

		if txt.find("famous") != -1 or txt.find("legendary") != -1 or txt.find("saved") != -1:
			delta += int(float(power) / 8.0)

	return clamp(delta, -35, 35)





func _store_memory(observer_id: int, memory: Dictionary):

	if not observer_memories.has(observer_id):
		observer_memories [observer_id] = []

	observer_memories [observer_id].append(memory)

	if observer_memories [observer_id].size() > MAX_MEMORIES_PER_AGENT:
		observer_memories [observer_id].sort_custom(func (a, b): return int(a.get("year", 0)) > int(b.get("year", 0)))
		observer_memories [observer_id] = observer_memories [observer_id].slice(0, MAX_MEMORIES_PER_AGENT)


	gs.memory_engine.remember(observer_id, str(memory.get("text", "")))


func _event_text(subject: Person, payload: Dictionary) -> String:

	var event_name = payload.get("event_name", "")
	var text = str(payload.get("text", ""))

	if text != "":
		return text

	match event_name:
		ActionEventTypes.NPC_DIED:
			return "%s %s died." % [subject.first_name, subject.last_name]
		ActionEventTypes.NPC_COMMITTED_CRIME:
			return "%s %s committed a crime." % [subject.first_name, subject.last_name]
		ActionEventTypes.ARTIFACT_ACQUIRED:
			return "%s %s acquired a legendary artifact." % [subject.first_name, subject.last_name]
		ActionEventTypes.WISH_MADE:
			return "%s %s made a reality-altering wish." % [subject.first_name, subject.last_name]
		ActionEventTypes.FAME_SPIKE:
			return "%s %s suddenly became widely known." % [subject.first_name, subject.last_name]
		ActionEventTypes.NPC_MOVED:
			return "%s %s moved away." % [subject.first_name, subject.last_name]
		ActionEventTypes.NPC_MARRIED:
			return "%s %s got married." % [subject.first_name, subject.last_name]
		ActionEventTypes.NPC_DIVORCED:
			return "%s %s got divorced." % [subject.first_name, subject.last_name]
		ActionEventTypes.NPC_PARTNERED:
			return "%s %s entered a relationship." % [subject.first_name, subject.last_name]
		ActionEventTypes.PLAYER_GIFTED_NPC:
			return "%s gave someone a meaningful gift." % subject.first_name
		ActionEventTypes.NPC_INSULTED:
			return "%s publicly insulted someone." % subject.first_name
		ActionEventTypes.NPC_FOUGHT:
			return "%s got into a fight." % subject.first_name
		ActionEventTypes.NPC_CHEATED:
			return "%s cheated in a relationship." % subject.first_name
		ActionEventTypes.NPC_BETRAYED:
			return "%s betrayed someone close." % subject.first_name
		ActionEventTypes.HEROIC_RESCUE:
			return "%s rescued someone from danger." % subject.first_name
		ActionEventTypes.SCHOOL_DRAMA:
			return "School drama spread around %s." % subject.first_name
		ActionEventTypes.CRIME_RUMOR_SPREAD:
			return "Rumors spread about %s." % subject.first_name
		ActionEventTypes.PREGNANCY_STARTED:
			return "%s became pregnant." % subject.first_name
		ActionEventTypes.CHILD_BORN_PLAYER_LINE:
			return "%s gave birth." % subject.first_name
		ActionEventTypes.DYNASTY_FEUD_STARTED:
			return "%s's dynasty entered a feud." % subject.first_name
		ActionEventTypes.ROMANCE_BETRAYAL:
			return "%s caused a romantic betrayal." % subject.first_name
	return ""


func _event_intensity(subject: Person, payload: Dictionary) -> int:

	var event_name = payload.get("event_name", "")
	var base:= 10

	match event_name:
		ActionEventTypes.NPC_DIED:
			base = 30
		ActionEventTypes.NPC_COMMITTED_CRIME:
			base = 28
		ActionEventTypes.ARTIFACT_ACQUIRED:
			base = 26
		ActionEventTypes.WISH_MADE:
			base = 35
		ActionEventTypes.FAME_SPIKE:
			base = 20
		ActionEventTypes.NPC_MARRIED:
			base = 16
		ActionEventTypes.NPC_DIVORCED:
			base = 20
		ActionEventTypes.NPC_PARTNERED:
			base = 14
		ActionEventTypes.NPC_MOVED:
			base = 8
		ActionEventTypes.PLAYER_GIFTED_NPC:
			base = 8
		ActionEventTypes.NPC_INSULTED:
			base = 12
		ActionEventTypes.NPC_FOUGHT:
			base = 20
		ActionEventTypes.NPC_CHEATED:
			base = 24
		ActionEventTypes.NPC_BETRAYED:
			base = 26
		ActionEventTypes.HEROIC_RESCUE:
			base = 22
		ActionEventTypes.SCHOOL_DRAMA:
			base = 14
		ActionEventTypes.CRIME_RUMOR_SPREAD:
			base = 18
		ActionEventTypes.PREGNANCY_STARTED:
			base = 16
		ActionEventTypes.CHILD_BORN_PLAYER_LINE:
			base = 24
		ActionEventTypes.DYNASTY_FEUD_STARTED:
			base = 28
		ActionEventTypes.ROMANCE_BETRAYAL:
			base = 26
	if subject.fame_tier == "Legend":
		base += 20
	elif subject.fame_tier == "Global":
		base += 12
	elif subject.fame_tier == "National":
		base += 8

	if subject.social_class in ["Royal", "Noble"]:
		base += 5

	return clamp(base, 5, 100)


func _get_observers(subject: Person, _payload: Dictionary) -> Array:
	var out:= []
	var seen:= {}


	for pid in subject.parents:
		var p = gs.get_npc_by_id(pid)
		if p != null and not seen.has(p.id):
			out.append(p)
			seen [p.id] = true

	for cid in subject.children:
		var c = gs.get_npc_by_id(cid)
		if c != null and not seen.has(c.id):
			out.append(c)
			seen [c.id] = true


	if subject.partner != null and not seen.has(subject.partner.id):
		out.append(subject.partner)
		seen [subject.partner.id] = true


	for oid in gs.social_graph_engine.get_connections(subject.id):
		var other = gs.get_npc_by_id(oid)
		if other != null and not seen.has(other.id):
			out.append(other)
			seen [other.id] = true


	for other in gs.world_space_engine.get_nearby_npcs(subject):
		if other != null and not seen.has(other.id):
			out.append(other)
			seen [other.id] = true


	for npc in gs.npcs:
		if npc == subject:
			continue
		if not npc.alive:
			continue
		if npc.realm_id == subject.realm_id and not seen.has(npc.id):
			if randi() % 100 < 15:
				out.append(npc)
				seen [npc.id] = true

	return out


func _spread_chance(subject: Person, observer: Person, intensity: int, _payload: Dictionary) -> int:

	var chance = intensity
	var tie = gs.social_graph_engine.relationship_strength(subject.id, observer.id)

	chance += int(tie / 3)

	if observer.id in subject.parents or subject.id in observer.parents:
		chance += 25

	if subject.partner == observer:
		chance += 20

	if observer.realm_id == subject.realm_id:
		chance += 8

	if subject.fame > 50:
		chance += 10

	return clamp(chance, MIN_PROPAGATION_CHANCE, MAX_PROPAGATION_CHANCE)


func _distort_memory_for_observer(subject: Person, observer: Person, memory: Dictionary) -> Dictionary:

	var txt = str(memory.get("text", ""))
	var tie = gs.social_graph_engine.relationship_strength(subject.id, observer.id)

	var distorted = txt
	var credibility = 0.9
	var firsthand = false

	if tie < 35 and randi() % 100 < 45:
		distorted = _rumorize(subject, txt)
		credibility = 0.6
	elif tie < 60 and randi() % 100 < 25:
		distorted = _soften_or_exaggerate(subject, txt)
		credibility = 0.75

	return {
		"id": randi(),
		"year": gs.year,
		"type": str(memory.get("type", "event")),
		"subject_id": subject.id,
		"source_event_id": int(memory.get("source_event_id", -1)),
		"text": distorted,
		"intensity": max(3, int(memory.get("intensity", 10)) - randi_range(1, 5)),
		"credibility": credibility,
		"firsthand": firsthand,
		"inherited": false
	}


func _rumorize(subject: Person, _txt: String) -> String:
	var rumors = [
		"People say %s %s was involved in something dangerous." % [subject.first_name, subject.last_name],
		"Rumors spread that %s %s changed everything." % [subject.first_name, subject.last_name],
		"Everyone keeps talking about %s %s." % [subject.first_name, subject.last_name],
		"It is said that %s %s brought chaos wherever they went." % [subject.first_name, subject.last_name]
	]
	return rumors [randi() % rumors.size()]


func _soften_or_exaggerate(subject: Person, txt: String) -> String:
	if randi() % 2 == 0:
		return txt
	return "%s became the center of attention after word spread." % subject.first_name


func _apply_memory_effect(observer: Person, subject: Person, memory: Dictionary):

	if observer == null or subject == null:
		return

	var text = str(memory.get("text", "")).to_lower()
	var intensity = int(memory.get("intensity", 0))

	if text.find("crime") != -1 or text.find("danger") != -1 or text.find("chaos") != -1 or text.find("died") != -1 \
or text.find("insulted") != -1 or text.find("fight") != -1 or text.find("cheated") != -1 \
or text.find("betrayed") != -1 or text.find("feud") != -1:
		observer.affection [subject.id] = observer.affection.get(subject.id, 50) - max(2, int(float(intensity) / 5.0))

	if text.find("famous") != -1 or text.find("legendary") != -1 or text.find("married") != -1 \
or text.find("rescued") != -1 or text.find("gift") != -1:
		observer.affection [subject.id] = observer.affection.get(subject.id, 50) + max(1, int(float(intensity) / 8.0))

	observer.affection [subject.id] = clamp(observer.affection.get(subject.id, 50), 0, 100)


func _apply_passive_memory_pressure(observer: Person):

	var arr = observer_memories.get(observer.id, [])
	if arr.size() == 0:
		return


	arr.sort_custom(func (a, b): return int(a.get("intensity", 0)) > int(b.get("intensity", 0)))
	var top = arr [0]
	var txt = str(top.get("text", "")).to_lower()

	if txt.find("died") != -1:
		observer.mental_health = clamp(observer.mental_health - 0.5, 0, 100)

	if txt.find("legendary") != -1 or txt.find("famous") != -1:
		observer.ambition = clamp(observer.ambition + 1, 0, 100)

	if txt.find("crime") != -1 or txt.find("chaos") != -1:
		observer.motivation = clamp(observer.motivation - 1, 0, 100)


func _select_inheritable_memories(parent: Person) -> Array:
	var arr = observer_memories.get(parent.id, [])
	if arr.size() == 0:
		return []

	var picks:= []
	for mem in arr:
		if int(mem.get("intensity", 0)) >= 18:
			picks.append(mem)

	if picks.size() <= 3:
		return picks

	picks.shuffle()
	return picks.slice(0, 3)
func _event_intensity_from_facts(subject_facts: Dictionary, payload: Dictionary) -> int:
	var event_name = payload.get("event_name", "")
	var base:= 10

	match event_name:
		ActionEventTypes.NPC_DIED:
			base = 30
		ActionEventTypes.NPC_COMMITTED_CRIME:
			base = 28
		ActionEventTypes.ARTIFACT_ACQUIRED:
			base = 26
		ActionEventTypes.WISH_MADE:
			base = 35
		ActionEventTypes.FAME_SPIKE:
			base = 20
		ActionEventTypes.NPC_MARRIED:
			base = 16
		ActionEventTypes.NPC_DIVORCED:
			base = 20
		ActionEventTypes.NPC_PARTNERED:
			base = 14
		ActionEventTypes.NPC_MOVED:
			base = 8
		ActionEventTypes.PLAYER_GIFTED_NPC:
			base = 8
		ActionEventTypes.NPC_INSULTED:
			base = 12
		ActionEventTypes.NPC_FOUGHT:
			base = 20
		ActionEventTypes.NPC_CHEATED:
			base = 24
		ActionEventTypes.NPC_BETRAYED:
			base = 26
		ActionEventTypes.HEROIC_RESCUE:
			base = 22
		ActionEventTypes.SCHOOL_DRAMA:
			base = 14
		ActionEventTypes.CRIME_RUMOR_SPREAD:
			base = 18
		ActionEventTypes.PREGNANCY_STARTED:
			base = 16
		ActionEventTypes.CHILD_BORN_PLAYER_LINE:
			base = 24
		ActionEventTypes.DYNASTY_FEUD_STARTED:
			base = 28
		ActionEventTypes.ROMANCE_BETRAYAL:
			base = 26

	var fame_tier = str(subject_facts.get("fame_tier", "None"))
	if fame_tier == "Legend":
		base += 20
	elif fame_tier == "Global":
		base += 12
	elif fame_tier == "National":
		base += 8

	if str(subject_facts.get("social_class", "")) in ["Royal", "Noble"]:
		base += 5

	return clamp(base, 5, 100)


func _get_observers_from_facts(subject_facts: Dictionary) -> Array:
	var out:= []
	var seen:= {}
	var subject_id = int(subject_facts.get("id", -1))

	for pid in subject_facts.get("parents", []):
		var p = gs.get_npc_by_id(int(pid))
		if p != null and not seen.has(p.id):
			out.append(p)
			seen [p.id] = true

	for cid in subject_facts.get("children", []):
		var c = gs.get_npc_by_id(int(cid))
		if c != null and not seen.has(c.id):
			out.append(c)
			seen [c.id] = true

	var partner_id = int(subject_facts.get("partner_id", -1))
	if partner_id != -1:
		var partner = gs.get_npc_by_id(partner_id)
		if partner != null and not seen.has(partner.id):
			out.append(partner)
			seen [partner.id] = true

	for oid in subject_facts.get("friends", []):
		var other = gs.get_npc_by_id(int(oid))
		if other != null and not seen.has(other.id):
			out.append(other)
			seen [other.id] = true

	for npc in gs.npcs:
		if npc == null or not npc.alive:
			continue
		if npc.id == subject_id:
			continue
		if npc.realm_id == int(subject_facts.get("realm_id", -1)) and not seen.has(npc.id):
			if randi() % 100 < 15:
				out.append(npc)
				seen [npc.id] = true

	return out


func _spread_chance_from_facts(subject_facts: Dictionary, observer: Person, intensity: int) -> int:
	var chance = intensity

	if observer.id in subject_facts.get("parents", []):
		chance += 25
	if int(subject_facts.get("id", -1)) in observer.parents:
		chance += 25
	if observer.id == int(subject_facts.get("partner_id", -1)):
		chance += 20
	if observer.id in subject_facts.get("friends", []):
		chance += 12
	if observer.realm_id == int(subject_facts.get("realm_id", -1)):
		chance += 8
	if int(subject_facts.get("fame", 0)) > 50:
		chance += 10

	return clamp(chance, MIN_PROPAGATION_CHANCE, MAX_PROPAGATION_CHANCE)


func _distort_memory_for_observer_from_facts(subject_facts: Dictionary, observer: Person, memory: Dictionary) -> Dictionary:
	var tie:= 0
	var subject_id = int(subject_facts.get("id", -1))

	if observer.id in subject_facts.get("friends", []):
		tie = 60
	elif observer.id in subject_facts.get("parents", []) or subject_id in observer.parents:
		tie = 80
	elif observer.id == int(subject_facts.get("partner_id", -1)):
		tie = 75

	var distorted = str(memory.get("text", ""))
	var credibility = 0.9

	if tie < 35 and randi() % 100 < 45:
		distorted = _rumorize_from_facts(subject_facts)
		credibility = 0.6
	elif tie < 60 and randi() % 100 < 25:
		distorted = _soften_or_exaggerate_from_facts(subject_facts, distorted)
		credibility = 0.75

	return {
		"id": randi(),
		"year": gs.year,
		"type": str(memory.get("type", "event")),
		"subject_id": subject_id,
		"source_event_id": int(memory.get("source_event_id", -1)),
		"text": distorted,
		"intensity": max(3, int(memory.get("intensity", 10)) - randi_range(1, 5)),
		"credibility": credibility,
		"firsthand": false,
		"inherited": false
	}


func _rumorize_from_facts(subject_facts: Dictionary) -> String:
	var first_name = str(subject_facts.get("first_name", "Unknown"))
	var last_name = str(subject_facts.get("last_name", ""))
	var rumors = [
		"People say %s %s was involved in something dangerous." % [first_name, last_name],
		"Rumors spread that %s %s changed everything." % [first_name, last_name],
		"Everyone keeps talking about %s %s." % [first_name, last_name],
		"It is said that %s %s brought chaos wherever they went." % [first_name, last_name]
	]
	return rumors [randi() % rumors.size()]


func _soften_or_exaggerate_from_facts(subject_facts: Dictionary, txt: String) -> String:
	if randi() % 2 == 0:
		return txt
	return "%s became the center of attention after word spread." % str(subject_facts.get("first_name", "Unknown"))


func _apply_memory_effect_from_subject_id(observer: Person, subject_id: int, memory: Dictionary):
	if observer == null:
		return

	var text = str(memory.get("text", "")).to_lower()
	var intensity = int(memory.get("intensity", 0))

	if text.find("crime") != -1 or text.find("danger") != -1 or text.find("chaos") != -1 or text.find("died") != -1 \
or text.find("insulted") != -1 or text.find("fight") != -1 or text.find("cheated") != -1 \
or text.find("betrayed") != -1 or text.find("feud") != -1:
		observer.affection [subject_id] = observer.affection.get(subject_id, 50) - max(2, int(float(intensity) / 5.0))

	if text.find("famous") != -1 or text.find("legendary") != -1 or text.find("married") != -1 \
or text.find("rescued") != -1 or text.find("gift") != -1:
		observer.affection [subject_id] = observer.affection.get(subject_id, 50) + max(1, int(float(intensity) / 8.0))

	observer.affection [subject_id] = clamp(observer.affection.get(subject_id, 50), 0, 100)