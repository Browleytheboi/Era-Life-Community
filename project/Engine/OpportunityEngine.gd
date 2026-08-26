extends Resource
class_name OpportunityEngine

var gs

func _init(_gs):
	gs = _gs


func generate_opportunities(
	person,
	context: Dictionary = {}
):
	var opts = []
	var place_bias: Dictionary = {}
	var surface_id: String = str(
		context.get(
			"surface_id",
			""
		)
	).strip_edges().to_lower()
	var exclude_career_opportunities: bool = bool(
		context.get(
			"exclude_career_opportunities",
			surface_id == "activities_hub"
		)
	)
	var hide_vampire_discovery_actions: bool = bool(
		context.get(
			"hide_vampire_discovery_actions",
			surface_id == "activities_hub"
		)
	)

	if gs.place_influence_engine != null:
		place_bias = (
			gs.place_influence_engine
			.get_opportunity_bias(
				person
			)
		)






	if gs.school_engine != null:
		var school_options = (
			gs.school_engine.get_school_options_for(
				person
			)
		)

		if (
			school_options.size() > 0
			and gs.school_engine.can_attend_school(
				person
			)
		):
			var school_started:= false

			for opt in school_options:
				match opt.get(
					"type",
					""
				):
					"era_school":
						if not school_started:
							opts.append(
								"Start School"
							)
							school_started = true

						opts.append(
							"Enroll In Era School"
						)

					"bending_school":
						if gs.is_feature_enabled(
							"supernatural_school"
						):
							opts.append(
								"Enroll In Bending School"
							)

					"dual_enrollment":
						opts.append(
							"Dual Enrollment"
						)

			if gs.school_engine.get_classmates(
				person
			).size() > 0:
				opts.append(
					"Interact With Classmates"
				)








	if (
		not exclude_career_opportunities
		and gs.career_engine != null
	):
		var part_time_jobs: Array = (
			gs.career_engine
			.get_available_part_time_jobs_for(
				person
			)
		)
		var full_time_jobs: Array = (
			gs.career_engine
			.get_available_jobs_for(
				person
			)
		)
		var famous_tracks: Array = (
			gs.career_engine
			.get_famous_career_tracks_for(
				person
			)
		)

		if person.job == "":
			if (
				person.age >= 16
				and person.age < 18
				and part_time_jobs.size() > 0
			):
				opts.append(
					"Apply for Part Time Job"
				)
				opts.append(
					"Browse Part Time Jobs"
				)

			if (
				person.age >= 18
				and full_time_jobs.size() > 0
			):
				opts.append(
					"Apply for Full Time Job"
				)
				opts.append(
					"Browse Full Time Jobs"
				)

			if famous_tracks.size() > 0:
				opts.append(
					"Browse Famous Careers"
				)
		else:
			opts.append(
				"View Job Details"
			)

			if (
				gs.workplace_engine != null
				and gs.workplace_engine.has_coworkers(
					person
				)
			):
				opts.append(
					"Work Normally"
				)
				opts.append(
					"Work Hard"
				)
				opts.append(
					"Slack Off"
				)
				opts.append(
					"Ask for Raise"
				)
				opts.append(
					"View Coworkers"
				)

			opts.append(
				"Quit Job"
			)

	if (
		gs.school_engine != null
		and person.age >= 18
	):
		var adult_academic_prompts = (
			gs.school_engine
			.get_adult_academic_prompts_for(
				person
			)
		)

		for prompt in adult_academic_prompts:
			opts.append(
				prompt
			)




	if (
		gs.is_feature_enabled(
			"bending"
		)
		and person.bending_type != "none"
	):
		opts.append(
			"Train Bending"
		)
		opts.append(
			"Challenge To Bending Duel"
		)

		if (
			person.bending_type != "none"
			and person.bending_mastery.get(
				person.bending_type,
				0
			) >= 3
		):
			opts.append(
				"Teach Bending"
			)

		if person.bending_type == "avatar":
			opts.append(
				"Grant Bending"
			)
			opts.append(
				"Remove Bending"
			)




	if gs.is_feature_enabled(
		"vampires"
	):
		if person.vampire_profile.get(
			"is_vampire",
			false
		):
			opts.append(
				"Feed"
			)
			opts.append(
				"Use Blood Bag"
			)
			opts.append(
				"Glamour Target"
			)
			opts.append(
				"Join Coven"
			)
			opts.append(
				"Found Coven"
			)
			opts.append(
				"Seek Cure"
			)

			if person.vampire_profile.get(
				"blood_potency",
				0
			) >= 35:
				opts.append(
					"Turn Someone"
				)

			if person.vampire_profile.get(
				"blood_potency",
				0
			) >= 25:
				opts.append(
					"Blood Bond"
				)
		elif not hide_vampire_discovery_actions:
			opts.append(
				"Investigate Vampire Rumors"
			)
			opts.append(
				"Ask To Be Turned"
			)




	if (
		gs.economy_engine != null
		and gs.economy_engine.silk_road_available()
	):
		opts.append(
			"Trade On The Silk Road"
		)

	if (
		person.age >= 18
		and gs.era != null
		and gs.era_data_loader != null
	):
		var property_templates: Array = (
			gs.era_data_loader
			.get_property_templates_for_era(
				gs.era.name
			)
		)
		var transport_templates: Array = (
			gs.era_data_loader
			.get_transport_templates_for_era(
				gs.era.name
			)
		)

		if property_templates.size() > 0:
			opts.append(
				"Browse Property Market"
			)

		if transport_templates.size() > 0:
			opts.append(
				"Browse Vehicle Market"
			)

	if (
		gs.boxing_engine != null
		and gs.boxing_engine.can_start_boxing(
			person
		)
	):
		if person.boxing_profile.get(
			"is_boxer",
			false
		):
			opts.append(
				"Boxing"
			)

	return _sort_opportunities_by_place_bias(
		opts,
		place_bias
	)
func _sort_opportunities_by_place_bias(opts: Array, place_bias: Dictionary) -> Array:
	var deduped: Array = []
	for raw_opt in opts:
		var opt: String = str(raw_opt)
		if opt == "":
			continue
		if opt not in deduped:
			deduped.append(opt)

	var action_bias: Dictionary = {}
	if typeof(place_bias) == TYPE_DICTIONARY:
		action_bias = place_bias.get("action_bias", {})
	if typeof(action_bias) != TYPE_DICTIONARY or action_bias.is_empty():
		return deduped

	var scored: Array = []
	for i in range(deduped.size()):
		var label: String = str(deduped [i])
		scored.append({
			"label": label,
			"score": float(action_bias.get(label, 0.0)),
			"index": i
		})

	scored.sort_custom(func (a, b):
		var a_score: float = float(a.get("score", 0.0))
		var b_score: float = float(b.get("score", 0.0))
		if a_score == b_score:
			return int(a.get("index", 0)) < int(b.get("index", 0))
		return a_score > b_score
	)

	var out: Array = []
	for row in scored:
		out.append(str(row.get("label", "")))
	return out


func resolve_action(action):
	if action == "Trade On The Silk Road":
		return {
			"success": true,
			"type": "open_silk_road_panel",
			"text": "Choose a trade good to purchase for your Silk Road route."
		}

	if action == "Apply for Part Time Job":
		var jobs = gs.career_engine.get_available_part_time_jobs_for(gs.player)
		if jobs.is_empty():
			return { "success": false, "text": " ❌ No part-time jobs are currently available."}
		var selected_job = jobs [randi() % jobs.size()]
		return gs.career_engine.apply_for_part_time_job(gs.player, selected_job)

	if action == "Apply for Full Time Job":
		var jobs = gs.career_engine.get_available_jobs_for(gs.player)
		if jobs.is_empty():
			return { "success": false, "text": " ❌ No full-time jobs are currently available."}
		var selected_job = jobs [randi() % jobs.size()]
		return gs.career_engine.apply_for_job(gs.player, selected_job)

	if action == "Browse Part Time Jobs":
		var jobs = gs.career_engine.get_available_part_time_jobs_for(gs.player)
		if jobs.is_empty():
			return { "success": true, "text": " 💼 No part-time jobs are available to me right now."}
		return { "success": true, "text": " 💼 Part-Time Jobs: %s" % ", ".join(jobs)}

	if action == "Browse Full Time Jobs":
		var jobs = gs.career_engine.get_available_jobs_for(gs.player)
		if jobs.is_empty():
			return { "success": true, "text": " 💼 No full-time jobs are available to me right now."}
		return { "success": true, "text": " 💼 Full-Time Jobs: %s" % ", ".join(jobs)}

	if action == "Browse Famous Careers":
		var tracks = gs.career_engine.get_famous_career_tracks_for(gs.player)
		if tracks.is_empty():
			return { "success": true, "text": " 🌟 No famous career tracks are visible in this era right now."}
		return { "success": true, "text": " 🌟 Famous Career Tracks: %s" % ", ".join(tracks)}

	if action.begins_with("Apply For Job::"):
		var job_name: String = action.trim_prefix("Apply For Job::")
		if gs.player.age >= 18:
			return gs.career_engine.apply_for_job(gs.player, job_name)
		return gs.career_engine.apply_for_part_time_job(gs.player, job_name)

	if action == "View Job Details":
		return gs.career_engine.describe_job(gs.player)
	if action == "Work Normally":
		return gs.career_engine.work_shift(gs.player, "normal")
	if action == "Work Hard":
		return gs.career_engine.work_shift(gs.player, "hard")
	if action == "Slack Off":
		return gs.career_engine.work_shift(gs.player, "slack")
	if action == "Ask for Raise":
		return gs.career_engine.ask_for_raise(gs.player)
	if action == "View Coworkers":
		var coworkers: Array = gs.workplace_engine.get_coworkers(gs.player)
		if coworkers.is_empty():
			return { "success": true, "text": "\n🧾\n I do not currently have any coworkers."}
		var coworker_ids: Array = []
		for c in coworkers:
			if c == null:
				continue
			coworker_ids.append(int(c.id))
		return {
			"success": true,
			"type": "open_career_coworkers_panel",
			"text": "Viewing coworkers.",
			"coworker_ids": coworker_ids
		}
	if action == "Quit Job":
		return gs.career_engine.quit_job(gs.player)


	if action in [
		"Start Boxing",
		"Start Boxing Career",
		"Train Boxing",
		"Boxing Sparring",
		"View Boxing Record",
		"Book Boxing Match",
		"Opponent Preview",
		"Confirm Boxing Fight",
		"Cancel Boxing Fight",
		"View Boxing Rivalries",
		"Call Out Opponent",
		"Change Weight Class",
		"Review Last Fight Log",
		"Enter Amateur Tournament",
		"Pound-for-Pound Rankings",
		"Fight Economy"
	]:
		if gs.boxing_contract_engine != null and gs.boxing_contract_engine.has_method("run_action_label"):
			return gs.boxing_contract_engine.run_action_label(action, gs.player)

		if action == "Start Boxing" or action == "Start Boxing Career":
			return gs.boxing_engine.start_boxing_career(gs.player)
		if action == "Train Boxing":
			return gs.boxing_training_engine.train_fighter(gs.player)
		if action == "View Boxing Record":
			return {
				"success": true,
				"text": gs.boxing_engine.describe_record(gs.player)
			}
		if action == "Book Boxing Match":
			return gs.boxing_matchmaking_engine.book_player_fight(gs.player)
		if action == "Review Last Fight Log":
			return {
				"success": true,
				"text": gs.boxing_engine.describe_last_fight_log(gs.player)
			}
		if action == "Enter Amateur Tournament":
			if gs.boxing_amateur_engine != null and gs.boxing_amateur_engine.has_method("enter_amateur_circuit"):
				return gs.boxing_amateur_engine.enter_amateur_circuit(gs.player, "player_fallback")

		return {
			"success": false,
			"text": "❌ Boxing action could not be resolved."
		}

	if action == "Enter Amateur Tournament":
		if gs.era_engine == null or not gs.era_engine.supports_world_title_boxing():
			return { "success": false, "text": "\n❌\n Boxing is not available in this era."}
		if gs.player == null or gs.player.boxing_profile.get("turned_pro", false):
			return { "success": false, "text": "\n❌\n I am already a professional boxer."}
		if not gs.player.boxing_profile.get("is_boxer", false):
			gs.boxing_fighter_engine.initialize_fighter(gs.player)
			gs.player.boxing_profile ["turned_pro"] = false
			gs.player.boxing_profile ["amateur_circuit"] ["is_amateur"] = true
			gs.player.boxing_profile ["record"] = {
				"wins": 0,
				"losses": 0,
				"draws": 0,
				"kos": 0
			}
		var amateur_txt = "\n🥇\n I entered the amateur boxing circuit."
		gs.narrative_engine.log_event(gs.player, { "type": "text", "text": amateur_txt})
		return { "success": true, "text": amateur_txt}