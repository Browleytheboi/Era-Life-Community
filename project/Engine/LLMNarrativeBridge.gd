extends Resource
class_name LLMNarrativeBridge

var gs
var recent_world_events: Array = []
const MAX_RECENT_WORLD_EVENTS:= 25
func _init(_gs):
	gs = _gs

func on_event(payload: Dictionary) -> void:
	if typeof(payload) != TYPE_DICTIONARY:
		return

	var fanout_hints_raw: Variant = payload.get("fanout_hints", {})
	var fanout_hints: Dictionary = fanout_hints_raw if typeof(fanout_hints_raw) == TYPE_DICTIONARY else {}
	if bool(fanout_hints.get("skip_llm_bridge", false)):
		return

	var qos_tier: String = _resolve_event_bus_qos_tier(payload)
	if qos_tier == "ambient":
		return

	var text: String = str(payload.get("text", "")).strip_edges()
	var event_name: String = str(payload.get("event_name", ""))
	if text == "":
		return

	var signature: String = _recent_event_signature(
		event_name,
		text,
		int(payload.get("year", gs.year)),
		int(payload.get("npc_id", -1))
	)
	if qos_tier == "important" and _has_recent_event_signature(signature):
		return

	recent_world_events.append({
		"event_id": int(payload.get("event_id", -1)),
		"year": int(payload.get("year", gs.year)),
		"event_name": event_name,
		"text": text,
		"npc_id": int(payload.get("npc_id", -1)),
		"target_id": int(payload.get("target_id", -1)),
		"source": str(payload.get("source", "event_bus")),
		"qos_tier": qos_tier,
		"_signature": signature
	})
	if recent_world_events.size() > MAX_RECENT_WORLD_EVENTS:
		recent_world_events.pop_front()
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


func _recent_event_signature(event_name: String, text: String, year_value: int, npc_id: int) -> String:
	return "%s|%s|%s|%s" % [
		event_name.strip_edges(),
		text.strip_edges(),
		str(year_value),
		str(npc_id)
	]


func _has_recent_event_signature(signature: String) -> bool:
	if signature == "":
		return false

	for raw_entry in recent_world_events:
		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = raw_entry
		if str(entry.get("_signature", "")).strip_edges() == signature:
			return true

	return false





var ERA_TONES = {

	"Ancient Era": {
		"style": "mythic, solemn, fate-driven",
		"voice": "poetic, symbolic, religious imagery",
		"cadence": "short declarative sentences",
		"keywords": ["omen", "fate", "sun", "stone", "blood", "empire"]
	},

	"Medieval Era": {
		"style": "folkloric, grounded, communal",
		"voice": "storyteller, village perspective",
		"cadence": "slightly archaic phrasing",
		"keywords": ["bell", "market", "lord", "road", "winter", "lantern"]
	},

	"Industrial Era": {
		"style": "introspective, gritty realism",
		"voice": "personal diary tone",
		"cadence": "longer reflective sentences",
		"keywords": ["smoke", "iron", "noise", "shift", "crowd"]
	},

	"Modern Era": {
		"style": "casual autobiographical",
		"voice": "contemporary conversational",
		"cadence": "natural speech rhythm",
		"keywords": ["phone", "city", "news", "online", "trend"]
	},

	"Future Era": {
		"style": "philosophical sci-fi",
		"voice": "observational, existential",
		"cadence": "clean precise sentences",
		"keywords": ["signal", "system", "orbit", "memory", "protocol"]
	}
}





const MAJOR_EVENT_TYPES = [
	"death",
	"illness_major",
	"injury",
	"era_shift"
]








var ERA_EVENT_FLAIR = {
	"Ancient Era": {
		"death": [
			" The air around us felt touched by fate.",
			" Priests would have called it an omen.",
			" It was written into stone.",
			" The gods seemed uncomfortably close.",
			" Even the dust felt like it knew before we did.",
			" Somewhere a torch flickered like it understood.",
			" Old women in the market would whisper about this for years.",
			" The sun itself felt harsher afterward.",
			" The temple steps suddenly felt colder.",
			" It landed on the village like a bronze bell to the skull.",
			" Acrello laughed at the circumstances. Historians hated that.",
			" Nobody seemed to care but Acrello.",
			" Fate came in through the front door like it paid taxes there.",
			" Even the goats looked briefly theological.",
			" It felt like a punishment, or a joke, or both.",
			" The empire rolled on anyway. Rude.",
			" Stone remembers things people pretend to forget.",
			" The scribes would have underlined this twice.",
			" Somewhere, some prophet would've milked this for content.",
			" The silence afterward felt carved by a chisel."
		],
		"illness_major": [
			" Priests murmured and pointed at the sky.",
			" Herbal smoke filled the air, though nobody looked especially confident.",
			" It felt like the body had offended something ancient.",
			" The healers gathered like men about to freestyle with leaves.",
			" Everybody started talking about omens the second things got bad.",
			" The room smelled like oil, stone, and panic.",
			" Even the strongest men suddenly found religion.",
			" Acrello claimed this built character. Suspicious behavior.",
			" People kept saying fate as if that explained literally anything.",
			" The household grew quiet in the way quiet gets loud.",
			" Someone definitely blamed a comet.",
			" The temple suddenly got a lot more popular.",
			" It was the sort of sickness that made everyone speak in whispers.",
			" The old remedies arrived immediately and none of them looked legal.",
			" The moment had that cursed sacred vibe to it.",
			" Even the sunlight felt invasive.",
			" Nobody knew what to do, so naturally they acted ceremonial.",
			" It felt like the body had entered negotiations with the underworld.",
			" A goat was probably unfairly blamed somewhere.",
			" The whole thing had deeply inconvenient omen energy."
		],
		"injury": [
			" Blood and dust made the moment feel larger than it was.",
			" Someone nearby gasped like the world had split open.",
			" The earth took note.",
			" It happened fast, then somehow kept happening in everyone's head.",
			" Acrello said walk it off. The body disagreed.",
			" The village stared with the useless intensity of professionals.",
			" Even the stones seemed judgmental.",
			" Pain arrived like a messenger with no bedside manner.",
			" The moment hit like a chariot wheel to destiny's ankle.",
			" It was ugly, immediate, and somehow mythic.",
			" A priest definitely would've tried to name this.",
			" The crowd reacted three business days too late.",
			" It felt like a lesson, which was frankly annoying.",
			" Dust rose like the world was trying to dramatize it.",
			" The body learned a brutal new paragraph.",
			" Nobody seemed prepared, which felt on brand for civilization.",
			" The gods watched with absolutely no customer support.",
			" It made the day weird in a way only blood can.",
			" Somewhere, a bystander muttered this was bad luck. Stunning insight.",
			" It had the energy of a cautionary tablet inscription."
		],
		"era_shift": [
			" It felt as though history itself had turned a page.",
			" Even the sun seemed to rise with a different opinion.",
			" The world stepped into a new age without asking anyone's permission.",
			" Time moved like a king changing thrones.",
			" The old order loosened its grip by one trembling finger.",
			" Acrello nodded like he had personally scheduled it.",
			" Something vast shifted behind ordinary life.",
			" The age changed, and everybody pretended that was normal.",
			" The calendar kept walking like nothing cosmic had happened.",
			" Stone, blood, and rumor all took new shapes.",
			" Even the air felt recently edited.",
			" History put on different sandals and kept moving.",
			" The world crossed an invisible border and called it destiny.",
			" Markets, temples, and empires all twitched at once.",
			" The old era coughed and the new one sat down.",
			" It felt like the start of a chapter written by louder gods.",
			" Civilization adjusted its robes and kept marching.",
			" The future arrived wearing ancient perfume.",
			" Time did one of its weird little dramatic reveals.",
			" Nobody could stop it. Classic time behavior."
		],
		"generic": [
			" Just another Monday.",
			" Our ENTIRE village celebrated!",
			" It's a christmas miracle!",
			" Acrello said it needed to happen."
		]
	},

	"Medieval Era": {
		"death": [
			" The village would remember.",
			" Word would travel farther than expected. Certainly Acrello's big mouth again.",
			" It felt like the start of an old tale.",
			" The bells might as well have rung on their own.",
			" Even the road out of town felt quieter.",
			" Lantern light suddenly seemed less cheerful.",
			" The whole village wore the news like wet wool.",
			" Someone crossed themselves before they even knew the details.",
			" The alehouse would be talking reckless by sundown.",
			" A chill moved through the town like it paid rent there.",
			" The crows were probably delighted. Grim little weirdos.",
			" It landed like winter on an unready field.",
			" Even the market noise thinned out.",
			" The moment had sermon energy all over it.",
			" Nobody seemed to care. I know I didn't.",
			" Acrello laughed at the circumstances. Naturally.",
			" It was the kind of loss that turns gossip into folklore.",
			" A monk somewhere would've written this extra dramatically.",
			" The mud, the bells, the faces — all of it remembered.",
			" It felt like the world had pulled one more mean little trick."
		],
		"illness_major": [
			" People spoke in whispers like that helped.",
			" The room smelled of herbs, wax, and very limited options.",
			" The healers arrived carrying confidence they had not earned.",
			" Every cough in the village suddenly felt suspicious.",
			" Somebody definitely blamed bad air, bad stars, or bad morals.",
			" It had plague-adjacent energy and nobody enjoyed that.",
			" The candles did their best. Respect to the candles.",
			" Even the strongest faces started looking prayer-shaped.",
			" The whole thing felt one monastery away from panic.",
			" The silence got thick enough to trip over.",
			" A bell in the distance would've fit the scene way too well.",
			" It was the sort of sickness that made everyone suddenly humble.",
			" Folk remedies began circulating with dangerous confidence.",
			" Acrello said drink broth and stop folding. Medieval medicine, apparently.",
			" The house went still in the most uncomfortable way.",
			" Nobody seemed to know what was happening, so they called it God's will.",
			" The night somehow got longer once the illness set in.",
			" It felt like fate had kicked the door open in muddy boots.",
			" Even the fire sounded concerned.",
			" The village rumor mill immediately clocked in."
		],
		"injury": [
			" It hurt in a way that would absolutely become a story later.",
			" Someone nearby reacted like a bard had just found new material.",
			" The ground offered no sympathy whatsoever.",
			" It happened with the ugly speed only real pain has.",
			" Acrello called it character development. Violent statement.",
			" The day split neatly into before and after.",
			" Even the horses would've judged that landing.",
			" The pain arrived armed and confident.",
			" A village elder was definitely going to over-explain this by evening.",
			" Blood made everything feel more official.",
			" The moment had tournament-gone-wrong energy.",
			" Nobody seemed especially useful. An ancient tradition.",
			" The body learned something expensive.",
			" It was the kind of injury that makes bystanders suddenly very spiritual.",
			" The mud was disrespectful about the whole thing.",
			" It turned a normal day into a cautionary folktale.",
			" Somebody muttered that it built toughness. Deeply unserious man.",
			" The pain clung on like cold rain.",
			" Even the road looked meaner afterward.",
			" It felt like a lesson from a cruel old ballad."
		],
		"era_shift": [
			" The world tilted into a new chapter.",
			" Old customs loosened and new ones crept in through the cracks.",
			" It felt like a new banner had been raised somewhere unseen.",
			" The age changed the way weather changes — slowly, then all at once.",
			" Even the roads seemed to point somewhere different.",
			" Acrello looked around like he had expected this from the start.",
			" A different kind of story had begun.",
			" The old world kept standing, but it no longer stood the same.",
			" The bells, the market, the fields — all of it belonged to a new age now.",
			" Time walked into town wearing a different cloak.",
			" The kingdom of yesterday lost a little ground.",
			" It felt like history had shifted its boots.",
			" The world changed and still expected everyone at work by dawn.",
			" One era closed its ledger and another opened one with worse handwriting.",
			" Even ordinary life felt newly translated.",
			" The horizon looked the same and meant something else.",
			" Time is really just a landlord with no mercy.",
			" The age turned over like a cartwheel in mud.",
			" The old tale ended and the next one didn't wait for applause.",
			" People called it change like that made it less strange."
		],
		"generic": [
			" It's been a LONG day."
		]
	},

	"Industrial Era": {
		"death": [
			" The noise of the world carried on.",
			" Smoke and routine swallowed the moment.",
			" The city did not pause for it.",
			" Nobody seemed to care but Acrello.",
			" EraLife creator, Acrello, laughed at the circumstances.",
			" The factory whistle could have blown straight through grief.",
			" Even tragedy had to compete with machinery.",
			" The street kept moving like loss was just another schedule issue.",
			" Coal dust, bad news, and tired faces — classic combo.",
			" The crowd absorbed it and kept walking.",
			" It vanished into the city's throat almost immediately.",
			" The newspapers would have loved this, the little vultures.",
			" The smoke made everything feel already mourned.",
			" Grief had no union protection here.",
			" The world felt loud in a particularly rude way.",
			" Nobody seemed to care. I know I didn't.",
			" It landed heavy, then got trampled by ordinary life.",
			" The buildings held the news without softening it.",
			" Even the silence sounded mechanical.",
			" The whole thing felt swallowed by soot."
		],
		"illness_major": [
			" The room smelled like medicine, iron, and overdue rent.",
			" The body looked like it had been drafted into a war it never asked for.",
			" Everybody suddenly had advice and none of it looked trustworthy.",
			" The city was full of sickness and somehow still surprised by it.",
			" Smoke did nobody any favors.",
			" The whole thing felt industrial in the worst possible sense.",
			" Coughs echoed like unpaid bills.",
			" Even the walls felt tired.",
			" It was the kind of illness that made the world look grimier.",
			" Acrello stared at the situation like it had insulted his breakfast.",
			" The doctors arrived wearing confidence and sideburns.",
			" Routine cracked open and showed the machinery underneath.",
			" Every breath suddenly sounded expensive.",
			" The factory outside kept roaring like nothing mattered.",
			" Nobody seemed prepared, but everyone pretended to be.",
			" The city specialized in continuing anyway.",
			" It felt like smoke had learned to live inside people.",
			" Hope looked thin, but still showed up to work.",
			" The whole house took on a sickly rhythm.",
			" The illness made the air feel rented."
		],
		"injury": [
			" Pain arrived with industrial efficiency.",
			" The body buckled, but the world kept its shift.",
			" The floor, naturally, offered no sympathy.",
			" Acrello laughed at the timing. Management behavior.",
			" It felt like iron had entered the conversation.",
			" The moment was brutal and embarrassingly public.",
			" Even the walls seemed used to this kind of thing.",
			" Somebody stared for half a second and went back to work.",
			" It hit like machinery with a grudge.",
			" Blood turned everything real in a hurry.",
			" The city had seen worse, which somehow made it meaner.",
			" Pain doesn't clock out, unfortunately.",
			" The noise around it made the hurt feel lonelier.",
			" The whole thing had factory-accident-adjacent vibes.",
			" Nobody seemed to care but Acrello. Again.",
			" The day suddenly tasted like metal.",
			" It felt like the kind of lesson the body resents forever.",
			" Routine broke for exactly five seconds.",
			" The injury sat there like an unpaid debt.",
			" The moment got swallowed by smoke and carried on."
		],
		"era_shift": [
			" The world changed gears and kept grinding.",
			" You could feel history under the floorboards.",
			" One age gave way to another like rust surrendering to steel.",
			" The streets looked the same but belonged to a different century.",
			" Even the smoke seemed to come from a newer ambition.",
			" The old world faded under louder machines.",
			" Time advanced with boots, rails, and bad intentions.",
			" Acrello looked around like the update patch had finally dropped.",
			" The calendar moved forward and dragged everyone with it.",
			" The age turned practical, sharp-edged, and exhausting.",
			" Change arrived looking efficient and deeply unromantic.",
			" The world put on iron and called it progress.",
			" The future started making noise.",
			" History switched uniforms mid-shift.",
			" A new era settled in with soot on its sleeves.",
			" The century reintroduced itself with less patience.",
			" Even memory sounded mechanical now.",
			" Progress is just destiny wearing factory boots.",
			" The old age coughed and the new one bought a rail line.",
			" Things were modern now, or at least louder."
		],
		"generic": []
	},

	"Modern Era": {
		"death": [
			" The group chat would not handle this well.",
			" The world kept scrolling anyway.",
			" It landed with the weird numbness modern life specializes in.",
			" Somebody definitely found out through a badly worded post.",
			" The city kept moving like nothing cosmic had happened.",
			" Acrello stared at it like the algorithm had finally gone too far.",
			" It made everything feel fake for a minute.",
			" Even the sunlight looked a little off afterward.",
			" Nobody knows how to react anymore, so everybody improvises badly.",
			" The silence afterward felt louder than traffic.",
			" Life kept buffering forward.",
			" It had that surreal this-can't-be-real texture to it.",
			" The whole day turned into one long pause screen.",
			" Somebody somewhere absolutely typed prayers hands and folded.",
			" The air felt weirdly overexposed.",
			" It made ordinary things feel disrespectfully normal.",
			" Modern grief is half tears, half staring at your phone.",
			" The room felt emptier in a very specific way.",
			" The moment sat on the chest like bad news with Wi-Fi.",
			" Nothing around it knew how to slow down."
		],
		"illness_major": [
			" Suddenly every symptom search looked cursed.",
			" The room changed temperature even if it technically didn't.",
			" Everybody started talking softer and Googling harder.",
			" It had that terrifying medical seriousness to it.",
			" Acrello looked at the situation like he wanted to argue with biology.",
			" The whole thing felt one diagnosis away from a life pivot.",
			" Even normal sounds got weird after that.",
			" Hope and dread started trading punches in the hallway.",
			" The day lost all of its casualness immediately.",
			" Nobody likes when the body starts speaking in capital letters.",
			" It made every breath feel more expensive.",
			" People tried to stay calm and mostly cosplayed calm.",
			" The atmosphere became aggressively hospital-shaped.",
			" Reality got very sterile, very fast.",
			" It felt like life had hit send on something ugly.",
			" The moment had no chill whatsoever.",
			" Even optimism started stretching before work.",
			" The silence in the room started doing too much.",
			" Everything before it felt like another timeline.",
			" The body had clearly filed a major complaint."
		],
		"injury": [
			" Pain showed up immediately and without manners.",
			" The body was not amused.",
			" It made the day weird on contact.",
			" Acrello definitely tried to play it cooler than it was.",
			" The moment had instant regret baked into it.",
			" It hurt with disrespectful efficiency.",
			" Everybody nearby suddenly became a fake EMT.",
			" The room reacted half a second late, as usual.",
			" It was one of those injuries that makes time hiccup.",
			" The body sent a very clear memo.",
			" Nothing dramatic happened except the pain, which was enough actually.",
			" It made the next few minutes feel stupidly long.",
			" The whole thing had clip-that-and-rewatch energy.",
			" Even the floor felt complicit.",
			" The day split into before that and after that.",
			" Nobody seemed helpful, but several people seemed curious. Disturbing species.",
			" It arrived like physics collecting a debt.",
			" The pain was immediate, sincere, and deeply committed.",
			" Suddenly walking normally became premium content.",
			" It felt like the universe had thrown elbows."
		],
		"era_shift": [
			" The world updated whether anybody was ready or not.",
			" It felt like history had pushed a silent notification.",
			" One version of life ended and another started auto-installing.",
			" The future arrived looking suspiciously like now, but stranger.",
			" Everything looked the same for about five seconds, then didn't.",
			" Acrello looked around like the patch notes had leaked early.",
			" Culture pivoted and dragged everybody's attention span with it.",
			" The age changed like an algorithm deciding who mattered.",
			" It felt like time had refreshed the page.",
			" The world kept its face but changed its mood.",
			" A new era rolled in wearing regular clothes.",
			" The timeline got a software update and no changelog.",
			" Yesterday's normal quietly expired.",
			" Something about the air felt recently revised.",
			" The future slid into the room and pretended it had always been there.",
			" Society shifted one inch and somehow that changed everything.",
			" Time does soft launches now.",
			" The old age was still visible in the rearview, looking bitter.",
			" Progress arrived carrying anxiety and branding.",
			" It was subtle, huge, and deeply on brand for history."
		],
		"generic": [
			" Weirdly enough, life kept moving."
		]
	},

	"Future Era": {
		"death": [
			" Systems registered the loss.",
			" The moment echoed like a signal.",
			" Something in the world quietly recalibrated.",
			" Nobody seemed to care but Acrello.",
			" We all shrugged and went on with life.",
			" Even the air felt processed afterward.",
			" The room went still like a severed network.",
			" Memory itself seemed to hesitate.",
			" It felt less like an ending and more like a system failure with grief attached.",
			" The silence had machine precision.",
			" The world logged it and kept spinning. Cold work.",
			" Somewhere, some protocol updated without asking permission.",
			" The loss moved through the room like a broken transmission.",
			" Acrello watched it like reality had glitched in bad taste.",
			" It left a hole shaped like missing data.",
			" Even the lights seemed less convinced.",
			" The moment had deep-space loneliness to it.",
			" Nothing crashed, but everything felt interrupted.",
			" It lingered like a corrupted file no one could repair.",
			" Existence remained functional and emotionally rude."
		],
		"illness_major": [
			" Diagnostics suddenly felt a little too honest.",
			" The body read like a failing interface.",
			" Everyone waited for a clean answer and got dread instead.",
			" It felt like biology had slipped past the safeguards.",
			" Even the monitors seemed tense.",
			" The room hummed with that cold futuristic panic.",
			" Somebody trusted the system right up until they didn't.",
			" Acrello looked at the situation like he wanted to fight the firmware.",
			" The illness moved like bad code in living tissue.",
			" Precision did not make it less frightening.",
			" Every reading felt heavier than numbers should.",
			" Hope flickered like a stressed-out power cell.",
			" It had the sterile terror of something too advanced to misunderstand.",
			" The world stayed sleek while the moment got ugly.",
			" Suddenly every breath felt monitored.",
			" It was one of those crises that made technology feel decorative.",
			" The body had clearly rejected the patch.",
			" The room felt clinically haunted.",
			" Even the silence sounded digitized.",
			" It made progress feel suspicious."
		],
		"injury": [
			" Impact translated instantly into pain.",
			" The body threw an alert the soul could not ignore.",
			" It hit like gravity briefly changed its mind.",
			" Acrello definitely acted like it was fine for three lying seconds.",
			" The moment glitched from normal to awful.",
			" Even the floor seemed algorithmically unhelpful.",
			" Pain arrived with clean futuristic efficiency.",
			" It felt like physics had filed a complaint.",
			" The world stayed smooth while the body very much did not.",
			" Nothing says alive like immediate system distress.",
			" The injury made time stutter for a second.",
			" Somebody nearby looked concerned in 4K.",
			" The impact had starship turbulence energy.",
			" Reality did a hard collision check.",
			" It was abrupt, precise, and unbelievably rude.",
			" The body logged the event in all caps.",
			" Even advanced civilization still gets folded by momentum.",
			" It made the room feel sharper afterward.",
			" The pain was crisp, modern, and deeply committed.",
			" Turns out the future still hurts."
		],
		"era_shift": [
			" Something in the world quietly recalibrated.",
			" Systems registered the change.",
			" The moment echoed like a signal.",
			" The age updated in real time.",
			" History changed states without ceremony.",
			" The world pivoted like a station adjusting orbit.",
			" Yesterday's protocols no longer fit.",
			" Acrello stood there like he'd read the patch notes already.",
			" The future became more itself.",
			" Time executed a clean transition.",
			" A new era propagated across reality.",
			" Even memory felt re-indexed.",
			" Civilization accepted a different operating assumption.",
			" The old age remained in archives and nowhere else.",
			" It felt like the timeline had entered a new build.",
			" The world didn't shatter. It migrated.",
			" One order of reality yielded to the next.",
			" Existence got versioned again.",
			" The horizon looked the same and computed differently.",
			" The update was invisible and total."
		],
		"generic": []
	}
}





func enhance(current_text: String, person, raw_event: Dictionary) -> String:

	if gs.era == null:
		return current_text

	var era_name = gs.era.name
	var tone = ERA_TONES.get(era_name, ERA_TONES ["Modern Era"])


	var context = _build_context(person, raw_event, tone)


	if not _llm_available():
		return _fallback_style(current_text, context)


	return _call_llm(current_text, context)





func _build_context(person, raw_event, tone) -> Dictionary:
	var npc_id: int = -1
	if person != null:
		npc_id = int(person.id)

	var target_id: int = int(raw_event.get("target_id", -1))

	var recent_memories: Array = []
	var high_impact_memories: Array = []
	var relationship_memories: Array = []
	var npc_facts: Dictionary = {}
	var target_facts: Dictionary = {}
	var context_recent_world_events: Array = []

	if gs.npc_memory_web_engine != null and npc_id != -1:
		recent_memories = gs.npc_memory_web_engine.get_recent_memories(npc_id, 8)
		high_impact_memories = gs.npc_memory_web_engine.get_high_impact_memories(npc_id, 20, 6)
		if target_id != -1:
			relationship_memories = gs.npc_memory_web_engine.get_relationship_relevant_memories(npc_id, target_id, 5)

	if gs.has_method("get_npc_facts_by_id"):
		npc_facts = gs.get_npc_facts_by_id(npc_id)
		if target_id != -1:
			target_facts = gs.get_npc_facts_by_id(target_id)

	var world_start: int = max(0, recent_world_events.size() - 8)
	context_recent_world_events = recent_world_events.slice(world_start, recent_world_events.size())

	return {
		"era": gs.era.name if gs.era != null else "",
		"year": gs.year,
		"event_name": raw_event.get("event_name", raw_event.get("type", "text")),
		"event_type": raw_event.get("type", raw_event.get("event_name", "text")),
		"event_text": raw_event.get("text", ""),
		"source": raw_event.get("source", "unknown"),
		"person": {
			"id": npc_id,
			"name": person.first_name + " " + person.last_name if person != null else "",
			"age": person.age if person != null else 0,
			"traits": person.traits if person != null else [],
			"fate_arc": person.fate_arc if person != null else "",
			"job": person.job if person != null else "",
			"fame": person.fame if person != null else 0,
			"social_class": person.social_class if person != null else ""
		},
		"npc_facts": npc_facts,
		"target_id": target_id,
		"target_facts": target_facts,
		"recent_memories": recent_memories,
		"high_impact_memories": high_impact_memories,
		"relationship_memories": relationship_memories,
		"context_recent_world_events": context_recent_world_events,
		"style": tone.style,
		"voice": tone.voice,
		"cadence": tone.cadence,
		"keywords": tone.keywords,
	}





func _llm_available() -> bool:

	return false






func _fallback_style(text: String, ctx: Dictionary) -> String:

	if text == "":
		return text

	var event_type:= str(ctx.get("event_type", "text"))


	if event_type not in MAJOR_EVENT_TYPES:
		return text

	var flair = _pick_flair(str(ctx.get("era", "Modern Era")), event_type)

	if flair == "":
		return text

	return text + flair


func _pick_flair(era_name: String, event_type: String) -> String:

	var era_pool = ERA_EVENT_FLAIR.get(era_name, {})
	if era_pool == {}:
		return ""

	var pool: Array = era_pool.get(event_type, [])
	if pool.size() == 0:
		pool = era_pool.get("generic", [])

	if pool.size() == 0:
		return ""

	return pool [randi() % pool.size()]





func _call_llm(text: String, _ctx: Dictionary) -> String:



	return text