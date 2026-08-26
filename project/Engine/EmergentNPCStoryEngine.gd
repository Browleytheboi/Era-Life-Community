extends Resource
class_name EmergentNPCStoryEngine

var gs

func _init(_gs):
	gs = _gs






var STORY_ARCS = [

	{
		"name": "RiseToFame",
		"steps": [
			"started_pursuit",
			"local_success",
			"national_attention",
			"global_fame"
		]
	},

	{
		"name": "CrimeSpiral",
		"steps": [
			"petty_crime",
			"organized_crime",
			"major_crime",
			"arrested"
		]
	},

	{
		"name": "BusinessEmpire",
		"steps": [
			"started_business",
			"small_success",
			"major_company",
			"wealthy"
		]
	},

	{
		"name": "PoliticalRise",
		"steps": [
			"local_politics",
			"regional_power",
			"national_power"
		]
	},

	{
		"name": "ReligiousAwakening",
		"steps": [
			"spiritual_interest",
			"devoted_follower",
			"religious_leader"
		]
	}
]



var npc_arcs = {}





func yearly_tick():

	for npc in gs.npcs:

		if npc == gs.player:
			continue

		if not npc.alive:
			continue

		if not npc_arcs.has(npc.id):

			if randi() % 400 == 0:
				_start_arc(npc)

		else:
			_progress_arc(npc)






func _start_arc(npc):

	var arc = STORY_ARCS [randi() % STORY_ARCS.size()]

	npc_arcs [npc.id] = {
		"arc": arc,
		"step": 0
	}

	_log_arc_event(npc, arc.steps [0])






func _progress_arc(npc):

	if randi() % 3 != 0:
		return

	var data = npc_arcs [npc.id]

	data.step += 1

	var steps = data.arc.steps

	if data.step >= steps.size():
		npc_arcs.erase(npc.id)
		return

	_log_arc_event(npc, steps [data.step])






func _log_arc_event(npc, step):

	var text = ""

	match step:

		"started_pursuit":
			text = "%s began chasing a dream." % npc.first_name

		"local_success":
			text = "%s gained local recognition." % npc.first_name

		"national_attention":
			text = "%s started gaining national attention." % npc.first_name

		"global_fame":
			text = "%s became globally famous." % npc.first_name
			gs.fame_engine.give_fame(npc, 80)

		"petty_crime":
			text = "%s was rumored to be involved in petty crimes." % npc.first_name

		"organized_crime":
			text = "%s became involved in organized crime." % npc.first_name

		"major_crime":
			text = "%s committed a major crime." % npc.first_name

		"arrested":
			text = "%s was arrested by authorities." % npc.first_name
			gs.event_bus.emit(ActionEventTypes.NPC_ARRESTED, { "npc_id": npc.id})

		"started_business":
			text = "%s started a small business." % npc.first_name

		"small_success":
			text = "%s's business began growing." % npc.first_name

		"major_company":
			text = "%s founded a major company." % npc.first_name

		"wealthy":
			npc.bank_balance += randi_range(500000, 5000000)
			text = "%s became extremely wealthy." % npc.first_name

		"local_politics":
			text = "%s entered local politics." % npc.first_name

		"regional_power":
			text = "%s gained regional political influence." % npc.first_name

		"national_power":
			text = "%s rose to national political power." % npc.first_name

		"spiritual_interest":
			text = "%s developed a deep spiritual interest." % npc.first_name

		"devoted_follower":
			text = "%s became a devoted religious follower." % npc.first_name

		"religious_leader":
			text = "%s became a religious leader." % npc.first_name

	gs.push_world_feed(text, {
		"npc_id": npc.id,
		"personally_relevant": false,
		"category": "story_arc",
		"event_name": "emergent_story_step",
		"source": "emergent_story_engine"
	})