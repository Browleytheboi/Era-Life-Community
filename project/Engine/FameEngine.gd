extends Resource
class_name FameEngine

var gs

func _init(_gs):
	gs = _gs

var FAME_JOBS = {
	"Ancient Era": ["Gladiator", "Prophet", "Poet", "Warlord", "Royal Scribe"],
	"Medieval Era": ["Knight", "Bard", "Court Magician", "Noble Hero"],
	"Industrial Era": ["Stage Actor", "Opera Singer", "Inventor", "Explorer"],
	"Modern Era": ["Actor", "Pop Star", "Influencer", "Athlete", "Politician", "Boxer"],
	"Future Era": ["HoloStar", "Starship Racer", "Galactic Diplomat", "Boxer"],
}

var fame_decay_per_year = 5

func yearly_fame_tick(_payload:= {}):
	var pending_family_fame: Dictionary = {}
	for npc in gs.npcs:
		if npc == null:
			continue
		if "RedBonnetFameForever" in npc.traits:
			npc.fame = 100
			npc.fame_tier = "Legend"
			continue
		if int(npc.fame) >= 30:
			_queue_family_fame_ripple_from_source(npc, pending_family_fame)
		if npc.fame > 0:
			npc.fame = max(npc.fame - fame_decay_per_year, 0)
		_update_fame_tier(npc)

	for raw_id in pending_family_fame.keys():
		var target_id:= int(raw_id)
		if target_id <= 0:
			continue
		var target: Person = gs.get_npc_by_id(target_id)
		if target == null:
			continue
		var inherited_floor:= int(pending_family_fame.get(raw_id, 0))
		if inherited_floor <= int(target.fame):
			_update_fame_tier(target)
			continue
		target.fame = clamp(max(int(target.fame), inherited_floor), 0, 100)
		if str(target.fame_job).strip_edges() == "" and int(target.fame) >= 10:
			target.fame_job = "Famous Relative"
		_update_fame_tier(target)
func _queue_family_fame_ripple_from_source(source: Person, pending: Dictionary) -> void:
	if source == null or not source.alive:
		return

	var inherited_floor:= 0
	if int(source.fame) >= 90:
		inherited_floor = 35
	elif int(source.fame) >= 60:
		inherited_floor = 22
	elif int(source.fame) >= 30:
		inherited_floor = 12
	else:
		return

	var target_ids: Array = []
	for pid in source.parents:
		target_ids.append(int(pid))
	for cid in source.children:
		target_ids.append(int(cid))
	if source.partner != null:
		target_ids.append(int(source.partner.id))

	for pid in source.parents:
		var parent: Person = gs.get_npc_by_id(int(pid))
		if parent == null:
			continue
		for sid in parent.children:
			target_ids.append(int(sid))

	var seen: Dictionary = {}
	for raw_id in target_ids:
		var target_id:= int(raw_id)
		if target_id <= 0 or target_id == int(source.id):
			continue
		if seen.has(target_id):
			continue
		seen [target_id] = true
		pending [target_id] = max(int(pending.get(target_id, 0)), inherited_floor)

func _update_fame_tier(npc):
	if npc == null:
		return

	if "RedBonnetFameForever" in npc.traits:
		npc.fame = 100
		npc.fame_tier = "Legend"
		return

	if npc.fame >= 90:
		npc.fame_tier = "Legend"
	elif npc.fame >= 60:
		npc.fame_tier = "Global"
	elif npc.fame >= 30:
		npc.fame_tier = "National"
	elif npc.fame >= 10:
		npc.fame_tier = "Local"
	else:
		npc.fame_tier = "None"

func give_fame(npc: Person, amount: int):
	npc.fame = clamp(npc.fame + amount, 0, 100)
	_update_fame_tier(npc)

func snapshot_public_fame_state(npc: Person) -> Dictionary:
	if npc == null:
		return {}
	return {
		"fame": int(npc.fame),
		"fame_tier": str(npc.fame_tier),
		"fame_job": str(npc.fame_job),
		"scandal": int(npc.scandal),
		"paparazzi_heat": int(npc.paparazzi_heat)
	}

func restore_public_fame_state(npc: Person, snapshot: Dictionary) -> void:
	if npc == null:
		return
	if typeof(snapshot) != TYPE_DICTIONARY or snapshot.is_empty():
		_update_fame_tier(npc)
		return
	npc.fame = int(snapshot.get("fame", npc.fame))
	npc.fame_tier = str(snapshot.get("fame_tier", npc.fame_tier))
	npc.fame_job = str(snapshot.get("fame_job", npc.fame_job))
	npc.scandal = int(snapshot.get("scandal", npc.scandal))
	npc.paparazzi_heat = int(snapshot.get("paparazzi_heat", npc.paparazzi_heat))
	_update_fame_tier(npc)
	if snapshot.has("fame_tier"):
		npc.fame_tier = str(snapshot.get("fame_tier", npc.fame_tier))

func assign_child_fame(arg):
	var npc: Person = null



	if typeof(arg) == TYPE_DICTIONARY:
		var id = arg.get("npc_id", -1)
		npc = gs.get_npc_by_id(id)



	elif arg is Person:
		npc = arg
	if npc == null:
		return

	var parents = []
	for pid in npc.parents:
		var p = gs.get_npc_by_id(pid)
		if p != null:
			parents.append(p)

	var inherited_fame:= 0
	for p in parents:
		var parent_fame:= int(p.fame)
		if parent_fame >= 90:
			inherited_fame = max(inherited_fame, randi_range(25, 40))
		elif parent_fame >= 60:
			inherited_fame = max(inherited_fame, randi_range(15, 28))
		elif parent_fame >= 30:
			inherited_fame = max(inherited_fame, randi_range(5, 16))

	if inherited_fame > 0:
		npc.fame = max(int(npc.fame), inherited_fame)
		if str(npc.fame_job).strip_edges() == "":
			npc.fame_job = "Celebrity Child"
		_update_fame_tier(npc)

func random_npc_becomes_famous():
	if randi() % 3000 == 0:
		var candidates = []
		for npc in gs.npcs:
			if npc.age >= 16 and npc.fame == 0:
				candidates.append(npc)

		if candidates.size() == 0:
			return

		var chosen = candidates [randi() % candidates.size()]
		give_fame(chosen, randi_range(20, 60))

		var pool = FAME_JOBS.get(gs.era.name, ["Performer"])
		chosen.fame_job = pool [randi() % pool.size()]

		gs.push_world_feed(
			"🌟 %s %s has risen to fame as a %s." %
			[chosen.first_name, chosen.last_name, chosen.fame_job],
			{
				"npc_id": chosen.id,
				"personally_relevant": false,
				"category": "fame",
				"event_name": ActionEventTypes.FAME_SPIKE,
				"source": "fame_engine"
			}
		)
func _count_infinity_stones_for(npc: Person) -> int:
	if npc == null or gs == null or gs.belongings_engine == null:
		return 0

	var required_stones: Array = [
		"Mind Infinity Stone",
		"Reality Infinity Stone",
		"Space Infinity Stone",
		"Time Infinity Stone",
		"Soul Infinity Stone",
		"Power Infinity Stone"
	]

	var total: int = 0
	for item_name in required_stones:
		if gs.belongings_engine.has_item_named(npc, "Artifacts", str(item_name)):
			total += 1
	return total

func _has_infinity_gauntlet_for(npc: Person) -> bool:
	if npc == null or gs == null or gs.belongings_engine == null:
		return false
	return gs.belongings_engine.has_item_named(npc, "Artifacts", "Infinity Gauntlet")

func _legendary_stone_escalation_line(npc: Person) -> String:
	if _has_infinity_gauntlet_for(npc):
		return "Nothing can stop them now."
	var stone_count: int = _count_infinity_stones_for(npc)
	match stone_count:
		1:
			return "People whisper their name..."
		2:
			return "Rumors spread worldwide..."
		3:
			return "Nations begin to watch them..."
		4:
			return "The world fears what they're becoming..."
		5:
			return "Reality itself fears them."
		6:
			return "The balance of creation bends around them..."
		_:
			return "Their legend keeps spreading."
func _legendary_stone_escalation_line_first_person(npc: Person) -> String:
	if _has_infinity_gauntlet_for(npc):
		return "Nothing can stop me now."

	var stone_count: int = _count_infinity_stones_for(npc)
	match stone_count:
		1:
			return "People whisper my name..."
		2:
			return "Rumors spread worldwide..."
		3:
			return "Nations begin to watch me..."
		4:
			return "The world fears what I'm becoming..."
		5:
			return "Reality itself fears me."
		6:
			return "The balance of creation bends around me..."
		_:
			return "My legend keeps spreading."
func _is_player_relic_moment(npc: Person) -> bool:
	return gs != null and gs.player != null and npc != null and int(npc.id) == int(gs.player.id)
func legendary_signal(payload):
	var npc_id = payload.get("npc_id", -1)
	var npc = gs.get_npc_by_id(npc_id)
	if npc == null:
		return

	var payload_dict: Dictionary = payload if typeof(payload) == TYPE_DICTIONARY else {}
	if bool(payload_dict.get("suppress_fame_signal", false)):
		return

	give_fame(npc, 40)

	var artifact_name: String = str(payload_dict.get("artifact", "")).strip_edges()
	var lower_artifact: String = artifact_name.to_lower()
	var force_non_stone_text: bool = bool(payload_dict.get("force_non_stone_text", false))
	var force_world_feed_only: bool = bool(payload_dict.get("force_world_feed_only", false))
	var use_payload_text: bool = bool(payload_dict.get("use_payload_text", false))

	var is_infinity_stone_event: bool = false
	if not force_non_stone_text:
		is_infinity_stone_event = (
			lower_artifact in ["mind", "reality", "space", "time", "soul", "power"]
			or lower_artifact.findn("infinity stone") != -1
			or _count_infinity_stones_for(npc) > 0
		)

	var is_player_moment: bool = _is_player_relic_moment(npc)
	var text: String = ""

	if use_payload_text:
		text = str(payload_dict.get("text", "")).strip_edges()
	elif is_infinity_stone_event:
		if is_player_moment:
			text = "\n🌌\n My infinity stone discovery has made me famous worldwide. %s" % _legendary_stone_escalation_line_first_person(npc)
		else:
			text = "\n🌌\n %s %s's infinity stone discovery has made them famous worldwide. %s" % [
				npc.first_name,
				npc.last_name,
				_legendary_stone_escalation_line(npc)
			]
	else:
		if is_player_moment:
			text = "\n⭐\n My legendary rise is becoming impossible to ignore."
		else:
			text = "\n⭐\n %s %s's legendary rise is becoming impossible to ignore." % [
				npc.first_name,
				npc.last_name
			]

	if text == "":
		return

	if is_player_moment and not force_world_feed_only:
		if gs.narrative_engine != null:
			gs.narrative_engine.log_event(npc, {
				"type": "text",
				"text": text,
				"source": "fame_engine"
			})
			if npc.memories != null and not npc.memories.has(text):
				npc.memories.append(text)
		elif npc.memories != null and not npc.memories.has(text):
			npc.memories.append(text)
		return

	gs.push_world_feed(
		text,
		{
			"npc_id": npc.id,
			"personally_relevant": npc == gs.player,
			"category": "fame",
			"event_name": ActionEventTypes.FAME_SPIKE,
			"source": "fame_engine",
			"suppress_diary": force_world_feed_only
		}
	)
func on_boxing_fight_completed(payload: Dictionary):
	var npc_id = int(payload.get("winner_id", -1))
	var npc = gs.get_npc_by_id(npc_id)
	if npc == null:
		return

	var method = str(payload.get("result_type", "Decision"))
	if method == "KO":
		give_fame(npc, 6)
	else:
		give_fame(npc, 3)

func on_boxing_title_won(payload: Dictionary):
	var npc_id = int(payload.get("npc_id", -1))
	var npc = gs.get_npc_by_id(npc_id)
	if npc == null:
		return

	give_fame(npc, 12)
	npc.fame_job = "Boxer"
func apply_special_birth_fame(npc: Person) -> void:
	if npc == null:
		return

	if npc.bending_type == "avatar":
		npc.fame = max(npc.fame, 100)
		npc.fame_tier = "Legend"
		npc.social_class = "Mythic"
func nominate_scenarios_for_player(context:= {}) -> Array:
	var out: Array = []
	var player: Person = context.get("player", null)
	if player == null or not player.alive:
		return out
	if int(player.fame) < 10:
		return out

	out.append({
		"id": "fame_attention_%d" % int(context.get("year", 0)),
		"category": "social",
		"era_tags": ["any"],
		"reality_modes": ["realistic", "enhanced", "chaos"],
		"reality_weights": {
			"realistic": 1.05,
			"enhanced": 1.0,
			"chaos": 0.95
		},
		"tone": "public",
		"rarity": 0.65,
		"cooldown_key": "fame:attention",
		"cooldown_years": 2,
		"priority": 11,
		"min_age": 10,
		"max_age": 130,
		"prompt": "The attention around me feels heavier this year. How do I handle it?",
		"followup_hooks": ["fame.attention"],
		"bias_payloads": {},
		"choices": [
			{
				"id": "lean_in",
				"label": "Lean into it and use the spotlight.",
				"journal_line": "I chose to lean into the attention and use the spotlight.",
				"journal_text": "I chose to lean into the attention and use the spotlight.",
				"followup_hooks": ["fame.attention.lean_in"],
				"bias_payloads": {
					"reputation_bias": {
						"public_attention": 10.0
					},
					"desire_bias": {
						"status_drive": 8.0
					},
					"expiry": {
						"years": 1
					}
				}
			},
			{
				"id": "stay_private",
				"label": "Protect my peace and keep a lower profile.",
				"journal_line": "I chose to protect my peace and keep a lower profile.",
				"journal_text": "I chose to protect my peace and keep a lower profile.",
				"followup_hooks": ["fame.attention.private"],
				"bias_payloads": {
					"reputation_bias": {
						"public_attention": -4.0
					},
					"health_bias": {
						"stress_delta": -2.0
					},
					"expiry": {
						"years": 1
					}
				}
			}
		]
	})
	return out