extends Resource
class_name PoliticsEngine

var gs

func _init(_gs):
	gs = _gs

func attempt_coup(attacker: Person, defender: Person) -> Dictionary:
	if attacker == null or defender == null:
		return { "text": "There is no throne to contest right now."}
	if attacker.age < 16:
		return { "text": "You are too young to stage a coup."}
	var chance:= int(attacker.smarts) + int(attacker.fame) - int(defender.approval)
	if attacker.is_royal:
		chance += 10
	if int(attacker.succession_rank) > 0 and int(defender.succession_rank) >= 0 and int(attacker.succession_rank) < int(defender.succession_rank):
		chance += 10
	chance = clamp(chance, 5, 95)
	var roll:= randi() % 100
	if roll < chance:
		defender.deposed = true
		defender.is_ruler = false
		defender.palace_owned = false
		attacker.is_ruler = true
		attacker.is_royal = true
		attacker.social_class = "Royal"
		attacker.deposed = false
		attacker.exiled = false
		attacker.palace_owned = true
		attacker.approval = randi_range(42, 68)

		var aftermath_text:= ""
		if randi() % 2 == 0:
			defender.exiled = true
			aftermath_text = "%s was banished from the royal house." % defender.first_name
		else:
			aftermath_text = "%s was executed after the coup." % defender.first_name
			if gs.health_engine != null:
				gs.health_engine.try_kill(defender, "Executed after a coup")

		if gs.royalty_engine != null:
			gs.royalty_engine.on_successful_coup(attacker, defender)

		var world_text:= "⚔ %s overthrew %s and seized the throne. %s" % [
			attacker.first_name,
			defender.first_name,
			aftermath_text
		]
		gs.push_world_feed(
			world_text,
			{
				"npc_id": attacker.id,
				"personally_relevant": attacker == gs.player or defender == gs.player,
				"category": "politics",
				"event_name": "royal_coup",
				"source": "politics_engine"
			}
		)
		if gs.event_bus != null:
			gs.event_bus.emit(ActionEventTypes.DYNASTY_SHIFT, {
				"npc_id": attacker.id,
				"text": world_text
			})
		return {
			"text": "I successfully overthrew %s and claimed the throne. %s" % [
				defender.first_name,
				aftermath_text
			]
		}

	var jail:= randi_range(5, 30)
	attacker.traits.append("InPrison_%d" % jail)
	return {
		"text": "My coup failed. I was arrested and sentenced to %d years." % jail
	}

func declare_war(realm_a, realm_b):

	var winner = realm_a if randi() % 2 == 0 else realm_b

	winner.population += randi_range(100, 500)
	winner.land_size += randi_range(1, 5)