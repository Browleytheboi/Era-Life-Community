extends Resource
class_name BoxingRoundLogEngine

var gs

func _init(_gs):
	gs = _gs

func generate_fight_log(a: Person, b: Person, projected_winner_id: int, result_type: String) -> Array:
	var logs:= []
	var max_rounds = 12
	var finish_round = max_rounds

	if result_type == "KO":
		finish_round = randi_range(2, 11)
	elif result_type == "TKO":
		finish_round = randi_range(4, 11)

	for round_num in range(1, finish_round + 1):
		var round_data = _simulate_round(a, b, round_num, projected_winner_id, result_type, finish_round)
		logs.append(round_data)

	return logs

func _simulate_round(a: Person, b: Person, round_num: int, projected_winner_id: int, result_type: String, finish_round: int) -> Dictionary:
	var a_pressure = _round_pressure(a)
	var b_pressure = _round_pressure(b)

	var swing = randi_range(-12, 12)
	var a_points = a_pressure + swing
	var b_points = b_pressure - swing

	var winner_id = a.id if a_points >= b_points else b.id
	var knockdowns:= []

	if result_type in ["KO", "TKO"] and round_num == finish_round:
		winner_id = projected_winner_id
		knockdowns.append({
			"scored_by": projected_winner_id,
			"text": "A huge shot changed the entire fight."
		})
	elif randi() % 100 < 12:
		knockdowns.append({
			"scored_by": winner_id,
			"text": "A flash knockdown stole the round."
		})

	return {
		"round": round_num,
		"winner_id": winner_id,
		"a_estimated_points": clamp(a_points, 8, 10),
		"b_estimated_points": clamp(b_points, 8, 10),
		"knockdowns": knockdowns,
		"summary": _round_summary(a, b, winner_id, knockdowns)
	}

func _round_pressure(p: Person) -> int:
	var r = p.boxing_profile ["ratings"]
	var bp = p.boxing_profile ["boxing_personality"]

	var total = 0
	total += int(r ["power"] * 0.1)
	total += int(r ["speed"] * 0.1)
	total += int(r ["ring_iq"] * 0.08)
	total += int(r ["defense"] * 0.07)
	total += int(r ["cardio"] * 0.08)
	total += int(bp ["courage"] * 0.04)
	total += int(bp ["adaptability"] * 0.03)

	return total

func _round_summary(a: Person, b: Person, winner_id: int, knockdowns: Array) -> String:
	var winner_name = a.first_name if winner_id == a.id else b.first_name

	if not knockdowns.is_empty():
		return "Round %d swung hard as %s dropped the other fighter." % [0, winner_name]

	var pool = [
		"%s controlled distance and landed the cleaner work.",
		"%s pressed forward and stole the exchanges.",
		"%s boxed sharply behind timing and defense.",
		"%s edged a close tactical round."
	]

	return pool [randi() % pool.size()] % winner_name